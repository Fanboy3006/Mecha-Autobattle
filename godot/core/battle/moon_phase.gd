## 职责：月球王国的【月相】状态机、【随侍】判定与回合级状态（月面偏导 / 拘束 / 月球护盾 / 月华溢流 / 不动如山）。
## 约定：全队状态挂在 `ctx.月球`；本回合给出的护盾记在 `u.月球护盾`，下个我方阶段初按记账扣回。
class_name MoonPhase
extends RefCounted

const 势力 := "月球王国"
const 王女键 := "M1"
const 盈月 := "盈月"
const 残月 := "残月"
const 祝福 := "祝福"
## 【月相仪典】的轮转顺序。
const 仪典下一个 := {"残月": "盈月", "盈月": "祝福", "祝福": "残月"}
const 拘束源 := "拘束"
const 拘束增益 := {"def": -20.0, "eva": -15.0, "剩余": 1.0}
const 溢流上限比 := 0.2

# ---- 一、成员与随侍（纯读）----
static func 是月球王国(u: Variant) -> bool:
	return Fac.是我方势力(u, 势力)

static func 活着(u: Variant) -> bool:
	return u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0

static func 键(u: Variant) -> String:
	return Units._键Of(u)

static func 是王女(u: Variant) -> bool:
	return 是月球王国(u) and 键(u) == 王女键

static func 王女(ctx: Variant) -> Variant:
	if not (ctx is Dictionary):
		return null
	for a in J.or_((ctx as Dictionary).get("allies"), []):
		if 活着(a) and 是王女(a):
			return a
	return null

static func 前排(ctx: Variant, u: Variant) -> bool:
	return Fm.是前排有效(u, ctx)

## Feena 十字相邻格上存活的月球王国成员（[随侍]）。
static func 随侍们(ctx: Variant) -> Array:
	var 菲 = 王女(ctx)
	if 菲 == null:
		return []
	var 位们: Array = Fm.十字相邻位(float(菲.slot))
	var 出: Array = []
	for a in Units.livingOf("ally", ctx):
		if not is_same(a, 菲) and 是月球王国(a) and 位们.has(int(a.slot)):
			出.append(a)
	return 出

static func 含(们: Array, u: Variant) -> bool:
	for a in 们:
		if is_same(a, u):
			return true
	return false

static func 随侍数(ctx: Variant) -> int:
	return 随侍们(ctx).size()

static func 是随侍(ctx: Variant, u: Variant) -> bool:
	return 含(随侍们(ctx), u)

## ★ 牌的触发条件：Feena 本人要随侍数 ≥ 1，其他成员要自己与 Feena 十字相邻。
static func 随侍达成(ctx: Variant, u: Variant) -> bool:
	if 是王女(u):
		return 随侍数(ctx) >= 1
	return 是月球王国(u) and 是随侍(ctx, u)

# ---- 二、全队状态 ----
static func 状态(ctx: Dictionary) -> Dictionary:
	if not (ctx.get("月球") is Dictionary):
		ctx["月球"] = {"月相": "", "到过": [], "切换次数": 0, "余响总伤": 0.0, "随侍触发": 0, "月光抽牌": 0,
			"领域回合": -1.0, "拘束必中回合": -1.0, "打出过大招": false, "随侍": []}
	return ctx["月球"]

static func 月相(ctx: Variant) -> String:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get("月球") is Dictionary):
		return ""
	return str((ctx as Dictionary).月球.get("月相", ""))

static func 到过(ctx: Variant) -> Array:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get("月球") is Dictionary):
		return []
	return (ctx as Dictionary).月球.get("到过", [])

## 开局月相按 Feena 的实际排位：前排 = 盈月、后排 = 残月（祝福只能打牌切入）。
static func 初始化(ctx: Dictionary) -> void:
	var 状 := 状态(ctx)
	var 菲 = 王女(ctx)
	if 菲 == null:
		return
	var 相 := 盈月 if Fm.rowOfSlot(float(菲.slot)) == Fm.ROW_FRONT else 残月
	状["月相"] = 相
	状["到过"] = [相]
	状["随侍"] = 随侍们(ctx).map(func(a): return a.key)
	Btl.pushLog(ctx, "〔月相〕%s 开战站在%s → 进入【%s】" % [菲.name, Fm.位名(float(菲.slot)), 相],
		J.merged({"类型": "月相", "月相": 相, "开局": true}, Btl.谁(菲)))

static func 切换月相(ctx: Dictionary, 新: String, 来源: String) -> void:
	var 状 := 状态(ctx)
	var 菲 = 王女(ctx)
	状["月相"] = 新
	if not (状.到过 as Array).has(新):
		(状.到过 as Array).append(新)
	状["切换次数"] = int(状.get("切换次数", 0)) + 1
	Btl.pushLog(ctx, "〔月相切换〕%s 进入【%s】！（%s）" % [str((菲 as Dictionary).get("name", "Feena")) if 菲 != null else "Feena", 新, 来源],
		J.merged({"类型": "月相切换", "月相": 新, "来源": 来源}, Btl.谁(菲) if 菲 != null else {}))

## 换位后：只重算随侍名单（月相不变），名单变了才写战报。
static func 换位后刷新(ctx: Dictionary) -> void:
	var 状 := 状态(ctx)
	var 新: Array = 随侍们(ctx).map(func(a): return a.key)
	if 新 == 状.get("随侍", []):
		return
	状["随侍"] = 新
	Btl.pushLog(ctx, "〔随侍〕换位后 Feena 的随侍：%s（%d 人；月相仍是【%s】）" % [
		"、".join(随侍们(ctx).map(func(a): return a.name)) if not 新.is_empty() else "没有", 新.size(), 月相(ctx)],
		{"类型": "随侍", "随侍": 新, "月相": 月相(ctx)})

# ---- 三、月相效果（全额 = 月相大招 / 半额 = 月光共鸣、月华流转）----
static func 释放月相(ctx: Dictionary, 全额: bool) -> Array:
	var 菲 = 王女(ctx)
	if 菲 == null:
		return ["Feena 不在场，月相不生效"]
	match 月相(ctx):
		盈月:
			var 盾 := J.round(float(菲.maxHp) * (0.15 if 全额 else 0.08))
			var 们: Array = [菲] + 随侍们(ctx)
			for a in 们:
				给护盾(a, 盾)
			return ["〔盈月〕护盾 %s → %s" % [J.s(盾), "、".join(们.map(func(a): return a.name))]]
		残月:
			return 余响(ctx, 1800.0 if 全额 else 900.0)
		祝福:
			var 随: Array = [菲] + 随侍们(ctx)
			var 全体12 := 全额 and Fm.rowOfSlot(float(菲.slot)) != Fm.ROW_FRONT
			for a in Units.livingOf("ally", ctx):
				var 比 := 0.12 if 全体12 else ((0.12 if 全额 else 0.06) if 含(随, a) else (0.06 if 全额 else 0.03))
				治疗(ctx, 菲, a, 比, 0.0)
			return ["〔祝福〕全队回复（%s）" % ("全体 12%" if 全体12 else ("随侍 12% / 其余 6%" if 全额 else "随侍 6% / 其余 3%"))]
	return []

## 【残月的余响】：HP 最高的 (1 + 随侍数) 台敌机各受一段固定伤害（月蚀领域本回合 ×1.5）。
static func 余响(ctx: Dictionary, 威力: float) -> Array:
	var 状 := 状态(ctx)
	var 敌们: Array = Units.livingOf("enemy", ctx)
	J.sort(敌们, func(a, b):
		var d := float(b.hp) - float(a.hp)
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	var n := mini(1 + 随侍数(ctx), 敌们.size())
	var 值 := 威力
	if J.same(状.get("领域回合"), ctx.get("turn")):
		值 = J.round(威力 * 1.5)
	var 打: Array = []
	for i in n:
		var 实 := CardEffects._固定伤害(ctx, 敌们[i], 值)
		状["余响总伤"] = float(状.get("余响总伤", 0.0)) + 实
		打.append("%s −%s" % [敌们[i].name, J.s(实)])
	Btl.pushLog(ctx, "〔残月的余响〕%d 段 × %s：%s" % [n, J.s(值), "、".join(打) if not 打.is_empty() else "没有敌机"],
		{"类型": "残月余响", "段数": n, "威力": 值})
	return ["余响 %s" % "、".join(打)]

# ---- 四、护盾 / 治疗 / 状态 ----
## 「至下个我方阶段开始」的护盾：记账，阶段初扣回 min(剩余护盾, 本回合给出)。
static func 给护盾(u: Dictionary, 值: float) -> float:
	var v := Btl.加卡牌护盾(u, 值)
	u["月球护盾"] = float(u.get("月球护盾", 0.0)) + v
	return v

## 回复 `比 × 最大 HP`；`溢流倍 > 0` 时溢出部分转护盾（[月华溢流]，每回合上限 20% 最大 HP）。
static func 治疗(ctx: Dictionary, _施放者: Variant, u: Dictionary, 比: float, 溢流倍: float) -> float:
	if not 活着(u):
		return 0.0
	var 量 := J.round(float(u.maxHp) * 比)
	var 实 := minf(量, float(u.maxHp) - float(u.hp))
	u["hp"] = float(u.hp) + 实
	var 溢 := 量 - 实
	if 溢流倍 > 0.0 and 溢 > 0.0:
		var 余额 := J.round(float(u.maxHp) * 溢流上限比) - float(u.get("月华溢流盾", 0.0))
		var 盾 := minf(J.round(溢 * 溢流倍), 余额)
		if 盾 > 0.0:
			给护盾(u, 盾)
			u["月华溢流盾"] = float(u.get("月华溢流盾", 0.0)) + 盾
			Btl.pushLog(ctx, "〔月华溢流〕%s 溢出 %s → 护盾 %s" % [u.name, J.s(溢), J.s(盾)],
				J.merged({"类型": "月华溢流", "溢出": 溢, "护盾": 盾}, Btl.谁(u)))
	return 实

static func 挂拘束(ctx: Dictionary, e: Dictionary) -> void:
	Btl.换同源增益(e, 拘束源, 拘束增益)
	Btl.pushLog(ctx, "〔拘束〕%s 防御 -20、闪避 -15（至下个我方阶段开始）" % e.name,
		J.merged({"类型": "拘束"}, Btl.谁目标(e)))

static func 有拘束(u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	for b in J.or_((u as Dictionary).get("buffs"), []):
		if b is Dictionary and str(b.get("src", "")) == 拘束源:
			return true
	return false

# ---- 五、受击钩子：月面偏导 / 月相修正 / 不动如山 ----
static func 受击前(_ctx: Dictionary, _att: Variant, def: Variant) -> void:
	if def is Dictionary and J.truthy((def as Dictionary).get("月面偏导")):
		(def as Dictionary)["月面偏导待消"] = true

## 每个命中段都会来一次：月面偏导只吃第一段（吃完就移除）。
static func 受方伤害倍率(ctx: Variant, def: Variant) -> float:
	if not (def is Dictionary) or not 是月球王国(def):
		return 1.0
	var d: Dictionary = def
	if J.truthy(d.get("月面偏导待消")):
		d.erase("月面偏导待消")
		d.erase("月面偏导")
		if ctx is Dictionary:
			Btl.pushLog(ctx, "〔月面偏导〕%s 抵消首段伤害！" % d.name, J.merged({"类型": "月面偏导"}, Btl.谁(d)))
		return 0.0
	var 倍 := 1.0
	if 是王女(d):
		var 相 := 月相(ctx)
		if 相 == 盈月:
			倍 *= 0.85
		elif 相 == 残月:
			倍 *= 1.2
	if J.truthy(d.get("不动如山中")):
		倍 *= 0.8
	return 倍

static func 受击后(def: Dictionary) -> void:
	def.erase("月面偏导待消")

# ---- 六、我方阶段初：回合级状态到期 + 祝福回战意 ----
static func 阶段初(ctx: Dictionary) -> void:
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		var 给 := float(u.get("月球护盾", 0.0))
		if 给 > 0.0:
			u["shieldHp"] = maxf(0.0, J.num0(u.get("shieldHp")) - minf(J.num0(u.get("shieldHp")), 给))
		for k in ["月球护盾", "月华溢流盾", "月面偏导", "月面偏导待消", "不动如山中", "月球下张命中", "月球余响共鸣"]:
			u.erase(k)
	if 月相(ctx) != 祝福:
		return
	var 菲 = 王女(ctx)
	if 菲 == null:
		return
	var 们: Array = [菲] + 随侍们(ctx)
	for a in 们:
		Btl.加战意(a, 3.0, ctx, "祝福")
	Btl.pushLog(ctx, "〔祝福〕%s 战意 +3" % "、".join(们.map(func(a): return a.name)), {"类型": "祝福", "人数": 们.size()})
