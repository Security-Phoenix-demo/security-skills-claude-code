#!/usr/bin/env python3
"""
Phoenix Security — Web Research Script
Primary: Brave Search API  |  Secondary: Scrapling
Usage: python3 web_research.py "query" [--count 20] [--reddit] [--json] [--quality-filter]
"""

import sys
import json
import argparse
import os
import requests
from datetime import datetime
from typing import Optional

# Quality scoring heuristics
HIGH_AUTHORITY_DOMAINS = {
    "arxiv.org": 10, "nvd.nist.gov": 10, "cisa.gov": 10,
    "owasp.org": 9, "github.com": 8, "security.googleblog.com": 9,
    "blog.cloudflare.com": 8, "portswigger.net": 9,
    "unit42.paloaltonetworks.com": 9, "blog.talosintelligence.com": 9,
    "research.checkpoint.com": 9, "mandiant.com": 9,
    "bleepingcomputer.com": 7, "krebsonsecurity.com": 8,
    "therecord.media": 7, "thehackernews.com": 6,
    "reddit.com": 5, "youtube.com": 5,
    "medium.com": 4, "substack.com": 4,
}


def score_result(url: str, title: str, description: str) -> int:
    """Score a result 0-10 based on source authority and content signals."""
    score = 3  # baseline
    domain = url.split("/")[2].replace("www.", "") if "://" in url else ""
    for d, s in HIGH_AUTHORITY_DOMAINS.items():
        if domain.endswith(d):
            score = max(score, s)
            break
    # Content signals
    technical_terms = ["CVE", "vulnerability", "exploit", "RCE", "SSRF", "injection",
                        "ASPM", "DevSecOps", "supply chain", "container", "kubernetes",
                        "zero-day", "patch", "remediation", "CISA", "MITRE"]
    combined = f"{title} {description}".lower()
    for term in technical_terms:
        if term.lower() in combined:
            score = min(score + 1, 10)
    return score


def search_brave(query: str, count: int = 20, api_key: Optional[str] = None) -> list:
    """Search using Brave Search API."""
    api_key = api_key or os.environ.get("BRAVE_API_KEY")
    if not api_key:
        print("[WARN] BRAVE_API_KEY not set, falling back to Scrapling", file=sys.stderr)
        return []

    headers = {
        "Accept": "application/json",
        "Accept-Encoding": "gzip",
        "X-Subscription-Token": api_key,
    }
    params = {"q": query, "count": min(count, 20), "search_lang": "en"}

    try:
        resp = requests.get("https://api.search.brave.com/res/v1/web/search",
                            headers=headers, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"[ERROR] Brave API error: {e}", file=sys.stderr)
        return []

    results = []
    for item in data.get("web", {}).get("results", []):
        url = item.get("url", "")
        title = item.get("title", "")
        desc = item.get("description", "")
        results.append({
            "title": title,
            "url": url,
            "description": desc,
            "published": item.get("age", ""),
            "source": url.split("/")[2].replace("www.", "") if "://" in url else "",
            "quality_score": score_result(url, title, desc),
            "engine": "brave",
        })
    return results


def search_scrapling(query: str, count: int = 20) -> list:
    """Fallback: scrape DuckDuckGo via Scrapling."""
    try:
        from scrapling import Fetcher
    except ImportError:
        print("[ERROR] scrapling not installed", file=sys.stderr)
        return []

    encoded = requests.utils.quote(query)
    url = f"https://html.duckduckgo.com/html/?q={encoded}"

    try:
        fetcher = Fetcher(auto_match=False)
        page = fetcher.get(url, stealthy_headers=True)
    except Exception as e:
        print(f"[ERROR] Scrapling fetch failed: {e}", file=sys.stderr)
        return []

    results = []
    # Parse DDG HTML results
    for result in page.css(".result")[:count]:
        title_el = result.css_first(".result__title a")
        snippet_el = result.css_first(".result__snippet")
        if not title_el:
            continue
        title = title_el.text or ""
        link = title_el.attrib.get("href", "")
        # DDG redirect URLs — extract real URL
        if "uddg=" in link:
            import urllib.parse
            qs = urllib.parse.parse_qs(urllib.parse.urlparse(link).query)
            link = qs.get("uddg", [link])[0]
        desc = snippet_el.text if snippet_el else ""
        results.append({
            "title": title,
            "url": link,
            "description": desc,
            "published": "",
            "source": link.split("/")[2].replace("www.", "") if "://" in link else "",
            "quality_score": score_result(link, title, desc),
            "engine": "scrapling/duckduckgo",
        })
    return results


def search_reddit(query: str, count: int = 10, subreddits: str = "netsec+cybersecurity+blueteamsec+devops+kubernetes") -> list:
    """Search Reddit via PRAW or RSS."""
    try:
        import praw
        reddit = praw.Reddit(
            client_id=os.environ.get("REDDIT_CLIENT_ID", ""),
            client_secret=os.environ.get("REDDIT_CLIENT_SECRET", ""),
            user_agent="phoenix-security-research/1.0",
        )
        results = []
        for submission in reddit.subreddit(subreddits).search(query, limit=count, sort="relevance", time_filter="month"):
            results.append({
                "title": submission.title,
                "url": f"https://reddit.com{submission.permalink}",
                "description": submission.selftext[:200] if submission.selftext else "",
                "published": datetime.fromtimestamp(submission.created_utc).strftime("%Y-%m-%d"),
                "source": "reddit.com",
                "quality_score": min(5 + int(submission.score / 100), 10),
                "upvotes": submission.score,
                "engine": "reddit/praw",
            })
        return results
    except Exception as e:
        print(f"[WARN] Reddit PRAW failed ({e}), trying RSS fallback", file=sys.stderr)

    # RSS fallback (no auth needed)
    results = []
    for sub in subreddits.split("+")[:3]:
        try:
            import feedparser
            feed_url = f"https://www.reddit.com/r/{sub}/search.rss?q={requests.utils.quote(query)}&sort=relevance&t=month"
            feed = feedparser.parse(feed_url)
            for entry in feed.entries[:count // 3]:
                results.append({
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "description": "",
                    "published": entry.get("published", ""),
                    "source": f"reddit.com/r/{sub}",
                    "quality_score": 5,
                    "engine": "reddit/rss",
                })
        except Exception:
            continue
    return results


def deduplicate(results: list) -> list:
    seen = set()
    out = []
    for r in results:
        key = r["url"].rstrip("/")
        if key not in seen:
            seen.add(key)
            out.append(r)
    return out


def main():
    parser = argparse.ArgumentParser(description="Phoenix Security — Web Research")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--reddit", action="store_true", help="Include Reddit results")
    parser.add_argument("--min-quality", type=int, default=0, help="Minimum quality score 0-10")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--urls-only", action="store_true")
    parser.add_argument("--brave-key", help="Brave API key (or set BRAVE_API_KEY env)")
    args = parser.parse_args()

    all_results = []

    # Primary: Brave
    brave_results = search_brave(args.query, args.count, args.brave_key)
    all_results.extend(brave_results)

    # Fallback to Scrapling if Brave returned nothing
    if not brave_results:
        print("[INFO] Using Scrapling/DuckDuckGo fallback", file=sys.stderr)
        all_results.extend(search_scrapling(args.query, args.count))

    # Optional: Reddit
    if args.reddit:
        all_results.extend(search_reddit(args.query, 10))

    # Deduplicate and quality filter
    all_results = deduplicate(all_results)
    if args.min_quality > 0:
        all_results = [r for r in all_results if r["quality_score"] >= args.min_quality]

    # Sort by quality score
    all_results.sort(key=lambda x: x["quality_score"], reverse=True)

    if not all_results:
        print("[WARN] No results found", file=sys.stderr)
        sys.exit(1)

    if args.json_output:
        print(json.dumps(all_results, indent=2))
    elif args.urls_only:
        for r in all_results:
            print(r["url"])
    else:
        print(f"\n{'='*80}\n  Web Research: {args.query}")
        print(f"  Found: {len(all_results)} — {datetime.now().strftime('%Y-%m-%d %H:%M')}\n{'='*80}\n")
        for i, r in enumerate(all_results, 1):
            stars = "★" * r["quality_score"] + "☆" * (10 - r["quality_score"])
            print(f"[{i:02d}] [{stars[:5]}] {r['title']}")
            print(f"     {r['source']} | {r['published']}")
            print(f"     {r['url']}")
            if r["description"]:
                print(f"     {r['description'][:120]}")
            print()


if __name__ == "__main__":
    main()
