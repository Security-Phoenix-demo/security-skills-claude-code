# Project Documenter — Claude Skill

**Generate production-grade, hierarchical documentation for any software project.**
Works on greenfield repos, legacy codebases, AI-heavy systems, and anything in between.

![Project Documentation: Turning Codebases into Living Documentation](../../images/project-documentation.jpg)

---

## What It Does

Project Documenter reverse-engineers your repository and produces a complete three-layer documentation system:

```
DOC_INDEX.md        ← compressed routing layer (~1–2k tokens, read first)
CLAUDE.md           ← engineering navigation map (150–300 lines)
/docs/**            ← authoritative domain sub-documents (all detail here)
```

Every layer has a strict job. Sub-documents hold all detail. CLAUDE.md routes. DOC_INDEX.md is the compressed entry point for AI assistants and new engineers. Nothing is ever duplicated across layers.

---

## Six Modes

| Mode | What It Produces | Best For |
|------|-----------------|----------|
| **0 Express** | Full pack, one run, zero questions | New projects with no existing docs |
| **1 General** | README, API docs, modules, changelog, ADRs | Developer-facing documentation |
| **2 AI / LLM** | Prompt inventory, model architecture, guardrails, cost model, agent safety | AI-heavy systems |
| **3 Architecture** | System map, runtime flows, data contracts, dependency map | Engineering design docs |
| **4 Full** | All modes + audit of existing docs | Mature codebases needing consolidation |
| **5 Self-Heal** | Cursor rules + GitHub Actions CI + Python drift-detection scripts | Keeping docs in sync automatically |

---

## Output at a Glance

**Modes 0 / 4 (full pack) — up to 20 files:**

```
/DOC_INDEX.md
/CLAUDE.md
/docs/general/      README, CONTRIBUTING, API_REFERENCE, MODULES, CHANGELOG
/docs/ai/           PROMPTS, LLM_ARCHITECTURE, AGENT_WORKFLOWS, MODEL_GUARDRAILS,
                    AI_RUNBOOK, PROMPT_TESTS, LLM_COST_MODEL, AGENT_SAFETY_MODEL
/docs/architecture/ SYSTEM_OVERVIEW, REPOSITORY_MAP, RUNTIME_FLOWS,
                    DEPENDENCY_MAP, DATA_CONTRACTS
```

**Mode 5 (self-heal) — adds 10 CI files:**

```
/.cursor/rules/     50-hierarchical-documentation.mdc
                    51-auto-documentation-updates.mdc
/.github/           workflows/docs-self-heal.yml
                    scripts/ (5 Python scripts + requirements.txt)
/docs/              DOC_AUTOMATION.md
```

---

## Quick Install

1. Download `project-documenter.skill`
2. In Claude.ai → Settings → Skills → Install from file
3. Say: **"document this project"** and share your codebase

Full installation guide: [INSTALL.md](./docs/INSTALL.md)

---

## Documentation

| File | Purpose |
|------|---------|
| [INSTALL.md](./docs/INSTALL.md) | Step-by-step installation and first-run guide |
| [HOW_IT_WORKS.md](./docs/HOW_IT_WORKS.md) | Complete technical reference for the skill |
| [MODES_REFERENCE.md](./docs/MODES_REFERENCE.md) | Detailed guide to every mode and its outputs |
| [SELF_HEAL_SETUP.md](./docs/SELF_HEAL_SETUP.md) | CI pipeline and Cursor rules setup |
| [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) | Common issues and fixes |

---

## Requirements

- Claude.ai Pro, Team, or Enterprise (skill installation required)
- A codebase to document — any language, any size
- For Mode 5 self-heal: GitHub repository + `ANTHROPIC_API_KEY` secret

---

## License

MIT — free to use, modify, and redistribute.  
Built for the Claude skills ecosystem.
