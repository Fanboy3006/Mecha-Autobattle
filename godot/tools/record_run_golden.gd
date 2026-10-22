## 职责：headless 录**局外（肉鸽）黄金样例** —— 地图 / 推进剂 / 招募券 / 晋升面板 / 三选一战术牌，
##       全部由 Godot 内核现算，写到 `tests/golden/run_vectors.json`（连跑两次应逐字节相同）。
## 用法（仓库根目录）：godot --headless --path godot --script res://tools/record_run_golden.gd
## 口径：8 个固定种子 × 4 层；名册人数 / 战术牌张数从**当前数据**取（不再写死 34 / 32）。
extends SceneTree

const 输出 := "res://tests/golden/run_vectors.json"
const 种子们 := [20261010, 20261011, 20261012, 20261013, 20261014, 20261015, 20261016, 20261017]
const 层们 := [1, 2, 3, 4]
const 分队 := "无"

func _initialize() -> void:
	var errs := []
	if not DataLoader.install(errs):
		print("✗ 数据装不进去：%s" % str(errs))
		quit(1)
		return
	var 名册: Array = RosterManager.名册键们()
	var 牌数 := (Db.T.get("战术卡牌表") as Array).size()
	print("名册 %d 人 · 战术牌 %d 张 · 种子 %d 个 × 层 %d 层" % [名册.size(), 牌数, 种子们.size(), 层们.size()])

	var 地图: Array = []
	var 推进剂明细: Array = []
	for 种子 in 种子们:
		var s: RunState = RosterManager.new_run(int(种子), 分队)
		for 层 in 层们:
			MapNavigator.enter_floor(s, int(层))
			var 账: Dictionary = MapGenerator.propellant_detail(s)
			var 上限 := MapGenerator.propellant_max(s)
			地图.append(GoldenIO.encode({
				"种子": float(种子), "层": float(层),
				"地图种子": float(MapGenerator.map_seed(int(种子), int(层))),
				"形状": MapGenerator.shape(int(层)),
				"地图": s.map_data,
				"推进剂": {"上限": float(上限), "账": 账, "进层后实发": float(s.propellant)},
			}))
			if s.propellant != 上限:
				print("✗ 种子 %s 第 %s 层：进层实发推进剂 ≠ 上限" % [J.s(种子), J.s(层)])
				quit(1)
				return
	for 层 in 层们:
		推进剂明细.append(GoldenIO.encode(MapGenerator.remainder_detail(int(层))))

	var 招募券: Array = []
	for 种子 in 种子们:
		var s2: RunState = RosterManager.new_run(int(种子), 分队)
		var 开局券: Array = []
		for c in s2.tickets:
			开局券.append(_券条(c))
		var 随机: Array = []
		for i in 5:
			var 选: Dictionary = RosterManager.随机券(s2, i)
			随机.append({"偏移": float(i), "类": str(选.get("类")) if not 选.is_empty() else null,
				"名": str(选.get("名")) if not 选.is_empty() else null})
		var 战后: Array = []
		for 档 in ["战斗", "精英", "Boss"]:
			var 券: Variant = RosterManager.掷战后券(s2, 档)
			战后.append({"档": 档, "券": null if 券 == null else _券条(券)})
		var 手上: Array = []
		for c in s2.tickets:
			手上.append(_券条(c))
		var 分队名 := str((Db.T.get("CLASSES") as Array)[0]) if not (Db.T.get("CLASSES") as Array).is_empty() else "无"
		var s3: RunState = RosterManager.new_run(int(种子), 分队名)
		var 队券: Array = []
		for c in s3.tickets:
			队券.append(_券条(c))
		招募券.append(GoldenIO.encode({
			"种子": float(种子), "分队": 分队, "开局券": 开局券, "随机": 随机, "战后": 战后,
			"分队券": {"分队": 分队名, "开局券": 队券}, "发券后手上": 手上,
		}))

	var 晋升面板: Array = []
	var 一局: RunState = RosterManager.new_run(20261010, 分队)
	for 键 in 名册:
		for 等级 in [10, 20]:
			var 预览: Dictionary = RosterManager.晋升预览(str(键), int(等级))
			if 预览.get("前") is not Dictionary or (预览.get("前") as Dictionary).is_empty():
				print("✗ 晋升预览（%s @ Lv%d）拿不到模板 —— 名册与数据脱节，录音中止" % [str(键), int(等级)])
				quit(1)
				return
			晋升面板.append(GoldenIO.encode({
				"职业": str(RosterManager.标签(键).get("战斗分类")),
				"势力": str(RosterManager.标签(键).get("势力")),
				"键": str(键), "前": 预览["前"], "后": 预览["后"], "到": 预览["到"],
				"价": float(RosterManager.晋升要多少(str(键), int(预览["到"]), 一局)),
			}))

	var 三选一: Array = []
	for 键 in 名册:
		var s4: RunState = RosterManager.new_run(20261010, 分队)
		var 候选: Array = _ids(DeckBuilder.offer_cards(s4, str(键), 3))
		var s5: RunState = RosterManager.new_run(20261010, 分队)
		var 第一次: Array = _ids(DeckBuilder.offer_cards(s5, str(键), 3))
		var 选了 := DeckBuilder.select_card(s5, str(第一次[0])) if not 第一次.is_empty() else false
		var 再来: Array = _ids(DeckBuilder.offer_cards(s5, str(键), 3))
		三选一.append(GoldenIO.encode({
			"键": str(键), "职业": str(RosterManager.标签(键).get("战斗分类")),
			"势力": str(RosterManager.标签(键).get("势力")),
			"候选": 候选, "第一次": 第一次, "选成功": 选了, "选后再候选": 再来,
		}))

	var 输出字典 := {
		"meta": {
			"来源": "Godot 原生（COL-1.1 起；旧的 JS 参考版导出已归档到 协作/归档/run_vectors-JS参考版.json）",
			"tag": "godot-native-col1",
			"rulesSignature": str(_清单().get("rulesSignature")),
			"生成": "godot --headless --path godot --script res://tools/record_run_golden.gd",
			"口径": "局外（肉鸽）：地图生成 / 推进剂 / 招募券 / 晋升面板 / 三选一战术牌；全部由 Godot 内核现算，同种子同输入逐字相同（0 界面依赖）",
			"名册人数": float(名册.size()), "战术牌张数": float(牌数), "种子们": 种子们,
		},
		"地图": 地图, "推进剂明细": 推进剂明细, "招募券": 招募券, "晋升面板": 晋升面板, "战术牌三选一": 三选一,
	}
	var f := FileAccess.open(输出, FileAccess.WRITE)
	if f == null:
		print("✗ 写不进去：%s" % 输出)
		quit(1)
		return
	f.store_string(JSON.stringify(输出字典))
	f.close()
	print("  地图 %d 张 · 推进剂明细 %d 层 · 招募券 %d 局 · 晋升面板 %d 条 · 三选一 %d 条" % [
		地图.size(), 推进剂明细.size(), 招募券.size(), 晋升面板.size(), 三选一.size()])
	print("✓ 已写 → %s" % 输出)
	quit(0)

func _券条(c: Variant) -> Dictionary:
	return {"类": RosterManager.券类(c), "名": str((c as Dictionary)["名"]),
		"档": (c as Dictionary).get("档"), "来源": str((c as Dictionary)["来源"])}

func _ids(牌们: Array) -> Array:
	var 出: Array = []
	for c in 牌们:
		if c is Dictionary:
			出.append(str((c as Dictionary).get("id", "")))
		elif c is String or c is StringName:
			出.append(str(c))
	return 出

func _清单() -> Dictionary:
	return GoldenIO.load_json("res://data/js/manifest.json")
