## 60-战斗-2-回合流程.js：单位行动、动作结算。
## ★ R1 退役清理：行动方针取消后「防御」不再发生 —— resolveAction 的 defend 分支不再改单位状态，
##   回合开始时消费「防御回复」回 5% HP 的那一段死代码已删（defending / 防御回复 由此恒为假，引擎里的读法不变）。
class_name Flow
extends RefCounted

static func 空位(ctx: Dictionary, side: String) -> Variant:
	var 占 := Units.livingOf(side, ctx).map(func(u): return u.slot)
	for r in Fm.ROWS():
		for c in int(Fm.行列数(r)):
			var s := Fm.slotOf(r, c)
			if not J.inc(占, s):
				return s
	return null

## 钩子薄转发：`我方阶段初_增援`（派发序在 `RuleHooks.顺序` 里）
static func 我方阶段初_增援(ctx: Dictionary) -> void:
	增援(ctx)

static func 增援(ctx: Dictionary) -> void:
	# 同一个敌人键在场 / 在波次里第 n 次出现 → 发 `键#n`（与 `Units.makeUnits` 同一份口径）
	var 已用 := Units.已用键表(ctx.get("enemies"))
	for w in J.or_(ctx.get("波次"), []):
		if w == null or not J.same(w.get("回合"), ctx.turn):
			continue
		增援一波(ctx, w, 已用)
	if J.some(ctx.enemies, func(u): return J.truthy(u.get("词条全场"))):
		Btl.应用全场词条(ctx)

## 来一波敌方增援（`w.来` = `[{键, 等级, 强化, 层, 词条}]`）：固定波次与 Boss 阶段进场共用。返回新来的单位。
static func 增援一波(ctx: Dictionary, w: Dictionary, 已用: Dictionary) -> Array:
	var 新 := []
	var 位们 := []
	var 单位们 := []
	var 名们 := []
	var 没空位 := 0.0
	for e in J.or_(w.get("来"), []):
		var s = 空位(ctx, "enemy")
		if s == null:
			没空位 += 1.0
			continue
		var 实例键 := Units.下一个键(str(e.键), 已用)
		var u := Units.makeUnit(e.键, "enemy", float(s), float(e.等级), e.强化 if e.get("强化") != null else 1.0, null, e.get("层"), 实例键)
		if J.truthy(e.get("词条")):
			Traits.词条到单位([u], {"词条": e.词条, "层": e.get("层")})
		ctx.enemies.append(u)
		新.append(u)
		位们.append(s)
		单位们.append(u.key)
		名们.append(u.name)
	if not 位们.is_empty():
		Btl.pushLog(ctx, "〔增援〕第 %s 回合：敌方 %d 台赶到（%s：%s）" % [J.s(ctx.turn), 位们.size(), "、".join(位们.map(func(s): return Fm.位名(s))), "、".join(名们)],
			{"类型": "增援", "数量": float(位们.size()), "位们": 位们, "目标方们": 位们.map(func(_s): return "enemy"), "单位们": 单位们})
	if 没空位 != 0:
		Btl.pushLog(ctx, "〔增援〕第 %s 回合：还有 %s 台挤不进来（9 个位都占着）" % [J.s(ctx.turn), J.s(没空位)], {"类型": "增援", "数量": 0.0, "结果": "没空位"})
	return 新

## 指挥职业被动：同排队友命中 +10（本回合）；后排指挥再给正前方队友「后方本阵」的命中 / 防御。
static func 指挥被动(ctx: Dictionary) -> void:
	for 方 in ["ally", "enemy"]:
		for c in Units.livingOf(方, ctx):
			if not Reach.职业是(c, "指挥"):
				continue
			var 同排 := Units.livingOf(方, ctx).filter(func(t): return not is_same(t, c) and Units.unitRow(t) == Units.unitRow(c))
			if not 同排.is_empty():
				for t in 同排:
					Btl.换同源增益(t, "指挥", {"hit": 10.0})
				Btl.pushLog(ctx, "〔指挥〕%s 让同一排的队友命中 +10（本回合）：%s" % [c.name, "、".join(同排.map(func(t): return t.name))],
					J.merged({"类型": "指挥", "单位": c.key, "目标": 同排.map(func(t): return t.key), "目标位们": 同排.map(func(t): return t.slot), "目标方们": 同排.map(func(t): return t.side)}, Btl.谁(c)))
			if Params.职业排位开() and J.is_int(c.slot) and Fm.rowOfSlot(c.slot) == Fm.ROW_BACK:
				var frontAlly = J.find(Units.livingOf(方, ctx), func(t): return not is_same(t, c) and float(t.slot) == float(c.slot) - 4.0)
				if frontAlly != null:
					Btl.换同源增益(frontAlly, "后方本阵", {
						"hit": Params.职业排位数("指挥后排护前排命中", 10),
						"def": Params.职业排位数("指挥后排护前排防御", 15),
						"turns": 1.0,
					})

## 钩子薄转发：`我方阶段初_指挥`（派发序在 `RuleHooks.顺序` 里）
static func 我方阶段初_指挥(ctx: Dictionary) -> void:
	指挥被动(ctx)

static func 单位动作(u: Dictionary, ctx: Dictionary) -> Variant:
	if u.side == "enemy":
		return Boss.bossTurn(u, ctx)
	return Ai.aiAction(u, ctx)

static func actOnce(u: Dictionary, ctx: Dictionary) -> void:
	if float(u.hp) <= 0:
		return
	u.actedTurn = ctx.turn
	if J.same(u.get("近卫连斩待追击Turn"), ctx.turn):
		u.近卫连斩追击Turn = ctx.turn
		u.erase("近卫连斩待追击Turn")
	var action = 单位动作(u, ctx)
	var r = null
	if action != null:
		r = resolveAction(u, action, ctx)
	else:
		Btl.pushLog(ctx, "%s 没有能打到人的武器，跳过" % u.name, J.merged({"类型": "跳过", "单位": u.key}, Btl.谁(u)))
	if u.get("近卫连斩追击Turn") != null:
		u.erase("近卫连斩追击Turn")
	runAutoCast(u, ctx)
	var 近卫后排受限: bool = Params.职业排位开() and Params.职业排位参数().get("近卫后排禁连斩") != false \
		and J.is_int(u.slot) and Fm.rowOfSlot(u.slot) == Fm.ROW_BACK \
		and J.some(Units.livingOf(u.side, ctx), func(t): return not is_same(t, u) and float(t.slot) == float(u.slot) - 4.0)
	if r != null and float(r.击破) > 0 and Reach.职业是(u, "近卫") and not J.same(u.get("近卫再动Turn"), ctx.turn) and not 近卫后排受限:
		u.近卫再动Turn = ctx.turn
		u.近卫连斩待追击Turn = ctx.turn
		ctx.again.append(u)
		Btl.pushLog(ctx, "〔连斩〕%s 击破了目标，立刻再行动一次（近卫，每回合 1 次）" % u.name, J.merged({"类型": "连斩"}, Btl.谁(u)))

static func runAutoCast(u: Dictionary, ctx: Dictionary) -> void:
	if J.same(u.get("echoTurn"), ctx.turn):
		return
	var pool := (u.weapons as Array).filter(func(e): return e.t.get("special") == "echo" and float(u.lv) >= J.num(e.t.get("unlock")) and J.num(e.cd) <= 0)
	if pool.is_empty():
		return
	J.sort(pool, func(a, b): return J.num(a.t.unlock) - J.num(b.t.unlock))
	var e = pool[pool.size() - 1]
	var w = e.t
	var foes := Units.livingOf(Units.otherSide(u.side), ctx)
	var targets := foes.filter(func(t): return Units.unitRow(t) == Fm.ROW_FRONT)
	if targets.is_empty():
		return
	u.echoTurn = ctx.turn
	if J.truthy(w.get("cd")):
		e.cd = w.cd
	for t in targets:
		if float(t.hp) <= 0:
			continue
		var rec := Calc.resolveAttack(u, t, w, ctx, {})
		Btl.pushLog(ctx, "〔%s〕%s" % [w.name, rec.文本], J.merged(J.merged({"类型": "残月余响", "单位": u.key, "目标": t.key, "武器": w.name}, Btl.谁(u), Btl.谁目标(t)), rec.字段))
		if float(t.hp) <= 0:
			Fac.势力击破(ctx, u, t)

## ★ A6a：这一次攻击里「散布」打死、但**不是**主目标的那些敌机（`rec.字段.散布击破` 是键数组）。
##   主目标由 `Flow.resolveAction` 自己的 `打死了` 分支算，这里把它排除掉，避免重复计击破。
static func _散布击破们(ctx: Dictionary, 字段: Variant, 已计入: Dictionary) -> Array:
	var 出: Array = []
	if not (字段 is Dictionary) or not (ctx is Dictionary):
		return 出
	var 键们 = (字段 as Dictionary).get("散布击破")
	if not (键们 is Array):
		return 出
	for t in Units.sideUnits(str(已计入.get("side", "enemy")), ctx):
		if not (t is Dictionary) or is_same(t, 已计入):
			continue
		if J.inc(键们, (t as Dictionary).get("key")) and float((t as Dictionary).get("hp", 0.0)) <= 0.0:
			出.append(t)
	return 出

static func _buff文字(buff: Dictionary) -> String:
	var 们 := []
	for k in buff.keys():
		var v = buff[k]
		们.append("%s %s%s" % [k, "+" if (J.is_num(v) and float(v) > 0) else "", J.s(v)])
	return "、".join(们)

## 一次攻击打一个目标。所有「造成攻击结算」的代码都走这里（不许再直接调 Calc.resolveAttack）。
## opts：
##   改目标: bool = true      —— 是否走 Btl.嘲讽（援护 / 掩护 / 铁壁）；范围攻击和「指定原目标重打」类传 false
##   面: bool = false         —— 这一发是范围攻击（不走嘲讽、不算遮挡惩罚）
##   blockPenalty / 伤害倍率 / 威力倍率 / 必中 / 必暴 / defending / preview / 强制QTE / _装甲池记录
##                            —— 原样透传给 Calc.resolveAttack（伤害倍率 / 威力倍率 会再乘上逐目标倍率）
##   位倍率表 / 威力倍表 / 动作 —— 范围落点倍率 / 顺劈倍率 / 【GN 力场】判定要用
##   不写标准攻击日志: bool = false —— 调用方自己写那条攻击记录（atx_three / fac_atx / 自爆）
##   旁路攻击: bool = false   —— 寄生在别人那一次攻击里的**派生打击**（残月余响 / ATX v0.1 牌 / 自爆）：
##                             照常执行哪些步骤、跳过哪些步骤，逐项见函数体里 `旁路` 那一段注释
## 返回：{rec, 实际目标, 打死了, 散布死们, 命中段数, 跳过}
static func 结算一个目标(ctx: Dictionary, actor: Dictionary, 原目标: Dictionary, w: Dictionary, opts: Dictionary) -> Dictionary:
	var 出 := {"rec": {}, "实际目标": 原目标, "打死了": false, "散布死们": [], "命中段数": 0, "跳过": true}
	if not (原目标 is Dictionary) or not (actor is Dictionary) or float(原目标.get("hp", 0.0)) <= 0.0:
		return 出
	出["跳过"] = false
	var 面: bool = J.truthy(opts.get("面"))
	var 实际: Dictionary = 原目标
	if not 面 and opts.get("改目标", true) != false:
		var 嘲 = Btl.嘲讽(ctx, actor, 原目标)
		if 嘲 != null:
			var 剩文 := Btl.援护剩余文(嘲)
			var 嘲字段 := {"类型": "嘲讽", "目标": 嘲.key, "原目标": 原目标.key,
				"保护者": 嘲.key, "被保护者": 原目标.key,
				"剩余": int(J.num0(嘲.get("靶机援护剩余"))),
				"上限": int(J.num0(嘲.get("靶机援护上限")))}
			Btl.pushLog(ctx, "〔援护防御〕%s 保护 %s，替其挡下攻击！（%s）" % [嘲.name, 原目标.name, 剩文],
				J.merged(J.merged(嘲字段, Btl.谁(嘲)), Btl.谁目标(嘲)))
			实际 = 嘲
	出["实际目标"] = 实际
	var 血 := float(实际.hp)
	var blockPenalty := 0.0
	if not 面:
		if opts.has("blockPenalty"):
			blockPenalty = J.num0(opts.get("blockPenalty"))
		else:
			blockPenalty = Reach.遮挡命中惩罚(ctx, actor, w, 实际)
	var 位倍率表: Dictionary = J.or_(opts.get("位倍率表"), {})
	var 威力倍表: Dictionary = J.or_(opts.get("威力倍表"), {})
	var 位倍 := float(位倍率表.get(int(实际.get("slot", -1)), 1.0))
	var 力场倍 := CelestialV01.掩护力场倍率(ctx, opts.get("动作"), 实际, w)
	var 计: Dictionary = {"blockPenalty": blockPenalty}
	for k in ["必中", "defending", "强制QTE", "preview", "必暴", "_装甲池记录"]:
		if opts.has(k):
			计[k] = opts[k]
	var 段位倍 := 位倍 * 力场倍
	# `Calc` 里 `伤害倍率` / `威力倍率` 缺省 = null（= 总攻乘子 / 1.0），所以只有传了才补这两个键。
	if opts.get("伤害倍率") != null:
		计["伤害倍率"] = float(opts.get("伤害倍率")) * 段位倍
	elif 段位倍 != 1.0:
		计["伤害倍率"] = 段位倍
	if opts.get("威力倍率") != null:
		计["威力倍率"] = float(opts.get("威力倍率")) * float(威力倍表.get(int(实际.get("slot", -1)), 1.0))
	Fac.势力攻击前(ctx, actor, 实际, w)
	var rec: Dictionary = Calc.resolveAttack(actor, 实际, w, ctx, 计)
	var 打死了: bool = 血 > 0.0 and float(实际.hp) <= 0.0
	var 散布死们: Array = _散布击破们(ctx, rec.字段, 实际)
	var 段数 := J.num0(rec.字段.get("段数"))
	if 段数 == 0.0:
		段数 = 1.0
	var 命中段 := 0.0 if rec.字段.get("命中") == false else (J.num(rec.字段.命中段数) if rec.字段.get("命中段数") != null else 1.0)
	var 未中段 := maxf(0.0, 段数 - 命中段)
	var 有伤 := J.num(rec.字段.get("伤害")) > 0.0
	if not J.truthy(opts.get("不写标准攻击日志")):
		var 攻击字段: Dictionary = J.merged(J.merged({"类型": "攻击", "单位": actor.key, "目标": 实际.key, "武器": w.name, "集火": false, "守护挡下": false, "原目标": null, "原目标位": null},
			Btl.谁(actor), Btl.谁目标(实际)), rec.字段)
		# 范围副目标的打折倍率（只有真打折时才记这个键，主目标 / 单体一发不多一个字段）
		if 位倍 != 1.0:
			攻击字段["范围倍率"] = 位倍
			攻击字段["范围型"] = Reach.范围型(w)
		Btl.pushLog(ctx, rec.文本, 攻击字段)
		# 【GN 力场】真的吃掉 40% 时单独记一行（否则玩家只看到伤害变小，不知道为什么）
		if 力场倍 != 1.0:
			Btl.pushLog(ctx, "〔GN 力场〕%s 替队友承受这一发光束伤害 → 伤害 −40%%（×0.6）" % str(实际.get("name", "")),
				J.merged({"类型": "GN力场", "单位": 实际.get("key"), "伤害倍率": 力场倍,
					"武器": w.name, "伤害类型": str(w.get("dmgType"))}, Btl.谁(实际)))
	Calc.标定经济记录(ctx, actor, 实际, {"类型": "攻击", "武器": w.name}, rec.字段.get("标定"))
	# 我方任何武器 / 大招 / 伤害牌选为目标或波及结算过的敌机 → `本回合被攻击过 = true`
	#（**打空也算**；纯 Buff / Debuff 的精神牌 / 势力牌不走这条路，所以不会把敌机标脏）
	if actor.get("side") == "ally":
		CelestialV01.标记被攻击(ctx, 实际)
	# `旁路攻击` = 残月余响 / ATX v0.1 牌 / 自爆这类**寄生在别人那一次攻击里**的结算：它们只借这条管线
	# 拿伤害与击破记账，外层攻击专属的那些钩子本来就由外层那一次负责，嵌套着再来一遍会把战报顺序与数值都改掉。
	# 传 `旁路攻击 = true` 时（调用方一律同时传 `改目标: false` 与 `不写标准攻击日志`）：
	#   **照常执行**（按下面的实际次序）：
	#     1) `Fac.势力攻击前`；2) `Calc.resolveAttack`；3) 击破判定 + `散布` 副目标筛选；
	#     4) `Calc.标定经济记录`（不判 `旁路`，记号为空时自己早返回）；
	#     5) `CelestialV01.标记被攻击`（我方出手时）；6) `CelestialV01.消费首击减伤`（哈罗吃一次就清）；
	#     7) `Fac.势力击破` + 克鲁佐击破计数 + `Btl.记击破`（含 `散布` 副目标那两笔）；
	#     8) 秘银「本回合被秘银攻击过」记账；9) `ctx.战况计数` 累加（`未命中段` / `响介受击或打空` 等）。
	#   **跳过**：
	#     · `Btl.嘲讽`（改目标走的是调用方的 `改目标: false`，不进那一段）；
	#     · 标准攻击战报行 `Btl.pushLog` + `〔GN 力场〕` 那一行（调用方传 `不写标准攻击日志`，自己写）；
	#     · `CelestialV01.受击后`（阿雷路亚双人格）；
	#     · `CelestialV01.消费行动预测`（Veda·行动预测）；
	#     · `Btl.自爆`（被击破单位不连锁自爆）；
	#     · `Fac.势力友军攻击后` 与 `Btl.镜甲反弹`。
	var 旁路: bool = J.truthy(opts.get("旁路攻击"))
	# 阿雷路亚【双人格】：受击结算后掷一次 20%（一次攻击事件 × 一个目标 = 一次）
	if not 旁路 and 实际.get("side") == "ally":
		CelestialV01.受击后(ctx, 实际)
		# 势力模块的受击后钩子（觉醒退醒 / 反射 / 转伤都挂在这条上）。
		RuleHooks.广播("受击后", [ctx, 实际, actor, rec, w])
	if not 旁路:
		# `Veda·行动预测`（敌方第一次攻击命中 −30）在这一发结算完之后作废
		CelestialV01.消费行动预测(ctx, actor)
	# `GN 全盾·哈罗`（第一次受到的攻击伤害 −40%）「吃一次就清」—— **旁路也算一次攻击**，
	# 否则自爆会白吃一次减伤、紧接着那一发又吃一次。
	CelestialV01.消费首击减伤(实际)
	if 打死了:
		Fac.势力击破(ctx, actor, 实际)
		# 自爆不连锁：旁路攻击（残月余响 / ATX v0.1 牌 / 自爆本身）打死的目标不再触发自爆，
		# 与改前一致（自爆的汇总行在这之前就写好了，连锁会把战报顺序倒过来）。
		if not 旁路:
			Btl.自爆(ctx, actor, 实际)
		Btl.记击破(ctx, actor, 实际)
	# `散布` 的副目标被击杀：与普通击杀同一套（势力钩子 + 击破记账）
	for 死 in 散布死们:
		Fac.势力击破(ctx, actor, 死)
		Btl.记击破(ctx, actor, 死)
	if 有伤 and not 旁路:
		Fac.势力友军攻击后(ctx, actor, 实际, rec.字段)
		Btl.镜甲反弹(ctx, actor, 实际, rec.字段, w)
	if J.truthy(ctx.get("战况计数")):
		var 计2: Dictionary = ctx.战况计数
		if 有伤 and actor.side == "ally" and Btl.提取单位三层信息(actor).势力 == "月球王国":
			计2.残月或月国命中 = float(计2.残月或月国命中) + 1.0
		if 未中段 > 0:
			计2.未命中段 = J.num0(计2.get("未命中段")) + 未中段
			计2.响介受击或打空 = float(计2.响介受击或打空) + 1.0
		if 有伤 and actor.side == "ally" and Btl._是(actor, "CB1"):
			计2.刹那命中或TA = float(计2.刹那命中或TA) + 1.0
		if 有伤 and 实际.side == "ally" and Btl._是(实际, "A1"):
			计2.响介受击或打空 = float(计2.响介受击或打空) + 1.0
	出["rec"] = rec
	出["打死了"] = 打死了
	出["散布死们"] = 散布死们
	出["命中段数"] = int(命中段)
	return 出

static func resolveAction(actor: Dictionary, action: Dictionary, ctx: Dictionary) -> Dictionary:
	var w = action.get("weapon")
	var 空 := {"击破": 0.0}
	# ★ A6b：塔斯克【掩护】的兑现 —— `Ai.enemyAction` / `Boss.单武器动作` 把目标改成了他，
	#   这里扣掉这个敌方阶段的一次额度并记一行（预告里写的就是他，所以预告 == 实际，R4）。
	#   不是掩护接管 = 第一行返回（一个字段都不动）。
	AtxDuo.行动前(ctx, actor, action)
	match action.kind:
		"none":
			return 空
		"buff":
			var buff: Dictionary = J.or_(J.or_(Calc.wv(actor, w, "buff"), w.get("buff")), {})
			for t in action.targets:
				Btl.换同源增益(t, w.name, buff)
			Calc.spendWeapon(actor, action.entry)
			Btl.pushLog(ctx, "%s【%s】→ %s：%s（到本回合结束）" % [actor.name, w.name, "、".join(action.targets.map(func(t): return t.name)), _buff文字(buff)],
				J.merged({"类型": "增益", "单位": actor.key, "武器": w.name, "目标": action.targets.map(func(t): return t.key),
					"目标位们": action.targets.map(func(t): return t.slot), "目标方们": action.targets.map(func(t): return t.side)}, Btl.谁(actor)))
			return 空
		"grant":
			var t: Dictionary = action.target
			# [规范v0.3·断路器3] 单机牌组口径下改道 `DeckFlow.再动`（唯一实现：写锁 + 写战报 + 跳过出鞘的剑牌）
			if t.get("主武器已销毁") != null:
				Calc.spendWeapon(actor, action.entry)
				DeckFlow.再动(ctx, t, str(w.name))
				return 空
			t.grantedTurn = ctx.turn
			ctx.again.append(t)
			# ★ DECK-1：再动 = 主武器卡回手（只对单机牌组单位生效）
			if t.get("主武器已销毁") != null:
				t["主武器已销毁"] = false
			Calc.spendWeapon(actor, action.entry)
			Btl.pushLog(ctx, "%s【%s】→ %s：再行动一次" % [actor.name, w.name, t.name], J.merged(J.merged({"类型": "再动", "单位": actor.key, "目标": t.key}, Btl.谁(actor)), Btl.谁目标(t)))
			return 空
		"defend":
			# 退役（R1）：行动方针已取消，Btl.禁止攻击 恒为假 → 没有任何地方会产出 defend。
			# 原来的 actor.defending / actor.防御回复（防御 +50 与「下回合回复 5% HP」）一起删掉；
			# 这里只留一声明确的报错，免得万一有新代码产出 defend 时静默掉进下面的攻击分支。
			push_error("Flow.resolveAction：收到已退役的 defend 行动（禁止攻击恒为假，应有新代码接错了）")
			return 空
		"heal":
			var tgt: Dictionary = action.target
			var amount := Calc.healAmount(actor, w)
			var before := float(tgt.hp)
			tgt.hp = minf(float(tgt.maxHp), float(tgt.hp) + amount)
			Calc.spendWeapon(actor, action.entry)
			var 回 := float(tgt.hp) - before
			Btl.pushLog(ctx, "%s 修理 %s，回复 %s" % [actor.name, tgt.name, J.s(回)], J.merged(J.merged({
				"类型": "修理", "单位": actor.key, "目标": tgt.key, "武器": w.name, "回复": 回, "目标剩余HP": tgt.hp,
			}, Btl.谁(actor)), Btl.谁目标(tgt)))
			Fac.势力修理(ctx, actor, tgt, w, 回)
			return 空
	var kind = Reach.rangeKindOf(w)
	# ★ A6a：近卫【回旋斩】的「横扫」也走范围那一支（`action.横扫` 由 `Btl._执行武器攻击` 写）。
	var 面: bool = Reach.isAreaKind(kind) or J.truthy(action.get("横扫"))
	var targets: Array = J.or_(action.get("hit"), []) if 面 else [action.target]
	# ★ MITH3-1：《武器范围规则 v0.1》的 `area` 五型（single / splash / pierce / row / all）。
	var 位倍率表: Dictionary = {}
	# ★ CB-0：**逐目标威力倍率**表（目前只有【顺劈】的副目标用它 = 50% 单段威力）。
	#   与 `位倍率表`（伤害倍率）分开：任务单要求的是「50% **单段威力**」——
	#   威力先减半再进装甲池扣减，装甲池的绝对数值因此不会被偷偷等价成「伤害减半」。
	var 威力倍表: Dictionary = {}
	if action.get("target") is Dictionary and J.truthy(w) \
		and Reach.是范围武器(w) and not J.truthy(action.get("_范围已展开")):
		var 落点 := Reach.范围目标们(ctx, w, action.target)
		if not 落点.is_empty():
			var 新目标们: Array = []
			for e in 落点:
				var tu = e.get("单位")
				if tu == null:
					continue
				新目标们.append(tu)
				位倍率表[int(tu.get("slot", -1))] = float(e.get("倍率", 1.0))
			if not 新目标们.is_empty():
				面 = true
				targets = 新目标们
	# ★ CB-0（任务单 §1.1 第 4 条）：近卫分类牌【顺劈】的落点展开 ——
	#   主目标 100% 威力；同排左右相邻格（`rowOfSlot` 相同、`colOfSlot` 相差 1）的存活敌机
	#   各按 `顺劈倍率`（默认 0.5）的**单段威力**独立掷命中与暴击，并各自初始化 / 消耗装甲共享池。
	#   `action.顺劈` 只由 `Btl._执行武器攻击` 在近战武器带 `cleave` / 顺劈标记时写。
	if J.truthy(action.get("顺劈")) and action.get("target") is Dictionary \
		and (action.get("target") as Dictionary).get("slot") != null:
		var 主: Dictionary = action.get("target")
		var 劈倍 := float(J.or_(action.get("顺劈倍率"), 0.5))
		var 劈们: Array = [主]
		for e2 in ClassCards.顺劈副目标们(ctx, 主):
			劈们.append(e2)
			威力倍表[int((e2 as Dictionary).get("slot", -1))] = 劈倍
		威力倍表[int(主.get("slot", -1))] = 1.0
		面 = true
		targets = 劈们
	var 总攻倍 := 1.0
	if Params.气势总攻开() and ctx.get("当前战术") == "总攻" and actor.side == "ally":
		总攻倍 = J.num0(Params.气势总攻参数().get("总攻伤害倍率"))
		if 总攻倍 == 0:
			总攻倍 = 1.35
	var 倍率 := Boss.Boss伤害倍率(actor) * Fac.势力伤害倍率(actor, w) * 总攻倍
	var 威力倍率 := Fac.势力威力倍率(actor, w)
	var 击破 := 0.0
	var 结算们: Array = []
	for t in targets:
		# 一个目标的全部结算（嘲讽 → 遮挡 → 结算 → 击破记账 → 战报 → 攻击后钩子）都在
		# `Flow.结算一个目标` 里，本函数只负责「这一次攻击打哪几个目标」与逐发倍率。
		var 一: Dictionary = 结算一个目标(ctx, actor, t, w, {
			"改目标": not 面, "面": 面,
			"伤害倍率": 倍率, "威力倍率": 威力倍率,
			"位倍率表": 位倍率表, "威力倍表": 威力倍表, "动作": action,
		})
		if J.truthy(一.get("跳过")):
			continue
		# 主目标 + `散布` 副目标的击杀都计进这一次攻击的击破数（近卫连斩 / 再动读它）
		if J.truthy(一.打死了):
			击破 += 1.0
		击破 += float((一.散布死们 as Array).size())
		结算们.append(一)
	# ★ A6a：三套职业分类牌的「攻击后」结算（乘胜追击 / 一击脱离）—— 一次攻击只判一次
	ClassCards.攻击后(ctx, actor, 击破)
	Calc.spendWeapon(actor, action.entry)
	# ★ MITH-2：杨（U8）的「ECS 隐形」到它下一次攻击为止 —— 这一击打出去就解除
	if J.truthy(actor.get("_隐身")):
		actor.erase("_隐身")
	Fac.势力武器用后(ctx, actor, action.entry, w)
	# `结算目标们` / `实际目标` 是**真实受击结果**（按结算顺序，每项含 `实际目标` / `命中段数` / `rec`），
	# 供 `Btl._执行武器攻击` 透传给 `CelestialV01.武器打完后` —— 不许再倒扫战报去猜。
	return {"击破": 击破, "结算目标们": 结算们, "实际目标": 结算们}
