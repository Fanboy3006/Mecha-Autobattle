## 职责：公有牌的**冷却区** —— 带 `进冷却区` 的公有牌打出后按卡上的 `冷却` 倒计时，归 0 洗回公有牌库。
## 见 协作/设计/维修职业分类牌 v0.1.md §1（「打出后移入左侧牌库显示〔X 回合后进入手牌〕」）
class_name PublicCooldown
extends RefCounted

## 牌库区就位（`DeckFlow.初始化` 的第一件事）。
static func 初始化(ctx: Variant) -> void:
	if ctx is Dictionary and not ((ctx as Dictionary).get("公有冷却") is Array):
		(ctx as Dictionary)["公有冷却"] = []

## 一张公有牌打完去哪儿：`"冷却"` / `"移出"`（每场 1 次）/ `"弃牌堆"`。
## 冷却区是**选择性加入**（卡上写 `进冷却区`）：既有带 `冷却` 却从未启用冷却区的统帅牌照旧进弃牌堆。
static func 去处(card: Variant) -> String:
	if not (card is Dictionary):
		return "弃牌堆"
	if J.truthy((card as Dictionary).get("进冷却区")) and float(J.num0((card as Dictionary).get("冷却"))) > 0.0:
		return "冷却"
	if J.truthy((card as Dictionary).get("移出本场")):
		return "移出"
	return "弃牌堆"

## 送进冷却区（`剩余` = 卡上的 `冷却`）。
static func 放入(ctx: Variant, card: Variant) -> void:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return
	初始化(ctx)
	(ctx as Dictionary).公有冷却.append({"卡": card, "剩余": float(J.num0((card as Dictionary).get("冷却")))})

## 每个我方阶段开始：倒计时 −1，归 0 的牌追加到公有牌库尾（不掷随机数）。
static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get("公有冷却") is Array):
		return
	var 剩: Array = []
	var 回: Array = []
	for e in (ctx as Dictionary).公有冷却:
		if not (e is Dictionary):
			continue
		var 余 := float(J.num0((e as Dictionary).get("剩余"))) - 1.0
		if 余 <= 0.0:
			回.append((e as Dictionary).get("卡"))
		else:
			(e as Dictionary)["剩余"] = 余
			剩.append(e)
	if 回.is_empty():
		return
	(ctx as Dictionary)["公有冷却"] = 剩
	var 库: Array = J.or_((ctx as Dictionary).get("公有牌库"), [])
	for c in 回:
		库.append(c)
	(ctx as Dictionary)["公有牌库"] = 库
	Btl.pushLog(ctx, "〔公有冷却〕%s 冷却结束 → 洗回公有牌库（还有 %d 张在冷却）" % [
		"】【".join(回.map(func(c): return str((c as Dictionary).get("名", "")))), 剩.size()],
		{"类型": "公有冷却", "卡牌": 回.map(func(c): return (c as Dictionary).get("id")), "剩余张数": float(剩.size())})

## 只读状态（表现层 / 测试取用）。
static func 状态(ctx: Variant) -> Dictionary:
	var 们: Array = []
	if ctx is Dictionary and (ctx as Dictionary).get("公有冷却") is Array:
		for e in (ctx as Dictionary).公有冷却:
			if e is Dictionary:
				们.append({"名": str(J.g((e as Dictionary).get("卡"), "名")), "剩余": float(J.num0((e as Dictionary).get("剩余")))})
	return {"张数": 们.size(), "明细": 们}
