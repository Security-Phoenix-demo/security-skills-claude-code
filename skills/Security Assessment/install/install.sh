#!/usr/bin/env bash
# install.sh — one-command installer for the Security Assessment skill suite.
#
# Usage (run from your project root):
#   bash "skills/Security Assessment/install/install.sh"            # lite preset (default)
#   bash "skills/Security Assessment/install/install.sh" --full     # full preset (active hooks + subagent)
#   bash "skills/Security Assessment/install/install.sh" --uninstall
#   bash "skills/Security Assessment/install/install.sh" --dry-run  # show what would change
#
# What it does (idempotent):
#   - Copies the 4 slash commands into .claude/commands/
#   - Merges the chosen hook preset into .claude/settings.json (creates if missing)
#   - --full only: copies the security-reviewer subagent to .claude/agents/
#   - chmods hook scripts so SessionStart / PreToolUse / PostToolUse can run
#   - Refuses to clobber existing customisations: backs up settings.json once before merge
#
# Requirements: bash, jq (for settings.json merge). Falls back to plain text injection
# with a clear instruction if jq is missing.

set -euo pipefail

# ---- locate suite root ------------------------------------------------------
# Prefer CLAUDE_PROJECT_DIR (set by Claude Code), else infer from this script's path.
SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

PRESET="lite"
DRY=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --lite) PRESET="lite" ;;
    --full) PRESET="full" ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

CL_DIR="$PROJECT_DIR/.claude"
CMD_DIR="$CL_DIR/commands"
AGENT_DIR="$CL_DIR/agents"
SETTINGS="$CL_DIR/settings.json"
BACKUP="$SETTINGS.before-security-suite.bak"
FRESH_MARKER="$SETTINGS.created-by-security-suite"

say()  { echo "[security-suite] $*"; }
do_or_show() {
  if [[ "$DRY" == 1 ]]; then echo "  would: $*"
  else eval "$@"; fi
}

# ---- uninstall path ---------------------------------------------------------
if [[ "$UNINSTALL" == 1 ]]; then
  say "uninstalling…"
  for f in security-0day security-review security-assessment threatmodel; do
    do_or_show "rm -f \"$CMD_DIR/$f.md\""
  done
  do_or_show "rm -f \"$AGENT_DIR/security-reviewer.md\""
  if [[ -f "$BACKUP" ]]; then
    say "restoring settings.json from $BACKUP"
    do_or_show "mv \"$BACKUP\" \"$SETTINGS\""
  elif [[ -f "$FRESH_MARKER" ]]; then
    say "settings.json was created by the installer — removing"
    do_or_show "rm -f \"$SETTINGS\" \"$FRESH_MARKER\""
  else
    say "no settings.json backup found — leaving $SETTINGS untouched (remove the security-suite hook entries manually if needed)"
  fi
  say "done."
  exit 0
fi

say "installing $PRESET preset"
say "  suite:   $SUITE_DIR"
say "  project: $PROJECT_DIR"

# ---- 1. slash commands ------------------------------------------------------
do_or_show "mkdir -p \"$CMD_DIR\""
for f in security-0day security-review security-assessment threatmodel; do
  src="$SUITE_DIR/install/commands/$f.md"
  dst="$CMD_DIR/$f.md"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then continue; fi
  do_or_show "cp \"$src\" \"$dst\""
done
say "✓ slash commands installed: /security-0day, /security-review, /security-assessment, /threatmodel"

# ---- 2. subagent (full only) ------------------------------------------------
if [[ "$PRESET" == "full" ]]; then
  do_or_show "mkdir -p \"$AGENT_DIR\""
  src="$SUITE_DIR/Security-automated-claude-skills/.claude/agents/security-reviewer.md"
  dst="$AGENT_DIR/security-reviewer.md"
  if [[ -f "$src" ]]; then
    do_or_show "cp \"$src\" \"$dst\""
    say "✓ subagent installed: $dst"
  else
    say "! subagent source missing at $src — extract sec-bundle.tar.gz and re-run"
  fi
fi

# ---- 3. chmod hook scripts --------------------------------------------------
do_or_show "chmod +x \"$SUITE_DIR/install/hooks/session-end-security-0day.sh\""
if [[ "$PRESET" == "full" ]]; then
  do_or_show "chmod +x \"$SUITE_DIR/Security-automated-claude-skills/.claude/hooks/\"*.sh 2>/dev/null || true"
fi
say "✓ hook scripts executable"

# ---- 4. settings.json merge -------------------------------------------------
preset_file="$SUITE_DIR/install/hooks/settings.$PRESET.example.json"
[[ -f "$preset_file" ]] || { say "! preset file missing: $preset_file"; exit 1; }

do_or_show "mkdir -p \"$CL_DIR\""

if [[ ! -f "$SETTINGS" ]]; then
  say "creating $SETTINGS"
  if [[ "$DRY" == 1 ]]; then
    echo "  would: write preset to $SETTINGS and drop marker $FRESH_MARKER"
  else
    if command -v jq >/dev/null 2>&1; then
      jq 'del(._comment, ._comment_security_reviewer)' "$preset_file" > "$SETTINGS"
    else
      cp "$preset_file" "$SETTINGS"
    fi
    : > "$FRESH_MARKER"   # marks file as installer-created so --uninstall can remove it
  fi
  say "✓ settings.json created (marker: $FRESH_MARKER — used by --uninstall)"
elif command -v jq >/dev/null 2>&1; then
  if [[ ! -f "$BACKUP" ]]; then
    say "backing up $SETTINGS → $BACKUP"
    do_or_show "cp \"$SETTINGS\" \"$BACKUP\""
  fi
  if [[ "$DRY" == 1 ]]; then
    echo "  would: jq-merge hooks from $preset_file into $SETTINGS"
  else
    tmp="$(mktemp)"
    # Deep-merge: preserve existing keys, add/overwrite the hooks block from preset.
    jq -s '.[0] * .[1] | del(._comment, ._comment_security_reviewer)' "$SETTINGS" "$preset_file" > "$tmp"
    mv "$tmp" "$SETTINGS"
  fi
  say "✓ settings.json merged (backup at $BACKUP — restore with --uninstall)"
else
  say "! jq not found — cannot auto-merge settings.json"
  say "  Manually copy the 'hooks' block from:"
  say "    $preset_file"
  say "  into:"
  say "    $SETTINGS"
fi

# ---- 5. final summary -------------------------------------------------------
say ""
say "install complete ($PRESET preset)."
say "Next steps:"
say "  - In Claude Code, type / and verify the four commands appear."
if [[ "$PRESET" == "full" ]]; then
  say "  - Open a new session — SessionStart hook should inject a SECURITY CONTEXT block."
  say "  - Optional: brew install osv-scanner   # better dependency audit at session start"
fi
say "  - Disable the SessionEnd reminder anytime: export SECURITY_0DAY_HOOK_DISABLED=1"
say "  - Uninstall:  bash \"\$SUITE_DIR/install/install.sh\" --uninstall"
