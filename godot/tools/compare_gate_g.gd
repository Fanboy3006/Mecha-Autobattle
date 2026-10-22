## 职责：闸门 G 的**签字依据** —— 把「删前」那份原生样例里的 `类型 == "发牌"` 事件去掉，再与「删后」那份逐条对比
##        （事件含 `_rng`、回合摘要逐项、结果），只报第一处分叉。
## 用法：godot --headless --path godot --script res://tools/compare_gate_g.gd
##   旧 = `res://tests/golden/_gateG_before`（闸门 G 之前的录制，直接从 native/ 复制的那份）
##   新 = `res://tests/golden/native`（闸门 G 之后重录的那份）
extends SceneTree

const 旧目录 := "res://tests/golden/_gateG_before"
const 新目录 := "res://tests/golden/native"
const 要去掉 := "发牌"

func _initialize() -> void:
	var 文件们: Array = []
	var dir := DirAccess.open(旧目录)
	if dir == null:
		print("✗ 找不到 %s（先把 native/ 复制一份过去）" % 旧目录)
		quit(1)
		return
	for f in dir.get_files():
		if f.ends_with(".json") and f != "inputs.json":
			文件们.append(f)
	文件们.sort()
	var 总场 := 0
	var 总去 := 0
	var 总差 := 0
	var 首处分叉 := ""
	for 文件 in 文件们:
		var 旧 := GoldenIO.load_json("%s/%s" % [旧目录, 文件])
		var 新 := GoldenIO.load_json("%s/%s" % [新目录, 文件])
		var 新表 := {}
		for s in (新.get("样例", []) as Array):
			if s is Dictionary:
				新表[str((s as Dictionary).get("id", ""))] = s
		var 场 := 0
		var 去 := 0
		var 差 := 0
		for o in (旧.get("样例", []) as Array):
			if not (o is Dictionary):
				continue
			var id := str((o as Dictionary).get("id", ""))
			var o期: Dictionary = (o as Dictionary).get("期望", {})
			var n: Dictionary = 新表.get(id, {})
			if n.is_empty():
				差 += 1
				if 首处分叉 == "":
					首处分叉 = "%s · 新那份里没有这一场" % id
				continue
			场 += 1
			var n期: Dictionary = n.get("期望", {})
			# ---- 事件：旧那份去掉「发牌」→ 与新逐条比（含 _rng）----
			var 旧事件: Array = []
			for e in (o期.get("事件", []) as Array):
				if e is Dictionary and str((e as Dictionary).get("类型", "")) == 要去掉:
					去 += 1
					continue
				旧事件.append(GoldenCompare.decode(e))
			var 新事件: Array = []
			for e in (n期.get("事件", []) as Array):
				新事件.append(GoldenCompare.decode(e))
			var d := _比事件(id, 旧事件, 新事件)
			if d == "":
				d = _比摘要(id, o期.get("回合摘要", []), n期.get("回合摘要", []))
			if d == "":
				d = GoldenCompare.diff(GoldenCompare.decode(o期.get("结果", {})), n期.get("结果", {}), "结果")
			if d != "":
				差 += 1
				if 首处分叉 == "":
					首处分叉 = d
		总场 += 场
		总去 += 去
		总差 += 差
		print("  %-24s %3d 场 · 去掉 %4d 条「发牌」 · 分叉 %d" % [文件, 场, 去, 差])
	print("")
	print("[闸门 G] 合计 %d 场 · 去掉 %d 条「发牌」 · 分叉 %d" % [总场, 总去, 总差])
	if 总差 == 0:
		print("✓ 通过：除了被去掉的「发牌」事件，其余事件（含 _rng）、回合摘要、结果**逐条相同**")
		quit(0)
	else:
		print("✗ 有 %d 场出现「发牌」以外的差异 —— **不要重录**，把下面这行贴进回执等判：" % 总差)
		print("   第一处：" + 首处分叉)
		quit(1)

func _比事件(id: String, 旧事件: Array, 新事件: Array) -> String:
	for i in mini(旧事件.size(), 新事件.size()):
		var d := GoldenCompare.diff(旧事件[i], 新事件[i], "事件[%d]" % i)
		if d != "":
			return "%s · 第 %s 回合 · %s · 当时随机数 %s 次" % [id, str((旧事件[i] as Dictionary).get("回合", -1)), d,
				str((旧事件[i] as Dictionary).get("_rng", -1))]
	if 旧事件.size() != 新事件.size():
		return "%s · 事件数不同（旧去掉发牌后 %d，新 %d）" % [id, 旧事件.size(), 新事件.size()]
	return ""

func _比摘要(id: String, 旧摘要: Array, 新摘要: Array) -> String:
	var 旧展开 := NativeGoldenRunner.展开(GoldenCompare.decode(旧摘要))
	var 新展开 := NativeGoldenRunner.展开(GoldenCompare.decode(新摘要))
	for i in mini(旧展开.size(), 新展开.size()):
		var d := GoldenCompare.diff(旧展开[i], 新展开[i], "回合摘要[%d]" % i)
		if d != "":
			return "%s · 回合摘要[%d] · %s" % [id, i, d]
	if 旧展开.size() != 新展开.size():
		return "%s · 回合摘要数不同（旧 %d，新 %d）" % [id, 旧展开.size(), 新展开.size()]
	return ""
