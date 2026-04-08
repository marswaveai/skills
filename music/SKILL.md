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

- User wants to generate original AI music from a prompt
- User wants to create a cover from reference audio
- User says "音乐", "music", "生成音乐", "generate music", "翻唱", "cover", "作曲", "compose", "create a song", or "做一首歌"

## When NOT to Use

- User wants text-to-speech reading (use `/speech`)
- User wants a podcast discussion (use `/podcast`)
- User wants an explainer video with narration (use `/explainer`)
- User wants to transcribe audio to text (use `/asr`)

## Purpose

Generate original AI music from text prompts, or create cover versions from reference audio. Two modes:

1. **Generate** (original): Create a new song from a text prompt, with optional style, title, and instrumental-only options.
2. **Cover**: Transform a reference audio file into a new version, with optional style modifications.

## Hard Constraints

- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/cli-patterns.md` for execution modes, error handling, and interaction patterns
- Always follow `shared/cli-authentication.md` for auth checks
- Never save files to `~/Downloads/` or `.listenhub/` — save artifacts to the current working directory with friendly topic-based names (see `shared/config-pattern.md` § Artifact Naming)
- No speakers involved — music generation does not use speaker selection
- Audio file constraints for cover mode: mp3, wav, flac, m4a, ogg, aac; max 20MB
- Long timeout: 600s default. Use `run_in_background: true` with `timeout: 660000`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any CLI command until the user has explicitly confirmed.

</HARD-GATE>

## Step -1: CLI Auth Check

Follow `shared/cli-authentication.md`. If the CLI is not installed or the user is not logged in, auto-install and auto-login — never ask the user to run commands manually.

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
  语言偏好：{zh / en / 未设置}
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
if [ "$LANGUAGE" != "null" ]; then
  NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg lang "$LANGUAGE" '. + {"language": $lang}')
fi
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

## Interaction Flow

### Step 1: Mode

Ask the user which mode they want, unless the intent is already clear from their message (e.g., "翻唱" or "cover" implies cover mode; "作曲" or "compose" implies generate mode).

```
Question: "选择音乐生成模式："
Options:
  - "原创 (Generate)" — 从文字描述生成全新歌曲
  - "翻唱 (Cover)" — 基于参考音频生成新版本
```

### Step 2a: Prompt (generate mode)

If the user chose **Generate**, ask for the song description:

> "请描述你想要的歌曲（主题、情绪、歌词片段等）："

Accept free text. This maps to `--prompt`.

### Step 2b: Reference Audio (cover mode)

If the user chose **Cover**, ask for the reference audio:

> "请提供参考音频文件路径或 URL："

Accept a local file path or URL. This maps to `--audio`.

**Validate the input:**

- If a local path: verify the file exists and check the extension is one of: `mp3`, `wav`, `flac`, `m4a`, `ogg`, `aac`
- If a URL: accept as-is (the CLI will validate)
- Check file size does not exceed 20 MB for local files:
  ```bash
  FILE_SIZE=$(stat -f%z "{path}" 2>/dev/null || stat -c%s "{path}" 2>/dev/null)
  if [ "$FILE_SIZE" -gt 20971520 ]; then
    echo "File exceeds 20 MB limit"
  fi
  ```

If validation fails, inform the user and re-ask.

Optionally, the user may also provide a prompt to guide the cover style.

### Step 3: Style (optional)

Ask for an optional style descriptor:

> "指定音乐风格？（如 pop、rock、jazz、电子、古风等，留空则由 AI 自动选择）"

Accept free text or empty. This maps to `--style`.

### Step 4: Title (optional)

Ask for an optional title:

> "歌曲标题？（留空则自动生成）"

Accept free text or empty. This maps to `--title`.

### Step 5: Instrumental

```
Question: "是否纯音乐（无人声）？"
Options:
  - "否，带人声（默认）"
  - "是，纯音乐"
```

Default is "no" (with vocals). If the user selects "是", add `--instrumental` flag.

### Step 6: Confirm & Generate

Summarize all choices:

**Generate mode:**
```
准备生成音乐：

  模式：原创 (Generate)
  描述：{prompt}
  风格：{style / 自动}
  标题：{title / 自动}
  人声：{带人声 / 纯音乐}

  确认？
```

**Cover mode:**
```
准备生成音乐：

  模式：翻唱 (Cover)
  参考音频：{path-or-url}
  描述：{prompt / 无}
  风格：{style / 自动}
  标题：{title / 自动}
  人声：{带人声 / 纯音乐}

  确认？
```

Wait for explicit confirmation before running any CLI command.

## Workflow

1. **Submit (background)**: Run the CLI command with `run_in_background: true` and `timeout: 660000`:

   **Generate mode:**
   ```bash
   listenhub music generate \
     --prompt "{prompt}" \
     --style "{style}" \
     --title "{title}" \
     --instrumental \
     --json
   ```

   **Cover mode:**
   ```bash
   listenhub music cover \
     --audio "{path-or-url}" \
     --prompt "{prompt}" \
     --style "{style}" \
     --title "{title}" \
     --instrumental \
     --json
   ```

   Flag notes:
   - `--prompt` — text description of the music (required for generate, optional for cover)
   - `--audio` — reference audio file path or URL (cover mode only, required)
   - `--style` — optional style/genre hint; omit if not provided
   - `--title` — optional track title; omit if not provided
   - `--instrumental` — add this flag for instrumental-only (no vocals); omit if not selected
   - Omit `--prompt` in cover mode if not provided

   The CLI handles polling internally. Music generation takes up to 10 minutes.

2. Tell the user the task is submitted and that they will be notified when it finishes.

3. When notified of completion, **present the result**:

   Parse the CLI JSON output for key fields:
   ```bash
   AUDIO_URL=$(echo "$RESULT" | jq -r '.audioUrl')
   TITLE=$(echo "$RESULT" | jq -r '.title // "Untitled"')
   DURATION=$(echo "$RESULT" | jq -r '.duration // empty')
   CREDITS=$(echo "$RESULT" | jq -r '.credits // empty')
   ```

   Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

   **`inline` or `both`**: Display audio URL as a clickable link.

   ```
   音乐已生成！

   标题：{title}
   在线收听：{audioUrl}
   时长：{duration}s
   消耗积分：{credits}
   ```

   **`download` or `both`**: Also download the file. Generate a slug from the title following `shared/config-pattern.md` § Artifact Naming.
   ```bash
   SLUG="{slug}"  # e.g. "summer-breeze"
   NAME="${SLUG}.mp3"
   # Dedup: if file exists, append -2, -3, etc.
   BASE="${NAME%.*}"; EXT="${NAME##*.}"; i=2
   while [ -e "$NAME" ]; do NAME="${BASE}-${i}.${EXT}"; i=$((i+1)); done
   curl -sS -o "$NAME" "{audioUrl}"
   ```
   Present:
   ```
   已保存到当前目录：
     {NAME}
   ```

### After Successful Generation

Update config with the language used this session if the user explicitly specified one:

```bash
if [ -n "$LANGUAGE" ]; then
  NEW_CONFIG=$(echo "$CONFIG" | jq --arg lang "$LANGUAGE" '. + {"language": $lang}')
  echo "$NEW_CONFIG" > "$CONFIG_PATH"
fi
```

**Estimated times**:
- Music generation: 5-10 minutes

## Resources

- CLI authentication: `shared/cli-authentication.md`
- CLI patterns: `shared/cli-patterns.md`
- Config pattern: `shared/config-pattern.md`
- Output mode: `shared/output-mode.md`

## Composability

- **Invokes**: nothing
- **Invoked by**: content-planner (Phase 3)

## Examples

**Generate original:**

> "帮我做一首关于夏天海边的歌"

1. Detect: generate mode ("做一首歌")
2. Read config (first run: create defaults with `outputMode: "download"`)
3. Infer: mode = generate, prompt = "夏天海边的歌"
4. Ask: style? title? instrumental?
5. Confirm summary → user confirms

```bash
listenhub music generate \
  --prompt "关于夏天海边的歌" \
  --json
```

Wait for CLI to return result, then download `{slug}.mp3` to cwd.

**Cover from file:**

> "用这个音频翻唱一下 demo.mp3，jazz 风格"

1. Detect: cover mode ("翻唱")
2. Validate: `demo.mp3` exists, is a supported format, under 20 MB
3. Infer: style = "jazz" from user input
4. Ask: title? instrumental?
5. Confirm summary → user confirms

```bash
listenhub music cover \
  --audio "demo.mp3" \
  --style "jazz" \
  --json
```

Wait for CLI to return result, then download `{slug}.mp3` to cwd.

**Generate instrumental:**

> "Create an instrumental electronic track for a game intro"

1. Detect: generate mode ("Create ... track")
2. Infer: style = "electronic", instrumental = yes
3. Ask: title?
4. Confirm summary → user confirms

```bash
listenhub music generate \
  --prompt "instrumental electronic track for a game intro" \
  --style "electronic" \
  --instrumental \
  --json
```

Wait for CLI to return result, then download `{slug}.mp3` to cwd.
