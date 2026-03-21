---
name: image-gen
description: |
  Generate AI images from text prompts. Triggers on: "生成图片", "画一张",
  "AI图", "generate image", "配图", "create picture", "draw", "visualize",
  "generate an image".
metadata:
  openclaw:
    emoji: "🖼️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
---

## When to Use

- User wants to generate an AI image from a text description
- User says "generate image", "draw", "create picture", "配图"
- User says "生成图片", "画一张", "AI图"
- User needs a cover image, illustration, or concept art

## When NOT to Use

- User wants to create audio content (use `/podcast`, `/speech`)
- User wants to create a video (use `/explainer`)
- User wants to edit an existing image (not supported)
- User wants to extract content from a URL (use `/content-parser`)

## Purpose

Generate AI images using the Labnana API. Supports text prompts with optional reference images, multiple resolutions, and aspect ratios. Images are saved as local files.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for error handling
- Image generation uses a **different base URL**: `https://api.marswave.ai/openapi/v1`
- Always read config following `shared/config-pattern.md` before any interaction
- Output saved to `.listenhub/image-gen/YYYY-MM-DD-{jobId}/` — never `~/Downloads/`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call the image generation API until the user has explicitly confirmed.
</HARD-GATE>

## Step -1: API Key Check

Follow `shared/config-pattern.md` § API Key Check. If the key is missing, stop immediately.

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
```bash
mkdir -p ".listenhub/image-gen"
echo '{"outputDir":".listenhub","outputMode":"inline"}' > ".listenhub/image-gen/config.json"
CONFIG_PATH=".listenhub/image-gen/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```
**Do NOT ask any setup questions.** Proceed directly to the Interaction Flow.

**If file exists** — read config silently and proceed:
```bash
CONFIG_PATH=".listenhub/image-gen/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/image-gen/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

### Setup Flow (user-initiated reconfigure only)

Only run when the user explicitly asks to reconfigure. Display current settings:
```
当前配置 (image-gen)：
  输出方式：{inline / download / both}
```

Then ask:

1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.

Save immediately:
```bash
NEW_CONFIG=$(echo "$CONFIG" | jq --arg m "$OUTPUT_MODE" '. + {"outputMode": $m}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

## Interaction Flow

### Step 1: Image Description

Free text input. Ask the user:

> Describe the image you want to generate.

If the prompt is very short (< 10 words) and the user hasn't asked for verbatim generation, offer to help enrich the prompt. Otherwise, use as-is.

### Step 2: Model

Ask:

```
Question: "Which model?"
Options:
  - "pro (recommended)" — gemini-3-pro-image-preview, higher quality
  - "flash" — gemini-3.1-flash-image-preview, faster and cheaper, unlocks extreme aspect ratios (1:4, 4:1, 1:8, 8:1)
```

### Step 3: Resolution and Aspect Ratio

Ask both together (independent parameters):

```
Question: "What resolution?"
Options:
  - "1K" — Standard quality
  - "2K (recommended)" — High quality, good balance
  - "4K" — Ultra high quality, slower generation
```

```
Question: "What aspect ratio?"
Options (all models):
  - "16:9" — Landscape, widescreen
  - "1:1" — Square
  - "9:16" — Portrait, phone screen
  - "Other" — 2:3, 3:2, 3:4, 4:3, 21:9
```

If flash model was selected, also offer: `1:4` (narrow portrait), `4:1` (wide landscape), `1:8` (extreme portrait), `8:1` (panoramic)

### Step 4: Reference Images (optional)

```
Question: "Any reference images for style guidance?"
Options:
  - "Yes, I have URL(s)" — Provide reference image URLs
  - "Yes, I have local file(s)" — Provide local file paths (base64 mode)
  - "No references" — Generate from prompt only
```

**If URL mode**: Collect URLs (comma-separated, max 14). For each URL, infer mimeType from suffix and build:
```json
{ "fileData": { "fileUri": "<url>", "mimeType": "<inferred>" } }
```
Suffix mapping: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`

**If local file (base64) mode**: Collect file paths (comma-separated, max 14). For each file, encode to base64 and infer mimeType from suffix:
```bash
# macOS
BASE64_REF=$(base64 -i /path/to/image.png)
# Linux
BASE64_REF=$(base64 -w 0 /path/to/image.png)
```
Build:
```json
{ "inlineData": { "data": "<base64-encoded>", "mimeType": "<inferred>" } }
```
Suffix mapping: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.heic` → `image/heic`, `.heif` → `image/heif`

### Step 5: Confirm & Generate

Summarize all choices:

```
Ready to generate image:

  Prompt: {prompt text}
  Model: {pro / flash}
  Resolution: {1K / 2K / 4K}
  Aspect ratio: {ratio}
  References: {yes — N URL(s) / yes — N local file(s) / no}

  Proceed?
```

Wait for explicit confirmation before calling the API.

## Workflow

1. **Build request**: Construct JSON with provider, model, prompt, imageConfig, and optional referenceImages (URL-based via `fileData` or base64 via `inlineData`)
2. **Encode local files** (if base64 mode): For each local file path, encode to base64 and build `inlineData` objects
3. **Submit**: `POST https://api.marswave.ai/openapi/v1/images/generation` with timeout of 600s
4. **Extract image**: Parse base64 data from response
5. **Decode and present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Decode base64 to a temp file, then use the Read tool.

```bash
JOB_ID=$(date +%s)
echo "$BASE64_DATA" | base64 -D > /tmp/image-gen-${JOB_ID}.jpg
```
Then use the Read tool on `/tmp/image-gen-{jobId}.jpg`. The image displays inline in the conversation.

Present:
```
图片已生成！
```

**`download` or `both`**: Save to the artifact directory.

```bash
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

Present:
```
图片已生成！

已保存到 .listenhub/image-gen/{YYYY-MM-DD}-{jobId}/：
  {jobId}.jpg
```

**Base64 decoding** (cross-platform):

```bash
# Linux
echo "$BASE64_DATA" | base64 -d > output.jpg

# macOS
echo "$BASE64_DATA" | base64 -D > output.jpg
# or
echo "$BASE64_DATA" | base64 --decode > output.jpg
```

**Retry logic**: On 429 (rate limit), wait 15 seconds and retry. Max 3 retries.

## Prompt Handling

**Default**: Pass the user's prompt directly without modification.

**When to offer optimization**:
- Prompt is very short (a few words) AND user hasn't requested verbatim
- Ask: "Would you like help enriching the prompt with style/lighting/composition details?"

**When to never modify**:
- Long, detailed, or structured prompts — treat the user as experienced
- User says "use this prompt exactly"

**Optimization techniques** (if user agrees):
- Style: "cyberpunk" → add "neon lights, futuristic, dystopian"
- Scene: time of day, lighting, weather
- Quality: "highly detailed", "8K quality", "cinematic composition"
- Always use English keywords (models trained on English)
- Show optimized prompt before submitting

## API Reference

- Image generation: `shared/api-image.md`
- Error handling: `shared/common-patterns.md` § Error Handling

## Composability

- **Invokes**: nothing (direct API call)
- **Invoked by**: platform skills for cover images (Phase 2)

## Example

**User**: "Generate an image: cyberpunk city at night"

**Agent workflow**:
1. Prompt is short → offer enrichment → user declines
2. Ask model → "pro"
3. Ask resolution → "2K"
4. Ask ratio → "16:9"
5. No references

```bash
RESPONSE=$(curl -sS -X POST "https://api.marswave.ai/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "model": "gemini-3-pro-image-preview",
    "prompt": "cyberpunk city at night",
    "imageConfig": {"imageSize": "2K", "aspectRatio": "16:9"}
  }')

BASE64_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

Decode the base64 data per `outputMode` (see `shared/output-mode.md`).

### Example 2 — With Local Reference Image (base64)

**User**: "Generate an image in this style" (provides a local file path)

**Agent workflow**:
1. Ask prompt → "a serene mountain lake at dawn"
2. Ask model → "pro"
3. Ask resolution → "2K"
4. Ask ratio → "16:9"
5. References → local file → `/path/to/style-reference.png`

```bash
# Encode local reference image
BASE64_REF=$(base64 -i /path/to/style-reference.png)

RESPONSE=$(curl -sS -X POST "https://api.marswave.ai/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d "{
    \"provider\": \"google\",
    \"model\": \"gemini-3-pro-image-preview\",
    \"prompt\": \"a serene mountain lake at dawn\",
    \"imageConfig\": {\"imageSize\": \"2K\", \"aspectRatio\": \"16:9\"},
    \"referenceImages\": [{\"inlineData\": {\"data\": \"$BASE64_REF\", \"mimeType\": \"image/png\"}}]
  }")

BASE64_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

Decode the base64 data per `outputMode` (see `shared/output-mode.md`).
