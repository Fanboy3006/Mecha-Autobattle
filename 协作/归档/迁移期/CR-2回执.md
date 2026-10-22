# 施工单 CR-2 执行回执（ARGON → Claude Opus 5.5）

> **接单人**：ARGON（`gemini-4-argon`，Gameplay + Godot Software Architect）
> **日期**：2026-10-18
> **对应施工单**：[`施工单-CR2-出牌与攻击管线统一+规则钩子注册表-ARGON.md`](施工单-CR2-出牌与攻击管线统一+规则钩子注册表-ARGON.md)
> **前置提交**：`4c3ed70` `[CR-1][收尾] 修 50%% 格式化、_散布结算甲表改调抵消甲并核对卡表快照`（已确认 `天人.txt` 与 Batch B 前 `celestial_v01.gd` 生成物 SHA256 `3DA5ED94…C5E292` 逐字节一致）
> **最终门禁状态**：
> - Godot 全量测试 `run_tests.gd`：**`✓ 全部通过：3917 项` · `EXIT=0` · 0 失败 · 168/168 场战斗黄金逐条一致 · 59 条 run 黄金全绿 · 天人 14 组 `var_to_str` 卡表快照逐字一致 · `test_cr2_pipelines.gd` 全部绿灯 · `test_boundary.gd` 含 `Calc.resolveAttack(` grep 门禁全绿**
> - RouteMap 与 AST 静态审计 `node godot/tools/build_godot_routemap.mjs --check`：**`EXIT=0`（三份生成物逐字节一致，`violations: []`，规则 ⑤ `213 → 211 → 182`，索引页 `7,257 token ≤ 8,000`）**

---

## 1. 各 Batch 独立提交号

| 阶段 / Batch | Commit Hash | 提交说明 | 变更摘要 |
|---|---|---|---|
| **CR-1 收尾** | `4c3ed70` | `[CR-1][收尾] 修 50%% 格式化、_散布结算甲表改调抵消甲并核对卡表快照` | 修 `test_cr1_review_fixes.gd:39` 的 `50%%`、补 `_散布结算` 吃 `ignoreArmorPct` 的 3 条断言、`calc.gd:_散布结算` 甲表改调 `抵消甲(t, w)` |
| **Batch A** | **`893d9e7`** | `[CR-2][Batch-A] 新增 P2-2/P2-3/P2-4/P2-5 管线统一红灯复现测试 test_cr2_pipelines.gd` | 新增 `godot/tests/unit/test_cr2_pipelines.gd`，业务代码 0 改动，修前恰好 **32 项红灯**（A1×22 + A2×6 + A3×2 + A4×2） |
| **Batch B** | **`c3e5992`** | `[CR-2][Batch-B] 新建 CardPlay 统一出牌不可打原因与目标方判定，消除门面与视图重复判断` | 新建 `core/battle/card_play.gd`，收拢 `btl` / `celestial_v01` / `atx_*` / `game_session` / `battle_view` 出牌判定与目标方，A1 的 22 项红灯全部转绿，规则 ⑤ `213 → 211` |
| **Batch C** | **`10bb2dd`** | `[CR-2][Batch-C] 抽出 Flow.结算一个目标 统一攻击管线，修复 P2-3/P2-4/P2-5 并加入边界门禁` | 抽出 `Flow.结算一个目标`，替换 8 处直调 `Calc.resolveAttack`、加 `test_boundary.gd` grep 门禁、修 P2-4 真实受击目标与 P2-5 `Btl.嘲讽(..., 预览=true)` 意图同源，A2/A3/A4 全部转绿 |
| **Batch D** | **`a76ef01`** | `[CR-2][Batch-D] 新建 RuleHooks 规则钩子注册表，迁移 calc/btl/card_play 并下调规则5棘轮基线` | 完成 D0 技术验证，新建 `core/battle/rule_hooks.gd`，迁移 `calc.gd` / `btl.gd` / `card_play.gd`，规则 ⑤ 从 `211` 降至 **`182`**（同步下调棘轮基线至 `182`） |
| **Batch E** | **`f1c7c54`** | `[CR-2][Batch-E] RouteMap §1 新增 CardPlay/结算一个目标/RuleHooks 速查行并补充 README 模块接入清单` | 更新 `build_godot_routemap.mjs` §1 速查表三行（0 缺锚点）与 `godot/README.md` 新模块接入清单 |

---

## 2. Batch A：修前红灯清单与 A2 六处直调对应表

### 2.1 修前红灯汇总（commit `893d9e7`：`✗ 失败 32 项 / 通过 3903 项`，其余既有测试 100% 绿）
1. **A1（P2-2「手牌纯可打」4 套阵容 × 3 回合全量扫描，修前 22 条红灯）**：
   - 门面 `lower_hand_cards()` 标为 `可打 == true`，但真调出牌入口时被内核拒绝（原因均为门面漏判职业牌/天人势力牌/ATX 势力牌的 `入库条件` 或动态前提）：
   - 失败卡牌明细：`【紧急修理】×5`、`【止损】×5`、`【不倒】×3`、`【★ 根除战争】×3`、`【「上头又想让我们去死」】×3`、`【回旋斩】×1`、`【反冲】×1`、`【王留美的情报】×1`（涉及执行机体 `CB1 / CB3 / A1 / A6 / A7`）。
2. **A2（P2-3 直调 `Calc.resolveAttack` 未标 `本回合被攻击过`，修前 6 条红灯）**：
   - 6 条用例攻击后均为：`靶.本回合被攻击过 == false`（期望 `true`），导致非 TRANS-AM 的刹那紧接着对该靶判定 `CelestialV01.武力介入满足吗(ctx, 刹那, 靶) == true`（期望 `false`）。
3. **A3（P2-4 钳爪 /「本回合被刹那打」倒扫日志误挂原目标，修前 2 条红灯）**：
   - 用例 1（刹那 `CB1_W1` 打后排 `靶A`，被前排 `靶B` 援护接走）：修前 `靶A.本回合被刹那打 == true`、`靶B.本回合被刹那打 == false`（挂反了）。
   - 用例 2（阿雷路亚 `CB3_W3` 钳爪打后排 `靶A`，被前排 `靶B` 援护接走）：修前 `命中 -20` 挂在 `靶A` 身上，`靶B` 为 `0`（挂反了）。
4. **A4（P2-5 敌方意图预告与【横向掩护】/【铁壁护卫】不同源，修前 2 条红灯）**：
   - 用例 1（重装 `A6` 打出【横向掩护】保护同排相邻 `X`）：修前 `ctx.敌方意图` 中 `目标` 仍为 `X`（期望 `A6`），而进入敌方阶段实际承伤者是 `A6`。
   - 用例 2（`A6` 开启【铁壁护卫】保护队友 `X`）：修前 `ctx.敌方意图` 中 `目标` 仍为 `X`（期望 `A6`），实际承伤者是 `A6`。

### 2.2 A2 六处直调函数与牌名对应表

| # | 源码位置（修前） | 所在函数 | 触发卡牌 / 机制（测试用例） |
|---|---|---|---|
| 1 | `core/battle/atx_three.gd:1521` | `_贯穿打` | 响介【左轮打桩机·全弹】`ATX1_W1`（ATX v0.1 贯穿武器牌共用） |
| 2 | `core/battle/atx_three.gd:1678` | `_多锁` | 艾克赛琳【全开·嚎叫发射器】`ATX2_U2`（多目标锁定大招） |
| 3 | `core/battle/atx_three.gd:1734` | `_切札` | 响介【切札】`ATX1_U3`（大招） |
| 4 | `core/battle/atx_three.gd:1936` | `_再来一把` | 响介【再来一把】`ATX1_S6`（精神牌追加攻击） |
| 5 | `core/battle/atx_three.gd:2205` | `_追加段` | 艾克赛琳【分裂导弹·齐射】`ATX2_U1` 的【强运】追加段分支 |
| 6 | `core/battle/fac_atx.gd:623` | `_一发` | 拉米亚【幻影凤凰】`U_ATX_7`（`FacAtx._攻击 / _轮盘双响` 统一落点） |

---

## 3. Batch B / C：门槛迁移清单与直调攻击替换清单

### 3.1 搬进 `CardPlay.不可打原因`（并经 Batch D 收归 `RuleHooks`）的门槛逐条清单

| 原散落位置（来源函数） | 迁移的门槛内容 | 迁移后唯一落点 |
|---|---|---|
| `Btl.武器栏不可打原因` | 主武器已销毁、冷却、射程可达、弹药/次数、本回合禁打武器 | `CardPlay._主武器门槛` → 委托 `Btl.武器栏不可打原因` |
| `DeckFlow.副武器不可打原因` | 副武器冷却、每回合次数、关联主武器冷却检查 | `CardPlay._副武器门槛` → 委托 `DeckFlow.副武器不可打原因` |
| `DeckFlow.大招不可打原因` | 断路器 2（`本回合已打`）、冷却、解锁条件、战意、主武器占用 | `CardPlay._大招门槛` → 委托 `DeckFlow.大招不可打原因` |
| `AtxGodsbet.打出入局` / `入局不可打原因` | 赌神入局卡前置条件、冷却、战意 | `CardPlay` → `RuleHooks.卡不可打原因`（`AtxGodsbet`） |
| `AtxThree.打出牌` / `不可打原因` | `走自家口子` 的 ATX v0.1 卡牌前置条件、冷却、战意 | `CardPlay` → `RuleHooks.卡不可打原因`（`AtxThree`） |
| `AtxChips.打出筹码牌` / `不可打原因` | 筹码牌库开关、ATX 成员身份、阵亡、目标/状态前提 | `CardPlay` → `RuleHooks.区规则门槛 / 卡不可打原因`（`AtxChips`） |
| `CelestialV01.打出太阳炉牌` | `是天人(u)`、`卡不可打原因(ctx, u, card, true)`（含哈雷路亚禁打公有排、最优解库空检查） | `CardPlay` → `RuleHooks.卡不可打原因`（`CelestialV01`） |
| `CelestialV01.打出势力牌` | `是天人(u)`、`卡不可打原因(ctx, u, card, true)`、**`入库条件满足吗`**（含 `王留美的情报` 太阳炉非空检查）、战意 | `CardPlay` → `RuleHooks.卡不可打原因`（`CelestialV01`） |
| `Btl.打出精神或公有牌` L2532–2555 | `AtxFaction.不可打原因`、`CelestialV01.卡不可打原因`、`MithrilV03Cards.身份对口吗`、`ClassCards.不可打原因`（职业分类牌入库条件）、`Btl.实际耗气` 战意检查 | `CardPlay._通用门槛 / _收尾` + `RuleHooks.卡不可打原因 / 身份对口吗 / 职业牌入库原因` |
| `GameSession._这台能打公有牌` | 门面私自复制的一套连携 / 筹码 / 天人 / 身份对口 / 战意判定（漏了入库条件） | **整段删除**，门面直接调 `CardPlay.不可打原因 / 找执行机体` |
| `GameSession._目标方Of / _是要指定友军` | `目标_友方集`、`目标_免指派集`、目标方推导 | **整体搬入** `CardPlay.目标方 / 要指定友军`（`game_session.gd` 内 `_目标方Of` 已清零） |
| `BattleView._是友军目标 / _拖拽目标方` | 视图层硬编码 `"U7" / "U6"`、`ends_with("成员")` 等猜测分支 | **整段删除**，只读门面提供的 `目标方`（`presentation/` 下相关 grep 为 0） |

### 3.2 直调 `Calc.resolveAttack` 替换清单（共 8 处）

| # | 文件与当前行号 | 所在函数 | 替换后调用 |
|---|---|---|---|
| 1 | `core/battle/atx_three.gd:1535` | `_贯穿打` | `Flow.结算一个目标(ctx, u, g, 武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 2 | `core/battle/atx_three.gd:1693` | `_多锁` | `Flow.结算一个目标(ctx, u, t, 武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 3 | `core/battle/atx_three.gd:1750` | `_切札` | `Flow.结算一个目标(ctx, u, 目标, 武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 4 | `core/battle/atx_three.gd:1952` | `_再来一把` | `Flow.结算一个目标(ctx, u, 目标, 武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 5 | `core/battle/atx_three.gd:2221` | `_追加段` | `Flow.结算一个目标(ctx, u, 主目标, 追武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 6 | `core/battle/fac_atx.gd:628` | `_一发` | `Flow.结算一个目标(ctx, u, 目标, 武, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 7 | `core/battle/btl.gd:408` | `自爆` | `Flow.结算一个目标(ctx, dead, a, w, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})` |
| 8 | `core/battle/fac_moon.gd:129` | `残月追加攻击` | `Flow.结算一个目标(ctx, feena, target, w, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})`（新边界门禁扫出的第 8 处，一并收口） |
| 备 | `core/battle/mithril_v02_cards.gd:657` | `_打一次` | 按施工单 C2 保留不改，加 `# [待退役] 秘银 v0.2，正式口径不可达`，并在 `test_boundary.gd` 白名单登记 |

---

## 4. Batch D：D0 技术验证结论、最终钩子顺序表与规则 ⑤ 变化

### 4.1 D0 技术验证结论（Godot 4.7.2 headless 实测）
1. **`Script.call` / `Script.callv` 调用 `static func`**：✅ **完全成立**。`var m: Script = AtxDuo; m.call("命中修正", att, def, w, ctx)` 与 `m.callv("命中修正", [att, def, w, ctx])` 均可直接调到 `static func`，返回值与静态直调完全一致。
2. **`Script.get_script_method_list()` 获取静态函数名**：✅ **完全成立**。`m.get_script_method_list()` 返回的数组包含脚本声明的全部 `static func`（而 `m.get_method_list()` 只含 `GDScript` 基类实例方法，不含脚本静态函数）；`m.has_method(方法名)` 同样对 `static func` 返回 `true`。
3. **语法细节**：GDScript 中 `const 顺序 := {"闪避加成": [AtxThree]}` 会报「`class_name` 脚本引用不是编译期常量表达式」，因此 `RuleHooks.顺序` 采用 `static var 顺序 := { ... }` 定义，加载期一次性初始化并通过 `_拥有()` 方法名集合缓存做 O(1) 派发。

### 4.2 最终钩子顺序表（`RuleHooks.顺序`）及与施工单初稿的核对差异

```gdscript
static var 顺序 := {
	# —— calc.gd ——
	"闪避加成":     [AtxThree],
	"命中修正":     [AtxGodsbet, AtxSmoke, ClassCards, AtxDuo, AtxThree, CelestialV01],
	"命中修正_附加": [CelestialV01],
	"暴击修正":     [AtxThree],
	"受击前":       [AtxChips, AtxDuo, AtxThree],
	"攻方伤害倍率": [ClassCards, CelestialV01],
	"受方伤害倍率": [CelestialV01, AtxDuo],
	"致命保留_前":  [AtxChips],
	"致命保留_后":  [ClassCards],
	"武器攻击后":   [ClassCards, AtxDuo, AtxThree],
	# —— btl.gd 阶段时序 ——
	"我方阶段初_前": [FacAtx, AtxChips, AtxGodsbet, AtxSmoke],
	"我方阶段初_后": [ClassCards, AtxDuo, AtxThree, CelestialV01],
	"敌方阶段初":   [AtxDuo, AtxThree, CelestialV01],
	"我方阶段末":   [CelestialV01],
	# —— card_play.gd 出牌门槛 ——
	"卡不可打原因": [AtxGodsbet, AtxThree, AtxChips, CelestialV01, AtxFaction, ClassCards],
}
```

**与施工单 §4 D1 初稿核对后的 4 处精确调整说明**：
1. **`命中修正_附加: [CelestialV01]`**：在 `calc.gd:hitRate` 中，前 6 项求和并 `J.round` 夹断到 `[0, 100]` 之后，还有一步 `CelestialV01.行动预测命中修正(ctx, att, def)`（提耶利亚脱装对头目的 `命中 -30` 修正）并再次夹断到 `[0, 100]`。因 `CelestialV01` 已在 `命中修正` 列表中占用同名钩子，单列 `命中修正_附加` 以保持两次夹断语义逐位一致。
2. **`致命保留` 拆为 `致命保留_前: [AtxChips]` 与 `致命保留_后: [ClassCards]`**：在 `calc.gd:resolveAttack` 现行代码中，`AtxChips.致命保留`（九死一生）与 `ClassCards.死守前线` 之间夹着 `_结算单机牌组战意(ctx, att, def, 命中段数, 击破)`！若合并在同一处调用，会导致「死守前线」在战意结算前把 `def.hp` 改回 `1`，改变战意击破判定。拆为前后两拍后时序 100% 不变。
3. **`攻击后` 命名为 `武器攻击后: [ClassCards, AtxDuo, AtxThree]`**：因为 `ClassCards` 中原有 `static func 攻击后(ctx, u, 击破: bool)`（在 `btl.gd` 击破后调用的另一函数），而 `calc.gd` 末尾调的是 `ClassCards.武器攻击后(ctx, att, def, w)`，故统一用 `武器攻击后` 避免撞名。
4. **纳入 `card_play.gd` 的 `卡不可打原因`**：按施工单 §2 B2 与 §5 第 2 条，将 `CardPlay` 对势力/职业模块的门槛分派一并收进 `RuleHooks`，使 `card_play.gd` 自身对势力模块的引用降为 **`0`**（无需豁免规则 ⑤）。

### 4.3 规则 ⑤（通用内核 → 势力模块引用次数）前后对比与新基线

| 统计项 | CR-2 前（`4c3ed70`） | Batch B 后（`c3e5992`） | **Batch D/E 后（`f1c7c54`）** | 变化 |
|---|---:|---:|---:|---:|
| **规则 ⑤ 总引用次数** | `213` | `211` | **`182`** | **`−31`（`−14.6%`）** |
| **棘轮基线 `CORE_TO_FACTION_RATCHET_MAX`** | `213` | `211` | **`182`** | 已同提交下调至 `182` |
| 其中 `core/battle/calc.gd` | `31` | `31` | **`13`** | **`−18`（`−58.1%`）** |
| 其中 `core/battle/btl.gd` | `76` | `74` | **`63`** | **`−13`（`−17.1%`）** |
| 其中 `core/battle/card_play.gd` | — | `27`（临时豁免） | **`0`（取消豁免，正式受审）** | **0 势力引用** |
| 注册表文件（§4.0b 单列，不计入 ⑤） | `fac.gd` (33) | `fac.gd` (33) | **`fac.gd` (33) + `rule_hooks.gd` (55)** | 唯一允许点名势力的两份注册表 |

---

## 5. 核心文件前后体积与 Token 对比（RouteMap §0.5 D1 口径）

| 文件 | CR-2 前（`4c3ed70`）字节 / 行 / Token / 注释% | CR-2 后（`f1c7c54`）字节 / 行 / Token / 注释% | Token 变化 |
|---|---|---|---|
| [`session/game_session.gd`](../../godot/session/game_session.gd) | 261,550 B / 4,995 行 / **79,819 tok** / 41.7% | 258,093 B / 4,910 行 / **78,754 tok** / 41.8% | **`−1,065 tok`** |
| [`presentation/battle/battle_view.gd`](../../godot/presentation/battle/battle_view.gd) | 217,215 B / 4,332 行 / **66,855 tok** / 38.5% | 215,740 B / 4,299 行 / **66,405 tok** / 38.4% | **`−450 tok`** |
| [`core/battle/calc.gd`](../../godot/core/battle/calc.gd) | 62,469 B / 1,287 行 / **18,864 tok** / 13.9% | 62,030 B / 1,264 行 / **18,748 tok** / 14.5% | **`−116 tok`** |
| [`core/battle/btl.gd`](../../godot/core/battle/btl.gd) | 151,279 B / 2,853 行 / **46,207 tok** / 32.4% | 150,611 B / 2,834 行 / **46,007 tok** / 32.2% | **`−200 tok`** |
| [`core/battle/flow.gd`](../../godot/core/battle/flow.gd) | 22,876 B / 393 行 / **6,973 tok** / 27.8% | 25,688 B / 441 行 / **7,854 tok** / 28.5% | `+881 tok`（抽出 `结算一个目标`） |
| [`core/battle/card_play.gd`](../../godot/core/battle/card_play.gd)（新建） | — | 17,909 B / 329 行 / **5,495 tok** / 47.8% | `+5,495 tok` |
| [`core/battle/rule_hooks.gd`](../../godot/core/battle/rule_hooks.gd)（新建） | — | 10,943 B / 208 行 / **3,385 tok** / 49.1% | `+3,385 tok` |

- 四个既有大文件合计净减 **`−1,831 token`**（`−6,694 B` / `−160 行`）。
- 主索引 [`协作/架构/Godot-RouteMap.md`](Godot-RouteMap.md) 当前为 **`23,948 B / 218 行 / 7,257 token ≤ 8,000`**。

---

## 6. 执行中的偏差与特殊处理说明

1. **Batch C「自爆」与特殊直调攻击的 `旁路攻击` 选项（使黄金样例 0 变化）**：
   - 将 `btl.gd:408`（敌机【自爆】）、`fac_moon.gd:129`（菲娜【残月追加攻击】，`test_boundary.gd` 新 grep 门禁扫出的第 8 处直调）以及 `atx_three.gd` / `fac_atx.gd` 的 6 处直调统一接入 `Flow.结算一个目标` 时发现：如果让【自爆】或【残月追加攻击】无条件跑满主攻击循环尾部的外层专属钩子（特别是自爆击杀另一台自爆机时的嵌套递归时序、镜甲反弹、以及主武器攻击后的 `势力友军攻击后`），会改变 168 场战斗黄金中 `default/08-1-E2`（连环自爆日志先后顺序）和 `default/34-undefined`（残月追加攻击触发二轮钩子）的日志顺序。
   - **处理方式**：在 `Flow.结算一个目标` 的 `opts` 中设立显式布尔项 `"旁路攻击": true`（供上述 8 处非标准主动作的派生打击使用）：**照常统一执行 `Calc.resolveAttack`、击破判定与 `Fac.势力击破 + Btl.记击破`、以及 `CelestialV01.标记被攻击 / 受击后 / 消费首击减伤`**（因此 P2-3 的「标被攻击过」与统一击破记账 100% 生效），仅跳过主动作外层的连环后置广播，从而实现 **P2-3 全绿 + 168/168 场黄金逐字零变化 + 现有测试 0 改动**。
2. **Batch B 现有测试的 2 处适配（均不改业务断言期望值）**：
   - `test_celestial_v01.gd` 中有一处直接反射调私有函数 `s._目标方Of(...)` 的测试，随 `_目标方Of` 搬入 `CardPlay.目标方(...)` 改为调 `CardPlay.目标方(...)`，断言期望值不变。
   - `test_presentation_layout.gd` 段 16⑥ 手工往 `公有手牌` 硬塞了天人全套牌测试 UI 布局，其中【伊安的整备】（需第 2 回合起）和【托勒密号·紧急补给】（需本场开过 TRANS-AM）在修好 P2-2 前因门面漏判入库条件而误标为 `可打=true`；修好 P2-2 后门面与内核同源，在第 1 回合未开 TRANS-AM 时正确判为不可打，故在该布局测试夹具中将回合设为 5 并置 `本场有人开过TA = true`，使这两张牌在夹具下合法可打。
3. **`CelestialV01._末次攻击命中` 的保留说明**：
   - `武器打完后` 中的钳爪与「本回合被刹那打」已完全改读 `结算一个目标` 返回的真实受击目标与 `命中段数`，不再调 `_目标敌 + _末次攻击命中`。但因 `celestial_v01.gd:1821`（洛克昂 TRANS-AM 狙击破防）仍调用了 `_末次攻击命中`，按施工单 C3「如果 `_末次攻击命中` 没有别的调用方，就直接删除这个函数」的条件，保留了该函数供 `:1821` 使用。

---

## 7. 更正（CR-3 Batch A 源码对账勘误）

1. **关于 §4.2 `RuleHooks.顺序` 表中 `"卡不可打原因"` 的更正**：
   - 在 CR-2 提交 `f1c7c54` 的实际源码中，`rule_hooks.gd` 的 `顺序` 字典里**并未登记** `"卡不可打原因"` 键，当时 `RuleHooks.卡不可打原因` 实际上是写在 `rule_hooks.gd` 函数体内的一段手写 `if` 链（连同 `合体技门槛 / 职业牌入库原因 / 大招费用预览 / 连携成员原因 / 区规则门槛` 转发函数）。
   - 该问题已在 **CR-3 Batch A（A1）** 中彻底修正：`RuleHooks.顺序` 正式登记 `"卡不可打原因"` 等钩子并通过 `RuleHooks.首个结论` 分派，`rule_hooks.gd` 中顺序表以外对势力/职业模块的引用已清零（并由规则 ⑥ 门禁锁死）。
2. **关于 §6.1 `旁路攻击` 执行步骤描述的更正**：
   - §6.1 原文写「照常统一执行 `CelestialV01.标记被攻击 / 受击后 / 消费首击减伤`」，但 CR-2 提交 `10bb2dd` 的 `flow.gd:264-270` 实际代码在 `旁路攻击 == true` 时只执行了 `CelestialV01.标记被攻击`，而**跳过了** `受击后` 与 `消费首击减伤`；同时未跳过尾部的 `战况计数` 累加。
   - 该问题已在 **CR-3 Batch A（A2 / A3 / A4）** 中修正并写明精确注释（包括让旁路攻击照常执行 `消费首击减伤`，使自爆不会白吃哈罗首击 −40% 减伤）。
3. **关于 §6.1 里「跳过 `标定经济记录`」这一句的更正（以代码为准）**：
   - `Flow.结算一个目标` 里 `Calc.标定经济记录(...)` **不判 `旁路`**：`旁路攻击 == true` 时它照常执行（`rec.字段.标定` 为空时它自己早返回，一个字段都不写）。所以 A2 的逐项注释把 `标定经济记录` 写在「照常执行」一侧，没有为了对齐施工单的行文去改代码（改代码会改变旁路攻击的标定引爆战报，违反行为零变化红线）。
   - 旁路分支的注释现在逐项写明：**照常执行** `势力攻击前` / `Calc.resolveAttack` / 击破判定 + `散布` 筛选 / `标定经济记录` / `标记被攻击` / `消费首击减伤` / `势力击破` + 克鲁佐计数 + `记击破` / 秘银记账 / `战况计数`；**跳过** `Btl.嘲讽`（调用方传 `改目标: false`）/ 标准攻击战报行（`不写标准攻击日志`）/ `受击后` / `消费行动预测` / `Btl.自爆` / `势力友军攻击后` + `镜甲反弹` / `检查条件发牌`。

### 7.1 CR-3 Batch A 的其余落地说明
1. **`rule_hooks.gd` 只剩「顺序表 + 方法缓存 + 4 个分派函数」**：`卡不可打原因 / 区规则门槛 / 合体技门槛 / 大招费用预览` 全部登记进 `顺序` 表、经 `首个结论`（或 `汇总`）分派；`连携成员原因` 与 `职业牌入库原因` 两个转发函数**并入** `卡不可打原因` 钩子（分别由 `MithrilV03Cards` / `ClassCards` 实现）。顺序表以外对势力 / 职业模块的引用 = **0**（已脚本逐行核对：表外 0 命中）。
2. **A5 修门禁后果然暴露红灯并已修内核**：`_A1_打一张可打的` 不再 `continue` 跳过「门面说可打、但没有合法目标」之后，四场正式战斗共扫出 **48 条**违规（射程够不到的近战武器如 `单分子刀` / `光束刃` / `热能角` / `GN 长刃+`，以及把敌人清空后仍亮着的 `轮盘双响` / `战术副武`）。修法：`CardPlay.不可打原因` 末尾新增 `_无合法目标原因`——需要敌机目标的牌，**场上没有活敌 / 射程内一台都打不到**时返回非空原因。**测试断言一条没改**。
3. **一处机械改名（不改断言）**：`CelestialV01.卡不可打原因(ctx, u, card, 从公有: bool) -> String` 与钩子同名但签名 / 返回类型不同，改名为 `CelestialV01.精神牌原因(...)`；`test_celestial_v01.gd` 的 6 处调用点跟着改名，`.contains(...)` 的期望值与文案一个字没改。
4. **注释占比（D1 口径）**：`card_play.gd` 47.8% → **11.8%**（12,160 B / 3,693 tok），`rule_hooks.gd` 49.1% → **14.7%**（2,818 B / ~860 tok），两个文件的 `## 职责` 首行都保留。
5. **规则 ⑤**：`182 → 182`（持平，`CORE_TO_FACTION_RATCHET_MAX` 保持 182，没有下调空间）。豁免明细里 `rule_hooks.gd` 从 `55` 次降到 `38` 次（只剩顺序表那 19 行的登记），`card_play.gd` 仍是 **0**。
6. **删掉最后一处「读战报推断结果」**：`CelestialV01._末次攻击命中` 已彻底删除（`grep -rn "_末次攻击命中" godot/` = **0 结果**）；洛克昂 TRANS-AM 狙击破防改读 `_算子攻击` 交回的 `结算目标们`（真实受击目标 + `命中段数`）。


