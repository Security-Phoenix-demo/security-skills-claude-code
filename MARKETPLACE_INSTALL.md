# Claude Marketplace Installation Guide

This guide covers installing Security Skills for Claude Code through the Claude Marketplace.

## Prerequisites

- Claude Code installed and running
- Node.js 18+ (for plugins that require dependencies)
- API keys for search providers (see [Configuration](#configuration))

## Installing from Claude Marketplace

### Method 1: Search and Install (Recommended)

1. **Open Claude Code**
2. **Access the Marketplace**:
   - Click on the Skills/Plugins menu
   - Or use the command palette: `Cmd/Ctrl + Shift + P` → "Browse Skills Marketplace"
3. **Search for Skills**:
   - Search for "CTI Domain Research" or "Security Skills"
   - Browse the security category
4. **Install**:
   - Click "Install" on the skill or plugin you want
   - Wait for installation to complete
   - Restart Claude Code if prompted

### Method 2: Direct Install via URL

If you have a direct marketplace URL:

```bash
# For skills
claude-code install skill:cti-domain-research

# For plugins
claude-code install plugin:cti-search-plugin
```

## Available Packages

### Skills

#### CTI Domain Research
- **Marketplace ID**: `cti-domain-research`
- **Description**: Search 300+ curated security domains for threat intelligence
- **Use Cases**: CVE research, threat actor analysis, malware intelligence
- **Dependencies**: None (pure instruction-based)
- **Install Command**: `claude-code install skill:cti-domain-research`

#### Secure PRD Generator
- **Marketplace ID**: `secure-prd-generator`
- **Description**: Generate security-focused Product Requirements Documents with threat modeling
- **Use Cases**: PRD creation, security requirements, threat model generation
- **Dependencies**: None (pure instruction-based; optional MCP integrations for Confluence, Linear, Slack)
- **Install Command**: `claude-code install skill:secure-prd-generator`

#### OpenGrep Rule Generator
- **Marketplace ID**: `opengrep-rule-generator`
- **Description**: Generate opengrep/semgrep SAST rules for vulnerability detection across 30+ languages
- **Use Cases**: SAST rule creation, vulnerability pattern detection, OWASP Top 10 coverage, code security scanning
- **Dependencies**: None (pure instruction-based; opengrep or semgrep CLI needed to run generated rules)
- **Install Command**: `claude-code install skill:opengrep-rule-generator`

#### OpenGrep Rule Generator Research
- **Marketplace ID**: `opengrep-rule-generator-research`
- **Description**: Research CVEs/CWEs via web search, then generate targeted detection rules from findings
- **Use Cases**: CVE-driven rule generation, vulnerability research, detection gap analysis, security coverage mapping
- **Dependencies**: None (pure instruction-based; uses web search and web fetch tools for research)
- **Install Command**: `claude-code install skill:opengrep-rule-generator-research`

#### NotebookLM Connector
- **Marketplace ID**: `notebooklm-connector`
- **Description**: Query Google NotebookLM notebooks from Claude Code for citation-backed answers
- **Use Cases**: Source-grounded research Q&A, security documentation querying, notebook library management
- **Dependencies**: Chrome/Edge browser, "Claude in Chrome" extension, Google account with NotebookLM access
- **Install Command**: `claude-code install skill:notebooklm-connector`

#### Global Research Pipeline
- **Marketplace ID**: `global-research-pipeline`
- **Description**: Systematic research pipeline with web search and NotebookLM integration
- **Use Cases**: Deep research, source collection, NotebookLM ingestion
- **Dependencies**: Python 3.8+ (for research modules), NotebookLM connector
- **Install Command**: `claude-code install skill:global-research-pipeline`

#### Project Documentation
- **Marketplace ID**: `project-documentation`
- **Description**: Auto-generate comprehensive project documentation from your codebase
- **Use Cases**: Project documentation, architecture summaries, onboarding docs
- **Dependencies**: None (pure instruction-based)
- **Install Command**: `claude-code install skill:project-documentation`

### Plugins

#### CTI Search Plugin
- **Marketplace ID**: `cti-search-plugin`
- **Description**: MCP server and CLI for executing CTI searches across 595+ domains
- **Use Cases**: Automated threat intelligence gathering, NotebookLM integration
- **Dependencies**: Node.js 18+, Brave Search API or SerpAPI
- **Install Command**: `claude-code install plugin:cti-search-plugin`

#### Secure PRD Plugin
- **Marketplace ID**: `secure-prd-plugin`
- **Description**: PRD generator with Confluence, Linear, Asana, Slack, Notion, and Gmail integrations
- **Use Cases**: Automated PRD publishing, task creation, stakeholder notifications
- **Dependencies**: Node.js 18+, MCP integrations for target platforms
- **Install Command**: `claude-code install plugin:secure-prd-plugin`

### Feature Descriptor — Phoenix Pipeline
- **Marketplace ID**: `phoenix-pipeline`
- **Description**: 12-role specification system for security-aware product requirements
- **Use Cases**: Feature specification, security-first PRDs, RFC 2119 requirements
- **Dependencies**: None (pure instruction-based)
- **Install Command**: `claude-code install skill:phoenix-pipeline`
- **Details**: See [`feature-descriptor/`](feature-descriptor/) for all 12 role definitions

## Post-Installation Configuration

### 1. Verify Installation

**For Skills:**
```bash
# Check skill is installed
ls ~/.claude/skills/cti-search-skill/

# Or for Cursor
ls ~/.cursor/skills/cti-search-skill/
```

**For Plugins:**
```bash
# Check plugin is installed
ls ~/.claude/plugins/cti-search-plugin/

# Verify dependencies
cd ~/.claude/plugins/cti-search-plugin
npm list
```

### 2. Configure API Keys

The CTI Search functionality requires a search API provider.

#### Option A: Brave Search (Recommended)

1. **Get API Key**:
   - Visit [api.search.brave.com](https://api.search.brave.com/app/keys)
   - Sign up for free account
   - Create an API key (2,000 requests/month free)

2. **Set Environment Variable**:
   ```bash
   # Add to ~/.bashrc, ~/.zshrc, or ~/.profile
   export BRAVE_SEARCH_API_KEY=your_api_key_here
   export SEARCH_PROVIDER=brave
   ```

3. **Or use .env file**:
   ```bash
   cd ~/.claude/plugins/cti-search-plugin
   cp .env.example .env
   # Edit .env and add your key
   ```

#### Option B: SerpAPI

1. **Get API Key**:
   - Visit [serpapi.com](https://serpapi.com)
   - Sign up for free account (100 requests/month)
   - Get your API key

2. **Set Environment Variable**:
   ```bash
   export SERPAPI_KEY=your_api_key_here
   export SEARCH_PROVIDER=serpapi
   ```

### 3. Optional: NotebookLM Integration

To enable automatic pushing of research to NotebookLM:

1. **Install NotebookLM Connector**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-code-zero /tmp/ccz
   cp -r /tmp/ccz/plugins/notebooklm-connector ~/.claude/plugins/
   cd ~/.claude/plugins/notebooklm-connector && npm install
   ```

2. **Get Notebook ID**:
   - Go to your NotebookLM notebook
   - Copy the ID from the URL: `https://notebooklm.google.com/notebook/<YOUR-ID>`

3. **Set Environment Variable**:
   ```bash
   export NOTEBOOKLM_NOTEBOOK_ID=your_notebook_id_here
   ```

### 4. Restart Claude Code

After configuration:
```bash
# Restart Claude Code to load new environment variables
# Or reload window: Cmd/Ctrl + Shift + P → "Reload Window"
```

## Testing Your Installation

### Test the Skill

Open Claude Code and ask:

```
Search for threat intelligence on CVE-2024-21762
```

Expected behavior:
- Skill activates automatically
- Claude searches across security domains
- Returns structured CTI brief with sources

### Test the Plugin (CLI)

```bash
cd ~/.claude/plugins/cti-search-plugin
node index.js --query "CVE-2024-21762" --dry-run
```

Expected output:
```
Processing query: CVE-2024-21762
[Dry run mode - no actual search performed]
✓ Configuration valid
✓ API key present
✓ Domain list loaded (595 domains)
```

### Test the Plugin (MCP)

In Claude Code, ask:

```
Use the CTI search tool to find recent LockBit ransomware reports
```

Expected behavior:
- Claude calls the `cti_search` MCP tool
- Returns structured results with URLs
- Offers to push to NotebookLM if configured

## Troubleshooting

### Skill Not Activating

**Problem**: Skill doesn't trigger when asking relevant questions

**Solutions**:
1. Verify installation:
   ```bash
   ls ~/.claude/skills/cti-search-skill/SKILL.md
   ```
2. Check skill is enabled in Claude Code settings
3. Try more explicit trigger phrases:
   - "Use the CTI domain research skill to..."
   - "Search security domains for..."
4. Restart Claude Code

### Plugin Not Found

**Problem**: "Tool not found" or "Plugin not available" errors

**Solutions**:
1. Verify plugin installation:
   ```bash
   ls ~/.claude/plugins/cti-search-plugin/
   ```
2. Check MCP server is registered:
   - Open Claude Code settings
   - Check MCP servers list
   - Ensure `cti-search-plugin` is listed
3. Check Node.js version:
   ```bash
   node --version  # Should be 18+
   ```
4. Reinstall dependencies:
   ```bash
   cd ~/.claude/plugins/cti-search-plugin
   npm install
   ```

### API Key Errors

**Problem**: "API key not found" or "Authentication failed"

**Solutions**:
1. Verify environment variable is set:
   ```bash
   echo $BRAVE_SEARCH_API_KEY
   # or
   echo $SERPAPI_KEY
   ```
2. Check .env file exists and has correct key:
   ```bash
   cat ~/.claude/plugins/cti-search-plugin/.env
   ```
3. Verify API key is valid:
   - Test at provider's website
   - Check quota hasn't been exceeded
4. Restart terminal and Claude Code after setting env vars

### Search Returns No Results

**Problem**: Search completes but returns empty results

**Solutions**:
1. Try broader query terms
2. Check specific domain tier:
   ```bash
   node index.js --query "test" --tier 1
   ```
3. Verify domain list is present:
   ```bash
   wc -l ~/.claude/plugins/cti-search-plugin/data/domains.txt
   # Should show 595+ lines
   ```
4. Check API quota hasn't been exceeded

### NotebookLM Integration Not Working

**Problem**: `--notebooklm` flag doesn't push sources

**Solutions**:
1. Verify connector is installed:
   ```bash
   ls ~/.claude/plugins/notebooklm-connector/
   ```
2. Check notebook ID is set:
   ```bash
   echo $NOTEBOOKLM_NOTEBOOK_ID
   ```
3. Verify notebook ID is valid (from NotebookLM URL)
4. Check connector dependencies:
   ```bash
   cd ~/.claude/plugins/notebooklm-connector
   npm install
   ```

## Updating Installed Packages

### Update via Marketplace

1. Open Claude Code
2. Go to Skills/Plugins menu
3. Check for updates
4. Click "Update" on packages with available updates

### Manual Update

```bash
# For skills
cd ~/.claude/skills/cti-search-skill
git pull  # If installed via git

# For plugins
cd ~/.claude/plugins/cti-search-plugin
git pull  # If installed via git
npm install  # Update dependencies
```

## Uninstalling

### Via Marketplace

1. Open Claude Code
2. Go to Skills/Plugins menu
3. Find the package
4. Click "Uninstall"

### Manual Uninstall

```bash
# Remove skill
rm -rf ~/.claude/skills/cti-search-skill

# Remove plugin
rm -rf ~/.claude/plugins/cti-search-plugin

# Remove environment variables from shell config
# Edit ~/.bashrc, ~/.zshrc, or ~/.profile and remove:
# export BRAVE_SEARCH_API_KEY=...
# export NOTEBOOKLM_NOTEBOOK_ID=...
```

## Getting Help

### Documentation

- **Main README**: [README.md](README.md)
- **CTI Skill Docs**: [skills/cti-search-skill/SKILL.md](skills/cti-search-skill/SKILL.md)
- **CTI Plugin Docs**: [plugins/cti-search-plugin/README.md](plugins/cti-search-plugin/README.md)
- **Contributing Guide**: [CONTRIBUTING.md](CONTRIBUTING.md)

### Support Channels

- **GitHub Issues**: [Report bugs or request features](https://github.com/YOUR_USERNAME/security-skills-claude-code/issues)
- **GitHub Discussions**: [Ask questions or share ideas](https://github.com/YOUR_USERNAME/security-skills-claude-code/discussions)
- **Documentation**: Check the detailed README files in each skill/plugin directory

## Next Steps

After successful installation:

1. **Explore Examples**: Try the example queries in the documentation
2. **Customize Configuration**: Adjust settings for your workflow
3. **Integrate with NotebookLM**: Set up automatic research ingestion
4. **Provide Feedback**: Share your experience and suggestions

## Quick Reference

### Common Commands

```bash
# Test plugin CLI
node ~/.claude/plugins/cti-search-plugin/index.js --query "test" --dry-run

# Check installation
ls ~/.claude/skills/cti-search-skill/
ls ~/.claude/plugins/cti-search-plugin/

# View environment variables
env | grep -E 'BRAVE|SERPAPI|NOTEBOOKLM'

# Update plugin dependencies
cd ~/.claude/plugins/cti-search-plugin && npm install
```

### Common Queries

```
# CVE research
Search for threat intelligence on CVE-2024-XXXX

# Threat actor analysis
What are security vendors saying about LockBit?

# Malware research
Find recent analysis of ALPHV ransomware

# General security research
Search security blogs for supply chain attacks

# With NotebookLM
Research CVE-2024-XXXX and push to NotebookLM
```

---

**Happy threat hunting!** 🔍🛡️
