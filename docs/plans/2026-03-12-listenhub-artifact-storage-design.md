# Design: ListenHub Artifact Storage (.listenhub)

**Date**: 2026-03-12
**Scope**: Global — applies to all ListenHub skills (podcast, content-parser, tts, image-gen, etc.)
**Status**: Approved

## Background

ListenHub skills generate artifacts (audio, transcripts, images, JSON data) that currently have no
consistent storage convention. The podcast skill saved drafts to `~/Downloads/`, other skills had
no download behavior at all. This design establishes a unified, per-skill artifact storage system.

## Goals

- All skills write their output to a predictable, version-controlled-friendly directory
- Per-skill config persists user preferences across sessions (language, voice, mode, etc.)
- Users are never surprised: storage location is confirmed once and remembered
- Artifacts for the same job are grouped together for easy retrieval

## Directory Structure

```
.listenhub/               ← base directory, in CWD or ~/.listenhub/ (global)
  podcast/
    config.json           ← podcast-specific user preferences
    2026-03-12-{episodeId}/
      {episodeId}.mp3     ← final audio
      {episodeId}.md      ← human-readable transcript
      {episodeId}.json    ← raw scripts array
  content-parser/
    config.json
    2026-03-12-{jobId}/
      {jobId}.md
      {jobId}.json
  tts/
    config.json
    2026-03-12-{jobId}/
      {jobId}.mp3
  image-gen/
    config.json
    2026-03-12-{jobId}/
      {jobId}.png
```

**Rules:**
- Base directory name is always `.listenhub`
- Each skill owns exactly one subdirectory named after the skill
- Each job gets a subfolder named `YYYY-MM-DD-{jobId}` (date = generation date, jobId = API-returned ID)
- All artifacts for a job go into its folder — no files at the skill level except `config.json`

## Config File

### Location & Lookup Order

Skills look for config in this order, stopping at the first match:

1. `{CWD}/.listenhub/{skill}/config.json` — project-level config
2. `~/.listenhub/{skill}/config.json` — global config
3. Neither found → **prompt user** (see below)

### First-Run Prompt

When no config file is found, the skill MUST use `AskUserQuestion` with options:

```
Question: "ListenHub 配置文件存在哪里？"
Options:
  - "当前目录" — 创建 .listenhub/podcast/config.json，仅此项目使用
  - "全局"     — 创建 ~/.listenhub/podcast/config.json，所有项目共用
```

After the user selects, the skill creates the directory and writes an initial `config.json` with
defaults. This prompt is shown **once per skill per location** — never again once config exists.

### Schema (podcast)

```json
{
  "outputDir": ".listenhub",
  "autoDownload": true,
  "language": "zh",
  "defaultMode": "deep",
  "defaultSpeakers": {
    "zh": ["speaker-id-1"],
    "en": ["speaker-id-2"]
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `outputDir` | string | `.listenhub` | Base directory relative to CWD, or absolute path |
| `autoDownload` | boolean | `true` | Automatically download artifacts after generation |
| `language` | string | `null` | Pre-fills the language step; `null` means always ask |
| `defaultMode` | string | `null` | Pre-fills the mode step; `null` means always ask |
| `defaultSpeakers` | object | `{}` | Map of language → array of speakerIds from last session |

Config values are used as **defaults**, not hard overrides. The user can still change them during
the interaction. After a successful generation, the skill updates `language`, `defaultMode`, and
`defaultSpeakers` to reflect the user's latest choices.

Other skills define their own config schema with only the fields relevant to them.

## Download Behavior

### autoDownload: true (default)

After a job completes:

1. Create `{outputDir}/{skill}/YYYY-MM-DD-{jobId}/`
2. Download each artifact with `curl -sS -o {path} {url}`
3. Present results:

```
播客已生成！

「{title}」

在线收听：https://listenhub.ai/app/episode/{episodeId}
MP3 直链： {audioUrl}

已下载到 .listenhub/podcast/2026-03-12-{episodeId}/：
  {episodeId}.mp3
  {episodeId}.md
  {episodeId}.json
```

### autoDownload: false

Skip all downloads. Present only the online link and direct URL. No local files created.

## Two-Step Generation (podcast)

| Step | Before | After |
|------|--------|-------|
| Text draft saved | `~/Downloads/{episodeId}.md` + `.json` | `.listenhub/podcast/YYYY-MM-DD-{episodeId}/{episodeId}-draft.md` + `-draft.json` |
| User reviews draft | — | — (no change) |
| Audio generation done | only link shown | MP3 downloaded to same folder; `-draft` files remain |

The `-draft` suffix distinguishes pre-approval files from the final output. After audio is
generated, the folder contains both draft and final artifacts.

## Applying to Other Skills

Each skill that produces downloadable artifacts should:

1. Read config from `.listenhub/{skill}/config.json` (CWD or global)
2. Prompt once if no config exists
3. Create `YYYY-MM-DD-{jobId}/` under `{outputDir}/{skill}/`
4. Download artifacts into that folder if `autoDownload: true`
5. Present the folder path in the completion message

Skills that don't produce files (e.g. content-parser when only returning structured data inline)
may skip download behavior but should still respect the config lookup convention if they add
download support in the future.

## Implementation Scope

This design is to be applied skill by skill. Priority order:

1. **podcast** — primary driver of this design, most artifact types
2. **tts** — MP3 output, already has `user-config.json` (migrate to new schema)
3. **content-parser** — MD/JSON output
4. **image-gen** — PNG output

Each skill's `SKILL.md` update is a separate implementation task.
