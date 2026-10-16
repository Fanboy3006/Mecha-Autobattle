## 72-势力-4：天人（TRANS-AM）与 ATX（赌徒的直觉）。
class_name FacCb
extends RefCounted

static func 天人参数() -> Dictionary:
	return Fac.势力参数("天人")

static func ATX参数() -> Dictionary:
	return Fac.势力参数("ATX")

static func _状(u: Variant, 势力: String) -> Variant:
	if u == null or not J.truthy(u.get("势力状态")):
		return null
	return u.势力状态.get(势力)

static func 有TRANSAM(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 天人参数()
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, J.or_(参.get("特技"), "transAm"))

static func 天人激活(u: Variant) -> bool:
	var s = _状(u, "天人")
	return s != null and J.truthy(s.get("激活"))

static func 天人手动(u: Variant) -> bool:
	return u != null and J.truthy(u.get("TRANSAM手动"))

static func 开启天人(ctx: Variant, u: Dictionary, 回合: float, 状: Dictionary, 参: Dictionary, 额外: Variant = null) -> void:
	状.启动回合 = 回合
	状.结束回合 = 回合 + float(参.持续回合)
	状.冷却到回合 = float(状.结束回合) + float(参.冷却回合) - 1.0
	状.开启次数 = J.num0(状.get("开启次数")) + 1.0
	状.激活 = true
	状.冷却中 = false
	状.结束已记 = null
	状.剩余回合 = maxf(0.0, float(状.结束回合) - 回合)
	状.冷却剩余 = 0.0
	if ctx != null and J.truthy(ctx.get("战况计数")) and (u.key == "CB1" or u.get("tplKey") == "CB1"):
		ctx.战况计数.刹那命中或TA = J.num0(ctx.战况计数.get("刹那命中或TA")) + 1.0
	var 标记 := "（手动开启）" if (额外 != null and 额外.get("开启方式") == "手动") else ""
	var 文 := "天人 %s 的 TRANS-AM 启动%s！第 %s–%s 回合：所有武器威力 ×%s、闪避 +%s（持续 %s 回合）；之后冷却 %s 回合，第 %s 回合可以再启动" % [
		u.name, 标记, J.s(回合), J.s(float(状.结束回合) - 1.0), J.s(参.威力倍率), J.s(参.闪避加成), J.s(参.持续回合), J.s(参.冷却回合), J.s(状.冷却到回合)]
	Fac.势力记录(ctx, 文, J.merged({
		"势力": "天人", "特色": "TRANS-AM", "结果": "启动", "单位": u.key, "单位方": u.side, "单位位": u.slot,
		"启动回合": 回合, "结束回合": 状.结束回合, "冷却到回合": 状.冷却到回合,
		"持续回合": 参.持续回合, "冷却回合": 参.冷却回合,
		"威力倍率": 参.威力倍率, "闪避加成": 参.闪避加成, "第几次": 状.开启次数,
	}, 额外 if 额外 != null else {}))

static func 推进天人(ctx: Variant, 回合: float, p: Variant) -> float:
	if ctx == null:
		return 0.0
	var 参: Dictionary = p if J.truthy(p) else 天人参数()
	var 启动数 := 0.0
	for u in Fac.势力在场("天人", ctx):
		if not 有TRANSAM(u, 参):
			continue
		var 状 := Fac.势力状态(u, "天人")
		if J.same(状.get("已推进回合"), 回合):
			continue
		状.已推进回合 = 回合
		if float(u.lv) < J.num0(参.get("解锁等级")):
			状.激活 = false
			状.冷却中 = false
			状.剩余回合 = 0.0
			状.冷却剩余 = 0.0
			continue
		var 启动 := J.num0(状.get("启动回合"))
		var 结束 := J.num0(状.get("结束回合"))
		var 冷却到 := J.num0(状.get("冷却到回合"))
		if 启动 != 0 and 回合 >= 结束 and not J.same(状.get("结束已记"), 启动):
			状.结束已记 = 启动
			Fac.势力记录(ctx, "天人 %s 的 TRANS-AM 结束（第 %s–%s 回合生效，持续 %s 回合）→ 冷却中：冷却 %s 回合，第 %s 回合可以再启动" % [
				u.name, J.s(启动), J.s(结束 - 1.0), J.s(参.持续回合), J.s(参.冷却回合), J.s(冷却到)], {
				"势力": "天人", "特色": "TRANS-AM", "结果": "结束", "单位": u.key, "单位方": u.side, "单位位": u.slot,
				"启动回合": 启动, "结束回合": 结束, "冷却到回合": 冷却到, "持续回合": 参.持续回合, "冷却回合": 参.冷却回合,
			})
		if 启动 != 0 and 回合 < 结束:
			状.激活 = true
			状.冷却中 = false
		elif 启动 != 0 and 回合 < 冷却到:
			状.激活 = false
			状.冷却中 = true
		elif 天人手动(u):
			状.激活 = false
			状.冷却中 = false
		else:
			开启天人(ctx, u, 回合, 状, 参)
			启动数 += 1.0
		状.剩余回合 = maxf(0.0, float(状.结束回合) - 回合) if 状.激活 else 0.0
		状.冷却剩余 = maxf(0.0, float(状.冷却到回合) - 回合) if 状.冷却中 else 0.0
	return 启动数

static func 手动开天人(ctx: Variant, 回合: float, p: Variant) -> float:
	if ctx == null:
		return 0.0
	var 参: Dictionary = p if J.truthy(p) else 天人参数()
	var 开数 := 0.0
	for u in Fac.势力在场("天人", ctx):
		if not J.truthy(u.get("本回合开TRANSAM")):
			continue
		u.本回合开TRANSAM = false
		if not 天人手动(u):
			continue
		if not 有TRANSAM(u, 参):
			continue
		var 状 := Fac.势力状态(u, "天人")
		if float(u.lv) < J.num0(参.get("解锁等级")):
			continue
		if J.truthy(状.get("激活")):
			continue
		if 回合 < J.num0(状.get("冷却到回合")):
			continue
		开启天人(ctx, u, 回合, 状, 参, {"开启方式": "手动"})
		开数 += 1.0
	if 开数 > 0 and J.truthy(ctx.get("战况计数")):
		Btl.检查条件发牌(ctx, "手动TRANSAM", {"开启数": 开数})
	return 开数

static func 天人开局(ctx: Dictionary, p: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		if not Fac.是我方势力(u, "天人"):
			continue
		var 状 := Fac.势力状态(u, "天人")
		状.启动回合 = 0.0
		状.结束回合 = 0.0
		状.冷却到回合 = 0.0
		状.开启次数 = 0.0
		状.激活 = false
		状.冷却中 = false
		状.剩余回合 = 0.0
		状.冷却剩余 = 0.0
		状.结束已记 = null
		状.已推进回合 = null
	推进天人(ctx, float(ctx.turn), p)
	手动开天人(ctx, float(ctx.turn), p)

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
		var 减 := ATX减冷却(u, 1.0, 参)
		var 名单 := ATX武器们(u, 参).map(func(e): return e.t.name)
		Fac.势力记录(ctx, "ATX %s【赌徒的直觉】%s 打空了（第 %s/%s 段）：%s 冷却 −1（本场累计 %s 段；本回合第 %s%s 段）" % [
			u.name, 攻击者.name, J.s(段号), J.s(段数), "、".join(名单), J.s(状.打空), J.s(状.本回合次数), "/%s" % J.s(上限) if 上限 != 0 else ""], {
			"势力": "ATX", "特色": "赌徒的直觉", "结果": "打空", "单位": u.key, "单位方": u.side, "单位位": u.slot,
			"攻击者": 攻击者.key, "目标": 目标.key if 目标 != null else 目标, "武器": w.name, "段号": 段号, "段数": 段数,
			"打空累计": 状.打空, "本回合次数": 状.本回合次数, "每回合上限": 上限, "真的减了冷却": 减,
		})
	return 记了

static func ATX武器用后(ctx: Variant, 使用者: Variant, 条目: Variant, p: Variant) -> float:
	if ctx == null or 使用者 == null or 条目 == null or not J.truthy(条目.get("t")):
		return 0.0
	var 参 = p if J.truthy(p) else ATX参数()
	if not Fac.是我方势力(使用者, "ATX") or not 有赌徒直觉(使用者, 参):
		return 0.0
	if not 是减冷却武器(条目.t, 参):
		return 0.0
	var 余 := ATX余量(使用者, 参)
	if 余 <= 0:
		return 0.0
	var 前 := J.num0(条目.get("cd"))
	if 余 >= J.num0(条目.t.get("cd")):
		条目.cd = 0.0
	else:
		条目.cd = maxf(0.0, 前 - 余)
	var 抵 := 前 - float(条目.cd)
	if 抵 > 0:
		Fac.势力记录(ctx, "ATX %s【赌徒的直觉】余量 %s 抵掉【%s】的冷却 %s 点（本场累计打空 %s 段，超过起算 %s 的余量）→ 现在冷却 %s%s" % [
			使用者.name, J.s(余), 条目.t.name, J.s(抵), J.s(ATX打空(使用者)), J.s(参.get("余量起算")), J.s(条目.cd),
			"（减到 0：每次行动都能用）" if float(条目.cd) == 0 else ""], {
			"势力": "ATX", "特色": "赌徒的直觉", "结果": "余量抵冷却", "单位": 使用者.key, "单位方": 使用者.side,
			"单位位": 使用者.slot, "武器": 条目.t.name, "余量": 余, "抵掉冷却": 抵, "现在冷却": 条目.cd,
		})
	return 抵

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
