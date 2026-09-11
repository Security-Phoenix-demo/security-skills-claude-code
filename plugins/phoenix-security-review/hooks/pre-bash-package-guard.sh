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

# Without a JSON parser this hook cannot read the command it exists to inspect, and an
# unreadable command is not the same thing as an absent one. get_json_field used to call
# python3 by name and swallow its stderr, so on a host without a working python3 -- stock
# macOS, a slim container, or Windows where python3 is an App Execution Alias that prints
# an advert -- CMD came back empty, the next branch read that as "not an install", and
# every install of every blocklisted package was approved in total silence.
#
# Still allow, because a PreToolUse hook that denies everything makes the session
# unusable, but never again without saying why. This mirrors the bash-3.2 preamble above.
if ! json_parser_available; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"package guard skipped: no working python3 or jq on PATH, so the command could not be read and no package was checked against the blocklist. Install python3 or jq to enable it."}}'
  exit 0
fi

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
# A global flag may sit between the program and its subcommand. npm's parser accepts
# `npm --prefix . install event-stream`, and pip, yarn, cargo and dotnet are similar.
# Requiring the subcommand to touch the program name meant such a command matched no
# pattern at all, ECO stayed empty, and the guard allowed it without a word -- on the
# wire indistinguishable from a command it had examined and cleared. This fragment
# absorbs flag tokens and an optional value for each.
OPTS='([[:space:]]+-{1,2}[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'

declare -A PM_PATTERNS=(
  ["nodejs:npm"]='(^|[^[:alnum:]_-])npm'"$OPTS"'[[:space:]]+(install|i|add)[[:space:]]+'
  ["nodejs:yarn"]='(^|[^[:alnum:]_-])yarn'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["nodejs:pnpm"]='(^|[^[:alnum:]_-])pnpm'"$OPTS"'[[:space:]]+(install|add|i)[[:space:]]+'
  ["nodejs:bun"]='(^|[^[:alnum:]_-])bun'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["python:pip"]='(^|[^[:alnum:]_-])pip3?'"$OPTS"'[[:space:]]+install[[:space:]]+'
  ["python:uv"]='(^|[^[:alnum:]_-])uv'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["python:poetry"]='(^|[^[:alnum:]_-])poetry'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["python:pipenv"]='(^|[^[:alnum:]_-])pipenv'"$OPTS"'[[:space:]]+install[[:space:]]+'
  ["go:goget"]='(^|[^[:alnum:]_-])go'"$OPTS"'[[:space:]]+get[[:space:]]+'
  ["rust:cargo"]='(^|[^[:alnum:]_-])cargo'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["ruby:gem"]='(^|[^[:alnum:]_-])gem'"$OPTS"'[[:space:]]+install[[:space:]]+'
  ["ruby:bundle"]='(^|[^[:alnum:]_-])bundle'"$OPTS"'[[:space:]]+add[[:space:]]+'
  ["php:composer"]='(^|[^[:alnum:]_-])composer'"$OPTS"'[[:space:]]+(require|install)[[:space:]]+'
  ["dotnet:add"]='(^|[^[:alnum:]_-])dotnet'"$OPTS"'[[:space:]]+add[[:space:]]+package[[:space:]]+'
)

# ---- Identify package install commands, one shell segment at a time ----
# A command line can hold more than one package manager, and the old loop took the
# FIRST pattern that matched anywhere in the whole string. PM_PATTERNS is an
# associative array, so "first" meant bash hash order -- not the order the managers
# appear in the command, and not the order they are written in the literal.
# `pip install requests && npm install event-stream` was classified python, the
# blocklist was asked about python:event-stream, which is not an entry, and a
# known-malicious npm package was installed with this guard's approval. Split on the
# shell's own separators and judge each segment under its own ecosystem.
NL=$'\012'
SEG_INPUT="${CMD//&&/$NL}"
SEG_INPUT="${SEG_INPUT//||/$NL}"
SEG_INPUT="${SEG_INPUT//;/$NL}"
SEG_INPUT="${SEG_INPUT//|/$NL}"

# A shell removes quotes during word expansion, so npm receives `event-stream` from
# all of 'event-stream', "event-stream", 'event'-stream and ev'ent-stream. Strip
# every quote so the blocklist is asked about the name the package manager will
# actually see. The quotes come from variables deliberately: writing one literally
# inside ${p//.../} opens a quoted region instead of being a pattern, which silently
# made an earlier form a no-op and let `npm install 'event-stream'` through.
SQ=$'\047'
DQ='"'

# Extras belong in the whitelist. `pip install requests[socks]` is ordinary and
# clean_pkg strips the bracket anyway, so rejecting [ ] and , here did nothing but
# empty the package list and turn a check into an allow. Bracket expression ordered
# for POSIX: ] first, - last.
PKG_CHARS="]a-zA-Z0-9@._/+:~^=<>,\"'[-"

PACKAGES=()          # entries are "<ecosystem>|<token>", because the ecosystem is
                     # per segment now and the blocklist is keyed on it
CANDIDATE_TOTAL=0
VALID_TOTAL=0
DROPPED_TOTAL=0
FOUND_PM=0

while IFS= read -r SEG; do
  [[ -z "${SEG//[[:space:]]/}" ]] && continue

  ECO=""; PM=""; PM_MATCH=""
  for key in "${!PM_PATTERNS[@]}"; do
    pat="${PM_PATTERNS[$key]}"
    if [[ "$SEG" =~ $pat ]]; then
      ECO="${key%%:*}"
      PM="${key##*:}"
      # Keep the text the regex actually matched (e.g. "pip3 install ", "go get ").
      # Captured while BASH_REMATCH still belongs to this match -- any later =~ in
      # this script would overwrite it.
      PM_MATCH="${BASH_REMATCH[0]}"
      break
    fi
  done
  [[ -z "$ECO" ]] && continue
  FOUND_PM=1
  log "package install detected: ecosystem=$ECO pm=$PM"

  # tr '[:space:]', not tr ' '. The detector accepts any whitespace between a package
  # manager and its arguments, so `npm install event-stream<TAB>lodash` arrived here
  # as a single tab-containing token, the validity grep dropped it, the package list
  # came out empty and the hook returned allow having checked neither name.
  CANDIDATES="$(printf '%s' "${SEG#*"$PM_MATCH"}" \
    | tr '[:space:]' '\n' \
    | grep -E -v '^$' \
    | grep -E -v '^(-|--)' \
    | grep -E -v '^(install|add|i|--save|--save-dev|--dev|-D|-g|--global)$')"

  # Two counts, not one: "some arguments were unreadable" and "no argument was
  # readable" are different facts, and only the second one used to be noticed.
  seg_c="$(printf '%s' "$CANDIDATES" | grep -c -E '^.+$' || true)"
  VALID="$(printf '%s' "$CANDIDATES" | grep -E "^[$PKG_CHARS]+\$")"
  seg_v="$(printf '%s' "$VALID" | grep -c -E '^.+$' || true)"
  CANDIDATE_TOTAL=$(( CANDIDATE_TOTAL + seg_c ))
  VALID_TOTAL=$(( VALID_TOTAL + seg_v ))
  DROPPED_TOTAL=$(( DROPPED_TOTAL + seg_c - seg_v ))

  while IFS= read -r p; do
    p="${p//$DQ/}"
    p="${p//$SQ/}"
    [[ -n "$p" ]] && PACKAGES+=("$ECO|$p")
  # 200, not 20. The blocklist lookup is a local string match and capping it turned a
  # certain deny into a nameless ask: a command whose 21st argument was event-stream
  # was approved-with-a-shrug and the prompt never said which name was the problem.
  # Only the expensive checks are capped now, inside the loop below.
  done <<< "$(printf '%s' "$VALID" | head -200)"
done <<< "$SEG_INPUT"

# No package manager anywhere in the command: not our business.
if [[ "$FOUND_PM" -eq 0 ]]; then
  emit_json PreToolUse permissionDecision '"allow"'
  exit 0
fi

# An install with no package argument is ordinary -- `npm install` from a lockfile,
# `pip install -r requirements.txt`. An install whose arguments ALL failed the
# whitelist is not, and the two used to be indistinguishable: both returned allow.
# Every bypass found in this function has ended on that line.
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  if [[ "$CANDIDATE_TOTAL" -gt 0 ]]; then
    log "ASK: install command whose arguments could not be read: $CMD"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' \
      "$(printf '%s' "This is a package install, but none of its arguments could be read as a package name, so nothing was checked against the blocklist. Proceed only if you recognise the command." | jsonenc)"
    exit 0
  fi
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
DEEP_USED=0

# `head -20` bounds the work above, and the whitelist drops tokens it cannot read.
# Neither may happen in silence: `npm install <20 harmless> evil` reported on twenty
# names, and `npm install lodash event\-stream` checked lodash and discarded the
# other without a word. VALID_TOTAL, not CANDIDATE_COUNT — the latter counts `&&`,
# sub-commands and prose, so it named a fictitious number of packages.
DEEP_BUDGET=20
if [[ "$VALID_TOTAL" -gt "$DEEP_BUDGET" ]]; then
  ASK_REASONS+=("This command names $VALID_TOTAL packages. All of them were checked against the blocklist; the typosquat and publish-date checks ran on the first $DEEP_BUDGET only.")
fi
if [[ "$DROPPED_TOTAL" -gt 0 ]]; then
  ASK_REASONS+=("$DROPPED_TOTAL argument(s) could not be read as a package name and were NOT checked against the blocklist.")
fi

# Popular package names per ecosystem for typosquat distance check.
# Edit-distance 1–2 against these names => suspicious (ask).
NPM_POPULAR='react vue angular express lodash axios moment chalk debug commander request webpack typescript jquery underscore async'
PYPI_POPULAR='requests numpy pandas flask django pytest pillow scipy matplotlib pyyaml urllib3 setuptools wheel boto3 cryptography'

# Levenshtein distance via python3
# One interpreter start per package, not one per comparison. The old lev() spawned a
# fresh python3 for every (package x popular-name) pair -- 16 for a single install and
# up to 320 for a full command line -- inside a hook that runs before every Bash tool
# call. Worst case was a CORRECTLY spelled popular package, which pays every spawn and
# matches nothing. Measured at 6.5 s of wall clock for `npm install lodash`, which is
# the kind of tax that gets a security hook switched off, and a hook that is off
# protects nothing.
#
# Prints "<distance> <name>" for the nearest popular package, or nothing.
closest_popular() {
  local py; py="$(py_interp)" || return 1
  "$py" -c '
import sys
a = sys.argv[1]
best = None
for b in sys.argv[2].split():
    if a == b or abs(len(a) - len(b)) > 3:
        continue
    m, n = len(a), len(b)
    dp = list(range(n + 1))
    for i in range(1, m + 1):
        prev = dp[0]; dp[0] = i
        for j in range(1, n + 1):
            cur = dp[j]
            dp[j] = prev if a[i - 1] == b[j - 1] else 1 + min(prev, dp[j - 1], dp[j])
            prev = cur
    if best is None or dp[n] < best[0]:
        best = (dp[n], b)
if best:
    print(best[0], best[1])
' "$1" "$2"
}

# Strip version specifiers and scope prefix for matching
clean_pkg() {
  local p="$1" eco="${2:-}" scope="" stripped

  # A URL, git ref, tarball or local path is not a name this function can normalise,
  # and reducing it to one is worse than leaving it alone. The composer strip below
  # used to cut `https://evil.example/event-stream.tgz` down to the literal string
  # `https`, which is what the blocklist was then asked about -- so every entry in it
  # could be walked around by installing from a URL instead of by name. npm, pip and
  # cargo all accept these forms. Hand them back whole; the caller treats a spec it
  # cannot resolve to a name as unverifiable rather than as clean.
  case "$p" in
    *://*|git+*|file:*|./*|../*|/*|*.tgz|*.tar.gz|*.whl|*.zip)
      printf '%s' "$p"
      return 0
      ;;
  esac

  # npm's documented alias form is <alias>@npm:<real-package>, and yarn and pnpm take
  # it too. Cutting at the @ handed the blocklist the alias and never mentioned the
  # package actually being installed, so `npm install safe@npm:event-stream` fetched
  # event-stream with the guard's approval. Resolve to the real name first.
  case "$p" in
    *@npm:*) p="${p#*@npm:}" ;;
  esac

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

  # vendor:package is composer's form alone. Applying it to every ecosystem is what
  # destroyed any token containing a colon.
  [[ "$eco" == "php" ]] && p="${p%:*}"
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

# Entries carry their ecosystem because a single command line can install from more
# than one. Checking every package against one ecosystem's blocklist is how
# `pip install requests && npm install event-stream` came back allow.
for entry in "${PACKAGES[@]}"; do
  eco="${entry%%|*}"
  pkg="${entry#*|}"
  cleaned="$(clean_pkg "$pkg" "$eco")"
  [[ -z "$cleaned" ]] && continue

  # An install from a URL, git ref or path carries no name to look up. Saying "allow"
  # here would be asserting something the guard cannot know -- the tarball's contents
  # are opaque to it -- so say that instead.
  case "$cleaned" in
    *://*|git+*|file:*|./*|../*|/*|*.tgz|*.tar.gz|*.whl|*.zip)
      ASK_REASONS+=("'$pkg' installs from a URL or path rather than a named package, so the blocklist, typosquat and publish-date checks cannot see what it contains.")
      continue
      ;;
  esac

  # 1. blocklist
  if is_blocklisted "$eco" "$cleaned"; then
    DENY_REASONS+=("Package '$cleaned' ($eco) is on the malicious/typosquat blocklist.")
    continue
  fi

  # The blocklist above is a local string match and runs for every package. What
  # follows is not: the distance check starts an interpreter and the npm checks make
  # two network round trips each, so they are budgeted. Exceeding the budget is
  # reported to the user above rather than passed over in silence.
  DEEP_USED=$(( DEEP_USED + 1 ))
  if (( DEEP_USED > DEEP_BUDGET )); then
    continue
  fi

  # 2. typosquat distance
  case "$eco" in
    nodejs) POPULAR="$NPM_POPULAR" ;;
    python) POPULAR="$PYPI_POPULAR" ;;
    *)      POPULAR="" ;;
  esac
  if [[ -n "$POPULAR" ]] && py_interp >/dev/null; then
    bare="${cleaned##@*/}"
    if (( ${#bare} >= 4 )); then
      read -r d popular <<< "$(closest_popular "$bare" "$POPULAR")"
      if [[ "$d" =~ ^[0-9]+$ ]] && (( d > 0 )) && (( d <= 2 )); then
        ASK_REASONS+=("Package '$cleaned' is edit-distance $d from popular package '$popular' — possible typosquat.")
      fi
    fi
  fi

  # 3. brand-newness (npm only — keeps the hook fast)
  if [[ "$eco" == "nodejs" ]]; then
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
