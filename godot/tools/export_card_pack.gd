extends SceneTree

## 一次性卡包导出脚本：调用现有卡表取表函数生成 JSON 卡包，并输出需还原为 int 的字段路径清单。
## 运行方式：godot --headless --path godot --script res://tools/export_card_pack.gd

func _init() -> void:
	var errs: Array = []
	if not DataLoader.install(errs):
		push_error("DataLoader.install 失败: %s" % [errs])
		quit(1)
		return

	_export_atx()
	_export_class_cards()
	quit(0)

func _export_atx() -> void:
	var 三小强 := AtxThree.卡表()
	var 三小强加 := AtxThree.升版卡表()
	var 双子 := AtxDuo.卡表()
	var 双子ids := {}
	for c in 双子:
		双子ids[str((c as Dictionary).get("id", ""))] = true
	var v02卡表: Array = []
	for c in FacAtx.卡表():
		var d: Dictionary = c
		if not 双子ids.has(str(d.get("id", ""))):
			v02卡表.append(d)
	var 筹码 := AtxChips.卡表()

	var atx_pack := {
		"势力": "ATX",
		"设计稿": "协作/设计/ATX小队卡牌设计 v0.3.md",
		"结构": {
			"三小强": "卡组",
			"三小强+": "卡组",
			"v02卡表": "卡组",
			"双子": "卡组",
			"筹码": "卡组",
		},
		"三小强": 三小强,
		"三小强+": 三小强加,
		"v02卡表": v02卡表,
		"双子": 双子,
		"筹码": 筹码,
	}

	_write_json("res://data/cards/ATX.json", atx_pack)

	print("=== ATX 需还原为 int 的字段清单 ===")
	_print_int_paths("三小强", 三小强)
	_print_int_paths("三小强+", 三小强加)
	_print_int_paths("v02卡表", v02卡表)
	_print_int_paths("双子", 双子)
	_print_int_paths("筹码", 筹码)

func _export_class_cards() -> void:
	var 卡组 := ClassCards.卡表()
	var pack := {
		"势力": "职业分类牌",
		"设计稿": "协作/设计/近卫尖兵重装分类牌设计 v0.1.md",
		"结构": {
			"分类牌": "卡组",
		},
		"分类牌": 卡组,
	}
	_write_json("res://data/cards/职业分类牌.json", pack)
	print("=== 职业分类牌 需还原为 int 的字段清单 ===")
	_print_int_paths("分类牌", 卡组)

func _print_int_paths(section: String, cards: Array) -> void:
	var key_paths := {}
	var float_paths := {}
	for c in cards:
		_collect_num_paths(c, "", key_paths, float_paths)
	var keys := key_paths.keys()
	keys.sort()
	var fkeys := float_paths.keys()
	fkeys.sort()
	print("[%s] (%d 张) int_paths: %s" % [section, cards.size(), JSON.stringify(keys)])
	print("[%s] (%d 张) float_paths: %s" % [section, cards.size(), JSON.stringify(fkeys)])

func _collect_num_paths(v: Variant, path: String, int_out: Dictionary, float_out: Dictionary) -> void:
	if typeof(v) == TYPE_INT:
		int_out[path] = true
	elif typeof(v) == TYPE_FLOAT:
		float_out[path] = true
	elif v is Dictionary:
		for k in (v as Dictionary).keys():
			var next_path := str(k) if path == "" else "%s.%s" % [path, str(k)]
			_collect_num_paths(v[k], next_path, int_out, float_out)
	elif v is Array:
		for x in (v as Array):
			var next_path := "%s[]" % path
			_collect_num_paths(x, next_path, int_out, float_out)

func _write_json(res_path: String, data: Dictionary) -> void:
	var text := JSON.stringify(data, "\t", false) + "\n"
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f == null:
		push_error("无法写入 %s" % res_path)
		return
	f.store_string(text)
	f.close()
	print("已写出 %s (%d 字节)" % [res_path, text.to_utf8_buffer().size()])
