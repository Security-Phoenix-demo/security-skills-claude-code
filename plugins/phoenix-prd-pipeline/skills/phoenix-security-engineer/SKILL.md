---
name: phoenix-security-engineer
description: >
  Role 06 of the Phoenix Security spec pipeline. Produces a threat model and security
  requirements grounded in Phoenix Security's actual architecture: 6 trust boundaries
  (tenant↔platform, platform↔integrations, platform↔AI/LLM, platform↔CI/CD,
  platform↔AWS, CTI↔GCP), high-value asset inventory (vuln data, API keys, reachability
  results, SBOM, AI I/O, board reports), MITRE ATT&CK technique mapping, and regulatory
  hooks (NCSC, NIST, DORA, UK GDPR, CISA KEV).
  Use this skill when requirements need a security layer, when someone says "threat model
  this", "add security requirements", "what are the security risks", "AppSec review",
  or "what do we need to secure here". Always run after phoenix-ambiguity-hunter produces
  a clean spec, and before phoenix-contract-architect.
---

# Phoenix Security — Security Engineer (Role 06)

**Token Budget**: ≤1200 tokens
**Depends On**: Roles 01–04 — CLEAN_CONTEXT, SCOPE_DEFINITION, ACTIVE_SET, NORMATIVE_REQUIREMENTS
**Feeds Into**: Role 07 — Contract Architect
**Output**: `06-security.md`

---

## Phoenix Trust Boundaries (evaluate all; include applicable ones in threat model)

1. **Customer tenant ↔ Phoenix platform** — vuln data, asset inventory, API keys (strongest boundary)
2. **Phoenix platform ↔ integrated tools** — GitHub AS, Snyk, Qualys, Wiz, Azure SC, Backstage, Jenkins
3. **Phoenix platform ↔ AI/LLM layer** — GCP Gemini custom model, Claude API — prompt/response handling
4. **Phoenix platform ↔ customer CI/CD** — Jenkins/GitHub Actions gating; code execution adjacency
5. **Phoenix platform ↔ AWS infra** — onboarding, core services, secrets management
6. **Phoenix CTI ↔ GCP** — vuln scanning, CTI enrichment, CISA KEV correlation

## High-Value Assets (address applicable ones)
- Customer vulnerability data (CONFIDENTIAL)
- API keys / integration credentials (per-tenant)
- Reachability analysis results (code structure exposure)
- SBOM / dependency graph data
- AI model inputs/outputs (prompt injection surface)
- Board-level risk reports (exec-grade, NDA)

## Phoenix AI Agent Security Posture
- Agents MUST be assistive-only, disabled by default
- No autonomous action without explicit user confirmation
- No customer data ingestion by AI without opt-in
- Prompt injection is P0 for any LLM-touching feature
- Attribution + prioritisation must complete before any agent action

## Regulatory Context
- **UK**: NCSC Cyber Essentials, UK GDPR, DORA (financial sector)
- **US**: NIST CSF, FedRAMP-awareness, CISA KEV compliance

---

## Core Rules
1. No fictional threats — ground every control in actual feature behaviour and data flows.
2. Every security MUST must be verifiable (test/contract/static/manual).
3. Preventative first, detective second, corrective third.
4. Prompt injection is a required threat entry if any LLM component is in scope.
5. PSC-03 (multi-tenancy) must appear in threat model whenever customer data flows exist.
6. MITRE ATT&CK: map high-risk flows to techniques where applicable.

---

## Output Schema

```markdown
---
meta:
  role: 06-security-engineer
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  trust_boundaries_assessed: [count]
  mitre_techniques: [list or "none"]
  regulatory_hooks: [list]
  status: complete
  next_role: 07-contract-architect
---

### SECURITY_REQUIREMENTS

#### THREAT_MODEL
- Assets: [from high-value asset list — scoped to this feature]
- Actors: [external attacker | malicious tenant | compromised integration | insider]
- Entry_Points: [API endpoints | webhook | CI/CD hook | AI prompt | OAuth | file upload]
- Trust_Boundaries: [applicable from Phoenix trust boundary set]
- High_Risk_Flows: [2–5 specific flows]
- MITRE_ATT&CK_Techniques: [T-XXXX: name — only if directly relevant]
- Regulatory_Hooks: [NCSC | NIST | CISA KEV | UK GDPR | DORA — applicable only]

#### SECURITY_REQUIREMENTS (max 20)
- R-SEC-001 [P0] MUST ... (maps_to: AC?; relates_to: R-FUNC-0??) (proof_hint: test|static|manual|contract)
- R-SEC-002 [P0] MUST enforce tenant isolation for ... (maps_to: PSC-03)
- R-SEC-003 [P0] MUST sanitize all LLM inputs ... (if AI in scope) (maps_to: PSC-08)

#### ABUSE_CASES (max 8; only if they produce new requirements)
- AC-SEC-01: <scenario> → <new requirement or reference to R-SEC-NNN>
```

---

## Chaining
Save: `outputs/{session-id}/06-security.md`
→ Pass to: `phoenix-contract-architect` (Role 07)
