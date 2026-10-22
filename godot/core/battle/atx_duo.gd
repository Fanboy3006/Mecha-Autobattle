## ★ A6b：塔斯克（A6 · 重装 · 吉甘斯库德）+ 雷欧娜（A7 · 指挥 · 齐格利昂）。
##
## 权威依据（数值逐字照抄，一个数都没改）：
##   · `协作/设计/塔斯克与雷欧娜卡牌设计 v0.1.md` §1（塔斯克）/ §2（雷欧娜）/ §4（升级字段）
##   · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §2.2（「次」与「段」）/ §4 的 A6b 行 / §5 R1·R4·R5
##
## 交付形状（每人 7 张 = 3 主武器 + 1 大招 + 3 精神，全部「初始」）：
##   · **主武器卡**（`卡类 = 主武器卡`，`武器` 字段带距离 / 段数 / 命中）→ 进 `u.武器栏`；
##   · **大招槽卡**（`卡类 = 大招槽卡`，`耗气 20 / 冷却 4`）→ 进 `u.大招槽`，两张都带【赌局】；
##   · **专属精神牌**（`卡类 = 专属精神牌`）→ 进 `u.专属牌库`。
##   单位模板（`单位模板()`）只给 3 把主武器 —— 大招在单机牌组里是**牌**（大招槽卡），不是常驻武器。
##
## 三条铁律：
##   · **R4**：两个**改目标**效果（【掩护】接管 /【我可是很耐打的！】优先选塔斯克）都挂在
##     `Ai.bestWeaponOn` / `Ai.enemyAction` / `Boss.单武器动作` 这**同一条链**上 ——
##     `Btl.算意图` 与敌方阶段实际出手走的是同一份代码，所以预告目标 == 实际挨打的目标。
##   · **R5**：一次攻击 = 一条记录（`Calc.resolveAttack` 的口径，本文件不逐段写日志）。
##
## 状态生存期：
##   · 「每个敌方阶段」= `敌方阶段初()`（`Btl.结束我方回合` 第一行调）：`引力墙待 = true`、`掩护剩余 = 2`；
##   · 「本场累计」= `v3计数.本场被攻击`（`DeckFlow.计数加`，与秘银 / A6a 的计数同一本账）；
##   · 「下一次攻击」= `命中惩罚待`（重力冲撞）/ `专注命中`（专注）—— 攻击结算完由 `攻击后消耗()` 清；
##   · 「到下个我方阶段前」= `Btl.换同源增益(..., {"剩余": 1.0})`（与铁壁 / 硬碰硬同一套过期机制）。
class_name AtxDuo
extends RefCounted

const 势力 := "ATX"
const 塔斯克 := "A6"
const 雷欧娜 := "A7"
## 本批「加入 ATX」的两个人（顺序 = 名册里出现的顺序）
const 加入键们: Array = ["A6", "A7"]
## 本批「移出 ATX」的两个人（库斯哈 A5 / 布鲁克林 A4）—— `RosterManager` 的名册据此过滤
const 移出键们: Array = ["A4", "A5"]

## 每个敌方阶段可以替队友接几次（设计稿 §1【掩护】）
const 掩护上限 := 2
## 【引力墙】每个敌方阶段第一次被攻击的减伤
const 引力墙减伤 := 0.30
## 【重力冲撞】命中后目标下一次攻击的每段命中惩罚
const 重力冲撞命中惩罚 := 15.0
## 【专注】下一张主武器牌每段命中加成
const 专注命中加成 := 20.0
## 【T-Link 感应】指定友军的下个我方阶段前闪避加成
const TLINK闪避加成 := 10.0
## 精神牌「塔斯克，退下」/「硬撑」的减伤
const 减伤30 := 0.30

# ---------------- 状态键 ----------------
const 引力墙待键 := "引力墙待"
const 掩护剩余键 := "掩护剩余"
const 命中惩罚待键 := "命中惩罚待"
const 专注键 := "专注命中"
const 耐打Turn键 := "耐打Turn"
const 本场被攻击键 := "本场被攻击"

# ==========================================================================================
# 一、单位模板（`DataFn.tplOf` 的兜底来源；`data/js` 一个字节都不改）
# ==========================================================================================
## 两人都是「大众脸」：数值取同档位姐妹机的同档（塔斯克 对应 布鲁克林 A4 重装 / 雷欧娜 对应 库斯哈 A5 指挥）。
## ★ 设计稿没给基础面板，只给了武器与职业 —— 面板按同职业同档位照抄，武器数值逐字照设计稿。
static func 模板(键: Variant) -> Variant:
	var k := str(键)
	for t in 单位模板():
		if str((t as Dictionary).get("mech", "")) == k:
			return t
	return null

static func 单位模板() -> Array:
	return [
		{
			"pilot": "塔斯克", "mech": 塔斯克, "short": 塔斯克, "mechName": "吉甘斯库德",
			"trait": "hotBlood",
			"tags": {"势力": 势力, "远近分类": "近战", "战斗分类": "重装"},
			"hp": 9000, "armor": 1500, "eva": 5, "mov": 5,
			"melee": 160, "shoot": 110, "defense": 110, "flying": false,
			"w": 1, "h": 1, "abilities": [],
			"weapons": [
				_武("回旋盾刃", "melee", "物理", 400, 5, 80, [1, 2], "格斗"),
				_武("肩部机炮", "direct", "物理", 200, 8, 75, [1, 3], "射击"),
				_武("重力冲撞", "melee", "物理", 1800, 1, 85, [1, 1], "格斗"),
			],
			"awaken": 100,
		},
		{
			"pilot": "雷欧娜", "mech": 雷欧娜, "short": 雷欧娜, "mechName": "齐格利昂",
			"trait": "cold",
			"tags": {"势力": 势力, "远近分类": "远程", "战斗分类": "指挥"},
			"hp": 6200, "armor": 900, "eva": 20, "mov": 5,
			"melee": 140, "shoot": 155, "defense": 85, "flying": false,
			"w": 1, "h": 1, "abilities": [],
			"weapons": [
				_武("T-Link 光束炮", "direct", "光束", 500, 3, 85, [2, 5], "射击"),
				_散布武("分裂飞弹", "indirect", "物理", 300, 4, 75, [2, 5], "射击"),
				_武("光束刃", "melee", "光束", 600, 2, 85, [1, 2], "格斗"),
			],
			"awaken": 100,
		},
	]

## 一把武器（照 `DataFn.wp` 的默认值补全 —— 与数据里 34 台机体同一份字段口径）。
static func _武(名: String, fire: String, 伤害类型: String, 威力: float, 段数: int, 命中: float,
	距离: Array, 属性: String) -> Dictionary:
	var w := {
		"name": 名, "fire": fire, "dmgType": 伤害类型, "power": 威力, "hit": 命中,
		"stat": 属性, "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"range": [float(距离[0]), float(距离[1])], "critMod": 0.0, "afterMove": true,
		"ignoreDef": false, "special": null, "desc": "", "v37": true,
	}
	if 段数 > 1:
		w["hits"] = float(段数)
		w["special"] = "multi"
	return w

static func _散布武(名: String, fire: String, 伤害类型: String, 威力: float, 段数: int, 命中: float,
	距离: Array, 属性: String) -> Dictionary:
	var w := _武(名, fire, 伤害类型, 威力, 段数, 命中, 距离, 属性)
	# ★ 每段独立掷一次 `ctx.rng` 换目标（A5b 的 `散布` 管线，`Calc.散布适用` 认这个键）
	w["散布"] = true
	return w

# ==========================================================================================
# 二、卡表（14 张 = 每人 7 张）
# ==========================================================================================
const ID_回旋盾刃 := "U_DUO_1"
const ID_肩部机炮 := "U_DUO_2"
const ID_重力冲撞 := "U_DUO_3"
const ID_千兆宽域爆破 := "U_DUO_4"
const ID_硬撑 := "U_DUO_5"
const ID_专注塔斯克 := "U_DUO_6"
const ID_耐打 := "U_DUO_7"
const ID_TLINK光束炮 := "U_DUO_8"
const ID_分裂飞弹 := "U_DUO_9"
const ID_光束刃 := "U_DUO_10"
const ID_TLINK突击 := "U_DUO_11"
const ID_冷静判断 := "U_DUO_12"
const ID_塔斯克退下 := "U_DUO_13"
const ID_专注雷欧娜 := "U_DUO_14"

const _整数路径们 := ["实时门槛.阈值"]

static var _表: Array = []
static var _表代: int = -1

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
	for 条 in 包.get("双子", []):
		if 条 is Dictionary:
			表.append(_还原值(条, ""))
	return 表

static func 卡表() -> Array:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读表()
		_表代 = Db.代
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return (c as Dictionary).duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	var 键 := str((id as Dictionary).get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str((c as Dictionary).get("id", "")) == 键:
			return (c as Dictionary).duplicate(true)
	return {}

static func 有(id: Variant) -> bool:
	return not 卡("" if id == null else id).is_empty()

## 某个人的 7 张牌（`角色` / `角色们` 两种认法；顺序 = 3 主武器 → 大招 → 3 精神）
static func 角色牌们(键: Variant) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 卡表():
		if str((c as Dictionary).get("角色", "")) == k or J.inc(J.or_((c as Dictionary).get("角色们"), []), k):
			出.append((c as Dictionary).duplicate(true))
	return 出

## 主武器卡 / 大招槽卡 / 精神牌三种取法（测试与门面用）
static func 主武器卡们(键: Variant = "") -> Array:
	return _按类("主武器卡", 键)

static func 大招卡们(键: Variant = "") -> Array:
	return _按类("大招槽卡", 键)

static func 精神牌们(键: Variant = "") -> Array:
	return _按类("专属精神牌", 键)

static func _按类(类: String, 键: Variant) -> Array:
	var 出: Array = []
	for c in 卡表():
		var d: Dictionary = c
		if str(d.get("卡类", "")) != 类:
			continue
		if str(键) != "" and str(d.get("角色", "")) != str(键):
			continue
		出.append(d)
	return 出

# ==========================================================================================
# 三、身份判读
# ==========================================================================================
static func 是塔斯克(u: Variant) -> bool:
	return _键Of(u) == 塔斯克

static func 是雷欧娜(u: Variant) -> bool:
	return _键Of(u) == 雷欧娜

static func 是本批单位(u: Variant) -> bool:
	var k := _键Of(u)
	return k == 塔斯克 or k == 雷欧娜

static func _键Of(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	return str(J.or_(J.or_(J.or_((u as Dictionary).get("tplKey"), (u as Dictionary).get("key")),
		(u as Dictionary).get("mech")), ""))

## 名册口径：这两个人不在「名册」里（旧版本存档 / 编成仍能造出 A4 / A5，战斗黄金要用）
static func 不在名册(键: Variant) -> bool:
	return J.inc(移出键们, str(键))

## 名册新增的键（`RosterManager` 把它们并进招募候选 / 晋升面板）
static func 名册新增键们() -> Array:
	return 加入键们.duplicate()

# ==========================================================================================
# 四、本场 / 本阶段状态
# ==========================================================================================
## 开局：把两个人的计数与阶段标记补齐（幂等；`Setup.初始化单机牌组` 调一次）。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if not (u is Dictionary) or not 是本批单位(u):
			continue
		if not ((u as Dictionary).get("v3计数") is Dictionary):
			(u as Dictionary)["v3计数"] = {}
		if not (u as Dictionary).v3计数.has(本场被攻击键):
			(u as Dictionary).v3计数[本场被攻击键] = 0
		敌方阶段初(ctx)

## 每个**敌方阶段**开始（`Btl.结束我方回合` 一进来就调）：
##   · 塔斯克 `引力墙待 = true`（这个阶段第一次被攻击 −30%）
##   · 塔斯克 `掩护剩余 = 2`（这个阶段可以替正后方的队友接 2 次）
static func 敌方阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if not (u is Dictionary) or str((u as Dictionary).get("side", "")) != "ally":
			continue
		if not 是塔斯克(u):
			continue
		(u as Dictionary)[引力墙待键] = true
		(u as Dictionary)[掩护剩余键] = BattleGuard.掩护额度(u)

## 我方阶段开始（`Btl.开始我方阶段` 的 A6a 那一段之后调）：清掉「对手回合」留下的阶段标记。
## 「到下个我方阶段前」的减伤 / 闪避走 buff 的 `剩余`，这里一个字节都不碰。
static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.concat(J.or_((ctx as Dictionary).get("allies"), []), J.or_((ctx as Dictionary).get("enemies"), [])):
		if not (u is Dictionary):
			continue
		(u as Dictionary).erase(引力墙待键)
		(u as Dictionary).erase(掩护剩余键)
		(u as Dictionary).erase("掩护补充")
		(u as Dictionary).erase(耐打Turn键)

## 规则钩子转发【我方阶段初_后】（`RuleHooks.广播("我方阶段初_后")`）。
static func 我方阶段初_后(ctx: Variant) -> void:
	阶段初(ctx)

# ==========================================================================================
# 五、防守侧钩子（由 `Calc` 在**每一次攻击**的非预览路径上调）
# ==========================================================================================
## 受击前的记账（`Calc._单体结算` 开头，非预览）：只动「本场被攻击」计数，不掷随机数。
static func 受击前(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return
	if not (att is Dictionary) or str((att as Dictionary).get("side", "")) != "enemy":
		return
	if str((def as Dictionary).get("side", "")) != "ally" or not 是塔斯克(def):
		return
	DeckFlow.计数加(def, 本场被攻击键, 1)

## 受伤倍率（`Calc._单体结算` 的段内倍率处与 `ClassCards.伤害倍率` 并列）：
##   【引力墙】= 每个敌方阶段**第一次**被攻击时受到伤害 ×0.7（其余攻击 = 1.0）。
##   消费点在 `攻击后消耗()`（一次攻击结算完才清），所以一次攻击的**所有段**都吃这 −30%。
static func 受伤倍率(ctx: Variant, att: Variant, def: Variant, _w: Variant = null) -> float:
	if not (ctx is Dictionary) or not (def is Dictionary) or not (att is Dictionary):
		return 1.0
	if str((att as Dictionary).get("side", "")) != "enemy":
		return 1.0
	if not 是塔斯克(def) or not J.truthy((def as Dictionary).get(引力墙待键)):
		return 1.0
	return 1.0 - 引力墙减伤

## 命中修正（`Calc.hitRate` 里与 `ClassCards.命中修正` 并列）：
##   · 【重力冲撞】命中后 → 目标**下一次攻击**每段命中 −15（`命中惩罚待`）
##   · 【专注】→ 打出者**下一张主武器牌**每段命中 +20（只认 `w.主武器卡`）
static func 命中修正(att: Variant, _def: Variant, w: Variant, ctx: Variant) -> float:
	if not (att is Dictionary):
		return 0.0
	var h := 0.0
	var 罚 := J.num0((att as Dictionary).get(命中惩罚待键))
	if 罚 > 0.0:
		h -= 罚
	if w is Dictionary and J.truthy((w as Dictionary).get("主武器卡")):
		var 加 := J.num0((att as Dictionary).get(专注键))
		if 加 > 0.0:
			h += 加
	return h

## 一次攻击结算完之后消费一次性标记（`Calc._单体结算` 非预览末尾，与 `ClassCards.攻击后消耗` 并列）。
static func 攻击后消耗(ctx: Variant, att: Variant, def: Variant, landed: float = 0.0, w: Variant = null) -> void:
	if not (ctx is Dictionary):
		return
	# ---- 【引力墙】消费：这个敌方阶段的第一次被攻击已经吃完 −30% ----
	if def is Dictionary and 是塔斯克(def) and J.truthy((def as Dictionary).get(引力墙待键)) \
		and att is Dictionary and str((att as Dictionary).get("side", "")) == "enemy":
		(def as Dictionary)[引力墙待键] = false
		_记(ctx, "引力墙", def, "这个敌方阶段的第一次被攻击已经用掉（受到的伤害 −%d%%）" % int(引力墙减伤 * 100.0))
	# ---- 【重力冲撞】命中后：目标下一次攻击每段命中 −15 ----
	if att is Dictionary and w is Dictionary and str((w as Dictionary).get("name", "")) == "重力冲撞" \
		and float(landed) > 0.0 and def is Dictionary and str((def as Dictionary).get("side", "")) != str((att as Dictionary).get("side", "")):
		(def as Dictionary)[命中惩罚待键] = 重力冲撞命中惩罚
		_记(ctx, "重力冲撞", def, "被撞中 → 它**下一次攻击每段命中 −%d**" % int(重力冲撞命中惩罚))
	# ---- 一次性标记的消费 ----
	if att is Dictionary:
		var 罚 := J.num0((att as Dictionary).get(命中惩罚待键))
		if 罚 > 0.0:
			(att as Dictionary).erase(命中惩罚待键)
			_记(ctx, "重力冲撞", att, "这一次攻击吃完每段命中 −%d，标记清除" % int(罚))
		if J.num0((att as Dictionary).get(专注键)) > 0.0 and w is Dictionary \
			and J.truthy((w as Dictionary).get("主武器卡")):
			var 加 := J.num0((att as Dictionary).get(专注键))
			(att as Dictionary).erase(专注键)
			_记(ctx, "专注", att, "这一张主武器牌吃完每段命中 +%d，标记清除" % int(加))

## 规则钩子转发【受方伤害倍率】（`RuleHooks.依次乘("受方伤害倍率")`）。
static func 受方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	return 受伤倍率(ctx, att, def, w)

## 规则钩子转发【武器攻击后】（`RuleHooks.广播("武器攻击后")`）。
static func 武器攻击后(ctx: Variant, att: Variant, def: Variant, landed: float, w: Variant) -> void:
	攻击后消耗(ctx, att, def, landed, w)

# ==========================================================================================
# 六、★ R4：「掩护」与「我可是很耐打的！」—— 改目标，必须与 `Btl.算意图` 同源
# ==========================================================================================
## 塔斯克正后方（我方后排同列）的那台队友（`原目标` 就是后排那台时才有值）。纯读。
static func 正后方队友(ctx: Variant, 后排: Variant) -> Variant:
	if not (ctx is Dictionary) or not (后排 is Dictionary) or (后排 as Dictionary).get("slot") == null:
		return null
	if Fm.rowOfSlot(float((后排 as Dictionary).slot)) != Fm.ROW_BACK:
		return null
	var 前列 := Fm.另一排同位(float((后排 as Dictionary).slot))
	if 前列 < 0:
		return null
	for u in Units.livingOf(str((后排 as Dictionary).get("side", "ally")), ctx):
		if u is Dictionary and float((u as Dictionary).get("slot", -1.0)) == float(前列) \
			and (是塔斯克(u) or CelestialV01.是掩护者(u)):
			return u
	return null

## 【掩护】的接管者：正后方的队友被**直射 / 近战单体**打 → 改由塔斯克承受。
##   返回 null = 不接管（不是后排 / 范围武器 / 不是直射近战 / 塔斯克不在 / 本阶段 2 次已用完）。
static func 掩护者Of(ctx: Variant, 原目标: Variant, w: Variant) -> Variant:
	if not (ctx is Dictionary) or not (原目标 is Dictionary):
		return null
	var 塔 = 正后方队友(ctx, 原目标)
	if not (塔 is Dictionary):
		return null
	if int((塔 as Dictionary).get(掩护剩余键, BattleGuard.掩护额度(塔))) <= 0:
		return null
	if 原目标 is Dictionary and str((原目标 as Dictionary).get("side", "ally")) != "ally":
		return null
	var kind = Reach.rangeKindOf(w)
	if kind != Reach.KIND_DIRECT() and kind != Reach.KIND_MELEE():
		return null
	if Reach.是范围武器(w):
		return null
	return 塔

## ★ 收口（`Ai.enemyAction` / `Boss.单武器动作` 的最后一句话）：
##   把「AI 选中的目标」按【掩护】改成塔斯克，并在返回里打上 `掩护接管 = true`（供 `行动前` 兑现次数）。
##   与 `Btl.算意图` **同一条链** —— 预告里写的目标就是实际挨打的目标（R4）。
static func 掩护收口(ctx: Variant, _攻: Variant, 选中: Variant) -> Variant:
	if not (选中 is Dictionary):
		return 选中
	var 出: Dictionary = 选中
	if 出.get("hit") != null:
		return 选中        # 范围 / 横扫的那一发不接管（一次攻击打一整排，不该整体挪给一个人）
	var 塔 = 掩护者Of(ctx, 出.get("target"), 出.get("weapon"))
	if not (塔 is Dictionary):
		return 选中
	var 改 := 出.duplicate(true)
	改["原目标"] = str((出.get("target") as Dictionary).get("key", ""))
	改["原目标位"] = (出.get("target") as Dictionary).get("slot")
	改["target"] = 塔
	改["掩护接管"] = true
	return 改

## 兑现【掩护】（`Flow.resolveAction` 一进来就调一次；`action.掩护接管` 才有动作）：
##   扣掉塔斯克这个敌方阶段的一次额度并记一行。返回 `{接管, 剩余}`。
static func 行动前(ctx: Variant, _actor: Variant, action: Variant) -> Dictionary:
	var 记 := {"接管": false, "剩余": 0}
	if not (ctx is Dictionary) or not (action is Dictionary):
		return 记
	if not J.truthy((action as Dictionary).get("掩护接管")):
		return 记
	var 塔 = (action as Dictionary).get("target")
	if not (塔 is Dictionary) or not (是塔斯克(塔) or CelestialV01.是掩护者(塔)):
		return 记
	var 剩 := maxi(0, int((塔 as Dictionary).get(掩护剩余键, BattleGuard.掩护额度(塔))) - 1)
	(塔 as Dictionary)[掩护剩余键] = 剩
	记["接管"] = true
	记["剩余"] = 剩
	var 被护键 = (action as Dictionary).get("原目标")
	var 被护名 := str(J.or_((action as Dictionary).get("原目标名"), 被护键))
	var 被护台 = Btl.找单位(ctx, 被护键, "ally")
	if 被护台 is Dictionary:
		被护名 = str((被护台 as Dictionary).get("name", 被护名))
	# ★ 2026-10-21（任务单问题 4）：日志写清「谁保护了谁 + 剩余几次」——
	#   `〔援护防御〕塔斯克 保护 艾克赛琳，替其挡下攻击！（剩余援护 2/2 次）`
	Btl.pushLog(ctx, "〔援护防御〕%s 保护 %s，替其挡下攻击！（%s）" % [塔.name, 被护名, Btl.援护剩余文(塔)],
		J.merged({"类型": "双人卡", "牌名": "掩护", "保护者": 塔.get("key"),
			"被保护者": 被护键, "剩余": 剩, "掩护剩余": 剩}, Btl.谁(塔)))
	return 记

## ★ 塔斯克在场时，老的「同路铁壁护卫 / 50% 重装挡枪」不再对他二次生效 ——
##   否则「掩护每阶段 2 次」会被老机制无限续上、而且老机制**不在预告里**（R4 会破）。
##   由 `Btl.嘲讽` 在开打前问一次（纯读）。
static func 接管嘲讽(ctx: Variant, _攻击者: Variant, 原目标: Variant) -> bool:
	if not (ctx is Dictionary) or not (原目标 is Dictionary):
		return false
	if (原目标 as Dictionary).get("slot") == null:
		return false
	if str((原目标 as Dictionary).get("side", "")) != "ally":
		return false
	return 正后方队友(ctx, 原目标) != null

## 「我可是很耐打的！」：敌人**单体**攻击优先选它（与【挑衅】同一套筛法，同一个调用点）。
static func 可选目标(ctx: Variant, 攻: Variant, 目标: Variant, w: Variant) -> bool:
	if not (ctx is Dictionary) or not (攻 is Dictionary) or not (目标 is Dictionary):
		return true
	if is_same(攻, 目标):
		return true
	if str((目标 as Dictionary).get("side", "")) == str((攻 as Dictionary).get("side", "")):
		return true
	if Reach.是范围武器(w):
		return true
	var 挑 = 耐打者(ctx, 攻)
	if not (挑 is Dictionary):
		return true
	return is_same(挑, 目标)

## 现在挂着「我可是很耐打的！」的塔斯克（活的；没有 = null）。纯读。
static func 耐打者(ctx: Variant, 攻: Variant) -> Variant:
	if not (ctx is Dictionary) or not (攻 is Dictionary):
		return null
	var 守方 := Units.otherSide(str((攻 as Dictionary).get("side", "enemy")))
	var t = (ctx as Dictionary).get("turn", 0.0)
	for u in Units.livingOf(守方, ctx):
		if u is Dictionary and J.same((u as Dictionary).get(耐打Turn键), t):
			return u
	return null

# ==========================================================================================
# 七、效果算子（`CardEffects.执行算子` 的 `"duo"` 分支转到这里）
# ==========================================================================================
static func _ctxOf(运行: Dictionary) -> Dictionary:
	var c = 运行.get("ctx")
	return c if c is Dictionary else {}

## 打出者：`ctx._当前出牌者` 优先（`Btl.打出精神或公有牌` 写死的那一个）
static func _施放者(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 键 := str(ctx.get("_当前出牌者", ""))
	if 键 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 and str((u as Dictionary).get("key", "")) == 键:
				return u
	var 目标们 = 运行.get("allies")
	if 目标们 is Array and not (目标们 as Array).is_empty():
		return (目标们 as Array)[0]
	return null

## 指定的友军：`ctx._当前目标` → 找不到就取**血量比例最低**的存活队友（确定性，不掷随机数）
static func _友军(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	var 们 := Units.livingOf("ally", ctx)
	if 们.is_empty():
		return null
	J.sort(们, func(a, b):
		var d := _血比(a) - _血比(b)
		return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
	return 们[0]

static func _血比(u: Variant) -> float:
	if not (u is Dictionary):
		return 0.0
	var 上 := float((u as Dictionary).get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float((u as Dictionary).get("hp", 0.0)) / 上

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String, 额外: Dictionary = {}) -> void:
	var 谁 := J.merged({"类型": "双人卡", "牌名": 牌名}, 额外)
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
		return ["没有能打出这张牌的机体"]
	var u: Dictionary = 施
	match 动作:
		"自身减伤":
			Btl.换同源增益(u, 牌名, {"受伤Mul": -减伤30, "剩余": 1.0})
			_记(ctx, 牌名, u, "到下个我方阶段前受到的伤害 **−%d%%**" % int(减伤30 * 100.0))
			return ["受到伤害 −%d%%" % int(减伤30 * 100.0)]
		"专注命中":
			u[专注键] = 专注命中加成
			_记(ctx, 牌名, u, "下一张主武器牌每段命中 **+%d**" % int(专注命中加成))
			return ["下一张主武器牌每段命中 +%d" % int(专注命中加成)]
		"耐打挑衅":
			u[耐打Turn键] = float(ctx.get("turn", 1.0))
			Btl.加战意(u, 10.0, ctx, 牌名)
			_记(ctx, 牌名, u, "到下个我方阶段前敌方单体攻击优先选它；战意 +10（现 %s）" % J.s(J.num0(u.get("战意"))))
			return ["敌方单体攻击优先选它；战意 +10"]
		"抽公有牌":
			var 抽 := Setup.抽公有牌(ctx, 1)
			_记(ctx, 牌名, u, "抽 %d 张公有牌" % 抽.size())
			return ["抽 %d 张公有牌" % 抽.size()]
		"指定友军减伤":
			var t = _友军(运行)
			if not (t is Dictionary):
				return ["没有能指定的友军"]
			Btl.换同源增益(t, 牌名, {"受伤Mul": -减伤30, "剩余": 1.0})
			_记(ctx, 牌名, t, "到下个我方阶段前受到的伤害 **−%d%%**" % int(减伤30 * 100.0),
				{"来源单位": u.get("key")})
			# ★ 【T-Link 感应】：雷欧娜打出「指定一台友军」的牌 → 那台友军到下个我方阶段前闪避 +10
			_tlink感应(ctx, u, t, 牌名)
			return ["%s 受到伤害 −%d%%（闪避 +%d）" % [str(t.get("name", "")), int(减伤30 * 100.0), int(TLINK闪避加成)]]
	push_error("AtxDuo：未知的动作「%s」" % 动作)
	return []

## 【T-Link 感应】：雷欧娜打出「指定一台友军」的牌 → 那台友军到下个我方阶段前**闪避 +10**。
##   `DeckFlow` / `FacAtx` 的等价物都没有，这一条只属于雷欧娜（`是雷欧娜` 才生效）。
static func _tlink感应(ctx: Dictionary, u: Variant, t: Variant, 牌名: String) -> bool:
	if not (t is Dictionary) or not 是雷欧娜(u):
		return false
	Btl.换同源增益(t, "T-Link感应:%s" % 牌名, {"eva": TLINK闪避加成, "剩余": 1.0})
	_记(ctx, "T-Link感应", t, "雷欧娜的【%s】指定了它 → 到下个我方阶段前闪避 **+%d**" % [牌名, int(TLINK闪避加成)])
	return true

## 打出任意一张「指定一台友军」的牌之后的钩子（`Btl.打出精神或公有牌` 末尾调一次）。
##   `card.目标 == "友军"` 且打出者是雷欧娜 → 那台友军闪避 +10；不指定友军的牌 = 一行都不写。
static func 打出牌后(ctx: Variant, u: Variant, card: Variant, target_id: Variant = null) -> bool:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (card is Dictionary):
		return false
	if str((card as Dictionary).get("目标", "")) != "友军":
		return false
	var t = Btl.找单位(ctx, target_id, "ally")
	if not (t is Dictionary):
		t = u
	return _tlink感应(ctx, u, t, str((card as Dictionary).get("名", "")))

# ==========================================================================================
# 八、大招亮起条件（纯读；`DeckFlow.条件满足` 的 `本场被攻击` 类型由这里定义口径）
# ==========================================================================================
## 这张大招现在**亮不亮**（`{满足, 现状, 门槛, 说明}`；不认识的牌 = 满足）。
static func 大招条件(ctx: Variant, u: Variant, 卡: Variant) -> Dictionary:
	var 出 := {"满足": true, "现状": 0, "门槛": 0, "说明": ""}
	if not (卡 is Dictionary):
		return 出
	var 门 = (卡 as Dictionary).get("实时门槛")
	if not (门 is Dictionary):
		return 出
	出["门槛"] = int(J.num0((门 as Dictionary).get("阈值")))
	出["说明"] = str((门 as Dictionary).get("说明", ""))
	if str((门 as Dictionary).get("类型", "")) == 本场被攻击键 or str((门 as Dictionary).get("类型", "")) == "本场被攻击":
		# ★ A6b：新的「本场累计次数」条件类型 —— 数的是 `v3计数.本场被攻击`（每个敌方攻击事件 +1）
		出["现状"] = DeckFlow._计数(u, 本场被攻击键)
		出["满足"] = int(出["现状"]) >= int(出["门槛"])
		return 出
	出["满足"] = DeckFlow.条件满足(ctx, u, 门)
	return 出

## 规则钩子【条件值】：`本场被攻击` 这个条件类型的口径由这里定义（别的类型不接手）。
static func 条件值(_ctx: Variant, u: Variant, t: String, 条: Variant) -> Dictionary:
	if t != "本场被攻击":
		return {"终局": false}
	var 阈 := float(J.or_((条 as Dictionary).get("阈值"), 0.0))
	var 需 := int(阈 if 阈 > 0.0 else 1.0)
	return {"终局": true, "值": DeckFlow._计数(u, 本场被攻击键) >= 需}

# ==========================================================================================
# 九、三层反馈：预告 / 状态行（纯读，一个状态都不改）
# ==========================================================================================
static func 状态行(u: Variant, ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 名 := str((u as Dictionary).get("name", ""))
	if J.truthy((u as Dictionary).get(引力墙待键)):
		出.append("%s〔引力墙〕这个敌方阶段的第一次被攻击 −%d%%" % [名, int(引力墙减伤 * 100.0)])
	var 剩 := int((u as Dictionary).get(掩护剩余键, 0))
	if 剩 > 0:
		出.append("%s〔掩护〕本阶段还能替正后方的队友接 %d 次" % [名, 剩])
	if J.num0((u as Dictionary).get(命中惩罚待键)) > 0.0:
		出.append("%s〔重力冲撞〕下一次攻击每段命中 −%d" % [名, int(J.num0((u as Dictionary).get(命中惩罚待键)))])
	var 加 := J.num0((u as Dictionary).get(专注键))
	if 加 > 0.0:
		出.append("%s〔专注〕下一张主武器牌每段命中 +%d" % [名, int(加)])
	var t = (ctx as Dictionary).get("turn", 0.0) if ctx is Dictionary else null
	if J.same((u as Dictionary).get(耐打Turn键), t):
		出.append("%s〔我可是很耐打的！〕敌方单体攻击优先选它" % 名)
	if 是本批单位(u):
		出.append("%s〔%s〕本场被攻击 %d 次" % [名, "塔斯克" if 是塔斯克(u) else "雷欧娜",
			DeckFlow._计数(u, 本场被攻击键)])
	return 出
