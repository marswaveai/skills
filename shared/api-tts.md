# ListenHub API — TTS

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

---

## POST /v1/tts

Low-latency single-voice TTS. Returns a **streaming binary MP3** — not JSON.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| input | Yes | string | Text to convert |
| voice | Yes | string | Speaker ID (`speakerId` from speakers API) |
| model | No | string | Model name, defaults to `flowtts` |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d '{
    "input": "Hello, welcome to ListenHub.",
    "voice": "EN-Man-General-01"
  }' \
  --output /tmp/tts-output.mp3
```

**Response:** Binary MP3 audio stream. On error, falls back to a JSON error object (check HTTP status code first).

**Key constraints:**
- Max ~10,000 characters for `input`
- `voice` must be a valid `speakerId` from `GET /speakers/list`

---

## POST /v1/speech

Multi-speaker script-to-audio. Each script segment uses a different voice. Returns audio URL **synchronously**.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| scripts | Yes | array | Ordered array of script segments |
| scripts[].content | Yes | string | Text for this segment |
| scripts[].speakerId | Yes | string | Speaker ID for this segment |
| title | No | string | Custom title (auto-generated if omitted) |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/speech" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d '{
    "scripts": [
      {"content": "Welcome everyone.", "speakerId": "EN-Man-General-01"},
      {"content": "Today we discuss an interesting topic.", "speakerId": "EN-Woman-General-01"},
      {"content": "Let us begin.", "speakerId": "EN-Man-General-01"}
    ]
  }'
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "audioUrl": "https://assets.listenhub.ai/listenhub-public-prod/podcast/example.mp3",
    "audioDuration": 12500,
    "subtitlesUrl": "https://assets.listenhub.ai/listenhub-public-prod/podcast/example.srt",
    "taskId": "1eed39d387a046c0a1213e6b8f139d77",
    "credits": 12
  }
}
```

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| audioUrl | string | MP3 audio file URL |
| audioDuration | integer | Duration in milliseconds |
| subtitlesUrl | string | SRT subtitle file URL |
| taskId | string | Task identifier |
| credits | integer | Credits consumed |
