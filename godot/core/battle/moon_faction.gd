## 职责：月球王国势力牌的算子（号令 / 阵形变换 / 战线轮换 / 月相仪典 / 王国之盾 / 公主挺身）。
## 约定：换位一律走 `BattleSwap.换位(ctx, "ally", …)`（只动我方，不跨阵）；陨石召唤是声明式 `固定伤害`，不经过这里。
class_name MoonFaction
extends RefCounted

static func 执行算子(运行: Dictionary, 表: Dictionary, 打者: Variant, 友: Variant) -> Array:
	var ctx: Dictionary = 运行.get("ctx") if 运行.get("ctx") is Dictionary else {}
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(卡.get("名", ""))
	var 菲 = MoonPhase.王女(ctx)
	match str(表.get("动作", "")):
		"月·王女的号令":
			var 抽 := Setup.抽公有牌(ctx, 1)
			var 文 := "抽 %d 张公有牌" % 抽.size()
			if 菲 != null and Fm.rowOfSlot(float(菲.slot)) == Fm.ROW_BACK:
				Btl.加战意(菲, 5.0, ctx, 牌名)
				var 抽2 := Setup.抽专属牌(菲, 1)
				文 += "；Feena 在后排：战意 +5、抽 %d 张精神牌" % 抽2.size()
			return [MoonDeck._记(ctx, 牌名, null, 文)]
		"月·阵形变换":
			return _阵形变换(ctx, 牌名)
		"月·战线轮换":
			var 基 = 友 if MoonPhase.活着(友) else 打者
			if not MoonPhase.活着(基):
				return []
			var 列 := Fm.colOfSlot(float(基.slot))
			var 前 := Fm.slotOf(Fm.ROW_FRONT, 列)
			var 后 := Fm.slotOf(Fm.ROW_BACK, 列)
			var 甲 = BattleSwap.格上单位(ctx, "ally", 前)
			var 乙 = BattleSwap.格上单位(ctx, "ally", 后)
			var k := BattleSwap.换位(ctx, "ally", 前, 后, {"来源": 牌名})
			for x in [甲, 乙]:
				if MoonPhase.活着(x):
					Btl.换同源增益(x, "战线轮换", {"eva": 15.0, "剩余": 1.0})
			return [MoonDeck._记(ctx, 牌名, null, "第 %d 列前后排对调（%d 台换位，闪避 +15）" % [int(列) + 1, k])]
		"月·月相仪典":
			if 菲 == null:
				return []
			var 新: String = MoonPhase.仪典下一个.get(MoonPhase.月相(ctx), MoonPhase.残月)
			MoonPhase.切换月相(ctx, 新, 牌名)
			var 送 := MoonDeck.月光牌("MOON_LT1_ECHO")
			送["月球赠牌"] = true
			var 手: Array = J.or_(ctx.get("公有手牌"), [])
			var 文2 := "Feena → 【%s】" % 新
			if 手.size() < MoonDeck.抽牌上限:
				手.append(送)
				ctx["公有手牌"] = 手
				文2 += "；【余响共鸣】进公有手牌"
			if Fm.rowOfSlot(float(菲.slot)) == Fm.ROW_BACK and MoonPhase.活着(打者):
				Btl.加战意(打者, 5.0, ctx, 牌名)
				文2 += "；Feena 在后排：返还 5 战意"
			return [MoonDeck._记(ctx, 牌名, null, 文2)]
		"月·王国之盾":
			if not MoonPhase.活着(友):
				return []
			var 随 := MoonPhase.活着(打者) and MoonDeck.随侍结算(ctx, 打者, 卡)
			var 值 := 2.0 if 随 and MoonPhase.是随侍(ctx, 友) else 1.0
			var 减 := MoonDeck.减一张冷却(友, 值)
			return [MoonDeck._记(ctx, 牌名, 友, "%s 冷却 -%d" % [减 if 减 != "" else "（没有冷却中的牌）", int(值)])]
		"月·公主挺身":
			if 菲 == null:
				return []
			if MoonPhase.活着(打者):
				MoonDeck.随侍结算(ctx, 打者, 卡)
			var 低 = _最低血成员(ctx, 菲)
			var 文3 := "没有可以替换的成员"
			if 低 != null:
				BattleSwap.换位(ctx, "ally", 菲.slot, 低.slot, {"来源": 牌名})
				文3 = "Feena 与 %s 交换位置" % 低.name
			var 盾 := MoonPhase.给护盾(菲, J.round(float(菲.maxHp) * 0.15))
			return [MoonDeck._记(ctx, 牌名, 菲, "%s；Feena 护盾 %s" % [文3, J.s(盾)])]
	return []

static func _阵形变换(ctx: Dictionary, 牌名: String) -> Array:
	var 前排们: Array = Units.livingOf("ally", ctx).filter(func(a):
		return MoonPhase.是月球王国(a) and Fm.rowOfSlot(float(a.slot)) == Fm.ROW_FRONT)
	if 前排们.is_empty():
		return [MoonDeck._记(ctx, 牌名, null, "前排没有月球王国成员")]
	J.sort(前排们, func(a, b):
		var d := float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp)
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	var 选: Dictionary = 前排们[0]
	BattleSwap.换位(ctx, "ally", 选.slot, Fm.另一排同位(选.slot), {"来源": 牌名})
	var 回 := MoonPhase.治疗(ctx, null, 选, 0.08, 0.0)
	return [MoonDeck._记(ctx, 牌名, 选, "换到后排，回复 %s HP" % J.s(回))]

static func _最低血成员(ctx: Dictionary, 菲: Dictionary) -> Variant:
	var 们: Array = Units.livingOf("ally", ctx).filter(func(a): return MoonPhase.是月球王国(a) and not is_same(a, 菲))
	if 们.is_empty():
		return null
	J.sort(们, func(a, b):
		var d := float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp)
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	return 们[0]
