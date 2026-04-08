---
name: slides
description: |
  Create slide decks with AI-generated visuals and optional narration. Triggers on:
  "幻灯片", "PPT", "slides", "slide deck", "做幻灯片", "create slides",
  "presentation".
metadata:
  openclaw:
    emoji: "📊"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
---

## When to Use

- User wants to create a slide deck or presentation
- User asks to make "slides", "幻灯片", or "PPT"
- User wants a visual presentation with optional narration

## When NOT to Use

- User wants a narrated video without slides (use `/explainer`)
- User wants audio-only content (use `/speech` or `/podcast`)
- User wants a podcast-style discussion (use `/podcast`)
- User wants to generate a standalone image (use `/image-gen`)

## Purpose

Generate slide decks that combine structured visual pages with optional voice narration. Ideal for business presentations, educational content, and topic overviews. By default, slides are generated without audio — narration can be enabled on request.

## Hard Constraints

- Always check CLI authentication following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for command structure, execution, errors, and interaction patterns
- Always read config following `shared/config-pattern.md` before any interaction
- Follow `shared/speaker-selection.md` when narration is enabled
- Never save files to `~/Downloads/` or `.listenhub/` — save artifacts to the current working directory with friendly topic-based names (see `shared/config-pattern.md` § Artifact Naming)
- Mode is always `slides` — never `info` or `story` (those are for `/explainer`)
- Only 1 speaker supported (when narration is enabled)
- Default behavior: skip audio (no narration). User must opt in with `--no-skip-audio`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation CLI command until the user has explicitly confirmed.

</HARD-GATE>

## Step -1: CLI Auth Check

Follow `shared/cli-authentication.md`. If the CLI is not installed or the user is not logged in, stop and guide them through setup.

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

> What would you like to create a slide deck about?

Accept: topic description, text content, URLs as source material.

### Step 2: Source URLs (optional)

If the user provided URLs in Step 1, collect them. Otherwise ask:

> Do you have any reference URLs to include as source material? (optional — type "skip" to proceed without)

Each URL will be passed as a `--source-url` flag (repeatable).

### Step 3: Language

If `config.language` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Content in Mandarin Chinese
  - "English (en)" — Content in English
```

### Step 4: Narration

Ask the user:

```
Question: "需要语音旁白吗？（默认否）"
Options:
  - "不需要" — Slides only, no narration
  - "需要旁白" — Add voice narration to slides
```

Default is no narration.

### Step 5: Speaker Selection (only if narration enabled)

**Skip this step entirely if narration is not enabled.**

Follow `shared/speaker-selection.md`:
- If `config.defaultSpeakers.{language}` is set → use saved speaker silently
- If not set → use **built-in default** from `shared/speaker-selection.md` for the language
- Show the speaker in the confirmation summary (Step 7) — user can change from there if desired
- Only show the full speaker list if the user explicitly asks to change voice

Only 1 speaker is supported.

### Step 6: Style (optional)

If the user mentioned a specific visual style, capture it. Otherwise skip — do not ask.

Style is passed as `--style "{style}"` when specified.

### Step 7: Confirm & Generate

Summarize all choices:

**Without narration:**
```
Ready to generate slides:

  Topic: {topic}
  Language: {language}
  Narration: None
  Sources: {urls or "none"}

  Proceed?
```

**With narration:**
```
Ready to generate slides:

  Topic: {topic}
  Language: {language}
  Narration: Yes
  Speaker: {speaker name}
  Sources: {urls or "none"}

  Proceed?
```

Wait for explicit confirmation before running any CLI command.

## Workflow

1. **Submit (foreground)** with `--no-wait` to get the creation ID:

   **Base command:**
   ```bash
   RESULT=$(listenhub slides create \
     --query "{topic}" \
     --lang {language} \
     --image-size 2K \
     --aspect-ratio 16:9 \
     --no-wait \
     --json)
   ID=$(echo "$RESULT" | jq -r '.id')
   ```

   **If narration enabled**, add:
   ```
   --no-skip-audio --speaker "{speakerName}"
   ```

   **If style specified**, add:
   ```
   --style "{style}"
   ```

   **If source URLs provided**, add for each URL:
   ```
   --source-url "{url}"
   ```

2. Tell the user the task is submitted.

3. **Poll (background)**: Run the following with `run_in_background: true` and `timeout: 360000`:

   ```bash
   ID="<id-from-step-1>"
   for i in $(seq 1 60); do
     RESULT=$(listenhub creation get "$ID" --json 2>/dev/null)
     STATUS=$(echo "$RESULT" | jq -r '.status // "processing"')

     case "$STATUS" in
       completed) echo "$RESULT"; exit 0 ;;
       failed) echo "FAILED: $RESULT" >&2; exit 1 ;;
       *) sleep 10 ;;
     esac
   done
   echo "TIMEOUT" >&2; exit 2
   ```

4. When notified, **parse and present the result**:

   Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

   Extract from the completed result:
   - `episodeId` — for the online link
   - `pageCount` — number of slides generated
   - `credits` — credits consumed

   **`inline` or `both`**: Present the result inline.

   ```
   幻灯片已生成！

   「{title}」

   在线查看：https://listenhub.ai/app/slides/{episodeId}
   页数：{pageCount}
   消耗积分：{credits}
   ```

   **If narration was enabled**, also show:
   ```
   音频链接：{audioUrl}
   ```

   **`download` or `both`**: Also save files locally. Generate a topic slug following `shared/config-pattern.md` § Artifact Naming.

   Create `{slug}-slides/` folder (dedup if exists):
   - Write `script.md` inside (the slide script/outline)
   - If narration was enabled: download `audio.mp3` inside

   ```bash
   DIR="{slug}-slides"
   i=2; while [ -d "$DIR" ]; do DIR="{slug}-slides-${i}"; i=$((i+1)); done
   mkdir -p "$DIR"

   # Save script
   echo "$RESULT" | jq -r '.script // .content // ""' > "$DIR/script.md"

   # If narration enabled, download audio
   AUDIO_URL=$(echo "$RESULT" | jq -r '.audioUrl // empty')
   [ -n "$AUDIO_URL" ] && curl -sS -o "$DIR/audio.mp3" "$AUDIO_URL"
   ```

   Present:
   ```
   已保存到当前目录：
     {slug}-slides/
       script.md
       audio.mp3    (if narration enabled)
   ```

### After Successful Generation

Update config with the choices made this session:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  '. + {"language": $lang}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

If narration was enabled and a speaker was used:
```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  --argjson ids '["speakerId"]' \
  '.defaultSpeakers[$lang] = $ids')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

**Estimated time**: 3-6 minutes

## API Reference

- CLI authentication: `shared/cli-authentication.md`
- CLI patterns: `shared/cli-patterns.md`
- Speaker list (CLI): `shared/cli-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Config pattern: `shared/config-pattern.md`
- Output mode: `shared/output-mode.md`

## Composability

- **Invokes**: speakers CLI (for speaker selection when narration enabled)
- **Invoked by**: content-planner (Phase 3)

## Example

**User**: "帮我做一个关于量子计算的幻灯片"

**Agent workflow**:
1. Topic: "量子计算"
2. Source URLs: skip (none provided)
3. Language: pre-filled from config or ask → "zh"
4. Narration: ask → "不需要"
5. Confirm and generate

```bash
RESULT=$(listenhub slides create \
  --query "量子计算" \
  --lang zh \
  --image-size 2K \
  --aspect-ratio 16:9 \
  --no-wait \
  --json)
ID=$(echo "$RESULT" | jq -r '.id')
```

Poll until completed, then present the online link and page count.

**User**: "Create slides about React hooks with narration"

**Agent workflow**:
1. Topic: "React hooks"
2. Source URLs: skip
3. Language: ask → "en"
4. Narration: ask → "需要旁白"
5. Speaker: use built-in default "Mars" (cozy-man-english)
6. Confirm and generate

```bash
RESULT=$(listenhub slides create \
  --query "React hooks" \
  --lang en \
  --image-size 2K \
  --aspect-ratio 16:9 \
  --no-skip-audio \
  --speaker "Mars" \
  --no-wait \
  --json)
ID=$(echo "$RESULT" | jq -r '.id')
```

Poll until completed, then present the online link, page count, and audio link.
