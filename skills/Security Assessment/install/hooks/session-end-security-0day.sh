#!/usr/bin/env bash
# Claude Code SessionEnd hook: reminds about a security 0-day scan
# when the current branch has a non-trivial diff vs the default branch.
#
# Behavior: prints a one-line reminder + copy-pasteable slash command.
# Does NOT invoke an LLM (cheap, no tokens spent).
#
# Install: see skills/Security Assessment/README.md
# Disable: remove the SessionEnd entry in .claude/settings.json,
#          or set SECURITY_0DAY_HOOK_DISABLED=1 in your environment.

set -u

[[ "${SECURITY_0DAY_HOOK_DISABLED:-0}" == "1" ]] && exit 0

# Bail silently if not a git repo.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Resolve default branch (main, master, or origin/HEAD fallback).
default_branch=""
for cand in main master; do
  if git show-ref --verify --quiet "refs/heads/$cand"; then
    default_branch="$cand"
    break
  fi
done
if [[ -z "$default_branch" ]]; then
  default_branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
fi
[[ -z "$default_branch" ]] && exit 0

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
[[ -z "$current_branch" || "$current_branch" == "$default_branch" || "$current_branch" == "HEAD" ]] && exit 0

# Count files changed vs default branch (committed + uncommitted).
changed=$(git diff --name-only "$default_branch"...HEAD 2>/dev/null | wc -l | tr -d ' ')
unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
total=$((changed + unstaged))

[[ "$total" -eq 0 ]] && exit 0

cat <<MSG
[security-0day reminder] Branch '$current_branch' has $total changed file(s) vs '$default_branch'.
  Run a quick security scan before you ship:
    /security-0day $default_branch
  (Disable this reminder: set SECURITY_0DAY_HOOK_DISABLED=1 or remove the SessionEnd hook.)
MSG
exit 0
