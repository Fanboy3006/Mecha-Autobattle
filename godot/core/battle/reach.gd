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
	# `无视前排`（近卫的破隐一击 / 死神的收割）：直接按真实位距判，不吃「只能打前排」。
	if J.truthy(J.g(w, "无视前排")) and kind == KIND_MELEE():
		var 距 := Calc.攻击距离(att, target)
		var 界 := 武器距离(w)
		return 距 >= 界.x and 距 <= 界.y
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
	elif area == "col" or area == "pierce":
		out = Fm.阻挡束(位).duplicate()
	elif area == "cross" or area == "splash":
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
	elif area == "single":
		out = [位]
	else:
		for c in int(Fm.行列数(row)):
			out.append(Fm.slotOf(row, c))
	return J.sort_num(J.uniq(out))

# ==========================================================================================
# ★ MITH3-1：《武器范围规则 v0.1》的落点实现（`area` 五型 · 顶位 · 遮挡 · `远距 N`）
#
#   调用纪律：这些函数由 `flow.gd` / `btl.gd` 在算落点 / 阻挡时调到（规则 v0.1 已是唯一口径）。
#   纯读纪律：一个随机数都不掷、一个状态都不改（`武器可达吗` 的 `why` 只拼字符串）。
# ==========================================================================================

## `area` 的五种写法（任务单 §1.1 第 4 条）：`single` / `splash` / `pierce` / `row` / `all`。
const AREA_SINGLE := "single"
const AREA_SPLASH := "splash"
const AREA_PIERCE := "pierce"
const AREA_ROW := "row"
const AREA_ALL := "all"

## 武器上的 `area` 归一化：新写法优先；老的 `col` / `cross` 折进来（`col`→`pierce`、`cross`→`splash`）。
static func 范围型(w: Variant) -> String:
	var a := str(J.or_(J.g(w, "area"), ""))
	match a:
		"single", "splash", "pierce", "row", "all":
			return a
		"col":
			return AREA_PIERCE
		"cross":
			return AREA_SPLASH
		"":
			return AREA_SINGLE
	return a

## 武器是不是「打一片」（= 目标由落点表决定，不是单个目标）。
static func 是范围武器(w: Variant) -> bool:
	return 范围型(w) != AREA_SINGLE

## 武器的有效距离 `[min_range, max_range]`（读 `距离` 优先，其次老的 `range`）。
## 没有写距离 = `[1, 6]`（整张 4×4 战场都够）。
static func 武器距离(w: Variant) -> Vector2i:
	if not (w is Dictionary):
		return Vector2i(1, 6)
	var 距 = w.get("距离")
	if 距 is Array and (距 as Array).size() >= 2:
		return Vector2i(int(距[0]), int(距[1]))
	var 老 = w.get("range")
	if 老 is Array and (老 as Array).size() >= 2:
		return Vector2i(int(老[0]), int(老[1]))
	return Vector2i(1, 6)

## 武器有没有「无视遮挡」（`ignore_block` / `无视遮挡` 两种写法）。
static func 无视遮挡(w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	return J.truthy(w.get("ignore_block")) or J.truthy(w.get("无视遮挡"))

## 打出者身上有没有「破障射击」（本回合直射无视遮挡）。
static func 有破障射击(u: Variant) -> bool:
	for b in J.or_(u.get("buffs") if u != null else null, []):
		if b is Dictionary and str(b.get("src", "")) == "破障射击" and float(b.get("剩余", 1.0)) > 0.0:
			return true
	return false

## 打出者身上有没有「后方渗透」（本回合近战可直接打敌方后排）。
static func 有后方渗透(u: Variant) -> bool:
	for b in J.or_(u.get("buffs") if u != null else null, []):
		if b is Dictionary and str(b.get("src", "")) == "后方渗透" and float(b.get("剩余", 1.0)) > 0.0:
			return true
	return false

## 这台单位对这把武器「算不算站在前排」（近战资格 / 顶位）。
static func 前排资格(ctx: Variant, u: Variant) -> bool:
	return Fm.是前排有效(u, ctx)

## 命中修正：直射打敌方**后排**时，若目标同列（`slot = col(t)`）的前排格有存活单位或掩体，
## 且武器不带 `ignore_block`、打出者也没有「破障射击」→ **命中 −20**。
static func 遮挡命中惩罚(ctx: Variant, u: Variant, w: Variant, t: Variant) -> float:
	if not (t is Dictionary) or t.get("slot") == null:
		return 0.0
	if rangeKindOf(w) != KIND_DIRECT():
		return 0.0
	if Fm.rowOfSlot(float(t.slot)) != Fm.ROW_BACK:
		return 0.0
	if 无视遮挡(w) or 有破障射击(u):
		return 0.0
	var 同列前 := Fm.另一排同位(t.slot)
	if 同列前 < 0:
		return 0.0
	if not Fm.格被占(ctx, str(t.get("side", "enemy")), 同列前):
		return 0.0
	return -20.0

## ★ 任务单 §2 的核心口子：`武器可达吗(ctx, u, w, t) -> {ok, dist, why}`。
##   · 近战：攻击方必须是前排有效（前排或顶位），目标也必须是前排有效 ——
##     除非武器 `ignore_block` 或打出者带「后方渗透」；
##   · 直射 / 曲射：任何排都能打，只看距离；
##   · 距离一律 `dist in [min_range, max_range]`（近战用 `近战距离`，其余用 `真实距离`）。
static func 武器可达吗(ctx: Variant, u: Variant, w: Variant, t: Variant) -> Dictionary:
	if not (u is Dictionary) or not (t is Dictionary) or u.get("slot") == null or t.get("slot") == null:
		return {"ok": false, "dist": 0, "why": "没有目标"}
	if str(u.get("side", "")) == str(t.get("side", "")):
		return {"ok": false, "dist": 0, "why": "不能打自己人"}
	var kind = rangeKindOf(w)
	var 近战: bool = kind == KIND_MELEE()
	var 甲顶 := Fm.是否顶位(ctx, str(u.get("side", "")))
	var 乙顶 := Fm.是否顶位(ctx, str(t.get("side", "")))
	var 距 := Fm.格距离(float(u.slot), float(t.slot), 近战, 甲顶, 乙顶)
	# ★ A6a：尖兵分类牌【绕后奇袭】—— 打出者的**下一张武器牌**无视距离上下限，可以打任意一格。
	#   只有这台机体挂着那个一次性标记时为真；其余情况走普通的距离 / 站位判定。
	if ClassCards.绕后奇袭(ctx, u):
		return {"ok": true, "dist": 距, "why": ""}
	var 界 := 武器距离(w)
	if 近战:
		var 无视拦: bool = 无视遮挡(w) or 有后方渗透(u)
		if not 前排资格(ctx, u) and not 无视拦:
			return {"ok": false, "dist": 距, "why": "近战要先站到前排（或在顶位）"}
		if not 前排资格(ctx, t) and not 无视拦:
			return {"ok": false, "dist": 距, "why": "近战打不到敌方后排（前排还有人挡着）"}
	if kind == KIND_DIRECT() and Fm.rowOfSlot(float(t.slot)) == Fm.ROW_BACK and not 无视遮挡(w) \
			and 封锁线成立(ctx, str(t.get("side", ""))):
		return {"ok": false, "dist": 距, "why": "封锁线：敌方前排 4 格塞满，直射打不到后排"}
	if 距 < 界.x:
		return {"ok": false, "dist": 距, "why": "太近了（距离 %d < 下限 %d）" % [距, 界.x]}
	if 距 > 界.y:
		return {"ok": false, "dist": 距, "why": "太远了（距离 %d > 上限 %d）" % [距, 界.y]}
	return {"ok": true, "dist": 距, "why": ""}

## N1【封锁线】：这一方前排 4 格都被占（活机体或掩体），且还有活着的带 `封锁线` 的机体。
static func 封锁线成立(ctx: Variant, side: String) -> bool:
	if not (ctx is Dictionary) or side.is_empty():
		return false
	var 们: Array = J.or_(ctx.get("enemies") if side == "enemy" else ctx.get("allies"), [])
	var 有 := false
	for u in 们:
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and J.truthy(u.get("封锁线")):
			有 = true
			break
	if not 有:
		return false
	for i in int(Fm.行列数(Fm.ROW_FRONT)):
		if not Fm.格被占(ctx, side, int(Fm.slotOf(Fm.ROW_FRONT, float(i)))):
			return false
	return true

## 界面用：「完整」/ 空串（这一方没有封锁线机体，或前排有缺口）。
static func 封锁线状态(ctx: Variant, side: String) -> String:
	return "完整" if 封锁线成立(ctx, side) else ""

## 便捷读法：只问能不能打。
static func 够得着吗(ctx: Variant, u: Variant, w: Variant, t: Variant) -> bool:
	return J.truthy(武器可达吗(ctx, u, w, t).get("ok"))

## 落点表（按 `area` 五型展开），每项 `{位: int, 倍率: float, 主目标: bool}`。
##   · `single`  → 只有目标自己（100%）；
##   · `splash`  → 目标 100% + 十字相邻格 `splash_mul`（默认 0.5，`+` 版 0.75）；
##   · `pierce`  → 目标 100% + **同列另一排** `pierce_mul`（默认 0.5）；
##   · `row`     → 目标所在排全部 4 格（100%）；
##   · `all`     → 敌方全部 8 格（100%）。
static func 范围落点(w: Variant, t: Variant) -> Array:
	var 出: Array = []
	if not (t is Dictionary) or t.get("slot") == null:
		return 出
	var 位 := int(t.slot)
	var 型 := 范围型(w)
	var 主亿 := float(J.or_(J.g(w, "splash_mul"), 0.5))
	var 穿亿 := float(J.or_(J.g(w, "pierce_mul"), 0.5))
	match 型:
		AREA_SPLASH:
			for s in Fm.十字相邻位(位):
				出.append({"位": s, "倍率": 主亿, "主目标": false})
		AREA_PIERCE:
			var 对 := Fm.另一排同位(位)
			if 对 >= 0:
				出.append({"位": 对, "倍率": 穿亿, "主目标": false})
		AREA_ROW:
			var r := Fm.rowOfSlot(float(位))
			for c in int(Fm.行列数(r)):
				var s2 := int(Fm.slotOf(r, c))
				if s2 != 位:
					出.append({"位": s2, "倍率": 1.0, "主目标": false})
		AREA_ALL:
			for r2 in Fm.ROWS():
				for c2 in int(Fm.行列数(r2)):
					var s3 := int(Fm.slotOf(r2, c2))
					if s3 != 位:
						出.append({"位": s3, "倍率": 1.0, "主目标": false})
		_:
			pass
	出.push_front({"位": 位, "倍率": 1.0, "主目标": true})
	return 出

## 范围落点 → 具体单位（只挑**同方且存活**的）。返回 `[{单位: Dictionary, 倍率: float, 主目标: bool}]`。
static func 范围目标们(ctx: Variant, w: Variant, t: Variant) -> Array:
	var 出: Array = []
	if not (t is Dictionary) or not (ctx is Dictionary):
		return 出
	var 方 := str(t.get("side", "enemy"))
	var 活 := Units.livingOf(方, ctx)
	for e in 范围落点(w, t):
		for u in 活:
			if u != null and int(u.get("slot", -1)) == int(e.get("位", -1)):
				出.append({"单位": u, "倍率": float(e.get("倍率", 1.0)), "主目标": J.truthy(e.get("主目标"))})
				break
	return 出
