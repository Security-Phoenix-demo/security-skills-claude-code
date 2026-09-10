#!/usr/bin/env python3
"""
Phoenix Security — NotebookLM Push Script
Supports two backends:
  --backend teng     notebooklm-py (async, full API)
  --backend jacob    notebooklm-cli (CLI wrapper, jacob-bd)

Usage:
  python3 notebooklm_push.py --urls urls.txt --title "Research: TOPIC" --backend teng
  python3 notebooklm_push.py --urls urls.txt --title "Research: TOPIC" --backend jacob
  cat urls.txt | python3 notebooklm_push.py --stdin --title "Research: TOPIC"
"""

import sys
import json
import argparse
import asyncio
import subprocess
import os
from datetime import datetime
from typing import Optional


# ─── Phoenix Brand Prompts ────────────────────────────────────────────────────

PHOENIX_BLOG_PROMPT = """You are generating structured technical research for a cybersecurity presentation under the Phoenix Security brand.

Your output must be analytical, precise, and designed for security engineers, AppSec teams, DevSecOps practitioners, and CISOs. Avoid sensational language. Focus on root cause analysis, system behavior, and engineering impact.

Structure:
1. Research Context — what the technology/vulnerability is, where it appears, why it matters
2. Problem Definition — system behavior creating risk, failing design assumptions, security boundaries
3. Technical Explanation — mechanics step by step, trust boundaries, data flow, failure conditions
4. Impact Analysis — security consequences, attack surface, realistic attacker capabilities
5. Remediation — code-level mitigation, configuration controls, architectural improvements
6. Conclusion — lesson for system design, how engineers prevent similar issues
7. References — CVEs, papers, vendor advisories, GitHub

Tone: analytical, professional. Avoid hype. Write for engineers who want to understand root cause."""

PHOENIX_SLIDE_PROMPT = """Create a structured technical slide deck for security engineers, DevSecOps teams, and CISOs.
Focus on root cause analysis and system behavior rather than marketing.

Slide structure:
1. Title — topic + technical focus subtitle
2. Context — where this exists in modern systems, architecture
3. The Problem — system assumptions, boundary failure, why it exists
4. System Architecture — components, trust boundaries, data flow
5. Technical Mechanics — step-by-step system behavior, processing flow
6. Failure Boundary — exactly where failure occurs
7. Exploit Conditions — conditions required for exploitation
8. Impact — realistic impact, attack surface, affected deployments
9. Remediation — code fixes, architecture controls, defensive practices
10. Key Lessons — what engineers should learn
11. References — sources used

Design: dark background #1E2535, gradient Deep Purple #6714CC → Indigo #380886 → Azure #245EE9.
Accent Red Orange #F03E1E → Mahogany #C6361F for exploit highlights only.
Phoenix Security logo bottom-right. Minimal typography. Engineering clarity over marketing."""

PHOENIX_VIDEO_PROMPT = """Generate a technical explainer video script for security engineers and DevSecOps practitioners.
Tone: analytical, calm, technical. Avoid dramatic or breach-alert language.

Structure:
Opening (10-15s): introduce topic, why it matters to engineers, system behavior focus
Context: where technology/system is used, architecture involved
Problem: technical problem, design assumption or boundary failure
Deep Technical Breakdown: step-by-step — internal processing, data flow, system assumptions, failure condition
Impact: realistic consequences, operational security impact
Engineering Mitigation: prevention/fix, design improvements, defensive coding
Closing: key engineering lesson, importance of root cause over symptoms

Visual: minimal animations, system behavior diagrams.
Phoenix Security logo bottom-right. Gradient: Deep Purple → Indigo → Azure.
Accent Red Orange → Mahogany for exploit highlights."""


# ─── Backend: teng-lin/notebooklm-py ─────────────────────────────────────────

async def push_teng(urls: list, title: str, prompt_type: str, notebook_id: Optional[str] = None) -> dict:
    """Push URLs to NotebookLM using notebooklm-py async API."""
    try:
        from notebooklm import NotebookLMClient
    except ImportError:
        return {"success": False, "error": "notebooklm-py not installed. Run: pip install notebooklm-py"}

    async with NotebookLMClient.from_storage() as client:
        # Create or use existing notebook
        if notebook_id:
            nb_id = notebook_id
            print(f"[INFO] Using existing notebook: {nb_id}")
        else:
            nb = await client.notebooks.create(title=title)
            nb_id = nb.id
            print(f"[INFO] Created notebook: '{title}' (ID: {nb_id})")

        # Add URLs as sources
        added = []
        failed = []
        for url in urls:
            try:
                await client.sources.add_url(nb_id, url)
                added.append(url)
                print(f"  [+] {url}")
            except Exception as e:
                failed.append({"url": url, "error": str(e)})
                print(f"  [!] Failed: {url} — {e}", file=sys.stderr)

        # Request analysis with Phoenix prompt
        prompt = _get_prompt(prompt_type)
        result_text = ""
        if prompt and added:
            try:
                print(f"\n[INFO] Requesting analysis ({prompt_type})...")
                result = await client.chat.ask(nb_id, prompt)
                result_text = result.answer if hasattr(result, "answer") else str(result)
                print(f"[INFO] Analysis complete ({len(result_text)} chars)")
            except Exception as e:
                print(f"[WARN] Analysis request failed: {e}", file=sys.stderr)

        nb_url = f"https://notebooklm.google.com/notebook/{nb_id}"
        return {
            "success": True,
            "backend": "teng-lin/notebooklm-py",
            "notebook_id": nb_id,
            "notebook_url": nb_url,
            "sources_added": len(added),
            "sources_failed": len(failed),
            "analysis_preview": result_text[:500] if result_text else "",
        }


# ─── Backend: jacob-bd/notebooklm-cli ────────────────────────────────────────

def push_jacob(urls: list, title: str, prompt_type: str, notebook_id: Optional[str] = None) -> dict:
    """Push URLs to NotebookLM using notebooklm-cli (jacob-bd)."""
    cli = "/usr/local/bin/notebooklm"
    if not os.path.exists(cli):
        return {"success": False, "error": f"notebooklm CLI not found at {cli}"}

    # Create notebook
    nb_id = notebook_id
    if not nb_id:
        try:
            result = subprocess.run([cli, "create", title], capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                return {"success": False, "error": f"Create failed: {result.stderr}"}
            # Parse notebook ID from output
            for line in result.stdout.split("\n"):
                if "id" in line.lower() or "notebook" in line.lower():
                    import re
                    match = re.search(r"[a-f0-9\-]{8,}", line)
                    if match:
                        nb_id = match.group()
                        break
            print(f"[INFO] Created notebook: '{title}' (ID: {nb_id or 'unknown'})")
        except Exception as e:
            return {"success": False, "error": str(e)}

    # Select notebook if we have an ID
    if nb_id:
        subprocess.run([cli, "use", nb_id], capture_output=True, timeout=15)

    # Add sources
    added = 0
    failed = []
    for url in urls:
        try:
            result = subprocess.run([cli, "add", url], capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                added += 1
                print(f"  [+] {url}")
            else:
                failed.append({"url": url, "error": result.stderr.strip()})
                print(f"  [!] {url}: {result.stderr.strip()}", file=sys.stderr)
        except subprocess.TimeoutExpired:
            failed.append({"url": url, "error": "timeout"})

    # Request analysis
    prompt = _get_prompt(prompt_type)
    analysis = ""
    if prompt and added > 0:
        try:
            print(f"\n[INFO] Requesting analysis ({prompt_type})...")
            result = subprocess.run([cli, "ask", prompt[:500]], capture_output=True, text=True, timeout=60)
            analysis = result.stdout.strip()
            print(f"[INFO] Analysis preview: {analysis[:200]}")
        except Exception as e:
            print(f"[WARN] Analysis failed: {e}", file=sys.stderr)

    return {
        "success": True,
        "backend": "jacob-bd/notebooklm-cli",
        "notebook_id": nb_id or "unknown",
        "notebook_url": f"https://notebooklm.google.com",
        "sources_added": added,
        "sources_failed": len(failed),
        "analysis_preview": analysis[:500],
    }


def _get_prompt(prompt_type: str) -> str:
    prompts = {
        "blog": PHOENIX_BLOG_PROMPT,
        "slides": PHOENIX_SLIDE_PROMPT,
        "video": PHOENIX_VIDEO_PROMPT,
    }
    return prompts.get(prompt_type, PHOENIX_BLOG_PROMPT)


def main():
    parser = argparse.ArgumentParser(description="Phoenix Security — NotebookLM Push")
    parser.add_argument("--urls", help="File with URLs (one per line)")
    parser.add_argument("--stdin", action="store_true", help="Read URLs from stdin")
    parser.add_argument("--title", default=f"Phoenix Research {datetime.now().strftime('%Y-%m-%d')}")
    parser.add_argument("--backend", choices=["teng", "jacob"], default="teng",
                        help="notebooklm-py (teng) or notebooklm-cli (jacob)")
    parser.add_argument("--notebook-id", help="Existing notebook ID to add to")
    parser.add_argument("--prompt", choices=["blog", "slides", "video"], default="blog",
                        help="Which Phoenix analysis prompt to use")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args()

    # Collect URLs
    urls = []
    if args.stdin:
        urls = [line.strip() for line in sys.stdin if line.strip().startswith("http")]
    elif args.urls:
        with open(args.urls) as f:
            urls = [line.strip() for line in f if line.strip().startswith("http")]

    if not urls:
        print("[ERROR] No URLs provided", file=sys.stderr)
        sys.exit(1)

    print(f"\n[Phoenix Security] Pushing {len(urls)} sources to NotebookLM")
    print(f"  Backend: {args.backend}  |  Prompt: {args.prompt}  |  Title: {args.title}\n")

    if args.backend == "teng":
        result = asyncio.run(push_teng(urls, args.title, args.prompt, args.notebook_id))
    else:
        result = push_jacob(urls, args.title, args.prompt, args.notebook_id)

    if args.json_output:
        print(json.dumps(result, indent=2))
    else:
        print(f"\n{'='*60}")
        print(f"  Status: {'✓ OK' if result['success'] else '✗ FAILED'}")
        if result.get("error"):
            print(f"  Error: {result['error']}")
        else:
            print(f"  Notebook: {result.get('notebook_url','')}")
            print(f"  Sources added: {result.get('sources_added',0)} / {len(urls)}")
            if result.get("analysis_preview"):
                print(f"\n  Analysis preview:\n  {result['analysis_preview'][:300]}")
        print(f"{'='*60}\n")

    sys.exit(0 if result.get("success") else 1)


if __name__ == "__main__":
    main()
