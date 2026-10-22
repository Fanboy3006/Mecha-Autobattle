## 职责：敌方意图预告（DECK-2）—— 算意图 / 算意图表 / 刷新敌方意图。预览与实际同源，只读、不掷随机数。
class_name BattleIntent
extends RefCounted

## 目标没传就自动挑一个：打人 → 血最低的活敌；修理 → 血比最低的活队友
static func _自动目标(ctx: Dictionary, u: Dictionary, 打人: bool) -> Variant:
	if 打人:
		var 敌 := Units.livingOf("enemy", ctx)
		if 敌.is_empty():
			return null
		var 排 := 敌.duplicate()
		J.sort(排, func(a, b):
			var d := float(a.hp) - float(b.hp)
			return d if d != 0.0 else float(a.slot) - float(b.slot))
		return 排[0]
	var 友 := Units.livingOf("ally", ctx)
	if 友.is_empty():
		return null
	var 排2 := 友.duplicate()
	J.sort(排2, func(a, b):
		var ra := float(a.hp) / maxf(1.0, float(a.maxHp))
		var rb := float(b.hp) / maxf(1.0, float(b.maxHp))
		var d := ra - rb
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	return 排2[0]

## 纯读：按敌方格位 0..7 顺序，对每台存活敌机用影子判断算一次行动。
static func 算意图(ctx: Dictionary) -> Array:
	var 出 := []
	if ctx == null:
		return 出
	var 敌们 := Units.livingOf("enemy", ctx)
	J.sort(敌们, func(a, b): return float(a.slot) - float(b.slot))
	for e in 敌们:
		if e == null:
			continue
		var 动作 = Boss.bossAction(e, ctx)
		var bp = Boss.Boss参数(e)
		var 条 := {
			"单位": e.key, "单位位": e.slot, "名称": e.name, "键": e.key, "位": e.slot, "位名": Fm.位名(float(e.slot)),
			"动作类型": "无", "武器": null, "武器名": null, "目标": null, "目标位": null, "目标位名": "",
			"目标名": null, "原目标": null, "期望": 0.0, "预计伤害": 0.0, "被挡": false, "命中修正": 0.0,
			"落点们": [], "落点": [], "形状": null, "大招": false, "是大招": false, "范围类型": null,
			"大技能": false, "是大技能": false, "Boss": bp != null, "Boss阶段": null, "蓄力": false,
		}
		var w = 动作.get("weapon") if 动作 is Dictionary else null
		var t = 动作.get("target") if 动作 is Dictionary else null
		if bp != null:
			条["Boss阶段"] = bp.get("第几阶段")
		if w is Dictionary:
			var 期望 := J.round(J.num0(动作.get("expected")))
			条["动作类型"] = "攻击"
			条["武器"] = str(w.get("name", ""))
			条["武器名"] = str(w.get("name", ""))
			条["期望"] = 期望
			条["预计伤害"] = 期望
			条["被挡"] = J.truthy(动作.get("被挡"))
			条["命中修正"] = -20.0 if J.truthy(动作.get("被挡")) else 0.0
			条["大招"] = Ai.isUltimate(w)
			条["是大招"] = 条.大招
			条["范围类型"] = str(Reach.rangeKindOf(w))
			条["大技能"] = J.truthy(动作.get("大技能"))
			条["是大技能"] = 条.大技能
			var 区 := Reach.isAreaKind(Reach.rangeKindOf(w))
			条["形状"] = (str(w.get("area", "row")) if 区 else "单格")
		var 终目标: Dictionary = t if t is Dictionary else {}
		if t is Dictionary:
			# 只问 `Btl.嘲讽(..., 预览 = true)` 这一处；`预览` 只读，绝不扣次数、绝不掷随机数。
			if w is Dictionary and not Reach.isAreaKind(Reach.rangeKindOf(w)):
				var 嘲 = Btl.嘲讽(ctx, e, t, true)
				if 嘲 is Dictionary:
					终目标 = 嘲
			var 原键 := str(动作.get("原目标")) if (动作 is Dictionary and J.truthy(动作.get("原目标"))) else str(t.get("key", ""))
			条["原目标"] = 原键
			条["目标"] = 终目标.key
			条["目标位"] = 终目标.slot
			条["目标位名"] = Fm.位名(float(终目标.slot))
			条["目标名"] = 终目标.name
		var 落点们 := []
		if w is Dictionary:
			if Reach.isAreaKind(Reach.rangeKindOf(w)):
				var 命中 = 动作.get("hit") if 动作 is Dictionary else null
				if 命中 is Array and not (命中 as Array).is_empty():
					for x in 命中:
						if x is Dictionary:
							落点们.append(x.slot)
				else:
					var 落位 = 动作.get("slot") if 动作 is Dictionary else null
					if 落位 == null and t is Dictionary:
						落位 = t.slot
					if 落位 != null:
						落点们 = Reach.areaSlots(w, Fm.rowOfSlot(float(落位)), Fm.colOfSlot(float(落位)))
			elif not 终目标.is_empty():
				落点们 = [终目标.slot]
		落点们 = J.sort_num(J.uniq(落点们))
		条["落点们"] = 落点们
		条["落点"] = 落点们
		if 动作 == null and bp != null:
			条["蓄力"] = true
		# [换位意图锁定] 三步规则的第几步、以及〔待机〕。
		if 动作 is Dictionary and J.truthy((动作 as Dictionary).get("换位方案")):
			条["换位方案"] = str((动作 as Dictionary).get("换位方案"))
		if 动作 is Dictionary and J.truthy((动作 as Dictionary).get("待机")):
			条["动作类型"] = "待机"
			条["待机"] = true
			条["射程不达待机"] = true
			条["待机原因"] = str((动作 as Dictionary).get("待机原因", ""))
		出.append(条)
	return 出

## 另一种取法：按单位键索引的字典（`算意图` 本身返回的是按格位 0..7 排好的数组）
static func 算意图表(ctx: Dictionary) -> Dictionary:
	var 表 := {}
	for 条 in 算意图(ctx):
		表[str(条.get("单位", ""))] = 条
	return 表

## 算完挂进 ctx（数组 + 两张按单位键 / 格位索引的表，表现层三种取法都能用）
static func 刷新敌方意图(ctx: Dictionary) -> Array:
	var 意图 := 算意图(ctx)
	if ctx != null:
		ctx["敌方意图"] = 意图
		var 表 := {}
		var 位表 := {}
		for 条 in 意图:
			表[str(条.get("单位", ""))] = 条
			位表[int(条.get("单位位", 0))] = 条
		ctx["敌方意图表"] = 表
		ctx["敌方意图位"] = 位表
	return 意图
