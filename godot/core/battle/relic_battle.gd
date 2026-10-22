## 93-藏品.js 的「开战应用」段（`藏品开战` / `应用藏品我方` / `应用藏品敌方` / `藏品单体效果` / `藏品层数`）。
## 唯一入口：`RelicBattle.apply_on_battle_start(ctx, relic_ids)`，由 `Setup.开局()` 在与 JS **完全相同**的时机调用
## （`60-战斗-3-开局与simulate.js:131`：ctx 造好 → 藏品开战 → 应用全场词条 → 武器开场冷却）。
##
## ★ DEBT-06（消除全局依赖）：JS 参考版从全局 `肉鸽.RUN.藏品` 读这一局的藏品；Godot 里**不再读全局** ——
##   藏品 id 数组由调用方从 `选项.get("藏品")` 取出来传进来。
##
## 与 JS 逐条对齐的三层落法（战棋 `23b-藏品.js:74-107`）：
##   ① 我方（`应用藏品我方`）：每件藏品先按「职业」挑（`数值.职业`）→ 累加 `mods`，`stack` 按**出击队伍里同职业台数**叠层；
##      `stat.hpPct` **逐件**改 maxHp / hp（每件各舍入一次，照 23b:86）；再叠整场的「混编 / 孤狼」两条；
##      最后按 `难度调整.藏品同类上限.我方` 夹一次，合成**一条** `{src:'藏品', 剩余:999, …}` 的常驻 buff 挂到 u.buffs，
##      并留一份 `u.藏品加成`（不参与计算，只给界面 / 测试看）。
##   ② 敌方（`应用藏品敌方`）：`foe` 直接加、`foeStack` 按我方出击职业人数叠层，按 `…上限.敌方` 夹一次后挂到每个敌人身上。
##   ③ 数值舍入一律 `JsCompat.js_round`（JS 的 Math.round）。**没有藏品时一个字段都不动** ——
##      `Setup.开局` 不传 `选项.藏品` 时这里立刻返回。
##
## ★ JS 的 `藏品开战` **一条日志都不写**（93-藏品.js 全文没有 `〔藏品〕`；`〔藏品〕` 只出现在大地图的
##   `拿藏品` / `战斗胜利发藏品` 那两段），这里也一条都不写 —— 逐条对拍要求如此。
class_name RelicBattle
extends RefCounted

## 40-单位.js:18 的 `战斗分类 = u => (u && u.tags && u.tags.战斗分类) || null`（**只看 tags**，不带敌方梯队兜底）
static func 战斗分类(u: Variant) -> Variant:
	var tags: Variant = J.g(u, "tags")
	if tags is Dictionary:
		var t: Variant = tags.get("战斗分类")
		if J.truthy(t):
			return t
	return null

## 藏品 id 数组 → 藏品表里的那几条（JS：`（藏品们 || []).map(id => 藏品表[id]).filter(Boolean)`）
static func 取件们(relic_ids: Variant) -> Array:
	var 表: Variant = Db.T.get("藏品表")
	var out := []
	for id in J.or_(relic_ids, []):
		var r: Variant = J.at(表, id) if 表 != null else null
		if r != null:
			out.append(r)
	return out

## 叠层：按「出击队伍里这些职业有几台」算层数（战棋 23b:77,91）
static func 藏品层数(件: Dictionary, 出击职业: Array) -> float:
	var 数值: Variant = J.g(件, "数值")
	var 层: Variant = J.or_(J.g(数值, "stack"), J.g(数值, "foeStack"))
	var 按: Variant = J.or_(J.g(层, "by"), [])
	var n := 0
	for c in 出击职业:
		if J.inc(按, c):
			n += 1
	return float(n)

## 这一件对某个职业的单体效果（mods / stat / stack）
static func 藏品单体效果(件: Dictionary, 职业: Variant, 出击职业: Array) -> Dictionary:
	var e: Variant = J.or_(J.g(件, "数值"), {})
	var 职业表: Variant = J.g(e, "职业")
	var 我的 := 职业表 == null or J.inc(职业表, 职业)
	var m := {}
	var mods: Variant = J.g(e, "mods")
	if mods != null and 我的:
		for k in (mods as Dictionary).keys():
			m[k] = J.num0(m.get(k)) + float((mods as Dictionary)[k])
	var st: Variant = J.g(e, "stack")
	if st != null and (J.g(st, "to") == null or J.inc(J.g(st, "to"), 职业)):
		var 层 := minf(J.num(J.g(st, "max")), 藏品层数(件, 出击职业))
		var per: Variant = J.g(st, "per")
		if per is Dictionary:
			for k in (per as Dictionary).keys():
				m[k] = J.num0(m.get(k)) + float((per as Dictionary)[k]) * 层
	return {"我的": 我的, "m": m, "stat": (J.or_(J.g(e, "stat"), null) if 我的 else null)}

## 把一组合计值按**同类上限**夹一次（71-改动-3-难度调整.js 的 `藏品合计封顶`；正负都往 0 的方向夹）
static func 藏品合计封顶(合计: Dictionary, 上限表: Variant) -> Dictionary:
	var 出 := {}
	for k in 合计.keys():
		var 限: Variant = (上限表 as Dictionary).get(k) if 上限表 is Dictionary else null
		var 有上限 := J.is_num(限) and J.finite(限) and float(限) > 0.0
		if 有上限:
			出[k] = J.clamp(float(合计[k]), -float(限), float(限))
		else:
			出[k] = 合计[k]
	return 出

static func _上限(方: String) -> Variant:
	var 难度: Variant = Db.T.get("难度调整")
	var t: Variant = J.g(难度, "藏品同类上限")
	return J.g(t, 方)

## 把一条 `src:'藏品'` 的常驻 buff 贴到单位上（先删掉旧的同源 buff，再 push —— 照 JS 的 filter + push）
static func _贴藏品buff(u: Dictionary, 夹过: Dictionary) -> void:
	var 新 := {"src": "藏品", "剩余": 999.0}
	for k in 夹过.keys():
		新[k] = 夹过[k]
	var 留 := []
	for b in J.or_(u.get("buffs"), []):
		if not (b is Dictionary and b.get("src") == "藏品"):
			留.append(b)
	u.buffs = 留
	(u.buffs as Array).append(新)
	u.藏品加成 = 夹过

## 开战时给**我方**出击机体算藏品加成（战棋 relicApplyAllies，23b:74-95）。返回受影响的单位数。
static func 应用藏品我方(我方: Array, 藏品们: Variant) -> float:
	var 件们 := 取件们(藏品们)
	if 件们.is_empty() or 我方.is_empty():
		return 0.0
	var 出击职业 := []
	for u in 我方:
		出击职业.append(战斗分类(u))
	var n := 我方.size()
	var 职业数 := J.uniq(出击职业).size()
	var 有混编 := J.some(件们, func(x): return J.g(J.g(x, "数值"), "特殊") == "mixed")
	var 有孤狼 := J.some(件们, func(x): return J.g(J.g(x, "数值"), "特殊") == "lonewolf")
	for u in 我方:
		var 职: Variant = 战斗分类(u)
		var 合计 := {}
		for 件 in 件们:
			var r := 藏品单体效果(件, 职, 出击职业)
			var m: Dictionary = r["m"]
			for k in m.keys():
				合计[k] = J.num0(合计.get(k)) + float(m[k])
			var stat: Variant = r["stat"]
			if stat != null and J.truthy(J.g(stat, "hpPct")):
				var 倍 := 1.0 + J.num(J.g(stat, "hpPct")) / 100.0
				u.maxHp = maxf(1.0, JsCompat.js_round(float(u.maxHp) * 倍))
				u.hp = maxf(1.0, JsCompat.js_round(float(u.hp) * 倍))
		if 有混编:
			合计["dmg"] = J.num0(合计.get("dmg")) + 8.0 * float(职业数)
		if 有孤狼:
			if n <= 2:
				合计["dmg"] = J.num0(合计.get("dmg")) + 50.0
				合计["armorPct"] = J.num0(合计.get("armorPct")) + 30.0
			elif n >= 4:
				合计["dmg"] = J.num0(合计.get("dmg")) - 15.0
		var 夹过 := 藏品合计封顶(合计, _上限("我方"))
		if 夹过.is_empty():
			continue
		_贴藏品buff(u, 夹过)
	var 数 := 0
	for u in 我方:
		if J.truthy(u.get("藏品加成")):
			数 += 1
	return float(数)

## 开战时给**敌方**单位算藏品减益（战棋 relicApplyFoe，23b:97-107）。返回受影响的敌方单位数。
static func 应用藏品敌方(敌方: Array, 我方: Variant, 藏品们: Variant) -> float:
	var 件们 := 取件们(藏品们)
	if 件们.is_empty() or 敌方.is_empty():
		return 0.0
	var 出击职业 := []
	for u in J.or_(我方, []):
		出击职业.append(战斗分类(u))
	var 合计 := {}
	for 件 in 件们:
		var e: Variant = J.or_(J.g(件, "数值"), {})
		var foe: Variant = J.g(e, "foe")
		if foe is Dictionary:
			for k in (foe as Dictionary).keys():
				合计[k] = J.num0(合计.get(k)) + float((foe as Dictionary)[k])
		var fs: Variant = J.g(e, "foeStack")
		if fs != null:
			var 层 := minf(J.num(J.g(fs, "max")), 藏品层数(件, 出击职业))
			var per: Variant = J.g(fs, "per")
			if per is Dictionary:
				for k in (per as Dictionary).keys():
					合计[k] = J.num0(合计.get(k)) + float((per as Dictionary)[k]) * 层
	if 合计.is_empty():
		return 0.0
	var 夹过 := 藏品合计封顶(合计, _上限("敌方"))
	for e2 in 敌方:
		_贴藏品buff(e2, 夹过)
	return float(敌方.size())

## 开战时一次全做完（`60-战斗-3-开局与simulate.js:131` 的 `藏品开战(ctx.allies, ctx.enemies)`）。
## 返回 `{我方, 敌方, 件数}`（JS 的返回值调用点没用，这里保留同形）。
static func apply_on_battle_start(ctx: Dictionary, relic_ids: Variant) -> Dictionary:
	var 件数 := 取件们(relic_ids).size()
	if 件数 == 0:
		return {"我方": 0.0, "敌方": 0.0, "件数": 0.0}
	return {
		"我方": 应用藏品我方(ctx.allies, relic_ids),
		"敌方": 应用藏品敌方(ctx.enemies, ctx.allies, relic_ids),
		"件数": float(件数),
	}
