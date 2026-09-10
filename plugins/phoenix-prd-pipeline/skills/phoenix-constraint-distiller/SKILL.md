---
name: phoenix-constraint-distiller
description: >
  Role 03 of the Phoenix Security spec pipeline. Distils SCOPE_DEFINITION into an
  ACTIVE_SET of 8–15 compact, testable constraints that govern all downstream requirements
  — drawing from Phoenix's 12 Standing Constraints (PSC-01 through PSC-12) covering
  AWS/GCP infra split, 12-person team capacity, multi-tenant isolation, integration
  surface, AI agent safety posture, and compliance hooks.
  Use this skill when you have a scope definition and need to produce the constraint set
  that locks down requirements, or when someone says "what are the constraints for this
  feature", "distil the active constraints", "what must always be true here", or
  "constraint layer for this spec". Always run after phoenix-scope-cutter and before
  phoenix-requirements-engineer.
---

# Phoenix Security — Constraint Distiller (Role 03)

**Token Budget**: ≤700 tokens
**Depends On**: Role 02 — SCOPE_DEFINITION
**Feeds Into**: Role 04 — Requirements Engineer
**Output**: `03-active-set.md`

---

## Phoenix Standing Constraints (PSC)

Evaluate all for inclusion. Include only those relevant to the current feature.

| ID | Constraint | Type | Proof Hint |
|----|-----------|------|-----------|
| PSC-01 | AWS = onboarding + core; GCP = Phoenix CTI + AI/LLM | operational | config/IaC |
| PSC-02 | Team = 12 people; no feature assumes >2 dedicated engineers | operational | planning |
| PSC-03 | Multi-tenant: customer data MUST be isolated at storage + query layer | security | test + static |
| PSC-04 | API ingestion MUST support: GitHub AS, Snyk, Qualys, Wiz minimum | functional | contract test |
| PSC-05 | Vuln prioritisation MUST incorporate reachability, not CVSS-only | functional | test |
| PSC-06 | All new endpoints MUST authenticate via Phoenix auth layer | security | static + test |
| PSC-07 | No direct competitor brand names in user-facing copy | compliance | manual review |
| PSC-08 | AI agents: assistive-only, disabled by default, no autonomous data ingestion | security | test + manual |
| PSC-09 | Customer data ingestion requires explicit opt-in | security/compliance | contract + manual |
| PSC-10 | Phoenix brand: ≤2 accent colors per visual; RFC 2119 in all specs | ux/doc | manual |
| PSC-11 | Container lineage: image build → registry → deployment MUST be preserved | functional | test |
| PSC-12 | Regulatory hooks: US (NIST) and UK (NCSC, Cyber Essentials) documented | compliance | manual |

---

## Core Rules
1. Constraints must be actionable and testable.
2. No duplicates — merge overlapping constraints.
3. No "nice-to-have" fluff.
4. Do not invent constraints; if suspected but unconfirmed → CONSTRAINT_OPEN_QUESTIONS.
5. Always include ≥1 security constraint (PSC-03 or PSC-06 or equivalent).
6. Always include ≥1 operational constraint reflecting team size (PSC-02 or equivalent).
7. If PSC-03 not included and feature touches customer data → flag as blocker.

---

## Output Schema

```markdown
---
meta:
  role: 03-constraint-distiller
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  status: complete | blocked
  next_role: 04-requirements-engineer
---

### ACTIVE_SET

#### ACTIVE_CONSTRAINTS (8–15)
- AC1: <constraint>
  (type: functional|reliability|ux|security|compliance|operational)
  (proof_hint: test|contract|static|manual)
  (source: PSC-NN | G?/IS?/D?)

#### CONSTRAINT_OPEN_QUESTIONS (max 7; blockers only)
- CQ1: ...
```

---

## Chaining
Save: `outputs/{session-id}/03-active-set.md`
→ Pass to: `phoenix-requirements-engineer` (Role 04)
