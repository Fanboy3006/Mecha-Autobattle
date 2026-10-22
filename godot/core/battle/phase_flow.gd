## 职责：阶段流转 —— 开始我方阶段 / 结束我方回合、出手顺序、单位人工开关、击破记账、AI 选牌器取用。
class_name BattlePhaseFlow
extends RefCounted

## 惰性取 AI 选牌器：用 `load` 而不是全局类名，避免 btl 与 ai_deck 的编译期循环依赖。
static var _AI选牌器缓存: Variant = null

## 当前方针恒为「全军突击」。
static func 默认方针() -> Dictionary:
	return {"类型": "全军突击", "目标位": null}

## 按开关表设我方单位的人工开关。
static func 设单位开关(ctx: Dictionary, 开关表: Variant) -> void:
	for u in ctx.allies:
		var c = J.at(开关表, u.slot) if 开关表 != null else null
		if not J.truthy(c):
			continue
		if c.get("保留大招") != null:
			u.holdUlt = J.truthy(c.保留大招)

## 这一台禁止攻击吗。
static func 禁止攻击(_u: Variant, _ctx: Variant) -> bool:
	if CelestialV01.脱装不能攻击(_u):
		return true
	return false

## 这一台按防御姿态结算吗。
static func 按防御结算(u: Variant, _ctx: Variant) -> bool:
	return u != null and J.truthy(u.get("defending"))

## 出手顺序：速度 → 我方先 → 列 → 位号（纯读）。
static func actionOrder(ctx: Dictionary) -> Array:
	var arr := Units.livingUnits(ctx)
	J.sort(arr, func(a, b):
		var d := Units.speedOf(b) - Units.speedOf(a)
		if d != 0:
			return d
		if a.side != b.side:
			return -1.0 if a.side == "ally" else 1.0
		var c := Fm.colOfSlot(a.slot) - Fm.colOfSlot(b.slot)
		if c != 0:
			return c
		return float(a.slot) - float(b.slot))
	return arr

## 记一次击破：计「本场击破」并写〔击破〕，合体技据此移出。
static func 记击破(ctx: Variant, 攻击者: Variant, 被击破者: Variant) -> void:
	if not (ctx is Dictionary) or not (被击破者 is Dictionary):
		return
	if 攻击者 is Dictionary:
		DeckFlow.计数加(攻击者, "本场击破", 1)
	var 攻名 := str((攻击者 as Dictionary).get("name", "")) if 攻击者 is Dictionary else ""
	var 计 = J.g(攻击者, "v3计数") if 攻击者 is Dictionary else null
	var 已记 := int(J.num0((计 as Dictionary).get("本场击破"))) if 计 is Dictionary else 0
	var 额外: Dictionary = {"类型": "击破", "目标": (被击破者 as Dictionary).get("key"), "本场击破": 已记}
	if 攻击者 is Dictionary:
		额外 = J.merged(额外, {"单位": (攻击者 as Dictionary).get("key")})
		额外 = J.merged(额外, Btl.谁(攻击者))
	Btl.pushLog(ctx, "〔击破〕%s%s" % [("%s 击破了 " % 攻名) if 攻名 != "" else "被击破：",
		str((被击破者 as Dictionary).get("name", ""))], J.merged(额外, Btl.谁目标(被击破者)))
	AtxFaction.合体移除(ctx)

## 进入我方阶段：严格 7 步（顺序见 `RuleHooks.顺序`）。
static func 开始我方阶段(ctx: Dictionary) -> void:
	if ctx == null:
		return
	ctx["阶段"] = Btl.阶段_我方开始
	ctx["turn"] = float(ctx.get("turn", 0.0)) + 1.0
	DeckFlow.阶段初_冷却与维持(ctx)
	RuleHooks.广播("我方阶段初_前", [ctx])
	# 顺序 = 增援 → 自爆 → 词条 → 势力 → 指挥（`在场的` = 增援前的名单）
	var 在场的: Array = (ctx.get("enemies") if ctx.get("enemies") is Array else []).duplicate()
	RuleHooks.广播("我方阶段初_增援", [ctx])
	RuleHooks.广播("我方阶段初_自爆", [ctx, 在场的])
	RuleHooks.广播("我方阶段初_词条", [ctx])
	RuleHooks.广播("我方阶段初_势力", [ctx])
	RuleHooks.广播("我方阶段初_指挥", [ctx])
	var 加 := Params.回合初战意()
	for u in Units.livingOf("ally", ctx):
		if not Btl.是单机牌组单位(u):
			Setup.初始化单机牌组单位(u, ctx)
		if J.num0(u.get("战意上限")) <= 0.0:
			u["战意上限"] = Params.战意上限()
		Btl.加战意(u, 加, ctx, "回合初")
		u["主武器已销毁"] = false
		u["连续攻击已用"] = false
		u["铁壁护卫中"] = false
		u["机动脱离中"] = false
		Setup.抽专属牌(u, int(Params.专属每回合抽()))
		Setup.派发衍生卡(u, ctx)
	Setup.抽公有牌(ctx, int(Params.公有每回合抽()))
	DeckFlow.阶段初_武器恢复(ctx)
	DeckFlow.阶段初_检查(ctx)
	ctx["上张打出牌"] = null
	RuleHooks.广播("我方阶段初_后", [ctx])
	Btl.重置靶机援护(ctx)
	ctx["阶段"] = Btl.阶段_我方主
	Btl.刷新敌方意图(ctx)
	Btl.pushLog(ctx, "—— 第 %s 回合 · 我方阶段 ——" % J.s(ctx.turn),
		{"类型": "回合", "阶段": Btl.阶段_我方主, "战意加": 加})

static func _AI选牌器() -> Variant:
	if _AI选牌器缓存 == null:
		_AI选牌器缓存 = load("res://core/battle/ai_deck.gd")
	return _AI选牌器缓存

## 我方主阶段结束 → Step A AI 补打 / Step B 敌方行动 / Step C 回合末结算。
static func 结束我方回合(ctx: Dictionary) -> void:
	if ctx == null:
		return
	if ctx.get("result") != null:
		return
	if str(ctx.get("阶段", "")) != Btl.阶段_我方主:
		return
	ctx["阶段"] = Btl.阶段_敌方
	Calc.九死一生_阶段切换(ctx)
	RuleHooks.广播("敌方阶段初", [ctx])
	for s in range(int(Fm.SLOTS())):
		if ctx.get("result") != null:
			return
		var u = Btl._按位单位(Units.livingOf("ally", ctx), s)
		if not (u is Dictionary):
			continue
		if J.truthy(u.get("主武器已销毁")):
			continue
		# 【AI 自动出牌跳过】：隐身中的机体不许 AI 补打。
		if bool(RuleHooks.首个结论("AI自动出牌跳过", [ctx, u]).get("终局", false)):
			continue
		_AI选牌器().auto_play_unit_main_weapon(ctx, u)
	ctx["result"] = Setup.checkResult(ctx)
	if ctx.get("result") != null:
		return
	RuleHooks.广播("我方阶段末", [ctx])
	for s in range(int(Fm.SLOTS())):
		if ctx.get("result") != null:
			break
		var e = Btl._按位单位(Units.livingOf("enemy", ctx), s)
		if not (e is Dictionary):
			continue
		Flow.actOnce(e, ctx)
		Setup.drainAgain(ctx)
		ctx["result"] = Setup.checkResult(ctx)
	if ctx.get("result") != null:
		return
	Setup.endTurn(ctx)
	var 上限 := J.num0(ctx.get("回合上限"))
	if 上限 == 0.0:
		上限 = float(Db.T.MAX_TURN)
	if float(ctx.turn) >= 上限:
		ctx["result"] = {"结果": "败", "原因": "第 %s 回合结束还没分出胜负（按撤退处理）" % J.s(上限)}
		return
	开始我方阶段(ctx)
