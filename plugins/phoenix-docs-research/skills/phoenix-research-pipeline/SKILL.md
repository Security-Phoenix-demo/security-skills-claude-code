---
name: phoenix-research-pipeline
description: >
  Automated research pipeline for Phoenix Security: searches YouTube (yt-dlp), web
  (Brave API + Scrapling fallback), and Reddit for trending content on any security topic,
  then pushes curated results into Google NotebookLM with Phoenix-branded analysis prompts
  (blog, slide deck, video script). Use this skill whenever the user says "research [topic]",
  "find trending videos on [X]", "push to NotebookLM", "yt-research", "run the pipeline",
  "find YouTube videos and send to NotebookLM", "research pipeline", or any combination of
  topic research + content curation. Also trigger for single-source commands like
  "find 25 YouTube videos on container security" or "search web for CISA KEV articles".
  If no topic is given, ask the user what topic to research before proceeding.
---

# Phoenix Security Research Pipeline

Automated research → quality filtering → NotebookLM ingestion with Phoenix brand prompts.

## Quick Start

```bash
# Interactive (prompts for topic)
python3 scripts/research_pipeline.py

# Full pipeline: YouTube + web + NotebookLM
python3 scripts/research_pipeline.py "CISA KEV exploited vulnerabilities 2025" \
  --count 25 --notebooklm --prompt blog

# YouTube only
python3 scripts/youtube_research.py "container security kubernetes" --count 25

# Web only (Brave primary, Scrapling fallback)  
python3 scripts/web_research.py "ASPM application security posture" --count 20 --reddit

# Push URLs directly to NotebookLM
python3 scripts/notebooklm_push.py --urls urls.txt --title "My Research" \
  --backend teng --prompt slides
```

## CRITICAL: Authentication Required

NotebookLM requires Google auth. **Before first use**, tell the user:

> "Open a separate terminal and run: `notebooklm login`
> This will open a browser for Google authentication. Come back when it completes."

This must happen before any `--notebooklm` flag will work.

---

## Workflow

```
User gives topic (or Claude asks)
     ↓
[1] YouTube Research (yt-dlp) — metadata: title, views, channel, duration, URL
[2] Web Research (Brave → Scrapling fallback) — title, URL, description, quality score
[3] Reddit Research (optional flag) — top posts from security subreddits  
     ↓
Quality Filter (min score 5/10 default, configurable)
Deduplication
     ↓
[4] NotebookLM Push — all URLs → new notebook → Phoenix prompt → analysis
     ↓
Summary: sources ingested, notebook URL, analysis preview
```

---

## Claude Behaviour

When a user gives a research command:

1. **Extract topic** — if none given, ask: "What topic do you want to research?"
2. **Run pipeline** using `bash_tool`:
   ```bash
   cd /path/to/skill && python3 scripts/research_pipeline.py "TOPIC" \
     --count 25 --notebooklm --prompt blog
   ```
3. **Check auth** — if NotebookLM fails with auth error, show login instruction
4. **Report results** — paste the summary output; include notebook URL
5. **Offer next steps** — "Want slides or a video script version? Re-run with `--prompt slides`"

---

## YouTube Research (`youtube_research.py`)

Uses yt-dlp. No API key required.

```bash
python3 scripts/youtube_research.py "QUERY" [OPTIONS]

Options:
  --count N        Number of results (default 25)
  --min-views N    Filter by minimum view count
  --json           JSON output
  --urls-only      URLs only (for piping to NotebookLM)
```

Output fields: title, url, channel, views, duration, upload_date, video_id

---

## Web Research (`web_research.py`)

Primary: Brave Search API (set `BRAVE_API_KEY` env var)
Fallback: Scrapling + DuckDuckGo (no key needed)

```bash
python3 scripts/web_research.py "QUERY" [OPTIONS]

Options:
  --count N        Results (default 20)
  --reddit         Include Reddit results (requires PRAW or uses RSS fallback)
  --min-quality N  Quality score filter 0-10 (default 0)
  --json           JSON output
  --urls-only      URLs only
  --brave-key KEY  Brave API key (or BRAVE_API_KEY env)
```

Quality scoring:
- Source authority (arxiv=10, CISA=10, NVD=10, portswigger=9, bleepingcomputer=7)
- Technical keyword density (CVE, RCE, SSRF, ASPM, DevSecOps, etc.)

---

## NotebookLM Push (`notebooklm_push.py`)

Two backends available:

| Backend | Flag | Package | Auth |
|---------|------|---------|------|
| teng-lin/notebooklm-py | `--backend teng` | `notebooklm-py` | `notebooklm login` |
| jacob-bd/notebooklm-cli | `--backend jacob` | `notebooklm-cli` | `notebooklm login` |

```bash
python3 scripts/notebooklm_push.py \
  --urls urls.txt \
  --title "Research: Container Security 2025" \
  --backend teng \
  --prompt blog \
  --notebook-id EXISTING_ID   # optional, creates new if omitted
```

Prompts (`--prompt`):
- `blog` — structured technical research, 7-section format, engineering focus
- `slides` — 11-slide deck, Phoenix dark theme, system anatomy framing  
- `video` — technical explainer script, 5-8 min, analytical tone

---

## Main Pipeline (`research_pipeline.py`)

```bash
python3 scripts/research_pipeline.py "TOPIC" [OPTIONS]

Options:
  --count N        Results per source (default 25)
  --no-youtube     Skip YouTube
  --no-web         Skip web search
  --reddit         Include Reddit
  --notebooklm     Push to NotebookLM
  --backend        teng|jacob (default: teng)
  --prompt         blog|slides|video (default: blog)
  --notebook-id    Existing notebook ID
  --min-quality N  Web quality floor (default 5)
  --json           JSON output
```

---

## Environment Variables

Written automatically to `.env` in skill root by `install.sh`. Source it or let scripts auto-load it:

```bash
export BRAVE_API_KEY="your_key"           # Brave Search API
export REDDIT_CLIENT_ID="..."             # Optional Reddit
export REDDIT_CLIENT_SECRET="..."
export NOTEBOOKLM_NOTEBOOK_ID="..."       # Default notebook (optional)
```

To bake the Brave key into the installer for your team: open `scripts/install.sh` and set `DEFAULT_BRAVE_KEY` to your actual key. It becomes the pre-filled default for all installs.

Brave key: https://api.search.brave.com/ (free tier: 2000 req/month)

---

## Installation

```bash
bash scripts/install.sh
```

Installs: yt-dlp, scrapling, notebooklm-py, notebooklm-cli, praw, requests, curl-cffi, browserforge

During install, the script prompts for the Brave API key with a pre-filled default. Three ways to supply it:

| Method | How |
|--------|-----|
| Interactive (default) | Script prompts; hit Enter to accept pre-filled key |
| Env var pre-set | `BRAVE_API_KEY=mykey bash scripts/install.sh` |
| Post-install edit | Edit `.env` in the skill root directory |

The install writes `.env` directly — no manual copy from template needed. If the Brave key remains as placeholder, the pipeline falls back to Scrapling/DuckDuckGo automatically.

---

## Reference Files

- `references/prompts.md` — Full Phoenix brand prompt text for all three formats
- `scripts/youtube_research.py` — yt-dlp YouTube scraper
- `scripts/web_research.py` — Brave + Scrapling web search
- `scripts/notebooklm_push.py` — NotebookLM push (teng + jacob backends)
- `scripts/research_pipeline.py` — Orchestrator
- `scripts/install.sh` — One-shot installer
- `.env.template` — Environment variable template

---

## Example Commands Claude Should Handle

| User says | Claude does |
|-----------|-------------|
| "Research container security" | Run pipeline with default settings, ask about NotebookLM |
| "Find 25 trending YouTube videos on CISA KEV" | `youtube_research.py "CISA KEV" --count 25` |
| "Research [topic] and send to NotebookLM" | Full pipeline with `--notebooklm` |
| "Make slides from this research" | Re-run with `--prompt slides` |
| "Use the jacob backend" | Add `--backend jacob` |
| "Research [topic]" (no topic given) | Ask "What topic?" before running |

---

## Error Reference

| Error | Fix |
|-------|-----|
| `NotAuthenticatedError` | Run `notebooklm login` in separate terminal |
| `BRAVE_API_KEY not set` | Scrapling fallback auto-activates; set key for better results |
| `No module named curl_cffi` | Run `pip install curl-cffi --break-system-packages` |
| yt-dlp returns 0 results | YouTube may rate-limit; retry after 30s or reduce `--count` |
