## 职责：版面门禁薄入口 —— 按原顺序调各 test_layout_*.gd 的 走一遍()，每段只跑 1 次。
extends "res://tests/unit/layout_fixtures.gd"

const 套件们 := [
	preload("res://tests/unit/test_layout_screens.gd"),
	preload("res://tests/unit/test_layout_tooltip.gd"),
	preload("res://tests/unit/test_layout_flow.gd"),
	preload("res://tests/unit/test_layout_log.gd"),
	preload("res://tests/unit/test_layout_board.gd"),
	preload("res://tests/unit/test_layout_hand.gd"),
	preload("res://tests/unit/test_layout_sidebar.gd"),
	preload("res://tests/unit/test_layout_drag.gd"),
	preload("res://tests/unit/test_layout_ux1.gd"),
]

func run(t) -> void:
	var 根: Node = _根()
	for 套件 in 套件们:
		var 套 = 套件.new()
		await 套.走一遍(t, 根)
