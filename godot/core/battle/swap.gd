## 职责：共用换位底座 —— `swapPos` 原语 + 换位后的 6 项刷新链（月球王国 / 影世界共用同一份）。
## 约定：同方阵内换格（绝不跨阵）；只在卡牌效果调用时改状态，一个随机数都不掷。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §8（`协作/设计/月球王国势力卡牌设计 v0.2.1.md` §8 是同一份底座）。
class_name BattleSwap
extends RefCounted

## 〔错位〕标记：本回合位置发生过改变（我方 / 敌方通用，回合初清）。
const 错位键 := "shiftedThisTurn"

## 换位后写给敌机的「本回合意图锁定」（`Boss.bossAction` 认这个键，预告与实战同源）。
const 意图锁定键 := "换位意图锁定"

## 意图锁定的四个来源（§8.2 第 4 项的三步确定性规则 + 待机兜底）。
const 方案_保持 := "保持原武器原目标"
const 方案_换目标 := "同武器换目标"
const 方案_换武器 := "改用远程武器"
const 方案_待机 := "射程不达 · 待机"

## 〔深渊之门〕每台敌机每回合最多被这条规则打几次。
const 深渊之门上限 := 3

# ---- 一、几何与合法性 ----
## 这个格子上站着的存活单位（空格 / 已阵亡 = null）。
static func 格上单位(ctx: Variant, side: String, slot: Variant) -> Variant:
	if not (ctx is Dictionary) or slot == null:
		return null
	for u in Units.livingOf(side, ctx):
		if u is Dictionary and u.get("slot") != null and int(u.slot) == int(slot):
			return u
	return null

## 这一方前排 4 格全空 → 该方后排进入「顶位」（纯读，转发 `Fm.是否顶位`）。
static func 顶位(ctx: Variant, side: String) -> bool:
	return Fm.是否顶位(ctx, side)

## 这次换位能不能做：两格都在本方阵型内、互不相同、至少一格有存活单位。
## **不接受跨阵**：`side` 之外的格子号一律非法。
static func 合法吗(ctx: Variant, side: String, posA: Variant, posB: Variant) -> bool:
	if not (ctx is Dictionary) or posA == null or posB == null:
		return false
	if side != "ally" and side != "enemy":
		return false
	if int(posA) == int(posB):
		return false
	for p in [posA, posB]:
		if float(p) < 0.0 or float(p) >= Fm.SLOTS():
			return false
	return 格上单位(ctx, side, posA) != null or 格上单位(ctx, side, posB) != null

## 两格上是不是都站着存活单位（= 互换；否则是「移入空格」）。
static func 是互换吗(ctx: Variant, side: String, posA: Variant, posB: Variant) -> bool:
	return 格上单位(ctx, side, posA) != null and 格上单位(ctx, side, posB) != null

# ---- 二、原语 ----
## 在同方阵内交换 `posA` / `posB`：两格都有单位 = 互换，一格空 = 把单位挪进空格。
## 返回**实际改变格子的存活单位数** `k`（0 = 没动；1 = 移入空格；2 = 互换）。
## `opts` 认两个键：`isShadowCard`（影世界牌 → 记【移位】并挂〔错位〕）、`来源`（战报里显示谁挪的）。
static func 换位(ctx: Variant, side: String, posA: Variant, posB: Variant, opts: Variant = null) -> int:
	if not 合法吗(ctx, side, posA, posB):
		return 0
	var 设: Dictionary = opts if opts is Dictionary else {}
	var 甲 = 格上单位(ctx, side, posA)
	var 乙 = 格上单位(ctx, side, posB)
	var 顶位前 := {"ally": 顶位(ctx, "ally"), "enemy": 顶位(ctx, "enemy")}
	var 快照 := 意图快照(ctx)
	var 移动的: Array = []
	if 甲 is Dictionary:
		甲["slot"] = float(posB)
		移动的.append(甲)
	if 乙 is Dictionary:
		乙["slot"] = float(posA)
		移动的.append(乙)
	_刷新链(ctx, side, 移动的, 顶位前, 快照, 设)
	return 移动的.size()

## 换位前那一刻的敌方意图表（`ctx.敌方意图表` 是每次刷新都会写的纯读快照，这里只做浅拷贝取用）。
static func 意图快照(ctx: Variant) -> Dictionary:
	var 出 := {}
	if not (ctx is Dictionary):
		return 出
	var 表 = ctx.get("敌方意图表")
	if not (表 is Dictionary):
		return 出
	for k in (表 as Dictionary).keys():
		var 条 = (表 as Dictionary)[k]
		if 条 is Dictionary:
			出[str(k)] = (条 as Dictionary).duplicate()
	return 出

# ---- 三、6 项刷新链（§8.2，按序立即执行） ----
static func _刷新链(ctx: Dictionary, side: String, 移动的: Array, 顶位前: Dictionary,
		快照: Dictionary, opts: Dictionary) -> void:
	if 移动的.is_empty():
		return
	_刷坐标与顶位(ctx, side, 顶位前)
	_记移位(ctx, side, 移动的, opts)
	# 第 3 项〔掩护〕连线 / 第 6 项手牌高亮都是**纯读现算**（`BattleGuard.当前援护连线们` /
	# 表现层直读），这里不必重建缓存；只保证不动别人的 `掩护剩余`。
	RuleHooks.广播("换位后", [ctx, side, 移动的, opts])
	_重算意图(ctx, 快照)
	DeckFlow.刷新实时门槛(ctx)
	_记换位(ctx, side, 移动的, opts)

## 第 1 项：坐标已在上一步写回；这里只把「顶位」的变化写进战报（顶位本身是纯读现算的）。
static func _刷坐标与顶位(ctx: Dictionary, side: String, 顶位前: Dictionary) -> void:
	var 后 := 顶位(ctx, side)
	if bool(顶位前.get(side, false)) == 后:
		return
	var 方 := "我" if side == "ally" else "敌"
	Btl.pushLog(ctx, "〔换位〕%s方前排%s → %s" % [方,
		"已经没有存活单位" if 后 else "重新有人",
		"后排全体进入〔顶位〕（近战资格按前排算）" if 后 else "解除〔顶位〕"],
		{"类型": "换位顶位", "方": side, "顶位": 后})

## 第 2 项：〔移位〕计数 与 〔错位〕标记；〔深渊之门〕激活时补一次特殊伤害。
static func _记移位(ctx: Dictionary, side: String, 移动的: Array, opts: Dictionary) -> void:
	if not J.truthy(opts.get("isShadowCard")):
		return
	var k := 移动的.size()
	ctx["turnShiftCount"] = J.num0(ctx.get("turnShiftCount")) + float(k)
	ctx["battleShiftCount"] = J.num0(ctx.get("battleShiftCount")) + float(k)
	for u in 移动的:
		if u is Dictionary:
			(u as Dictionary)[错位键] = true
			if side == "enemy" and J.truthy(ctx.get("abyssGateActive")):
				_深渊之门(ctx, u)

## 〔深渊之门〕：因影世界牌移位的敌机各受 700 点无视防御特殊伤害（每台每回合最多 3 次）。
static func _深渊之门(ctx: Dictionary, u: Dictionary) -> void:
	var 记: Dictionary = u.get("深渊之门计数") if u.get("深渊之门计数") is Dictionary else {}
	if not J.same(记.get("回合"), ctx.get("turn")):
		记 = {"回合": ctx.get("turn"), "次": 0.0}
	var 次 := J.num0(记.get("次"))
	if 次 >= float(深渊之门上限):
		return
	记["次"] = 次 + 1.0
	u["深渊之门计数"] = 记
	var 前 := float(u.get("hp", 0.0))
	if 前 <= 0.0:
		return
	u["hp"] = maxf(0.0, 前 - 700.0)
	Btl.pushLog(ctx, "〔深渊之门〕%s 被移位 → 受 700 点无视防御特殊伤害（%s → %s，本回合第 %d 次）" % [
		str(u.get("name", "")), J.s(前), J.s(u.get("hp")), int(记.get("次"))],
		J.merged({"类型": "深渊之门", "目标": u.get("key"), "伤害": 700.0, "本回合第几次": 记.get("次")}, Btl.谁(u)))
	if float(u.get("hp", 0.0)) <= 0.0:
		Btl.记击破(ctx, null, u)

## 第 4 项：敌方意图按三步确定性规则重算，结果写成「本回合意图锁定」挂在敌机身上。
## 第 1 步 原武器原目标仍合法 → 保持；第 2 步 原武器可用、原目标不可达 → 同武器换目标；
## 第 3 步 原武器在新位置不可用 → 改用可用远程武器，没有就〔射程不达 · 待机〕。
static func _重算意图(ctx: Dictionary, 快照: Dictionary) -> void:
	if 快照.is_empty():
		return
	for e in Units.livingOf("enemy", ctx):
		if not (e is Dictionary):
			continue
		var 原 = 快照.get(str((e as Dictionary).get("key", "")))
		if not (原 is Dictionary):
			continue
		var 名 := str((原 as Dictionary).get("武器", ""))
		if 名 == "":
			continue
		var w := _按名找武器(e, 名)
		if w.is_empty():
			continue
		var t = _按键找友军(ctx, str((原 as Dictionary).get("目标", "")))
		# 「原武器在新位置还能不能用」= 冷却次数够 **且** 排位锁满足（近战被挪到后排就用不了了）。
		if _武器仍可用(e, w, ctx) and _武器站得住(ctx, e, w):
			var 保 := _保原方案(ctx, e, w, t)
			if not 保.is_empty():
				_写锁定(e, 保, ctx)
				continue
			var 换 := _按同武器换目标(ctx, e, w)
			if not 换.is_empty():
				_写锁定(e, 换, ctx)
				continue
			_写锁定(e, _待机(e, "原武器可用但没有够得着的我方目标"), ctx)
			continue
		var 远 = Ai.enemyAction(e, ctx, true)
		if 远 is Dictionary and 远.get("weapon") is Dictionary and 远.get("target") is Dictionary:
			_写锁定(e, {"kind": "attack", "weapon": 远.get("weapon"), "target": 远.get("target"),
				"expected": J.num0(远.get("expected")), "entry": 远.get("entry"),
				"被挡": J.truthy(远.get("被挡")), "换位方案": 方案_换武器}, ctx)
			continue
		_写锁定(e, _待机(e, "在这个位置用不了原武器（近战被挪到后排），也没有够得着的远程武器"), ctx)

## 第 1 步：原武器 + 原目标仍合法 → 原样保留（只按新位置重算被挡与预计伤害）。
static func _保原方案(ctx: Dictionary, e: Dictionary, w: Dictionary, t: Variant) -> Dictionary:
	if not (t is Dictionary):
		return {}
	if not J.truthy(Reach.武器可达吗(ctx, e, w, t).get("ok")):
		return {}
	var 局面 := Ai.局面Of(Units.livingOf("ally", ctx))
	var 得 = Ai.bestWeaponOn(e, t, [{"t": w, "cd": 0.0, "uses": null}], 局面, ctx)
	if 得 == null:
		return {}
	return {"kind": "attack", "weapon": w, "target": t, "expected": J.num0((得 as Dictionary).get("exp")),
		"entry": (得 as Dictionary).get("entry"), "被挡": J.truthy((得 as Dictionary).get("被挡")),
		"换位方案": 方案_保持}

## 第 2 步：原武器可用、原目标不可达 → 保持原武器，按敌方 AI 规则重选我方目标。
static func _按同武器换目标(ctx: Dictionary, e: Dictionary, w: Dictionary) -> Dictionary:
	var 敌们 := Units.livingOf("ally", ctx)
	if 敌们.is_empty():
		return {}
	var 条 := [{"t": w, "cd": 0.0, "uses": null}]
	var 得 = null
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		得 = Ai.pickAreaTarget(e, 敌们, 条, ctx)
	else:
		得 = Ai.pickSingleTarget(e, 敌们, 条, ctx)
	if 得 == null:
		return {}
	return {"kind": "attack", "weapon": w, "target": (得 as Dictionary).get("target"),
		"expected": J.num0((得 as Dictionary).get("exp")), "entry": (得 as Dictionary).get("entry"),
		"slot": (得 as Dictionary).get("slot"), "hit": (得 as Dictionary).get("hit"),
		"被挡": J.truthy((得 as Dictionary).get("被挡")), "换位方案": 方案_换目标}

static func _待机(_e: Dictionary, 缘由: String) -> Dictionary:
	return {"kind": "none", "待机": true, "待机原因": 缘由, "换位方案": 方案_待机}

## 第 5 项之后的一行战报：把这次换位与它的下游影响写清楚（三层反馈的「即时」）。
static func _记换位(ctx: Dictionary, side: String, 移动的: Array, opts: Dictionary) -> void:
	var 名们: Array = []
	for u in 移动的:
		if u is Dictionary:
			名们.append("%s→%s" % [str(u.get("name", "")), Fm.位名(float(u.get("slot", 0.0)))])
	var 来源 := str(opts.get("来源", "换位"))
	var 尾 := ""
	if J.truthy(opts.get("isShadowCard")):
		尾 = "（本回合移位 %d 次，累计 %d 次）" % [int(J.num0(ctx.get("turnShiftCount"))),
			int(J.num0(ctx.get("battleShiftCount")))]
	Btl.pushLog(ctx, "〔%s〕%s方：%s%s" % [来源, "我" if side == "ally" else "敌", "、".join(名们), 尾],
		{"类型": "换位", "来源": 来源, "方": side, "移位": float(移动的.size()),
			"移动单位们": 移动的.map(func(u): return u.get("key") if u is Dictionary else null)})

# ---- 四、意图锁定的读取与清理 ----
## `Boss.bossAction` 在选武器**之前**问这一句：本回合有没有换位写下的锁定。
## 返回 `null` = 没有锁定（一个字节都不影响原有 AI）。
static func 锁定动作(ctx: Variant, u: Variant) -> Variant:
	if not (u is Dictionary) or not ((u as Dictionary).has(意图锁定键)):
		return null
	var 锁 = (u as Dictionary).get(意图锁定键)
	if not (锁 is Dictionary):
		return null
	if not J.same((锁 as Dictionary).get("回合"), (ctx as Dictionary).get("turn") if ctx is Dictionary else null):
		return null
	if J.truthy((锁 as Dictionary).get("待机")):
		return {"kind": "none", "待机": true, "待机原因": str((锁 as Dictionary).get("待机原因", "")),
			"换位方案": str((锁 as Dictionary).get("换位方案", 方案_待机))}
	var w = (锁 as Dictionary).get("weapon")
	var t = (锁 as Dictionary).get("target")
	if not (w is Dictionary) or not (t is Dictionary):
		return null
	return {"kind": "attack", "weapon": w, "target": t, "expected": J.num0((锁 as Dictionary).get("expected")),
		"entry": (锁 as Dictionary).get("entry"), "被挡": J.truthy((锁 as Dictionary).get("被挡")),
		"slot": (锁 as Dictionary).get("slot"), "hit": (锁 as Dictionary).get("hit"),
		"换位方案": str((锁 as Dictionary).get("换位方案", ""))}

## 写锁定（`_重算意图` 用；统一补上「回合」，免得跨回合残留）。
static func _写锁定(u: Dictionary, 锁: Dictionary, ctx: Dictionary) -> void:
	var 带 := (锁 as Dictionary).duplicate(true)
	带["回合"] = ctx.get("turn")
	u[意图锁定键] = 带

## 每回合清掉上一回合的锁定与〔错位〕（`DeckFlow.阶段初_冷却与维持` 调）。
static func 清回合状态(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["turnShiftCount"] = 0.0
	for u in J.concat(J.or_((ctx as Dictionary).get("allies"), []), J.or_((ctx as Dictionary).get("enemies"), [])):
		if u is Dictionary:
			(u as Dictionary).erase(意图锁定键)
			(u as Dictionary).erase(错位键)

## 〔错位〕读法（纯读）：这台单位本回合位置改变过吗。
static func 已错位(u: Variant) -> bool:
	return u is Dictionary and J.truthy((u as Dictionary).get(错位键))

# ---- 五、小工具（纯读） ----
static func _按名找武器(e: Dictionary, 名: String) -> Dictionary:
	for 条 in J.or_(e.get("weapons"), []):
		if 条 is Dictionary and 条.get("t") is Dictionary and str((条.get("t") as Dictionary).get("name", "")) == 名:
			return 条.get("t")
	return {}

static func _按键找友军(ctx: Dictionary, 键: String) -> Variant:
	if 键 == "":
		return null
	for a in Units.livingOf("ally", ctx):
		if a is Dictionary and str((a as Dictionary).get("key", "")) == 键:
			return a
	return null

## 这把武器**站在现在这个位置**用得了吗（冷却次数之外的那道排位锁：近战必须在有效前排）。
static func _武器站得住(ctx: Dictionary, e: Dictionary, w: Dictionary) -> bool:
	if Reach.rangeKindOf(w) != Reach.KIND_MELEE():
		return true
	if Reach.无视遮挡(w) or Reach.有后方渗透(e):
		return true
	return Reach.前排资格(ctx, e)

## 这把武器现在还用得了吗（冷却 / 次数 / 已解锁门槛，认 `Calc.usableWeapons` 的同一份口径）。
static func _武器仍可用(e: Dictionary, w: Dictionary, ctx: Dictionary) -> bool:
	for 条 in Calc.usableWeapons(e, ctx):
		if 条 is Dictionary and 条.get("t") is Dictionary and str((条.get("t") as Dictionary).get("name", "")) \
			== str(w.get("name", "")):
			return true
	return false
