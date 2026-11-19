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
# Optional: use China Standard Time in report dates and filenames
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --timezone Asia/Shanghai
```

Defaults are 48 hours, 15 stories, and Chinese. Follow any requested time window, item count, language, time zone, and output paths. Add `--timezone Asia/Shanghai` when report dates should use China time; otherwise the system time zone is used. The engine requires network access to feeds and a configured model client: Gemini API, OpenAI-compatible API, or authenticated Codex CLI. See `.env.example` and `README.md` for setup.

The RSS catalog is `scripts/source-catalog.ts` and currently contains 151 feeds. Hugging Face Papers is fetched separately on each run; WaytoAGI is optional and is enabled only when `--waytoagi-limit` is greater than zero. Do not claim these sources cover all AI news.

## Verify the result

- Confirm the Markdown report exists at the requested path or under `reports/output/`.
- Confirm the matching health JSON exists under `reports/health/` unless a different path was requested.
- Report actual feed and article counts from the health log or command output. Identify failed feeds when relevant.
- If requested, summarize recent health logs with `scripts/analyze-ai-digest-health.ps1`.
- The engine deduplicates in-window stories by normalized URL and same-day normalized title. Report the number removed when useful.
- Scores and summaries are generated from RSS titles and descriptions; the engine does not fetch full article text. The report labels this limitation. Do not describe an RSS-based summary as a verified summary of the full article.
- If the model omits or duplicates score/summary indexes, the engine retries and then stops rather than silently assigning a neutral score or producing a partial report.
- If a Hugging Face Papers listing date cannot be read, report the source error; do not treat undated papers as current.
- Check source pages for consequential claims when the user requests review or verification.

## Keep the scope to the digest

This skill covers source collection, scoring, summaries, Markdown report generation, and source-health analysis. Stop after the requested digest operation. Do not create article work items, long-form posts, illustrations, covers, SVG layouts, or publication packages as an assumed next step.

If the engine cannot reach the feeds or model service, report the actual error and affected stage. Never claim a report or health analysis exists until you have checked the output file.
