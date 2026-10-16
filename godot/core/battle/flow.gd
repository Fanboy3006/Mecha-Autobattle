## 60-战斗-2-回合流程.js：回合开始（增援 / 势力 / 气势 / 指挥 / 词条 / 发牌）、单位行动、动作结算。
class_name Flow
extends RefCounted

static func 回合开始(ctx: Dictionary) -> void:
	var 在场的: Array = ctx.enemies.duplicate()
	增援(ctx)
	Btl.词条到点自爆(ctx, 在场的)
	Fac.势力回合开始(ctx)
	if Params.气势总攻开() and float(ctx.turn) >= 2 and not J.same(ctx.get("自然气势已加回合"), ctx.turn):
		ctx.自然气势已加回合 = ctx.turn
		Btl.加气势(ctx, 自然加())
	Btl.战术回合(ctx)
	FacMoon.判定月球不动(ctx, Fac.势力参数("月球王国"))
	for 方 in ["ally", "enemy"]:
		for c in Units.livingOf(方, ctx):
			if not Reach.职业是(c, "指挥"):
				continue
			var 同排 := Units.livingOf(方, ctx).filter(func(t): return not is_same(t, c) and Units.unitRow(t) == Units.unitRow(c))
			if not 同排.is_empty():
				for t in 同排:
					Btl.换同源增益(t, "指挥", {"hit": 10.0})
				Btl.pushLog(ctx, "〔指挥〕%s 让同一排的队友命中 +10（本回合）：%s" % [c.name, "、".join(同排.map(func(t): return t.name))],
					J.merged({"类型": "指挥", "单位": c.key, "目标": 同排.map(func(t): return t.key), "目标位们": 同排.map(func(t): return t.slot), "目标方们": 同排.map(func(t): return t.side)}, Btl.谁(c)))
			if Params.职业排位开() and J.is_int(c.slot) and Fm.rowOfSlot(c.slot) == Fm.ROW_BACK:
				var frontAlly = J.find(Units.livingOf(方, ctx), func(t): return not is_same(t, c) and float(t.slot) == float(c.slot) - 4.0)
				if frontAlly != null:
					Btl.换同源增益(frontAlly, "后方本阵", {
						"hit": Params.职业排位数("指挥后排护前排命中", 10),
						"def": Params.职业排位数("指挥后排护前排防御", 15),
						"turns": 1.0,
					})
	Calc.标定经济点名(ctx)
	for u in Units.livingUnits(ctx):
		if not J.truthy(u.get("防御回复")):
			continue
		u.防御回复 = false
		var amt := minf(J.round(float(u.maxHp) * 0.05), float(u.maxHp) - float(u.hp))
		if amt > 0:
			u.hp = float(u.hp) + amt
			Btl.pushLog(ctx, "%s 防御调整完成，回复 %s" % [u.name, J.s(amt)], J.merged({"类型": "回复", "回复": amt, "目标剩余HP": u.hp}, Btl.谁(u), Btl.谁目标(u)))
	Btl.词条冷却延长(ctx)
	Btl.词条隐身刷新(ctx)
	if Params.战术卡牌开(ctx):
		Btl.候补补位(ctx)
		Btl.检查条件发牌(ctx, "回合开始", {"回合": ctx.turn, "_内部自动": true})

static func 自然加() -> float:
	var v := J.num0(Params.气势总攻参数().get("每回合自然加"))
	return v if v != 0 else 10.0

static func 空位(ctx: Dictionary, side: String) -> Variant:
	var 占 := Units.livingOf(side, ctx).map(func(u): return u.slot)
	for r in Fm.ROWS():
		for c in int(Fm.行列数(r)):
			var s := Fm.slotOf(r, c)
			if not J.inc(占, s):
				return s
	return null

static func 增援(ctx: Dictionary) -> void:
	for w in J.or_(ctx.get("波次"), []):
		if w == null or not J.same(w.get("回合"), ctx.turn):
			continue
		var 位们 := []
		var 单位们 := []
		var 没空位 := 0.0
		for e in J.or_(w.get("来"), []):
			var s = 空位(ctx, "enemy")
			if s == null:
				没空位 += 1.0
				continue
			var u := Units.makeUnit(e.键, "enemy", float(s), float(e.等级), e.强化 if e.get("强化") != null else 1.0, null, e.get("层"))
			if J.truthy(e.get("词条")):
				Traits.词条到单位([u], {"词条": e.词条, "层": e.get("层")})
			ctx.enemies.append(u)
			位们.append(s)
			单位们.append(u.key)
		if not 位们.is_empty():
			Btl.pushLog(ctx, "〔增援〕第 %s 回合：敌方 %d 台赶到（%s：%s）" % [J.s(ctx.turn), 位们.size(), "、".join(位们.map(func(s): return Fm.位名(s))), "、".join(单位们)],
				{"类型": "增援", "数量": float(位们.size()), "位们": 位们, "目标方们": 位们.map(func(_s): return "enemy"), "单位们": 单位们})
		if 没空位 != 0:
			Btl.pushLog(ctx, "〔增援〕第 %s 回合：还有 %s 台挤不进来（9 个位都占着）" % [J.s(ctx.turn), J.s(没空位)], {"类型": "增援", "数量": 0.0, "结果": "没空位"})
	if J.some(ctx.enemies, func(u): return J.truthy(u.get("词条全场"))):
		Btl.应用全场词条(ctx)

static func 单位动作(u: Dictionary, ctx: Dictionary) -> Variant:
	if u.side == "enemy":
		return Boss.bossTurn(u, ctx)
	return Ai.aiAction(u, ctx)

static func actOnce(u: Dictionary, ctx: Dictionary) -> void:
	if float(u.hp) <= 0:
		return
	u.actedTurn = ctx.turn
	if J.same(u.get("近卫连斩待追击Turn"), ctx.turn):
		u.近卫连斩追击Turn = ctx.turn
		u.erase("近卫连斩待追击Turn")
	var action = 单位动作(u, ctx)
	var r = null
	if action != null:
		r = resolveAction(u, action, ctx)
	else:
		Btl.pushLog(ctx, "%s 没有能打到人的武器，跳过" % u.name, J.merged({"类型": "跳过", "单位": u.key}, Btl.谁(u)))
	if u.get("近卫连斩追击Turn") != null:
		u.erase("近卫连斩追击Turn")
	runAutoCast(u, ctx)
	var 近卫后排受限: bool = Params.职业排位开() and Params.职业排位参数().get("近卫后排禁连斩") != false \
		and J.is_int(u.slot) and Fm.rowOfSlot(u.slot) == Fm.ROW_BACK \
		and J.some(Units.livingOf(u.side, ctx), func(t): return not is_same(t, u) and float(t.slot) == float(u.slot) - 4.0)
	if r != null and float(r.击破) > 0 and Reach.职业是(u, "近卫") and not J.same(u.get("近卫再动Turn"), ctx.turn) and not 近卫后排受限:
		u.近卫再动Turn = ctx.turn
		u.近卫连斩待追击Turn = ctx.turn
		ctx.again.append(u)
		Btl.pushLog(ctx, "〔连斩〕%s 击破了目标，立刻再行动一次（近卫，每回合 1 次）" % u.name, J.merged({"类型": "连斩"}, Btl.谁(u)))

static func runAutoCast(u: Dictionary, ctx: Dictionary) -> void:
	if J.same(u.get("echoTurn"), ctx.turn):
		return
	var pool := (u.weapons as Array).filter(func(e): return e.t.get("special") == "echo" and float(u.lv) >= J.num(e.t.get("unlock")) and J.num(e.cd) <= 0)
	if pool.is_empty():
		return
	J.sort(pool, func(a, b): return J.num(a.t.unlock) - J.num(b.t.unlock))
	var e = pool[pool.size() - 1]
	var w = e.t
	var foes := Units.livingOf(Units.otherSide(u.side), ctx)
	var targets := foes.filter(func(t): return Units.unitRow(t) == Fm.ROW_FRONT)
	if targets.is_empty():
		return
	u.echoTurn = ctx.turn
	if J.truthy(w.get("cd")):
		e.cd = w.cd
	for t in targets:
		if float(t.hp) <= 0:
			continue
		var rec := Calc.resolveAttack(u, t, w, ctx, {})
		Btl.pushLog(ctx, "〔%s〕%s" % [w.name, rec.文本], J.merged(J.merged({"类型": "残月余响", "单位": u.key, "目标": t.key, "武器": w.name}, Btl.谁(u), Btl.谁目标(t)), rec.字段))
		if float(t.hp) <= 0:
			Fac.势力击破(ctx, u, t)

static func _buff文字(buff: Dictionary) -> String:
	var 们 := []
	for k in buff.keys():
		var v = buff[k]
		们.append("%s %s%s" % [k, "+" if (J.is_num(v) and float(v) > 0) else "", J.s(v)])
	return "、".join(们)

static func resolveAction(actor: Dictionary, action: Dictionary, ctx: Dictionary) -> Dictionary:
	var w = action.get("weapon")
	var 空 := {"击破": 0.0}
	match action.kind:
		"none":
			return 空
		"buff":
			var buff: Dictionary = J.or_(J.or_(Calc.wv(actor, w, "buff"), w.get("buff")), {})
			for t in action.targets:
				Btl.换同源增益(t, w.name, buff)
			Calc.spendWeapon(actor, action.entry)
			Btl.pushLog(ctx, "%s【%s】→ %s：%s（到本回合结束）" % [actor.name, w.name, "、".join(action.targets.map(func(t): return t.name)), _buff文字(buff)],
				J.merged({"类型": "增益", "单位": actor.key, "武器": w.name, "目标": action.targets.map(func(t): return t.key),
					"目标位们": action.targets.map(func(t): return t.slot), "目标方们": action.targets.map(func(t): return t.side)}, Btl.谁(actor)))
			return 空
		"grant":
			var t: Dictionary = action.target
			t.grantedTurn = ctx.turn
			ctx.again.append(t)
			Calc.spendWeapon(actor, action.entry)
			Btl.pushLog(ctx, "%s【%s】→ %s：再行动一次" % [actor.name, w.name, t.name], J.merged(J.merged({"类型": "再动", "单位": actor.key, "目标": t.key}, Btl.谁(actor)), Btl.谁目标(t)))
			return 空
		"defend":
			# 方针已取消：只有「禁止攻击」才会走到这里，现在不会发生；防御给气势（防御每台加 / 每回合上限）不迁移
			actor.defending = true
			actor.防御回复 = true
			Btl.pushLog(ctx, "%s 进入防御（本回合伤害按防御 +50 结算，下回合开始回复 5%% HP）" % actor.name, J.merged({"类型": "防御"}, Btl.谁(actor)))
			return 空
		"heal":
			var tgt: Dictionary = action.target
			var amount := Calc.healAmount(actor, w)
			var before := float(tgt.hp)
			tgt.hp = minf(float(tgt.maxHp), float(tgt.hp) + amount)
			Calc.spendWeapon(actor, action.entry)
			var 回 := float(tgt.hp) - before
			Btl.pushLog(ctx, "%s 修理 %s，回复 %s" % [actor.name, tgt.name, J.s(回)], J.merged(J.merged({
				"类型": "修理", "单位": actor.key, "目标": tgt.key, "武器": w.name, "回复": 回, "目标剩余HP": tgt.hp,
			}, Btl.谁(actor)), Btl.谁目标(tgt)))
			Fac.势力修理(ctx, actor, tgt, w, 回)
			return 空
	var kind = Reach.rangeKindOf(w)
	var 面: bool = Reach.isAreaKind(kind)
	var targets: Array = J.or_(action.get("hit"), []) if 面 else [action.target]
	var 总攻倍 := 1.0
	if Params.气势总攻开() and ctx.get("当前战术") == "总攻" and actor.side == "ally":
		总攻倍 = J.num0(Params.气势总攻参数().get("总攻伤害倍率"))
		if 总攻倍 == 0:
			总攻倍 = 1.35
	var 倍率 := Boss.Boss伤害倍率(actor) * Fac.势力伤害倍率(actor, w) * 总攻倍
	var 威力倍率 := Fac.势力威力倍率(actor, w)
	var 击破 := 0.0
	for t in targets:
		if float(t.hp) <= 0:
			continue
		var 实际: Dictionary = t
		if not 面:
			var 嘲 = Btl.嘲讽(ctx, actor, t)
			if 嘲 != null:
				Btl.pushLog(ctx, "〔嘲讽〕%s 把这一击勾了过去" % 嘲.name, J.merged(J.merged({"类型": "嘲讽", "目标": 嘲.key, "原目标": t.key}, Btl.谁(嘲)), Btl.谁目标(嘲)))
				实际 = 嘲
		var 血 := float(实际.hp)
		var 活位 := Units.livingOf(实际.side, ctx).map(func(x): return x.slot)
		var blockPenalty := 0.0 if 面 else Reach.rowBlockPenalty(kind, 实际.slot, 活位, actor, 实际)
		Fac.势力攻击前(ctx, actor, 实际, w)
		var rec := Calc.resolveAttack(actor, 实际, w, ctx, {"blockPenalty": blockPenalty, "伤害倍率": 倍率, "威力倍率": 威力倍率})
		var 打死了: bool = 血 > 0 and float(实际.hp) <= 0
		if 打死了:
			击破 += 1.0
		Btl.pushLog(ctx, rec.文本, J.merged(J.merged({"类型": "攻击", "单位": actor.key, "目标": 实际.key, "武器": w.name, "集火": false, "守护挡下": false, "原目标": null, "原目标位": null},
			Btl.谁(actor), Btl.谁目标(实际)), rec.字段))
		Calc.标定经济记录(ctx, actor, 实际, {"类型": "攻击", "武器": w.name}, rec.字段.get("标定"))
		if 打死了:
			Fac.势力击破(ctx, actor, 实际)
			Btl.自爆(ctx, actor, 实际)
		if float(rec.字段.伤害) > 0:
			Fac.势力友军攻击后(ctx, actor, 实际, rec.字段)
		if float(rec.字段.伤害) > 0:
			Btl.镜甲反弹(ctx, actor, 实际, rec.字段, w)
		if J.truthy(ctx.get("战况计数")):
			var 计: Dictionary = ctx.战况计数
			var 段数 := J.num0(rec.字段.get("段数"))
			if 段数 == 0:
				段数 = 1.0
			var 命中段 := 0.0 if rec.字段.get("命中") == false else (J.num(rec.字段.命中段数) if rec.字段.get("命中段数") != null else 1.0)
			var 未中段 := maxf(0.0, 段数 - 命中段)
			var 有伤 := J.num(rec.字段.get("伤害")) > 0
			if 有伤 and actor.side == "ally" and Btl.提取单位三层信息(actor).势力 == "月球王国":
				计.残月或月国命中 = float(计.残月或月国命中) + 1.0
			if 未中段 > 0:
				计.未命中段 = J.num0(计.get("未命中段")) + 未中段
				计.响介受击或打空 = float(计.响介受击或打空) + 1.0
			if 有伤 and actor.side == "ally" and Btl._是(actor, "CB1"):
				计.刹那命中或TA = float(计.刹那命中或TA) + 1.0
			if 有伤 and 实际.side == "ally" and Btl._是(实际, "A1"):
				计.响介受击或打空 = float(计.响介受击或打空) + 1.0
			Btl.检查条件发牌(ctx, "攻击后", {
				"攻击者": actor, "目标": 实际, "武器": w, "记录": rec.字段, "伤害": rec.字段.伤害, "命中": rec.字段.命中,
				"暴击": rec.字段.暴击, "击破": 打死了, "未命中段数": 未中段, "_内部自动": true,
			})
	Calc.spendWeapon(actor, action.entry)
	Fac.势力武器用后(ctx, actor, action.entry, w)
	return {"击破": 击破}
