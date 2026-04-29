---
trigger: model_decision
description: When the user finishes a feature, edits an endpoint/auth/render path, or asks to ship/commit/PR, run a lightweight security review before declaring done.
---

# Security Review Rule (Windsurf)

When any of the following are true, before declaring a task done or opening a PR, run an 8-point security review on the diff:

- A new HTTP endpoint, route, or controller was added or modified
- Auth, RBAC, session, or permission logic changed
- Frontend rendering, templating, or HTML/markdown output changed
- An outbound HTTP fetch (SSRF surface) was added or changed
- Dependencies were updated
- The user said "ship", "commit", "PR", "merge", or "done"

## How to run

Use the patterns and 8-Point Security Check from
`skills/Security Assessment/Security-reviewr/security-reviewer.md`.

Output a short findings list with severity (CRITICAL/HIGH/MEDIUM/LOW), file:line,
evidence snippet, and recommended fix. If clean, say so explicitly and list
residual risks worth follow-up.

For a heavier sweep, run the workflow `/security-assessment`.
For a STRIDE/DREAD threat model, run `/threatmodel`.
