# Go — Security Review Reference

## Manifest files

`go.mod`, `go.sum`, optionally `vendor/`. `go.sum` must be committed. Replace directives in `go.mod` pointing at non-canonical paths or `../` need justification.

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| `net/http` | `mux.Handle`, `mux.HandleFunc` | every handler wrapped in auth middleware; `http.DefaultServeMux` not used in prod |
| chi / gorilla mux | `r.Use(authMW)`, `r.With(authMW).Get(...)` | every group has `Use`; no `r.Get` outside an authenticated subrouter |
| Echo | `e.Use(...)`, `e.Group(...)` | JWT middleware applied at group level; `Skipper` not too permissive |
| Fiber | `app.Use`, `app.Group` | same; `c.Locals("user")` populated and checked |
| Gin | `r.Use`, `r.Group` | `c.MustGet("user")` reachable in every handler |
| gRPC | `UnaryServerInterceptor`, `StreamServerInterceptor` | auth interceptor registered; per-method skip list reviewed |

Watch for: `r.HandleFunc("/admin/...", h)` outside the authenticated subrouter, JWT verification with `jwt.ParseWithClaims` accepting `nil` keyfunc results, and middleware that returns `next.ServeHTTP(w, r)` after a failed auth check.

## Output / templating

- `html/template` is the safe default; `text/template` rendering HTML is XSS by design
- `template.HTML(userInput)` / `template.JS(userInput)` / `template.URL(userInput)` — these are escape hatches that disable encoding
- `fmt.Fprintf(w, "<div>%s</div>", x)` writing HTML without encoding
- Markdown via `gomarkdown/markdown` rendered to HTML without `bluemonday` policy

## Outbound HTTP / SSRF

- `http.Get`, `http.Post`, `http.Client.Do`, `httputil.NewSingleHostReverseProxy`
- Default `http.Client` follows up to 10 redirects with no host re-validation — write a custom `CheckRedirect`
- Validate URL with `net/url.Parse` then resolve host with `net.LookupIP` and reject private/link-local
- `httputil.ReverseProxy` with user-controlled `Director` — full SSRF
- `net/http/httputil.DumpRequest` in logs — leaks Authorization headers

## SQL & ORM

- `db.Exec(fmt.Sprintf("..."))` — string-formatted SQL
- `db.Query(query + userInput)` — same
- `database/sql` parameterised form is `db.Query("... WHERE id = $1", id)` — flag any `Query`/`Exec` whose first arg contains `%s` / `+` / `fmt.Sprintf`
- GORM `Where(fmt.Sprintf(...))` instead of `Where("col = ?", x)`
- `sqlx.MustExec` with concatenation

## RCE / injection primitives

- `os/exec.Command(name, args...)` — args is a slice, so user input as separate args is safe; user input concatenated into `name` is RCE
- `exec.Command("sh", "-c", userInput)` — RCE
- `template.HTMLEscapeString` not applied where it should be
- `encoding/gob.NewDecoder(...).Decode(&v)` on untrusted bytes — type-confusion / panic-DoS
- `gopkg.in/yaml.v2` `Unmarshal` is safe for data, but `yaml.v3` with custom `UnmarshalYAML` running side effects

## Path / file handling

- `os.Open(filepath.Join(base, userInput))` without `filepath.Clean` + prefix check — path traversal
- `os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0666)` — world-writable; should be `0600` for secrets
- `filepath.IsAbs(userInput)` not checked before joining

## Crypto / TLS

- `crypto/md5`, `crypto/sha1` for password hashing — use `golang.org/x/crypto/bcrypt` or `argon2`
- `math/rand` for tokens — use `crypto/rand`
- `tls.Config{ InsecureSkipVerify: true }` — disables verification
- `tls.Config{ MinVersion: 0 }` (or unset) — allows TLS 1.0/1.1; set `tls.VersionTLS12` minimum

## Goroutine / panic-DoS

- `go func() { ... }()` with no recover, performing work on user input — uncaught panic crashes the process
- Unbounded goroutine spawn per request — request amplification DoS

## Diagnostic ripgrep patterns

```bash
# Auth
rg -n 'http\.HandleFunc|mux\.Handle|router\.(Get|Post|Put|Patch|Delete)' -g '*.go'
rg -n 'InsecureSkipVerify\s*:\s*true' -g '*.go'
rg -n 'jwt\.Parse(WithClaims)?\(' -g '*.go'

# Templates / XSS
rg -n 'text/template|template\.HTML\(|template\.JS\(|template\.URL\(' -g '*.go'
rg -n 'fmt\.Fprintf?\([^,]+,\s*"[^"]*<[^"]*%s' -g '*.go'

# SSRF
rg -n 'http\.(Get|Post|Head|PostForm)\(|client\.Do\(' -g '*.go'
rg -n '169\.254\.169\.254|metadata\.google\.internal' -g '*.go'

# SQL
rg -n '\.(Query|Exec|QueryRow)\(\s*fmt\.Sprintf' -g '*.go'
rg -n '\.(Query|Exec)\(\s*"[^"]*"\s*\+' -g '*.go'

# RCE
rg -n 'exec\.Command\(\s*"sh"\s*,\s*"-c"' -g '*.go'
rg -n 'exec\.CommandContext\(.*"sh"' -g '*.go'

# Crypto
rg -n 'md5\.New|sha1\.New|math/rand' -g '*.go'

# Path
rg -n 'os\.Open\(\s*filepath\.Join\([^)]*,\s*[a-zA-Z]+\.' -g '*.go'

# Panic
rg -n '^\s*go\s+func\(' -g '*.go' | rg -v 'recover'
```

## Dependency audit

Prefer `govulncheck ./...` (official, integrates with `go.sum`). Then `osv-scanner -r .`. `nancy` (Sonatype) is also fine. `go list -m -u all` to surface upgradable modules. Pin transitives where pinning matters via `replace` only as a last resort.
