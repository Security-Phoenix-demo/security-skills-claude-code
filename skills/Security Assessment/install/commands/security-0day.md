---
description: Scan the current branch's diff (vs main) for 0-day-style vulnerabilities. Light, fast, PR-focused.
argument-hint: "[base-ref] (default: main)"
---

You are running the **0-Day Vulnerability Scanner** skill against the current branch's diff.

## Instructions

1. Invoke the `0day-scanner` skill (file: `skills/Security Assessment/0day-scanner/SKILL.md`).
2. Target = git diff between `$ARGUMENTS` (default `main`) and `HEAD`.
3. Prefer **light mode** unless the diff is large (>50 changed files → standard mode).
4. Report findings inline with severity, file:line, evidence, and suggested fix.
5. If no vulnerabilities are found, say so explicitly and list residual risks worth follow-up.

## Scope guard

- Do **not** modify code. This is a read-only review.
- Do **not** run the full `security-assessment` skill — that's a different command.

If you cannot determine a base ref or the working tree has no diff, say so and stop.
