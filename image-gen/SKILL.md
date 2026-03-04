---
name: image-gen
description: |
  Generate AI images from text prompts. Triggers on: "生成图片", "画一张",
  "AI图", "generate image", "配图", "create picture", "draw", "visualize",
  "generate an image".
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

- No shell scripts. Construct curl commands from `shared/api-reference.md`
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for error handling
- Image generation uses a **different base URL**: `https://api.labnana.com/openapi/v1`
- Output saved to `$LISTENHUB_OUTPUT_DIR` (default: `~/Downloads`)
- Filename format: `listenhub-YYYYMMDD-HHMMSS-XXXX.jpg`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call the image generation API until the user has explicitly confirmed.
</HARD-GATE>

## Interaction Flow

### Step 1: Image Description

Free text input. Ask the user:

> Describe the image you want to generate.

If the prompt is very short (< 10 words) and the user hasn't asked for verbatim generation, offer to help enrich the prompt. Otherwise, use as-is.

### Step 2: Resolution and Aspect Ratio

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
Options:
  - "16:9" — Landscape, widescreen
  - "1:1" — Square
  - "9:16" — Portrait, phone screen
  - "Other" — 2:3, 3:2, 3:4, 4:3, 21:9
```

### Step 3: Reference Images (optional)

```
Question: "Any reference images for style guidance?"
Options:
  - "Yes, I have URL(s)" — Provide reference image URLs
  - "No references" — Generate from prompt only
```

If yes, collect URLs (comma-separated, max 14). URLs must be direct image links ending in `.jpg`, `.png`, `.webp`, or `.gif`.

### Step 4: Confirm & Generate

Summarize all choices:

```
Ready to generate image:

  Prompt: {prompt text}
  Resolution: {1K / 2K / 4K}
  Aspect ratio: {ratio}
  References: {yes (N URLs) / no}

  Proceed?
```

Wait for explicit confirmation before calling the API.

## Workflow

1. **Build request**: Construct JSON with provider, prompt, imageConfig, and optional referenceImages
2. **Submit**: `POST https://api.labnana.com/openapi/v1/images/generation` with timeout of 600s
3. **Extract image**: Parse base64 data from response
4. **Save**: Decode base64 and save to `$LISTENHUB_OUTPUT_DIR/listenhub-YYYYMMDD-HHMMSS-XXXX.jpg`
5. **Present result**:
   ```
   Image generated!

   ~/Downloads/listenhub-20260304-143145-0001.jpg
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

- Image generation: `shared/api-reference.md` § 6. Image Generation (Labnana)
- Error handling: `shared/common-patterns.md` § Error Handling

## Composability

- **Invokes**: nothing (direct API call)
- **Invoked by**: platform skills for cover images (Phase 2)

## Example

**User**: "Generate an image: cyberpunk city at night"

**Agent workflow**:
1. Prompt is short → offer enrichment → user declines
2. Ask resolution → "2K"
3. Ask ratio → "16:9"
4. No references

```bash
RESPONSE=$(curl -sS -X POST "https://api.labnana.com/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "prompt": "cyberpunk city at night",
    "imageConfig": {"imageSize": "2K", "aspectRatio": "16:9"}
  }')

BASE64_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
echo "$BASE64_DATA" | base64 -D > ~/Downloads/listenhub-20260304-143145-0001.jpg
```

Present the saved file path to the user.
