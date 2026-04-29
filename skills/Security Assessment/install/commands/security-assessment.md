---
description: Full OWASP Top 10 + ASVS L1 security assessment of the codebase. Slow + thorough.
argument-hint: "[scope] (e.g. 'backend', 'frontend', 'A01,A03', or empty for full repo)"
---

You are running the **Comprehensive Security Assessment** skill.

## Instructions

1. Load the skill at `skills/Security Assessment/security-assessment/SKILL.md`.
2. Parse `$ARGUMENTS` for scope hints (full / backend / frontend / specific OWASP categories).
3. Follow the skill's workflow: detect stack → run OWASP Top 10 + ASVS L1 checks → present results.
4. Stream progress (checks completed, findings count, estimated cost).
5. Final output sections: Executive Summary, Detailed Findings (grouped by OWASP category), ASVS L1 Compliance Matrix, Remediation Roadmap.
6. Offer follow-up: generate test suite, export report, create remediation tickets.

## Scope guard

- This is the **heavy** assessment. Confirm scope and budget before starting if either is ambiguous.
- Read-only by default. Only generate test files if the user explicitly asks.
- For PR/diff-only checks, use `/security-0day` instead.
