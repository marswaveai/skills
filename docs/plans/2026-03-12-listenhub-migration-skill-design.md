# ListenHub Migration Skill Design

**Date**: 2026-03-12
**Branch**: feat/skills-optimization-design

## Problem

The monolithic `listenhub` skill (v0.6.0) has been decomposed into five individual skills. Existing users who run `npx skills update` will not receive a migration prompt because:

1. The new skills have different names (`tts`, `podcast`, etc.)
2. The `listenhub/` directory no longer has a `SKILL.md`, so `npx skills` cannot discover it
3. Users' installed `listenhub` skill will silently fail or do nothing

## Solution

Add a `listenhub/SKILL.md` that makes the AI actively notify users to upgrade when they trigger any ListenHub-related intent.

## Design

### `listenhub/SKILL.md`

```markdown
---
name: listenhub
description: |
  DEPRECATED — replaced by individual skills. Use when the user triggers any
  ListenHub action: "make a podcast", "explainer video", "read aloud", "TTS",
  "generate image", "解说视频", "播客", "朗读", "生成图片".
---

## ⚠️ This skill has been replaced

The `listenhub` skill has been split into focused individual skills.

**Tell the user:**

> This skill is outdated. Please upgrade with:
>
> ```bash
> npx skills add marswaveai/skills
> ```
>
> Then restart your agent.

After upgrading, the new skills work the same way — just say what you want:

| What you wanted | New skill |
|----------------|-----------|
| Make a podcast | `/podcast` |
| Explainer video | `/explainer` |
| Read aloud / TTS | `/tts` |
| Generate image | `/image-gen` |
| Extract URL content | `/content-parser` |

**Do not attempt the original task until the user has upgraded.**
```

### Key decisions

- **Description preserves old trigger words** — ensures the skill activates for any ListenHub-related user intent, even after upgrade prompt is shown
- **"Do not attempt" instruction** — prevents the AI from falling back to old shell-script logic, which would fail against the new API
- **Migration command is explicit** — users get a copy-pasteable command, not just vague guidance

## Scope

One file: `listenhub/SKILL.md`. No other changes required.
