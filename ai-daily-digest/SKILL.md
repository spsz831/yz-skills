---
name: ai-daily-digest
description: Research and write a timely AI industry news digest from current, verifiable sources. Use for AI news roundups, daily or weekly AI briefings, and digest editing; do not assume a particular private repository, personal brand, or publishing workflow.
---

# AI Daily Digest

Create or revise a concise, useful digest of recent AI and technology developments. Work from current sources or materials supplied by the user. Keep the scope and time window the user requests; if omitted, treat “today's AI digest” as the most recent 24 hours in the user's local timezone.

## Gather and verify

- Use available web search and page-reading tools for current news. If browsing is unavailable, ask for source material or state that current facts cannot be verified; do not fill gaps from memory.
- Prefer primary sources for announcements, releases, papers, policy, and company statements. Use reliable reporting to add context or independently verify consequential claims.
- Check both the publication date and when the event occurred. Exclude stale stories unless a new development makes them relevant to the requested window.
- Open the source pages before writing. Confirm names, dates, numbers, product availability, and quoted claims. Link directly to sources and distinguish confirmed facts from analysis.
- Deduplicate stories that different outlets describe as separate updates. Keep a balanced mix of meaningful developments; do not force categories or keywords when the news does not support them.

## Select and write

Prioritize developments by significance, novelty, evidence quality, and practical or industry impact. Omit routine funding or product updates when they add little beyond promotion. Explain why each selected item matters without exaggerating its implications.

Unless the user requests another format, produce Markdown with:

1. A dated title and the covered time window.
2. A short overview of the most important shifts.
3. Numbered stories, each with a clear headline, concise factual summary, a brief “why it matters” note, and direct source links.
4. A short closing synthesis only when the stories support one.

Keep language direct and readable. Preserve useful technical detail, define unfamiliar terms briefly, and label analysis as analysis. Do not invent a trend, consensus, date, quote, source, or causal link to make the digest feel complete.

## Adapt to the request

- For a requested interval, region, topic, audience, item count, or output path, follow it.
- For a provided draft, spreadsheet, or source list, improve its accuracy, selection, organization, and readability; identify claims that still need verification.
- If the user asks for only headlines, a brief, or an editorial plan, return that deliverable without expanding it into an article.
- Do not add a personal byline, account identity, fixed call to action, WeChat formatting, cover design, illustrations, or a separate article-production pipeline unless asked.
- Do not assume access to any local repository or run repository-specific scripts. Use project-specific instructions only when the user explicitly supplies that project as the task context.

## Final check

Before returning the digest, confirm that every current-events claim has a source, dates match the requested window, duplicate stories are removed, links are direct, and the summary does not claim more than its sources support. If a key detail remains uncertain, say so beside that item.
