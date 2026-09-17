# 从素材到成片

## 三种起点

- **参考视频**：用户给链接或授权 Agent 选择时，保存可使用的视频、作者、来源与许可。`npx hypit media probe`、`tile`/`frames` 看节奏、机位、角色、动作和画面布局。口播参考经报价授权后用 `npx hypit transcribe reference.mp4 --language zh --to reference-transcript.json --runtime ./hypit.runtime.json`；有参考歌声的无口播片不为字幕调用转写。
- **纯 brief**：先写逐段 Script 与分镜。旁白产品演示优先“图片 + TTS + 音乐”，不为静态内容额外生成视频。用 [narration.svml](templates/narration.svml)、[narration.svrun](templates/narration.svrun) 和 [styles.svs](templates/styles.svs)。
- **用户素材**：probe 真实尺寸、时长、音轨、透明通道；能直接使用的素材列为复用，确认缺少哪些素材再报价。

Script 的 `||` 是字幕断句；Segment 是可独立重生成的一段表演/台词。口播、短剧、播客与街访按角色与表演段拆 Take；排行榜把揭示节点放 Script marker；主讲演示的屏幕录像与主讲人作为独立轨道。用 hypit 的相应格式参考指导构图，不把这些结构封装成不可编辑的一条生成任务。

## 视频与声音

| 选择 | 生成参数与适用输入 |
|---|---|
| Seedance Pro / Fast，效果优先 | `doubao-seedance-2-pro` / `doubao-seedance-2-fast`，常用 720p；1080p 用 Pro。输出 4–15 秒；参考视频最多 3 段、每段 2–60 秒；参考图最多 9 张；参考音频 ≤20MB，必须同时带图或视频 |
| MiniMax H3，性价比 | `MiniMax-H3`，显式 `768p` 或 `2k`（不接受720p）；输出4–15秒，参考图最多5张、参考视频/音频各最多3条；参考视频/音频单条2–15秒且合计≤15秒。参考音频可只配提示词。图/视频/音频同时输入前用当前 CLI/API 校验数量与时长上限 |

口播 Take 用机位图 + 对应段参考音频，提示角色、动作、机位和逐字台词。动作/跳舞段以参考视频迁移动作；唱歌段以用户给的本地音频驱动。Seedance 可这样通过现有 `/video-gen` 的 OpenAPI 路由执行（先按同参数估价）：

```bash
listenhub openapi video create --model doubao-seedance-2-pro --resolution 720p \
  --ratio 9:16 --duration 5 --prompt '保持角色外观，跟随参考动作' \
  --reference-image ./assets/character.png --reference-video ./assets/reference.mp4 --json
```

音频参考加 `--reference-audio`；H3 换模型并显式指定 `--resolution 768p`。先读 `listenhub openapi video create --help` 确认安装版本参数；CLI 支持本地上传时传本地路径，URL 模式只用自有上传地址。同步图片生成应使用至少300秒请求超时（Provider 默认600秒），SDK 设置 `maxRetries:0`。客户端超时可能仍在后台完成并扣费，先查既有任务/实扣，不能自动重新生成。所有结果下载到项目 `assets/`，记录来源任务 ID、prompt、模型和积分。长输入先裁剪，不发送超限素材：

```bash
npx hypit media cut reference.mp4 --start 0 --end 5 --to assets/reference.mp4
ffmpeg -i user-song.wav -ss 0 -t 5 -c:a pcm_s16le assets/song-5s.wav
```

歌曲分轨用 `/music` 的 `stem`，歌词时间用 `recognize`，均单独列报价。不要从参考视频网站抽取歌曲。无用户歌曲时生成原创 BGM，不声称它是用户自带音频场景验收。

声音来源三档：内置音色 `/tts`；持久克隆 `/voice-clone`（保存 `speakerInnerId`，后续不重建、不再提示克隆）；一次性参考克隆 `/listenhub-voice`。保存声音选择到项目记录，与镜头素材独立。TTS 台词必须与 Script spoken text 一致，否则逐词对齐会失败。

宠物 meme 用 [meme.svml](templates/meme.svml) 的空 `<dance/>` Segment；不写虚假台词、不触发 WhisperX。宠物多角度照片作身份参考，动作视频作运动参考，歌曲作演唱参考。分别用两档视频模型时独立报价，观看形象一致性、动作还原、嘴型和成本；没有真实对比证据时不给优劣定论。

## 素材接入与本地渲染

`<asset:Image id="poster" src="./assets/poster.png"/>` 的引用是 `{poster}`（没有 `.image`）；生成节点如 `cutout` 才输出 `{cutout.image}`。视频/声音先显式 Normalize，视频选 `video="primary-moving"`，旁白用 `video="none" audio="default" span-authority="audio"`。独立 BGM 用 Audio Track，Film 中显式包含 `.audio`。字体与图片 Extent 必须对应实际素材。

```bash
npx hypit check narration.svrun --json
npx hypit plan narration.svrun --runtime ./hypit.runtime.json --json
npx hypit pricing narration.svrun --runtime ./hypit.runtime.json --json
npx hypit build narration.svrun --runtime ./hypit.runtime.json --follow
```

`check/plan` 不生成素材。确认 plan 没有 HypiHub 或未知的生成 endpoint；图像/音频生成在前置 ListenHub 步骤完成。声音存在时可检查字幕渲染和对齐；没有口播的 meme plan 应无转写能力请求。按 build 的输出路径展示成片，保留 `.hypit/results` 与 Run，后续才能精确复用。

## 静态与动态悬浮主讲人

静态先用 [cutout.svml](templates/cutout.svml) 与对应 Run 生成透明图。`npx hypit pricing cutout.svrun` 计入一张 Seedream 图，得到 PNG 后在白/黑/洋红背景人工看发丝、衣缘与绿边。probe PNG 真实尺寸，以 Media Track 的 `image + extent` 叠在 B-roll 上；不把原输入图尺寸当输出尺寸。

动态 Take 在 `/video-gen` 提示里要求纯 `#00FF00` 背景、无背景阴影、无绿色衣物、保留人物细节。使用 ffmpeg chromakey 合成，不经静态抠图 Provider：

```bash
ffmpeg -i screen-recording.mp4 -i green-take.mp4 \
  -filter_complex '[1:v]chromakey=0x00FF00:0.18:0.10,despill=type=green,scale=320:-1[person];[0:v][person]overlay=W-w-24:H-h-24:shortest=1[out]' \
  -map '[out]' -map '1:a?' -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac assets/presenter-composite.mp4
```

上述数值只是起点。看全段动作、头发和手指边缘，调阈值避免主体穿孔；屏幕与人物需同一计划时长。把合成结果重新 Normalize 加入 hypit。绿色溢色或快速运动边缘不足时明确展示缺陷，记录是否需要另评视频 matting，不静默引入外部付费服务。

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
