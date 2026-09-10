#!/usr/bin/env python3
"""
Phoenix Security — Research Pipeline Orchestrator
Combines YouTube + Web + Reddit research and pushes to NotebookLM.

Usage:
  python3 research_pipeline.py "CISA KEV exploited vulnerabilities 2025" --count 25 --notebooklm
  python3 research_pipeline.py "container security kubernetes" --youtube --web --reddit --notebooklm
  python3 research_pipeline.py  # Interactive mode — prompts for topic
"""

import sys
import json
import argparse
import subprocess
import os
import tempfile
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent


def run_youtube(query: str, count: int) -> list:
    print(f"\n[1/3] YouTube research: '{query}'")
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "youtube_research.py"), query,
         "--count", str(count), "--json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  [WARN] YouTube: {result.stderr.strip()[:200]}")
        return []
    try:
        data = json.loads(result.stdout)
        print(f"  ✓ {len(data)} YouTube results")
        return data
    except Exception as e:
        print(f"  [WARN] YouTube JSON parse failed: {e}")
        return []


def run_web(query: str, count: int, reddit: bool = False) -> list:
    print(f"\n[2/3] Web research: '{query}'")
    cmd = [sys.executable, str(SCRIPT_DIR / "web_research.py"), query,
           "--count", str(count), "--json"]
    if reddit:
        cmd.append("--reddit")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  [WARN] Web: {result.stderr.strip()[:200]}")
        return []
    try:
        data = json.loads(result.stdout)
        print(f"  ✓ {len(data)} web results")
        return data
    except Exception as e:
        print(f"  [WARN] Web JSON parse failed: {e}")
        return []


def push_to_notebooklm(urls: list, title: str, backend: str, prompt_type: str,
                        notebook_id: str = None) -> dict:
    print(f"\n[3/3] Pushing {len(urls)} sources to NotebookLM ({backend})...")

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        for url in urls:
            f.write(url + "\n")
        tmp_path = f.name

    cmd = [sys.executable, str(SCRIPT_DIR / "notebooklm_push.py"),
           "--urls", tmp_path,
           "--title", title,
           "--backend", backend,
           "--prompt", prompt_type,
           "--json"]
    if notebook_id:
        cmd.extend(["--notebook-id", notebook_id])

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    os.unlink(tmp_path)

    if result.returncode != 0:
        print(f"  [ERROR] NotebookLM push failed: {result.stderr.strip()[:300]}")
        return {"success": False}

    try:
        return json.loads(result.stdout)
    except Exception:
        return {"success": True, "raw": result.stdout}


def format_summary(query: str, yt_results: list, web_results: list, nb_result: dict):
    """Print a clean research summary."""
    print(f"\n{'='*80}")
    print(f"  PHOENIX SECURITY RESEARCH SUMMARY")
    print(f"  Topic: {query}")
    print(f"  Date:  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*80}\n")

    if yt_results:
        print(f"YouTube Results ({len(yt_results)}):")
        for r in yt_results[:5]:
            print(f"  [{r['views_formatted']:>6}] {r['title'][:70]}")
            print(f"           {r['url']}")

    if web_results:
        print(f"\nWeb Results ({len(web_results)}):")
        for r in web_results[:5]:
            stars = r.get("quality_score", 5)
            print(f"  [Q:{stars}/10] {r['title'][:70]}")
            print(f"           {r['url']}")

    if nb_result and nb_result.get("success"):
        print(f"\nNotebookLM:")
        print(f"  URL:     {nb_result.get('notebook_url','')}")
        print(f"  Sources: {nb_result.get('sources_added',0)} added")
        if nb_result.get("analysis_preview"):
            print(f"\n  Analysis Preview:")
            print(f"  {nb_result['analysis_preview'][:400]}")

    print(f"\n{'='*80}\n")


def main():
    parser = argparse.ArgumentParser(description="Phoenix Security Research Pipeline")
    parser.add_argument("topic", nargs="?", help="Research topic (prompts if omitted)")
    parser.add_argument("--count", type=int, default=25, help="Results per source")
    parser.add_argument("--youtube", action="store_true", default=True)
    parser.add_argument("--web", action="store_true", default=True)
    parser.add_argument("--reddit", action="store_true")
    parser.add_argument("--no-youtube", action="store_true")
    parser.add_argument("--no-web", action="store_true")
    parser.add_argument("--notebooklm", action="store_true", help="Push to NotebookLM")
    parser.add_argument("--backend", choices=["teng", "jacob"], default="teng")
    parser.add_argument("--prompt", choices=["blog", "slides", "video"], default="blog")
    parser.add_argument("--notebook-id", help="Existing NotebookLM notebook ID")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--min-quality", type=int, default=5, help="Min web quality score")
    args = parser.parse_args()

    # Prompt for topic if not provided
    topic = args.topic
    if not topic:
        topic = input("\nWhat topic do you want to research? > ").strip()
        if not topic:
            print("[ERROR] No topic provided")
            sys.exit(1)

    do_youtube = args.youtube and not args.no_youtube
    do_web = args.web and not args.no_web

    all_urls = []
    yt_results = []
    web_results = []

    if do_youtube:
        yt_results = run_youtube(topic, args.count)
        all_urls.extend([r["url"] for r in yt_results])

    if do_web:
        web_results = run_web(topic, args.count, args.reddit)
        # Quality filter
        filtered = [r for r in web_results if r.get("quality_score", 0) >= args.min_quality]
        all_urls.extend([r["url"] for r in filtered])
        if len(filtered) < len(web_results):
            print(f"  (Quality filter: kept {len(filtered)}/{len(web_results)})")

    # Deduplicate
    seen = set()
    unique_urls = []
    for url in all_urls:
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)

    print(f"\n  Total unique sources: {len(unique_urls)}")

    # Push to NotebookLM
    nb_result = {}
    if args.notebooklm and unique_urls:
        title = f"Phoenix Research: {topic} — {datetime.now().strftime('%Y-%m-%d')}"
        nb_result = push_to_notebooklm(unique_urls, title, args.backend, args.prompt, args.notebook_id)

    # Output
    if args.json_output:
        print(json.dumps({
            "topic": topic,
            "youtube": yt_results,
            "web": web_results,
            "total_urls": len(unique_urls),
            "notebooklm": nb_result,
        }, indent=2))
    else:
        format_summary(topic, yt_results, web_results, nb_result)

        # Auth reminder
        if args.notebooklm and not nb_result.get("success"):
            print("⚠️  NotebookLM auth required.")
            print("   Run in a separate terminal:  notebooklm login")
            print("   Then re-run this pipeline.\n")


if __name__ == "__main__":
    main()
