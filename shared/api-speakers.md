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
