# Common Patterns

Reusable patterns for all skills that call ListenHub APIs.

<HARD-GATE>
**Language Adaptation**: Always respond in the user's language. Chinese input → Chinese output. English input → English output. Mixed → follow dominant language. This applies to all UI text, questions, confirmations, and error messages.
</HARD-GATE>

## Async Polling

Most generation endpoints are asynchronous: submit a task, get an ID, then poll until completion.

### Execution Model

All polling MUST run in the background using Bash `run_in_background: true`. This keeps the terminal responsive while the task processes.

**Two-step pattern:**

1. **Submit (foreground)**: POST the creation request, extract the task/episode ID from the response. This is fast and runs in the foreground.
2. **Poll (background)**: Run the polling loop with `run_in_background: true`. You will be notified automatically when it completes — do NOT sleep or poll manually.

### Step 1: Submit (foreground)

```bash
RESPONSE=$(curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d '{ ... }')

EPISODE_ID=$(echo "$RESPONSE" | jq -r '.data.episodeId')
echo "Submitted: $EPISODE_ID"
```

After this returns, tell the user the task is submitted and polling will run in the background.

### Step 2: Poll (background)

Run this as a **separate Bash call** with `run_in_background: true`:

```bash
# Poll until complete — runs in background
EPISODE_ID="<id-from-step-1>"
for i in $(seq 1 30); do
  RESULT=$(curl -sS "https://api.marswave.ai/openapi/v1/podcast/episodes/$EPISODE_ID" \
    -H "Authorization: Bearer $LISTENHUB_API_KEY" \
    -H "X-Source: skills" 2>/dev/null)

  STATUS=$(echo "$RESULT" | tr -d '\000-\037\177' | jq -r '.data.processStatus // "pending"')

  case "$STATUS" in
    success|completed) echo "$RESULT"; exit 0 ;;
    failed|error) echo "FAILED: $RESULT" >&2; exit 1 ;;
    *) sleep 10 ;;
  esac
done
echo "TIMEOUT" >&2; exit 2
```

### Polling Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| Interval | 10s | Use 5s for content-parser only |
| Max polls | 30 | = 300s timeout at 10s interval |
| Timeout (Bash) | 600000 | Set `timeout: 600000` on the Bash tool call |

### After Completion

When the background task finishes, you will be notified with the output. Parse the result and present it to the user. If the task failed or timed out, report the error.

## Standard Response Structure

All API responses follow this format:

```json
{
  "code": 0,
  "message": "",
  "data": { ... }
}
```

- `code: 0` = success
- Non-zero `code` = error (see Error Handling below)

## Error Handling

### HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Parse response body |
| 400 | Bad request | Check parameters |
| 401 | Invalid API key | Re-check `LISTENHUB_API_KEY` |
| 402 | Insufficient credits | Inform user to recharge |
| 403 | Forbidden | No permission for this resource |
| 429 | Rate limited | Exponential backoff, retry after delay |
| 500/502/503/504 | Server error | Retry up to 3 times |

### Retry Strategy

- **429 rate limit**: Wait 15 seconds, then retry (exponential backoff)
- **5xx server errors**: Retry up to 3 times with 5-second intervals
- **Network errors**: Retry up to 3 times

### Application Error Codes

| Code | Meaning |
|------|---------|
| 21007 | Invalid user API key |
| 25429 | Rate limited (application-level) |

## Input Validation

| Constraint | Rule |
|-----------|------|
| URL format | Must be valid HTTP(S) URL |
| Text content length | Max 10,000 characters for TTS |
| Supported languages | `zh` (Chinese), `en` (English) |
| ID format | Alphanumeric + hyphen + underscore only |
| Episode ID format | 24-character hex string (MongoDB ObjectId) |

## Long Text Input

When `sources` content is long (e.g., a full article), passing it inline in `-d '{...}'` may hit shell argument length limits. Use `@file` to read the request body from a file:

```bash
# Write request JSON to a temp file
cat > /tmp/lh-request.json << 'ENDJSON'
{
  "sources": [{"type": "text", "content": "Very long text content goes here..."}],
  "speakers": [{"speakerId": "cozy-man-english"}],
  "language": "en"
}
ENDJSON

# Reference the file with @
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d @/tmp/lh-request.json
```

**When to use `@file`**: Always use this approach when text content exceeds a few KB. The `@` prefix tells curl to read the body from the file, bypassing shell argument limits entirely.

**Cleanup**: Remove the temp file after use: `rm /tmp/lh-request.json`

## Interactive Parameter Collection

Skills must use the **AskUserQuestion tool** for all enumerable parameters, following a **conversational, step-by-step** approach. This renders an interactive picker in the terminal that users can navigate with arrow keys.

### Conversation Behavior (mandatory)

1. **One question at a time.** Ask a single question, then STOP and wait for the user's answer before proceeding to the next step. Do not batch multiple steps into one message unless the parameters are explicitly independent (e.g., resolution + aspect ratio).
2. **Wait for the answer.** Never assume a default and skip ahead. If the user hasn't answered, do not proceed.
3. **Confirm before executing.** After all parameters are collected, summarize the choices and ask the user to confirm before calling any API. This is the final gate.
4. **Be ready to go back.** If the user changes their mind or says something doesn't look right, revise and re-ask instead of pushing forward.

### How to Ask

**Always use the AskUserQuestion tool** — do NOT print questions as plain text. Each step's `Question` and `Options` map directly to AskUserQuestion parameters:

```
Step definition in SKILL.md:          →  AskUserQuestion tool call:

Question: "What language?"            →  question: "What language?"
  - "Chinese (zh)" — Mandarin         →  options: [{label: "Chinese (zh)", description: "Mandarin"}
  - "English (en)" — English          →           {label: "English (en)", description: "English"}]
```

For **free text** steps (topic, URL, prompt), just ask the question in a normal text message and wait for the user to type their answer.

### Parameter Types

- **Multiple-choice → AskUserQuestion**: language, mode, speaker count, generation style, resolution, aspect ratio
- **Free text → normal message**: topic, content body, URL, image prompt
- **Sequential when dependent**: e.g., speaker list depends on language choice — ask language first, then fetch speakers and present list
- **Batch when independent**: e.g., resolution + aspect ratio can be asked together in one AskUserQuestion call (multiple questions)
- **Options include descriptions**: not just labels — explain what each choice means
