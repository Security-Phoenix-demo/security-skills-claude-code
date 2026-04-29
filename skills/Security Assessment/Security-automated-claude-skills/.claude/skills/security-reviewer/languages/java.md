# Java / Kotlin — Security Review Reference

Covers Spring Boot, Quarkus, Micronaut, plain Servlet, Jakarta EE, Ktor, Vert.x.

## Manifest files

`pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle*`, `gradle.lockfile`. Lockfile (`gradle.lockfile` or Maven `dependencyManagement` BOM) must pin transitive versions. Repository declarations beyond `mavenCentral` / `gradlePluginPortal` need justification.

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| Spring Security | `SecurityFilterChain`, `@PreAuthorize`, `@RolesAllowed` | `permitAll()` paths reviewed; `csrf().disable()` only for stateless APIs |
| Spring MVC | `@RequestMapping`, `@GetMapping`, etc. | every controller method either annotated or covered by chain config |
| JAX-RS / Quarkus | `@RolesAllowed`, `@PermitAll`, `@DenyAll` | no `@PermitAll` on write methods |
| Micronaut | `@Secured(...)` | `@Secured(SecurityRule.IS_ANONYMOUS)` audit |
| Ktor | `authenticate { ... }` block | every protected route inside an `authenticate` block; `optional = true` reviewed |
| Servlet | `web.xml` `<security-constraint>` or filters | URL patterns cover all sensitive paths |

Watch for: Spring Security `http.authorizeHttpRequests(a -> a.anyRequest().permitAll())`, custom `Filter` ordering that puts auth after a logging filter that already responded, and JWT verification with `Algorithm.none()` / `setSigningKey(null)`.

## Output / templating

- Thymeleaf `th:utext` (unescaped) on user input — XSS
- JSP `<%= userInput %>` without `<c:out value="${userInput}"/>`
- Freemarker `${userInput}` is escaped only when `outputFormat="HTML"` is set
- Velocity has no built-in escaping
- `ResponseEntity.ok().body(html)` built by string concat
- Markdown rendered via `commonmark-java` without `Sanitizer` (use OWASP Java HTML Sanitizer / `jsoup.clean`)

## Outbound HTTP / SSRF

- `RestTemplate`, `WebClient`, `HttpClient` (java.net.http), `OkHttpClient`, Apache HttpClient, `URL.openConnection`
- `RestTemplate` follows redirects by default; configure with `SimpleClientHttpRequestFactory` setting `setOutputStreaming(false)` and a custom redirect strategy
- Validate target with `URI.create(...)` then `InetAddress.getAllByName(host)` and reject private ranges
- `URL.openConnection` with `userInput` is the simplest SSRF — flag every occurrence

## SQL & ORM

- `Statement.executeQuery("SELECT ... " + x)` — string concatenation
- `JdbcTemplate.queryForObject("... " + x, ...)` — same
- JPA `entityManager.createQuery("... " + x)` instead of named parameters
- `@Query("SELECT ... :name")` is fine; `@Query(nativeQuery = true)` with concatenation is not
- MyBatis `${x}` (substitution) vs `#{x}` (parameter binding) — `${x}` with user input is injection

## XML / XXE

- `DocumentBuilderFactory`, `SAXParserFactory`, `XMLInputFactory` without `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` and `XMLConstants.FEATURE_SECURE_PROCESSING`
- `Transformer` / `TransformerFactory` without `XMLConstants.ACCESS_EXTERNAL_DTD` set to empty
- Jackson XML `XmlMapper` without DOCTYPE disabled

## Deserialisation / RCE

- `ObjectInputStream.readObject()` on untrusted bytes — historical RCE goldmine; banned outright in modern code
- Jackson `enableDefaultTyping()` / `activateDefaultTyping(...)` — gadget chains
- `Yaml.load(...)` (snakeyaml < 2.0) — RCE; use `new Yaml(new SafeConstructor(...))` or upgrade to 2.x default
- `XStream` without typed allowlist
- `Runtime.getRuntime().exec(userInput)` — command injection
- `ProcessBuilder` with `.command(String.join(" ", parts))` and shell expansion
- SpEL: `expression.getValue(rootObject)` where `expression` is parsed from user input — RCE
- Spring `@Value("#{userInput}")` reading from request — RCE if SpEL evaluates

## Crypto / TLS

- `MessageDigest.getInstance("MD5"|"SHA-1")` for passwords — use `BCryptPasswordEncoder`, `Argon2PasswordEncoder`
- `Random` for tokens — use `SecureRandom`
- `TrustManager` that overrides `checkServerTrusted` to do nothing — disables TLS verification
- `HostnameVerifier` returning `true` unconditionally
- `SSLContext.getInstance("SSL")` — pinned to deprecated SSLv3; use `TLSv1.2` minimum

## Diagnostic ripgrep patterns

```bash
# Auth
rg -n '@(GetMapping|PostMapping|PutMapping|DeleteMapping|RequestMapping|Path)\b' -g '*.{java,kt}'
rg -n 'permitAll\(\)|csrf\(\)\.disable\(\)' -g '*.{java,kt}'
rg -n 'Algorithm\.none|setSigningKey\(\s*null' -g '*.{java,kt}'

# Templates
rg -n 'th:utext|<%=\s*\w' -g '*.{java,kt,jsp,html}'

# SSRF
rg -n '(RestTemplate|WebClient|OkHttpClient|HttpClient|URL)\.|new URL\(' -g '*.{java,kt}'

# SQL
rg -n 'createQuery\(\s*"[^"]*"\s*\+|executeQuery\(\s*"[^"]*"\s*\+' -g '*.{java,kt}'
rg -n 'nativeQuery\s*=\s*true' -g '*.{java,kt}'
rg -n '\$\{[^#}]*\}' -g '*.xml' -g 'mappers/**'

# XXE
rg -n 'DocumentBuilderFactory|SAXParserFactory|XMLInputFactory|TransformerFactory' -g '*.{java,kt}'

# Deserialisation
rg -n 'ObjectInputStream|enableDefaultTyping|activateDefaultTyping|XStream\(' -g '*.{java,kt}'
rg -n 'snakeyaml|new Yaml\(' -g '*.{java,kt}'

# RCE
rg -n 'Runtime\.getRuntime\(\)\.exec|new ProcessBuilder' -g '*.{java,kt}'
rg -n 'SpelExpressionParser|parseExpression\(' -g '*.{java,kt}'

# Crypto
rg -n 'MessageDigest\.getInstance\("(MD5|SHA-?1)' -g '*.{java,kt}'
rg -n 'new Random\(' -g '*.{java,kt}'

# TLS bypass
rg -n 'X509TrustManager|HostnameVerifier|InsecureSkipVerify' -g '*.{java,kt}'
```

## Dependency audit

Prefer `osv-scanner -r .`. Otherwise OWASP Dependency-Check (`mvn dependency-check:check` / `gradle dependencyCheckAnalyze`), Snyk CLI, or `mvn versions:display-dependency-updates`. For Spring, watch CVEs against the Spring BOM; transitive Tomcat / Netty / Jackson upgrades require integration testing.
