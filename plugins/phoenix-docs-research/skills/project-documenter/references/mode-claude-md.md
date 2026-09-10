# Mode 5 — CLAUDE.md (Navigation Index)

Generated second-to-last (after all sub-documents, before DOC_INDEX.md).
Synthesized from sub-documents that were actually written. Never from a generic template.

**Position in hierarchy:**
```
DOC_INDEX.md  ← compressed router — generated AFTER this file
CLAUDE.md     ← this file — engineering navigation map
/docs/**      ← authoritative domain sub-documents
```

---

## Purpose

CLAUDE.md is the engineering map for the repository. It answers structural questions and
routes readers to the right sub-document. It does not answer detailed questions itself.

A reader opening CLAUDE.md should be able to answer:
- What does this system do?
- What does this repo own?
- Where do I find detail on [X]?
- Which docs should I load for [task]?
- What are the high-risk areas?
- Where do I start if I'm new?

A reader should NOT need to finish reading CLAUDE.md to understand any specific detail.
Every detail lives in a sub-document. CLAUDE.md contains the pointer.

---

## Length Gate

Target: **150–250 lines**
Hard limit: **300 lines**

Over 300 = content leaking from sub-documents. Find it, move it to the right sub-doc,
and replace it with a 2-line summary + link.

---

## CLAUDE.md Template

Generate CLAUDE.md using this exact structure. Fill every section from the
sub-documents that were actually written — no placeholder text.

```markdown
> For minimal context usage, read `/DOC_INDEX.md` first, then load only the documents needed for your task.

# CLAUDE.md
# Engineering navigation map. All detail lives in sub-documents.
# DOC_INDEX.md is the compressed routing layer above this file.

---

## 1. System Identity

**Project:** [name]
**One-liner:** [what this system does — one sentence]

[1 paragraph: problem solved, who uses it, what this repo is actually responsible for.
No padding. No marketing copy. Engineering precision only.]

---

## 2. Repository Boundaries

**This repo owns:**
- [specific capability — not generic]
- [specific capability]

**This repo does NOT own:**
- [external system — be explicit]
- [shared infra concern]

*AI assistants make poor decisions when repo ownership is unclear.*

---

## 3. Architecture

**Style:** [monolith / modular monolith / microservice / event-driven / agent-based / hybrid]

```mermaid
graph TD
  [Real component names from the scan — 8–12 nodes max]
  [Reference SYSTEM_OVERVIEW.md for full diagram]
```

→ Full architecture: `/docs/architecture/SYSTEM_OVERVIEW.md`

---

## 4. Entry Points

| Entry Point | Path | Purpose |
|------------|------|---------|
| [name] | /path/to/file | [one-liner] |

→ Runtime startup and flow detail: `/docs/architecture/RUNTIME_FLOWS.md`

---

## 5. Core Runtime Flows

2 sentences max per flow. Link to full trace.

| Flow | Summary | Detail |
|------|---------|--------|
| [name] | [trigger → transformation → output] | `/docs/architecture/RUNTIME_FLOWS.md#[anchor]` |

→ All execution traces: `/docs/architecture/RUNTIME_FLOWS.md`

---

## 6. High-Risk Areas

Zones where incorrect changes cause cascading failures or security incidents.
2–3 lines max per zone. Full detail in sub-docs.

| Area | Risk | Why | Detail |
|------|------|-----|--------|
| AI output schema | High | Consumers break on field change | `/docs/ai/PROMPTS.md#output-contracts` |
| Auth middleware | High | Shared across all routes | `/docs/general/API_REFERENCE.md#auth` |
| [component] | High | [specific reason] | [link to sub-doc section] |

→ Full change-risk guide: `/docs/architecture/REPOSITORY_MAP.md#change-zones`

---

## 7. Documentation Map

Every sub-document in this system. Load only what you need for the current task.

| File | Covers | Load when |
|------|--------|-----------|
| `/docs/architecture/SYSTEM_OVERVIEW.md` | Components, C4 diagram, external deps | Architecture understanding |
| `/docs/architecture/REPOSITORY_MAP.md` | Module ownership, change-risk zones | Before editing any module |
| `/docs/architecture/RUNTIME_FLOWS.md` | Execution paths, sequence diagrams | Tracing any request or flow |
| `/docs/architecture/DEPENDENCY_MAP.md` | Internal + external dependency graph | Changing integrations |
| `/docs/architecture/DATA_CONTRACTS.md` | Critical schemas, breaking-change rules | Changing data structures |
| `/docs/ai/PROMPTS.md` | Prompt inventory, templates, output contracts | Any AI feature work |
| `/docs/ai/LLM_ARCHITECTURE.md` | Model providers, pipeline, retry/fallback | Changing model or pipeline |
| `/docs/ai/AGENT_WORKFLOWS.md` | Agent logic, approval gates, autonomy | Modifying agent behavior |
| `/docs/ai/MODEL_GUARDRAILS.md` | Injection defense, validation, privacy | AI security review |
| `/docs/ai/AI_RUNBOOK.md` | Monitoring, debugging, incident response | Operating AI system |
| `/docs/ai/PROMPT_TESTS.md` | Prompt contract tests, regressions | Before shipping prompt changes |
| `/docs/ai/LLM_COST_MODEL.md` | Token budget, cost per op, optimization | Cost review or model change |
| `/docs/ai/AGENT_SAFETY_MODEL.md` | Agent risk classification, constraints | Changing agent autonomy |
| `/docs/general/README.md` | Setup, quick start, config | Onboarding, local dev |
| `/docs/general/CONTRIBUTING.md` | Dev workflow, PR process, tests | Contributing |
| `/docs/general/API_REFERENCE.md` | All endpoints, auth, request/response | API work or testing |
| `/docs/general/MODULES.md` | Module purposes, ownership, risk | Before editing any module |
| `/docs/general/ARCHITECTURE_OVERVIEW.md` | Infrastructure, external deps | Infra or deployment work |
| `/docs/general/CHANGELOG.md` | Version history | Release or audit |

*Remove rows for files that were not generated. No placeholder rows.*

---

## 8. Documentation Loading Guide

Which documents to load for each task type. Load in order; stop when you have enough context.

**Understanding the system:**
1. `/DOC_INDEX.md` → `/CLAUDE.md` → `/docs/architecture/SYSTEM_OVERVIEW.md`

**Tracing a request or runtime flow:**
1. `/CLAUDE.md` (Section 5)
2. `/docs/architecture/RUNTIME_FLOWS.md`
3. `/docs/architecture/DEPENDENCY_MAP.md` ← if the flow touches external services

**Working on AI prompts or model behavior:**
1. `/CLAUDE.md` (Section 6 — High-Risk Areas)
2. `/docs/ai/PROMPTS.md`
3. `/docs/ai/LLM_ARCHITECTURE.md`
4. `/docs/ai/MODEL_GUARDRAILS.md`
5. `/docs/ai/PROMPT_TESTS.md` ← before shipping

**Changing a data contract or schema:**
1. `/CLAUDE.md` (Section 6)
2. `/docs/architecture/DATA_CONTRACTS.md`
3. `/docs/architecture/DEPENDENCY_MAP.md`

**Debugging a production failure:**
1. `/docs/ai/AI_RUNBOOK.md` ← if AI-related
2. `/docs/general/ARCHITECTURE_OVERVIEW.md` ← for infra context

**Modifying auth or authorization:**
1. `/CLAUDE.md` (Section 6)
2. `/docs/general/API_REFERENCE.md#auth`
3. `/docs/ai/MODEL_GUARDRAILS.md#data-privacy` ← if AI is involved

**Changing an external integration:**
1. `/docs/architecture/DEPENDENCY_MAP.md`
2. `/docs/architecture/RUNTIME_FLOWS.md` ← for affected flows

**Local development or contribution:**
1. `/docs/general/README.md`
2. `/docs/general/CONTRIBUTING.md`
3. `/docs/general/MODULES.md` ← for the module you're working in

---

## 9. Reading Order for New Engineers

1. `/DOC_INDEX.md` — 2 min, pick your first task
2. `/CLAUDE.md` — 10 min, understand the system (this file)
3. `/docs/architecture/SYSTEM_OVERVIEW.md` — 15 min
4. `/docs/general/README.md` — run it locally
5. `/docs/architecture/RUNTIME_FLOWS.md` — trace 1–2 flows end to end
6. `/docs/general/MODULES.md` — understand module ownership
7. `/docs/ai/PROMPTS.md` ← if AI is present
8. `/docs/architecture/DATA_CONTRACTS.md` — know what must not break

---

## 10. Rules for Safe Changes

Before modifying any code:

- [ ] Identify which execution flow is affected (Section 5)
- [ ] Load the relevant docs from Section 8
- [ ] Check `/docs/architecture/REPOSITORY_MAP.md` for module change-risk level
- [ ] If touching an AI prompt or output schema: run prompt contract tests first
- [ ] If touching a data contract: check `/docs/architecture/DATA_CONTRACTS.md` for consumers
- [ ] If touching auth: read `/docs/general/API_REFERENCE.md#auth` fully
- [ ] State the blast radius of your change before merging

**Zones requiring cross-team sign-off:**
- [Real path from scan] — [specific reason]
- [Real path from scan] — [specific reason]

---

## 11. Known Unknowns

- [inferred behavior — link to sub-doc Known Gaps section]
- [undocumented area — link to relevant sub-doc]
- [open architecture question — link to relevant sub-doc]
```

---

## Rules for Generating CLAUDE.md

1. **Do not write CLAUDE.md until all sub-documents are complete.**
   Every link must point to a file that was actually created.

2. **Pull content from sub-docs, not from the codebase directly.**
   If a detail is worth summarizing, it must already be fully documented in a sub-doc.

3. **Verify every link before writing it.**
   Before writing `/docs/ai/PROMPTS.md#output-contracts`, confirm the section exists.

4. **No orphan links.** If a doc was skipped, remove its row from the Documentation Map.

5. **Preserve useful content from existing CLAUDE.md.**
   Custom routing rules, team conventions, architecture notes — carry these forward.

6. **Section 8 loading guide must match DOC_INDEX.md task routing.**
   They must agree on which docs load for which task.

7. **Section 11 unknown links must resolve.**
   Every unknown must point to the Known Gaps section of a specific sub-document.

8. **First line is mandatory:**
   ```
   > For minimal context usage, read `/DOC_INDEX.md` first, then load only the documents needed for your task.
   ```
