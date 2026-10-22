# 任务单：零件系统全面改造 —— 对齐《黑流树海》原版规格（ARGON）

> **立项人**：ARGON（Gameplay Architecture + Godot Software Architecture）· **日期**：2026-10-17
> **来源**：作者《给 ARGON：零件系统修改说明（对齐〈黑流树海〉原版）》+ 4 条边界问题作者亲口拍板。
> **当前门禁基线**：`✓ 全部通过：1785 项`（`MITH-1~3` + `UX-1~3` + `UX-4~6` 均已在工作区落地并验过）。
> **并行性状态**：🟢 `UX-4~6` 已完成收口，本任务单可独立全量施工，无并行冲突。

---

## §1 作者拍板的 4 条核心边界口径（施工必守，不许更改）

1. **老妈的融雪（`thaw`）与迷雾关系（拍板 = A）**：
   - `thaw` 的目标范围为**全图任意非战斗格（不要求已探明）**；点击瞄准时，直接高亮全图所有非战斗格（含迷雾格）。
   - *背景说明*：原版大地图对「战斗格」与「非战斗格」本来就有粗略颜色分类（紫 vs 蓝），因此高亮迷雾中的非战斗格符合原版信息透明度设计。
2. **「非战斗格」的精确定义（拍板 = 含起点与两个出口）**：
   - 凡是不直接触发战斗的节点类型，一律算可落点的「非战斗格」（影响 `bagua` 小八界 & `thaw` 老妈的融雪）。
   - **完整名单**：`空`、`黑市(shop)`、`休整(rest)`、`招募站(recruit)`、`事件(event)`、`瞭望站(watch)`、`遗迹(relic)`、`隧道(tunnel)`、**`起点(start)`**、**`出口小径(exit_trail)`**、**`出口尽头(exit)`**。
   - **战斗格名单（排除项）**：`普通战斗`、`精英战斗`、`首领(Boss)`、`侵蚀源`、`出口守军(guard)`（即 `MapGenerator.是战斗节点(type) == true` 的格子）。
   - *注*：跳关问题后续通过守关/Boss 机制解决，零件层不封禁出口格。
3. **`free: false` 零件的推进剂消耗与 `推进剂 == 0` 禁则（拍板 = 推进剂为 0 时不可使用）**：
   - 默认每次使用加工品移动消耗 **1 点推进剂**（仅 `free: true` 的 `spring` 重弹簧、`jet` 一次性喷气背包、`bagua` 小八界 **消耗 0 点推进剂**）。
   - **当剩余推进剂 `< 1`（即 `== 0`）时**：所有 `free: false` 的零件**严禁使用**（`part_can_use_now` 返回 `ok: false, why: "推进剂不足（需 1 点）"`，顶栏按钮置灰）；只有 `free: true` 的零件在 0 推进剂时仍可使用。
   - 当剩余推进剂 `== 1` 时使用 `free: false` 零件：移动后推进剂扣为 `0`，并照常触发落点事件 / 0 推进剂追击机制。
4. **直线范围 `line(n)` 的方向（拍板 = 仅横竖 4 方向，不含斜线，配布尔常量）**：
   - 在 `part_system.gd` 中定义常量：`const LINE_ALLOW_DIAGONAL: bool = false`；
   - 当 `LINE_ALLOW_DIAGONAL == false` 时，`line(n)` 判定为：**`(dx == 0 or dy == 0) and max(dx, dy) >= 1 and max(dx, dy) <= n`**（仅正横、正竖 4 方向，1~n 格内，不可拐弯、不含斜线）。

---

## §2 通用移动规则与范围函数（全部加工品通用）

1. **网格坐标几何距离（无视连通与障碍）**：
   - 判定目标格一律用**网格坐标 `(x, y)` 几何距离**（`dx = abs(tx - cx)`, `dy = abs(ty - cy)`），**严禁使用 BFS / 最短路 / 道路连通性**。隔着空格（不存在的格）或断路时，零件照样可以跳过去！
2. **瞬移语义**：
   - 中间经过的格子**不触发事件、不揭雾**，只有最终落点格揭雾并触发该格节点事件；
   - 目标格必须是 `cell.exists == true`（存在节点的格），且除 `bagua`（小八界极端兜底可能原地不动）外，目标格**不能是当前所在格（`cell_id != state.cur`）**。
3. **范围是 `1 ~ N` 格内（非恰好 `= N`）**：
   - 四种几何范围算子：
     - `adj8`：`max(dx, dy) == 1`（周围相邻 8 格，含斜角，距离 1）
     - `ring12`：`dx + dy >= 1 and dx + dy <= 2`（周围曼哈顿距离 1~2 的 12 格菱形）
     - `line(n)`：`((dx == 0 or dy == 0) or (LINE_ALLOW_DIAGONAL and dx == dy)) and max(dx, dy) >= 1 and max(dx, dy) <= n`（默认 `LINE_ALLOW_DIAGONAL = false`，横竖直线 1~n 格）
     - `any`：除当前格外的本层任意存在格

---

## §3 全部 13 件零件逐件完整规格表

> 数据源文件：`godot/data/js/94-零件.json`（同步更新）与 `godot/core/run/part_system.gd`。
> 每个零件均須携带 `rarity`（`"low" | "mid" | "high"`）、`free`（布尔）、`breakOnNextFloor`（布尔，默认 `false`）字段。

| # | 键 (`id`) | 名称 | 分类 | `range` / 目标规则 | `uses` | `free` | `breakOnNextFloor` | `price` | `rarity` | 特殊效果与规则变更 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `wheel` | 报废轮子 | 加工品 | `line(2)`（横竖直线 1~2 格） | 1 | `false` | `false` | 2 | `"low"` | 耗 1 推进剂；只能落横竖直线 1~2 格 |
| 2 | `limb` | 报废假肢 | 加工品 | `adj8`（相邻 8 格，含斜角） | 1 | `false` | `false` | 2 | `"low"` | 耗 1 推进剂 |
| 3 | `hover` | 气垫底座 | 加工品 | `ring12`（菱形 `1 <= dx+dy <= 2`） | 2 | `false` | `false` | 4 | `"mid"` | 耗 1 推进剂 |
| 4 | `exo` | 试作外骨骼 | 加工品 | `line(3)`（横竖直线 1~3 格） | 2 | `false` | `false` | 4 | `"mid"` | 耗 1 推进剂；只能落横竖直线 1~3 格 |
| 5 | `engine` | 标准引擎 | 加工品 | `adj8`（相邻 8 格，含斜角） | 3 | `false` | `false` | 4 | `"mid"` | 耗 1 推进剂 |
| 6 | `spring` | 重弹簧 | 加工品 | `ring12`（菱形 `1 <= dx+dy <= 2`） | 1 | **`true`** | **`true`** | 6 | `"mid"` | **免推进剂**；**进入下一层时自动损坏** |
| 7 | `jet` | 一次性喷气背包 | 加工品 | `any`（全图任意存在格） | 1 | **`true`** | `false` | 8 | `"mid"` | **免推进剂**；额外带字段 `"downgradePool": true` |
| 8 | `bagua` | 小八界 | 加工品 | **不可自选落点（一键随机传送）** | 1 | **`true`** | **`true`** | 4 | `"low"` | **免推进剂**；**进入下一层自动损坏**；点击直接使用，随机传送到一个非战斗格（**优先未探索 `not is_known` 的非战斗格**；若无未探索非战斗格，则从全部非战斗格含当前格中随机选，可能原地不动）。**删除旧版的揭四邻雾与回 1 推进剂效果！** |
| 9 | `thaw` | 老妈的融雪 | 加工品 | **全图任意非战斗格（不要求已探明）** | 1 | `false` | `false` | 8 | `"high"` | 耗 1 推进剂；移动后 **希望 +2**；**删除旧版的 +3 肉鸽经验！** |
| 10 | `tentacle` | 坎诺特的触须 | 加工品 | **本层已探明（`is_known`）的黑市格** | 2 | `false` | `false` | 12 | `"high"` | 耗 1 推进剂；每次移动后 **源碳 +4**；**无法选中迷雾里的黑市**（无已探明黑市或已在黑市格时置灰不可用） |
| 11 | `bloodcap` | 血蕈 | 自然物 | 不可主动使用（只供黑市卖出） | `null` | — | `false` | 4 | `"mid"` | **初始估价 `2`**；持有期间**每打完一场战斗（无论胜败）估价 `+2`，不设上限**！ |
| 12 | `wave` | 浪花 | 自然物 | 不可主动使用（只供黑市卖出） | `null` | — | `false` | 6 | `"low"` | **初始估价 `3`**；大地图**每移动一次**（含普通移动与零件移动），每件浪花独立随机 **`-6` 或 `+8`（各 50% 概率）**，估价夹在 **`[0, 999]`** 之间（用可复现的带种子随机步进，非旧版 2~8 循环表）。 |
| 13 | `rite` | 河谷祭祈 | 概念体 | 被动常驻（`用: false`） | `null` | — | `false` | 6 | `"mid"` | 持有时每层推进剂上限 `+1`；修正表内 `"用": false` |

---

## §4 子任务拆解与文件落点

### 子任务 `PART-1`：数据表更新与 `PartSystem` 内核重写
- **归属文件**：
  - `godot/data/js/94-零件.json`
  - `godot/core/run/part_system.gd`
- **施工要点**：
  1. 更新 `94-零件.json` 中全部 13 件零件的字段（`价`、`次数`、`用`、`移动`、`免费`/`free`、`跨层损坏`/`breakOnNextFloor`、`rarity`、`downgradePool`、`初值`、`说明` 文案同步更新为新效果）。
  2. 在 `part_system.gd` 中：
     - 定义 `const LINE_ALLOW_DIAGONAL: bool = false`；
     - 重写 `part_targets(state, key)`：
       - 移除旧版基于 BFS 距离 `d == 2` 等连通距离的判据，改为读取当前格 `(cx, cy)` 与目标格 `(tx, ty)` 的几何 `dx, dy`；
       - 实现 `adj8`、`ring12`、`line(2)`、`line(3)`、`any`、`thaw`（全图非当前格且 `not MapGenerator.是战斗节点(cell.type)`）、`tentacle`（`cell.type == "黑市" and MapNavigator.is_known(state, id) and id != state.cur`）；
       - 对 `bagua`（小八界）：标记为 `no_target_select = true`（不需要玩家选格），并提供候选池计算函数 `bagua_candidates(state) -> Array`：先收集本层所有 `exists and not is_known and 非战斗格`；若非空则从中随机抽 1 格；若为空则收集本层所有 `exists and 非战斗格`（含当前格）随机抽 1 格。
     - 重写 `use_part(state, idx, target_cell_id)`：
       - 校验推进剂：若 `not info.free` 且 `int(state.propellant) < 1`，拒绝使用并返回 `{ok: false, why: "推进剂不足"}`；
       - 若是 `bagua`：若未传 `target_cell_id` 或传空，内部按带种子的确定性随机从 `bagua_candidates(state)` 抽出落点格（不揭四邻雾、不回推进剂）；
       - 扣减推进剂：若 `not info.free`，`state.propellant = max(0, int(state.propellant) - 1)`，并在 `state.propellant_log` 记录零件耗能；
       - 执行瞬移落点：将 `state.cur = target_cell_id`，揭开落点本身（`MapNavigator.reveal_at(state, target_cell_id)` 或只揭落点），触发 `wave_fluctuate(state)`（大地图移动一次，浪花波动）；
       - 特殊奖励：
         - `thaw`（老妈的融雪）：`state.hope += 2`（不再加肉鸽经验）；
         - `tentacle`（坎诺特的触须）：`state.carbon += 4`；
       - 扣减零件 `uses`（归 0 从 `state.parts` 移除）。
     - 重写自然物与跨层损坏函数：
       - `bloodcap_appreciate(state)`：遍历 `state.parts` 中所有 `bloodcap`，每件 `val += 2`（**无上限**）；
       - `wave_fluctuate(state)`：每次移动步进计数器，每件 `wave` 按确定性伪随机（50% `-6`，50% `+8`）更新 `val = clampi(val + delta, 0, 999)`；
       - `break_on_next_floor(state) -> Array`：进入下一层时遍历 `state.parts`，移除所有 `breakOnNextFloor == true`（`spring` 重弹簧、`bagua` 小八界）的零件，返回损坏的零件名列表并写入 `state.add_log("〔零件〕跨层损坏：…")`。
     - 重写 `sell_price(part) -> int`：
       - `类 == "自然物"`：返回 `int(part.get("val", info.初值))`；
       - `类 == "加工品"` 或 `类 == "概念体"`：**固定返回 `1`**（1 源碳）。
     - 随机抽零件函数支持 `weight_by_rarity = null` 可选参数：
       - 在 `PartSystem.draw_part(seed_val, salt, weight_by_rarity = null)` 与 `NodeResolver.抽零件(state, salt, weight_by_rarity = null)` 统一预留可选参数 `weight_by_rarity`（默认 `null` 时从 13 件中等权随机，不读 `rarity`；传入字典如 `{"low": 50, "mid": 35, "high": 15}` 时按权重抽取）。

---

### 子任务 `PART-2`：局外流程接线（换层损坏 / 战后血蕈涨价 / 一键小八界 / 门面接口）
- **归属文件**：
  - `godot/core/run/map_navigator.gd`
  - `godot/core/run/node_resolver.gd`
  - `godot/session/game_session.gd`
- **施工要点**：
  1. **跨层损坏接线**：在 `map_navigator.gd` 的 `advance_floor(state)`（进入第 2/3/4 层调用 `enter_floor` 时），调用 `PartSystem.break_on_next_floor(state)` 移除 `spring` 与 `bagua`。
  2. **战后血蕈涨价接线**：在 `node_resolver.gd` 的 `resolve_battle(state, won, ...)` 中，**无论 `won` 为 `true` 还是 `false`（每打完一场战斗）**，一律调用 `PartSystem.bloodcap_appreciate(state)`。
  3. **普通移动触发浪花波动确认**：检查 `map_navigator.gd:move_to` 确保每次大地图移动都会调用 `PartSystem.wave_fluctuate(state)`。
  4. **门面 `GameSession` 适配**：
     - `part_can_use_now(idx)`：
       - 对 `rite` / `bloodcap` / `wave` 返回 `passive: true, ok: false`；
       - 对 `free: false` 的加工品，若 `state.propellant < 1`，返回 `ok: false, why: "推进剂不足（需 1 点）"`；
       - 对 `bagua`（小八界）：不需要选目标格（返回 `ok: true, instant: true, targets: ...`）；
     - `use_part_on_cell(idx, cell_id)` 与新增/兼容一键使用：当点 `bagua` 时，若 `instant == true`，可直接调用 `use_part` 完成随机传送并进入落点节点流程（若落点是特殊节点如休整/黑市/事件/出口则自动打开对应视图）。
     - `part_hover_text(idx)`：清晰展示 `[稀有度]`、`[消耗 1 推进剂 / 免推进剂]`、`[跨层损坏]`、`[出售价：N 源碳（自然物实时估价）]`。

---

### 子任务 `PART-3`：UI 表现层适配（黑市卖出估价 / 小八界一键触发 / 融雪全图非战斗格高亮）
- **归属文件**：
  - `godot/presentation/widgets/top_bar.gd`
  - `godot/presentation/run_map/map_view.gd`
  - `godot/presentation/menus/shop_view.gd`
- **施工要点**：
  1. **顶栏零件栏（`top_bar.gd`）**：
     - 自然物（`bloodcap` 血蕈、`wave` 浪花）在顶栏标签上直接显示实时估价，如 `血蕈(估价6)`、`浪花(估价11)`；
     - 概念体（`rite` 河谷祭祈）显示 `河谷祭祈·被动`（不再当成坏掉的按钮）；
     - 点击 `bagua`（小八界）时：因为不需要选落点，点击直接触发（或在地图瞄准条点「立即发动随机传送」一键生效）。
  2. **大地图零件瞄准（`map_view.gd`）**：
     - 当瞄准 `thaw`（老妈的融雪）时，允许高亮并点击**迷雾中的非战斗格**；
     - 瞄准横幅写明该零件是否消耗推进剂（如 `【正在使用：报废轮子（消耗 1 推进剂）— 请点击横竖直线 1~2 格内的高亮格】`）。
  3. **黑市出售界面（`shop_view.gd`）**：
     - 在黑市「出售持有零件」区域，醒目区分自然物与其他零件：
       - 自然物按钮显示：`卖出【血蕈】 -> 获得 6 源碳（当前估价）`；
       - 加工品/概念体按钮显示：`卖出【报废轮子】 -> 获得 1 源碳`。

---

## §5 验收门禁（必须全部绿）

1. **更新并扩充单元测试（`test_run_map.gd` / `test_session_flow.gd` / `test_presentation_layout.gd`）**：
   - 断言 1（直线不拐弯）：`wheel`（`line(2)`）和 `exo`（`line(3)`）只能选中 `dx == 0` 或 `dy == 0` 的直线格，`dx == 1, dy == 1` 的斜角格不在目标列表内；
   - 断言 2（无视断路/空格）：人为把中间格设为 `exists = false` 或无边相连，`wheel` / `exo` / `hover` / `spring` 照样能选中对岸的目标格并瞬移过去；
   - 断言 3（推进剂消耗与 0 推进剂禁则）：除 `spring`、`jet`、`bagua` 外，其余 7 件使用后 `state.propellant` 精确 `-1`；且当 `state.propellant == 0` 时，这 7 件 `part_can_use_now().ok == false`，而 `spring` / `jet` / `bagua` 仍为 `true`；
   - 断言 4（跨层损坏）：持有 `spring`、`bagua`、`wheel`、`rite` 进入下一层后，`spring` 与 `bagua` 自动从 `state.parts` 移除，`wheel` 与 `rite` 保留；
   - 断言 5（坎诺特的触须迷雾限制）：当本层黑市格 `is_known == false` 时，`tentacle` 的 `part_targets` 为空（不可选中迷雾黑市）；探明后可选，移动后 `carbon +4` 且剩余次数 `2 -> 1`；
   - 断言 6（老妈的融雪 & 小八界）：`thaw` 可选中未探明的非战斗格（含出口格，不含战斗/守军格），移动后 `hope +2` 且经验不变；`bagua` 优先传送到未探明非战斗格，不回推进剂；
   - 断言 7（血蕈与浪花 & 黑市售价）：战斗胜利和战斗失败后 `bloodcap` 估价均 `+2` 且可超过 15；每次移动后 `wave` 估价按 `-6` 或 `+8` 变化并夹在 `[0, 999]`；黑市卖自然物得当前估价，卖加工品/概念体固定得 `1` 源碳；
   - 断言 8（`weight_by_rarity` 接口）：默认 `null` 等权抽取；传入权重表时按稀有度权重抽取。
2. **全量门禁**：`run_tests.gd` 全部通过、退出码 `0`、`SCRIPT ERROR = 0`、`test_font_coverage.gd` 通过、`SEAL_EXIT=0`。
3. **重打本地 Web 包**：更新 `F:\DSH-mecha\.tools\smoke\_site\godot\index.pck`。
