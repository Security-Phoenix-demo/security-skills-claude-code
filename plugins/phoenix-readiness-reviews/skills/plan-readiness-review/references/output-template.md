# Output template — plan readiness review

Use this structure verbatim. Drop sections that are genuinely empty rather than writing
"none identified" filler, except the Verdict block, which is always complete.

---

## Verdict

**READY TO IMPLEMENT: YES / NO**

- Plan completeness: **X%** (`n` READY / `N` requirements; `g` GAP, `u` UNVERIFIABLE)
- Requirements inventoried: `N` (`i` of them `[implied]`, not stated)
- Open issues: `c` Critical, `h` High, `m` Medium, `l` Low
- Scope of this review: <artefacts + versions reviewed; what was out of scope>
- Verdict rule applied: NOT READY while any Critical or High is open

## What would flip the verdict

Ordered, exact edits. Nothing vague.

1. `<ID>` — <exact text or section to add to the plan> — owner, ETA
2. …

## Requirement inventory

| ID | Requirement | Anchor | Status | Failing check(s) |
|---|---|---|---|---|
| R-001 | <short statement> | §2.1 | READY / GAP / UNVERIFIABLE | e.g. 3 schema, 5 errors |

`UNVERIFIABLE` rows state what access or document would resolve them.

## Issues

One block per issue, ordered Critical → Low. Stable IDs across re-runs.

**`P-001` · Critical · <requirement or area>**
- Evidence: <anchor + the quoted phrase that is the problem>
- Gap: <what an implementer cannot determine, or what two readings exist>
- Required fix: <the concrete edit — schema, contract, threshold, rule>
- Cost of deferring: <what gets built wrong / what rework this causes>

## Falsification results

- Literal implementation: <what a lazy compliant build would produce, and where it diverges from intent>
- Two-engineer divergence: <the 3 requirements tested, with the two incompatible builds each allows>
- Hostile input / abuse: <which requirement has no answer>

## Unresolved assumptions

| ID | Assumption | Why it cannot be derived | Suggested default | Owner | Decide by |
|---|---|---|---|---|---|
| A-001 | | | | | |

These are never resolved by the reviewer. A suggested default is a proposal, not a decision.

## Cross-cutting findings

Only the sweeps that produced something: coherence, sequencing, security-by-design,
failure/recovery, observability, impact on existing behaviour, rollout/rollback,
compliance.

## Scope limits

What this review could not cover and why (missing docs, no repo access, no data on current
load). State it plainly — an unstated limit reads as a clean bill of health.
