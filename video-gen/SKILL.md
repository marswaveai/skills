---
name: video-gen
metadata:
  openclaw:
    emoji: "🎬"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
description: |
  Generate AI videos from text prompts or reference materials.
  Supports HappyHorse and SeeDance models.
  Triggers on: "生成视频", "做视频", "video generation", "text to video",
  "create video", "视频生成", "视频编辑", "video edit".
---

## When to Use

- User wants to generate an AI video from a text description
- User wants to animate a still image (first-frame)
- User has reference images to guide video generation
- User wants to edit an existing video (change style, background, etc.)
- User says "生成视频", "做视频", "video generation", "text to video", "视频编辑"

## When NOT to Use

- User wants an explainer video with narration and AI visuals (use `/explainer`)
- User wants to transcribe audio/video to text (use `/asr`)
- User wants to generate an image (use `/image-gen`)

## Purpose

Generate AI videos using the ListenHub CLI. Supports two model families:

- **HappyHorse** (default) — text-to-video, image-to-video, reference-image-to-video, video-edit
- **SeeDance** — text-to-video, frame mode (first + last frame), reference mode (images, videos, audio)

## Hard Constraints

- Always check CLI auth following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for CLI execution, errors, and interaction patterns
- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/output-mode.md` for result presentation — `download` mode saves `{slug}.mp4` to cwd with dedupe per `shared/config-pattern.md` § Artifact Naming
- Always use `--no-wait --json` for video creation — generation takes minutes
- Never use `eval` to execute CLI commands — always invoke `listenhub video ...` directly with proper quoting

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options
as plain text. Ask one question at a time. Wait for the user's answer before
proceeding to the next step. After all parameters are collected, summarize the
choices and ask the user to confirm. Do NOT call the video generation command
until the user has explicitly confirmed.
</HARD-GATE>

## Model Comparison

| Feature | HappyHorse (default) | SeeDance |
|---------|---------------------|----------|
| Text-to-video | ✅ | ✅ |
| Image-to-video (first-frame) | ✅ | ✅ (+ last-frame) |
| Reference images | ✅ (1–9, with [Image N] prompt syntax) | ✅ |
| Video edit | ✅ | ❌ |
| Reference video | ❌ (use video-edit instead) | ✅ |
| Reference audio | ❌ | ✅ |
| Resolution | 720p, 1080p | 480p, 720p, 1080p |
| Duration range | 3–15s | 4–15s |
| Extra ratios | 4:5, 5:4 | — |
| Prompt length | ≤2500 中文 / ≤5000 非中文 | ≤500 |

## Step -1: CLI Auth Check + Video Command Gate

Follow `shared/cli-authentication.md` § Auth Check. If CLI is not installed or not logged in, auto-install and auto-login — never ask the user to run commands manually.

After standard auth check, verify the `video` subcommand is available:

```bash
if ! listenhub video --help &>/dev/null; then
  npm install -g @marswave/listenhub-cli@latest
  if ! listenhub video --help &>/dev/null; then
    echo "VIDEO_COMMAND_UNAVAILABLE"
  fi
fi
```

If `VIDEO_COMMAND_UNAVAILABLE`: stop and tell the user:

> video-gen 需要 listenhub-cli 的最新版本，当前已安装版本不包含 video 命令，请等待新版发布。

### Auth Mode Detection

The CLI supports two auth modes. Detect which one is active:

```bash
# Check if OpenAPI key is configured
OPENAPI_STATUS=$(listenhub openapi config show --json 2>/dev/null)
HAS_OPENAPI=$(echo "$OPENAPI_STATUS" | jq -r '.source // empty')

# Check if internal auth is active
AUTH=$(listenhub auth status --json 2>/dev/null)
HAS_INTERNAL=$(echo "$AUTH" | jq -r '.authenticated // false')
```

**Priority:** If both are configured, prefer internal auth (richer features). Set a session variable:

```bash
if [ "$HAS_INTERNAL" = "true" ]; then
  CMD_PREFIX="listenhub video"
elif [ -n "$HAS_OPENAPI" ]; then
  CMD_PREFIX="listenhub openapi video"
else
  # Neither configured — trigger internal auth login
  listenhub auth login
  CMD_PREFIX="listenhub video"
fi
```

All subsequent commands use `$CMD_PREFIX` instead of hardcoded `listenhub video`. The flags and JSON output format are identical between the two modes.

**OpenAPI-specific notes:**
- OpenAPI mode requires API Key (`lh_sk_...`), configured via `listenhub openapi config set-key` or env `LISTENHUB_API_KEY`
- OpenAPI mode does not support `--audio-setting` flag (video-edit audio control not yet exposed)
- All media inputs must be **URLs** in OpenAPI mode (no local file upload) — if user provides local paths, inform them: "OpenAPI 模式需要使用公网 URL，请先上传文件后提供链接。"

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
```bash
mkdir -p ".listenhub/video-gen"
echo '{"outputMode":"inline"}' > ".listenhub/video-gen/config.json"
CONFIG_PATH=".listenhub/video-gen/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

Session defaults (not persisted unless user reconfigures):
- model: `happyhorse`
- resolution: `1080p`
- ratio: `16:9`
- duration: `5`

**Do NOT ask any setup questions.** Proceed directly to the Interaction Flow.

**If file exists** — read config silently and proceed:
```bash
CONFIG_PATH=".listenhub/video-gen/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/video-gen/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

### Setup Flow (user-initiated reconfigure only)

Only run when the user explicitly asks to reconfigure. Display current settings:
```
当前配置 (video-gen)：
  输出方式: {outputMode}
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

### Step 1: Collect Prompt

Ask the user for a video description. If they haven't provided one:

> 描述你想要生成的视频内容。

Free text input. Use as-is — do not modify the prompt unless the user asks for help.

### Step 2: Mode Routing

```
Question: "你有参考素材想提供吗？"
Options:
  - "没有，纯文字生成" — Text-to-video mode, skip to Step 4
  - "有图片，想做首帧动画" — Image-to-video (first-frame) → Step 3a
  - "有参考图片（风格/角色参考）" — Reference-image mode → Step 3b
  - "有视频，想编辑/修改" — Video-edit mode → Step 3c
```

### Step 3a: Image-to-Video (First-Frame)

1. **first-frame** (required): Ask for the image path or URL.
   - Supported formats: jpg, jpeg, png, webp
   - Local files max 20MB
   - Image: width & height ≥ 300px, ratio between 1:2.5 and 2.5:1

2. **last-frame** (optional, SeeDance only): If model is SeeDance, ask if there is a last-frame image.

```
Question: "有尾帧图片吗？（仅 SeeDance 支持）"
Options:
  - "没有，只用首帧" — Skip last-frame
  - "有" — Collect last-frame path/URL
```

After collecting, proceed to Step 4.

**Note:** HappyHorse i2v mode has no `ratio` parameter — ratio is determined by the input image. SeeDance still accepts `--ratio`.

### Step 3b: Reference-Image Mode

Collect reference images (1–9 images required).

Ask for image paths/URLs:
- Supported formats: jpg, jpeg, png, webp
- Max 20MB per file
- HappyHorse: short edge ≥ 400px recommended

**HappyHorse prompt syntax:** When multiple reference images are provided, the user can use `[Image 1]`, `[Image 2]` etc. in the prompt to refer to specific images. Inform the user of this capability.

**SeeDance additional references** (only if model is SeeDance):
- reference-video (optional, max 3): mp4, mov, max 50MB
- reference-audio (optional, max 3): mp3, wav, max 20MB (must pair with image or video)

After collecting, proceed to Step 4.

### Step 3c: Video-Edit Mode (HappyHorse Only)

If model is SeeDance, inform the user: "视频编辑仅 HappyHorse 模型支持，已自动切换。" and set model to `happyhorse`.

1. **video** (required): Ask for the video path or URL.
   - Supported formats: mp4, mov (H.264 recommended)
   - Duration: 3–60s (output capped at 15s)
   - Max 100MB, ≥ 360px short edge, ≤ 4096px long edge
   - URL only (no base64)

2. **reference-image** (optional, 0–5): Ask if there are reference images for the edit.

3. **audio-setting**:
```
Question: "音频如何处理？"
Options:
  - "自动（模型决定）" — audio_setting: auto
  - "保留原声" — audio_setting: origin
```

After collecting, proceed to Step 4.

**Note:** Video-edit has no `ratio` or `duration` parameters — output matches input video.

### Step 4: Optional Parameter Adjustment

Read session defaults and present. Adjust display based on mode:

**For text-to-video and reference-image modes:**
```
Question: "要调整生成参数吗？当前默认配置：\n  模型: happyhorse\n  分辨率: 1080p\n  比例: 16:9\n  时长: 5 秒"
Options:
  - "用默认，直接生成" — Proceed to Step 5
  - "我要调整参数" — Ask each parameter below
```

**For image-to-video (first-frame) mode:**
```
Question: "要调整生成参数吗？当前默认配置：\n  模型: happyhorse\n  分辨率: 1080p\n  时长: 5 秒"
Options:
  - "用默认，直接生成" — Proceed to Step 5
  - "我要调整参数" — Ask each parameter below
```

**For video-edit mode:** Skip Step 4 entirely — no adjustable generation params (only resolution).

**If adjusting**, ask each parameter one at a time:

**Model:**
```
Question: "模型？"
Options:
  - "happyhorse（推荐）" — Higher quality, video-edit support
  - "doubao-seedance-2-pro" — SeeDance pro, supports last-frame & audio ref
  - "doubao-seedance-2-fast" — SeeDance fast
```

**Resolution:**
```
Question: "分辨率？"
Options:
  - "1080p（推荐）" — High quality (default for HappyHorse)
  - "720p" — Standard quality
  - "480p" — Low quality (SeeDance only)
```

Constraint: if user selects 480p and model is `happyhorse`, inform "HappyHorse 不支持 480p，已切换为 720p。"
Constraint: if user selects 1080p and model is `doubao-seedance-2-fast`, silently upgrade to `doubao-seedance-2-pro` and inform "1080p 需要使用 pro 模型，已自动切换。"

**Aspect ratio** (not shown for i2v or video-edit):
```
Question: "画面比例？"
Options:
  - "16:9" — Landscape, widescreen
  - "9:16" — Portrait, phone screen
  - "1:1" — Square
  - "Other" — 4:3, 3:4, 4:5, 5:4 (4:5/5:4 HappyHorse only)
```

**Duration:**
```
Question: "时长？"
Options:
  - "5 秒（推荐）" — Standard
  - "8 秒" — Medium
  - "10 秒" — Long
  - "Other" — Custom (HappyHorse: 3–15, SeeDance: 4–15)
```

**Seed** (optional): Only ask if the user mentions wanting to reproduce a result. Otherwise skip.

### Step 5: Cost Estimate + Execution Confirmation

**Build and run the estimate command** (no `eval` — direct invocation):

```bash
ESTIMATE=$($CMD_PREFIX estimate \
  --model "happyhorse" \
  --resolution "1080p" \
  --duration 5 \
  --ratio "16:9" \
  --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

For **video-edit mode** — add `--has-video-input` and `--input-video-duration`:
- If user provided a URL: ask duration or use ffprobe if local
- Local files: detect with ffprobe as best-effort:
  ```bash
  INPUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "/path/to/ref.mp4" 2>/dev/null | cut -d. -f1)
  ```
  If ffprobe is unavailable or fails, skip estimate — show "预估不可用" in the summary.

```bash
ESTIMATE=$($CMD_PREFIX estimate \
  --model "happyhorse" \
  --resolution "1080p" \
  --has-video-input \
  --input-video-duration "$INPUT_DUR" \
  --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

Parse estimate result:
```bash
if [ $EXIT_CODE -eq 0 ]; then
  TOKENS=$(echo "$ESTIMATE" | jq -r '.tokens // empty')
  CREDITS=$(echo "$ESTIMATE" | jq -r '.credits // empty')
else
  TOKENS=""
  CREDITS=""
fi
rm -f /tmp/lh-err
```

**Present confirmation summary:**

```
Ready to generate video:

  Prompt: {prompt text}
  模式: {纯文字 / 首帧动画 / 参考图 / 视频编辑}
  模型: {model}
  分辨率: {resolution}
  比例: {ratio or "跟随输入"}
  时长: {duration} 秒 {or "跟随输入"}
  素材: {无 / first-frame: path / references: N 个 / video: path}
  预估费用: {tokens} tokens / {credits} credits    ← or "预估不可用" if estimate failed

  确认生成？
```

Wait for explicit confirmation before executing.

## Execution & Polling

### Submit (foreground)

Invoke `$CMD_PREFIX create` directly — never build a command string with `eval`. Substitute the actual collected values into the command. `$CMD_PREFIX` is either `listenhub video` (internal auth) or `listenhub openapi video` (API Key auth), determined in Step -1.

**Text-to-video:**
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "用户的视频描述" \
  --model "happyhorse" \
  --resolution "1080p" \
  --ratio "16:9" \
  --duration 5 \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**Image-to-video (first-frame):**
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "用户的视频描述" \
  --model "happyhorse" \
  --resolution "1080p" \
  --duration 5 \
  --first-frame "/path/to/first.png" \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**Reference-image mode:**
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "[Image 1]中的角色在城市中行走" \
  --model "happyhorse" \
  --resolution "1080p" \
  --ratio "16:9" \
  --duration 5 \
  --reference-image "/path/to/ref1.png" \
  --reference-image "/path/to/ref2.png" \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**Video-edit mode (HappyHorse):**
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "将背景替换为星空" \
  --model "happyhorse" \
  --resolution "1080p" \
  --reference-video "/path/to/input.mp4" \
  --audio-setting "origin" \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**SeeDance frame mode** (with optional last-frame):
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "用户的视频描述" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 8 \
  --first-frame "/path/to/first.png" \
  --last-frame "/path/to/last.png" \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**SeeDance reference mode** (images, videos, audio):
```bash
RESULT=$($CMD_PREFIX create \
  --prompt "保持参考视频的运镜和色调风格" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 5 \
  --reference-video "/path/to/ref.mp4" \
  --reference-image "/path/to/ref.png" \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**Flags only when needed:**
- `--no-generate-audio` — only if user disabled audio (SeeDance only)
- `--seed 12345` — only if user specified a seed
- `--audio-setting origin` — video-edit mode, keep original audio
- `--input-video-duration N` — only for reference-video URLs (local files auto-detected by CLI)

**Error check:**
```bash
if [ $EXIT_CODE -ne 0 ]; then
  ERROR=$(cat /tmp/lh-err)
  case $EXIT_CODE in
    2) echo "Auth error" ;;
    *) echo "Error: $ERROR" ;;
  esac
  rm -f /tmp/lh-err
  # Handle error per shared/cli-patterns.md
fi
rm -f /tmp/lh-err

TASK_ID=$(echo "$RESULT" | jq -r '.taskId')
```

Tell the user the task is submitted: "任务已提交，ID: {TASK_ID}，正在生成中…"

### Poll (background)

Run with `run_in_background: true` and `timeout: 1260000` (21 minutes):

```bash
TASK_ID="{taskId from above}"
for i in $(seq 1 120); do
  RESULT=$($CMD_PREFIX get "$TASK_ID" --json 2>/dev/null)
  STATUS=$(echo "$RESULT" | jq -r '.status')
  case "$STATUS" in
    success) echo "$RESULT"; exit 0 ;;
    failed) echo "FAILED: $RESULT" >&2; exit 1 ;;
    *) sleep 10 ;;
  esac
done
echo "TIMEOUT" >&2; exit 2
```

Status flow: `pending` → `generating` → `uploading` → `success` | `failed`

### Result Presentation

**On success**, parse the result (note: `get` returns `.id`, not `.taskId`):

```bash
VIDEO_URL=$(echo "$RESULT" | jq -r '.videoUrl')
DURATION=$(echo "$RESULT" | jq -r '.duration')
RESOLUTION=$(echo "$RESULT" | jq -r '.resolution')
RATIO=$(echo "$RESULT" | jq -r '.ratio')
SEED=$(echo "$RESULT" | jq -r '.seed')
CREDITS=$(echo "$RESULT" | jq -r '.creditCharged')
```

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Display video URL and metadata.

Present:
```
视频已生成！

  URL: {videoUrl}
  时长: {duration}s
  分辨率: {resolution}
  比例: {ratio}
  Seed: {seed}
  消耗: {creditCharged} credits
```

**`download` or `both`**: Save to **current working directory** with a topic-based slug per `shared/config-pattern.md` § Artifact Naming:

```bash
SLUG="{topic-slug}"  # e.g. "赛博朋克城市夜景"
NAME="${SLUG}.mp4"
BASE="${NAME%.*}"; EXT="${NAME##*.}"; i=2
while [ -e "$NAME" ]; do NAME="${BASE}-${i}.${EXT}"; i=$((i+1)); done
curl -sS -o "$NAME" "$VIDEO_URL"
```

Present:
```
已保存到当前目录：
  {NAME}
```

**On failure**: Display error and suggest checking prompt or parameters.

**On timeout**: Tell the user to check later:

> 生成超时。你可以稍后用 `listenhub video get {taskId} --json`（或 `listenhub openapi video get {taskId} --json`）查询结果。

## Querying Past Tasks

Users can ask to check a previous task or list recent tasks:

```bash
# Get a specific task
$CMD_PREFIX get "{taskId}" --json

# List recent tasks
$CMD_PREFIX list --json
```

Present results using the same format as the success output above.

## Error Handling

Reuse `shared/cli-patterns.md` standard error codes:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Parse JSON output |
| 1 | General error | Display stderr to user |
| 2 | Auth error | Internal: re-login via `listenhub auth login`. OpenAPI: check API Key via `listenhub openapi config show` |
| 3 | Timeout | Suggest checking task status later |

## API Reference

- CLI authentication: `shared/cli-authentication.md`
- CLI execution patterns: `shared/cli-patterns.md`
- Config pattern: `shared/config-pattern.md`
- Output mode: `shared/output-mode.md`
- HappyHorse API: `references/happyhorse-api.md`

## Composability

| Direction | Description |
|-----------|-------------|
| `listenhub` router → `video-gen` | Routed when user mentions video generation via `/listenhub` |
| `listenhub-cli` router → `video-gen` | Same routing via `/listenhub-cli` |
| `video-gen` → (none) | Independent terminal skill, no downstream dependencies |

## Examples

### Text-to-video (HappyHorse)

> "帮我生成一个视频：赛博朋克城市夜景"

```bash
listenhub video create \
  --prompt "赛博朋克城市夜景" \
  --model "happyhorse" \
  --resolution "1080p" \
  --ratio "16:9" \
  --duration 5 \
  --no-wait --json
```

### Image-to-video (HappyHorse)

> "把这张图片变成动画视频" + 提供图片路径

```bash
listenhub video create \
  --prompt "将静态场景转化为流畅动画" \
  --model "happyhorse" \
  --resolution "1080p" \
  --duration 5 \
  --first-frame "/path/to/scene.png" \
  --no-wait --json
```

### Reference-Image Mode (HappyHorse)

> "参考这两张图片的风格，生成一段视频"

```bash
listenhub video create \
  --prompt "[Image 1]中的角色在[Image 2]的场景中漫步" \
  --model "happyhorse" \
  --resolution "1080p" \
  --ratio "16:9" \
  --duration 5 \
  --reference-image "/path/to/character.png" \
  --reference-image "/path/to/scene.png" \
  --no-wait --json
```

### Video Edit (HappyHorse)

> "把这个视频的背景换成星空"

```bash
listenhub video create \
  --prompt "将背景替换为深邃的星空，保持人物动作不变" \
  --model "happyhorse" \
  --resolution "1080p" \
  --reference-video "/path/to/input.mp4" \
  --audio-setting "origin" \
  --no-wait --json
```

### SeeDance Frame Mode

> "用首帧和尾帧生成过渡动画"

```bash
listenhub video create \
  --prompt "从白天自然过渡到夜晚" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 8 \
  --first-frame "/path/to/day.png" \
  --last-frame "/path/to/night.png" \
  --no-wait --json
```
