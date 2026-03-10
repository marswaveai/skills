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
