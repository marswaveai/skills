# Creator Writing Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate khazix-writer's writing methodology into the creator skill, replacing thin writing guidance with a deep writing engine across WeChat, Xiaohongshu, and Narration platforms.

**Architecture:** Shared `writing-engine/` directory holds cross-platform rules (forbidden words, rhetoric, quality review, AI-human boundary). Each platform gets rewritten `style.md`, new prototypes, methodology, and style examples. Platform `template.md` files are updated to reference the engine. `SKILL.md` gets three new interactive steps.

**Tech Stack:** Markdown content files only. No code, no dependencies. Source material in `~/coding/khazix-skills/khazix-writer/`.

**Spec:** `docs/superpowers/specs/2026-04-09-creator-writing-engine-design.md`

---

## File Map

### Created (13 files)

| File | Responsibility | Source |
|------|---------------|--------|
| `creator/writing-engine/forbidden-words.md` | Universal forbidden vocabulary, punctuation, anti-patterns | khazix SKILL.md § 绝对禁区 + L1 |
| `creator/writing-engine/rhetoric.md` | 19 rhetorical techniques with examples | khazix SKILL.md § 风格内核 + style_examples.md |
| `creator/writing-engine/quality-review.md` | L1-L4 pyramid framework, iteration logic, thresholds | khazix SKILL.md § 第四步 |
| `creator/writing-engine/ai-human-boundary.md` | AI/human collaboration roles | khazix SKILL.md § 第二步 |
| `creator/templates/wechat/methodology.md` | WeChat topic selection | khazix content_methodology.md |
| `creator/templates/wechat/article-prototypes.md` | 5 article prototypes + matching heuristics | khazix SKILL.md § 文章原型 + content_methodology.md § 按写作原型 |
| `creator/templates/wechat/references/style-examples.md` | Before/after comparisons, technique examples | khazix style_examples.md (adapt directly) |
| `creator/templates/xiaohongshu/methodology.md` | Xiaohongshu topic selection | Adapt from khazix methodology for short-form |
| `creator/templates/xiaohongshu/content-prototypes.md` | 5 xiaohongshu content types | Original, informed by spec § 5.2 |
| `creator/templates/xiaohongshu/references/style-examples.md` | Card copy examples, short-form technique examples | Original, inspired by khazix examples |
| `creator/templates/narration/methodology.md` | Narration topic selection | Adapt from khazix methodology for spoken word |
| `creator/templates/narration/script-prototypes.md` | 4 narration script types | Original, informed by spec § 5.3 |
| `creator/templates/narration/references/style-examples.md` | Script opening examples, oral transitions | Original, inspired by khazix examples |

### Rewritten (3 files — complete replacement)

| File | Responsibility |
|------|---------------|
| `creator/templates/wechat/style.md` | Full khazix style rules for long-form + review thresholds |
| `creator/templates/xiaohongshu/style.md` | Adapted khazix style for short-form + review thresholds |
| `creator/templates/narration/style.md` | Adapted khazix style for spoken word + review thresholds |

### Modified (4 files — surgical updates)

| File | Changes |
|------|---------|
| `creator/templates/wechat/template.md` | Add writing-engine references, self-review step, prototype loading |
| `creator/templates/xiaohongshu/template.md` | Add writing-engine references, self-review step, prototype loading |
| `creator/templates/narration/template.md` | Add writing-engine references, self-review step, prototype loading |
| `creator/SKILL.md` | Add Step 2.5 (Topic Assistance), Step 3a (Prototype Classification), update Step 5 |

### Unchanged

All preset files, `shared/` utilities, other skills (content-parser, image-gen, tts, asr).

---

## Task 1: Create Writing Engine — Forbidden Words

**Files:**
- Create: `creator/writing-engine/forbidden-words.md`
- Source: `~/coding/khazix-skills/khazix-writer/SKILL.md` lines 147-166 (绝对禁区) and lines 255-281 (L1 checks)

- [ ] **Step 1: Create the writing-engine directory**

```bash
mkdir -p creator/writing-engine
```

- [ ] **Step 2: Write `forbidden-words.md`**

Create `creator/writing-engine/forbidden-words.md` with this structure:

```markdown
# 禁用词表与结构规范

> 本文件由所有平台共享。写作和自查时必须遵守，零容忍。

## 禁用词汇

| 禁用 | 原因 | 替代方案 |
|------|------|---------|
```

**Content instructions:**

1. Extract ALL forbidden words from khazix SKILL.md § 绝对禁区 items 1, 4 (lines 151-163). These include:
   - 套话: "首先...其次...最后", "综上所述", "值得注意的是", "不难发现", "让我们来看看", "接下来让我们"
   - 高频踩雷词: "说白了", "意味着什么", "这意味着", "本质上", "换句话说", "不可否认"
2. Add the additional terms from spec § 4.1: "深入探讨", "全面分析", "在当今...的时代", "随着...的发展", "总的来说"
3. For each entry: forbidden term, one-line reason, 1-2 replacement suggestions

Then add sections:
- **禁用标点** — table: `：` → comma, `——` → comma/period, `""` / `""` → `「」` or bare. Extracted from khazix § 绝对禁区 item 3.
- **结构反模式** — bullet list: >3 consecutive bullets, >2-line bold blocks, markdown headers in body (exception: numbered methodology articles). From khazix § 绝对禁区 items 2, 5.
- **空泛工具名** — never "AI工具", "某个模型", "相关技术". From khazix § 绝对禁区 item 6.
- **教科书开头** — ban "在当今AI快速发展的时代" etc. From khazix § 绝对禁区 item 7.

- [ ] **Step 3: Verify no cross-contamination**

Read the created file and confirm:
- No duplicate entries
- Every forbidden term has at least one replacement
- Replacements don't themselves appear in the forbidden list

- [ ] **Step 4: Commit**

```bash
git add creator/writing-engine/forbidden-words.md
git commit -m "feat(writing-engine): create forbidden words reference"
```

---

## Task 2: Create Writing Engine — Rhetoric

**Files:**
- Create: `creator/writing-engine/rhetoric.md`
- Source: khazix SKILL.md § 风格内核 (lines 101-145) + `references/style_examples.md` (all 19 sections)

- [ ] **Step 1: Write `rhetoric.md`**

Create `creator/writing-engine/rhetoric.md` with this structure:

```markdown
# 修辞技巧库

> 19 种核心写作技巧。每种包含：定义、适用场景、平台适用性、1-2 个实例。
> 本文件由所有平台共享。各平台按自身特点选用。

## 1. 契诃夫之枪 (Chekhov's Gun)

**定义**：...
**适用场景**：...
**平台**：WeChat ✅ | Xiaohongshu ❌ | Narration ✅（长口播）
**示例**：

> [extract from style_examples.md § 相关 section]
```

**Content instructions:**

For each of the 19 techniques listed in spec § 4.2:

1. **Definition**: Extract from khazix SKILL.md § 风格内核 — each technique has a paragraph explaining it
2. **When to use**: Summarize in 1 line
3. **Platform applicability**: Use spec § 7 adaptation principles to tag each technique:
   - 契诃夫之枪: WeChat only (needs 4000+ chars)
   - 升番逻辑: All platforms (scale differs)
   - 人物压缩法: All platforms
   - 知识随口丢: All platforms
   - 逻辑断裂: All platforms
   - 反向论证: All platforms
   - 文化升维: WeChat required, others optional
   - 句式断裂: WeChat + Xiaohongshu text, Narration = dramatic pause
   - 层层剥开: WeChat + long narration
   - 谦逊铺垫: All platforms (methodology types)
   - 读者直呼: All platforms (more frequent in narration)
   - 疑问节奏: All platforms (stronger in narration)
   - 对立面承认: All platforms
   - 英雄之旅: WeChat + narration
   - 亲自下场: All platforms
   - 创意案例包装: All platforms
   - 逐一展示+吐槽: All platforms (scale differs)
   - 坦诚学习曲线: All platforms (methodology types)
   - 幽默写法: All platforms
4. **Examples**: For each technique, extract 1-2 concrete examples from the sources below. Keep examples verbatim — they are real khazix quotes.

   Source mapping (technique → example source):
   - 契诃夫之枪 → SKILL.md line 127 (callback discussion) — no dedicated style_examples section
   - 升番逻辑 → style_examples.md § 8 (逐一展示法)
   - 人物压缩法 → style_examples.md § 6 (人物画像法)
   - 知识随口丢 → style_examples.md § 3 (知识"随手掏"示例)
   - 逻辑断裂 → style_examples.md § 13 (论述中的故意打破)
   - 反向论证 → style_examples.md § 16 (反向论证的荒诞启蒙)
   - 文化升维 → style_examples.md § 7 (文化升维)
   - 句式断裂 → style_examples.md § 9 (句式断裂)
   - 层层剥开 → style_examples.md § 18 (层层剥开式写法)
   - 谦逊铺垫 → style_examples.md § 19 (谦逊铺垫的进阶写法)
   - 读者直呼 → SKILL.md line 131 (读者直呼法 discussion) — no dedicated style_examples section
   - 疑问节奏 → style_examples.md § 17 (疑问句制造节奏刹车)
   - 对立面承认 → style_examples.md § 14 (对立面的理解与承认)
   - 英雄之旅 → SKILL.md lines 137-138 (英雄之旅叙事弧 discussion) — no dedicated style_examples section
   - 亲自下场 → style_examples.md § 5 (亲自下场/调查实验)
   - 创意案例包装 → SKILL.md lines 201-203 (创意案例的力量) — no dedicated style_examples section
   - 逐一展示+吐槽 → style_examples.md § 8 (逐一展示法)
   - 坦诚学习曲线 → style_examples.md § 15 (方法论中的坦诚学习曲线)
   - 幽默写法 → style_examples.md § 10 (幽默写法)

- [ ] **Step 2: Verify completeness**

Confirm all 19 techniques from spec § 4.2 are present. Count headings.

- [ ] **Step 3: Commit**

```bash
git add creator/writing-engine/rhetoric.md
git commit -m "feat(writing-engine): create rhetoric techniques reference"
```

---

## Task 3: Create Writing Engine — Quality Review

**Files:**
- Create: `creator/writing-engine/quality-review.md`
- Source: khazix SKILL.md § 第四步 (lines 246-413) + spec § 4.3

- [ ] **Step 1: Write `quality-review.md`**

Create `creator/writing-engine/quality-review.md` with this structure:

```markdown
# L1-L4 质量自查体系

> 写完内容后自动执行的四层质量审查。从硬性规则到主观活人感，层层递进。
> 框架跨平台通用，具体阈值见各平台 style.md § Review Thresholds。

## 运行方式

写完后自动执行，用户不可见。沉默通过或迭代修复。

### 迭代逻辑
[the L1→L4 flow diagram from spec § 3]

### 迭代上限
最多 3 轮完整迭代。超过 3 轮输出 cap-hit 报告。

### Cap-hit 报告格式
[the ⚠️ format from spec § 3]

### 上下文管理
逐层加载参考文件：L1 加载 forbidden-words.md，L2 加载 style.md，L3 加载 *-prototypes.md，L4 全文通读。

---

## L1 硬性规则检查（自动扫描层）
[adopt verbatim from khazix lines 250-282, adapting references to point at writing-engine/forbidden-words.md]

## L2 风格一致性检查（模式匹配层）
[adopt verbatim from khazix lines 284-310]

## L3 内容质量检查（深度审查层）
[adopt verbatim from khazix lines 312-346]

## L4 活人感终审（最终人格层）
[adopt verbatim from khazix lines 348-371]

---

## 平台阈值差异

| 检查项 | 公众号 | 小红书 | 口播 |
|--------|--------|--------|------|
[the table from spec § 4.3]
```

**Content instructions:**

1. Copy the L1-L4 sections from khazix SKILL.md § 第四步 (lines 246-413) **verbatim** — these are the core quality rules
2. Add the iteration logic and cap-hit report from spec § 3
3. Add the platform threshold table from spec § 4.3
4. Add the context management note from spec § 6 (layer-by-layer loading)
5. Remove the "自检输出格式" section from khazix (lines 373-410) — replaced by silent pass / cap-hit report
6. Change all file references from khazix-internal ("推荐口语化词组") to writing-engine paths ("see `forbidden-words.md`", "see platform `style.md`")

- [ ] **Step 2: Verify references**

Check that all file paths mentioned in the document (`forbidden-words.md`, `style.md`, `*-prototypes.md`) use correct relative paths.

- [ ] **Step 3: Commit**

```bash
git add creator/writing-engine/quality-review.md
git commit -m "feat(writing-engine): create L1-L4 quality review framework"
```

---

## Task 4: Create Writing Engine — AI-Human Boundary

**Files:**
- Create: `creator/writing-engine/ai-human-boundary.md`
- Source: khazix SKILL.md § 第二步 (lines 46-82)

- [ ] **Step 1: Write `ai-human-boundary.md`**

Create `creator/writing-engine/ai-human-boundary.md`. Copy khazix SKILL.md lines 46-82 (§ 第二步：明确AI的角色边界) **verbatim**, with these changes:

1. Remove the leading "这一步非常重要" intro sentence — replace with a brief header explaining this file's purpose
2. Keep all subsections: "AI擅长做的", "AI做了会暴露的", "理想的协作流程"
3. Keep all concrete examples (9.9 DeepSeek, 499 OpenClaw, etc.) — they are real and illustrative
4. Add a note at top: "本文件帮助用户理解：提供越具体的一手素材，AI 产出质量越高。"

**Note:** This file is intentionally not referenced in any pipeline step or template. It serves as informational documentation that can be surfaced to users on request (e.g., when they ask why output quality varies based on input quality). It is NOT loaded during the self-review loop.

- [ ] **Step 2: Commit**

```bash
git add creator/writing-engine/ai-human-boundary.md
git commit -m "feat(writing-engine): create AI-human collaboration boundary"
```

---

## Task 5: Create WeChat Style, Prototypes, Methodology, and Examples

**Files:**
- Rewrite: `creator/templates/wechat/style.md` (31 lines → ~200 lines)
- Create: `creator/templates/wechat/article-prototypes.md`
- Create: `creator/templates/wechat/methodology.md`
- Create: `creator/templates/wechat/references/style-examples.md`

- [ ] **Step 1: Create references directory**

```bash
mkdir -p creator/templates/wechat/references
```

- [ ] **Step 2: Rewrite `style.md`**

Replace `creator/templates/wechat/style.md` entirely. New structure:

```markdown
# 公众号写作风格

> 基于「数字生命卡兹克」的写作体系。完整采用其风格作为默认声音。
> 通用禁用规则见 `../../writing-engine/forbidden-words.md`
> 修辞技巧库见 `../../writing-engine/rhetoric.md`

## 核心价值观

[Copy from khazix SKILL.md lines 18-29 — the 4 values verbatim]

## 风格内核

[Copy from khazix SKILL.md § 风格内核 lines 101-145 — ALL subsections:
- 节奏感
- 论述中的故意打破
- 知识输出方式
- 私人视角
- 判断力
- 对立面的理解与承认
- 情绪表达
- 亲自下场
- 人物画像法
- 文化升维
- 句式断裂
- 回环呼应
- 谦逊铺垫法
- 读者直呼法
- 疑问句的节奏作用
- 层层剥开的修辞
- 英雄之旅叙事弧
- 反向论证
- 案例人物的公正性
- 游戏细节要用玩家语言
- 方法论文章的结构原则]

## 绝对禁区

参考 `../../writing-engine/forbidden-words.md`（完整禁用词表在那边），此处仅补充公众号特定规范：
- 不加小标题（除分条目方法论文章）
- 用口语化转场句衔接板块
- 段落要短，一句话常独立成段

## 推荐口语化词组

[Copy from khazix SKILL.md lines 168-184 verbatim — the full phrase inventory:
转场和过渡、表达判断、承认和自嘲、情绪表达、拉近距离、口头禅和口癖]

## 开头模板

[Copy from khazix SKILL.md lines 186-194 — the 4 opening types]

## 结构模板

[Copy from khazix SKILL.md lines 205-235 — the full structure template including 固定尾部]

## 字数和格式

[Copy from khazix SKILL.md lines 237-244]

## Review Thresholds

本平台在 L1-L4 自查中使用以下阈值：
- L2-2 一句话独立成段最少出现次数：3
- L2-3 不同口语化表达最少使用数量：8-10
- L2-3 情绪标点（。。。/？？？/= =）：必须出现至少 1 种
- L3-3 文化升维：必须（不可跳过）
```

**Critical**: Copy khazix content verbatim where indicated. Do not summarize or rephrase — the precision of the phrasing IS the value.

- [ ] **Step 3: Create `article-prototypes.md`**

Create `creator/templates/wechat/article-prototypes.md`. Content source: khazix SKILL.md § 文章原型 (lines 87-99) + `content_methodology.md` § 按写作原型 (lines 77-102).

Structure:

```markdown
# 公众号文章原型

> 写作前先判断文章属于哪种原型，每种的写法重心不同。

## 匹配启发

| 用户输入信号 | 推荐原型 |
|-------------|---------|
| 提到测试、尝试、购买、亲手做某事 | 调查实验型 |
| 提供具体产品/工具要评测 | 产品体验型 |
| 描述一个趋势、现象、"为什么X" | 现象解读型 |
| 有一个具体工具/Prompt 要推荐 | 工具分享型 |
| 想分享积累的经验、"N条心得" | 方法论分享型 |

## 1. 调查实验型

**核心**：[from khazix]
**叙事弧**：[from khazix]
**过往案例**：[from content_methodology.md]
**L3-5 专项检查**：[from khazix L3-5]

[repeat for all 5 prototypes]
```

Merge the prototype descriptions from khazix SKILL.md (lines 87-99) with the detailed examples from `content_methodology.md` (lines 77-102). Add the matching heuristics table from spec § 3. Add the L3-5 check criteria from khazix SKILL.md (lines 334-339).

- [ ] **Step 4: Create `methodology.md`**

Create `creator/templates/wechat/methodology.md`. Content source: khazix `content_methodology.md` (full file, lines 1-137).

Structure:

```markdown
# 公众号内容方法论

> 选题辅助框架。当用户输入是话题/关键词时，Step 2.5 使用本文件。

## 选题交集模型

[Copy from content_methodology.md § 选题交集模型 — the three-circle Venn]
Note: the three circles are 你的专业领域 + 读者的普遍兴趣 + 当下的时间节点

## HKR 质检法

[Copy from content_methodology.md § HKR质检法]

## 角色代入法

[Copy from content_methodology.md § 角色代入法]

## 选题来源

[Copy from content_methodology.md § 选题来源]

## 选题分类与案例

[Copy from content_methodology.md § 按业务类型 — 3 categories with example titles]
[Copy from content_methodology.md § 按内容类型]

## 创意案例工作法

[Copy from content_methodology.md § 创意案例工作法 — anchors + micro-story packaging]
```

Adapt by stripping khazix-specific branding — this methodology is now the creator skill's methodology.

- [ ] **Step 5: Create `references/style-examples.md`**

Create `creator/templates/wechat/references/style-examples.md`. Copy `~/coding/khazix-skills/khazix-writer/references/style_examples.md` **nearly verbatim** — this is 429 lines of real examples that should be preserved as-is.

Changes from source:
1. Add a header: "# 公众号风格示例库\n\n> 真实案例，来自「数字生命卡兹克」的公众号文章。写作和自查时参考。"
2. Keep ALL 19 sections (§1-§19) intact
3. Keep the AI vs. khazix comparison section (§12) intact — this is critical teaching material

- [ ] **Step 6: Verify cross-references**

Read the newly created `style.md` and confirm:
- References to `../../writing-engine/forbidden-words.md` exist
- References to `../../writing-engine/rhetoric.md` exist
- The "Review Thresholds" section is present with correct values per spec § 4.3

- [ ] **Step 7: Commit**

```bash
git add creator/templates/wechat/style.md creator/templates/wechat/article-prototypes.md creator/templates/wechat/methodology.md creator/templates/wechat/references/style-examples.md
git commit -m "feat(wechat): rewrite style, add prototypes, methodology, and examples"
```

---

## Task 6: Create Xiaohongshu Style, Prototypes, Methodology, and Examples

**Files:**
- Rewrite: `creator/templates/xiaohongshu/style.md` (36 lines → ~120 lines)
- Create: `creator/templates/xiaohongshu/content-prototypes.md`
- Create: `creator/templates/xiaohongshu/methodology.md`
- Create: `creator/templates/xiaohongshu/references/style-examples.md`

- [ ] **Step 1: Create references directory**

```bash
mkdir -p creator/templates/xiaohongshu/references
```

- [ ] **Step 2: Rewrite `style.md`**

Replace `creator/templates/xiaohongshu/style.md` entirely. This is an **adaptation** of khazix style for short-form, NOT a copy. Structure:

```markdown
# 小红书写作风格

> 基于「数字生命卡兹克」写作体系，适配小红书短内容格式。
> 通用禁用规则见 `../../writing-engine/forbidden-words.md`
> 修辞技巧库见 `../../writing-engine/rhetoric.md`

## 核心价值观

同公众号（好奇心、讲人话、真诚、有所为有所不为）。在小红书场景下的体现：
- 好奇心 → 用标题和封面激发点击欲
- 讲人话 → 比公众号更口语，可用网络流行语（但不硬凑）
- 真诚 → 真实体验，不夸大效果
- 有所为 → 不做无脑种草

## 风格适配

相比公众号长文，小红书内容的关键差异：
- **信息密度更高**：每句话都要有信息量，没有铺垫的余地
- **段落更短**：1-2 句一段，大量换行
- **Emoji 策略**：每段最多 1-2 个，作为视觉标点而非装饰
- **口语词组**：保留但压缩，使用频率 4-6 个不同表达即可
- **情绪标点**：可用但更克制（公众号的"？？？"在小红书可能显得过激）

## 长文结构

- 标题：必须含数字或情绪钩子（"5个方法"、"绝绝子"、"一定要看"）
- 开头：1-2 句立即钩住
- 正文：短段落，自由换行
- 标签：末尾 3-5 个相关 hashtag

## 卡片文案规范

- 封面卡：一个核心信息，大字醒目
- 内容卡：每卡一个要点，标题 + 2-3 行解释
- 文字密度分级：sparse / balanced / dense（见 template.md）
- 每行不超过 10 个中文字（AI 图片模型渲染长文本不可靠）

## 禁用规则

参考 `../../writing-engine/forbidden-words.md`（全部适用）。

小红书额外规则：
- 不用过长的句子（超过 30 字就拆）
- 避免学术腔（小红书读者期待轻松感）

## 推荐口语化词组

从公众号词库中精选适合短内容的表达：
- 转场："说真的"、"其实吧"、"你想想看"
- 判断："我觉得还是挺重要的"、"我自己的感受是"
- 自嘲："说实话我也不确定"、"可能有些想法还不成熟"
- 情绪："太离谱了"、"你敢信？"、"给我一下子整不会了"

## Review Thresholds

- L2-2 一句话独立成段最少出现次数：2
- L2-3 不同口语化表达最少使用数量：4-6
- L2-3 情绪标点：可选（不强制）
- L3-3 文化升维：可选（可跳过）
```

- [ ] **Step 3: Create `content-prototypes.md`**

Create `creator/templates/xiaohongshu/content-prototypes.md`. **This is original content**, informed by spec § 5.2:

```markdown
# 小红书内容原型

> 创作前先判断内容属于哪种原型，决定叙事结构和卡片密度。

## 匹配启发

| 用户输入信号 | 推荐原型 |
|-------------|---------|
| 体验了某产品/工具，想推荐 | 种草测评 |
| 想分享N个技巧/工具/方法 | 干货清单 |
| 踩了坑，想提醒别人 | 踩坑避雷 |
| 想对比多个产品 | 对比横评 |
| 有个人故事想分享 | 故事分享 |

## 1. 种草测评

**核心**："我试了，你不用试了"
**叙事结构**：使用场景 → 真实体验 → 优缺点 → 明确推荐/不推荐
**卡片密度**：封面 sparse，体验卡 balanced，总结卡 balanced
**典型钩子**："用了一周，说说真实感受"、"这个XX真的值得买吗"
**L3-5 专项**：是否有真实使用场景？是否给出明确好恶判断？

## 2. 干货清单
[similar structure]

## 3. 踩坑避雷
[similar structure]

## 4. 对比横评
[similar structure]

## 5. 故事分享
[similar structure]
```

Fill in each prototype per spec § 5.2 descriptions. Include narrative structure, card density recommendation, typical hooks, and L3-5 review criteria.

- [ ] **Step 4: Create `methodology.md`**

Create `creator/templates/xiaohongshu/methodology.md`. **Adapted from khazix for xiaohongshu** per spec § 5.2:

```markdown
# 小红书内容方法论

> 选题辅助框架。当用户输入是话题/关键词时使用。

## 选题交集模型

同公众号三圈模型（专业领域 ∩ 读者兴趣 ∩ 当下时机），但小红书更强调：
- 视觉可表达性：这个话题能做成好看的卡片吗？
- 搜索需求：小红书用户会搜这个关键词吗？

## HKR 质检

H/K/R 三项仍适用，但小红书额外要求**视觉钩子**：
- 话题能否用封面图一句话表达？
- 卡片内容是否有"一眼就想保存"的冲动？

## 选题来源

- 小红书热搜榜
- 评论区高频需求（"有没有""推荐""怎么"）
- 季节性内容（开学季、年终总结、节日）
- 竞品账号的爆款话题

## 标题工程

- 数字型："5个"、"3步"、"10分钟"
- 情绪型："绝了"、"一定要看"、"后悔没早知道"
- 悬念型："原来..."、"没想到..."
```

- [ ] **Step 5: Create `references/style-examples.md`**

Create `creator/templates/xiaohongshu/references/style-examples.md`. **Original content** with ~100 lines:

```markdown
# 小红书风格示例库

## 好的卡片文案 vs 坏的

**好**：
> 标题：3个AI工具让我下班早了2小时
> 副标题：第2个真的绝了

**坏**：
> 标题：深入探讨AI工具如何提升工作效率
> 副标题：综合分析三款主流产品

[3-4 more good/bad pairs]

## 长文钩子示例

[4-6 examples of good xiaohongshu opening hooks]

## 修辞技巧适配示例

### 升番逻辑（小红书版）
[compressed example: 3-4 items instead of 6]

### 人物压缩法（小红书版）
[shorter, 1-2 sentences instead of 3-5]

### 知识随口丢（小红书版）
[even more casual than wechat version]
```

- [ ] **Step 6: Verify cross-references**

Read the newly created `style.md` and confirm:
- References to `../../writing-engine/forbidden-words.md` exist
- References to `../../writing-engine/rhetoric.md` exist
- The "Review Thresholds" section is present with correct values per spec § 4.3

- [ ] **Step 7: Commit**

```bash
git add creator/templates/xiaohongshu/style.md creator/templates/xiaohongshu/content-prototypes.md creator/templates/xiaohongshu/methodology.md creator/templates/xiaohongshu/references/style-examples.md
git commit -m "feat(xiaohongshu): rewrite style, add prototypes, methodology, and examples"
```

---

## Task 7: Create Narration Style, Prototypes, Methodology, and Examples

**Files:**
- Rewrite: `creator/templates/narration/style.md` (34 lines → ~120 lines)
- Create: `creator/templates/narration/script-prototypes.md`
- Create: `creator/templates/narration/methodology.md`
- Create: `creator/templates/narration/references/style-examples.md`

- [ ] **Step 1: Create references directory**

```bash
mkdir -p creator/templates/narration/references
```

- [ ] **Step 2: Rewrite `style.md`**

Replace `creator/templates/narration/style.md` entirely. **Critical migration note**: the current file recommends `——` for asides (line 19). This MUST be replaced with `...` or comma.

Structure:

```markdown
# 口播写作风格

> 基于「数字生命卡兹克」写作体系，适配口播/演讲脚本格式。
> 通用禁用规则见 `../../writing-engine/forbidden-words.md`
> 修辞技巧库见 `../../writing-engine/rhetoric.md`

## 核心价值观

同公众号。在口播场景下的体现：
- 好奇心 → 开头 5 秒必须抓住听众
- 讲人话 → 比文字更口语，允许更多语气词和自然停顿
- 真诚 → 声音传递情绪更直接，假的更容易被听出来

## 风格适配

相比公众号长文，口播脚本的关键差异：
- **更多语气词**：允许"嗯"、"对"、"你知道吗"等自然语气词（但不啰嗦）
- **呼吸节奏**：句子长度要适合朗读，自然断句处留停顿
- **反问更重**：口头反问比书面更有力，多用
- **情绪强度更高**：口播能承载更强烈的情绪表达
- **停顿标记**：用 `...` 表示戏剧性停顿，**不用** `——`（禁止）
- **直接称呼**：更频繁使用"你知道吗"、"想象一下"、"听我说"
- **无标题**：脚本连贯流动，不需要 heading

## 格式规范

- 每个 talking point 一段
- 主要节拍之间空行
- 不用 headers（这是脚本不是文章）
- 可选：`[pause]` 标记 TTS 停顿
- 可选：`[emphasis: 词]` 标记重读
- 短口播 300-800 字，长口播 800-2000 字

## 禁用规则

参考 `../../writing-engine/forbidden-words.md`（全部适用，很多禁用词说出来同样难听）。

口播额外规则：
- 不用过长的从句（听众无法回看）
- 信息点分散到多个节拍，不要信息轰炸
- 列表不超过 3 项（超过就转成叙述）

## 推荐口语化词组

比公众号更偏口语的表达：
- 转场："说到这个"、"我跟你说"、"你想想看"
- 判断："我是真的觉得"、"坦率的讲"
- 自嘲："说实话我也不确定"、"愚钝如我"
- 情绪："太离谱了"、"我当时就愣住了"、"你敢信"

## Review Thresholds

- L2-2 一句话独立成段最少出现次数：N/A（口播无段落概念）
- L2-3 不同口语化表达最少使用数量：8+
- L2-3 情绪标点：可选（口播靠语气传递情绪，标点不是重点）
- L3-3 文化升维：可选（可跳过）
```

- [ ] **Step 3: Create `script-prototypes.md`**

Create `creator/templates/narration/script-prototypes.md`. **Original content**, informed by spec § 5.3:

```markdown
# 口播脚本原型

> 创作前先判断脚本属于哪种原型，决定节奏和节拍结构。

## 匹配启发

| 用户输入信号 | 推荐原型 |
|-------------|---------|
| 有个经历/故事想讲 | 故事型 |
| 想表达对某事的看法 | 观点输出型 |
| 要演示/教某个操作 | 教程演示型 |
| 某个话题很火，想聊聊 | 热点解读型 |

## 1. 故事型 (Story)
**核心**："你听我说发生了什么"
**节拍**：设置场景 → 遭遇问题/好奇 → 行动+挫折 → 意外发现 → 感悟
**节奏**：英雄之旅弧线，适配口语
**典型开头**："故事是这样的"、"前两天发生了一件事"
**L3-5 专项**：是否有真实细节？过程是否有起伏？

## 2. 观点输出型 (Opinion)
[similar structure per spec § 5.3]

## 3. 教程演示型 (Tutorial)
[similar structure]

## 4. 热点解读型 (Trending Topic)
[similar structure]
```

- [ ] **Step 4: Create `methodology.md`**

Create `creator/templates/narration/methodology.md`. **Adapted from khazix** per spec § 5.3:

```markdown
# 口播内容方法论

> 选题辅助框架。口播选题逻辑与文字内容不同。

## 选题原则

口播的本质是声音传递信息。适合口播的话题：
- 故事 > 抽象概念（听众需要画面感）
- 情感 > 数据（声音传递情感更直接）
- 一个核心观点 > 多个散点（听众无法回看）

## HKR 质检

R（Resonance）权重最高 — 口播必须在情感上命中。
H（Happy）次之 — 话题要有趣，能让人听下去。
K（Knowledge）辅助 — 有信息量加分，但不是口播的核心竞争力。

## 长度指引

- 短口播（300-800 字）：1 个核心观点，2-3 个支撑点
- 长口播（800-2000 字）：完整叙事弧或 3-4 个 talking points
```

- [ ] **Step 5: Create `references/style-examples.md`**

Create `creator/templates/narration/references/style-examples.md`. **Original content** with ~80 lines:

```markdown
# 口播风格示例库

## 好的脚本开头 vs 坏的

**好**：
> 故事是这样的。前两天我在淘宝上搜了一下 DeepSeek... [pause] 然后我整个人都不好了。

**坏**：
> 大家好，今天我想跟大家深入探讨一下 DeepSeek 的市场现象。

[3-4 more pairs]

## 口语化转场示例

> "说到这个，我突然想到一件事..."
> "你想想看，如果你是那个人..."
> "回到刚才说的那个点..."

[6-8 transition examples]

## 朗读节奏示例

标注停顿和重读：

> 我当时就 [pause] 愣住了。
> 这个世界 [emphasis: 终于] 魔幻到我看不懂的程度了。
> 太离谱了... [pause] 你敢信？

[4-6 rhythm examples with markers]
```

- [ ] **Step 6: Verify cross-references**

Read the newly created `style.md` and confirm:
- References to `../../writing-engine/forbidden-words.md` exist
- References to `../../writing-engine/rhetoric.md` exist
- The "Review Thresholds" section is present with correct values per spec § 4.3

- [ ] **Step 7: Commit**

```bash
git add creator/templates/narration/style.md creator/templates/narration/script-prototypes.md creator/templates/narration/methodology.md creator/templates/narration/references/style-examples.md
git commit -m "feat(narration): rewrite style, add prototypes, methodology, and examples"
```

---

## Task 8: Update Platform Templates (WeChat, Xiaohongshu, Narration)

**Files:**
- Modify: `creator/templates/wechat/template.md`
- Modify: `creator/templates/xiaohongshu/template.md`
- Modify: `creator/templates/narration/template.md`

- [ ] **Step 1: Update WeChat `template.md`**

Edit `creator/templates/wechat/template.md`. Changes:

1. **Before Step 2 (Generate Outline)**, add a new step:

```markdown
### 1.5. Load Writing Context

Before writing, read and internalize:
- `../../writing-engine/forbidden-words.md` — 禁用词表
- `../../writing-engine/rhetoric.md` — 修辞技巧库
- `style.md` — 公众号风格规则
- `article-prototypes.md` — 使用 Step 3a 中用户选定的文章原型的叙事结构

Apply the prototype's narrative arc when generating the outline.
```

2. **After Step 3 (Write Article)**, add a new step:

```markdown
### 3.5. Self-Review Loop

Execute the L1-L4 quality review per `../../writing-engine/quality-review.md`.

1. Run L1 (forbidden words scan against `../../writing-engine/forbidden-words.md`). Auto-fix any hits.
2. Run L2 (style consistency against `style.md` § Review Thresholds). Auto-fix any failures.
3. Run L3 (content quality, including L3-5 prototype-specific checks from `article-prototypes.md`). Auto-fix any failures.
4. Run L4 (aliveness review). Auto-fix any failures.

If any layer fails, auto-fix and re-run from L1. Maximum 3 full iterations.
If all layers pass: proceed silently to Step 4.
If cap hit: show user the cap-hit report per `../../writing-engine/quality-review.md` and await decision.
```

3. Keep all other steps (4-8) unchanged.

- [ ] **Step 2: Update Xiaohongshu `template.md`**

Edit `creator/templates/xiaohongshu/template.md`. Same pattern:

1. **Before Step 4 (Generate Content Plan)**, add:

```markdown
### 3.5. Load Writing Context

Before writing, read and internalize:
- `../../writing-engine/forbidden-words.md`
- `../../writing-engine/rhetoric.md`
- `style.md`
- `content-prototypes.md` — 使用 Step 3a 中用户选定的内容原型

Apply the prototype's narrative structure when planning content.
```

2. **After Step 5 (Write Long Text)**, add self-review step (same structure as WeChat, but references `content-prototypes.md` instead of `article-prototypes.md`, and uses xiaohongshu review thresholds from `style.md`).

   **Mode-dependent placement:**
   - If mode is `"long-text"` only or `"both"`: self-review goes after Step 5 (Write Long Text)
   - If mode is `"cards"` only: self-review applies to card copy text and goes after Step 6 (Design Card Prompts)

3. Keep all other steps unchanged.

- [ ] **Step 3: Update Narration `template.md`**

Edit `creator/templates/narration/template.md`. Same pattern:

1. **Before Step 2 (Generate Script)**, add:

```markdown
### 1.5. Load Writing Context

Before writing, read and internalize:
- `../../writing-engine/forbidden-words.md`
- `../../writing-engine/rhetoric.md`
- `style.md`
- `script-prototypes.md` — 使用 Step 3a 中用户选定的脚本原型

Apply the prototype's beat structure when writing the script.
```

2. **After Step 2 (Generate Script)**, add self-review step (references `script-prototypes.md`, narration review thresholds).

3. Keep all other steps unchanged.

- [ ] **Step 4: Verify all three templates reference writing-engine correctly**

For each of the 3 updated templates, verify:
- Path `../../writing-engine/forbidden-words.md` is correct relative to `templates/{platform}/template.md`
- Path `../../writing-engine/rhetoric.md` is correct
- Path `../../writing-engine/quality-review.md` is correct
- Prototype file reference matches the platform's actual prototype file name

- [ ] **Step 5: Commit**

```bash
git add creator/templates/wechat/template.md creator/templates/xiaohongshu/template.md creator/templates/narration/template.md
git commit -m "feat(templates): add writing-engine references and self-review loop to all platforms"
```

---

## Task 9: Update SKILL.md

**Files:**
- Modify: `creator/SKILL.md`

- [ ] **Step 1: Add Step 2.5 (Topic Assistance)**

Insert after the existing "### Step 2: Template Matching" section (after line ~143) and before "### Step 3: Style Extraction":

```markdown
### Step 2.5: Topic Assistance

This step runs only when the user's input is a topic or keywords (short text <50 chars, no URL/path). Skip if user provided a URL, file, or substantial text.

1. Read the selected platform's `methodology.md`:
   - WeChat: `creator/templates/wechat/methodology.md`
   - Xiaohongshu: `creator/templates/xiaohongshu/methodology.md`
   - Narration: `creator/templates/narration/methodology.md`

2. Evaluate the topic using the three-circle Venn model:
   - 用户的专业领域 (creator's expertise)
   - 读者的普遍兴趣 (reader interest)
   - 当下的时间节点 (current timing/relevance)

3. Run HKR quality filter:
   - **H (Happy)**: 足够有趣、有悬念？
   - **K (Knowledge)**: 有信息量？看完能学到新东西？
   - **R (Resonance)**: 能戳中情绪？让人"对对对我也这么想"？

4. If topic scores ≥2 of 3 HKR criteria: proceed with the topic.
5. If topic scores <2: proactively suggest 2-3 alternative angles to the user via AskUserQuestion.
6. If topic is vague: ask for more specifics — key points, personal experiences, what excites or frustrates them.
```

- [ ] **Step 2: Add Step 3a (Prototype Classification)**

Insert after the existing "### Step 3: Style Extraction" section and before "### Step 3b: Preset Selection":

```markdown
### Step 3a: Prototype Classification

Read the selected platform's prototype file:
- WeChat: `creator/templates/wechat/article-prototypes.md`
- Xiaohongshu: `creator/templates/xiaohongshu/content-prototypes.md`
- Narration: `creator/templates/narration/script-prototypes.md`

Based on the user's material/topic, auto-match the best-fit prototype using the matching heuristics table in the prototype file.

Present the recommendation to the user via AskUserQuestion:

Question: "这篇内容最适合哪种写法？" / "Which content prototype fits best?"
Options: [list all prototypes for the platform, recommended one first with "(Recommended)" suffix]

The selected prototype determines the narrative structure and L3-5 review criteria for writing.
```

- [ ] **Step 3: Update Step 4 confirmation summary**

In the existing Step 4 confirmation summary template, add a line for the selected prototype:

```
  文章/内容原型：{selected prototype name}
```

Add this after the "配图/卡片预设" line in the confirmation summary. This line is always present for all platforms (WeChat, Xiaohongshu, Narration).

- [ ] **Step 4: Update Step 5 description**

In the existing "### Step 5: Execute Pipeline" section, add a note after "Then follow the platform template":

```markdown
**Writing engine integration:** Each platform's `template.md` now includes writing-engine references and a self-review loop. The template handles loading `writing-engine/` files, applying the selected prototype's narrative structure, and running L1-L4 quality review after writing. See each platform's `template.md` for details.
```

- [ ] **Step 5: Verify the SKILL.md step numbering is consistent**

Read through the full SKILL.md and confirm:
- Step 2.5 is between Step 2 and Step 3
- Step 3a is between Step 3 and Step 3b
- Step 4 summary includes the prototype field
- Step 5 references the writing engine

- [ ] **Step 6: Commit**

```bash
git add creator/SKILL.md
git commit -m "feat(creator): add topic assistance (Step 2.5) and prototype classification (Step 3a)"
```

---

## Task 10: Cross-Reference Verification

**Files:** All created/modified files

- [ ] **Step 1: Verify writing-engine file references**

Check that every file path referenced in templates and SKILL.md actually exists:

```bash
# From creator/ directory:
ls writing-engine/forbidden-words.md
ls writing-engine/rhetoric.md
ls writing-engine/quality-review.md
ls writing-engine/ai-human-boundary.md
ls templates/wechat/article-prototypes.md
ls templates/wechat/methodology.md
ls templates/wechat/references/style-examples.md
ls templates/xiaohongshu/content-prototypes.md
ls templates/xiaohongshu/methodology.md
ls templates/xiaohongshu/references/style-examples.md
ls templates/narration/script-prototypes.md
ls templates/narration/methodology.md
ls templates/narration/references/style-examples.md
```

All must exist. If any is missing, identify which task failed to create it.

- [ ] **Step 2: Verify no forbidden words leaked into style examples**

Spot check that the style-examples files don't use forbidden words outside of quoted examples. The forbidden words should only appear inside `>` blockquotes (as bad examples) or inside comparison tables.

```bash
# Quick scan for top forbidden words in non-quoted lines
grep -n "说白了\|本质上\|不可否认\|综上所述" creator/templates/*/style.md creator/templates/*/methodology.md
```

Expected: zero hits (these words should not appear in instructional text).

- [ ] **Step 3: Verify Review Thresholds are present in all platform style.md files**

```bash
grep -l "Review Thresholds" creator/templates/*/style.md
```

Expected: 3 files (wechat/style.md, xiaohongshu/style.md, narration/style.md).

- [ ] **Step 4: Verify template.md files reference writing-engine**

```bash
grep -l "writing-engine" creator/templates/*/template.md
```

Expected: 3 files.

- [ ] **Step 5: Verify SKILL.md has new steps**

```bash
grep -c "Step 2.5\|Step 3a" creator/SKILL.md
```

Expected: at least 2 (one for each new step header).

- [ ] **Step 6: Final commit if any fixes were needed**

If any verification step found issues and fixes were applied:

```bash
git add -A creator/
git commit -m "fix(writing-engine): cross-reference verification fixes"
```

If all checks passed with no changes needed, skip this step.
