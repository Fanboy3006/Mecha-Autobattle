## 职责：版面门禁：战报栏与播报层（段 5 实时监视与全动作记录 / 段 11 UX-3 动作播报条与战斗动画层）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起5: int = t.passes + t.fails
	await _段5_实时监视与全动作记录(t, 根)
	var 段5: int = t.passes + t.fails - 起5
	var 起11: int = t.passes + t.fails
	await _段11_UX3战斗动画层(t, 根)
	var 段11: int = t.passes + t.fails - 起11
	t.info("★ 版面门禁（本套）：段 5（实时监视与全动作记录）%d 项 · 段 11（UX-3 动作播报条与战斗动画层）%d 项 · 合计 %d 项" % [段5, 段11, 段5 + 段11])

func _段5_实时监视与全动作记录(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 5：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)

	# ---- 5a：信号 + 历史容器就在门面上（初始态） ----
	t.ok(s.has_signal("action_recorded"), "★ 段 5：`GameSession` 有 `action_recorded(entry)` 信号")
	t.ok(s.action_history is Array and s.action_history.is_empty(),
		"★ 段 5：新会话 `action_history` 是空数组（0 条）")
	var 收到: Array = []
	var 回调 := func(e): 收到.append(e)
	s.action_recorded.connect(回调)

	# ---- 5b：全新会话的裸快照也拿得到（不崩、字段齐） ----
	var 空快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["screen", "modal", "is_quick_battle", "in_battle", "errors"]:
		t.ok(空快.has(名), "★ 段 5：全新会话快照含顶层字段「%s」（screen = %s）" % [名, str(空快.get("screen", ""))])
	t.ok(not 空快.has("tickets") and not 空快.has("roster"),
		"★ 段 5：没有局时快照**不瞎编**局字段（tickets / roster 都不在）")

	# ---- 5c：开局 → 快照字段齐 + 记了一条 ----
	var 前条数 := s.action_history.size()
	var 开了: bool = s.start_new_run(20261031, "混编")
	t.ok(开了 and s.run_state != null, "★ 段 5：`start_new_run` 照旧开得出局（返回 %s）" % str(开了))
	t.ok(s.action_history.size() == 前条数 + 1, "★ 段 5：开局之后 `action_history` %d → %d 条（自动追加 1 条）"
		% [前条数, s.action_history.size()])
	var 记0: Dictionary = s.action_history[s.action_history.size() - 1]
	t.ok(int(记0.get("seq", 0)) == s.action_history.size() and str(记0.get("kind", "")) == "action",
		"★ 段 5：最新一条 = `seq %d` / `kind \"action\"`（序号从 1 开始严格递增）" % int(记0.get("seq", 0)))
	t.ok(str(记0.get("action", "")) == "start_new_run", "★ 段 5：动作名 `start_new_run`（真实值「%s」）" % str(记0.get("action", "")))
	var 参0: Dictionary = 记0.get("args", {})
	t.ok(int(参0.get("seed_val", 0)) == 20261031 and str(参0.get("squad", "")) == "混编",
		"★ 段 5：参数原样记下（%s）" % JSON.stringify(参0))
	t.ok(记0.get("result") == true, "★ 段 5：返回结果原样记下（%s）" % str(记0.get("result")))
	t.ok(收到.size() >= 1 and str((收到[收到.size() - 1] as Dictionary).get("action", "")) == "start_new_run",
		"★ 段 5：`action_recorded` 信号真的发了（收到 %d 条，最新「%s」）"
		% [收到.size(), str((收到[收到.size() - 1] as Dictionary).get("action", ""))])
	# ---- 5d：有局快照的关键字段 ----
	var 局快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["screen", "tickets", "roster", "lineup", "pending_card_picks", "relics", "parts",
			"seed", "squad", "status", "floor", "pos", "propellant", "hope", "carbon",
			"base_hp", "commander_lv", "deploy_cap", "errors", "modal", "in_battle"]:
		t.ok(局快.has(名), "★ 段 5：有局快照含「%s」" % 名)
	t.ok(str(局快.get("screen", "")) == "map" and str(局快.get("status", "")) == "进行中",
		"★ 段 5：快照读得出屏与状态（screen = %s / status = %s）" % [str(局快.get("screen", "")), str(局快.get("status", ""))])
	t.ok(str(局快.get("propellant", "")) == "%d/%d" % [s.run_state.propellant, s.run_state.propellant_max],
		"★ 段 5：推进剂照 `当前/上限` 的写法报（%s）" % str(局快.get("propellant", "")))
	t.ok(int(局快.get("deploy_cap", 0)) > 0 and int(局快.get("commander_lv", 0)) >= 1,
		"★ 段 5：出击上限 %d / 部队等级 %d" % [int(局快.get("deploy_cap", 0)), int(局快.get("commander_lv", 0))])
	var 券表: Array = 局快.get("tickets", [])
	t.ok(券表.size() == s.run_state.tickets.size() and (券表.is_empty() or (券表[0] is Dictionary and 券表[0].has("id") and 券表[0].has("名") and 券表[0].has("类型"))),
		"★ 段 5：`tickets` = %d 张、每张都写清 `id` / `名` / `类型`（首张 %s）"
		% [券表.size(), JSON.stringify(券表[0]) if not 券表.is_empty() else "—"])
	t.ok(局快.get("lineup") is Dictionary, "★ 段 5：`lineup` 是「位号 → 机体键(名)」的字典（%s）" % JSON.stringify(局快.get("lineup")))

	# ---- 5e：招募 / 放弃券 / 选牌 都记 ----
	var 名册前 := s.roster_count()
	var 目标们 := s.available_recruit_targets(0)
	if 目标们.is_empty():
		t.ok(false, "★ 段 5：开局券招不到人 —— 招募那几条断言跑不了")
	else:
		var 键 := str((目标们[0] as Dictionary).get("键", ""))
		var 招 := s.recruit_unit(键, 0)
		t.ok(bool(招.get("ok", false)) and s.roster_count() == 名册前 + 1,
			"★ 段 5：招募 %s 成功（名册 %d → %d）" % [键, 名册前, s.roster_count()])
		var 招记: Dictionary = s.action_history[s.action_history.size() - 1]
		t.ok(str(招记.get("action", "")) == "recruit_unit" and bool((招记.get("result") as Dictionary).get("ok", false)),
			"★ 段 5：`recruit_unit` 记了一条（seq %d，result.ok = %s）"
			% [int(招记.get("seq", 0)), str((招记.get("result") as Dictionary).get("ok", false))])
		# 快照里的名册 / 编队 / 待选牌都要跟着变
		var 招快: Dictionary = 招记.get("state", {})
		t.ok(int(招快.get("roster", []).size()) == s.roster_count(),
			"★ 段 5：那一条记录里的快照名册 %d 台 == 现值 %d 台（快照是「这一步做完」的局面）"
			% [(招快.get("roster", []) as Array).size(), s.roster_count()])
		t.ok(int((招快.get("pending_card_picks", {}) as Dictionary).get("次数", 0)) == s.run_state.pending_card_picks.size(),
			"★ 段 5：快照的 `pending_card_picks.次数` = %d（与 `run_state` 一致）"
			% int((招快.get("pending_card_picks", {}) as Dictionary).get("次数", 0)))
		# 三选一：把候选选掉 → 记一条
		if not s.run_state.pending_card_picks.is_empty():
			var 选 := s.pick_tactical_card(str(s.run_state.pending_card_picks[0]))
			t.ok(选 and str(s.action_history[s.action_history.size() - 1].get("action", "")) == "pick_tactical_card",
				"★ 段 5：`pick_tactical_card` 记了一条（返回值 %s）" % str(选))
	# 放弃券（还有券才验；没有就明说不跑）
	if s.ticket_count() > 0:
		var 券前 := s.ticket_count()
		var 丢 := s.discard_ticket(0)
		t.ok(bool(丢.get("ok", false)) and s.ticket_count() == 券前 - 1,
			"★ 段 5：放弃 1 张券（%d → %d）" % [券前, s.ticket_count()])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "discard_ticket",
			"★ 段 5：`discard_ticket` 记了一条")

	# ---- 5f：编队（上阵 / 撤下 / 清空）都记 ----
	if not s.run_state.roster.is_empty():
		var 首键 := str(s.run_state.roster.keys()[0])
		var 位名 := str(s.lineup_slots()[0].get("位名", ""))
		s.set_lineup_slot(首键, 位名)
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "set_lineup_slot",
			"★ 段 5：`set_lineup_slot` 记了一条（%s → %s）" % [首键, 位名])
		t.ok(s.run_state.lineup.size() >= 1 and not (s.snapshot_for_monitor().get("lineup", {}) as Dictionary).is_empty(),
			"★ 段 5：上阵之后快照 `lineup` 非空（%s）" % JSON.stringify(s.snapshot_for_monitor().get("lineup", {})))
		s.remove_from_lineup(首键)
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "remove_from_lineup",
			"★ 段 5：`remove_from_lineup` 记了一条")
		s.set_lineup_slot(首键, 位名)
		var 清 := s.clear_lineup()
		t.ok(清 and s.run_state.lineup.is_empty(),
			"★ 段 5：`clear_lineup` 清空出击名单（返回值 %s、出击 %d 条）" % [str(清), s.run_state.lineup.size()])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "clear_lineup",
			"★ 段 5：`clear_lineup` 记了一条")
		t.ok(not s.clear_lineup() and str(s.action_history[s.action_history.size() - 1].get("action", "")) == "clear_lineup",
			"★ 段 5：本来就空时 `clear_lineup` 回 false —— **失败也照记**（监视侧才知道「为什么没反应」）")
		s.set_lineup_slot(首键, 位名)

	# ---- 5g：大地图（走一格）也记，且快照里 pos / propellant 跟着变 ----
	_清券(s)
	var 起点 := s.run_state.node_id
	var 下一 := _找相邻落脚点(s, _找战斗格(s)) if _找战斗格(s) >= 0 else -1
	if 下一 >= 0:
		var 走 := s.move_to_cell(下一)
		t.ok(bool(走.get("ok", false)) or s.screen == "battle",
			"★ 段 5：`move_to_cell(%d)` 记了一条（ok = %s / 屏 = %s）" % [下一, str(走.get("ok", false)), s.screen])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "move_to_cell",
			"★ 段 5：动作名是大写原样的 `move_to_cell`（别名 `move_to` 也走同一条记录：%s）"
			% str(s.move_to(下一).get("ok", false)))

	# ---- 5h：战斗四连（开战 / 打牌 / 推回合 / 自动打完 / 结算）都记 ----
	await _关弹窗(boot)
	if s.run_state != null:
		s.run_state.pending_card_picks = []
	var 快前: Dictionary = s.snapshot_for_monitor()
	# ★ RT-3b：改用双入口里的新入口（自动开单机牌组 + 秘银五人），动作名随之变成
	#   `start_quick_test_battle`（旧 `start_quick_battle` 开出来的那场没有牌，四连里打牌那一步会缺）。
	t.ok(s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013), "★ 段 5：`开始快速测试战斗` 开起来了")
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "start_quick_test_battle",
		"★ 段 5：`开始快速测试战斗` 记了一条")
	var 战快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["turn", "result", "policy", "allies", "enemies", "recent_battle_log"]:
		t.ok(战快.has(名), "★ 段 5：战斗中快照含「%s」" % 名)
	t.ok(bool(战快.get("in_battle", false)) and int(战快.get("turn", 0)) >= 1,
		"★ 段 5：战斗中快照 `in_battle = true`、回合 %d" % int(战快.get("turn", 0)))
	t.ok((战快.get("allies", []) as Array).size() > 0 and (战快.get("enemies", []) as Array).size() > 0,
		"★ 段 5：`allies` %d 行 / `enemies` %d 行（位号:名:HP/最大HP；首行我方「%s」、敌方「%s」）"
		% [(战快.get("allies", []) as Array).size(), (战快.get("enemies", []) as Array).size(),
			str((战快.get("allies", []) as Array)[0]) if not (战快.get("allies", []) as Array).is_empty() else "—",
			str((战快.get("enemies", []) as Array)[0]) if not (战快.get("enemies", []) as Array).is_empty() else "—"])
	# ★ RT-3b-4：`morale`（气势）那一栏已经从快照里删掉 —— 气势整个退役，快照不再报一个恒 0 的数值。
	# ★ RT-4：`hand` / `playable_now` / `reserve_count` 也随旧手牌只读口子一起删掉了（恒空 / 恒 0）。
	var 能打: Array = (s.upper_hand_cards() + s.lower_hand_cards()).filter(
		func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	if not 能打.is_empty():
		var 首牌: Dictionary = 能打[0]
		var 区 := str(首牌.get("区", ""))
		var 打: Dictionary = {}
		if 区 == GameSession.单机区_主武器:
			打 = s.打出主武器卡(str(首牌.get("手牌键", "")))
		elif 区 == GameSession.单机区_副武器:
			打 = s.打出副武器(str(首牌.get("手牌键", "")))
		elif 区 == GameSession.单机区_衍生:
			打 = s.打出衍生攻击卡(str(首牌.get("手牌键", "")))
		else:
			打 = s.打出精神或公有牌(str(首牌.get("手牌键", "")))
		var 动作 := str(s.action_history[s.action_history.size() - 1].get("action", ""))
		t.ok(bool(打.get("ok", false)) and 动作.begins_with("play_"),
			"★ 段 5：单机牌组的出牌口子也走 `_record_action`（打的是【%s】，动作 `%s`）"
			% [str(s.last.get("牌", "")), 动作])
	s.step_battle_turn()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "step_battle_turn",
		"★ 段 5：`step_battle_turn` 记了一条（现在回合 %d）" % int(float(s.battle_ctx.get("turn", 1.0))))
	s.auto_finish_battle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "auto_finish_battle",
		"★ 段 5：`auto_finish_battle` 记了一条（结果「%s」）" % s.战果文字())
	t.ok((s.snapshot_for_monitor().get("recent_battle_log", []) as Array).size() > 0,
		"★ 段 5：快照 `recent_battle_log` 有 %d 行战斗日志"
		% (s.snapshot_for_monitor().get("recent_battle_log", []) as Array).size())
	var 结 := s.finish_battle_and_settle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "finish_battle_and_settle",
		"★ 段 5：`finish_battle_and_settle` 记了一条（屏 = %s）" % s.screen)
	# 幂等那一条也要记（失败照记）
	s.finish_battle_and_settle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "finish_battle_and_settle",
		"★ 段 5：重复结算（幂等闸拒绝）**也记一条** —— 监视侧看得见「为什么这次没结算」")
	t.ok(not 快前.is_empty() and str(快前.get("screen", "")) != str(s.snapshot_for_monitor().get("screen", "")),
		"★ 段 5：从「%s」一路走到「%s」，快照的屏真的跟着变"
		% [str(快前.get("screen", "")), str(s.snapshot_for_monitor().get("screen", ""))])

	# ---- 5i：上限 100 条 + 序号严格递增 + 信号条数对得上 ----
	var 已记 := s.action_history.size()
	t.ok(已记 > 0 and int(s.action_history[0].get("seq", 0)) == 1,
		"★ 段 5：历史第 1 条的 `seq` = %d（从 1 开始；现在共 %d 条）" % [int(s.action_history[0].get("seq", 0)), 已记])
	var 递增 := true
	for i in range(1, 已记):
		if int(s.action_history[i].get("seq", 0)) != int(s.action_history[i - 1].get("seq", 0)) + 1:
			递增 = false
	t.ok(递增, "★ 段 5：`action_history` 里 `seq` 一条接一条严格 +1（%d 条都连着）" % 已记)
	# 再灌 120 次开局，逼出上限
	for i in 120:
		s.start_new_run(3000000 + i, "混编")
	t.ok(s.action_history.size() == 100,
		"★ 段 5：灌到 120 条之后 `action_history` 仍是 **%d 条**（上限 100，超了丢最老）" % s.action_history.size())
	t.ok(s.action_history.size() == 100 and int(s.action_history[99].get("seq", 0)) - int(s.action_history[0].get("seq", 0)) == 99,
		"★ 段 5：留的是**最近** 100 条（首条 seq = %d、末条 seq = %d）"
		% [int(s.action_history[0].get("seq", 0)), int(s.action_history[s.action_history.size() - 1].get("seq", 0))])
	t.ok(收到.size() == int(s.action_history[s.action_history.size() - 1].get("seq", 0)),
		"★ 段 5：`action_recorded` 发的条数（%d）== 最后一条的 `seq`（每个动作恰好发一次）" % 收到.size())

	# ---- 5j：★ 记录**不改返回值**（与「私下直调内部实现」逐字对账） ----
	var 甲 := GameSession.new()
	var 乙 := GameSession.new()
	var 甲开 := 甲._开始新局(20261031, "混编")
	var 乙开 := 乙.start_new_run(20261031, "混编")
	t.ok(甲开 == 乙开 and JSON.stringify(甲.last) == JSON.stringify(乙.last),
		"★ 段 5：包一层之后 `start_new_run` 的返回值与 `last` 与内部实现**逐字相同**（%s）" % str(乙开))
	var 甲走 := 甲._走一格(2)
	var 乙走 := 乙.move_to_cell(2)
	t.ok(JSON.stringify(甲走) == JSON.stringify(乙走),
		"★ 段 5：`move_to_cell` 包一层前后返回值逐字相同（%s）" % JSON.stringify(乙走).substr(0, 60))
	t.ok(甲.action_history.is_empty() and 乙.action_history.size() == 2,
		"★ 段 5：只有**公开口子**才记（甲 0 条 = 走的都是内部实现；乙 2 条 = 开局 + 走一格）")

	s.action_recorded.disconnect(回调)
	_拆boot(树根, 舱)

# 段 6：★ 2026-10-18 作者试玩反馈第 1 / 3 条 —— 战前强制编队确认 + 顶栏锁死 + 战斗孤儿守卫
#   ① 走上战斗格 → 进的是 `formation` 战前确认态（不是直接开打）：标题醒目、开始战斗按钮可见、
#      回地图按钮**藏起来**；点【确认编队 · 开始战斗】→ 才进 `battle`；
#   ② 战斗中顶栏「招募按钮 / 编队按钮」都置灰，`boot.去屏("formation")` 被守卫拦下
#      （不许把战斗打一半切去编队屏 → 孤儿战斗死锁）。

func _段11_UX3战斗动画层(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 错误 := []
	t.ok(DataLoader.install(错误) and Db.installed, "★ 段 11：数据已装入 Db（%d 条错误）" % 错误.size())
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段11.json"
	# ★ RT-3b：改用双入口里的新入口 —— 旧入口那场战斗 `单机牌组_开 == false`，
	#   `Setup.打一回合()`（`Btl.结束我方回合`）会直接 return，推进几拍都没有任何战斗事件。
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261015):
		t.ok(false, "★ 段 11：开不出快速战斗 —— 本段跑不了")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	# ---------- ① 两个新节点真的在 ----------
	var 播报 = v.find_child("动作播报条", true, false)
	t.ok(播报 is Label, "★★ 段 11：战斗屏里有《动作播报条》（Label，`find_child(\"动作播报条\")`）")
	t.ok(播报 is Label and str((播报 as Label).text).contains("【战斗开始】"),
		"★★ 段 11 ①：开战初始播报条写着「【战斗开始】等待推进下一拍或点击自动播放」（%s）"
		% (str((播报 as Label).text) if 播报 is Label else "—"))
	var 层 = v.find_child("战斗动画层", true, false)
	t.ok(层 is Control, "★★ 段 11：战斗屏里有《战斗动画层》（Control）")
	t.ok(层 is Control and (层 as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"★★ 段 11：动画层 `mouse_filter == MOUSE_FILTER_IGNORE`（纯表现，不吃鼠标事件）")
	t.ok(层 is Control and (层 as Control).get_parent() == v,
		"★★ 段 11：动画层是「战斗屏」的**直接子节点**（不进任何 Container → 不参与自动排版、不挤占版面）")
	t.ok(层 != null and 层.get("active_trajectories") is Array and 层.get("active_popups") is Array,
		"★★ 段 11：动画层暴露 `active_trajectories: Array` 与 `active_popups: Array`（测试直接查它）")
	# ---------- ② 版面：播报条自身不出画布、不压手牌栏 / 战报栏 ----------
	await _等帧(1)
	var 播框 := _框(v, "动作播报条")
	var 手框 := _框(v, "手牌栏")
	var 报框 := _框(v, "战报栏")
	t.ok(播框.size.x > 0.0 and _在界内(播框), "★★ 段 11：播报条 %s 完全落在 1280×720 内（不把版面顶出画布）" % _短(播框))
	t.ok(播框.size.y > 0.0 and 播框.size.y <= 26.5,
		"★★ 段 11：播报条是**紧凑单行横条**（高 %.0f ≤ 26px）—— 不会把底部手牌栏挤出 720 底边" % 播框.size.y)
	t.ok(手框.size.x > 0.0 and _在界内(手框) and 报框.size.x > 0.0 and _在界内(报框),
		"★★ 段 11：手牌栏 %s / 战报栏 %s 仍然完全落在 1280×720 内" % [_短(手框), _短(报框)])
	t.ok(not _叠(播框, 手框) and not _叠(播框, 报框),
		"★★ 段 11：播报条与手牌栏 / 战报栏互不重叠（交面积 %.0f / %.0f）" % [_交面积(播框, 手框), _交面积(播框, 报框)])
	t.ok(层 is Control and (层 as Control).get_global_rect().size.x > 0.0,
		"★ 段 11：动画层覆盖整块战斗屏（%s）—— 弹道可以画在任意两台机体之间" % _短((层 as Control).get_global_rect()))
	# ---------- ③ 推进一拍：播报条更新 + 弹道 / 飘字出现 + 卡片反馈更新 ----------
	var 初始文 := v.播报文本()
	var 有动作 := false
	var 轮 := 0
	# ★ RT-3b：原来这一拍是 `step_battle_turn()`（推进一回合）。单机牌组下「一回合」会跨**两个回合号**
	#   （敌方那一半 + 新回合的我方阶段初），而动画层只画**最后一个回合号**那一组事件
	#   （`_收窄到最后一拍`）—— 最后那一组全是「待入库 / 大招解锁」，一条攻击都没有。
	#   新模式真正的一拍是**一次出牌**（`_打单机卡()` 也是按这一拍演 0.5 秒），所以这里改打一张
	#   主武器卡：那一拍里一定有「攻击」日志。断言的意图（一拍 → 弹道 / 飘字 / 播报条）不变。
	while 轮 < 3 and not 有动作:
		轮 += 1
		var 能打: Array = s.upper_hand_cards().filter(
			func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)) \
				and str((c as Dictionary).get("区", "")) == GameSession.单机区_主武器)
		if 能打.is_empty():
			break
		s.打出主武器卡(str((能打[0] as Dictionary).get("手牌键", "")))
		v.refresh()
		await _等帧(2)
		var 轨: Array = 层.get("active_trajectories")
		var 飘: Array = 层.get("active_popups")
		有动作 = not 轨.is_empty() or not 飘.is_empty()
	t.ok(轮 <= 3 and 有动作, "★ 段 11：走了 %d 拍就抓到了本拍的战斗动画事件（不需要把整场打完）" % 轮)
	var 轨们: Array = 层.get("active_trajectories")
	var 飘们: Array = 层.get("active_popups")
	t.ok(有动作, "★★ 段 11 ②③：打一拍并 `refresh()` 之后，动画层记下了本拍的弹道 %d 条 / 飘字 %d 条"
		% [轨们.size(), 飘们.size()])
	var 播文 := v.播报文本()
	t.ok(not 播文.strip_edges().is_empty() and 播文 != 初始文,
		"★★ 段 11 ①：播报条已更新为本拍动作摘要（%s）" % 播文.substr(0, 96))
	var 有头 := false
	for 头 in ["【攻击】", "【大招】", "【修理】", "【战术牌】", "【势力】", "【镜甲】"]:
		if 播文.contains(str(头)):
			有头 = true
			break
	t.ok(有头, "★★ 段 11 ①：摘要用固定格式开头（【攻击】/【大招】/【修理】/【战术牌】/【势力】/【镜甲】）")
	t.ok(not (播文.contains("【攻击】") or 播文.contains("【大招】") or 播文.contains("【修理】")
			or 播文.contains("【战术牌】")) or 播文.contains("->"),
		"★★ 段 11 ①：摘要写出了「谁 -> 谁」的指向（含 `->`）")
	# 弹道结构：起点 / 终点槽位 + 颜色 + 类型 + alpha
	var 轨键齐 := true
	var 轨例 := ""
	for x in 轨们:
		if not (x is Dictionary):
			轨键齐 = false
			break
		for k in ["起点方", "起点位", "终点方", "终点位", "颜色", "类型", "alpha"]:
			if not (x as Dictionary).has(k):
				轨键齐 = false
		if 轨例.is_empty():
			轨例 = "%s〔%s·%s〕 -> %s〔%s·%s〕" % [str(x.get("类型", "")), str(x.get("起点方", "")),
				Fm.位名(float(x.get("起点位", 0.0))), str(x.get("类型", "")), str(x.get("终点方", "")),
				Fm.位名(float(x.get("终点位", 0.0)))]
	t.ok(not 轨们.is_empty() and 轨键齐,
		"★★ 段 11 ②：每条弹道都带 起点方 / 起点位 / 终点方 / 终点位 / 颜色 / 类型 / alpha（首条 %s）" % 轨例)
	var 飘键齐 := true
	var 飘例 := ""
	for x in 飘们:
		if not (x is Dictionary):
			飘键齐 = false
			break
		for k in ["文本", "颜色", "字号", "alpha"]:
			if not (x as Dictionary).has(k):
				飘键齐 = false
		if 飘例.is_empty():
			飘例 = str(x.get("文本", ""))
	t.ok(not 飘们.is_empty() and 飘键齐,
		"★★ 段 11 ③：每条飘字都带 文本 / 颜色 / 字号 / alpha（首条「%s」）" % 飘例)
	var 有伤害文 := false
	for x in 飘们:
		if x is Dictionary and (str(x.get("文本", "")).contains("-") or str(x.get("文本", "")).contains("未命中")
				or str(x.get("文本", "")).contains("+")):
			有伤害文 = true
			break
	t.ok(有伤害文, "★★ 段 11 ③：飘字里看得到「-伤害 / 未命中 / +耐久」这类数字（高对比度大字）")
	# 卡片反馈：弹道的起点（出手方）与终点（受击方）都留下了反馈状态
	var 起反 := 0
	var 终反 := 0
	var 反馈种类: Array = []
	for x in 轨们:
		if not (x is Dictionary):
			continue
		var 起卡 := _卡Of(v, str(x.get("起点方", "")), int(float(x.get("起点位", -1.0))))
		var 终卡 := _卡Of(v, str(x.get("终点方", "")), int(float(x.get("终点位", -1.0))))
		if 起卡 != null and not str(起卡.combat_fx_kind()).is_empty():
			起反 += 1
			if not 反馈种类.has(str(起卡.combat_fx_kind())):
				反馈种类.append(str(起卡.combat_fx_kind()))
		if 终卡 != null and not str(终卡.combat_fx_kind()).is_empty():
			终反 += 1
			if not 反馈种类.has(str(终卡.combat_fx_kind())):
				反馈种类.append(str(终卡.combat_fx_kind()))
	t.ok(起反 > 0, "★★ 段 11 ②：出手方 `UnitCard` 有了动作反馈状态（%d 条弹道的起点卡都亮着；种类 %s）"
		% [起反, "、".join(反馈种类)])
	t.ok(终反 > 0, "★★ 段 11 ③：受击方 `UnitCard` 也有了动作反馈状态（%d 条弹道的终点卡）" % 终反)
	var 角标见 := false
	for c in v._我方卡:
		if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
			var 标 = (c as UnitCard).find_child("动作反馈标", true, false)
			角标见 = 标 is Label and (标 as Label).visible
			break
	if not 角标见:
		for c in v._敌方卡:
			if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
				var 标2 = (c as UnitCard).find_child("动作反馈标", true, false)
				角标见 = 标2 is Label and (标2 as Label).visible
				break
	t.ok(角标见, "★★ 段 11：出手 / 受击那张卡的右下角亮出〔出手〕/〔受击〕角标（`动作反馈标` 可见）")
	# ---------- ④ 再刷一次（没有新日志）：播报条不被清空、弹道留着 ----------
	var 拍文 := v.播报文本()
	v.refresh()
	await _等帧(1)
	t.ok(v.播报文本() == 拍文,
		"★ 段 11：没有新日志时再 `refresh()` 一次 → 播报条保留上一拍原文（不被清成空白）")
	t.ok((层.get("active_trajectories") as Array).size() == 轨们.size(),
		"★ 段 11：没有新日志时弹道数组不被乱动（%d 条）" % (层.get("active_trajectories") as Array).size())
	# ---------- ⑤ 版面门禁照旧：卡片不互压、都在 1280×720 内 ----------
	var 叠了 := 0
	var 出界 := 0
	for 排名 in ["我方阵型第0排", "我方阵型第1排", "敌方阵型第0排", "敌方阵型第1排"]:
		var 排 = v.find_child(排名, true, false)
		if 排 == null:
			continue
		var 框们: Array = []
		for c in (排 as Node).get_children():
			if c is UnitCard:
				框们.append((c as Control).get_global_rect())
				if not _在界内((c as Control).get_global_rect()):
					出界 += 1
		for i in 框们.size():
			for j in range(i + 1, 框们.size()):
				if _叠(框们[i], 框们[j]):
					叠了 += 1
	t.ok(叠了 == 0 and 出界 == 0,
		"★★ 段 11：有动作反馈状态时，16 张单位卡仍然两两不重叠（重叠对数 %d）且全在 1280×720 内（出界 %d 张）"
		% [叠了, 出界])
	# ---------- ⑥ 换一场：播报条回到「【战斗开始】…」、动画层清干净 ----------
	if s.开始快速测试战斗(GameSession.快速测试_秘银, 20261016):
		v.refresh()
		await _等帧(2)
		t.ok(v.播报文本().contains("【战斗开始】"),
			"★★ 段 11：换一场新战斗 → 播报条回到「【战斗开始】…」（`_已播日志数` 归零重播；%s）" % v.播报文本())
		var 清空 := (层.get("active_trajectories") as Array).is_empty() and (层.get("active_popups") as Array).is_empty()
		t.ok(清空, "★★ 段 11：换一场新战斗 → 上一场的弹道 / 飘字被清干净（不留残影）")
		var 卡净 := true
		for c in v._我方卡:
			if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
				卡净 = false
		t.ok(卡净, "★★ 段 11：换一场新战斗 → 单位卡上的动作反馈也收干净了")
	else:
		t.ok(false, "★ 段 11：第二场快速战斗开不起来（换场那几条断言跑不了）")
	# ---------- ⑦ 静默：整段零报错、门面错误表干净 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 11：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆视图(树根, v)

func _卡Of(v: BattleView, 方: String, 位号: int) -> UnitCard:
	var 池: Array = v._我方卡 if (方 == "ally" or 方 == "我方") else v._敌方卡
	if 位号 < 0 or 位号 >= 池.size():
		return null
	var c: Variant = 池[位号]
	return c as UnitCard if (c is UnitCard) else null

# 段 12：★ DECK-2 / DECK-3 —— 单机牌组战斗屏（点选机体 + 战意条 + 上下双排手牌 + 0.5s 即时演出）
#
#   任务单 §3 验收门禁 断言 7 的表现层那一半：
#     ① 点选不同机体 → **上排专属牌整排切换**（主武器卡 / 衍生攻击卡 / 专属精神牌 三区）；
#     ② 下排公有牌**按职业 / 势力动态置灰与亮起**（`〔需：近卫〕` / `〔需：重装〕`、指挥机 -5 折后价）；
#     ③ 敌方 `UnitCard` 显示**意图预告**（内核 `Btl.算意图` 的逐台结果，且**没有任何压制射击**）；
#     ④ 我方被瞄准的机体卡有受威胁提示；
#     ⑤ 每打一张牌**立刻**播 0.5 秒一步的演出（复用 UX-5 的串行队列，headless 下同步播完帧数记满）；
#     ⑥ 控制栏在单机牌组模式下是「结束我方回合 / 全员自动回合 / 2x 加速 / 跳过本回演出 / 结束并结算」；
#     ⑦ 版面门禁照旧：上下双排 + 阵型区 + 战报栏都在 1280×720 内、两两不重叠、16 张单位卡不互压。
#
#   ★ 数据来源纪律：本段只读**门面**（`upper_hand_cards()` / `lower_hand_cards()` / `deck_turn_summary()` /
#     `select_battle_unit()` / `unit_view()`），断言的是「门面给的事实」与「视图把它排在哪」，
#     不在测试里另立第二套判据。
