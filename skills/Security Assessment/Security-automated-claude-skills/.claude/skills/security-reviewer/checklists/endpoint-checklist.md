# Per-Endpoint Review Checklist

Use this when reviewing a single new or changed HTTP route, RPC handler, or queue consumer.

## Pre-flight

- [ ] What does this endpoint do, in one sentence?
- [ ] Who is the intended caller — anonymous user, authenticated user, admin, internal service?
- [ ] What does it read? What does it write? What does it send outbound?

## Authentication

- [ ] Is auth required? If "no", is that justified and signed off?
- [ ] How is the caller identified — session cookie, JWT, API key, mTLS?
- [ ] Where is the auth check made — middleware, decorator, handler? Is it possible to skip it?
- [ ] If JWT: algorithm pinned? Issuer + audience + lifetime validated? Key rotation handled?

## Authorisation

- [ ] What role/permission is required?
- [ ] If a resource ID is in the request, is ownership / tenant-scope checked?
- [ ] Could a user with role X read or modify another user's data?
- [ ] If multi-tenant: is the tenant ID server-derived (from session) or client-supplied (dangerous)?

## Input

- [ ] Every parameter has a typed, bounded validator (length, charset, range)
- [ ] Free-form strings used in queries: parameterised
- [ ] Free-form strings used in shell commands: forbidden, or argv-style
- [ ] File paths: contained against a base directory after `realpath`
- [ ] URLs from input that drive outbound HTTP: validated against the SSRF allow-list
- [ ] Redirect targets: only allowlisted relative paths or known domains
- [ ] Deserialisation: only from trusted formats with type allow-lists

## Output

- [ ] HTML response: autoescape is on for the templating engine
- [ ] JSON response: no fields leaked beyond what this caller's role can see
- [ ] Error response: no stack trace, no internal IDs, no PII
- [ ] Headers: security headers present (CSP / HSTS / X-Content-Type-Options) — if not endpoint-specific, confirmed at the framework layer

## Side effects

- [ ] Idempotent? If not, is that intentional and documented?
- [ ] Rate-limited? At what scope — per IP, per user, per tenant?
- [ ] Audited? Auth events, access-control failures, sensitive writes logged?
- [ ] Outbound calls have timeouts and retries with backoff?

## Failure mode

- [ ] What happens if the auth service is down? (Should fail closed.)
- [ ] What happens if the database errors mid-write? (Transaction or saga?)
- [ ] What happens if the outbound HTTP times out? (Caller doesn't hang.)
- [ ] Errors don't reveal whether a user / record exists when that's a privacy concern

## Cleanup

- [ ] Sensitive intermediate values (passwords, tokens) zeroed where the language supports it
- [ ] Temp files cleaned up
- [ ] No logs of full request body when it might contain secrets

If all rows pass, mark the endpoint reviewed in the PR. If any fail, the finding goes in the report.
