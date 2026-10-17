# 任务单：M4 试玩反馈 6 项修复与体验升级（ARGON）

> **立项人**：ARGON（Gameplay Architecture + Godot Software Architecture）· **日期**：2026-10-16
> **来源**：作者本地网页（`http://127.0.0.1:8099/godot/`）实机试玩 6 项直接反馈 + `live_state.json` / `live_actions.jsonl`（#1–#127 步）全量轨迹取证。
> **并行性结论**：🔴 **与「秘银连携作战（`MITH-1~3`）」在 `btl.gd`、`game_session.gd`、`battle_view.gd`、`test_presentation_layout.gd` 存在直接文件冲突，不可并行施工。必须等秘银连携 Agent 收口交卷后，再按本任务单顺序派发 Subagent 落地。**

---

## §1 现场取证与根因定位对照表

| # | 作者反馈 / 监控日志发现 | 实测代码根因（`文件:行号`） |
|---|---|---|
| **1** | **现在零件点击了无法使用** | ① `presentation/widgets/top_bar.gd:211` 把主动零件画成按钮，点击后发 `零件瞄准` 进入大地图选格模式（`map_view.gd:449`），但**界面没有任何醒目提示告诉玩家「请点击大地图高亮目标格使用」**；<br>② 当主动零件在当前位置 `PartSystem.part_targets(state, 键)` 为空（无合法目标格）时，按钮仍可点，点完进空瞄准态、点哪格都被拒；<br>③ 被动常驻零件直接显示「（用不了）」，误导玩家以为坏了。 |
| **2** | **走地图的时候也需要可以打开查看编队**（日志中作者在 `screen=map` 连点 11 次灰掉的「编队/招募/牌库」按钮） | `presentation/battle/result_view.gd:273` 点击战后结算「继续（回大地图）」只发了切屏信号 `screen = "map"`，**没有清空 `session.battle_ctx`**！导致回到大地图后 `session.in_battle()` 仍为 `true`，`top_bar.gd:89` 误判仍在战斗中，把顶栏「编队 / 招募 / 牌库」永久锁死为灰色。 |
| **3** | **编队要用拖动的方式放进去，现在这个编队调整方式很不对，另外也有放不进去的情况**（日志中 `set_lineup_slot` 连报 17 次 `出击位满了（上限 6）` 卡死 12 分钟） | ① **严重门面 Bug（放不进去的真因）**：`session/game_session.gd:1070-1080` 在把已上阵机体换到新空格时，只写了 `位表[新位] = 机体`，**漏了先 `erase` 旧格位**！导致 `S1` 占 3 格、`S3` 占 2 格，`lineup.size()` 涨到 8（> 上限 6），画面上还有空格却永远报「出击位满了」；<br>② **交互方式不对**：`presentation/run_map/formation_view.gd` 目前只有「先点名册选中→再点格位」的分步点击，未实现 Godot 原生拖拽（`_get_drag_data` / `_can_drop_data` / `_drop_data`）。 |
| **4** | **发牌需要做一些示意，牌来自哪些机体** | `core/battle/btl.gd` 与 `session/game_session.gd:hand_cards()` 目前只传 `归属`（职业或势力名），**未标注具体来自场上哪台我方机体**；手牌卡面与新发牌时也缺少来源机体标识与联动高亮。 |
| **5** | **鼠标 hover 藏品需要显示藏品细节**（日志中作者点击藏品栏 4 次无反应） | `presentation/widgets/top_bar.gd` 的 `_建藏品栏` 与 `_建零件栏` 只设置了原生 `tooltip_text`，**未接入统一的 `HoverTooltip.bind(...)` 悬停说明层**。 |
| **6** | **需要给一点基本的示意性质的战斗动画，让我理解一下谁打了谁，造成了多少伤害，造成了什么效果** | `presentation/battle/battle_view.gd` 目前每推进一拍只做静态重绘 + 底部日志追加文字，阵型区没有「出手方前冲/高亮 → 指向受击方的连线/弹道 → 受击方闪烁抖动 + 头顶伤害/未命中/暴击/效果飘字 + 中央动作播报条」。 |
| **附** | **监控日志额外暴露的 3 个伴生缺陷** | ① 大地图点击玩家脚下当前格报 `已经在那一格` 并污染 `session.errors`；<br>② 休整屏 `resolve_rest` 可被连点 6 次；<br>③ `session.errors` 只增不减，累积在状态快照里。 |

---

## §2 派工拆分（等 `MITH-1~3` 完成后按序执行）

### 子任务 `UX-1`：大地图/顶栏/编队状态机修复 + 拖拽编队 + 零件与藏品 Hover（对应反馈 1、2、3、5 + 伴生缺陷）

- **归属模块**：
  - `godot/session/game_session.gd`
  - `godot/presentation/widgets/top_bar.gd`
  - `godot/presentation/battle/result_view.gd`
  - `godot/presentation/run_map/map_view.gd`
  - `godot/presentation/run_map/formation_view.gd`
  - `godot/presentation/menus/rest_view.gd`
- **具体规格**：
  1. **战后回大地图清理战斗上下文（修复反馈 2）**：
     - 在 `GameSession` 新增/收口战后回地图清理逻辑（当 `battle_ctx` 已结算且切回 `"map"` 时清空 `battle_ctx` 与 `_本场已结算`），确保大地图非 `pending_battle_confirm` 时 `session.in_battle() == false`，顶栏「编队」「招募/晋升」「战术牌库」随时可自由打开查看与调整；从大地图打开编队后点「返回大地图」直接回到大地图。
  2. **修复 `set_lineup_slot` 重复占格 Bug（修复反馈 3 根因）**：
     - 在 `game_session.gd` 的 `set_lineup_slot(slot, unit_key)` 中：若 `unit_key` 已在 `lineup` 的其他格位上，属于**格位移动/互换**，不触发「出击位满了」拦截，且必须先移除该 `unit_key` 原先所在格位记录（若目标格原本有另一台机体 `other_key` 且 `unit_key` 来自原格 `old_slot`，则将 `other_key` 换到 `old_slot` 实现平滑互换！）；
     - 新增 `_清理重复占格()` 守卫，保证任何时刻 `lineup` 中同一 `unit_key` 最多出现 1 次、同一 `slot` 最多出现 1 次。
  3. **编队屏支持直接拖拽（Drag & Drop）+ 保留点击兜底（修复反馈 3）**：
     - 在 `formation_view.gd` 中封装可拖拽/可放置卡片控件（实现 `_get_drag_data` / `_can_drop_data` / `_drop_data`）：
       - **从名册拖到 8 格阵型槽**：直接上阵到该槽（槽上已有人的话直接替换，若未超上限则原机下阵或替换）；
       - **从阵型槽 A 拖到阵型槽 B**：若槽 B 为空则移位，若槽 B 有人则两台机体**直接互换格位**；
       - **从阵型槽拖回名册区（或右键点击阵型槽 / 点槽上「卸下」小按钮）**：直接下阵；
       - 拖拽时 `set_drag_preview` 显示半透明机体名片，悬停在可放置目标槽上时目标槽边框高亮金色；
       - 同时保留「点击名册机体 → 点击阵型格」作为无拖拽环境（及自动化测试）兜底。
  4. **零件点击可用 + 瞄准态横幅引导（修复反馈 1）**：
     - `GameSession` 新增 `part_hover_text(idx: int) -> String` 与 `part_can_use_now(idx: int) -> Dictionary`（返回 `{ok, passive, targets, why}`）；
     - `top_bar.gd` 渲染零件时：
       - 被动零件（如加推进剂上限）文本标 `·被动生效`，样式设为常驻徽章而非坏掉的灰按钮；
       - 主动零件若当前在大地图且 `targets.size() > 0`，按钮亮起可点；若不在大地图或当前位置 `targets` 为空，按钮置灰并在 Hover 中写清原因（如 `当前位置周围没有可作用的地图格`）；
     - `map_view.gd` 进入零件瞄准态时，在地图上方显示醒目的金色引导条：`【正在使用零件：XXX — 请点击下方高亮闪烁的地图格生效（再点零件或点「取消瞄准」退出）】`，点击合法目标格立即执行 `use_part` 并弹出即时提示。
  5. **藏品与零件接入 `HoverTooltip`（修复反馈 5）**：
     - `GameSession` 新增 `relic_hover_text(relic_id: String) -> String`（含藏品名称、稀有度/来源、完整数值加成说明）；
     - `top_bar.gd` 中每一个藏品标签与零件控件全部调用 `HoverTooltip.bind(ctrl, ...)`，鼠标移上去立即在右侧弹出标准悬停详情框（同时设置 `mouse_filter = Control.MOUSE_FILTER_STOP` 或 `PASS` 确保事件不被父滚动区吞掉）。
  6. **伴生缺陷清理**：
     - 大地图点击当前所在格（`cell_id == state.cur`）时若该格已结算，直接静默返回提示而不计入 `session.errors`；
     - 休整屏 `rest_view.gd` 执行完休整动作后自动切回大地图或置灰按钮，防连点报错。

---

### 子任务 `UX-2`：发牌来源机体标注与发牌示意（对应反馈 4）

- **归属模块**：
  - `godot/core/battle/btl.gd`
  - `godot/session/game_session.gd`
  - `godot/presentation/battle/battle_view.gd`
- **具体规格**：
  1. **牌面来源机体解析（纯读 + 发牌记录）**：
     - 在 `GameSession.hand_cards()` 与 `bench_cards()`（及 `card_hover_text()`）中，为每张牌计算并附上 `来源机体文本`（`source_unit_text`）与 `来源机体位列表`（`source_slots: Array`）：
       - **角色牌 / 专属牌**：直接指向该角色机体（如 `来自：卡莲（前1）`）；
       - **职业牌（如近卫/狙击/格斗等）**：指向我方场上属于该职业的存活/出战机体（如 `来自：刹那·近卫`）；
       - **势力牌（如秘银/ATX/天人等）**：指向我方场上属于该势力的机体（如 `来自：宗介/毛·秘银`）；
       - **统帅通用牌**：标注 `来自：指挥官（统帅）`。
     - 在 `btl.gd` 的 `发牌` 日志条目中附带 `来源文本`，让战斗日志也能看到「`〔发牌〕因【条件】从〔刹那〕获得战术牌【…】`」。
  2. **手牌卡面显示 + 悬停联动高亮场上机体**：
     - `battle_view.gd` 每张手牌卡与候补牌在卡面醒目位置显示 **`【来自：XXX】`** 标签；
     - 当鼠标 Hover 在某张手牌/候补牌上时，场上对应的 `source_slots` 机体卡（`UnitCard`）同步亮起青/金色联动外框，让玩家瞬间看懂「这张牌是谁带来的」。
  3. **新发牌入栏视觉示意**：
     - 当本拍有新牌发入手牌（`触发回合 == 当前回合` 或本拍刚入栏）时，手牌卡挂 `★新发牌` 角标与脉冲亮框，并在战场中央/手牌栏上方浮现 `🃏 新发牌：【牌名】（来自：机体名）` 提示。

---

### 子任务 `UX-3`：示意性战斗动画层 —— 谁打了谁、多少伤害、什么效果（对应反馈 6）

- **归属模块**：
  - `godot/presentation/battle/battle_view.gd`
  - `godot/presentation/widgets/unit_card.gd`
- **具体规格**（严格遵守 `M4-表现层接口契约.md`：纯表现层消费 `session.battle_log_entries()` 新增条目，**零改动战斗内核 RNG 与数值**；headless 模式下跳过 Tween 等待，保持测试毫秒级跑完）：
  1. **中央动作播报横幅（Action Banner）**：
     - 在双方阵型区之间（或阵型区顶部）常驻一条高对比度战术播报条，每推进一拍展示本拍核心事件摘要：
       - 例：`⚔️ [我方·前1] 强袭 ➔ 使用【光束步枪】攻击 [敌方·前2] 铁人式 · 命中 2/2 段 · 造成 420 伤害！`
       - 例：`🃏 [战术牌] 打出【集中火力】 ➔ 全队伤害提升`
  2. **谁打了谁（出手高亮前冲 + 指向弹道连线）**：
     - `battle_view.gd` 维护 `_已播日志数`，每次 `refresh()` 提取本拍新增的战斗日志事件（`攻击` / `大招` / `修理` / `镜甲` / `战术牌`）：
     - **出手方 `UnitCard`**：高亮亮金外框 + 朝敌方方向短促前冲 12px 后回弹；
     - **战场弹道指示层（Overlay Control `_绘制弹道`）**：从**出手方 `UnitCard` 中心点**到**受击方 `UnitCard` 中心点**画一条带箭头和发光描边的指向线（普通攻击为亮橙色、大招/暴击为粗金红色、未命中为灰白虚线、修理支援为翠绿色），持续约 0.5 秒淡出。
  3. **造成了多少伤害 / 什么效果（受击闪烁 + 头顶浮动飘字）**：
     - **受击方 `UnitCard`**：受到伤害时卡片底色短暂红闪 + 左右微抖；
     - **头顶浮动战斗飘字（Floating Text）**：在目标 `UnitCard` 上方生成带描边的大字号浮动标签（向上飘动并淡出）：
       - 伤害：`-420`（红色大字；若暴击则为 `💥暴击 -680!` 金红大字；多段显示 `[2/3中] -420`）
       - 未命中：`MISS 未命中`（灰蓝色）
       - 治疗/修理：`+310 HP`（亮绿色）
       - 效果/状态/势力触发：在攻击者或受击者卡上弹出胶囊标签，如 `〔破防 -20%〕`、`〔被挡 -20〕`、`〔SEED 觉醒〕`、`〔连携触发〕`、`💥 击破！`。

---

## §3 验收门禁（全部子任务完成后必须通过）

1. **自动化门禁**：
   - `run_tests.gd` 在既有全绿基础上，新增 `test_presentation_layout.gd` / `test_session_flow.gd` 断言覆盖：
     - ① 战后结算点「继续」回大地图后，`session.in_battle() == false`，顶栏「编队 / 招募 / 牌库」按钮 `disabled == false`；
     - ② `set_lineup_slot` 把已在 `前1` 的机体移到 `前2` 或与 `前2` 互换时，`lineup` 中该机体绝不重复出现，连续调换 20 次不触发假「出击位满了」；
     - ③ 编队卡片 `_get_drag_data` / `_can_drop_data` / `_drop_data` 编程调用可完成「名册拖上阵 / 格位互换 / 拖回名册下阵」；
     - ④ 顶栏藏品与零件均绑有 `HoverTooltip`，`relic_hover_text` 与 `part_hover_text` 非空；
     - ⑤ 手牌 `hand_cards()` 含非空 `source_unit_text`（来源机体说明）；
     - ⑥ 战斗推进一拍后，动作播报横幅与战斗动画指示层节点正常更新且零报错；
     - ⑦ `test_font_coverage.gd` 字体覆盖 100% 通过（只用 GB2312 常用字，不引入未覆盖生僻符号）。
2. **JS 封存红线**：`SEAL_EXIT=0`。
3. **本机 Web 重打包**：重导出 `F:\DSH-mecha\.tools\smoke\_site\godot\index.pck`，供作者在 `http://127.0.0.1:8099/godot/` 直接刷新验证。
