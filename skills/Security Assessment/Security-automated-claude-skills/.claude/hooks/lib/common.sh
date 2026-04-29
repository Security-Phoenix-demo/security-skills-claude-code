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

  printf '%s\n' "${found[@]}" | awk 'NF' | sort -u
}

# Tool availability
have() { command -v "$1" >/dev/null 2>&1; }

# JSON-encode a string for safe inclusion in JSON output.
# Uses python3 (always present on dev machines) — falls back to jq if not.
jsonenc() {
  if have python3; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
  elif have jq; then
    jq -Rs .
  else
    # last-resort manual encoding — escapes the bare minimum
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g' \
      | awk 'BEGIN{printf "\""} {printf "%s", $0} END{printf "\""}'
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
  local input="$1" path="$2"
  python3 -c "
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
}
