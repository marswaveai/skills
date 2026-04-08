# Skills CLI Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all ListenHub skills from curl/API to CLI commands, add slides and music skills, and clean up shared/ docs.

**Architecture:** Replace curl + API Key + polling loops with `listenhub` CLI commands that handle auth (OAuth), polling, and JSON output natively. New shared/ CLI docs replace old API docs. content-parser stays curl-based with inlined API info.

**Tech Stack:** Markdown (SKILL.md files), ListenHub CLI (`@marswave/listenhub-cli`), bash (for CLI invocations in skill workflows)

**Spec:** `docs/specs/cli-migration.md`

---

## File Map

### New files

| File | Responsibility |
|------|---------------|
| `shared/cli-authentication.md` | CLI install check + `listenhub auth login/status` |
| `shared/cli-patterns.md` | CLI execution: `--json`, `--no-wait`, `--timeout`, error handling |
| `shared/cli-speakers.md` | `listenhub speakers list --json` speaker query |
| `slides/SKILL.md` | Slides generation skill (storybook mode=slides) |
| `music/SKILL.md` | Music generation + cover skill |
| `listenhub-cli/SKILL.md` | Umbrella router skill |

### Modified files

| File | Change |
|------|--------|
| `podcast/SKILL.md` | curl → CLI, remove two-step, remove API Key |
| `tts/SKILL.md` | curl → CLI, remove API Key |
| `explainer/SKILL.md` | curl → CLI, remove API Key |
| `image-gen/SKILL.md` | curl → CLI, remove API Key |
| `content-parser/SKILL.md` | Inline API docs (auth, endpoints, polling) |
| `listenhub/SKILL.md` | Undeprecat, match listenhub-cli content |
| `shared/speaker-selection.md` | Speaker fetch via CLI instead of curl |
| `shared/config-pattern.md` | Remove API Key Check section, add CLI Auth Check |
| `creator/SKILL.md` | Update shared/ references |
| `creator/templates/narration/template.md` | Update speaker-selection + TTS references |
| `creator/templates/wechat/template.md` | Update api-image.md reference |
| `creator/templates/xiaohongshu/template.md` | Update api-image.md reference |
| `README.md` | Add slides, music, CLI install, OAuth auth |
| `README.zh.md` | Same changes in Chinese |

### Deleted files

| File | Reason |
|------|--------|
| `shared/api-podcast.md` | Replaced by CLI |
| `shared/api-tts.md` | Replaced by CLI |
| `shared/api-image.md` | Replaced by CLI |
| `shared/api-storybook.md` | Replaced by CLI |
| `shared/api-content-extract.md` | Inlined into content-parser |
| `shared/api-speakers.md` | Replaced by CLI |
| `shared/authentication.md` | Replaced by cli-authentication.md |
| `shared/common-patterns.md` | Replaced by cli-patterns.md |
| `listenhub/DEPRECATED.md` | No longer deprecated |

---

## Task 1: Create shared CLI docs

**Files:**
- Create: `shared/cli-authentication.md`
- Create: `shared/cli-patterns.md`
- Create: `shared/cli-speakers.md`

- [ ] **Step 1: Write `shared/cli-authentication.md`**

```markdown
# CLI Authentication

## Prerequisites

ListenHub CLI must be installed:

```bash
npm install -g @marswave/listenhub-cli
```

Requires Node.js >= 20.

## Auth Check

Run this **before Step 0** in every CLI-based skill.

```bash
if ! command -v listenhub &>/dev/null; then
  echo "MISSING_CLI"
else
  AUTH=$(listenhub auth status --json 2>/dev/null)
  echo "$AUTH" | jq -r '.authenticated // false'
fi
```

**If `true`**: proceed to Step 0 silently.

**If `false` or `MISSING_CLI`**: run the interactive setup below.

### Interactive Setup

1. If CLI not installed, tell the user:
   > ListenHub CLI 未安装。请运行：
   > ```bash
   > npm install -g @marswave/listenhub-cli
   > ```

2. If CLI installed but not logged in, tell the user:
   > 请先登录 ListenHub：
   > ```bash
   > listenhub auth login
   > ```
   > 浏览器会自动打开授权页面。

3. Wait for the user to confirm login is complete.

4. Verify: `listenhub auth status --json` → `authenticated: true`

5. **Continue** — proceed to Step 0 and the skill's Interaction Flow.

## Security Notes

- Credentials stored at `~/.config/listenhub/credentials.json` (mode 0600)
- Tokens auto-refresh before expiry
- Never log or display tokens in output
```

- [ ] **Step 2: Write `shared/cli-patterns.md`**

```markdown
# CLI Patterns

Reusable patterns for all skills that use the `listenhub` CLI.

<HARD-GATE>
**Language Adaptation**: Always respond in the user's language. Chinese input → Chinese output. English input → English output. Mixed → follow dominant language. This applies to all UI text, questions, confirmations, and error messages.
</HARD-GATE>

## Command Execution

All generation commands follow the same pattern:

```bash
listenhub <command> create [options] --json
```

The CLI handles polling internally — it submits the task and waits until completion by default. No background polling loops needed.

### Synchronous (default)

```bash
RESULT=$(listenhub podcast create --query "topic" --mode quick --lang zh --json)
```

The command blocks until the task completes, then prints the JSON result to stdout. Use this for most cases.

### Asynchronous (--no-wait)

```bash
RESULT=$(listenhub podcast create --query "topic" --no-wait --json)
ID=$(echo "$RESULT" | jq -r '.episodeId')
# Later check status:
listenhub creation get "$ID" --json
```

Use `--no-wait` only when you need to do work between submission and completion.

### Timeout

Each command has a default timeout. Override with `--timeout <seconds>`:

| Command | Default timeout |
|---------|----------------|
| `podcast create` | 300s |
| `tts create` | 300s |
| `explainer create` | 300s |
| `slides create` | 300s |
| `image create` | 120s |
| `music generate` | 600s |
| `music cover` | 600s |

### Background Execution

For long-running commands (music especially), use Bash `run_in_background: true` with `timeout: 660000`:

```bash
listenhub music generate --prompt "..." --style "..." --json
```

You will be notified when the command completes.

## JSON Output

All commands with `--json` output structured JSON. Parse with `jq`:

```bash
RESULT=$(listenhub podcast create --query "topic" --json)
AUDIO_URL=$(echo "$RESULT" | jq -r '.audioUrl')
DURATION=$(echo "$RESULT" | jq -r '.audioDuration')
CREDITS=$(echo "$RESULT" | jq -r '.credits')
```

## Error Handling

CLI exits with non-zero codes on failure:

| Exit code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | General error (bad params, API error) |
| 2 | Auth error (not logged in, token expired) |
| 3 | Timeout |

On error with `--json`, stderr contains the error message. Handle:

```bash
RESULT=$(listenhub podcast create --query "topic" --json 2>/tmp/lh-err.txt)
if [ $? -ne 0 ]; then
  ERROR=$(cat /tmp/lh-err.txt)
  # Report error to user
fi
```

### Common Errors

| Error | Action |
|-------|--------|
| "Not authenticated" | Run `listenhub auth login` |
| "Insufficient credits" | Inform user to recharge at listenhub.ai |
| "Rate limited" | CLI retries automatically (2 retries on 429) |
| Timeout | Increase `--timeout` or use `--no-wait` + poll |

## Interactive Parameter Collection

Same as before — use `AskUserQuestion` tool for enumerable parameters, free text for topics/prompts. One question at a time. Confirm before executing.

## Long Text Input

For long content, write to a temp file and use shell substitution:

```bash
cat > /tmp/lh-content.txt << 'EOF'
Long text content here...
EOF

listenhub tts create --text "$(cat /tmp/lh-content.txt)" --json
rm /tmp/lh-content.txt
```
```

- [ ] **Step 3: Write `shared/cli-speakers.md`**

```markdown
# CLI Speaker Query

## Listing Speakers

```bash
listenhub speakers list --json
listenhub speakers list --lang zh --json
listenhub speakers list --lang en --json
```

Returns JSON array of speaker objects. Parse with `jq`:

```bash
SPEAKERS=$(listenhub speakers list --lang zh --json)
echo "$SPEAKERS" | jq -r '.[] | "\(.name)\t\(.speakerId)\t\(.gender)"'
```

## Speaker Selection by Name

Use `--speaker "name"` in create commands:

```bash
listenhub podcast create --query "topic" --speaker "原野" --json
listenhub tts create --text "hello" --speaker "Mars" --json
```

For exact ID matching, use `--speaker-id`:

```bash
listenhub podcast create --query "topic" --speaker-id "CN-Man-Beijing-V2" --json
```

## Multi-Speaker Commands

Podcast supports up to 2 speakers (repeat the flag):

```bash
listenhub podcast create --query "topic" --speaker "原野" --speaker "高晴" --json
```

## Integration with speaker-selection.md

The interaction flow in `shared/speaker-selection.md` remains the same — present text table, accept free-text input. The only change is the underlying query:

- **Before**: `curl -sS "https://api.marswave.ai/openapi/v1/speakers/list?language=zh" -H "Authorization: Bearer $LISTENHUB_API_KEY" -H "X-Source: skills"`
- **After**: `listenhub speakers list --lang zh --json`
```

- [ ] **Step 4: Commit**

```bash
git add shared/cli-authentication.md shared/cli-patterns.md shared/cli-speakers.md
git commit -m "feat: add shared CLI docs for authentication, patterns, and speakers"
```

---

## Task 2: Create `/slides` skill

**Files:**
- Create: `slides/SKILL.md`
- Reference: `explainer/SKILL.md` (template), `shared/cli-authentication.md`, `shared/cli-patterns.md`

- [ ] **Step 1: Write `slides/SKILL.md`**

Use `explainer/SKILL.md` as template. Key differences:
- mode = slides (not info/story)
- Default: skip audio (`--no-skip-audio` to enable narration)
- Interaction asks "need narration?" (default no) instead of "output type?"
- CLI command: `listenhub slides create`

Full content:

```markdown
---
name: slides
description: |
  Create slide decks from topics, URLs, or text. Triggers on: "幻灯片", "PPT",
  "slides", "slide deck", "做幻灯片", "create slides", "presentation".
metadata:
  openclaw:
    emoji: "📊"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
---

## When to Use

- User wants to create a slide deck or presentation
- User asks for "slides", "PPT", "幻灯片", "presentation"
- User wants visual content pages from a topic

## When NOT to Use

- User wants a narrated video (use `/explainer`)
- User wants audio-only content (use `/podcast` or `/tts`)
- User wants to generate a standalone image (use `/image-gen`)

## Purpose

Generate slide decks with AI-generated visuals from topics, URLs, or text. Optionally add voice narration. Ideal for presentations, teaching materials, and visual summaries.

## Hard Constraints

- Always check CLI auth following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for command execution and error handling
- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/speaker-selection.md` for speaker selection when narration is enabled
- Slides use exactly 1 speaker (when narration is enabled)
- Never save files to `~/Downloads/` or `.listenhub/` — save artifacts to the current working directory with friendly topic-based names (see `shared/config-pattern.md` § Artifact Naming)

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation command until the user has explicitly confirmed.
</HARD-GATE>

## Step -1: CLI Auth Check

Follow `shared/cli-authentication.md` § Auth Check. If CLI is not installed or not logged in, guide the user through setup.

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
```bash
mkdir -p ".listenhub/slides"
echo '{"outputMode":"inline","language":null,"defaultSpeakers":{}}' > ".listenhub/slides/config.json"
CONFIG_PATH=".listenhub/slides/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```
**Do NOT ask any setup questions.** Proceed directly to the Interaction Flow.

**If file exists** — read config silently and proceed:
```bash
CONFIG_PATH=".listenhub/slides/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/slides/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

### Setup Flow (user-initiated reconfigure only)

Only run when the user explicitly asks to reconfigure. Display current settings:
```
当前配置 (slides)：
  输出方式：{inline / download / both}
  语言偏好：{zh / en / 未设置}
  默认主播：{speakerName / 使用内置默认}
```

Then ask:

1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.

2. **Language** (optional): "默认语言？"
   - "中文 (zh)"
   - "English (en)"
   - "每次手动选择" → keep `null`

After collecting answers, save immediately:
```bash
NEW_CONFIG=$(echo "$CONFIG" | jq --arg m "$OUTPUT_MODE" '. + {"outputMode": $m}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

## Interaction Flow

### Step 1: Topic / Content

Free text input. Ask the user:

> What would you like to create slides about?

Accept: topic description, text content, or concept.

### Step 2: Language

If `config.language` is set, pre-fill and show in summary — skip this question.
Otherwise, detect from the user's input language:
- Chinese input → `zh`
- English input → `en`

Show in the confirmation summary. Never ask explicitly.

### Step 3: Narration

```
Question: "需要语音旁白吗？"
Options:
  - "不需要（默认）" — Skip audio, slides only
  - "需要" — Generate narration with speaker
```

Default: no narration (slides default skips audio).

### Step 4: Speaker Selection (only if narration enabled)

Follow `shared/speaker-selection.md`:
- If `config.defaultSpeakers.{language}` is set → use saved speaker silently
- If not set → use **built-in default** from `shared/speaker-selection.md` for the language
- Show the speaker in the confirmation summary — user can change from there
- Only show the full speaker list if the user explicitly asks to change voice

Only 1 speaker is supported.

### Step 5: Visual Options (optional)

```
Question: "图片尺寸？"
Options:
  - "2K（推荐）" — 2K resolution
  - "4K" — Ultra high quality
```

```
Question: "宽高比？"
Options:
  - "16:9（推荐）" — Landscape, presentation
  - "9:16" — Portrait
  - "1:1" — Square
```

Visual style: ask only if user mentions a specific style. Otherwise skip.

### Step 6: Confirm & Generate

Summarize all choices:

```
Ready to generate slides:

  Topic: {topic}
  Language: {language}
  Narration: {yes (speaker name) / no}
  Resolution: {2K / 4K}
  Aspect ratio: {ratio}
  Style: {style / default}

  Proceed?
```

Wait for explicit confirmation.

## Workflow

1. **Build CLI command**:
   ```bash
   listenhub slides create \
     --query "{topic}" \
     --lang {en|zh|ja} \
     --image-size {2K|4K} \
     --aspect-ratio {16:9|9:16|1:1} \
     --json
   ```

   If narration enabled, add: `--no-skip-audio --speaker "{name}"`
   If style specified, add: `--style "{style}"`
   If source URLs provided, add: `--source-url "{url}"` (repeatable)

2. **Execute**: Run the CLI command. It handles polling internally.
   Use `run_in_background: true` with `timeout: 360000`:

   ```bash
   listenhub slides create --query "{topic}" --lang zh --json
   ```

3. When notified, **parse and present result**:

   Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

   **`inline` or `both`**: Display links.

   Present:
   ```
   幻灯片已生成！

   在线查看：https://listenhub.ai/app/slides/{episodeId}
   页数：{pageCount}
   消耗积分：{credits}
   ```

   **`download` or `both`**: Generate a topic slug following `shared/config-pattern.md` § Artifact Naming.
   - Create `{slug}-slides/` folder (dedup if exists)
   - Write `script.md` inside (narration text per page)
   - If narration audio exists, download: `curl -sS -o "{slug}-slides/audio.mp3" "{audioUrl}"`
   - Present the save path.

### After Successful Generation

Update config:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  '. + {"language": $lang}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

If narration was used with a new speaker, also update `defaultSpeakers`.

**Estimated time**: 2-4 minutes.

## Composability

- **Invokes**: speakers API via CLI (for speaker selection when narration enabled)
- **Invoked by**: none currently

## Example

**User**: "Create slides about quantum computing basics"

**Agent workflow**:
1. Topic: "quantum computing basics"
2. Language: en (detected from input)
3. Narration: no (default)
4. Resolution: 2K, Ratio: 16:9 (defaults)
5. Confirm → proceed

```bash
listenhub slides create \
  --query "quantum computing basics" \
  --lang en \
  --image-size 2K \
  --aspect-ratio 16:9 \
  --json
```

Poll until complete, then present the result.
```

- [ ] **Step 2: Commit**

```bash
git add slides/SKILL.md
git commit -m "feat: add /slides skill for slide deck generation via CLI"
```

---

## Task 3: Create `/music` skill

**Files:**
- Create: `music/SKILL.md`
- Reference: `shared/cli-authentication.md`, `shared/cli-patterns.md`

- [ ] **Step 1: Write `music/SKILL.md`**

```markdown
---
name: music
description: |
  Generate AI music or create covers from reference audio. Triggers on: "音乐",
  "music", "生成音乐", "generate music", "翻唱", "cover", "作曲", "compose",
  "create a song", "做一首歌".
metadata:
  openclaw:
    emoji: "🎵"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
---

## When to Use

- User wants to generate original music from a text description
- User wants to create a cover from reference audio
- User says "music", "generate music", "create a song"
- User says "音乐", "生成音乐", "翻唱", "作曲"

## When NOT to Use

- User wants text-to-speech (use `/tts`)
- User wants a podcast discussion (use `/podcast`)
- User wants to transcribe audio to text (use `/asr`)

## Purpose

Generate original AI music from text prompts, or create cover versions from reference audio. Supports style control, titles, and instrumental-only generation.

## Hard Constraints

- Always check CLI auth following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for command execution and error handling
- Always read config following `shared/config-pattern.md` before any interaction
- Never save files to `~/Downloads/` or `.listenhub/` — save artifacts to the current working directory with friendly topic-based names (see `shared/config-pattern.md` § Artifact Naming)
- Music generation has longer timeouts (default 600s) — always use `run_in_background: true`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation command until the user has explicitly confirmed.
</HARD-GATE>

## Step -1: CLI Auth Check

Follow `shared/cli-authentication.md` § Auth Check.

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
```bash
mkdir -p ".listenhub/music"
echo '{"outputMode":"download","language":null}' > ".listenhub/music/config.json"
CONFIG_PATH=".listenhub/music/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```
**Do NOT ask any setup questions.** Proceed directly to the Interaction Flow.

**If file exists** — read config silently and proceed:
```bash
CONFIG_PATH=".listenhub/music/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/music/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

### Setup Flow (user-initiated reconfigure only)

Only run when the user explicitly asks to reconfigure. Display current settings:
```
当前配置 (music)：
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

### Step 1: Creation Mode

```
Question: "创作模式？"
Options:
  - "原创 — 从文字描述生成音乐" — Generate original music
  - "翻唱 — 从参考音频创建翻唱" — Create cover from reference audio
```

### Step 2a: Music Description (generate mode)

Free text input. Ask:

> 描述你想要的音乐（风格、情绪、场景等）

Example: "轻松的 lo-fi 节拍，适合深夜学习"

### Step 2b: Reference Audio (cover mode)

Free text input. Ask:

> 提供参考音频文件路径或 URL

Accept: local file path (mp3, wav, flac, m4a, ogg, aac; max 20MB) or URL.

Optionally ask for a description prompt to guide the cover style.

### Step 3: Style (optional)

Free text input. Ask:

> 音乐风格？（可选，直接回车跳过）

Examples: "lo-fi", "EDM", "classical piano", "jazz"

### Step 4: Title (optional)

Free text input. Ask:

> 曲名？（可选，不填则自动生成）

### Step 5: Instrumental

```
Question: "纯音乐（无人声）？"
Options:
  - "有人声（默认）" — Include vocals
  - "纯音乐" — Instrumental only, no vocals
```

### Step 6: Confirm & Generate

Summarize all choices:

**Generate mode:**
```
Ready to generate music:

  Mode: Original
  Prompt: {prompt}
  Style: {style / not set}
  Title: {title / auto}
  Instrumental: {yes / no}

  Proceed?
```

**Cover mode:**
```
Ready to create cover:

  Mode: Cover
  Reference: {audio path or URL}
  Prompt: {prompt / not set}
  Style: {style / not set}
  Title: {title / auto}
  Instrumental: {yes / no}

  Proceed?
```

Wait for explicit confirmation.

## Workflow

### Generate Mode

1. **Build CLI command**:
   ```bash
   listenhub music generate \
     --prompt "{description}" \
     --json
   ```
   If style set: add `--style "{style}"`
   If title set: add `--title "{title}"`
   If instrumental: add `--instrumental`

2. **Execute** with `run_in_background: true` and `timeout: 660000`

3. When notified, **parse and present result**:

   Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

   **`inline` or `both`**: Display audio URL as clickable link.

   Present:
   ```
   音乐已生成！

   在线收听：{audioUrl}
   标题：{title}
   时长：{duration}s
   消耗积分：{credits}
   ```

   **`download` or `both`**: Generate a topic slug following `shared/config-pattern.md` § Artifact Naming.
   ```bash
   SLUG="{title-slug}"  # e.g. "late-night-lofi"
   NAME="${SLUG}.mp3"
   BASE="${NAME%.*}"; EXT="${NAME##*.}"; i=2
   while [ -e "$NAME" ]; do NAME="${BASE}-${i}.${EXT}"; i=$((i+1)); done
   curl -sS -o "$NAME" "{audioUrl}"
   ```
   Present:
   ```
   已保存到当前目录：
     {NAME}
   ```

### Cover Mode

1. **Build CLI command**:
   ```bash
   listenhub music cover \
     --audio "{path-or-url}" \
     --json
   ```
   If prompt set: add `--prompt "{description}"`
   If style set: add `--style "{style}"`
   If title set: add `--title "{title}"`
   If instrumental: add `--instrumental`

2. Same execution and presentation as generate mode.

**Estimated times**: 3-8 minutes (music generation is slower).

## Composability

- **Invokes**: nothing (direct CLI call)
- **Invoked by**: none currently

## Example

**User**: "生成一段轻松的 lo-fi 音乐"

**Agent workflow**:
1. Mode: generate (detected from "生成")
2. Prompt: "轻松的 lo-fi 音乐"
3. Style: "lo-fi" (inferred from prompt, confirm with user)
4. Title: auto
5. Instrumental: no (default)
6. Confirm → proceed

```bash
listenhub music generate \
  --prompt "轻松的lo-fi音乐" \
  --style "lo-fi" \
  --json
```

Poll until complete, then present result.
```

- [ ] **Step 2: Commit**

```bash
git add music/SKILL.md
git commit -m "feat: add /music skill for AI music generation and covers via CLI"
```

---

## Task 4: Migrate `/podcast` to CLI

**Files:**
- Modify: `podcast/SKILL.md`

- [ ] **Step 1: Rewrite `podcast/SKILL.md`**

Key changes from current file:
1. **Frontmatter**: `requires.env` → `requires.bin`, `primaryEnv` → `primaryBin`
2. **Hard Constraints**: Remove "No shell scripts. Construct curl commands from API reference" → "Always check CLI auth following `shared/cli-authentication.md`" + "Follow `shared/cli-patterns.md`"
3. **Step -1**: API Key Check → CLI Auth Check
4. **Step 0**: Same config pattern (unchanged)
5. **Interaction Flow**: Remove Step 6 (Generation Method — two-step is gone). Keep Steps 1-5 and 7 (renumber 7→6).
6. **Workflow**: Remove Two-Step Generation entirely. One-Step becomes the only workflow:
   - Replace curl POST with `listenhub podcast create --query ... --json`
   - Replace background polling loop with CLI built-in polling (run CLI with `run_in_background: true`)
   - Replace `jq` parsing of curl response with `jq` parsing of CLI JSON output
7. **API Reference section**: Replace `shared/api-podcast.md` → `shared/cli-patterns.md`, `shared/api-speakers.md` → `shared/cli-speakers.md`, `shared/authentication.md` → `shared/cli-authentication.md`, `shared/common-patterns.md` → `shared/cli-patterns.md`
8. **Example**: Replace curl example with CLI command

The full rewrite should follow the exact same structure as the current file but with CLI commands. The interaction flow (AskUserQuestion steps) stays identical except removing the Generation Method step.

- [ ] **Step 2: Verify no references to deleted files**

```bash
grep -n "shared/api-\|shared/authentication\|shared/common-patterns\|LISTENHUB_API_KEY" podcast/SKILL.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add podcast/SKILL.md
git commit -m "feat: migrate /podcast to CLI, remove two-step workflow"
```

---

## Task 5: Migrate `/tts` to CLI

**Files:**
- Modify: `tts/SKILL.md`

- [ ] **Step 1: Rewrite `tts/SKILL.md`**

Key changes:
1. **Frontmatter**: `requires.env` → `requires.bin`, `primaryEnv` → `primaryBin`
2. **Hard Constraints**: curl refs → CLI refs
3. **Step -1**: API Key → CLI Auth
4. **Quick Mode**: Replace curl `POST /v1/tts` with `listenhub tts create --text "..." --mode direct --speaker "..." --json`. Note: TTS Quick maps to CLI `--mode direct`, Script maps to `--mode smart`.
5. **Script Mode**: Replace curl `POST /v1/speech` with `listenhub tts create --text "..." --mode smart --speaker "..." --json`. For multi-speaker scripts, the CLI handles this with a single `--text` containing the formatted script.
6. **Polling**: Quick mode is sync in both old (curl returns MP3 stream) and new (CLI waits). Script mode: remove background polling loop, CLI handles it.
7. **Output handling**: `inline` mode — CLI returns JSON with `audioUrl`, use that directly instead of saving to `/tmp/`. For `download`/`both` — download from `audioUrl` same as before but using URL from CLI JSON output.
8. **API Reference**: Update all shared/ references.

- [ ] **Step 2: Verify no references to deleted files**

```bash
grep -n "shared/api-\|shared/authentication\|shared/common-patterns\|LISTENHUB_API_KEY" tts/SKILL.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add tts/SKILL.md
git commit -m "feat: migrate /tts to CLI commands"
```

---

## Task 6: Migrate `/explainer` to CLI

**Files:**
- Modify: `explainer/SKILL.md`

- [ ] **Step 1: Rewrite `explainer/SKILL.md`**

Key changes:
1. **Frontmatter**: `requires.env` → `requires.bin`, `primaryEnv` → `primaryBin`
2. **Hard Constraints**: curl refs → CLI refs. Keep "Mode must be `info` or `story` — never `slides`"
3. **Step -1**: API Key → CLI Auth
4. **Workflow**: Replace curl `POST /storybook/episodes` + polling loop with `listenhub explainer create --query ... --mode info --json`. Replace video generation curl + polling with... the CLI handles both text and video in one command. If `--skip-audio` is passed, only text script is generated.
5. **Output**: Parse CLI JSON output instead of curl response. The `episodeId`, `audioUrl`, `videoUrl`, `credits` fields come from CLI JSON.
6. **API Reference**: Update all shared/ references.

- [ ] **Step 2: Verify no references to deleted files**

```bash
grep -n "shared/api-\|shared/authentication\|shared/common-patterns\|LISTENHUB_API_KEY" explainer/SKILL.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add explainer/SKILL.md
git commit -m "feat: migrate /explainer to CLI commands"
```

---

## Task 7: Migrate `/image-gen` to CLI

**Files:**
- Modify: `image-gen/SKILL.md`

- [ ] **Step 1: Rewrite `image-gen/SKILL.md`**

Key changes:
1. **Frontmatter**: `requires.env` → `requires.bin`, `primaryEnv` → `primaryBin`
2. **Hard Constraints**: curl refs → CLI refs
3. **Step -1**: API Key → CLI Auth
4. **Reference images**: CLI handles local file upload natively (`--reference ./image.png`). Remove base64 encoding logic entirely. Just pass `--reference "{path-or-url}"` (repeatable, max 5).
5. **Workflow**: Replace curl `POST /images/generation` with `listenhub image create --prompt "..." --model "..." --json`. CLI returns JSON with image data.
6. **New**: Add `--lang` flag for prompt language hint.
7. **API Reference**: Update all shared/ references.

- [ ] **Step 2: Verify no references to deleted files**

```bash
grep -n "shared/api-\|shared/authentication\|shared/common-patterns\|LISTENHUB_API_KEY" image-gen/SKILL.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add image-gen/SKILL.md
git commit -m "feat: migrate /image-gen to CLI commands"
```

---

## Task 8: Inline content-parser API docs

**Files:**
- Modify: `content-parser/SKILL.md`

- [ ] **Step 1: Rewrite `content-parser/SKILL.md`**

This skill stays curl-based (CLI has no content-extract command). Changes:
1. Remove all `shared/` references from Hard Constraints and API Reference sections
2. Inline the following into the SKILL.md itself:
   - **Authentication** (from `shared/authentication.md`): API Key env var, base URL, required headers, curl template
   - **API endpoints** (from `shared/api-content-extract.md`): POST /v1/content/extract request/response, GET /v1/content/extract/{taskId} request/response
   - **Polling pattern** (from `shared/common-patterns.md`): background polling loop (5s interval, 60 polls), error handling, retry strategy
   - **Config pattern**: Keep reference to `shared/config-pattern.md` (it's being retained)
3. The SKILL.md should be fully self-contained for API usage — no external shared/ references except `shared/config-pattern.md` and `shared/output-mode.md`

Structure the inlined content as collapsed sections at the bottom:

```markdown
## API Reference (Inlined)

### Authentication

[content from shared/authentication.md]

### POST /v1/content/extract

[content from shared/api-content-extract.md — create endpoint]

### GET /v1/content/extract/{taskId}

[content from shared/api-content-extract.md — poll endpoint]

### Async Polling Pattern

[content from shared/common-patterns.md § Async Polling, adapted for content-parser's 5s interval]

### Error Handling

[content from shared/common-patterns.md § Error Handling]
```

- [ ] **Step 2: Verify only allowed shared/ refs remain**

```bash
grep -n "shared/" content-parser/SKILL.md
```

Expected: only `shared/config-pattern.md` and `shared/output-mode.md` references.

- [ ] **Step 3: Commit**

```bash
git add content-parser/SKILL.md
git commit -m "refactor: inline API docs into content-parser (no more shared/ deps)"
```

---

## Task 9: Create `listenhub-cli` + update `listenhub` umbrella skills

**Files:**
- Create: `listenhub-cli/SKILL.md`
- Modify: `listenhub/SKILL.md`
- Delete: `listenhub/DEPRECATED.md`

- [ ] **Step 1: Write `listenhub-cli/SKILL.md`**

```markdown
---
name: listenhub-cli
description: |
  ListenHub CLI skills router. Routes to the correct skill based on user intent.
  Triggers on: "make a podcast", "explainer video", "read aloud", "TTS",
  "generate image", "做播客", "解说视频", "朗读", "生成图片", "幻灯片",
  "slides", "音乐", "music", "generate music", "翻唱", "cover song",
  "parse URL", "解析链接", "提取内容".
metadata:
  openclaw:
    emoji: "🎧"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
---

## Purpose

This is a router skill. When users trigger a general ListenHub action, this skill identifies the intent and delegates to the appropriate specialized skill.

## Routing Table

| User intent | Keywords | Route to |
|-------------|----------|----------|
| Podcast | "podcast", "播客", "debate", "dialogue" | `/podcast` |
| Explainer video | "explainer", "解说视频", "tutorial video" | `/explainer` |
| Slides / PPT | "slides", "幻灯片", "PPT", "presentation" | `/slides` |
| TTS / Read aloud | "TTS", "read aloud", "朗读", "配音", "语音合成" | `/tts` |
| Image generation | "generate image", "画一张", "生成图片", "AI图" | `/image-gen` |
| Music | "music", "音乐", "生成音乐", "翻唱", "cover" | `/music` |
| Content extraction | "parse URL", "extract content", "解析链接" | `/content-parser` |
| Audio transcription | "transcribe", "ASR", "语音转文字" | `/asr` |
| Creator workflow | "创作", "写公众号", "小红书", "口播" | `/creator` |

## How to Route

1. Read the user's message and identify which category it falls into
2. Tell the user which skill you're routing to
3. Follow that skill's SKILL.md completely

If the intent is ambiguous, ask the user to clarify:

```
Question: "What would you like to create?"
Options:
  - "Podcast" — Audio discussion on a topic
  - "Explainer Video" — Narrated video with AI visuals
  - "Slides" — Slide deck / presentation
  - "Music" — AI-generated music or cover
```

## Prerequisites

Most skills require the ListenHub CLI. Check:

```bash
listenhub auth status --json
```

If not installed or not logged in, guide the user:

1. Install: `npm install -g @marswave/listenhub-cli`
2. Login: `listenhub auth login`

Exception: `/asr` runs locally and needs no CLI or API key.
```

- [ ] **Step 2: Copy to `listenhub/SKILL.md` with name change**

Copy the exact same content to `listenhub/SKILL.md`, changing only `name: listenhub-cli` → `name: listenhub` in the frontmatter. Everything else is identical.

- [ ] **Step 3: Delete `listenhub/DEPRECATED.md`**

```bash
rm listenhub/DEPRECATED.md
```

- [ ] **Step 4: Commit**

```bash
git add listenhub-cli/SKILL.md listenhub/SKILL.md
git rm listenhub/DEPRECATED.md
git commit -m "feat: add listenhub-cli router skill, sync listenhub skill"
```

---

## Task 10: Update `shared/speaker-selection.md`

**Files:**
- Modify: `shared/speaker-selection.md`

- [ ] **Step 1: Update speaker fetch command**

Replace the "Fetching Speakers" section. Change:

```markdown
## Fetching Speakers

Always call the speakers API before presenting options (when user requests to change voice):

```
GET /speakers/list?language={language}
```
```

To:

```markdown
## Fetching Speakers

Always query the speaker list before presenting options (when user requests to change voice):

```bash
listenhub speakers list --lang {language} --json
```

See `shared/cli-speakers.md` for full query patterns.
```

No other changes — the built-in defaults table, selection UI, and persistence logic stay the same.

- [ ] **Step 2: Verify no curl/API Key references remain**

```bash
grep -n "curl\|LISTENHUB_API_KEY\|Authorization" shared/speaker-selection.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add shared/speaker-selection.md
git commit -m "refactor: update speaker-selection to use CLI query"
```

---

## Task 11: Update `shared/config-pattern.md`

**Files:**
- Modify: `shared/config-pattern.md`

- [ ] **Step 1: Replace API Key Check with CLI Auth Check**

Replace the entire "## API Key Check" section (from `## API Key Check` through the end of "### Interactive Key Setup" including step 6) with:

```markdown
## CLI Auth Check

Run this **before Step 0** in every skill that uses the ListenHub CLI.

Follow `shared/cli-authentication.md` § Auth Check.

If CLI is not installed or not logged in, guide the user through setup as described in `shared/cli-authentication.md`.
```

No other changes to the file.

- [ ] **Step 2: Commit**

```bash
git add shared/config-pattern.md
git commit -m "refactor: replace API Key Check with CLI Auth Check in config-pattern"
```

---

## Task 12: Delete old shared/ API docs

**Files:**
- Delete: `shared/api-podcast.md`
- Delete: `shared/api-tts.md`
- Delete: `shared/api-image.md`
- Delete: `shared/api-storybook.md`
- Delete: `shared/api-content-extract.md`
- Delete: `shared/api-speakers.md`
- Delete: `shared/authentication.md`
- Delete: `shared/common-patterns.md`

- [ ] **Step 1: Verify no remaining references**

```bash
grep -rn "shared/api-\|shared/authentication\.md\|shared/common-patterns\.md" \
  --include="*.md" \
  --exclude-dir=".git" \
  --exclude-dir="docs" \
  .
```

Expected: no matches outside `docs/` (specs/plans are documentation, not runtime references).

If any matches found in SKILL.md files, fix them first before proceeding.

- [ ] **Step 2: Delete files**

```bash
git rm shared/api-podcast.md shared/api-tts.md shared/api-image.md \
  shared/api-storybook.md shared/api-content-extract.md shared/api-speakers.md \
  shared/authentication.md shared/common-patterns.md
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove old shared/ API docs (replaced by CLI + inlined)"
```

---

## Task 13: Update creator/ templates

**Files:**
- Modify: `creator/SKILL.md`
- Modify: `creator/templates/narration/template.md`
- Modify: `creator/templates/wechat/template.md`
- Modify: `creator/templates/xiaohongshu/template.md`

- [ ] **Step 1: Update `creator/SKILL.md` references**

Replace all `shared/` references that point to deleted files:
- `shared/authentication.md` → `shared/cli-authentication.md`
- `shared/common-patterns.md` → `shared/cli-patterns.md`
- `shared/api-image.md` → inline the image CLI command: `listenhub image create --prompt "..." --json`
- `shared/api-content-extract.md` → reference `content-parser/SKILL.md` § API Reference (Inlined)
- `shared/api-tts.md` → inline the TTS CLI command: `listenhub tts create --text "..." --json`

In the Hard Constraints section, change:
- "No shell scripts. Construct curl commands from the API reference files in `shared/`" → "Use `listenhub` CLI commands for image-gen and TTS. Use curl for content-parser (see `content-parser/SKILL.md` § API Reference)."

In the API Key Check at Confirmation Gate, change:
- Check `LISTENHUB_API_KEY` → Check `listenhub auth status --json` for CLI-based calls. For content-parser calls, still check `LISTENHUB_API_KEY`.

In the API Reference section at the bottom, update:
- `shared/authentication.md` → `shared/cli-authentication.md`
- `shared/api-image.md` → "Use `listenhub image create` (see `shared/cli-patterns.md`)"
- `shared/api-content-extract.md` → `content-parser/SKILL.md` § API Reference (Inlined)
- `shared/api-tts.md` → "Use `listenhub tts create` (see `shared/cli-patterns.md`)"
- `shared/common-patterns.md` → `shared/cli-patterns.md`

Also update the image generation curl commands in the workflow to use CLI:
```bash
# Before:
curl -sS -X POST "https://api.marswave.ai/openapi/v1/images/generation" ...

# After:
listenhub image create --prompt "{prompt}" --aspect-ratio "1:1" --size "2K" --json
```

And TTS commands:
```bash
# Before:
curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" ...

# After:
listenhub tts create --text "{text}" --speaker "{speaker}" --json
```

- [ ] **Step 2: Update `creator/templates/narration/template.md`**

- Replace `shared/speaker-selection.md` built-in defaults reference → keep as-is (speaker-selection.md is retained)
- Replace TTS API curl command with CLI:
  ```bash
  listenhub tts create --text "$(cat /tmp/lh-content.txt)" --speaker "{speaker}" --json
  ```

- [ ] **Step 3: Update `creator/templates/wechat/template.md`**

Replace `shared/api-image.md` reference with CLI command note:
- `(per shared/api-image.md)` → `(use listenhub image create --json)`

- [ ] **Step 4: Update `creator/templates/xiaohongshu/template.md`**

Same change as wechat template.

- [ ] **Step 5: Verify no deleted shared/ references remain in creator/**

```bash
grep -rn "shared/api-\|shared/authentication\.md\|shared/common-patterns\.md" creator/
```

Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add creator/SKILL.md creator/templates/narration/template.md \
  creator/templates/wechat/template.md creator/templates/xiaohongshu/template.md
git commit -m "refactor: update creator/ to use CLI commands and new shared/ docs"
```

---

## Task 14: Update READMEs

**Files:**
- Modify: `README.md`
- Modify: `README.zh.md`

- [ ] **Step 1: Update `README.md`**

Changes:
1. **Skills table**: Add slides and music rows:
   ```
   | `/slides` | "slides", "幻灯片" | Create slide decks with AI visuals |
   | `/music` | "music", "音乐" | AI music generation and covers |
   ```
2. **Setup section**: Replace API Key with CLI:
   ```
   **ListenHub CLI** — Install and login:
   ```bash
   npm install -g @marswave/listenhub-cli
   listenhub auth login
   ```
   ```
3. **Directory structure**: Add `slides/`, `music/`, `listenhub-cli/`. Change `listenhub/` description from "Deprecated" to "Router skill (alias for listenhub-cli)".
4. **Supported Inputs**: Add "Music prompts" and "Reference audio" to the list.

- [ ] **Step 2: Update `README.zh.md`**

Same changes as README.md but in Chinese:
1. Skills table:
   ```
   | `/slides` | "幻灯片"、"slides" | 幻灯片生成 |
   | `/music` | "音乐"、"music" | AI 音乐生成、翻唱 |
   ```
2. Setup: CLI install + login
3. Directory structure: add new dirs
4. Supported inputs: add music items

- [ ] **Step 3: Commit**

```bash
git add README.md README.zh.md
git commit -m "docs: update READMEs with slides, music, CLI auth"
```

---

## Dependency Graph

```
Task 1 (shared CLI docs)
├── Task 2 (slides) ────────────┐
├── Task 3 (music) ─────────────┤
├── Task 4 (podcast) ───────────┤
├── Task 5 (tts) ───────────────┤
├── Task 6 (explainer) ─────────┼── Task 9 (listenhub-cli + listenhub) ── Task 14 (README)
├── Task 7 (image-gen) ─────────┤
├── Task 10 (speaker-selection) ┘
├── Task 11 (config-pattern)
│
Task 8 (content-parser inline) ─── Task 12 (delete old shared/) ── Task 13 (creator/ update)
```

Tasks 2-8, 10, 11 can run in parallel after Task 1.
Task 9 requires Tasks 2-7.
Task 12 requires Task 8.
Task 13 requires Tasks 4-7 and 12.
Task 14 requires Tasks 2-9.
