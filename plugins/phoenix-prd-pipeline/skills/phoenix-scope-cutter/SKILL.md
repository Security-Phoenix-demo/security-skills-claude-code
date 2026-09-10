---
name: phoenix-scope-cutter
description: >
  Role 02 of the Phoenix Security spec pipeline. Converts CLEAN_CONTEXT into an explicit,
  minimal SCOPE_DEFINITION — goals, non-goals, in/out boundaries, assumptions, success
  metrics, and gating questions — anchored to Phoenix's product pillars and 12-person
  team constraints. Use this skill when you have a cleaned context block and need to define
  what the feature actually is and isn't, prevent scope spiral, or when someone says
  "define the scope", "what are we building vs not building", "set the boundaries for this
  feature", or "trim the scope". Always run after phoenix-context-curator and before
  phoenix-constraint-distiller.
---

# Phoenix Security — Scope Cutter (Role 02)

**Token Budget**: ≤800 tokens
**Depends On**: Role 01 — CLEAN_CONTEXT
**Feeds Into**: Role 03 — Constraint Distiller
**Output**: `02-scope-definition.md`

---

## Phoenix Scope Anchors

Every goal MUST map to at least one Phoenix product pillar:

| Pillar | Scope signals |
|--------|--------------|
| ASPM | Posture scoring, risk aggregation, multi-tool ingestion |
| CTEM | Exposure tracking, prioritisation loops, remediation workflows |
| Container Lineage | Image → deployment → vuln tracing |
| Reachability | Code-path analysis, false-positive reduction |
| Supply Chain / SCA | SBOM, dependency graph, Snyk integration |
| DevSecOps | CI/CD gating, shift-left, Jenkins / GitHub Actions |
| LLM Security | AI model risk, prompt injection surface |
| Board-Level Reporting | 10-category risk, exec dashboards, compliance mapping |

## Team Constraint
12-person team. Any scope implying >2 sprint capacity without P0 justification → flag for @Alfonso Eusebio.

## Success Metric Benchmarks
- Vuln reduction: ClearBank 98%, Bazaarvoice 94%
- False positive reduction: IAS 78%
- Cost savings: ClearBank $15M, Bazaarvoice $6.3M, IAS $1.7M+
- Rule auto-mapping: Bazaarvoice 32K via Backstage

---

## Core Rules
1. Do not invent features, integrations, policies, or architecture.
2. Every NON_GOAL must be explicit — silence is not a boundary.
3. Flag scope touching active enterprise accounts (Mimecast, JM, Anaplan) → P0 by default.
4. Flag anything implying competitive positioning vs Prisma/Wiz/Snyk → route to @Francesco Cipollone.
5. If GOALS cannot be stated from input, output only SCOPE_OPEN_QUESTIONS.

---

## Output Schema

```markdown
---
meta:
  role: 02-scope-cutter
  timestamp: [ISO 8601]
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  status: complete | blocked | needs-input
  validation: passed | failed
  next_role: 03-constraint-distiller
---

### SCOPE_DEFINITION

#### GOALS (max 6)
- G1: ... (pillar: ASPM|CTEM|Container Lineage|Reachability|SCA|DevSecOps|LLM|Reporting)

#### NON_GOALS (max 6)
- NG1: ...

#### IN_SCOPE (max 10)
- IS1: ...

#### OUT_OF_SCOPE (max 10)
- OS1: ...

#### ASSUMPTIONS (max 6; map to FACT/DECISION IDs)
- A1: ... (based_on: F? / D?)

#### SUCCESS_METRICS (max 5; quantified where possible)
- SM1: ... (benchmark: ClearBank|Bazaarvoice|IAS|new)

#### SCOPE_OPEN_QUESTIONS (max 7; blockers only)
- SQ1: ...

#### ENTERPRISE_FLAGS (only if active accounts affected)
- EF1: <account> → <impact> → <escalation: @Francesco|@Alfonso|@Philip>
```

---

## Chaining
Save: `outputs/{session-id}/02-scope-definition.md`
→ Pass to: `phoenix-constraint-distiller` (Role 03)
