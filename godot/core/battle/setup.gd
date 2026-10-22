## 60-战斗-3-开局与simulate.js：开局、一回合的行动顺序、胜负判定、回合结束。
## 这是 Battle Core 的入口：开局() → 每回合 打一回合()，直到 ctx.result 有值。
class_name Setup
extends RefCounted

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
	return Boss.撤离检查(ctx)

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
	for u in ctx.allies:
		u.掩护盾 = 0.0
	Fac.势力回合结束(ctx)

## ======================== 单机牌组（DECK-1）初始化 ========================
## 单机牌组是唯一模式 → 每次开局都跑这一套。
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
	var 职业 := Units.unit_class(u, ctx)
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

## 这台机体是不是**已经走卡牌流转的四区域**（副武器栏存在且装过牌）——
## 有的话旧版衍生卡不再派发（否则会与副武器栏里同名的那张重复）。
static func _有副武器栏(_u: Dictionary, _ctx: Variant = null) -> bool:
	return true

## 按 7 职业规则派发本回合的初始衍生卡（同一张牌不重复叠加：开局派过、开始我方阶段再叫也只补不叠）
static func 派发衍生卡(u: Variant, ctx: Variant = null) -> Array:
	var 加 := []
	if not (u is Dictionary):
		return 加
	var 职业 := Units.unit_class(u, ctx)
	var 名们 := []
	if 职业 == "狙击":
		# ★ 2026-10-21（任务单「战斗UI重构4x4与手牌纯可打与援护连线」问题 1）：
		#   旧版 M3 的通用衍生卡 `D_援护射击` 与卡牌流转 v0.1 的**副武器栏【援护射击】**
		#   （艾克赛琳 `ATX2_D1` / 克鲁兹 `V3_U6_D1`）**同名** → 上排会同时挂两张【援护射击】
		#   （作者反馈「艾克赛琳有多个援护射击」）。卡牌流转开着、或这台机体的副武器栏已经
		#   装过东西时，一律不再派发旧版衍生卡 —— 保证任何一台狙击永远只有 1 张【援护射击】。
		if not _有副武器栏(u, ctx):
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
##   倍率随等级抬升）；下排 = 全表公有牌 + 秘银 v0.2 / ATX v0.2 的势力牌。
static func 初始化单机牌组(ctx: Dictionary) -> void:
	ctx["单机牌组"] = true
	ctx["阶段"] = "PLAYER_MAIN"
	ctx["公有牌库"] = []
	ctx["公有手牌"] = []
	ctx["公有弃牌堆"] = []
	var 全表: Array = Db.T.战术卡牌表 if Db.T.战术卡牌表 is Array else []
	var 公有牌们 := 全表.filter(func(c): return c is Dictionary and str(c.get("层级", "")) != "角色")
	# ★ M2（试玩反馈修复）：卡牌流转开着时，基础表里的公有牌要按**本队在场职业 / 势力**过滤 ——
	#   · `层级 = 职业` 且没人属于该职业 → 不装（秘银五人没有重装，就不塞「铁壁〔需：重装〕」这种永远打不出的牌）；
	#   · `层级 = 势力` 且没人属于该势力 → 不装（ATX 势力牌不进秘银队）；
	#   · 秘银 v0.3 开着 → 基础表里那批旧版 M3 占位职业 / 势力牌（C_* / F_*）整批退场，
	#     只留统帅牌；新版 36 张分类牌与新版势力牌由下面的 `DeckBuilder.公有扩展牌们` 装。
	var 场 := _在场职业与势力(ctx)
	公有牌们 = 公有牌们.filter(func(c): return _基础表公有牌入池吗(ctx, c, 场))
	# ★ DECK-4：势力扩展卡表（秘银 v0.2 / ATX v0.2）也进下排公有牌库。
	# ★ MITH3-2 / MITH3-3：先把全队级状态造好（连携牌库 / 上张打出牌 / 待入库）。
	DeckFlow.初始化(ctx)
	RuleHooks.广播("开局初始化", [ctx])
	FacAtx.初始化(ctx)
	# ★ A3b：筹码牌库（全队一份，开场只有小筹码 4 张）。
	AtxChips.初始化(ctx)
	# ★ A5a：拉米亚的「烟雾」场上状态（`ctx.烟雾`）+ 两个纯读计数。
	AtxSmoke.初始化(ctx)
	# ★ A6b：塔斯克（A6）/ 雷欧娜（A7）的本场计数（`本场被攻击`）与阶段标记。
	AtxDuo.初始化(ctx)
	# ★ CB-1：天人 v0.1 的全队状态（太阳炉牌库 / TRANS-AM 记账 / 拉塞的掩护额度）。
	#   队里没有天人 = 第一行返回（一个字段都不写）。
	CelestialV01.初始化(ctx)
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
		# ★ A6c：响介 / 艾克赛琳 / 拉米亚的 v0.1 卡表（**只装「初始」档**）追加到牌库**末尾** ——
		#   起手抽牌从队头抽，既有牌的顺序与张数因此一个字节都不变。
		#   ★ A6d：子开关收口成「跟随主开关 `单机牌组_开`」（作者会在 ATX 五人快速战斗里验这套牌）。
		#   同一张牌（id 相同，例如复用的 `U_ATX_2` 赌神·入局 / `U_ATX_8` 烟雾弹）**只装一次**。
		var 已有id := {}
		for c in 库:
			if c is Dictionary:
				已有id[str((c as Dictionary).get("id", ""))] = true
		for c in AtxThree.装填单位(u, 等级, ctx):
			if c is Dictionary and 已有id.has(str((c as Dictionary).get("id", ""))):
				continue
			库.append(c)
		# ★ CB-1：拉塞 CB5 的 7 张（主武器 3 / 大招 1 / 精神 3）；Lv20 起装 `+` 版。
		#   其余天人成员这一批没有专属牌（四名驾驶员的卡池在 Batch 2 的 CB-2）。
		for c in CelestialV01.装填单位(u, 等级, ctx):
			if c is Dictionary and 已有id.has(str((c as Dictionary).get("id", ""))):
				continue
			库.append(c)
		# 势力 / 职业模块自己的专属牌走 `RuleHooks.装填单位`（内核只认钩子，不点名模块）。
		for c in RuleHooks.收集("装填单位", [u, 等级, ctx]):
			if c is Dictionary and 已有id.has(str((c as Dictionary).get("id", ""))):
				continue
			库.append(c)
		u["专属牌库"] = 库
		u["专属手牌"] = []
		u["专属弃牌堆"] = []
		u["衍生手牌"] = []
		# ★ MITH3-2：把牌分进四个区域（武器栏 / 副武器栏 / 大招槽 / 待入库），大招槽**不进抽牌堆**。
		DeckFlow.拆分单位牌(u, ctx)
		# ★ 第 5 项断路器修复（DS41F）：响介 / 艾克赛琳 / 拉米亚的 v0.1 **大招槽**按等级解锁
		#   （lv ≥ 10 初始大招 / lv ≥ 20 晋升大招 / lv ≥ 30 Lv30 晋升大招）。槽条目是 `v01别名`：
		#   状态真源仍是 `v01冷却`，`DeckFlow` 的两个大招口子见到别名槽直接转交 `AtxThree`。
		AtxThree.装填大招槽(ctx, u, 等级)
		# ★ CB-1：四名高达驾驶员各装一张 `TRANS-AM·启动`（大招槽卡，绝不进抽牌堆）。
		#   已经有一份 = 幂等跳过；`ctx.禁止TRANSAM入场` 为真时不装。
		CelestialV01.装填大招槽(ctx, u)
		# 势力模块自己的入场牌（觉醒入场牌等）走同一个钩子。
		RuleHooks.广播("装填大招槽", [ctx, u])
		抽专属牌(u, int(Params.专属起手()))
	# ★ A4：「赌神·入局」放进响介的大招槽。卡牌流转开着时 `拆分单位牌` 已经按 `卡类 = 大招槽卡`
	#   放好了（这里幂等跳过）；关着时由这里补上 —— 赌神只挂 `单机牌组_开`，不依赖卡牌流转。
	AtxGodsbet.装填大招槽(ctx)
	# ★ 第 3 项断路器修复（DS41F）：合体技【轮盘双响】按 v0.3 §4 归位到**大招槽** ——
	#   响介（A1）与艾克赛琳（A2）同时在场时，两人的大招槽各装一份（共用状态，冷却 5、各付 15）。
	#   同时把这张牌从两人的 `专属牌库 / 专属手牌 / 专属弃牌堆 / 待入库` 里摘掉（绝不两边各留一份）。
	AtxFaction.装填轮盘双响(ctx)
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
	# ★ MITH3-2：带入库条件的公有牌先进 `ctx.公有待入库`，条件满足时 push_front 到公有牌库顶
	DeckFlow.初始化公有待入库(ctx)
	抽公有牌(ctx, int(Params.公有起手()))
	# ★ M1（试玩反馈修复）：快速测试的起手连携体验保证（只在 `选项.快速测试` 时进）
	if J.truthy(J.g(ctx.get("选项"), "快速测试")):
		_保证快速测试起手连携(ctx)
	for u in Units.livingOf("ally", ctx):
		派发衍生卡(u, ctx)
	Btl.刷新敌方意图(ctx)
	Btl.pushLog(ctx, "〔单机牌组〕阶段制开启：我方 %d 台各起手 %d 张专属牌、公有起手 %d 张" % [
		ctx.allies.size(), int(Params.专属起手()), int(Params.公有起手())],
		{"类型": "单机牌组", "阶段": "PLAYER_MAIN"})

# ==========================================================================================
# ★ M2：公有牌池的过滤口径（`Setup.初始化单机牌组` / `DeckBuilder.公有扩展牌们` 共用同一份）
# ==========================================================================================
## 本期在场队伍的**职业集合**与**势力集合**（含副势力；只看活着的机体）。
static func _在场职业与势力(ctx: Variant) -> Dictionary:
	var 职业 := {}
	var 势力 := {}
	if not (ctx is Dictionary):
		return {"职业": 职业, "势力": 势力}
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if not (u is Dictionary):
			continue
		if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 类 := Units.unit_class(u, ctx)
		if 类 != "":
			职业[类] = true
		for 势 in Units.势力们(u):
			势力[str(势)] = true
	return {"职业": 职业, "势力": 势力}

## 这张公有牌该不该进下排牌池（`场` = `_在场职业与势力(ctx)`）。
##   · `层级 = 统帅` → 谁都打得出，一律留；
##   · `层级 = 职业` → 本队在场没人属于该职业就不装（秘银五人没有重装 → 不塞重装牌）；
##   · `层级 = 势力` → 本队在场没人属于该势力就不装（ATX 势力牌不进秘银队）。
## 这一份口径对**基础表**与**扩展牌表**（`DeckBuilder.公有扩展牌们`）是同一份。
static func _公有牌入池吗(_ctx: Variant, c: Variant, 场: Dictionary) -> bool:
	if not (c is Dictionary):
		return false
	var d: Dictionary = c
	var 层 := str(d.get("层级", ""))
	if 层 == "统帅":
		return true
	var 归 := str(d.get("归属", ""))
	var 职: Dictionary = 场.get("职业", {})
	var 势: Dictionary = 场.get("势力", {})
	if 层 == "职业":
		return 职.has(归)
	if 层 == "势力":
		return 势.has(归)
	return true

## ★ M2：**基础表**（`Db.T.战术卡牌表`）额外的一道口径 —— 秘银 v0.3 开着时，那批旧版 M3 占位
## 职业 / 势力牌（`C_GUARD_*` / `C_VANG_*` / `C_SNIPE_*` / `C_SPEC_*` / `C_CMD_*` / `C_HEAVY_*` /
## `F_MITH_*` / `F_ATX_*` / 其余 `F_*`）整批退场：只留**统帅牌**，新版 36 张分类牌与新版势力牌
## 由 `DeckBuilder.公有扩展牌们` 装（不然下排会同时挂着「旧占位 + 新版」两套同义牌）。
static func _基础表公有牌入池吗(_ctx: Variant, c: Variant, _场: Dictionary) -> bool:
	if not (c is Dictionary):
		return false
	return str((c as Dictionary).get("层级", "")) == "统帅"

## 这张公有牌**是不是秘银牌**（下排起手连携体验的判据：秘银势力牌 / 连携牌）。
static func 是秘银公有牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	var d: Dictionary = c
	if str(d.get("种类", "")) == "连携":
		return true
	return str(d.get("归属", "")) == MithrilV03Cards.势力

# ==========================================================================================
# ★ M1（试玩反馈修复）：「快速测试」两入口的起手连携体验保证
# ==========================================================================================
## 快速测试（`选项.快速测试 = true`）下，装填完牌组后补两件事，让玩家**第 1 回合**就能直观看到〔连携〕：
##   ① 毛（`U2`）的 `专属手牌` 里一定有【呼叫达纳号】（`V3_U2_S1`：带连携 + 把 TDD-1 放进公有手牌）；
##   ② `ctx.公有手牌` 起手 3 张里至少有 1 张秘银牌（`V3_F_*` 势力牌）。
## 两条都**只在缺的时候**动手（已经有了 = 一个字节都不改）；正常肉鸽起手 / 老口径快速战斗不经过这里。
static func _保证快速测试起手连携(ctx: Dictionary) -> void:
	var 毛 := {}
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == "U2":
			毛 = u
	if not 毛.is_empty():
		_把手牌换进来(毛, "V3_U2_S1")
	for c in J.or_(ctx.get("公有手牌"), []):
		if 是秘银公有牌(c):
			return
	# 公有起手里没有秘银牌 → 从公有牌库里挑一张换进来（牌库顶那张作废回牌库顶，手牌张数不变）
	var 库: Array = J.or_(ctx.get("公有牌库"), [])
	for i in 库.size():
		var c: Variant = 库[i]
		if not 是秘银公有牌(c):
			continue
		var 手: Array = J.or_(ctx.get("公有手牌"), [])
		库.remove_at(i)
		if 手.is_empty():
			手.append(c)
		else:
			var 出: Variant = 手.pop_back()
			库.push_front(出)
			手.append(c)
		ctx["公有手牌"] = 手
		ctx["公有牌库"] = 库
		Btl.pushLog(ctx, "〔快速测试〕起手换入秘银牌【%s】（第 1 回合就能试〔连携〕）" % str((c as Dictionary).get("名", "")),
			{"类型": "起手换牌", "卡牌ID": (c as Dictionary).get("id"), "公有": true})
		return

## 把 `id` 那张牌从 `u.专属牌库` 换进 `u.专属手牌`（已经在手里 = 什么都不做）。
## 手牌满时把手里最后一张换回牌库顶 —— 张数守恒，绝不静默烧牌。
static func _把手牌换进来(u: Dictionary, id: String) -> bool:
	var 手: Array = J.or_(u.get("专属手牌"), [])
	for c in 手:
		if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
			return true
	var 库: Array = J.or_(u.get("专属牌库"), [])
	var 序 := -1
	for i in 库.size():
		var c: Variant = 库[i]
		if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
			序 = i
			break
	if 序 < 0:
		return false
	var 卡: Variant = 库[序]
	库.remove_at(序)
	if 手.size() >= int(Params.专属手牌上限()) and not 手.is_empty():
		var 出: Variant = 手.pop_back()
		库.push_front(出)
	手.append(卡)
	u["专属手牌"] = 手
	u["专属牌库"] = 库
	return true

## 开局。种子按 JS 的 (种子 >>> 0) || 1；选项：波次 / 战术卡牌 / 已选战术牌 / 初始手牌上限 / 含统帅牌 / 补齐基础激励。
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
		"当前战术": null,
		"log": [], "_rng_at": [], "result": null, "again": [],
		"波次": 波次,
	}
	# ★ DECK-4：ATX v0.2 卡表的开关也透传（只在**显式写了** `选项.ATXv02` 时才加这个键 ——
	#   没写的时候 `ctx.选项` 就多不出这个键）。
	if 选项 is Dictionary:
		var 传ATX := {}
		# ★ 第 5 项断路器修复（DS41F）：`快速测试` / `全卡池体验` 也要透传进 `ctx.选项` ——
		#   否则 `AtxThree.全卡池体验(ctx)` 永远读不到（`Setup.开局` 只认白名单里的键）。
		for k in ["快速测试", "全卡池体验"]:
			if 选项.has(k):
				传ATX[k] = 选项.get(k)
		if not 传ATX.is_empty():
			ctx.选项 = J.merged(ctx.get("选项"), 传ATX)
	# ★ MITH3：规则 v0.3 的开关（秘银 v0.3 / 卡牌流转 / 武器范围）也透传进 `ctx.选项` ——
	#   只在**显式写了**这几个键时才加（没写 = 一个字段都不多，`Params.*v03开` 一律 false）。
	if 选项 is Dictionary:
		var 传 := {}
		for k in ["秘银v03", "卡牌流转", "武器范围", "规则v03", "QTE结果", "月球v02", "影世界v02", "势力手感v01", "集火破绽"]:
			if 选项.has(k):
				传[k] = 选项.get(k)
		if not 传.is_empty():
			ctx.选项 = J.merged(ctx.get("选项"), 传)
	# 藏品（93-藏品.js 的「开战应用」段）：**与 JS 同一时机** —— ctx 造好后、应用全场词条之前
	# （60-战斗-3-开局与simulate.js:131 → 134）。藏品 id 数组从 `选项.藏品` 来（DEBT-06：不读全局 `肉鸽.RUN`）；
	# 不传 / 空数组 → 立刻返回，一个字段都不动。
	RelicBattle.apply_on_battle_start(ctx, J.or_(选项.get("藏品") if 选项 is Dictionary else null, []))
	Btl.应用全场词条(ctx)
	for u in Units.livingUnits(ctx):
		u.weapons = (u.weapons as Array).map(func(e): return J.merged(e, {"cd": 0.0}))
		u.holdUlt = false
		u.掩护盾 = 0.0
	Btl.设单位开关(ctx, 单位开关表)
	Btl.pushLog(ctx, "战斗开始：我方 %d 台 vs 敌方 %d 台" % [ctx.allies.size(), ctx.enemies.size()], {"类型": "开始"})
	Fac.势力开局(ctx)
	# 战况计数：键集合固定（`满手牌推迟数` 保留键、恒为 0，模型层照旧读得到）。
	ctx.战况计数 = {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0, "刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0}
	ctx["选项"] = J.merged(ctx.get("选项"), {"单机牌组": true})
	初始化单机牌组(ctx)
	return ctx

static func 打一回合(ctx: Dictionary) -> void:
	Btl.结束我方回合(ctx)

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
