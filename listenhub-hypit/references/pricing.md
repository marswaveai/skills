# 报价单

每次生成前保存 `quote.json`（不含凭证），并面向用户展示简短报价。列出机位图张数、每段 Take 的模型/时长/分辨率/参考输入、TTS 计费文字单位、音乐条数/模型、转写原音频毫秒、抠图张数、克隆次数。项目范围内现有素材列为复用/0；`npx hypit plan` 的本地请求不扣积分。

以本机已确认账号的 OpenAPI base（含 `/openapi`）为前缀，逐项调用只读估价：

| 项目 | POST 路径和报价依据 |
|---|---|
| 视频 | `/v1/video-generation/estimate-credits`，请求与实际生成的模型、分辨率、时长及参考素材时长一致；返回 `estimatedCostUsd` 时按当前服务换算 `round(USD × 15 × 7.3)`，保留美元原值和换算来源，不能把美元当积分 |
| 图片/抠图 | `/v1/images/generation/estimate-credits`，例如 `{model:"seedream-5-0-pro",imageConfig:{imageSize:"2K",aspectRatio:"9:16"}}`，读取 `credits`、`canGenerate`、warnings |
| ListenHub Voice | `/v1/listenhub-voice/estimate-credits`，使用对应 API 的完整估价参数和目标时长，读取当前结果；旧 skill 中历史秒费率不能替代实时估价 |
| 转写 | `/v1/audio-transcriptions/estimate-credits`，`{durationMs:实际原音频毫秒}` → `credits`；未生成的 Take 先按计划时长估算，实际音轨生成后校准 |

同一账号调用 `GET /v1/user/subscription` 获取 `totalAvailableCredits`（以及预留/可用字段如返回），记录余额时间戳。报价合计加用户批准的余量，预算不足就缩短/减少候选，不先调再问。Provider `readPricing` 在未来音频时长未定时会给明确标记的 **60 秒费率样例**（`usageKnown:false`），这个数字不是整条片子的总价。

## 无估价接口的费率表

核对日期：2026-09-17。以下在报价上标 **“按费率表估算”**；可用实时接口优先实时接口。

| 项目 | 积分 |
|---|---|
| TTS 直接配音 | 每次调用 `ceil(文字单位 × 0.006)`；汉字/中日韩字符及全角标点每个 2 单位，ASCII 可打印字符每个 1，其他字符按当前混合计数规则处理。按段分别取整后求和，不先合并取整 |
| 原创/纯音乐/混音 | `mureka-7.6` 5；`auto`、`mureka-8/9/o2` 10；其余模型必须先核对最新表，不猜价 |
| 音乐续写 | `mureka-7.6` 10；`auto`、`mureka-8` 15 |
| 视频/图片配乐、生成分轨、区域改写、音乐描述 | 每次 15 |
| 歌词识别 | 每次 3 |
| 分轨 | `audio-separation-1` 10；`audio-separation-2` 100 |
| 持久说话人克隆 `/voice-clone` | 套餐确认额度内 0，额度耗尽后每次保存 300；先查 speaker 列表/remainingConfirmations/maxSpeakers；数量达到上限就不能保存，不能仅凭 `isLimitReached` 或剩余确认额度判断。第二条变体直接复用 `speakerInnerId` |
| 音乐人声克隆 | 600（与说话人克隆不同；仅确实需要时列入） |

来源：[TTS 计数与换算](https://github.com/marswaveai/marswave-lib/tree/main/packages/common-lib/src/mtoken)、[音乐费率](https://github.com/marswaveai/listenhub-api-server/blob/main/src/lib/credits-config.ts)、[说话人确认费率](https://github.com/marswaveai/listenhub-api-server/blob/main/src/common/constants.ts)、[视频积分换算](https://github.com/marswaveai/listenhub-api-server/blob/main/src/lib/video-generation-credits.ts)。费率会变，检查日期与结果，不保证历史固定价长期有效。

## 实扣对账

保存调用前后余额、每个任务 ID/模型/计费输出（转写 `reservedCredits` 与 `chargedCredits`，音乐 `creditCost`，语音 `creditCharged` 等）、报价来源和成片路径。余额差可能包含同账号其他任务，优先逐任务对账，差额无法归属时说明。失败退款与尚未完成预留分开列。按费率表项目偏差超过 10% 时在交付/PR 标出，并建议补估价接口；不擅自新增接口或调钱包。
