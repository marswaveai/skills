# ListenHub API Reference

Complete API reference for ListenHub and Labnana services. Source of truth for all skills.

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

---

## 1. Speakers

### GET /speakers/list

Get available voice speakers, optionally filtered by language.

**Parameters (query string):**

| Param | Required | Type | Description |
|-------|----------|------|-------------|
| language | No | string | Filter by language: `zh` or `en` |
| status | No | integer | Speaker status: `1` (active, default) or `2` |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/speakers/list?language=en" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \

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

---

## 2. Podcast

### POST /podcast/episodes

Create a podcast episode (one-stage: text + audio generated together).

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| sources | **Yes** | array | Content sources (see Sources format below) |
| speakers | **Yes** | array | 1-2 speaker objects `[{speakerId: "..."}]` |
| language | No | string | `en` or `zh` |
| mode | No | string | `quick` (default), `deep`, or `debate` |

**Sources format:**

```json
[
  {"type": "url", "content": "https://example.com/article"},
  {"type": "text", "content": "Topic description or reference text..."}
]
```

**Constraints:**
- `debate` mode requires exactly 2 speakers
- Max 2 speakers

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "The future of AI development"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "deep"
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

### POST /podcast/episodes/text-content

Create podcast text content only (two-stage step 1). Same request body as POST /podcast/episodes.

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes/text-content" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "AI history"}],
    "speakers": [{"speakerId": "cozy-man-english"}, {"speakerId": "travel-girl-english"}],
    "language": "en",
    "mode": "deep"
  }'
```

**Response:** Same as POST /podcast/episodes — returns `{data: {episodeId: "..."}}`

### POST /podcast/episodes/{episodeId}/audio

Generate audio from reviewed text (two-stage step 2).

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID |

**Request body (optional):**

If user edited scripts, pass modified scripts:

```json
{
  "scripts": [
    {"content": "Hello everyone", "speakerId": "cozy-man-english"},
    {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
  ]
}
```

If no edits, send `{}` to use original scripts.

**curl:**

```bash
# No edits:
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes/688c9a27348f001e707ba331/audio" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### GET /podcast/episodes/{episodeId}

Get podcast episode details and status.

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/podcast/episodes/688c9a27348f001e707ba331" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \

```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "episodeId": "688c9a27348f001e707ba331",
    "createdAt": 1718230400,
    "credits": 10,
    "message": "success",
    "failCode": 0,
    "processStatus": "success",
    "completedTime": 1718230400,
    "sourceProcessResult": {
      "content": "User-provided source text",
      "references": [
        {
          "type": "url",
          "urlCitation": {
            "title": "Reference Title",
            "url": "https://example.com/reference",
            "favicon": "https://example.com/favicon.ico"
          }
        }
      ]
    },
    "title": "My Podcast Title",
    "outline": "This is the podcast outline.",
    "cover": "https://example.com/cover.jpg",
    "audioUrl": "https://gcs.example.com/audio.mp3",
    "audioStreamUrl": "https://gcs.example.com/audio_stream.m3u8",
    "scripts": [
      {
        "speakerId": "speaker-1",
        "speakerName": "Host A",
        "content": "This is the first segment"
      }
    ]
  }
}
```

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| processStatus | string | `pending`, `success`, or `failed` |
| audioUrl | string | Direct audio download URL |
| audioStreamUrl | string | M3U8 streaming URL |
| scripts | array | Script segments with speaker info and text |
| title | string | Generated episode title |
| outline | string | Generated outline |
| cover | string | Cover image URL |
| credits | integer | Credits consumed |

---

## 3. Explainer (Storybook)

### POST /storybook/episodes

Create an explainer episode with narration and optional video.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| sources | **Yes** | array | Content sources: `[{type: "text", content: "..."}]` |
| speakers | **Yes** | array | Exactly 1 speaker: `[{speakerId: "..."}]` |
| language | **Yes** | string | `zh` or `en` |
| mode | No | string | `info` (default) or `story` |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "Introduce ListenHub features"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "info"
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

### POST /storybook/episodes/{episodeId}/video

Generate video for an explainer episode (after text/audio is ready).

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID |

**Request body:** `{}` (empty object)

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/storybook/episodes/688c9a27348f001e707ba331/video" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### GET /storybook/episodes/{episodeId}

Get explainer episode details and status. Same polling pattern as podcast.

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/storybook/episodes/688c9a27348f001e707ba331" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \

```

**Response:** Same structure as podcast episode info (`processStatus`, `title`, `audioUrl`, etc.).

---

## 4. FlowSpeech (TTS)

### POST /flow-speech/episodes

Create a FlowSpeech episode for single-speaker text-to-speech.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| sources | **Yes** | array | 1 source: `[{type: "text"|"url", content: "..."}]` |
| speakers | **Yes** | array | 1-2 speakers: `[{speakerId: "..."}]` |
| language | No | string | `en` or `zh` |
| mode | No | string | `direct` (default) or `smart` (fixes grammar/punctuation) |

**Text content limit:** 10,000 characters.

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/flow-speech/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "Welcome to ListenHub audio service"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "smart"
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

### GET /flow-speech/episodes/{episodeId}

Get FlowSpeech episode details and status.

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/flow-speech/episodes/688c9a27348f001e707ba331" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \

```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "episodeId": "flowspeech_episode_001",
    "createdAt": 0,
    "credits": 5,
    "message": "success",
    "failCode": 0,
    "processStatus": "success",
    "completedTime": 0,
    "sourceProcessResult": {
      "content": "User-provided source text"
    },
    "title": "My FlowSpeech Title",
    "outline": "FlowSpeech outline.",
    "cover": "https://example.com/cover.jpg",
    "audioUrl": "https://gcs.example.com/flowspeech_audio.mp3",
    "audioStreamUrl": "https://gcs.example.com/flowspeech_audio_stream.m3u8",
    "scripts": "Script content as string"
  }
}
```

---

## 5. Speech (Multi-Speaker)

### POST /speech

Create multi-speaker audio from a scripts array.

**Request body:**

```json
{
  "scripts": [
    {"content": "Hello everyone", "speakerId": "cozy-man-english"},
    {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
  ]
}
```

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| scripts | **Yes** | array | Array of script segments |
| scripts[].content | **Yes** | string | Text content for this segment |
| scripts[].speakerId | **Yes** | string | Speaker ID for this segment |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/speech" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "scripts": [
      {"content": "Hello everyone", "speakerId": "cozy-man-english"},
      {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
    ]
  }'
```

**Response:** Returns `episodeId` for status polling (poll via flow-speech endpoint).

---

## 6. Image Generation (Labnana)

**Base URL:** `https://api.labnana.com/openapi/v1` (different from ListenHub API)

### POST /images/generation

Generate an AI image. Returns base64-encoded image data.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| provider | **Yes** | string | Always `"google"` |
| prompt | **Yes** | string | Image description |
| imageConfig.imageSize | No | string | `1K`, `2K` (default), or `4K` |
| imageConfig.aspectRatio | No | string | `16:9` (default), `1:1`, `9:16`, `2:3`, `3:2`, `3:4`, `4:3`, `21:9` |
| referenceImages | No | array | Up to 14 reference images (see format below) |

**Reference images format:**

```json
[
  {
    "fileData": {
      "fileUri": "https://example.com/ref.jpg",
      "mimeType": "image/jpeg"
    }
  }
]
```

Supported MIME types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/bmp`.

**curl:**

```bash
curl -sS -X POST "https://api.labnana.com/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "prompt": "Sunset over mountains, cinematic composition",
    "imageConfig": {
      "imageSize": "2K",
      "aspectRatio": "16:9"
    }
  }'
```

**Response:**

The image data is returned as base64 in the response. Extract via:

```
.candidates[0].content.parts[0].inlineData.data
```

or fallback paths:

```
.candidates[0].content.parts[0].inline_data.data
.data
```

**Saving the image:**

```bash
# Extract base64 and decode
IMAGE_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
echo "$IMAGE_DATA" | base64 -d > output.jpg   # Linux
echo "$IMAGE_DATA" | base64 -D > output.jpg   # macOS (older)
```

**Output directory**: Save to `$LISTENHUB_OUTPUT_DIR` (default: `~/Downloads`).
**Filename format**: `listenhub-YYYYMMDD-HHMMSS-XXXX.jpg` (XXXX = random 4-digit).

**Error codes:**

| HTTP | Meaning |
|------|---------|
| 401 | Invalid API key |
| 402 | Insufficient credits |
| 429 | Rate limited — wait and retry |

---

## 7. Content Extract

> **TEMPORARY**: Content extract endpoints use `http://localhost:3040/openapi/v1` instead of the production base URL. Update when the endpoint goes live.

### POST /v1/content/extract

Create a content extraction task for a URL. Returns a `taskId` for polling.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| url | **Yes** | string | Valid HTTP(S) URL to extract content from |
| language | No | string | `en` or `zh` |

**curl:**

```bash
curl -sS -X POST "http://localhost:3040/openapi/v1/content/extract" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://en.wikipedia.org/wiki/Topology", "language": "en"}'
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb"
  }
}
```

**Error codes:**

| Code | Meaning |
|------|---------|
| 29003 | Validation error (`"url" is required`, `"url" must be a valid uri`, invalid language) |
| 21007 | Invalid API key |

### GET /v1/content/extract/{taskId}

Get extraction task status and results.

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| taskId | string | 24-char hex task ID |

**curl:**

```bash
curl -sS "http://localhost:3040/openapi/v1/content/extract/69a7dac700cf95938f86d9bb" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

**Response (processing):**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb",
    "status": "processing",
    "createdAt": 1772608199726
  }
}
```

**Response (completed):**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb",
    "status": "completed",
    "createdAt": 1772608199726,
    "data": {
      "content": "Extracted text content...",
      "metadata": {},
      "references": []
    },
    "credits": 1
  }
}
```

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| status | string | `processing`, `completed`, or `failed` |
| data.content | string | Extracted text content |
| data.metadata | object | Platform-specific metadata |
| data.references | array | Source references |
| credits | integer | Credits consumed |

**Error codes:**

| Code | Meaning |
|------|---------|
| 29003 | Invalid taskId format |
| 25002 | Task not found |

**Supported URL types:**

| Category | Platforms |
|----------|----------|
| Video | YouTube, Bilibili |
| Social | Twitter/X (profile pages), WeChat articles |
| Documents | PDF, DOCX (direct URLs) |
| Images | JPEG, PNG, etc. (direct URLs) |
| Web | Any general web page (Wikipedia, arXiv, GitHub, etc.) |
