## 职责：§0.3 原生样例差异摘要 —— 只统计两份录制（重录前 / 重录后），不打开内容给人看。
## 用法：godot --headless --path godot --script res://tools/diff_native_summary.gd [-- <旧目录> <新目录>]
##   默认 旧 = res://tests/golden/_br1_before、新 = res://tests/golden/native
extends SceneTree

const 默认旧 := "res://tests/golden/_br1_before"
const 默认新 := "res://tests/golden/native"
const 翻转最多 := 10

func _initialize() -> void:
	var 参 := OS.get_cmdline_user_args()
	var 旧目录 := str(参[0]) if 参.size() > 0 else 默认旧
	var 新目录 := str(参[1]) if 参.size() > 1 else 默认新
	var dir := DirAccess.open(旧目录)
	if dir == null:
		print("✗ 找不到旧录制目录 %s（先把 native/ 复制一份过去）" % 旧目录)
		quit(1)
		return
	var 文件们: Array = []
	for f in dir.get_files():
		if f.ends_with(".json") and f != "inputs.json":
			文件们.append(f)
	文件们.sort()
	var 全事件旧 := {}
	var 全事件新 := {}
	var 翻转: Array = []
	var 总场 := 0
	var 总差场 := 0
	print("旧 = %s" % 旧目录)
	print("新 = %s\n" % 新目录)
	for 文件 in 文件们:
		var 旧 := GoldenIO.load_json("%s/%s" % [旧目录, 文件])
		var 新 := GoldenIO.load_json("%s/%s" % [新目录, 文件])
		if 旧.is_empty() or 新.is_empty():
			print("  %-16s ✗ 读不进来（旧空 %s / 新空 %s）" % [文件, str(旧.is_empty()), str(新.is_empty())])
			continue
		var 新表 := {}
		for s in (新.get("样例", []) as Array):
			if s is Dictionary:
				新表[str((s as Dictionary).get("id", ""))] = s
		var 计 := _新计()
		var 新计 := _新计()
		var 差场 := 0
		for o in (旧.get("样例", []) as Array):
			if not (o is Dictionary):
				continue
			var id := str((o as Dictionary).get("id", ""))
			var n: Dictionary = 新表.get(id, {})
			if n.is_empty():
				continue
			var o期: Dictionary = (o as Dictionary).get("期望", {})
			var n期: Dictionary = n.get("期望", {})
			var o结 := _结(o期)
			var n结 := _结(n期)
			_攒(计, o结)
			_攒(新计, n结)
			var o事: Array = GoldenCompare.decode(o期.get("事件", []))
			var n事: Array = GoldenCompare.decode(n期.get("事件", []))
			计["事件"] = int(计["事件"]) + o事.size()
			新计["事件"] = int(新计["事件"]) + n事.size()
			for e in o事:
				_加(全事件旧, str((e as Dictionary).get("类型", "")))
			for e in n事:
				_加(全事件新, str((e as Dictionary).get("类型", "")))
			var o摘: Array = NativeGoldenRunner.展开(GoldenCompare.decode(o期.get("回合摘要", [])))
			var n摘: Array = NativeGoldenRunner.展开(GoldenCompare.decode(n期.get("回合摘要", [])))
			if 有差异(o事, n事) or 有差异(o摘, n摘):
				差场 += 1
			var a := str(o结.get("结果", ""))
			var b := str(n结.get("结果", ""))
			if a != b:
				翻转.append("%s（%s→%s）" % [id, a, b])
		总场 += 计["场"]
		总差场 += 差场
		print("%-16s 场 %3d · 胜/败 %s → %s · 平均回合 %.1f → %.1f · 事件 %d → %d · 有差异 %d 场" % [
			文件.trim_suffix(".json"), 计["场"], _胜败(计), _胜败(新计), _均(计), _均(新计), 计["事件"], 新计["事件"], 差场])
	print("\n[事件类型] 只列条数变了的（旧 → 新）：")
	var 型们: Array = 全事件旧.keys()
	for k in 全事件新.keys():
		if not 型们.has(k):
			型们.append(k)
	型们.sort()
	var 变了型 := 0
	for k in 型们:
		var a := int(全事件旧.get(k, 0))
		var b := int(全事件新.get(k, 0))
		if a != b:
			变了型 += 1
			print("  %-12s %6d → %6d（%+d）" % [k, a, b, b - a])
	if 变了型 == 0:
		print("  （无：事件按类型逐项相同）")
	print("\n[结果翻转] %d 场%s" % [翻转.size(), ("，只列前 %d 场：" % 翻转最多) if 翻转.size() > 翻转最多 else "："])
	for i in mini(翻转.size(), 翻转最多):
		print("  " + str(翻转[i]))
	print("\n[合计] %d 场 · 有差异 %d 场 · 结果翻转 %d 场" % [总场, 总差场, 翻转.size()])
	quit(0)

func _新计() -> Dictionary:
	return {"场": 0, "胜": 0, "败": 0, "回合和": 0.0, "回合数": 0, "事件": 0}

func _攒(计: Dictionary, 结: Dictionary) -> void:
	计["场"] = int(计["场"]) + 1
	if str(结.get("结果", "")) == "胜":
		计["胜"] = int(计["胜"]) + 1
	else:
		计["败"] = int(计["败"]) + 1
	var t := float(结.get("回合", 0.0))
	if t > 0.0:
		计["回合和"] = float(计["回合和"]) + t
		计["回合数"] = int(计["回合数"]) + 1

func _胜败(计: Dictionary) -> String:
	return "%d/%d" % [int(计["胜"]), int(计["败"])]

func _均(计: Dictionary) -> float:
	var n := int(计["回合数"])
	return float(计["回合和"]) / float(n) if n > 0 else 0.0

## 两份事件列表有没有任何一处不同（含条数）。
func 有差异(旧: Array, 新: Array) -> bool:
	if 旧.size() != 新.size():
		return true
	for i in 旧.size():
		if GoldenCompare.diff(旧[i], 新[i], "") != "":
			return true
	return false

func _结(期: Dictionary) -> Dictionary:
	var r = GoldenCompare.decode(期.get("结果", {}))
	return r if r is Dictionary else {}

func _加(表: Dictionary, 键: String) -> void:
	表[键] = int(表.get(键, 0)) + 1
