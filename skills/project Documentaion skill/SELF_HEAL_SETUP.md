# Self-Heal Setup Guide — Project Documenter Mode 5

Complete setup guide for the self-healing documentation pipeline: Cursor rules, GitHub Actions workflow, and Python scripts.

---

## What the Self-Heal System Does

The self-heal system maintains documentation accuracy as code evolves — automatically and conservatively.

```
Code change committed
         ↓
analyze_codebase_changes.py     detect structural changes (no AI needed)
         ↓
detect_documentation_drift.py  Claude identifies outdated docs and severity
         ↓
generate_drift_report.py        generate PR comment / artifact
         ↓
update_documentation.py         (update mode) targeted section updates only
         ↓
verify_documentation_integrity.py  broken links, length gates, headers
         ↓
PR: comment + optional merge block
Nightly: auto-commit updated docs
```

---

## Prerequisites

| Item | Required | Notes |
|------|----------|-------|
| CLAUDE.md and DOC_INDEX.md exist | Yes | Run Mode 0 or 4 first |
| GitHub repository | Yes | Actions must be enabled |
| `ANTHROPIC_API_KEY` | Recommended | Falls back to heuristics without it |
| Python 3.11+ | Yes | For local testing |

---

## Part 1 — Cursor Rules

### What They Do

Two `.mdc` files are placed in `.cursor/rules/`. Cursor loads these on every AI-assisted editing session.

**`50-hierarchical-documentation.mdc`** enforces the three-layer documentation hierarchy:
- Always start with DOC_INDEX.md
- Load only task-relevant sub-documents
- Maintain CLAUDE.md ≤ 300 lines, DOC_INDEX.md ≤ 200 lines
- Use required header/footer on every sub-document
- Never duplicate content across layers

**`51-auto-documentation-updates.mdc`** tells the agent which docs to update for each code change:
- API change → `docs/general/API_REFERENCE.md`
- AI prompt change → `docs/ai/PROMPTS.md` + `PROMPT_TESTS.md`
- Architecture change → `docs/architecture/SYSTEM_OVERVIEW.md` + `REPOSITORY_MAP.md`
- Auth change → `API_REFERENCE.md#auth` + `MODEL_GUARDRAILS.md`
- Schema change → `docs/architecture/DATA_CONTRACTS.md` + `DEPENDENCY_MAP.md`

Both rules use `alwaysApply: true` — they fire on every Cursor session, not just documentation-specific tasks.

### Activating Cursor Rules

1. Ensure the files exist at `.cursor/rules/50-hierarchical-documentation.mdc` and `.cursor/rules/51-auto-documentation-updates.mdc`
2. Restart Cursor (rules are loaded at startup)
3. The rules are active — no further configuration needed

### Verifying Cursor Rules Are Active

Open Cursor, start a new chat, and type:

```
what documentation rules are you following?
```

Cursor should reference the hierarchical documentation system and the auto-update behavior.

---

## Part 2 — GitHub Actions Workflow

### Workflow File

Location: `.github/workflows/docs-self-heal.yml`

### Three Triggers

**Pull Request (check mode)**
- Runs when PRs target `main`, `develop`, or `master`
- Path filter: only triggers when source code, docs, or rules change
- Detects drift, posts comment to PR, blocks merge on high severity
- Does NOT auto-update documentation

**Nightly Schedule (update mode)**
- Runs at 2:00 AM UTC daily
- Detects drift and automatically updates affected doc sections
- Commits changes with `docs: self-healing update [skip ci]`
- `[skip ci]` prevents the commit from triggering another workflow run

**Manual Dispatch (check or update)**
- Available in GitHub Actions → Self-Healing Documentation → Run workflow
- Select mode: `check` (report only) or `update` (report + update)
- Useful for on-demand documentation refresh

### Adjusting the Path Filter

By default the workflow triggers when these paths change:

```yaml
paths:
  - 'src/**'
  - 'lib/**'
  - 'app/**'
  - 'services/**'
  - 'api/**'
  - 'ai/**'
  - 'docs/**'
  - 'CLAUDE.md'
  - 'DOC_INDEX.md'
  - '.cursor/rules/**'
```

Adjust to match your project's source paths. The workflow will only run when the matched paths change.

### Adjusting the Nightly Schedule

Edit the cron expression in `docs-self-heal.yml`:

```yaml
schedule:
  - cron: '0 2 * * *'    # 2 AM UTC daily
  # - cron: '0 14 * * *'  # 2 PM UTC daily
  # - cron: '0 2 * * 1'   # 2 AM UTC Mondays only
```

### Disabling the Merge Block

The workflow blocks merge on high-severity drift by default. To disable:

Remove or comment out the final step in `docs-self-heal.yml`:

```yaml
# - name: Block merge on high-severity drift
#   if: ...
#   run: |
#     echo "::error::High-severity documentation drift..."
#     exit 1
```

---

## Part 3 — Python Scripts

### Script Overview

| Script | Requires AI? | Purpose |
|--------|-------------|---------|
| `analyze_codebase_changes.py` | No | Regex-based structural change detection |
| `detect_documentation_drift.py` | Yes | AI drift analysis and severity classification |
| `generate_drift_report.py` | No | Convert JSON analysis to markdown report |
| `update_documentation.py` | Yes | Targeted section updates |
| `verify_documentation_integrity.py` | No | Link check, length gates, header/footer validation |

### Installing Dependencies

```bash
pip install anthropic openai tiktoken
# or
pip install -r .github/scripts/requirements.txt
```

### Running Locally

```bash
cd your-repo
export ANTHROPIC_API_KEY="sk-ant-..."

# Step 1: analyze what changed
export GITHUB_EVENT_NAME="pull_request"
python .github/scripts/analyze_codebase_changes.py
cat .github/codebase-changes.json

# Step 2: detect drift
python .github/scripts/detect_documentation_drift.py
cat .github/drift-analysis.json

# Step 3: generate readable report
python .github/scripts/generate_drift_report.py
cat .github/drift-report.md

# Step 4: update docs (optional, use carefully)
python .github/scripts/update_documentation.py

# Step 5: verify integrity
python .github/scripts/verify_documentation_integrity.py
```

### Customizing Change Detection

`analyze_codebase_changes.py` detects changes using regex patterns. The default patterns work across Python, TypeScript, Kotlin, Go, and Ruby. To add support for additional languages or patterns, edit the `patterns` dictionary:

```python
patterns = {
    'new_routes':      r'(@app\.(get|post|put|delete|patch)|@Router|...)',
    'new_services':    r'(@Service|@Injectable|class \w+Service|...)',
    # add your patterns here
    'new_graphql':     r'(@Query|@Mutation|@Resolver)',
}
```

### Customizing Drift Detection Severity

Edit the `DRIFT_PROMPT` in `detect_documentation_drift.py`. The severity classification section defines what counts as high, medium, and low:

```python
DRIFT_PROMPT = """...
SEVERITY CLASSIFICATION
-----------------------
high:   New entry point, removed service, changed runtime flow, new AI component, auth change
medium: New API endpoint, new service, configuration change, schema change
low:    Minor feature addition, internal refactoring with external API unchanged
...
```

### Customizing Update Behavior

Edit the `UPDATE_PROMPT` in `update_documentation.py`. The STRICT RULES section controls how conservative the updates are:

```python
UPDATE_PROMPT = """...
STRICT RULES:
1. Preserve ALL content that is still accurate
2. Update ONLY the sections affected by this specific drift item
...
```

---

## Part 4 — Adding GitHub Secrets

### Required Secret

| Secret | Value | Where to Get It |
|--------|-------|----------------|
| `ANTHROPIC_API_KEY` | `sk-ant-...` | [console.anthropic.com](https://console.anthropic.com) → API Keys |

### Optional Secret

| Secret | Value | Purpose |
|--------|-------|---------|
| `OPENAI_API_KEY` | `sk-...` | GPT-4 fallback if Claude unavailable |

### Adding to GitHub

1. Go to your repository on GitHub
2. **Settings** (top menu) → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `ANTHROPIC_API_KEY`
5. Value: your key
6. Click **Add secret**

### For Organizations

If using an organization-level secret shared across repos:
1. **Organization Settings** → **Secrets and variables** → **Actions**
2. Add the secret and select which repositories can access it

---

## Part 5 — Verification

### Confirm the Workflow Runs

1. Create a branch, make a code change, open a PR
2. Go to **Actions** tab in your GitHub repository
3. Look for **Self-Healing Documentation** workflow
4. It should trigger within 1–2 minutes of the PR being opened

### Confirm Drift Detection Works

If the first run shows "No structural changes detected" but you know there have been changes:
- Check that your source paths are included in the workflow's `paths` filter
- Run `analyze_codebase_changes.py` locally to see what it detected
- Check `.github/codebase-changes.json` for the output

### Confirm PR Comments Work

The workflow needs `pull-requests: write` permission. Verify in `docs-self-heal.yml`:

```yaml
permissions:
  contents: write
  pull-requests: write
```

If comments are not posting, check the Actions tab for permission errors.

---

## Cost Estimation

Each drift detection run sends approximately 3,000–6,000 tokens to Claude (changes summary + doc summaries). Each update run sends 8,000–16,000 tokens per affected document.

Approximate costs using Claude Sonnet:

| Run Type | Tokens | Approx. Cost |
|----------|--------|-------------|
| Detection only (PR) | ~4,000 | ~$0.01 |
| Detection + 1 update | ~12,000 | ~$0.03 |
| Detection + 5 updates | ~48,000 | ~$0.14 |
| Nightly (no drift) | ~4,000 | ~$0.01 |

Monthly estimate for an active project (20 PRs, 30 nightly runs):
- Detection: ~$0.50
- Updates: ~$1–3 depending on drift frequency
- Total: **~$1.50–$3.50 / month**

---

## Disabling the System

### Disable CI workflow only (keep Cursor rules)

Delete or rename `.github/workflows/docs-self-heal.yml`.

### Disable Cursor rules only (keep CI)

Delete `.cursor/rules/50-hierarchical-documentation.mdc` and `.cursor/rules/51-auto-documentation-updates.mdc`, then restart Cursor.

### Disable everything

Delete all self-heal files. The documentation system (CLAUDE.md, DOC_INDEX.md, /docs) remains intact and fully functional — it just won't update automatically anymore.
