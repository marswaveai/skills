# Provider 边界

本包只提供两个已有 hypit capability；图片/视频/语音/音乐生成素材仍由现有 ListenHub skills 出文件。

| capability | 请求 | 返回 |
|---|---|---|
| `@hypit/whisperx@1#whisperx-alignment` | `{audio:BlobRef,sampleFrames,language}`，16kHz 单声道 PCM s16 WAV | `@hypit/speech-evidence@1#AlignedTranscriptEvidence` 内联 `{passages:[{words:[{text,startSample,endSampleExclusive,score}],chars:[]}]}` |
| `@hypit/background-removal@1#remove-background` | `{source:BlobRef}`，PNG/JPEG | `@hypit/artifact@1#BlobArtifact`，带 alpha 的 PNG |

毫秒转 sample 为 `round(ms*16)`，不是视频帧号。未知/负数/倒序/越过音频末尾的时间不伪造，保留词而省略时间字段。confidence 仅合法 0..1 映射 score。原服务不返回字符级证据时 `chars:[]`。

转写支持 `zh en ja ko vi th id ms fil hi ar fr de es pt ru it nl sv da fi no el pl cs hu ro bg hr sk`。hypit 显式语言只用于能力选择；ListenHub 服务自动检测实际语种，API 不接受 language 参数，可能识别出不同语种，须核对实际台词与结果。其他语言在 plan/支持检查显式拒绝，不改用本地或其他云服务。

hypit 0.2.1 的 `transcribe` 只调用 immediate endpoint，所以 Provider 在一次 immediate 调用里执行签名上传→创建→有界轮询。API key 仅送 ListenHub API，上传仅送签名地址需要的 headers。稳定幂等键取 WAV 字节、语言和 Provider 契约版本的 SHA256；同输入重跑返回原任务（即使重新上传得到新 fileKey），不重复预留积分。失败任务也会复用失败结果；用户明确同意重新付费识别时，用 CLI 指定新的幂等键创建并核对输出，不自动换 key 重试。`reportDiagnostic` 保存已受理任务 ID；超时不宣称远端取消，不自动重提。

静态抠图使用 Seedream 5.0 Pro 2K 以原图为参考换纯绿背景，再用纯 JS PNG/JPEG 解码和键控输出 PNG。结果可能重绘细节、尺寸按最接近原图的支持画幅生成；先 inspect 输出再填写真实 Extent。主体含绿色、玻璃/半透明材质不适合这条键控路线，先告知并选适合的角色服装/素材；不能声称像素级保真。WebP 等格式先本地转为 PNG/JPEG。视频绿幕按 production.md 用 ffmpeg 处理，不把静态 Provider 当视频 matting。

开发校验在 `provider/`：`npm ci && npm run lint && npm run typecheck && npm test`。`npm run build` 更新随包分发的 `dist/`。单测使用 mock transport，无真实 API key、无扣费；开发测试启动器只从安装的 hypit 包加载其测试所需模块解析器，不复制该实现。生产代码仅 import 公开 `@hypit/hypit/endpoint-kit` 与 `runtime-kit`。
