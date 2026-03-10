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
