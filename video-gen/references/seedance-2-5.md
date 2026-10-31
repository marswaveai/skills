# Seedance 2.5 generation and Draft

Use `--model doubao-seedance-2-5` with `listenhub video` or `listenhub openapi video`. OAuth Labnana creation also accepts the same flags at `listenhub labnana video create`. Before using these commands, check `create --help` for `--draft-task-id`; if missing, update the CLI or report that the installed version cannot submit this request. Do not switch models silently.

## Limits and modes

| Rule | Seedance 2.0 Pro/Fast | Seedance 2.5 |
|---|---|---|
| Prompt | 1500 characters | 5000 characters, including asset reference text |
| Reference images | 9 | 30 |
| Reference videos | 3; each 2–15s; total ≤15s | 10; each 2–30s (edit: 4–30s); total ≤30s |
| Reference audios | 3; each 2–15s; total ≤15s; needs image/video | 10; each 2–30s; total ≤30s; audio-only allowed |
| Output duration | 4–15s | 4–30s or -1 (automatic); edit requires -1 |
| Resolution | Pro 480p/720p/1080p; Fast 480p/720p | 480p/720p/1080p; draft 480p; final 1080p |
| First frame / first-last | 1 / 2 images, fixed ratio | 1 / 2 images, `adaptive` |
| Task intent | Existing reference modes | `auto`, `reference`, `edit`, `extend` |

Frame mode cannot mix with reference-image/video/audio mode. Edit and extend require video input and `--ratio adaptive`; edit also requires `--duration -1`. Use the prompt to identify the editing target when there are multiple videos; do not assume the first video is the target. Task intent is submitted as `omniReferenceTaskType`, and an upstream mismatch is an error, not permission to reroute.

Videos: MP4/MOV, ≤200 MB per file; audio: WAV/MP3, ≤15 MB per file. Read every video's own width, height, duration, frame rate and byte size. Pass one `--reference-video-meta WIDTHxHEIGHT:DURATION:FPS:SIZE` per video in the same order. Pass audio `--reference-audio-meta DURATION:SIZE` in matching order. Use ffprobe for local metadata if available; otherwise collect known metadata. Never fabricate metadata. The server independently validates media geometry and ownership.

Use `--reference-image-meta WIDTHxHEIGHT[:SIZE]` for each remote image (local image dimensions are inferred). `--first-frame-meta` / `--last-frame-meta` apply to frame URLs. Do not truncate prompts or drop assets to pass limits. 5000 is the product cap; report an upstream rejection as a failure, not a successful generation.

## Multi-video and audio

```bash
listenhub video create \
  --model doubao-seedance-2-5 \
  --prompt 'Use the two video references and the reference music' \
  --omni-reference-task-type reference \
  --resolution 720p --ratio 16:9 --duration 10 \
  --reference-video /path/to/landscape.mp4 --reference-video-meta 1280x720:5:24:8000000 \
  --reference-video /path/to/portrait.mp4 --reference-video-meta 720x1280:7:30:9000000 \
  --reference-audio /path/to/music.wav --reference-audio-meta 5:800000 \
  --no-wait --json
```

Metadata above is illustrative; replace with the actual files' metadata. The input video duration is 12 seconds; its native dimensions are used for validation, not individual pixel billing. Estimate using the same model, output parameters and all metadata:

```bash
listenhub video estimate --model doubao-seedance-2-5 \
  --resolution 720p --ratio 16:9 --duration 10 \
  --reference-video-meta 1280x720:5:24:8000000 \
  --reference-video-meta 720x1280:7:30:9000000 \
  --reference-audio-meta 5:800000 --json
```

Pure audio: omit both video references, keep prompt + audio metadata and choose the requested output parameters. Multiple audio references use repeated `--reference-audio` and `--reference-audio-meta`. They use the no-input-video price tier; audio duration is not added to video tokens.

Edit example (video metadata must be real):

```bash
listenhub video create --model doubao-seedance-2-5 \
  --prompt 'Replace the background with a starry sky; preserve the subject motion' \
  --omni-reference-task-type edit --ratio adaptive --duration -1 --resolution 720p \
  --reference-video /path/to/input.mp4 --reference-video-meta 1280x720:5:24:8000000 \
  --no-wait --json
```

Extend uses `--omni-reference-task-type extend --ratio adaptive` and a supported requested output duration. First-frame generation uses `--first-frame ... --ratio adaptive`. Never send HappyHorse's `--audio-setting` on Seedance.

## Draft → final

A draft is a playable 480p generation. Final generation creates a new 1080p task referencing the **ListenHub task ID**, not a provider task ID. Both tasks charge independently. Show the two estimates separately and obtain the user's generation authorization using the parent skill's normal confirmation flow.

Create a draft with a stable request ID (a UUID is suitable):

```bash
listenhub video create --model doubao-seedance-2-5 \
  --prompt 'A paper boat floats through a luminous city' \
  --draft --resolution 480p --ratio 16:9 --duration 5 \
  --request-id 'draft-request-unique-id' --no-wait --json
```

Poll with `listenhub video get <draft-task-id> --json` until `success` or `failed`. Only successful, owned, same-application, unexpired drafts can be finalized. A current draft expires after 14 days; use the API's actual validation/error as authoritative. Do not create a final from a failed or still-running draft.

```bash
listenhub video estimate --model doubao-seedance-2-5 \
  --draft-task-id '<draft-task-id>' --json

listenhub video create --model doubao-seedance-2-5 \
  --draft-task-id '<draft-task-id>' \
  --request-id 'final-request-unique-id' --no-wait --json
```

Do not add prompt, assets, resolution, ratio, duration, seed, generate-audio, task intent or `--draft` to a final request. The API uses the draft's original inputs and channel. Reuse the exact request ID for a network retry; a deliberately new final generation needs a new ID and is charged separately. A final failure refunds only the final task. Retain and show the successful draft result.

Task detail/list exposes `draft`, `draftTaskId` and `finalTaskIds` for navigation between generated results. Present both IDs and their own status/credits; do not call this “billing inheritance”.

## Billing interpretation

Estimates use total original input-video seconds plus output seconds, multiplied by **output** width × height × fps / 1024, with upstream minimum token rules. Final settlements use actual `usage.completion_tokens`; adaptive/automatic-duration estimates are provisional. The 2.5 per-million-token RMB pricing baseline is 2.0 Pro's matching tier multiplied by the official 2.5/Pro unit-rate ratio. Final credits are rounded up after multiplying by 15 × 1.25. This coefficient does not establish a 25% profit margin.

The final's video-input tier comes from original draft inputs; never add the draft output as another input video or subtract the draft charge from the final price. Upstream rejection is handled by normal task failure/refund; do not retry a paid new request without checking the existing task or reusing its request ID.
