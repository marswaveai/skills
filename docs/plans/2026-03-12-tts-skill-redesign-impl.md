# TTS Skill Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the `speech` skill with a redesigned `tts` skill that uses `/v1/tts` (quick, sync) and `/v1/speech` (multi-speaker, sync), removing all FlowSpeech async logic.

**Architecture:** Signal detection auto-routes to Quick mode (`/v1/tts`) for casual single-speaker requests, or Script mode (`/v1/speech`) for multi-character dialogue. A `user-config.json` file persists voice preferences so the user is only asked once.

**Tech Stack:** Markdown skill files, JSON config, curl for API calls, jq for response parsing.

---

## Task 1: Rename directories and files

Rename the skill directory and the shared API reference file. Using `git mv` preserves history.

**Files:**
- Rename: `speech/` → `tts/`
- Rename: `shared/api-speech.md` → `shared/api-tts.md`

**Step 1: Rename the skill directory**

```bash
git mv speech tts
```

**Step 2: Rename the API reference file**

```bash
git mv shared/api-speech.md shared/api-tts.md
```

**Step 3: Verify the renames**

```bash
ls tts/
ls shared/api-tts.md
```

Expected: `tts/` directory exists with `SKILL.md` and `references/` inside; `shared/api-tts.md` exists.

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(tts): rename speech/ → tts/ and api-speech.md → api-tts.md"
```

---

## Task 2: Rewrite `shared/api-tts.md`

Replace the FlowSpeech-only content with documentation for the two new endpoints. This is the reference file the skill reads during execution.

**Files:**
- Modify: `shared/api-tts.md`

**Step 1: Overwrite with new content**

Replace the entire file with:

```markdown
# ListenHub API — TTS

**Base URL**: `https://api.marswave.ai/openapi/v1`
**Authentication**: See [authentication.md](./authentication.md)

---

## POST /v1/tts

Low-latency single-voice TTS. Returns a **streaming binary MP3** — not JSON.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| input | Yes | string | Text to convert |
| voice | Yes | string | Speaker ID (`speakerId` from speakers API) |
| model | No | string | Model name, defaults to `flowtts` |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Hello, welcome to ListenHub.",
    "voice": "EN-Man-General-01"
  }' \
  --output /tmp/tts-output.mp3
```

**Response:** Binary MP3 audio stream. On error, falls back to a JSON error object (check HTTP status code first).

**Key constraints:**
- Max ~10,000 characters for `input`
- `voice` must be a valid `speakerId` from `GET /speakers/list`

---

## POST /v1/speech

Multi-speaker script-to-audio. Each script segment uses a different voice. Returns audio URL **synchronously**.

**Request body:**

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| scripts | Yes | array | Ordered array of script segments |
| scripts[].content | Yes | string | Text for this segment |
| scripts[].speakerId | Yes | string | Speaker ID for this segment |
| title | No | string | Custom title (auto-generated if omitted) |

**curl:**

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/speech" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "scripts": [
      {"content": "Welcome everyone.", "speakerId": "EN-Man-General-01"},
      {"content": "Today we discuss an interesting topic.", "speakerId": "EN-Woman-General-01"},
      {"content": "Let us begin.", "speakerId": "EN-Man-General-01"}
    ]
  }'
```

**Response:**

```json
{
  "code": 0,
  "message": "",
  "data": {
    "audioUrl": "https://assets.listenhub.ai/listenhub-public-prod/podcast/example.mp3",
    "audioDuration": 12500,
    "subtitlesUrl": "https://assets.listenhub.ai/listenhub-public-prod/podcast/example.srt",
    "taskId": "1eed39d387a046c0a1213e6b8f139d77",
    "credits": 12
  }
}
```

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| audioUrl | string | MP3 audio file URL |
| audioDuration | integer | Duration in milliseconds |
| subtitlesUrl | string | SRT subtitle file URL |
| taskId | string | Task identifier |
| credits | integer | Credits consumed |
```

**Step 2: Verify the file looks right**

Read `shared/api-tts.md` and confirm:
- Two sections: `POST /v1/tts` and `POST /v1/speech`
- No FlowSpeech content anywhere

**Step 3: Commit**

```bash
git add shared/api-tts.md
git commit -m "docs(api): rewrite api-tts.md with /v1/tts and /v1/speech endpoints"
```

---

## Task 3: Create `tts/user-config.json`

This file persists the user's voice preferences between sessions. The skill reads it at startup.

**Files:**
- Create: `tts/user-config.json`

**Step 1: Create the file**

```json
{
  "quickVoice": null,
  "scriptVoices": [],
  "language": null
}
```

**Step 2: Verify**

```bash
cat tts/user-config.json
```

Expected: valid JSON with all three keys set to null/empty.

**Step 3: Commit**

```bash
git add tts/user-config.json
git commit -m "feat(tts): add user-config.json for voice preference persistence"
```

---

## Task 4: Update `tts/references/tts-guide.md`

Remove the FlowSpeech comparison table and update the guide to match the two new endpoints.

**Files:**
- Modify: `tts/references/tts-guide.md`

**Step 1: Replace the file content**

```markdown
# TTS Guide

## Quick Mode vs Script Mode

| Feature | Quick (`/v1/tts`) | Script (`/v1/speech`) |
|---------|-------------------|----------------------|
| Speakers | 1 (single voice) | Multiple (per-segment) |
| Input | Plain text | `scripts` JSON array |
| Response | Sync MP3 stream | Sync JSON with `audioUrl` |
| Best for | Chat, notifications, quick reads | Dialogue, audiobooks, narrated scripts |

## When to Use Each

### Quick Mode (`/v1/tts`)

Use when:
- Single paragraph or short text
- User says "read this", "TTS this", "朗读"
- No character roles or speaker assignments needed
- Instant audio for in-conversation use

### Script Mode (`/v1/speech`)

Use when:
- User mentions multiple characters, roles, or voices
- Content is dialogue (A says X, B replies Y)
- User says "多角色", "脚本", "对话", "script", "dialogue"
- User provides or wants to create per-segment speaker assignments

## Script Format

```json
{
  "scripts": [
    {"content": "Hello everyone, welcome.", "speakerId": "EN-Man-General-01"},
    {"content": "Thanks for having me!", "speakerId": "EN-Woman-General-01"},
    {"content": "Today we are talking about...", "speakerId": "EN-Man-General-01"}
  ]
}
```

Tips:
- Keep segments at natural speech boundaries (sentences or short paragraphs)
- Alternate speakers for a natural dialogue feel
- All `speakerId` values must be valid IDs from the speakers API
- Speakers should share the same language

## Language Auto-Detection

- Read `user-config.json.language` first
- If null: detect from text content — Chinese characters → `zh`, Latin script → `en`
- Never ask the user about language

## Voice Preference Persistence

- `user-config.json.quickVoice` — used for Quick mode
- `user-config.json.scriptVoices` — list of voices for Script mode characters
- After a new selection, ask: "Save this voice as your default?" — update file on yes
- On next run, if config has a value, use it silently without asking
```

**Step 2: Verify no FlowSpeech references remain**

```bash
grep -i "flowspeech\|flow-speech\|flow_speech" tts/references/tts-guide.md
```

Expected: no output (no matches).

**Step 3: Commit**

```bash
git add tts/references/tts-guide.md
git commit -m "docs(tts): rewrite tts-guide.md to cover quick and script modes"
```

---

## Task 5: Rewrite `tts/SKILL.md`

This is the main skill instruction file. Rewrite it completely with the new interaction logic.

**Files:**
- Modify: `tts/SKILL.md`

**Step 1: Replace the entire file**

```markdown
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
- Always read `tts/user-config.json` before asking the user about voice preferences

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Mode Detection

Determine the mode from the user's input **automatically** before asking any questions:

| Signal | Mode |
|--------|------|
| "多角色", "脚本", "对话", "script", "dialogue", "multi-speaker" | Script |
| Multiple characters mentioned by name/role | Script |
| Input contains structured segments (A: ..., B: ...) | Script |
| Single paragraph of text, no character markers | Quick |
| "读一下", "read this", "TTS", "朗读" with plain text | Quick |
| Ambiguous | Quick (default) |

## Interaction Flow

### Step 0: Read config

Before doing anything, read `tts/user-config.json`. Note the values for `quickVoice`, `scriptVoices`, and `language`. These will be used to skip asking the user where preferences are already saved.

### Quick Mode — `POST /v1/tts`

**Step 1: Extract text**

Get the text to convert. If the user hasn't provided it, ask:

> "What text would you like me to read aloud?"

**Step 2: Determine voice**

- If `user-config.json.quickVoice` is set → use it silently (skip to Step 4)
- Otherwise: `GET /speakers/list?language={detected-language}`, then ask:

```
Question: "Which voice?"
Options: [one per speaker — label: name, description: gender]
```

**Step 3: Save preference**

```
Question: "Save {voice name} as your default quick voice?"
Options:
  - "Yes" — update user-config.json
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

**Step 6: Present result**

```
Audio generated!

  File: /tmp/tts-output.mp3
  Tip: Open the file to listen, or move it to your preferred location.
```

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

- If `user-config.json.scriptVoices` has a saved voice → auto-assign silently
- Otherwise: fetch `GET /speakers/list?language={detected-language}` and ask:

```
Question: "Which voice for {character name}?"
Options: [one per speaker — label: name, description: gender]
```

**Step 3: Save preferences**

After all voices are assigned (if any were new):

```
Question: "Save these voice assignments for future sessions?"
Options:
  - "Yes" — update scriptVoices in user-config.json
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

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/speech" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/lh-speech-request.json
```

(Write request to temp file first — see `shared/common-patterns.md` § Long Text Input)

**Step 6: Present result**

```
Audio generated!

  Listen: {audioUrl}
  Subtitles: {subtitlesUrl}
  Duration: {audioDuration / 1000}s
  Credits used: {credits}
```

---

## Updating user-config.json

When saving preferences, edit only the relevant key(s) in `tts/user-config.json`. Do not overwrite unchanged keys.

- Quick voice: set `quickVoice` to the selected `speakerId`
- Script voices: replace `scriptVoices` with the full list of `speakerId` values assigned in the current session
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
```

**Step 2: Verify no FlowSpeech references remain**

```bash
grep -i "flowspeech\|flow-speech\|flow_speech\|episodeId\|episode" tts/SKILL.md
```

Expected: no output.

**Step 3: Verify api-speech.md reference is gone**

```bash
grep "api-speech" tts/SKILL.md
```

Expected: no output.

**Step 4: Commit**

```bash
git add tts/SKILL.md
git commit -m "feat(tts): rewrite SKILL.md — quick mode (/tts) + script mode (/speech), remove FlowSpeech"
```

---

## Task 6: Final verification

Confirm no stale references remain across the live skill files.

**Step 1: Check for any remaining FlowSpeech references in skill files**

```bash
grep -ri "flowspeech\|flow-speech\|flow_speech" tts/ shared/api-tts.md
```

Expected: no output.

**Step 2: Check for stale api-speech.md references in live files**

```bash
grep -r "api-speech" tts/ shared/
```

Expected: no output.

**Step 3: Confirm user-config.json is valid JSON**

```bash
cat tts/user-config.json | python3 -m json.tool
```

Expected: pretty-printed JSON with no errors.

**Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(tts): clean up stale references"
```

(Skip this step if Step 1-3 produced no issues.)
