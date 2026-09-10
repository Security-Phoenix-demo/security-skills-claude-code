# Contributing to Security Skills for Claude Code

Thank you for your interest in contributing! This repository is maintained by the engineering and security teams at [Phoenix Security](https://phoenix.security) and open to contributions from the global security community.

This guide will help you add new skills, plugins, feature-descriptor roles, or improve existing ones.

## Table of Contents

- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
- [Adding a New Skill](#adding-a-new-skill)
- [Adding a New Plugin](#adding-a-new-plugin)
- [Adding a Feature-Descriptor Role](#adding-a-feature-descriptor-role)
- [Documentation Standards](#documentation-standards)
- [Testing Your Contribution](#testing-your-contribution)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Code Review Process](#code-review-process)

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/security-skills-claude-code.git
   cd security-skills-claude-code
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Repository Structure

```
security-skills-claude-code/
├── .claude-plugin/
│   └── marketplace.json               # the marketplace manifest — lists every plugin
├── README.md                          # Main documentation — start here
├── CONTRIBUTING.md                    # This file
├── MARKETPLACE_INSTALL.md             # Marketplace installation guide
├── LICENSE                            # MIT License
│
└── plugins/                           # one directory per plugin
    ├── phoenix-security-review/       # AppSec review suite (6 skills)
    ├── phoenix-readiness-reviews/     # plan + production review gates (2 skills)
    ├── phoenix-sast-rules/            # opengrep/semgrep rule generation (2 skills)
    ├── phoenix-cti-search/            # threat intel search (2 skills + CLI + MCP)
    ├── phoenix-prd-pipeline/          # PRD generator + 12 pipeline roles (13 skills)
    └── phoenix-docs-research/         # documenter, NotebookLM, research (3 skills)
```

Every plugin has the same shape:

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json                    # required — the plugin manifest
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md                   # required — frontmatter + instructions
│       ├── references/                # optional — files the skill reads on demand
│       └── scripts/                   # optional — executables the skill runs
├── commands/                          # optional — slash commands
├── agents/                            # optional — subagents
├── hooks/                             # optional — hook scripts
├── dist/                              # optional — packaged .skill bundles for claude.ai
└── README.md                          # what this plugin is, and how to use it
```

### Key Concepts

- **Marketplace** — the single `.claude-plugin/marketplace.json` at the repository root. It
  lists every plugin. `/plugin marketplace add` reads this and nothing else.
- **Plugin** — a distributable unit with its own `.claude-plugin/plugin.json`. Users install
  a plugin, not a skill.
- **Skill** — one directory holding a `SKILL.md`. It is an instruction-based workflow, and it
  also becomes a slash command named after the directory.
- **Command** — a thin `commands/*.md` wrapper that routes to a skill with a shorter name
  and an argument hint.
- **Agent** — a subagent definition in `agents/*.md` that a skill can dispatch.

**Every new skill goes inside a plugin.** There is no top-level `skills/` directory any more.
Pick the plugin whose theme fits, or propose a new plugin in your pull request.

## Adding a New Skill

Skills are instruction-based workflows that guide Claude Code's behavior. They don't execute code directly but can reference plugins for tool execution.

### Step 1: Create the Skill Directory Inside a Plugin

Pick the plugin your skill belongs to, then create the directory under its `skills/`:

```bash
mkdir -p plugins/phoenix-security-review/skills/your-skill-name
cd plugins/phoenix-security-review/skills/your-skill-name
```

The directory name becomes the slash command, so use lowercase and hyphens — no spaces, no
capitals. It must match the `name:` in the frontmatter.

### Step 2: Create SKILL.md

Create `SKILL.md` with the following structure:

```markdown
---
name: your-skill-identifier
description: >
  Clear description of what the skill does, when to use it, and what triggers it.
  Include key phrases that should activate the skill (e.g., "search for vulnerabilities",
  "analyze threat intelligence", "review security posture").
---

# Your Skill Display Name

Brief overview of the skill's purpose and capabilities.

---

## Workflow

```
1. Step one of the workflow
2. Step two of the workflow
3. Step three of the workflow
```

---

## [Additional Sections]

Add sections as needed:
- Query Parsing
- Domain Selection
- Output Formats
- Integration Points
- Error Handling

---

## Installation

How to install and configure this skill.

---

## Error Handling

| Condition | Behaviour |
|-----------|-----------|
| Error case 1 | How to handle it |
| Error case 2 | How to handle it |
```

### Step 3: Create README.md

Create a user-facing `README.md`:

```markdown
# Your Skill Name

Brief description of what the skill does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

Ships inside the `phoenix-<plugin>` plugin:

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
/plugin install phoenix-<plugin>@phoenix-security
```

Or copy just this skill in:

```bash
cp -r plugins/phoenix-<plugin>/skills/your-skill-name ~/.claude/skills/
```

## Usage

Describe how to use the skill with examples:

```
Ask Claude: "Search for vulnerabilities in package X"
Ask Claude: "Analyze threat actor Y"
```

## Configuration

List any configuration requirements or environment variables.

## Examples

Provide real-world examples of the skill in action.

## Troubleshooting

Common issues and solutions.
```

### Step 4: Validate

A skill needs no installer. It is distributed by the plugin it lives in. What it does need is
frontmatter that parses:

```bash
claude plugin validate --strict plugins/phoenix-security-review/skills
```

`--strict` fails on unrecognised fields and missing metadata. Fix everything it reports
before opening a pull request.

**Stay inside the Agent Skills spec.** Only `name`, `description` and `allowed-tools` are
portable. Add a Claude Code-only field such as `argument-hint`, `context: fork` or
`disable-model-invocation` and the same folder will no longer upload to claude.ai — it fails
with a hard error rather than ignoring the field.

**Reference bundled files by variable, never by an absolute path.** `${CLAUDE_SKILL_DIR}`
resolves to the skill's own directory at every install level:

```markdown
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/your_script.sh *)
```

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/your_script.sh /path/to/target
```

Inside a `commands/*.md` file, use `${CLAUDE_PLUGIN_ROOT}` instead — it resolves to the
plugin's root directory.

Make any script executable and commit that bit:

```bash
chmod +x plugins/<plugin>/skills/<skill>/scripts/your_script.sh
git update-index --chmod=+x plugins/<plugin>/skills/<skill>/scripts/your_script.sh
```

### Step 5: Update the Documentation

Three places, all in the repository root `README.md`:

1. The **All 27 skills** table — add a row with the skill, its plugin and one line of
   description. Update the heading count.
2. The plugin's row in **The six plugins** table — bump its skill count.
3. The plugin's own `plugins/<plugin>/README.md`.

If the skill changes what the plugin does, update the `description` in
`plugins/<plugin>/.claude-plugin/plugin.json` **and** the matching entry in
`.claude-plugin/marketplace.json`. Those two descriptions are what users read before they
install, and `claude plugin tag` will fail if a plugin manifest and its marketplace entry
disagree.

## Adding a New Plugin

Plugins provide executable functionality via MCP servers and CLI tools.

A plugin is the unit users install. Add one when your work is a new theme rather than another
skill inside an existing theme.

### Step 1: Create the Plugin Directory and Manifest

```bash
mkdir -p plugins/your-plugin-name/.claude-plugin
mkdir -p plugins/your-plugin-name/skills
cd plugins/your-plugin-name
```

Write `.claude-plugin/plugin.json`. This file is required — without it the directory is not a
plugin:

```json
{
  "$schema": "https://www.schemastore.org/claude-code-plugin-manifest.json",
  "name": "your-plugin-name",
  "version": "1.0.0",
  "description": "One or two sentences a user reads before installing. Say what it does, not what it is.",
  "author": { "name": "Your Name", "email": "you@example.com" },
  "homepage": "https://github.com/Security-Phoenix-demo/security-skills-claude-code",
  "repository": "https://github.com/Security-Phoenix-demo/security-skills-claude-code",
  "license": "MIT",
  "keywords": ["security", "your", "keywords"]
}
```

`name` must match the directory name.

### Step 1b: Register It in the Marketplace

A plugin nobody can find is not installable. Add an entry to
`.claude-plugin/marketplace.json` at the repository root:

```json
{
  "name": "your-plugin-name",
  "source": "./plugins/your-plugin-name",
  "description": "Same description as the plugin manifest.",
  "category": "security",
  "keywords": ["security", "your", "keywords"]
}
```

Then prove both manifests parse:

```bash
claude plugin validate .
claude plugin validate plugins/your-plugin-name
```

A plugin holding only skills is finished at this point. The Node CLI and MCP server steps
below apply only if your plugin ships executable tooling.

### Step 2: Create package.json

```json
{
  "name": "your-plugin-name",
  "version": "1.0.0",
  "description": "Brief description of your plugin",
  "main": "index.js",
  "bin": {
    "your-plugin": "./index.js"
  },
  "scripts": {
    "test": "node index.js --dry-run"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "chalk": "^4.1.2",
    "commander": "^11.0.0",
    "dotenv": "^16.3.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### Step 3: Create index.js (CLI)

```javascript
#!/usr/bin/env node

const { Command } = require('commander');
const chalk = require('chalk');
require('dotenv').config();

const program = new Command();

program
  .name('your-plugin')
  .description('Your plugin description')
  .version('1.0.0')
  .option('-q, --query <query>', 'Query to process')
  .option('--dry-run', 'Test without executing')
  .parse(process.argv);

const options = program.opts();

async function main() {
  try {
    console.log(chalk.blue('Processing query:'), options.query);
    
    // Your plugin logic here
    
    console.log(chalk.green('✓ Complete'));
  } catch (error) {
    console.error(chalk.red('Error:'), error.message);
    process.exit(1);
  }
}

main();
```

### Step 4: Create mcp-server.js

```javascript
#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');

// Define your MCP tools
const tools = [
  {
    name: 'your_tool_name',
    description: 'What your tool does',
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Query parameter'
        }
      },
      required: ['query']
    }
  }
];

// Create server
const server = new Server(
  {
    name: 'your-plugin-name',
    version: '1.0.0'
  },
  {
    capabilities: {
      tools: {}
    }
  }
);

// Handle tool calls
server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;
  
  if (name === 'your_tool_name') {
    // Your tool implementation
    return {
      content: [
        {
          type: 'text',
          text: 'Tool result'
        }
      ]
    };
  }
  
  throw new Error(`Unknown tool: ${name}`);
});

// Start server
const transport = new StdioServerTransport();
server.connect(transport);
```

### Step 5: Create .env.example

```bash
# Required API keys
YOUR_API_KEY=your_api_key_here

# Optional configuration
YOUR_OPTION=default_value
```

### Step 6: Dependencies, Not an Installer

Do not write an `install.sh`. Users install through the marketplace, and a plugin directory is
managed by Claude Code. What you do need:

- A `package.json` with pinned dependency ranges and `"engines": { "node": ">=18.0.0" }`.
- A `.env.example` listing every variable, with no real values. Never commit a `.env`.
- One clear error message per missing prerequisite. "Cannot find module 'axios' — run
  `npm install --omit=dev` in this plugin directory" beats a stack trace.

Document the one-time setup in the plugin's `README.md` and in
[`MARKETPLACE_INSTALL.md`](MARKETPLACE_INSTALL.md) under **Per-plugin setup**.

**Never write into the plugin directory anything a user would hate to lose.** `/plugin update`
replaces that directory. Credentials, saved sessions and libraries belong somewhere the update
does not reach, or the README must warn the user to back them up.

### Step 7: Create README.md

Document your plugin thoroughly:

```markdown
# Your Plugin Name

Description of what your plugin does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

```
/plugin marketplace add Security-Phoenix-demo/security-skills-claude-code
/plugin install your-plugin-name@phoenix-security
```

Then, once, for the bundled CLI and MCP server:

```bash
MP=~/.claude/plugins/marketplaces/phoenix-security
cd "$MP/plugins/your-plugin-name"
npm install --omit=dev
cp .env.example .env    # then add your keys
```

## Configuration

Required environment variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `YOUR_API_KEY` | Yes | Your API key from provider |

## Usage

### As CLI Tool
```bash
node index.js --query "your query"
```

### As MCP Tool
In Claude Code, ask naturally:
> "Use your plugin to do X"

### Available Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--query` | Query to process | Required |
| `--dry-run` | Test mode | false |

## Examples

Provide real examples.

## Troubleshooting

Common issues and solutions.
```

### Step 8: Update Main Documentation

Add your plugin to the main `README.md`:

```markdown
### Plugins
- **[Your Plugin Name](plugins/your-plugin-name/)** - Brief description
```

## Adding a Feature-Descriptor Role

Feature-descriptor roles are specialised stages in the Phoenix Pipeline. Each role is a skill
directory inside the `phoenix-prd-pipeline` plugin.

### Step 1: Create the Skill Directory

```bash
mkdir -p plugins/phoenix-prd-pipeline/skills/phoenix-your-role
```

Follow the naming convention `phoenix-<role-name>`. The directory name, the `name:` in the
frontmatter, and the slash command are all the same string.

### Step 2: Define the Role

```markdown
---
name: phoenix-your-role
description: >
  One-line description of what this pipeline role does and when it activates.
---

## Role: Your Role Name

Brief description of the role's purpose within the pipeline.

## Inputs
- What this role receives from upstream roles

## Process
1. Step one
2. Step two
3. Step three

## Outputs
- What this role produces for downstream roles

## Integration
- How this role fits into the Phoenix Pipeline sequence
```

### Step 3: Update Documentation

1. Add the role to the Phoenix Pipeline table in `README.md`
2. Reference it in the pipeline flow diagram
3. Update the `OVERARCHING-phoenix-pipeline-navigator.skill` if the role changes the pipeline sequence

---

## Documentation Standards

### Required Documentation

Every contribution must include:

1. **README.md** - User-facing documentation
   - Clear description
   - Installation instructions (all methods)
   - Configuration requirements
   - Usage examples
   - Troubleshooting section

2. **SKILL.md** (for skills) - Agent instructions
   - Frontmatter with name and description
   - Workflow steps
   - Error handling
   - Integration points

3. **`.claude-plugin/plugin.json`** (for a new plugin) - the plugin manifest
   - `name` matching the directory name
   - A `description` a user can decide from
   - A matching entry in the root `.claude-plugin/marketplace.json`

4. **.env.example** (for plugins) - Environment template
   - All required variables
   - Comments explaining each variable
   - Example values (non-sensitive)

### Documentation Style

- Use clear, concise language
- Include code examples for all features
- Use tables for reference information
- Link between related documentation
- Keep formatting consistent with existing docs

## Testing Your Contribution

Test against a local marketplace. Edits land immediately, so this is the loop for real work.

### 1. Validate the manifests and the frontmatter

```bash
claude plugin validate .                                 # the marketplace manifest
claude plugin validate plugins/your-plugin-name          # the plugin manifest
claude plugin validate --strict plugins/*/skills         # every skill's frontmatter
```

### 2. Install from your checkout

```bash
claude plugin marketplace add "$(pwd)"
claude plugin install your-plugin-name@phoenix-security
```

If `phoenix-security` is already registered from GitHub, remove it first —
`claude plugin marketplace remove phoenix-security` — since two marketplaces cannot share a
name.

### 3. Confirm the component actually loaded

```bash
claude plugin details your-plugin-name
```

Your skill, command and agent must appear in the component inventory. If a skill is missing,
its frontmatter did not parse. Check the projected token cost too: the always-on figure is
what your `description` adds to **every** session, so keep it tight.

### 4. Check for name clashes

Two components cannot share a slash name. Compare the inventory against the other five
plugins before you commit. A command that wraps a skill must not reuse the skill's name.

### 5. Exercise it for real

- Trigger it by description — ask the kind of question the `description` promises. If Claude
  does not reach for it, the description is the problem, not the body.
- Trigger it explicitly — `/your-plugin-name:your-skill-name`.
- Run any bundled script by hand and confirm it exits 0 and writes nothing outside its target.
- For a CLI or MCP plugin, test the missing-dependency and missing-key paths and read the
  error message as a new user would.

### 6. Prove the paths survive relocation

Copy the skill into `~/.claude/skills/` and run it again. Anything that breaks was a
hard-coded path — replace it with `${CLAUDE_SKILL_DIR}`.

### Testing Checklist

- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate --strict plugins/*/skills` passes
- [ ] `claude plugin details <plugin>` lists every component you added
- [ ] No slash-name clash with any other plugin in this repository
- [ ] The skill fires from its description, not only from the explicit command
- [ ] Frontmatter uses only `name`, `description`, `allowed-tools`
- [ ] `name:` matches the directory name exactly
- [ ] Bundled paths use `${CLAUDE_SKILL_DIR}` or `${CLAUDE_PLUGIN_ROOT}`, never an absolute path
- [ ] Scripts are committed executable (`git update-index --chmod=+x`)
- [ ] Nothing a user would hate to lose is written inside the plugin directory
- [ ] Plugin manifest and marketplace entry descriptions agree
- [ ] README tables and counts updated
- [ ] No credentials, no `.env`, no `.DS_Store`
- [ ] Works on both macOS and Linux (if possible)

## Submitting a Pull Request

1. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: add your-feature-name"
   ```

   Use conventional commit messages:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation changes
   - `refactor:` - Code refactoring
   - `test:` - Test additions/changes

2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request**:
   - Go to GitHub and create a PR from your fork
   - Fill out the PR template (if available)
   - Describe what your contribution does
   - Link any related issues

4. **PR Description Template**:
   ```markdown
   ## Description
   Brief description of what this PR does.

   ## Type of Change
   - [ ] New skill
   - [ ] New plugin
   - [ ] Bug fix
   - [ ] Documentation update
   - [ ] Other (please describe)

   ## Testing
   - [ ] Tested installation script
   - [ ] Tested CLI interface (if plugin)
   - [ ] Tested MCP interface (if plugin)
   - [ ] Tested in Claude Code
   - [ ] Documentation is accurate

   ## Checklist
   - [ ] Code follows existing style
   - [ ] Documentation is complete
   - [ ] No hardcoded credentials
   - [ ] Install script is idempotent
   - [ ] Examples work as shown
   ```

## Code Review Process

1. **Initial Review**: Maintainers will review your PR within a few days
2. **Feedback**: Address any requested changes
3. **Approval**: Once approved, your PR will be merged
4. **Release**: Your contribution will be included in the next release

### What Reviewers Look For

- Code quality and style consistency
- Documentation completeness and clarity
- Security considerations (no hardcoded secrets)
- Error handling and user experience
- Test coverage and examples
- Compatibility with existing features

## Getting Help

- **Questions**: Open a [GitHub Discussion](https://github.com/YOUR_USERNAME/security-skills-claude-code/discussions)
- **Bugs**: Open a [GitHub Issue](https://github.com/YOUR_USERNAME/security-skills-claude-code/issues)
- **Ideas**: Share in Discussions or open a feature request issue

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to Security Skills for Claude Code! Built and maintained by [Phoenix Security](https://phoenix.security) for the global security community.
