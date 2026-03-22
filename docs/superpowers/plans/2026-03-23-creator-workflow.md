# Creator Workflow Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a template-based creator workflow skill that orchestrates existing skills (content-parser, image-gen, tts, asr) to produce platform-specific content packages for WeChat, Xiaohongshu, and narration.

**Architecture:** A dispatcher SKILL.md reads user input, matches a template from `creator/templates/{platform}/`, executes the template's pipeline (writing + API calls), and outputs a content package to the current directory. Style evolution is stored per-platform in `config.json`.

**Tech Stack:** Claude Code skill (Markdown-driven), ListenHub API (curl + jq), coli CLI (local ASR)

**Spec:** `docs/superpowers/specs/2026-03-23-creator-workflow-design.md`

---

## File Map

| File | Responsibility | Action |
|------|---------------|--------|
| `creator/SKILL.md` | Dispatcher: input recognition, template selection, config, confirmation gate, pipeline execution, style evolution | Create |
| `creator/templates/wechat/template.md` | WeChat article pipeline: outline → write → image-gen → assemble | Create |
| `creator/templates/wechat/style.md` | WeChat writing style guide (authoritative, structured, deep) | Create |
| `creator/templates/xiaohongshu/template.md` | Xiaohongshu pipeline: cards + long text modes | Create |
| `creator/templates/xiaohongshu/style.md` | Xiaohongshu style guide (punchy, trendy, hook-first) | Create |
| `creator/templates/narration/template.md` | Narration pipeline: script writing + optional TTS | Create |
| `creator/templates/narration/style.md` | Narration style guide (conversational, rhythmic, oral) | Create |
| `creator/templates/ppt/template.md` | PPT placeholder (future, empty with TODO note) | Create |
| `creator/templates/ppt/style.md` | PPT style placeholder (future, empty with TODO note) | Create |
| `creator/shared` | Symlink → `../shared` | Create (symlink) |
| `README.md` | Add creator skill to the skill matrix table | Modify |

---

## Task 1: Scaffold directory structure and symlink

**Files:**
- Create: `creator/` directory tree
- Create: `creator/shared` → `../shared` symlink

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p creator/templates/wechat
mkdir -p creator/templates/xiaohongshu
mkdir -p creator/templates/narration
mkdir -p creator/templates/ppt  # Future placeholder per spec
```

- [ ] **Step 2: Create shared symlink**

```bash
cd creator && ln -s ../shared shared && cd ..
```

- [ ] **Step 3: Verify structure**

```bash
ls -la creator/shared  # Should show symlink → ../shared
ls creator/templates/   # Should show wechat/ xiaohongshu/ narration/ ppt/
```

- [ ] **Step 4: Commit**

```bash
git add creator/
git commit -m "feat(creator): scaffold directory structure and shared symlink"
```

---

## Task 2: Write `creator/SKILL.md` — the dispatcher

This is the core file. It must follow the exact patterns from `podcast/SKILL.md` (frontmatter, Hard Constraints, Step -1, Step 0, Interaction Flow, etc.) but adapted for the creator workflow.

**Files:**
- Create: `creator/SKILL.md`
- Reference: `podcast/SKILL.md` (structural pattern), `shared/config-pattern.md`, `shared/common-patterns.md`, `shared/authentication.md`

- [ ] **Step 1: Write the YAML frontmatter**

```yaml
---
name: creator
description: |
  Creator workflow — generate platform-ready content packages. Triggers on:
  "创作", "写公众号", "小红书", "口播", "creator", "content workflow",
  "帮我写一篇", "生成内容", "write an article", "create content".
metadata:
  openclaw:
    emoji: "✍️"
---
```

No `requires.env` — API key is checked conditionally at the confirmation gate.

- [ ] **Step 2: Write When to Use / When NOT to Use sections**

```markdown
## When to Use

- User wants a full content package for a specific platform (WeChat article, Xiaohongshu post, narration script)
- User says "帮我写篇公众号", "小红书图文", "口播稿", "create content"
- User provides a URL/text/topic and wants it turned into platform-ready content with images

## When NOT to Use

- User wants a single image without a content workflow → use image-gen directly
- User wants a single TTS audio → use tts directly
- User wants to transcribe audio → use asr directly
- User wants a podcast episode → use podcast directly
- User wants to extract content from a URL without further processing → use content-parser directly

Creator is for **multi-step content production** that combines writing + media generation into a platform-ready package.
```

- [ ] **Step 3: Write Purpose and Hard Constraints**

```markdown
## Purpose

Generate platform-specific content packages by orchestrating existing skills. Input: topic, URL, text, or audio/video file. Output: a folder with article/script, images, and metadata — ready to publish.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files in `shared/`
- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Never save files to `~/Downloads/` or `.listenhub/` — save content packages to the current working directory
- JSON parsing: use `jq` only (no python3, awk)

<HARD-GATE>
Language Adaptation: All UI text follows the user's input language. Chinese input → Chinese output. English input → English output. Mixed → follow dominant language.
</HARD-GATE>

<HARD-GATE>
Use AskUserQuestion for every multiple-choice step. One question at a time. Wait for the answer. After template is selected and input is understood, show a confirmation summary and wait for explicit approval before executing the pipeline.
</HARD-GATE>

<HARD-GATE>
API Key Check at Confirmation Gate: If the pipeline includes any remote API call (image-gen, content-parser, tts), check `LISTENHUB_API_KEY` before proceeding. If missing, run interactive setup from `shared/authentication.md`. Pure text-only pipelines (e.g., topic → narration script without TTS) can proceed without an API key.
</HARD-GATE>
```

- [ ] **Step 4: Write Step -1 and Step 0 (config)**

```markdown
## Step -1: API Key Check

Deferred. API key is checked at the confirmation gate (Step 4) only when the pipeline requires remote API calls. See Hard Constraints above.

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
` ``bash
mkdir -p ".listenhub/creator"
cat > ".listenhub/creator/config.json" << 'EOF'
{"outputMode":"download","language":null,"preferences":{"wechat":{"styleNotes":[],"history":[]},"xiaohongshu":{"styleNotes":[],"mode":"both","history":[]},"narration":{"styleNotes":[],"history":[]}}}
EOF
CONFIG_PATH=".listenhub/creator/config.json"
CONFIG=$(cat "$CONFIG_PATH")
` ``

Note: `outputMode` defaults to `"download"` (not the usual `"inline"`) because creator always produces multi-file output folders that must be saved to disk.

**If file exists** — read config silently and proceed:
` ``bash
CONFIG_PATH=".listenhub/creator/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/creator/config.json"
CONFIG=$(cat "$CONFIG_PATH")
` ``

### Setup Flow (user-initiated reconfigure only)

Only when user explicitly asks to reconfigure. Display current settings:
` ``
当前配置 (creator)：
  输出方式：{outputMode}
  小红书模式：{both / cards / long-text}
` ``

Ask:
1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.
2. **xiaohongshu.mode**: "小红书默认模式？"
   - "图文 + 长文（both）"
   - "仅图文卡片（cards）"
   - "仅长文（long-text）"
```

- [ ] **Step 5: Write Interaction Flow — Input Understanding**

```markdown
## Interaction Flow

### Step 1: Understand Input

The user provides input along with their request. Classify the input:

| Input Type | Detection | Auto Action |
|-----------|-----------|-------------|
| URL (web/article) | `http(s)://` prefix, not an audio/video URL | Will call content-parser (requires API key) |
| URL (audio/video) | Extension `.mp3/.mp4/.wav/.m4a/.webm` or domain is youtube.com/bilibili.com/douyin.com | Will download + call `coli asr` to transcribe |
| Local audio file | File path exists, extension is audio/video | Will call `coli asr` directly |
| Local text file | File path exists, extension is `.txt/.md/.json` | Read file content |
| Raw text | Multi-line or >50 chars, not a URL/path | Use directly as material |
| Topic/keywords | Short text (<50 chars), no URL/path pattern | AI writes from scratch |

**For URL (audio/video) inputs:**
1. Download to `/tmp/creator-{slug}.{ext}` using `curl -L -o`
2. Check `coli` is available: `which coli 2>/dev/null && echo yes || echo no`
3. If `coli` missing: inform user to install (`npm install -g @marswave/coli`), ask them to paste text instead
4. Transcribe: `coli asr -j --model sensevoice "/tmp/creator-{slug}.{ext}"`
5. Extract text from JSON result
6. Cleanup: `rm "/tmp/creator-{slug}.{ext}"`

**For URL (web/article) inputs:**
Content-parser will be called during pipeline execution (after confirmation).
```

- [ ] **Step 6: Write Interaction Flow — Template Matching**

```markdown
### Step 2: Template Matching

If the user specified a platform in their prompt, match directly:
- "公众号", "wechat", "微信" → wechat
- "小红书", "xiaohongshu", "xhs" → xiaohongshu
- "口播", "narration", "脚本" → narration

If no platform was specified, ask via AskUserQuestion:

Question: "Which content template?" / "用哪个创作模板？"
Options (adapt language to user's input):
- "WeChat article (公众号长文)" — Long-form article with AI illustrations
- "Xiaohongshu (小红书)" — Image cards + long text post
- "Narration script (口播稿)" — Spoken script with optional audio
```

- [ ] **Step 7: Write Interaction Flow — Style Learning Check**

```markdown
### Step 3: Style Learning Check (silent)

Before the confirmation gate, check if there's a previous generation to learn from:

` ``bash
PLATFORM="{selected platform}"
LAST_OUTPUT=$(echo "$CONFIG" | jq -r ".preferences.$PLATFORM.history[-1].output // empty")
if [ -n "$LAST_OUTPUT" ] && [ -d "$LAST_OUTPUT" ]; then
  # Check for .original/ snapshot
  # Determine the main content file based on platform
  case "$PLATFORM" in
    wechat) MAIN_FILE="article.md" ;;
    xiaohongshu) MAIN_FILE="long-text.md" ;;
    narration) MAIN_FILE="script.md" ;;
  esac
  ORIGINAL="$LAST_OUTPUT/.original/$MAIN_FILE"
  CURRENT="$LAST_OUTPUT/$MAIN_FILE"
  if [ -f "$ORIGINAL" ] && [ -f "$CURRENT" ]; then
    DIFF=$(diff "$ORIGINAL" "$CURRENT" 2>/dev/null)
    if [ -n "$DIFF" ]; then
      echo "USER_EDITED: $DIFF"
      # AI will analyze the diff and append to styleNotes
    fi
  fi
fi
` ``

If the user edited the previous output, analyze the diff:
> "The user edited the generated content. What style preferences can you infer? Express each as a short directive (e.g., '减少 emoji 使用', '段落更短')."

Append inferred notes to `preferences.{platform}.styleNotes` (max 10, FIFO).
```

- [ ] **Step 8: Write Interaction Flow — Confirmation Gate**

```markdown
### Step 4: Confirmation Gate

**Check API key** if the pipeline needs remote APIs:
- WeChat template always needs image-gen → requires API key
- Xiaohongshu cards mode needs image-gen → requires API key
- Xiaohongshu long-text only → no API key needed
- Narration without TTS → no API key needed
- Any URL input → needs content-parser → requires API key

If API key required and missing: run `shared/authentication.md` interactive setup.

**Show confirmation summary:**

` ``
准备生成内容：

  模板：{WeChat article / Xiaohongshu / Narration}
  输入：{topic description / URL / text excerpt...}
  输出目录：{slug}-{platform}/
  需要 API 调用：{content-parser, image-gen, ...}
  风格偏好：{N条自定义规则 / 使用默认风格}

确认开始？
` ``

Wait for explicit "yes" / confirmation before proceeding.
```

- [ ] **Step 9: Write Interaction Flow — Pipeline Execution**

```markdown
### Step 5: Execute Pipeline

Read the selected template file and execute:

` ``bash
# The template file path
TEMPLATE="creator/templates/$PLATFORM/template.md"
STYLE="creator/templates/$PLATFORM/style.md"
` ``

**For URL inputs — extract content first:**

` ``bash
# Submit content extraction
RESPONSE=$(curl -sS -X POST "https://api.marswave.ai/openapi/v1/content/extract" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d "{\"source\":{\"type\":\"url\",\"uri\":\"$INPUT_URL\"}}")
TASK_ID=$(echo "$RESPONSE" | jq -r '.data.taskId')
` ``

Then poll in background. Run this as a **separate Bash call** with `run_in_background: true` and `timeout: 600000` (per `shared/common-patterns.md`). Content-parser uses 5s intervals; 60 polls × 5s = 300s matches the standard 300s timeout budget:

` ``bash
# Run with: run_in_background: true, timeout: 600000
TASK_ID="<id>"
for i in $(seq 1 60); do
  RESULT=$(curl -sS "https://api.marswave.ai/openapi/v1/content/extract/$TASK_ID" \
    -H "Authorization: Bearer $LISTENHUB_API_KEY" \
    -H "X-Source: skills" 2>/dev/null)
  STATUS=$(echo "$RESULT" | tr -d '\000-\037\177' | jq -r '.data.status // "processing"')
  case "$STATUS" in
    completed) echo "$RESULT"; exit 0 ;;
    failed) echo "FAILED: $RESULT" >&2; exit 1 ;;
    *) sleep 5 ;;
  esac
done
echo "TIMEOUT" >&2; exit 2
` ``

Extract content: `MATERIAL=$(echo "$RESULT" | jq -r '.data.data.content')`

If extraction fails: tell user "URL 解析失败，你可以直接粘贴文字内容给我" and stop.

**Then follow the platform template** — read `template.md` and execute each step. The template specifies the exact writing instructions and API calls. See Tasks 3-5 for template contents.

**For image generation** (called by wechat and xiaohongshu templates):

` ``bash
RESPONSE=$(curl -sS -X POST "https://api.marswave.ai/openapi/v1/images/generation" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  --max-time 600 \
  -d '{
    "provider": "google",
    "model": "gemini-3-pro-image-preview",
    "prompt": "<generated prompt>",
    "imageConfig": {"imageSize": "2K", "aspectRatio": "<ratio>"}
  }')

BASE64_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].inlineData.data // .data')
# macOS uses -D, Linux uses -d (detect platform)
if [[ "$(uname)" == "Darwin" ]]; then
  echo "$BASE64_DATA" | base64 -D > "{output-path}/{filename}.jpg"
else
  echo "$BASE64_DATA" | base64 -d > "{output-path}/{filename}.jpg"
fi
` ``

On 429: wait 15s, retry up to 3 times. On failure after retries: skip this image, annotate in output summary.

Generate images **sequentially** (not parallel) to respect rate limits.

**For TTS** (called by narration template when user wants audio):

Use `@file` pattern per `shared/common-patterns.md` to handle special chars in script text:

` ``bash
# Write TTS request to temp file (handles quotes, newlines safely)
cat > /tmp/creator-tts-request.json << ENDJSON
{"input": $(echo "$SCRIPT_TEXT" | jq -Rs .), "voice": "$SPEAKER_ID"}
ENDJSON

curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d @/tmp/creator-tts-request.json \
  --output "{slug}-narration/audio.mp3"

rm /tmp/creator-tts-request.json
` ``
```

- [ ] **Step 10: Write Interaction Flow — Output Assembly & Preference Update**

```markdown
### Step 6: Assemble Output

Create the output folder and write all files:

` ``bash
SLUG="{topic-slug}"
OUTPUT_DIR="${SLUG}-{platform}"
# Dedup folder name
i=2; while [ -d "$OUTPUT_DIR" ]; do OUTPUT_DIR="${SLUG}-{platform}-${i}"; i=$((i+1)); done
mkdir -p "$OUTPUT_DIR"
` ``

Write content files per template spec. Then write `.original/` snapshot:

` ``bash
mkdir -p "$OUTPUT_DIR/.original"
cp "$OUTPUT_DIR/{main-file}" "$OUTPUT_DIR/.original/{main-file}"
` ``

Write `meta.json`:

` ``json
{
  "title": "...",
  "slug": "...",
  "platform": "wechat|xiaohongshu|narration",
  "date": "YYYY-MM-DD",
  "tags": ["...", "..."],
  "summary": "..."
}
` ``

### Step 7: Present Result

` ``
✅ 内容已生成！保存在 {OUTPUT_DIR}/

📄 {main files list}
🖼️ images/ — N 张配图（如有）
📋 meta.json — 标题、标签、摘要

你可以编辑 {main-file}，下次我会学习你的修改偏好。
` ``

(Adapt language to user's input language per Hard Constraints.)

### Step 8: Update Preferences

Record this generation in history:

` ``bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg platform "$PLATFORM" \
  --arg date "$(date +%Y-%m-%d)" \
  --arg output "$OUTPUT_DIR" \
  --arg topic "$TOPIC" \
  '.preferences[$platform].history = (.preferences[$platform].history + [{"date": $date, "output": $output, "topic": $topic}])[-5:]')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
` ``

Keep only the last 5 history entries per platform. Note: `output` stores the folder path (e.g., `ai-future-wechat/`), not a file path. The style learning check in Step 3 uses this to find `.original/` snapshots.

Note: `cardStyle` from the spec is deferred — not implemented in V1 config. Can be added later when card style customization is needed.
```

- [ ] **Step 11: Write Manual Tuning section**

```markdown
### Manual Style Tuning

If the user says "记住：{style directive}" or "remember: {style directive}":

1. Detect which platform it applies to (from context or ask)
2. Append to `preferences.{platform}.styleNotes`
3. Trim to max 10 entries (remove oldest)
4. Save config

If the user says "重置风格偏好" or "reset style":
1. Ask which platform (or all)
2. Set `preferences.{platform}.styleNotes` to `[]`
3. Save config
```

- [ ] **Step 12: Verify SKILL.md is complete and well-formed**

Check that SKILL.md has all required sections in the correct order:
1. YAML frontmatter
2. When to Use / When NOT to Use
3. Purpose
4. Hard Constraints (with 3 HARD-GATEs)
5. Step -1 / Step 0
6. Setup Flow
7. Interaction Flow (Steps 1-8)
8. Manual Style Tuning
9. API Reference (links to shared/ docs)
10. Composability

- [ ] **Step 13: Commit**

```bash
git add creator/SKILL.md
git commit -m "feat(creator): add dispatcher SKILL.md with full interaction flow"
```

---

## Task 3: Write WeChat template (`wechat/template.md` + `wechat/style.md`)

**Files:**
- Create: `creator/templates/wechat/template.md`
- Create: `creator/templates/wechat/style.md`
- Reference: `shared/api-image.md`, `shared/api-content-extract.md`

- [ ] **Step 1: Write `wechat/style.md`**

This is the WeChat writing style guide. The dispatcher and AI read this to shape the writing tone.

```markdown
# WeChat (公众号) Writing Style

## Tone
- Authoritative yet accessible — like a knowledgeable friend explaining something
- Professional but not stiff — avoid overly academic or bureaucratic language
- Confident assertions backed by specifics, not hedging

## Structure
- Title: Clear, informative, moderate clickbait OK (no excessive punctuation or all-caps)
- Opening: Hook the reader in the first 2 sentences — a surprising fact, a question, or a bold statement
- Body: Organized with clear H2/H3 headings, each section 2-4 paragraphs
- Closing: Actionable takeaway or thought-provoking conclusion
- Paragraphs: Max 3-4 lines each. Break long paragraphs aggressively.

## Image Strategy
- Cover image: Sets the tone, should be visually striking
- Section illustrations: One every 300-500 characters of body text
- Style consistency: All images in the same article should share a visual style (color palette, rendering style)
- Aspect ratio: 3:2 landscape for cover, 3:2 or 16:9 for body images

## Language
- Use the user's language (Chinese or English)
- For Chinese: prefer 书面语 but keep it readable, avoid 文言文
- Short sentences preferred. Vary rhythm between short punchy lines and longer explanatory ones.

## Formatting
- Use **bold** for key terms on first appearance
- Use > blockquotes for important quotes or callouts
- Use numbered lists for sequences, bullet lists for collections
- No emoji in body text (WeChat articles are more formal)
```

- [ ] **Step 2: Write `wechat/template.md`**

```markdown
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

Apply any user `styleNotes` from preferences on top of the baseline style.

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

Generate sequentially. On failure: wait 15s on 429, retry up to 3 times per `shared/api-image.md`. After 3 retries, skip and note in output summary.

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
├── .original/
│   └── article.md
└── meta.json
```
```

- [ ] **Step 3: Verify both files read well and are consistent**

Read both files and check:
- style.md tone directives match what template.md tells the AI to do
- Image aspect ratios are consistent between style.md and template.md
- No contradictions

- [ ] **Step 4: Commit**

```bash
git add creator/templates/wechat/
git commit -m "feat(creator): add WeChat template and style guide"
```

---

## Task 4: Write Xiaohongshu template (`xiaohongshu/template.md` + `xiaohongshu/style.md`)

**Files:**
- Create: `creator/templates/xiaohongshu/template.md`
- Create: `creator/templates/xiaohongshu/style.md`
- Reference: `shared/api-image.md`

- [ ] **Step 1: Write `xiaohongshu/style.md`**

```markdown
# Xiaohongshu (小红书) Writing Style

## Tone
- Light, energetic, personal — like sharing with a friend
- Trendy vocabulary, internet slang OK (but not forced)
- First-person perspective, direct address to reader ("你")
- Emotionally expressive — enthusiasm, surprise, empathy

## Structure (Long Text)
- Title: Must include a number or a hook ("5个方法", "绝绝子", "一定要看")
- Opening: 1-2 sentences max, hook immediately
- Body: Short paragraphs (1-3 sentences each), use line breaks liberally
- Emoji: Strategic, not excessive. 1-2 per paragraph max. Use as visual punctuation, not decoration.
- Tags: 3-5 relevant hashtags at the end

## Card Design (图文卡片)
- Cover card: Bold title text, eye-catching, ONE core message
- Content cards: One key point per card
  - Core quote or statement (large text, bold)
  - Brief explanation (2-3 lines, smaller text)
  - Clean layout, generous whitespace
- Typography: Bold sans-serif for headlines, readable body font
- Color: Consistent palette across all cards. Clean backgrounds (white, soft gradients, or contextual).
- 5-8 cards total (including cover)

## Image Prompt Guidelines for Cards
- Describe the card as a graphic design composition, not a photo
- Include: text content, layout direction, color palette, typography style
- Example prompt: "Minimalist card design with bold Chinese text '5个关键习惯' centered, subtitle '改变你的生活' below, clean white background with soft blue gradient accent, modern sans-serif typography"

## Language
- Primarily Chinese for Xiaohongshu audience
- English: casual social media style if user writes in English
- Mix of casual and informative
```

- [ ] **Step 2: Write `xiaohongshu/template.md`**

```markdown
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
- **For cards**: Distill into 5-8 key points. Each point becomes one card.
- **For long text**: Plan a hook-first short article (500-1000 chars).
- **Cover**: Design a cover card with attention-grabbing title.

### 4. Write Long Text (if mode includes long text)

Write `long-text.md` following `style.md` § Long Text structure.

Include:
- Hook title with number/emotional hook
- Short punchy paragraphs
- Strategic emoji
- 3-5 hashtags at the end

### 5. Design Card Prompts (if mode includes cards)

For each card (cover + 5-8 content cards):
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

Generate sequentially. On failure: wait 15s on 429, retry up to 3 times per `shared/api-image.md`. After 3 retries, skip and note.

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
├── .original/
│   └── long-text.md    (snapshot, only if long text was generated)
└── meta.json
```
```

- [ ] **Step 3: Verify consistency**

Check:
- Card aspect ratios match style.md guidance
- Prompt format in template.md produces good image-gen results
- No style contradictions

- [ ] **Step 4: Commit**

```bash
git add creator/templates/xiaohongshu/
git commit -m "feat(creator): add Xiaohongshu template and style guide"
```

---

## Task 5: Write Narration template (`narration/template.md` + `narration/style.md`)

**Files:**
- Create: `creator/templates/narration/template.md`
- Create: `creator/templates/narration/style.md`
- Reference: `shared/api-tts.md`, `shared/speaker-selection.md`

- [ ] **Step 1: Write `narration/style.md`**

```markdown
# Narration (口播) Writing Style

## Tone
- Conversational — as if talking to a friend or camera
- Natural rhythm — vary sentence length, use rhetorical questions
- Emotionally engaging — enthusiasm, curiosity, empathy
- Direct address: "你知道吗", "想象一下", "Let me tell you"

## Structure
- Hook opening: Start with a surprising fact, question, or bold claim (first 5 seconds matter)
- Body: Organized in 2-4 talking points, clear transitions
- Each point: Setup → Insight → Implication
- Closing: Clear takeaway or call to action
- Total length: 300-800 characters for short form, 800-2000 for long form

## Oral Language Patterns
- Use contractions and colloquialisms
- Short sentences dominate. Occasionally a longer one for emphasis.
- Pause markers: Use `...` for dramatic pauses, `——` for asides
- Filler-free: No "那个", "就是说", "basically", "you know" — keep it clean but natural
- Chinese: 口语化但不随意，避免书面语气词
- English: Casual but articulate, podcast-host energy

## Formatting
- One paragraph per talking point
- Line breaks between major beats
- No headers (this is a script, not an article)
- Optional: `[pause]` markers for TTS timing
- Optional: `[emphasis: word]` for stress guidance

## What to Avoid
- Dense information dumps — spread insights across beats
- Academic tone — this is spoken word, not an essay
- Lists longer than 3 items — convert to narrative
```

- [ ] **Step 2: Write `narration/template.md`**

```markdown
# Narration Script Template

## Pipeline Steps

### 1. Prepare Material

Same as other templates — material from dispatcher.

### 2. Generate Script

Write a spoken-word script following `style.md`:
- Hook opening
- 2-4 talking points with clear transitions
- Strong closing

Apply user `styleNotes` from preferences.

Save as `script.md` in the output folder.

### 3. TTS Audio (Optional)

TTS is offered only if:
- The pipeline requires it (user asked for audio)
- `LISTENHUB_API_KEY` is available

If generating audio:

1. Select speaker using built-in defaults from `shared/speaker-selection.md`:
   - Chinese: "原野" (`CN-Man-Beijing-V2`)
   - English: "Mars" (`cozy-man-english`)

2. Call TTS API (use `@file` pattern for safe text handling per `shared/common-patterns.md`):
` ``bash
cat > /tmp/creator-tts-request.json << ENDJSON
{"input": $(echo "$SCRIPT_TEXT" | jq -Rs .), "voice": "$SPEAKER_ID"}
ENDJSON

curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d @/tmp/creator-tts-request.json \
  --output "{output}/audio.mp3"

rm /tmp/creator-tts-request.json
` ``

Note: TTS max input is ~10,000 characters. For longer scripts, this is still well within limits for narration (typically 300-2000 chars).

If TTS fails: deliver script without audio, note in output summary.

### 4. Write meta.json

```json
{
  "title": "...",
  "platform": "narration",
  "date": "YYYY-MM-DD",
  "wordCount": N,
  "hasAudio": true/false,
  "speaker": "speaker-name"
}
```

### Output Structure

```
{slug}-narration/
├── script.md
├── audio.mp3          (if TTS was generated)
├── .original/
│   └── script.md
└── meta.json
```
```

- [ ] **Step 3: Verify TTS integration**

Check that:
- Speaker IDs match `shared/speaker-selection.md` built-in defaults
- curl command matches `shared/api-tts.md` exactly
- Max text length constraint is documented

- [ ] **Step 4: Commit**

```bash
git add creator/templates/narration/
git commit -m "feat(creator): add narration template and style guide"
```

---

## Task 6: Update README.md — add creator to skill matrix

**Files:**
- Modify: `README.md` (add creator row to the skills table)

- [ ] **Step 1: Read current README.md**

Read the file to find the skills table and understand the format.

- [ ] **Step 2: Add creator row to the skills table**

Add a new row after the existing skills:

```markdown
| ✍️ Creator | `creator` | 创作者工作流 — 一键生成公众号/小红书/口播内容 | "创作", "写公众号", "小红书", "口播", "creator" |
```

Match the exact column format of existing rows.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add creator skill to README skill matrix"
```

---

## Task 7: End-to-end verification

Manually trace through each template to verify correctness.

- [ ] **Step 1: Trace WeChat flow**

Walk through: user says "帮我根据这个链接写篇公众号 https://example.com"

1. SKILL.md Step 1: URL detected → content-parser route
2. Step 2: "公众号" keyword → wechat template
3. Step 3: Check style learning (first run, no history)
4. Step 4: Confirmation gate — URL input + wechat = needs API key → check
5. Step 5: Execute wechat/template.md pipeline
   - Content-parser: POST + poll (5s intervals)
   - Write article from extracted content
   - Plan 3-5 images
   - Generate each image (image-gen API, sequential)
   - Insert image refs
   - Write meta.json
6. Step 6: Assemble output folder
7. Step 7: Present result
8. Step 8: Update history

Verify: all API endpoints correct, all curl commands match `shared/api-*.md`, all paths consistent.

- [ ] **Step 2: Trace Xiaohongshu flow**

Walk through: user says "把这段文字做成小红书" + pastes text

1. Raw text input, xiaohongshu template
2. No API key needed for long-text only, but default mode is "both" → needs image-gen → needs API key
3. Confirmation gate checks API key
4. Generate cards (5-8 prompts → 5-8 image-gen calls) + long text
5. Output folder with cards/ and long-text.md

- [ ] **Step 3: Trace Narration flow (no TTS)**

Walk through: user says "帮我写个口播稿，主题是AI"

1. Topic input, narration template
2. No TTS requested → no API key needed
3. Confirmation gate: pure text pipeline, no API check
4. Generate script.md
5. Output folder with script.md only

- [ ] **Step 4: Trace audio input flow**

Walk through: user provides "meeting.mp3"

1. Local audio file detected
2. Check `coli` available
3. Transcribe with `coli asr`
4. Use transcript as material
5. Template selection → user picks one
6. Pipeline continues with text material

- [ ] **Step 5: Fix any issues found during tracing**

If any API calls, paths, or logic don't align, fix them in the relevant files.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "fix(creator): address issues found during end-to-end verification"
```

(Only if changes were made.)
