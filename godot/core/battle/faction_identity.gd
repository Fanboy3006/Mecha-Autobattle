## 职责：IT-4「势力手感 v0.1」的**唯一注册点**（作者 10-21 试玩方向）——
##   · ATX【王牌】：响介 = 玻璃大炮（开局削装甲 / HP、给闪避，攻击 ×1.4）；
##     【押注王牌】本回合每有一名其他 ATX 成员完成一次武器攻击，响介「押注」+1 层（上限 3），每层伤害 +20%。
##     → 出手顺序有讲究：队友先打、再让响介收割。
##   · 秘银【Uruz 待机】：每次【连携】成功触发，宗介战意 +8（λ 门槛 60，早期靠连携攒）；
##     λ 开启中宗介攻击 ×1.3（「λ 一开，爆杀全场」）。
## 约定：只判「归不归我管」+ 读写自己的 ctx 键；开关 `选项.势力手感v01 == false` 整套关掉（默认开）。
## 规则正文：`协作/迭代/IT-4-势力手感-v0.1.md`。
class_name FactionIdentity
extends RefCounted

const 选项键 := "势力手感v01"
const 响介键 := "A1"
const 宗介键 := "U7"

# ---- 数值（改这里；正文表格同步）----
const 响介装甲倍 := 0.4
const 响介HP倍 := 0.75
const 响介闪避加 := 15.0
const 响介火力倍 := 1.4
const 押注每层 := 0.2
const 押注上限 := 3
const 连携充能 := 8.0
const λ火力倍 := 1.3

static func 开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	return not (选 is Dictionary and (选 as Dictionary).get(选项键) == false)

static func _键(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var t := str((u as Dictionary).get("tplKey", ""))
	return t if not t.is_empty() else str((u as Dictionary).get("key", ""))

static func _我方(u: Variant) -> bool:
	return u is Dictionary and str((u as Dictionary).get("side", "ally")) == "ally"

static func 是响介(u: Variant) -> bool:
	return _我方(u) and _键(u) == 响介键

static func 是宗介(u: Variant) -> bool:
	return _我方(u) and _键(u) == 宗介键

static func _活着(u: Variant) -> bool:
	return u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0

static func _找我方(ctx: Dictionary, 判: Callable) -> Variant:
	for u in J.or_(ctx.get("allies"), []):
		if 判.call(u) and _活着(u):
			return u
	return null

# ---- 一、开局：响介改玻璃大炮 ----
static func 开局初始化(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	for u in J.or_(ctx.get("allies"), []):
		if not 是响介(u):
			continue
		var 比 := float(u.hp) / maxf(1.0, float(u.maxHp))
		u["armor"] = J.round(float(u.armor) * 响介装甲倍)
		u["maxHp"] = J.round(float(u.maxHp) * 响介HP倍)
		u["hp"] = J.round(float(u.maxHp) * 比)
		u["eva"] = float(u.eva) + 响介闪避加
		Btl.pushLog(ctx, "〔王牌〕%s：玻璃大炮 —— 装甲 ×%s、HP ×%s、闪避 +%d，攻击 ×%s" % [
			u.name, J.s(响介装甲倍), J.s(响介HP倍), int(响介闪避加), J.s(响介火力倍)],
			J.merged({"类型": "王牌"}, Btl.谁(u)))

# ---- 二、ATX【押注王牌】----
static func 押注层数(ctx: Dictionary) -> int:
	var 记: Variant = ctx.get("王牌押注")
	if not (记 is Dictionary) or int((记 as Dictionary).get("回合", -1)) != int(ctx.get("turn", 1)):
		return 0
	return int((记 as Dictionary).get("层", 0))

static func 武器攻击后(ctx: Dictionary, att: Variant, _def: Variant, _landed: Variant, _w: Variant) -> void:
	if not 开(ctx) or not _我方(att) or 是响介(att) or not FacAtx._是ATX(att):
		return
	var 响 = _找我方(ctx, func(u): return 是响介(u))
	if 响 == null:
		return
	var 层 := 押注层数(ctx)
	if 层 >= 押注上限:
		return
	ctx["王牌押注"] = {"回合": int(ctx.get("turn", 1)), "层": 层 + 1}
	Btl.pushLog(ctx, "〔押注王牌〕%s 出手 → 押在 %s 身上（%d / %d 层，响介本回合伤害 +%d%%）" % [
		str(att.get("name", "")), str(响.get("name", "")), 层 + 1, 押注上限, int(押注每层 * 100.0 * (层 + 1))],
		J.merged({"类型": "押注王牌", "层": float(层 + 1)}, Btl.谁(att)))

static func 攻方伤害倍率(ctx: Variant, att: Variant, _def: Variant, _w: Variant) -> float:
	if not 开(ctx):
		return 1.0
	if 是响介(att):
		return 响介火力倍 * (1.0 + 押注每层 * float(押注层数(ctx)))
	if 是宗介(att) and DeckFlow.λ开启(att):
		return λ火力倍
	return 1.0

# ---- 三、秘银【Uruz 待机】：连携给宗介充战意（`DeckFlow.触发连携` 触发成功后调）----
static func 连携触发后(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	var 宗 = _找我方(ctx, func(u): return 是宗介(u))
	if 宗 == null:
		return
	Btl.加战意(宗, 连携充能, ctx, "Uruz 待机")
	Btl.pushLog(ctx, "〔Uruz 待机〕连携成功 → %s 战意 +%d（%d；λ 门槛 60）" % [
		str(宗.get("name", "")), int(连携充能), int(Btl.战意(宗))],
		J.merged({"类型": "连携充能", "战意": Btl.战意(宗)}, Btl.谁(宗)))
