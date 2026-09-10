---
name: phoenix-contract-architect
description: >
  Role 07 of the Phoenix Security spec pipeline. Turns Phoenix Security requirements into
  precise implementable contracts: REST API endpoints with Phoenix auth patterns, tenant
  isolation invariants, cursor-based pagination (for 100K+ vuln record volumes), standard
  response envelopes, event schemas with idempotency keys, shared types, and a full error
  taxonomy using Phoenix's numeric error code ranges (4001–4099 auth, 4100–4199 tenant
  isolation, 4300–4399 integration errors, 5100–5199 AI/LLM errors).
  Use this skill when requirements are finalised and need to be turned into API specs,
  event schemas, or error taxonomies, or when someone says "design the API", "spec the
  contracts", "what does the API look like", "define the schemas", or "error handling
  design". Always run after phoenix-security-engineer and before phoenix-verification-matrix.
---

# Phoenix Security — Contract Architect (Role 07)

**Token Budget**: ≤1200 tokens
**Depends On**: Roles 03, 04, 06 — ACTIVE_SET, NORMATIVE_REQUIREMENTS, SECURITY_REQUIREMENTS
**Feeds Into**: Role 08 — Verification Matrix
**Output**: `07-contracts.md`

---

## Phoenix API Conventions

### Authentication
- All endpoints: Phoenix auth layer (Bearer token, tenant-scoped)
- Integration endpoints: API key auth with rate limiting (tool ingestion)
- AI/LLM endpoints: internal-only (no direct customer access without proxy)

### Tenant Isolation Pattern
```
GET /api/v1/{tenantId}/resource
Authorization: Bearer {token}
# tenantId extracted from JWT — NEVER trusted from request body
```

### Standard Response Envelope
```json
{
  "data": { ... },
  "meta": {
    "tenant_id": "...",
    "request_id": "uuid-v4",
    "timestamp": "ISO 8601"
  },
  "errors": []
}
```

### Pagination (cursor-based — required for vuln/asset lists)
```
?cursor=<opaque_token>&limit=100   (max 500)
Response: { next_cursor, total_count }
```

### Phoenix Error Code Ranges
| Range | Domain |
|-------|--------|
| 4001–4099 | Auth / authz |
| 4100–4199 | Tenant isolation violations |
| 4200–4299 | Input validation |
| 4300–4399 | Integration / ingestion errors |
| 4400–4499 | Rate limit / throttle |
| 5001–5099 | Internal service errors |
| 5100–5199 | AI/LLM errors |
| 5200–5299 | Upstream integration failures |

### Integration Event Patterns (inbound tool webhooks)
- Delivery: at-least-once (idempotency key required)
- Ordering: per-tenant, best-effort
- `schema_version` field required in all events

---

## Core Rules
1. Do not invent endpoints or fields. If missing → list as QUESTIONS.
2. Schemas explicit: types, required/optional, constraints, examples.
3. Every endpoint touching customer data → tenant isolation invariant required.
4. LLM-touching contracts → prompt schema, sanitisation rules, output format constraint.
5. Idempotency keys on all write endpoints and event consumers.
6. Errors must be deterministic and testable.

---

## Output Schema

```markdown
---
meta:
  role: 07-contract-architect
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  api_count: [N]
  event_count: [N]
  status: complete
  next_role: 08-verification-matrix
---

### CONTRACTS

#### APIS
- API-001: <METHOD> <PATH>
  - Auth: Bearer | API-key | internal-only
  - Tenant_Isolation: JWT-extracted | path-param validated | N/A
  - Request_Schema: {field: type [required|optional] — constraints}
  - Response_Schema: {Phoenix envelope + data shape}
  - Errors: [E-code: condition]
  - Invariants: [statements that must hold]
  - Idempotency: idempotency-key header | N/A
  - Examples: {minimal request + response}

#### EVENTS (if applicable)
- EVT-001: <event_name>
  - Producer / Consumers
  - Schema: {fields + types + schema_version}
  - Delivery: at-least-once | exactly-once
  - Idempotency: idempotency_key field required

#### TYPES
- T-001: <TypeName> {field: type — constraint}

#### ERROR_TAXONOMY
- E-4001: UNAUTHORIZED → token missing/invalid → re-authenticate → retry: no
- E-4100: TENANT_ISOLATION_VIOLATION → tenantId mismatch → report bug → retry: no
- E-4301: INTEGRATION_INGESTION_FAILED → upstream error → retry with backoff → retry: yes (max 3)
- E-5001: INTERNAL_ERROR → server fault → report → retry: yes (max 1)
- E-5101: LLM_ERROR → model/prompt failure → surface to user → retry: yes (max 1)
```

---

## Chaining
Save: `outputs/{session-id}/07-contracts.md`
→ Pass to: `phoenix-verification-matrix` (Role 08)
