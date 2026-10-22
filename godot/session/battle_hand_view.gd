## 会话门面的「五之三 单机牌组」上半 —— 选机体、上排 / 下排、公有牌判定与卡面行。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionBattleHandView
extends RefCounted

static func _目标原文(session: GameSession, c: Dictionary) -> String:
	return str((c as Dictionary).get("目标", "")) if c is Dictionary else ""

static func _武器是修理(session: GameSession, w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	return Reach.isHealKind(Reach.rangeKindOf(w))

## 卡上的武器威力（没有武器 = 0）
static func _武器威力Of(session: GameSession, c: Variant) -> float:
	if not (c is Dictionary):
		return 0.0
	var w: Variant = (c as Dictionary).get("武器")
	if not (w is Dictionary):
		return 0.0
	var x: Variant = (w as Dictionary).get("威力")
	if x == null:
		x = (w as Dictionary).get("power")
	return _读数(session, x)

## 卡上的武器段数（没有武器 / 没写 = 1）
static func _武器段数Of(session: GameSession, c: Variant) -> float:
	if not (c is Dictionary):
		return 1.0
	var w: Variant = (c as Dictionary).get("武器")
	if not (w is Dictionary):
		return 1.0
	var x: Variant = (w as Dictionary).get("段数")
	if x == null:
		x = (w as Dictionary).get("hits")
	if x == null:
		return 1.0
	return maxf(1.0, _读数(session, x))

static func 卡目标方(session: GameSession, c: Dictionary, 区: String = "", 是修理: bool = false) -> String:
	return CardPlay.目标方(c, 区, 是修理)

static func 单机牌组开(session: GameSession) -> bool:
	return not session.battle_ctx.is_empty()

static func deck_mode_active(session: GameSession) -> bool:
	return 单机牌组开(session)

## 开战时自动选中「格位 0 起第一台存活的我方」
static func _选中默认机体(session: GameSession) -> String:
	session.selected_unit_id = ""
	if session.battle_ctx.is_empty():
		return ""
	var 我: Variant = session.battle_ctx.get("allies")
	if not (我 is Array):
		return ""
	var 最小位 := 9999
	var 键 := ""
	for x in (我 as Array):
		if not (x is Dictionary) or float((x as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 位 := int(float((x as Dictionary).get("slot", 9999.0)))
		if 位 < 最小位:
			最小位 = 位
			键 = str((x as Dictionary).get("key", ""))
	session.selected_unit_id = 键
	return 键

## 我方单位（只认 ally
static func _找我方单位(session: GameSession, unit_id: String) -> Dictionary:
	if session.battle_ctx.is_empty() or unit_id.is_empty():
		return {}
	var 池: Variant = session.battle_ctx.get("allies")
	if not (池 is Array):
		return {}
	for x in (池 as Array):
		if not (x is Dictionary):
			continue
		if str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id:
			return x
	return {}

static func _选中单位(session: GameSession, unit_id: String = "") -> Dictionary:
	var 键 := unit_id if not unit_id.is_empty() else session.selected_unit_id
	if 键.is_empty():
		return {}
	return _找我方单位(session, 键)

static func select_battle_unit(session: GameSession, unit_id: String) -> Dictionary:
	return session._record_action("select_battle_unit", {"unit_id": unit_id}, _点选机体(session, unit_id))

static func 点选机体(session: GameSession, unit_id: String) -> Dictionary:
	return select_battle_unit(session, unit_id)

static func _点选机体(session: GameSession, unit_id: String) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	var u := _找我方单位(session, unit_id)
	if u.is_empty():
		return session._fail("我方没有这台机体（%s）" % unit_id, {"ok": false, "单位": unit_id})
	if float(u.get("hp", 0.0)) <= 0.0:
# 倒下的机体不许选中（没有牌可打），但把原因说清楚
		return session._fail("%s 已经倒下，选不了（换一台活着的）" % str(u.get("name", unit_id)),
			{"ok": false, "单位": unit_id})
	session.selected_unit_id = str(u.get("key", unit_id))
	session.last = {"行动": "点选机体", "单位": session.selected_unit_id, "名": str(u.get("name", "")),
		"职业": str(Units.unit_class(u, session.battle_ctx)), "势力": str(Fac.势力名(u)),
		"战意": Btl.战意(u), "上排": upper_hand_cards(session).size(), "下排": lower_hand_cards(session).size()}
	session._emit()
	return {"ok": true, "选中": session.selected_unit_id, "名": str(u.get("name", "")),
		"战意": Btl.战意(u), "上排": upper_hand_cards(session).size(), "下排": lower_hand_cards(session).size()}

## 当前选中机体的展示快照（纯读
static func selected_unit_view(session: GameSession) -> Dictionary:
	if session.selected_unit_id.is_empty():
		return {}
	return session.unit_view("ally", session.selected_unit_id)

static func selected_unit(session: GameSession) -> String:
	return session.selected_unit_id

## 上排三区（DECK-3 §2）
static func upper_hand_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	var u := _选中单位(session, unit_id)
	if u.is_empty():
		return 出
	if session.v03_active():
		var 武栏 := session.weapon_bar_cards(unit_id)
		if not 武栏.is_empty():
			出.append_array(武栏)
		elif u.get("weapons") is Array:
			for e in (u.weapons as Array):
				if not (e is Dictionary) or not ((e as Dictionary).get("t") is Dictionary):
					continue
				var w0: Dictionary = (e as Dictionary).t
				if str(w0.get("卡类", "")) == GameSession.单机区_衍生 or not Calc.weaponPlayable(w0):
					continue
				出.append(_武器牌视图(session, u, e, w0))
		出.append_array(session.sub_weapon_cards(unit_id))
		出.append_array(session.ultimate_slots(unit_id))
		出.append_array(session.spirit_hand_cards(unit_id))
		出.append_array(衍生视图们(session, u))
		return 出
	if u.get("weapons") is Array:
		for e in (u.weapons as Array):
			if not (e is Dictionary) or not ((e as Dictionary).get("t") is Dictionary):
				continue
			var w: Dictionary = (e as Dictionary).t
			if str(w.get("卡类", "")) == GameSession.单机区_衍生:
				continue
			if not Calc.weaponPlayable(w):
				continue   # 被动 / 不能主动打出的武器不算「手牌」
			出.append(_武器牌视图(session, u, e, w))
	if u.get("专属手牌") is Array:
		for c in (u.专属手牌 as Array):
			if not (c is Dictionary):
				continue
			if str((c as Dictionary).get("卡类", "")) == GameSession.单机区_主武器:
				出.append(_专属牌视图(session, u, c, GameSession.单机区_主武器))
# ---- ② 衍生攻击卡（不毁主武）----
	if u.get("衍生手牌") is Array:
		for c in (u.衍生手牌 as Array):
			if c is Dictionary and not _衍生该跳过(session, u, c):
				出.append(_专属牌视图(session, u, c, GameSession.单机区_衍生))
# ---- ③ 专属精神牌（不限张数，够战意就能打）----
	if u.get("专属手牌") is Array:
		for c in (u.专属手牌 as Array):
			if not (c is Dictionary):
				continue
			if str((c as Dictionary).get("卡类", "")) == GameSession.单机区_主武器:
				continue
			if Btl.是衍生攻击卡(c):
				continue
			出.append(_专属牌视图(session, u, c, GameSession.单机区_精神))
	return 出

static func 衍生视图们(session: GameSession, u: Dictionary) -> Array:
	var 出: Array = []
	for c in (u.get("衍生手牌") as Array) if u.get("衍生手牌") is Array else []:
		if c is Dictionary and not _衍生该跳过(session, u, c):
			出.append(_专属牌视图(session, u, c, GameSession.单机区_衍生))
	for c in (session.battle_ctx.get("公有手牌") as Array) if session.battle_ctx.get("公有手牌") is Array else []:
		if c is Dictionary and Btl.是衍生攻击卡(c):
			出.append(_公有牌视图(session, u, c))
	return 出

## ★ 2026-10-21（任务单问题 1）：衍生手牌里的旧版【援护射击】在卡牌流转开着、
static func _衍生该跳过(_session: GameSession, u: Dictionary, c: Dictionary) -> bool:
	if str(c.get("名", "")) != "援护射击":
		return false
	var 栏 = u.get("副武器栏")
	if not (栏 is Array):
		return false
	for e in (栏 as Array):
		if not (e is Dictionary):
			continue
		var 卡 = (e as Dictionary).get("卡")
		if 卡 is Dictionary and str((卡 as Dictionary).get("名", "")) == "援护射击":
			return true
	return false

## 一张「常驻武器卡」的视图
static func _武器牌视图(session: GameSession, u: Dictionary, entry: Dictionary, w: Dictionary) -> Dictionary:
	var 名 := str(w.get("name", ""))
	var 费 := Btl.战意费用(w)
	var 原因 := ""
	var 可打 := true
	if _真(session, u.get("主武器已销毁")):
		可打 = false
		原因 = "本回合主武器卡已销毁（下回合初回手）"
	elif entry.get("uses") != null and float(entry.uses) <= 0.0:
		可打 = false
		原因 = "使用次数已用尽"
	elif _读数(session, entry.get("cd")) > 0.0:
		可打 = false
		原因 = "冷却中"
	elif _读数(session, u.get("lv", 1.0)) < _读数(session, Params.残月武器运行期解锁(w)):
		可打 = false
		原因 = "等级不够"
	elif _读数(session, entry.get("readyTurn")) > float(session.battle_ctx.get("turn", 1.0)):
		可打 = false
		原因 = "还没到解锁回合"
	elif Btl.战意(u) < 费:
		可打 = false
		原因 = "战意不足"
	else:
		原因 = "点击发动"
	return {
		"区": GameSession.单机区_主武器, "手牌键": 名, "名": 名, "武器名": 名, "卡类": GameSession.单机区_主武器,
		"战意": 费, "耗气": 费, "冷却": _读数(session, entry.get("cd")),
		"剩余": (int(_读数(session, entry.get("uses"))) if entry.get("uses") != null else -1),
		"可打": 可打, "原因": 原因, "描述": str(w.get("desc", "")),
		"单机牌组_铁壁": _真(session, w.get("单机牌组_铁壁")),
		"是修理": Reach.isHealKind(Reach.rangeKindOf(w)),
# ★ UI-1：卡面第三行的「威力 / 段数」（卡片很窄，这两项让玩家一眼看清打多少）
		"威力": _武器威力Of(session, w), "段数": _武器段数Of(session, w),
# ★ P3-2：卡面 `目标` 原文 + 统一的 `目标方`（修理 → 友方、其余攻击武器 → 敌方）
		"目标": _目标原文(session, w),
		"目标方": CardPlay.目标方(w, GameSession.单机区_主武器, Reach.isHealKind(Reach.rangeKindOf(w))),
	}

## 数字读法（门面里**不许出现 `J.*`** 
static func _读数(session: GameSession, v: Variant) -> float:
	if v is int or v is float:
		return float(v)
	return 0.0

static func _真(session: GameSession, v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return not (v as String).is_empty()
	return true

static func pending_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	if session.battle_ctx.is_empty():
		return 出
	var u := _选中单位(session, unit_id)
	var 条们: Array = []
	if u.get("待入库") is Array:
		for c in (u.待入库 as Array):
			if c is Dictionary:
				条们.append({"卡": c, "公有": false})
	if not u.is_empty() and session.battle_ctx.get("公有待入库") is Array:
		for c in (session.battle_ctx.公有待入库 as Array):
			if c is Dictionary:
				条们.append({"卡": c, "公有": true})
	for e in 条们:
		var c: Dictionary = (e as Dictionary).卡
		var 条: Variant = DeckFlow.入库条件Of(c)
		var 因 := "入库条件未满足"
		if 条 is Dictionary:
			因 = str((条 as Dictionary).get("说明", 因))
		出.append({
			"区": "待入库", "手牌键": str(c.get("id", "")), "id": str(c.get("id", "")),
			"名": str(c.get("名", "")), "卡类": "待入库牌",
			"战意": Btl.战意费用(c), "耗气": Btl.战意费用(c), "可打": false, "原因": 因,
			"描述": str(c.get("效果说明", c.get("描述", ""))),
			"归属": str(c.get("归属", "")), "层级": str(c.get("层级", "")),
			"公有": bool((e as Dictionary).公有), "入库条件": (条 if 条 is Dictionary else null),
		})
	return 出

## 一张「上排卡牌」（大招牌 / 衍生 / 精神）的视图
static func _专属牌视图(session: GameSession, u: Dictionary, c: Dictionary, 区: String) -> Dictionary:
	var 费 := Btl.战意费用(c)
	var 因 := CardPlay.不可打原因(session.battle_ctx, u, c, 区) if not u.is_empty() else "没有选中我方机体"
	var 可打 := 因 == ""
	var 原因 := "点击发动" if 可打 else 因
	var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
	var id := str(c.get("id", ""))
# ★ P3-2：这张牌打谁（`区` 决定兜底口径；卡面 `目标` 优先）
	var 目标方 := CardPlay.目标方(c, 区, _武器是修理(session, c.get("武器")))
	return {
		"区": 区, "手牌键": (str(实例) if 实例 > 0 else id), "id": id, "实例号": 实例,
		"名": str(c.get("名", "")), "卡类": (区 if str(c.get("卡类", "")).is_empty() else str(c.get("卡类", ""))),
		"战意": 费, "耗气": 费, "可打": 可打, "原因": 原因,
		"描述": str(c.get("效果说明", c.get("描述", ""))),
		"归属": str(c.get("归属", "")), "种类": str(c.get("种类", "")),
		"目标": _目标原文(session, c), "目标方": 目标方,
		"是修理": _武器是修理(session, c.get("武器")),
		"威力": _武器威力Of(session, c), "段数": _武器段数Of(session, c),
		"是衍生": Btl.是衍生攻击卡(c),
		"单机牌组_铁壁": _真(session, c.get("单机牌组_铁壁")),
		"觉醒感应": _真(session, c.get("觉醒感应")),
		"亮金边": ColonialV01.该亮金边(u, c),
	}

## 下排（DECK-3 §2）
static func lower_hand_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	if session.battle_ctx.is_empty():
		return 出
	var 公: Variant = session.battle_ctx.get("公有手牌")
	if not (公 is Array):
		return 出
	var u := _选中单位(session, unit_id)
	for c in (公 as Array):
		if not (c is Dictionary):
			continue
		出.append(_公有牌视图(session, u, c))
	return 出

static func _这台能打公有牌(session: GameSession, u: Dictionary, c: Dictionary) -> bool:
	if not (c is Dictionary):
		return false
	return CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_公有) == ""

## ★ M2：这张下楼牌「现在由谁打得出来」
static func _找公有牌可打机体(session: GameSession, c: Dictionary, 首选: Dictionary = {}) -> Dictionary:
	if session.battle_ctx.is_empty() or not (c is Dictionary):
		return {}
	var 头 := 首选
	if 头.is_empty():
		头 = _选中单位(session, "")
	return CardPlay.找执行机体(session.battle_ctx, c, GameSession.单机区_公有, 头)

## 「点击发动」/「〔由 队友名 发动〕」
static func _发动原因(session: GameSession, u: Dictionary, 机: Dictionary) -> String:
	if u.is_empty() or 机.is_empty():
		return "点击发动"
	if str(机.get("key", "")) == str(u.get("key", "")):
		return "点击发动"
	return "〔由 %s 发动〕" % str(机.get("name", "队友"))

## ★ M2：`card_inst_id` 指的是不是 `ctx.公有手牌` 里的牌（是 → 返回那张牌
static func _公有手牌里的牌(session: GameSession, card_inst_id: String) -> Dictionary:
	if session.battle_ctx.is_empty() or card_inst_id.is_empty():
		return {}
	var 手: Variant = session.battle_ctx.get("公有手牌")
	if not (手 is Array):
		return {}
	for c in (手 as Array):
		if not (c is Dictionary):
			continue
		var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
		if 实例 > 0 and str(实例) == card_inst_id:
			return c
		if str(c.get("id", "")) == card_inst_id or str(c.get("名", "")) == card_inst_id:
			return c
	return {}

## ★ M2：当前选中机体打不动这张下楼牌、但队内有对口的活人 → 返回那台队友（空字典 = 不用换）
static func _换给能打的队友(session: GameSession, u: Dictionary, card_inst_id: String) -> Dictionary:
	var 卡 := _公有手牌里的牌(session, card_inst_id)
	if 卡.is_empty():
		return {}
	if _这台能打公有牌(session, u, 卡):
		return {}
	var 机 := _找公有牌可打机体(session, 卡)
	if 机.is_empty():
		return {}
# 真的换人发动：选中同步到那台队友（否则打完上排还是旧机体的牌、下排的「由谁发动」也对不上）
	session.selected_unit_id = str(机.get("key", ""))
	return 机

static func _公有牌判定(session: GameSession, u: Dictionary, c: Dictionary) -> Dictionary:
	var 机 := _找公有牌可打机体(session, c, u)
	if not 机.is_empty():
		return {"可打": true, "原因": _发动原因(session, u, 机), "机体": 机}
# ---- 打不出来：给出**最贴近玩家**的那一条原因 ----
	if str(c.get("种类", "")) == "连携":
		return {"可打": false, "原因": "〔需：秘银成员〕", "机体": {}}
	if AtxChips.是筹码牌(c):
		if u.is_empty():
			return {"可打": false, "原因": "没有选中我方机体", "机体": {}}
		return {"可打": false, "原因": CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_筹码), "机体": {}}
	if not u.is_empty() and not Btl.身份对口(u, c, session.battle_ctx):
		var 归 := str(c.get("归属", ""))
		return {"可打": false, "原因": "〔需：%s〕" % (归 if not 归.is_empty() else str(c.get("层级", ""))), "机体": {}}
	if u.is_empty():
		return {"可打": false, "原因": "战意不足", "机体": {}}
	return {"可打": false, "原因": CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_公有), "机体": {}}

static func _公有牌视图(session: GameSession, u: Dictionary, c: Dictionary) -> Dictionary:
	var 原费 := Btl.战意费用(c)
# ★ M2：`可打` 不再只看当前选中机体 —— 队内有对口且战意够的活人就能打（自动换人发动）
	var 判 := _公有牌判定(session, u, c)
	var 可打 := bool(判.get("可打", false))
	var 原因 := str(判.get("原因", ""))
	var 主机: Dictionary = 判.get("机体", {}) if 判.get("机体") is Dictionary else {}
	var 算价: Dictionary = 主机 if not 主机.is_empty() else u
	var 减 := 0.0
	if (not 算价.is_empty()) and str(Units.unit_class(算价, session.battle_ctx)) == "指挥":
		减 = Params.指挥公有减费()
	var 费 := maxf(0.0, 原费 - 减)
	var 对口 := true
	if not u.is_empty():
		对口 = Btl.身份对口(u, c, session.battle_ctx)
	var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
	var id := str(c.get("id", ""))
# ★ MITH3-4：连携牌在下排单独一个区（0 费、只有秘银成员能打、不占主武器）
	var 连携 := str(c.get("种类", "")) == "连携"
	var 区名 := "连携牌" if 连携 else GameSession.单机区_公有
	var 筹码 := AtxChips.是筹码牌(c)
	if 筹码:
		区名 = GameSession.单机区_筹码
		费 = 0.0
		原费 = 0.0
		减 = 0.0
	return {
		"区": 区名, "手牌键": (str(实例) if 实例 > 0 else id), "id": id, "实例号": 实例,
		"名": str(c.get("名", "")), "层级": str(c.get("层级", "")), "归属": str(c.get("归属", "")),
		"卡类": str(c.get("卡类", GameSession.单机区_公有)), "是衍生": Btl.是衍生攻击卡(c),
		"原费": 原费, "费": 费, "减费": 减, "战意": 费, "对口": 对口, "可打": 可打, "原因": 原因,
# ★ M2：实际发动者（不一定是当前选中机体）
		"发动键": str(主机.get("key", "")), "发动名": str(主机.get("name", "")),
		"由队友发动": 可打 and not 主机.is_empty() and str(主机.get("key", "")) != str(u.get("key", "")),
		"描述": str(c.get("效果说明", "")), "连携": 连携,
		"连携等级": int(c.get("连携等级", 0)), "连携就绪": 连携 and DeckFlow.连携就绪(session.battle_ctx, c),
		"筹码": 筹码, "筹码等级": int(c.get("筹码等级", 0)),
		"筹码目标": str(c.get("目标", "")),
		"是修理": false, "单机牌组_铁壁": false,
		"目标": _目标原文(session, c),
		"目标方": CardPlay.目标方(c, 区名, _武器是修理(session, c.get("武器"))),
# ★ COL-4b：哪张牌带【觉醒感应】、现在要不要亮金边（判据在 `ColonialV01.该亮金边`）。
		"觉醒感应": _真(session, c.get("觉醒感应")),
		"亮金边": ColonialV01.该亮金边(算价, c),
# ★ UI-1：卡面第三行的「威力 / 段数」（公有 Buff 牌 = 0，表现层就不写这一段）
		"威力": _武器威力Of(session, c), "段数": _武器段数Of(session, c),
	}
