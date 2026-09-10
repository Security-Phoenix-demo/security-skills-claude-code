---
name: tm-security-review
description: The COMPREHENSIVE tier. Build (or ingest) a full STRIDE threat model as input, then run a sophisticated whole-repo adversarial zeroday exploit review (triple-pass HUNT -> JUDGE -> VERIFY) that validates the model against the code and proves a runnable PoC per confirmed finding. Composes the threat-modeling + 0day-scanner (deep) skills. Use for "tm security review", a deep exploit-focused review with a threat model, or any agentic/LLM/MCP codebase where design risk outweighs pattern bugs. Ask about deployment/trust context when unclear. For a quick pre-merge diff pass instead, use tm-security-assessment.
---

# TM Security Review  (comprehensive tier)

**Model first, hunt second.** A bare hunt enumerates source→sink flows but never asks *"is this
source actually lower-trust than its sink?"* — so it over-rates operator-controlled inputs (CLI
flags, config, a JAR on the classpath) as HIGH and misses the real design risk (e.g. an
indirect-prompt-injection → auto-exec chain). The threat model supplies that missing trust-direction
check. This skill builds the model, then runs the **sophisticated zeroday exploit hunt against it**.

**This is the deep, comprehensive, whole-repo review with a threat model as input** — the heavier of
the two tiers. When you only need a **quick pass over the changes on a branch/worktree**, use
`tm-quick-security-assessment` instead (and optionally hand its finding surface here for the deep
follow-up).

**It composes two sibling skills:**
- Phase 0 → **`threat-modeling`** (`../threat-modeling/SKILL.md`) — STRIDE/DREAD, DFD, trust boundaries.
- Phases 1-3 → **`0day-scanner`** (`../0day-scanner/SKILL.md`) — the LLM exploit engine, run in `deep` mode, steered by the model's KEY threats. Its on-disk fallback (`security-reviewer/languages/*` + 8-point check) applies when the MCP tool is unreachable.

## When to use
- "threat model security review", "hunt for exploitable vulns with a threat model", "/security-review"
- Agentic / LLM / MCP / connector codebases; whole-repo or pre-merge exploit review
- You need a runnable PoC + evidence chain per finding, not a posture summary

## Inputs (ask; if user is away, default + label `[ASSUMPTION]`)
- **Target**: repo path / service / feature / diff + commit or branch.
- **Existing threat model?** If handed one (e.g. `*-threat-model.md`), **ingest it as Phase 0 — do not regenerate.**
- **Deployment/trust context** (drives severity): self-hosted library vs hosted multi-tenant service; who is the attacker vs the operator; any network-exposed surface (stdio vs HTTP)?

---

## Phase 0 — Threat model  (run the `threat-modeling` skill)
Produce, or ingest, a STRIDE-per-trust-boundary model. Beyond that skill's default output, require:
- **DFD** with every trust-boundary crossing labelled `TBn`, and a `| ID | Boundary | Crosses | Primary risk |` table.
- **Confidence label on every threat**: `[CONFIRMED]` / `[REFUTED]` / `[ASSUMPTION]` / `[QUESTION]`.
- **AI surfaces mapped to OWASP Top 10 for LLM Apps 2025** (LLM01 prompt injection, LLM02 sensitive-info disclosure, LLM05 improper output handling, LLM06 excessive agency, LLM08, LLM10). These design risks are the ones no pattern scanner can test.
- **Severity calibrated to the deployment context** from Inputs.
- Surface the `[QUESTION]`/`[ASSUMPTION]` items that change severity and **ask the user**; if away, take the conservative default and mark it.

### The trust-direction gate (do NOT skip — this is the whole point)
Before any threat keeps a HIGH: **is the source genuinely lower-trust than the sink it reaches?**
- Operator-supplied CLI flags / config / env / a JAR on the classpath = the operator acting on their own system → **not attacker-controlled**. "RCE" that needs you to already run code crosses no boundary. Demote or refute, with the reason recorded.
- A source is only dangerous if a *lower-trust* party controls it (external HTTP content, ingested third-party metadata, an anonymous request, another tenant).
- Refutations are findings too — they stop bad HIGHs shipping and preserve reviewer credibility.

---

## Phase 1 — HUNT (attack-surface map, model-driven)
Take the KEY / High threats that passed the gate. Drive `0day-scanner` (deep mode) plus your own
code reading / grep / graph tracing at each one. Enumerate the concrete **source → sink** path per
threat. Narrate reasoning as you go.

## Phase 2 — JUDGE (classify)
One table, exactly these columns:

`| ID | Vulnerability | File | Line(s) | Severity | Sink |`

IDs `V-01…`; severity `CRITICAL / HIGH / MEDIUM / LOW`. **Apply the trust-direction gate to every
row** — a flow whose source ≥ sink trust is demoted/refuted with a reason, never listed HIGH.

## Phase 3 — VERIFY (prove it)
For each confirmed exploit:
- **Root cause** — why the sink is reachable with genuinely attacker-controlled input.
- **Evidence chain** — the source→sink path, every step cited `[[path:line]]`.
- **PoC** — a concrete, runnable proof (curl / payload / unit snippet) in a fenced block.
- **Compensating-control residual** — residual risk *after* the suggested control.

## Consolidated report
- Findings `V-01…V-N`: severity label, `[[path:line]]` citations, residual rating, PoC.
- **Confirmed-against-model score** (e.g. "12/15 model claims confirmed in code") **with the caveat**: it is an *agreement* score, not an independent check — grading against the model doesn't prove the model's severities are right.
- Cross-cutting positives (`[CONFIRMED]`): parameterized queries, safe deserialisation, correct secret handling — call them out.
- Prioritised remediation: `| Action | Owner/ETA | Trade-off |`. Lead with the real critical (usually the design chain), not the demoted CLI bugs.
- Plain-text headers + markdown tables; no emojis, no Mermaid in the review body.

## Deliverable
Save to `~/security-reviews/<target>-security-review.md` (models & reviews live outside the reviewed
repo; never modify source). State the path. If no Semgrep/OpenGrep pass was run, recommend it as a
**pattern-level backstop** for classic injection/secret/subprocess bugs — not for the LLM-architecture
design risks.
