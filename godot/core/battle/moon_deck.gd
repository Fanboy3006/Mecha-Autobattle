## 职责：月球王国的【月光牌库】（三层 `SubDeck`）+ 7 张势力牌 + ★【随侍】的抽牌 / 放入。
## 约定：卡表只读 `Db.T.卡包["月球王国"]`；五人的牌与被动在 `MoonUnits`，月相与回合级状态在 `MoonPhase`。
class_name MoonDeck
extends RefCounted

const 势力 := "月球王国"
const 等级键 := "级"
const 抽牌上限 := 6

# ---- 零、卡包与卡表 ----
static func 卡包() -> Dictionary:
	var 包们 = Db.T.get("卡包")
	var 包 = (包们 as Dictionary).get(势力) if 包们 is Dictionary else null
	if not (包 is Dictionary):
		push_error("月球王国卡表没装入：缺 Db.T.卡包[\"%s\"]（见 data/cards/月球王国.json）" % 势力)
		return {}
	return 包

## 动作 → `{"全局": [moon 算子]}`；条目自带 `效果`（声明式）时原样用。
static func 效果组(条目: Dictionary) -> Array:
	if 条目.get("效果") is Array:
		return (条目.效果 as Array).duplicate(true)
	var 表 := {"算子": "moon", "动作": str(条目.get("动作", ""))}
	if 条目.has("月相"):
		表["月相"] = 条目.月相
	return [{"全局": [表]}]

static func _公有底(条目: Dictionary, 支: String) -> Dictionary:
	var 牌 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": "公有牌", "类型": "战术", "层级": "势力", "种类": 支,
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": 支 == "月光", "衍生": false, "入库条件": null, "获取": str(J.or_(条目.get("获取"), "初始")),
		"等级需求": 10, "效果说明": str(条目.get("效果说明", "")), "目标": str(条目.get("目标", "")),
		"随侍": J.truthy(条目.get("随侍")), "随侍放入": str(J.or_(条目.get("随侍放入"), "")),
		"武器牌": false, "连携": false, 等级键: int(J.num0(条目.get(等级键))),
		"每场一次": J.truthy(条目.get("每场一次")), "效果": 效果组(条目),
	}
	if 条目.get("入库条件") is Dictionary:
		牌["入库条件"] = (条目.入库条件 as Dictionary).duplicate(true)
	return 牌

static var _月光表: Array = []
static var _月光代: int = -1
static var _势力表: Array = []
static var _势力代: int = -1

## 月光牌（一级 4 / 二级 3 / 三级 1）。
static func 月光牌们() -> Array:
	if _月光代 != Db.代:
		_月光表 = _构建(卡包().get("月光牌库"), "月光")
		_月光代 = Db.代
	return _月光表

## 势力牌（公有排，只有月球王国成员能打）。
static func 势力牌们() -> Array:
	if _势力代 != Db.代:
		_势力表 = _构建(卡包().get("势力牌"), "势力")
		_势力代 = Db.代
	return _势力表

static func _构建(条目们: Variant, 支: String) -> Array:
	var 表: Array = []
	for 条目 in (条目们 as Array) if 条目们 is Array else []:
		if 条目 is Dictionary:
			表.append(_公有底(条目, 支))
	return 表

## 月光牌的一份**新副本**（库里 / 手里的都是本场自己的实例）。
static func 月光牌(id: Variant) -> Dictionary:
	for c in 月光牌们():
		if str((c as Dictionary).get("id", "")) == str(id):
			return (c as Dictionary).duplicate(true)
	return {}

static func 是月球牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("归属", "")) == 势力 \
		and ["月光", "势力"].has(str((c as Dictionary).get("种类", "")))

static func 是月光牌(c: Variant) -> bool:
	return 是月球牌(c) and str((c as Dictionary).get("种类", "")) == "月光"

# ---- 一、月光牌库（全队一份，开场只有一级牌）----
static func 初始牌库() -> Dictionary:
	var 库 := SubDeck.新建()
	for c in 月光牌们():
		if int((c as Dictionary).get(等级键, 0)) == 1:
			SubDeck.牌们(库).append((c as Dictionary).duplicate(true))
	return 库

static func 初始化(ctx: Dictionary) -> void:
	ctx["月光牌库"] = 初始牌库()
	ctx["月光移出"] = []

static func 库(ctx: Variant) -> Variant:
	return (ctx as Dictionary).get("月光牌库") if ctx is Dictionary else null

static func 移出表(ctx: Dictionary) -> Array:
	if not (ctx.get("月光移出") is Array):
		ctx["月光移出"] = []
	return ctx.月光移出

## 从月光牌库随机抽 1 张进公有手牌（公有手牌满 6 张不抽）。
static func 抽月光牌(ctx: Dictionary) -> Dictionary:
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 抽 := SubDeck.抽一张(库(ctx), ctx.公有手牌, 抽牌上限, ctx.get("rng"))
	if 抽.is_empty():
		Btl.pushLog(ctx, "〔随侍〕公有手牌已满（%d 张）或月光牌库已空 → 这次不抽" % ctx.公有手牌.size(),
			{"类型": "随侍", "抽牌": false})
		return {}
	MoonPhase.状态(ctx)["月光抽牌"] = int(MoonPhase.状态(ctx).get("月光抽牌", 0)) + 1
	Btl.pushLog(ctx, "〔随侍〕从月光牌库抽到【%s】→ 公有手牌" % str(抽.get("名", "")),
		{"类型": "随侍", "抽牌": true, "卡牌": 抽.get("id"), "牌名": 抽.get("名")})
	return 抽

## 放入月光牌库（三级牌每种每场 1 次，由 `SubDeck` 结构化库自带的断路器拦）。
static func 放入(ctx: Dictionary, id: Variant) -> bool:
	var 卡 := 月光牌(id)
	if 卡.is_empty():
		return false
	var 成 := SubDeck.放入(库(ctx), 卡, null, "", 等级键)
	Btl.pushLog(ctx, "〔随侍〕%s【%s】%s月光牌库" % ["把" if 成 else "「放入」被拦下：", str(卡.get("名", "")),
		"放进" if 成 else "不再放进"], {"类型": "月光放入", "卡牌": 卡.get("id"), "放入": 成})
	return 成

static func 各级张数(ctx: Variant) -> Dictionary:
	return SubDeck.各级张数(库(ctx), 等级键)

## ★【随侍】结算：达成 → 抽 1 张月光牌 + 「放入」；返回是否达成（牌面强化由调用方自己做）。
static func 随侍结算(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> bool:
	if not J.truthy(卡.get("随侍")):
		return false
	if not MoonPhase.随侍达成(ctx, u):
		Btl.pushLog(ctx, "〔随侍〕%s 打出【%s】：随侍未达成" % [u.name, str(卡.get("名", ""))],
			J.merged({"类型": "随侍", "触发": false}, Btl.谁(u)))
		return false
	var 状 := MoonPhase.状态(ctx)
	状["随侍触发"] = int(状.get("随侍触发", 0)) + 1
	Btl.pushLog(ctx, "〔随侍〕%s 打出【%s】触发随侍（当前随侍 %d 人）" % [u.name, str(卡.get("名", "")), MoonPhase.随侍数(ctx)],
		J.merged({"类型": "随侍", "触发": true, "卡牌": 卡.get("id")}, Btl.谁(u)))
	抽月光牌(ctx)
	var 放 := str(卡.get("随侍放入", ""))
	if 放 != "" and MoonPhase.随侍数(ctx) >= int(J.or_(卡.get("放入随侍数"), 0)):
		放入(ctx, 放)
	return true

# ---- 二、公有牌打出（`{终局:false}` = 不归我管）----
static func 打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not 是月球牌(卡):
		return {"终局": false}
	if not MoonPhase.是月球王国(u):
		return {"终局": true, "结果": {"成功": false, "原因": "只有月球王国成员能打这张牌"}}
	var 费 := Btl.战意费用(卡)
	if not 是月光牌(卡) and str(Units.unit_class(u, ctx)) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	if Btl.战意(u) < 费:
		return {"终局": true, "结果": {"成功": false, "原因": "战意不足"}}
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	var 摘要 := CardEffects.execute(ctx, 卡)
	ctx["公有手牌"] = J.or_(ctx.get("公有手牌"), []).filter(func(c): return not is_same(c, 卡))
	var 去 := _去处(ctx, 卡)
	Btl.pushLog(ctx, "〔%s〕%s 打出【%s】（战意 -%s，剩 %s；%s）%s" % ["月光牌" if 是月光牌(卡) else "势力牌",
		u.name, str(卡.get("名", "")), J.s(费), J.s(Btl.战意(u)), 去, Btl.效果摘要文(摘要)],
		J.merged({"类型": "月光牌" if 是月光牌(卡) else "势力牌", "势力": 势力, "单位": u.key, "卡牌": 卡.get("id"),
			"牌名": 卡.get("名"), "去处": 去, "战意": u.get("战意"), "效果摘要": 摘要}, Btl.谁(u)))
	DeckFlow.记上张打出牌(ctx, u, 卡)
	Btl.刷新敌方意图(ctx)
	return {"终局": true, "结果": {"成功": true, "卡牌": str(卡.get("名", "")), "去处": 去,
		"战意": Btl.战意(u), "效果摘要": 摘要}}

static func _去处(ctx: Dictionary, 卡: Dictionary) -> String:
	if 是月光牌(卡):
		if J.truthy(卡.get("月球赠牌")):
			return "赠牌用完即弃"
		return "移出本场" if SubDeck.回库或移出(库(ctx), 移出表(ctx), 卡, 等级键, "回库") == "移出" else "回月光牌库"
	if J.truthy(卡.get("每场一次")):
		卡["已用"] = true
		return "每场 1 次，移出本场"
	if not (ctx.get("公有弃牌堆") is Array):
		ctx["公有弃牌堆"] = []
	ctx.公有弃牌堆.append(卡)
	return "进弃牌堆"

## 【卡不可打原因】：月光牌 / 势力牌只有月球王国成员能打。
static func 卡不可打原因(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> Dictionary:
	if not 是月球牌(卡):
		return {"终局": false}
	if not MoonPhase.是月球王国(u):
		return {"终局": true, "原因": "只有月球王国成员能打这张牌"}
	if J.truthy(卡.get("已用")):
		return {"终局": true, "原因": "这一张每场只能用一次"}
	if ["MOON_FAC_4", "MOON_FAC_9"].has(str(卡.get("id", ""))) and MoonPhase.王女(ctx) == null:
		return {"终局": true, "原因": "Feena 不在场"}
	return {"终局": false}

# ---- 三、算子（月光牌 / 势力牌）----
static func 执行算子(运行: Dictionary, 表: Dictionary) -> Array:
	var ctx: Dictionary = 运行.get("ctx") if 运行.get("ctx") is Dictionary else {}
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 打者 = Btl.找单位(ctx, ctx.get("_当前出牌者"), "ally")
	var 友 = 目标友(ctx)
	var 牌名 := str(卡.get("名", ""))
	match str(表.get("动作", "")):
		"月·新月微光":
			if 友 == null:
				return []
			Btl.加战意(友, 10.0, ctx, 牌名)
			return [_记(ctx, 牌名, 友, "战意 +10（现在 %d）" % int(Btl.战意(友)))]
		"月·弦月护佑":
			if 友 == null:
				return []
			var 回 := MoonPhase.治疗(ctx, 打者, 友, 0.08, 1.0)
			return [_记(ctx, 牌名, 友, "回复 %s HP" % J.s(回))]
		"月·月影校射":
			if 友 == null:
				return []
			友["月球下张命中"] = 15.0
			return [_记(ctx, 牌名, 友, "本回合下一张武器牌命中 +15")]
		"月·余响共鸣":
			if 友 == null:
				return []
			友["月球余响共鸣"] = true
			return [_记(ctx, 牌名, 友, "本回合下一次武器攻击后 Feena 追加 700")]
		"月·月面偏导盾":
			if 友 == null:
				return []
			友["月面偏导"] = true
			return [_记(ctx, 牌名, 友, "获得【月面偏导】")]
		"月·引力坍缩":
			var 敌 = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
			if not MoonPhase.活着(敌):
				敌 = Btl._自动目标(ctx, 打者, true) if 打者 is Dictionary else null
			if not MoonPhase.活着(敌):
				return []
			Btl.换同源增益(敌, "引力坍缩", {"def": -20.0, "剩余": 1.0})
			return [_记(ctx, 牌名, 敌, "防御 -20（至下个我方阶段开始）")]
		"月·朔望流转":
			if 友 == null:
				return []
			var 减 := 减一张冷却(友, 1.0)
			var 抽 := Setup.抽专属牌(友, 1)
			return [_记(ctx, 牌名, 友, "%s 冷却 -1；抽 %d 张精神牌" % [减 if 减 != "" else "（没有冷却中的牌）", 抽.size()])]
		"月·月蚀领域":
			var 菲 = MoonPhase.王女(ctx)
			var 盾 := J.round(float(菲.maxHp) * 0.15) if 菲 != null else 0.0
			for a in Units.livingOf("ally", ctx):
				if MoonPhase.是月球王国(a):
					Btl.加战意(a, 15.0, ctx, 牌名)
					if 盾 > 0.0:
						MoonPhase.给护盾(a, 盾)
			MoonPhase.状态(ctx)["领域回合"] = ctx.get("turn")
			return [_记(ctx, 牌名, null, "全体月球王国成员战意 +15、护盾 %s；本回合余响 ×1.5" % J.s(盾))]
	return MoonFaction.执行算子(运行, 表, 打者, 友)

## 指定的月球王国成员（没指定 → 打出者）。
static func 目标友(ctx: Dictionary) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if MoonPhase.活着(t) and MoonPhase.是月球王国(t):
		return t
	var 打者 = Btl.找单位(ctx, ctx.get("_当前出牌者"), "ally")
	return 打者 if MoonPhase.活着(打者) else null

## 一张冷却中的大招（槽 cd 最长）或副武器冷却 −值；返回牌名（没有 = 空串）。
static func 减一张冷却(u: Dictionary, 值: float) -> String:
	var 选: Dictionary = {}
	for 槽 in J.or_(u.get("大招槽"), []) + J.or_(u.get("副武器栏"), []):
		if 槽 is Dictionary and float(槽.get("cd", 0.0)) > float(选.get("cd", 0.0)):
			选 = 槽
	if 选.is_empty():
		return ""
	选["cd"] = maxf(0.0, float(选.cd) - 值)
	return str(((选.get("卡") if 选.get("卡") is Dictionary else {}) as Dictionary).get("名", ""))

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String) -> String:
	var 谁 := {"类型": 势力, "牌名": 牌名}
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	var 行 := "%s%s" % [("%s " % (u as Dictionary).get("name", "")) if u is Dictionary else "", 文]
	Btl.pushLog(ctx, "〔%s〕%s" % [牌名, 行], 谁)
	return 行
