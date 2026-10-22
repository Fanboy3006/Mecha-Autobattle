## 会话门面的「二 大地图与零件 / 四 非战斗节点」子模块 —— 移动、零件、追击战、换层、休整 / 黑市 / 奇遇结算。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionRunFacade
extends RefCounted

## 纯读预告（三层反馈的「预告」那一层）：这一格走过去要几点推进剂、退路成本多少、能不能去
static func preview_cell_move(session: GameSession, cell_id: int) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有大地图", {"ok": false, "格": cell_id})
	if s.map_data.is_empty():
		return session._fail("还没有大地图", {"ok": false, "格": cell_id})
	var can := MapNavigator.can_move_to(s, cell_id)
	var 退 := MapNavigator.retreat_cost_preview(s, cell_id)
	var 格 := s.cell_at(cell_id)
	return {
		"ok": bool(can.get("ok", false)), "格": cell_id,
		"推进剂消耗": int(can.get("cost", 0)), "推进剂": s.propellant, "推进剂上限": s.propellant_max,
		"隧道": bool(can.get("隧道", false)), "路径": can.get("path", []),
		"退路成本": int(退.get("退路成本", -1)), "是干路": bool(退.get("是干路", false)),
		"是割点": bool(退.get("是割点", false)), "度数": int(退.get("度数", 0)),
		"类型": str(格.get("类型", "")), "列": int(格.get("列", 0)), "行": int(格.get("行", 0)),
		"已过": bool(格.get("已过", false)), "为什么": str(can.get("为什么", "")),
	}

static func move_to_cell(session: GameSession, cell_id: int) -> Dictionary:
	return session._record_action("move_to_cell", {"cell_id": cell_id}, _走一格(session, cell_id))

static func move_to(session: GameSession, cell_id: int) -> Dictionary:
	return move_to_cell(session, cell_id)

static func _走一格(session: GameSession, cell_id: int) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有大地图", {"ok": false})
	if s.map_data.is_empty():
		return session._fail("还没有大地图", {"ok": false})
# ★ UX-1 第 6 项（2026-10-19）：点在**自己脚下这一格**上、而且这一格没有要结算的东西
	if cell_id == int(s.node_id) and not _这一格要先结算吗(session, s):
		return {"ok": false, "why": "已经在当前所在格", "noop": true, "格": cell_id}
	var 前 := {"推进剂": s.propellant, "格": s.node_id}
	var r := MapNavigator.move_to(s, cell_id)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("为什么", "走不过去")), {"ok": false, "格": cell_id})
# ★ 落脚之后把「当前节点类型」同步成**脚下这一格**的真实类型：`_进层()` 只写过起点那一格，
	var 脚 := s.cell_at(s.node_id)
	var 脚类型 := str(脚.get("类型", ""))
	if 脚类型.is_empty():
		脚类型 = "空"
	s.map_data["当前节点类型"] = 脚类型
	session.last = {
		"行动": "移动", "从": 前["格"], "到": s.node_id, "类型": 脚类型,
		"距离": int(r.get("距离", 0)), "推进剂前": 前["推进剂"], "推进剂后": s.propellant,
		"追击": bool(r.get("追击", false)), "提示": str(r.get("提示", "")),
		"日志": session._tail_logs(3),
	}
# ★ D-08：走完这一格 → 推进剂见底就开追击战（站的是出口格时留给 `try_advance_floor()`）。
	if not _这一格要先结算吗(session, s):
		if _接追击战(session, s):
			return session.last
	session._set_screen("map")
	return r

static func use_part(session: GameSession, part_idx: int, target_cell: int = -1) -> Dictionary:
	return session._record_action("use_part", {"part_idx": part_idx, "target_cell": target_cell}, _用零件(session, part_idx, target_cell))

static func use_part_on_cell(session: GameSession, idx: int, cell_id: int = -1) -> Dictionary:
	return session._record_action("use_part_on_cell", {"part_idx": idx, "cell_id": cell_id}, _用零件(session, idx, cell_id))

static func _用零件(session: GameSession, part_idx: int, target_cell: int) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if part_idx < 0 or part_idx >= s.parts.size():
		return session._fail("没有这件零件（下标 %d，手上有 %d 件）" % [part_idx, s.parts.size()], {"ok": false})
	var 前推进 := int(s.propellant)
	var 前格 := int(s.node_id)
	var r := PartSystem.use_part(s, part_idx, target_cell)
	if not bool(r.get("ok", false)):
		var 因 := str(r.get("why", r.get("为什么", "用不了")))
		return session._fail(因 if not 因.is_empty() else "用不了", {"ok": false, "why": 因})
# ★ bagua 的落点由内核随机抽出后回填在 `target`；其余零件就是传进来的那一格。
	var 落 := int(r.get("target", r.get("到", s.node_id)))
	var 脚 := s.cell_at(落)
	var 脚类型 := str(脚.get("类型", ""))
	if 脚类型.is_empty():
		脚类型 = "空"
# ★ 与 `_走一格()` 同款：落脚之后把「当前节点类型」同步成脚下这一格的真实类型。
	s.map_data["当前节点类型"] = 脚类型
	var 需进 := _这一格要先结算吗(session, s)
	r["到"] = 落
	r["target"] = 落
	r["类型"] = 脚类型
	r["从"] = 前格
	r["需要进入"] = 需进
	r["推进剂前"] = 前推进
	r["推进剂后"] = s.propellant
	session.last = {"行动": "用零件", "零件": str(r.get("零件", "")), "到": 落, "落点": 落, "类型": 脚类型,
		"免费": bool(r.get("免费", false)), "推进剂前": 前推进, "推进剂后": s.propellant,
		"需要进入": 需进, "额外": r.get("额外", {}), "零件剩": s.parts.size(), "日志": session._tail_logs(3)}
# ★ D-08 / D-10：推进剂见底 → 这一格没东西要结算就当场开追击战；有东西要结算则由节点
	if _接追击战(session, s):
		return session.last
	session._set_screen("map")
	return r

## ★ D-10（对齐封存 JS `92-肉鸽界面-1-大图与记录.js:315`）：「**这一格结算完**才会触发追击战」
static func _这一格要先结算吗(session: GameSession, s: RunState) -> bool:
	if s == null or s.map_data.is_empty():
		return false
	return GameSession._要先结算的类型.has(session._脚下类型(s))

## 这一格结算完要不要开一场追击战？要 → 开战并返回 true（屏幕已进 `"battle"`）
static func _接追击战(session: GameSession, s: RunState, 已结算: bool = false) -> bool:
	if not MapNavigator.exit_chase_pending(s):
		return false
	if MapGenerator.exit_kinds().has(s.current_type()):
		return false
	if not 已结算 and _这一格要先结算吗(session, s):
		return false
	return _开追击战(session, s, false)

static func _收尾这一格(session: GameSession, s: RunState) -> bool:
	return _接追击战(session, s, true)

static func fight_chase_battle(session: GameSession) -> bool:
	return session._record_action("fight_chase_battle", {}, _打追击战(session))

static func trigger_pursuit_battle(session: GameSession) -> bool:
	return fight_chase_battle(session)

static func _打追击战(session: GameSession) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
# ★ 2026-10-18（作者试玩反馈第 2 条）：手上还有没决定的招募券 → 不许**手动**开新战斗，
	if session.有未决的招募券():
		session._fail("手上还有 %d 张招募券没决定（先招募一台，或者按【放弃此券】）" % session.ticket_count(), {"ok": false})
		return false
	if not MapNavigator.exit_chase_pending(s):
		session._fail("现在不是追击战的时机（推进剂 %d、本层已追击过 = %s）" % [s.propellant, str(s.chased)], {"ok": false})
		return false
	return _开追击战(session, s, s.exit_chase)

static func _开追击战(session: GameSession, s: RunState, 在出口: bool) -> bool:
	if NodeResolver.我方编成(s).is_empty():
		return false
	if 在出口:
		MapNavigator.begin_exit_chase(s)
	var 类型 := NodeResolver.战斗类型Of(s, "追击")
	var rng := Mulberry32.new(NodeResolver.编成种子(s, s.floor_num))
	var 详情 := NodeResolver.抽编成兜底(s.floor_num, 类型, rng)
	if 详情.is_empty() or not (详情.get("条目") is Dictionary):
		session._fail("抽不到第 %d 层「追击」的编成" % s.floor_num, {"ok": false})
		return false
	s.map_data["本场兜底"] = {"层": s.floor_num, "格": s.node_id, "到": str(详情.get("类型", 类型))} if 详情.get("兜底") != null else null
# ★ 让 `finish_battle_and_settle()` 认出这是一场追击战（它按 `_脚下类型(s)` 决定后处理）。
	s.map_data["当前节点类型"] = "追击"
	session._本场格类型 = "追击"
	var ctx := NodeResolver.开战(s, 详情["条目"], "追击", session._附加战斗选项())
	if ctx.is_empty():
		session._fail("追击战：战斗内核没有给出 ctx", {"ok": false})
		return false
	session._quick_battle = false
	session._全卡池体验 = false
	session._快速测试局 = false
	session._本场已结算 = false
	session._血比战前 = session._名册血比()
	session.battle_ctx = ctx
	session._unit_switches = session.表(ctx, "选项")
	session._result_cache = {}
	session.selected_unit_id = ""
	session._选中默认机体()
	session.last = {"行动": "追击战", "格类型": "追击", "编成类型": str(详情.get("类型", 类型)),
		"出口那一步": 在出口, "推进剂": s.propellant, "已追击过": s.chased,
		"敌方": (ctx.get("enemies") as Array).size(), "我方": (ctx.get("allies") as Array).size(),
		"日志": session.battle_log_lines(3)}
	session._set_screen("battle")
	return true

static func enter_current_node(session: GameSession) -> Dictionary:
	return session._record_action("enter_current_node", {}, _进当前格(session))

static func _进当前格(session: GameSession) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return session._fail("还没有大地图", {"ok": false})
	var 类型 := session._脚下类型(s)
	match 类型:
		"作战", "精英", "守军", "侵蚀源", "出口守军", "追击":
# ★ 调**内部**实现：这一趟的「动作」由 `enter_current_node` 那一条记录代表，
			session._开节点战()
			return session.last
		"休整":
			return _结算休整(session, "耐久")
		"黑市":
			session._node_result = {"ok": true, "节点": "黑市", "货": NodeResolver.黑市货(s)}
			session.last = {"行动": "进黑市", "货": session._node_result["货"], "源碳": s.carbon, "日志": session._tail_logs(2)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"事件":
			session._node_result = {"ok": true, "节点": "事件", "事件": NodeResolver.当前事件(s), "选项": current_event_choices(session)}
			session.last = {"行动": "进事件", "事件": str(session._node_result["事件"].get("名", "")), "日志": session._tail_logs(2)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"瞭望站":
			session._node_result = NodeResolver.结算瞭望站(s, "登高")
			session._node_result["节点"] = "瞭望站"
			session.last = {"行动": "瞭望站", "结果": session._node_result, "日志": session._tail_logs(3)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"遗迹":
			session._node_result = NodeResolver.结算遗迹(s, "藤蔓")
			session._node_result["节点"] = "遗迹"
			session.last = {"行动": "遗迹", "结果": session._node_result, "日志": session._tail_logs(3)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"隧道":
			session._node_result = NodeResolver.结算隧道(s)
			session._node_result["节点"] = "隧道"
			session.last = {"行动": "隧道", "结果": session._node_result, "从": s.node_id, "日志": session._tail_logs(3)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"空":
			NodeResolver.清空格(s)
			session._node_result = {"ok": true, "节点": "空", "文本": "林间空地：落脚休整片刻，未遭遇敌情。"}
			session.last = {"行动": "空格", "结果": session._node_result, "日志": session._tail_logs(2)}
# ★ D-08 / D-10：这一格的事做完了 → 推进剂见底就追击战（不然玩家在这儿无路可走）。
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"招募站":
			var 领 := RosterManager.招募站领券(s)
			session._node_result = {"ok": bool(领.get("ok", false)), "节点": "招募站", "券": 领.get("券", null),
				"券名": str(领.get("券名", "")), "重复": bool(领.get("重复", false))}
			session.last = {"行动": "招募站", "结果": session._node_result, "券数": s.tickets.size(), "日志": session._tail_logs(2)}
			if _收尾这一格(session, s):
				return session._node_result
			session._set_screen("map")
			return session._node_result
		"出口尽头", "出口小径":
			return _换层(session)
# ★ D-08 兜底：这一格没有「进去就结算」的东西时，也检查一次**追击战** ——
	if _接追击战(session, s, true):
		return session.last
	return session._fail("这一格（%s）没有可以直接进去的东西" % 类型, {"ok": false, "类型": 类型})

static func try_advance_floor(session: GameSession) -> Dictionary:
	return session._record_action("try_advance_floor", {}, _换层(session))

static func advance_floor(session: GameSession) -> Dictionary:
	return try_advance_floor(session)

static func _换层(session: GameSession) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return session._fail("还没有大地图", {"ok": false})
	if not s.pending_card_picks.is_empty():
		return session._fail("还有 %d 张战术牌没选（先选完再换层）" % s.pending_card_picks.size(), {"ok": false})
	if MapNavigator.exit_chase_pending(s) and MapGenerator.exit_kinds().has(s.current_type()):
		if _开追击战(session, s, true):
			return session.last
	var 前层 := s.floor_num
	var 前推进 := s.propellant
	var r := MapNavigator.resolve_exit(s)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("为什么", "这一层还换不了")), {"ok": false, "待换层": r.get("待换层", null)})
	var 藏品希望 := RelicSystem.藏品每层希望(s, s.floor_num)
	session.last = {
		"行动": "换层", "从层": 前层, "到层": s.floor_num, "通关": bool(r.get("通关", false)),
		"出口类型": MapNavigator.current_exit_kind(s), "推进剂前": 前推进, "推进剂后": s.propellant,
		"推进剂上限": s.propellant_max, "希望": s.hope, "藏品希望": 藏品希望,
		"推进剂明细": MapGenerator.propellant_detail(s), "日志": session._tail_logs(3),
	}
	if bool(r.get("通关", false)):
		session._result_cache = {"胜": s.status == "胜利", "通关": true, "层": s.floor_num}
		session._set_screen("result")
		return r
	session._set_screen("map")
	return r

static func resolve_rest(session: GameSession, choice: String = "耐久") -> Dictionary:
	return session._record_action("resolve_rest", {"choice": choice}, _结算休整(session, choice))

static func rest_action(session: GameSession, choice: String = "耐久") -> Dictionary:
	return resolve_rest(session, choice)

static func _结算休整(session: GameSession, choice: String = "耐久") -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
# ★ 2026-10-18（作者试玩反馈第 3 条）：**同一格只结算一次**。
	var 键 := session.当前节点结算键()
	if session._已结算节点键.has(键):
		return session._fail("当前节点已结算完毕", {"ok": false, "键": 键, "节点": "休整"})
	var 前 := {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	var r := NodeResolver.结算休整(s, choice)
	if r.is_empty():
		return session._fail("休整结算失败", {"ok": false})
	session._已结算节点键[键] = true
	r["节点"] = "休整"
	r["前"] = 前
	r["后"] = {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	session._node_result = r
	session.last = {"行动": "休整", "选": choice, "结果": r, "日志": session._tail_logs(3)}
# ★ D-08：休整也可能把推进剂补回来，但若仍是 0（例如选了「耐久」）→ 这一格结算完就追击战。
	if _接追击战(session, s):
		return r
	session._set_screen("map")
	return r

static func buy_from_shop(session: GameSession, relic_id: String) -> Dictionary:
	return session._record_action("buy_from_shop", {"relic_id": relic_id}, _黑市买(session, relic_id))

static func shop_buy(session: GameSession, relic_id: String) -> Dictionary:
	return buy_from_shop(session, relic_id)

static func _黑市买(session: GameSession, relic_id: String) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if relic_id.is_empty():
		return session._fail("没有指定要买哪一件", {"ok": false})
	var 前碳 := s.carbon
	var r := NodeResolver.黑市买(s, relic_id)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "买不了")), {"ok": false, "id": relic_id})
	session.last = {"行动": "黑市买", "id": relic_id, "名": str(r.get("名", "")), "价": int(r.get("价", 0)),
		"源碳前": 前碳, "源碳后": s.carbon, "藏品数": s.relics.size(), "日志": session._tail_logs(3)}
	session._emit()
	return r

static func refresh_shop(session: GameSession) -> Dictionary:
	return session._record_action("refresh_shop", {}, _黑市刷新(session))

static func _黑市刷新(session: GameSession) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	var r := NodeResolver.黑市刷新(s)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "刷新不了")), {"ok": false})
	session.last = {"行动": "黑市刷新", "价": int(r.get("价", 0)), "次": int(r.get("次", 0)),
		"货": r.get("货", []), "源碳": s.carbon, "日志": session._tail_logs(3)}
	session._emit()
	return r

static func sell_part_in_shop(session: GameSession, part_idx: int) -> Dictionary:
	return session._record_action("sell_part_in_shop", {"part_idx": part_idx}, _黑市卖零件(session, part_idx))

static func _黑市卖零件(session: GameSession, part_idx: int) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if part_idx < 0 or part_idx >= s.parts.size():
		return session._fail("没有这件零件（下标 %d，手上有 %d 件）" % [part_idx, s.parts.size()], {"ok": false})
	var 前碳 := s.carbon
	var r := PartSystem.sell_part(s, part_idx)
	if r.is_empty():
		return session._fail("卖不出去（下标 %d）" % part_idx, {"ok": false})
	session.last = {"行动": "卖零件", "名": str(r.get("名", "")), "价": int(r.get("价", 0)),
		"源碳前": 前碳, "源碳后": s.carbon, "零件剩": s.parts.size(), "日志": session._tail_logs(3)}
	session._emit()
	return r

static func leave_shop(session: GameSession) -> bool:
	return session._record_action("leave_shop", {}, _离开黑市(session))

static func _离开黑市(session: GameSession) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	var ok := NodeResolver.黑市离开(s)
	session.last = {"行动": "离开黑市", "成功": ok, "已清节点": s.nodes_cleared, "日志": session._tail_logs(2)}
# ★ D-08：离开黑市 = 这一格的事做完了 → 推进剂见底就追击战。
	if _接追击战(session, s):
		return ok
	session._set_screen("map")
	return ok

static func resolve_event_choice(session: GameSession, choice: String = "") -> Dictionary:
	return session._record_action("resolve_event_choice", {"choice": choice}, _结算奇遇(session, choice))

static func event_choose(session: GameSession, choice: String = "") -> Dictionary:
	return resolve_event_choice(session, choice)

static func _结算奇遇(session: GameSession, choice: String = "") -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
# ★ 2026-10-18（作者试玩反馈第 3 条）：**同一格只结算一次**（与休整同一口径）。
	var 键 := session.当前节点结算键()
	if session._已结算节点键.has(键):
		return session._fail("当前节点已结算完毕", {"ok": false, "键": 键, "节点": "事件"})
	var r := NodeResolver.结算奇遇(s, choice)
	if not bool(r.get("ok", false)):
		return session._fail(str(r.get("why", "这个事件结算不了")), {"ok": false})
	session._已结算节点键[键] = true
	r["节点"] = "事件"
	session._node_result = r
	session.last = {"行动": "事件", "事件": str(r.get("事件", "")), "选": str(r.get("选", "")),
		"结果": str(r.get("结果", "")), "日志": session._tail_logs(3)}
# ★ D-06：事件结算**不产生待选战术牌**（JS 只有招募 / 晋升两处产生）。
	if _接追击战(session, s):
		return r
	session._set_screen("map")
	return r

## 这一格事件的选项文字（纯读
static func current_event_choices(session: GameSession) -> Array:
	var s := session._need_run()
	if s == null:
		return []
	var 事 := NodeResolver.当前事件(s)
	var out: Array = []
	var 选项们: Array = 事.get("选") if 事.get("选") is Array else []
	for i in 选项们.size():
		var 条: Variant = 选项们[i]
		out.append({"序": i, "文": str((条 as Dictionary).get("文", "")) if 条 is Dictionary else str(条)})
	return out
