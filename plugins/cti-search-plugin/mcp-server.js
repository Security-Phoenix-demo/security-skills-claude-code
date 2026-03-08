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
      if (err) {
        send({
          jsonrpc: "2.0",
          id,
          result: {
            content: [{ type: "text", text: `Error: ${stderr || err.message}` }],
            isError: true,
          },
        });
        return;
      }

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
