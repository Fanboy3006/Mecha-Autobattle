## 职责：headless 录原生黄金样例 —— 按 `tests/golden/native/inputs.json` 逐场跑 `NativeGoldenRunner`，
##       写到 `tests/golden/native/<组>.json`（连跑两次应逐字节相同）。
## 用法（仓库根目录）：godot --headless --path godot --script res://tools/record_native_golden.gd
extends SceneTree

const 输入 := "res://tests/golden/native/inputs.json"
const 输出目录 := "res://tests/golden/native"

func _initialize() -> void:
	var errs := []
	if not DataLoader.install(errs):
		print("✗ 数据装不进去：%s" % str(errs))
		quit(1)
		return
	var 入 := GoldenIO.load_json(输入)
	var 样例们: Array = 入.get("样例", [])
	if 样例们.is_empty():
		print("✗ %s 里没有样例（先跑 res://tools/extract_native_inputs.gd）" % 输入)
		quit(1)
		return
	var 按组 := {}
	for s in 样例们:
		if not (s is Dictionary):
			continue
		var 组 := str((s as Dictionary).get("分文件", (s as Dictionary).get("组", "")))
		if not 按组.has(组):
			按组[组] = []
		(按组[组] as Array).append(GoldenCompare.decode(s))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(输出目录))
	var 组名们: Array = 按组.keys()
	组名们.sort()
	var 总事件 := 0
	var 总场 := 0
	var 全出牌 := {}
	var 全事件类型 := {}
	var 结局 := {}
	var 按区 := {}
	var Boss场 := 0
	var 带波次场 := 0
	for 组 in 组名们:
		var 样: Array = 按组[组]
		var 出: Array = []
		var 组事件 := 0
		var 组出牌 := 0
		var 策略错误: Array = []
		var 策略rng := 0
		for s in 样:
			var r := NativeGoldenRunner.run(s)
			if r.has("错误"):
				print("✗ %s：%s" % [str(r.get("id", "")), str(r["错误"])])
				quit(1)
				return
			var 期望: Dictionary = r["期望"]
			组事件 += (期望["事件"] as Array).size()
			组出牌 += (r["出牌"] as Array).size()
			策略rng += int(r["策略rng步数"])
			for p in (r["出牌"] as Array):
				全出牌[str((p as Dictionary).get("牌", ""))] = {"名": str((p as Dictionary).get("牌名", "")),
					"区": str((p as Dictionary).get("区", ""))}
				var 区键 := str((p as Dictionary).get("区", ""))
				按区[区键] = int(按区.get(区键, 0)) + 1
			for e in (期望["事件"] as Array):
				var 型 := str((e as Dictionary).get("类型", "（无类型）"))
				全事件类型[型] = int(全事件类型.get(型, 0)) + 1
			var 结 := str((期望["结果"] as Dictionary).get("结果", ""))
			结局[结] = int(结局.get(结, 0)) + 1
			if str((((s as Dictionary).get("编成", {}) as Dictionary)).get("类型", "")) == "Boss":
				Boss场 += 1
			var 真条目 := NativeGoldenRunner.认编成(s)
			if not 真条目.is_empty() and not NodeResolver.增援波次(真条目, 0).is_empty():
				带波次场 += 1
			if not (r["策略错误"] as Array).is_empty():
				策略错误.append("%s · %s" % [str(r["id"]), " / ".join(r["策略错误"])])
			期望["回合摘要"] = NativeGoldenRunner.压缩(期望["回合摘要"])
			出.append({"id": str(r["id"]), "期望": GoldenIO.encode(期望)})
		var 路径 := "%s/%s.json" % [输出目录, 组]
		var f := FileAccess.open(路径, FileAccess.WRITE)
		if f == null:
			print("✗ 写不进去：%s" % 路径)
			quit(1)
			return
		f.store_string(JSON.stringify({
			"meta": {
				"文件": 组, "条数": 出.size(), "事件数": 组事件,
				"生成": "godot --headless --path godot --script res://tools/record_native_golden.gd",
				"来源": "输入来自 tests/golden/native/inputs.json",
				"口径": "生产选项（SessionBattleOptions.生产）+ 确定性出牌策略（NativeGoldenPolicy）；回合摘要只记新模式白名单字段",
			},
			"样例": 出,
		}))
		f.close()
		var 字节 := FileAccess.get_file_as_bytes(路径).size()
		总事件 += 组事件
		总场 += 出.size()
		print("  %-9s %3d 场 · %5d 事件 · %6d 出牌 · %8.1f KB" % [组, 出.size(), 组事件, 组出牌, float(字节) / 1024.0])
		if not 策略错误.is_empty():
			print("    ⚠ 策略打不出来 %d 处：%s" % [策略错误.size(), 策略错误[0]])
		if 策略rng != 0:
			print("    ✗ 策略抽了 %d 次随机数（应为 0）" % 策略rng)
	print("✓ 合计 %d 场 · %d 事件 · 带波次 %d 场" % [总场, 总事件, 带波次场])
	_覆盖报告(总场, 总事件, 全出牌, 全事件类型, 结局, 按区, Boss场, 带波次场)
	quit(0)


## RT-2e：覆盖自检（打出过哪些卡 / 哪些事件 / 结局 / Boss / 新模式下一次都没打出的卡）。**加 `--coverage` 才打印**。
func _覆盖报告(总场: int, 总事件: int, 全出牌: Dictionary, 全事件类型: Dictionary, 结局: Dictionary, 按区: Dictionary, Boss场: int, 带波次场: int) -> void:
	# 覆盖自检默认安静：加 `--coverage` 才打全表，平时只有上面那几行汇总。
	if not ("--coverage" in OS.get_cmdline_user_args()) and not ("--coverage" in OS.get_cmdline_args()):
		return
	print("")
	print("[覆盖] 场数 %d · 事件 %d · 结局 %s · Boss 场 %d · 带波次 %d 场 · 增援事件 %d 条" % [
		总场, 总事件, str(结局), Boss场, 带波次场, int(全事件类型.get("增援", 0))])
	print("[覆盖] 出牌按区 %s" % str(按区))
	print("[覆盖] 事件类型 %s" % str(全事件类型))
	var 宇宙 := _卡宇宙()
	var 缺口: Array = []
	for id in 宇宙.keys():
		if not 全出牌.has(id):
			缺口.append("%s〔%s〕" % [str(id), str((宇宙[id] as Dictionary).get("层级", ""))])
	缺口.sort()
	var 打出过的 := 0
	for id in 全出牌.keys():
		if 宇宙.has(id):
			打出过的 += 1
	print("[覆盖] 打出过的卡 id %d 个（卡库 %d 个 · 打出过且在库里 %d 个）" % [全出牌.size(), 宇宙.size(), 打出过的])
	var 库外: Array = []
	for id in 全出牌.keys():
		if not 宇宙.has(id):
			库外.append(str(id))
	库外.sort()
	if not 库外.is_empty():
		print("[覆盖] 打出过但不在卡库里的 id %d 个（衍生 / 未登记的牌）：%s" % [库外.size(), "、".join(库外)])
	print("[缺口] 新模式下有、但一次都没打出过的卡 %d 张：%s" % [缺口.size(), "、".join(缺口)])

## 「新模式下有的卡」：`data/cards/*.json` 各卡包的 `结构` 段 + 基础表里新模式在用的统帅 / 角色牌。
func _卡宇宙() -> Dictionary:
	var 出 := {}
	var 包们: Variant = Db.T.get("卡包")
	if 包们 is Dictionary:
		for 包名 in (包们 as Dictionary).keys():
			var 包: Dictionary = (包们 as Dictionary)[包名]
			var 结构: Variant = 包.get("结构")
			if 结构 is Dictionary:
				for 段 in (结构 as Dictionary).keys():
					_收卡(包.get(段), 出)
	var 表: Variant = Db.T.get("战术卡牌表")
	if 表 is Array:
		for c in (表 as Array):
			if c is Dictionary and str((c as Dictionary).get("层级", "")) in ["统帅", "角色"]:
				出[str((c as Dictionary).get("id", ""))] = {"层级": str((c as Dictionary).get("层级", ""))}
	return 出

func _收卡(v: Variant, 出: Dictionary) -> void:
	if v is Array:
		for x in (v as Array):
			_收卡(x, 出)
	elif v is Dictionary:
		if (v as Dictionary).get("id") != null and ((v as Dictionary).get("名") != null or (v as Dictionary).get("卡类") != null):
			出[str((v as Dictionary).get("id"))] = {"层级": str((v as Dictionary).get("卡类", (v as Dictionary).get("层级", "")))}
		for k in (v as Dictionary).keys():
			_收卡((v as Dictionary)[k], 出)
