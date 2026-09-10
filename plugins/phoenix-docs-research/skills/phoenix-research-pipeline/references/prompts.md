# Phoenix Security — NotebookLM Analysis Prompts

These prompts are injected automatically by `notebooklm_push.py` based on `--prompt` flag.
Use `--prompt blog | slides | video` to select.

---

## Blog / Research Prompt (`--prompt blog`)

Structured technical research for phoenix.security blog posts.
Target audience: security engineers, AppSec teams, DevSecOps practitioners, CISOs.

```
You are generating structured technical research for a cybersecurity presentation
under the Phoenix Security brand.

Your output must be analytical, precise, and designed for security engineers,
AppSec teams, DevSecOps practitioners, and CISOs. Avoid sensational language.
Focus on root cause analysis, system behavior, and engineering impact.

Structure:
1. Research Context — what the technology/vulnerability is, where it appears, why it matters
2. Problem Definition — system behavior creating risk, failing design assumptions, security boundaries
3. Technical Explanation — mechanics step by step, trust boundaries, data flow, failure conditions  
4. Impact Analysis — security consequences, attack surface, realistic attacker capabilities
5. Remediation — code-level mitigation, configuration controls, architectural improvements
6. Conclusion — lesson for system design, how engineers prevent similar issues
7. References — CVEs, papers, vendor advisories, GitHub

Tone: analytical, professional. Avoid hype. Write for engineers who understand root cause.
```

---

## Slide Deck Prompt (`--prompt slides`)

Generates a 11-slide structured deck with Phoenix brand design spec.

Slides: Title → Context → Problem → Architecture → Mechanics → Failure Boundary →
Exploit Conditions → Impact → Remediation → Key Lessons → References

Design spec:
- Background: #1E2535
- Primary gradient: Deep Purple #6714CC → Indigo #380886 → Azure #245EE9
- Accent (exploit only): Red Orange #F03E1E → Mahogany #C6361F
- Logo: Phoenix Security, bottom-right corner
- Typography: minimal, white on dark

---

## Video Script Prompt (`--prompt video`)

Technical explainer video script, ~5-8 minutes.

Sections: Opening (10-15s) → Context → Problem → Deep Technical Breakdown →
Impact → Engineering Mitigation → Closing

Visual direction:
- Minimal animations, system behavior diagrams
- Phoenix Security logo bottom-right
- Gradient: Deep Purple → Indigo → Azure
- Accent for exploit highlights only

---

## Brand Reference

| Element | Value |
|---------|-------|
| Dark BG | #1E2535 |
| Deep Purple | #6714CC |
| Indigo | #380886 |
| Azure | #245EE9 |
| Red Orange (accent) | #F03E1E |
| Mahogany (accent) | #C6361F |
| Logo position | bottom-right preferred |
| Logo on dark | white |
| Logo on light | black or orange |
