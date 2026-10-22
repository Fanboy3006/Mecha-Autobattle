## ★ A4（响介 v0.3，作者 2026-10-17 拍板）：「赌神」—— 全局「上一次攻击」账 + 入局 / 翻盘 / 续注。
##
## 权威依据（数值与口径逐字照抄，一个数都不许改）：
##   · `协作/设计/响介卡牌设计 v0.1.md` §1（段 / 打空 / **上一把输了**）、§2（独有机制【赌神】）
##   · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A4 行
##
## 四条口径（改一个字都要先改设计稿）：
##   ① **「上一把输了」= 场上最近一次攻击**（**敌我都算**、**跨阶段保留不清空**）：
##      `打空段 >= 命中段` 且 `打空段 + 命中段 >= 1`。
##      **只用于「赌神·入局」的亮起门槛** —— 【赌局】只看 `u.闪`（A3b 已落地，这里别碰）。
##   ② 入局：大招槽卡、`is_weapon = false`（不算武器牌、**不销毁武器**）、费用 10；
##      亮起 = 上一把输了 **且** 响介战意 ≥ 40 **且** 赌神未开启。
##   ③ 开启中：响介所有攻击**每段命中 −10**；**每打空 1 段**独立掷一次 50%「翻盘」——
##      成功则该段**改为命中并暴击**、该段**暴击倍率 ×3**（平时 ×2）；
##      **翻盘的段仍然记为打空**（`状.打空` / `ctx.战况计数.未命中段` 照常 +1，不许因为翻盘就少记）。
##   （4）续注：每个我方阶段开始**先扣 10 战意**；扣不出 10 → 赌神关闭，入局冷却 2。
##   （5）概率覆盖（给后续牌留口子，默认 50%）：单位键 `赌神翻盘概率` 优先，其次 `ctx.赌神翻盘概率`
##      —— 例如「响介，交给你了」把它改成 0.6。
##
## ★ 三层反馈（缺一层不算做完）：
##   即时 = 三行 `〔赌神〕…`（入局 / 翻盘 / 续注）；
##   预告 = 机体卡状态行 / 快照上的「赌神」标记 + 入局置灰时写明原因（上一把没输 / 战意不足）；
##   结算 = `赌神本场翻盘段数(ctx)`（**纯读**，本轮不做界面）。
class_name AtxGodsbet
extends RefCounted

## 「赌神·入局」的卡片 id（= `FacAtx` 卡表里的 `U_ATX_2`；v0.2 的「赌神」在 A4 原地改造成这张）
const 入局ID := "U_ATX_2"
const 入局名 := "赌神·入局"
## 费用 10（战意）/ 亮起门槛 40 / 续注 10 / 离场后冷却 2（设计稿 §2 表格）
const 费用 := 10.0
const 战意门槛 := 40.0
const 续注 := 10.0
const 关闭冷却 := 2.0
## 翻盘：默认 50%，该段暴击倍率 **×3**（平时 ×2）
const 默认翻盘概率 := 0.5
const 翻盘暴击倍率 := 3.0
## 响介的机体键（ATX 的 A1）
const 响介键 := "A1"

## 本场初始化：`ctx.上一次攻击`（空账）与 `ctx.赌神`（未开启）。由 `FacAtx.初始化` 调。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["上一次攻击"] = {}
	ctx["赌神"] = {"开启": false, "本场翻盘段数": 0, "本场入局次数": 0, "本场续注次数": 0, "本场关闭次数": 0}

# ==========================================================================================
# 二、★ 核心新数据结构：`ctx.上一次攻击`（全局一条，敌我都算，跨阶段保留）
# ==========================================================================================
## 一次攻击结算完之后汇总成**全局一条**。`记账` = `Calc.resolveAttack` 里按目标数出来的
## `{命中段, 打空段}`（A2 建的 per-target 账，这里直接复用）。
## 打空 + 命中 < 1（完全被吞掉的攻击）不算一次攻击 —— 不覆盖上一把。
static func 记上一次攻击(ctx: Variant, 攻: Variant, 守: Variant, 记账: Variant) -> void:
	if not (ctx is Dictionary) or not (记账 is Dictionary):
		return
	var 中 := int(J.num0(记账.get("命中段")))
	var 空 := int(J.num0(记账.get("打空段")))
	# 注：`打空 + 命中 < 1`（完全被吞掉的攻击）也照记 —— 「上一把输了」自己带 `>= 1` 的下限，
	#   这样账永远等于「场上最近一次攻击」这一条真源（0/0 判出来就是「没输」）。
	ctx["上一次攻击"] = {
		"命中段": 中, "打空段": 空,
		"攻击方": J.g(攻, "key"), "防守方": J.g(守, "key"),
		"回合": int(ctx.get("turn", 1)),
	}

## 最近一次攻击的两个数（**纯读**；没有 = 空字典）。
static func 上一次攻击(ctx: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {}
	var 账 = ctx.get("上一次攻击")
	return (账 as Dictionary).duplicate(true) if 账 is Dictionary else {}

## ★ 「上一把输了」：场上最近一次攻击里 `打空段 >= 命中段` 且 `打空段 + 命中段 >= 1`。
## **敌我都算**（不看是谁打的）、**跨阶段保留**（没有任何地方清它，只有下一次攻击覆盖）。
static func 上一把输了(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 账 = ctx.get("上一次攻击")
	if not (账 is Dictionary):
		return false
	var 空 := int(J.num0((账 as Dictionary).get("打空段")))
	var 中 := int(J.num0((账 as Dictionary).get("命中段")))
	return 空 >= 中 and 空 + 中 >= 1

## `」字面账（只给记录文案用）：`{打空段, 命中段}`。
static func 上一把数字(ctx: Variant) -> Dictionary:
	var 账 := 上一次攻击(ctx)
	if 账.is_empty():
		return {"打空段": 0, "命中段": 0}
	return {"打空段": int(J.num0(账.get("打空段"))), "命中段": int(J.num0(账.get("命中段")))}

# ==========================================================================================
# 三、赌神状态（`ctx.赌神` 一本账；不往单位上写任何持久字段）
# ==========================================================================================
static func _态(ctx: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {}
	if not (ctx.get("赌神") is Dictionary):
		ctx["赌神"] = {"开启": false, "本场翻盘段数": 0, "本场入局次数": 0, "本场续注次数": 0, "本场关闭次数": 0}
	return ctx["赌神"]

## 赌神现在开着吗（**纯读**；只认布尔 `true`）。
static func 赌神开启(ctx: Variant) -> bool:
	if not (ctx is Dictionary) or not (ctx.get("赌神") is Dictionary):
		return false
	return J.truthy((ctx["赌神"] as Dictionary).get("开启"))

## 结算（纯读）：本场累计「翻盘段数」。
static func 赌神本场翻盘段数(ctx: Variant) -> int:
	if not (ctx is Dictionary) or not (ctx.get("赌神") is Dictionary):
		return 0
	return int(J.num0((ctx["赌神"] as Dictionary).get("本场翻盘段数")))

## 这张单位是不是响介（键 / 模板键两种认法；只认我方）。
static func 是响介(u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if str(u.get("side", "ally")) != "ally":
		return false
	return str(u.get("key", "")) == 响介键 or str(u.get("tplKey", "")) == 响介键

## 赌神开启中，响介**每段命中 −10**（没开启 / 不是响介 = 0，一个数字都不动）。
static func 命中惩罚(att: Variant, ctx: Variant = null) -> float:
	if not (ctx is Dictionary):
		return 0.0
	if not 赌神开启(ctx) or not 是响介(att):
		return 0.0
	return 10.0

## 规则钩子转发【命中修正】（`RuleHooks.汇总("命中修正")`）：赌神是**减**命中，所以取负。
static func 命中修正(att: Variant, _def: Variant, _w: Variant, ctx: Variant) -> float:
	return -命中惩罚(att, ctx)

## 规则钩子转发【我方阶段初_前】（`RuleHooks.广播("我方阶段初_前")`）。
static func 我方阶段初_前(ctx: Variant) -> void:
	阶段初(ctx)

## 翻盘概率（默认 50%）：**单位上的临时覆盖键**优先，其次 `ctx.赌神翻盘概率`。
static func 翻盘概率(ctx: Variant, u: Variant = null) -> float:
	var v = J.g(u, "赌神翻盘概率")
	if v == null:
		v = J.g(ctx, "赌神翻盘概率")
	if not J.finite(v):
		return 默认翻盘概率
	return clampf(float(v), 0.0, 1.0)

## ★ 每打空 1 段独立掷一次「翻盘」。没开启 / 不是响介 → **false 且不掷随机数**。
static func 掷翻盘(ctx: Variant, att: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	if not 赌神开启(ctx) or not 是响介(att):
		return false
	var rng = ctx.get("rng")
	if rng == null:
		return false
	return float(rng.next_float()) < 翻盘概率(ctx, att)

# ==========================================================================================
# 四、「赌神·入局」—— 大招槽卡（不算武器牌、不销毁武器）
# ==========================================================================================
static func 是入局卡(card: Variant) -> bool:
	return card is Dictionary and str((card as Dictionary).get("id", "")) == 入局ID

## 赌神·入局槽的初始形状（与 `DeckFlow` 的大招槽同构：`卡 / cd / cd_max / is_weapon / 已解锁 / 本回合已打`）。
## ★ CR-3 Batch B：`处理者` = 这个槽归谁管（`DeckFlow` 按它分派，不点名任何势力模块）。
static func _新槽() -> Dictionary:
	return {
		"卡": FacAtx.卡(入局ID), "cd": 0.0, "cd_max": 关闭冷却,
		"is_weapon": false, "已解锁": true, "解锁说明": "",
		"实时门槛满足": true, "门槛说明": "", "本回合已打": false,
		"处理者": "AtxGodsbet",
	}

static func _响介(ctx: Variant) -> Variant:
	if not (ctx is Dictionary):
		return null
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and 是响介(u):
			return u
	return null

static func 找入局槽(u: Variant) -> Dictionary:
	if not (u is Dictionary):
		return {}
	for 槽 in J.or_(u.get("大招槽"), []):
		if 槽 is Dictionary and 是入局卡(槽.get("卡")):
			return 槽
	return {}

## 把「赌神·入局」放进响介的大招槽（幂等）。由 `Setup.初始化单机牌组` 在分牌之后调一次：
## 卡牌流转开着时 `DeckFlow.拆分单位牌` 已经把它（`卡类 = 大招槽卡`）放好了；否则这里补上。
static func 装填大招槽(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	var u = _响介(ctx)
	if u == null:
		return
	if not (u.get("大招槽") is Array):
		u["大招槽"] = []
	if not 找入局槽(u).is_empty():
		return
	(u["大招槽"] as Array).append(_新槽())

## 这张入局现在打不打得出来：空串 = 能打；否则是**给玩家看的理由**（预告层直接拿去置灰）。
static func 入局不可打原因(ctx: Variant, u: Variant, 槽: Variant = null) -> String:
	if not (u is Dictionary):
		return "响介不在场"
	var 本槽: Dictionary = 槽 if 槽 is Dictionary else 找入局槽(u)
	if 本槽.is_empty():
		return "大招槽里没有「%s」" % 入局名
	if J.truthy(本槽.get("本回合已打", false)):
		return "本回合已经打过这张大招（同一张每回合限 1 次）"
	if float(本槽.get("cd", 0.0)) > 0.0:
		return "冷却中（还剩 %d 回合）" % int(本槽.get("cd", 0.0))
	if 赌神开启(ctx):
		return "赌神已经在局中（不能重复入局）"
	if not 上一把输了(ctx):
		return "亮起条件未满足：上一把没输（打空段 < 命中段）"
	if Btl.战意(u) < 战意门槛:
		return "战意不够（要 %d，现在 %d）" % [int(战意门槛), int(Btl.战意(u))]
	return ""

static func 入局可用吗(ctx: Variant, u: Variant) -> bool:
	return 入局不可打原因(ctx, u) == ""

## 规则钩子【卡不可打原因】：入局卡走赌神自己的口子；别的牌一律不接手。
static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	if not 是入局卡(card):
		return {"终局": false}
	return {"终局": true, "原因": 入局不可打原因(ctx, u, 找入局槽(u))}

# ---- ★ CR-3 Batch B：大招槽按处理者分派（`DeckFlow` 只认 `处理者`，不点名本模块） ----
## 这个槽归本模块吗（纯读；`DeckFlow.识别大招处理者` 只在槽上没有 `处理者` 时问）。
static func 认领大招槽(ctx: Dictionary, _u: Variant, 槽: Dictionary) -> String:
	if not (槽 is Dictionary):
		return ""
	return "AtxGodsbet" if 是入局卡(槽.get("卡")) else ""

## 规则钩子【大招不可打原因】：（终局 = true → 由本模块说了算）。
static func 大招不可打原因(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> Dictionary:
	if not 是入局卡(槽.get("卡")):
		return {"终局": false}
	return {"终局": true, "原因": 入局不可打原因(ctx, u, 槽)}

## 规则钩子【打出大招】：入局 = 开赌神（不置 `主武器已销毁`、不进冷却）。
static func 打出大招(ctx: Dictionary, u: Dictionary, _槽: Dictionary, _目标: Variant) -> Dictionary:
	return 打出入局(ctx, u)

## 打出「赌神·入局」：扣 10 战意 → 赌神开启（**不置** `主武器已销毁`、不进冷却）。
## `u_or_id` 收单位字典 / 单位键（界面两条路都能进来）。
static func 打出入局(ctx: Variant, u_or_id: Variant, _标识: Variant = null) -> Dictionary:
	if not (ctx is Dictionary):
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = u_or_id if u_or_id is Dictionary else Btl.找单位(ctx, u_or_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var 槽 := 找入局槽(u)
	var 因 := 入局不可打原因(ctx, u, 槽)
	if 因 != "":
		return {"成功": false, "原因": 因}
	var 战意前 := Btl.战意(u)
	u["战意"] = maxf(0.0, 战意前 - 费用)
	var 态 := _态(ctx)
	态["开启"] = true
	态["本场入局次数"] = int(J.num0(态.get("本场入局次数"))) + 1
	槽["本回合已打"] = true
	槽["cd"] = 0.0
	# ★ 第 4 项断路器修复（DS41F）：响介开启赌神时按**单位**打一个标记 ——
	#   精神牌「再加一注（别名 加码）」的 `入牌库条件 = 本场赌神开启过` 读它
	#   （设计稿 响介 §6 第 71 行）。读的地方在 `DeckFlow.条件满足`。
	u["本场赌神开启过"] = true
	ctx["本场赌神开启过"] = true
	var 账 := 上一把数字(ctx)
	Btl.pushLog(ctx, "〔赌神〕%s 入局（上一把输了：打空 %d ≥ 命中 %d · 战意 %d）" % [
		str(u.get("name", "")), int(账["打空段"]), int(账["命中段"]), int(战意前)],
		{"类型": "赌神", "状态": "入局", "单位": u.get("key"), "打空段": int(账["打空段"]),
			"命中段": int(账["命中段"]), "战意": 战意前, "费用": 费用,
			"赌神开启": true, "主武器已销毁": J.truthy(u.get("主武器已销毁")), "回合": ctx.get("turn")})
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": 入局名, "战意": Btl.战意(u), "费用": 费用,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "cd": float(槽.get("cd", 0.0)),
		"is_weapon": false, "赌神开启": true}

## `FacAtx` 的算子分发兜底（有人直接跑这张牌的 `效果` 时走同一条路）。
static func 打出算子(ctx: Dictionary, _card: Dictionary) -> Array:
	var u = _响介(ctx)
	if u == null:
		return ["【%s】响介不在场，打不出" % 入局名]
	var r := 打出入局(ctx, u)
	if not J.truthy(r.get("成功")):
		return ["【%s】%s" % [入局名, str(r.get("原因", "打不出来"))]]
	return ["%s 入局：赌神开启" % str(u.get("name", ""))]

# ==========================================================================================
# 五、续注 / 关闭（每个我方阶段开始）
# ==========================================================================================
## 关闭赌神：状态归 false + 「赌神·入局」冷却抬到 2。
static func 关闭赌神(ctx: Variant, 原因: String, 记一条: bool = true) -> void:
	if not (ctx is Dictionary) or not 赌神开启(ctx):
		return
	var 态 := _态(ctx)
	态["开启"] = false
	态["本场关闭次数"] = int(J.num0(态.get("本场关闭次数"))) + 1
	var u = _响介(ctx)
	var 槽 := 找入局槽(u)
	if not 槽.is_empty():
		槽["cd"] = maxf(float(槽.get("cd", 0.0)), 关闭冷却)
	if 记一条:
		Btl.pushLog(ctx, "〔赌神〕关闭（%s）；入局冷却 %d" % [原因, int(关闭冷却)],
			{"类型": "赌神", "状态": "关闭", "原因": 原因, "cd": 关闭冷却,
				"单位": J.g(u, "key"), "回合": ctx.get("turn")})

## 我方阶段开始：赌神开着 → 续注 10 战意。
static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	if not 赌神开启(ctx):
		return
	var u = _响介(ctx)
	if u == null:
		关闭赌神(ctx, "响介不在场", false)
		return
	var 前 := Btl.战意(u)
	if 前 + 0.0001 < 续注:
		# 「扣不出 10」→ 关闭（不扣任何战意），入局冷却 2（与成功续注合成**一行**记录）
		关闭赌神(ctx, "续注扣不出 %d 战意（余 %d）" % [int(续注), int(前)], false)
		Btl.pushLog(ctx, "〔赌神〕续注扣不出 %d 战意（余 %d）→ 赌神关闭，入局冷却 %d" % [
			int(续注), int(前), int(关闭冷却)],
			{"类型": "赌神", "状态": "关闭", "续注": 续注, "战意": 前, "cd": 关闭冷却,
				"单位": u.get("key"), "回合": ctx.get("turn")})
		return
	u["战意"] = maxf(0.0, 前 - 续注)
	var 态 := _态(ctx)
	态["本场续注次数"] = int(J.num0(态.get("本场续注次数"))) + 1
	Btl.pushLog(ctx, "〔赌神〕续注 −%d 战意（余 %d）" % [int(续注), int(u.get("战意"))],
		{"类型": "赌神", "状态": "续注", "续注": 续注, "战意": u.get("战意"),
			"单位": u.get("key"), "回合": ctx.get("turn")})

# ==========================================================================================
# 六、给 `Calc.resolveAttack` 的两条口子（一次攻击内）
# ==========================================================================================
## 这一发攻击该不该掷翻盘（赌神开启 + 是响介 + 非预览）。
static func 可翻盘(ctx: Variant, att: Variant) -> bool:
	return 赌神开启(ctx) and 是响介(att)

## 翻盘段轰出去之后：累计本场翻盘段数 + 记一行即时记录（**一次攻击只写一行**，绝不逐段写）。
static func 记翻盘(ctx: Variant, att: Variant, 段数: int) -> void:
	if not (ctx is Dictionary) or 段数 <= 0:
		return
	var 态 := _态(ctx)
	态["本场翻盘段数"] = int(J.num0(态.get("本场翻盘段数"))) + 段数
	Btl.pushLog(ctx, "〔赌神〕翻盘 ×%d 段 → 改判命中并暴击 ×%d（这 %d 段仍记为打空）" % [
		段数, int(翻盘暴击倍率), 段数],
		J.merged({"类型": "赌神", "状态": "翻盘", "翻盘段数": 段数, "暴击倍率": 翻盘暴击倍率,
			"仍记为打空": true, "单位": J.g(att, "key"), "回合": ctx.get("turn")},
			Btl.谁(att) if att is Dictionary else {}))
