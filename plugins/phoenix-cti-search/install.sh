#!/usr/bin/env bash
# install.sh — CTI Search Plugin installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$HOME/.claude/plugins"
COMMANDS_DIR="$HOME/.claude/commands"
PLUGIN_DEST="$PLUGINS_DIR/cti-search-plugin"
CONFIG_FILE="$HOME/.claude/claude_desktop_config.json"

echo "=== CTI Search Plugin — Installer ==="
echo ""

# 1. Copy plugin to ~/.claude/plugins/
echo "[1/5] Installing plugin..."
mkdir -p "$PLUGINS_DIR"
rm -rf "$PLUGIN_DEST"
cp -r "$SCRIPT_DIR" "$PLUGIN_DEST"
echo "      ✓ $PLUGIN_DEST"

# 2. Copy domain data
echo "[2/5] Installing domain data..."
mkdir -p "$PLUGIN_DEST/data"
SKILL_REF="$(dirname "$SCRIPT_DIR")/cti-domain-research/references"
if [ -d "$SKILL_REF" ]; then
  cp "$SKILL_REF/domains.txt" "$PLUGIN_DEST/data/"
  cp "$SKILL_REF/tier-map.json" "$PLUGIN_DEST/data/"
  echo "      ✓ $(wc -l < "$PLUGIN_DEST/data/domains.txt") domains loaded"
else
  echo "      ⚠ Domain data not found at $SKILL_REF"
  echo "        Expected: domains.txt and tier-map.json from the cti-domain-research skill"
fi

# 3. npm install
echo "[3/5] Installing Node.js dependencies..."
cd "$PLUGIN_DEST"
npm install --silent
echo "      ✓ Dependencies installed"

# 4. Install slash command
echo "[4/5] Installing /cti-search slash command..."
mkdir -p "$COMMANDS_DIR"
cp "$PLUGIN_DEST/slash-command.md" "$COMMANDS_DIR/cti-search.md"
echo "      ✓ ~/.claude/commands/cti-search.md"

# 5. Register as MCP server
echo "[5/5] Registering MCP server..."
if command -v python3 &>/dev/null; then
  python3 - <<PYEOF
import json, os, sys

config_path = os.path.expanduser("$CONFIG_FILE")
plugin_path = os.path.expanduser("$PLUGIN_DEST/mcp-server.js")

# Load or create config
try:
    with open(config_path) as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

config.setdefault("mcpServers", {})

config["mcpServers"]["cti-search"] = {
    "command": "node",
    "args": [plugin_path],
    "env": {
        "BRAVE_SEARCH_API_KEY": os.environ.get("BRAVE_SEARCH_API_KEY", ""),
        "SEARCH_PROVIDER": os.environ.get("SEARCH_PROVIDER", "brave"),
        "NOTEBOOKLM_NOTEBOOK_ID": os.environ.get("NOTEBOOKLM_NOTEBOOK_ID", "")
    }
}

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"      ✓ MCP server registered in {config_path}")
PYEOF
else
  echo "      ⚠ python3 not found — add MCP config manually (see README)"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo ""
echo "1. Set your search API key:"
echo "   export BRAVE_SEARCH_API_KEY=<your-key>"
echo "   # Get a free key at: https://api.search.brave.com/app/keys"
echo ""
echo "2. (Optional) Set your NotebookLM notebook ID:"
echo "   export NOTEBOOKLM_NOTEBOOK_ID=<id-from-notebooklm-url>"
echo ""
echo "3. Restart Claude Code to pick up the MCP server"
echo ""
echo "Usage:"
echo "  /cti-search CVE-2024-21762"
echo "  /cti-search LockBit ransomware --full --since 30"
echo "  /cti-search ALPHV --notebooklm --count 20"
echo ""
echo "Or as MCP tool (Claude Code calls it directly):"
echo "  'Search for recent LockBit TTPs across vendor blogs'"
