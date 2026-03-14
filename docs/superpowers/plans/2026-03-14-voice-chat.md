# Voice Chat Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code skill that launches a Discord voice bot — users speak in a voice channel, coli does ASR/TTS, Claude generates replies.

**Architecture:** A Node.js script (`discord-bot.js`) runs as a child process, communicating with Claude Code via stdin/stdout JSON lines. Discord.js handles voice channel I/O, coli handles ASR (with VAD) and TTS (cloud + local fallback). The SKILL.md orchestrates environment setup, config, and the conversation loop.

**Tech Stack:** Node.js, discord.js + @discordjs/voice, @marswave/coli (ASR + TTS), @discordjs/opus, prism-media, ffmpeg

**Spec:** `docs/superpowers/specs/2026-03-14-voice-chat-design.md`

---

## File Map

| File | Purpose |
|---|---|
| `voice-chat/SKILL.md` | Skill definition — interaction flow, environment checks, config, conversation loop |
| `voice-chat/scripts/discord-bot.js` | Discord bot + coli ASR/TTS pipeline, stdin/stdout JSON protocol |
| `voice-chat/scripts/package.json` | Dependency declarations (copied to `~/.listenhub/voice-chat/` on first run) |
| `shared/api-speakers.md` | Already exists — speaker list API reference (reused) |
| `shared/config-pattern.md` | Already exists — config management pattern (reused) |
| `shared/common-patterns.md` | Already exists — error handling patterns (reused) |

---

## Chunk 1: discord-bot.js — the Node.js script

This is the core: a standalone script that connects to Discord, receives audio, runs ASR, does TTS, and communicates with Claude Code via stdin/stdout.

### Task 1: Project scaffolding and package.json

**Files:**
- Create: `voice-chat/scripts/package.json`

- [ ] **Step 1: Create package.json with all dependencies**

```json
{
  "name": "voice-chat-bot",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=18"
  },
  "dependencies": {
    "discord.js": "^14.18.0",
    "@discordjs/voice": "^0.18.0",
    "@discordjs/opus": "^0.9.0",
    "@marswave/coli": "latest",
    "sodium-native": "^4.3.1",
    "prism-media": "^1.3.5"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add voice-chat/scripts/package.json
git commit -m "feat(voice-chat): add package.json for bot dependencies"
```

### Task 2: discord-bot.js — startup and Discord connection

**Files:**
- Create: `voice-chat/scripts/discord-bot.js`

- [ ] **Step 1: Write the startup section**

The script reads CLI args, logs into Discord, finds the voice channel, checks for users, and joins. All output goes to stdout as JSON lines. All input comes from stdin as JSON lines.

```js
#!/usr/bin/env node

import { Client, GatewayIntentBits } from 'discord.js';
import {
  joinVoiceChannel,
  VoiceConnectionStatus,
  entersState,
  createAudioPlayer,
  createAudioResource,
  AudioPlayerStatus,
  StreamType,
} from '@discordjs/voice';
import { OpusEncoder } from '@discordjs/opus';
import { streamAsr, ensureModels, ensureVadModel, runCloudTts, runTts } from '@marswave/coli';
import { createReadStream } from 'node:fs';
import { unlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

// --- JSON line protocol helpers ---

function emit(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

// --- Parse CLI args ---

const args = process.argv.slice(2);
const config = {};
for (let i = 0; i < args.length; i += 2) {
  const key = args[i].replace(/^--/, '');
  config[key] = args[i + 1];
}

const {
  token,
  channelId,
  guildId,
  language = 'zh',
  speakerId,
  apiKey,
  ttsTimeout = '5000',
} = config;

if (!token || !channelId || !guildId) {
  emit({ type: 'error', message: 'Missing required args: --token, --channelId, --guildId' });
  process.exit(1);
}

// --- State ---

let asrPaused = false;
let activeUserId = null;
let connection = null;
let player = null;

// --- Main ---

async function main() {
  // Ensure ASR models are ready
  await ensureModels(['sensevoice']);
  await ensureVadModel();

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates],
  });

  client.once('ready', async () => {
    const guild = client.guilds.cache.get(guildId);
    if (!guild) {
      emit({ type: 'error', message: `Guild ${guildId} not found` });
      process.exit(1);
    }

    const channel = guild.channels.cache.get(channelId);
    if (!channel) {
      emit({ type: 'error', message: `Channel ${channelId} not found` });
      process.exit(1);
    }

    // Check if anyone is in the channel
    if (channel.members.size === 0) {
      emit({ type: 'waiting', channel: channel.name });

      // Wait for someone to join
      await new Promise((resolve) => {
        const handler = (oldState, newState) => {
          if (newState.channelId === channelId && !newState.member.user.bot) {
            client.off('voiceStateUpdate', handler);
            resolve();
          }
        };
        client.on('voiceStateUpdate', handler);
      });
    }

    // Join voice channel
    connection = joinVoiceChannel({
      channelId,
      guildId,
      adapterCreator: guild.voiceAdapterCreator,
      selfDeaf: false,
    });

    await entersState(connection, VoiceConnectionStatus.Ready, 10_000);

    player = createAudioPlayer();
    connection.subscribe(player);

    emit({ type: 'ready', channel: channel.name, guild: guild.name });
    emit({ type: 'listening' });

    // Start listening for audio
    startAudioReceiver(connection);

    // Listen for user leaving channel
    client.on('voiceStateUpdate', (oldState, newState) => {
      if (
        oldState.channelId === channelId &&
        newState.channelId !== channelId &&
        !oldState.member.user.bot
      ) {
        // Check if channel is now empty (only bot)
        const nonBotMembers = channel.members.filter((m) => !m.user.bot);
        if (nonBotMembers.size === 0) {
          emit({ type: 'disconnected', reason: 'user_left' });
          cleanup();
        }
      }
    });
  });

  // Handle stdin commands
  const rl = createInterface({ input: process.stdin });
  rl.on('line', async (line) => {
    try {
      const msg = JSON.parse(line);
      if (msg.type === 'reply') {
        await handleReply(msg.text);
      } else if (msg.type === 'stop') {
        cleanup();
      }
    } catch {
      // Ignore malformed input
    }
  });

  await client.login(token);
}

function cleanup() {
  if (connection) connection.destroy();
  process.exit(0);
}

// Placeholder — implemented in Task 3
function startAudioReceiver(_connection) {}

// Placeholder — implemented in Task 4
async function handleReply(_text) {}

main().catch((err) => {
  emit({ type: 'error', message: err.message });
  process.exit(1);
});
```

- [ ] **Step 2: Verify syntax**

Since this is an ESM module (`"type": "module"` in package.json), `node --check` won't work. Instead, verify the file parses correctly:

```bash
node --input-type=module --check < voice-chat/scripts/discord-bot.js
```

Expected: no output (valid syntax). Import resolution errors are expected (deps not installed) but won't appear with `--check`.

- [ ] **Step 3: Commit**

```bash
git add voice-chat/scripts/discord-bot.js
git commit -m "feat(voice-chat): add discord-bot.js with startup and Discord connection"
```

### Task 3: discord-bot.js — Audio receive and ASR pipeline

**Files:**
- Modify: `voice-chat/scripts/discord-bot.js`

- [ ] **Step 1: Implement `startAudioReceiver`**

Replace the placeholder `startAudioReceiver` function. This subscribes to user audio from the Discord voice connection, decodes Opus packets to PCM, wraps them as an `AsyncIterable<Float32Array>`, and feeds them to coli's `streamAsr`.

```js
function startAudioReceiver(voiceConnection) {
  const receiver = voiceConnection.receiver;
  const subscribedUsers = new Set();
  const decoder = new OpusEncoder(48000, 2);

  receiver.speaking.on('start', (userId) => {
    // Only listen to first non-bot user
    if (activeUserId && activeUserId !== userId) return;
    if (asrPaused) return;
    if (subscribedUsers.has(userId)) return;

    if (!activeUserId) {
      activeUserId = userId;
    }

    subscribedUsers.add(userId);

    const opusStream = receiver.subscribe(userId, {
      end: { behavior: 'afterSilence', duration: 100 },
    });

    let resolveChunk = null;
    let chunkQueue = [];
    let streamEnded = false;

    // Create an AsyncIterable<Float32Array> from Opus packets
    const audioIterable = {
      [Symbol.asyncIterator]() {
        return {
          next() {
            if (chunkQueue.length > 0) {
              return Promise.resolve({ value: chunkQueue.shift(), done: false });
            }
            if (streamEnded) {
              return Promise.resolve({ value: undefined, done: true });
            }
            return new Promise((resolve) => {
              resolveChunk = resolve;
            });
          },
        };
      },
    };

    function pushChunk(float32) {
      if (resolveChunk) {
        const r = resolveChunk;
        resolveChunk = null;
        r({ value: float32, done: false });
      } else {
        chunkQueue.push(float32);
      }
    }

    function endStream() {
      streamEnded = true;
      subscribedUsers.delete(userId);
      if (resolveChunk) {
        const r = resolveChunk;
        resolveChunk = null;
        r({ value: undefined, done: true });
      }
    }

    opusStream.on('data', (packet) => {
      if (asrPaused) return;

      // Decode Opus to PCM (int16, 48kHz stereo)
      const pcm48k = decoder.decode(packet);

      // Downsample 48kHz stereo int16 → 16kHz mono float32
      const samples48k = new Int16Array(pcm48k.buffer, pcm48k.byteOffset, pcm48k.byteLength / 2);
      const monoLength = Math.floor(samples48k.length / 2); // stereo → mono
      const ratio = 3; // 48000 / 16000
      const outLength = Math.min(
        Math.floor(monoLength / ratio),
        Math.floor((samples48k.length - 1) / (ratio * 2)), // bounds guard
      );
      const float32 = new Float32Array(outLength);

      for (let i = 0; i < outLength; i++) {
        const srcIdx = i * ratio * 2; // *2 for stereo
        float32[i] = (samples48k[srcIdx] + samples48k[srcIdx + 1]) / 2 / 32768;
      }

      pushChunk(float32);
    });

    opusStream.on('end', () => {
      endStream();
    });

    opusStream.on('error', () => {
      endStream();
    });

    // Run ASR on this audio stream segment
    // A new streamAsr session is created each time the user speaks,
    // because the AsyncIterable ends when the user stops speaking.
    // coli's VAD handles segment boundaries within each session.
    streamAsr(audioIterable, {
      vad: true,
      model: 'sensevoice',
      onResult(result) {
        if (result.isFinal) {
          const text = result.text?.trim();
          if (!text) return; // Discard empty
          emit({
            type: 'final',
            text,
            ...(result.lang && { lang: result.lang }),
            ...(result.emotion && { emotion: result.emotion }),
          });
        } else {
          emit({ type: 'partial', text: result.text });
        }
      },
    }).catch((err) => {
      emit({ type: 'error', message: `ASR error: ${err.message}` });
    });
  });
}
```

- [ ] **Step 2: Remove the placeholder**

Delete the line `function startAudioReceiver(_connection) {}` and replace with the implementation above.

- [ ] **Step 3: Commit**

```bash
git add voice-chat/scripts/discord-bot.js
git commit -m "feat(voice-chat): add audio receive and ASR pipeline"
```

### Task 4: discord-bot.js — TTS reply handler with fallback

**Files:**
- Modify: `voice-chat/scripts/discord-bot.js`

- [ ] **Step 1: Implement `handleReply`**

Replace the placeholder `handleReply` function. This calls coli's cloud TTS, falls back to local TTS on timeout, then plays the audio in the Discord voice channel.

```js
async function handleReply(text) {
  emit({ type: 'tts_start' });
  asrPaused = true;

  const ttsTimeoutMs = Number.parseInt(ttsTimeout, 10);
  const tmpPath = join(tmpdir(), `voice-chat-tts-${Date.now()}.mp3`);

  try {
    // Try cloud TTS with timeout
    let usedCloud = false;

    try {
      await Promise.race([
        runCloudTts(text, {
          apiKey,
          voice: speakerId,
          output: tmpPath,
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('TTS timeout')), ttsTimeoutMs),
        ),
      ]);
      usedCloud = true;
    } catch (err) {
      emit({ type: 'error', message: `Cloud TTS failed: ${err.message}, falling back to local` });

      // Fallback to local TTS (macOS say)
      const localPath = join(tmpdir(), `voice-chat-tts-${Date.now()}.aiff`);
      try {
        await runTts(text, { output: localPath });
        // Use local file instead
        await playAudio(localPath);
        await unlink(localPath).catch(() => {});
        return;
      } catch (localErr) {
        emit({ type: 'error', message: `Local TTS also failed: ${localErr.message}` });
        return;
      }
    }

    if (usedCloud) {
      await playAudio(tmpPath);
      await unlink(tmpPath).catch(() => {});
    }
  } finally {
    asrPaused = false;
    emit({ type: 'listening' });
    emit({ type: 'tts_done' });
  }
}

function playAudio(filePath) {
  return new Promise((resolve, reject) => {
    const resource = createAudioResource(createReadStream(filePath), {
      inputType: StreamType.Arbitrary,
    });
    player.play(resource);
    player.once(AudioPlayerStatus.Idle, resolve);
    player.once('error', reject);
  });
}
```

- [ ] **Step 2: Remove the placeholder**

Delete the line `async function handleReply(_text) {}` and replace with the implementation above.

- [ ] **Step 3: Commit**

```bash
git add voice-chat/scripts/discord-bot.js
git commit -m "feat(voice-chat): add TTS reply handler with cloud/local fallback"
```

### Task 5: Smoke test discord-bot.js syntax

**Files:**
- None (verification only)

- [ ] **Step 1: Verify the complete script parses as valid ESM**

```bash
node --input-type=module --check < voice-chat/scripts/discord-bot.js
```

Expected: no output (valid syntax).

- [ ] **Step 2: Verify all key functions exist**

```bash
grep -c 'function startAudioReceiver\|async function handleReply\|function playAudio\|function emit\|async function main' voice-chat/scripts/discord-bot.js
```

Expected: `5` (all five functions present).

---

## Chunk 2: SKILL.md — the skill definition

This defines the interaction flow that Claude Code follows when the user invokes `/voice-chat`.

### Task 6: Create SKILL.md

**Files:**
- Create: `voice-chat/SKILL.md`

- [ ] **Step 1: Write the complete SKILL.md**

The skill follows the standard pattern: frontmatter → hard constraints → interaction flow (env check → config → setup → launch → conversation loop → cleanup).

```markdown
---
name: voice-chat
metadata:
  openclaw:
    emoji: "📞"
    requires:
      env: ["COLI_LISTENHUB_API_KEY"]
      tools: ["coli", "ffmpeg"]
    primaryEnv: "COLI_LISTENHUB_API_KEY"
description: |
  AI voice chat via Discord. Launch a bot that joins a Discord voice channel
  for real-time voice conversation. "voice chat", "语音聊天", "Discord 通话"
---

# Voice Chat

## Purpose

Launch a Discord voice bot that lets you have a real-time voice conversation with Claude. You speak in a Discord voice channel, Claude listens (via coli ASR with VAD), thinks, and speaks back (via coli cloud TTS with local fallback).

## When to Use

- User wants to talk to Claude by voice
- User mentions Discord voice chat, voice call, 语音聊天, 语音通话
- User wants to set up a voice bot

## When NOT to Use

- User wants text-to-speech only → use `/tts`
- User wants to transcribe an audio file → use `/asr`
- User wants a podcast or explainer → use `/podcast` or `/explainer`

<HARD-GATE>
- **Language adaptation**: respond in the user's language (Chinese input → Chinese, English → English)
- **One question at a time**: use `AskUserQuestion` for all multiple-choice questions, wait for answer before proceeding
- **Confirm before launch**: summarize config, get explicit user confirmation before starting the bot
- **No shell scripts**: use direct commands only
- Read config per `shared/config-pattern.md`
</HARD-GATE>

## Interaction Flow

### Step -1: API Key Check

Check `COLI_LISTENHUB_API_KEY` (this is coli's own env var for ListenHub cloud TTS, separate from `LISTENHUB_API_KEY` used by other skills):

```bash
[ -z "$COLI_LISTENHUB_API_KEY" ] && echo "MISSING" || echo "OK"
```

If MISSING, stop and tell the user:

> You need a ListenHub API key for voice synthesis.
> Get one at: https://listenhub.ai/zh/settings/api-keys (中文)
> or: https://listenhub.ai/en/settings/api-keys (English)
>
> Then set it:
> ```
> export COLI_LISTENHUB_API_KEY="lh_sk_..."
> ```

Do NOT proceed until the key is set.

### Step 0: Environment & Dependencies

**Check and update coli:**

```bash
COLI_INSTALLED=$(npm list -g @marswave/coli --depth=0 2>/dev/null | grep @marswave/coli || echo "")
COLI_LATEST=$(npm view @marswave/coli version 2>/dev/null || echo "")
```

- If not installed: `npm install -g @marswave/coli`
- If installed but outdated (compare versions): `npm install -g @marswave/coli@latest`
- If up to date: skip

**Check ffmpeg:**

```bash
which ffmpeg >/dev/null 2>&1 && echo "OK" || echo "MISSING"
```

If MISSING: tell user to install (`brew install ffmpeg` on macOS).

**Check Node.js version:**

```bash
node -v
```

Must be ≥ 18.

**Install local dependencies (always at `~/.listenhub/voice-chat/`):**

Resolve the skill directory path first, then copy package.json and install:

```bash
VOICE_CHAT_DIR="$HOME/.listenhub/voice-chat"
if [ ! -d "$VOICE_CHAT_DIR/node_modules" ]; then
  mkdir -p "$VOICE_CHAT_DIR"
fi
```

Then copy `voice-chat/scripts/package.json` to `$VOICE_CHAT_DIR/package.json` (use the resolved skill path, not `$(dirname "$0")`), and run `cd "$VOICE_CHAT_DIR" && npm install && cd -`.

### Step 0.5: Config Setup

Follow `shared/config-pattern.md` for config location. Ask user: store config locally (`.listenhub/voice-chat/config.json`) or globally (`~/.listenhub/voice-chat/config.json`)?

Note: node_modules always live at `~/.listenhub/voice-chat/` regardless of config location.

If config exists, display summary and ask: reuse or reconfigure?

If no config or user wants to reconfigure, proceed to Step 1.

### Step 1: Discord Bot Configuration

**If first time (no `discord.token` in config):**

Tell the user:

> To create a Discord bot:
> 1. Go to https://discord.com/developers/applications
> 2. Click "New Application", give it a name
> 3. Go to "Bot" tab, click "Reset Token", copy the token
> 4. Under "Privileged Gateway Intents", enable **Server Members Intent** and **Message Content Intent** are NOT needed — but go to Bot settings and make sure the bot can join voice
> 5. Go to "OAuth2" → "URL Generator":
>    - Scopes: `bot`
>    - Bot Permissions: `Connect`, `Speak`
> 6. Copy the generated URL and open it to invite the bot to your server

Then ask for:

1. **Discord Bot Token** (free text input)
2. **Guild (server) ID** (free text — tell user: right-click server name → "Copy Server ID", needs Developer Mode on in Discord settings)
3. **Voice Channel ID** (free text — tell user: right-click voice channel → "Copy Channel ID")

Save to config.

### Step 2: TTS Configuration

Ask language using `AskUserQuestion`:
- 中文 (zh)
- English (en)

Fetch speaker list using coli:

```bash
coli cloud-tts --list-speakers --language {lang} --json
```

Present speakers as a text table. Ask user to pick one (free text matching per `shared/speaker-selection.md`).

Ask fallback timeout using `AskUserQuestion`:
- 5 seconds (recommended)
- 10 seconds
- 3 seconds

Save to config.

### Step 3: Confirm and Launch

Display summary:

> **Voice Chat Configuration:**
> - Discord server: {guildId}
> - Voice channel: {channelId}
> - Language: {language}
> - Voice: {speakerName} ({speakerId})
> - TTS fallback timeout: {ttsTimeout}ms
>
> Ready to start?

Wait for user confirmation.

**Launch the bot** (use resolved skill path for the script):

```bash
NODE_PATH="$HOME/.listenhub/voice-chat/node_modules" node "{resolved_skill_path}/scripts/discord-bot.js" \
  --token "$DISCORD_TOKEN" \
  --channelId "$CHANNEL_ID" \
  --guildId "$GUILD_ID" \
  --language "$LANGUAGE" \
  --speakerId "$SPEAKER_ID" \
  --apiKey "$COLI_LISTENHUB_API_KEY" \
  --ttsTimeout "$TTS_TIMEOUT"
```

Run this with `run_in_background: true` and capture the task ID.

Start reading stdout. Wait for the first message:

- `{"type":"waiting",...}` → Display "Waiting for you to join the voice channel..."
- `{"type":"ready",...}` → Display "Bot is online! Joined #{channel}. Start speaking!"
- `{"type":"error",...}` → Display error and stop

### Step 4: Conversation Loop

Listen on the bot's stdout. For each line:

| Message type | Action |
|---|---|
| `{"type":"partial","text":"..."}` | Optionally display: `🎙️ (hearing: {text}...)` |
| `{"type":"final","text":"..."}` | Display the user's speech. Generate a reply as Claude. Send to stdin: `{"type":"reply","text":"<claude_reply>"}` |
| `{"type":"tts_start"}` | Optionally display: `🔊 Speaking...` |
| `{"type":"tts_done"}` | Optionally display: `🎙️ Listening...` |
| `{"type":"listening"}` | No action needed |
| `{"type":"error","message":"..."}` | Display warning |
| `{"type":"disconnected",...}` | Display "Call ended." → go to Step 5 |

**Generating replies:** When a `final` message arrives, treat the `text` as if the user typed it. Generate a conversational reply. Keep it concise — this is a voice conversation, not a written one. Aim for 1-3 sentences.

**Ending the call:** If user says "bye", "再见", "hangup", "结束通话", or similar, send `{"type":"stop"}` to stdin and go to Step 5.

Also end if the user presses Ctrl+C or types "stop" in the Claude Code session.

### Step 5: Cleanup

- Kill the background bot process
- Display: "Call ended. 👋"
- Update config with any changed preferences (merge pattern)
```

- [ ] **Step 2: Verify SKILL.md frontmatter**

```bash
head -10 voice-chat/SKILL.md
```

Expected: valid YAML frontmatter with `name: voice-chat`.

- [ ] **Step 3: Commit**

```bash
git add voice-chat/SKILL.md
git commit -m "feat(voice-chat): add SKILL.md with complete interaction flow"
```

### Task 7: Add shared symlink

**Files:**
- Create: `voice-chat/shared` (symlink)

- [ ] **Step 1: Create symlink to shared docs (following existing skill convention)**

```bash
cd voice-chat && ln -s ../shared shared && cd ..
```

- [ ] **Step 2: Verify**

```bash
ls -la voice-chat/shared/
```

Expected: shows symlinked files (api-speakers.md, config-pattern.md, etc.)

- [ ] **Step 3: Commit**

```bash
git add voice-chat/shared
git commit -m "feat(voice-chat): add shared docs symlink"
```

---

## Chunk 3: Integration and README

### Task 8: Update README

**Files:**
- Modify: `README.md`
- Modify: `README.zh.md`

- [ ] **Step 1: Add voice-chat to the skills table in README.md**

Find the skills table in `README.md` and add a row for voice-chat. Follow the existing format.

- [ ] **Step 2: Add voice-chat to README.zh.md**

Same update for the Chinese README.

- [ ] **Step 3: Commit**

```bash
git add README.md README.zh.md
git commit -m "docs: add voice-chat skill to README"
```

### Task 9: Manual integration test

**Files:** None (verification only)

- [ ] **Step 1: Verify skill structure matches convention**

```bash
ls -la voice-chat/
ls -la voice-chat/scripts/
cat voice-chat/scripts/package.json | jq .
head -10 voice-chat/SKILL.md
```

Expected structure:
```
voice-chat/
├── SKILL.md
├── scripts/
│   ├── discord-bot.js
│   └── package.json
└── shared -> ../shared
```

- [ ] **Step 2: Validate SKILL.md with skill-creator validator (if available)**

```bash
python3 ~/.claude/skills/skill-creator/scripts/quick_validate.py voice-chat/
```

Expected: validation passes.

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A && git status
# Only commit if there are changes
git diff --staged --quiet || git commit -m "fix(voice-chat): address validation issues"
```

---

## Execution Notes

**Testing is limited for this skill** because:
- Discord bot requires a real bot token + server + voice channel
- coli ASR requires audio models downloaded
- TTS requires a valid `COLI_LISTENHUB_API_KEY`

The plan focuses on structural correctness and syntax validation. Real end-to-end testing happens manually with actual Discord infrastructure.

**Key files to reference during implementation:**
- Spec: `docs/superpowers/specs/2026-03-14-voice-chat-design.md`
- Existing skill example: `tts/SKILL.md` (closest pattern)
- Config pattern: `shared/config-pattern.md`
- Speaker selection: `shared/speaker-selection.md`
