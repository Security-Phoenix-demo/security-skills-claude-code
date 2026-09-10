#!/usr/bin/env python3
"""
Phoenix Security Research Pipeline — Orchestrator
Single command: research topic → rank sources → push to NotebookLM → generate artifacts.

Usage:
  python3 pipeline.py "ASPM container escape CVEs 2025"
  python3 pipeline.py "LLM prompt injection" --youtube 25 --web 25 --artifacts infographic slides
  python3 pipeline.py  # Interactive mode (asks for topic)
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent


def run_youtube_research(query: str, count: int) -> list[str]:
    """Run YouTube research and return list of URLs."""
    print(f"\n[🎬 YouTube] Searching for {count} videos on: '{query}'", flush=True)
    result = subprocess.run(
        [sys.executable, str(SCRIPT_DIR / "youtube_research.py"), query,
         "--count", str(count), "--urls-only"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  [WARN] YouTube research error: {result.stderr[:200]}", file=sys.stderr)
        return []

    urls = [line.strip() for line in result.stdout.splitlines()
            if line.strip().startswith("http")]
    print(f"  ✓ Found {len(urls)} videos")
    return urls


def run_web_research(query: str, count: int, reddit: bool = True,
                     brave_key: str = None) -> list[str]:
    """Run web research and return list of URLs."""
    print(f"\n[🌐 Web] Searching for {count} articles on: '{query}'", flush=True)
    env = os.environ.copy()
    if brave_key:
        env["BRAVE_API_KEY"] = brave_key

    cmd = [sys.executable, str(SCRIPT_DIR / "web_research.py"), query,
           "--count", str(count), "--urls-only", "--min-score", "45"]
    if reddit:
        cmd.append("--reddit")

    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        print(f"  [WARN] Web research error: {result.stderr[:200]}", file=sys.stderr)
        return []

    urls = [line.strip() for line in result.stdout.splitlines()
            if line.strip().startswith("http")]
    print(f"  ✓ Found {len(urls)} web sources")
    return urls


def push_to_notebooklm(urls: list[str], topic: str, artifacts: list[str],
                        notebook_id: str = None, notebook_title: str = None,
                        backend: str = "nlm", video_style: str = "whiteboard") -> dict:
    """Push sources to NotebookLM and trigger artifact generation."""
    print(f"\n[📓 NotebookLM] Pushing {len(urls)} sources...", flush=True)

    # Write URLs to temp file
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write("\n".join(urls))
        tmp_path = f.name

    try:
        cmd = [
            sys.executable, str(SCRIPT_DIR / "notebooklm_push.py"),
            "--urls", tmp_path,
            "--topic", topic,
            "--backend", backend,
            "--json-output",
        ]
        if notebook_id:
            cmd += ["--notebook-id", notebook_id]
        if notebook_title:
            cmd += ["--notebook-title", notebook_title]
        if artifacts:
            cmd += ["--artifacts"] + artifacts
        if video_style:
            cmd += ["--video-style", video_style]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)

        try:
            return json.loads(result.stdout)
        except Exception:
            return {
                "error": result.stderr[:300] if result.returncode != 0 else "parse error",
                "stdout": result.stdout[:300],
            }
    finally:
        os.unlink(tmp_path)


def print_banner():
    print("""
╔══════════════════════════════════════════════════════════╗
║     Phoenix Security — Automated Research Pipeline       ║
║     Web + YouTube → NotebookLM → Artifacts               ║
╚══════════════════════════════════════════════════════════╝""")


def print_summary(topic: str, all_urls: list[str], push_results: dict,
                  artifacts: list[str], elapsed: float):
    notebook_id = push_results.get("notebook_id", "N/A")
    sources_added = push_results.get("sources_added", "?")
    artifact_results = push_results.get("artifacts", {})

    print(f"""
{'='*62}
  Research Pipeline Complete
{'='*62}
  Topic       : {topic}
  Sources     : {sources_added}/{len(all_urls)} added to NotebookLM
  Notebook ID : {notebook_id}
  Time        : {elapsed:.1f}s
{'='*62}""")

    if artifact_results:
        print("  Artifacts   :")
        for a, status in artifact_results.items():
            icon = "✓" if "queue" in str(status) else "✗"
            print(f"    {icon} {a}: {status}")

    print(f"""
  Open NotebookLM:
    https://notebooklm.google.com/

  Notebook ID for future runs:
    {notebook_id}
{'='*62}
""")


def main():
    parser = argparse.ArgumentParser(
        description="Phoenix Security Research Pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full pipeline: 25 YouTube + 25 web, generate all artifacts
  python3 pipeline.py "container escape CVEs 2025" --artifacts all

  # YouTube only, infographic + slides
  python3 pipeline.py "ASPM tools comparison" --youtube 25 --web 0 --artifacts infographic slides

  # Web only with Brave API, push to existing notebook
  BRAVE_API_KEY=xxx python3 pipeline.py "LLM security" --youtube 0 --web 25 \\
    --notebook-id <id> --artifacts report

  # Interactive mode
  python3 pipeline.py
        """
    )
    parser.add_argument("topic", nargs="?", help="Research topic")
    parser.add_argument("--youtube", "-y", type=int, default=25,
                        help="Number of YouTube videos (default: 25, 0=skip)")
    parser.add_argument("--web", "-w", type=int, default=25,
                        help="Number of web/Reddit articles (default: 25, 0=skip)")
    parser.add_argument("--no-reddit", action="store_true", help="Skip Reddit results")
    parser.add_argument("--artifacts", nargs="+", default=[],
                        choices=["infographic", "slides", "report", "audio",
                                 "video", "flashcards", "mindmap", "all"],
                        help="Artifacts to generate")
    parser.add_argument("--video-style", default="whiteboard",
                        choices=["auto_select", "classic", "whiteboard", "kawaii",
                                 "anime", "watercolor", "retro_print", "heritage", "paper_craft"],
                        help="Video style (default: whiteboard)")
    parser.add_argument("--notebook-id", help="Existing NotebookLM notebook ID")
    parser.add_argument("--backend", choices=["nlm", "py"], default="nlm",
                        help="NotebookLM backend (default: nlm)")
    parser.add_argument("--brave-key", help="Brave Search API key (or set BRAVE_API_KEY env var)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Research only, print URLs without pushing to NotebookLM")
    args = parser.parse_args()

    print_banner()

    # Get topic
    topic = args.topic
    if not topic:
        topic = input("\nWhat topic do you want to research? ").strip()
        if not topic:
            print("ERROR: No topic provided.", file=sys.stderr)
            sys.exit(1)

    brave_key = args.brave_key or os.environ.get("BRAVE_API_KEY", "")
    start = datetime.now()

    # Research phase
    all_urls = []

    if args.youtube > 0:
        yt_urls = run_youtube_research(topic, args.youtube)
        all_urls.extend(yt_urls)

    if args.web > 0:
        web_urls = run_web_research(
            topic, args.web,
            reddit=not args.no_reddit,
            brave_key=brave_key
        )
        all_urls.extend(web_urls)

    # Deduplicate
    seen = set()
    unique_urls = []
    for url in all_urls:
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)

    print(f"\n[Summary] Total unique sources: {len(unique_urls)}")

    if not unique_urls:
        print("No sources found. Check your query and network.", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print("\n[DRY RUN] URLs that would be pushed:")
        for url in unique_urls:
            print(f"  {url}")
        sys.exit(0)

    # NotebookLM phase
    artifacts = args.artifacts
    if "all" in artifacts:
        artifacts = ["report", "infographic", "slides", "audio", "video", "flashcards", "mindmap"]

    notebook_title = f"Phoenix Research — {topic} — {datetime.now().strftime('%Y-%m-%d')}"

    push_results = push_to_notebooklm(
        unique_urls,
        topic=topic,
        artifacts=artifacts,
        notebook_id=args.notebook_id,
        notebook_title=notebook_title,
        backend=args.backend,
        video_style=args.video_style,
    )

    elapsed = (datetime.now() - start).total_seconds()
    print_summary(topic, unique_urls, push_results, artifacts, elapsed)

    # Save notebook ID for reuse
    if push_results.get("notebook_id"):
        config_file = Path.home() / ".phoenix_research_last_notebook"
        config_file.write_text(push_results["notebook_id"])


if __name__ == "__main__":
    main()
