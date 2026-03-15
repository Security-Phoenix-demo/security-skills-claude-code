# CTI Domain Research Skill

Search for cyber threat intelligence across 300+ curated security domains, with optional NotebookLM integration for research ingestion.

![Research, Verify, Detect: Structured Threat Intelligence for Claude Code](../../images/cti-skills.jpg)

## What It Does

This skill performs structured threat intelligence searches across a curated list of 300+ security domains organized into four authority tiers. When you need to research a CVE, investigate a threat actor, analyze malware, or gather situational awareness on a security topic, the skill constructs scoped web searches using `site:` operators against domain batches and returns deduplicated, ranked results with extracted IOCs, TTPs, and severity assessments.

The domain tiers route queries intelligently: CVE lookups hit authoritative sources first (CISA, NVD, MSRC), threat actor and malware research prioritizes vendor research blogs (Unit42, Talos, Securelist, Mandiant), news queries go to community sources (BleepingComputer, Krebs, TheRecord), and exploit/OSINT queries target specialized platforms (any.run, VulnCheck, GreyNoise).

Results can be output as a concise CTI brief (default), a long-form report with MITRE ATT&CK mapping (`--full`), or raw JSON (`--json`). The `--notebooklm` flag pushes all discovered source URLs into a NotebookLM notebook via the companion connector plugin.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Core skill definition with full workflow, domain tiers, output formats, and NotebookLM integration spec |
| `cti-search.md` | Slash command definition for Claude Code (`/cti-search`) |
| `tier-map.json` | Domain-to-tier mapping with authority scores (80+ domains across 4 tiers) |
| `cti-domain-research.skill` | Packaged skill bundle (ZIP archive) |
| `install.sh` | One-shot installer that copies slash command, domain list, and tier map to `~/.claude/` |
| `Readme` | Original build notes |

## Installation

```bash
# Run the installer
bash install.sh

# Set your search API key (Brave recommended — 2,000 free requests/month)
export BRAVE_SEARCH_API_KEY=<your-key>

# Optional: set NotebookLM notebook ID for --notebooklm flag
export NOTEBOOKLM_NOTEBOOK_ID=<your-notebook-id>
```

## Usage

```bash
/cti-search CVE-2024-21762
/cti-search LockBit ransomware --full --since 30
/cti-search ALPHV BlackCat --notebooklm
/cti-search supply chain npm --count 20 --tier 2
```

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--count N` | Number of results to return | 10 |
| `--full` | Long-form brief with MITRE ATT&CK mapping | off |
| `--json` | Raw JSON output | off |
| `--tier 1\|2\|3\|4` | Restrict to a specific domain tier | all |
| `--since DAYS` | Limit results to last N days | 90 |
| `--notebooklm` | Push source URLs to NotebookLM after search | off |
| `--notebook-id ID` | Override NotebookLM notebook ID | env var |

## Requirements

- A web search API key: Brave Search (recommended), SerpAPI, or Google CSE
- Claude Code with WebSearch and Bash tools enabled
- Optional: NotebookLM connector plugin at `~/.claude/plugins/notebooklm-connector/`
- See also: [`plugins/cti-search-plugin/`](../../plugins/cti-search-plugin/) for the Node.js plugin implementation
