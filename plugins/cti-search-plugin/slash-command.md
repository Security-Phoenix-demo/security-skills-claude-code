---
description: "Search 300+ security domains for CTI — powered by cti-search-plugin. Works for CVEs, threat actors, malware, exploits, or any security topic. Push results to NotebookLM with --notebooklm."
argument-hint: "<query> [--count N] [--full] [--json] [--tier 1|2|3|4] [--since DAYS] [--notebooklm] [--notebook-id ID]"
allowed-tools: Bash
---

Run the CTI search plugin:

```bash
node ~/.claude/plugins/cti-search-plugin/index.js $ARGUMENTS
```

If the plugin is not installed, fall back to:
```bash
echo "cti-search-plugin not found at ~/.claude/plugins/cti-search-plugin/"
echo "Install: cp -r /path/to/cti-search-plugin ~/.claude/plugins/ && cd ~/.claude/plugins/cti-search-plugin && npm install"
```
