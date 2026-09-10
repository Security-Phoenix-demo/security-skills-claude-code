---
name: security-tester-frontend-generic
description: >
  Technology-agnostic frontend security test agent. Covers XSS sinks, markdown
  rendering, visualisation injection, auth token storage, HTTP interceptor leakage,
  state management DevTools exposure, routing/open redirect, client-side permission
  bypass, third-party widget injection, decompression bombs, CSP/security headers,
  and secrets in the JS bundle. All stack tokens are {{PLACEHOLDERS}} — hydrate
  before use. See ADAPTATION MANIFEST below or run the hydration script in the
  companion runbook.
tools: [Shell, Read, Grep, Glob, Write]
---

# Security Test Agent — Frontend (Generic Template)

> **This file contains {{PLACEHOLDERS}}.**
> Before using this agent, hydrate every token in the ADAPTATION MANIFEST.
> Use the bash script or Claude prompt at the bottom of the companion runbook.

---

## ADAPTATION MANIFEST

| Token | Description | Example values |
|---|---|---|
| `{{STACK_NAME}}` | Project / product name | `SP-MVP1`, `DashboardApp` |
| `{{FE_FRAMEWORK}}` | Frontend framework + version | `Angular 20.3.16`, `React 18`, `Vue 3.4` |
| `{{FE_FILE_EXT}}` | TypeScript/JS file extension | `ts`, `tsx`, `jsx`, `vue` |
| `{{TEMPLATE_EXT}}` | Template file extension | `html`, `tsx`, `jsx`, `vue` |
| `{{SRC_ROOT}}` | Source root | `src/app`, `src/`, `src/` |
| `{{SANITIZE_BYPASS_FN}}` | Framework XSS bypass API | `bypassSecurityTrustHtml`, `dangerouslySetInnerHTML`, `v-html` |
| `{{SANITIZE_BYPASS_PATTERN}}` | Grep pattern for bypass | `bypassSecurityTrust(Html\|Style\|Script\|Url)`, `dangerouslySetInnerHTML`, `v-html` |
| `{{BINDING_SYNTAX}}` | Template HTML binding | `[innerHTML]`, `dangerouslySetInnerHTML`, `v-html` |
| `{{TEMPLATE_ESCAPE_HATCH}}` | Template type-escape API | `$any()`, `as any`, `v-bind` |
| `{{DOM_WRITE_PATTERN}}` | Direct DOM write pattern | `nativeElement\.(innerHTML\|outerHTML)`, `\.innerHTML\s*=`, `el\.innerHTML\s*=` |
| `{{NATIVE_ELEMENT_PATTERN}}` | Access to native DOM element | `nativeElement`, `useRef\(\)`, `this\.\$el` |
| `{{SANITIZE_LIB}}` | Client-side sanitisation library | `DOMPurify` (universal default) |
| `{{STATE_LIBRARY}}` | State management library + version | `NgRx 20.1.0`, `Redux Toolkit 2.x`, `Pinia 2.x` |
| `{{DEVTOOLS_MODULE}}` | DevTools extension module | `StoreDevtoolsModule`, `devTools()`, `devtools: true` |
| `{{DEVTOOLS_PROD_GUARD}}` | Production DevTools guard | `isDevMode()`, `process.env.NODE_ENV !== 'production'`, `import.meta.env.PROD` |
| `{{DEVTOOLS_SANITIZER}}` | DevTools state/action sanitizer | `stateSanitizer / actionSanitizer`, `actionCreatorCheck`, `none` |
| `{{HTTP_CLIENT}}` | HTTP client | `HttpClient`, `axios`, `fetch` |
| `{{HTTP_INTERCEPTOR}}` | Interceptor/middleware mechanism | `HttpInterceptor`, `axios interceptors`, `fetch wrapper` |
| `{{AUTH_HEADER_PATTERN}}` | Grep pattern for auth header | `Authorization\|Bearer`, `Authorization`, `Bearer` |
| `{{ALLOWED_ORIGINS_CONFIG}}` | Name of origin allowlist | `ALLOWED_ORIGINS`, `secureRoutes`, `allowedUrls` |
| `{{ROUTER}}` | Client-side router | `Angular Router`, `React Router v6`, `Vue Router 4` |
| `{{NAVIGATE_FN_PATTERN}}` | Grep pattern for navigation calls | `router\.navigate\|navigateByUrl`, `useNavigate\|history\.push`, `router\.push\|router\.replace` |
| `{{RETURN_URL_PARAM}}` | Open redirect query param name | `returnUrl`, `redirect`, `next`, `callbackUrl` |
| `{{PERMISSION_LIB}}` | Client-side permission library | `ngx-permissions`, `CASL`, `vue-gates`, `none` |
| `{{PERMISSION_DIRECTIVE}}` | Permission template directive | `*ngxPermissionsOnly`, `<Can>`, `v-can`, `none` |
| `{{PERMISSION_SERVICE}}` | Permission service | `NgxPermissionsService`, `useAbility()`, `usePermission()` |
| `{{MARKDOWN_LIB}}` | Markdown rendering library + version | `marked 4.2.4`, `react-markdown 9.x`, `markdown-it 14.x` |
| `{{MARKDOWN_PARSE_FN}}` | Markdown parse function pattern | `marked\.parse\|marked\s*\(`, `ReactMarkdown`, `md\.render\(` |
| `{{MARKDOWN_BROKEN_SANITIZE}}` | Deprecated/no-op sanitize option | `sanitize:\s*true`, `allowDangerousHtml`, `html:\s*true` |
| `{{VIZ_LIB}}` | Data visualisation library | `ECharts 5.6.0`, `Chart.js 4.x`, `D3.js 7.x` |
| `{{VIZ_FORMATTER_PATTERN}}` | Grep for HTML formatters | `formatter\s*:`, `generateHTML\s*:`, `\.html\s*\(` |
| `{{VIZ_ENCODE_FN}}` | Library's HTML-encode function | `echarts.format.encodeHTML`, `Chart.helpers.escapeHtml`, `DOMPurify.sanitize` |
| `{{VIZ_INNER_HTML_SINK}}` | Visualisation innerHTML write | `formatter.*=>.*<`, `\.html\s*\(`, `innerHTML.*=` |
| `{{THIRD_PARTY_WIDGET}}` | Embeddable widget library | `angularx-qrcode`, `react-qr-code`, `vue-qrcode`, `none` |
| `{{WIDGET_DATA_PATTERN}}` | Grep for widget data binding | `\[qrdata\]\|qrdata\s*=`, `value=\{`, `\:data=`, `none` |
| `{{COMPRESS_LIB}}` | Compression library or `none` | `pako 2.1.0`, `fflate 0.8`, `lz-string 1.5`, `none` |
| `{{COMPRESS_FN_PATTERN}}` | Grep for decompress call | `pako\.(inflate\|ungzip)`, `fflate\.decompress`, `none` |
| `{{TEST_FRAMEWORK}}` | Frontend test framework | `Karma/Jasmine`, `Jest/React Testing Library`, `Vitest` |
| `{{TEST_DESCRIBE_FN}}` | Test describe block function | `describe(`, `describe(`, `describe(` |
| `{{TEST_IT_FN}}` | Test case function | `it(`, `test(`, `it(` |
| `{{TEST_FIXTURE}}` | Component test fixture API | `ComponentFixture`, `render()`, `mount()` |
| `{{PACKAGE_MANAGER}}` | Package manager | `npm`, `pnpm`, `yarn` |
| `{{BUILD_TOOL}}` | Build tool | `Angular CLI 20.x`, `Vite 5.x`, `webpack 5.x` |
| `{{PROD_BUILD_CMD}}` | Production build command | `ng build --configuration production`, `npm run build`, `vite build` |
| `{{LINT_CMD}}` | Linting command | `npx eslint src/`, `npm run lint` |
| `{{DEP_AUDIT_CMD}}` | Dependency audit command | `npm audit --audit-level=high`, `pnpm audit` |
| `{{SOURCEMAP_CHECK}}` | Source map production check | `ls dist/**/*.map`, `ls build/**/*.map` |
| `{{LIFECYCLE_HOOK_PATTERN}}` | Post-render lifecycle hooks | `afterRender\|afterNextRender`, `useEffect\|useLayoutEffect`, `mounted\|updated` |

---

## Related Files

- `.cursor/agents/security-testing-runbook-frontend-generic.md` — full attack
  scenarios, test templates, fix patterns, WSTG/ASVS mappings, hydration script
- `.cursor/rules/21-security-hard-guards.mdc` — non-negotiable hard limits

> **Foundational constraint (ASVS 4.1.1)**: The frontend is always an untrusted
> client. `{{PERMISSION_LIB}}` directives, route guards, and interceptor checks
> are UX convenience only. Every access decision must be enforced server-side.

---

## When This Agent Is Invoked

| Trigger | Why it matters |
|---|---|
| Any `{{BINDING_SYNTAX}}` binding or `{{SANITIZE_BYPASS_FN}}` call | Direct XSS — framework sanitiser bypassed |
| New `{{MARKDOWN_PARSE_FN}}` call or markdown renderer | `{{MARKDOWN_LIB}}` sanitiser behaviour — see §2 for version-specific risks |
| `{{VIZ_LIB}}` formatter / label returning HTML | Server data injected into unsanitised DOM via `{{VIZ_FORMATTER_PATTERN}}` |
| D3 / SVG `.html()` or `innerHTML` write | Direct innerHTML to SVG — no framework sanitisation |
| New or modified `{{HTTP_INTERCEPTOR}}` | Auth token leakage to third-party domains |
| Auth token stored in `localStorage` / `sessionStorage` | Full account takeover on any XSS |
| `{{DEVTOOLS_MODULE}}` configuration change | Sensitive state visible in browser DevTools extension |
| New `canActivate` / route guard added | Client-side auth — must have server-side counterpart |
| `{{PERMISSION_DIRECTIVE}}` added to template | Client-side only — trivially bypassed in DevTools |
| `{{THIRD_PARTY_WIDGET}}` data bound from user input | Malformed data → injection or DoS in widget |
| `{{COMPRESS_LIB}}` decompression of server / user data | Decompression bomb, potential prototype pollution |
| `{{NAVIGATE_FN_PATTERN}}` with dynamic `{{RETURN_URL_PARAM}}` | Open redirect — phishing pivot |
| `{{NATIVE_ELEMENT_PATTERN}}` access that writes HTML | DOM write bypassing framework sanitiser |
| `{{LIFECYCLE_HOOK_PATTERN}}` writing to DOM | Post-render write — invisible to sanitiser |
| `environment.ts` containing API keys or secrets | Secrets compiled into public JS bundle |
| `{{DEVTOOLS_MODULE}}` not gated on `{{DEVTOOLS_PROD_GUARD}}` | DevTools active in production |
| CSP / security headers changed | XSS blast radius expansion |

---

## 12-Point Security Check

Run these `rg` commands first; write tests for every finding.

### 1 — Framework XSS Sinks (WSTG-INPV-01/02, WSTG-CLNT-01, ASVS 5.2.1)
```bash
# Framework sanitiser bypass — each call is a mandatory manual review
rg "{{SANITIZE_BYPASS_PATTERN}}" --type {{FE_FILE_EXT}} -n --color always

# Template HTML bindings
rg "{{BINDING_SYNTAX}}" --glob "*.{{TEMPLATE_EXT}}" --glob "*.{{FE_FILE_EXT}}" -n

# Direct DOM writes bypassing framework
rg "{{DOM_WRITE_PATTERN}}" --type {{FE_FILE_EXT}} -n

# eval / document.write / new Function
rg "(document\.write|eval\s*\(|new Function\s*\()" --type {{FE_FILE_EXT}} -n

# Template escape hatch hiding unsafe data flows
rg '{{TEMPLATE_ESCAPE_HATCH}}' --glob "*.{{TEMPLATE_EXT}}" -n

# Post-render lifecycle DOM writes (framework-version risk)
rg "{{LIFECYCLE_HOOK_PATTERN}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg "{{DOM_WRITE_PATTERN}}\|{{NATIVE_ELEMENT_PATTERN}}" 2>/dev/null
```

### 2 — Markdown Library XSS (WSTG-INPV-01, ASVS 5.2.1)
```bash
# All parse call sites
rg "{{MARKDOWN_PARSE_FN}}" --type {{FE_FILE_EXT}} -n

# Markdown used WITHOUT {{SANITIZE_LIB}} on the same file
rg "{{MARKDOWN_PARSE_FN}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg -L "DOMPurify\|purify\|sanitize"

# Deprecated no-op sanitize option (version-specific)
rg "{{MARKDOWN_BROKEN_SANITIZE}}" --type {{FE_FILE_EXT}} -n

# Markdown output bound to HTML binding (compound risk)
rg "{{MARKDOWN_PARSE_FN}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg "{{BINDING_SYNTAX}}" --glob "*.{{TEMPLATE_EXT}}" 2>/dev/null
```

### 3 — Visualisation Library Injection (WSTG-CLNT-01, ASVS 5.2.1)
```bash
# HTML formatters / tooltips in chart definitions
rg "{{VIZ_FORMATTER_PATTERN}}" --type {{FE_FILE_EXT}} \
  -g "*chart*" -g "*echart*" -g "*dashboard*" -n

# Formatter with HTML tags / template literals containing data
rg "{{VIZ_FORMATTER_PATTERN}}" --type {{FE_FILE_EXT}} -A3 \
  | rg "<[a-zA-Z]\|params\.\|data\["

# HTML sink in visualisation library
rg "{{VIZ_INNER_HTML_SINK}}" --type {{FE_FILE_EXT}} \
  -g "*chart*" -g "*graph*" -g "*d3*" -n
```

### 4 — Auth Token Storage (WSTG-SESS-01, ASVS 3.4.1)
```bash
# localStorage / sessionStorage holding tokens
rg "(localStorage|sessionStorage)\.(setItem|getItem)" --type {{FE_FILE_EXT}} -n \
  | rg -i "token|jwt|auth|bearer|refresh|access"

# Token fields in state management (serialised to DevTools)
rg "(token|jwt|accessToken|refreshToken|idToken)" \
  --type {{FE_FILE_EXT}} -g "*reducer*" -g "*store*" -g "*state*" -n -i

# Token in URL query params (in server logs / referrer headers)
rg "(token|apiKey|jwt).*queryParam" --type {{FE_FILE_EXT}} -i -n
```

### 5 — HTTP Interceptor Token Leakage (WSTG-ATHZ-02, ASVS 3.5.2)
```bash
# Interceptors adding auth header without origin filtering
rg "{{AUTH_HEADER_PATTERN}}" \
  --type {{FE_FILE_EXT}} -g "*interceptor*" -g "*middleware*" -n \
  | rg -v "({{ALLOWED_ORIGINS_CONFIG}}|allowList|startsWith|includes)"

# Protocol-relative URLs (XSRF leakage pattern)
rg '"//[a-zA-Z]' --type {{FE_FILE_EXT}} -g "*service*" -g "*http*" -n
```

### 6 — State Management DevTools Exposure (WSTG-CONF-05, ASVS 3.1.1)
```bash
# DevTools not gated on production guard
rg "{{DEVTOOLS_MODULE}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg -L "{{DEVTOOLS_PROD_GUARD}}"

# Sensitive fields in state shape
rg "(password|secret|token|jwt|ssn|creditCard|accessToken|refreshToken)" \
  --type {{FE_FILE_EXT}} -g "*reducer*" -g "*state*" -g "*store*" -i -n

# Missing state/action sanitizer (DevTools sees raw sensitive state)
rg "{{DEVTOOLS_MODULE}}" --type {{FE_FILE_EXT}} -A10 \
  | rg -v "{{DEVTOOLS_SANITIZER}}"
```

### 7 — Route Guards & Open Redirect (WSTG-ATHZ-02, WSTG-CLNT-04, ASVS 4.1.3)
```bash
# Guards returning hard-coded true
rg "canActivate|canMatch|requireAuth" --type {{FE_FILE_EXT}} -A10 \
  | rg "return\s*(true|of\s*\(\s*true\s*\))"

# Navigation with user-supplied {{RETURN_URL_PARAM}}
rg "{{NAVIGATE_FN_PATTERN}}" --type {{FE_FILE_EXT}} -n -B3 \
  | rg "{{RETURN_URL_PARAM}}\|redirect\|next\|queryParam"

# Lazy routes without guards
rg "loadChildren\|loadComponent\|lazy\(" --type {{FE_FILE_EXT}} -n -A2 \
  | rg -v "canActivate\|canMatch\|guard\|requireAuth"
```

### 8 — Client-Side Permission Bypass (WSTG-ATHZ-02, ASVS 4.1.1)
```bash
# Every permission directive — each needs server-side verification
rg "{{PERMISSION_DIRECTIVE}}" --glob "*.{{TEMPLATE_EXT}}" -n

# Permissions loaded from tamper-able storage
rg "(localStorage|sessionStorage).*(permission|role\|can)" --type {{FE_FILE_EXT}} -i -n

# Permission guard used without accompanying auth guard
rg "{{PERMISSION_SERVICE}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg -L "authGuard\|AuthGuard\|requireAuth\|isAuthenticated" 2>/dev/null
```

### 9 — Third-Party Widget Injection (WSTG-CLNT-01, ASVS 5.2.1)
```bash
# Widget data bound from component state / route params
rg "{{WIDGET_DATA_PATTERN}}" --glob "*.{{TEMPLATE_EXT}}" -n

# Widget value set from route params or user input without validation
rg "{{WIDGET_DATA_PATTERN}}" --type {{FE_FILE_EXT}} -n -B5 \
  | rg "queryParam\|pathParam\|route\.\|user\|input"
```

### 10 — Compression Library Risks (ASVS 13.3.1)
```bash
# Decompress calls — check if source is user/server supplied
rg "{{COMPRESS_FN_PATTERN}}" --type {{FE_FILE_EXT}} -n

# Decompressed output passed directly to JSON.parse without size check
rg "{{COMPRESS_FN_PATTERN}}" --type {{FE_FILE_EXT}} -A5 \
  | rg "JSON\.parse\|parse\s*\("

# Decompression of HTTP response data (largest blast radius)
rg "{{COMPRESS_LIB}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg "http\|{{HTTP_CLIENT}}\|response\|body" 2>/dev/null
```

### 11 — CSP & Security Headers (WSTG-CONF-12, ASVS 14.4.*)
```bash
# unsafe-inline / unsafe-eval in any CSP config
rg "unsafe-inline\|unsafe-eval" \
  --glob "*.conf" --glob "*.{{FE_FILE_EXT}}" --glob "*.json" -n

# Security headers present in server/nginx config
rg "Content-Security-Policy\|X-Frame-Options\|HSTS\|X-Content-Type" \
  --glob "*.conf" -n

# Source maps enabled in production build config
rg "\"sourceMap\"\s*:\s*true" --glob "*.json" -n
```

### 12 — Secrets & Sensitive Config in Bundle (WSTG-CONF-05, ASVS 14.2.2)
```bash
# API keys / secrets in environment files (compiled into bundle)
rg "(apiKey|secretKey|clientSecret|privateKey|password)" \
  --glob "environment*.{{FE_FILE_EXT}}" --glob ".env*" -n -i

# Internal IP / hostname in config (topology exposure)
rg "(apiUrl|baseUrl|backendUrl)\s*=\s*\"http://" \
  --glob "environment*.{{FE_FILE_EXT}}" -n

# Source maps in production output
{{SOURCEMAP_CHECK}} 2>/dev/null && echo "FAIL: source maps in production bundle"
```

---

## Output Format

For each finding:

```
## [SEVERITY] Finding: <title>
WSTG: <test-id>     ASVS: <requirement>     CVE: <if applicable>

**File**: `{{SRC_ROOT}}/path/to/file.{{FE_FILE_EXT}}` line <N>
**Vulnerable code**:
  <snippet>
**Attack scenario**: <concrete, one paragraph>
**Fix**: <concrete code snippet>
**Test**: `<test path>` — `{{TEST_DESCRIBE_FN}} > {{TEST_IT_FN}}`
```

Severity: `Critical` (XSS with token theft) → `High` (data injection / auth bypass) →
`Medium` (config / info leak) → `Low` (hardening gap).

---

## Test Templates — Quick Reference

Full scaffolding with `{{TEST_FIXTURE}}`, HTTP mocks, and helpers is in the runbook.

| Check | Test approach |
|---|---|
| XSS via `{{BINDING_SYNTAX}}` | Bind XSS payload → assert `{{SANITIZE_LIB}}` called or no `onerror` in DOM |
| `{{SANITIZE_BYPASS_FN}}` audit | Assert call never flows from HTTP response |
| `{{MARKDOWN_LIB}}` XSS | `{{MARKDOWN_PARSE_FN}}('<img src=x onerror=...>')` → assert output safe before binding |
| `{{VIZ_LIB}}` formatter | Formatter called with `<script>` payload → assert `{{VIZ_ENCODE_FN}}` applied |
| Token in localStorage | Spy on `localStorage.setItem` → assert never called with token key |
| Interceptor domain filtering | Request to third-party URL → assert no `Authorization` header |
| Open redirect | Navigate with `{{RETURN_URL_PARAM}}=https://evil.com` → assert redirect to `/` not external |
| `{{PERMISSION_LIB}}` bypass | API call without UI permission check → assert backend returns 403 |
| `{{DEVTOOLS_MODULE}}` production | `production=true` → assert DevTools not in providers |
| `{{COMPRESS_LIB}}` bomb | Feed oversized compressed input → assert size limit throws before parse |
| CSP header | Check response header — assert no `unsafe-inline` |
| Source map in prod | `{{PROD_BUILD_CMD}}` → assert `.map` files absent in `dist/` |
