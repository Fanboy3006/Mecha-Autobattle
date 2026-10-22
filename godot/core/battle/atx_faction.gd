## ★ A6d：ATX **势力牌 v0.3（9 张）** 的状态与算子 —— 「公有排 / 只有 ATX 成员能打 / 谁打出扣谁的
# 见 协作/设计/ATX势力卡牌设计 v0.3.md §1 / §2 / §4 / §5
class_name AtxFaction
extends RefCounted

const 势力 := "ATX"

const 送死 := "F_ATX_V2_1"
const 必闪 := "F_ATX_V2_2"
const 诱敌 := "F_ATX_V2_3"
const 加注 := "F_ATX_V2_4"
const 止损 := "F_ATX_V2_5"
const 读牌 := "F_ATX_V2_6"
const 二次下注 := "F_ATX_V2_7"
const 幸运连号 := "F_ATX_V2_8"
const 上头 := "F_ATX_V2_9"

const 卡id们: Array = ["F_ATX_V2_1", "F_ATX_V2_2", "F_ATX_V2_3", "F_ATX_V2_4", "F_ATX_V2_5",
	"F_ATX_V2_6", "F_ATX_V2_7", "F_ATX_V2_8", "F_ATX_V2_9"]

const 止损血比 := 0.40
const 止损战意 := 15.0
const 止损闪避 := 15.0
const 诱敌闪避 := 10.0
const 读牌闪避 := 15.0
const 加注命中 := -15.0
const 必闪闪避 := 20.0
const 必闪伤害倍率 := -0.20
const 幸运连号降费 := 10
const 二次下注伤害比 := 0.5

const 诱敌键 := "ATX诱敌回合"
const 加注回合键 := "ATX加注回合"
const 二次下注键 := "ATX二次下注"
const 降费键 := "下张ATX大招降费"
const 读牌键 := "ATX读牌目标"
const 打出大招键 := "ATX打出大招"
const 大招人键 := "ATX大招打出人"

# ---- 一、身份 ----
static func 是势力牌(card: Variant) -> bool:
	return card is Dictionary and J.inc(卡id们, str((card as Dictionary).get("id", "")))

static func 是ATX成员(u: Variant) -> bool:
	return u is Dictionary and FacAtx._是ATX(u)

static func _回合(ctx: Dictionary) -> int:
	return int(ctx.get("turn", 1))

static func 血比(u: Variant) -> float:
	if not (u is Dictionary):
		return 0.0
	var 上 := float((u as Dictionary).get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float((u as Dictionary).get("hp", 0.0)) / 上

# ---- 二、【赌局】前置：亮闪字成员 ----
static func 亮闪者们(ctx: Variant) -> Array:
	var 出: Array = []
	if not (ctx is Dictionary):
		return 出
	for u in Units.livingOf("ally", ctx):
		if 是ATX成员(u) and J.truthy((u as Dictionary).get("闪")):
			出.append(u)
	return 出

# ---- 三、可打判定（纯读） ----
static func 不可打原因(ctx: Dictionary, u: Variant, card: Variant) -> String:
	if not (ctx is Dictionary):
		return ""
	if not 是势力牌(card):
		return ""
	if not (u is Dictionary):
		return "没有打出者"
	if not 是ATX成员(u):
		return "这张 ATX 势力牌只有 ATX 成员能打（%s 不是 ATX 成员）" % str((u as Dictionary).get("name", ""))
	if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
		return "这台机体已经阵亡"
	var id := str((card as Dictionary).get("id", ""))
	var 回合 := _回合(ctx)
	match id:
		加注:
			if int(J.num0(ctx.get(加注回合键))) == 回合:
				return "本回合已经打过【加注】（每回合限 1 次）"
		止损:
			if _危机成员(ctx) == null:
				return "没有 HP ≤ %d%% 的 ATX 成员（当前最低 %d%%）" % [
					int(止损血比 * 100.0), int(roundf(_最低血比(ctx) * 100.0))]
		读牌:
			if 回合 < 2:
				return "第 2 回合起才能打（现在是第 %d 回合）" % 回合
		二次下注:
			if 回合 < 2:
				return "第 2 回合起才能打（现在是第 %d 回合）" % 回合
		幸运连号:
			if not J.truthy(ctx.get(打出大招键)):
				return "本场还没打出过 ATX 大招"
		上头:
			if 回合 < 3:
				return "第 3 回合起才能打（现在是第 %d 回合）" % 回合
	return ""

static func 可用吗(ctx: Dictionary, u: Variant, card: Variant) -> bool:
	return 不可打原因(ctx, u, card) == ""

static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	var 因 := 不可打原因(ctx, u, card)
	if 因 == "":
		return {"终局": false}
	return {"终局": true, "原因": 因}

static func 合体技门槛(ctx: Dictionary, card: Dictionary) -> Dictionary:
	return {"终局": true, "进入原因": 合体技不可打原因(ctx, card), "各付": 各付费用(card)}

static func _危机成员(ctx: Dictionary) -> Variant:
	var 选 = null
	for u in Units.livingOf("ally", ctx):
		if not 是ATX成员(u):
			continue
		if 血比(u) > 止损血比 + 0.000001:
			continue
		if 选 == null or 血比(u) < 血比(选):
			选 = u
	return 选

static func _最低血比(ctx: Dictionary) -> float:
	var 低 := 1.0
	var 有 := false
	for u in Units.livingOf("ally", ctx):
		if 是ATX成员(u):
			低 = minf(低, 血比(u))
			有 = true
	return 低 if 有 else 0.0

# ---- 四、效果执行器 ----
static func 执行(ctx: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	var u = _打出者(ctx)
	if u == null:
		return ["没有能出手的 ATX 成员"]
	var card: Dictionary = ctx.get("_当前牌") if ctx.get("_当前牌") is Dictionary else {}
	return _按id(ctx, u, str(表.get("id", "")), card, 表, 目标们)

static func 执行算子(ctx: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	return 执行(ctx, 表, 目标们)

static func _打出者(ctx: Dictionary) -> Variant:
	var 键 = ctx.get("_当前出牌者")
	if 键 != null:
		var u = Btl.找单位(ctx, 键, "ally")
		if u is Dictionary:
			return u
	return null

static func _目标成员(ctx: Dictionary, u: Dictionary, target_id: Variant) -> Dictionary:
	var t = Btl.找单位(ctx, target_id, "ally")
	if t is Dictionary and 是ATX成员(t) and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	return u

static func _按id(ctx: Dictionary, u: Dictionary, id: String, card: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	match id:
		送死: return _送死(ctx, u, card)
		必闪: return _必闪(ctx, u, card, 表)
		诱敌: return _诱敌(ctx, u, card, 目标们)
		加注: return _加注(ctx, u, card, 表)
		止损: return _止损(ctx, u, card)
		读牌: return _读牌(ctx, u, card)
		二次下注: return _二次下注(ctx, u, card)
		幸运连号: return _幸运连号(ctx, u, card)
		上头: return _上头(ctx, u, card)
	return []

static func _记(ctx: Dictionary, 类型: String, 文: String, 额外: Dictionary = {}) -> void:
	var 字段: Dictionary = J.merged({"类型": 类型, "势力": 势力, "回合": _回合(ctx)}, 额外)
	Btl.pushLog(ctx, 文, 字段)

static func _送死(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	var 抽 := Setup.抽公有牌(ctx, 1)
	var 文 := "〔又是送死的任务〕%s 抽 %d 张公有牌" % [str((u as Dictionary).get("name", "")), 抽.size()]
	if not 抽.is_empty():
		文 += "（%s）" % str((抽[0] as Dictionary).get("名", ""))
	_记(ctx, "抽牌", 文, {"抽牌": 抽.size(), "单位": (u as Dictionary).get("key"),
		"卡牌ID": 送死, "抽到": str((抽[0] as Dictionary).get("名", "")) if not 抽.is_empty() else ""})
	return ["送死的任务：抽 %d 张公有牌" % 抽.size()]

static func _必闪(ctx: Dictionary, u: Dictionary, _card: Dictionary, 表: Dictionary) -> Array:
	var 光环 := 表.duplicate(true) if 表 is Dictionary else {}
	光环["范围"] = "ATX"
	光环["增益"] = {"eva": 必闪闪避, "dmgMul": 必闪伤害倍率, "剩余": 1.0}
	光环["说明"] = "必闪"
	var 摘要 := FacAtx._光环(ctx, 光环)
	_记(ctx, "增益", "〔必闪〕ATX 全体闪避 +%d；代价：本回合 ATX 伤害 −%d%%" % [
		int(必闪闪避), int(-必闪伤害倍率 * 100.0)],
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 必闪, "闪避加": 必闪闪避,
			"伤害倍率": 1.0 + 必闪伤害倍率})
	return 摘要

static func _诱敌(ctx: Dictionary, u: Dictionary, _card: Dictionary, 目标们: Array) -> Array:
	var 目标键 = 目标们[0] if (not 目标们.is_empty() and 目标们[0] != null) else ctx.get("_当前目标")
	var t := _目标成员(ctx, u, 目标键)
	t[诱敌键] = _回合(ctx)
	Btl.换同源增益(t, "ATX:诱敌", {"eva": 诱敌闪避, "剩余": 1.0})
	_记(ctx, "增益", "〔诱敌〕%s 到下个我方阶段前：敌方**单体**攻击优先选它、闪避 +%d" % [
		str((t as Dictionary).get("name", "")), int(诱敌闪避)],
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 诱敌, "目标": t.get("key"),
			"目标名": t.get("name"), "闪避加": 诱敌闪避, 诱敌键: _回合(ctx)})
	return ["诱敌：%s 吸引敌方单体攻击、闪避 +%d" % [str((t as Dictionary).get("name", "")), int(诱敌闪避)]]

static func 诱敌者(ctx: Variant) -> Variant:
	if not (ctx is Dictionary):
		return null
	for u in Units.livingOf("ally", ctx):
		if 是ATX成员(u) and int(J.num0((u as Dictionary).get(诱敌键))) == _回合(ctx):
			return u
	return null

## 敌方单体攻击只能选亮着【诱敌】的 ATX 成员（范围武器不受限）。
static func 可选目标(ctx: Variant, 攻: Variant, 目标: Variant, w: Variant) -> bool:
	if not (ctx is Dictionary):
		return true
	if not (攻 is Dictionary) or not (目标 is Dictionary):
		return true
	if str((攻 as Dictionary).get("side", "")) != "enemy":
		return true
	if str((目标 as Dictionary).get("side", "")) == "enemy":
		return true
	if is_same(攻, 目标):
		return true
	if w != null and Reach.是范围武器(w):
		return true
	var 诱 = 诱敌者(ctx)
	if 诱 == null:
		return true
	return is_same(诱, 目标)

static func 诱敌预告(ctx: Variant) -> Variant:
	var 诱 = 诱敌者(ctx)
	return (诱 as Dictionary).get("key") if 诱 != null else null

static func _加注(ctx: Dictionary, u: Dictionary, _card: Dictionary, 表: Dictionary) -> Array:
	ctx[加注回合键] = _回合(ctx)
	var 光环 := 表.duplicate(true) if 表 is Dictionary else {}
	光环["范围"] = "敌我全体"
	光环["增益"] = {"hit": 加注命中, "剩余": 1.0}
	光环["说明"] = "加注"
	var 摘要 := FacAtx._光环(ctx, 光环)
	_记(ctx, "增益", "〔加注〕到下个我方阶段前，**敌我全体**每段命中 −%d（全场光环，每回合限 1 次）" % int(-加注命中),
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 加注, "命中惩罚": 加注命中, 加注回合键: _回合(ctx)})
	return 摘要

static func _止损(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	var t = _危机成员(ctx)
	if t == null:
		return ["止损：没有 HP ≤ %d%% 的 ATX 成员" % int(止损血比 * 100.0)]
	var 前 := float((t as Dictionary).get("战意", 0.0))
	var 后 := Btl.加战意(t, 止损战意, ctx, "止损")
	Btl.换同源增益(t, "ATX:止损", {"eva": 止损闪避, "剩余": 1.0})
	_记(ctx, "增益", "〔止损〕%s（HP %d%%）战意 +%d（%s → %s）、闪避 +%d" % [
		str((t as Dictionary).get("name", "")), int(roundf(血比(t) * 100.0)), int(止损战意),
		J.s(前), J.s(后), int(止损闪避)],
		{"单位": u.get("key"), "卡牌ID": 止损, "目标": t.get("key"), "目标名": t.get("name"),
			"战意加": 止损战意, "战意": 后, "闪避加": 止损闪避, "血比": 血比(t)})
	return ["止损：%s 战意 +%d、闪避 +%d" % [str((t as Dictionary).get("name", "")), int(止损战意), int(止损闪避)]]

static func _清读牌增益(ctx: Dictionary) -> void:
	for a in J.or_(ctx.get("allies"), []):
		if not (a is Dictionary) or not ((a as Dictionary).get("buffs") is Array):
			continue
		(a as Dictionary)["buffs"] = ((a as Dictionary).buffs as Array).filter(
			func(b): return not (b is Dictionary and str((b as Dictionary).get("src", "")) == "ATX:读牌"))

static func _挂读牌(ctx: Dictionary, 意图: Array) -> int:
	var 台 := 0
	for 键 in _被瞄键们(意图):
		for a in Units.livingOf("ally", ctx):
			if 是ATX成员(a) and str((a as Dictionary).get("key", "")) == 键:
				Btl.换同源增益(a, "ATX:读牌", {"eva": 读牌闪避, "剩余": 1.0})
				台 += 1
	return 台

static func _被瞄键们(意图: Array) -> Array:
	var 出: Array = []
	for 条 in 意图:
		if 条 is Dictionary and 条.get("目标") != null and not J.inc(出, str(条.get("目标"))):
			出.append(str(条.get("目标")))
	J.sort(出, func(a, b):
		var x := str(a)
		var y := str(b)
		return -1.0 if x < y else (1.0 if x > y else 0.0))
	return 出

## 读牌：挂 `eva +15` 后敌方最优目标可能改变，需迭代 `Btl.算意图` 收敛（最多 4 轮），保证显示与实际出手一致。
static func _读牌(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	var 意图: Array = Btl.算意图(ctx)
	for _轮 in range(4):
		_清读牌增益(ctx)
		var 被瞄 := _被瞄键们(意图)
		_挂读牌(ctx, 意图)
		var 意图2: Array = Btl.算意图(ctx)
		_挂读牌(ctx, 意图2)
		var 意图3: Array = Btl.算意图(ctx)
		意图 = 意图3
		if _被瞄键们(意图3) == 被瞄:
			break
	var 表 := {}
	var 名们: Array = []
	var 加成 := _被瞄键们(意图).size()
	for 条 in 意图:
		if not (条 is Dictionary):
			continue
		var 目标键 = 条.get("目标")
		if 目标键 == null:
			continue
		表[str(条.get("单位", ""))] = str(目标键)
		名们.append("%s → %s" % [str(条.get("名称", "")), str(条.get("目标名", ""))])
	ctx[读牌键] = 表
	_记(ctx, "读牌", "〔读牌〕敌方下一个攻击目标：%s%s" % [
		"、".join(名们) if not 名们.is_empty() else "（这一回合没有敌人锁定目标）",
		"；被选中的 %d 台 ATX 成员闪避 +%d" % [加成, int(读牌闪避)] if 加成 > 0 else ""],
		{"单位": u.get("key"), "卡牌ID": 读牌, "意图": 表, "台数": float(加成), "闪避加": 读牌闪避})
	return ["读牌：显示 %d 台敌人的目标；%d 台 ATX 成员闪避 +%d" % [表.size(), 加成, int(读牌闪避)]]

static func _二次下注(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	ctx[二次下注键] = {"打出者": str((u as Dictionary).get("key", "")), "回合": _回合(ctx)}
	_记(ctx, "标记", "〔二次下注〕%s 本回合下一张武器牌结算后：把**打空的段**重打一次（每段 %d%%）" % [
		str((u as Dictionary).get("name", "")), int(二次下注伤害比 * 100.0)],
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 二次下注, "伤害比": 二次下注伤害比})
	return ["二次下注：下一张武器牌打空的段重打一次（每段 %d%%）" % int(二次下注伤害比 * 100.0)]

static func _牌威力(card: Dictionary) -> float:
	for 段 in J.or_(card.get("效果"), []):
		if not (段 is Dictionary):
			continue
		for 条 in J.or_(段.get("全局"), []):
			if 条 is Dictionary and J.num0(条.get("威力")) > 0.0:
				return J.num0(条.get("威力"))
	if card.get("武器") is Dictionary:
		return J.num0((card.get("武器") as Dictionary).get("power"))
	if J.num0(card.get("威力")) > 0.0:
		return J.num0(card.get("威力"))
	return 300.0

## 武器牌结算后：若打出者挂有本回合【二次下注】，将打空的段按 50% 威力必中重打一次（消费即清）。
static func 尝试二次下注(ctx: Variant, u: Variant, card: Variant) -> bool:
	return 攻击后二次下注(ctx, u, card)

static func 攻击后二次下注(ctx: Variant, u: Variant, card: Variant) -> bool:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (card is Dictionary):
		return false
	var 记 = ctx.get(二次下注键)
	if not (记 is Dictionary):
		return false
	if int(J.num0((记 as Dictionary).get("回合"))) != _回合(ctx):
		ctx.erase(二次下注键)
		return false
	if str((记 as Dictionary).get("打出者", "")) != str((u as Dictionary).get("key", "")):
		return false
	ctx.erase(二次下注键)
	var 段数 := 0
	var 命中段数 := 0
	var 目标名 := ""
	var 日志: Array = J.or_(ctx.get("log"), [])
	for i in range(日志.size() - 1, -1, -1):
		var e = 日志[i]
		if not (e is Dictionary):
			continue
		if str(e.get("类型", "")) != "攻击":
			continue
		if str(e.get("单位", "")) != str((u as Dictionary).get("key", "")):
			continue
		段数 = int(J.num0(e.get("段数")))
		命中段数 = int(J.num0(e.get("命中段数")))
		目标名 = str(e.get("目标", ""))
		break
	var 打空 := maxi(0, 段数 - 命中段数)
	if 打空 <= 0:
		_记(ctx, "二次下注", "〔二次下注〕%s 这一张武器牌没有打空的段 → 不重打" % str((u as Dictionary).get("name", "")),
			{"单位": (u as Dictionary).get("key"), "卡牌ID": 二次下注, "打空段": 0.0, "重打段": 0.0})
		return false
	var t = Btl.找单位(ctx, 目标名, "enemy")
	if not (t is Dictionary) or float((t as Dictionary).get("hp", 0.0)) <= 0.0:
		var 敌 := FacAtx._选目标(ctx, {"目标": "自动"})
		if 敌.is_empty():
			return false
		t = 敌[0]
	var 威力 := _牌威力(card) * 二次下注伤害比
	var w := FacAtx._武器(str((card as Dictionary).get("名", "")) + "·二次下注", {"必中": true}, 威力, 100.0, 打空)
	w["必中"] = true
	var rec: Dictionary = FacAtx._一发(ctx, u, t, w, false)
	FacAtx._记攻击(ctx, str(w.name), card, u, t, rec, {"二次下注": true, "打空段": 打空})
	var 重打账: Dictionary = rec.get("字段") if rec.get("字段") is Dictionary else {}
	_记(ctx, "二次下注", "〔二次下注〕%s 的【%s】打空 %d 段 → 重打 %d 段（每段 %s × %d%% = %s）" % [
		str((u as Dictionary).get("name", "")), str((card as Dictionary).get("名", "")), 打空, 打空,
		J.s(J.round(_牌威力(card))), int(二次下注伤害比 * 100.0), J.s(J.round(威力))],
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 二次下注, "打空段": float(打空), "重打段": float(打空),
			"重打威力": J.round(威力), "重打伤害": J.num0(重打账.get("伤害")),
			"重打命中段": J.num0(重打账.get("命中段数")), "目标": (t as Dictionary).get("key"),
			"二次下注账": true})
	return true

## 纯读大招费用预览（计入【幸运连号】降费但不消费状态）。
static func 大招费用预览(ctx: Variant, card: Variant) -> float:
	var 费 := J.num0(J.g(card, "耗气"))
	if not (ctx is Dictionary) or not (card is Dictionary):
		return 费
	if str((card as Dictionary).get("类型", "")) != "大招":
		return 费
	var 降 := int(J.num0((ctx as Dictionary).get(降费键)))
	if 降 <= 0:
		return 费
	return maxf(0.0, 费 - float(降))

## 大招实际费用（消费【幸运连号】降费并记录战报）。
static func 大招实际费用(ctx: Variant, card: Variant) -> float:
	var 费 := J.num0(J.g(card, "耗气"))
	if not (ctx is Dictionary) or not (card is Dictionary):
		return 费
	if str((card as Dictionary).get("类型", "")) != "大招":
		return 费
	var 降 := int(J.num0((ctx as Dictionary).get(降费键)))
	if 降 <= 0:
		return 费
	(ctx as Dictionary)[降费键] = 0
	Btl.pushLog(ctx, "〔幸运连号〕【%s】费用 −%d（%s → %s）" % [str((card as Dictionary).get("名", "")), 降,
		J.s(费), J.s(maxf(0.0, 费 - float(降)))],
		{"类型": "降费", "势力": 势力, "卡牌ID": (card as Dictionary).get("id"), "降费": 降,
			"回合": (ctx as Dictionary).get("turn")})
	return maxf(0.0, 费 - float(降))

static func _幸运连号(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	ctx[降费键] = 幸运连号降费
	_记(ctx, "降费", "〔幸运连号〕下一张 ATX 大招费用 −%d" % 幸运连号降费,
		{"单位": (u as Dictionary).get("key"), "卡牌ID": 幸运连号, "值": 幸运连号降费,
			"累计": int(J.num0(ctx.get(降费键)))})
	return ["幸运连号：下一张 ATX 大招降费 −%d" % 幸运连号降费]

static func _上头(ctx: Dictionary, u: Dictionary, _card: Dictionary) -> Array:
	var 亮们 := 亮闪者们(ctx)
	if not (ctx.get("筹码牌库") is Array):
		ctx["筹码牌库"] = []
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 名们: Array = []
	var 抽到: Array = []
	var 满 := false
	for a in 亮们:
		if (ctx["公有手牌"] as Array).size() >= AtxChips.手牌上限:
			满 = true
			break
		var c := SubDeck.抽一张(ctx["筹码牌库"], ctx["公有手牌"], AtxChips.手牌上限, ctx.get("rng"))
		if c.is_empty():
			break
		名们.append(str((a as Dictionary).get("name", "")))
		抽到.append(str(c.get("名", "")))
	var 文 := "〔上头又想让我们去死〕亮着闪字的 ATX 成员 %d 台 → 各抽 1 张筹码牌：%s" % [
		亮们.size(), "、".join(抽到) if not 抽到.is_empty() else "（没抽到）"]
	if 满:
		文 += "（公有手牌已满 %d 张 → 不抽）" % AtxChips.手牌上限
	_记(ctx, "赌局", 文, {"单位": (u as Dictionary).get("key"), "卡牌ID": 上头,
		"亮闪": 亮们.size(), "抽到": 抽到.size(), "公有手牌": (ctx["公有手牌"] as Array).size(),
		"筹码牌库张数": (ctx["筹码牌库"] as Array).size()})
	return ["上头的任务：%d 台亮闪字的成员各抽 1 张筹码牌（实抽 %d 张）" % [亮们.size(), 抽到.size()]]

# ---- 五、每场 / 每回合状态 ----
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx.erase(加注回合键)
	ctx.erase(二次下注键)
	ctx.erase(读牌键)
	ctx[降费键] = 0
	ctx[打出大招键] = false
	ctx[大招人键] = {}

static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx.erase(加注回合键)
	ctx.erase(二次下注键)
	ctx.erase(读牌键)
	for u in Units.livingOf("ally", ctx):
		if 是ATX成员(u):
			(u as Dictionary).erase(诱敌键)

## 记录「本场打出过 ATX 大招」（同步写角色键表与 `v3打出ATX大招` 计数）。
static func 记打出大招(ctx: Variant, card: Variant, u: Variant = null) -> void:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return
	if str((card as Dictionary).get("类型", "")) != "大招":
		return
	ctx[打出大招键] = true
	if not (ctx.get(大招人键) is Dictionary):
		ctx[大招人键] = {}
	for k in FacAtx.涉及角色键(card):
		(ctx[大招人键] as Dictionary)[str(k)] = true
	if u is Dictionary:
		(u as Dictionary)["本场已打大招"] = true
		if 是ATX成员(u):
			DeckFlow.ctx计数加(ctx, "v3打出ATX大招")

static func 轮盘双响可打吗(ctx: Variant, u: Variant = null) -> bool:
	if not (ctx is Dictionary):
		return false
	return 轮盘双响不可打原因(ctx, u) == ""

static func 合体技不可打原因(ctx: Dictionary, card: Variant) -> String:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return ""
	if str((card as Dictionary).get("id", "")) != FacAtx.合体技ID:
		return ""
	return 轮盘双响不可打原因(ctx, null)

## 【轮盘双响】可打判定：两人存活、本场各大招打过 1 次、本回合未打主武器、战意 ≥ 15、cd ≤ 0 且本回合未打。
static func 轮盘双响不可打原因(ctx: Dictionary, u: Variant) -> String:
	if not (ctx is Dictionary):
		return "没有战斗上下文"
	var 响 = Btl.找单位(ctx, FacAtx.合体技成员[0], "ally")
	var 艾 = Btl.找单位(ctx, FacAtx.合体技成员[1], "ally")
	if not (响 is Dictionary) or float((响 as Dictionary).get("hp", 0.0)) <= 0.0:
		return "合体技参与者 %s 不在场（要全部存活才打得出来）" % str(FacAtx.合体技成员[0])
	if not (艾 is Dictionary) or float((艾 as Dictionary).get("hp", 0.0)) <= 0.0:
		return "合体技参与者 %s 不在场（要全部存活才打得出来）" % str(FacAtx.合体技成员[1])
	var 人: Dictionary = ctx.get(大招人键) if ctx.get(大招人键) is Dictionary else {}
	var 缺: Array = []
	for v in [响, 艾]:
		var k := str((v as Dictionary).get("key", ""))
		var 打过: bool = J.truthy(人.get(k)) or J.truthy((v as Dictionary).get("本场已打大招"))
		if not 打过:
			缺.append("%s %s" % [k, str((v as Dictionary).get("name", k))])
	if not 缺.is_empty():
		return "需响介与艾克赛琳本场各打出过 1 次大招（还没打：%s）" % "、".join(缺)
	for v in [响, 艾]:
		if J.truthy((v as Dictionary).get("主武器已销毁")):
			return "%s 本回合主武器卡已销毁（两人都没打过才打得出）" % str((v as Dictionary).get("name", ""))
	var 各付 := 各付费用(FacAtx.合体技卡())
	for v in [响, 艾]:
		if Btl.战意(v) < 各付:
			return "%s 的战意不足（要各付 %d，现在 %d）" % [
				str((v as Dictionary).get("name", "")), int(各付), int(Btl.战意(v))]
	for v in [响, 艾]:
		var 槽: Dictionary = _找槽(v)
		if 槽.is_empty():
			continue
		if J.truthy(槽.get("本回合已打")):
			return "%s 本回合已经打过【轮盘双响】（同一张每回合限 1 次）" % str((v as Dictionary).get("name", ""))
		if float(J.num0(槽.get("cd"))) > 0.0:
			return "冷却中（还剩 %d 回合）" % int(J.num0(槽.get("cd")))
	if u is Dictionary:
		if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
			return "这台机体已经阵亡"
		if not [str(FacAtx.合体技成员[0]), str(FacAtx.合体技成员[1])].has(str((u as Dictionary).get("key", ""))):
			return "【轮盘双响】只有响介 / 艾克赛琳打得出来"
	return ""

static func 合体技槽(u: Variant) -> Dictionary:
	return _找槽(u)

static func _找槽(u: Variant) -> Dictionary:
	if not (u is Dictionary):
		return {}
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if not (槽 is Dictionary):
			continue
		var 卡 = J.g(槽, "卡")
		if 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == FacAtx.合体技ID:
			return 槽
	return {}

# ---- 六、合体技【轮盘双响】收尾与同步 ----
static func 各付费用(card: Variant) -> float:
	if not (card is Dictionary):
		return 0.0
	return J.num0((card as Dictionary).get("各付"))

static func 放入大招槽(u: Variant, card: Variant, 额外: Dictionary = {}) -> bool:
	if not (u is Dictionary) or not (card is Dictionary):
		return false
	if not ((u as Dictionary).get("大招槽") is Array):
		(u as Dictionary)["大招槽"] = []
	var 键 := str((card as Dictionary).get("id", ""))
	for 槽 in (u as Dictionary).大招槽:
		if not (槽 is Dictionary):
			continue
		var 已有 = J.g(槽, "卡")
		if 已有 is Dictionary and str((已有 as Dictionary).get("id", "")) == 键:
			return false
	var 底 := {"cd": float(J.or_((card as Dictionary).get("冷却"), 5.0)), "已解锁": true}
	for k in 额外.keys():
		底[k] = 额外[k]
	底["处理者"] = "AtxFaction"
	var 槽 := MithrilV03Cards._槽(card, 底)
	(u as Dictionary).大招槽.append(槽)
	return true

## 开场装填：响介（A1）与艾克赛琳（A2）同时在场时将【轮盘双响】装入双方大招槽，并从抽牌堆等区域摘除。
static func 装填轮盘双响(ctx: Variant) -> int:
	if not (ctx is Dictionary):
		return 0
	var 响 = Btl.找单位(ctx, FacAtx.合体技成员[0], "ally")
	var 艾 = Btl.找单位(ctx, FacAtx.合体技成员[1], "ally")
	if not (响 is Dictionary) or not (艾 is Dictionary):
		return 0
	if float((响 as Dictionary).get("hp", 0.0)) <= 0.0 or float((艾 as Dictionary).get("hp", 0.0)) <= 0.0:
		return 0
	var 卡 := FacAtx.合体技卡()
	if 卡.is_empty():
		return 0
	var 装 := 0
	for v in [响, 艾]:
		_清牌堆里的合体技(v)
		if _找槽(v).is_empty():
			if 放入大招槽(v, 卡, {"cd": 0.0, "cd_max": 冷却Of(卡), "本回合已打": false,
				"实时门槛满足": true, "已解锁": true, "is_weapon": true}):
				装 += 1
	return 装

static func 冷却Of(card: Variant) -> float:
	var v := J.num0(J.g(card, "冷却"))
	return v if v > 0.0 else 5.0

static func _清牌堆里的合体技(u: Variant) -> void:
	if not (u is Dictionary):
		return
	var 键 := FacAtx.合体技ID
	for 区 in ["专属牌库", "专属手牌", "专属弃牌堆", "待入库", "武器栏"]:
		var 们 = (u as Dictionary).get(区)
		if not (们 is Array):
			continue
		(u as Dictionary)[区] = (们 as Array).filter(func(c):
			return not (c is Dictionary and str((c as Dictionary).get("id", "")) == 键))

static func 同步轮盘双响冷却(ctx: Variant, 响: Variant, 艾: Variant) -> void:
	var 卡 := FacAtx.合体技卡()
	var 冷 := 冷却Of(卡)
	for v in [响, 艾]:
		if not (v is Dictionary):
			continue
		var 槽: Dictionary = _找槽(v)
		if 槽.is_empty():
			if 放入大招槽(v, 卡, {"cd": 冷, "cd_max": 冷}):
				槽 = _找槽(v)
		if 槽.is_empty():
			continue
		槽["cd_max"] = 冷
		槽["cd"] = 冷
		槽["本回合已打"] = true
		槽["已解锁"] = true
		槽["实时门槛满足"] = true
	Btl.pushLog(ctx, "〔轮盘双响〕两人的大招槽同步进入冷却 %s（同一张牌，共用状态）" % J.s(冷),
		{"类型": "合体技冷却", "势力": 势力, "卡牌ID": FacAtx.合体技ID, "cd": 冷})

static func 打出轮盘双响(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant = null) -> Dictionary:
	if not (ctx is Dictionary):
		return {"成功": false, "原因": "没有战斗上下文"}
	if not (u is Dictionary) or not (card is Dictionary):
		return {"成功": false, "原因": "没有这张牌"}
	var 原因 := 轮盘双响不可打原因(ctx, u)
	if 原因 != "":
		return {"成功": false, "原因": 原因}
	var 响 = Btl.找单位(ctx, FacAtx.合体技成员[0], "ally")
	var 艾 = Btl.找单位(ctx, FacAtx.合体技成员[1], "ally")
	var 各付 := 各付费用(card)
	if 各付 <= 0.0:
		各付 = 15.0
	for v in [响, 艾]:
		(v as Dictionary)["战意"] = maxf(0.0, Btl.战意(v) - 各付)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = card
	var 结果 := {"击破": 0.0}
	if card.get("效果") is Array and not (card.get("效果") as Array).is_empty():
		CardEffects.execute(ctx, card)
	if card.get("武器") is Dictionary:
		结果 = Btl._执行武器攻击(ctx, u, {"t": card.武器, "cd": 0.0, "uses": null}, target_id)
	for v in [响, 艾]:
		(v as Dictionary)["主武器已销毁"] = true
	同步轮盘双响冷却(ctx, 响, 艾)
	var 名们: Array = [响, 艾].map(func(v): return "%s 剩 %s" % [
		str((v as Dictionary).get("name", "")), J.s(Btl.战意(v))])
	Btl.pushLog(ctx, "〔合体技〕%s 打出【轮盘双响】（各付 %s 战意：%s；两人的主武器本回合全部销毁；留在两人大招槽里进冷却 %s）" % [
		str(u.get("name", "")), J.s(各付), "、".join(名们), J.s(冷却Of(card))],
		J.merged({"类型": "合体技", "势力": 势力, "单位": u.get("key"), "卡牌ID": FacAtx.合体技ID,
			"卡牌": "轮盘双响", "各付": 各付, "参与者": FacAtx.合体技成员.duplicate(),
			"留大招槽": true, "主武器已销毁": true}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": "轮盘双响", "合体技": true, "各付": 各付,
		"参与者": FacAtx.合体技成员.duplicate(), "战意": Btl.战意(u),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")),
		"主武器已销毁": true, "cd": 冷却Of(card)}

static func 认领大招槽(_ctx: Dictionary, _u: Variant, 槽: Dictionary) -> String:
	if not (槽 is Dictionary):
		return ""
	var 卡 = (槽 as Dictionary).get("卡")
	if not (卡 is Dictionary) or str((卡 as Dictionary).get("id", "")) != FacAtx.合体技ID:
		return ""
	return "AtxFaction"

static func 大招不可打原因(ctx: Dictionary, u: Variant, _槽: Dictionary) -> Dictionary:
	var 因 := 轮盘双响不可打原因(ctx, u)
	return {"终局": 因 != "", "原因": 因}

static func 打出大招(ctx: Dictionary, u: Dictionary, 槽: Dictionary, target_id: Variant) -> Dictionary:
	return 打出轮盘双响(ctx, u, (槽 as Dictionary).get("卡"), target_id)

static func 大招结算后(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> void:
	尝试二次下注(ctx, u, 卡)

static func 大招收尾后(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> void:
	记打出大招(ctx, 卡, u)

## 任一参与者被击破时将【轮盘双响】从大招槽移出本场。
static func 合体移除(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 响 = Btl.找单位(ctx, "A1", "ally")
	var 艾 = Btl.找单位(ctx, "A2", "ally")
	var 死 := (响 != null and float((响 as Dictionary).get("hp", 0.0)) <= 0.0) \
		or (艾 != null and float((艾 as Dictionary).get("hp", 0.0)) <= 0.0)
	if not 死:
		return false
	var 移 := 0
	for u in Units.sideUnits("ally", ctx):
		if not ((u as Dictionary).get("大招槽") is Array):
			continue
		var 留: Array = []
		for 槽 in (u as Dictionary).大招槽:
			var 卡 = J.g(槽, "卡")
			if 槽 is Dictionary and 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == FacAtx.合体技ID:
				if not (ctx.get("移出牌") is Array):
					ctx["移出牌"] = []
				ctx["移出牌"].append(卡)
				移 += 1
				continue
			留.append(槽)
		(u as Dictionary)["大招槽"] = 留
	if 移 > 0:
		Btl.pushLog(ctx, "〔轮盘双响〕响介 / 艾克赛琳 有人被击破 → 这张合体技移出本场（%d 张）" % 移,
			{"类型": "移出本场", "势力": 势力, "卡牌ID": FacAtx.合体技ID, "移出": 移})
	return 移 > 0

# ---- 七、结算口径（纯读） ----
static func 本场计数(ctx: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {}
	return {
		"打出过ATX大招": J.truthy(ctx.get(打出大招键)),
		"加注回合": int(J.num0(ctx.get(加注回合键))),
		"降费": int(J.num0(ctx.get(降费键))),
		"读牌目标数": (ctx.get(读牌键) as Dictionary).size() if ctx.get(读牌键) is Dictionary else 0,
	}
