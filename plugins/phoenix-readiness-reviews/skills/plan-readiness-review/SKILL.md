---
name: plan-readiness-review
description: >
  Adversarial senior/staff-engineer review of a PRD, plan, spec, RFC, design doc, or
  implementation plan to decide whether it is implementation-ready — detailed enough that
  a different senior engineer could build it without inventing requirements, architecture,
  schemas, API contracts, error handling, or acceptance criteria. Produces a requirement
  inventory with stable IDs, a per-requirement readiness verdict backed by document
  anchors, an unresolved-assumption register, and a counted READY / NOT READY decision.
  Use this whenever someone asks to review a plan, PRD, spec, RFC, design, or ticket
  before build; says "is this ready to implement", "is this spec complete", "review my
  plan", "poke holes in this", "will an engineer know what to build", "plan readiness",
  or "sign this off"; or hands over planning artefacts and asks whether work can start.
  Use it even when they only say "have a look at this spec". If working code already
  exists and the question is whether it ships, use production-readiness-review instead;
  run this one first when both a plan and code are in play.
---

# Plan readiness review

One question decides everything here: **could a competent senior engineer who was not in
any of the meetings implement this correctly, without inventing anything?** Every check
below is a way of attacking that question. Anything an implementer would have to decide
for themselves is a gap in the plan, not a detail for later — an implementer's guess is
an unreviewed product decision made by whoever happened to pick up the ticket.

Approving a weak plan is the expensive failure mode. A rejected plan costs a day; an
ambiguous plan that reaches production costs a rewrite. Bias towards NOT READY and say
precisely what would change the verdict.

## Phase 0 — Input contract

Before reading anything in depth, state what is under review. If any of these are unknown
and cannot be inferred, ask once, in one message, then proceed with what is available and
mark the rest as a scope limit in the output.

- Artefacts under review (paths, doc URLs, ticket IDs) and their versions or dates.
- What is explicitly out of scope for this review.
- Target: greenfield, change to an existing system, or integration. For changes, name the
  system being changed — plan quality depends on whether the existing behaviour is pinned.
- Whether code exists yet. If it does, this skill covers the plan only; the code question
  belongs to `production-readiness-review`.
- Who decides the open product questions (name a person, not a team).

Record the exact scope in the output. A review with an unstated denominator is unusable.

## Phase 1 — Requirement inventory

Extract every requirement, acceptance criterion, and implied obligation into a numbered
inventory before judging any of them. Judging as you read produces a review biased towards
whatever the document mentions loudly.

- Stable IDs: `R-001`, `R-002`, … Keep IDs stable across re-runs so a second review shows
  a delta rather than a new list.
- Each row carries a source anchor (`§3.2`, `p4`, `PROJ-123`, line number). No anchor means
  it is inferred, not stated — tag it `[implied]`, and an implied requirement is itself a
  finding.
- Capture obligations hidden in prose ("naturally this is audited", "should be fast") as
  first-class requirements. These are where plans usually fail.
- Include non-functional requirements, migration/backfill steps, and rollout steps as
  requirements. If the plan has none, that absence is a finding, not an empty section.

The count of this inventory is the denominator for every percentage reported later.

## Phase 2 — Per-requirement readiness test

Score each requirement against these seven checks. A requirement is READY only when all
seven pass; otherwise it is a GAP (or UNVERIFIABLE where the answer lives in a system or
document you were not given access to — record what you would need).

1. **Unambiguous** — one reasonable reading. Check against
   `references/ambiguity-patterns.md`; it lists the specific words and shapes that reliably
   produce divergent implementations.
2. **Testable acceptance criteria** — states an observable outcome with a threshold, not an
   intention. "Fast" fails; "p95 < 300 ms at 50 rps on the current dataset" passes.
3. **Data and schema defined** — entities, fields, types, nullability, defaults, retention,
   and where state lives. Include the migration and backfill for existing rows.
4. **Contract defined** — API shape, event schema, or UI states, including auth,
   pagination, idempotency, and versioning where relevant.
5. **Error behaviour defined** — what happens on invalid input, dependency failure,
   timeout, partial write, and concurrent access. "Handle errors gracefully" is a gap.
6. **Non-functional bounds** — load, latency, data volume, concurrency, retention, cost
   limits where the requirement is sensitive to any of them.
7. **Decision ownership** — no requirement leaves a product or architectural choice to the
   implementer. If a choice is deliberately delegated, the plan must say so and name the
   boundaries within which the implementer may choose.

## Phase 3 — Cross-cutting sweeps

Requirement-by-requirement review misses everything that lives between requirements. Run
these sweeps over the plan as a whole:

- **Coherence** — requirements that contradict each other, or contradict the architecture
  section. Quote both sides.
- **Sequencing and dependencies** — work that cannot start until an external team, vendor,
  contract, or data migration lands. Unsequenced dependencies are a delivery risk with a
  schedule cost, so flag them at High even when each requirement is individually clear.
- **Security by design** — trust boundaries crossed, authn/authz per new surface, tenant
  and data isolation, secrets handling, PII classification and retention, audit trail,
  input validation at the boundary, third-party data flow. A plan that never names its
  trust boundaries cannot be implemented securely by accident.
- **Failure and recovery** — what degraded mode looks like, what is retried, what is
  idempotent, what needs a dead-letter path, what a human has to do at 3am.
- **Observability** — for each failure mode the plan anticipates, the signal that would
  reveal it. A failure mode with no signal is undetectable in production.
- **Existing behaviour** — what currently works that this could break: shared tables,
  shared endpoints, consumers of changed contracts, cached data, permissions.
- **Rollout, flags, rollback** — flag defaults, dark launch, back-out path, and whether any
  step is irreversible (schema drops, data deletion, external writes). An irreversible step
  with no back-out plan is Critical.
- **Compliance and regulatory hooks** where the domain implies them (UK GDPR, DORA, NIS2,
  SOC 2, NCSC/NIST guidance). Name the specific obligation, not the framework.

## Phase 4 — Falsification pass

Confirming what a document contains is not review. Run three deliberate attacks and report
what each produced:

1. **Literal implementation** — implement the plan exactly as written, in the laziest
   compliant way. Where does that produce something the author would reject? That gap is
   under-specification.
2. **Two-engineer divergence** — pick the three most consequential requirements and
   describe two defensible, incompatible implementations of each. Any requirement where
   this is easy is not implementation-ready.
3. **Hostile input and abuse** — a malicious authenticated user, a hostile tenant, a
   replayed request, a 100× payload. Which requirement has no answer?

## Severity rubric

Use these definitions rather than intuition, so severities stay comparable across reviews.

| Severity | Definition |
|---|---|
| **Critical** | Would ship a security or data-integrity defect: undefined authz/isolation, undefined data handling for sensitive data, irreversible step with no back-out, or a requirement whose two readings differ in whether data is lost. |
| **High** | Materially unimplementable as written: an implementer must invent a contract, schema, behaviour, or acceptance criterion; contradictory requirements; unsequenced hard dependency; missing failure behaviour on a primary path. |
| **Medium** | Implementable but likely to be got wrong or reworked: vague thresholds, thin edge-case coverage, missing observability, unclear ownership. |
| **Low** | Clarity, structure, naming, or documentation debt. Does not affect what gets built. |

## Output

Use `references/output-template.md` verbatim. Rules that keep the output honest:

- **Every issue**: `Severity → Requirement/area → Evidence (anchor) → Gap → Required fix`.
  The required fix is a concrete edit to the plan ("add response schema and error codes for
  POST /v1/x"), not "clarify this".
- **Never emit a percentage without its counts.** `Plan completeness: 71% (32/45
  requirements READY; 9 GAP, 4 UNVERIFIABLE)`. A percentage with no denominator is an
  invented number.
- Requirements you did not check are UNVERIFIABLE with a reason. Never count them as ready.
- **Unresolved assumptions** get their own register: assumption, why it cannot be derived
  from the plan, the default you would suggest, the owner who must decide, and the cost of
  deciding late. Never resolve a product question by guessing and never quietly change a
  requirement to make the plan coherent — propose the change and mark it as needing a
  decision.
- Verdict rule: **NOT READY if any Critical or High issue is open.** No partial approvals,
  no "ready with caveats". Give the exact list of edits that would flip the verdict.

## Working on the fixes

If asked to fix the plan rather than just review it, work in severity order, one issue at
a time, and rewrite the plan text itself — a review comment is not a fix. After each edit,
re-run Phase 2 on the affected requirements and update the counts. Product decisions stay
in the unresolved register until the named owner answers; do not clear them by writing a
plausible answer into the plan.

Hand off to `production-readiness-review` once code exists.
