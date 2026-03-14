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

**Install local dependencies:**

Check if `node_modules/` exists in the skill's `scripts/` directory:

```bash
ls {skill_scripts_dir}/node_modules/.package-lock.json 2>/dev/null && echo "OK" || echo "MISSING"
```

If MISSING, install:

```bash
cd {skill_scripts_dir} && npm install && cd -
```

Where `{skill_scripts_dir}` is the resolved path to `voice-chat/scripts/`.

### Step 0.5: Config Setup

Follow `shared/config-pattern.md` for config location. Ask user: store config locally (`.listenhub/voice-chat/config.json`) or globally (`~/.listenhub/voice-chat/config.json`)?

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

**Launch the bot** from the skill's scripts directory:

```bash
cd {skill_scripts_dir} && node discord-bot.js \
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
