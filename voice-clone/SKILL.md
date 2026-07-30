---
name: voice-clone
metadata:
  openclaw:
    emoji: "🗣️"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
description: |
  Clone a voice from reference audio into a reusable private ListenHub speaker,
  then use it for narration. Triggers on: "克隆我的声音", "克隆音色", "声音克隆",
  "语音克隆", "用我的声音", "自定义音色", "复刻声音", "clone my voice",
  "voice clone", "custom voice", "my own voice".
---

## When to Use

- User wants to clone a voice from a recording and **keep it** for later use
- User says "用我自己的声音朗读", "克隆我的声音", "clone my voice", "custom voice"
- User wants to manage voices they already cloned (list, rename, delete)
- User hit the voice limit and needs to free a slot

## When NOT to Use

- User wants a **one-off** reference-audio clone inside a single generation, with nothing
  stored — use `/listenhub-voice` with a `reference` voice instead
- User just wants an existing ListenHub voice to read text (use `/tts`)
- User wants a podcast, explainer video, music, or AI video (use those skills)

`/listenhub-voice` vs `/voice-clone`: `/listenhub-voice` clones a voice **for that one
request** from a public audio URL and stores nothing. `/voice-clone` creates a **persistent
private speaker** with its own speaker ID that works in `/tts`, `/podcast`, and every other
ListenHub surface — at the cost of a confirmation step, a plan quota, and a stored voice slot.

## Purpose

Turn 1–6 reference audio files into a reusable private voice:

1. **Create** — upload the reference audio; the task clones a temporary voice.
2. **Poll** — wait for cloning to finish and listen to the preview.
3. **Confirm** — name the voice and keep it. Only then does it become a permanent speaker.

Confirming is what costs: free within the plan's per-period quota, then 300 credits each,
and only when the user explicitly authorizes the charge. Unconfirmed tasks expire after
7 days.

## Hard Constraints

- Always check CLI auth following `shared/cli-authentication.md`
- Follow `shared/cli-patterns.md` for CLI execution, errors, and interaction patterns
- Always read config following `shared/config-pattern.md` before any interaction
- **Never confirm a voice without the user's explicit go-ahead** — confirming can spend
  300 credits. Show the preview first, then ask.
- **Never pass `--use-credits` unless the user said yes to spending credits** in this
  conversation. Without it the server refuses to charge, which is the safe default.
- **Never clone a voice the user does not have consent for.** If the recording is not the
  user's own voice, ask whether they have the speaker's permission before uploading, and
  stop if they do not.
- Never invent a speaker ID — read it back from `voice-clone speakers` after confirming
- Never expose provider names, internal task states, DAO, MongoDB, or credential details

<HARD-GATE>
Use the AskUserQuestion tool for every multiple-choice step — do NOT print options as plain text. Ask one question at a time. Wait for the user's answer before proceeding. Confirming a clone spends credits once the quota is used up, so never run `voice-clone confirm` (or pass `--auto-confirm`) before the user has explicitly said to keep the voice.

</HARD-GATE>

## Prerequisites

```bash
listenhub auth status --json
```

Handle install/login automatically per `shared/cli-authentication.md`. Voice cloning
requires a paid plan — a free account gets an upgrade error at the confirm step.

## Workflow

### Step 1 — Collect the reference audio

Ask for the audio file path(s) if the user did not provide one. Accept 1–6 local files
(`.mp3`, `.wav`, `.m4a`, `.flac`, `.ogg`, `.aac`); a single file is the common case.

Limits worth stating up front: single file ≤5MB, ≤20MB total. Clean speech with no
background music clones best.

### Step 2 — Confirm consent

If the recording is not the user's own voice, ask whether they have the speaker's
permission. Stop if they do not — cloning someone's voice without consent is not
something to work around.

### Step 3 — Pick the language

Ask which language the recording is in: `zh` or `en`.

### Step 4 — Create and wait

```bash
listenhub voice-clone create --file <path> --lang <zh|en> --json
```

Repeat `--file` for multiple files. The command polls until cloning finishes and returns
`demoAudioUrl`, a preview of the temporary voice. `--no-wait` returns the task ID
immediately; `listenhub voice-clone get <taskId> --json` checks it later.

If the task fails, report the reason plainly — usually the audio was too short, too long,
or had no clear speech — and offer to retry with a different recording.

### Step 5 — Preview, then ask before keeping it

Give the user the preview URL and ask whether to keep this voice. Do not confirm on your
own initiative.

If they want to keep it, ask for a name (max 50 chars) and gender (`male` / `female` /
`other`), then:

```bash
listenhub voice-clone confirm --task-id <taskId> --name "<name>" --gender <gender> --json
```

If the response says the quota is used up and 300 credits are needed, **ask the user
before spending them**. Only after an explicit yes:

```bash
listenhub voice-clone confirm --task-id <taskId> --name "<name>" --gender <gender> --use-credits --json
```

### Step 6 — Hand back the speaker ID

```bash
listenhub voice-clone speakers --json
```

Read the new voice's `speakerInnerId` from the list and tell the user they can now use it
anywhere a voice is expected, for example:

```bash
listenhub tts create --text "..." --speaker-id <speakerInnerId>
```

## Managing Cloned Voices

| Goal | Command |
|------|---------|
| List voices, quota, remaining confirmations | `listenhub voice-clone speakers --json` |
| Inspect one voice | `listenhub voice-clone speaker <speakerId> --json` |
| Rename / change gender | `listenhub voice-clone update <speakerId> --name "<name>" --gender <gender> --json` |
| Delete a voice (frees a slot) | `listenhub voice-clone delete <speakerId> --json` |

`speakers` returns `maxSpeakers` (how many voices the plan may keep at once) and
`remainingConfirmations` (how many more confirmations this period includes). When the user
is at `maxSpeakers`, ask which existing voice to delete before cloning another — deleting
frees a slot but does not refund confirmations already spent.

## Error Handling

| Symptom | What it means | What to do |
|---------|---------------|------------|
| Upgrade required | Voice cloning needs a paid plan | Tell the user; do not retry |
| Credits required | Quota used up, charge not authorized | Ask before re-running with `--use-credits` |
| Voice limit reached | Plan already holds `maxSpeakers` voices | Offer to list and delete one |
| Already confirmed | The task was confirmed before | Read the speaker ID from `voice-clone speakers` — nothing was charged twice |
| No speech detected / duration invalid | Reference audio unusable | Ask for a cleaner or longer recording |
| Busy / temporarily unavailable | Another confirmation is in flight, or a transient failure | Wait a few seconds and retry the same command |

## Notes

- The `openapi` command group offers the same flow for API-key users, plus Japanese and a
  one-shot `--auto-confirm` mode: `listenhub openapi voice-clone create --consent ...`.
  Prefer the logged-in commands above unless the user is explicitly working with an API key.
- Cloned voices are private to the account and appear alongside official voices when
  listing speakers.
