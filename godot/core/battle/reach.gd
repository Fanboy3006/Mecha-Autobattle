## 30-射程.js：5 类射程、能不能打到、被挡惩罚、职业判定、范围落点。
class_name Reach
extends RefCounted

static func KIND_MELEE() -> String: return Db.T.KIND_MELEE
static func KIND_DIRECT() -> String: return Db.T.KIND_DIRECT
static func KIND_INDIRECT() -> String: return Db.T.KIND_INDIRECT
static func KIND_AREA() -> String: return Db.T.KIND_AREA
static func KIND_HEAL() -> String: return Db.T.KIND_HEAL
static func KIND_SUPPORT() -> String: return Db.T.KIND_SUPPORT

static func rangeKindOf(w: Variant) -> Variant:
	var fire = J.g(w, "fire")
	if fire == "passive" or fire == "device":
		return null
	if fire == "support" and J.truthy(J.or_(w.get("buff"), w.get("grant"))):
		return KIND_SUPPORT()
	return J.or_(J.at(Db.T.RANGE_KIND, fire) if fire != null else null, KIND_DIRECT())

static func isAreaKind(kind: Variant) -> bool:
	return kind == KIND_AREA()

static func isHealKind(kind: Variant) -> bool:
	return kind == KIND_HEAL()

static func isSupportKind(kind: Variant) -> bool:
	return kind == KIND_SUPPORT()

static func hasSupportField(w: Variant) -> bool:
	return w != null and J.truthy(J.or_(w.get("buff"), w.get("grant")))

static func rowReachable(kind: Variant, targetRow: float, frontAlive: bool) -> bool:
	if kind == KIND_MELEE():
		return targetRow == Fm.ROW_FRONT or not frontAlive
	return true

static func 破阵暴露吗(target: Variant, 敌方活位们: Variant, ctx: Variant) -> bool:
	if target == null or target.get("slot") == null:
		return false
	return J.truthy(Params.兰斯破阵暴露(target, 敌方活位们, ctx))

static func 近战可达(att: Variant, w: Variant, target: Variant, 敌方单位们: Variant) -> bool:
	if target == null:
		return false
	var kind = rangeKindOf(w)
	var 们: Array = J.or_(敌方单位们, [])
	var 前排有人 := J.some(们, func(u): return u != null and u.hp > 0 and Units.unitRow(u) == Fm.ROW_FRONT)
	if rowReachable(kind, Units.unitRow(target), 前排有人):
		return true
	if kind != KIND_MELEE():
		return false
	var 活位们 := J.filter(们, func(u): return u != null and u.hp > 0).map(func(u): return u.slot)
	return 破阵暴露吗(target, 活位们, null)

static func rowBlockPenalty(kind: Variant, 目标位: Variant, 活着的位: Variant, attacker: Variant, 目标: Variant) -> float:
	if 职业是(attacker, "狙击"):
		return 0.0
	if kind != KIND_DIRECT():
		return 0.0
	if not Fm.被挡吗(目标位, 活着的位):
		return 0.0
	if FacMith.秘银取消被挡(attacker, 目标):
		return 0.0
	return -20.0

static func 战斗分类Of(u: Variant) -> Variant:
	if u == null:
		return null
	var tags = u.get("tags")
	var t = J.or_(tags.get("战斗分类") if tags is Dictionary else null, null)
	if J.truthy(t):
		return t
	if u.get("side") == "enemy":
		return Params.敌方职业(u.get("key"))
	return null

static func 职业是(u: Variant, k: String) -> bool:
	if u == null:
		return false
	var side = u.get("side")
	if J.truthy(side) and side != "ally" and not Params.对称职业特色开():
		return false
	return 战斗分类Of(u) == k

static func areaSlots(w: Variant, row: float, col: float) -> Array:
	var area = J.or_(J.g(w, "area"), "row")
	var 位 := Fm.slotOf(row, col)
	var out := []
	if area == "all":
		for r in Fm.ROWS():
			for c in int(Fm.行列数(r)):
				out.append(Fm.slotOf(r, c))
	elif area == "col":
		out = Fm.阻挡束(位).duplicate()
	elif area == "cross":
		out = [位]
		var r := Fm.rowOfSlot(位)
		var c := Fm.colOfSlot(位)
		if Fm.有这一列(r, c - 1):
			out.append(Fm.slotOf(r, c - 1))
		if Fm.有这一列(r, c + 1):
			out.append(Fm.slotOf(r, c + 1))
		for s in Fm.对位(位):
			if not J.inc(out, s):
				out.append(s)
	else:
		for c in int(Fm.行列数(row)):
			out.append(Fm.slotOf(row, c))
	return J.sort_num(J.uniq(out))
