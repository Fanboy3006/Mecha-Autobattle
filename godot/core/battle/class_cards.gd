## ★ A6a：三套**职业分类牌** 18 张（近卫 6 / 尖兵 6 / 重装 6）。
##
## 权威依据（数值逐字照抄，一个数都没改）：
##   · `协作/设计/响介卡牌设计 v0.1.md` §8.2  —— 近卫 6 张
##   · `协作/设计/拉米亚卡牌设计 v0.1.md` §7.2 —— 尖兵 6 张
##   · `协作/设计/塔斯克与雷欧娜卡牌设计 v0.1.md` §3 —— 重装 6 张
##   · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §2.2（「次」与「段」）/ §4 的 A6a 行 / §5 R4
##
## 注册形状照秘银 v0.3 的 `_分类牌()` / `_职业()`（`core/battle/mithril_v03_cards.gd:680-743`）：
##   `卡类 = 公有牌` / `层级 = 职业` / `种类 = 职业` / `归属 = 近卫|尖兵|重装` / `回库 = true`。
##   **本文件是自己的卡表**（秘银那份一个字都没动）。
##
## 三条铁律：
##   · **R5**：一次攻击 = 一条记录。本文件不逐段写日志；`反冲` 是「每次攻击事件一次」，
##     8 段近战命中也只反 400（任务单 §2.2）。
##   · **R4**：会改「敌方打谁」的效果（`挑衅` / `一击脱离`）统一走 `可选目标()`，
##     而它只在 `Ai.bestWeaponOn()` 里被调用 —— `Btl.算意图()` 与敌方阶段实际出手
##     共用 `Ai.enemyAction()`，所以预告与实战**天然同源**（预告说打 A，实际就打 A）。
##
## 状态的生存期：全部是「本回合」或「到下个我方阶段前」，统一在 `ClassCards.阶段初()` 里清，
## 由 `Btl.开始我方阶段()` 调用（`反冲`/`铁壁` 这类跟着 buff 的由 `Setup.endTurn` 的 `剩余` 清）。
class_name ClassCards
extends RefCounted

const 近卫 := "近卫"
const 尖兵 := "尖兵"
const 重装 := "重装"

## 三套牌的职业顺序（测试与门面按这个顺序取）。
const 职业们: Array = ["近卫", "尖兵", "重装"]

const _整数路径们 := ["等级需求"]

static var _表: Array = []
static var _表代: int = -1

# ==========================================================================================
# 一、牌面（18 张；从 `data/cards/职业分类牌.json` 读入）
# ==========================================================================================
static func _还原值(v: Variant, 路径: String, 父: Dictionary = {}) -> Variant:
	if v is Dictionary:
		var 出 := {}
		for k in (v as Dictionary).keys():
			var 子路径 := str(k) if 路径 == "" else "%s.%s" % [路径, str(k)]
			出[k] = _还原值(v[k], 子路径, v)
		return 出
	if v is Array:
		var 组: Array = []
		var 子路径 := "%s[]" % 路径
		for x in (v as Array):
			组.append(_还原值(x, 子路径, 父))
		return 组
	if typeof(v) == TYPE_FLOAT:
		if 路径 in _整数路径们:
			return int(v)
		if 路径 == "入库条件.阈值" and 父.has("职业"):
			return int(v)
	return v

static func _读表() -> Array:
	var 表: Array = []
	var 包: Dictionary = Db.T.get("卡包", {}).get("职业分类牌", {})
	for 条 in 包.get("分类牌", []):
		if 条 is Dictionary:
			表.append(_还原值(条, ""))
	return 表

static func 卡表() -> Array:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读表()
		_表代 = Db.代
	return _表

## 全部 18 张（按 近卫 → 尖兵 → 重装 顺序）。
static func 职业牌们(职业: String = "") -> Array:
	var 全 := 卡表()
	if 职业 == "":
		return 全
	return 全.filter(func(c): return str(c.get("归属", "")) == 职业)

static func 卡(id: String) -> Dictionary:
	for c in 卡表():
		if str(c.get("id", "")) == id:
			return c
	return {}

## 按显示名找（测试与门面方便）。
static func 按名(名: String) -> Dictionary:
	for c in 卡表():
		if str(c.get("名", "")) == 名:
			return c
	return {}

## 这张牌是不是三套分类牌之一（`分类牌` 标记 / id 前缀两种认法）。
static func 是分类牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return J.truthy((c as Dictionary).get("分类牌")) or str((c as Dictionary).get("id", "")).begins_with("CC_")

# ==========================================================================================
# 二、算出「这张牌现在能不能打」（空串 = 能打；否则是给玩家看的理由）
# ==========================================================================================
## 分类牌是**公有排、按职业限制**：职业由 `Btl._身份对口`（`层级 == 职业`）拦；
## 这里再按「入库条件」用**打出者自己**的口径验一次（`打出者本场击破 ≥ 1` / `在前排` / `HP ≤ 50%` /
## `第 N 回合起`）—— 公有待入库时按该职业的在场机体算过一遍，打出时不认别人的成果。
static func 不可打原因(ctx: Variant, u: Variant, card: Variant) -> String:
	if not 是分类牌(card) or not (u is Dictionary):
		return ""
	var 条 = (card as Dictionary).get("入库条件")
	if 条 is Dictionary and not DeckFlow.条件满足(ctx, u, 条):
		return "入库条件未满足：%s" % str((条 as Dictionary).get("说明", "条件没达成"))
	return ""

## 规则钩子【卡不可打原因】：职业分类牌的入库条件由这边给结论；别的牌一律不接手。
static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	var 因 := 不可打原因(ctx, u, card)
	if 因 == "":
		return {"终局": false}
	return {"终局": true, "原因": 因}

# ==========================================================================================
# 三、效果算子（`CardEffects.执行算子` 的 `"职业牌"` 分支转到这里）
# ==========================================================================================
static func _ctxOf(运行: Dictionary) -> Dictionary:
	var c = 运行.get("ctx")
	return c if c is Dictionary else {}

## 打出者：`ctx._当前出牌者` 优先（`Btl.打出精神或公有牌` 写死的那一个）。
static func _施放者(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 键 := str(ctx.get("_当前出牌者", ""))
	if 键 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key", "")) == 键:
				return u
	return null

## 指定的敌机：`ctx._当前目标` → 找不到就取第一台存活敌机（确定性，不掷随机数）。
static func _敌方(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	var 敌们 := Units.livingOf("enemy", ctx)
	J.sort(敌们, func(a, b): return float(a.slot) - float(b.slot))
	return 敌们[0] if not 敌们.is_empty() else null

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String, 额外: Dictionary = {}) -> void:
	var 谁 := J.merged({"类型": "分类牌", "牌名": 牌名}, 额外)
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % str((u as Dictionary).get("name", ""))) if u is Dictionary else "", 文], 谁)

static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx := _ctxOf(运行)
	if ctx.is_empty():
		return []
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(card.get("名", ""))
	var 施 = _施放者(运行)
	if not (施 is Dictionary):
		return ["没有能打出这张分类牌的机体"]
	var u: Dictionary = 施
	var 回合 := float(ctx.get("turn", 0.0))
	match 动作:
		"压制杂兵":
			u["压制杂兵Turn"] = 回合
			_记(ctx, 牌名, u, "本回合打杂兵伤害 +50%、命中 +20")
			return ["打杂兵伤害 +50%、命中 +20"]
		"突入":
			var 抽 := Setup.抽专属牌(u, 1)
			u["突入命中"] = true
			_记(ctx, 牌名, u, "抽 %d 张；下一张近战武器牌命中 +10" % 抽.size())
			return ["抽 %d 张；下一张近战武器命中 +10" % 抽.size()]
		"乘胜追击":
			u["乘胜追击Turn"] = 回合
			_记(ctx, 牌名, u, "本回合下一次攻击若击破目标 → 战意 +10、抽 1 张")
			return ["下一次击破 → 战意 +10、抽 1 张"]
		"死守前线":
			u["死守前线中"] = true
			u["下阶段销毁武器"] = 牌名
			_记(ctx, 牌名, u, "HP 最少保留 1（到下个我方阶段前）；代价：下个我方阶段武器牌全部销毁")
			return ["HP 最少保留 1；下个我方阶段武器全毁"]
		"回旋斩":
			u["回旋斩"] = true
			_记(ctx, 牌名, u, "下一张近战武器牌附加「横扫」（目标一整排）、伤害 −40%")
			return ["下一张近战武器牌：横扫、伤害 −40%"]
		"顺劈":
			# ★ CB-0：近战武器的一次性标记 —— 真正生效在 `Btl._执行武器攻击`（消耗即清）。
			u["下张近战附加顺劈"] = true
			_记(ctx, 牌名, u, "本回合下一张近战武器牌附加【顺劈】（同排左右相邻敌机各受 50% 伤害）")
			return ["作用于【%s】：本回合下一张近战武器牌附加【顺劈】（同排左右相邻敌机各受 50%% 伤害）" % str(u.get("name", ""))]
		"标记目标":
			var t = _敌方(运行)
			if not (t is Dictionary):
				return ["没有能标记的敌机"]
			t["标记目标Turn"] = 回合
			t["标记目标已用"] = false
			_记(ctx, 牌名, t, "本回合我方第一次攻击它，每段命中 +15")
			return ["标记：%s（本回合首次攻击每段命中 +15）" % str(t.get("name", ""))]
		"侧翼渗透":
			u["侧翼渗透Turn"] = 回合
			Btl.换同源增益(u, 牌名, {"受伤Mul": 0.15, "剩余": 1.0})
			_记(ctx, 牌名, u, "本回合打敌方后排伤害 +20%；代价：到下个我方阶段前受到的伤害 +15%")
			return ["打后排伤害 +20%；受到伤害 +15%"]
		"闪避机动":
			u["闪避机动Turn"] = 回合
			Btl.换同源增益(u, 牌名, {"eva": 20.0, "剩余": 1.0})
			_记(ctx, 牌名, u, "闪避 +20（到下个我方阶段前）；代价：本回合每段命中 −10")
			return ["闪避 +20；本回合每段命中 −10"]
		"扰乱通讯":
			var t2 = _敌方(运行)
			if not (t2 is Dictionary):
				return ["没有能扰乱的敌机"]
			t2["扰乱通讯"] = true
			_记(ctx, 牌名, t2, "它下一次攻击每段命中 −20")
			return ["扰乱：%s（下一次攻击每段命中 −20）" % str(t2.get("name", ""))]
		"一击脱离":
			u["一击脱离待Turn"] = 回合
			_记(ctx, 牌名, u, "打完主武器后，到下个我方阶段前敌方近战不能选它为目标")
			return ["打完主武器后：敌方近战不能选它"]
		"绕后奇袭":
			u["绕后奇袭"] = true
			_记(ctx, 牌名, u, "下一张武器牌无视距离上下限、可打任意一格；伤害 −20%")
			return ["下一张武器牌：无视距离、伤害 −20%"]
		"铁壁":
			u["铁壁Turn"] = 回合
			Btl.换同源增益(u, 牌名, {"受伤Mul": -0.40, "剩余": 1.0})
			_记(ctx, 牌名, u, "受到的伤害 −40%（到下个我方阶段前）；代价：本回合伤害 −30%")
			return ["受到伤害 −40%；本回合伤害 −30%"]
		"挑衅":
			u["挑衅Turn"] = 回合
			_记(ctx, 牌名, u, "到下个我方阶段前，敌方前排的单体攻击只能选它")
			return ["敌方前排的单体攻击只能选它"]
		"横向掩护":
			u["横向掩护Turn"] = 回合
			_记(ctx, 牌名, u, "本回合「掩护」范围扩大到左右相邻的前排队友")
			return ["掩护范围扩大到左右相邻前排队友"]
		"紧急修理":
			var 上 := float(u.get("maxHp", 0.0))
			var 前 := float(u.get("hp", 0.0))
			var 回 := J.round(上 * 0.25)
			u["hp"] = minf(上, 前 + 回)
			var 实 := J.round(float(u.get("hp", 0.0)) - 前)
			_记(ctx, 牌名, u, "回复 %s HP（%s → %s）" % [J.s(实), J.s(前), J.s(u.get("hp"))])
			return ["回复 %s HP" % J.s(实)]
		"反冲":
			u["反冲Turn"] = 回合
			_记(ctx, 牌名, u, "到下个我方阶段前，每被近战命中 1 次（每次攻击一次）反手 400 物理")
			return ["每被近战命中一次 → 攻击者受 400 物理"]
		"不倒":
			u["不倒中"] = true
			u["下阶段销毁武器"] = 牌名
			_记(ctx, 牌名, u, "HP 最少保留 1（到下个我方阶段前）；代价：下个我方阶段武器牌全部销毁")
			return ["HP 最少保留 1；下个我方阶段武器全毁"]
	push_error("ClassCards：未知的分类牌动作「%s」" % 动作)
	return []

# ==========================================================================================
# 四、战斗管线的四个钩子（全部纯读）
# ==========================================================================================

## 命中修正（`Calc.hitRate` 调用 —— 预告与真结算同一处，所以两边看到的数一样）。
##   · 压制杂兵：打杂兵命中 +20（本回合）
##   · 闪避机动：本回合每段命中 −10
##   · 扰乱通讯：这台敌机下一次攻击每段命中 −20
##   · 标记目标：本回合我方**第一次**攻击它每段命中 +15
static func 命中修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	if not (ctx is Dictionary) or not (att is Dictionary) or not (def is Dictionary):
		return 0.0
	var t = (ctx as Dictionary).get("turn", 0.0)
	var h := 0.0
	if J.same((att as Dictionary).get("压制杂兵Turn"), t) and 是杂兵(def):
		h += 20.0
	if J.same((att as Dictionary).get("闪避机动Turn"), t):
		h -= 10.0
	if J.truthy((att as Dictionary).get("扰乱通讯")):
		h -= 20.0
	if J.same((def as Dictionary).get("标记目标Turn"), t) and not J.truthy((def as Dictionary).get("标记目标已用")):
		h += 15.0
	return h

## 伤害倍率（`Calc._单体结算` 在各段求和之后乘一次 —— 常数倍率，段数不影响结果）。
##   · 压制杂兵 +50%（打杂兵）· 侧翼渗透 +20%（打敌方后排）
##   · 铁壁的代价 −30%（本回合打出者伤害）
##   · 回旋斩 −40%（`w.横扫`）· 绕后奇袭 −20%（`w.绕后奇袭`）
static func 伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	if not (ctx is Dictionary) or not (att is Dictionary):
		return 1.0
	var t = (ctx as Dictionary).get("turn", 0.0)
	var m := 1.0
	if J.same((att as Dictionary).get("压制杂兵Turn"), t) and 是杂兵(def):
		m *= 1.5
	if J.same((att as Dictionary).get("侧翼渗透Turn"), t) and 是后排(def):
		m *= 1.2
	if J.same((att as Dictionary).get("铁壁Turn"), t):
		m *= 0.7
	if w is Dictionary and J.truthy((w as Dictionary).get("横扫")):
		m *= 0.6
	if w is Dictionary and J.truthy((w as Dictionary).get("绕后奇袭")):
		m *= 0.8
	return m

## 规则钩子转发【攻方伤害倍率】（`RuleHooks.依次乘("攻方伤害倍率")`）。
static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	return 伤害倍率(ctx, att, def, w)

## 这台目标算不算「杂兵」（`DataFn.tierOfEnemy` 的梯队名）。
static func 是杂兵(u: Variant) -> bool:
	if not (u is Dictionary) or str((u as Dictionary).get("side", "")) != "enemy":
		return false
	return DataFn.tierOfEnemy((u as Dictionary).get("key")) == "杂兵"

static func 是后排(u: Variant) -> bool:
	if not (u is Dictionary) or (u as Dictionary).get("slot") == null:
		return false
	return Fm.rowOfSlot(float((u as Dictionary).slot)) == Fm.ROW_BACK

static func _近战(w: Variant) -> bool:
	return w != null and Reach.rangeKindOf(w) == Reach.KIND_MELEE()

## 致死伤害保留 1 HP（死守前线 / 不倒）。由 `Calc._单体结算` 在扣完血之后调（非预览）。
static func 致命保留(ctx: Variant, def: Variant) -> bool:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return false
	var 名 := ""
	if J.truthy((def as Dictionary).get("死守前线中")):
		名 = "死守前线"
	elif J.truthy((def as Dictionary).get("不倒中")):
		名 = "不倒"
	if 名 == "" or float((def as Dictionary).get("hp", 0.0)) > 0.0:
		return false
	def["hp"] = 1.0
	_记(ctx, 名, def, "HP 最少保留 1 —— **没被击破**（剩 1）", {"保留": 1.0})
	return true

## 反冲（重装 §3）：**每次攻击事件一次**（不是每段）。8 段近战命中 1 次也只反 400。
static func 反冲(ctx: Variant, att: Variant, def: Variant, landed: float, w: Variant) -> float:
	if not (ctx is Dictionary) or not (att is Dictionary) or not (def is Dictionary):
		return 0.0
	if landed <= 0.0 or not _近战(w):
		return 0.0
	if not J.same((def as Dictionary).get("反冲Turn"), (ctx as Dictionary).get("turn", 0.0)):
		return 0.0
	if float((att as Dictionary).get("hp", 0.0)) <= 0.0 or is_same(att, def):
		return 0.0
	att["hp"] = maxf(0.0, float(att.get("hp")) - 400.0)
	var 多段: String = "（%d 段也只反 1 次：按攻击事件算）" % int(J.num0(w.get("hits"))) if J.num0(w.get("hits")) > 1.0 else ""
	_记(ctx, "反冲", def, "被 %s 近战命中 → 反手 **400** 物理伤害%s" % [str((att as Dictionary).get("name", "")), 多段],
		J.merged({"反冲": 400.0, "攻击者": (att as Dictionary).get("key")}, Btl.谁(def)))
	return 400.0

## 一次攻击结算完之后要消费的一次性标记（`Calc._单体结算` 非预览时调）。
##   · 标记目标：被攻击过一次 → 本回合不再加命中
##   · 扰乱通讯：这台敌机打完之后清掉
static func 攻击后消耗(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary):
		return
	var t = (ctx as Dictionary).get("turn", 0.0)
	if def is Dictionary and J.same((def as Dictionary).get("标记目标Turn"), t):
		if not J.truthy((def as Dictionary).get("标记目标已用")):
			def["标记目标已用"] = true
			_记(ctx, "标记目标", def, "第一次被攻击已经用掉（本回合不再加命中）")
	if att is Dictionary and J.truthy((att as Dictionary).get("扰乱通讯")):
		att.erase("扰乱通讯")
		_记(ctx, "扰乱通讯", att, "这一次攻击吃完 −20 命中，标记清除")

## 规则钩子转发【致命保留_后】（`RuleHooks.广播("致命保留_后")`：在「单机牌组战意」之后 → 不算击破）。
static func 致命保留_后(ctx: Variant, _att: Variant, def: Variant) -> void:
	致命保留(ctx, def)

## 规则钩子转发【武器攻击后】（`RuleHooks.广播("武器攻击后")`）：反冲 → 攻击后消耗（原顺序）。
static func 武器攻击后(ctx: Variant, att: Variant, def: Variant, landed: float, w: Variant) -> void:
	反冲(ctx, att, def, landed, w)
	攻击后消耗(ctx, att, def)

## 打出者「下一张武器牌」的一次性改写（突入 / 回旋斩 / 绕后奇袭）。
## `Btl._执行武器攻击` 在开打前调；返回 `{生效, 武器}`（不生效 = 原武器原样返回、一个字节都不改）。
static func 改写武器(ctx: Variant, u: Variant, w: Dictionary) -> Dictionary:
	var 空 := {"生效": false, "武器": w}
	if not (ctx is Dictionary) or not (u is Dictionary):
		return 空
	var 改: Dictionary = {}
	var 生效 := false
	if J.truthy((u as Dictionary).get("突入命中")) and _近战(w) and not Reach.是范围武器(w):
		if not 生效:
			改 = w.duplicate(true)
			生效 = true
		改["hit"] = float(改.get("hit", 100.0)) + 10.0
		u.erase("突入命中")
		_记(ctx, "突入", u, "下一张近战武器牌命中 +10（%s）" % str(w.get("name", "")))
	if J.truthy((u as Dictionary).get("回旋斩")) and _近战(w):
		if not 生效:
			改 = w.duplicate(true)
			生效 = true
		改["横扫"] = true
		u.erase("回旋斩")
		_记(ctx, "回旋斩", u, "这一张近战武器牌变成「横扫」（目标一整排）、伤害 −40%%（%s）" % str(w.get("name", "")))
	if J.truthy((u as Dictionary).get("绕后奇袭")):
		if not 生效:
			改 = w.duplicate(true)
			生效 = true
		改["距离"] = [1, 6]
		改["绕后奇袭"] = true
		u.erase("绕后奇袭")
		_记(ctx, "绕后奇袭", u, "这一张武器牌无视距离上下限、伤害 −20%%（%s）" % str(w.get("name", "")))
	if not 生效:
		return 空
	return {"生效": true, "武器": 改}

## 绕后奇袭生效中（`Reach.武器可达吗` 用它绕过距离 / 站位限制）。纯读。
static func 绕后奇袭(ctx: Variant, u: Variant) -> bool:
	return u is Dictionary and J.truthy((u as Dictionary).get("绕后奇袭"))

## 一次攻击结算完的「攻击后」（`Flow.resolveAction` 在 `Calc.spendWeapon` 之前调一次）。
##   · 乘胜追击：这一次攻击击破了目标 → 战意 +10、抽 1 张（用掉即清）
##   · 一击脱离：打完主武器 → 到下个我方阶段前敌方近战不能选它
static func 攻击后(ctx: Variant, u: Variant, 击破: float) -> void:
	if not (ctx is Dictionary) or not (u is Dictionary):
		return
	var t = (ctx as Dictionary).get("turn", 0.0)
	if J.same((u as Dictionary).get("乘胜追击Turn"), t):
		u.erase("乘胜追击Turn")
		if 击破 > 0.0:
			Btl.加战意(u, 10.0, ctx, "乘胜追击")
			var 抽 := Setup.抽专属牌(u, 1)
			_记(ctx, "乘胜追击", u, "击破目标 → 战意 +10（现 %s）、抽 %d 张" % [J.s(J.num0((u as Dictionary).get("战意"))), 抽.size()],
				J.merged({"击破": 击破, "抽牌": 抽.size()}, Btl.谁(u)))
	if J.same((u as Dictionary).get("一击脱离待Turn"), t):
		u.erase("一击脱离待Turn")
		u["一击脱离中"] = true
		_记(ctx, "一击脱离", u, "主武器打完 → 到下个我方阶段前敌方近战不能选它为目标")

# ==========================================================================================
# 五、★ R4：改目标选择（`挑衅` / `一击脱离`）—— **只在 `Ai.bestWeaponOn` 里被调**
#     `Btl.算意图()` → `Boss.bossAction()` → `Ai.enemyAction()` → `pickSingleTarget/pickLowestHp/
#     pickBackRowFirst` → `bestWeaponOn`；敌方阶段实际出手走的是**同一条链**。
#     所以「预告目标」与「实际目标」天然逐次相同（门禁见 `tests/unit/test_class_cards.gd` 第 9 段）。
# ==========================================================================================

## 攻击者 `攻` 现在能不能选 `目标`（`w` = 这一发要用的武器）。纯读，一个随机数都不掷。
##   · 一击脱离：`攻` 的**近战**武器不能选带 `一击脱离中` 的目标
##   · 挑衅：`攻` 在**前排**、且这一发是**单体**攻击 → 对面只有挑衅者能被选
static func 可选目标(ctx: Variant, 攻: Variant, 目标: Variant, w: Variant) -> bool:
	if not (ctx is Dictionary) or not (攻 is Dictionary) or not (目标 is Dictionary):
		return true
	if is_same(攻, 目标):
		return true
	var 攻方 := str((攻 as Dictionary).get("side", ""))
	if str((目标 as Dictionary).get("side", "")) == 攻方:
		return true
	if _近战(w) and J.truthy((目标 as Dictionary).get("一击脱离中")):
		return false
	if not Reach.是范围武器(w) and (攻 as Dictionary).get("slot") != null \
		and Fm.rowOfSlot(float((攻 as Dictionary).slot)) == Fm.ROW_FRONT:
		var 挑 = 挑衅者(ctx, 攻)
		if 挑 != null and not is_same(挑, 目标):
			return false
	return true

## 对面（`攻` 的敌方阵营）里带「挑衅」的单位（活的；没有 = null）。纯读。
static func 挑衅者(ctx: Variant, 攻: Variant) -> Variant:
	if not (ctx is Dictionary) or not (攻 is Dictionary):
		return null
	var 守方 := Units.otherSide(str((攻 as Dictionary).get("side", "enemy")))
	var t = (ctx as Dictionary).get("turn", 0.0)
	for u in Units.livingOf(守方, ctx):
		if u is Dictionary and J.same((u as Dictionary).get("挑衅Turn"), t):
			return u
	return null

## 横向掩护：把「打向左右相邻的前排队友」的单体攻击接管过来（重装 §3）。
## 由 `Btl.嘲讽` 在开打前问一次（纯读；没有 = null）。
static func 横向掩护接管(ctx: Variant, 原目标: Variant) -> Variant:
	if not (ctx is Dictionary) or not (原目标 is Dictionary) or (原目标 as Dictionary).get("slot") == null:
		return null
	if Fm.rowOfSlot(float((原目标 as Dictionary).slot)) != Fm.ROW_FRONT:
		return null
	var t = (ctx as Dictionary).get("turn", 0.0)
	var 候选: Array = []
	for u in Units.livingOf(str((原目标 as Dictionary).get("side", "ally")), ctx):
		if not (u is Dictionary) or is_same(u, 原目标):
			continue
		if not J.same((u as Dictionary).get("横向掩护Turn"), t):
			continue
		if J.truthy((u as Dictionary).get("主武器已销毁")):
			continue
		if absi(int(Fm.colOfSlot(float((u as Dictionary).slot))) - int(Fm.colOfSlot(float((原目标 as Dictionary).slot)))) != 1:
			continue
		候选.append(u)
	if 候选.is_empty():
		return null
	J.sort(候选, func(a, b): return float(a.slot) - float(b.slot))
	return 候选[0]

## 【顺劈】主目标同排左右相邻的存活敌机（最多 2 台；**只看同排左右**，不看前后排）。纯读。
## `Btl._执行武器攻击` 用它展开落点 —— 与任务单写的几何口径逐字一致
## （`Fm.rowOfSlot(e.slot) == Fm.rowOfSlot(target.slot)` 且 `abs(colOfSlot 之差) == 1`）。
static func 顺劈副目标们(ctx: Variant, 主目标: Variant) -> Array:
	var 出: Array = []
	if not (ctx is Dictionary) or not (主目标 is Dictionary) or (主目标 as Dictionary).get("slot") == null:
		return 出
	var 排 := Fm.rowOfSlot(float((主目标 as Dictionary).slot))
	var 列 := int(Fm.colOfSlot(float((主目标 as Dictionary).slot)))
	for e in Units.livingOf(str((主目标 as Dictionary).get("side", "enemy")), ctx):
		if not (e is Dictionary) or is_same(e, 主目标) or (e as Dictionary).get("slot") == null:
			continue
		if Fm.rowOfSlot(float((e as Dictionary).slot)) != 排:
			continue
		if absi(int(Fm.colOfSlot(float((e as Dictionary).slot))) - 列) != 1:
			continue
		出.append(e)
	J.sort(出, func(a, b): return float(a.slot) - float(b.slot))
	return 出

## 这一发近战武器是不是带【顺劈】（武器 `area` 本身写了 `cleave` / `顺劈`，
## 或打出者身上还有那张分类牌给的一次性标记 —— **只有近战才算**）。
static func 是顺劈武器(ctx: Variant, u: Variant, w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	var 区 := str((w as Dictionary).get("area", ""))
	if 区 == "cleave" or 区 == "顺劈":
		return true
	if not (u is Dictionary) or not J.truthy((u as Dictionary).get("下张近战附加顺劈")):
		return false
	if not _近战(w):
		return false
	# 消耗一次性标记（触发后清掉，下一张不再带）
	(u as Dictionary).erase("下张近战附加顺劈")
	return true

# ==========================================================================================
# 六、我方阶段开始：清「本回合」状态 + 兑现「下个我方阶段武器牌全部销毁」的代价
# ==========================================================================================
## 「本回合」/「到下个我方阶段前」的单位级状态键（全部在这里清）。
const 阶段初清键: Array = [
	"压制杂兵Turn", "突入命中", "乘胜追击Turn", "回旋斩", "下张近战附加顺劈",
	"标记目标Turn", "标记目标已用", "侧翼渗透Turn", "闪避机动Turn", "一击脱离待Turn", "一击脱离中",
	"绕后奇袭", "铁壁Turn", "挑衅Turn", "横向掩护Turn", "反冲Turn", "死守前线中", "不倒中",
]

static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	var 全部: Array = J.concat(J.or_((ctx as Dictionary).get("allies"), []), J.or_((ctx as Dictionary).get("enemies"), []))
	for u in 全部:
		if not (u is Dictionary):
			continue
		# 代价：死守前线 / 不倒 → 下个我方阶段打出者武器牌全部销毁
		var 名 := str((u as Dictionary).get("下阶段销毁武器", ""))
		if 名 != "" and str((u as Dictionary).get("side", "")) == "ally":
			u["主武器已销毁"] = true
			_记(ctx, 名, u, "代价兑现：本阶段武器牌全部销毁（不能攻击）", {"主武器已销毁": true})
		u.erase("下阶段销毁武器")
		for k in 阶段初清键:
			u.erase(k)

## 规则钩子转发【我方阶段初_后】（`RuleHooks.广播("我方阶段初_后")`）。
static func 我方阶段初_后(ctx: Variant) -> void:
	阶段初(ctx)

# ==========================================================================================
# 七、三层反馈的「预告」读法（纯读；表现层与门禁都可以随便连调）
# ==========================================================================================
## 一台机体身上现在挂着哪些分类牌状态（一行一条）。一个都没有 = 空数组。
static func 状态行(u: Variant, ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 名 := str((u as Dictionary).get("name", ""))
	var t = (ctx as Dictionary).get("turn", 0.0) if ctx is Dictionary else (u as Dictionary).get("turn")
	if J.same((u as Dictionary).get("压制杂兵Turn"), t):
		出.append("%s〔压制杂兵〕本回合打杂兵伤害 +50%%、命中 +20" % 名)
	if J.truthy((u as Dictionary).get("突入命中")):
		出.append("%s〔突入〕下一张近战武器牌命中 +10" % 名)
	if J.same((u as Dictionary).get("乘胜追击Turn"), t):
		出.append("%s〔乘胜追击〕本回合下一次攻击若击破 → 战意 +10、抽 1 张" % 名)
	if J.truthy((u as Dictionary).get("死守前线中")):
		出.append("%s〔死守前线〕HP 最少保留 1（下个我方阶段武器全毁）" % 名)
	if J.truthy((u as Dictionary).get("回旋斩")):
		出.append("%s〔回旋斩〕下一张近战武器牌：横扫、伤害 −40%%" % 名)
	if J.truthy((u as Dictionary).get("下张近战附加顺劈")):
		出.append("%s〔顺劈〕下一张近战武器牌：同排左右相邻敌机各受 50%% 伤害" % 名)
	if J.same((u as Dictionary).get("标记目标Turn"), t) and not J.truthy((u as Dictionary).get("标记目标已用")):
		出.append("%s〔标记目标〕本回合第一次被攻击每段命中 +15" % 名)
	if J.same((u as Dictionary).get("侧翼渗透Turn"), t):
		出.append("%s〔侧翼渗透〕打后排伤害 +20%%（受到的伤害 +15%%）" % 名)
	if J.same((u as Dictionary).get("闪避机动Turn"), t):
		出.append("%s〔闪避机动〕闪避 +20、本回合每段命中 −10" % 名)
	if J.truthy((u as Dictionary).get("扰乱通讯")):
		出.append("%s〔扰乱通讯〕下一次攻击每段命中 −20" % 名)
	if J.truthy((u as Dictionary).get("一击脱离中")):
		出.append("%s〔一击脱离〕敌方近战不能选它" % 名)
	if J.truthy((u as Dictionary).get("绕后奇袭")):
		出.append("%s〔绕后奇袭〕下一张武器牌无视距离、伤害 −20%%" % 名)
	if J.same((u as Dictionary).get("挑衅Turn"), t):
		出.append("%s〔挑衅〕敌方前排的单体攻击只能选它" % 名)
	if J.same((u as Dictionary).get("横向掩护Turn"), t):
		出.append("%s〔横向掩护〕掩护范围扩大到左右相邻的前排队友" % 名)
	if J.same((u as Dictionary).get("反冲Turn"), t):
		出.append("%s〔反冲〕每被近战命中一次 → 攻击者受 400 物理" % 名)
	if J.truthy((u as Dictionary).get("不倒中")):
		出.append("%s〔不倒〕HP 最少保留 1（下个我方阶段武器全毁）" % 名)
	return 出
