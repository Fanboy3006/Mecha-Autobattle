## 显示名表骨架与取名入口：八个分区齐全；表里有就用表里的，没有就回落到兜底 / 卡包名。
extends RefCounted

## 施工单 NAME §二规定的固定分区（顺序即表里的顺序）。
const 分区们 := ["势力", "驾驶员", "机体", "关键词", "状态标签", "身份", "卡牌", "其它"]

func run(t) -> void:
	var errors := []
	var data := DataLoader.load_game_data(errors)
	t.ok(data != null and errors.is_empty(), "读入数据无错误%s" % ("" if errors.is_empty() else "：" + str(errors)))
	if data == null:
		return
	t.ok(data.has("显示名"), "有常量 显示名（来自 %s）" % (data.origin_of("显示名") if data.has("显示名") else "缺"))
	var 表 = data.get_const("显示名")
	t.ok(表 is Dictionary, "显示名 是字典")
	if not 表 is Dictionary:
		return
	var 缺 := []
	for 区 in 分区们:
		if not 表.has(区):
			缺.append(区)
		elif not 表[区] is Dictionary:
			缺.append(区 + " 不是字典")
	t.ok(缺.is_empty(), "八个分区都在且都是字典%s" % ("" if 缺.is_empty() else "：有问题 " + ", ".join(缺)))

	# 取名入口：临时换一张演习表，验证「表里的优先、没有就回落到兜底 / id」
	var errors2 := []
	DataLoader.install(errors2)
	t.ok(Db.installed and errors2.is_empty(), "数据装入 Db%s" % ("" if errors2.is_empty() else "：" + str(errors2)))
	var 有原键 := Db.T.has("显示名")
	var 原值 = Db.T.get("显示名")
	Db.T["显示名"] = {"关键词": {"TRANS-AM": "※TA"}, "卡牌": {"X1": "※卡"}}
	t.ok(DisplayNames.名("关键词", "TRANS-AM") == "※TA", "表里有就用表里的：关键词 TRANS-AM")
	t.ok(DisplayNames.名("关键词", "不存在") == "不存在", "表里没有、兜底为空就用 id 本身")
	t.ok(DisplayNames.名("关键词", "不存在", "兜底") == "兜底", "表里没有就用兜底")
	t.ok(DisplayNames.名("没这个区", "a") == "a", "没有这个分区就回落到 id")
	t.ok(DisplayNames.卡名({"id": "X1", "名": "原名"}) == "※卡", "卡名有覆盖就用覆盖")
	t.ok(DisplayNames.卡名({"id": "X2", "名": "原名"}) == "原名", "卡名没有覆盖就用卡包里的名")
	if 有原键:
		Db.T["显示名"] = 原值
	else:
		Db.T.erase("显示名")
