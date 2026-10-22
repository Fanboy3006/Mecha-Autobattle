## 61-Boss.js：站桩 Boss 脚本（阶段 / 大技能间隔 / 伤害倍率）。
class_name Boss
extends RefCounted

static func 取Boss脚本(u: Variant) -> Variant:
	if u == null or u.get("side") != "enemy" or not J.truthy(u.get("key")):
		return null
	if J.truthy(u.get("词条Boss")):
		return u.词条Boss
	return J.at(Db.T.Boss脚本, u.key)

static func Boss触发阈值(触发: Variant) -> Variant:
	if J.is_num(触发):
		return float(触发) / 100.0 if float(触发) > 1 else float(触发)
	if 触发 == "半血":
		return 0.5
	return null

static func Boss阶段序号(u: Dictionary) -> int:
	var s = 取Boss脚本(u)
	if s == null or not J.is_arr(s.get("阶段")) or s.阶段.is_empty() or not (float(u.maxHp) > 0):
		return 0
	var 血比 := float(u.hp) / float(u.maxHp)
	var n := 0
	for i in s.阶段.size():
		var t = Boss触发阈值(s.阶段[i].get("触发") if s.阶段[i] != null else null)
		if t != null and 血比 <= float(t):
			n = i + 1
	return n

static func Boss参数(u: Variant) -> Variant:
	var s = 取Boss脚本(u)
	if s == null:
		return null
	var 阶段 := Boss阶段序号(u)
	var o = J.or_(s.阶段[阶段 - 1] if 阶段 > 0 else null, {})
	var 取 := func(k: String, d: Variant) -> Variant:
		if o.get(k) != null:
			return o[k]
		return s[k] if s.get(k) != null else d
	return {"脚本": s, "阶段": float(阶段), "第几阶段": float(阶段 + 1),
		"大技能间隔": 取.call("大技能间隔", 0.0), "大技能武器": 取.call("大技能武器", null), "伤害倍率": 取.call("伤害倍率", 1.0)}

static func Boss本回合放大技能(u: Variant, ctx: Variant) -> bool:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器) or not (J.num(p.大技能间隔) > 0):
		return false
	if ctx == null or ctx.get("turn") == null:
		return false
	return J.mod(float(ctx.turn) - 1.0, float(p.大技能间隔)) == 0

static func Boss下次技能回合(u: Variant, ctx: Variant) -> Variant:
	var p = Boss参数(u)
	if p == null or not (J.num(p.大技能间隔) > 0) or ctx == null or ctx.get("turn") == null:
		return null
	var 间隔 := float(p.大技能间隔)
	return float(ctx.turn) + (间隔 - J.mod(float(ctx.turn) - 1.0, 间隔))

## 脚本里出现过的所有大技能武器名（顶层 + 各阶段）。
static func 脚本大技能武器们(s: Variant) -> Array:
	var 出 := []
	if not (s is Dictionary):
		return 出
	if J.truthy(s.get("大技能武器")):
		出.append(s.大技能武器)
	for st in (s.get("阶段") if J.is_arr(s.get("阶段")) else []):
		if st is Dictionary and J.truthy(st.get("大技能武器")) and not 出.has(st.大技能武器):
			出.append(st.大技能武器)
	return 出

## 预告用：大技能**真正能放**的下一个回合（含本回合）—— 既要落在间隔上，也要过了武器的开场冷却 / 冷却。
## 没配大技能 → null。只读，不改任何状态。
static func 大技能预告回合(u: Variant, ctx: Variant) -> Variant:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器) or not (J.num(p.大技能间隔) > 0) or ctx == null or ctx.get("turn") == null:
		return null
	var 早 := float(ctx.turn)
	for e in J.or_(u.get("weapons"), []):
		if e.t.get("name") == p.大技能武器:
			早 = maxf(早, maxf(float(e.get("readyTurn", 1.0)), float(ctx.turn) + J.num0(e.get("cd"))))
	var 间隔 := float(p.大技能间隔)
	var r := J.mod(早 - 1.0, 间隔)
	return 早 if r == 0 else 早 + (间隔 - r)

static func Boss本回合禁用(u: Variant, ctx: Variant, w: Variant) -> bool:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器) or not (J.num(p.大技能间隔) > 0):
		return false
	if w == null:
		return false
	# 别的阶段的大技能武器：平时一律不许当普通武器用（阶段换武器后旧的那把也收起来）
	if w.get("name") != p.大技能武器:
		return 脚本大技能武器们(p.脚本).has(w.get("name"))
	if ctx == null or ctx.get("turn") == null:
		return false
	return not Boss本回合放大技能(u, ctx)

static func Boss伤害倍率(u: Variant) -> float:
	var p = Boss参数(u)
	var v = p.伤害倍率 if p != null else 1.0
	return float(v) if (J.is_num(v) and float(v) > 0) else 1.0

static func Boss大技能条目(u: Dictionary, ctx: Dictionary) -> Variant:
	var p = Boss参数(u)
	if p == null or not J.truthy(p.大技能武器):
		return null
	return J.find(Calc.usableWeapons(u, ctx), func(e): return e.t.name == p.大技能武器)

static func 单武器动作(u: Dictionary, 条目: Variant, ctx: Dictionary) -> Variant:
	var foes := Units.livingOf(Units.otherSide(u.side), ctx)
	if 条目 == null or foes.is_empty():
		return null
	var w = 条目.t
	var pool := [条目]
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		var a = Ai.pickAreaTarget(u, foes, pool, null)
		if a != null:
			return {"kind": "attack", "weapon": w, "target": a.target, "expected": a.exp, "slot": a.slot, "hit": a.hit, "entry": a.entry, "被挡": false}
	var s = Ai.pickSingleTarget(u, foes, pool, ctx)
	if s != null:
		# ★ A6b（R4）：Boss 的大技能也是敌方单体攻击 —— 塔斯克的【掩护】在这里同样收口，
		#   保证「算意图 预告」与「实际挨打」仍然是同一个人。
		return AtxDuo.掩护收口(ctx, u, {"kind": "attack", "weapon": w, "target": s.target,
			"expected": s.exp, "entry": s.entry, "被挡": J.truthy(s.被挡)})
	return null

## [换位意图锁定] 这一步是「预告 == 实战」的唯一入口：`Btl.算意图`（预告）与敌方阶段实际出手
## （`Boss.bossTurn`）都走 `bossAction`，所以换位重算出来的意图两边逐次相同。
static func bossAction(u: Dictionary, ctx: Dictionary) -> Variant:
	var 锁 = BattleSwap.锁定动作(ctx, u)
	if 锁 != null:
		return 锁
	if 取Boss脚本(u) == null:
		var 辅 = 敌方辅助动作(u, ctx)
		return 辅 if 辅 != null else Ai.enemyAction(u, ctx)
	if Boss本回合放大技能(u, ctx):
		var a = 单武器动作(u, Boss大技能条目(u, ctx), ctx)
		if a != null:
			a.大技能 = true
			a.第几阶段 = Boss参数(u).第几阶段
			return a
	var 辅2 = 敌方辅助动作(u, ctx)
	return 辅2 if 辅2 != null else Ai.enemyAction(u, ctx)

## 敌方的修理 / 支援武器：有人掉到修理线就先修，支援（再动 / 增益）有对象就先放，否则照常攻击。
## 预告（`Btl.算意图`）与实战都经 `bossAction`，所以同源。没有这类武器的敌机一律返回 null。
static func 敌方辅助动作(u: Dictionary, ctx: Dictionary) -> Variant:
	var 有 := false
	for e in J.or_(u.get("weapons"), []):
		var k = Reach.rangeKindOf(e.t)
		if Reach.isHealKind(k) or Reach.isSupportKind(k):
			有 = true
	if not 有:
		return null
	if 取Boss脚本(u) != null and Boss本回合放大技能(u, ctx):
		return null
	var h = Ai.chooseHeal(u, ctx)
	if h != null:
		return h
	return Ai.chooseSupport(u, ctx)

## [换位意图锁定] 待机的锁定在这里收口：预告与实战都写同一条〔待机〕战报、都返回 `none`。
static func bossTurn(u: Dictionary, ctx: Dictionary) -> Variant:
	var 锁 = BattleSwap.锁定动作(ctx, u)
	if 锁 is Dictionary and J.truthy((锁 as Dictionary).get("待机")):
		Btl.pushLog(ctx, "〔%s〕%s 本回合不攻击：%s" % [str((锁 as Dictionary).get("换位方案", "待机")), u.name,
			str((锁 as Dictionary).get("待机原因", ""))],
			J.merged({"类型": "待机", "单位": u.key, "换位方案": (锁 as Dictionary).get("换位方案"),
				"待机原因": (锁 as Dictionary).get("待机原因")}, Btl.谁(u)))
		return {"kind": "none", "待机": true}
	var p = Boss参数(u)
	# 没有 Boss 脚本的敌机也走 `bossAction` —— 否则锁定只影响预告、不影响实战。
	if p == null:
		return bossAction(u, ctx)
	var 已报 := J.num0(u.get("boss阶段已报"))
	if float(p.第几阶段) > 已报:
		u.boss阶段已报 = p.第几阶段
		var 文: String
		if float(p.第几阶段) > 1:
			文 = "〔Boss〕%s 进入第 %s 阶段（大技能间隔 %s 回合、伤害倍率 ×%s）" % [u.name, J.s(p.第几阶段), J.s(p.大技能间隔), J.s(p.伤害倍率)]
		else:
			var 中 := "每 %s 回合放一次【%s】" % [J.s(p.大技能间隔), J.s(p.大技能武器)] if (J.num(p.大技能间隔) > 0 and J.truthy(p.大技能武器)) else "（没配大技能）"
			文 = "〔Boss〕%s 站桩 Boss：%s（伤害倍率 ×%s）" % [u.name, 中, J.s(p.伤害倍率)]
		Btl.pushLog(ctx, 文, J.merged({"类型": "Boss", "Boss事件": "阶段", "Boss阶段": p.第几阶段, "大技能间隔": p.大技能间隔, "伤害倍率": p.伤害倍率}, Btl.谁(u)))
		for n in range(int(已报) + 1, int(p.第几阶段) + 1):
			阶段进场(u, ctx, n)
	var a = bossAction(u, ctx)
	if a == null:
		var 下次 = Boss下次技能回合(u, ctx)
		var 尾 := "（第 %s 回合释放【%s】）" % [J.s(下次), J.s(p.大技能武器)] if J.truthy(下次) else ""
		Btl.pushLog(ctx, "〔Boss〕%s 蓄力中%s" % [u.name, 尾], J.merged({"类型": "Boss", "Boss事件": "蓄力", "大技能回合": 下次}, Btl.谁(u)))
		return {"kind": "none"}
	if J.truthy(a.get("大技能")):
		Btl.pushLog(ctx, "〔Boss〕%s 释放【%s】" % [u.name, a.weapon.name], J.merged({"类型": "Boss", "Boss事件": "大技能", "BOSS大技能": true, "武器": a.weapon.name,
			"目标": a.target.key if a.target != null else null, "目标位": a.target.slot if a.target != null else null}, Btl.谁(u)))
	return a

## N4 进入第 n 阶段：执行 `阶段[n-2].进场`（战报 → 词条 → 增援）。只由 `bossTurn` 调，每阶段一次。
static func 阶段进场(u: Dictionary, ctx: Dictionary, n: int) -> void:
	var s = 取Boss脚本(u)
	if s == null or not J.is_arr(s.get("阶段")) or n < 2 or n - 2 >= s.阶段.size() or not (s.阶段[n - 2] is Dictionary):
		return
	var 进 = s.阶段[n - 2].get("进场")
	for 条 in (进 if 进 is Array else ([进] if 进 is Dictionary else [])):
		if not (条 is Dictionary) or (条.get("除非") is Dictionary and Rival.条件成立(ctx, 条.除非)):
			continue
		var 增: Array = J.or_(条.get("增援"), [])
		var 词: Array = J.or_(条.get("词条"), [])
		var 段 := []
		if J.truthy(条.get("战报")):
			段.append(str(条.战报))
		if not 词.is_empty():
			段.append("套上【%s】" % "、".join(词.map(func(t): return str(J.g(t, "键")))))
		if not 增.is_empty():
			段.append("呼叫增援 %d 台" % 增.size())
		Btl.pushLog(ctx, "〔Boss〕%s 阶段进场：%s" % [u.name, "；".join(段) if not 段.is_empty() else "（无）"],
			J.merged({"类型": "Boss", "Boss事件": "进场", "Boss阶段": float(n), "增援数": float(增.size())}, Btl.谁(u)))
		for t in 词:
			Traits.应用词条到单位(u, t, u.get("层"))
		if not 增.is_empty():
			Flow.增援一波(ctx, {"来": 增.map(func(e): return 进场增援规格(u, e))}, Units.已用键表(ctx.get("enemies")))
			if J.some(ctx.enemies, func(x): return J.truthy(x.get("词条全场"))):
				Btl.应用全场词条(ctx)

## N9 中途撤离：带 `撤退 {HP线, 回合, 条件}` 的敌机到线 / 到回合 → 移出战场，本场判我方胜利（`撤退: true`）。
static func 撤离检查(ctx: Dictionary) -> Variant:
	if ctx.get("result") != null:
		return null
	for e in Units.livingOf("enemy", ctx):
		var 撤 = e.get("撤退")
		if not (撤 is Dictionary) or (撤.get("条件") is Dictionary and not Rival.条件成立(ctx, 撤.条件)):
			continue
		var 到线: bool = J.finite(撤.get("HP线")) and float(e.hp) <= float(e.maxHp) * float(撤.HP线) / 100.0
		var 到点: bool = J.finite(撤.get("回合")) and float(ctx.get("turn", 0.0)) >= float(撤.回合)
		if not (到线 or 到点):
			continue
		ctx.enemies.erase(e)
		ctx["撤离单位"] = J.concat(J.or_(ctx.get("撤离单位"), []), [e.key])
		Btl.pushLog(ctx, "〔撤离〕%s %s，撤出战场：本场判我方胜利（奖励减半）" % [e.name, "HP 到线" if 到线 else "到第 %s 回合" % J.s(撤.回合)],
			J.merged({"类型": "撤离", "单位": e.key}, Btl.谁(e)))
		return {"结果": "胜", "原因": "敌方头目撤离", "撤退": true, "撤离单位": e.key}
	return null

## 进场增援规格：等级 / 强化按 Boss 的层与梯队推。
static func 进场增援规格(u: Dictionary, e: Variant) -> Dictionary:
	var 键 := str(e.get("键") if e is Dictionary else e)
	var 表: Dictionary = J.or_(Db.T.get("TIER_LV"), {})
	var 等级 := float(u.get("lv", 1.0)) - J.num0(表.get(DataFn.tierOfEnemy(Rival.键Of(u)))) + J.num0(表.get(DataFn.tierOfEnemy(键)))
	var 层 = u.get("层")
	return {"键": 键, "等级": maxf(1.0, 等级), "强化": float(Diff.敌方强度倍率(层, DataFn.tierOfEnemy(键)).倍率), "层": 层,
		"词条": e.get("词条") if e is Dictionary else null}
