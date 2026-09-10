# Phoenix Security — Brand System & NotebookLM Prompts

## Color Palette

### Primary Gradient (technical backgrounds, diagrams)
| Name | Hex | Usage |
|------|-----|-------|
| Deep Purple | #6714CC | Gradient start |
| Indigo | #380886 | Gradient mid |
| Azure | #245EE9 | Gradient end |

Direction: top-left → bottom-right

### Background Variants
| Name | Hex | Usage |
|------|-----|-------|
| Nightfall Spectrum | #030331 | Dark technical slides |
| Indigo Blue Blend | #380886 | Mid-tone backgrounds |
| Neutral Dark | #1E2535 | Code slides, diagrams |
| Neutral White | #FFFFFF | Remediation tables, patch matrices |

### Accent (exploit highlights ONLY — max 2 elements per visual)
| Name | Hex | RGB |
|------|-----|-----|
| Red Orange | #F03E1E | R240 G62 B30 |
| Mahogany | #C6361F | R198 G54 B31 |

Never use accent as full background.

### Brand Orange
| Name | Hex | Usage |
|------|-----|-------|
| Primary Pumpkin Orange | #F36717 | Logo, "SECURITY" wordmark |
| Primary Vivid Red | #FF2D46 | Supplementary accent |

---

## Logo Placement

| Logo Variant | Background | Placement |
|---|---|---|
| White on dark | Dark/gradient | bottom-right or upper-right |
| Black | Light/white | bottom-right or upper-right |
| Phoenix Orange | Emphasis | bottom-right or upper-right |

Never: bottom-left, center, over complex gradients.

---

## Typography

| Element | Style |
|---------|-------|
| Headlines | White / light grey |
| Body | Light grey |
| Code | Monospace |
| Exploit markers | #F03E1E |

---

## Visual Aesthetic

- Root-cause anatomy, not breach-alert drama
- Prefer diagrams explaining system behavior over incident graphics
- Architecture flow charts > threat actor narratives
- Engineering clarity > marketing language

---

## NotebookLM Prompts

### Blog / Research Report Prompt

```
You are generating structured technical research for a cybersecurity presentation under the Phoenix Security brand.

Your output must be analytical, precise, and designed for security engineers, AppSec teams, DevSecOps practitioners, and CISOs.

Avoid sensational language. Focus on root cause analysis, system behavior, and engineering impact.

Structure:
1. Research Context — what the technology/vulnerability is, where it appears in modern systems, why it matters to AppSec/DevSecOps
2. Problem Definition — system behavior creating risk, design assumptions failing, security boundaries, affected architecture layers
3. Detailed Technical Explanation — internal system behavior, trust boundaries, memory/data flow, processing sequence, failure conditions
4. Impact Analysis — security consequences, affected environments, attack surface, realistic attacker capabilities, supply chain implications
5. Remediation and Engineering Considerations — code-level mitigations, configuration controls, architectural improvements, patch considerations
6. Conclusion — what this teaches about system design, how engineers can prevent similar issues, why root cause analysis matters
7. References — CVEs, research papers, technical documentation, vendor advisories, GitHub commits

Tone: analytical, professional. No breach-alert language. Engineers need root cause, not headlines.
```

---

### Slide Deck Prompt

```
Create a structured technical slide deck based on the provided research.
Audience: security engineers, DevSecOps teams, CISOs.

Slide structure:
1. Title — topic + technical focus subtitle
2. Context — where this technology/vulnerability exists in modern systems, architecture
3. The Problem — system assumptions, boundary that fails, why the issue exists
4. System Architecture — components, trust boundaries, data flow
5. Technical Mechanics — step-by-step system behavior and internal logic
6. Failure Boundary — exactly where and how the failure occurs
7. Exploit Conditions — conditions for exploitation (system behavior, not attacker narrative)
8. Impact — attack surface, affected deployments, operational consequences
9. Remediation — engineering mitigation options, code fixes, defensive architecture
10. Key Lessons — what engineers should learn from this issue
11. References — all sources used

Design guidelines:
- Dark technical aesthetic
- Primary gradient: Deep Purple #6714CC → Indigo #380886 → Azure #245EE9 (top-left to bottom-right)
- Accent (exploit highlights only): Red Orange #F03E1E → Mahogany #C6361F
- Background: Neutral Dark #1E2535
- Phoenix Security logo: bottom-right or upper-right corner (white on dark)
- Typography: headlines white/light grey, body light grey, code monospace
- No marketing language. Engineering clarity.
```

---

### Video Script Prompt

```
Generate a technical explainer video script based on the research.
Audience: security engineers, DevSecOps practitioners.
Tone: analytical, calm, technical. No dramatic language. No breach-alert narration.

Structure:
- Opening (10–15s): Introduce topic, explain why it matters to engineers. System behavior focus, not attack headlines.
- Context: Where the technology/system is deployed. Architecture involved.
- Problem Explanation: The technical problem. The design assumption or boundary failure.
- Deep Technical Breakdown: Internal processing, memory/data flow, system assumptions, failure condition step by step.
- Impact Analysis: Realistic operational security consequences. Affected environments.
- Engineering Mitigation: How engineers can prevent or fix the issue. Design improvements and defensive coding.
- Closing: Key engineering lesson. Root cause > symptoms.

Visual style:
- Minimal animations, focus on system diagrams
- Phoenix Security logo: bottom-right corner
- Background gradient: Deep Purple → Indigo → Azure
- Accent: Red Orange → Mahogany for failure boundary highlights
- Avoid marketing visuals. Diagram system behavior.
```

---

### Infographic Focus Prompt

Use as the `--focus` argument when generating infographics:

```
Phoenix Security technical analysis: root cause, attack surface, and engineering remediation.
Analytical tone. System anatomy, not breach headlines. Include: affected components, failure boundary, mitigation path.
```

---

## SEO Keywords (for blog content)

Primary: DevSecOps, ASPM, CTEM, Container Lineage, Exposure Management
Secondary: CISA KEV, Supply Chain Security, Gartner, OWASP, reachability analysis
Emerging: LLM security, AI security, CNAPP, cloud-native security
Regulatory hooks: US (CISA directives, NIST CSF 2.0) / UK (NCSC, Cyber Essentials)
