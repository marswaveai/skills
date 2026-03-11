# TTS Skill Redesign

**Date**: 2026-03-12
**Branch**: feat/skills-optimization-design
**Status**: Approved

## Problem

The current `speech` skill only uses `/v1/flow-speech/episodes` — an async, long-form endpoint that creates tasks in the ListenHub web UI. This is misaligned with two natural use cases:

1. **Agent chat**: User sends text and wants instant spoken audio (low-latency, ephemeral)
2. **Content creation**: User has a multi-character script and wants a produced audio file with distinct voices

The two synchronous endpoints — `/v1/tts` and `/v1/speech` — were never wired in. The multi-speaker path in the old skill also incorrectly routed through FlowSpeech instead of `/v1/speech`.

## Decision

- Rename skill directory `speech/` → `tts/`
- Remove all FlowSpeech (`/v1/flow-speech/episodes`) logic entirely
- Implement two clean paths using the synchronous endpoints
- Rename `shared/api-speech.md` → `shared/api-tts.md`
- Add config file `tts/user-config.json` to persist voice preferences

## Architecture

```
User triggers tts skill
        │
        ▼
[Signal detection]
        │
        ├── Quick mode signals: single paragraph, "TTS", "读一下", no character markers
        │           │
        │           ▼
        │   POST /v1/tts  →  sync MP3 stream  →  present audio
        │
        └── Script mode signals: "多角色", "脚本", "对话", structured input with speaker markers
                    │
                    ▼
            POST /v1/speech  →  sync JSON with audioUrl + subtitlesUrl  →  present links
```

When ambiguous, default to Quick mode.

## Interaction Flow

### Quick Mode (`/v1/tts`)

1. Extract text from user input
2. Read `user-config.json` → has `quickVoice`?
   - Yes: use silently
   - No: fetch speakers API, present options, user selects
3. If new voice selected: ask whether to save preference
4. `POST /v1/tts` → sync MP3 stream
5. Present result: playback hint + audio file reference

### Script Mode (`/v1/speech`)

1. Receive or help build `scripts` JSON
   - Already provided: parse directly
   - Not provided: guide user to write segments, or offer AI-assisted segmentation
2. Assign a voice per character (read `user-config.json` → `scriptVoices`)
   - Saved voices: auto-fill silently
   - Missing: ask per character
3. If new voices selected: ask whether to save
4. `POST /v1/speech` → sync JSON response
5. Present: audio link, subtitles link, duration

### Language Handling

Read `user-config.json.language`. If not set, auto-detect from text content (Chinese → `zh`, English → `en`). Do not ask the user.

## Config File: `tts/user-config.json`

```json
{
  "quickVoice": null,
  "scriptVoices": [],
  "language": null
}
```

Updated in-place when the user consents to saving a preference.

## File Changes

| Action | File |
|--------|------|
| Rename directory | `speech/` → `tts/` |
| Rewrite | `tts/SKILL.md` — new interaction logic, remove FlowSpeech |
| Update | `tts/references/tts-guide.md` — update endpoint descriptions, remove FlowSpeech comparison |
| Create | `tts/user-config.json` — default empty config |
| Rename | `shared/api-speech.md` → `shared/api-tts.md` |
| Rewrite | `shared/api-tts.md` — document `/v1/tts` and `/v1/speech`, remove FlowSpeech section |
| Update references | Any file referencing `shared/api-speech.md` → `shared/api-tts.md` |

## API Mapping

| Use Case | Endpoint | Response | Notes |
|----------|----------|----------|-------|
| Quick / chat | `POST /v1/tts` | Sync binary MP3 stream | `input` + `voice` (speakerId) |
| Multi-character script | `POST /v1/speech` | Sync JSON: `audioUrl`, `subtitlesUrl`, `duration` | `scripts[]` with per-segment `speakerId` |
