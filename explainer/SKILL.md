---
name: explainer
metadata:
  openclaw:
    emoji: "🎬"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
description: |
  Create explainer videos with narration and AI-generated visuals. Triggers on:
  "解说视频", "explainer video", "explain this as a video", "tutorial video",
  "introduce X (video)", "解释一下XX（视频形式）".
---

## When to Use

- User wants to create an explainer or tutorial video
- User asks to "explain" something in video form
- User wants narrated content with AI-generated visuals
- User says "explainer video", "解说视频", "tutorial video"

## When NOT to Use

- User wants audio-only content without visuals (use `/speech` or `/podcast`)
- User wants a podcast-style discussion (use `/podcast`)
- User wants to generate a standalone image (use `/image-gen`)
- User wants to read text aloud without video (use `/speech`)

## Purpose

Generate explainer videos that combine a single narrator's voiceover with AI-generated visuals. Ideal for product introductions, concept explanations, and tutorials. Supports text-only script generation or full text + video output.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Never hardcode speaker IDs — always fetch from the speakers API
- Explainer uses exactly 1 speaker

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Interaction Flow

### Step 1: Topic / Content

Free text input. Ask the user:

> What would you like to explain or introduce?

Accept: topic description, text content, or concept to explain.

### Step 2: Language

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Content in Mandarin Chinese
  - "English (en)" — Content in English
```

### Step 3: Style

```
Question: "What style of explainer?"
Options:
  - "Info" — Informational, factual presentation style
  - "Story" — Narrative, storytelling approach
```

### Step 4: Speaker Selection

Call `GET /speakers/list?language={language}` and present options.
Only 1 speaker is supported for explainer videos.

### Step 5: Output Type

```
Question: "What output do you want?"
Options:
  - "Text script only" — Generate narration script, no video
  - "Text + Video" — Generate full explainer video with AI visuals
```

### Step 6: Confirm & Generate

Summarize all choices:

```
Ready to generate explainer:

  Topic: {topic}
  Language: {language}
  Style: {info/story}
  Speaker: {speaker name}
  Output: {text only / text + video}

  Proceed?
```

Wait for explicit confirmation before calling any API.

## Workflow

1. **Submit (foreground)**: `POST /storybook/episodes` with content, speaker, language, mode → extract `episodeId`
2. Tell the user the task is submitted
3. **Poll (background)**: `GET /storybook/episodes/{episodeId}` every 10s with `run_in_background: true` and `timeout: 600000`
4. When notified, **present script**: Show the generated text/outline to the user
5. **If video requested**: `POST /storybook/episodes/{episodeId}/video` (foreground) → **poll again (background)** with `run_in_background: true`
6. When notified, **present result**:
   ```
   Explainer video generated!

   "{title}"

   Watch: https://listenhub.ai/app/explainer
   Duration: ~{estimated} minutes
   ```

**Estimated times**:
- Text script only: 2-3 minutes
- Text + Video: 3-5 minutes

## API Reference

- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-storybook.md`
- Polling: `shared/common-patterns.md` § Async Polling

## Composability

- **Invokes**: speakers API (for speaker selection); may invoke `/speech` for voiceover
- **Invoked by**: content-planner (Phase 3)

## Example

**User**: "Create an explainer video introducing Claude Code"

**Agent workflow**:
1. Topic: "Claude Code introduction"
2. Ask language → "English"
3. Ask style → "Info"
4. Fetch speakers, user picks "cozy-man-english"
5. Ask output → "Text + Video"

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "Introduce Claude Code: what it is, key features, and how to get started"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "info"
  }'
```

Poll until text is ready, then generate video if requested.
