#!/usr/bin/env node
/**
 * cti-search-plugin — CTI Domain Research Plugin for Claude Code
 *
 * Searches 300+ curated security sources and optionally pushes to NotebookLM.
 *
 * Usage (standalone):
 *   node index.js --query "CVE-2024-21762" --count 10 --full
 *   node index.js --query "LockBit ransomware" --notebooklm --notebook-id <id>
 *
 * Usage (from Claude Code slash command):
 *   /cti-search CVE-2024-21762 --full
 *   /cti-search LockBit --notebooklm
 *
 * Usage (as MCP tool):
 *   Called by Claude via the MCP server defined in mcp-server.js
 */

"use strict";

require("dotenv").config();
const { Command } = require("commander");
const axios = require("axios");
const path = require("path");
const fs = require("fs");

// ─── Configuration ───────────────────────────────────────────────────────────

const TIER_MAP = JSON.parse(
  fs.readFileSync(path.join(__dirname, "data", "tier-map.json"), "utf8")
);

const ALL_DOMAINS = fs
  .readFileSync(path.join(__dirname, "data", "domains.txt"), "utf8")
  .split("\n")
  .map((d) => d.trim())
  .filter(Boolean);

const SEARCH_API_URL = "https://api.search.brave.com/res/v1/web/search";
// Alternatively swap in SerpAPI, Google Custom Search, or Bing Search API.
// Set SEARCH_PROVIDER=brave|serpapi|google in .env

// ─── Tier Routing ────────────────────────────────────────────────────────────

/**
 * Detect query type and return ordered list of domain tiers to search.
 */
function routeTiers(query) {
  const q = query.toLowerCase();
  if (/cve-\d{4}-\d+/.test(q)) return [1, 2, 4];          // CVE → authoritative first
  if (/ransomware|apt|actor|group|gang/.test(q)) return [2, 4, 3]; // Threat actor
  if (/malware|rat|trojan|backdoor|stealer/.test(q)) return [2, 4]; // Malware
  if (/poc|exploit|0day|zero.?day/.test(q)) return [4, 2]; // Exploit
  if (/breach|leak|incident/.test(q)) return [3, 2];       // News
  if (/iot|ics|ot|scada/.test(q)) return [2, 1];           // ICS/OT
  if (/cloud|aws|gcp|azure|k8s|container/.test(q)) return [2, 3]; // Cloud
  return [1, 2, 3, 4]; // General — all tiers
}

/**
 * Get domains for a given tier, sorted by authority score.
 */
function getDomainsForTier(tier) {
  const tierDomains = Object.entries(TIER_MAP.domains)
    .filter(([, v]) => v.tier === tier)
    .sort(([, a], [, b]) => b.score - a.score)
    .map(([domain]) => domain);

  // Fall back to full list for any domain not in tier map
  const unmapped = ALL_DOMAINS.filter((d) => !TIER_MAP.domains[d]);
  return [...tierDomains, ...unmapped].slice(0, 30); // cap per batch
}

// ─── Search Execution ────────────────────────────────────────────────────────

/**
 * Build a site:-scoped search query for a batch of domains.
 */
function buildSiteQuery(subject, domains, maxDomains = 10) {
  const siteClause = domains
    .slice(0, maxDomains)
    .map((d) => `site:${d}`)
    .join(" OR ");
  return `${subject} (${siteClause})`;
}

/**
 * Execute search via Brave Search API.
 * Swap out searchBrave() for searchSerpApi() / searchGoogleCSE() as needed.
 */
async function searchBrave(query, count = 10, since = 90) {
  const apiKey = process.env.BRAVE_SEARCH_API_KEY;
  if (!apiKey) {
    throw new Error(
      "BRAVE_SEARCH_API_KEY not set. Add to .env or export in shell.\n" +
      "Alternatively set SEARCH_PROVIDER=serpapi and SERPAPI_KEY=<key>."
    );
  }

  const freshness = since <= 7 ? "pw" : since <= 30 ? "pm" : since <= 365 ? "py" : null;

  const params = {
    q: query,
    count,
    ...(freshness && { freshness }),
  };

  const resp = await axios.get(SEARCH_API_URL, {
    headers: {
      Accept: "application/json",
      "Accept-Encoding": "gzip",
      "X-Subscription-Token": apiKey,
    },
    params,
  });

  // A 200 is not an answer. A TLS-intercepting proxy, a captive portal, an SSO
  // splash page and a future schema change all return 200 with a body this code
  // cannot read, and `|| []` turned every one of them into a lookup that
  // succeeded and found nothing. That is byte-for-byte the brief this file was
  // just fixed to stop producing, one layer in: searchesSucceeded counted
  // 'axios did not throw', not 'the provider answered'.
  const body = resp.data;
  if (!body || typeof body !== "object" || !("web" in body || "query" in body || "type" in body)) {
    throw new Error(
      `Brave returned HTTP ${resp.status} with a body that is not a Brave search response ` +
        `(${typeof body === "string" ? "non-JSON text, likely a proxy or captive portal" : "JSON without web/query/type"})`
    );
  }

  return (body.web?.results || []).map((r) => ({
    title: r.title,
    url: r.url,
    source: new URL(r.url).hostname.replace(/^www\./, ""),
    published: r.page_age || null,
    description: r.description || "",
  }));
}

async function searchSerpApi(query, count = 10) {
  const apiKey = process.env.SERPAPI_KEY;
  if (!apiKey) throw new Error("SERPAPI_KEY not set");
  const resp = await axios.get("https://serpapi.com/search", {
    params: { q: query, api_key: apiKey, num: count, engine: "google" },
  });
  // Same reasoning as the Brave branch above.
  const body = resp.data;
  if (!body || typeof body !== "object" ||
      !("organic_results" in body || "search_metadata" in body || "search_information" in body)) {
    throw new Error(
      `SerpAPI returned HTTP ${resp.status} with a body that is not a SerpAPI search response ` +
        `(${typeof body === "string" ? "non-JSON text, likely a proxy or captive portal" : "JSON without the expected keys"})`
    );
  }

  return (body.organic_results || []).map((r) => ({
    title: r.title,
    url: r.link,
    source: new URL(r.link).hostname.replace(/^www\./, ""),
    published: r.date || null,
    description: r.snippet || "",
  }));
}

async function executeSearch(query, count, since) {
  const provider = process.env.SEARCH_PROVIDER || "brave";
  if (provider === "serpapi") return searchSerpApi(query, count);
  return searchBrave(query, count, since);
}

// ─── Failure Accounting ──────────────────────────────────────────────────────

/**
 * Why did a lookup fail? The distinction is the whole value of the message.
 *
 * "Search failed" tells the reader nothing they can act on. A missing key is a
 * thirty-second fix by whoever ran this; a 401 means a key is present but wrong,
 * which is a different thirty seconds; a DNS failure may be the corporate proxy and
 * is worth a retry; a 429 means slow down. Collapsing all four into one sentence is
 * how an operator ends up re-running the same broken command four times.
 */
function classifyFailure(err) {
  const msg = err && err.message ? String(err.message) : String(err);
  const firstLine = msg.split("\n")[0];
  const status = err && err.response ? err.response.status : undefined;

  if (/_KEY not set/i.test(msg)) {
    return { kind: "missing-credentials", detail: firstLine };
  }
  if (status === 401 || status === 403) {
    return {
      kind: "rejected-credentials",
      detail: `search API returned HTTP ${status} — a key was sent and refused`,
    };
  }
  if (status === 429) {
    return { kind: "rate-limited", detail: "search API returned HTTP 429 — rate limited" };
  }
  if (status) {
    return { kind: "api-error", detail: `search API returned HTTP ${status}` };
  }
  if (
    err &&
    typeof err.code === "string" &&
    /^(ENOTFOUND|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN|ECONNRESET|ECONNABORTED|EHOSTUNREACH|ENETUNREACH|CERT_|UNABLE_TO_)/.test(
      err.code
    )
  ) {
    return { kind: "network-error", detail: `${err.code} reaching the search API — ${firstLine}` };
  }
  // A 200 carrying something that is not a search response. Worth its own kind:
  // "unknown" sends the reader to "re-run and see if it reproduces", and this one
  // reproduces every time until somebody looks at the proxy.
  if (/is not a (Brave|SerpAPI) search response/.test(firstLine)) {
    return { kind: "not-a-search-response", detail: firstLine };
  }

  return { kind: "unknown", detail: firstLine };
}

const REMEDIATION = {
  "missing-credentials":
    "set BRAVE_SEARCH_API_KEY (or SEARCH_PROVIDER=serpapi with SERPAPI_KEY) in the plugin's .env, " +
    "or in the env block of the MCP server entry that launches this. See .env.example.",
  "rejected-credentials":
    "the key is present but the provider refused it — check it has not expired and that the " +
    "subscription is active.",
  "rate-limited":
    "wait, then re-run with a lower --count or a single --tier so that fewer calls are made.",
  "network-error":
    "this host cannot reach the search API — check connectivity, DNS, and any outbound proxy " +
    "or TLS interception.",
  "api-error": "see the HTTP status above; re-run once the provider is healthy.",
  "not-a-search-response":
    "the provider answered with HTTP 200 but the body is not a search result — this is " +
    "what a TLS-intercepting proxy, a captive portal or an SSO splash page returns. " +
    "Check outbound proxying from this host, then confirm the API contract has not changed.",
  unknown: "see the message above; re-run with the same arguments to confirm it is reproducible.",
};

/**
 * One-line tally, e.g. "missing-credentials ×9".
 */
function summariseFailures(failures) {
  const counts = new Map();
  for (const f of failures) counts.set(f.kind, (counts.get(f.kind) || 0) + 1);
  return [...counts.entries()].map(([kind, n]) => `${kind} ×${n}`).join(", ");
}

/**
 * A machine-readable census of what actually happened, written to stderr on EVERY
 * run — success, partial, total failure and dry run alike.
 *
 * It is always emitted because its ABSENCE has to mean something. mcp-server.js
 * treats a missing status line as "this run cannot be vouched for" rather than as
 * success, and that only works if a healthy run is guaranteed to print one.
 */
const STATUS_PREFIX = "CTI-SEARCH-STATUS ";

function emitStatus(status) {
  console.error(STATUS_PREFIX + JSON.stringify(status));
}

// ─── Result Processing ───────────────────────────────────────────────────────

/**
 * Score a result based on source tier and recency.
 */
function scoreResult(result) {
  const domainInfo = TIER_MAP.domains[result.source] || { tier: 3, score: 5 };
  const authorityScore = domainInfo.score * 10;
  const recencyScore = result.published ? 10 : 0; // basic — improve with date parsing
  return authorityScore + recencyScore;
}

/**
 * Deduplicate results by URL and sort by score.
 */
function rankResults(results) {
  const seen = new Set();
  return results
    .filter((r) => {
      if (seen.has(r.url)) return false;
      seen.add(r.url);
      return true;
    })
    .map((r) => ({ ...r, _score: scoreResult(r) }))
    .sort((a, b) => b._score - a._score);
}

/**
 * Extract CVE IDs, MITRE T-IDs, and common IOC patterns from descriptions.
 */
function extractTags(results) {
  const text = results.map((r) => `${r.title} ${r.description}`).join(" ");
  const cves = [...new Set(text.match(/CVE-\d{4}-\d{4,7}/gi) || [])];
  const mitre = [...new Set(text.match(/T\d{4}(?:\.\d{3})?/g) || [])];
  const ips = [...new Set(text.match(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g) || [])].slice(0, 10);
  return { cves, mitre, ips };
}

// ─── Output Formatters ───────────────────────────────────────────────────────

function formatBrief(query, results, tags, opts = {}) {
  const date = new Date().toISOString().split("T")[0];
  const lines = [];

  lines.push(`## CTI Brief: ${query} — ${date}`);
  // opts.domainsQueried counts only domains that sat inside a lookup which RETURNED.
  // The old code passed the ENUMERATED count here, so a run in which every lookup
  // threw still announced "90 domains searched" — the most load-bearing sentence in
  // the brief was the one furthest from the truth.
  lines.push(`> Sources searched: ${opts.domainsQueried || 0} domains across ${opts.tiersUsed?.join(", ") || "all"} tiers`);
  const failures = opts.failures || [];
  if (failures.length > 0) {
    const missed = (opts.domainsEnumerated || 0) - (opts.domainsQueried || 0);
    lines.push(
      `> **INCOMPLETE: ${failures.length} of ${opts.searchesAttempted || 0} lookups failed** ` +
      `(${summariseFailures(failures)}). ${missed} domain${missed === 1 ? " was" : "s were"} ` +
      `never queried — an absence below is not evidence of absence.`
    );
  }
  lines.push("");

  // Key findings (top 5 summarised)
  lines.push("### Key Findings");
  results.slice(0, 5).forEach((r) => {
    const tier = TIER_MAP.domains[r.source]?.tier || "?";
    const tags = TIER_MAP.domains[r.source]?.tags?.join(", ") || "";
    lines.push(`- **[T${tier}]** [${r.title}](${r.url})`);
    lines.push(`  ${r.source}${r.published ? ` — ${r.published}` : ""} ${tags ? `| ${tags}` : ""}`);
    if (r.description) lines.push(`  > ${r.description.slice(0, 180)}...`);
  });
  lines.push("");

  // Full source table
  lines.push("### Source Table");
  lines.push("| Tier | Source | Title | Date |");
  lines.push("|------|--------|-------|------|");
  results.forEach((r) => {
    const tier = TIER_MAP.domains[r.source]?.tier || "?";
    const shortTitle = r.title.slice(0, 60) + (r.title.length > 60 ? "…" : "");
    lines.push(`| T${tier} | ${r.source} | [${shortTitle}](${r.url}) | ${r.published || "—"} |`);
  });
  lines.push("");

  // Tags/IOCs
  lines.push("### Observed Tags");
  if (tags.cves.length) lines.push(`**CVEs:** ${tags.cves.join(", ")}`);
  if (tags.mitre.length) lines.push(`**MITRE ATT&CK:** ${tags.mitre.join(", ")}`);
  if (tags.ips.length) lines.push(`**IPs observed in snippets:** ${tags.ips.join(", ")}`);
  lines.push("");

  // Coverage gaps — printed before Next Steps so that a reader skimming upward from
  // the recommendations hits the caveat before they act on partial data.
  if (failures.length > 0) {
    lines.push("### Coverage Gaps");
    const byKind = new Map();
    for (const f of failures) {
      if (!byKind.has(f.kind)) {
        byKind.set(f.kind, { count: 0, detail: f.detail, tiers: new Set() });
      }
      const entry = byKind.get(f.kind);
      entry.count += 1;
      entry.tiers.add(f.tier);
    }
    for (const [kind, info] of byKind) {
      lines.push(
        `- **${kind}** — ${info.count} lookup${info.count === 1 ? "" : "s"} ` +
        `(tier${info.tiers.size === 1 ? "" : "s"} ${[...info.tiers].join(", ")}): ${info.detail}`
      );
      lines.push(`  - Fix: ${REMEDIATION[kind] || REMEDIATION.unknown}`);
    }
    lines.push("");
  }

  // Next steps
  lines.push("### Next Steps");
  if (failures.length > 0) {
    lines.push(
      `- **Re-run once the gaps above are fixed.** This brief saw ${opts.domainsQueried || 0} of ` +
      `${opts.domainsEnumerated || 0} sources; it is not a full sweep.`
    );
  }
  if (tags.cves.length) {
    lines.push(`- Patch check: ${tags.cves.slice(0, 3).join(", ")}`);
  }
  if (tags.mitre.length) {
    lines.push(`- Hunt for: ${tags.mitre.slice(0, 5).join(", ")}`);
  }
  // Say which shape --json returns, because this line used to route a reader from an
  // INCOMPLETE-marked brief to output that carried no such marking at all.
  lines.push(
    `- Full raw results: re-run with \`--json\` flag` +
      (opts.searchesAttempted && opts.searchesSucceeded !== opts.searchesAttempted
        ? ` (it returns an object with \`incomplete: true\` and the same census while lookups are failing)`
        : ``)
  );
  if (!opts.notebooklm) {
    lines.push(`- Push to NotebookLM: re-run with \`--notebooklm\` flag`);
  }

  return lines.join("\n");
}

/**
 * The brief for a run in which every lookup failed.
 *
 * It keeps the "## CTI Brief" heading because whatever reads this is looking for that
 * shape, but every line under it says the same thing: nothing was searched, so there
 * are no findings and no absences either. A CTI consumer that cannot distinguish
 * "nobody has published on this actor" from "we asked nobody" will draw exactly the
 * wrong conclusion from a clean empty page — and a clean empty page, with exit 0 and a
 * claim that 90 domains had been searched, is what this used to print.
 */
function formatFailureReport(query, opts) {
  const date = new Date().toISOString().split("T")[0];
  const lines = [];

  lines.push(`## CTI Brief: ${query} — ${date}`);
  lines.push("> **SEARCH FAILED — no intelligence was gathered.**");
  lines.push(
    `> 0 of ${opts.searchesAttempted} lookups succeeded, so 0 of ${opts.domainsEnumerated} ` +
    `enumerated domains were actually queried.`
  );
  lines.push(
    "> There are no findings below because there was no search — not because there is nothing to find."
  );
  lines.push("");

  lines.push("### Why every lookup failed");
  const byKind = new Map();
  for (const f of opts.failures) {
    if (!byKind.has(f.kind)) byKind.set(f.kind, { count: 0, detail: f.detail });
    byKind.get(f.kind).count += 1;
  }
  if (byKind.size === 0) {
    // Zero attempts is its own bug and must not be reported as zero results: it means
    // no domain batch was constructed at all, which points at the data files rather
    // than at the search provider.
    lines.push(
      `- **no-lookups-attempted** — not one search was constructed for ` +
      `tier${opts.tiersUsed.length === 1 ? "" : "s"} ${opts.tiersUsed.join(", ")}. ` +
      `Check that data/tier-map.json and data/domains.txt exist and are non-empty.`
    );
  } else {
    for (const [kind, info] of byKind) {
      lines.push(`- **${kind}** — ${info.count} lookup${info.count === 1 ? "" : "s"}: ${info.detail}`);
      lines.push(`  - Fix: ${REMEDIATION[kind] || REMEDIATION.unknown}`);
    }
  }
  lines.push("");

  lines.push("### Next Steps");
  lines.push('- Fix the cause above and re-run. Do not record this query as "no results found".');

  return lines.join("\n");
}

// ─── NotebookLM Integration ──────────────────────────────────────────────────

async function pushToNotebookLM(notebookId, results, query) {
  const pluginPath = path.join(
    process.env.HOME,
    ".claude",
    "plugins",
    "notebooklm-connector",
    "index.js"
  );

  if (!fs.existsSync(pluginPath)) {
    console.error(
      "\n⚠ NotebookLM connector not installed.\n" +
      "  Install: git clone https://github.com/Security-Phoenix-demo/security-skills-claude-code /tmp/ccz\n" +
      "           cp -r /tmp/ccz/plugins/notebooklm-connector ~/.claude/plugins/\n" +
      "           cd ~/.claude/plugins/notebooklm-connector && npm install\n\n" +
      "Fallback: source URLs for manual import below:\n"
    );
    results.forEach((r) => console.log(`  ${r.url}`));
    return false;
  }

  // Call the connector plugin directly as a Node module
  try {
    const connector = require(pluginPath);
    const sources = results.map((r) => ({
      url: r.url,
      title: r.title,
    }));

    await connector.addSources({
      notebookId,
      sources,
      title: `CTI: ${query} — ${new Date().toISOString().split("T")[0]}`,
    });

    console.log(`\n✓ Pushed ${sources.length} sources to NotebookLM notebook: ${notebookId}`);
    return true;
  } catch (err) {
    console.error(`\n✗ NotebookLM push failed: ${err.message}`);
    console.error("  Falling back to manual source list:");
    results.forEach((r) => console.log(`  ${r.url}`));
    return false;
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const program = new Command();

  program
    .name("cti-search")
    .description("Search 300+ security domains for CTI on any CVE, actor, malware, or topic")
    .argument("[query...]", "Search query")
    .option("-q, --query <string>", "Search query (alternative to positional arg)")
    .option("-c, --count <n>", "Number of results per tier batch", "10")
    .option("--tier <n>", "Restrict to tier 1|2|3|4 only")
    .option("--since <days>", "Limit to last N days", "90")
    .option("--full", "Long-form brief with full source analysis")
    .option("--json", "Output raw JSON")
    .option("--notebooklm", "Push sources to NotebookLM after search")
    .option("--notebook-id <id>", "NotebookLM notebook ID (overrides NOTEBOOKLM_NOTEBOOK_ID env)")
    .option("--dry-run", "Print constructed queries without executing")
    .parse(process.argv);

  const opts = program.opts();
  const args = program.args;
  const query = opts.query || args.join(" ");

  if (!query) {
    program.help();
    process.exit(1);
  }

  const count = parseInt(opts.count, 10);
  const since = parseInt(opts.since, 10);
  const tiers = opts.tier ? [parseInt(opts.tier, 10)] : routeTiers(query);

  if (!opts.json) {
    console.error(`\n🔍 CTI Search: "${query}"`);
    console.error(`   Tiers: ${tiers.join(", ")} | Count: ${count} | Since: ${since}d\n`);
  }

  // Build per-tier searches.
  //
  // Two counts, deliberately kept apart, because conflating them is the defect this
  // accounting exists to prevent: domainsEnumerated is how many domains we LISTED,
  // domainsQueried is how many sat inside a lookup that actually came back. Only the
  // second one is a fact about the world; the first is a fact about our data files.
  const allResults = [];
  const failures = [];
  let domainsEnumerated = 0;
  let domainsQueried = 0;
  let searchesAttempted = 0;
  let searchesSucceeded = 0;

  for (const tier of tiers) {
    const domains = getDomainsForTier(tier);
    domainsEnumerated += domains.length;

    // Batch domains into groups of 10 (site: query length limit)
    const batches = [];
    for (let i = 0; i < Math.min(domains.length, 30); i += 10) {
      batches.push(domains.slice(i, i + 10));
    }

    for (const batch of batches) {
      const q = buildSiteQuery(query, batch);

      if (opts.dryRun) {
        console.log(`[Tier ${tier} batch] ${q}\n`);
        continue;
      }

      searchesAttempted += 1;
      try {
        const results = await executeSearch(q, count, since);
        searchesSucceeded += 1;
        domainsQueried += batch.length;
        allResults.push(...results);
      } catch (err) {
        const failure = classifyFailure(err);
        failures.push({ tier, kind: failure.kind, detail: failure.detail });
        console.error(`  ✗ Tier ${tier} lookup failed [${failure.kind}]: ${failure.detail}`);
      }
    }
  }

  if (opts.dryRun) {
    console.log(`\nDry run complete. Would search ${domainsEnumerated} domains.`);
    emitStatus({
      dry_run: true,
      attempted: 0,
      succeeded: 0,
      failed: 0,
      domains_queried: 0,
      domains_enumerated: domainsEnumerated,
      tiers,
    });
    process.exit(0);
  }

  emitStatus({
    dry_run: false,
    attempted: searchesAttempted,
    succeeded: searchesSucceeded,
    failed: failures.length,
    domains_queried: domainsQueried,
    domains_enumerated: domainsEnumerated,
    tiers,
    failure_kinds: failures.reduce((acc, f) => {
      acc[f.kind] = (acc[f.kind] || 0) + 1;
      return acc;
    }, {}),
  });

  // Nothing came back from anywhere. That is a failed run, not an empty result set.
  //
  // The old code fell through to formatBrief() here and printed a confident, empty
  // brief with exit 0. For a CTI tool that is the worst possible output: the reader
  // cannot tell "no source has published on this" from "we asked no source", and the
  // two lead to opposite decisions. So: say why, on stdout where the brief goes, and
  // exit non-zero. 2 rather than 1, because 1 is this script's generic fatal.
  if (searchesSucceeded === 0) {
    const report = formatFailureReport(query, {
      searchesAttempted,
      domainsEnumerated,
      failures,
      tiersUsed: tiers,
    });

    if (opts.json) {
      // The happy path's shape is an array, and it is held on the happy path only.
      // Here there is nothing to hold: printing [] with exit 0 is exactly the lie
      // being removed, and an object makes a caller that ignores the exit code fail
      // loudly (undefined.length) rather than quietly record "0 results".
      console.log(
        JSON.stringify(
          {
            error: "all-lookups-failed",
            query,
            searches_attempted: searchesAttempted,
            searches_succeeded: 0,
            domains_queried: 0,
            domains_enumerated: domainsEnumerated,
            failures,
          },
          null,
          2
        )
      );
    } else {
      console.log(report);
    }

    // The report is NOT echoed to stderr. The per-lookup lines above and the status
    // line already record the failure there, and anything reading both streams —
    // mcp-server.js does — would otherwise show the same page twice.
    //
    // exitCode rather than exit(), so the stdout write above is flushed when stdout
    // is a pipe, which it always is under the MCP server.
    process.exitCode = 2;
    return;
  }

  const ranked = rankResults(allResults).slice(0, count * 2);
  const tags = extractTags(ranked);

  // Output
  if (opts.json) {
    // A complete run prints the bare array it always printed. An INCOMPLETE one must
    // not: with 5 of 9 lookups failed, stdout was a well-formed array and exit 0, and
    // nothing in it said that 50 of 90 domains were never queried -- while the brief's
    // own Next Steps sent the reader here for "full raw results". Total failure
    // already returns an object for this reason; partial failure now does too, so a
    // caller that ignores the census fails loudly rather than quietly recording a
    // short list as the whole answer.
    if (failures.length > 0) {
      console.log(
        JSON.stringify(
          {
            incomplete: true,
            query,
            searches_attempted: searchesAttempted,
            searches_succeeded: searchesSucceeded,
            domains_queried: domainsQueried,
            domains_enumerated: domainsEnumerated,
            failures,
            results: ranked,
          },
          null,
          2
        )
      );
    } else {
      console.log(JSON.stringify(ranked, null, 2));
    }
  } else {
    const brief = formatBrief(query, ranked, tags, {
      domainsQueried,
      domainsEnumerated,
      searchesAttempted,
      searchesSucceeded,
      failures,
      tiersUsed: tiers,
      notebooklm: opts.notebooklm,
    });
    console.log(brief);
  }

  // NotebookLM push
  if (opts.notebooklm) {
    const notebookId =
      opts.notebookId || process.env.NOTEBOOKLM_NOTEBOOK_ID;

    if (!notebookId) {
      console.error(
        "\n✗ No notebook ID. Pass --notebook-id <id> or set NOTEBOOKLM_NOTEBOOK_ID env var."
      );
      process.exit(1);
    }

    await pushToNotebookLM(notebookId, ranked, query);
  }
}

main().catch((err) => {
  console.error(`\nFatal: ${err.message}`);
  process.exit(1);
});
