## 72-势力-2：卫星国防军（SEED 觉醒）与流星小队（单独行动）。
class_name FacSeed
extends RefCounted

const 流星伤害来源 := "势力·流星小队"

static func _状(u: Variant, 势力: String) -> Variant:
	if u == null or not J.truthy(u.get("势力状态")):
		return null
	return u.势力状态.get(势力)

static func SEED累计(u: Variant) -> float:
	var s = _状(u, "卫星国防军")
	return J.num0(s.get("累计")) if s != null and J.truthy(s.get("累计")) else 0.0

static func SEED已觉醒(u: Variant) -> bool:
	var s = _状(u, "卫星国防军")
	return s != null and J.truthy(s.get("已觉醒"))

static func 有SEED(u: Variant) -> bool:
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, "seed")

static func SEED无尽(u: Variant, p: Variant) -> bool:
	return u != null and p != null and J.truthy(p.get("不封顶特技")) and u.get("trait") == p.不封顶特技

static func SEED重装(u: Variant, p: Variant) -> bool:
	if u == null or not J.truthy(u.get("tags")):
		return false
	var 分 = J.or_(p.get("重装分类") if p != null else null, "重装")
	return u.tags.get("战斗分类") == 分

static func SEED觉醒值(u: Variant) -> float:
	return Fac.势力觉醒值(u)

static func SEED闪避加成(u: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else Fac.势力参数("卫星国防军")
	if not 有SEED(u) or not SEED已觉醒(u) or SEED重装(u, 参):
		return 0.0
	return J.round(SEED觉醒值(u) * float(参.闪避系数))

static func SEED防御加成(u: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else Fac.势力参数("卫星国防军")
	if not 有SEED(u) or not SEED已觉醒(u) or not SEED重装(u, 参):
		return 0.0
	return J.round(SEED觉醒值(u) * float(参.防御系数))

static func SEED加成文字(u: Dictionary, p: Dictionary) -> String:
	if SEED重装(u, p):
		return "防御 +%s（重装：SEED 后不加闪避，改成防御 + 觉醒 × %s）" % [J.s(SEED防御加成(u, p)), J.s(p.防御系数)]
	return "闪避 +%s（= 觉醒 × %s）" % [J.s(SEED闪避加成(u, p)), J.s(p.闪避系数)]

static func 加SEED(u: Dictionary, n: float, ctx: Variant, p: Dictionary) -> float:
	var 参 := p
	if not Fac.是我方势力(u, "卫星国防军") or not 有SEED(u):
		return 0.0
	var 状 := Fac.势力状态(u, "卫星国防军")
	if J.truthy(状.get("已觉醒")) and not SEED无尽(u, 参):
		return 0.0
	var 满 := float(参.阈值)
	var 加 := n if SEED无尽(u, 参) else minf(n, 满 - J.num0(状.get("累计")))
	if 加 <= 0:
		return 0.0
	状.累计 = J.num0(状.get("累计")) + 加
	if not J.truthy(状.get("已觉醒")) and float(状.累计) >= 满:
		状.已觉醒 = true
		Fac.势力记录(ctx, "SEED 觉醒！%s 觉醒 %s：%s%s" % [u.name, J.s(SEED觉醒值(u)), SEED加成文字(u, 参), "（觉醒继续成长）" if SEED无尽(u, 参) else ""],
			{"势力": "卫星国防军", "特色": "SEED", "结果": "觉醒", "单位": u.key, "单位方": u.side, "单位位": u.slot, "觉醒": SEED觉醒值(u)})
	return 加

static func SEED开局(ctx: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		if not Fac.是我方势力(u, "卫星国防军"):
			continue
		var 状 := Fac.势力状态(u, "卫星国防军")
		状.累计 = 0.0
		状.已觉醒 = false

static func _加一队(队: Array, n: float, ctx: Dictionary, p: Dictionary) -> Array:
	var 得到 := []
	for u in 队:
		var 加 := 加SEED(u, n, ctx, p)
		if 加 != 0:
			得到.append("%s +%s" % [u.name, J.s(加)])
	return 得到

static func SEED回合结束(ctx: Dictionary, p: Dictionary) -> void:
	var 队 := Fac.势力在场("卫星国防军", ctx)
	if 队.is_empty():
		return
	if float(ctx.turn) + 1.0 < float(J.or_(p.get("第几回合起"), 2.0)):
		return
	var 得到 := _加一队(队, float(p.每回合), ctx, p)
	if 得到.is_empty():
		return
	Fac.势力记录(ctx, "卫星国防军 SEED：本回合在场每人觉醒 +%s（%s）" % [J.s(p.每回合), "、".join(得到)],
		{"势力": "卫星国防军", "特色": "SEED", "加觉醒": p.每回合, "单位们": 队.map(func(u): return u.key),
			"单位方们": 队.map(func(_u): return "ally"), "单位位们": 队.map(func(u): return u.slot)})

static func SEED击破(ctx: Dictionary, 击破者: Dictionary, 被击破者: Dictionary, p: Dictionary) -> void:
	if not Fac.是我方势力(击破者, "卫星国防军"):
		return
	if 被击破者.side == 击破者.side or 被击破者.side == "neutral":
		return
	var 队 := Fac.势力在场("卫星国防军", ctx)
	if 队.is_empty():
		return
	var 得到 := _加一队(队, float(p.每次击破), ctx, p)
	if 得到.is_empty():
		return
	Fac.势力记录(ctx, "卫星国防军 %s 击破敌机：在场每人觉醒 +%s（%s）" % [击破者.name, J.s(p.每次击破), "、".join(得到)],
		{"势力": "卫星国防军", "特色": "SEED", "加觉醒": p.每次击破, "击破者": 击破者.key, "被击破者": 被击破者.key,
			"单位们": 队.map(func(u): return u.key), "单位方们": 队.map(func(_u): return "ally"), "单位位们": 队.map(func(u): return u.slot)})

# ======================== 流星小队 ========================
static func 有流星单独行动(u: Variant) -> bool:
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, J.or_(Fac.势力参数("流星小队").get("特技"), "loneWolf"))

static func 流星孤立(u: Variant) -> bool:
	var s = _状(u, "流星小队")
	return s != null and J.truthy(s.get("孤立"))

static func 流星检查位(位: Variant) -> Array:
	var 相邻 := Fm.相邻位(位)
	var 前方 := Fm.遮挡位(位)
	return J.concat(相邻, 前方.filter(func(s): return not J.inc(相邻, s)))

static func 判定流星小队(ctx: Variant, p: Dictionary) -> void:
	if ctx == null:
		return
	var 参 := p
	var 队 := Fac.势力在场("流星小队", ctx)
	for u in 队:
		if not 有流星单独行动(u):
			continue
		var 状 := Fac.势力状态(u, "流星小队")
		var 检查 := 流星检查位(u.slot)
		var 挡路单位 := Units.livingOf("ally", ctx).filter(func(a): return not is_same(a, u) and J.inc(检查, a.slot))
		J.sort(挡路单位, func(a, b): return float(a.slot) - float(b.slot))
		var 挡路 := 挡路单位.map(func(a): return "%s %s" % [Fm.位名(a.slot), a.name])
		var 孤立 := 挡路.is_empty()
		var 变了: bool = 状.get("就绪") != true or 状.get("孤立") != 孤立
		状.孤立 = 孤立
		状.检查位 = 检查
		状.挡路 = 挡路
		状.就绪 = true
		u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != 流星伤害来源)
		if 孤立:
			u.buffs.append({"src": 流星伤害来源, "dmg": 参.伤害加成, "剩余": 1.0})
		if 变了:
			var 面 := "、".join(检查.map(func(s): return Fm.位名(s)))
			var 文: String
			if 孤立:
				文 = "流星小队 %s 单独行动成立（%s 的相邻 / 前方 %s 都没有队友）→ 伤害 +%s、闪避 +%s" % [u.name, Fm.位名(u.slot), 面, J.s(参.伤害加成), J.s(参.闪避加成)]
			else:
				文 = "流星小队 %s 单独行动失效（%s 在 %s 的相邻 / 前方）" % [u.name, "、".join(挡路), Fm.位名(u.slot)]
			Fac.势力记录(ctx, 文, {
				"势力": "流星小队", "特色": "单独行动", "结果": "成立" if 孤立 else "失效",
				"单位": u.key, "单位方": u.side, "单位位": u.slot, "检查位": 检查,
				"伤害加成": 参.伤害加成 if 孤立 else 0.0, "闪避加成": 参.闪避加成 if 孤立 else 0.0,
			})
