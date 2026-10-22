## 会话门面的「三 名册 / 招募 / 晋升 / 三选一 / 编队」子模块。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionRosterFacade
extends RefCounted

static func recruit_unit(session: GameSession, unit_key: String, ticket_idx: int = -1) -> Dictionary:
	return session._record_action("recruit_unit", {"unit_key": unit_key, "ticket_idx": ticket_idx}, _招募(session, unit_key, ticket_idx))

static func _招募(session: GameSession, unit_key: String, ticket_idx: int = -1) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if RosterManager.模板(unit_key).is_empty():
		return session._fail("没有这位机师（%s）" % unit_key, {"ok": false, "键": unit_key})
	var 找 := RosterManager.找同类券(s, unit_key)
	if ticket_idx < 0 and not 找.is_empty():
		ticket_idx = int(找.get("下标", -1))
	if ticket_idx < 0 or ticket_idx >= s.tickets.size():
		return session._fail("手上没有能招 %s 的券（要有同职业 / 同势力的招募券；现在手上 %d 张：%s）"
			% [unit_key, s.tickets.size(), RosterManager.券汇总文字(s)], {"ok": false, "键": unit_key})
	var 前 := {"希望": s.hope, "券": s.tickets.size(), "名册": s.roster.size()}
	var r := RosterManager.recruit(s, unit_key, ticket_idx)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "招不了")), {"ok": false, "键": unit_key})
	session.last = {
		"行动": "招募", "键": unit_key, "等级": int(r.get("等级", 0)), "费": int(r.get("费", 0)),
		"券名": str(r.get("券名", "")), "带队核心": bool(r.get("带队核心", false)),
		"希望前": 前["希望"], "希望后": s.hope, "券前": 前["券"], "券后": s.tickets.size(),
		"名册前": 前["名册"], "名册后": s.roster.size(), "候选战术牌": s.pending_card_picks.duplicate(),
		"日志": session._tail_logs(3),
	}
	session._refresh_modal()
	session._emit()
	return r

## 10-22 作者定：券最多留 3 张；超出才算「必须先决定」，名册空时照旧必须先招 1 台。
static func 有未决的券(session: GameSession) -> bool:
	var n := session.ticket_count()
	return n > RosterManager.券留存上限() or (n > 0 and session.roster_count() == 0)

static func discard_ticket(session: GameSession, ticket_idx: int = 0) -> Dictionary:
	return session._record_action("discard_ticket", {"ticket_idx": ticket_idx}, _丢券(session, ticket_idx))

static func _丢券(session: GameSession, ticket_idx: int = 0) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if s.tickets.is_empty():
		return session._fail("手上没有招募券可以放弃", {"ok": false, "券": 0})
	var 下标 := ticket_idx
	if 下标 < 0 or 下标 >= s.tickets.size():
		下标 = 0
	var 券前 := s.tickets.size()
	var 名 := RosterManager.券名(s.tickets[下标])
	var r := RosterManager.丢券(s, 下标)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "丢不了")), {"ok": false, "券": 券前})
	session.last = {"行动": "丢券", "券名": 名, "下标": 下标, "券前": 券前, "券后": s.tickets.size(),
		"名册": s.roster.size(), "日志": session._tail_logs(3)}
	session._refresh_modal()
	session._emit()
	return r

static func promote_unit(session: GameSession, unit_key: String) -> Dictionary:
	return session._record_action("promote_unit", {"unit_key": unit_key}, _晋升(session, unit_key))

static func _晋升(session: GameSession, unit_key: String) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	var r := RosterManager.promote(s, unit_key)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "升不了")), {"ok": false, "键": unit_key})
	session.last = {"行动": "晋升", "键": unit_key, "从": int(r.get("从", 0)), "到": int(r.get("到", 0)),
		"价": int(r.get("价", 0)), "前": r.get("前", {}), "后": r.get("后", {}),
		"希望": s.hope, "候选战术牌": s.pending_card_picks.duplicate(), "日志": session._tail_logs(3)}
	session._refresh_modal()
	session._emit()
	return r

static func pick_tactical_card(session: GameSession, card_id: String) -> bool:
	return session._record_action("pick_tactical_card", {"card_id": card_id}, _选战术牌(session, card_id))

static func _选战术牌(session: GameSession, card_id: String) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	if card_id.is_empty():
		session._fail("没有指定要选哪张牌", {"ok": false})
		return false
	if s.pending_card_picks.is_empty():
		session._fail("现在没有待选的战术牌", {"ok": false, "候选": []})
		return false
	if not s.pending_card_picks.has(card_id) and DeckBuilder.找到(card_id).is_empty():
		session._fail("这张牌不在候选里（%s）" % card_id, {"ok": false, "候选": s.pending_card_picks.duplicate()})
		return false
	var 前 := s.tactical_deck.size()
	var ok := DeckBuilder.select_card(s, card_id)
	if not ok:
		session._fail("选牌被内核拒绝（%s）" % card_id, {"ok": false})
		return false
	session.last = {"行动": "选战术牌", "牌": card_id, "牌库前": 前, "牌库后": s.tactical_deck.size(),
		"候选清空": s.pending_card_picks.is_empty(), "日志": session._tail_logs(2)}
	session._refresh_modal()
	session._emit()
	return true

static func refresh_card_offers(session: GameSession, unit_key: String = "") -> Array:
	return session._record_action("refresh_card_offers", {"unit_key": unit_key}, _刷新候选(session, unit_key))

static func _刷新候选(session: GameSession, unit_key: String = "") -> Array:
	var s := session._need_run()
	if s == null:
		return []
	var 键 := unit_key
	if 键.is_empty():
		键 = str(s.squad_leader) if not str(s.squad_leader).is_empty() else ""
	if 键.is_empty() and not s.roster.is_empty():
		键 = str(s.roster.keys()[0])
	if 键.is_empty() or RosterManager.模板(键).is_empty():
		return []
	if s.pending_card_picks.is_empty():
		DeckBuilder.offer_cards(s, 键, 3)
		var 候选: Array = s.pending_card_picks.duplicate()
		s.pending_card_picks = []
		return 候选
	return DeckBuilder.候选战术牌们(s, 键, 3)

static func lineup_slots(session: GameSession) -> Array:
	session._data_ready()
	var s := session.run_state
# ★ UX-1 第 2 项：**读之前先过一遍唯一性守卫**（同一台最多 1 格、同一格位最多 1 台）。
	session._清理重复占格(s)
	var 占位 := {}
	if s != null:
		for x in s.lineup:
			if x is Dictionary:
				占位[str(x.get("key"))] = session._条位号(x)
	var out: Array = []
	var n := int(Fm.SLOTS())
	for i in n:
		var 名 := Fm.位名(float(i))
		var 谁 := ""
		for k in 占位.keys():
			if int(占位[k]) == i:
				谁 = str(k)
				break
		out.append({"位": i, "位名": 名, "键": 谁})
	return out

static func normalize_lineup_slots(session: GameSession) -> bool:
	session._data_ready()
	return session._规范编队槽位(session.run_state)

static func 规范编队槽位(session: GameSession) -> bool:
	return normalize_lineup_slots(session)

## ★ UX-4：玩家**亲手动过编队** → 记一笔（`map_data.lineup_customized = true`）
static func _标记编队已调整(session: GameSession, s: RunState) -> void:
	if s == null:
		return
	if bool(s.map_data.get("lineup_customized", false)):
		return
	s.map_data["lineup_customized"] = true

static func set_lineup_slot(session: GameSession, unit_key: String, slot_name: String) -> bool:
	return session._record_action("set_lineup_slot", {"unit_key": unit_key, "slot_name": slot_name}, _摆上阵(session, unit_key, slot_name))

static func deploy_unit(session: GameSession, unit_key: String, slot_name: String) -> bool:
	return set_lineup_slot(session, unit_key, slot_name)

static func _摆上阵(session: GameSession, unit_key: String, slot_name: String) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	if not s.roster.has(unit_key):
		session._fail("名册里没有这台机体（%s）" % unit_key, {"ok": false, "键": unit_key})
		return false
	if not session._位名合法(slot_name):
		session._fail("没有这个格位（%s）" % slot_name, {"ok": false, "位名": slot_name})
		return false
	session._清理重复占格(s)
	var 位 := session._位号(slot_name)
# ★ 纯函数式重建：先把「位号 → 一条出击记录」压实成一张表（同一位号只留最后一条），
	var 位表 := session._压实出击位(s)
	var 旧 := -1
	for k in 位表.keys():
		if str(位表[k]) == unit_key:
			旧 = int(k)
			break
	var 占者 := str(位表.get(位, ""))
	var 会换人 := not 占者.is_empty() and 占者 != unit_key
# ★ 上限闸只有一个口径：**上阵人数会不会变多**。
	if 旧 < 0 and not 会换人 and s.lineup.size() >= RosterManager.deploy_limit(s):
		session._fail("出击位满了（上限 %d 台，先把一台撤下来）" % RosterManager.deploy_limit(s), {"ok": false})
		return false
	if 旧 == 位:
# 已经站在这一格上：幂等（不改状态），只留一条即时反馈。
		session.last = {"行动": "编队", "键": unit_key, "位名": slot_name, "位": 位, "原": 旧,
			"出击": s.lineup.duplicate(true), "上限": RosterManager.deploy_limit(s), "没变": true}
		session._set_screen("formation")
		return true
# ① 先移除这一台原来的那一条（否则同一个键会占两格 —— 反馈第 3 条的假「满了」就是这么来的）。
	if 旧 >= 0:
		位表.erase(旧)
	if 会换人 and 旧 >= 0:
		位表[旧] = 占者
# ③ 这一台落到目标格。
	位表[位] = unit_key
	s.lineup = session._位表到出击(位表)
	session._清理重复占格(s)
	_标记编队已调整(session, s)
	session.last = {"行动": "编队", "键": unit_key, "位名": slot_name, "位": 位, "原": 旧,
		"换下": 占者 if 会换人 else "", "出击": s.lineup.duplicate(true),
		"上限": RosterManager.deploy_limit(s)}
	session._set_screen("formation")
	return true

static func remove_from_lineup(session: GameSession, unit_key: String) -> bool:
	return session._record_action("remove_from_lineup", {"unit_key": unit_key}, _撤下来(session, unit_key))

static func undeploy_unit(session: GameSession, unit_key: String) -> bool:
	return remove_from_lineup(session, unit_key)

static func _撤下来(session: GameSession, unit_key: String) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	var 前 := s.lineup.size()
	var 新出击: Array = []
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			continue
		新出击.append(x)
	if 新出击.size() == 前:
		session._fail("%s 本来就不在出击位上" % unit_key, {"ok": false, "键": unit_key})
		return false
	s.lineup = 新出击
	session._清理重复占格(s)
	_标记编队已调整(session, s)
	session.last = {"行动": "撤下", "键": unit_key, "出击前": 前, "出击后": s.lineup.size(),
		"出击": s.lineup.duplicate(true)}
	session._set_screen("formation")
	return true

static func clear_lineup(session: GameSession) -> bool:
	return session._record_action("clear_lineup", {}, _清空编队(session))

static func _清空编队(session: GameSession) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	var 前 := s.lineup.size()
	if 前 == 0:
		session._fail("出击名单本来就是空的", {"ok": false, "出击": 0})
		return false
	s.lineup = []
	_标记编队已调整(session, s)
	session.last = {"行动": "清空编队", "出击前": 前, "出击后": 0, "出击": []}
	session._set_screen("formation")
	return true

static func available_recruit_targets(session: GameSession, ticket_idx: int = -1) -> Array:
	session._data_ready()
	var s := session._need_run()
	if s == null:
		return []
	if s.tickets.is_empty():
		return []
	if ticket_idx < 0 or ticket_idx >= s.tickets.size():
		return []
	var 券: Variant = s.tickets[ticket_idx]
	var 费表: Dictionary = Db.catalog.roguelike_config().get("招募费") if Db.catalog.roguelike_config().get("招募费") is Dictionary else {}
	var out: Array = []
	var 上限值: Variant = RosterManager.cfg().get("队伍上限")
	var 上限 := maxi(0, int(上限值) if 上限值 != null else 12)
	for 键 in RosterManager.券合机师们(券):
		if s.roster.has(键):
			continue
		var 档 := RosterManager.档(键)
		var 费 := int(费表.get(档)) if 费表.get(档) != null else 0
		# ★ IT-3：招不了的也列出来，但带上「为什么」—— 招募屏把它灰掉并写明原因（试玩反馈：希望不足要看得见）。
		var 为什么 := ""
		if s.roster.size() >= 上限:
			为什么 = "队伍满了（%d 台）" % 上限
		elif s.hope < 费:
			为什么 = "希望不足（要 %d，只有 %d）" % [费, s.hope]
		out.append({"键": 键, "名": str(RosterManager.模板(键).get("名", 键)), "档": 档,
			"费": 费, "等级": RosterManager.带队核心等级 if s.roster.is_empty() else RosterManager.招募等级(s.floor_num),
			"职业": str(RosterManager.标签(键).get("战斗分类")), "势力": str(RosterManager.标签(键).get("势力")),
			"带队核心": s.roster.is_empty(), "可招": 为什么.is_empty(), "为什么": 为什么})
	return out

static func promotion_preview(session: GameSession, unit_key: String) -> Dictionary:
	session._data_ready()
	var s := session._need_run()
	if s == null:
		return {"ok": false, "why": "还没有进行中的局"}
	if not s.roster.has(unit_key):
		return {"ok": false, "why": "名册里没有这台机体", "键": unit_key}
	var 从 := s.get_unit_level(unit_key)
	var 到 := RosterManager.晋升目标(从)
	if 到 == 0:
		return {"ok": false, "why": "%s 已经 Lv%d，到顶了" % [unit_key, 从], "键": unit_key, "等级": 从}
	var 价 := RosterManager.晋升要多少(unit_key, 到, s)
	var 找 := RosterManager.找同类券(s, unit_key)
	var 预 := RosterManager.晋升预览(unit_key, 从)
	return {"ok": true, "键": unit_key, "从": 从, "到": 到, "价": 价, "希望": s.hope,
		"能升": s.hope >= 价 and not 找.is_empty(), "有券": not 找.is_empty(),
		"券名": RosterManager.券名(找["券"]) if not 找.is_empty() else "", "前": 预["前"], "后": 预["后"],
		"解锁专属牌": 预.get("解锁专属牌", []), "专属牌库": 预.get("专属牌库", []),
		"等级倍率": DeckBuilder.等级倍率(到)}
