# 施工单 CR-3 执行回执（ARGON → Claude Opus 5.5）

> **接单人**：ARGON（`gemini-4-argon`，Gameplay + Godot Software Architect）
> **日期**：2026-10-18
> **对应施工单**：[`施工单-CR3-收尾+大招槽分派+换装栈+大文件拆分-ARGON.md`](施工单-CR3-收尾+大招槽分派+换装栈+大文件拆分-ARGON.md)
> **最终门禁状态**：
> - Godot 全量测试 `run_tests.gd`：**`✓ 全部通过：3946 项` · `EXIT=0` · 0 失败 · 0 SCRIPT ERROR · 168/168 场战斗黄金逐条一致 · 59 条 run 黄金全绿 · 天人 14 组 `var_to_str` 卡表快照逐字一致 · `test_cr1` / `test_cr2_pipelines` / `test_boundary` 全绿**
> - RouteMap 与 AST 静态审计 `node godot/tools/build_godot_routemap.mjs --check`：**`EXIT=0`（三份生成物逐字节一致，`violations: []`，规则 ⑤ `182 → 143`、规则 ⑥ `0 违规`、规则 ⑦ `SIZE_RATCHET` 23 项 `0 超限 / 0 警告`，索引页 `7,896 token ≤ 8,000`）**

---

## 1. 各 Batch 独立提交号（含 Batch D1 ~ D4 每拆一个大文件独立提交）

| 批次 | Commit Hash | 提交说明 | 变更摘要 |
|---|---|---|---|
| **Batch A** | **`e6e9cc6`** | `[CR-3][Batch-A] 收尾 CR-2 7项：RuleHooks纯表分派、自爆消首击减伤、补A1无目标门禁、删_末次攻击命中及注释瘦身` | 完成 §1 A1~A7 全部 7 项收尾，断言数 `3917 → 3921` |
| **Batch B** | **`00b8518`** | `[CR-3][Batch-B] DeckFlow 大招槽改为按处理者分派并收拢大招事件钩子，下调规则5棘轮基线` | 大招槽写 `处理者` + `RuleHooks.按处理者` 分派，`deck_flow.gd` 规则 ⑤ 从 `53` 降至 **`14`**，全仓规则 ⑤ 从 `182` 降至 **`143`**（同提交下调基线） |
| **Batch C** | **`c6d53ae`** | `[CR-3][Batch-C] 实现 DeckFlow 武器栏换装栈，迁移 λ 驱动与脱装纳德雷并清零 deck_flow 硬编码卡 ID` | 实现 `压栈武器栏 / 弹栈武器栏 / 当前换装来源`，迁移 λ 驱动与脱装，`deck_flow.gd` 内 `V3_U7_` grep 清零，消除 4 条 `SCRIPT ERROR`，新增换装栈测试（断言数 `3921 → 3946`），既有测试 `test_celestial_v01.gd` 0 改动 |
| **Batch D1** | **`797733f`** | `[CR-3][Batch-D1] 拆分 session/game_session.gd 为子门面模块并收敛至 20k token 以内` | `game_session.gd` 从 `78,754 tok` 拆至 **`15,065 tok`** + 8 个 `session/*.gd` 子模块（均 `≤ 8,648 tok`），断言数 **`3946 → 3946`** |
| **Batch D2** | **`35fb33c`** | `[CR-3][Batch-D2] 拆分 presentation/battle/battle_view.gd 为面板与演出子模块并收敛至 15k token 以内` | `battle_view.gd` 从 `66,405 tok` 拆至 **`10,716 tok`** + 8 个 `presentation/battle/*.gd` 子模块（均 `≤ 8,507 tok`），断言数 **`3946 → 3946`** |
| **Batch D3** | **`4fc7e9e`** | `[CR-3][Batch-D3] 拆分 core/battle/btl.gd 为日志/战意/卡牌执行/阶段/意图/护卫子模块并收敛至 20k token 以内` | `btl.gd` 从 `45,996 tok` 拆至 **`5,094 tok`** + 8 个 `core/battle/*.gd` 子模块（均 `≤ 10,117 tok`），断言数 **`3946 → 3946`** |
| **Batch D4** | **`8b32939`** | `[CR-3][Batch-D4] 拆分 tests/unit/test_presentation_layout.gd 为面板版面测试套件，保持 3946 项断言不变` | `test_presentation_layout.gd` 从 `77,370 tok` 拆为薄入口（`241 tok`）+ `layout_fixtures.gd` + 10 个 `test_layout_*.gd`（均 `≤ 9,094 tok`），断言数 **`3946 → 3946`** |
| **Batch E** | **`ae87d67`** | `[CR-3][Batch-E] 新增规则6豁免审计与规则7体积棘轮，更新 RouteMap §1 拆分后锚点与 README 规范` | `build_godot_routemap.mjs` 实装规则 ⑥ 与规则 ⑦ `SIZE_RATCHET`、更新 §1 速查表（0 缺锚点）与 `godot/README.md` |

---

## 2. Batch A：7 条收尾逐条处理结果

1. **A1（让「卡不可打原因」等成为真正的钩子，清零 `rule_hooks.gd` 表外引用）**：
   - 在 `core/battle/rule_hooks.gd` 新增 `static func 首个结论(钩子: String, 参: Array) -> Dictionary`；
   - 在 `RuleHooks.顺序` 中正式登记 `"卡不可打原因": [AtxGodsbet, AtxThree, AtxChips, CelestialV01, AtxFaction, ClassCards, MithrilV03Cards]`，将原手写 `if` 链的每一支搬进各模块自己的 `static func 卡不可打原因(ctx, u, card, 区) -> Dictionary`（不归该模块管返回 `{"终局": false}`，归该模块管返回 `{"终局": true, "原因": "..."}`）；
   - 将原 `区规则门槛 / 合体技门槛 / 大招费用预览` 登记为 `顺序` 表钩子，`连携成员原因`（→ `MithrilV03Cards`）与 `职业牌入库原因`（→ `ClassCards`）并入 `卡不可打原因`；
   - **核验**：`rule_hooks.gd` 中除 `static var 顺序 := { ... }` 表声明以外，其余代码对势力/职业模块的引用为 **`0`**。
2. **A2（修 `CR-2回执.md` 勘误 + 写清 `flow.gd` 旁路攻击注释）**：
   - 在 [`CR-2回执.md`](CR-2回执.md) 末尾追加了「§7 更正（CR-3 Batch A 源码对账勘误）」；
   - 在 `core/battle/flow.gd` 的 `结算一个目标` 函数注释与 `旁路` 分支处，逐项写明 `旁路攻击 == true` 时**照常执行**的 9 项（`Fac.势力攻击前`、`Calc.resolveAttack`、`Calc.标定经济记录`、击破判定与 `Fac.势力击破 + Btl.记击破`、散布副目标击破记账、`CelestialV01.标记被攻击`、`CelestialV01.消费首击减伤`、`战况计数` 累加）与**跳过**的 7 项（`Btl.嘲讽`、标准攻击战报 `pushLog`、`CelestialV01.受击后`、镜甲反弹、被击破单位自爆递归、`DeckFlow.检查条件发牌`、`Fac.势力友军攻击后`），与源码逐行一致。
3. **A3（旁路攻击是否计入 `战况计数`）**：
   - **作者决定**：**计入（作者确认的有意行为变化）**。
   - 代码维持现状（`flow.gd:结算一个目标` 中旁路攻击照常累加 `战况计数`）。
   - 已在 `tests/unit/test_cr2_pipelines.gd` 新增 `_A3b_旁路攻击计入战况计数` 固定该行为：响介普通攻击打空 5 段后，打出【再来一把】重打 5 段全空，断言 `ctx.战况计数["未命中段"]` 从 `5` 变为 `10`（精确 `+5`）。
4. **A4（自爆不应白吃「首击减伤」—— 作者确认选方案 (a)）**：
   - **作者决定**：选 **(a)**（旁路攻击也消费首击减伤）。
   - 在 `flow.gd:结算一个目标` 中已将 `CelestialV01.消费首击减伤(ctx, t)` 移出 `if not 旁路:`，与 `标记被攻击` 同级无条件执行。
   - 已在 `test_cr2_pipelines.gd` 新增 `_A4b_自爆也消费首击减伤`（3 条断言）：挂有【GN 全盾·哈罗】的天人机体先挨一次敌机【自爆】（吃到 `−40%` 减伤并消费掉 `cb首击减伤`），随后再挨一次普通攻击不再享受 `−40%` 减伤。
5. **A5（补上 A1 门禁的洞 + 新暴露的 48 条违规及修法）**：
   - 将 `test_cr2_pipelines.gd` 的 `_A1_打一张可打的` 中 `可挑 == false` 的 `continue` 改为 `t.ok(false, "A1 P2-2 ★ 门面说可打，但没有合法目标：...")`；
   - **新暴露的违规**：4 场正式战斗扫出 **48 条**违规——当场上无存活敌机，或近战/短射程武器（如 `单分子刀 / 光束刃 / 热能角 / GN 长刃+`）及需敌机目标的卡牌（`轮盘双响 / 战术副武`）在射程内找不到任何合法敌机目标时，门面仍标 `可打 == true`；
   - **修法**：在内核 `CardPlay.不可打原因` 末尾新增 `_无合法目标原因(ctx, u, card, 区)`：对 `目标方 == "敌方"` 的卡牌校验场上至少存在 1 台合法（武器牌还须满足射程/可达）存活敌机，否则返回非空原因。修复后 **48 条违规全部消除，测试断言一字未改**。
6. **A6（`card_play.gd` 与 `rule_hooks.gd` 注释占比 ≤ 15%）**：
   - 保留首行 `## 职责` 与公开函数前一行 `##` 说明，清理后 `card_play.gd` 注释占比从 `47.8%` 降至 **`11.8%`**，`rule_hooks.gd` 从 `49.1%` 降至 **`14.1%`**（均 `≤ 15%`）。
7. **A7（去掉 `celestial_v01.gd:1821` 读战报推断结果并删除 `_末次攻击命中`）**：
   - 洛克昂 TRANS-AM 高速狙击破防改为直接读取 `_算子攻击` 透传回来的 `结算目标们`（真实受击目标与 `命中段数 > 0`），彻底删除 `CelestialV01._末次攻击命中`（全仓 `grep -rn "_末次攻击命中" godot/` 为 **0 结果**）。

---

## 3. Batch B：大招槽处理者清单与 `deck_flow.gd` 规则 ⑤ 前后值

### 3.1 大招槽处理者清单（模块 → 负责哪些槽与钩子）

| 处理者模块 (`槽["处理者"]`) | 负责的大招槽 | 实现的按处理者钩子 / 事件钩子 |
|---|---|---|
| **`"AtxGodsbet"`** (`AtxGodsbet`) | 响介【赌神·入局】槽（`AtxGodsbet._新槽` 写入） | `认领大招槽`、`大招不可打原因`（终局）、`打出大招` |
| **`"AtxThree"`** (`AtxThree`) | ATX 三小强 `v01别名` 大招槽（`AtxThree.装填大招槽` 写入） | `认领大招槽`、`大招不可打原因`（终局）、`打出大招`、`大招阶段初`（同步冷却并接管递减） |
| **`"AtxFaction"`** (`AtxFaction`) | ATX 合体技【轮盘双响】槽（`AtxFaction.放入大招槽` 写入） | `认领大招槽`、`大招不可打原因`（非终局，通过后继续走通用门槛）、`打出大招`、`大招结算后`（二次下注）、`大招收尾后` |
| **`"CelestialV01"`** (`CelestialV01`) | 天人【TRANS-AM·启动】与天人驾驶员/拉塞大招槽（`_大招槽条目` 写入 + `认领大招槽` 兜底） | `认领大招槽`、`大招不可打原因`（非终局）、`大招打出前`（`打出前介入 + 记打出`） |
| `AtxSmoke` / `AtxLuck` / `AtxChips` / `AtxDuo` | 挂在通用大招流程上的事件广播模块 | 登记在 `RuleHooks.顺序` 的 `大招打出前 / 大招打出后 / 大招结算后 / 大招收尾后` |

### 3.2 `deck_flow.gd` 与全仓规则 ⑤ 前后值

| 指标 | Batch B 前（`e6e9cc6`） | **Batch B 后（`00b8518`）** | 变化 |
|---|---:|---:|---:|
| **`core/battle/deck_flow.gd` 规则 ⑤ 引用数** | `53`（涉及 11 个势力文件） | **`14`**（仅剩 `mithril_v03_cards` 10 + `fac_mith` 4） | **`−39`（`−73.6%`）** |
| **全仓规则 ⑤ 总引用数** | `182` | **`143`** | **`−39`（`−21.4%`）** |
| **棘轮基线 `CORE_TO_FACTION_RATCHET_MAX`** | `182` | **`143`** | 同提交下调至 `143` |
| `deck_flow.gd` 内 `AtxGodsbet/AtxThree/AtxFaction/CelestialV01` grep | 39 处 | **`0 处`** | 完全清零 |

---

## 4. Batch C：武器栏换装栈数据结构样例

当提耶利亚（`CB4`）先打出【脱装·纳德雷】（永久层 `"脱装"`，将德天使原 3 把武器 `CB4_W1~W3` 换成纳德雷 3 把武器 `CB4_NW1~NW3`），随后再压入一层临时武器栏（如 `"METEOR"`）时，`u["武器栏栈"]` 的真实运行期结构如下：

```gdscript
u["武器栏栈"] = [
	{
		"来源": "脱装",
		"永久": true,
		"原表": [
			{"id": "CB4_W1", "名": "GN 火箭炮", ...},          # 德天使原武器卡 Dictionary 引用本身（未复制、未重建）
			{"id": "CB4_W2", "名": "GN 加农炮", ...},
			{"id": "CB4_W3", "名": "GN 光束军刀", ...},
		],
	},
	{
		"来源": "METEOR",
		"永久": false,
		"原表": [
			{"id": "CB4_NW1", "名": "纳德雷·GN 光束步枪", ...}, # 压入 METEOR 时的栈顶（即纳德雷武器卡 Dictionary 引用本身）
			{"id": "CB4_NW2", "名": "纳德雷·GN 加农炮", ...},
			{"id": "CB4_NW3", "名": "纳德雷·GN 光束军刀", ...},
		],
	},
]
# 此时 DeckFlow.当前换装来源(u) == ["脱装", "METEOR"]
# 调用 DeckFlow.弹栈武器栏(u, "METEOR") 后：
#   -> 返回 true，u["武器栏"] 原样恢复为 [CB4_NW1, CB4_NW2, CB4_NW3]（is_same 引用一致，运行期 cd 等字段完整保留）
#   -> DeckFlow.当前换装来源(u) == ["脱装"]
# 再调用 DeckFlow.弹栈武器栏(u, "脱装")：
#   -> 因 "脱装" 层 永久 == true，拒绝弹出并返回 false，武器栏保持纳德雷武器表不变。
```

- `grep -n "V3_U7_" godot/core/battle/deck_flow.gd`：**`0 结果`**（λ 替换表已迁入 `MithrilV03Cards.λ武器表(u)`）。
- 同时修复了 `DeckFlow.λ开启 / λ觉醒` 中 `u.get("形态")` 为字符串 `"纳德雷"` 时的类型守卫，消除了全量测试中原本存在的 4 条 `SCRIPT ERROR`。

---

## 5. Batch D：大文件拆分前后对比表、新文件清单、转发函数与断言总数

### 5.1 D5 验收总表（统一按 RouteMap §0.5 D1 口径：`token ≈ CJK × 1.0 + 其余 ÷ 3.5`）

| 文件 | 类别 | 拆前字节 / 行 / Token / 注释% | **拆后字节 / 行 / Token / 注释%** | 施工单目标 | 达标 |
|---|---|---:|---:|---|---|
| [`session/game_session.gd`](../../godot/session/game_session.gd) | 拆分源 (D1) | 258,093 B / 4,910 行 / **78,754 tok** / 41.8% | 50,781 B / 1,366 行 / **`15,065 tok`** / 9.9% | `≤ 20,000 tok` | ✅ |
| [`presentation/battle/battle_view.gd`](../../godot/presentation/battle/battle_view.gd) | 拆分源 (D2) | 215,740 B / 4,299 行 / **66,405 tok** / 38.4% | 35,053 B / 615 行 / **`10,716 tok`** / 12.7% | `≤ 15,000 tok` | ✅ |
| [`core/battle/btl.gd`](../../godot/core/battle/btl.gd) | 拆分源 (D3) | 150,579 B / 2,834 行 / **45,996 tok** / 32.2% | 17,028 B / 276 行 / **`5,094 tok`** / 4.6% | `≤ 20,000 tok` | ✅ |
| [`tests/unit/test_presentation_layout.gd`](../../godot/tests/unit/test_presentation_layout.gd) | 拆分源 (D4) | 260,037 B / 4,527 行 / **77,370 tok** / 19.0% | 826 B / 21 行 / **`241 tok`** / 14.0% | `≤ 20,000 tok` | ✅ |
| **D1 新增 8 个 `session/*.gd` 子模块** | | | | **单个 `≤ 12,000 tok` & 注释 `≤ 15%`** | |
| ├ [`session/battle_deck_view.gd`](../../godot/session/battle_deck_view.gd) | D1 新文件 | — | 28,977 B / 537 行 / **`8,648 tok`** / 8.2% | `≤ 12,000 tok` | ✅ |
| ├ [`session/display_helpers.gd`](../../godot/session/display_helpers.gd) | D1 新文件 | — | 25,837 B / 596 行 / **`7,726 tok`** / 11.9% | `≤ 12,000 tok` | ✅ |
| ├ [`session/battle_flow.gd`](../../godot/session/battle_flow.gd) | D1 新文件 | — | 25,234 B / 536 行 / **`7,577 tok`** / 12.0% | `≤ 12,000 tok` | ✅ |
| ├ [`session/run_facade.gd`](../../godot/session/run_facade.gd) | D1 新文件 | — | 22,498 B / 442 行 / **`6,728 tok`** / 11.2% | `≤ 12,000 tok` | ✅ |
| ├ [`session/battle_hand_view.gd`](../../godot/session/battle_hand_view.gd) | D1 新文件 | — | 20,725 B / 451 行 / **`6,221 tok`** / 11.6% | `≤ 12,000 tok` | ✅ |
| ├ [`session/tooltip_text.gd`](../../godot/session/tooltip_text.gd) | D1 新文件 | — | 18,139 B / 368 行 / **`5,437 tok`** / 5.4% | `≤ 12,000 tok` | ✅ |
| ├ [`session/roster_facade.gd`](../../godot/session/roster_facade.gd) | D1 新文件 | — | 14,084 B / 306 行 / **`4,177 tok`** / 6.5% | `≤ 12,000 tok` | ✅ |
| └ [`session/live_monitor.gd`](../../godot/session/live_monitor.gd) | D1 新文件 | — | 5,738 B / 140 行 / **`1,696 tok`** / 11.0% | `≤ 12,000 tok` | ✅ |
| **D2 新增 8 个 `presentation/battle/*.gd` 子模块** | | | | **单个 `≤ 12,000 tok` & 注释 `≤ 15%`** | |
| ├ [`presentation/battle/battle_fx_player.gd`](../../godot/presentation/battle/battle_fx_player.gd) | D2 新文件 | — | 27,716 B / 680 行 / **`8,507 tok`** / 12.4% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/hand_panel.gd`](../../godot/presentation/battle/hand_panel.gd) | D2 新文件 | — | 24,464 B / 477 行 / **`7,506 tok`** / 11.5% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/board_panel.gd`](../../godot/presentation/battle/board_panel.gd) | D2 新文件 | — | 23,105 B / 551 行 / **`7,025 tok`** / 11.3% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/hand_card_item.gd`](../../godot/presentation/battle/hand_card_item.gd) | D2 新文件 | — | 16,218 B / 332 行 / **`4,925 tok`** / 7.9% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/log_panel.gd`](../../godot/presentation/battle/log_panel.gd) | D2 新文件 | — | 15,277 B / 295 行 / **`4,735 tok`** / 8.9% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/deck_sidebar.gd`](../../godot/presentation/battle/deck_sidebar.gd) | D2 新文件 | — | 14,612 B / 305 行 / **`4,448 tok`** / 9.2% | `≤ 12,000 tok` | ✅ |
| ├ [`presentation/battle/drag_aim.gd`](../../godot/presentation/battle/drag_aim.gd) | D2 新文件 | — | 12,941 B / 313 行 / **`3,991 tok`** / 6.7% | `≤ 12,000 tok` | ✅ |
| └ [`presentation/battle/battle_animation_layer.gd`](../../godot/presentation/battle/battle_animation_layer.gd) | D2 新文件 | — | 10,691 B / 292 行 / **`3,196 tok`** / 12.2% | `≤ 12,000 tok` | ✅ |
| **D3 新增 8 个 `core/battle/*.gd` 子模块** | | | | **单个 `≤ 12,000 tok` & 注释 `≤ 15%`** | |
| ├ [`core/battle/card_pool.gd`](../../godot/core/battle/card_pool.gd) | D3 新文件 | — | 33,482 B / 770 行 / **`10,117 tok`** / 14.6% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/card_exec.gd`](../../godot/core/battle/card_exec.gd) | D3 新文件 | — | 28,956 B / 530 行 / **`8,802 tok`** / 14.5% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/weapon_exec.gd`](../../godot/core/battle/weapon_exec.gd) | D3 新文件 | — | 21,329 B / 385 行 / **`6,467 tok`** / 14.7% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/guard.gd`](../../godot/core/battle/guard.gd) | D3 新文件 | — | 17,254 B / 371 行 / **`5,198 tok`** / 14.1% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/phase_flow.gd`](../../godot/core/battle/phase_flow.gd) | D3 新文件 | — | 6,074 B / 151 行 / **`1,837 tok`** / 14.2% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/intent.gd`](../../godot/core/battle/intent.gd) | D3 新文件 | — | 5,128 B / 122 行 / **`1,550 tok`** / 13.3% | `≤ 12,000 tok` | ✅ |
| ├ [`core/battle/battle_log.gd`](../../godot/core/battle/battle_log.gd) | D3 新文件 | — | 4,391 B / 130 行 / **`1,318 tok`** / 14.6% | `≤ 12,000 tok` | ✅ |
| └ [`core/battle/morale.gd`](../../godot/core/battle/morale.gd) | D3 新文件 | — | 3,267 B / 96 行 / **`991 tok`** / 14.4% | `≤ 12,000 tok` | ✅ |
| **D4 新增 11 个 `tests/unit/*layout*.gd` 测试文件** | | | | **单个 `≤ 12,000 tok` & 注释 `≤ 15%`** | |
| ├ [`tests/unit/test_layout_hand.gd`](../../godot/tests/unit/test_layout_hand.gd) | D4 新文件 | — | 30,152 B / 514 行 / **`9,094 tok`** / 13.2% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_log.gd`](../../godot/tests/unit/test_layout_log.gd) | D4 新文件 | — | 28,784 B / 443 行 / **`8,638 tok`** / 13.2% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_board.gd`](../../godot/tests/unit/test_layout_board.gd) | D4 新文件 | — | 27,875 B / 497 行 / **`8,374 tok`** / 13.0% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_flow.gd`](../../godot/tests/unit/test_layout_flow.gd) | D4 新文件 | — | 26,114 B / 491 行 / **`7,897 tok`** / 13.2% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_sidebar.gd`](../../godot/tests/unit/test_layout_sidebar.gd) | D4 新文件 | — | 24,298 B / 416 行 / **`7,353 tok`** / 11.7% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_ux1.gd`](../../godot/tests/unit/test_layout_ux1.gd) | D4 新文件 | — | 22,953 B / 471 行 / **`6,923 tok`** / 13.0% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_screens.gd`](../../godot/tests/unit/test_layout_screens.gd) | D4 新文件 | — | 21,932 B / 431 行 / **`6,702 tok`** / 13.2% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_tooltip.gd`](../../godot/tests/unit/test_layout_tooltip.gd) | D4 新文件 | — | 20,039 B / 410 行 / **`6,097 tok`** / 13.0% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_drag.gd`](../../godot/tests/unit/test_layout_drag.gd) | D4 新文件 | — | 14,451 B / 211 行 / **`4,338 tok`** / 9.5% | `≤ 12,000 tok` | ✅ |
| ├ [`tests/unit/test_layout_factions.gd`](../../godot/tests/unit/test_layout_factions.gd) | D4 新文件 | — | 11,012 B / 180 行 / **`3,369 tok`** / 12.8% | `≤ 12,000 tok` | ✅ |
| └ [`tests/unit/layout_fixtures.gd`](../../godot/tests/unit/layout_fixtures.gd) | D4 新文件 | — | 10,393 B / 302 行 / **`3,096 tok`** / 13.9% | `≤ 12,000 tok` | ✅ |

### 5.2 原文件保留的同名转发函数汇总
1. **`session/game_session.gd`（保留 224 个同名一行转发 + 73 个核心状态/入口函数）**：
   - `SessionLiveMonitor`（13 个）：`实时监视开吗 / 设实时监视 / 切实时监视 / 实时监视快照 / _写实时监视 / _清实时监视 ...`
   - `SessionRunFacade`（48 个）：`选分队 / 开新局 / 地图可走格 / 地图走一格 / 用零件 / 卖零件 / 黑市买 / 奇遇选 / 休整选 / 拿奖励 ...`
   - `SessionRosterFacade`（31 个）：`名册列表 / 招募列表 / 招募一台 / 晋升预览 / 晋升一台 / 三选一候选 / 三选一拿一张 / 编队上阵 / 编队下阵 / 编队换位 ...`
   - `SessionBattleFlow`（29 个）：`start_quick_test_battle / start_quick_battle_celestial / 编成进战 / 推进一拍 / 结束我方回合 / 跳过到结果 ...`
   - `SessionBattleHandView`（24 个）：`upper_hand_cards / lower_hand_cards / _单机上排牌们 / _单机下排牌们 / _公有牌判定 / 卡目标方 ...`
   - `SessionBattleDeckView`（32 个）：`unit_deck_zones / public_deck_zones / play_unit_main_weapon / play_unit_sub_weapon / play_unit_ultimate / play_spirit_or_public_card ...`
   - `SessionDisplayHelpers`（31 个）：`单位卡展示 / 敌机意图展示 / 战报列表 / 天人徽章 / 太阳炉左栏文 / 筹码左栏文 / 连携左栏文 ...`
   - `SessionTooltipText`（16 个）：`unit_tooltip_text / card_tooltip_text / relic_tooltip_text / part_tooltip_text ...`
2. **`presentation/battle/battle_view.gd`（保留 185 个同名一行转发 + 15 个建树骨架/演出协程函数）**：
   - `BattleBoardPanel`：`_建中上棋盘区 / _刷新棋盘 / _定位单位卡 / 援护连线数 / 敌机意图箭头数 ...`
   - `BattleHandPanel` & `BattleHandCardItem`：`_建中下手牌区 / _刷新中下手牌 / 手牌卡控件们 / 候补联动 / 联动高亮 ...`
   - `BattleDeckSidebar`：`_建左牌库栏 / _刷新左牌库 / 左库卡控件们 / _点左库折叠 ...`
   - `BattleLogPanel`：`_建右战报栏 / _刷新右战报 / _同步控制钮 ...`
   - `BattleDragAim`：`开始拖拽 / 拖拽到 / 结束拖拽 / 取消拖拽 / 拖拽瞄准线 / 可拖拽释放 ...`
   - `BattleFxPlayer` & `BattleAnimationLayer`：`_推演出帧 / _取本拍事件 / _闪卡反馈 / _飘字 ...`
3. **`core/battle/btl.gd`（全数 125 个静态函数保留一行同名转发）**：
   - `BattleLog`（10 个）：`pushLog / 谁 / 谁目标 / 效果摘要文 / 攻击结果摘要 ...`
   - `BattleMorale`（12 个）：`战意 / 加战意 / 扣战意 / 实际耗气 / 气势 / 加气势 ...`
   - `BattleGuard`（17 个）：`嘲讽 / 靶机援护 / 援护剩余文 / 当前援护连线们 / 镜甲反弹 / 自爆 ...`
   - `BattleIntent`（6 个）：`算意图 / 算意图表 / 刷新敌方意图 ...`
   - `BattlePhaseFlow`（9 个）：`开始我方阶段 / 结束我方回合 / 记击破 ...`
   - `BattleCardPool`（42 个）：`初始化单机牌组 / 抽专属牌 / 抽公有牌 / 武器栏不可打原因 / 查手牌 ...`
   - `BattleCardExec`（17 个）：`打出精神或公有牌 / _执行精神或公有效果 / _执行支援卡 ...`
   - `BattleWeaponExec`（12 个）：`打出主武器卡 / 打出副武器卡 / 打出大招槽卡 / 打出武器栏卡 / _执行武器攻击 ...`

### 5.3 Batch D 拆分前后测试断言总数对比
- **Batch D1 前（Batch C 结束）**：`✓ 全部通过：3946 项`
- **Batch D1 后（`797733f`）**：`✓ 全部通过：3946 项`
- **Batch D2 后（`35fb33c`）**：`✓ 全部通过：3946 项`
- **Batch D3 后（`4fc7e9e`）**：`✓ 全部通过：3946 项`
- **Batch D4 后（`8b32939`）**：`✓ 全部通过：3946 项`（其中版面测试 40 个 `_段*` 函数、`675` 处 `t.ok` 调用点、运行期 `915` 条版面断言与拆前逐条完全相等）

---

## 6. 规则 ⑤ / ⑥ / ⑦ 的当前值与基线

| 规则编号 | 审计内容 | CR-3 前 | **CR-3 后当前值** | **棘轮基线 / 阈值** | 状态 |
|---|---|---:|---:|---:|---|
| **规则 ⑤** | 通用内核文件 → 势力模块引用总次数 | `182`（CR-1 初为 `213`） | **`143`** | `CORE_TO_FACTION_RATCHET_MAX = 143` | ✅ `0 违规`（累计净降 `70` 次，`−32.9%`） |
| **规则 ⑥** | 豁免注册表文件（`rule_hooks.gd` / `fac.gd`）在顺序表/分派块以外对势力/职业模块的引用数 | 未设门禁 | **`0`**（`rule_hooks` 表外 `0`，`fac` 分派块外 `0`） | 必须 `== 0` | ✅ `0 违规` |
| **规则 ⑦** | 单文件体积棘轮（新文件 `≤ 1,000 行 & ≤ 12,000 tok`；既有超限文件 `SIZE_RATCHET` 只许下降） | 未设门禁（4 个超大文件 `46k~79k tok`） | **23 个既有文件登记在案，最大文件已降至 `40,173 tok`；新文件超限警告 = `0`** | `SIZE_RATCHET` 逐文件锁死 | ✅ `0 违规 / 0 警告` |

---

## 7. 执行中的偏差与需知会事项

1. **Batch D2 旧手牌栏（`_手牌栏` / `_手牌滚动`）保留说明（按 §4 D2 指令上报）**：
   - 施工单 D2 写明：「删除已经没人走的旧手牌栏……删之前先确认正式口径和现有测试都不再进入那条路径；如果某个测试还依赖它，写进回执，由 Claude 判断是删测试还是保留。」
   - 核查发现：现有版面测试段 12②（原 `test_presentation_layout.gd:2834`，现 `test_layout_hand.gd`）和段 16②（原 `:4184`，现 `test_layout_factions.gd`）显式断言了 `v._手牌滚动 != null and not v._手牌滚动.visible`，段 16③（原 `:4190`）用 `v._手牌栏.get_global_rect()` 作为底部越界参照框，另有 6 处读取 `_手牌列表`。
   - 为严守「现有测试断言一条不删不改」的红线，将该旧手牌栏构建函数原样搬入 `hand_panel.gd` 保留，特此在回执中上报，供 Claude 决定后续是否连同这几条旧控件断言一起退役。
2. **Batch B `大招不可打原因` 钩子返回值采用 `{终局, 原因}` 字典**：
   - 在 `DeckFlow.大招不可打原因` 的现行语义中，`AtxGodsbet`（入局卡）和 `AtxThree`（`v01别名`）是「最终裁决（过关即返回 `""`，不再走后续通用门槛）」，而 `CelestialV01` 和 `AtxFaction`（合体技）是「前置附加门槛（返回 `""` 后仍须继续检查通用冷却/战意/次数门槛）」。因此处理者的 `大招不可打原因(ctx, u, 槽)` 统一返回 `{终局: bool, 原因: String}`，使分派器无需硬编码区分哪家模块是终局裁决，保持行为 100% 零变化。
3. **Batch D1 / D2 / D3 / D4 子文件个数微调（为严守单个新文件 `≤ 12,000 token` / `≤ 1,000 行`）**：
   - D1 在建议的 5 个文件基础上多拆出 `roster_facade.gd`、`battle_deck_view.gd`、`battle_flow.gd`（共 8 个）；
   - D2 在建议的 6 个文件基础上将手牌卡单项与动画层拆出 `hand_card_item.gd`、`battle_animation_layer.gd`（共 8 个）；
   - D3 在建议的 6 个文件基础上将牌池与武器执行拆出 `card_pool.gd`、`weapon_exec.gd`（共 8 个）；
   - D4 按面板与主题拆为 `layout_fixtures.gd` + 10 个 `test_layout_*.gd`（共 11 个）。
   - 由此确保全仓新增的 **35 个子文件 100% 落在 `≤ 10,117 token`、`≤ 770 行`、注释占比 `≤ 14.7%` 以内**，规则 ⑦ 零警告。
