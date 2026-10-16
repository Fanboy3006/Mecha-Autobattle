## M0 占位首页：证明 Web 版能打开、中文字体正常、确定性内核在浏览器里与无界面结果一致。
## M4 起由真正的标题画面替换。
extends Control

## 冒烟校验用：Mulberry32(20261015) 前 2000 次抽取的滚动校验和（与 tests/unit/test_rng.gd 同一算法）
static func smoke_checksum() -> int:
	var r := Mulberry32.new(20261015)
	var acc := 0
	for i in 2000:
		acc = (acc * 31 + int(r.next_float() * 4294967296.0)) & 0xFFFFFFFF
	return acc

func _ready() -> void:
	var checksum := smoke_checksum()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "机甲指挥"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Godot 版 · 迁移进行中\n现在可玩的版本仍在原链接（上一级目录）"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var info := Label.new()
	info.text = "版本 %s · 规则参考 %s\n确定性自检：%d" % [GameVersion.GAME_VERSION, GameVersion.RULES_REFERENCE, checksum]
	info.add_theme_font_size_override("font_size", 14)
	info.modulate = Color(1, 1, 1, 0.6)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	# 给 Web 冒烟脚本读的一行（浏览器控制台）
	print("MECHA_SMOKE %s" % JSON.stringify({"checksum": checksum, "version": GameVersion.GAME_VERSION}))
