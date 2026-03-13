<h1 align="center">MarsWave Skills</h1>

<p align="center">
<strong>Explain Anything. In Videos, Podcasts, and More.</strong>
</p>

<p align="center">
<a href="https://listenhub.ai"><img alt="ListenHub" src="https://img.shields.io/badge/Made%20by%20ListenHub-000?logo=listenhub&logoColor=fff" /></a>
<a href="https://discord.gg/ZbwA7g2guU"><img alt="Discord" src="https://img.shields.io/discord/1365293903405645886?label=Discord&logo=discord&color=eee&labelColor=5865f2&logoColor=fff" /></a>
<a href="https://x.com/ListenHub"><img alt="Twitter" src="https://img.shields.io/twitter/follow/ListenHub?logo=x" /></a>
<a href="https://github.com/marswaveai/skills/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/marswaveai/skills?color=blue" /></a>
<br />
English | <a href="./README.zh.md">简体中文</a>
</p>

---

You have ideas worth sharing. [ListenHub](https://listenhub.ai) turns them into content people actually want to watch and listen to — no editing skills required.

## Install

```bash
npx skills add marswaveai/skills
```

## Update

**Via npx skills** (recommended for most users):

```bash
npx skills update -g
```

**Via Git** (for contributors or local development):

```bash
cd path/to/marswaveai/skills
git pull origin main
```

Restart your agent (Claude Code, Cursor, etc.) after updating.

## Skills

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `/podcast` | "make a podcast", "播客" | Generate podcast episodes (solo, dialogue, debate) |
| `/explainer` | "explainer video", "解说视频" | Narrated explainer videos with AI visuals |
| `/tts` | "read aloud", "TTS", "朗读" | Text-to-speech and voice narration |
| `/image-gen` | "generate image", "画一张" | AI image generation from text prompts |
| `/content-parser` | "parse this URL", "解析链接" | Extract content from URLs |
| `/asr` | "transcribe", "语音转文字", "ASR" | Transcribe audio files to text |

## Supported Inputs

- Any topic you can describe
- YouTube videos
- Article URLs
- Plain text
- Image prompts
- Audio files

## Setup

**ListenHub API Key** — [Get yours](https://listenhub.ai/settings/api-keys) (Pro plan required)

Keys auto-configure on first use.

## Directory Structure

```
├── shared/              # API reference, auth, common patterns
├── podcast/             # Podcast generation
├── explainer/           # Explainer videos
├── tts/                 # TTS and voice narration
├── image-gen/           # AI image generation
├── content-parser/      # URL content extraction
├── asr/                 # Audio transcription
└── listenhub/           # Deprecated (see DEPRECATED.md)
```

## Supported Clients

Claude Code · Cursor · Windsurf · OpenCode · Codex · Trae · and more.

If you have any questions, feel free to reach out: support@marswave.ai

## License

MIT
