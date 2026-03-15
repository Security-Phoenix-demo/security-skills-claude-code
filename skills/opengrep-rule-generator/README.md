# Opengrep Rule Generator

Generate opengrep/semgrep SAST rules through collaborative dialogue, supporting both guided discovery and vulnerability-driven workflows.

## What It Does

This skill helps you create valid opengrep/semgrep YAML rules for static application security testing (SAST). It supports two primary workflows: a guided mode where it asks interactive questions to discover what vulnerability patterns to detect, and a vulnerability-driven mode where it generates rules directly from CVE IDs, CWE references, or OWASP categories.

The guided workflow walks through five steps: identifying the target vulnerability or anti-pattern, confirming the language and framework, examining vulnerable and safe code examples, determining whether taint analysis or pattern matching is appropriate, and setting severity and scope. The vulnerability-driven workflow parses the vulnerability details, checks existing rule coverage, selects the appropriate rule mode (search, taint, or regex/generic), and generates one or more rules with full metadata.

Generated rules include CWE and OWASP metadata, structured messages explaining what was detected, why it is dangerous, and how to fix it. Every rule comes with companion test files containing true positive and true negative cases. The skill also provides an advanced patterns cookbook covering common scenarios like missing security checks, tainted string concatenation, weak config values, and multi-step taint analysis with labels.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Core skill definition with full workflow, rule generation templates, mode selection guide, and validation checklist |
| `RULES_SYNTAX.md` | Reference documentation for all opengrep/semgrep rule operators, pattern syntax, taint mode spec, and supported languages |
| `OPENGREP_RULE_GENERATOR_PROMPT.md` | System prompt version for use as Claude Desktop project knowledge |

## Installation

Add the skill files to your Claude Code skills directory or load them as project knowledge in Claude Desktop:

```bash
# For Claude Code: copy to your skills directory
cp -r opengrep-rule-generator/ ~/.claude/skills/

# For Claude Desktop: add OPENGREP_RULE_GENERATOR_PROMPT.md as Project Knowledge
```

## Usage

```
# Guided mode — interactive Q&A
Create a rule to detect SQL injection in our Flask app

# Vulnerability-driven mode — from CVE
Generate opengrep rules for CVE-2024-21762

# From OWASP category
Generate SAST rules for OWASP A03:2021 Injection in Python

# Batch generation
Generate opengrep rules for OWASP Top 10 in Java Spring
```

Generated rules are saved to `custom-rules/<vuln-type>/` with companion test files.

## Requirements

- Claude Code or Claude Desktop
- Optional: opengrep/semgrep CLI installed locally for rule validation (`opengrep scan --config <rule.yaml> <test-file>`)
- Optional: existing semgrep-rules repositories for coverage gap analysis
