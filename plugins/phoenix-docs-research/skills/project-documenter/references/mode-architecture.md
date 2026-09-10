# Mode 3 — Architecture Documentation

Generates five focused architecture sub-documents.
Each covers one concern. None duplicates another.
All cross-link to CLAUDE.md and each other.

---

## File: SYSTEM_OVERVIEW.md → `/docs/architecture/SYSTEM_OVERVIEW.md`

The single most important architecture document.
Goal: a new senior engineer understands the system in 15 minutes.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/architecture/RUNTIME_FLOWS.md, /docs/architecture/REPOSITORY_MAP.md -->
<!-- Read when: onboarding, architectural decisions, understanding component relationships -->

# System Overview

**Scope:** What this system is, how it is organized, and how its components relate.
Out of scope: runtime flows (→ RUNTIME_FLOWS.md), module-level detail (→ MODULES.md).

---

## System Identity

**Project:** [name]
**Purpose:** [2–3 sentences: what problem it solves, who uses it]
**Engineering Reality:** [what this repo is *actually* responsible for, stripped of marketing]

---

## Architecture Style

[Monolith / Modular Monolith / Microservice / Event-Driven / Agent-Based / Hybrid]

Explain *why* this style was chosen or evolved to, if evident from the codebase.

---

## Component Map

High-fidelity diagram of all major components and how they connect.
Use real names from the scan — not generic placeholders.

\`\`\`mermaid
graph TD
  Client["Client / Consumer"]
  API["API Layer\n/api"]
  Services["Service Layer\n/services"]
  DB[("Database")]
  Queue["Message Queue"]
  AIOrch["AI Orchestrator\n/ai/orchestrator"]
  LLM["LLM API\n(Anthropic / OpenAI)"]
  Validator["Output Validator\n/ai/validation"]

  Client --> API
  API --> Services
  Services --> DB
  Services --> Queue
  Services --> AIOrch
  AIOrch --> LLM
  LLM --> Validator
  Validator --> DB
\`\`\`

---

## Repository Ownership

**This repo owns:**
- [capability 1 — specific, not generic]
- [capability 2]

**This repo does NOT own:**
- [external system]
- [shared platform concern]

---

## Major Components

For each component detected in the scan:

| Component | Path | Purpose | Owned By |
|-----------|------|---------|---------|
| [name] | /path | [what it does] | [team/owner if known] |

For each **High change-risk** component — explain what breaks downstream if it changes.

---

## External Dependencies

| Service | Purpose | Failure Impact | Auth Method |
|---------|---------|----------------|-------------|
| Anthropic API | LLM inference | AI features degrade | API key |
| PostgreSQL | Primary persistence | Total outage | Connection string |
| [service] | [purpose] | [impact] | [method] |

---

## Infrastructure

- Cloud: [AWS / GCP / Azure / on-prem]
- Compute: [ECS / k8s / Lambda / VMs]
- Storage: [RDS / S3 / GCS / Redis]
- Broker: [SQS / Pub/Sub / Kafka / RabbitMQ / none]
- CDN/Edge: [CloudFront / none]

---

## Security Model Summary

High-level security posture. Detail lives in MODEL_GUARDRAILS.md and API_REFERENCE.md.

- Auth mechanism: [JWT / OAuth2 / API key / session]
- Multi-tenancy: [yes — isolation strategy / no]
- Data in transit: [TLS everywhere / partial]
- Data at rest: [encrypted / not encrypted]
- AI data privacy: [what is sent to external models]

---

## Known Gaps / Uncertainties

- [anything inferred rather than confirmed]
- [architecture questions that remain open]
```

---

## File: REPOSITORY_MAP.md → `/docs/architecture/REPOSITORY_MAP.md`

A navigational guide to the codebase — which modules matter, what they own, and where to start.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/architecture/SYSTEM_OVERVIEW.md, /docs/general/MODULES.md -->
<!-- Read when: before editing any module, onboarding, change-risk assessment -->

# Repository Map

**Scope:** Module inventory, change-risk classification, safe vs. high-risk zones, reading order.
Out of scope: runtime flows (→ RUNTIME_FLOWS.md), external services (→ DEPENDENCY_MAP.md).

---

## Top-Level Structure

\`\`\`
/
├── [entry point]       — [what it does]
├── /api/               — [what it owns]
├── /services/          — [what it owns]
├── /ai/
│   ├── /prompts/       — prompt templates — HIGH RISK: consumers depend on output schema
│   ├── /orchestrator/  — LLM invocation + retry — HIGH RISK
│   └── /validation/    — response parsing + schema enforcement
├── /models/            — data contracts — HIGH RISK: rename = migration required
├── /tests/             — unit + integration + prompt tests
└── /infra/             — deployment config
\`\`\`

Do not list every file. List every folder that has meaningful ownership or risk.

---

## Module Ownership Table

| Module | Path | Purpose | Change Risk | Why High Risk (if applicable) |
|--------|------|---------|-------------|-------------------------------|
| API Layer | /api | Routes + request handling | Medium | |
| Service Layer | /services | Core business logic | High | Central orchestration — changes fan out |
| AI Prompts | /ai/prompts | Prompt templates | High | Output schema consumed by /services/X |
| LLM Orchestrator | /ai/orchestrator | Model calls + retry | High | Silent failures if retry logic breaks |
| Response Validator | /ai/validation | Schema enforcement | High | Downstream consumers trust this output |
| Data Models | /models | Shared contracts | High | Rename = migration + consumer updates |

---

## Safe Change Zones

Safe to modify without cross-team check:
- UI copy and labels
- Log message wording
- Isolated prompt wording (with prompt tests passing)
- Internal helpers with no downstream schema dependency
- Test fixtures

---

## High-Risk Zones

Require explicit blast-radius assessment before merging:

| Zone | Path | Risk | What Breaks |
|------|------|------|-------------|
| AI output schemas | /ai/validation | High | JSON parser in /services/X fails silently |
| Auth middleware | /api/middleware/auth | High | All routes affected |
| Data model fields | /models | High | DB queries + downstream consumers |
| Orchestrator retry logic | /ai/orchestrator | High | Duplicate requests or silent failures |

---

## Where to Start Reading

For a new engineer, read in this order:
1. `/CLAUDE.md`
2. `/docs/architecture/SYSTEM_OVERVIEW.md`
3. `/docs/general/README.md` — run it locally
4. `/[core service entry point]`
5. `/ai/orchestrator/`
6. `/ai/prompts/`
7. `/models/`
8. `/api/`

Do NOT start with: generated code, migrations, test snapshots, vendor/node_modules,
large utility files unless referenced by a critical flow.

---

## Change Playbook

When modifying this repo:
1. Identify the affected execution flow (→ RUNTIME_FLOWS.md)
2. Identify affected modules (this file)
3. Identify schema contracts (→ DATA_CONTRACTS.md)
4. Identify AI touchpoints (→ PROMPTS.md)
5. Update docs before merge
6. Update tests
7. Verify fallback behavior if AI is involved
8. Check logs and observability coverage

---

## Known Gaps / Uncertainties

- [unclear module ownership]
- [inferred change risks that could not be confirmed from code]
```

---

## File: RUNTIME_FLOWS.md → `/docs/architecture/RUNTIME_FLOWS.md`

End-to-end execution traces for the most important flows.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/architecture/SYSTEM_OVERVIEW.md, /docs/architecture/DEPENDENCY_MAP.md -->
<!-- Read when: tracing a request, debugging a flow, understanding what happens when X occurs -->

# Runtime Flows

**Scope:** Step-by-step execution traces for critical paths. Failure impacts per flow.
Out of scope: module-level internals (→ REPOSITORY_MAP.md), external service details (→ DEPENDENCY_MAP.md).

---

## Flow 1: [Name — e.g., Vulnerability Ingestion and Enrichment]

**Trigger:** [what starts this flow]
**Owner:** [team / service responsible]
**SLA / latency expectation:** [if known]

**Steps:**
1. [What arrives + how]
2. [Normalization / transformation]
3. [Business logic applied]
4. [AI enrichment — prompt built, model invoked]
5. [Output validated]
6. [Persisted / returned]

\`\`\`mermaid
sequenceDiagram
  participant Client
  participant API
  participant Service
  participant AIOrch as AI Orchestrator
  participant LLM
  participant DB

  Client->>API: POST /[endpoint] {payload}
  API->>Service: normalize(payload)
  Service->>AIOrch: enrich(record)
  AIOrch->>LLM: prompt(context)
  LLM-->>AIOrch: structured JSON
  AIOrch->>AIOrch: validate(response)
  AIOrch->>DB: persist(enrichedRecord)
  DB-->>Service: ok
  Service-->>API: enrichedRecord
  API-->>Client: 200 {result}
\`\`\`

**Failure impact:** [what users or systems see if this flow fails at each step]

**Retry behavior:** [retries at which step, with what policy]

---

## Flow 2: [Name — e.g., Remediation Recommendation]

[Same structure]

---

## Flow N: [Name]

[Same structure — document every critical path found in scan]

---

## Background / Async Flows

| Job | Trigger | Path | Output | Failure Behavior |
|-----|---------|------|--------|-----------------|
| [name] | [cron / event] | /path | [what it produces] | [what happens on failure] |

---

## Known Gaps / Uncertainties

- [flows that were inferred, not confirmed by tests or docs]
- [retry policies that are undocumented]
- [failure paths with no observable signal]
```

---

## File: DEPENDENCY_MAP.md → `/docs/architecture/DEPENDENCY_MAP.md`

All internal and external dependencies — what depends on what, and what breaks if it changes.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/architecture/RUNTIME_FLOWS.md, /docs/architecture/DATA_CONTRACTS.md -->
<!-- Read when: changing an integration, assessing blast radius of a dependency change -->

# Dependency Map

**Scope:** Internal module dependencies + external service dependencies + failure cascades.
Out of scope: runtime flow traces (→ RUNTIME_FLOWS.md).

---

## Internal Module Dependencies

\`\`\`mermaid
graph LR
  API --> ServiceA
  API --> ServiceB
  ServiceA --> DB
  ServiceA --> AIOrch[AI Orchestrator]
  AIOrch --> LLM[LLM API]
  ServiceB --> Queue
  Queue --> Worker
  Worker --> DB
\`\`\`

For each high-coupling dependency, explain:
- what breaks if the upstream changes
- whether there is a contract test for this boundary

---

## External Service Dependencies

| Service | Version / API | Used By | Failure Mode | Fallback |
|---------|-------------|---------|-------------|---------|
| Anthropic API | claude-sonnet-4-5 | AI Orchestrator | AI features degrade | deterministic fallback |
| PostgreSQL | 15 | All services | Total outage | none |
| [service] | [version] | [module] | [what degrades] | [fallback strategy] |

---

## Dependency Health

| Service | Health Check | SLA | On-Call Alert |
|---------|-------------|-----|--------------|
| [service] | [endpoint or script] | [99.X%] | [yes/no] |

---

## Known Gaps / Uncertainties

- [dependencies without health checks]
- [external services with undocumented failure behavior]
- [circular internal dependencies if found]
```

---

## File: DATA_CONTRACTS.md → `/docs/architecture/DATA_CONTRACTS.md`

All schemas and data contracts that must not change without a migration or consumer update.

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/architecture/DEPENDENCY_MAP.md, /docs/ai/PROMPTS.md -->
<!-- Read when: changing any data schema, adding fields, deprecating fields -->

# Data Contracts

**Scope:** All critical schemas — API request/response shapes, DB models, event formats,
AI prompt output schemas. Anything consumed by more than one module.
Out of scope: internal-only data structures with no external consumer.

---

## Contract: [SchemaName]

**Produced by:** [module path]
**Consumed by:** [module paths — list all consumers]
**Validation:** [where is this schema validated?]
**Backward compat:** [additive only / breaking allowed with migration / strict]

\`\`\`json
{
  "id": "string — UUID v4",
  "cve": "string — CVE-YYYY-NNNNN format",
  "severity": "string — enum: critical | high | medium | low | informational",
  "mitre_techniques": "string[] — ATT&CK technique IDs, may be empty",
  "exploitability_score": "number — 0.0–10.0",
  "remediation": "string — non-empty",
  "created_at": "string — ISO 8601"
}
\`\`\`

**What breaks if this changes:**
- /services/reporting — reads `mitre_techniques` to generate board reports
- /ai/validation — enforces `severity` enum values
- /api/v1/vulnerabilities — returns this shape in GET response

---

## Contract: [EventSchemaName]

**Event type:** [topic / queue name]
**Producer:** [module]
**Consumers:** [modules]
**Idempotency:** [key field used for deduplication, if any]

\`\`\`json
{
  "event_id": "string — UUID, idempotency key",
  "event_type": "string — enum",
  "payload": { ... },
  "timestamp": "string — ISO 8601"
}
\`\`\`

---

## Schema Evolution Rules

- MUST NOT remove required fields without a versioned migration
- MUST NOT rename fields without updating all consumers
- SHOULD add new fields as optional with defaults
- MUST update /docs/ai/PROMPT_TESTS.md when AI output schemas change
- MUST update consumer contract tests when any schema changes

---

## Known Gaps / Uncertainties

- [schemas that exist in code but have no enforcement]
- [AI output schemas that are assumed but not validated]
- [consumer list that may be incomplete]
```
