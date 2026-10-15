## Web 冒烟场景：在浏览器里跑同一套 RNG，把校验和显示在屏幕上（与无界面测试的结果一致即证明 Web 端确定性）。
extends Control

func _ready() -> void:
	var r := Mulberry32.new(20261015)
	var acc := 0
	for i in 2000:
		acc = (acc * 31 + int(r.next_float() * 4294967296.0)) & 0xFFFFFFFF
	var label := Label.new()
	label.text = "机甲指挥 · Godot 迁移 spike\nMulberry32(20261015) 2000 次抽取校验和 = %d\njs_round(-2.5) = %s" % [acc, JsCompat.js_round(-2.5)]
	label.position = Vector2(24, 24)
	add_child(label)
	print("SPIKE_CHECKSUM=%d" % acc)
