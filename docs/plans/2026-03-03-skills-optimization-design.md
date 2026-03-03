# Skills Optimization Design

**Date**: 2026-03-03
**Updated**: 2026-03-03
**Status**: Approved
**Issue**: [MARS-3517](https://linear.app/marswave/issue/MARS-3517)

## Problem

The marswave/skills repo ships a single monolithic skill (ListenHub v0.6.0) bundling four distinct capabilities — podcast creation, explainer videos, TTS/speech, and image generation — into one large SKILL.md (500+ lines). This falls short of top-tier skill repos in trigger precision, progressive disclosure, composability, and developer experience.

The current architecture wraps ListenHub's OpenAPI behind shell scripts, adding maintenance overhead and limiting the AI's ability to make intelligent API decisions. Skills should be knowledge packages, not code wrappers.

The repo also lacks support for content platforms (WeChat, Xiaohongshu, Douyin, Twitter, Instagram, YouTube), a content ingestion layer for parsing source material from URLs, and a style system for personalized content voice.

## Vision

**marswave/skills** — Content Creator Skills for AI Coding Assistants.

Platform-expert skill matrix for content creators. Each skill deeply understands one content platform or creation capability. Skills are pure knowledge — SKILL.md + API reference docs — with no shell scripts. The AI reads documentation and makes API calls directly. Skills work independently and compose into cross-platform workflows through a dedicated orchestrator.

## Target Users

- **Knowledge creators** — tech, finance, science (WeChat articles, Zhihu, B站, podcasts)
- **Lifestyle creators** — food, travel, fashion (Xiaohongshu, Douyin, Instagram)
- **Professional creators** — deep reports, courses (Dedao, Ximalaya, YouTube)
- **Cross-platform creators** — one topic, multiple platforms

## Architecture

### Docs-Only Skills (No Scripts)

Skills are pure knowledge packages. The AI reads API reference documentation and constructs API calls directly — no shell script wrappers.

**Rationale:** Shell scripts add maintenance burden, limit AI flexibility, and create an unnecessary abstraction layer over what is already a well-documented OpenAPI. The AI is better served by understanding the API directly and making intelligent decisions about which endpoints to call, how to handle errors, and when to retry.

**What this means:**
- No `scripts/` directories
- No `lib.sh` or shared shell utilities
- No VERSION files
- API reference docs replace all script functionality
- AI constructs curl/HTTP calls based on documentation

### Repository Structure

```
skills/
├── shared/                   # Shared API reference & utilities
│   ├── api-reference.md      # ListenHub OpenAPI reference (readable format)
│   ├── authentication.md     # API key setup: env var + Claude Code settings
│   └── common-patterns.md    # Polling, error handling, rate limits, retries
├── styles/                   # User style profiles
│   └── README.md             # How to create and use styles
├── content-parser/           # Content extraction from platform URLs
│   ├── SKILL.md
│   └── references/
├── podcast/                  # Podcast generation
│   ├── SKILL.md
│   └── references/
├── explainer/                # Explainer video creation
│   ├── SKILL.md
│   └── references/
├── speech/                   # TTS / voice narration
│   ├── SKILL.md
│   └── references/
├── image-gen/                # AI image generation
│   ├── SKILL.md
│   └── references/
├── wechat-article/           # WeChat article writing
│   ├── SKILL.md
│   └── references/
├── xiaohongshu/              # Xiaohongshu content
│   ├── SKILL.md
│   └── references/
├── douyin-script/            # Douyin short video scripts
│   ├── SKILL.md
│   └── references/
├── twitter/                  # Twitter/X content
│   ├── SKILL.md
│   └── references/
├── instagram/                # Instagram content
│   ├── SKILL.md
│   └── references/
├── youtube/                  # YouTube content
│   ├── SKILL.md
│   └── references/
└── content-planner/          # Cross-platform orchestration
    ├── SKILL.md
    └── references/
```

### Two-Layer Orchestration Model

**Layer 1: Platform-level Orchestration**
Each platform skill internally invokes base capabilities to deliver complete output.
- wechat-article invokes image-gen for inline images
- xiaohongshu invokes image-gen for cover and inline images
- douyin-script can invoke speech for sample audio
- instagram invokes image-gen for cover images and carousel slides
- youtube invokes image-gen for thumbnail concepts, optionally speech for voiceover
- twitter invokes image-gen for embedded images or infographics

Users get complete deliverables from a single skill invocation.

**Layer 2: Cross-platform Orchestration**
content-planner coordinates multiple platform skills for multi-platform distribution.
- Routes source content to selected platforms
- Ensures content consistency across platforms
- Manages dependencies and execution order
- Handles cross-cultural adaptation (not just format changes)

### Trigger Design (Dual-track)

**Single platform -> direct skill trigger:**
- "Make a podcast" -> /podcast
- "Write a WeChat article" -> /wechat-article
- "Create Xiaohongshu note" -> /xiaohongshu
- "Write a tweet thread" -> /twitter
- "Create Instagram post" -> /instagram
- "Write a YouTube script" -> /youtube
- "Parse this URL" -> /content-parser

**Cross-platform -> content-planner:**
- "Make this into content for all platforms" -> /content-planner
- "WeChat + Xiaohongshu + podcast" -> /content-planner
- "Multi-platform distribution" -> /content-planner

## Skill Design Standard

### Core Principles

1. **Docs-Only** — No shell scripts. API reference docs instead of code wrappers
2. **Progressive Disclosure** — SKILL.md <500 lines, details in references/
3. **Trigger Precision** — "When to Use" + "When NOT to Use" in every SKILL.md
4. **Behavioral Guidance** — Teach decision-making, not facts Claude already knows
5. **Composability** — Explicit declaration of cross-skill invocation
6. **Independent Value** — Every skill works standalone
7. **Clean Naming** — Descriptive names (/podcast not /listenhub)

### Standard Skill Structure

```
skill-name/
├── SKILL.md                 # Core instructions (<500 lines)
└── references/              # Deep reference material (loaded on demand)
    ├── api-endpoints.md     # Relevant API endpoints for this skill
    ├── platform-guide.md    # Platform-specific knowledge
    └── examples/            # Example content
```

No VERSION files. No scripts/ directories. No hooks/ directories.
Version management through git tags and `npx skills check/update`.

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

## API Reference
[Key endpoints this skill uses, or pointer to shared/api-reference.md]

## Composability
- Invokes: [skills this one calls]
- Invoked by: [skills that call this one]

## [Domain-specific sections]
```

## Shared API Layer

### shared/api-reference.md

Human-readable ListenHub API reference covering all endpoints: podcast creation, explainer videos, TTS/speech, image generation, content parsing. Structured so each skill's references/api-endpoints.md can point to relevant sections.

### shared/authentication.md

Documents both authentication approaches:
- **Environment variable**: `LISTENHUB_API_KEY` in `.zshrc`/`.bashrc` (current approach)
- **Claude Code settings**: Project or user-level configuration

The AI reads this reference and includes the API key in request headers. No script-level key management.

### shared/common-patterns.md

Reusable patterns the AI follows when making API calls:
- **Polling**: How to check job status for async operations (podcast generation, video rendering)
- **Error handling**: HTTP status codes, retry logic, rate limits
- **Input validation**: URL formats, content length limits, supported languages
- **Response parsing**: How to extract results from API responses

## Style System

### Purpose

Users define their personal content style (voice, tone, vocabulary) that all platform skills respect during generation. Styles are project-local, git-tracked, and portable.

### Storage

```
styles/
├── README.md                # How to create and use styles
├── tech-blogger.md          # Example: technical writing style
└── casual-creator.md        # Example: informal social media style
```

### Style Profile Format

```markdown
---
name: tech-blogger
description: Thoughtful technical writing with clear explanations
---

## Voice Description
Analytical but approachable. Uses concrete examples over abstract theory.
Short paragraphs. Questions to engage readers. Avoids jargon unless defining it.

## Examples

### Example 1: Opening paragraph
Source: [optional URL or "original"]
> The thing about distributed systems isn't that they're complex — it's that
> they fail in ways you didn't think to test for. Here's what happened when
> our message queue decided to forget 40,000 events.

### Example 2: Explaining a concept
> Think of rate limiting like a bouncer at a club. Doesn't matter who you
> are — when the room's full, you wait. The question is: what kind of
> bouncer do you want?

## Platform Adaptations
- Twitter: More punchy, use threads for depth, rhetorical questions as hooks
- WeChat: Longer paragraphs, more structured with headers, include code blocks
- YouTube: Conversational opening, signpost structure early
```

### How Skills Consume Styles

1. User specifies style when invoking a skill: "Write a tweet thread about X in my tech-blogger style"
2. Skill reads `styles/tech-blogger.md`
3. Style informs tone, structure, and vocabulary of generated content
4. Platform-specific adaptations in the style profile override defaults for that platform

### Style Creation

Users can create styles two ways (hybrid approach):
- **From examples**: Provide past content samples, system derives voice patterns
- **From description**: Describe style in natural language
- **Both**: Provide examples AND descriptions for a unified profile

No dedicated /style skill needed — style management is lightweight enough to handle inline.

## Content Parser Skill

### Purpose

Standalone infrastructure skill that extracts structured content from platform URLs via ListenHub API. Any skill can invoke it to get normalized source material.

### Structure

```
content-parser/
├── SKILL.md                    # ~200 lines
└── references/
    └── supported-platforms.md  # Platform-specific parsing notes
```

### API Contract

Input: any supported platform URL.

Output: normalized JSON structure:

```json
{
  "platform": "twitter",
  "type": "thread",
  "title": null,
  "author": "@username",
  "content": "...",
  "media": [],
  "metadata": {
    "published_at": "...",
    "engagement": {},
    "tags": []
  }
}
```

Content types by platform:
- **Twitter/X**: tweet, thread
- **Instagram**: post, reel, story
- **YouTube**: video (transcript + metadata)

### Composability

- **Invokes**: nothing (calls ListenHub API directly)
- **Invoked by**: all platform skills (in "Adapt from Source" mode), content-planner

### Trigger Design

```
When to Use:
- User provides a URL and wants to extract/analyze its content
- Another skill needs to parse source material from a platform

When NOT to Use:
- User already has the content as text (no URL to parse)
- User wants to generate content (use platform skills instead)
```

## Phase 1: Architecture Migration + Infrastructure

### Docs-Only Migration

Replace all shell scripts with API reference documentation:

**Remove:**
- All shell scripts (*.sh) in skills/listenhub/scripts/
- lib.sh and the symlink strategy
- VERSION files
- check_version(), REMOTE_VERSION_URL
- The entire scripts/ directory convention

**Create:**
- shared/api-reference.md — full ListenHub API reference
- shared/authentication.md — API key setup guide
- shared/common-patterns.md — polling, errors, retries

### Skill Decomposition

**podcast/**
- SKILL.md focus: podcast modes (quick/deep/debate), speaker selection, source materials, two-stage review flow
- References: api-endpoints.md, mode-guide.md, speaker-selection.md

**explainer/**
- SKILL.md focus: single-narrator explainer videos with AI visuals
- References: api-endpoints.md, video-guide.md

**speech/**
- SKILL.md focus: TTS/FlowSpeech modes, direct vs smart, multi-speaker scripts
- References: api-endpoints.md, tts-guide.md

**image-gen/**
- SKILL.md focus: AI image generation, resolution/aspect ratio, reference images
- References: api-endpoints.md, prompt-guide.md, style-reference.md

### Content Parser

Build the content-parser/ skill as described in the Content Parser section above.

### Style System

Set up the styles/ directory with README.md and example style profiles.

### Migration

- Clean rename: /listenhub -> /podcast, /explainer, /speech, /image-gen
- No alias transition period
- Add DEPRECATED.md in old listenhub/ pointing to new skills
- Document migration in README and CHANGELOG

## Phase 2: Platform Skills

### Capability Model

Each platform skill is a **full-stack platform expert** with 3 modes:

1. **Create from Scratch** — Generate original content for the platform from a topic or idea
2. **Adapt from Source** — Transform existing content (via content-parser or raw text) into platform-native format
3. **Guidance** — Provide platform rules, best practices, and optimization advice

All platform skills read from styles/ when user specifies a style profile.

### Platform-level Orchestration

Platform skills invoke base capabilities for complete deliverables:

```
wechat-article (Complete Mode):
  1. Generate article structure and content
  2. Identify 3-5 image insertion points
  3. Invoke image-gen for each image
  4. Assemble final article with embedded images
  (Text-only mode available when user requests)
```

### Chinese Platform Skills

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

### Global Platform Skills

**twitter/**
- SKILL.md (~300 lines): 3 modes, orchestration with image-gen for embedded images
- Content types: single tweets, threads (3-15 tweets), quote tweets, reply threads
- Platform expertise: character economics (280 chars), hook patterns, thread pacing, hashtag strategy, visual formatting
- References: platform-guide.md, thread-techniques.md
- Composability: invokes image-gen, content-parser; invoked by content-planner

**instagram/**
- SKILL.md (~300 lines): 3 modes, orchestration with image-gen for visuals
- Content types: post captions, carousel copy (slide-by-slide), reel scripts, story sequences
- Platform expertise: caption structure (hook/value/CTA), hashtag strategy, carousel storytelling, reel timing, image direction specs
- References: platform-guide.md, caption-techniques.md, carousel-guide.md
- Composability: invokes image-gen, content-parser; invoked by content-planner

**youtube/**
- SKILL.md (~350 lines): 3 modes, orchestration with image-gen + optional speech
- Content types: video scripts, titles + descriptions, thumbnail concepts, chapter markers
- Platform expertise: script structure (30s hook, retention valleys), title formulas, description SEO, thumbnail direction, chapter generation
- References: platform-guide.md, script-structure.md, seo-guide.md
- Composability: invokes image-gen, speech, content-parser; invoked by content-planner

### Future API Integration

Current implementation: pure AI generation + ListenHub API for media (images, audio, content parsing).

When ListenHub provides text generation APIs, platform skills will leverage:
- **Platform-specific optimization** — Content tuned for each platform's algorithm
- **Cross-platform consistency** — Same facts and arguments across all outputs
- **Multi-modal coordination** — Text, images, and audio generated in sync

The skill interface remains unchanged; only the API endpoints evolve.

## Phase 3: Content Planner

### Three Operating Modes

**Mode 1: Auto-route**
Analyze content type and depth, recommend suitable platforms, ask user to confirm, then orchestrate.

**Mode 2: Explicit**
User specifies target platforms. Planner coordinates execution order, manages dependencies, ensures consistency.

**Mode 3: Transform**
From a "master content" (e.g., long article), extract core information via content-parser, then adapt for each platform. Handles cross-cultural adaptation — a WeChat article becoming a Twitter thread requires cultural context shifts, not just truncation.

### Orchestration Rules

- **Content consistency**: Core facts, data, and arguments must be identical across platforms. Tone adapts to platform culture. Format and length vary by platform.
- **Style propagation**: If user specifies a style, content-planner passes it to all coordinated skills. Platform-specific adaptations in the style profile are respected.
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

- [ ] Pure docs-only (no shell scripts)
- [ ] SKILL.md < 500 lines
- [ ] "When to Use" and "When NOT to Use" present
- [ ] Description focuses on trigger conditions, not workflow summary
- [ ] Detailed reference material in references/, not inline
- [ ] API endpoints documented in references/api-endpoints.md
- [ ] Behavioral guidance over reference dumps
- [ ] Composability declared (invokes / invoked by)
- [ ] Style system integration documented
- [ ] At least 2-3 curated examples
- [ ] All functionality tested

## Roadmap Summary

| Phase | Scope | Key Deliverables |
|-------|-------|-----------------|
| Phase 1 | Architecture migration + infrastructure | Docs-only architecture; shared API reference; content-parser skill; style system; decompose ListenHub into podcast, explainer, speech, image-gen |
| Phase 2 | All platform skills | wechat-article, xiaohongshu, douyin-script, twitter, instagram, youtube with platform-level orchestration and style support |
| Phase 3 | Cross-platform orchestration | content-planner with auto-route, explicit, and transform modes covering all platforms |
