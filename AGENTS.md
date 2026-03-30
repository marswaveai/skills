# ListenHub Skills

AI-powered audio content generation skills: podcast, TTS, image generation, content parsing, and more.

## Project Structure

- `shared/` — Shared docs (API references, auth, interaction patterns)
- `<skill>/SKILL.md` — Execution instructions for each skill
- `<skill>/references/` — Supplementary reference materials

## API Documentation: Single Source of Truth

The live documentation at **listenhub.ai** is the single source of truth for all API specifications. Each `shared/api-*.md` file references its authoritative URL at the top — API details (endpoints, parameters, request/response schemas) must stay strictly consistent with that page. Format differences are fine (skills only need curl, not JS/Python), but the API contract itself must match.

When inconsistencies are found, fix the skills side to match the live docs.
