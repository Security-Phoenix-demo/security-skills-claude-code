# AGENTS.md - Security Skills Repository Maintenance Guide

This file provides guidance to AI coding agents working on the `security-skills-claude-code` repository.

## Project Overview

`security-skills-claude-code` is a collection of security-focused skills and plugins for Claude Code that enable advanced threat intelligence research, vulnerability analysis, and security automation.

## Repository Structure

```
security-skills-claude-code/
├── README.md                          # Main installation and usage guide
├── .cursor/
│   └── rules/
│       └── AGENTS.md                  # This file
├── skills/                            # Claude Code skills directory
│   └── cti-search-skill/
│       ├── SKILL.md                   # Skill specification (frontmatter + workflow)
│       ├── Readme                     # Brief description
│       ├── install.sh                 # Skill installation script
│       ├── cti-search.md              # Slash command definition
│       ├── cti-domain-research.skill  # Legacy skill format
│       └── tier-map.json              # Domain tier and authority mappings
└── plugins/                           # Claude Code plugins directory
    └── cti-search-plugin/
        ├── README.md                  # Plugin documentation
        ├── index.js                   # CLI entry point
        ├── mcp-server.js              # MCP tool server
        ├── install.sh                 # Plugin installation script
        ├── package.json               # Node.js dependencies
        ├── .env.example               # Environment variable template
        └── data/
            ├── domains.txt            # Curated security domain list (595+)
            └── tier-map.json          # Domain tier mappings
```

## Core Principles

### 1. Skills vs Plugins

**Skills** (`skills/` directory):
- SKILL.md files with frontmatter metadata
- Define workflows, prompts, and agent behaviors
- No code execution, pure instruction-based
- Installed to `~/.claude/skills/` or `~/.cursor/skills/`
- Can reference plugins for tool execution

**Plugins** (`plugins/` directory):
- Node.js applications with MCP server capabilities
- Provide tools, APIs, and executable functionality
- Can be used standalone (CLI) or via MCP (Claude Code integration)
- Installed to `~/.claude/plugins/`
- Require `npm install` for dependencies

### 2. Documentation Standards

Every skill and plugin MUST have:
- **README.md** - User-facing documentation with:
  - Clear description and use cases
  - Installation instructions (all methods)
  - Configuration requirements
  - Usage examples
  - API/flag reference
  - Troubleshooting section
- **install.sh** - Automated installation script that:
  - Checks prerequisites
  - Copies files to correct locations
  - Installs dependencies (for plugins)
  - Validates installation
  - Prints next steps

### 3. SKILL.md Format

All skills MUST follow this structure:

```markdown
---
name: skill-identifier
description: >
  Clear, concise description of what the skill does, when to use it,
  and what triggers it. Include key phrases that should activate the skill.
---

# Skill Display Name

Brief overview paragraph.

---

## Workflow

Step-by-step process the agent should follow.

---

## [Additional Sections]

Domain Tiers, Query Parsing, Output Formats, etc.

---

## Installation

How to install and configure the skill.

---

## Error Handling

Expected error conditions and how to handle them.
```

### 4. Plugin Standards

All plugins MUST:
- Include `package.json` with:
  - Clear name and description
  - All dependencies with versions
  - Node.js version requirement (>=18.0.0)
  - Test script
- Provide both CLI and MCP server interfaces
- Use environment variables for configuration (never hardcode)
- Include `.env.example` with all required variables
- Handle errors gracefully with clear messages
- Support `--dry-run` flag for testing

### 5. Installation Scripts

All `install.sh` scripts MUST:
- Be idempotent (safe to run multiple times)
- Check for existing installations
- Validate prerequisites (Node.js version, required tools)
- Create necessary directories
- Copy files with proper permissions
- Install dependencies (for plugins)
- Provide clear success/failure messages
- Print next steps after installation

Example template:

```bash
#!/bin/bash
set -e

SKILL_NAME="your-skill-name"
INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME"

echo "Installing $SKILL_NAME..."

# Check prerequisites
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    exit 1
fi

# Create directory
mkdir -p "$INSTALL_DIR"

# Copy files
cp -r ./* "$INSTALL_DIR/"

# Install dependencies (for plugins)
if [ -f "$INSTALL_DIR/package.json" ]; then
    cd "$INSTALL_DIR"
    npm install
fi

echo "✓ $SKILL_NAME installed successfully!"
echo "Next steps:"
echo "  1. Configure environment variables in $INSTALL_DIR/.env"
echo "  2. Restart Claude Code"
```

## Maintenance Tasks

### When Adding a New Skill

1. Create skill directory: `skills/new-skill-name/`
2. Create `SKILL.md` with proper frontmatter
3. Create `README.md` with installation and usage
4. Create `install.sh` script
5. Add entry to main `README.md` in "What's Included" section
6. Update installation instructions if needed
7. Test installation on clean system

### When Adding a New Plugin

1. Create plugin directory: `plugins/new-plugin-name/`
2. Create `package.json` with dependencies
3. Create `index.js` (CLI) and `mcp-server.js` (MCP interface)
4. Create `README.md` with architecture and usage
5. Create `.env.example` with all required variables
6. Create `install.sh` script
7. Add entry to main `README.md` in "What's Included" section
8. Update configuration section if new env vars needed
9. Test both CLI and MCP interfaces

### When Updating Domain Lists

For the CTI Search plugin:

1. Edit `plugins/cti-search-plugin/data/domains.txt`
   - Add one domain per line (format: `domain.com`)
   - Keep alphabetically sorted within tiers
   - Remove duplicates

2. Update `plugins/cti-search-plugin/data/tier-map.json`
   - Add tier assignment (1-4)
   - Add authority score (0-100)
   - Format:
     ```json
     {
       "newdomain.com": {
         "tier": 2,
         "authority": 85
       }
     }
     ```

3. Update domain count in documentation:
   - Main `README.md`
   - `plugins/cti-search-plugin/README.md`
   - `skills/cti-search-skill/SKILL.md`

4. Test with: `node index.js --query "test" --tier X`

### When Updating Documentation

**ALWAYS update these files together:**
- Main `README.md` (user-facing, installation guide)
- Skill `SKILL.md` (agent instructions, workflow)
- Plugin `README.md` (technical details, API reference)

**Keep synchronized:**
- Version numbers
- Feature lists
- API flags and parameters
- Environment variables
- Domain counts
- Installation instructions

### Version Bumping

When releasing updates:

1. Update `package.json` version in all plugins
2. Update version references in documentation
3. Update CHANGELOG.md (if exists) or create one
4. Tag release in git: `git tag -a v1.x.x -m "Release v1.x.x"`
5. Push tags: `git push --tags`

## Code Quality Standards

### Shell Scripts
- Use `set -e` for error handling
- Quote all variables: `"$VAR"`
- Use `#!/bin/bash` shebang
- Add comments for complex logic
- Test on macOS and Linux

### JavaScript/Node.js
- Use modern ES6+ syntax
- Handle errors with try/catch
- Validate all inputs
- Use environment variables for config
- Add JSDoc comments for functions
- Follow existing code style

### Documentation
- Use clear, concise language
- Include code examples for all features
- Provide troubleshooting section
- Link between related docs
- Keep table of contents updated
- Use proper markdown formatting

## Testing Checklist

Before committing changes:

- [ ] All installation scripts run successfully
- [ ] Documentation is updated and synchronized
- [ ] Examples in README work as shown
- [ ] Environment variables are documented
- [ ] Error messages are clear and actionable
- [ ] No hardcoded paths or credentials
- [ ] Code follows existing style
- [ ] Git status is clean (no untracked sensitive files)

## Common Pitfalls to Avoid

1. **Hardcoded Paths**: Always use `$HOME` or environment variables
2. **Missing Prerequisites**: Check for Node.js, npm, git before installation
3. **Unsynchronized Docs**: Update all related documentation files
4. **Breaking Changes**: Maintain backward compatibility or document breaking changes
5. **Missing Error Handling**: Every external call should have error handling
6. **Unclear Error Messages**: Always tell users what went wrong and how to fix it
7. **Untested Installation**: Test install scripts on clean system
8. **Missing .env.example**: Never commit `.env`, always provide `.env.example`

## File Naming Conventions

- Skills: `kebab-case-name/SKILL.md`
- Plugins: `kebab-case-name/index.js`
- Scripts: `install.sh`, `test.sh`, `deploy.sh`
- Documentation: `README.md`, `CHANGELOG.md`
- Data files: `kebab-case.json`, `kebab-case.txt`

## Git Workflow

1. Create feature branch: `git checkout -b feature/new-skill`
2. Make changes following this guide
3. Test thoroughly
4. Update documentation
5. Commit with clear message: `feat: add new CTI skill for malware analysis`
6. Push and create pull request
7. Ensure CI passes (if configured)

## Environment Variables Reference

Current environment variables used across the repository:

| Variable | Required | Used By | Purpose |
|----------|----------|---------|---------|
| `BRAVE_SEARCH_API_KEY` | Yes* | cti-search-plugin | Brave Search API authentication |
| `SERPAPI_KEY` | Yes* | cti-search-plugin | SerpAPI authentication (alternative) |
| `SEARCH_PROVIDER` | No | cti-search-plugin | Search provider selection (default: brave) |
| `NOTEBOOKLM_NOTEBOOK_ID` | No | cti-search-plugin | Default NotebookLM notebook for ingestion |

*One search provider key is required (either Brave or SerpAPI)

## Support and Troubleshooting

### Common Issues

**"Command not found" errors:**
- Ensure installation script completed successfully
- Check that files were copied to correct location
- Verify PATH includes `~/.claude/plugins/` or `~/.cursor/skills/`

**"Module not found" errors:**
- Run `npm install` in plugin directory
- Check Node.js version (must be 18+)
- Verify `package.json` exists

**MCP server not responding:**
- Restart Claude Code
- Check MCP server registration in settings
- Verify plugin path is correct

**Search API errors:**
- Verify API key is set in `.env`
- Check API key is valid and has quota remaining
- Test with `--dry-run` flag first

## Resources

- [Claude Code Skills Documentation](https://docs.anthropic.com/claude/docs/skills)
- [MCP Server Specification](https://modelcontextprotocol.io/)
- [Brave Search API](https://api.search.brave.com/app/keys)
- [NotebookLM](https://notebooklm.google.com/)

## Questions?

When in doubt:
1. Check existing skills/plugins for examples
2. Follow the structure and patterns already established
3. Test thoroughly before committing
4. Document everything clearly
5. Ask for review if making significant changes
