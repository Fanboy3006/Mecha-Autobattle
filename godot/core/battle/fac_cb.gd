## 72-势力-4：ATX（赌徒的直觉）。
class_name FacCb
extends RefCounted

static func ATX参数() -> Dictionary:
	return Fac.势力参数("ATX")

static func _状(u: Variant, 势力: String) -> Variant:
	if u == null or not J.truthy(u.get("势力状态")):
		return null
	return u.势力状态.get(势力)

# ======================== ATX ========================
static func 有赌徒直觉(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else ATX参数()
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, J.or_(参.get("特技"), "gamblerSense"))

static func 是减冷却武器(w: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else ATX参数()
	return w != null and J.truthy(w.get(J.or_(参.get("武器标记"), "evadeCd")))

static func ATX打空(u: Variant) -> float:
	var s = _状(u, "ATX")
	return J.num0(s.get("打空")) if s != null else 0.0

static func ATX余量(u: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else ATX参数()
	return maxf(0.0, ATX打空(u) - J.num0(参.get("余量起算")))

static func ATX武器们(u: Variant, p: Variant) -> Array:
	return J.or_(u.get("weapons") if u != null else null, []).filter(func(e):
		return e != null and J.truthy(e.get("t")) and 是减冷却武器(e.t, p) and float(u.lv) >= J.num0(e.t.get("unlock")))

static func ATX减冷却(u: Variant, n: float, p: Variant) -> float:
	var 参 = p if J.truthy(p) else ATX参数()
	if u == null or n == 0 or n <= 0:
		return 0.0
	var 每段 := J.num(参.get("每段减冷却"))
	var 步 := 每段 if (is_finite(每段) and 每段 > 0) else 1.0
	if not Fac.是我方势力(u, "ATX") or not 有赌徒直觉(u, 参):
		return 0.0
	var 减了 := 0.0
	for e in ATX武器们(u, 参):
		var 剩 := n * 步
		var 开场 := maxf(0.0, (1.0 if e.get("readyTurn") == null else float(e.readyTurn)) - 1.0)
		var 抵开场 := minf(剩, 开场)
		if 抵开场 > 0:
			e.readyTurn = float(e.readyTurn) - 抵开场
			剩 -= 抵开场
			减了 += 抵开场
		if 剩 > 0 and J.num(e.cd) > 0:
			var 抵cd := minf(剩, float(e.cd))
			e.cd = float(e.cd) - 抵cd
			减了 += 抵cd
	return 减了

static func ATX逐段未命中(ctx: Variant, 攻击者: Variant, 目标: Variant, w: Variant, 段: Variant, p: Variant) -> float:
	if ctx == null or w == null:
		return 0.0
	# ★ A4（v0.3）：「每打空一段 → ATX 角色牌冷却 −1」已整体停用（由 A2 的【九死一生】轮转取代）。
	#   **打空计数照常记**（`状.打空` 不许少记 → 赌神「翻盘的段仍记为打空」要靠它）。
	var 参 = p if J.truthy(p) else ATX参数()
	var 队 := Fac.势力在场("ATX", ctx).filter(func(u): return 有赌徒直觉(u, 参) and not ATX武器们(u, 参).is_empty())
	if 队.is_empty():
		return 0.0
	var 上限 := maxf(0.0, J.round(J.num0(参.get("每回合上限"))))
	var 段号 = J.or_(J.g(段, "段号"), 1.0)
	var 段数 = J.or_(J.g(段, "段数"), 1.0)
	var 记了 := 0.0
	for u in 队:
		var 状 := Fac.势力状态(u, "ATX")
		if not J.same(状.get("本回合号"), ctx.turn):
			状.本回合号 = ctx.turn
			状.本回合次数 = 0.0
		if 上限 > 0 and J.num0(状.get("本回合次数")) >= 上限:
			continue
		状.打空 = J.num0(状.get("打空")) + 1.0
		状.本回合次数 = J.num0(状.get("本回合次数")) + 1.0
		记了 += 1.0
	return 记了

static func ATX武器用后(ctx: Variant, 使用者: Variant, 条目: Variant, p: Variant) -> float:
	if ctx == null or 使用者 == null or 条目 == null or not J.truthy(条目.get("t")):
		return 0.0
	# ★ A4：「余量抵冷却」这条 v0.2 被动已整体停用（同一条赌徒的直觉）。
	return 0.0

static func ATX开局(ctx: Dictionary, p: Variant) -> void:
	var 参 = p if J.truthy(p) else ATX参数()
	var 加 := maxf(0.0, J.round(J.num0(参.get("初始CD"))))
	for u in Units.livingOf("ally", ctx):
		if not Fac.是我方势力(u, "ATX"):
			continue
		var 状 := Fac.势力状态(u, "ATX")
		状.打空 = 0.0
		状.本回合号 = ctx.turn
		状.本回合次数 = 0.0
		if 加 == 0:
			continue
		for e in ATX武器们(u, 参):
			e.readyTurn = (1.0 if e.get("readyTurn") == null else float(e.readyTurn)) + 加
		var 们 := ATX武器们(u, 参)
		if not 们.is_empty():
			Fac.势力记录(ctx, "ATX %s：初始 CD +%s 回合（初稿常量「初始CD」；左轮打桩机 第 %s 回合起可用 —— 作者原话「太强就加初始CD就行」）" % [u.name, J.s(加), J.s(们[0].readyTurn)],
				{"势力": "ATX", "特色": "赌徒的直觉", "结果": "初始CD", "单位": u.key, "单位方": u.side, "单位位": u.slot, "初始CD": 加})
