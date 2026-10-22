## 战术牌构筑（3 选 1）——原生 Godot，**零 `J.*`**。
##
## 逐字对齐封存 JS 参考版 `src/js/90-肉鸽-2-招募券与晋升.js` 的两条口子
## （接口登记 = `协作/接口约定.md` §26.2）：
##   · `候选战术牌们(RUN, 机体键, 数量 = 3)`：从「职业牌 + 势力牌 + 角色牌」三层池里剔除
##     已在 `RUN.战术牌库` 的牌，**优先各层取 1 张**（顺序：职业 → 势力 → 角色），再按
##     职业池 → 势力池 → 角色池 的顺序补齐到最多 `count` 张。**纯函数 + 0 次随机数调用**。
##   · `选战术牌(RUN, cardId)`：把选中的牌并入 `RUN.战术牌库`（去重）并清空 `RUN.待选战术牌`。
##
## ★ DECK-4（肉鸽双轨成长）：
##   · **上排（单机专属牌库）**：跟着机体晋升 Lv10 → Lv20 → Lv30 解锁 ——
##     `unit_exclusive_cards(unit_key, lv, ctx)` 是**纯函数**（只看键与等级），
##     `RosterManager.promote` 把它写进返回字典的一栏 `解锁专属牌`，
##     **绝不往 `state.roster[k]` 里多塞键**（那三个键 `key / lv / hpRatio` 是存档契约）。
##   · **下排（全队公有牌池）**：战后三选一 + 黑市买牌 / 删牌只碰 `state.tactical_deck` 里的
##     公有牌（`层级` = 职业 / 势力 / 统帅）。带 `public_only` 的三选一只出公有牌。
class_name DeckBuilder
extends RefCounted

## 专属牌按等级解锁：Lv10 带基础牌，Lv20 解锁第 2 张，Lv30 解锁第 3 张（第 4 张起一律 Lv30）。
const 解锁等级们 := [10, 20, 30]
## 晋升带来的「卡牌威力倍率」（Lv10 → 1.0 / Lv20 → 1.2 / Lv30 → 1.4）
const 等级倍率表 := {10: 1.0, 20: 1.2, 30: 1.4}
## 响介 / 艾克赛琳 / 拉米亚：专属牌分两路装填（本文件的候选 + `AtxThree.装填单位`）。
const ATX三小强 := ["A1", "A2", "A3"]

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

# ======================== DECK-4：上排（专属牌库）========================
static func 等级倍率(lv: int) -> float:
	if lv >= 30:
		return float(等级倍率表.get(30, 1.4))
	if lv >= 20:
		return float(等级倍率表.get(20, 1.2))
	return float(等级倍率表.get(10, 1.0))

## 这张牌算不算「这台机体的专属牌」（角色牌：`归属` / `角色` / `角色们` 三种认法）
static func _卡属于单位(c: Dictionary, 键: String) -> bool:
	if 键.is_empty():
		return false
	if String(c.get("归属", "")) == 键 or String(c.get("角色", "")) == 键:
		return true
	var 角色们: Variant = c.get("角色们")
	return 角色们 is Array and (角色们 as Array).has(键)

## 这台机体**全部**候选专属牌（不按等级裁）。来源两处：
##   ① 数据库 `战术卡牌表` 的角色牌（老口径）；② ATX v0.2 卡表。
## `ctx == null` = 不按开关裁剪（晋升预览 / 测试要看到「将来会解锁什么」）。
static func _专属候选(unit_key: String, ctx: Variant) -> Array:
	var 出: Array = []
	var 已收 := {}
	var 表: Array = Db.catalog.cards()
	for c in 表:
		if c is Dictionary and _卡属于单位(c, unit_key) and not 已收.has(String(c.get("id", ""))):
			已收[String(c.get("id", ""))] = true
			出.append({"卡": c, "来源": "数据"})
	# ★ A6d：主开关开着时，与 v0.1 卡表**同名**的 v0.2 旧角色牌**退出牌池**
	#   （同一角色同一张牌只留 v0.1 版）；`ctx == null`（晋升预览 / 旧断言）不过滤。
	for c in FacAtx.角色专属牌们(unit_key, ctx):
		if not 已收.has(String(c.get("id", ""))):
			已收[String(c.get("id", ""))] = true
			出.append({"卡": c, "来源": "ATXv02"})
	return 出

## 候选排序（确定性，纯函数）：**开局在手的先**（基础主武器 / 初始角色牌）→ 耗气升序 → id。
## 返回 true = `a` 排在 `b` 前面（`sort_custom` 的比较器口径）。
static func _候选档(a: Dictionary, b: Dictionary) -> bool:
	var ca: Dictionary = a.get("卡", {})
	var cb: Dictionary = b.get("卡", {})
	var sa := 0 if _是开局在手(ca) else 1
	var sb := 0 if _是开局在手(cb) else 1
	if sa != sb:
		return sa < sb
	var 耗a := float(ca.get("耗气", 0.0))
	var 耗b := float(cb.get("耗气", 0.0))
	if 耗a != 耗b:
		return 耗a < 耗b
	return String(ca.get("id", "")) < String(cb.get("id", ""))

static func _是开局在手(c: Dictionary) -> bool:
	var 条件: Variant = c.get("触发条件")
	if 条件 is Dictionary and String((条件 as Dictionary).get("类型", "")) == "开局在手":
		return true
	return String(c.get("入牌", "")) == "初始"

## ★ DECK-4：这台机体在 `lv` 这一级解锁的**全部**专属牌（纯函数：只看 `unit_key` 与 `lv`）。
## 返回 `[{卡, id, 名, 卡类, 来源, 等级需求, 倍率}]`：
##   · `等级需求` = 该牌排到的解锁档（10 / 20 / 30；第 4 张起封顶 30）；
##   · `倍率`     = `等级倍率(lv)` —— 晋升会**提升全部**已解锁专属牌的威力倍率。
static func unit_exclusive_cards(unit_key: String, lv: int, ctx: Variant = null) -> Array:
	# ★ MITH3-3：秘银 v0.3 开着 → 直接用 v0.3 卡表自己的 `等级需求`（初始 10 / 剧情 20 / 肉鸽 30），
	#   不再按「排到第几张」硬分档（那一套会把 λ 驱动·启动 排到 Lv10 或 Lv30 上去）。
	# ★ A7：这张表**只接管秘银成员**。非秘银机体（ATX 五人 / 混编）在 v0.3 卡表里查不到牌 →
	#   落到下面的通用候选（ATX v0.2 角色牌 + A6c 的 v0.1 卡表），否则「快速测试：ATX 五人」里
	#   塔斯克 / 雷欧娜的专属牌库会是**空的**（秘银v03 由菜单入口一路开着）。
	if ctx != null:
		var v3 := _v03专属牌(unit_key, lv)
		if not v3.is_empty():
			return v3
	var 出 := _按档分片(unit_key, lv, ctx)
	# ★ 闸门 G2：局外晋升预览要报「战斗里真正会发的牌」—— 三小强的上排还有 `AtxThree` 那一路。
	if ctx == null and ATX三小强.has(unit_key):
		_补ATX三小强(出, unit_key, lv)
	return 出

## 候选排序后：「开局在手」的牌 Lv10 就发，其余按「排到第几张」硬分档（`解锁等级们`）—— 战斗与局外同一份。
static func _按档分片(unit_key: String, lv: int, ctx: Variant) -> Array:
	var 候选 := _专属候选(unit_key, ctx)
	候选 = JsCompat.stable_sort(候选, func(a, b): return _候选档(a, b))
	var 出: Array = []
	var 倍 := 等级倍率(lv)
	var 排位 := 0
	for i in 候选.size():
		var c: Dictionary = 候选[i].get("卡", {})
		# 标了「开局在手」的牌按设计是初始牌，Lv10 就发；只有没标的牌才按排位逐档解锁。
		var 档: int = int(解锁等级们[0])
		if not _是开局在手(c):
			档 = int(解锁等级们[mini(排位, 解锁等级们.size() - 1)])
			排位 += 1
		if lv < 档:
			continue
		出.append({
			"卡": c, "id": String(c.get("id", "")), "名": String(c.get("名", "")),
			"卡类": String(c.get("卡类", "专属精神牌")), "来源": String(候选[i].get("来源", "")),
			"等级需求": 档, "倍率": 倍,
		})
	return 出

## 三小强的牌库除了上面那份候选，`Setup.初始化单机牌组` 还会在末尾追加 `AtxThree.装填单位`
## （= `AtxThree.开局牌库`，肉鸽局只发「初始」档、与等级无关，所以每张都算 Lv10 就发）。
## 这里照装填那一路把同一批补进晋升预览；id 重复的跳过（战斗里也是按 id 去重）。
## 倍率写 1.0：这一路在战斗里**不乘**等级倍率，多写 1.4 会让预览说假话。
static func _补ATX三小强(出: Array, unit_key: String, lv: int) -> void:
	var 已有 := {}
	for x in 出:
		已有[String((x as Dictionary).get("id", ""))] = true
	for c in AtxThree.开局牌库(unit_key, lv, {"选项": {"单机牌组": true}}):
		var id := String((c as Dictionary).get("id", ""))
		if 已有.has(id):
			continue
		已有[id] = true
		出.append({
			"卡": c, "id": id, "名": String((c as Dictionary).get("名", "")),
			"卡类": String((c as Dictionary).get("卡类", "专属精神牌")), "来源": "AtxThree",
			"等级需求": 10, "倍率": 1.0,
		})

## 只报「这一次晋升**新解锁**的那几张」（Lv10 → Lv20 只报 Lv20 档；预览 / 结算都读它）。
static func 新解锁专属牌(unit_key: String, lv: int, ctx: Variant = null) -> Array:
	return unit_exclusive_cards(unit_key, lv, ctx).filter(func(x): return int(x.get("等级需求", 0)) == lv)

## ★ MITH3-3：v0.3 的专属牌解锁 —— 一张牌的 `等级需求` 写在牌面上（初始 10 / 剧情 20 / 肉鸽 30），
## 威力倍率仍按 Lv10 → 1.0 / Lv20 → 1.2 / Lv30 → 1.4 抬（与既有双轨成长同一口径）。
static func _v03专属牌(unit_key: String, lv: int) -> Array:
	var 出: Array = []
	var 倍 := 等级倍率(lv)
	for c in MithrilV03Cards.角色专属牌们按等级(unit_key, lv):
		出.append({
			"卡": c, "id": String(c.get("id", "")), "名": String(c.get("名", "")),
			"卡类": String(c.get("卡类", "专属精神牌")), "来源": "秘银v03",
			"等级需求": int(c.get("等级需求", 10)), "倍率": 倍,
		})
	return 出

## 把 `倍率` 乘进这张牌的威力字段（`效果` 里所有以「威力」结尾的数值 + 顶层 `威力`）。
## 返回**新的**字典（原牌表一个字节都不动；`效果` 也深拷贝过）。
static func 应用等级倍率(card: Dictionary, 倍: float) -> Dictionary:
	var 出 := card.duplicate(true)
	出["等级倍率"] = 倍
	if 出.get("威力") is int or 出.get("威力") is float:
		出["威力"] = float(出["威力"]) * 倍
	缩放威力(出.get("效果"), 倍)
	return 出

static func 缩放威力(节点: Variant, 倍: float) -> void:
	if 节点 is Array:
		for x in (节点 as Array):
			缩放威力(x, 倍)
		return
	if not (节点 is Dictionary):
		return
	var d: Dictionary = 节点
	for k in d.keys():
		var v: Variant = d[k]
		var 键 := String(k)
		if (v is int or v is float) and 键.ends_with("威力"):
			d[k] = float(v) * 倍
		elif v is Array or v is Dictionary:
			缩放威力(v, 倍)

# ======================== DECK-4：下排（公有牌池）========================
## 这张牌是不是**公有牌**（`层级` = 职业 / 势力 / 统帅）—— 角色牌不在其列（上排专属）。
static func 是公有牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return ["职业", "势力", "统帅"].has(String(c.get("层级", "")))

## 势力扩展卡表里的公有牌（秘银 v0.2 的 9 张 + ATX v0.2 的 9 张）。
## 场上**没有**该势力的成员时也不装（那些牌对全队都打不出去）。
##
## ★ M2（试玩反馈修复）：卡牌流转开着时，**职业分类牌**还要按本队在场职业再过滤一道 ——
##   秘银五人没有重装 → 不塞「铁壁〔需：重装〕」这种永远打不出的牌；`层级 = 势力` 的新版势力牌
##   同理按在场势力过滤（没有 ATX 成员的队伍不装 ATX 势力牌）。过滤口径与 `Setup._公有牌入池吗`
##   同一份（`Setup._在场职业与势力`），不在两处各写一套。
static func 公有扩展牌们(ctx: Variant = null) -> Array:
	var 出: Array = []
	var 在: Array = []
	if ctx is Dictionary:
		for u in (ctx as Dictionary).get("allies", []):
			if u is Dictionary:
				在.append(String(u.get("key", "")))
	var 场: Variant = Setup._在场职业与势力(ctx) if ctx is Dictionary else null
	var 过滤 := ctx is Dictionary and 场 is Dictionary
	# ★ MITH3-3：秘银 v0.3 的 9 张势力牌 + 18 张职业分类牌
	if ctx == null or _有成员(在, MithrilV03Cards.成员键):
		for c in MithrilV03Cards.势力牌们():
			if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
				continue
			出.append(c)
	for c in MithrilV03Cards.职业牌们():
		if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
			continue
		出.append(c)
	if ctx == null or _有成员(在, FacAtx.成员键):
		for c in FacAtx.公有牌们():
			# ★ A6b / M2：秘银 v0.3 队伍不装 ATX 势力牌（`_公有牌入池吗` 按在场势力判）
			if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
				continue
			出.append(c)
	# ★ A6a：三套职业分类牌 18 张（近卫 / 尖兵 / 重装）—— 公有排、按职业限制、谁打出扣谁的战意。
	for c in ClassCards.职业牌们():
		# ★ M2：没有这个职业的机体 → 这张分类牌永远打不出去，不装
		if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
			continue
		出.append(c)
	# 第 7 职业【维修】6 张分类牌 —— 队里没有维修机体时一张都不装（同一份过滤口径）。
	for c in RepairCards.职业牌们():
		if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
			continue
		出.append(c)
	# ★ CB-1：天人势力牌 9 张（`层级 = 势力` / `归属 = 天人` / 只有天人成员能打）——
	#   挂 `Params.单机牌组_开(ctx)`，且队里没有天人成员时一张都不加
	#   （`_公有牌入池吗` 按在场势力再过滤一次，与秘银 / ATX 同一份口径）。
	if ctx == null or CelestialV01.开(ctx):
		if ctx == null or _有成员(在, CelestialV01.成员键):
			for c in CelestialV01.势力牌们():
				if 过滤 and not Setup._公有牌入池吗(ctx, c, 场):
					continue
				出.append(c)
	# 势力扩展卡表的统一出口：模块自己判「队里有没有我的人」并把牌交回来（内核不点名模块）。
	出.append_array(RuleHooks.收集("公有扩展牌", [ctx]))
	return 出

static func _有成员(在场: Array, 成员键: Array) -> bool:
	for k in 成员键:
		if 在场.has(String(k)):
			return true
	return false

## 单机牌组模式（写在 `state.map_data["_rogue"]`，**不进 `to_dict()`**）→ 三选一只出公有牌。
static func 单机牌组模式(state: RunState) -> bool:
	if state == null:
		return false
	var 记: Variant = state.map_data.get("_rogue")
	return 记 is Dictionary and (记 as Dictionary).get("单机牌组") == true

## 从三层牌池里挑最多 `count` 张候选（**不消耗任何随机数**）。返回 id 数组。
## `public_only == true`（或这一局开了单机牌组）= 只出**公有牌**（职业 / 势力 / 统帅），
## 角色牌一律不出（那些属于机体上排专属牌库，跟着晋升成长）。
static func offer_cards(state: RunState, 机体键: String, count: int = 3, public_only: bool = false) -> Array:
	var 只看公有: bool = public_only or 单机牌组模式(state)
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
	var 统帅池 := []
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
		elif 层 == "角色" and not 只看公有 and 归 == String(info.get("键")):
			角色池.append(c)
		elif 层 == "统帅":
			统帅池.append(c)
	var 池序 := [职业池, 势力池, 竞争池(只看公有, 角色池, 统帅池)]
	var 平铺: Array = []
	for 池 in 池序:
		for c in 池:
			平铺.append(c)
	var 选出 := []
	var 已选 := {}
	for 池 in 池序:
		if not 池.is_empty():
			加一张(选出, 已选, 池[0], count)
	for c in 平铺:
		if 选出.size() >= count:
			break
		加一张(选出, 已选, c, count)
	state.pending_card_picks = 选出.duplicate()
	return 选出

## 公有牌模式下「第三层池」= 统帅牌；老口径下 = 角色牌（一个字节都不改）。
static func 竞争池(只看公有: bool, 角色池: Array, 统帅池: Array) -> Array:
	return 统帅池 if 只看公有 else 角色池

## 只出公有牌的三选一（下排 / 黑市口径）。
static func offer_public_cards(state: RunState, 机体键: String, count: int = 3) -> Array:
	return offer_cards(state, 机体键, count, true)

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
