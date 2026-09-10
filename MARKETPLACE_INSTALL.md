# Marketplace Installation Guide

Everything in this repository installs as **six Claude Code plugins** from **one
marketplace**. You add the marketplace once, then install the plugins you want.

Built by the engineering and security teams at [Phoenix Security](https://phoenix.security).

---

## Contents

- [The 30-second version](#the-30-second-version)
- [Prerequisites](#prerequisites)
- [What you can install](#what-you-can-install)
- [Step 1 — add the marketplace](#step-1--add-the-marketplace)
- [Step 2 — install the plugins](#step-2--install-the-plugins)
- [Step 3 — verify](#step-3--verify)
- [Team-wide auto-install](#team-wide-auto-install)
- [Per-plugin setup](#per-plugin-setup)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Installing from a local checkout](#installing-from-a-local-checkout)
- [Copying a single skill instead](#copying-a-single-skill-instead)
- [Troubleshooting](#troubleshooting)
- [Quick reference](#quick-reference)

---

## The 30-second version

Paste this into Claude Code:

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
/plugin install phoenix-security-review@phoenix-security
/plugin install phoenix-readiness-reviews@phoenix-security
/plugin install phoenix-sast-rules@phoenix-security
/plugin install phoenix-cti-search@phoenix-security
/plugin install phoenix-prd-pipeline@phoenix-security
/plugin install phoenix-docs-research@phoenix-security
```

Nothing else is required. Only `phoenix-cti-search` needs an API key, and only for its
bundled CLI — its skill works with no key at all.

---

## Prerequisites

| Requirement | Needed for | Notes |
|---|---|---|
| Claude Code | Everything | `claude --version`. Plugins need a reasonably current build |
| Git | Adding a marketplace from GitHub | Already required by Claude Code |
| Node.js 18+ | `phoenix-cti-search` CLI and MCP server only | The `cti-domain-research` skill does not need it |
| A search API key | `phoenix-cti-search` CLI only | [Brave Search](https://api.search.brave.com/app/keys) — 2,000 free requests a month |
| Python 3 + Chrome | The `notebooklm` skill only | Plus the "Claude in Chrome" extension |
| `ripgrep` | Faster repo scanning | Optional. The scanner falls back to `grep` |
| `jq` | Clean hook wiring in `phoenix-security-review` | Optional. The installer falls back to copy-paste instructions |

---

## What you can install

| Plugin | Skills | What it gives you |
|---|---|---|
| `phoenix-security-review` | 6 | AppSec review across the lifecycle: `security-reviewer`, `security-assessment`, `0day-scanner`, `threat-modeling`, `tm-quick-security-assessment`, `tm-security-review`. Plus 4 commands (`/security-review`, `/security-0day`, `/security-audit`, `/threatmodel`), a `security-reviewer` subagent, and 3 opt-in hooks |
| `phoenix-readiness-reviews` | 2 | `plan-readiness-review` (READY / NOT READY on a plan) and `production-readiness-review` (SHIP / NO-SHIP on a codebase), with a deterministic repo scanner |
| `phoenix-sast-rules` | 2 | `opengrep-rule-generator` and `opengrep-rule-generator-research` — SAST rules for 30+ languages |
| `phoenix-cti-search` | 1 | `cti-domain-research` skill (no API key) plus a `/cti-search` command over a Node CLI and MCP server, across 595 curated domains |
| `phoenix-prd-pipeline` | 13 | `prd-generator` plus the 12 Phoenix Pipeline roles, from context curation to a final ship gate |
| `phoenix-docs-research` | 3 | `project-documenter` (6 modes, self-healing), `notebooklm`, `phoenix-research-pipeline` |

A **skill** also gives you a slash command named after it. Plugin skills are namespaced —
`/phoenix-readiness-reviews:plan-readiness-review` always works, and the bare
`/plan-readiness-review` works too unless something else has claimed that name.

---

## Step 1 — add the marketplace

In a Claude Code session:

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
```

Or from your shell:

```bash
claude plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
```

Expected output:

```
✔ Successfully added marketplace: phoenix-security
```

The marketplace is named **`phoenix-security`**. That is the name you use after the `@` in
every install command.

---

## Step 2 — install the plugins

Install all six:

```
/plugin install phoenix-security-review@phoenix-security
/plugin install phoenix-readiness-reviews@phoenix-security
/plugin install phoenix-sast-rules@phoenix-security
/plugin install phoenix-cti-search@phoenix-security
/plugin install phoenix-prd-pipeline@phoenix-security
/plugin install phoenix-docs-research@phoenix-security
```

Or install only what you need. Each plugin is independent — nothing depends on anything else.

Prefer a browser-style UI? Just type `/plugin` and pick from the list.

### Scope

By default a plugin installs at **user** scope, so it is available in every project on this
machine. To scope one to the current project instead:

```bash
claude plugin install phoenix-readiness-reviews@phoenix-security --scope project
```

---

## Step 3 — verify

```bash
# Everything installed, and which marketplace it came from
claude plugin list

# What one plugin actually exposes: skills, agents, hooks, MCP servers, token cost
claude plugin details phoenix-security-review
```

`claude plugin details` is the fastest way to confirm a skill loaded. It prints the component
inventory and the projected token cost — the always-on cost is what each skill's description
adds to every session, and the on-invoke cost is what you pay each time a skill fires.

Then, in a session, type `/` and confirm the commands appear:

```
/security-review    /security-0day    /security-audit    /threatmodel
/plan-readiness-review    /production-readiness-review
/cti-search
```

---

## Team-wide auto-install

Commit this to your repository's `.claude/settings.json`. Every teammate gets the
marketplace and the plugins on their next session, with no manual step:

```json
{
  "extraKnownMarketplaces": {
    "phoenix-security": {
      "source": {
        "source": "github",
        "repo": "Security-Phoenix-demo/security-skills-claude-code"
      }
    }
  },
  "enabledPlugins": {
    "phoenix-security-review@phoenix-security": true,
    "phoenix-readiness-reviews@phoenix-security": true,
    "phoenix-sast-rules@phoenix-security": true
  }
}
```

List only the plugins your team should actually get. Each enabled plugin adds its skills'
descriptions to every session, so a shorter list means a smaller always-on context cost.

---

## Per-plugin setup

Five of the six plugins need no setup at all. These are the exceptions.

### Finding a plugin's directory on disk

Two of the setup steps below need the path where a plugin actually landed. It depends on how
you added the marketplace:

| Marketplace source | Plugin path |
|---|---|
| GitHub repo | `~/.claude/plugins/marketplaces/phoenix-security/plugins/<plugin-name>` |
| Local directory | `<that directory>/plugins/<plugin-name>` |

`claude plugin marketplace list` prints the source, so this always works:

```bash
MP=~/.claude/plugins/marketplaces/phoenix-security     # GitHub route
# MP=/path/to/your/checkout                            # local-directory route
```

### phoenix-cti-search — Node and an API key

The `cti-domain-research` skill works immediately with no setup: it does the same tiered
search using Claude's own web-search tools. The bundled CLI and MCP server are faster and
scriptable, and those need Node plus a search key.

```bash
CTI="$MP/plugins/phoenix-cti-search"
cd "$CTI"
npm install --omit=dev
cp .env.example .env
```

Then edit `.env`:

```bash
# Option A — Brave Search (recommended: 2,000 free requests a month)
SEARCH_PROVIDER=brave
BRAVE_SEARCH_API_KEY=your_key_here

# Option B — SerpAPI (100 free requests a month)
SEARCH_PROVIDER=serpapi
SERPAPI_KEY=your_key_here

# Option C — Google Custom Search
SEARCH_PROVIDER=google
GOOGLE_CSE_KEY=your_key_here
GOOGLE_CSE_ID=your_cse_id_here

# Optional — push results into a NotebookLM notebook
NOTEBOOKLM_NOTEBOOK_ID=your_notebook_id_here
```

Get the keys here:

- Brave Search — [api.search.brave.com/app/keys](https://api.search.brave.com/app/keys)
- SerpAPI — [serpapi.com](https://serpapi.com)

Smoke test, no API call made:

```bash
node "$CTI/index.js" --query "CVE-2024-21762" --dry-run
```

**MCP server.** `mcp-server.js` ships with the plugin but is not wired automatically. To
register it, add it to your MCP config pointing at
`$CTI/mcp-server.js` with `node` as the command.

### phoenix-security-review — the hooks are opt-in

Installing the plugin gives you the six skills, four commands and the subagent right away.
The three **active hooks** are deliberately *not* wired on install, because a `PreToolUse`
gate on every Bash call and a scan on every file write should be your choice, not a side
effect of installing a plugin.

To wire them into a project:

```bash
PLUGIN="$MP/plugins/phoenix-security-review"
cd /path/to/your/project
bash "$PLUGIN/install/install.sh" --full
```

Variants:

| Command | Effect |
|---|---|
| `install.sh` or `install.sh --lite` | Slash commands + the SessionEnd reminder hook only. Zero LLM cost |
| `install.sh --full` | Everything in lite, plus the three active hooks, plus the subagent |
| `install.sh --dry-run [--lite\|--full]` | Show what would change, write nothing |
| `install.sh --uninstall` | Remove the commands and subagent, restore `.claude/settings.json` from its backup |

What the three hooks do:

- **`SessionStart`** fingerprints the project, runs a fast dependency audit (osv-scanner if
  installed, else the per-ecosystem audit), and injects a `## SECURITY CONTEXT` block that
  every agent reads before its first turn.
- **`PreToolUse` on `Bash`** gates package-manager installs. It blocks known-malicious
  packages and asks on typosquats and brand-new packages.
- **`PostToolUse` on `Edit|Write|MultiEdit`** runs a fast pattern scan on each file write
  and feeds findings back through `additionalContext`.

**Other editors.** `install/windsurf/` holds a Windsurf rule and two workflows.
`install/codex/AGENTS.md.snippet` is a behavioural instruction for Codex CLI, which has no
hook system.

### phoenix-docs-research — the notebooklm skill

Needs Python 3, a Chrome or Edge browser, the "Claude in Chrome" extension, and a Google
account with NotebookLM access.

```bash
NB="$MP/plugins/phoenix-docs-research/skills/notebooklm"
python3 -m pip install -r "$NB/requirements.txt"
python3 "$NB/scripts/setup_environment.py"
```

Get a notebook ID from the URL: `https://notebooklm.google.com/notebook/<YOUR-ID>`.

> **Know this before you rely on it:** the skill stores its browser session and notebook
> library under its own directory. A plugin directory is managed by Claude Code and is
> replaced on `/plugin update`, so an update can drop your saved login and library. Back
> up `$NB/data/library.json` before updating, or install this one skill by copying it into
> `~/.claude/skills/` instead.

---

## Updating

```
/plugin marketplace update phoenix-security          # refresh the catalogue
/plugin update phoenix-security-review@phoenix-security
```

From the shell:

```bash
claude plugin marketplace update phoenix-security
claude plugin update phoenix-security-review@phoenix-security
```

A plugin update needs a restart to take effect.

After updating `phoenix-cti-search`, re-run `npm install --omit=dev` if `package.json`
changed. Your `.env` is not tracked by git, but a plugin update replaces the plugin
directory — copy `.env` somewhere safe first.

---

## Uninstalling

```
/plugin uninstall phoenix-security-review@phoenix-security
```

To remove the marketplace and everything from it:

```bash
claude plugin marketplace remove phoenix-security
```

If you wired the `phoenix-security-review` hooks into a project, unwire them first — the
installer tracks what it created, so the removal is clean:

```bash
bash "$PLUGIN/install/install.sh" --uninstall
```

---

## Installing from a local checkout

Use this while writing or changing a skill. A marketplace can point at a directory instead
of a repository, and your edits take effect immediately.

```bash
git clone https://github.com/Security-Phoenix-demo/security-skills-claude-code.git
cd security-skills-claude-code
claude plugin marketplace add "$(pwd)"
claude plugin install phoenix-readiness-reviews@phoenix-security
```

Validate before you push:

```bash
claude plugin validate .                                    # the marketplace manifest
claude plugin validate plugins/phoenix-security-review      # one plugin manifest
claude plugin validate --strict plugins/*/skills            # every skill's frontmatter
```

`--strict` fails on unrecognised fields and missing metadata — use it in CI. A local
marketplace and the GitHub one cannot both be named `phoenix-security` at the same time, so
remove one before adding the other.

---

## Copying a single skill instead

A skill directory is fully self-contained. Copy one in and it becomes a slash command named
after the directory, with no manifest and no marketplace:

```bash
# personal — every project on this machine
cp -r plugins/phoenix-readiness-reviews/skills/* ~/.claude/skills/

# project-scoped — committed, so the team gets it
cp -r plugins/phoenix-readiness-reviews/skills/* .claude/skills/
```

Claude Code watches these directories, so an edit lands in the running session with no
restart. Two limits to know:

- `~/.claude/skills/` is **not** read by Cowork or cloud sessions. Use the plugin route, or
  enable the skill on your claude.ai account, for those.
- Copied skills are not versioned and `/plugin update` does not touch them. You update them
  by copying again.

Make any bundled script executable after copying:

```bash
chmod +x ~/.claude/skills/production-readiness-review/scripts/scan_repo.sh
```

---

## Troubleshooting

### `/plugin marketplace add` fails

- **`marketplace.json not found`** — you pointed at the wrong place. The manifest must be at
  `.claude-plugin/marketplace.json` in the repository root. Check with
  `claude plugin validate <path>`.
- **A marketplace with that name already exists** — `claude plugin marketplace remove
  phoenix-security` first. This bites most often when you already added a local checkout.
- **Git clone failed** — the repository must be reachable with your current credentials. Try
  `git clone` by hand to see the real error.

### A skill never fires

1. Confirm it is loaded: `claude plugin details <plugin-name>` and look for it in the
   component inventory. If it is missing, the plugin is installed but the skill did not
   parse.
2. Confirm the plugin is **enabled**, not just installed: type `/plugin` and check.
3. Invoke it explicitly to rule out description matching:
   `/phoenix-readiness-reviews:plan-readiness-review`.
4. Still nothing? `claude plugin validate --strict <plugin>/skills` will name the file and
   the field that is wrong.

### Two commands with the same name

Claude Code resolves the bare name to one of them. Use the namespaced form —
`/phoenix-security-review:security-assessment` — to be unambiguous. The clash is usually
another marketplace or a skill in `~/.claude/skills/` claiming the same name.

### `Cannot find module` from `/cti-search`

The Node dependencies are not installed. See
[phoenix-cti-search setup](#phoenix-cti-search--node-and-an-api-key).

### `No search provider configured`

There is no `.env`, or the key in it is empty. The CLI reads `.env` from the plugin
directory, not from your project. Verify:

```bash
cat ~/.claude/plugins/marketplaces/phoenix-security/plugins/phoenix-cti-search/.env
```

If you would rather not manage a key, use the `cti-domain-research` skill — same tiered
search, no key needed.

### CTI search returns nothing

- Your query may be too narrow. Widen it, or raise `--since` (default is 90 days).
- Try a broader tier: `--tier 1` is the highest-authority sources only.
- Confirm the key works at all: `node "$CTI/index.js" --query test --dry-run`.
- A free-tier quota may be exhausted. Brave gives 2,000 requests a month.

### The hooks do not run

- Confirm the scripts are executable:
  `chmod +x "$PLUGIN/hooks/"*.sh`
- Confirm the wiring landed in a **project-level** `.claude/settings.json` — project settings
  beat user settings.
- Run a hook by hand to see its output. It should print JSON, not an error.
- `ripgrep` is required by the post-edit quickscan hook.

### NotebookLM will not connect

- Chrome or Edge must be running, with the "Claude in Chrome" extension installed.
- You must be signed in to the Google account that has the notebook.
- Re-run `python3 "$NB/scripts/setup_environment.py"`.
- If a `/plugin update` wiped the saved session, re-authenticate — see the warning in
  [per-plugin setup](#phoenix-docs-research--the-notebooklm-skill).

### The scanner reports nothing useful

`production-readiness-review`'s scanner emits **leads, not findings**. A `TODO` in a test
fixture is not a defect. If it finds nothing at all, check you passed a real base ref:

```bash
bash "$SKILL/scripts/scan_repo.sh" . --base origin/main
```

Without a valid base it skips the change-surface sections silently.

---

## Quick reference

### Commands

```bash
claude plugin marketplace add <owner>/<repo>       # or a local absolute path
claude plugin marketplace list
claude plugin marketplace update phoenix-security
claude plugin marketplace remove phoenix-security
claude plugin install <plugin>@phoenix-security [--scope user|project|local]
claude plugin update <plugin>@phoenix-security
claude plugin uninstall <plugin>@phoenix-security
claude plugin list
claude plugin details <plugin>
claude plugin validate <path> [--strict]
```

In a session: `/plugin`, `/plugin marketplace add`, `/plugin install`, `/plugin update`.

### Where things land

| Path | What it is |
|---|---|
| `~/.claude/plugins/marketplaces/phoenix-security/` | The cloned marketplace — all six plugins live under `plugins/` here |
| `~/.claude/plugins/installed_plugins.json` | What is installed, and at which scope |
| `~/.claude/skills/` | Skills you copied in by hand (Method 3) |
| `.claude/settings.json` | Project-level marketplace + enabled-plugin declarations |

### Try it

```
review this PRD before we build it              → plan-readiness-review
is this branch actually ready to ship?          → production-readiness-review
/security-review auth                          → 8-point check on auth surfaces
/security-0day origin/main                      → diff-scoped exploit scan
/threatmodel src/payments/                      → STRIDE + DREAD model
/cti-search CVE-2024-21762                      → tiered threat-intel search
write a PRD for passwordless login              → prd-generator
document this codebase                          → project-documenter
```

---

## Getting help

- **[README.md](README.md)** — full skill and plugin reference, FAQ
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — how to add a skill or a plugin
- **Issues** — [github.com/Security-Phoenix-demo/security-skills-claude-code/issues](https://github.com/Security-Phoenix-demo/security-skills-claude-code/issues)
- **Phoenix Security** — [phoenix.security](https://phoenix.security)

---

**License:** MIT — see [LICENSE](LICENSE).
