# Changelog

## [1.0.0] - 2026-03-04

### Architecture Migration (Phase 1)

Decomposed the monolithic `listenhub` skill into individual, focused skills with shared infrastructure.

**Added:**
- `shared/` — Centralized API reference, authentication guide, and common patterns
- `podcast/` — Podcast generation skill (solo, dialogue, debate modes)
- `explainer/` — Explainer video skill (info and story styles)
- `speech/` — Text-to-speech skill (FlowSpeech + multi-speaker Speech)
- `image-gen/` — AI image generation skill (Labnana API)
- `content-parser/` — URL content extraction skill
- `CHANGELOG.md` — This file

**Removed:**
- `listenhub/scripts/` — All shell scripts (replaced by curl-from-docs pattern)
- `listenhub/VERSION` — No longer needed
- `listenhub/SKILL.md` — Replaced by individual skill files

**Changed:**
- API interaction model: from shell script execution to curl commands constructed from `shared/api-reference.md`
- Parameter collection: all enumerable params now use AskUserQuestion interactive prompts
- `listenhub/` now contains only `DEPRECATED.md` pointing to new skills
- Flattened directory structure: skills now live at repo root instead of under `skills/` subdirectory
- `README.md` and `README.zh.md` updated with new skill matrix and directory structure

**Issue:** [MARS-3517](https://linear.app/marswave/issue/MARS-3517)
