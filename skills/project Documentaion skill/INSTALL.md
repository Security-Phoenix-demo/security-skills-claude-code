# Installation Guide — Project Documenter

Complete guide to installing the skill, running your first documentation session, and verifying the output.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Claude.ai account | Pro, Team, or Enterprise plan (skill installation requires a paid plan) |
| Codebase | Any language, any size — uploaded files, pasted code, or repo context |
| Mode 5 only | GitHub repository + `ANTHROPIC_API_KEY` in GitHub Secrets |

---

## Step 1 — Download the Skill File

Download `project-documenter.skill` from the marketplace or release page.

The `.skill` file is a ZIP archive containing:
```
project-documenter/
├── SKILL.md                              ← orchestration logic
└── references/
    ├── mode-docs.md                      ← general documentation templates
    ├── mode-ai.md                        ← AI/LLM documentation templates
    ├── mode-architecture.md              ← architecture sub-document templates
    ├── mode-claude-md.md                 ← CLAUDE.md generation rules
    ├── mode-doc-index.md                 ← DOC_INDEX.md generation rules
    └── mode-self-heal.md                 ← CI pipeline and Cursor rules templates
```

---

## Step 2 — Install in Claude.ai

### Option A — File Upload (recommended)

1. Open [claude.ai](https://claude.ai)
2. Navigate to **Settings** (top-right profile menu)
3. Select **Skills** from the left sidebar
4. Click **Install skill from file**
5. Select `project-documenter.skill`
6. Confirm the skill name appears as **project-documenter** in your skills list

### Option B — Claude Code (CLI)

If you use Claude Code (`claude` CLI):

```bash
claude skills install ./project-documenter.skill
```

Verify installation:

```bash
claude skills list | grep project-documenter
```

---

## Step 3 — Verify Installation

Start a new conversation and type:

```
what skills do you have?
```

You should see `project-documenter` listed. If not, restart the browser tab and try again.

---

## Step 4 — Your First Documentation Run

### Option A — New project (fastest)

Share your codebase and say:

```
document this project
```

Claude will ask which mode to use. Select **[0] Express** for a new project with no existing docs. It will run without further questions and produce the full documentation pack.

### Option B — Existing project with some docs

```
document this project — it has partial existing docs at /docs and README.md
```

Claude will run the audit step, triage existing files, and integrate them rather than overwriting.

### Option C — Specific domain only

```
document the AI layer of this project
```

Claude will detect this as Mode 2 and produce only the AI/LLM documentation files.

---

## Step 5 — Provide Your Codebase

Claude needs access to your code. Three ways to provide it:

**Upload files** — drag files or folders directly into the chat.  
Best for projects under 50 files.

**Paste key files** — paste the content of critical files (entry points, models, routes, prompts).  
Works for any size; focus on the files that matter most.

**Describe the structure** — if you can't share code, describe it:

```
The project is a Python Flask API with:
- /api/routes/ — REST endpoints
- /services/ — business logic
- /ai/prompts/ — prompt templates calling Claude API
- /models/ — SQLAlchemy ORM models
- PostgreSQL database, Redis cache, deployed on AWS ECS
```

Claude will work with whatever level of detail you provide and flag anything it could not confirm.

---

## Step 6 — Download Your Documentation

After the run completes, Claude will:

1. Print the **Completion Report** — a full inventory of every file created, every existing doc audited, key findings, and recommended next actions
2. Call `present_files` — making all generated files available for download

Click the file links to download individual files, or download all at once.

---

## First-Run Checklist

```
□ Skill appears in claude.ai Skills list
□ Test message "document this project" triggers the skill
□ Codebase provided (uploaded, pasted, or described)
□ Mode selected (0 Express if brand new project)
□ Completion Report reviewed
□ Files downloaded
□ (Mode 5 only) ANTHROPIC_API_KEY added to GitHub Secrets
□ (Mode 5 only) Workflow tested locally
```

---

## Running Mode 5 (Self-Heal CI)

Mode 5 adds automated documentation maintenance. Run it after Modes 0–4.

### Prerequisites for Mode 5

- Repository hosted on GitHub
- GitHub Actions enabled
- `ANTHROPIC_API_KEY` available

### Add the GitHub Secret

1. Go to your repository on GitHub
2. **Settings → Secrets and variables → Actions → New repository secret**
3. Name: `ANTHROPIC_API_KEY`
4. Value: your Anthropic API key (`sk-ant-...`)
5. Click **Add secret**

Optionally add `OPENAI_API_KEY` as a fallback.

### Test Locally Before Pushing

```bash
cd your-repo

# Install dependencies
pip install anthropic openai tiktoken

# Set your key
export ANTHROPIC_API_KEY="sk-ant-..."

# Simulate a PR run
export GITHUB_EVENT_NAME="pull_request"
python .github/scripts/analyze_codebase_changes.py
python .github/scripts/detect_documentation_drift.py
python .github/scripts/generate_drift_report.py

# Review the report
cat .github/drift-report.md
```

### Commit the Generated Files

```bash
git add .cursor/rules/ .github/workflows/ .github/scripts/ docs/DOC_AUTOMATION.md
git commit -m "docs: add self-healing documentation CI"
git push
```

The workflow will activate on the next pull request.

---

## Updating the Skill

When a new version of `project-documenter.skill` is available:

1. Download the new `.skill` file
2. In Claude.ai → Settings → Skills → click the existing skill → **Replace**
3. Upload the new file

Skill updates do not affect previously generated documentation in your repos.

---

## Uninstalling

In Claude.ai → Settings → Skills → click `project-documenter` → **Remove skill**

This removes the skill from Claude. It does not affect any documentation files already generated in your repositories.
