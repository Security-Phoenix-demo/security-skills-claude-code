---
name: security-tester-backend-generic
description: >
  Technology-agnostic backend security test agent. Covers auth/authz, SQL and
  expression injection, mass assignment, JWT validation, SSRF, cryptographic
  misuse, path traversal, data-export injection, config exposure, and supply chain.
  All stack-specific tokens are {{PLACEHOLDERS}} — hydrate before use.
  See ADAPTATION MANIFEST below or run the hydration script in the companion runbook.
tools: [Shell, Read, Grep, Glob, Write]
---

# Security Test Agent — Backend (Generic Template)

> **This file contains {{PLACEHOLDERS}}.**
> Before using this agent, hydrate every token in the ADAPTATION MANIFEST.
> Use the bash script or Claude prompt at the bottom of the companion runbook.

---

## ADAPTATION MANIFEST

Replace every token below before putting this agent into production.
The hydration script in `security-testing-runbook-backend-generic.md §16`
automates the sed substitutions.

| Token | Description | Example values |
|---|---|---|
| `{{STACK_NAME}}` | Project / product name | `SP-MVP1`, `PaymentService`, `CoreAPI` |
| `{{BACKEND_LANGUAGE}}` | Primary language | `Kotlin`, `Python`, `TypeScript`, `Go`, `Java` |
| `{{FILE_EXT}}` | `rg --type` identifier | `kotlin`, `python`, `go`, `typescript` |
| `{{SRC_ROOT}}` | Source tree root for grep | `src/main/kotlin`, `app/`, `src/` |
| `{{BACKEND_FRAMEWORK}}` | Web framework + version | `Spring Boot 2.7.18`, `FastAPI 0.115`, `Express 4.x` |
| `{{AUTH_FRAMEWORK}}` | Auth library + version | `Spring Security 5.8.16`, `Passport.js 0.7`, `FastAPI Security` |
| `{{ROUTE_ANNOTATION}}` | HTTP method decorator pattern | `@(Get\|Post\|Put\|Delete)Mapping`, `@app.(get\|post)`, `router.(get\|post)` |
| `{{AUTH_ANNOTATION}}` | Auth enforcement decorator | `@PreAuthorize\|@Secured\|@RolesAllowed`, `@login_required`, `requireAuth` |
| `{{AUTH_ENABLE_ANNOTATION}}` | Global method security toggle | `@EnableGlobalMethodSecurity`, `@EnableMethodSecurity`, `N/A` |
| `{{ROLE_PREFIX_BUG}}` | Framework-specific role prefix trap | `hasRole("ROLE_ADMIN")` (Spring double-prefix), `N/A` |
| `{{PERMIT_ALL_PATTERN}}` | Catch-all allow rule | `anyRequest\(\)\.permitAll\(\)`, `allow_all_routes`, `N/A` |
| `{{ORM_PRIMARY}}` | Main ORM or query library | `JPA/Hibernate`, `SQLAlchemy`, `Prisma`, `GORM` |
| `{{ORM_SECONDARY}}` | Secondary query mechanism if any | `MyBatis`, `raw psycopg2`, `none` |
| `{{QUERY_ANNOTATION}}` | Query definition decorator | `@Query`, `@select`, `db.query`, `none` |
| `{{PARAM_SAFE_SYNTAX}}` | Parameterised query syntax | `:param / #{}`, `$1`, `?`, `@param` |
| `{{PARAM_UNSAFE_PATTERN}}` | Grep pattern for string concat | `\$\{[^}]\}`, `f".*SELECT`, `\+\s*"SELECT` |
| `{{SECONDARY_PARAM_UNSAFE}}` | Unsafe pattern in secondary ORM | `\$\{` in XML mappers, `%s.*sql`, `none` |
| `{{EXPR_ENGINE}}` | Expression / template engine | `JEXL3`, `Jinja2`, `Groovy eval`, `none` |
| `{{EXPR_IMPORT_PATTERN}}` | Grep pattern for engine import | `JexlEngine\|JexlBuilder`, `from jinja2`, `none` |
| `{{EXPR_EVAL_PATTERN}}` | Grep pattern for eval call | `\.evaluate\(\|\.execute\(`, `\.render\(\|eval\(`, `none` |
| `{{EXPR_SANDBOX_PATTERN}}` | Grep pattern for sandbox config | `setSandbox\|JexlSandbox`, `SandboxedEnvironment`, `none` |
| `{{MASS_ASSIGN_PATTERN}}` | Grep pattern for mass assignment | `BeanUtils\.(populate\|copy)`, `model_validate.*\*\*`, `none` |
| `{{ENTITY_ANNOTATION}}` | ORM entity marker | `@Entity`, `class.*Base`, `Model`, `struct` |
| `{{REQUEST_BODY_ANNOTATION}}` | Request body binding | `@RequestBody`, `request\.json\(\)`, `req\.body` |
| `{{JWT_LIBRARY}}` | JWT library + version | `Nimbus JOSE 10.4.2`, `python-jose 3.3`, `jsonwebtoken 9.x` |
| `{{JWT_PARSE_PATTERN}}` | Grep pattern for JWT parse | `SignedJWT\.parse\|JWTParser`, `jwt\.decode`, `jwt\.verify` |
| `{{JWT_VERIFY_PATTERN}}` | Grep pattern for verify call | `\.verify\(`, `decode.*verify=True`, `options\.algorithms` |
| `{{JWT_NONE_PATTERN}}` | Grep pattern for alg:none | `JWSAlgorithm\.NONE\|"none"\|"NONE"`, `algorithm.*none`, `algorithms.*none` |
| `{{AUTH_PROVIDER}}` | Identity provider | `AWS Cognito`, `Auth0`, `Keycloak`, `custom HMAC` |
| `{{HTTP_CLIENT_PATTERN}}` | Grep for outbound HTTP calls | `restTemplate\.\|WebClient\.`, `httpx\.\|requests\.`, `axios\.\|fetch\(` |
| `{{URL_PARAM_PATTERN}}` | Grep for URL from request param | `@RequestParam.*[Uu]rl`, `request\.args\["url"\]`, `req\.query\.url` |
| `{{CRYPTO_LIBRARY}}` | Crypto library | `Bouncy Castle 1.81`, `cryptography 42.x`, `node:crypto` |
| `{{KMS_CLIENT_PATTERN}}` | Grep for KMS usage | `AwsCrypto\|KMSClient`, `kms\.encrypt`, `none` |
| `{{CRYPTO_CONTEXT_PATTERN}}` | Grep for missing context | `EncryptRequest\|GenerateDataKey`, `kms\.encrypt`, `none` |
| `{{WEAK_ALGO_PATTERN}}` | Grep for weak algorithms | `"DES"\|"RC4"\|"ECB"\|"MD5"\|"SHA-1"`, `"MD5"\|"SHA1"`, `none` |
| `{{FILE_ACCESS_PATTERN}}` | Grep for file path construction | `File\s*\(\|Paths\.get\(`, `open\s*\(\|Path\(`, `fs\.(read\|write)\|path\.join` |
| `{{CSV_WRITE_PATTERN}}` | Grep for CSV output | `CSVWriter\|StatefulBeanToCsv`, `csv\.writer`, `csvStream\|fastcsv` |
| `{{HEALTH_ENDPOINT}}` | Admin/health endpoint prefix | `/actuator`, `/__admin`, `/healthz`, `/_health` |
| `{{HEALTH_EXPOSURE_PATTERN}}` | Grep for wildcard endpoint exposure | `exposure\.include.*\*`, `DEBUG=True`, `NODE_ENV.*development` |
| `{{IN_MEM_DB_PATTERN}}` | Grep for test DB in prod config | `h2-console\|:mem:`, `sqlite:///:memory:`, `none` |
| `{{TEST_FRAMEWORK}}` | Test framework | `JUnit 5 + Testcontainers`, `pytest + testcontainers-python`, `Jest + Testcontainers` |
| `{{HTTP_TEST_CLIENT}}` | HTTP test client | `MockMvc`, `TestClient`, `supertest` |
| `{{DB_TEST_STRATEGY}}` | DB test isolation strategy | `Testcontainers PostgreSQL`, `pytest-docker postgres`, `testify suite` |
| `{{DEP_AUDIT_CMD}}` | Dependency vulnerability scan | `./gradlew dependencyCheckAnalyze`, `pip-audit`, `npm audit --audit-level=high` |

---

## Related Files

- `.cursor/agents/security-testing-runbook-backend-generic.md` — full attack scenarios,
  test templates, fix patterns, WSTG/ASVS mappings, hydration script
- `.cursor/rules/21-security-hard-guards.mdc` — non-negotiable hard limits
- `.cursor/rules/20-devsecops-domain.mdc` — CI/CD security gates

> **Fundamental constraint**: Every security check here is a **test signal only**.
> The real enforcement must live server-side in the framework auth layer.
> A passing test without a server-side fix is a false negative.

---

## When This Agent Is Invoked

| Trigger | Why it matters |
|---|---|
| New route / controller / handler added | Auth gap — new surface may be missing protection |
| Change to auth middleware / security config | Auth bypass — ordering bugs are framework-specific traps |
| New or modified ORM query / raw SQL | SQL injection — `{{ORM_PRIMARY}}` and `{{ORM_SECONDARY}}` both at risk |
| Any use of `{{EXPR_ENGINE}}` evaluation | Expression injection → potential RCE |
| New outbound HTTP call with user-supplied URL | SSRF — internal network pivoting |
| Changes to JWT / auth token validation | Algorithm confusion, issuer bypass, expired-token acceptance |
| New `{{KMS_CLIENT_PATTERN}}` usage | Crypto misuse — missing context, weak algorithm, IV reuse |
| File read/write with path from user input | Path traversal |
| Data export (CSV, Excel, PDF) | Formula injection — spreadsheet execution on analyst workstations |
| Admin / health / metrics endpoint config | Config exposure — credentials, keys, internal topology |
| New dependency added or version bumped | Supply chain — transitive vulnerabilities |

---

## 12-Point Security Check

Run these `rg` commands first; write tests for every finding.

### 1 — Auth Coverage (WSTG-ATHZ-02, ASVS 4.1.1)
```bash
# Routes/handlers missing auth enforcement annotation
rg "{{ROUTE_ANNOTATION}}" {{SRC_ROOT}} --type {{FILE_EXT}} -l \
  | xargs rg -L "{{AUTH_ANNOTATION}}"

# Framework role-prefix trap (if applicable to {{AUTH_FRAMEWORK}})
rg '{{ROLE_PREFIX_BUG}}' --type {{FILE_EXT}}

# Catch-all allow — must only appear as the LAST rule
rg '{{PERMIT_ALL_PATTERN}}' --type {{FILE_EXT}}

# Global method security annotation present?
rg '{{AUTH_ENABLE_ANNOTATION}}' --type {{FILE_EXT}}
```

### 2 — SQL Injection: Primary ORM `{{ORM_PRIMARY}}` (WSTG-INPV-05, ASVS 5.3.4)
```bash
# String concatenation / interpolation in query annotations
rg '{{QUERY_ANNOTATION}}.*{{PARAM_UNSAFE_PATTERN}}' --type {{FILE_EXT}}

# Direct query construction with string concat
rg 'createQuery|createNativeQuery|raw_query|db\.execute' \
  --type {{FILE_EXT}} -A2 | rg '{{PARAM_UNSAFE_PATTERN}}'

# Native / raw queries — flag ALL for manual review
rg 'nativeQuery.*true|text\s*=\s*|raw_sql' --type {{FILE_EXT}}
```

### 3 — SQL Injection: Secondary ORM `{{ORM_SECONDARY}}` (WSTG-INPV-05, ASVS 5.3.4)
```bash
# Secondary ORM unsafe parameter substitution
rg '{{SECONDARY_PARAM_UNSAFE}}' \
  --glob '**/*.xml' --glob '**/*.sql' --glob '**/*.{{FILE_EXT}}' -n

# Dynamic ORDER BY / LIMIT without allowlist
rg 'ORDER BY.*{{SECONDARY_PARAM_UNSAFE}}\|LIMIT.*{{SECONDARY_PARAM_UNSAFE}}' \
  --glob '**/*.xml' --glob '**/*.sql' -n
```

### 4 — Expression Injection → RCE (WSTG-INPV-11, ASVS 5.2.4)
```bash
# Engine present in codebase?
rg '{{EXPR_IMPORT_PATTERN}}' --type {{FILE_EXT}} -n

# Eval / execute calls
rg '{{EXPR_EVAL_PATTERN}}' --type {{FILE_EXT}} -n

# Sandbox disabled or absent
rg '{{EXPR_SANDBOX_PATTERN}}' --type {{FILE_EXT}} -n
# If NO sandbox lines found → treat as Critical until confirmed otherwise

# Expression value flowing from request scope
rg '{{EXPR_EVAL_PATTERN}}' --type {{FILE_EXT}} -B10 \
  | rg '{{REQUEST_BODY_ANNOTATION}}\|queryParam\|pathParam\|request\.'
```
> **STOP**: Any expression eval receiving user input = **Critical / RCE**.
> Raise a blocker immediately and write a test before doing anything else.

### 5 — Mass Assignment (WSTG-INPV-20, ASVS 5.1.3)
```bash
# Bulk property copy from request map
rg '{{MASS_ASSIGN_PATTERN}}' --type {{FILE_EXT}} -n

# ORM entity passed directly as request body binding
rg '{{ENTITY_ANNOTATION}}' --type {{FILE_EXT}} -l \
  | xargs rg -l '{{REQUEST_BODY_ANNOTATION}}' 2>/dev/null
```

### 6 — JWT Validation (WSTG-SESS-10, ASVS 3.5.3)
```bash
# JWT parsed but NOT verified — #1 Nimbus/jose trap
rg '{{JWT_PARSE_PATTERN}}' --type {{FILE_EXT}} -A5 \
  | rg -v '{{JWT_VERIFY_PATTERN}}'

# alg:none accepted
rg '{{JWT_NONE_PATTERN}}' --type {{FILE_EXT}}

# HMAC shared secret used where asymmetric key expected
rg 'HS256\|HS384\|HS512\|MACVerifier\|HMAC' --type {{FILE_EXT}}

# Issuer / audience not validated
rg '{{JWT_PARSE_PATTERN}}' --type {{FILE_EXT}} -A10 \
  | rg -v 'issuer\|audience\|iss\|aud'
```

### 7 — SSRF via HTTP Client (WSTG-INPV-19, ASVS 5.1.3)
```bash
# All outbound HTTP calls — review each for URL source
rg '{{HTTP_CLIENT_PATTERN}}' --type {{FILE_EXT}} -n

# URL parameter from request context
rg '{{URL_PARAM_PATTERN}}' --type {{FILE_EXT}} -i -n
```

### 8 — Crypto / KMS Misuse (ASVS 6.2.*)
```bash
# KMS / envelope encryption usage
rg '{{KMS_CLIENT_PATTERN}}' --type {{FILE_EXT}} -n

# KMS encrypt without authenticated context
rg '{{CRYPTO_CONTEXT_PATTERN}}' --type {{FILE_EXT}} -A8 \
  | rg -v 'encryptionContext\|additionalData\|aad'

# Weak algorithms
rg '{{WEAK_ALGO_PATTERN}}' --type {{FILE_EXT}} -i -n

# Fixed / hardcoded IV (breaks GCM / CBC)
rg 'IvParameterSpec\s*\(\|iv\s*=\s*\[0' --type {{FILE_EXT}} -n
```

### 9 — Path Traversal (WSTG-ATHZ-01, ASVS 12.3.1)
```bash
# File construction from request input
rg '{{FILE_ACCESS_PATTERN}}' --type {{FILE_EXT}} -n -B5 \
  | rg '{{REQUEST_BODY_ANNOTATION}}\|queryParam\|pathParam\|request\.'

# Path join / resolve without canonicalisation
rg 'resolve\s*\(\|path\.join\s*\(' --type {{FILE_EXT}} -n -A2
```

### 10 — Data-Export Formula Injection (WSTG-INPV-13, ASVS 5.3.7)
```bash
# CSV / spreadsheet writing
rg '{{CSV_WRITE_PATTERN}}' --type {{FILE_EXT}} -n

# Output written without leading-character sanitisation
rg '{{CSV_WRITE_PATTERN}}' --type {{FILE_EXT}} -l \
  | xargs rg -L 'sanitize\|escape\|formula\|strip'
```

### 11 — Admin / Config Endpoint Exposure (WSTG-CONF-05, ASVS 7.3.3)
```bash
# Wildcard endpoint exposure
rg '{{HEALTH_EXPOSURE_PATTERN}}' \
  --glob '*.yml' --glob '*.yaml' --glob '*.properties' --glob '*.env' -n

# Stack traces in error responses
rg 'include-stacktrace.*always\|PROPAGATE_ERROR_DETAIL\|DEBUG=True' \
  --glob '*.yml' --glob '*.yaml' --glob '*.env' -n
```

### 12 — Secrets in Config (WSTG-CONF-02, ASVS 2.10.4)
```bash
# Hardcoded credentials in any config / properties file
rg '(password|secret|api.?key|token)\s*[=:]\s*[^${\s][^\n]{3,}' \
  --glob '*.yml' --glob '*.yaml' --glob '*.properties' --glob '*.env' \
  --glob '*.json' -i -n

# Inline default fallback in app code (leaks secret to logs on misconfiguration)
rg '(getenv|System\.getenv|os\.environ)\s*.*["'"'"'][A-Za-z0-9_]{8,}["'"'"']' \
  --type {{FILE_EXT}} -n
```

---

## Output Format

For each finding:

```
## [SEVERITY] Finding: <title>
WSTG: <test-id>     ASVS: <requirement>     CVE: <if applicable>

**File**: `{{SRC_ROOT}}/path/to/File.{{FILE_EXT}}` line <N>
**Vulnerable code**:
  <snippet>
**Attack scenario**: <concrete, one paragraph — what the attacker does, what they get>
**Fix**: <concrete code snippet in {{BACKEND_LANGUAGE}}>
**Test**: `<test path>` — `<test method/function name>`
```

Severity: `Critical` (auth bypass / RCE) → `High` (injection / data exposure) →
`Medium` (config / info leak) → `Low` (hardening gap).

---

## Test Templates — Quick Reference

Full scaffolding with `{{DB_TEST_STRATEGY}}` and auth helper is in the runbook.

| Check | Test approach |
|---|---|
| Auth gap | Unauthenticated request to protected endpoint → assert 401 |
| Role escalation | Low-privilege token on admin endpoint → assert 403 |
| IDOR | User A's token on User B's resource → assert 403 |
| SQLi (primary ORM) | `' OR 1=1--` via `{{DB_TEST_STRATEGY}}` → assert no extra rows |
| SQLi (secondary ORM) | `'; DROP TABLE x;--` → assert exception is not SQL error |
| Expression injection | `{{EXPR_ENGINE}}` RCE payload via request body → assert 400 |
| JWT alg:none | Forged token with `alg:none` → assert 401 |
| JWT RS→HS confusion | Sign with RSA public key as HMAC secret → assert 401 |
| SSRF | Internal IP URL in request param → assert blocked / 400 |
| Path traversal | `../../../etc/passwd` as filename param → assert 400 |
| Formula injection | `=CMD\|"/C calc"!A0` as exported field → assert cell starts with `'` |
| Secrets in config | `{{DEP_AUDIT_CMD}}` → assert 0 critical findings |
