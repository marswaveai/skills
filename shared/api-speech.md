# ListenHub API — Speech (FlowSpeech)

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

## FlowSpeech

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

## Multi-Speaker (coming soon)

> This section will document multi-speaker speech synthesis when the endpoint is available.
