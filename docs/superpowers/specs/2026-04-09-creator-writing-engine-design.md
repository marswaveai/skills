# Creator Writing Engine — Design Spec

**Date**: 2026-04-09
**Scope**: Deep integration of khazix-writer methodology into the creator skill's writing pipeline across all three platforms (WeChat, Xiaohongshu, Narration).
**Reference**: `~/coding/khazix-skills/khazix-writer/` — 数字生命卡兹克的公众号写作 skill

---

## 1. Problem Statement

The creator skill has strong production infrastructure (content extraction, image generation, TTS, pipeline orchestration) but thin writing guidance. The WeChat `style.md` is 31 lines of generic advice ("Authoritative yet accessible"), the Xiaohongshu `style.md` is 36 lines, and narration `style.md` is 34 lines. None has article/content type classification, quality review systems, forbidden word lists, or concrete rhetorical techniques.

The khazix-writer skill is the opposite — 981 lines of deeply codified writing wisdom with a 4-layer quality review system, 5 article prototypes, 27+ forbidden words with replacements, 19 rhetorical techniques with examples, and before/after comparisons. But it has no production pipeline (no images, no TTS, no multi-platform support).

**Goal**: Merge khazix-writer's writing brain into creator's production body. Full adoption of khazix's style as the default voice across all platforms, adapted to each platform's format.

---

## 2. Architecture: Shared Writing Engine + Platform Specialization

### File Structure

```
creator/
├── SKILL.md                              # Updated pipeline (new steps)
├── writing-engine/                       # Cross-platform writing capabilities
│   ├── quality-review.md                 # L1-L4 self-review pyramid
│   ├── forbidden-words.md                # Forbidden words + replacements
│   ├── rhetoric.md                       # 19 rhetorical techniques + examples
│   └── ai-human-boundary.md              # AI/human collaboration boundary
│
├── templates/wechat/
│   ├── template.md                       # Rewritten pipeline (new steps)
│   ├── style.md                          # Rewritten: khazix full style rules
│   ├── methodology.md                    # New: topic selection framework
│   ├── article-prototypes.md             # New: 5 article prototypes
│   ├── references/style-examples.md      # New: before/after comparisons
│   └── presets/                          # Unchanged (flat, watercolor, photo-realistic)
│
├── templates/xiaohongshu/
│   ├── template.md                       # Updated pipeline (self-review loop)
│   ├── style.md                          # Rewritten: khazix style adapted for short-form
│   ├── methodology.md                    # New: xiaohongshu topic selection
│   ├── content-prototypes.md             # New: xiaohongshu content types
│   ├── references/style-examples.md      # New: platform-specific examples
│   └── presets/                          # Unchanged (10 presets)
│
└── templates/narration/
    ├── template.md                       # Updated pipeline (self-review loop)
    ├── style.md                          # Rewritten: khazix style adapted for spoken word
    ├── methodology.md                    # New: narration topic selection
    ├── script-prototypes.md              # New: narration script types
    └── references/style-examples.md      # New: platform-specific examples
```

### Layer Separation

- **`writing-engine/`** = universal rules shared by all platforms (forbidden words, rhetorical techniques, quality review framework, AI/human collaboration boundaries)
- **Platform `style.md`** = khazix's voice adapted to that platform's format (long-form article vs. short cards vs. spoken script)
- **Platform `*-prototypes.md`** = content type taxonomy specific to that platform
- **Platform `methodology.md`** = topic selection logic specific to that platform
- **Platform `references/`** = concrete examples specific to that platform

### Reference Direction

- Each platform's `template.md` references `../../writing-engine/` for shared capabilities
- Shared files never reference platform files (dependency flows one way)
- Platform files complement but do not duplicate shared files

---

## 3. Pipeline Modifications

This section describes the conceptual pipeline. Section 6 maps these onto exact SKILL.md step numbers.

### Current Conceptual Pipeline (per-platform template)

```
Prepare Material → Generate Outline → Write Content → Select Preset → Plan Illustrations → Generate Images → Insert Images → Write meta.json
```

### New Conceptual Pipeline

```
Prepare Material → [Topic Assistance] → [Prototype Classification] → Generate Outline → Write Content → [Self-Review Loop] → Select Preset → Plan Illustrations → Generate Images → Insert Images → Write meta.json
```

Three new steps marked with `[]`. All three are pre-confirmation interactive steps (require user input via AskUserQuestion), except the Self-Review Loop which runs silently during pipeline execution.

### Topic Assistance (maps to SKILL.md Step 2.5)

**Triggers when**: User input is a topic/keywords (not existing material/URL).
**Skips when**: User provides a URL, file, or substantial text.

Process:
1. Apply the platform's `methodology.md` topic selection framework
2. Evaluate using the three-circle Venn model: creator's expertise ∩ reader interest ∩ current timing/relevance (adapted from khazix's "当下的时间节点")
3. Run HKR quality filter:
   - **H (Happy)**: Interesting enough? Creates curiosity?
   - **K (Knowledge)**: Has information value? Reader learns something?
   - **R (Resonance)**: Hits an emotion? "Yes, I think so too"?
4. S-tier topics have all three. Passing requires at least two. If topic scores only one or zero, proactively suggest 2-3 alternative angles to the user.
5. If topic is vague, ask user for more specifics: key points, personal experiences, what excites or frustrates them about the topic.

### Prototype Classification (maps to SKILL.md Step 3a)

**Applies to all platforms** (different prototype sets per platform). Happens before the confirmation gate since it requires user interaction.

Process:
1. Read platform's `*-prototypes.md`
2. Auto-match the best-fit prototype based on material/topic using matching heuristics (see below)
3. Present the recommended prototype with rationale to user via AskUserQuestion
4. User confirms or selects a different prototype
5. The selected prototype determines the narrative structure used in writing

**Matching heuristics** (WeChat article prototypes as example — each platform defines its own):
- **调查实验型**: user mentions testing, trying, buying, or doing something hands-on
- **产品体验型**: user provides a specific product/tool to review or demo
- **现象解读型**: user describes a trend, observation, or "why is X happening"
- **工具分享型**: user has a specific tool/prompt to recommend
- **方法论分享型**: user wants to share accumulated knowledge, tips, or "N lessons learned"

### Self-Review Loop (runs inside SKILL.md Step 5, after writing)

After writing is complete, automatically execute the L1→L4 quality review:

```
Write Content
  ↓
L1: Hard Rules Scan (forbidden words, forbidden punctuation, structural anti-patterns, vague tool names)
  ├─ FAIL → auto-fix → re-run L1
  └─ PASS ↓
L2: Style Consistency (opening hook, rhythm, colloquialism frequency, punctuation patterns)
  ├─ FAIL → auto-fix → re-run L1+L2
  └─ PASS ↓
L3: Content Quality (argument support, knowledge delivery, cultural reference, empathy, type-specific checks)
  ├─ FAIL → auto-fix → re-run L1-L3
  └─ PASS ↓
L4: "Aliveness" Review (temperature, uniqueness, voice/posture, flow)
  ├─ FAIL → auto-fix → re-run all
  └─ PASS → proceed to preset selection
```

**Iteration cap**: Maximum 3 full iterations. If L4 still fails after 3 rounds, output the best version with a quality report, let user decide whether to accept.

**The review does NOT produce a visible report to the user.** The loop runs silently. The user receives the final, quality-passed article. If the cap is hit, only then does the user see a brief report in this format:

```
⚠️ 质量审查未完全通过（3轮迭代后）

未通过项：
- L4-1 温度感：第3-4段情绪表达偏知识性描述
- L3-3 文化升维：未找到自然的文化/哲学连接点

已输出当前最佳版本。你可以：
1. 接受现状，继续生成配图
2. 手动修改上述段落后继续
```

---

## 4. Writing Engine Files

### 4.1 `writing-engine/forbidden-words.md`

Extracted and organized from khazix-writer's "绝对禁区". Categorized for easy scanning:

**Forbidden vocabulary** (each with replacement):

| Forbidden | Why | Replace with |
|-----------|-----|-------------|
| 说白了 | AI marker, extremely common in AI output | 坦率的讲、其实就是 |
| 这意味着 / 意味着什么 | AI-signature phrasing | 那结果会怎样呢、所以呢 |
| 本质上 | Too academic | 说到底、其实 |
| 换句话说 | Too formal | 你想想看、也就是说 |
| 不可否认 | Filler, add nothing | Delete, reframe as positive assertion |
| 综上所述 / 总的来说 | Summary cliche | Use a specific callback sentence |
| 首先...其次...最后 | Kills rhythm, telegraphs structure | Use natural transition phrases |
| 值得注意的是 / 不难发现 | Empty preamble | Delete, just say it |
| 深入探讨 / 全面分析 | Hollow modifiers | Delete, go directly into the substance |
| 让我们来看看 / 接下来让我们 | Textbook phrasing | Use conversational transitions |
| 在当今...的时代 / 随着...的发展 | AI-typical opening cliche | Cut entirely, start with a concrete event |

**Forbidden punctuation**:

| Forbidden | Why | Replace with |
|-----------|-----|-------------|
| ： (colon) | Overly formal, creates report-like structure | Comma, or restructure sentence |
| —— (em-dash) | Same | Comma or period |
| "" or "" (double quotes, curly or straight) | Formal feel | 「」 or no quotes at all |

**Structural anti-patterns**:
- More than 3 consecutive bullet points → convert to prose narrative
- Bold text spanning more than 2 lines → over-structured, break up
- Markdown headers in article body → use conversational transitions instead (exception: numbered methodology articles)

**Vague tool names**: Never write "AI工具", "某个模型", "相关技术". Always use specific names (Claude Code, Codex, Seedance 2.0, etc.).

### 4.2 `writing-engine/rhetoric.md`

19 techniques extracted from khazix-writer, each with: one-line definition, when to use, 1-2 concrete examples.

1. **契诃夫之枪 (Chekhov's Gun)** — Plant a detail early, pay it off later. Creates a sense of completeness. Best for long-form.
2. **升番逻辑 (Escalation)** — Like sketch comedy escalation: each example tops the previous one. Most powerful placement is last. Best for product comparisons, tool tests.
3. **人物压缩法 (Persona Compression)** — Transform a data point into a concrete person in 3-5 sentences: trigger data → quick persona → multi-dimensional stacking → emotional anchor → concrete detail.
4. **知识随口丢 (Casual Knowledge Drop)** — Sound like you just remembered something, not like you researched it. "突然想起了以前做交互设计的时候" not "下面我来科普".
5. **逻辑断裂 (Logic Break)** — Insert colloquial interruptions into formal arguments to create warmth. Repetition, trailing off, dropping subjects.
6. **反向论证 (Reverse Argument)** — Fulfill the reader's expectation, then break it. "You think it'd be complex? It's just copy-paste."
7. **文化升维 (Cultural Elevation)** — Connect a concrete tech topic to a larger cultural/philosophical reference. Must feel like "I just thought of this" not "let me educate you".
8. **句式断裂 (Sentence Fracture)** — Ultra-short sentence or phrase as its own paragraph for weight. "黑暗森林。" Use sparingly at emotional peaks.
9. **层层剥开 (Layer Peeling)** — Not direct conclusions. Phenomenon → surface explanation → deeper question → core insight. Reader participates in the thinking process.
10. **谦逊铺垫 (Humble Preface)** — Before giving advice, lower the reader's defenses with genuine uncertainty. "我也不知道行不行" "不成熟的经验".
11. **读者直呼 (Reader Direct Address)** — At key moments, talk directly to reader. "屏幕前的你" "你相信我". Precision deployment, not constant use.
12. **疑问节奏 (Question Rhythm)** — Use questions as "brakes and turns". Makes reader pause before new information. "为啥复制一遍，会有效果呢？"
13. **对立面承认 (Opposing View Acknowledgment)** — Before your point, fully articulate the opposing position with empathy. Makes your eventual point far more persuasive.
14. **英雄之旅 (Hero's Journey)** — Mundane problem → curiosity/call → execution with setbacks → surprising discovery. Reader feels they experienced it too.
15. **亲自下场 (Hands-On Reporting)** — Not imagining, but doing. The detail must be real and specific enough that fabrication would be obvious.
16. **创意案例包装 (Creative Case Packaging)** — Challenge → idea → process → mind-blowing result. Micro-story structure for product demos.
17. **逐一展示 + 吐槽 (Sequential Showcase + Commentary)** — Don't list conclusions; show each case one by one with commentary. Each gets its own mini-reaction.
18. **坦诚学习曲线 (Honest Learning Curve)** — In methodology articles, don't just paint the success picture. Acknowledge initial awkwardness, time cost, common failure points.
19. **幽默写法 (Humor Methods)** — Absurd metaphor ("我家小龙虾是镀金的吗"), classic line adaptation, roast-style commentary. Humor flows from precise capture of absurd reality, not forced jokes.

### 4.3 `writing-engine/quality-review.md`

The L1-L4 quality pyramid, directly adopted from khazix-writer with the following adaptations:

- Framework is platform-agnostic (the 4-layer structure applies everywhere)
- Specific checks within each layer can vary by platform (referenced via platform `style.md` and `*-prototypes.md`)
- The iteration logic (auto-fix → re-run) is defined here
- The iteration cap (3 rounds) is defined here
- Output format (silent pass or quality report on cap-hit) is defined here
- Each platform's `style.md` includes a "Review Thresholds" section with adjusted numeric values

**Platform-specific threshold overrides**:

| Check | WeChat (long-form) | Xiaohongshu (short-form) | Narration (spoken) |
|-------|--------------------|--------------------------|--------------------|
| L2-2 single-sentence paragraphs min | 3 | 2 | N/A (no paragraphs) |
| L2-3 colloquial expressions min | 8-10 different | 4-6 different | 8+ different |
| L2-3 emotional punctuation | required (at least 1) | optional | optional |
| L3-3 cultural elevation | required | optional (skip OK) | optional (skip OK) |
| L3-5 prototype-specific | per article-prototypes.md | per content-prototypes.md | per script-prototypes.md |

**L1 — Hard Rules (Automated Scan)**:
Checks against `forbidden-words.md`. Binary pass/fail. Zero tolerance.
- L1-1: Forbidden vocabulary scan
- L1-2: Forbidden punctuation scan
- L1-3: Structural anti-pattern scan (consecutive bullets, excessive bold, textbook openings)
- L1-4: Vague tool name check

Pass criteria: Zero hits across all four sub-checks.

**L2 — Style Consistency (Pattern Matching)**:
Checks against platform `style.md` patterns. Threshold pass.
- L2-1: Opening check — concrete event/scene opening, creates "then what?" impulse, no textbook opening
- L2-2: Rhythm & structure — long/short sentence alternation, single-sentence paragraphs (min 3 occurrences), "anchor to main thread" sentences after digressions, question-based rhythm breaks, no unnecessary markdown headers (per platform rules)
- L2-3: Colloquialism check — recommended phrases used (min 8-10 different colloquial expressions in WeChat long-form, proportionally less for shorter formats), deliberate logic breaks, at least one self-deprecation or admission of uncertainty, emotional punctuation ("。。。", "？？？", "= =")
- L2-4: Forbidden punctuation re-confirmation (AI tends to reintroduce these during revision)

Pass criteria: L2-1 all pass, L2-2 at least 3/4, L2-3 at least 3/4, L2-4 pass.

**L3 — Content Quality (Deep Review)**:
Checks content depth and persuasiveness. Contextual pass.
- L3-1: Argument support — every core argument has concrete person/scene/detail/data backing
- L3-2: Knowledge delivery — presented as "happened to remember" not "let me teach you"
- L3-3: Cultural elevation — at least one connection to larger cultural/philosophical/historical reference, feels natural
- L3-4: Opposing view & empathy — shows understanding of the other side before presenting own view
- L3-5: Prototype-specific checks (varies by article/content/script prototype selected in Step 3a)
- L3-6: Sequential showcase check — if comparing multiple products/cases, uses one-by-one with commentary, not summary listing

Pass criteria: L3-1 and L3-2 must pass. L3-3 through L3-6 pass for applicable items (some skip depending on content type).

**L4 — "Aliveness" Review (Final Personality Check)**:
Core question: "Does this read like a thoughtful person genuinely sharing something that moved them, or like an AI outputting information?"
- L4-1: Temperature — emotional expressions are somatic memories ("我当时就愣住了") not knowledge descriptions ("我感到非常震撼")
- L4-2: Uniqueness — does this article have an angle that only this voice would produce?
- L4-3: Posture — is the voice "an informed regular person earnestly discussing something that moved them"? Not a teacher lecturing or a brand marketing.
- L4-4: Flow — can you read start to finish without your attention breaking? Any point where you need to re-read for logic?

Pass criteria: Overall assessment "this reads like a real person wrote it". Any section that feels AI-heavy requires rework.

### 4.4 `writing-engine/ai-human-boundary.md`

Directly adopted from khazix-writer § 第二步.

**AI excels at (delegate freely)**:
- Finding evidence, counter-arguments, and supporting examples
- Finding analogies and metaphors for abstract concepts
- Expanding from established angles (when user has already set the direction and section headings)
- Providing academic/historical background knowledge
- Suggesting logical restructuring

**Only humans can do (will expose AI if fabricated)**:
- First-hand observations and real experiences (buying 9.9 DeepSeek, personally testing tools)
- The core creative angle (the "aha" moment that makes the article stand)
- Authentic emotional expression (somatic memory, not knowledge description)
- Data-to-person empathy translation (imagining the real person behind a number)

**Ideal collaboration flow**:
```
Human: material + core viewpoint + personal experience + emotional beats
  ↓
AI: background knowledge + evidence/analogies + structure suggestions + expand from angles
  ↓
Human: second pass (inject own voice, break rhythm, add real details)
  ↓
AI: run L1-L4 review → output revision suggestions
  ↓
Human: final review and approval
```

This file is informational. It helps users understand that providing more specific, first-hand material yields dramatically better output.

---

## 5. Platform-Specific Content

### 5.1 WeChat (公众号)

**`style.md`** (complete rewrite ~200 lines):
Full khazix style ruleset for long-form articles:
- Core values: curiosity, speak like a real person, sincerity is the only shortcut, selective about what to write
- Rhythm: like chatting with a friend, sentence length varies, paragraphs jump naturally, single-sentence paragraphs for emphasis, "anchor to main thread" sentences
- Deliberate logic breaks in formal arguments (repetition, trailing off, dropping subjects)
- Knowledge delivery as "casual drop" not "let me teach you"
- Private perspective: "I also face this problem" not "the lesson for us is"
- Judgment: bold opinions, but expressed as "I was moved" not "let me evaluate"
- Opposing view acknowledgment before own viewpoint
- Emotional expression: "。。。" for drawn-out tone, self-deprecation, "？？？" for extreme surprise
- Hands-on reporting as core gene
- Persona compression for data-to-human conversion
- Cultural elevation at article end
- Sentence fracture for weight at key points
- Recommended colloquial phrases (transitions, judgments, admissions, emotions, rapport, verbal tics)
- Opening templates (4 types: narrative, absurd fact, trending topic, curiosity-driven)
- Closing templates (5 types: quote, philosophical, CTA, belief declaration, callback)
- Fixed footer template (以上...三连...星标...谢谢你看我的文章)
- Format: 4000-8000 characters, short paragraphs, no markdown headers (use conversational transitions), important points get breathing room

**`article-prototypes.md`** (~100 lines):
5 article prototypes with distinct narrative structures:
1. **调查实验型** (Investigation/Experiment) — "I went and did this for you". Process narrative + layer-by-layer discovery.
2. **产品体验型** (Product Experience) — "Come play with me". Scenario-driven + genuine reactions + natural comparison with other products.
3. **现象解读型** (Phenomenon Interpretation) — "Did you notice this? What's behind it?" Observation → curiosity → research → philosophical elevation.
4. **工具分享型** (Tool Sharing) — "I found something great". Personal story framing → natural tool introduction → usage process → wow result.
5. **方法论分享型** (Methodology) — "I'm giving you my best stuff". Every section has executable action + honest learning curve + failure points + humble preface to disarm arrogance.

Each prototype includes: core narrative arc, paragraph allocation guidance, typical opening approach, specific L3-5 review criteria.

**`methodology.md`** (~80 lines):
- Three-circle Venn topic selection: creator's expertise ∩ reader interest ∩ current timing/relevance (from khazix's "你的专业领域 + 读者的普遍兴趣 + 当下的时间节点")
- HKR quality filter (Happy/Knowledge/Resonance)
- Role-based empathy check (busy user / playful friend / anxious learner)
- Topic sources: Twitter, Reddit, Xiaohongshu, Jike, Weibo/Douyin/Bilibili, reader communities
- 3 business categories with example titles: LLM tech, AIGC art, internet culture
- Content type taxonomy: product review, tutorial, phenomenon analysis, opinion, AI experiments

**`references/style-examples.md`** (~300 lines):
Adapted from khazix-writer's `style_examples.md`:
- Opening examples by type (4 types, 8+ examples)
- Transition phrase examples (good vs. bad)
- Knowledge casual drop examples (good vs. bad)
- Self-deprecation and vulnerability examples
- Hands-on reporting examples
- Persona compression examples
- Cultural elevation examples
- Sequential showcase examples
- Sentence fracture examples
- Humor examples
- Closing examples by type
- AI draft vs. khazix revision comparisons (4 pairs with delta analysis)

### 5.2 Xiaohongshu (小红书)

**`style.md`** (complete rewrite from scratch ~120 lines, not a patch on existing):
khazix style adapted for short-form content:
- Same core values (curiosity, sincerity, speak human)
- Compressed rhythm: denser information per sentence, shorter paragraphs (1-2 sentences)
- Colloquial phrases preserved but adapted for brevity
- Emotional punctuation still used but with more restraint
- Internet slang OK but not forced
- Strategic emoji (1-2 per paragraph max, as visual punctuation)
- Card text rules: bold statements, one key point per card, under 10 chars per line
- Long-text structure: hook title with number/emotional hook, punchy paragraphs, 3-5 hashtags
- Still uses forbidden words list from writing-engine (applies universally)

**`content-prototypes.md`** (~80 lines):
Xiaohongshu content types (adapted from article prototypes):
1. **种草测评 (Recommendation Review)** — Genuine product experience + verdict. "I tried it so you don't have to."
2. **干货清单 (Knowledge Listicle)** — N items, each a nugget. "5个让你效率翻倍的AI工具"
3. **踩坑避雷 (Pitfall Warning)** — "Don't make my mistake". Pain → lesson → alternative.
4. **对比横评 (Comparison)** — Multiple products head-to-head. Sequential showcase with commentary.
5. **故事分享 (Story Sharing)** — Personal experience narrative. Compressed hero's journey.

Each includes: narrative structure, card density recommendation, typical hook patterns.

**`methodology.md`** (~50 lines):
- Xiaohongshu-specific topic selection: trending searches, comment section demand mining, seasonal content
- Adapted HKR filter: H (Happy/curiosity) still applies but Xiaohongshu also requires visual hook appeal as a separate factor — topics must be visually representable in card format
- Title engineering: numbers, emotional hooks, "绝绝子" "一定要看" patterns

**`references/style-examples.md`** (~100 lines):
- Good vs. bad card copy examples
- Long-text hook examples
- Condensed versions of key rhetorical techniques adapted for short form

### 5.3 Narration (口播)

**`style.md`** (complete rewrite from scratch ~120 lines, not a patch on existing):
khazix style adapted for spoken word:
- Same core values
- More filler words and natural hesitation OK (but cleaned up, not sloppy)
- Sentence rhythm optimized for reading aloud: natural breath points
- Rhetorical questions used more heavily (they work better spoken)
- Emotional intensity can be higher (spoken word carries it better than text)
- Pause markers: `...` for dramatic pauses, not `——` (forbidden)
- Direct reader address used more frequently (they're listeners now)
- No markdown headers (script flows continuously)
- Still uses forbidden words list (many forbidden words sound equally bad spoken)
- Colloquial phrases: heavier on spoken-word ones, lighter on text-specific ones

**`script-prototypes.md`** (~60 lines):
Narration script types:
1. **故事型 (Story)** — "Let me tell you what happened." Hero's journey adapted for spoken word.
2. **观点输出型 (Opinion)** — "Here's what I think." Bold claim → evidence → empathy for opposing view → conclusion.
3. **教程演示型 (Tutorial)** — "Watch me do this." Step-by-step with reactions and commentary.
4. **热点解读型 (Trending Topic)** — "Everyone's talking about X. Here's what they're missing."

Each includes: pacing guide, beat structure, typical opening hooks.

**`methodology.md`** (~40 lines):
- Narration topic selection: what topics work spoken (stories > abstractions, emotion > data)
- Adapted HKR (R is weighted higher — spoken word must land emotionally)
- Length guidance by format: 300-800 chars short-form, 800-2000 chars long-form

**`references/style-examples.md`** (~80 lines):
- Good vs. bad script openings
- Oral transition examples
- Spoken rhythm examples (with pause markers)

---

## 6. SKILL.md Modifications

The main `SKILL.md` is modified to integrate the new steps into the interaction flow. All new interactive steps happen before the confirmation gate (Step 4).

### Step 2.5 (New): Topic Assistance

Inserted after Step 2 (Template Matching), before Step 3 (Style Extraction):

- If input is topic/keywords (not URL/file/text), run the platform's `methodology.md` topic assistance
- If input is existing material, skip this step
- Uses the three-circle Venn model and HKR filter as defined in Section 3

### Existing Step 3 (Style Extraction)

No change to the style extraction step.

### Step 3a (New): Prototype Classification

Inserted between Step 3 (Style Extraction) and Step 3b (Preset Selection). Before the confirmation gate since it requires user interaction.

1. Read the platform's prototype file
2. Auto-match prototype based on material/topic using the matching heuristics defined in Section 3
3. Present recommendation to user via AskUserQuestion with rationale
4. User confirms or overrides
5. The selected prototype is displayed in the Step 4 confirmation summary

### Existing Step 3b (Preset Selection)

No change.

### Modified Step 5 (Execute Pipeline)

The writing step in each platform's `template.md` is modified:

1. **Before writing**: Load the prototype's narrative structure from `*-prototypes.md`
2. **During writing**: Apply style hierarchy (session > persisted > platform style.md) PLUS `writing-engine/` rules (forbidden words, rhetorical techniques). Each platform's template.md includes explicit instructions like: "Before writing, read and apply `../../writing-engine/forbidden-words.md` and `../../writing-engine/rhetoric.md`. After writing, execute the self-review loop per `../../writing-engine/quality-review.md`."
3. **After writing**: Run self-review loop (quality-review.md L1→L4, max 3 iterations, silent pass or cap-hit report). Load review files layer by layer: `forbidden-words.md` for L1, add `style.md` for L2, add `*-prototypes.md` for L3, holistic read for L4 — to manage context pressure.
4. **Then continue** to illustrations/images as before

### Other Steps

Steps 6-8 (Assemble Output, Present Result, Update Preferences) remain unchanged.

---

## 7. Adaptation Principles

khazix-writer was designed for WeChat long-form. Not everything transfers directly to other platforms:

### What transfers to all platforms (in `writing-engine/`)
- Forbidden words — AI-smell vocabulary sounds bad everywhere
- L1-L4 quality framework — the pyramid concept is universal
- AI/human collaboration boundary — applies regardless of platform
- Core rhetorical techniques — persona compression, casual knowledge drop, opposing view acknowledgment work in any format

### What needs platform adaptation
- **Chekhov's Gun** — works in 4000+ word articles, not in 500-char Xiaohongshu posts → WeChat only
- **Cultural elevation** — needs room to breathe, works in long-form → WeChat and long narration only
- **Sequential showcase** — works everywhere but scale differs (6 products in WeChat, 3-4 in Xiaohongshu cards)
- **Sentence fracture** — works in text (WeChat, Xiaohongshu), translates to dramatic pause in narration
- **Colloquial phrase frequency** — full density in WeChat (8-10 different phrases), moderate in Xiaohongshu (4-6), high in narration (8+, spoken word carries it)
- **L2 pass thresholds** — adjusted per platform (shorter content has proportionally lower minimums)
- **L3 cultural elevation** — required for WeChat, optional for Xiaohongshu and narration

### What's WeChat-only
- Fixed footer template (三连、星标、谢谢你看我的文章)
- No-markdown-headers rule (Xiaohongshu has its own card structure; narration has no headers by nature)
- 4000-8000 character target length

---

## 8. Migration Notes

### Files modified (existing)
- `creator/SKILL.md` — add Step 2.5 (Topic Assistance), Step 3a (Prototype Classification), modify Step 5 (writing with engine references + self-review loop)
- `creator/templates/wechat/template.md` — rewrite to reference writing-engine, add self-review step
- `creator/templates/wechat/style.md` — complete rewrite with khazix style
- `creator/templates/xiaohongshu/template.md` — update to reference writing-engine, add self-review step
- `creator/templates/xiaohongshu/style.md` — rewrite with adapted khazix style
- `creator/templates/narration/template.md` — update to reference writing-engine, add self-review step
- `creator/templates/narration/style.md` — rewrite with adapted khazix style. **Note**: current style.md recommends `——` for asides (line 19) which directly conflicts with the forbidden punctuation rule. Must be replaced with `...` or comma in the rewrite.

### Files created (new)
- `creator/writing-engine/quality-review.md`
- `creator/writing-engine/forbidden-words.md`
- `creator/writing-engine/rhetoric.md`
- `creator/writing-engine/ai-human-boundary.md`
- `creator/templates/wechat/methodology.md`
- `creator/templates/wechat/article-prototypes.md`
- `creator/templates/wechat/references/style-examples.md`
- `creator/templates/xiaohongshu/methodology.md`
- `creator/templates/xiaohongshu/content-prototypes.md`
- `creator/templates/xiaohongshu/references/style-examples.md`
- `creator/templates/narration/methodology.md`
- `creator/templates/narration/script-prototypes.md`
- `creator/templates/narration/references/style-examples.md`

### Files unchanged
- All preset files (`presets/*.md`)
- `shared/` utilities
- Other skills (content-parser, image-gen, tts, asr)
- Other template directories not listed above (e.g., any future platform templates)

### Backward Compatibility
- Existing user style files (`.listenhub/creator/styles/*.md`) continue to work unchanged
- Config structure unchanged
- Output folder structure unchanged
- API calls unchanged
- The writing quality improves; the pipeline interface stays the same

---

## 9. Success Criteria

1. **No AI-smell words in output**: L1 scan passes on first or second attempt consistently
2. **Distinct voice**: Output reads like khazix's style, not generic AI content
3. **Platform adaptation**: WeChat articles feel like long-form editorials, Xiaohongshu posts feel snappy and visual, narration scripts feel natural when read aloud
4. **Quality iteration works**: L1-L4 loop catches and fixes issues without user intervention in most cases
5. **Topic assistance adds value**: When given vague topics, the system helps users find better angles
6. **Prototype matching is accurate**: The auto-matched prototype matches the content type at least 80% of the time
