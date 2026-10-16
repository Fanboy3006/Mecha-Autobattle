## Stage M3-Core-A 单元测试：大地图生成 / 导航 / 零件（原生 Godot，零 `J.*`）。
##   ① 对拍 `tests/golden/run_vectors.json` 的「地图」32 张（8 种子 × 4 层）**逐字段相等**；
##   ② 对拍「推进剂」账（上限 = 最短路 + 余量 + 层修正 + 零件 + 小径）与「推进剂明细」4 层；
##   ③ 地图几何自洽（独立 BFS 复核 起点 / 出口 / 守军 / 最短路家族 / 每格的列行邻距离）；
##   ④ 移动、跳格、林间空地扣费与标记、退路成本预告（纯读）；
##   ⑤ 推进剂归零 → 追击打赢 → 下一层上限 −2（**无推进剂恢复**，★ D-02 口径 C）；
##   ⑥ 出口追击守军闸拦截 / 守军打赢放行 / 出口小径免守军 + 下一层上限 +2（★ 口径 D / E）/ 第 4 层通关；
##   ⑦ 13 件零件：数据 / 目标格枚举 / 位移 / 增值 / 买卖折算。
extends RefCounted

const 种子们 := [20261010, 20261011, 20261012, 20261013, 20261014, 20261015, 20261016, 20261017]
const 主动零件 := ["wheel", "limb", "hover", "exo", "engine", "spring", "jet", "bagua", "thaw", "tentacle", "rite"]

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
# ⑧ 零件：数据 / 目标格 / 位移
# ==========================================================================================

func _零件数据(t) -> void:
	var 表 := PartSystem.part_table()
	t.ok(表.size() == 13, "零件表 13 件")
	t.ok(PartSystem.active_part_ids().size() == 11, "能动的那 11 件（`用: true`）")
	var 缺 := []
	for k in 主动零件:
		if not 表.has(k):
			缺.append(k)
		elif not bool(PartSystem.part_info(k).get("用", false)):
			缺.append(k + "(用:false)")
	t.ok(缺.is_empty(), "11 件主动零件齐全：%s" % ", ".join(主动零件))
	t.ok(PartSystem.tradable_part_ids().size() == 13, "买卖池 = 全表 13 件（含两件理财自然物）")
	var w := PartSystem.part_info("wheel")
	t.ok(String(w["名"]) == "报废轮子" and String(w["类"]) == "加工品" and int(w["次数"]) == 1
		and String(w["移动"]) == "line2" and int(w["价"]) == 3 and bool(w["用"]), "wheel 报废轮子：加工品 / 1 次 / line2 / 价 3")
	var b := PartSystem.part_info("bloodcap")
	t.ok(b.get("次数") == null and int(b["估价"]) == 3 and not bool(b["用"]) and bool(b["可卖"]),
		"bloodcap 血蕈：自然物（次数 null、估价 3、不能主动用、可卖）")
	t.ok(String(PartSystem.part_info("rite")["名"]) == "河谷祭祈" and PartSystem.零件箱上限() == 8,
		"rite 河谷祭祈 + 零件箱上限 8")
	var n := PartSystem.new_part("wheel")
	t.ok(String(n["id"]) == "wheel" and int(n["uses"]) == 1 and n["value"] == null, "new_part：{id, uses, value}")

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
	var 期望 := {
		"wheel": [2, 6, 10], "limb": [1, 5], "hover": [1, 2, 5, 6, 10],
		"exo": [2, 3, 6, 7, 10, 11, 15], "engine": [1, 5], "spring": [1, 2, 5, 6, 10],
	}
	var 坏 := []
	for k in 期望.keys():
		var 实 := PartSystem.part_targets(s, k)
		if 实 != 期望[k]:
			坏.append("%s：期望 %s 实际 %s" % [k, str(期望[k]), str(实)])
	t.ok(坏.is_empty(), "11 件里的 6 件跳跃类目标格逐条对齐（ring / ringline / line2 / line3 / step）%s"
		% ("" if 坏.is_empty() else "：" + "；".join(坏)))
	t.ok(PartSystem.part_targets(s, "jet").size() == 24, "jet 喷气背包（any）：除当前格之外 24 格全可点")
	t.ok(PartSystem.part_targets(s, "tentacle") == [2], "tentacle 触须：直接指向本层黑市那一格")
	t.ok(PartSystem.part_targets(s, "bloodcap").is_empty() and PartSystem.part_targets(s, "wave").is_empty(),
		"两件自然物不能用（目标格为空）")
	t.ok(PartSystem.part_targets(s, "rite").is_empty(), "rite 没有位移（目标格为空）")
	s.revealed_cells = [14]
	t.ok(PartSystem.part_targets(s, "thaw") == [14], "thaw 融雪：只飞到**已知**的非战斗格（揭开 (2,4) 遗迹后 = [14]）")
	t.ok(not PartSystem.part_targets(s, "thaw").has(12), "thaw 飞不到出口尽头（战斗类节点）")

	# 用零件位移：不消耗推进剂、不结算
	var s2 := _新局(_合成图())
	s2.parts = [PartSystem.new_part("wheel")]
	var 推前 := s2.propellant
	var r := PartSystem.use_part(s2, 0, 2)
	t.ok(bool(r["ok"]) and s2.node_id == 2 and s2.propellant == 推前, "用轮子跳到 2 格远：位移成功且**不消耗推进剂**")
	t.ok(s2.parts.is_empty(), "次数用光（1 次）→ 零件从手上消失")
	t.ok(not bool(PartSystem.use_part(s2, 0, 6)["ok"]), "零件已经用光 → 拒绝")
	var s3 := _新局(_合成图())
	s3.parts = [PartSystem.new_part("engine")]
	PartSystem.use_part(s3, 0, 1)
	PartSystem.use_part(s3, 0, 6)
	t.ok(int((s3.parts[0] as Dictionary)["uses"]) == 1, "引擎能用 3 次：用掉 2 次后还剩 1 次")
	var s4 := _新局(_合成图())
	s4.parts = [PartSystem.new_part("engine")]
	t.ok(not bool(PartSystem.use_part(s4, 0, 12)["ok"]), "目标不在这一件的目标格里 → 拒绝（引擎到不了 4 格远）")

	# thaw：+2 希望 +3 经验
	var s5 := _新局(_合成图())
	s5.parts = [PartSystem.new_part("thaw")]
	s5.revealed_cells = [14]
	s5.hope = 0
	s5.exp_val = 0
	s5.level = 1
	var r5 := PartSystem.use_part(s5, 0, 14)
	t.ok(bool(r5["ok"]) and s5.node_id == 14, "融雪：飞跃到已知非战斗格 (2,4)")
	t.ok(s5.hope == 2 and s5.exp_val == 3 and s5.level == 1, "融雪附加效果：希望 +2、经验 +3（3 < 门槛 8，不升级）")
	t.ok(int((r5["额外"] as Dictionary)["希望"]) == 2 and int((r5["额外"] as Dictionary)["经验"]) == 3, "返回里带回额外效果明细")

	# bagua：探明四邻 + 回复 1 推进剂
	var s6 := _新局(_合成图())
	s6.parts = [PartSystem.new_part("bagua")]
	s6.propellant = 1
	var r6 := PartSystem.use_part(s6, 0, 6)
	var 探 := int((r6["额外"] as Dictionary)["探明"])
	t.ok(bool(r6["ok"]) and 探 == 4, "小八界：落地探明四邻 4 格（额外.探明 = %d）" % 探)
	t.ok(s6.propellant == 2 and int((r6["额外"] as Dictionary)["推进剂"]) == 1, "小八界：回复 +1 推进剂（1 → 2）")
	t.ok(s6.is_revealed(1) and s6.is_revealed(5) and s6.is_revealed(7) and s6.is_revealed(11), "四邻接格都进了「已揭开」")

# ==========================================================================================
# ⑨ 零件：增值 / 买卖折算
# ==========================================================================================

func _零件买卖(t) -> void:
	# 卖价：自然物按当前估价；加工品 / 概念体 max(2, floor(价 × 0.6))
	var 期望卖 := {"wheel": 2, "limb": 2, "hover": 3, "exo": 3, "engine": 2, "spring": 2,
		"jet": 4, "bagua": 5, "thaw": 3, "tentacle": 2, "rite": 3}
	var 坏 := []
	for k in 期望卖.keys():
		var 实 := PartSystem.sell_price(PartSystem.new_part(k))
		if 实 != 期望卖[k]:
			坏.append("%s：期望 %d 实际 %d" % [k, 期望卖[k], 实])
	t.ok(坏.is_empty(), "11 件加工品 / 概念体卖价 = max(2, floor(价 × 0.6))%s" % ("" if 坏.is_empty() else "：" + "；".join(坏)))
	t.ok(PartSystem.sell_price(PartSystem.new_part("bloodcap")) == 3, "血蕈按当前估价卖（初始 3）")
	t.ok(PartSystem.sell_price(PartSystem.new_part("wave")) == 4, "浪花按当前估价卖（初始 4）")
	t.ok(PartSystem.sell_price({"id": "bloodcap", "uses": null, "value": 9}) == 9, "血蕈涨价之后按**当前估价**卖（9）")

	# 黑市买价（f1 藏品打折 0.7）
	var s := RunState.new()
	t.ok(PartSystem.buy_price(s, "jet") == 8 and PartSystem.buy_price(s, "bagua") == 9, "黑市买价 = 表里的参考价")
	s.relics = ["f1"]
	t.ok(PartSystem.buy_price(s, "jet") == 6 and PartSystem.buy_price(s, "bagua") == 6,
		"有 f1 藏品 → 买价 × 0.7 四舍五入（8→6、9→6）")

	# 血蕈：每次战斗胜利后估价 +2、封顶 15
	var s2 := RunState.new()
	s2.parts = [PartSystem.new_part("bloodcap")]
	var 涨1 := PartSystem.bloodcap_appreciate(s2)
	t.ok(涨1.size() == 1 and int((s2.parts[0] as Dictionary)["value"]) == 5, "血蕈战后估价 +2（3 → 5）")
	for i in 10:
		PartSystem.bloodcap_appreciate(s2)
	t.ok(int((s2.parts[0] as Dictionary)["value"]) == 15, "血蕈估价封顶 15（★ 不再往上涨）")
	t.ok(PartSystem.sell_price(s2.parts[0]) == 15, "封顶后按 15 源碳卖出")

	# 浪花：移动后估值在 2~8 之间确定性波动
	var s3 := RunState.new()
	s3.seed_val = 20261010
	s3.floor_num = 1
	s3.map_data = _合成图()
	s3.node_id = 0
	s3.parts = [PartSystem.new_part("wave")]
	var 见 := {}
	var 变了 := 0
	for k in [1, 5, 6, 11, 12, 18, 24]:
		s3.visited_cells.append(k)
		var 变 := PartSystem.wave_fluctuate(s3, k)
		var v := int((s3.parts[0] as Dictionary)["value"])
		见[v] = true
		if not 变.is_empty():
			变了 += 1
	t.ok(见.keys().size() > 1 and 变了 > 0, "浪花：每一步都在 2~8 之间波动（出现过 %d 个不同估价）" % 见.keys().size())
	var 越界 := false
	for v in 见.keys():
		if v < 2 or v > 8:
			越界 = true
	t.ok(not 越界, "浪花估价恒落在 2~8（%s）" % str(见.keys()))
	var a := PartSystem.new_part("wave")
	var s4 := RunState.new()
	s4.seed_val = 20261010
	s4.floor_num = 1
	s4.visited_cells = [1, 5, 6]
	s4.parts = [a]
	PartSystem.wave_fluctuate(s4, 11)
	var 值1 := int((s4.parts[0] as Dictionary)["value"])
	s4.parts = [PartSystem.new_part("wave")]
	PartSystem.wave_fluctuate(s4, 11)
	t.ok(值1 == int((s4.parts[0] as Dictionary)["value"]), "同一局同一步永远是同一个数（确定性，不消耗 rng）")

	# 卖零件：源碳到账 + 零件移走
	var s5 := RunState.new()
	s5.carbon = 10
	s5.parts = [PartSystem.new_part("jet"), PartSystem.new_part("rite")]
	var 卖 := PartSystem.sell_part(s5, 0)
	t.ok(bool(卖["ok"]) and int(卖["价"]) == 4 and s5.carbon == 14, "卖喷气背包 +4 源碳（10 → 14）")
	t.ok(s5.parts.size() == 1 and PartSystem.part_key(s5.parts[0]) == "rite", "卖掉的是第 0 件，祭祈留在手上")
	t.ok(PartSystem.sell_part(s5, 5).is_empty(), "下标越界 → 空结果（不崩）")

	# 箱满：保留新的、换掉参考价最低的旧件
	var s6 := RunState.new()
	var 箱 := ["wheel", "limb", "hover", "exo", "engine", "spring", "jet", "bagua"]
	s6.parts = []
	for k in 箱:
		s6.parts.append(PartSystem.new_part(k))
	t.ok(s6.parts.size() == 8 and PartSystem.零件箱满了吗(s6), "零件箱 8 件 = 上限")
	var 得 := PartSystem.grant_part(s6, "thaw", "遗迹")
	t.ok(bool(得.get("满了", false)) and s6.parts.size() == 8, "箱满时不静默丢：收下新的，箱子里仍然是 8 件")
	t.ok(String((得["换掉"] as Dictionary)["id"]) == "spring", "换掉的是参考价最低的旧件（重弹簧 价 2）")
	var 键们 := []
	for p in s6.parts:
		键们.append(PartSystem.part_key(p))
	t.ok(键们.has("thaw") and not 键们.has("spring"), "新件在箱子里、最便宜的那件被换掉")
	var s7 := RunState.new()
	s7.parts = [PartSystem.new_part("rite")]
	for k in ["wheel", "limb", "hover", "exo", "engine", "spring", "jet"]:
		s7.parts.append(PartSystem.new_part(k))
	PartSystem.recalc_propellant_bonus(s7)
	var 换 := PartSystem.grant_part(s7, "thaw", "遗迹")
	t.ok(s7.part_prop_bonus == 1 and String((换["换掉"] as Dictionary)["id"]) == "spring",
		"箱满时按**参考价**挑最便宜的换：祭祈（参考价 6）留着，重弹簧（价 2）被换掉 → 加成仍是 1")
	PartSystem.recalc_propellant_bonus(s7)
	PartSystem.sell_part(s7, 0)
	t.ok(s7.part_prop_bonus == 0, "卖掉祭祈 → 推进剂加成重算为 0")
