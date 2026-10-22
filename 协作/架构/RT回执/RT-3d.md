# RT 回执 · RT-3d

> 决策表第 12 行：**剩下的测试迁移**。判据两条：
> ① 只是「借旧入口开一场战斗」→ 改走新入口（`开始快速测试战斗`），**断言不动**；
> ② 断言测的就是**旧屏本身** → 保留旧入口，把实测证据写进代码注释，等 RT-4 删旧屏时一起走。
>
> 前置事实：RT-3b 已把 13 个混合文件里的大头迁完 —— 剩下的 `战术手牌 / 候补初始牌 / 候补补位`
> **全都在注释里**（不是断言），`Btl.打战术牌` / `play_tactical_card` / `候补补位()` 也已经没有调用点。
> 所以本单真正要做的是**还落在旧入口 `start_quick_battle()` 上**的那 5 处。

## 0. 清点（旧入口 = 不带 `单机牌组` 开局）

| `文件:行` | 它拿这场战斗做什么 | 处理 |
|---|---|---|
| `test_layout_tooltip.gd:51` | 段 3a 只量 `UnitCard` 的 tooltip | 改新入口（§1） |
| `test_layout_hand.gd:20-21` | 段 12 先 `set_unit_deck_mode(true)` 再开 | 改新入口（§2） |
| `test_session_flow.gd:1285` | D-07 快速战结算 / 幂等 | 改新入口（§3） |
| `test_session_flow.gd:1304` | D-07 再开一场、标志复位 | 改新入口（§3） |
| `test_ux5_ux6_feedback.gd:227` | 段 ③ 断言「旧战斗屏没有憋大招字」 | **保留**（§4，有实测证据） |

`start_quick_battle_celestial()` / `start_quick_test_battle()` / `开始快速测试战斗()` 都是**新**入口
（内部走 `_开快速测试战` → `单机牌组模式 = true`），12 个测试文件已经在用，本单只做复核。

## 1. `[RT-3d-1]`（`5c9b1eb`）`test_layout_tooltip.gd`：段 3a 改走新入口

- 改：`s.start_quick_battle(20261013)` → `s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013)`（1 处 2 行 + 1 行注释）。
- 断言一条没动：段 3a 只量 `UnitCard` 的 tooltip 与编队 / 招募屏；段 3b 本来就有「手上没牌就换新入口」的兜底。
- 测试：`test_presentation_layout` ✓ 856（10 个 `test_layout_*` 都由它驱动，项数不变）· 全量 3568。

## 2. `[RT-3d-2]`（`90aaa6e`）`test_layout_hand.gd`：段 12 改走新入口

- 改：删掉 `s.set_unit_deck_mode(true)` + `start_quick_battle` 这对旧组合（A6 时代「界面先拨开关再开战」的写法），
  换成菜单现在真正调的 `开始快速测试战斗(GameSession.快速测试_秘银, 20261020)`（`menu_view.gd:136`）。
- 断言一条没动（上排三栏 / 下排公有牌 / 零滚动那一整套）。
- 测试：`test_presentation_layout` ✓ 856 · 全量 3568。

## 3. `[RT-3d-3]`（`a8e113d`）`test_session_flow.gd`：D-07 那两处

- 改：`:1285` / `:1304` 的 `q.start_quick_battle(快速种子 + 3 / + 4)` → `开始快速测试战斗(秘银, …)`。
- 新入口多出来的两件事都没碰到 D-07 的断言：`单机牌组` 只把开场战意设成 80、`_快速测试局` 只把敌机换成试玩靶机
  且不写存档（`battle_flow.gd:68-74`、`game_session.gd:245`）；`finish_battle_and_settle` 的幂等 / 复位判据完全不变。
- 测试：`test_session_flow` **240/240**（项数没变）· 全量 3568。

## 4. `[RT-3d-4]`（`5e61b2f`）`test_ux5_ux6_feedback.gd`：段 ③ **保留旧入口**（附实测）

- 段 ③ 测的是「旧战斗屏里没有可见的憋大招按钮 / 控制栏还是那套」。按第 12 行试过换成新入口，**实测 2 条断言不成立**（已回滚）：
  ① 控制栏变成「结束我方回合 / 全员自动回合 / 2x 加速 / 跳过本回演出 / 结束并结算」那套；
  ② 整棵树冒出「憋大招」三个字（`session/display_helpers.gd:487` 的 `u.holdUlt` 状态行 + 牌面说明）。
- 「断言不动」优先 → 保留旧入口，把这 2 条实测证据写进代码注释（顺手把 RT-3b 那段旧注释合并，不留两段历史）。
- 测试：`test_ux5_ux6_feedback` **53/53** · 全量 3568。
- 发牌动画那一问（第 12 行后半句）RT-3b 已查完并记进 `RT-3b.md` 的「已知缺口」表（`card_deal` 帧恒 0，
  保留 6 条用合成输入验拆帧逻辑的守卫）—— 本单**没有新增缺口**。

## 5. `[RT-3d-5]`（`963e194`）+ `[RT-3d-6]`（本提交）RouteMap 生成物重建

- 前面 4 个提交只改 `tests/unit/`，三份生成物（`Godot-RouteMap.md` / `-明细.md` / `Godot-AST依赖清单.json`）随之变了。
- `[RT-3d-5]` 重建时**临时探针 `godot/_rt3d_probe.gd` 还在盘上**，生成物把它算成了第 152 个 `.gd`；
  探针删掉之后 `--check` 报「152 vs 151 个文件」不同步。`[RT-3d-6]` 按干净的源码**再重算一次**，`--check` 才回到 `violations = []`。
  （教训：重建 RouteMap 要在「临时文件已删」的树上做。）

## 6. 门禁（最后一次全量）

```
godot --headless --path godot --script res://tests/run_tests.gd  → EXIT=0
  ✓ 全部通过：3568 项 · [test_native_goldens] ✓ 11 · [test_presentation_layout] ✓ 856
node godot/tools/build_godot_routemap.mjs --check                → EXIT=0（violations = []）
```

- 项数 **3568 → 3568（±0）**：本单只换入口，一条断言都没删、没加。
  第 12 行「删测试跟着被删的代码走同一个提交」在这批里**没有适用对象** —— 要删的代码 RT-3b 已经删完了。

## 7. 不动的（附理由）

| 文件 / 位置 | 为什么不动 |
|---|---|
| `test_unit_deck_system.gd:533`「关着时一个字段都不多」 | 它测的是 `单机牌组` **关着**那条路，不是「借旧入口开一场战斗」；RT-4 删掉这条路径时一起走 |
| `test_session_run.gd` | 决策表第 13 行：不动 |
| `test_run_core.gd:371` 的 `{"战术卡牌": true}` 夹具 | RT-3b 已把「每回合先打一张战术牌」删掉（旧字段恒空）；改成新入口会把公有牌带进来、改变这条夹具的前提 |
| `test_presentation_smoke.gd` | 走的是真肉鸽路径 `start_node_battle()`，不是快速入口 |
| `test_layout_screen / flow / board / log / sidebar` | 已经是新入口，本单只做复核（`test_layout_log` 的播报条也不再读「发牌」事件） |

## 8. 交给 RT-4 的一件事

- 旧入口 `GameSession.start_quick_battle()` 现在**生产代码 0 个调用**（菜单三个按钮走 `开始快速测试战斗` / `start_quick_battle_celestial`），
  全仓只剩 `test_ux5_ux6_feedback.gd:228` 这一处**故意**保留的调用。RT-4 删旧战斗屏时，这个入口和那段测试一起走；
  注意它还是录像里的动作名（`_record_action("start_quick_battle", …)`），删之前要确认旧录像重放口径。
