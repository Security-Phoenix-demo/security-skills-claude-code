#!/usr/bin/env python3
"""Fail the build on a credential committed to the tree.

This lived inline in .github/workflows/validate.yml, where it could not be run
without pushing and could not be tested at all. Four bypasses shipped that way:

    a bare, unquoted assignment      quoting was required, so a bare value passed
    two assignments on one line      only the first match on a line was examined
    a key pasted into a README       .md was excluded wholesale
    a value containing a dollar      any `$` at all counted as interpolation

Each one is a case in scripts/test-scan-secrets.py now.

The hard part is not finding `password=`; it is not shouting at the thousand lines
of code that legitimately mention one. The rule is that a credential is an opaque
high-entropy token, while code that reads a secret is a name or an expression:

    process.env.BRAVE_API_KEY   reads a secret, ships none
    RSA_PUBLIC_KEY_BYTES        a constant's name
    state.auth.accessToken      a member expression
    ${{ secrets.BRAVE_KEY }}    a reference resolved at run time

Stdlib only, so it runs anywhere with python3 and no install step.

    python3 scripts/scan-secrets.py            # from the repo root
    python3 scripts/scan-secrets.py --root .   # explicitly

Exit 0 clean, 1 if anything looks like a committed credential.
"""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
from collections import Counter

# The keyword may sit inside a longer name — AWS_SECRET_ACCESS_KEY= is the
# most-committed secret there is, and requiring the keyword to touch the `=` missed
# every compound name. A separator is required on both sides, so `tokenizer =` and
# `tokens =` still do not match.
KEY = (
    r"(?:[A-Za-z0-9]+[_.-])*"
    r"(?:api[_-]?key|secret|password|passwd|token|private[_-]?key)"
    r"(?:[_.-][A-Za-z0-9]+)*"
)

# The value may be quoted OR bare. A bare assignment ships a credential just as
# thoroughly as a quoted one; requiring quotes skipped every shell-style and
# dotenv-style line in the tree.
ASSIGNMENT = re.compile(
    # The `["']?` closes a JSON key: {"token": "..."} puts a quote between the name
    # and the colon, which is how a credential in a .json config went unread.
    KEY + r"""["']?\s*[:=]\s*"""
    r"""(?:(?P<q>["'])(?P<qv>[^"']{12,})(?P=q)|(?P<bv>[^\s"'`,;)]{12,}))""",
    re.I,
)

PLACEHOLDER = re.compile(
    r"example|CHANGEME|your_|<your|placeholder|xxx|dummy|REPLACE|\.\.\."
    r"|redacted|\bfake\b|\bsample\b|\bTODO\b"
    # Narrowly-identified doc examples: the runbooks deliberately show a hardcoded
    # key so a reviewer knows what one looks like.
    r"|sk-live-1234|eyJ\.token",
    re.I,
)

# A value that *is* a reference ships no secret. A value that merely CONTAINS a
# dollar sign is still a literal — the old test was `[$]`, so a real key with a
# dollar in it was waved through. Anchor against the whole value instead.
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
    r"process\.env|os\.environ|os\.getenv|getenv|ENV\[|Deno\.env|System\.getenv",
    re.I,
)

NAME_SHAPED = re.compile(r"[A-Za-z_][A-Za-z0-9_]*$")            # RSA_PUBLIC_KEY_BYTES
DOTTED = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+$")        # state.auth.token2

SKIP_DIRS = {".git", "node_modules", ".venv", "__pycache__"}

# Only narrowly-identified example files are exempt. Markdown is NOT: a key pasted
# into a README is committed exactly like one in a script, and PLACEHOLDER above is
# what keeps real documentation quiet.
SKIP_SUFFIXES = (".example", ".example.json")


def entropy(s: str) -> float:
    n = len(s)
    return -sum((c / n) * math.log2(c / n) for c in Counter(s).values())


def is_secret(value: str) -> bool:
    """True when the value looks like a credential rather than a name or expression."""
    v = value.strip().strip("`").strip().rstrip(".,;:")

    if len(v) < 12 or PLACEHOLDER.search(v) or REFERENCE.match(v) or READS_ENV.search(v):
        return False
    if re.search(r"\s", v) or re.search(r"[\[\]{}()<>?]", v):
        return False                       # an expression, not a token
    if not re.search(r"\d", v):
        return False                       # RSA_PUBLIC_KEY_BYTES, accessToken, prose

    # A constant or variable name is short words joined by separators; a key is one
    # long opaque run. ghp_16C7e42F292c6912E7710c838347Ae178B4a is not a name just
    # because it happens to contain an underscore.
    longest_run = max((len(r) for r in re.split(r"[^A-Za-z0-9]+", v) if r), default=0)
    if NAME_SHAPED.match(v) and longest_run <= 12:
        return False
    if DOTTED.match(v) and len(v) < 40:
        return False

    return entropy(v) >= 3.0


def scan(root: str = ".") -> list[str]:
    """Return one "path:line: text" string per suspected credential."""
    hits: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in sorted(filenames):
            if name.endswith(SKIP_SUFFIXES):
                continue
            path = os.path.join(dirpath, name)
            try:
                raw = open(path, "rb").read()
            except OSError:
                continue
            if b"\x00" in raw[:8192]:      # a zip or an image, not source
                continue
            for i, line in enumerate(raw.decode("utf-8", "ignore").split("\n"), 1):
                # finditer, not search: a safe-looking first assignment used to hide
                # a real one later on the same line.
                for m in ASSIGNMENT.finditer(line):
                    if is_secret(m.group("qv") or m.group("bv") or ""):
                        rel = os.path.relpath(path, root).replace(os.sep, "/")
                        hits.append(f"{rel}:{i}: {line.strip()[:100]}")
                        break
    return sorted(hits)


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
