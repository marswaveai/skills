# Design: API Reference Split + Slides Skill

Date: 2026-03-11

## Background

`shared/api-reference.md` is a 500-line monolithic file covering all ListenHub API endpoints. SKILL.md files reference sections by number (e.g., `§ 3. Explainer`, `§ 5. Speech`), but many of these sections don't exist yet — the file only has 4 sections while skills reference up to §6. The section numbers are inconsistent across skills.

Additionally, the storybook endpoint (`/v1/storybook/episodes`) exists in the OpenAPI controllers and supports a `slides` mode (PPT-style output), but is not documented in the public `openapi.yaml` and has no corresponding skill.

## Decisions

### 1. Split api-reference.md into per-skill files

Delete `shared/api-reference.md` and replace with one file per API domain:

| File | Content |
|------|---------|
| `shared/api-speakers.md` | `GET /speakers/list` |
| `shared/api-podcast.md` | `POST/GET /podcast/episodes` |
| `shared/api-speech.md` | `POST/GET /flow-speech/episodes` |
| `shared/api-storybook.md` | `POST/GET /storybook/episodes`, `POST /storybook/episodes/:id/video` |
| `shared/api-image.md` | Image generation endpoint |
| `shared/api-content-extract.md` | `POST/GET /content/extract` |

Each SKILL.md's Resources section updates from `shared/api-reference.md § X` to direct file references.

**Rationale:** Eliminates broken section references, each skill loads only what it needs, new skills only require a new file.

### 2. New `/slides` skill

Create `skills/slides/SKILL.md` using the storybook endpoint with `mode=slides`.

**Triggers:** `PPT`, `slides`, `presentation`, `slide deck`, `幻灯片`, `做个PPT`, `制作幻灯片`

**API:** `POST /v1/storybook/episodes` with `mode: slides`

**Constraints from the endpoint:**
- Max 1 source (text or URL)
- Max 1 speaker
- No editing support (no PATCH/PUT endpoints)

**Interaction flow:**
1. Collect input: topic text or URL (1 source)
2. Select language (en/zh)
3. Select 1 speaker (fetched from `/speakers/list`)
4. Confirm, then call create endpoint
5. Poll `GET /v1/storybook/episodes/:episodeId` until `processStatus=success`
6. Present result: pages array (text + imageUrl per page) + audioUrl
7. Ask if user wants to generate video → `POST /v1/storybook/episodes/:episodeId/video`

**References used by the skill:**
- `shared/api-speakers.md`
- `shared/api-storybook.md`
- `shared/authentication.md`
- `shared/common-patterns.md`

## Out of Scope

- Editing slides after generation (no API support)
- Adding storybook to the public `openapi.yaml` (separate concern)
- The `story` mode of the storybook endpoint (not surfaced in any skill)
