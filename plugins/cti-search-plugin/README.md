# cti-search-plugin

CTI domain research plugin for Claude Code. Searches 300+ curated security sources and optionally pushes results to NotebookLM.

## Architecture

```
cti-search-plugin/
├── index.js          ← CLI entry point (node index.js --query "CVE-2024-21762")
├── mcp-server.js     ← MCP tool server (Claude Code calls this natively)
├── slash-command.md  ← /cti-search slash command definition
├── install.sh        ← One-shot installer
├── package.json
├── .env.example      ← Copy to .env, add your API keys
└── data/
    ├── domains.txt   ← 595 curated security domains
    └── tier-map.json ← Domain → tier + authority score
```

## Three ways to use it

### 1. Slash command (Claude Code)
```
/cti-search CVE-2024-21762
/cti-search LockBit ransomware --full --since 30
/cti-search ALPHV --notebooklm
```

### 2. MCP tool (Claude calls it directly)
After installing + registering the MCP server, Claude Code can call `cti_search` as a tool without any slash command. Just ask naturally:
> "Search for recent LockBit TTPs across vendor security blogs and push to NotebookLM"

### 3. CLI (standalone)
```bash
node index.js --query "CVE-2024-21762" --full
node index.js --query "LockBit" --tier 2 --since 30 --notebooklm
node index.js --query "supply chain attack npm" --json | jq '.[] | .url'
```

## Installation

```bash
bash install.sh

# Set API keys
export BRAVE_SEARCH_API_KEY=<key>          # https://api.search.brave.com/app/keys
export NOTEBOOKLM_NOTEBOOK_ID=<notebook-id> # optional

# Restart Claude Code
```

## Search API options

| Provider | Env var | Free tier | Notes |
|---|---|---|---|
| **Brave** (recommended) | `BRAVE_SEARCH_API_KEY` | 2000 req/mo | Set `SEARCH_PROVIDER=brave` |
| SerpAPI | `SERPAPI_KEY` | 100 req/mo | Set `SEARCH_PROVIDER=serpapi` |

## Domain tiers

| Tier | Description | Examples |
|---|---|---|
| **T1** | Authoritative / govt | CISA, NVD, MSRC, NCSC, RedHat |
| **T2** | Vendor research | Unit42, Talos, Securelist, DFIR Report, Volexity |
| **T3** | News + community | BleepingComputer, Krebs, TheRecord, HackerNews |
| **T4** | OSINT + PoC | any.run, VulnCheck, AttackerKB, GreyNoise |

## Flags

| Flag | Description |
|---|---|
| `--query <q>` | Search subject |
| `--count <n>` | Results per tier (default: 10) |
| `--tier <1-4>` | Restrict to tier |
| `--since <days>` | Recency filter (default: 90) |
| `--full` | Long-form brief + MITRE mapping |
| `--json` | Raw JSON output |
| `--notebooklm` | Push sources to NotebookLM |
| `--notebook-id <id>` | NotebookLM notebook ID |

## NotebookLM integration

Requires the [notebooklm-connector](https://github.com/franksec42/claude-code-zero/tree/main/plugins/notebooklm-connector) plugin:

```bash
git clone https://github.com/franksec42/claude-code-zero /tmp/ccz
cp -r /tmp/ccz/plugins/notebooklm-connector ~/.claude/plugins/
cd ~/.claude/plugins/notebooklm-connector && npm install
```

Get your notebook ID from the NotebookLM URL:
`https://notebooklm.google.com/notebook/<YOUR-NOTEBOOK-ID>`
