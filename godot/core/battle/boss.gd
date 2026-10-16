## 61-Boss.js：站桩 Boss 脚本（阶段 / 大技能间隔 / 伤害倍率）。
class_name Boss
extends RefCounted

static func 取Boss脚本(u: Variant) -> Variant:
	if u == null or u.get("side") != "enemy" or not J.truthy(u.get("key")):
		return null
	if J.truthy(u.get("词条Boss")):
		return u.词条Boss
	return J.at(Db.T.Boss脚本, u.key)

static func Boss触发阈值(触发: Variant) -> Variant:
	if J.is_num(触发):
		return float(触发) / 100.0 if float(触发) > 1 else float(触发)
	if 触发 == "半血":
		return 0.5
	return null

static func Boss阶段序号(u: Dictionary) -> int:
	var s = 取Boss脚本(u)
	if s == null or not J.is_arr(s.get("阶段")) or s.阶段.is_empty() or not (float(u.maxHp) > 0):
		return 0
	var 血比 := float(u.hp) / float(u.maxHp)
	var n := 0
	for i in s.阶段.size():
		var t = Boss触发阈值(s.阶段[i].get("触发") if s.阶段[i] != null else null)
		if t != null and 血比 <= float(t):
			n = i + 1
	return n

static func Boss参数(u: Variant) -> Variant:
	var s = 取Boss脚本(u)
	if s == null:
		return null
	var 阶段 := Boss阶段序号(u)
	var o = J.or_(s.阶段[阶段 - 1] if 阶段 > 0 else null, {})
	var 取 := func(k: String, d: Variant) -> Variant:
		if o.get(k) != null:
			return o[k]
		return s[k] if s.get(k) != null else d
	return {"脚本": s, "阶段": float(阶段), "第几阶段": float(阶段 + 1),
		"大技能间隔": 取.call("大技能间隔", 0.0), "大技能武器": 取.call("大技能武器", null), "伤害倍率": 取.call("伤害倍率", 1.0)}

static func Boss本回合放大技能(u: Variant, ctx: Variant) -> bool:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器) or not (J.num(p.大技能间隔) > 0):
		return false
	if ctx == null or ctx.get("turn") == null:
		return false
	return J.mod(float(ctx.turn) - 1.0, float(p.大技能间隔)) == 0

static func Boss下次技能回合(u: Variant, ctx: Variant) -> Variant:
	var p = Boss参数(u)
	if p == null or not (J.num(p.大技能间隔) > 0) or ctx == null or ctx.get("turn") == null:
		return null
	var 间隔 := float(p.大技能间隔)
	return float(ctx.turn) + (间隔 - J.mod(float(ctx.turn) - 1.0, 间隔))

static func Boss本回合禁用(u: Variant, ctx: Variant, w: Variant) -> bool:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器) or not (J.num(p.大技能间隔) > 0):
		return false
	if w == null or w.get("name") != p.大技能武器:
		return false
	if ctx == null or ctx.get("turn") == null:
		return false
	return not Boss本回合放大技能(u, ctx)

static func Boss伤害倍率(u: Variant) -> float:
	var p = Boss参数(u)
	var v = p.伤害倍率 if p != null else 1.0
	return float(v) if (J.is_num(v) and float(v) > 0) else 1.0

static func Boss大技能条目(u: Dictionary, ctx: Dictionary) -> Variant:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器):
		return null
	return J.find(Calc.usableWeapons(u, ctx), func(e): return e.t.name == p.大技能武器)

static func 单武器动作(u: Dictionary, 条目: Variant, ctx: Dictionary) -> Variant:
	var foes := Units.livingOf(Units.otherSide(u.side), ctx)
	if 条目 == null or foes.is_empty():
		return null
	var w = 条目.t
	var pool := [条目]
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		var a = Ai.pickAreaTarget(u, foes, pool, null)
		if a != null:
			return {"kind": "attack", "weapon": w, "target": a.target, "expected": a.exp, "slot": a.slot, "hit": a.hit, "entry": a.entry, "被挡": false}
	var s = Ai.pickSingleTarget(u, foes, pool, ctx)
	if s != null:
		return {"kind": "attack", "weapon": w, "target": s.target, "expected": s.exp, "entry": s.entry, "被挡": J.truthy(s.被挡)}
	return null

static func bossAction(u: Dictionary, ctx: Dictionary) -> Variant:
	if 取Boss脚本(u) == null:
		return Ai.enemyAction(u, ctx)
	if Boss本回合放大技能(u, ctx):
		var a = 单武器动作(u, Boss大技能条目(u, ctx), ctx)
		if a != null:
			a.大技能 = true
			a.第几阶段 = Boss参数(u).第几阶段
			return a
	return Ai.enemyAction(u, ctx)

static func bossTurn(u: Dictionary, ctx: Dictionary) -> Variant:
	var p = Boss参数(u)
	if p == null:
		return Ai.enemyAction(u, ctx)
	var 已报 := J.num0(u.get("boss阶段已报"))
	if float(p.第几阶段) > 已报:
		u.boss阶段已报 = p.第几阶段
		var 文: String
		if float(p.第几阶段) > 1:
			文 = "〔Boss〕%s 进入第 %s 阶段（大技能间隔 %s 回合、伤害倍率 ×%s）" % [u.name, J.s(p.第几阶段), J.s(p.大技能间隔), J.s(p.伤害倍率)]
		else:
			var 中 := "每 %s 回合放一次【%s】" % [J.s(p.大技能间隔), J.s(p.大技能武器)] if (J.num(p.大技能间隔) > 0 and J.truthy(p.大技能武器)) else "（没配大技能）"
			文 = "〔Boss〕%s 站桩 Boss：%s（伤害倍率 ×%s）" % [u.name, 中, J.s(p.伤害倍率)]
		Btl.pushLog(ctx, 文, J.merged({"类型": "Boss", "Boss事件": "阶段", "Boss阶段": p.第几阶段, "大技能间隔": p.大技能间隔, "伤害倍率": p.伤害倍率}, Btl.谁(u)))
	var a = bossAction(u, ctx)
	if a == null:
		var 下次 = Boss下次技能回合(u, ctx)
		var 尾 := "（第 %s 回合释放【%s】）" % [J.s(下次), J.s(p.大技能武器)] if J.truthy(下次) else ""
		Btl.pushLog(ctx, "〔Boss〕%s 蓄力中%s" % [u.name, 尾], J.merged({"类型": "Boss", "Boss事件": "蓄力", "大技能回合": 下次}, Btl.谁(u)))
		return {"kind": "none"}
	if J.truthy(a.get("大技能")):
		Btl.pushLog(ctx, "〔Boss〕%s 释放【%s】" % [u.name, a.weapon.name], J.merged({"类型": "Boss", "Boss事件": "大技能", "BOSS大技能": true, "武器": a.weapon.name,
			"目标": a.target.key if a.target != null else null, "目标位": a.target.slot if a.target != null else null}, Btl.谁(u)))
	return a
