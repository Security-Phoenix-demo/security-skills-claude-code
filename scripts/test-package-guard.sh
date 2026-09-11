#!/usr/bin/env bash
# Cases for plugins/phoenix-security-review/hooks/pre-bash-package-guard.sh
#
# This hook had four bypasses fixed in #4/#5 and two more after review, and every
# one of them produced the same observable behaviour: permissionDecision "allow",
# emitted confidently, with nothing checked. There was no test, so the only way to
# notice was to read the pipeline carefully enough to see which tokens fell out of
# it. These cases assert on the decision, which is the part that matters.
#
#     bash scripts/test-package-guard.sh
#
# Exit 0 all pass, 1 on any failure.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/../plugins/phoenix-security-review/hooks/pre-bash-package-guard.sh"

if [ ! -f "$HOOK" ]; then
  echo "cannot find the hook at $HOOK" >&2
  exit 1
fi

STUB="$(mktemp -d)"
trap 'rm -rf "$STUB"' EXIT

# The guard asks registry.npmjs.org about brand-newness and install scripts. A test
# that needs the network is a test that fails on a plane, so a stub curl earlier in
# PATH makes every case hermetic -- and exercises exactly the path a user behind a
# firewall already gets.
printf '#!/bin/sh\nexit 1\n' > "$STUB/curl"
chmod +x "$STUB/curl"

# The hook shells out to `python3` by name. Windows ships a python3.exe App
# Execution Alias that `command -v` finds and that then refuses to run, so probe by
# running one rather than by looking one up.
PY3=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
    PY3="$c"
    break
  fi
done
if [ -z "$PY3" ]; then
  echo "a working python3 (or python) is required to run these cases" >&2
  exit 1
fi
if [ "$PY3" != "python3" ]; then
  printf '#!/bin/sh\nexec %s "$@"\n' "$PY3" > "$STUB/python3"
  chmod +x "$STUB/python3"
fi

PATH="$STUB:$PATH"
export PATH

decision() {
  "$PY3" -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1" \
    | bash "$HOOK" 2>/dev/null \
    | "$PY3" -c 'import json,sys
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])
except Exception:
    print("NO-JSON")'
}

FAILURES=0
check() {  # check <expected> <label> <command>
  want="$1"; label="$2"; cmd="$3"
  got="$(decision "$cmd")"
  if [ "$got" = "$want" ]; then
    printf '  ok    %-5s  %s\n' "$got" "$label"
  else
    printf '  FAIL  wanted %s, got %s -- %s\n' "$want" "$got" "$label"
    FAILURES=$((FAILURES + 1))
  fi
}

TAB="$(printf '\t')"

echo "the bypasses"
# Was allow: only literal spaces were split, so the whole tab-joined token failed
# the whitelist, PACKAGES came out empty, and nothing was checked -- including
# event-stream, which is on the hook's own built-in blocklist.
check deny  "tab-separated packages are still checked" \
            "npm install event-stream${TAB}lodash"
# Was allow: the whitelist rejected [ and ] so an extras spec emptied PACKAGES.
check deny  "pip extras cannot hide a blocklisted name" \
            "pip install colourama[socks]"
# Was allow: arguments that parsed to nothing were indistinguishable from having
# no arguments at all.
check ask   "unreadable arguments ask rather than allow" \
            'npm install pkg$(whoami)'

echo
echo "still denies what it always denied"
check deny  "a blocklisted npm package"      "npm install event-stream"
check deny  "a blocklisted pip package"      "pip install colourama"
check deny  "a blocklisted name among others" "npm install @types/node event-stream"
check deny  "pip3, not just pip"             "pip3 install colourama"
check deny  "a path-invoked package manager" "/usr/local/bin/npm install event-stream"

echo
echo "does not cry wolf"
check allow "an ordinary install"            "npm install lodash"
check allow "tab-separated safe packages"    "pip install requests${TAB}flask"
check allow "extras on a safe package"       "pip install requests[socks]"
check allow "install from a lockfile"        "npm install"
check allow "flags only"                     "npm install --production"
check allow "a requirements file"            "pip install -r requirements.txt"
check allow "not an install at all"          "ls -la /tmp"
check deny  "a quoted package name is read"  'npm install "event-stream"'
# Widening the whitelist to admit quotes without trimming them correctly put a NEW
# bypass in: bash reads the ' inside ${p%'} as opening a quoted region, so the
# single-quote trim was a no-op and `npm install 'event-stream'` returned allow.
# A shell removes quotes during word expansion, so all four of these reach npm as
# event-stream and all four must be checked as event-stream.
check deny  "single-quoted package name"     "npm install 'event-stream'"
check deny  "quotes in the middle of a name" "npm install 'event'-stream"
check deny  "a stray quote inside a name"    "npm install ev'ent-stream"
# The empty-PACKAGES ask was per-command, so one readable argument silently covered
# for every unreadable one beside it.
check ask   "an unreadable argument beside a readable one"             'npm install lodash pkg$(whoami)'

echo
echo "the detector over-matches on purpose"
# `npm install` inside a string is read as an install. That is deliberate and it is
# not new: the detector cannot tell `git commit -m "npm install fix"` from
# `sh -c "npm install evil"` without parsing the shell, and of the two mistakes
# available, treating a commit message as an install is the one you can live with.
# The words after it are checked as package names, so an ordinary sentence passes
# quietly and a sentence naming a blocklisted package does not.
check allow "an install mentioned inside a string"             "echo 'run npm install later'"
check deny  "...and a blocklisted name in one still denies"             "echo 'run npm install event-stream later'"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "all cases pass"
