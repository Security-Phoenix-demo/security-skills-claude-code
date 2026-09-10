---
description: "Search 300+ security domains for CTI. Works for CVEs, threat actors, malware, exploits, or any security topic. Push results to NotebookLM with --notebooklm."
argument-hint: "<query> [--count N] [--full] [--json] [--tier 1|2|3|4] [--since DAYS] [--notebooklm] [--notebook-id ID]"
allowed-tools: Bash
---

Run the bundled CTI search CLI:

```bash
node "${CLAUDE_PLUGIN_ROOT}/index.js" $ARGUMENTS
```

## If it fails

**`Cannot find module` / missing dependency** — the plugin's Node dependencies are not
installed yet. Install them once, then re-run:

```bash
cd "${CLAUDE_PLUGIN_ROOT}" && npm install --omit=dev
```

**`No search provider configured`** — copy the example env file and add a key
(Brave Search gives 2,000 free requests a month):

```bash
cp "${CLAUDE_PLUGIN_ROOT}/.env.example" "${CLAUDE_PLUGIN_ROOT}/.env"
```

Then set `BRAVE_SEARCH_API_KEY` in that file and re-run.

**Anything else** — fall back to the `cti-domain-research` skill in this plugin, which does
the same tiered search with the assistant's own web-search tools and needs no API key.
