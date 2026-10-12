# 音乐生成清单（给 Gemini · 《机甲指挥》BGM 批量出 prompt）

> **这份文件怎么用**：把它整份丢给 Gemini，让 Gemini 按第 4 节「逐首清单」一条条产出 **Suno 可用的 prompt**
> （每条我都已经写了一版现成的，Gemini 的活是**照着风格锚点润色 / 扩写成正式 prompt**，或者直接照抄）。
> 作者（我）拿到 prompt 后在 Suno 上批量生成 → 导出 mp3 → 放进 `F:\DSH-mecha\mecha-autobattle\audio\SUNO\`。
> 写这份文件的是本仓库的**音乐会话**（`协作\交接-音乐.md` 的接手方），写于 2026-10-11。

---

## 0. 一分钟背景（给 Gemini 的上下文）

《机甲指挥》是一个**浏览器里跑的回合制机甲战斗 RPG**（肉鸽爬塔 + 自动战斗）。
玩家看的是**俯视的 6×4 格子地图**和**双方对撞的机体图标**，一个回合几秒钟就播完，
所以 BGM 的作用是**铺情绪 + 给节奏**，不是叙事。

- **画面风格**：冷色金属 + 霓虹点缀的科幻界面；机体是**矢量剪影图标**（不是写实 CG）。
- **主角势力**：影世界（B1 雷萨 / B2 蕾卡 / B3 维诺 / B4 比格特拉克 / 近卫·尖兵·特种）。
- **世界观关键词**：机甲小队、母舰、宇宙战场、影子世界、月亮王国、卫星国防军、秘银（雇佣兵）、天人（GN 粒子）。
- **参考的量级**：一个场景一首曲子，**一首 2–4 分钟、整首循环**（游戏里 `loop = true`，会连续放十几分钟）。

---

## 1. ★ 风格锚点（**这一节是整批曲子必须共用的**）

**已有 9 首（Suno 生成）确立的风格，新曲子必须听上去是「同一张专辑」**：

| 已有曲名 | 对应场景 / 势力 | 风格定位（新曲子请对齐） |
|---|---|---|
| `Suno 主角` | 菜单 / 影世界主角 | 主旋律感最强的主题曲，明亮 + 燃 |
| `Suno 我方回合` | 我方回合（常规战斗） | 推进感强的战斗曲，鼓点清晰、循环不腻 |
| `Suno 敌方回合` | 敌方回合 | 同一条战斗曲的「压迫版」：低频更重、更阴 |
| `Suno ATX` | ATX 势力 | 热血 / 突击感、铜管与失真吉他 |
| `Suno 流星小队` | 流星小队势力 | 孤狼感、电子 + 弦乐、稍冷 |
| `Suno 影世界` | 影世界势力 | **暗色、压抑、神秘**（Boss 现在是借它顶的） |
| `Suno 月王国` | 月球王国势力 | 庄严 + 优美，月面 / 宫廷感 |
| `Suno 秘银` | 秘银势力 | 军事、冷静、战术感（雇佣兵） |
| `SUNO 卫星国防军` | 卫星国防军势力 | 宏大、进行曲感、SEED 觉醒的爆发 |
| `SUNO战斗音乐` | —— | （与「我方回合」同源） |

**统一风格关键词（每条 prompt 都建议带上）**：
`Japanese mecha anime BGM, orchestral + electronic hybrid, cinematic, 4/4, driving taiko/rock drums, brass stabs, synth arpeggio, choir accents, instrumental (no vocals), loop-friendly, seamless loop, 80s-90s robot anime spirit (like Super Robot Wars-style battle themes), modern polished mix`

**硬性要求（客观项，写进每一条 prompt）**：

1. **纯器乐**（`instrumental`）—— 游戏里没有人声提示，人声会和界面文字打架；
2. **可无缝循环**：不要淡出结尾、不要在最后 2 秒收束（BGM 是整首 loop）；
3. **不要突然静音 / 不要长留白**（客户端淡入淡出是代码做的，曲子内部不要留空）；
4. **时长 2–4 分钟**；
5. **导出码率与现有 9 首一致（实测 80 kbps）**，不要混 128/192/320；
6. **不要采样 / 不要模仿具体已知曲目**（版权）—— 只要**风格**，不要旋律雷同。

---

## 2. 命名 / 交付规范

- 导出文件名用**英文 + 空格**（现有 9 首就是这样，例如 `Suno 主角.mp3`、`SUNO 月王国.mp3`）；
  文件名的建议写法见每条的「**导出文件名**」字段，**可以改，但要在交给音乐会话时说明**。
- 每个文件交给音乐会话时，必须能对上 **`id`**（英文短名，进发布包用）和**挂在哪个 cue / 势力**。
- 放进 `audio\SUNO\` 之后**告诉音乐会话是哪几个文件**，剩下的（实测 lufs、写 `TRACKS` / `CUES` / `THEMES`、
  跑构建与测试）**由音乐会话做**，作者不用碰代码。

---

## 3. 这次要生成的总表（**7 条线 = 8 首**）

| # | `id` | 曲名（中文） | 挂在哪 | 优先级 | 备注 |
|---|---|---|---|---|---|
| 1 | `boss` | Suno Boss | 所有 Boss 战（`CUES.boss`） | ★★★ 必须 | 现在借「Suno 影世界」，撞影世界势力曲 |
| 2 | `victory` | Suno 通关 | 本局通关 / 战斗胜利（`CUES.victory`） | ★★★ 必须 | 现在借「Suno 主角」，和菜单曲撞 |
| 3 | `defeat` | Suno 败北 | 本局失败（`CUES.defeat`） | ★★★ 必须 | 现在**没有**（`null`，不切曲） |
| 4 | `map` | Suno 战略 | 大地图 / 分队 / 招募 / 奇遇 / 编队（`CUES.mapStrategy`） | ★★ 强烈建议 | 现在还指着**作者本地的版权曲**，别人机器上听不到 |
| 5 | `cb` | Suno 天人 | 天人势力（CB1–CB5）放大招（`THEMES.faction['天人']`） | ★★ 建议 | 7 个势力里**唯一没有曲子**的 |
| 6a | `feena` | Suno 月王 | M1 Feena 个人主题曲（`THEMES.unit.M1`） | ○ 可选 | 月球王国核心角色 |
| 6b | `setsuna` | Suno 刹那 | CB1 刹那 个人主题曲（`THEMES.unit.CB1`） | ○ 可选 | 天人主角 |
| 7 | `boss2` | Suno Boss 二阶段 | Boss 半血后的第 2 阶段（**要另外改代码**） | △ 锦上添花 | 见第 5 节「额外可选」 |
| 8 | `title` | Suno 标题 | 开场菜单（`CUES.title`，替代现在的「Suno 主角」） | △ 锦上添花 | 想让菜单曲和胜利曲分开时做 |

> **先做 1–5 这 5 首**就能把「明显不对」的地方全补上；6–8 看心情。

---

## 4. 逐首清单（每条都带**现成 prompt**）

> 下面的 `Prompt（可直接用）` 我是按第 1 节的风格锚点写好的：
> Gemini 可以**直接照抄**，也可以**在不改变「用途 / 情绪 / 硬性要求」的前提下润色成更长的正式 prompt**。
> 每条末尾的「**必须 / 不许**」是硬约束，**不许被润色掉**。

### 4.1 `boss` · Boss 战曲 ★★★

- **用途**：肉鸽里**第 4 层终点的站桩大 Boss**（蓝色大肥鱼，HP 极高、每 3 回合放一次「周身冲击」），
  以及练习模式里选 Boss 编成时。整场战斗**从头放到尾**（一首曲子要撑 10+ 分钟循环）。
- **情绪 / 场面**：巨大、缓慢、**压迫感**；像「你打不动它」的绝望感里带着反攻的希望。
  不要激昂的胜利感（那是 `victory` 的活），要**重量**。
- **乐器**：低频铜管 + 定音鼓 / 太鼓、低音合成器、管风琴或男声合唱的**低音层**、
  中段加入快速的弦乐跑动（表现 Boss 的连续攻击）。
- **参考**：它是「`Suno 影世界` 的升级版」——比影世界更重、更慢、更宏大，但**不能变成同一首**（影世界是势力曲，会在同一场战斗里被角色主题曲切换）。
- **必须 / 不许**：纯器乐 · 无缝循环 · 2–4 分钟 · 不要结尾淡出 · 不要人声歌词 · 不要采样已知曲目。
- **导出文件名**：`Suno Boss.mp3`

**Prompt（可直接用）**：

```
Instrumental Japanese mecha anime boss battle BGM, cinematic orchestral + electronic hybrid.
Colossal, oppressive, slow and heavy: deep brass, timpani and taiko, sub-bass synth drone,
low male choir pads, dissonant string clusters. Mid-section adds fast tense string runs and
double-kick drums to portray the boss unleashing a shockwave attack, then falls back to the
dread-laden main motif. Dark, monumental, hopeless-but-defiant. No vocals, no lyrics.
Loop-friendly: no fade-out ending, no final cadence, seamless loop.
2-4 minutes, 4/4, ~90-110 BPM.
```

### 4.2 `victory` · 通关 / 胜利曲 ★★★

- **用途**：一场战斗打赢的结算屏，以及**走完 4 层通关**的本局结算屏。
- **情绪 / 场面**：**松一口气 + 高扬**；不是「凯旋进行曲」，而是「打得很难、终于赢了」的呼吸感，
  中后段有一段明确的**主旋律大调爆发**（通关时听到会起鸡皮疙瘩的那种）。
- **乐器**：弦乐主旋律 + 铜管齐奏、明亮的合成器铺底、鼓点从克制到全开（前 15 秒轻，后面起来）。
- **必须 / 不许**：纯器乐 · 2–3 分钟（**这一首不用严格无缝**，它是一次性播放的，但**不要淡出结尾**，要给一个「收住」的结束）· 不要人声歌词。
- **导出文件名**：`Suno 通关.mp3`

**Prompt（可直接用）**：

```
Instrumental Japanese mecha anime victory / clear theme, cinematic orchestral + electronic hybrid.
Relieved and uplifting, not a pompous march: starts restrained (solo strings, soft synth pad,
sparse drums) and builds over ~20 seconds into a full major-key brass and string melody burst,
with bright synth arpeggios and driving drums. Triumphant but earned, hopeful, clean ending.
No vocals, no lyrics, no fade-out (give it a proper final chord).
2-3 minutes, 4/4.
```

### 4.3 `defeat` · 败北曲 ★★★

- **用途**：作战失败 / 耐久耗尽 / 玩家放弃本局时的结算屏（**现在什么都不放**）。
- **情绪 / 场面**：安静的失落、疲惫、但不悲情到哭；像「撤退、回母舰、下次再来」。
- **乐器**：钢琴或电钢独奏起手，低音弦乐长音、稀疏的鼓或干脆没有鼓，末段留一点微弱的光（一个悬而未决的和弦）。
- **必须 / 不许**：纯器乐 · **不要**悲伤的独唱 / 哭声 / 人声 · 1.5–3 分钟 · **不要**强烈的战斗鼓点。
- **导出文件名**：`Suno 败北.mp3`

**Prompt（可直接用）**：

```
Instrumental Japanese mecha anime defeat / retreat theme, cinematic, mostly orchestral.
Quiet, weary and reflective: solo electric piano over sustained low strings, sparse percussion
(or none), distant synth pad. Melancholic but restrained - a tactical retreat, not a tragedy.
Ends on a soft unresolved chord that hints the fight is not over. No vocals, no lyrics, no fade-out.
1.5-3 minutes, slow 4/4.
```

### 4.4 `map` · 战略 / 大地图曲 ★★（**推荐做**）

- **用途**：肉鸽大地图（6×4 格子，玩家在选下一个节点）、分队、招募、奇遇、编队屏。
  **这是玩家听得最久的一首**（大部分时间都在大地图上点）。
- **情绪 / 场面**：冷静的**战前规划感**：像指挥室里看星图、在地图上推演。
  **不能太吵**（会听腻），要有**稳定的律动**和一点**向前走的动力**；
  可以有一点神秘 / 未知（地图上还没揭开的格子）。
- **乐器**：中速合成器 arpeggio + 干净的电子鼓、弦乐 pad、偶尔的钟琴 / 马林巴点缀；
  低音不要压太重（这是「看地图」不是「打架」）。
- **参考**：像《超级机器人大战》的**舰内 / 地图 BGM**那种质感。
- **必须 / 不许**：纯器乐 · **严格无缝循环**（会连续循环 10–20 分钟）· 2–3 分钟 · 不要人声 · 不要鼓点过密。
- **导出文件名**：`Suno 战略.mp3`

**Prompt（可直接用）**：

```
Instrumental strategy / world-map BGM for a Japanese mecha anime tactics game, cinematic electronic + orchestral.
Calm, tactical, forward-moving: steady mid-tempo electronic drums, clean synth arpeggio ostinato,
warm string pads, occasional glockenspiel and marimba accents, light bass (never heavy).
Feels like planning a campaign on a star map inside a carrier bridge - cool, slightly mysterious,
not aggressive. Must be pleasant on endless repeat. No vocals, no lyrics.
Strictly loop-friendly: no fade-out, no final cadence, seamless loop. 2-3 minutes, 4/4, ~100-120 BPM.
```

### 4.5 `cb` · 天人（CB）势力曲 ★★

- **用途**：`CB1 刹那 / CB2 洛克昂 / CB3 阿雷路亚 / CB4 提耶利亚 / CB5 拉塞` **放大招**时切过去（现在是**什么都不切**）。
- **情绪 / 场面**：**「天使 / 审判」气质**——圣洁、冷冽、压倒性的力量；
  设定是「GN 粒子 + TRANS-AM 爆发」，所以有一层**发光的合成器**和**合唱的圣咏感**。
- **乐器**：女声 / 男声**合唱（啊声，无歌词）**、教堂管风琴感、明亮的合成器 lead、快速弦乐 + 电子鼓。
- **必须 / 不许**：**纯器乐**（合唱只能是元音「ah / oo」，**不许有歌词**）· 无缝循环友好 · 2–3 分钟 · 不要采样已知曲目。
- **导出文件名**：`Suno 天人.mp3`

**Prompt（可直接用）**：

```
Instrumental Japanese mecha anime faction theme for a celestial "angelic" mecha squad, cinematic orchestral + electronic.
Holy, cold and overwhelming: wordless choir (only "ah"/"oo" vowels, no lyrics), church-organ pads,
bright glowing synth lead, fast string ostinato and tight electronic drums.
Feels like a transcendent power awakening - divine judgement, not evil.
No vocals with words, no lyrics. Loop-friendly, seamless loop, no fade-out. 2-3 minutes, 4/4.
```

---

> **下面 3 首是可选的**，做不做都行；做之前跟音乐会话说一声（不影响前 5 首的接入）。

### 4.6a `feena` · M1 Feena 个人主题曲 ○

- **用途**：M1 Feena（月球王国指挥）**放大招**时切过去。她的机制是「月光祝福 + 残月的余响（操作质量加速器丢陨石）」。
- **情绪**：月光的**温柔 + 决断**；前段静、后段重（像从祈祷到丢下陨石）。
- **乐器**：竖琴 / 钟琴 + 弦乐 + 女声无词吟唱，后段加厚重低音与太鼓。
- **必须 / 不许**：纯器乐（吟唱只能是元音）· 无缝循环 · 2–3 分钟。
- **导出文件名**：`Suno Feena.mp3`
- **Prompt（可直接用）**：

```
Instrumental Japanese mecha anime character theme, cinematic orchestral + electronic.
Gentle moonlight turning into resolve: harp and celesta intro with warm strings, wordless female
vocalise (vowels only), then the second half grows heavy with low brass, taiko and a descending
meteor-like bass drop motif. Serene, elegant, then decisive. No lyrics. Loop-friendly, no fade-out. 2-3 minutes.
```

### 4.6b `setsuna` · CB1 刹那 个人主题曲 ○

- **用途**：CB1 刹那（天人近卫，TRANS-AM）**放大招**时切过去。
- **情绪**：孤高的**剑客 + 觉醒**；比势力曲 `cb` 更个人化、更快、更锋利。
- **乐器**：失真吉他 + 快速弦乐 + 电子鼓、明亮的 lead synth、**低男声**无词合唱。
- **必须 / 不许**：纯器乐 · 无缝循环 · 2–3 分钟。
- **导出文件名**：`Suno 刹那.mp3`
- **Prompt（可直接用）**：

```
Instrumental Japanese mecha anime character theme, fast and sharp, orchestral + electronic.
A lone swordsman awakening: distorted guitar riffs, fast string ostinato, tight electronic drums,
bright lead synth, low wordless male choir. Intense, proud, transcendent.
No lyrics. Loop-friendly, seamless loop, no fade-out. 2-3 minutes, 4/4, ~140-160 BPM.
```

---

## 5. 额外可选（**要另外改代码，做之前必须先问音乐会话**）

| 曲子 | 用途 | 为什么现在不能直接用 |
|---|---|---|
| `boss2` · Boss 二阶段曲 | Boss **半血后**换一首（现在只是「间隔 3→2、伤害 ×1.25」，曲子不变） | 引擎里已经有「进入第 2 阶段」的记录，但**音乐层的判定要新加一条**（相当于又一次 `看记录` 的改造），属于**接口改动**，要走登记流程 |
| `title` · 标题曲 | 开场菜单单独一首（现在 `title` 和 `victory` 共用「Suno 主角」） | 技术上**只改一行**；但 `victory` 也指着它，要一起换（做 4.2 之后正好把 `victory` 换掉，`title` 就能单独用新的标题曲） |

---

## 6. 给 Gemini 的产出格式（建议）

**每首曲子输出一段，字段照抄**，方便我批量贴进 Suno：

```
【id】boss
【曲名】Suno Boss
【挂在哪】所有 Boss 战
【时长目标】2-4 分钟
【BPM / 拍号】90-110 / 4/4
【必须】纯器乐 · 无缝循环 · 无淡出结尾
【不许】人声歌词 · 采样已知曲目 · 结尾收束
【Style / 风格标签】（逗号分隔的关键词，Suno 的风格框用）
【Prompt / 正文】（Suno 的歌词框用：写 [Instrumental] / [Intro] / [Main Theme] / [Breakdown] / [Build] / [Loop] 这类段落标记也行）
```

**Suno 使用小贴士（写进 prompt 时可以用上）**：

- 风格框里放**风格标签**（第 1 节的统一关键词 + 每首的差异词），正文框放**结构**；
- 想要无缝循环：在正文里明确写 `loop-friendly, seamless loop, no fade out, end on the main groove`；
- 想避免人声：风格框里加 `instrumental, no vocals, no lyrics`；
- 想统一响度：所有曲子都用**同一个导出档位**，不要单独调音量（游戏里会用实测 LUFS 自动拉平）。

---

## 7. 交付清单（作者做完打勾）

- [ ] `Suno Boss.mp3` → Boss 战
- [ ] `Suno 通关.mp3` → 通关 / 战斗胜利
- [ ] `Suno 败北.mp3` → 本局失败
- [ ] `Suno 战略.mp3` → 大地图 / 分队 / 招募 / 奇遇 / 编队
- [ ] `Suno 天人.mp3` → 天人（CB1–CB5）放大招
- [ ] （可选）`Suno Feena.mp3` / `Suno 刹那.mp3`
- [ ] 全部放进 `F:\DSH-mecha\mecha-autobattle\audio\SUNO\`，**码率与现有 9 首一致（80 kbps）**
- [ ] 告诉音乐会话：「这 N 个文件 + 各自挂在哪」（剩下的写表 / 测响度 / 跑测试由音乐会话做）

---

## 8. 音乐会话拿到文件后会做什么（作者不用管，列出来是为了对账）

1. 用 Windows Media Foundation 把 mp3 转 WAV → **实测 LUFS**（本机没有 ffmpeg）；
2. 按**实测 lufs** 在 `audio\local-music.js` 的 `TRACKS` 加一行（曲名 / 文件 / lufs / `id`）；
3. 把 `CUES`（`boss` / `victory` / `defeat` / `mapStrategy`）或 `THEMES.faction['天人']` / `THEMES.unit` 指过去；
4. `node tools/build-src.mjs` 重新生成 `index.html` + `src/artifact-fragment.html`；
5. `node tests/audio.js`（[5] 曲目数与场景映射、[9] 假浏览器里**真的指向仓库里的文件**）+ `tests/battle_ui.js`；
6. 十六套测试 + `--check`，然后把「曲名 / 文件 / lufs / id / 挂在哪」追加进 `协作\任务板.md`。

---

> 附：本仓库现在的曲子（**17 首** = 原 9 首 + 2026-10-11 作者补的 8 首，**都是 Suno 生成、可以进仓库**）：
> `Suno 主角` / `Suno 我方回合` / `Suno 敌方回合` / `Suno ATX` / `Suno 流星小队` / `Suno 影世界` /
> `Suno 月王国` / `Suno 秘银` / `Suno 卫星国防军`；
> 2026-10-11 作者补的 8 首：`Suno Title` / `Suno Setsuna` / `Suno Feena` / `SUNO 天人` / `SUNO 战略` / `Suno Victory` / `Suno Defeat` / `Suno Boss`。
> **作者本地的 8 首版权曲（`BOSS BGM.mp3`、`战略音乐1.mp3` 等）绝对不能进仓库**——
> 那是公开分发受版权保护的录音；新曲子必须是 **Suno 生成 / 作者原创**。
