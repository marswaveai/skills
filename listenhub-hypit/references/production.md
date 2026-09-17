# 从素材到成片

## 三种起点

- **参考视频**：用户给链接或授权 Agent 选择时，保存可使用的视频、作者、来源与许可。`npx hypit media probe`、`tile`/`frames` 看节奏、机位、角色、动作和画面布局，同时试听原声与 BGM。需要对白文字/时间时，经报价授权后用 `npx hypit transcribe reference.mp4 --language zh --to reference-transcript.json --runtime ./hypit.runtime.json`；需要歌词及时间时用 `/music recognize`。仅保留声音且不需要文字或字幕对齐时，不额外调用转写。
- **纯 brief**：先写逐段 Script 与分镜。旁白产品演示优先“图片 + TTS”，音乐按需加入，不为静态内容额外生成视频。用 [narration.svml](templates/narration.svml)、[narration.svrun](templates/narration.svrun) 和 [styles.svs](templates/styles.svs)。
- **用户素材**：probe 真实尺寸、时长、音轨、透明通道；能直接使用的素材列为复用，确认缺少哪些素材再报价。

Script 的 `||` 是字幕断句；Segment 是可独立重生成的一段表演/台词。口播、短剧、播客与街访按角色与表演段拆 Take；排行榜把揭示节点放 Script marker；主讲演示的屏幕录像与主讲人作为独立轨道。角色种类不限制制作流程：宠物说话同样写真实台词并按需对齐字幕，有对白与纯动作段可在同一 Timeline 中混排。用 hypit 的相应格式参考指导构图，不把这些结构封装成不可编辑的一条生成任务。

## 视频与声音

| 选择 | 生成参数与适用输入 |
|---|---|
| Seedance Pro / Fast，效果优先 | `doubao-seedance-2-pro` / `doubao-seedance-2-fast`，常用 720p；1080p 用 Pro。输出 4–15 秒；参考视频最多 3 段、每段 2–15 秒且合计≤15秒；参考图最多 9 张；参考音频最多 3 条、≤20MB，必须同时带图或视频 |
| MiniMax H3，性价比 | `MiniMax-H3`，显式 `768p` 或 `2k`（不接受720p）；输出4–15秒，参考图最多5张、参考视频/音频各最多3条；参考视频/音频单条2–15秒且合计≤15秒。参考音频可只配提示词。图/视频/音频同时输入前用当前 CLI/API 校验数量与时长上限 |

有台词的 Take 用角色/机位图 + 对应段参考音频，提示角色、动作、机位和逐字台词；同样适用于说话的宠物和动画角色。动作/跳舞段以参考视频迁移动作；唱歌段可用参考片抽出的音频、现有歌曲或新生成歌曲驱动。Seedance 可这样通过现有 `/video-gen` 的 OpenAPI 路由执行（先按同参数估价）：

```bash
listenhub openapi video create --model doubao-seedance-2-pro --resolution 720p \
  --ratio 9:16 --duration 5 --prompt '保持角色外观，跟随参考动作' \
  --reference-image ./assets/character.png --reference-video ./assets/reference.mp4 --input-video-duration 5 --json
```

音频参考加 `--reference-audio`；H3 换模型并显式指定 `--resolution 768p`。先读 `listenhub openapi video create --help` 确认安装版本参数；CLI 支持本地上传时传本地路径，URL 模式只用自有上传地址。参考视频先 probe 实际时长，`--input-video-duration` 与引用片段一致（上例5秒）。图片较慢时优先走现有 ListenHub `POST /v1/images/generation/async` 并轮询 `GET /v1/images/generation/tasks/:taskId`，成功后下载 `images[].url`；参数与同步生成一致，Provider 抠图默认采用此路径。CLI 同步图接口可能遇到网关超时，单纯延长客户端超时不能保证拿到结果；SDK 禁止自动重试。超时先查既有任务/实扣，不能自动重新生成。若旧版 CLI 把上传返回的 `fileUrl` 强改为 `storage.googleapis.com`，参考素材会失效：走同一 ListenHub OpenAPI 的 `POST /v1/files` 获取签名上传地址，PUT 文件后保留原样 `fileUrl` 再传给视频命令，并按实际 probe 结果传 metadata。禁止自行改文件域名或漏掉存储桶路径。所有结果下载到项目 `assets/`，记录来源任务 ID、prompt、模型和积分。长输入先裁剪，不发送超限素材：

```bash
npx hypit media cut reference.mp4 --start 0 --end 5 --to assets/reference.mp4
ffmpeg -i reference.mp4 -ss 0 -t 5 -map 0:a:0 -vn -c:a pcm_s16le assets/reference-audio-5s.wav
```

### 选用原声还是生成声音

| 用户意图 | 处理与费用 |
|---|---|
| 原画面、原声一起保留 | Normalize 保留视频音轨，Sound Track 混入成片；本地复用，0 生成费 |
| 换画面，声音保持原样 | 用上面的 ffmpeg 命令抽取选定时间段音轨，或 hypit `media:ExtractAudio`；以 Audio Track 对齐新画面；不需要 TTS 或克隆，0 生成费 |
| 只要原 BGM / 只要原人声 | 原片已有独立音轨时直接选轨；混合音轨用 `/music stem` 分轨，单列费用。试听对白残留、音质损伤，不能承诺任意对白/环境声都能无损拆开 |
| 用原声音指导新的表演、唱歌或节奏 | 抽取并裁剪参考音频，作为 Seedance/H3 的 `--reference-audio`；支付新视频生成费用。参考输入不等于原声透传，检查生成音轨的台词、节奏与音色 |
| 改台词，保留近似音色 | 一次性 `/listenhub-voice` 参考克隆；需要长期复用才用 `/voice-clone` 保存 speaker 后 `/tts`。分别报价，不能为保留原音默认建克隆 |
| 需要新配乐 | 才调用 `/music` 生成原创 BGM，单列费用；也可以不配乐，不要求用户先交歌曲 |

抽轨保留的是所选音轨里的全部声音，不会自动去掉对白。只用抽出的原音配新画面时，将生成视频 Normalize 的 `audio` 设为 `none`，Film 只加入选定的音频轨，避免旧对白残留或同一音轨叠加两次。按相同起止点裁剪画面与音频并检查同步；新画面时长不同需显式剪辑，不能默认循环对白。歌曲分轨用 `/music stem`，需要歌词时间才用 `recognize`，均单独列报价。保存音频来源、选定时间段和用途；本机抽轨复用无需新的生成任务。

需要新增配音时的三条路：内置音色 `/tts`；持久克隆 `/voice-clone`（保存 `speakerInnerId`，后续不重建、不再提示克隆）；一次性参考克隆 `/listenhub-voice`。保存声音选择到项目记录，与镜头素材独立。TTS 台词必须与 Script spoken text 一致，否则逐词对齐会失败。

带台词及字幕的视频用 [dialogue.svml](templates/dialogue.svml) 和 [dialogue.svrun](templates/dialogue.svrun)：把示例台词改成视频的实际台词，适用于人物、宠物或其他角色。纯动作或仅保留音轨、不需要文字对齐的段用 [action.svml](templates/action.svml) 和 [action.svrun](templates/action.svrun) 的空 `<action/>` Segment，不编造台词、不触发转写；模板保留视频原声，不强制另加音乐。多角度照片作身份参考，动作视频作运动参考，音频作声音/演唱参考。只生成用户要的版本；两档模型对比须纳入明确的成片数量与报价，观看形象一致性、动作还原、嘴型和成本，没有真实对比证据时不给优劣定论。

## 素材接入与本地渲染

`<asset:Image id="poster" src="./assets/poster.png"/>` 的引用是 `{poster}`（没有 `.image`）；生成节点如 `cutout` 才输出 `{cutout.image}`。视频/声音先显式 Normalize，视频选 `video="primary-moving"`，旁白用 `video="none" audio="default" span-authority="audio"`。独立 BGM 用 Audio Track，Film 中显式包含 `.audio`。字体与图片 Extent 必须对应实际素材。

```bash
npx hypit check narration.svrun --json
npx hypit plan narration.svrun --runtime ./hypit.runtime.json --json
npx hypit pricing narration.svrun --runtime ./hypit.runtime.json --json
npx hypit build narration.svrun --runtime ./hypit.runtime.json --follow
```

`check/plan` 不生成素材。确认 plan 没有 HypiHub 或未知的生成 endpoint；图像/音频生成在前置 ListenHub 步骤完成。不需要对白/歌词文字对齐的段应无转写能力请求；需要字幕时检查实际声音与字幕同步。按 build 的输出路径展示成片，保留 `.hypit/results` 与 Run，后续才能精确复用。

## 静态与动态悬浮主讲人

静态先用 [cutout.svml](templates/cutout.svml) 与对应 Run 生成透明图。`npx hypit pricing cutout.svrun` 计入一张 Seedream 图，得到 PNG 后在白/黑/洋红背景人工看发丝、衣缘与绿边。probe PNG 真实尺寸，以 Media Track 的 `image + extent` 叠在 B-roll 上；不把原输入图尺寸当输出尺寸。

动态 Take 在 `/video-gen` 提示里要求纯 `#00FF00` 背景、无背景阴影、无绿色衣物、保留人物细节。使用 ffmpeg chromakey 合成，不经静态抠图 Provider：

```bash
ffmpeg -i screen-recording.mp4 -i green-take.mp4 \
  -filter_complex '[1:v]chromakey=0x00FF00:0.08:0.03,despill=type=green:mix=0.35:green=-0.5,scale=320:-1[person];[0:v][person]overlay=W-w-24:H-h-24:shortest=1[out]' \
  -map '[out]' -map '1:a?' -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac assets/presenter-composite.mp4
```

上述数值只是起点。先采样真实背景色；提示词写纯绿不代表输出一定是纯绿，背景有明暗时也不能只提高容差。看全段动作、头发和手指边缘，检查白衣是否穿孔；屏幕与人物需同一计划时长。把合成结果重新 Normalize 加入 hypit。2026-09-17 的实测中，实际背景约 `#258A5A`，容差0.08保留白衣，0.10已出现穿孔；最终仍有少量灰绿发丝边与散发损失。绿色溢色或快速运动边缘不足时明确展示缺陷，记录是否需要另评视频 matting，不静默引入外部付费服务。

## 只改一句台词

保留 Script 与 Segment 的 `id`；每个 Segment 的 Take/配音和 SemanticTake 各有稳定输出名。修改该段 Script 与该段音频/视频文件，只报价这一段生成及一次新转写；保留其他段素材。新 `.svrun` 为每个未变 Segment 显式复用 prior Build 的 semantic 输出，字幕和 Timeline 重新计算：

```xml
<build-record id="kept-opening" build="PRIOR_BUILD_ID" output="opening.take"/>
<satisfy output="opening.take" candidate="kept-opening"/>
```

`PRIOR_BUILD_ID` 取实际成功 Build，`output` 取 `npx hypit inspect <build-id>` 列出的准确公开名。只复用未变 Script 段的 SemanticTake，改过文本的段须重新对齐；复用过旧语义会造成字幕错位。还可用普通文件覆盖输出：

```xml
<file id="approved-poster" type="@hypit/artifact@1#BlobArtifact" from="./assets/poster.png" media-type="image/png"/>
<satisfy output="poster" candidate="approved-poster"/>
```

重复执行同一 Run 不会自动选择上次结果。新 plan 确认未变段没有新增转写/生成请求，费用记录核对仅变化段。修改后的字幕以 Script 为准自动重排；不得拿旧 SRT 冒充新对齐。
