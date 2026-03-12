# ListenHub API — Content Extract

**Authentication**: See [authentication.md](./authentication.md)

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
curl -sS -X POST "https://api.marswave.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
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
curl -sS -X POST "https://api.marswave.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
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
curl -sS "https://api.marswave.ai/openapi/v1/content/extract/69a7dac700cf95938f86d9bb" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY"
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
