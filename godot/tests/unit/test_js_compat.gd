## JsCompat：与 JS 结算语义对齐的四舍五入与稳定排序。
extends RefCounted

func run(t) -> void:
	var data: Dictionary = GoldenIO.load_json("res://tests/golden/rng_vectors.json")
	var bad := []
	for pair in data.get("rounds", []):
		var x := GoldenIO.bits_to_float(pair[0])
		var got := JsCompat.js_round(x)
		var want := GoldenIO.bits_to_float(pair[1])
		if got != want:
			bad.append("%s→%s(期望 %s)" % [x, got, want])
	t.ok(bad.is_empty(), "js_round 与 JS Math.round 一致（%d 个样本，含负数 .5 与浮点边界）%s" % [
		data.get("rounds", []).size(), "" if bad.is_empty() else "：" + ", ".join(bad)])
	t.ok(round(-2.5) == -3.0 and JsCompat.js_round(-2.5) == -2.0,
		"对照：Godot 内置 round(-2.5) = -3，JS 是 -2 —— 规则代码一律用 js_round")

	var got_sorted := JsCompat.stable_sort(data.get("sortInput", []), func(a, b): return a["k"] < b["k"])
	var ids := got_sorted.map(func(x): return int(x["id"]))
	var want_ids: Array = data.get("sortExpected", []).map(func(x): return int(x))
	t.ok(ids == want_ids and not ids.is_empty(), "stable_sort 与 V8 稳定排序一致（40 个元素、5 组并列键）")

	var lossy := 0
	for pair in data.get("jsonProbe", []):
		if float(pair[0]) != GoldenIO.bits_to_float(pair[1]):
			lossy += 1
	t.info("对照：%d / %d 个浮点经 JSON 小数解析后与原值不同（所以 golden 文件不存 JSON 小数）" % [lossy, data.get("jsonProbe", []).size()])
