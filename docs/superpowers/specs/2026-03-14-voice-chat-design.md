# Voice Chat Skill Design Spec

**Date:** 2026-03-14
**Status:** Draft

## Overview

A Claude Code skill (`/voice-chat`) that lets developers launch a Discord voice bot in one command. Users speak in a Discord voice channel, coli handles ASR and TTS, Claude Code generates replies.

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
        │                          │ coli cloud TTS → audio            │
        │                          │ (fallback: coli local TTS)        │
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
| `waiting` | `channel` | No user in channel, waiting for someone to join |
| `listening` | | Resumed listening (ASR active) |
| `partial` | `text` | Interim ASR result (display only) |
| `final` | `text`, `lang`, `emotion` | Complete utterance, requires reply. `lang`/`emotion` are SenseVoice-specific, may be absent with other models. Empty `text` = discarded silently, not sent. |
| `tts_start` | | Started TTS playback (ASR paused) |
| `tts_done` | | Finished TTS playback |
| `error` | `message` | Non-fatal error (e.g. TTS fallback) |
| `disconnected` | `reason` | Bot disconnected (`user_left`, `kicked`, `error`) |

### Claude Code → coli (stdin)

| type | Fields | Description |
|---|---|---|
| `reply` | `text` | Text to synthesize and play |
| `stop` | | Disconnect and exit |

## Skill Interaction Flow

### Step 0: Environment Check

- `COLI_LISTENHUB_API_KEY` exists (used by coli for cloud TTS)
- coli: check global install (`npm list -g @marswave/coli`), compare with latest version (`npm view @marswave/coli version`), auto-update if outdated, auto-install if missing
- Node.js ≥ 18
- ffmpeg installed (required for TTS audio decoding)
- Local dependencies in `~/.listenhub/voice-chat/node_modules/` (auto-install if missing)

### Step 1: Discord Bot Configuration

- Guide user to create Discord bot at Developer Portal (if first time)
  - Required intents: `GuildVoiceStates`, `Guilds`
  - OAuth2 scope: `bot`
  - Bot permissions: `Connect`, `Speak`
- Collect Discord Bot Token
- Collect Guild (server) ID
- Collect voice channel ID or name
- Save to `~/.listenhub/voice-chat/config.json`

### Step 2: TTS Configuration

- Select language (zh / en)
- Select voice (from coli `listSpeakers({ apiKey, language })`)
- Configure fallback timeout (default: 5 seconds, connection timeout)

### Step 3: Confirm and Launch

- Summary of all configuration
- User confirms
- Start `discord-bot.js` as background process
- Bot logs in and checks: is there a user in the target voice channel?
  - **Yes:** Join and start listening, display "Bot online, joined #channel"
  - **No:** Display "Waiting for you to join #channel...", poll until a user joins, then start

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

v1 listens to a single user: the first to speak, or a configured user ID.
Other users in the channel are ignored.

```
Subscribe to user audio (receiver.subscribe(userId))
  → Receive discrete Opus packets (silence gaps = no packets)
  → Decode each packet to PCM via @discordjs/opus
  → Buffer and convert int16 PCM → Float32Array chunks
  → Yield as AsyncIterable<Float32Array>
  → Feed to coli streamAsr({ vad: true, model: "sensevoice" })
  → partial result → stdout: {"type":"partial",...}
  → final result (empty text = discard silently)
  → final result (has text) → stdout: {"type":"final",...}
```

Note: Discord stops sending packets during silence. The AsyncIterable
wrapper must handle gaps gracefully — coli's VAD will treat silence
as segment boundaries naturally.

### stdin Reply Handler

```
Receive {"type":"reply","text":"..."}
  → stdout: {"type":"tts_start"}
  → Pause ASR (half-duplex)
  → Call coli runCloudTts(text, { voice, apiKey }) → MP3 response
  → Timeout (5s connection)? Fallback to coli runTts (macOS say)
  → Decode MP3 → PCM via ffmpeg/prism-media
  → Play via @discordjs/voice AudioPlayer (auto Opus encode)
  → Resume ASR
  → stdout: {"type":"listening"}
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
- `prism-media` — MP3 → PCM decoding for TTS playback

### Prerequisites (system-level)

- `ffmpeg` — Required by prism-media for audio decoding
- `@marswave/coli` — Installed globally (`npm i -g @marswave/coli`)

### Platform

- **v1: macOS only.** TTS fallback uses macOS `say` command. Linux support is a future consideration.

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
    "fallbackTimeout": 5000
  },
  "asr": {
    "vad": true,
    "vadMinSilenceDuration": 0.5
  }
}
```

## Conversation Context

Claude Code naturally maintains conversation context within the session. Each `final` ASR message is part of the ongoing conversation — Claude sees all previous exchanges and replies accordingly. No explicit context management is needed; the skill just forwards user speech as text messages in the existing session.

## Future Considerations (Not in v1)

- **Full-duplex:** User can interrupt AI mid-speech
- **Multi-user:** Handle multiple speakers in one channel
- **Telegram support:** Voice message mode
- **Conversation memory:** Persist context across sessions
- **Role presets:** "English tutor", "interview coach", etc.
