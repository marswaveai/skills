# API Reference Split + Slides Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the monolithic `shared/api-reference.md` into per-skill API reference files, fix broken section references in all SKILL.md files, and create a new `/slides` skill backed by the storybook endpoint.

**Architecture:** Extract each API section from `api-reference.md` into its own file in `shared/`. Update all SKILL.md Resources sections to reference the new files directly. Create `skills/slides/SKILL.md` using `POST /v1/storybook/episodes` with `mode=slides`. Add `shared/api-storybook.md` documenting the 3 storybook endpoints.

**Tech Stack:** Markdown only. No code, no tests. Verify by reading the final files.

---

## Task 1: Extract `shared/api-speakers.md`

**Files:**
- Create: `shared/api-speakers.md`

**Step 1: Extract the Speakers section from `api-reference.md`**

Create `shared/api-speakers.md` with this content (line 10–60 of `api-reference.md`, section `## 1. Speakers`):

```markdown
# ListenHub API — Speakers

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

## GET /speakers/list

Get available voice speakers, optionally filtered by language.

**Parameters (query string):**

| Param | Required | Type | Description |
|-------|----------|------|-------------|
| language | No | string | Filter by language: `zh` or `en` |
| status | No | integer | Speaker status: `1` (active, default) or `2` |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/speakers/list?language=en" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "items": [
      {
        "name": "Yuanye",
        "speakerId": "cozy-man-english",
        "demoAudioUrl": "https://example.com/demo.mp3",
        "gender": "male",
        "language": "en"
      }
    ]
  }
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| name | string | Display name |
| speakerId | string | ID to pass to creation endpoints |
| demoAudioUrl | string | Preview audio URL |
| gender | string | `male` or `female` |
| language | string | `zh` or `en` |
```

**Step 2: Verify the file looks correct**

Read `shared/api-speakers.md` and confirm it has the curl example and response fields table.

**Step 3: Commit**

```bash
git add shared/api-speakers.md
git commit -m "refactor(api-ref): extract api-speakers.md"
```

---

## Task 2: Extract `shared/api-podcast.md`

**Files:**
- Create: `shared/api-podcast.md`

**Step 1: Create the file**

Extract section `## 2. Podcast` (lines 62–190 of `api-reference.md`). The file should contain:

- Header with base URL
- `POST /podcast/episodes` — request body table, sources format, constraints, curl example, response JSON, key fields table
- `GET /podcast/episodes/{episodeId}` — path params, curl, full response JSON, key fields table

Start the file with:
```markdown
# ListenHub API — Podcast

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)
```

Then copy the podcast sections verbatim from `api-reference.md` §2, replacing the `## 2. Podcast` heading with `## Podcast`.

**Step 2: Verify**

Read `shared/api-podcast.md` and confirm both `POST /podcast/episodes` and `GET /podcast/episodes/{episodeId}` are present with their curl examples.

**Step 3: Commit**

```bash
git add shared/api-podcast.md
git commit -m "refactor(api-ref): extract api-podcast.md"
```

---

## Task 3: Extract `shared/api-speech.md`

**Files:**
- Create: `shared/api-speech.md`

**Step 1: Create the file**

Extract section `## 3. FlowSpeech` (lines 192–310 of `api-reference.md`).

Start with:
```markdown
# ListenHub API — Speech (FlowSpeech)

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)
```

Copy `POST /flow-speech/episodes` and `GET /flow-speech/episodes/{episodeId}` verbatim from `api-reference.md` §3.

Note: The speech skill also references "Multi-Speaker" (`§ 5. Speech (Multi-Speaker)`). That section does not currently exist in `api-reference.md`. Leave a placeholder comment at the bottom:

```markdown
---

## Multi-Speaker (coming soon)

> This section will document multi-speaker speech synthesis when the endpoint is available.
```

**Step 2: Verify**

Read `shared/api-speech.md` and confirm the FlowSpeech endpoints are present.

**Step 3: Commit**

```bash
git add shared/api-speech.md
git commit -m "refactor(api-ref): extract api-speech.md"
```

---

## Task 4: Extract `shared/api-content-extract.md`

**Files:**
- Create: `shared/api-content-extract.md`

**Step 1: Create the file**

Extract section `## 4. Content Extract` (lines 313–500 of `api-reference.md`). This is the longest section — copy it in full.

Start with:
```markdown
# ListenHub API — Content Extract

> **TEMPORARY**: Content extract endpoints use `https://api.staging.listenhub.ai/openapi/v1` with staging API key `lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3` (not `$LISTENHUB_API_KEY`). Update when the endpoint goes live.
```

Then copy `POST /v1/content/extract` and `GET /v1/content/extract/{taskId}` verbatim including error codes table and supported URL types table.

**Step 2: Verify**

Read `shared/api-content-extract.md` and confirm it has both endpoints, the staging URL note, and the supported platforms table.

**Step 3: Commit**

```bash
git add shared/api-content-extract.md
git commit -m "refactor(api-ref): extract api-content-extract.md"
```

---

## Task 5: Create `shared/api-image.md`

The image generation API is not in `api-reference.md` (it uses a separate Labnana base URL). The full API details live inline in `image-gen/SKILL.md`. Extract a standalone reference file.

**Files:**
- Create: `shared/api-image.md`

**Step 1: Read `image-gen/SKILL.md` to locate the API call details**

Look for the `POST https://api.labnana.com/openapi/v1/images/generation` call — it's in the Workflow and Example sections.

**Step 2: Create the file**

```markdown
# ListenHub API — Image Generation (Labnana)

**Base URL**: `https://api.labnana.com/openapi/v1`
**Authentication**: Bearer `$LISTENHUB_API_KEY` (same key, different host)

## POST /images/generation

Generate an AI image from a text prompt. Synchronous — returns base64-encoded image data directly (no polling needed).

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| provider | Yes | string | Model provider. Use `"google"` |
| prompt | Yes | string | Image description (English recommended) |
| imageConfig | Yes | object | Size and aspect ratio config |
| imageConfig.imageSize | No | string | `"2K"` (default) or `"4K"` |
| imageConfig.aspectRatio | No | string | `"1:1"`, `"16:9"`, `"9:16"`, `"4:3"`, `"3:4"` |
| referenceImages | No | array | Up to 14 reference image URLs for style guidance |

**Constraints:**
- Use `--max-time 600` (generation can take up to 10 minutes)
- On 429 (rate limit): wait 15s and retry. Max 3 retries.

**curl:**

```bash
RESPONSE=$(curl -sS -X POST "https://api.labnana.com/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "prompt": "cyberpunk city at night, neon lights, highly detailed",
    "imageConfig": {"imageSize": "2K", "aspectRatio": "16:9"}
  }')
```

**Response:**

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "inlineData": {
              "data": "<base64-encoded-jpeg>",
              "mimeType": "image/jpeg"
            }
          }
        ]
      }
    }
  ]
}
```

**Extract base64 data:**

```bash
BASE64_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
```

**Save to file (macOS):**

```bash
echo "$BASE64_DATA" | base64 -D > ~/Downloads/listenhub-$(date +%Y%m%d-%H%M%S)-0001.jpg
```

**Save to file (Linux):**

```bash
echo "$BASE64_DATA" | base64 -d > ~/Downloads/listenhub-$(date +%Y%m%d-%H%M%S)-0001.jpg
```
```

**Step 3: Verify**

Read `shared/api-image.md` and confirm request/response tables and both platform decode commands are present.

**Step 4: Commit**

```bash
git add shared/api-image.md
git commit -m "refactor(api-ref): extract api-image.md"
```

---

## Task 6: Create `shared/api-storybook.md`

This is new content — the storybook API is not documented anywhere in the skills repo yet. Source of truth: `listenhub-api-server/src/openapi-controllers/storybook.ts`.

**Files:**
- Create: `shared/api-storybook.md`

**Step 1: Create the file**

```markdown
# ListenHub API — Storybook

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

Used by: `/explainer` skill (mode=`info`), `/slides` skill (mode=`slides`)

---

## POST /v1/storybook/episodes

Create a storybook episode. Returns an `episodeId` immediately; generation runs asynchronously.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| sources | **Yes** | array | Exactly 1 source object |
| sources[].type | **Yes** | string | `"text"` or `"url"` |
| sources[].content | **Yes** | string | Topic text or URL |
| speakers | **Yes** | array | Exactly 1 speaker: `[{"speakerId": "..."}]` |
| language | No | string | `"en"` or `"zh"` |
| mode | No | string | `"info"` (explainer), `"story"`, or `"slides"` (default: `"info"`) |
| style | No | string | Visual style hint (optional, free text) |

**Constraints:**
- Exactly 1 source
- Max 1 speaker

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "The history of the Roman Empire"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "slides"
  }'
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "episodeId": "688c9a27348f001e707ba331"
  }
}
```

---

## GET /v1/storybook/episodes/{episodeId}

Get storybook episode status and result.

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/storybook/episodes/688c9a27348f001e707ba331" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "episodeId": "688c9a27348f001e707ba331",
    "createdAt": 1718230400,
    "mode": "slides",
    "processStatus": "success",
    "completedTime": 1718230450,
    "credits": 10,
    "message": "success",
    "failCode": 0,
    "title": "The Roman Empire",
    "cover": "https://example.com/cover.jpg",
    "audioUrl": "https://gcs.example.com/audio.mp3",
    "audioDuration": 120,
    "videoUrl": null,
    "videoStatus": "not_generated",
    "pages": [
      {
        "text": "The Roman Empire began in 27 BC...",
        "pageNumber": 1,
        "imageUrl": "https://example.com/page1.jpg",
        "audioTimestamp": 0
      }
    ],
    "sourceProcessResult": {
      "query": "The history of the Roman Empire",
      "content": "Processed source text...",
      "imageSources": []
    }
  }
}
```

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| processStatus | string | `"pending"`, `"success"`, or `"failed"` |
| mode | string | `"info"`, `"story"`, or `"slides"` |
| pages | array | Slide pages — each has `text`, `pageNumber`, `imageUrl`, `audioTimestamp` |
| audioUrl | string | Narration audio URL |
| audioDuration | number | Audio length in seconds |
| videoUrl | string | Video URL (null until generated via video endpoint) |
| videoStatus | string | `"not_generated"`, `"pending"`, `"success"`, `"failed"` |
| credits | integer | Credits consumed |
| failCode | number | Non-zero on failure |

---

## POST /v1/storybook/episodes/{episodeId}/video

Trigger video generation for a completed storybook episode. Video combines the page images with narration audio.

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID (must be `processStatus=success`) |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes/688c9a27348f001e707ba331/video" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "success": true
  }
}
```

After calling this endpoint, poll `GET /v1/storybook/episodes/{episodeId}` and wait for `videoStatus=success`. Then `videoUrl` will contain the video URL.
```

**Step 2: Verify**

Read `shared/api-storybook.md` and confirm all 3 endpoints are present, the `pages` response field is documented, and the `videoStatus` polling note is at the end.

**Step 3: Commit**

```bash
git add shared/api-storybook.md
git commit -m "docs(api-ref): add api-storybook.md for storybook/slides endpoints"
```

---

## Task 7: Update all SKILL.md Resources sections

Now update each skill's Resources section to reference the new per-file docs instead of `shared/api-reference.md § X`.

**Files:**
- Modify: `podcast/SKILL.md`
- Modify: `speech/SKILL.md`
- Modify: `explainer/SKILL.md`
- Modify: `image-gen/SKILL.md`
- Modify: `content-parser/SKILL.md`

**Step 1: Update `podcast/SKILL.md`**

Find (lines ~162–165):
```
- Speaker list: `shared/api-reference.md` § 1. Speakers
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-reference.md` § 2. Podcast
- Polling: `shared/common-patterns.md` § Async Polling
```

Replace with:
```
- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-podcast.md`
- Polling: `shared/common-patterns.md` § Async Polling
```

Also update the Hard Constraints section — find:
```
- No shell scripts. Construct curl commands from `shared/api-reference.md`
```
Replace with:
```
- No shell scripts. Construct curl commands from the API reference files listed in Resources
```

**Step 2: Update `speech/SKILL.md`**

Find Resources section (lines ~150–154):
```
- Speaker list: `shared/api-reference.md` § 1. Speakers
- Speaker selection guide: `shared/speaker-selection.md`
- FlowSpeech: `shared/api-reference.md` § 4. FlowSpeech (TTS)
- Multi-speaker: `shared/api-reference.md` § 5. Speech (Multi-Speaker)
- Polling: `shared/common-patterns.md` § Async Polling
```

Replace with:
```
- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- FlowSpeech (TTS): `shared/api-speech.md`
- Multi-speaker: `shared/api-speech.md` § Multi-Speaker
- Polling: `shared/common-patterns.md` § Async Polling
```

Also update the Hard Constraints `api-reference.md` reference same as podcast.

**Step 3: Update `explainer/SKILL.md`**

Find Resources section (lines ~128–131):
```
- Speaker list: `shared/api-reference.md` § 1. Speakers
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-reference.md` § 3. Explainer (Storybook)
- Polling: `shared/common-patterns.md` § Async Polling
```

Replace with:
```
- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-storybook.md`
- Polling: `shared/common-patterns.md` § Async Polling
```

Also update the Hard Constraints `api-reference.md` reference.

**Step 4: Update `image-gen/SKILL.md`**

Find Resources section (lines ~153–154):
```
- Image generation: `shared/api-reference.md` § 6. Image Generation (Labnana)
- Error handling: `shared/common-patterns.md` § Error Handling
```

Replace with:
```
- Image generation: `shared/api-image.md`
- Error handling: `shared/common-patterns.md` § Error Handling
```

Also update Hard Constraints `api-reference.md` reference.

**Step 5: Update `content-parser/SKILL.md`**

Find Resources section (lines ~122–125):
```
- Content extract: `shared/api-reference.md` § 5. Content Extract
- Supported platforms: `references/supported-platforms.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Error handling: `shared/common-patterns.md` § Error Handling
```

Replace with:
```
- Content extract: `shared/api-content-extract.md`
- Supported platforms: `references/supported-platforms.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Error handling: `shared/common-patterns.md` § Error Handling
```

Also update Hard Constraints `api-reference.md` reference.

**Step 6: Verify all 5 files**

Grep to confirm no skill still references `api-reference.md`:

```bash
grep -r "api-reference.md" skills/podcast/SKILL.md skills/speech/SKILL.md skills/explainer/SKILL.md skills/image-gen/SKILL.md skills/content-parser/SKILL.md
```

Expected: no output.

**Step 7: Commit**

```bash
git add podcast/SKILL.md speech/SKILL.md explainer/SKILL.md image-gen/SKILL.md content-parser/SKILL.md
git commit -m "refactor: update skill Resources to use per-skill api reference files"
```

---

## Task 8: Delete `shared/api-reference.md`

**Files:**
- Delete: `shared/api-reference.md`

**Step 1: Confirm no remaining references**

```bash
grep -r "api-reference.md" .
```

Expected: no output (or only the design doc + plan doc, which are historical and fine to keep).

**Step 2: Delete the file**

```bash
git rm shared/api-reference.md
git commit -m "refactor: remove monolithic api-reference.md (split into per-skill files)"
```

---

## Task 9: Create `slides/SKILL.md`

**Files:**
- Create: `slides/SKILL.md`

**Step 1: Create the file**

```markdown
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
```

**Step 2: Verify the file**

Read `slides/SKILL.md` and confirm:
- Trigger words include `PPT`, `幻灯片`, `presentation`
- Hard constraints mention max 1 source, max 1 speaker
- HARD-GATE block is present
- Resources section lists `shared/api-storybook.md`

**Step 3: Commit**

```bash
git add slides/SKILL.md
git commit -m "feat: add slides skill for PPT generation via storybook endpoint"
```

---

## Task 10: Final verification

**Step 1: Check all new shared files exist**

```bash
ls shared/api-*.md
```

Expected output:
```
shared/api-content-extract.md
shared/api-image.md
shared/api-podcast.md
shared/api-speakers.md
shared/api-speech.md
shared/api-storybook.md
```

**Step 2: Check `api-reference.md` is gone**

```bash
ls shared/api-reference.md
```

Expected: `No such file or directory`

**Step 3: Check no broken references remain**

```bash
grep -r "api-reference.md" podcast/ speech/ explainer/ image-gen/ content-parser/ slides/
```

Expected: no output.

**Step 4: Check the slides skill exists**

```bash
ls slides/SKILL.md
```

Expected: file present.

**Step 5: Commit if any loose files**

If all verification passes and nothing is staged, you're done. Otherwise commit any remaining changes.
