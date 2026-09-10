# phoenix-readiness-reviews

Two adversarial review gates, split by what is under review.

![Plan readiness and production readiness — the two gates side by side, their focus areas and their verdicts](../../images/PRD-IMp-skill.jpeg)

| Skill | Input | Question | Verdict |
|---|---|---|---|
| `plan-readiness-review` | PRD / plan / spec / RFC / design | Could another senior engineer build this without inventing anything? | READY / NOT READY |
| `production-readiness-review` | Repo + branch + plan | Is it actually built, wired, tested, and safe to deploy? | SHIP / NO-SHIP |

Run the plan gate before build. Run the production gate before merge or release. The
production gate assumes the plan exists but never trusts it.

Splitting them on the artefact is deliberate: one prompt that reviews both a plan and a
codebase at once ends up doing neither well. Split, each is shorter, sharper, and
independently re-runnable.

## Install

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
/plugin install phoenix-readiness-reviews@phoenix-security
```

That gives you `/plan-readiness-review` and `/production-readiness-review`, plus automatic
invocation when a request matches either description.

Full installation options, including a local checkout and team-wide auto-install:
[MARKETPLACE_INSTALL.md](../../MARKETPLACE_INSTALL.md).

### Or copy the skills in by hand

Each skill directory is self-contained, so you can copy one or both without a manifest:

```bash
git clone https://github.com/Security-Phoenix-demo/security-skills-claude-code.git
cd security-skills-claude-code/plugins/phoenix-readiness-reviews

cp -r skills/* ~/.claude/skills/                # both gates
# or just one:
cp -r skills/plan-readiness-review ~/.claude/skills/

chmod +x ~/.claude/skills/production-readiness-review/scripts/scan_repo.sh
```

Claude Code watches these directories, so an edit lands in the running session without a
restart. Use `.claude/skills/` instead of `~/.claude/skills/` to commit them to a repo for
the team. Note `~/.claude/skills/` is not read by Cowork or cloud sessions — use the plugin
route for those.

## How the two reviews work

![Plan readiness review and production readiness review — inputs, checks, evidence model and verdicts](../../images/PRD-Imp_skill-review.jpeg)

**Left — the plan gate.** Every artefact it accepts (PRD, plan, spec, RFC, design), the gaps
it hunts for (ambiguity, missing requirements, unresolved decisions, undocumented
assumptions, incomplete edge cases, missing acceptance criteria), and the READY / NOT READY
decision. It passes only when no implementation assumption is left.

**Right — the production gate.** What it proves against the real repository: implemented,
wired, tested, secure, observable, deployable, rollback-ready. It hunts dead code, missing
wiring, swallowed errors, permission and validation gaps, absent negative tests. Evidence
over assumption, or NO-SHIP.

**Bottom.** Where each gate sits — `PLAN → REVIEW → BUILD → VERIFY → MERGE → SHIP` — and the
three-state evidence model both share.

## Use it

```
/plan-readiness-review docs/payments-prd.md
review this spec before we build it
is this ready to implement?
poke holes in this plan

/production-readiness-review
is this actually implemented?
verify the implementation against the PRD
ship or no-ship?
```

## Layout

```
skills/
├── plan-readiness-review/
│   ├── SKILL.md
│   └── references/
│       ├── ambiguity-patterns.md      # phrasings that survive review and then split teams
│       └── output-template.md
└── production-readiness-review/
    ├── SKILL.md
    ├── references/
    │   ├── verification-checklists.md # per-domain checks, each with required evidence
    │   └── output-template.md
    └── scripts/
        └── scan_repo.sh               # deterministic evidence collector
```

## The scanner

`skills/production-readiness-review/scripts/scan_repo.sh` is standalone and useful on its own.
It needs only bash and grep:

```bash
MP=~/.claude/plugins/marketplaces/phoenix-security          # or your local checkout
SCAN="$MP/plugins/phoenix-readiness-reviews/skills/production-readiness-review/scripts/scan_repo.sh"

bash "$SCAN" /path/to/repo --base origin/main > scan.md
bash "$SCAN" . --base main --exclude 'generated/'
bash "$SCAN" --help
```

It uses ripgrep when present and falls back to grep. It emits `path:line` for every hit,
under seven sections:

| # | Section | What it collects |
|---|---|---|
| 1 | Incompleteness markers | `TODO` / `FIXME` / `HACK` / `XXX` / `TBD`; not-implemented bodies; placeholder values (`CHANGEME`, `example.com`, dummy tokens); mocks, stubs and fakes outside tests |
| 2 | Silent failure and swallowed errors | Empty `except` / `catch` / `rescue`; broad catches (`except Exception`, `catch (Throwable)`); silent defaults on failure |
| 3 | Debug and dev leftovers | Debug output (`console.log`, `pdb.set_trace`, `debugger`, `binding.pry`); disabled tests; lint and type suppressions (`# type: ignore`, `@ts-ignore`, `nosec`, `noqa`) |
| 4 | Security surface | Secret-shaped literals; auth and permission markers; route definitions (count them against the auth markers); injection-prone patterns (`eval`, `shell=True`, `innerHTML`, string-built SQL); TLS and certificate checks disabled |
| 5 | Config, flags, migrations, deploy | Environment-variable reads; feature flags; and which config, migration and deploy artefacts are **present or missing** |
| 6 | Test surface | Test-file and source-file counts; negative and failure-path assertions; tautological or empty tests |
| 7 | Change surface | Merge-base against the ref, changed files, how many of them are tests — and a warning when a diff changed no test at all |

Sections 1, 3 and parts of 4 and 5 skip test paths, so a `TODO` in a fixture does not
pollute the result. Vendor directories (`node_modules`, `dist`, `target`, `.venv`, `.next`,
`.terraform` and friends) are excluded by default; `--exclude <regex>` adds your own.

Exit code is `0` whenever the scan completes — findings are not failures. It exits `1` only
on bad usage or a bad path. Without a usable base ref, section 7 says so instead of failing.

Output is deterministic, so two runs diff cleanly and the review's evidence is reproducible
rather than dependent on what the model happened to read.

The skill declares `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/scan_repo.sh *)`, so the
scan runs without a permission prompt on the turn you invoke the skill. `${CLAUDE_SKILL_DIR}`
resolves to the skill's own directory at every install level.

Its output is **leads, not findings**. A `TODO` in a test fixture is not a defect. The review
opens each hit and judges it in context.

## What the output looks like

Both skills open with a Verdict block, and both are counted. This is the plan gate:

```markdown
## Verdict

**READY TO IMPLEMENT: NO**

- Plan completeness: **68%** (23 READY / 34 requirements; 9 GAP, 2 UNVERIFIABLE)
- Requirements inventoried: 34 (6 of them [implied], not stated)
- Open issues: 2 Critical, 4 High, 3 Medium, 0 Low
- Scope of this review: docs/payments-prd.md @ v1.4; billing schema out of scope
- Verdict rule applied: NOT READY while any Critical or High is open

## What would flip the verdict

1. R-007 — state the retry budget and the dead-letter destination for a failed capture — owner, ETA
2. R-012 — define who may refund, and above which amount approval is required — owner, ETA
```

And the production gate:

```markdown
## Verdict

**PRODUCTION READY: NO**

- Plan completeness: **91%** (31 READY / 34 requirements)
- Implementation completeness: **74%** (25 VERIFIED / 34; 7 GAP, 2 UNVERIFIABLE)
- Open issues: 1 Critical, 3 High, 5 Medium, 2 Low
- Scope: repo `.` @ `a1b2c3d` vs base `origin/main`; plan `payments-prd.md v1.4`
- Verdict rule applied: NO-SHIP while any Critical or High is open

## Blocking issues

- P-001 [Critical] `GET /v1/findings/{id}` has no tenant check — findings/api.py:212
- P-004 [High] refund handler catches and drops every exception — billing/refund.py:88
```

After the verdict come the per-requirement inventory, the remaining work with owners, and an
evidence log of what was actually executed — so the review's limits are visible, not implied.
Full structures: each skill's `references/output-template.md`.

## What makes the verdicts trustworthy

| Rule | Why |
|---|---|
| Percentages carry counts — `68% (23/34 VERIFIED)` | A bare percentage from a language model is an invented number |
| Three states: VERIFIED / GAP / UNVERIFIABLE | "I could not check this" must not collapse into a pass or a fail |
| Absence claims cite the search that returned zero hits | Makes the review falsifiable instead of merely confident |
| Audit and remediation split by a hard gate | Fixing while auditing destroys the record of what shipped |
| Severity from a rubric, not intuition | Two reviewers reach the same ranking |
| Test integrity checked by breaking the code | A test that cannot fail proves nothing, whatever the coverage says |
| Wiring gets its own pass | With a named list of the "exists but is dead" traps |
| Stable issue IDs | A re-run reports a delta, not a fresh list |
| Sub-agent work has an input/output contract | Including explicit stop conditions |

## Pairs with

- **`phoenix-prd-pipeline`** writes the PRD that `plan-readiness-review` then reviews. Use
  `prd-generator` or the 12 roles to produce the plan, this plugin to decide whether it holds.
- **`phoenix-security-review`** answers the security half of the ship question. The
  production gate checks that security controls exist and are wired; `security-reviewer` and
  `0day-scanner` judge whether they are correct.

## Notes

- Both skills stay inside the Agent Skills spec frontmatter (`name`, `description`,
  `allowed-tools`), so the same folders upload to claude.ai and the Skills API unchanged.
  Adding a Claude Code-only field such as `argument-hint` or `context: fork` would break that
  path with a hard error.
- The descriptions are deliberately pushy, so Claude reaches for these on "quick check before
  we merge". Add `disable-model-invocation: true` if you want them to fire only when you type
  the command — but that also drops the description from context, so Claude stops suggesting
  them, and it takes the skill outside the portable spec.
- `production-readiness-review` can burn real time on a large repo. Worth knowing before you
  point it at a monorepo.
