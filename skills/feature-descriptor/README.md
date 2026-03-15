# Feature Descriptor Pipeline

A multi-stage pipeline of 12 specialized skills that collaboratively generate security-aware feature specifications and product requirements documents.

![Shift Security Left at the PRD Stage](../../images/prd-pipeline.jpg)

## What It Does

The Feature Descriptor pipeline implements a 10-role specification process orchestrated by a pipeline navigator and an orchestrator skill. Each role in the chain handles a distinct aspect of feature specification: gathering context, cutting scope, distilling constraints, engineering requirements, hunting ambiguities, analyzing security implications, defining API contracts, building verification matrices, planning delivery batches, and performing a final ship/no-ship gate review.

Each `.skill` file is a binary ZIP archive containing a `SKILL.md` that defines the role's inputs, outputs, token budget, and handoff protocol. The pipeline navigator (OVERARCHING) coordinates the execution order and data flow between roles, while the orchestrator manages the end-to-end session. The output is a complete, security-focused feature specification with RFC 2119 requirement levels, STRIDE threat models, verification proof paths, and incremental delivery batches.

This pipeline is designed for teams that need rigorous, security-first feature planning with traceable requirements from problem statement through to implementation plan.

## Files

| File | Purpose |
|------|---------|
| `pipeline-navigator.skill` | Pipeline navigator that coordinates execution order across all roles |
| `orchestrator.skill` | End-to-end session orchestrator |
| `context-curator.skill` | Role 01: Extracts facts, decisions, and open questions from input |
| `ambiguity-hunter.skill` | Role 02: Identifies and flags critical ambiguities |
| `requirements-engineer.skill` | Role 03: Produces normative requirements with RFC 2119 levels |
| `security-engineer.skill` | Role 04: Generates security requirements and threat models |
| `contract-architect.skill` | Role 05: Defines API contracts, events, and error taxonomies |
| `constraint-distiller.skill` | Role 06: Distills testable acceptance criteria |
| `scope-cutter.skill` | Role 07: Defines goals, non-goals, and in/out boundaries |
| `verification-matrix.skill` | Role 08: Ensures every MUST requirement has a proof path |
| `batch-planner.skill` | Role 09: Creates incremental, verifiable delivery batches |
| `final-gate.skill` | Role 10: Ship/no-ship decision with blocker list |

## Installation

Each `.skill` file is a ZIP archive. To inspect or modify:

```bash
# Unzip any skill to view its SKILL.md
unzip context-curator.skill -d context-curator/
cat context-curator/SKILL.md
```

To use the full pipeline, install all skill files into your Claude Code skills directory or load them as project knowledge.

## Usage

Invoke the pipeline by describing a feature you want to specify:

```
Generate a security-aware feature spec for: [your feature description]
```

The pipeline navigator will automatically route through all 10 roles in sequence, producing a complete specification document.

## Requirements

- Claude Code or Claude.ai with skill support
- All 12 `.skill` files must be available in the same directory or installed in the skills path
