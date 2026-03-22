# Creator Workflow Skill — Design Spec

## Overview

A template-based creator workflow skill that orchestrates existing skills (content-parser, image-gen, tts, asr) to produce platform-specific content. Users provide a topic, URL, text, or audio/video file, select a platform template, and get a fully assembled content package — automatically, with no mid-process interruptions.

## Target Platforms

| Platform | Output | Status |
|----------|--------|--------|
| WeChat (公众号) | Long-form article with AI-generated illustrations | V1 |
| Xiaohongshu (小红书) | Image cards (图文) + long text, both modes | V1 |
| Narration (口播) | Spoken script + optional TTS audio | V1 |
| PPT | Slide deck | Future |

## Architecture: Template Registry (方案 B)

The skill consists of a lightweight dispatcher (SKILL.md) and self-contained template folders. Adding a new platform = adding a new folder. The dispatcher does not need modification.

### Directory Structure

```
creator/
├── SKILL.md                    # Dispatcher: input recognition, template selection,
│                               #   pipeline execution, preference evolution
├── shared -> ../shared         # Reuse existing infrastructure
├── references/
│   └── skill-discovery.md      # How to detect/install other skills
│
└── templates/
    ├── wechat/
    │   ├── template.md         # Workflow steps, output format, skill calls
    │   └── style.md            # WeChat writing style guide
    │
    ├── xiaohongshu/
    │   ├── template.md         # Two sub-modes (cards / long text)
    │   └── style.md            # Xiaohongshu writing style guide
    │
    ├── narration/
    │   ├── template.md         # Script generation workflow
    │   └── style.md            # Spoken-word style guide
    │
    └── ppt/                    # Future placeholder
        ├── template.md
        └── style.md
```

## Dispatcher Logic (SKILL.md)

The dispatcher handles four responsibilities: **Input Understanding → Template Matching → Pipeline Execution → Preference Update**.

### 1. Input Understanding

| Input Type | Detection | Auto Action |
|-----------|-----------|-------------|
| URL (web/article) | `http(s)://` prefix | Call content-parser to extract content |
| URL (audio/video) | File extension `.mp3/.mp4/.wav` or known video platform | Call asr to transcribe → text material |
| Local file | File path exists on disk | Read file / call asr for audio |
| Raw text | Not a URL, not a file path | Use directly as material |
| Topic/keywords | Short text, no explicit material | AI writes from scratch |

### 2. Template Matching

- If user specifies platform in their prompt (e.g., "写篇公众号"), match directly
- Otherwise, present template selection via AskUserQuestion:
  ```
  你想用哪个创作模板？
  (1) 公众号长文
  (2) 小红书图文 + 长文
  (3) 口播稿
  ```

### 3. Pipeline Execution

The dispatcher reads `templates/{name}/template.md` and executes steps sequentially. Each step is one of:

- **Internal operation**: AI writing (applying style.md + user preferences)
- **Skill call**: Call image-gen, tts, content-parser, asr APIs (referencing shared/ docs)
- **Output operation**: Write files, assemble content package

Execution is fully automatic — no mid-process user interruptions.

### 4. Preference Update

After execution, record output path in history. On next run, compare previous output with user's edits to learn style adjustments. See "Style Evolution System" section below.

## Template Designs

### WeChat (公众号)

**Workflow**:
1. Acquire material (parse input → text content)
2. Generate article outline (title + section headings)
3. Write body section by section (apply style.md)
4. Identify illustration positions (one every 300-500 chars, cover image required)
5. Call image-gen for each illustration (unified style, respecting user preferences)
6. Assemble output

**Output structure**:
```
{slug}-wechat/
├── article.md          # Body text, images referenced via relative paths
├── images/
│   ├── cover.jpg       # Cover image
│   ├── section-1.jpg   # Section illustrations
│   └── section-2.jpg
└── meta.json           # Title, summary, tags
```

**Style baseline** (style.md): Authoritative tone, structured with clear headings, in-depth analysis, professional yet accessible. Paragraphs 3-4 lines max.

### Xiaohongshu (小红书)

**Two sub-modes, both output simultaneously**:

**Card mode (图文)**:
1. Acquire material
2. Distill content into 5-8 key points/pages
3. Design each page: core quote + brief explanation + visual theme description
4. Call image-gen to generate integrated text-on-image cards for each page
5. Generate cover card (attention-grabbing title)

**Long text mode**:
1. Rewrite same material in Xiaohongshu long-text style
2. Add title, tags, emoji accents

**Output structure**:
```
{slug}-xiaohongshu/
├── cards/
│   ├── 01-cover.jpg      # Cover card
│   ├── 02-page.jpg       # Content card 1
│   ├── 03-page.jpg       # ...
│   └── prompts.json      # Prompt record per card (for regeneration)
├── long-text.md           # Long text version
└── meta.json              # Title, tags, topics
```

**Style baseline** (style.md): Light, punchy, trendy. Short sentences, strategic emoji, numbers in titles, hook-first structure. Cards: bold typography, clean layout, one core message per page.

### Narration (口播)

**Workflow**:
1. Acquire material
2. Generate script outline
3. Write spoken script (apply style.md: conversational, rhythmic, with pause markers)
4. (Optional) Call tts to generate voiceover audio

**Output structure**:
```
{slug}-narration/
├── script.md             # Spoken script
├── audio.mp3             # Voiceover (if generated)
└── meta.json
```

**Style baseline** (style.md): Conversational, rhythmic flow, natural pauses (marked with `...` or `——`), emotional words, direct address ("你知道吗"), avoid written-language structures.

## Skill Orchestration

### Dependency Detection

Before calling another skill's API, check prerequisites:
- `LISTENHUB_API_KEY` env var for content-parser, image-gen, tts, podcast, explainer
- `coli` command for asr

If unavailable: output a one-line notice with install command suggestion. Do not block the entire workflow — skip the dependent step, deliver what's possible, annotate what was skipped.

### Call Method

Creator does NOT nest-trigger other skills. It directly calls their APIs using `curl`, referencing `shared/api-*.md` documentation. The template.md files specify which API endpoints to call and how to use the results.

### Input → Skill Routing

| Input Feature | Skill Called | Purpose |
|--------------|-------------|---------|
| `http(s)://` non-audio/video | content-parser | Extract web content |
| `.mp3/.mp4/.wav` URL or local file | asr | Transcribe to text |
| Template needs illustrations | image-gen | Generate AI images |
| Narration template with voiceover | tts | Text to speech |
| Xiaohongshu card mode | image-gen | Generate text-on-image cards |

## Style Evolution System

### Storage

```
.listenhub/creator/
├── config.json           # Base config (outputMode, language, etc.)
└── preferences.json      # Style preferences (per-platform)
```

### Evolution Mechanisms

**Automatic learning**:
- Each generation records output path in `preferences.json` history
- On next run, compare previous output with current file state (user edits)
- Extract style tendencies from diff (e.g., "user removed all emoji" → record "减少 emoji 使用")
- `styleNotes` array keeps latest 10 entries, newer replaces older

**Manual tuning**:
- User can say "记住：我的公众号不要用问句结尾" → append to platform's styleNotes
- User can say "重置风格偏好" → clear styleNotes for that platform

**Style application order**:
1. `style.md` — platform baseline style (shared across all users)
2. `preferences.json` → `styleNotes` — user's personal adjustments (additive)

### preferences.json Schema

```json
{
  "wechat": {
    "styleNotes": [
      "段落保持在3-4行以内",
      "配图偏好：科技感、扁平插画"
    ],
    "history": [
      {
        "date": "2026-03-22",
        "output": "ai-future-wechat/article.md",
        "topic": "AI的未来"
      }
    ]
  },
  "xiaohongshu": {
    "styleNotes": ["标题必须带数字", "少用emoji"],
    "cardStyle": "简约白底",
    "history": []
  },
  "narration": {
    "styleNotes": [],
    "history": []
  }
}
```

## Trigger & Interaction

### SKILL.md Frontmatter

```yaml
name: creator
description: 创作者工作流 - 一键生成公众号/小红书/口播等平台内容
metadata:
  openclaw:
    emoji: "✍️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
```

**Trigger keywords**: `"创作"`, `"写公众号"`, `"小红书"`, `"口播"`, `"creator"`, `"content workflow"`, `"帮我写一篇"`, `"生成内容"`

### Interaction Flow Example

```
User: 帮我根据这个链接写篇公众号 https://example.com/article

Creator:
  1. Identify: URL input + WeChat template specified ✓
  2. [Silent] Read config + preferences
  3. [Silent] Call content-parser to parse URL → text material
  4. [Silent] Read wechat/template.md + wechat/style.md + user preferences
  5. [Silent] Generate outline → write body
  6. [Silent] Identify illustration positions → call image-gen for 3-5 images
  7. Output:
     ✅ 文章已生成！保存在 ai-developments-wechat/

     📄 article.md — 正文（约 2000 字）
     🖼️ images/ — 4 张配图（含封面）
     📋 meta.json — 标题、摘要、标签

     你可以编辑 article.md，下次我会学习你的修改偏好。
```

### Error Handling

- content-parser fails → "URL 解析失败，你可以直接粘贴文字内容给我"
- image-gen fails → Skip illustrations, deliver article, annotate which images were not generated
- API key missing → Follow standard authentication flow (shared/authentication.md)
- asr/tts unavailable → Skip audio step, deliver text output, suggest installing the skill

## Scope Boundaries

**V1 includes**: WeChat, Xiaohongshu (cards + long text), Narration templates. Style evolution. Skill orchestration with content-parser, image-gen, tts, asr.

**V1 excludes**: PPT template (future). Custom user-defined templates. Publishing/posting to platforms. Analytics or A/B testing.

## Config Schema

```json
{
  "outputMode": "download",
  "language": null
}
```

Follows `shared/config-pattern.md` conventions. Zero-question boot on first run.
