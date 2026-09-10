---
name: phoenix-final-gate
description: >
  Role 10 of the Phoenix Security spec pipeline. Makes the final SHIP / NO_SHIP decision
  for a Phoenix Security feature spec by checking 8 hard blockers: critical ambiguities
  remaining, unverified MUSTs, multi-tenant isolation gaps (PSC-03), auth layer coverage
  (PSC-06), AI agent safety violations (PSC-08), scope creep vs SCOPE_DEFINITION, P0
  security not in Batch 1, and active enterprise account requirements (Mimecast, Johnson
  Matthey, Anaplan) not covered at P0. On SHIP, triggers Confluence push + optional
  Linear/Slack/Asana/email. On NO_SHIP, lists blockers with source role and required fix.
  Use this skill for final quality review, when someone says "is this ready to build",
  "final gate", "ship or no-ship", "is the spec done", or "review the full spec". Can be
  re-run after fixing blockers.
---

# Phoenix Security — Final Gate Reviewer (Role 10)

**Token Budget**: ≤800 tokens
**Depends On**: All previous roles (01–09)
**Feeds Into**: FEATURE_SPEC.md + Confluence push (if SHIP)
**Output**: `10-final-gate.md`

---

## Hard Blockers (any = NO_SHIP)

Run this checklist explicitly — do not skip any item:

- [ ] Critical ambiguities remaining (Role 05) > 0
- [ ] Any MUST lacks proof path (Role 08, `unverified_musts > 0` without downgrade rationale)
- [ ] PSC-03 multi-tenancy not addressed in security requirements
- [ ] PSC-06 auth layer not addressed for any new endpoint
- [ ] PSC-08 AI agent autonomous action not gated (if LLM in scope)
- [ ] Scope creep: requirements outside SCOPE_DEFINITION from Role 02
- [ ] P0 security requirements NOT in Batch 1 (Role 09)
- [ ] Active enterprise account requirements (Mimecast/JM/Anaplan) not covered at P0

## Soft Warnings (flag, do not block)
- Manual-only proof paths for non-security requirements
- Missing success metrics vs Phoenix case study benchmarks
- Batch count implies >4 weeks without CTO sign-off
- Regulatory hooks not documented
- Competitor brand names in user-facing copy

---

## Output Schema

```markdown
---
meta:
  role: 10-final-gate
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  decision: SHIP | NO_SHIP
  blocker_count: [N]
  status: complete
---

### FINAL_GATE

#### DECISION
SHIP | NO_SHIP

#### HARD_BLOCKER_CHECK
- PSC-03 multi-tenancy: addressed | missing
- PSC-06 auth: addressed | missing
- PSC-08 AI agent: addressed | N/A
- Critical ambiguities: [count]
- Unverified MUSTs: [count]
- Scope creep: detected | none
- P0 in Batch 1: yes | no
- Enterprise account coverage: complete | gaps → [list gaps]

#### BLOCKERS (max 10; NO_SHIP only)
- B1: <gap> → source role: 0N → fix required: <exact action>

#### NON_BLOCKING_IMPROVEMENTS (max 10)
- N1: ...

#### NEXT_ACTIONS (ordered; owner + ETA)
1. [@owner] <action> — <ETA>
```

---

## Post-Gate Actions

**On SHIP:**
1. Save `10-final-gate.md`
2. Compile `FEATURE_SPEC.md` (Phoenix PRD template)
3. Push to Confluence SPM space (Atlassian MCP — mandatory; fallback parent: 1273987073)
4. Ask once: *"Want me to create Linear/Asana tickets, notify Slack, or email stakeholders?"*
5. Status: ✅ Pipeline complete

**On NO_SHIP:**
1. Save `10-final-gate.md`
2. Mark PRD status: BLOCKED
3. Produce all output files regardless — partial spec beats no artefact
4. Fix each blocker at source role → re-run downstream → return here

## Chaining
Save: `outputs/{session-id}/10-final-gate.md`
→ If SHIP: compile `FEATURE_SPEC.md` using phoenix-prd-generator template
