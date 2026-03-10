---
name: slides
metadata:
  openclaw:
    emoji: "📊"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
description: |
  Create AI-generated slide presentations from topics or URLs. Triggers on:
  "PPT", "slides", "presentation", "slide deck", "幻灯片", "做个PPT",
  "制作幻灯片", "make slides", "create a presentation".
---

## When to Use

- User wants to create a slide deck / presentation on a topic
- User says "PPT", "slides", "幻灯片", "做个PPT"
- User provides a URL or text and wants it turned into a presentation

## When NOT to Use

- User wants an explainer video with narration (use `/explainer`)
- User wants a podcast discussion (use `/podcast`)
- User wants text-to-speech only (use `/speech`)

## Purpose

Generate slide presentations with AI-created page images and narration audio. Each slide has text content, an AI-generated image, and a narration timestamp. After generation, optionally create a video combining slides + audio.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Never hardcode speaker IDs — always fetch from the speakers API
- Never fabricate API endpoints or parameters
- Max 1 source. Max 1 speaker.

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Interaction Flow

### Step 1: Topic / Content Source

Ask the user:

> What topic or content would you like to turn into a slide presentation?

Accept: topic description, URL, or pasted text. Only 1 source is supported.

### Step 2: Language

```
Question: "What language for the slides?"
Options:
  - "English (en)"
  - "Chinese (zh)"
```

### Step 3: Speaker

Call `GET /speakers/list?language={language}` to fetch available speakers.
Present the list as options with name and gender.
Select exactly 1 speaker (storybook supports max 1).

### Step 4: Confirm

Summarize choices and ask user to confirm before calling the API.

```
Ready to generate slides:
  - Topic: {topic}
  - Language: {language}
  - Speaker: {speakerName}

Proceed?
```

Wait for explicit confirmation.

## Workflow

1. **Submit**: `POST /v1/storybook/episodes` with `mode: "slides"` → extract `episodeId`
2. Tell user: "Slides are being generated..."
3. **Poll (background)**: `GET /v1/storybook/episodes/{episodeId}` every 10s, `timeout: 600000`
4. When `processStatus=success`, **present result**:

```
Slides generated!

"{title}"

{pageCount} slides · {audioDuration}s narration

Slide 1: {pages[0].imageUrl}
Slide 2: {pages[1].imageUrl}
...

Audio: {audioUrl}
```

5. Ask if user wants to generate a video:

```
Question: "Would you like to generate a video combining slides + audio?"
Options:
  - "Yes, generate video"
  - "No, slides are enough"
```

6. If yes: `POST /v1/storybook/episodes/{episodeId}/video`, then poll until `videoStatus=success`, present `videoUrl`.

## Result Presentation

**After slides generation:**
- Show title
- List each slide: page number, text snippet, image URL
- Show audio URL

**After video generation:**
- Show video URL

## Resources

- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Slides creation: `shared/api-storybook.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Authentication: `shared/authentication.md`

## Composability

- **Invokes**: speakers API (for speaker selection)
- **Invoked by**: nothing currently

## Example

**User**: "Make a PPT about the solar system"

**Agent workflow**:
1. Detect: slides request, topic = "the solar system"
2. Ask language → "English"
3. Fetch speakers list, user picks "cozy-man-english"
4. Confirm → user says yes

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "the solar system"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "slides"
  }'
```

Poll every 10s. When done, show pages and audio. Offer video generation.
