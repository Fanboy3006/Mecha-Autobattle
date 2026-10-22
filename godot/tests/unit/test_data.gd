## 数据层：从 JS 参考版导出的内容数据能完整读入，规模与来源可核对，小数无损。
extends RefCounted

const EXPECTED_SIGNATURE := "r1:05a9cbf9"

func run(t) -> void:
	var errors := []
	var data := DataLoader.load_game_data(errors)
	t.ok(data != null and errors.is_empty(), "读入 res://data/js（%s）" % ("; ".join(errors) if not errors.is_empty() else "无错误"))
	if data == null:
		return
	t.ok(data.rules_signature == EXPECTED_SIGNATURE, "数据来自封存的 JS 参考版（规则签名 %s）" % data.rules_signature)
	t.ok(data.names().size() >= 100, "常量数 %d" % data.names().size())

	# 规模核对（COL-1：退役五人 + 两张旧势力战术牌之后同步）
	var sizes := {"ALLY_T": 29, "编成表": 93, "战术卡牌表": 28, "零件表": 13}
	for name in sizes.keys():
		var v = data.get_const(name)
		var n: int = v.size() if (v is Array or v is Dictionary) else -1
		t.ok(n == sizes[name], "%s 共 %d 条（期望 %d）" % [name, n, sizes[name]])
	for name in ["战斗结构", "难度调整", "势力特色", "肉鸽数值", "守军奖励", "藏品表", "ENEMY_T"]:
		t.ok(data.has(name), "有 %s（来自 %s）" % [name, data.origin_of(name)])

	# 行动方针已取消（作者 2026-10-15）：数据里仍保留方针名表，但 Godot 只实现全军突击
	var cards: Array = data.get_const("战术卡牌表")
	var ids := {}
	for c in cards:
		ids[c["id"]] = true
	t.ok(ids.size() == 28 and ids.has("CMD_ALL_OUT") and ids.has("CMD_COVER"), "28 张战术牌 id 唯一，含两张统帅牌")

	# 小数无损：数据里的每个小数，经 Godot JSON 解析后与 JS 的 IEEE-754 位串逐位相同
	var dec = DataLoader._read_json("res://data/js/_decimals.json", [])
	var lossy := []
	for pair in (dec if dec is Array else []):
		if float(pair[0]) != GoldenIO.bits_to_float(pair[1]):
			lossy.append(str(pair[0]))
	t.ok(dec is Array and lossy.is_empty(), "数据里 %d 个不同小数全部无损%s" % [
		(dec as Array).size() if dec is Array else 0, "" if lossy.is_empty() else "；有损：" + ", ".join(lossy)])
