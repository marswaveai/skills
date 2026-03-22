# Narration Script Template

## Pipeline Steps

### 1. Prepare Material

Same as other templates — material from dispatcher.

### 2. Generate Script

Write a spoken-word script following `style.md`:
- Hook opening
- 2-4 talking points with clear transitions
- Strong closing

Apply user `styleNotes` from preferences.

Save as `script.md` in the output folder.

### 3. TTS Audio (Optional)

TTS is offered only if:
- The pipeline requires it (user asked for audio)
- `LISTENHUB_API_KEY` is available

If generating audio:

1. Select speaker using built-in defaults from `shared/speaker-selection.md`:
   - Chinese: "原野" (`CN-Man-Beijing-V2`)
   - English: "Mars" (`cozy-man-english`)

2. Call TTS API (use `@file` pattern for safe text handling per `shared/common-patterns.md`):
```bash
cat > /tmp/creator-tts-request.json << ENDJSON
{"input": $(echo "$SCRIPT_TEXT" | jq -Rs .), "voice": "$SPEAKER_ID"}
ENDJSON

curl -sS -X POST "https://api.marswave.ai/openapi/v1/tts" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d @/tmp/creator-tts-request.json \
  --output "{output}/audio.mp3"

rm /tmp/creator-tts-request.json
```

Note: TTS max input is ~10,000 characters. For longer scripts, this is still well within limits for narration (typically 300-2000 chars).

If TTS fails: deliver script without audio, note in output summary.

### 4. Write meta.json

```json
{
  "title": "...",
  "platform": "narration",
  "date": "YYYY-MM-DD",
  "wordCount": N,
  "hasAudio": true/false,
  "speaker": "speaker-name"
}
```

### Output Structure

```
{slug}-narration/
├── script.md
├── audio.mp3          (if TTS was generated)
├── .original/
│   └── script.md
└── meta.json
```
