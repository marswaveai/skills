<h1 align="center">MarsWave Skills</h1>

<p align="center">
<a href="https://github.com/marswaveai"><img alt="MarsWave" src="https://img.shields.io/badge/Made%20by%20MarsWave-000?logoColor=fff" /></a>
<a href="https://discord.gg/ZbwA7g2guU"><img alt="Discord" src="https://img.shields.io/discord/1365293903405645886?label=Discord&logo=discord&color=eee&labelColor=5865f2&logoColor=fff" /></a>
<a href="https://github.com/marswaveai/skills/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/marswaveai/skills?color=blue" /></a>
<br />
English | <a href="./README.zh.md">简体中文</a>
</p>

---

AI-powered skills for your coding agent — by [MarsWave](https://github.com/marswaveai).

## Install

```bash
npx skills add marswaveai/skills
```

## Update

**Via npx skills** (recommended):

```bash
npx skills update -g
```

**Via Git** (for contributors):

```bash
cd path/to/marswaveai/skills
git pull origin main
```

Restart your agent (Claude Code, Cursor, etc.) after updating.

## Skills

### ListenHub — Content Creation

Turn ideas into videos, podcasts, and more. Powered by [ListenHub](https://listenhub.ai).

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `/podcast` | "make a podcast", "播客" | Generate podcast episodes (solo, dialogue, debate) |
| `/explainer` | "explainer video", "解说视频" | Narrated explainer videos with AI visuals |
| `/slides` | "slides", "幻灯片" | Create slide decks with AI visuals |
| `/tts` | "read aloud", "TTS", "朗读" | Text-to-speech and voice narration |
| `/music` | "music", "音乐" | AI music generation and covers |
| `/image-gen` | "generate image", "画一张" | AI image generation from text prompts |
| `/content-parser` | "parse this URL", "解析链接" | Extract content from URLs |
| `/asr` | "transcribe", "语音转文字", "ASR" | Transcribe audio files to text |
| `/creator` | "创作", "写公众号", "小红书", "口播" | Creator workflow — platform-ready content packages |

**Setup:**

```bash
npm install -g @marswave/listenhub-cli
listenhub auth login
```

> `/content-parser` and `/creator` still require a [ListenHub API Key](https://listenhub.ai/settings/api-keys).

### COLA

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `/cola-avatar-pack` | "生成形象", "avatar", "表情包", "梗图" | Generate pixel-art avatar, profile card, emoji GIFs & meme stickers |

**Setup:** Requires Python 3.10+ and Pillow. See [cola-avatar-pack/SKILL.md](cola-avatar-pack/SKILL.md).

## Directory Structure

```
├── shared/              # Shared infrastructure (auth, CLI patterns)
│
│   # ListenHub
├── podcast/             # Podcast generation
├── explainer/           # Explainer videos
├── slides/              # Slide decks
├── tts/                 # Text-to-speech
├── music/               # AI music generation
├── image-gen/           # AI image generation
├── content-parser/      # URL content extraction
├── asr/                 # Audio transcription
├── creator/             # Creator workflow
├── listenhub-cli/       # CLI auth and setup
├── listenhub/           # Router skill
│
│   # COLA
└── cola-avatar-pack/    # Avatar pack generation
```

## Supported Clients

Claude Code · Cursor · Windsurf · OpenCode · Codex · Trae · and more.

If you have any questions, feel free to reach out: support@marswave.ai

## License

MIT
