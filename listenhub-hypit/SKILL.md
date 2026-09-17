---
name: listenhub-hypit
description: 用 ListenHub 生成素材、hypit 本地编排和渲染视频。适用于“用 ListenHub 做 hypit 视频”、参考片复刻、短剧、播客、街访、排行榜、旁白演示和无口播的宠物动作 meme。
metadata:
  openclaw:
    emoji: "🎬"
    requires:
      bin: ["listenhub", "node", "npm", "ffmpeg", "uv"]
    primaryBin: "npx"
---

把用户的参考片、brief 或自有素材变成可继续编辑的 hypit 项目和实际成片。ListenHub 负责所有生成与词级转写，hypit 负责本地分析、Script、字幕对齐计算、合成和渲染；不需要 HypiHub 账号。

## 先确定这条片子

从已给内容确定起点、片长、画幅、语言、角色和声音；只问仍缺少且影响结果的信息。覆盖口播、短剧、播客、街访、排行榜、主讲演示、旁白驱动及宠物 meme。参考片复刻分析的是镜头/节奏/动作/信息结构，不把格式压成口播换脸。用户授权自行选参考时搜索可下载的公开参考视频，记录来源和使用许可。

阅读 [setup.md](references/setup.md) 准备环境；读取已安装的 `/hypit` skill 及与当前格式相关的参考文档，保留其 Script、构图、字幕与质量验收方法。素材生成与报价按本 skill 路由。具体生产和增量修改见 [production.md](references/production.md)。

## 生成路由与报价

在**任何付费调用前**按 [pricing.md](references/pricing.md) 列计划项、估价来源、合计、余额和预留余量，取得用户对该账号、范围和预算的确认；已有明确授权覆盖这些条件时直接执行，不重复逐段确认。包括参考片转写、抠图在内，不把分析步骤当免费。改一句台词或加变体只报新增费用，账号/范围/预算变化才重新确认。报价同时作为下列子 skill 的本次参数及费用授权，执行参数沿用已确认选择。

| 工作 | 路由 |
|---|---|
| 角色、人像、产品和机位图 | `/image-gen`，用 ListenHub OpenAPI；结果落 `assets/` |
| 视频 Take | `/video-gen`，只选择 Seedance Pro/Fast（效果优先）或 MiniMax H3（性价比） |
| 内置音色配音 | `/tts`，OpenAPI 模式、按 Script Segment 生成 |
| 持久音色 | `/voice-clone` 建一次 speaker，记录 `speakerInnerId`，之后 `/tts` 复用 |
| 一次性参考克隆、多声音、音效 | `/listenhub-voice`，不创建持久 speaker |
| 原创音乐、分轨取人声、歌词及时间 | `/music`，ListenHub OpenAPI 模式 |
| 词级转写与字幕对齐证据 | 随 skill 的 Provider → ListenHub 转写，支持语言见 [provider.md](references/provider.md) |
| 静态抠图 | Provider → Seedream 5.0 Pro 原图换绿幕 → 本地 JS 键控 |

既有生成 skill 有更宽的默认模型表；本工作流显式传已选择的模型和参数，不继承其默认视频模型。所有生成只调用 ListenHub 公开 API/CLI。当前 CLI 某参数尚不可用时按对应 ListenHub API 合约调用，不切换服务。没有用户音频时生成原创 BGM；用户给出的本地歌曲可作参考音频/BGM/歌声源，仅提示一次“请确认你有权使用这段音频，版权责任由你承担”。不从任何平台代下载音频；参考视频的音轨只用于该视频分析，不提取成歌曲素材。

## 交付

先 `npx hypit check`、`npx hypit plan`，确认只有本地端点与 `listenhub.local`；`npx hypit pricing` 仅列 Provider 的转写与抠图，不能代替整条报价。素材通过 `asset:Image/Video/Audio` 或 `.svrun` 的 `<file>` Candidate 接入。用户无需手敲命令。

渲染后播放/抽帧检查画面、字幕同步、声音、边缘和转场。展示实际本地 MP4/可播放结果及关键帧，交付项目路径、报价与实扣差额。保留 hypit CLI、Studio、run report、manifest 的名字、LOGO 和版权，不把 hypit 作为托管或收费产品分发。本 skill 和 Provider 按 MIT 免费开源；hypit 为外部安装依赖，遵守其自身协议。
