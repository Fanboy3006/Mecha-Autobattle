## Mulberry32 与 JS 参考版逐位一致（向量由 tools/gen_rng_vectors.mjs 从 JS 导出）。
## 约定：golden 文件里随机数存 uint32 整数、其他浮点存 IEEE-754 位串 —— Godot 的 JSON 小数解析会丢精度。
extends RefCounted

func run(t) -> void:
	var data: Dictionary = GoldenIO.load_json("res://tests/golden/rng_vectors.json")
	t.ok(not data.is_empty(), "读到 rng_vectors.json")
	if data.is_empty():
		return
	var table: Dictionary = data["rng"]
	for seed_key in table.keys():
		var expected: Array = table[seed_key]
		var r := Mulberry32.new(int(seed_key))
		var first_bad := -1
		for i in expected.size():
			if r.next_float() * 4294967296.0 != float(int(expected[i])):
				first_bad = i
				break
		t.ok(first_bad == -1, "种子 %s：%d 次抽取%s" % [seed_key, expected.size(),
			"与 JS 全部一致" if first_bad == -1 else "，第 %d 次分叉" % first_bad])
	var r2 := Mulberry32.new(1)
	for i in 5:
		r2.next_float()
	t.ok(r2.steps == 5, "steps 计数随抽取递增（对账时定位第一处分叉用）")
	t.ok(load("res://presentation/boot/boot.gd").smoke_checksum() == 182751003,
		"Web 冒烟校验和 = 182751003（spike 在 Chromium 中实测值）")
