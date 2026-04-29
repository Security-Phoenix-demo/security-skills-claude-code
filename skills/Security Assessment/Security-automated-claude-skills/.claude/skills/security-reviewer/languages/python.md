# Python — Security Review Reference

## Manifest files

`pyproject.toml`, `requirements.txt`, `requirements-*.txt`, `Pipfile`, `Pipfile.lock`, `poetry.lock`, `uv.lock`, `setup.py`, `setup.cfg`, `constraints.txt`. Lockfile must exist for the chosen tool — its absence is a finding.

## Auth & route guards

| Framework | Decorator / pattern | What to check |
|---|---|---|
| FastAPI | `@router.get/post/...`, `Depends(...)` | every route has a `Depends` resolving to an auth dependency; no route uses `Depends(lambda: None)` |
| Flask | `@app.route`, `@blueprint.route`, `@login_required` | every state-changing route has CSRF + auth; `before_request` doesn't whitelist by path alone |
| Django | `urls.py`, `@login_required`, `LoginRequiredMixin`, `permission_required` | DRF `permission_classes`; no `AllowAny` on write endpoints; admin paths gated |
| Starlette | `Mount`, `Route` | middleware order — auth must precede route-level access |

Watch for: routes that build their own auth out of headers (`request.headers.get("X-User-Id")`), JWT verification with `verify=False`, and any `@router.get("/internal/...")` that lacks an auth dependency on the assumption the path is "internal".

## Output / templating

- Jinja2 with `autoescape=False` or rendering raw HTML inside `Markup(...)` — XSS surface
- `markdown.markdown(user_input)` without `safe_mode` / bleach sanitisation
- Django templates with `|safe` on user-influenced strings
- Logging user input with f-strings that hit a log aggregator — log injection / forging
- Returning a `HTMLResponse` built by string concatenation

## Outbound HTTP / SSRF

- `requests.get`, `requests.post`, `httpx.get`, `aiohttp.ClientSession.get`, `urllib.request.urlopen`, `urllib3.PoolManager.request`
- Validate target URL: scheme allowlist (`https` only by default), host allowlist or DNS-resolution check, no `127.0.0.0/8`, `169.254.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `::1`, `fc00::/7`
- `allow_redirects=True` (the default) without bounding the redirect chain or re-validating each hop
- Cloud metadata: `169.254.169.254` (AWS/Azure/GCP), `metadata.google.internal`, `fd00:ec2::254`

## SQL & ORM

- `cursor.execute(f"SELECT ... WHERE id = {x}")` — string-formatted SQL is the canonical bug
- `cursor.execute("... %s ..." % x)` — same
- `Model.objects.raw(...)` with f-string interpolation
- `text("SELECT ... " + x)` in SQLAlchemy
- ORM `extra(where=[...])` with user-controlled strings

## Deserialisation & RCE primitives

- `pickle.load`, `pickle.loads`, `dill.loads`, `shelve.open`, `marshal.loads` on any non-trusted byte stream — RCE
- `yaml.load` without `Loader=yaml.SafeLoader` — RCE
- `eval`, `exec`, `compile` with user input — RCE
- `subprocess.*` with `shell=True` and user input in the command string — command injection
- `os.system`, `os.popen` with user input
- `xml.etree`, `lxml.etree` without `defusedxml` — XXE / billion laughs
- `jinja2.Environment(...).from_string(user_input)` — SSTI

## Secrets

- Hardcoded keys: rg `(?i)(api[_-]?key|secret|token|password)\s*=\s*["'][^"']{12,}` 
- Keys in `os.environ.get("X", "fallback-actual-secret")` — fallback is the leak
- Secrets logged: `logger.info(f"... token={token}")`
- `.env` files committed (check `.gitignore`)

## Dangerous stdlib / API patterns

- `tempfile.mktemp` (race condition) — should be `mkstemp` / `NamedTemporaryFile`
- `random` for tokens — must be `secrets.token_urlsafe` / `secrets.token_bytes`
- `hashlib.md5` / `sha1` for password hashing — must be `bcrypt` / `argon2` / `scrypt`
- `ssl._create_unverified_context()`, `verify=False` on `requests`
- `Path("/").resolve() / user_input` without containment check — path traversal

## Diagnostic ripgrep patterns

```bash
# Auth surface
rg -n '@(app|router|blueprint)\.(get|post|put|patch|delete)' -g '*.py'
rg -n 'verify=False|verify\s*:\s*False' -g '*.py'
rg -n 'Depends\(\s*lambda' -g '*.py'

# Output / SSTI / XSS
rg -n 'autoescape\s*=\s*False|Markup\(|\|safe\b' -g '*.py' -g '*.html' -g '*.jinja*'
rg -n 'from_string\(.*request\.|\.render_template_string\(' -g '*.py'

# SSRF
rg -n '(requests|httpx|aiohttp|urllib).*\.(get|post|request|urlopen)\(' -g '*.py'
rg -n '169\.254\.169\.254|metadata\.google\.internal' -g '*.py'

# SQL
rg -n 'cursor\.execute\([fF]?["' -g '*.py'
rg -n '\.raw\(\s*[fF]?["' -g '*.py'
rg -n 'text\(\s*["\x27].*\+' -g '*.py'

# Deserialisation / RCE
rg -n 'pickle\.loads?|yaml\.load\(|marshal\.loads' -g '*.py'
rg -n 'shell\s*=\s*True' -g '*.py'
rg -n '\b(eval|exec)\(' -g '*.py'

# Secrets
rg -ni '(api[_-]?key|secret|token|password)\s*=\s*["\x27][^"\x27]{12,}' -g '*.py'

# Crypto
rg -n 'hashlib\.(md5|sha1)\(|random\.(random|choice|randint).*token' -g '*.py'
```

## Dependency audit

Prefer `osv-scanner -r .`. Fall back to `pip-audit` (PyPA) or `safety check` (Snyk-backed). Pin via lockfile, never `>=` for runtime deps. Watch for forks of common packages on the same registry — typosquats are the #1 supply-chain vector here (e.g., `python-dateutil` → `python-dateutil2`).
