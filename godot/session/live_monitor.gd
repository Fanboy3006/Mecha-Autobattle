## 会话门面的「一之三 实时监视」子模块 —— 动作历史记录 + 完整局面快照（纯观测，不改任何业务规则与返回值）。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionLiveMonitor
extends RefCounted

static func snapshot_for_monitor(session: GameSession) -> Dictionary:
	session._data_ready()
	if session._在看快照:
		return {"screen": session.screen, "modal": "", "is_quick_battle": session._quick_battle,
			"in_battle": session.in_battle(), "errors": [], "重入": true}
	session._在看快照 = true
	var 快 := {
		"screen": session.screen,
		"modal": str(session.modal.get("类型", "")),
		"is_quick_battle": session._quick_battle,
		"in_battle": session.in_battle(),
		"errors": session.errors.slice(maxi(0, session.errors.size() - 20)).duplicate(),
		"当前错误": session._当前错误,
	}
	var s := session.run_state
	if s != null:
		快["seed"] = s.seed_val
		快["squad"] = s.squad
		快["status"] = s.status
		快["floor"] = s.floor_num
		快["pos"] = s.node_id
		快["propellant"] = "%d/%d" % [s.propellant, s.propellant_max]
		快["hope"] = s.hope
		快["carbon"] = s.carbon
		快["base_hp"] = s.base_hp
		快["commander_lv"] = s.level
		快["deploy_cap"] = RosterManager.deploy_limit(s)
		快["tickets"] = _监控券表(session, s)
		快["pending_card_picks"] = _监控待选牌(session, s)
		快["roster"] = _监控名册(session, s)
		快["lineup"] = _监控编队(session, s)
		快["relics"] = _监控藏品(session, s)
		快["parts"] = _监控零件(session, s)
	if not session.battle_ctx.is_empty():
		var 名册: Array = []
		var 敌: Array = []
		_收在场(session, 名册, "allies")
		_收在场(session, 敌, "enemies")
		快["turn"] = int(float(session.battle_ctx.get("turn", 0.0)))
		快["result"] = session.战果文字()
		快["policy"] = str((session.battle_ctx.get("方针") as Dictionary).get("类型", "")) if session.battle_ctx.get("方针") is Dictionary else ""
		快["allies"] = 名册
		快["enemies"] = 敌
		快["recent_battle_log"] = session.battle_log_lines(40)
	session._在看快照 = false
	return 快

## 待决定招募券：每张的 `id` / `名` / `类型`
static func _监控券表(session: GameSession, s: RunState) -> Array:
	var out: Array = []
	for 券 in s.tickets:
		if 券 is Dictionary:
			out.append({"id": int(券.get("id", 0)), "名": RosterManager.券名(券), "类型": str(券.get("类", ""))})
		else:
			out.append({"id": 0, "名": str(券), "类型": ""})
	return out

## 待三选一：次数（候补张数）+ 当前 3 张候选**牌名**
static func _监控待选牌(session: GameSession, s: RunState) -> Dictionary:
	var 名们: Array = []
	for id in s.pending_card_picks:
		var c := DeckBuilder.找到(str(id))
		名们.append(str(c.get("名", id)))
	return {"次数": s.pending_card_picks.size(), "候选": 名们}

## 名册简述：`键(Lv等级 HP百分比%)`
static func _监控名册(session: GameSession, s: RunState) -> Array:
	var out: Array = []
	for k in s.roster.keys():
		var 键 := str(k)
		out.append("%s(Lv%d HP%d%%)" % [键, s.get_unit_level(键),
			int(JsCompat.js_round(s.get_unit_hp_ratio(键) * 100.0))])
	return out

## 当前编队上阵格位映射（`位号 -> 机体键(名)`）
static func _监控编队(session: GameSession, s: RunState) -> Dictionary:
	var out := {}
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var 键 := str(x.get("key", ""))
		if 键.is_empty():
			continue
		out[session._条位号(x)] = "%s(%s)" % [键, _监控名(session, 键)]
	return out

## 藏品数 + 名字列表
static func _监控藏品(session: GameSession, s: RunState) -> Dictionary:
	var 名们: Array = []
	for id in s.relics:
		名们.append(RelicSystem.名(str(id)))
	return {"数": s.relics.size(), "名": 名们}

static func _监控零件(session: GameSession, s: RunState) -> Dictionary:
	var 名们: Array = []
	for i in s.parts.size():
		var 键 := PartSystem.part_key(s.parts[i])
		var 信 := PartSystem.part_info(键)
		名们.append("#%d %s" % [i, str(信.get("名", 键)) if not 信.is_empty() else 键])
	return {"数": s.parts.size(), "名": 名们}

static func _收在场(session: GameSession, out: Array, 池名: String) -> void:
	var 池: Variant = session.battle_ctx.get(池名)
	if not (池 is Array):
		return
	for u in (池 as Array):
		if not (u is Dictionary):
			continue
		out.append("%s:%s:%d/%d" % [Fm.位名(float(u.get("slot", 0.0))),
			str(u.get("name", u.get("key", ""))),
			int(JsCompat.js_round(float(u.get("hp", 0.0)))), int(JsCompat.js_round(float(u.get("maxHp", 0.0))))])

## 机体键 → 显示名（读纯目录
static func _监控名(session: GameSession, 键: String) -> String:
	if 键.is_empty():
		return ""
	var 模 := RosterManager.模板(键)
	return str(模.get("名", 键))

static func _record_action(session: GameSession, act: String, args: Dictionary, res: Variant) -> Variant:
	session._action_seq += 1
	# ★ IT-3：`res` 先算完才传进来；本次没做成就留着本次的原因，做成了才清。
	if not _是失败(res):
		session._当前错误 = ""
	var entry := {
		"seq": session._action_seq, "kind": "action", "action": act,
		"args": args, "result": res, "state": snapshot_for_monitor(session),
	}
	session.action_history.append(entry)
	while session.action_history.size() > GameSession.动作历史上限:
		session.action_history.remove_at(0)
	session.action_recorded.emit(entry)
	return res

## 动作结果算不算「没做成」：`false`，或 `{"ok": false}`。
static func _是失败(res: Variant) -> bool:
	if res is bool:
		return not bool(res)
	if res is Dictionary:
		return (res as Dictionary).get("ok", true) == false
	return false
