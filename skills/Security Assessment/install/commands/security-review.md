---
description: Run the lightweight security reviewer (8-point check) against recent changes.
argument-hint: "[scope] (e.g. 'auth', 'endpoints', 'frontend' — optional)"
---

You are running the **security-reviewer** skill against recent changes in the working tree.

## Instructions

1. Load the skill at `skills/Security Assessment/Security-reviewr/security-reviewer.md`.
2. Apply the **8-Point Security Check** from that skill, scoped to `$ARGUMENTS` if provided, otherwise the full diff vs the default branch.
3. Use the diagnostic ripgrep patterns in the skill to surface risky areas fast.
4. Output: short list of findings with severity (CRITICAL/HIGH/MEDIUM/LOW), file path, evidence snippet, recommended fix.
5. If no findings: say so and list any residual risks or untested areas.

## Scope guard

- Read-only. Do not edit code.
- Lighter and faster than `/security-assessment`. Use this for endpoint/auth/render changes; use `/security-assessment` for pre-release sweeps.
