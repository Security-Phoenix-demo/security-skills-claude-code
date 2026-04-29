# Comprehensive Security Assessment Skill

## Purpose

Run comprehensive security assessment covering OWASP Top 10 2025 and ASVS Level 1 requirements. This skill provides automated, full-codebase security analysis with real-time token monitoring, knowledge graph integration, and automated test generation.

> **On-disk fallback (when MCP unavailable):** if `run_security_assessment` is not reachable, use the bundled checklists at
> `../Security-automated-claude-skills/.claude/skills/security-reviewer/checklists/owasp-asvs.md` (OWASP Top 10 ↔ ASVS L1 mapping) and
> `../Security-automated-claude-skills/.claude/skills/security-reviewer/checklists/endpoint-checklist.md` (per-endpoint review template),
> plus the language reference packs at `../Security-automated-claude-skills/.claude/skills/security-reviewer/languages/*.md`,
> to drive the workflow with the assistant's built-in tools (Read/Grep/Glob/Bash).

## When to Use

- User asks to "run a security assessment" or "security audit"
- User mentions "OWASP Top 10" or "ASVS"
- User requests "security check" or "vulnerability assessment"
- User clicks the 🛡️ Security Assessment quick access button
- User wants comprehensive security analysis before release

## Workflow

### 1. Parse User Request

Extract:
- **Scope**: Full repo, backend only, frontend only, or specific OWASP categories
- **Budget**: Max cost willing to spend (default: $10.00)
- **Options**: Generate tests, link to graph, check dependencies, report format

### 2. Invoke Assessment

Use MCP tool `run_security_assessment`:

```json
{
  "repo_path": "/path/to/repo",
  "max_cost_usd": 10.0,
  "link_to_graph": true,
  "generate_tests": true,
  "check_dependencies": true,
  "stream_progress": true,
  "report_format": "markdown"
}
```

### 3. Monitor Progress

Stream real-time updates to user:
- Stack detection results
- Checks completed (X/24)
- Findings discovered
- Token usage and cost
- Estimated time remaining

### 4. Present Results

**Executive Summary**:
- Total findings by severity
- OWASP Top 10 breakdown
- ASVS L1 compliance percentage
- Top 5 critical risks

**Detailed Findings**:
- Findings grouped by OWASP category
- Each finding includes:
  - Vulnerable code snippet
  - Attack scenario
  - Proof of concept
  - Remediation guidance
  - Generated test template
  - Knowledge graph context (blast radius)

**Compliance Report**:
- ASVS L1 compliance matrix
- Failed requirements
- Remediation roadmap

### 5. Follow-Up Actions

Offer to:
- Generate and save security test suite
- Export detailed report (Markdown/HTML/PDF)
- Set up continuous security monitoring
- Analyze specific findings in depth
- Create remediation tickets

## Example Interactions

### Example 1: Quick Assessment

**User**: "Run a security assessment on this repository"

**Assistant**:
```
I'll run a comprehensive security assessment covering OWASP Top 10 and ASVS Level 1 (estimated cost: $8-10, duration: 15-20 minutes).

[Detecting stack...]
✅ Stack detected:
- Backend: Kotlin/Spring Boot 2.7.18 with Spring Security
- Frontend: Angular 20 with NgRx
- ORM: JPA/Hibernate
- Auth: JWT with Nimbus JOSE

[Running 24 security checks...]

[Progress: 5/24 checks completed (21%)]
Token usage: 15,000 tokens ($0.75)
Findings: 3 (1 Critical, 2 High)

🔴 **CRITICAL**: Missing Authentication on Admin Endpoint
File: src/main/kotlin/com/example/AdminController.kt:45
OWASP: A01 (Broken Access Control)
ASVS: 4.1.1, 4.1.3

[Progress: 12/24 checks completed (50%)]
Token usage: 45,000 tokens ($2.25)
Findings: 8 (2 Critical, 4 High, 2 Medium)

🔴 **CRITICAL**: SQL Injection via String Concatenation
File: src/main/kotlin/com/example/UserRepository.kt:78
OWASP: A03 (Injection)
ASVS: 5.3.4

[Progress: 24/24 checks completed (100%)]
✅ **ASSESSMENT COMPLETE**

**Executive Summary**:
- Total findings: 23
- 🔴 Critical: 2
- 🟠 High: 7
- 🟡 Medium: 10
- 🟢 Low: 4

**OWASP Top 10 Breakdown**:
- A01 Broken Access Control: 5 findings
- A02 Cryptographic Failures: 3 findings
- A03 Injection: 8 findings
- A04 Insecure Design: 2 findings
- A05 Security Misconfiguration: 3 findings
- A06 Vulnerable Components: 1 finding
- A07 Authentication Failures: 1 finding
- A08 Software and Data Integrity Failures: 0 findings
- A09 Security Logging and Monitoring Failures: 0 findings
- A10 Server-Side Request Forgery (SSRF): 0 findings

**ASVS L1 Compliance**: 84.7% (127/150 requirements passed)

**Token Usage**: 160,000 tokens ($8.20)
**Analysis Time**: 18 minutes

**Top 5 Risks**:
1. Missing Authentication on Admin Endpoint (CRITICAL)
2. SQL Injection via String Concatenation (CRITICAL)
3. XSS via Sanitizer Bypass in Dashboard (HIGH)
4. JWT Expired Token Accepted (HIGH)
5. Weak Cryptography: MD5 Password Hashing (HIGH)

Would you like me to:
1. Generate security test suite (23 tests)
2. Export detailed report (Markdown/HTML/PDF)
3. Show detailed analysis of critical findings
4. Create remediation roadmap
```

### Example 2: Targeted Assessment

**User**: "Check for SQL injection vulnerabilities, budget $2"

**Assistant**:
```
I'll run a targeted assessment for SQL injection (OWASP A03) with a budget of $2.00.

[Detecting stack...]
Backend: Kotlin/Spring Boot with JPA/Hibernate and MyBatis

[Analyzing SQL injection vectors...]

[Check 1/2: Primary ORM (JPA/Hibernate)]
Token usage: 8,500 tokens ($0.43)
✅ No SQL injection found in JPA queries

[Check 2/2: Secondary ORM (MyBatis)]
Token usage: 12,000 tokens ($0.60)
🟠 **HIGH**: SQL Injection in MyBatis XML Mapper

**Finding Details**:
File: src/main/resources/mappers/UserMapper.xml:34
Severity: High
OWASP: A03 (Injection)
ASVS: 5.3.4, 5.3.5

**Vulnerable Code**:
```xml
<select id="findByStatus">
  SELECT * FROM users WHERE status = ${status}
</select>
```

**Attack Scenario**: Attacker can inject SQL via status parameter: ' OR 1=1--

**Proof of Concept**: status=' OR 1=1--

**Remediation**: Use #{status} instead of ${status} for parameterized query

**Knowledge Graph Context**:
- Affected symbols: findByStatus, UserService.getUsers
- Blast radius: 3 direct callers, 12 transitive callers

**Generated Test**:
```kotlin
@Test
fun `MyBatis findByStatus rejects SQL injection`() {
    val result = userMapper.findByStatus("' OR 1=1--")
    assertThat(result).isEmpty()
}
```

**Summary**:
- Total findings: 1 (High)
- Total cost: $1.03 / $2.00 budget
- Analysis time: 3 minutes

Would you like me to:
1. Check for other injection types (XSS, command injection)
2. Generate the full security test suite
3. Run a complete OWASP Top 10 assessment
```

### Example 3: Quick Access Button

**User**: [Clicks 🛡️ Security Assessment button]

**System**: [Shows quick options dialog]
```
┌─────────────────────────────────────┐
│     Security Assessment Options     │
├─────────────────────────────────────┤
│ Max Cost (USD): [10.00    ] 💵      │
│ ☑ Generate Security Tests           │
│ ☑ Link to Knowledge Graph           │
│ ☑ Check Dependencies                │
│                                      │
│ [Cancel]              [Run Assessment]│
└─────────────────────────────────────┘
```

**User**: [Clicks "Run Assessment"]

**Assistant**:
```
Starting comprehensive security assessment...

[Detecting stack...]
✅ Backend: Kotlin/Spring Boot
✅ Frontend: Angular 20

[Running 24 security checks...]
[Progress updates stream here...]

[Assessment complete - see Example 1 for full output]
```

## Key APIs

### MCP Tool

```typescript
run_security_assessment({
  repo_path: string,
  backend_only?: boolean,
  frontend_only?: boolean,
  owasp_categories?: string[],
  asvs_chapters?: number[],
  max_cost_usd?: number,
  provider?: "openai" | "anthropic" | "gemini",
  model?: string,
  link_to_graph?: boolean,
  generate_tests?: boolean,
  check_dependencies?: boolean,
  save_to_db?: boolean,
  stream_progress?: boolean,
  report_format?: "markdown" | "html" | "pdf" | "json"
})
```

### REST API

```bash
# Run assessment
POST /api/v1/security-assessment/assessments
{
  "repo_path": "/path/to/repo",
  "options": {
    "max_cost_usd": 10.0,
    "generate_tests": true,
    "link_to_graph": true
  }
}

# Get status
GET /api/v1/security-assessment/assessments/{assessment_id}

# Stream progress (SSE)
GET /api/v1/security-assessment/assessments/{assessment_id}/stream

# Get report
GET /api/v1/security-assessment/assessments/{assessment_id}/report?format=markdown

# Get generated tests
GET /api/v1/security-assessment/assessments/{assessment_id}/tests
```

## Configuration

### Default Settings

- **Budget**: $10.00 per assessment
- **Provider**: openai
- **Model**: gpt-4o (for accuracy)
- **OWASP Categories**: All 10
- **ASVS Chapters**: All (V1-V14)
- **Generate Tests**: true
- **Link to Graph**: true
- **Check Dependencies**: true
- **Stream Progress**: true

### User Overrides

```
"Security assessment with budget $5, backend only"
"Run OWASP Top 10 check without generating tests"
"Assess authentication and authorization only"
```

## Best Practices

1. **Set Realistic Budget**: Full assessment typically costs $8-10
2. **Stream Progress**: Enable streaming for visibility into long-running assessments
3. **Generate Tests**: Always generate tests for immediate remediation validation
4. **Link to Graph**: Enable graph linking for impact analysis
5. **Review Critical First**: Address critical findings before high/medium
6. **Run Periodically**: Quarterly assessments to maintain security posture

## 📈 Risk Matrix Format

**IMPORTANT:** When displaying risk assessments, use a proper risk matrix format, NOT a flowchart.

**✅ CORRECT - Use Markdown Table Matrix:**

| Impact ↓ / Likelihood → | 🟢 Low | 🟡 Medium | 🟠 High | 🔴 Very High |
|------------------------|--------|-----------|---------|--------------|
| 🔴 **Critical** | Medium | High | Critical | **SQL Injection, Command Injection** |
| 🟠 **High** | Low | Medium | **XXE Injection** | Critical |
| 🟡 **Medium** | Low | Medium | High | High |
| 🟢 **Low** | Low | Low | Medium | Medium |

**✅ CORRECT - Use Mermaid Quadrant Chart (Mermaid 10.6+):**
```
%%{init: {'theme': 'dark', 'themeVariables': { 'quadrant1Fill': '#991b1b', 'quadrant2Fill': '#b45309', 'quadrant3Fill': '#166534', 'quadrant4Fill': '#7d6608', 'quadrant1TextFill': '#ffffff', 'quadrant2TextFill': '#ffffff', 'quadrant3TextFill': '#ffffff', 'quadrant4TextFill': '#ffffff'}}}%%
quadrantChart
    title Vulnerability Risk Assessment
    x-axis Low Likelihood --> High Likelihood
    y-axis Low Impact --> High Impact
    quadrant-1 Critical Risk
    quadrant-2 High Risk
    quadrant-3 Low Risk
    quadrant-4 Medium Risk
    SQL Injection: [0.90, 0.95]
    Command Injection: [0.90, 0.95]
    XXE Injection: [0.75, 0.70]
```

**❌ WRONG - Never use flowchart/graph for risk matrix:**
```
graph LR
    subgraph Likelihood
        L1[Low] --> L2[Medium]
    end
```
This creates a flow diagram, NOT a risk matrix. Risk matrices must show 2D positioning (likelihood × impact).

## Integration Points

- **Phoenix Code Analyzer**: Links findings to knowledge graph
- **0-Day Scanner**: Complements with historical vulnerability detection
- **SAST Agent**: Provides comprehensive static analysis
- **Threat Modeling**: Feeds findings into threat models
- **CVE Intelligence**: Correlates findings with known CVEs

## Limitations

- **Manual Review Required**: 44/150 ASVS L1 requirements need human verification
- **False Positives**: LLM may flag defensive coding (typically <15%)
- **Cost**: Full assessment can be expensive ($8-10)
- **Duration**: 15-20 minutes for typical repository
- **Stack Support**: Limited to detected frameworks (Kotlin, Python, Go, Java, Node, Angular, React, Vue)

## Example Cypher Queries

```cypher
-- Get all security findings for repository
MATCH (a:SecurityAssessment {repo_name: "my-repo"})-[:CONTAINS]->(f:SecurityFinding)
RETURN f.title, f.severity, f.owasp_category
ORDER BY f.severity DESC

-- Find critical findings affecting specific function
MATCH (f:SecurityFinding {severity: 'CRITICAL'})-[:AFFECTS]->(fn:Function {name: "authenticate"})
RETURN f.title, f.description, f.attack_scenario

-- Calculate vulnerability density by OWASP category
MATCH (f:SecurityFinding)-[:MAPS_TO]->(o:OwaspCategory)
WITH o.category_id AS category, COUNT(f) AS count
RETURN category, count
ORDER BY count DESC

-- Find functions with multiple security findings
MATCH (fn:Function)<-[:AFFECTS]-(f:SecurityFinding)
WITH fn, COUNT(f) AS finding_count
WHERE finding_count > 1
RETURN fn.name, fn.filePath, finding_count
ORDER BY finding_count DESC

-- Get ASVS compliance gaps
MATCH (f:SecurityFinding)-[:VIOLATES]->(r:AsvsRequirement)
WITH r.chapter AS chapter, COUNT(DISTINCT r) AS failed_requirements
RETURN chapter, failed_requirements
ORDER BY chapter
```

## Example Output

### Console Output

```
🛡️ **SECURITY ASSESSMENT STARTED**

Stack Detection:
✅ Backend: Kotlin/Spring Boot 2.7.18
✅ Frontend: Angular 20.3.16
✅ ORM: JPA/Hibernate + MyBatis
✅ Auth: Spring Security 5.8.16 + JWT

Running 24 Security Checks:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100%

OWASP Top 10 Analysis:
✅ A01 Broken Access Control: 5 findings
✅ A02 Cryptographic Failures: 3 findings
✅ A03 Injection: 8 findings
✅ A04 Insecure Design: 2 findings
✅ A05 Security Misconfiguration: 3 findings
✅ A06 Vulnerable Components: 1 finding
✅ A07 Authentication Failures: 1 finding
✅ A08 Software/Data Integrity: 0 findings
✅ A09 Logging/Monitoring: 0 findings
✅ A10 SSRF: 0 findings

ASVS Level 1 Compliance: 84.7% (127/150 passed)

Token Usage: 160,000 tokens ($8.20)
Duration: 18 minutes

📊 **RESULTS SUMMARY**:
- Total Findings: 23
- 🔴 Critical: 2
- 🟠 High: 7
- 🟡 Medium: 10
- 🟢 Low: 4

🎯 **TOP 5 RISKS**:
1. Missing Authentication on Admin Endpoint (CRITICAL)
2. SQL Injection via String Concatenation (CRITICAL)
3. XSS via Sanitizer Bypass (HIGH)
4. JWT Expired Token Accepted (HIGH)
5. Weak Cryptography: MD5 Hashing (HIGH)

📝 **GENERATED ARTIFACTS**:
- Security test suite: 23 tests across 5 files
- Detailed report: SECURITY_ASSESSMENT_REPORT.md
- ASVS compliance matrix
- Remediation roadmap

Next steps:
1. Review critical findings
2. Run generated test suite
3. Implement high-priority remediations
4. Re-run assessment to verify fixes
```
