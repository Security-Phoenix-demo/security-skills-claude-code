---
description: Generate a STRIDE/DREAD threat model for the repository, a feature, or a component.
argument-hint: "[scope] (e.g. 'full', 'auth-flow', 'src/payments/', or paste an architecture description)"
---

You are running the **Threat Modeling** skill.

## Instructions

1. Load the skill at `skills/Security Assessment/threat-modeling/SKILL.md`.
2. Determine scope from `$ARGUMENTS`: full repo / feature / component / architecture description.
3. Follow the skill's 10-step workflow: scope → architecture extraction → STRIDE analysis → DREAD scoring → attack scenarios → attack tree → mitigations → report.
4. Output sections (in order):
   - **System overview** (components, trust boundaries, data flows)
   - **STRIDE threats** (grouped by category, each with affected components and attack vectors)
   - **DREAD risk scores** (table, sorted by risk)
   - **Attack scenarios** (top 3-5 chained attacks)
   - **Attack tree** (Mermaid diagram)
   - **Mitigations** (preventive / detective / corrective, prioritized by risk)
5. If knowledge graph or CVE intelligence is unavailable, proceed with code-only analysis and note the limitation.

## Scope guard

- Read-only. No code changes.
- This is a **design-time** activity. For diff-level vuln checks use `/security-0day`; for full code sweep use `/security-assessment`.
