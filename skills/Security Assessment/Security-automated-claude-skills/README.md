# Claude Code Security Reviewer Bundle

A drop-in `.claude/` directory that gives Claude Code a security-reviewer skill,
a matching subagent, and three hooks that feed live security context back to
whatever agent is running. Multi-language: Python, JS/TS, Go, Java/Kotlin,
Rust, Ruby, C#/.NET, PHP.

## What's in the box

```
.claude/
├── settings.json                          # hook wiring
├── agents/
│   └── security-reviewer.md               # subagent — invocation surface
├── skills/security-reviewer/
│   ├── SKILL.md                           # router + 8-point check
│   ├── languages/                         # per-language reference packs
│   │   ├── python.md, javascript-typescript.md,
│   │   ├── go.md, java.md, rust.md,
│   │   ├── ruby.md, dotnet.md
│   ├── checklists/
│   │   ├── owasp-asvs.md                  # OWASP Top 10 ↔ ASVS L1
│   │   └── endpoint-checklist.md          # per-endpoint review template
│   └── playbooks/
│       └── triage.md                      # severity + fix templates
└── hooks/
    ├── lib/common.sh                      # JSON helpers, project detection
    ├── session-start.sh                   # SessionStart: project + dep audit
    ├── pre-bash-package-guard.sh          # PreToolUse Bash: install gate
    └── post-edit-quickscan.sh             # PostToolUse: pattern scan
```

## Install

```bash
# from the root of your project
cp -r .claude /path/to/your/repo/
chmod +x .claude/hooks/*.sh

# optional but recommended — better dep audit at session start
brew install osv-scanner   # or: go install github.com/google/osv-scanner/cmd/osv-scanner@latest
```

That's it. Claude Code picks up `.claude/settings.json`, `.claude/agents/`,
and `.claude/skills/` automatically when it opens a session in that
directory.

## How the pieces talk to each other

```
session opens
  └─ SessionStart hook
      ├─ fingerprints project (ecosystems, lockfiles, .gitignore hygiene)
      ├─ runs dep audit  (osv-scanner, falls back per-ecosystem)
      └─ injects "## SECURITY CONTEXT" block via additionalContext
            ↓
   every agent (main or subagent) reads that block before its first turn
            ↓
agent runs Bash to install a package
  └─ PreToolUse Bash hook
      ├─ parses the command (npm/pip/go get/cargo add/gem/composer/dotnet)
      ├─ checks blocklist  → deny on hit
      ├─ checks typosquat distance ≤2 vs popular packages → ask
      ├─ checks brand-newness <7 days on npm → ask
      └─ otherwise → allow
            ↓
agent edits/writes a source file
  └─ PostToolUse Edit|Write|MultiEdit hook
      ├─ dispatches by extension
      ├─ runs ripgrep over high-confidence patterns
      └─ feeds findings back via additionalContext
            ↓
agent decides: fix inline, or invoke `security-reviewer` subagent for full review
```

The subagent is the deep-review path. It loads `SKILL.md`, picks the right
language reference, runs the 8-point check against the diff, and reports
findings with severity + fix.

## Phase 1 vs Phase 2 (mapping to your ask)

- **Phase 1 — multi-language reviewer launchable by Claude Code**
  → `agents/security-reviewer.md` + `skills/security-reviewer/` (skill, language refs, checklists, triage playbook)

- **Phase 2 — hooks at session start and on package manager**
  → `hooks/session-start.sh` + `hooks/pre-bash-package-guard.sh`
  → bonus: `hooks/post-edit-quickscan.sh` for live feedback on every write

## The 8-point check

Every language pack and the subagent share this spine:

1. **Authn / Authz** — every route has explicit guards; no role bypass
2. **Output encoding** — no raw HTML/markdown sinks; templates auto-escape
3. **SSRF** — outbound HTTP validates URL + redirect policy
4. **Secrets** — none in client storage, none hardcoded, none in logs
5. **Input handling** — parameterised SQL, path containment, redirect allow-list
6. **Config & headers** — CSP, CORS, rate limits, no dev bypass leaking to prod
7. **Supply chain** — pinned + lockfile + audit clean
8. **Failure modes** — fail-closed; no silent `except:` or `catch (_)`

## Customisation hooks

- **Blocklist**: add lines to `.claude/security/blocklist.txt`, format `ecosystem:pkgname` (e.g. `npm:event-stream`). Built-in floor includes the historical bad actors.
- **Cache TTL**: session-start caches for 15 min. Run with the env var `SEC_FRESH=1` to bust.
- **Severity tuning**: edit the `add_finding` calls in `post-edit-quickscan.sh` to up- or down-grade per pattern.

## Troubleshooting

- **No SECURITY CONTEXT block at session start** → `chmod +x .claude/hooks/*.sh` and check `.claude/settings.json` is the one being loaded (project-level beats user-level).
- **Hook output not visible** → hooks emit JSON on stdout and human logs on stderr. Run a hook by hand with a sample input to inspect:
  ```bash
  echo '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.py"}}' \
    | .claude/hooks/post-edit-quickscan.sh
  ```
- **`rg: not found`** → install ripgrep. Claude Code requires it; the hooks rely on it for scan speed.
- **`osv-scanner: not found`** → optional; `session-start.sh` falls back to npm audit / pip-audit / govulncheck / cargo audit / bundle audit per ecosystem.

## Phoenix integration points

For Phoenix Security workflows specifically, this bundle composes with:

- `phoenix-final-gate` — finding hand-off can include the quickscan output as a triage attachment.
- `opengrep-rule-generator` — patterns flagged here that recur often are good candidates for promotion to opengrep rules.
- `confluence-cli-connector` / `prd-generator` — review findings on a feature branch can be appended to the PRD's residual-risk section before publish.
