---
name: prd-generator
description: >
  Generate a full Phoenix Security PRD (Product Requirements Document) from a plain-language
  feature description. Use this skill whenever someone wants to create a PRD, product spec,
  feature spec, requirements document, or says things like "write a PRD for", "create a spec for",
  "plan this feature", "document this feature", or "I need a requirements doc".
  The skill produces: (1) a structured PRD in Phoenix Security template format,
  (2) a Confluence page pushed to the SPM space via Atlassian MCP (called directly),
  (3) a cursor-compatible .md plan file for .cursor/plans/,
  (4) a downloadable formatted markdown,
  (5) optionally: Linear/Asana tasks from the batch plan, Slack notification to stakeholders,
  Notion page mirror. Always use this skill for PRD and feature planning tasks.
compatibility:
  mcp_connectors:
    - Atlassian   # Confluence page creation — PRIMARY (always attempt)
    - Slack        # Stakeholder notification — OPTIONAL
    - Linear       # Batch → tickets — OPTIONAL
    - Asana        # Batch → tasks — OPTIONAL
    - Notion       # Mirror doc — OPTIONAL
    - Gmail        # Send PRD to stakeholders — OPTIONAL
  tools:
    - present_files
    - create_file
    - bash_tool
---

# PRD Generator — Phoenix Security

## What This Skill Does

Takes a feature description → runs the 10-role spec pipeline → produces all outputs.
**Connectors are called directly by Claude — no separate user action required.**

| Output | Connector / Tool |
|--------|-----------------|
| Full PRD Markdown | `create_file` + `present_files` |
| `.cursor/plans/` file | `create_file` + `present_files` |
| Confluence page in SPM space | `Atlassian:createConfluencePage` (called directly) |
| Linear issues from batch plan | `Linear` MCP (if user confirms) |
| Asana tasks from batch plan | `Asana` MCP (if user confirms) |
| Slack notification | `Slack:slack_send_message` (if channel provided) |
| Notion mirror | `Notion:notion-create-pages` (if user confirms) |
| Email to stakeholders | `Gmail:gmail_create_draft` (if user confirms) |

---

## Execution Steps

### Step 1 — Extract Intent

From the user's description, extract:
- **Feature name** → becomes `PROJECT-NAME` in the Confluence title
- **Problem statement** — why this exists
- **Key stakeholders** — who asked, who owns (default: @Francesco Cipollone / @Alfonso Eusebio)
- **Rough scope** — what's in / out
- **Which connectors to activate** — infer from context; see heuristics at bottom

Ask **at most one clarifying question** if critical info is missing. Then proceed.

---

### Step 2 — Run the Spec Pipeline (Roles 01–10, inline)

Execute each role mentally. Chain outputs:

| Role | Output | Token Budget |
|------|--------|-------------|
| 01 Context Curator | CLEAN_CONTEXT: facts, decisions, open Qs | ≤900 |
| 02 Scope Cutter | SCOPE_DEFINITION: goals, non-goals, in/out | ≤800 |
| 03 Constraint Distiller | ACTIVE_SET: 8–15 testable ACs | ≤700 |
| 04 Requirements Engineer | NORMATIVE_REQUIREMENTS: RFC-2119, IDs, P0/P1/P2 | ≤1500 |
| 05 Ambiguity Hunter | CLARIFICATIONS: flag critical ambiguities; loop back to 04 if needed (max 3x) | ≤1000 |
| 06 Security Engineer | SECURITY_REQUIREMENTS + THREAT_MODEL | ≤1200 |
| 07 Contract Architect | CONTRACTS: APIs, events, error taxonomy | ≤1200 |
| 08 Verification Matrix | every MUST has a proof path | ≤1000 |
| 09 Batch Planner | BATCH_PLAN: incremental, verifiable batches | ≤1200 |
| 10 Final Gate | SHIP / NO_SHIP + blocker list | ≤800 |

---

### Step 3 — Render PRD

Produce the full document using the Phoenix Security template (see end of this file).

---

### Step 4 — Write Files

```
outputs/{feature-slug}-PRD.md          ← full PRD document
outputs/{feature-slug}-cursor-plan.md  ← .cursor/plans format
```

Use `create_file` for both, then call `present_files` with both paths.

---

### Step 5 — Confluence Push (ALWAYS attempt)

Call tools in this exact order:

**5a. Get cloud ID**
```
tool: Atlassian:getAccessibleAtlassianResources
→ capture cloudId from response
```

**5b. Find parent page**
```
tool: Atlassian:searchConfluenceUsingCql
  cql: title = "TEMPLATE PRD" AND space = "SPM"
→ capture page ID from first result
  fallback parent ID if search returns nothing: 1273987073
```

**5c. Create the PRD page**
```
tool: Atlassian:createConfluencePage
  cloudId: {from 5a}
  spaceKey: SPM
  title: "{PROJECT-NAME} — {Feature Name}"
  parentId: {from 5b}
  body: {full PRD markdown content}
```

Report the resulting page URL to the user. If any step fails, note why and deliver files anyway.

---

### Step 6 — Optional Connectors

Activate based on user intent (see heuristics at bottom). Ask once after Confluence push:
> "Want me to also create Linear/Asana tickets, post to Slack, or email the spec?"

#### 6a. Linear — issues from batch plan
```
tool: Linear (search or create project matching feature name)
For each BATCH in BATCH_PLAN:
  create issue:
    title: "{BATCH_ID} — {batch goal}"
    description: steps + validation criterion + requirements covered
    priority: P0 batches → urgent | P1 → medium | P2 → low
```

#### 6b. Asana — tasks from batch plan
```
tool: Asana (find or create project "{PROJECT-NAME}")
For each BATCH:
  create task:
    name: "{BATCH_ID} — {batch goal}"
    notes: steps + validation + requirements
    assignee: infer from stakeholders or leave unassigned
```

#### 6c. Slack — notify stakeholders
```
tool: Slack:slack_search_channels → find #{channel}
tool: Slack:slack_send_message
  channel: #{channel}
  text: |
    📋 *New PRD: {Feature Name}*
    Status: DRAFT | Owner: @Francesco Cipollone
    Confluence: {page URL from Step 5}
    _{2-sentence summary}_
    Batches: {N} | P0 requirements: {count}
    Reply to request changes.
```

#### 6d. Notion — mirror page
```
tool: Notion:notion-search → find "Product Features" page or space root
tool: Notion:notion-create-pages
  parent: {found page}
  title: "{PROJECT-NAME} — {Feature Name}"
  content: full PRD markdown
```

#### 6e. Gmail — draft to stakeholders
```
tool: Gmail:gmail_create_draft
  subject: "[PRD DRAFT] {Feature Name} — Phoenix Security"
  body: executive summary + Confluence link + P0 requirements list
  (to: leave blank unless user provides emails)
```

---

## Phoenix Security PRD Template

```markdown
# {FEATURE_NAME}

**Owner:** @Francesco Cipollone / @Alfonso Eusebio
**Status:** DRAFT
**Information Classification:** INTERNAL *NDA SHARE*
**Date:** {ISO_DATE}
**Version:** 1.0

---

## Interested Parties
- @Alfonso Eusebio
- {other stakeholders}

---

## Classification Reference

| TAG | Action | Sharing |
|-----|--------|---------|
| N/A | To be classified | No — only who has access |
| PUBLIC | Public information | Can be shared externally |
| INTERNAL | Internal knowledge | Internal + external under NDA with password protection |
| CONFIDENTIAL | Confidential | No sharing |

| Status TAG | When | Action |
|-----------|------|--------|
| N/A | Default | No particular state |
| APPROVED Vx | Reviewed + approved by senior SP/SPD team | Approved version |
| DRAFT | Work in progress | Draft document |
| BRAINSTORM | Info not reliable yet | In progress, not done |
| DISREGARD | Obsolete | Archived |

---

## 0) Overview

{problem_statement}

### Context
{clean_context summary — FACTS + DECISIONS from Role 01}

### Goals
{goals — from Role 02 Scope Cutter}

### Non-Goals
{non_goals — from Role 02 Scope Cutter}

---

## Features

### FEATURE 1 — {name}

**Objective:** {one-line}

#### Functional Logic
{R-FUNC-* requirements with IDs, priority tags, maps_to AC#}

#### UI / UX Changes *(if applicable)*
{R-UX-* requirements}

#### Data Model Changes *(if applicable)*
{field names, types, constraints, migration notes}

#### Export Requirements *(if applicable)*
{formats: CSV / PNG / PDF; fields included; filter state preservation}

#### Open Questions
1. {question}

---

{repeat FEATURE block for each logical grouping from normative requirements}

---

## Security Requirements

### Threat Model
- **Assets:** {list}
- **Actors:** {list}
- **Entry Points:** {list}
- **Trust Boundaries:** {list}
- **High-Risk Flows:** {list}

### Security Requirements
{R-SEC-* with IDs, [P0/P1], proof_hint: test|static|contract|manual}

### Abuse Cases *(only if they produce new requirements)*
{AC-SEC-* items}

---

## API Contracts

{API-001, EVT-001 definitions from Role 07 Contract Architect}

---

## Verification Matrix

| Requirement ID | Level | Proof Type | Proof Artifact | Notes |
|---|---|---|---|---|
| R-FUNC-001 | MUST | test | test_{name} | |
| R-SEC-001 | MUST | static | rule_{name} | |

---

## Delivery Plan

### BATCH 1 — {name}
- **Goal:** {goal}
- **Covers:** R-FUNC-001, R-SEC-001
- **Steps:**
  1. {step}
- **Validation:** {done-when criterion from verification matrix}
- **Risks/Rollback:** {risk + rollback strategy}

{repeat per batch}

---

## Data & Performance Considerations
{NFRs: volume thresholds, precomputation requirements, caching strategy, timezone handling}

---

## Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| {risk} | {mitigation} |

---

## Open Clarification Summary

1. {Q1}
2. {Q2}

---

## References
- Baseline spec: {reference doc or "N/A"}
- Confluence: {page URL from Step 5}
```

---

## Cursor Plans Format

Save as `outputs/{slug}-cursor-plan.md`. User drops into `.cursor/plans/`:

```markdown
# Plan: {Feature Name}
Date: {ISO date}
Status: DRAFT

## Objective
{one paragraph}

## Implementation Batches

### Batch 1 — {name}
**Files to touch:** {list or TBD}
**Requirements:** R-FUNC-001, R-SEC-001
**Steps:**
1. {step}
**Done when:** {validation criterion}

### Batch 2 — ...

## P0 Requirements
- R-FUNC-001 [P0] MUST ...
- R-SEC-001 [P0] MUST ...

## Open Questions (resolve before implementation)
- Q1: ...
```

---

## Output Format Rules

- RFC 2119 throughout: MUST / MUST NOT / SHOULD / MAY
- Requirement IDs: R-FUNC-001, R-SEC-001, R-REL-001, R-UX-001
- Priority tags: [P0] critical path / [P1] important / [P2] nice-to-have
- `maps_to: AC#` on every functional requirement
- No invented facts — unknowns surface as open questions
- Max 40 total requirements across all sections
- Every MUST has a proof path in the verification matrix

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Description too vague | Ask one question, proceed with flagged assumptions |
| Atlassian MCP auth fails | Deliver files only, log error clearly |
| Linear/Asana project not found | Create new project, report name to user |
| Slack channel not found | Ask user for correct channel name |
| >10 open questions from pipeline | Surface top 5 blockers, park rest as low-priority |
| Contradictions in requirements | Flag in CLARIFICATIONS, do NOT auto-resolve |
| Final Gate = NO_SHIP | List blockers explicitly, still produce all files, mark PRD status BLOCKED |

---

## Connector Activation Heuristics

Activate connectors proactively based on these signals in the user's message:

| Signal | Connector |
|--------|-----------|
| "create tickets", "add to Linear" | Linear |
| "add to Asana", "create tasks" | Asana |
| "notify the team", "post to Slack", channel name mentioned | Slack |
| "send to", "email the spec", email address mentioned | Gmail |
| "add to Notion" | Notion |
| any PRD request | Atlassian (always) |

Default if no signals: **Atlassian + files only**.
After Confluence push, ask once: *"Want me to also create Linear tickets, notify Slack, or email stakeholders?"*
