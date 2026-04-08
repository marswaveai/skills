---
name: listenhub-cli
description: |
  ListenHub CLI skills router. Routes to the correct skill based on user intent.
  Triggers on: "make a podcast", "explainer video", "read aloud", "TTS",
  "generate image", "做播客", "解说视频", "朗读", "生成图片", "幻灯片",
  "slides", "音乐", "music", "generate music", "翻唱", "cover song",
  "parse URL", "解析链接", "提取内容".
metadata:
  openclaw:
    emoji: "🎧"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
---

## Purpose

This is a router skill. When users trigger a general ListenHub action, this skill identifies the intent and delegates to the appropriate specialized skill.

## Routing Table

| User intent | Keywords | Route to |
|-------------|----------|----------|
| Podcast | "podcast", "播客", "debate", "dialogue" | `/podcast` |
| Explainer video | "explainer", "解说视频", "tutorial video" | `/explainer` |
| Slides / PPT | "slides", "幻灯片", "PPT", "presentation" | `/slides` |
| TTS / Read aloud | "TTS", "read aloud", "朗读", "配音", "语音合成" | `/tts` |
| Image generation | "generate image", "画一张", "生成图片", "AI图" | `/image-gen` |
| Music | "music", "音乐", "生成音乐", "翻唱", "cover" | `/music` |
| Content extraction | "parse URL", "extract content", "解析链接" | `/content-parser` |
| Audio transcription | "transcribe", "ASR", "语音转文字" | `/asr` |
| Creator workflow | "创作", "写公众号", "小红书", "口播" | `/creator` |

## How to Route

1. Read the user's message and identify which category it falls into
2. Tell the user which skill you're routing to
3. Follow that skill's SKILL.md completely

If the intent is ambiguous, ask the user to clarify:

```
Question: "What would you like to create?"
Options:
  - "Podcast" — Audio discussion on a topic
  - "Explainer Video" — Narrated video with AI visuals
  - "Slides" — Slide deck / presentation
  - "Music" — AI-generated music or cover
```

## Prerequisites

Most skills require the ListenHub CLI. Check:

```bash
listenhub auth status --json
```

If not installed or not logged in, guide the user:

1. Install: `npm install -g @marswave/listenhub-cli`
2. Login: `listenhub auth login`

Exception: `/asr` runs locally and needs no CLI or API key.
