## ★ A4（艾克赛琳 v0.3）：「强运」硬币框架。
##
## 权威依据：`协作/设计/艾克赛琳卡牌设计 v0.1.md`（§独有关键词【强运】+ 各卡的「强运：…」分支）
##          · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A4 行
##
## 三条口径（逐字照设计稿）：
##   ① 牌上标 `"强运": true`（可选 `"强运效果"` = 一句给人看的描述）；
##      打出时掷**一次** 50% 硬币（`ctx.rng`，**一次判定**，不按段、不按次重复掷）；
##      正面 → 执行该牌的「强运：…」分支（`卡["强运分支"]`，与普通效果同一套声明式算子）；
##      反面 → **什么也不发生**。
##   ② **不留状态**：判定完即弃 —— **严禁**写任何持久字段
##      （没有层数、没有剩余回合、没有「已触发」这类衍生键；单位字典前后一个字节都不多）。
##   ③ 两个覆盖口子（供后续牌用，默认不生效）：
##      · 「必定触发」（如「好运连连」）→ 硬币必为正面：`卡["强运必触发"]` / `u.强运必触发` / `ctx.强运必触发`
##        （必为正面时**不掷**随机数 —— 结果与随机数序列都确定）；
##      · 概率覆盖（默认 50%）：`卡["强运概率"]` → `u.强运概率` → `ctx.强运概率`。
##
## ★ 三层反馈：
##   即时 = 一行 `〔强运〕<谁>「<牌名>」硬币 → 正面（触发）/ 反面（未触发）`；
##   预告 = `强运文字(card)`（牌面能看出这张牌带【强运】，以及触发什么）；
##   结算 = `强运本场正反面次数(ctx)`（**纯读**，本轮不做界面）。
class_name AtxLuck
extends RefCounted

## 硬币默认 50%
const 默认概率 := 0.5

# ==========================================================================================
# 一、牌面判定（全部纯读）
# ==========================================================================================
## 这张牌带不带【强运】（唯一口径：牌上的 `强运` 布尔）。
static func 是强运牌(card: Variant) -> bool:
	return card is Dictionary and J.truthy((card as Dictionary).get("强运"))

## 牌面「强运：…」那一句给人看的描述（没有 = 空串）。预告层直接读它。
static func 强运文字(card: Variant) -> String:
	if not 是强运牌(card):
		return ""
	return str(J.or_((card as Dictionary).get("强运效果"), "强运"))

## 本场初始化：硬币正 / 反面两个计数（**只在有 ctx 时**建键）。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["强运硬币"] = {"正面": 0, "反面": 0}

## 结算（纯读）：本场硬币正 / 反面各掷出几次。
static func 强运本场正反面次数(ctx: Variant) -> Dictionary:
	if not (ctx is Dictionary) or not (ctx.get("强运硬币") is Dictionary):
		return {"正面": 0, "反面": 0}
	var 计: Dictionary = ctx["强运硬币"]
	return {"正面": int(J.num0(计.get("正面"))), "反面": int(J.num0(计.get("反面")))}

# ==========================================================================================
# 二、两个覆盖口子
# ==========================================================================================
## 「必定触发」：牌 / 单位 / ctx 任一处写了真值 → 硬币必为正面。
static func 必触发(ctx: Variant, u: Variant, card: Variant) -> bool:
	if J.truthy(J.g(card, "强运必触发")):
		return true
	if J.truthy(J.g(u, "强运必触发")):
		return true
	return J.truthy(J.g(ctx, "强运必触发"))

## 概率覆盖（默认 50%）：牌 > 单位 > ctx。
static func 概率(ctx: Variant, u: Variant, card: Variant) -> float:
	for 源 in [card, u, ctx]:
		var v = J.g(源, "强运概率")
		if J.finite(v):
			return clampf(float(v), 0.0, 1.0)
	return 默认概率

# ==========================================================================================
# 三、★ 打出时掷一次硬币（唯一的副作用入口）
# ==========================================================================================
## 规则钩子【大招打出后】：通用大招打出流程里的那一次掷硬币（`DeckFlow` 只认钩子）。
static func 大招打出后(ctx: Dictionary, u: Variant, 卡: Variant, _槽: Variant) -> void:
	打出时(ctx, u, 卡)

## 返回 `{掷, 正面, 概率, 必触发, 触发, 摘要}`。
## `{掷: false}` = 这次**没掷**（这张牌不带【强运】/ 没有 ctx）。
static func 打出时(ctx: Variant, u: Variant, card: Variant) -> Dictionary:
	var 记 := {"掷": false, "正面": false, "概率": 0.0, "必触发": false, "触发": false, "摘要": ""}
	if not (ctx is Dictionary) or not 是强运牌(card):
		return 记
	var 必 := 必触发(ctx, u, card)
	var 概 := 概率(ctx, u, card)
	var 正 := 必
	if not 必:
		var rng = ctx.get("rng")
		if rng == null:
			return 记
		# ★ 一次判定：整张牌只掷这一下（不按段、不按次）
		正 = float(rng.next_float()) < 概
	记["掷"] = true
	记["正面"] = 正
	记["概率"] = 概
	记["必触发"] = 必
	记["触发"] = 正
	# ---- 结算计数（ctx 上的两个纯数字，不是单位状态）----
	if not (ctx.get("强运硬币") is Dictionary):
		ctx["强运硬币"] = {"正面": 0, "反面": 0}
	var 计: Dictionary = ctx["强运硬币"]
	if 正:
		计["正面"] = int(J.num0(计.get("正面"))) + 1
	else:
		计["反面"] = int(J.num0(计.get("反面"))) + 1
	# ---- 即时那一行 ----
	var 谁 := str(J.g(u, "name"))
	if 谁 == "":
		谁 = "我方"
	Btl.pushLog(ctx, "〔强运〕%s「%s」硬币 → %s" % [
		谁, str(J.g(card, "名")), "正面（触发）" if 正 else "反面（未触发）"],
		J.merged({"类型": "强运", "单位": J.g(u, "key"), "卡牌ID": J.g(card, "id"), "卡牌": J.g(card, "名"),
			"硬币": "正面" if 正 else "反面", "概率": 概, "必触发": 必, "触发": 正,
			"回合": ctx.get("turn")}, Btl.谁(u) if u is Dictionary else {}))
	记["摘要"] = "硬币 %s" % ("正面" if 正 else "反面")
	# ★ A6c 收口：「好运连连」写的是单位级的 `强运必触发`，牌面口径是「本回合**下一张**」——
	#   一张用掉就清（否则整场每张强运牌都必触发 = 比牌面强得多）。
	#   `card` / `ctx` 上的必触发是**判定口子**（测试与全局覆盖），不动。
	if 必 and u is Dictionary and not J.truthy(J.g(card, "强运必触发")):
		if J.truthy(J.g(u, "强运必触发")):
			(u as Dictionary).erase("强运必触发")
	if not 正:
		return 记
	# ---- 正面：执行这张牌的「强运：…」分支（与普通效果同一套声明式算子）----
	var 分支 = card.get("强运分支")
	if 分支 is Array and not (分支 as Array).is_empty():
		var 摘要 := CardEffects.execute_ops(ctx, card, 分支)
		记["摘要"] += "；" + "；".join(摘要.map(func(x): return str(x)))
	return 记
