## 会话门面的「五 战斗」重实现部分 —— 开战装配、试玩靶机、回合推进、战后结算与给券。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionBattleFlow
extends RefCounted

## 月球王国 / 影世界 v0.2.1 试玩版的快速编成（全员 Lv30）。
## 月球王国：Feena 在前排中间，阿布拉德 / 苏菲 / Iris 十字相邻（随侍 3），Nagi 在后排狙击位。
## 影世界：雷萨 / 比格特拉克在前排，拉米亚 / 蕾卡 / 维诺在后排（拉米亚是副势力，能打影世界牌）。
const 新势力快速编成 := {
	"月球王国": [
		{"键": "M2", "位": 0, "等级": 30}, {"键": "M1", "位": 1, "等级": 30}, {"键": "M5", "位": 2, "等级": 30},
		{"键": "M3", "位": 5, "等级": 30}, {"键": "M4", "位": 6, "等级": 30},
	],
	"影世界": [
		{"键": "B1", "位": 0, "等级": 30}, {"键": "B4", "位": 1, "等级": 30}, {"键": "A3", "位": 4, "等级": 30},
		{"键": "B2", "位": 5, "等级": 30}, {"键": "B3", "位": 6, "等级": 30},
	],
}

static func _新势力编成(阵容: String) -> Array:
	var out: Array = []
	for e in 新势力快速编成.get(阵容, []):
		out.append({"键": str(e["键"]), "等级": float(e["等级"]), "位": float(e["位"]), "hp比": 1.0})
	return out

static func _规范快速阵容(session: GameSession, 阵容: String) -> String:
	var 文 := str(阵容).strip_edges()
	if 新势力快速编成.has(文):
		return 文
	if 文.to_upper() == "ATX":
		return GameSession.快速测试_ATX
	if 文 == GameSession.快速测试_天人 or 文.to_upper() == "CELESTIAL" or 文.to_upper() == "CB":
		return GameSession.快速测试_天人
	return GameSession.快速测试_秘银

## ★ A7：这两个入口的**公共前置** 
static func _开快速测试战(session: GameSession, 阵容: String, seed_val: int) -> bool:
# ★ 第 5 项断路器修复（DS41F）：两个「快速测试」入口 = **全卡池体验** ——
	session._全卡池体验 = true
# ★ 第 7 项修复：这场战斗的 `run_state`（如果下面 `_开快速战` 顺手造了一个）是假的 ——
	session._快速测试局 = true
	return _开快速战(session, seed_val, 阵容)

static func _开快速战(session: GameSession, seed_val: int = 20261013, 阵容: String = "") -> bool:
	session._data_ready()
# ★ MITH3-4 / 任务单 §1.5：「5 人快速测试战斗」默认开**完整体验池** ——
	var 我方 := session._默认五人编成()
	if 阵容 == GameSession.快速测试_ATX:
		我方 = session._ATX五人编成()
	elif 阵容 == GameSession.快速测试_天人:
# ★ CB-4：天人五人（前排 刹那 / 阿雷路亚 / 拉塞，后排 洛克昂 / 提耶利亚）。
		我方 = session._天人五人编成()
	elif 新势力快速编成.has(阵容):
		我方 = _新势力编成(阵容)
	elif 阵容 == GameSession.快速测试_殖民卫星军:
# ★ COL-4：殖民卫星军五人（前排 迪奥 / 特洛瓦 / 拉克丝，后排 卡嘉莉 / 希罗）。
		我方 = session._殖民卫星军五人编成()
	else:
		我方 = session._秘银五人编成()
	if 我方.is_empty():
		session._fail("默认五人队读不到（数据没装好）", {"ok": false})
		return false
	var 条目: Dictionary = session._第几层普通编成(1)
	if 条目.is_empty():
		session._fail("编成表里没有第 1 层「普通」编成", {"ok": false})
		return false
	if session.run_state == null:
		session.run_state = RosterManager.new_run(seed_val, GameSession.默认分队)
# ★ 快速战斗也要把默认五人队填进名册：顶栏 / 结算屏的「名册」与「血比」才有内容可画。
	for 条 in 我方:
		var k := str((条 as Dictionary).get("键", ""))
		if k.is_empty() or session.run_state.roster.has(k):
			continue
		session.run_state.roster[k] = {"key": k, "lv": int(float((条 as Dictionary).get("等级", 10))), "hpRatio": 1.0}
		if session.run_state.lineup.size() < RosterManager.deploy_limit(session.run_state):
			session.run_state.lineup.append({"key": k, "slot": session._第一个空位(session._压实出击位(session.run_state))})
	session._quick_battle = true
	session._本场已结算 = false
	session._本场格类型 = ""
	session._血比战前 = session._名册血比()
	var 选项 := session._build_battle_options()
	var 种子 := seed_val + GameSession.快速战斗种子偏移
	var 敌方 := NodeResolver.编成到规格(条目, 0)
	选项["单位开关"] = session._unit_switches.duplicate(true)
	var ctx := Setup.开局(我方, 敌方, 种子, session._unit_switches.duplicate(true), 选项)
	if ctx.is_empty():
		session._fail("战斗内核没有给出 ctx", {"ok": false})
		return false
	session.battle_ctx = ctx
	session._unit_switches = session.表(ctx, "选项")
	session._result_cache = {}
	session.selected_unit_id = ""
	for u in (ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 80.0
# ★ M2（试玩反馈修复）：从前这里把下排公有手牌**强行补抽到 6/6 满手** ——
	if session._快速测试局:
		_把敌机改成试玩靶机(session, ctx)
	session._选中默认机体()
	session.last = {"行动": "快速战斗", "种子": 种子, "我方": 我方.size(), "敌方": 敌方.size(),
		"日志": session.battle_log_lines(3)}
# ★ A7：只有带阵容的那条路才多这一个键。
	if not 阵容.is_empty():
		session.last["阵容"] = 阵容
	session._set_screen("battle")
	return true

## ★ M4（试玩反馈修复）：把这一场的敌机改造成「高耐久、低攻击」试玩靶机
static func _把敌机改成试玩靶机(session: GameSession, ctx: Dictionary) -> void:
	if not (ctx.get("enemies") is Array):
		return
	ctx["波次"] = []
	for e in (ctx.get("enemies") as Array):
		if not (e is Dictionary):
			continue
		var u: Dictionary = e
		var 前排 := u.get("slot") != null and Fm.rowOfSlot(float(u.slot)) == Fm.ROW_FRONT
		var 重机 := str(u.get("mech", "")).contains("重") \
			or int(float(u.get("w", 1))) * int(float(u.get("h", 1))) >= 4
		var 血 := 20000.0
		if 前排:
			血 = 32000.0 if 重机 else 28000.0
		u["maxHp"] = 血
		u["hp"] = 血
		u["melee"] = 35.0
		u["shoot"] = 35.0
		var 武们: Variant = u.get("weapons")
		if 武们 is Array:
			for 条 in (武们 as Array):
				if not (条 is Dictionary) or not ((条 as Dictionary).get("t") is Dictionary):
					continue
				var w: Dictionary = ((条 as Dictionary).t as Dictionary).duplicate(true)
				w["power"] = maxf(200.0, roundi(float(w.get("power", 0.0)) * 0.35))
				(条 as Dictionary)["t"] = w
		var 名 := str(u.get("name", ""))
		if not 名.ends_with("·靶机"):
			u["name"] = 名 + "·靶机"
	_布置靶机援护(session, ctx)
# 数值变了 → 敌方意图（伤害预告）必须重算，否则战斗屏上的「预计」是改造前的数字。
	Btl.刷新敌方意图(ctx)
	Btl.pushLog(ctx, "〔快速测试〕敌方 %d 台全部换装「高耐久·低攻击」试玩靶机（波次清空）" % (ctx.enemies as Array).size(),
		{"类型": "试玩靶机", "台数": (ctx.enemies as Array).size()})

## ★ 2026-10-21（任务单问题 4）：「靶机先只保留 1 个援护设定」
static func _布置靶机援护(session: GameSession, ctx: Dictionary) -> void:
	if not (ctx.get("enemies") is Array):
		return
	var 敌们: Array = ctx.enemies
	if 敌们.size() < 2:
		return
# ---- ① 唯一的援护者 = 名字带「盾卫」的那台（找不到就退到第一台）----
	var 护者: Variant = null
	for e in 敌们:
		if e is Dictionary and str((e as Dictionary).get("name", "")).contains("盾卫"):
			护者 = e
			break
	if 护者 == null:
		护者 = 敌们[0]
	var 被护: Variant = null
	for e in 敌们:
		if e is Dictionary and not is_same(e, 护者) and str((e as Dictionary).get("name", "")).contains("突击兵"):
			被护 = e
			break
	if 被护 == null:
		for e in 敌们:
			if e is Dictionary and not is_same(e, 护者):
				被护 = e
				break
# 占着目标格的那台**与它换位**（绝不两台挤在同一格）。
	_靶机挪位(session, 敌们, 护者, 0)
	if 被护 != null:
		_靶机挪位(session, 敌们, 被护, 4)
# ---- (4) 援护次数只给援护者；其余靶机一律不许护卫 ----
	for e in 敌们:
		if not (e is Dictionary):
			continue
		if is_same(e, 护者):
			(e as Dictionary)["靶机援护剩余"] = 2
			(e as Dictionary)["靶机援护上限"] = 2
			(e as Dictionary).erase("禁用护卫")
		else:
			(e as Dictionary)["禁用护卫"] = true
			(e as Dictionary).erase("靶机援护剩余")
			(e as Dictionary).erase("靶机援护上限")
	Btl.pushLog(ctx, "〔快速测试〕靶机援护只留 1 条：%s（%s）→ 同列后排 %s（%s），每我方阶段 2 次" % [
		str((护者 as Dictionary).get("name", "")), Fm.位名(float((护者 as Dictionary).get("slot", 0.0))),
		str((被护 as Dictionary).get("name", "")) if 被护 != null else "—",
		Fm.位名(float((被护 as Dictionary).get("slot", 4.0))) if 被护 != null else "—"],
		{"类型": "试玩靶机", "援护上限": 2, "援护键": str((护者 as Dictionary).get("key", ""))})

## 把 `目标` 挪到 `位` 格：已经在那格 = 什么都不做
static func _靶机挪位(session: GameSession, 敌们: Array, 目标: Variant, 位: int) -> void:
	if not (目标 is Dictionary):
		return
	var 旧 := int(float((目标 as Dictionary).get("slot", -1.0)))
	if 旧 == 位:
		return
	for e in 敌们:
		if not (e is Dictionary) or is_same(e, 目标):
			continue
		if int(float((e as Dictionary).get("slot", -1.0))) == 位 and float((e as Dictionary).get("hp", 0.0)) > 0.0:
			(e as Dictionary)["slot"] = float(旧)
			break
	(目标 as Dictionary)["slot"] = float(位)

static func _开节点战(session: GameSession) -> bool:
	var s := session._need_run()
	if s == null:
		session._fail("还没有进行中的局", {"ok": false})
		return false
	if s.map_data.is_empty():
		session._fail("还没有大地图", {"ok": false})
		return false
# ★ D-08：脚下是「追击」→ 走追击战那条（编成用「追击」档、打完走 `after_chase_win`）。
	if str(s.map_data.get("当前节点类型", "")) == "追击":
		return session._开追击战(s, s.exit_chase)
	if NodeResolver.我方编成(s).is_empty():
		session._fail("出击名单是空的（先去招募并编队）", {"ok": false})
		return false
	var 格类型 := session._脚下类型(s)
	var 类型 := NodeResolver.战斗类型Of(s, 格类型)
	var rng := Mulberry32.new(NodeResolver.编成种子(s, s.floor_num))
	var 详情 := NodeResolver.抽编成兜底(s.floor_num, 类型, rng)
	if 详情.is_empty() or not (详情.get("条目") is Dictionary):
		session._fail("抽不到第 %d 层「%s」的编成" % [s.floor_num, 类型], {"ok": false})
		return false
	s.map_data["本场兜底"] = {"层": s.floor_num, "格": s.node_id, "到": str(详情.get("类型", 类型))} if 详情.get("兜底") != null else null
	var ctx := NodeResolver.开战(s, 详情["条目"], "", session._附加战斗选项())
	if ctx.is_empty():
		session._fail("战斗内核没有给出 ctx", {"ok": false})
		return false
	session._quick_battle = false
	session._全卡池体验 = false
	session._快速测试局 = false
	session._本场已结算 = false
	session._本场格类型 = 格类型
	session._血比战前 = session._名册血比()
	session.battle_ctx = ctx
	session._unit_switches = session.表(ctx, "选项")
	session._result_cache = {}
	session.selected_unit_id = ""
	session._选中默认机体()
	session.last = {"行动": "开战", "格类型": 格类型, "编成类型": str(详情.get("类型", 类型)),
		"编成层": int(详情.get("层", s.floor_num)), "兜底": 详情.get("兜底", null),
		"敌方": (ctx.get("enemies") as Array).size(), "我方": (ctx.get("allies") as Array).size(),
		"日志": session.battle_log_lines(3)}
	session._set_screen("battle")
	return true

static func _准备战前编队(session: GameSession, kind: String = "node") -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return session._fail("还没有大地图", {"ok": false})
	var 种 := "chase" if kind == "chase" else "node"
	session.pending_battle_confirm = true
	session.pending_battle_kind = 种
# ★ UX-4：进战前编队确认屏之前**先把 slot 规范成明确位号** —— 编队屏现在显示的站位，
	var 规范了 := session._规范编队槽位(s)
# ★ 一键自动补满：**只在出击名单为空时**动手（有名册 → 把还没上阵的按上限补进空位）。
	var 补了 := _自动补满编队(session, s)
	session.last = {"行动": "战前编队", "种类": 种, "格": s.node_id, "格类型": session._脚下类型(s),
		"出击": s.lineup.size(), "上限": RosterManager.deploy_limit(s), "自动补": 补了, "槽位规范": 规范了,
		"提示": "确认出击阵容，然后点【确认编队 · 开始战斗】"}
	session._set_screen("formation")
	return session.last

static func _确认编队开战(session: GameSession) -> Dictionary:
	var s := session._need_run()
	if s == null:
		return session._fail("还没有进行中的局", {"ok": false})
# ★ UX-4：开打前最后再规范一次槽位（程序直接调这个口子时也保证「编队屏 = 战场」）。
	session._规范编队槽位(s)
	if _出击存活数(session, s) < 1:
		return session._fail("请至少上阵 1 台机体", {"ok": false, "出击": s.lineup.size()})
	var 种 := session.pending_battle_kind if not session.pending_battle_kind.is_empty() else "node"
	session.pending_battle_confirm = false
	session.pending_battle_kind = ""
	if 种 == "chase":
		var ok := session._打追击战()
		if not ok and not session.in_battle():
			session._set_screen("map")
		return session.last
	return session._进当前格()

## 出击名单里**活着**（名册血比 > 0）的台数
static func _出击存活数(session: GameSession, s: RunState) -> int:
	var n := 0
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var k := str(x.get("key", ""))
		if k.is_empty() or not s.roster.has(k):
			continue
		if float(s.get_unit_hp_ratio(k)) > 0.0:
			n += 1
	return n

static func _自动补满编队(session: GameSession, s: RunState) -> int:
	if not s.lineup.is_empty():
		return 0
	var 上限 := RosterManager.deploy_limit(s)
	if 上限 <= 0:
		return 0
	var 位表 := {}
	var 补 := 0
	for 键 in s.roster.keys():
		if s.lineup.size() >= 上限:
			break
		var k := str(键)
		if k.is_empty() or session._在出击里(s, k):
			continue
		var 位 := session._第一个空位(位表)
		s.lineup.append({"key": k, "slot": 位})
		位表[位] = k
		补 += 1
	return 补


static func _切开关(session: GameSession, unit_id: String, switch_key: String) -> bool:
	if session.battle_ctx.is_empty():
		session._fail("现在不在战斗里", {"ok": false})
		return false
	var u := session._找单位(unit_id)
	if u.is_empty():
		session._fail("这一方没有这台单位（%s）" % unit_id, {"ok": false, "单位": unit_id})
		return false
	var 位 := str(int(float(u.get("slot", -1))))
	if not session._unit_switches.has(位) or not (session._unit_switches[位] is Dictionary):
		session._unit_switches[位] = {}
	var 表条: Dictionary = session._unit_switches[位]
	var 值 := ""
	if switch_key == "保留大招":
		var 新: bool = not bool(u.get("holdUlt", false))
		表条["保留大招"] = 新
		值 = "开" if 新 else "关"
	else:
		session._fail("没有这个开关（%s）—— 真实内核只有「保留大招」" % switch_key, {"ok": false})
		return false
	Btl.设单位开关(session.battle_ctx, session._unit_switches)
	session.last = {"行动": "切开关", "单位": unit_id, "开关": switch_key, "值": 值,
		"开关表": session._unit_switches.duplicate(true), "状态行": session.unit_view("ally", unit_id).get("状态", [])}
	session._emit()
	return true


static func _打一回合(session: GameSession) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	if session.battle_ctx.get("result") != null:
		return session._fail("这一场已经打完了（%s）" % str((session.battle_ctx["result"] as Dictionary).get("结果", "")), {"ok": false})
	var 前回合 := int(float(session.battle_ctx.get("turn", 1.0)))
	Setup.打一回合(session.battle_ctx)
	var 后回合 := int(float(session.battle_ctx.get("turn", 1.0)))
	session.last = {"行动": "打一回合", "从回合": 前回合, "到回合": 后回合,
		"结果": session.战果文字(), "结算": session.battle_ctx.get("result", null),
		"日志": session.battle_log_lines(4)}
	session._emit()
	return session.last

static func _自动打完(session: GameSession) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	var 打了几回合 := 0
	if session.battle_ctx.get("result") == null:
		var 顶 := maxf(float(Db.T.get("MAX_TURN", 12.0)), float(session.battle_ctx.get("回合上限", 12.0))) + 2.0
		var 护栏 := 0.0
		while session.battle_ctx.get("result") == null and 护栏 < 顶:
			护栏 += 1.0
			打了几回合 += 1
			Setup.打一回合(session.battle_ctx)
		if session.battle_ctx.get("result") == null:
			session.battle_ctx["result"] = {"结果": "败", "原因": "超出回合上限"}
	session.last = {"行动": "自动打完", "回合数": 打了几回合, "结果": session.战果文字(), "结算": session.battle_ctx.get("result", null),
		"我方存活": session._存活数("ally"), "敌方存活": session._存活数("enemy"), "日志": session.battle_log_lines(4)}
	session._emit()
	return session.last

static func _结算这一场(session: GameSession) -> Dictionary:
	if session.battle_ctx.is_empty():
		return session._fail("现在不在战斗里", {"ok": false})
	if session.battle_ctx.get("result") == null:
		return session._fail("这一场还没打完（先 `auto_finish_battle()` 或 `step_battle_turn()`）", {"ok": false})
	if session._本场已结算:
		var 为什么 := "这一场已经结算过了（要再打请先走下一格 / 开下一场）"
		session._记错误(为什么)
		session.errored.emit(为什么)
		return {"ok": false, "为什么": 为什么, "屏幕": session.screen, "已结算": true}
	var s := session.run_state
	if s == null or session._quick_battle or s.map_data.is_empty():
		session._本场已结算 = true
		session._result_cache = session._build_result_cache({})
		session.last = {"行动": "结算", "结果": session.result_summary()}
		session._set_screen("result")
		return session.last["结果"]
	var 格类型 := session._本场格类型 if not session._本场格类型.is_empty() else session._脚下类型(s)
	session._血比战前 = session._名册血比()
# ★ 战后给券那一签用的场次：**取内核自增之前**的那一拍（`resolve_battle` 自己会 +1）。
	var 场次前 := int(s.battles_fought)
	var r := NodeResolver.resolve_battle(s, session.battle_ctx, 格类型)
	r["格类型"] = 格类型
	_战后按率给券(session, s, r, 场次前)
	session._result_cache = session._build_result_cache(r)
# 战斗之后：守军 / 追击要补上欠的换层；其他节点清空这一格。
	if 格类型 == "追击" and s.status != "失败":
		if not bool(r.get("胜", false)):
			r["追击结束"] = true
			r["甩掉追兵"] = true
			s.add_log("追击战没打赢，但甩掉了追兵")
		var 追 := MapNavigator.after_chase_win(s)
		r["追击换层"] = 追
		r["追击"] = true
	elif bool(r.get("胜", false)):
		if 格类型 == "出口守军":
			var 进 := MapNavigator.after_guard_win(s)
			r["换层"] = 进
		elif s.propellant <= 0:
			var 追2 := MapNavigator.after_chase_win(s)
			r["追击换层"] = 追2
			r["追击"] = true
		else:
			NodeResolver.清空格(s)
	else:
		if s.status != "失败":
			NodeResolver.清空格(s)
	session._result_cache["结算"] = r
	session._本场已结算 = true
	if 格类型 != "追击" and session._接追击战(s, true):
		return r
	session.last = {"行动": "结算", "结果": session.result_summary(), "内核": r}
	session._set_screen("result")
	return r

static func _战后按率给券(session: GameSession, s: RunState, r: Dictionary, 场次前: int) -> void:
	if s == null or r == null:
		return
# 本局已经结束（耐久耗尽 / 通关）→ 不掷。
	if s.status != "进行中":
		return
	var 券: Variant = r.get("券")
	var 有券 := 券 is Dictionary
	var roll := _战后给券掷签(session, s, 场次前)
	r["战后券掷"] = roll
	if roll < GameSession.战后给券率:
		if 有券:
# 内核已经给了 1 张 → 保留，**不重复发第 2 张**。
			r["券"] = 券
			r["券名"] = RosterManager.券名(券)
			return
		var 新券: Variant = RosterManager.发随机券(s, "战后")
		if 新券 is Dictionary:
			s.add_log("战斗结束：战后那一签给到了，获得【%s】" % RosterManager.券名(新券))
			r["券"] = 新券
			r["券名"] = RosterManager.券名(新券)
			r["补发券"] = true
		else:
# 券池已满 / 抽不出来 → 照实报「没有」。
			r["券"] = null
			r["券名"] = ""
		return
	if 有券:
		_撤回刚发的券(session, s, 券)
		r["券"] = null
		r["券名"] = ""
		r["撤券"] = true
# 没有券 → 什么都不用做。
	return

## 战后那一签的确定性掷点（`0.0 ≤ roll < 1.0`）
static func _战后给券掷签(session: GameSession, s: RunState, 场次前: int) -> float:
	var 种子 := int(s.seed_val) + int(s.floor_num) * 613 + int(场次前) * 37 + int(s.node_id) * 17 + 20261018
	var rng := Mulberry32.new(种子)
	return rng.next_float()

static func _撤回刚发的券(session: GameSession, s: RunState, 券: Variant) -> void:
	if s == null or not (券 is Dictionary):
		return
	var id := int((券 as Dictionary).get("id", -1))
	var 下标 := -1
	for i in s.tickets.size():
		var x: Variant = s.tickets[i]
		if x is Dictionary and int((x as Dictionary).get("id", -2)) == id:
			下标 = i
			break
	if 下标 < 0 and not s.tickets.is_empty():
		下标 = s.tickets.size() - 1
	if 下标 < 0:
		return
	s.tickets.remove_at(下标)
	s.add_log("战斗结束：战后那一签没给到，这一场不获得招募券")
