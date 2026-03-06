# ListenHub API Reference

Complete API reference for ListenHub services. Source of truth for all skills.

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

---

## 1. Auth

### GET /auth/api-key

Get a user's API key by email. Requires admin API key.

**Parameters (query string):**

| Param | Required | Type | Description |
|-------|----------|------|-------------|
| email | **Yes** | string | User email address |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/auth/api-key?email=user@example.com" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "apiKey": "lh_sk_abc123_def456"
  }
}
```

---

## 2. Speakers

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

---

## 3. Podcast

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

## 4. FlowSpeech

### POST /flow-speech/episodes

Create a FlowSpeech episode.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| sources | **Yes** | array | Exactly 1 source (see Sources format below) |
| speakers | **Yes** | array | 1-2 speakers: `[{speakerId: "..."}]` |
| language | No | string | `en` or `zh` |

**Sources format:**

```json
[
  {
    "type": "text",
    "content": "Text content to convert to speech",
    "uri": "https://example.com/source",
    "metadata": {}
  }
]
```

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| type | **Yes** | string | `text` or `url` |
| content | **Yes** | string | Source text or description |
| uri | No | string | Source URI |
| metadata | No | object | Additional metadata |

**Constraints:**
- Exactly 1 source
- Max 2 speakers

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/flow-speech/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "Welcome to ListenHub audio service"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en"
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

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| episodeId | string | 24-char hex episode ID |

**curl:**

```bash
curl -sS "https://api.marswave.ai/openapi/v1/flow-speech/episodes/688c9a27348f001e707ba331" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
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

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| processStatus | string | `pending`, `success`, or `failed` |
| audioUrl | string | Direct audio download URL |
| audioStreamUrl | string | Streaming audio URL |
| scripts | string | Script content (string, not array) |
| title | string | Generated title |
| outline | string | Generated outline |
| credits | integer | Credits consumed |

---

## 5. Content Extract

> **TEMPORARY**: Content extract endpoints use `https://api.staging.listenhub.ai/openapi/v1` with staging API key `lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3` (not `$LISTENHUB_API_KEY`). Update when the endpoint goes live.

### POST /v1/content/extract

Create a content extraction task for a URL. Returns a `taskId` for polling.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| source | **Yes** | object | Source to extract from |
| source.type | **Yes** | string | Must be `"url"` |
| source.uri | **Yes** | string | Valid HTTP(S) URL to extract content from |
| options | No | object | Extraction options |
| options.summarize | No | boolean | Whether to generate a summary |
| options.maxLength | No | integer | Maximum content length |
| options.twitter | No | object | Twitter/X specific options |
| options.twitter.count | No | integer | Number of tweets to fetch (1-100, default 20) |

**curl (basic):**

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

**curl (with options):**

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
      "summarize": true,
      "maxLength": 5000,
      "twitter": {
        "count": 50
      }
    }
  }'
```

**Response:**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb"
  }
}
```

**Error codes:**

| Code | Meaning |
|------|---------|
| 29003 | Validation error (`"source.uri" is required`, `"source.uri" must be a valid uri`) |
| 21007 | Invalid API key |

### GET /v1/content/extract/{taskId}

Get extraction task status and results.

**Path params:**

| Param | Type | Description |
|-------|------|-------------|
| taskId | string | 24-char hex task ID |

**curl:**

```bash
curl -sS "https://api.staging.listenhub.ai/openapi/v1/content/extract/69a7dac700cf95938f86d9bb" \
  -H "Authorization: Bearer lh_sk_692d52b84f08f4069ce53d9f_236a4aeb56c7a52914fae4c5ed0b3ccb3008ea18853945d3"
```

**Response (processing):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb",
    "status": "processing",
    "createdAt": "2025-04-09T12:00:00Z",
    "data": null,
    "credits": 0,
    "failCode": null,
    "message": null
  }
}
```

**Response (completed):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb",
    "status": "completed",
    "createdAt": "2025-04-09T12:00:00Z",
    "data": {
      "content": "Extracted text content...",
      "metadata": {
        "title": "Article Title",
        "author": "Author Name",
        "publishedAt": "2025-04-01T08:00:00Z"
      },
      "references": [
        "https://example.com/related-article"
      ]
    },
    "credits": 5,
    "failCode": null,
    "message": null
  }
}
```

**Response (failed):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "taskId": "69a7dac700cf95938f86d9bb",
    "status": "failed",
    "createdAt": "2025-04-09T12:00:00Z",
    "data": null,
    "credits": 0,
    "failCode": "EXTRACT_FAILED",
    "message": "Unable to extract content from the provided URL"
  }
}
```

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| status | string | `processing`, `completed`, or `failed` |
| data.data.content | string | Extracted text content |
| data.data.metadata | object | Page metadata (title, author, publishedAt) |
| data.data.references | array | Referenced URLs (array of strings) |
| credits | integer | Credits consumed |
| failCode | string | Error code (null on success) |
| message | string | Error message (null on success) |

**Error codes:**

| Code | Meaning |
|------|---------|
| 29003 | Invalid taskId format |
| 25002 | Task not found |

**Supported URL types:**

| Category | Platforms |
|----------|----------|
| Video | YouTube, Bilibili |
| Social | Twitter/X (profiles and single tweets), WeChat articles |
| Documents | PDF, DOCX (direct URLs) |
| Images | JPEG, PNG, etc. (direct URLs) |
| Web | Any general web page (Wikipedia, arXiv, GitHub, etc.) |

**Twitter/X notes:**
- For profile URLs (e.g. `https://x.com/username`), use `options.twitter.count` to control tweet count (1-100, default 20)
- This option is ignored for non-Twitter URLs
