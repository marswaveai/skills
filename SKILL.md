---
name: listenhub
description: |
  Explain anything — turn ideas into podcasts, explainer videos, or voice narration.
  Use when the user wants to "make a podcast", "create an explainer video",
  "read this aloud", "generate an image", or share knowledge in audio/visual form.
  Supports: topic descriptions, YouTube links, article URLs, plain text, and image prompts.
version: 1.0.0
license: MIT
compatibility: Claude Code, Cursor, Copilot, OpenCode
---

<purpose>
**The Hook**: Paste content, get audio/video/image. That simple.

Four modes, one entry point:
- **Podcast** — Two-person dialogue, ideal for deep discussions
- **Explain** — Single narrator + AI visuals, ideal for product intros
- **TTS/Flow Speech** — Pure voice reading, ideal for articles
- **Image Generation** — AI image creation, ideal for creative visualization

Users don't need to remember APIs, modes, or parameters. Just say what you want.
</purpose>

<instructions>

## Design Philosophy

**Hide complexity, reveal magic.**

Users don't need to know: Episode IDs, API structure, polling mechanisms, credits, endpoint differences.
Users only need: Say idea → wait a moment → get the link.

## Environment

### ListenHub API Key

API key stored in `$LISTENHUB_API_KEY`. Check on first use:

```bash
source ~/.zshrc 2>/dev/null; [ -n "$LISTENHUB_API_KEY" ] && echo "ready" || echo "need_setup"
```

If setup needed, guide user:
1. Visit https://listenhub.ai/zh/settings/api-keys
2. Paste key (only the `lh_sk_...` part)
3. Auto-save to ~/.zshrc

### Labnana API Key (for Image Generation)

API key stored in `$LABNANA_API_KEY`, output path in `$LABNANA_OUTPUT_DIR`.

On first image generation, the script auto-guides configuration:
1. Visit https://labnana.com/api-keys (requires subscription)
2. Paste API key
3. Configure output path (default: ~/Downloads)
4. Auto-save to shell rc file

**Security**: Never expose full API keys in output.

## Mode Detection

Auto-detect mode from user input:

**→ Podcast (Two-person dialogue)**
- Keywords: "podcast", "chat about", "discuss", "debate", "dialogue"
- Use case: Topic exploration, opinion exchange, deep analysis
- Feature: Two voices, interactive feel

**→ Explain (Explainer video)**
- Keywords: "explain", "introduce", "video", "explainer", "tutorial"
- Use case: Product intro, concept explanation, tutorials
- Feature: Single narrator + AI-generated visuals, can export video

**→ TTS (Text-to-speech)**
- Keywords: "read aloud", "convert to speech", "tts", "voice"
- Use case: Article to audio, note review, document narration
- Feature: Fastest (1-2 min), pure audio

**→ Image Generation**
- Keywords: "generate image", "draw", "create picture", "visualize"
- Use case: Creative visualization, concept art, illustrations
- Feature: AI image generation via Labnana API, multiple resolutions and aspect ratios

**Default**: If unclear, ask user which format they prefer.

**Explicit override**: User can say "make it a podcast" / "I want explainer video" / "just voice" / "generate image" to override auto-detection.

## Interaction Flow

### Step 1: Receive input + detect mode

```
→ Got it! Preparing...
  Mode: Two-person podcast
  Topic: Latest developments in Manus AI
```

For URLs, identify type:
- `youtu.be/XXX` → convert to `https://www.youtube.com/watch?v=XXX`
- Other URLs → use directly

### Step 2: Submit generation

```
→ Generation submitted

  Estimated time:
  • Podcast: 2-3 minutes
  • Explain: 3-5 minutes
  • TTS: 1-2 minutes

  You can:
  • Wait and ask "done yet?"
  • Check listenhub.ai/zh/app/library
  • Do other things, ask later
```

Internally remember Episode ID for status queries.

### Step 3: Query status

When user says "done yet?" / "ready?" / "check status":

- **Success**: Show result + next options
- **Processing**: "Still generating, wait another minute?"
- **Failed**: "Generation failed, content might be unparseable. Try another?"

### Step 4: Show results

**Podcast result**:
```
✓ Podcast generated!

  "{title}"

  Listen: https://listenhub.ai/zh/app/library

  Duration: ~{duration} minutes

  Need to download? Just say so.
```

**Explain result**:
```
✓ Explainer video generated!

  "{title}"

  Watch: https://listenhub.ai/zh/app/explainer-video/slides/{episodeId}

  Duration: ~{duration} minutes

  Need to download audio? Just say so.
```

**Image result**:
```
✓ Image generated!

  ~/Downloads/labnana-{timestamp}.jpg
```

**Important**: Prioritize web experience. Only provide download URLs when user explicitly requests.

## Script Reference

All scripts located at `./scripts/`, curl-based (no extra dependencies).

### Podcast
```bash
./scripts/create-podcast.sh <type> "<content>" [mode]
# type: query (topic) | url (link)
# mode: quick (default) | deep | debate
```

### Explain
```bash
./scripts/create-explainer.sh "<topic>" [mode]
# mode: info (default) | story

# Generate video file (optional)
./scripts/generate-video.sh "<episode-id>"
```

### TTS
```bash
./scripts/create-tts.sh "<text>" [mode]
# mode: smart (default) | direct
```

### Image Generation
```bash
./scripts/generate-image.sh "<prompt>" [size] [ratio]
# size: 1K | 2K | 4K (default: 2K)
# ratio: 16:9 | 1:1 | 9:16 | 2:3 | 3:2 | 3:4 | 4:3 | 21:9 (default: 16:9)
```

### Check Status
```bash
./scripts/check-status.sh "<episode-id>" <type>
# type: podcast | explainer | tts
```

## AI Responsibilities

**ListenHub modes (passthrough)**:
- Podcast/Explain/TTS → pass user input directly
- Server has full AI capability to process content

**Labnana mode (enhance)**:
- Image Generation → client-side AI optimizes prompt
- Thin forwarding layer, needs client intelligence enhancement

## Prompt Optimization (Image Generation)

When generating images, optimize user prompts by adding:

**Style Enhancement**:
- "cyberpunk" → add "neon lights, futuristic, dystopian"
- "ink painting" → add "Chinese ink painting, traditional art style"
- "photorealistic" → add "highly detailed, 8K quality"

**Scene Details**:
- Time: at night / at sunset / in the morning
- Lighting: dramatic lighting / soft lighting / neon glow
- Weather: rainy / foggy / clear sky

**Composition Quality**:
- Composition: cinematic composition / wide-angle / close-up
- Quality: highly detailed / 8K quality / professional photography

**DO**:
- Understand user intent, add missing details
- Use English keywords (models trained on English)
- Add quality descriptors
- Keep user's core intent unchanged
- Show optimized prompt transparently

**DON'T**:
- Drastically change user's original meaning
- Add elements user explicitly doesn't want
- Over-stack complex terminology
- If user wants "simple", don't add "highly detailed"

</instructions>

<examples>

<example name="podcast-request">
<user>Make a podcast about the latest AI developments</user>
<response>
→ Got it! Preparing two-person podcast...
  Topic: Latest AI developments

→ Generation submitted, about 2-3 minutes

  You can:
  • Wait and ask "done yet?"
  • Check listenhub.ai/zh/app/library
</response>
</example>

<example name="explainer-request">
<user>Create an explainer video introducing Claude Code</user>
<response>
→ Got it! Preparing explainer video...
  Topic: Claude Code introduction

→ Generation submitted, explainer videos take 3-5 minutes

  Includes: Script + narration + AI visuals
</response>
</example>

<example name="tts-request">
<user>Convert this article to speech https://blog.example.com/article</user>
<response>
→ Got it! Parsing article...

→ TTS submitted, about 1-2 minutes

  Wait a moment, or ask "done yet?" to check
</response>
</example>

<example name="image-generation">
<user>Generate an image: cyberpunk city at night</user>
<response>
→ Generating image...

  Original: cyberpunk city at night

  Optimized prompt:
  "Cyberpunk city at night, neon lights reflecting on wet streets,
   towering skyscrapers with holographic ads, flying vehicles,
   cinematic composition, highly detailed, 8K quality"

  Resolution: 4K (16:9)

✓ Image generated!
  ~/Downloads/labnana-20260121-143145.jpg
</response>
</example>

<example name="status-check">
<user>Done yet?</user>
<response>
✓ Podcast generated!

  "AI Revolution: From GPT to AGI"

  Listen: https://listenhub.ai/zh/app/library

  Duration: ~8 minutes

  Need to download? Just say so.
</response>
</example>

</examples>
