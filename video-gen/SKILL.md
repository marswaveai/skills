---
name: video-gen
metadata:
  openclaw:
    emoji: "🎬"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
description: |
  Generate AI videos from text prompts or reference materials (SeeDance).
  Triggers on: "生成视频", "做视频", "video generation", "text to video",
  "seedance", "create video", "视频生成".
---

## When to Use

- User wants to generate an AI video from a text description
- User wants to animate a still image (first-frame / last-frame)
- User has reference materials (images, videos, audio) to guide video generation
- User says "生成视频", "做视频", "video generation", "text to video", "seedance"

## When NOT to Use

- User wants an explainer video with narration and AI visuals (use `/explainer`)
- User wants to edit or trim an existing video (not supported)
- User wants to transcribe audio/video to text (use `/asr`)
- User wants to generate an image (use `/image-gen`)

## Purpose

Generate AI videos using the ListenHub CLI's SeeDance integration. Three generation modes:

1. **Text-to-video**: Pure text prompt, no reference materials
2. **Frame mode**: First-frame image (+ optional last-frame) to animate a still into video
3. **Reference mode**: Reference images, videos, or audio to guide generation style

## Hard Constraints

- Always check CLI auth following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for CLI execution, errors, and interaction patterns
- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/output-mode.md` for result presentation — `download` mode saves `{slug}.mp4` to cwd with dedupe per `shared/config-pattern.md` § Artifact Naming
- Frame mode and Reference mode are mutually exclusive — never mix them
- Always use `--no-wait --json` for video creation — generation takes minutes
- Never use `eval` to execute CLI commands — always invoke `listenhub video ...` directly with proper quoting

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options
as plain text. Ask one question at a time. Wait for the user's answer before
proceeding to the next step. After all parameters are collected, summarize the
choices and ask the user to confirm. Do NOT call the video generation command
until the user has explicitly confirmed.
</HARD-GATE>

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
- model: `doubao-seedance-2-pro`
- resolution: `720p`
- ratio: `16:9`
- duration: `5`
- generateAudio: `true`

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
  - "有图片，想做首帧/尾帧动画" — Frame mode → Step 3a
  - "有参考素材（图/视频/音频）" — Reference mode → Step 3b
```

### Step 3a: Frame Mode Parameters

1. **first-frame** (required): Ask for the image path or URL.
   - Supported formats: jpg, jpeg, png, webp, gif
   - Local files max 10MB

2. **last-frame** (optional): Ask if there is a last-frame image.

```
Question: "有尾帧图片吗？"
Options:
  - "没有，只用首帧" — Skip last-frame
  - "有" — Collect last-frame path/URL
```

After collecting, proceed to Step 4.

### Step 3b: Reference Mode Parameters

Collect references in order. Each is optional, but at least one must be provided.

1. **reference-image** (optional, max 9): Ask for image paths/URLs.
   - Supported formats: jpg, jpeg, png, webp, gif
   - Max 10MB per file

2. **reference-video** (optional, max 3): Ask for video paths/URLs.
   - Supported formats: mp4, mov
   - Local files max 50MB
   - For URLs: also ask for `--input-video-duration` (2–15 seconds)
   - Local files: CLI auto-detects duration — no need to ask

3. **reference-audio** (optional, max 3): Ask for audio paths/URLs.
   - Supported formats: mp3, wav
   - Local files max 20MB
   - Must be paired with reference-image or reference-video

```
Question: "要提供哪些参考素材？"
Options:
  - "参考图片" — Collect image paths/URLs
  - "参考视频" — Collect video paths/URLs
  - "参考音频" — Collect audio paths/URLs (must pair with image or video)
  - "收集完毕" — Proceed to Step 4
```

Ask iteratively until the user says "收集完毕" or provides at least one reference.

After collecting, proceed to Step 4.

### Step 4: Optional Parameter Adjustment

Read session defaults and present:

```
Question: "要调整生成参数吗？当前默认配置：\n  模型: doubao-seedance-2-pro\n  分辨率: 720p\n  比例: 16:9\n  时长: 5 秒\n  生成音频: 是"
Options:
  - "用默认，直接生成" — Proceed to Step 5
  - "我要调整参数" — Ask each parameter below
```

**If adjusting**, ask each parameter one at a time:

**Model:**
```
Question: "模型？"
Options:
  - "doubao-seedance-2-pro（推荐）" — Higher quality, required for 1080p
  - "doubao-seedance-2-fast" — Faster generation
```

**Resolution:**
```
Question: "分辨率？"
Options:
  - "480p" — Low quality, fastest
  - "720p（推荐）" — Standard quality
  - "1080p" — High quality (requires pro model)
```

Constraint: if user selects 1080p and model is `fast`, silently upgrade to `pro` and inform: "1080p 需要使用 pro 模型，已自动切换。"

**Aspect ratio:**
```
Question: "画面比例？"
Options:
  - "16:9" — Landscape, widescreen
  - "9:16" — Portrait, phone screen
  - "1:1" — Square
  - "Other" — 4:3, 3:4, 21:9
```

**Duration:**
```
Question: "时长（4–15 秒）？"
Options:
  - "5 秒（推荐）" — Standard
  - "8 秒" — Medium
  - "10 秒" — Long
  - "Other" — Custom (4–15)
```

**Audio:**
```
Question: "生成视频配音？"
Options:
  - "是（推荐）" — Generate audio with video
  - "否" — Video only
```

**Seed** (optional): Only ask if the user mentions wanting to reproduce a result. Otherwise skip.

### Step 5: Cost Estimate + Execution Confirmation

**Build and run the estimate command** (no `eval` — direct invocation):

For **text-to-video, frame mode, or reference mode without reference-video**:
```bash
ESTIMATE=$(listenhub video estimate \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --duration 5 \
  --ratio "16:9" \
  --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

For **reference mode with reference-video** — need `--has-video-input` and `--input-video-duration`:
- If user provided a URL: use the `--input-video-duration` value they gave in Step 3b.
- If user provided a local file: detect duration with ffprobe as best-effort:
  ```bash
  INPUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "/path/to/ref.mp4" 2>/dev/null | cut -d. -f1)
  ```
  If ffprobe is unavailable or fails, skip estimate — show "预估不可用" in the summary.

```bash
ESTIMATE=$(listenhub video estimate \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --duration 5 \
  --ratio "16:9" \
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
  模式: {纯文字 / Frame / Reference}
  模型: {model}
  分辨率: {resolution}
  比例: {ratio}
  时长: {duration} 秒
  音频: {是 / 否}
  素材: {无 / first-frame: path / references: N 个}
  预估费用: {tokens} tokens / {credits} credits    ← or "预估不可用" if estimate failed

  确认生成？
```

Wait for explicit confirmation before executing.

## Execution & Polling

### Submit (foreground)

Invoke `listenhub video create` directly — never build a command string with `eval`. Substitute the actual collected values into the command. The examples below show all possible flags; include only the ones relevant to the current mode.

**Text-to-video:**
```bash
RESULT=$(listenhub video create \
  --prompt "用户的视频描述" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 5 \
  --no-wait --json 2>/tmp/lh-err)
EXIT_CODE=$?
```

**Frame mode** (add `--first-frame` and optionally `--last-frame`):
```bash
RESULT=$(listenhub video create \
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

**Reference mode** (add `--reference-image`, `--reference-video`, `--reference-audio` as needed):
```bash
RESULT=$(listenhub video create \
  --prompt "用户的视频描述" \
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
- `--no-generate-audio` — only if user disabled audio
- `--seed 12345` — only if user specified a seed
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
  RESULT=$(listenhub video get "$TASK_ID" --json 2>/dev/null)
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

> 生成超时。你可以稍后用 `listenhub video get {taskId} --json` 查询结果。

## Querying Past Tasks

Users can ask to check a previous task or list recent tasks:

```bash
# Get a specific task
listenhub video get "{taskId}" --json

# List recent tasks
listenhub video list --json
```

Present results using the same format as the success output above.

## Error Handling

Reuse `shared/cli-patterns.md` standard error codes:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Parse JSON output |
| 1 | General error | Display stderr to user |
| 2 | Auth error | Auto re-login via `listenhub auth login` |
| 3 | Timeout | Suggest `listenhub video get {taskId}` to check later |

## API Reference

- CLI authentication: `shared/cli-authentication.md`
- CLI execution patterns: `shared/cli-patterns.md`
- Config pattern: `shared/config-pattern.md`
- Output mode: `shared/output-mode.md`

## Composability

| Direction | Description |
|-----------|-------------|
| `listenhub` router → `video-gen` | Routed when user mentions video generation via `/listenhub` |
| `listenhub-cli` router → `video-gen` | Same routing via `/listenhub-cli` |
| `video-gen` → (none) | Independent terminal skill, no downstream dependencies |

## Examples

### Text-to-video

> "帮我生成一个视频：赛博朋克城市夜景"

1. Prompt: "赛博朋克城市夜景"
2. Mode: "没有，纯文字生成"
3. Parameters: use defaults
4. Estimate → confirm → execute

```bash
listenhub video create \
  --prompt "赛博朋克城市夜景" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 5 \
  --no-wait --json
```

### Frame Mode

> "把这张图片变成动画视频" + 提供图片路径

1. Prompt: "将静态场景转化为流畅动画"
2. Mode: "有图片，做首帧动画"
3. first-frame: `/path/to/scene.png`, no last-frame
4. Adjust duration to 8s
5. Estimate → confirm → execute

```bash
listenhub video create \
  --prompt "将静态场景转化为流畅动画" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 8 \
  --first-frame "/path/to/scene.png" \
  --no-wait --json
```

### Reference Mode

> "参考这个视频的风格，生成一个类似的新视频"

1. Prompt: "保持参考视频的运镜和色调风格"
2. Mode: "有参考素材"
3. reference-video: `/path/to/ref.mp4` (local file, CLI auto-detects duration)
4. Parameters: use defaults
5. Estimate (ffprobe for duration, or skip if unavailable) → confirm → execute

```bash
listenhub video create \
  --prompt "保持参考视频的运镜和色调风格" \
  --model "doubao-seedance-2-pro" \
  --resolution "720p" \
  --ratio "16:9" \
  --duration 5 \
  --reference-video "/path/to/ref.mp4" \
  --no-wait --json
```
