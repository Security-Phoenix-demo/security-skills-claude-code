# JavaScript / TypeScript — Security Review Reference

Covers Node.js (Express, Fastify, Koa, NestJS, Next.js, SvelteKit, Remix, Hono) and browser code (React, Vue, Svelte, Angular, plain DOM).

## Manifest files

`package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `.npmrc`, `.yarnrc.yml`. Lockfile must be committed; `.npmrc` registry overrides must be reviewed (private registry exfil risk).

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| Express | `app.get/post/...`, `router.use(authMiddleware)` | middleware order — `authMiddleware` before route handlers; no per-method bypass |
| Fastify | `fastify.route(...)`, `preHandler` | every route has `preHandler` resolving auth; `config.public: true` is reviewed case-by-case |
| NestJS | `@UseGuards(...)`, `@Public()` | `@Public()` audit — every public endpoint justified; global `AuthGuard` enabled |
| Next.js (app router) | `middleware.ts`, route handlers in `app/api/**/route.ts` | matcher includes all protected paths; `request.cookies.get(...)` not parsed manually |
| Next.js (pages) | `getServerSideProps`, `pages/api/**` | every API route checks session before doing work |
| SvelteKit | `+server.ts`, `hooks.server.ts` | `event.locals.user` set in hooks, checked in handlers |

Watch for: hand-rolled JWT verification (`jwt.verify(token, secret, { algorithms: ['none'] })` or missing `algorithms`), trusting `req.headers['x-user-id']`, route handlers that do auth in `try/catch` and proceed on failure.

## Output / DOM / templating

Browser-side XSS sinks:

- `element.innerHTML = userInput`
- `element.outerHTML = ...`
- `element.insertAdjacentHTML(...)`
- `document.write(...)`
- `eval(...)`, `Function(...)`, `setTimeout(string, ...)`, `setInterval(string, ...)`
- React `dangerouslySetInnerHTML={{ __html: userInput }}`
- Vue `v-html="userInput"`
- Svelte `{@html userInput}`
- Angular `[innerHTML]="userInput"` without `DomSanitizer.sanitize`

Server-side:

- Templating with `triple-stash` ({{{x}}} in Handlebars, `{- x }` in EJS, `=raw= x` in Pug) on user input
- `res.send(html)` built by string concatenation
- Markdown rendered without `dompurify` / `sanitize-html` after parse

## Outbound HTTP / SSRF

- `fetch`, `axios`, `got`, `node-fetch`, `undici.request`, `https.request`, `http.get`, `request` (deprecated)
- Validate scheme + host before fetch; default to `https`
- Block private ranges and cloud metadata (same list as Python ref)
- `redirect: 'follow'` (default) without bound on hops or re-validation

Special note: `node:http`'s default agent does not follow redirects, but `axios`/`got`/`node-fetch` do. Each library needs its own redirect policy.

## SQL & ORM

- Template-string SQL: `` db.query(`SELECT ... WHERE id = ${x}`) ``
- `knex.raw('SELECT ... ' + x)`
- `sequelize.query("SELECT ..." + x)` instead of `replacements`
- Prisma is mostly safe, but `$queryRawUnsafe` and `$executeRawUnsafe` are bypasses
- TypeORM `find({ where: req.query })` — query injection via operator keys

## Deserialisation & RCE primitives

- `eval`, `Function(string)`, `vm.runInNewContext` with user input
- `child_process.exec(cmd)` with user input in `cmd` (use `execFile` with array args)
- `child_process.spawn(cmd, [...args], { shell: true })`
- `serialize-javascript`, `node-serialize` on untrusted input — RCE-prone
- `JSON.parse(userInput)` is fine; reviver functions running user code are not

## Secrets & client storage

- `localStorage.setItem('token', ...)` — XSS-stealable; tokens belong in HttpOnly cookies
- `sessionStorage.setItem('apiKey', ...)` — same
- Tokens / keys in URL query strings — leak via referer + server logs
- Hardcoded keys in client bundles: rg `(?i)(api[_-]?key|secret|token)\s*[:=]\s*["'][A-Za-z0-9_\-]{20,}` against `*.js` `*.ts` `*.tsx` `*.jsx` and built assets
- `.env` files committed; `NEXT_PUBLIC_*` / `VITE_*` / `REACT_APP_*` env vars — these reach the browser, never put secrets in them

## Dangerous patterns

- `crypto.createHash('md5'|'sha1')` for password hashing — use `bcrypt` / `argon2` / `scrypt`
- `Math.random()` for tokens — use `crypto.randomBytes` / `crypto.randomUUID`
- `https.Agent({ rejectUnauthorized: false })` — disables TLS verification
- `cors({ origin: true })` — reflects any Origin
- `cors({ origin: '*', credentials: true })` — illegal combo, but seen in the wild
- `helmet()` not installed in Express apps
- `req.query.url` passed to `fs.readFile` / `fs.createReadStream` without containment — path traversal
- `app.use(express.static('uploads'))` over a user-writable dir — content sniffing / XSS

## Diagnostic ripgrep patterns

```bash
# Auth / route surface
rg -n 'app\.(get|post|put|patch|delete|all)\(|router\.(get|post|put|patch|delete)\(' -g '*.{js,ts,jsx,tsx}'
rg -n 'jwt\.verify\(|jsonwebtoken' -g '*.{js,ts}'
rg -n 'algorithms:\s*\[\s*[\x27"]none' -g '*.{js,ts}'
rg -n '@Public\(\)|skipAuth|isPublic' -g '*.{js,ts}'

# DOM XSS
rg -n 'innerHTML|outerHTML|insertAdjacentHTML|document\.write' -g '*.{js,ts,jsx,tsx,html}'
rg -n 'dangerouslySetInnerHTML' -g '*.{jsx,tsx}'
rg -n 'v-html|\{@html|\[innerHTML\]' -g '*.{vue,svelte,html,ts}'
rg -n '\beval\(|new Function\(' -g '*.{js,ts}'

# SSRF
rg -n 'fetch\(|axios\.|got\(|node-fetch|undici|http\.request|https\.request' -g '*.{js,ts}'
rg -n '169\.254\.169\.254|metadata\.google\.internal' -g '*.{js,ts}'

# SQL
rg -n 'db\.query\(\s*`|\.raw\(\s*[`\x27"].*\$\{|queryRawUnsafe|executeRawUnsafe' -g '*.{js,ts}'

# Secrets / client storage
rg -n 'localStorage\.|sessionStorage\.' -g '*.{js,ts,jsx,tsx}'
rg -ni '(api[_-]?key|secret|token|password)\s*[:=]\s*[\x27"][A-Za-z0-9_\-]{20,}' -g '*.{js,ts,jsx,tsx}'

# CORS / TLS
rg -n 'cors\(\{' -g '*.{js,ts}'
rg -n 'rejectUnauthorized\s*:\s*false' -g '*.{js,ts}'

# RCE
rg -n 'child_process|exec\(|execSync\(|spawn\(' -g '*.{js,ts}'
rg -n 'shell\s*:\s*true' -g '*.{js,ts}'
```

## Dependency audit

Prefer `osv-scanner -r .`. Otherwise `npm audit --audit-level=high`, `pnpm audit`, `yarn npm audit`. Run `npx better-npm-audit` to filter advisories properly. Always check for `postinstall`, `preinstall`, `install` scripts in newly added deps — those run on `npm install` and are the supply-chain sweet spot.
