# 施工单 RT 回执：旧口径退役（JS 时代的战斗模式 + 黄金样例 + 版本开关）

> 施工单：[`施工单-RT-旧口径退役-DS4.1F.md`](施工单-RT-旧口径退役-DS4.1F.md)。设计/验收：Claude Opus 5.5 · 执行：DS4.1F。
> 每完成一个 Batch 追加一节；新对话只读 §0.1 与本文件最后一节即可接着干。

---

## RT-1：只读盘点（Q1–Q6）

- **提交号**：`70fad07` `[RT-1] 只读盘点 Q1-Q6（旧口径退役）`。本批按施工单 §RT-1「只读，不改任何 `.gd` / 数据」执行，
  代码与数据 **0 个字节**（下面「改了哪些文件」= 只新增两份文档）。
- **产出**：[`RT-1盘点.md`](RT-1盘点.md)（Q1–Q6 全部结论 + 证据）。
- **新增文件**：
  - `协作/架构/RT-1盘点.md`
  - `协作/架构/RT回执.md`（本文件，新建）

### 1. 改了哪些文件

| 类别 | 结果 |
|---|---|
| `.gd` 源码 | **0 个字节**（临时探针 `godot/tests/_probe_rt1.gd` 用完已删；`Test-Path` = `False`，`git status` 里没有它） |
| `godot/data/js/**` | **0 个字节**（一个数据文件都没写；只 `Get-Content` 读过 `71-改动-4` / `71-改动-5` 两份） |
| 黄金样例 / 卡表快照 | **0 个字节**（`tests/golden/battle/*.json`、`card_tables/*.txt`、`run_vectors.json`、`rng_vectors.json` 都没写；`battle/*.json` 只由探针读了 `default.json` 的「选项键」与第 1 条输入） |
| 生成物（RouteMap / AST 清单） | **0 个字节**（见下面 `--check` 的「逐字节一致」三行） |

### 2. 门禁结果（本批没改代码，属于「只读基线」，留给 RT-2 当参照）

```
$ node godot/tools/build_godot_routemap.mjs --check
  ✓ 逐字节一致：协作/架构/Godot-RouteMap.md
  ✓ 逐字节一致：协作/架构/Godot-RouteMap-明细.md
  ✓ 逐字节一致：协作/架构/Godot-AST依赖清单.json
✓ --check 通过（三份生成物与源码逐字节同步，索引页未超 8,000 估算 token）
EXIT=0
```

```
$ godot --headless --path godot --script res://tests/run_tests.gd
机甲指挥 · Godot 测试：47 个测试文件
…
[test_battle_rules] ✓ 10
[test_golden_battles] ✓ 17
[test_mithril_v02_cards] ✓ 139
[test_mithril_v02_core] ✓ 55
[test_presentation_layout] ✓ 915
[test_unit_deck_system] ✓ 215
==========================================
✓ 全部通过：3949 项          （退出码 0）
```

> 起点数字（RT-2 报「耗时变化」时拿它当基线）：**47 个文件 / 3949 项 / 全绿**。
> 另：`MECHA_SMOKE` 那行自报 `{"战术卡牌表":32,"编成表":47,"ALLY_T":34}` —— 与 Q6 的「32 张」互相印证。

### 3. 六个问题的结论（详情与逐条证据见 [`RT-1盘点.md`](RT-1盘点.md)）

| 问题 | 结论 | 关键证据 |
|---|---|---|
| **Q1** 开关表 | `params.gd` **19 个 `…开(` 开关**（+2 别名 `装甲共享池(ctx)` / `DeckFlow.开(ctx)`）。**8 个只读数据** → 三套选项取值完全一样（`动作QTE` 恒关）；**11 个读 ctx 选项** → **9 个「生产开、旧样例关」**、`战术卡牌开` 三套全开、`秘银v02开` **三套全关**（生产 32 个调用点全是死路） | 探针 `[A6]` 五列对照表 + `route_query.mjs` 逐开关生产调用点数（§Q1.2） |
| **Q2** 旧手牌在新模式活不活 | **C（会产生事件，也改数值）**：9 场（3 队 × 3 种子）每场 **4 条 `类型: 发牌`**（合计 36）、`战术手牌` 6→10、`待触发战术牌` 8/9→4/5/6、`气势` **25→100**；`已打出战术牌` 恒 0（新模式没人打旧手牌）。实测点火路径 = `flow.gd:322`（`攻击后` 条件发牌） | §Q2.2 逐回合表 + `[C汇总]` / `[D]` 输出 |
| **Q3** 只有旧模式走得到的代码 | 真正旧专属 **4 处**：`Setup.runTurn`、`打一回合` 旧分支、`手牌装填_JS参考`、旧手牌栏界面（`hand_panel.gd:115-120` 藏 + 提前 return）。另有 **3 处「代码没守卫、只是界面藏起来」**：`Btl.打战术牌` → `BattleCardExec.打战术牌` → `SessionBattleFlow._打战术牌` → `play_tactical_card`（唯一 UI 入口 `log_panel.gd:263`）。**看着像旧其实新模式在跑的 3 处**：`Setup.endTurn`（`phase_flow.gd:144` 在新模式调它）、`候补补位`、检查条件发牌 —— RT-3b 别误删 | §Q3 表（每条带 `文件:行号`） |
| **Q4** 测试分类 | 47 个文件：**纯旧 5**（≈230 条）、**混合 13**、**纯新 17**、**与模式无关 12**。纯旧 4 个可执行文件的实际项数 = **221**（17+10+139+55）；`test_layout_factions` 的 37 条记在 `test_presentation_layout` 的 915 里 | §Q4 表（每文件一行 + 混合文件点名哪几个用例） |
| **Q5** JS 时代工具 | `export_golden.mjs` 只为 168 场旧样例（8.0 MB / 5 个文件）→ 可删；`export_run_golden.mjs` / `js_ref.mjs` / `gen_rng_vectors.mjs` 仍要保留（`run_vectors.json` / `rng_vectors.json` 保留）；**`export_data.mjs` 会 `rmSync` 整个 `data/js` 重写 → 重跑必然冲掉手改**（`71-改动-4` 的 `单机牌组` 块就是 `9d9f8bb [M4]` 手写的，而 `manifest.json` 自 M2 后没再变）。今天它跑不起来（`checkSealed()` 因 `.ignore` + 一份 docs 与 tag 有差而抛错，且抛错在 `rmSync` 之前） | §Q5.1 / §Q5.2（含 `git diff` / `git log` / `git show` 的原始输出） |
| **Q6** 战术卡牌表去向 | 32 张：新模式只读 **8 张**（`CMD_ALL_OUT` / `CMD_COVER` 统帅 + `U_CB1` / `U_CB2` / `U_M1` / `U_A1` / `U_S1` / `U_B1` 角色→上排）；**24 张 `C_*` / `F_*` 基础表公有牌新模式一张都不装**（`setup.gd:459-460` 见 `秘银v03开` 就 `return false`），它们只剩旧模式用（含 D-01 举例的【激励】`C_CMD_1`、【热血】`C_GUARD_1`）。**只列不删** | §Q6 表（逐个卡 id） |

### 4. 未决问题（停下等验收）

1. **Q2 = C → 施工单 §RT-3a 的「闸门 G」成立**。按我的量化：删旧牌池后每场会少 **4 条 `类型: 发牌`**（`气势` 不在 RT-2d 白名单里，不影响对拍）。
   重录前请作者签字。
2. **`秘银v02开` 生产三套全关**（32 个调用点 / `mithril_v02_cards.gd` 1099 行 / `MITH-1~2` 全部机制）。
   它不是「为旧样例存在」，而是「v0.3 顶掉 v0.2 但没删」；**退不退它，施工单没写** → 请决策。
   （补充：旧黄金样例那一列它也是关，所以退掉它**连旧样例都不动**。）
3. **`export_data.mjs` 怎么处理**（删 / 改成读到即抛错 / 只加警告）—— 见 §Q5.2，我没动。
4. **`战术卡牌表` 的 24 张 `C_*` / `F_*` 与 `CARD_OPS`（`card_effects.gd:36-230`）里它们的效果代码**：数据一张不删（红线 5），
   但**效果代码**要不要随旧池一起删，需要 RT-3.0 决策表明确。
5. **「只是用旧入口开一场战斗」的测试**（`test_session_run` / `test_layout_flow` / `test_layout_screens` / `test_layout_board` 等）：
   我建议改成新入口（`开始快速测试战斗`）而不是删 —— 这属于「迁」不是「删」，请在决策表里确认。
6. **`_battle_options_cache` 在节点战路上算而不用**（`battle_flow.gd:204-205` 赋值，`:206` 调 `NodeResolver.开战` 自己重建），
   且 `_build_battle_options()` 里显式写的 `卡牌流转` 在节点战里**根本没传**（只是靠 `秘银v03` 间接带出来）。
   RT-2a 抽 `SessionBattleOptions.生产()` 时顺手收口，**本单不改**。

**RT-1 到此停下**，等 Claude 验收并补写 §RT-3.0 决策表。RT-2 未开工。

---

## RT-2：录 Godot 原生黄金样例（RT-2a ~ RT-2e）

- **提交号**：`[RT-2]` 那一条（本节与代码 / 样例在**同一个提交**里；`git log --oneline | grep '\[RT-2\]'` 可查）。
- **施工单口径**：按 §RT-2 原文 + 「RT-2 补充要求」1~3 条执行（补充要求覆盖原文：选项三处收口 / 快速测试走真路径 /
  白名单再去掉 `战况计数.满手牌推迟数`）。

### 1. 改了哪些文件

| 类别 | 文件 |
|---|---|
| **唯一的生产代码改动（RT-2a）** | 新增 `godot/session/battle_options.gd`（`SessionBattleOptions.生产`）；改 `session/game_session.gd`（两个方法改成调它、删 `_battle_options_cache`）、`session/battle_flow.gd`（快速战改用局部选项；节点战删两行死赋值）、`session/roster_facade.gd`（删 4 行死赋值）、`session/run_facade.gd`（删 5 行死赋值）、`core/run/node_resolver.gd`（只改注释：第 4 参的语义） |
| **新增测试设施** | `godot/tests/native_golden_policy.gd`（确定性出牌策略）、`godot/tests/native_golden_runner.gd`（录制 / 对拍核心）、`godot/tests/unit/test_native_goldens.gd`（逐场重跑断言）、`godot/tests/golden_io.gd`（补 `encode` / `float_to_bits`，只加不删） |
| **新增工具** | `godot/tools/extract_native_inputs.gd`（抽输入）、`godot/tools/record_native_golden.gd`（headless 录制 + RT-2e 覆盖自检） |
| **新增样例数据** | `godot/tests/golden/native/` 12 个文件（`inputs.json` + 11 个样例文件），合计 **10.65 MB** |
| **重建的生成物** | `协作/架构/Godot-RouteMap.md` / `Godot-RouteMap-明细.md` / `Godot-AST依赖清单.json`（加了 6 个 `.gd`，必须重建） |
| **没动** | 旧 168 场 `tests/golden/battle/*.json`、`golden_runner.gd`、`test_golden_battles.gd`、`data/js/**`、任何开关函数 |

### 2. RT-2a：生产选项单一来源（三处收口）

- **做法**：新增 `SessionBattleOptions.生产(run_state, 全卡池体验 := false, 单机牌组 := true) -> Dictionary`，
  它复刻了原 `GameSession._build_battle_options()` 的**全部**分支（`run_state == null` 的兜底、`战术卡牌`、`单机牌组` /
  `秘银v03` / `卡牌流转`、`全卡池体验` 时的 `快速测试` / `全卡池体验`）。
  第三个参数 `单机牌组` 是**必须**的：老入口 `start_quick_battle` / 还没开局时 `单机牌组模式 == false`，
  原逻辑那时只写 `战术卡牌 / 已选战术牌 / 藏品`（一个单机牌组的键都不写）。不保留这一支就会改变老入口的行为（RT-2a 红线：不改变行为）。
- **`NodeResolver.开战` 选的是「接收算好的选项」**（补充要求给的两选一）：
  `battle_flow.gd:206`（节点战）与 `run_facade.gd:164`（追击战）现在把 `session._附加战斗选项()` 传进去，而
  `_附加战斗选项()` 已改成**直接返回 `SessionBattleOptions.生产(...)` 整份**（不再只写两个键）。
  `开战` 仍先用 `RelicSystem.build_battle_options(state)` 兜底、再用传进来的覆盖同名键 ——
  这样 `test_run_core.gd:246` / `test_ux4_lineup_slots.gd:49` 那种「不传选项」的旧调用路径逐字不变。
- **删掉的死代码**：`GameSession._battle_options_cache` 整个成员 + **15 处赋值**（`game_session` 3 处、`battle_flow` 3 处、
  `roster_facade` 4 处、`run_facade` 5 处；其中 `battle_flow.gd:59` / `:205` 那两处是 `["单位开关"]` 的子键赋值），
  **唯一读过它的是 `battle_flow.gd:60`**，现在改成局部变量 `选项`；节点战那两行（`:204-205`）算完没人读，直接删。

**验收（补充要求 1）**：`[A6]` 探针重跑，三套取值与 RT-1 表格逐行一致；**节点战的 `ctx.选项` 键现在包含 `卡牌流转`**：

```
[A2b] 肉鸽选项全文   = { "战术卡牌": true, "已选战术牌": [], "藏品": [], "单机牌组": true, "秘银v03": true, "卡牌流转": true }
[A2c] 附加(节点战)   = { "战术卡牌": true, "已选战术牌": [], "藏品": [], "单机牌组": true, "秘银v03": true, "卡牌流转": true }
[A3]  节点战 ctx.选项 键 = ["秘银v03", "卡牌流转", "战术卡牌", "单机牌组"]        ← 改前只有 ["秘银v03","战术卡牌","单机牌组"]
[A4b] 快速测试 ctx.选项 = { "快速测试": true, "全卡池体验": true, "秘银v03": true, "卡牌流转": true, "战术卡牌": true, "单机牌组": true }
[A6]  19 个开关 | 肉鸽 | 肉鸽真路径 | 快速测试 | 旧黄金样例   → 与 RT-1 §Q1.2 表逐行相同（8 个读数据开关四列全同、
      9 个「生产开 / 旧样例关」、秘银v02 四列全关、战术卡牌 四列全开、动作QTE 四列全关）
```

### 3. RT-2b：输入复用（`inputs.json`）

- `godot --headless --path godot --script res://tools/extract_native_inputs.gd` →
  **176 条输入 / 201 KB**（`default` 47 · `faction` 84 · `character` 6 · `relic` 30 · `quick` 9）。`card_baseline` 按要求不要。
- 每条只取 `id / 我方 / 敌方规格 / 种子 / 藏品 / 编成`（+ 我加的 `组` / `分文件` / `快速测试阵容`）；非整数仍是 `{"$f": 位串}`（847 处）。
- **⚠ 旧大文件里有 14 个 id 撞车**（`编成.编号` 是 `undefined`，同一势力的 4 条编成同名），共 42 条：
  我给第 2 条起补了 `#2..#4` 后缀去重，原 id 留在 `原id` 里。**不改 id 的话「id → 输入」根本对不上**（第一版就是这么错的，已修）。
- `quick` 组：3 队（秘银 / ATX / 天人）× 第 1 层普通编成 × 种子 `20261013 / 20261014 / 20261015`；
  按补充要求 2 走**真路径** `GameSession.开始快速测试战斗(队, 种子)`，样例里记的是**传入**的种子（`20261013`），
  不是门面变换后的 `20269814`。

### 4. RT-2c：确定性出牌策略（`tests/native_golden_policy.gd`）

| 规则（施工单 §RT-2c） | 实现 |
|---|---|
| 每个我方阶段按槽位从小到大轮一遍，每台机体按「大招槽 → 副武器 → 衍生 → 精神 / 公有 → 主武器」 | `找下一张()` → `_该机体的第一张可打()`，顺序与施工单一致 |
| 能不能打用 `CardPlay.不可打原因`（界面置灰的同一个函数），不许"试打再换" | 只用 `CardPlay.不可打原因(...) == ""` 判定；**实测 0 次"选中了却打不出来"** |
| 目标 = `CardPlay.目标方` 那一侧、按槽位从小到大第一个合法目标 | `挑目标()`：敌方用 `Reach.武器可达吗` 找第一个可达；友方取第一个存活；`目标方_无` → `null` |
| 出牌调门面背后的核心函数 | 大招 `DeckFlow.打出大招` · 副武器 `DeckFlow.打出副武器` · 衍生 `Btl.打出衍生攻击卡` · 精神/公有 `Btl.打出精神或公有牌` · 主武器 `Btl.打出武器栏卡`（`卡牌流转` 关着时才退 `Btl.打出主武器卡`）——与 `session/battle_deck_view.gd` 的实际调用逐条对应，不另写结算 |
| 每阶段最多 30 次出牌，打不出就结束 | `每阶段上限 := 30`；录制器再调 `Btl.结束我方回合` |

**「策略一次 `ctx.rng` 都不许抽」的两条证明**：

1. **实测**：`出牌阶段()` 在**每次选牌判定**前后各取一次 `ctx.rng.steps`，把差值累加成 `选择rng`；
   176 场 × 全部回合的 `选择rng` 合计 **0**（`test_native_goldens` 里是一条硬断言：
   `★★ 策略选牌一次随机数都不抽（0 步；读 ctx.rng.steps 不算抽）`）。
   > 注意区分：**打出**牌当然会掷骰（那是内核的攻击结算，与策略无关）；被禁的是**判定**。
2. **源码扫描**（同一条测试里）：`tests/native_golden_policy.gd` 里不存在 `next_float` / `randi(` / `randf(` / `randomize(` /
   `rand_from_seed` 任何一个；只出现 `ctx.rng.steps`（读）。另断言它用的是 `CardPlay.不可打原因`。

### 5. RT-2d：录制器与对拍

- **`tests/native_golden_runner.gd`**：开局（`quick` 组走门面真路径，其余 `Setup.开局(我方, 敌方规格, 种子, null, 生产(...) ∪ {藏品})`）
  → 循环 `{策略出牌 → Btl.结束我方回合 → 记回合摘要}` 直到出结果或超过护栏 → 记结束。
- **回合摘要白名单**（严格按施工单 + 补充要求 3）：
  每台机体 `hp / maxHp / shieldHp / 掩护盾 / buffs / debuffs / 战意 / 主武器已销毁 / 武器[cd, uses] / 势力状态`
  + 牌组 8 个区的张数（`武器栏 / 副武器栏 / 大招槽 / 待入库 / 专属牌库 / 专属手牌 / 专属弃牌堆 / 衍生手牌`）+ `专属手牌` / `衍生手牌` 的 id；
  全局 `回合 / 阶段 / rng / 公有牌库 / 公有手牌 / 公有弃牌堆 的 id / 战况计数（去掉「满手牌推迟数」）/ 结果`。
  **不记** `战术手牌 / 待触发战术牌 / 候补初始牌 / 战术牌池 / 已打出战术牌 / 气势`。
  第 0 项全量、之后只记 `单位数 + 单位变化`（与旧样例同一套压缩，比对时展开）。
- **事件**：沿用旧做法去掉 `DISPLAY_ONLY`（`文本 / 效果说明 / 触发说明 / 来源文本 / 来源位`），附 `_rng`；
  非整数一律 `{"$f": 十六进制}`（新增 `GoldenIO.encode` / `float_to_bits`，与 `js_ref.mjs` 的 `normalize` 同口径）。

**每组场数 / 事件数 / 文件大小**（单个文件都 < 3 MB；`faction` 已按势力拆成 7 个文件）：

| 文件 | 场数 | 事件数 | 大小 |
|---|---:|---:|---:|
| `character.json` | 6 | 518 | 165.4 KB |
| `default.json` | 47 | 5322 | 1966.4 KB |
| `faction_ATX.json` | 12 | 3249 | 1154.1 KB |
| `faction_卫星国防军.json` | 12 | 2571 | 894.9 KB |
| `faction_天人.json` | 12 | 3411 | 1076.1 KB |
| `faction_影世界.json` | 12 | 2553 | 825.9 KB |
| `faction_月球王国.json` | 12 | 1927 | 689.4 KB |
| `faction_流星小队.json` | 12 | 2045 | 733.0 KB |
| `faction_秘银.json` | 12 | 3206 | 1067.4 KB |
| `quick.json` | 9 | 1533 | 461.8 KB |
| `relic.json` | 30 | 5128 | 1796.8 KB |
| `inputs.json` | —（输入） | — | 201.0 KB |
| **合计** | **176** | **31463** | **10.65 MB** |

**连录两次逐字节相同**（`tools/record_native_golden.gd` 跑两遍，中间不删文件）：

```
character.json  b406de082b8881304515b3750d5698d10fff20989219534497cfe552b0aa6b20
default.json  bb69643389f7afbf787296e9b3eed9f17e5d72a0e799c86d396381b326b494f5
faction_ATX.json  07f2aa19bdbbb457fb16baf5f8ee030d3e7d881835a6158d2fcdf3ff5ac911e2
faction_卫星国防军.json  49e4475f237f6810d9f43ff41fac7572988b66929a68c0a19b8bc21c72fc6e4c
faction_天人.json  2a6ca23ef5e75b6185e68836ee5097afe4754c0980fcf9a4e1dc2ebf5d3f78b0
faction_影世界.json  cbce69c50a305b63433ac55694c7abfa45d8181bf2a339c73719579235a78c5a
faction_月球王国.json  46c43e9eb2dfc2562f70dc2dd51b40554b5a4da4851f2cbb03c4566bafee88db
faction_流星小队.json  77806e0b0e36dcfe4cba97b561d8622c8b812b377aa6c02771572f8c5591fe83
faction_秘银.json  128f9a66beeeee4c1b3e9fe8fd0426701b41deae3fed70ddd4d9a3b92f9f56a5
inputs.json  41e1aaa963d038478ab4b4f02caf553fbb95a6b0edc32a013c90c1cc08a4141b
quick.json  47db45604b59b755dc3dce50da2c55bf7b5ce1c62ae22d81fa5c01afe10ba92d
relic.json  1128696b6abee287289e71f99946cea96b4278f56a3b716ae3b375093575ac30
→ 两遍 12 个文件全部逐字节相同（Compare-Object 无差异）
```

**耗时**（本机 `Godot 4.7.2 stable`，headless）：

| 项 | 时间 |
|---|---:|
| `tools/record_native_golden.gd`（176 场录制 + 写文件） | **122 秒** |
| `tests/unit/test_native_goldens.gd` 单跑（176 场重跑 + 对拍 + 确定性 + 源码扫描） | **117 秒** |
| 整套测试（**含**原生样例） | **217.6 秒** / `✓ 全部通过：3960 项` |
| 整套测试（不含原生样例，推算 = 217.6 − 117） | **约 100 秒** / 3949 项 |

> 新增的 11 条断言就是 `test_native_goldens.gd` 的那 11 条（含 4 条 ★ 硬断言）。

### 6. RT-2e：覆盖自检（`tools/record_native_golden.gd` 末尾自动打印）

```
[覆盖] 场数 176 · 事件 31463 · 结局 { "胜": 133, "败": 43 } · Boss 场 22
[覆盖] 出牌按区 { "专属精神牌": 4034, "公有牌": 905, "主武器卡": 677, "大招槽卡": 555, "衍生攻击卡": 530, "副武器卡": 387 }
[覆盖] 打出过的卡 id 238 个（卡库 345 个 · 打出过且在库里 233 个）
[覆盖] 打出过但不在卡库里的 id 5 个（衍生 / 未登记）：D_SP_BISHAN、D_SP_JIZHONG、D_SP_QIHE、D_应急补丁、D_战术副武
[覆盖] 事件类型 82 种：上张打出牌 6180 / 攻击 5944 / 专属精神牌 3908 / 主武器卡 2277 / 击破 1085 / 势力 985 /
       标定 951 / 发牌 710 / 武器栏 680 / 公有牌 649 / 回合 624 / 待入库 616 / 天人 613 / 衍生攻击卡 530 /
       大招槽 460 / 副武器 387 / 修理 383 / 嘲讽 348 / 大招解锁 265 / 秘银v03 262 / Boss 258 / …（其余 61 种略，
       最少的 1 次：满开 / 七剑齐出 / 各员开火 / 再动）
```

> 上面的合计我用独立脚本从录好的 11 个文件重算过一遍：**176 场 / 31463 事件 / 82 种 / 胜 133 · 败 43**，与录制器自报一致。

- **结局**：胜 133 / 败 43（**没有「撤退」**——策略会把牌打完，基本打不到回合上限）。
- **Boss 场**：22 场（`编成.类型 == "Boss"`；这 22 场的敌方规格里都含 `bluefish`）。
- **缺口（新模式下有、但一次都没打出过的卡）：112 张** —— 清单全文见本节末尾附录；粗分成几类：
  `_P` 升版牌（Lv30 档）、ATX 筹码牌 7 张、天人 `CB*_W*` 主武器、秘银 v0.3 的 `V3_*`、ATX `U_ATX_*` / `U_DUO_*`、
  `F_ATX_V2_*`（ATX v0.2 势力牌 9 张）。**要不要补样例请你判断**（我没有为凑覆盖去改输入）。

<details><summary>附录：112 张「一次都没打出过」的卡（原样输出）</summary>

```
ATX1_S10〔专属精神牌〕 ATX1_S1_P〔专属精神牌〕 ATX1_S2_P〔专属精神牌〕 ATX1_S6〔专属精神牌〕 ATX1_S7〔专属精神牌〕
ATX1_S8〔专属精神牌〕 ATX1_S9〔专属精神牌〕 ATX1_U1_P〔大招槽卡〕 ATX1_U3_P〔大招槽卡〕 ATX1_W2_P〔主武器卡〕
ATX1_W3_P〔主武器卡〕 ATX1_W4〔主武器卡〕 ATX2_D1_P〔副武器卡〕 ATX2_S1_P〔专属精神牌〕 ATX2_S2_P〔专属精神牌〕
ATX2_S5〔专属精神牌〕 ATX2_S6〔专属精神牌〕 ATX2_S7〔专属精神牌〕 ATX2_S8〔专属精神牌〕 ATX2_S9〔专属精神牌〕
ATX2_U1_P〔大招槽卡〕 ATX2_U2_P〔大招槽卡〕 ATX2_U3_P〔大招槽卡〕 ATX2_W1_P〔主武器卡〕 ATX2_W2_P〔主武器卡〕
ATX2_W4〔主武器卡〕 ATX3_S10〔专属精神牌〕 ATX3_S1_P〔专属精神牌〕 ATX3_S6〔专属精神牌〕 ATX3_S7〔专属精神牌〕
ATX3_S8_P〔专属精神牌〕 ATX3_S8〔专属精神牌〕 ATX3_S9〔专属精神牌〕 ATX3_U1_P〔大招槽卡〕 ATX3_U2_P〔大招槽卡〕
ATX3_U3_P〔大招槽卡〕 ATX3_U3〔大招槽卡〕 ATX3_W1_P〔主武器卡〕 ATX3_W2_P〔主武器卡〕 ATX3_W4〔主武器卡〕
ATX_CHIP_COIN〔筹码牌〕 ATX_CHIP_DEALER〔筹码牌〕 ATX_CHIP_ESCAPE〔筹码牌〕 ATX_CHIP_GODDESS〔筹码牌〕
ATX_CHIP_RESPIN〔筹码牌〕 ATX_CHIP_SHOWHAND〔筹码牌〕 ATX_CHIP_SLAM〔筹码牌〕 ATX_RW_JIAYIZHU〔专属精神牌〕
ATX_RW_LIANZHU〔专属精神牌〕 ATX_RW_MANXIAN_P〔专属精神牌〕 CB1_S8〔专属精神牌〕 CB1_W2〔主武器卡〕
CB1_W3〔主武器卡〕 CB1_W4〔主武器卡〕 CB1_W5〔主武器卡〕 CB2_U4〔大招槽卡〕 CB2_W2〔主武器卡〕
CB2_W3〔主武器卡〕 CB2_W4〔主武器卡〕 CB3_U5〔大招槽卡〕 CB3_W2〔主武器卡〕 CB3_W3〔主武器卡〕
CB3_W4〔主武器卡〕 CB4_NW3〔主武器卡〕 CB4_U4〔大招槽卡〕 CB4_W3〔主武器卡〕 CB5_W2〔主武器卡〕
CB_FAC_1〔〕 CB_FAC_2〔〕 CB_FAC_3〔〕 CB_FAC_4〔〕 CB_SD2_VEDA_PLAN〔〕 CB_SD3_HERITAGE〔〕
CB_SD3_VEDA_OPTIMAL〔〕 F_ATX_V2_1〔公有牌〕 F_ATX_V2_2〔公有牌〕 F_ATX_V2_3〔公有牌〕 F_ATX_V2_4〔公有牌〕
F_ATX_V2_5〔公有牌〕 F_ATX_V2_6〔公有牌〕 F_ATX_V2_7〔公有牌〕 F_ATX_V2_8〔公有牌〕 F_ATX_V2_9〔公有牌〕
U_ATX_1〔主武器卡〕 U_ATX_2_P〔大招槽卡〕 U_ATX_3〔专属精神牌〕 U_ATX_4〔主武器卡〕 U_ATX_5〔专属精神牌〕
U_ATX_6〔专属精神牌〕 U_ATX_7〔主武器卡〕 U_ATX_8_P〔副武器卡〕 U_ATX_9〔专属精神牌〕 U_DUO_10〔主武器卡〕
U_DUO_2〔主武器卡〕 U_DUO_3〔主武器卡〕 U_DUO_9〔主武器卡〕 V3_C_SN_3〔〕 V3_C_SP_4〔〕 V3_L3_FULL〔〕
V3_L3_SUPPORT〔〕 V3_U2_W3〔主武器卡〕 V3_U2_W4〔主武器卡〕 V3_U6_S5〔专属精神牌〕 V3_U6_U3〔大招槽卡〕
V3_U6_W2〔主武器卡〕 V3_U6_W3〔主武器卡〕 V3_U6_W4〔主武器卡〕 V3_U7_LW1〔主武器卡〕 V3_U7_LW2〔主武器卡〕
V3_U7_LW3〔主武器卡〕 V3_U7_S7〔专属精神牌〕 V3_URUZ_TRI〔主武器卡〕
```

</details>

### 7. 门禁结果

```
$ godot --headless --path godot --script res://tests/run_tests.gd
机甲指挥 · Godot 测试：48 个测试文件
…
✓ 全部通过：3960 项                （退出码 0；旧 168 场 test_golden_battles ✓ 仍绿）

$ node godot/tools/build_godot_routemap.mjs --check
✓ --check 通过（三份生成物与源码逐字节同步，索引页未超 8,000 估算 token）
EXIT=0
```

- 重建 RouteMap 时的审计：`violations = []` ✓ · 规则 ⑤ 143/143 持平 · ⑥ 违规 0 · ⑦ 超限 0 · ⑧ 超阈值 0。
- **索引页 7,971 / 8,000 估算 token**（加了 6 个 `.gd` 之后只剩 29 token 余量）—— 记为隐患，见未决问题 3。

### 8. 发现的缺陷（**没改**，按 RT-2 只许一处生产改动）

`BattleWeaponExec._找武器栏卡`（`core/battle/weapon_exec.gd:126-138`）的「字典按引用比」分支写成了：

```gdscript
		if 标识 is Dictionary:
			return c if is_same(c, 标识) else null      ← 在第一张卡上就直接 return，不会再看后面的卡
```

所以**传字典进来时只认武器栏里的第一张**，别的都会返回 null（表现 = `打出主武器卡` 报「没有这张主武器卡」）。
UI 传的是 id（字符串），所以玩家碰不到；我第一版策略传字典时踩到了，176 场里 45 处失败。
我没有改它（RT-2 只允许 RT-2a 一处生产改动），策略改成传 `str(卡.id)`（与界面 `手牌键` 同口径）。
**建议 RT-3 顺手修**（一行：把 `return ... if ... else null` 换成 `if is_same(...): return c`）。

### 9. 未决问题（停下等验收）

1. **`波次` 没有迁过来**（按补充要求 2 的原文：其余各组就是 `Setup.开局(...生产() ∪ {藏品})`，不带 `波次`）。
   所以原生样例里**没有〔增援〕事件**，而生产节点战是有的（`NodeResolver.开战` 会算 `增援波次(编成, 0)`）。
   若你要覆盖增援：我在 `inputs.json` 里已经留了 `编成`，加一行就能补一组带波次的样例（重录约 2 分钟）。
2. **112 张「一次都没打出过」的卡**（§6 附录）—— 要不要补样例请你判断；我没有为了凑覆盖率去改输入。
3. **索引页 token 余量只剩 29**（7,971 / 8,000）。RT-3 还要删文件、RT-4 还要改 RouteMap 文案 ——
   很可能顶破上限。要不要现在就把索引页的某一段搬到明细页，请示口径。
4. **整套测试从约 100 秒变成 217.6 秒**（原生样例重跑占 117 秒）。可选的软化办法：
   给 `test_native_goldens` 加一个环境变量开关（默认仍全跑）、或按文件拆成 3~4 个测试文件让 CI 并行 ——
   但那就不是"逐场重跑"了，我没自作主张。
5. **`_battle_options_cache` 删除后的行为等价性**：三套入口的取值都实测过，但 `roster_facade` / `run_facade` 里那 9 处赋值
   是「招募 / 丢券 / 晋升 / 选战术牌 / 移动 / 换层 / 结算」之后刷缓存用的 —— 现在全部删掉，那些动作不再预先算选项。
   选项是**纯函数**（不读也不写内核状态），所以等价；若你认为还是留一个显式的 `_build_battle_options()` 预热更稳，我加回去。

**RT-2 到此停下**，等验收。RT-3 未开工（闸门 G 的作者签字已在下方记录，但按批次顺序要等 RT-3a 做完才进闸门 G）。

> **本节第 9 小节的第 1、2 条已被下面的「RT-2 补录」处理**（补波次 / 补连携·筹码区 / 主武器轮换），以那一节为准。

---

## RT-2 补录（`[RT-2补]`：策略补两区 + 主武器轮换 + 补波次 + 重录）

- **提交号**：`[RT-2补]` 那一条（本节与代码 / 样例在同一个提交里）。
- **⚠ 先说一件事**：施工单里**没有「RT-2 验收结论」这一节** —— 我把 `施工单-RT-旧口径退役-DS4.1F.md` 的标题全列了一遍，
  只有 `## RT-1 验收结论（Claude，2026-10-19）`、`## RT-2 补充要求`、下面的 `## 作者签字记录`，没有 RT-2 的验收结论
  （文件 mtime 仍是 19/10 13:55，即 RT-1 验收那一次）。
  **所以我是按你这次消息里点名的 5 条做的**：① 连携区 ② 筹码区 ③ 主武器轮换（状态只在策略局部）④ 按生产同一个函数补波次
  ⑤ 重录两次逐字节相同 + 重跑覆盖自检 + 回执贴新旧缺口对比与「增援」条数。若施工单里本该有更细的口径，请补上我再对齐。

### 1. 策略补「连携」「筹码」两个区

- `ctx.公有手牌` 现在按品类**分桶**（`Btl.是衍生攻击卡` / `种类 == "连携"` / `AtxChips.是筹码牌（卡类 == "筹码牌"）` / 其余）：
  衍生走 `区_衍生`、连携走 `区_连携`、筹码走 `区_筹码`、其余仍走 `区_公有` —— 四个桶**互斥**，不会一张牌被两条路算两次。
- 每台机体的看牌顺序变成：**大招槽 → 副武器 → 衍生 → 精神 → 连携 → 筹码 → 公有 → 主武器**
  （新增两个区插在「精神」与「公有」之间，原顺序的相对次序没动）。
- 出牌仍调门面背后的核心函数：连携 → `DeckFlow.打出连携牌`（门面 `_打连携牌` 调的就是它）、
  筹码 → `AtxChips.打出筹码牌`（门面 `打出精神或公有牌` 内部也是转给它）。
- 判定仍只用 `CardPlay.不可打原因`，而且**它本来就是精确的**：连携的「只有秘银成员能打」由
  `MithrilV03Cards.卡不可打原因`（`core/battle/mithril_v03_cards.gd:255`）给出，筹码由 `AtxChips.区规则门槛` 接管 —— 所以没有「试着打」。
- **实测**：连携牌 **76 次**、筹码牌 **9 次**（补录前两个区都是 **0**）。

### 2. 主武器轮换（状态只在策略局部）

- `NativeGoldenPolicy` 从「全静态」改成**一场一个实例**（`NativeGoldenRunner.run()` 里 `NativeGoldenPolicy.new()`），
  新增 `var _主武器轮换 := {}`（单位键 → 下一回合从武器栏第几张开始看）。
- 环形扫描武器栏，**只打 `不可打原因 == ""` 的那张**；打成功才把游标 +1。
  这个游标**只活在这个对象里**：不进 `ctx`、不落存档、不读不写任何全局；`选择rng` 仍恒为 **0**。
- **效果**：主武器出牌 677 → **701**；天人 `CB1_W2..W5 / CB2_W2..W4 / CB3_W4 / CB4_W3 / CB4_NW3 / CB5_W2` 与 `CB1_S8 / V3_U2_W4`
  共 **13 张**从缺口里消失（详见 §5）。

### 3. 波次（按生产同一个函数）

- 用**生产同一个函数** `NodeResolver.增援波次(条目, 0)`（生产里是 `node_resolver.gd:373` 调的）。
- 编成条目从 `Db.catalog.stages()` 里**按「敌方规格」逐条对上**：旧样例导出的 `输入.编成` 大多只剩 `{层, 类型}`
  （101 条连 `编号` 都没有），而且 `层` 被导成了 `null` 而编成表里是 `1`，所以比对时**忽略 `层`**，其余
  （键 / 位 / 等级 / 强化 / 词条）逐项相同才算命中。**唯一定位 174 条，0 条多义，2 条认不出 → 那 2 条不带波次（不猜）。**
- **⚠ 但「增援」事件仍然是 0 条**，原因不在录制：
  `ctx.波次` 在单机牌组模式下**没有任何消费者** —— `Flow.增援()` 只被 `Flow.回合开始`（`core/battle/flow.gd:17`）调用，
  而新模式走的是 `BattlePhaseFlow.开始我方阶段`（`phase_flow.gd:70`），`打一回合` 在单机牌组下第一行就 `return`，
  所以 `Flow.回合开始` 一次都不会跑 → 波次虽进了 `ctx.波次`（`setup.gd:556`），却没人处理。
  **这是新模式的规则缺口，不是样例的问题。** 要真出增援得在内核补一处「阶段初处理波次」的钩子 ——
  那是生产代码改动，超出 RT-2 的授权，**我没动**。
- **连带影响（请验收时一并裁决）**：一旦以后补上那个钩子，这 174 场的原生样例**会变**（多出 `增援` 事件），
  到时要么重录、要么按闸门 G 的办法登记。现在把波次写进选项的唯一意义是「先按生产口径把输入铺好」。

### 4. 重录两遍逐字节相同 + 覆盖自检（新数）

**两遍 sha256**（`tools/record_native_golden.gd` 连跑两次，不删文件；`Compare-Object` 无差异）：

```
character.json       14818e3088b744d2974c36991e5590500f04f4156851fecc48be8041ee10af9f
default.json         2a63551af01d5bcb7db00835369c2d40f1d86ca362098825fac32016cfa0ecef
faction_ATX.json     07f2aa19bdbbb457fb16baf5f8ee030d3e7d881835a6158d2fcdf3ff5ac911e2
faction_卫星国防军.json 49e4475f237f6810d9f43ff41fac7572988b66929a68c0a19b8bc21c72fc6e4c
faction_天人.json      1dd6bfb13a9e0d1ef4ae857843e847c79e28c99bead466fe09a11967e3dcc0fa
faction_影世界.json    cbce69c50a305b63433ac55694c7abfa45d8181bf2a339c73719579235a78c5a
faction_月球王国.json  46c43e9eb2dfc2562f70dc2dd51b40554b5a4da4851f2cbb03c4566bafee88db
faction_流星小队.json  77806e0b0e36dcfe4cba97b561d8622c8b812b377aa6c02771572f8c5591fe83
faction_秘银.json      66a2c9cb816122c70829a42c9437321652d147958b88624d4e86433eeca6087e
inputs.json          41e1aaa963d038478ab4b4f02caf553fbb95a6b0edc32a013c90c1cc08a4141b   （输入没变）
quick.json           47db45604b59b755dc3dce50da2c55bf7b5ce1c62ae22d81fa5c01afe10ba92d   （快速测试组未受影响）
relic.json           44b74620d598744c8725caf20c7f0f09727a3bbc45d3dd4061382998768caf3c
→ 两遍 12 个文件全部逐字节相同
```

> 只有 5 个文件变了（`character` / `default` / `faction_天人` / `faction_秘银` / `relic`）——
> 另外 5 个样例文件的 sha256 与补录前**完全一样**，说明新加的两个区与轮换在那些场里没有改变任何出牌顺序（ATX 那 9 次筹码本来就走公有路打出来了）。

**覆盖自检（新）**：

```
[覆盖] 场数 176 · 事件 31953（补录前 31463，+490）· 结局 { "胜": 133, "败": 43 } · Boss 场 22 · 带波次 174 场 · 增援事件 0 条
[覆盖] 出牌按区 { "专属精神牌": 4073, "公有牌": 829, "主武器卡": 701, "大招槽卡": 561,
                  "衍生攻击卡": 529, "副武器卡": 388, "连携牌": 76, "筹码牌": 9 }
       （补录前：专属精神牌 4034 · 公有牌 905 · 主武器卡 677 · 大招槽卡 555 · 衍生 530 · 副武器 387 · 连携 0 · 筹码 0）
[覆盖] 打出过的卡 id 249 个（补录前 238）· 卡库 345 个 · 事件类型仍 82 种（增援没出现）
[覆盖] 连携相关事件：连携牌 76 / 连携抽牌 65 / 连携放入 46 · 筹码相关：筹码牌 9 / 赌局 10
```

**大小**：合计 **10.99 MB**（补录前 10.65 MB）；最大仍是 `default.json` 2,018.6 KB，全部 < 3 MB。

### 5. 新旧缺口对比（你要的那张表）

**112 张 → 101 张（净减 11）**。

| 变化 | 张数 | 卡 id |
|---|---:|---|
| **从缺口里消失**（这次打出来了） | 13 | `CB1_S8` `CB1_W2` `CB1_W3` `CB1_W4` `CB1_W5` `CB2_W2` `CB2_W3` `CB2_W4` `CB3_W4` `CB4_NW3` `CB4_W3` `CB5_W2` `V3_U2_W4` |
| **新进缺口**（上次打出来、这次没打） | 2 | `V3_L2_TESSA` `V3_U7_W2` |

- 消失的 13 张里有 12 张是**天人的主武器 / 精神牌**（`CB*`）—— 正是主武器轮换的效果；
- 新进缺口的 2 张是秘银 v0.3 的牌：轮换换了主武器打法，这两张这次没轮到（下一轮样例若想覆盖，可以调输入或再加轮换策略）；
- **筹码牌 7 张（`ATX_CHIP_*`）仍在缺口里**：筹码区这次确实打了 9 次，但打来打去是手里那几张（小筹码回库后还会再抽到），
  7 个 id 一次没抽到 —— 它们是「抽到才打」的，不是策略顺序能决定的。

### 6. 门禁结果

```
$ godot --headless --path godot --script res://tests/run_tests.gd
机甲指挥 · Godot 测试：48 个测试文件
…
[test_native_goldens] ✓ 11
✓ 全部通过：3960 项                （退出码 0；整套 217.4 秒，与补录前持平）

$ node godot/tools/build_godot_routemap.mjs          → violations = [] ✓
$ node godot/tools/build_godot_routemap.mjs --check  → EXIT=0（索引页 7,971 / 8,000）
```

### 7. 未决问题（停下等验收）

1. **施工单缺「RT-2 验收结论」一节**（见本节开头）—— 请补上，或确认我按消息理解的 5 条就是全部。
2. **增援事件 = 0 的根因在新模式内核**（`Flow.回合开始` 在单机牌组下从不被调用）。要不要在 RT-3b 补一处「阶段初处理波次」？
   补之前得先定：已经录好的 174 场样例怎么处理（重录 / 登记差异）。**我没有动内核。**
3. **101 张缺口**（筹码 7 张 + ATX `_P` 升版牌 + `F_ATX_V2_*` 9 张 + `U_ATX_*`/`U_DUO_*` + 秘银 `V3_*`）—— 要不要补样例，请你判断。

---

## RT-3-fix / RT-3a / 闸门 G（三个提交，做到闸门 G 就停）

按施工单「RT-2 补录验收结论 → RT-3 可以开工」的顺序做：`[RT-3-fix]` → `[RT-3a]` → `[闸门G]`。**RT-3b 未开工。**

### 1. `[RT-3-fix]` `118f2b9` —— 修 `_找武器栏卡` + 回归测试

- **改了一行**（`core/battle/weapon_exec.gd:132-136`）：
  ```gdscript
  		if 标识 is Dictionary:
  			if is_same(c, 标识):
  				return c
  			continue              ← 原来这里是 `return c if is_same(c, 标识) else null`（在第一张卡上就返回）
  ```
- **新增 `tests/unit/test_weapon_bar_lookup.gd`（10 条）**：传 id 找第 2 张 / 传第 1 张字典 / **传第 2 张字典** / 传最后一张字典 /
  传不在栏里的空字典 → null / 传不存在的 id → null / **用字典端到端调 `Btl.打出武器栏卡` 真能打出去**。
  夹具用 `SessionBattleOptions.生产(null)` 开局 —— 武器栏只在「卡牌流转」开着时才拆得出来（我第一版夹具只给了 `单机牌组`，武器栏是 null，测试自己抓到了）。
- **门禁**：全量 **3970 项**全绿（48 个测试文件）；`test_native_goldens ✓ 11` —— **原生样例逐条不变**（策略传的是 id，符合预期）。

### 2. `[RT-3a]` `7bbebb0` —— 旧黄金样例退役

| 类别 | 内容 |
|---|---|
| **删** | `tests/golden/battle/*.json`（5 个文件 / **8.0 MB** / 168 场）、`tests/golden_runner.gd`、`tests/unit/test_golden_battles.gd`、`tests/unit/test_battle_rules.gd`、`tools/export_golden.mjs`、`tools/export_data.mjs` |
| **删代码** | `Btl.手牌装填_JS参考` 常量 + `card_pool.gd` 里 `手牌装填 == "JS参考"` 的分支（**正式装填从此是唯一分支**：已选 → 基础激励 → 角色 → 势力 → 职业 → 统帅，取前 6 张，多出的进候补初始牌）+ `setup.gd` 注释里那半句 |
| **搬走** | `tests/golden/README.md` → [`协作/归档/黄金样例-旧README（JS 参考版导出）.md`](归档/黄金样例-旧README（JS 参考版导出）.md)；`已接受差异表.md` → [`协作/归档/黄金样例-已接受差异表（D-01~D-03）.md`](归档/黄金样例-已接受差异表（D-01~D-03）.md)（**逐字搬家，没删内容**） |
| **新增** | [`tests/golden/README.md`](../../godot/tests/golden/README.md)：现在保留什么（native / card_tables / run_vectors / rng_vectors）、怎么重录、白名单口径、**差异登记区** |
| **保留** | `rng_vectors.json`、`run_vectors.json`、`test_run_golden.gd`、`test_run_core.gd`、`js_ref.mjs`、`export_run_golden.mjs`、`gen_rng_vectors.mjs` |
| **顺带改** | `godot/README.md`：删两条导出命令 + 加一句「`data/js/*.json` 从 M2 起由 Godot 侧直接维护，没有导出脚本了」+ 原生样例的重录命令；进度行去掉「168 场」改指原生样例与归档。`build_godot_routemap.mjs`：`COMMENT_RATCHET` 去掉两个被删的测试；§1 速查表锚点 `golden_runner.gd` → `native_golden_runner.gd`。`extract_native_inputs.gd` / `export_run_golden.mjs` 里指向旧路径的注释各改一句 |
| **测试数变化** | **删 27 条**（`test_golden_battles` 17 + `test_battle_rules` 10），**迁 0 条**（「同种子两遍逐字相同」早在 RT-2d 就落在 `test_native_goldens.gd` 的 `_同种子两遍` 里）→ 3970 → **3943 项**，47 个测试文件 |

**门禁**：3943 项全绿；`test_native_goldens ✓ 11`（**176 场原生样例逐条不变**，这就是 RT-3a 的验收）；`--check` EXIT=0；整套 **179.5 秒**。

### 3. `[闸门G]`（本节所在的提交）—— 新模式不再建旧战术牌池

**改了 5 处，都只是「新模式跳过」，没有删任何函数**（那些留给 RT-3b）：

| 文件 | 改法 |
|---|---|
| `core/battle/setup.gd`（开局） | `if Params.战术卡牌开(ctx) and not 单机开:` —— 新模式不再生成 `战术牌池 / 战术手牌 / 待触发战术牌 / 候补初始牌 / 已打出战术牌`；**`ctx.战况计数` 挪到这段外面**（键集合不变，`满手牌推迟数` 保留键、值为 0），`ctx.气势` 也不再被这段设成 25 |
| `core/battle/setup.gd`（`endTurn`） | 战术手牌冷却 + `检查条件发牌("回合结束")` 那段加 `and not Params.单机牌组_开(ctx)` |
| `core/battle/flow.gd:46` | 回合开始那段的 `候补补位` + `检查条件发牌("回合开始")` 加 `and not Params.单机牌组_开(ctx)`（`Flow.回合开始` 本来就只在旧模式跑，双保险） |
| `core/battle/morale.gd:40` | `气势变动后发牌` 在单机牌组下直接 `return []` |
| `core/battle/fac_cb.gd:115` | 手动 TRANS-AM 那条 `检查条件发牌` 在单机牌组下不走 |

> 注释只加了 3 行：`morale.gd` 那句加上去就把它顶过 15% 阈值（规则 ⑧ 判红，`COMMENT_RATCHET` 登记文件），所以**那一处不留注释**，理由写在回执与 README。

#### 3.1 闸门 G 的验证（按「闸门 G 的验证方法」1~5 步做，全部通过才重录）

1. 删前把当时的 `native/` **整份复制**到 `tests/golden/_gateG_before/`（12 个文件，`default.json` 的 sha256 与 `native/` 一致，抽查过）。
2. 打完上面 5 处补丁后重录一份到 `native/`。
3. 新脚本 [`tools/compare_gate_g.gd`](../../godot/tools/compare_gate_g.gd)：把「删前」那份里 `类型 == "发牌"` 的事件去掉，
   再与「删后」**逐条比事件（含 `_rng`）**、**逐项比回合摘要**、比结果，只报第一处分叉。
4. 输出（**这就是签字依据**）：

```
  character.json             6 场 · 去掉   25 条「发牌」 · 分叉 0
  default.json              47 场 · 去掉  188 条「发牌」 · 分叉 0
  faction_ATX.json          12 场 · 去掉   48 条「发牌」 · 分叉 0
  faction_卫星国防军.json        12 场 · 去掉   48 条「发牌」 · 分叉 0
  faction_天人.json           12 场 · 去掉   48 条「发牌」 · 分叉 0
  faction_影世界.json          12 场 · 去掉   59 条「发牌」 · 分叉 0
  faction_月球王国.json         12 场 · 去掉   48 条「发牌」 · 分叉 0
  faction_流星小队.json         12 场 · 去掉   41 条「发牌」 · 分叉 0
  faction_秘银.json           12 场 · 去掉   48 条「发牌」 · 分叉 0
  quick.json                 9 场 · 去掉   36 条「发牌」 · 分叉 0
  relic.json                30 场 · 去掉  121 条「发牌」 · 分叉 0

[闸门 G] 合计 176 场 · 去掉 710 条「发牌」 · 分叉 0
✓ 通过：除了被去掉的「发牌」事件，其余事件（含 _rng）、回合摘要、结果**逐条相同**
```

5. **没有出现「发牌」以外的差异** → 按第 6 步正式重录（重录后连跑两次仍**逐字节相同**，sha256 见下），
   并在 [`tests/golden/README.md`](../../godot/tests/golden/README.md) 的「登记过的差异」里登记了一行。

#### 3.2 重录后的数（闸门 G 版）

- 事件 **31953 → 31243（−710，正好 = 去掉的 `发牌` 条数）**；事件类型从 82 种降到 **81 种**（`发牌` 整类消失，其余类型条数**一条没变**：
  攻击 6103 / 上张打出牌 6264 / 专属精神牌 3949 / 主武器卡 2297 / 标定 983 / 武器栏 704 / 击破 1092 / 回合 642 … 与删前逐项相同）。
- 结局 **胜 133 / 败 43** 不变；Boss 22 场不变；带波次 174 场不变；**出牌按区完全不变**（连携 76 / 筹码 9 / 主武器 701 …）；
  **缺口仍是 101 张**（同一份清单）。
- 两遍 sha256：

```
character.json        b8a38962f6c956b34bdc2f1ad366ff33416f79fcebf5bf369fc89e6e6d70546c
default.json          c6bf7c5ebdcc981e4766057840c4201b27ac1c2247105e72390bcbfd9eff6f47
faction_ATX.json      4e5956068dca9e71f32a6c5034d22a43bfea054f519d426109a5e6ff439cb459
faction_卫星国防军.json 76468f6116a3544fbcef3834587eebd2cee1c7e7e067ae5ac725e9a46db5795e
faction_天人.json      70c0fa1eb434a410b1ddf59146b4ab4b7c2a9530e8d97e664428337e83767fc1
faction_影世界.json     62a644f5029e8458cd61c08c212cbf54526ee4d9ef757a2a7f0ebe8b9ba79969
faction_月球王国.json   c30bf992e068b0917bc36ed65e05e04d236b0b5f0b96e920126d78027d3772ac
faction_流星小队.json   6994c44f277a8749a84e00d9f059160a0cd07a4676a02ea4cc9aeed545f7d56e
faction_秘银.json      87cf98f85664840ffc8f2d403142b1ecccccf1639831ecedcf79118b97fa87a7
inputs.json          41e1aaa963d038478ab4b4f02caf553fbb95a6b0edc32a013c90c1cc08a4141b   （没变）
quick.json           dbb146c60bb08befd208acfdacb993a866a615885ab56edfb9b30ba079418b98
relic.json           72b59a5c7f474ea17503d269f89ea50fba670063623b7e68d425bd932f49887e
→ 第二次录制与第一次逐字节相同（Compare-Object 无差异）
```

#### 3.3 门禁

```
$ godot --headless --path godot --script res://tests/run_tests.gd
机甲指挥 · Godot 测试：47 个测试文件
[test_native_goldens] ✓ 11
✓ 全部通过：3943 项                （退出码 0；整套 177.7 秒）

$ node godot/tools/build_godot_routemap.mjs          → violations = [] ✓
$ node godot/tools/build_godot_routemap.mjs --check  → EXIT=0（索引页 7,975 / 8,000）
```

### 4. 已知缺口（按 RT-2 验收结论：本单不修，另开单）

- **新模式仍然不会出现增援**（`ctx.波次` 无消费者，见 RT-2 补录 §3）。闸门 G 没有改变这一点（`增援` 事件仍是 0 条）。
  按你的裁决：本单只拆不改，RT-4 收尾后另开一张小施工单「新模式补增援」。
- `F_ATX_V2_*` 9 张 / `U_ATX_*` / `U_DUO_*` / `V3_*` 里没出场的卡：**留给 RT-3c 的核查**（你那节 §6 与「101 张缺口」的要求），本批没有动。

### 5. 交回前的状态

- **索引页 7,975 / 8,000（只剩 25 token）** —— RT-3b 只要再加几行就会顶破，届时按你已给的预先授权把 §0.5 的规则 ⑧ 警告清单整段搬到明细页。
- **RT-3b 未开工**（`打战术牌` 全链路 / 旧手牌五字段 / `runTurn` / 旧手牌栏 / `CARD_OPS` 里那 24 张 / `气势` 统计都在下一批）。
- 工作区里剩下的未跟踪/未提交项都是历史遗留（`CR-*` 回执、`施工单-CR*`、`check_strip_diff.mjs`、`clean_history_comments.mjs`），**与本单无关，我没有碰**。

**RT-3-fix → RT-3a → 闸门 G 到此停下**，等验收。RT-3b 等你点头再开。

---

## `[docs]` 补提交 CR 施工单与回执（`9437f6e`，就是「RT-3b 开工前先入库」那一件）

按你的第 2 条提醒，把工作区里那批文档记录入库，**一个 `.gd` 都没动**（`godot/core` `godot/session` `godot/presentation` `godot/tests` 零改动）：

| 类别 | 文件 |
|---|---|
| 回执 | `CR-1回执.md`（含 `CR-1附件/test_cr1_review_fixes.gd` 原样附件）、`CR-3回执.md`、`CR-4回执.md` |
| 施工单 | `施工单-CR1-P1修复与Token瘦身示范-ARGON.md`、`施工单-CR2-出牌与攻击管线统一+规则钩子注册表-ARGON.md`、`施工单-CR3-收尾+大招槽分派+换装栈+大文件拆分-ARGON.md`（**补上工作区里那处未提交的改动**）、`施工单-CR4-ATX与秘银卡表抽数据+注释清理-ARGON.md` |
| 工具 | `godot/tools/check_strip_diff.mjs`、`godot/tools/clean_history_comments.mjs`（CR-4 用过的两个） |
| 顺带 | 本单的 `施工单-RT-旧口径退役-DS4.1F.md`（RT 回执要引它，本来也没入库） |

- 11 个文件（9 新增 / 1 修改 / 2 工具），`git diff --cached` 里没有任何 `.gd`。
- 工作区还剩两篇不属于 `CR-*` / `施工单-CR*` 的文档**没有入库**：`Godot-CodeReview报告-ClaudeOpus5.5.md`、`任务单-殖民卫星军v0.1与觉醒QTE锁定链-ARGON.md`。它们不属于这次交办的范围，等你说了再收。

## RT-3b（决策表第 4 / 5 / 10 行，第 6 行殿后；每项一个提交）

### 1. `[RT-3b-1]`（本节所在的提交）—— 决策表第 4 行：**旧模式整套**删除

**生产代码删了 13 个文件里的 12 段函数 / 大块，净 −831 行 / +12 行**（多出来的 12 行是搬不走的注释改写与一处空体收尾）：

| 文件 | 删了什么 |
|---|---|
| `core/battle/setup.gd` | `runOverwatch`（压制射击，只有 `runTurn` 调它）、`runTurn`（旧的速度混排回合循环）、`打一回合` 的**旧分支**（现在 = `Btl.结束我方回合`，一回合就是「阶段制我方 → 敌方 → 下一回合」）、`endTurn` 里只属于旧模式的那段（战术手牌冷却 / 待触发池冷却 / `检查条件发牌("回合结束")`）、开局那段旧牌池构造（`ctx.战术卡牌开` / `ctx.气势 = 25` / 战术牌池 / 战术手牌 / 待触发战术牌 / 候补初始牌 / 已打出战术牌 / `满手牌推迟记录`） |
| `core/battle/flow.gd` | `回合开始`（增援 / 词条到点自爆 / 势力回合开始 / 气势 / 政治回合 / 指挥 / 条件发牌那一段；**唯一调用者是 `打一回合` 的旧分支**）、`结算一个目标` 里的「攻击后」条件发牌与 `不发攻击后牌` 选项 |
| `core/battle/morale.gd` | `气势变动后发牌`（+ `加气势` 里那次调用） |
| `core/battle/card_pool.gd` | `生成队伍牌池`、`_装填档`、`候补补位`、`检查条件发牌`、`记满手牌推迟`、`是否满足卡牌触发条件`、`_手牌下标`（**−274 行**） |
| `core/battle/card_exec.gd` | `打战术牌` 整个函数（**−150 行**，含 `card_exec.gd:31-43` 那段「公有手牌衍生卡」分支） |
| `core/battle/btl.gd` | 上面那些函数在门面上的同名转发（9 条，−18 行） |
| `core/battle/fac_cb.gd` | 手动 TRANS-AM 那条 `检查条件发牌`（闸门 G 加的守卫随调用点一起没了） |
| `session/battle_flow.gd` | `_打战术牌`（−30 行） |
| `session/game_session.gd` | `play_tactical_card` + `_打战术牌` 转发（−6 行） |
| `presentation/battle/hand_panel.gd` | `_画手牌` 的旧分支（`hand_panel.gd:104-159`）、`_画候补`、`候补联动`、`_点候补`、`_是新发牌`、`_刷新新发牌提示`（−103 行） |
| `presentation/battle/hand_card_item.gd` | `_建手牌卡`、`_层级文字`（只服务旧手牌那张卡，−64 行） |
| `presentation/battle/log_panel.gd` | `_点手牌`（就是那个 `play_tactical_card` 调用点，−11 行） |
| `presentation/battle/battle_view.gd` | 上面这些函数在 `BattleView` 上的同名转发（−8 行） |

**`card_exec.gd:31-43`「公有手牌衍生卡」那段的调用者核查（按你的要求，删前用 `route_query` 查的）**：

```
# route_query：「打战术牌」（删前现扫）
■ 函数 / 常量命中 2 个
  符号  Btl.打战术牌            签名 static func 打战术牌(ctx, cardId) -> Dictionary   外部调用 13 次
  符号  BattleCardExec.打战术牌  同签名                                              外部调用 1 次
■ 全仓调用点 [现扫] 14 行（涉及 6 个文件）
  core/battle/btl.gd:218            return BattleCardExec.打战术牌(ctx, cardId)          ← 门面
  session/battle_flow.gd:316        var r := Btl.打战术牌(session.battle_ctx, card_id)   ← 唯一生产调用者
  tests/unit/test_mithril_v02_cards.gd(3) / test_mithril_v02_core.gd(7)
  tests/unit/test_run_core.gd(1) / test_unit_deck_system.gd(1)
```

那段分支的**唯一入口**是 `Btl.打战术牌` → `SessionBattleFlow._打战术牌` → `GameSession.play_tactical_card` → `LogPanel._点手牌`；
而 `_打战术牌` 在 `battle_flow.gd:301-314` 先要求这张牌在 `session.hand_cards()`（= `ctx.战术手牌`）里，**新模式里那个数组根本不存在（恒空）**，
所以走到 `打战术牌` 之前就已经 `return {"ok": false, "为什么": "手牌里没有这张牌"}` 了 —— **生产上不可达**。
新模式下真正打公有牌/衍生牌的口子是 `打出精神或公有牌` / `打出衍生攻击卡`（`card_exec.gd` 里那两条，**一行没动**）。
`play_tactical_card` 的生产调用点也只有 `log_panel.gd:263` 一处（其余全在测试里），一并删了。

**测试**（同一批提交，删测试跟着被删的代码走）：

- **整删 2 个文件 194 条**：`test_mithril_v02_core.gd`（55）、`test_mithril_v02_cards.gd`（139）—— 它们测的就是本批删掉的
  `打战术牌` / `检查条件发牌` / `是否满足卡牌触发条件` / `Flow.回合开始` / 旧手牌五字段。**排期上说一句**：决策表第 7 行原定
  RT-3c 才删这两个，但它们的被测代码在本批就没了（`秘银v02` 的牌池初始化本来就在旧牌池那一段里），所以跟着走了。
  第 7 行剩下的部分（`mithril_v02_cards.gd` 里还被 v0.3 用到的函数搬走、`秘银v02开` 退役）仍然是 RT-3c 的活。
- **迁入口 22 处**：`start_quick_battle(种子)` → `开始快速测试战斗(GameSession.快速测试_秘银, 种子)`（决策表第 12 行的口径）。
  这条不只是「换个入口」——旧入口那场是「默认五人队 B1/B2/CB4/CB2/M1（Lv10）」，新入口是「秘银五人 U7/U1/U6/U2/U8（Lv30）」，
  所以点名 `B1` 的断言改成了 `_我首键(s)`，对 Lv10 / 名册血比有依赖的按新编成改。
- **`Setup.打一回合` 现在必须先开单机牌组**：它就是 `Btl.结束我方回合`，而 `结束我方回合` 第一行 `if not 单机牌组_开: return`。
  `test_run_core` 直接调 `NodeResolver.开战()`（绕过 `GameSession._build_battle_options`），要自己把 `{"单机牌组": true}` 传进去，
  否则四层全败 —— 这一条最隐蔽。
- **删的断言（−296，逐条理由见下）**：

| 文件 | 基线 | 现在 | 变化 | 主要删了什么 |
|---|---:|---:|---:|---|
| `test_mithril_v02_core.gd` | 55 | — | −55 | 整文件（被测代码已删） |
| `test_mithril_v02_cards.gd` | 139 | — | −139 | 整文件（同上） |
| `test_session_flow.gd` | 274 | 240 | −34 | 段 1 的 14 条「战术手牌有几张 / 候补有几张 / 本回合已打出几张 / 点手牌打不打得出」+ 段 14「UX-2 发牌来源机体」整段 20 条（挂在旧手牌与**已清零的 `发牌` 事件**上） |
| `test_presentation_layout.gd`（汇总） | 915 | 858 | −57 | `test_layout_factions` 段 8「秘银 v0.2 连携」33 条（`_建秘银战()` 往 `ctx.战术手牌` 塞牌 + `play_tactical_card`）、`test_layout_tooltip` 段 10「发牌来源 / 悬停联动」13 条 + 段 3b 旧手牌 tooltip 9 条、`test_layout_log` 段 5 两条 0==0 空断言 |
| `test_unit_deck_system.gd` | 215 | 210 | −5 | 段 ⑩「第三条路 `Btl.打战术牌`」那 5 条 |
| `test_presentation_smoke.gd` | 234 | 231 | −3 | D-01「候补区里有内容 / 写出 N 张 / 列出第一张牌名」 |
| `test_ux5_ux6_feedback.gd` | 56 | 53 | −3 | 「本回有 N 个 `card_deal` 发牌帧」等 3 条（见下面缺口） |
| 其余 36 个文件 | — | 逐项不变 | 0 | 入口换了、断言一条没动（`test_run_core` 67 / `test_session_run` 25 都是 0 变化） |

  **共有 12 条断言不是删而是「原意迁到新模式口子」**（打出一张牌成功 / 打一张不在手里的牌被拒 / 出牌被 `_record_action` 记下 /
  手牌栏卡数 == 能打张数 / 上排下排张数 …）：判据换成 `upper_hand_cards()` / `lower_hand_cards()` / 四个出牌口子
  （`打出主武器卡` `打出副武器` `打出衍生攻击卡` `打出精神或公有牌`），断言数因此是净减。

- **测试文件数 47 → 45**：删掉 `test_mithril_v02_cards.gd` / `test_mithril_v02_core.gd` / `test_layout_factions.gd`
  （最后一个的断言本来就在 `test_presentation_layout.gd` 的 `套件们` 里跑，删完只剩 18 行空壳 + 一行 info，留着没有意义），
  新增 `test_battle_screen.gd`。
- **`test_presentation_smoke.gd` 拆文件**：它被这一批的迁移撑到 **17,622 token**，顶破了 `SIZE_RATCHET` 登记的 16,725
  （规则 ⑦ 只许降不许升）。按 `godot/README.md`「文件体积约定 2：先拆再加功能／拆分是纯搬家」，
  把**段 7「真开一局战斗再验」整段**（137 行 / 27 条断言，段号与断言文字一个字没改）搬到新文件
  `test_battle_screen.gd`（172 行 / 2,962 token / 注释 16.76%），smoke 留 204 条（19.22% 注释）。
  **没有删任何断言**，`231 = 204 + 27` 对得上。
- **顺带把三处棘轮卡回阈值以内**（同批提交，`build_godot_routemap.mjs` 的登记表只删条目、没上调任何数字）：
  `test_session_flow.gd` 注释 20.64% → 16.96%、`core/battle/card_pool.gd` 19.07% → 12.19%（**只删注释，代码 token 零增删**）、
  `SIZE_RATCHET`/`COMMENT_RATCHET` 里三个已删文件的条目清掉（工具不再报「已不存在」）。
  §1 速查表两处失效锚点改指活着的符号：`flow.gd 回合开始` → `phase_flow.gd 开始我方阶段`、`card_exec.gd 打战术牌` → `打出精神或公有牌`。
  索引页按你的预先授权把 §0.5 的规则 ⑧ 警告清单压成「一行指针 + 总数」。

**门禁**：

```
$ godot --headless --path godot --script res://tests/run_tests.gd
机甲指挥 · Godot 测试：45 个测试文件
[test_native_goldens] ✓ 11
✓ 全部通过：3647 项                （3943 → 3647，−296；退出码 0）

$ node godot/tools/build_godot_routemap.mjs --check
架构分层审计：violations = [] ✓ · 缺锚点 0 处
索引页 7,909 / 8,000 token ✓（25,934 字节）· 明细页 37,045 token
EXIT=0
```

**原生样例：176 场逐条一致（`test_native_goldens ✓ 11`，没重录、没改、没删）。** 这一批一行都没碰新模式的行为。

**未决问题（按红线 7 交给你，本批没自己拍板）**：

1. **旧手牌那套「只读口子」还在，现在恒返回空**：`session.hand_cards()` / `hand_count()` / `bench_cards()` /
   `reserve_preview()` / `deck_remaining()` / `cards_played_this_turn()` / `cards_playable_now()` / `hand_card_status()` /
   `hand_status_all()` / `playable_hand_ids()` / `_找手牌卡()` / `_卡可打吗()` / `_补手牌连携状态()` / `_附来源()`
   （`session/display_helpers.gd` 约 250 行）读的就是被删掉的五个字段，`ctx.get()` 拿到 null → 全部返回 `[]` / `0`。
   它们还有活着的调用者（`live_monitor.gd` 的局面快照、`log_panel` 的底栏一行、`turn_card_summary()`、录像的 `state`），
   删了会连带动到「录像 / 监视」的口径，所以**本批只删字段、没删口子**。要不要在 RT-4 一起清掉，你定。
   同一批还留着两处读已删字段的**结算/展示**：`game_session.turn_card_summary()` 的 `"本场已打出"`、
   `_build_result_cache()` 的 `"本场战术牌"`（都恒 0 / 空数组，玩家看到的就是「没有」）。

2. **`Flow.回合开始` 删掉之后，它的被调者现在没有调用者**：`Flow.增援`（新模式至今不会增援，就是这条）、
   `Btl.词条到点自爆`、`Fac.势力回合开始`（SEED 觉醒 +5 / 月球光环 / TRANS-AM 冷却那几个钩子）、`Btl.战术回合`（全队憋大招）、
   `FacMoon.判定月球不动`、指挥 buff 那一段、`Flow.自然加`。这些是**游戏规则**，不是手牌机制 —— 按红线 1「只拆没人走得到的路」
   和红线 7「没写到的取舍停下来问」，我**没有删**，只删了入口。它们现在是「有实现、无调用者」，
   要么在「新模式补规则」那张单里重新接上，要么在 RT-4 里判死。**这一条和「新模式不会增援」是同一件事的两面。**

3. **`ctx.气势` 的开局值**：旧牌池那一段删掉后，新模式开局不再写 `ctx.气势`（闸门 G 之后本来也没写）。
   气势的读法还有 `card_pool.卡可打吗`、`_声明式触发`（都在旧牌那边）和几处展示 —— 这是**第 6 行**的活，见本节第 4 小节。

4. **发牌动画缺口（本单不做新动画）**：新模式没有「发牌」事件、`_手牌快照()` 读的 `hand_cards()` 恒空 ⇒
   `BattleView` 的 `card_deal` 帧**恒 0**，那段拆帧代码还在但走不到。`test_ux5_ux6_feedback` 删了 3 条依赖内核发牌的断言，
   **保留** 6 条「用手工合成的 `{"类型":"发牌"}` 输入验拆帧逻辑本身」的守卫。缺口记在这里，等你决定要不要补新动画。

5. **顺带发现（表现层既有行为，本批没动）**：单机牌组下「一回合」跨两个回合号（敌方那一半 + 新回合我方阶段初），
   而 `BattleFx` 末尾的 `_收窄到最后一拍()` 只留最后一个回合号那一组 ⇒ 用 `step_battle_turn()` 推一回合再 `refresh()`，
   动画层只画得到「待入库 / 大招解锁」，**一条攻击弹道都画不出来**。`test_layout_log` 段 11 因此把「推进一拍」
   改成了「打一张主武器牌」（新模式真正的一拍就是一次出牌）。要不要调整请你们判断。

6. **工作区里有一处不是本单写的改动**：`施工单-RT-旧口径退役-DS4.1F.md` 里被插进来 +8 行「省 token 的记录规矩
   （2026-10-19 起，RT-3b 开始执行）」，要求「RT回执.md 不再追加、改写成 `协作/架构/RT回执/RT-3b.md` 小文件」，
   还要求「把 `record_native_golden.gd` 的覆盖自检改成 `--coverage` 才打印，放进 RT-3b 的第一个提交」。
   这和本单交办的口径（**每做完一个提交就在 `RT回执.md` 追加一小节**）以及决策表的提交边界都冲突，
   所以我**没有执行**它，也**没有提交**它（原样留在工作区，`git diff` 里看得到）。若是你或 Claude 补的规矩，说一声我再照办。

### 2. `[RT-3b-2]`（本节所在的提交）—— 决策表第 5 行：`CARD_OPS` 里那 24 张旧战术牌的效果条目

**只删效果条目，数据一张没动**（红线 5）：`data/js/71-改动-5-参数入口.json` 的 `战术卡牌表` 仍是 **32 张**（其中 `C_*` / `F_*` 正好 24 张），
`core/battle/card_effects.gd` 的 `CARD_OPS` 从 **32 条降到 8 条**（**−130 行 / +2 行注释**），留下的正是在用的那 8 张：

```
2 统帅：CMD_ALL_OUT（全军总攻）· CMD_COVER（紧急掩护）
6 角色：U_CB1 · U_CB2 · U_M1 · U_A1 · U_S1 · U_B1        （上排专属牌，走 unit_exclusive_cards）
```

**删掉的 24 个 id（数据仍在，以后要复用得按新体系重写效果）**：

| 层 | 删掉的 id |
|---|---|
| 职业（12） | `C_HEAVY_1` `C_HEAVY_2` `C_GUARD_1` `C_GUARD_2` `C_VANG_1` `C_VANG_2` `C_SNIPE_1` `C_SNIPE_2` `C_CMD_1` `C_CMD_2` `C_SPEC_1` `C_SPEC_2` |
| 势力（12） | `F_SEED_1` `F_SEED_2` `F_METEOR_1` `F_METEOR_2` `F_MOON_1` `F_MOON_2` `F_CB_1` `F_CB_2` `F_ATX_1` `F_ATX_2` `F_MITH_1` `F_MITH_2` |

- **共用辅助一行没删**：`执行算子` 的算子实现、`选单位 / 匹配 / 取一 / 固定伤害 / 解令牌` 这些 8 张在用卡也在用的函数全留着；
  被删的只是「按 id 查效果组」的那 24 条**条目**。
- `card_effects.gd` 里留了一行注释指向数据出处（`data/js/71-改动-5-参数入口.json` 的 `战术卡牌表`），
  写明「以后要复用得按新体系重写效果」。
- **为什么现在删是安全的**：新模式的公有牌库在 `卡牌流转v01开` 时就把 `C_*` / `F_*` 那批旧 M3 占位牌整批退场、
  只留统帅牌（`setup.gd` 的 `_基础表公有牌入池吗`，注释里写的就是这条），生产选项 `生产(null)` 同时开了
  `单机牌组 / 秘银v03 / 卡牌流转`；所以这 24 条效果在生产里**一张也打不到**。

**测试**：`test_boundary.gd` 那条结构门禁原来断言「`CARD_OPS` 不多不少覆盖 32 张」，
改成 **「在用的 8 张必须一条不少 + 旧 24 张不许再有效果条目 + 不许有多余 id + 每条都要写「选」或「全局」」**
（多了一条反向断言，防止以后有人把 24 条悄悄加回来）。项数 **3647 → 3648**。

**门禁**：`✓ 全部通过：3648 项`（45 文件）· `[test_native_goldens] ✓ 11`（**176 场逐条一致**）·
`--check` EXIT=0（violations=[]、索引页 7,909/8,000）。

### 3. `[RT-3b-3]`（本节所在的提交）—— 决策表第 10 行：`Params.战术卡牌开` 退役

删前先按你的要求用 `route_query` 举证「已经没有生产调用点」（第 4 行那批一删，它的 6 个调用点全部跟着消失）：

```
$ node godot/tools/route_query.mjs 战术卡牌开

# route_query：「战术卡牌开」
■ 函数 / 常量命中 1 个
  符号  Params.战术卡牌开   [清单] core/battle/params.gd:524
        签名  static func 战术卡牌开(ctx: Variant = null) -> bool
        返回  bool · static · 外部调用 0 次 / 全仓 0 次
■ 全仓调用点 [现扫] 0 行（没有任何 `.gd` 代码里出现这个符号；注释/字符串里的不算）
```

同一个查询在 **RT-3b-1 之前**是 6 个调用点（这就是闸门 G 交接时说的「已没有生产调用点」的实际验证）：

```
# RT-3b-1 之前（删前现扫）
■ 全仓调用点 [现扫] 6 行（涉及 4 个文件）
  core/battle/card_pool.gd:313  if not (候补 is Array) or 候补.is_empty() or not Params.战术卡牌开(ctx):
  core/battle/card_pool.gd:483  if ctx == null or not Params.战术卡牌开(ctx):
  core/battle/setup.gd:80       if Params.战术卡牌开(ctx) and not Params.单机牌组_开(ctx):
  core/battle/setup.gd:611      if Params.战术卡牌开(ctx) and not 单机开:
  core/battle/flow.gd:47        if Params.战术卡牌开(ctx) and not Params.单机牌组_开(ctx):
  core/battle/morale.gd:41      if ctx == null or not Params.战术卡牌开(ctx) or Params.单机牌组_开(ctx):
```

- **删**：`core/battle/params.gd` 的 `战术卡牌开()` 整个函数（12 行）。全仓代码里再没有这个符号。
- **留下的两个同族读取口**（还有活着的调用者，不动）：`战术卡牌参数()`（`card_effects.gd:215` 用它的 `手牌总上限`）与
  `手牌上限(ctx, 键, 默认值)`（`card_effects.gd` / `mithril_v02_cards.gd` 还在用）。
  数据里的 `战斗结构.战术卡牌.开` 这个键本批**没有删**（`data/js` 一律不动；按 RT-4 的「唯一允许的 data/js 改动」处理）。
- 测试项数不变（3648），**176 场原生样例逐条一致**。
- 门禁：`✓ 全部通过：3648 项`（45 文件）· `[test_native_goldens] ✓ 11` · `--check` EXIT=0（violations=[]、索引页 7,909/8,000）。

### 4. `[RT-3b-4]`（本节所在的提交）—— 决策表第 6 行：`气势`（殿后）

---

## 作者签字记录

- **2026-10-19 · 闸门 G：同意。** 新模式不再建旧战术牌池（每场约 4 条看不见、打不出的 `发牌` 随之消失）。
  前提不变：删前删后各录一份原生样例，去掉旧 `发牌` 事件后其余逐条一致（含 `_rng`）才算通过；出现其它差异就停下交 Claude 判断。（Claude 代记）
