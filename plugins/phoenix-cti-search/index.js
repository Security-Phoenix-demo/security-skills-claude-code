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

  return (resp.data.web?.results || []).map((r) => ({
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
  return (resp.data.organic_results || []).map((r) => ({
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
  lines.push(`> Sources searched: ${opts.domainsSearched || 0} domains across ${opts.tiersUsed?.join(", ") || "all"} tiers`);
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

  // Next steps
  lines.push("### Next Steps");
  if (tags.cves.length) {
    lines.push(`- Patch check: ${tags.cves.slice(0, 3).join(", ")}`);
  }
  if (tags.mitre.length) {
    lines.push(`- Hunt for: ${tags.mitre.slice(0, 5).join(", ")}`);
  }
  lines.push(`- Full raw results: re-run with \`--json\` flag`);
  if (!opts.notebooklm) {
    lines.push(`- Push to NotebookLM: re-run with \`--notebooklm\` flag`);
  }

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

  // Build per-tier searches
  const allResults = [];
  let totalDomains = 0;

  for (const tier of tiers) {
    const domains = getDomainsForTier(tier);
    totalDomains += domains.length;

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

      try {
        const results = await executeSearch(q, count, since);
        allResults.push(...results);
      } catch (err) {
        console.error(`  ✗ Tier ${tier} search failed: ${err.message}`);
      }
    }
  }

  if (opts.dryRun) {
    console.log(`\nDry run complete. Would search ${totalDomains} domains.`);
    process.exit(0);
  }

  const ranked = rankResults(allResults).slice(0, count * 2);
  const tags = extractTags(ranked);

  // Output
  if (opts.json) {
    console.log(JSON.stringify(ranked, null, 2));
  } else {
    const brief = formatBrief(query, ranked, tags, {
      domainsSearched: totalDomains,
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
