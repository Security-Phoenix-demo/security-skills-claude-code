---
name: security-reviewer
description: Multi-language security review for web apps, APIs, and CLIs. Use whenever code is added or modified — new endpoints, auth/RBAC changes, template or DOM rendering, outbound HTTP, dependency updates, IaC/config changes, or end-of-feature reviews. Covers Python, JavaScript, TypeScript, Go, Rust, Java/Kotlin, Ruby, C#/.NET, plus shared OWASP Top 10 and ASVS L1 logic. Triggers on phrases like "security review", "review this for security", "audit this code", "is this safe", "AppSec check", "threat-model this change", "supply chain risk", "before I merge", or whenever a senior engineer would pause to ask "what could go wrong here". Pairs with the `security-reviewer` subagent and the session-start / pre-bash / post-edit hooks shipped alongside it.
---

# Security Reviewer

A pragmatic AppSec review pass for any modern stack. Output is short, severity-ranked findings with file paths, evidence, and a concrete fix — never a 30-page "report".

## When to run

Run on any of:

- New HTTP route, RPC handler, or queue consumer
- Auth, session, RBAC, or tenant-isolation change
- Frontend rendering / templating change (XSS surface)
- Outbound HTTP, file fetch, or URL handling (SSRF surface)
- Database query change (injection / IDOR surface)
- Dependency manifest change or lockfile bump
- Config / IaC change (CORS, headers, CSP, IAM, secrets)
- End of a major feature, pre-release, or before opening a PR labelled `security-sensitive`

If unsure, run it. False positives are cheap; missed CVEs are not.

## Eight-point check (language-agnostic)

These eight categories drive every review. Every finding maps to one.

1. **Authn/Authz** — every route has explicit auth + role/tenant checks; no implicit "logged-in means allowed"
2. **Output encoding** — all user-influenced HTML/markdown/JSON/log output is encoded for its sink
3. **SSRF & outbound HTTP** — URL allow-listed, redirects bounded, IMDS / link-local / RFC1918 blocked unless intentional
4. **Secrets & key material** — no client-side storage, no hardcoded keys, no secrets in URLs or logs
5. **Input handling** — parameterised queries, path containment, redirect target validation, deserialisation guards
6. **Config & headers** — CSP, HSTS, X-Content-Type-Options, secure cookies, CORS allowlist, rate limits, dev-bypass off in prod
7. **Supply chain** — dependencies pinned, lockfile committed, manifest scanned, no unknown registries, install scripts reviewed
8. **Failure modes** — fail-closed on auth/policy errors, no broad `except`/`catch`, errors don't leak stack traces or PII

## Routing

When language is known, load the matching reference and use its diagnostic patterns. When mixed, run all relevant ones.

| Detected from… | Read… |
|---|---|
| `pyproject.toml`, `requirements*.txt`, `Pipfile`, `setup.py` | `languages/python.md` |
| `package.json`, `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `languages/javascript-typescript.md` |
| `go.mod` | `languages/go.md` |
| `Cargo.toml` | `languages/rust.md` |
| `pom.xml`, `build.gradle*`, `*.kt`, `*.java` | `languages/java.md` |
| `Gemfile`, `*.rb` | `languages/ruby.md` |
| `*.csproj`, `*.sln`, `*.cs` | `languages/dotnet.md` |

Then consult the cross-cutting checklists:

- `checklists/owasp-asvs.md` — OWASP Top 10 (2021) and ASVS L1 controls keyed to the eight-point check
- `checklists/endpoint-checklist.md` — per-endpoint review template
- `playbooks/triage.md` — what to do once a finding fires (severity rubric, fix templates, follow-up tickets)

## Output format

Every review emits a finding list. Nothing else.

```
[SEVERITY] <one-line summary>
File:     <path>:<line>
Category: <one of the 8 categories>
Evidence: <code snippet or pattern matched>
Fix:      <concrete change, ideally a diff>
Refs:     <CWE-XXX, OWASP A0X:2021, ASVS V-X.Y.Z>
```

Severities: `CRITICAL` (auth bypass, RCE, secret leak in prod), `HIGH` (data exposure, SSRF to internal, missing CSRF on state change), `MEDIUM` (weak crypto choice, missing rate limit, stack trace leak), `LOW` (defence-in-depth, hygiene).

If nothing fires, say so explicitly and list residual risks or untested areas — silence is not a clean bill.

## Hook integration

Three hooks ship with this skill (`/.claude/hooks/`):

- **`session-start.sh`** — fingerprints the project on session open, runs a fast dependency audit if tooling is present, and injects a security-context block so every agent in the session starts informed.
- **`pre-bash-package-guard.sh`** — gates package-manager invocations (`npm/yarn/pnpm/pip/uv/poetry/cargo/go get/gem/bundle/composer/dotnet add`). Blocks installs of typosquatted, brand-new, or known-malicious packages; prompts for confirmation on borderline cases.
- **`post-edit-quickscan.sh`** — runs a fast pattern scan on files touched by `Edit`/`Write`/`MultiEdit` and feeds findings back to the agent that made the change.

Subagents that consume this skill should treat the `## SECURITY CONTEXT` block (when injected by `session-start.sh`) as authoritative project metadata.

## Author / provenance

Maintained by Phoenix Security as part of the Phoenix developer-tooling kit. Pairs with `phoenix-final-gate` (spec-pipeline review) and `opengrep-rule-generator` (rule synthesis from findings).
