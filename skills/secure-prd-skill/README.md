# Secure PRD Generator Skill

Generate security-focused Product Requirements Documents (PRDs) from plain-language feature descriptions, with integrated STRIDE threat modeling and multi-platform publishing.

![Shift Security Left at the PRD Stage](../../images/prd-pipeline.jpg)

## What It Does

This skill takes a feature description and runs it through a 10-role specification pipeline to produce a comprehensive PRD with security considerations built in from the start. The roles execute in sequence: Context Curator, Scope Cutter, Constraint Distiller, Requirements Engineer, Ambiguity Hunter, Security Engineer, Contract Architect, Verification Matrix, Batch Planner, and Final Gate. Each role has a defined token budget and produces structured output that feeds into the next stage.

The Security Engineer role generates STRIDE threat models, identifies assets, actors, entry points, and trust boundaries, and produces security requirements with proof hints. The Verification Matrix ensures every MUST-level requirement has a traceable proof path (test, static analysis, contract, or manual). The Batch Planner creates incremental delivery batches with validation criteria and rollback strategies.

The skill integrates with multiple platforms for publishing and notification. It always attempts to push the PRD to Confluence via the Atlassian MCP connector, and optionally creates Linear or Asana tickets from the batch plan, sends Slack notifications to stakeholders, mirrors the document to Notion, or drafts emails via Gmail. All outputs follow RFC 2119 requirement levels with structured IDs (R-FUNC-001, R-SEC-001) and priority tags (P0/P1/P2).

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Complete skill definition including the 10-role pipeline spec, PRD template, Cursor plans format, connector activation heuristics, and error handling |

## Installation

Install as a Claude Code skill or load as project knowledge:

```bash
# For Claude Code
cp -r secure-prd-skill/ ~/.claude/skills/
```

Configure on first use or via environment variables:

```bash
export PRD_OWNER="@your-name"
export PRD_STAKEHOLDERS="@stakeholder1, @stakeholder2"
export PRD_CONFLUENCE_SPACE="YOUR_SPACE_KEY"
export PRD_SLACK_CHANNEL="#your-channel"
```

## Usage

```
Write a PRD for [feature description]
Create a security-focused spec for [feature]
Plan this feature: [description]. Owner: @jane. Space: ENG. Notify #product-specs.
```

The skill produces:
- Full PRD markdown document (`outputs/{feature-slug}-PRD.md`)
- Cursor-compatible plan file (`outputs/{feature-slug}-cursor-plan.md`)
- Confluence page in your configured space
- Optional: Linear/Asana tickets, Slack notification, Notion mirror, Gmail draft

## Requirements

- Claude Code or Claude.ai with skill support
- Atlassian MCP connector configured for Confluence publishing (primary output)
- Optional MCP connectors: Slack, Linear, Asana, Notion, Gmail
- See also: [`plugins/secure-prd/`](../../plugins/secure-prd/) for the Claude.ai web UI plugin version
