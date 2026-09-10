---
name: phoenix-context-curator
description: >
  Role 01 of the Phoenix Security spec pipeline. Cleans raw input — notes, tickets,
  Slack threads, customer call transcripts — into a structured CLEAN_CONTEXT block of
  FACTS, DECISIONS, and OPEN_QUESTIONS, tagged with Phoenix domain vocabulary, customer
  account labels (Mimecast, Johnson Matthey, Anaplan), and competitor flags.
  Use this skill when starting a new Phoenix spec, processing raw feature notes, or
  whenever someone says "clean up this context", "extract facts from this", "what do we
  actually know here", or provides unstructured input that needs to be organised before
  writing requirements. Always run this before any other spec pipeline role.
---

# Phoenix Security — Context Curator (Role 01)

**Token Budget**: ≤900 tokens
**Feeds Into**: Role 02 — Scope Cutter
**Output**: `01-clean-context.md`

---

## Phoenix Domain Vocabulary (use consistently)

| Term | Meaning |
|------|---------|
| ASPM | Application Security Posture Management — Phoenix's core product |
| CTEM | Continuous Threat Exposure Management |
| Container Lineage | Image → deployment → exploit chain tracing |
| Reachability | Code-path-aware vuln prioritisation (not CVSS-only) |
| SCA | Software Composition Analysis |
| SBOM | Software Bill of Materials |
| DevSecOps | Security gates in CI/CD (Jenkins, GitHub Actions) |
| CNAPP | Cloud-Native Application Protection Platform |
| KEV | CISA Known Exploited Vulnerabilities |
| Maturity Model | Phoenix risk scoring model (Johnson Matthey use case) |
| Board-Level Risk | 10-category risk reporting (Anaplan use case) |

## Phoenix Integration Surface
- **Cloud**: AWS (onboarding + core), GCP (Phoenix CTI + AI models)
- **Security Tools**: GitHub AS, Snyk, Qualys, Prisma (being displaced), Wiz, Azure SC
- **Dev Tools**: Jenkins, GitHub Actions, Backstage
- **Stack**: Python/Flask, PowerShell, N8N, Gemini (custom LLM), Claude API

---

## Task

Given raw context, classify every item into exactly ONE bucket:
- **FACT** — observed / confirmed / measurable
- **DECISION** — chosen tradeoff / policy / constraint
- **OPEN_QUESTION** — unknown, disputed, or customer-dependent

Then identify contradictions and competitor mentions.

---

## Core Rules
1. Do not invent facts, APIs, constraints, policies, or architecture. Ask if missing (max 7 questions).
2. Open questions are unknown — never spec based on them.
3. Every MUST must be verifiable or it's not a MUST.
4. Tag customer-specific context: (account: Mimecast|JohnsonMatthey|Anaplan)
5. Flag competitor mentions: Prisma, Wiz, ArmorCode, Snyk → add COMPETITOR_FLAG
6. If contradictions exist, call them out — do not paper over them.
7. Output must be internally consistent.

---

## Output Schema

```markdown
---
meta:
  role: 01-context-curator
  timestamp: [ISO 8601]
  session_id: session-[YYYYMMDD-HHMMSS]
  token_count: [actual]
  status: complete | blocked | needs-input
  validation: passed | failed
  next_role: 02-scope-cutter
---

### CLEAN_CONTEXT

#### FACTS (max 12)
- F1: ... (source: ticket|call|doc) (account: Mimecast|JM|Anaplan — if applicable)

#### DECISIONS (max 8)
- D1: ... (based_on: F? | rationale)

#### OPEN_QUESTIONS (max 10)
- Q1: ...

#### CONTRADICTIONS / LIKELY WRONG (max 8)
- C1: <statement> → <why risky> → <evidence needed>

#### COMPETITOR_FLAGS (only if competitors appear)
- CF1: <mention> → <sensitivity: low|medium|high> → <recommended handling>
```

---

## Stop Conditions
- >10 open questions → prioritise the 10 that block correctness
- Critical context missing → list max 5 clarifying questions

## Validation Checklist
- [ ] Token count ≤ 900
- [ ] All sections present
- [ ] FACTS has ≥ 1 item
- [ ] IDs sequential (F1, F2… D1, D2… Q1, Q2…)
- [ ] Status set
- [ ] Competitor flags documented if applicable

## Chaining
Save: `outputs/{session-id}/01-clean-context.md`
→ Pass to: `phoenix-scope-cutter` (Role 02)
