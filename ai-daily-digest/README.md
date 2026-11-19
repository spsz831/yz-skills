# AI Daily Digest Skill

A standalone, reusable agent skill for researching and writing concise digests of recent AI and technology news.

This folder contains the Skill instructions only. It is not an application repository and does not include a bundled news crawler, account-specific feeds, local report archive, or publishing pipeline.

## What it does

- Researches recent developments from current, verifiable sources.
- Checks event dates, publication dates, key figures, and direct source links.
- Selects significant stories, removes duplicates, and explains why each item matters.
- Produces or edits a Markdown digest for the time range and audience requested.

## Use it when

- You need a daily or weekly AI news roundup.
- You want to turn a source list or research notes into a digest.
- You need to review an existing digest for freshness, sourcing, selection, and clarity.

The default for an unspecified “today's AI digest” is the latest 24 hours in the user's local timezone. The user can choose another window, topic, region, audience, length, or format.

## Files

```text
ai-daily-digest/
├── SKILL.md   # Agent instructions and source-verification workflow
├── README.md  # This overview
└── LICENSE    # MIT License
```

The Skill uses web research capabilities available in the agent environment. It does not hard-code a news-source list or model provider. If current browsing is unavailable, it asks for source material rather than presenting stale information as current.

## Scope

This Skill provides a reusable research and writing method for AI news digests. It does not bundle an application, crawler, or fixed source catalog.

## Install

Install this folder in the skills directory supported by your agent, keeping the folder name `ai-daily-digest`. The Skill is available for automatic selection when a request matches its description, or can be invoked explicitly by name.

See [`SKILL.md`](SKILL.md) for the operating instructions.
