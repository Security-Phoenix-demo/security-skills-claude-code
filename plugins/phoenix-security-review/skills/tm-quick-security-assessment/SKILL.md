---
name: tm-quick-security-assessment
description: The QUICK tier. Scope to a git worktree/branch and assess only what changed against a base — a fast, threat-model-aware pre-merge security pass (attack-surface delta + OWASP Top 10 on changed files) with the trust-direction gate applied. Composes the security-assessment + 0day-scanner (light) skills. Use for "quick security assessment on this branch", pre-merge review of a worktree/diff, or a fast posture check. For a comprehensive whole-repo review with a full threat model as input, use tm-security-review.
---

# TM Security Assessment  (quick tier)

**Quick and change-scoped.** This tier does NOT re-model the whole system or hunt the entire repo.
It scopes to a **git worktree / branch**, diffs against a base, and assesses **only the changed
attack surface** — fast enough to run on every branch before merge. It stays *threat-model-aware*:
if a model exists it uses it to prioritise, but it does not build a full one.

**Two tiers, pick by need:**
- **This skill (quick)** — a branch/worktree diff pass; minutes; catches regressions and obvious bugs in what changed.
- **`tm-security-review` (comprehensive)** — full threat model as input + deep whole-repo zeroday hunt with a PoC per finding. Escalate to it when this pass flags a design-level risk or the change touches a trust boundary.

**It composes two sibling skills, scoped to the diff:**
- **`security-assessment`** (`../security-assessment/SKILL.md`) — OWASP Top 10 checks, run only over changed files.
- **`0day-scanner`** (`../0day-scanner/SKILL.md`) in **`light` mode** — it is built for commit/PR/branch/diff analysis; drive it with the branch or diff.

## When to use
- "quick security assessment on this branch/worktree", "pre-merge security check", "scan the diff"
- Fast, cheap, change-scoped — not a full audit

## Inputs (ask; if user is away, default + label `[ASSUMPTION]`)
- **Worktree / branch**: the branch or worktree path to assess. Default: current worktree's checked-out branch.
- **Base**: what to diff against. Default: the repo's default branch (`main`/`master`), else the branch's merge-base.
- **Existing threat model?** Optional. If a `*-threat-model.md` is available, use its trust boundaries to prioritise; do **not** build a new one here (that's the review's job).
- **Deployment/trust context** (drives severity): self-hosted vs hosted multi-tenant; attacker vs operator.

---

## Phase 0 — Establish scope (worktree / branch diff)
1. Resolve the target branch and base. If the branch isn't checked out, create a throwaway worktree:
   `git worktree add <tmp> <branch>` (remove it when done).
2. Compute the changed set: `git diff --name-only <base>...<branch>` (three-dot = changes on the branch since it forked). Note added/modified files and any new entry points, routes, deps, or IaC.
3. **Map the changed surface**: `| Changed file | New/changed entry point or sink | Reaches a trust boundary? |`. Pull trust boundaries from an existing threat model if provided; otherwise infer them quickly from the changed files (new HTTP handler, new subprocess/exec, new query, new deserialization, new external fetch).

## Phase 1 — Quick assessment of the delta
Run the composed engines **only over the changed files**:
- `0day-scanner` light mode on the diff/branch (fast LLM pass for injection, secrets, unsafe exec, weak crypto, etc.).
- `security-assessment` OWASP Top 10 checks scoped to the changed files (+ OWASP-LLM if the change touches an AI/MCP surface).

Present one table:

`| ID | Vulnerability | File | Line | Severity | OWASP |`

Cite evidence `[[path:line]]`.

### The trust-direction gate (do NOT skip)
Before any finding keeps a HIGH: **is the source genuinely lower-trust than the sink it reaches?**
- Operator-supplied CLI flags / config / env / a JAR on the classpath = the operator acting on their own system → **not attacker-controlled**. Demote or refute, with the reason recorded.
- Dangerous only if a *lower-trust* party controls the source (external HTTP content, ingested third-party metadata, an anonymous request, another tenant).

## Phase 2 — Verdict + escalation
- **Merge verdict**: PASS / PASS-WITH-NOTES / BLOCK, with the reason.
- Per finding: severity, `[[path:line]]`, one-line fix.
- **Escalate flag**: if the change touches a trust boundary or a design-level risk (e.g. an LLM/MCP surface, an auth path, a new exec/query sink), recommend a follow-up `tm-security-review` — this quick pass does not prove exploit chains or build the full model.

## Deliverable
For a quick pass, reporting inline in chat is fine. For a durable record, save to
`~/security-reviews/<branch>-quick-assessment.md` (outside the reviewed repo; never modify source).
Always remove any throwaway `git worktree` you created.
