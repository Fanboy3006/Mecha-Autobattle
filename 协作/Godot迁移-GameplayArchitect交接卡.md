# Godot 迁移阶段 · Gameplay & Software Architect 交接卡（M3 收口 → M4 交接版）

> **交接对象**：下一任架构师（DSH 主会话 ARGON）
> **角色职责**：你同时负责 **Gameplay Architecture + Godot Software Architecture + 迁移边界与验收**；子代理 **DS4F**（`subagent`）负责低成本调查与实际代码施工（项目架构主导权已从外部 CC 彻底收回 DSH）。
> **最高战略纲领**：[**`协作/项目方向调整-Godot唯一引擎.md`**](项目方向调整-Godot唯一引擎.md) —— **最终只维护一套正式游戏引擎：Godot**（Web 导出 + GitHub Pages 静态托管发布，点开即玩）。
> **JS 参考版状态**：已永久封存于 Git 标签 **`js-reference-final`（提交 `a745235`）**，`rulesSignature = "r1:05a9cbf9"`，`defaultPathBattleLogCount = 2788`，开牌基线 `31` 条，`verify-all` 23/23 全绿。**严禁再修改 `src/**`、`tests/**`、`index.html` 等 JS 文件**（`godot/tools/js_ref.mjs` 的 `checkSealed()` 会检查非 `godot/.github/协作` 路径与 `js-reference-final` 零差异）。
> **本机 Godot 4.7.2 Headless 路径**：`F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`（已安装在仓库外，SHA512 官方校验通过）。
> **一键回归门禁命令**：
> ```powershell
> & 'F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'F:\DSH-mecha\mecha-autobattle\godot' --script res://tests/run_tests.gd
> ```
> 当前基线：**退出码 0 · 326 项断言全绿 · 168/168 战斗黄金样例通过 · 局外黄金样例 100% 对齐**。

---

## 一、当前进度与 Git 提交链快照（至 M3 全部收口）

| 阶段 | Git 提交 / 标签 | 状态 | 核心成果 |
|---|---|---|---|
| **JS 封存基线** | `a745235` (`tag: js-reference-final`) | ✅ 已完成并推送 | 战术卡牌 P1 + P1.1 + P1.2 + P1.3 全部收口，23/23 门禁全绿 |
| **Godot M0** | `e7c78c6` (`[Godot M0]`) | ✅ 已完成 | `godot/` 工程骨架、`Mulberry32` 逐位对齐、`JsCompat`、中文字体子集、24 项测试、`.github/workflows/godot-ci.yml` & `pages.yml` |
| **Godot M1** | `4065a48` (`[Godot M1]`) | ✅ 已完成 | 数据导出（`godot/data/js/*.json`）、战斗黄金样例 **138 场**（含 2788 自检）、字体后备链、53 项测试 |
| **Godot M2** | `2d75d22` (`[Godot M2]`) | ✅ 已完成 | `godot/core/battle/` 落盘；138/138 场黄金样例与 `js-reference-final` 逐条一致；D-01 签字确认；65 项测试全绿 |
| **ARGON 接管审计 & D-02** | `6e5f94c` | ✅ 已完成 | 独立复跑 M2 基线；登记 **D-02（M3 五处冻结语义施工口径纠错）**；落盘 [`协作/Godot迁移-ARGON验收对照表.md`](Godot迁移-ARGON验收对照表.md) |
| **Stage R1 + M3-Prep** | `126ba46` | ✅ 已完成（141 项全绿） | ① **R1 架构整顿**：新增零 `J.*` 强类型领域目录 `GameCatalog`（`core/data/game_catalog.gd`）、32 张战术卡牌声明式效果执行器 `CardEffects`（`core/battle/card_effects.gd`，替掉 `btl.gd` 27 个硬编码分支）、清理 `flow.gd` 退役防御回复死代码、`test_boundary.gd` 锁死新模块严禁调用 `J.*`；② **M3-Prep**：新增 `RelicBattle`（`core/battle/relic_battle.gd`，58 件藏品开战注入，清掉 DEBT-06）、导出 **30 场带藏品战斗黄金样例**（战斗黄金样例扩至 **168/168 全绿**）、导出局外肉鸽黄金样例 `tests/golden/run_vectors.json` + `test_run_golden.gd`、落盘强类型 `core/run/run_state.gd` |
| **Godot M3（Run Core 肉鸽内核 + 存档）** | `52a953c` (`[Godot M3]`) | ✅ 已完成（**326 项全绿**） | 在 `godot/core/run/` 下用原生 Godot 架构（**零 `J.*` 调用**）完整落地：`map_generator.gd`、`map_navigator.gd`、`part_system.gd`、`roster_manager.gd`、`deck_builder.gd`、`relic_system.gd`、`node_resolver.gd` + `session/save_service.gd`；跑通 `run_vectors.json` 全量对拍、1~4 层真战斗通关冒烟、第 2 层中途 `save → load` 往返逐字节一致 |
| **Godot M4（表现层与 UI + Web 导出）** | **下一任架构师开机直接执行** | 🎯 **当前任务** | 建立 `session/game_session.gd` 统一会话门面 + 构建 `presentation/` 原生 Godot 场景（菜单/分队/大地图/编队/战斗屏/手牌栏/招募晋升3选1弹窗/结算屏）+ Web 导出与试玩验收（含 D-01 体感确认） |
| **Godot M5** | 最终收口 | ⏳ 待做 | 根路径 `/` 切换为 Godot 版，JS 旧版归档，开启 P2 玩法迭代 |

---

## 二、已锁死的架构红线与 M2/M3 核心资产速查

### 2.1 架构铁律（由 `godot/tests/unit/test_boundary.gd` 自动门禁守卫）
1. **严禁在新代码中调用 `J.*` (`core/util/js.gd`)**：`test_boundary.gd` 会扫描 `res://core/run`、`res://core/data/game_catalog.gd`、`res://session`、`res://presentation` 下所有 `.gd` 文件，一旦出现 `J.` 直接报错退出码 1。数值四舍五入请用 `JsCompat.js_round`，并列稳定排序用 `JsCompat.stable_sort`，确定性随机用 `Mulberry32`。
2. **`core/` 零引擎耦合**：`res://core/` 下的所有类一律 `extends RefCounted`，禁止继承 `Node`、禁止访问 `SceneTree` / `FileAccess` / `res://presentation`。
3. **字体覆盖门禁（`test_font_coverage.gd`）**：所有 `.gd` 与 `.tscn` 中的非 ASCII 字符必须被 `godot/assets/fonts/NotoSansSC-Subset.otf` 覆盖；若新增了生僻字导致 `test_font_coverage` 报警，要么换常用字，要么运行 `python godot/tools/build_font_subset.py` 重建字体子集。
4. **GDScript 4 类型转换注意**：在 GDScript 4 中，`String(x)` 构造函数**不接受** `int`/`float`/`Variant(null)`（会报 `SCRIPT ERROR: Invalid call. Nonexistent 'String' constructor.`）。将任意 `Variant` 转字符串一律用 `str(x)` 或 `RosterManager.串(x)`。

### 2.2 已落盘的 `core/` 与 `session/` 模块接口速查
- **领域数据目录**：`Db.catalog` (`godot/core/data/game_catalog.gd`) —— 提供 `characters()`, `enemies()`, `stages()`, `trait_groups()`, `cards()`, `relics()`, `parts()`, `roguelike_config()`。
- **战斗内核门面**：
  - `Setup.开局(allies, enemies, seed_val, options) -> Dictionary`（`options` 传 `RelicSystem.build_battle_options(run_state)` 即 `{"战术卡牌": true, "已选战术牌": ..., "藏品": ...}`；正式游戏使用 D-01 默认手牌装填，不传 `"手牌装填": "JS参考"`）。
  - `Btl.打战术牌(ctx, card_id) -> Dictionary`（内部调用声明式的 `CardEffects.execute(ctx, card)`）。
  - `Btl.切换单位开关(ctx, unit_id, key) -> bool`（切换天人 TRANS-AM 自动/手动，或手动激活 `Btl.激活单位状态(ctx, unit_id)`）。
  - `Setup.打一回合(ctx) -> Dictionary`（推进一个完整战斗回合：回合初 `Btl.候补补位` → 条件发牌 → 按速度行动 → 回合末结算）。
- **肉鸽内核门面（`godot/core/run/`）**：
  - `RunState` (`run_state.gd`)：单局状态容器，支持 `to_dict()` / `from_dict()`。
  - `RosterManager` (`roster_manager.gd`)：`new_run(seed_val, squad, squad_kind)`、`recruit(state, unit_key, ticket_idx)`、`promote(state, unit_key)`、`deploy_limit(state)`、`战后回血(state)`。
  - `DeckBuilder` (`deck_builder.gd`)：`offer_cards(state, unit_key, 3)`、`select_card(state, card_id)`。
  - `MapGenerator` (`map_generator.gd`)：`generate_floor(floor_num, seed_val)`、`propellant_limit(state)`、`propellant_detail(state)`。
  - `MapNavigator` (`map_navigator.gd`)：`enter_floor(state, floor_num)`、`can_move_to(state, target_id)`、`retreat_cost_preview(state, target_id)`、`move_to(state, target_id)`、`use_tunnel(state)`、`after_chase_win(state)`、`after_guard_win(state)`、`advance_floor(state)`。
  - `NodeResolver` (`node_resolver.gd`)：`抽编成兜底(floor_num, kind, rng)`、`开战(state, stage_entry, cell_type)`、`resolve_battle(state, ctx, cell_type)`、`结算休整(state, choice)`、`黑市货(state)`、`黑市买(state, relic_id)`、`黑市刷新(state)`、`结算瞭望站(state, choice)`、`结算遗迹(state, choice)`、`结算侵蚀源代价(state, choice)`、`结算奇遇(state, choice_idx)`。
  - `RelicSystem` (`relic_system.gd`) & `PartSystem` (`part_system.gd`)：藏品与零件全部操作。
- **存档服务（`godot/session/save_service.gd`）**：
  - `SaveService.save_to_file(state, path)` / `SaveService.load_from_file(path)` / `SaveService.serialize(state)` / `SaveService.deserialize(json_str)`。

---

## 三、下一任架构师的直接任务：Stage M4（Presentation & Scenes 表现层与 Web 导出试玩）

### 3.1 M4 架构设计原则
1. **单向数据流（Command → `GameSession` → Signal → UI 刷新）**：
   - 表现层（`godot/presentation/`）**不直接拼凑复杂的内核调用链**，而是通过会话门面 `godot/session/game_session.gd` (`class_name GameSession extends RefCounted` 或 Autoload Node) 驱动。
   - `GameSession` 持有当前 `run_state: RunState`、当前战斗 `battle_ctx: Dictionary`、当前屏幕状态 `screen: String`（`"menu" | "squad" | "map" | "formation" | "battle" | "result"`）及活动弹窗 `modal: Dictionary`。
   - **这样做有两大决定性好处**：
     1. `GameSession` 的全部 UI 动作流（从菜单选分队 → 走图 → 招募/3选1 → 编队 → 开战打牌 → 结算 → 换层 → 存档读档）可以在 **`--headless` 单元测试（`test_session_flow.gd`）中 100% 自动化测通**！
     2. `presentation/` 下的 `.tscn` / `.gd` 场景组件只需要把 `GameSession` 的状态渲染成 Godot `Control` 节点，并把按钮点击转发给 `GameSession` 即可，极薄且极稳。
2. **三层反馈纪律（`CLAUDE.md` 第 7 节第 10 条）**：
   - **预告**：大地图悬停/选中格子时显示推进剂消耗与 `MapNavigator.retreat_cost_preview` 退路成本预告；战斗手牌悬停/展示时显示气势消耗与效果说明。
   - **即时**：战斗内打出战术牌、触发条件发牌、候补补位、大招、BOSS 技能、势力特色（SEED/TRANS-AM/标定等）时，在战斗日志与单位卡状态行即时体现。
   - **结算**：战后结算面板清晰展示本场胜负、存活回血 `50%` 明细、获得的源碳/希望/招募券/藏品/零件，以及本场打出的战术牌回顾。

### 3.2 推荐的 M4 派单拆分（可分 2~3 个 DS4F 子代理并行施工）

#### 子任务 M4-1：会话门面 `godot/session/game_session.gd` + Headless 会话流测试 `test_session_flow.gd`
- 新建 `godot/session/game_session.gd` (`class_name GameSession extends RefCounted`)，封装完整的玩家命令 API（零 `J.*`）：
  - **开局与存档**：`start_new_run(seed_val: int, squad: String)`、`save_current_run() -> bool`、`load_saved_run() -> bool`、`has_saved_run() -> bool`。
  - **大地图与零件**：`move_to_cell(cell_id: int) -> Dictionary`、`preview_cell_move(cell_id: int) -> Dictionary`、`use_part(part_idx: int, target_cell: int) -> Dictionary`、`enter_current_node() -> Dictionary`、`try_advance_floor() -> Dictionary`。
  - **名册、招募、晋升、3选1、编队**：`recruit_unit(unit_key: String, ticket_idx: int) -> Dictionary`、`promote_unit(unit_key: String) -> Dictionary`、`pick_tactical_card(card_id: String) -> bool`、`set_lineup_slot(unit_key: String, slot_name: String) -> bool`、`remove_from_lineup(unit_key: String) -> bool`。
  - **非战斗节点交互**：`resolve_rest(choice: String)`、`buy_from_shop(relic_id: String)`、`refresh_shop()`、`sell_part_in_shop(part_idx: int)`、`leave_shop()`、`resolve_event_choice(choice: String)`。
  - **战斗交互（含快速测试战与肉鸽战）**：`start_quick_battle(seed_val: int)`、`start_node_battle()`、`play_tactical_card(card_id: String) -> Dictionary`、`toggle_unit_switch(unit_id: String, switch_key: String) -> bool`、`activate_unit_state(unit_id: String) -> bool`、`step_battle_turn() -> Dictionary`、`auto_finish_battle() -> Dictionary`、`finish_battle_and_settle() -> Dictionary`。
- 新建 `godot/tests/unit/test_session_flow.gd`：在 Headless 下通过 `GameSession` 跑通「快速战斗打牌结算」与「肉鸽开局 → 招募 → 3选1 → 编队 → 移动 → 战斗打牌 → 战后结算 → 休整/黑市 → 存档读档」。

#### 子任务 M4-2：大地图、菜单、分队、招募/晋升/3选1/黑市/休整/奇遇 UI（`godot/presentation/`）
- 重构/扩充 `godot/presentation/boot.tscn` & `boot.gd`（或拆分为清晰的子视图构建器 `godot/presentation/ui_run_views.gd`）：
  1. **顶栏常驻状态条**：显示当前层数、推进剂 `当前/上限`（含明细提示）、源碳、希望、基地耐久、部队等级/经验、出击上限、当前持有的藏品图标/名称栏、零件栏（点击主动零件可高亮大地图目标格）、以及「名册/招募/晋升」「编队」「战术牌库」「保存并返回主菜单」按钮。
  2. **主菜单与分队选择屏**：支持「继续游戏（读档）」「开始新肉鸽（选分队 + 可选种子）」「快速测试战斗（默认五人队立即可试玩 D-01 手牌体感）」。
  3. **正方形大地图视图**：渲染 `5×5 ~ 7×7` 网格节点（区分起点、作战、精英、休整、黑市、奇遇、瞭望站、遗迹、侵蚀源、废弃隧道、出口守军、出口尽头、出口小径；标明必经点、已走过、当前所在格），点击或悬停显示推进剂消耗与退路成本预告，点击移动并触发对应节点面板。
  4. **局外交互面板/弹窗**：
     - **招募与晋升面板**：展示手上的招募券、点击券列出可招募机师（标注★带队核心直上 Lv20）、名册机师五维与晋升预览（Lv10→20→30）。
     - **3 选 1 战术牌构筑弹窗**：当 `state.pending_card_picks` 非空时弹出 3 张候选战术牌（显示层级、归属、气势消耗、冷却、触发条件、效果说明），点击即选入 `tactical_deck`。
     - **9 格编队面板**：前排 4 格（前1..前4）+ 后排 5 格（后1..后5）错位排布，点击上阵/下阵/换位。
     - **休整 / 黑市 / 奇遇 / 瞭望站 / 遗迹 / 侵蚀源面板**：提供完整选项按钮与即时结果反馈。

#### 子任务 M4-3：战斗屏（9格双方阵型 + 底部战术手牌栏 + 战报与结算屏）& Web 导出冒烟
- 构建战斗视图（`godot/presentation/ui_battle_view.gd`）：
  1. **双方 9 格阵型面板**：显示我方（左）与敌方（右）在场单位卡片（名称、职业/势力、Lv、HP 进度条与数值、气势、护盾、当前增益/减益/标定/SEED/TRANS-AM 状态行、天人单位自动/手动开关按钮、敌方下一拍行动意图预告与 Boss 阶段预告）。
  2. **底部战术手牌栏（核心体验区）**：
     - 显示当前手牌（最多 10 张）、牌库剩余、**候补初始牌数量与列表预览（D-01 重点展示！）**、本回合剩余可打牌次数（`2 - 本回合已打出`）、我方平均气势/最高气势。
     - 每张手牌显示：卡名、层级标签（角色/势力/职业/统帅/基础）、气势消耗、冷却回合、效果说明；满足条件时高亮可点击打出，不满足时置灰并显示原因（气势不足/冷却中/本回合已满2张）。
  3. **回合控制与战斗日志栏**：提供「推进下一回合」「自动打完本场」按钮；右侧或底部滚动显示本回合/整场结构化战斗日志（含 `〔发牌·候补补位〕`、`〔战术牌〕`、`〔势力〕`、`〔Boss〕` 高亮）。
  4. **战后结算屏**：展示胜负、存活机体战后 `+50%` 回血前后对照、战利品（源碳/希望/招募券/藏品/零件）与「继续前进」按钮。
- **Web 导出与验证**：
  - 检查字体子集是否需要更新（若有新 UI 字符，跑 `python godot/tools/build_font_subset.py`）。
  - 执行 Web 导出并跑通 `run_tests.gd` 全套门禁。

---

## 四、给下一任架构师的开机指令（3 步走）

1. **开机核对（只读，耗时 < 30 秒）**：
   - 读本文件（`协作/Godot迁移-GameplayArchitect交接卡.md`）；
   - 运行一次 `git status --short` 和 `run_tests.gd`，确认处于 `52a953c`（或本交接卡提交）且 **326 项测试全绿**。
2. **直接启动 Stage M4**：
   - 先派 DS4F 完成 **M4-1（`godot/session/game_session.gd` + `test_session_flow.gd`）**；
   - 再派 DS4F 完成 **M4-2 & M4-3（`godot/presentation/` 完整 UI + 字体子集检查 + Web 导出验证）**。
3. **试玩与签字**：
   - M4 完成后，引导作者试玩 Web 导出版本（或本地窗口运行），重点确认 **D-01（角色牌开局在手、职业牌进候补逐回合补位）** 的实际打牌体感，随后进入 M5 收口。
