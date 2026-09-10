---
name: phoenix-batch-planner
description: >
  Role 09 of the Phoenix Security spec pipeline. Slices a Phoenix Security feature into
  safe, incremental batches sized for a 12-person team (1–3 engineer-days each), with
  P0 security requirements always in Batch 1, API contracts before consumers, integrations
  last, explicit rollback strategies for irreversible steps, AI gate flags for LLM-touching
  batches, and a Cursor plan summary for direct drop into .cursor/plans/.
  Use this skill when you have verified requirements and contracts and need a delivery plan,
  or when someone says "create the implementation plan", "batch this up", "how do we build
  this", "create the delivery batches", "sprint plan for this feature", or "cursor plan".
  Always run after phoenix-verification-matrix and before phoenix-final-gate.
---

# Phoenix Security — Batch Planner (Role 09)

**Token Budget**: ≤1200 tokens
**Depends On**: Roles 04, 06, 07, 08 — REQUIREMENTS, SECURITY, CONTRACTS, VERIFICATION MATRIX
**Feeds Into**: Role 10 — Final Gate
**Output**: `09-batch-plan.md` + `{slug}-cursor-plan.md` section

---

## Phoenix Team Constraints

| Constraint | Value |
|-----------|-------|
| Team size | 12 people total |
| Batch size target | 1–3 engineer-days |
| Default stack | Python/Flask · N8N · GCP (AI) · AWS (core) |
| Architectural decisions | @Alfonso Eusebio (CTO) |
| Product sign-off | @Francesco Cipollone (CEO) |
| CI/CD | GitHub Actions + Jenkins |

## Batch Ordering Rules (non-negotiable)
1. **Security-first**: P0 R-SEC-* + PSC-03 + PSC-06 MUST be in Batch 1
2. **Contracts before consumers**: types + API contracts before any consumer implementation
3. **Integrations last**: external tool connectors after core logic is stable
4. **Verify before advance**: each batch ends with a binary "done-when" from the verification matrix
5. **Non-reversible steps**: DB migrations, schema changes, tenant data writes → flag explicitly
6. **AI gate**: any batch touching LLM components requires manual-review sign-off before merge
7. **Blocked batches**: depends on open question → mark `BLOCKED` with Q-ID

## Standard Batch Sequence
| Batch | Focus |
|-------|-------|
| 1 | Auth + tenant isolation + data model + security foundation |
| 2 | Core API contracts + shared types + error taxonomy |
| 3 | Core functional logic (happy path) |
| 4 | Integration ingestion (tool connectors) |
| 5 | Edge cases + error handling + rate limiting |
| 6 | Performance validation + load test |
| 7 | UX/DX polish + documentation + Cursor plan handoff |

---

## Output Schema

```markdown
---
meta:
  role: 09-batch-planner
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  batch_count: [N]
  blocked_batches: [count]
  p0_requirements_in_batch_1: yes | no
  status: complete
  next_role: 10-final-gate
---

### BATCH_PLAN

#### BATCH_1
- Goal:
- Scope: [files/modules/services affected]
- Covers_Requirements: [R-FUNC-NNN, R-SEC-NNN, API-NNN]
- Steps:
  1. ...
- Validation: [proof artifact from verification matrix]
- Done_When: [concrete, binary criterion]
- Reversible: yes | no — [rollback strategy if no]
- AI_Gate: required | N/A
- Blocked_By: [Q? | none]
- Risks: [1–2 key risks]
- Assignee_Hint: @Alfonso Eusebio | @Francesco Cipollone | team | TBD

#### BATCH_2 ...

#### CURSOR_PLAN_SUMMARY
Key files across all batches (for .cursor/plans/ handoff):
- ...
```

---

## Cursor Plan Output
The `CURSOR_PLAN_SUMMARY` section feeds directly into the `.cursor/plans/{slug}.md` file.
Format per batch:
```markdown
### Batch N — {name}
**Files to touch:** {list or TBD}
**Requirements:** R-FUNC-001, R-SEC-001
**Steps:**
1. {step}
**Done when:** {binary criterion}
```

## Chaining
Save: `outputs/{session-id}/09-batch-plan.md`
→ Pass to: `phoenix-final-gate` (Role 10)
