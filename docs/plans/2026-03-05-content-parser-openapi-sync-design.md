# Content-Parser OpenAPI Sync

Date: 2026-03-05
Scope: content-parser skill only (shared files untouched)

## Context

The OpenAPI spec was updated. Podcast and Flowspeech are the two main product lines. Explainer (Storybook), Speech (multi-speaker), and Image Generation endpoints were removed. Content-parser is not yet live, so its API endpoints remain at `http://localhost:3040/openapi/v1`.

## Changes

### 1. Update "When NOT to Use" (line 19)

Remove references to specific platform skills. Replace with generic wording.

**Before:** `User wants to generate content (use platform skills: /podcast, /explainer, /speech)`
**After:** `User wants to generate audio/video content (not content extraction)`

### 2. Delete "Composability" section (lines 98-101)

Remove the entire section:

```markdown
## Composability

- **Invokes**: content extract API (direct)
- **Invoked by**: all platform skills (podcast, explainer, speech) when URL preprocessing is needed; content-planner (Phase 3)
```

## What stays the same

- API endpoints (localhost:3040)
- Interaction flow, workflow, hard constraints
- Shared doc references (api-reference.md, authentication.md, common-patterns.md)
- Supported platforms reference
- Example section
