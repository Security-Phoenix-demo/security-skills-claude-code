# Troubleshooting — Project Documenter

Common issues, diagnostics, and fixes.

---

## Skill Installation Issues

### Skill doesn't appear in Claude.ai after installing

**Symptom:** Uploaded the `.skill` file but it doesn't show in Settings → Skills.

**Fixes:**
1. Hard-refresh the page (Ctrl+Shift+R or Cmd+Shift+R)
2. Close and reopen the browser tab
3. Try a different browser
4. Check the file uploaded completely — the `.skill` file should be 30–80 KB

### Skill installed but Claude doesn't use it

**Symptom:** You say "document this project" and Claude just starts writing freeform, not following the skill's structured workflow.

**Fixes:**
1. Start a new conversation — skills don't activate mid-conversation
2. Use an explicit trigger phrase: *"document this project"*, *"generate documentation for this repo"*, *"reverse engineer this codebase into docs"*
3. Check the skill is enabled: Settings → Skills → verify `project-documenter` shows a green active indicator
4. If the skill was very recently installed, wait 60 seconds and start a fresh conversation

---

## Documentation Generation Issues

### Claude asks questions when I selected Mode 0 (Express)

**Symptom:** You selected Express mode but Claude keeps stopping to confirm inferences.

**Cause:** Codebase has ambiguous patterns that Claude cannot confidently interpret.

**Fix:** Mode 0 should not ask questions — it should document inferences as explicitly inferred in Known Gaps sections. If Claude is asking, it may not have fully processed the Express mode instructions. Try:
```
I selected Mode 0 Express — please document everything without asking questions.
Mark any inferences explicitly in the Known Gaps sections.
```

### Generated documentation is generic / doesn't reflect my codebase

**Symptom:** SYSTEM_OVERVIEW.md talks about a generic "API layer" and "service layer" rather than your actual components.

**Cause:** Claude doesn't have enough codebase context to be specific.

**Fix:** Provide more concrete codebase content:
- Upload actual source files, not just directory listings
- Paste the content of your entry points, key services, and data models
- Share your `requirements.txt`/`package.json`/`go.mod` to establish the tech stack
- Share any existing README that describes the architecture

### CLAUDE.md is over 300 lines

**Symptom:** The generated CLAUDE.md exceeds the 300-line hard limit.

**Cause:** Content is leaking from sub-documents into CLAUDE.md — full descriptions instead of 2-line summaries with links.

**Fix:** Tell Claude:
```
CLAUDE.md is over 300 lines. Please identify which sections contain detail that belongs
in a sub-document, move that content to the appropriate sub-doc, and replace it in
CLAUDE.md with a 2-line summary plus a link.
```

### DOC_INDEX.md is over 200 lines

**Cause:** Content is leaking from CLAUDE.md into DOC_INDEX.md.

**Fix:**
```
DOC_INDEX.md is over 200 lines. It should only contain: repository identity (5 lines),
domain tables, task routing, high-risk areas, and do-not-load list. Please remove any
architecture explanations or module descriptions and link to CLAUDE.md instead.
```

### Files are skipping that I expected to be generated

**Symptom:** Expected `AGENT_WORKFLOWS.md` or `LLM_COST_MODEL.md` but they're marked as skipped.

**Cause:** The repo scan didn't find evidence for those file types.

**Fix:** Provide more context:
```
The project does use AI agents — here are the relevant files: [paste agent code]
```
Or re-run with explicit instruction:
```
Please generate AGENT_WORKFLOWS.md — the agents are in /src/agents/
```

### Sub-documents are missing the required header/footer

**Symptom:** Generated files don't have the `<!-- Parent: /CLAUDE.md -->` header or `Known Gaps` footer.

**Fix:**
```
Please add the required header block to every sub-document that is missing it:
<!-- Parent: /CLAUDE.md -->
<!-- Index:  /DOC_INDEX.md -->
<!-- Related: [related files] -->
<!-- Read when: [scenario] -->

And add the Known Gaps / Uncertainties footer to any sub-document that is missing it.
```

---

## Mode 5 / Self-Heal Issues

### GitHub Actions workflow doesn't trigger on PRs

**Symptom:** You open a PR but the **Self-Healing Documentation** workflow doesn't appear in the Actions tab.

**Fixes:**
1. Check the `paths` filter in `docs-self-heal.yml` — your changed files must match at least one path
2. Check the `branches` filter — your PR must target `main`, `develop`, or `master`
3. Verify GitHub Actions is enabled: Repository → Settings → Actions → General → Allow all actions
4. Confirm the workflow file is in `.github/workflows/` (not a subdirectory)

### Drift detection returns "No changes detected" when there were changes

**Symptom:** `analyze_codebase_changes.py` outputs `has_changes: false` despite real code changes.

**Fixes:**
1. Run locally with `GITHUB_EVENT_NAME=pull_request` to see the git diff:
   ```bash
   export GITHUB_EVENT_NAME="pull_request"
   python .github/scripts/analyze_codebase_changes.py
   cat .github/codebase-changes.json
   ```
2. Check the `by_type` section — it shows which pattern categories matched
3. If your language isn't covered by default patterns, add patterns to the `patterns` dict in `analyze_codebase_changes.py`
4. For scheduled runs (not PRs), the script looks at commits from the last 24 hours — if nothing was committed in that window, it returns `has_changes: false`

### API key error in GitHub Actions

**Symptom:** `detect_documentation_drift.py` fails with `ValueError: ANTHROPIC_API_KEY not set`

**Fixes:**
1. Confirm the secret name is exactly `ANTHROPIC_API_KEY` (case-sensitive)
2. Check the secret is added to the correct repository (not just the organization)
3. Verify the workflow passes the secret correctly:
   ```yaml
   env:
     ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
   ```
4. Re-run the workflow manually after confirming the secret exists

### `update_documentation.py` overwrites accurate content

**Symptom:** The nightly update replaces correct documentation with something less accurate.

**Cause:** The update prompt may be too permissive, or the drift item is misclassified.

**Fix:**
1. Review `.github/drift-analysis.json` — is the drift item accurate?
2. Review the commit diff — what exactly changed?
3. If the detection is a false positive, add a note to the drift detection prompt in `detect_documentation_drift.py`:
   ```python
   # In DRIFT_PROMPT, add to DO NOT FLAG section:
   DO NOT FLAG:
   - Changes to [specific file pattern] — these do not affect documentation
   ```
4. Revert the bad update: `git revert HEAD`

### PR comment not posting

**Symptom:** Drift is detected (shows in artifacts) but no comment appears on the PR.

**Fixes:**
1. Check workflow permissions:
   ```yaml
   permissions:
     pull-requests: write
   ```
2. Check the Actions tab for the GitHub Script step — look for permission errors
3. Confirm the workflow is running on the PR event, not just on push
4. For organization repos, ensure GitHub Actions has write access to PRs: Organization Settings → Actions → General

### Cursor rules not activating

**Symptom:** Cursor doesn't mention the documentation rules and doesn't update docs when you make code changes.

**Fixes:**
1. Verify the files exist at `.cursor/rules/50-hierarchical-documentation.mdc` and `.cursor/rules/51-auto-documentation-updates.mdc`
2. Restart Cursor — rules are loaded at startup, not hot-reloaded
3. Check the frontmatter has `alwaysApply: true`:
   ```
   ---
   description: ...
   alwaysApply: true
   ---
   ```
4. Verify Cursor rules are enabled: Cursor Settings → Features → Rules for AI

### Integrity check fails with broken links

**Symptom:** `verify_documentation_integrity.py` reports broken links in CLAUDE.md or DOC_INDEX.md.

**Fix:** Check which links are broken:
```bash
python .github/scripts/verify_documentation_integrity.py
```

Then fix the broken links:
- If the file was skipped during generation: remove the row from CLAUDE.md Section 7 and DOC_INDEX.md Domains
- If the file exists but at a different path: update the link
- If the section anchor doesn't exist: remove the anchor from the link or add the section to the target file

### Length gate violation after nightly update

**Symptom:** `verify_documentation_integrity.py` reports CLAUDE.md over 300 lines after an automated update.

**Cause:** The update prompt added detail to CLAUDE.md instead of the appropriate sub-document.

**Fix:**
1. Identify which section grew beyond its summary (should be 2 lines + link)
2. Move the detail to the relevant sub-document
3. Replace with: `[Brief summary]. See [/docs/path/to/file.md] for detail.`
4. Improve the update prompt to be more specific about what belongs in CLAUDE.md

---

## Output Quality Issues

### Mermaid diagrams not rendering

**Symptom:** Diagrams show as code blocks rather than rendered diagrams.

**Cause:** Mermaid rendering depends on the Markdown viewer. GitHub renders Mermaid natively; VS Code requires the Mermaid Preview extension.

**This is not a skill issue.** The diagrams are correctly generated. Use a Mermaid-compatible viewer.

### Data contracts show placeholder types instead of real types

**Symptom:** `DATA_CONTRACTS.md` shows `"field": "type"` instead of `"field": "string"` or `"id": "UUID v4"`.

**Cause:** Claude couldn't find the actual schema definitions in the provided codebase.

**Fix:** Share the actual model/schema files:
```
Here are my Pydantic models: [paste models.py]
Here are my TypeScript interfaces: [paste types.ts]
```

### Known Gaps section is empty

**Symptom:** Sub-documents end with `Known Gaps / Uncertainties: - None` when there are clearly gaps.

**Cause:** Claude may be overconfident about the completeness of the scan.

**Fix:**
```
Please review the Known Gaps sections — be more critical. What couldn't you confirm from
the code alone? What behavior is inferred? What tests are missing? What is the scan
missing that a reader would expect?
```

---

## Getting Further Help

If an issue isn't covered here:

1. Check the [HOW_IT_WORKS.md](./HOW_IT_WORKS.md) — the design decisions section often explains unexpected behavior
2. Re-read [MODES_REFERENCE.md](./MODES_REFERENCE.md) — verify you're using the right mode for your situation
3. For Mode 5 issues, the [SELF_HEAL_SETUP.md](./SELF_HEAL_SETUP.md) has detailed configuration options
4. Use the thumbs-down feedback button in Claude.ai to flag specific outputs for Anthropic to review
