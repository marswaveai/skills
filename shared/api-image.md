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
| model | No | string | `"gemini-3-pro-image-preview"` (default) or `"gemini-3.1-flash-image-preview"` |
| imageConfig | No | object | Size and aspect ratio config |
| imageConfig.imageSize | No | string | `"1K"`, `"2K"` (default), or `"4K"` |
| imageConfig.aspectRatio | No | string | `"1:1"` (default). See aspect ratio table below. |
| referenceImages | No | array | Up to 14 reference images for style guidance (see format below) |

**Aspect ratios:**

| Ratio | Description | Models |
|-------|-------------|--------|
| 1:1 | Square | All |
| 2:3 | Portrait photo | All |
| 3:2 | Landscape photo | All |
| 3:4 | Poster portrait | All |
| 4:3 | Traditional landscape | All |
| 9:16 | Portrait / phone | All |
| 16:9 | Landscape / widescreen | All |
| 21:9 | Ultrawide | All |
| 1:4 | Narrow portrait | gemini-3.1-flash-image-preview only |
| 4:1 | Wide landscape | gemini-3.1-flash-image-preview only |
| 1:8 | Extreme narrow portrait | gemini-3.1-flash-image-preview only |
| 8:1 | Panoramic | gemini-3.1-flash-image-preview only |

**referenceImages format:**

Each item must have either `fileData` (URL) or `inlineData` (base64), not both. You can mix URL and base64 items in the same array.

*URL-based reference:*

```json
{
  "fileData": {
    "fileUri": "https://example.com/photo.png",
    "mimeType": "image/png"
  }
}
```

Infer `mimeType` from URL suffix: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`

*Base64 reference (inline):*

```json
{
  "inlineData": {
    "data": "<base64-encoded-image>",
    "mimeType": "image/png"
  }
}
```

Supported mimeTypes: `image/png`, `image/jpeg`, `image/webp`, `image/heic`, `image/heif`

To encode a local file as base64:

```bash
# macOS
BASE64_REF=$(base64 -i /path/to/image.png)

# Linux
BASE64_REF=$(base64 -w 0 /path/to/image.png)
```

**Constraints:**
- Use `--max-time 600` (generation can take up to 10 minutes)
- On 429 (rate limit): wait 15s and retry. Max 3 retries.

**curl (text-only):**

```bash
RESPONSE=$(curl -sS -X POST "https://api.labnana.com/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "model": "gemini-3-pro-image-preview",
    "prompt": "cyberpunk city at night, neon lights, highly detailed",
    "imageConfig": {"imageSize": "2K", "aspectRatio": "16:9"}
  }')
```

**curl (with base64 reference image):**

```bash
BASE64_REF=$(base64 -i /path/to/reference.png)

RESPONSE=$(curl -sS -X POST "https://api.labnana.com/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d "{
    \"provider\": \"google\",
    \"model\": \"gemini-3-pro-image-preview\",
    \"prompt\": \"cyberpunk city at night\",
    \"imageConfig\": {\"imageSize\": \"2K\", \"aspectRatio\": \"16:9\"},
    \"referenceImages\": [{\"inlineData\": {\"data\": \"$BASE64_REF\", \"mimeType\": \"image/png\"}}]
  }")
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
