## 会话门面的「五之三 单机牌组」下半 —— 四区域视图与徽章、武器栏 / 大招槽 / 牌库计数、出牌命令、回合结束与意图。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionBattleDeckView
extends RefCounted

static func v03_active(session: GameSession) -> bool:
	return not session.battle_ctx.is_empty()

static func 卡牌流转开(session: GameSession) -> bool:
	return v03_active(session)

## (1) 武器栏（常驻上排）：主武器卡
static func weapon_bar_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	var u := session._选中单位(unit_id)
	if u.is_empty() or not v03_active(session):
		return 出
	for c in (u.get("武器栏") as Array) if u.get("武器栏") is Array else []:
		if not (c is Dictionary):
			continue
		var 原因 := CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_主武器)
		出.append({
			"区": GameSession.单机区_主武器, "手牌键": str((c as Dictionary).get("id", "")),
			"id": str((c as Dictionary).get("id", "")), "名": str((c as Dictionary).get("名", "")),
			"卡类": GameSession.单机区_主武器, "武器名": str((c as Dictionary).get("名", "")),
			"战意": Btl.战意费用(c), "耗气": Btl.战意费用(c),
			"可打": 原因 == "", "原因": ("点击发动" if 原因 == "" else 原因),
			"描述": str((c as Dictionary).get("效果说明", "")),
			"距离": _距离文(session, c), "λ版": session._真((c as Dictionary).get("λ版")),
			"剩余": (int(session._读数((c as Dictionary).get("剩余次数"))) if (c as Dictionary).get("剩余次数") != null else -1),
			"武器类型": _武器类型文(session, c),
			"单机牌组_铁壁": false, "是修理": false, "是衍生": false,
# ★ P3-2：武器栏 = 攻击型主武器 → 目标方恒为「敌方」
			"目标": session._目标原文(c), "目标方": GameSession.目标方_敌方,
# ★ UI-1：卡面第三行的「威力 / 段数」
			"威力": session._武器威力Of(c), "段数": session._武器段数Of(c),
		})
	return 出

## (2) 副武器栏：不被主武器销毁、也不销毁主武器
static func sub_weapon_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	var u := session._选中单位(unit_id)
	if u.is_empty() or not v03_active(session):
		return 出
	for e in (u.get("副武器栏") as Array) if u.get("副武器栏") is Array else []:
		if not (e is Dictionary) or not ((e as Dictionary).get("卡") is Dictionary):
			continue
		var c: Dictionary = (e as Dictionary).卡
		var 原因 := CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_副武器)
		var 修 := session._武器是修理(c.get("武器"))
		出.append({
			"区": GameSession.单机区_副武器, "手牌键": str(c.get("id", "")), "id": str(c.get("id", "")),
			"名": str(c.get("名", "")), "卡类": GameSession.单机区_副武器,
			"战意": Btl.战意费用(c), "耗气": Btl.战意费用(c),
			"可打": 原因 == "", "原因": ("点击发动" if 原因 == "" else 原因),
			"已用": int((e as Dictionary).get("本回合已用", 0)),
			"可用": int((e as Dictionary).get("本回合可用", 1)),
			"描述": str(c.get("效果说明", "")), "距离": _距离文(session, c),
# ★ P3-2：副武器里的修理类 → 目标方「友方」，其余 → 「敌方」
			"是修理": 修, "目标": session._目标原文(c), "目标方": CardPlay.目标方(c, GameSession.单机区_副武器, 修),
# ★ UI-1：卡面第三行的「威力 / 段数」
			"威力": session._武器威力Of(c), "段数": session._武器段数Of(c),
		})
	return 出

## (3) 大招槽（常驻、置灰时标明冷却或条件原因）
static func ultimate_slots(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	var u := session._选中单位(unit_id)
	if u.is_empty() or not v03_active(session):
		return 出
	for 槽 in (u.get("大招槽") as Array) if u.get("大招槽") is Array else []:
		if not (槽 is Dictionary):
			continue
		var c: Dictionary = (槽 as Dictionary).get("卡") if (槽 as Dictionary).get("卡") is Dictionary else {}
		var 原因 := CardPlay.不可打原因(session.battle_ctx, u, c, GameSession.单机区_大招槽)
		出.append({
			"区": GameSession.单机区_大招槽, "手牌键": str(c.get("id", "")), "id": str(c.get("id", "")),
			"名": str(c.get("名", "")), "卡类": GameSession.单机区_大招槽,
			"战意": Btl.战意费用(c), "耗气": Btl.战意费用(c),
			"可打": 原因 == "", "原因": ("点击发动" if 原因 == "" else 原因),
			"冷却": session._读数((槽 as Dictionary).get("cd")), "冷却上限": session._读数((槽 as Dictionary).get("cd_max")),
			"已解锁": session._真((槽 as Dictionary).get("已解锁")), "本回合已打": session._真((槽 as Dictionary).get("本回合已打")),
			"武器牌": session._真(c.get("武器牌")), "描述": str(c.get("效果说明", "")),
			"距离": _距离文(session, c),
# ★ P3-2：武器型大招 → 「敌方」；纯效果型（`Uruz 全员突击` 之类）→ 「无」（点一下就放）
			"目标": session._目标原文(c), "目标方": CardPlay.目标方(c, GameSession.单机区_大招槽, session._武器是修理(c.get("武器"))),
# ★ UI-1：卡面第三行的「威力 / 段数」
			"威力": session._武器威力Of(c), "段数": session._武器段数Of(c),
# ★ COL-4b：这一张要不要先弹 QTE 三档 / 要不要亮金边（判据都在 `ColonialV01`）。
			"QTE": ColonialV01.走QTE(c),
			"觉醒感应": session._真(c.get("觉醒感应")),
			"亮金边": ColonialV01.该亮金边(u, c),
		})
	return 出

static func spirit_hand_cards(session: GameSession, unit_id: String = "") -> Array:
	var 出: Array = []
	var u := session._选中单位(unit_id)
	if u.is_empty():
		return 出
	for c in (u.get("专属手牌") as Array) if u.get("专属手牌") is Array else []:
		if c is Dictionary:
			出.append(session._专属牌视图(u, c, GameSession.单机区_精神))
	return 出

static func 精神手牌(session: GameSession, unit_id: String = "") -> Array:
	return spirit_hand_cards(session, unit_id)

static func deck_counts(session: GameSession, unit_id: String = "") -> Dictionary:
	var u := session._选中单位(unit_id)
	if u.is_empty():
		return {"牌库": 0, "手牌": 0, "弃牌": 0, "待入库": 0, "手牌上限": 0}
	return {
		"牌库": (u.get("专属牌库") as Array).size() if u.get("专属牌库") is Array else 0,
		"手牌": (u.get("专属手牌") as Array).size() if u.get("专属手牌") is Array else 0,
		"弃牌": (u.get("专属弃牌堆") as Array).size() if u.get("专属弃牌堆") is Array else 0,
		"待入库": (u.get("待入库") as Array).size() if u.get("待入库") is Array else 0,
		"手牌上限": int(Params.专属手牌上限()) if Params.专属手牌上限() > 0.0 else 4,
		"公有手牌": (session.battle_ctx.get("公有手牌") as Array).size() if session.battle_ctx.get("公有手牌") is Array else 0,
		"公有上限": 6,
		"公有待入库": (session.battle_ctx.get("公有待入库") as Array).size() if session.battle_ctx.get("公有待入库") is Array else 0,
	}

static func link_library_state(session: GameSession) -> Dictionary:
	if not v03_active(session):
		return {"张数": 0, "一级": 0, "二级": 0, "三级": 0, "卡牌": [], "就绪": false, "文案": "未启用"}
	var 状 := DeckFlow.连携牌库状态(session.battle_ctx)
	状["文案"] = "连携牌库 一%d / 二%d / 三%d" % [int(状["一级"]), int(状["二级"]), int(状["三级"])]
	状["悬停"] = "连携牌库（%d 张）：%s" % [int(状["张数"]), "、".join(状["卡牌"])] if not (状["卡牌"] as Array).is_empty() else "连携牌库（空）"
	return 状

## ★ A7：**筹码牌库**徽章（ATX v0.3 · 小筹码 / 大筹码 / 头奖张数）
static func chip_library_state(session: GameSession) -> Dictionary:
	var 空 := {"张数": 0, "小": 0, "大": 0, "头奖": 0, "启用": false, "文案": "未启用", "悬停": ""}
	if session.battle_ctx.is_empty():
		return 空
	var 库: Variant = session.battle_ctx.get("筹码牌库")
	var 张 := (库 as Array).size() if 库 is Array else 0
	if 张 <= 0 and not _ctx有ATX(session, session.battle_ctx):
		return 空
	var 计 := AtxChips.筹码牌库张数(session.battle_ctx)
	var 名们: Array = []
	for c in (库 if 库 is Array else []):
		if c is Dictionary:
			名们.append(str((c as Dictionary).get("名", "")))
	return {
		"张数": 张, "小": int(计["小"]), "大": int(计["大"]), "头奖": int(计["头奖"]),
		"启用": true,
		"文案": "筹码 %d（小%d/大%d/头奖%d）" % [张, int(计["小"]), int(计["大"]), int(计["头奖"])],
		"悬停": ("筹码牌库（%d 张）：%s" % [张, "、".join(名们)]) if 张 > 0 else "筹码牌库（空）",
	}

static func _ctx有ATX(session: GameSession, ctx: Dictionary) -> bool:
	for u in (ctx.get("allies") as Array) if ctx.get("allies") is Array else []:
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 \
			and str(Fac.势力名(u)) == "ATX":
			return true
	return false

## 上一张打出的牌（连携就绪金边提示用）
static func last_card_state(session: GameSession) -> Dictionary:
	if not v03_active(session):
		return {"有": false}
	var 上 = session.battle_ctx.get("上张打出牌")
	if not (上 is Dictionary):
		return {"有": false, "文案": "上一张：（本回合还没出牌）"}
	return {"有": true, "名": str(上.get("名", "")), "is_mithril_card": session._真(上.get("is_mithril_card")),
		"就绪": session._真(上.get("is_mithril_card")),
		"文案": "上一张：%s%s" % [str(上.get("名", "")), "（秘银牌 · 连携就绪！）" if session._真(上.get("is_mithril_card")) else "（非秘银牌）"]}

## 宗介 λ 驱动的展示状态（UnitCard / 武器栏用）
static func lambda_state_of(session: GameSession, unit_id: String = "") -> Dictionary:
	var u := session._选中单位(unit_id)
	if u.is_empty():
		return {}
	var 态 := DeckFlow.λ状态(u)
	var 开 := session._真(态.get("开启"))
	var 觉 := session._真(态.get("觉醒"))
	if not 开 and not 觉:
		return {"开启": false, "觉醒": false, "文案": ""}
	return {
		"开启": 开, "觉醒": 觉,
		"力场": session._读数(u.get("shieldHp")), "力场上限": 4000.0,
		"被破次数": int(session._读数(态.get("力场被破次数"))),
		"文案": DeckFlow.λ文案(u),
	}

## 拖拽 / 点击时的距离提示：`{ok, dist, why, 文案}`（超出 `[a,b]` 时 why 非空、界面标红）
static func weapon_range_check(session: GameSession, unit_id: String, card_or_id: String, target_id: String) -> Dictionary:
	if session.battle_ctx.is_empty() or not v03_active(session):
		return {"ok": true, "dist": 0, "why": "", "文案": ""}
	var u := session._找我方单位(unit_id)
	if u.is_empty():
		return {"ok": false, "dist": 0, "why": "没有选中的机体", "文案": "没有选中的机体"}
	var t: Variant = Btl.找单位(session.battle_ctx, target_id, "enemy")
	if not (t is Dictionary):
		return {"ok": false, "dist": 0, "why": "目标不存在", "文案": "目标不存在"}
	var w: Variant = null
	for c in (u.get("武器栏") as Array) if u.get("武器栏") is Array else []:
		if c is Dictionary and (str(c.get("id", "")) == card_or_id or str(c.get("名", "")) == card_or_id):
			w = c.get("武器")
	for 槽 in (u.get("大招槽") as Array) if u.get("大招槽") is Array else []:
		if 槽 is Dictionary and (槽.get("卡") is Dictionary):
			var c2: Dictionary = 槽.卡
			if str(c2.get("id", "")) == card_or_id or str(c2.get("名", "")) == card_or_id:
				w = c2.get("武器")
	for e in (u.get("副武器栏") as Array) if u.get("副武器栏") is Array else []:
		if e is Dictionary and (e.get("卡") is Dictionary):
			var c3: Dictionary = e.卡
			if str(c3.get("id", "")) == card_or_id or str(c3.get("名", "")) == card_or_id:
				w = c3.get("武器")
	if not (w is Dictionary):
		return {"ok": true, "dist": 0, "why": "", "文案": ""}
	var 判: Dictionary = Reach.武器可达吗(session.battle_ctx, u, w, t)
	var ok := session._真(判.get("ok"))
	var 距 := int(session._读数(判.get("dist")))
	return {"ok": ok, "dist": 距, "why": str(判.get("why", "")),
		"文案": ("距离 %d · %s" % [距, str(t.get("name", ""))]) if ok else ("打不到：%s（距离 %d）" % [str(判.get("why", "")), 距])}

## 武器距离的展示文案 `近战 1–2` / `直射 2–6`
static func _距离文(session: GameSession, c: Dictionary) -> String:
	var w = c.get("武器")
	if not (w is Dictionary):
		return ""
	var 界 := Reach.武器距离(w)
	return "%s %d–%d" % [_武器类型文(session, c), 界.x, 界.y]

static func _武器类型文(session: GameSession, c: Dictionary) -> String:
	var w = c.get("武器")
	if not (w is Dictionary):
		return ""
	match str((w as Dictionary).get("fire", "")):
		"melee": return "近战"
		"indirect": return "曲射"
		_: return "直射"

static func play_unit_ultimate(session: GameSession, slot_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_unit_ultimate", {"slot": slot_ident, "target_id": target_id, "unit_id": unit_id},
		_打大招(session, slot_ident, target_id, unit_id))

static func 打出大招(session: GameSession, slot_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_ultimate(session, slot_ident, target_id, unit_id)

## ★ COL-4b：**手动 QTE** —— 先把玩家选的那一档写进 `ctx.QTE指定`，打完立刻收掉（不留在场上）。
## `qte` 只认 `miss / good / perfect`；给别的值就走普通大招（= 不指定）。
static func play_unit_ultimate_qte(session: GameSession, slot_ident: String, target_id: String = "",
		qte: String = "", unit_id: String = "") -> Dictionary:
	if session.battle_ctx.is_empty() or not ["miss", "good", "perfect"].has(qte):
		return play_unit_ultimate(session, slot_ident, target_id, unit_id)
	session.battle_ctx["QTE指定"] = qte
	var r := play_unit_ultimate(session, slot_ident, target_id, unit_id)
	session.battle_ctx.erase("QTE指定")
	return r

static func _打大招(session: GameSession, slot_ident: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := DeckFlow.打出大招(session.battle_ctx, str(u.get("key", "")), slot_ident, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": GameSession.单机区_大招槽})
	return _出牌成功(session, "打大招", GameSession.单机区_大招槽, str(r.get("卡牌", slot_ident)), u, 战意前, r)

static func play_unit_sub_weapon(session: GameSession, card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_unit_sub_weapon", {"card": card_ident, "target_id": target_id, "unit_id": unit_id},
		_打副武器(session, card_ident, target_id, unit_id))

static func 打出副武器(session: GameSession, card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_sub_weapon(session, card_ident, target_id, unit_id)

static func _打副武器(session: GameSession, card_ident: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := DeckFlow.打出副武器(session.battle_ctx, str(u.get("key", "")), card_ident, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": GameSession.单机区_副武器})
	return _出牌成功(session, "打副武器", GameSession.单机区_副武器, str(r.get("卡牌", card_ident)), u, 战意前, r)

static func play_link_card(session: GameSession, card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_link_card", {"card": card_ident, "target_id": target_id, "unit_id": unit_id},
		_打连携牌(session, card_ident, target_id, unit_id))

static func 打出连携牌(session: GameSession, card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_link_card(session, card_ident, target_id, unit_id)

static func _打连携牌(session: GameSession, card_ident: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
# ★ M2：连携牌 0 费、只有秘银成员能打 —— 选中机体不是秘银但队里有秘银 → 自动换那台队友发动
	var 换 := session._换给能打的队友(u, card_ident)
	if not 换.is_empty():
		u = 换
	var 战意前 := Btl.战意(u)
	var r := DeckFlow.打出连携牌(session.battle_ctx, str(u.get("key", "")), card_ident, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": "连携牌"})
	return _出牌成功(session, "打连携牌", "连携牌", str(r.get("卡牌", card_ident)), u, 战意前, r)

## 打一张【主武器卡】（上排左区 / 角色大招牌也走这里）
static func play_unit_main_weapon(session: GameSession, weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_unit_main_weapon",
		{"weapon_or_card_id": weapon_or_card_id, "target_id": target_id, "unit_id": unit_id},
		_打主武器卡(session, weapon_or_card_id, target_id, unit_id))

static func 打出主武器卡(session: GameSession, weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_main_weapon(session, weapon_or_card_id, target_id, unit_id)

static func _打主武器卡(session: GameSession, weapon_or_card_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
# ★ MITH3-2：v0.3 开着 → 走「武器栏」那条口子（常驻武器 / 距离校验 / 记上一张 / 触发连携）
	var r := Btl.打出武器栏卡(session.battle_ctx, str(u.get("key", "")), weapon_or_card_id, target_id) if v03_active(session) \
		else Btl.打出主武器卡(session.battle_ctx, str(u.get("key", "")), weapon_or_card_id, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": GameSession.单机区_主武器})
	return _出牌成功(session, "打主武器卡", GameSession.单机区_主武器, str(r.get("武器", weapon_or_card_id)), u, 战意前, r)

## 打一张【衍生攻击卡】（上排中区
static func play_unit_derived_card(session: GameSession, card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_unit_derived_card",
		{"card_inst_id": card_inst_id, "target_id": target_id, "unit_id": unit_id},
		_打衍生卡(session, card_inst_id, target_id, unit_id))

static func 打出衍生攻击卡(session: GameSession, card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_derived_card(session, card_inst_id, target_id, unit_id)

static func _打衍生卡(session: GameSession, card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := Btl.打出衍生攻击卡(session.battle_ctx, str(u.get("key", "")), card_inst_id, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": GameSession.单机区_衍生})
	return _出牌成功(session, "打衍生攻击卡", GameSession.单机区_衍生, str(r.get("卡牌", card_inst_id)), u, 战意前, r)

static func play_unit_spirit_or_public_card(session: GameSession, card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return session._record_action("play_unit_spirit_or_public_card",
		{"card_inst_id": card_inst_id, "target_id": target_id, "unit_id": unit_id},
		_打精神或公有卡(session, card_inst_id, target_id, unit_id))

static func 打出精神或公有牌(session: GameSession, card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_spirit_or_public_card(session, card_inst_id, target_id, unit_id)

static func _打精神或公有卡(session: GameSession, card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(session, unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
# ★ M2：下排公有牌 / 连携牌 / 筹码牌 —— 选中机体打不动但队内有对口活人 → 自动换那台队友发动
	var 换 := session._换给能打的队友(u, card_inst_id)
	if not 换.is_empty():
		u = 换
	var 战意前 := Btl.战意(u)
	var r := Btl.打出精神或公有牌(session.battle_ctx, str(u.get("key", "")), card_inst_id, target_id)
	if not bool(r.get("成功", false)):
		return session._fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": GameSession.单机区_精神})
	return _出牌成功(session, "打精神或公有牌", GameSession.单机区_精神, str(r.get("卡牌", card_inst_id)), u, 战意前, r)

static func _单机出牌门(session: GameSession, unit_id: String) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	if session.battle_ctx.get("result") != null:
		return session._fail("这一场已经打完了（%s）" % session.战果文字(), {"ok": false})
	var u := session._选中单位(unit_id)
	if u.is_empty():
		return session._fail("还没有选中我方机体（先点一张机体卡）", {"ok": false})
	if float(u.get("hp", 0.0)) <= 0.0:
		return session._fail("%s 已经倒下，打不了牌" % str(u.get("name", "")), {"ok": false})
	return {"ok": true, "单位": u}

## 打牌成功后的统一收尾：`last` + 发射 `changed`
static func _出牌成功(session: GameSession, 行动: String, 区: String, 牌名: String, u: Dictionary, 战意前: float, 内核: Dictionary) -> Dictionary:
	var r: Dictionary = 内核.duplicate(true)
	r["ok"] = true
	r["行动"] = 行动
	r["区"] = 区
	r["单位"] = str(u.get("key", ""))
	r["战意前"] = 战意前
	r["战意后"] = Btl.战意(u)
	session.last = {"行动": 行动, "区": 区, "牌": 牌名, "单位": str(u.get("key", "")),
		"战意前": 战意前, "战意后": Btl.战意(u), "主武器已销毁": session._真(u.get("主武器已销毁")),
		"击破": session._读数(r.get("击破")), "日志": session.battle_log_lines(3)}
	session._emit()
	return r

static func end_player_turn(session: GameSession) -> Dictionary:
	return session._record_action("end_player_turn", {}, _结束我方回合(session))

static func 结束我方回合(session: GameSession) -> Dictionary:
	return end_player_turn(session)

static func auto_play_all_units(session: GameSession) -> Dictionary:
	return end_player_turn(session)

static func _结束我方回合(session: GameSession) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	if session.battle_ctx.get("result") != null:
		return session._fail("这一场已经打完了（%s）" % session.战果文字(), {"ok": false})
	var 前回合 := int(float(session.battle_ctx.get("turn", 1.0)))
	var 前日志 := session.battle_log_entries(0).size()
	Btl.结束我方回合(session.battle_ctx)
	var 后回合 := int(float(session.battle_ctx.get("turn", 1.0)))
# ★ DECK-3：敌方阶段可能把「当前选中」那台打掉了 —— 换一台活着的，
	var 选中 := session._选中单位("")
	if 选中.is_empty() or float(选中.get("hp", 0.0)) <= 0.0:
		session._选中默认机体()
	session.last = {"ok": true, "行动": "结束我方回合", "从回合": 前回合, "到回合": 后回合,
		"结果": session.战果文字(), "结算": session.battle_ctx.get("result", null),
		"新日志": maxi(0, session.battle_log_entries(0).size() - 前日志),
		"阶段": str(session.battle_ctx.get("阶段", "")), "选中": session.selected_unit_id, "日志": session.battle_log_lines(4)}
	session._emit()
	return session.last

## 底栏 / 标题那一行的小计（**纯读**
static func deck_turn_summary(session: GameSession) -> Dictionary:
	var 出 := session.turn_card_summary()
	if session.battle_ctx.is_empty():
		return 出
	var u := session._选中单位("")
	var 上 := session.upper_hand_cards()
	var 下 := session.lower_hand_cards()
	var 上能 := 0
	for c in 上:
		if bool((c as Dictionary).get("可打", false)):
			上能 += 1
	var 下能 := 0
	for c in 下:
		if bool((c as Dictionary).get("可打", false)):
			下能 += 1
	出["阶段"] = str(session.battle_ctx.get("阶段", ""))
	出["单机牌组"] = true
	出["选中"] = session.selected_unit_id
	出["选中名"] = str(u.get("name", ""))
	出["选中职业"] = (str(Units.unit_class(u, session.battle_ctx)) if not u.is_empty() else "")
	出["选中势力"] = (str(Fac.势力名(u)) if not u.is_empty() else "")
	出["战意"] = Btl.战意(u) if not u.is_empty() else 0.0
	出["战意上限"] = Params.战意上限()
	出["主武器已销毁"] = session._真(u.get("主武器已销毁"))
	出["上排"] = 上.size()
	出["下排"] = 下.size()
	出["上排能打"] = 上能
	出["下排能打"] = 下能
	return 出

## ★ 2026-10-21（任务单问题 4）：**当前援护连线们**（纯读门面）
static func guard_links(session: GameSession) -> Array:
	if session.battle_ctx.is_empty():
		return []
	return Btl.当前援护连线们(session.battle_ctx)

static func enemy_intents(session: GameSession) -> Array:
	if session.battle_ctx.is_empty():
		return []
	var 意: Variant = session.battle_ctx.get("敌方意图")
	if not (意 is Array):
		意 = Btl.算意图(session.battle_ctx)
	var 出: Array = []
	for x in (意 as Array):
		if x is Dictionary:
			出.append((x as Dictionary).duplicate(true))
		else:
			出.append(x)
	return 出

static func unit_intent_lines(session: GameSession, side: String, unit_id: String) -> Array:
	var 出: Array = []
	if session.battle_ctx.is_empty():
		return 出
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	var u := session._找我方单位(unit_id) if 方 == "ally" else session._找单位(unit_id)
	if u.is_empty():
		return 出
	if 方 == "enemy" and not _在敌方(session, u):
		return 出   # `_找单位` 会先找我方：键撞车时别把友军当敌机
	var 意 := enemy_intents(session)
	var 键 := str(u.get("key", ""))
	var 位 := float(u.get("slot", -1.0))
	for 条 in 意:
		if not (条 is Dictionary):
			continue
		var c: Dictionary = 条
		if 方 == "enemy":
			if str(c.get("单位", "")) != 键:
				continue
			出.append(_意图一行文本(session, c))
		else:
			var 打我 := str(c.get("目标", "")) == 键
			var 落点: Variant = c.get("落点们")
			if not 打我 and 落点 is Array and (落点 as Array).has(位):
				打我 = true
			if 打我:
				出.append("〔被瞄准〕%s·%s（预计 %s）" % [str(c.get("位名", "")), str(c.get("武器名", "")),
					_数文(session, c.get("预计伤害"))])
	return 出

## 一条 `算意图` 条目 → 一行中文预告
static func _意图一行文本(session: GameSession, c: Dictionary) -> String:
	var 武 := str(c.get("武器名", ""))
	var 段 := "意图："
	if 武.is_empty():
		段 += "这一拍打不到人"
		return 段
	段 += "攻击【%s】" % 武
	var 目 := str(c.get("目标名", ""))
	if not 目.is_empty():
		段 += "→ %s（%s）" % [目, str(c.get("目标位名", ""))]
	段 += "（预计 %s）" % _数文(session, c.get("预计伤害"))
	if bool(c.get("是大招", false)):
		段 += "· 大招"
	if bool(c.get("是大技能", false)):
		段 += "· Boss 大技能"
	if bool(c.get("被挡", false)):
		段 += "· 被挡 -20"
	var 落: Variant = c.get("落点们")
	if 落 is Array and (落 as Array).size() > 1:
		段 += "· 范围：%s" % str(c.get("形状", ""))
	return 段

## 数值 → 文本（0 位小数
static func _数文(session: GameSession, v: Variant) -> String:
	if v == null:
		return "0"
	return str(int(JsCompat.js_round(float(v))))

## 这台（`_找单位` 找到的）单位是不是敌方的
static func _在敌方(session: GameSession, u: Dictionary) -> bool:
	var 池: Variant = session.battle_ctx.get("enemies")
	if not (池 is Array):
		return false
	for x in (池 as Array):
		if x is Dictionary and is_same(x, u):
			return true
	return false
