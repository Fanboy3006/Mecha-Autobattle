## 职责：把旧战斗黄金样例的**输入**抽成 `tests/golden/native/inputs.json`（只取输入，不取期望）。
## 用法（仓库根目录）：godot --headless --path godot --script res://tools/extract_native_inputs.gd
##
## ⚠ RT-3a 起 `tests/golden/battle/*.json` 已经退役（说明归档在 `协作/归档/`）：这个脚本只有在「把旧大文件拿回来」时才对得上。
##   `tests/golden/native/inputs.json` 是它当年产出的那一份，**别重跑**。
##
## 取每条样例的 `id / 我方 / 敌方规格 / 种子 / 藏品 / 编成`；`card_baseline` 不要（它测的是旧手牌）。
## 末尾追加 `quick` 组：3 支快速测试队 × 第 1 层普通编成 × 3 个种子（用快速测试的真实路径开局）。
extends SceneTree

const 组们 := ["default", "faction", "character", "relic"]
const 输出 := "res://tests/golden/native/inputs.json"
const 快速队们 := ["秘银", "ATX", "天人"]
const 快速种子们 := [20261013, 20261014, 20261015]

func _initialize() -> void:
	var 全: Array = []
	for 组名 in 组们:
		var d := GoldenIO.load_json("res://tests/golden/battle/%s.json" % 组名)
		var 样: Array = d.get("样例", [])
		var n := 0
		for s in 样:
			if not (s is Dictionary):
				continue
			var 输入: Dictionary = (s as Dictionary).get("输入") if (s as Dictionary).get("输入") is Dictionary else {}
			if 输入.is_empty():
				continue
			var 条 := {
				"组": 组名, "id": str((s as Dictionary).get("id", "")),
				"我方": 输入.get("我方", []), "敌方规格": 输入.get("敌方规格", []),
				"种子": 输入.get("种子", 0), "编成": 输入.get("编成", {}),
				"分文件": _分文件(组名, str((s as Dictionary).get("id", ""))),
			}
			if 输入.has("藏品"):
				条["藏品"] = 输入["藏品"]
			全.append(条)
			n += 1
		print("  %-9s %d 条" % [组名, n])
	# quick 组：3 支快速测试队 × 第 1 层普通编成 × 3 个种子
	var s := GameSession.new()
	DataLoader.install([])
	var 条目: Dictionary = s._第几层普通编成(1)
	var 规格: Array = NodeResolver.编成到规格(条目, 0)
	var 快速数 := 0
	for 队 in 快速队们:
		var 编成: Array = []
		match 队:
			GameSession.快速测试_ATX: 编成 = s._ATX五人编成()
			GameSession.快速测试_天人: 编成 = s._天人五人编成()
			_: 编成 = s._秘银五人编成()
		for 种 in 快速种子们:
			全.append({"组": "quick", "id": "quick/%s-%d" % [队, 种], "快速测试阵容": 队, "分文件": "quick",
				"我方": 编成, "敌方规格": 规格, "种子": 种, "编成": 条目, "藏品": []})
			快速数 += 1
	print("  quick     %d 条（3 队 × 3 种子）" % 快速数)

	# 旧大文件里有 14 个 id 撞车（编成编号是 `undefined`，同一势力 4 条同名）——
	# 这里补 `#2..#4` 后缀去重，原始 id 留在 `原id` 里。
	var 已用 := {}
	var 改名 := 0
	for 条 in 全:
		var id := str((条 as Dictionary).get("id", ""))
		var n := int(已用.get(id, 0)) + 1
		已用[id] = n
		if n > 1:
			(条 as Dictionary)["原id"] = id
			(条 as Dictionary)["id"] = "%s#%d" % [id, n]
			改名 += 1
	if 改名 > 0:
		print("  （%d 条重复 id 已加 #n 后缀去重）" % 改名)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/golden/native"))
	var f := FileAccess.open(输出, FileAccess.WRITE)
	if f == null:
		print("✗ 写不进去：%s" % 输出)
		quit(1)
		return
	f.store_string(JSON.stringify({
		"说明": "RT-2b：从 tests/golden/battle/{default,faction,character,relic}.json 抽出的**输入**（我方 / 敌方规格 / 种子 / 编成 / 藏品），"
			+ "外加 quick 组（快速测试真路径）。`$f` 是 IEEE-754 小端位串，读的时候用 GoldenCompare.decode。",
		"来源": "tests/golden/battle/{default,faction,character,relic}.json（card_baseline 不要）",
		"样例": 全,
	}))
	f.close()
	print("✓ %d 条 → %s（%d 字节）" % [全.size(), 输出, FileAccess.get_file_as_bytes(输出).size()])
	quit(0)

## 输出文件按 `分文件` 切：`faction` 组按势力拆（单个文件才不超过 3 MB），其余一组一个文件。
static func _分文件(组名: String, id: String) -> String:
	if 组名 != "faction":
		return 组名
	var 斜 := id.find("/")
	var 位 := id.find("-Lv")
	if 斜 < 0 or 位 <= 斜 + 1:
		return "faction_其它"
	return "faction_%s" % id.substr(斜 + 1, 位 - 斜 - 1)
