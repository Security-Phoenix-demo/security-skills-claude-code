# Security Assessment Skills Suite

Most security review still happens at the wrong end of the cycle. The diff is fat, the deadline is closer than you'd like, and the reviewer (you, or someone you've roped in) is staring at three hundred files trying to remember which ones touched auth. By that point, anything beyond "looks fine" is a stretch.
The Security Assessment Skills Suite is a set of four commands that move that work earlier. Not all the way to the left — there's no shifting your way out of judgement — but earlier enough that the review fits the change instead of the calendar. It plugs into Claude Code, Windsurf, and Codex, and on Claude Code it ships three hooks that catch obvious things before the human even sees the diff.

![Security Assessment Suite — four AppSec skills and active hooks for Claude Code](../../images/Security-automation-agents.jpg)
This repo contains: 
A bundle of four complementary security skills plus parameterized testing runbooks.
Each skill solves a different problem at a different price point — pick the one that
matches what you're doing right now.

This suite is the **open-source companion** to **[Phoenix Purple](https://phoenix.security/phoenix-purple-ai-sast-sca-ai-generated-code/)** — Phoenix Security's enhanced AppSec and remediation product. The skills here distill the same thinking (pre-merge AppSec review, OWASP/ASVS coverage, threat-model-driven design) into commands you can run inside Claude Code, Windsurf, or Codex without a backend. If you need graph-powered SAST with real taint paths, multi-step exploit chains, and PR-time + agent-time enforcement, that's [Phoenix Purple](https://phoenix.security/phoenix-purple-ai-sast-sca-ai-generated-code/). For threat-intelligence-driven supply-chain blocking, see **[Phoenix Blue](https://phoenix.security/phoenix-blue-ai-vulnerability-intelligence-cve-scoring/)** — the package guard hook in this suite is a minimal local stand-in for what Blue does at platform scale.

> **TL;DR**
> - End of a coding cycle / before opening a PR → **`/security-0day`** (cheap, fast, diff-only)
> - Endpoint, auth, render, or dependency change → **`/security-review`** (light, 8-point check)
> - Pre-release / quarterly audit → **`/security-assessment`** (heavy, OWASP Top 10 + ASVS L1)
> - New feature design / architecture review → **`/threatmodel`** (STRIDE + DREAD)

---

## What's in this folder

| Path | What it is | Cost | Use when |
|---|---|---|---|
| [`0day-scanner/`](./0day-scanner/SKILL.md) | LLM-powered diff/PR/commit vulnerability scanner | Low (~$0.05–$0.20 per run) | End of cycle, before PR merge |
| [`Security-automated-claude-skills/`](./Security-automated-claude-skills/) | **Canonical reviewer** — multi-language (Python, JS/TS, Go, Java/Kotlin, Rust, Ruby, .NET) skill + subagent + 3 active hooks (SessionStart fingerprint, PreToolUse Bash guard, PostToolUse quickscan). Includes language reference packs, OWASP/ASVS + endpoint checklists, triage playbook. Also serves as the on-disk fallback for `/security-assessment` and `/security-0day` when their MCP tools aren't reachable. | Low | New endpoint, auth/RBAC change, frontend render change — `/security-review` routes here |
| [`security-assessment/`](./security-assessment/SKILL.md) | Full OWASP Top 10 (2025) + ASVS Level 1 sweep | High (~$8–$10 per run) | Pre-release, compliance, post-incident |
| [`threat-modeling/`](./threat-modeling/SKILL.md) | Automated STRIDE/DREAD threat model with attack trees and mitigation mapping | Medium | Architecture review, new feature design, compliance docs |
| [`Security-Analysis-Agent/`](./Security-Analysis-Agent/) | Parameterized backend/frontend tester + runbook templates (technology-agnostic, hydrate placeholders before use) | n/a (templates) | Drop-in scaffolding for stack-specific testing |
| [`install/`](./install/) | Slash commands, hooks (lite + full presets), Windsurf rules/workflows, Codex `AGENTS.md` snippet | n/a | Wire the skills into your tool of choice |

> **No redundancy.** The four skills cover non-overlapping scopes (diff vs review vs sweep vs design). Don't merge them. The bundle's checklists and language packs are the *shared resource* the other skills fall back to when their MCP tools aren't reachable.
>
> **Archived:** the older single-file `Security-reviewr/` reviewer was superseded by the bundle's multi-language version and moved to [`_archive/`](./_archive/). Recover by moving it back if you need it.

---

## When to use which — decision tree

```
Are you reviewing a specific diff/PR/commit?
├── Yes → /security-0day
└── No → Did the change touch endpoints/auth/render/deps/config?
        ├── Yes → /security-review  (8-point check, fast)
        └── No → Are you about to ship / quarterly audit?
                ├── Yes → /security-assessment  (heavy, OWASP + ASVS)
                └── No → Are you designing a new feature or architecture?
                        ├── Yes → /threatmodel
                        └── No → You probably don't need this suite right now.
```

---

## Slash commands

After install, you get four commands:

| Command | Engine | Cost | When |
|---|---|---|---|
| `/security-0day [base-ref]` | `0day-scanner/SKILL.md` (with bundle language packs as fallback) | low | Manual diff scan; default base = `main` |
| `/security-review [scope]` | `Security-automated-claude-skills/.claude/skills/security-reviewer/SKILL.md` | low–med | Endpoint, auth/RBAC, render, dep, or config change |
| `/security-assessment [scope]` | `security-assessment/SKILL.md` (with bundle checklists as fallback) | high | Pre-release full sweep |
| `/threatmodel [scope]` | `threat-modeling/SKILL.md` | medium | Architecture / new feature design |

Sources live in [`install/commands/`](./install/commands/). Each command file is a thin wrapper that loads the matching engine SKILL with scope guards — see the files for the exact instructions sent to the assistant.

---

## Install

> **All paths below assume this folder lives at `skills/Security Assessment/` in your project.**
> If you cloned the marketplace plugin elsewhere, adjust paths accordingly.

### Claude Code — one command

```bash
# From your project root:
bash "skills/Security Assessment/install/install.sh" --full
```

That's it. The installer:

- copies the 4 slash commands into `.claude/commands/`
- merges the chosen hook preset into `.claude/settings.json` (backs up first; uses `jq` if available, otherwise prints a copy-paste fallback)
- copies the security-reviewer subagent into `.claude/agents/` (full preset only)
- chmods all hook scripts so they're executable

**Variants:**

| Command | What you get |
|---|---|
| `install.sh` *(default)* or `install.sh --lite` | Slash commands + SessionEnd 0-day reminder hook only. Zero LLM cost. |
| `install.sh --full` | Everything in lite **+** SessionStart project fingerprint & dep audit **+** PreToolUse Bash package-install guard **+** PostToolUse Edit/Write/MultiEdit pattern quickscan **+** the security-reviewer subagent. |
| `install.sh --dry-run [--lite\|--full]` | Show what would change without writing anything. |
| `install.sh --uninstall` | Remove the 4 commands and the subagent, restore `.claude/settings.json` from the backup the installer made. |

**Verify:**

```bash
ls .claude/commands/                                          # 4 *.md files
# In Claude Code, type / and confirm the four commands appear.
```

**Optional (full preset only):** `brew install osv-scanner` for richer dependency auditing at session start. Without it, the SessionStart hook falls back to ecosystem-native tools (`npm audit`, `pip-audit`, `cargo audit`, `govulncheck`, `bundle audit`).

**Disable the SessionEnd reminder any time:** `export SECURITY_0DAY_HOOK_DISABLED=1`.

### Windsurf — one command

```bash
# From your project root:
mkdir -p .windsurf/rules .windsurf/workflows && \
cp "skills/Security Assessment/install/windsurf/rules/"*.md      .windsurf/rules/ && \
cp "skills/Security Assessment/install/windsurf/workflows/"*.md  .windsurf/workflows/
```

The rule auto-fires on endpoint/auth/render/dep changes; the two workflows (`/security-assessment`, `/threatmodel`) are invoked manually.

### Codex CLI — one command

```bash
# From your project root:
cat "skills/Security Assessment/install/codex/AGENTS.md.snippet" >> AGENTS.md
```

Codex has no hook system, so this is enforced as a behavioral instruction in `AGENTS.md`.

Codex will then run the appropriate review before declaring a feature done.

### Manual fallback (any tool)

You can always invoke the skills directly by pasting the path of the relevant `SKILL.md`
into your assistant: `Read skills/Security Assessment/0day-scanner/SKILL.md and run it on
the current diff vs main`.

---

## Bundle internals — `Security-automated-claude-skills/`

The bundle is the canonical reviewer and the shared resource the other skills fall back to. Layout:

```
Security-automated-claude-skills/
├── .claude/
│   ├── settings.json                                    # ready-to-merge hook wiring (the installer uses install/hooks/settings.full.example.json instead, which targets the suite path)
│   ├── agents/security-reviewer.md                      # subagent — pre-merge AppSec reviewer, dispatched by /security-review or proactively
│   ├── hooks/
│   │   ├── lib/common.sh                                # JSON I/O + project-root detection (uses git rev-parse --show-toplevel)
│   │   ├── session-start.sh                             # SessionStart: project fingerprint + dep audit + SECURITY CONTEXT injection
│   │   ├── pre-bash-package-guard.sh                    # PreToolUse Bash: install gate (blocklist, typosquat, brand-new packages)
│   │   └── post-edit-quickscan.sh                       # PostToolUse Edit/Write/MultiEdit: per-extension pattern scan
│   └── skills/security-reviewer/
│       ├── SKILL.md                                     # router + 8-point check
│       ├── languages/{python,javascript-typescript,go,java,rust,ruby,dotnet}.md   # per-language reference packs
│       ├── checklists/owasp-asvs.md                     # OWASP Top 10 ↔ ASVS L1 controls (used by /security-assessment fallback)
│       ├── checklists/endpoint-checklist.md             # per-endpoint review template
│       └── playbooks/triage.md                          # severity rubric + fix templates
├── README.md                                            # bundle's own docs
└── sec-bundle.tar.gz                                    # original tarball (kept for re-packaging; already extracted)
```

## Hook reference (full preset)

| Hook | Event | Purpose | Cost | Disable |
|---|---|---|---|---|
| `session-start.sh` | `SessionStart` | Detect ecosystems, run a fast dep audit (osv-scanner if present, else npm/pip/cargo/go/bundle audits per ecosystem), inject a `## SECURITY CONTEXT` block via `additionalContext` so every agent reads project posture before its first turn. | Free (no LLM) | Remove the SessionStart entry from `.claude/settings.json`. Bust the 15-min cache with `SEC_FRESH=1`. |
| `pre-bash-package-guard.sh` | `PreToolUse` (matcher: `Bash`) | Parse `npm/yarn/pnpm/pip/uv/poetry/cargo/go get/gem/bundle/composer/dotnet add` invocations. Blocks installs of known-malicious packages, asks on typosquats (edit distance ≤2 vs popular packages) and brand-new packages (npm registry publish < 7 days). | Free | Remove the PreToolUse entry. Tune blocklist via `.claude/security/blocklist.txt` (`ecosystem:pkgname` per line). |
| `post-edit-quickscan.sh` | `PostToolUse` (matcher: `Edit\|Write\|MultiEdit`) | Dispatches by file extension, runs ripgrep over high-confidence patterns (SQL string formatting, `innerHTML`, hardcoded secrets, etc.), feeds findings back via `additionalContext`. Heuristic only — full review remains the subagent's job. | Free | Remove the PostToolUse entry. Tune severities in the `add_finding` calls in the script. |
| `session-end-security-0day.sh` | `SessionEnd` | One-line reminder when branch ≠ default and there's a non-zero diff: prints the `/security-0day` command to copy-paste. Does not invoke an LLM. | Free | `export SECURITY_0DAY_HOOK_DISABLED=1` or remove the SessionEnd entry. |

Lite preset includes only the SessionEnd reminder. Full preset includes all four.

## Subagent — `security-reviewer`

Installed by `install.sh --full` to `.claude/agents/security-reviewer.md`. Pairs with the bundle SKILL.

- **Triggers**: invoked by `/security-review`, the Windsurf rule, or proactively when an agent decides a change warrants AppSec review (frontmatter description steers Claude Code's auto-dispatch heuristics).
- **Inputs it reads**: the `## SECURITY CONTEXT` block (if `session-start.sh` injected one), the user's stated scope, files in the diff (`git diff --name-only HEAD~1` by default), the language reference pack(s) matching the project, and findings already emitted by `post-edit-quickscan.sh` (won't re-discover them).
- **Output**: a deduplicated finding list in the format defined by the bundle SKILL (`[SEVERITY] one-liner / File / Category / Evidence / Fix / Refs`). Plus, when a finding warrants a ticket, a `## TICKETS` block.
- **What it doesn't do**: run destructive commands, write the fix itself (unless asked), roleplay outside AppSec.

## Cross-skill integration — how the four skills share state

```
                    ┌────────────────────────────────────────────┐
                    │  Security-automated-claude-skills (bundle) │
                    │  ─ checklists/owasp-asvs.md                │
                    │  ─ checklists/endpoint-checklist.md        │
                    │  ─ languages/*.md                          │
                    │  ─ playbooks/triage.md                     │
                    └────────────────────────────────────────────┘
                                    ▲       ▲       ▲
            on-disk fallback ───────┘       │       └─── on-disk fallback
                                            │
            /security-assessment ───────────┤              /security-0day
            (when MCP unreachable)          │              (when MCP unreachable;
                                            │               + stack-aware language packs)
                                            │
                                  /security-review (canonical)
```

- `/security-review` always loads the bundle SKILL.
- `/security-assessment` and `/security-0day` first try their MCP tools (`run_security_assessment`, `analyze_for_zero_day_vulnerabilities`); if those aren't reachable, they fall back to the bundle's checklists / language packs and run the workflow with the assistant's built-in tools (Read/Grep/Glob/Bash).
- `/threatmodel` is independent — different methodology (STRIDE/DREAD), different output (attack trees, mitigation matrix). It does not consume bundle resources.

## Adapting the skills

### Tailoring the canonical reviewer (`Security-automated-claude-skills/`)

Add coverage without forking the SKILL.md:

- **Add a language** — drop `languages/<lang>.md` into `.claude/skills/security-reviewer/languages/` following the same structure as the existing packs (diagnostic patterns + framework-specific gotchas + OWASP/ASVS mapping). Add the manifest pattern for it to the `Routing` table in `SKILL.md`.
- **Tighten the package guard** — add lines to `.claude/security/blocklist.txt` in `ecosystem:pkgname` form (e.g., `npm:event-stream`).
- **Adjust quickscan severities** — edit the `add_finding` calls in `hooks/post-edit-quickscan.sh`.
- **Override checklists** — create a project-local `checklists/` next to the SKILL with your own files; the SKILL reads from its own `checklists/` first, but you can vendor your overrides into the project copy after install.

### Tailoring `security-assessment`

- **Scope** — pass `backend`, `frontend`, or specific OWASP categories (`A01,A03`) as the slash command arg.
- **Budget cap** — pass `budget=N.NN` to constrain MCP cost (when MCP is reachable).
- **No MCP?** — the skill auto-falls back to the bundle's checklists. Customize that path by editing the bundle's `checklists/owasp-asvs.md`.

### Tailoring `0day-scanner`

- **Base ref** — pass it as the slash command arg (default `main`).
- **Mode** — light/standard/deep (default light; the slash command auto-promotes to standard for >50 changed files).
- **No MCP?** — falls back to the bundle's `languages/*.md` packs scoped to the diff. Customize by editing those packs.

### Tailoring `threat-modeling`

- **Knowledge graph** — if your repo is indexed, the skill extracts architecture automatically. Otherwise it falls back to code analysis (`git ls-files` + import graph heuristics).
- **Business context** — paste industry / compliance constraints when invoking `/threatmodel` to enrich DREAD scoring.
- **Architecture diagrams** — supply image paths; the skill uses vision to extract components and trust boundaries.

### Adapting the parameterized testers (`Security-Analysis-Agent/`)

`security-tester-{backend,frontend}-generic.md` are technology-agnostic templates with `{{PLACEHOLDERS}}` (`{{STACK_NAME}}`, `{{BACKEND_FRAMEWORK}}`, `{{ROUTE_ANNOTATION}}`, etc.).

To hydrate:

1. **Manual** — copy the `.md` to your repo, find/replace each `{{TOKEN}}` per the ADAPTATION MANIFEST table at the top of the file.
2. **Scripted** — use the bash hydration script in the companion runbook
   (`security-testing-runbook-{backend,frontend}-generic.md §16`).

Once hydrated, treat the resulting file as a stack-specific Claude Code skill: drop it under `.claude/skills/` or invoke directly.

---

## SessionEnd hook behavior (Claude Code)

What it does:

- Detects current branch and the project's default branch (`main`/`master`/`origin/HEAD`).
- Counts files changed (committed + uncommitted) vs the default branch.
- If the count is non-zero and you're not on the default branch, prints a one-line reminder with a copy-pasteable `/security-0day` command.

What it does **not** do:

- It does **not** invoke an LLM. Zero token cost.
- It does **not** modify files.
- It does **not** block session end — purely informational.

Disable: set `SECURITY_0DAY_HOOK_DISABLED=1`, or remove the SessionEnd entry from `.claude/settings.json`.

If you'd rather have the hook run a real LLM scan automatically, replace the script body with a `claude -p '/security-0day main'` headless call. Be aware of cost — every `Stop`/`SessionEnd` event will spend tokens.

---

## Troubleshooting

**Slash commands don't appear in Claude Code.**
Confirm the files are in `.claude/commands/` (not nested deeper) and have the YAML frontmatter intact. Restart Claude Code if needed.

**SessionEnd hook prints nothing.**
Either you're on `main`/`master` (intended), there's no diff, or you're not in a git repo. Run the script directly with `bash` to verify; check `git status` first.

**`Security-reviewr/` is gone — where did it go?**
Archived to [`_archive/Security-reviewr/`](./_archive/) — superseded by the bundle's multi-language reviewer. Move it back if you need the lite single-file version.

**Full-preset hooks don't fire / no SECURITY CONTEXT block at session start.**
Confirm the bundle scripts are executable: `chmod +x "skills/Security Assessment/Security-automated-claude-skills/.claude/hooks/"*.sh` and that your `.claude/settings.json` is project-level (project beats user-level). Run a hook by hand to inspect (see the verify smoke test above).

**The `0day-scanner` and `security-assessment` skills mention an MCP tool (`run_security_assessment`, `analyze_for_zero_day_vulnerabilities`).**
Those skills were authored against a Phoenix Security MCP server. Without the MCP server, the assistant will fall back to running the workflow steps inline using its built-in tools. Findings will still be valid; performance and breadth depend on the assistant.

**Windsurf rule fires too often / not enough.**
Edit `.windsurf/rules/security-review.md` — change `trigger: model_decision` to `trigger: always_on` (always), `manual` (never auto), or narrow the description to your liking.

**Codex doesn't run the review.**
Codex respects `AGENTS.md` instructions but can ignore them under tight context. Make the snippet the first item under a `## Security` heading and keep it concise.

---

## Related

- [`SETUP_COMPLETE.md`](../../SETUP_COMPLETE.md) — repo-level setup overview
- [`MARKETPLACE_INSTALL.md`](../../MARKETPLACE_INSTALL.md) — plugin marketplace install
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) — contributing guidelines
