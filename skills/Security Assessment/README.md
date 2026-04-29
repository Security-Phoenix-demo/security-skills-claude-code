# Security Assessment Skills Suite

A bundle of four complementary security skills plus parameterized testing runbooks.
Each skill solves a different problem at a different price point — pick the one that
matches what you're doing right now.

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
| [`Security-reviewr/`](./Security-reviewr/security-reviewer.md) | Lightweight reviewer agent — 8-point security check + diagnostic ripgrep patterns | Low | New endpoint, auth/RBAC change, frontend render change |
| [`security-assessment/`](./security-assessment/SKILL.md) | Full OWASP Top 10 (2025) + ASVS Level 1 sweep | High (~$8–$10 per run) | Pre-release, compliance, post-incident |
| [`threat-modeling/`](./threat-modeling/SKILL.md) | Automated STRIDE/DREAD threat model with attack trees and mitigation mapping | Medium | Architecture review, new feature design, compliance docs |
| [`Security-Analysis-Agent/`](./Security-Analysis-Agent/) | Parameterized backend/frontend tester + runbook templates (technology-agnostic, hydrate placeholders before use) | n/a (templates) | Drop-in scaffolding for stack-specific testing |
| [`install/`](./install/) | Slash commands, hooks, Windsurf rules/workflows, Codex `AGENTS.md` snippet | n/a | Wire the skills into your tool of choice |

> **No redundancy.** The four skills cover non-overlapping scopes (diff vs review vs sweep vs design). Don't merge them.

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

| Command | Skill | Cost | When |
|---|---|---|---|
| `/security-0day [base-ref]` | `0day-scanner` | low | Manual diff scan (default base = `main`) |
| `/security-review [scope]` | `Security-reviewr/security-reviewer` | low–med | Endpoint/auth/render change |
| `/security-assessment [scope]` | `security-assessment` | high | Pre-release full sweep |
| `/threatmodel [scope]` | `threat-modeling` | medium | Architecture / new feature |

Sources live in [`install/commands/`](./install/commands/).

---

## Install

> **All paths below assume this folder lives at `skills/Security Assessment/` in your project.**
> If you cloned the marketplace plugin elsewhere, adjust paths accordingly.

### Claude Code

**1. Slash commands** — copy or symlink the four command files into `.claude/commands/`:

```bash
# From your project root:
mkdir -p .claude/commands
cp "skills/Security Assessment/install/commands/"*.md .claude/commands/
```

Or symlink (so updates flow through automatically):

```bash
ln -s "../../skills/Security Assessment/install/commands/security-0day.md"        .claude/commands/security-0day.md
ln -s "../../skills/Security Assessment/install/commands/security-review.md"      .claude/commands/security-review.md
ln -s "../../skills/Security Assessment/install/commands/security-assessment.md"  .claude/commands/security-assessment.md
ln -s "../../skills/Security Assessment/install/commands/threatmodel.md"          .claude/commands/threatmodel.md
```

**2. SessionEnd hook (optional, recommended)** — reminds you to run `/security-0day` if your branch has unscanned changes vs `main`. Zero LLM cost, plain bash.

Merge the `hooks` block from [`install/hooks/settings.example.json`](./install/hooks/settings.example.json)
into your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/skills/Security Assessment/install/hooks/session-end-security-0day.sh\""
          }
        ]
      }
    ]
  }
}
```

The script bails silently if you're not on a feature branch or there's no diff. Disable any time with `SECURITY_0DAY_HOOK_DISABLED=1` in your environment, or by removing the entry.

**3. Verify**

```bash
ls .claude/commands/                 # should list 4 *.md files
bash "skills/Security Assessment/install/hooks/session-end-security-0day.sh"  # smoke test
```

In Claude Code, type `/` and confirm the four commands appear.

### Windsurf

Windsurf has no session-end hook. The closest equivalent is a **rule** (model-decision triggered) plus **workflows** for the heavier skills.

```bash
# From your project root:
mkdir -p .windsurf/rules .windsurf/workflows
cp "skills/Security Assessment/install/windsurf/rules/security-review.md"          .windsurf/rules/
cp "skills/Security Assessment/install/windsurf/workflows/security-assessment.md"  .windsurf/workflows/
cp "skills/Security Assessment/install/windsurf/workflows/threatmodel.md"          .windsurf/workflows/
```

The rule fires when you finish a feature, change endpoint/auth/render/deps, or say "ship/commit/PR/done". The two workflows are invoked manually.

### Codex CLI

Codex has no hook system. Append the snippet from
[`install/codex/AGENTS.md.snippet`](./install/codex/AGENTS.md.snippet) to your
project's `AGENTS.md`:

```bash
cat "skills/Security Assessment/install/codex/AGENTS.md.snippet" >> AGENTS.md
```

Codex will then run the appropriate review before declaring a feature done.

### Manual fallback (any tool)

You can always invoke the skills directly by pasting the path of the relevant `SKILL.md`
into your assistant: `Read skills/Security Assessment/0day-scanner/SKILL.md and run it on
the current diff vs main`.

---

## Adapting the skills

### Tailoring `security-assessment` to your stack

The skill auto-detects stack via `Stack detection results`, but you can constrain it:

- **Scope** — pass `backend`, `frontend`, or specific OWASP categories (`A01,A03`) as the slash command arg.
- **Custom rules** — add a `rules/` folder next to `Security-reviewr/security-reviewer.md` with `.mdc` files (the reviewer file documents the convention as optional extension points).
- **Custom checklists** — drop `checklists/owasp-checklist.md` or `checklists/asvs-l1-checklist.md` next to the skill to override the defaults.

### Adapting the parameterized testers

`Security-Analysis-Agent/security-tester-{backend,frontend}-generic.md` are technology-agnostic templates. They contain `{{PLACEHOLDERS}}` (`{{STACK_NAME}}`, `{{BACKEND_FRAMEWORK}}`, `{{ROUTE_ANNOTATION}}`, etc.).

Two options to hydrate:

1. **Manual** — copy the `.md` to your repo, find/replace each `{{TOKEN}}` per the ADAPTATION MANIFEST table in the file.
2. **Scripted** — use the bash hydration script in the companion runbook
   (`security-testing-runbook-{backend,frontend}-generic.md §16`).

Once hydrated, treat the resulting file as a stack-specific Claude Code skill: drop it under `.claude/skills/` or invoke directly.

### Adapting `threat-modeling`

The skill expects optional inputs:

- **Knowledge graph** — if your repo is indexed, set the relevant env / config so the skill can extract architecture automatically. Otherwise it falls back to code analysis.
- **Business context** — paste industry / compliance constraints when invoking `/threatmodel` to enrich DREAD scoring.
- **Architecture diagrams** — supply image paths; the skill uses vision to extract components.

### Adapting `Security-reviewr`

The 8-point check and ripgrep patterns in `security-reviewer.md` are language-light but optimized for Python/JS/Kotlin patterns. To extend:

- Add language-specific patterns to the **Diagnostic Patterns** block (e.g., Go SSRF: `http\.Get|http\.NewRequest`).
- Add a project-specific `rules/sec-*.mdc` file (referenced as optional extension points in the skill).

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

**`security-reviewer.md` references `rules/` and `checklists/` paths that don't exist.**
That's by design — those are optional extension points. The skill works without them. See the **Adapting the skills** section above.

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
