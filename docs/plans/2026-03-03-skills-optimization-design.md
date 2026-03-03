# Skills Optimization Design

**Date**: 2026-03-03
**Status**: Approved
**Issue**: [MARS-3517](https://linear.app/marswave/issue/MARS-3517)

## Problem

The marswave/skills repo ships a single monolithic skill (ListenHub v0.6.0) bundling four distinct capabilities — podcast creation, explainer videos, TTS/speech, and image generation — into one large SKILL.md (500+ lines). This falls short of top-tier skill repos in trigger precision, progressive disclosure, composability, and developer experience.

The repo also lacks support for text-based content platforms (WeChat, Xiaohongshu, Douyin) that self-media creators rely on daily.

## Vision

**marswave/skills** — Content Creator Skills for AI Coding Assistants.

Platform-expert skill matrix for content creators. Each skill deeply understands one content platform or creation capability. Skills work independently and compose into cross-platform workflows through a dedicated orchestrator.

## Target Users

- **Knowledge creators** — tech, finance, science (WeChat articles, Zhihu, B站, podcasts)
- **Lifestyle creators** — food, travel, fashion (Xiaohongshu, Douyin, Instagram)
- **Professional creators** — deep reports, courses (Dedao, Ximalaya, YouTube)
- **Cross-platform creators** — one topic, multiple platforms

## Architecture

### Final Repository Structure

```
skills/
├── shared/               # Shared utilities
│   └── lib.sh           # API auth, HTTP helpers, input validation
├── podcast/              # Podcast generation (ListenHub API)
├── explainer/            # Explainer video creation (ListenHub API)
├── speech/               # TTS / voice narration (ListenHub API)
├── image-gen/            # AI image generation (ListenHub API)
├── wechat-article/       # WeChat article writing (AI + image-gen)
├── xiaohongshu/          # Xiaohongshu content (AI + image-gen)
├── douyin-script/        # Douyin short video scripts (AI + speech)
└── content-planner/      # Cross-platform orchestration
```

### Two-Layer Orchestration Model

**Layer 1: Platform-level Orchestration**
Each platform skill internally invokes base capabilities to deliver complete output.
- wechat-article calls image-gen for inline images
- xiaohongshu calls image-gen for cover and inline images
- douyin-script can call speech for sample audio

Users get complete deliverables from a single skill invocation.

**Layer 2: Cross-platform Orchestration**
content-planner coordinates multiple platform skills for multi-platform distribution.
- Routes source content to selected platforms
- Ensures content consistency across platforms
- Manages dependencies and execution order

### Trigger Design (Dual-track)

**Single platform -> direct skill trigger:**
- "Make a podcast" -> /podcast
- "Write a WeChat article" -> /wechat-article
- "Create Xiaohongshu note" -> /xiaohongshu

**Cross-platform -> content-planner:**
- "Make this into content for all platforms" -> /content-planner
- "WeChat + Xiaohongshu + podcast" -> /content-planner
- "Multi-platform distribution" -> /content-planner

## Skill Design Standard

### Core Principles

1. **Progressive Disclosure** — SKILL.md <500 lines, details in references/
2. **Trigger Precision** — "When to Use" + "When NOT to Use" in every SKILL.md
3. **Behavioral Guidance** — Teach decision-making, not facts Claude already knows
4. **Composability** — Explicit declaration of cross-skill invocation
5. **Independent Value** — Every skill works standalone
6. **Clean Naming** — Descriptive names (/podcast not /listenhub)

### Standard Skill Structure

```
skill-name/
├── SKILL.md                 # Core instructions (<500 lines)
├── references/              # Deep reference material (loaded on demand)
│   ├── platform-guide.md
│   ├── workflow-details.md
│   └── examples/
├── scripts/                 # Executable scripts (if needed)
└── hooks/                   # Claude Code hooks (optional)
```

No VERSION files. Version management through git tags and `npx skills check/update`.

### SKILL.md Template

```markdown
---
name: skill-name
description: |
  Brief trigger description (triggering conditions only, never workflow summary)
---

## When to Use
[Specific triggering scenarios]

## When NOT to Use
[Negative triggers to prevent over-activation]

## Purpose
[1-2 paragraphs: what this skill does and for whom]

## Modes
[If applicable: basic/complete modes]

## Hard Constraints
[Non-negotiable rules]

## Interaction Flow
[Step-by-step user journey]

## Composability
- Invokes: [skills this one calls]
- Invoked by: [skills that call this one]

## [Domain-specific sections]
```

## Phase 1: ListenHub Decomposition

### Shared Library Strategy

**Approach: Symlink**

```
skills/shared/lib.sh              # Single source of truth
podcast/scripts/lib.sh      -> ../../shared/lib.sh
explainer/scripts/lib.sh    -> ../../shared/lib.sh
speech/scripts/lib.sh       -> ../../shared/lib.sh
image-gen/scripts/lib.sh    -> ../../shared/lib.sh
```

**lib.sh cleanup:**
- Remove: check_version(), VERSION_FILE, REMOTE_VERSION_URL
- Keep: API key management, HTTP helpers, input validation

### Skill Decomposition

**podcast/**
- Scripts: create-podcast.sh, create-podcast-text.sh, create-podcast-audio.sh, get-speakers.sh, check-status.sh
- SKILL.md focus: podcast modes (quick/deep/debate), speaker selection, source materials, two-stage review flow
- References: mode-guide.md, speaker-selection.md

**explainer/**
- Scripts: create-explainer.sh, generate-video.sh, check-status.sh
- SKILL.md focus: single-narrator explainer videos with AI visuals
- References: video-guide.md

**speech/**
- Scripts: create-tts.sh, create-speech.sh, check-status.sh
- SKILL.md focus: TTS/FlowSpeech modes, direct vs smart, multi-speaker scripts
- References: tts-guide.md

**image-gen/**
- Scripts: generate-image.sh
- SKILL.md focus: AI image generation, resolution/aspect ratio, reference images
- References: prompt-guide.md, style-reference.md

### Migration

- Clean rename: /listenhub -> /podcast, /explainer, /speech, /image-gen
- No alias transition period
- Add DEPRECATED.md in old listenhub/ pointing to new skills
- Document migration in README and CHANGELOG

## Phase 2: Text Platform Skills

### Capability Model

Each text platform skill is a **full-stack platform expert** with 3 modes:

1. **Create from Scratch** — Generate original content for the platform from a topic or idea
2. **Adapt from Source** — Transform existing content (article, transcript, video script) into platform-native format
3. **Guidance** — Provide platform rules, best practices, and optimization advice

### Platform-level Orchestration

Text platform skills invoke base capabilities for complete deliverables:

```
wechat-article (Complete Mode):
  1. Generate article structure and content
  2. Identify 3-5 image insertion points
  3. Call image-gen for each image
  4. Assemble final article with embedded images
  (Text-only mode available when user requests)
```

### Skill Details

**wechat-article/**
- SKILL.md (~300 lines): 3 modes, platform-level orchestration with image-gen, WeChat-specific writing guidance
- References: platform-algorithm.md, writing-techniques.md, image-strategy.md
- Examples: tech article, lifestyle article, tutorial

**xiaohongshu/**
- SKILL.md (~300 lines): 3 modes, platform-level orchestration with image-gen, Xiaohongshu content philosophy
- References: platform-culture.md, title-formulas.md, tag-strategy.md, layout-guide.md
- Examples: product review, tutorial note, lifestyle sharing

**douyin-script/**
- SKILL.md (~250 lines): 3 modes, optional orchestration with speech for sample audio
- References: hook-techniques.md, script-structure.md, voice-direction.md
- Examples: knowledge sharing, product intro, storytelling

### Future API Integration

Current implementation: pure AI generation + ListenHub API for media (images, audio).

When ListenHub provides text generation APIs, platform skills will leverage:
- **Platform-specific optimization** — Content tuned for each platform's algorithm
- **Cross-platform consistency** — Same facts and arguments across all outputs
- **Multi-modal coordination** — Text, images, and audio generated in sync

The skill interface remains unchanged; only internal implementation evolves.

## Phase 3: Content Planner

### Three Operating Modes

**Mode 1: Auto-route**
Analyze content type and depth, recommend suitable platforms, ask user to confirm, then orchestrate.

**Mode 2: Explicit**
User specifies target platforms. Planner coordinates execution order, manages dependencies, ensures consistency.

**Mode 3: Transform**
From a "master content" (e.g., long article), extract core information, then adapt for each platform while maintaining factual consistency.

### Orchestration Rules

- **Content consistency**: Core facts, data, and arguments must be identical across platforms. Tone adapts to platform culture. Format and length vary by platform.
- **Dependency management**: Text platforms can run in parallel. Audio/video platforms can run in parallel. Images generated on-demand by each platform skill.
- **Error handling**: If one platform fails, continue with others. Report partial success. Allow retry of failed platforms.

### SKILL.md Structure

```markdown
## When to Use
- User requests content for 2+ platforms
- User says "全平台", "多平台", "cross-platform"
- User wants to transform one piece into multiple formats

## When NOT to Use
- Single platform request -> use platform-specific skill directly
- User just wants platform guidance -> use platform skill's guidance mode
```

## Quality Checklist

Every skill must satisfy:

- [ ] SKILL.md < 500 lines
- [ ] "When to Use" and "When NOT to Use" present
- [ ] Description focuses on trigger conditions, not workflow summary
- [ ] Detailed reference material in references/, not inline
- [ ] Behavioral guidance over reference dumps
- [ ] Composability declared (invokes / invoked by)
- [ ] At least 2-3 curated examples
- [ ] All functionality tested

## Technical Debt Cleanup

**Remove:**
- VERSION files (all skills)
- check_version() in lib.sh
- REMOTE_VERSION_URL constant
- Version-check curl calls

**Keep:**
- lib.sh core: API key management, HTTP helpers, input validation
- Semantic versioning via git tags
- User updates via `npx skills check` and `npx skills update`

## Roadmap Summary

| Phase | Scope | Key Deliverables |
|-------|-------|-----------------|
| Phase 1 | ListenHub decomposition | podcast, explainer, speech, image-gen as independent skills |
| Phase 2 | Text platform skills | wechat-article, xiaohongshu, douyin-script with platform-level orchestration |
| Phase 3 | Cross-platform orchestration | content-planner with auto-route, explicit, and transform modes |
