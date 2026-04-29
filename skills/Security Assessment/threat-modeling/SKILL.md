# Threat Modeling Agent Skill

**Purpose:** Automated threat modeling from code analysis using STRIDE/DREAD methodologies

**When to use:** Security assessment, architecture review, compliance documentation, attack scenario planning

---

## Workflow

### 1. Scope Determination

**Determine analysis scope:**
- Full repository threat model
- Feature-specific threat model
- Component-level threat model
- Architecture diagram analysis

**Check prerequisites:**
- Repository is indexed in knowledge graph
- Business context available (optional)
- Architecture diagrams uploaded (optional)
- CVE intelligence data available (optional)

### 2. Architecture Extraction

**Extract system architecture from:**
- Knowledge graph clusters (components)
- Call chains (data flows)
- Entry points (public APIs)
- Trust boundaries (zone crossings)
- Technology stack
- External dependencies

**Enrich with:**
- Architecture diagram analysis (AI vision)
- Business context (industry, compliance)
- Deployment context (cloud infrastructure)

### 3. STRIDE Threat Analysis

**Generate threats for each category:**
- **Spoofing**: Identity and authentication threats
- **Tampering**: Data and code integrity threats
- **Repudiation**: Audit and accountability threats
- **Information Disclosure**: Data leakage threats
- **Denial of Service**: Availability threats
- **Elevation of Privilege**: Access control threats

**For each threat, identify:**
- Affected components
- Affected data flows
- Trust boundary crossings
- Attack vectors
- Prerequisites
- Detection methods

### 4. DREAD Risk Assessment

**Score each threat (1-10):**
- Damage Potential
- Reproducibility
- Exploitability
- Affected Users
- Discoverability

**Calculate:**
- Risk Score = Average of 5 dimensions
- Risk Level = Critical/High/Medium/Low

### 5. Phoenix Intelligence Enrichment

**Enrich with Phoenix data (IP-protected):**
- Related CVEs
- Phoenix proprietary scores (high-level only)
- Threat actor data
- MITRE ATT&CK techniques
- CAPEC attack patterns

**Validate IP protection:**
- Only expose `psHpScore`, `psHpTier`, `componentLevels`
- Never expose numeric component values
- Never expose formulas or weights

### 6. Attack Scenario Synthesis

**Combine threats with CVE attack vectors:**
- Map threats to relevant CVEs
- Build step-by-step attack chains
- Map to MITRE ATT&CK tactics
- Identify detection opportunities
- Suggest mitigations

### 7. Attack Tree Generation

**Build hierarchical attack structure:**
- Root: Compromise application
- Branches: Attack objectives
- Leaves: Specific attack techniques
- Include likelihood scores
- Generate Mermaid diagram

### 8. Knowledge Graph Linking

**Link threats to code:**
- Find affected symbols
- Calculate blast radius
- Identify entry point paths
- Map to execution flows

### 9. Mitigation Generation

**Generate security controls:**
- Preventive controls
- Detective controls
- Corrective controls
- Map to compliance frameworks
- Prioritize by risk score

### 10. Report Generation

**Generate comprehensive report:**
- Executive summary
- Architecture overview
- STRIDE threat model
- DREAD risk assessment
- Attack scenarios
- Attack tree diagram
- Mitigation roadmap
- Compliance mapping

---

## Checklist

- [ ] **Scope defined**: Full repo, feature, or component
- [ ] **Architecture extracted**: Components, data flows, trust boundaries
- [ ] **STRIDE analysis**: 20-30 threats identified across all categories
- [ ] **DREAD assessment**: Risk scores calculated for all threats
- [ ] **Phoenix enrichment**: CVE intelligence added (IP-protected)
- [ ] **Attack scenarios**: Realistic attack chains with CVE mappings
- [ ] **Attack tree**: Visual representation with likelihood scores
- [ ] **Graph linking**: Threats linked to code symbols
- [ ] **Mitigations**: Controls mapped to frameworks
- [ ] **Report generated**: Comprehensive documentation in multiple formats

---

## Key APIs

### REST Endpoints

```bash
# Generate threat model
POST /api/v1/threat-model/assessments
{
  "repo_name": "myapp",
  "assessment_type": "full_repo",
  "include_dread": true,
  "include_attack_tree": true,
  "provider": "openai",
  "model": "gpt-4o",
  "industry": "financial_services",
  "compliance_frameworks": ["pci_dss", "sox"]
}

# Get assessment status
GET /api/v1/threat-model/assessments/{assessment_id}/status

# Get threat model results
GET /api/v1/threat-model/assessments/{assessment_id}

# Upload architecture diagram
POST /api/v1/threat-model/architecture-diagrams
(multipart/form-data: file, name, description, provider, model)

# Generate feature threat model
POST /api/v1/threat-model/assessments/feature
{
  "repo_name": "myapp",
  "feature_name": "User Authentication",
  "entry_points": ["login", "register", "resetPassword"]
}
```

### MCP Tools

```typescript
// Generate threat model
await use_mcp_tool("gitnexus", "threat_model", {
  repo_name: "myapp",
  assessment_type: "full_repo",
  include_dread: true
})

// Get threats for component
await use_mcp_tool("gitnexus", "get_threats", {
  repo_name: "myapp",
  component_name: "Authentication Service"
})

// Get attack scenarios
await use_mcp_tool("gitnexus", "get_attack_scenarios", {
  assessment_id: "tm_abc123"
})
```

---

## Example Cypher Queries

### Get All Threats for Repository

```cypher
MATCH (threat:ThreatModel {repoName: 'myapp'})
RETURN threat.category, threat.title, threat.riskScore
ORDER BY threat.riskScore DESC
```

### Get Threats Affecting Specific Function

```cypher
MATCH (threat:ThreatModel)-[:THREATENS]->(func:Function {name: 'authenticate'})
RETURN threat.title, threat.scenario, threat.riskScore, threat.category
```

### Find Attack Paths from Entry Points to Threatened Functions

```cypher
MATCH path = (entry:Function {isEntryPoint: true})-[:CALLS*1..5]->(func:Function)
WHERE EXISTS((threat:ThreatModel)-[:THREATENS]->(func))
WITH path, func
MATCH (threat:ThreatModel)-[:THREATENS]->(func)
RETURN path, threat.title, threat.riskScore
ORDER BY threat.riskScore DESC
LIMIT 10
```

### Get Threats by STRIDE Category

```cypher
MATCH (threat:ThreatModel {repoName: 'myapp', category: 'SPOOFING'})
RETURN threat.title, threat.scenario, threat.riskScore
ORDER BY threat.riskScore DESC
```

### Get High-Risk Threats with CVE Mappings

```cypher
MATCH (threat:ThreatModel)-[:EXPLOITS_VIA_CVE]->(cve:CVE)
WHERE threat.repoName = 'myapp' AND threat.riskScore >= 7.0
RETURN threat.title, threat.riskScore, collect(cve.cveId) as relatedCVEs
ORDER BY threat.riskScore DESC
```

---

## Integration Points

### With SAST Agent

- SAST findings trigger targeted threat modeling
- Vulnerabilities mapped to threat scenarios
- Combined risk scoring (SAST + Threat Model)

### With 0-Day Scanner

- 0-day vulnerabilities included in threat model
- Attack scenarios incorporate 0-day exploits
- Combined threat intelligence

### With Phoenix Database

- CVE intelligence enrichment (IP-protected)
- Threat actor data
- MITRE ATT&CK mapping
- Combined risk scoring

### With Knowledge Graph

- Architecture extraction from code
- Threat linking to symbols
- Attack path analysis
- Blast radius calculation

---

## Configuration

### ThreatModelConfig

```kotlin
data class ThreatModelConfig(
    val userId: String,
    val repoName: String,
    
    // Architecture extraction
    val includeBusinessContext: Boolean = true,
    val architectureDiagramIds: List<String> = emptyList(),
    val extractFromCode: Boolean = true,
    
    // Analysis settings
    val strideCategories: List<STRIDECategory> = STRIDECategory.values().toList(),
    val includeDREAD: Boolean = true,
    val includeAttackTree: Boolean = true,
    val includeAttackScenarios: Boolean = true,
    val includeMitigations: Boolean = true,
    
    // LLM settings
    val provider: LLMProvider = LLMProvider.OPENAI,
    val model: String = "gpt-4o",
    val temperature: Double = 0.2,
    
    // Phoenix integration
    val usePhoenixIntelligence: Boolean = true,
    val includeThreatActors: Boolean = true,
    val includeMITREAttack: Boolean = true,
    
    // Industry/compliance
    val industry: Industry? = null,
    val complianceFrameworks: List<ComplianceFramework> = emptyList(),
    
    // Output settings
    val outputFormats: List<OutputFormat> = listOf(OutputFormat.JSON, OutputFormat.MARKDOWN)
)
```

---

## Best Practices

### Architecture Extraction

1. **Use knowledge graph clusters** for component identification
2. **Infer trust zones** from naming conventions and patterns
3. **Identify data flows** from call chains and imports
4. **Detect trust boundaries** from zone crossings
5. **Leverage entry points** for attack surface analysis

### STRIDE Analysis

1. **Be specific** - Tailor threats to actual architecture
2. **Include context** - Reference specific components and data flows
3. **Consider trust boundaries** - Focus on boundary crossings
4. **Think like an attacker** - Realistic attack vectors
5. **Include detection** - How threats could be detected

### Risk Assessment

1. **Use DREAD consistently** - Apply same criteria across threats
2. **Consider business impact** - Factor in industry and compliance
3. **Validate with Phoenix** - Enrich with real CVE data
4. **Prioritize objectively** - Use quantitative scoring
5. **Review regularly** - Re-assess as architecture evolves

### 📈 Risk Matrix Format

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

### Attack Scenarios

1. **Map to real CVEs** - Use actual vulnerability data
2. **Build complete chains** - Initial access to impact
3. **Include indicators** - Detection opportunities
4. **Map to MITRE ATT&CK** - Standard technique taxonomy
5. **Provide mitigations** - Actionable recommendations

### IP Protection

1. **Never expose formulas** - Protect proprietary algorithms
2. **Only high-level scores** - `psHpScore`, `psHpTier`, `componentLevels`
3. **Validate before exposure** - Use `PhoenixDataShieldingService`
4. **Audit access** - Log all Phoenix data access
5. **Encrypt at rest** - Protect stored Phoenix data

---

## Example Usage

### Full Repository Threat Model

```bash
# Generate comprehensive threat model
# Note: Use port 8090 for Docker deployments, 8080 for direct Gradle runs
curl -X POST http://localhost:8090/api/v1/threat-model/assessments \
  -H "Content-Type: application/json" \
  -d '{
    "repo_name": "financial-platform",
    "assessment_type": "full_repo",
    "include_dread": true,
    "include_attack_tree": true,
    "include_attack_scenarios": true,
    "provider": "openai",
    "model": "gpt-4o",
    "industry": "financial_services",
    "compliance_frameworks": ["pci_dss", "sox", "glba"]
  }'

# Response
{
  "assessment_id": "tm_abc123",
  "status": "processing",
  "progress_percentage": 10,
  "estimated_completion": "2026-02-27T10:15:00Z"
}

# Check status
curl http://localhost:8090/api/v1/threat-model/assessments/tm_abc123/status

# Get results
curl http://localhost:8090/api/v1/threat-model/assessments/tm_abc123
```

### Feature-Specific Threat Model

```bash
# Generate threat model for authentication feature
curl -X POST http://localhost:8090/api/v1/threat-model/assessments/feature \
  -H "Content-Type: application/json" \
  -d '{
    "repo_name": "financial-platform",
    "feature_name": "User Authentication",
    "entry_points": ["login", "register", "resetPassword", "validateToken"],
    "provider": "anthropic",
    "model": "claude-3-5-sonnet-20241022"
  }'
```

---

## Output Examples

### Executive Summary

```
## Executive Summary

### Overall Risk Posture: HIGH

Your application has **24 identified threats** with **3 critical** and **8 high-risk** threats requiring immediate attention.

### Top 5 Critical Threats

1. **SQL Injection in Authentication Endpoint** (8.5/10)
   - Allows unauthorized database access
   - PCI-DSS compliance violation
   - Related CVEs: CVE-2024-12345
   - Threat Actors: APT28, Lazarus

2. **OAuth Token Theft via MITM** (8.0/10)
   - Enables account takeover
   - Affects all users
   - No certificate pinning

3. **Privilege Escalation via API Misconfiguration** (7.8/10)
   - Allows admin access from user role
   - Missing authorization checks

### Key Recommendations

**Immediate (0-30 days):**
- Implement parameterized queries
- Add certificate pinning
- Fix authorization bypass

**Short-term (1-6 months):**
- Deploy WAF
- Implement database monitoring
- Add input validation framework

### Business Impact

**Financial Risk:** $2M+ in potential fines and remediation costs  
**Compliance Status:** ❌ FAILING PCI-DSS requirements 6.5.1, 6.5.8  
**Reputation Risk:** HIGH - data breach could affect 100,000+ customers
```

### STRIDE Threat Table

| Category | Threat | Risk Score | Affected Components |
|----------|--------|------------|-------------------|
| Spoofing | OAuth Token Theft via MITM | 8.0/10 | API Gateway, Auth Service |
| Tampering | SQL Injection in Login | 8.5/10 | Auth Service, Database |
| Information Disclosure | Database Exposure via API | 7.5/10 | API Gateway, Database |
| Elevation of Privilege | Authorization Bypass | 7.8/10 | API Gateway |

### Attack Scenario Example

```
## SCENARIO_001: SQL Injection to Database Exfiltration

**Threat:** SQL Injection in Authentication Endpoint  
**Risk Score:** 8.5/10  
**Related CVEs:** CVE-2024-12345

### Attack Chain

1. **Initial Access** - SQL Injection
   - Attacker identifies injection point in login endpoint
   - MITRE ATT&CK: T1190
   - Tools: sqlmap, Burp Suite
   - Indicators: SQL error messages, failed login attempts

2. **Execution** - Database Enumeration
   - Attacker enumerates database structure
   - MITRE ATT&CK: T1213
   - Indicators: Excessive queries, schema access

3. **Exfiltration** - Data Extraction
   - Attacker extracts customer data via DNS tunneling
   - MITRE ATT&CK: T1041
   - Indicators: Unusual DNS queries

### Detection Opportunities
- WAF SQL injection detection
- Database query anomaly detection
- DNS tunneling detection

### Mitigations
- Implement parameterized queries
- Deploy WAF
- Add database monitoring
```

---

## Related Documents

- **[THREAT_MODELING_AGENT_SPEC.md](../../docs/THREAT_MODELING_AGENT_SPEC.md)** - Complete technical specification
- **[ROADMAP.md](../../docs/ROADMAP.md)** - Phase 6 implementation plan
- **[STATIC_CODE_ANALYSIS_AGENT_SPEC.md](../../docs/STATIC_CODE_ANALYSIS_AGENT_SPEC.md)** - SAST integration
- **[PHOENIX_DATABASE_INTEGRATION_PLAN.md](../../docs/PHOENIX_DATABASE_INTEGRATION_PLAN.md)** - Phoenix DB integration

---

**Version:** 1.0  
**Last Updated:** 2026-02-27  
**Status:** Planned
