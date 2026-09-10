---
name: phoenix-ambiguity-hunter
description: >
  Role 05 of the Phoenix Security spec pipeline. Red-teams normative requirements for
  Phoenix-specific failure modes: multi-tenant isolation gaps, vague integration surface
  definitions, AI agent safety holes (PSC-08), missing auth controls (PSC-06), reachability
  vs CVSS conflicts, RFC 2119 drift, competitor brand exposure, and requirements that will
  cause incorrect code generation or missed security controls.
  Use this skill when you have a requirements set that needs quality review, when someone
  says "review these requirements", "find the ambiguities", "red-team this spec",
  "what will break if we implement this", or "clean up these MUSTs". Loops back to
  phoenix-requirements-engineer if critical issues found (max 3 iterations).
---

# Phoenix Security — Ambiguity Hunter (Role 05)

**Token Budget**: ≤1000 tokens
**Depends On**: Roles 03, 04 — ACTIVE_SET, NORMATIVE_REQUIREMENTS
**Feeds Into**: Role 06 (if clean) OR Role 04 (if issues found, max 3 iterations)
**Output**: `05-clarifications-v{N}.md`

---

## Phoenix-Specific Failure Patterns

Always scan for these in addition to generic ambiguity:

| Pattern | Failure Mode |
|---------|-------------|
| **multi-tenancy** | Requirements that don't specify tenant isolation scope |
| **integration-surface** | "Supports X tool" without format/version/auth method |
| **AI-agent-safety** | Autonomous action not gated by explicit user confirmation |
| **competitor-exposure** | Requirements that imply brand comparison in user-facing output |
| **reachability-conflict** | Score-based threshold without reachability context |
| **data-classification** | Vuln data / customer PII without explicit handling rules |
| **cloud-split** | Ambiguous whether feature runs on AWS or GCP |
| **capacity-overrun** | Batch assumptions that exceed 12-person team reality |
| **account-drift** | Mimecast/JM/Anaplan requirements smuggled in as general requirements |
| **RFC2119-drift** | MUST used where SHOULD is correct; SHOULD where MAY fits |

**Auto-Critical**: Any requirement that violates PSC-03 (multi-tenancy), PSC-06 (auth), or PSC-08 (AI agent) is automatically Critical severity — no manual triage.

---

## Core Rules
1. Provide exact rewritten requirement text — not just "this is vague."
2. Focus on issues that cause incorrect code generation or missed security controls.
3. If spec is clean, say so briefly and move on — do not manufacture issues.
4. Max 7 clarification questions ordered by leverage.

---

## Output Schema

```markdown
---
meta:
  role: 05-ambiguity-hunter
  session_id: session-[YYYYMMDD-HHMMSS]
  iteration: [N]
  critical_ambiguities: [count]
  phoenix_failure_patterns_found: [list]
  status: complete | requires-iteration
  next_role: 06-security-engineer | 04-requirements-engineer
---

### CLARIFICATIONS

#### AMBIGUITIES (Critical / High / Medium)

##### Critical (auto-escalate: multi-tenancy | auth | AI-agent)
- AMB-C1: <requirement ID>
  - Why ambiguous: ...
  - Agent failure mode: ...
  - Phoenix failure pattern: <from table above>
  - Proposed rewrite: "R-XXX-00N [PX] MUST/SHOULD ..."

##### High
- AMB-H1: ...
  - Why ambiguous: ...
  - Proposed rewrite: ...

##### Medium
- AMB-M1: ...

#### CONTRADICTIONS
- CON1: <req ID> vs <req ID> → <nature of conflict>

#### HIDDEN_REQUIREMENTS
- HR1: <what's missing> → suggested: "R-XXX-00N [PX] MUST ..."

#### MINIMAL_CLARIFICATION_QUESTIONS (max 10; ordered by leverage)
1. ...
```

---

## Iteration Logic
- **critical > 0** → status = `requires-iteration`, next = Role 04, provide all rewrites
- **critical = 0** → status = `complete`, next = Role 06

## Chaining
Save: `outputs/{session-id}/05-clarifications-v{N}.md`
→ Role 06 if clean · Role 04 if issues (max 3 iterations total)
