## 职责：Boss「宿敌」彩蛋骨架（B 稿 N1 宿敌在场 / N2 指定角色修正 / N3 猎杀名单）。只读敌机模板的 `宿敌` 字段。
## 台词只在私密仓库；这里只写机制与一行通用战报。
class_name Rival
extends RefCounted

## 我方机体的角色键（重复上场时去掉 `#n`）。
static func 键Of(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	return str(J.or_(u.get("tplKey"), u.get("key")))

static func _我方键们(ctx: Dictionary) -> Array:
	var 出 := []
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			出.append(键Of(u))
	return 出

static func _势力数(ctx: Dictionary, 势力: String) -> int:
	var n := 0
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and str(J.g(u.get("tags"), "势力")) == 势力:
			n += 1
	return n

## 一条宿敌条目的条件成立吗：`在场`（任一）/ `在场全部` / `在场至少 {键们, 数}` / `势力至少 {势力: 数}`。
static func 条件成立(ctx: Dictionary, 件: Variant) -> bool:
	if not (件 is Dictionary):
		return false
	var 键们 := _我方键们(ctx)
	if J.is_arr(件.get("在场")) and not (件.在场 as Array).any(func(k): return 键们.has(str(k))):
		return false
	if J.is_arr(件.get("在场全部")) and not (件.在场全部 as Array).all(func(k): return 键们.has(str(k))):
		return false
	if 件.get("在场至少") is Dictionary:
		var 至: Dictionary = 件.在场至少
		if (J.or_(至.get("键们"), []) as Array).filter(func(k): return 键们.has(str(k))).size() < int(J.num0(至.get("数"))):
			return false
	if 件.get("势力至少") is Dictionary:
		for 势 in (件.势力至少 as Dictionary).keys():
			if _势力数(ctx, str(势)) < int(J.num0(件.势力至少[势])):
				return false
	return true

## 开局：逐台敌机看 `宿敌` 条目，成立的记到 `_宿敌生效`，并兑现开场效果（词条 / 开场 HP / 无视力场名单）。
static func 开局初始化(ctx: Dictionary) -> void:
	for e in J.or_(ctx.get("enemies"), []):
		if not (e is Dictionary) or not J.is_arr(e.get("宿敌")):
			continue
		var 生效 := []
		for 条 in e.宿敌:
			if 条 is Dictionary and 条件成立(ctx, 条.get("条件")):
				生效.append(条)
		if 生效.is_empty():
			continue
		e["_宿敌生效"] = 生效
		var 名们 := []
		for 条 in 生效:
			for t in J.or_(条.get("词条"), []):
				Traits.应用词条到单位(e, t, null)
			if J.num(条.get("开场HP比")) > 0.0:
				e.hp = maxf(1.0, J.round(float(e.hp) * J.num(条.开场HP比)))
			if J.is_arr(条.get("无视力场")):
				e["_无视力场键"] = J.concat(J.or_(e.get("_无视力场键"), []), 条.无视力场)
			if 条.get("清屏障") == true:
				e.barrierLeft = 0.0
			for k in J.or_(J.g(条.get("条件"), "在场"), []):
				if _我方键们(ctx).has(str(k)) and not 名们.has(str(k)):
					名们.append(str(k))
		Btl.pushLog(ctx, "〔宿敌〕%s 认出了老对手%s" % [str(e.get("name", "")), ("（" + "、".join(名们) + "）") if not 名们.is_empty() else ""],
			J.merged({"类型": "宿敌", "单位": e.get("key"), "条目数": 生效.size()}, Btl.谁(e)))

static func _生效(e: Variant) -> Array:
	return J.or_(e.get("_宿敌生效"), []) if e is Dictionary else []

## 猎杀名单：名单里的角色还活着、而且这一把武器够得着 → 只许选名单里的人（预告与实战同源）。
static func 可选目标(ctx: Dictionary, actor: Variant, target: Variant, w: Variant) -> Dictionary:
	var 单 := []
	var 档 := ""
	for 条 in _生效(actor):
		单 = J.concat(单, J.or_(条.get("猎杀"), []))
		if J.truthy(条.get("猎杀档")):
			档 = str(条.猎杀档)
	if 单.is_empty() and 档.is_empty():
		return {"终局": false}
	var 敌们 := Units.livingOf(Units.otherSide(actor.side), ctx)
	var 名单人 := 敌们.filter(func(u): return 单.has(键Of(u)) or (not 档.is_empty() and str(J.at(Db.T.TIER, 键Of(u))) == 档))
	名单人 = 名单人.filter(func(u): return Reach.近战可达(actor, w, u, 敌们))
	if 名单人.is_empty() or 名单人.has(target):
		return {"终局": false}
	return {"终局": true, "可选": false, "原因": "宿敌：先打名单上的人"}

## 指定角色修正：名单角色打这台 Boss 增伤 / 斩杀线；Boss 自己的宿敌伤害倍率。
static func 攻方伤害倍率(_ctx: Variant, att: Variant, def: Variant, _w: Variant) -> float:
	var 倍 := 1.0
	for 条 in _生效(att):
		if J.num(条.get("伤害倍率")) > 0.0:
			倍 *= J.num(条.伤害倍率)
	var 键 := 键Of(att)
	for 条 in _生效(def):
		var 增 = J.g(条.get("增伤"), 键)
		if J.finite(增):
			倍 *= 1.0 + float(增) / 100.0
		var 线 = J.g(条.get("斩杀线"), 键)
		if J.finite(线) and float(def.get("hp", 0.0)) <= float(def.get("maxHp", 1.0)) * float(线) / 100.0:
			倍 *= 3.0
	return 倍
