## 职责：武器卡执行 —— 主武器卡与武器栏卡的打出，武器攻击 / 修理 / 支援 / 铁壁护卫的结算入口。
class_name BattleWeaponExec
extends RefCounted

## 打出一张【主武器卡】。`weapon_or_card_id` 可以是 u.weapons 的下标 / 武器名 / 专属手牌里的牌。
static func 打出主武器卡(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	if J.truthy(u.get("主武器已销毁")):
		return {"成功": false, "原因": "本回合主武器卡已销毁（下回合初回手）"}
	var 手牌 = Btl._找手牌卡(u, weapon_or_card_id)
	if 手牌 is Dictionary:
		if str(手牌.get("卡类", "")) == "衍生攻击卡":
			return {"成功": false, "原因": "这是衍生攻击卡（请用打出衍生攻击卡）"}
		return _打出手牌主武器(ctx, u, 手牌, target_id)
	if weapon_or_card_id != null:
		var 栏卡 = _找武器栏卡(u, weapon_or_card_id)
		if 栏卡 is Dictionary and J.truthy((栏卡 as Dictionary).get("v01卡")):
			return 打出武器栏卡(ctx, unit_id, weapon_or_card_id, target_id)
	if weapon_or_card_id == null:
		var 候选 := Calc.usableWeapons(u, ctx).filter(func(e): return e is Dictionary and e.get("t") is Dictionary and Calc.weaponPlayable(e.t))
		if not 候选.is_empty():
			weapon_or_card_id = 候选[0].t.get("name")
	var entry = Btl._找武器(u, weapon_or_card_id)
	if not (entry is Dictionary) or not (entry.get("t") is Dictionary):
		return {"成功": false, "原因": "没有这张主武器卡"}
	var w: Dictionary = entry.t
	if not Calc.weaponPlayable(w):
		return {"成功": false, "原因": "这张武器不能主动打出"}
	if entry.get("uses") != null and float(entry.uses) <= 0.0:
		return {"成功": false, "原因": "使用次数已用尽"}
	if J.num0(entry.get("cd")) > 0.0:
		return {"成功": false, "原因": "冷却中"}
	if float(u.get("lv", 1.0)) < J.num(Params.残月武器运行期解锁(w)):
		return {"成功": false, "原因": "等级不够"}
	if J.num0(entry.get("readyTurn")) > float(ctx.get("turn", 1.0)):
		return {"成功": false, "原因": "还没到解锁回合"}
	var 费 := Btl._战意费用(w)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	var 名 := str(w.get("name", ""))
	if 名 == "铁壁护卫" or J.truthy(w.get("单机牌组_铁壁")):
		结果 = _执行铁壁护卫(ctx, u, entry)
	elif Reach.isHealKind(Reach.rangeKindOf(w)):
		结果 = _执行修理卡(ctx, u, entry, target_id)
	elif Reach.isSupportKind(Reach.rangeKindOf(w)):
		结果 = _执行支援卡(ctx, u, entry, target_id)
	else:
		结果 = _执行武器攻击(ctx, u, entry, target_id)
	# 尖兵【机动脱离】：本回合打出主武器卡后自身闪避 +15%
	if Units.unit_class(u, ctx) == "尖兵":
		Btl.换同源增益(u, "机动脱离", {"eva": 15.0, "剩余": 1.0})
		u["机动脱离中"] = ctx.turn
	if not Btl._不销毁主武器(w):
		u["主武器已销毁"] = true
	if J.num0(结果.get("击破")) > 0.0 and Units.unit_class(u, ctx) == "近卫" and Btl.连续攻击可用(u, ctx):
		Btl.连续攻击记(u, ctx)
		DeckFlow.恢复主武器栏(ctx, u)
		Btl.pushLog(ctx, "〔近卫·连续攻击〕【%s】主武器卡全部回手！" % str(w.get("name", "")),
			J.merged({"类型": "连续攻击", "单位": u.key, "武器": w.get("name")}, Btl.谁(u)))
	Btl.pushLog(ctx, "〔主武器卡〕%s 打出【%s】（战意 -%s，剩 %s）" % [u.name, str(w.get("name", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "主武器卡", "单位": u.key, "武器": w.get("name"), "战意": u.get("战意"),
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "武器": str(w.get("name", "")), "战意": J.num0(u.get("战意")),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 别名（评审稿里的英文写法）
static func play_unit_weapon_card(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出主武器卡(ctx, unit_id, weapon_or_card_id, target_id)

## 这张武器栏卡现在打不打得出来（空串 = 能打）。**纯读**：门面置灰、拖拽提示都用它。
static func 武器栏不可打原因(ctx: Dictionary, u: Dictionary, 卡: Variant, target_id: Variant = null) -> String:
	if not (卡 is Dictionary):
		return "武器栏里没有这张牌"
	if J.truthy(卡.get("v01卡")):
		var 因 := AtxThree.不可打原因(ctx, u, 卡)
		if 因 != "":
			return 因
	var cb武因 := CelestialV01.武器栏不可打原因(ctx, u, 卡)
	if cb武因 != "":
		return cb武因
	if J.truthy(u.get("主武器已销毁")):
		return "本回合主武器已销毁（下个我方阶段初恢复）"
	if 卡.get("剩余次数") != null and float(卡.剩余次数) <= 0.0:
		return "每场次数已用完"
	if float(卡.get("当前冷却", 0.0)) > 0.0:
		return "冷却中"
	if str(卡.get("id", "")) == MithrilV03Cards.合体技ID:
		if not DeckFlow.条件满足(ctx, u, DeckFlow.入库条件Of(卡)):
			return "亮起条件未满足：连携牌库需出现过三级牌"
		for 键 in MithrilV03Cards.合体技成员:
			var 友 = Btl._找队友(ctx, str(键))
			if not (友 is Dictionary) or float((友 as Dictionary).get("hp", 0.0)) <= 0.0:
				return "亮起条件未满足：宗介 / 毛 / 克鲁兹 三人必须都在场存活"
	if Btl.战意(u) < Btl.战意费用(卡):
		return "战意不足（要 %d，现在 %d）" % [int(Btl.战意费用(卡)), int(Btl.战意(u))]
	var w = 卡.get("武器")
	if not (w is Dictionary):
		return ""
	if target_id == null:
		return ""
	var t = Btl.找单位(ctx, target_id, "enemy")
	if not (t is Dictionary):
		return ""   # 没指定 / 指定不到 → 走自动挑目标，不在这里拦
	var 判: Dictionary = Reach.武器可达吗(ctx, u, w, t)
	if not J.truthy(判.get("ok")):
		return "距离 / 站位不符：%s" % str(判.get("why", ""))
	return ""

## 挑一张现在打得出来的武器栏卡（AI 补打 / 界面「点一下自动选」用）。
static func _自动武器栏卡(ctx: Dictionary, u: Dictionary, target_id: Variant = null) -> Variant:
	for c in J.or_(u.get("武器栏"), []):
		if 武器栏不可打原因(ctx, u, c, target_id) == "":
			return c
	return null

## 在武器栏里找一张牌（字典按引用比，否则比 id / 牌名 / 实例号）。
static func _找武器栏卡(u: Dictionary, 标识: Variant) -> Variant:
	if 标识 == null:
		return null
	for c in J.or_(u.get("武器栏"), []):
		if not (c is Dictionary):
			continue
		if 标识 is Dictionary:
			if is_same(c, 标识):
				return c
			continue
		if str(c.get("id", "")) == str(标识) or str(c.get("名", "")) == str(标识):
			return c
		if c.get("_实例号") != null and str(c._实例号) == str(标识):
			return c
	return null

## 打出武器栏 / 副武器栏里的一张牌（v0.3 的主入口）。
static func 打出武器栏卡(ctx: Dictionary, unit_id: Variant, 标识: Variant = null, target_id: Variant = null) -> Dictionary:
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var 副 = DeckFlow.找副武器(u, 标识) if 标识 != null else {}
	if 副 is Dictionary and not 副.is_empty():
		return DeckFlow.打出副武器(ctx, u.get("key"), 标识, target_id)
	var 卡 = _找武器栏卡(u, 标识)
	if 卡 == null and 标识 == null:
		卡 = _自动武器栏卡(ctx, u, target_id)
	if not (卡 is Dictionary):
		return 打出主武器卡(ctx, unit_id, 标识, target_id)
	var 原因 := 武器栏不可打原因(ctx, u, 卡, target_id)
	if 原因 != "":
		return {"成功": false, "原因": 原因}
	var 费 := Btl.战意费用(卡)
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	var cb打 := CelestialV01.武器打出前(ctx, u, 卡)
	AtxSmoke.打出时(ctx, u, 卡, _存活敌(ctx, u, target_id))
	var 结果 := {"击破": 0.0}
	if J.truthy(卡.get("v01卡")):
		结果 = AtxThree.武器栏打出(ctx, u, 卡, target_id)
	elif 卡.get("武器") is Dictionary:
		var 倍 := 1.0
		if float(u.get("v3伤害加成", 0.0)) != 0.0:
			倍 += float(u.v3伤害加成)
		var w: Dictionary = (卡.武器 as Dictionary).duplicate(true)
		if 倍 != 1.0:
			w["power"] = float(w.get("power", 0.0)) * 倍
		if cb打.get("武器") is Dictionary:
			w = cb打["武器"]
		var 开火: Dictionary = J.or_(ctx.get("v3各员开火"), {})
		if float(开火.get("伤害", 0.0)) > 0.0 and FacMith.是秘银(u):
			w["power"] = float(w.get("power", 0.0)) * (1.0 + float(开火.伤害))
			w["hit"] = float(w.get("hit", 100.0)) + float(开火.命中)
			ctx["v3各员开火"] = {"伤害": 0.0, "命中": 0.0}
			Btl.pushLog(ctx, "〔Uruz 各员，开火〕%s 这一张主武器伤害 +%d%%、命中 +%d" % [
				u.name, int(float(开火.伤害) * 100.0), int(float(开火.命中))],
				J.merged({"类型": "各员开火", "单位": u.key}, Btl.谁(u)))
		结果 = _执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, target_id)
	elif 卡.get("效果") is Array:
		CardEffects.execute(ctx, 卡)
	# ★ 第 3 项断路器修复（DS41F）：**打出武器栏卡**也要挂一次【二次下注】结算
	#   `AtxFaction.攻击后二次下注` 消费即清 → 同一张武器牌恰好只结算 1 次）。
	AtxFaction.尝试二次下注(ctx, u, 卡)
	# 主武器互毁（带「不被销毁」标签的除外；★ CB-2 的「剑舞 / 迅击」本回合不收起其余主武器）
	if not Btl._不销毁主武器(卡) and not J.truthy(cb打.get("不销毁主武器")):
		u["主武器已销毁"] = true
	if 卡.get("剩余次数") != null:
		卡["剩余次数"] = maxf(0.0, float(卡.剩余次数) - 1.0)
	if J.num0(结果.get("击破")) > 0.0 and Units.unit_class(u, ctx) == "近卫" and Btl.连续攻击可用(u, ctx):
		Btl.连续攻击记(u, ctx)
		DeckFlow.恢复主武器栏(ctx, u)
	# ★ M1（试玩反馈修复）【连携】的判定**必须在 `记上张打出牌` 之前** ——
	#   `DeckFlow.连携就绪` 读的是「上一张打出的牌」，先记自己就等于拿自己跟自己比（恒 false）。
	if J.truthy(卡.get("连携")):
		DeckFlow.触发连携(ctx, 卡)
	DeckFlow.记上张打出牌(ctx, u, 卡)
	CelestialV01.武器打完后(ctx, u, 卡, 结果)
	RuleHooks.广播("牌打出后", [ctx, u, 卡, CardPlay.区_主武器])
	Btl.pushLog(ctx, "〔武器栏〕%s 打出【%s】（战意 -%s，剩 %s）" % [u.name, str(卡.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "武器栏", "单位": u.key, "卡牌ID": 卡.get("id"), "武器": 卡.get("名"),
			"战意": u.get("战意"), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "武器": str(卡.get("名", "")), "战意": Btl.战意(u),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")),
		"主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 打人的目标取法（★ 2026-10-20「打空气」事故的修法）：
static func _存活敌(ctx: Dictionary, u: Dictionary, target_id: Variant) -> Variant:
	var 敌 = Btl.找单位(ctx, target_id, "enemy")
	if 敌 is Dictionary and not Btl._是活体(敌):
		敌 = null
	if not (敌 is Dictionary):
		敌 = Btl._自动目标(ctx, u, true)
	return 敌 if 敌 is Dictionary else null

## 武器攻击的统一入口：逐层取改写后的武器实例，再交给 `Flow.resolveAction` 结算。
static func _执行武器攻击(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 敌 = _存活敌(ctx, u, target_id)
	if not (敌 is Dictionary):
		return {"击破": 0.0}
	# ★ A5b：武器「**段数改写**」层 —— 改的是**这一次**的武器实例（`应用` 返回 duplicate，牌面模板不动）；
	#   匹配这张牌 → 生效并**用完即清**；不匹配（满弦/连珠箭遇上非【弓】）→ 槽原样还在（不消耗）。
	var 改写 := AtxRewrite.应用(ctx, u, w)
	if J.truthy(改写.get("生效")):
		w = 改写["武器"]
	var 卡改 := ClassCards.改写武器(ctx, u, w)
	if J.truthy(卡改.get("生效")):
		w = 卡改["武器"]
	var 顺劈 := false
	var 区 := str(w.get("area", ""))
	if 区 == "cleave" or 区 == "顺劈":
		顺劈 = true
	elif ClassCards.是顺劈武器(ctx, u, w):
		顺劈 = true
	if CelestialV01.开(ctx):
		var cb命中 := CelestialV01.攻击前命中(ctx, u, w, 敌) + CelestialV01.主武器命中加成(ctx, u)
		if cb命中 != 0.0:
			w = w.duplicate(true)
			w["hit"] = float(w.get("hit", 100.0)) + cb命中
	var 命中加 := 0.0
	var kind0 = Reach.rangeKindOf(w)
	if J.truthy(u.get("专业军人")) and (kind0 == Reach.KIND_DIRECT() or kind0 == Reach.KIND_INDIRECT()):
		命中加 += 10.0
	var 秘命中 := float(J.or_(ctx.get("v3秘银命中"), 0.0))
	if 秘命中 != 0.0 and FacMith.是秘银(u):
		命中加 += 秘命中
		ctx["v3秘银命中"] = 0.0
	var 下限减 := int(J.or_(u.get("v3距离下限减"), 0))
	var 上限加 := int(J.or_(u.get("v3距离上限加"), 0))
	if 命中加 != 0.0 or 下限减 != 0 or 上限加 != 0:
		w = w.duplicate(true)
		w["hit"] = float(w.get("hit", 100.0)) + 命中加
		if 下限减 != 0 or 上限加 != 0:
			var 界 := Reach.武器距离(w)
			w["距离"] = [maxi(1, 界.x - 下限减), mini(6, 界.y + 上限加)]
		u.erase("v3距离下限减")
		u.erase("v3距离上限加")
	var action := {"kind": "attack", "weapon": w, "target": 敌, "entry": entry}
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		var 落点: Array = Reach.areaSlots(w, Fm.rowOfSlot(float(敌.slot)), Fm.colOfSlot(float(敌.slot)))
		var 命中 := Units.livingOf("enemy", ctx).filter(func(t): return J.inc(落点, t.slot))
		action["hit"] = 命中
	# ★ A6a：近卫【回旋斩】的「横扫」—— 目标所在一整排全打（与 `area = row` 同一个落点口径，
	#   但**不改** `fire`：近战还是近战，只是这一发打一排）。一次攻击仍是一条记录（R5：
	elif J.truthy(w.get("横扫")) and 敌.get("slot") != null:
		var 排 := Fm.rowOfSlot(float(敌.slot))
		var 扫位: Array = Reach.areaSlots({"area": "row"}, 排, Fm.colOfSlot(float(敌.slot)))
		action["横扫"] = true
		action["hit"] = Units.livingOf("enemy", ctx).filter(func(t): return J.inc(扫位, t.slot))
	# ★ CB-0：【顺劈】—— 主目标正常 100% 威力逐段结算，同排左右相邻的存活敌机各按 **50% 单段威力**
	#   独立掷命中与暴击、各自初始化并消耗自己的装甲共享池（落点由 `Flow.resolveAction` 展开）。
	elif 顺劈 and 敌.get("slot") != null:
		action["顺劈"] = true
		action["顺劈倍率"] = float(J.or_(w.get("cleave_mul"), 0.5))
	var 护盾前 := float(敌.get("shieldHp", 0.0))
	var r = Flow.resolveAction(u, action, ctx)
	# ★ MITH3-3：λ 力场被完全击破（> 0 → 0）累计 2 次 → λ 觉醒
	if 护盾前 > 0.0 and float(敌.get("shieldHp", 0.0)) <= 0.0:
		DeckFlow.记录力场被破(ctx, 敌, 护盾前)
	if r is Dictionary:
		var 记: Dictionary = r.get("字段") if (r.get("字段") is Dictionary) else {}
		if J.num0(记.get("暴击")) > 0.0:
			DeckFlow.计数加(u, "本场暴击", int(J.num0(记.get("暴击"))))
		if J.num0(记.get("伤害")) > 0.0:
			DeckFlow.计数加(u, "本场武器牌", 1)
	if r is Dictionary:
		r["目标"] = 敌.key
		# ★ 2026-10-21（任务单问题 3）：把这一发的攻击记录文本带回去（打出的那张牌自己的日志
		#   因此能写清「实际打出了什么」，不只是「打出【牌名】」）。
		var 刚文 := Btl._最后一条文(ctx, ["攻击"])
		if not 刚文.is_empty():
			r["文本"] = 刚文
		return r
	return {"击破": 0.0, "目标": 敌.key}

## 修理卡：找目标（找不到自动挑）→ `Flow.resolveAction` 修一发，顺手清负面。
static func _执行修理卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 目标 = Btl.找单位(ctx, target_id, "ally")
	if not (目标 is Dictionary):
		目标 = Btl._自动目标(ctx, u, false)
	if not (目标 is Dictionary):
		return {"击破": 0.0}
	var r = Flow.resolveAction(u, {"kind": "heal", "weapon": w, "target": 目标, "entry": entry}, ctx)
	# 【紧急修理】：回复大量 HP 并清除负面状态
	目标["debuffs"] = []
	目标["armorCut"] = 0.0
	return {"击破": 0.0, "回复": r.get("回复", 0.0) if r is Dictionary else 0.0, "目标": 目标.key}

## 支援类主武器卡（buff / grant）：走现成的 Flow.resolveAction 支援分支
static func _执行支援卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 目标 = Btl.找单位(ctx, target_id, "ally")
	if J.truthy(w.get("grant")):
		if not (目标 is Dictionary):
			目标 = Ai.grantTargetOf(u, ctx)
		if not (目标 is Dictionary):
			return {"击破": 0.0}
		return Flow.resolveAction(u, {"kind": "grant", "weapon": w, "target": 目标, "entry": entry}, ctx)
	var 们 := Units.livingOf("ally", ctx)
	if 目标 is Dictionary:
		们 = [目标]
	else:
		们 = 们.filter(func(x): return not is_same(x, u))
	if 们.is_empty():
		们 = [u]
	var r = Flow.resolveAction(u, {"kind": "buff", "weapon": w, "targets": 们, "entry": entry}, ctx)
	return r if r is Dictionary else {"击破": 0.0}

## 铁壁护卫：回复 5% HP、防御 +50、受伤 −30%，本回合替同列后排挡枪。
static func _执行铁壁护卫(ctx: Dictionary, u: Dictionary, entry: Dictionary) -> Dictionary:
	var 前 := float(u.hp)
	var 加 := J.round(float(u.maxHp) * 0.05)
	u["hp"] = minf(float(u.maxHp), float(u.hp) + 加)
	Btl.换同源增益(u, "铁壁护卫", {"def": 50.0, "受伤Mul": -0.30, "剩余": 1.0})
	u["铁壁护卫中"] = ctx.turn
	Calc.spendWeapon(u, entry)
	Btl.pushLog(ctx, "〔铁壁护卫〕%s 架起铁壁：防御 +50、受到伤害 -30%%、回复 %s（替同列后排挡枪）" % [u.name, J.s(J.round(float(u.hp) - 前))],
		J.merged({"类型": "铁壁护卫", "单位": u.key, "回复": J.round(float(u.hp) - 前)}, Btl.谁(u)))
	return {"击破": 0.0}

## 打出专属手牌里的主武器卡（合体技转 `_打出手牌合体技`）：扣战意、结算、销毁主武器。
static func _打出手牌主武器(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	if Btl.是合体技牌(card):
		return Btl._打出手牌合体技(ctx, u, card, target_id)
	var 费 := Btl._ATX实际战意(ctx, card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	AtxSmoke.打出时(ctx, u, card, _存活敌(ctx, u, target_id))
	if card.get("武器") is Dictionary:
		结果 = _执行武器攻击(ctx, u, {"t": card.武器, "cd": 0.0, "uses": null}, target_id)
	else:
		CardEffects.execute(ctx, card)
	AtxFaction.攻击后二次下注(ctx, u, card)
	AtxFaction.记打出大招(ctx, card)
	if Units.unit_class(u, ctx) == "尖兵":
		Btl.换同源增益(u, "机动脱离", {"eva": 15.0, "剩余": 1.0})
		u["机动脱离中"] = ctx.turn
	u["主武器已销毁"] = true
	if J.num0(结果.get("击破")) > 0.0 and Units.unit_class(u, ctx) == "近卫" and Btl.连续攻击可用(u, ctx):
		Btl.连续攻击记(u, ctx)
		DeckFlow.恢复主武器栏(ctx, u)
		Btl.pushLog(ctx, "〔近卫·连续攻击〕【%s】主武器卡全部回手！" % str(card.get("名", "")),
			J.merged({"类型": "连续攻击", "单位": u.key, "武器": card.get("名")}, Btl.谁(u)))
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	u["专属弃牌堆"].append(card)
	Btl.pushLog(ctx, "〔主武器卡〕%s 打出【%s】（战意 -%s，剩 %s）" % [u.name, str(card.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "主武器卡", "单位": u.key, "武器": card.get("名"), "卡牌ID": card.get("id"),
			"战意": u.get("战意"), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "武器": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}
