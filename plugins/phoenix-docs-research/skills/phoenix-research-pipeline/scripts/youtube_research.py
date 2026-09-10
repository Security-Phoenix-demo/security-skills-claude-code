#!/usr/bin/env python3
"""
Phoenix Security — YouTube Research Script
Scrapes YouTube metadata via yt-dlp: titles, views, author, duration, URLs.
Usage: python3 youtube_research.py "query" [--count 25] [--json] [--min-views 1000]
"""

import sys
import json
import argparse
from datetime import datetime
import yt_dlp


def search_youtube(query: str, count: int = 25, min_views: int = 0) -> list:
    results = []
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": "in_playlist",
        "skip_download": True,
        "ignoreerrors": True,
    }

    search_url = f"ytsearch{count}:{query}"

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            info = ydl.extract_info(search_url, download=False)
        except Exception as e:
            print(f"[ERROR] yt-dlp search failed: {e}", file=sys.stderr)
            return []

    if not info or "entries" not in info:
        return []

    for entry in info.get("entries", []) or []:
        if not entry:
            continue
        view_count = entry.get("view_count") or 0
        if view_count < min_views:
            continue
        duration_sec = entry.get("duration") or 0
        h = duration_sec // 3600
        m = (duration_sec % 3600) // 60
        s = duration_sec % 60
        duration_str = f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
        upload_date = entry.get("upload_date") or ""
        if upload_date and len(upload_date) == 8:
            upload_date = f"{upload_date[:4]}-{upload_date[4:6]}-{upload_date[6:8]}"
        n = view_count
        views_fmt = f"{n/1_000_000:.1f}M" if n >= 1_000_000 else (f"{n/1_000:.1f}K" if n >= 1_000 else str(n))
        results.append({
            "title": entry.get("title") or "N/A",
            "url": f"https://www.youtube.com/watch?v={entry.get('id','')}" if entry.get("id") else entry.get("url",""),
            "channel": entry.get("uploader") or entry.get("channel") or "Unknown",
            "views": view_count,
            "views_formatted": views_fmt,
            "duration": duration_str,
            "upload_date": upload_date,
            "description": (entry.get("description") or "")[:300],
            "video_id": entry.get("id") or "",
            "source": "youtube",
        })

    results.sort(key=lambda x: x["views"], reverse=True)
    return results


def main():
    parser = argparse.ArgumentParser(description="Phoenix Security — YouTube Research")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--count", type=int, default=25)
    parser.add_argument("--min-views", type=int, default=0)
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--urls-only", action="store_true")
    args = parser.parse_args()

    results = search_youtube(args.query, args.count, args.min_views)

    if not results:
        print(f"[WARN] No results for: {args.query}", file=sys.stderr)
        sys.exit(1)

    if args.json_output:
        print(json.dumps(results, indent=2))
    elif args.urls_only:
        for r in results:
            print(r["url"])
    else:
        print(f"\n{'='*80}\n  YouTube Research: {args.query}")
        print(f"  Found: {len(results)} — {datetime.now().strftime('%Y-%m-%d %H:%M')}\n{'='*80}\n")
        for i, r in enumerate(results, 1):
            print(f"[{i:02d}] {r['title']}")
            print(f"     {r['channel']} | {r['views_formatted']} views | {r['duration']} | {r['upload_date']}")
            print(f"     {r['url']}\n")

if __name__ == "__main__":
    main()
