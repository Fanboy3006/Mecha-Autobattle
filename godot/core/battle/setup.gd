## 60-战斗-3-开局与simulate.js：开局、一回合的行动顺序（含压制射击 / 再动）、胜负判定、回合结束。
## 这是 Battle Core 的入口：开局() → 每回合 [打战术牌()…] → 打一回合()，直到 ctx.result 有值。
class_name Setup
extends RefCounted

static func runOverwatch(ally: Dictionary, ctx: Dictionary) -> void:
	# ★ DECK-1：单机牌组模式下「压制射击」彻底不触发（作者 2026-10-17 拍板删除）。
	if Params.单机牌组_开(ctx):
		return
	for e in Units.livingOf("enemy", ctx):
		if not Ai.hasOverwatch(e, ctx) or J.same(e.get("overwatchFiredTurn"), ctx.turn):
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
		# ★ MITH-2：本回合已经用「占行动的战术牌 / 大招牌」动过的角色，不再走普通自动行动
		#   （这就是「打出占行动的牌 = 替代它本回合的普通行动」；只在我方 + 秘银 v0.2 开着时判）
		if u.side == "ally" and Params.秘银v02开(ctx) and int(u.get("actedTurn", -1)) == int(ctx.get("turn", 1)):
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
		# ★ MITH-1 Loop-3 断路器：**回库型**（大招牌化 / 秘银 v0.2）的牌冷却也要在回合结束时走一格，
		#   否则「打出 → 回库」的牌当前冷却永远停在基础值上、再也发不回来。
		#   只在秘银 v0.2 开着时做：关着时一张牌也不动（既有黄金样例的待触发牌冷却逐字不变）。
		if Params.秘银v02开(ctx):
			for c in J.or_(ctx.get("待触发战术牌"), []):
				if c != null and int(c.get("当前冷却", 0)) > 0:
					c["当前冷却"] = int(c["当前冷却"]) - 1
		Btl.检查条件发牌(ctx, "回合结束", {"回合": ctx.turn, "_内部自动": true})

## ======================== 单机牌组（DECK-1）初始化 ========================
## 只在新模式里跑；关着的时候一个字段都不加（黄金样例零改动）。
const 单机牌组_通用精神牌 := [
	{"id": "D_SP_QIHE", "名": "气合", "卡类": "专属精神牌", "层级": "角色", "耗气": 5.0, "回气": 0.0,
		"限次": 99.0, "冷却": 0.0, "效果说明": "自身战意 +10", "单机牌组效果": "回战意", "值": 10.0},
	{"id": "D_SP_JIZHONG", "名": "集中", "卡类": "专属精神牌", "层级": "角色", "耗气": 10.0, "回气": 0.0,
		"限次": 99.0, "冷却": 0.0, "效果说明": "本回合自身命中 +15", "单机牌组效果": "增益",
		"增益": {"hit": 15.0, "剩余": 1.0}},
	{"id": "D_SP_BISHAN", "名": "必闪", "卡类": "专属精神牌", "层级": "角色", "耗气": 10.0, "回气": 0.0,
		"限次": 99.0, "冷却": 0.0, "效果说明": "本回合自身闪避 +20", "单机牌组效果": "增益",
		"增益": {"eva": 20.0, "剩余": 1.0}},
]

## 维修的常驻主武器卡【紧急修理】（fire = heal，走现成的修理管线）
static func 紧急修理武器() -> Dictionary:
	return {
		"name": "紧急修理", "fire": "heal", "power": 1400.0, "hit": 100.0, "critMod": 0.0,
		"stat": "射击", "dmgType": "治疗", "cd": 0.0, "uses": null, "unlock": 1.0,
		"upgrades": [], "ignoreDef": false, "special": null, "range": [1.0, 8.0],
		"desc": "指定我方单体回复大量 HP 并清除负面状态",
	}

## 重装的常驻主武器卡【铁壁护卫】
static func 铁壁护卫武器() -> Dictionary:
	return {
		"name": "铁壁护卫", "fire": "support", "power": 0.0, "hit": 100.0, "critMod": 0.0,
		"stat": "防御", "dmgType": "物理", "cd": 0.0, "uses": null, "unlock": 1.0,
		"upgrades": [], "ignoreDef": false, "special": null, "range": [1.0, 1.0],
		"buff": {"def": 50.0, "受伤Mul": -0.30, "剩余": 1.0},
		"单机牌组_铁壁": true,
		"desc": "本回合防御 +50、受到伤害 -30%、回复 5% HP，并替同列后排挡枪",
	}

static func _保证武器(u: Dictionary, 名: String, 规格: Dictionary) -> void:
	if not (u.get("weapons") is Array):
		u["weapons"] = []
	for e in u.weapons:
		if e is Dictionary and e.get("t") is Dictionary and str(e.t.get("name", "")) == 名:
			return
	u.weapons.append({"t": 规格, "cd": 0.0, "uses": 规格.get("uses"), "readyTurn": 1.0})

static func 初始化单机牌组单位(u: Variant, ctx: Variant = null) -> void:
	if not (u is Dictionary):
		return
	u["战意"] = Params.开场战意()
	u["战意上限"] = Params.战意上限()
	u["主武器已销毁"] = false
	u["连续攻击已用"] = false
	u["铁壁护卫中"] = false
	u["机动脱离中"] = false
	if not (u.get("专属牌库") is Array):
		u["专属牌库"] = []
	if not (u.get("专属手牌") is Array):
		u["专属手牌"] = []
	if not (u.get("专属弃牌堆") is Array):
		u["专属弃牌堆"] = []
	if not (u.get("衍生手牌") is Array):
		u["衍生手牌"] = []
	# 这个函数就是「把一台单位初始化成单机牌组单位」，所以哪怕调用方没传 ctx，
	# 职业映射也按「单机牌组开着」来算（B3 / M5 / M3 自动归【维修】）。
	var 看ctx = ctx
	if not Params.单机牌组_开(看ctx):
		看ctx = {"单机牌组": true}
	var 职业 := Units.unit_class(u, 看ctx)
	if 职业 == Params.单机牌组_维修职业():
		var 标 = u.get("tags")
		if 标 is Dictionary:
			u["tags"] = 标.duplicate(true)
			u.tags["战斗分类"] = 职业
		_保证武器(u, "紧急修理", 紧急修理武器())
	elif 职业 == "重装":
		_保证武器(u, "铁壁护卫", 铁壁护卫武器())

static func _卡属于单位(c: Dictionary, u: Dictionary) -> bool:
	var 键 := Units._键Of(u)
	if 键 == "":
		return false
	if str(c.get("归属", "")) == 键 or str(c.get("角色", "")) == 键:
		return true
	var 角色们 = c.get("角色们")
	return 角色们 is Array and J.inc(角色们, 键)

static func _从专属库抽(u: Dictionary) -> Variant:
	if u.专属牌库.is_empty():
		if u.专属弃牌堆.is_empty():
			return null
		u["专属牌库"] = u.专属弃牌堆.duplicate()
		u["专属弃牌堆"] = []
	if u.专属牌库.is_empty():
		return null
	return u.专属牌库.pop_front()

static func 抽专属牌(u: Dictionary, 张数: int) -> Array:
	var 抽 := []
	if 张数 <= 0:
		return 抽
	for _i in range(张数):
		if u.专属手牌.size() >= int(Params.专属手牌上限()):
			break
		var c = _从专属库抽(u)
		if c == null:
			break
		u.专属手牌.append(c)
		抽.append(c)
	return 抽

static func 抽公有牌(ctx: Dictionary, 张数: int) -> Array:
	var 抽 := []
	if 张数 <= 0 or not (ctx.get("公有牌库") is Array) or not (ctx.get("公有手牌") is Array):
		return 抽
	for _i in range(张数):
		if ctx.公有手牌.size() >= int(Params.公有手牌自然上限()):
			break
		if ctx.公有牌库.is_empty():
			if not (ctx.get("公有弃牌堆") is Array) or ctx.公有弃牌堆.is_empty():
				break
			ctx["公有牌库"] = ctx.公有弃牌堆.duplicate()
			ctx["公有弃牌堆"] = []
		if ctx.公有牌库.is_empty():
			break
		ctx.公有手牌.append(ctx.公有牌库.pop_front())
		抽.append(ctx.公有手牌[ctx.公有手牌.size() - 1])
	return 抽

## 一张衍生攻击 / 支援卡的模板（不落数据表，避免影响旧牌池）
static func 衍生卡模板(名: String, u: Variant = null, ctx: Variant = null) -> Dictionary:
	match 名:
		"援护射击":
			var 威力 := 600.0
			if u is Dictionary:
				威力 = maxf(400.0, J.round(Btl.主武器威力(u) * 0.6))
			return {"id": "D_援护射击", "名": "援护射击", "卡类": "衍生攻击卡", "种类": "援护射击",
				"耗气": 0.0, "归属": "", "威力": 威力, "描述": "0 战意，对一台敌机补枪；不销毁主武器卡"}
		"战术副武":
			return {"id": "D_战术副武", "名": "战术副武", "卡类": "衍生攻击卡", "种类": "战术副武",
				"耗气": 0.0, "归属": "", "描述": "0 战意，打一台敌机并压低其命中；不销毁主武器卡"}
		"应急补丁":
			return {"id": "D_应急补丁", "名": "应急补丁", "卡类": "衍生攻击卡", "种类": "应急补丁",
				"耗气": 0.0, "归属": "", "描述": "0 战意，顺发回复一名队友的 HP"}
	return {"id": "D_%s" % 名, "名": 名, "卡类": "衍生攻击卡", "种类": 名, "耗气": 0.0, "归属": ""}

static func _已有衍生卡(u: Dictionary, 名: String) -> bool:
	for c in u.衍生手牌:
		if c is Dictionary and str(c.get("名", "")) == 名:
			return true
	return false

## 按 7 职业规则派发本回合的初始衍生卡（同一张牌不重复叠加：开局派过、开始我方阶段再叫也只补不叠）
static func 派发衍生卡(u: Variant, ctx: Variant = null) -> Array:
	var 加 := []
	if not (u is Dictionary):
		return 加
	var 职业 := Units.unit_class(u, ctx)
	var 名们 := []
	if 职业 == "狙击":
		名们.append("援护射击")
	elif 职业 == "特种":
		名们.append("战术副武")
	elif 职业 == Params.单机牌组_维修职业():
		名们.append("应急补丁")
	if not (u.get("衍生手牌") is Array):
		u["衍生手牌"] = []
	for 名 in 名们:
		if _已有衍生卡(u, 名):
			continue
		var c := 衍生卡模板(名, u, ctx)
		u.衍生手牌.append(c)
		加.append(c)
	return 加

## 开局初始化：单机战意 / 双排牌库 / 起手抽牌 / 首回合衍生卡 / 敌方意图
## ★ DECK-4：上排 = `DeckBuilder.unit_exclusive_cards(键, lv, ctx)`（Lv10 → Lv20 → Lv30 逐档解锁，
##   倍率随等级抬升）；下排 = 全表公有牌 + 秘银 v0.2 / ATX v0.2 的势力牌（开关关着 = 一张都不加）。
static func 初始化单机牌组(ctx: Dictionary) -> void:
	if not Params.单机牌组_开(ctx):
		return
	ctx["单机牌组"] = true
	ctx["阶段"] = "PLAYER_MAIN"
	ctx["公有牌库"] = []
	ctx["公有手牌"] = []
	ctx["公有弃牌堆"] = []
	var 全表: Array = Db.T.战术卡牌表 if Db.T.战术卡牌表 is Array else []
	var 公有牌们 := 全表.filter(func(c): return c is Dictionary and str(c.get("层级", "")) != "角色")
	# ★ DECK-4：势力扩展卡表（秘银 v0.2 / ATX v0.2）也进下排公有牌库 —— 开关关着 = 一张都不加。
	if Params.秘银v02开(ctx):
		MithrilV02Cards.初始化(ctx)
	if Params.ATXv02开(ctx):
		FacAtx.初始化(ctx)
	for u in ctx.allies:
		初始化单机牌组单位(u, ctx)
		var 库 := []
		var 键 := Units._键Of(u)
		var 等级 := int(J.num0(u.get("lv", 10.0)))
		if 等级 < 10:
			等级 = 10
		for 解锁 in DeckBuilder.unit_exclusive_cards(键, 等级, ctx):
			var 源: Dictionary = 解锁.get("卡") if 解锁.get("卡") is Dictionary else {}
			if 源.is_empty():
				continue
			var 牌: Dictionary = Btl.克隆战术牌(源, ctx)
			# 角色牌是纯增益 / 回战意类 → 标成【专属精神牌】（不销毁主武器卡）；攻击 / 大招牌早就是主武器卡。
			if str(牌.get("卡类", "")) == "":
				牌["卡类"] = "专属精神牌"
			var 倍 := J.num0(解锁.get("倍率"))
			if 倍 > 0.0 and absf(倍 - 1.0) > 0.0001:
				牌 = DeckBuilder.应用等级倍率(牌, 倍)
			牌["等级需求"] = int(解锁.get("等级需求", 10))
			库.append(牌)
		for tpl in 单机牌组_通用精神牌:
			库.append(Btl.克隆战术牌(tpl, ctx))
		u["专属牌库"] = 库
		u["专属手牌"] = []
		u["专属弃牌堆"] = []
		u["衍生手牌"] = []
		抽专属牌(u, int(Params.专属起手()))
	for u in ctx.enemies:
		# 敌方不参与单机牌组，但先把战意字段清掉，免得旧数据里万一有同名键被误读
		if u is Dictionary:
			u.erase("战意")
			u.erase("主武器已销毁")
			u.erase("专属手牌")
			u.erase("衍生手牌")
	for c in 公有牌们:
		ctx.公有牌库.append(Btl.克隆战术牌(c, ctx))
	# ★ DECK-4：秘银 v0.2 / ATX v0.2 的势力牌 → `ctx.公有牌库`（`卡类: "公有牌"`）
	for c in DeckBuilder.公有扩展牌们(ctx):
		var 扩展牌: Dictionary = Btl.克隆战术牌(c, ctx)
		if str(扩展牌.get("卡类", "")) == "":
			扩展牌["卡类"] = "公有牌"
		ctx.公有牌库.append(扩展牌)
	抽公有牌(ctx, int(Params.公有起手()))
	for u in Units.livingOf("ally", ctx):
		派发衍生卡(u, ctx)
	Btl.刷新敌方意图(ctx)
	Btl.pushLog(ctx, "〔单机牌组〕阶段制开启：我方 %d 台各起手 %d 张专属牌、公有起手 %d 张" % [
		ctx.allies.size(), int(Params.专属起手()), int(Params.公有起手())],
		{"类型": "单机牌组", "阶段": "PLAYER_MAIN"})

## 开局。种子按 JS 的 (种子 >>> 0) || 1；选项：波次 / 战术卡牌 / 已选战术牌 / 初始手牌上限 / 含统帅牌 / 补齐基础激励
## / 手牌装填（"JS参考" = 按 JS 参考版装填初始手牌，只给黄金样例对账用；不写 = 正式规则，见已接受差异 D-01）。
static func 开局(我方编成: Array, 敌方编成: Array, 种子: Variant, 单位开关表: Variant = null, 选项: Variant = null) -> Dictionary:
	var 单机开: bool = Params.单机牌组_开({"选项": 选项}) or Params.单机牌组_开(选项) or Params.单机牌组_开(null)
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
	# 秘银 v0.2（MITH-1）/ 大招牌化的玩法开关透传进 ctx.选项：默认两边都不写 → 一个字段都不多
	# （既有黄金样例的 ctx / 事件 / 摘要逐字不变）。写进去了后面 Params.秘银v02开(ctx) 才读得到。
	if 选项 is Dictionary and (选项.has("秘银v02") or 选项.has("大招牌化")):
		ctx.选项 = J.merged(ctx.get("选项"), {
			"秘银v02": J.truthy(选项.get("秘银v02")), "大招牌化": J.truthy(选项.get("大招牌化")),
		})
	# ★ DECK-4：ATX v0.2 卡表的开关也透传（只在**显式写了** `选项.ATXv02` 时才加这个键 ——
	#   没写的时候 `ctx.选项` 一个字节都不多，既有黄金样例逐字不变）。
	if 选项 is Dictionary and 选项.has("ATXv02"):
		ctx.选项 = J.merged(ctx.get("选项"), {"ATXv02": 选项.get("ATXv02")})
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
	# ★ MITH-1：秘银 v0.2 的本回合计数 / 派生牌计数 / 卡牌实例号发号器。开关关着 = 一个字段都不加。
	if Params.秘银v02开(ctx):
		ctx["本回合秘银牌数"] = 0
		ctx["本回合连携触发倍率"] = 1
		ctx["本回合衍生牌生成计数"] = {}
		ctx["_下个卡牌实例号"] = 0   # 0 = 还没发过号；`Btl.克隆战术牌` 见到 0 就把第一张发成 1
	Fac.势力开局(ctx)
	if 选项 is Dictionary and 选项.has("战术卡牌"):
		ctx.选项 = J.merged(ctx.get("选项"), {"战术卡牌": J.truthy(选项.战术卡牌)})
	if Params.战术卡牌开(ctx):
		ctx.战术卡牌开 = true
		var 默气 := J.num(Params.战术卡牌参数().get("初始默认气力"))
		ctx.气势 = 默气 if is_finite(默气) else 25.0
		var 池 := Btl.生成队伍牌池(ctx.allies, J.merged({"补齐基础激励": true}, 选项 if 选项 is Dictionary else {}), ctx)
		ctx.战术牌池 = 池.全部牌池
		ctx.战术手牌 = 池.初始手牌
		ctx.待触发战术牌 = 池.待触发牌
		ctx.候补初始牌 = 池.候补初始牌
		ctx.已打出战术牌 = []
		ctx.战况计数 = {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0, "刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0}
		# ★ MITH-1：两个秘银 v0.2 计数键。**只在开关开着时加** —— 关着的时候一个键都不多，
		#   黄金样例摘要里的 `战况计数` 才不会被多出来的字段顶掉（硬性红线 2）。原有键一个不动。
		if Params.秘银v02开(ctx):
			ctx.战况计数["触发连携"] = 0
			ctx.战况计数["打出TDD1"] = 0
			# ★ MITH-2：v0.2 的四个新计数键（受击 / 击破 / 秘银大招牌）——同样只在开关开着时才加
			ctx.战况计数["秘银受击"] = 0
			ctx.战况计数["宗介受击"] = 0
			ctx.战况计数["克鲁佐击破"] = 0
			ctx.战况计数["打出秘银大招"] = 0
			MithrilV02Cards.初始化(ctx)
		ctx.满手牌推迟记录 = []
	# ★ DECK-1：单机牌组（阶段制）总开关。关着 = 这一段一行都不执行（黄金样例零改动）。
	if 单机开:
		ctx["选项"] = J.merged(ctx.get("选项"), {"单机牌组": true})
		初始化单机牌组(ctx)
	return ctx

static func 打一回合(ctx: Dictionary) -> void:
	# ★ DECK-1：单机牌组模式下「打一回合」= 我方阶段交给 AI 补打 → 敌方阶段 → 下一回合。
	#   关着的时候仍然走原来按速度混排的 runTurn（逐字不变）。
	if Params.单机牌组_开(ctx):
		Btl.结束我方回合(ctx)
		return
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
