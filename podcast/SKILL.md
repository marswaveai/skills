---
name: podcast
metadata:
  openclaw:
    emoji: "🎙️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
description: |
  Create podcasts from topics, URLs, or text. Triggers on: "做播客", "podcast",
  "播客", "录一期节目", "chat about", "discuss", "debate", "dialogue",
  "make a podcast about".
---

## When to Use

- User wants to create a podcast episode on any topic
- User provides a URL or text and wants it turned into a podcast discussion
- User asks for a "debate", "dialogue", or "discussion" format
- User says "podcast", "播客", or "录一期节目"

## When NOT to Use

- User wants text-to-speech reading (use `/speech`)
- User wants an explainer video with visuals (use `/explainer`)
- User wants to generate an image (use `/image-gen`)
- User only wants to extract content from a URL without generating audio (use `/content-parser`)

## Purpose

Generate podcast episodes with 1-2 AI speakers discussing a topic. Supports quick overviews, deep analysis, and debate formats. Input can be a topic description, URL(s), or text. Output is a full audio episode with transcript.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Never hardcode speaker IDs — always fetch from the speakers API
- Never fabricate API endpoints or parameters

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Interaction Flow

### Step 1: Topic / Content Source

Free text input. Ask the user:

> What topic or content would you like to turn into a podcast?

Accept: topic description, URL, or pasted text.

### Step 2: Mode

```
Question: "What podcast generation mode?"
Options:
  - "Quick" — Short, concise overview (~5 min)
  - "Deep" — Thorough analysis with more detail (~10-15 min)
  - "Debate" — Two speakers with opposing views (requires 2 speakers)
```

### Step 3: Language

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Content in Mandarin Chinese
  - "English (en)" — Content in English
```

### Step 4: Speaker Count

```
Question: "How many speakers?"
Options:
  - "1 speaker (solo)" — Monologue style
  - "2 speakers (dialogue)" — Conversation style
```

Note: Debate mode automatically sets 2 speakers.

### Step 5: Speaker Selection

Call `GET /speakers/list?language={language}` to fetch available speakers.
Present the list as options with name and gender.

If 2 speakers needed, ask twice or present pairs.

### Step 6: Reference Materials (optional)

```
Question: "Any reference materials to include?"
Options:
  - "Yes, URL(s)" — Provide URLs to analyze
  - "Yes, text" — Paste reference text
  - "No references" — Generate from topic alone
```

### Step 7: Generation Method

```
Question: "How would you like to generate?"
Options:
  - "One step (recommended)" — Generate text + audio together, faster
  - "Two steps (review first)" — Generate text, review/edit, then generate audio
```

### Step 8: Confirm & Generate

Summarize all choices:

```
Ready to generate podcast:

  Topic: {topic}
  Mode: {mode}
  Language: {language}
  Speakers: {speaker name(s)}
  References: {yes/no}
  Method: {one-step/two-step}

  Proceed?
```

Wait for explicit confirmation before calling any API.

## Workflow

### One-Step Generation

1. **Submit (foreground)**: `POST /podcast/episodes` with collected parameters → extract `episodeId`
2. Tell the user the task is submitted
3. **Poll (background)**: `GET /podcast/episodes/{episodeId}` every 10s with `run_in_background: true` and `timeout: 600000`
4. When notified of completion, **present result**:
   ```
   Podcast generated!

   "{title}"

   Listen: https://listenhub.ai/app/episode/{episodeId}
   Duration: ~{estimated} minutes
   ```
5. Offer to show transcript or provide download URL on request

### Two-Step Generation

1. **Step 1 — Submit text (foreground)**: `POST /podcast/episodes/text-content` → extract `episodeId`
2. **Poll text (background)**: `run_in_background: true`, `timeout: 600000`
3. When notified, **save draft**: Save the `scripts` array as a readable markdown file and a JSON file to `~/Downloads/`
4. **STOP**: Present the draft and wait for explicit user approval
5. **Step 2 — Submit audio (foreground, after approval)**:
   - No changes: `POST /podcast/episodes/{episodeId}/audio` with `{}`
   - With edits: `POST /podcast/episodes/{episodeId}/audio` with modified `{scripts: [...]}`
6. **Poll audio (background)**: `run_in_background: true`, `timeout: 600000`
7. When notified, present result

## API Reference

- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-podcast.md`
- Polling: `shared/common-patterns.md` § Async Polling

## Composability

- **Invokes**: speakers API (for speaker selection)
- **Invoked by**: content-planner (Phase 3)

## Example

**User**: "Make a podcast about the latest AI developments"

**Agent workflow**:
1. Detect: podcast request, topic = "latest AI developments"
2. Ask mode → user picks "Deep"
3. Ask language → "English"
4. Ask speakers → 1 speaker
5. Fetch speakers list, user picks "cozy-man-english"
6. No references
7. One-step generation

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "The latest AI developments"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "deep"
  }'
```

Poll until complete, then present the result with title and listen link.
