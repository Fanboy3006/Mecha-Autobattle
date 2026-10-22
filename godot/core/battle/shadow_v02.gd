## 职责：影世界 v0.2.1 的唯一注册点 —— 开关、成员识别、共用小工具与规则钩子转发（牌库 `ShadowDeck` / 四人 `ShadowUnits` / 大招 `ShadowUlts`）。
## 约定：内核只经 `RuleHooks` 找本文件；`选项.影世界v02 == false` 或没有活着的 B1–B4 时每个钩子都返回中性值。
class_name ShadowV02
extends RefCounted

const 势力 := "影世界"
const 成员键: Array = ["B1", "B2", "B3", "B4"]
const 选项键 := "影世界v02"
const 算子名 := "shadow"

# ---- 一、开关与成员识别（纯读）----
## 拉米亚（副势力影世界）单独在场不开势力；开了之后她能打影世界牌。
static func 开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	if 选 is Dictionary and (选 as Dictionary).get(选项键) == false:
		return false
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 and 是主成员(u):
			return true
	return false

static func 是主成员(u: Variant) -> bool:
	if not (u is Dictionary) or not 成员键.has(键(u)):
		return false
	var 们 := Units.势力们(u)
	return not 们.is_empty() and str(们[0]) == 势力

## 含副势力影世界的拉米亚。
static func 是影世界成员(u: Variant) -> bool:
	return u is Dictionary and J.inc(Units.势力们(u), 势力)

static func 键(u: Variant) -> String:
	return Units._键Of(u)

static func 活(u: Variant) -> bool:
	return u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0

# ---- 二、共用小工具 ----
## 影世界牌的换位：一律带 `isShadowCard`，由 `BattleSwap` 记【移位】、挂〔错位〕、结算〔深渊之门〕。
static func 换位(ctx: Dictionary, side: String, a: Variant, b: Variant, 来源: String) -> int:
	if a == null or b == null:
		return 0
	return BattleSwap.换位(ctx, side, int(a), int(b), {"isShadowCard": true, "来源": 来源})

static func 对位格(u: Dictionary) -> int:
	return Fm.另一排同位(float(u.get("slot", 0.0)))

## 无视防御的定额伤害（不掷随机数）；打死了照常记击破。
static func 真伤(ctx: Dictionary, 出手者: Variant, e: Dictionary, 值: float) -> float:
	if not 活(e):
		return 0.0
	var 实 := CardEffects._固定伤害(ctx, e, 值)
	if float(e.get("hp", 0.0)) <= 0.0:
		if 出手者 is Dictionary:
			Fac.势力击破(ctx, 出手者, e)
		Btl.记击破(ctx, 出手者 if 出手者 is Dictionary else null, e)
	return 实

static func 施放者(ctx: Dictionary) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前出牌者"), "ally")
	return t if 活(t) else null

## 指定的影世界成员，否则打出者。
static func 友目标(ctx: Dictionary) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if 活(t) and 是影世界成员(t):
		return t
	return 施放者(ctx)

static func 敌目标(ctx: Dictionary, 默认: String = "最高血") -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
	if 活(t):
		return t
	return 按血挑(Units.livingOf("enemy", ctx), 默认 == "最高血")

static func 按血挑(们: Array, 最高: bool) -> Variant:
	var 选: Variant = null
	for u in 们:
		if not 活(u):
			continue
		if 选 == null or (最高 and float(u.hp) > float(选.hp)) or (not 最高 and float(u.hp) < float(选.hp)):
			选 = u
	return 选

static func 名(u: Variant) -> String:
	return str((u as Dictionary).get("name", "（无）")) if u is Dictionary else "（无）"

static func 记(ctx: Dictionary, 牌名: String, u: Variant, 文: String) -> void:
	var 谁 := {"类型": 势力, "牌名": 牌名}
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % 名(u)) if u is Dictionary else "", 文], 谁)

# ---- 三、入口：装填与公有牌 ----
static func 开局初始化(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	ShadowDeck.初始化(ctx)

static func 装填单位(u: Variant, 等级: int, ctx: Variant) -> Array:
	if not 开(ctx) or not 是主成员(u):
		return []
	return ShadowUnits.装填单位(u, 等级)

## 大招槽亮起条件（`实时门槛`）开局先算一次（第 1 回合没有阶段初检查）。
static func 装填大招槽(ctx: Dictionary, u: Variant) -> void:
	if not 开(ctx) or not 是主成员(u):
		return
	ShadowUnits.刷新本人门槛(ctx, u)

static func 公有扩展牌(ctx: Variant) -> Array:
	if not 开(ctx):
		return []
	return ShadowDeck.势力牌们()

static func 公有牌打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not ShadowDeck.是影世界公有牌(卡):
		return {"终局": false}
	return ShadowDeck.打出(ctx, u, 卡, target_id)

static func 执行算子(名_: String, 运行: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	if 名_ != 算子名 or not (运行.get("ctx") is Dictionary):
		return []
	var 回 := ShadowDeck.执行算子(运行, 表, 目标们)
	if 回.is_empty():
		回 = ShadowUnits.执行算子(运行, 表)
	if 回.is_empty():
		回 = ShadowUlts.执行算子(运行, 表)
	return 回

# ---- 四、规则钩子（数值）----
static func 闪避加成(def: Variant, ctx: Variant) -> float:
	if not 开(ctx):
		return 0.0
	return ShadowUnits.闪避加成(def, ctx)

static func 命中修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	if not 开(ctx):
		return 0.0
	return ShadowUnits.命中修正(att, def, w, ctx)

static func 暴击修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	if not 开(ctx):
		return 0.0
	return ShadowUnits.暴击修正(att, def, w)

static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	if not 开(ctx):
		return 1.0
	return ShadowUnits.攻方伤害倍率(ctx, att, def, w)

static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if not 开(ctx):
		return
	ShadowUnits.武器攻击后(ctx, att, def, landed, w)

# ---- 五、规则钩子（阶段 / 换位 / 出牌）----
## 撤〔错位〕换装、清「到下个我方阶段前」的状态与〔深渊之门〕。
static func 我方阶段初_后(ctx: Variant) -> void:
	if not 开(ctx):
		return
	ShadowUnits.阶段初(ctx)
	(ctx as Dictionary).erase("abyssGateActive")

static func 换位后(ctx: Dictionary, side: String, 移动的: Array, opts: Dictionary) -> void:
	if not 开(ctx) or not J.truthy(opts.get("isShadowCard")):
		return
	ShadowUnits.换位后(ctx, side, 移动的)
	DeckFlow.检查公有待入库(ctx)

static func 卡不可打原因(ctx: Dictionary, u: Dictionary, 卡: Dictionary, _区: String) -> Dictionary:
	if not ShadowDeck.是影世界公有牌(卡):
		return {"终局": false}
	return ShadowDeck.不可打原因(ctx, u, 卡)

static func 副武器门槛(ctx: Dictionary, u: Dictionary, 条目: Dictionary) -> Dictionary:
	var 卡: Dictionary = 条目.get("卡") if 条目.get("卡") is Dictionary else {}
	if not ShadowUnits.是影世界动作牌(卡):
		return {"终局": false}
	var 因 := ShadowUnits.副武器门槛(ctx, u, 卡)
	return {"终局": 因 != "", "原因": 因}

static func 副武器特殊打出(ctx: Dictionary, u: Variant, 条目: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not (u is Dictionary) or not ShadowUnits.是影世界动作牌(卡):
		return {"终局": false}
	return {"终局": true, "结果": ShadowUnits.打出副武器(ctx, u, 条目, 卡, target_id)}

## 【AI 自动出牌跳过】：影世界四人由本模块按新武器栏补打（旧版机体武器不再参与）。
static func AI自动出牌跳过(ctx: Dictionary, u: Variant) -> Dictionary:
	if not 开(ctx) or not 是主成员(u) or not 活(u):
		return {"终局": false}
	ShadowUnits.AI补打(ctx, u)
	return {"终局": true}

static func 条件值(ctx: Variant, _u: Variant, t: String, 条: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {"终局": false}
	var 阈 := float(J.num0((条 as Dictionary).get("阈值"))) if 条 is Dictionary else 0.0
	match t:
		"本回合移位至少":
			return {"终局": true, "值": J.num0((ctx as Dictionary).get("turnShiftCount")) >= 阈}
		"本场移位至少":
			return {"终局": true, "值": J.num0((ctx as Dictionary).get("battleShiftCount")) >= 阈}
		"本场影种至少":
			return {"终局": true, "值": J.num0((ctx as Dictionary).get("本场影种")) >= 阈}
		"本场打出过影世界大招":
			return {"终局": true, "值": J.truthy((ctx as Dictionary).get("本场影世界大招"))}
	return {"终局": false}

static func 牌打出后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> void:
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary):
		return
	ShadowUnits.牌打出后(ctx, u, 卡, 区)

# ---- 六、表现层读接口 ----
static func 状态行(ctx: Variant) -> String:
	if not 开(ctx):
		return ""
	var 计 := SubDeck.各级张数((ctx as Dictionary).get("影门牌库"), ShadowDeck.等级键)
	return "〔本回合移位：%d ｜ 本场移位：%d〕影门牌库：一级 %d · 二级 %d · 三级 %d" % [
		int(J.num0((ctx as Dictionary).get("turnShiftCount"))), int(J.num0((ctx as Dictionary).get("battleShiftCount"))),
		int(计["一级"]), int(计["二级"]), int(计["三级"])]

static func 标签行(u: Variant) -> Array:
	var 出: Array = []
	if BattleSwap.已错位(u):
		出.append("〔错位〕")
	var 层 := int(J.num0((u as Dictionary).get("影种层数"))) if u is Dictionary else 0
	if 层 > 0:
		出.append("〔影种×%d〕" % 层)
	return 出
