---
name: phoenix-verification-matrix
description: >
  Role 08 of the Phoenix Security spec pipeline. Maps every MUST/MUST NOT to a concrete
  proof method using Phoenix's proof type hierarchy: unit-test, integration-test,
  contract-test, static-analysis, infra-check, load-test, manual-review. Enforces that
  security requirements use static-analysis + unit-test minimum, multi-tenancy requirements
  use integration-test, AI agent requirements use manual-review + unit-test, and all API
  contracts use contract-test. Includes negative test cases for auth, tenant isolation,
  and input validation requirements.
  Use this skill when you need to verify a spec is provable end-to-end, when someone says
  "how do we test this", "map the proofs", "verification plan", "how do we know this works",
  or "create the test matrix". Always run after phoenix-contract-architect and before
  phoenix-batch-planner.
---

# Phoenix Security — Verification Matrix (Role 08)

**Token Budget**: ≤1000 tokens
**Depends On**: Roles 04, 06, 07 — NORMATIVE_REQUIREMENTS, SECURITY_REQUIREMENTS, CONTRACTS
**Feeds Into**: Role 09 — Batch Planner
**Output**: `08-verification-matrix.md`

---

## Phoenix Proof Types

| Proof Type | Description | Naming Convention |
|-----------|-------------|------------------|
| `unit-test` | Automated unit test | `test_<module>_<behaviour>.py` |
| `integration-test` | Multi-component test | `test_<feature>_integration.py` |
| `contract-test` | API / Pact test | `pact_<api-id>_<scenario>.json` |
| `static-analysis` | Linter / SAST | Bandit, CodeQL, Semgrep rule name |
| `infra-check` | IaC / config validation | Terraform plan / AWS policy check |
| `manual-review` | Human checklist | Named checklist item |
| `pen-test` | Penetration test | For new trust boundary crossings |
| `load-test` | Performance validation | Locust / k6 scenario name |

## Proof Priority (prefer automated)
`unit-test` → `integration-test` → `contract-test` → `static-analysis` → `infra-check` → `load-test` → `manual-review`

## Mandatory Proof Assignments
- **R-SEC-*** → `static-analysis` + `unit-test` minimum
- **PSC-03 (multi-tenancy)** → `integration-test` required
- **PSC-08 (AI agent)** → `manual-review` + `unit-test`
- **API-NNN** → `contract-test` as primary
- **Auth / tenant isolation / input validation** → negative tests required

---

## Core Rules
1. Every MUST/MUST NOT must have ≥1 proof path.
2. If proof is impossible → downgrade MUST → SHOULD, or mark OPEN QUESTION with rationale.
3. Negative tests for all auth, tenant isolation, and input validation requirements.
4. `unverified_musts > 0` is a Final Gate blocker unless downgraded with rationale.

---

## Output Schema

```markdown
---
meta:
  role: 08-verification-matrix
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  total_musts: [count]
  automated_proofs: [count]
  manual_proofs: [count]
  unverified_musts: [count]
  status: complete
  next_role: 09-batch-planner
---

### VERIFICATION_MATRIX

| Requirement_ID | Statement (short) | Level | Proof_Type | Proof_Artifact | Negative_Test | Notes |
|---|---|---|---|---|---|---|
| R-FUNC-001 | ... | MUST | unit-test | test_feature_behaviour.py | test_feature_unauthorised.py | |
| R-SEC-001 | Tenant data isolated | MUST | integration-test + static | test_tenant_isolation.py + semgrep_tenant | test_cross_tenant_leak.py | PSC-03 |
| R-SEC-002 | LLM input sanitised | MUST | unit-test + manual-review | test_prompt_sanitise.py + ai-review-checklist | test_prompt_injection.py | PSC-08 |
| API-001 | GET /... returns envelope | MUST | contract-test | pact_api001_consumer.json | pact_api001_invalid_token.json | |

#### UNVERIFIED_MUSTS (if any)
- R-XXX-NNN: <reason> → recommended: downgrade | ask | manual
```

---

## Chaining
Save: `outputs/{session-id}/08-verification-matrix.md`
→ Pass to: `phoenix-batch-planner` (Role 09)
Warning: `unverified_musts > 0` → Final Gate blocker
