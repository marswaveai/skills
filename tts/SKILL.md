---
name: tts
metadata:
  openclaw:
    emoji: "🔊"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
description: |
  Text-to-speech and voice narration. Triggers on: "朗读这段", "配音", "TTS",
  "语音合成", "text to speech", "read this aloud", "convert to speech",
  "voice narration", "read aloud".
---

## When to Use

- User wants to convert text to spoken audio
- User asks for "read aloud", "TTS", "text to speech", "voice narration"
- User says "朗读", "配音", "语音合成"
- User wants multi-speaker scripted audio or dialogue

## When NOT to Use

- User wants a podcast-style discussion with topic exploration (use `/podcast`)
- User wants an explainer video with visuals (use `/explainer`)
- User wants to generate an image (use `/image-gen`)

## Purpose

Convert text into natural-sounding speech audio. Two paths:

1. **Quick mode** (`/v1/tts`): Single voice, low-latency, sync MP3 stream. For casual chat, reading snippets, instant audio.
2. **Script mode** (`/v1/speech`): Multi-speaker, per-segment voice assignment. For dialogue, audiobooks, scripted content.

## Hard Constraints

- No shell scripts. Construct curl commands from the API reference files listed in Resources
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for errors and interaction patterns
- Never hardcode speaker IDs — always fetch from the speakers API
- Always read config following `shared/config-pattern.md` before any interaction
- Always follow `shared/speaker-selection.md` for speaker selection (text table + pagination)
- Never save files to `~/Downloads/` or `/tmp/` as primary output — use `.listenhub/tts/`

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Mode Detection

Determine the mode from the user's input **automatically** before asking any questions:

| Signal | Mode |
|--------|------|
| "多角色", "脚本", "对话", "script", "dialogue", "multi-speaker" | Script |
| Multiple characters mentioned by name or role | Script |
| Input contains structured segments (A: ..., B: ...) | Script |
| Single paragraph of text, no character markers | Quick |
| "读一下", "read this", "TTS", "朗读" with plain text | Quick |
| Ambiguous | Quick (default) |

## Interaction Flow

### Step 0: Read config

Before doing anything, load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/tts/config.json`, then `~/.listenhub/tts/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it

Initial default config for tts:
```json
{
  "outputDir": ".listenhub",
  "autoDownload": true,
  "language": null,
  "defaultSpeakers": {}
}
```

Note saved values for `language`, `defaultSpeakers`, `autoDownload`.

### Quick Mode — `POST /v1/tts`

**Step 1: Extract text**

Get the text to convert. If the user hasn't provided it, ask:

> "What text would you like me to read aloud?"

**Step 2: Determine voice**

- If `config.defaultSpeakers.{language}[0]` is set → use it silently (skip to Step 4)
- Otherwise: `GET /speakers/list?language={detected-language}`, then follow `shared/speaker-selection.md` (text table + paginated AskUserQuestion)

**Step 3: Save preference**

```
Question: "Save {voice name} as your default voice for {language}?"
Options:
  - "Yes" — update .listenhub/tts/config.json
  - "No" — use for this session only
```

**Step 4: Confirm**

```
Ready to generate:

  Text: "{first 80 chars}..."
  Voice: {voice name}

Proceed?
```

**Step 5: Generate**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": "...", "voice": "..."}' \
  --output /tmp/tts-output.mp3
```

**Step 6: Download and present result**

If `autoDownload` is `true`:
- The TTS endpoint returns audio directly (not async) — save the output during the curl call
- Use a timestamped jobId: `$(date +%s)`
- Create `.listenhub/tts/YYYY-MM-DD-{jobId}/`
- Save as `{jobId}.mp3` via `curl ... --output {dir}/{jobId}.mp3`

Present:
```
Audio generated!

已下载到 .listenhub/tts/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```

If `autoDownload` is `false`, save to `/tmp/tts-{jobId}.mp3` and show that path.

---

### Script Mode — `POST /v1/speech`

**Step 1: Get scripts**

Determine whether the user already has a scripts array:

- **Already provided** (JSON or clear segments): parse and display for confirmation
- **Not yet provided**: help the user structure segments. Ask:

  > "Please provide the script with speaker assignments. Format: each line as `SpeakerName: text content`. I'll convert it."

  Once the user provides the script, parse it into the `scripts` JSON format.

**Step 2: Assign voices per character**

For each unique character in the script:

- If `config.defaultSpeakers.{language}` has saved voices → auto-assign silently (one per character in order)
- Otherwise: fetch `GET /speakers/list?language={detected-language}` and follow `shared/speaker-selection.md` for each character

**Step 3: Save preferences**

After all voices are assigned (if any were new):

```
Question: "Save these voice assignments for future sessions?"
Options:
  - "Yes" — update defaultSpeakers in .listenhub/tts/config.json
  - "No" — use for this session only
```

**Step 4: Confirm**

```
Ready to generate:

  Characters:
    {name}: {voice}
    {name}: {voice}
  Segments: {count}
  Title: (auto-generated)

Proceed?
```

**Step 5: Generate**

Write the request body to a temp file, then submit:

```bash
# Write request to temp file
cat > /tmp/lh-speech-request.json << 'ENDJSON'
{
  "scripts": [
    {"content": "...", "speakerId": "..."},
    {"content": "...", "speakerId": "..."}
  ]
}
ENDJSON

# Submit
curl -sS -X POST "https://api.marswave.ai/openapi/v1/speech" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/lh-speech-request.json

rm /tmp/lh-speech-request.json
```

**Step 6: Download and present result**

If `autoDownload` is `true`:
- Create `.listenhub/tts/YYYY-MM-DD-{jobId}/`
- `curl -sS -o {dir}/{jobId}.mp3 {audioUrl}`

Present:
```
Audio generated!

在线收听：{audioUrl}
字幕：{subtitlesUrl}
时长：{audioDuration / 1000}s
消耗积分：{credits}

已下载到 .listenhub/tts/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```

---

## Updating Config

When saving preferences, merge into `.listenhub/tts/config.json` — do not overwrite unchanged keys.
Follow the merge pattern in `shared/config-pattern.md`.

- Quick voice: set `defaultSpeakers.{language}[0]` to the selected `speakerId`
- Script voices: set `defaultSpeakers.{language}` to the full array assigned this session
- Language: set `language` if the user explicitly specifies it

## API Reference

- TTS & Speech endpoints: `shared/api-tts.md`
- Speaker list: `shared/api-speakers.md`
- Speaker selection guide: `shared/speaker-selection.md`
- Error handling: `shared/common-patterns.md` § Error Handling
- Long text input: `shared/common-patterns.md` § Long Text Input

## Composability

- **Invokes**: speakers API (for speaker selection)
- **Invoked by**: explainer (for voiceover)

## Examples

**Quick mode:**

> "TTS this: The server will be down for maintenance at midnight."

1. Detect: Quick mode (plain text, "TTS this")
2. Read config: `quickVoice` is `null`
3. Fetch speakers, user picks "Yuanye"
4. Ask to save → yes → update config
5. `POST /v1/tts` with `input` + `voice`
6. Present: `/tmp/tts-output.mp3`

**Script mode:**

> "帮我做一段双人对话配音，A说：欢迎大家，B说：谢谢邀请"

1. Detect: Script mode ("双人对话")
2. Parse segments: A → "欢迎大家", B → "谢谢邀请"
3. Read config: `scriptVoices` empty
4. Fetch `zh` speakers, assign A and B voices
5. Ask to save → yes → update config
6. `POST /v1/speech` with scripts array
7. Present: `audioUrl`, `subtitlesUrl`, duration
