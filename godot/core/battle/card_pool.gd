## 职责：卡牌可用性判定 / 声明式触发条件求值 / 卡牌与单位的查找 / 护盾与标定层数。
class_name BattleCardPool
extends RefCounted

## ★ MITH-1：这张牌算不算「秘银连携计入口径」。
static func 是秘银计入牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if str(card.get("归属", "")) == "秘银":
		return true
	if str(card.get("角色所属势力", "")) == "秘银":
		return true
	return bool(card.get("是TDD1", false))

static func 卡可打吗(ctx: Variant, card: Variant) -> bool:
	if ctx == null or not (card is Dictionary):
		return false
	if card.get("剩余次数") != null and float(card.剩余次数) <= 0:
		return false
	if J.num0(card.get("当前冷却")) > 0:
		return false
	if not bool(card.get("衍生", false)) and int(card.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
		return false
	# 气势已退役：能不能打只看次数 / 冷却 / 本回合断路器（上面那两道）。
	return true

static func _找队友(ctx: Variant, 键: String) -> Variant:
	if not (ctx is Dictionary):
		return null
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key")) == 键:
			return u
	return null

## 从单位（或机体键）取出「键 / 职业 / 势力」三层 —— 牌池归位用，纯读。
static func 提取单位三层信息(u: Variant) -> Dictionary:
	if not J.truthy(u):
		return {"键": "", "职业": "", "势力": ""}
	var 键
	if u is String:
		键 = u
	else:
		键 = J.or_(J.or_(J.or_(J.or_(u.get("tplKey"), u.get("key")), u.get("mech")), u.get("键")), "")
	var tpl = DataFn.tplOf(键) if J.truthy(键) else null
	var ut = u.get("tags") if u is Dictionary else null
	var tt = tpl.get("tags") if tpl != null else null
	var 职业 = J.or_(J.or_(J.or_(J.g(ut, "战斗分类"), J.g(u, "职业")), J.g(tt, "战斗分类")), "")
	var 势力 = J.or_(J.or_(J.or_(J.g(ut, "势力"), J.g(u, "势力")), J.g(tt, "势力")), "")
	return {"键": 键, "职业": 职业, "势力": 势力}

static func 牌来源机体(card: Variant, 单位们: Variant) -> Dictionary:
	if not (card is Dictionary):
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "未知"}
	var c: Dictionary = card
	var 层 := str(c.get("层级", ""))
	var 归 := str(c.get("归属", ""))
	var 表: Array = 单位们 if 单位们 is Array else []
	if 层 == "统帅":
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "统帅"}
	var 命中: Array = []
	if 层 == "角色":
		var 角色们: Array = c.get("角色们") if c.get("角色们") is Array else []
		if 角色们.is_empty():
			var 单 := str(c.get("角色", ""))
			角色们 = [单 if not 单.is_empty() else 归]
		for u in 表:
			if _单位键属于(u, 角色们):
				命中.append(u)
	elif 层 == "职业":
		if not 归.is_empty():
			for u in 表:
				if _单位职业(u) == 归:
					命中.append(u)
	elif 层 == "势力":
		if not 归.is_empty():
			for u in 表:
				if _单位势力(u) == 归:
					命中.append(u)
	else:
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "未知"}
	var 活: Array = 命中.filter(func(u): return float(u.get("hp", 1.0)) > 0.0)
	var 用: Array = 活 if not 活.is_empty() else 命中
	if 用.is_empty():
		if 层 == "角色":
			var 谁 := str(c.get("角色", ""))
			if 谁.is_empty():
				谁 = 归
			return {"文本": "来自：%s（角色）" % 谁, "位": [], "类别": 层}
		return {"文本": "来自：%s（%s）" % [归, 层], "位": [], "类别": 层}
	var 名们: Array = []
	var 位们: Array = []
	for u in 用:
		名们.append(_单位显示名(u))
		var s: Variant = u.get("slot", null)
		位们.append(Fm.位名(float(s)) if s != null else "")
	var 已阵亡 := 活.is_empty()
	var 名字 := "/".join(名们)
	if 层 == "角色":
		var 位文 := "/".join(位们)
		if 已阵亡:
			位文 = (位文 + " · 已阵亡") if not 位文.is_empty() else "已阵亡"
		return {"文本": "来自：%s（%s）" % [名字, 位文], "位": 位们, "类别": 层}
	var 文 := "来自：%s·%s" % [名字, 归]
	if 已阵亡:
		文 += "（已阵亡）"
	return {"文本": 文, "位": 位们, "类别": 层}

static func _单位键(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var d: Dictionary = u
	for k in ["tplKey", "key", "mech"]:
		var v: Variant = d.get(k)
		if v != null and str(v) != "":
			return str(v)
	return ""

static func _单位键属于(u: Variant, 键们: Array) -> bool:
	var k := _单位键(u)
	if k.is_empty():
		return false
	for x in 键们:
		if str(x) == k:
			return true
	return false

static func _单位职业(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var 标: Variant = (u as Dictionary).get("tags")
	if 标 is Dictionary:
		var a := str((标 as Dictionary).get("战斗分类", ""))
		if not a.is_empty():
			return a
	var b: Variant = (u as Dictionary).get("职业")
	return str(b) if b != null else ""

static func _单位势力(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var 标: Variant = (u as Dictionary).get("tags")
	if 标 is Dictionary:
		var a := str((标 as Dictionary).get("势力", ""))
		if not a.is_empty():
			return a
	var b: Variant = (u as Dictionary).get("势力")
	return str(b) if b != null else ""

static func _单位显示名(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var n := str((u as Dictionary).get("name", ""))
	if not n.is_empty():
		return n
	var 短 := str((u as Dictionary).get("short", ""))
	return 短 if not 短.is_empty() else _单位键(u)

## 克隆一张战术牌：重置剩余次数 / 当前冷却 / 新触发。
static func 克隆战术牌(c: Variant, _ctx: Variant = null) -> Variant:
	if c == null:
		return null
	return J.merged(c, {"剩余次数": J.num(c.限次) if c.get("限次") != null else 1.0, "当前冷却": 0.0, "新触发": false, "触发回合": null})

static func _是(u: Variant, k: String) -> bool:
	return u != null and (u.get("key") == k or u.get("tplKey") == k)

## ★ MITH-1：声明式触发条件表求值（`card["触发条件"] = {类型, 阈值, …}`）。认不出来 = 不满足（不静默放行）。
static func _声明式触发(cond: Dictionary, ctx: Variant, 事件类型: Variant, 计: Dictionary, card: Variant = null) -> bool:
	var 类型 := str(cond.get("类型", ""))
	var 阈值 := int(cond.get("阈值", 1))
	if 阈值 < 1:
		阈值 = 1
	match 类型:
		"开局在手":
			if card is Dictionary and J.truthy(card.get("回库")):
				return true
			return str(事件类型) == "开局"
		"触发连携":
			return int(计.get("触发连携", 0)) >= 阈值
		"打出TDD1":
			return int(计.get("打出TDD1", 0)) >= 阈值
		"未命中段", "打空":
			return false
		"第N回合起":
			return int(ctx.get("turn", 1)) >= 阈值
	return false

static func _触发阈值(card: Dictionary) -> float:
	var v := J.num(card.get("触发阈值"))
	return v if (is_finite(v) and v >= 1.0) else 1.0

## 加卡牌护盾：`shield` 取大值，盾值累进 `shieldHp`。
static func 加卡牌护盾(u: Variant, 盾值: float) -> float:
	if u == null or not (盾值 > 0):
		return 0.0
	var v := J.round(盾值)
	u.shield = maxf(J.num0(u.get("shield")), v)
	u.shieldHp = J.num0(u.get("shieldHp")) + v
	return v

static func 减单位大招冷却(u: Variant, 减值: Variant, 清零: bool = false) -> void:
	if u == null or not J.is_arr(u.get("weapons")):
		return
	for e in u.weapons:
		if e == null or not J.truthy(e.get("t")):
			continue
		var 是大: bool = Ai.isUltimate(e.t) or J.num(e.t.get("unlock")) >= 20 or J.num(e.t.get("cd")) > 0
		if not 是大:
			continue
		if 清零:
			e.cd = 0.0
			if J.truthy(e.get("readyTurn")) and float(e.readyTurn) > 1:
				e.readyTurn = 1.0
			u.holdUlt = false
		else:
			var n := J.num0(减值)
			if n == 0:
				n = 1.0
			if J.num(e.get("cd")) > 0:
				e.cd = maxf(0.0, float(e.cd) - n)
			if J.truthy(e.get("readyTurn")) and float(e.readyTurn) > 1:
				e.readyTurn = maxf(1.0, float(e.readyTurn) - n)

static func 减秘银牌冷却(ctx: Variant, card: Variant, 值: int = 1) -> int:
	if not (ctx is Dictionary) or 值 <= 0:
		return 0
	var 自己 := str(card.get("_实例号", "")) if card is Dictionary else ""
	var 减了 := 0
	for 池 in [ctx.get("战术手牌"), ctx.get("待触发战术牌")]:
		if not (池 is Array):
			continue
		for c in 池:
			if not (c is Dictionary) or not 是秘银计入牌(c):
				continue
			if 自己 != "" and str(c.get("_实例号", "")) == 自己:
				continue
			if int(c.get("当前冷却", 0)) > 0:
				c["当前冷却"] = maxi(0, int(c["当前冷却"]) - 值)
				减了 += 1
	return 减了

## 战术牌加标定层数（`补满` = 直接顶到上限，来源名记进标定来源）。
static func 卡牌加标定(目标: Variant, 层数: Variant, 来源名: Variant = "战术牌", 补满: bool = false) -> float:
	if 目标 == null:
		return 0.0
	var 上限 := Calc.标定层数上限()
	var d = Calc.标定经济拿条(目标)
	if d == null:
		return 0.0
	d.上限 = 上限
	var 前 := maxf(0.0, J.num0(d.get("层数")))
	var 加 := J.num0(层数)
	d.层数 = 上限 if 补满 else minf(上限, 前 + (加 if 加 != 0 else 1.0))
	if not J.some(J.or_(d.get("来源们"), []), func(g): return g != null and g.get("名") == 来源名):
		d.来源们 = J.concat(J.or_(d.get("来源们"), []), [{"键": "CARD", "名": 来源名, "方": "ally", "怎么来的": "战术牌"}])
	return float(d.层数)

## 单机牌组单位找目标：键 / 位号 / 位名（"前1"）都认
static func 找单位(ctx: Dictionary, 标识: Variant, 方: String) -> Variant:
	if ctx == null or 标识 == null:
		return null
	if 标识 is String and (标识 as String).strip_edges().is_empty():
		return null
	var 们 := Units.sideUnits(方, ctx)
	if 标识 is float or 标识 is int:
		var 死位 = null
		for u in 们:
			if u == null or int(u.slot) != int(标识):
				continue
			if _是活体(u):
				return u
			if 死位 == null:
				死位 = u
		return 死位
	if 标识 is Dictionary:
		return 标识 if J.inc(们, 标识) else null
	var 文 := str(标识).strip_edges()
	if 文.is_empty():
		return null
	var 死键 = null
	for u in 们:
		if u == null:
			continue
		if _键匹配(u, 文):
			if _是活体(u):
				return u
			if 死键 == null:
				死键 = u
	if 死键 != null:
		return 死键
	for u in 们:
		if u != null and Fm.位名(float(u.slot)) == 文:
			return u
	return null

## `找单位` 的存活判据（**没有 `hp` 字段**的单位按「活着」算 —— 别把非战斗单位筛掉）。
static func _是活体(u: Dictionary) -> bool:
	return float(u.get("hp", 1.0)) > 0.0

## `找单位`：这个单位的 key / tplKey / name 与 `文` 是否相等。
static func _键匹配(u: Dictionary, 文: String) -> bool:
	if 文.is_empty():
		return false
	if str(u.get("key", "")) == 文:
		return true
	if str(u.get("name", "")) == 文:
		return true
	var t := str(u.get("tplKey", ""))
	return not t.is_empty() and t == 文

static func _按位单位(们: Array, 位号: int) -> Variant:
	for u in 们:
		if u != null and int(u.slot) == 位号:
			return u
	return null

## 一张牌是否等于标识：字典按引用比，否则比实例号 / id / 牌名。
static func _卡匹配(c: Variant, 标识: Variant) -> bool:
	if not (c is Dictionary) or 标识 == null:
		return false
	if 标识 is Dictionary:
		return is_same(c, 标识)
	var 文 := str(标识)
	return (c.get("_实例号") != null and str(c._实例号) == 文) \
		or str(c.get("id", "")) == 文 or str(c.get("名", "")) == 文

## 在专属手牌里找一张牌（数字参数一律当武器下标，不当手牌下标）。
static func _找手牌卡(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("专属手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		return null   # 数字参数一律当武器下标，不当手牌下标（避免歧义）
	for c in u.专属手牌:
		if _卡匹配(c, 标识):
			return c
	return null

static func _找公有手牌卡(ctx: Dictionary, 标识: Variant) -> Variant:
	if not (ctx.get("公有手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		return null
	for c in ctx.公有手牌:
		if _卡匹配(c, 标识):
			return c
	return null

static func _找衍生卡(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("衍生手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		var i := int(标识)
		return u.衍生手牌[i] if (i >= 0 and i < u.衍生手牌.size()) else null
	for c in u.衍生手牌:
		if _卡匹配(c, 标识):
			return c
	return null

static func _找武器(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("weapons") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		var i := int(标识)
		return u.weapons[i] if (i >= 0 and i < u.weapons.size()) else null
	if 标识 is Dictionary:
		if 标识.get("t") is Dictionary:
			return 标识 if J.inc(u.weapons, 标识) else null
		var 名 := str(标识.get("name", 标识.get("武器名", "")))
		标识 = 名
	var 文 := str(标识)
	for e in u.weapons:
		if e is Dictionary and e.get("t") is Dictionary and str(e.t.get("name", "")) == 文:
			return e
	return null

## ★ DECK-3：`_身份对口` 的**公开**读法（下排公有牌「归属对不对口」的置灰判据）。
static func 身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	return Btl._身份对口(u, card, ctx)

## ★ DECK-3：`_是衍生卡` 的**公开**读法（下排公有牌里「这是不是衍生攻击卡」）。
static func 是衍生攻击卡(c: Variant) -> bool:
	return _是衍生卡(c)

## 这张武器卡打出后不销毁主武器（衍生攻击卡 / 带不销毁标记的）。
static func _不销毁主武器(w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	return J.truthy(w.get("不被销毁")) or J.truthy(w.get("不销毁其他武器")) or str(w.get("卡类", "")) == "衍生攻击卡"

## 这张牌算不算【衍生攻击卡】（卡类 / 衍生标记 / 秘银 TDD-1 三种认法）
static func _是衍生卡(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return str(c.get("卡类", "")) == "衍生攻击卡" or J.truthy(c.get("衍生")) or str(c.get("id", "")) == "TDD-1"
