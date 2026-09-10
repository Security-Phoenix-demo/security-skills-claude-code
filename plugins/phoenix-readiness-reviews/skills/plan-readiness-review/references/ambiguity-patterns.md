# Ambiguity patterns

Read this during Phase 2. These are the phrasings that reliably survive plan review and
then produce two engineers building two different things. Each one is a finding when it
appears in a requirement, not a style nit.

## Contents
1. Undefined magnitude
2. Undefined actor and permission
3. Undefined scope of "all"
4. Verbs that hide a design decision
5. Error-handling non-statements
6. Hidden state and timing
7. Unbounded lists
8. Passive voice hiding the owner
9. Rewrites that pass

---

## 1. Undefined magnitude

`fast`, `scalable`, `high volume`, `real time`, `near real time`, `soon`, `large`,
`reasonable`, `acceptable`, `performant`, `lightweight`, `minimal impact`.

Ask: which metric, measured where, at what percentile, under what load, on what data size?
"Real time" in particular means anything from 50 ms to "same business day" depending on
the reader's background.

## 2. Undefined actor and permission

`the user can…`, `admins can…`, `we show…`, `the system allows…`.

Ask: which role, in which tenant, with which permission, seeing whose data? Any
requirement about reading or writing data that does not name the authorisation rule is at
minimum High, and Critical in a multi-tenant system — the implementer will pick whatever
the surrounding code does, which is how tenant leaks get built.

## 3. Undefined scope of "all"

`all records`, `existing data`, `everything is migrated`, `sync all repos`.

Ask: how many rows today, what is the growth rate, does this include soft-deleted and
archived data, what happens to rows that fail validation mid-migration, is it one pass or
continuous, and is it re-runnable?

## 4. Verbs that hide a design decision

`sync`, `integrate`, `support`, `handle`, `manage`, `process`, `enrich`, `normalise`,
`hook up`, `surface`, `wire up`.

Each of these hides direction, trigger, frequency, conflict resolution, and failure
behaviour. "Sync findings from the scanner" leaves open: push or pull, full or
incremental, what wins on conflict, what happens to findings deleted upstream, and whether
the sync is transactional.

## 5. Error-handling non-statements

`handle errors gracefully`, `fail safely`, `retry as needed`, `log and continue`,
`show an error message`, `best effort`.

Ask, per failure: what does the caller receive (status, code, body), what is retried and
with what backoff and cap, is the operation idempotent under retry, what is persisted on
partial failure, what is alerted, and what does the user see? "Log and continue" is a
silent-failure design unless the log line has an alert attached to it.

## 6. Hidden state and timing

`when the job runs`, `once the data is ready`, `after the scan completes`, `eventually
consistent`, `cached`.

Ask: what triggers it, what is the schedule and the timeout, what happens on overlapping
runs, what is the staleness bound, what invalidates the cache, and what does a reader see
during the window?

## 7. Unbounded lists

`e.g.`, `such as`, `including but not limited to`, `and so on`, `similar sources`.

An example list in a requirement is not a requirement. Either the set is enumerated and
closed, or the plan states the rule for membership and how new members are added.

## 8. Passive voice hiding the owner

`will be validated`, `is expected to be configured`, `should be deployed`, `access will be
provisioned`.

Ask: by which component, at which layer, at which time, by whom? Validation "will be
performed" usually means both the client and server assumed the other one was doing it.

---

## 9. Rewrites that pass

Use these as the standard for the "Required fix" column — the fix is the rewritten text.

| Fails | Passes |
|---|---|
| The API should be fast. | `GET /v1/findings` returns p95 < 300 ms at 50 rps against a 10M-row dataset; over budget, the dashboard shows a cached result with its age. |
| Users can export their data. | A user with `export:read` in tenant T can export only tenant T's findings; a request for another tenant returns 404 (not 403) and raises an audit event. |
| Sync findings from the scanner. | Every 15 min, pull findings updated since the stored cursor; upsert on `(source, external_id)`; upstream-deleted findings are marked `resolved_upstream`, never hard-deleted; a run overlapping a previous run is skipped and counted. |
| Handle scanner downtime gracefully. | On 5xx/timeout, retry 3× with exponential backoff (1s/4s/16s, jitter); after that, fail the run, keep the cursor unchanged, emit `sync_failed{source}`, and alert if two consecutive runs fail. |
| Migrate existing findings. | One-shot re-runnable backfill in 1k batches; rows failing validation go to `findings_backfill_errors` with a reason; the job reports processed/failed counts; running it twice produces no duplicates. |
