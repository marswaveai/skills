# TTS Guide

## FlowSpeech vs Speech API

| Feature | FlowSpeech | Speech |
|---------|-----------|--------|
| Speakers | 1 (single voice) | Multiple (per-segment assignment) |
| Input | Text or URL | Scripts JSON array |
| Endpoint | `POST /flow-speech/episodes` | `POST /speech` |
| Modes | `direct`, `smart` | N/A |
| Best for | Simple reading, articles | Dialogue, narrated scripts |
| Speed | Faster (~1-2 min) | Moderate (~2-3 min) |

## When to Use Each

### FlowSpeech (Default)

Use FlowSpeech when:
- Reading a single piece of text or URL content
- One voice is sufficient
- User says "read aloud", "TTS", "convert to speech"
- No per-segment speaker assignment needed

### Speech (Multi-Speaker)

Use Speech when:
- User explicitly requests multiple voices
- Content has dialogue with different characters
- User provides or wants to create per-segment speaker assignments
- User says "multi-speaker", "dialogue script"

## FlowSpeech Modes

### Direct

- Reads text exactly as provided, no modifications
- Best for: well-formatted text, articles, prepared content
- Default mode when no preference is stated

### Smart

- Fixes grammar, punctuation, and formatting before reading
- Best for: rough drafts, notes, casual text
- May slightly alter content for better speech flow

## Multi-Speaker Script Format

```json
{
  "scripts": [
    {"content": "Hello everyone, welcome to the show.", "speakerId": "cozy-man-english"},
    {"content": "Thanks for having me! Let's dive in.", "speakerId": "travel-girl-english"},
    {"content": "Today we're talking about...", "speakerId": "cozy-man-english"}
  ]
}
```

Each segment is spoken by the assigned speaker in order. Tips:

- Keep segments at natural speech boundaries (sentences or paragraphs)
- Alternate speakers for dialogue feel
- Each segment's `speakerId` must be a valid ID from the speakers API
- All speakers should share the same language

## Text Length Limits

- FlowSpeech text input: max 10,000 characters
- For longer content: split into multiple requests, or use a URL input (the API will fetch and process it)
