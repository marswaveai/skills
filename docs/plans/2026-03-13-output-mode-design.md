# Output Mode Design

**Date**: 2026-03-13
**Skills affected**: tts, podcast, explainer, image-gen, content-parser

## Problem

All skills currently use an `autoDownload: true/false` config field to control whether generated artifacts are saved locally. This is a blunt instrument:

- New users get files saved to `.listenhub/` by default, but often just want to see the result immediately in the conversation
- Tools that support inline media (images, audio) can display artifacts directly — no download needed
- `autoDownload: false` has no clear alternative behavior (where does the result go?)
- content-parser saves text extractions to `.listenhub/content-parser/`, but text files belong in the working directory, not a media library

## Goals

1. Replace `autoDownload` with a clearer `outputMode` field across media-generating skills
2. Default to showing results inline in the conversation (URL for audio, Read tool for images)
3. Keep download-to-directory as an explicit opt-in
4. Fix content-parser to save to the current directory instead of `.listenhub/`

## Design

### 1. Config Field: `outputMode`

Replace `autoDownload: boolean` with `outputMode: "inline" | "download" | "both"` in tts, podcast, explainer, and image-gen.

**Default**: `"inline"`

**Migration**: When reading a config that has `autoDownload` but no `outputMode`:
- `autoDownload: true` → treat as `outputMode: "download"`
- `autoDownload: false` → treat as `outputMode: "inline"`
- Write migrated config back immediately

### 2. Output Behavior Per Mode

#### `inline` (new default)

| Skill / Output type | Behavior |
|---|---|
| TTS quick (sync stream) | Save to `/tmp/tts-{jobId}.mp3`, then Read tool (inline in supported clients; shows path in Claude Code terminal) |
| TTS script (has `audioUrl`) | Display `audioUrl` link in conversation, no download |
| Podcast (has `audioUrl`) | Display `audioUrl` link in conversation, no download |
| Explainer (has video/audio URLs) | Display video URL + audio URL in conversation, no download |
| image-gen (base64 response) | Save to `/tmp/image-gen-{jobId}.jpg`, then Read tool (displays inline in all clients) |

#### `download`

Save to `.listenhub/{skill}/YYYY-MM-DD-{jobId}/` directory. Show local file path. This is the previous `autoDownload: true` behavior.

#### `both`

Download to `.listenhub/` directory **and** execute inline display logic (Read tool or URL).

### 3. Setup Flow Question Change

Replace the "自动下载？" question in all four skills with:

```
Question: "输出方式？"
Options:
  - "对话中展示（推荐）" → outputMode: "inline"
  - "下载到本地目录"     → outputMode: "download"
  - "两者都要"           → outputMode: "both"
```

Config summary display changes from "自动下载：是/否" to "输出方式：inline / download / both".

### 4. content-parser Storage Path

content-parser is excluded from the `outputMode` system. Its artifacts are text files (`.md`, `.json`), not media — they belong in the working directory, not a media library.

**Change**: Save extracted content to the **current directory** instead of `.listenhub/content-parser/`.

Output files: `{taskId}-extracted.md` and `{taskId}-extracted.json` in the current working directory.

The `autoDownload` field is retained but its semantics narrow to "save files at all vs. show inline only in conversation".

## File Changes

| File | Change |
|---|---|
| `shared/output-mode.md` | **New** — defines the three modes, migration logic, per-skill behavior table |
| `tts/SKILL.md` | `autoDownload` → `outputMode`, Setup Flow, Step 6 branching |
| `podcast/SKILL.md` | Same as tts |
| `explainer/SKILL.md` | Same as tts |
| `image-gen/SKILL.md` | Same as tts |
| `content-parser/SKILL.md` | Storage path → current directory; `autoDownload` semantics update |

Total: 5 existing files + 1 new shared doc.

## Non-Goals

- No changes to the API calls themselves
- No changes to polling logic or error handling
- No changes to speaker selection or other config fields
- content-parser does not get `outputMode` (text files, different concern)
