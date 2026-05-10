# Graph Report - /Users/fango/coding/marswave/skills  (2026-05-10)

## Corpus Check
- 1 files · ~35,934 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 52 nodes · 96 edges · 9 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]

## God Nodes (most connected - your core abstractions)
1. `fit_to_canvas()` - 12 edges
2. `remove_background()` - 9 edges
3. `generate_profile_card()` - 9 edges
4. `main()` - 8 edges
5. `process_image()` - 7 edges
6. `generate_meme_confused()` - 7 edges
7. `generate_meme_cracked()` - 7 edges
8. `_deform()` - 6 edges
9. `save_base_image()` - 6 edges
10. `generate_meme_annoyed()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `process_image()` --calls--> `remove_background()`  [EXTRACTED]
  /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py → /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py  _Bridges community 3 → community 2_
- `generate_meme_confused()` --calls--> `remove_background()`  [EXTRACTED]
  /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py → /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py  _Bridges community 3 → community 1_
- `generate_profile_card()` --calls--> `remove_background()`  [EXTRACTED]
  /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py → /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py  _Bridges community 3 → community 0_
- `generate_bounce_squash_frames()` --calls--> `fit_to_canvas()`  [EXTRACTED]
  /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py → /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py  _Bridges community 4 → community 7_
- `generate_shrink_sink_frames()` --calls--> `fit_to_canvas()`  [EXTRACTED]
  /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py → /Users/fango/coding/marswave/skills/cola-avatar-pack/scripts/process_avatar.py  _Bridges community 4 → community 8_

## Communities

### Community 0 - "Community 0"
Cohesion: 0.24
Nodes (12): add_watermark(), draw_diamond(), draw_rarity_diamonds(), draw_rounded_rect(), generate_profile_card(), load_font(), load_pixel_font(), Draw a pixel diamond (rotated square) centered at (cx, cy).      size: half-widt (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.22
Nodes (11): check_background(), generate_meme_annoyed(), generate_meme_confused(), generate_meme_cracked(), main(), Check if an image's background is acceptable for the avatar pipeline.      Decis, Save a meme sticker in both @2x and display sizes., Confused meme: AI-generated confused pose + single "?" symbol.      The characte (+3 more)

### Community 2 - "Community 2"
Cohesion: 0.25
Nodes (8): _find_unused_color(), process_image(), Find an RGB color not present in any frame, for use as transparent proxy., Convert RGBA frames to paletted GIF with transparency., Resize RGBA frames to a new size using NEAREST for pixel art., Process a single image: remove bg, generate animated GIF.      Outputs two files, _resize_frames(), _save_gif()

### Community 3 - "Community 3"
Cohesion: 0.33
Nodes (6): Try to remove background using rembg CLI. Returns RGBA image or None on failure., Save base image as transparent PNG in two sizes, plus the original.      Outputs, Remove background. Tries rembg first (best quality), falls back to flood-fill., remove_background(), save_base_image(), _try_rembg()

### Community 4 - "Community 4"
Cohesion: 0.5
Nodes (4): _clean_transparent_rgb(), fit_to_canvas(), Zero out RGB values where alpha is 0 to prevent color bleed during resize., Resize image to fit within canvas while maintaining aspect ratio, then center it

### Community 5 - "Community 5"
Cohesion: 0.5
Nodes (4): _deform(), generate_tilt_zoom_frames(), Scale canvas content by (sx, sy) around bottom-center or center anchor.      Ret, Thinking: subtle head tilt via asymmetric scale, slight zoom on upper half.

### Community 6 - "Community 6"
Cohesion: 1.0
Nodes (2): generate_swell_shake_frames(), Angry: swell up then shake violently with decay.      First frame puffs up (scal

### Community 7 - "Community 7"
Cohesion: 1.0
Nodes (2): generate_bounce_squash_frames(), Bounce with squash on landing and stretch at apex.      Cycle: rise → apex(stret

### Community 8 - "Community 8"
Cohesion: 1.0
Nodes (2): generate_shrink_sink_frames(), Sad: character shrinks slightly and sinks, then slowly returns.      Conveys def

## Knowledge Gaps
- **24 isolated node(s):** `Try to remove background using rembg CLI. Returns RGBA image or None on failure.`, `Remove background. Tries rembg first (best quality), falls back to flood-fill.`, `Zero out RGB values where alpha is 0 to prevent color bleed during resize.`, `Resize image to fit within canvas while maintaining aspect ratio, then center it`, `Scale canvas content by (sx, sy) around bottom-center or center anchor.      Ret` (+19 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 6`** (2 nodes): `generate_swell_shake_frames()`, `Angry: swell up then shake violently with decay.      First frame puffs up (scal`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 7`** (2 nodes): `generate_bounce_squash_frames()`, `Bounce with squash on landing and stretch at apex.      Cycle: rise → apex(stret`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 8`** (2 nodes): `generate_shrink_sink_frames()`, `Sad: character shrinks slightly and sinks, then slowly returns.      Conveys def`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `fit_to_canvas()` connect `Community 4` to `Community 0`, `Community 1`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **Why does `remove_background()` connect `Community 3` to `Community 0`, `Community 1`, `Community 2`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `generate_profile_card()` connect `Community 0` to `Community 1`, `Community 3`, `Community 4`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **What connects `Try to remove background using rembg CLI. Returns RGBA image or None on failure.`, `Remove background. Tries rembg first (best quality), falls back to flood-fill.`, `Zero out RGB values where alpha is 0 to prevent color bleed during resize.` to the rest of the system?**
  _24 weakly-connected nodes found - possible documentation gaps or missing edges._