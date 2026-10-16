## 战术牌构筑（3 选 1）——原生 Godot，**零 `J.*`**。
##
## 逐字对齐封存 JS 参考版 `src/js/90-肉鸽-2-招募券与晋升.js` 的两条口子
## （接口登记 = `协作/接口约定.md` §26.2）：
##   · `候选战术牌们(RUN, 机体键, 数量 = 3)`：从「职业牌 + 势力牌 + 角色牌」三层池里剔除
##     已在 `RUN.战术牌库` 的牌，**优先各层取 1 张**（顺序：职业 → 势力 → 角色），再按
##     职业池 → 势力池 → 角色池 的顺序补齐到最多 `count` 张。**纯函数 + 0 次随机数调用**。
##   · `选战术牌(RUN, cardId)`：把选中的牌并入 `RUN.战术牌库`（去重）并清空 `RUN.待选战术牌`。
class_name DeckBuilder
extends RefCounted

static func 全表() -> Array:
	return Db.catalog.cards()

static func 找到(card_id: String) -> Dictionary:
	return Db.catalog.card(card_id)

static func 键们() -> Array:
	var 出 := []
	for c in 全表():
		if c is Dictionary and c.get("id") != null:
			出.append(String(c["id"]))
	return 出

## 从三层牌池里挑最多 `count` 张候选（**不消耗任何随机数**）。返回 id 数组。
static func offer_cards(state: RunState, 机体键: String, count: int = 3) -> Array:
	var 已有 := {}
	for x in state.tactical_deck:
		if x is String:
			已有[String(x)] = true
		elif x is Dictionary and x.get("id") != null:
			已有[String(x["id"])] = true
	var info := Btl.提取单位三层信息(机体键)
	var 表 := 全表()
	var 职业池 := []
	var 势力池 := []
	var 角色池 := []
	for c in 表:
		if not (c is Dictionary):
			continue
		var 层 := String(c.get("层级"))
		var 归 := String(c.get("归属"))
		var id := String(c.get("id"))
		if 已有.has(id):
			continue
		if 层 == "职业" and 归 == String(info.get("职业")):
			职业池.append(c)
		elif 层 == "势力" and 归 == String(info.get("势力")):
			势力池.append(c)
		elif 层 == "角色" and 归 == String(info.get("键")):
			角色池.append(c)
	var 选出 := []
	var 已选 := {}
	for 池 in [职业池, 势力池, 角色池]:
		if not 池.is_empty():
			加一张(选出, 已选, 池[0], count)
	for 池 in [职业池, 势力池, 角色池]:
		for c in 池:
			if 选出.size() >= count:
				break
			加一张(选出, 已选, c, count)
	state.pending_card_picks = 选出.duplicate()
	return 选出

static func 加一张(选出: Array, 已选: Dictionary, c: Dictionary, count: int) -> void:
	if 选出.size() >= count:
		return
	var id := String(c.get("id"))
	if 已选.has(id):
		return
	已选[id] = true
	选出.append(id)

## 把选中的卡并入牌库并清空待选（去重）。卡 id / 卡名都认。
static func select_card(state: RunState, card_id: String) -> bool:
	if state == null or card_id.is_empty():
		return false
	var id := card_id
	if 找到(card_id).is_empty():
		var found := ""
		for c in 全表():
			if c is Dictionary and String(c.get("名")) == card_id:
				found = String(c.get("id"))
				break
		if found.is_empty():
			return false
		id = found
	if not state.tactical_deck.has(id):
		state.tactical_deck.append(id)
	state.pending_card_picks = []
	return true

## 别名（与 JS 名字一致的调用点用这个）。
static func 候选战术牌们(state: RunState, 机体键: String, count: int = 3) -> Array:
	return offer_cards(state, 机体键, count)

static func 选战术牌(state: RunState, card_id: String) -> bool:
	return select_card(state, card_id)
