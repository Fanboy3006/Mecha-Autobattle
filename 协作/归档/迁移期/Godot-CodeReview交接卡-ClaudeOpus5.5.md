# Godot M4 & P2 玩法线（秘银 v0.3 / ATX v0.3 / 天人 v0.1 / 4×4 三栏 UI）→ Claude Opus 5.5 Code Review 交接卡

> **交接对象**：**Claude Opus 5.5**（Code Review & 架构/规则审计会话）
> **交接人**：**ARGON**（`gemini-4-argon`，Gameplay + Godot Software Architect）
> **交接日期**：2026-10-18
> **当前测试门禁**：**`✓ 全部通过：3879 项（0 失败 · 0 SCRIPT ERROR · 168/168 战斗黄金逐条一致 · 59 条 run 黄金全绿）`**

---

## §1 ★★ 首要回答：Godot 版本的 RouteMap 与 AST 依赖在哪里？是否需要重新分析？

### 1.1 历史盲区与本次补齐
- **旧版文件的局限（切勿误读）**：
  - 仓库里原有的 [`docs/实现/RouteMap.md`](../../docs/实现/RouteMap.md)、[`docs/实现/结构表.md`](../../docs/实现/结构表.md)、[`协作/架构/依赖清单.json`](依赖清单.json) 以及生成器 [`tools/build-route-map.mjs`](../../tools/build-route-map.mjs) **仅扫描已封存的 JS 参考版（`src/shell.html` + `src/js/*.js`）**，对 `godot/**/*.gd` 的覆盖率为 **0%**！
  - 而从 `9d9f8bb`（单机牌组 v1.0）→ `e2efa72`（秘银 v0.3 + ATX v0.3）→ `c78ab2a`（4×4 三栏 UI 重构）→ 本轮（规范 v0.3 三条断路器 + 顺劈 + 天人 v0.1 + 零滚动三栏手牌与左牌库），Godot 工程规模已增长到 **108 个 `.gd` 文件 / 66,893 行代码 / 72 个 `class_name` / 3,389 个函数 / 886 条跨文件依赖边**。
- **已为你新建并跑完最新静态 AST / 符号依赖分析（无需从零盲扫）**：
  1. **人类 & AI Reviewer 直读路由地图**：**[`协作/架构/Godot-RouteMap.md`](Godot-RouteMap.md)**（516 行，90 KB）
     - `§0`：四层（`core` 52 文件、`session` 3 文件、`presentation` 16 文件、`tests` 37 文件）全量统计；
     - `§1`：**48 条「业务现象 / 规则机制 → 精确 `.gd` 文件与行号」速查路由表**；
     - `§2`：108 个 `.gd` 文件逐一定位表（行数、字节、`class_name`、`extends`、`const` 数、`func` 数、前 15 个公开函数签名与行号）；
     - `§3`：层间依赖矩阵、被依赖最多的 Top 22 核心模块、逐文件正向依赖清单、最热函数 Top 25、62 对模块间双向调用清单；
     - `§4`：**架构分层合规审计结论（`violations: []`，0 违规）**。
  2. **机器可读完整 AST 符号与依赖图 JSON**：**[`协作/架构/Godot-AST依赖清单.json`](Godot-AST依赖清单.json)**（1.39 MB）
     - 包含每个 `.gd` 文件的 `declares`、`funcs[]`（含签名、行号、`static`、返回类型、函数体内外部调用符号）、`consts[]`、`dependsOn[]`（精确到引用了对方哪些符号与次数）、`dependsBy[]` 及 `audit` 报告。
  3. **零依赖可复跑生成与校验工具**：**[`godot/tools/build_godot_routemap.mjs`](../../godot/tools/build_godot_routemap.mjs)**
     - 重建命令：`node godot/tools/build_godot_routemap.mjs`
     - 幂等校验：`node godot/tools/build_godot_routemap.mjs --check`（当前 `EXIT=0` 逐字节一致）。

### 1.2 你做 Code Review 时「是否需要重新分析」？
- **不需要重跑全量目录扫描**：[`协作/架构/Godot-RouteMap.md`](Godot-RouteMap.md) 与 [`协作/架构/Godot-AST依赖清单.json`](Godot-AST依赖清单.json) 就是基于当前工作区最新状态（含天人 v0.1 与最新 UI 改动）刚刚生成的 **100% 实时真源**。
- **如果你在 Review 过程中修改了任何 `.gd` 文件**：只需在改完后跑一行 `node godot/tools/build_godot_routemap.mjs`，即可在 1 秒内刷新上述两份文件并自动审计是否引入了分层违规（`violations`）。

---

## §2 架构分层现状与 AST 静态审计结果

Godot 工程严格执行 **三层单向依赖架构**（详见 [`M4-表现层接口契约.md`](M4-表现层接口契约.md)）：

```text
presentation/** (16 个 .gd, 9,854 行)   —— 视图层（BattleView / UnitCard / MenuView / MapView ...）
       │  只调 GameSession 公开动作与纯读快照（+ 69 处白名单枚举/纯格式只读辅助）
       ▼
session/**      (3 个 .gd, 4,768 行)    —— 会话门面层（GameSession / SaveStore / TelemetryStore）
       │  组装视图字典、驱动状态机、持久化与实时监控落盘
       ▼
core/**         (52 个 .gd, 25,651 行)  —— 纯逻辑内核层（Btl / Calc / Flow / DeckFlow / SubDeck / 各势力卡包）
```

- **AST 静态审计结果（`Godot-RouteMap.md §4`）**：
  - `core/** → session/**`：**0 处** ✅
  - `core/** → presentation/**`：**0 处** ✅
  - `session/** → presentation/**`：仅 `game_session.gd → UiTheme.文本()`（12 处纯字符串格式化静态函数，零节点/场景依赖，已登记在符号级白名单）✅
  - `presentation/** → core/**` 写接口绕过：**0 处** ✅

---

## §3 重点请 Claude Opus 5.5 Review 的 5 大模块与核心文件索引

### Review 重点 1：全局规范 v0.3（手牌纯可打 + 3 条防死循环断路器 + 装甲共享池 + 顺劈）
- **设计真源**：[`协作/设计/势力与职业卡牌设计规范 v0.3.md`](../设计/势力与职业卡牌设计规范%20v0.3.md)（同 [`docs/设计/势力与职业卡牌设计规范.md`](../../docs/设计/势力与职业卡牌设计规范.md)）
- **对应代码**：
  1. **断路器 1（三级副牌库牌每种每场最多放入 1 次，打出后移出本场）**：
     - [`godot/core/battle/sub_deck.gd`](../../godot/core/battle/sub_deck.gd)（`191 行`，`SubDeck.新建()` 内置 `已放入三级: {}`，`SubDeck.放入()` 对等级 `>= 3` 双表强制拦截重复放入，`回库或移出()` 对三级牌移出本场）。
  2. **断路器 2（同一张大招每回合最多打 1 次）**：
     - [`godot/core/battle/deck_flow.gd`](../../godot/core/battle/deck_flow.gd)（`1,169 行`，`大招不可打原因()` 最顶层检查 `槽.本回合已打`，覆盖标准大招槽、ATX `v01别名` 大招与合体技；[`atx_chips.gd`](../../godot/core/battle/atx_chips.gd) 的 `_梭哈` 清零 `u.v01冷却` 但保留 `本回合已打`）。
  3. **断路器 3（每台机体每回合最多触发 1 次「再动 / 连续攻击 / 主武器恢复」）**：
     - [`godot/core/battle/deck_flow.gd`](../../godot/core/battle/deck_flow.gd)（`DeckFlow.再动` + `DeckFlow.恢复主武器栏`）与 [`godot/core/battle/btl.gd`](../../godot/core/battle/btl.gd)（`连续攻击可用 / 连续攻击记`）及 [`godot/core/battle/fac_atx.gd`](../../godot/core/battle/fac_atx.gd)（`W17·中继`）共用同一把锁 `本回合再动已用 / 连续攻击已用`；且恢复主武器时严禁恢复 `出鞘 == true` 的刹那剑牌。
  4. **多段武器「装甲共享池」**：
     - [`godot/core/battle/calc.gd`](../../godot/core/battle/calc.gd)（`1,336 行`）：每次攻击按每个目标初始化 `pool = round(有效装甲 × 防御倍率)`，命中段消耗 `absorb = min(pool, 单段威力)`，打穿后后续命中段全额伤。
  5. **近卫分类牌删除「连斩」→ 新增「顺劈」与范围形状 `area = "顺劈"`**：
     - [`godot/core/battle/class_cards.gd`](../../godot/core/battle/class_cards.gd)（`620 行`，`CC_G6 顺劈`）+ [`godot/core/battle/flow.gd`](../../godot/core/battle/flow.gd)（`813 行`，展开主目标同排左右相邻格，副目标按 `50% 单段威力` 逐段独立掷命中/暴击、独立初始化并消耗各自的装甲共享池）。

### Review 重点 2：天人势力 v0.1 全栈实现（本轮新增核心模块）
- **设计真源**：[`协作/设计/天人→ARGON 施工单 v0.1.md`](../设计/天人→ARGON%20施工单%20v0.1.md) · [`天人势力卡牌设计 v0.1.md`](../设计/天人势力卡牌设计%20v0.1.md) · 五人单卡稿（[`刹那`](../设计/刹那卡牌设计%20v0.1.md) / [`洛克昂`](../设计/洛克昂卡牌设计%20v0.1.md) / [`提耶利亚`](../设计/提耶利亚卡牌设计%20v0.1.md) / [`阿雷路亚`](../设计/阿雷路亚卡牌设计%20v0.1.md) / [`拉塞`](../设计/拉塞卡牌设计%20v0.1.md)）
- **核心代码与测试**：
  - [`godot/core/battle/celestial_v01.gd`](../../godot/core/battle/celestial_v01.gd)（`2,462 行`，`class_name CelestialV01`）
  - [`godot/tests/unit/test_celestial_v01.gd`](../../godot/tests/unit/test_celestial_v01.gd)（`1,690 行`，17 大段单元测试，72 张牌逐张真打验证）
- **建议重点审查的边界逻辑**：
  1. `TRANS-AM·启动`（大招槽非武器入场牌，持续 3 个我方阶段伤害 `×1.3` / 闪避 `+15` / 武力介入必触发，结束后转 1 个我方阶段 `粒子耗尽` 伤害 `−30%`；仅三级太阳炉牌 `伊奥利亚的遗产` 可重置 `本场已开TRANSAM`）；
  2. 【武力介入】判定时机：精神牌/势力牌给敌机挂状态**不把敌机标为 `本回合被攻击过`**，只有武器/大招/伤害牌攻击结算后才把目标标为 `本回合被攻击过 = true`（确保刹那先打「武力介入，开始」再砍第一刀时，精神牌本身触发一次武力介入，紧接着第一刀还能触发或按预期衔接）；
  3. 刹那【七剑】：「迅击」（TRANS-AM 中每回合第一张剑牌打出后不收起其余主武器，不占断路器 3）、「收剑 / 拔刀」（只解除 `出鞘`，已收起的主武器不弹回，不占断路器 3）、「七剑齐出」（5 张剑牌全出鞘 = 7 把剑）使 `七剑·TRANS-AM 乱舞` 切换为完全版并放入 `伊奥利亚的遗产`；
  4. 洛克昂【狙い撃つ】：基于**最终命中**（扣除遮挡 `-20` 等修正后）`> 100` 的溢出部分 1:1（`狙击手的直觉` 1:2）加暴击率，副武器 `援护射击` 继承【狙い撃つ】；
  5. 提耶利亚【演算】与 `脱装·纳德雷`：调用通用接口 `DeckFlow.切换武器栏(u, 新武器表, "permanent")` 本场永久替换主武器栏（同时预留了 `"overlay"` 栈模式供下一势力殖民卫星军拉克丝 METEOR 复用）；
  6. 阿雷路亚【双人格】：哈雷路亚禁打公有排（但打出的【武力介入】照常抽太阳炉牌进公有手牌给队友打；TRANS-AM `超兵同调` 与 `双重思考` 期间哈雷路亚可打公有排）。

### Review 重点 3：秘银 v0.3 与 ATX v0.3 已落地模块
- **秘银 v0.3**：[`godot/core/battle/mithril_v03_cards.gd`](../../godot/core/battle/mithril_v03_cards.gd)（`1,397 行`，连携牌库 9 张、宗介 λ 驱动 4000 力场与觉醒、克鲁兹【远距·N】、毛【指令】、`Uruz 全员突击` 不毁主武器、`火力支援请求` 公有牌武器攻击结算）。
- **ATX v0.3**：
  - [`godot/core/battle/atx_three.gd`](../../godot/core/battle/atx_three.gd)（`2,114 行`，响介/艾克赛琳/拉米亚 52 张牌）
  - [`godot/core/battle/atx_chips.gd`](../../godot/core/battle/atx_chips.gd)（`542 行`，筹码牌库 10 张与【赌局】）
  - [`godot/core/battle/atx_godsbet.gd`](../../godot/core/battle/atx_godsbet.gd)（`320 行`，响介赌神状态机与翻盘 ×3）
  - [`godot/core/battle/atx_luck.gd`](../../godot/core/battle/atx_luck.gd)（`125 行`，艾克赛琳【强运】硬币）
  - [`godot/core/battle/atx_smoke.gd`](../../godot/core/battle/atx_smoke.gd)（`306 行`，拉米亚烟雾与【雾袭】）
  - [`godot/core/battle/atx_duo.gd`](../../godot/core/battle/atx_duo.gd)（`663 行`，塔斯克/雷欧娜与重装通用【掩护 2/2】）
  - [`godot/core/battle/atx_faction.gd`](../../godot/core/battle/atx_faction.gd)（`800 行`，ATX 9 张势力牌与合体技「轮盘双响」）。

### Review 重点 4：4×4 统一棋盘 + 三栏零滚动战斗 UI 与友军绿色箭头拖拽
- **对应文件**：[`godot/presentation/battle/battle_view.gd`](../../godot/presentation/battle/battle_view.gd)（`4,074 行`）· [`godot/presentation/widgets/unit_card.gd`](../../godot/presentation/widgets/unit_card.gd)（`546 行`）· [`godot/session/game_session.gd`](../../godot/session/game_session.gd)（`4,650 行`）
- **核心设计**：
  1. **中上 4×4 统一棋盘**：从上到下严格为 `敌后排 (slot 4..7) → 敌前排 (slot 0..3) → 战线 → 我前排 (slot 0..3) → 我后排 (slot 4..7)`（修复了此前 `_敌方卡` 按视觉顺序 append 导致敌方前后排颠倒的 Bug），实时绘制青蓝色**援护防御连线**（`〔援护 2/2〕`）；
  2. **中下手牌区（100% 纯可打 + 零滚动自适应缩放）**：彻底移除横向 `ScrollContainer`，上排拆为 **`【主武器】|【副武器】|【精神】`** 并列三栏（按各栏张数动态分配 `stretch_ratio`），下排为 **`【公有牌】`**，卡牌宽度与字号按张数自动缩放；
  3. **左侧未激活/冷却牌库栏（三分区 + 2 列网格零滚动自适应）**：彻底移除 `ScrollContainer`，分为 `【武器 / 大招（冷却·出鞘·收起）】`、`【精神 / 待入库条件牌】`、`【公有 / 势力副牌库】` 三个子区块，内部 2 列 `GridContainer` 高密度展示；
  4. **友军/修理卡强制拖拽 + 翠绿色连线与箭头**：补齐 `"天人成员"` / `"…成员"` 友方目标识别；凡 `目标方 == "友方"` 的手牌禁止单击盲放（单击时提示拖动并点亮我方存活机体绿框），按住拖动时绘制**翠绿色发光连线 + 箭头 + 双圈准星**，松手精准作用于目标友军并弹出棋盘胶囊飘字。

### Review 重点 5：文件体积观察（供重构评估）
- 目前体积最大的 4 个 `.gd` 文件：
  1. `godot/session/game_session.gd`（`4,650 行`）
  2. `godot/presentation/battle/battle_view.gd`（`4,074 行`）
  3. `godot/core/battle/btl.gd`（`2,721 行`）
  4. `godot/core/battle/celestial_v01.gd`（`2,462 行`） / `atx_three.gd`（`2,114 行`）
- 请评估在后续接入「殖民卫星军 v0.1」「影世界」「月球王国」前，是否需要将 `battle_view.gd` 的「左牌库栏 / 手牌三栏 / 战斗动画层」或 `game_session.gd` 的「单机牌组视图组装」拆分为独立子组件/辅助类。

---

## §4 Review 验证命令速查

```powershell
# 1. 运行 Godot 全量单元测试 + 168 场战斗黄金 + 59 条 run 黄金 + 版面门禁（期望 3879 项全绿，EXIT=0）
& 'F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:\DSH-mecha\mecha-autobattle\godot' --script res://tests/run_tests.gd

# 2. 校验 / 重建 Godot RouteMap 与 AST 依赖图（期望 --check EXIT=0）
node F:\DSH-mecha\mecha-autobattle\godot\tools\build_godot_routemap.mjs --check
```
