# Rust — Security Review Reference

Covers Actix, Axum, Rocket, Warp, Tower, plain Hyper/Tokio.

## Manifest files

`Cargo.toml`, `Cargo.lock`. Lockfile must be committed for binaries (libraries: leave it out, but the consuming binary must commit one). `[patch]` and `git`/`path` dependencies need justification — they bypass `Cargo.lock`'s integrity guarantees in subtle ways.

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| Axum | `Router::route(...).layer(auth_middleware)` | every route / nested router has auth in its layer stack |
| Actix-web | `App::wrap(auth_mw)`, `web::scope(...).wrap(...)` | `wrap` order — outermost wraps run first; auth must be applied before logging |
| Rocket | `#[get("/...", rank=N)]` + `FromRequest` guards | every protected route uses a `Guard` impl; `Outcome::Success` on missing token is a bug |
| Tower / Hyper | `ServiceBuilder::layer(...)` | service stack composition; per-route auth not skipped |

Watch for: `extract::Extension<UserId>` with `Option<UserId>` and a default of `UserId(0)` ("system") on missing auth, and JWT crates configured to accept `alg: none` (jsonwebtoken accepts only what you configure, but custom verifiers may not).

## Output / templating

- `askama`, `tera`, `handlebars` — all autoescape by default in HTML mode; the bug is using `text` mode for HTML output
- `format!("<div>{}</div>", user_input)` written to response — XSS
- `Html(html_string)` from `axum::response` built by concatenation
- `comrak`/`pulldown-cmark` rendering markdown without an HTML sanitiser (`ammonia`)

## Outbound HTTP / SSRF

- `reqwest::Client::get`, `reqwest::Client::post`, `hyper::Client::request`, `ureq::get`
- `reqwest::Client::builder().redirect(reqwest::redirect::Policy::limited(N))` — set explicit limit; default is 10
- Custom `redirect::Policy::custom(|attempt| ...)` to re-validate each hop's host
- Validate target with `url::Url::parse` then `tokio::net::lookup_host` and reject private/link-local ranges
- `reqwest::Client::builder().danger_accept_invalid_certs(true)` — disables TLS verification

## SQL

- `sqlx::query(&format!("SELECT ... {}", x))` — string-formatted SQL
- `sqlx::query_as!` is compile-time-checked and parameterised — safe by construction
- `diesel`'s typed query builder is safe; raw SQL via `sql_query` with `format!` is not
- `tokio-postgres` raw `client.query(&format!(...), &[])` — flag any `format!` whose result feeds `query`

## `unsafe` and panics

- `unsafe` blocks added in this change must justify each use; lifetime / aliasing violations in `unsafe` are CVE-grade
- `.unwrap()` / `.expect()` on user-influenced data — panic-driven DoS
- Integer arithmetic on user-influenced data without `checked_*` / `saturating_*` / `overflowing_*` — overflow in release mode wraps silently
- `slice::from_raw_parts` with user-influenced length — UB

## Deserialisation

- `serde_json::from_str` is safe for data; with `#[serde(deserialize_with = "...")]` running side effects, review
- `bincode`, `rmp-serde` (MessagePack) — type-confusion possible across versions
- `serde_yaml` < 0.9 had recursion-depth issues; modern `serde_yaml` is OK
- `bson::from_slice` / `bson::Bson::from_reader` — depth-bound issues historically

## Crypto / randomness

- `rand::thread_rng()` for tokens — fine
- `rand::random::<u32>()` for tokens — fine for non-secret use
- `getrandom` directly is the gold standard for keys
- Any use of `rand::SeedableRng::seed_from_u64(0)` for production crypto is a finding
- `md5`, `sha1` crates for password hashing — use `argon2` / `bcrypt` / `scrypt`
- `rustls` is preferred over `native-tls`; `native-tls` with `danger_accept_invalid_certs` reaches OS trust store

## Command execution

- `std::process::Command::new("sh").args(["-c", &user_input])` — RCE
- `Command::new(&user_input)` — RCE if user controls the binary path
- `tokio::process::Command` — same rules

## Diagnostic ripgrep patterns

```bash
# Auth
rg -n '\.layer\(|\.wrap\(|FromRequest|extract::Extension|axum::middleware' -g '*.rs'
rg -n 'danger_accept_invalid_certs|accept_invalid_hostnames' -g '*.rs'

# Output / XSS
rg -n 'format!\([^)]*<[^)]*\{' -g '*.rs'
rg -n 'Html\(\s*format!|Html\(\s*\w+\s*\+' -g '*.rs'

# SSRF
rg -n 'reqwest::|hyper::Client|ureq::' -g '*.rs'
rg -n '169\.254\.169\.254|metadata\.google\.internal' -g '*.rs'

# SQL
rg -n 'sqlx::query\(\s*&?format!|sql_query\(\s*&?format!' -g '*.rs'

# Unsafe / panic
rg -n 'unsafe\s*\{' -g '*.rs'
rg -n '\.unwrap\(\)|\.expect\(' -g '*.rs'
rg -n 'from_raw_parts' -g '*.rs'

# Deserialisation
rg -n 'serde_yaml::from|bincode::deserialize|rmp_serde::from' -g '*.rs'

# RCE
rg -n 'Command::new\(\s*"sh"|Command::new\(\s*"bash"|\.arg\("-c"\)' -g '*.rs'

# Crypto
rg -n 'use\s+md5|use\s+sha1|seed_from_u64' -g '*.rs'
```

## Dependency audit

Run `cargo audit` (RustSec advisory DB) — it's the canonical answer here. `cargo deny check` for license + advisory + duplicate-version policy. `osv-scanner -r .` works on `Cargo.lock` too. `cargo outdated` to surface upgrade pressure. Pin via `Cargo.lock`; never use `*` in `[dependencies]`.
