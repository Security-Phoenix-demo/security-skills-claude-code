#!/usr/bin/env python3
"""Cases for scripts/scan-secrets.py.

Four bypasses reached main because the scanner lived inline in a workflow file,
where nothing could run it. Each is a case below, and so is the thing that makes a
secret scanner useless in practice: shouting at the code that legitimately reads a
credential. A gate nobody trusts gets switched off.

    python3 scripts/test-scan-secrets.py

Exit 0 all pass, 1 on any failure.

The literal values here are assembled at run time from harmless halves. Written out
whole they would be real key-shaped literals in a tracked file, and scan-secrets.py
would — correctly — fail the build on its own test file.
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

K = "api_" + "key"
PASS = "pass" + "word"
TOK = "to" + "ken"

# (filename, file body, must the scanner flag it?)
CASES: list[tuple[str, str, bool]] = [
    # ---- the four bypasses Copilot found on PR #7 ---------------------------
    ("bypass_bare.sh", f"API_{K.upper()}={HEX16}\n", True),
    (
        "bypass_second_on_line.js",
        f'const cfg = {{ {K}: "your_placeholder", {PASS}: "{HEX16B}" }};\n',
        True,
    ),
    ("bypass_markdown.md", f'Run:\n\n    export SECRET_{TOK.upper()}="{GHP}"\n', True),
    ("bypass_dollar_in_value.py", f'{K} = "{DOLLAR}"\n', True),

    # ---- credentials that must not slip past --------------------------------
    ("aws.env.txt", f"AWS_SECRET_ACCESS_KEY={AWS}\n", True),
    ("google.env.txt", f"GOOGLE_API_KEY={GOOG}\n", True),
    ("jwt.json", f'{{"{TOK}": "{JWT}"}}\n', True),
    ("db.env.txt", f"DB_{PASS.upper()}={PW}\n", True),

    # ---- code that mentions a secret but ships none -------------------------
    ("read_env.js", f"const k = process.env.BRAVE_{K.upper()};\n", False),
    ("read_env.py", f'{K} = os.environ.get("BRAVE_{K.upper()}", "")\n', False),
    ("actions.yml", f"  {K}: ${{{{ secrets.BRAVE_KEY }}}}\n", False),
    ("shell_ref.sh", f"{PASS}=${{DB_PASS:-changeme}}\n{TOK}=$GITHUB_TOKEN\n", False),
    ("constant.py", f"{PASS[:-1]}d_bytes = RSA_PUBLIC_KEY_BYTES\n", False),
    ("member.js", f"const t = state.auth.access{TOK.capitalize()};\n", False),
    ("annotation.py", f"def f({K}: Optional[str] = None) -> list:\n    ...\n", False),
    ("placeholder.py", f'{PASS} = "your_{PASS}_here"\n{K} = "<your-key>"\n', False),
    ("template.md", f"Set `{K}: {{{{ YOUR_KEY }}}}` in the config.\n", False),
    ("exempt.env.example", f"API_{K.upper()}={HEX16}\n", False),  # narrowly exempt
]


def main() -> int:
    failures: list[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        for name, body, _ in CASES:
            (Path(tmp) / name).write_text(body, encoding="utf-8")

        flagged = {h.split(":", 1)[0] for h in scan_secrets.scan(tmp)}

        for name, body, should_flag in CASES:
            was = name in flagged
            if was is should_flag:
                print(f"  ok    {'catches' if should_flag else 'ignores':7} {name}")
            else:
                verb = "missed" if should_flag else "false positive on"
                failures.append(f"{verb} {name}: {body.strip().splitlines()[0][:70]}")
                print(f"  FAIL  {verb} {name}")

    # A binary blob must never be read as text and mined for matches.
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "archive.skill").write_bytes(b"PK\x03\x04\x00" + HEX16.encode() * 40)
        if scan_secrets.scan(tmp):
            failures.append("read a binary file as text")
            print("  FAIL  reads binary files")
        else:
            print("  ok    ignores  binary files")

    print()
    if failures:
        print(f"{len(failures)} failure(s):")
        for f in failures:
            print(f"  x {f}")
        return 1
    print(f"all {len(CASES) + 1} cases pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
