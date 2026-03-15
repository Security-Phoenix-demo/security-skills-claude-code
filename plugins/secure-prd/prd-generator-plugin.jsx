import { useState, useCallback } from "react";

// ─── System prompt embedded from SKILL.md ────────────────────────────────────
const SYSTEM_PROMPT = `You are the Phoenix Security PRD Generator. You run a 10-role spec pipeline (Context Curator → Scope Cutter → Constraint Distiller → Requirements Engineer → Ambiguity Hunter → Security Engineer → Contract Architect → Verification Matrix → Batch Planner → Final Gate) on a feature description and produce a complete Product Requirements Document.

You MUST respond with valid JSON only — no markdown fences, no preamble, no text outside the JSON object.

Output this exact schema:
{
  "feature_name": "string",
  "feature_slug": "string (kebab-case, max 40 chars)",
  "date": "YYYY-MM-DD",
  "problem_statement": "string (2-4 sentences)",
  "context": "string (pipeline Role 01 summary — FACTS + DECISIONS)",
  "interested_parties": ["@Alfonso Eusebio"],
  "goals": ["string (max 6)"],
  "non_goals": ["string (max 6)"],
  "active_constraints": [
    { "id": "AC1", "text": "string", "type": "functional|security|reliability|ux|compliance|operational", "proof_hint": "test|contract|static|manual" }
  ],
  "features": [
    {
      "id": "FEATURE 1",
      "name": "string",
      "objective": "string (one line)",
      "functional_requirements": ["R-FUNC-001 [P0] MUST ... (maps_to: AC1)"],
      "ui_changes": "string or null",
      "data_model": "string or null",
      "export_requirements": "string or null",
      "open_questions": ["string"]
    }
  ],
  "security": {
    "threat_model": {
      "assets": ["string"],
      "actors": ["string"],
      "entry_points": ["string"],
      "trust_boundaries": ["string"],
      "high_risk_flows": ["string"]
    },
    "requirements": ["R-SEC-001 [P0] MUST ... (proof_hint: test)"],
    "abuse_cases": ["string"]
  },
  "api_contracts": [
    { "id": "API-001", "method": "GET|POST|PUT|DELETE|EVENT", "path": "string", "auth": "string", "request_schema": "string", "response_schema": "string", "errors": ["E-001: code → meaning → client_action"], "invariants": ["string"] }
  ],
  "verification_matrix": [
    { "req_id": "R-FUNC-001", "level": "MUST", "proof_type": "test|static|contract|manual", "artifact": "string", "notes": "string" }
  ],
  "batches": [
    { "id": "BATCH 1", "name": "string", "goal": "string", "covers": ["R-FUNC-001"], "steps": ["string"], "validation": "string", "risks": "string" }
  ],
  "performance_notes": "string",
  "risks": [{ "risk": "string", "mitigation": "string" }],
  "open_questions": ["string"],
  "final_gate": "SHIP|NO_SHIP",
  "blockers": []
}

Pipeline rules:
- RFC 2119 throughout (MUST/MUST NOT/SHOULD/MAY)
- Requirement IDs: R-FUNC-001, R-SEC-001, R-REL-001, R-UX-001 with [P0/P1/P2] tags
- Every MUST maps to an AC# constraint
- Every MUST has a verification matrix entry
- No invented facts — unknowns go in open_questions
- Max 40 total requirements across all features
- Prefer preventative security controls over detective
- If Final Gate = NO_SHIP, populate blockers array`;

// ─── Renderers ────────────────────────────────────────────────────────────────
function buildPRDMarkdown(d) {
  const sep = "\n---\n";
  const lines = [
    `# ${d.feature_name}`,
    ``,
    `**Owner:** @Francesco Cipollone / @Alfonso Eusebio`,
    `**Status:** DRAFT`,
    `**Information Classification:** INTERNAL *NDA SHARE*`,
    `**Date:** ${d.date}`,
    `**Version:** 1.0`,
    sep,
    `## Interested Parties`,
    ...(d.interested_parties || ["@Alfonso Eusebio"]).map(p => `- ${p}`),
    sep,
    `## Classification Reference`,
    ``,
    `| TAG | Action | Sharing |`,
    `|-----|--------|---------|`,
    `| N/A | To be classified | No — only who has access |`,
    `| PUBLIC | Public information | Can be shared externally |`,
    `| INTERNAL | Internal knowledge | Internal + external under NDA with password |`,
    `| CONFIDENTIAL | Confidential | No sharing |`,
    ``,
    `| Status | When | Action |`,
    `|--------|------|--------|`,
    `| N/A | Default | No particular state |`,
    `| APPROVED Vx | Reviewed by senior SP/SPD team | Approved version |`,
    `| DRAFT | Work in progress | Draft document |`,
    `| BRAINSTORM | Info not reliable | In progress |`,
    `| DISREGARD | Obsolete | Archived |`,
    sep,
    `## 0) Overview`,
    ``,
    d.problem_statement,
    ``,
    `### Context`,
    d.context,
    ``,
    `### Goals`,
    ...(d.goals || []).map(g => `- ${g}`),
    ``,
    `### Non-Goals`,
    ...(d.non_goals || []).map(g => `- ${g}`),
    sep,
    `## Active Constraints`,
    ``,
    `| ID | Constraint | Type | Proof Hint |`,
    `|----|-----------|------|-----------|`,
    ...(d.active_constraints || []).map(c => `| ${c.id} | ${c.text} | ${c.type} | ${c.proof_hint} |`),
    sep,
    `## Features`,
  ];

  (d.features || []).forEach(f => {
    lines.push(``, `### ${f.id} — ${f.name}`, ``, `**Objective:** ${f.objective}`, ``);
    lines.push(`#### Functional Requirements`);
    (f.functional_requirements || []).forEach(r => lines.push(`- ${r}`));
    if (f.ui_changes) { lines.push(``, `#### UI / UX Changes`, ``, f.ui_changes); }
    if (f.data_model) { lines.push(``, `#### Data Model`, ``, f.data_model); }
    if (f.export_requirements) { lines.push(``, `#### Export Requirements`, ``, f.export_requirements); }
    if (f.open_questions?.length) {
      lines.push(``, `#### Open Questions`);
      f.open_questions.forEach((q, i) => lines.push(`${i + 1}. ${q}`));
    }
    lines.push(sep);
  });

  const tm = d.security?.threat_model || {};
  lines.push(
    `## Security Requirements`, ``,
    `### Threat Model`,
    `- **Assets:** ${(tm.assets || []).join(", ")}`,
    `- **Actors:** ${(tm.actors || []).join(", ")}`,
    `- **Entry Points:** ${(tm.entry_points || []).join(", ")}`,
    `- **Trust Boundaries:** ${(tm.trust_boundaries || []).join(", ")}`,
    `- **High-Risk Flows:** ${(tm.high_risk_flows || []).join(", ")}`,
    ``, `### Security Requirements`,
    ...(d.security?.requirements || []).map(r => `- ${r}`),
  );
  if (d.security?.abuse_cases?.length) {
    lines.push(``, `### Abuse Cases`);
    d.security.abuse_cases.forEach((a, i) => lines.push(`- AC-SEC-0${i + 1}: ${a}`));
  }

  if (d.api_contracts?.length) {
    lines.push(sep, `## API Contracts`);
    d.api_contracts.forEach(c => {
      lines.push(``, `### ${c.id}: \`${c.method} ${c.path}\``,
        `- **Auth:** ${c.auth}`,
        `- **Request:** ${c.request_schema}`,
        `- **Response:** ${c.response_schema}`);
      if (c.errors?.length) { lines.push(`- **Errors:**`); c.errors.forEach(e => lines.push(`  - ${e}`)); }
      if (c.invariants?.length) { lines.push(`- **Invariants:**`); c.invariants.forEach(i => lines.push(`  - ${i}`)); }
    });
  }

  lines.push(sep, `## Verification Matrix`, ``,
    `| Requirement ID | Level | Proof Type | Proof Artifact | Notes |`,
    `|---|---|---|---|---|`,
    ...(d.verification_matrix || []).map(r => `| ${r.req_id} | ${r.level} | ${r.proof_type} | ${r.artifact} | ${r.notes} |`),
    sep, `## Delivery Plan`,
  );
  (d.batches || []).forEach(b => {
    lines.push(``, `### ${b.id} — ${b.name}`, ``,
      `**Goal:** ${b.goal}`,
      `**Covers:** ${(b.covers || []).join(", ")}`,
      `**Steps:**`,
      ...(b.steps || []).map((s, i) => `${i + 1}. ${s}`),
      `**Validation:** ${b.validation}`,
      `**Risks/Rollback:** ${b.risks}`);
  });

  if (d.performance_notes) lines.push(sep, `## Data & Performance`, ``, d.performance_notes);

  if (d.risks?.length) {
    lines.push(sep, `## Risk & Mitigation`, ``, `| Risk | Mitigation |`, `|------|-----------|`,
      ...d.risks.map(r => `| ${r.risk} | ${r.mitigation} |`));
  }
  if (d.open_questions?.length) {
    lines.push(sep, `## Open Clarification Summary`, ``,
      ...d.open_questions.map((q, i) => `${i + 1}. ${q}`));
  }
  lines.push(sep, `## Final Gate`, ``, `**Decision:** ${d.final_gate}${d.blockers?.length ? `\n\n**Blockers:**\n${d.blockers.map((b, i) => `${i + 1}. ${b}`).join("\n")}` : ""}`);
  return lines.join("\n");
}

function buildCursorPlan(d) {
  const p0reqs = [
    ...(d.features || []).flatMap(f => (f.functional_requirements || []).filter(r => r.includes("[P0]"))),
    ...(d.security?.requirements || []).filter(r => r.includes("[P0]")),
  ];
  return [
    `# Plan: ${d.feature_name}`,
    `Date: ${d.date}`,
    `Status: DRAFT`,
    ``,
    `## Objective`,
    ``,
    d.problem_statement,
    ``,
    `## Implementation Batches`,
    ``,
    ...(d.batches || []).flatMap(b => [
      `### ${b.id} — ${b.name}`,
      `**Requirements:** ${(b.covers || []).join(", ")}`,
      `**Files to touch:** TBD`,
      `**Steps:**`,
      ...(b.steps || []).map((s, i) => `${i + 1}. ${s}`),
      `**Done when:** ${b.validation}`,
      ``,
    ]),
    `## P0 Requirements`,
    ``,
    ...p0reqs.map(r => `- ${r}`),
    ``,
    ...(d.open_questions?.length ? [`## Open Questions (resolve before implementation)`, ``, ...d.open_questions.map((q, i) => `- Q${i + 1}: ${q}`)] : []),
  ].join("\n");
}

// ─── UI helpers ───────────────────────────────────────────────────────────────
const C = {
  bg: "#0f1623",
  surface: "#161e2e",
  surfaceAlt: "#1c2740",
  border: "#2a3a5c",
  borderHover: "#3d5080",
  purple: "#7c3aed",
  purpleLight: "#a78bfa",
  blue: "#3b82f6",
  blueLight: "#93c5fd",
  green: "#10b981",
  orange: "#f59e0b",
  red: "#ef4444",
  textPrimary: "#f0f4ff",
  textSecondary: "#8b9fc4",
  textMuted: "#4a5c80",
};

const pill = (color, bg, text) => ({
  display: "inline-block",
  background: bg,
  color: color,
  padding: "2px 10px",
  borderRadius: 20,
  fontSize: 11,
  fontWeight: 700,
  letterSpacing: "0.04em",
});

function Tag({ label, color = C.blueLight, bg = "#1e3a5f" }) {
  return <span style={pill(color, bg, label)}>{label}</span>;
}

function Stat({ label, value, color = C.purpleLight }) {
  return (
    <div style={{ background: C.surfaceAlt, borderRadius: 10, padding: "14px 18px", border: `1px solid ${C.border}`, flex: 1, minWidth: 100 }}>
      <div style={{ fontSize: 22, fontWeight: 800, color, fontVariantNumeric: "tabular-nums" }}>{value}</div>
      <div style={{ fontSize: 11, color: C.textMuted, marginTop: 2, textTransform: "uppercase", letterSpacing: "0.06em" }}>{label}</div>
    </div>
  );
}

function Section({ title, accent = C.purple, children }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12 }}>
        <div style={{ width: 3, height: 16, background: accent, borderRadius: 2 }} />
        <div style={{ fontSize: 12, fontWeight: 700, color: C.textSecondary, textTransform: "uppercase", letterSpacing: "0.08em" }}>{title}</div>
      </div>
      {children}
    </div>
  );
}

function ReqChip({ req }) {
  const p0 = req.includes("[P0]");
  const p1 = req.includes("[P1]");
  return (
    <div style={{ fontSize: 12, color: C.textPrimary, padding: "7px 12px", background: C.surfaceAlt, borderRadius: 6, marginBottom: 5, borderLeft: `3px solid ${p0 ? C.red : p1 ? C.orange : C.border}`, lineHeight: 1.5 }}>
      {req}
    </div>
  );
}

// ─── Main component ───────────────────────────────────────────────────────────
export default function PRDPlugin() {
  const [projectName, setProjectName] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [stage, setStage] = useState("");
  const [prd, setPrd] = useState(null);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState("overview");
  const [confluenceLog, setConfluenceLog] = useState([]);
  const [confPushing, setConfPushing] = useState(false);

  const logConf = (msg, type = "info") => setConfluenceLog(prev => [...prev, { msg, type, t: Date.now() }]);

  const generate = async () => {
    if (!description.trim()) return;
    setLoading(true);
    setError(null);
    setPrd(null);
    setConfluenceLog([]);
    setActiveTab("overview");
    try {
      setStage("Running spec pipeline (Roles 01–10)…");
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          system: SYSTEM_PROMPT,
          messages: [{
            role: "user",
            content: `Project name: ${projectName || "Phoenix Security Feature"}\nDate: ${new Date().toISOString().split("T")[0]}\n\nFeature description:\n${description}\n\nRun the full pipeline and return the PRD JSON.`
          }]
        })
      });
      setStage("Parsing output…");
      const data = await res.json();
      const raw = (data.content || []).filter(b => b.type === "text").map(b => b.text).join("");
      const parsed = JSON.parse(raw.replace(/```json|```/g, "").trim());
      setPrd(parsed);
      setStage("");
    } catch (e) {
      setError(e.message);
      setStage("");
    } finally {
      setLoading(false);
    }
  };

  const pushConfluence = async () => {
    if (!prd) return;
    setConfPushing(true);
    setConfluenceLog([]);
    const title = `${projectName ? projectName + " — " : ""}${prd.feature_name}`;
    try {
      logConf("Connecting to Atlassian…");
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          system: `You are a Confluence page publisher. Use the available Atlassian MCP tools to:
1. Call getAccessibleAtlassianResources to get the cloudId
2. Call searchConfluenceUsingCql with: title = "TEMPLATE PRD" AND space = "SPM" to find the parent page. Fallback parent ID: 1273987073
3. Call createConfluencePage with the provided content
Return JSON only: {"success": true/false, "url": "string or null", "page_id": "string or null", "error": "string or null"}`,
          messages: [{
            role: "user",
            content: `Create a Confluence page:
Title: "${title}"
Space: SPM
Parent page: search for "TEMPLATE PRD" in SPM space (fallback ID 1273987073)
Owner: Francesco Cipollone
Status: DRAFT

Content (Markdown):
${buildPRDMarkdown(prd).substring(0, 8000)}`
          }],
          mcp_servers: [{ type: "url", url: "https://mcp.atlassian.com/v1/mcp", name: "atlassian" }]
        })
      });
      const data = await res.json();
      const text = (data.content || []).filter(b => b.type === "text").map(b => b.text).join("");
      try {
        const result = JSON.parse(text.replace(/```json|```/g, "").trim());
        if (result.success) {
          logConf(`✓ Published: "${title}"`, "success");
          if (result.url) logConf(`→ ${result.url}`, "url");
        } else {
          logConf(`✗ ${result.error || "Unknown error"}`, "error");
        }
      } catch {
        logConf("✓ Confluence request completed", "success");
      }
    } catch (e) {
      logConf(`✗ ${e.message}`, "error");
    } finally {
      setConfPushing(false);
    }
  };

  const download = (content, name) => {
    const url = URL.createObjectURL(new Blob([content], { type: "text/markdown" }));
    Object.assign(document.createElement("a"), { href: url, download: name }).click();
    URL.revokeObjectURL(url);
  };

  const tabs = [
    { id: "overview", label: "Overview" },
    { id: "features", label: `Features${prd ? ` (${prd.features?.length || 0})` : ""}` },
    { id: "security", label: "Security" },
    { id: "contracts", label: "Contracts" },
    { id: "matrix", label: "Verification" },
    { id: "batches", label: "Delivery" },
  ];

  const totalReqs = prd ? (prd.features || []).reduce((s, f) => s + (f.functional_requirements?.length || 0), 0) + (prd.security?.requirements?.length || 0) : 0;
  const p0count = prd ? (prd.features || []).flatMap(f => f.functional_requirements || []).filter(r => r.includes("[P0]")).length + (prd.security?.requirements || []).filter(r => r.includes("[P0]")).length : 0;

  return (
    <div style={{ fontFamily: "'JetBrains Mono', 'Fira Code', 'Courier New', monospace", background: C.bg, minHeight: "100vh", color: C.textPrimary }}>

      {/* Header */}
      <div style={{ borderBottom: `1px solid ${C.border}`, padding: "16px 24px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 32, height: 32, background: `linear-gradient(135deg, ${C.purple}, ${C.blue})`, borderRadius: 8, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>🔥</div>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14, color: C.textPrimary, letterSpacing: "-0.01em" }}>PRD Generator</div>
            <div style={{ fontSize: 10, color: C.textMuted, letterSpacing: "0.08em" }}>PHOENIX SECURITY · ASPM</div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          <Tag label="INTERNAL" color="#fbbf24" bg="#292006" />
          <Tag label="NDA SHARE" color={C.textMuted} bg={C.surfaceAlt} />
        </div>
      </div>

      <div style={{ maxWidth: 900, margin: "0 auto", padding: "24px 20px" }}>

        {/* Input card */}
        <div style={{ background: C.surface, borderRadius: 12, padding: 22, border: `1px solid ${C.border}`, marginBottom: 20 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 2fr", gap: 14, marginBottom: 14 }}>
            <div>
              <label style={{ display: "block", fontSize: 10, fontWeight: 700, color: C.textMuted, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 6 }}>Project Name</label>
              <input value={projectName} onChange={e => setProjectName(e.target.value)}
                placeholder="SPM-VULN-AGE"
                style={{ width: "100%", background: C.bg, border: `1px solid ${C.border}`, borderRadius: 7, padding: "9px 12px", color: C.textPrimary, fontSize: 13, boxSizing: "border-box", outline: "none", fontFamily: "inherit" }} />
            </div>
            <div>
              <label style={{ display: "block", fontSize: 10, fontWeight: 700, color: C.textMuted, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 6 }}>Feature Description</label>
              <textarea value={description} onChange={e => setDescription(e.target.value)}
                placeholder="Describe the feature. E.g: Add SLA breach depth bands to the vulnerability screen — 'Just Outside', 'Outside 1-10d', 'A Lot Outside 10-30d', '>30d'. Teams need a ranking table ordered by outside_count to drive remediation accountability..."
                rows={4}
                style={{ width: "100%", background: C.bg, border: `1px solid ${C.border}`, borderRadius: 7, padding: "9px 12px", color: C.textPrimary, fontSize: 12, boxSizing: "border-box", resize: "vertical", outline: "none", fontFamily: "inherit", lineHeight: 1.7 }} />
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <button onClick={generate} disabled={loading || !description.trim()}
              style={{ background: loading || !description.trim() ? C.surfaceAlt : `linear-gradient(135deg, ${C.purple}, ${C.blue})`, color: loading || !description.trim() ? C.textMuted : "#fff", border: "none", borderRadius: 7, padding: "10px 22px", fontSize: 12, fontWeight: 700, cursor: loading || !description.trim() ? "not-allowed" : "pointer", letterSpacing: "0.03em", transition: "opacity 0.15s" }}>
              {loading ? "⚙ Running pipeline…" : "→ Generate PRD"}
            </button>
            {stage && <span style={{ fontSize: 11, color: C.textMuted, fontStyle: "italic" }}>{stage}</span>}
            {error && <span style={{ fontSize: 11, color: C.red }}>✗ {error}</span>}
          </div>
        </div>

        {/* Output */}
        {prd && (
          <div style={{ background: C.surface, borderRadius: 12, border: `1px solid ${C.border}` }}>

            {/* Doc header */}
            <div style={{ padding: "18px 22px", borderBottom: `1px solid ${C.border}` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: 12 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 17, fontWeight: 800, color: C.textPrimary, letterSpacing: "-0.02em", marginBottom: 4 }}>{prd.feature_name}</div>
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap", alignItems: "center" }}>
                    <Tag label="DRAFT" color="#fbbf24" bg="#292006" />
                    <Tag label={prd.final_gate} color={prd.final_gate === "SHIP" ? "#6ee7b7" : "#fca5a5"} bg={prd.final_gate === "SHIP" ? "#052e1c" : "#2d0a0a"} />
                    <span style={{ fontSize: 11, color: C.textMuted }}>@Francesco Cipollone / @Alfonso Eusebio · {prd.date}</span>
                  </div>
                </div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  <button onClick={() => download(buildPRDMarkdown(prd), `${prd.feature_slug}-PRD.md`)}
                    style={{ background: C.surfaceAlt, color: C.blueLight, border: `1px solid ${C.border}`, borderRadius: 6, padding: "7px 13px", fontSize: 11, fontWeight: 700, cursor: "pointer", letterSpacing: "0.03em" }}>
                    ↓ PRD.md
                  </button>
                  <button onClick={() => download(buildCursorPlan(prd), `${prd.feature_slug}-cursor-plan.md`)}
                    style={{ background: C.surfaceAlt, color: C.blueLight, border: `1px solid ${C.border}`, borderRadius: 6, padding: "7px 13px", fontSize: 11, fontWeight: 700, cursor: "pointer", letterSpacing: "0.03em" }}>
                    ↓ .cursor/plan
                  </button>
                  <button onClick={pushConfluence} disabled={confPushing}
                    style={{ background: confPushing ? C.surfaceAlt : `linear-gradient(135deg, #5b21b6, #1d4ed8)`, color: confPushing ? C.textMuted : "#fff", border: "none", borderRadius: 6, padding: "7px 13px", fontSize: 11, fontWeight: 700, cursor: confPushing ? "not-allowed" : "pointer", letterSpacing: "0.03em" }}>
                    {confPushing ? "Publishing…" : "→ Confluence"}
                  </button>
                </div>
              </div>

              {/* Confluence log */}
              {confluenceLog.length > 0 && (
                <div style={{ marginTop: 10, background: C.bg, borderRadius: 7, padding: "10px 14px", fontSize: 11 }}>
                  {confluenceLog.map((l, i) => (
                    <div key={i} style={{ color: l.type === "success" ? C.green : l.type === "error" ? C.red : l.type === "url" ? C.blueLight : C.textMuted, marginBottom: 2 }}>{l.msg}</div>
                  ))}
                </div>
              )}

              {/* Stats row */}
              <div style={{ display: "flex", gap: 10, marginTop: 14, flexWrap: "wrap" }}>
                <Stat label="Features" value={prd.features?.length || 0} color={C.purpleLight} />
                <Stat label="Requirements" value={totalReqs} color={C.blueLight} />
                <Stat label="P0 Critical" value={p0count} color={C.red} />
                <Stat label="Batches" value={prd.batches?.length || 0} color={C.green} />
                <Stat label="Open Qs" value={prd.open_questions?.length || 0} color={C.orange} />
              </div>
            </div>

            {/* Tabs */}
            <div style={{ display: "flex", borderBottom: `1px solid ${C.border}`, padding: "0 22px", overflowX: "auto" }}>
              {tabs.map(t => (
                <button key={t.id} onClick={() => setActiveTab(t.id)}
                  style={{ background: "none", border: "none", color: activeTab === t.id ? C.purpleLight : C.textMuted, padding: "11px 14px", fontSize: 11, fontWeight: activeTab === t.id ? 700 : 400, cursor: "pointer", borderBottom: activeTab === t.id ? `2px solid ${C.purpleLight}` : "2px solid transparent", whiteSpace: "nowrap", fontFamily: "inherit", letterSpacing: "0.04em", textTransform: "uppercase", transition: "color 0.15s" }}>
                  {t.label}
                </button>
              ))}
            </div>

            <div style={{ padding: 22 }}>

              {/* ── Overview tab ── */}
              {activeTab === "overview" && (
                <div>
                  <Section title="Problem Statement">
                    <p style={{ fontSize: 13, color: C.textSecondary, lineHeight: 1.8, margin: 0, background: C.surfaceAlt, padding: "12px 16px", borderRadius: 8, borderLeft: `3px solid ${C.purple}` }}>{prd.problem_statement}</p>
                  </Section>
                  <Section title="Context">
                    <p style={{ fontSize: 12, color: C.textSecondary, lineHeight: 1.8, margin: 0 }}>{prd.context}</p>
                  </Section>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginBottom: 20 }}>
                    <Section title="Goals" accent={C.green}>
                      {(prd.goals || []).map((g, i) => <div key={i} style={{ fontSize: 12, color: C.textPrimary, marginBottom: 5, display: "flex", gap: 8 }}><span style={{ color: C.green }}>✓</span>{g}</div>)}
                    </Section>
                    <Section title="Non-Goals" accent={C.orange}>
                      {(prd.non_goals || []).map((g, i) => <div key={i} style={{ fontSize: 12, color: C.textPrimary, marginBottom: 5, display: "flex", gap: 8 }}><span style={{ color: C.orange }}>✗</span>{g}</div>)}
                    </Section>
                  </div>
                  <Section title="Active Constraints">
                    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))", gap: 8 }}>
                      {(prd.active_constraints || []).map((c, i) => (
                        <div key={i} style={{ background: C.surfaceAlt, borderRadius: 7, padding: "10px 12px", border: `1px solid ${C.border}` }}>
                          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 5 }}>
                            <span style={{ fontSize: 11, fontWeight: 700, color: C.purpleLight }}>{c.id}</span>
                            <span style={{ fontSize: 10, color: C.textMuted }}>{c.proof_hint}</span>
                          </div>
                          <div style={{ fontSize: 11, color: C.textSecondary, lineHeight: 1.6 }}>{c.text}</div>
                          <div style={{ marginTop: 5 }}><Tag label={c.type} color={C.textMuted} bg={C.bg} /></div>
                        </div>
                      ))}
                    </div>
                  </Section>
                  {prd.open_questions?.length > 0 && (
                    <Section title="Open Clarifications" accent={C.orange}>
                      <div style={{ background: "#1a1200", border: `1px solid #4a3500`, borderRadius: 8, padding: "12px 16px" }}>
                        {prd.open_questions.map((q, i) => <div key={i} style={{ fontSize: 12, color: "#fcd34d", marginBottom: 5 }}>Q{i + 1}: {q}</div>)}
                      </div>
                    </Section>
                  )}
                </div>
              )}

              {/* ── Features tab ── */}
              {activeTab === "features" && (
                <div>
                  {(prd.features || []).map((f, fi) => (
                    <div key={fi} style={{ background: C.surfaceAlt, borderRadius: 10, padding: 16, marginBottom: 14, border: `1px solid ${C.border}` }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 10 }}>
                        <div>
                          <div style={{ fontSize: 14, fontWeight: 800, color: C.textPrimary }}>{f.id} — {f.name}</div>
                          <div style={{ fontSize: 12, color: C.textMuted, marginTop: 3 }}>{f.objective}</div>
                        </div>
                        <Tag label={`${(f.functional_requirements || []).length} reqs`} color={C.blueLight} bg={C.bg} />
                      </div>
                      <Section title="Functional Requirements">
                        {(f.functional_requirements || []).map((r, ri) => <ReqChip key={ri} req={r} />)}
                      </Section>
                      {f.ui_changes && <Section title="UI Changes"><p style={{ fontSize: 12, color: C.textSecondary, margin: 0, lineHeight: 1.7 }}>{f.ui_changes}</p></Section>}
                      {f.data_model && <Section title="Data Model"><pre style={{ fontSize: 11, color: C.textSecondary, background: C.bg, padding: 12, borderRadius: 6, margin: 0, whiteSpace: "pre-wrap" }}>{f.data_model}</pre></Section>}
                      {f.export_requirements && <Section title="Export"><p style={{ fontSize: 12, color: C.textSecondary, margin: 0 }}>{f.export_requirements}</p></Section>}
                      {f.open_questions?.length > 0 && (
                        <Section title="Open Questions" accent={C.orange}>
                          {f.open_questions.map((q, qi) => <div key={qi} style={{ fontSize: 11, color: "#fbbf24", marginBottom: 3 }}>Q{qi + 1}: {q}</div>)}
                        </Section>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {/* ── Security tab ── */}
              {activeTab === "security" && (
                <div>
                  <Section title="Threat Model" accent={C.red}>
                    <div style={{ background: "#1a0a0a", border: `1px solid #4a1010`, borderRadius: 8, padding: "14px 16px" }}>
                      {Object.entries(prd.security?.threat_model || {}).map(([k, v]) => (
                        <div key={k} style={{ marginBottom: 8, display: "flex", gap: 10 }}>
                          <span style={{ fontSize: 11, fontWeight: 700, color: "#f87171", minWidth: 110, textTransform: "capitalize" }}>{k.replace(/_/g, " ")}</span>
                          <span style={{ fontSize: 12, color: C.textSecondary }}>{Array.isArray(v) ? v.join(" · ") : v}</span>
                        </div>
                      ))}
                    </div>
                  </Section>
                  <Section title="Security Requirements">
                    {(prd.security?.requirements || []).map((r, i) => <ReqChip key={i} req={r} />)}
                  </Section>
                  {prd.security?.abuse_cases?.length > 0 && (
                    <Section title="Abuse Cases">
                      {prd.security.abuse_cases.map((a, i) => (
                        <div key={i} style={{ fontSize: 12, color: C.textSecondary, padding: "7px 12px", background: C.surfaceAlt, borderRadius: 6, marginBottom: 5, borderLeft: `3px solid ${C.orange}` }}>{a}</div>
                      ))}
                    </Section>
                  )}
                </div>
              )}

              {/* ── Contracts tab ── */}
              {activeTab === "contracts" && (
                <div>
                  {(prd.api_contracts || []).length === 0 && (
                    <div style={{ textAlign: "center", padding: 32, color: C.textMuted, fontSize: 13 }}>No API contracts defined for this feature.</div>
                  )}
                  {(prd.api_contracts || []).map((c, i) => (
                    <div key={i} style={{ background: C.surfaceAlt, borderRadius: 10, padding: 16, marginBottom: 12, border: `1px solid ${C.border}` }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
                        <Tag label={c.id} color={C.purpleLight} bg={C.bg} />
                        <code style={{ fontSize: 13, fontWeight: 700, color: C.blueLight }}>{c.method} {c.path}</code>
                        <span style={{ fontSize: 11, color: C.textMuted }}>auth: {c.auth}</span>
                      </div>
                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                        <div><div style={{ fontSize: 10, color: C.textMuted, textTransform: "uppercase", marginBottom: 4 }}>Request</div><pre style={{ fontSize: 11, color: C.textSecondary, background: C.bg, padding: 10, borderRadius: 6, margin: 0, whiteSpace: "pre-wrap" }}>{c.request_schema}</pre></div>
                        <div><div style={{ fontSize: 10, color: C.textMuted, textTransform: "uppercase", marginBottom: 4 }}>Response</div><pre style={{ fontSize: 11, color: C.textSecondary, background: C.bg, padding: 10, borderRadius: 6, margin: 0, whiteSpace: "pre-wrap" }}>{c.response_schema}</pre></div>
                      </div>
                      {c.errors?.length > 0 && <div style={{ marginTop: 10 }}><div style={{ fontSize: 10, color: C.textMuted, textTransform: "uppercase", marginBottom: 4 }}>Errors</div>{c.errors.map((e, ei) => <div key={ei} style={{ fontSize: 11, color: C.red, marginBottom: 2 }}>→ {e}</div>)}</div>}
                    </div>
                  ))}
                </div>
              )}

              {/* ── Verification tab ── */}
              {activeTab === "matrix" && (
                <div style={{ overflowX: "auto" }}>
                  <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12 }}>
                    <thead>
                      <tr style={{ borderBottom: `1px solid ${C.border}` }}>
                        {["Req ID", "Level", "Proof Type", "Artifact", "Notes"].map(h => (
                          <th key={h} style={{ textAlign: "left", padding: "8px 12px", fontSize: 10, fontWeight: 700, color: C.textMuted, textTransform: "uppercase", letterSpacing: "0.08em" }}>{h}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {(prd.verification_matrix || []).map((r, i) => (
                        <tr key={i} style={{ borderBottom: `1px solid ${C.border}`, background: i % 2 === 0 ? "transparent" : C.surfaceAlt }}>
                          <td style={{ padding: "9px 12px" }}><code style={{ color: C.purpleLight, fontSize: 11 }}>{r.req_id}</code></td>
                          <td style={{ padding: "9px 12px" }}><Tag label={r.level} color={C.red} bg="#2d0a0a" /></td>
                          <td style={{ padding: "9px 12px" }}><Tag label={r.proof_type} color={C.blueLight} bg={C.bg} /></td>
                          <td style={{ padding: "9px 12px", color: C.textSecondary }}>{r.artifact}</td>
                          <td style={{ padding: "9px 12px", color: C.textMuted, fontSize: 11 }}>{r.notes}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {/* ── Batches tab ── */}
              {activeTab === "batches" && (
                <div>
                  {(prd.batches || []).map((b, bi) => (
                    <div key={bi} style={{ background: C.surfaceAlt, borderRadius: 10, padding: 16, marginBottom: 12, border: `1px solid ${C.border}` }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 10 }}>
                        <div>
                          <div style={{ fontSize: 13, fontWeight: 800, color: C.textPrimary }}>{b.id} — {b.name}</div>
                          <div style={{ fontSize: 12, color: C.textMuted, marginTop: 2 }}>{b.goal}</div>
                        </div>
                        <div style={{ display: "flex", gap: 4, flexWrap: "wrap", maxWidth: 200, justifyContent: "flex-end" }}>
                          {(b.covers || []).slice(0, 4).map((c, ci) => <Tag key={ci} label={c} color={C.blueLight} bg={C.bg} />)}
                        </div>
                      </div>
                      <Section title="Steps">
                        {(b.steps || []).map((s, si) => (
                          <div key={si} style={{ fontSize: 12, color: C.textPrimary, marginBottom: 5, display: "flex", gap: 10 }}>
                            <span style={{ color: C.purple, fontWeight: 700, minWidth: 18 }}>{si + 1}.</span>{s}
                          </div>
                        ))}
                      </Section>
                      <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 8 }}>
                        <div style={{ flex: 1, background: "#052e1c", border: `1px solid #065f46`, borderRadius: 6, padding: "8px 12px" }}>
                          <div style={{ fontSize: 10, color: C.green, textTransform: "uppercase", fontWeight: 700, marginBottom: 3 }}>Done when</div>
                          <div style={{ fontSize: 12, color: "#6ee7b7" }}>{b.validation}</div>
                        </div>
                        <div style={{ flex: 1, background: "#1a0a0a", border: `1px solid #4a1010`, borderRadius: 6, padding: "8px 12px" }}>
                          <div style={{ fontSize: 10, color: C.red, textTransform: "uppercase", fontWeight: 700, marginBottom: 3 }}>Risk / Rollback</div>
                          <div style={{ fontSize: 12, color: "#fca5a5" }}>{b.risks}</div>
                        </div>
                      </div>
                    </div>
                  ))}
                  {prd.risks?.length > 0 && (
                    <Section title="Risk & Mitigation">
                      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12 }}>
                        <thead>
                          <tr style={{ borderBottom: `1px solid ${C.border}` }}>
                            <th style={{ textAlign: "left", padding: "7px 12px", fontSize: 10, fontWeight: 700, color: C.textMuted, textTransform: "uppercase" }}>Risk</th>
                            <th style={{ textAlign: "left", padding: "7px 12px", fontSize: 10, fontWeight: 700, color: C.textMuted, textTransform: "uppercase" }}>Mitigation</th>
                          </tr>
                        </thead>
                        <tbody>
                          {prd.risks.map((r, i) => (
                            <tr key={i} style={{ borderBottom: `1px solid ${C.border}` }}>
                              <td style={{ padding: "8px 12px", color: "#fca5a5" }}>{r.risk}</td>
                              <td style={{ padding: "8px 12px", color: C.textSecondary }}>{r.mitigation}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </Section>
                  )}
                </div>
              )}
            </div>
          </div>
        )}

        {!prd && !loading && (
          <div style={{ textAlign: "center", padding: "52px 24px", color: C.textMuted }}>
            <div style={{ fontSize: 32, marginBottom: 12, opacity: 0.4 }}>📋</div>
            <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 6 }}>Paste a feature description and hit Generate</div>
            <div style={{ fontSize: 11, lineHeight: 1.8, maxWidth: 400, margin: "0 auto" }}>
              The pipeline runs 10 roles — Context → Scope → Constraints → Requirements → Ambiguity → Security → Contracts → Verification → Batches → Gate
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
