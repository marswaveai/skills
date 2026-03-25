# Xiaohongshu Template

## Pipeline Steps

### 1. Prepare Material

Same as WeChat — material from dispatcher (URL extraction or direct input).

### 2. Determine Mode

Read `preferences.xiaohongshu.mode` from config:
- `"both"` (default): Generate cards AND long text
- `"cards"`: Cards only
- `"long-text"`: Long text only

### 3. Generate Content Plan

Based on material:
- **For cards**: Distill into 4-7 key points. Each point becomes one card (plus cover = 5-8 cards total).
- **For long text**: Plan a hook-first short article (500-1000 chars).
- **Cover**: Design a cover card with attention-grabbing title.

### 4. Write Long Text (if mode includes long text)

Write `long-text.md` following `style.md` § Long Text structure. Apply any user style directives from `.listenhub/creator/styles/xiaohongshu.md` (if exists) and `sessionStyle` (from style reference) on top of the baseline style. `sessionStyle` takes priority over the user style file, which takes priority over `style.md`.

Include:
- Hook title with number/emotional hook
- Short punchy paragraphs
- Strategic emoji
- 3-5 hashtags at the end

### 5. Design Card Prompts (if mode includes cards)

For each card (cover + 4-7 content cards, 5-8 total per style.md). Apply any user style directives from `.listenhub/creator/styles/xiaohongshu.md` (if exists) and `sessionStyle` to card tone and formatting choices:
1. Write the text content that appears ON the card (Chinese, concise)
2. Write an English image generation prompt that describes the card as a designed graphic:
   - Include the exact text to appear on the card
   - Specify layout, typography style, color palette
   - Request "graphic design", "card layout", "social media post design"
3. Use consistent style descriptors across all cards

Save all prompts to `{output}/cards/prompts.json`:
```json
[
  {
    "page": 1,
    "type": "cover",
    "text": "5个改变生活的习惯",
    "prompt": "Modern social media card design..."
  },
  {
    "page": 2,
    "type": "content",
    "text": "习惯一：早起",
    "subtitle": "每天早起30分钟，你会发现...",
    "prompt": "Clean card design with Chinese text..."
  }
]
```

### 6. Generate Card Images (if mode includes cards)

For each prompt in `prompts.json`:
- **Model**: `gemini-3-pro-image-preview`
- **Aspect ratio**: `3:4` (portrait, standard Xiaohongshu card)
- **Size**: `2K`
- **Timeout**: `--max-time 600` on curl (per `shared/api-image.md`)

Save to `{output}/cards/01-cover.jpg`, `{output}/cards/02-page.jpg`, etc.

Generate sequentially. On 429: exponential backoff (wait 15s → 30s → 60s), retry up to 3 times. After 3 retries, skip and note.

### 7. Write meta.json

```json
{
  "title": "...",
  "tags": ["#tag1", "#tag2", "#tag3"],
  "platform": "xiaohongshu",
  "date": "YYYY-MM-DD",
  "modes": ["cards", "long-text"],
  "cardCount": N
}
```

### Output Structure

```
{slug}-xiaohongshu/
├── cards/              (if mode includes cards)
│   ├── 01-cover.jpg
│   ├── 02-page.jpg
│   ├── ...
│   └── prompts.json
├── long-text.md        (if mode includes long text)
└── meta.json
```
