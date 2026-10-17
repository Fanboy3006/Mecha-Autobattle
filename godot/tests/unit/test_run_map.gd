## Stage M3-Core-A 单元测试：大地图生成 / 导航 / 零件（原生 Godot，零 `J.*`）。
##   ① 对拍 `tests/golden/run_vectors.json` 的「地图」32 张（8 种子 × 4 层）**逐字段相等**；
##   ② 对拍「推进剂」账（上限 = 最短路 + 余量 + 层修正 + 零件 + 小径）与「推进剂明细」4 层；
##   ③ 地图几何自洽（独立 BFS 复核 起点 / 出口 / 守军 / 最短路家族 / 每格的列行邻距离）；
##   ④ 移动、跳格、林间空地扣费与标记、退路成本预告（纯读）；
##   ⑤ 推进剂归零 → 追击打赢 → 下一层上限 −2（**无推进剂恢复**，★ D-02 口径 C）；
##   ⑥ 出口追击守军闸拦截 / 守军打赢放行 / 出口小径免守军 + 下一层上限 +2（★ 口径 D / E）/ 第 4 层通关；
##   ⑦ 13 件零件（按《黑流树海》原版规格）：数据表 / 目标格 / 位移 / 跨层损坏 / 抽取 / 买卖折算
##      —— 任务单 §5 的 8 组核心验收断言：① 直线不拐弯 ② 无视断路空格 ③ 推进剂消耗与 0 推进剂禁则
##      ④ 跨层损坏 ⑤ 触须迷雾限制 ⑥ 融雪与小八界 ⑦ 血蕈浪花与黑市售价 ⑧ `weight_by_rarity` 接口。
extends RefCounted

const 种子们 := [20261010, 20261011, 20261012, 20261013, 20261014, 20261015, 20261016, 20261017]
## ★ 2026-10-17：`rite` 河谷祭祈改为 `用: false` 被动常驻 → 主动可点击件从 11 件降为 **10 件**。
const 主动零件 := ["wheel", "limb", "hover", "exo", "engine", "spring", "jet", "bagua", "thaw", "tentacle"]

var _地图缓存: Dictionary = {}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	_对拍地图(t)
	_对拍推进剂(t)
	_地图几何自洽(t)
	_移动与跳格(t)
	_退路成本(t)
	_追击与换层(t)
	_守军闸与小径(t)
	_零件数据(t)
	_零件目标与位移(t)
	_零件跨层与抽取(t)
	_零件买卖(t)

# ==========================================================================================
# ① 地图对拍
# ==========================================================================================

func _地图(种子: int, 层: int) -> Dictionary:
	var 键 := "%d_%d" % [种子, 层]
	if not _地图缓存.has(键):
		_地图缓存[键] = MapGenerator.generate_floor(层, MapGenerator.map_seed(种子, 层))
	return _地图缓存[键]

## 把字典里的键递归改成字符串 —— 生成出来的图用 int 键，黄金样例（JSON）用字符串键；
## 统一成字符串再比，`GoldenCompare.diff` 就不用走 `String(整数键)` 那条路（那条路会报
## 「Nonexistent 'String' constructor」的运行时错误，比对结果也就不再可信）。
func _串键(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		var o := {}
		for k in d.keys():
			o[str(k)] = _串键(d[k])
		return o
	if v is Array:
		var a: Array = v
		var out := []
		for x in a:
			out.append(_串键(x))
		return out
	return v

func _对拍地图(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 块: Array = data.get("地图", [])
	t.ok(块.size() == 32, "黄金样例「地图」32 张 = 8 种子 × 4 层")
	var 坏 := 0
	var 首错 := ""
	var 有图 := 0
	for raw in 块:
		var m: Dictionary = GoldenCompare.decode(raw)
		var 层 := int(m["层"])
		var 种子 := int(m["种子"])
		if int(m["地图种子"]) != MapGenerator.map_seed(种子, 层):
			坏 += 1
			if 首错.is_empty():
				首错 = "种子 %d 第 %d 层：地图种子 %d ≠ %d" % [种子, 层, int(m["地图种子"]), MapGenerator.map_seed(种子, 层)]
		var 图 := _地图(种子, 层)
		if 图.is_empty():
			坏 += 1
			if 首错.is_empty():
				首错 = "种子 %d 第 %d 层：生成失败（2000 次重试用完）" % [种子, 层]
			continue
		有图 += 1
		var d1 := GoldenCompare.diff(m["形状"], MapGenerator.shape(层), "形状")
		var d2 := GoldenCompare.diff(m["地图"], _串键(图), "种子 %d 第 %d 层 地图" % [种子, 层])
		if d1 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d1
		if d2 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d2
	t.ok(坏 == 0 and 有图 == 32, "32 张地图逐字段对齐（列数/形状/存在率/连通下限/起点/两个出口/守军/隧道/每格类型与已过/关卡编号/最短路家族/试了几次）：%s"
		% ("全对" if 坏 == 0 else "有 %d 处分叉（%d 张生成成功），首处：%s" % [坏, 有图, 首错]))

	# ★ 自检：**故意改一个格子**，确认这套逐字段比对真的抓得到差异（不是空比对）
	var m0: Dictionary = GoldenCompare.decode(块[0])
	var 真图 := _地图(int(m0["种子"]), int(m0["层"]))
	var 坏图: Dictionary = _串键(真图)
	(坏图["格"] as Dictionary)[str(int(真图["起点"]))]["类型"] = "遗迹"
	var 自检1 := GoldenCompare.diff(m0["地图"], 坏图, "自检·格子类型")
	var 坏图2: Dictionary = _串键(真图)
	坏图2["最短路"] = int(真图["最短路"]) + 1
	var 自检2 := GoldenCompare.diff(m0["地图"], 坏图2, "自检·最短路")
	(坏图2["格"] as Dictionary).erase(str(int(真图["守军"])))
	var 自检3 := GoldenCompare.diff(m0["地图"], 坏图2, "自检·少一个格")
	t.ok(自检1 != "" and 自检2 != "" and 自检3 != "",
		"对拍自检：改格子类型 / 改最短路 / 删一个格 都能被抓到（比对器不是空的）")

func _对拍推进剂(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 块: Array = data.get("地图", [])
	var 坏 := 0
	var 首错 := ""
	for raw in 块:
		var m: Dictionary = GoldenCompare.decode(raw)
		var 层 := int(m["层"])
		var 种子 := int(m["种子"])
		var s := RunState.new()
		s.seed_val = 种子
		s.floor_num = 层
		s.map_data = _地图(种子, 层)
		var 期望: Dictionary = m["推进剂"]
		var 上 := MapGenerator.propellant_max(s)
		var 账 := MapGenerator.propellant_detail(s)
		var d1 := GoldenCompare.diff(期望["上限"], 上, "上限")
		var d2 := GoldenCompare.diff(期望["账"], 账, "第 %d 层 推进剂账" % 层)
		# 走一遍真入口：`enter_floor`（换地图 → 起点 → 重算推进剂）
		var s2 := RunState.new()
		s2.seed_val = 种子
		MapNavigator.enter_floor(s2, 层)
		var d3 := GoldenCompare.diff(期望["进层后实发"], s2.propellant, "进层后实发")
		var d4 := GoldenCompare.diff(期望["上限"], s2.propellant_max, "进层后上限")
		for d in [d1, d2, d3, d4]:
			if d != "":
				坏 += 1
				if 首错.is_empty():
					首错 = "种子 %d 第 %d 层 %s" % [种子, 层, d]
	t.ok(坏 == 0, "32 条推进剂账逐字段对齐（上限 = 最短路 + 余量 + 层修正 + 零件 + 小径；进层实发 = 上限）：%s"
		% ("全对" if 坏 == 0 else "有 %d 处分叉，首处：%s" % [坏, 首错]))

	# 推进剂明细（逐层的静态口径：2 / 2 / 4 / 4，恒偶数）
	var 明细: Array = data.get("推进剂明细", [])
	var 明细坏 := 0
	var 明细首错 := ""
	for raw2 in 明细:
		var e: Dictionary = GoldenCompare.decode(raw2)
		var d := GoldenCompare.diff(e, MapGenerator.remainder_detail(int(e["层"])), "推进剂明细[%s]" % str(e["层"]))
		if d != "":
			明细坏 += 1
			if 明细首错.is_empty():
				明细首错 = d
	t.ok(明细.size() == 4 and 明细坏 == 0, "推进剂明细 4 层对齐（余量表 = 余量、恒偶数）%s"
		% ("" if 明细坏 == 0 else "，首处：%s" % 明细首错))
	t.ok(MapGenerator.propellant_remainder(1) == 2 and MapGenerator.propellant_remainder(2) == 2
		and MapGenerator.propellant_remainder(3) == 4 and MapGenerator.propellant_remainder(4) == 4
		and MapGenerator.remainder_is_even(1) and MapGenerator.remainder_is_even(4),
		"余量表 = {1:2, 2:2, 3:4, 4:4} 且恒偶数（★ D-02 口径 A）")

# ==========================================================================================
# ③ 几何自洽（独立 BFS 复核，不借 MapGenerator 的 BFS）
# ==========================================================================================

func _独立BFS(格: Dictionary, 起点: int, 列数: int) -> Dictionary:
	var d: Dictionary = {起点: 0}
	var q: Array = [起点]
	var head := 0
	while head < q.size():
		var k: int = int(q[head])
		head += 1
		var c := k % 列数
		var r := int(k / 列数)
		var ns: Array = []
		if c > 0:
			ns.append(k - 1)
		if c < 列数 - 1:
			ns.append(k + 1)
		if r > 0:
			ns.append(k - 列数)
		if r < 列数 - 1:
			ns.append(k + 列数)
		for n in ns:
			if 格.has(n) and not d.has(n):
				d[n] = int(d[k]) + 1
				q.append(n)
	return d

func _地图几何自洽(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 块: Array = data.get("地图", [])
	var 坏 := 0
	var 首错 := ""
	for raw in 块:
		var m: Dictionary = GoldenCompare.decode(raw)
		var 层 := int(m["层"])
		var 种子 := int(m["种子"])
		var 图: Dictionary = _地图(种子, 层)
		if 图.is_empty():
			continue
		var 列数 := int(图["列数"])
		var 行数 := int(图["行数"])
		var 格原: Dictionary = 图["格"]
		var 格: Dictionary = {}
		for k in 格原.keys():
			格[int(k)] = 格原[k]
		var 起点 := int(图["起点"])
		var 尽头 := int(图["出口尽头"])
		var 小径 := int(图["出口小径"])
		var 守军 := int(图["守军"])
		var 距离 := _独立BFS(格, 起点, 列数)
		var 守距 := _独立BFS(格, 守军, 列数)
		var 形状 := MapGenerator.shape(层)
		var 问题 := ""
		if 列数 != 行数 or String(图["形状"]) != "正方形":
			问题 = "不是正方形"
		elif float(图["存在率"]) != float(形状["存在率"]) or int(图["连通下限"]) != int(形状["连通下限"]):
			问题 = "形状参数与形状表不符"
		elif 距离.size() != 格.size():
			问题 = "有走不到的格（连通分量不唯一）"
		elif 起点 != ((列数 - 1) >> 1):
			问题 = "起点不是最上排中间格"
		elif int(图["最短路"]) != int(距离[尽头]) or int(图["直达"]) != int(图["最短路"]):
			问题 = "最短路 ≠ 起点→出口尽头的直达步数"
		elif int(图["最短路守军"]) != int(距离[守军]):
			问题 = "最短路守军 ≠ 起点→守军步数"
		elif int(图["最短路尽头"]) != int(距离[守军]) + int(守距[尽头]):
			问题 = "最短路尽头 ≠ 起点→守军→尽头"
		elif int(图["最短路小径"]) != int(距离[守军]) + int(守距[小径]):
			问题 = "最短路小径 ≠ 起点→守军→小径"
		elif int(格[尽头]["行"]) != 行数 - 1:
			问题 = "出口尽头不在最下排"
		elif int(格[小径]["列"]) < 列数 - 2:
			问题 = "出口小径不在最右列 / 最右 2 列"
		elif not (absi(int(格[守军]["列"]) - int(格[尽头]["列"])) + absi(int(格[守军]["行"]) - int(格[尽头]["行"])) == 1):
			问题 = "守军不是出口尽头的四邻接格"
		elif MapGenerator.far_apart(小径, 尽头, MapGenerator.int_key_set(格), 列数) < 3:
			问题 = "两个出口的图上距离 < 3"
		else:
			for k in 格.keys():
				var cell: Dictionary = 格[k]
				if int(cell["k"]) != k or int(cell["列"]) != k % 列数 or int(cell["行"]) != int(k / 列数):
					问题 = "第 %d 格的 列/行/k 不自洽" % k
					break
				if bool(cell["已过"]) != (k == 起点):
					问题 = "第 %d 格的 已过 不对（只有起点是 true）" % k
					break
				for n in MapGenerator.neighbors_of(k, 列数):
					if 距离.has(n) and 距离.has(k) and absi(int(距离[n]) - int(距离[k])) != 1:
						问题 = "第 %d 格与邻居 %d 的 BFS 距离不是差 1" % [k, n]
						break
				if 问题 != "":
					break
		if 问题 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = "种子 %d 第 %d 层：%s" % [种子, 层, 问题]
	t.ok(坏 == 0, "32 张地图几何自洽（独立 BFS 复核：连通 / 起点位置 / 出口尽头在最下排 / 小径在最右列 / 守军贴尽头 / 出口拉开 ≥3 / 最短路家族 / 每格列行邻距离）：%s"
		% ("全对" if 坏 == 0 else "有 %d 处分叉，首处：%s" % [坏, 首错]))

# ==========================================================================================
# ④ 移动 / 跳格 / 林间空地
# ==========================================================================================

## 一张 5×5 全格合成图（可控、可读）：起点 (0,0)、出口尽头 (2,2)、守军 (2,3)、
## 出口小径 (3,4)、黑市 (0,2)、作战 (1,0)、事件 (1,1)、遗迹 (2,4)。
func _合成图(含隧道: bool = false) -> Dictionary:
	var 列数 := 5
	var 类型 := {2: "黑市", 5: "作战", 6: "事件", 12: "出口尽头", 13: "出口守军", 14: "遗迹", 19: "出口小径"}
	if 含隧道:
		类型[4] = "隧道"
		类型[20] = "隧道"
	var 格: Dictionary = {}
	for row in 列数:
		for col in 列数:
			var k := row * 列数 + col
			格[k] = {"k": k, "列": col, "行": row, "类型": String(类型.get(k, "空")), "已过": k == 0}
	(格[0] as Dictionary)["类型"] = "空"
	return {
		"列数": 列数, "行数": 列数, "形状": "正方形", "存在率": 0.78, "连通下限": 17,
		"种子": 1, "起点": 0, "出口": 12, "出口尽头": 12, "出口小径": 19, "守军": 13,
		"隧道": ([4, 20] if 含隧道 else []), "格": 格, "试": 0,
		"最短路": 4, "最短路尽头": 4, "最短路小径": 7, "直达": 4, "最短路守军": 3,
	}

func _新局(图: Dictionary) -> RunState:
	var s := RunState.new()
	s.seed_val = 20261010
	s.floor_num = 1
	s.map_data = 图
	s.node_id = int(图["起点"])
	s.visited_cells = [s.node_id]
	s.propellant = MapGenerator.propellant_max(s)
	s.propellant_max = s.propellant
	return s

## 给一件零件验「门面口径」用的一次性会话：手上就是这个 `RunState`，停在大地图屏。
## （`GameSession.part_can_use_now()` 只读 `run_state` / `screen`，不碰表现层。）
func _会话(s: RunState) -> GameSession:
	var g := GameSession.new()
	g.run_state = s
	g.screen = "map"
	return g

func _移动与跳格(t) -> void:
	var 图 := _合成图()
	var s := _新局(图)
	t.ok(s.propellant == 6, "合成图第 1 层推进剂上限 = 最短路 4 + 余量 2 + 层修正 0 = %d" % s.propellant)

	# 相邻 1 格
	var c1 := MapNavigator.can_move_to(s, 1)
	t.ok(bool(c1["ok"]) and int(c1["cost"]) == 1 and (c1["path"] as Array) == [0, 1], "相邻移动：ok、扣 1 点、路径 [0,1]")
	# 跳格（按 BFS 最短路扣 d 点）
	var c2 := MapNavigator.can_move_to(s, 12)
	t.ok(bool(c2["ok"]) and int(c2["cost"]) == 4 and (c2["path"] as Array).size() == 5, "跳格：到出口尽头扣 4 点、路径 5 格（含两端）")
	t.ok(not bool(MapNavigator.can_move_to(s, 0)["ok"]), "目标 = 当前格 → 走不了")
	t.ok(not bool(MapNavigator.can_move_to(s, 99)["ok"]), "不存在的格 → 走不了")

	# 推进剂不够 → 走不了
	s.propellant = 2
	t.ok(not bool(MapNavigator.can_move_to(s, 12)["ok"]), "推进剂 2 < 4：跳格走到出口尽头被拒（BFS 深度上限 = 推进剂）")
	t.ok(MapNavigator.reachable_cells(s).size() > 0, "推进剂 2 仍然有能去的格")

	# 林间空地：未走过的「空」格 → 照常扣费 + 当场标已过 + 结果条
	s.propellant = 6
	var r1 := MapNavigator.move_to(s, 1)
	t.ok(bool(r1["ok"]) and int(r1["距离"]) == 1 and s.propellant == 5, "落到空地：照常扣 1 点推进剂（★ D-02 口径 B）")
	t.ok(bool(r1["空格落脚"]) and String(r1["提示"]) == MapNavigator.林间空地提示,
		"未走过的空地 → 空格落脚 + 结果条「%s」（不弹模态框）" % MapNavigator.林间空地提示)
	t.ok(bool(s.cell_at(1)["已过"]), "林间空地当场标 `已过 = true`")
	t.ok(s.is_visited(1) and s.visited_cells == [0, 1], "走过列表 = [起点, 空地]")

	# 已标过的空地再落上去 → 不再触发
	var r2 := MapNavigator.move_to(s, 2)
	t.ok(bool(r2["ok"]) and String(r2["类型"]) == "黑市" and not bool(r2["空格落脚"]), "非空节点不算林间空地")
	var 图2 := _合成图()
	(图2["格"] as Dictionary)[7]["已过"] = true
	var s2 := _新局(图2)
	var r3 := MapNavigator.move_to(s2, 7)
	t.ok(bool(r3["ok"]) and bool(r3["已过"]) and not bool(r3["空格落脚"]), "已经标过 `已过` 的空地：走上去了但不再触发林间空地")

	# 跳格：中间格不落脚、不进走过列表
	var s3 := _新局(_合成图())
	var r4 := MapNavigator.move_to(s3, 11)
	t.ok(bool(r4["ok"]) and int(r4["距离"]) == 3 and s3.propellant == 3, "跳格 3 步：一次扣 3 点推进剂（6 → %d）" % s3.propellant)
	t.ok(s3.node_id == 11 and s3.visited_cells == [0, 11], "跳格的中间格（1/6）不进走过列表")
	t.ok(not bool(s3.cell_at(1)["已过"]) and not bool(s3.cell_at(6)["已过"]), "跳格的中间格不触发结算（不标已过）")

	# 能去的格：滤掉走过 / 已过 / 当前
	var 能去 := MapNavigator.reachable_cells(s2)
	t.ok(not 能去.has(0) and not 能去.has(7), "能去的格不含起点（已过）与已经落脚过的格")

	# 推进剂 0 → 一个都去不了 + 追击标记
	var s4 := _新局(_合成图())
	s4.propellant = 0
	t.ok(MapNavigator.reachable_cells(s4).is_empty(), "推进剂 0 → 能去的格为空")
	t.ok(not bool(MapNavigator.can_move_to(s4, 1)["ok"]), "推进剂 0 → 走不动")
	s4.propellant = 1
	var r5 := MapNavigator.move_to(s4, 5)
	t.ok(bool(r5["ok"]) and bool(r5["追击"]) and s4.propellant == 0, "走完最后 1 点推进剂 → 结果里 `追击 = true`")
	t.ok(MapNavigator.exit_chase_pending(s4), "推进剂 0 且本层没追击过 → 该打追击战")

	# 废弃隧道两端互通
	var s5 := _新局(_合成图(true))
	s5.node_id = 4
	s5.mark_visited(4)
	s5.propellant = 3
	var c3 := MapNavigator.can_move_to(s5, 20)
	t.ok(bool(c3["ok"]) and int(c3["cost"]) == 1 and bool(c3["隧道"]), "废弃隧道：两端互通、只花 1 点（照抄「行动力只在进入时被消耗」）")
	var r6 := MapNavigator.move_to(s5, 20)
	t.ok(bool(r6["ok"]) and s5.node_id == 20 and s5.propellant == 2, "穿隧道：推进剂 3 → 2")
	t.ok(s5.is_revealed(20), "穿隧道顺手揭开落点")
	t.ok(int(MapNavigator.tunnel_other_end(s5)) == 4, "隧道另一头 = 对面的那一端")

# ==========================================================================================
# ⑤ 退路成本预告（A4，纯读）
# ==========================================================================================

func _退路成本(t) -> void:
	var 图 := _合成图()
	var s := _新局(图)
	var 前 := s.to_dict()
	var p := MapNavigator.retreat_cost_preview(s, 0)
	t.ok(bool(p["ok"]) and int(p["退路成本"]) == 1, "起点（度 2、非割点）→ 退路成本 1 步（最近的干路格是邻居）")
	var p2 := MapNavigator.retreat_cost_preview(s, 6)
	t.ok(int(p2["退路成本"]) == 0 and bool(p2["是干路"]) and int(p2["度数"]) == 4, "格 (1,1)：度 4 是干路 → 退路成本 0")
	var p3 := MapNavigator.retreat_cost_preview(s, 12)
	t.ok(int(p3["退路成本"]) == 0, "出口尽头本身是干路 → 退路成本 0")
	t.ok(not bool(MapNavigator.retreat_cost_preview(s, 99)["ok"]), "不存在的格 → 预告 ok = false")
	var d := GoldenCompare.diff(_串键(前), _串键(s.to_dict()), "退路成本预告之后")
	t.ok(d == "", "退路成本预告是**纯读**（连算 3 次之后 `to_dict()` 逐字段不变）%s" % ("" if d == "" else "：" + d))

# ==========================================================================================
# ⑥ 追击 → 下一层上限 −2（★ D-02 口径 C）
# ==========================================================================================

func _追击与换层(t) -> void:
	var s := RunState.new()
	s.seed_val = 20261010
	MapNavigator.enter_floor(s, 1)
	t.ok(s.floor_num == 1 and s.propellant == MapGenerator.propellant_max(s), "进第 1 层：推进剂 = 上限 = %d" % s.propellant)
	t.ok(s.node_id == int(s.map_data["起点"]) and s.visited_cells == [s.node_id], "进层落在起点、走过列表只有起点")
	var 上限1 := s.propellant
	s.propellant = 0
	var r := MapNavigator.after_chase_win(s)
	t.ok(s.layer_prop_bonus == -2, "追击打赢：`层推进剂修正 = -2`（★ 口径 C：没有推进剂恢复）")
	t.ok(bool(r["ok"]) and bool(r["换层"]) and s.floor_num == 2, "追击打赢 → 直接换到第 2 层（第 %d 层，从 %d）" % [s.floor_num, 1])
	var 上2 := MapGenerator.propellant_max(s)
	t.ok(上2 == int(s.map_data["最短路"]) + MapGenerator.propellant_remainder(2) - 2,
		"第 2 层上限 = 该图最短路 %d + 余量 %d − 2 = %d（追击的惩罚落在下一层）" % [
			int(s.map_data["最短路"]), MapGenerator.propellant_remainder(2), 上2])
	t.ok(s.propellant == 上2 and s.propellant_max == 上2, "进层实发 = 上限（没有额外恢复推进剂）")
	t.ok(s.chased == false, "进新层清掉 `chased` 标记（−2 留在 `层推进剂修正` 上）")
	t.ok(上限1 > 0, "第 1 层上限正常（%d）" % 上限1)

# ==========================================================================================
# ⑦ 守军闸 / 小径 / 通关（★ D-02 口径 D / E）
# ==========================================================================================

func _走到(s: RunState, k: int) -> void:
	s.node_id = k
	s.mark_visited(k)

func _守军闸与小径(t) -> void:
	# ① 出口尽头 + 出口那一步的追击战 + 守军没清 → 拦截
	var s := RunState.new()
	s.seed_val = 20261010
	MapNavigator.enter_floor(s, 1)
	_走到(s, int(s.map_data["出口尽头"]))
	s.propellant = 0
	MapNavigator.begin_exit_chase(s)
	t.ok(not MapNavigator.is_guard_cleared(s), "第 1 层出口守军还没清")
	t.ok(MapNavigator.exit_requires_guard("尽头") and not MapNavigator.exit_requires_guard("小径"),
		"出口尽头要守军、出口小径免守军（判据只有一处）")
	var r := MapNavigator.advance_floor(s)
	t.ok(not bool(r["ok"]) and not bool(r["换层"]) and s.floor_num == 1, "出口尽头 + 守军没清 → 拦下换层（★ 口径 D）")
	t.ok(s.pending_floor_change is Dictionary and int(s.pending_floor_change["层"]) == 1 and bool(s.pending_floor_change["追击"]),
		"拦下这一趟记进 `待换层 = {层: 1, 追击: true}`")

	# ② 守军打赢 → 当场补上欠的换层
	var r2 := MapNavigator.after_guard_win(s)
	t.ok(MapNavigator.is_guard_cleared(s) or s.floor_num == 2, "打赢守军 → 守军格清空")
	t.ok(bool(r2["ok"]) and bool(r2["换层"]) and s.floor_num == 2, "打赢守军 → 当场补上第 1 层那次没走成的换层（进第 2 层）")
	t.ok(s.pending_floor_change == null, "补完之后 `待换层` 清空")

	# ③ 出口小径：免守军 + 下一层上限 +2
	var s2 := RunState.new()
	s2.seed_val = 20261010
	MapNavigator.enter_floor(s2, 1)
	_走到(s2, int(s2.map_data["出口小径"]))
	s2.propellant = 0
	MapNavigator.begin_exit_chase(s2)
	t.ok(not MapNavigator.is_guard_cleared(s2), "走小径时守军一样没清")
	t.ok(MapNavigator.current_exit_kind(s2) == "小径", "脚下是出口小径 → 本层出口类型 = 小径")
	var r3 := MapNavigator.advance_floor(s2)
	t.ok(bool(r3["ok"]) and bool(r3["换层"]) and s2.floor_num == 2, "出口小径免打守军：守着没清也照样换层（★ 口径 D）")
	t.ok(s2.trail_floors.has(2), "走小径把**下一层**（第 2 层）记进 `层出口小径`")
	var 上2 := MapGenerator.propellant_max(s2)
	t.ok(上2 == int(s2.map_data["最短路"]) + MapGenerator.propellant_remainder(2) + 2,
		"第 2 层上限 = 最短路 %d + 余量 %d + 小径 2 = %d（★ 口径 E：+2 加在下一层）" % [
			int(s2.map_data["最短路"]), MapGenerator.propellant_remainder(2), 上2])
	t.ok(s2.propellant == 上2, "进层实发 = 带上小径加成的上限")
	t.ok(int(MapGenerator.propellant_detail(s2)["小径"]) == 2, "推进剂账里「小径」那一项 = 2")

	# ④ 尽头：剩余推进剂换希望（率 0.5）
	var s3 := RunState.new()
	s3.seed_val = 20261010
	MapNavigator.enter_floor(s3, 1)
	_走到(s3, int(s3.map_data["出口尽头"]))
	var 守 := s3.cell_at(int(s3.map_data["守军"]))
	守["已过"] = true
	s3.propellant = 5
	var 希望前 := s3.hope
	var r4 := MapNavigator.advance_floor(s3)
	t.ok(bool(r4["ok"]) and s3.floor_num == 2, "守军已清 + 正常换层 → 进第 2 层")
	t.ok(s3.hope == 希望前 + 2 and s3.propellant == MapGenerator.propellant_max(s3),
		"出口尽头：剩余推进剂 5 × 0.5 → 希望 +2（%d → %d）" % [希望前, s3.hope])
	t.ok(not s3.trail_floors.has(2), "走尽头**不**给下一层小径加成")

	# ⑤ 第 4 层通过 → 通关
	var s4 := RunState.new()
	s4.seed_val = 20261010
	MapNavigator.enter_floor(s4, 4)
	_走到(s4, int(s4.map_data["出口尽头"]))
	(s4.cell_at(int(s4.map_data["守军"])) as Dictionary)["已过"] = true
	var r5 := MapNavigator.advance_floor(s4)
	t.ok(bool(r5["通关"]) and s4.status == "胜利" and s4.floor_num == 4, "第 4 层走出出口 → `status = 胜利`（不再进第 5 层）")

	# ⑥ 选出口 / 出口类型判据
	var s5 := RunState.new()
	s5.seed_val = 20261010
	MapNavigator.enter_floor(s5, 1)
	t.ok(MapNavigator.current_exit_kind(s5) == "", "站在起点：本层出口类型认不出来（按「要守军」算，保守）")
	t.ok(MapGenerator.exit_kinds()["出口尽头"] == "尽头" and MapGenerator.exit_kinds()["出口小径"] == "小径", "出口类型表 = 尽头 / 小径")

# ==========================================================================================
# ⑧ 零件：数据表（对齐《黑流树海》原版 —— 13 件里主动可点击的 10 件）
# ==========================================================================================

func _零件数据(t) -> void:
	var 表 := PartSystem.part_table()
	t.ok(表.size() == 13, "零件表 13 件")
	t.ok(PartSystem.active_part_ids().size() == 10,
		"主动可点击的零件 = **10 件**（`用: true`；`rite` 河谷祭祈改为被动常驻）")
	var 缺 := []
	for k in 主动零件:
		if not 表.has(k):
			缺.append(k)
		elif not bool(PartSystem.part_info(k).get("用", false)):
			缺.append(k + "(用:false)")
	t.ok(缺.is_empty(), "10 件主动零件齐全：%s" % ", ".join(主动零件))
	t.ok(not bool(PartSystem.part_info("rite").get("用", true)),
		"rite 河谷祭祈 = 被动常驻（数据表 `用: false`，不在 10 件主动件里）")
	t.ok(PartSystem.tradable_part_ids().size() == 13,
		"买卖池 13 件 = 10 件主动件 + 两件理财自然物 + `rite`（`用: false` 但 `可买: true`）")

	# ---- 10 件加工品逐件对齐原版规格 ----
	# 每条 = [名, 类, 次数, range 算子, 价, rarity, free, breakOnNextFloor, 用]
	var 规格 := {
		"wheel": ["报废轮子", "加工品", 1, "line2", 2, "low", false, false, true],
		"limb": ["报废假肢", "加工品", 1, "adj8", 2, "low", false, false, true],
		"hover": ["气垫底座", "加工品", 2, "ring12", 4, "mid", false, false, true],
		"exo": ["试作外骨骼", "加工品", 2, "line3", 4, "mid", false, false, true],
		"engine": ["标准引擎", "加工品", 3, "adj8", 4, "mid", false, false, true],
		"spring": ["重弹簧", "加工品", 1, "ring12", 6, "mid", true, true, true],
		"jet": ["一次性喷气背包", "加工品", 1, "any", 8, "mid", true, false, true],
		"bagua": ["小八界", "加工品", 1, "bagua", 4, "low", true, true, true],
		"thaw": ["老妈的融雪", "加工品", 1, "thaw", 8, "high", false, false, true],
		"tentacle": ["坎诺特的触须", "加工品", 2, "tentacle", 12, "high", false, false, true],
	}
	var 坏 := []
	for k in 规格.keys():
		var 期望: Array = 规格[k]
		var P := PartSystem.part_info(k)
		var 实 := [String(P.get("名", "")), String(P.get("类", "")), int(P.get("次数", -1)),
			PartSystem.part_range(k), int(P.get("价", -1)), PartSystem.part_rarity(k),
			PartSystem.part_is_free(k), PartSystem.part_breaks_on_next_floor(k),
			bool(P.get("用", false))]
		if 实 != 期望:
			坏.append("%s：期望 %s 实际 %s" % [k, str(期望), str(实)])
	t.ok(坏.is_empty(), "10 件加工品的 range / 次数 / 价 / rarity / free / 跨层损坏 逐件对齐原版规格%s"
		% ("" if 坏.is_empty() else "：" + "；".join(坏)))
	t.ok(PartSystem.part_range("wheel") == "line2" and PartSystem.part_range("exo") == "line3"
		and String(PartSystem.part_info("wheel").get("range", "")) == "line(2)"
		and String(PartSystem.part_info("exo").get("range", "")) == "line(3)",
		"line(n) 归一化：表里 `range: \"line(2)\"` / `\"line(3)\"` → 算子 line2 / line3（也兼容旧的 `移动` 字段）")

	var 概 := PartSystem.part_info("rite")
	t.ok(String(概.get("名")) == "河谷祭祈" and String(概.get("类")) == "概念体"
		and 概.get("次数") == null and int(概["价"]) == 6 and PartSystem.part_rarity("rite") == "mid"
		and not bool(概.get("用", true)) and not PartSystem.part_is_free("rite"),
		"rite 河谷祭祈：概念体 / 不计次数 / 价 6 / rarity mid / 被动常驻（`用: false`）")
	var 血 := PartSystem.part_info("bloodcap")
	t.ok(String(血.get("类")) == "自然物" and 血.get("次数") == null and int(血["初值"]) == 2
		and int(血["价"]) == 4 and PartSystem.part_rarity("bloodcap") == "mid"
		and not bool(血.get("用", true)) and bool(血.get("可卖", false)),
		"bloodcap 血蕈：自然物（次数 null、初值 2、价 4、rarity mid、不能主动用、可卖）")
	var 浪 := PartSystem.part_info("wave")
	t.ok(String(浪.get("类")) == "自然物" and int(浪["初值"]) == 3 and int(浪["价"]) == 6
		and PartSystem.part_rarity("wave") == "low" and not bool(浪.get("用", true)),
		"wave 浪花：自然物（初值 3、价 6、rarity low、不能主动用）")
	t.ok(bool(PartSystem.part_info("jet").get("downgradePool", false)),
		"jet 一次性喷气背包带 `downgradePool: true`")
	t.ok(bool(PartSystem.part_info("bagua").get("noTargetSelect", false)),
		"bagua 小八界带 `noTargetSelect: true`（一键随机传送、不用选落点）")
	t.ok(PartSystem.零件箱上限() == 8, "零件箱上限 8")
	var n := PartSystem.new_part("wheel")
	t.ok(String(n["id"]) == "wheel" and int(n["uses"]) == 1 and n["value"] == null,
		"new_part：{id, uses, value}（加工品没有估价）")
	t.ok(int(PartSystem.new_part("bloodcap")["value"]) == 2 and int(PartSystem.new_part("wave")["value"]) == 3,
		"new_part：自然物带上表里的初值（血蕈 2 / 浪花 3）")

	# 推进剂加成（河谷祭祈）
	var s := RunState.new()
	s.seed_val = 1
	s.floor_num = 1
	s.map_data = _合成图()
	t.ok(PartSystem.recalc_propellant_bonus(s) == 0, "手上没有祭祈 → 零件加成 0")
	PartSystem.grant_part(s, "rite", "测试")
	t.ok(s.part_prop_bonus == 1, "拿到 1 件祭祈 → 零件加成 1")
	PartSystem.grant_part(s, "rite", "测试")
	t.ok(s.part_prop_bonus == 2, "两件祭祈 → 零件加成 2")
	t.ok(MapGenerator.propellant_max(s) == 4 + 2 + 2, "推进剂上限跟着变：最短路 4 + 余量 2 + 零件 2 = %d" % MapGenerator.propellant_max(s))
	PartSystem.sell_part(s, 0)
	t.ok(s.part_prop_bonus == 1, "卖掉一件祭祈 → 加成回到 1（重算）")

func _零件目标与位移(t) -> void:
	var s := _新局(_合成图())
	# 从起点 (0,0) 出发，全部按**网格坐标几何距离**算（不走近路 / 不看连通）
	var 期望 := {
		"wheel": [1, 2, 5, 10],            # line(2)：横竖 1~2 格（不含斜角）
		"limb": [1, 5, 6],                 # adj8：相邻 8 格（含斜角）
		"hover": [1, 2, 5, 6, 10],         # ring12：曼哈顿 1~2 的 12 格菱形
		"exo": [1, 2, 3, 5, 10, 15],       # line(3)：横竖 1~3 格（不含斜角）
		"engine": [1, 5, 6],               # adj8
		"spring": [1, 2, 5, 6, 10],        # ring12
	}
	var 坏 := []
	for k in 期望.keys():
		var 实 := PartSystem.part_targets(s, k)
		if 实 != 期望[k]:
			坏.append("%s：期望 %s 实际 %s" % [k, str(期望[k]), str(实)])
	t.ok(坏.is_empty(), "6 件位移件的目标格按几何距离逐条对齐（adj8 / ring12 / line(2) / line(3)）%s"
		% ("" if 坏.is_empty() else "：" + "；".join(坏)))
	t.ok(PartSystem.part_targets(s, "jet").size() == 24, "jet 喷气背包（any）：除当前格之外 24 格全可点")
	t.ok(PartSystem.part_targets(s, "bloodcap").is_empty() and PartSystem.part_targets(s, "wave").is_empty(),
		"两件自然物不能用（目标格为空）")
	t.ok(PartSystem.part_targets(s, "rite").is_empty(), "rite 河谷祭祈被动常驻（目标格为空）")

	# ---- 断言 1：直线不拐弯（wheel = line(2) / exo = line(3)，仅横竖 4 方向）----
	t.ok(not PartSystem.LINE_ALLOW_DIAGONAL,
		"断言 1：`PartSystem.LINE_ALLOW_DIAGONAL = false`（line(n) 只认横竖 4 方向）")
	var 当 := PartSystem.cell_xy(s, s.node_id)
	t.ok(not PartSystem.part_targets(s, "wheel").has(6) and not PartSystem.part_targets(s, "exo").has(6),
		"断言 1：dx == 1, dy == 1 的斜角格 (1,1) 不在 wheel / exo 的目标列表里")
	var 斜 := []
	for 件 in ["wheel", "exo"]:
		var 界 := 2 if 件 == "wheel" else 3
		for k in PartSystem.part_targets(s, 件):
			var xy := PartSystem.cell_xy(s, k)
			var dx := absi(int(xy["x"]) - int(当["x"]))
			var dy := absi(int(xy["y"]) - int(当["y"]))
			if not (dx == 0 or dy == 0) or maxi(dx, dy) < 1 or maxi(dx, dy) > 界:
				斜.append("%s→(%d,%d)" % [件, dx, dy])
	t.ok(斜.is_empty(), "断言 1：wheel / exo 的每个目标格都满足「dx == 0 或 dy == 0」且落在 1~n 格（不可拐弯）%s"
		% ("" if 斜.is_empty() else "：" + "、".join(斜)))
	t.ok(PartSystem.part_targets(s, "wheel").has(2) and PartSystem.part_targets(s, "wheel").has(10)
		and PartSystem.part_targets(s, "exo").has(3) and PartSystem.part_targets(s, "exo").has(15),
		"断言 1：wheel 到得了横竖 2 格（(2,0)/(0,2)）、exo 到得了横竖 3 格（(3,0)/(0,3)）")

	# ---- 断言 2：无视断路 / 空格（只看 (x, y) 几何距离，不用 BFS 连通）----
	var 挖 := _新局(_合成图())
	for k in [1, 2, 5]:
		(挖.cell_at(k) as Dictionary)["exists"] = false   # 人为挖掉 (1,0)、(2,0)、(0,1)
	t.ok(PartSystem.part_targets(挖, "wheel").has(10) and not PartSystem.part_targets(挖, "wheel").has(1)
		and not PartSystem.part_targets(挖, "wheel").has(2),
		"断言 2：中间格不存在也不影响 wheel 选中对岸的 (0,2)；不存在的格自己不是目标")
	t.ok(PartSystem.part_targets(挖, "exo").has(3),
		"断言 2：exo 穿过 (1,0)/(2,0) 两个空格照样选中 (3,0)")
	t.ok(PartSystem.part_targets(挖, "hover").has(10) and PartSystem.part_targets(挖, "spring").has(10),
		"断言 2：hover / spring 无视 (0,1) 的空缺，照样选中 (0,2)")
	var 洞 := _新局(_合成图())
	(洞.map_data["格"] as Dictionary).erase(1)   # 直接把中间格从格表里删掉（连 exists 都没有）
	(洞.map_data["格"] as Dictionary).erase(5)
	t.ok(PartSystem.part_targets(洞, "wheel").has(2) and PartSystem.part_targets(洞, "hover").has(6),
		"断言 2：中间格被整格删掉（空格）也照样算得到对岸的目标格")
	var 跳 := _新局(_合成图())
	(跳.cell_at(1) as Dictionary)["exists"] = false
	(跳.cell_at(5) as Dictionary)["exists"] = false
	跳.parts = [PartSystem.new_part("wheel")]
	var 前推 := 跳.propellant
	var r轮 := PartSystem.use_part(跳, 0, 2)
	t.ok(bool(r轮["ok"]) and 跳.node_id == 2 and 跳.propellant == 前推 - 1,
		"断言 2：wheel 跨过空格瞬移到 (2,0)（推进剂 %d → %d）" % [前推, 跳.propellant])
	var 跳2 := _新局(_合成图())
	(跳2.cell_at(1) as Dictionary)["exists"] = false
	(跳2.cell_at(2) as Dictionary)["exists"] = false
	跳2.parts = [PartSystem.new_part("exo")]
	var r外 := PartSystem.use_part(跳2, 0, 3)
	t.ok(bool(r外["ok"]) and 跳2.node_id == 3, "断言 2：exo 跨过两个空格瞬移到 (3,0)")
	var 跳3 := _新局(_合成图())
	(跳3.cell_at(5) as Dictionary)["exists"] = false
	跳3.parts = [PartSystem.new_part("hover")]
	var r气 := PartSystem.use_part(跳3, 0, 10)
	t.ok(bool(r气["ok"]) and 跳3.node_id == 10, "断言 2：hover 跨过空格瞬移到 (0,2)")
	var 跳4 := _新局(_合成图())
	(跳4.cell_at(5) as Dictionary)["exists"] = false
	跳4.parts = [PartSystem.new_part("spring")]
	var r簧 := PartSystem.use_part(跳4, 0, 10)
	t.ok(bool(r簧["ok"]) and 跳4.node_id == 10 and 跳4.propellant == 前推,
		"断言 2：spring 跨过空格瞬移到 (0,2)，且不耗推进剂（仍是 %d）" % 跳4.propellant)

	# ---- 断言 3：推进剂消耗与「0 推进剂禁则」----
	var 可落 := {"wheel": 2, "limb": 1, "hover": 1, "exo": 2, "engine": 1, "thaw": 12, "tentacle": 2}
	var 疑 := []
	for 件 in 可落.keys():
		var sN := _新局(_合成图())
		if 件 == "tentacle":
			sN.mark_revealed(2)          # 触须只认已探明的黑市
		sN.parts = [PartSystem.new_part(件)]
		sN.propellant = 5
		var rN := PartSystem.use_part(sN, 0, int(可落[件]))
		if not bool(rN["ok"]) or sN.propellant != 4:
			疑.append("%s：ok=%s 推进剂 5 → %d（%s）"
				% [件, str(rN.get("ok", false)), sN.propellant, str(rN.get("why", ""))])
	t.ok(疑.is_empty(), "断言 3：7 件 `free: false` 的主动件用一次后 `state.propellant` 精确 −1（5 → 4）%s"
		% ("" if 疑.is_empty() else "：" + "；".join(疑)))
	t.ok(PartSystem.part_is_free("spring") and PartSystem.part_is_free("jet")
		and PartSystem.part_is_free("bagua") and not PartSystem.part_is_free("wheel")
		and not PartSystem.part_is_free("thaw"),
		"断言 3：只有 spring / jet / bagua 是 `free: true`（免推进剂）")
	var 拒 := []
	for 件 in 可落.keys():
		var s0 := _新局(_合成图())
		if 件 == "tentacle":
			s0.mark_revealed(2)
		s0.parts = [PartSystem.new_part(件)]
		s0.propellant = 0
		var r0 := PartSystem.use_part(s0, 0, int(可落[件]))
		var 门 := _会话(s0).part_can_use_now(0)
		var 差 := (bool(r0["ok"]) or not str(r0.get("why", "")).contains("推进剂不足")
			or bool(门.get("ok", true)) or not str(门.get("why", "")).contains("推进剂不足")
			or s0.node_id != 0)
		if 差:
			拒.append("%s：use_part=%s/「%s」 门面=%s/「%s」"
				% [件, str(r0.get("ok", false)), str(r0.get("why", "")),
					str(门.get("ok", true)), str(门.get("why", ""))])
	t.ok(拒.is_empty(),
		"断言 3：`propellant == 0` 时这 7 件的 `use_part` 与 `part_can_use_now().ok` 都是 false，原因含「推进剂不足」%s"
		% ("" if 拒.is_empty() else "：" + "；".join(拒)))
	var 免坏 := []
	for 件 in ["spring", "jet", "bagua"]:
		var sF := _新局(_合成图())
		sF.parts = [PartSystem.new_part(件)]
		sF.propellant = 0
		var 门F := _会话(sF).part_can_use_now(0)
		if not bool(门F.get("ok", false)) or not bool(门F.get("free", false)) or sF.node_id != 0:
			免坏.append("%s：ok=%s free=%s why=「%s」"
				% [件, str(门F.get("ok", false)), str(门F.get("free", true)), str(门F.get("why", ""))])
	t.ok(免坏.is_empty(), "断言 3：`propellant == 0` 时 spring / jet / bagua 的 `part_can_use_now().ok` 仍为 true%s"
		% ("" if 免坏.is_empty() else "：" + "；".join(免坏)))
	var 落点 := {"spring": 10, "jet": 24, "bagua": -1}
	var 免费坏 := []
	for 件 in 落点.keys():
		var sU := _新局(_合成图())
		sU.parts = [PartSystem.new_part(件)]
		sU.propellant = 0
		var rU := PartSystem.use_part(sU, 0, int(落点[件]))
		if not bool(rU["ok"]) or sU.propellant != 0:
			免费坏.append("%s：ok=%s 推进剂 %d（%s）"
				% [件, str(rU.get("ok", false)), sU.propellant, str(rU.get("why", ""))])
	t.ok(免费坏.is_empty(),
		"断言 3：0 推进剂下 spring / jet / bagua 照样用得出来，且既不扣也不回推进剂（仍是 0）%s"
		% ("" if 免费坏.is_empty() else "：" + "；".join(免费坏)))

	# ---- 断言 5：坎诺特的触须 —— 迷雾里的黑市选不中 ----
	var 触 := _新局(_合成图())
	触.parts = [PartSystem.new_part("tentacle")]
	t.ok(not MapNavigator.is_known(触, 2) and PartSystem.black_market_cell(触) == 2,
		"断言 5：本层黑市 = 格 2（(2,0)），一开始 `is_known == false`（迷雾里）")
	t.ok(PartSystem.part_targets(触, "tentacle").is_empty(),
		"断言 5：迷雾里的黑市不可选中 → tentacle 的 `part_targets` 为空（%s）"
		% str(PartSystem.part_targets(触, "tentacle")))
	var r迷 := PartSystem.use_part(触, 0, 2)
	t.ok(not bool(r迷["ok"]) and 触.node_id == 0, "断言 5：未探明时直接 `use_part` 也被拒（不偷偷飞过去）")
	触.mark_revealed(2)
	t.ok(PartSystem.part_targets(触, "tentacle") == [2], "断言 5：探明之后黑市可选（目标格 = [2]）")
	var 碳前 := 触.carbon
	var r触 := PartSystem.use_part(触, 0, 2)
	t.ok(bool(r触["ok"]) and 触.node_id == 2, "断言 5：触须直达已探明的黑市格")
	t.ok(触.carbon == 碳前 + 4 and int((r触["额外"] as Dictionary)["源碳"]) == 4,
		"断言 5：移动后 `state.carbon` 精确 +4（%d → %d）" % [碳前, 触.carbon])
	t.ok(int((触.parts[0] as Dictionary)["uses"]) == 1,
		"断言 5：剩余次数 2 → 1")

	# ---- 断言 6：老妈的融雪 —— 迷雾里的非战斗格都能选 ----
	var 雪 := _新局(_合成图())
	雪.node_id = 7
	雪.mark_visited(7)          # 当前格 = (2,1) 空
	雪.parts = [PartSystem.new_part("thaw")]
	雪.hope = 0
	雪.exp_val = 0
	雪.level = 1
	var 雪目标 := PartSystem.part_targets(雪, "thaw")
	t.ok(雪目标.has(0) and 雪目标.has(12) and 雪目标.has(19),
		"断言 6：thaw 到得了**未探明**的非战斗格（起点 0 / 出口尽头 12 / 出口小径 19）")
	t.ok(not 雪目标.has(5) and not 雪目标.has(13) and not 雪目标.has(7),
		"断言 6：thaw 到不了战斗格 5（作战）/ 13（出口守军），当前格 7 也不能选")
	t.ok(雪目标.size() == 22, "断言 6：thaw 的目标格 = 25 格 − 当前格 1 − 两个战斗格 = %d" % 雪目标.size())
	var r雪 := PartSystem.use_part(雪, 0, 12)
	t.ok(bool(r雪["ok"]) and 雪.node_id == 12, "断言 6：融雪飞到未探明的出口尽头 (2,2)")
	t.ok(雪.hope == 2 and int((r雪["额外"] as Dictionary)["希望"]) == 2,
		"断言 6：落地 `state.hope` +2（0 → %d）" % 雪.hope)
	t.ok(雪.exp_val == 0 and 雪.level == 1 and int((r雪["额外"] as Dictionary)["经验"]) == 0,
		"断言 6：融雪**不再给**肉鸽经验（exp 仍是 0，★ 旧版的 +3 已删）")

	# ---- 断言 6：小八界 —— 优先未探明的非战斗格、免推进剂、不回推进剂、不揭四邻雾 ----
	var 卦 := _新局(_合成图())
	卦.parts = [PartSystem.new_part("bagua")]
	卦.propellant = 1
	var 候 := PartSystem.bagua_candidates(卦)
	var 候合法 := not 候.is_empty()
	for k in 候:
		if MapNavigator.is_known(卦, k) or PartSystem.is_combat_type(PartSystem.cell_type(卦.cell_at(k))):
			候合法 = false
	t.ok(候合法 and not 候.has(0),
		"断言 6：小八界的候选池 = 本层**未探明**的非战斗格（%d 格，不含当前格）" % 候.size())
	var r卦 := PartSystem.use_part(卦, 0, -1)
	var 落卦 := int(r卦.get("target", -1))
	t.ok(bool(r卦["ok"]) and 候.has(落卦) and 卦.node_id == 落卦,
		"断言 6：一键随机传送落在候选池里的非战斗格（%d）" % 落卦)
	t.ok(卦.propellant == 1, "断言 6：小八界免推进剂，也**不回**推进剂（仍是 1）")
	t.ok(卦.revealed_cells.size() == 1 and 卦.is_revealed(落卦),
		"断言 6：只揭开落点本身、**不揭四邻雾**（已揭开 = %s）" % str(卦.revealed_cells))
	var 全 := _新局(_合成图())
	全.parts = [PartSystem.new_part("bagua")]
	for k in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]:
		全.mark_revealed(k)
	var 全候 := PartSystem.bagua_candidates(全)
	t.ok(全候.has(全.node_id) and 全候.size() == 23,
		"断言 6：全探明之后候选池 = 全部非战斗格（含当前格 0，共 %d 格）" % 全候.size())
	var r全 := PartSystem.use_part(全, 0, -1)
	t.ok(bool(r全["ok"]) and 全候.has(int(r全.get("target", -1))) and 全.parts.is_empty(),
		"断言 6：全探明时从全部非战斗格里随机抽一个（可能原地不动），一次用尽后从手上移除")

# ==========================================================================================
# ⑨ 零件：跨层损坏 / 稀有度抽取（断言 4、断言 8）
# ==========================================================================================

func _零件跨层与抽取(t) -> void:
	# ---- 断言 4：跨层损坏 —— spring / bagua 掉，wheel / rite 留 ----
	var 持 := ["spring", "bagua", "wheel", "rite"]
	var 直 := RunState.new()
	直.seed_val = 20261010
	直.floor_num = 1
	直.map_data = _合成图()
	for k in 持:
		直.parts.append(PartSystem.new_part(k))
	t.ok(PartSystem.part_breaks_on_next_floor("spring") and PartSystem.part_breaks_on_next_floor("bagua")
		and not PartSystem.part_breaks_on_next_floor("wheel") and not PartSystem.part_breaks_on_next_floor("rite"),
		"断言 4：只有 spring / bagua 带 `breakOnNextFloor: true`")
	var 坏名 := PartSystem.break_on_next_floor(直)
	var 键直 := []
	for p in 直.parts:
		键直.append(PartSystem.part_key(p))
	t.ok(坏名.size() == 2 and 坏名.has("重弹簧") and 坏名.has("小八界"),
		"断言 4：`break_on_next_floor` 返回被损坏的两件（%s）" % str(坏名))
	t.ok(直.parts.size() == 2 and 键直.has("wheel") and 键直.has("rite")
		and not 键直.has("spring") and not 键直.has("bagua"),
		"断言 4：损坏后手上只剩 wheel 与 rite（%s）" % str(键直))
	var 换 := RunState.new()
	换.seed_val = 20261010
	MapNavigator.enter_floor(换, 1)
	for k in 持:
		换.parts.append(PartSystem.new_part(k))
	var r换 := MapNavigator.advance_floor(换)
	var 键换 := []
	for p in 换.parts:
		键换.append(PartSystem.part_key(p))
	t.ok(bool(r换["ok"]) and 换.floor_num == 2, "断言 4：`MapNavigator.advance_floor` 进到第 2 层")
	t.ok((r换.get("跨层损坏") as Array).size() == 2,
		"断言 4：换层结果带回「跨层损坏」两件（%s）" % str(r换.get("跨层损坏")))
	t.ok(换.parts.size() == 2 and 键换.has("wheel") and 键换.has("rite")
		and not 键换.has("spring") and not 键换.has("bagua"),
		"断言 4：换层之后 spring / bagua 自动从 `state.parts` 移除，wheel / rite 保留（%s）" % str(键换))

	# ---- 断言 8：`weight_by_rarity` 接口（默认 null = 等权抽取）----
	var 抽 := RunState.new()
	抽.seed_val = 20261010
	抽.floor_num = 1
	抽.map_data = _合成图()
	抽.node_id = 0
	var 池 := PartSystem.tradable_part_ids()
	var 默认见 := {}
	var 非法 := 0
	for i in 200:
		var k := PartSystem.draw_part(抽, i)
		if not 池.has(k):
			非法 += 1
		默认见[k] = true
	t.ok(非法 == 0 and 默认见.size() == 池.size(),
		"断言 8：`draw_part(默认 null)` = 买卖池等权抽取（200 次把 %d 件全抽到过）" % 默认见.size())
	var 逐格同 := true
	for i in 20:
		if PartSystem.draw_part(抽, i) != NodeResolver.抽零件(抽, i):
			逐格同 = false
	t.ok(逐格同, "断言 8：`NodeResolver.抽零件(state, salt)` 默认透传 null → 与 `PartSystem.draw_part` 逐盐相同")
	var 高池 := ["thaw", "tentacle"]
	var 高见 := {}
	var 高档 := true
	for i in 50:
		var k := PartSystem.draw_part(抽, i, {"low": 0, "mid": 0, "high": 100})
		高见[k] = true
		if not 高池.has(k):
			高档 = false
	t.ok(高档 and 高见.size() == 2,
		"断言 8：传 `{\"low\": 0, \"mid\": 0, \"high\": 100}` → 只出 high 档的 thaw / tentacle（%s）"
		% str(高见.keys()))
	var 低池 := ["wheel", "limb", "bagua", "wave"]
	var 低档 := true
	for i in 50:
		if not 低池.has(PartSystem.draw_part(抽, i, {"low": 100, "mid": 0, "high": 0})):
			低档 = false
	t.ok(低档, "断言 8：传 `{\"low\": 100, \"mid\": 0, \"high\": 0}` → 只出 low 档（%s）" % str(低池))
	var 门权 := true
	for i in 30:
		if not 高池.has(NodeResolver.抽零件(抽, i, {"low": 0, "mid": 0, "high": 100})):
			门权 = false
	t.ok(门权, "断言 8：`NodeResolver.抽零件(state, salt, 权重表)` 也严格按稀有度权重抽")

# ==========================================================================================
# ⑩ 零件：增值 / 买卖折算（断言 7）
# ==========================================================================================

func _零件买卖(t) -> void:
	# ---- 卖价：自然物按当前估价；加工品 / 概念体固定 1 源碳 ----
	t.ok(PartSystem.sell_price(PartSystem.new_part("bloodcap")) == 2, "断言 7：黑市卖血蕈 = 当前估价 2")
	t.ok(PartSystem.sell_price(PartSystem.new_part("wave")) == 3, "断言 7：黑市卖浪花 = 当前估价 3")
	t.ok(PartSystem.sell_price({"id": "bloodcap", "uses": null, "value": 9}) == 9,
		"断言 7：血蕈涨价之后按**当前估价**卖（9）")
	var 加工与概念 := ["wheel", "limb", "hover", "exo", "engine", "spring", "jet", "bagua",
		"thaw", "tentacle", "rite"]
	var 坏 := []
	for k in 加工与概念:
		var 实 := PartSystem.sell_price(PartSystem.new_part(k))
		if 实 != 1:
			坏.append("%s：%d" % [k, 实])
	t.ok(坏.is_empty(),
		"断言 7：10 件加工品 + 概念体（河谷祭祈）卖价**固定 1 源碳**，不再按参考价折算%s"
		% ("" if 坏.is_empty() else "：" + "；".join(坏)))

	# ---- 黑市买价（f1 藏品打折 0.7）----
	var s := RunState.new()
	t.ok(PartSystem.buy_price(s, "jet") == 8 and PartSystem.buy_price(s, "bagua") == 4
		and PartSystem.buy_price(s, "tentacle") == 12,
		"黑市买价 = 表里的「价」（喷气背包 8 / 小八界 4 / 触须 12）")
	s.relics = ["f1"]
	t.ok(PartSystem.buy_price(s, "jet") == 6 and PartSystem.buy_price(s, "bagua") == 3,
		"有 f1 藏品 → 买价 × 0.7 四舍五入（8 → 6、4 → 3）")

	# ---- 断言 7：血蕈 —— 胜 / 败都 +2，且**无上限** ----
	var 血 := RunState.new()
	血.seed_val = 20261010
	血.floor_num = 1
	血.map_data = _合成图()
	血.parts = [PartSystem.new_part("bloodcap")]
	var 胜报 := {"result": {"结果": "胜"}, "allies": [], "enemies": []}
	var 败报 := {"result": {"结果": "败"}, "allies": [], "enemies": []}
	NodeResolver.resolve_battle(血, 胜报, "作战")
	t.ok(int((血.parts[0] as Dictionary)["value"]) == 4, "断言 7：打赢一场后血蕈估价 2 → 4（`NodeResolver.resolve_battle`）")
	NodeResolver.resolve_battle(血, 败报, "作战")
	t.ok(int((血.parts[0] as Dictionary)["value"]) == 6, "断言 7：打输一场后血蕈估价**同样** +2（4 → 6）")
	for i in 6:
		NodeResolver.resolve_battle(血, 胜报, "作战")
	var 血值 := int((血.parts[0] as Dictionary)["value"])
	t.ok(血值 == 18 and 血值 > 15,
		"断言 7：连打多场血蕈估价**没有上限**（6 + 6×2 = %d > 15）" % 血值)
	t.ok(PartSystem.sell_price(血.parts[0]) == 血值,
		"断言 7：黑市按当前估价 %d 卖出（不再封顶 15）" % 血值)

	# ---- 断言 7：浪花 —— 每次移动 −6 / +8，夹在 [0, 999] ----
	var 浪 := RunState.new()
	浪.seed_val = 20261010
	浪.floor_num = 1
	浪.map_data = _合成图()
	浪.node_id = 0
	var 件 := PartSystem.new_part("wave")
	件["value"] = 500
	件["val"] = 500
	浪.parts = [件]
	var 异 := 0
	var 越界 := false
	for i in 30:
		浪.visited_cells.append(i + 1)
		var 前 := PartSystem.current_value(浪.parts[0])
		PartSystem.wave_fluctuate(浪, i)
		var 后 := PartSystem.current_value(浪.parts[0])
		var 差 := 后 - 前
		if not (差 == -6 or 差 == 8):
			异 += 1
		if 后 < 0 or 后 > 999:
			越界 = true
	t.ok(异 == 0, "断言 7：浪花每次移动估价只按 −6 或 +8 变化（30 次全部合规，例外 %d 次）" % 异)
	t.ok(not 越界, "断言 7：浪花估价恒落在 [0, 999]")
	var 顶 := PartSystem.new_part("wave")
	顶["value"] = 999
	顶["val"] = 999
	浪.parts = [顶]
	PartSystem.wave_fluctuate(浪, 99)
	var 顶值 := PartSystem.current_value(浪.parts[0])
	t.ok(顶值 <= 999 and (顶值 == 999 or 顶值 == 993),
		"断言 7：估价 999 时只可能夹回 999 / 993（实际 %d）" % 顶值)
	var 底 := PartSystem.new_part("wave")
	底["value"] = 0
	底["val"] = 0
	浪.parts = [底]
	PartSystem.wave_fluctuate(浪, 98)
	var 底值 := PartSystem.current_value(浪.parts[0])
	t.ok(底值 >= 0 and (底值 == 0 or 底值 == 8),
		"断言 7：估价 0 时只可能夹成 0 / 8（实际 %d）" % 底值)
	var 甲 := RunState.new()
	甲.seed_val = 20261010
	甲.floor_num = 1
	甲.map_data = _合成图()
	甲.parts = [PartSystem.new_part("wave")]
	var 乙 := RunState.new()
	乙.seed_val = 20261010
	乙.floor_num = 1
	乙.map_data = _合成图()
	乙.parts = [PartSystem.new_part("wave")]
	PartSystem.wave_fluctuate(甲, 7)
	PartSystem.wave_fluctuate(乙, 7)
	t.ok(PartSystem.current_value(甲.parts[0]) == PartSystem.current_value(乙.parts[0]),
		"断言 7：同种子同一步的浪花估价逐字相同（带种子的确定性步进，不消耗全局 rng）")

	# ---- 卖零件：源碳到账 + 零件移走 ----
	var s5 := RunState.new()
	s5.carbon = 10
	s5.parts = [PartSystem.new_part("jet"), PartSystem.new_part("rite")]
	var 卖 := PartSystem.sell_part(s5, 0)
	t.ok(bool(卖["ok"]) and int(卖["价"]) == 1 and s5.carbon == 11,
		"断言 7：黑市卖加工品（喷气背包）固定 +1 源碳（10 → 11）")
	t.ok(s5.parts.size() == 1 and PartSystem.part_key(s5.parts[0]) == "rite", "卖掉的是第 0 件，祭祈留在手上")
	var 卖祭 := PartSystem.sell_part(s5, 0)
	t.ok(int(卖祭["价"]) == 1 and s5.carbon == 12, "断言 7：黑市卖概念体（河谷祭祈）也固定 1 源碳（11 → 12）")
	t.ok(PartSystem.sell_part(s5, 5).is_empty(), "下标越界 → 空结果（不崩）")

	# ---- 箱满：保留新的、换掉参考价最低的旧件（按新价格表）----
	var s6 := RunState.new()
	var 箱 := ["wheel", "limb", "hover", "exo", "engine", "spring", "jet", "bagua"]
	for k in 箱:
		s6.parts.append(PartSystem.new_part(k))
	t.ok(s6.parts.size() == 8 and PartSystem.零件箱满了吗(s6), "零件箱 8 件 = 上限")
	var 得 := PartSystem.grant_part(s6, "thaw", "遗迹")
	t.ok(bool(得.get("满了", false)) and s6.parts.size() == 8, "箱满时不静默丢：收下新的，箱子里仍然是 8 件")
	t.ok(String((得["换掉"] as Dictionary)["id"]) == "wheel",
		"箱满替换按**当前价**挑最便宜的：wheel / limb 都是 2（比 spring 的 6 便宜），取先遇上的 wheel（%s）"
		% str(得["换掉"]))
	var 键们 := []
	for p in s6.parts:
		键们.append(PartSystem.part_key(p))
	t.ok(键们.has("thaw") and not 键们.has("wheel") and 键们.has("spring") and 键们.has("limb"),
		"新件在箱子里、参考价最低的 wheel 被换掉，spring（价 6）/ limb（价 2）都留着")
	var s7 := RunState.new()
	s7.parts = [PartSystem.new_part("rite")]
	for k in ["wheel", "limb", "hover", "exo", "engine", "spring", "jet"]:
		s7.parts.append(PartSystem.new_part(k))
	PartSystem.recalc_propellant_bonus(s7)
	var 换 := PartSystem.grant_part(s7, "thaw", "遗迹")
	t.ok(s7.part_prop_bonus == 1 and String((换["换掉"] as Dictionary)["id"]) == "wheel",
		"箱满时按**参考价**挑最便宜的换：祭祈（参考价 6）留着，wheel（价 2）被换掉 → 加成仍是 1")
	PartSystem.recalc_propellant_bonus(s7)
	PartSystem.sell_part(s7, 0)
	t.ok(s7.part_prop_bonus == 0, "卖掉祭祈 → 推进剂加成重算为 0")

