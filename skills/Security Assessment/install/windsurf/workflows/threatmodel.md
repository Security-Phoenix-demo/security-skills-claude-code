---
description: Generate a STRIDE/DREAD threat model for the repo, a feature, or a component.
---

# Threat Model (Windsurf Workflow)

Run the threat-modeling skill at `skills/Security Assessment/threat-modeling/SKILL.md`.

## Steps

1. Determine scope: full repo / feature / component / architecture description.
2. Extract architecture (components, trust boundaries, data flows, entry points, tech stack, external deps).
3. Generate STRIDE threats (Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege).
4. Score each threat with DREAD (Damage, Reproducibility, Exploitability, Affected Users, Discoverability) → Risk Score and Risk Level.
5. Synthesize top 3–5 attack scenarios chained from threats + known CVE patterns.
6. Generate an attack tree (Mermaid diagram).
7. Propose mitigations: preventive / detective / corrective, prioritized by risk.

Read-only — no code changes.
