---
name: cti-domain-research
description: >
  Search for threat intelligence, CVEs, malware analysis, breach reports, and security research
  across 300+ curated security domains (BleepingComputer, Hacker News, Krebs, Unit42, Talos,
  CISA, Mandiant, Rapid7, Securelist, etc.). Use this skill whenever the user asks to:
  research a CVE or vulnerability, find what security vendors are saying about a threat actor
  or malware family, search security blogs, look up threat intelligence on a topic, find recent
  breach or ransomware reports, collect CTI for a MITRE technique, or push research into
  NotebookLM. Triggers for phrases like "search security sources", "find threat intel on X",
  "what are vendors saying about Y", "research CVE-XXXX", "look up malware Z", "collect CTI",
  "push to NotebookLM", or any domain-scoped web research request in a security context.
---

# CTI Domain Research

Structured threat intelligence search across 300+ curated security domains with optional
NotebookLM ingestion.

---

## Customization

Configure these settings to personalize your CTI research workflow. All are optional — the skill works with sensible defaults.

| Setting | Description | Default | How to Set |
|---------|-------------|---------|------------|
| **Search provider** | Which search API to use | Brave Search | `SEARCH_PROVIDER=brave` in `.env` |
| **Brave API key** | Your Brave Search API key | — (required) | `BRAVE_SEARCH_API_KEY=...` in `.env` |
| **SerpAPI key** | Alternative search provider | — | `SERPAPI_KEY=...` in `.env` |
| **Google CSE key + ID** | Alternative search provider | — | `GOOGLE_CSE_KEY=...` + `GOOGLE_CSE_ID=...` in `.env` |
| **NotebookLM notebook ID** | Target notebook for `--notebooklm` flag | — | `NOTEBOOKLM_NOTEBOOK_ID=...` in `.env` or `--notebook-id` flag |
| **Default result count** | Results per tier | 10 | `--count N` flag per query |
| **Default recency** | How far back to search | 90 days | `--since DAYS` flag per query |
| **Custom domains** | Add your own security sources | 595 built-in | Edit `data/domains.txt` and `data/tier-map.json` |

**Setup steps:**

1. Copy `.env.example` to `.env` in the plugin directory
2. Add your search API key (Brave recommended — 2,000 free requests/month)
3. Optionally set your NotebookLM notebook ID
4. Restart Claude Code

```bash
cd ~/.claude/plugins/cti-search-plugin
cp .env.example .env
# Edit .env with your API keys
```

**Adding custom domains:**

```bash
# Add a domain (one per line)
echo "your-security-blog.com" >> data/domains.txt

# Add tier mapping
# Edit data/tier-map.json and add:
# "your-security-blog.com": { "tier": 3, "authority": 70 }
```

---

## Workflow

```
1. Parse query + flags
2. Select domain tier(s) based on query type
3. Execute scoped web searches (site: operator per domain batch)
4. Deduplicate + rank results by recency and source authority
5. Extract: title, source, date, summary, key IOCs/TTPs/CVEs mentioned
6. [Optional] Push findings to NotebookLM via connector plugin
7. Return structured CTI brief
```

---

## Query Parsing

Accept free-text queries. Extract:
- **Subject**: CVE ID, actor name, malware family, technique (MITRE ATT&CK), product name
- **Time filter**: default = last 90 days; honour "last week / month / year" if stated
- **Depth**: default = top 10 results; `--count N` overrides
- **Output format**: default = brief table + bullets; `--full` = long-form brief; `--json` = raw JSON
- **NotebookLM push**: `--notebooklm` flag triggers the connector (see NotebookLM section below)

---

## Domain Tiers

Load the full domain list from `references/domains.txt`. Apply tier routing:

| Tier | When to use | Examples |
|------|-------------|---------|
| **Tier 1 — Authoritative** | CVEs, advisories, govt alerts | cisa.gov, nvd.nist.gov, msrc.microsoft.com, access.redhat.com, support.apple.com, cert.europa.eu, ncsc.gov.uk |
| **Tier 2 — Vendor Research** | Deep technical analysis | unit42.paloaltonetworks.com, blog.talosintelligence.com, securelist.com, research.checkpoint.com, thedfirreport.com, blog.google, mandiant.com, secureworks.com, sentinelone.com, crowdstrike.com |
| **Tier 3 — News + Community** | Situational awareness | bleepingcomputer.com, krebsonsecurity.com, therecord.media, thehackernews.com, arstechnica.com, reddit.com/r/cybersecurity, news.ycombinator.com |
| **Tier 4 — Specialised** | Malware, PoC, OSINT | any.run, otx.alienvault.com, vulncheck.com, attackerkb.com, greynoise.io, hunt.io, packetstormsecurity.com |

**Routing logic:**
- CVE query → Tier 1 first, then Tier 2
- Threat actor / malware → Tier 2 first, then Tier 4
- Situational / news → Tier 3 first, then Tier 2
- PoC / exploit → Tier 4 + Tier 2
- General → all tiers, ranked by authority score

---

## Search Execution

Use the web search tool with `site:` scoping. Batch domains to maximise coverage per call:

```
# Example batch query construction
query = f'"{subject}" site:bleepingcomputer.com OR site:krebsonsecurity.com OR site:therecord.media'

# For CVEs, always include NVD and MSRC
query = f'{cve_id} site:nvd.nist.gov OR site:msrc.microsoft.com OR site:cisa.gov'
```

Run multiple searches in parallel when `--full` is specified:
1. Tier 1 batch
2. Tier 2 batch  
3. Tier 3 + 4 batch

---

## Result Schema

For each result, extract:

```json
{
  "title": "...",
  "source": "domain.com",
  "url": "https://...",
  "published": "YYYY-MM-DD",
  "authority_tier": 1,
  "summary": "1-2 sentence distillation",
  "tags": ["CVE-XXXX", "ransomware", "RCE", "MITRE:T1190"],
  "iocs": ["hash", "IP", "domain"],
  "severity": "Critical|High|Medium|Low|Info"
}
```

---

## Output Formats

### Default — CTI Brief (table + bullets)

```
## CTI Brief: <query> — <date>

### Key Findings
- [Critical] <1-line finding> — <source> (<date>)
- [High] ...

### Source Table
| Source | Title | Date | Tags |
|--------|-------|------|------|
| bleepingcomputer.com | ... | ... | ransomware, RCE |

### IOC Summary
IPs: ...  Hashes: ...  Domains: ...

### Next Steps
- Patch priority: ...
- Detection: MITRE T-IDs to hunt
- Intel gaps: ...
```

### `--full` — Long-Form Brief
Add: executive summary, per-source analysis paragraphs, MITRE ATT&CK mapping table, recommended detection rules (Sigma header stubs).

### `--json`
Return raw JSON array of result objects (schema above).

---

## NotebookLM Integration

When `--notebooklm` flag is set, use the NotebookLM connector plugin to ingest findings.

**Plugin location (Claude Code):** `~/.claude/plugins/notebooklm-connector/`  
**Plugin repo:** https://github.com/Security-Phoenix-demo/security-skills-claude-code/tree/main/plugins/notebooklm-connector

### Connector flow:

```
1. Collect all result URLs from the search phase
2. Format as source list per plugin spec
3. Call connector to add sources to target NotebookLM notebook
4. Report: N sources added, notebook URL
```

### Plugin call pattern (Claude Code):

```bash
# Check connector is installed
ls ~/.claude/plugins/notebooklm-connector/

# Call connector with source list
node ~/.claude/plugins/notebooklm-connector/index.js \
  --notebook-id "$NOTEBOOKLM_NOTEBOOK_ID" \
  --sources "$(echo $URLS | jq -R -s 'split("\n")')" \
  --title "CTI: $QUERY — $(date +%Y-%m-%d)"
```

### Required env var:
```bash
export NOTEBOOKLM_NOTEBOOK_ID="<your-notebook-id>"
# Or pass via --notebook-id flag at query time
```

### Fallback (Claude.ai — no plugin runtime):
If running in Claude.ai (no bash), present a formatted source list the user can manually add to NotebookLM, plus a direct link to their notebook if the ID is known.

---

## Slash Command (Claude Code)

Install by creating `~/.claude/commands/cti-search.md`:

```markdown
---
description: "Search 300+ security domains for CTI on any topic, CVE, actor, or malware"
argument-hint: "<query> [--count N] [--full] [--json] [--notebooklm] [--notebook-id ID]"
allowed-tools: WebSearch, Bash
---

Search curated security domains for threat intelligence on: $ARGUMENTS

Follow the CTI Domain Research skill (cti-domain-research) exactly.
Domain list: ~/.claude/commands/cti-domains.txt

Flags:
- --count N        : Return N results (default 10)
- --full           : Long-form brief with MITRE mapping
- --json           : Raw JSON output
- --notebooklm     : Push sources to NotebookLM after search
- --notebook-id ID : Target notebook ID (overrides env var)
- --tier 1|2|3|4   : Restrict to specific domain tier
- --since DAYS     : Limit to last N days (default 90)
```

---

## Installation Script

Run `scripts/install.sh` to:
1. Copy slash command to `~/.claude/commands/`
2. Copy domain list to `~/.claude/commands/cti-domains.txt`
3. Verify NotebookLM connector plugin presence
4. Print setup confirmation

See `scripts/install.sh` for full details.

---

## Error Handling

| Condition | Behaviour |
|-----------|-----------|
| No results for domain batch | Skip tier, try next; warn if all tiers empty |
| NotebookLM connector not installed | Warn + fallback to manual source list |
| Rate limited on search | Back off 2s, retry once; surface partial results |
| Query too broad (>1000 potential results) | Auto-narrow to Tier 1+2 only, suggest refinement |
| CVE not yet in NVD | Note "CVE may be pre-NVD — check vendor advisories directly" |

---

## Reference Files

- `references/domains.txt` — Full curated domain list (300+ sources, one per line)
- `references/tier-map.json` — Domain → tier + authority score mapping
- `scripts/install.sh` — One-shot installer for Claude Code slash command
