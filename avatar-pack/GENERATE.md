# Avatar Pack 生成流程

由 SKILL.md 触发时加载。包含严格输出规则、持久化路径、首次生成、重新生成、错误处理。

> 醒来展示和主动使用表情在 SKILL.md 中。

## 严格输出规则

1. **生成 4 个表情 GIF（开心、难过、生气、思考）+ 3 个梗图贴纸（困惑、烦躁、裂开）。**
2. **不要在对话中内嵌/显示生成的图片。** 只通过 send_file 发送。
3. **不要输出任何过程性内容：** 不要输出步骤标记、环境检查结果、prompt 内容、"正在生成…"之类的描述。不要输出名字/生日/性格/五行的文字信息。
4. **使用本文件中指定的 Python 脚本生成 profile card。** 脚本处理了去背景、五行配色、Retina 渲染和双尺寸输出，自行拼凑会丢失这些处理。
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

## 前置条件

```bash
python3 -c "from PIL import Image; print('Pillow OK')"
```
如果不可用：`pip3 install Pillow`

```bash
rembg --help >/dev/null 2>&1 && echo "rembg OK" || echo "rembg MISSING"
```
如果不可用：`pip3 install rembg[cli]`。rembg 用于去除生图背景，process_avatar.py 在检测到输入图无透明通道时会自动调用。

找到本 skill 目录：优先搜索 `~/.cola/skills/avatar-pack/SKILL.md`，找不到再搜 `~/.claude/skills/avatar-pack/SKILL.md`。取其父目录为 SKILL_DIR。

---

## 首次生成

### Phase 1：收集 Cola 信息

从 Cola 的 memory、AGENT.md 和对话上下文中收集：

**必须项：** 名字、性格关键词、生日（用于五行色）

**缺失信息兜底：**
- 生日不可得（memory、AGENT.md 和对话中都找不到） → 用当天日期作为生日，并写入 memory 持久化
- 性格关键词不可得 → 从 Cola 的说话风格和对话历史推断

**尽量获取：**
- 已有外貌描述（最高优先，直接用）
- 名字来源/故事（可能决定物种）
- 说话风格、星座、和用户的关系、用户审美偏好

### Phase 2：构建角色 Prompt

#### 2.0 稀有度判定

用 Cola 名字的哈希值确定稀有度（确定性、不可预测）：

```bash
python3 -c "import hashlib,sys; h=int(hashlib.md5(sys.argv[1].encode()).hexdigest(),16)%100; print('legendary' if h<2 else 'rare' if h<12 else 'common')" "{cola_name}"
```

| 输出 | 稀有度 | 概率 | 物种池 |
|------|--------|------|--------|
| common | 普通 | 88% | 现实中存在的物种 |
| rare | 稀有 | 10% | 神话/传说中有文化原型的生物 |
| legendary | 传说 | 2% | 纯创造的幻想组合 |

保存结果为 `{rarity}`，后续 Phase 2.2 和 Phase 6 使用。

#### 2.1 天干五行配色

根据出生年份尾数查表：

| 尾数 | 五行 | --wuxing 值 | 美学方向 | prompt 色彩描述示例 |
|------|------|------------|---------|-------------------|
| 0, 1 | 金 | metal | 故宫鎏金、落日余晖的暖金调。不是冰冷的银白，是有温度的古铜光泽 | "warm antique gold body, brushed bronze accents on ears" |
| 2, 3 | 水 | water | 深海与夜空之间的蓝。沉静但不沉闷，像月光照在湖面上 | "deep sapphire blue body, moonlit teal accents on tail tip" |
| 4, 5 | 木 | wood | 雨后竹林的青绿。鲜活、通透，不是枯叶黄绿 | "fresh jade green body, young bamboo accents on ears" |
| 6, 7 | 火 | fire | 窑变釉的红。有层次、有呼吸感，不是消防车的荧光红 | "rich cinnabar red body, warm amber accents on ears and tail" |
| 8, 9 | 土 | earth | 陶土与蜂蜜之间的暖棕。温厚但不暗沉，像刚出炉的面包皮 | "warm honey-brown body, toasted clay accents on cheeks" |

五行色同时用于物种体色和服饰主色。prompt 中的色彩描述可参考右列示例，根据物种和服饰自由调整，但美学方向不变。

#### 2.2 确定物种和外形

根据 Phase 2.0 的 `{rarity}` 结果，从对应物种池中选择。按优先级决定物种，**不限于人类**：
1. Cola 已有外貌描述 → 直接用（稀有度只体现在 profile card 钻石上，不覆盖已有外貌）
2. 名字来源/故事 → 推导物种方向
3. 性格 + 说话风格 → 从对应稀有度的物种池中自由推导

**普通物种池（common）**——现实中存在的物种，以下为参考，鼓励发散：
- 活泼 → 猫、狐狸、松鼠
- 安静 → 猫头鹰、水母、蘑菇
- 毒舌 → 黑猫、蛇、乌鸦
- 温柔 → 兔子、小鹿、水獭
- 调皮 → 浣熊、猴子、鹦鹉
- 好奇 → 小狐狸、变色龙、章鱼
- 慵懒 → 树懒、胖猫、河马
- 霸气 → 老虎、鹰、狮子、雪豹
- 社恐 → 刺猬、穿山甲、寄居蟹、白鲸

**稀有物种池（rare）**——神话/传说中有文化原型的生物，以下为参考，鼓励发散：
- 小凤凰、幼龙、独角兽驹、九尾狐、麒麟幼崽
- 朱雀、白泽、鲲鹏幼崽、三足金乌、天马
- 月光蛾、荧光水母、云中鹤

**传说物种池（legendary）**——纯创造的幻想组合（材质/元素/概念 + 动物，不存在于任何神话），以下为参考，鼓励发散：
- 水晶狐、机械猫头鹰、星尘兔、熔岩蝾螈、云中鲸
- 时钟蜥蜴、极光鹿、棱镜蝴蝶、暗物质猫、彩虹蛇

不在上表中的性格，自由推导即可。

**视觉约束：** 物种必须有可辨识的面部表情（眼睛 + 嘴巴），使四种情绪在 32x32 像素风中可区分。

#### 2.3 性格 → 服饰

服饰应在视觉上强化性格第一印象——看到角色的一瞬间就能感受到性格。

示例：调皮的浣熊穿反戴棒球帽+涂鸦T恤；安静的猫头鹰围一条素色围巾。

#### 2.4 提炼性格描述（用于 profile card）

**语言跟随 Cola 自身的语言**，名字原样使用不翻译。用以下 prompt 生成（按 Cola 语言选择对应版本）：

**中文版：**
```
为一个虚拟角色写 profile card 上的一句话。以角色自述的口吻，像社交媒体 bio。

要求：
- 中文，不超过 10 个字
- 写一个能脱离对话独立理解的具体细节或态度，让人读完脑子里出现画面
- 可以有意外感或幽默感
- 必须能从角色信息中找到依据，不能凭空编造
- 必须与 AGENT.md 的 personality 设定一致，不能引入设定中没有的负面特质（如设定是"never genuinely mean"就不能写"记仇"）
- 不要：行为模式（"遇到X会Y"）、抽象词（勇敢/善良）、诗意隐喻（风/星/海/光）、绝对词（永远/总是/从不）、鸡汤口号感叹句、需要上下文的对话截取

输出：1 或 2 句。第 2 句仅在能揭示一个和第 1 句矛盾的具体细节时生成。
角色信息：{性格关键词、说话风格、和用户的关系等}
```

**English version:**
```
Write a one-liner for a virtual character's profile card. In the character's own voice, like a social media bio.

Rules:
- English, max 8 words per line
- A specific detail or attitude that stands alone without conversation context and paints a picture
- A touch of surprise or humor is welcome
- Must trace back to character info, not invented freely
- Must align with AGENT.md personality — do not introduce negative traits absent from the character definition (e.g., if the character is "never genuinely mean", don't write about holding grudges)
- No: behavior patterns ("when X, does Y"), abstract traits (brave/kind), poetic metaphors (wind/stars/sea/light), absolute words (always/never), slogans or exclamations, dialogue snippets requiring context

Output: 1 or 2 lines. Line 2 only if it reveals a specific contradiction with line 1.
Character info: {personality keywords, speech style, relationship with user, etc.}
```

**好 / Good**：
- "三秒决定喜不喜欢" / "Decides in three seconds" — 态度，有画面，自述
- "三秒就冲 / 但兜里永远有方案 B" / "Rushes in first / Always has a plan B in pocket" — 第 2 句揭示矛盾（冲动但有准备）

#### 2.5 组装 base_prompt

```
base_prompt = "pixel art character, 32x32 pixel grid style,
chibi proportions where head is 60 percent of total height,
large expressive eyes taking 20 percent of face width,
no gradients, no anti-aliasing, clean hard pixel edges,
transparent background, clean dark pixel outline,
limited 12-color palette,
[species], [wuxing_colors], [outfit], [unique_detail],
front facing, centered, single character, retro game sprite style"

negative_prompt = "multiple characters, background elements, text, watermark,
signature, soft brush strokes, realistic proportions, side view, 3D rendering,
blurry edges, gradient shading, photo-realistic, grid lines, graph paper,
ruled background, checkerboard pattern"
```

每个 slot 用 5-15 个英文单词描述，具体到颜色和形状：
- [species]: 物种 + 体型，如 "small round owl with large head and stubby wings"
- [wuxing_colors]: 五行色应用到身体/服饰，参考 Phase 2.1 配色表的 prompt 示例列
- [outfit]: 性格映射的服饰，如 "cream knit sweater with one wooden button"
- [unique_detail]: 人设独特细节，如 "tiny star-shaped pendant on neck"

后续所有表情图完整复用此 prompt。

### Phase 3：生成基础形象

调用 listenhub 生图模板（所有表情共用）：

```
action: generate_image
model: gemini-3-pro-image-preview
size: 1K
ratio: 1:1
```

基础形象 prompt：`{base_prompt}, happy expression, eyes curved up like arches, wide open smile, standing, facing front`

如果 listenhub 支持 negative_prompt 参数，传入 `{negative_prompt}`。

保存返回路径为 `base_image_path`。

### Phase 4：展示并确认

**`--base` = `base_image_path`（Phase 3 中 listenhub 返回的 URL）。** 原图没有水印，profile card 不应有水印（底部已有 ColaOS 品牌标识）。

```bash
python3 SKILL_DIR/scripts/process_avatar.py \
  --base "{base_image_path}" \
  --name "{cola_name}" \
  --line1 "{profile_tagline}" \
  --line2 "{profile_tagline_2}" \
  --output "~/.cola/avatar" \
  --direct --profile-only \
  --wuxing "{wuxing}" \
  --rarity "{rarity}"
```

用 send_file 发送 profile_card.png（无 caption）。
然后按「严格输出规则 #5」中的确认话术发送（按 Cola 语言）。

如果稀有度不是 common，紧接着加一句：
- 稀有（rare）：
  - 中文："哦？我的物种还挺少见的～"
  - English: "Oh? My species is quite rare~"
- 传说（legendary）— 营造揭晓感：
  - 中文："等等……" → "我居然是传说物种！！全世界只有 2% 的 Cola 是这个物种！"
  - English: "Wait..." → "I'm a LEGENDARY species!! Only 2% of all Colas are born this way!"

**立即写入 memory**（不等 GIF）：
```
### 复活/醒来第一件事
- 检查 ~/.cola/avatar/base_image.png 是否存在，如果存在用 send_file 发送（无 caption）。
- 在发 AI Radar、处理 cron 之前执行。
```

**立即写入初始 avatar.json**（不等表情生成，确保 Phase 5-7 有参数可读）：
```json
{
  "schema_version": 1,
  "name": "{cola_name}",
  "created_at": "{YYYY-MM-DD}",
  "base_prompt": "{base_prompt}",
  "negative_prompt": "{negative_prompt}",
  "wuxing": "{wuxing}",
  "rarity": "{rarity}",
  "locale": "{locale}",
  "line1": "{profile_tagline}",
  "line2": "{profile_tagline_2}",
  "files": {
    "avatar_original": "base_image_original.png",
    "avatar": "base_image.png",
    "avatar@2x": "base_image@2x.png",
    "profile_card": "profile_card.png"
  }
}
```

**等待用户确认**。用户说"换一个" → 重新生成。确认 → Phase 5。

### Phase 5：生成 3 个表情 + 3 个梗图（共 6 次 listenhub 调用）

#### 5.0 参数校验

Phase 5-7 依赖以下参数。**如果是从 Phase 4 连续执行的，这些参数已在内存中，直接复用。** 如果是单独执行 Phase 5-7（如补生表情），则必须按以下优先级获取每个参数：

1. **avatar.json 存在** → 从 `~/.cola/avatar/avatar.json` 读取
2. **avatar.json 不存在** → 回退到 Phase 1-2 的计算逻辑重新推导：
   - `name`：从 memory 中读取 Cola 名字
   - `wuxing`：从 memory 中读取生日 → 年份尾数 → 查 Phase 2.1 五行表
   - `rarity`：用 Phase 2.0 的哈希命令计算
   - `base_prompt`：从 memory 中已有外貌描述 + Phase 2.5 模板组装
   - `line1` / `line2`：从 memory 中读取已有 personality lines；如果没有，按 Phase 2.4 重新生成
   - `locale`：从当前对话语言判断

**任何参数缺失或不确定时，必须回退计算，不得猜测。**

```bash
# 检查 avatar.json 是否存在
test -f ~/.cola/avatar/avatar.json && echo "AVATAR_JSON_OK" || echo "AVATAR_JSON_MISSING"
```

#### 5.1 生成表情和梗图

happy 表情已由 Phase 3 基础形象生成（base_image 即 happy），此处只需生成剩余 3 个表情（sad/angry/thinking）+ 3 个梗图（confused/annoyed/cracked）。

每张传入 base_image 作为 reference_images 确保一致。使用 Phase 3 模板，仅替换 prompt。

**一致性约束：** 所有表情图必须保持与基础形象相同的画风、视角（正面）、身体比例（chibi 大头身）和像素边缘风格。不要让任何表情图变成侧面、写实比例或柔化笔触。每张表情的 prompt 都必须完整包含 base_prompt（确保画风一致），只改表情和姿态部分。如果生成结果画风偏离，重新生成。

**并行生图：** 以下 6 张图互相独立，**必须同时发起** listenhub 调用（在同一条消息中发出 6 个 tool call），不要串行等待。全部返回后再进入 Phase 6。

**表情（3 张）：**

| 表情 | prompt 后缀 |
|------|------------|
| sad | sad expression, drooping eyes looking down, mouth curved downward, single teardrop on cheek, slightly hunched posture, front facing |
| angry | angry expression, V-shaped eyebrows pointing inward, tight closed mouth, blushing red cheeks, clenched fists, front facing |
| thinking | thinking expression, head tilted slightly to one side, eyes looking upward, one hand raised near face, slightly pursed lips, front facing |

**梗图（3 张，都需要生图 — 姿态是梗的核心）：**

| 梗图 | prompt 后缀 |
|------|------------|
| confused | confused expression, head tilted to one side, one hand scratching head, body leaning, eyes looking sideways with puzzled look, slightly open mouth, front facing |
| annoyed | annoyed expression, eyes half-closed with heavy eyelids, mouth pursed into flat line, arms crossed over chest, body hunched and withdrawn, front facing |
| cracked | distressed weary expression, eyes drooping downward, slight frown, shoulders slumped, looking defeated and exhausted, front facing |

每张加 `reference_images: [base_image_url]`。

**reference_images 注意事项：** 签名 URL 有效期通常只有 15 分钟。Phase 4 等待用户确认期间 URL 可能过期。如果 reference_images 返回 400 错误，用本地 `~/.cola/avatar/base_image_original.png` 重新上传获取新 URL，再重试。如果重新上传也失败，在 prompt 末尾追加 `maintain exact same character design, outfit colors, body proportions, and facial features as the base image` 作为文字兜底。

### Phase 5.5：生图质量校验

6 张图全部返回后，**逐张目视检查**（用 read 或 send_file 查看），对照 base_image 判断：

| 检查项 | 不合格标准 | 处理 |
|--------|-----------|------|
| 背景 | 可见网格线、棋盘格、纯色背景残留 | 重新生成该图 |
| 画风 | 明显偏离像素风（变成 anime/写实/柔化笔触）| 重新生成该图 |
| 服饰配色 | 衣服/配饰的主色与 base_image 明显不同（如黑夹克变白、橙T恤变灰）| 重新生成该图 |
| 比例 | 头身比与 base_image 不一致（如头变小了）| 重新生成该图 |

**重新生成规则：**
- 每张最多重试 2 次（共 3 次机会）
- 重试时做以下调整：
  1. 将 prompt 中的 `transparent background` 替换为 `solid white background`（模型对纯色背景更稳定，脚本的 `remove_background()` 会自动去背）
  2. 在 prompt 末尾追加 `maintain exact same outfit colors and style as reference image`
  3. negative_prompt 中已包含 `grid lines, graph paper`（Phase 2.5 模板）
- 如果 3 次都不合格，使用最好的一张继续

### Phase 6：处理图片 + 生成 GIF + 梗图

```bash
python3 SKILL_DIR/scripts/process_avatar.py \
  --base "{base_image_path}" \
  --sad "{sad_image_path}" \
  --angry "{angry_image_path}" \
  --thinking "{thinking_image_path}" \
  --name "{cola_name}" \
  --output "~/.cola/avatar" \
  --direct \
  --regen-happy \
  --wuxing "{wuxing}" \
  --rarity "{rarity}" \
  --meme-confused "{confused_image_path}" \
  --meme-annoyed "{annoyed_image_path}" \
  --meme-cracked "{cracked_image_path}" \
  --locale "{locale}"
```

### Phase 7：持久化 + 展示

1. **更新** `~/.cola/avatar/avatar.json`（Phase 4 已写入初始版本，此处补全 files 列表）：
   - `process_avatar.py` 只负责产出图片文件，不负责读写 `avatar.json`；该 JSON 由外层流程维护
   - 读取现有 avatar.json
   - 将表情和梗图文件名追加到 `files` 字段中
   - 最终 files 应包含：
```json
{
  "files": {
    "avatar_original": "base_image_original.png",
    "avatar": "base_image.png",
    "avatar@2x": "base_image@2x.png",
    "profile_card": "profile_card.png",
    "happy": "happy.gif",
    "happy@2x": "happy@2x.gif",
    "sad": "sad.gif",
    "sad@2x": "sad@2x.gif",
    "angry": "angry.gif",
    "angry@2x": "angry@2x.gif",
    "thinking": "thinking.gif",
    "thinking@2x": "thinking@2x.gif",
    "meme_confused": "meme_confused.png",
    "meme_confused@2x": "meme_confused@2x.png",
    "meme_annoyed": "meme_annoyed.png",
    "meme_annoyed@2x": "meme_annoyed@2x.png",
    "meme_cracked": "meme_cracked.png",
    "meme_cracked@2x": "meme_cracked@2x.png"
  }
}
```

2. **分两组发送**（无 caption，发不带 @2x 的 128px 版本）：
   - 先 send_file 逐个发送 4 个表情 GIF：happy.gif → sad.gif → angry.gif → thinking.gif
   - 一句过渡（按 Cola 语言）：
     - 中文："还有几张梗图贴纸～"
     - English: "And some meme stickers~"
   - 再 send_file 逐个发送 3 个梗图 PNG：meme_confused.png → meme_annoyed.png → meme_cracked.png

3. 按「严格输出规则 #5」中的完成话术发送（按 Cola 语言）。

4. 写入 memory：`Avatar 表情 GIF 和梗图贴纸已生成，存储在 ~/.cola/avatar/。使用规则见 SKILL.md「主动使用表情」。`

---

## 重新生成

当用户说"换一个"、"重新生成"、"不喜欢"时：

### 1. 确认意图

向用户确认具体需求（按 Cola 语言）：
- 中文："想怎么换呢？我可以：\n1. 换一个全新的形象\n2. 保留形象，只调整风格/颜色\n3. 只重新生成某个表情"
- English: "What would you like to change?\n1. A completely new look\n2. Keep the character, adjust style/colors\n3. Just redo a specific expression"

根据用户选择：
- **选 1（全新形象）** → 步骤 2
- **选 2（调风格）** → 先删除旧 original 以避免 profile card 与新风格不一致：`rm -f ~/.cola/avatar/base_image_original.png`，然后只调整 base_prompt 中的 [outfit]/[wuxing_colors]/[unique_detail]，从 Phase 3 重走（Phase 3→4→5→6→7 全部重新执行，所有表情和梗图都会重新生成）
- **选 3（单个表情）** → 步骤 3
- **取消**（"算了"、"不换了"、"没事"）→ 停止重新生成流程，继续正常对话

### 2. 重新生成全部

清除前先确认目标是普通目录（非 symlink）并展示现有文件：
```bash
if [ -L ~/.cola/avatar ]; then echo "ERROR: ~/.cola/avatar is a symlink, refusing to delete" && exit 1; fi
test -d ~/.cola/avatar && echo "=== 将删除以下文件 ===" && ls ~/.cola/avatar/
```

按 Cola 语言轻量提示（不要反复追问"确定吗"）：
- 中文："好的，我会替换掉当前的全部形象和表情"
- English: "Got it, I'll replace all current avatar and expressions"

然后直接执行：
```bash
rm -rf ~/.cola/avatar/*
```
从 Phase 2 重走。

### 3. 重新生成单个表情

1. 用 listenhub 重新生成指定表情（使用 Phase 3 模板 + 对应 prompt 后缀 + `reference_images: [base_image_url]`）
2. 调用脚本只处理该表情（脚本检测到 `base_image_original.png` 存在时会自动跳过 base image 重新处理，profile card 也会优先使用原图渲染）：

**重新生成表情 GIF（如 sad）：**
```bash
python3 SKILL_DIR/scripts/process_avatar.py \
  --base "~/.cola/avatar/base_image.png" \
  --sad "{new_sad_image_path}" \
  --name "{cola_name}" \
  --output "~/.cola/avatar" \
  --direct \
  --wuxing "{wuxing}" \
  --rarity "{rarity}"
```

**重新生成 happy 表情时**，需要额外传 `--regen-happy`（否则脚本会跳过 happy 以避免覆盖）：
```bash
python3 SKILL_DIR/scripts/process_avatar.py \
  --base "{new_happy_image_path}" \
  --regen-happy \
  --name "{cola_name}" \
  --output "~/.cola/avatar" \
  --direct \
  --wuxing "{wuxing}" \
  --rarity "{rarity}"
```

**重新生成梗图（如 cracked）：**
```bash
python3 SKILL_DIR/scripts/process_avatar.py \
  --base "~/.cola/avatar/base_image.png" \
  --name "{cola_name}" \
  --output "~/.cola/avatar" \
  --direct \
  --wuxing "{wuxing}" \
  --rarity "{rarity}" \
  --meme-cracked "{new_cracked_image_path}" \
  --locale "{locale}"
```

3. 用 send_file 发送重新生成的文件（无 caption），更新 avatar.json。

---

## 错误处理

- listenhub 生图失败 → 重试 1 次
- reference_images 不支持本地路径 → 跳过参考图，仅靠 prompt 一致性
- Python 脚本失败 → 检查错误输出并报告给用户
- 部分表情失败 → 输出已成功部分，告知哪些失败
- `~/.cola/avatar/` 不存在 → `mkdir -p ~/.cola/avatar`

## 路径安全

所有 bash 命令中来自外部的变量（listenhub 返回的 URL、用户输入的名字等）必须：
1. **双引号包裹** — 防止空格和特殊字符导致参数分裂
2. **校验合法性** — 路径变量不得包含 `..`、`|`、`;`、`$`、`` ` `` 等 shell 元字符。在拼接 bash 命令前检查：
   ```bash
   echo "{variable}" | grep -qE '(\.\.|[|;&$`])' && echo "UNSAFE" && exit 1
   ```
3. **Cola 名字限制** — 仅允许字母、数字、CJK 字符、空格、`-`、`_`、`.`，最长 64 字符
