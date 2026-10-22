## DECK-4：ATX 势力卡牌设计 v0.2 的卡表（25 张）+ 装填 + 专属效果执行器。
# 见 协作/设计/ATX势力卡牌设计 v0.2.md
class_name FacAtx
extends RefCounted

const 势力 := "ATX"
const 成员键: Array = ["A1", "A2", "A3", "A6", "A7"]
const 合体技成员: Array = ["A1", "A2"]
const 合体技ID := "U_ATX_COMBO"
const 赌神入局ID := "U_ATX_2"
const 梭哈冷却最小 := 1

const 旧版卡id们: Array = ["U_ATX_1", "U_ATX_3", "U_ATX_4", "U_ATX_5", "U_ATX_6", "U_ATX_7", "U_ATX_9"]

const _整数路径们 := [
	"效果[].全局[].上限", "效果[].全局[].先射段数", "效果[].全局[].冲锋段数",
	"效果[].全局[].段数", "效果[].全局[].每段", "效果[].全局[].每闪气势",
	"效果[].全局[].气势上限", "效果[].全局[].补段上限", "触发条件.阈值",
]

static var _表: Array = []
static var _表代: int = -1

# ---- 一、牌表（从 `data/cards/ATX.json` 读入 + 合并双子） ----
static func _还原值(v: Variant, 路径: String) -> Variant:
	if v is Dictionary:
		var 出 := {}
		for k in (v as Dictionary).keys():
			var 子路径 := str(k) if 路径 == "" else "%s.%s" % [路径, str(k)]
			出[k] = _还原值(v[k], 子路径)
		return 出
	if v is Array:
		var 组: Array = []
		var 子路径 := "%s[]" % 路径
		for x in (v as Array):
			组.append(_还原值(x, 子路径))
		return 组
	if typeof(v) == TYPE_FLOAT and 路径 in _整数路径们:
		return int(v)
	return v

static func _读表() -> Array:
	var 表: Array = []
	var 包: Dictionary = Db.T.get("卡包", {}).get(势力, {})
	for 条 in 包.get("v02卡表", []):
		if 条 is Dictionary:
			表.append(_还原值(条, ""))
	for c in AtxDuo.卡表():
		表.append(c)
	return 表

static func 卡表() -> Array:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读表()
		_表代 = Db.代
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return c.duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return c.duplicate(true)
	return {}

static func 有(id: Variant) -> bool:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return true
	return false

static func 是v02牌(card: Variant) -> bool:
	return card is Dictionary and 有(card.get("id"))

static func 是旧版(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	return J.inc(旧版卡id们, str((card as Dictionary).get("id", "")))

## 这 7 张旧卡的数据还在（红线：卡牌数据一张不删），但一律不进牌池。
static func 进牌池(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	return not J.inc(旧版卡id们, str((card as Dictionary).get("id", "")))

## 按名查询：v0.1 三小强卡表 → v0.2 卡表 → 双子卡表。
static func 按名取(名: Variant) -> Dictionary:
	var 文 := str(名)
	if 文 == "":
		return {}
	for c in AtxThree.卡表():
		if c is Dictionary and str((c as Dictionary).get("名", "")) == 文 and not J.truthy((c as Dictionary).get("加版")):
			return (c as Dictionary).duplicate(true)
	for c in 卡表():
		if c is Dictionary and str((c as Dictionary).get("名", "")) == 文 and not J.inc(旧版卡id们, str(c.get("id", ""))):
			return (c as Dictionary).duplicate(true)
	for c in AtxDuo.卡表():
		if c is Dictionary and str((c as Dictionary).get("名", "")) == 文:
			return (c as Dictionary).duplicate(true)
	return {}

static func 按id取(id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in AtxThree.卡表():
		if c is Dictionary and str(c.get("id", "")) == 键:
			return (c as Dictionary).duplicate(true)
	for c in 卡表():
		if c is Dictionary and str(c.get("id", "")) == 键:
			if J.inc(旧版卡id们, 键):
				return {}
			return (c as Dictionary).duplicate(true)
	for c in AtxDuo.卡表():
		if c is Dictionary and str(c.get("id", "")) == 键:
			return (c as Dictionary).duplicate(true)
	return {}

static func 角色牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "角色")

static func 势力牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "势力")

static func 合体技卡() -> Dictionary:
	return 卡(合体技ID)

static func 轮盘双响可打吗(ctx: Variant, u: Variant = null) -> bool:
	return AtxFaction.轮盘双响可打吗(ctx, u)

static func 轮盘双响不可打原因(ctx: Variant, u: Variant = null) -> String:
	if not (ctx is Dictionary):
		return "单机牌组未开启"
	return AtxFaction.轮盘双响不可打原因(ctx, u)

static func 卡类(card: Variant) -> String:
	if not (card is Dictionary):
		return ""
	return str(card.get("卡类", ""))

static func 是主武器卡(card: Variant) -> bool:
	return 卡类(card) == "主武器卡"

static func 是专属精神牌(card: Variant) -> bool:
	return 卡类(card) == "专属精神牌"

static func 是衍生攻击卡(card: Variant) -> bool:
	return 卡类(card) == "衍生攻击卡"

static func 是公有牌(card: Variant) -> bool:
	return 卡类(card) == "公有牌"

static func 角色专属牌们(键: Variant, _ctx: Variant = null) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 卡表():
		if str(c.get("角色", "")) == k or J.inc(J.or_(c.get("角色们"), []), k):
			if not 进牌池(c):
				continue
			出.append(c.duplicate(true))
	return 出

static func 公有牌们() -> Array:
	return 势力牌们()

# ---- 二、装填 / 分流 ----
static func 装填(ctx: Variant, 在场角色键们: Variant) -> Array:
	var 出: Array = []
	var 成员 := J.filter(在场角色键们, func(k): return J.inc(成员键, k))
	if 成员.is_empty():
		return 出
	for k in 成员键:
		if not J.inc(成员, k):
			continue
		for c in 卡表():
			if str(c.get("种类", "")) == "角色" and str(c.get("角色", "")) == k:
				出.append(Btl.克隆战术牌(c, ctx))
	if 合体技在场(成员):
		出.append(Btl.克隆战术牌(合体技卡(), ctx))
	for c in 卡表():
		if str(c.get("种类", "")) == "势力":
			出.append(Btl.克隆战术牌(c, ctx))
	return 出

static func 合体技在场(在场角色键们: Variant) -> bool:
	return J.every(合体技成员, func(k): return J.inc(在场角色键们, k))

static func 涉及角色键(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	for k in J.or_(card.get("角色们"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	var 单 := str(card.get("角色", ""))
	if 单 != "" and not J.inc(出, 单):
		出.append(单)
	return 出

static func 占行动键(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	if 出.is_empty() and str(card.get("类型", "")) == "大招" and str(card.get("角色", "")) != "":
		出.append(str(card.get("角色")))
	return 出

static func 是合体技(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	return J.truthy(card.get("合体技")) or str(card.get("种类", "")) == "合体技" \
		or J.or_(card.get("占行动"), []).size() >= 2

# ---- 三、效果执行器 ----
static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx = 运行.get("ctx")
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	if not (ctx is Dictionary):
		return []
	match 动作:
		"赌神": return _赌神(ctx, card, 表)
		"赌神入局": return AtxGodsbet.打出算子(ctx, card)
		"轮盘双响": return _轮盘双响(ctx, card, 表)
		"势力v03": return AtxFaction.执行算子(ctx, 表, _目标们)
		"守护": return _守护(ctx, card, 表)
		"硬碰硬": return _硬碰硬(ctx, card, 表)
		"治疗": return _治疗(ctx, 表)
		"读牌": return 读牌(ctx)
		"冷却清零": return _冷却清零(ctx, 表)
		"止损": return _止损(ctx, 表)
		"标记": return _标记(ctx, 表)
		"降费": return _降费(ctx, 表)
	push_error("FacAtx：未知的 ATX 动作「%s」" % 动作)
	return []

static func _队友(ctx: Dictionary, 键: String) -> Variant:
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key")) == 键:
			return u
	return null

static func _是ATX(u: Variant) -> bool:
	return u is Dictionary and str(Btl.提取单位三层信息(u).势力) == 势力

static func ATX成员(ctx: Dictionary) -> Array:
	return Units.livingOf("ally", ctx).filter(func(u): return _是ATX(u))

static func 血比(u: Variant) -> float:
	var 上 := float(u.get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float(u.get("hp", 0.0)) / 上

static func _头(们: Array, 比较: Callable) -> Array:
	if 们.is_empty():
		return []
	var 排 := 们.duplicate()
	J.sort(排, 比较)
	return [排[0]]

static func _选目标(ctx: Dictionary, 参: Dictionary) -> Array:
	var 敌 := Units.livingOf("enemy", ctx)
	if 敌.is_empty():
		return []
	match str(参.get("目标", "自动")):
		"全体":
			return 敌
		"一排":
			var 前 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			var 后 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_BACK)
			return 前 if 前.size() >= 后.size() else 后
		"最高血":
			return _头(敌, func(a, b):
				var d := float(b.get("hp", 0.0)) - float(a.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"最低血":
			return _头(敌, func(a, b):
				var d := float(a.get("hp", 0.0)) - float(b.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"前排优先":
			var 前2 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			return _头(前2 if not 前2.is_empty() else 敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		_:
			return _头(敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))

static func _武器(名: String, 参: Dictionary, 威力: float, 命中: float, 段数: int) -> Dictionary:
	var 曲射: bool = J.truthy(参.get("曲射"))
	var 近战: bool = J.truthy(参.get("近战"))
	var w := {
		"name": 名, "fire": "melee" if 近战 else ("indirect" if 曲射 else "direct"),
		"power": 威力, "hit": 命中, "critMod": J.num0(参.get("暴击")),
		"stat": str(参.get("属性", "射击")), "dmgType": str(参.get("伤害类型", "物理")),
		"cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"ignoreDef": J.truthy(参.get("无视防御")), "special": null,
	}
	if 段数 > 1:
		w["hits"] = float(段数)
		w["special"] = "multi"
	return w

static func _被挡罚(ctx: Dictionary, 攻: Variant, t: Variant, w: Dictionary) -> float:
	if t == null or t.get("slot") == null:
		return 0.0
	var kind = Reach.rangeKindOf(w)
	if kind != Reach.KIND_DIRECT():
		return 0.0
	var 活位 = Units.livingOf("enemy", ctx).map(func(x): return x.slot)
	return Reach.rowBlockPenalty(kind, t.get("slot"), 活位, 攻, t)

static func _一发(ctx: Dictionary, 攻: Dictionary, t: Dictionary, w: Dictionary, 必暴: bool = false) -> Dictionary:
	var 结算: Dictionary = Flow.结算一个目标(ctx, 攻, t, w,
		{"改目标": false, "blockPenalty": _被挡罚(ctx, 攻, t, w), "必暴": 必暴, "不写标准攻击日志": true, "旁路攻击": true})
	var rec: Dictionary = 结算.rec
	var 段数 := int(rec.get("段数", 1.0))
	var 中 := int(rec.get("命中段数", 段数))
	if 中 < 段数:
		t["_本回合被打空回合"] = int(ctx.get("turn", 1))
	return rec

static func _记攻击(ctx: Dictionary, 牌名: String, card: Dictionary, 攻: Dictionary, t: Dictionary, rec: Dictionary, 额外: Dictionary = {}) -> void:
	var 字段: Dictionary = J.merged(J.merged({
		"类型": "攻击", "单位": 攻.get("key"), "武器": 牌名,
		"战术牌": card.get("id"), "目标": t.get("key"),
	}, Btl.谁(攻)), Btl.谁目标(t))
	字段 = J.merged(字段, rec.get("字段"))
	字段 = J.merged(字段, 额外)
	Btl.pushLog(ctx, "〔%s〕%s → %s：%s" % [牌名, str(攻.get("name", "")), str(t.get("name", "")), rec.get("文本")], 字段)

static func _赌神(ctx: Dictionary, card: Dictionary, _参: Dictionary) -> Array:
	return AtxGodsbet.打出算子(ctx, card)

static func _段账(rec: Variant, 段数: int) -> Dictionary:
	var 字: Dictionary = {}
	if rec is Dictionary:
		var 内 = (rec as Dictionary).get("字段")
		字 = 内 if 内 is Dictionary else rec
	var 中 := int(J.num0(字.get("命中段数"))) if 字.has("命中段数") else 段数
	return {"命中段数": 中, "暴击": int(J.num0(字.get("暴击")))}

## 合体技【轮盘双响】：艾克赛琳先射 4 段 → 响介冲锋 8 段 → 任一段打空由另一人必中必暴补段（最多 6 次）→ 触发赌局。
static func _轮盘双响(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 艾 = _队友(ctx, "A2")
	var 响 = _队友(ctx, "A1")
	if 艾 == null or 响 == null:
		return ["【轮盘双响】响介 / 艾克赛琳 不在场，打不出"]
	var t = null
	var 指定 = ctx.get("_当前目标")
	if 指定 != null:
		var v = Btl.找单位(ctx, 指定, "enemy")
		if v is Dictionary and float(v.get("hp", 0.0)) > 0.0:
			t = v
	if t == null:
		var 敌 := _选目标(ctx, {"目标": "自动"})
		if 敌.is_empty():
			return ["【轮盘双响】没有可打的目标"]
		t = 敌[0]
	var 先段 := maxi(1, int(参.get("先射段数", 4)))
	var 冲段 := maxi(1, int(参.get("冲锋段数", 8)))
	var 先威 := J.num0(参.get("先射威力", 600.0))
	var 冲威 := J.num0(参.get("冲锋威力", 500.0))
	var 先命 := J.num0(参.get("先射命中", 90.0))
	var 冲命 := J.num0(参.get("冲锋命中", 75.0))
	var 总段 := 0
	var 打空 := 0
	var 步们 := [
		[艾, "轮盘双响·艾克赛琳先射", 先段, 先威, 先命, false],
		[响, "轮盘双响·响介冲锋", 冲段, 冲威, 冲命, true],
	]
	var 缺口: Array = []
	for 步 in 步们:
		var 谁: Dictionary = 步[0]
		if float(t.get("hp", 0.0)) <= 0.0:
			break
		var w := _武器(str(步[1]), {"近战": J.truthy(步[5])}, J.num0(步[3]), J.num0(步[4]), int(步[2]))
		var rec := _一发(ctx, 谁, t, w, false)
		_记攻击(ctx, str(步[1]), card, 谁, t, rec, {"合体技": true})
		var 账 := _段账(rec, int(步[2]))
		var 中 := int(账["命中段数"])
		var 缺 := maxi(0, int(步[2]) - 中)
		总段 += int(步[2])
		打空 += 缺
		缺口.append([响 if is_same(谁, 艾) else 艾, 缺])
		摘要.append("%s：%d 段（命中 %d / 打空 %d）" % [str(步[1]), int(步[2]), 中, 缺])
	var 上限 := maxi(0, int(参.get("补段上限", 6)))
	var 必暴 := J.truthy(参.get("补段必暴", true))
	var 补总 := 0
	var 补暴 := 0
	for 组 in 缺口:
		var 补者: Dictionary = 组[0]
		var 可补 := mini(int(组[1]), 上限 - 补总)
		if 可补 <= 0:
			continue
		if float(t.get("hp", 0.0)) <= 0.0:
			break
		var 补威 := 先威 if is_same(补者, 艾) else 冲威
		var 补名 := "轮盘双响·%s补段" % str(补者.get("name", ""))
		var w2 := _武器(补名, {"必中": true}, 补威, 100.0, 可补)
		w2["必中"] = true
		var rec2 := _一发(ctx, 补者, t, w2, 必暴)
		_记攻击(ctx, 补名, card, 补者, t, rec2, {"合体技": true, "补段": true, "必暴": 必暴})
		var 账2 := _段账(rec2, 可补)
		补总 += 可补
		补暴 += int(账2["暴击"])
		总段 += 可补
		摘要.append("%s：%d 段（命中 %d / 必暴 %d 段）" % [补名, 可补, int(账2["命中段数"]), int(账2["暴击"])])
	var 亮 = null
	if J.truthy((艾 as Dictionary).get("闪")):
		亮 = 艾
	elif J.truthy((响 as Dictionary).get("闪")):
		亮 = 响
	var 赌 := {}
	if 亮 != null:
		赌 = AtxChips.触发赌局(ctx, 亮, card, true)
	Btl.pushLog(ctx, "〔轮盘双响〕艾克赛琳先射 %d 段 + 响介冲锋 %d 段 + 补段 %d 段（打空 %d 段）→ 总段数 %d；补的段必暴击（暴击 %d 段）%s" % [
		先段, 冲段, 补总, 打空, 总段, 补暴,
		"" if 亮 == null else "；赌局由 %s 的闪字触发" % str((亮 as Dictionary).get("name", ""))],
		J.merged({"类型": "合体技", "势力": 势力, "卡牌ID": 合体技ID, "卡牌": card.get("名"),
			"轮盘双响": true,
			"先射段": float(先段), "冲锋段": float(冲段), "补段": float(补总), "总段数": float(总段),
			"打空段": float(打空), "补段暴击": float(补暴), "必暴": 必暴,
			"赌局": 赌, "回合": ctx.turn}, Btl.谁(艾)))
	摘要.append("总段数 %d = %d + %d + 补段 %d；补段必暴击（暴击 %d 段）" % [总段, 先段, 冲段, 补总, 补暴])
	return 摘要

static func _增益表(参: Dictionary) -> Dictionary:
	var 出: Dictionary = J.or_(参.get("增益"), {}).duplicate(true)
	if 出.get("剩余") == null:
		出["剩余"] = 1.0
	return 出

static func _光环(ctx: Dictionary, 参: Dictionary) -> Array:
	var 范围 := str(参.get("范围", "ATX"))
	var 增益 := _增益表(参)
	var 源 := "ATX:%s" % 范围
	var 们: Array = []
	match 范围:
		"我方全体", "敌我全体":
			们 = Units.livingOf("ally", ctx)
		"敌方前排":
			们 = Units.livingOf("enemy", ctx).filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
		"敌方全体":
			们 = Units.livingOf("enemy", ctx)
		_:
			们 = ATX成员(ctx)
	for u in 们:
		Btl.换同源增益(u, 源, 增益)
	if 范围 == "敌我全体":
		for e in Units.livingOf("enemy", ctx):
			Btl.换同源增益(e, 源, 增益)
	Btl.pushLog(ctx, "〔ATX 光环·%s〕%s：%d 台（%s）" % [范围, str(参.get("说明", "本回合光环")), 们.size(), str(增益)],
		{"类型": "增益", "势力": 势力, "光环": 范围, "台数": float(们.size()), "回合": ctx.turn})
	return ["ATX 光环·%s：%d 台" % [范围, 们.size()]]

static func _守护(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	u["守护中"] = ctx.turn
	Btl.换同源增益(u, "守护", _增益表(参))
	Btl.pushLog(ctx, "〔守护〕%s 本回合替对位队友承受攻击" % str(u.get("name", "")),
		{"类型": "增益", "势力": 势力, "单位": 键, "守护": true, "回合": ctx.turn})
	return ["守护：%s 替对位队友挡枪" % str(u.get("name", ""))]

static func _硬碰硬(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	u["硬碰硬中"] = ctx.turn
	Btl.换同源增益(u, "硬碰硬", {"受伤Mul": -0.30, "eva": -100.0, "剩余": 1.0})
	Btl.pushLog(ctx, "〔硬碰硬〕%s 本回合闪避归零、受到伤害 −30%%，每受击一次自己的大招牌冷却 −1" % str(u.get("name", "")),
		{"类型": "增益", "势力": 势力, "单位": 键, "回合": ctx.turn})
	return ["硬碰硬：闪避归零、受伤 −30%"]

static func _治疗(ctx: Dictionary, 参: Dictionary) -> Array:
	var 们 := Units.livingOf("ally", ctx)
	if 们.is_empty():
		return ["没有可治疗的队友"]
	var 排 := 们.duplicate()
	J.sort(排, func(a, b):
		var d := 血比(a) - 血比(b)
		return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
	var t: Dictionary = 排[0]
	var 前 := float(t.get("hp", 0.0))
	var 量 := J.round(float(t.get("maxHp", 0.0)) * J.num0(参.get("比", 0.25)))
	t["hp"] = minf(float(t.get("maxHp", 0.0)), 前 + 量)
	Btl.pushLog(ctx, "〔念动迷彩·治愈〕%s 回复 %s（%s → %s）" % [str(t.get("name", "")), J.s(J.round(float(t.hp) - 前)),
		J.s(J.round(前)), J.s(J.round(float(t.hp)))],
		{"类型": "修理", "单位": t.get("key"), "回复": J.round(float(t.hp) - 前), "回合": ctx.turn})
	return ["治疗：%s 回复 %d" % [str(t.get("name", "")), J.round(float(t.hp) - 前)]]

static func 读牌(ctx: Dictionary) -> Array:
	var 意图: Array = Btl.算意图(ctx)
	var 打 := 0
	var 名们: Array = []
	for 条 in 意图:
		if not (条 is Dictionary):
			continue
		var 目标键 = 条.get("目标")
		var 打ATX := false
		for u in ATX成员(ctx):
			if 目标键 != null and str(u.get("key")) == str(目标键):
				打ATX = true
				break
		if not 打ATX:
			continue
		var 敌 = _找敌(ctx, str(条.get("单位", "")))
		if 敌 == null:
			continue
		Btl.换同源增益(敌, "读牌", {"hit": -30.0, "剩余": 1.0})
		打 += 1
		名们.append(str(敌.get("name", "")))
	Btl.pushLog(ctx, "〔读牌〕本回合意图攻击 ATX 的敌人命中 −30：%s" % ("、".join(名们) if not 名们.is_empty() else "（这一回合没有敌人瞄准 ATX）"),
		{"类型": "增益", "势力": 势力, "读牌": true, "台数": float(打), "命中惩罚": -30.0, "回合": ctx.turn})
	return ["读牌：%d 台敌人命中 −30" % 打]

static func _找敌(ctx: Dictionary, 键: String) -> Variant:
	for e in Units.livingOf("enemy", ctx):
		if str(e.get("key")) == 键:
			return e
	return null

static func _冷却清零(ctx: Dictionary, 参: Dictionary) -> Array:
	if J.truthy(ctx.get("ATX梭哈已用")):
		return ["梭哈：本场已经用过 1 次"]
	ctx["ATX梭哈已用"] = true
	var 最小 := maxi(1, int(参.get("最小冷却", 梭哈冷却最小)))
	var 清 := 0
	for u in Units.livingOf("ally", ctx):
		for 池 in [J.or_(u.get("专属手牌"), []), J.or_(u.get("专属牌库"), []), J.or_(u.get("专属弃牌堆"), [])]:
			for c in 池:
				if not (c is Dictionary) or str(c.get("归属", "")) != 势力:
					continue
				var 旧 := int(c.get("当前冷却", 0))
				if 旧 <= 0:
					continue
				c["当前冷却"] = 最小
				清 += 1
	Btl.pushLog(ctx, "〔梭哈〕所有冷却中的 ATX 角色牌冷却清零（清零后最小冷却 %d；本场只能用 1 次，清了 %d 张）" % [最小, 清],
		{"类型": "减冷却", "势力": 势力, "清零": true, "最小冷却": 最小, "张数": float(清), "回合": ctx.turn})
	return ["梭哈：%d 张 ATX 角色牌冷却清零（最小 %d）" % [清, 最小]]

static func _止损(ctx: Dictionary, 参: Dictionary) -> Array:
	var 段 := maxi(0, int(ctx.get("ATX上回合打空", 0)))
	var 加 := mini(int(参.get("上限", 15)), 段)
	Btl.pushLog(ctx, "〔止损〕上回合打空 %d 段" % 段,
		{"类型": "增益", "势力": 势力, "回合": ctx.turn})
	return ["止损：上回合打空 %d 段" % 段]

static func _标记(ctx: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("键", ""))
	if 键 == "":
		return []
	ctx[键] = true
	Btl.pushLog(ctx, "〔%s〕本回合生效（只生效一次）" % 键,
		{"类型": "增益", "势力": 势力, "标记": 键, "回合": ctx.turn})
	return ["%s：本回合生效" % 键]

static func _降费(ctx: Dictionary, 参: Dictionary) -> Array:
	var 值 := int(参.get("值", 10))
	ctx["下张ATX角色牌降费"] = int(ctx.get("下张ATX角色牌降费", 0)) + 值
	Btl.pushLog(ctx, "〔幸运连号〕下一张 ATX 角色牌费用 −%d（累计 %d）" % [值, int(ctx["下张ATX角色牌降费"])],
		{"类型": "降费", "势力": 势力, "值": 值, "累计": int(ctx["下张ATX角色牌降费"]), "回合": ctx.turn})
	return ["幸运连号：下一张 ATX 角色牌降费 −%d" % 值]

# ---- 四、每回合 / 每场状态 ----
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["下张ATX角色牌降费"] = 0
	ctx["ATX赌神上次打空"] = 0
	ctx["ATX梭哈已用"] = false
	ctx["ATX本回合起始打空"] = int(J.g(ctx.get("战况计数"), "未命中段"))
	ctx["ATX上回合打空"] = 0
	AtxFaction.初始化(ctx)
	AtxGodsbet.初始化(ctx)
	AtxLuck.初始化(ctx)

static func 本回合重置(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	var 本场 := int(J.g(ctx.get("战况计数"), "未命中段"))
	var 起始 := int(ctx.get("ATX本回合起始打空", 本场))
	ctx["ATX上回合打空"] = maxi(0, 本场 - 起始)
	ctx["ATX本回合起始打空"] = 本场
	ctx["下张ATX角色牌降费"] = 0
	ctx.erase("ATX二次下注")
	ctx.erase("ATX庄家通吃")
	AtxFaction.阶段初(ctx)

static func 我方阶段初_前(ctx: Variant) -> void:
	本回合重置(ctx)
