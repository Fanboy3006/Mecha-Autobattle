## RT-2d：原生黄金样例（Godot 原生标准答案）逐场重跑并对拍 —— 这是本仓唯一的战斗黄金样例。
## 期望值由 `tools/record_native_golden.gd` 用生产选项 + 确定性出牌策略录出（连录两次逐字节相同）。
extends RefCounted

const 目录 := "res://tests/golden/native"
## ★ COL-5：+4 场（`colonial` 分区：殖民卫星军五人 × 2 套久战敌方规格 × 2 种子）。
const 期望条数 := 180
## 策略源码里出现这些 = 抽了随机数（读 `ctx.rng.steps` 不算）。
const 抽随机数的记号 := ["next_float", "randi(", "randf(", "randomize(", "rand_from_seed"]

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db")
	var 输入表 := _输入表(t)
	var 文件们 := _样例文件们()
	t.ok(文件们.size() >= 5, "native/ 下 %d 个样例文件（含按势力拆开的 faction_*）" % 文件们.size())
	var 总 := 0
	var 分叉 := 0
	var 策略错误 := 0
	var 选择rng := 0
	var 首场: Dictionary = {}
	for 文件 in 文件们:
		var d := GoldenIO.load_json("%s/%s" % [目录, 文件])
		var 样: Array = d.get("样例", [])
		t.info("%s：%d 场" % [文件, 样.size()])
		for s in 样:
			var id := str((s as Dictionary).get("id", ""))
			var 输入: Dictionary = 输入表.get(id, {})
			if 输入.is_empty():
				分叉 += 1
				if 分叉 <= 5:
					t.ok(false, "%s 在 inputs.json 里找不到输入" % id)
				continue
			var r := NativeGoldenRunner.run(输入)
			if r.has("错误"):
				分叉 += 1
				if 分叉 <= 5:
					t.ok(false, "%s 开局失败：%s" % [id, str(r["错误"])])
				continue
			总 += 1
			策略错误 += (r["策略错误"] as Array).size()
			选择rng += int(r["策略rng步数"])
			if 首场.is_empty():
				首场 = {"输入": 输入, "期望": r["期望"]}
			var 差 := NativeGoldenRunner.compare(s, r)
			if 差 != "":
				分叉 += 1
				if 分叉 <= 5:
					t.ok(false, 差)
	t.ok(总 == 期望条数, "★ 重跑 %d 场（期望 %d）" % [总, 期望条数])
	t.ok(策略错误 == 0, "★ 策略没有一张「选中了却打不出来」（%d 处）" % 策略错误)
	t.ok(选择rng == 0, "★★ 策略选牌一次随机数都不抽（%d 步；读 ctx.rng.steps 不算抽）" % 选择rng)
	t.ok(分叉 == 0, "★ 逐场逐条一致（分叉 %d 场）" % 分叉)
	_同种子两遍(t, 首场)
	_策略源码(t)

func _输入表(t) -> Dictionary:
	var 入 := GoldenIO.load_json("%s/inputs.json" % 目录)
	var 样: Array = 入.get("样例", [])
	t.ok(样.size() == 期望条数, "inputs.json 共 %d 条输入（期望 %d）" % [样.size(), 期望条数])
	var 表 := {}
	for s in 样:
		if s is Dictionary:
			# `inputs.json` 里的非整数是 `{"$f": 位串}`，必须先解码（否则强化 / 等级会当成字典用）。
			表[str((s as Dictionary).get("id", ""))] = GoldenCompare.decode(s)
	return 表

## 目录里除 `inputs.json` 之外的样例文件（`faction` 按势力拆成了 `faction_<势力>.json`）。
func _样例文件们() -> Array:
	var 出: Array = []
	var dir := DirAccess.open(目录)
	if dir == null:
		return 出
	for f in dir.get_files():
		if f.ends_with(".json") and f != "inputs.json":
			出.append(f)
	出.sort()
	return 出

## 同一份输入跑两遍，期望结构逐字节相同（从旧 `test_battle_rules.gd` 迁过来的那一条）。
func _同种子两遍(t, 首场: Dictionary) -> void:
	if 首场.is_empty():
		t.ok(false, "没有可复用的首场（前面的重跑全失败）")
		return
	var a := NativeGoldenRunner.run(首场["输入"])
	var b := NativeGoldenRunner.run(首场["输入"])
	var sa := JSON.stringify(GoldenIO.encode(a["期望"]))
	var sb := JSON.stringify(GoldenIO.encode(b["期望"]))
	t.ok(sa == sb and not sa.is_empty(), "★ 同一份输入跑两遍，事件与回合摘要逐字节相同（%d 字节）" % sa.length())

## 策略源码里不许出现抽随机数的调用（`ctx.rng.steps` 是**读**，允许）。
func _策略源码(t) -> void:
	var f := FileAccess.open("res://tests/native_golden_policy.gd", FileAccess.READ)
	t.ok(f != null, "读得到 tests/native_golden_policy.gd")
	if f == null:
		return
	var 源 := f.get_as_text()
	var 命中: Array = []
	for 记号 in 抽随机数的记号:
		if 源.contains(记号):
			命中.append(记号)
	t.ok(命中.is_empty(), "★ 策略源码里没有抽随机数的调用（命中 %s）" % str(命中))
	t.ok(源.contains("CardPlay.不可打原因"), "策略的「能不能打」用的是 `CardPlay.不可打原因`（界面置灰的同一个函数）")
