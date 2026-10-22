# 施工单 CR-1 执行回执（ARGON → Claude Opus 5.5）

> **接单人**：ARGON（`gemini-4-argon`，Gameplay + Godot Software Architect）
> **日期**：2026-10-18
> **对应施工单**：[`施工单-CR1-P1修复与Token瘦身示范-ARGON.md`](施工单-CR1-P1修复与Token瘦身示范-ARGON.md)
> **对应 Review 报告**：[`Godot-CodeReview报告-ClaudeOpus5.5.md`](Godot-CodeReview报告-ClaudeOpus5.5.md)
> **最终门禁状态**：
> - Godot 全量测试 `run_tests.gd`：**`✓ 全部通过：3891 项` · `EXIT=0` · 0 失败 · 0 SCRIPT ERROR · 168/168 场战斗黄金逐条一致 · 59 条 run 黄金全绿 · 天人 14 组 `var_to_str` 卡表快照逐字一致**
> - RouteMap 与 AST 静态审计 `node godot/tools/build_godot_routemap.mjs --check`：**`EXIT=0`（三份生成物逐字节一致，`violations: []`）**

---

## 1. 四个 Batch 的独立提交号

> *注*：开工前先将工作区此前已完成但未提交的「天人 v0.1 + 规范 v0.3 断路器 + 三栏零滚动 UI + RouteMap 初版（`3879 项`）」固化为干净基线提交 `2cd879e`，确保 CR-1 的四个 Batch 提交 diff 100% 纯净、互不掺杂。

| Batch | Commit Hash | 提交说明 | 变更范围摘要 |
|---|---|---|---|
| **基线** | `2cd879e` | `[M4-CB] 落地天人v0.1、规范v0.3断路器、顺劈、手牌左库零滚动UI与Godot RouteMap基线 (3879项)` | CR-1 前的 `3879 项` 完整工作区基线 |
| **Batch A** | **`fa45420`** | `[CR-1][Batch-A] 修 P1-1 装甲共享池吃无视装甲、P1-2 哈雷路亚禁打公有排、P2-1 grant走断路器3` | 拷入 `test_cr1_review_fixes.gd`（163 行），修改 `calc.gd` / `celestial_v01.gd` / `game_session.gd` / `flow.gd`（手写源码仅 `+26 / -4` 行）+ 重建 RouteMap |
| **Batch B** | **`0f40ffb`** | `[CR-1][Batch-B] 天人卡表抽成数据 data/cards/天人.json 并建立 var_to_str 卡表等价快照` | 新增 `test_card_table_snapshot.gd` 与 `tests/golden/card_tables/天人.txt`（145,865 B），抽离 `godot/data/cards/天人.json`（49,756 B），`data_loader.gd` 强校验装载，`celestial_v01.gd` 改读 `Db.T.卡包["天人"]` |
| **Batch C** | **`69e3ca2`** | `[CR-1][Batch-C] 制定 godot/README.md 注释规范并清理 calc.gd 与 celestial_v01.gd 历史冗余注释` | `godot/README.md` 新增「注释约定」，清理 `calc.gd` 与 `celestial_v01.gd` 历史/冗余注释（剥离注释后纯代码 diff = `0`） |
| **Batch D** | **`2dc0a38`** | `[CR-1][Batch-D] RouteMap拆分索引与明细、新增Token统计与规则5棘轮审计及route_query查询工具` | 升级 `build_godot_routemap.mjs`（§0.5 Token Top 20 + 规则 ⑤ 棘轮 `213` + 拆出 `Godot-RouteMap-明细.md`），新增 `route_query.mjs`，清理 `godot/.godot/` 临时日志并新增 `.ignore` |

---

## 2. Batch A：先红后绿输出与三处修改位置

### 2.1 修前红灯输出（A0：原样拷入 `test_cr1_review_fixes.gd`，0 处夹具改动）
将 `协作/架构/CR-1附件/test_cr1_review_fixes.gd` 原样拷入 `godot/tests/unit/test_cr1_review_fixes.gd` 后直接运行 `run_tests.gd`，恰好 **6 条断言失败（3 组问题）**，其余 3883 项全绿：

```text
✗ P1-1 ★ 无视 50% 装甲：池应为 500 → 10 + 500×5 = 2510（实际 %d；2020 = 池没扣无视装甲）
✗ P1-2 ★ 哈雷路亚打太阳炉牌【GN 粒子散布】→ 必须失败且原因提到哈雷路亚（实际：{ "成功": true, "卡牌": "GN 粒子散布", "太阳炉": true, "级": 1, "去处": "回库", "效果摘要": ["作用于【靶1】：它所在整排（1 台）命中 −10"], "主武器已销毁": false }）
✗ P1-2 ★ 哈雷路亚打天人势力牌 → 必须失败且原因提到哈雷路亚（实际：{ "成功": true, "卡牌": "「天人，出击」", "战意": 100.0, "费用": 0.0, "效果摘要": ["抽 0 张公有牌"], "主武器已销毁": false }）
✗ P1-2 对照：阿雷路亚打同一张太阳炉牌 → 成功（实际：{ "成功": false, "原因": "手里没有这张牌" }）
✗ P2-1 ★ 本回合已经再动过的队友，被「再动」支援卡指定 → 断路器 3 拦下，主武器保持已销毁
✗ P2-1 ★ 额度完好的队友 → 主武器恢复，并且 `本回合再动已用` / `连续攻击已用` 一起置真（同一把锁）
✗ 失败 6 项 / 通过 3883 项
```

### 2.2 修后全绿输出（A4）
```text
✓ Battle Core 对拍：168 / 168 场与 JS 参考版逐条一致
✓ 全部通过：3889 项
```
（退出码 `0`，`✗` 计数为 `0`，59 条 run 黄金与 168 场战斗黄金 100% 通过）

### 2.3 三处修改的文件与行号（以 Batch C 瘦身后的当前行号 / Batch A 当时行号对照）
1. **P1-1（`godot/core/battle/calc.gd`）**：
   - 新增静态函数 `Calc.抵消甲(def: Dictionary, w: Dictionary) -> float`（Batch A `calc.gd:39-47` / 当前 `calc.gd:35-43`）；
   - `Calc.dmgCore` 中原 `A` 计算段改为 `var A := 抵消甲(def, w)`（Batch A `calc.gd:308` / 当前 `calc.gd:268`）；
   - `Calc.resolveAttack` 中初始化 `装甲池` 改为 `装甲池 = 抵消甲(def, w)`（Batch A `calc.gd:760` / 当前 `calc.gd:652`）。
2. **P1-2（`godot/core/battle/celestial_v01.gd` + `godot/session/game_session.gd`）**：
   - `CelestialV01.打出太阳炉牌` 在 `是天人(u)` 检查后新增 `var 门因 := 卡不可打原因(ctx, u, card, true)` 拦截（Batch A `celestial_v01.gd:561-563` / 当前 `celestial_v01.gd:516-518`）；
   - `CelestialV01.打出势力牌` 在 `是天人(u)` 检查后新增同一 `卡不可打原因(ctx, u, card, true)` 拦截（Batch A `celestial_v01.gd:596-598` / 当前 `celestial_v01.gd:551-553`）；
   - `GameSession._这台能打公有牌` 在「③ 普通公有牌」前新增 `# TODO(CR-2): 并入 Btl.公有牌不可打原因` 与 `if CelestialV01.卡不可打原因(battle_ctx, u, c, true) != "": return false`（`game_session.gd:2819-2821`）。
3. **P2-1（`godot/core/battle/flow.gd`）**：
   - `Flow.resolveAction` 的 `"grant":` 分支开头新增单机牌组分支：`if Params.单机牌组_开(ctx) and t.get("主武器已销毁") != null: Calc.spendWeapon(actor, action.entry); DeckFlow.再动(ctx, t, str(w.name)); return 空`（`flow.gd:190-194`），旧口径代码原样保留。

---

## 3. Batch B / C 前后对比表（统一按 D1 脚本口径：`token ≈ CJK × 1.0 + 其余 ÷ 3.5`）

### 3.1 `godot/core/battle/celestial_v01.gd`（Batch B 抽卡表 + Batch C 注释规范）

| 指标 | 改前（CR-1 前基线 / Batch A 后） | Batch B 后（仅抽卡表 JSON） | **Batch C 后（抽卡表 + 注释规范）** | 施工单目标 | 达标 |
|---|---|---|---|---|---|
| **文件字节（LF）** | 148,828 B（148,998 B） | 113,961 B（`−23.5%`） | **97,570 B（`−34.4%`）** | `≤ 100,000 B` | ✅ |
| **代码行数** | 2,595 行（2,601 行） | 2,218 行 | **2,069 行（`−526 行`）** | — | ✅ |
| **估算 Token（D1 口径）** | 45,602（45,627） | 34,795 | **29,710（`−34.8%`）** | `≤ 30,000` | ✅ |
| **注释字节 / 注释占比** | 25,449 B / `17.1%` | 26,074 B / `22.9%` | **9,688 B / `9.9%`** | `≤ 15%` | ✅ |
| **卡表快照（14 组 `var_to_str`）** | 基线生成（145,865 B） | 逐字一致 | **逐字一致** | 逐字一致 | ✅ |
| **Batch B→C 剥离注释纯代码 diff** | — | 1,815 行非空代码 | **1,815 行（`charDiff = 0`）** | 0 行代码改动 | ✅ |

- 抽离的数据文件：`godot/data/cards/天人.json`（`49,756 B`），由 `session/data_loader.gd` 强校验装入 `Db.T.卡包["天人"]`（缺文件或字段缺失时 `DataLoader.install` 返回 `false` 并记录 `errors`，无静默回退）。

### 3.2 `godot/core/battle/calc.gd`（Batch C 注释规范示范）

| 指标 | 改前（CR-1 前基线 / Batch A 后） | **Batch C 后（注释规范清理）** | 施工单目标 | 达标 |
|---|---|---|---|---|
| **文件字节（LF）** | 77,877 B（78,231 B） | **62,345 B（`−19.9%`）** | `≤ 66,000 B` | ✅ |
| **代码行数** | 1,411 行（1,414 行） | **1,286 行（`−128 行`）** | — | ✅ |
| **估算 Token（D1 口径）** | 23,700（23,806） | **18,824（`−20.6%`）** | — | ✅ |
| **注释字节 / 注释占比** | 24,142 B / `31.0%` | **8,521 B / `13.7%`** | `≤ 15%` | ✅ |
| **首行 `## 职责` 列** | `20-战斗计算.js：命中 / 暴击 / 伤害管线…` | **一字未改（完全相同）** | 不变 | ✅ |
| **剥离注释纯代码 diff** | 1,113 行非空代码 | **1,113 行（`charDiff = 0`）** | 0 行代码改动 | ✅ |

---

## 4. Batch D：规则 ⑤ 当前值与索引页 Token 数

1. **规则 ⑤（通用内核文件 → 势力文件引用次数棘轮）**：
   - **当前值**：**`213` 次**（涉及 12 个通用内核文件 → 16 个势力文件，共 66 条文件级依赖边）
   - **棘轮基线（`CORE_TO_FACTION_RATCHET_MAX`）**：**`213` 次**（`213 <= 213`，`violations: []` ✅）
   - **逐文件明细**（与 Review 报告 §3 完全吻合）：
     - `core/battle/btl.gd`：引用 15 个势力文件，共 **76** 次
     - `core/battle/deck_flow.gd`：引用 11 个势力文件，共 **53** 次
     - `core/battle/calc.gd`：引用 8 个势力文件，共 **31** 次
     - `core/battle/setup.gd`：引用 10 个势力文件，共 **14** 次
     - `core/run/deck_builder.gd`：引用 4 个势力文件，共 **13** 次
     - `core/battle/flow.gd`：引用 4 个势力文件，共 **9** 次
     - `core/battle/card_effects.gd`：引用 6 个势力文件，共 **8** 次
     - `ai.gd` (3) / `roster_manager.gd` (2) / `boss.gd` (1) / `data_fn.gd` (1) / `params.gd` (1) / `reach.gd` (1)：共 **9** 次
2. **RouteMap 索引页与明细页拆分后体积**：
   - 主索引 [`协作/架构/Godot-RouteMap.md`](Godot-RouteMap.md)（含 §0、§0.5 Token Top 20、§1 速查表、§4 合规审计）：**`22,409 B` / `215 行` / 估算 Token = `6,780`（目标 `≤ 8,000`，且已写入 `--check` 硬门禁）** ✅
   - 明细页 [`协作/架构/Godot-RouteMap-明细.md`](Godot-RouteMap-明细.md)（含 §2 全文件职责与函数表、§3 依赖矩阵与热点、§4.1 逐条白名单）：`85,346 B` / `542 行` / 估算 Token = `24,697`
   - 按需切片查询工具：`node godot/tools/route_query.mjs <符号|文件路径>` 已就绪并实测通过。

---

## 5. 执行中观察到的细节与偏差说明

1. **Batch A 复现测试 `test_cr1_review_fixes.gd` 零改动跑通，发现一处提示文本 `%` 转义小细节**：
   - 附件 `test_cr1_review_fixes.gd` 无需改任何一行夹具即可跑通，先红（6 项）后绿（全过）。
   - 小观察：该文件第 39 行格式化字符串 `"P1-1 ★ 无视 50% 装甲：…（实际 %d…）" % _伤(r1)` 中，`50%` 未写成 `50%%`，在 GDScript 中导致 `%d` 未被展开而是把数字填进了 `50%` 的位置。因遵守「断言那一行不许动」的红线，保持了原样未改。
2. **Batch B 卡表段实际体积 vs 预估，以及静态缓存失效机制**：
   - `celestial_v01.gd` 中原卡表构建段实测为 **506 行 / 41,184 B**（而非预估的 741 行 / 52 KB），加之保留了 `_炉底 / _势力底 / _驾驶员 / _拉塞 / _武 / _炉算子` 等构建骨架，仅做 Batch B 后文件为 `113,961 B`。紧接着按 §3 C2 对 `celestial_v01.gd` 执行注释规范清理后，最终降至 **`97,570 B` / `29,710 token`**，圆满达到 B2 的 `≤ 100,000 B` 与 `≤ 30,000 token` 目标。
   - **JSON 类型还原清单**：JSON 解析后数值全为 `float`，在 `_额外 / _武参` 中对 `距离` 数组元素、`剑数`、`等级需求`、`级（太阳炉等级）` 统一做 `int()` 转换；`2800.0 * 1.15` 在 IEEE-754 下为 `3219.9999999999995`，JSON 中按原值写入以保证 `var_to_str` 快照逐字节一致。
   - **静态缓存代次同步**：在 `Db` 上新增安装代次计数器 `Db.代`（每次 `Db.install` 自增），`CelestialV01` 的 `_炉表 / _势力表` 静态缓存校验代次，确保测试中多次 `DataLoader.install` 时缓存自动刷新。
3. **Batch D 索引页 Token 预算控制**：
   - 为将 `Godot-RouteMap.md` 严格控制在 `≤ 8,000 token`（实测 `6,780 token`），索引页 §4.1 展示「`presentation → core` 只读白名单按目标模块聚合表（14 行）」，69 条逐符号调用明细放入 `Godot-RouteMap-明细.md` §4.1。
