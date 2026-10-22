## CR-1（Claude Opus 5.5 Code Review，2026-10-18）：P1-1 / P1-2 / P2-1 的复现测试。
## 先红后绿：修复前本文件应有 3 组断言失败；修复后全绿。
## 夹具（造单位 / 造场）可以按内核实际需要微调；**断言的期望值不许改**（改期望值 = 没修 Bug）。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 块 = Db.T.战斗结构.get("单机牌组")
	if not (块 is Dictionary):
		t.ok(false, "数据里找不到 战斗结构.单机牌组")
		return
	var 原 = 块.get("开")
	块["开"] = true
	_P1_1_装甲池吃无视装甲(t)
	_P1_2_哈雷路亚禁打公有排(t)
	_P2_1_grant受断路器3约束(t)
	块["开"] = 原

# ==========================================================================================
# P1-1：装甲共享池的初值必须扣掉 `ignoreArmorPct`
#   受控：atk == D（coef = 1）、defMul = 1、必中（fire = map）、暴击率 0。
#   甲 1000、500 × 6 段：
#     · 不带无视装甲：池 1000 → 10 + 10 + 500×4 = 2020（对照，修前修后都应成立）
#     · 无视 50% 装甲：池 500 → 10 + 500×5 = 2510（修前会算成 2020）
# ==========================================================================================
func _P1_1_装甲池吃无视装甲(t) -> void:
	var att := _裸("测试攻方", "ally", 4.0, 500.0, 0.0, 0.0)
	var def := _裸("测试靶", "enemy", 0.0, 0.0, 1000.0, 500.0)
	var w := {"name": "测试武器", "fire": "map", "dmgType": "物理", "power": 500.0, "hit": 100.0,
		"stat": "射击", "hits": 6.0, "cd": 0.0, "upgrades": []}
	var r0 := Calc.resolveAttack(att, def, w.duplicate(true), _裸场([att], [def]), {})
	t.ok(_伤(r0) == 2020, "P1-1 对照：甲 1000、500×6、不无视装甲 → %d（期望 2020）" % _伤(r0))
	def["hp"] = def["maxHp"]
	var w2 := w.duplicate(true)
	w2["ignoreArmorPct"] = 0.5
	var r1 := Calc.resolveAttack(att, def, w2, _裸场([att], [def]), {})
	t.ok(_伤(r1) == 2510,
		"P1-1 ★ 无视 50% 装甲：池应为 500 → 10 + 500×5 = 2510（实际 %d；2020 = 池没扣无视装甲）" % _伤(r1))

# ==========================================================================================
# P1-2：哈雷路亚人格不能打公有排（太阳炉牌 / 天人势力牌），要从真正的打出入口验
# ==========================================================================================
func _P1_2_哈雷路亚禁打公有排(t) -> void:
	var 阿 := _天人("CB3", "ally", 0.0, "重装")
	var c := _天人场([阿], [_靶("靶1", 0.0)])
	阿["人格"] = CelestialV01.人格哈雷路亚
	t.ok(not CelestialV01.公有牌可打(c, 阿), "P1-2 前提：哈雷路亚人格 → `公有牌可打() == false`")
	# ① 一级太阳炉牌
	var 炉 := _拿一张一级炉(c)
	t.ok(not 炉.is_empty(), "P1-2 前提：拿到一张一级太阳炉牌进公有手牌")
	var 炉id := str(炉.get("id", ""))
	var r1 := Btl.打出精神或公有牌(c, "CB3", 炉id, "靶1")
	t.ok(not J.truthy(r1.get("成功")) and str(r1.get("原因", "")).contains("哈雷路亚"),
		"P1-2 ★ 哈雷路亚打太阳炉牌【%s】→ 必须失败且原因提到哈雷路亚（实际：%s）" % [str(炉.get("名")), str(r1)])
	# ② 天人势力牌「天人，出击」（0 费、无入库条件）
	var 势 := _势力牌("CB_FAC_1")
	(c["公有手牌"] as Array).append(势)
	var r2 := Btl.打出精神或公有牌(c, "CB3", "CB_FAC_1", null)
	t.ok(not J.truthy(r2.get("成功")) and str(r2.get("原因", "")).contains("哈雷路亚"),
		"P1-2 ★ 哈雷路亚打天人势力牌 → 必须失败且原因提到哈雷路亚（实际：%s）" % str(r2))
	# ③ 对照：切回阿雷路亚，同一张太阳炉牌能打（也证明失败时牌没有离手）
	阿["人格"] = CelestialV01.人格阿雷路亚
	var r3 := Btl.打出精神或公有牌(c, "CB3", 炉id, "靶1")
	t.ok(J.truthy(r3.get("成功")), "P1-2 对照：阿雷路亚打同一张太阳炉牌 → 成功（实际：%s）" % str(r3))

# ==========================================================================================
# P2-1：`grant`（支援型「再动」主武器卡）必须走断路器 3 的同一把锁
# ==========================================================================================
func _P2_1_grant受断路器3约束(t) -> void:
	var 菲 := _天人("FEENA", "ally", 0.0, "指挥")
	菲["tags"] = {"战斗分类": "指挥", "势力": "月球王国"}
	var 已用 := _天人("CB1", "ally", 1.0, "近卫")
	已用["本回合再动已用"] = true
	已用["主武器已销毁"] = true
	var 新 := _天人("CB2", "ally", 2.0, "狙击")
	新["主武器已销毁"] = true
	var c := _天人场([菲, 已用, 新], [_靶("靶1", 0.0)])
	var 再动 := {"name": "再动", "fire": "support", "grant": true, "power": 0.0, "hit": 100.0,
		"stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": []}
	Btl._执行支援卡(c, 菲, {"t": 再动.duplicate(true), "cd": 0.0, "uses": null}, "CB1")
	t.ok(J.truthy(已用.get("主武器已销毁")),
		"P2-1 ★ 本回合已经再动过的队友，被「再动」支援卡指定 → 断路器 3 拦下，主武器保持已销毁")
	Btl._执行支援卡(c, 菲, {"t": 再动.duplicate(true), "cd": 0.0, "uses": null}, "CB2")
	t.ok(not J.truthy(新.get("主武器已销毁")) and J.truthy(新.get("本回合再动已用")) and J.truthy(新.get("连续攻击已用")),
		"P2-1 ★ 额度完好的队友 → 主武器恢复，并且 `本回合再动已用` / `连续攻击已用` 一起置真（同一把锁）")

# ==========================================================================================
# 夹具
# ==========================================================================================
func _伤(r: Dictionary) -> int:
	var 字 = r.get("字段")
	return int(float((字 as Dictionary).get("伤害", -1))) if 字 is Dictionary else -1

## 纯数值单位（与 test_armor_pool.gd 的 `_单位` 同口径）。
func _裸(键: String, side: String, 位: float, 射: float, 甲值: float, 防值: float) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 999999.0, "hp": 999999.0,
		"melee": 射, "shoot": 射, "awaken": 0.0, "defense": 防值,
		"armor": 甲值, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {}, "weapons": [],
	}

func _裸场(我方: Array, 敌方: Array) -> Dictionary:
	return {"turn": 1.0, "种子": 20261018.0, "rng": Mulberry32.new(20261018),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [], "当前战术": null, "气势": 0.0}

## 单机牌组单位（与 test_celestial_v01.gd 的 `_单位` 同口径）。
func _天人(键: String, side: String, 位: float, 职业: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 3000.0, "hp": 3000.0,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"战斗分类": 职业, "势力": "天人"}, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _靶(键: String, 位: float) -> Dictionary:
	var e := _天人(键, "enemy", 位, "")
	e["tags"] = {}
	e["hp"] = 999999.0
	e["maxHp"] = 999999.0
	return e

func _天人场(我方: Array, 敌方: Array) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": 20261018.0, "rng": Mulberry32.new(20261018),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	CelestialV01.初始化(c)
	return c

## 从太阳炉牌库里拿第一张一级牌放进公有手牌（与 test_celestial_v01.gd 的 `拿炉` 同口径）。
func _拿一张一级炉(c: Dictionary) -> Dictionary:
	var 牌们: Array = SubDeck.牌们(c.get("太阳炉牌库"))
	for i in range(牌们.size()):
		var x = 牌们[i]
		if x is Dictionary and int(J.num0((x as Dictionary).get(CelestialV01.炉等级键))) == 1:
			牌们.remove_at(i)
			(c["公有手牌"] as Array).append(x)
			return x
	return {}

func _势力牌(id: String) -> Dictionary:
	for x in CelestialV01.势力牌们():
		if x is Dictionary and str((x as Dictionary).get("id")) == id:
			return (x as Dictionary).duplicate(true)
	return {}
