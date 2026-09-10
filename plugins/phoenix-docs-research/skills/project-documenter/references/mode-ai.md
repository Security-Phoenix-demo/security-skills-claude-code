# Mode 2 — AI / LLM Documentation

Generate the full AI-native documentation layer.
Every file generated in this mode uses the cross-linking header/footer defined in SKILL.md Step 4.
The prompt is the real program. This mode documents it properly.

---

## PROMPTS.md → `/docs/ai/PROMPTS.md`

```markdown
<!-- Parent: /CLAUDE.md -->
<!-- Related: /docs/ai/LLM_ARCHITECTURE.md, /docs/ai/PROMPT_TESTS.md, /docs/architecture/DATA_CONTRACTS.md -->
<!-- Read when: working on any AI feature, changing prompt templates, reviewing output contracts -->

Document **every prompt** in the system. For each:

```markdown
## Prompt: [prompt_name]

**Purpose:** What this prompt is designed to produce
**Location:** /path/to/prompt/file_or_function
**Model:** Claude / GPT-4 / Gemini / local

### Inputs

| Variable | Type | Source | Required |
|----------|------|--------|----------|
| {{cve}} | string | vulnerability record | yes |
| {{environment}} | string | deployment context | yes |

### Output Contract

\`\`\`json
{
  "field_name": "type — description",
  "required_field": "string — always present",
  "optional_field": "string | null"
}
\`\`\`

### Prompt Template

\`\`\`
[Full prompt template with {{placeholders}} shown]
\`\`\`

### Example Input

\`\`\`json
{
  "cve": "CVE-2024-1234",
  "package": "openssl",
  "environment": "internet-facing container"
}
\`\`\`

### Example Output

\`\`\`json
{
  "mitre_techniques": ["T1190"],
  "attack_vector": "network",
  "exploitability_score": "high",
  "recommended_remediation": "Upgrade to openssl >= 3.0.8"
}
\`\`\`

### Downstream Dependencies

What code consumes this output? What breaks if the JSON shape changes?

### Versioning

Current version: v[N]
Change history: [if tracked]
Test coverage: [yes/no — reference PROMPT_TESTS.md]
```

---

## LLM_ARCHITECTURE.md

```markdown
# LLM Architecture

## Model Providers

| Provider | Model | Version | Purpose |
|----------|-------|---------|---------|
| Anthropic | Claude Sonnet | claude-sonnet-X | [detected use] |
| OpenAI | GPT-4o | ... | [detected use] |

## Request Pipeline

\`\`\`mermaid
graph TD
  InputData --> ContextBuilder
  ContextBuilder --> PromptBuilder
  PromptBuilder --> LLM_API
  LLM_API --> Parser
  Parser --> Validator
  Validator --> Storage
  Validator -->|fail| RetryHandler
  RetryHandler -->|max retries| FallbackModel
\`\`\`

## Context Construction

How each prompt receives its context:
- Sources injected (DB records, config, scan results, user input)
- Token budget: estimated context + prompt + response per call
- Truncation strategy if context exceeds limit

## Response Parsing

Where and how LLM output is parsed.
Schema enforcement mechanism.
Handling of partial or malformed JSON.

## Retry and Fallback

| Failure Mode | Retry Policy | Fallback |
|-------------|-------------|---------|
| Timeout | 3x exponential backoff | deterministic result |
| Malformed JSON | 2x retry with clarification prompt | null result + alert |
| Rate limit | Backoff + queue | delayed execution |
| Model unavailable | Immediate fallback | alternate model |

## Streaming vs Batch

[Detected interaction mode — streaming / batch / single-shot]
```

---

## AGENT_WORKFLOWS.md

For each detected agent or orchestration pipeline:

```markdown
## Agent: [AgentName]

**Purpose:** What this agent is responsible for
**Trigger:** What starts this agent (event / API call / schedule)
**Autonomy Level:** Recommendation-only / Approval-gated / Autonomous
**Human Review Required:** Yes / No — when and why

### Workflow

\`\`\`mermaid
graph TD
  Trigger --> LoadContext
  LoadContext --> BuildPrompt
  BuildPrompt --> InvokeLLM
  InvokeLLM --> ValidateOutput
  ValidateOutput -->|valid| PersistResult
  ValidateOutput -->|invalid| RetryOrFallback
  PersistResult --> NotifyUser
\`\`\`

### Steps

1. [Step description — what data is loaded]
2. [Step description — how context is constructed]
3. [Step description — LLM invocation details]
4. [Step description — output validation]
5. [Step description — downstream action]

### Outputs

| Output | Type | Consumer |
|--------|------|---------|

### Safety Constraints

What prevents this agent from taking harmful or incorrect actions.
```

---

## MODEL_GUARDRAILS.md

```markdown
# Model Guardrails

## Prompt Injection Defense

- How user-supplied or external data is isolated from prompt instructions
- Input sanitization rules (strip special chars, length limits, encoding checks)
- System prompt structure — what is fixed vs. dynamic

## Output Validation

For each prompt type, document the validation layer:

| Prompt | Validation Method | Failure Action |
|--------|------------------|----------------|
| [name] | JSON schema + regex | retry / null result |

## Hallucination Mitigation

- Grounding strategy: what factual data is injected to constrain outputs
- Constrained output formats (JSON-only, structured schema)
- Fields that are verified against deterministic sources post-generation
- Confidence score requirements (if used)

## Data Privacy

What data is sent to external LLM APIs:
- Customer identifiers: [yes/no — how handled]
- Vulnerability details: [yes/no — sanitized?]
- Code snippets: [yes/no — anonymized?]
- PII: [explicit statement — should be MUST NOT]

Anonymization strategy if applicable.

## Sensitive Data Handling (RFC 2119)

- MUST NOT send raw PII to external model providers
- MUST redact secrets/tokens before prompt injection
- SHOULD anonymize customer-specific identifiers
- MUST log prompt inputs with appropriate retention policy
```

---

## AI_RUNBOOK.md

```markdown
# AI Operations Runbook

## Monitoring

Key signals to track:

| Signal | Source | Alert Threshold |
|--------|--------|----------------|
| LLM latency p99 | API response time | > 5s |
| Prompt validation failure rate | validator logs | > 5% |
| Token usage | provider dashboard | > budget/day |
| Fallback activation rate | retry logs | > 2% |

## Diagnosing AI Failures

Step-by-step:
1. Check validator logs — did the output parse?
2. Check raw LLM response — was the format correct?
3. Check prompt builder output — was context injected correctly?
4. Check context builder — was upstream data complete?
5. Check model provider status page

## Prompt Update Process

MUST follow this sequence:
1. Create new prompt version (do not overwrite in-place)
2. Run prompt contract tests (ref: PROMPT_TESTS.md)
3. Deploy to staging, run against representative sample
4. Compare outputs to baseline
5. Gradual rollout (10% → 50% → 100%)
6. Monitor validation failure rate during rollout

## Model Failure Response

If primary model is unavailable:
1. Confirm provider outage on status page
2. Activate fallback model (see LLM_ARCHITECTURE.md)
3. Alert on-call — AI-generated outputs are degraded
4. Disable autonomous agent actions — recommendation-only mode
5. Resume normal operation after primary model recovery + validation pass

## Incident Response — Bad AI Output in Production

1. Identify affected prompt (check logs for request IDs)
2. Quarantine affected output records — flag as `ai_output_suspect`
3. Re-run affected records with fixed prompt or fallback
4. Root cause: prompt logic / context quality / model change?
5. Update PROMPT_TESTS.md with regression test for this case
```

---

## PROMPT_TESTS.md

```markdown
# Prompt Tests

Prompt contracts must be regression-tested before any prompt change ships.

## Test Structure

For each prompt, define:
- Canonical input → expected output shape
- Edge cases (missing fields, empty values, adversarial input)
- Schema assertions (field presence, type, value constraints)

## Test Cases

### [prompt_name] — Baseline

**Input:**
\`\`\`json
{ [representative input] }
\`\`\`

**Assertions:**
- [ ] Response is valid JSON
- [ ] `mitre_techniques` is an array
- [ ] `exploitability_score` is one of: critical/high/medium/low/informational
- [ ] `recommended_remediation` is non-empty string
- [ ] No fields named `<script>` or containing injection patterns

### [prompt_name] — Missing Optional Field

**Input:** [same as baseline but with optional field removed]
**Expected:** graceful degradation — no crash, reduced confidence score acceptable

### [prompt_name] — Adversarial Input

**Input:** Inject prompt-like content into a data field
**Expected:** Output matches schema — instructions are NOT followed

## Running Tests

\`\`\`bash
[command to run prompt test suite]
\`\`\`

## Regression Policy

Any prompt change that alters output schema MUST:
1. Update test assertions
2. Update downstream consumers
3. Get sign-off from owner of consuming module
```

---

## LLM_COST_MODEL.md

```markdown
# LLM Cost Model

## Token Budget Per Operation

| Operation | Input Tokens (est.) | Output Tokens (est.) | Total |
|-----------|--------------------|--------------------|-------|
| [prompt_name] | 800 | 400 | 1,200 |

## Cost Per Operation (current pricing)

| Operation | Model | Cost/1K tokens | Cost/call | Cost/10K calls |
|-----------|-------|---------------|-----------|----------------|
| [prompt_name] | claude-sonnet | $0.003 | $0.0036 | $36 |

## Monthly Estimates

Based on detected usage patterns:
- Estimated daily calls: [N]
- Estimated monthly cost: $[N]

## Optimization Strategies

| Strategy | Current Status | Potential Saving |
|---------|---------------|-----------------|
| Response caching (24h TTL) | [implemented/not implemented] | ~40% on repeat CVEs |
| Batching (10 vulns/request) | [implemented/not implemented] | ~30% on throughput |
| Prompt compression | [implemented/not implemented] | ~15% on input tokens |
| Model tiering (Haiku for triage) | [implemented/not implemented] | ~70% on low-stakes ops |
```

---

## AGENT_SAFETY_MODEL.md

```markdown
# Agent Safety Model

## Risk Classification

| Agent | Type | Risk Level | Reason |
|-------|------|-----------|--------|
| [agent_name] | recommendation | Low | Output shown to human before action |
| [agent_name] | automated suggestion | Medium | Writes to DB, no code execution |
| [agent_name] | autonomous | High | Executes code or modifies prod |

## Safety Constraints (RFC 2119)

**Low-risk agents:**
- MUST display output to user before persistence
- SHOULD include confidence score

**Medium-risk agents:**
- MUST enforce confidence threshold before auto-write (e.g., > 0.85)
- MUST log all automated actions with input + output + timestamp
- MUST support manual override/rollback

**High-risk agents:**
- MUST require explicit human approval
- MUST enforce dry-run mode by default
- MUST NOT execute in production without sign-off
- MUST have rollback mechanism tested

## Incident Handling

If an agent produces incorrect or harmful output:
1. Disable agent — set `AGENT_[NAME]_ENABLED=false`
2. Quarantine affected records
3. Alert on-call with agent name, time window, affected record IDs
4. Root cause analysis within 24h
5. Regression test added before re-enabling
```
