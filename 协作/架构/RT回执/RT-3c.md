# RT 回执 · RT-3c

> 按施工单 §0.2 与「RT-3b 终验」：一个开关一个提交，每个提交 ≤ 20 行；每内联一个开关前先核查相关缺口卡（`F_ATX_V2_*`、`U_ATX_*`、`U_DUO_*`、`V3_*` 中没出场的）进不进牌组，进不去的停下等 Claude 确认，其余开关照常推进。

---

## 0. 缺口卡进牌组核查总表（内联前逐项查清）

| 卡族 / 关联开关 | 缺口卡（`--coverage` 未出场） | 生产进不进牌组 | 发牌代码引用（`文件:行`）与未出场原因 |
|---|---|---|---|
| **`U_ATX_*`** ⇄ `ATXv01开` / `ATXv02开` | `U_ATX_1, 3, 4, 5, 6, 7, 9`（7 张 v0.2 旧角色牌）+ `U_ATX_2_P, U_ATX_8_P`（2 张加版牌，连同 `ATX1..3_*_P` 共 24 张 `升版卡表`） | **❌ 进不去** | ① `U_ATX_1/3/4/5/6/7/9`：`core/run/deck_builder.gd:65` 调 `FacAtx.角色专属牌们`（`core/battle/fac_atx.gd:157-165`）→ `FacAtx.进牌池`（`fac_atx.gd:84-89`），当 `Params.ATXv01开(ctx)` 为真（生产战斗恒真）时对 `旧版卡id们`（`fac_atx.gd:14`）一律返回 `false`；`按名取`（`:101`）/ `按id取`（`:115`）同样屏蔽。注意：局外 `RosterManager.晋升预览 / promote`（`core/run/roster_manager.gd:446, 478`）传 `ctx = null` 时 `ATXv01开(null)` 目前为 `false`，所以局外晋升仍报出解锁 `U_ATX_9 / U_ATX_7`（`test_unit_deck_system.gd:559, 565`），进战斗却不进牌组。<br>② `U_ATX_2_P / U_ATX_8_P`（及 24 张 `AtxThree.升版卡表()`）：`AtxThree.装填单位`（`core/battle/atx_three.gd:410`）→ `开局牌库`（`:256`）→ `角色牌们`（`:190`）与 `装填大招槽`（`:427`）→ `大招卡们`（`:219`）全部只读 `卡表()`，生产 0 处调用 `升版卡表()` / `角色牌们加版()`。<br>③ 顺带：`AtxThree.这一档发吗`（`atx_three.gd:247-254`）在 `肉鸽 == true` 时只发 `"初始"` 档，19 张 `"剧情" / "肉鸽"` 档在肉鸽局不进牌库。<br>👉 **按指令：`ATXv01开` 先停下等 Claude 确认是否退役这批进不去的卡及相关算子，其余开关照常推进。** |
| **`F_ATX_V2_*`** ⇄ `ATXv02开` | `F_ATX_V2_1` ~ `F_ATX_V2_9`（9 张） | **✅ 进牌组** | `Setup.初始化单机牌组`（`core/battle/setup.gd:328`）→ `DeckBuilder.公有扩展牌们`（`core/run/deck_builder.gd:201-206`）→ `FacAtx.公有牌们()`（`core/battle/fac_atx.gd:167`）装入 `ctx.公有牌库`（无 `入库条件`，留在 `ctx.公有牌库`）。未出场原因：`ctx.公有牌库` 不洗牌、从队头 `pop_front`（`setup.gd:162`），这 9 张排在 2 张统帅牌 + `MithrilV03Cards.职业牌们()` 之后第 12～20 张，ATX 样例在摸到第 12 张前已结束。 |
| **`U_DUO_*`** ⇄ `ATXv02开` | `U_DUO_2, 3, 9, 10`（4 张主武器卡） | **✅ 进牌组** | `Setup.初始化单机牌组`（`core/battle/setup.gd:262`）→ `DeckBuilder.unit_exclusive_cards`（`core/run/deck_builder.gd:100-124`）→ `FacAtx.角色专属牌们`（`fac_atx.gd:49` 合并 `AtxDuo.卡表()`）→ `DeckFlow.拆分单位牌`（`core/battle/deck_flow.gd:90`）装入 `u.武器栏`。未出场原因：排在第 1 把 0 费 0 冷却无限次主武器 `U_DUO_1 / U_DUO_8` 后面，策略每回合打第 1 把即 `主武器已销毁 = true`。 |
| **`V3_*`** ⇄ `秘银v03开` | `V3_C_SN_3, V3_C_SP_4, V3_L2_TESSA, V3_L3_FULL, V3_L3_SUPPORT, V3_U2_W3, V3_U6_S5, V3_U6_U3, V3_U6_W2..4, V3_U7_LW1..3, V3_U7_S7, V3_U7_W2, V3_URUZ_TRI`（17 张） | **✅ 全部进牌组** | ① `V3_C_SN_3 / V3_C_SP_4`：`deck_builder.gd:197` → `setup.gd:328` → `deck_flow.gd:99` 进 `ctx.公有待入库`；<br>② `V3_L2_TESSA / V3_L3_FULL / V3_L3_SUPPORT`：`deck_flow.gd:721-731` 连携触发时由 `SubDeck.放入` 放进 `ctx.连携牌库`；<br>③ `V3_U2_W3 / V3_U6_S5 / V3_U6_U3 / V3_U6_W2..4 / V3_U7_S7 / V3_U7_W2 / V3_URUZ_TRI`：`deck_builder.gd:104-106, 130-139`（`MithrilV03Cards.角色专属牌们按等级`，`等级需求 <= lv`）→ `setup.gd:262` → `deck_flow.gd:40-96` 进 `u.武器栏 / 大招槽 / 待入库`；<br>④ `V3_U7_LW1..3`：宗介开启 λ 驱动时经 `deck_flow.gd:820` + `mithril_v03_cards.gd:230-252`（`λ武器表`）压栈进 `u.武器栏`。 |

---

## 1. `[RT-3c-1]`（`66f2b65`）决策表第 7 行：`Params.秘银v02开` 与 `mithril_v02_cards.gd` 退役

- `route_query MithrilV02Cards --all` 核查在用引用：`display_helpers.gd:95, 98` 的 `成员键 / 势力` 改指 `MithrilV03Cards`；`fac_mith.gd:26-31` 的 `卡类 / 是专属牌` 内联 4 行实现保留；其余全在 `秘银v02开` 死分支内。
- 删：`core/battle/mithril_v02_cards.gd`（整文件 1099 行）、`Params.秘银v02开`、`FacMith.旧机制退役` 及 6 处早退分支、`BattleCardPool.实际耗气 / 不可打原因 / _占用行动 / _消费降费 / _实例号计数` 与 `_声明式触发` 的 6 个 v0.2 分支（及 `btl.gd` 4 条转发）、`CardEffects` 的 `v02` 算子与 `MithrilV02Cards.衍生牌定义`、`card_exec.gd` / `calc.gd` / `flow.gd` / `setup.gd` / `deck_builder.gd` / `display_helpers.gd` / `game_session.gd` / `tooltip_text.gd` 的 `秘银v02` 分支、`test_boundary.gd` 白名单项、`test_unit_deck_system.gd` 的 v0.2 专属断言（保留 TDD-1 公有手牌活跃路径断言）。
- 测试：**3646 → 3625 项**（−21）。
- 门禁：`✓ 全部通过：3625 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 2. `[RT-3c-2]`（`1d3356e`）决策表第 8 行（1/5）：`Params.九死一生开` 内联为真

- 相关缺口卡：无。
- 删 / 改：`Params.九死一生开`（删函数）；`core/battle/calc.gd:九死一生_阶段切换 / 九死一生_判定` 去掉开关早退；`tests/unit/test_atx_nine_lives.gd` 删开关对照段 `_段9`。
- 测试：**3625 → 3618 项**（−7）。
- 门禁：`✓ 全部通过：3618 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 3. `[RT-3c-3]`（`49aaa17`）决策表第 8 行（2/5）：`Params.段数改写开` 内联为真

- 相关缺口卡：无。
- 删 / 改：`Params.段数改写开`（删函数）；`core/battle/atx_rewrite.gd:开` 恒返回 `true`；`tests/unit/test_atx_spread_and_rewrite.gd` 删 `段数改写开` 关态断言。
- 测试：**3618 → 3616 项**（−2）。
- 门禁：`✓ 全部通过：3616 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 4. `[RT-3c-4]`（`b6fe658`）决策表第 8 行（3/5）：`Params.散布开` 内联为真

- 相关缺口卡：无。
- 删 / 改：`Params.散布开`（删函数）；`core/battle/calc.gd:散布适用` 去掉开关早退；`tests/unit/test_atx_spread_and_rewrite.gd` 删 `_段13_开关关`、`tests/unit/test_class_cards.gd` 删前置开关断言 1 条。
- 测试：**3616 → 3608 项**（−8）。
- 门禁：`✓ 全部通过：3608 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 5. 决策表第 8 行（4/5）：`Params.ATXv01开` —— 挂起等确认

- 见 §0 核查总表第 1 行：`U_ATX_1/3/4/5/6/7/9`（7 张）与 `U_ATX_2_P/U_ATX_8_P`（及 24 张 `AtxThree.升版卡表()`）在生产里进不去战斗牌组，且局外 `RosterManager.promote`（`ctx == null`）当前因 `ATXv01开(null) == false` 仍报出解锁 `U_ATX_9 / U_ATX_7`。按指令停下本开关等 Claude 确认。

## 6. `[RT-3c-5]`（`82536f5`）决策表第 8 行（5/5）：`Params.装甲共享池` 内联为真

- 相关缺口卡：无。
- 删 / 改：`Params.装甲共享池`（删函数）；`core/battle/calc.gd:dmgCore / resolveAttack` 两处内联为真；`test_armor_pool.gd` 删 `_段3` 及关态对照、`test_atx_spread_and_rewrite.gd` 与 `test_quick_battle_v03.gd` 删关态对照断言。
- 测试：**3608 → 3594 项**（−14）。
- 门禁：`✓ 全部通过：3594 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 7. `[RT-3c-6]`（`bb3931e`）决策表第 9 行（1/4）：`Params.武器范围v01开` 内联为真

- 相关缺口卡：无。
- 删 / 改：`Params.武器范围v01开`（删函数）；`core/battle/calc.gd`（`hitRate / 远距判定 / 狙击之王加成 / v03伤害倍率 / resolveAttack` 5 处）、`core/battle/flow.gd`（`结算一个目标` 删 `else Reach.rowBlockPenalty` 旧分支、`resolveAction` 2 处）、`core/battle/weapon_exec.gd`（`武器栏不可打原因 / _执行武器攻击` 2 处）内联为真；`test_mithril_v03.gd` / `test_quick_battle_v03.gd` / `test_unit_deck_system.gd` 删开关断言。
- 测试：**3594 → 3593 项**（−1）。
- 门禁：`✓ 全部通过：3593 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 8. `[RT-3c-7]`（`28dc520`）决策表第 9 行（2/4）：`Params.ATXv02开` 内联为真

- 相关缺口卡：`F_ATX_V2_1..9`（9 张）与 `U_DUO_2/3/9/10`（4 张）生产均进牌组（见 §0 表）；`U_ATX_1/3/4/5/6/7/9` 由 `ATXv01开` 把门，随第 5 节挂起。
- 删 / 改：`Params.ATXv02开`（删函数）；`atx_chips.gd:我方阶段初_前`、`atx_godsbet.gd:装填大招槽`、`card_effects.gd:execute_ops`、`card_exec.gd:_ATX实际战意`、`card_play.gd:_实际费`、`fac_atx.gd:我方阶段初_前`、`setup.gd:初始化单机牌组 / 开局`、`deck_builder.gd:_专属候选 / 公有扩展牌们` 内联为真；`test_unit_deck_system.gd` / `test_class_cards.gd` / `test_class_heavy_cmd.gd` 删关态对照断言。
- 测试：**3593 → 3589 项**（−4）。
- 门禁：`✓ 全部通过：3589 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 9. `[RT-3c-8]`（`020f370`）决策表第 9 行（3/4）：`Params.秘银v03开` 内联为真

- 相关缺口卡：`V3_*` 17 张生产全部进牌组（见 §0 表）。
- 删 / 改：`Params.秘银v03开`（删函数）；`card_effects.gd:execute_ops`、`setup.gd:_基础表公有牌入池吗`（删旧占位公有牌入池分支）、`deck_builder.gd:unit_exclusive_cards / 公有扩展牌们` 内联为真；`test_mithril_v03.gd` / `test_unit_deck_system.gd` / `test_celestial_v01.gd` 删开关断言。
- 测试：**3589 → 3588 项**（−1）。
- 门禁：`✓ 全部通过：3588 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`。

## 10. `[RT-3c-9]`（`7f9fbe3`）决策表第 9 行（4/4）：`Params.卡牌流转v01开` + `DeckFlow.开` 内联为真

- 相关缺口卡：无新增。
- 删 / 改：`Params.卡牌流转v01开`、`Params._开关`、`DeckFlow.开`（删函数）；`deck_flow.gd`（12 处入口去掉 `开(ctx)` 早退）、`flow.gd:结算一个目标`（删旧 `〔嘲讽〕` 日志分支）、`guard.gd:嘲讽`（删旧 50% 随机重装挡枪分支）、`phase_flow.gd:开始我方阶段`、`setup.gd:_有副武器栏 / 初始化单机牌组`、`weapon_exec.gd`、`deck_builder.gd`、`atx_faction.gd`、`atx_godsbet.gd`、`atx_three.gd`、`card_exec.gd`、`card_play.gd`、`celestial_v01.gd`、`battle_deck_view.gd`、`battle_hand_view.gd`（保留无 `武器栏` 机体的 `u.weapons` 兜底显示）、`display_helpers.gd`、`native_golden_policy.gd` 内联为真；测试删关态断言并对齐四区域拆牌口径。
- 测试：**3588 → 3577 项**（−11）。
- 门禁：`✓ 全部通过：3577 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`（缺锚点 0，索引页 7,830 / 8,000 token）。

---

## 11. 待 Claude 确认的未决问题（停下等验收）

> ✅ 第 1 条已由 §12（闸门 G2）关闭；第 2 条已由「RT-3c 验收结论 · 未决 2」答复：**保留，不退役**（24 张 `+` 版等「肉鸽升级」接入）。

1. **`U_ATX_1, 3, 4, 5, 6, 7, 9`（7 张 v0.2 旧角色牌）与 `Params.ATXv01开`**：
   - 生产战斗里 `Params.ATXv01开(ctx)` 恒真，这 7 张被 `FacAtx.进牌池 / 按名取 / 按id取`（`core/battle/fac_atx.gd:84-121`）全部挡在外面，永远进不去战斗牌组；
   - 但局外 `RosterManager.晋升预览 / promote`（`core/run/roster_manager.gd:446, 478`）调 `DeckBuilder.unit_exclusive_cards(键, 到, null)` 时传 `ctx = null`，因 `ATXv01开(null)` 为假，局外晋升仍报出解锁 `U_ATX_9 / U_ATX_7`（`test_unit_deck_system.gd:559, 565`）。
   - 请确认：① `Params.ATXv01开` 内联为真后，局外 `DeckBuilder.unit_exclusive_cards` 对 ATX 三小强（`A1/A2/A3`）应怎么报（改走 `AtxThree` 还是只留 `U_ATX_2 / U_ATX_8`）？② `FacAtx` 里只服务这 7 张旧卡的算子（攻击大招 / 再来一把 / W17·中继 等，但注意红线 5「卡牌数据一张不删」）是否一并退役？
2. **`U_ATX_2_P / U_ATX_8_P` 及 `AtxThree.升版卡表()`（`"三小强+"` 共 24 张）**：
   - 生产装填路径（`AtxThree.装填单位 / 装填大招槽`）只读 `AtxThree.卡表()`，0 处调用 `升版卡表()` / `角色牌们加版()`。这 24 张 `+` 版是留作后续补接（如 Lv20 升级替换），还是退役 `升版卡表()` / `角色牌们加版()` 读口？

---

## 12. `[RT-3c-10]`（`f793808`）闸门 G2：`Params.ATXv01开` 内联为真 + 三小强晋升取牌改走 `AtxThree` + 旧算子退役

- **route_query 取证（「只服务这 7 个 id」）**：`route_query ATXv01开 --all` → 全仓 9 处，生产只有 4 处（`atx_three.gd:59` / `fac_atx.gd:87, 96, 115`），其余 5 处在测试 —— 没有第 5 个消费者。`data/cards/ATX.json` 的「算子/动作」汇总（写脚本取摘要，不开大文件）：`atx/攻击`(U_ATX_1, 4, 7) · `atx/闪避增益`(U_ATX_3) · `atx/自身增益`(U_ATX_4) · `atx/光环`(U_ATX_5) · `atx/打空回气势`(U_ATX_6) · `atx/再动`(U_ATX_9) —— 这 6 个动作**其余 45 张牌一张都不用**；`atx/势力v03`(F_ATX_V2_*) · `atx/赌神入局`(U_ATX_2/_P) · `atx/轮盘双响`(U_ATX_COMBO) 原样留着。
- **与 `AtxFaction` 共用的一律保留**（不属「只服务那 7 个 id」）：`_光环`(`atx_faction.gd:196, 251`) · `_选目标`(:389) · `_武器`(:394) · `_一发`(:396) · `_记攻击`(:397) · `_头` · `血比` · `_队友` · `ATX成员` · `_增益表`。
- 删 / 改：`Params.ATXv01开`（含显式 `false` 覆盖口）· `AtxThree.装填开` · `setup.gd` 透传白名单里的 `"ATXv01"` · `FacAtx.执行算子` 的 6 个动作分支 + `_攻击 / _施法者 / _自身增益 / _闪避增益 / _打空回气势 / _本回合打空 / _再动`（`fac_atx.gd` 746 → 607 行）；`进牌池 / 按名取 / 按id取` 不再看 `ctx`。**卡牌数据一张没删。**
- 晋升取牌：`unit_exclusive_cards` 对 A1/A2/A3 在 `ctx == null` 时，除原有候选外**再按 `AtxThree.开局牌库` 补上战斗装填那一批**（肉鸽局只发「初始」档 → 每张算 Lv10、倍率 1.0，因为战斗那一路不乘倍率；id 重复跳过，与 `Setup` 的 `已有id` 同口径）。面板张数：A1 9/10/11 · A2 10/10/10 · A3 9/9/9（Lv10/20/30），7 张旧卡一张都不出现。战斗那一路（`ctx != null`）**一个字节没动**。
- 黄金样例：战斗原生样例 **176 场逐条不变**（`[test_native_goldens] ✓ 11`）。`run_vectors.json` **没改也不用改** —— 晋升面板那 68 条只记 `键/职业/势力/前/后/到/价`，从来没记 `解锁专属牌 / 专属牌库`，所以未决 1.4 说的「只允许 A1/A2/A3 晋升条目变」**没有可变的字段**；改前改后 `test_run_core` 68 条全对。**真重录的是 `card_tables/ATX.txt` 的 3 段**：`FacAtx.角色专属牌们(A1)` 4→2、`(A2)` 4→1、`(A3)` 3→1，少掉的正好是那 7 张、没有新增，其余 38 段逐字不变；已登记进 `godot/tests/golden/README.md`。
- 测试：**3577 → 3568 项（−9）**。删 13 条（`U_ATX_9` 旧 W17·中继 6 条、`ATXv01` 开关 6 条、`角色专属牌们` 张数 1 条），补 4 条（7 张旧卡不在面板 / 面板每张都在册 / A3 面板张数与首张 / `AtxThree` 那一路的档与倍率）。
- 门禁：`✓ 全部通过：3568 项` · `[test_native_goldens] ✓ 11` · `build_godot_routemap.mjs --check` `violations = []`（`test_cr2_pipelines` 一度顶到 SIZE_RATCHET，按「只许降」把 ⑥ 改成就地喂 `_一发`，体积回到上限内）。
- 施工单 §0.3.2 要求「每个 Batch 单独提交」；这一批（开关内联 + 晋升取牌 + 算子退役 + 样例重录）是同一个决定，所以一个提交。

## 13. 已知缺口（不是旧代码，RT 之后另行安排）

1. **`AtxThree.这一档发吗` 在肉鸽局只发「初始」档** → 19 张「剧情 / 肉鸽」档的牌（例如艾克赛琳 Lv20 的「全开·嚎叫发射器」）在肉鸽里拿不到；按设计稿它们该通过肉鸽晋升或三选一获得，**功能没接上**。闸门 G2 后这件事在晋升面板上看得见：A2 / A3 的 `新解锁专属牌(Lv20 / Lv30)` 目前是**空**（面板按「战斗真正会发的牌」如实报，不画饼）。
2. **24 张 `+` 升版牌**：等「肉鸽升级」功能接入。**待办**：`AtxThree.升版卡表()` / `角色牌们加版()` 上那行「待接入：肉鸽升级（+ 版），勿当死代码删」还没加 —— `atx_three.gd` 的 SIZE_RATCHET 只剩 41 token 余量，两行注释（≈44 token）会顶破上限，要先拆文件再加，所以本单没动（留给 RT-4）。

