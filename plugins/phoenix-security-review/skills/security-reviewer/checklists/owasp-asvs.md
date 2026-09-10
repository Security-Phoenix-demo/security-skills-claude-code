# OWASP Top 10 (2021) + ASVS L1 — keyed to the 8-point check

The skill's 8 categories cover the OWASP Top 10 and the ASVS L1 controls a senior reviewer should care about pre-merge. This file is the cross-reference.

## A01: Broken Access Control → Check 1 (Authn/Authz)

- Every state-changing endpoint requires authentication (ASVS V4.1.1)
- Authorization decisions made server-side, never trusted from the client (V4.2.1)
- Resource ownership checked on every read/write — `GET /orders/123` must verify `123` belongs to the caller (V4.2.2)
- Force-browsing protected — direct object references either UUIDs or wrapped through an authorization service (V4.4.1)
- CORS allow-list explicit; never `*` with `credentials: true` (V14.5.3)

## A02: Cryptographic Failures → Check 4 (Secrets) + Check 6 (Config)

- TLS 1.2+ only; HSTS preload-eligible config (V9.1.2)
- Passwords hashed with bcrypt / Argon2 / scrypt / PBKDF2 with appropriate work factor (V2.4.1, V2.4.4)
- Secrets in env or secret manager, never in source, never client-side, never in URLs (V14.3.2)
- Sensitive data not logged at INFO/DEBUG (V8.3.4)
- JWT signing keys 256-bit minimum; HS256 only with strong keys, prefer RS256/ES256 in multi-service setups (V3.5.3)

## A03: Injection → Check 5 (Input Handling)

- Parameterised queries everywhere; raw SQL only with allow-listed identifiers (V5.3.4, V5.3.5)
- Command exec uses argv arrays, never shell strings with interpolation (V5.3.8)
- LDAP / XPath / NoSQL queries parameterised the same way (V5.3.7)
- Template engines render with autoescape on; raw / unsafe markers reviewed (V5.2.5)

## A04: Insecure Design → Check 1 + Check 8

- Rate limits on auth endpoints, password reset, OTP (V11.1.4)
- Account lockout / progressive delay on failed auth (V2.2.1)
- Business-logic limits — max items per cart, max API calls per second per tenant (V11.1.2)
- Threat model documented for any feature touching money, PII, or admin functions

## A05: Security Misconfiguration → Check 6 (Config)

- Security headers shipped: CSP, HSTS, X-Content-Type-Options: nosniff, Referrer-Policy, X-Frame-Options or `frame-ancestors` (V14.4.1–V14.4.7)
- Default credentials removed (V2.10.1)
- Stack traces / verbose errors disabled in production (V7.4.1)
- Admin interfaces not network-exposed (V1.10.1)
- Container / cloud config: no privileged mode, no host network, no `:latest` images in prod (V14.1.4)

## A06: Vulnerable & Outdated Components → Check 7 (Supply Chain)

- All deps tracked in lockfile (V14.2.1)
- CVE / advisory scan in CI; build fails on `HIGH+` unless waived (V14.2.4)
- License compliance scan
- Provenance: SLSA-style attestation if shipping artifacts (V10.3.2)
- No deps from non-canonical registries without explicit allow

## A07: Identification & Auth Failures → Check 1 (Authn/Authz)

- MFA available and enforced for admin (V2.7.1)
- Session tokens regenerated on auth and privilege change (V3.2.3)
- Cookies: `Secure`, `HttpOnly`, `SameSite=Lax` minimum (V3.4.1–V3.4.3)
- Password reset tokens short-lived, single-use, bound to the account (V2.5.1)

## A08: Software & Data Integrity → Check 7 + Check 5

- Deserialisation only from trusted sources, with type allow-lists (V5.5.2)
- Auto-updates / live code reload disabled in prod (V10.3.3)
- CI/CD: signed commits where the threat model demands; protected branches with required reviews

## A09: Logging & Monitoring → Check 8 (Failure Modes)

- Auth events, access-control failures, input validation failures all logged (V7.1.1)
- Logs don't contain secrets, full credit-card numbers, or full session tokens (V7.1.4)
- Centralised log aggregation; tamper-resistant (V7.4.3)
- Alerts on auth-failure spikes, 5xx surges, dependency advisory matches

## A10: SSRF → Check 3 (SSRF)

- All outbound URLs validated against an allow-list of schemes + hosts (V12.6.1)
- DNS rebinding mitigated — resolve once, fetch via IP, set `Host` header explicitly
- Cloud metadata (`169.254.169.254`, `metadata.google.internal`) blocked at egress
- Redirect hops bounded and re-validated

---

If a finding doesn't fit one of the eight categories, that's a sign either the categories need updating or the finding is out of scope (e.g., infra-only, business-logic governance, supply-chain provenance beyond CVE scan).
