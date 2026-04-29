# C# / .NET — Security Review Reference

Covers ASP.NET Core, MVC, Web API, Blazor, plain console apps that handle network input.

## Manifest files

`*.csproj`, `*.sln`, `Directory.Packages.props`, `packages.lock.json`, `nuget.config`. Lockfile (`packages.lock.json`) needs `<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>` in csproj. Custom `nuget.config` `<packageSources>` entries beyond `nuget.org` need justification.

## Auth & route guards

| Framework | Pattern | What to check |
|---|---|---|
| ASP.NET Core | `[Authorize]`, `[Authorize(Roles=...)]`, `[Authorize(Policy=...)]` | every controller/action either decorated or covered by `MapControllers().RequireAuthorization()` |
| Minimal APIs | `app.MapGet(...).RequireAuthorization()` | every endpoint chained with `RequireAuthorization` or covered by global filter |
| Razor Pages | `[Authorize]` on PageModel or `AuthorizeFolder` in `Program.cs` | every page covered |
| Blazor Server | `<AuthorizeView>`, `[Authorize]` on routable components | every protected page; SignalR hub auth |
| SignalR | `[Authorize]` on `Hub` class | hub-level auth + per-method auth where roles differ |

Watch for: `[AllowAnonymous]` on individual endpoints inside an authorised controller, JWT bearer config with `ValidateIssuer = false` / `ValidateAudience = false` / `ValidateLifetime = false`, and `app.UseAuthentication()` missing or placed *after* `app.UseAuthorization()` (middleware order matters).

## Output / templating

- Razor `@Html.Raw(userInput)` — XSS
- `@((MarkupString)userInput)` in Blazor — XSS
- `Response.WriteAsync(html)` built by string concat — XSS
- Markdown via `Markdig` rendered without an HTML sanitiser (`HtmlSanitizer` package)

## Outbound HTTP / SSRF

- `HttpClient.GetAsync`, `HttpClient.SendAsync`, `WebRequest.Create`, `RestSharp`, `Flurl`
- Validate target with `Uri.TryCreate(input, UriKind.Absolute, out var uri)`, then `Dns.GetHostAddresses(uri.Host)` and reject private/link-local
- `HttpClientHandler { AllowAutoRedirect = true }` (default) — set explicit policy and re-validate hops
- `HttpClientHandler { ServerCertificateCustomValidationCallback = (_, _, _, _) => true }` — disables TLS verification

## SQL & ORM

- `command.CommandText = "SELECT ... " + x` — injection
- `string.Format("SELECT ... {0}", x)` for SQL — injection
- Dapper `connection.Query("SELECT ... " + x)` instead of `connection.Query("...", new { p = x })`
- EF Core `FromSqlRaw($"... {x}")` — interpolation builds parameters when used with `$""` *and* the EF interpolated overload, but `FromSqlRaw(string.Format(...))` does not — flag the latter
- LINQ `Where(x => x.Name == userName)` is safe; building expression trees from strings is not

## XML / XXE

- `XmlDocument` / `XmlReader` / `XmlTextReader` without `XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null }`
- `XPathDocument` and `XslCompiledTransform` — same hardening required
- Modern .NET (`>=4.5.2`) defaults are safer, but legacy code still surfaces

## Deserialisation / RCE

- `BinaryFormatter.Deserialize` — banned, removed in .NET 8; flag any reference
- `NetDataContractSerializer` — same risk class
- `JavaScriptSerializer` with `SimpleTypeResolver` — gadget chains
- `Newtonsoft.Json` `JsonSerializerSettings { TypeNameHandling = TypeNameHandling.All|Auto|Objects }` — gadget chains; only `None` is safe by default
- `System.Text.Json` is safe by default; custom `JsonConverter` with reflection over user input — review
- `XmlSerializer` is safer but `XmlSerializer(typeof(object), userType)` is a footgun
- `Process.Start("cmd", "/c " + userInput)` — command injection
- `Process.Start(new ProcessStartInfo { FileName = "cmd", Arguments = userInput, UseShellExecute = true })` — same

## Crypto / TLS

- `MD5.Create()`, `SHA1.Create()` for passwords — use `Rfc2898DeriveBytes` (PBKDF2) with high iterations, or BCrypt/Argon2 via Konscious.Security.Cryptography
- `Random` for tokens — use `RandomNumberGenerator.GetBytes`
- `ServicePointManager.ServerCertificateValidationCallback = (s,c,ch,e) => true` — disables TLS verification globally
- `SecurityProtocolType.Ssl3 | Tls | Tls11` — deprecated; require `Tls12 | Tls13`

## ASP.NET-specific

- `[ValidateAntiForgeryToken]` missing on POST/PUT/DELETE actions outside Web API
- `[IgnoreAntiforgeryToken]` audit
- `services.AddCors(o => o.AddDefaultPolicy(b => b.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader().AllowCredentials()))` — illegal but seen
- `UseDeveloperExceptionPage()` left enabled outside `IsDevelopment()` — leaks stack traces

## Diagnostic ripgrep patterns

```bash
# Auth
rg -n '\[Authorize|\[AllowAnonymous|RequireAuthorization\(' -g '*.cs'
rg -n 'ValidateIssuer\s*=\s*false|ValidateAudience\s*=\s*false|ValidateLifetime\s*=\s*false' -g '*.cs'
rg -n 'UseAuthentication\(\)|UseAuthorization\(\)' -g '*.cs'

# Output / XSS
rg -n '@Html\.Raw\(|MarkupString\)|Response\.WriteAsync\(' -g '*.{cs,cshtml,razor}'

# SSRF
rg -n 'HttpClient|WebRequest\.Create|HttpWebRequest|RestClient|Flurl' -g '*.cs'
rg -n 'ServerCertificateCustomValidationCallback' -g '*.cs'
rg -n 'ServicePointManager\.ServerCertificateValidationCallback' -g '*.cs'

# SQL
rg -n 'CommandText\s*=\s*"[^"]*"\s*\+|FromSqlRaw\(\s*string\.Format' -g '*.cs'

# XML / XXE
rg -n 'XmlDocument\(|XmlTextReader\(|XmlReader\.Create\(' -g '*.cs'
rg -n 'DtdProcessing\.Parse' -g '*.cs'

# Deserialisation
rg -n 'BinaryFormatter|NetDataContractSerializer|JavaScriptSerializer' -g '*.cs'
rg -n 'TypeNameHandling\.(All|Auto|Objects)' -g '*.cs'

# RCE
rg -n 'Process\.Start\(' -g '*.cs'
rg -n 'UseShellExecute\s*=\s*true' -g '*.cs'

# Crypto
rg -n 'MD5\.Create\(\)|SHA1\.Create\(\)|new Random\(' -g '*.cs'

# CSRF / CORS
rg -n 'IgnoreAntiforgeryToken|AllowAnyOrigin\(\).*AllowCredentials' -g '*.cs'

# Dev leakage
rg -n 'UseDeveloperExceptionPage\(\)' -g '*.cs'
```

## Dependency audit

`dotnet list package --vulnerable --include-transitive` is the official path. Then `osv-scanner -r .`. `dotnet outdated` (third-party) for upgrade pressure. Pin transitives via `Directory.Packages.props` central management. Watch CVEs against `Microsoft.AspNetCore.*`, `System.Text.Json`, `Newtonsoft.Json`.
