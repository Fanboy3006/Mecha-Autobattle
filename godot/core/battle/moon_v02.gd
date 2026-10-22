## 职责：月球王国 v0.2.1 的**唯一注册点** —— 开关与成员识别、装填入口与全部规则钩子的转发。
## 约定：`选项.月球v02` 没显式写 false 且有存活的月球王国成员就接手；本文件只判「归不归我管」，规则细节在 `MoonPhase` / `MoonDeck` / `MoonUnits` / `MoonFaction`。
class_name MoonV02
extends RefCounted

const 势力 := "月球王国"

# ---- 一、开关与成员识别（纯读）----
static func 开(ctx: Variant) -> bool:
	if not 选项开(ctx):
		return false
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if MoonPhase.活着(u) and MoonPhase.是月球王国(u):
			return true
	return false

## 默认开；只有 `选项.月球v02 == false` 才关（旧版 `FacMoon` 的让位也读这一条）。
static func 选项开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	return not (选 is Dictionary and (选 as Dictionary).get("月球v02") == false)

static func _管(ctx: Variant, u: Variant) -> bool:
	return MoonPhase.是月球王国(u) and 开(ctx)

# ---- 二、装填 ----
static func 开局初始化(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	MoonDeck.初始化(ctx)
	MoonPhase.初始化(ctx)

static func 装填单位(u: Variant, 等级: int, ctx: Variant) -> Array:
	if not _管(ctx, u) or not MoonUnits.成员键.has(MoonPhase.键(u)):
		return []
	return MoonUnits.装填单位(u, 等级)

## 拆分四区之后：站位层与大招亮起条件的第一次刷新。
static func 装填大招槽(ctx: Dictionary, u: Variant) -> void:
	if _管(ctx, u):
		MoonUnits.装填后(ctx, u)

static func 公有扩展牌(ctx: Variant) -> Array:
	return MoonDeck.势力牌们() if 开(ctx) else []

static func 公有牌打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not MoonDeck.是月球牌(卡) or not 开(ctx):
		return {"终局": false}
	return MoonDeck.打出(ctx, u, 卡, target_id)

static func 执行算子(名: String, 运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	if 名 != "moon" or not 开(运行.get("ctx")):
		return []
	var 回 := MoonDeck.执行算子(运行, 表)
	if not 回.is_empty():
		return 回
	return MoonUnits.执行算子(运行, 表)

# ---- 三、数值与受击钩子 ----
static func 命中修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	if not _管(ctx, att):
		return 0.0
	return MoonUnits.命中修正(ctx, att, def, w)

static func 攻方伤害倍率(ctx: Variant, att: Variant, _def: Variant, w: Variant) -> float:
	if not _管(ctx, att):
		return 1.0
	return MoonUnits.攻方伤害倍率(ctx, att, w)

static func 受方伤害倍率(ctx: Variant, _att: Variant, def: Variant, _w: Variant) -> float:
	if not _管(ctx, def):
		return 1.0
	return MoonPhase.受方伤害倍率(ctx, def)

static func 受击前(ctx: Dictionary, att: Variant, def: Variant) -> void:
	if _管(ctx, def):
		MoonPhase.受击前(ctx, att, def)

static func 受击后(ctx: Dictionary, def: Variant, _att: Variant, _rec: Variant, _w: Variant) -> void:
	if not _管(ctx, def):
		return
	MoonPhase.受击后(def)
	MoonUnits.受击后(def)

static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if _管(ctx, att):
		MoonUnits.武器攻击后(ctx, att, def, landed, w)

# ---- 四、阶段 / 换位 / 出牌 ----
static func 我方阶段初_后(ctx: Variant) -> void:
	if not 开(ctx):
		return
	MoonPhase.阶段初(ctx)
	MoonUnits.阶段初(ctx)

## 【换位后】：随侍重算（月相不变）+ 主武器站位层。
static func 换位后(ctx: Dictionary, side: String, _移动的: Array, _opts: Variant) -> void:
	if side != "ally" or not 开(ctx):
		return
	MoonPhase.换位后刷新(ctx)
	for u in Units.livingOf("ally", ctx):
		MoonUnits.刷新站位武器栏(ctx, u)

static func 卡不可打原因(ctx: Dictionary, u: Dictionary, 卡: Dictionary, _区: String) -> Dictionary:
	if not MoonDeck.是月球牌(卡) or not 开(ctx):
		return {"终局": false}
	return MoonDeck.卡不可打原因(ctx, u, 卡)

static func 副武器门槛(ctx: Dictionary, u: Dictionary, 条目: Dictionary) -> Dictionary:
	if not _管(ctx, u):
		return {"终局": false}
	return MoonUnits.副武器门槛(ctx, u, 条目)

static func 副武器特殊打出(ctx: Dictionary, u: Variant, 条目: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not _管(ctx, u):
		return {"终局": false}
	return MoonUnits.副武器特殊打出(ctx, u, 条目, 卡, target_id)

static func 条件值(ctx: Variant, u: Variant, t: String, 条: Variant) -> Dictionary:
	if not t.begins_with("月球") or not 开(ctx):
		return {"终局": false}
	return MoonUnits.条件值(ctx, u, t, 条)

static func 牌打出后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> void:
	if _管(ctx, u):
		MoonUnits.牌打出后(ctx, u, 卡, 区)

## 【AI 自动出牌跳过】：月球王国成员由本模块按新武器栏补打（旧版机体武器不再参与）。
static func AI自动出牌跳过(ctx: Dictionary, u: Variant) -> Dictionary:
	if not _管(ctx, u):
		return {"终局": false}
	MoonUnits.AI补打(ctx, u)
	return {"终局": true}

# ---- 五、表现层读接口 ----
static func 月相(ctx: Variant) -> String:
	return MoonPhase.月相(ctx)

static func 随侍们(ctx: Variant) -> Array:
	return MoonPhase.随侍们(ctx)

## 机体卡上的紧凑标签：〔盈月〕/〔随侍〕/〔月面偏导〕/〔拘束〕。
static func 标签行(u: Variant, ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary) or not 开(ctx):
		return 出
	if MoonPhase.是王女(u) and MoonPhase.月相(ctx) != "":
		出.append("〔%s〕" % MoonPhase.月相(ctx))
	if MoonPhase.是随侍(ctx, u):
		出.append("〔随侍〕")
	if J.truthy((u as Dictionary).get("月面偏导")):
		出.append("〔月面偏导〕")
	if MoonPhase.有拘束(u):
		出.append("〔拘束〕")
	return 出
