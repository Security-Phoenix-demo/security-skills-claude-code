#!/usr/bin/env bash
# install.sh — CTI Domain Research skill installer for Claude Code
# Usage: bash install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_COMMANDS="$HOME/.claude/commands"
CLAUDE_PLUGINS="$HOME/.claude/plugins"

echo "=== CTI Domain Research — Claude Code Installer ==="
echo ""

# 1. Create directories
mkdir -p "$CLAUDE_COMMANDS"
mkdir -p "$CLAUDE_PLUGINS"

# 2. Install slash command
echo "[1/4] Installing /cti-search slash command..."
cp "$SCRIPT_DIR/cti-search.md" "$CLAUDE_COMMANDS/cti-search.md"
echo "      ✓ ~/.claude/commands/cti-search.md"

# 3. Install domain list
echo "[2/4] Installing domain list..."
cp "$SKILL_DIR/references/domains.txt" "$CLAUDE_COMMANDS/cti-domains.txt"
DOMAIN_COUNT=$(wc -l < "$CLAUDE_COMMANDS/cti-domains.txt")
echo "      ✓ ~/.claude/commands/cti-domains.txt ($DOMAIN_COUNT domains)"

# 4. Install tier map
echo "[3/4] Installing tier map..."
cp "$SKILL_DIR/references/tier-map.json" "$CLAUDE_COMMANDS/cti-tier-map.json"
echo "      ✓ ~/.claude/commands/cti-tier-map.json"

# 5. Check NotebookLM connector
echo "[4/4] Checking NotebookLM connector plugin..."
NLM_PLUGIN="$CLAUDE_PLUGINS/notebooklm-connector"
if [ -d "$NLM_PLUGIN" ]; then
  echo "      ✓ NotebookLM connector found at $NLM_PLUGIN"
else
  echo "      ⚠ NotebookLM connector NOT installed."
  echo "        To enable --notebooklm flag, install it:"
  echo "        git clone https://github.com/YOUR_USERNAME/claude-code-zero \\"
  echo "          /tmp/claude-code-zero"
  echo "        cp -r /tmp/claude-code-zero/plugins/notebooklm-connector \\"
  echo "          ~/.claude/plugins/"
  echo "        cd ~/.claude/plugins/notebooklm-connector && npm install"
  echo ""
  echo "        Then set your notebook ID:"
  echo "        export NOTEBOOKLM_NOTEBOOK_ID=<your-notebook-id>"
  echo "        # Add to ~/.zshrc or ~/.bashrc to persist"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Usage in Claude Code:"
echo "  /cti-search CVE-2024-21762"
echo "  /cti-search LockBit ransomware --full --since 30"
echo "  /cti-search ALPHV BlackCat --notebooklm"
echo "  /cti-search supply chain attack npm --count 20 --tier 2"
echo ""
echo "NotebookLM notebook ID:"
if [ -n "$NOTEBOOKLM_NOTEBOOK_ID" ]; then
  echo "  ✓ NOTEBOOKLM_NOTEBOOK_ID is set: ${NOTEBOOKLM_NOTEBOOK_ID:0:8}..."
else
  echo "  ✗ Not set. Run: export NOTEBOOKLM_NOTEBOOK_ID=<id>"
fi
