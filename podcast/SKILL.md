---
name: podcast
description: |
  Create podcasts from topics, URLs, or text. Triggers on: "做播客", "podcast",
  "播客", "录一期节目", "chat about", "discuss", "debate", "dialogue",
  "make a podcast about".
metadata:
  openclaw:
    emoji: "🎙️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
---

## When to Use

- User wants to create a podcast episode on any topic
- User provides a URL or text and wants it turned into a podcast discussion
- User asks for a "debate", "dialogue", or "discussion" format
- User says "podcast", "播客", or "录一期节目"

## When NOT to Use

- User wants text-to-speech reading (use `/speech`)
- User wants an explainer video with visuals (use `/explainer`)
- User wants to generate an image (use `/image-gen`)
- User only wants to extract content from a URL without generating audio (use `/content-parser`)

## Purpose

Generate podcast episodes with 1-2 AI speakers discussing a topic. Supports quick overviews, deep analysis, and debate formats. Input can be a topic description, URL(s), or text. Output is a full audio episode with transcript.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Use saved speaker preferences or the built-in defaults from `shared/speaker-selection.md`; only fetch from the speakers API when the user explicitly wants to change voices
- Never fabricate API endpoints or parameters
- Always read config following `shared/config-pattern.md` before any interaction
- Always follow `shared/speaker-selection.md` for speaker selection (text table + free-text input)
- Never save files to `~/Downloads/` — use `.listenhub/podcast/` from config

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.

</HARD-GATE>

## Step -1: API Key Check

Follow `shared/config-pattern.md` § API Key Check. If the key is missing, stop immediately.

## Step 0: Config Setup

Follow `shared/config-pattern.md` Step 0 (Zero-Question Boot).

**If file doesn't exist** — silently create with defaults and proceed:
```bash
mkdir -p ".listenhub/podcast"
echo '{"outputDir":".listenhub","outputMode":"inline","language":null,"defaultMode":null,"defaultMethod":"one-step","defaultSpeakers":{}}' > ".listenhub/podcast/config.json"
CONFIG_PATH=".listenhub/podcast/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```
**Do NOT ask any setup questions.** Proceed directly to the Interaction Flow.

**If file exists** — read config silently and proceed:
```bash
CONFIG_PATH=".listenhub/podcast/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/podcast/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

### Setup Flow (user-initiated reconfigure only)

Only run when the user explicitly asks to reconfigure. Display current settings:
```
当前配置 (podcast)：
  输出方式：{inline / download / both}
  语言偏好：{zh / en / 未设置}
  默认模式：{quick / deep / debate / 未设置}
  默认生成方式：{one-step / two-step}
  默认主播：{speakerName(s) / 使用内置默认}
```

Then ask these questions in order and save:

1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.

2. **Language** (optional): "默认语言？"
   - "中文 (zh)"
   - "English (en)"
   - "每次手动选择" → keep `null`

3. **Mode** (optional): "默认播客模式？"
   - "Quick — 简短概述"
   - "Deep — 深度分析"
   - "Debate — 辩论对话"
   - "每次手动选择" → keep `null`

4. **Method** (optional): "默认生成方式？"
   - "一步生成（推荐）" → `defaultMethod: "one-step"`
   - "两步生成（先预览文本）" → `defaultMethod: "two-step"`
   - "每次手动选择" → keep `null`

After collecting answers, save immediately:
```bash
# Follow shared/output-mode.md § Save to Config
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg m "$OUTPUT_MODE" \
  --arg lang "$LANGUAGE" \
  --arg mode "$MODE" \
  --arg method "$METHOD" \
  '. + {
    "outputMode": $m,
    "language": (if ($lang == "" or $lang == "null") then null else $lang end),
    "defaultMode": (if ($mode == "" or $mode == "null") then null else $mode end),
    "defaultMethod": (if ($method == "" or $method == "null") then null else $method end)
  }')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

## Interaction Flow

### Step 1: Topic / Content Source

Free text input. Ask the user:

> What topic or content would you like to turn into a podcast?

Accept: topic description, URL, or pasted text.

### Step 2: Mode

If `config.defaultMode` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "What podcast generation mode?"
Options:
  - "Quick" — Short, concise overview (~5 min)
  - "Deep" — Thorough analysis with more detail (~10-15 min)
  - "Debate" — Two speakers with opposing views (requires 2 speakers)
```

### Step 3: Language

If `config.language` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Content in Mandarin Chinese
  - "English (en)" — Content in English
```

### Step 4: Speaker Count

```
Question: "How many speakers?"
Options:
  - "1 speaker (solo)" — Monologue style
  - "2 speakers (dialogue)" — Conversation style
```

Note: Debate mode automatically sets 2 speakers.

### Step 5: Speaker Selection

Follow `shared/speaker-selection.md`:
- If `config.defaultSpeakers.{language}` is set → use saved speakers silently
- If not set → use **built-in defaults** from `shared/speaker-selection.md` (no question asked)
- Show the speaker(s) in the confirmation summary (Step 8) — user can change from there if desired
- Only show the full speaker list if the user explicitly asks to change voices

For 2-speaker mode (dialogue/debate): use Primary + Secondary defaults for the language.

### Step 6: Reference Materials (optional)

```
Question: "Any reference materials to include?"
Options:
  - "Yes, URL(s)" — Provide URLs to analyze
  - "Yes, text" — Paste reference text
  - "No references" — Generate from topic alone
```

### Step 7: Generation Method

If `config.defaultMethod` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "How would you like to generate?"
Options:
  - "One step (recommended)" — Generate text + audio together, faster
  - "Two steps (review first)" — Generate text, review/edit, then generate audio
```

### Step 8: Confirm & Generate

Summarize all choices:

```
Ready to generate podcast:

  Topic: {topic}
  Mode: {mode}
  Language: {language}
  Speakers: {speaker name(s)}
  References: {yes/no}
  Method: {one-step/two-step}

  Proceed?
```

Wait for explicit confirmation before calling any API.

## Workflow

### One-Step Generation

1. **Submit (foreground)**: `POST /podcast/episodes` with collected parameters → extract `episodeId`
2. Tell the user the task is submitted
3. **Poll (background)**: Run the following **exact** bash command with `run_in_background: true` and `timeout: 600000`. Do NOT use python3, awk, or any other JSON parser — use `jq` as shown:

   ```bash
   EPISODE_ID="<id-from-step-1>"
   for i in $(seq 1 30); do
     RESULT=$(curl -sS "https://api.marswave.ai/openapi/v1/podcast/episodes/$EPISODE_ID" \
       -H "Authorization: Bearer $LISTENHUB_API_KEY" 2>/dev/null)
     STATUS=$(echo "$RESULT" | tr -d '\000-\037\177' | jq -r '.data.processStatus // "pending"')
     case "$STATUS" in
       success|completed) echo "$RESULT"; exit 0 ;;
       failed|error) echo "FAILED: $RESULT" >&2; exit 1 ;;
       *) sleep 10 ;;
     esac
   done
   echo "TIMEOUT" >&2; exit 2
   ```
4. When notified of completion, **Step 6: Present result**

   Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

   **`inline` or `both`**: Display `audioUrl` as a clickable link.

   Present:
   ```
   播客已生成！

   在线收听：{audioUrl}
   字幕：{subtitlesUrl}（如有）
   时长：{audioDuration / 1000}s
   消耗积分：{credits}
   ```

   **`download` or `both`**: Also download the file.
   ```bash
   DATE=$(date +%Y-%m-%d)
   JOB_DIR=".listenhub/podcast/${DATE}-{episodeId}"
   mkdir -p "$JOB_DIR"
   curl -sS -o "${JOB_DIR}/{episodeId}.mp3" "{audioUrl}"
   ```
   Present the download path in addition to the above summary.
5. Offer to show transcript or provide download URL on request

### Two-Step Generation

1. **Step 1 — Submit text (foreground)**: `POST /podcast/episodes/text-content` → extract `episodeId`
2. **Poll text (background)**: Use the exact `jq`-based polling loop above (substitute endpoint `podcast/episodes/text-content/{episodeId}` if needed), with `run_in_background: true` and `timeout: 600000`
3. When notified, **save draft to config output dir**:
   - Create `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
   - Write `{episodeId}-draft.md` (human-readable: `**{speakerName}**: {content}` per line)
   - Write `{episodeId}-draft.json` (raw `scripts` array)
   - Present the draft location and content preview
4. **STOP**: Present the draft and wait for explicit user approval
5. **Step 2 — Submit audio (foreground, after approval)**:
   - No changes: `POST /podcast/episodes/{episodeId}/audio` with `{}`
   - With edits: `POST /podcast/episodes/{episodeId}/audio` with modified `{scripts: [...]}`
6. **Poll audio (background)**: Same exact `jq`-based loop, `run_in_background: true`, `timeout: 600000`
7. When notified, **download audio to same folder**:
   - `curl -sS -o .listenhub/podcast/{dir}/{episodeId}.mp3 {audioUrl}`
   - Present final result (same format as one-step, folder now has draft + final files)

### After Successful Generation

Update config with the choices made this session:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  --arg mode "{mode}" \
  --arg method "{one-step/two-step}" \
  --argjson speakers '{"{language}": ["{speakerId}"]}' \
  '. + {"language": $lang, "defaultMode": $mode, "defaultMethod": $method, "defaultSpeakers": (.defaultSpeakers + $speakers)}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

## API Reference

- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Episode creation: `shared/api-podcast.md`
- Polling: `shared/common-patterns.md` § Async Polling
- Config pattern: `shared/config-pattern.md`

## Composability

- **Invokes**: speakers API (for speaker selection)
- **Invoked by**: content-planner (Phase 3)

## Example

**User**: "Make a podcast about the latest AI developments"

**Agent workflow**:
1. Detect: podcast request, topic = "latest AI developments"
2. Ask mode → user picks "Deep"
3. Ask language → "English"
4. Ask speakers → 1 speaker
5. Fetch speakers list, user picks "cozy-man-english"
6. No references
7. One-step generation

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "text", "content": "The latest AI developments"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "deep"
  }'
```

Poll until complete, then present the result with title and listen link.
