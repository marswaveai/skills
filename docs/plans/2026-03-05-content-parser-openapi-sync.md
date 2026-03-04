# Content-Parser OpenAPI Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update content-parser SKILL.md to remove stale cross-skill references after OpenAPI spec change.

**Architecture:** Two targeted edits to `content-parser/SKILL.md` — update one line and delete one section. No shared files touched. No tests needed (documentation-only change).

**Tech Stack:** Markdown

---

### Task 1: Update content-parser SKILL.md

**Files:**
- Modify: `content-parser/SKILL.md:19` (When NOT to Use)
- Modify: `content-parser/SKILL.md:98-101` (delete Composability section)

**Step 1: Update "When NOT to Use" line**

In `content-parser/SKILL.md`, change line 19 from:

```markdown
- User wants to generate content (use platform skills: `/podcast`, `/explainer`, `/speech`)
```

to:

```markdown
- User wants to generate audio/video content (not content extraction)
```

**Step 2: Delete "Composability" section**

Remove lines 98-101 entirely (the `## Composability` heading and its two bullet points):

```markdown
## Composability

- **Invokes**: content extract API (direct)
- **Invoked by**: all platform skills (podcast, explainer, speech) when URL preprocessing is needed; content-planner (Phase 3)
```

**Step 3: Verify the file**

Run: `cat -n content-parser/SKILL.md | head -25`
Expected: Line 19 reads `- User wants to generate audio/video content (not content extraction)`

Run: `grep -n "Composability" content-parser/SKILL.md`
Expected: No output (section deleted)

**Step 4: Commit**

```bash
git add content-parser/SKILL.md
git commit -m "refactor(content-parser): remove stale cross-skill references"
```
