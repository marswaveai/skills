# WeChat Article Template

## Pipeline Steps

### 1. Prepare Material

If input is a URL, material has already been extracted by the dispatcher (content-parser).
If input is text/topic, use it directly.

### 2. Generate Outline

Based on the material and `style.md`, generate:
- **Title**: Informative, attention-grabbing (see style.md § Title)
- **Sections**: 3-6 H2 sections, each with a brief description of what it covers
- **Estimated word count**: 1500-3000 characters

### 3. Write Article

Write the full article section by section, following `style.md` for tone, structure, and formatting.

Apply any user style directives from `.listenhub/creator/styles/wechat.md` (if exists) and `sessionStyle` (from style reference) on top of the baseline style. `sessionStyle` takes priority over the user style file, which takes priority over `style.md`.

Write the complete article as `article.md` in the output folder.

### 4. Plan Illustrations

After writing, identify illustration positions:
- **Cover image**: Always required. Placed at the top.
- **Section images**: One every 300-500 characters. Place after the paragraph that introduces a new concept or topic shift.
- For each image, write a detailed English prompt describing the desired illustration.
- All prompts should share a consistent visual style descriptor (e.g., "flat illustration, soft pastel colors, minimalist" or per user's imageStyle preference).

### 5. Generate Images

For each planned illustration, call the image generation API:

- **Model**: `gemini-3-pro-image-preview`
- **Cover**: aspect ratio `3:2`, size `2K`
- **Body images**: aspect ratio `3:2` or `16:9`, size `2K`
- **Timeout**: `--max-time 600` on curl (per `shared/api-image.md`)

Save images to `{output}/images/cover.jpg`, `{output}/images/section-1.jpg`, etc.

Generate sequentially. On 429: exponential backoff (wait 15s → 30s → 60s), retry up to 3 times. After 3 retries, skip and note in output summary.

### 6. Insert Image References

Update `article.md` to reference images with relative paths:

```
![cover](images/cover.jpg)
```

Insert at the planned positions.

### 7. Write meta.json

```json
{
  "title": "...",
  "summary": "One-sentence summary",
  "tags": ["tag1", "tag2", "tag3"],
  "platform": "wechat",
  "date": "YYYY-MM-DD",
  "imageCount": N,
  "wordCount": N
}
```

### Output Structure

```
{slug}-wechat/
├── article.md
├── images/
│   ├── cover.jpg
│   ├── section-1.jpg
│   └── section-N.jpg
└── meta.json
```
