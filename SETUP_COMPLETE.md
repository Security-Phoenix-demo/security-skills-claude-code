# Repository Setup Summary

This document summarizes the documentation structure and content of the `security-skills-claude-code` repository.

Built by the engineering and security teams at [Phoenix Security](https://phoenix.security).

## Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| **[README.md](README.md)** | Main documentation — overview, skills/plugins reference, FAQ, quick start | End users, contributors |
| **[MARKETPLACE_INSTALL.md](MARKETPLACE_INSTALL.md)** | Step-by-step marketplace installation with troubleshooting | New users |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | How to add skills, plugins, and feature-descriptor roles | Contributors |
| **[LICENSE](LICENSE)** | MIT License | Legal |

## What's Included

### Skills (7)

| Skill | Folder | Description |
|-------|--------|-------------|
| CTI Domain Research | `skills/cti-search-skill/` | Search 300+ security domains for threat intelligence |
| Secure PRD Generator | `skills/secure-prd-skill/` | Security-focused product requirements with threat modeling |
| OpenGrep Rule Generator | `skills/opengrep-rule-generator/` | SAST rule generation for 30+ languages |
| OpenGrep Rule Generator Research | `skills/opengrep-rule-generator-research/` | CVE/CWE research + rule generation |
| NotebookLM Connector | `skills/notebooklm/` | Query NotebookLM for citation-backed answers |
| Global Research Pipeline | `skills/global-research-notebook-lm/` | Web + YouTube research with NotebookLM |
| Project Documentation | `skills/project Documentaion skill/` | Auto-generate project documentation |

### Plugins (2)

| Plugin | Folder | Description |
|--------|--------|-------------|
| CTI Search Plugin | `plugins/cti-search-plugin/` | MCP server + CLI for CTI searches (595+ domains) |
| Secure PRD Plugin | `plugins/secure-prd/` | PRD generator with Confluence/Linear/Slack integration |

### Feature Descriptor — Phoenix Pipeline (12 roles)

All in `feature-descriptor/`:

1. Pipeline Navigator — orchestrates the full pipeline
2. Context Curator — extracts and cleanses context
3. Scope Cutter — defines in/out scope
4. Constraint Distiller — identifies constraints and acceptance criteria
5. Requirements Engineer — RFC 2119 requirements with IDs
6. Ambiguity Hunter — flags and resolves ambiguities
7. Security Engineer — threat models and abuse cases
8. Contract Architect — API design, events, errors
9. Verification Matrix — proof paths for requirements
10. Batch Planner — incremental delivery planning
11. Final Gate — go/no-go with blocker list
12. Orchestrator — coordinates all roles

## Statistics

- **Skills:** 7
- **Plugins:** 2
- **Feature-Descriptor Roles:** 12
- **Security Domains:** 595+
- **Domain Tiers:** 4
- **Installation Methods:** 3 (Marketplace, Git, Direct copy)
- **License:** MIT

---

**Last updated:** March 2026
