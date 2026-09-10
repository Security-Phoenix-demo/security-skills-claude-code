# Ruby — Security Review Reference

Covers Rails, Sinatra, Hanami, Rack apps.

## Manifest files

`Gemfile`, `Gemfile.lock`, `*.gemspec`. Lockfile must be committed. `gem "x", git: "..."` and `gem "x", path: "..."` need justification.

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| Rails | `before_action :authenticate_user!`, `Devise`, `Pundit`, `CanCanCan` | every controller has `before_action`; `skip_before_action` audited; `params.require(...).permit(...)` strong-params used |
| Sinatra | `before { halt 401 unless authenticated? }` | top-level `before` block covers all routes; per-route bypass checked |
| Hanami | actions with `include Hanami::Action::Auth` | every protected action |
| Rack | custom middleware | mounted before any app-level handler |

Watch for: `protect_from_forgery with: :null_session` on state-changing controllers, `devise_for :users, controllers: { sessions: 'custom' }` with custom logic that skips lockout, and Rails `params[:user]` flowing into `User.update` without `.permit` (mass-assignment).

## Output / templating

- ERB `<%= raw user_input %>` or `<%= user_input.html_safe %>` — XSS
- Haml `!= user_input` (unescaped) vs `= user_input` (escaped)
- Slim `== user_input` vs `= user_input`
- `render inline: "<%= ... %>"` with user-influenced template — SSTI / RCE
- Markdown via `kramdown` / `redcarpet` rendered without `Loofah` or `sanitize` gem

## Outbound HTTP / SSRF

- `Net::HTTP.get`, `Net::HTTP.post_form`, `Faraday.get`, `HTTParty.get`, `RestClient.get`, `OpenURI.open_uri`
- `OpenURI.open_uri(user_url)` is the simplest SSRF — flag every occurrence
- `Net::HTTP` follows redirects only when you implement it; manual redirect loops without host re-validation are common
- Faraday: `connection.builder.use Faraday::FollowRedirects::Middleware` — bound and validate

## SQL

- `User.where("name = '#{params[:q]}'")` — injection
- `User.find_by_sql("...#{x}...")` — injection
- `Model.where("col = ?", x)` — safe; flag string-interpolated `where` calls
- Raw `ActiveRecord::Base.connection.execute(...)` with interpolation

## Mass assignment / params

- `User.create(params[:user])` instead of `User.create(params.require(:user).permit(:name, :email))`
- `update_attributes(params[:user])` (deprecated in modern Rails but appears in older code)

## RCE / dangerous patterns

- `eval(user_input)`, `instance_eval(user_input)`, `class_eval(user_input)` — RCE
- `send(user_input, ...)` — call any method, including private; use `public_send` and an allowlist
- `system("cmd #{user_input}")`, backticks `` `cmd #{x}` ``, `Kernel.exec`, `IO.popen("cmd #{x}")` — command injection
- `YAML.load(user_input)` (pre-Psych 4) — RCE; use `YAML.safe_load`
- `Marshal.load(user_input)` — RCE
- `ERB.new(user_input).result(binding)` — SSTI / RCE
- `Object.const_get(user_input)` — load arbitrary class

## File / path

- `File.open(params[:path])` without `File.expand_path` + prefix containment — path traversal
- `send_file(params[:path])` — same
- Rails `params[:path]` reaching `File.read` is the canonical traversal in Rails apps

## Crypto

- `Digest::MD5`, `Digest::SHA1` for passwords — use `BCrypt` / `Argon2`
- `SecureRandom` for tokens — correct; flag any use of `rand` for tokens
- `OpenSSL::SSL::VERIFY_NONE` on `Net::HTTP` / `Faraday` / `HTTParty`

## Diagnostic ripgrep patterns

```bash
# Auth / mass assignment
rg -n 'before_action|skip_before_action|protect_from_forgery' -g '*.rb'
rg -n '\.update\(\s*params\[' -g '*.rb'
rg -n '\.create\(\s*params\[' -g '*.rb'

# Output / XSS
rg -n 'raw\(|\.html_safe\b|<%=\s*raw' -g '*.{rb,erb,haml,slim}'
rg -n 'render\s+inline:' -g '*.rb'

# SSRF
rg -n 'Net::HTTP|OpenURI\.open_uri|HTTParty|Faraday|RestClient' -g '*.rb'

# SQL
rg -n '\.where\(\s*"[^"]*#\{' -g '*.rb'
rg -n 'find_by_sql\(' -g '*.rb'
rg -n 'execute\(\s*"[^"]*#\{' -g '*.rb'

# RCE
rg -n '\beval\(|instance_eval\(|class_eval\(' -g '*.rb'
rg -n '\.send\(\s*params\[' -g '*.rb'
rg -n 'system\(\s*"[^"]*#\{|`[^`]*#\{' -g '*.rb'
rg -n 'YAML\.load\(|Marshal\.load\(' -g '*.rb'
rg -n 'ERB\.new\(' -g '*.rb'

# Path
rg -n 'File\.(open|read|new)\(\s*params\[|send_file\(\s*params\[' -g '*.rb'

# Crypto
rg -n 'Digest::(MD5|SHA1)' -g '*.rb'
rg -n 'VERIFY_NONE' -g '*.rb'
```

## Dependency audit

Run `bundle audit check --update` (`bundler-audit` against ruby-advisory-db). Then `osv-scanner -r .`. For Rails, watch the GHSA feed for Rails / Rack / Nokogiri / Devise — those four cover most RCE-grade Rails CVEs.
