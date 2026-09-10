# Repository Setup Summary

What this repository contains and how it is laid out.

Built by the engineering and security teams at [Phoenix Security](https://phoenix.security).

## Documentation

| File | Purpose | Audience |
|------|---------|----------|
| **[README.md](README.md)** | Overview, per-skill reference, quick start, FAQ | End users, contributors |
| **[MARKETPLACE_INSTALL.md](MARKETPLACE_INSTALL.md)** | Install, per-plugin setup, updating, troubleshooting | New users |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | How to add a skill or a plugin, and how to test it | Contributors |
| **[LICENSE](LICENSE)** | MIT License | Legal |

## Distribution

One marketplace, declared at `.claude-plugin/marketplace.json`. Six plugins, each with its
own `.claude-plugin/plugin.json` under `plugins/`.

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
/plugin install <plugin-name>@phoenix-security
```

The marketplace is named `phoenix-security`.

## The six plugins

| Plugin | Skills | Also ships |
|---|---|---|
| `phoenix-security-review` | 6 | 4 commands, 1 subagent, 3 opt-in hooks, Windsurf + Codex install |
| `phoenix-readiness-reviews` | 2 | A deterministic repo scanner |
| `phoenix-sast-rules` | 2 | Rule-syntax references for 30+ languages |
| `phoenix-cti-search` | 1 | `/cti-search` command, Node CLI, MCP server, 595-domain dataset in 4 tiers |
| `phoenix-prd-pipeline` | 13 | The Claude.ai web UI variant under `dist/` |
| `phoenix-docs-research` | 3 | Python browser automation for NotebookLM |

**27 skills total.** Each is also a slash command named after it.

### phoenix-security-review

`security-reviewer` · `security-assessment` · `0day-scanner` · `threat-modeling` ·
`tm-quick-security-assessment` · `tm-security-review`

Commands: `/security-review` `/security-0day` `/security-audit` `/threatmodel`

### phoenix-readiness-reviews

`plan-readiness-review` (READY / NOT READY on a plan) ·
`production-readiness-review` (SHIP / NO-SHIP on a codebase)

### phoenix-sast-rules

`opengrep-rule-generator` · `opengrep-rule-generator-research`

### phoenix-cti-search

`cti-domain-research` (no API key needed). Command: `/cti-search`, over the bundled CLI.

### phoenix-prd-pipeline

`prd-generator`, plus the 12 Phoenix Pipeline roles:

1. `phoenix-pipeline-navigator` — interactive guide and launcher
2. `phoenix-context-curator` — role 01, cleans raw input
3. `phoenix-scope-cutter` — role 02, in and out of scope
4. `phoenix-constraint-distiller` — role 03, constraints and acceptance criteria
5. `phoenix-requirements-engineer` — role 04, RFC 2119 requirements with IDs
6. `phoenix-ambiguity-hunter` — role 05, red-teams the requirements
7. `phoenix-security-engineer` — role 06, threat model and abuse cases
8. `phoenix-contract-architect` — role 07, APIs, events, error taxonomy
9. `phoenix-verification-matrix` — role 08, a proof path per requirement
10. `phoenix-batch-planner` — role 09, incremental delivery
11. `phoenix-final-gate` — role 10, SHIP / NO_SHIP with blockers
12. `phoenix-orchestrator` — runs roles 01–10 end to end

### phoenix-docs-research

`project-documenter` (6 modes, self-healing) · `notebooklm` · `phoenix-research-pipeline`

## Numbers

- **Plugins:** 6
- **Skills:** 27
- **Slash commands:** 5 dedicated (4 security + `/cti-search`), plus one per skill
- **Subagents:** 1
- **Hooks:** 3 (opt-in) + 1 SessionEnd reminder
- **Security domains:** 595 across 4 authority tiers
- **Editors supported:** Claude Code, plus Windsurf and Codex for the security suite
- **License:** MIT

## Validating the repository

```bash
python3 scripts/validate-marketplace.py             # does everything fit together?
claude plugin validate .                            # marketplace manifest
claude plugin validate --strict plugins/<plugin>    # its skills, commands and agents
```

---

**Last updated:** September 2026
