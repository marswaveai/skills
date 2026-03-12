---
name: podcast
metadata:
  openclaw:
    emoji: "🎙️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
description: |
  Create podcasts from topics, URLs, or text. Triggers on: "做播客", "podcast",
  "播客", "录一期节目", "chat about", "discuss", "debate", "dialogue",
  "make a podcast about".
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
- Never hardcode speaker IDs — always fetch from the speakers API
- Never fabricate API endpoints or parameters
- Always read config following `shared/config-pattern.md` before any interaction
- Always follow `shared/speaker-selection.md` for speaker selection (text table + pagination)
- Never save files to `~/Downloads/` — use `.listenhub/podcast/` from config

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding to the next step. After all parameters are collected, summarize the choices and ask the user to confirm. Do NOT call any generation API until the user has explicitly confirmed.
</HARD-GATE>

## Step 0: Read Config

Before any interaction, load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/podcast/config.json`, then `~/.listenhub/podcast/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it
3. Note saved values: `language`, `defaultMode`, `defaultSpeakers`, `autoDownload`

Saved values pre-fill steps 2–5. User can still override any of them during the interaction.

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

Follow `shared/speaker-selection.md` for the full selection flow, including:
- Default from `config.defaultSpeakers.{language}` (skip step if set)
- Text table + paginated AskUserQuestion
- Input matching and re-prompt on no match

For 2-speaker mode (dialogue/debate): run selection twice (or until both are chosen).

### Step 6: Reference Materials (optional)

```
Question: "Any reference materials to include?"
Options:
  - "Yes, URL(s)" — Provide URLs to analyze
  - "Yes, text" — Paste reference text
  - "No references" — Generate from topic alone
```

### Step 7: Generation Method

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
3. **Poll (background)**: `GET /podcast/episodes/{episodeId}` every 10s with `run_in_background: true` and `timeout: 600000`
4. When notified of completion, **download and present result**:

   a. Read `autoDownload` from config (default: `true`)
   b. If `autoDownload` is `true`:
      - Create `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
      - `curl -sS -o {dir}/{episodeId}.mp3 {audioUrl}`
      - Write `{episodeId}.md` from `scripts` array (one line per speaker turn: `**{speakerName}**: {content}`)
      - Write `{episodeId}.json` with raw `scripts` array

   c. Present:

   ```
   播客已生成！

   「{title}」

   在线收听：https://listenhub.ai/app/episode/{episodeId}
   MP3 直链： {audioUrl}

   已下载到 .listenhub/podcast/{YYYY-MM-DD}-{episodeId}/：
     {episodeId}.mp3
     {episodeId}.md
     {episodeId}.json
   ```

   (If `autoDownload` is `false`, omit the download section and only show the links.)
5. Offer to show transcript or provide download URL on request

### Two-Step Generation

1. **Step 1 — Submit text (foreground)**: `POST /podcast/episodes/text-content` → extract `episodeId`
2. **Poll text (background)**: `run_in_background: true`, `timeout: 600000`
3. When notified, **save draft to config output dir**:
   - Create `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
   - Write `{episodeId}-draft.md` (human-readable: `**{speakerName}**: {content}` per line)
   - Write `{episodeId}-draft.json` (raw `scripts` array)
   - Present the draft location and content preview
4. **STOP**: Present the draft and wait for explicit user approval
5. **Step 2 — Submit audio (foreground, after approval)**:
   - No changes: `POST /podcast/episodes/{episodeId}/audio` with `{}`
   - With edits: `POST /podcast/episodes/{episodeId}/audio` with modified `{scripts: [...]}`
6. **Poll audio (background)**: `run_in_background: true`, `timeout: 600000`
7. When notified, **download audio to same folder**:
   - `curl -sS -o .listenhub/podcast/{dir}/{episodeId}.mp3 {audioUrl}`
   - Present final result (same format as one-step, folder now has draft + final files)

### After Successful Generation

Update config with the choices made this session:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  --arg mode "{mode}" \
  --argjson speakers '{"{language}": ["{speakerId}"]}' \
  '. + {"language": $lang, "defaultMode": $mode, "defaultSpeakers": ($speakers + .defaultSpeakers)}')
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
