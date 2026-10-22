## 职责：殖民卫星军的觉醒状态机（SEED / ZERO / 隐身）与 QTE 接口 —— 只读写单位字典上的状态，不认任何牌表。
## 约定：纯逻辑；「觉醒中」写在 `u.觉醒中` / `u.觉醒类型`，属性「觉醒值」是另一回事，牌面一律写「觉醒中」。
class_name ColonialAwaken
extends RefCounted

const 势力 := "殖民卫星军"
const SEED := "SEED"
const ZERO := "ZERO"
const 隐身 := "隐身"
const 三档: Array = ["miss", "good", "perfect"]
## 觉醒类型 → 结束后的入场牌冷却（SEED 本场不再关闭，没有冷却）。
const 结束冷却 := {ZERO: 3.0, 隐身: 2.0}
## QTE 标准三档（见 协作/设计/殖民卫星军势力卡牌设计 v0.1.md §3.2）。
const 加成表 := {
	"miss": {"命中": 0.0, "倍率": 1.0, "闪避": 0.0},
	"good": {"命中": 10.0, "倍率": 1.1, "闪避": 0.0},
	"perfect": {"命中": 20.0, "倍率": 1.25, "闪避": 20.0},
}
## ZERO 的暴伤倍率（平时 ×2，ZERO 中 ×2.5 → 补 0.5 的 `critX` 增益）。
const ZERO暴伤补 := 0.5
const ZERO负担 := 0.10
const ZERO负担加号 := 0.07
const ZERO退醒线 := 30.0

static func 键(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var k := str((u as Dictionary).get("key", ""))
	if k != "":
		return k
	return str((u as Dictionary).get("tplKey", ""))

static func 是殖民卫星军(u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if J.inc(Units.势力们(u), 势力):
		return true
	return J.inc(ColonialUnits.成员键, 键(u))

static func 觉醒中(u: Variant) -> bool:
	return u is Dictionary and J.truthy((u as Dictionary).get("觉醒中"))

static func 类型Of(u: Variant) -> String:
	if not 觉醒中(u):
		return ""
	return str((u as Dictionary).get("觉醒类型", ""))

static func 是类型(u: Variant, 类型: String) -> bool:
	return 类型Of(u) == 类型

static func 是SEED中(u: Variant) -> bool:
	return 是类型(u, SEED)

static func 是ZERO中(u: Variant) -> bool:
	return 是类型(u, ZERO)

static func 是隐身中(u: Variant) -> bool:
	return 是类型(u, 隐身)

static func 血比(u: Variant) -> float:
	if not (u is Dictionary):
		return 0.0
	var 上 := float((u as Dictionary).get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float((u as Dictionary).get("hp", 0.0)) / 上

# ---- 一、状态开启 / 结束 ----
## 进入觉醒。`来源` 只进战报（入场牌名）。
static func 开启(ctx: Dictionary, u: Dictionary, 类型: String, 来源: String = "") -> void:
	if not (u is Dictionary) or 类型 == "":
		return
	u["觉醒中"] = true
	u["觉醒类型"] = 类型
	u["本场已开" + 类型] = true
	if 类型 == ZERO:
		挂ZERO暴伤(u)
	if ctx != null:
		ctx["本场有人觉醒过"] = true
		Btl.pushLog(ctx, "〔觉醒〕%s 进入【觉醒中·%s】%s" % [str(u.get("name", "")), 类型,
			("（%s）" % 来源) if 来源 != "" else ""],
			J.merged({"类型": "觉醒", "觉醒类型": 类型}, Btl.谁(u)))

static func 挂ZERO暴伤(u: Dictionary) -> void:
	Btl.换同源增益(u, "ZERO系统", {"critX": ZERO暴伤补, "剩余": 9999.0})

static func 摘ZERO暴伤(u: Dictionary) -> void:
	u["buffs"] = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != "ZERO系统")

## 结束觉醒：三种类型共用；入场牌按 `结束冷却` 进冷却。
static func 结束(ctx: Dictionary, u: Dictionary, 原因: String, 冷却: float = -1.0) -> void:
	if not (u is Dictionary):
		return
	var 类型 := 类型Of(u)
	u["觉醒中"] = false
	u["觉醒类型"] = ""
	u.erase("QTE闪避加")
	摘ZERO暴伤(u)
	var 槽 := 入场槽(u, 类型)
	var 转 := 冷却 if 冷却 >= 0.0 else float(结束冷却.get(类型, 0.0))
	if not 槽.is_empty() and 转 > 0.0:
		槽["cd"] = 转
		槽["cd_max"] = maxf(float(槽.get("cd_max", 0.0)), 转)
	if ctx != null:
		Btl.pushLog(ctx, "〔觉醒结束〕%s 结束【觉醒中·%s】%s%s" % [str(u.get("name", "")), 类型,
			("（%s）" % 原因) if 原因 != "" else "",
			("；入场牌冷却 %d 回合" % int(转)) if 转 > 0.0 else ""],
			J.merged({"类型": "觉醒结束", "觉醒类型": 类型, "冷却": 转}, Btl.谁(u)))

## 希罗【系统拒绝】：ZERO 中任何时刻 `HP ≤ 30%` 当场退醒（扣血后 / 受击后 / 自损后都要调）。
static func 检查系统拒绝(ctx: Dictionary, u: Dictionary) -> bool:
	if not 是ZERO中(u) or float(u.get("hp", 0.0)) <= 0.0:
		return false
	if float(u.get("hp", 0.0)) * 100.0 > float(u.get("maxHp", 0.0)) * ZERO退醒线:
		return false
	结束(ctx, u, "HP 降至 30% 以下，触发系统拒绝")
	return true

## 希罗【精神负担】：每个我方阶段开始（回合初战意之后）扣最大 HP 的 10%（`+` 版 7%），最多扣到 1。
static func 精神负担(ctx: Dictionary, u: Dictionary, 加号: bool) -> void:
	if J.truthy(u.get("下回合免精神负担")):
		u.erase("下回合免精神负担")
		Btl.pushLog(ctx, "〔ZERO 系统〕%s 这一回合免去精神负担" % str(u.get("name", "")),
			J.merged({"类型": "ZERO免负担"}, Btl.谁(u)))
		return
	if float(u.get("hp", 0.0)) <= 1.0:
		return
	var 比 := ZERO负担加号 if 加号 else ZERO负担
	var 扣 := maxf(1.0, J.round(float(u.get("maxHp", 0.0)) * 比))
	var 后 := maxf(1.0, float(u.get("hp", 0.0)) - 扣)
	u["hp"] = 后
	Btl.pushLog(ctx, "〔ZERO 系统〕%s 精神负担 −%s HP（剩 %s）" % [str(u.get("name", "")), J.s(扣), J.s(后)],
		J.merged({"类型": "精神负担", "扣血": 扣}, Btl.谁(u)))
	检查系统拒绝(ctx, u)

# ---- 二、入场牌与觉醒大招槽 ----
static func 入场槽(u: Variant, 类型: String) -> Dictionary:
	if not (u is Dictionary) or 类型 == "":
		return {}
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if not (槽 is Dictionary) or not ((槽 as Dictionary).get("卡") is Dictionary):
			continue
		var 卡: Dictionary = (槽 as Dictionary).卡
		if str(卡.get("觉醒", "")) == 类型:
			return 槽
	return {}

## 这台机体的大招槽里有哪些是「觉醒大招」（`武器牌 == true`）。
static func 觉醒大招槽们(u: Variant) -> Array:
	var 出: Array = []
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if 槽 is Dictionary and ((槽.get("卡") is Dictionary)) and J.truthy((槽.get("卡") as Dictionary).get("武器牌")):
			出.append(槽)
	return 出

## 入场牌能不能亮（空串 = 能打）。`无视战意` 来自【觉醒连锁】/【背水】，`强制` 来自【强制觉醒】。
static func 入场门原因(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> String:
	if 觉醒中(u):
		return "已经在觉醒中"
	var 类型 := str(卡.get("觉醒", ""))
	if 类型 == "":
		return "这张不是觉醒入场牌"
	var 强制 := J.truthy(u.get("本回合强制觉醒"))
	if 类型 == SEED and J.truthy(u.get("本场已开SEED")):
		return "本场已经开过 SEED"
	var 槽 := 入场槽(u, 类型)
	if not 强制 and not 槽.is_empty() and float(槽.get("cd", 0.0)) > 0.0:
		return "入场牌冷却中（还剩 %d 回合）" % int(槽.get("cd", 0.0))
	if 强制:
		return ""
	var 门: Dictionary = 卡.get("入场门") if 卡.get("入场门") is Dictionary else {}
	var 比 := 血比(u) * 100.0
	if 门.get("HP不高于") != null:
		var 险 := 比 <= float(门.get("HP不高于"))
		var 回合场 := float(门.get("或回合", 0.0))
		var 到回合 := 回合场 > 0.0 and float(ctx.get("turn", 1.0)) >= 回合场
		if not (险 or 到回合):
			return "HP 还没降到 %d%% 以下，也没到第 %d 回合" % [int(门.get("HP不高于")), int(回合场)]
	if 门.get("HP高于") != null and 比 <= float(门.get("HP高于")):
		return "HP 已不高于 %d%%，开不出这一张" % int(门.get("HP高于"))
	var 无视战意 := J.truthy(u.get("本回合无视觉醒战意门槛"))
	if not 无视战意 and Btl.战意(u) < float(门.get("战意", 0.0)):
		return "战意不够（要 %d，现在 %d）" % [int(门.get("战意", 0.0)), int(Btl.战意(u))]
	return ""

## 这一张觉醒牌的实际费用（强制觉醒 / 极限超频 → 0；【超频】只减觉醒大招）。
static func 实际费用(u: Variant, 卡: Variant) -> float:
	var 费 := Btl.战意费用(卡)
	if not (u is Dictionary) or not (卡 is Dictionary):
		return 费
	if J.truthy((u as Dictionary).get("本回合强制觉醒")) or J.truthy((u as Dictionary).get("本回合极限超频")):
		return 0.0
	var 降 := int(J.num0((u as Dictionary).get("本回合觉醒大招降费")))
	if 降 > 0 and J.truthy((卡 as Dictionary).get("武器牌")):
		费 = maxf(0.0, 费 - float(降))
	return 费

# ---- 三、QTE 接口 ----
## 取一次 QTE 结果（`miss` / `good` / `perfect`）。管线见旧单 §1.3 —— 以后 QTE 本体只替换这一个函数。
static func 取QTE结果(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 指定结果: String = "") -> String:
	if J.truthy(u.get("本回合极限超频")):
		return "perfect"
	var raw := ""
	if J.truthy(ctx.get("_ai自动出牌中")):
		raw = "good"
	elif 三档.has(指定结果):
		raw = 指定结果
	else:
		match str(J.or_(J.g(ctx.get("选项"), "QTE结果"), "manual")):
			"perfect": raw = "perfect"
			"good": raw = "good"
			"miss": raw = "miss"
			"random": raw = _掷档(ctx)
			_: raw = "good"
	if raw == "miss" and (是SEED中(u) or J.truthy(ctx.get("本回合全体QTE保底成功"))):
		raw = "good"
	Btl.pushLog(ctx, "〔QTE·%s〕%s【%s】QTE 判定：%s" % [_档名(raw), str(u.get("name", "")), str(卡.get("名", "")), _档文(raw)],
		J.merged({"类型": "QTE", "结果": raw, "卡牌": 卡.get("名")}, Btl.谁(u)))
	return raw

## 随机档（20% 失手 / 50% 成功 / 30% 完美）—— 只被「随机」模式调用。
static func _掷档(ctx: Dictionary) -> String:
	var rng = ctx.get("rng")
	if rng == null:
		return "good"
	var x := float(rng.next_float())
	if x < 0.2:
		return "miss"
	if x < 0.7:
		return "good"
	return "perfect"

static func _档名(结果: String) -> String:
	return {"miss": "失手", "good": "成功", "perfect": "完美"}.get(结果, "成功")

static func _档文(结果: String) -> String:
	var 加: Dictionary = 加成表.get(结果, 加成表["good"])
	if 结果 == "miss":
		return "失手（无加成）"
	return "%s（命中 +%d / 伤害 +%d%%%s）" % [_档名(结果), int(加["命中"]), int((float(加["倍率"]) - 1.0) * 100.0),
		(" / 闪避 +%d" % int(加["闪避"])) if float(加["闪避"]) > 0.0 else ""]

## 把这一发的 QTE 加成挂进 `ctx`（命中 / 伤害倍率在钩子里读它，攻击结束由 `清QTE` 收掉）。
static func 开QTE(ctx: Dictionary, u: Dictionary, 结果: String) -> void:
	var 加: Dictionary = 加成表.get(结果, 加成表["good"])
	ctx["_觉醒QTE"] = {"打出者": 键(u), "命中": float(加["命中"]), "倍率": float(加["倍率"])}
	if float(加["闪避"]) > 0.0:
		u["QTE闪避加"] = float(加["闪避"])

static func 清QTE(ctx: Dictionary) -> void:
	if ctx is Dictionary:
		ctx.erase("_觉醒QTE")

static func _本发QTE(ctx: Variant, att: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {}
	var q = (ctx as Dictionary).get("_觉醒QTE")
	if not (q is Dictionary):
		return {}
	return q if str((q as Dictionary).get("打出者", "")) == 键(att) else {}

# ---- 四、规则钩子的实现体（由 `ColonialV01` 转发） ----
## 【命中修正】：SEED +15 / ZERO +20、本发 QTE 命中加成、【零的预见】整次打空。
static func 命中修正(att: Variant, def: Variant, _w: Variant, ctx: Variant) -> float:
	var 修 := 0.0
	if 是SEED中(att):
		修 += 15.0
	elif 是ZERO中(att):
		修 += 20.0
	修 += float(_本发QTE(ctx, att).get("命中", 0.0))
	if ctx is Dictionary and J.truthy((ctx as Dictionary).get("_本次打空")):
		修 -= 1000.0
	return 修

## 【闪避加成】：SEED +15 / ZERO +20、QTE 完美的闪避 +20（到下个我方阶段前）。
static func 闪避加成(def: Variant, _ctx: Variant) -> float:
	var 修 := 0.0
	if 是SEED中(def):
		修 += 15.0
	elif 是ZERO中(def):
		修 += 20.0
	if def is Dictionary:
		修 += float(J.num0((def as Dictionary).get("QTE闪避加")))
	return 修

## 【攻方伤害倍率】：本发 QTE 的伤害加成（失手 1.0 / 成功 1.1 / 完美 1.25）。
static func 攻方伤害倍率(ctx: Variant, att: Variant, _def: Variant, _w: Variant) -> float:
	return float(_本发QTE(ctx, att).get("倍率", 1.0))

## 【受击前】：先结算「本回合下次受击必暴」与【零的预见】这两条一次性状态（每次攻击只走一次）。
static func 受击前(ctx: Dictionary, att: Variant, def: Variant) -> void:
	if not (def is Dictionary) or not (att is Dictionary):
		return
	if float((att as Dictionary).get("hp", 0.0)) <= 0.0:
		return
	if J.truthy((def as Dictionary).get("本回合下次受击必暴")):
		(def as Dictionary).erase("本回合下次受击必暴")
		ctx["_本次必暴"] = true
	if float(J.num0((def as Dictionary).get("零的预见层数"))) > 0.0:
		(def as Dictionary)["零的预见层数"] = 0.0
		ctx["_本次打空"] = true
		Btl.pushLog(ctx, "〔零的预见〕%s 看见这一次攻击 → 整次打空" % str((def as Dictionary).get("name", "")),
			J.merged({"类型": "零的预见"}, Btl.谁(def)))

## 【暴击修正】：「本回合下次受击必暴」→ 这一发必定暴击。
static func 暴击修正(_att: Variant, _def: Variant, _w: Variant, ctx: Variant) -> float:
	if ctx is Dictionary and J.truthy((ctx as Dictionary).get("_本次必暴")):
		return 1000.0
	return 0.0

## 【武器攻击后】：一次性状态收尾（每次攻击 × 每个目标都会来一次，收两次也安全）。
static func 武器攻击后(ctx: Dictionary, _att: Variant, _def: Variant, _landed: Variant, _w: Variant) -> void:
	ctx.erase("_本次必暴")
	ctx.erase("_本次打空")

## 【受方伤害倍率】：【正规军掩护】给被保护者 −30%（卡嘉莉 / 减伤在 `ColonialUnits`，由门面相乘）。
static func 受方伤害倍率(_ctx: Variant, _att: Variant, def: Variant, w: Variant) -> float:
	return ColonialDeck.受方伤害倍率(def, w)

## 【可选目标】：隐身中的迪奥在「还有其他非隐身队友存活」时不可被敌方单体选中。
static func 可选目标(ctx: Dictionary, _actor: Variant, target: Variant, w: Variant) -> Dictionary:
	if not (target is Dictionary) or not 是隐身中(target):
		return {"终局": false}
	if w is Dictionary and Reach.isAreaKind(Reach.rangeKindOf(w)):
		return {"终局": false}
	# 还有其他非隐身队友 → 不能选他；只剩隐身单位 → 允许选中（避免死锁）。
	return {"终局": true, "可选": not 还有非隐身队友(ctx, target)}

static func 还有非隐身队友(ctx: Dictionary, u: Dictionary) -> bool:
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and not is_same(a, u) and float((a as Dictionary).get("hp", 0.0)) > 0.0 \
			and not 是隐身中(a):
			return true
	return false

## 【AI 自动出牌跳过】：结束回合时 AI 不许替隐身中的迪奥打主武器（否则自动破隐）。
static func AI自动出牌跳过(_ctx: Dictionary, u: Variant) -> Dictionary:
	if 是隐身中(u):
		return {"终局": true}
	return {"终局": false}

## 【我方阶段初_后】：歌姬 / 潜伏蓄势 / ZERO 精神负担 / 一次性状态收尾。
static func 阶段初(ctx: Dictionary, 加号: bool = false) -> void:
	var 拉: Variant = _找成员(ctx, "S1")
	var 希: Variant = _找成员(ctx, "W1")
	var 迪: Variant = _找成员(ctx, "W2")
	# 歌姬：SEED 中，其他存活的殖民卫星军成员战意 +3
	if 拉 is Dictionary and 是SEED中(拉):
		for a in J.or_(ctx.get("allies"), []):
			if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and not is_same(a, 拉) and 是殖民卫星军(a):
				Btl.加战意(a, 3.0, ctx, "歌姬")
	# 潜伏蓄势：隐身中额外 +5
	if 迪 is Dictionary and 是隐身中(迪):
		Btl.加战意(迪, 5.0, ctx, "潜伏蓄势")
		Btl.pushLog(ctx, "〔潜伏蓄势〕%s 隐身中 → 战意额外 +5" % str(迪.get("name", "")),
			J.merged({"类型": "潜伏蓄势"}, Btl.谁(迪)))
	# 精神负担：ZERO 中每个我方阶段初扣最大 HP 的 10%（`+` 版 7%）
	if 希 is Dictionary and 是ZERO中(希):
		var 槽 := 入场槽(希, ZERO)
		精神负担(ctx, 希, not 槽.is_empty() and J.truthy(槽.get("plus")))
	# 一次性状态：本回合的降费 / 门槛豁免 / 极限超频
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		u.erase("本回合觉醒大招降费")
		u.erase("本回合无视觉醒战意门槛")
		u.erase("本回合强制觉醒")
		u.erase("本回合极限超频")
	# QTE 完美的闪避 +20「到下个我方阶段前」—— 到这里正好到期
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary:
			u.erase("QTE闪避加")

static func _找成员(ctx: Dictionary, 键名: String) -> Variant:
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and 键(a) == 键名:
			return a
	return null

# ---- 五、表现层读接口 ----
## 觉醒徽章文字（空串 = 没觉醒）。颜色由表现层按类型自己选。
static func 徽章文字(u: Variant) -> String:
	var 类型 := 类型Of(u)
	return "" if 类型 == "" else "〔觉醒中·%s〕" % 类型

static func 状态行(u: Variant) -> Array:
	var 出: Array = []
	var 类型 := 类型Of(u)
	if 类型 == "":
		return 出
	match 类型:
		SEED:
			出.append("SEED：命中 / 闪避 +15、QTE 失手视为成功、METEOR 与超级 DRAGOON 已解锁（本场不关）")
		ZERO:
			出.append("ZERO：命中 / 闪避 +20、暴伤 ×2.5、每回合扣最大 HP %d%%、HP ≤ %d%% 退醒"
				% [int(ZERO负担 * 100.0), int(ZERO退醒线)])
		隐身:
			出.append("隐身：敌方单体选不中、每回合战意额外 +5、打出武器牌即破隐")
	return 出
