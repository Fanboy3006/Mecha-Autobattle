## 职责：N2【悬赏令】—— 敌方阶段开始标记我方本回合输出最高者；带悬赏令的敌机够得着就只打它、伤害 +20%；
## 悬赏目标顶着悬赏击破过敌机 → 下次结算时战意 +10。场上没有带悬赏令的敌机就不标记。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 甲 := Units.makeUnit("CB2", "ally", 0.0, 30.0)
	var 乙 := Units.makeUnit("B1", "ally", 1.0, 30.0)
	甲["战意"] = 0.0
	var 私 := Units.makeUnit("ok_trooper", "enemy", 0.0, 1.0)
	var 犬 := Units.makeUnit("ok_hound", "enemy", 1.0, 1.0)
	var ctx := {"turn": 2.0, "allies": [甲, 乙], "enemies": [私, 犬], "log": []}
	ctx.log.append({"回合": 2.0, "类型": "攻击", "单位": 甲.key, "单位方": "ally", "伤害": 3000.0})
	ctx.log.append({"回合": 2.0, "类型": "攻击", "单位": 乙.key, "单位方": "ally", "伤害": 1200.0})
	ctx.log.append({"回合": 1.0, "类型": "攻击", "单位": 乙.key, "单位方": "ally", "伤害": 9999.0})
	EnemyMech.敌方阶段初(ctx)
	t.ok(str(ctx.get("悬赏目标", "")) == str(甲.key), "本回合输出最高的被悬赏（上回合的不算）")
	t.ok(EnemyMech.攻方伤害倍率(ctx, 私, 甲, {}) == 1.2 and EnemyMech.攻方伤害倍率(ctx, 私, 乙, {}) == 1.0, "私兵打悬赏目标 ×1.2，打别人 ×1")
	var 远 := {"name": "猎枪", "fire": "direct", "power": 1000.0, "range": [1.0, 3.0]}
	t.ok(bool(EnemyMech.可选目标(ctx, 犬, 乙, 远).get("终局")) and not EnemyMech.可选目标(ctx, 犬, 甲, 远).get("终局"),
		"猎犬够得着悬赏目标时：别的目标不许选，悬赏目标照选")
	var 旧 := Units.makeUnit("grunt", "enemy", 2.0, 1.0)
	t.ok(not EnemyMech.可选目标(ctx, 旧, 乙, 远).get("终局") and EnemyMech.攻方伤害倍率(ctx, 旧, 甲, {}) == 1.0, "不带悬赏令的旧敌机不受影响")
	# 赏金：悬赏目标在下一回合击破了敌机
	ctx.turn = 3.0
	ctx.log.append({"回合": 3.0, "类型": "击破", "单位": 甲.key, "单位方": "ally", "目标": 私.key})
	ctx.log.append({"回合": 3.0, "类型": "攻击", "单位": 乙.key, "单位方": "ally", "伤害": 500.0})
	EnemyMech.敌方阶段初(ctx)
	t.ok(float(甲.战意) == 10.0, "顶着悬赏击破敌机：战意 +10（实际 %s）" % J.s(甲.战意))
	t.ok(str(ctx.get("悬赏目标", "")) == str(乙.key), "悬赏改标本回合输出最高的乙")
	# 带悬赏令的敌机全灭：不再标记
	私.hp = 0.0
	犬.hp = 0.0
	ctx.turn = 4.0
	ctx.log.append({"回合": 4.0, "类型": "攻击", "单位": 甲.key, "单位方": "ally", "伤害": 800.0})
	EnemyMech.敌方阶段初(ctx)
	t.ok(not ctx.has("悬赏目标"), "带悬赏令的敌机都没了：不标记")
