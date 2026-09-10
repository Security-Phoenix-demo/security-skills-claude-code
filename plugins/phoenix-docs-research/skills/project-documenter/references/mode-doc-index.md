# Mode 6 — DOC_INDEX.md (Compressed Routing Layer)

Generated LAST of all files — after all sub-documents and after CLAUDE.md.
Synthesized from CLAUDE.md. Every routing entry must point to a file that exists.

---

## Purpose

DOC_INDEX.md is the entry point for AI assistants and engineers in large repositories.
Its only job: tell the reader which documents to load for their task, in the minimum words possible.

A reader opens DOC_INDEX.md, finds their task, gets an ordered load list, and closes the file.
That's the entire use case.

**Role split — commit this to memory:**

| File | Role | Max length |
|------|------|------------|
| DOC_INDEX.md | Compressed router | 80–150 lines (hard limit: 200) |
| CLAUDE.md | Engineering navigation map | 150–250 lines (hard limit: 300) |
| Sub-docs | Authoritative domain detail | Unlimited |

---

## Length Gate

Target: **80–150 lines**
Hard limit: **200 lines**

If DOC_INDEX.md exceeds 200 lines, content is leaking from CLAUDE.md.
Move the leaked content back to CLAUDE.md and replace with a single link.

---

## DOC_INDEX.md Template

Generate DOC_INDEX.md using this structure. Fill from CLAUDE.md — no generic placeholders.

```markdown
<!-- This file is the compressed routing layer for repository documentation. -->
<!-- Read this first. Load only what you need for your task. -->
<!-- Full engineering map: /CLAUDE.md -->

# DOC_INDEX.md

## Repository Identity

**Project:** [name — pulled from CLAUDE.md]
**Purpose:** [1–3 sentences max — what this system does]
**Stack:** [language / framework / infra — one line]
**Architecture:** [monolith / microservice / event-driven / agent-based / hybrid]
**AI present:** [yes — providers / no]

---

## Read This First

For full architecture context and detailed loading guide:
→ `/CLAUDE.md`

---

## Documentation Domains

### Architecture
Authoritative files for system structure, flows, and data:

| File | Use for |
|------|--------|
| `/docs/architecture/SYSTEM_OVERVIEW.md` | Component map, architecture style, external deps |
| `/docs/architecture/REPOSITORY_MAP.md` | Module ownership, change-risk zones, reading order |
| `/docs/architecture/RUNTIME_FLOWS.md` | End-to-end execution traces, sequence diagrams |
| `/docs/architecture/DEPENDENCY_MAP.md` | Internal + external dependency graph, failure cascades |
| `/docs/architecture/DATA_CONTRACTS.md` | Critical schemas, event formats, breaking change rules |

*Omit any row for files that were not generated.*

### AI / LLM
Authoritative files for AI components:

| File | Use for |
|------|--------|
| `/docs/ai/PROMPTS.md` | Prompt inventory, templates, input/output contracts |
| `/docs/ai/LLM_ARCHITECTURE.md` | Model providers, pipeline, retry/fallback |
| `/docs/ai/AGENT_WORKFLOWS.md` | Agent logic, approval gates, autonomy levels |
| `/docs/ai/MODEL_GUARDRAILS.md` | Injection defense, output validation, privacy |
| `/docs/ai/AI_RUNBOOK.md` | Monitoring, debugging, incident response |
| `/docs/ai/PROMPT_TESTS.md` | Prompt contract tests, regression cases |
| `/docs/ai/LLM_COST_MODEL.md` | Token budget, cost per operation, optimization |
| `/docs/ai/AGENT_SAFETY_MODEL.md` | Agent risk classification, safety constraints |

*Omit this section entirely if no AI layer was detected.*

### General
Authoritative files for development and API:

| File | Use for |
|------|--------|
| `/docs/general/README.md` | Setup, quick start, configuration |
| `/docs/general/CONTRIBUTING.md` | Dev workflow, PR process, test requirements |
| `/docs/general/API_REFERENCE.md` | All endpoints, auth, request/response shapes |
| `/docs/general/MODULES.md` | Module purposes, ownership, change risk |
| `/docs/general/ARCHITECTURE_OVERVIEW.md` | Infrastructure, external dependencies |
| `/docs/general/CHANGELOG.md` | Version history |

---

## Task Routing

Load in the order listed. Stop when you have enough context.

**Understanding the system for the first time:**
1. `/DOC_INDEX.md` ← you are here
2. `/CLAUDE.md`
3. `/docs/architecture/SYSTEM_OVERVIEW.md`

**Tracing a request or runtime behavior:**
1. `/CLAUDE.md` (Section: Core Runtime Flows)
2. `/docs/architecture/RUNTIME_FLOWS.md`
3. `/docs/architecture/DEPENDENCY_MAP.md` ← if the flow touches external services

**Working on AI prompts or model behavior:**
1. `/CLAUDE.md` (Section: High-Risk Areas)
2. `/docs/ai/PROMPTS.md`
3. `/docs/ai/LLM_ARCHITECTURE.md`
4. `/docs/ai/MODEL_GUARDRAILS.md`
5. `/docs/ai/PROMPT_TESTS.md` ← before shipping any change

**Changing a data contract or schema:**
1. `/CLAUDE.md` (Section: High-Risk Areas)
2. `/docs/architecture/DATA_CONTRACTS.md`
3. `/docs/architecture/DEPENDENCY_MAP.md`

**Debugging a production failure:**
1. `/docs/ai/AI_RUNBOOK.md` ← if AI-related
2. `/docs/general/ARCHITECTURE_OVERVIEW.md` ← for infra context

**Modifying authentication or authorization:**
1. `/CLAUDE.md` (Section: High-Risk Areas)
2. `/docs/general/API_REFERENCE.md#auth`
3. `/docs/ai/MODEL_GUARDRAILS.md#data-privacy` ← if AI is involved

**Changing an external integration:**
1. `/docs/architecture/DEPENDENCY_MAP.md`
2. `/docs/architecture/RUNTIME_FLOWS.md` ← for affected flows

**Local development or contribution:**
1. `/docs/general/README.md`
2. `/docs/general/CONTRIBUTING.md`

---

## High-Risk Areas

Load the listed docs before making changes to these zones.

| Zone | Why High Risk | Load Before Changing |
|------|-------------|---------------------|
| AI output schemas | Consumers fail silently on field change | DATA_CONTRACTS + PROMPTS + PROMPT_TESTS |
| Auth middleware | Shared across all routes | API_REFERENCE#auth |
| Orchestrator retry logic | Silent failures or duplicates | LLM_ARCHITECTURE + AI_RUNBOOK |
| Data model fields | Rename = DB migration + consumer updates | DATA_CONTRACTS + DEPENDENCY_MAP |
| [zone detected in scan] | [specific risk] | [relevant doc] |

*Replace the last row with actual high-risk zones found during repo scan.*

---

## Do Not Load Unless Directly Relevant

Avoid pulling these into context unless your task specifically requires them:

- Verbose runbooks (load only the section you need)
- Legacy ADRs or archived decision records
- Generated API specs for endpoints you are not changing
- Large integration docs for providers not involved in your task
- Low-level test fixture files

---

## Documentation Rules (for AI assistants)

- DOC_INDEX.md is the compressed routing layer — do not add detail here
- CLAUDE.md is the engineering map — load it when you need architectural context
- Sub-documents are authoritative — load only the ones relevant to your task
- One canonical home per topic — never duplicate detail across files
- Load the minimum required documents for the task at hand
```

---

## Rules for Generating DOC_INDEX.md

1. **Generate after CLAUDE.md is complete.** Every link must point to a real file.

2. **Routing tables must match CLAUDE.md Section 8.** If CLAUDE.md says to load doc X for
   task Y, DOC_INDEX.md's routing for task Y must include doc X. They must agree.

3. **No orphan rows.** If a doc was skipped during generation (e.g., no AI detected),
   remove its row from the domains table. Do not include placeholder rows.

4. **High-Risk Areas table must be grounded.** Every row must correspond to something
   flagged during the repo scan — not generic advice.

5. **Do-not-load list must be honest.** If a doc was generated, only include it in the
   do-not-load list if it is legitimately large and rarely needed.

6. **Preserve routing from existing DOC_INDEX.md.** If one already existed and had
   project-specific routing rules that were accurate, carry those forward.

7. **The first two lines are mandatory:**
   ```
   <!-- This file is the compressed routing layer for repository documentation. -->
   <!-- Read this first. Load only what you need for your task. -->
   ```

8. **No architecture explanation.** If you find yourself writing "the system uses X because Y",
   that belongs in CLAUDE.md or SYSTEM_OVERVIEW.md — not here.
