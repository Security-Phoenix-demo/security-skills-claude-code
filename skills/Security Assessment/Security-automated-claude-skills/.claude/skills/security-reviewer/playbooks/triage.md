# Triage Playbook

When a finding fires, this is the decision tree. Use it both for live reviews and for findings the hooks emit.

## Severity rubric

| Severity | Definition | Examples |
|---|---|---|
| **CRITICAL** | Pre-auth attacker can take over an account, read other tenants' data, or run code on the server | SQLi via login, RCE via deserialisation, IDOR exposing PII, auth bypass |
| **HIGH** | Authenticated attacker can escalate or read data outside their scope, or pre-auth attacker can leak material data | Stored XSS in a shared resource, SSRF reaching internal services, missing CSRF on a state-changing endpoint, secret in client bundle |
| **MEDIUM** | Defence-in-depth gap that compounds with another bug, or hygiene that fails an audit | MD5 for password hashing, missing CSP, stack-trace leakage, broad `except` swallowing security errors |
| **LOW** | Best-practice deviation with no plausible immediate exploit | Missing `nosniff`, low-quality entropy in non-secret IDs, deprecated TLS suite still configured alongside modern ones |

If you can't tell whether something is HIGH or MEDIUM, write it down as HIGH and let the team negotiate down. Underclassifying is worse than overclassifying.

## What to do at each severity

**CRITICAL** — block the merge, page the on-call AppSec engineer if the change is already in main, file a security ticket immediately. Do not write a public commit message that names the bug class until a fix is shipped.

**HIGH** — block the merge, file a ticket, fix in this sprint. PR can land only with the fix in the same change or with a documented compensating control.

**MEDIUM** — request changes on the PR, file a follow-up ticket if the fix is too large for this PR, due in the current quarter.

**LOW** — comment on the PR, add to the hygiene backlog, no merge block.

## Fix templates

When you propose a fix, lead with the smallest change that closes the bug. Defence-in-depth recommendations come second, labelled as such.

### SQL injection

```diff
- cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
+ cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

If a column or table name needs to be variable, use an allow-list — never interpolate identifiers from input.

### XSS via innerHTML

```diff
- el.innerHTML = userComment;
+ el.textContent = userComment;
```

If the content really must be HTML, route through DOMPurify with a strict policy.

### SSRF on outbound fetch

```diff
- const r = await fetch(req.body.url);
+ const url = new URL(req.body.url);
+ if (!ALLOWED_HOSTS.has(url.host)) throw new ForbiddenError();
+ const ips = await dns.lookup(url.hostname, { all: true });
+ if (ips.some(isPrivateOrLinkLocal)) throw new ForbiddenError();
+ const r = await fetch(url, { redirect: 'manual' });
```

### Hardcoded secret

```diff
- const apiKey = "sk_live_abc123...";
+ const apiKey = process.env.API_KEY;
+ if (!apiKey) throw new Error('API_KEY not set');
```

Then rotate the leaked secret. Always. Even if "the repo is private". A hardcoded secret found in review must be assumed compromised.

### Missing auth on a route

```diff
- router.get('/orders/:id', getOrder)
+ router.get('/orders/:id', requireAuth, requireOwnership('order'), getOrder)
```

## Ticket fields

When this report files a ticket, include:

- **Title** — `[SEVERITY] <category>: <one-line summary>`
- **Affected component** — file path or service name
- **Reproducer** — minimal request that demonstrates the issue, or the static-analysis pattern that fired
- **Impact** — concrete worst case (account takeover, data exfil, RCE) — be specific
- **Fix recommendation** — diff or description
- **References** — CWE, OWASP A0X, ASVS V-X.Y.Z, related CVEs if any

## Hand-off

If the project ships with `phoenix-final-gate` or a Jira / Linear / Asana CLI, route the ticket through that. Otherwise, leave the formatted block in the PR description so a human can file it manually — never assume the finding will be remembered between sessions.
