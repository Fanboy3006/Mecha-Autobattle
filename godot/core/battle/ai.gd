## 50-AI.js：自动战斗的选武器 / 选目标。
## 「行动方针」已取消（作者 2026-10-15）：集中攻击 / 攻击后排两类候选不迁移，当前方针恒为全军突击。
class_name Ai
extends RefCounted

const 修理阈值 := 0.6

static func isUltimate(w: Variant) -> bool:
	return w != null and (J.inc(Db.T.ULT_UNLOCKS, w.get("unlock")) or w.get("大招") == true)

static func 憋住大招吗(u: Variant, ctx: Variant) -> bool:
	if u == null:
		return false
	if Params.气势总攻开() and ctx != null and ctx.get("当前战术") == "总攻" and u.get("side") == "ally" and Params.气势总攻参数().get("总攻强制放大招") != false:
		return false
	if J.truthy(u.get("holdUlt")):
		return true
	if Params.气势总攻开() and ctx != null and J.truthy(ctx.get("全队憋大招")) and u.get("side") == "ally":
		return true
	return false

static func ultAllowed(u: Variant, w: Variant, ctx: Variant = null) -> bool:
	return isUltimate(w) and not 憋住大招吗(u, ctx)

static func targetScore(exp: float, t: Dictionary, att: Dictionary) -> Dictionary:
	var canKill := exp >= float(t.hp)
	var 权 := Diff.站位权重(att, t) * Params.同路索敌倍率(att, t)
	return {"canKill": canKill, "value": (float(t.hp) if canKill else exp / maxf(1.0, float(t.hp))) * 权}

static func betterTarget(a: Dictionary, b: Variant) -> bool:
	if b == null:
		return true
	if a.canKill != b.canKill:
		return a.canKill
	return a.value > b.value

static func weaponPool(actor: Dictionary, ctx: Dictionary) -> Array:
	var pool := Calc.usableWeapons(actor, ctx).filter(func(e):
		var kind = Reach.rangeKindOf(e.t)
		if kind == null or Reach.isHealKind(kind) or Reach.isSupportKind(kind):
			return false
		if isUltimate(e.t) and 憋住大招吗(actor, ctx):
			return false
		if Boss.Boss本回合禁用(actor, ctx, e.t):
			return false
		return true)
	var ults := pool.filter(func(e): return ultAllowed(actor, e.t, ctx))
	return ults if not ults.is_empty() else pool

static func 局面Of(foes: Array) -> Dictionary:
	return {"前排有人": Units.frontAlive(foes), "活位": foes.map(func(u): return u.slot), "单位们": foes}

static func bestWeaponOn(actor: Dictionary, target: Dictionary, pool: Array, 局面: Dictionary, ctx: Variant) -> Variant:
	var best = null
	for e in pool:
		var kind = Reach.rangeKindOf(e.t)
		if not Reach.近战可达(actor, e.t, target, 局面.单位们):
			continue
		var 罚 := Reach.rowBlockPenalty(kind, target.slot, 局面.活位, actor, target)
		var exp := Calc.expectedDamage(actor, target, e.t, {"blockPenalty": 罚, "turn": ctx.get("turn") if ctx != null else null, "ctx": ctx})
		if best == null or exp > best.exp:
			best = {"entry": e, "exp": exp, "被挡": 罚 < 0}
	return best

static func pickSingleTarget(actor: Dictionary, foes: Array, pool: Array, ctx: Variant) -> Variant:
	var 局面 := 局面Of(foes)
	var best = null
	for t in foes:
		var w = bestWeaponOn(actor, t, pool, 局面, ctx)
		if w == null:
			continue
		var score := targetScore(w.exp, t, actor)
		if betterTarget(score, best.score if best != null else null):
			best = {"target": t, "entry": w.entry, "exp": w.exp, "score": score, "被挡": w.被挡}
	return best

static func pickAreaTarget(actor: Dictionary, foes: Array, pool: Array, ctx: Variant) -> Variant:
	var best = null
	for e in pool:
		if not Reach.isAreaKind(Reach.rangeKindOf(e.t)):
			continue
		for slot in int(Fm.SLOTS()):
			var hit := Reach.areaSlots(e.t, Fm.rowOfSlot(slot), Fm.colOfSlot(slot))
			var inside := foes.filter(func(t): return J.inc(hit, t.slot))
			if inside.is_empty():
				continue
			var total := 0.0
			for t in inside:
				total += Calc.expectedDamage(actor, t, e.t, {"blockPenalty": 0.0, "ctx": ctx})
			if best == null or total > best.exp:
				best = {"target": inside[0], "entry": e, "exp": total, "slot": float(slot), "hit": inside}
	return best

static func chooseAttack(actor: Dictionary, ctx: Dictionary) -> Variant:
	var foes := Units.livingOf(Units.otherSide(actor.side), ctx)
	if foes.is_empty():
		return null
	if not J.truthy(ctx.get("忽略攻击禁令")) and Btl.禁止攻击(actor, ctx):
		return null
	var pool := weaponPool(actor, ctx)
	if pool.is_empty():
		return null
	var areaPool := pool.filter(func(e): return Reach.isAreaKind(Reach.rangeKindOf(e.t)))
	var singlePool := pool.filter(func(e): return not Reach.isAreaKind(Reach.rangeKindOf(e.t)))
	var cands := []
	if not singlePool.is_empty():
		var s = pickSingleTarget(actor, foes, singlePool, ctx)
		if s != null:
			cands.append({"kind": "attack", "weapon": s.entry.t, "target": s.target, "expected": s.exp, "score": s.score, "entry": s.entry, "被挡": s.被挡})
	if not areaPool.is_empty():
		var a = pickAreaTarget(actor, foes, areaPool, ctx)
		if a != null:
			cands.append({"kind": "attack", "weapon": a.entry.t, "target": a.target, "expected": a.exp, "slot": a.slot, "hit": a.hit, "entry": a.entry})
	if cands.is_empty():
		return null
	J.sort(cands, func(x, y):
		var kx = x.score if x.get("score") != null else targetScore(x.expected, x.target, actor)
		var ky = y.score if y.get("score") != null else targetScore(y.expected, y.target, actor)
		if kx.canKill != ky.canKill:
			return -1.0 if kx.canKill else 1.0
		return float(ky.value) - float(kx.value))
	return cands[0]

static func chooseHeal(actor: Dictionary, ctx: Dictionary) -> Variant:
	var pool := Calc.usableWeapons(actor, ctx).filter(func(e): return Reach.isHealKind(Reach.rangeKindOf(e.t)))
	if pool.is_empty():
		return null
	var mates := Units.livingOf(actor.side, ctx)
	var hurt := mates.filter(func(u): return float(u.hp) / float(u.maxHp) < 修理阈值)
	if hurt.is_empty():
		return null
	J.sort(hurt, func(a, b):
		var d := float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp)
		return d if d != 0 else float(a.slot) - float(b.slot))
	var e = pool[0]
	return {"kind": "heal", "weapon": e.t, "target": hurt[0], "entry": e}

static func grantTargetOf(actor: Dictionary, ctx: Dictionary) -> Variant:
	var done := Units.livingOf(actor.side, ctx).filter(func(u):
		return not is_same(u, actor) and J.same(u.get("actedTurn"), ctx.turn) and not J.same(u.get("grantedTurn"), ctx.turn))
	if done.is_empty():
		return null
	var best = null
	for u in done:
		var a = chooseAttack(u, J.merged(ctx, {"忽略攻击禁令": true}))
		var v := float(a.expected) if a != null else 0.0
		if best == null or v > best.v or (v == best.v and float(u.slot) < float(best.u.slot)):
			best = {"u": u, "v": v}
	return best.u

static func chooseSupport(actor: Dictionary, ctx: Dictionary) -> Variant:
	var pool := Calc.usableWeapons(actor, ctx).filter(func(e): return Reach.isSupportKind(Reach.rangeKindOf(e.t)) and not Fac.势力支援关着(e.t))
	if pool.is_empty():
		return null
	var ults := pool.filter(func(e): return ultAllowed(actor, e.t))
	var 有序 := J.concat(ults, pool.filter(func(e): return not J.inc(ults, e)))
	for e in 有序:
		if J.truthy(e.t.get("grant")):
			var t = grantTargetOf(actor, ctx)
			if t != null:
				return {"kind": "grant", "weapon": e.t, "target": t, "entry": e}
			continue
		if J.truthy(e.t.get("buff")):
			var mates := Units.livingOf(actor.side, ctx).filter(func(u): return not is_same(u, actor))
			if not mates.is_empty():
				return {"kind": "buff", "weapon": e.t, "targets": mates, "entry": e}
	return null

static func aiAction(actor: Dictionary, ctx: Dictionary) -> Variant:
	var heal = chooseHeal(actor, ctx)
	if heal != null:
		return heal
	var atk = chooseAttack(actor, ctx)
	if atk != null:
		return atk
	var sup = chooseSupport(actor, ctx)
	if sup != null:
		return sup
	if Btl.禁止攻击(actor, ctx):
		return {"kind": "defend"}
	return null

static func combatClassOf(u: Dictionary, ctx: Variant) -> String:
	var t = u.tags.get("战斗分类") if J.truthy(u.get("tags")) else null
	if J.truthy(t):
		return t
	var kinds := Calc.usableWeapons(u, ctx if ctx != null else {"turn": 1.0}).map(func(e): return Reach.rangeKindOf(e.t))
	if J.every(kinds, func(k): return k == Reach.KIND_MELEE()):
		return "近卫"
	if J.some(kinds, func(k): return k == Reach.KIND_INDIRECT()):
		return "狙击"
	return "重装"

static func pickLowestHp(actor: Dictionary, foes: Array, pool: Array, ctx: Variant) -> Variant:
	var 局面 := 局面Of(foes)
	var best = null
	for t in foes:
		if not J.some(pool, func(e): return Reach.近战可达(actor, e.t, t, 局面.单位们)):
			continue
		var w = bestWeaponOn(actor, t, pool, 局面, ctx)
		if w == null:
			continue
		if best == null or float(t.hp) < float(best.target.hp):
			best = {"target": t, "entry": w.entry, "exp": w.exp, "score": targetScore(w.exp, t, actor), "被挡": w.被挡}
	return best

static func pickBackRowFirst(actor: Dictionary, foes: Array, pool: Array, ctx: Variant) -> Variant:
	var back := foes.filter(func(t): return Units.unitRow(t) == Fm.ROW_BACK)
	if not back.is_empty():
		var s = pickSingleTarget(actor, back, pool, ctx)
		if s != null:
			return s
	return pickSingleTarget(actor, foes, pool, ctx)

static func enemyAction(actor: Dictionary, ctx: Dictionary) -> Variant:
	var foes := Units.livingOf(Units.otherSide(actor.side), ctx)
	if foes.is_empty():
		return null
	# ★ MITH-2：「ECS 隐形」—— 到杨下一次攻击之前，敌人不能选它为目标。
	#   只有秘银 v0.2 会给单位打 `_隐身`；没有隐身单位时这里一个都不筛（既有路径逐字不变）。
	var 可见 := foes.filter(func(t): return not J.truthy(t.get("_隐身")))
	if not 可见.is_empty():
		foes = 可见
	var pool := weaponPool(actor, ctx)
	if pool.is_empty():
		return null
	var cls := combatClassOf(actor, ctx)
	var allMelee := J.every(pool, func(e): return Reach.rangeKindOf(e.t) == Reach.KIND_MELEE())
	var pick = null
	if cls == "狙击":
		pick = pickBackRowFirst(actor, foes, pool, ctx)
	elif allMelee:
		pick = pickLowestHp(actor, foes, pool, ctx)
	if pick == null:
		pick = pickSingleTarget(actor, foes, pool, ctx)
	var areaPool := pool.filter(func(e): return Reach.isAreaKind(Reach.rangeKindOf(e.t)))
	if not areaPool.is_empty():
		var a = pickAreaTarget(actor, foes, areaPool, ctx)
		if a != null and (pick == null or a.exp > pick.exp):
			pick = {"target": a.target, "entry": a.entry, "exp": a.exp, "slot": a.slot, "hit": a.hit}
	if pick == null:
		return null
	return {"kind": "attack", "weapon": pick.entry.t, "target": pick.target, "expected": pick.exp, "slot": pick.get("slot"), "hit": pick.get("hit"), "entry": pick.entry, "被挡": J.truthy(pick.get("被挡"))}

static func hasOverwatch(u: Dictionary, ctx: Variant = null) -> bool:
	# ★ DECK-1：单机牌组模式下压制射击整条链路短路（不查表、不触发）。
	if Params.单机牌组_开(ctx):
		return false
	return u.side == "enemy" and J.inc(Db.T.ENEMY_OVERWATCH, u.key)
