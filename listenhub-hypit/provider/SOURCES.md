# Provider 协议来源

核对日期：2026-09-17；安装分发版本 `@hypit/hypit@0.2.1`。本包实现 MIT、免费分发，未复制 hypit 源码，未修改 hypit 署名。下列模块的公开协议身份版本均为 `1`，与 npm 分发版本不同：

- `@hypit/endpoint-kit`、`@hypit/runtime-kit`：生产仅用 Distribution 的公开 subpath `@hypit/hypit/endpoint-kit` 与 `@hypit/hypit/runtime-kit`。
- `@hypit/whisperx@1#whisperx-alignment` → `@hypit/speech-evidence@1#AlignedTranscriptEvidence`。
- `@hypit/background-removal@1#remove-background` → `@hypit/artifact@1#BlobArtifact`。
- 视频模板：`@hypit/media@1`、`@hypit/media-pipeline@1`、`@hypit/script@1`、`@hypit/timeline-author@1`、`@hypit/spatial@1`、`@hypit/media-track@1`、`@hypit/performance@1`、`@hypit/sound@1`、`@hypit/audio-track@1`、`@hypit/caption-fine@1`、`@hypit/film@1`、`@hypit/render-hyperframes@1`、`@hypit/svs@1`、`@hypit/run-markup@1`。

官方来源：[Endpoint SDK](https://github.com/hypit-ai/hypit/blob/main/packages/endpoint-kit/README.md)、[Provider 包示例](https://github.com/hypit-ai/hypit/tree/main/examples/provider-package)、[WhisperX 请求](https://github.com/hypit-ai/hypit/tree/main/packages/whisperx)、[对齐证据](https://github.com/hypit-ai/hypit/tree/main/packages/speech-evidence)、[静态抠图](https://github.com/hypit-ai/hypit/tree/main/packages/background-removal)、[Runtime Profile](https://github.com/hypit-ai/hypit/tree/main/packages/runtime-local)、[平台凭证库](https://github.com/hypit-ai/hypit/tree/main/packages/credential-store-platform)、[协议](https://github.com/hypit-ai/hypit/blob/main/LICENSE)。GitHub main 会前进，实际开发以 package-lock 锁定的 npm 0.2.1 为准。

ListenHub 来源：[转写公开合约](https://github.com/marswaveai/listenhub-api-server/blob/main/api-docs/openapi-user-en.yaml)、[图片公开控制器](https://github.com/marswaveai/listenhub-api-server/blob/main/src/openapi-controllers/image.ts)、[转写上游语言清单](https://help.aliyun.com/zh/model-studio/asr-model)（Qwen-Audio-3.0-ASR-Flash-Filetrans）。

图像读取和键控仅依赖纯 JS `pngjs@7.0.0`、`jpeg-js@0.4.4`；`@hypit/hypit` 只作为 peer/devDependency，由用户项目安装并运行其原版 CLI/Studio。测试 bootstrap 仅加载已安装 Distribution 的解析器，不分发其源文件。
