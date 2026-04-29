# Archive

Items here are superseded but kept for reference. **Recover by moving back up one level.**

## `Security-reviewr/`

Single-file 8-point security reviewer. Superseded by the multi-language reviewer at
`../Security-automated-claude-skills/.claude/skills/security-reviewer/SKILL.md`,
which covers the same 8 categories plus per-language reference packs (Python, JS/TS, Go,
Java/Kotlin, Rust, Ruby, .NET), checklists (OWASP/ASVS, endpoints), and a triage playbook.

The lite version was removed because:

- Both files defined the same 8-point check — duplicated content.
- The bundle's reviewer is strictly more capable (language-aware, structured CWE/OWASP/ASVS output).
- The `/security-review` slash command already routes to the bundle.

If you genuinely need a single-file portable reviewer (e.g. for a one-off audit on a repo
where you can't install the suite), move this folder back up:

```bash
mv _archive/Security-reviewr ./
```

Date archived: 2026-04-29.
