# Modes Reference — Project Documenter

Complete reference for all six modes: what each produces, when to use it, and example prompts.

---

## Mode 0 — Express

**Use when:** Brand new project, no existing documentation, want everything generated in one pass without answering questions mid-run.

**What it skips:** The audit step (nothing to audit) and all mid-run confirmation prompts.

**What it produces:** The full documentation pack — all 20 files across General, AI/LLM, and Architecture domains, plus CLAUDE.md and DOC_INDEX.md.

**Inferences:** Since Express asks no questions, anything inferred from the codebase (rather than confirmed by tests or docs) is documented explicitly as inferred and flagged in the relevant sub-doc's Known Gaps section.

**Example prompts:**
```
document this project — it's brand new, no existing docs
```
```
generate the full documentation pack for this repo
```
```
bootstrap documentation for this project
```

**Output tree:**
```
/DOC_INDEX.md
/CLAUDE.md
/docs/general/README.md
/docs/general/CONTRIBUTING.md
/docs/general/API_REFERENCE.md
/docs/general/MODULES.md
/docs/general/ARCHITECTURE_OVERVIEW.md
/docs/general/CHANGELOG.md
/docs/ai/PROMPTS.md              (if AI detected)
/docs/ai/LLM_ARCHITECTURE.md    (if AI detected)
/docs/ai/AGENT_WORKFLOWS.md     (if agents detected)
/docs/ai/MODEL_GUARDRAILS.md    (if AI detected)
/docs/ai/AI_RUNBOOK.md          (if AI detected)
/docs/ai/PROMPT_TESTS.md        (if AI detected)
/docs/ai/LLM_COST_MODEL.md      (if AI detected)
/docs/ai/AGENT_SAFETY_MODEL.md  (if agents detected)
/docs/architecture/SYSTEM_OVERVIEW.md
/docs/architecture/REPOSITORY_MAP.md
/docs/architecture/RUNTIME_FLOWS.md
/docs/architecture/DEPENDENCY_MAP.md
/docs/architecture/DATA_CONTRACTS.md
```

---

## Mode 1 — General

**Use when:** You need developer-facing documentation — setup, API reference, module map, contribution guide, changelog.

**What it produces:** 7 files under `/docs/general/`

**Includes audit step:** Yes. Existing README, CONTRIBUTING, CHANGELOG, and API docs are triaged and integrated rather than replaced.

**Example prompts:**
```
document this project — just the general developer docs
```
```
create a README and API reference for this project
```
```
generate contributing guide and module documentation
```

**Files produced:**

| File | Contents |
|------|---------|
| `README.md` | One-liner, prerequisites, quick start, architecture summary, key modules, config, tests, deployment |
| `CONTRIBUTING.md` | Dev setup, branching strategy, commit convention, PR process, test requirements, code style |
| `API_REFERENCE.md` | Every endpoint: method, path, auth, request/response schemas, error codes, rate limits |
| `MODULES.md` | Module ownership table, change-risk classification, what breaks downstream per module |
| `ARCHITECTURE_OVERVIEW.md` | Infrastructure, external dependencies, SPoFs, deployment pipeline |
| `CHANGELOG.md` | Version history (created from git history if accessible, or template) |
| `ADR_TEMPLATE.md` | Architecture Decision Record template (skipped if no decisions found) |

---

## Mode 2 — AI / LLM

**Use when:** Your project uses LLMs, AI agents, prompt templates, or model APIs and needs rigorous documentation of the AI layer.

**What it produces:** Up to 8 files under `/docs/ai/`

**Includes audit step:** Yes. Existing AI docs (PROMPTS.md, LLM docs, agent docs) are triaged and integrated.

**Example prompts:**
```
document the AI layer of this project
```
```
generate prompt documentation and model architecture docs
```
```
document how we use Claude in this system — prompts, guardrails, cost model
```

**Files produced:**

| File | Contents |
|------|---------|
| `PROMPTS.md` | Every prompt: name, purpose, location, inputs, output contract, template, example I/O, versioning, downstream consumers |
| `LLM_ARCHITECTURE.md` | Model providers, pipeline (context builder → prompt builder → LLM → parser → validator), retry/fallback, streaming vs batch |
| `AGENT_WORKFLOWS.md` | Per agent: purpose, trigger, workflow steps, Mermaid diagram, autonomy level, approval gates |
| `MODEL_GUARDRAILS.md` | Prompt injection defense, input sanitization, output validation, hallucination mitigation, data privacy, sensitive data handling |
| `AI_RUNBOOK.md` | Monitoring signals, debugging steps, model failure response, prompt update process, incident response |
| `PROMPT_TESTS.md` | Prompt contract tests, schema validation tests, adversarial input tests, regression policy |
| `LLM_COST_MODEL.md` | Token budget per operation, cost per call, monthly estimates, batching/caching/compression optimization strategies |
| `AGENT_SAFETY_MODEL.md` | Risk classification table (recommendation/automated/autonomous), safety constraints per risk level, incident handling |

**Skip conditions:**
- `LLM_COST_MODEL.md` skipped if no LLM usage detected
- `AGENT_WORKFLOWS.md` skipped if no agents detected
- `AGENT_SAFETY_MODEL.md` skipped if no autonomous agents detected

---

## Mode 3 — Architecture

**Use when:** You need engineering architecture documentation — system map, execution flows, data contracts, dependency graph.

**What it produces:** 5 files under `/docs/architecture/`

**Includes audit step:** Yes. Existing architecture docs are triaged and integrated.

**Example prompts:**
```
document the architecture of this project
```
```
create a system map and runtime flow documentation
```
```
reverse engineer this repo into architecture docs
```

**Files produced:**

| File | Contents |
|------|---------|
| `SYSTEM_OVERVIEW.md` | System identity, architecture style, component map (Mermaid), repo ownership, external dependencies, security model summary |
| `REPOSITORY_MAP.md` | Top-level structure (what each folder *does*, not just what it *is*), module ownership table, change-risk classification, safe vs. high-risk zones, reading order, change playbook |
| `RUNTIME_FLOWS.md` | End-to-end execution traces for every critical flow: trigger, steps, sequence diagram (Mermaid), failure impact, retry behavior. Background/async flows catalogued separately. |
| `DEPENDENCY_MAP.md` | Internal module dependency graph (Mermaid), external service dependencies table (purpose, failure mode, fallback, SLA), dependency health |
| `DATA_CONTRACTS.md` | Every critical schema: field names/types from actual codebase, producers, consumers, validation rules, breaking-change policy, schema evolution rules |

---

## Mode 4 — Full

**Use when:** A mature project with existing documentation needs auditing, consolidation, and a complete documentation system.

**What it does differently from Mode 0:**
- Runs the full audit step on all existing docs
- Merges overlapping documents rather than duplicating
- Preserves accurate content in existing files
- Requires user confirmation before replacing any file
- Produces a detailed audit log in the Completion Report

**What it produces:** All files from Modes 1 + 2 + 3 + CLAUDE.md + DOC_INDEX.md (up to 22 files).

**Example prompts:**
```
document this project — it has existing docs that need updating
```
```
audit and consolidate our documentation
```
```
generate the full documentation pack, preserving what already exists
```

**Audit actions:**

| Symbol | Action | What Happens |
|--------|--------|-------------|
| ✓ Reused | Accurate, well-structured | Kept, cross-linked from CLAUDE.md |
| ↑ Extended | Accurate but incomplete | New sections added below existing content |
| ⊕ Merged | Overlapping with another doc | Consolidated into one canonical file |
| ✗ Replaced | Stale or incorrect | Rewritten after user confirms |
| + Created | No equivalent exists | Generated from templates |

---

## Mode 5 — Self-Heal

**Use when:** You want documentation to stay automatically in sync with code as the project evolves.

**Prerequisites:** CLAUDE.md and DOC_INDEX.md must already exist. Run Mode 0 or Mode 4 first.

**What it produces:** 10 files — two Cursor rules, one GitHub Actions workflow, five Python scripts, requirements.txt, and DOC_AUTOMATION.md.

**Example prompts:**
```
add self-healing documentation CI to this project
```
```
create cursor rules and github actions for auto doc updates
```
```
set up the documentation drift detection pipeline
```

**Files produced:**

| File | Purpose |
|------|---------|
| `.cursor/rules/50-hierarchical-documentation.mdc` | Cursor rule: enforce three-layer hierarchy on every AI edit |
| `.cursor/rules/51-auto-documentation-updates.mdc` | Cursor rule: define which docs to update for each code change type |
| `.github/workflows/docs-self-heal.yml` | GitHub Actions: PR check + nightly update + manual dispatch |
| `.github/scripts/analyze_codebase_changes.py` | Detect structural changes via regex (no AI required) |
| `.github/scripts/detect_documentation_drift.py` | Claude compares changes to current docs, classifies severity |
| `.github/scripts/generate_drift_report.py` | Convert drift analysis to markdown for PR comments |
| `.github/scripts/update_documentation.py` | Surgically update only affected doc sections |
| `.github/scripts/verify_documentation_integrity.py` | Broken link check, length gates, header/footer validation |
| `.github/scripts/requirements.txt` | `anthropic`, `openai`, `tiktoken` |
| `docs/DOC_AUTOMATION.md` | Living operations guide for the self-heal system |

**Recommended run order for a new project:**

```
1. Mode 0 Express  →  generate full documentation pack
2. Mode 5          →  add CI automation to keep it in sync
```

**Cursor rules take effect immediately** — restart Cursor to load the new `.mdc` files.

**CI pipeline activates on next push to GitHub** — no additional configuration needed beyond adding `ANTHROPIC_API_KEY` to GitHub Secrets.

---

## Choosing the Right Mode

```
New project, no docs?
  → Mode 0 Express

Existing project, need developer docs?
  → Mode 1 General

Existing project, need AI layer documented?
  → Mode 2 AI / LLM

Existing project, need architecture documented?
  → Mode 3 Architecture

Existing project, need everything audited and updated?
  → Mode 4 Full

Want docs to stay in sync automatically?
  → Run Mode 0 or 4 first, then Mode 5
```

---

## Combining Modes

You can run multiple modes in sequence within the same session:

```
Run Mode 3 first — get the architecture docs
Then run Mode 2 — add the AI layer on top
Then run Mode 5 — add CI automation
```

Each run audits what already exists before adding anything new, so combining modes is safe and non-destructive.
