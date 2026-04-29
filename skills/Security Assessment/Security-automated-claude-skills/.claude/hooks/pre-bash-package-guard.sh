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
# Patterns we care about (and the ecosystem each implies)
declare -A PM_PATTERNS=(
  ["nodejs:npm"]='\bnpm[[:space:]]+(install|i|add)[[:space:]]+'
  ["nodejs:yarn"]='\byarn[[:space:]]+add[[:space:]]+'
  ["nodejs:pnpm"]='\bpnpm[[:space:]]+(install|add|i)[[:space:]]+'
  ["nodejs:bun"]='\bbun[[:space:]]+add[[:space:]]+'
  ["python:pip"]='\bpip3?[[:space:]]+install[[:space:]]+'
  ["python:uv"]='\buv[[:space:]]+add[[:space:]]+'
  ["python:poetry"]='\bpoetry[[:space:]]+add[[:space:]]+'
  ["python:pipenv"]='\bpipenv[[:space:]]+install[[:space:]]+'
  ["go:goget"]='\bgo[[:space:]]+get[[:space:]]+'
  ["rust:cargo"]='\bcargo[[:space:]]+add[[:space:]]+'
  ["ruby:gem"]='\bgem[[:space:]]+install[[:space:]]+'
  ["ruby:bundle"]='\bbundle[[:space:]]+add[[:space:]]+'
  ["php:composer"]='\bcomposer[[:space:]]+(require|install)[[:space:]]+'
  ["dotnet:add"]='\bdotnet[[:space:]]+add[[:space:]]+package[[:space:]]+'
)

ECO=""
PM=""
for key in "${!PM_PATTERNS[@]}"; do
  pat="${PM_PATTERNS[$key]}"
  if [[ "$CMD" =~ $pat ]]; then
    ECO="${key%%:*}"
    PM="${key##*:}"
    break
  fi
done

if [[ -z "$ECO" ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

log "package install detected: ecosystem=$ECO pm=$PM"

# ---- Extract package names from the command ----
# Strip the package-manager prefix and flags. This is heuristic; we err on the
# side of catching extra tokens (which then get filtered by the validity check).
TAIL="$(printf '%s' "$CMD" \
  | sed -E "s/.*${PM}[[:space:]]+(install|i|add|require|get|package)[[:space:]]+//" \
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
  local p="$1"
  # strip @scope/ prefix temporarily for distance check; keep for blocklist
  p="${p%@*}"           # strip @version (npm: react@18 -> react; scoped @scope/x stays)
  p="${p%[[<>=!~^]*}"   # strip pip/cargo specifiers like ==1.0
  p="${p%:*}"            # strip composer vendor:
  printf '%s' "$p"
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
