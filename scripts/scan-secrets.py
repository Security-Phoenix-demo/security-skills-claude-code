#!/usr/bin/env python3
"""Fail the build on a credential committed to the tree.

This lived inline in .github/workflows/validate.yml, where it could not be run
without pushing and could not be tested at all. Four bypasses shipped that way:

    a bare, unquoted assignment      quoting was required, so a bare value passed
    two assignments on one line      only the first match on a line was examined
    a key pasted into a README       .md was excluded wholesale
    a value containing a dollar      any `$` at all counted as interpolation

A later audit found that keyword=value was itself too narrow a model, and that the
value filters were inverted with respect to risk -- a password was exempt for
containing the symbols a password generator puts in it, and a private key was exempt
because a PEM header has spaces in it. So there are three detectors now:

  1. Self-identifying literals    a PEM block, AKIA..., ghp_..., a JWT, user:pass@host.
                                  No keyword needed: the value says what it is.
  2. Keyword assignments          name = value, in shell, dotenv, JSON, YAML and XML.
  3. YAML block scalars           `key: |` with the value on the lines beneath.

Every one of those is a case in scripts/test-scan-secrets.py.

The hard part is not finding `password=`; it is not shouting at the thousand lines
that legitimately mention one. A gate that cries wolf gets switched off, and then it
protects nothing. The rule is that a credential is an opaque token while code that
reads one is a name or an expression:

    process.env.BRAVE_API_KEY             reads a secret, ships none
    RSA_PUBLIC_KEY_BYTES                  a constant's name -- every segment is a word
    state.auth.accessToken                a member expression
    ${{ secrets.BRAVE_KEY }}              a reference resolved at run time
    https://oauth2.googleapis.com/token   a public endpoint, not a credential

Stdlib only, so it runs anywhere with python3 and no install step.

    python3 scripts/scan-secrets.py            # from the repo root
    python3 scripts/scan-secrets.py --root .   # explicitly

Exit 0 clean, 1 if anything looks like a committed credential.

Known limits, stated rather than left to be discovered: an all-digit secret of low
entropy (SMS_TOKEN=202420242024) is not flagged, because every timestamp and account
number in the tree would be. Encrypted or base64-wrapped credential stores are not
opened.
"""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
from collections import Counter

# A file larger than this is a build artefact or a dataset, not source. Scanning it
# costs more than it finds, and an unbounded scan is how a CI step becomes a timeout.
MAX_FILE_BYTES = 2_000_000

# Beyond this a "line" is minified output or an encoded blob. The bounded
# self-identifying patterns still run on it; the keyword scan does not, because that
# is where the quadratic backtracking lived.
MAX_LINE_CHARS = 4096

SKIP_DIRS = {
    ".git", "node_modules", ".venv", "venv", "__pycache__",
    "dist", "build", "target", "vendor", ".mypy_cache", ".pytest_cache",
}

# Only narrowly-identified example files are exempt. Markdown is NOT: a key pasted
# into a README is committed exactly like one in a script, and PLACEHOLDER below is
# what keeps real documentation quiet.
SKIP_SUFFIXES = (".example", ".example.json")

# ----------------------------------------------------------------- detector 1
# These need no keyword. The value identifies itself, which is why they also catch
# the shapes that carry no name at all: a PEM body, a connection string, an .npmrc.
SELF_IDENTIFYING = [
    ("private key block",
     re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----")),
    ("AWS access key id",
     re.compile(r"(?:AKIA|ASIA)[0-9A-Z]{16}")),
    ("GitHub token",
     re.compile(r"gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}")),
    ("Google API key",
     re.compile(r"AIza[0-9A-Za-z_-]{35}")),
    ("Slack token",
     re.compile(r"xox[abprs]-[0-9A-Za-z-]{10,}")),
    ("Stripe key",
     re.compile(r"[sr]k_(?:live|test)_[0-9A-Za-z]{16,}")),
    ("GitLab token",
     re.compile(r"glpat-[0-9A-Za-z_-]{20,}")),
    ("npm token",
     re.compile(r"npm_[0-9A-Za-z]{36}")),
    ("JSON web token",
     re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}")),
    # postgres://user:hunter2@host, mongodb+srv://..., amqp://... A credential inside
    # a URL carries no keyword of its own, so the keyword detector never saw it.
    ("credentials in a connection string",
     re.compile(r"[a-zA-Z][a-zA-Z0-9+.-]{1,20}://[^\s:/@'\"]{1,64}:([^\s/@'\"]{4,})@")),
    # .npmrc, including the //registry.../:_authToken= form it actually uses. Anchored
    # to the start of a line or a registry prefix: unanchored, `is_auth = auth.is_...`
    # ends with _auth and matched, which is a function call, not a credential.
    ("npm auth token",
     re.compile(r"(?:^|[:/])_auth(?:Token)?\s*=\s*([^\s'\"]{8,})", re.M)),
]

# ----------------------------------------------------------------- detector 2
# The keyword may sit inside a longer name -- AWS_SECRET_ACCESS_KEY= is the
# most-committed secret there is, and requiring the keyword to touch the `=` missed
# every compound name. Separators are required on both sides, so `tokenizer =` and
# `tokens =` still do not match.
#
# The repetition counts are bounded on purpose. `(?:[A-Za-z0-9]+[_.-])*` backtracks
# over every length of every alphanumeric run, which made one 80 KB line of hex take
# 76 seconds. Bounded, the same input is linear.
_WORD = r"[A-Za-z0-9]{1,32}"
KEYWORD = (
    r"(?:" + _WORD + r"[_.-]){0,4}"
    r"(?:api[_-]?key|secret|password|passwd|pwd|token|private[_-]?key"
    r"|access[_-]?key|auth[_-]?token|credential|bearer)"
    r"(?:[_.-]" + _WORD + r"){0,4}"
)

# The `["']?` closes a JSON key: {"token": "..."} puts a quote between the name and
# the colon, which is how a credential in a .json config went unread.
ASSIGNMENT = re.compile(
    KEYWORD + r"""["']?\s*[:=]\s*"""
    r"""(?:(?P<q>["'])(?P<qv>[^"'\n]{8,})(?P=q)|(?P<bv>[^\s"'`,;)\]}]{8,}))""",
    re.I,
)

# <password>hunter2hunter2</password> -- an XML element has no [:=] after the name, so
# the assignment detector could not match a Maven settings.xml at all.
XML_ELEMENT = re.compile(
    r"<(" + KEYWORD + r")\s*>([^<\n]{8,})</\1\s*>",
    re.I,
)

# ----------------------------------------------------------------- detector 3
# `api_key: |` puts the value on the following lines. That is the ordinary shape of a
# Kubernetes Secret's stringData, a docker-compose config, and a PEM key in YAML.
YAML_BLOCK = re.compile(r"^(\s*)" + KEYWORD + r"\s*:\s*[|>][-+0-9]*\s*$", re.I)

# ------------------------------------------------------------------- filtering
PLACEHOLDER = re.compile(
    r"example|CHANGEME|your_|<your|placeholder|xxx|dummy|REPLACE|\.\.\."
    r"|redacted|\bfake\b|\bsample\b|\bTODO\b|notasecret"
    # Narrowly-identified doc examples: the runbooks deliberately show a hardcoded
    # key so a reviewer knows what one looks like.
    r"|sk-live-1234|eyJ\.token",
    re.I,
)

# A value that *is* a reference ships no secret. A value that merely CONTAINS a dollar
# sign is still a literal -- the original test was `[$]`, so a real key with a dollar
# in it was waved through. Anchor against the whole value instead.
REFERENCE = re.compile(
    r"""^(?:
          \$\{\{[^}]*\}\}                                 # ${{ secrets.X }}
        | \$\{[A-Za-z_][A-Za-z0-9_]*(?:[:\-=?+][^}]*)?\}  # ${VAR} ${VAR:-default}
        | \$[A-Za-z_][A-Za-z0-9_]*                        # $VAR
        | \$\([^)]*\)                                     # $(command)
        | \{\{[^}]*\}\}                                   # {{ template }}
        | %[A-Za-z_][A-Za-z0-9_]*%                        # %WINVAR%
        | <[^>]*>                                         # <placeholder>
      )$""",
    re.X,
)

# Reading a secret is not shipping one.
READS_ENV = re.compile(
    r"process\.env|os\.environ|os\.getenv|getenv|ENV\[|Deno\.env|System\.getenv"
    r"|config\.get|settings\.|vault|secretsmanager",
    re.I,
)

# token_uri, token_url, token_endpoint and issuer are PUBLIC endpoints and appear in
# every OIDC client config ever written. A credential embedded in a URL is caught by
# the connection-string pattern above, so a bare URL here is not a finding.
BARE_URL = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]{1,20}://[^\s]*$")

DOTTED = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+$")     # state.auth.accessToken


def entropy(s: str) -> float:
    n = len(s)
    if n == 0:
        return 0.0
    return -sum((c / n) * math.log2(c / n) for c in Counter(s).values())


def looks_like_a_name(v: str) -> bool:
    """True for RSA_PUBLIC_KEY_BYTES and accessToken; false for Xq7RtP2mV9Lw.

    The previous rule was 'identifier-shaped and no alphanumeric run over 12
    characters', which exempted every 12-character generated password -- the default
    length of most generators -- and anything with underscores in it, which is the
    shape of Django's own SECRET_KEY. A name is not defined by its length; it is made
    of words. So: split on separators and ask whether every piece is a word.
    """
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", v):
        return False
    segments = [s for s in re.split(r"[^A-Za-z0-9]+", v) if s]
    if not segments:
        return False
    for seg in segments:
        # camelCase counts as words joined without a separator.
        pieces = re.findall(r"[A-Z]+(?![a-z])|[A-Z][a-z]+|[a-z]+|[0-9]+", seg)
        if "".join(pieces) != seg:
            return False                      # letters and digits interleaved
        for piece in pieces:
            if piece.isdigit():
                if len(piece) > 4:            # a long digit run is not a word
                    return False
            elif not (2 <= len(piece) <= 14):
                return False
    return entropy(v) < 3.9


def is_secret(value: str, quoted: bool = False) -> bool:
    """True when the value looks like a credential rather than a name or expression."""
    v = value.strip().strip("`").strip().rstrip(".,;:")

    if len(v) < 8:
        return False
    if PLACEHOLDER.search(v) or REFERENCE.match(v) or READS_ENV.search(v):
        return False
    if BARE_URL.match(v):
        return False

    if not quoted:
        # An unquoted value comes from shell, dotenv or YAML, where a credential
        # cannot contain a space or a bracket without quoting. A QUOTED value can:
        # rejecting those outright was inverted with respect to risk, because
        # ? { } [ ] ( ) < > are exactly what a password generator's symbol set holds,
        # so the stronger the committed password the more certainly it was exempt.
        if re.search(r"\s", v) or re.search(r"[\[\]{}()<>?]", v):
            return False

    if looks_like_a_name(v):
        return False
    if DOTTED.match(v) and len(v) < 40:
        return False

    return entropy(v) >= 3.0


def _decode(raw: bytes) -> str | None:
    """Text of the file, or None when it is genuinely binary.

    A NUL in the first 8 KB used to mean 'binary, skip the file'. Every UTF-16 text
    file has a NUL in every second byte, and UTF-16LE is what PowerShell 5.1's
    Out-File and Notepad's 'Unicode' produce -- so a .ps1 or .env written on Windows
    was a fully readable file the scanner never opened, and the run still said clean.
    """
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        try:
            return raw.decode("utf-16")
        except UnicodeDecodeError:
            return None
    head = raw[:8192]
    if b"\x00" in head:
        # Unmarked UTF-16 puts a NUL beside roughly every other ASCII byte.
        if head.count(b"\x00") > len(head) * 0.25:
            for enc in ("utf-16-le", "utf-16-be"):
                try:
                    return raw.decode(enc)
                except UnicodeDecodeError:
                    continue
        return None                            # a real binary
    return raw.decode("utf-8", "ignore")


def _hits_in_line(line: str) -> list[str]:
    """Reasons this line looks like it carries a credential."""
    found = []

    for label, pattern in SELF_IDENTIFYING:
        m = pattern.search(line)
        if not m:
            continue
        # Group 1, when the pattern has one, is the credential itself; otherwise the
        # whole match identifies it.
        val = (m.group(1) if m.groups() else m.group(0)).strip()
        if PLACEHOLDER.search(line) or REFERENCE.match(val):
            continue
        # A captured value that is code rather than an opaque token: a call, a member
        # expression, anything with a space in it. These patterns are deliberately
        # loose about their surroundings, so this is where that looseness is paid for.
        if m.groups() and (re.search(r"[()\s]", val) or READS_ENV.search(val)):
            continue
        found.append(label)

    if found:
        return found

    if len(line) <= MAX_LINE_CHARS:
        # finditer, not search: a safe-looking first assignment used to hide a real
        # one later on the same line.
        for m in ASSIGNMENT.finditer(line):
            quoted = m.group("qv") is not None
            if is_secret(m.group("qv") or m.group("bv") or "", quoted=quoted):
                found.append("key-shaped literal")
                break
        if not found:
            for m in XML_ELEMENT.finditer(line):
                if is_secret(m.group(2), quoted=True):
                    found.append("credential in an XML element")
                    break

    return found


def _block_is_secret(joined: str) -> bool:
    if not joined or PLACEHOLDER.search(joined):
        return False
    if any(p.search(joined) for _, p in SELF_IDENTIFYING):
        return True
    return is_secret(joined, quoted=True)


def scan(root: str = ".") -> list[str]:
    """Return one "path:line: reason" string per suspected credential."""
    hits: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in sorted(filenames):
            if name.endswith(SKIP_SUFFIXES):
                continue
            path = os.path.join(dirpath, name)
            try:
                if os.path.getsize(path) > MAX_FILE_BYTES:
                    continue
                with open(path, "rb") as fh:
                    raw = fh.read()
            except OSError:
                continue

            text = _decode(raw)
            if text is None:
                continue

            rel = os.path.relpath(path, root).replace(os.sep, "/")

            in_block = False
            block_indent = 0
            block_parts: list[str] = []
            block_start = 0

            for i, line in enumerate(text.split("\n"), 1):
                if in_block:
                    indent = len(line) - len(line.lstrip())
                    if line.strip() and indent > block_indent:
                        block_parts.append(line.strip())
                        continue
                    if _block_is_secret(" ".join(block_parts)):
                        hits.append(
                            f"{rel}:{block_start}: block scalar value looks like a credential"
                        )
                    in_block = False
                    block_parts = []

                reasons = _hits_in_line(line)
                if reasons:
                    hits.append(f"{rel}:{i}: {reasons[0]}: {line.strip()[:100]}")

                if len(line) <= MAX_LINE_CHARS and YAML_BLOCK.match(line):
                    in_block = True
                    block_indent = len(line) - len(line.lstrip())
                    block_parts = []
                    block_start = i

            if in_block and _block_is_secret(" ".join(block_parts)):
                hits.append(
                    f"{rel}:{block_start}: block scalar value looks like a credential"
                )

    return sorted(set(hits))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="directory to scan (default: cwd)")
    args = ap.parse_args()

    hits = scan(args.root)
    for h in hits:
        print(f"::error::{h}")
    print(f"{len(hits)} suspicious literal(s)")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
