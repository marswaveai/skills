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

## Hard Constraints

- **No shell scripts**: Construct all API calls with `curl` referencing `shared/api-*.md`
- **Always read config first**: Follow `shared/config-pattern.md` Step -1 and Step 0 before any interaction
- **Language adaptation** `<HARD-GATE>`: All UI text (questions, confirmations, errors, output summaries) follows the user's input language. Chinese input → Chinese output.
- **AskUserQuestion for choices** `<HARD-GATE>`: Use AskUserQuestion for all multiple-choice parameters. One question at a time, wait for answer.
- **Confirmation before API calls** `<HARD-GATE>`: After input is understood and template is selected, show a brief summary of what will be generated and wait for user confirmation before executing the pipeline.
- **Artifact output**: Save to current working directory, never `~/Downloads/` or `.listenhub/`
- **Dedup filenames**: Use `-2`, `-3` pattern if file already exists
- **Slug naming**: Follow `shared/config-pattern.md` slug generation rules
- **JSON parsing**: Use `jq` only (no python3, awk)
- **Polling**: Follow `shared/common-patterns.md` async polling pattern with `run_in_background: true`

## When NOT to Use

- User wants a single image without a content workflow → use image-gen directly
- User wants a single TTS audio → use tts directly
- User wants to transcribe audio → use asr directly
- User wants a podcast episode → use podcast directly
- User wants to extract content from a URL without further processing → use content-parser directly

Creator is for **multi-step content production** that combines writing + media generation into a platform-ready package.

## Architecture: Template Registry (方案 B)

The skill consists of a lightweight dispatcher (SKILL.md) and self-contained template folders. Adding a new platform = adding a new folder. The dispatcher does not need modification.

### Directory Structure

```
creator/
├── SKILL.md                    # Dispatcher: input recognition, template selection,
│                               #   pipeline execution, preference evolution
├── shared -> ../shared         # Reuse existing infrastructure
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
    └── ppt/                    # Future placeholder (not created in V1)
        ├── template.md
        └── style.md
```

## Dispatcher Logic (SKILL.md)

The dispatcher handles four responsibilities: **Input Understanding → Template Matching → Pipeline Execution → Preference Update**.

### 1. Input Understanding

| Input Type | Detection | Auto Action |
|-----------|-----------|-------------|
| URL (web/article) | `http(s)://` prefix | Call content-parser to extract content |
| URL (audio/video) | File extension `.mp3/.mp4/.wav`, or known video platforms (youtube.com, bilibili.com, douyin.com) | Call asr to transcribe → text material |
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

**Image generation calls**: When a template needs multiple images (e.g., WeChat article with 3-5 illustrations), generate them sequentially. If some fail, deliver what succeeded and annotate failures in the output summary.

After all parameters are collected and input is processed, execution is automatic — no mid-step interruptions. (The confirmation gate happens before execution starts, per Hard Constraints.)

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
├── .original/
│   └── article.md      # Snapshot for style learning diff
└── meta.json           # Title, summary, tags
```

**Style baseline** (style.md): Authoritative tone, structured with clear headings, in-depth analysis, professional yet accessible. Paragraphs 3-4 lines max.

### Xiaohongshu (小红书)

**Two sub-modes (default: both; user can choose one via preferences)**:

**Card mode (图文)**:
1. Acquire material
2. Distill content into 5-8 key points/pages
3. Design each page: core quote + brief explanation + visual theme description
4. Call image-gen to generate integrated text-on-image cards for each page
   - **Note**: AI image generation models may render Chinese text imperfectly. Generated cards may need manual text adjustment. Prompts should keep on-card text short (under 10 characters per line) for best results.
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
├── .original/
│   └── long-text.md      # Snapshot for style learning diff
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
├── .original/
│   └── script.md         # Snapshot for style learning diff
└── meta.json
```

**Style baseline** (style.md): Conversational, rhythmic flow, natural pauses (marked with `...` or `——`), emotional words, direct address ("你知道吗"), avoid written-language structures.

## Skill Orchestration

### Dependency Detection & API Key Strategy

**API Key requirement depends on whether the pipeline calls remote APIs**:

| Scenario | Needs `LISTENHUB_API_KEY`? | Reason |
|----------|--------------------------|--------|
| Topic → narration script (text only) | No | Pure AI writing, no API calls |
| Topic → WeChat article with images | **Yes** | image-gen requires API |
| URL → any template | **Yes** | content-parser requires API |
| Audio/video → any template | No (ASR is local) | But if template then needs images/TTS, yes |

**Rule**: Check at the confirmation gate (before pipeline execution) whether any step in the selected template's pipeline requires `LISTENHUB_API_KEY`. If yes and the key is missing, run the interactive setup from `shared/authentication.md` — do NOT skip and do NOT proceed without it. Image generation and content extraction are core to the output quality and should not be silently skipped.

**ASR is the exception**: It uses the local `coli` CLI tool (see `asr/SKILL.md`), not a remote API. If `coli` is unavailable, suggest installation and skip the transcription step.

### Audio/Video Input Handling

When the input is an audio/video URL (not a local file):

1. Download the file to `/tmp/creator-{slug}.{ext}` using `curl -L -o`
2. Call `coli` to transcribe the downloaded file
3. Delete the downloaded file after transcription: `rm /tmp/creator-{slug}.{ext}`
4. Use the transcript as text material for the selected template

For local audio/video files, call `coli` directly on the file path (no download/cleanup needed).

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

Preferences are stored alongside config in `.listenhub/creator/config.json` under a `preferences` key, following the single-config-file convention from `shared/config-pattern.md`.

## Config Schema

### Step -1: API Key Check

Deferred until the confirmation gate. If the selected template's pipeline includes any remote API call (image-gen, content-parser, tts), check `LISTENHUB_API_KEY` at that point. If missing, run interactive setup from `shared/authentication.md`. Pure text-only pipelines (e.g., topic → narration script without TTS) can proceed without an API key.

### Step 0: Config Setup (Zero-Question Boot)

On first run, silently create `.listenhub/creator/config.json` with defaults:

```json
{
  "outputMode": "download",
  "language": null,
  "preferences": {
    "wechat": { "styleNotes": [], "history": [] },
    "xiaohongshu": { "styleNotes": [], "mode": "both", "history": [] },
    "narration": { "styleNotes": [], "defaultSpeaker": null, "history": [] }
  }
}
```

Follows `shared/config-pattern.md` conventions.

### Full Config Schema

```json
{
  "outputMode": "download",
  "language": null,
  "preferences": {
    "wechat": {
      "styleNotes": [
        "段落保持在3-4行以内",
        "配图偏好：科技感、扁平插画"
      ],
      "history": [
        {
          "date": "2026-03-22",
          "output": "ai-future-wechat/",
          "topic": "AI的未来"
        }
      ]
    },
    "xiaohongshu": {
      "styleNotes": ["标题必须带数字", "少用emoji"],
      "mode": "both",
      "cardStyle": "简约白底",
      "history": []
    },
    "narration": {
      "styleNotes": [],
      "defaultSpeaker": null,
      "history": []
    }
  }
}
```

- `mode` (xiaohongshu only): `"both"` | `"cards"` | `"long-text"` — which sub-mode to generate
- `styleNotes`: Max 10 entries per platform, newest replaces oldest
- `defaultSpeaker` (narration only): Speaker ID for TTS (e.g., `CN-Man-Beijing-V2`), `null` uses built-in defaults
- `history`: Last 5 generation records for automatic learning

### Evolution Mechanisms

**Automatic learning**:
- Each generation saves a snapshot of the main output file alongside the output. For example, `{slug}-wechat/.original/article.md` is an exact copy of the generated `article.md` before any user edits.
- Each generation records output folder path in `config.json` → `preferences.{platform}.history` (relative to the CWD where creator was invoked)
- **CWD dependency**: Style learning only works when the user runs creator from the same working directory as the previous generation. If the previous output folder is not found at the recorded relative path, style learning is silently skipped.
- On next run, if `.original/article.md` exists and differs from the current `article.md`, compute the diff
- Present the diff to the AI with the prompt: "The user edited the generated content. What style preferences can you infer? Express each as a short directive (e.g., '减少 emoji 使用', '段落更短')."
- Append inferred notes to `styleNotes`; array keeps latest 10 entries, newer replaces older
- If the file was not modified (or `.original/` doesn't exist), skip learning

**Manual tuning**:
- User can say "记住：我的公众号不要用问句结尾" → append to platform's styleNotes
- User can say "重置风格偏好" → clear styleNotes for that platform

**Style application order**:
1. `style.md` — platform baseline style (shared across all users)
2. `config.json` → `preferences.{platform}.styleNotes` — user's personal adjustments (additive)

## Trigger & Interaction

### SKILL.md Frontmatter

```yaml
name: creator
description: 创作者工作流 - 一键生成公众号/小红书/口播等平台内容
metadata:
  openclaw:
    emoji: "✍️"
    # No hard env requirement — API key is checked at confirmation gate
    # only when the pipeline includes remote API calls (image-gen, content-parser, tts)
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
- image-gen 429 → Exponential backoff (15s → 30s → 60s), retry up to 3 times; if still fails, deliver article without that image, annotate which images were not generated
- API key missing at confirmation gate → Run interactive setup, do not proceed without it
- `coli` unavailable → Skip transcription step, ask user to paste text instead or install coli
- tts fails → Deliver script without audio, note that TTS generation failed

## Scope Boundaries

**V1 includes**: WeChat, Xiaohongshu (cards + long text), Narration templates. Style evolution. Skill orchestration with content-parser, image-gen, tts, asr.

**V1 excludes**: PPT template (future). Custom user-defined templates. Publishing/posting to platforms. Analytics or A/B testing.
