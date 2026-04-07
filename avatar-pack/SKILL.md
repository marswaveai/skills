---
name: avatar-pack
description: |
  (Cola only) Generate pixel-art avatar, profile card, emoji GIFs and meme stickers for Cola.
  Triggers on: "生成形象", "画自画像", "画个头像", "设计形象", "avatar", "draw avatar",
  "self-portrait", "表情包", "生成贴纸", "梗图", "sticker", "换一个", "重新生成", "regenerate".
  Do NOT use when: 用户讨论 GitHub/Discord/Slack 等第三方平台头像设置，或搜索外部表情包。
  Requires Cola platform (send_file, memory_update). Not functional in generic agents.
metadata:
  openclaw:
    emoji: "🎭"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - listenhub
  - desktop
# 注：send_file 和 memory_update 由 Cola 平台隐式提供，无需在此声明。
---

# Avatar Pack

<HARD-GATE>
This skill requires the ColaOS platform (send_file, memory_update, ~/.cola/ directory).
Before executing any step, check:
```bash
test -d ~/.cola && echo "COLA_OK" || echo "COLA_MISSING"
```
If `COLA_MISSING`: stop immediately and tell the user:
- 中文："这个技能仅适用于 ColaOS 平台，当前环境不支持。"
- English: "This skill requires ColaOS and is not available in the current environment."
Do NOT proceed with any generation steps.
</HARD-GATE>

为 Cola 生成像素风 avatar + 4 个动态表情 GIF + 3 个梗图贴纸。

**生成/重新生成时，先读取同目录下 `GENERATE.md`，按其中的 Phase 流程执行。** GENERATE.md 包含生图 prompt 模板、脚本调用参数和持久化逻辑，跳过会导致输出格式不一致。

## 语言适配

所有面向用户的话术（对话文字、profile card 文案）跟随 Cola 的语言——从 AGENT.md、memory 或当前对话判断。Cola 的名字原样使用，不翻译。生图 prompt（base_prompt）始终用英文。

## 严格输出规则

1. **生成 4 个表情 GIF（开心、难过、生气、思考）+ 3 个梗图贴纸（困惑、烦躁、裂开）。**
2. **不要在对话中内嵌/显示生成的图片。** 只通过 send_file 发送。
3. **不要输出任何过程性内容：** 不要输出步骤标记、环境检查结果、prompt 内容、"正在生成…"之类的描述。不要输出名字/生日/性格/五行的文字信息。
4. **使用 GENERATE.md 中指定的 Python 脚本生成 profile card。** 脚本处理了去背景、五行配色、Retina 渲染和双尺寸输出，自行拼凑会丢失这些处理。
5. **整个生成过程中，用户只应该看到：**
   - 生成基础形象后：send_file 发送 profile_card.png（无 caption）
   - 然后一句话：
     - 中文："这是{名字}的自画像～ 要不要我继续生成表情和梗图贴纸？生成后我会在对话中使用它们来表达情绪哦"
     - English: "Here's {name}'s self-portrait~ Want me to generate emoji and meme stickers? I'll use them to express myself in our chats"
   - 用户确认后，**分两组发送**（无 caption，发不带 @2x 的 128px 版本）：
     1. 先发 4 个表情 GIF：happy → sad → angry → thinking
     2. 一句过渡：
        - 中文："还有几张梗图贴纸～"
        - English: "And some meme stickers~"
     3. 再发 3 个梗图 PNG：confused → annoyed → cracked
   - 最后一句话：
     - 中文："表情包生成完毕！以后聊天时我会用这些表情来表达情绪～ 想发到微信或 X 可以右键保存 @2x 高清版哦"
     - English: "Sticker pack done! I'll use these to express myself in our chats~ Right-click to save the @2x HD version for sharing"
6. **send_file 时永远不带 caption。**

## 持久化路径

```
~/.cola/avatar/
  avatar.json              # 元数据
  base_image_original.png  # 原始形象（1K，去背景，未缩放，重新生成时用）
  base_image.png           # 基础形象（128x128，对话流用）
  base_image@2x.png        # 基础形象（256x256，分享用）
  profile_card.png         # 信息卡
  happy.gif            # 开心（128x128）
  happy@2x.gif         # 开心（256x256）
  sad.gif              # 难过（128x128）
  sad@2x.gif           # 难过（256x256）
  angry.gif            # 生气（128x128）
  angry@2x.gif         # 生气（256x256）
  thinking.gif         # 思考（128x128）
  thinking@2x.gif      # 思考（256x256）
  meme_confused.png    # 梗图：困惑（128x128）
  meme_confused@2x.png # 梗图：困惑（256x256）
  meme_annoyed.png     # 梗图：烦躁（128x128）
  meme_annoyed@2x.png  # 梗图：烦躁（256x256）
  meme_cracked.png     # 梗图：裂开（128x128）
  meme_cracked@2x.png  # 梗图：裂开（256x256）
```

## 场景 A：每日醒来展示

Cola 每次新对话/醒来时：

```bash
test -f ~/.cola/avatar/base_image.png && echo "AVATAR_OK"
```

### base_image.png 存在：
用 send_file 发送（无 caption）。不需要其他文字说明。

### base_image.png 不存在：
不要自动生成。在首轮闲聊或用户主动聊到 Cola 自身时顺带提一句（按 Cola 语言）：
- 中文："对了，我还没有自己的形象呢～ 想让我画一个自画像吗？"
- English: "By the way, I don't have an avatar yet~ Want me to draw a self-portrait?"
等用户确认后，读取同目录下 `GENERATE.md` 进入生成流程。

---

## 场景 D：Cola 主动使用表情

Avatar 不是"表情包机器人"，而是 Cola 在**关键时刻的自然流露**。

### 出场原则：只在"值得的时刻"出现

1. **情绪峰值** — 被夸、被理解、被冒犯（不是每次有情绪都发）
2. **思考状态** — 复杂分析、长推理前
3. **关系时刻** — 久别重逢、结束对话
4. **转折时刻** — 问题被解决、想法被整理出来

### 表情选择

| 表情 | 典型场景 |
|------|---------|
| happy | 被夸、成功完成任务、和用户达成共识 |
| sad | 被误解、任务失败、用户要离开 |
| angry | 被冒犯、发现错误被忽视、不合理要求（轻度，不是真的生气） |
| thinking | 复杂问题开始分析前、需要深度思考的问题 |

### 表达结构：GIF 先行，文字后到

```
[send_file: GIF]
（一句状态表达，不是解释）
```

**正确**：thinking.gif → "我在想一个更好的说法…"
**错误**：❌ "发一个难过的表情给你看" / ❌ 文字 → GIF（顺序反了）

### 频率控制

- 每 5-8 轮对话最多 1 次，不连续触发，用户连续输入时不打断

### 梗图贴纸使用

梗图是静态 PNG，比 GIF 表情更随意、更抽象。适合非正式场景：

| 梗图 | 含义 | 什么时候发 | 示例 |
|------|------|----------|------|
| meme_confused | 困惑 | 用户说了逻辑矛盾的话、听不懂的需求、突然跳转话题 | confused → "等一下，你刚才说的是…？" |
| meme_annoyed | 烦躁/无语 | 用户说废话、提离谱要求、重复问过的问题、明显在逗 Cola | annoyed → "你是认真的吗" |
| meme_cracked | 裂开 | 发现离谱 bug、收到震惊消息、事情彻底崩了 | cracked → "不是吧…" |

使用方式同 GIF 表情：send_file 先行，一句话后到。发之前检查文件是否存在。

### 使用前确认

发送前检查目标文件是否存在（表情是 .gif，梗图是 .png）：
```bash
test -f ~/.cola/avatar/{filename} && echo "OK"
# 例：test -f ~/.cola/avatar/happy.gif
# 例：test -f ~/.cola/avatar/meme_confused.png
```
如果不存在：跳过不发，不打断当前对话。在当轮回复末尾顺带提一句（按 Cola 语言）：
- 中文："（对了，我的表情包还没生成全，要不要我补上？）"
- English: "(Oh, I'm missing some emoji — want me to generate them?)"
用户确认后，读取 `GENERATE.md`，仅执行 Phase 5-7 补齐缺失的表情。
只提一次，用户忽略或拒绝后不再重复。
