## 72-势力-1-框架与钩子.js：势力特色的框架与引擎钩子。
## JS 用「注册势力特色」把条目挂进一张表、钩子遍历 Object.keys(表)；这里用固定顺序 ORDER（= JS 注册顺序）
## 加上 match 分派，语义一致：只对我方、且 tags.势力 = 该势力的单位生效。
class_name Fac
extends RefCounted

const ORDER := ["殖民卫星军", "月球王国", "天人", "ATX", "秘银"]

static func 势力名(u: Variant) -> Variant:
	if u == null or not J.truthy(u.get("tags")):
		return null
	return J.or_(u.tags.get("势力"), null)

static func 是我方势力(u: Variant, 势力: String) -> bool:
	return u != null and u.get("side") == "ally" and 势力名(u) == 势力

static func 势力参数(势力: String) -> Dictionary:
	var t = Db.T.get("势力特色")
	if t is Dictionary and t.get(势力) is Dictionary:
		return t[势力]
	return {}

static func 势力启用(势力: String) -> bool:
	return 势力参数(势力).get("启用") != false

static func 启用势力们() -> Array:
	return ORDER.filter(func(x): return 势力启用(x))

static func 势力状态(u: Dictionary, 势力: String) -> Dictionary:
	if not J.truthy(u.get("势力状态")):
		u.势力状态 = {}
	if not J.truthy(u.势力状态.get(势力)):
		u.势力状态[势力] = {}
	return u.势力状态[势力]

static func 势力在场(势力: String, ctx: Dictionary) -> Array:
	return Units.livingOf("ally", ctx).filter(func(u): return 是我方势力(u, 势力))

static func 势力记录(ctx: Variant, 文本: String, 字段: Dictionary = {}) -> void:
	if ctx == null:
		return
	Btl.pushLog(ctx, "〔势力〕%s" % 文本, J.merged({"类型": "势力"}, 字段))

# ---------------- 事件钩子 ----------------
static func 势力开局(ctx: Dictionary) -> void:
	for 势力 in 启用势力们():
		var p := 势力参数(势力)
		match 势力:
			"月球王国":
				FacMoon.判定月球王国光环(ctx, p)
				FacMoon.判定月球不动(ctx, p)
			"ATX": FacCb.ATX开局(ctx, p)
			"秘银": FacMith.秘银开局(ctx, p)

static func 势力回合开始(ctx: Dictionary) -> void:
	for 势力 in 启用势力们():
		var p := 势力参数(势力)
		match 势力:
			"月球王国": FacMoon.判定月球王国光环(ctx, p)
			"秘银": FacMith.刷新秘银缓存(ctx, p)

## 钩子薄转发：`我方阶段初_势力` → `势力回合开始`（派发序在 `RuleHooks.顺序` 里）
static func 我方阶段初_势力(ctx: Dictionary) -> void:
	势力回合开始(ctx)

static func 势力回合结束(ctx: Dictionary) -> void:
	for 势力 in 启用势力们():
		var p := 势力参数(势力)
		match 势力:
			"秘银": FacMith.秘银回合结束(ctx, p)

static func 势力击破(ctx: Variant, 击破者: Variant, 被击破者: Variant) -> void:
	if ctx == null or 击破者 == null or 被击破者 == null:
		return
	for 势力 in 启用势力们():
		var p := 势力参数(势力)
		match 势力:
			"月球王国": FacMoon.判定月球王国光环(ctx, p)
			"秘银": FacMith.倒下接力(ctx, 被击破者, p)

static func 势力友军攻击后(ctx: Variant, 攻击者: Variant, 目标: Variant, 一击: Variant) -> float:
	if ctx == null or 攻击者 == null or 攻击者.get("side") != "ally":
		return 0.0
	var 合计 := 0.0
	for 势力 in 启用势力们():
		var p := 势力参数(势力)
		var r := 0.0
		match 势力:
			"月球王国": r = FacMoon.残月追加攻击(ctx, 攻击者, 目标, 一击, p)
			"秘银": r = FacMith.秘银友军攻击后(ctx, 攻击者, 目标, 一击, p)
		合计 += r if is_finite(r) else 0.0
	return 合计

static func 势力逐段未命中(ctx: Variant, 攻击者: Variant, 目标: Variant, 武器: Variant, 段: Dictionary) -> void:
	if ctx == null or 攻击者 == null or 武器 == null:
		return
	for 势力 in 启用势力们():
		if 势力 == "ATX":
			FacCb.ATX逐段未命中(ctx, 攻击者, 目标, 武器, 段, 势力参数(势力))

static func 势力武器用后(ctx: Variant, 使用者: Variant, 条目: Variant, _武器: Variant = null) -> void:
	if ctx == null or 使用者 == null or 条目 == null or 使用者.get("side") != "ally":
		return
	for 势力 in 启用势力们():
		if 势力 == "ATX":
			FacCb.ATX武器用后(ctx, 使用者, 条目, 势力参数(势力))

static func 势力攻击前(ctx: Variant, 攻击者: Variant, 目标: Variant, _武器: Variant) -> void:
	if ctx == null or 攻击者 == null or 目标 == null:
		return
	for 势力 in 启用势力们():
		if 势力 == "秘银":
			FacMith.秘银兑现(ctx, 攻击者, 目标, 势力参数(势力))

static func 势力修理(ctx: Variant, 修理者: Variant, 目标: Variant, 武器: Variant, 回复: Variant) -> void:
	if ctx == null or 修理者 == null or 目标 == null:
		return
	for 势力 in 启用势力们():
		if 势力 == "月球王国":
			FacMoon.战地急救(ctx, 修理者, 目标, 武器, 回复, 势力参数(势力))

# ---------------- 数值钩子 ----------------
static func 段内命中加成(att: Variant, w: Variant, _段: Dictionary) -> float:
	if att == null or att.get("side") != "ally":
		return 0.0
	var n := 0.0
	for 势力 in 启用势力们():
		if 势力 == "月球王国" and 是我方势力(att, 势力):
			# JS 把「段」当成第三个参数传给条目的 (att, w, pt)：段里没有残心键 → 等于读参数表的 连射残心
			n += FacMoon.连射残心(att, w, null)
	return J.round(n)

static func 势力装甲(u: Variant) -> float:
	if u == null or u.get("side") != "ally":
		return 0.0
	var n := 0.0
	for 势力 in 启用势力们():
		if 势力 == "月球王国" and 是我方势力(u, 势力):
			n += FacMoon.不动装甲(u, 势力参数(势力))
	return J.round(n)

static func 势力闪避(_u: Variant) -> float:
	# 现有势力都没有「闪避加成」条目
	return 0.0

static func 势力防御(_u: Variant) -> float:
	# 现有势力都没有「防御加成」条目
	return 0.0

static func 势力觉醒成长(_u: Variant) -> float:
	# 现有势力都没有「觉醒值成长」条目
	return 0.0

static func 势力觉醒值(u: Variant) -> float:
	var base := 100.0
	if u != null and u.get("awaken") != null:
		base = float(u.awaken)
	return base + 势力觉醒成长(u)

static func 势力伤害倍率(_u: Variant, _w: Variant) -> float:
	# 现有势力都没有「伤害倍率」条目
	return 1.0

static func 势力威力倍率(_u: Variant, _w: Variant) -> float:
	# 现有势力都没有「威力倍率」条目
	return 1.0

## 已接的「势力支援武器」被 `启用: false` 关掉了吗（目前只有 ATX 的「好运加护」）
static func 势力支援关着(w: Variant) -> bool:
	if w == null or w.get("name") != "好运加护":
		return false
	var p := 势力参数("ATX")
	return J.truthy(p.get("已接好运加护")) and p.get("启用") == false
