# Mode 1 — General Documentation

Generate standard engineering documentation for the project.
Every file generated in this mode uses the cross-linking header/footer defined in SKILL.md Step 4.

---

## README.md → `/docs/general/README.md`

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/general/CONTRIBUTING.md, /docs/general/API_REFERENCE.md -->
<!-- Read when: onboarding, local setup, understanding what this project is -->

# [Project Name]

> One-sentence description of what this system does.

## What This Is
[2–3 sentences: problem solved, who uses it, what it owns]

## Prerequisites
[Runtime versions, env vars required, external dependencies]

## Quick Start
[Minimal steps to run locally — no fluff]

## Architecture
[Brief plain-English description + Mermaid diagram]

## Key Modules
| Module | Path | Purpose |
|--------|------|---------|

## Configuration
[All env vars with types, defaults, and descriptions]

## Running Tests
[Exact commands — unit, integration, contract]

## Deployment
[How this gets to production — CI/CD, infra, platform]

## Contributing
[Link to CONTRIBUTING.md]

## Known Issues / Limitations
[Be honest — what doesn't work or is fragile]
```

Rules:
- Detect the actual stack and write version-specific instructions
- Every command must be copy-pasteable and working
- If there's a `.env.example`, document every variable

---

## CONTRIBUTING.md

```markdown
# Contributing

## Development Setup
[Step-by-step — venv, npm install, docker-compose, etc.]

## Branching Strategy
[main/dev/feature — whatever the repo uses]

## Commit Convention
[Detected or recommend: Conventional Commits]

## Pull Request Process
[Review requirements, CI gates, merge policy]

## Running the Test Suite
[Full test command breakdown]

## Code Style
[Linter, formatter, pre-commit hooks if present]

## Architecture Decision Records
[If ADRs exist, link them. If not, note the gap.]
```

---

## API_REFERENCE.md

For each detected endpoint:

```markdown
## [METHOD] /path/to/endpoint

**Purpose:** What this endpoint does

**Auth:** Required / Optional / None — mechanism

**Request:**
\`\`\`json
{
  "field": "type — description"
}
\`\`\`

**Response (200):**
\`\`\`json
{
  "field": "type — description"
}
\`\`\`

**Error Codes:**
| Code | Meaning |
|------|---------|
| 400  | ... |
| 401  | ... |
| 404  | ... |

**Notes:** Rate limits, caching, side effects
```

Rules:
- Document every route found in scan
- Include auth mechanism per route (not just "auth required")
- If response schema is from an AI output, note it explicitly

---

## MODULES.md

For each major module/service:

```markdown
## [Module Name]

**Path:** /services/[name]
**Purpose:** What this module is responsible for
**Owns:** List of entities/functions this module controls
**Does NOT own:** What it delegates elsewhere

**Inputs:** What it receives (events, API calls, messages)
**Outputs:** What it produces (DB writes, events, API responses)

**Change Risk:** Low / Medium / High
**Why:** [Explain what breaks downstream if this changes]

**Key Files:**
- `main_file.py` — [one-liner purpose]
- `helpers.py` — [one-liner purpose]

**Dependencies:**
- Internal: [other modules it calls]
- External: [third-party APIs, services]
```

---

## ARCHITECTURE_OVERVIEW.md

```markdown
# Architecture Overview

## Style
[Monolith / Modular Monolith / Microservice / Event-Driven / Agent-Based / Hybrid]

## Component Map

\`\`\`mermaid
graph TD
  [detected components with real names]
\`\`\`

## Data Flow

\`\`\`mermaid
sequenceDiagram
  [key flows with real service names]
\`\`\`

## Infrastructure
[Cloud provider, compute, storage, message broker, CDN]

## External Dependencies
| Service | Purpose | Failure Impact |
|---------|---------|----------------|

## Single Points of Failure
[Honest assessment]
```

---

## CHANGELOG.md

If no changelog exists, create a template:

```markdown
# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased]

### Added
### Changed
### Fixed
### Removed

## [x.y.z] — YYYY-MM-DD
...
```

If git history is accessible, extract recent meaningful commits and populate.

---

## ADR_TEMPLATE.md

```markdown
# ADR-[NNN]: [Short Decision Title]

**Date:** YYYY-MM-DD
**Status:** Proposed / Accepted / Deprecated / Superseded

## Context
[What situation forced this decision]

## Decision
[What was decided — be direct]

## Consequences
[What gets easier, what gets harder, what risks this introduces]

## Alternatives Considered
| Option | Why Rejected |
|--------|-------------|
```

If ADRs already exist in the repo, document their pattern.
If none exist, note in the Completion Report that ADRs are absent and recommend introducing them.
