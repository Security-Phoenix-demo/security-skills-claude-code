# Secure PRD Plugin

A Claude.ai web UI plugin for generating security-focused Product Requirements Documents, built as a React component with an embedded 10-role specification pipeline.

## What It Does

This plugin brings the Secure PRD Generator into the Claude.ai web interface as an interactive plugin. It packages the same 10-role specification pipeline (Context Curator through Final Gate) as the skill version, but wraps it in a React-based UI component that renders structured PRD output directly in the Claude.ai conversation.

The plugin embeds the full system prompt as a constant, instructing Claude to respond with structured JSON matching a defined schema. The JSON output includes feature specifications, security threat models, API contracts, verification matrices, delivery batches, and risk assessments. The React component then renders this structured data as a formatted PRD with interactive sections.

This is the Claude.ai-compatible counterpart to the [`skills/secure-prd-skill/`](../../skills/secure-prd-skill/) skill, which is designed for Claude Code. Both produce the same security-focused PRD output through the same pipeline, but this version runs as a web UI plugin rather than a CLI skill.

## Files

| File | Purpose |
|------|---------|
| `prd-generator.skill` | Packaged skill bundle (ZIP archive) containing the core SKILL.md with the full pipeline specification |
| `prd-generator-plugin.jsx` | React component that renders the PRD generator UI in Claude.ai, with embedded system prompt and JSON schema |

## Installation

### Claude.ai Web UI

Upload `prd-generator-plugin.jsx` as a plugin in your Claude.ai project, or add `prd-generator.skill` as project knowledge.

### Claude Code (skill version)

If you prefer the CLI experience, use the skill version instead:

```bash
cp -r ../skills/secure-prd-skill/ ~/.claude/skills/
```

## Usage

In Claude.ai with the plugin loaded:

```
Generate a PRD for [feature description]
Create a security-focused product spec for [feature]
```

The plugin will produce structured JSON output rendered as a formatted PRD with:
- Feature specifications with functional requirements
- STRIDE threat model and security requirements
- API contracts and error taxonomies
- Verification matrix with proof paths
- Incremental delivery batches with validation criteria

## Requirements

- Claude.ai with plugin support enabled
- For Confluence/Slack/Linear integration, the corresponding MCP connectors must be configured in your Claude.ai project
- See also: [`skills/secure-prd-skill/`](../../skills/secure-prd-skill/) for the Claude Code CLI version
