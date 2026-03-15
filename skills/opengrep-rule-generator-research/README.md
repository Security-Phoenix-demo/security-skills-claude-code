# Opengrep Rule Generator with Research

Generate opengrep/semgrep SAST rules with integrated web research capabilities for comprehensive vulnerability analysis before rule creation.

## What It Does

This skill extends the standard Opengrep Rule Generator with online research capabilities. Before generating detection rules, it can research CVEs, CWEs, and vulnerability classes using web search and fetch tools to build a complete understanding of the attack surface, affected APIs, known exploits, and existing detection coverage gaps.

The research-enhanced workflow follows four phases: understanding the vulnerability through official sources (NVD, CWE, OWASP), mapping the language-specific attack surface by identifying sources, sinks, and sanitizers for the target framework, studying existing detection rules to find coverage gaps, and documenting all findings as structured YAML comments in the generated rule files. This ensures that generated rules are grounded in real-world vulnerability data rather than generic patterns.

Like the base rule generator, it supports both guided (interactive Q&A) and vulnerability-driven workflows, produces rules with CWE/OWASP metadata and companion test files, and covers search mode, taint analysis, and regex/generic patterns across 30+ languages. The key difference is the ability to conduct online research before rule generation, which produces more accurate and comprehensive detection rules.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Core skill definition with research-enhanced workflow, vulnerability research plan, rule generation templates, and validation checklist |
| `RULES_SYNTAX.md` | Reference documentation for all opengrep/semgrep rule operators, pattern syntax, taint mode spec, and supported languages |
| `OPENGREP_RULE_GENERATOR_PROMPT.md` | System prompt version for use as Claude Desktop project knowledge |

## Installation

Add the skill files to your Claude Code skills directory or load them as project knowledge in Claude Desktop:

```bash
# For Claude Code: copy to your skills directory
cp -r opengrep-rule-generator-research/ ~/.claude/skills/

# For Claude Desktop: add OPENGREP_RULE_GENERATOR_PROMPT.md as Project Knowledge
```

## Usage

```
# Research a CVE and generate detection rules
Research CVE-2024-21762 and generate opengrep rules

# Research a vulnerability class with web search
Research SSRF vulnerabilities in Node.js Express and create detection rules

# Build comprehensive coverage for a framework
Research and generate SAST rules for OWASP Top 10 in Python Django
```

The skill will conduct web research first, then generate rules with research documentation embedded as YAML comments.

## Requirements

- Claude Code with WebSearch and WebFetch tools enabled (required for research capabilities)
- Optional: opengrep/semgrep CLI installed locally for rule validation
- Optional: existing semgrep-rules repositories for coverage gap analysis
- See also: [`opengrep-rule-generator/`](../opengrep-rule-generator/) for the version without web research
