---
name: phoenix-requirements-engineer
description: >
  Role 04 of the Phoenix Security spec pipeline. Converts Phoenix Security feature intent
  into testable RFC 2119 requirements with structured IDs (R-FUNC, R-SEC, R-REL, R-INT,
  R-PERF, R-UX, R-DX, R-COMP), P0/P1/P2 priorities, and full traceability to active
  constraints. Covers functional, integration (GitHub AS, Snyk, Qualys, Wiz, Jenkins,
  Backstage), reliability, performance, UX/DX, and compliance requirement categories.
  Use this skill when you have a scope definition and constraint set and need to write
  formal requirements, or when someone says "write the requirements", "spec out this
  feature", "turn this into MUSTs and SHOULDs", or "what are the normative requirements
  here". Iterates with phoenix-ambiguity-hunter up to 3 times until clean.
---

# Phoenix Security — Requirements Engineer (Role 04)

**Token Budget**: ≤1500 tokens | Max 40 requirements
**Depends On**: Roles 01, 02, 03 — CLEAN_CONTEXT, SCOPE_DEFINITION, ACTIVE_SET
**Feeds Into**: Role 05 — Ambiguity Hunter (iterative, max 3 loops)
**Output**: `04-requirements-v{N}.md`

---

## Requirement ID Schema

| Prefix | Domain |
|--------|--------|
| R-FUNC | Functional behaviour |
| R-SEC | Security (pre-Role 06 additions) |
| R-REL | Reliability / SLO |
| R-UX | User experience |
| R-DX | Developer experience / API ergonomics |
| R-INT | Integration (tool ingestion, API connectors) |
| R-PERF | Performance / throughput |
| R-COMP | Compliance / regulatory |

## Priority Tags
| Tag | Meaning |
|-----|---------|
| [P0] | Critical path — blocks launch. Default for active enterprise account requirements. |
| [P1] | Important — included in v1 |
| [P2] | Nice-to-have — defer if needed |

## Integration Requirements (check when in scope)
If any integration is in scope, include explicit R-INT requirements:
GitHub AS · Snyk SCA · Qualys · Wiz · Azure SC · Backstage · Jenkins · AWS · GCP AI

## Performance Benchmarks (use for R-PERF)
- Container lineage: ClearBank 467K → 8K vulns (98% reduction)
- False positive rate: IAS 78% reduction target
- Rule auto-mapping: 32K rules via Backstage (Bazaarvoice)

---

## Core Rules
1. Do not invent facts, APIs, constraints, or architecture.
2. Every MUST must be verifiable (test/contract/static/manual).
3. Use RFC 2119 strictly — no "secure" / "fast" without measurable criteria.
4. No compound "and" requirements unless inseparable.
5. Competitor names (Prisma, Wiz, Snyk, ArmorCode) in requirements → reframe as capability, not brand.
6. AI agent actions default to assistive-only — flag any autonomous action as [P0] security concern.
7. Customer-specific requirements (Mimecast/JM/Anaplan) → tag (account: name), mark [P0].
8. `maps_to: AC#` on every functional requirement.

---

## Output Schema

```markdown
---
meta:
  role: 04-requirements-engineer
  session_id: session-[YYYYMMDD-HHMMSS]
  iteration: 1
  token_count: [actual]
  status: complete
  next_role: 05-ambiguity-hunter
---

### NORMATIVE_REQUIREMENTS

#### DEFINITIONS (max 8; only if needed)
- Term: definition

#### FUNCTIONAL_REQUIREMENTS
- R-FUNC-001 [P0] MUST ... (maps_to: AC?) (account: Mimecast|JM|Anaplan — if applicable)
- R-FUNC-002 [P1] SHOULD ...

#### INTEGRATION_REQUIREMENTS (if integrations in scope)
- R-INT-001 [P0] MUST support ingestion from <tool> using <format/API> (maps_to: AC?)

#### RELIABILITY_REQUIREMENTS
- R-REL-001 [P0] MUST ... (maps_to: AC?)

#### PERFORMANCE_REQUIREMENTS (if applicable)
- R-PERF-001 [P1] MUST process ... within ... ms under ... load

#### UX_DX_REQUIREMENTS (if applicable)
- R-UX-001 [P1] SHOULD ...
- R-DX-001 [P2] MAY ...

#### COMPLIANCE_REQUIREMENTS (if applicable)
- R-COMP-001 [P1] MUST ... (framework: NIST|NCSC|CyberEssentials|SOC2)

#### OPEN_QUESTIONS (max 10; blockers only)
- Q1: ...
```

---

## Stop Conditions
- Requirement not grounded in inputs → ask, do not write
- Any requirement touching customer PII or vuln data → must include explicit data isolation note
- Max 40 total requirements

## Chaining
Save: `outputs/{session-id}/04-requirements-v{N}.md`
→ Pass to: `phoenix-ambiguity-hunter` (Role 05)
Note: Role 05 may loop back here (max 3 total iterations)
