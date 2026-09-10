#!/usr/bin/env bash
# .claude/hooks/pre-bash-package-guard.sh
#
# Runs before every Bash tool invocation. If the command is a package-manager
# install/add, the hook inspects each package: known-malicious lists,
# typosquat heuristics against popular packages, brand-newness (registry
# publish date < 7 days), and presence of postinstall scripts (npm).
#
# Output contract (PreToolUse):
#   {
#     "hookSpecificOutput": {
#       "hookEventName": "PreToolUse",
#       "permissionDecision": "allow" | "deny" | "ask",
#       "permissionDecisionReason": "..."
#     }
#   }
#
# Wire-up in .claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [
#         { "matcher": "Bash",
#           "hooks": [ { "type": "command", "command": ".claude/hooks/pre-bash-package-guard.sh" } ] }
#       ]
#     }
#   }

# This hook uses associative arrays, which need bash 4 or newer. macOS still ships bash 3.2,
# where `declare -A` silently misbehaves and the guard would fail open without saying so.
# Re-exec under a newer bash if one is installed; otherwise allow, and say why.
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash5 2>/dev/null)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      exec "$candidate" "$0" "$@"
    fi
  done
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"package guard skipped: needs bash 4+ (found '"${BASH_VERSION:-unknown}"'). Install a newer bash (brew install bash) to enable it."}}'
  exit 0
fi

. "$(dirname "$0")/lib/common.sh"

# Read tool input JSON from stdin
INPUT="$(cat)"
if [[ -z "$INPUT" ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

CMD="$(get_json_field "$INPUT" "tool_input.command")"
if [[ -z "$CMD" ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

# ---- Identify package-manager install commands ----
# Patterns we care about (and the ecosystem each implies).
#
# The leading (^|[^[:alnum:]_-]) is a portable word boundary. \b is a GNU regex
# extension: glibc implements it, BSD and macOS libc do not, and bash's =~ uses the
# system regex library. Every pattern here used \b, so on macOS none of them matched
# and this guard allowed every install without a word of warning. The class permits
# / and . before the command name so a path invocation (/usr/local/bin/npm install)
# still matches, while mynpm install does not.
# Only BASH_REMATCH[0] is read below, so the extra leading group is harmless.
declare -A PM_PATTERNS=(
  ["nodejs:npm"]='(^|[^[:alnum:]_-])npm[[:space:]]+(install|i|add)[[:space:]]+'
  ["nodejs:yarn"]='(^|[^[:alnum:]_-])yarn[[:space:]]+add[[:space:]]+'
  ["nodejs:pnpm"]='(^|[^[:alnum:]_-])pnpm[[:space:]]+(install|add|i)[[:space:]]+'
  ["nodejs:bun"]='(^|[^[:alnum:]_-])bun[[:space:]]+add[[:space:]]+'
  ["python:pip"]='(^|[^[:alnum:]_-])pip3?[[:space:]]+install[[:space:]]+'
  ["python:uv"]='(^|[^[:alnum:]_-])uv[[:space:]]+add[[:space:]]+'
  ["python:poetry"]='(^|[^[:alnum:]_-])poetry[[:space:]]+add[[:space:]]+'
  ["python:pipenv"]='(^|[^[:alnum:]_-])pipenv[[:space:]]+install[[:space:]]+'
  ["go:goget"]='(^|[^[:alnum:]_-])go[[:space:]]+get[[:space:]]+'
  ["rust:cargo"]='(^|[^[:alnum:]_-])cargo[[:space:]]+add[[:space:]]+'
  ["ruby:gem"]='(^|[^[:alnum:]_-])gem[[:space:]]+install[[:space:]]+'
  ["ruby:bundle"]='(^|[^[:alnum:]_-])bundle[[:space:]]+add[[:space:]]+'
  ["php:composer"]='(^|[^[:alnum:]_-])composer[[:space:]]+(require|install)[[:space:]]+'
  ["dotnet:add"]='(^|[^[:alnum:]_-])dotnet[[:space:]]+add[[:space:]]+package[[:space:]]+'
)

ECO=""
PM=""
PM_MATCH=""
for key in "${!PM_PATTERNS[@]}"; do
  pat="${PM_PATTERNS[$key]}"
  if [[ "$CMD" =~ $pat ]]; then
    ECO="${key%%:*}"
    PM="${key##*:}"
    # Keep the text the regex actually matched (e.g. "pip3 install ", "go get ").
    # Captured here, while BASH_REMATCH still belongs to this match — any later
    # =~ in this script would overwrite it.
    PM_MATCH="${BASH_REMATCH[0]}"
    break
  fi
done

if [[ -z "$ECO" ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

log "package install detected: ecosystem=$ECO pm=$PM"

# ---- Extract package names from the command ----
# Drop everything up to and including the matched "<pm> <subcommand> " prefix, then
# filter flags. Heuristic: we err on the side of catching extra tokens, which the
# validity check below then discards.
#
# This uses PM_MATCH — the exact substring the regex matched — rather than
# rebuilding the prefix from the pattern key. Rebuilding was wrong whenever the key
# is not the literal command text: key "python:pip" gives PM=pip, which never
# matches "pip3 install", and key "go:goget" gives PM=goget, which never matches
# "go get". In both cases nothing was stripped, so the command name itself leaked
# into the package list as a pseudo-package (pip3, go, get).
TAIL="$(printf '%s' "${CMD#*"$PM_MATCH"}" \
  | tr ' ' '\n' \
  | grep -E -v '^(-|--)' \
  | grep -E -v '^(install|add|i|--save|--save-dev|--dev|-D|-g|--global)$' \
  | grep -E '^[a-zA-Z0-9@._/+:~^=<>-]+$' \
  | head -20)"

PACKAGES=()
while IFS= read -r p; do
  [[ -n "$p" ]] && PACKAGES+=("$p")
done <<< "$TAIL"

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

# ---- Known-malicious / typosquat lists (project-local) ----
# A user can extend this file at .claude/security/blocklist.txt with one
# package per line, scoped by ecosystem prefix:
#   nodejs:eslint-config-airbnb-typo
#   python:requesst
ROOT="$(project_root)"
BLOCKLIST="$ROOT/.claude/security/blocklist.txt"

# Built-in floor: a small set of long-publicised malicious packages and
# common typosquats. The user should expand this in their own blocklist.
BUILTIN_BLOCK='
nodejs:event-stream
nodejs:flatmap-stream
nodejs:rc.js
nodejs:colors-2
nodejs:eslint-scope-redactor
python:colourama
python:requesst
python:python-mysql
python:pythn
python:urllib
python:numpyy
ruby:rest-client-2
'

# ---- Heuristic checks per package ----
DENY_REASONS=()
ASK_REASONS=()

# Popular package names per ecosystem for typosquat distance check.
# Edit-distance 1–2 against these names => suspicious (ask).
NPM_POPULAR='react vue angular express lodash axios moment chalk debug commander request webpack typescript jquery underscore async'
PYPI_POPULAR='requests numpy pandas flask django pytest pillow scipy matplotlib pyyaml urllib3 setuptools wheel boto3 cryptography'

# Levenshtein distance via python3
lev() {
  python3 -c '
import sys
a,b=sys.argv[1],sys.argv[2]
m,n=len(a),len(b)
if abs(m-n)>3:print(99);sys.exit()
dp=list(range(n+1))
for i in range(1,m+1):
  prev=dp[0]; dp[0]=i
  for j in range(1,n+1):
    cur=dp[j]
    if a[i-1]==b[j-1]: dp[j]=prev
    else: dp[j]=1+min(prev,dp[j-1],dp[j])
    prev=cur
print(dp[n])
' "$1" "$2"
}

# Strip version specifiers and scope prefix for matching
clean_pkg() {
  local p="$1" scope="" stripped

  # Detach the @scope/ prefix of a scoped npm package before touching versions.
  # Without this, the leading @ of an unversioned "@types/node" is read as the
  # version separator, ${p%@*} returns the empty string, and the caller's
  # `[[ -z "$cleaned" ]] && continue` drops the package before any check runs —
  # a silent bypass of the blocklist, typosquat, brand-new and install-script
  # checks. Reattached before returning, because the blocklist is keyed on the
  # full scoped name.
  if [[ "$p" == @*/* ]]; then
    scope="${p%%/*}/"
    p="${p#*/}"
  fi

  # Strip @version (react@18 -> react). Never let this blank the name: a token
  # that is nothing but a version separator is malformed, and a malformed token
  # must reach the checks rather than vanish.
  stripped="${p%@*}"
  [[ -n "$stripped" ]] && p="$stripped"

  # Strip pip/cargo specifiers (requests==2.0 -> requests). %% not %: the shortest
  # match leaves the first operator behind ("requesst==2.0" -> "requesst="), which
  # no longer equals the blocklist key, so pinning a version downgraded a block to
  # a prompt.
  p="${p%%[[<>=!~^]*}"

  p="${p%:*}"            # strip composer vendor: suffix
  printf '%s' "$scope$p"
}

is_blocklisted() {
  local fullkey="$1:$2"
  if [[ -f "$BLOCKLIST" ]] && grep -qx -F -- "$fullkey" "$BLOCKLIST"; then
    return 0
  fi
  printf '%s\n' "$BUILTIN_BLOCK" | grep -qx -F -- "$fullkey" && return 0
  return 1
}

# Brand-newness check (npm only — fastest registry)
npm_publish_age_days() {
  local pkg="$1"
  if ! have curl || ! have python3; then echo ""; return; fi
  local resp
  resp="$(curl -fsSL --max-time 5 "https://registry.npmjs.org/$pkg" 2>/dev/null || true)"
  [[ -z "$resp" ]] && return
  python3 -c '
import json,sys,datetime
d=json.loads(sys.argv[1])
t=d.get("time",{})
created=t.get("created")
if not created: sys.exit()
dt=datetime.datetime.fromisoformat(created.replace("Z","+00:00"))
age=(datetime.datetime.now(datetime.timezone.utc)-dt).days
print(age)
' "$resp" 2>/dev/null
}

npm_has_install_scripts() {
  local pkg="$1"
  if ! have curl || ! have python3; then echo "0"; return; fi
  local resp
  resp="$(curl -fsSL --max-time 5 "https://registry.npmjs.org/$pkg/latest" 2>/dev/null || true)"
  [[ -z "$resp" ]] && { echo "0"; return; }
  python3 -c '
import json,sys
d=json.loads(sys.argv[1])
s=d.get("scripts",{}) or {}
hooks=[k for k in ("preinstall","install","postinstall") if k in s]
print(",".join(hooks) if hooks else "0")
' "$resp" 2>/dev/null
}

for pkg in "${PACKAGES[@]}"; do
  cleaned="$(clean_pkg "$pkg")"
  [[ -z "$cleaned" ]] && continue

  # 1. blocklist
  if is_blocklisted "$ECO" "$cleaned"; then
    DENY_REASONS+=("Package '$cleaned' ($ECO) is on the malicious/typosquat blocklist.")
    continue
  fi

  # 2. typosquat distance
  case "$ECO" in
    nodejs) POPULAR="$NPM_POPULAR" ;;
    python) POPULAR="$PYPI_POPULAR" ;;
    *)      POPULAR="" ;;
  esac
  if [[ -n "$POPULAR" ]] && have python3; then
    bare="${cleaned##@*/}"
    for popular in $POPULAR; do
      [[ "$bare" == "$popular" ]] && continue
      d=$(lev "$bare" "$popular")
      if [[ "$d" =~ ^[0-9]+$ ]] && (( d > 0 )) && (( d <= 2 )) && (( ${#bare} >= 4 )); then
        ASK_REASONS+=("Package '$cleaned' is edit-distance $d from popular package '$popular' — possible typosquat.")
        break
      fi
    done
  fi

  # 3. brand-newness (npm only — keeps the hook fast)
  if [[ "$ECO" == "nodejs" ]]; then
    age=$(npm_publish_age_days "$cleaned")
    if [[ "$age" =~ ^[0-9]+$ ]] && (( age < 7 )); then
      ASK_REASONS+=("Package '$cleaned' was first published $age day(s) ago — unusually new for production use.")
    fi

    # 4. install scripts
    scripts=$(npm_has_install_scripts "$cleaned")
    if [[ -n "$scripts" && "$scripts" != "0" ]]; then
      ASK_REASONS+=("Package '$cleaned' declares install scripts: $scripts — these run on \`npm install\`. Review before proceeding.")
    fi
  fi
done

# ---- Decision ----
if (( ${#DENY_REASONS[@]} > 0 )); then
  reason='Blocked by security-reviewer pre-install guard:'$'\n'
  for r in "${DENY_REASONS[@]}"; do reason+='- '"$r"$'\n'; done
  log "DENY: ${DENY_REASONS[*]}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$reason" | jsonenc)"
  exit 0
fi

if (( ${#ASK_REASONS[@]} > 0 )); then
  reason='security-reviewer flagged this install for review:'$'\n'
  for r in "${ASK_REASONS[@]}"; do reason+='- '"$r"$'\n'; done
  reason+=$'\nProceed only if these packages are intentional and trusted.'
  log "ASK: ${ASK_REASONS[*]}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$reason" | jsonenc)"
  exit 0
fi

emit_json PreToolUse permissionDecision '"allow"'
exit 0
