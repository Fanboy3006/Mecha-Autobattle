## 72-势力-5：秘银（SRT 交叉训练：情报岗挂标定 → 作战岗兑现破防；倒下接力）。
class_name FacMith
extends RefCounted

const 秘银标定来源 := "势力·秘银"

static func 秘银参数() -> Dictionary:
	return Fac.势力参数("秘银")

static func 是秘银(u: Variant) -> bool:
	return Fac.是我方势力(u, "秘银")

static func 是秘银情报岗(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 秘银参数()
	return 是秘银(u) and J.inc(J.or_(参.get("情报岗"), []), u.key)

static func 是秘银作战岗(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 秘银参数()
	return 是秘银(u) and J.inc(J.or_(参.get("作战岗"), []), u.key)

static func 秘银岗位(u: Variant, p: Variant) -> String:
	if 是秘银情报岗(u, p):
		return "情报岗"
	if 是秘银作战岗(u, p):
		return "作战岗"
	return "其他"

static func 键名(g: Variant) -> Variant:
	if g == null:
		return ""
	return J.or_(J.or_(g.get("名"), g.get("键")), "")

static func 秘银战场(ctx: Dictionary) -> Dictionary:
	if not J.truthy(ctx.get("秘银")):
		ctx.秘银 = {"倒下接力次数": 0.0, "标定挂过": 0.0, "兑现次数": 0.0}
	return ctx.秘银

static func 标定条目们(u: Variant) -> Array:
	return J.or_(u.get("debuffs") if u != null else null, []).filter(func(d): return d != null and J.truthy(d.get("标定")))

static func 标定层数(d: Variant) -> float:
	return maxf(0.0, J.num0(d.get("剩余")) if d != null else 0.0)

static func 标定是挂者(d: Variant, u: Variant) -> bool:
	return d != null and u != null and J.some(J.or_(d.get("挂者们"), []), func(g): return g.get("键") == u.key)

static func 秘银挂标定(ctx: Variant, 挂者: Variant, 目标: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else 秘银参数()
	if ctx == null or 挂者 == null or 目标 == null:
		return 0.0
	if not 是秘银情报岗(挂者, 参):
		return 0.0
	if 目标.side == 挂者.side:
		return 0.0
	var 标: Dictionary = J.or_(参.get("标定"), {})
	var 上限 := maxf(1.0, J.round(J.num0(标.get("最多层数")))) if J.truthy(J.num0(标.get("最多层数"))) else 1.0
	var 每层 := J.num0(标.get("破防百分比"))
	var d = J.find(标定条目们(目标), func(x): return J.truthy(x.get("挂者们")) and not x.挂者们.is_empty())
	if d == null:
		d = {"src": 秘银标定来源, "标定": true, "挂者们": [], "剩余": 0.0, "pct": 0.0, "已兑现": false, "兑现者": null, "兑现回合": null}
		目标.debuffs = J.concat(J.or_(目标.get("debuffs"), []), [d])
	var 前 := 标定层数(d)
	if 前 >= 上限:
		Fac.势力记录(ctx, "秘银 %s（情报岗）又标定了 %s，但它已经到层数上限 %s 层了（不再加）" % [挂者.name, 目标.name, J.s(上限)],
			{"势力": "秘银", "特色": "标定", "结果": "到上限", "单位": 挂者.key, "单位方": 挂者.side, "单位位": 挂者.slot,
				"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot, "层数": 前, "层数上限": 上限})
		return 前
	if not 标定是挂者(d, 挂者):
		d.挂者们 = J.concat(J.or_(d.get("挂者们"), []), [{"键": 挂者.key, "名": 挂者.name}])
	d.剩余 = 前 + 1.0
	d.pct = float(d.剩余) * 每层 if J.truthy(d.get("已兑现")) else 0.0
	var 场 := 秘银战场(ctx)
	场.标定挂过 = float(场.标定挂过) + 1.0
	if J.truthy(ctx.get("战况计数")):
		ctx.战况计数.秘银标定 = J.num0(ctx.战况计数.get("秘银标定")) + 1.0
	Fac.势力记录(ctx, "秘银 %s（情报岗）标定 %s：%s/%s 层%s" % [挂者.name, 目标.name, J.s(d.剩余), J.s(上限),
		"（已兑现过，破防 −%s%%）" % J.s(d.pct) if J.truthy(d.get("已兑现")) else "（还没兑现：要另一台作战岗去打它）"],
		{"势力": "秘银", "特色": "标定", "结果": "挂标定", "单位": 挂者.key, "单位方": 挂者.side, "单位位": 挂者.slot,
			"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot, "层数": d.剩余, "层数上限": 上限,
			"破防百分比": 每层, "挂者们": J.or_(d.get("挂者们"), []).map(func(g): return g.get("键"))})
	刷新秘银缓存(ctx, 参)
	return float(d.剩余)

static func 秘银兑现(ctx: Variant, 攻击者: Variant, 目标: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else 秘银参数()
	var 标: Dictionary = J.or_(参.get("标定"), {})
	if ctx == null or 攻击者 == null or 目标 == null:
		return 0.0
	if J.or_(参.get("兑现收益"), {}).get("破防") == false:
		return 0.0
	if not 是秘银作战岗(攻击者, 参):
		return 0.0
	if 目标.side == 攻击者.side:
		return 0.0
	var 每层 := J.num0(标.get("破防百分比"))
	var 兑了 := 0.0
	for d in 标定条目们(目标):
		if J.truthy(d.get("已兑现")):
			continue
		if 参.get("禁止同台兑现") != false and 标定是挂者(d, 攻击者):
			Fac.势力记录(ctx, "秘银 %s 想兑现自己挂的标定（%s）：**同一台不能兑现自己挂的标定** → 不生效（标定还是 %s 层，破防还是 0）" % [攻击者.name, 目标.name, J.s(d.剩余)],
				{"势力": "秘银", "特色": "标定", "结果": "自己兑现（不生效）", "单位": 攻击者.key, "单位方": 攻击者.side,
					"单位位": 攻击者.slot, "目标": 目标.key, "目标位": 目标.slot, "层数": d.剩余, "破防百分比": 每层, "破防后defMul": 1.0})
			continue
		var 挂者们 = J.or_(d.get("挂者们"), []).map(func(g): return 键名(g))
		var 首 = J.or_(J.at(J.or_(d.get("挂者们"), []), 0), {})
		var 挂者 = J.find(ctx.allies, func(a): return a.key == 首.get("键"))
		if 挂者 == null:
			continue
		d.已兑现 = true
		d.兑现者 = 攻击者.key
		d.兑现回合 = ctx.turn
		d.pct = float(d.剩余) * 每层
		var 场 := 秘银战场(ctx)
		场.兑现次数 = float(场.兑现次数) + 1.0
		兑了 += 1.0
		if J.truthy(ctx.get("战况计数")):
			ctx.战况计数.秘银标定 = J.num0(ctx.战况计数.get("秘银标定")) + 1.0
		Fac.势力记录(ctx, "秘银 %s（作战岗）兑现 %s 挂在 %s 身上的标定：%s 层 → 破防 −%s%%（目标现在按 ×%.2f 算装甲 / 防御，走的是现成管线）" % [
			攻击者.name, "、".join(挂者们), 目标.name, J.s(d.剩余), J.s(d.pct), Calc.defMul(目标)],
			{"势力": "秘银", "特色": "标定", "结果": "兑现", "单位": 攻击者.key, "单位方": 攻击者.side, "单位位": 攻击者.slot,
				"挂者": 挂者.key, "挂者们": J.or_(d.get("挂者们"), []).map(func(g): return g.get("键")), "挂者位": 挂者.slot,
				"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot,
				"层数": d.剩余, "破防百分比": 每层, "破防后defMul": Calc.defMul(目标)})
	if 兑了 != 0:
		刷新秘银缓存(ctx, 参)
	return 兑了

static func 秘银取消被挡(attacker: Variant, 目标: Variant) -> bool:
	if attacker == null or attacker.get("side") != "ally":
		return false
	if 目标 == null:
		return false
	if J.or_(秘银参数().get("兑现收益"), {}).get("取消被挡") == false:
		return false
	return J.some(标定条目们(目标), func(d): return d.get("已兑现") == true)

static func 倒下接力(ctx: Variant, 被击破者: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else 秘银参数()
	var 接: Dictionary = J.or_(参.get("倒下接力"), {})
	var 上限 := maxf(0.0, J.round(J.num0(接.get("每场次数"))))
	if ctx == null or 被击破者 == null or 上限 <= 0:
		return 0.0
	if 被击破者.side != "ally":
		return 0.0
	if 接.get("只认秘银倒下") != false and not 是秘银(被击破者):
		return 0.0
	var 战场 := 秘银战场(ctx)
	if J.num0(战场.get("倒下接力次数")) >= 上限:
		return 0.0
	var 岗 := 秘银岗位(被击破者, 参)
	var 候选 := Fac.势力在场("秘银", ctx).filter(func(u): return not is_same(u, 被击破者))
	J.sort(候选, func(a, b):
		var d1 := 0.0
		if 接.get("同岗位优先") != false:
			d1 = (0.0 if 秘银岗位(a, 参) == 岗 else 1.0) - (0.0 if 秘银岗位(b, 参) == 岗 else 1.0)
		return d1 if d1 != 0 else float(a.slot) - float(b.slot))
	if 候选.is_empty():
		return 0.0
	var 接管者 = 候选[0]
	var 原 = 被击破者.slot
	var 接管者原位 = 接管者.slot
	接管者.slot = 原
	战场.倒下接力次数 = J.num0(战场.get("倒下接力次数")) + 1.0
	var 再动: bool = 接.get("再动一次") != false
	if 再动:
		ctx.again.append(接管者)
	Fac.势力记录(ctx, "秘银（SRT 交叉训练·倒下接力）%s 被击破 → %s 接管他的岗位（%s：%s → %s）%s　每场 %s 次，本场已用 %s 次" % [
		被击破者.name, 接管者.name, 岗, Fm.位名(接管者原位), Fm.位名(原), "并立刻再行动一次" if 再动 else "", J.s(上限), J.s(战场.倒下接力次数)],
		{"势力": "秘银", "特色": "倒下接力", "结果": "接管", "单位": 接管者.key, "单位方": 接管者.side, "单位位": 接管者.slot,
			"接管者原位": 接管者原位, "被击破者": 被击破者.key, "被击破者位": 原, "岗位": 岗, "每场次数": 上限,
			"已用次数": 战场.倒下接力次数, "再动": 再动})
	刷新秘银缓存(ctx, 参)
	return 1.0

static func 刷新秘银缓存(ctx: Variant, p: Variant) -> void:
	if ctx == null:
		return
	var 参 = p if J.truthy(p) else 秘银参数()
	var 上限 := maxf(0.0, J.round(J.num0(J.or_(参.get("倒下接力"), {}).get("每场次数"))))
	var 已用 := J.num0(秘银战场(ctx).get("倒下接力次数"))
	for u in Units.sideUnits("ally", ctx):
		if not 是秘银(u):
			continue
		var 状 := Fac.势力状态(u, "秘银")
		状.岗位 = 秘银岗位(u, 参)
		状.接力上限 = 上限
		状.接力已用 = 已用
		状.接力剩余 = maxf(0.0, 上限 - 已用)
		状.标定名单 = []
		状.兑现名单 = []
	for t in Units.livingUnits(ctx):
		for d in 标定条目们(t):
			for g in J.or_(d.get("挂者们"), []):
				var 挂 = J.find(ctx.allies, func(a): return a.key == g.get("键"))
				if 挂 == null or not 是秘银(挂):
					continue
				J.or_(Fac.势力状态(挂, "秘银").get("标定名单"), []).append({
					"目标": t.key, "目标名": t.name, "目标位": t.slot, "层数": 标定层数(d),
					"已兑现": J.truthy(d.get("已兑现")), "兑现者": J.or_(d.get("兑现者"), null), "pct": J.or_(d.get("pct"), 0.0),
				})
			if not J.truthy(d.get("兑现者")):
				continue
			var 兑 = J.find(ctx.allies, func(a): return a.key == d.兑现者)
			if 兑 == null or not 是秘银(兑):
				continue
			J.or_(Fac.势力状态(兑, "秘银").get("兑现名单"), []).append({
				"目标": t.key, "目标名": t.name, "目标位": t.slot, "层数": 标定层数(d), "pct": J.or_(d.get("pct"), 0.0), "回合": d.get("兑现回合"),
			})

static func 秘银开局(ctx: Dictionary, p: Variant) -> void:
	var 参 = p if J.truthy(p) else 秘银参数()
	ctx.秘银 = {"倒下接力次数": 0.0, "标定挂过": 0.0, "兑现次数": 0.0}
	for u in Units.sideUnits("ally", ctx):
		if not 是秘银(u):
			continue
		var 状 := Fac.势力状态(u, "秘银")
		状.岗位 = 秘银岗位(u, 参)
		状.标定名单 = []
		状.兑现名单 = []
		状.接力上限 = maxf(0.0, J.round(J.num0(J.or_(参.get("倒下接力"), {}).get("每场次数"))))
		状.接力已用 = 0.0
		状.接力剩余 = 状.接力上限
	刷新秘银缓存(ctx, 参)

static func 秘银回合结束(ctx: Dictionary, p: Variant) -> void:
	var 参 = p if J.truthy(p) else 秘银参数()
	var 每层 := J.num0(J.or_(参.get("标定"), {}).get("破防百分比"))
	for t in ctx.allies + ctx.enemies:
		for d in 标定条目们(t):
			d.pct = 标定层数(d) * 每层 if J.truthy(d.get("已兑现")) else 0.0
	刷新秘银缓存(ctx, 参)

static func 秘银友军攻击后(ctx: Variant, 攻击者: Variant, 目标: Variant, 一击: Variant, p: Variant) -> float:
	if ctx == null or 攻击者 == null or 目标 == null:
		return 0.0
	if 攻击者.side != "ally" or not (一击 != null and J.num(一击.get("伤害")) > 0):
		return 0.0
	return 秘银挂标定(ctx, 攻击者, 目标, p)
