# Contributing to Security Skills for Claude Code

Thank you for your interest in contributing! This guide will help you add new skills, plugins, or improve existing ones.

## Table of Contents

- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
- [Adding a New Skill](#adding-a-new-skill)
- [Adding a New Plugin](#adding-a-new-plugin)
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
├── README.md                 # Main documentation
├── CONTRIBUTING.md           # This file
├── .cursor/rules/AGENTS.md   # Agent maintenance guide
├── skills/                   # Skills directory
│   └── [skill-name]/
│       ├── SKILL.md          # Skill specification
│       ├── README.md         # User documentation
│       └── install.sh        # Installation script
└── plugins/                  # Plugins directory
    └── [plugin-name]/
        ├── README.md         # Plugin documentation
        ├── index.js          # CLI entry point
        ├── mcp-server.js     # MCP server
        ├── package.json      # Dependencies
        ├── install.sh        # Installation script
        └── .env.example      # Environment template
```

## Adding a New Skill

Skills are instruction-based workflows that guide Claude Code's behavior. They don't execute code directly but can reference plugins for tool execution.

### Step 1: Create Skill Directory

```bash
mkdir -p skills/your-skill-name
cd skills/your-skill-name
```

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

### Via Install Script
```bash
cd skills/your-skill-name
bash install.sh
```

### Manual Installation
```bash
cp -r skills/your-skill-name ~/.claude/skills/
# or for Cursor
cp -r skills/your-skill-name ~/.cursor/skills/
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

### Step 4: Create install.sh

Create an installation script:

```bash
#!/bin/bash
set -e

SKILL_NAME="your-skill-name"
INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME"

echo "Installing $SKILL_NAME skill..."

# Check if already installed
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  $SKILL_NAME is already installed at $INSTALL_DIR"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# Create directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying skill files..."
cp SKILL.md "$INSTALL_DIR/"
cp README.md "$INSTALL_DIR/"
cp install.sh "$INSTALL_DIR/"

# Copy any additional files (data, configs, etc.)
if [ -d "data" ]; then
    cp -r data "$INSTALL_DIR/"
fi

echo "✓ $SKILL_NAME installed successfully to $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load the skill"
echo "  2. Try asking: 'Your example query here'"
echo ""
echo "For Cursor users, also copy to:"
echo "  cp -r $INSTALL_DIR ~/.cursor/skills/"
```

Make it executable:
```bash
chmod +x install.sh
```

### Step 5: Update Main Documentation

Add your skill to the main `README.md`:

```markdown
### Skills
- **[Your Skill Name](skills/your-skill-name/)** - Brief description
```

## Adding a New Plugin

Plugins provide executable functionality via MCP servers and CLI tools.

### Step 1: Create Plugin Directory

```bash
mkdir -p plugins/your-plugin-name
cd plugins/your-plugin-name
```

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

### Step 6: Create install.sh

```bash
#!/bin/bash
set -e

PLUGIN_NAME="your-plugin-name"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"

echo "Installing $PLUGIN_NAME plugin..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js 18+ is required but not installed."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "Error: Node.js 18+ is required (found v$NODE_VERSION)"
    exit 1
fi

# Check if already installed
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  $PLUGIN_NAME is already installed at $INSTALL_DIR"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# Create directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying plugin files..."
cp -r ./* "$INSTALL_DIR/"

# Install dependencies
echo "Installing dependencies..."
cd "$INSTALL_DIR"
npm install

# Setup environment
if [ ! -f "$INSTALL_DIR/.env" ]; then
    cp .env.example .env
    echo "⚠️  Created .env file - please add your API keys"
fi

echo "✓ $PLUGIN_NAME installed successfully to $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit $INSTALL_DIR/.env and add your API keys"
echo "  2. Test with: cd $INSTALL_DIR && node index.js --dry-run"
echo "  3. Restart Claude Code to load the MCP server"
```

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

```bash
cd plugins/your-plugin-name
bash install.sh
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

3. **install.sh** - Automated installation
   - Prerequisite checks
   - Idempotent (safe to run multiple times)
   - Clear success/error messages
   - Next steps after installation

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

### For Skills

1. **Install the skill**:
   ```bash
   bash install.sh
   ```

2. **Verify installation**:
   ```bash
   ls ~/.claude/skills/your-skill-name/
   ```

3. **Test in Claude Code**:
   - Restart Claude Code
   - Ask a query that should trigger your skill
   - Verify the skill activates and works correctly

### For Plugins

1. **Install the plugin**:
   ```bash
   bash install.sh
   ```

2. **Test CLI interface**:
   ```bash
   cd ~/.claude/plugins/your-plugin-name
   node index.js --dry-run
   node index.js --query "test query"
   ```

3. **Test MCP interface**:
   - Restart Claude Code
   - Ask Claude to use your plugin
   - Verify the tool is called correctly

4. **Test error handling**:
   - Try invalid inputs
   - Test with missing environment variables
   - Verify error messages are clear

### Testing Checklist

- [ ] Installation script runs without errors
- [ ] All documentation is clear and accurate
- [ ] Examples work as shown
- [ ] Error messages are helpful
- [ ] No hardcoded paths or credentials
- [ ] Works on both macOS and Linux (if possible)
- [ ] Follows existing code style

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

Thank you for contributing to Security Skills for Claude Code! 🎉
