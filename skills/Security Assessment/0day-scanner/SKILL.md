# 0-Day Vulnerability Scanner Skill

## Purpose

Analyze code changes (commits, PRs, files) for potential zero-day security vulnerabilities using LLM-powered analysis. This skill provides conversational access to the 0-Day Scanner Agent with real-time token monitoring and knowledge graph integration.

> **Stack-aware fallback (when MCP unavailable):** if `analyze_for_zero_day_vulnerabilities` is not reachable, detect the changed files' language(s) and load the matching reference pack from
> `../Security-automated-claude-skills/.claude/skills/security-reviewer/languages/{python,javascript-typescript,go,java,rust,ruby,dotnet}.md`
> to drive a diff-only review using the assistant's built-in tools. Apply the 8-point check from
> `../Security-automated-claude-skills/.claude/skills/security-reviewer/SKILL.md` scoped to the diff.

## When to Use

- User asks to "scan for vulnerabilities" or "check for security issues"
- User mentions "0-day", "zero-day", or "security analysis"
- User wants to analyze a specific commit, PR, or file for security
- User requests vulnerability assessment during code review

## Workflow

### 1. Parse User Request

Extract:
- **Target**: Commit SHA, PR number, file path, or branch
- **Scope**: Single commit (light), multiple commits (standard), or full branch (deep)
- **Budget**: Max cost willing to spend (default: $0.10 for light mode)
- **Options**: Link to graph, save to DB, return reasoning

### 2. Invoke Scanner

Use MCP tool `analyze_for_zero_day_vulnerabilities`:

```json
{
  "commit_sha": "abc123def456",
  "mode": "light",
  "max_cost_usd": 0.10,
  "link_to_graph": true,
  "save_to_db": true,
  "stream_tokens": true,
  "return_reasoning": true
}
```

### 3. Monitor Progress

- Stream token usage updates to user
- Report estimated cost and time remaining
- Show findings as they're discovered

### 4. Present Results

**If vulnerabilities found**:
- Summarize each vulnerability with severity and type
- Show affected code and proof of concept
- Display knowledge graph context (affected symbols, blast radius)
- Provide remediation suggestions

**If no vulnerabilities found**:
- Confirm analysis completed successfully
- Report token usage and cost
- Suggest next steps (e.g., analyze related commits)

### 5. Follow-Up Actions

Offer to:
- Analyze related commits or PRs
- Set up continuous monitoring for the repository
- Link findings to existing CVEs
- Generate detailed security report

## Example Interactions

### Example 1: Quick Commit Analysis

**User**: "Analyze commit abc123 for security vulnerabilities"

**Assistant**:
```
I'll analyze commit abc123 for potential zero-day vulnerabilities using light-touch mode (estimated cost: $0.05).

[Analyzing commit abc123...]
Token usage: 3,500 input + 800 output = 4,300 total ($0.043)

🔴 **CRITICAL VULNERABILITY FOUND**

**Type**: SQL Injection
**Severity**: Critical
**Confidence**: 85%

**Description**: SQL injection vulnerability found where user input is directly concatenated into a query string without parameterization.

**Vulnerable Code**:
```python
query = f"SELECT * FROM users WHERE id={user_id}"  # VULNERABLE: unsanitized input
```

**Proof of Concept**:
```
' OR 1=1 --
```

**Knowledge Graph Context**:
- Affected symbols: `getUserById`, `authenticateUser`
- Entry point paths: `handleRequest` → `authenticateUser` → `getUserById`
- Blast radius: 5 direct callers, 23 transitive callers

**Remediation**: Use parameterized queries or prepared statements to prevent SQL injection.

Would you like me to:
1. Analyze related commits for similar issues
2. Set up continuous monitoring for this repository
3. Generate a detailed security report
```

### Example 2: PR Review

**User**: "Check PR #1234 for security issues, budget $0.20"

**Assistant**:
```
I'll analyze PR #1234 for security vulnerabilities with a budget of $0.20.

[Fetching PR #1234: "Add user authentication"]
[Found 3 commits to analyze]

[Analyzing commit 1/3...]
Token usage: 4,200 tokens ($0.042)
✅ No vulnerabilities found

[Analyzing commit 2/3...]
Token usage: 5,100 tokens ($0.051)
🟡 **MEDIUM VULNERABILITY FOUND**

**Type**: Weak Cryptography
**Severity**: Medium
**Description**: Uses MD5 for password hashing instead of bcrypt/scrypt

[Analyzing commit 3/3...]
Token usage: 3,800 tokens ($0.038)
✅ No vulnerabilities found

**Summary**:
- Total commits analyzed: 3
- Vulnerabilities found: 1 (Medium)
- Total cost: $0.131 / $0.20 budget
- Analysis time: 45 seconds

Would you like details on the weak cryptography finding?
```

### Example 3: File Analysis

**User**: "Is src/auth.ts secure?"

**Assistant**:
```
I'll analyze the current state of src/auth.ts for security vulnerabilities.

[Reading file: src/auth.ts]
[Analyzing for vulnerabilities...]

Token usage: 2,800 input + 600 output = 3,400 total ($0.034)

✅ **NO CRITICAL VULNERABILITIES FOUND**

However, I noticed some security best practices that could be improved:

1. **Rate Limiting**: No rate limiting on login attempts (potential brute force)
2. **Session Timeout**: Session timeout is set to 24 hours (consider reducing)
3. **Error Messages**: Error messages reveal whether username exists (information disclosure)

These are not exploitable vulnerabilities but could strengthen security posture.

Would you like me to:
1. Analyze the git history of this file for past vulnerabilities
2. Check related authentication files
3. Generate a security hardening checklist
```

### Example 4: Full Repository Analysis

**User**: "Scan the entire repository for 0-day vulnerabilities in the last 30 days, budget $5"

**Assistant**:
```
I'll perform a comprehensive security audit of the repository, analyzing all commits from the last 30 days with a budget of $5.00.

[Fetching commits from main and develop branches...]
[Found 87 commits to analyze]
[Estimated cost: $4.35]

[Progress: 10/87 commits analyzed (11%)]
Token usage: 3,200 tokens ($0.48)
Findings: 1 (Medium)

[Progress: 25/87 commits analyzed (29%)]
Token usage: 8,100 tokens ($1.22)
Findings: 2 (1 High, 1 Medium)

[Progress: 50/87 commits analyzed (57%)]
Token usage: 16,500 tokens ($2.48)
Findings: 4 (1 Critical, 1 High, 2 Medium)

🔴 **CRITICAL VULNERABILITY FOUND** (Commit: def456)
**Type**: Command Injection
**File**: src/utils/exec.ts
**Blast Radius**: 12 direct callers, 45 transitive

[Progress: 75/87 commits analyzed (86%)]
Token usage: 24,800 tokens ($3.72)
Findings: 5 (1 Critical, 2 High, 2 Medium)

[Progress: 87/87 commits analyzed (100%)]
✅ **ANALYSIS COMPLETE**

**Summary**:
- Total commits analyzed: 87
- Date range: 2026-01-28 to 2026-02-27
- Branches: main, develop
- Total cost: $4.18 / $5.00 budget
- Analysis time: 12 minutes

**Findings**:
- 🔴 Critical: 1
- 🟠 High: 2
- 🟡 Medium: 2
- 🟢 Low: 0

**Top Vulnerabilities**:
1. Command Injection in src/utils/exec.ts (Critical)
2. SQL Injection in src/db/queries.ts (High)
3. XSS in src/components/UserProfile.tsx (High)
4. Weak Cryptography in src/auth/hash.ts (Medium)
5. Path Traversal in src/api/files.ts (Medium)

**Affected Files**: 5 files across 12 modules
**Knowledge Graph**: All vulnerabilities linked to affected symbols

Would you like me to:
1. Generate a detailed security report with remediation steps
2. Analyze specific vulnerabilities in depth
3. Set up continuous monitoring for this repository
4. Export findings to CSV/JSON
```

## Key APIs

### MCP Tool

```typescript
analyze_for_zero_day_vulnerabilities({
  // Input source (one required)
  commit_sha?: string,
  pr_number?: number,
  file_path?: string,
  diff?: string,
  full_repo?: boolean,              // Analyze entire repository
  
  // Full repo options (when full_repo=true)
  max_commits?: number,             // Max commits to analyze (default: 100)
  since_date?: string,              // ISO 8601 date (e.g., "2026-01-01T00:00:00Z")
  since_days?: number,              // Scan last N days (alternative to since_date)
  branches?: string[],              // Branches to scan (default: ["main", "master"])
  
  // Analysis options
  mode: "light" | "standard" | "deep",
  max_cost_usd?: number,            // Budget limit (default: 0.10 for single, 5.00 for full repo)
  provider?: "openai" | "anthropic" | "gemini",
  model?: string,
  
  // Integration
  link_to_graph?: boolean,
  save_to_db?: boolean,
  stream_tokens?: boolean,
  return_reasoning?: boolean
})
```

### REST API

```bash
# Light-touch analysis
POST /api/v1/zeroday/analyze/light
{
  "commit_sha": "abc123",
  "repo_url": "https://github.com/owner/repo",
  "mode": "light",
  "max_cost_usd": 0.10
}

# Full repository analysis
POST /api/v1/zeroday/analyze/full-repo
{
  "repo_url": "https://github.com/owner/repo",
  "mode": "standard",
  "max_commits": 100,
  "since_days": 30,
  "branches": ["main", "develop"],
  "max_cost_usd": 5.00,
  "link_to_graph": true,
  "stream_tokens": true
}

# Programmatic launch
POST /api/v1/zeroday/scans/launch
{
  "scan_type": "commit",
  "target": {"repo_url": "...", "commit_sha": "..."},
  "options": {"mode": "light", "max_cost_usd": 0.50}
}

# Get scan status
GET /api/v1/zeroday/scans/{scan_id}

# Stream updates (SSE)
GET /api/v1/zeroday/scans/{scan_id}/stream
```

## Configuration

### Default Settings

- **Mode**: light (for chat invocations)
- **Budget**: $0.10 per analysis
- **Provider**: openai
- **Model**: gpt-4o-mini (light mode), gpt-4o (standard/deep)
- **Link to Graph**: true
- **Save to DB**: true
- **Stream Tokens**: true

### User Preferences

Users can override defaults:
```
"Analyze commit abc123 using Claude Sonnet, budget $0.50"
"Scan PR #1234 in deep mode, don't save to database"
```

## Best Practices

1. **Start with Light Mode**: Use light mode for interactive chat analysis
2. **Set Budget Limits**: Always specify max_cost_usd to prevent runaway costs
3. **Stream Token Usage**: Enable streaming for real-time cost visibility
4. **Link to Graph**: Enable graph linking for blast radius analysis
5. **Return Reasoning**: Include LLM reasoning for transparency

## Integration Points

- **Phoenix Code Analyzer**: Links findings to knowledge graph
- **CVE Intelligence**: Correlates findings with known CVEs
- **SAST Agent**: Complements static analysis with 0-day detection
- **Threat Modeling**: Feeds vulnerabilities into threat models

## Limitations

- **False Positives**: LLM may flag defensive coding as vulnerabilities
- **Cost**: Deep analysis can be expensive ($0.20-$1.00 per scan)
- **Context**: Limited to commit diff (no full codebase context in light mode)
- **Rate Limits**: Subject to GitHub API and LLM provider rate limits

## Example Cypher Queries

```cypher
-- Get all 0-day vulnerabilities in repository
MATCH (v:Vulnerability)
WHERE v.detected_at > datetime() - duration({days: 7})
RETURN v.vuln_type, v.severity, v.commit_sha

-- Find functions with critical vulnerabilities
MATCH (v:Vulnerability {severity: 'critical'})-[:AFFECTS]->(f:Function)
RETURN f.name, f.filePath, v.vuln_type

-- Calculate vulnerability density by file
MATCH (v:Vulnerability)-[:AFFECTS]->(s)
WITH s.filePath AS file, COUNT(v) AS vuln_count
RETURN file, vuln_count
ORDER BY vuln_count DESC
```
