## 大地图移动 / 层流转（MapNavigator）—— 对齐封存 JS 参考版的
##   `91-地图.js` 的 `全距离()` / `移动距离()` / `能去的格()` / `退路成本()`
##   `90-肉鸽-3-开局与移动.js` 的 `进层()` / `下一层()` / `换层()` / `追击之后()` / `移动()`
##   `90-肉鸽-6-存档与收尾.js` 的 `格没走过()` · `90-肉鸽-5` 的 `清空格()` / `守军已清()` / `出口要守军()`
##
## ★ 严格落实 **D-02 五处口径**（`godot/tests/golden/已接受差异表.md`）：
##   B 林间空地**照常扣 d 点推进剂**，落到未走过的「空」格 → 当场标 `已过` + 结果条（不弹模态框）；
##   C 追击打赢**没有推进剂恢复** → `追击 = true` + `层推进剂修正 = -2` → 直接换层；
##   D **只有**「脚下是出口格 + 推进剂 0」这一次追击战过守军闸（显式标记 `state.exit_chase`，
##     绝不用 `追击 && 推进剂 ≤ 0` 推断）；走**小径免打守军**；
##   E 走小径 → 把**下一层**的推进剂上限 +2（记进 `state.trail_floors`）。
##
## 原生 Godot 强类型实现：**零 `J.*`**、零随机数（0 rng）。
class_name MapNavigator
extends RefCounted

const TUNNEL_COST_DEFAULT := 1
const 林间空地提示 := "经过林间空地：落脚休整片刻，未遭遇敌情。"

# ==========================================================================================
# 一、读取态（格表 / 距离表 / 能去的格）
# ==========================================================================================

## 地图格号（升序 —— 与 JS `Object.keys(格).map(Number)` 的整数键次序一致）。
static func cell_ids(state: RunState) -> Array:
	var ids: Array = []
	for k in state.grid().keys():
		ids.append(int(k))
	return JsCompat.stable_sort(ids, func(a, b): return int(a) < int(b))

static func columns(state: RunState) -> int:
	return maxi(1, int(state.map_data.get("列数", 5)))

## 不算推进剂上限的距离表（`91-地图.js:692-694` 的全距离）。
static func full_distances(state: RunState) -> Dictionary:
	return MapGenerator.bfs_distances(state.node_id, _int_set(state), columns(state))

## 推进剂够得着的距离表（BFS 深度上限 = 当前推进剂，`91-地图.js:696-705`）。
static func move_distances(state: RunState) -> Dictionary:
	var cols := columns(state)
	var cap: int = maxi(0, state.propellant)
	var d: Dictionary = {state.node_id: 0}
	var q: Array = [state.node_id]
	var head := 0
	while head < q.size():
		var k: int = int(q[head])
		head += 1
		if int(d[k]) >= cap:
			continue
		for n in MapGenerator.neighbors_of(k, cols):
			if state.has_cell(n) and not d.has(n):
				d[n] = int(d[k]) + 1
				q.append(n)
	return d

## 这一格走过了吗（`90-肉鸽-6-存档与收尾.js:341-348` 的 `格没走过()`）。
static func walkable(state: RunState, k: int) -> bool:
	if k == state.node_id:
		return false
	var cell := state.cell_at(k)
	if cell.is_empty():
		return false
	if bool(cell.get("已过", false)):
		return false
	if MapGenerator.exit_kinds().has(String(cell.get("类型", ""))):
		return true
	return not state.is_visited(k)

## 能去的格（`90-肉鸽-3-开局与移动.js:326-331`）：推进剂为 0 时一个都去不了。
static func reachable_cells(state: RunState) -> Array:
	if state.propellant <= 0:
		return []
	var out: Array = []
	var d := move_distances(state)
	for k in d.keys():
		if int(d[k]) >= 1 and walkable(state, k):
			out.append(k)
	return out

# ==========================================================================================
# 二、移动
# ==========================================================================================

static func tunnel_cost() -> int:
	if Db.installed and Db.T.get("肉鸽数值") is Dictionary:
		var v: Variant = (Db.T["肉鸽数值"] as Dictionary).get("隧道花费")
		if v != null:
			return int(v)
	return TUNNEL_COST_DEFAULT

## 废弃隧道另一头（`90-肉鸽-4-节点结算.js:120-124`）：本层隧道里第一个不是当前格的；没有 → −1。
static func tunnel_other_end(state: RunState) -> int:
	var tunnels: Variant = state.map_data.get("隧道", [])
	if not (tunnels is Array):
		return -1
	for t in (tunnels as Array):
		if int(t) != state.node_id:
			return int(t)
	return -1

static func _is_tunnel_cell(state: RunState) -> bool:
	return state.current_type() == "隧道"

## 能不能走到 `target_id`：相邻走 1 格扣 1 点 / 跳格按 BFS 最短路扣 d 点 / 隧道两端互通扣 1 点。
## 返回 `{"ok": bool, "cost": int, "path": Array, "隧道": bool, "为什么": String}`。
static func can_move_to(state: RunState, target_id: int) -> Dictionary:
	if state.map_data.is_empty():
		return {"ok": false, "cost": 0, "path": [], "隧道": false, "为什么": "还没有大地图"}
	var target := int(target_id)
	if target == state.node_id:
		return {"ok": false, "cost": 0, "path": [], "隧道": false, "为什么": "已经在那一格"}
	if not state.has_cell(target):
		return {"ok": false, "cost": 0, "path": [], "隧道": false, "为什么": "那一格不存在"}
	# (1) 废弃隧道两端互通（照抄原作「行动力只在进入时被消耗」：进隧道花 1 点）
	if _is_tunnel_cell(state) and target == tunnel_other_end(state):
		var 费 := tunnel_cost()
		if state.propellant >= 费:
			return {"ok": true, "cost": 费, "path": [state.node_id, target], "隧道": true, "为什么": ""}
		return {"ok": false, "cost": 费, "path": [], "隧道": true,
			"为什么": "推进剂不够：进隧道要花 %d 点（现在 %d）" % [费, state.propellant]}
	# (2) 普通徒步 / 跳格：BFS 最短路的格数，上限 = 当前推进剂
	var d := move_distances(state)
	if not d.has(target) or int(d[target]) <= 0:
		return {"ok": false, "cost": 0, "path": [], "隧道": false,
			"为什么": "走不到那一格（推进剂 %d 点不够，或者路上断开了）" % state.propellant}
	var cost := int(d[target])
	return {"ok": true, "cost": cost, "path": _bfs_path(state, state.node_id, target, cost), "隧道": false, "为什么": ""}

## 最短路径（含起点与终点）。
static func _bfs_path(state: RunState, from_id: int, to_id: int, cap: int) -> Array:
	var cols := columns(state)
	var prev: Dictionary = {}
	var d: Dictionary = {from_id: 0}
	var q: Array = [from_id]
	var head := 0
	while head < q.size():
		var k: int = int(q[head])
		head += 1
		if k == to_id:
			break
		if int(d[k]) >= cap:
			continue
		for n in MapGenerator.neighbors_of(k, cols):
			if state.has_cell(n) and not d.has(n):
				d[n] = int(d[k]) + 1
				prev[n] = k
				q.append(n)
	if not d.has(to_id):
		return [from_id]
	var path: Array = [to_id]
	var cur := to_id
	while prev.has(cur):
		cur = int(prev[cur])
		path.append(cur)
	path.reverse()
	return path

## 走到某一格（可以跳格）。返回 `{"ok", "格", "类型", "距离", "追击", "已过", "空格落脚", "从", "提示"}`。
## ★ 口径 B：**照常扣 d 点推进剂**；落到**未走过的**「空」格 → 当场标 `已过` + 结果条（不弹模态框）。
static func move_to(state: RunState, target_id: int) -> Dictionary:
	var can := can_move_to(state, target_id)
	if not bool(can["ok"]):
		return {"ok": false, "为什么": String(can.get("为什么", ""))}
	var target := int(target_id)
	var d := int(can["cost"])
	var 隧道 := bool(can.get("隧道", false))
	var 旧 := state.node_id
	state.propellant = maxi(0, state.propellant - d)
	if 隧道:
		state.mark_revealed(target)
	state.node_id = target
	state.mark_visited(target)
	var cell := state.cell_at(target)
	var 类型 := String(cell.get("类型", ""))
	var 已过 := bool(cell.get("已过", false)) or 类型 == "空"
	var 空格落脚 := 类型 == "空" and not bool(cell.get("已过", false))
	var 提示 := ""
	if 空格落脚:
		cell["已过"] = true
		提示 = 林间空地提示
		state.add_log(提示)
	if d == 1:
		state.add_log("移动到 (%d, %d)%s（−1 推进剂，剩 %d）" % [
			int(cell.get("列", 0)) + 1, int(cell.get("行", 0)) + 1,
			"" if 类型 == "空" else " · %s" % 类型, state.propellant])
	if d > 1:
		state.add_log("跳过中间格，直接前往（−%d 推进剂）" % d)
	# ★ 任务书 §1 模块 2 · (3)：浪花估价在**每次移动成功后**确定性波动（−6 / +8，不消耗 rng）
	var 浪变 := PartSystem.wave_fluctuate(state)
	if not 浪变.is_empty():
		state.add_log("浪花估价波动：%s（可在黑市按新的估价卖出）" % "、".join(浪变))
	return {
		"ok": true, "格": cell, "类型": 类型, "距离": d, "追击": state.propellant <= 0,
		"已过": 已过, "空格落脚": 空格落脚, "从": 旧, "提示": 提示, "路径": can.get("path", []),
	}

## 穿隧道（`90-肉鸽-4-节点结算.js:131-146`）：花 1 点推进剂跳到另一端，顺手揭开那一格。
static func use_tunnel(state: RunState) -> Dictionary:
	var 那头 := tunnel_other_end(state)
	if 那头 < 0:
		state.add_log("废弃隧道：另一头已经塌了（这一格没有配对隧道）")
		return {"ok": false, "传送": false, "为什么": "这一格没有配对隧道"}
	var 费 := tunnel_cost()
	if state.propellant < 费:
		return {"ok": false, "传送": false,
			"为什么": "推进剂不够：进隧道要花 %d 点（现在 %d）—— 照抄原作「行动力只在进入时被消耗」" % [费, state.propellant]}
	state.propellant -= 费
	state.mark_revealed(那头)
	state.node_id = 那头
	state.mark_visited(那头)
	state.add_log("废弃隧道：花 %d 推进剂（剩 %d），传送到另一头，顺手揭开那一格" % [费, state.propellant])
	return {"ok": true, "传送": true, "到": 那头, "类型": state.current_type(), "花费": 费, "推进剂": state.propellant}

# ==========================================================================================
# 三、退路成本（★ 调研 §5 A4，**纯读**、0 rng —— 三层反馈的「预告」那一层）
# ==========================================================================================

## 走进去之后要花几点才回得到干路（`91-地图.js:721-740`）。返回 −1 = 找不到 / 这一格不存在。
static func retreat_cost(state: RunState, target_id: int) -> int:
	var target := int(target_id)
	if state.cell_at(target).is_empty():
		return -1
	var cols := columns(state)
	var present := _int_set(state)
	var arts := MapGenerator.articulation_points(present, cols)
	if _is_trunk(target, present, arts, cols):
		return 0
	var 已走过 := MapGenerator.int_key_set(state.visited_cells)
	var d: Dictionary = {target: 0}
	var q: Array = [target]
	var head := 0
	while head < q.size():
		var x: int = int(q[head])
		head += 1
		for n in MapGenerator.neighbors_of(x, cols):
			if not present.has(n) or d.has(n):
				continue
			if _is_trunk(n, present, arts, cols) and n != target and not 已走过.has(n):
				return int(d[x]) + 1
			d[n] = int(d[x]) + 1
			q.append(n)
	return -1

## 退路成本预告（界面 / 测试用；**纯读**：不写 state 任何字段、不消耗随机数）。
static func retreat_cost_preview(state: RunState, target_id: int) -> Dictionary:
	var target := int(target_id)
	var cell := state.cell_at(target)
	if cell.is_empty():
		return {"ok": false, "格": target, "退路成本": -1, "是干路": false, "为什么": "那一格不存在"}
	var cols := columns(state)
	var present := _int_set(state)
	var arts := MapGenerator.articulation_points(present, cols)
	var m := retreat_cost(state, target)
	return {
		"ok": m >= 0, "格": target, "退路成本": m, "是干路": m == 0,
		"类型": String(cell.get("类型", "")),
		"列": int(cell.get("列", MapGenerator.cell_col(target, cols))),
		"行": int(cell.get("行", MapGenerator.cell_row(target, cols))),
		"度数": _degree(target, present, cols), "是割点": arts.has(target),
	}

static func _is_trunk(k: int, present: Dictionary, arts: Dictionary, cols: int) -> bool:
	return _degree(k, present, cols) >= 3 or arts.has(k)

static func _degree(k: int, present: Dictionary, cols: int) -> int:
	var n := 0
	for x in MapGenerator.neighbors_of(k, cols):
		if present.has(x):
			n += 1
	return n

# ==========================================================================================
# 四、出口 / 追击 / 层流转（★ D-02 口径 C / D / E）
# ==========================================================================================

## 这一层的出口守军清了吗（`90-肉鸽-5-晋升与通关.js:281-285`）：没地图 / 没守军格 = 清。
static func is_guard_cleared(state: RunState) -> bool:
	var id: Variant = state.map_data.get("守军")
	if id == null:
		return true
	var cell := state.cell_at(int(id))
	if cell.is_empty():
		return true
	return bool(cell.get("已过", false)) or String(cell.get("类型", "")) == "空"

## 这个出口要不要先打赢出口守军（`90-肉鸽-5-晋升与通关.js:294`）：
## **出口尽头要，出口小径免**；认不出来（"" / null）按「要」算（保守，老行为一字不变）。
static func exit_requires_guard(exit_kind: String) -> bool:
	return exit_kind != "小径"

## 本层走的出口类型（"尽头" / "小径" / "" —— 认不出来）；判据只此一处：
## `state.exit_choices[层]` 优先（由界面/调用方 `选出口()` 记），否则看脚下那一格的类型。
static func current_exit_kind(state: RunState) -> String:
	var v: Variant = state.exit_choices.get(state.floor_num)
	if v == null:
		v = state.exit_choices.get(str(state.floor_num))
	if v != null:
		var s := String(v)
		if s == "尽头" or s == "小径":
			return s
	var kinds := MapGenerator.exit_kinds()
	var t := state.current_type()
	if kinds.has(t):
		return String(kinds[t])
	return ""

## 记下「这一层走的是哪个出口」（出口两型互斥）。认不出来的类型拒绝。
static func choose_exit(state: RunState, exit_kind: String) -> bool:
	if exit_kind != "尽头" and exit_kind != "小径":
		return false
	state.exit_choices[state.floor_num] = exit_kind
	return true

## 「推进剂 0 触发的追击战」要不要打（`90-肉鸽-3-开局与移动.js:211`）：本层没追击过、推进剂见底。
static func exit_chase_pending(state: RunState) -> bool:
	return state.propellant <= 0 and not state.chased

## 由**知道脚下是不是出口格**的调用方置位（★ 口径 D：这道闸只认这个显式标记）。
static func begin_exit_chase(state: RunState) -> void:
	state.exit_chase = true

## 进一层（`90-肉鸽-3-开局与移动.js:91-120`）：换地图 → 起点 → 清已走过 / 已揭开 → 重置推进剂。
## ★ 不动 `layer_prop_bonus`（被追击过的 −2 要跨层留着，JS 也一样）。
static func enter_floor(state: RunState, floor_num: int) -> void:
	var 旧rogue: Variant = state.map_data.get("_rogue")
	state.floor_num = floor_num
	state.map_data = MapGenerator.generate_floor(floor_num, MapGenerator.map_seed(state.seed_val, floor_num))
	# `_rogue` 是别的模块挂在 map_data 上的侧信道（希望来源账 / 黑市刷新次数）—— 换层不能把它丢掉；
	# 其中「黑市刷新次数」照 JS 的 `进层()` 归零（它是**每一格黑市**的计数）。
	if 旧rogue is Dictionary:
		var rogue: Dictionary = (旧rogue as Dictionary).duplicate(true)
		rogue["黑市刷新次数"] = 0
		state.map_data["_rogue"] = rogue
	state.node_id = int(state.map_data.get("起点", 0))
	state.visited_cells = [state.node_id]
	state.revealed_cells = []
	state.chased = false
	state.exit_chase = false
	state.pending_floor_change = null
	PartSystem.recalc_propellant_bonus(state)
	state.propellant = MapGenerator.propellant_max(state)
	state.propellant_max = state.propellant
	var 账 := MapGenerator.propellant_detail(state)
	state.add_log("—— 进入第 %d 层（%d×%d 正方形；推进剂 %d = 该图最短路 %d + 余量 %d）：可以绕 %d 步 ——" % [
		floor_num, int(state.map_data.get("列数", 0)), int(state.map_data.get("行数", 0)),
		state.propellant, int(账["最短路"]), int(账["余量"]), int(账["余量"])])

## 出口换希望（`90-肉鸽-3-开局与移动.js:149-161`；率 = `肉鸽数值.出口换希望`）。
static func _exit_hope_rate() -> float:
	if Db.installed and Db.T.get("肉鸽数值") is Dictionary:
		var v: Variant = (Db.T["肉鸽数值"] as Dictionary).get("出口换希望")
		if v != null:
			return float(v)
	return 0.5

## 出口结算 + 换层（= JS `下一层()` + `换层()` 的合并版，**唯一漏斗**）。
##   (1) **守军闸**（★ 口径 D）：只有 `state.exit_chase` 这一趟、守军没清、且走的是**尽头** → 拦下来，
##      记 `state.pending_floor_change = {"层": 当前层, "追击": true}` 并返回（等守军打赢那一下补上）；
##   (2) **出口小径**（★ 口径 E）：不给希望，把**下一层**推进剂上限 +2（记进 `state.trail_floors`）；
##   (3) **出口尽头**：剩余推进剂 × 率 → 希望，推进剂清零；
##   (4) 第 4 层通过 → `state.status = "胜利"`；否则进下一层。
static func advance_floor(state: RunState) -> Dictionary:
	var kind := current_exit_kind(state)
	if state.exit_chase and not is_guard_cleared(state) and exit_requires_guard(kind):
		state.pending_floor_change = {"层": state.floor_num, "追击": true}
		state.add_log("出口守军还没打掉：这一格通不了下一层（打赢守军才放行，这次走到的出口先记着）")
		return {"ok": false, "换层": false, "层": state.floor_num,
			"待换层": (state.pending_floor_change as Dictionary).duplicate(), "为什么": "出口守军还没清"}
	if kind == "小径" and state.floor_num < 4:
		var 目标层 := state.floor_num + 1
		if not state.trail_floors.has(目标层):
			state.trail_floors.append(目标层)
		state.add_log("走了出口小径：把推进剂带到下一层 → 第 %d 层上限 +%d" % [目标层, MapGenerator.TRAIL_BONUS_FALLBACK])
	elif kind != "小径":
		var 余 := maxi(0, state.propellant)
		var 换 := floori(float(余) * _exit_hope_rate())
		if 换 > 0:
			state.hope += 换
			state.propellant = 0
			state.add_log("出口尽头：剩余推进剂 %d → 希望 +%d（照抄黑流树海「险路尽头」，希望 %d）" % [余, 换, state.hope])
		else:
			state.add_log("出口尽头：一点推进剂都没剩，换不到希望（照抄黑流树海「险路尽头」）")
	if state.floor_num >= 4:
		state.pending_floor_change = null
		state.status = "胜利"
		state.add_log("通关：击败终点守军，走出迷宫（最后一层）")
		return {"ok": true, "换层": true, "通关": true, "层": state.floor_num}
	state.pending_floor_change = null
	var 前 := state.floor_num
	enter_floor(state, 前 + 1)
	# ★ 任务单 PART-2 · 1：进入下一层时结算「跨层损坏」（重弹簧 / 小八界自动从手上移除）。
	var 坏 := PartSystem.break_on_next_floor(state)
	return {"ok": true, "换层": true, "通关": false, "层": state.floor_num, "从": 前, "跨层损坏": 坏}

## 走出口（普通路径）：先按「被追击过 → 下一层上限 −2」定修正，再走 `advance_floor`。
static func resolve_exit(state: RunState) -> Dictionary:
	state.layer_prop_bonus = -2 if state.chased else 0
	return advance_floor(state)

## 追击战打赢（`90-肉鸽-3-开局与移动.js:193-198`，★ 口径 C：**没有推进剂恢复**）。
static func after_chase_win(state: RunState) -> Dictionary:
	state.chased = true
	state.layer_prop_bonus = -2
	return advance_floor(state)

## 出口守军被打赢（`90-肉鸽-4-节点结算.js:382-396`）：清空格 + 把欠的那一次换层**当场补上**。
static func after_guard_win(state: RunState) -> Dictionary:
	var id: Variant = state.map_data.get("守军")
	if id != null:
		var cell := state.cell_at(int(id))
		if not cell.is_empty():
			cell["已过"] = true
			cell["类型"] = "空"
			cell["关卡"] = null
	var 欠: Variant = state.pending_floor_change
	state.pending_floor_change = null
	if 欠 is Dictionary:
		state.add_log("出口守军已清 —— 补上第 %d 层那次没走成的换层（当时被守军挡着）" % int((欠 as Dictionary).get("层", state.floor_num)))
		return advance_floor(state)
	return {"ok": true, "换层": false, "层": state.floor_num}

## 格表（int 键集合，**升序**插入 —— 与 JS `Object.keys(格).map(Number)` 的整数键次序一致，
## 这决定了 Tarjan 的起点，从而决定「割点」在**根**上的那一条判据）。
static func _int_set(state: RunState) -> Dictionary:
	var out: Dictionary = {}
	for k in cell_ids(state):
		out[k] = true
	return out

## 这一格「已知」吗（已走过 / 被揭开）。★ 兼容别的模块挂在 `map_data["已揭开"]` 上的记录。
static func is_known(state: RunState, k: int) -> bool:
	if state.is_visited(k) or state.is_revealed(k):
		return true
	var 揭: Variant = state.map_data.get("已揭开")
	if 揭 is Array:
		for x in (揭 as Array):
			if int(x) == k:
				return true
	return false
