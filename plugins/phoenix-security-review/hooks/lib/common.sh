#!/usr/bin/env bash
# .claude/hooks/lib/common.sh
#
# Shared helpers for the security-reviewer hooks.
# Source this from each hook: . "$(dirname "$0")/lib/common.sh"
#
# All hooks emit JSON on stdout that conforms to Claude Code's hook contract:
#   { "hookSpecificOutput": { "hookEventName": "...", ... } }
#
# Plus they write human-readable progress to stderr (visible in Claude Code's
# transcript-mode log but not injected into the model context).

set -uo pipefail

# Project root — try git first, fall back to CWD
project_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Detect ecosystems by manifest presence. Prints one ecosystem per line.
detect_ecosystems() {
  local root; root="$(project_root)"
  local found=()

  [[ -f "$root/package.json" ]]       && found+=("nodejs")
  [[ -f "$root/pyproject.toml" ]] || [[ -f "$root/requirements.txt" ]] || [[ -f "$root/Pipfile" ]] || [[ -f "$root/setup.py" ]] && found+=("python")
  [[ -f "$root/go.mod" ]]             && found+=("go")
  [[ -f "$root/Cargo.toml" ]]         && found+=("rust")
  [[ -f "$root/pom.xml" ]] || ls "$root"/build.gradle* >/dev/null 2>&1 && found+=("java")
  [[ -f "$root/Gemfile" ]]            && found+=("ruby")
  ls "$root"/*.csproj >/dev/null 2>&1 || ls "$root"/*.sln >/dev/null 2>&1 && found+=("dotnet")
  [[ -f "$root/composer.json" ]]      && found+=("php")

  # bash 3.2 (macOS default) errors on "${arr[@]}" when arr is empty and set -u is on.
  printf '%s\n' ${found[@]+"${found[@]}"} | awk 'NF' | sort -u
}

# Tool availability
have() { command -v "$1" >/dev/null 2>&1; }

# A WORKING python, resolved once. Probing with have() is not enough and that is the
# whole point of this function: macOS ships a /usr/bin/python3 stub that exists and
# exits non-zero until the Xcode tools are installed, and Windows puts a python3.exe
# App Execution Alias on PATH that prints an advert to stdout instead of running.
# Both satisfy `command -v`. Neither can parse JSON.
#
# Echoes the interpreter name, or nothing when there is no working one.
_PY_RESOLVED=""
py_interp() {
  if [[ -n "$_PY_RESOLVED" ]]; then
    [[ "$_PY_RESOLVED" == "none" ]] && return 1
    printf '%s' "$_PY_RESOLVED"
    return 0
  fi
  local c
  for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json' >/dev/null 2>&1; then
      _PY_RESOLVED="$c"
      printf '%s' "$c"
      return 0
    fi
  done
  _PY_RESOLVED="none"
  return 1
}

# Can anything here parse JSON at all? Callers whose decision depends on reading the
# tool input MUST check this and say so when it is false, rather than treating an
# unparsed payload as an empty one. An empty payload reads as "nothing to check",
# which is how a guard comes to approve an install it never looked at.
# jq is probed by RUNNING it, for the same reason py_interp is. Checking `have jq`
# alone repeated the exact error this file was changed to remove: a jq on PATH that
# cannot run satisfied the check, get_json_field then fell to the jq branch, jq
# failed, the field came back empty, and the caller read that as "no command" and
# allowed. Existence is not function; that distinction is the whole point here.
jq_works() { have jq && printf '{}' | jq -e . >/dev/null 2>&1; }

json_parser_available() { py_interp >/dev/null || jq_works; }

# JSON-encode a string for safe inclusion in JSON output.
jsonenc() {
  local py
  if py="$(py_interp)"; then
    "$py" -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
  elif jq_works; then
    jq -Rs .
  else
    # Last-resort encoder. The previous version ran its s/// commands in sed's first
    # cycle and only then slurped the remaining lines with :a;N;$!ba, so every
    # backslash and double quote after line 1 reached the output unescaped and the
    # hook response was invalid JSON -- which Claude Code drops silently, taking the
    # entire injected context with it. awk escapes each line before joining, so the
    # order cannot be got wrong. Control characters other than tab and CR are left
    # as-is; this path is a fallback for a host with neither python nor jq.
    awk '
      BEGIN { ORS = ""; printf "\"" }
      {
        s = $0
        gsub(/\\/, "\\\\", s)
        gsub(/"/,  "\\\"", s)
        gsub(/\t/, "\\t",  s)
        gsub(/\r/, "\\r",  s)
        if (NR > 1) printf "\\n"
        printf "%s", s
      }
      END { printf "\"" }'
  fi
}

# Emit a JSON hook response. $1 = hookEventName, $2 = key, $3 = value (already JSON-encoded).
emit_json() {
  local event="$1" key="$2" value="$3"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","%s":%s}}\n' "$event" "$key" "$value"
}

# Log to stderr (won't pollute the JSON channel)
log() {
  printf '[security-reviewer] %s\n' "$*" >&2
}

# Cache directory under the project (gitignored by convention)
cache_dir() {
  local root; root="$(project_root)"
  local d="$root/.claude/.cache/security-reviewer"
  mkdir -p "$d"
  printf '%s' "$d"
}

# Read stdin into a variable, safely (handles empty input)
read_stdin() {
  if [[ -t 0 ]]; then
    printf ''
  else
    cat
  fi
}

# Extract a JSON field from stdin payload using python3 (most portable).
# Usage: get_json_field <input> <jq-style.path>   (dotted path only, no arrays)
get_json_field() {
  local input="$1" path="$2" py
  if py="$(py_interp)"; then
    "$py" -c "
import json,sys
try:
    d = json.loads(sys.argv[1])
    for p in sys.argv[2].split('.'):
        if p == '': continue
        d = d.get(p) if isinstance(d, dict) else None
        if d is None: break
    print(d if d is not None else '')
except Exception:
    pass
" "$input" "$path" 2>/dev/null
  elif jq_works; then
    # Dotted path only, matching the python branch. // empty keeps a missing key
    # printing nothing rather than the string "null".
    printf '%s' "$input" | jq -r --arg p "$path" 'getpath($p | split(".")) // empty' 2>/dev/null
  else
    # No parser. Print nothing -- and note that callers must not read that as "the
    # field was absent". json_parser_available() exists so they can tell the two
    # apart, because treating them as the same is what let an unchecked install
    # through.
    printf ''
  fi
}
