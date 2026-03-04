---
name: content-parser
description: |
  Extract and parse content from URLs. Triggers on: user provides a URL to extract
  content from, another skill needs to parse source material, "parse this URL",
  "extract content", "解析链接", "提取内容".
---

## When to Use

- User provides a URL and wants to extract/read its content
- Another skill needs to parse source material from a URL before generation
- User says "parse this URL", "extract content from this link"
- User says "解析链接", "提取内容"

## When NOT to Use

- User already has text content and doesn't need URL parsing
- User wants to generate audio/video content (not content extraction)
- User wants to read a local file (use standard file reading tools)

## Purpose

Extract and normalize content from URLs across supported platforms. Returns structured data including content body, metadata, and references. Useful as a preprocessing step for content generation skills or standalone content extraction.

## Hard Constraints

- No shell scripts. Construct curl commands from `shared/api-reference.md`
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- URL must be a valid HTTP(S) URL
- **TEMPORARY**: Content extract API is at `https://staging-api.marswave.ai/openapi/v1` (not the production base URL). Use this until the endpoint goes live.

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After collecting URL and language preference, confirm with the user before calling the extraction API.
</HARD-GATE>

## Interaction Flow

### Step 1: URL Input

Free text input. Ask the user:

> What URL would you like to extract content from?

### Step 2: Language (optional)

```
Question: "What language should the extracted content be in?"
Options:
  - "Chinese (zh)" — Extract/process in Chinese
  - "English (en)" — Extract/process in English
  - "Auto-detect" — Let the system decide based on content
```

If user doesn't specify, omit the `language` parameter.

### Step 3: Confirm & Extract

Summarize:

```
Ready to extract content:

  URL: {url}
  Language: {language / auto-detect}

  Proceed?
```

Wait for explicit confirmation before calling the API.

## Workflow

1. **Validate URL**: Must be HTTP(S). Normalize if needed (see `references/supported-platforms.md`)
2. **Submit (foreground)**: `POST /v1/content/extract` with `{url, language}` → extract `taskId`
3. Tell the user extraction is in progress
4. **Poll (background)**: `GET /v1/content/extract/{taskId}` every 5s with `run_in_background: true` and `timeout: 300000`
5. When notified, **present result**:
   ```
   Content extracted!

   Source: {url}
   Length: ~{character count} characters
   ```
6. Show a preview of the extracted content (first ~500 chars)
7. Offer to save full content to file or use it in another skill

**Estimated time**: 5-30 seconds depending on content size and platform.

## API Reference

- Content extract: `shared/api-reference.md` § 5. Content Extract
- Supported platforms: `references/supported-platforms.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Error handling: `shared/common-patterns.md` § Error Handling

## Example

**User**: "Parse this article: https://en.wikipedia.org/wiki/Topology"

**Agent workflow**:
1. URL: `https://en.wikipedia.org/wiki/Topology`
2. Language: auto-detect (omit parameter)
3. Submit extraction

```bash
curl -sS -X POST "https://staging-api.marswave.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://en.wikipedia.org/wiki/Topology"}'
```

4. Poll until complete:

```bash
curl -sS "https://staging-api.marswave.ai/openapi/v1/content/extract/69a7dac700cf95938f86d9bb" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

5. Present extracted content preview and offer next actions.
