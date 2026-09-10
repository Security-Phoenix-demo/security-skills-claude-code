# Global Research NotebookLM Pipeline

An end-to-end research automation pipeline that combines web research, YouTube transcript extraction, and NotebookLM integration for comprehensive intelligence gathering.

![Research, Verify, Detect: Structured Threat Intelligence for Claude Code](../../images/cti-skills.jpg)

## What It Does

This skill automates the full research workflow: from conducting web searches and extracting YouTube video transcripts to pushing all collected sources into Google NotebookLM for AI-assisted analysis. It is designed for security researchers, analysts, and anyone who needs to rapidly collect, organize, and synthesize information from multiple source types.

The pipeline orchestrates multiple research stages. Web research scripts perform structured searches across relevant domains and extract key findings. YouTube research scripts locate and transcribe relevant video content. The pipeline orchestrator coordinates these stages, deduplicates results, and formats them for ingestion. Finally, the NotebookLM source-pushing component adds all collected URLs and content to a target notebook, enabling NotebookLM's summarization and Q&A capabilities over the full research corpus.

The skill also includes brand reference files and prompt templates to ensure consistent research quality and output formatting across sessions.

## Files

| File | Purpose |
|------|---------|
| `research-pipeline.skill` | Packaged skill bundle (ZIP archive) containing the full pipeline with web research, YouTube research, pipeline orchestration, NotebookLM source pushing, cookie auth, install script, and reference files |

## Installation

```bash
# Unzip the skill bundle to inspect contents
unzip research-pipeline.skill -d research-pipeline/

# Run the included install script
bash research-pipeline/install.sh
```

## Usage

Invoke the research pipeline with a topic:

```
Research [topic] and push findings to NotebookLM
```

The pipeline will:
1. Conduct web research across relevant sources
2. Find and transcribe relevant YouTube content
3. Deduplicate and organize all findings
4. Push collected sources to your NotebookLM notebook

## Requirements

- Claude Code with WebSearch, WebFetch, and Bash tools enabled
- A web search API key (Brave Search, SerpAPI, or Google CSE)
- Google NotebookLM account with a target notebook ID
- Optional: YouTube transcript extraction dependencies
- NotebookLM cookie authentication configured (see install script)
