---
name: ai-daily-digest
description: Run, configure, or troubleshoot the bundled AI news digest engine. It collects from the included RSS catalog, scores and summarizes recent items, and writes a Markdown report with source-health data. Use for AI daily or weekly digest generation, not for long-form article publishing.
---

# AI Daily Digest

Use the bundled digest engine and source catalog to produce or troubleshoot AI news reports. The skill directory is self-contained; do not assume a separate private repository or a fixed local workspace path.

## Generate a report

Run commands from this skill's directory so the engine can read its local `.env` and use relative output paths:

```powershell
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh
```

Defaults are 48 hours, 15 stories, and Chinese. Follow any requested time window, item count, language, and output paths. The engine requires network access to feeds and a configured model client: Gemini API, OpenAI-compatible API, or authenticated Codex CLI. See `.env.example` and `README.md` for setup.

The RSS catalog is the `RSS_FEEDS` array in `scripts/digest.ts`. It currently contains 151 feeds. Hugging Face Papers is fetched separately on each run; WaytoAGI is optional and is enabled only when `--waytoagi-limit` is greater than zero. Do not claim these sources cover all AI news.

## Verify the result

- Confirm the Markdown report exists at the requested path or under `reports/output/`.
- Confirm the matching health JSON exists under `reports/health/` unless a different path was requested.
- Report actual feed and article counts from the health log or command output. Identify failed feeds when relevant.
- If requested, summarize recent health logs with `scripts/analyze-ai-digest-health.ps1`.
- Distinguish feed collection from editorial verification: scores and summaries are machine-generated; check source pages for consequential claims when the user requests review or verification.

## Keep the scope to the digest

This skill covers source collection, scoring, summaries, Markdown report generation, and source-health analysis. Stop after the requested digest operation. Do not create article work items, long-form posts, illustrations, covers, SVG layouts, or publication packages as an assumed next step.

If the engine cannot reach the feeds or model service, report the actual error and affected stage. Never claim a report or health analysis exists until you have checked the output file.
