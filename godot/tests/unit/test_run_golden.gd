## 局外（肉鸽）黄金样例的形状与自洽校验：godot/tests/golden/run_vectors.json
## **COL-1.1 起由 `godot/tools/record_run_golden.gd` 从 Godot 内核原生录出**（旧的 JS 导出版归档在 `协作/归档/run_vectors-JS参考版.json`）。
## 这里**只做形状 + 自洽**（M3 肉鸽内核的地图 / 推进剂 / 券 / 晋升 / 三选一还不在 Battle Core 里）：
##   · 五块内容齐全、条数对得上（8 种子 × 4 层 / 4 层明细 / 8 局券 / 名册人数 × 2 档 / 名册人数三选一）；
##   · 推进剂自洽：上限 = 最短路 + 余量 + 层修正 + 零件 + 小径，且余量恒偶数（二部图那一条）；
##   · 地图自洽：起点 / 两个出口 / 守军都在格表里，形状与顶层字段一致；
##   · 晋升面板自洽：前 lv 升一档、后 maxHp 更大、价格非负；三选一：候选不重复、选走后不再出现。
## 等 M3 的肉鸽内核落地后，这份文件改由内核重跑并逐字段比对（与战斗黄金样例同一套路）。
extends RefCounted

const 样例标签 := "godot-native-col1"

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db %s" % ("" if errors.is_empty() else str(errors)))
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	t.ok(not data.is_empty(), "run_vectors.json 能读成字典")
	var meta: Dictionary = data.get("meta", {})
	var 清单 := GoldenIO.load_json("res://data/js/manifest.json")
	t.ok(str(meta.get("tag", "")) == 样例标签 and str(meta.get("rulesSignature", "")) == str(清单.get("rulesSignature", "")),
		"局外样例由 Godot 原生录出（tag %s / 签名 %s）" % [str(meta.get("tag", "")), str(meta.get("rulesSignature", ""))])
	t.ok(str(meta.get("生成", "")).contains("record_run_golden"),
		"样例的「生成」指向 `tools/record_run_golden.gd`（%s）" % str(meta.get("生成", "")))
	var 名册人数: int = RosterManager.名册键们().size()
	t.ok(int(meta.get("名册人数", -1)) == 名册人数,
		"样例记的名册人数 = 当前名册（%d / %d）" % [int(meta.get("名册人数", -1)), 名册人数])
	for 块 in ["地图", "推进剂明细", "招募券", "晋升面板", "战术牌三选一"]:
		t.ok(data.has(块) and data[块] is Array and not (data[块] as Array).is_empty(), "有「%s」这一块且非空" % 块)

	# ---- 地图：8 种子 × 4 层 ----
	var 地图: Array = data["地图"]
	var 层集 := {}
	var 种子集 := {}
	for raw in 地图:
		var m: Dictionary = GoldenCompare.decode(raw)
		种子集[m["种子"]] = true
		层集[m["层"]] = true
		var 图: Dictionary = m["地图"]
		var 格: Dictionary = 图["格"]
		var 坏 := []
		for k in ["起点", "出口", "出口尽头", "出口小径", "守军"]:
			if not 格.has(J.s(图[k])):
				坏.append(k)
		var 账: Dictionary = m["推进剂"]["账"]
		var 和 := float(账["最短路"]) + float(账["余量"]) + float(账["层修正"]) + float(账["零件"]) + float(账["小径"])
		var ok: bool = (坏.is_empty() and 图["列数"] == m["形状"]["列数"] and 图["形状"] == "正方形"
			and float(账["余量"]) > 0.0 and int(账["余量"]) % 2 == 0
			and absf(float(m["推进剂"]["上限"]) - 和) < 0.0001
			and float(m["推进剂"]["进层后实发"]) == float(m["推进剂"]["上限"])
			and 图["最短路"] == 图["直达"] and float(图["最短路"]) > 0.0)
		t.ok(ok, "种子 %s 第 %s 层：形状 / 五个坐标 / 推进剂账自洽%s" % [J.s(m["种子"]), J.s(m["层"]), "" if 坏.is_empty() else str(坏)])
	t.ok(地图.size() == 32 and 种子集.size() == 8 and 层集.size() == 4,
		"地图 %d 张 = %d 个种子 × %d 层" % [地图.size(), 种子集.size(), 层集.size()])

	# ---- 推进剂明细（逐层的静态口径）----
	var 明细: Array = data["推进剂明细"]
	var 明细对 := 明细.size() == 4
	for raw2 in 明细:
		var d: Dictionary = GoldenCompare.decode(raw2)
		if not (int(d["余量表"]) == int(d["余量"]) and bool(d["是偶数"]) and int(d["余量"]) % 2 == 0 and int(d["余量"]) > 0):
			明细对 = false
	t.ok(明细对, "推进剂明细 4 层：余量表 = 余量、恒偶数（2 / 2 / 4 / 4）")

	# ---- 招募券 ----
	var 券块: Array = data["招募券"]
	var 券对 := 券块.size() == 8
	for raw3 in 券块:
		var q: Dictionary = GoldenCompare.decode(raw3)
		if (q["开局券"] as Array).size() != 3: 券对 = false
		for c in q["开局券"]:
			if not (J.truthy(c.get("名")) and (c.get("类") == "职业" or c.get("类") == "势力")): 券对 = false
		if (q["随机"] as Array).size() != 5 or (q["战后"] as Array).size() != 3: 券对 = false
		# 第 1 张 = 分队券：分队是职业 / 势力时名字必须等于分队名
		var 分 := String(q["分队券"]["分队"])
		if J.inc(Db.T.CLASSES, 分) or J.inc(Db.T.FACTIONS, 分):
			if q["分队券"]["开局券"][0]["名"] != 分: 券对 = false
	t.ok(券对, "招募券 8 局：开局 3 张（第 1 张是分队券）/ 随机 5 偏移 / 战后 3 档")

	# ---- 晋升面板 ----
	var 面板: Array = data["晋升面板"]
	var 键集 := {}
	var 面板对 := true
	for raw4 in 面板:
		var p: Dictionary = GoldenCompare.decode(raw4)
		键集[p["键"]] = true
		var 档 := int(p["前"]["lv"])
		if not (档 == 10 or 档 == 20) or int(p["后"]["lv"]) != 档 + 10 or int(p["到"]) != 档 + 10: 面板对 = false
		if float(p["后"]["maxHp"]) <= float(p["前"]["maxHp"]) or float(p["价"]) < 0.0: 面板对 = false
	t.ok(键集.size() == 名册人数 and 面板.size() == 名册人数 * 2 and 面板对,
		"晋升面板 %d 条 = %d 名机师 × Lv10/Lv20，前后同键、后档更高、价格非负" % [面板.size(), 键集.size()])

	# ---- 三选一战术牌 ----
	var 三选一: Array = data["战术牌三选一"]
	var 三对 := 三选一.size() == 名册人数
	for raw5 in 三选一:
		var c: Dictionary = GoldenCompare.decode(raw5)
		var 候选: Array = c["候选"]
		if 候选.is_empty() or 候选.size() > 3 or not bool(c["选成功"]): 三对 = false
		var 去重 := {}
		for id in 候选:
			去重[id] = true
		if 去重.size() != 候选.size(): 三对 = false
		var 选后: Array = c["选后再候选"]
		if J.inc(选后, 候选[0]) or 选后.size() >= 候选.size() + 1: 三对 = false
	t.ok(三对, "三选一 %d 条：候选 ≤3 且不重复、选走第一张后不再出现（排除了战术牌库）" % 三选一.size())
