## 60-战斗-3-开局与simulate.js：开局、一回合的行动顺序（含压制射击 / 再动）、胜负判定、回合结束。
## 这是 Battle Core 的入口：开局() → 每回合 [打战术牌()…] → 打一回合()，直到 ctx.result 有值。
class_name Setup
extends RefCounted

static func runOverwatch(ally: Dictionary, ctx: Dictionary) -> void:
	for e in Units.livingOf("enemy", ctx):
		if not Ai.hasOverwatch(e) or J.same(e.get("overwatchFiredTurn"), ctx.turn):
			continue
		if float(ally.hp) <= 0:
			return
		var action = Ai.enemyAction(e, ctx)
		if action == null:
			continue
		e.overwatchFiredTurn = ctx.turn
		Btl.pushLog(ctx, "〔压制射击〕%s 抢先开火" % e.name, J.merged(J.merged({"类型": "压制射击", "单位": e.key, "目标": ally.key}, Btl.谁(e)), Btl.谁目标(ally)))
		Flow.resolveAction(e, action, ctx)

static func runTurn(ctx: Dictionary) -> void:
	Btl.pushLog(ctx, "—— 第 %s 回合 ——" % J.s(ctx.turn), {"类型": "回合"})
	for u in Btl.actionOrder(ctx):
		if ctx.result != null:
			return
		if float(u.hp) <= 0:
			continue
		if u.side == "ally":
			runOverwatch(u, ctx)
		if float(u.hp) <= 0:
			continue
		Flow.actOnce(u, ctx)
		drainAgain(ctx)
		ctx.result = checkResult(ctx)
		if ctx.result != null:
			return

static func drainAgain(ctx: Dictionary) -> void:
	while not ctx.again.is_empty():
		var g = ctx.again.pop_front()
		if float(g.hp) <= 0 or ctx.result != null:
			continue
		Flow.actOnce(g, ctx)
		ctx.result = checkResult(ctx)

static func checkResult(ctx: Dictionary) -> Variant:
	if Units.livingOf("enemy", ctx).is_empty():
		return {"结果": "胜", "原因": "敌方全灭"}
	if Units.livingOf("ally", ctx).is_empty():
		return {"结果": "败", "原因": "我方全灭"}
	return null

static func _减剩余(b: Dictionary) -> bool:
	b.剩余 = (1.0 if b.get("剩余") == null else float(b.剩余)) - 1.0
	return float(b.剩余) > 0

static func endTurn(ctx: Dictionary) -> void:
	for u in Units.livingUnits(ctx):
		for e in u.weapons:
			if J.num(e.cd) > 0:
				e.cd = float(e.cd) - 1.0
		u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return _减剩余(b))
		u.debuffs = J.or_(u.get("debuffs"), []).filter(func(b):
			var 还活着 := _减剩余(b)
			if not 还活着 and J.truthy(b.get("armorCut")):
				u.armorCut = maxf(0.0, J.num0(u.get("armorCut")) - float(b.armorCut))
			return 还活着)
		u.defending = false
	ctx.当前战术 = null
	ctx.本回合防御气势 = 0.0
	for u in ctx.allies:
		u.掩护盾 = 0.0
	Fac.势力回合结束(ctx)
	if Params.战术卡牌开(ctx):
		for c in J.or_(ctx.get("战术手牌"), []):
			if c != null and J.num(c.get("当前冷却")) > 0:
				c.当前冷却 = maxf(0.0, float(c.当前冷却) - 1.0)
		Btl.检查条件发牌(ctx, "回合结束", {"回合": ctx.turn, "_内部自动": true})

## 开局。种子按 JS 的 (种子 >>> 0) || 1；选项：波次 / 战术卡牌 / 已选战术牌 / 初始手牌上限 / 含统帅牌 / 补齐基础激励
## / 手牌装填（"JS参考" = 按 JS 参考版装填初始手牌，只给黄金样例对账用；不写 = 正式规则，见已接受差异 D-01）。
static func 开局(我方编成: Array, 敌方编成: Array, 种子: Variant, 单位开关表: Variant = null, 选项: Variant = null) -> Dictionary:
	var s := int(J.num0(种子)) & 0xFFFFFFFF
	if s == 0:
		s = 1
	var 波次 := []
	for w in J.or_(选项.get("波次") if 选项 is Dictionary else null, []):
		var 来 := []
		for e in J.or_(w.get("来"), []):
			来.append({"键": e.get("键"), "等级": e.get("等级"), "强化": e.强化 if e.get("强化") != null else 1.0, "层": e.get("层")})
		波次.append({"回合": w.get("回合"), "来": 来})
	var ctx := {
		"turn": 1.0, "种子": float(s), "rng": Mulberry32.new(s),
		"allies": Units.makeUnits(我方编成, "ally"), "enemies": Units.makeUnits(敌方编成, "enemy"),
		"方针": Btl.默认方针(),
		"回合上限": Diff.回合上限(敌方编成),
		"气势": J.num0(Params.气势总攻参数().get("开场气势")),
		"当前战术": null, "本回合防御气势": 0.0, "全队憋大招": false, "曾满气势回合": null, "自然气势已加回合": 1.0,
		"log": [], "_rng_at": [], "result": null, "again": [],
		"波次": 波次,
	}
	# 藏品（93-藏品.js 的「开战应用」段）：**与 JS 同一时机** —— ctx 造好后、应用全场词条之前
	# （60-战斗-3-开局与simulate.js:131 → 134）。藏品 id 数组从 `选项.藏品` 来（DEBT-06：不读全局 `肉鸽.RUN`）；
	# 不传 / 空数组 → 立刻返回，一个字段都不动（既有黄金样例逐字不变）。
	RelicBattle.apply_on_battle_start(ctx, J.or_(选项.get("藏品") if 选项 is Dictionary else null, []))
	Btl.应用全场词条(ctx)
	for u in Units.livingUnits(ctx):
		u.weapons = (u.weapons as Array).map(func(e): return J.merged(e, {"cd": 0.0}))
		u.holdUlt = false
		u.掩护盾 = 0.0
		u.TRANSAM手动 = false
		u.本回合开TRANSAM = false
	Btl.设单位开关(ctx, 单位开关表)
	Btl.pushLog(ctx, "战斗开始：我方 %d 台 vs 敌方 %d 台" % [ctx.allies.size(), ctx.enemies.size()], {"类型": "开始"})
	Fac.势力开局(ctx)
	if 选项 is Dictionary and 选项.has("战术卡牌"):
		ctx.选项 = J.merged(ctx.get("选项"), {"战术卡牌": J.truthy(选项.战术卡牌)})
	if Params.战术卡牌开(ctx):
		ctx.战术卡牌开 = true
		var 默气 := J.num(Params.战术卡牌参数().get("初始默认气力"))
		ctx.气势 = 默气 if is_finite(默气) else 25.0
		var 池 := Btl.生成队伍牌池(ctx.allies, J.merged({"补齐基础激励": true}, 选项 if 选项 is Dictionary else {}))
		ctx.战术牌池 = 池.全部牌池
		ctx.战术手牌 = 池.初始手牌
		ctx.待触发战术牌 = 池.待触发牌
		ctx.候补初始牌 = 池.候补初始牌
		ctx.已打出战术牌 = []
		ctx.战况计数 = {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0, "刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0}
		ctx.满手牌推迟记录 = []
	return ctx

static func 打一回合(ctx: Dictionary) -> void:
	Flow.回合开始(ctx)
	runTurn(ctx)
	if ctx.result == null:
		var 上限 := J.num0(ctx.get("回合上限"))
		if 上限 == 0:
			上限 = float(Db.T.MAX_TURN)
		if float(ctx.turn) >= 上限:
			ctx.result = {"结果": "败", "原因": "第 %s 回合结束还没分出胜负（按撤退处理）" % J.s(上限)}
		else:
			endTurn(ctx)
			ctx.turn = float(ctx.turn) + 1.0
			if Params.气势总攻开() and float(ctx.turn) >= 2 and not J.same(ctx.get("自然气势已加回合"), ctx.turn):
				ctx.自然气势已加回合 = ctx.turn
				Btl.加气势(ctx, Flow.自然加())

## 一整场（没有命令）：simulate() 的等价物，给测试 / 无界面结算用
static func 跑完(我方: Array, 敌方: Array, 种子: Variant, 选项: Variant = null) -> Dictionary:
	var ctx := 开局(我方, 敌方, 种子, null, 选项)
	var 顶 := maxf(float(Db.T.MAX_TURN), J.num0(ctx.get("回合上限")) if J.truthy(ctx.get("回合上限")) else float(Db.T.MAX_TURN)) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		打一回合(ctx)
	if ctx.result == null:
		ctx.result = {"结果": "败", "原因": "超出回合上限"}
	Btl.pushLog(ctx, "战斗结束：%s（%s）" % [ctx.result.结果, ctx.result.原因], {"类型": "结束"})
	return ctx
