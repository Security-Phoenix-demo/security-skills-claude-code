---
description: Full OWASP Top 10 + ASVS L1 security assessment of the codebase. Heavy — run before release or on demand.
---

# Security Assessment (Windsurf Workflow)

Run the comprehensive security assessment skill at
`skills/Security Assessment/security-assessment/SKILL.md`.

## Steps

1. Confirm scope with the user (full repo / backend / frontend / specific OWASP categories) and budget if a token cap matters.
2. Detect the stack (language, web framework, ORM, auth library) before running checks.
3. Execute OWASP Top 10 2025 and ASVS L1 checks. Stream progress (checks completed, findings count).
4. Group findings by OWASP category. Each finding: vulnerable code snippet, attack scenario, PoC, remediation, generated test template (if requested).
5. Produce an ASVS L1 compliance matrix and remediation roadmap.
6. Offer follow-up: generate security test suite, export report, create remediation tickets.

## Notes

- This is the heavy workflow. For PR/diff-only checks, use a 0-day scan instead (see `skills/Security Assessment/0day-scanner/SKILL.md`).
- For STRIDE/DREAD threat modeling, use `skills/Security Assessment/threat-modeling/SKILL.md`.
- Read-only by default. Only generate test files if the user explicitly asks.
