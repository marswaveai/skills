# ListenHub API — Podcast

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

## Podcast

### POST /podcast/episodes

Create a podcast episode.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| speakers | **Yes** | array | 1-2 speaker objects `[{speakerId: "..."}]` |
| query | No | string | Topic or prompt text |
| sources | No | array | Content sources (see Sources format below) |
| language | No | string | `en` or `zh` |
| mode | No | string | `deep` or `quick` |

**Sources format:**

```json
[
  {"type": "url", "content": "https://example.com/article"},
  {"type": "text", "content": "Topic description or reference text..."}
]
```

**Constraints:**
- Max 2 speakers

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d '{
    "query": "The future of AI development",
    "sources": [{"type": "text", "content": "Reference material about AI trends"}],
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
  -H "X-Source: skills"
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
