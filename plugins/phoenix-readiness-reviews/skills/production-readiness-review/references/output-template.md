# Output template — production readiness review

Use this structure verbatim. Drop genuinely empty sections rather than writing filler,
except the Verdict block and Evidence log, which are always complete.

---

## Verdict

**PRODUCTION READY: YES / NO**

- Plan completeness: **X%** (`n` READY / `N` requirements) — from plan-readiness criteria
- Implementation completeness: **X%** (`v` VERIFIED / `N`; `g` GAP, `u` UNVERIFIABLE)
- Open issues: `c` Critical, `h` High, `m` Medium, `l` Low
- Scope: repo `<path>` @ `<sha>` vs base `<ref>`; plan `<doc + version>`
- Verdict rule applied: NO-SHIP while any Critical or High is open

## Blocking issues

Ordered list of the Critical and High IDs only, each one line. This is the section people
act on.

## Remaining work

Exact actionable items, ordered, each with owner and ETA. "Add cross-tenant negative test
for `GET /v1/findings/{id}` in `tests/api/test_findings.py`" — not "improve test coverage".

## Evidence log

What was actually executed, so the review is reproducible and its limits are visible.

| Check | Command | Result |
|---|---|---|
| Deterministic scan | `bash scan_repo.sh . --base origin/main` | 14 leads, 6 material |
| Test suite | `pytest -q` | 212 passed, 3 skipped, 41s |
| Type check | `mypy src/` | 0 errors |
| Mutation spot-check | inverted tenant check at `api/findings.py:88` | `test_tenant_isolation` still passed → issue I-004 |

If the suite was not run, say so here and label the review a documentation review.

## Requirement trace matrix

| ID | Requirement | Status | Evidence (path:line) | Test proving it |
|---|---|---|---|---|
| R-001 | | VERIFIED / GAP / UNVERIFIABLE | | |

GAP rows carry the search that returned nothing. UNVERIFIABLE rows carry what would resolve
them.

## Issues

One block per issue, Critical → Low, stable IDs across re-runs.

**`I-001` · Critical · R-007 cross-tenant isolation on findings export**
- Evidence: `api/export.py:142` filters by `body.tenant_id`; `rg -n "session.tenant" api/export.py` → 0 hits
- Problem: tenant is taken from the request body, so any authenticated user can export another tenant's findings
- Required fix: derive tenant from the session claim; add a negative test asserting 404 for a foreign tenant ID; add an audit event on rejection
- Blast radius: `export.py`, `ExportService.build_query`, 2 callers in `jobs/scheduled_export.py`

## Regressions and blast radius

Existing behaviour affected by this change, and by any remediation performed in this run.

## Unverified assumptions

| ID | Assumption | Why it could not be verified | Suggested default | Owner | Decide by |
|---|---|---|---|---|---|
| A-001 | | | | | |

## Remediation log (only when fixes were performed)

| Issue | Sub-agent | Files changed | Tests run | Result | Re-audit |
|---|---|---|---|---|---|
| I-001 | fix-tenant-scope | api/export.py, tests/api/test_export.py | `pytest tests/api -q` | 18 passed | R-007 VERIFIED |

Then re-issue the Verdict block with updated counts.

## Scope limits

What could not be reviewed and why: no staging access, external system unavailable,
generated code excluded, no production data profile. An unstated limit reads as a pass.
