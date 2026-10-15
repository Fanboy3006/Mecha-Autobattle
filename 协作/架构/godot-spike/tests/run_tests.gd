## 无界面测试入口：godot --headless --path . --script res://tests/run_tests.gd
## 退出码 0 = 全绿，1 = 有失败。CI 与本地都用这一条命令。
extends SceneTree

var _fails := 0
var _passes := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  ✓ " + msg)
	else:
		_fails += 1
		print("  ✗ " + msg)

## 把 16 位十六进制的 IEEE-754（小端）位串还原成 float，保证与 JS 逐位一致
func _bits(hex: String) -> float:
	var b := PackedByteArray()
	for i in 8:
		b.append(hex.substr(i * 2, 2).hex_to_int())
	return b.decode_double(0)

func _initialize() -> void:
	var f := FileAccess.open("res://tests/golden/rng_vectors.json", FileAccess.READ)
	if f == null:
		print("✗ 找不到 golden 向量")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())

	print("[1] Mulberry32 与 JS 逐位一致")
	var rng_table: Dictionary = data["rng"]
	for seed_key in rng_table.keys():
		var expected: Array = rng_table[seed_key]
		var r := Mulberry32.new(int(seed_key))
		var first_bad := -1
		for i in expected.size():
			if r.next_float() * 4294967296.0 != float(int(expected[i])):
				first_bad = i
				break
		_ok(first_bad == -1, "种子 %s：%d 次抽取%s" % [seed_key, expected.size(), "全部一致" if first_bad == -1 else "，第 %d 次分叉" % first_bad])

	print("[2] js_round 与 JS Math.round 一致（含负数 .5 与边界值）")
	var bad_rounds := []
	for pair in data["rounds"]:
		var x := _bits(pair[0])
		var got := JsCompat.js_round(x)
		if got != _bits(pair[1]):
			bad_rounds.append("%s→%s(期望 %s)" % [x, got, _bits(pair[1])])
	_ok(bad_rounds.is_empty(), "%d 个样本%s" % [data["rounds"].size(), "全部一致" if bad_rounds.is_empty() else "：" + ", ".join(bad_rounds)])
	_ok(round(-2.5) != JsCompat.js_round(-2.5), "对照：Godot 内置 round(-2.5)=%s，JS 是 -2 —— 规则代码必须用 js_round" % round(-2.5))

	print("[2b] 对照：Godot JSON 解析浮点会丢精度 → golden 文件里的浮点一律存位串")
	var lossy := 0
	for pair in data["jsonProbe"]:
		if float(pair[0]) != _bits(pair[1]):
			lossy += 1
	_ok(true, "%d / %d 个浮点经 JSON 文本解析后与原值不同（因此不能用 JSON 小数做对拍）" % [lossy, data["jsonProbe"].size()])

	print("[3] stable_sort 与 V8 稳定排序一致")
	var got_sorted := JsCompat.stable_sort(data["sortInput"], func(a, b): return a["k"] < b["k"])
	var ids := got_sorted.map(func(x): return int(x["id"]))
	var exp_ids: Array = data["sortExpected"].map(func(x): return int(x))
	_ok(ids == exp_ids, "40 个元素、5 组并列键：顺序%s" % ("一致" if ids == exp_ids else "不一致"))

	print("")
	print("%s 通过 %d · 失败 %d" % ["✓" if _fails == 0 else "✗", _passes, _fails])
	quit(0 if _fails == 0 else 1)
