---
name: phoenix-orchestrator
description: >
  Run the full Phoenix Security spec pipeline (roles 01–10) from raw context to a
  ship-ready PRD — automatically chaining context curation, scope cutting, constraint
  distillation, requirements engineering, ambiguity hunting, security threat modelling,
  contract design, verification mapping, batch planning, and final gate review.
  Use this skill whenever someone says "run the spec pipeline", "build a PRD end to end",
  "run all the roles", "full pipeline on this feature", or provides raw notes/tickets and
  wants a complete Phoenix Security product spec. Also trigger when the user uploads raw
  context (Slack threads, customer call notes, feature ideas) and asks Claude to turn it
  into a spec, plan, or PRD. This is the master runner — use it over individual role skills
  when the full pipeline is needed.
---

# Phoenix Security — Pipeline Orchestrator

## What This Does
Runs roles 01–10 sequentially, validates each output, manages the 04↔05 iteration loop,
and produces a ship-ready Phoenix PRD + Cursor plan + Confluence page.

---

## Phoenix Domain Context (carry through every role)

### Product Pillars
ASPM · CTEM · Container Lineage · Reachability Analysis · Supply Chain / SCA · DevSecOps · LLM Security · Board-Level Reporting

### Active Integrations
GitHub Advanced Security, Snyk (SCA eval), Qualys, Prisma (being displaced), Wiz (replacing Prisma at Anaplan), Azure Security Center, Backstage, Jenkins, AWS (core), GCP (CTI + AI)

### Key Stakeholders
| Role | Name |
|------|------|
| CEO / Product Owner | Francesco Cipollone |
| CTO | Alfonso Eusebio |
| CRO | Philip Moroni |

### Active Enterprise Accounts
- **Mimecast** — replacing Prisma, Snyk SCA eval, multi-cloud + on-prem, container lineage
- **Johnson Matthey** — OT/manufacturing, GitHub AS + Azure SC + Qualys, reachability + maturity model
- **Anaplan** — Prisma → Wiz, Jenkins gating, board-level risk reporting (10 categories)

### Case Study Benchmarks
- ClearBank: 98% container vuln reduction, $15M dev time saved
- Bazaarvoice: 94% container reduction, $6.3M saved, 32K rules via Backstage
- IAS: 78% false positive reduction, $1.7M+ saved

### Competitors (handle carefully in external content)
Prisma · Wiz · ArmorCode · Snyk

---

## Pipeline Execution Flow

### Phase 1 — Foundation (Roles 01–03)
```
Raw Context
  → [01] Context Curator      → CLEAN_CONTEXT (≤900 tokens)
  → [02] Scope Cutter         → SCOPE_DEFINITION (≤800 tokens)
  → [03] Constraint Distiller → ACTIVE_SET (≤700 tokens)
```

### Phase 2 — Requirements Loop (Roles 04–05, max 3 iterations)
```
  → [04] Requirements Engineer → NORMATIVE_REQUIREMENTS (≤1500 tokens)
  → [05] Ambiguity Hunter      → CLARIFICATIONS
       If critical > 0 → back to [04] (max 3 iterations)
       If critical = 0 → Phase 3
```

### Phase 3 — Security & Contracts (Roles 06–07)
```
  → [06] Security Engineer    → SECURITY_REQUIREMENTS (≤1200 tokens)
  → [07] Contract Architect   → CONTRACTS (≤1200 tokens)
```

### Phase 4 — Verification & Planning (Roles 08–09)
```
  → [08] Verification Matrix  → VERIFICATION_MATRIX (≤1000 tokens)
  → [09] Batch Planner        → BATCH_PLAN (≤1200 tokens)
```

### Phase 5 — Final Decision (Role 10)
```
  → [10] Final Gate           → SHIP | NO_SHIP (≤800 tokens)
       If SHIP   → compile FEATURE_SPEC.md + push Confluence + ask about Linear/Slack
       If NO_SHIP → list blockers, still produce all files, mark PRD BLOCKED
```

---

## Validation Rules (apply after each role)
- Token budget not exceeded
- All required sections present
- IDs sequential
- Status set
- PSC-03 (multi-tenancy) addressed whenever customer data flows exist
- PSC-06 (auth) addressed for any new endpoint
- PSC-08 (AI agent) addressed for any LLM component

---

## Output Structure
```
outputs/session-{timestamp}/
  01-clean-context.md
  02-scope-definition.md
  03-active-set.md
  04-requirements-v{N}.md
  05-clarifications-v{N}.md
  06-security.md
  07-contracts.md
  08-verification-matrix.md
  09-batch-plan.md
  10-final-gate.md
  FEATURE_SPEC.md              ← Phoenix PRD template (if SHIP)
  {slug}-cursor-plan.md        ← .cursor/plans drop-in
```

---

## Post-Pipeline Connectors
Always push to Confluence (SPM space, fallback parent ID: 1273987073).
After SHIP, ask once: *"Want me to also create Linear/Asana tickets, notify Slack, or email stakeholders?"*

| Connector | Action |
|-----------|--------|
| Atlassian | Push PRD to SPM space — always |
| Slack | Post Confluence link + 2-line summary |
| Linear | Create issues per batch (P0=urgent, P1=medium, P2=low) |
| Asana | Create tasks per batch under feature project |
| Notion | Mirror under "Product Features" |
| Gmail | Draft: exec summary + Confluence link + P0 req list |

---

## Writing Standards (enforced at every role)
- RFC 2119: MUST / MUST NOT / SHOULD / MAY
- Req IDs: R-FUNC-001, R-SEC-001, R-REL-001, R-UX-001, R-INT-001
- Priority: [P0] / [P1] / [P2]
- `maps_to: AC#` on every functional requirement
- Voice: direct, no filler, security-first — Francesco Cipollone style
- Banned: "In conclusion", "Furthermore", "Moreover", "In today's rapidly evolving", "cybersecurity landscape", "It is important to note"
- Max 1 emoji per document
