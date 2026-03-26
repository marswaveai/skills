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

### 4. Select Illustration Preset

Choose an illustration preset from `presets/` for image generation.

**If user specified a preset** (e.g., "用水彩风格"): use that preset directly, skip the question below.

**If not specified**: MUST ask the user via AskUserQuestion. Before presenting the options, output a one-line hint: "配图风格可以随时换，先选一个开始吧". List all available presets with their Chinese labels (from frontmatter `label` field). Use the topic-matching table below only as a hint to put the most relevant option first (marked "Recommended"), but always let the user choose:

| Content Signals | Recommended Preset |
|---|---|
| 科技, 职场, 效率, 工具, 通用 | flat |
| 文化, 读书, 情感, 文艺, 哲学 | watercolor |
| 商业, 产品, 前沿科技, 城市 | photo-realistic |

The selected preset MUST be shown in the Step 4 confirmation summary.

After selection, read the full preset file to get the Prompt Fragment for use in Step 5.

### 5. Plan Illustrations

After writing, identify illustration positions:
- **Cover image**: Always required. Placed at the top.
- **Section images**: One every 300-500 characters. Place after the paragraph that introduces a new concept or topic shift.
- For each image, write a detailed English prompt that starts with the selected preset's **Prompt Fragment** as the visual foundation, then adds scene-specific details.
- All prompts inherit the preset's color palette and style — ensuring visual consistency across the article.

### 6. Generate Images

For each planned illustration, call the image generation API:

- **Model**: `gemini-3-pro-image-preview`
- **Cover**: aspect ratio `3:2`, size `2K`
- **Body images**: aspect ratio `3:2` or `16:9`, size `2K`
- **Timeout**: `--max-time 600` on curl (per `shared/api-image.md`)

Save images to `{output}/images/cover.jpg`, `{output}/images/section-1.jpg`, etc.

Generate sequentially. On 429: exponential backoff (wait 15s → 30s → 60s), retry up to 3 times. After 3 retries, skip and note in output summary.

### 7. Insert Image References

Update `article.md` to reference images with relative paths:

```
![cover](images/cover.jpg)
```

Insert at the planned positions.

### 8. Write meta.json

```json
{
  "title": "...",
  "summary": "One-sentence summary",
  "tags": ["tag1", "tag2", "tag3"],
  "platform": "wechat",
  "date": "YYYY-MM-DD",
  "preset": "flat",
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
