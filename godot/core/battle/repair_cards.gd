## 职责：第 7 职业【维修】的 6 张分类牌 + 职业专属机制【过量整备】。
## 约定：公有排、按职业限制、谁打出扣谁的战意；牌面数值全部从 `data/cards/维修职业分类牌.json` 读入。
## 见 协作/设计/维修职业分类牌 v0.1.md（v0.1.1）
class_name RepairCards
extends RefCounted

const 职业 := "维修"
const 包名 := "维修职业分类牌"

## 「本回合」/「到下个我方阶段前」的单位级状态键（`阶段初()` 统一清）。
const 阶段初清键: Array = ["过量整备命中", "紧急损管中", "紧急损管施放者"]

## 本场统计的 ctx 键（`{回复, 过量整备}`，给三层反馈的「结算」读）。
const 统计键 := "维修统计"

# ==========================================================================================
# 一、牌面（6 张，从 `data/cards/维修职业分类牌.json` 读入）
# ==========================================================================================
static var _表: Array = []
static var _表代: int = -1

static func _读表() -> Array:
	var 表: Array = []
	var 包: Dictionary = Db.T.get("卡包", {}).get(包名, {})
	for 条 in 包.get("分类牌", []):
		if 条 is Dictionary:
			表.append(条)
	return 表

static func 卡表() -> Array:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读表()
		_表代 = Db.代
	return _表

static func 职业牌们() -> Array:
	return 卡表()

static func 卡(id: String) -> Dictionary:
	for c in 卡表():
		if str(c.get("id", "")) == id:
			return c
	return {}

static func 按名(名: String) -> Dictionary:
	for c in 卡表():
		if str(c.get("名", "")) == 名:
			return c
	return {}

## 这张牌是不是【维修】分类牌（`归属 = 维修` 且带 `分类牌` 标记）。
static func 是维修牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return str((c as Dictionary).get("归属", "")) == 职业 and J.truthy((c as Dictionary).get("分类牌"))

# ==========================================================================================
# 二、出牌门槛（规则钩子【卡不可打原因】）
# ==========================================================================================
## 只有【全舱整备】自带额外门槛：代价是「本回合打出者不能打主武器」，
## 所以已经打过主武器的机体本回合就再也打不出它（§1 第 5 行）。
static func 卡不可打原因(_ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	if not 是维修牌(card):
		return {"终局": false}
	if str(card.get("名", "")) == "全舱整备" and J.truthy(u.get("主武器已销毁")):
		return {"终局": true, "原因": "本回合已经打过主武器（全舱整备的代价是不能再打主武器，所以本回合打不出来）"}
	return {"终局": false}

# ==========================================================================================
# 三、效果算子（`CardEffects.执行算子` 的 `"维修牌"` 分支转到这里）
# ==========================================================================================
static func _ctxOf(运行: Dictionary) -> Dictionary:
	var c = 运行.get("ctx")
	return c if c is Dictionary else {}

static func _施放者(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 键 := str(ctx.get("_当前出牌者", ""))
	if 键 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key", "")) == 键:
				return u
	return null

## 指定的友军：`ctx._当前目标` → 血比最低的存活友军（确定性，不掷随机数）。
static func _目标(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	var 友们 := Units.livingOf("ally", ctx)
	if 友们.is_empty():
		return null
	J.sort(友们, func(a, b):
		var d := 血比(a) - 血比(b)
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	return 友们[0]

static func 血比(u: Variant) -> float:
	if not (u is Dictionary):
		return 0.0
	var 上 := float(u.get("maxHp", 0.0))
	return 0.0 if 上 <= 0.0 else float(u.get("hp", 0.0)) / 上

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String, 额外: Dictionary = {}) -> void:
	var 谁 := J.merged({"类型": "分类牌", "牌名": 牌名}, 额外)
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % str((u as Dictionary).get("name", ""))) if u is Dictionary else "", 文], 谁)

## 累计统计（三层反馈的「结算」）：本场总回复量 / 【过量整备】触发次数。
static func _计(ctx: Dictionary, 键: String, 加: float) -> void:
	var 统: Dictionary = ctx.get(统计键) if ctx.get(统计键) is Dictionary else {"回复": 0.0, "过量整备": 0.0}
	统[键] = J.num0(统.get(键)) + 加
	ctx[统计键] = 统

static func 统计(ctx: Variant) -> Dictionary:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get(统计键) is Dictionary):
		return {"回复": 0.0, "过量整备": 0.0}
	return (ctx as Dictionary).get(统计键)

## 回复一名友军 `比` 比例的最大 HP，返回 `{前, 后, 回复, 溢出, 满血}`。
static func _回(ctx: Dictionary, 目标: Dictionary, 比: float) -> Dictionary:
	var 上 := float(目标.get("maxHp", 0.0))
	var 前 := float(目标.get("hp", 0.0))
	var 量 := J.round(上 * 比)
	目标["hp"] = minf(上, 前 + 量)
	var 实 := float(目标.get("hp")) - 前
	_计(ctx, "回复", 实)
	return {"前": 前, "后": float(目标.get("hp")), "回复": 实,
		"溢出": maxf(0.0, 前 + 量 - 上), "满血": 前 >= 上}

## 【过量整备】判定：目标**已满血**，或**本次回复量溢出**（§0 双轨解法的第 1 条）。
static func 触发过量整备(回: Dictionary) -> bool:
	return J.truthy((回 as Dictionary).get("满血")) or float((回 as Dictionary).get("溢出")) > 0.0

## 「回复 X HP（前 → 后）」的半句话。
static func _回文(回: Dictionary) -> String:
	return "回复 %s HP（%s → %s）" % [J.s((回 as Dictionary).get("回复")),
		J.s((回 as Dictionary).get("前")), J.s((回 as Dictionary).get("后"))]

## 牌子面上一共给了几张「维修牌」—— 风控用（防同一个动作名手滑写错）。
static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx := _ctxOf(运行)
	if ctx.is_empty():
		return []
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(card.get("名", 动作))
	var 施 = _施放者(运行)
	if not (施 is Dictionary):
		return ["没有能打出这张分类牌的机体"]
	match 动作:
		"常规整备":
			return [_常规整备(ctx, 牌名, 运行, 施)]
		"装甲焊补":
			return [_装甲焊补(ctx, 牌名, 运行, 施)]
		"强制排热":
			return [_强制排热(ctx, 牌名, 运行, 施)]
		"野战补给":
			return [_野战补给(ctx, 牌名, 运行, 施)]
		"全舱整备":
			return [_全舱整备(ctx, 牌名, 施)]
		"紧急损管":
			return [_紧急损管(ctx, 牌名, 运行, 施)]
	push_error("RepairCards：未知的维修分类牌动作「%s」" % 动作)
	return []

## 1 常规整备（0 费）：回复 15%；过量整备 → 该友军战意 +10、本回合下一张武器牌每段命中 +10。
static func _常规整备(ctx: Dictionary, 牌名: String, 运行: Dictionary, _施: Dictionary) -> String:
	var t = _目标(运行)
	if not (t is Dictionary):
		return "没有能整备的友军"
	var 回 := _回(ctx, t, 0.15)
	if not 触发过量整备(回):
		var 平 := _回文(回)
		_记(ctx, 牌名, t, 平)
		return 平
	var 前 := Btl.战意(t)
	Btl.加战意(t, 10.0, ctx, 牌名)
	t["过量整备命中"] = ctx.get("turn")
	_计(ctx, "过量整备", 1.0)
	var 文 := "%s；〔过量整备〕战意 +%d（%s → %s）、本回合下一张武器牌每段命中 +10" % [
		_回文(回), int(Btl.战意(t) - 前), J.s(前), J.s(Btl.战意(t))]
	_记(ctx, 牌名, t, 文, {"过量整备": true, "战意": t.get("战意")})
	return 文

## 2 装甲焊补（10 费）：回复 25% + 清命中 / 防御减益；
##   过量整备 → 到下个我方阶段前有效装甲 +25%，有掩护的再补 1 次掩护。
static func _装甲焊补(ctx: Dictionary, 牌名: String, 运行: Dictionary, _施: Dictionary) -> String:
	var t = _目标(运行)
	if not (t is Dictionary):
		return "没有能焊补的友军"
	var 回 := _回(ctx, t, 0.25)
	t["debuffs"] = []
	t["armorCut"] = 0.0
	t["buffs"] = J.or_(t.get("buffs"), []).filter(func(b):
		return not (b is Dictionary and (J.num0((b as Dictionary).get("hit")) < 0.0 or J.num0((b as Dictionary).get("def")) < 0.0)))
	if not 触发过量整备(回):
		var 平 := _回文(回)
		_记(ctx, 牌名, t, 平)
		return 平
	Btl.换同源增益(t, 牌名, {"armorPct": 25.0, "剩余": 1.0})
	var 掩 := ""
	if BattleGuard.是掩护者(t):
		t["掩护补充"] = 1
		掩 = "、掩护次数 +1（本阶段 %d 次）" % BattleGuard.掩护额度(t)
	_计(ctx, "过量整备", 1.0)
	var 文 := "%s；〔过量整备〕有效装甲 +25%%（到下个我方阶段前）%s" % [_回文(回), 掩]
	_记(ctx, 牌名, t, 文, {"过量整备": true, "掩护补充": 掩 != ""})
	return 文

## 3 强制排热（5 费）：回复 15% + 把目标 1 张正在冷却的副武器 / 专属牌冷却 −2；
##   过量整备 → 目标本回合伤害 +15%。
static func _强制排热(ctx: Dictionary, 牌名: String, 运行: Dictionary, _施: Dictionary) -> String:
	var t = _目标(运行)
	if not (t is Dictionary):
		return "没有能排热的友军"
	var 回 := _回(ctx, t, 0.15)
	var 减 := _减一条冷却(t, 2.0)
	var 文 := _回文(回)
	if 减 != "":
		文 += "；%s 冷却 −2" % 减
	else:
		文 += "；左栏没有正在冷却的副武器 / 专属牌（这一半没吃上）"
	if not 触发过量整备(回):
		_记(ctx, 牌名, t, 文)
		return 文
	Btl.换同源增益(t, 牌名, {"dmgMul": 0.15, "剩余": 1.0})
	_计(ctx, "过量整备", 1.0)
	文 += "；〔过量整备〕本回合伤害 +15%"
	_记(ctx, 牌名, t, 文, {"过量整备": true})
	return 文

## 4 野战补给（15 费）：目标友军战意 −10，把它 1 张**武器型大招**冷却 −2；
##   过量整备（该友军 HP ≥ 80%）→ 额外抽 1 张公有牌。**不能指定自己**。
static func _野战补给(ctx: Dictionary, 牌名: String, 运行: Dictionary, 施: Dictionary) -> String:
	var t = _目标(运行)
	if not (t is Dictionary):
		return "没有能补给的友军"
	if is_same(t, 施):
		var 换 = _另一台友军(运行, 施)
		if not (换 is Dictionary):
			return "野战补给不能指定自己，场上也没有别的友军"
		t = 换
	var 前 := Btl.战意(t)
	Btl.加战意(t, -10.0, ctx, 牌名)
	var 文 := "战意 −%d（%s → %s）" % [int(前 - Btl.战意(t)), J.s(前), J.s(Btl.战意(t))]
	var 减 := _减大招冷却(t, 2.0)
	if 减 != "":
		文 += "；大招【%s】冷却 −2" % 减
	else:
		文 += "；大招槽里没有正在冷却的武器型大招（这一半没吃上）"
	var 过 := 血比(t) >= 0.8
	if 过:
		_计(ctx, "过量整备", 1.0)
		var 抽 := Setup.抽公有牌(ctx, 1)
		文 += "；〔过量整备〕额外抽 %d 张公有牌" % 抽.size()
	_记(ctx, 牌名, t, 文, {"过量整备": 过})
	return 文

## 5 全舱整备（15 费）：我方全体回复 15%；结算后每台**满血**的友军战意 +5、受伤 −15%。
##   代价：本回合打出者不能打主武器（门槛在 `卡不可打原因`，这里落状态）。
static func _全舱整备(ctx: Dictionary, 牌名: String, 施: Dictionary) -> String:
	var 台 := 0
	var 满血们: Array = []
	for u in Units.livingOf("ally", ctx):
		if not (u is Dictionary):
			continue
		_回(ctx, u, 0.15)
		台 += 1
		if 血比(u) >= 0.999:
			满血们.append(u)
	for u in 满血们:
		Btl.加战意(u, 5.0, ctx, 牌名)
		Btl.换同源增益(u, 牌名, {"受伤Mul": -0.15, "剩余": 1.0})
	施["主武器已销毁"] = true
	var 名们: Array = 满血们.map(func(u): return str((u as Dictionary).get("name", "")))
	var 文 := "我方 %d 台全体回复 15%% HP" % 台
	if 满血们.is_empty():
		文 += "；〔过量整备〕没有满血友军（战意 +5 / 受伤 −15% 没吃到）"
	else:
		_计(ctx, "过量整备", 1.0)
		文 += "；〔过量整备〕%d 台满血：%s 战意 +5、到下个我方阶段前受伤 −15%%" % [满血们.size(), "、".join(名们)]
	文 += "；代价：%s 本回合不能打主武器" % str(施.get("name", ""))
	_记(ctx, 牌名, 施, 文, {"过量整备": not 满血们.is_empty(), "满血台数": float(满血们.size())})
	return 文

## 6 紧急损管（15 费，每场 1 次）：回复 20% + 挂〔紧急损管〕（致命伤害时锁 1 血、弹回 20%、给打出者 +15 战意）。
static func _紧急损管(ctx: Dictionary, 牌名: String, 运行: Dictionary, 施: Dictionary) -> String:
	var t = _目标(运行)
	if not (t is Dictionary):
		return "没有能损管的友军"
	var 回 := _回(ctx, t, 0.20)
	t["紧急损管中"] = ctx.get("turn")
	t["紧急损管施放者"] = 施.get("key")
	var 文 := "回复 %s HP，并挂上〔紧急损管〕（到下个我方阶段前：致命伤害锁 1 血 → 再回 20%% + %s 战意 +15）" % [
		J.s((回 as Dictionary).get("回复")), str(施.get("name", ""))]
	_记(ctx, 牌名, t, 文, {"紧急损管": true})
	return 文

# ==========================================================================================
# 四、冷却缩减 / 找友军（纯读 + 精确写入）
# ==========================================================================================
## 左栏里**正在冷却的非大招牌**减冷却：优先副武器栏，其次武器栏的 `当前冷却`。
## 返回被减的那张牌名（没有 = 空串）。
static func _减一条冷却(t: Dictionary, 值: float) -> String:
	for e in J.or_(t.get("副武器栏"), []):
		if e is Dictionary and float((e as Dictionary).get("cd", 0.0)) > 0.0:
			(e as Dictionary)["cd"] = maxf(0.0, float((e as Dictionary).get("cd")) - 值)
			return "【%s】" % str(J.g((e as Dictionary).get("卡"), "名"))
	for c in J.or_(t.get("武器栏"), []):
		if c is Dictionary and float((c as Dictionary).get("当前冷却", 0.0)) > 0.0:
			(c as Dictionary)["当前冷却"] = maxf(0.0, float((c as Dictionary).get("当前冷却")) - 值)
			return "【%s】" % str((c as Dictionary).get("名", ""))
	return ""

## 大招槽里的**武器型大招**（`武器牌 == true`，状态入场大招自动被排除）冷却 −2。
static func _减大招冷却(t: Dictionary, 值: float) -> String:
	for 槽 in J.or_(t.get("大招槽"), []):
		if not (槽 is Dictionary):
			continue
		var 卡: Dictionary = (槽 as Dictionary).get("卡") if (槽 as Dictionary).get("卡") is Dictionary else {}
		if 卡.is_empty() or not J.truthy(卡.get("武器牌")):
			continue
		if float((槽 as Dictionary).get("cd", 0.0)) <= 0.0:
			continue
		(槽 as Dictionary)["cd"] = maxf(0.0, float((槽 as Dictionary).get("cd")) - 值)
		return str(卡.get("名", ""))
	return ""

static func _另一台友军(运行: Dictionary, 施: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 们 := Units.livingOf("ally", ctx).filter(func(u): return not is_same(u, 施))
	if 们.is_empty():
		return null
	J.sort(们, func(a, b):
		var d := 血比(a) - 血比(b)
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	return 们[0]

# ==========================================================================================
# 五、战斗管线钩子
# ==========================================================================================
## 【常规整备】的过量整备：本回合下一张武器牌每段命中 +10（这一次攻击结算完就清）。
static func 命中修正(att: Variant, _def: Variant, _w: Variant, ctx: Variant) -> float:
	if not (ctx is Dictionary) or not (att is Dictionary):
		return 0.0
	if not J.same((att as Dictionary).get("过量整备命中"), (ctx as Dictionary).get("turn", 0.0)):
		return 0.0
	return 10.0

## 一次攻击结算完 → 吃掉【常规整备】的命中标记（只吃一次）。
static func 武器攻击后(ctx: Variant, att: Variant, _def: Variant, _landed: float, _w: Variant) -> void:
	if not (ctx is Dictionary) or not (att is Dictionary):
		return
	if (att as Dictionary).has("过量整备命中"):
		(att as Dictionary).erase("过量整备命中")

## 【紧急损管】：致命伤害的瞬间锁 1 血 → 再回 20% → 打出者战意 +15。
static func 致命保留_后(ctx: Variant, _att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return
	if not J.same((def as Dictionary).get("紧急损管中"), (ctx as Dictionary).get("turn", 0.0)):
		return
	if float((def as Dictionary).get("hp", 0.0)) > 0.0:
		return
	(def as Dictionary)["hp"] = 1.0
	var 上 := float((def as Dictionary).get("maxHp", 0.0))
	var 弹 := J.round(上 * 0.20)
	(def as Dictionary)["hp"] = minf(上, float((def as Dictionary).get("hp")) + 弹)
	var 施键 := str((def as Dictionary).get("紧急损管施放者", ""))
	var 施 = Btl.找单位(ctx, 施键, "ally")
	if 施 is Dictionary and float((施 as Dictionary).get("hp", 0.0)) > 0.0:
		Btl.加战意(施, 15.0, ctx, "紧急损管")
	(def as Dictionary).erase("紧急损管中")
	(def as Dictionary).erase("紧急损管施放者")
	Btl.pushLog(ctx, "〔紧急损管〕%s 受到致命伤害 → **锁 1 血后又弹回 %s HP**（现 %s）%s" % [
		str((def as Dictionary).get("name", "")), J.s(弹), J.s((def as Dictionary).get("hp")),
		"，%s 战意 +15" % str((施 as Dictionary).get("name", "")) if 施 is Dictionary else ""],
		J.merged({"类型": "紧急损管", "目标": (def as Dictionary).get("key"), "回复": 弹,
			"施放者": 施键, "保留": 1.0}, Btl.谁(def)))

## 规则钩子转发【我方阶段初_后】：清「本回合」的维修状态（`紧急损管` 只活到下个我方阶段前）。
static func 我方阶段初_后(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.concat(J.or_((ctx as Dictionary).get("allies"), []), J.or_((ctx as Dictionary).get("enemies"), [])):
		if not (u is Dictionary):
			continue
		for k in 阶段初清键:
			(u as Dictionary).erase(k)

# ==========================================================================================
# 六、三层反馈的「预告」读法（纯读）
# ==========================================================================================
## 这台机体身上现在挂着哪些维修状态（一行一条）。
static func 状态行(u: Variant, ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 名 := str((u as Dictionary).get("name", ""))
	var t = (ctx as Dictionary).get("turn") if ctx is Dictionary else (u as Dictionary).get("turn")
	if J.same((u as Dictionary).get("过量整备命中"), t):
		出.append("%s〔过量整备〕下一张武器牌每段命中 +10" % 名)
	if J.same((u as Dictionary).get("紧急损管中"), t):
		出.append("%s〔紧急损管〕受到致命伤害时锁 1 血并弹回 20%% HP" % 名)
	return 出

## 悬停 / 拖动时的面板预览标签：目标已满血或这次一定溢出 → 直接亮〔过量整备〕。
static func 预览标签(ctx: Variant, 目标: Variant, 比: float) -> String:
	if not (目标 is Dictionary):
		return ""
	var 上 := float((目标 as Dictionary).get("maxHp", 0.0))
	var 前 := float((目标 as Dictionary).get("hp", 0.0))
	if 前 >= 上 or 前 + J.round(上 * 比) > 上:
		return "〔过量整备生效〕"
	return ""
