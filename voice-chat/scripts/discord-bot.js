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
import pkg from '@discordjs/opus';
const { OpusEncoder } = pkg;
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
const cliConfig = {};
for (let i = 0; i < args.length; i += 2) {
  const key = args[i].replace(/^--/, '');
  cliConfig[key] = args[i + 1];
}

const {
  token,
  channelId,
  guildId,
  language = 'zh',
  speakerId,
  apiKey,
  ttsTimeout = '5000',
} = cliConfig;

if (!token || !channelId || !guildId) {
  emit({ type: 'error', message: 'Missing required args: --token, --channelId, --guildId' });
  process.exit(1);
}

// --- State ---

let asrPaused = false;
let activeUserId = null;
let connection = null;
let player = null;

// --- Audio Receive and ASR Pipeline ---

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

    // Run ASR on this audio stream segment.
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

// --- TTS Reply Handler ---

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

main().catch((err) => {
  emit({ type: 'error', message: err.message });
  process.exit(1);
});
