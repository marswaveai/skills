<h1 align="center">MarsWave Skills</h1>

<p align="center">
<strong>解说万物，一键生成视频、播客、语音</strong>
</p>

<p align="center">
<a href="https://listenhub.ai"><img alt="ListenHub" src="https://img.shields.io/badge/Made%20by%20ListenHub-000?logo=listenhub&logoColor=fff" /></a>
<a href="https://discord.gg/ZbwA7g2guU"><img alt="Discord" src="https://img.shields.io/discord/1365293903405645886?label=Discord&logo=discord&color=eee&labelColor=5865f2&logoColor=fff" /></a>
<a href="https://x.com/ListenHub"><img alt="Twitter" src="https://img.shields.io/twitter/follow/ListenHub?logo=x" /></a>
<a href="https://github.com/marswaveai/skills/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/marswaveai/skills?color=blue" /></a>
<br />
<a href="./README.md">English</a> | 简体中文
</p>

---

你有值得分享的想法。[ListenHub](https://listenhub.ai) 把它们变成人们真正想看、想听的内容——无需剪辑技能。

## 安装

```bash
npx skills add marswaveai/skills
```

## 更新

**通过 npx skills**（推荐大多数用户使用）：

```bash
npx skills update -g
```

**通过 Git**（适合贡献者或本地开发）：

```bash
cd path/to/marswaveai/skills
git pull origin main
```

更新后需重启你的 agent（Claude Code、Cursor 等）。

## 技能列表

| 技能 | 触发词 | 功能 |
|------|--------|------|
| `/podcast` | "做播客"、"podcast" | 生成播客单集（独白、对话、辩论） |
| `/explainer` | "解说视频"、"explainer video" | 带 AI 配图的解说视频 |
| `/tts` | "朗读"、"TTS"、"语音合成" | 文字转语音、配音 |
| `/image-gen` | "生成图片"、"画一张" | AI 图片生成 |
| `/content-parser` | "解析链接"、"提取内容" | URL 内容提取 |
| `/asr` | "转录"、"语音转文字"、"ASR" | 音频文件转文字 |
| `/creator` | "创作"、"写公众号"、"小红书"、"口播" | 创作者工作流 — 一键生成平台内容包 |

## 支持的输入

- 任何你能描述的主题
- YouTube 视频
- 文章链接
- 纯文本
- 图片描述
- 音频文件

## 配置

**ListenHub API Key** — [获取](https://listenhub.ai/zh/settings/api-keys)（Pro 订阅）

首次使用时自动配置。

## 目录结构

```
├── shared/              # API 参考、认证、通用模式
├── podcast/             # 播客生成
├── explainer/           # 解说视频
├── tts/                 # 文字转语音
├── image-gen/           # AI 图片生成
├── content-parser/      # URL 内容提取
├── asr/                 # 音频转文字
├── creator/             # 创作者工作流
└── listenhub/           # 已弃用（见 DEPRECATED.md）
```

## 支持的客户端

Claude Code · Cursor · Windsurf · OpenCode · Codex · Trae 等

如有任何问题，欢迎联系我们：support@marswave.ai

## 许可证

MIT
