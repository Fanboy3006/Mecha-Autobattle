## 职责：护卫与敌方词条的回合效果 —— 嘲讽 / 靶机援护 / 援护连线 / 镜甲反弹 / 自爆 / 冷却延长 / 隐身刷新 / 全场烟幕。
class_name BattleGuard
extends RefCounted

## 这一击会不会被「改目标」（靶机援护 / 塔斯克【掩护】 / 横向掩护 / 铁壁护卫）。返回接管者，null = 不改。
static func 嘲讽(ctx: Dictionary, 攻击者: Dictionary, 原目标: Dictionary, 预览: bool = false) -> Variant:
	var 守方 := Units.otherSide(攻击者.side)
	if 原目标.side != 守方:
		return null
	var 靶护 = _靶机援护(ctx, 原目标, 预览)
	if 靶护 != null:
		return 靶护
	if AtxDuo.接管嘲讽(ctx, 攻击者, 原目标):
		return null
	var 横 = ClassCards.横向掩护接管(ctx, 原目标)
	if 横 != null:
		return 横
	var 卫 = Params.同路铁壁护卫(ctx, 攻击者, 原目标)
	if 卫 != null and _可挡枪(卫):
		return 卫
	var 铁壁候选 := Units.livingOf(守方, ctx).filter(func(u):
		return _可挡枪(u) and Reach.职业是(u, "重装") and not is_same(u, 原目标) and u.hp > 0 and J.same(u.get("铁壁护卫中"), ctx.turn))
	if not 铁壁候选.is_empty():
		var 同列 := 铁壁候选.filter(func(u): return 原目标.get("slot") != null and Fm.colOfSlot(u.slot) == Fm.colOfSlot(原目标.slot))
		var 用: Array = 同列 if not 同列.is_empty() else 铁壁候选
		J.sort(用, func(a, b): return float(a.slot) - float(b.slot))
		return 用[0]
	return null

## 掩护者（A6 / CB5）与额度（2 + 【装甲焊补】的 `掩护补充`）。
static func 是掩护者(u: Variant) -> bool:
	return u is Dictionary and (str((u as Dictionary).get("key", "")) == "A6" or CelestialV01.是掩护者(u))

static func 掩护额度(u: Variant) -> int:
	if not (u is Dictionary):
		return 0
	return 2 + maxi(0, int(J.num0((u as Dictionary).get("掩护补充", 0))))

## 这台单位现在能不能**替别人挡枪**（纯读）。
static func _可挡枪(u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	return not J.truthy((u as Dictionary).get("禁用护卫"))

## **靶机援护** —— `靶机援护上限 > 0` 的单位替「同列后排」挡枪。
static func _靶机援护(ctx: Variant, 原目标: Variant, 预览: bool = false) -> Variant:
	if not (原目标 is Dictionary) or (原目标 as Dictionary).get("slot") == null:
		return null
	if not (ctx is Dictionary):
		return null
	var 目标: Dictionary = 原目标
	var 守方 := str(目标.get("side", ""))
	if Fm.rowOfSlot(float(目标.slot)) != Fm.ROW_BACK:
		return null
	var 列 := int(Fm.colOfSlot(float(目标.slot)))
	var 候选: Array = []
	for u in Units.livingOf(守方, ctx):
		if not (u is Dictionary) or is_same(u, 目标):
			continue
		if J.num0((u as Dictionary).get("靶机援护上限")) <= 0.0:
			continue
		if (u as Dictionary).get("slot") == null:
			continue
		if Fm.rowOfSlot(float((u as Dictionary).slot)) != Fm.ROW_FRONT:
			continue
		if int(Fm.colOfSlot(float((u as Dictionary).slot))) != 列:
			continue
		if int(J.num0((u as Dictionary).get("靶机援护剩余"))) <= 0:
			continue
		候选.append(u)
	if 候选.is_empty():
		return null
	J.sort(候选, func(a, b): return float(a.slot) - float(b.slot))
	var 护: Dictionary = 候选[0]
	# 预览只读：`Btl.算意图` 那条路不许扣次数、不写日志。
	if not 预览:
		护["靶机援护剩余"] = maxi(0, int(J.num0(护.get("靶机援护剩余"))) - 1)
	return 护

## 每个我方阶段开始：把**存活靶机**的 `靶机援护剩余` 重置回 `靶机援护上限`（默认 2 次）。
static func 重置靶机援护(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for 方 in ["enemy", "ally"]:
		for u in Units.livingOf(方, ctx):
			if not (u is Dictionary):
				continue
			var 上 := int(J.num0((u as Dictionary).get("靶机援护上限")))
			if 上 <= 0:
				continue
			(u as Dictionary)["靶机援护剩余"] = 上

## # ★ 2026-10-21（任务单问题 4）：**当前援护连线们** —— 纯读，一次随机数都不掷、一个状态都不改。
static func 当前援护连线们(ctx: Variant) -> Array:
	var 出: Array = []
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get("allies") is Array):
		return 出
	# ---------------- ① 敌方的「靶机援护」----------------
	for u in Units.livingOf("enemy", ctx):
		if not (u is Dictionary):
			continue
		var 上 := int(J.num0((u as Dictionary).get("靶机援护上限")))
		var 剩 := int(J.num0((u as Dictionary).get("靶机援护剩余")))
		if 上 <= 0 or 剩 <= 0:
			continue
		if (u as Dictionary).get("slot") == null:
			continue
		if Fm.rowOfSlot(float((u as Dictionary).slot)) != Fm.ROW_FRONT:
			continue
		var 列 := int(Fm.colOfSlot(float((u as Dictionary).slot)))
		var 友 = _同列后排友军(ctx, "enemy", (u as Dictionary), 列)
		if 友 == null:
			continue
		出.append(_连线条(u, 友, "enemy", 剩, 上, "援护 %d/%d" % [剩, 上]))
	# ---------------- ② 我方的四条援护 ----------------
	var t: Variant = (ctx as Dictionary).get("turn", 0.0)
	for u in Units.livingOf("ally", ctx):
		if not (u is Dictionary):
			continue
		var 键 := str((u as Dictionary).get("key", ""))
		if (u as Dictionary).get("slot") == null:
			continue
		var 排 := Fm.rowOfSlot(float((u as Dictionary).slot))
		var 列2 := int(Fm.colOfSlot(float((u as Dictionary).slot)))
		# ②-a 【掩护】：前排 → 同列后排（额度见 `掩护额度`）
		if 是掩护者(u) and 排 == Fm.ROW_FRONT:
			var 友2 = _同列后排友军(ctx, "ally", (u as Dictionary), 列2)
			var 剩2 := int(J.num0((u as Dictionary).get("掩护剩余")))
			if 友2 != null and 剩2 > 0:
				出.append(_连线条(u, 友2, "ally", 剩2, 掩护额度(u), "掩护 %d/%d" % [剩2, 掩护额度(u)]))
		# ②-b 重装【横向掩护】：本回合 → 同排左右相邻的存活队友
		if J.same((u as Dictionary).get("横向掩护Turn"), t):
			for 邻列 in [列2 - 1, 列2 + 1]:
				if 邻列 < 0 or 邻列 >= int(Fm.行列数(排)):
					continue
				var 邻 = _同排友军(ctx, "ally", (u as Dictionary), 排, 邻列)
				if 邻 == null:
					continue
				出.append(_连线条(u, 邻, "ally", -1, -1, "横向掩护"))
		# ②-c 宗介 U7【掩护后方】：同列后排（受伤分摊 30%）
		if 键 == "U7" and J.num0((u as Dictionary).get("v3掩护后方")) > 0.0:
			var 友3 = _同列后排友军(ctx, "ally", (u as Dictionary), 列2)
			if 友3 != null:
				出.append(_连线条(u, 友3, "ally", -1, -1, "掩护30%"))
		# ②-d 重装【铁壁护卫】：本回合 → 同列后排
		if J.same((u as Dictionary).get("铁壁护卫中"), t):
			var 友4 = _同列后排友军(ctx, "ally", (u as Dictionary), 列2)
			if 友4 != null:
				出.append(_连线条(u, 友4, "ally", -1, -1, "铁壁护卫"))
	return 出

## 一条援护连线字典（`remaining` / `max_count` 传 −1 = 本回合无限次 / 持续保护）。
static func _连线条(护者: Variant, 被护者: Variant, 方: String, 剩: int, 上: int, 标签: String) -> Dictionary:
	return {
		"from_key": str((护者 as Dictionary).get("key", "")),
		"to_key": str((被护者 as Dictionary).get("key", "")),
		"from_name": str((护者 as Dictionary).get("name", "")),
		"to_name": str((被护者 as Dictionary).get("name", "")),
		"from_slot": int(float((护者 as Dictionary).get("slot", -1.0))),
		"to_slot": int(float((被护者 as Dictionary).get("slot", -1.0))),
		"side": 方, "remaining": 剩, "max_count": 上, "label": 标签,
	}

## 同列**后排**的存活友军（纯读）。
static func _同列后排友军(ctx: Variant, 方: String, 排除: Variant, 列: int) -> Variant:
	for t in Units.livingOf(方, ctx):
		if not (t is Dictionary) or is_same(t, 排除):
			continue
		if (t as Dictionary).get("slot") == null:
			continue
		if Fm.rowOfSlot(float((t as Dictionary).slot)) != Fm.ROW_BACK:
			continue
		if int(Fm.colOfSlot(float((t as Dictionary).slot))) != 列:
			continue
		return t
	return null

## 同排 / 同列的存活友军（纯读）。
static func _同排友军(ctx: Variant, 方: String, 排除: Variant, 排: float, 列: int) -> Variant:
	for t in Units.livingOf(方, ctx):
		if not (t is Dictionary) or is_same(t, 排除):
			continue
		if (t as Dictionary).get("slot") == null:
			continue
		if Fm.rowOfSlot(float((t as Dictionary).slot)) != 排:
			continue
		if int(Fm.colOfSlot(float((t as Dictionary).slot))) != 列:
			continue
		return t
	return null

## 镜甲反弹：自带词条反弹优先，比例 > 0 才弹；扣攻击者的血并记账（可顺手击破）。
static func 镜甲反弹(ctx: Dictionary, 攻击者: Variant, 防御者: Variant, 一击: Variant, 武器: Variant) -> float:
	var 自带: bool = 防御者 != null and J.truthy(防御者.get("词条反弹"))
	var 比 := J.num0(防御者.get("反弹比例")) if 自带 else Params.镜甲反弹比例()
	if not (比 > 0) or not (Params.有敌人机制(防御者, "beamReflect") or 自带):
		return 0.0
	if 自带 and J.truthy(防御者.get("反弹仅近战")) and Reach.rangeKindOf(武器) != Reach.KIND_MELEE():
		return 0.0
	var 受伤 := J.num0(一击.get("伤害")) if 一击 != null else 0.0
	if not (受伤 > 0) or 攻击者 == null or is_same(攻击者, 防御者):
		return 0.0
	if float(攻击者.hp) <= 0:
		return 0.0
	var 反弹 := maxf(0.0, J.round(受伤 * 比))
	var 还没死: bool = float(攻击者.hp) > 0
	攻击者.hp = maxf(0.0, float(攻击者.hp) - 反弹)
	Btl.pushLog(ctx, "〔镜甲〕%s 的镜甲把 %s 反弹给 %s（这一下受到 %s × %s%%）" % [防御者.name, J.s(反弹), 攻击者.name, J.s(受伤), J.s(J.round(比 * 100.0))],
		J.merged({"类型": "镜甲", "单位": 防御者.key, "目标": 攻击者.key, "反弹": 反弹, "伤害": 反弹, "原伤害": 受伤,
			"反弹比例": 比, "目标剩余HP": 攻击者.hp}, Btl.谁(防御者), Btl.谁目标(攻击者)))
	if 还没死 and float(攻击者.hp) <= 0:
		Fac.势力击破(ctx, 防御者, 攻击者)
	return 反弹

## 这台单位主武器的最高威力（修理 / 支援武器不算）。
static func 主武器威力(u: Variant) -> float:
	var 最高 := 0.0
	for e in J.or_(u.get("weapons") if u != null else null, []):
		var w = e.get("t") if e != null else null
		if w == null:
			continue
		var k = Reach.rangeKindOf(w)
		if not J.truthy(k) or Reach.isHealKind(k) or Reach.isSupportKind(k):
			continue
		var p := J.num0(Calc.wv(u, w, "power"))
		if p > 最高:
			最高 = p
	return 最高

## 自爆：词条 / 强制两种入口；落点上每台走一遍统一攻击管线（旁路攻击、不许被改目标）。
static func 自爆(ctx: Dictionary, _击破者: Variant, 死者: Variant, 缘由: Variant = null, 强制: bool = false) -> Variant:
	var 词条自爆: bool = 死者 != null and J.truthy(死者.get("词条自爆"))
	if 死者 != null and J.truthy(死者.get("自爆过")):
		return null
	if not 强制 and not (Params.有敌人机制(死者, "selfDestruct") or 词条自爆):
		return null
	死者.自爆过 = true
	var c := Params.自爆参数()
	var 倍 := (J.num(死者.get("词条自爆倍率")) if J.truthy(死者.get("词条自爆倍率")) else 1.0) if 词条自爆 else 1.0
	var 威力 := J.round(主武器威力(死者) * float(c.威力倍率) * 倍)
	var 落点 := Reach.areaSlots({"fire": "map", "area": c.范围}, Fm.rowOfSlot(死者.slot), Fm.colOfSlot(死者.slot))
	var 武器 := {
		"name": c.武器名, "fire": "map", "area": c.范围, "power": 威力, "hit": 100.0, "critMod": 0.0,
		"stat": "射击", "dmgType": "物理", "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null,
	}
	var 目标方们 := [Units.otherSide(死者.side), 死者.side] if J.truthy(死者.get("自爆两侧")) else [Units.otherSide(死者.side)]
	var 靶子 := []
	for s in 目标方们:
		for t in Units.livingOf(s, ctx):
			if not is_same(t, 死者) and J.inc(落点, t.slot):
				靶子.append(t)
	var 记录们 := []
	var 合计 := 0.0
	var 少挨 := 0.0
	for t in 靶子:
		# `旁路攻击` —— 自爆是击破的副产品：照常拿伤害 / 标记被攻击 / 击破记账 / 战况计数，
		# 并**照常消费**目标身上的 `GN 全盾·哈罗` 首击减伤（自爆也是一次攻击）；
		var 结算: Dictionary = Flow.结算一个目标(ctx, 死者, t, 武器,
			{"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})
		var rec: Dictionary = 结算.rec
		合计 += J.num0(rec.字段.get("伤害"))
		少挨 += J.num0(rec.字段.get("防御少挨"))
		记录们.append([t, rec])
	var 缘由文字 = J.or_(缘由, "被击破的瞬间自爆")
	Btl.pushLog(ctx, "〔自爆〕%s %s：落点 %s（打掉你 %s%s）" % [死者.name, 缘由文字, "、".join(落点.map(func(s): return Fm.位名(s))), J.s(合计), "，防御少挨 %s" % J.s(少挨) if 少挨 > 0 else ""],
		J.merged(J.merged({
			"类型": "自爆", "单位": 死者.key, "武器": 武器.name, "威力": 威力, "落点们": 落点, "自爆": true,
			"自爆伤害": 合计, "自爆少挨": 少挨, "命中数": float(靶子.size()),
			"目标位们": 落点, "目标方们": 落点.map(func(_s): return Units.otherSide(死者.side)),
		}, {"自爆缘由": 缘由} if J.truthy(缘由) else null), Btl.谁(死者)))
	for pair in 记录们:
		var t = pair[0]
		var rec = pair[1]
		Btl.pushLog(ctx, "〔%s〕%s" % [武器.name, rec.文本],
			J.merged(J.merged({"类型": "攻击", "单位": 死者.key, "目标": t.key, "武器": 武器.name, "自爆": true, "自爆落点": 落点}, Btl.谁(死者), Btl.谁目标(t)), rec.字段))
	return {"落点": 落点, "威力": 威力, "合计": 合计, "少挨": 少挨, "台数": float(靶子.size())}

## 钩子薄转发：`我方阶段初_自爆`
static func 我方阶段初_自爆(ctx: Dictionary, 在场的: Array) -> void:
	词条到点自爆(ctx, 在场的)

## 词条「到点自爆」：到回合就炸并当场退场（返回台数）。
static func 词条到点自爆(ctx: Dictionary, 在场的: Array) -> float:
	if not Params.词条开():
		return 0.0
	var 次 := 0.0
	for u in Units.livingOf("enemy", ctx):
		if not (J.num(u.get("自爆回合")) > 0) or J.truthy(u.get("自爆过")):
			continue
		if float(ctx.turn) < J.num(u.自爆回合):
			continue
		if not J.inc(在场的, u):
			continue
		自爆(ctx, null, u, "到点自爆", true)
		u.hp = 0.0
		次 += 1.0
	if 次 != 0:
		ctx.result = J.or_(ctx.result, Setup.checkResult(ctx))
	return 次

## 钩子薄转发：`我方阶段初_词条`（冷却延长 → 隐身刷新）
static func 我方阶段初_词条(ctx: Dictionary) -> void:
	词条冷却延长(ctx)
	词条隐身刷新(ctx)

## 词条「电磁干扰」：我方带冷却的武器延长 1-2 回合（每件只延一次）。
static func 词条冷却延长(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 数 := 0.0
	for e in Units.livingOf("enemy", ctx):
		var v := J.num(e.get("冷却延长"))
		if is_finite(v) and v > 0:
			数 = maxf(数, minf(2.0, J.round(v)))
	if 数 == 0:
		return 0.0
	var 受影响 := []
	for u in Units.livingOf("ally", ctx):
		for e in J.or_(u.get("weapons"), []):
			if e == null or not J.truthy(e.get("t")):
				continue
			var 大招 := Ai.isUltimate(e.t)
			if not (J.num0(e.t.get("cd")) > 0 or 大招):
				continue
			var 冷却中 := J.num0(e.get("cd")) > 0
			var 本回合能用 := not 冷却中 and float(ctx.turn) >= (J.num0(e.get("readyTurn")) if J.truthy(e.get("readyTurn")) else 1.0)
			if not 冷却中 and not 本回合能用:
				continue
			if J.truthy(e.get("词条已延")):
				continue
			e.cd = J.num0(e.get("cd")) + 数
			e.词条已延 = true
			受影响.append("%s【%s】" % [u.name, e.t.name])
	if not 受影响.is_empty():
		Btl.pushLog(ctx, "〔电磁干扰〕第 %s 回合：我方 %d 把带冷却的武器被延长 %s 回合（%s%s）" % [J.s(ctx.turn), 受影响.size(), J.s(数), "、".join(受影响.slice(0, 4)), "…" if 受影响.size() > 4 else ""],
			{"类型": "冷却延长", "延长数": 数, "台数": float(受影响.size()), "武器们": 受影响})
	return float(受影响.size())

## 词条「隐身刷新」：每回合重新进入隐身（返回台数）。
static func 词条隐身刷新(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 次 := 0.0
	for u in Units.livingOf("enemy", ctx):
		if not J.truthy(u.get("隐身刷新")):
			continue
		u.隐身中 = true
		次 += 1.0
	return 次

## 词条「全场烟幕」：摘掉旧烟幕再给所有单位挂命中减益（返回台数）。
static func 应用全场词条(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 生效 = null
	for e in J.or_(ctx.get("enemies"), []):
		if J.truthy(e.get("词条全场")):
			生效 = e.词条全场
			break
	if 生效 == null:
		return 0.0
	var 持续 := J.num(J.or_(Params.词条参数(), {}).get("全员命中持续"))
	var 剩余 := 持续 if (is_finite(持续) and 持续 > 0) else 9999.0
	var 台 := 0.0
	for u in Units.livingUnits(ctx):
		u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != "烟幕")
		var 条 := {"src": "烟幕", "剩余": 剩余}
		if J.truthy(生效.get("命中")):
			条.hit = 生效.命中
		u.buffs.append(条)
		台 += 1.0
	return 台

## 换一条同源 buff：同 `src` 的旧条先摘掉，再挂新的 1 回合。
static func 换同源增益(u: Dictionary, src: Variant, buff: Dictionary) -> void:
	u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != src)
	u.buffs.append(J.merged({"src": src, "剩余": 1.0}, buff))
