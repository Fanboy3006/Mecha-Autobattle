## 战斗黄金样例（从 JS 参考版导出，godot/tools/export_golden.mjs）。
## M1：校验样例文件完整、可解码，比对器能抓到分叉。
## M2：Battle Core 落地后，这里逐场重跑并与期望比对（全部通过 = 战斗玩法迁移完成）。
extends RefCounted

const GROUPS := ["default", "faction", "character", "card_baseline"]
const EXPECTED_SIGNATURE := "r1:05a9cbf9"

func run(t) -> void:
	var total := 0
	var all_samples := []
	for g in GROUPS:
		var data := GoldenIO.load_json("res://tests/golden/battle/%s.json" % g)
		var meta: Dictionary = data.get("meta", {})
		var samples: Array = data.get("样例", [])
		var events := 0
		var ok_shape := true
		for s in samples:
			events += (s["期望"]["事件"] as Array).size()
			ok_shape = ok_shape and s.has("输入") and s.has("命令") and (s["期望"]["回合摘要"] as Array).size() >= 1
		t.ok(samples.size() == int(meta.get("场数", -1)) and events == int(meta.get("事件数", -1)) and ok_shape,
			"%s：%d 场、%d 条事件，与 meta 一致，结构完整" % [g, samples.size(), events])
		t.ok(meta.get("rulesSignature", "") == EXPECTED_SIGNATURE, "%s 来自封存的 JS 参考版" % g)
		total += samples.size()
		all_samples.append_array(samples)
	t.ok(total == 138, "黄金样例共 %d 场" % total)

	# 比对器自检：样例与自身比对 = 相同；改动一个伤害值 = 报出第一处分叉
	var s: Dictionary = all_samples[0]
	var actual: Array = (s["期望"]["事件"] as Array).map(func(e): return GoldenCompare.decode(e))
	t.ok(GoldenCompare.compare_events(s, actual) == "", "比对器：样例与自身比对无差异")
	var idx := -1
	for i in actual.size():
		if actual[i].get("类型") == "攻击" and actual[i].has("伤害"):
			idx = i
			break
	if idx >= 0:
		var tampered := actual.duplicate(true)
		tampered[idx]["伤害"] = float(tampered[idx]["伤害"]) + 1.0
		var report := GoldenCompare.compare_events(s, tampered)
		t.ok(report.contains("事件[%d].伤害" % idx), "比对器：改动 1 点伤害能定位到第一处分叉 → %s" % report)
	var short := actual.slice(0, actual.size() - 1)
	t.ok(GoldenCompare.compare_events(s, short).contains("事件数不同"), "比对器：少一条事件能报出来")

	# 浮点无损解码：样例里的 $f 位串还原后是有限数
	var floats := 0
	for e in actual:
		for k in e.keys():
			if e[k] is float and not is_finite(e[k]):
				floats = -1
	t.ok(floats == 0, "样例数值解码正常")
	t.info("Battle Core 尚未实现（M2）：%d 场待对拍" % total)
