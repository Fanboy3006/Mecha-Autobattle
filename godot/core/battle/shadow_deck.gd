## 职责：影世界的【影门牌库】（`SubDeck` 结构化库）+ 8 张势力牌 + ★【错位】的抽牌 / 放入 + 这两类公有牌的打出与算子。
## 约定：卡表只读 `Db.T.卡包["影世界"]`；四人的独有机制在 `ShadowUnits`，大招在 `ShadowUlts`。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §2.2 / §3 / §6
class_name ShadowDeck
extends RefCounted

const 势力 := "影世界"
const 等级键 := "级"
## 公有手牌满这么多张时 ★ 不抽牌（「放入」照常）。
const 抽牌上限 := 6

# ---- 零、卡包与卡表 ----
static func 卡包() -> Dictionary:
	var 包们 = Db.T.get("卡包")
	var 包 = (包们 as Dictionary).get(势力) if 包们 is Dictionary else null
	if not (包 is Dictionary):
		push_error("影世界卡表没装入：缺 Db.T.卡包[\"%s\"]（见 data/cards/影世界.json）" % 势力)
		return {}
	return 包

## 一张牌的「动作」→ `CardEffects` 的 `shadow` 算子（`参` 原样并进算子表）。
static func 效果组(条目: Dictionary) -> Array:
	var 表 := {"算子": ShadowV02.算子名, "动作": str(条目.get("动作", ""))}
	var 参 = 条目.get("参")
	if 参 is Dictionary:
		for k in (参 as Dictionary).keys():
			表[k] = 参[k]
	return [{"全局": [表]}]

static func _公有底(条目: Dictionary, 支: String) -> Dictionary:
	var 牌 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": "公有牌", "类型": "战术", "层级": "势力", "种类": 支,
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": 支 == "影门", "衍生": false, "入库条件": null,
		"获取": str(J.or_(条目.get("获取"), "初始")), "等级需求": 10,
		"效果说明": str(条目.get("效果说明", "")), "目标": str(条目.get("目标", "")),
		"错位": str(J.or_(条目.get("错位"), "")), "错位放入": str(J.or_(条目.get("错位放入"), "")),
		"每场一次": J.truthy(条目.get("每场一次")),
		"武器牌": false, "连携": false, 等级键: int(J.num0(条目.get(等级键))),
		"效果": 效果组(条目),
	}
	if 条目.get("入库条件") is Dictionary:
		牌["入库条件"] = (条目["入库条件"] as Dictionary).duplicate(true)
	return 牌

static var _影门表: Array = []
static var _影门代: int = -1
static var _势力表: Array = []
static var _势力代: int = -1

## 影门牌（一级 4 / 二级 3 / 三级 1）。
static func 影门牌们() -> Array:
	if _影门代 != Db.代:
		_影门表 = _构建(卡包().get("影门牌库"), "影门")
		_影门代 = Db.代
	return _影门表

## 8 张势力牌（公有排，只有影世界成员能打）。
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

static func 影门牌(id: Variant) -> Dictionary:
	for c in 影门牌们():
		if str((c as Dictionary).get("id", "")) == str(id):
			return c
	return {}

static func 是影门牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("归属", "")) == 势力 and str((c as Dictionary).get("种类", "")) == "影门"

static func 是势力牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("归属", "")) == 势力 and str((c as Dictionary).get("种类", "")) == "势力"

static func 是影世界公有牌(c: Variant) -> bool:
	return 是影门牌(c) or 是势力牌(c)

# ---- 一、影门牌库（全队一份；开场只有一级牌）----
static func 初始牌库() -> Dictionary:
	var 库 := SubDeck.新建()
	for c in 影门牌们():
		if int(J.num0((c as Dictionary).get(等级键))) == 1:
			SubDeck.牌们(库).append((c as Dictionary).duplicate(true))
	return 库

static func 初始化(ctx: Dictionary) -> void:
	ctx["影门牌库"] = 初始牌库()
	ctx["影门移出"] = []
	ctx["本场影种"] = 0.0
	ctx["本场影世界大招"] = false
	ctx["turnShiftCount"] = 0.0
	ctx["battleShiftCount"] = 0.0

static func 库(ctx: Variant) -> Variant:
	return (ctx as Dictionary).get("影门牌库") if ctx is Dictionary else null

static func 移出表(ctx: Dictionary) -> Array:
	if not (ctx.get("影门移出") is Array):
		ctx["影门移出"] = []
	return ctx["影门移出"]

static func _手牌上限() -> int:
	var 上 := int(Params.公有手牌自然上限())
	return 上 if 上 > 0 else 抽牌上限

## 从影门牌库抽 1 张进公有手牌（满手不抽）。返回抽到的牌。
static func 抽影门牌(ctx: Dictionary) -> Dictionary:
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 抽 := SubDeck.抽一张(库(ctx), ctx.公有手牌, _手牌上限(), ctx.get("rng"))
	if 抽.is_empty():
		Btl.pushLog(ctx, "〔错位〕公有手牌已满（%d 张）或影门牌库已空 → 这次不抽" % ctx.公有手牌.size(),
			{"类型": "影门抽牌", "抽牌": false})
		return {}
	Btl.pushLog(ctx, "〔错位〕从影门牌库抽到【%s】→ 公有手牌" % str(抽.get("名", "")),
		{"类型": "影门抽牌", "抽牌": true, "卡牌": 抽.get("id"), "牌名": 抽.get("名")})
	return 抽

## 把一张影门牌放进影门牌库（三级牌每种每场最多 1 次，`SubDeck` 断路器 1）。
static func 放入影门牌(ctx: Dictionary, id: String) -> bool:
	if id == "":
		return false
	var 卡 := 影门牌(id)
	if 卡.is_empty():
		Btl.pushLog(ctx, "〔错位〕「%s」本版未实装 → 不放入" % id, {"类型": "影门放入", "卡牌": id, "放入": false})
		return false
	var 成 := SubDeck.放入(库(ctx), 卡.duplicate(true), null, id, 等级键)
	Btl.pushLog(ctx, "〔错位〕%s【%s】%s影门牌库" % [("把" if 成 else "「放入」被拦下："), str(卡.get("名", "")),
		("放进" if 成 else "不放进")], {"类型": "影门放入", "卡牌": id, "放入": 成})
	return 成

## ★【错位】成立时：抽 1 张（满手不抽）+ 放入牌面写的那张。
static func 错位触发(ctx: Dictionary, 卡: Dictionary) -> void:
	Btl.pushLog(ctx, "〔错位〕【%s】错位条件成立" % str(卡.get("名", "")), {"类型": "错位触发", "卡牌": 卡.get("id")})
	抽影门牌(ctx)
	放入影门牌(ctx, str(卡.get("错位放入", "")))

## 打出后归哪儿：一 / 二级回库，三级移出本场；【播种】置入的副本用完即弃。
static func 回库或移出(ctx: Dictionary, 卡: Dictionary) -> String:
	if J.truthy(卡.get("置入副本")):
		return "弃"
	return SubDeck.回库或移出(库(ctx), 移出表(ctx), 卡, 等级键, "回库")

# ---- 二、公有牌打出（`ShadowV02.公有牌打出` 转进来）----
static func 不可打原因(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> Dictionary:
	if not ShadowV02.是影世界成员(u):
		return {"终局": true, "原因": "只有影世界成员能打这张牌"}
	if J.truthy(卡.get("已用")):
		return {"终局": true, "原因": "这一张每场只能用一次"}
	match str(卡.get("id", "")):
		"SHD_GATE_DRAIN":
			if _错位成员们(ctx).is_empty():
				return {"终局": true, "原因": "场上没有本回合已〔错位〕的影世界成员"}
		"SHD_GATE_FAULT":
			if 错位敌们(ctx).is_empty():
				return {"终局": true, "原因": "场上没有已〔错位〕的敌机"}
	return {"终局": false}

static func 打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	var 门 := 不可打原因(ctx, u, 卡)
	if bool(门.get("终局", false)):
		return {"终局": true, "结果": {"成功": false, "原因": str(门.get("原因", ""))}}
	var 费 := Btl.战意费用(卡)
	if str(Units.unit_class(u, ctx)) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	if Btl.战意(u) < 费:
		return {"终局": true, "结果": {"成功": false, "原因": "战意不足"}}
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	var 摘要 := CardEffects.execute(ctx, 卡)
	ctx["公有手牌"] = J.or_(ctx.get("公有手牌"), []).filter(func(c): return not is_same(c, 卡))
	var 去 := ""
	if 是影门牌(卡):
		去 = 回库或移出(ctx, 卡)
	elif J.truthy(卡.get("每场一次")):
		卡["已用"] = true
		移出表(ctx).append(卡)
		去 = "移出"
	else:
		ctx["公有弃牌堆"].append(卡)
		去 = "弃牌堆"
	Btl.pushLog(ctx, "〔%s〕%s 打出【%s】（战意 -%s，剩 %s；%s）%s" % [
		"影门牌" if 是影门牌(卡) else "势力牌", str(u.get("name", "")), str(卡.get("名", "")), J.s(费),
		J.s(J.num0(u.get("战意"))), 去, Btl.效果摘要文(摘要)],
		J.merged({"类型": "影门牌" if 是影门牌(卡) else "势力牌", "势力": 势力, "单位": u.get("key"),
			"卡牌": 卡.get("id"), "牌名": 卡.get("名"), "去处": 去, "战意": u.get("战意"), "效果摘要": 摘要}, Btl.谁(u)))
	DeckFlow.记上张打出牌(ctx, u, 卡)
	DeckFlow.检查公有待入库(ctx)
	DeckFlow.刷新实时门槛(ctx)
	Btl.刷新敌方意图(ctx)
	return {"终局": true, "结果": {"成功": true, "卡牌": str(卡.get("名", "")), "去处": 去,
		"战意": J.num0(u.get("战意")), "效果摘要": 摘要}}

# ---- 三、算子 ----
static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var ctx: Dictionary = 运行.get("ctx")
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(卡.get("名", ""))
	var 打者 = ShadowV02.施放者(ctx)
	match str(表.get("动作", "")):
		"影·影之种", "影·寄生影种":
			return _影种(ctx, 打者, 表, 牌名)
		"影·影步":
			var 友 = ShadowV02.友目标(ctx)
			if 友 == null:
				return []
			var k := ShadowV02.换位(ctx, "ally", 友.slot, ShadowV02.对位格(友), 牌名)
			return ["影步：%s 与同列对位换位（移位 %d）" % [ShadowV02.名(友), k]]
		"影·暗影汲取":
			var 友2 = ShadowV02.友目标(ctx)
			if not BattleSwap.已错位(友2):
				var 们 := _错位成员们(ctx)
				友2 = 们[0] if not 们.is_empty() else null
			if 友2 == null:
				return ["没有已〔错位〕的影世界成员"]
			Btl.加战意(友2, float(J.num0(表.get("战意"))), ctx, 牌名)
			var 回 := J.round(float(友2.maxHp) * float(J.num0(表.get("回复比"))))
			友2["hp"] = minf(float(友2.maxHp), float(友2.hp) + 回)
			ShadowV02.记(ctx, 牌名, 友2, "战意 +%d、回复 %s HP" % [int(J.num0(表.get("战意"))), J.s(回)])
			return ["暗影汲取 → %s" % ShadowV02.名(友2)]
		"影·门扉折光":
			var 友3 = ShadowV02.友目标(ctx)
			if 友3 == null:
				return []
			Btl.换同源增益(友3, "门扉折光", {"eva": float(J.num0(表.get("闪避"))), "剩余": 1.0})
			友3["门扉折光命中"] = float(J.num0(表.get("命中")))
			ShadowV02.记(ctx, 牌名, 友3, "闪避 +%d，下一张武器牌命中 +%d" % [int(J.num0(表.get("闪避"))), int(J.num0(表.get("命中")))])
			return ["门扉折光 → %s" % ShadowV02.名(友3)]
		"影·空间断层":
			var 敌 = ShadowV02.敌目标(ctx)
			if not BattleSwap.已错位(敌):
				var 错 := 错位敌们(ctx)
				敌 = 错[0] if not 错.is_empty() else null
			if 敌 == null:
				return ["没有已〔错位〕的敌机"]
			Btl.换同源增益(敌, "空间断层", {"hit": float(J.num0(表.get("命中"))), "剩余": 1.0})
			禁护卫(ctx, 敌)
			ShadowV02.记(ctx, 牌名, 敌, "到下个我方阶段前命中 %d、不能援护 / 掩护" % int(J.num0(表.get("命中"))))
			return ["空间断层 → %s" % ShadowV02.名(敌)]
		"影·炉心逆流":
			var 友4 = ShadowV02.友目标(ctx)
			if 友4 == null:
				return []
			var 扣 := J.round(float(友4.hp) * float(J.num0(表.get("扣血比"))))
			友4["hp"] = maxf(1.0, float(友4.hp) - 扣)
			Btl.加战意(友4, float(J.num0(表.get("战意"))), ctx, 牌名)
			var 减 := 减冷却(友4, float(J.num0(表.get("减冷却"))))
			ShadowV02.记(ctx, 牌名, 友4, "扣 %s HP、战意 +%d%s" % [J.s(扣), int(J.num0(表.get("战意"))),
				("" if 减 == "" else "，【%s】冷却 −%d" % [减, int(J.num0(表.get("减冷却")))])])
			return ["炉心逆流 → %s" % ShadowV02.名(友4)]
		"影·次元崩落":
			var 合 := 0.0
			for e in 错位敌们(ctx):
				合 += ShadowV02.真伤(ctx, 打者, e, float(J.num0(表.get("伤害"))))
			ShadowV02.记(ctx, 牌名, null, "对所有已〔错位〕的敌机造成无视防御伤害（合计 %s）" % J.s(合))
			return ["次元崩落：合计 %s" % J.s(合)]
	return _势力牌算子(ctx, 打者, 卡, 表, 牌名)

## 【影之种】/【寄生影种·改】：永久削甲 + 叠〔影种〕+（后排 / 必然）换位；改版对已错位目标追加伤害。
static func _影种(ctx: Dictionary, 打者: Variant, 表: Dictionary, 牌名: String) -> Array:
	var 敌 = ShadowV02.敌目标(ctx)
	if 敌 == null:
		return []
	var 改 := str(表.get("动作", "")) == "影·寄生影种"
	var 原错位 := BattleSwap.已错位(敌)
	叠影种(敌, float(J.num0(表.get("削甲"))))
	ctx["本场影种"] = J.num0(ctx.get("本场影种")) + 1.0
	var k := 0
	if 改 or Fm.rowOfSlot(float(敌.slot)) == Fm.ROW_BACK:
		k = ShadowV02.换位(ctx, "enemy", 敌.slot, ShadowV02.对位格(敌), 牌名)
	ShadowV02.记(ctx, 牌名, 敌, "装甲 −%d（〔影种〕×%d），移位 %d" % [int(J.num0(表.get("削甲"))),
		int(J.num0(敌.get("影种层数"))), k])
	if 改 and 原错位:
		ShadowV02.真伤(ctx, 打者, 敌, float(J.num0(表.get("错位伤害"))))
	return ["%s → %s" % [牌名, ShadowV02.名(敌)]]

## 8 张势力牌的算子。
static func _势力牌算子(ctx: Dictionary, 打者: Variant, 卡: Dictionary, 表: Dictionary, 牌名: String) -> Array:
	match str(表.get("动作", "")):
		"影·低语":
			var 抽 := Setup.抽公有牌(ctx, 1)
			var 加 := 打者 != null and J.num0(ctx.get("turnShiftCount")) >= 1.0
			if 加:
				Btl.加战意(打者, 5.0, ctx, 牌名)
			ShadowV02.记(ctx, 牌名, 打者, "抽 %d 张公有牌%s" % [抽.size(), "，本回合已移位 → 战意 +5" if 加 else ""])
			return ["抽 %d 张公有牌" % 抽.size()]
		"影·门扉轮转":
			var 前们 := Units.livingOf("ally", ctx).filter(func(a): return Fm.rowOfSlot(float(a.slot)) == Fm.ROW_FRONT)
			var 低 = ShadowV02.按血挑(前们, false)
			if 低 == null:
				return ["我方前排没有人"]
			var k := ShadowV02.换位(ctx, "ally", 低.slot, ShadowV02.对位格(低), 牌名)
			var 盾 := Btl.加卡牌护盾(低, float(低.maxHp) * float(J.num0(表.get("护盾比"))))
			ShadowV02.记(ctx, 牌名, 低, "换到后排（移位 %d），护盾 +%s" % [k, J.s(盾)])
			return ["门扉轮转 → %s" % ShadowV02.名(低)]
		"影·换形":
			if 打者 == null:
				return []
			var 换 = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
			if not ShadowV02.活(换) or is_same(换, 打者):
				换 = ShadowV02.按血挑(Units.livingOf("ally", ctx).filter(func(a): return not is_same(a, 打者)), false)
			var k2 := 0
			if 换 != null:
				k2 = ShadowV02.换位(ctx, "ally", 打者.slot, 换.slot, 牌名)
			打者["换形回合"] = ctx.get("turn")
			打者["换形伤害"] = float(J.num0(表.get("伤害")))
			ShadowV02.记(ctx, 牌名, 打者, "与 %s 换位（移位 %d），本回合伤害 +%d%%" % [ShadowV02.名(换), k2,
				int(float(J.num0(表.get("伤害"))) * 100.0)])
			return ["换形 → %s" % ShadowV02.名(打者)]
		"影·错乱":
			var 敌们 := Units.livingOf("enemy", ctx)
			var 高 = ShadowV02.按血挑(敌们, true)
			var 低2 = ShadowV02.按血挑(敌们, false)
			if 高 == null or 低2 == null or is_same(高, 低2):
				return ["敌方不足两台，无法交换"]
			var k3 := ShadowV02.换位(ctx, "enemy", 高.slot, 低2.slot, 牌名)
			for e in [高, 低2]:
				Btl.换同源增益(e, "错乱", {"hit": float(J.num0(表.get("命中"))), "剩余": 1.0})
			ShadowV02.记(ctx, 牌名, null, "%s ⇄ %s（移位 %d），两者本回合命中 %d" % [ShadowV02.名(高), ShadowV02.名(低2),
				k3, int(J.num0(表.get("命中")))])
			return ["错乱：%s ⇄ %s" % [ShadowV02.名(高), ShadowV02.名(低2)]]
		"影·门的回响":
			var 抽2 := Setup.抽公有牌(ctx, 2)
			ShadowV02.记(ctx, 牌名, 打者, "抽 %d 张公有牌" % 抽2.size())
			return ["抽 %d 张公有牌" % 抽2.size()]
		"影·影缝":
			var 敌 = ShadowV02.敌目标(ctx)
			if 敌 == null:
				return []
			var 成立 := BattleSwap.已错位(敌)
			Btl.换同源增益(敌, "影缝", {"eva": float(J.num0(表.get("闪避"))), "剩余": 1.0})
			ShadowV02.记(ctx, 牌名, 敌, "本回合闪避 %d" % int(J.num0(表.get("闪避"))))
			if 成立:
				var 锁们 := 错位敌们(ctx)
				for e2 in 锁们:
					禁护卫(ctx, e2)
				ShadowV02.记(ctx, 牌名, null, "%d 台已〔错位〕的敌机到下个我方阶段前不能援护 / 掩护" % 锁们.size())
				错位触发(ctx, 卡)
			return ["影缝 → %s%s" % [ShadowV02.名(敌), "（错位）" if 成立 else ""]]
		"影·影返":
			if 打者 != null:
				Btl.加战意(打者, float(J.num0(表.get("战意"))), ctx, 牌名)
			var 成立2 := not 错位敌们(ctx).is_empty()
			if 成立2:
				var 友 = ShadowV02.友目标(ctx)
				var 减 := 减冷却(友, float(J.num0(表.get("减冷却")))) if 友 != null else ""
				ShadowV02.记(ctx, 牌名, 友, "冷却 −%d：%s" % [int(J.num0(表.get("减冷却"))), 减 if 减 != "" else "（没有冷却中的牌）"])
				错位触发(ctx, 卡)
			return ["影返%s" % ("（错位）" if 成立2 else "")]
		"影·深渊之门":
			ctx["abyssGateActive"] = true
			ShadowV02.记(ctx, 牌名, 打者, "本回合此后因影世界牌移位的敌机各受 700 点无视防御特殊伤害（每台最多 3 次）")
			return ["深渊之门开启"]
	return []

# ---- 四、共用读写 ----
## 〔影种〕：装甲永久削减走 `armorCut`（可叠，最低到 0 由装甲公式兜底），层数记在 `影种层数`。
static func 叠影种(e: Dictionary, 削: float) -> void:
	e["armorCut"] = J.num0(e.get("armorCut")) + 削
	e["影种层数"] = J.num0(e.get("影种层数")) + 1.0

## 到下个我方阶段开始前不能援护 / 掩护（`BattleGuard` 认 `禁用护卫`）。
static func 禁护卫(ctx: Dictionary, e: Dictionary) -> void:
	e["禁用护卫"] = true
	if not (ctx.get("影世界禁护卫") is Array):
		ctx["影世界禁护卫"] = []
	(ctx["影世界禁护卫"] as Array).append(e)

static func 错位敌们(ctx: Dictionary) -> Array:
	return Units.livingOf("enemy", ctx).filter(func(e): return BattleSwap.已错位(e))

static func _错位成员们(ctx: Dictionary) -> Array:
	return Units.livingOf("ally", ctx).filter(func(a): return ShadowV02.是影世界成员(a) and BattleSwap.已错位(a))

## 一张冷却中的大招 / 副武器冷却 −值（挑剩得最久的那张）。返回牌名。
static func 减冷却(u: Dictionary, 值: float) -> String:
	var 选: Variant = null
	for 条 in J.or_(u.get("大招槽"), []) + J.or_(u.get("副武器栏"), []):
		if 条 is Dictionary and float((条 as Dictionary).get("cd", 0.0)) > 0.0:
			if 选 == null or float((条 as Dictionary).cd) > float(选.cd):
				选 = 条
	if 选 == null:
		return ""
	选["cd"] = maxf(0.0, float(选.cd) - 值)
	return str(((选.get("卡") if 选.get("卡") is Dictionary else {}) as Dictionary).get("名", ""))
