---
description: Multi-language security review (8-point check) on recent changes. Routes to the bundled stronger reviewer when present, falls back to the lite reviewer otherwise.
argument-hint: "[scope] (e.g. 'auth', 'endpoints', 'frontend', a path, or empty for the diff)"
---

You are running the **security-reviewer** skill against recent changes.

## Skill

Load `skills/Security Assessment/Security-automated-claude-skills/.claude/skills/security-reviewer/SKILL.md` —
multi-language reviewer (Python, JS/TS, Go, Java/Kotlin, Rust, Ruby, .NET) with per-language reference packs in `languages/`,
OWASP/ASVS + endpoint checklists in `checklists/`, and a triage playbook in `playbooks/`.

## Instructions

1. Load the skill above. Read it fully, including the language reference(s) matching the project's stack and the relevant checklists.
2. Determine scope:
   - If `$ARGUMENTS` is provided, scope to that (path, keyword like `auth`/`endpoints`/`frontend`, or category).
   - Otherwise, scope to files changed since the last commit (`git diff --name-only HEAD~1`) plus obviously security-relevant globs (route files, middleware, auth, templates, IaC).
3. Apply the 8-point check (Authn/Authz, Output encoding, SSRF, Secrets, Input handling, Config & headers, Supply chain, Failure modes).
4. **Confirm before flagging.** Pattern matches that turn out safe-by-context get dropped. Open the file and read enough surrounding context to confirm.
5. Output one block per finding in the skill's output format:
   ```
   [SEVERITY] <one-line summary>
   File:     <path>:<line>
   Category: <one of the 8 categories>
   Evidence: <code snippet or pattern matched>
   Fix:      <concrete change, ideally a diff>
   Refs:     <CWE-XXX, OWASP A0X:2021, ASVS V-X.Y.Z>
   ```
6. If nothing fires, say so explicitly and list residual risks or untested areas — silence is not a clean bill.

## Scope guard

- Read-only. Do not edit code as part of the review itself; describe fixes precisely instead.
- For diff-level checks against a base ref, prefer `/security-0day`.
- For pre-release sweeps, prefer `/security-assessment`.
- For architecture / new feature design, prefer `/threatmodel`.
