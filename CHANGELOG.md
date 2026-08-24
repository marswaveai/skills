# Changelog

## [Unreleased]

### Enhancement

**Changed:**
- `podcast/SKILL.md` + `tts/SKILL.md` — support a task-level generation speed via the CLI's `--speed` flag. Continuous `0.5`–`2.0` range with at most two decimals; common values are `0.5 / 0.75 / 1 / 1.25 / 1.5 / 2`. The skills never ask about speed: with no explicit user request they omit the flag and generation stays at `1` (original speed).
- `google-calendar-skill` `1.0.3` — calendar-specific proxy discovery: apply a device HTTP CONNECT proxy to the first `gws` login/API call; do not wait for timeout; mixed SOCKS `all_proxy` is cleared. See `google-calendar-skill/references/proxy.md`.
- `outlook-calendar-skill` `1.0.5` — refresh bundled `cola-outlook-calendar` binaries.
- `universal-email` `1.2.11` — Outlook / Microsoft 365 Graph mail connects through the bundled `cola-outlook-mail-auth` helper; never the Himalaya setup wizard. See `universal-email/references/outlook.md`.
- `universal-email` `1.2.12` — wrap Outlook helper `connect`/`doctor`/`token` with the device HTTP CONNECT proxy.
- `universal-email` `1.2.13` — IMAP/SMTP secrets (Gmail, QQ, iCloud, other) are entered on a local Cola page via `cola-credential-helper prompt`; never the Himalaya wizard or a terminal. Gmail app passwords require Google 2-Step Verification ([official](https://support.google.com/accounts/answer/185833)); “您的账号不支持您正在尝试的设置” is Google's app-passwords page, including Workspace accounts that cannot issue app passwords. Personal Gmail and Workspace Gmail use the same IMAP method.
- `universal-email` `1.2.14` — `cola-credential-helper prompt` prefers a system password dialog (macOS `display dialog`, Windows Forms); HTML is fallback only. After a successful keychain write it shows a “已保存” dialog, not the OAuth “连上了” page. Secrets are stored at service `com.marswave.cola.app-secrets` / account `universal-email/<key>`.
- `universal-email` `1.2.15` — system dialog is activated to the front and times out after 180s; cancel does not open HTML; empty input re-prompts; HTML fallback bypasses the device proxy for `127.0.0.1`. Keychain location is unchanged.
- `universal-email` `1.2.16` — user-facing secret collection copy: do not paste in chat; say the system window is about to appear, then they fill it and click 保存.
- `universal-email` `1.2.17` — lock spoken lines for Gmail, QQ, iCloud, Outlook, and secret collection: what to do now, which link, what to click, what not to paste.

## [1.4.0] - 2026-07-30

### New Skill

**Added:**
- `voice-clone/` — Persistent voice cloning: upload 1–6 reference audio files, poll until cloning finishes, preview, then confirm into a reusable private speaker whose ID works in `/tts`, `/podcast`, and every other ListenHub surface. Also covers listing, renaming, and deleting cloned voices with the plan's quota and voice-slot limits. Confirming is gated behind explicit user consent because it can spend 300 credits once the quota is used up; cloning someone else's voice is gated behind a consent check. Requires `listenhub-cli` with the `voice-clone` subcommand.

**Changed:**
- `listenhub/SKILL.md` + `listenhub-cli/SKILL.md` — added the `/voice-clone` route and the trigger words for it, plus a "Voice Cloning" option in the disambiguation picker.
- `README.md` + `README.zh.md` — listed the new skill.

## [1.3.0] - 2026-06-25

### Enhancement

**Added:**
- `video-gen/` — PixVerse as a third model family (`listenhub openapi video pixverse generate`). Nine atomic capabilities: text_to_video, image_to_video, transition, multi_transition, fusion, restyle, mimic, lip_sync, agent. Introduces **lip sync** (PixVerse-only, audio or TTS), mimic (locked 720p), the marketing agent (ad_master/promo_mix, 720p/1080p + 20/30/60), and fusion `@refName` prompt syntax.
- `video-gen/references/pixverse-api.md` — dedicated PixVerse reference (capability list, capability→flag mapping, per-capability parameter tables, constraints, output format).
- `video-gen/SKILL.md` — Step 3d lip-sync collection block, PixVerse command templates (generate + estimate), PixVerse option in the model picker, PixVerse examples, Lipsync row in the Model Comparison table.

**Changed:**
- `listenhub/SKILL.md` + `listenhub-cli/SKILL.md` — added `pixverse`, `口型`, `lipsync`, `对口型` trigger words routing to `/video-gen`.
- `video-gen/SKILL.md` — corrected SeeDance rate limit to 5 RPM (was stale at 2; aligned with HappyHorse via #243).

## [1.2.0] - 2026-05-20

### New Skill

**Added:**
- `video-gen/` — AI video generation via SeeDance (text-to-video, first/last frame animation, reference-guided generation with images/video/audio). Requires `listenhub-cli` with `video` subcommand (not yet in published 0.1.0 — skill gates gracefully at runtime).

**Changed:**
- `listenhub/SKILL.md` — Added video-gen route to router
- `listenhub-cli/SKILL.md` — Added video-gen route to router

## [1.1.0] - 2026-04-07

### New Skill

**Added:**
- `cola-avatar-pack/` — Generate Cola pixel-art avatar, profile card, 4 emoji GIFs (happy/sad/angry/thinking) and 3 meme stickers (confused/annoyed/cracked)

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
