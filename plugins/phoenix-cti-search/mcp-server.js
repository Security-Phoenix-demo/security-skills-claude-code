#!/usr/bin/env node
/**
 * mcp-server.js — MCP tool server for cti-search-plugin
 *
 * Exposes the CTI search as a proper MCP tool that Claude Code
 * can call natively, without needing a slash command.
 *
 * Register in ~/.claude/claude_desktop_config.json:
 * {
 *   "mcpServers": {
 *     "cti-search": {
 *       "command": "node",
 *       "args": ["/path/to/cti-search-plugin/mcp-server.js"],
 *       "env": {
 *         "BRAVE_SEARCH_API_KEY": "<your-key>",
 *         "NOTEBOOKLM_NOTEBOOK_ID": "<optional>"
 *       }
 *     }
 *   }
 * }
 */

"use strict";

const readline = require("readline");
const { execFile } = require("child_process");
const path = require("path");

const PLUGIN_INDEX = path.join(__dirname, "index.js");

// index.js writes exactly one of these to stderr on every run. Its ABSENCE is
// meaningful: it means the run did not reach the point where it could account for
// itself, so nothing it printed can be vouched for.
const STATUS_PREFIX = "CTI-SEARCH-STATUS ";

/**
 * Pull the last status line out of stderr. Returns null when there is none.
 */
function parseStatus(stderr) {
  const lines = String(stderr || "").split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (!line.startsWith(STATUS_PREFIX)) continue;
    try {
      return JSON.parse(line.slice(STATUS_PREFIX.length));
    } catch {
      return null;
    }
  }
  return null;
}

/**
 * stderr with the status line taken out, because that line is for this code, not
 * for the model reading the tool result.
 */
function humanDiagnostic(stderr) {
  return String(stderr || "")
    .split(/\r?\n/)
    .filter((line) => !line.trim().startsWith(STATUS_PREFIX))
    .join("\n")
    .trim();
}

// MCP protocol: read JSON-RPC from stdin, write to stdout
const rl = readline.createInterface({ input: process.stdin });

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

// Tool manifest
const TOOLS = [
  {
    name: "cti_search",
    description:
      "Search 300+ curated security domains (BleepingComputer, Talos, Unit42, CISA, NVD, Securelist, etc.) for threat intelligence on CVEs, threat actors, malware families, exploits, or any security topic. Optionally push all found sources to a NotebookLM notebook.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "CVE ID, threat actor name, malware family, or free-text topic",
        },
        count: {
          type: "number",
          description: "Max results to return (default: 10)",
          default: 10,
        },
        tier: {
          type: "number",
          description: "Restrict to domain tier: 1=Authoritative, 2=Vendor Research, 3=News, 4=OSINT",
          enum: [1, 2, 3, 4],
        },
        since_days: {
          type: "number",
          description: "Limit results to last N days (default: 90)",
          default: 90,
        },
        full: {
          type: "boolean",
          description: "Return long-form brief with MITRE mapping (default: false)",
          default: false,
        },
        notebooklm: {
          type: "boolean",
          description: "Push found sources to NotebookLM after search",
          default: false,
        },
        notebook_id: {
          type: "string",
          description: "NotebookLM notebook ID (overrides NOTEBOOKLM_NOTEBOOK_ID env var)",
        },
      },
      required: ["query"],
    },
  },
];

rl.on("line", (line) => {
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = req;

  // Capability handshake
  if (method === "initialize") {
    send({
      jsonrpc: "2.0",
      id,
      result: {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "cti-search", version: "1.0.0" },
      },
    });
    return;
  }

  if (method === "tools/list") {
    send({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
    return;
  }

  if (method === "tools/call") {
    const { name, arguments: args } = params;

    if (name !== "cti_search") {
      send({
        jsonrpc: "2.0",
        id,
        error: { code: -32601, message: `Unknown tool: ${name}` },
      });
      return;
    }

    // Build CLI args
    const cliArgs = ["--query", args.query];
    if (args.count) cliArgs.push("--count", String(args.count));
    if (args.tier) cliArgs.push("--tier", String(args.tier));
    if (args.since_days) cliArgs.push("--since", String(args.since_days));
    if (args.full) cliArgs.push("--full");
    if (args.notebooklm) cliArgs.push("--notebooklm");
    if (args.notebook_id) cliArgs.push("--notebook-id", args.notebook_id);

    execFile("node", [PLUGIN_INDEX, ...cliArgs], (err, stdout, stderr) => {
      // The uncomfortable fact this block exists for: the previous version set
      // isError purely from `err` and dropped stderr entirely on success. With no
      // API key, index.js failed every single lookup, exited 0, and this handed the
      // model a confident, empty threat-intelligence brief with nothing at all to
      // suggest that no source had been consulted. For a CTI tool, a brief that
      // silently means "we found nothing because we asked nobody" is worse than an
      // error, because it is indistinguishable from a genuine all-clear.
      const status = parseStatus(stderr);
      const diagnostic = humanDiagnostic(stderr);
      const out = String(stdout || "");

      if (err) {
        // Non-zero exit, a spawn failure, or a killed process. index.js exits 2 when
        // every lookup failed, and in that case stdout holds the brief that explains
        // why — so hand over both halves rather than only the exception.
        const exitCode = typeof err.code === "number" ? err.code : null;

        // The census is parsed above and was then ignored right here, so a run that
        // searched successfully and failed at a step AFTER the search -- index.js
        // exits 1 when --notebooklm is passed without a notebook id -- was labelled
        // "Nothing below is a finding", throwing away a brief that was complete.
        // Telling a model to discard real intelligence is the same class of error as
        // handing it an empty brief and calling it an all-clear, in the other
        // direction. Let the census decide which sentence is true.
        const searched = status && Number(status.succeeded) > 0;
        const parts = [
          exitCode === null
            ? `CTI search could not be run: ${err.message}`
            : searched
              ? `CTI search exited ${exitCode} AFTER completing ${status.succeeded} of ` +
                `${status.attempted} lookups. The brief below is real — the failure was ` +
                `in a step after the search.`
              : `CTI search FAILED (exit ${exitCode}). Nothing below is a finding.`,
        ];
        if (out.trim()) parts.push(out.trim());
        if (diagnostic) parts.push(`--- diagnostic (stderr) ---\n${diagnostic}`);

        send({
          jsonrpc: "2.0",
          id,
          result: {
            content: [{ type: "text", text: parts.join("\n\n") }],
            isError: true,
          },
        });
        return;
      }

      // Exit 0 is not on its own proof that any lookup happened, so check the census
      // rather than the exit code.
      if (!status) {
        // No status line. Either this is an older index.js or the process died after
        // printing. Either way we cannot say how many sources were consulted, and the
        // house rule is to say so rather than pass the brief along as complete.
        const parts = [
          "WARNING: this run printed no CTI-SEARCH-STATUS line, so the number of " +
            "sources actually consulted is UNKNOWN. Treat the brief below as " +
            "unverified coverage — in particular, do not read an empty result as " +
            "'no intelligence exists'.",
          out,
        ];
        if (diagnostic) parts.push(`--- diagnostic (stderr) ---\n${diagnostic}`);
        send({
          jsonrpc: "2.0",
          id,
          result: { content: [{ type: "text", text: parts.join("\n\n") }], isError: false },
        });
        return;
      }

      if (status.succeeded === 0 && !status.dry_run) {
        // Belt and braces: index.js exits 2 on this, so `err` should already have
        // caught it. If it somehow exits 0 having searched nothing, it is still an
        // error and must never reach the model as a plain brief.
        const parts = [
          `CTI search FAILED: 0 of ${status.attempted} lookups succeeded, so none of ` +
            `the ${status.domains_enumerated} enumerated domains were queried.`,
          out,
        ];
        if (diagnostic) parts.push(`--- diagnostic (stderr) ---\n${diagnostic}`);
        send({
          jsonrpc: "2.0",
          id,
          result: { content: [{ type: "text", text: parts.join("\n\n") }], isError: true },
        });
        return;
      }

      if (status.failed > 0) {
        // A partial sweep is still worth having — it is not an error — but the model
        // has to be told the brief is incomplete before it reads the brief, not after.
        const kinds = Object.entries(status.failure_kinds || {})
          .map(([kind, n]) => `${kind} ×${n}`)
          .join(", ");
        const parts = [
          `INCOMPLETE COVERAGE: ${status.failed} of ${status.attempted} lookups failed ` +
            `(${kinds}). ${status.domains_queried} of ${status.domains_enumerated} sources ` +
            `were actually queried. An absence in the brief below is not evidence of absence.`,
          out,
        ];
        if (diagnostic) parts.push(`--- diagnostic (stderr) ---\n${diagnostic}`);
        send({
          jsonrpc: "2.0",
          id,
          result: { content: [{ type: "text", text: parts.join("\n\n") }], isError: false },
        });
        return;
      }

      // Every lookup returned. Hand back stdout unchanged, exactly as before, so that
      // callers already parsing the brief see no difference on the happy path.
      send({
        jsonrpc: "2.0",
        id,
        result: {
          content: [{ type: "text", text: stdout }],
        },
      });
    });
    return;
  }

  // Unknown method
  send({
    jsonrpc: "2.0",
    id,
    error: { code: -32601, message: `Method not found: ${method}` },
  });
});
