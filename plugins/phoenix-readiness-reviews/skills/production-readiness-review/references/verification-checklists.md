# Verification checklists

Per-domain checks for Phase 5. Each item states what counts as evidence — a claim without
that evidence is a GAP, not a pass. Read the section relevant to the change; skip the rest.

## Contents
1. Security and authorisation
2. Multi-tenancy and data isolation
3. Reliability and failure paths
4. Concurrency and idempotency
5. Data, schema and migrations
6. Performance
7. Observability
8. Config, deploy, flags, rollback
9. Backwards compatibility
10. Wiring proofs (the "it exists but is dead" traps)

---

## 1. Security and authorisation

- Every new or changed route, job, queue consumer, and admin action has an explicit
  authorisation decision **in code**. Evidence: `path:line` of the check plus a test that
  fails when it is removed. Framework-wide middleware counts only if you can show the new
  route is inside its scope and not on an allow-list.
- Authentication and authorisation are distinct. A logged-in user is not an authorised one.
- Object-level checks, not just endpoint-level: can user A fetch entity B by guessing an
  ID? Evidence: a negative test.
- Input validated at the trust boundary, with types and bounds. Client-side validation is
  not validation.
- Secrets: nothing secret-shaped in the repo, config, or logs; secrets sourced from the
  intended store in every environment; rotation does not require a code change.
- Sensitive data never reaches logs, error responses, analytics, or exception trackers.
- Injection surfaces: parameterised queries, no shelling out with user input, safe
  deserialisation, no HTML injection into a rendered DOM, SSRF controls on any
  user-supplied URL.
- Dependencies: lockfile committed, new deps intentional, known vulnerable versions
  checked, transitive additions reviewed.
- Audit trail for privileged and destructive actions, with actor, target, and timestamp.
- Rate limiting and abuse controls on anything unauthenticated or expensive.

## 2. Multi-tenancy and data isolation

- Every query touching tenant-scoped data filters by tenant at a layer that cannot be
  bypassed, and the filter comes from the session/token, never from the request body.
- Evidence required: a cross-tenant negative test — tenant A requesting tenant B's object
  gets 404, and nothing about B leaks in the error, timing, or metrics labels.
- Caches, background jobs, exports, webhooks, and search indexes are tenant-partitioned.
  Jobs are the usual leak: they often run with elevated context.
- Bulk and admin endpoints have their own isolation tests; they are the usual bypass.

## 3. Reliability and failure paths

- Every outbound call has a connect and read timeout. Evidence: the config, not the intent.
- Retries: bounded, backed off, jittered, and only on retryable errors. A retry on a
  non-idempotent write is a data-integrity bug.
- Partial failure: what is persisted when step 3 of 5 fails, and how the system converges.
  Transaction boundaries visible in the code.
- Failures surface rather than disappear: no empty `catch`, no `except: pass`, no default
  value substituted for a failed dependency unless that degradation is specified and
  signalled.
- Resource limits: bounded queues, bounded batch sizes, bounded in-memory accumulation,
  connection pool sized against expected concurrency.
- Graceful shutdown: in-flight work drains or is safely re-queued.

## 4. Concurrency and idempotency

- Duplicate delivery: replaying the same request or message twice produces one effect.
  Evidence: an idempotency key with a uniqueness constraint, plus a test that submits twice.
- Concurrent writers: optimistic locking, row locks, or a documented last-write-wins that
  someone actually decided.
- Read-modify-write cycles on shared counters or state use atomic operations.
- Scheduled jobs: overlapping runs prevented or safe; a run that dies mid-way is safely
  resumable.

## 5. Data, schema and migrations

- Migration is reversible, or the irreversible step is called out with an explicit
  back-out plan (Critical if neither).
- Migration is safe on production-sized data: no long-held locks, no full-table rewrite
  during peak, batched backfills, and a stated runtime estimate against real row counts.
- Order of operations for a live deploy: add column → deploy code that writes both → backfill
  → switch reads → drop. A single-step destructive migration paired with a code deploy is a
  guaranteed error window.
- Backfill is re-runnable, reports processed/failed counts, and quarantines bad rows.
- New columns: nullability, defaults, and indexes match the query patterns actually used.
- Retention and deletion honour the stated policy, including derived copies and backups.

## 6. Performance

- Query patterns checked against the real query, not the ORM's intent: N+1 loops, missing
  index on the new filter/sort column, unbounded `IN` lists, `SELECT *` on wide tables.
- Every list endpoint is paginated with a bounded page size, and pagination is stable under
  concurrent writes (cursor, not offset, for large sets).
- Payload sizes bounded; large exports streamed rather than materialised.
- The stated latency/throughput target has a measurement, not an opinion. If none was run,
  that is a GAP, sized by risk.

## 7. Observability

- For each failure mode the design anticipates, name the signal that reveals it: metric,
  log with a queryable field, trace span, or alert. A failure with no signal is invisible.
- Errors carry correlation IDs across service boundaries.
- Logs are structured and free of secrets and PII; log volume is bounded on hot paths.
- Alerts have thresholds and an owner; a new alert with no runbook is Medium.
- Health checks distinguish liveness from readiness, and readiness actually reflects
  dependency health.

## 8. Config, deploy, flags, rollback

- Every env var and config key read by the code exists in every target environment.
  Evidence: the deploy manifest or secrets store, not `.env.example` alone.
- Defaults are safe when a value is missing: fail fast at boot rather than serving a
  degraded path silently.
- Feature flag defaults are stated, and the off path is tested — the off path is the one
  that runs in production first.
- Rollback: redeploying the previous version works with the new schema and new data.
  Anything that breaks this is Critical unless a forward-fix plan is documented.
- Deploy order between services is stated where it matters.

## 9. Backwards compatibility

- API: no removed field, narrowed type, changed enum meaning, or newly required parameter
  on a version already consumed. Deprecations have a stated window.
- Events and messages: old consumers tolerate the new payload; in-flight messages in the
  old shape are still handled.
- Persisted data: code can read rows written by the previous version, and vice versa
  during rollout.
- Clients you do not control (mobile, partner integrations) get their own row in the
  analysis; they cannot be redeployed with you.

## 10. Wiring proofs — the "it exists but is dead" traps

Check each of these explicitly; they are how a review passes code that never runs:

- Route defined but not registered on the router/app that is actually served.
- Handler registered but shadowed by an earlier matching route.
- Service method implemented with no caller (`rg -n "method_name" --type <lang>` → one hit,
  its own definition).
- Job written but not scheduled, or scheduled only in a config that the target environment
  does not load.
- Event published with no subscriber, or subscriber not deployed.
- Feature-flag-gated code where the flag does not exist in the target environment.
- UI component built but not routed, or rendered behind a permission nobody has.
- Migration file present but not in the migration chain / not applied by the deploy step.
- Config key read in code, absent in the environment, with a silent default masking it.
- New dependency imported but not in the lockfile or the runtime image.
