---
description: "Search 300+ curated security domains for CTI on any CVE, threat actor, malware, or topic. Optionally push all sources to NotebookLM."
argument-hint: "<query> [--count N] [--full] [--json] [--tier 1|2|3|4] [--since DAYS] [--notebooklm] [--notebook-id ID]"
allowed-tools: WebSearch, Bash
---

# CTI Domain Search

Search for threat intelligence on: $ARGUMENTS

## Instructions

Follow the `cti-domain-research` skill exactly. The full domain list is at:
`~/.claude/commands/cti-domains.txt`

The tier map (domain → authority score) is at:
`~/.claude/commands/cti-tier-map.json`

### Parse these flags from $ARGUMENTS:
- `--count N`        → return N results (default: 10)
- `--full`           → long-form brief + MITRE ATT&CK mapping
- `--json`           → raw JSON output only
- `--tier 1|2|3|4`  → restrict to that domain tier only
- `--since DAYS`     → limit to last N days (default: 90)
- `--notebooklm`     → after search, push all source URLs to NotebookLM
- `--notebook-id ID` → NotebookLM notebook ID (overrides $NOTEBOOKLM_NOTEBOOK_ID)

### Search strategy:
1. Identify query type (CVE / actor / malware / general)
2. Select domain tiers per routing rules in the skill
3. Run batched `site:` searches using web search tool
4. Deduplicate, rank by tier + recency
5. Extract: title, source, date, summary, IOCs/CVEs/TTPs

### Output (default brief):
```
## CTI Brief: <query> — <date>
### Key Findings
### Source Table  
### IOC Summary
### MITRE TTPs Observed
### Next Steps
```

### NotebookLM push (if --notebooklm):
```bash
# Check plugin
ls ~/.claude/plugins/notebooklm-connector/ 2>/dev/null || echo "Plugin not installed — see https://github.com/franksec42/claude-code-zero/tree/main/plugins/notebooklm-connector"

# Push sources
NOTEBOOK_ID="${NOTEBOOKLM_NOTEBOOK_ID:-<from flag>}"
node ~/.claude/plugins/notebooklm-connector/index.js \
  --notebook-id "$NOTEBOOK_ID" \
  --sources "$SOURCES_JSON" \
  --title "CTI: $(echo '$ARGUMENTS' | sed 's/ --.*//') — $(date +%Y-%m-%d)"
```
If plugin not installed, print the source URLs formatted for manual NotebookLM import.
