#!/usr/bin/env bash
# .claude/hooks/session-start.sh
#
# Runs at the beginning of every Claude Code session for this project.
# Fingerprints the codebase, runs a fast dependency audit if tooling is
# present, and injects a "## SECURITY CONTEXT" block via the SessionStart
# hook's additionalContext channel. Every agent (including security-reviewer)
# starts the session aware of the project's security posture.
#
# Wire-up in .claude/settings.json:
#   {
#     "hooks": {
#       "SessionStart": [
#         { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] }
#       ]
#     }
#   }

. "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
CACHE="$(cache_dir)"
CACHE_FILE="$CACHE/session-context.txt"
CACHE_TTL_SECONDS=900   # 15 minutes; re-runs faster than this reuse cache

# Bypass cache if invoked with --fresh
FRESH=0
[[ "${1:-}" == "--fresh" ]] && FRESH=1

# Cache check
if [[ $FRESH -eq 0 && -f "$CACHE_FILE" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if (( age < CACHE_TTL_SECONDS )); then
    log "using cached context (age ${age}s)"
    body="$(cat "$CACHE_FILE")"
    emit_json SessionStart additionalContext "$(printf '%s' "$body" | jsonenc)"
    exit 0
  fi
fi

# shellcheck disable=SC2207
# SC2207 suggests mapfile. mapfile is bash 4+, and this hook has to keep working on
# the bash 3.2 that macOS still ships. Word splitting is safe here: detect_ecosystems
# prints one short, fixed identifier per line (nodejs, python, go, ...) — never a path.
ECOSYSTEMS=($(detect_ecosystems))
if [[ ${#ECOSYSTEMS[@]} -eq 0 ]]; then
  log "no recognised ecosystem manifests; skipping deep audit"
fi

# Build the context block
{
  printf '## SECURITY CONTEXT (injected by .claude/hooks/session-start.sh)\n\n'
  printf 'Project root: `%s`\n' "$ROOT"
  printf 'Detected ecosystems: %s\n' "${ECOSYSTEMS[*]:-none}"
  printf 'Generated at: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # ----- Manifest fingerprint -----
  printf '### Manifests present\n\n'
  for f in package.json package-lock.json yarn.lock pnpm-lock.yaml \
           pyproject.toml requirements.txt Pipfile Pipfile.lock poetry.lock uv.lock \
           go.mod go.sum Cargo.toml Cargo.lock pom.xml build.gradle build.gradle.kts gradle.lockfile \
           Gemfile Gemfile.lock composer.json composer.lock; do
    [[ -f "$ROOT/$f" ]] && printf -- '- `%s`\n' "$f"
  done
  ls "$ROOT"/*.csproj 2>/dev/null | awk -F/ '{printf "- `%s`\n", $NF}'
  printf '\n'

  # ----- Lockfile sanity -----
  printf '### Lockfile sanity\n\n'
  for eco in ${ECOSYSTEMS[@]+"${ECOSYSTEMS[@]}"}; do
    case "$eco" in
      nodejs)
        if [[ -f "$ROOT/package.json" && ! -f "$ROOT/package-lock.json" && ! -f "$ROOT/yarn.lock" && ! -f "$ROOT/pnpm-lock.yaml" ]]; then
          printf -- '- ⚠️ nodejs: package.json present but no lockfile committed\n'
        else
          printf -- '- ✅ nodejs: lockfile present\n'
        fi
        ;;
      python)
        # "pinned requirements.txt" used to be asserted without opening the file: the
        # branch only warned when pyproject.toml existed, so a requirements.txt-only
        # project fell to the else and got a green tick no matter what was in it.
        if [[ -f "$ROOT/poetry.lock" || -f "$ROOT/uv.lock" || -f "$ROOT/Pipfile.lock" ]]; then
          printf -- '- â python: lockfile present
'
        elif [[ -f "$ROOT/requirements.txt" ]]; then
          # wc -l, not grep -c: grep -c prints 0 AND exits 1 when it matches nothing, so a
          # `|| printf 0` fallback appends a second zero and the arithmetic below dies.
          req_total=$(grep -E -v '^[[:space:]]*(#|$)' "$ROOT/requirements.txt" 2>/dev/null | wc -l | tr -d '[:space:]')
          req_pinned=$(grep -E -c '==' "$ROOT/requirements.txt" 2>/dev/null | tr -d '[:space:]')
          [[ -z "$req_total" ]] && req_total=0
          [[ -z "$req_pinned" ]] && req_pinned=0
          if [[ "$req_total" -gt 0 && "$req_pinned" -eq "$req_total" ]]; then
            printf -- '- â python: requirements.txt fully pinned (%s entries)
' "$req_pinned"
          else
            printf -- '- â ï¸ python: no lockfile, and %s of %s requirements.txt entries are unpinned
'               "$(( req_total - req_pinned ))" "$req_total"
          fi
        elif [[ -f "$ROOT/pyproject.toml" ]]; then
          printf -- '- â ï¸ python: pyproject.toml present but no lockfile (poetry.lock / uv.lock / Pipfile.lock)
'
        else
          printf -- '- â ï¸ python: no lockfile and no requirements.txt
'
        fi
        ;;
      go)
        [[ -f "$ROOT/go.sum" ]] && printf -- '- ✅ go: go.sum present\n' || printf -- '- ⚠️ go: go.sum missing\n'
        ;;
      rust)
        [[ -f "$ROOT/Cargo.lock" ]] && printf -- '- ✅ rust: Cargo.lock present\n' || printf -- '- ⚠️ rust: Cargo.lock missing\n'
        ;;
      java)
        if [[ -f "$ROOT/gradle.lockfile" ]] || grep -q '<dependencyManagement>' "$ROOT/pom.xml" 2>/dev/null; then
          printf -- '- ✅ java: lockfile or BOM present\n'
        else
          printf -- '- ⚠️ java: no gradle.lockfile or Maven dependencyManagement BOM detected\n'
        fi
        ;;
      ruby)
        [[ -f "$ROOT/Gemfile.lock" ]] && printf -- '- ✅ ruby: Gemfile.lock present\n' || printf -- '- ⚠️ ruby: Gemfile.lock missing\n'
        ;;
      dotnet)
        [[ -f "$ROOT/packages.lock.json" ]] && printf -- '- ✅ dotnet: packages.lock.json present\n' || printf -- '- ⚠️ dotnet: no packages.lock.json (set RestorePackagesWithLockFile=true)\n'
        ;;
    esac
  done
  printf '\n'

  # ----- .gitignore basics -----
  printf '### Secrets hygiene (.gitignore)\n\n'
  if [[ -f "$ROOT/.gitignore" ]]; then
    # grep -F was an unanchored substring match, so `!.env` -- a rule that explicitly
    # UN-ignores .env -- satisfied the `.env` probe, and `*.keystore` satisfied the
    # `*.key` probe. Both printed a green tick for a file git will happily commit.
    # Compare whole rules, and let a later negation win the way git does.
    gitignore_ignores() {
      local want="$1" line found=0 neg=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(printf '%s' "$line" | tr -d '
' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        case "$line" in
          '#'*) continue ;;
          "!$want") found=1; neg=1 ;;
          "$want"|"/$want") found=1; neg=0 ;;
        esac
      done < "$ROOT/.gitignore"
      [[ "$found" -eq 1 && "$neg" -eq 0 ]]
    }
    for pat in '.env' '.env.local' '*.pem' '*.key'; do
      if gitignore_ignores "$pat"; then
        printf -- '- â `%s` ignored
' "$pat"
      else
        printf -- '- â ï¸ `%s` not in .gitignore
' "$pat"
      fi
    done
  else
    printf -- '- ⚠️ no .gitignore at project root\n'
  fi
  printf '\n'

  # ----- Quick dep audit -----
  printf '### Dependency audit (best-effort, fast)\n\n'

  # `timeout` is GNU coreutils and is absent from stock macOS -- the same platform this
  # hook's bash-3.2 handling exists to protect. Because the 2>&1 belongs to the simple
  # command, bash applied it before reporting the missing binary, so "timeout: command
  # not found" was captured into the fenced block and presented to the model as audit
  # output, while AUDIT_RAN was set to 1 anyway and suppressed the "no audit tool
  # installed" guidance. Run the tool unbounded rather than not at all.
  if have timeout; then
    run_limited() { timeout "$@"; }
  elif have gtimeout; then
    run_limited() { gtimeout "$@"; }
  else
    run_limited() { shift; "$@"; }
  fi

  AUDIT_RAN=0

  if have osv-scanner; then
    AUDIT_RAN=1
    printf 'Tool: `osv-scanner` (multi-ecosystem)\n\n'
    printf '```\n'
    run_limited 30 osv-scanner -r "$ROOT" --format=table 2>&1 | head -60 || true
    printf '\n```\n\n'
  else
    # Per-ecosystem fallback, capped tight on time
    for eco in ${ECOSYSTEMS[@]+"${ECOSYSTEMS[@]}"}; do
      case "$eco" in
        nodejs)
          if have npm; then
            printf 'Tool: `npm audit` (nodejs)\n\n```\n'
            (cd "$ROOT" && run_limited 20 npm audit --audit-level=high 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        python)
          if have pip-audit; then
            printf 'Tool: `pip-audit` (python)\n\n```\n'
            (cd "$ROOT" && run_limited 30 pip-audit 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        go)
          if have govulncheck; then
            printf 'Tool: `govulncheck` (go)\n\n```\n'
            (cd "$ROOT" && run_limited 30 govulncheck ./... 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        rust)
          if have cargo-audit; then
            printf 'Tool: `cargo audit` (rust)\n\n```\n'
            (cd "$ROOT" && run_limited 30 cargo audit 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        ruby)
          if have bundle && bundle help audit >/dev/null 2>&1; then
            printf 'Tool: `bundle audit` (ruby)\n\n```\n'
            (cd "$ROOT" && run_limited 30 bundle audit check --update 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
      esac
    done
  fi

  if [[ $AUDIT_RAN -eq 0 ]]; then
    printf 'No dependency-audit tool installed. Recommended (pick one):\n'
    printf -- '- `osv-scanner` (multi-ecosystem, single binary): https://github.com/google/osv-scanner\n'
    printf -- '- ecosystem-native: `npm audit`, `pip-audit`, `govulncheck`, `cargo audit`, `bundle audit`, `dotnet list package --vulnerable`\n\n'
  fi

  # ----- Operating instructions for downstream agents -----
  printf '### Guidance for agents in this session\n\n'
  printf -- '- The `security-reviewer` skill (from the phoenix-security-review plugin) defines the 8-point review and the per-language reference packs. Load it by name.\n'
  printf -- '- Trust this context block over re-discovery for ecosystem and lockfile state.\n'
  printf -- '- The `pre-bash-package-guard.sh` hook will block typosquatted, brand-new, or known-malicious package installs — do not try to bypass it; surface the issue to the user instead.\n'
  printf -- '- The `post-edit-quickscan.sh` hook will scan files written by Edit/Write/MultiEdit and may emit findings to consume.\n'
  printf '\n'
} > "$CACHE_FILE"

body="$(cat "$CACHE_FILE")"
emit_json SessionStart additionalContext "$(printf '%s' "$body" | jsonenc)"
log "session context emitted (${#body} bytes)"
exit 0
