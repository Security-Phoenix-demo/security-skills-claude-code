# Security Skills for Claude Code

A collection of security-focused skills and plugins for Claude Code that enable advanced threat intelligence research, vulnerability analysis, and security automation.

## 📦 What's Included

### Skills
- **[CTI Domain Research](skills/cti-search-skill/)** - Search 300+ curated security domains for threat intelligence, CVEs, malware analysis, and breach reports

### Plugins
- **[CTI Search Plugin](plugins/cti-search-plugin/)** - MCP server and CLI tool for executing CTI searches with optional NotebookLM integration

## 🚀 Quick Start

### Prerequisites

- Claude Code installed
- Node.js 18+ (for plugins)
- API keys for search providers (Brave Search recommended)

### Installation Methods

Choose the method that works best for you:

#### Method 1: Claude Marketplace (Recommended)

📘 **[See detailed marketplace installation guide](MARKETPLACE_INSTALL.md)**

1. Open Claude Code
2. Navigate to the Skills marketplace
3. Search for "CTI Domain Research" or "Security Skills"
4. Click "Install" on the skills/plugins you want
5. Follow the [configuration steps](MARKETPLACE_INSTALL.md#post-installation-configuration)

#### Method 2: Manual Installation via Git

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/security-skills-claude-code.git
cd security-skills-claude-code

# Install the CTI Search Skill
cd skills/cti-search-skill
bash install.sh

# Install the CTI Search Plugin
cd ../../plugins/cti-search-plugin
bash install.sh
```

#### Method 3: Direct File Copy

**For Skills:**
```bash
# Copy skill to Claude Code skills directory
cp -r skills/cti-search-skill ~/.claude/skills/

# Or for Cursor
cp -r skills/cti-search-skill ~/.cursor/skills/
```

**For Plugins:**
```bash
# Copy plugin to Claude Code plugins directory
cp -r plugins/cti-search-plugin ~/.claude/plugins/
cd ~/.claude/plugins/cti-search-plugin
npm install

# Configure environment variables
cp .env.example .env
# Edit .env and add your API keys
```

> 💡 **New to this repo?** Check out the [Marketplace Installation Guide](MARKETPLACE_INSTALL.md) for step-by-step instructions with troubleshooting.

## 🔧 Configuration

### Required API Keys

The CTI Search functionality requires a search API provider. Choose one:

| Provider | Free Tier | Setup |
|----------|-----------|-------|
| **Brave Search** (recommended) | 2,000 requests/month | Get key at [api.search.brave.com](https://api.search.brave.com/app/keys) |
| SerpAPI | 100 requests/month | Get key at [serpapi.com](https://serpapi.com) |

### Environment Variables

Create a `.env` file in the plugin directory or set system-wide:

```bash
# Required: Search provider
BRAVE_SEARCH_API_KEY=your_brave_api_key_here
SEARCH_PROVIDER=brave

# Optional: NotebookLM integration
NOTEBOOKLM_NOTEBOOK_ID=your_notebook_id_here
```

### Verify Installation

```bash
# Test the skill is accessible
ls ~/.claude/skills/cti-search-skill/

# Test the plugin
cd ~/.claude/plugins/cti-search-plugin
node index.js --query "CVE-2024-21762" --dry-run
```

## 📚 Usage

### Using the CTI Search Skill

In Claude Code, simply ask:

```
Search for threat intelligence on CVE-2024-21762
Find recent LockBit ransomware reports
What are security vendors saying about ALPHV?
Research MITRE T1190 exploitation techniques
```

The skill will automatically:
1. Route your query to appropriate security domain tiers
2. Execute searches across 300+ curated sources
3. Deduplicate and rank results by authority
4. Extract IOCs, CVEs, and MITRE ATT&CK mappings
5. Return a structured CTI brief

### Using the Plugin Directly

#### As a Slash Command
```
/cti-search CVE-2024-21762
/cti-search LockBit ransomware --full --since 30
/cti-search ALPHV --notebooklm --tier 2
```

#### As CLI Tool
```bash
node index.js --query "CVE-2024-21762" --full
node index.js --query "LockBit" --tier 2 --since 30 --notebooklm
node index.js --query "supply chain attack npm" --json | jq '.[] | .url'
```

### Available Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--query <q>` | Search subject (required) | - |
| `--count <n>` | Results per tier | 10 |
| `--tier <1-4>` | Restrict to specific domain tier | All tiers |
| `--since <days>` | Recency filter | 90 days |
| `--full` | Long-form brief with MITRE mapping | Brief format |
| `--json` | Raw JSON output | Formatted text |
| `--notebooklm` | Push sources to NotebookLM | Disabled |
| `--notebook-id <id>` | NotebookLM notebook ID | From env var |

## 🎯 Domain Tiers

The CTI search uses a tiered domain system for intelligent routing:

| Tier | Type | Use Case | Examples |
|------|------|----------|----------|
| **T1** | Authoritative/Govt | CVEs, advisories, official alerts | CISA, NVD, MSRC, NCSC, Red Hat |
| **T2** | Vendor Research | Deep technical analysis | Unit42, Talos, Securelist, DFIR Report, Mandiant |
| **T3** | News/Community | Situational awareness | BleepingComputer, Krebs, TheRecord, HackerNews |
| **T4** | OSINT/PoC | Malware samples, exploits | any.run, VulnCheck, AttackerKB, GreyNoise |

### Routing Logic

- **CVE queries** → T1 first (authoritative sources), then T2 (vendor analysis)
- **Threat actor/malware** → T2 first (research), then T4 (OSINT)
- **News/situational** → T3 first (news), then T2 (context)
- **PoC/exploits** → T4 + T2 (technical details)
- **General queries** → All tiers, ranked by authority

## 🔗 NotebookLM Integration

The CTI Search can automatically push research findings to Google NotebookLM for further analysis.

### Setup

1. Install the [notebooklm-connector plugin](https://github.com/franksec42/claude-code-zero/tree/main/plugins/notebooklm-connector):
   ```bash
   git clone https://github.com/franksec42/claude-code-zero /tmp/ccz
   cp -r /tmp/ccz/plugins/notebooklm-connector ~/.claude/plugins/
   cd ~/.claude/plugins/notebooklm-connector && npm install
   ```

2. Get your NotebookLM notebook ID from the URL:
   ```
   https://notebooklm.google.com/notebook/<YOUR-NOTEBOOK-ID>
   ```

3. Set the environment variable:
   ```bash
   export NOTEBOOKLM_NOTEBOOK_ID=your_notebook_id_here
   ```

### Usage

Add the `--notebooklm` flag to any search:

```bash
/cti-search CVE-2024-21762 --notebooklm
```

The plugin will:
1. Execute the CTI search
2. Collect all result URLs
3. Push them as sources to your NotebookLM notebook
4. Report the number of sources added

## 📖 Detailed Documentation

- **[CTI Search Skill Documentation](skills/cti-search-skill/SKILL.md)** - Complete skill specification and workflow
- **[CTI Search Plugin Documentation](plugins/cti-search-plugin/README.md)** - Plugin architecture, MCP server, and CLI usage

## 🛠️ Development

### Project Structure

```
security-skills-claude-code/
├── README.md                          # This file
├── skills/
│   └── cti-search-skill/
│       ├── SKILL.md                   # Skill specification
│       ├── install.sh                 # Skill installer
│       ├── cti-search.md              # Slash command definition
│       └── tier-map.json              # Domain tier mappings
└── plugins/
    └── cti-search-plugin/
        ├── README.md                  # Plugin documentation
        ├── index.js                   # CLI entry point
        ├── mcp-server.js              # MCP tool server
        ├── install.sh                 # Plugin installer
        ├── package.json               # Dependencies
        ├── .env.example               # Environment template
        └── data/
            ├── domains.txt            # 595+ curated domains
            └── tier-map.json          # Domain authority scores
```

### Adding New Domains

To add new security domains to the search:

1. Edit `plugins/cti-search-plugin/data/domains.txt`
2. Add one domain per line (format: `domain.com`)
3. Update `data/tier-map.json` with tier and authority score:
   ```json
   {
     "newdomain.com": {
       "tier": 2,
       "authority": 85
     }
   }
   ```
4. Test with: `node index.js --query "test" --tier 2`

### Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for detailed instructions on:
- Adding new skills
- Adding new plugins
- Documentation standards
- Testing requirements
- Pull request process

Quick start:
1. Fork this repository
2. Create a feature branch: `git checkout -b feature/new-skill`
3. Follow the [Contributing Guide](CONTRIBUTING.md)
4. Submit a pull request

## 📚 Documentation

- **[Main README](README.md)** - This file (overview and quick start)
- **[Marketplace Installation Guide](MARKETPLACE_INSTALL.md)** - Detailed installation and troubleshooting
- **[Contributing Guide](CONTRIBUTING.md)** - How to add skills and plugins
- **[Agent Maintenance Guide](.cursor/rules/AGENTS.md)** - For AI agents working on this repo
- **[CTI Search Skill](skills/cti-search-skill/SKILL.md)** - Skill specification and workflow
- **[CTI Search Plugin](plugins/cti-search-plugin/README.md)** - Plugin architecture and API reference

## 📝 License

MIT License - see LICENSE file for details

## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/security-skills-claude-code/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/security-skills-claude-code/discussions)
- **Documentation**: Check the guides above for detailed help

## 🔐 Security Note

This toolkit is designed for legitimate security research and threat intelligence gathering. Always:
- Respect rate limits and terms of service for search APIs
- Use responsibly and ethically
- Follow responsible disclosure practices
- Comply with applicable laws and regulations

## 🙏 Acknowledgments

- Built for the Claude Code ecosystem
- Curated domain list includes 300+ trusted security sources
- Inspired by the need for efficient, structured CTI research workflows
