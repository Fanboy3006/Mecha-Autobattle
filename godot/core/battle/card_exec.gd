## 职责：出牌执行 —— 精神牌 / 公有牌、衍生攻击卡、合体技的效果执行与回收。门槛在 `CardPlay`。
class_name BattleCardExec
extends RefCounted

## 这张牌算不算【合体技】（合体技标记 / `种类 == 合体技` / `占行动` ≥ 2 三种认法）
static func 是合体技牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if J.truthy(card.get("合体技")) or str(card.get("种类", "")) == "合体技":
		return true
	var 占 = card.get("占行动")
	return 占 is Array and (占 as Array).size() >= 2

## 合体技的**全部参与者键**（`占行动` 优先，其次 `角色们`，最后 `角色`）
static func 合体技参与者(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	for k in J.or_(card.get("角色们"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	var 单 := str(card.get("角色", ""))
	if 单 != "" and not J.inc(出, 单):
		出.append(单)
	return 出

## ★ DECK-4：ATX「幸运连号」的降费 —— 只对 **ATX 角色牌**（`归属 == ATX` 且 `层级 == 角色`）生效，吃一次就清。
static func _ATX实际战意(ctx: Dictionary, card: Dictionary) -> float:
	var 费 := Btl._战意费用(card)
	if str(card.get("归属", "")) != "ATX" or str(card.get("层级", "")) != "角色":
		return 费
	if str(card.get("类型", "")) == "大招":
		return AtxFaction.大招实际费用(ctx, card)
	var 降 := int(ctx.get("下张ATX角色牌降费", 0))
	if 降 <= 0:
		return 费
	ctx["下张ATX角色牌降费"] = 0
	Btl.pushLog(ctx, "〔幸运连号〕【%s】费用 −%d（%s → %s）" % [str(card.get("名", "")), 降, J.s(费),
		J.s(maxf(0.0, 费 - float(降)))],
		{"类型": "降费", "势力": "ATX", "卡牌ID": card.get("id"), "降费": 降, "回合": ctx.turn})
	return maxf(0.0, 费 - float(降))

## ★ DECK-4：合体技（`占行动` ≥ 2 人 / `合体技 == true`）。
static func _打出手牌合体技(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	if str(card.get("id", "")) == FacAtx.合体技ID:
		var 手: Array = J.or_(u.get("专属手牌"), []).duplicate()
		var 合果 := AtxFaction.打出轮盘双响(ctx, u, card, target_id)
		if not J.truthy(合果.get("成功")):
			return 合果
		u["专属手牌"] = 手.filter(func(c): return not is_same(c, card))
		return 合果
	var 参与者: Array = []
	for k in 合体技参与者(card):
		var v = Btl._找队友(ctx, str(k))
		if v == null:
			return {"成功": false, "原因": "合体技参与者 %s 不在场（要全部存活才打得出来）" % str(k)}
		参与者.append(v)
	if 参与者.is_empty():
		参与者 = [u]
	for v in 参与者:
		if J.truthy(v.get("主武器已销毁")):
			return {"成功": false, "原因": "合体技参与者 %s 本回合主武器卡已销毁（要都没动过才打得出）" % str(v.get("name", ""))}
	var 进入原因 := AtxFaction.合体技不可打原因(ctx, card)
	if 进入原因 != "":
		return {"成功": false, "原因": 进入原因}
	var 费 := _ATX实际战意(ctx, card)
	var 各付 := AtxFaction.各付费用(card)
	if 各付 > 0.0:
		for v in 参与者:
			if J.num0(v.get("战意")) < 各付:
				return {"成功": false, "原因": "%s 的战意不足（要各付 %s，现在 %s）" % [
					str(v.get("name", "")), J.s(各付), J.s(J.num0(v.get("战意")))]}
		for v in 参与者:
			v["战意"] = maxf(0.0, J.num0(v.get("战意")) - 各付)
		费 = 各付
	elif J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	if 各付 <= 0.0:
		u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = card
	CardEffects.execute(ctx, card)
	for v in 参与者:
		v["主武器已销毁"] = true
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	var 留大招 := str(card.get("id", "")) == FacAtx.合体技ID
	if 留大招:
		for v in 参与者:
			AtxFaction.放入大招槽(v, card)
	else:
		u["专属弃牌堆"].append(card)
	var 名们: Array = 参与者.map(func(v): return str(v.get("name", "")))
	var 战意们: Array = 参与者.map(func(v): return "%s 剩 %s" % [str(v.get("name", "")), J.s(v.get("战意"))])
	Btl.pushLog(ctx, "〔合体技〕%s 打出【%s】（%s；参与者 %s 的主武器卡本回合全部销毁%s）" % [
		u.name, str(card.get("名", "")),
		("各付 %s 战意（%s）" % [J.s(各付), "、".join(战意们)]) if 各付 > 0.0 \
			else ("战意 -%s，剩 %s" % [J.s(费), J.s(u.get("战意"))]),
		"、".join(名们), "；留在两人的大招槽里进冷却 %s" % J.s(card.get("冷却")) if 留大招 else ""],
		J.merged({"类型": "合体技", "单位": u.key, "卡牌ID": card.get("id"), "卡牌": card.get("名"),
			"战意": u.get("战意"), "各付": 各付, "参与者": 合体技参与者(card), "留大招槽": 留大招}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"合体技": true, "参与者": 合体技参与者(card), "目标": Btl.目标名Of(结果),
		"击破": J.num0(结果.get("击破")), "主武器已销毁": true}

## 打出一张衍生攻击卡（专属手牌或公有手牌）：扣战意、执行效果、直接销毁，绝不动主武器。
static func 打出衍生攻击卡(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var card = Btl._找衍生卡(u, card_inst_id)
	var 从公有 := false
	if not (card is Dictionary):
		var 公牌 = Btl._找公有手牌卡(ctx, card_inst_id) if card_inst_id != null else null
		if 公牌 is Dictionary and Btl._是衍生卡(公牌):
			card = 公牌
			从公有 = true
	if not (card is Dictionary) and card_inst_id == null:
		if not u.衍生手牌.is_empty():
			card = u.衍生手牌[0]
		elif ctx.get("公有手牌") is Array and not ctx.公有手牌.is_empty():
			for c in ctx.公有手牌:
				if Btl._是衍生卡(c):
					card = c
					从公有 = true
					break
	if not (card is Dictionary):
		return {"成功": false, "原因": "手里没有这张衍生攻击卡"}
	var 费 := Btl._战意费用(card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := _执行衍生效果(ctx, u, card, target_id)
	if 从公有:
		ctx["公有手牌"] = ctx.公有手牌.filter(func(c): return not is_same(c, card))
		ctx["公有弃牌堆"].append(card)
	else:
		u["衍生手牌"] = u.衍生手牌.filter(func(c): return not is_same(c, card))
	Btl.pushLog(ctx, "〔衍生攻击卡〕%s 打出【%s】（战意 -%s，剩 %s；不影响主武器卡）" % [u.name, str(card.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "衍生攻击卡", "单位": u.key, "卡牌ID": card.get("id"), "卡牌": card.get("名"),
			"战意": u.get("战意")}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 英文别名转发（旧名字，表现层 / 测试在用）。
static func play_derived_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出衍生攻击卡(ctx, unit_id, card_inst_id, target_id)

## 给衍生攻击卡现造一份武器字典（固定 1 段、射程 1-8）。
static func _衍生假武器(名: String, 威力: float) -> Dictionary:
	return {"name": 名, "fire": "direct", "dmgType": "物理", "stat": "射击", "hit": 100.0, "critMod": 0.0,
		"hits": 1.0, "power": 威力, "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"ignoreDef": false, "special": null, "range": [1.0, 8.0]}

## 衍生攻击卡的效果本体：数据驱动牌走 CardEffects，否则按 `种类` 打一发 / 修理。
static func _执行衍生效果(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	if card.get("效果") is Array and not (card.get("效果") as Array).is_empty():
		CardEffects.execute(ctx, card)
		return {"击破": 0.0}
	var 种 := str(card.get("种类", card.get("名", "")))
	if 种 == "应急补丁":
		var 目标 = Btl.找单位(ctx, target_id, "ally")
		if 目标 is Dictionary and not Btl._是活体(目标):
			目标 = null
		if not (目标 is Dictionary):
			目标 = Btl._自动目标(ctx, u, false)
		if not (目标 is Dictionary):
			return {"击破": 0.0}
		var 量 := maxf(300.0, J.round(float(目标.maxHp) * 0.15))
		var 前 := float(目标.hp)
		目标["hp"] = minf(float(目标.maxHp), float(目标.hp) + 量)
		Btl.pushLog(ctx, "〔应急补丁〕%s → %s：回复 %s" % [u.name, 目标.name, J.s(J.round(float(目标.hp) - 前))],
			J.merged({"类型": "修理", "单位": u.key, "目标": 目标.key, "回复": J.round(float(目标.hp) - 前)}, Btl.谁(u)))
		return {"击破": 0.0, "目标": 目标.key}
	var w := _衍生假武器(种, maxf(300.0, J.num0(card.get("威力"))))
	if 种 == "战术副武":
		w["power"] = maxf(300.0, J.round(Btl.主武器威力(u) * 0.35))
	var 敌 = Btl._存活敌(ctx, u, target_id)
	if not (敌 is Dictionary):
		return {"击破": 0.0}
	var r = Flow.resolveAction(u, {"kind": "attack", "weapon": w, "target": 敌, "entry": {"t": w, "cd": 0.0, "uses": null}}, ctx)
	if 种 == "战术副武" and float(敌.hp) > 0.0:
		敌["buffs"] = J.or_(敌.get("buffs"), []).filter(func(b): return b.get("src") != "战术副武")
		敌.buffs.append({"src": "战术副武", "hit": -15.0, "剩余": 2.0})
	return {"击破": r.get("击破", 0.0) if r is Dictionary else 0.0, "目标": 敌.key}

## 打出专属精神牌或下排公有牌。指挥机打公有牌享受 `费用 - 5`（最低 0）。
static func 打出精神或公有牌(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var card = Btl._找手牌卡(u, card_inst_id)
	var 从公有 := false
	if not (card is Dictionary):
		card = Btl._找公有手牌卡(ctx, card_inst_id)
		从公有 = card is Dictionary
	if not (card is Dictionary) and card_inst_id == null:
		if not u.专属手牌.is_empty():
			card = u.专属手牌[0]
		elif ctx.get("公有手牌") is Array and not ctx.公有手牌.is_empty():
			card = ctx.公有手牌[0]
			从公有 = true
	if not (card is Dictionary):
		return {"成功": false, "原因": "手里没有这张牌"}
	# ★ CR-2 Batch B（P2-2）：**出牌门槛的唯一真源** —— 门面「这张牌亮不亮」显示调的是同一个函数。
	#   本函数只负责**分流与执行**；下面各分支里的门槛调用是「执行口子自己的防御」，不再是第二套判定。
	var 门因 := CardPlay.不可打原因(ctx, u, card, CardPlay.区_公有 if 从公有 else CardPlay.区_精神)
	if 门因 != "":
		return {"成功": false, "原因": 门因}
	# 势力模块自己的公有牌（感应牌 / 势力牌）走统一钩子；`{终局:false}` = 不归它管，继续走通用逻辑。
	var 公 = RuleHooks.首个结论("公有牌打出", [ctx, u, card, target_id])
	if bool((公 as Dictionary).get("终局", false)):
		var 公果 = (公 as Dictionary).get("结果")
		return 公果 if 公果 is Dictionary else {"成功": false, "原因": "这张牌打不出来"}
	if AtxGodsbet.是入局卡(card):
		return AtxGodsbet.打出入局(ctx, u)
	if AtxThree.走自家口子(card):
		return AtxThree.打出牌(ctx, u, card, target_id)
	if str(card.get("种类", "")) == "连携":
		return DeckFlow.打出连携牌(ctx, unit_id, card.get("id"), target_id)
	if AtxChips.是筹码牌(card):
		var 筹码目标 = target_id
		if 筹码目标 == null or (筹码目标 is String and str(筹码目标).strip_edges().is_empty()):
			筹码目标 = _筹码默认目标(ctx, u, card)
		var 筹码果 := AtxChips.打出筹码牌(ctx, u.get("key"), card.get("id"), 筹码目标)
		if not J.truthy(筹码果.get("成功")):
			return {"成功": false, "原因": str(筹码果.get("原因", "这张筹码牌打不出来"))}
		return {"成功": true, "卡牌": str(筹码果.get("卡牌", card.get("名", ""))), "筹码牌": true,
			"筹码等级": int(筹码果.get("筹码等级", 0)), "去处": str(筹码果.get("去处", "")),
			"目标": Btl.目标名Of(筹码果), "击破": J.num0(筹码果.get("击破")),
			"主武器已销毁": J.truthy(u.get("主武器已销毁")), "战意": J.num0(u.get("战意"))}
	if CelestialV01.开(ctx):
		if CelestialV01.是太阳炉牌(card):
			return CelestialV01.打出太阳炉牌(ctx, u, card, target_id)
		if CelestialV01.是势力牌(card):
			return CelestialV01.打出势力牌(ctx, u, card, target_id)
	var 类 := str(card.get("卡类", ""))
	if 类 == "主武器卡":
		return Btl.打出主武器卡(ctx, unit_id, card_inst_id, target_id)
	if 类 == "大招槽卡":
		return DeckFlow.打出大招(ctx, unit_id, card.get("id"), target_id)
	if 类 == "副武器卡":
		return DeckFlow.打出副武器(ctx, unit_id, card.get("id"), target_id)
	if Btl._是衍生卡(card):
		if 从公有:
			return 打出衍生攻击卡(ctx, unit_id, card.get("id") if card.get("id") != null else card, target_id)
		return _打出专属手牌衍生(ctx, u, card, target_id)
	var 费 := _ATX实际战意(ctx, card)
	if 从公有 and Units.unit_class(u, ctx) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = card
	#   ★ 判空必须同时看 `is_empty()`：`ATX2_U3 好运加护·满开` 的 `"武器": {}` 是**空字典**，
	#   只判 `is Dictionary` 会误触发一次 0 伤害攻击。
	var 摘要: Array = []
	if card.get("武器") is Dictionary and not (card.get("武器") as Dictionary).is_empty():
		摘要.append_array(Btl.攻击结果摘要(Btl._执行武器攻击(ctx, u, {"t": card.get("武器"), "cd": 0.0, "uses": null}, target_id)))
	摘要.append_array(_执行精神效果(ctx, u, card))
	AtxLuck.打出时(ctx, u, card)
	AtxSmoke.打出时(ctx, u, card, null)
	AtxRewrite.打出时(ctx, u, card)
	if 从公有:
		ctx["公有手牌"] = ctx.公有手牌.filter(func(c): return not is_same(c, card))
		_送公有牌去处(ctx, card)
	else:
		u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
		u["专属弃牌堆"].append(card)
	Btl.pushLog(ctx, "〔%s〕%s 打出【%s】（战意 -%s，剩 %s）%s" % ["公有牌" if 从公有 else "专属精神牌", u.name,
		str(card.get("名", "")), J.s(费), J.s(u.get("战意")), Btl.效果摘要文(摘要)],
		J.merged({"类型": "公有牌" if 从公有 else "专属精神牌", "单位": u.key, "卡牌ID": card.get("id"),
			"牌名": card.get("名"), "战意": u.get("战意"), "主武器已销毁": J.truthy(u.get("主武器已销毁")),
			"效果摘要": 摘要}, Btl.谁(u)))
	# ★ M1（试玩反馈修复）：**先触发连携、再记上张** —— `DeckFlow.连携就绪` 判的是「上一张」，
	#   先记自己就会拿自己跟自己比（`上.id != card.id` 恒 false）→ 〔连携〕100% 不触发。
	if J.truthy(card.get("连携")):
		DeckFlow.触发连携(ctx, card)
	DeckFlow.记上张打出牌(ctx, u, card)
	AtxChips.打出后赌局(ctx, u, card)
	AtxDuo.打出牌后(ctx, u, card, target_id)
	RuleHooks.广播("牌打出后", [ctx, u, card, CardPlay.区_公有 if 从公有 else CardPlay.区_精神])
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")), "费用": 费,
		"效果摘要": 摘要, "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 英文别名转发（旧名字，表现层 / 测试在用）。
static func play_spirit_or_public_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出精神或公有牌(ctx, unit_id, card_inst_id, target_id)

## ★ 第 2 项断路器修复：筹码牌的**默认目标容错**（玩家在 UI 上直接点牌、没传 `target_id`）。
static func _筹码默认目标(ctx: Dictionary, u: Dictionary, card: Variant) -> Variant:
	if not (card is Dictionary):
		return null
	var 要 := str((card as Dictionary).get("目标", ""))
	if 要 == "":
		return null
	if 要 == "敌机":
		var 方 = ctx.get("方针")
		if 方 is Dictionary and str((方 as Dictionary).get("类型", "")) == "集中攻击":
			var t = Btl.找单位(ctx, (方 as Dictionary).get("目标位"), "enemy")
			if t is Dictionary and Btl._是活体(t):
				return t.get("key")
		var 敌们 := Units.livingOf("enemy", ctx)
		if 敌们.is_empty():
			return null
		var 排 := 敌们.duplicate()
		J.sort(排, func(a, b): return float(a.slot) - float(b.slot))
		return (排[0] as Dictionary).get("key")
	return u.get("key")

## 打出专属手牌里的衍生攻击卡：扣战意 → 执行 → 进专属弃牌堆。
static func _打出专属手牌衍生(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var 费 := Btl._战意费用(card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := _执行衍生效果(ctx, u, card, target_id)
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	u["专属弃牌堆"].append(card)
	Btl.pushLog(ctx, "〔衍生攻击卡〕%s 打出【%s】（不影响主武器卡）" % [u.name, str(card.get("名", ""))],
		J.merged({"类型": "衍生攻击卡", "单位": u.key, "卡牌": card.get("名")}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": Btl.目标名Of(结果), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 打完的公有牌归哪儿：`冷却 > 0` → 公有冷却区（倒计时归 0 洗回公有牌库）；
## `移出本场` → 移出牌（每场 1 次，不再回库）；其余照旧进公有弃牌堆。
static func _送公有牌去处(ctx: Dictionary, card: Dictionary) -> void:
	match PublicCooldown.去处(card):
		"冷却":
			PublicCooldown.放入(ctx, card)
			Btl.pushLog(ctx, "〔公有冷却〕【%s】进入冷却：%d 回合后洗回公有牌库" % [
				str(card.get("名", "")), int(J.num0(card.get("冷却")))],
				{"类型": "公有冷却", "卡牌ID": card.get("id"), "卡牌": card.get("名"), "冷却": card.get("冷却")})
		"移出":
			var 移出: Array = J.or_(ctx.get("移出牌"), [])
			移出.append(card)
			ctx["移出牌"] = 移出
			Btl.pushLog(ctx, "〔移出本场〕【%s】每场 1 次，打出后移出本场" % str(card.get("名", "")),
				{"类型": "移出本场", "卡牌ID": card.get("id"), "卡牌": card.get("名")})
		_:
			ctx["公有弃牌堆"].append(card)

## 这张牌的层级 / 归属对不对得上这台机体（统帅牌与空归属恒对口）。
static func _身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	var 层 := str(card.get("层级", ""))
	var 归 := str(card.get("归属", ""))
	if 归 == "" or 层 == "统帅":
		return true
	match 层:
		"职业":
			return Units.unit_class(u, ctx) == 归
		"势力":
			return J.inc(Units.势力们(u), 归)
		"角色":
			return str(u.get("key", "")) == 归
	return true

## ★ A6a：这张势力牌被 `u` 打出时**算哪几家的牌**（拉米亚：她打的牌算 ATX，也算影世界）。
static func 牌的势力归属(u: Variant, card: Variant) -> Array:
	if not (u is Dictionary) or not (card is Dictionary):
		return []
	if str((card as Dictionary).get("层级", "")) != "势力":
		return []
	var 们 := Units.势力们(u)
	return 们 if J.inc(们, str((card as Dictionary).get("归属", ""))) else []

## ★ 2026-10-21（任务单问题 3）：执行一张精神牌 / 公有牌的效果，并**返回效果摘要**（一行一条）。
static func _执行精神效果(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 摘要: Array = []
	match str(card.get("单机牌组效果", "")):
		"回战意":
			var 值 := J.num0(card.get("值"))
			Btl.加战意(u, card.get("值", 0.0), ctx, "精神牌")
			摘要.append("战意 +%s（现在 %s）" % [J.s(值), J.s(J.num0(u.get("战意")))])
		"增益":
			var 增: Dictionary = card.get("增益") if card.get("增益") is Dictionary else {}
			Btl.换同源增益(u, "卡牌:%s" % str(card.get("id", "")), 增)
			摘要.append(Btl._增益摘要(增))
		_:
			摘要.append_array(CardEffects.execute(ctx, card))
	return 摘要
