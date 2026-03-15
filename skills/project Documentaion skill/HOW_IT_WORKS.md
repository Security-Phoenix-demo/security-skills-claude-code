# How It Works — Project Documenter Technical Reference

Complete internal reference for the skill: architecture, execution sequence, design decisions, and the rules that govern every output.

---

## Architecture Overview

Project Documenter is a seven-step orchestration skill. It has a main controller (`SKILL.md`) and six reference files that it loads on demand for each mode. The reference files contain all templates and generation rules; the controller contains all workflow logic.

```
SKILL.md                         ← controller: steps 1–7, mode routing, quality rules
references/
  mode-docs.md                   ← loaded for Mode 1: general documentation templates
  mode-ai.md                     ← loaded for Mode 2: AI/LLM documentation templates
  mode-architecture.md           ← loaded for Mode 3: architecture sub-document templates
  mode-claude-md.md              ← loaded for Step 5: CLAUDE.md generation rules
  mode-doc-index.md              ← loaded for Step 6: DOC_INDEX.md generation rules
  mode-self-heal.md              ← loaded for Mode 5: CI pipeline and Cursor rules
```

Reference files are loaded progressively — only the ones needed for the selected mode are loaded. This keeps token usage low for single-domain runs.

---

## The Three-Layer Output Hierarchy

Every run produces (or updates) a three-layer documentation system:

```
Layer 1  /DOC_INDEX.md      compressed routing layer       80–150 lines  hard limit: 200
Layer 2  /CLAUDE.md         engineering navigation map    150–250 lines  hard limit: 300
Layer 3  /docs/**           authoritative sub-documents   unlimited
```

**The fundamental law:** detail flows downward, never up.

- Sub-documents contain full explanations, diagrams, schemas, code examples
- CLAUDE.md contains 2-line summaries + links to sub-docs, nothing more
- DOC_INDEX.md contains task routing tables, nothing more

If CLAUDE.md exceeds 300 lines, content is leaking from sub-documents and must be moved back. If DOC_INDEX.md exceeds 200 lines, content is leaking from CLAUDE.md.

---

## Mandatory Execution Sequence

The skill enforces a strict seven-step sequence. Steps cannot be reordered.

```
Step 1  INTAKE        Select mode, confirm existing-doc situation
Step 2  AUDIT         Triage every existing doc (skip only for Mode 0)
Step 3  REPO SCAN     Build internal codebase model
Step 4  SUB-DOCS      Generate domain documents (depth first, one at a time)
Step 5  CLAUDE.md     Synthesize navigation index from sub-docs
Step 6  DOC_INDEX.md  Synthesize routing layer from CLAUDE.md
Step 7  REPORT        Completion report + file delivery
```

The most critical constraint: **CLAUDE.md and DOC_INDEX.md are always generated last.** Both are synthesized from what was actually written in Step 4, not from templates. This guarantees every link in the index layer points to a real file.

---

## Step 1 — INTAKE

The skill asks two questions before touching anything:

**Q1 — Mode selection**

Six modes map to different reference files and output sets:

| Mode | Reference File(s) | When to Use |
|------|------------------|-------------|
| 0 Express | All three mode files | New project, no existing docs, want everything at once |
| 1 General | `mode-docs.md` | Need developer-facing docs only |
| 2 AI / LLM | `mode-ai.md` | Need AI layer docs only |
| 3 Architecture | `mode-architecture.md` | Need architecture docs only |
| 4 Full | All three mode files | Existing docs need auditing and updating |
| 5 Self-Heal | `mode-self-heal.md` | Need CI automation to keep docs in sync |

**Q2 — Existing documentation status**

Answers A/B/C determine whether the audit step runs and how aggressively:
- A (no docs): audit still runs, finds nothing, proceeds to scan
- B (partial): audit runs, triages each file, extends or merges
- C (substantial): audit runs, full consolidation pass before any new content is written

**Mode 0 skips Q2 entirely** — it assumes a blank slate and asks no further questions mid-run.

---

## Step 2 — AUDIT

The audit step is the key difference between this skill and a simple "generate docs" command. It prevents the most common documentation failure: generating new docs that contradict, overlap with, or ignore existing ones.

### What Gets Scanned

```
README.md, CONTRIBUTING.md, CHANGELOG.md
DOC_INDEX.md, CLAUDE.md (existing versions — extract routing, preserve what's accurate)
/docs/** (all files, all subdirectories)
/architecture/, /arch/, /design/, /decisions/
ADRs, runbooks, playbooks
AI-specific docs (PROMPTS.md, LLM_ARCHITECTURE.md, etc.)
OpenAPI / Swagger specs
Root-level .md files (SECURITY.md, CODE_OF_CONDUCT.md)
Config file comments that function as documentation
```

### The Triage Decision

Every found document gets one of five actions:

| Action | Condition | What Happens |
|--------|-----------|-------------|
| **Reuse** | Accurate, well-structured | Kept as-is, cross-linked from CLAUDE.md |
| **Extend** | Accurate but incomplete | New sections added below existing content |
| **Merge** | Overlapping with another doc | Consolidated into one canonical file |
| **Replace** | Stale or incorrect | Rewritten after user confirmation |
| **Create** | No equivalent exists | Generated from templates |

**Replace requires explicit user confirmation** — the skill will name the file, explain why it's stale, and wait for a yes before overwriting anything.

**Preservation rule for CLAUDE.md / DOC_INDEX.md:** If these files already exist, their routing tables and any project-specific rules are extracted before regeneration. The new versions carry forward anything that was accurate.

---

## Step 3 — REPO SCAN

Before writing a single word of documentation, the skill builds an internal model of the codebase. This is the step that makes documentation accurate rather than generic.

### What Gets Catalogued

```
Entry points       main.py, index.js, cmd/, app.py, server.ts
API layer          routes, controllers, handlers, middleware (note: auth? rate limiting?)
Service layer      orchestration, domain logic, business rules
Data models        ORM models, Pydantic, TypeScript interfaces, Protobuf
Config loading     .env.example, config/, settings, feature flags
AI / LLM layer     prompt templates, API call sites, parsers, validators, guardrails
Agent pipelines    multi-step workflows, orchestrators, tool use
Tests              unit, integration, contract, prompt regression (note coverage gaps)
Infrastructure     Dockerfile, k8s, terraform, CI/CD (note deploy process)
Jobs / workers     cron, queues, async processors
External clients   third-party API wrappers, SDKs
Schemas            data contracts, event formats, API response shapes
```

### What Gets Flagged

Three categories of findings get explicit flags in the generated documentation:

**Undocumented + high-risk:** auth layers with no tests, multi-tenant isolation logic, AI output consumers, payment flows. These get called out in the relevant sub-doc and in the Completion Report.

**Inferred:** behavior assumed from code patterns, not confirmed by tests or existing docs. For modes other than Express, the skill pauses and asks for confirmation before documenting inferred behavior as fact.

**Fragile:** tight coupling, no validation, silent failure paths, no retry logic. Flagged in the Known Gaps sections of the relevant sub-documents.

---

## Step 4 — SUB-DOCUMENT GENERATION

Each domain's reference file is loaded, then sub-documents are generated one at a time. Each file is completed fully before the next begins.

### Domain → Files Mapping

**Mode 1 (General) → `references/mode-docs.md`:**
```
/docs/general/README.md                   setup, quick start, configuration
/docs/general/CONTRIBUTING.md             dev workflow, PR process, test requirements
/docs/general/API_REFERENCE.md            all endpoints, auth, request/response shapes
/docs/general/MODULES.md                  module ownership, change-risk classification
/docs/general/ARCHITECTURE_OVERVIEW.md   infrastructure, external dependencies
/docs/general/CHANGELOG.md               version history
/docs/general/ADR_TEMPLATE.md            architecture decision records
```

**Mode 2 (AI / LLM) → `references/mode-ai.md`:**
```
/docs/ai/PROMPTS.md                       prompt inventory, templates, output contracts
/docs/ai/LLM_ARCHITECTURE.md             model providers, pipeline, retry/fallback
/docs/ai/AGENT_WORKFLOWS.md              agent logic, approval gates, autonomy levels
/docs/ai/MODEL_GUARDRAILS.md             injection defense, output validation, privacy
/docs/ai/AI_RUNBOOK.md                   monitoring, debugging, incident response
/docs/ai/PROMPT_TESTS.md                 prompt contract tests, regression cases
/docs/ai/LLM_COST_MODEL.md              token budget, cost per operation, optimization
/docs/ai/AGENT_SAFETY_MODEL.md          agent risk classification, safety constraints
```

**Mode 3 (Architecture) → `references/mode-architecture.md`:**
```
/docs/architecture/SYSTEM_OVERVIEW.md    component map, architecture style, security posture
/docs/architecture/REPOSITORY_MAP.md    module ownership, change-risk zones, reading order
/docs/architecture/RUNTIME_FLOWS.md     end-to-end execution traces, sequence diagrams
/docs/architecture/DEPENDENCY_MAP.md    internal + external dependency graph
/docs/architecture/DATA_CONTRACTS.md    critical schemas, breaking-change rules
```

**Mode 5 (Self-Heal) → `references/mode-self-heal.md`:**
```
/.cursor/rules/50-hierarchical-documentation.mdc
/.cursor/rules/51-auto-documentation-updates.mdc
/.github/workflows/docs-self-heal.yml
/.github/scripts/analyze_codebase_changes.py
/.github/scripts/detect_documentation_drift.py
/.github/scripts/generate_drift_report.py
/.github/scripts/update_documentation.py
/.github/scripts/verify_documentation_integrity.py
/.github/scripts/requirements.txt
/docs/DOC_AUTOMATION.md
```

### Required Header on Every Sub-Document

Every file generated in Step 4 starts with this block. It is not optional.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Index:  /DOC_INDEX.md -->
<!-- Related: /docs/path/related.md, /docs/path/other.md -->
<!-- Read when: [specific engineering scenario] -->

# Document Title

**Scope:** [what this doc covers | what it explicitly does NOT cover]
```

### Required Footer on Every Sub-Document

Every file generated in Step 4 ends with this block:

```markdown
---
## Known Gaps / Uncertainties

- [anything inferred rather than confirmed from code]
- [anything missing that a reader would reasonably expect]
- [pointer to related doc if topic bleeds into adjacent domain]
```

### Content Rules

These apply to every line written:

- **One canonical home per topic** — if detail exists in another sub-doc, link to it; never copy it
- **No folder names without purpose** — every path named must explain what breaks if it changes
- **Mermaid diagrams** for all flows, architectures, and agent workflows
- **Concrete schemas** — actual field names and types from the scanned codebase, not pseudo-JSON
- **RFC 2119 language** — MUST / MUST NOT / SHOULD / SHOULD NOT for all constraints
- **Security-first framing** — auth, isolation, injection risks, data leakage flagged wherever relevant
- **No hedging** — write with engineering confidence; state assumptions explicitly
- **Merge rule** — when extending an existing doc, preserve accurate content; add below; never overwrite

### Skip Logic

A file is skipped if the codebase provides no evidence for it. Examples:
- No LLM usage detected → `LLM_COST_MODEL.md` skipped
- No architecture decisions found → `ADR_TEMPLATE.md` skipped
- No external agents detected → `AGENT_WORKFLOWS.md` skipped

Every skipped file is listed in the Completion Report with the reason.

---

## Step 5 — CLAUDE.md Generation

CLAUDE.md is generated from the sub-documents written in Step 4. It is never generated from a template first and filled in later.

### What CLAUDE.md Contains

```
Line 1:   > For minimal context usage, read /DOC_INDEX.md first...
Section 1: System identity (1 paragraph — no marketing)
Section 2: Repository boundaries (in scope / out of scope)
Section 3: Architecture diagram (Mermaid, 8–12 nodes max)
Section 4: Entry points table
Section 5: Core runtime flows (2 lines per flow + link)
Section 6: High-risk areas (2–3 lines per zone + link)
Section 7: Documentation map (every sub-doc: file → what it covers → when to load)
Section 8: Documentation loading guide (task → ordered load list)
Section 9: Reading order for new engineers
Section 10: Rules for safe changes (checklist)
Section 11: Known unknowns (3–5 bullets, each linked to a sub-doc's Known Gaps section)
```

### What CLAUDE.md Must Not Contain

- Full module descriptions (those live in MODULES.md)
- Full prompt documentation (lives in PROMPTS.md)
- Full flow traces (live in RUNTIME_FLOWS.md)
- Any content that is duplicated in a sub-document

### Length Gate

Target 150–250 lines. Hard limit 300 lines. If exceeded, the overflow is identified, moved to the correct sub-document, and replaced with a 2-line summary + link.

### Link Verification

Before writing any link to a sub-document section (e.g., `/docs/ai/PROMPTS.md#output-contracts`), the skill verifies the section exists in the file just written. No orphan links.

---

## Step 6 — DOC_INDEX.md Generation

DOC_INDEX.md is generated from CLAUDE.md. It is the compressed routing layer — the file that AI assistants and engineers read before deciding which documents to load.

### What DOC_INDEX.md Contains

```
Top comment: "This file is the compressed routing layer..."
Repository identity: 3–5 lines (name, purpose, stack, architecture style)
Read-this-first pointer: → /CLAUDE.md
Documentation domains table: one row per domain, authoritative file per row
Task routing: task → ordered load list (5–8 task types)
High-risk areas: zone → why → which docs to load before changing
Do-not-load list: files that should only be loaded when directly relevant
Documentation rules (for AI assistants): 5 bullets
```

### What DOC_INDEX.md Must Not Contain

Architecture explanations, module descriptions, flow traces, or anything that already lives in CLAUDE.md or a sub-document. If you find yourself writing "the system uses X because Y" in DOC_INDEX.md, that sentence belongs in CLAUDE.md — not here.

### Length Gate

Target 80–150 lines. Hard limit 200 lines. Over 200 = content leaking from CLAUDE.md.

### Routing Consistency Rule

DOC_INDEX.md Task Routing and CLAUDE.md Section 8 (Documentation Loading Guide) must agree on which documents to load for each task. If they disagree, something was generated in the wrong order or a file was skipped without updating both.

---

## Step 7 — Completion Report

The report is printed in the conversation and contains five sections:

**Project Overview** — name, stack, architecture style, AI present, risk level, mode used, one-liner description of what the system does.

**Existing Docs Audit** — every doc found during the audit step, with its triage action and reason. Symbols: ✓ Reused, ↑ Extended, ⊕ Merged, ✗ Replaced, + Created, – Skipped.

**Files Generated** — every file written, with line count. Skipped files listed with the reason.

**Documentation Coverage** — progress bars per domain showing how many files were produced vs. the maximum possible for that domain.

**Key Findings** — specific problems found in the codebase that are not yet fixed: undocumented high-risk zones, missing tests, inconsistent retry policies, etc.

**Recommended Next Actions** — the three highest-priority gaps with specific file/line references where possible.

**Reading Order** — the five-step path for a new engineer joining the project.

---

## Mode 5 — Self-Heal CI Detail

Mode 5 generates two layers of automated documentation maintenance:

### Layer 1 — Cursor Rules (agent-side)

Two `.mdc` files that activate inside Cursor on every AI-assisted editing session:

**`50-hierarchical-documentation.mdc`** (`alwaysApply: true`) — enforces the three-layer hierarchy. Tells the Cursor agent to always start with DOC_INDEX.md, load only task-relevant docs, maintain length gates, use required headers/footers, and never duplicate content across layers.

**`51-auto-documentation-updates.mdc`** (`alwaysApply: true`) — tells the Cursor agent which documents to update for each type of code change. API change → update API_REFERENCE.md. New AI prompt → update PROMPTS.md + PROMPT_TESTS.md. Auth change → update API_REFERENCE.md#auth + MODEL_GUARDRAILS.md. Documentation updates are in the same commit as the code change, not deferred.

### Layer 2 — GitHub Actions CI (repo-side)

The workflow has three triggers:

| Trigger | Mode | What Happens |
|---------|------|-------------|
| Pull request | Check | Detect drift, report on PR, block merge on high severity |
| Nightly 2AM UTC | Update | Detect drift, update affected sections, commit with `[skip ci]` |
| Manual dispatch | Check or Update | Selected in GitHub Actions UI |

**Pipeline stages:**

1. `analyze_codebase_changes.py` — language-agnostic pattern detection using regex across all source files. No AI required. Detects new routes, services, models, AI prompts, agents, auth changes, config changes, schema changes. Output: `.github/codebase-changes.json`

2. `detect_documentation_drift.py` — Claude reads the change summary and current doc state, classifies drift by severity (high/medium/low), identifies affected files. Falls back to heuristic analysis if no API key. Output: `.github/drift-analysis.json`

3. `generate_drift_report.py` — converts drift analysis to human-readable markdown grouped by category. Posted as PR comment. Output: `.github/drift-report.md`

4. `update_documentation.py` — (update mode only) Claude surgically updates only the affected sections of each flagged document. The prompt explicitly requires `NO_UPDATE_NEEDED` or a full updated file — no diffs, no partial writes. Output: updated doc files in place.

5. `verify_documentation_integrity.py` — checks broken links in CLAUDE.md and DOC_INDEX.md, enforces length gates, checks sub-doc headers and footers. Exits with code 1 on critical failures (broken links, length gate violations), blocking the CI step.

---

## Design Decisions

**Why sub-docs first, index files last?**  
If CLAUDE.md were generated first from a template, its links would be speculative — pointing at files that might not exist or might be skipped. Generating it last guarantees every link is real. The same logic applies to DOC_INDEX.md, which is synthesized from CLAUDE.md.

**Why strict length gates?**  
CLAUDE.md and DOC_INDEX.md are loaded by AI assistants for every task. If they grow without bound, the token cost of every interaction goes up and the signal-to-noise ratio goes down. The length gates enforce the discipline: if a file exceeds its limit, detail is leaking from sub-documents, and the fix is to push that detail back down.

**Why `alwaysApply: true` on the Cursor rules?**  
Documentation drift happens gradually, one code change at a time. If the rule only fires when someone explicitly asks about documentation, it will be missed the 95% of the time when someone is just writing code. `alwaysApply: true` means the agent always knows which docs to update for which change, without needing to be reminded.

**Why block PR merge on high-severity drift?**  
A "warning" that doesn't gate anything is ignored. High-severity drift means architecture has changed without the navigation layer reflecting it — new engineers and AI assistants will work from a map that doesn't match the territory. The merge block makes the feedback loop immediate rather than deferred.

**Why conservative updates in the self-heal pipeline?**  
The `update_documentation.py` prompt instructs Claude to return `NO_UPDATE_NEEDED` or the complete updated file. It explicitly prohibits speculative content, requires marking unverified behavior, and prohibits regenerating the entire document. This prevents the automation from hallucinating architecture that doesn't exist or slowly degrading accurate documentation with each nightly run.
