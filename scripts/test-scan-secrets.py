#!/usr/bin/env python3
"""Cases for scripts/scan-secrets.py.

Four bypasses reached main because the scanner lived inline in a workflow file,
where nothing could run it. Each is a case below. So is every shape a later audit
found the keyword=value model could not see at all -- a PEM body, a connection
string, an XML element, a YAML block scalar, a UTF-16 file -- and so is the thing
that makes a secret scanner useless in practice: shouting at the code that
legitimately reads a credential. A gate nobody trusts gets switched off.

    python3 scripts/test-scan-secrets.py

Exit 0 all pass, 1 on any failure.

The literal values here are assembled at run time from harmless halves. Written out
whole they would be real credentials in a tracked file, and scan-secrets.py would --
correctly -- fail the build on its own test file.
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

_spec = importlib.util.spec_from_file_location("scan_secrets", HERE / "scan-secrets.py")
scan_secrets = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(scan_secrets)

HEX16 = "0123456789" + "abcdef"
HEX16B = "a9f3c2e8" + "b1d74506"
GHP = "ghp_16C7e42F292c" + "6912E7710c838347Ae178B4a"
GOOG = "AIzaSyD-9tSrke72Pou" + "QMnMX-a7eZSW0jkFMBWY"
JWT = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJzdWIiOiIxMjM0NTY3ODkwIn0."
    "dozjgNryP4J3jVmNHl0w5N9XgL0n3I9PlFUP0THsR8U"
)
AWS = "wJalrXUtnFEMI/K7MDENG/" + "bPxRfiCY7uZq9Kd3N"
DOLLAR = "pre$fix" + "9c2b41xz"
PW = "h7Kq2mNp" + "9vRt4xZw"

# Shapes the keyword=value model could not see at all. Split the same way: written
# whole they would be real credentials in a tracked file.
AWSID = "AKIA" + "J7Q2XR4TLM9BVZ3D"
SLACK = "xox" + "b-2468013579-1357924680-aZ9bY8cX7dW6eV5f"
STRIPE = "sk_" + "live_51H8xQ2eZvKYlo2C0abcd"
GLPAT = "glpat-" + "x9Kd3Nq7RtP2mV8Lw1Zy"
NPMTOK = "npm_" + "aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bD1fH3jL5"
PEMHDR = "-----BEGIN " + "PRIVATE KEY" + "-----"
PW12 = "Xq7Rt" + "P2mV9Lw"
DJANGO = "django_insecure_" + "k3x9_prod_2024_aQ"
SYMPW = "Tr0ub4dour" + "&3-horse!Zz"
NODIGIT = "zXcVbNmAs" + "DfGhJkLqWeRtY"

K = "api_" + "key"
PASS = "pass" + "word"
TOK = "to" + "ken"

NL = chr(10)

# (filename, file body, must the scanner flag it?)
CASES: list[tuple[str, object, bool]] = [
    # ---- the four bypasses Copilot found on PR #7 ---------------------------
    ("bypass_bare.sh", f"API_{K.upper()}={HEX16}{NL}", True),
    (
        "bypass_second_on_line.js",
        f'const cfg = {{ {K}: "your_placeholder", {PASS}: "{HEX16B}" }};{NL}',
        True,
    ),
    ("bypass_markdown.md", f'Run:{NL}{NL}    export SECRET_{TOK.upper()}="{GHP}"{NL}', True),
    ("bypass_dollar_in_value.py", f'{K} = "{DOLLAR}"{NL}', True),

    # ---- credentials that must not slip past --------------------------------
    ("aws.env.txt", f"AWS_SECRET_ACCESS_KEY={AWS}{NL}", True),
    ("google.env.txt", f"GOOGLE_API_KEY={GOOG}{NL}", True),
    ("jwt.json", f'{{"{TOK}": "{JWT}"}}{NL}', True),
    ("db.env.txt", f"DB_{PASS.upper()}={PW}{NL}", True),

    # ---- shapes the keyword=value model could not see at all ----------------
    # A PEM body carries no keyword on any line, so the key material was never
    # examined; and written as an assignment the header's spaces made is_secret()
    # class it "an expression, not a token" and drop it.
    ("id_rsa", f"{PEMHDR}{NL}MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7{NL}", True),
    ("firebase.env.txt", "GOOGLE_PRIVATE_" + 'KEY="' + PEMHDR + 'MIIEvQIBADANBgkq"' + NL, True),
    # A credential inside a URL has no name of its own.
    ("db.url.env.txt", "DATABASE_URL=postgres://appuser:" + PW12 + "@db.internal:5432/prod" + NL, True),
    # `passwd` was in the keyword list; `pwd`, which is what ODBC uses, was not.
    ("odbc.ini", f"Driver={{SQL Server}};Server=db;Pwd={PW12};{NL}", True),
    # An XML element has no [:=] after the name, so a Maven settings.xml never matched.
    ("settings.xml", f"  <server>{NL}    <{PASS}>{PW12}3Kd</{PASS}>{NL}  </server>{NL}", True),
    ("dot_npmrc", "//registry.npmjs.org/:_auth" + "Token=" + NPMTOK + NL, True),
    # The value sits on the following line, where no keyword reaches it.
    ("k8s-secret.yaml", f"stringData:{NL}  {K}: |{NL}    {NPMTOK}{NL}", True),

    # ---- vendor token shapes -------------------------------------------------
    ("aws_id.env.txt", f"AWS_ACCESS_KEY_ID={AWSID}{NL}", True),
    ("slack.env.txt", f"SLACK_BOT_{TOK.upper()}={SLACK}{NL}", True),
    ("stripe.env.txt", f"STRIPE_{K.upper()}={STRIPE}{NL}", True),
    ("gitlab.env.txt", f"CI_JOB_{TOK.upper()}={GLPAT}{NL}", True),
    ("npm.env.txt", f"NPM_{TOK.upper()}={NPMTOK}{NL}", True),

    # ---- passwords the value filters were inverted against -------------------
    # 12 alphanumerics is the default length of most generators, and the old
    # "longest run <= 12" name test exempted exactly that.
    ("gen12.env.txt", f"DB_{PASS.upper()}={PW12}{NL}", True),
    # Underscores defeated the same test at any length -- this is Django's own shape.
    ("django.py", "SECRET_" + 'KEY = "' + DJANGO + '"' + NL, True),
    # Symbols are what a generator's symbol set contains, so rejecting them made the
    # filter stronger against weak passwords than against strong ones.
    ("symbols.env.txt", f'{PASS.upper()}="{SYMPW}"{NL}', True),
    # A hand-typed signing secret need not contain a digit.
    ("nodigit.env.txt", f"JWT_SECRET={NODIGIT}{NL}", True),

    # ---- encodings -----------------------------------------------------------
    # UTF-16 is what PowerShell 5.1's Out-File and Notepad's "Unicode" produce. Every
    # second byte is a NUL, so the binary heuristic skipped the whole file and the run
    # still printed "0 suspicious literal(s)" and exited 0.
    ("utf16.env.txt", ("API_" + "KEY=" + HEX16 + NL).encode("utf-16"), True),

    # ---- code that mentions a secret but ships none -------------------------
    ("read_env.js", f"const k = process.env.BRAVE_{K.upper()};{NL}", False),
    ("read_env.py", f'{K} = os.environ.get("BRAVE_{K.upper()}", ""){NL}', False),
    ("actions.yml", f"  {K}: ${{{{ secrets.BRAVE_KEY }}}}{NL}", False),
    ("shell_ref.sh", f"{PASS}=${{DB_PASS:-changeme}}{NL}{TOK}=$GITHUB_TOKEN{NL}", False),
    ("constant.py", f"{PASS[:-1]}d_bytes = RSA_PUBLIC_KEY_BYTES{NL}", False),
    ("member.js", f"const t = state.auth.access{TOK.capitalize()};{NL}", False),
    ("annotation.py", f"def f({K}: Optional[str] = None) -> list:{NL}    ...{NL}", False),
    ("placeholder.py", f'{PASS} = "your_{PASS}_here"{NL}{K} = "<your-key>"{NL}', False),
    ("template.md", f"Set `{K}: {{{{ YOUR_KEY }}}}` in the config.{NL}", False),
    ("exempt.env.example", f"API_{K.upper()}={HEX16}{NL}", False),  # narrowly exempt

    # ---- public endpoints, which are not credentials -------------------------
    # token_uri and token_endpoint are required fields of every OIDC client config
    # ever written, and the keyword's suffix group matches all of them.
    ("oidc.json", f'  "token_uri": "https://oauth2.googleapis.com/token",{NL}', False),
    (
        "wellknown.json",
        f'  "token_endpoint": "https://login.microsoftonline.com/common/oauth2/v2.0/token"{NL}',
        False,
    ),
    ("issuer.yml", f"  auth_url: https://accounts.google.com/o/oauth2/auth{NL}", False),
]


def main() -> int:
    failures: list[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        for name, body, _ in CASES:
            target = Path(tmp) / name
            if isinstance(body, bytes):
                target.write_bytes(body)
            else:
                target.write_text(body, encoding="utf-8")

        flagged = {h.split(":", 1)[0] for h in scan_secrets.scan(tmp)}

        for name, body, should_flag in CASES:
            was = name in flagged
            if was is should_flag:
                print(f"  ok    {'catches' if should_flag else 'ignores':7} {name}")
            else:
                verb = "missed" if should_flag else "false positive on"
                shown = body.decode("utf-16", "ignore") if isinstance(body, bytes) else body
                first = shown.strip().splitlines()[0] if shown.strip() else ""
                failures.append(f"{verb} {name}: {first[:70]}")
                print(f"  FAIL  {verb} {name}")

    # A binary blob must never be read as text and mined for matches.
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "archive.skill").write_bytes(b"PK\x03\x04\x00" + HEX16.encode() * 40)
        if scan_secrets.scan(tmp):
            failures.append("read a binary file as text")
            print("  FAIL  reads binary files")
        else:
            print("  ok    ignores  binary files")

    # One 80 KB line of hex used to take 76 seconds: the keyword's unbounded prefix
    # backtracked over every length of every alphanumeric run. A CI step that hangs is
    # a CI step someone deletes.
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "blob.txt").write_text("data = " + ("a1b2c3d4" * 10_000) + NL, encoding="utf-8")
        import time

        t0 = time.monotonic()
        scan_secrets.scan(tmp)
        elapsed = time.monotonic() - t0
        if elapsed > 5.0:
            failures.append(f"an 80 KB line took {elapsed:.1f}s")
            print(f"  FAIL  80 KB line took {elapsed:.1f}s")
        else:
            print(f"  ok    bounded  80 KB line scanned in {elapsed:.2f}s")

    print()
    if failures:
        print(f"{len(failures)} failure(s):")
        for f in failures:
            print(f"  x {f}")
        return 1
    print(f"all {len(CASES) + 2} cases pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
