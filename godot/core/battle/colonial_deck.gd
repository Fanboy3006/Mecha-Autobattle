## 职责：殖民卫星军的感应牌库（11 张，`SubDeck` 结构化库）+ 9 张势力牌 + 【觉醒感应】的抽牌 / 放入。
## 约定：卡表只读 `Db.T.卡包["殖民卫星军"]`；本文件不认识五人的独有机制（那些在 `ColonialUnits`）。
class_name ColonialDeck
extends RefCounted

const 势力 := "殖民卫星军"
const 等级键 := "级"
## 公有手牌满这么多张时，「感应」不抽牌（「放入」照常生效）。
const 感应抽牌上限 := 6

# ---- 零、卡包与卡表 ----
static func 卡包() -> Dictionary:
	var 包们 = Db.T.get("卡包")
	var 包 = (包们 as Dictionary).get(势力) if 包们 is Dictionary else null
	if not (包 is Dictionary):
		push_error("殖民卫星军卡表没装入：缺 Db.T.卡包[\"%s\"]（见 session/data_loader.gd 与 data/cards/殖民卫星军.json）" % 势力)
		return {}
	return 包

static func _并(底: Dictionary, 盖: Dictionary) -> Dictionary:
	var 出 := 底.duplicate(true)
	for k in 盖.keys():
		出[k] = 盖[k]
	return 出

## 感应牌 / 势力牌共用的底（`卡类 = 公有牌`、`层级 = 势力`、`归属 = 殖民卫星军`）。
static func _公有底(条目: Dictionary, 支: String) -> Dictionary:
	var 动作 := str(条目.get("动作", ""))
	var 选 := "enemy" if str(条目.get("目标", "")) == "敌机" else "ally"
	var 牌 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": "公有牌", "类型": "战术", "层级": "势力", "种类": 支,
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": true, "衍生": false, "入库条件": null, "获取": str(J.or_(条目.get("获取"), "初始")),
		"等级需求": int(J.num0(条目.get("等级需求"))),
		"效果说明": str(条目.get("效果说明", "")), "目标": str(条目.get("目标", "")),
		"觉醒感应": J.truthy(条目.get("觉醒感应")),
		"感应放入": str(J.or_(条目.get("感应放入"), "")),
		"武器牌": false, "连携": false,
		"级": int(J.num0(条目.get("感应等级"))),
		"效果": [{"选": {"方": 选}, "效果": [{"算子": "colonial", "动作": 动作}]}],
	}
	if 牌["等级需求"] <= 0:
		牌["等级需求"] = 10
	for k in 条目.keys():
		if k in ["id", "名", "动作", "耗气", "目标", "效果说明", "觉醒感应", "感应放入", "获取", "等级需求"]:
			continue
		if k == "入库条件" and 条目[k] is Dictionary:
			牌["入库条件"] = 条目[k].duplicate(true)
		elif 条目[k] is Array or 条目[k] is Dictionary:
			牌[k] = 条目[k].duplicate(true)
		else:
			牌[k] = 条目[k]
	return 牌

static var _感应表: Array = []
static var _感应代: int = -1
static var _势力表: Array = []
static var _势力代: int = -1

## 11 张感应牌（一级 4 / 二级 4 / 三级 3）。
static func 感应牌们() -> Array:
	if _感应代 != Db.代:
		_感应表 = _构建((卡包().get("感应牌库") as Array) if 卡包().get("感应牌库") is Array else [], "感应")
		_感应代 = Db.代
	return _感应表

## 9 张势力牌（公有排，只有殖民卫星军成员能打）。
static func 势力牌们() -> Array:
	if _势力代 != Db.代:
		_势力表 = _构建((卡包().get("势力牌") as Array) if 卡包().get("势力牌") is Array else [], "势力")
		_势力代 = Db.代
	return _势力表

static func _构建(条目们: Array, 支: String) -> Array:
	var 表: Array = []
	for 条目 in 条目们:
		if not (条目 is Dictionary):
			continue
		表.append(_公有底(条目, 支))
	return 表

static func 感应牌(id: Variant) -> Dictionary:
	for c in 感应牌们():
		if str((c as Dictionary).get("id", "")) == str(id):
			return c
	return {}

## 这张牌是不是殖民卫星军的公有牌（感应牌 / 势力牌）。
static func 是殖民卫星军牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return str((c as Dictionary).get("归属", "")) == 势力 \
		and ["感应", "势力"].has(str((c as Dictionary).get("种类", "")))

static func 是感应牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("种类", "")) == "感应"

static func 是势力牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("种类", "")) == "势力"

## 公有扩展牌：队里有殖民卫星军成员时，把 9 张势力牌装进下排公有牌库。
static func 公有扩展牌(ctx: Variant) -> Array:
	if not (ctx is Dictionary):
		return 势力牌们()
	if not ColonialV01.有成员(ctx):
		return []
	return 势力牌们()

# ---- 一、感应牌库（`SubDeck.新建()`；全队一份，开场只有一级牌）----
static func 初始牌库() -> Dictionary:
	var 库 := SubDeck.新建()
	for c in 感应牌们():
		if int(J.num0((c as Dictionary).get("感应等级"))) == 1:
			SubDeck.牌们(库).append(c)
	return 库

static func 初始化(ctx: Dictionary) -> void:
	ctx["感应牌库"] = 初始牌库()
	ctx["感应移出"] = []
	ctx["本场有人觉醒过"] = false

static func 库(ctx: Variant) -> Variant:
	return (ctx as Dictionary).get("感应牌库") if ctx is Dictionary else null

static func 移出表(ctx: Variant) -> Array:
	if not (ctx is Dictionary):
		return []
	if not ((ctx as Dictionary).get("感应移出") is Array):
		(ctx as Dictionary)["感应移出"] = []
	return (ctx as Dictionary).感应移出

## 从感应牌库抽 1 张放进公有手牌（满 6 张不抽）。返回抽到的牌。
static func 抽感应牌(ctx: Dictionary) -> Dictionary:
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 上 := int(Params.公有手牌自然上限())
	if 上 <= 0:
		上 = 感应抽牌上限
	var 抽 := SubDeck.抽一张(库(ctx), ctx.公有手牌, 上, ctx.get("rng"))
	if 抽.is_empty():
		Btl.pushLog(ctx, "〔觉醒感应〕公有手牌已满（%d 张）或感应牌库已空 → 这次不抽" % ctx.公有手牌.size(),
			{"类型": "觉醒感应", "抽牌": false})
		return {}
	Btl.pushLog(ctx, "〔觉醒感应〕从感应牌库抽到【%s】→ 公有手牌" % str(抽.get("名", "")),
		{"类型": "觉醒感应", "抽牌": true, "卡牌": 抽.get("id"), "牌名": 抽.get("名")})
	return 抽

## 把一张感应牌放进感应牌库（本场有效）；三级牌每种每场最多放入 1 次（`SubDeck` 断路器 1）。
static func 放入感应牌(ctx: Dictionary, id: Variant) -> bool:
	var 卡 := 感应牌(id)
	if 卡.is_empty():
		return false
	var 成 := SubDeck.放入(库(ctx), 卡, null, "", 等级键)
	Btl.pushLog(ctx, "〔觉醒感应〕%s【%s】%s感应牌库" % [("把" if 成 else "「放入」被拦下："),
		str(卡.get("名", "")), ("放进" if 成 else "不放进")],
		{"类型": "感应放入", "卡牌": 卡.get("id"), "放入": 成})
	return 成

## 感应牌打出后归哪儿：一 / 二级回库，三级移出本场（`SubDeck` 口径）。
static func 回库或移出(ctx: Dictionary, 卡: Dictionary) -> String:
	var 去 := SubDeck.回库或移出(库(ctx), 移出表(ctx), 卡, 等级键, "回库")
	if 去 == "移出":
		Btl.pushLog(ctx, "〔感应牌〕【%s】打出后移出本场" % str(卡.get("名", "")),
			{"类型": "感应移出", "卡牌": 卡.get("id")})
	elif 去 == "回库":
		Btl.pushLog(ctx, "〔感应牌〕【%s】打出后回感应牌库" % str(卡.get("名", "")),
			{"类型": "感应回库", "卡牌": 卡.get("id")})
	return 去

static func 各级张数(ctx: Variant) -> Dictionary:
	return SubDeck.各级张数(库(ctx), 等级键)

static func 感应牌库明细(ctx: Variant) -> Array:
	var 出: Array = []
	for c in SubDeck.牌们(库(ctx)):
		if c is Dictionary:
			出.append({"id": c.get("id"), "名": c.get("名"), "级": int(J.num0(c.get("级")))})
	return 出

## 本场已经移出的三级感应牌（明细面板的「移出」那一栏）。
static func 感应移出明细(ctx: Variant) -> Array:
	var 出: Array = []
	for c in 移出表(ctx):
		if c is Dictionary:
			出.append({"id": c.get("id"), "名": c.get("名"), "级": int(J.num0(c.get("级")))})
	return 出

static func 感应牌库左栏文(ctx: Variant) -> String:
	var 计 := 各级张数(ctx)
	return "感应牌库：一级 %d · 二级 %d · 三级 %d（移出 %d）" % [
		int(计["一级"]), int(计["二级"]), int(计["三级"]), 移出表(ctx).size()]

# ---- 二、【觉醒感应】触发（打出那一刻看**打出者**是否在觉醒中）----
static func 触发觉醒感应(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> void:
	if not J.truthy(卡.get("觉醒感应")):
		return
	if ColonialAwaken.觉醒中(u):
		Btl.pushLog(ctx, "〔觉醒感应〕%s 正在觉醒中 → 这一张不感应" % str(u.get("name", "")),
			J.merged({"类型": "觉醒感应", "触发": false}, Btl.谁(u)))
		return
	抽感应牌(ctx)
	var 放 := str(卡.get("感应放入", ""))
	if 放 != "":
		放入感应牌(ctx, 放)

# ---- 三、公有牌打出的入口（由 `ColonialV01.公有牌打出` 转发；`{终局:false}` = 不归我管）----
static func 打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not 是殖民卫星军牌(卡):
		return {"终局": false}
	if not ColonialAwaken.是殖民卫星军(u):
		return {"终局": true, "结果": {"成功": false, "原因": "只有殖民卫星军成员能打这张牌"}}
	if 是感应牌(卡):
		return {"终局": true, "结果": 打出感应牌(ctx, u, 卡, target_id)}
	return {"终局": true, "结果": 打出势力牌(ctx, u, 卡, target_id)}

static func 打出感应牌(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	var 摘要 := CardEffects.execute(ctx, 卡)
	_离手(ctx, 卡)
	var 去 := 回库或移出(ctx, 卡)
	Btl.pushLog(ctx, "〔感应牌〕%s 打出【%s】（0 费、不占武器；%s）%s" % [str(u.get("name", "")),
		str(卡.get("名", "")), "移出本场" if 去 == "移出" else "回库", Btl.效果摘要文(摘要)],
		J.merged({"类型": "感应牌", "单位": u.key, "卡牌": 卡.get("id"), "牌名": 卡.get("名"),
			"去处": 去, "效果摘要": 摘要}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "感应牌": true, "去处": 去,
		"效果摘要": 摘要, "战意": J.num0(u.get("战意"))}

static func 打出势力牌(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	var 费 := Btl.战意费用(卡)
	# ★ COL-5：指挥机打公有牌「战意 -5」—— 与 `CardPlay.不可打原因` / 通用公有牌那条路同一口径
	#   （从前这里只判原价，于是界面说「能打」、点下去回「战意不足」）。
	if str(Units.unit_class(u, ctx)) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	if Btl.战意(u) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	触发觉醒感应(ctx, u, 卡)
	var 摘要 := CardEffects.execute(ctx, 卡)
	_离手(ctx, 卡)
	ctx["公有弃牌堆"].append(卡)
	Btl.pushLog(ctx, "〔势力牌〕%s 打出【%s】（战意 -%s，剩 %s）%s" % [str(u.get("name", "")),
		str(卡.get("名", "")), J.s(费), J.s(J.num0(u.get("战意"))), Btl.效果摘要文(摘要)],
		J.merged({"类型": "势力牌", "势力": 势力, "单位": u.key, "卡牌": 卡.get("id"),
			"牌名": 卡.get("名"), "战意": u.get("战意"), "效果摘要": 摘要}, Btl.谁(u)))
	AtxLuck.打出时(ctx, u, 卡)
	DeckFlow.记上张打出牌(ctx, u, 卡)
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "势力牌": true, "战意": J.num0(u.get("战意")),
		"效果摘要": 摘要}

static func _离手(ctx: Dictionary, 卡: Dictionary) -> void:
	ctx["公有手牌"] = J.or_(ctx.get("公有手牌"), []).filter(func(c): return not is_same(c, 卡))

# ---- 四、算子（`CardEffects` 的 `"colonial"` 分支转进来）----
static func 执行算子(_名: String, 运行: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	var ctx: Dictionary = 运行.get("ctx") if 运行.get("ctx") is Dictionary else {}
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 动作 := str(表.get("动作", ""))
	var 目标 = _友(ctx, 目标们)
	var 敌 = _敌(ctx, 目标们)
	var 牌名 := str(卡.get("名", ""))
	match 动作:
		"推进剂":
			if 目标 == null:
				return []
			Btl.加战意(目标, 10.0, ctx, "推进剂")
			_记(ctx, 牌名, 目标, "战意 +10（现在 %d）" % int(Btl.战意(目标)))
			return ["战意 +10 → %s" % _名(目标)]
		"同步":
			if 目标 == null:
				return []
			var 槽 := ColonialAwaken.入场槽(目标, _觉醒类型Of(目标))
			if 槽.is_empty():
				return ["%s 没有可减冷却的觉醒入场牌" % _名(目标)]
			槽["cd"] = maxf(0.0, float(槽.get("cd", 0.0)) - 1.0)
			_记(ctx, 牌名, 目标, "觉醒入场牌冷却 −1（剩 %d）" % int(槽.get("cd", 0.0)))
			return ["觉醒入场牌冷却 −1 → %s" % _名(目标)]
		"预感":
			if 目标 == null:
				return []
			Btl.换同源增益(目标, "预感", {"eva": 15.0, "剩余": 1.0})
			_记(ctx, 牌名, 目标, "到下个我方阶段前闪避 +15")
			return ["闪避 +15 → %s" % _名(目标)]
		"共感":
			if 目标 == null:
				return []
			目标["下张武器"] = {"命中": 15.0, "暴击": 15.0}
			_记(ctx, 牌名, 目标, "本回合下一张武器牌命中 +15、暴击 +15")
			return ["下一张武器牌 命中 +15 / 暴击 +15 → %s" % _名(目标)]
		"觉醒连锁":
			if 目标 == null:
				return []
			目标["本回合无视觉醒战意门槛"] = true
			_记(ctx, 牌名, 目标, "本回合觉醒入场牌无视战意门槛")
			return ["觉醒入场牌无视战意门槛 → %s" % _名(目标)]
		"超频":
			if 目标 == null:
				return []
			目标["本回合觉醒大招降费"] = int(J.num0(目标.get("本回合觉醒大招降费"))) + 10
			_记(ctx, 牌名, 目标, "本回合下一张觉醒大招费用 −10")
			return ["觉醒大招 −10 费 → %s" % _名(目标)]
		"死神影子":
			if 敌 == null:
				return []
			敌["本回合下次受击必暴"] = true
			_记(ctx, 牌名, 敌, "本回合我方对它的下一次攻击必定暴击")
			return ["下次受击必暴 → %s" % _名(敌)]
		"零的预见":
			if 目标 == null:
				return []
			目标["零的预见层数"] = 1.0
			_记(ctx, 牌名, 目标, "到下个我方阶段前第一次被攻击整次打空")
			return ["零的预见 → %s" % _名(目标)]
		"强制觉醒":
			if 目标 == null:
				return []
			目标["本回合强制觉醒"] = true
			_记(ctx, 牌名, 目标, "本回合觉醒入场牌无视全部亮起条件、费用 0")
			return ["强制觉醒 → %s" % _名(目标)]
		"极限超频":
			if 目标 == null or not ColonialAwaken.觉醒中(目标):
				return ["极限超频要指定一台觉醒中的成员"]
			目标["本回合极限超频"] = true
			_记(ctx, 牌名, 目标, "本回合觉醒大招费用 0、QTE 视为完美")
			return ["极限超频 → %s" % _名(目标)]
		"感应风暴":
			var 台 := 0
			for a in J.or_(ctx.get("allies"), []):
				if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and ColonialAwaken.觉醒中(a):
					for 槽2 in ColonialAwaken.觉醒大招槽们(a):
						槽2["cd"] = 0.0
						台 += 1
			_记(ctx, 牌名, null, "本回合所有觉醒中成员的大招冷却清零（%d 张）" % 台)
			return ["清 %d 张觉醒大招冷却" % 台]
		"抽公有":
			var 抽 := Setup.抽公有牌(ctx, 1)
			_记(ctx, 牌名, null, "抽 1 张公有牌%s" % ("" if 抽.is_empty() else "：【%s】" % str((抽[0] as Dictionary).get("名", ""))))
			return ["抽 1 张公有牌"]
		"歌声":
			if 目标 == null:
				return []
			Btl.加战意(目标, 10.0, ctx, "歌声")
			_记(ctx, 牌名, 目标, "战意 +10（现在 %d）" % int(Btl.战意(目标)))
			return ["战意 +10 → %s" % _名(目标)]
		"接应":
			var 打者 = _施放者(ctx)
			if 打者 == null:
				return []
			打者["下张武器"] = {"命中": 15.0, "暴击": 0.0}
			_记(ctx, 牌名, 打者, "下一张武器牌命中 +15")
			return ["下一张武器牌命中 +15 → %s" % _名(打者)]
		"正规军掩护":
			if 目标 == null or not ColonialAwaken.觉醒中(目标):
				return ["正规军掩护要指定一台觉醒中的成员"]
			var 打者2 = _施放者(ctx)
			if 打者2 == null or ColonialAwaken.觉醒中(打者2):
				return ["正规军掩护只能由没在觉醒中的成员打出"]
			目标["正规军掩护"] = {"打出者": str((打者2 as Dictionary).get("key", "")), "回合": float(ctx.get("turn", 1.0))}
			_记(ctx, 牌名, 目标, "到下个我方阶段前受到伤害 −30%%，减掉的部分由 %s 承受" % _名(打者2))
			return ["掩护 30%% → %s（由 %s 承受）" % [_名(目标), _名(打者2)]]
		"背水":
			if 目标 == null:
				return []
			目标["本回合无视觉醒战意门槛"] = true
			_记(ctx, 牌名, 目标, "本回合觉醒入场牌无视战意门槛")
			return ["背水：觉醒入场牌无视战意门槛 → %s" % _名(目标)]
		"不杀":
			var 打者3 = _施放者(ctx)
			if 打者3 == null:
				return []
			打者3["本回合不杀"] = true
			_记(ctx, 牌名, 打者3, "本回合下一次攻击会击破目标时改为保留 1 HP，并让它下个敌方阶段不能攻击")
			return ["不杀：这一回合留手 → %s" % _名(打者3)]
		"塔莉亚指挥":
			var 减 := _减一张大招冷却(ctx, 目标)
			_记(ctx, 牌名, 目标 if 目标 != null else null, "一张冷却中的殖民卫星军大招冷却 −1%s" % ("" if 减 == "" else "：【%s】" % 减))
			return ["大招冷却 −1%s" % ("" if 减 == "" else "：【%s】" % 减)]
		"伪装粮船":
			if 目标 == null:
				return []
			var 抽们 := Setup.抽专属牌(目标, 2)
			_记(ctx, 牌名, 目标, "抽 %d 张精神牌" % 抽们.size())
			return ["抽 %d 张精神牌 → %s" % [抽们.size(), _名(目标)]]
		"星之歌":
			var 台们: Array = []
			for a in J.or_(ctx.get("allies"), []):
				if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and ColonialAwaken.觉醒中(a):
					Btl.加战意(a, 10.0, ctx, "星之歌")
					台们.append(_名(a))
			_记(ctx, 牌名, null, "每台觉醒中的成员战意 +10（%s）" % ("、".join(台们) if not 台们.is_empty() else "没有人在觉醒中"))
			return ["觉醒中成员战意 +10：%s" % "、".join(台们)]
	return []

static func _施放者(ctx: Dictionary) -> Variant:
	var 键 := str(ctx.get("_当前出牌者", ""))
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and str((a as Dictionary).get("key", "")) == 键:
			return a
	return null

static func _友(ctx: Dictionary, 目标们: Array) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0 and ColonialAwaken.是殖民卫星军(t):
		return t
	for u in 目标们:
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 and ColonialAwaken.是殖民卫星军(u):
			return u
	return _施放者(ctx)

static func _敌(ctx: Dictionary, 目标们: Array) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	for u in 目标们:
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0:
			return u
	return null

static func _名(u: Variant) -> String:
	return str((u as Dictionary).get("name", "（无）")) if u is Dictionary else "（无）"

static func _觉醒类型Of(u: Dictionary) -> String:
	return str(ColonialUnits.觉醒.get(ColonialAwaken.键(u), ""))

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String) -> void:
	var 谁 := {"类型": 势力, "牌名": 牌名}
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % _名(u)) if u is Dictionary else "", 文], 谁)

## 冷却中的殖民卫星军大招 −1（优先选打出者自己，其次任意冷却中最长的那一张）。
static func _减一张大招冷却(ctx: Dictionary, 目标: Variant) -> String:
	var 候选: Array = []
	for a in J.or_(ctx.get("allies"), []):
		if not (a is Dictionary) or float((a as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		if not ColonialAwaken.是殖民卫星军(a):
			continue
		for 槽 in J.or_((a as Dictionary).get("大招槽"), []):
			if 槽 is Dictionary and float((槽 as Dictionary).get("cd", 0.0)) > 0.0:
				候选.append(槽)
	# 先看指定目标，再看打出者，最后全场挑冷却最久的
	for 优先 in [目标, _施放者(ctx)]:
		if not (优先 is Dictionary):
			continue
		for 槽 in J.or_((优先 as Dictionary).get("大招槽"), []):
			if 槽 is Dictionary and float((槽 as Dictionary).get("cd", 0.0)) > 0.0:
				槽["cd"] = maxf(0.0, float(槽.get("cd", 0.0)) - 1.0)
				return str(((槽.get("卡") if 槽.get("卡") is Dictionary else {}) as Dictionary).get("名", ""))
	if 候选.is_empty():
		return ""
	J.sort(候选, func(x, y): return float((y as Dictionary).get("cd", 0.0)) - float((x as Dictionary).get("cd", 0.0)))
	var 选: Dictionary = 候选[0]
	选["cd"] = maxf(0.0, float(选.get("cd", 0.0)) - 1.0)
	return str(((选.get("卡") if 选.get("卡") is Dictionary else {}) as Dictionary).get("名", ""))

# ---- 五、【正规军掩护】：受方 −30%，减掉的部分在受击后转给打出者 ----
static func 受方伤害倍率(def: Variant, _w: Variant) -> float:
	if not (def is Dictionary):
		return 1.0
	if (def as Dictionary).get("正规军掩护") is Dictionary:
		return 0.7
	return 1.0

## 受击后转伤：`实受 × 3/7` = 原来那 30% 的份额（四舍五入，`J.round`）。
static func 受击后转伤(ctx: Dictionary, def: Dictionary, 实受: float) -> void:
	var 记 = def.get("正规军掩护")
	if not (记 is Dictionary) or 实受 <= 0.0:
		return
	var 键 := str((记 as Dictionary).get("打出者", ""))
	def.erase("正规军掩护")
	var 护: Variant = null
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and str((a as Dictionary).get("key", "")) == 键 and float((a as Dictionary).get("hp", 0.0)) > 0.0:
			护 = a
			break
	if not (护 is Dictionary):
		return
	var 转 := J.round(实受 * 3.0 / 7.0)
	if 转 <= 0.0:
		return
	护["hp"] = maxf(0.0, float((护 as Dictionary).get("hp", 0.0)) - 转)
	Btl.pushLog(ctx, "〔正规军掩护〕%s 替 %s 分担 %s 点伤害（剩 %s）" % [_名(护), _名(def), J.s(转),
		J.s(float((护 as Dictionary).get("hp", 0.0)))],
		J.merged(J.merged({"类型": "正规军掩护", "转伤": 转}, Btl.谁(护)), Btl.谁目标(def)))
	if float((护 as Dictionary).get("hp", 0.0)) <= 0.0:
		Btl.记击破(ctx, null, 护)
