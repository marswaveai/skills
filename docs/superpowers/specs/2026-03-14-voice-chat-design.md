# Voice Chat Skill Design Spec

**Date:** 2026-03-14
**Status:** Draft

## Overview

A Claude Code skill (`/voice-chat`) that lets developers launch a Discord voice bot in one command. Users speak in a Discord voice channel, coli handles ASR, Claude Code generates replies, and ListenHub TTS speaks them back.

**Scope:** Development/demo tool. Bot runs while Claude Code session is open.

## Architecture

Three components, clear separation of concerns:

```
┌────────────────┐       ┌─────────────────────────┐       ┌────────────────┐
│  User           │       │  coli (Node.js process)  │       │  Claude Code   │
│  Discord voice  │       │  discord-bot.js           │       │                │
│  channel        │       │                           │       │                │
└───────┬────────┘       └─────────┬───────────────┘       └───────┬────────┘
        │                          │                                │
        │ Opus audio stream        │                                │
        │ ───────────────────────▶ │                                │
        │  (Discord WebSocket)     │                                │
        │                          │ Decode PCM → coli ASR (VAD)    │
        │                          │ Detect end of speech            │
        │                          │                                │
        │                          │ stdout: {"type":"final",...}    │
        │                          │ ──────────────────────────────▶ │
        │                          │  (JSON line, child process)     │
        │                          │                                │
        │                          │               Claude generates  │
        │                          │               reply             │
        │                          │                                │
        │                          │ stdin: {"type":"reply",...}     │
        │                          │ ◀────────────────────────────── │
        │                          │  (JSON line, child process)     │
        │                          │                                │
        │                          │ ListenHub TTS → audio           │
        │                          │ (fallback: local say)           │
        │                          │                                │
        │ AI voice reply           │                                │
        │ ◀─────────────────────── │                                │
        │  (Discord WebSocket)     │                                │
        │                          │                                │
        │ Loop: wait for user      │                                │
```

### Component Responsibilities

| Component | Role | What it does |
|---|---|---|
| User (Discord) | Audio terminal | Speak and listen in a voice channel |
| coli (Node.js) | Audio pipeline | Discord bot, ASR, TTS synthesis, audio playback |
| Claude Code | Brain | Understand user speech, generate replies |

### Communication Protocols

- **User ↔ coli:** Discord WebSocket (Opus audio)
- **coli ↔ Claude Code:** stdin/stdout JSON lines (child process)

## stdin/stdout Protocol

Each message is a single JSON line (`\n`-delimited).

### coli → Claude Code (stdout)

| type | Fields | Description |
|---|---|---|
| `ready` | `channel`, `guild` | Bot joined voice channel |
| `listening` | | Resumed listening after TTS |
| `partial` | `text` | Interim ASR result (display only) |
| `final` | `text`, `lang`, `emotion` | Complete utterance, requires reply |
| `tts_start` | | Started playing TTS audio |
| `tts_done` | | Finished playing TTS audio |
| `error` | `message` | Non-fatal error (e.g. TTS fallback) |
| `disconnected` | `reason` | Bot disconnected (`user_left`, `kicked`, `error`) |

### Claude Code → coli (stdin)

| type | Fields | Description |
|---|---|---|
| `reply` | `text` | Text to synthesize and play |
| `stop` | | Disconnect and exit |

## Skill Interaction Flow

### Step 0: Environment Check

- `LISTENHUB_API_KEY` exists
- coli installed (`npm list -g @marswave/coli`)
- Node.js ≥ 18
- Auto-install missing dependencies

### Step 1: Discord Bot Configuration

- Guide user to create Discord bot at Developer Portal (if first time)
- Collect Discord Bot Token
- Collect voice channel ID or name
- Save to `~/.listenhub/voice-chat/config.json`

### Step 2: TTS Configuration

- Select language (zh / en)
- Select voice (from ListenHub speakers API)
- Configure fallback timeout (default: 3 seconds)

### Step 3: Confirm and Launch

- Summary of all configuration
- User confirms
- Start `discord-bot.js` as background process
- Display: "Bot online, joined #channel"

### Step 4: Conversation Loop

- Listen on stdout for `final` messages
- Claude generates reply
- Send reply via stdin
- Optionally display `partial` messages (real-time transcription)
- Loop until: user says goodbye / Ctrl+C / Discord disconnect

### Step 5: Cleanup

- Kill child process
- Optional conversation summary

## discord-bot.js Script

### Startup

```
Read CLI args: token, channelId, language, speakerId, ttsTimeout
  → Login to Discord
  → Join voice channel
  → stdout: {"type":"ready",...}
```

### Audio Receive Loop

```
Listen to user audio (discord.js/voice receiver)
  → Decode Opus to PCM
  → Wrap as AsyncIterable<Float32Array>
  → Feed to coli streamAsr({ vad: true })
  → partial → stdout: {"type":"partial",...}
  → final   → stdout: {"type":"final",...}
```

### stdin Reply Handler

```
Receive {"type":"reply","text":"..."}
  → Call ListenHub TTS API
  → Timeout (3s)? Fallback to coli local TTS (macOS say)
  → Play audio to Discord voice channel
  → stdout: {"type":"tts_done"}

Receive {"type":"stop"}
  → Disconnect from voice channel, exit process
```

### Half-Duplex Control (v1)

- Pause coli ASR during TTS playback (don't listen to own voice)
- Resume ASR after TTS completes
- v2: remove this constraint for full-duplex

## Dependency Management

Dependencies install to a persistent location, not per-session:

```
~/.listenhub/voice-chat/
├── config.json       — User configuration
├── package.json      — Dependency declarations
└── node_modules/     — Installed once, persists across sessions
```

- **First use:** Auto `npm install`, ~30 seconds
- **Subsequent uses:** Skip install, launch immediately
- **Updates:** Skill detects package.json version changes, re-installs when needed

### Required Packages

- `discord.js` + `@discordjs/voice` — Discord connection
- `@discordjs/opus` — Opus codec
- `@marswave/coli` — ASR + TTS
- `sodium-native` — Discord.js encryption dependency

## Skill File Structure

```
voice-chat/
├── SKILL.md              — Interaction flow, configuration guidance
├── scripts/
│   └── discord-bot.js    — Discord bot + coli ASR + TTS pipeline
└── references/
    └── (optional docs)
```

## Configuration Schema

`~/.listenhub/voice-chat/config.json`:

```json
{
  "discord": {
    "token": "...",
    "channelId": "...",
    "guildId": "..."
  },
  "tts": {
    "language": "zh",
    "speakerId": "...",
    "speakerName": "...",
    "fallbackTimeout": 3000
  },
  "asr": {
    "vad": true,
    "vadMinSilenceDuration": 0.5
  }
}
```

## Future Considerations (Not in v1)

- **Full-duplex:** User can interrupt AI mid-speech
- **Multi-user:** Handle multiple speakers in one channel
- **Telegram support:** Voice message mode
- **Conversation memory:** Persist context across sessions
- **Role presets:** "English tutor", "interview coach", etc.
