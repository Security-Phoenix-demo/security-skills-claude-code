---
name: project-documenter
description: >
  Generate production-grade documentation for any software project. Supports five modes:
  (0) Express — full pack in one run for new projects; (1) General — README, API docs, modules,
  changelog; (2) AI/LLM — PROMPTS, LLM_ARCHITECTURE, MODEL_GUARDRAILS, AGENT_WORKFLOWS, AI_RUNBOOK;
  (3) Architecture — SYSTEM_OVERVIEW, RUNTIME_FLOWS, DATA_CONTRACTS, DEPENDENCY_MAP;
  (4) Full — all modes with existing-docs audit and integration.
  Always produces DOC_INDEX.md (compressed routing layer), CLAUDE.md (navigation index), and all
  sub-documents. Ends with a Completion Report listing every file created/updated/skipped.
  Trigger when user says: document this project, generate documentation, create docs for,
  document the AI layer, document the architecture, reverse engineer this repo,
  full doc pack, new project docs, bootstrap documentation, create system map,
  self-healing documentation, add ci docs, cursor rules for docs, github actions for docs,
  or points to a repo and wants comprehensive documentation produced.
---

# Project Documenter

Generates a three-layer, AI-native documentation hierarchy for any software repository.

```
Layer 1  DOC_INDEX.md    — compressed routing layer (~1–2k tokens)
Layer 2  CLAUDE.md       — engineering navigation map (150–300 lines)
Layer 3  /docs/**        — authoritative domain sub-documents (all detail here)
```

**Core law:** Sub-documents hold all detail. CLAUDE.md routes to sub-docs. DOC_INDEX.md routes to
CLAUDE.md. Nothing is ever duplicated across layers. Both CLAUDE.md and DOC_INDEX.md are generated
LAST, synthesized from what was actually written.

---

## EXECUTION SEQUENCE — mandatory order, no exceptions

```
1. INTAKE        — Select mode, confirm existing-doc situation
2. AUDIT         — Scan + triage every existing doc (skip only for Mode 0)
3. REPO SCAN     — Build internal codebase model
4. SUB-DOCS      — Generate all domain documents (depth first)
5. CLAUDE.md     — Synthesize navigation index from sub-docs
6. DOC_INDEX.md  — Synthesize compressed routing layer from CLAUDE.md
7. REPORT        — Completion report + present_files
```

---

## Step 1 — INTAKE

Ask two questions. Do not proceed until both are answered.

### Q1 — Mode

```
How should I run this?

  [0] Express       — Brand new project, no existing docs.
                      Full pack in one run, no audit step, no questions mid-run.

  [1] General       — README, CONTRIBUTING, API_REFERENCE, MODULES, CHANGELOG, ADRs

  [2] AI / LLM      — PROMPTS, LLM_ARCHITECTURE, AGENT_WORKFLOWS, MODEL_GUARDRAILS,
                      AI_RUNBOOK, PROMPT_TESTS, LLM_COST_MODEL, AGENT_SAFETY_MODEL

  [3] Architecture  — SYSTEM_OVERVIEW, REPOSITORY_MAP, RUNTIME_FLOWS,
                      DEPENDENCY_MAP, DATA_CONTRACTS

  [4] Full          — All three domains + audit of any existing docs
  [5] Self-Heal     — Cursor .mdc rules + GitHub Actions CI + Python scripts
                      (drift detection, targeted updates, integrity verification)
                      Requires: CLAUDE.md and DOC_INDEX.md already exist.
                      Run Mode 0 or Mode 4 first if starting from scratch.
```

**Mode 0 note:** Express mode skips the audit step entirely (nothing to audit), runs all three
domains in one pass, generates CLAUDE.md and DOC_INDEX.md, and asks no further questions.
It is the fastest path for a greenfield project.

### Q2 — Existing docs (skip for Mode 0)

```
Does this project have existing documentation?

  [A] No docs — start fresh
  [B] Partial docs — integrate and extend
  [C] Substantial docs — audit, consolidate, update
```

If B or C: ask where the docs live (path, uploaded files, wiki URL, or pasted content).
If no codebase provided: ask for repo path, file upload, or pasted code before proceeding.

---

## Step 2 — AUDIT EXISTING DOCUMENTATION

**Skip this step only for Mode 0.** All other modes run it, even when user selects [A].

### Scan checklist

```
□ README.md / README.rst / README.txt
□ CONTRIBUTING.md
□ CHANGELOG.md / HISTORY.md / RELEASES.md
□ DOC_INDEX.md (if already present — read it fully, preserve routing rules)
□ CLAUDE.md (if already present — read it fully, extract routing + architecture summaries)
□ /docs/** — all files, all subdirectories
□ /architecture/, /arch/, /design/, /decisions/
□ ADRs — any numbered decision records
□ Runbooks, playbooks, incident docs
□ AI-specific docs — PROMPTS.md, LLM_ARCHITECTURE.md, MODEL_GUARDRAILS.md, etc.
□ OpenAPI / Swagger specs (.yaml, .json in any directory)
□ Root-level .md files — SECURITY.md, CODE_OF_CONDUCT.md, etc.
□ Config comments that function as documentation
```

### Triage table — produce this before writing anything

| File | Quality | Current? | Action | Reason |
|------|---------|----------|--------|--------|
| README.md | Good | Yes | **Reuse + extend** | Accurate, needs API section |
| /docs/old_arch.md | Poor | No | **Replace** | References retired services |
| PROMPTS.md | Partial | Yes | **Merge** | Absorb into /docs/ai/PROMPTS.md |
| — | — | — | **Create** | No equivalent exists |

**Action definitions:**
- **Reuse** — accurate, well-structured → keep as-is, cross-link from CLAUDE.md
- **Extend** — accurate but incomplete → add sections below existing content
- **Merge** — overlapping content → consolidate into one canonical file, deprecate others
- **Replace** — stale or incorrect → rewrite; get user confirmation before overwriting
- **Create** — no equivalent → generate from templates in reference files

**Replace rule:** If any doc is marked Replace, tell the user the file path and reason, and
get explicit confirmation before overwriting. Do not proceed without it.

**Preservation rule:** If DOC_INDEX.md or CLAUDE.md already exist, extract their routing tables
and custom rules. The new versions are regenerated from scratch but must carry forward any
project-specific routing that was accurate.

---

## Step 3 — REPO SCAN

Build an internal codebase model. Document what modules *do*, not what folders *are*.

```
□ Entry points       — main.py, index.js, cmd/, app.py, server.ts
□ API layer          — routes, controllers, handlers, middleware (auth? rate limiting?)
□ Service layer      — orchestration, domain logic, business rules
□ Data models        — ORM models, Pydantic, TypeScript interfaces, Protobuf
□ Config loading     — .env.example, config/, settings, feature flags
□ AI / LLM layer     — prompt templates, API call sites, parsers, validators, guardrails
□ Agent pipelines    — multi-step workflows, orchestrators, tool use
□ Tests              — unit, integration, contract, prompt regression; note coverage gaps
□ Infrastructure     — Dockerfile, k8s, terraform, CI/CD; note deploy process
□ Jobs / workers     — cron, queues, async processors
□ External clients   — third-party API wrappers, SDKs
□ Schemas            — data contracts, event formats, API response shapes
```

**Flag anything that is:**
- **Undocumented + high-risk** — auth, multi-tenancy, AI output consumers, payment flows
- **Inferred** — behavior assumed from code, not confirmed by docs or tests
- **Fragile** — tight coupling, no validation, silent failure paths, no retry logic

For inferences: ask the user to confirm before documenting as fact.
For Mode 0: document inferences as explicitly inferred, flag them in sub-doc Known Gaps sections.

---

## Step 4 — GENERATE SUB-DOCUMENTS

Read the reference file for each active mode *before* generating its files.
Complete each domain fully before starting the next.

### Mode → Reference File → Output files

| Mode | Reference File | Sub-documents produced |
|------|---------------|------------------------|
| 0 — Express | All three below | All files from modes 1+2+3 |
| 1 — General | `references/mode-docs.md` | README, CONTRIBUTING, API_REFERENCE, MODULES, ARCHITECTURE_OVERVIEW, CHANGELOG, ADR_TEMPLATE |
| 2 — AI / LLM | `references/mode-ai.md` | PROMPTS, LLM_ARCHITECTURE, AGENT_WORKFLOWS, MODEL_GUARDRAILS, AI_RUNBOOK, PROMPT_TESTS, LLM_COST_MODEL, AGENT_SAFETY_MODEL |
| 3 — Architecture | `references/mode-architecture.md` | SYSTEM_OVERVIEW, REPOSITORY_MAP, RUNTIME_FLOWS, DEPENDENCY_MAP, DATA_CONTRACTS |
| 4 — Full | All three above | All files above |
| 5 — Self-Heal | `references/mode-self-heal.md` | `.cursor/rules/50-hierarchical-documentation.mdc`, `.cursor/rules/51-auto-documentation-updates.mdc`, `.github/scripts/*.py`, `.github/workflows/docs-self-heal.yml`, `docs/DOC_AUTOMATION.md` |

### Required header — every sub-document starts with this

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Index:  /DOC_INDEX.md -->
<!-- Related: [comma-separated doc paths] -->
<!-- Read when: [specific engineering scenario] -->

# [DOCUMENT TITLE]

**Scope:** [what this doc covers | what it explicitly does NOT cover]
```

### Required footer — every sub-document ends with this

```markdown
---
## Known Gaps / Uncertainties

- [anything inferred rather than confirmed from code]
- [anything missing that a reader would reasonably expect]
- [pointer to related doc if topic bleeds into another domain]
```

### Content rules (non-negotiable)

- **One canonical home per topic** — if detail exists in another sub-doc, link; do not copy
- **No folder names without purpose** — every path mentioned must explain what breaks if it changes
- **Mermaid diagrams** for all flows, architectures, and agent workflows
- **Concrete schemas** — actual field names and types from the codebase, not pseudo-JSON
- **RFC 2119** — MUST / MUST NOT / SHOULD / SHOULD NOT for all constraints and guardrails
- **Security-first** — flag auth, isolation, injection risks, data leakage wherever relevant
- **No hedging** — write with engineering confidence; state assumptions explicitly
- **Merge rule** — if extending or merging an existing doc, preserve accurate content;
  add new sections below existing ones; do not overwrite what is correct

### Output directory structure

```
/DOC_INDEX.md                                  ← NOT yet — Step 6
/CLAUDE.md                                     ← NOT yet — Step 5

/docs/general/
  README.md
  CONTRIBUTING.md
  API_REFERENCE.md
  MODULES.md
  ARCHITECTURE_OVERVIEW.md
  CHANGELOG.md
  ADR_TEMPLATE.md

/docs/ai/
  PROMPTS.md
  LLM_ARCHITECTURE.md
  AGENT_WORKFLOWS.md
  MODEL_GUARDRAILS.md
  AI_RUNBOOK.md
  PROMPT_TESTS.md
  LLM_COST_MODEL.md
  AGENT_SAFETY_MODEL.md

/docs/architecture/
  SYSTEM_OVERVIEW.md
  REPOSITORY_MAP.md
  RUNTIME_FLOWS.md
  DEPENDENCY_MAP.md
  DATA_CONTRACTS.md
```

**Only create files justified by the actual codebase.** Skipped files are noted in the
Completion Report with the reason (e.g., "No LLM usage detected — LLM_COST_MODEL.md skipped").

---

## Step 5 — GENERATE CLAUDE.md

Read `references/mode-claude-md.md` for the exact structure and content rules.

**Synthesized from sub-documents just written — not from a template.**
Every link must point to a file that was actually created in Step 4.

**What CLAUDE.md contains:** System identity (1 paragraph) · Repo boundaries · Architecture
diagram (concise Mermaid) · Documentation map (file → what it covers → when to load) ·
Task-based loading guide · High-risk zones summary (2–3 lines, link to sub-doc) ·
Reading order · Known unknowns (3–5 bullets, link to detail)

**What CLAUDE.md must NOT contain:** Full module descriptions · Full prompt docs ·
Full flow traces · Any content that duplicates a sub-document

**First line of CLAUDE.md must be:**
```markdown
> For minimal context usage, read `/DOC_INDEX.md` first, then load only the documents needed for your task.
```

**Length gate:** Target 150–250 lines. Hard limit 300 lines. Over 300 = content leaking
from sub-docs. Move it back and replace with a 2-line summary + link.

---

## Step 6 — GENERATE DOC_INDEX.md

Read `references/mode-doc-index.md` for the exact structure and content rules.

**Synthesized from CLAUDE.md — generated after CLAUDE.md, before the report.**
DOC_INDEX.md is the compressed routing layer that sits *above* CLAUDE.md.

**Purpose:** Help AI assistants and engineers decide which docs to load without pulling the
full documentation set into context. A reader should be able to open DOC_INDEX.md, identify
their task, get an ordered load list, and close it — all in under 30 seconds.

**What DOC_INDEX.md contains:** Repository identity (3–5 lines max) · Documentation domains
with authoritative file per domain · Task-based routing (task → ordered load list) ·
High-risk areas (load deeper docs before changing) · Explicit do-not-load list ·
Single hint pointing to CLAUDE.md for full detail

**What DOC_INDEX.md must NOT contain:** Architecture explanation · Module descriptions ·
Flow traces · Any content that belongs in CLAUDE.md or sub-docs

**Length gate:** Target 80–150 lines. Hard limit 200 lines. This is a router, not a map.
If it exceeds 200 lines, content is leaking from CLAUDE.md — move it back.

---

## Step 7 — COMPLETION REPORT

Print in the conversation, then call `present_files` with all generated files.

```
╔══════════════════════════════════════════════════════════════════╗
║              PROJECT DOCUMENTATION — COMPLETION REPORT           ║
╚══════════════════════════════════════════════════════════════════╝

PROJECT OVERVIEW
────────────────
Name:         [detected project name]
Stack:        [language / framework / infra]
Architecture: [monolith / microservice / event-driven / agent-based / hybrid]
AI Present:   [yes — providers / no]
Risk Level:   [low / medium / high]
Mode:         [0 Express / 1 General / 2 AI / 3 Architecture / 4 Full / 5 Self-Heal]
One-liner:    [what this system actually does]

EXISTING DOCS AUDIT
───────────────────
[✓ Reused]    /README.md               — accurate, cross-linked from CLAUDE.md
[↑ Extended]  /docs/api.md             — added auth + error code sections
[⊕ Merged]    /arch1.md + /arch2.md   → /docs/architecture/SYSTEM_OVERVIEW.md
[✗ Replaced]  /docs/old_runbook.md     — referenced decommissioned infra (2022)
[+ Created]   /docs/ai/PROMPTS.md      — no equivalent existed
[– Skipped]   (Mode 0 — no audit)

FILES GENERATED
───────────────
[✓] /DOC_INDEX.md                                   [N lines]  compressed routing layer
[✓] /CLAUDE.md                                      [N lines]  navigation index
[✓] /docs/architecture/SYSTEM_OVERVIEW.md           [N lines]
[✓] /docs/architecture/RUNTIME_FLOWS.md             [N lines]
[✓] /docs/architecture/REPOSITORY_MAP.md            [N lines]
[✓] /docs/architecture/DATA_CONTRACTS.md            [N lines]
[✓] /docs/architecture/DEPENDENCY_MAP.md            [N lines]
[✓] /docs/ai/PROMPTS.md                             [N lines]
[✓] /docs/ai/LLM_ARCHITECTURE.md                    [N lines]
[✓] /docs/ai/MODEL_GUARDRAILS.md                    [N lines]
[✓] /docs/ai/AI_RUNBOOK.md                          [N lines]
[✓] /docs/general/README.md                         [N lines]
[✓] /docs/general/API_REFERENCE.md                  [N lines]
[✓] /docs/general/MODULES.md                        [N lines]
... (complete list of every file)
[–] /docs/ai/LLM_COST_MODEL.md          SKIPPED — no LLM usage detected
[–] /docs/general/ADR_TEMPLATE.md       SKIPPED — no architecture decisions found

SELF-HEAL CI FILES (Mode 5)
────────────────────────────
[✓] /.cursor/rules/50-hierarchical-documentation.mdc     [N lines]
[✓] /.cursor/rules/51-auto-documentation-updates.mdc     [N lines]
[✓] /.github/workflows/docs-self-heal.yml                [N lines]
[✓] /.github/scripts/analyze_codebase_changes.py         [N lines]
[✓] /.github/scripts/detect_documentation_drift.py       [N lines]
[✓] /.github/scripts/generate_drift_report.py            [N lines]
[✓] /.github/scripts/update_documentation.py             [N lines]
[✓] /.github/scripts/verify_documentation_integrity.py   [N lines]
[✓] /.github/scripts/requirements.txt
[✓] /docs/DOC_AUTOMATION.md                              [N lines]
(omit this section if Mode 5 was not run)

DOCUMENTATION COVERAGE
──────────────────────
General       ██████████░░  86%   (6/7 — ADR skipped)
AI Layer      ████████████ 100%   (8/8)
Architecture  ████████████ 100%   (5/5)
Index Layer   ████████████ 100%   (DOC_INDEX.md + CLAUDE.md)
Self-Heal     ████████████ 100%   (10/10 — .mdc rules + CI workflow + scripts)
              (omit if Mode 5 not run)

KEY FINDINGS
────────────
• [e.g., "3 prompt templates found with no output validation or schema contract"]
• [e.g., "Auth middleware is present but has no contract tests"]
• [e.g., "Queue retry policy appears inconsistent across two workers"]

RECOMMENDED NEXT ACTIONS
────────────────────────
1. [Highest-priority gap — specific file/line if possible]
2. [Second priority]
3. [Third priority]

READING ORDER (new engineer)
─────────────────────────────
1. /DOC_INDEX.md          — 2 min, pick your task
2. /CLAUDE.md             — 10 min, understand the system
3. /docs/architecture/SYSTEM_OVERVIEW.md
4. /docs/general/README.md — run it locally
5. [next most relevant sub-doc for the engineer's role]
```

---

## Setup Required After Mode 5

Tell the user these steps are required before the CI pipeline will work:

```
1. Add ANTHROPIC_API_KEY to GitHub Secrets
   → Settings → Secrets and variables → Actions → New repository secret

2. (Optional) Add OPENAI_API_KEY as fallback

3. Test locally before first push:
   export ANTHROPIC_API_KEY="sk-ant-..."
   python .github/scripts/analyze_codebase_changes.py
   python .github/scripts/detect_documentation_drift.py
   cat .github/drift-report.md

4. Confirm the merge-blocking behavior is acceptable:
   High-severity drift on a PR will block merge via exit 1.
   To disable: remove the last step in docs-self-heal.yml.

5. Cursor rules take effect immediately — no setup needed.
   Restart Cursor to load the new .mdc rules.
```

---

## Handling Missing Context

Ask targeted questions rather than inventing architecture:

- "I see prompt templates but no response parser — where is LLM output validated?"
- "I found API routes but no auth middleware — is authentication handled upstream?"
- "The orchestrator has retry logic but no fallback model configured — intentional?"
- "There are database models but no migration files — is schema managed externally?"

**Mode 0 exception:** Do not stop to ask questions during Express mode. Instead, document
inferences explicitly in the relevant sub-doc's Known Gaps section and note them in Key Findings.
