#!/usr/bin/env bash
# scan_repo.sh — deterministic evidence collection for a production-readiness review.
#
# Purpose: replace "the model eyeballed the repo" with reproducible, quotable output.
# Every finding is printed as path:line so the audit can cite it and a second run
# can be diffed against the first.
#
# Usage:
#   ./scan_repo.sh <repo-path> [--base <git-ref>] [--exclude <regex>]
#
#   --base    compare against this ref to scope the change surface (default: origin/main
#             if it exists, else main, else master, else skip diff sections)
#   --exclude extra path regex to ignore on top of the vendor defaults
#
# Exit codes: 0 = scan completed (findings are NOT failures), 1 = bad usage/path.
set -uo pipefail

REPO=""
BASE=""
EXTRA_EXCLUDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)    BASE="${2:-}"; shift 2 ;;
    --exclude) EXTRA_EXCLUDE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *)         REPO="$1"; shift ;;
  esac
done

[[ -z "$REPO" || ! -d "$REPO" ]] && { echo "usage: $0 <repo-path> [--base ref] [--exclude regex]" >&2; exit 1; }
cd "$REPO" || exit 1

EXCLUDE_RE='(^|/)(node_modules|dist|build|out|target|vendor|\.git|\.venv|venv|__pycache__|coverage|\.next|\.terraform)(/|$)'
[[ -n "$EXTRA_EXCLUDE" ]] && EXCLUDE_RE="$EXCLUDE_RE|$EXTRA_EXCLUDE"
TEST_RE='(^|/)(tests?|spec|__tests__|e2e|integration[-_]tests?)(/|$)|\.(test|spec)\.[a-z]+$|(^|/)test_[^/]+\.py$|[^/]+_test\.(go|py|rb)$'

# SEARCH <regex> [ci]  — ci="i" makes the match case-insensitive
if command -v rg >/dev/null 2>&1; then
  SEARCH() { if [[ "${2:-}" == "i" ]]; then rg -i --no-heading --line-number --color never -e "$1" . 2>/dev/null; else rg --no-heading --line-number --color never -e "$1" . 2>/dev/null; fi; }
else
  SEARCH() { if [[ "${2:-}" == "i" ]]; then grep -rnIiE "$1" . 2>/dev/null; else grep -rnIE "$1" . 2>/dev/null; fi; }
fi

# filter <exclude-tests:yes|no>
filter() {
  local drop_tests="${1:-no}"
  awk -v ex="$EXCLUDE_RE" -v tre="$TEST_RE" -v dt="$drop_tests" -F: '
    { p=$1; sub(/^\.\//,"",p) }
    p ~ ex { next }
    dt=="yes" && p ~ tre { next }
    { print }'
}

section() { printf '\n## %s\n\n' "$1"; }
emit() {  # emit <title> <regex> <drop_tests> <cap> [ci]
  local title="$1" re="$2" dt="$3" cap="${4:-40}" ci="${5:-}" out n
  out="$(SEARCH "$re" "$ci" | filter "$dt")"
  n="$(printf '%s' "$out" | grep -c . || true)"
  printf '\n### %s — %s hit(s)\n' "$title" "$n"
  [[ "$n" -eq 0 ]] && { printf '\n_none_\n'; return; }
  printf '\n```\n%s\n```\n' "$(printf '%s\n' "$out" | head -n "$cap")"
  [[ "$n" -gt "$cap" ]] && printf '\n_(truncated: showing %s of %s)_\n' "$cap" "$n"
  return 0
}

echo "# Deterministic scan — $(basename "$(pwd)")"
echo
echo "- scanned: \`$(pwd)\`"
echo "- date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
command -v rg >/dev/null 2>&1 && echo "- engine: ripgrep" || echo "- engine: grep (ripgrep not installed)"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "- commit: $(git rev-parse --short HEAD 2>/dev/null)"

section "1. Incompleteness markers (non-test paths)"
emit "TODO / FIXME / HACK / XXX / TBD" '(^|[^A-Za-z])(TODO|FIXME|HACK|XXX|TBD)([^A-Za-z]|$)' yes
emit "Not-implemented bodies" 'NotImplementedError|not implemented|notImplemented|unimplemented\(\)|todo!\(\)|panic\("TODO' yes
emit "Placeholder values" 'placeholder|dummy[-_ ]?(data|value|token)|lorem ipsum|CHANGEME|changeme|<your-|example\.com' yes
emit "Mocks / stubs / fakes outside tests" '\b(mock|stub|fake|sandbox|simulate)[A-Za-z_]*\s*[=(:]|from unittest\.mock|jest\.mock|sinon\.stub' yes

section "2. Silent failure and swallowed errors"
emit "Empty except / catch" 'except[^:]*:\s*pass|except\s*:\s*$|catch\s*\([^)]*\)\s*\{\s*\}|catch\s*\{\s*\}|rescue\s*(=>\s*\w+\s*)?$|_ = err$' yes
emit "Broad catches" 'except Exception|except BaseException|catch\s*\(\s*(Throwable|Exception|e)\s*\)|panic\(recover' yes
emit "Silent defaults on failure" 'or\s+\{\}|\|\|\s*\{\}|\?\?\s*\[\]|return None\s*#|default_factory=dict\s*#' yes

section "3. Debug and dev leftovers (non-test paths)"
emit "Debug output" 'console\.(log|debug)\(|debugger;|pdb\.set_trace|breakpoint\(\)|binding\.pry|fmt\.Print' yes
emit "Disabled tests" '@(pytest\.mark\.)?skip|\.skip\(|xit\(|xdescribe\(|t\.Skip\(|@Ignore' no
emit "Lint / type suppression" 'eslint-disable|# type: ignore|@ts-ignore|@ts-nocheck|nosec|noqa|#\s*pylint:\s*disable' yes

section "4. Security surface"
emit "Possible hardcoded secrets" '(api[_-]?key|secret|password|passwd|token|private[_-]?key)\s*[:=]\s*["'"'"'][^"'"'"']{8,}' yes 40 i
emit "Auth / permission markers" '@(login_required|requires_auth|authorize|PreAuthorize|permission_classes)|isAuthenticated|checkPermission|requireRole|tenant_id|tenantId' yes
emit "Route / endpoint definitions" '@(app|router|blueprint|api)\.(get|post|put|patch|delete)|app\.(get|post|put|patch|delete)\(|@(Get|Post|Put|Patch|Delete)Mapping|path\(|urlpatterns' yes 60
emit "Injection-prone patterns" 'eval\(|exec\(|pickle\.loads|yaml\.load\((?!.*Loader)|shell=True|innerHTML\s*=|dangerouslySetInnerHTML|f".*SELECT .*\{|\+ *" *(SELECT|INSERT|UPDATE|DELETE)' yes
emit "Verify: TLS / cert checks disabled" 'verify\s*=\s*False|rejectUnauthorized:\s*false|InsecureSkipVerify:\s*true|--no-check-certificate' yes

section "5. Config, flags, migrations, deploy"
emit "Environment variable reads" 'os\.environ|process\.env\.|getenv\(|ENV\[|System\.getenv' yes 60
emit "Feature flags" 'feature[_-]?flag|isEnabled\(|flagd|launchdarkly|unleash|\bff_[a-z]' yes
echo
echo "### Config / deploy artefacts present"
echo
for f in .env.example .env.sample docker-compose.yml Dockerfile Makefile; do
  [[ -e "$f" ]] && echo "- present: \`$f\`" || echo "- MISSING: \`$f\`"
done
for d in migrations db/migrate alembic prisma/migrations .github/workflows charts k8s terraform; do
  [[ -d "$d" ]] && echo "- present: \`$d/\` ($(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
done

section "6. Test surface"
TEST_FILES="$(find . -type f 2>/dev/null | sed 's|^\./||' | grep -Ev "$EXCLUDE_RE" | grep -E "$TEST_RE" || true)"
SRC_FILES="$(find . -type f \( -name '*.py' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.go' -o -name '*.rb' -o -name '*.java' -o -name '*.cs' \) 2>/dev/null | sed 's|^\./||' | grep -Ev "$EXCLUDE_RE" | grep -Ev "$TEST_RE" || true)"
echo "- test files: $(printf '%s' "$TEST_FILES" | grep -c . || true)"
echo "- source files: $(printf '%s' "$SRC_FILES" | grep -c . || true)"
emit "Negative / failure-path assertions" 'assertRaises|pytest\.raises|expect\(.*\)\.(toThrow|rejects)|assert\.Error|should\.throw|@Test\(expected' no
emit "Tautological or empty tests" 'assert True|expect\(true\)\.toBe\(true\)|assert 1 == 1|it\([^)]*\)\s*\{\s*\}\s*\)|def test_[a-z_]+\(.*\):\s*pass' no

section "7. Change surface"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -z "$BASE" ]]; then
    for cand in origin/main main origin/master master; do
      git rev-parse --verify -q "$cand" >/dev/null 2>&1 && { BASE="$cand"; break; }
    done
  fi
  if [[ -n "$BASE" ]] && git rev-parse --verify -q "$BASE" >/dev/null 2>&1; then
    MB="$(git merge-base HEAD "$BASE" 2>/dev/null || echo "$BASE")"
    echo "- base: \`$BASE\` (merge-base \`$(git rev-parse --short "$MB" 2>/dev/null)\`)"
    echo
    echo '```'
    git diff --stat "$MB"...HEAD 2>/dev/null | tail -n 40
    echo '```'
    CH="$(git diff --name-only "$MB"...HEAD 2>/dev/null || true)"
    CT="$(printf '%s\n' "$CH" | grep -Ec "$TEST_RE" || true)"
    CN="$(printf '%s' "$CH" | grep -c . || true)"
    echo "- changed files: $CN (of which test files: $CT)"
    [[ "$CN" -gt 0 && "$CT" -eq 0 ]] && echo "- ⚠ no test files changed in this diff"
  else
    echo "_no usable base ref; pass --base <ref> to scope the change surface_"
  fi
else
  echo "_not a git repository; change-surface analysis skipped_"
fi

section "Scan complete"
echo "Findings above are leads, not verdicts. Each one must be opened and judged in context"
echo "before it enters the audit table, and each cited as path:line."
