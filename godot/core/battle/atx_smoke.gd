## ★ A5a（拉米亚 v0.1）：「烟雾」场上状态 + 独有关键词【雾袭】+ 烟雾弹副武器。
##
## 权威依据：`协作/设计/拉米亚卡牌设计 v0.1.md` §0 / §1 / §2 / §3.2 / §6
##          · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A5a 行
##
## 三条口径（逐字照设计稿）：
##   ① 烟雾 = **敌方一列（前后 2 格）** 的场上状态，存在 `ctx.烟雾`（数组），
##      每个元素 = `{列, 方, 消失阶段, 放出阶段, 来源}`（**没有「层数」概念**）。
##      效果：**攻击烟雾里的目标**、或**从烟雾里开火** → 每段命中 −30（`Calc.hitRate` 里真的进公式），
##      **敌我都算**（惩罚只读 `方 + 列`，不区分是谁）。
##      叠加：同一列再放一次**只刷新持续时间**，惩罚不叠加（最多 −30，绝不 −60）。
##      持续：到放出后的**第 2 个我方阶段开始时**消失（放出阶段 + 2；`Btl.开始我方阶段` 里判一次）。
##   ② 拉米亚本人的被动「W 系列」：不受烟雾影响 —— **两头都不吃**（她开火 / 她被瞄准都免 −30）。
##      识别口径 = 单位上的 `trait == "wSeries"`（数据里 A3 拉米亚就是这个，纯数据驱动，不写死键）。
##   ③ 【雾袭】：卡上标 `"雾袭": true`，可选 `"雾袭效果"` = 一句给人看的描述。
##      **判定时机 = 打出时**，分两类 —— 攻击牌看「目标在烟雾里」、非攻击牌看「场上有烟雾」；
##      **只判定一次**（不按段、不按次）；**打完即弃，严禁写任何持久键**
##      （没有「层数」、没有「已用」、没有「剩余」这类衍生键；单位字典前后一个字节都不多）。
##      触发后执行 `卡["雾袭分支"]`（与【强运】同一套声明式算子；另认 `算子: "抽牌"`）。
##
## ★ 三层反馈：
##   即时 = `〔烟雾〕…放出 / 刷新 / 散去` + `〔雾袭〕…触发：…` 一行一条；
##   预告 = `雾标` 用（`单位在雾里` → `unit_view()["雾"] = true` → `unit_card` 上的「雾」字）；
##   结算 = `烟雾本场放出次数(ctx)` / `雾袭本场触发次数(ctx)`（**纯读**，本轮不做界面）。
class_name AtxSmoke
extends RefCounted

## 每段命中惩罚（设计稿 §1「每段命中 −30」）。
const 命中惩罚值 := 30.0
## 放出后的第 2 个我方阶段开始时消失 → `消失阶段 = 放出阶段 + 2`。
const 持续阶段数 := 2

# ==========================================================================================
# 一、牌面判定（全部纯读）
# ==========================================================================================
## 这张牌是不是「烟雾弹」（唯一口径：牌上的 `烟雾` 布尔）。
static func 是烟雾卡(card: Variant) -> bool:
	return card is Dictionary and J.truthy((card as Dictionary).get("烟雾"))

## 这张牌带不带【雾袭】（唯一口径：牌上的 `雾袭` 布尔）。
static func 是雾袭牌(card: Variant) -> bool:
	return card is Dictionary and J.truthy((card as Dictionary).get("雾袭"))

## 牌面「雾袭：…」那一句给人看的描述（没有 = 空串）。预告层直接读它。
static func 雾袭文字(card: Variant) -> String:
	if not 是雾袭牌(card):
		return ""
	return str(J.or_((card as Dictionary).get("雾袭效果"), "雾袭"))

## 这张牌算不算「攻击牌」：命中判定要看**目标在不在烟雾里**（非攻击牌只看场上有雾）。
## 烟雾弹自己是「放一片烟」的非攻击牌，先排掉。
static func 是攻击牌(card: Variant) -> bool:
	if not (card is Dictionary) or 是烟雾卡(card):
		return false
	if J.truthy(card.get("武器牌")) or card.get("武器") is Dictionary:
		return true
	if ["主武器卡", "副武器卡", "衍生攻击卡"].has(str(card.get("卡类", ""))):
		return true
	# ATX v0.2 的「大招牌」用声明式算子打人（`效果 → 全局 → 算子 atx / 动作 攻击`）
	for 组 in J.or_(card.get("效果"), []):
		if not (组 is Dictionary):
			continue
		for 算子 in J.or_(组.get("全局"), []):
			if 算子 is Dictionary and ["攻击", "轮盘双响"].has(str(算子.get("动作", ""))):
				return true
	return false

## 拉米亚本人（被动「W 系列」= 不受烟雾影响）。识别口径只有一条：单位上的 `trait`。
static func 是拉米亚(u: Variant) -> bool:
	return u is Dictionary and str((u as Dictionary).get("trait", "")) == "wSeries"

# ==========================================================================================
# 二、场上状态（`ctx.烟雾`）
# ==========================================================================================
## 本场初始化：有 ctx 就建 `ctx.烟雾` 与两个纯读计数。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["烟雾"] = []
	ctx["烟雾计数"] = {"放出": 0, "雾袭": 0}

## 现在场上有几片烟雾（纯读）。
static func 片数(ctx: Variant) -> int:
	if not (ctx is Dictionary):
		return 0
	return J.or_((ctx as Dictionary).get("烟雾"), []).size()

## 场上有烟雾吗（纯读）。
static func 有雾吗(ctx: Variant) -> bool:
	return 片数(ctx) > 0

## 这一列有烟雾吗（`方` 写空串 = 不分敌我；纯读）。
static func 列有雾(ctx: Variant, 列: int, 方: String = "") -> bool:
	if not (ctx is Dictionary):
		return false
	for e in J.or_(ctx.get("烟雾"), []):
		if not (e is Dictionary):
			continue
		if int(J.num0(e.get("列"))) != 列:
			continue
		if 方 == "" or str(e.get("方", "enemy")) == 方:
			return true
	return false

## 这台单位在不在烟雾里（`方 + 列`；纯读）。没有 `slot` / 没有烟雾 = false。
static func 单位在雾里(ctx: Variant, u: Variant) -> bool:
	if not (u is Dictionary) or (u as Dictionary).get("slot") == null:
		return false
	if not 有雾吗(ctx):
		return false
	var 位 := int(J.num0(u.slot))
	if 位 < 0:
		return false
	return 列有雾(ctx, int(Fm.colOfSlot(float(位))), str(u.get("side", "")))

## 这一发攻击吃不吃 −30（**纯读**，`Calc.hitRate` 唯一的落点）：
##   · 场上一片雾都没有 → 0（一个数字都不动）；
##   · 拉米亚本人在任一端（开火 / 被瞄准）→ 0（被动「W 系列」两头都不吃）；
##   · 从烟雾里开火 或 目标在烟雾里 → 30（**只加一次**，几片雾都只 −30，绝不叠加成 −60）。
static func 命中惩罚(att: Variant, def: Variant, ctx: Variant) -> float:
	if not (ctx is Dictionary) or not 有雾吗(ctx):
		return 0.0
	if 是拉米亚(att) or 是拉米亚(def):
		return 0.0
	if 单位在雾里(ctx, att) or 单位在雾里(ctx, def):
		return 命中惩罚值
	return 0.0

## 规则钩子转发【命中修正】（`RuleHooks.汇总("命中修正")`）：烟雾是**减**命中，所以取负。
static func 命中修正(att: Variant, def: Variant, _w: Variant, ctx: Variant) -> float:
	return -命中惩罚(att, def, ctx)

## 规则钩子转发【我方阶段初_前】（`RuleHooks.广播("我方阶段初_前")`）。
static func 我方阶段初_前(ctx: Variant) -> void:
	阶段初(ctx)

## 这一发攻击吃惩罚的**来源**（给记录文案用）：空串 = 没吃。
static func 惩罚来源(att: Variant, def: Variant, ctx: Variant) -> String:
	if 命中惩罚(att, def, ctx) <= 0.0:
		return ""
	var 我 := 单位在雾里(ctx, att)
	var 敌 := 单位在雾里(ctx, def)
	if 我 and 敌:
		return "从烟雾里开火 · 目标在烟雾里"
	return "从烟雾里开火" if 我 else "目标在烟雾里"

# ==========================================================================================
# 三、★ 放一片烟（唯一的写入入口：只刷新、不叠加）
# ==========================================================================================
## `方` 默认 `"enemy"`（拉米亚在**敌方一列**放）；测试要验「敌我都算」时可以放一片到我方一侧。
## 返回 `{新增, 刷新, 列, 方, 消失阶段, 回合}`。
static func 放烟(ctx: Variant, u: Variant, 列: int, 方: String = "enemy") -> Dictionary:
	var 记 := {"新增": false, "刷新": false, "列": 列, "方": 方, "消失阶段": 0, "回合": 0}
	if not (ctx is Dictionary) or 列 < 0:
		return 记
	var 回合 := int(J.num0(ctx.get("turn", 1.0)))
	var 消失 := 回合 + 持续阶段数
	记["回合"] = 回合
	记["消失阶段"] = 消失
	if not (ctx.get("烟雾") is Array):
		ctx["烟雾"] = []
	var 们: Array = ctx["烟雾"]
	for e in 们:
		if not (e is Dictionary):
			continue
		if int(J.num0(e.get("列"))) == 列 and str(e.get("方", "enemy")) == 方:
			# ★ 同一列再放一次：**只刷新持续时间，惩罚不叠加**（还是那一片，不是第二片）
			e["消失阶段"] = 消失
			e["刷新回合"] = 回合
			e["来源"] = u.get("key") if u is Dictionary else null
			记["刷新"] = true
			_计数加(ctx, "放出", 1)
			Btl.pushLog(ctx, "〔烟雾〕第 %d 列刷新（持续到第 %d 个我方阶段开始，惩罚不叠加）" % [列 + 1, 消失],
				J.merged({"类型": "烟雾", "动作": "刷新", "列": 列, "方": 方, "消失阶段": 消失,
					"回合": 回合}, Btl.谁(u) if u is Dictionary else {}))
			记["摘要"] = "第 %d 列刷新" % (列 + 1)
			return 记
	们.append({"列": 列, "方": 方, "消失阶段": 消失, "放出阶段": 回合,
		"来源": u.get("key") if u is Dictionary else null})
	ctx["烟雾"] = 们
	记["新增"] = true
	_计数加(ctx, "放出", 1)
	Btl.pushLog(ctx, "〔烟雾〕%s 在第 %d 列放出烟雾（前后 2 格 · 每段命中 −30）" % [_谁名(u), 列 + 1],
		J.merged({"类型": "烟雾", "动作": "放出", "列": 列, "方": 方, "消失阶段": 消失, "回合": 回合},
			Btl.谁(u) if u is Dictionary else {}))
	记["摘要"] = "第 %d 列放出" % (列 + 1)
	return 记

## 我方阶段开始时判一次：`消失阶段 <= 当前我方阶段序号` 的烟雾在这一刻散去。
## （放出的那个阶段算第 0 个；下一个阶段 = 第 1 个、再下一个 = 第 2 个 → 那时才散。）
static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary) or not (ctx.get("烟雾") is Array):
		return
	var 回合 := int(J.num0(ctx.get("turn", 1.0)))
	var 留: Array = []
	var 散: Array = []
	for e in ctx["烟雾"]:
		if not (e is Dictionary):
			continue
		if int(J.num0(e.get("消失阶段"))) <= 回合:
			散.append(int(J.num0(e.get("列"))))
		else:
			留.append(e)
	if 散.is_empty():
		return
	ctx["烟雾"] = 留
	for 列 in 散:
		Btl.pushLog(ctx, "〔烟雾〕第 %d 列烟雾散去（第 %d 个我方阶段开始）" % [int(列) + 1, 回合],
			{"类型": "烟雾", "动作": "散去", "列": int(列), "回合": 回合})

# ==========================================================================================
# 四、★ 打出时判一次【雾袭】（唯一的判定入口；不掷随机数、不留状态）
# ==========================================================================================
## 返回 `{触发, 依据, 摘要, 目标, 攻击牌}`。`目标` 可以是单位字典 / 键 / 位。
## `{触发: false}` = 这次没触发（这张牌不带【雾袭】/ 条件不成立）。
static func 打出时(ctx: Variant, u: Variant, card: Variant, 目标: Variant = null) -> Dictionary:
	var 记 := {"触发": false, "依据": "", "摘要": "", "目标": null, "攻击牌": false}
	if not (ctx is Dictionary) or not 是雾袭牌(card):
		return 记
	var 攻 := 是攻击牌(card)
	记["攻击牌"] = 攻
	var 靶: Variant = null
	if 攻 and 目标 != null:
		靶 = 目标 if 目标 is Dictionary else Btl.找单位(ctx, 目标, "enemy")
	var 成 := false
	var 依据 := ""
	if 攻:
		if 靶 is Dictionary and 单位在雾里(ctx, 靶):
			成 = true
			依据 = "目标在烟雾里"
	else:
		if 有雾吗(ctx):
			成 = true
			依据 = "场上有烟雾"
	if not 成:
		return 记
	记["触发"] = true
	记["依据"] = 依据
	记["目标"] = (靶 as Dictionary).get("key") if 靶 is Dictionary else null
	_计数加(ctx, "雾袭", 1)
	# ---- 执行这张牌的「雾袭：…」分支（与普通效果同一套声明式算子）----
	var 摘要 := 执行分支(ctx, u, card, card.get("雾袭分支"))
	记["摘要"] = "；".join(摘要.map(func(x): return str(x)))
	# ---- 即时那一行 ----
	var 说明 := str(J.or_(card.get("雾袭效果"), ""))
	if 说明 == "":
		说明 = 记["摘要"] if 记["摘要"] != "" else "触发"
	Btl.pushLog(ctx, "〔雾袭〕%s「%s」→ %s，触发：%s" % [_谁名(u), str(J.g(card, "名")), 依据, 说明],
		J.merged({"类型": "雾袭", "单位": u.get("key") if u is Dictionary else null,
			"卡牌ID": J.g(card, "id"), "卡牌": J.g(card, "名"), "依据": 依据, "触发": true,
			"攻击牌": 攻, "目标": 记["目标"], "回合": ctx.get("turn")},
			Btl.谁(u) if u is Dictionary else {}))
	return 记

## 执行【雾袭】分支：`{"全局": [算子…]}` 走本文件（认 `抽牌` / `抽精神`），其余原样交给
## `CardEffects.execute_ops`（与普通效果、`强运分支` 同一套声明式算子）。
static func 执行分支(ctx: Variant, u: Variant, card: Variant, ops: Variant) -> Array:
	var 摘要: Array = []
	if not (ctx is Dictionary) or not (ops is Array):
		return 摘要
	for 组 in ops:
		if not (组 is Dictionary):
			continue
		if 组.has("全局"):
			for 算子 in J.or_(组.get("全局"), []):
				_执行算子(ctx, u, card, 算子, 摘要)
			continue
		摘要.append_array(CardEffects.execute_ops(ctx, card, [组]))
	return 摘要

static func _执行算子(ctx: Dictionary, u: Variant, card: Variant, 算子: Variant, 摘要: Array) -> void:
	if not (算子 is Dictionary):
		return
	var 名 := str(算子.get("算子", ""))
	if 名 == "抽牌" or 名 == "抽精神":
		var 张 := maxi(1, int(J.or_(算子.get("数量"), 1)))
		var 抽: Array = []
		if u is Dictionary:
			抽 = Setup.抽专属牌(u, 张)
		摘要.append("抽 %d 张（%d）" % [张, 抽.size()])
		return
	if 名 == "抽公有":
		var 张2 := maxi(1, int(J.or_(算子.get("数量"), 1)))
		var 抽2: Array = Setup.抽公有牌(ctx, 张2)
		摘要.append("抽公有 %d 张（%d）" % [张2, 抽2.size()])
		return
	摘要.append_array(CardEffects.execute_ops(ctx, card, [{"全局": [算子]}]))

# ==========================================================================================
# 五、★ 烟雾弹副武器（`DeckFlow.打出副武器` 里的那个口子）
# ==========================================================================================
## 在一列放烟。`target_id` 指一台敌机 → 用它的列；指不到 / 没指定 → 第一台存活敌机的列；
## 一台敌机都没有 → 第 1 列。返回 `{成功, 列, 卡牌}`。
static func 打出烟雾弹(ctx: Dictionary, u: Variant, card: Dictionary, target_id: Variant = null) -> Dictionary:
	var 靶 = Btl.找单位(ctx, target_id, "enemy")
	if not (靶 is Dictionary):
		var 活: Array = Units.livingOf("enemy", ctx)
		靶 = 活[0] if not 活.is_empty() else null
	var 列 := 0
	if 靶 is Dictionary and 靶.get("slot") != null:
		列 = int(Fm.colOfSlot(float(靶.slot)))
	var r := 放烟(ctx, u, 列, "enemy")
	return {"成功": true, "列": int(r.get("列")), "卡牌": str(card.get("名", "")), "摘要": str(r.get("摘要", ""))}

# ==========================================================================================
# 五之二、★ CR-3 Batch B：`DeckFlow.打出副武器` 的钩子（通用内核不再点名本模块）
# ==========================================================================================
## 规则钩子【副武器特殊打出】：烟雾弹走自己的整段（条目记账 / 放烟 / 雾袭 / 上一张 / 收尾日志）。
static func 副武器特殊打出(ctx: Dictionary, u: Variant, 条目: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not 是烟雾卡(卡) or not (u is Dictionary):
		return {"终局": false}
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	条目["本回合已用"] = int(条目.get("本回合已用", 0)) + 1
	if float(条目.get("cd_max", 0.0)) > 0.0:
		条目["cd"] = float(条目.get("cd_max", 0.0))
	var 放 := 打出烟雾弹(ctx, u, 卡, target_id)
	打出时(ctx, u, 卡, null)
	DeckFlow.记上张打出牌(ctx, u, 卡)
	var 摘要 := Btl.攻击结果摘要(放)
	Btl.pushLog(ctx, "〔副武器〕%s 打出【%s】（不销毁主武器，本回合已用 %d/%d；冷却 %d）%s" % [
		str(u.get("name", "")), str(卡.get("名", "")), int(条目.get("本回合已用", 0)),
		int(条目.get("本回合可用", 1)), int(条目.get("cd", 0.0)), Btl.效果摘要文(摘要)],
		J.merged({"类型": "副武器", "单位": u.get("key"), "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"主武器已销毁": J.truthy(u.get("主武器已销毁")), "列": 放.get("列"),
			"效果摘要": 摘要, "cd": 条目.get("cd")}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"终局": true, "结果": {"成功": true, "卡牌": str(卡.get("名", "")), "击破": 0.0,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "列": 放.get("列"),
		"cd": float(条目.get("cd", 0.0))}}

## 规则钩子【副武器攻击前】：打出时判一次【雾袭】（攻击牌看目标在不在烟里；不留状态）。
static func 副武器攻击前(ctx: Dictionary, u: Variant, 卡: Variant, _条目: Variant, 目标: Variant) -> void:
	打出时(ctx, u, 卡, 目标)

## 规则钩子【大招打出前】：通用大招打出时判一次【雾袭】（不带雾袭 = 立刻返回）。
static func 大招打出前(ctx: Dictionary, u: Variant, 卡: Variant, _槽: Variant, target_id: Variant) -> void:
	打出时(ctx, u, 卡, Btl._存活敌(ctx, u, target_id))

## 规则钩子【条件值】：`有烟雾` 这一类入库 / 亮起条件（别的类型不接手）。
static func 条件值(ctx: Variant, _u: Variant, t: String, _条: Variant) -> Dictionary:
	if t != "有烟雾":
		return {"终局": false}
	return {"终局": true, "值": 有雾吗(ctx)}

# ==========================================================================================
# 六、结算（纯读）
# ==========================================================================================
## 本场一共放出过几片烟雾（刷新也算一次「放出」）。
static func 烟雾本场放出次数(ctx: Variant) -> int:
	return _计数读(ctx, "放出")

## 本场【雾袭】一共触发过几次。
static func 雾袭本场触发次数(ctx: Variant) -> int:
	return _计数读(ctx, "雾袭")

# ==========================================================================================
# 小工具
# ==========================================================================================
static func _谁名(u: Variant) -> String:
	var 名 := str(J.g(u, "name"))
	return 名 if 名 != "" else "我方"

static func _计数加(ctx: Dictionary, 键: String, 加: int) -> void:
	if not (ctx.get("烟雾计数") is Dictionary):
		ctx["烟雾计数"] = {"放出": 0, "雾袭": 0}
	var 计: Dictionary = ctx["烟雾计数"]
	计[键] = int(J.num0(计.get(键))) + 加

static func _计数读(ctx: Variant, 键: String) -> int:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get("烟雾计数") is Dictionary):
		return 0
	return int(J.num0((ctx["烟雾计数"] as Dictionary).get(键)))
