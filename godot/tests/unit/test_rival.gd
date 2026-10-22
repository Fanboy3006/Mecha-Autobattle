## 职责：Boss 宿敌骨架（B 稿 N1 宿敌在场 / N2 指定角色修正 / N3 猎杀名单）。
extends RefCounted

func _敌(k: String, slot: float) -> Dictionary:
	return Units.makeUnit(k, "enemy", slot, 1.0)

func _我(k: String, slot: float) -> Dictionary:
	return Units.makeUnit(k, "ally", slot, 30.0)

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	# N1：开场效果
	var 乙 := _敌("g1b", 0.0)
	var ctx := {"turn": 1.0, "allies": [_我("M2", 0.0), _我("B2", 1.0), _我("B1", 2.0)], "enemies": [乙], "log": []}
	Rival.开局初始化(ctx)
	t.ok((乙.get("_宿敌生效", []) as Array).size() == 2, "g1b：M2 在场 + B2&M2 同在 → 两条都生效")
	t.ok(float(乙.hp) == J.round(float(乙.maxHp) * 0.85), "B2 与 M2 同在：开场 HP −15%")
	t.ok((ctx.log as Array).any(func(l): return str(l.get("类型", "")) == "宿敌"), "战报写〔宿敌〕")
	# N3：猎杀名单
	var 远 := {"name": "测试炮", "fire": "direct", "power": 1000.0, "range": [1.0, 9.0]}
	t.ok(bool(Rival.可选目标(ctx, 乙, ctx.allies[1], 远).get("终局")) and not Rival.可选目标(ctx, 乙, ctx.allies[0], 远).get("终局"),
		"猎杀名单里的 M2 够得着：别的目标不许选")
	# N2：指定角色修正
	t.ok(Rival.攻方伤害倍率(ctx, ctx.allies[0], 乙, 远) == 1.2 and Rival.攻方伤害倍率(ctx, ctx.allies[2], 乙, 远) == 1.0, "M2 打它 ×1.2，别人 ×1")
	# 条件不成立：什么都不发生
	var 甲 := _敌("g1a", 0.0)
	var ctx2 := {"turn": 1.0, "allies": [_我("CB1", 0.0)], "enemies": [甲], "log": []}
	Rival.开局初始化(ctx2)
	t.ok(not 甲.has("_宿敌生效") and (ctx2.log as Array).is_empty(), "宿敌不在场：不生效、不写战报")
	# 斩杀线
	var 丙 := _敌("g1c", 0.0)
	var ctx3 := {"turn": 1.0, "allies": [_我("B1", 0.0)], "enemies": [丙], "log": []}
	Rival.开局初始化(ctx3)
	t.ok(Rival.攻方伤害倍率(ctx3, ctx3.allies[0], 丙, 远) == 1.0, "斩杀线以上：B1 打它 ×1")
	丙.hp = float(丙.maxHp) * 0.15
	t.ok(Rival.攻方伤害倍率(ctx3, ctx3.allies[0], 丙, 远) == 3.0, "血线 20% 以下：B1 打它 ×3（斩杀线）")
	# 无视力场 + 计算管线
	var 九 := _敌("g3b", 0.0)
	var 宗 := _我("U7", 0.0)
	var ctx4 := {"turn": 1.0, "allies": [宗], "enemies": [九], "log": []}
	Rival.开局初始化(ctx4)
	var 刀 := {"name": "测试刀", "power": 4000.0, "fire": "melee", "stat": "格斗", "dmgType": "物理", "hit": 100.0, "range": [1.0, 1.0]}
	var 有 := Calc.dmgCore(宗, 刀, 九, {"power": 4000.0, "preview": true, "turn": 1.0, "ctx": ctx4})
	var 九2: Dictionary = 九.duplicate(true)
	九2.erase("_无视力场键")
	var 无 := Calc.dmgCore(宗, 刀, 九2, {"power": 4000.0, "preview": true, "turn": 1.0, "ctx": ctx4})
	t.ok(float(有.dmg) > float(无.dmg), "g3b：U7 无视它的 λ 力场（同一刀 %s vs 被减免 %s）" % [J.s(有.dmg), J.s(无.dmg)])
	# 王牌档猎杀（g4a 无条件）
	var 牙 := _敌("g4a", 0.0)
	var ctx5 := {"turn": 1.0, "allies": [_我("B1", 0.0), _我("M4", 1.0)], "enemies": [牙], "log": []}
	Rival.开局初始化(ctx5)
	t.ok(bool(Rival.可选目标(ctx5, 牙, ctx5.allies[1], 远).get("终局")), "g4a 回收名单：王牌档（S）的 B1 够得着时只打 B1")
	t.ok(RuleHooks.顺序["开局初始化"].has(Rival) and RuleHooks.顺序["可选目标"].has(Rival) and RuleHooks.顺序["攻方伤害倍率"].has(Rival), "三个钩子都登记了 Rival")
