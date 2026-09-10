---
name: production-readiness-review
description: >
  Adversarial senior/staff-engineer review that verifies a real codebase against its PRD,
  plan, or implementation plan and decides whether it is genuinely complete and production
  ready — never trusting the plan, the changelog, or the commit messages. Runs a
  deterministic repo scan, traces every requirement end-to-end through UI, API, service,
  persistence, jobs, config, migrations and deploy, checks that tests would actually fail
  if the code were wrong, then returns a counted SHIP / NO-SHIP with severity-ranked
  issues and, on request, fixes the Critical and High ones with sub-agents. Use this
  whenever someone asks whether something is done, shippable, or production ready; says
  "final review", "is this actually implemented", "verify the implementation against the
  PRD", "pre-merge review", "did we miss anything", "production readiness", "ship or
  no-ship", "audit this repo against the plan", or hands over a branch/PR plus a spec.
  Use it even when the request sounds routine, such as "quick check before we merge".
  If there is no code yet and only a plan, use plan-readiness-review instead.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/scan_repo.sh *)
---

# Production readiness review

The plan is a claim. The commit history is a claim. A passing test suite is a weaker claim
than it looks. Only the code, its wiring, its configuration and its behaviour under
failure are evidence. The job here is to **try to disprove that the work is done** and to
report what survived that attempt.

Two failure modes to avoid, in order: approving something that is not finished, and
producing a long review that never actually opened the files. Both come from reading the
plan instead of the repo.

## Phase 0 — Input contract

State what is under review before starting. Ask once, in one message, for whatever cannot
be inferred, then proceed with what is available and record the rest as a scope limit.

- Repo path(s), branch or PR, and the base ref the change is measured against.
- The plan/PRD/implementation-plan artefacts and their versions.
- Target environment and how it differs from local (managed DB, secrets store, replicas).
- How to run the tests, the linter, and the type checker. If they cannot be run, say so —
  a review that never executed the suite is a documentation review, and must be labelled
  as one.
- Whether remediation is authorised now, and up to which severity.

## Phase 1 — Deterministic scan

Run the bundled scanner first. It is reproducible, quotable, and
diffable across runs, which the model's own reading of the tree is not.

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scan_repo.sh /path/to/repo --base origin/main > scan.md
```

`${CLAUDE_SKILL_DIR}` resolves to this skill's own directory, so the path works whether the
skill is installed personally, in a project, or as part of a plugin.

It reports: incompleteness markers, swallowed errors and silent fallbacks, debug and
suppression leftovers, secret-shaped literals, route definitions vs auth markers, config
and migration artefacts, test surface, and the change surface vs base.

Its output is **leads, not findings**. Open each hit and judge it in context; a `TODO` in
a comment about future work is noise, a `TODO` where a permission check belongs is
Critical. Also run the suite, the linter and the type checker, and record the exact
commands and results.

## Phase 2 — Requirement trace matrix

Build the inventory of requirements and acceptance criteria from the plan (stable IDs
`R-001`…, source anchors), then trace each one to code. Three states only:

- **VERIFIED** — cited as `path:line` for each layer it touches, plus the test that proves
  it. A citation to a function that exists but is never called is not verification.
- **GAP** — with *evidence of absence*: the exact search that came back empty
  (`rg -n "revoke_token" src/` → 0 hits), so the finding is falsifiable.
- **UNVERIFIABLE** — what blocked verification and what would resolve it (no staging
  access, no seed data, external system). Never counted as done.

Trace in the direction of execution, not of the file tree: entrypoint → route/handler →
authz → validation → service → persistence → side effects (jobs, events, external calls)
→ config → migration → deploy manifest. A requirement is only VERIFIED when a real user
action in the target environment reaches the code that satisfies it.

The most common false pass: a service method that implements the requirement perfectly and
is wired to nothing. Check callers, route registration, DI container entries, job
schedules, feature-flag defaults, and env vars that exist in code but not in the deploy
config.

## Phase 3 — Test integrity

Test count and coverage percentage are not evidence. Do this instead:

- For the three most consequential MUSTs, **break the code and confirm a test fails**:
  invert a condition or comment out the check, run the targeted test, then restore. A test
  that still passes proves nothing. Record what you broke and what happened.
- Check that negative cases exist: rejected input, missing permission, wrong tenant,
  dependency failure, timeout, duplicate/replayed request.
- Look for tests that assert on mocks rather than behaviour, tautologies (`assert True`),
  and suites where the mock encodes the same assumption as the code.
- Check the changed lines specifically. Global coverage hides an untested new branch.
- Confirm skipped, quarantined, and flaky-retried tests are not covering this work.

## Phase 4 — Blast radius

New behaviour that works while old behaviour quietly breaks is the expensive outcome.

- Diff against the base ref; for every changed public function, endpoint, schema, event, or
  config key, list the existing consumers and check each still holds.
- Shared tables and columns: new NOT NULL, changed defaults, index changes, lock duration
  of the migration on production-sized data.
- Contract compatibility for anything already deployed and consumed: old clients, in-flight
  messages, cached payloads, persisted enums.
- Permission model changes that widen access for existing roles.

## Phase 5 — Non-functional gates

Work through `references/verification-checklists.md` — security, reliability,
observability, performance, data/migrations, config/deploy/rollback. It gives the concrete
per-domain checks and what counts as evidence for each. Security is not one bullet: every
new route needs an authorisation decision proven in code and in a test, and in a
multi-tenant system, isolation is verified with a cross-tenant test, not by inspection.

## Severity rubric

| Severity | Definition |
|---|---|
| **Critical** | Exploitable or destructive in production: authz bypass, cross-tenant data exposure, secret exposure, data loss or corruption, silently wrong results, irreversible migration with no back-out, guaranteed outage on deploy. |
| **High** | A material requirement is unimplemented, unwired, or unreachable; a primary-path failure is unhandled; a MUST has no test that would catch its violation; a breaking change to a consumed contract; a designed-for failure mode with no signal. |
| **Medium** | Partially implemented or weakly proven: missing negative tests, unhandled secondary edge case, known-load performance risk, config drift between environments, missing runbook for a real alert. |
| **Low** | Dead code, naming, cosmetic debt, non-blocking cleanup. |

## Output

Use `references/output-template.md` verbatim.

- **Every issue**: `Severity → Requirement → Evidence (path:line or command output) → Problem → Required fix`. The required fix names files and behaviour, not "improve error handling".
- **Never emit a percentage without its counts**: `Implementation completeness: 68% (23/34 requirements VERIFIED; 8 GAP, 3 UNVERIFIABLE)`. Unverifiable is never rounded into done.
- Verdict rule: **NO-SHIP if any Critical or High is open.** Say exactly what flips it.
- Every "not present" claim carries the search that produced zero hits.
- Emit the full audit before touching any code. An audit interleaved with fixes stops being
  an audit — the picture of what was actually shipped is lost.

## Phase 6 — Remediation (only after the audit is emitted)

When authorised, fix in severity order: Critical, then High, then Medium if asked.

**Sub-agent contract.** One issue per sub-agent, and give it:

- the issue ID, the requirement, the evidence, and the required fix;
- the exact files it may touch and the ones it may not;
- the acceptance test it must add or make pass;
- the constraint that product requirements, public contracts, and unrelated code stay
  unchanged.

It must return: the diff summary, files changed, the test command and its real output, any
new UNRESOLVED ASSUMPTION, and the blast radius it observed. Reject any return that claims
success without test output.

After each fix: run the targeted tests, then the full suite, then re-audit the affected
requirement **and its consumers** — a fix that breaks a neighbour is a new Critical, not a
detail. Update the counts and re-issue the verdict block.

**Stop conditions.** Stop and come back to the human when: a fix requires a product
decision, a fix requires changing a requirement, the same test fails twice after two
different attempts, the blast radius exceeds the area under review, or a fix would need
credentials or production access. Record it as an UNRESOLVED ASSUMPTION with a suggested
default and an owner. Never guess a product decision to close an issue, and never delete or
weaken a failing test to make a fix pass — that converts a High into a Critical.

## Re-runs

Keep issue IDs stable so a second run reports a delta: fixed, still open, newly introduced.
Regressions introduced by remediation are reported in their own section, since they are the
most likely thing a rushed second review misses.
