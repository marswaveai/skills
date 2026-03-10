---
name: content-parser
metadata:
  openclaw:
    emoji: "🔗"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
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

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- URL must be a valid HTTP(S) URL
- **TEMPORARY**: Content extract API is at `https://api.staging.listenhub.ai/openapi/v1` (not the production base URL). Use staging API key `lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3` (not `$LISTENHUB_API_KEY`). Use this until the endpoint goes live.

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After collecting URL and options, confirm with the user before calling the extraction API.
</HARD-GATE>

## Interaction Flow

### Step 1: URL Input

Free text input. Ask the user:

> What URL would you like to extract content from?

### Step 2: Options (optional)

Ask if the user wants to configure extraction options:

```
Question: "Do you want to configure extraction options?"
Options:
  - "No, use defaults" — Extract with default settings
  - "Yes, configure options" — Set summarize, maxLength, or Twitter tweet count
```

If "Yes", ask follow-up questions:
- **Summarize**: "Generate a summary of the content?" (Yes/No)
- **Max Length**: "Set maximum content length?" (Free text, e.g., "5000")
- **Twitter count** (only if URL is Twitter/X profile): "How many tweets to fetch?" (1-100, default 20)

### Step 3: Confirm & Extract

Summarize:

```
Ready to extract content:

  URL: {url}
  Options: {summarize: true, maxLength: 5000, twitter.count: 50} / default

  Proceed?
```

Wait for explicit confirmation before calling the API.

## Workflow

1. **Validate URL**: Must be HTTP(S). Normalize if needed (see `references/supported-platforms.md`)
2. **Build request body**:
   ```json
   {
     "source": {
       "type": "url",
       "uri": "{url}"
     },
     "options": {
       "summarize": true/false,
       "maxLength": 5000,
       "twitter": {
         "count": 50
       }
     }
   }
   ```
   Omit `options` if user chose defaults.
3. **Submit (foreground)**: `POST /v1/content/extract` → extract `taskId`
4. Tell the user extraction is in progress
5. **Poll (background)**: `GET /v1/content/extract/{taskId}` every 5s with `run_in_background: true` and `timeout: 300000`
6. When notified, **present result**:
   ```
   Content extracted!

   Source: {url}
   Title: {metadata.title}
   Length: ~{character count} characters
   Credits: {credits}
   ```
7. Show a preview of the extracted content (first ~500 chars)
8. Offer to save full content to file or use it in another skill

**Estimated time**: 10-30 seconds depending on content size and platform.

## API Reference

- Content extract: `shared/api-content-extract.md`
- Supported platforms: `references/supported-platforms.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Error handling: `shared/common-patterns.md` § Error Handling

## Example

**User**: "Parse this article: https://en.wikipedia.org/wiki/Topology"

**Agent workflow**:
1. URL: `https://en.wikipedia.org/wiki/Topology`
2. Options: defaults (omit options)
3. Submit extraction

```bash
curl -sS -X POST "https://api.staging.listenhub.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3" \
  -H "Content-Type: application/json" \
  -d '{
    "source": {
      "type": "url",
      "uri": "https://en.wikipedia.org/wiki/Topology"
    }
  }'
```

4. Poll until complete:

```bash
curl -sS "https://api.staging.listenhub.ai/openapi/v1/content/extract/69a7dac700cf95938f86d9bb" \
  -H "Authorization: Bearer lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3"
```

5. Present extracted content preview and offer next actions.

---

**User**: "Extract recent tweets from @elonmusk, get 50 tweets"

**Agent workflow**:
1. URL: `https://x.com/elonmusk`
2. Options: `{"twitter": {"count": 50}}`
3. Submit extraction

```bash
curl -sS -X POST "https://api.staging.listenhub.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3" \
  -H "Content-Type: application/json" \
  -d '{
    "source": {
      "type": "url",
      "uri": "https://x.com/elonmusk"
    },
    "options": {
      "twitter": {
        "count": 50
      }
    }
  }'
```

4. Poll until complete, present results.
