## 卡表等价快照：各卡包注册表的卡表用 `var_to_str` 序列化后，与 `tests/golden/card_tables/<卡包名>.txt` 逐字比对。
##
## 为什么这样能锁住「行为零变化」：`var_to_str` **带类型**（`1` 与 `1.0` 输出不同）、
## 字典按键的**插入顺序**、数组按**索引顺序**输出。卡表抽成 JSON 数据后，只要快照
## 逐字不变，牌序（影响随机抽牌）、字段类型（`剑数` / `等级需求` / `距离` 元素是 int）、
## 键顺序（界面与测试按顺序读）就都没变。
##
## 快照不存在时自动生成并报 ✗（要求人工确认后重跑），存在时逐字比对。
extends RefCounted

const 快照目录 := "res://tests/golden/card_tables"

func run(t) -> void:
	var errors := []
	DataLoader.install(errors)
	t.ok(errors.is_empty(), "卡表快照前先装入数据%s" % ("" if errors.is_empty() else "：" + str(errors)))
	if not errors.is_empty():
		return
	var 表 := 快照注册表()
	for 包名 in 表.keys():
		_检查卡包快照(t, str(包名), 表[包名])

func _检查卡包快照(t, 包名: String, 段们: Array) -> void:
	var 路径 := 快照目录.path_join("%s.txt" % 包名)
	var 实际 := _拼(包名, 段们)
	if not FileAccess.file_exists(路径):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(快照目录))
		var f := FileAccess.open(路径, FileAccess.WRITE)
		if f != null:
			f.store_string(实际)
		t.ok(false, "已生成 %s 卡表快照，请确认后重跑" % 包名)
		return
	var 期望 := FileAccess.get_file_as_string(路径)
	var 不同 := _不同段(期望, 段们)
	t.ok(实际 == 期望, "%s卡表快照（%d 组 var_to_str）逐字一致" % [包名, 段们.size()])
	if not 不同.is_empty():
		t.info("%s 不一致的段：%s" % [包名, "、".join(不同)])

## 各卡包快照注册表：卡包名 → [[段名, 返回值], ...]（顺序即语义，改顺序等于改快照）
func 快照注册表() -> Dictionary:
	return {
		"天人": _天人段们(),
		"秘银": _秘银段们(),
		"ATX": _atx段们(),
		"职业分类牌": _职业分类牌段们(),
		"维修职业分类牌": _维修分类牌段们(),
		"殖民卫星军": _殖民卫星军段们(),
		"月球王国": _月球王国段们(),
		"影世界": _影世界段们(),
	}

func _月球王国段们() -> Array:
	var 段们: Array = []
	段们.append(["MoonDeck.月光牌们()", MoonDeck.月光牌们()])
	段们.append(["MoonDeck.势力牌们()", MoonDeck.势力牌们()])
	段们.append(["MoonDeck.初始牌库()", MoonDeck.初始牌库()])
	for 键 in MoonUnits.成员键:
		段们.append(["MoonUnits.角色牌们(%s)" % 键, MoonUnits.角色牌们(键)])
	return 段们

func _影世界段们() -> Array:
	var 段们: Array = []
	段们.append(["ShadowDeck.影门牌们()", ShadowDeck.影门牌们()])
	段们.append(["ShadowDeck.势力牌们()", ShadowDeck.势力牌们()])
	段们.append(["ShadowDeck.初始牌库()", ShadowDeck.初始牌库()])
	for 键 in ShadowV02.成员键:
		段们.append(["ShadowUnits.角色牌们(\"%s\")" % 键, ShadowUnits.角色牌们(键)])
	return 段们

func _殖民卫星军段们() -> Array:
	var 段们: Array = []
	段们.append(["ColonialDeck.感应牌们()", ColonialDeck.感应牌们()])
	段们.append(["ColonialDeck.势力牌们()", ColonialDeck.势力牌们()])
	段们.append(["ColonialDeck.初始牌库()", ColonialDeck.初始牌库()])
	段们.append(["ColonialV01.入场牌们()", ColonialV01.入场牌们()])
	return 段们

func _天人段们() -> Array:
	var 段们: Array = []
	段们.append(["太阳炉卡表", CelestialV01.太阳炉卡表()])
	段们.append(["势力牌们", CelestialV01.势力牌们()])
	段们.append(["拉塞卡表(false)", CelestialV01.拉塞卡表(false)])
	段们.append(["拉塞卡表(true)", CelestialV01.拉塞卡表(true)])
	for 键 in ["CB1", "CB2", "CB3", "CB4"]:
		段们.append(["驾驶员卡表(%s, false)" % 键, CelestialV01.驾驶员卡表(键, false)])
		段们.append(["驾驶员卡表(%s, true)" % 键, CelestialV01.驾驶员卡表(键, true)])
	段们.append(["大招卡", CelestialV01.大招卡()])
	段们.append(["纳德雷武器表(CB4)", CelestialV01.纳德雷武器表("CB4")])
	return 段们

func _秘银段们() -> Array:
	var 段们: Array = []
	段们.append(["MithrilV03Cards.卡表()", MithrilV03Cards.卡表()])
	段们.append(["MithrilV03Cards.角色牌们()", MithrilV03Cards.角色牌们()])
	段们.append(["MithrilV03Cards.势力牌们()", MithrilV03Cards.势力牌们()])
	段们.append(["MithrilV03Cards.职业牌们()", MithrilV03Cards.职业牌们()])
	段们.append(["MithrilV03Cards.连携牌们()", MithrilV03Cards.连携牌们()])
	段们.append(["MithrilV03Cards.合体技卡()", MithrilV03Cards.合体技卡()])
	段们.append(["MithrilV03Cards.公有牌们()", MithrilV03Cards.公有牌们()])
	段们.append(["MithrilV03Cards.初始连携牌库()", MithrilV03Cards.初始连携牌库()])
	for 键 in MithrilV03Cards.成员键:
		段们.append(["MithrilV03Cards.角色专属牌们(%s)" % 键, MithrilV03Cards.角色专属牌们(键)])
		for lv in [10, 20, 30]:
			段们.append(["MithrilV03Cards.角色专属牌们按等级(%s, %d)" % [键, lv], MithrilV03Cards.角色专属牌们按等级(键, lv)])
	return 段们

func _atx段们() -> Array:
	var 段们: Array = []
	段们.append(["AtxThree.卡表()", AtxThree.卡表()])
	段们.append(["AtxThree.升版卡表()", AtxThree.升版卡表()])
	for 键 in ["A1", "A2", "A3"]:
		段们.append(["AtxThree.角色牌们(%s)" % 键, AtxThree.角色牌们(键)])
		段们.append(["AtxThree.角色牌们加版(%s)" % 键, AtxThree.角色牌们加版(键)])
		for 档 in ["初始", "剧情", "肉鸽"]:
			段们.append(["AtxThree.按档名单(%s, %s)" % [键, 档], AtxThree.按档名单(键, 档)])
	段们.append(["AtxThree.主武器卡们()", AtxThree.主武器卡们()])
	段们.append(["AtxThree.副武器卡们()", AtxThree.副武器卡们()])
	段们.append(["AtxThree.大招卡们()", AtxThree.大招卡们()])
	段们.append(["AtxThree.精神牌们()", AtxThree.精神牌们()])
	段们.append(["AtxThree.按角色张数()", AtxThree.按角色张数()])
	段们.append(["AtxThree.卡表张数()", AtxThree.卡表张数()])
	段们.append(["FacAtx.卡表()", FacAtx.卡表()])
	段们.append(["FacAtx.角色牌们()", FacAtx.角色牌们()])
	段们.append(["FacAtx.势力牌们()", FacAtx.势力牌们()])
	段们.append(["FacAtx.合体技卡()", FacAtx.合体技卡()])
	段们.append(["FacAtx.公有牌们()", FacAtx.公有牌们()])
	for 键 in FacAtx.成员键:
		段们.append(["FacAtx.角色专属牌们(%s)" % 键, FacAtx.角色专属牌们(键)])
	段们.append(["AtxChips.卡表()", AtxChips.卡表()])
	段们.append(["AtxChips.初始筹码牌库()", AtxChips.初始筹码牌库()])
	段们.append(["AtxDuo.卡表()", AtxDuo.卡表()])
	for 键 in ["A6", "A7"]:
		段们.append(["AtxDuo.角色牌们(%s)" % 键, AtxDuo.角色牌们(键)])
	段们.append(["AtxDuo.主武器卡们()", AtxDuo.主武器卡们()])
	段们.append(["AtxDuo.大招卡们()", AtxDuo.大招卡们()])
	段们.append(["AtxDuo.精神牌们()", AtxDuo.精神牌们()])
	return 段们

func _职业分类牌段们() -> Array:
	var 段们: Array = []
	段们.append(["ClassCards.卡表()", ClassCards.卡表()])
	for 职业 in ClassCards.职业们:
		段们.append(["ClassCards.职业牌们(%s)" % 职业, ClassCards.职业牌们(职业)])
	return 段们

func _维修分类牌段们() -> Array:
	var 段们: Array = []
	段们.append(["RepairCards.卡表()", RepairCards.卡表()])
	段们.append(["RepairCards.职业牌们()", RepairCards.职业牌们()])
	return 段们

func _拼(包名: String, 段们: Array) -> String:
	var 文 := "%s卡表等价快照（var_to_str；%d 组；顺序固定）\n" % [包名, 段们.size()]
	for 段 in 段们:
		文 += "\n===== %s =====\n" % 段[0]
		文 += var_to_str(段[1]) + "\n"
	return 文

## 逐个段落比对，只用于失败时定位（不改判定：判定看整份文本）
func _不同段(期望: String, 段们: Array) -> Array:
	var 不同: Array = []
	for 段 in 段们:
		var 标 := "===== %s =====\n" % 段[0]
		var 起 := 期望.find(标)
		if 起 < 0:
			不同.append(段[0])
			continue
		var 文 := var_to_str(段[1]) + "\n"
		if 期望.substr(起 + 标.length(), 文.length()) != 文:
			不同.append(段[0])
	return 不同
