## 大地图生成（MapGenerator）—— 100% 复现封存 JS 参考版 `src/js/91-地图.js` 的
## `生成层()` / `推进剂上限()` / `推进剂账()` / `推进剂余量()` / `割点们()` / `必经点()`。
##
## 原生 Godot 强类型实现：**零 `J.*`**（`JsCompat` / `Mulberry32` 是底层数值工具，不是 JS 特有写法）。
## 数据（形状表 / 推进剂余量表 / 出口类型表 / 关卡池 / 阶段名 / 肉鸽数值）从 `Db` 读；
## `Db` 没装时退回本文件里的兜底常量（值逐字等于 `godot/data/js/9*.json`）。
##
## 对拍口径：`generate_floor(层, 地图种子(种子, 层))` 的返回值与
## `godot/tests/golden/run_vectors.json` 的 `地图[].地图` **逐字段相等**（8 种子 × 4 层）。
class_name MapGenerator
extends RefCounted

## JS `重试上限`：试满这么多次还挑不出合条件的图就判失败（确定性，同种子同结果）。
const MAX_TRIES := 2000

## 形状表兜底（`91-地图.js:53-64`，逐字）。正方形：列数 = 行数。
const SHAPE_FALLBACK: Dictionary = {
	1: {"列数": 5, "行数": 5, "存在率": 0.78, "连通下限": 17},
	2: {"列数": 6, "行数": 6, "存在率": 0.72, "连通下限": 23},
	3: {"列数": 6, "行数": 6, "存在率": 0.66, "连通下限": 21},
	4: {"列数": 7, "行数": 7, "存在率": 0.62, "连通下限": 27},
}
## 推进剂余量表兜底（`91-地图.js:237`：★ D-02 口径 A，全部偶数）。
const REMAINDER_FALLBACK: Dictionary = {1: 2, 2: 2, 3: 4, 4: 4}
## 关卡池 / 阶段名兜底（`91-地图.js:302-303`）。
const STAGE_POOL_FALLBACK: Dictionary = {"作战": 8, "精英": 3, "守军": 3, "侵蚀源": 2, "追击": 2}
const PHASE_NAME_FALLBACK: Dictionary = {"作战": "N", "精英": "E", "守军": "G", "侵蚀源": "S", "追击": "C", "终点": "F"}
## 出口两型 → 出口类型表（`91-地图.js:137`）。
const EXIT_KIND_FALLBACK: Dictionary = {"出口尽头": "尽头", "出口小径": "小径"}
## 走出口小径 → 下一层推进剂上限 +2（`90-肉鸽-1-数据与规则.js:250`，D-02 口径 E）。
const TRAIL_BONUS_FALLBACK := 2
## 进废弃隧道要花 1 点推进剂（`90-肉鸽-1-数据与规则.js:235`）。
const TUNNEL_COST_FALLBACK := 1

# ==========================================================================================
# 一、数据取用（Db 优先，兜底常量逐字等于导出的 JSON）
# ==========================================================================================

static func _db_const(常量名: String) -> Variant:
	if Db.installed and Db.T.has(常量名):
		return Db.T[常量名]
	return null

## 某一层的形状（`91-地图.js:66-69`：坏值 / 越界 → 第 1 层）。纯读，不消耗随机数。
static func shape(floor_num: int) -> Dictionary:
	var n := floori(float(floor_num))
	var t: Variant = _db_const("形状表")
	if t is Dictionary:
		var v: Variant = (t as Dictionary).get(str(n))
		if v is Dictionary:
			return {
				"列数": int((v as Dictionary).get("列数", 5)),
				"行数": int((v as Dictionary).get("行数", 5)),
				"存在率": float((v as Dictionary).get("存在率", 0.78)),
				"连通下限": int((v as Dictionary).get("连通下限", 17)),
			}
	var f: Variant = SHAPE_FALLBACK.get(n)
	if f is Dictionary:
		return (f as Dictionary).duplicate()
	return (SHAPE_FALLBACK[1] as Dictionary).duplicate()

## 某一层的推进剂余量（偶数，`91-地图.js:281-284`）。纯读。
static func propellant_remainder(floor_num: int) -> int:
	var n := floori(float(floor_num))
	var t: Variant = _db_const("推进剂余量表")
	if t is Dictionary:
		var v: Variant = (t as Dictionary).get(str(n))
		if v != null:
			return int(v)
	if REMAINDER_FALLBACK.has(n):
		return int(REMAINDER_FALLBACK[n])
	return int(REMAINDER_FALLBACK[1])

## 余量是不是偶数（二部图那一条，`91-地图.js:254-258`）。纯读。
static func remainder_is_even(floor_num: int) -> bool:
	return propellant_remainder(floor_num) % 2 == 0

## 逐层的静态口径（对应黄金样例 `run_vectors.json` 的 `推进剂明细[]`）。纯读。
static func remainder_detail(floor_num: int) -> Dictionary:
	var n := floori(float(floor_num))
	var 量 := propellant_remainder(n)
	return {"层": n, "形状": shape(n), "余量表": 量, "余量": 量, "是偶数": 量 % 2 == 0}

## 出口两型映射（"出口尽头" → "尽头"）。
static func exit_kinds() -> Dictionary:
	var t: Variant = _db_const("出口类型表")
	return (t as Dictionary) if t is Dictionary else EXIT_KIND_FALLBACK

## 地图种子 = `(RUN种子 + 层 × 101) >>> 0`（`91-地图.js:108`）。
static func map_seed(run_seed: int, floor_num: int) -> int:
	return (run_seed + floor_num * 101) & 0xFFFFFFFF

# ==========================================================================================
# 二、网格几何（正方形：列数 = 行数；索引制 格号 = 行 × 列数 + 列）
# ==========================================================================================

static func cell_id(col: int, row: int, cols: int) -> int:
	return row * cols + col

static func cell_col(k: int, cols: int) -> int:
	return k % cols

static func cell_row(k: int, cols: int) -> int:
	return floori(float(k) / float(cols))

## 四邻接（`91-地图.js:141-150`）：左 → 右 → 上 → 下（顺序会影响 BFS 的发现次序）。
static func neighbors_of(k: int, cols: int) -> Array:
	var out: Array = []
	var c := k % cols
	var r := floori(float(k) / float(cols))
	if c > 0:
		out.append(k - 1)
	if c < cols - 1:
		out.append(k + 1)
	if r > 0:
		out.append(k - cols)
	if r < cols - 1:
		out.append(k + cols)
	return out

## 一个格集合的「有没有这一格」。接受 Dictionary（键可以是 int 或 String）。
static func has_cell(格们: Dictionary, k: int) -> bool:
	if 格们.has(k):
		return true
	return 格们.has(str(k))

## 把 Dictionary（键 int / String）或 Array 统一成 int 键的集合。
static func int_key_set(格们: Variant) -> Dictionary:
	var out: Dictionary = {}
	if 格们 is Dictionary:
		for key in (格们 as Dictionary).keys():
			out[int(key)] = true
	elif 格们 is Array:
		for key in (格们 as Array):
			out[int(key)] = true
	return out

## 从 s 出发在 `格们` 里做四邻接 BFS：返回 Dictionary(格号 → 步数)。
## ★ 键的插入顺序 = BFS 发现顺序（JS 的 `Map` 一样）—— 调用方靠它复现「格们」的次序。
static func bfs_distances(start: int, 格们: Dictionary, cols: int) -> Dictionary:
	var d: Dictionary = {start: 0}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var k := int(q[head])
		head += 1
		var dk := int(d[k])
		for n in neighbors_of(k, cols):
			if has_cell(格们, n) and not d.has(n):
				d[n] = dk + 1
				q.append(n)
	return d

## 死胡同 = 连通份里只有一个邻居的格（`91-地图.js:177`）。
static func is_dead_end(k: int, 格们: Dictionary, cols: int) -> bool:
	var n := 0
	for x in neighbors_of(k, cols):
		if has_cell(格们, x):
			n += 1
	return n == 1

## 割点（Tarjan，无向连通图，`91-地图.js:182-201`）。返回 Dictionary(割点格号 → true)。
## 迭代版 DFS（GDScript 的 lambda 不能递归）；顶点次序与 JS 的 Set 遍历一致。
static func articulation_points(格们: Variant, cols: int) -> Dictionary:
	var present := int_key_set(格们)
	var disc: Dictionary = {}
	var low: Dictionary = {}
	var ap: Dictionary = {}
	var children: Dictionary = {}
	var parent_of: Dictionary = {}
	var timer := 0
	for root in present.keys():
		if disc.has(root):
			continue
		disc[root] = timer
		low[root] = timer
		timer += 1
		children[root] = 0
		var stack: Array = [[root, -1, 0]]
		while not stack.is_empty():
			var top: Array = stack[stack.size() - 1]
			var u := int(top[0])
			var parent := int(top[1])
			var ns := neighbors_of(u, cols)
			var pushed := false
			while int(top[2]) < ns.size():
				var v := int(ns[int(top[2])])
				top[2] = int(top[2]) + 1
				if not present.has(v):
					continue
				if not disc.has(v):
					disc[v] = timer
					low[v] = timer
					timer += 1
					children[v] = 0
					children[u] = int(children[u]) + 1
					parent_of[v] = u
					stack.append([v, u, 0])
					pushed = true
					break
				elif v != parent:
					low[u] = mini(int(low[u]), int(disc[v]))
			if pushed:
				continue
			stack.pop_back()
			if parent != -1:
				low[parent] = mini(int(low[parent]), int(low[u]))
				# ★ Tarjan 的老规矩：**根不许用这条判据** —— 只有「父节点自己也有父」时才成立
				#   （JS 那句是 `if (p != null && low.get(v) >= disc.get(u)) ap.add(u)`，
				#    `p` 是 u 的父亲；根的父亲是 null，所以根只走下面的 `子 > 1`）。
				if parent_of.has(parent) and int(low[u]) >= int(disc[parent]):
					ap[parent] = true
		if int(children[root]) > 1:
			ap[root] = true
	return ap

## 从 s 到 t 的**必经点**（去掉它之后 t 就不可达；不含 s / t 自己，`91-地图.js:206-216`）。
static func must_pass(格们: Variant, s: int, t: int, cols: int) -> Array:
	var present := int_key_set(格们)
	var out: Array = []
	for v in present.keys():
		if v == s or v == t:
			continue
		var rest: Dictionary = present.duplicate()
		rest.erase(v)
		if not bfs_distances(s, rest, cols).has(t):
			out.append(v)
	return out

# ==========================================================================================
# 三、推进剂（★ D-02 口径 A：余量表 {1:2,2:2,3:4,4:4}，「最短路」= 直达）
# ==========================================================================================

## 走出口小径带来的上限加成（`91-地图.js:265-269`）：`trail_floors` 里等于**当前层**的条数 × 量。
static func trail_bonus(state: RunState) -> int:
	var 量 := TRAIL_BONUS_FALLBACK
	var t: Variant = _db_const("肉鸽数值")
	if t is Dictionary and (t as Dictionary).has("出口小径加成"):
		量 = int((t as Dictionary)["出口小径加成"])
	var n := 0
	for x in state.trail_floors:
		if int(x) == state.floor_num:
			n += 1
	return n * 量

## 这一层的推进剂上限 = 该图最短路（直达） + 余量 + 层修正 + 零件 + 小径（`91-地图.js:274-279`）。
static func propellant_max(state: RunState) -> int:
	var 层 := maxi(1, state.floor_num)
	var base := 0
	if state.map_data.has("最短路"):
		var v := int(state.map_data["最短路"])
		if v > 0:
			base = v
	return base + propellant_remainder(层) + state.layer_prop_bonus + state.part_prop_bonus + trail_bonus(state)

## 这一层的推进剂账（**纯读**，`91-地图.js:288-297`）：
## `{层, 最短路, 基础, 余量, 层修正, 零件, 小径, 上限}`，恒等式
## `上限 = 基础 + 余量 + 层修正 + 零件 + 小径`。
static func propellant_detail(state: RunState) -> Dictionary:
	var 层 := maxi(1, state.floor_num)
	var 基础 := 0
	if state.map_data.has("最短路"):
		var v := int(state.map_data["最短路"])
		if v > 0:
			基础 = v
	var 余量 := propellant_remainder(层)
	var 小径 := trail_bonus(state)
	return {
		"层": 层, "最短路": 基础, "基础": 基础, "余量": 余量,
		"层修正": state.layer_prop_bonus, "零件": state.part_prop_bonus, "小径": 小径,
		"上限": 基础 + 余量 + state.layer_prop_bonus + state.part_prop_bonus + 小径,
	}

# ==========================================================================================
# 四、固定节点个数表（`91-地图.js:538-562` 的 `计划要放()`，逐字）
# ==========================================================================================

static func plan_counts(floor_num: int) -> Dictionary:
	var n := floori(float(floor_num))
	if n <= 1:
		return {"作战": 4, "精英": 1, "侵蚀源": 0, "黑市": 1, "事件": 2, "瞭望站": 2, "空": 2,
			"遗迹": 1, "休整": 0, "招募站": 1, "隧道": 0}
	if n == 2:
		return {"作战": 5, "精英": 1, "侵蚀源": 1, "黑市": 1, "事件": 3, "瞭望站": 3, "空": 3,
			"遗迹": 1, "休整": 1, "招募站": 1, "隧道": 2}
	if n == 3:
		return {"作战": 5, "精英": 1, "侵蚀源": 1, "黑市": 1, "事件": 2, "瞭望站": 2, "空": 3,
			"遗迹": 1, "休整": 1, "招募站": 1, "隧道": 2}
	return {"作战": 6, "精英": 2, "侵蚀源": 2, "黑市": 2, "事件": 3, "瞭望站": 3, "空": 4,
		"遗迹": 2, "休整": 2, "招募站": 2, "隧道": 2}

## 这一层这类节点能用哪些关卡编号（`91-地图.js:305-310`，逐字照抄战棋 31-战斗.js:96-97）。
static func stage_ids(floor_num: int, kind: String) -> Array:
	if kind == "终点":
		return ["ISW-4-F-1"] if floor_num == 4 else []
	if kind == "侵蚀源":
		return ["ISW-%d-S-1" % floor_num, "ISW-%d-S-2" % floor_num] if floor_num >= 2 else []
	var 池: Dictionary = STAGE_POOL_FALLBACK
	var t: Variant = _db_const("关卡池")
	if t is Dictionary:
		池 = t
	var 名表: Dictionary = PHASE_NAME_FALLBACK
	var t2: Variant = _db_const("阶段名")
	if t2 is Dictionary:
		名表 = t2
	var n := int(池.get(kind, 0))
	var out: Array = []
	for i in n:
		out.append("ISW-%d-%s-%d" % [floor_num, String(名表.get(kind, "N")), i + 1])
	return out

# ==========================================================================================
# 五、生成一层（`91-地图.js:325-501`）
# ==========================================================================================

## 生成第 `floor_num` 层、用 `seed_val` 当随机种子。返回地图字典（与黄金样例逐字段一致）；
## 2000 次都失败时返回空字典（JS 抛错；Godot 侧由测试断言非空）。
static func generate_floor(floor_num: int, seed_val: int) -> Dictionary:
	var S := shape(floor_num)
	var cols := int(S["列数"])
	var rows := int(S["行数"])
	var rate := float(S["存在率"])
	var floor_min := int(S["连通下限"])
	var mid_col := (cols - 1) >> 1
	var start_fixed := mid_col
	var plan := plan_counts(floor_num)
	for attempt in MAX_TRIES:
		# 每次尝试的种子：`试 × 104729 + 试 × 试 × 31`（★ 修掉与「种子差 7919」同余的那个 bug）
		var rng := Mulberry32.new((seed_val + attempt * 104729 + attempt * attempt * 31) & 0xFFFFFFFF)
		var present: Dictionary = {}
		for row in rows:
			for col in cols:
				if rng.next_float() < rate:
					present[cell_id(col, row, cols)] = true
		present[start_fixed] = true
		var start := start_fixed
		# (2) 保证「起点 → 最下排中间格」连通（只补一条 L 形走廊，不消耗 rng）
		_ensure_connected(cell_id(mid_col, rows - 1, cols), present, start, cols)
		# (3) 连通性：只留起点所在的连通分量
		var dist := bfs_distances(start, present, cols)
		var cells: Array = dist.keys()
		if cells.size() < floor_min:
			continue
		# (4) 出口尽头 = 最下排里离中间最近的连通格
		var bottom: Array = []
		for k in cells:
			if cell_row(k, cols) == rows - 1:
				bottom.append(k)
		if bottom.is_empty():
			continue
		var exit_end := int(JsCompat.stable_sort(bottom, func(a, b): return _less_mid(a, b, mid_col, cols))[0])
		# (5) 出口小径 = 最右列（退化：最右 2 列）里离尽头 ≥3 步的格
		var exit_trail := _pick_trail(cells, cols, exit_end, dist, present)
		if exit_trail < 0:
			continue
		# (6) 出口守军 = 四级优先（★ 2026-10-13：尽头的四邻接 / 直达最短路上的格）
		var guard := _pick_guard(cells, cols, start, exit_end, exit_trail, dist, present)
		if guard < 0:
			continue
		# (7) 节点安放（试放 + 隧道提前预定）
		var blank: Array = []
		for k in cells:
			if k != start and k != exit_end and k != exit_trail and k != guard:
				blank.append(k)
		shuffle_cells(blank, rng)
		var pre := _pick_tunnel_ends(floor_num, cols, present, blank)
		var T := _trial_place(floor_num, cols, dist, start, exit_end, exit_trail, guard, blank, rng, pre)
		if T.is_empty():
			continue
		for k in cells:
			if not T.has(k):
				T[k] = "空"
		var grid: Dictionary = {}
		for k in cells:
			grid[k] = {"k": k, "列": cell_col(k, cols), "行": cell_row(k, cols), "类型": T[k], "已过": k == start}
		(grid[start] as Dictionary)["类型"] = "空"
		# (8) 关卡编号（按格号顺序轮转指派；第 4 层的出口守军用终点 Boss 关）
		for 类 in ["作战", "精英", "出口守军", "侵蚀源"]:
			var 池: Array = stage_ids(4, "终点") if (类 == "出口守军" and floor_num == 4) \
				else (stage_ids(floor_num, "守军") if 类 == "出口守军" else stage_ids(floor_num, 类))
			if 池.is_empty():
				continue
			var i := 0
			for k in cells:
				if String((grid[k] as Dictionary)["类型"]) == 类:
					(grid[k] as Dictionary)["关卡"] = 池[i % 池.size()]
					i += 1
		var tunnels: Array = []
		for k in cells:
			if String(T[k]) == "隧道":
				tunnels.append(k)
		# (9) 最短路家族（`最短路` = `直达` = 距离.get(出口尽头)）
		var guard_to_end := bfs_distances(guard, present, cols)
		var direct := int(dist.get(exit_end, 0))
		return {
			"列数": cols, "行数": rows, "形状": "正方形", "存在率": rate, "连通下限": floor_min,
			"种子": seed_val, "起点": start, "出口": exit_end, "出口尽头": exit_end,
			"出口小径": exit_trail, "守军": guard, "隧道": tunnels, "格": grid, "试": attempt,
			"最短路": direct,
			"最短路尽头": int(dist.get(guard, 0)) + int(guard_to_end.get(exit_end, 0)),
			"最短路小径": int(dist.get(guard, 0)) + int(guard_to_end.get(exit_trail, 0)),
			"直达": direct,
			"最短路守军": int(dist.get(guard, 0)),
		}
	return {}

## `保证连通(目标)`：从起点分量里挑离目标曼哈顿最近的格，往目标补一条 L 形走廊。
static func _ensure_connected(target: int, present: Dictionary, start: int, cols: int) -> void:
	var comp := bfs_distances(start, present, cols)
	if present.has(target) and comp.has(target):
		return
	var tcol := cell_col(target, cols)
	var trow := cell_row(target, cols)
	var near := start
	var best := 0x7FFFFFFF
	for k in comp.keys():
		var d: int = absi(cell_col(k, cols) - tcol) + absi(cell_row(k, cols) - trow)
		if d < best:
			best = d
			near = k
	var c := cell_col(near, cols)
	var r := cell_row(near, cols)
	while r != trow:
		r += signi(trow - r)
		present[cell_id(c, r, cols)] = true
	while c != tcol:
		c += signi(tcol - c)
		present[cell_id(c, r, cols)] = true
	present[target] = true

## 出口小径的挑选（`91-地图.js:393-408`）：最右列 → 最右 2 列，按 (离尽头的距离, 离起点的距离) 降序。
static func _pick_trail(cells: Array, cols: int, exit_end: int, dist: Dictionary, present: Dictionary) -> int:
	for band in [1, 2]:
		var cand: Array = []
		for k in cells:
			if k != exit_end and cell_col(k, cols) >= cols - band:
				cand.append(k)
		var sorted: Array = JsCompat.stable_sort(cand, func(a, b): return _less_trail(a, b, exit_end, dist, present, cols))
		for k in sorted:
			if far_apart(k, exit_end, present, cols) >= 3:
				return int(k)
	return -1

## 量距（`91-地图.js:397`）：从 a BFS 到 b 的步数；走不到给 −1。
static func far_apart(a: int, b: int, present: Dictionary, cols: int) -> int:
	var d := bfs_distances(a, present, cols)
	if d.has(b):
		return int(d[b])
	return -1

static func _less_mid(a: int, b: int, mid: int, cols: int) -> bool:
	var da: int = absi(cell_col(a, cols) - mid)
	var db: int = absi(cell_col(b, cols) - mid)
	if da != db:
		return da < db
	return a < b

static func _less_trail(a: int, b: int, exit_end: int, dist: Dictionary, present: Dictionary, cols: int) -> bool:
	var c1: int = far_apart(b, exit_end, present, cols) - far_apart(a, exit_end, present, cols)
	if c1 != 0:
		return c1 < 0
	var c2: int = int(dist.get(b, 0)) - int(dist.get(a, 0))
	if c2 != 0:
		return c2 < 0
	return a < b

static func _less_guard(a: int, b: int, exit_end: int, present: Dictionary, cols: int) -> bool:
	var c1: int = far_apart(a, exit_end, present, cols) - far_apart(b, exit_end, present, cols)
	if c1 != 0:
		return c1 < 0
	return a < b

## 出口守军（`91-地图.js:409-450`）：四级优先 → 收费站 → 共同邻格 → 任一出口邻格。
static func _pick_guard(cells: Array, cols: int, start: int, exit_end: int, exit_trail: int,
		dist: Dictionary, present: Dictionary) -> int:
	var to_end := bfs_distances(exit_end, present, cols)
	var direct := int(dist.get(exit_end, 0))
	var must_end := int_key_set(must_pass(present, start, exit_end, cols))
	var must_trail := int_key_set(must_pass(present, start, exit_trail, cols))
	var end_nb := int_key_set(neighbors_of(exit_end, cols))
	var trail_nb := int_key_set(neighbors_of(exit_trail, cols))
	var placeable: Array = []
	for k in cells:
		if k != start and k != exit_end and k != exit_trail:
			placeable.append(k)
	var groups: Array = []
	groups.append(_pick_group(placeable, end_nb, must_end, true, true, true, dist, to_end, direct))
	groups.append(_pick_group(placeable, end_nb, must_end, true, false, true, dist, to_end, direct))
	groups.append(_pick_group(placeable, end_nb, must_end, false, true, true, dist, to_end, direct))
	groups.append(_pick_group(placeable, end_nb, must_end, true, false, false, dist, to_end, direct))
	var pool: Array = []
	for g in groups:
		if not (g as Array).is_empty():
			pool = g
			break
	if not pool.is_empty():
		return int(JsCompat.stable_sort(pool, func(a, b): return _less_guard(a, b, exit_end, present, cols))[0])
	# 兜底 (1)：小径侧的收费站 / 共同邻格（近出口 = 到两个出口的较小值）
	var toll: Array = []
	for k in placeable:
		if (end_nb.has(k) or trail_nb.has(k)) and (must_end.has(k) or must_trail.has(k)):
			toll.append(k)
	if not toll.is_empty():
		var near := func(k: int) -> int:
			return mini(far_apart(k, exit_end, present, cols), far_apart(k, exit_trail, present, cols))
		var sorted: Array = JsCompat.stable_sort(toll, func(a, b):
			var na: int = near.call(a)
			var nb: int = near.call(b)
			if na != nb:
				return na < nb
			return a < b)
		return int(sorted[0])
	# 兜底 (2)：两个出口的共同邻格
	var shared: Array = []
	for k in placeable:
		if end_nb.has(k) and trail_nb.has(k):
			shared.append(k)
	if not shared.is_empty():
		var sv: Array = JsCompat.stable_sort(shared, func(a, b): return a < b)
		return int(sv[0])
	# 兜底 (3)：任一出口的邻格（去重后第一个连通的）
	var merged: Array = []
	for arr in [neighbors_of(exit_end, cols), neighbors_of(exit_trail, cols)]:
		for k in arr:
			if not merged.has(k):
				merged.append(k)
	for k in merged:
		if dist.has(k) and k != exit_end and k != exit_trail:
			return int(k)
	return -1

static func _pick_group(placeable: Array, end_nb: Dictionary, must_end: Dictionary,
		want_end_nb: bool, want_must: bool, want_direct: bool, dist: Dictionary, to_end: Dictionary, direct: int) -> Array:
	var out: Array = []
	for k in placeable:
		if want_end_nb and not end_nb.has(k):
			continue
		if want_must and not must_end.has(k):
			continue
		if want_direct and not _on_direct_path(k, dist, to_end, direct):
			continue
		out.append(k)
	return out

## `在直达路上`：`距离 + 尽到 === 直达步`（`91-地图.js:422`）。
static func _on_direct_path(k: int, dist: Dictionary, to_end: Dictionary, direct: int) -> bool:
	var a: float = float(dist.get(k, INF))
	var b: float = float(to_end.get(k, INF))
	return a + b == float(direct)

## 选隧道两端（`91-地图.js:578-588`）：一端左端两列、一端右端两列，图上距离 ≥2，第 1 层不放。
static func _pick_tunnel_ends(floor_num: int, cols: int, present: Dictionary, blank: Array) -> Array:
	if floor_num < 2:
		return []
	var pool: Array = JsCompat.stable_sort(blank, func(a, b): return a < b)
	if pool.size() < 2:
		return []
	var 甲 := -1
	for k in pool:
		if cell_col(k, cols) <= 1:
			甲 = int(k)
			break
	var 乙 := -1
	for k in pool:
		if cell_col(k, cols) >= cols - 2 and k != 甲:
			乙 = int(k)
			break
	if 甲 < 0 or 乙 < 0:
		return []
	var d := bfs_distances(甲, present, cols)
	if int(d.get(乙, 0)) < 2:
		return []
	return [[甲, "隧道"], [乙, "隧道"]]

## 洗牌（`91-地图.js:505-508`，从后往前换）。
static func shuffle_cells(a: Array, rng: Mulberry32) -> void:
	var i := a.size() - 1
	while i > 0:
		var j := floori(rng.next_float() * float(i + 1))
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
		i -= 1

static func _asc(a: Array) -> Array:
	return JsCompat.stable_sort(a, func(x, y): return int(x) < int(y))

## 试放（`91-地图.js:606-687`）：能按「固定个数」放满返回 Map(格号 → 类型)，放不下返回空字典。
static func _trial_place(floor_num: int, cols: int, dist: Dictionary, start: int, exit_end: int,
		exit_trail: int, guard: int, blank: Array, rng: Mulberry32, pre: Array) -> Dictionary:
	var T: Dictionary = {start: "起点", exit_end: "出口尽头", exit_trail: "出口小径", guard: "出口守军"}
	var present: Dictionary = {}
	for k in dist.keys():
		present[k] = true
	var plan := plan_counts(floor_num)
	var dead := _asc(blank.filter(func(k): return is_dead_end(k, present, cols)))
	var dead_set := int_key_set(dead)
	var nondead := _asc(blank.filter(func(k): return not dead_set.has(k)))
	var arts := articulation_points(present, cols)
	var trunk := _asc(blank.filter(func(k): return _degree(k, present, cols) >= 3 or arts.has(k)))
	var branch := _asc(blank.filter(func(k): return _degree(k, present, cols) <= 2))
	var far3 := _asc(blank.filter(func(k): return int(dist.get(k, 0)) >= 3))
	var pick := func(类型: String, 个数: int, 池: Array) -> bool:
		var 用 := _asc(池)
		for i in 个数:
			var 落 := -1
			for x in 用:
				if not T.has(x):
					落 = int(x)
					break
			if 落 < 0:
				return false
			T[落] = 类型
		return true
	for pair in pre:
		var pair_arr: Array = pair
		if not T.has(int(pair_arr[0])):
			T[int(pair_arr[0])] = String(pair_arr[1])
	var combat_pool := func() -> Array:
		var 优 := _asc(trunk.filter(func(k): return arts.has(k)))
		if not 优.is_empty():
			var rest := trunk.filter(func(k): return not arts.has(k))
			return 优 + rest
		return trunk
	var gain_pool := func() -> Array:
		if not dead.is_empty():
			return dead + branch.filter(func(k): return not dead_set.has(k))
		return branch
	var 遗迹池 := func() -> Array:
		if not dead.is_empty():
			return dead
		if not branch.is_empty():
			return branch
		return JsCompat.stable_sort(_asc(blank), func(a, b):
			var da := int(dist.get(a, 0))
			var db := int(dist.get(b, 0))
			if da != db:
				return da < db
			return a < b)
	var bones: Array = [
		func() -> bool: return pick.call("遗迹", int(plan["遗迹"]), 遗迹池.call()),
		func() -> bool: return true,
		func() -> bool:
			var cp: Array = combat_pool.call()
			var 池: Array = cp if cp.size() >= int(plan["作战"]) else (nondead if nondead.size() >= int(plan["作战"]) else blank)
			return pick.call("作战", int(plan["作战"]), 池),
		func() -> bool:
			if floor_num < 2:
				return true
			return pick.call("侵蚀源", int(plan["侵蚀源"]), far3),
		func() -> bool: return pick.call("精英", int(plan["精英"]), far3),
		func() -> bool: return pick.call("黑市", int(plan["黑市"]), gain_pool.call()),
		func() -> bool: return pick.call("事件", int(plan["事件"]), gain_pool.call()),
		func() -> bool: return pick.call("瞭望站", int(plan["瞭望站"]), gain_pool.call()),
		func() -> bool:
			if floor_num < 2:
				return true
			return pick.call("休整", int(plan["休整"]), gain_pool.call()),
		func() -> bool: return pick.call("招募站", int(plan["招募站"]), gain_pool.call()),
	]
	var order: Array = []
	for i in bones.size():
		order.append(i)
	shuffle_cells(order, rng)
	for i in order:
		var f: Callable = bones[int(i)]
		if not bool(f.call()):
			return {}
	var free_cells := func() -> Array:
		return _asc(blank.filter(func(k): return not T.has(k)))
	pick.call("空", int(plan["空"]), free_cells.call())   # 「空」不够也没关系：剩下的最后都补成空节点
	return T

static func _degree(k: int, present: Dictionary, cols: int) -> int:
	var n := 0
	for x in neighbors_of(k, cols):
		if present.has(x):
			n += 1
	return n
