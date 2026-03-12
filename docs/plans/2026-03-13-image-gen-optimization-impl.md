# Image-Gen Skill Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the image-gen skill and API reference to match the new Labnana API spec.

**Architecture:** Two files need editing — `shared/api-image.md` (API reference) and `/Users/fango/.claude/skills/listenhub-image-gen/SKILL.md` (interaction flow). No new files. No tests (these are markdown docs).

**Tech Stack:** Markdown

---

### Task 1: Update `shared/api-image.md`

**Files:**
- Modify: `shared/api-image.md`

**What to change:**

1. Add `model` row to the request params table (optional, default `gemini-3-pro-image-preview`)
2. Change `imageConfig` row from required `Yes` to `No`
3. Replace the `referenceImages` description — change from "up to 14 reference image URLs" to the nested object format
4. Expand `imageConfig.aspectRatio` description to mention the full list
5. Update the curl example to include `model` field
6. Add a new section after the params table documenting all aspect ratios + flash-only ones

**Step 1: Edit `shared/api-image.md`**

Replace the full file content with:

```markdown
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

```json
[
  {
    "fileData": {
      "fileUri": "https://example.com/photo.png",
      "mimeType": "image/png"
    }
  }
]
```

Infer `mimeType` from URL suffix: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`

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
    "model": "gemini-3-pro-image-preview",
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
```

**Step 2: Commit**

```bash
git add shared/api-image.md
git commit -m "docs(api-image): add model param, fix referenceImages format, expand aspect ratios"
```

---

### Task 2: Update `listenhub-image-gen/SKILL.md` interaction flow

**Files:**
- Modify: `/Users/fango/.claude/skills/listenhub-image-gen/SKILL.md`

**What to change:**

The interaction flow currently has Steps 1–4. We're inserting a new Step 2 (model selection) and shifting the rest:

- Step 1: Image description — **unchanged**
- **Step 2 (NEW)**: Model selection
- Step 3: Resolution + Aspect Ratio — update aspect ratio options based on model
- Step 4: Reference images — update URL collection to build nested object format
- Step 5: Confirm — renumber from Step 4

Also update the `## Workflow` section's curl example to include the `model` field.

**Step 1: Insert new Step 2 (model selection)**

In the `## Interaction Flow` section, after Step 1, insert:

```markdown
### Step 2: Model

```
Question: "Which model?"
Options:
  - "pro (recommended)" — gemini-3-pro-image-preview, higher quality
  - "flash" — gemini-3.1-flash-image-preview, faster and cheaper, unlocks extreme aspect ratios
```
```

**Step 2: Update old Step 2 → new Step 3 (resolution + aspect ratio)**

Change the heading from `### Step 2: Resolution and Aspect Ratio` to `### Step 3: Resolution and Aspect Ratio`.

Expand the aspect ratio question to show flash-only options when flash is selected:

```markdown
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

If flash model was selected, also show:
```
Flash-only options also available: 1:4, 4:1, 1:8, 8:1
```
```

**Step 3: Update old Step 3 → new Step 4 (reference images)**

Change heading to `### Step 4: Reference Images (optional)`.

Replace the URL collection instruction with:

```markdown
If yes, collect URLs (comma-separated, max 14). For each URL, infer mimeType from suffix and build:
```json
{ "fileData": { "fileUri": "<url>", "mimeType": "<inferred>" } }
```
Suffix mapping: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`
```

**Step 4: Update old Step 4 → new Step 5 (confirm)**

Change heading from `### Step 4: Confirm & Generate` to `### Step 5: Confirm & Generate`.

Add model to the summary:

```markdown
Ready to generate image:

  Prompt: {prompt text}
  Model: {pro / flash}
  Resolution: {1K / 2K / 4K}
  Aspect ratio: {ratio}
  References: {yes (N URLs) / no}

  Proceed?
```

**Step 5: Update Workflow section curl example**

In `## Workflow`, find the curl command in the example section and add `"model": "gemini-3-pro-image-preview"` (or whichever model was selected) to the JSON body. Also update the inline example at the bottom of the file.

**Step 6: Commit**

```bash
git -C /Users/fango/.claude/skills add listenhub-image-gen/SKILL.md
git -C /Users/fango/.claude/skills commit -m "feat(image-gen): add model selection, fix referenceImages format, expand aspect ratios"
```

Wait — the skills directory may be a separate repo. Check first:

```bash
ls /Users/fango/.claude/skills/.git
```

If it exists, commit from there. If not, commit from the marswave/skills repo working directory.

---

### Task 3: Commit the impl plan

```bash
git add docs/plans/2026-03-13-image-gen-optimization-impl.md
git commit -m "docs: add image-gen optimization implementation plan"
```
