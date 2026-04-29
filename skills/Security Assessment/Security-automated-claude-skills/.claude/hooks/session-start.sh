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
  for eco in "${ECOSYSTEMS[@]}"; do
    case "$eco" in
      nodejs)
        if [[ -f "$ROOT/package.json" && ! -f "$ROOT/package-lock.json" && ! -f "$ROOT/yarn.lock" && ! -f "$ROOT/pnpm-lock.yaml" ]]; then
          printf -- '- ⚠️ nodejs: package.json present but no lockfile committed\n'
        else
          printf -- '- ✅ nodejs: lockfile present\n'
        fi
        ;;
      python)
        if [[ -f "$ROOT/pyproject.toml" && ! -f "$ROOT/poetry.lock" && ! -f "$ROOT/uv.lock" && ! -f "$ROOT/Pipfile.lock" ]]; then
          printf -- '- ⚠️ python: pyproject.toml present but no lockfile (poetry.lock / uv.lock / Pipfile.lock)\n'
        else
          printf -- '- ✅ python: lockfile present or pinned requirements.txt\n'
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
    for pat in '.env' '.env.local' '*.pem' '*.key'; do
      if grep -q -F -- "$pat" "$ROOT/.gitignore"; then
        printf -- '- ✅ `%s` ignored\n' "$pat"
      else
        printf -- '- ⚠️ `%s` not in .gitignore\n' "$pat"
      fi
    done
  else
    printf -- '- ⚠️ no .gitignore at project root\n'
  fi
  printf '\n'

  # ----- Quick dep audit -----
  printf '### Dependency audit (best-effort, fast)\n\n'

  AUDIT_RAN=0

  if have osv-scanner; then
    AUDIT_RAN=1
    printf 'Tool: `osv-scanner` (multi-ecosystem)\n\n'
    printf '```\n'
    timeout 30 osv-scanner -r "$ROOT" --format=table 2>&1 | head -60 || true
    printf '\n```\n\n'
  else
    # Per-ecosystem fallback, capped tight on time
    for eco in "${ECOSYSTEMS[@]}"; do
      case "$eco" in
        nodejs)
          if have npm; then
            printf 'Tool: `npm audit` (nodejs)\n\n```\n'
            (cd "$ROOT" && timeout 20 npm audit --audit-level=high 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        python)
          if have pip-audit; then
            printf 'Tool: `pip-audit` (python)\n\n```\n'
            (cd "$ROOT" && timeout 30 pip-audit 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        go)
          if have govulncheck; then
            printf 'Tool: `govulncheck` (go)\n\n```\n'
            (cd "$ROOT" && timeout 30 govulncheck ./... 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        rust)
          if have cargo-audit; then
            printf 'Tool: `cargo audit` (rust)\n\n```\n'
            (cd "$ROOT" && timeout 30 cargo audit 2>&1 | head -40) || true
            printf '\n```\n\n'
            AUDIT_RAN=1
          fi
          ;;
        ruby)
          if have bundle && bundle help audit >/dev/null 2>&1; then
            printf 'Tool: `bundle audit` (ruby)\n\n```\n'
            (cd "$ROOT" && timeout 30 bundle audit check --update 2>&1 | head -40) || true
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
  printf -- '- The `security-reviewer` skill at `.claude/skills/security-reviewer/SKILL.md` defines the 8-point review and per-language references.\n'
  printf -- '- Trust this context block over re-discovery for ecosystem and lockfile state.\n'
  printf -- '- The `pre-bash-package-guard.sh` hook will block typosquatted, brand-new, or known-malicious package installs — do not try to bypass it; surface the issue to the user instead.\n'
  printf -- '- The `post-edit-quickscan.sh` hook will scan files written by Edit/Write/MultiEdit and may emit findings to consume.\n'
  printf '\n'
} > "$CACHE_FILE"

body="$(cat "$CACHE_FILE")"
emit_json SessionStart additionalContext "$(printf '%s' "$body" | jsonenc)"
log "session context emitted (${#body} bytes)"
exit 0
