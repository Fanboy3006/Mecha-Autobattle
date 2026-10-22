## 职责：战报与描述 —— 记一条事件、单位 / 目标署名、增益与攻击结果摘要文。「一张牌打出了什么」这类文本都从这里出。
class_name BattleLog
extends RefCounted

## 记一条事件；`_rng_at` 与 log 一一对应（对账用）。
static func pushLog(ctx: Dictionary, text: String, extra: Variant = null) -> void:
	var r := {"回合": ctx.turn, "文本": text}
	if extra is Dictionary:
		for k in extra.keys():
			r[k] = extra[k]
	ctx.log.append(r)
	if ctx.has("_rng_at"):
		var rng = ctx.get("rng")
		ctx._rng_at.append(rng.steps if rng != null else -1)

## 按事件字典记一条（`文本` 走文案，其余键进事件）。
static func 记(ctx: Dictionary, 事件: Dictionary) -> void:
	if ctx == null or not (事件 is Dictionary):
		return
	var 文本 := str(事件.get("文本", ""))
	var 余 := 事件.duplicate()
	余.erase("文本")
	pushLog(ctx, 文本, 余)

static func 谁(u: Dictionary) -> Dictionary:
	return {"单位方": u.side, "单位位": u.slot}

static func 谁目标(u: Dictionary) -> Dictionary:
	return {"目标方": u.side, "目标位": u.slot}

## 援护日志的「剩几次」尾巴（纯读）。
static func 援护剩余文(护者: Variant) -> String:
	if not (护者 is Dictionary):
		return "本回合持续保护"
	var 上 := int(J.num0((护者 as Dictionary).get("靶机援护上限")))
	var 剩 := int(J.num0((护者 as Dictionary).get("靶机援护剩余")))
	if 上 > 0:
		return "剩余援护 %d/%d 次" % [剩, 上]
	var 掩: Variant = (护者 as Dictionary).get("掩护剩余")
	if 掩 != null:
		# [掩护额度]
		var 额 := 2 + maxi(0, int(J.num0((护者 as Dictionary).get("掩护补充", 0))))
		return "剩余援护 %d/%d 次" % [int(J.num0(掩)), 额]
	return "本回合持续保护"

## 攻击结果里的目标键（不是字典 = null）。
static func 目标名Of(结果: Variant) -> Variant:
	return 结果.get("目标") if 结果 is Dictionary else null

## 一条增益字典 → 中文短句。
static func _增益摘要(增: Dictionary) -> String:
	var 段: Array = []
	for k in 增.keys():
		var 键 := str(k)
		if 键 == "剩余" or 键 == "turns":
			continue
		var v = 增[k]
		if not J.is_num(v):
			continue
		var 名 := _增益中文(键)
		var n := J.num0(v)
		段.append("%s %s%s%s" % [名, "+" if n >= 0 else "", J.s(n), _增益单位(键)])
	if 段.is_empty():
		return "获得增益"
	var 时 := "本回合" if J.num0(增.get("剩余")) <= 1.0 else "%s 回合" % J.s(J.num0(增.get("剩余")))
	return "%s%s" % [时, "、".join(段)]

static func _增益中文(键: String) -> String:
	match 键:
		"hit":
			return "命中"
		"eva":
			return "闪避"
		"def":
			return "防御"
		"dmgMul":
			return "伤害"
		"受伤Mul":
			return "受到伤害"
		"critMod":
			return "暴击"
		"critDmg":
			return "暴击伤害"
	return 键

static func _增益单位(键: String) -> String:
	return "%" if 键 == "hit" or 键 == "eva" or 键 == "critMod" else ""

## 效果摘要数组 → 一句中文。
static func 效果摘要文(摘要: Variant) -> String:
	if not (摘要 is Array) or (摘要 as Array).is_empty():
		return ""
	var 段: Array = []
	for x in (摘要 as Array):
		var s := str(x).strip_edges()
		if not s.is_empty():
			段.append(s)
	if 段.is_empty():
		return ""
	return " → " + "、".join(段)

## `ctx.log` 里最后一条指定类型记录的文本（没有 = 空串）。
static func _最后一条文(ctx: Variant, 类型们: Array) -> String:
	if not (ctx is Dictionary):
		return ""
	var 行 = (ctx as Dictionary).get("log")
	if not (行 is Array):
		return ""
	for i in range((行 as Array).size() - 1, -1, -1):
		var e: Variant = (行 as Array)[i]
		if not (e is Dictionary):
			continue
		if J.inc(类型们, str((e as Dictionary).get("类型", ""))):
			return str((e as Dictionary).get("文本", ""))
	return ""

## 打出攻击牌的结果 → 效果摘要数组。
static func 攻击结果摘要(结果: Variant) -> Array:
	var 出: Array = []
	if not (结果 is Dictionary):
		return 出
	var d: Dictionary = 结果
	var 文 := str(d.get("文本", ""))
	if not 文.is_empty():
		出.append(文)
	if J.num0(d.get("击破")) > 0.0:
		出.append("击破 %s 台" % J.s(J.num0(d.get("击破"))))
	if d.get("回复") != null and J.num0(d.get("回复")) > 0.0:
		出.append("回复 %s HP" % J.s(J.num0(d.get("回复"))))
	if d.get("列") != null:
		出.append("第 %s 列放烟（每段命中 -30）" % J.s(int(J.num0(d.get("列"))) + 1))
	return 出
