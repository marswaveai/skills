---
name: speech
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

- User wants to convert text or a URL to spoken audio
- User asks for "read aloud", "TTS", "text to speech", "voice narration"
- User says "朗读", "配音", "语音合成"
- User wants multi-speaker scripted audio

## When NOT to Use

- User wants a podcast-style discussion with topic exploration (use `/podcast`)
- User wants an explainer video with visuals (use `/explainer`)
- User wants to generate an image (use `/image-gen`)

## Purpose

Convert text or URL content into natural-sounding speech audio. Two paths:

1. **FlowSpeech** (default): Single-speaker reading of text or URL content. Simple and fast.
2. **Speech** (advanced): Multi-speaker scripted audio with per-segment speaker assignment.

## Hard Constraints

- No shell scripts. Construct curl commands from `shared/api-reference.md`
- Always read `shared/authentication.md` for API key and headers
- Follow `shared/common-patterns.md` for polling, errors, and interaction patterns
- Never hardcode speaker IDs — always fetch from the speakers API
- Text content limit: 10,000 characters for FlowSpeech

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Interaction Flow

### Step 1: Input Type

```
Question: "What would you like to convert to speech?"
Options:
  - "Text" — Paste or type text content
  - "URL" — Provide a URL to read aloud
```

### Step 2: Content

Free text input: the text to read or the URL.

### Step 3: Language

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Chinese voice output
  - "English (en)" — English voice output
```

### Step 4: Mode

```
Question: "Processing mode?"
Options:
  - "Direct" — Read as-is, no modifications
  - "Smart" — Fix grammar and punctuation before reading
```

### Step 5: Speaker Selection

Call `GET /speakers/list?language={language}` and present options.

### Step 6: Multi-Speaker Check

If user explicitly requests multiple speakers or per-segment speaker assignment:

```
Question: "This requires a multi-speaker script. Would you like to:"
Options:
  - "Write the script" — Provide a JSON script with speaker assignments
  - "Let AI assign speakers" — Auto-generate script segments (not yet supported)
```

If multi-speaker, guide the user to create a scripts JSON:

```json
{
  "scripts": [
    {"content": "Hello everyone", "speakerId": "cozy-man-english"},
    {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
  ]
}
```

### Step 7: Confirm & Generate

Summarize all choices:

```
Ready to generate speech:

  Input: {text / URL}
  Language: {language}
  Mode: {direct / smart}
  Speaker: {speaker name(s)}
  Path: {FlowSpeech / Multi-Speaker}

  Proceed?
```

Wait for explicit confirmation before calling any API.

## Workflow

### Single Speaker (FlowSpeech) — Default Path

1. **Submit (foreground)**: `POST /flow-speech/episodes` with source, speaker, language, mode → extract `episodeId`
2. Tell the user the task is submitted
3. **Poll (background)**: `GET /flow-speech/episodes/{episodeId}` every 10s with `run_in_background: true` and `timeout: 600000`
4. When notified, **present result**:
   ```
   Audio generated!

   Listen: https://listenhub.ai/app/text-to-speech
   Duration: ~{estimated} minutes
   ```

**Estimated time**: 1-2 minutes.

### Multi-Speaker (Speech) — Advanced Path

1. **Collect scripts**: User provides or agent helps create scripts JSON
2. **Submit (foreground)**: `POST /speech` with scripts array → extract `episodeId`
3. **Poll (background)**: via flow-speech episode endpoint with `run_in_background: true` and `timeout: 600000`
4. When notified, **present result**: same as above

## API Reference

- Speaker list: `shared/api-reference.md` § 1. Speakers
- Speaker selection guide: `shared/speaker-selection.md`
- FlowSpeech: `shared/api-reference.md` § 4. FlowSpeech (TTS)
- Multi-speaker: `shared/api-reference.md` § 5. Speech (Multi-Speaker)
- Polling: `shared/common-patterns.md` § Async Polling

## Composability

- **Invokes**: speakers API (for speaker selection)
- **Invoked by**: explainer (for voiceover), platform skills (Phase 2)

## Example

**User**: "Read this article aloud: https://blog.example.com/article"

**Agent workflow**:
1. Input type: URL
2. Content: `https://blog.example.com/article`
3. Ask language → "English"
4. Ask mode → "Direct"
5. Fetch speakers, user picks "cozy-man-english"
6. Single speaker → FlowSpeech path

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/flow-speech/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sources": [{"type": "url", "content": "https://blog.example.com/article"}],
    "speakers": [{"speakerId": "cozy-man-english"}],
    "language": "en",
    "mode": "direct"
  }'
```

Poll until complete, then present audio link.
