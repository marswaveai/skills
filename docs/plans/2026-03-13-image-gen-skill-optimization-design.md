# Image-Gen Skill Optimization Design

**Date**: 2026-03-13
**Status**: Approved

## Background

The Labnana image generation API has been updated. The current skill has several inaccuracies against the new API spec:

1. Missing `model` parameter selection
2. `referenceImages` format is wrong — the API expects nested objects, not plain URL strings
3. `imageConfig` is optional but marked required in `api-image.md`
4. Aspect ratio list is incomplete (missing `2:3`, `3:2`, `21:9`, and flash-only ratios)

## Changes

### `shared/api-image.md`

- Add `model` field (optional, default `gemini-3-pro-image-preview`, alternative `gemini-3.1-flash-image-preview`)
- Fix `imageConfig` to be optional
- Expand aspect ratio table with all supported ratios, marking flash-only ones
- Fix `referenceImages` format from plain URL to nested object:
  ```json
  { "fileData": { "fileUri": "https://...", "mimeType": "image/png" } }
  ```
- Update curl example to include `model` field

### `SKILL.md` — Interaction Flow

**Step 2 (new): Model selection**

Ask user:
- `pro` — `gemini-3-pro-image-preview`, higher quality (default)
- `flash` — `gemini-3.1-flash-image-preview`, faster/cheaper, unlocks extreme aspect ratios

**Step 3: Resolution + Aspect Ratio**

Aspect ratio options are filtered by model:
- All models: `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `9:16`, `16:9`, `21:9`
- Flash only: `1:4`, `4:1`, `1:8`, `8:1`

**Step 4: Reference Images**

When collecting URLs, infer mimeType from URL suffix and construct the correct structure:
```json
{
  "fileData": {
    "fileUri": "https://example.com/photo.png",
    "mimeType": "image/png"
  }
}
```
Supported suffixes: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`

**API call** adds `model` field to request body.

## Files to Change

- `shared/api-image.md`
- `listenhub-image-gen/SKILL.md`
