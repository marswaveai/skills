# Design: Speaker Selection UX — Pagination & Environment Fallback

**Date**: 2026-03-12
**Scope**: Global — applies to all skills that use speaker selection (podcast, tts)
**Status**: Approved

## Background

The current `speaker-selection.md` instructs skills to present speakers via `AskUserQuestion`.
Since `AskUserQuestion` is capped at 4 options, skills silently truncate the speaker list, leaving
users unaware of other available voices.

Additionally, skills run in multiple environments (Claude Code / Cursor IDE, Slack, WeChat IM)
with varying UI capabilities. The design must degrade gracefully without requiring environment
detection or config flags.

## Goals

- Users can access all available speakers, not just the first few
- Works well in Claude Code / Cursor (interactive picker)
- Degrades gracefully in IM environments (text list + free-text input)
- Selected speaker is remembered in config for future sessions

## Design

### Step 1 — Fetch & Display Full Text List

After fetching speakers, **always** output a formatted markdown table before calling
`AskUserQuestion`. This ensures IM users see the complete list regardless of picker support.

```
可用音色（共 N 个）：

| # | 名称        | 性别 | ID                  |
|---|-------------|------|---------------------|
| 1 | Yuanye      | 男   | cozy-man-english    |
| 2 | Travel Girl | 女   | travel-girl-english |
| 3 | Alex        | 男   | alex-en             |
| …                                            |

也可以直接输入音色名称或 ID
```

### Step 2 — AskUserQuestion with Pagination

Immediately after the text list, call `AskUserQuestion` with paginated options:

- **Page size**: 3 speakers per page
- **4th option**: navigation control
  - Any page except last: `下一页 → ({current}/{total_pages})`
  - Last page: `← 上一页`
- **`Other`** (built-in): always available for free-text input

Example — page 1 of 3:
```
Question: "选择音色"
Options:
  - "Yuanye"      — 男, English
  - "Travel Girl" — 女, English
  - "Alex"        — 男, English
  - "下一页 → (1/3)"
```

Example — last page:
```
Question: "选择音色"
Options:
  - "Brian"  — 男, English
  - "Sophie" — 女, English
  - "← 上一页"
```

Navigation options (`下一页 →`, `← 上一页`) trigger the next/previous `AskUserQuestion` call.
The page state is tracked within the skill's interaction loop.

### Step 3 — Input Matching

| Input source | Matching rule |
|---|---|
| AskUserQuestion option selected | Use `speakerId` directly |
| Free text — exact `speakerId` | Exact match |
| Free text — name | Case-insensitive substring match on `name` |
| Free text — no match | Reply "未找到「{input}」，请重新输入" and re-prompt |

If multiple speakers match the name substring, present the matches as a new `AskUserQuestion`.

### Step 4 — Persist to Config

After confirmation, write the selected `speakerId` to
`.listenhub/{skill}/config.json` under `defaultSpeakers.{language}`.

On subsequent runs with the same language, skip the speaker selection step and show the saved
choice in the confirmation summary. The user can still change it from the summary screen.

```json
"defaultSpeakers": {
  "zh": ["speaker-zh-id"],
  "en": ["cozy-man-english"]
}
```

For 2-speaker mode, the array holds two IDs. If only one is saved, ask for the second speaker.

## Environment Behavior Summary

| Environment | Picker rendered | User action |
|---|---|---|
| Claude Code / Cursor | Yes — interactive arrow-key picker | Select from paginated list |
| IM (Slack, WeChat) | No — text only | Read table, reply with name or ID via `Other` |
| Any | — | Always has free-text fallback via `Other` |

No config flag or environment detection required. The text table provides the fallback naturally.

## Files to Update

| File | Change |
|---|---|
| `shared/speaker-selection.md` | Rewrite "Presenting Options" section with pagination and fallback pattern |
| `podcast/SKILL.md` | Update Step 5 to reference new selection flow |
| `tts/SKILL.md` | Same — update voice selection step |

## Relation to Artifact Storage Design

This design is implemented alongside the `.listenhub` artifact storage design
(`2026-03-12-listenhub-artifact-storage-design.md`). The `defaultSpeakers` field written here
lives inside the same `config.json` defined in that design.
