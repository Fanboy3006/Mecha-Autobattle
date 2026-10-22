## 会话门面的「六 展示辅助」子模块 —— 战报 / 单位卡 / 顶栏 / 结算摘要，以及末端「天人 v0.1 的表现层读法」（全部纯读）。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionDisplayHelpers
extends RefCounted

## 「我方现在有哪些机体」
static func _我方阵(session: GameSession) -> Array:
	if not session.battle_ctx.is_empty():
		var 我: Variant = session.battle_ctx.get("allies")
		if 我 is Array and not (我 as Array).is_empty():
			return 我
	var s := session.run_state
	var 出: Array = []
	if s == null or not Db.installed:
		return 出
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var 键 := str((x as Dictionary).get("key", ""))
		if 键.is_empty():
			continue
		var tpl := RosterManager.模板(键)
		var 名 := str(tpl.get("pilot", 键))
		var 标: Variant = tpl.get("tags")
		出.append({"key": 键, "slot": float(maxi(0, session._条位号(x))),
			"name": 名, "tags": 标, "hp": 1.0})
	return 出

static func mithril_link_state(session: GameSession) -> Dictionary:
	var 倍率 := int(session.battle_ctx.get("本回合连携触发倍率", 1))
	var 计: Dictionary = session.battle_ctx.get("战况计数") if session.battle_ctx.get("战况计数") is Dictionary else {}
	return {
		"启用": _ctx有秘银(session, session.battle_ctx),
		"本回合秘银牌数": int(session.battle_ctx.get("本回合秘银牌数", 0)),
		"连携倍率": 倍率,
		"双倍连携": 倍率 >= 2,
		"触发连携次数": int(计.get("触发连携", 0)),
		"打出TDD1数": int(计.get("打出TDD1", 0)),
	}

static func _ctx有秘银(session: GameSession, ctx: Dictionary) -> bool:
	if ctx.is_empty():
		return false
	var 我: Variant = ctx.get("allies")
	for u in (我 if 我 is Array else []):
		if not (u is Dictionary):
			continue
		var 键 := str((u as Dictionary).get("key", ""))
		if not 键.is_empty() and (键 in MithrilV03Cards.成员键):
			return true
		var 标签: Variant = (u as Dictionary).get("tags")
		if 标签 is Dictionary and str((标签 as Dictionary).get("势力", "")) == MithrilV03Cards.势力:
			return true
	return false

## 战斗日志文本行（纯读
static func battle_log_lines(session: GameSession, limit: int = 40) -> Array:
	if session.battle_ctx.is_empty():
		return []
	var 日志: Variant = session.battle_ctx.get("log")
	if not (日志 is Array):
		return []
	var 全: Array = 日志
	var 起 := 0 if limit <= 0 else maxi(0, 全.size() - limit)
	var out: Array = []
	for i in range(起, 全.size()):
		var e: Variant = 全[i]
		if e is Dictionary:
			out.append("[第 %d 回合] %s" % [int(float(e.get("回合", 0.0))), _单条战斗日志转文本(session, e)])
		else:
			out.append(str(e))
	return out

## ★ UX-2 第 1 项：**一条战斗日志的展示文本**
static func _单条战斗日志转文本(session: GameSession, e: Dictionary) -> String:
	var 文 := str(e.get("文本", ""))
	var 源 := str(e.get("来源文本", ""))
	if 源.is_empty() or 文.contains("来自："):
		return 文
	return "%s · %s" % [文, 源]

## 结构化日志（最近 `limit` 条，字典原样
static func battle_log_entries(session: GameSession, limit: int = 40) -> Array:
	if session.battle_ctx.is_empty():
		return []
	var 日志: Variant = session.battle_ctx.get("log")
	if not (日志 is Array):
		return []
	var 全: Array = 日志
	var 起 := 0 if limit <= 0 else maxi(0, 全.size() - limit)
	var out: Array = []
	for i in range(起, 全.size()):
		var e: Variant = 全[i]
		out.append((e as Dictionary).duplicate(true) if e is Dictionary else {"文本": str(e)})
	return out

static func unit_view(session: GameSession, side: String, unit_id: String) -> Dictionary:
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	if session.battle_ctx.is_empty():
		return {"ok": false, "为什么": "现在不在战斗里"}
	var 池: Variant = session.battle_ctx.get(方 + "s")
	if not (池 is Array):
		池 = session.battle_ctx.get("allies") if 方 == "ally" else session.battle_ctx.get("enemies")
	var u := {}
	for x in (池 as Array):
		if not (x is Dictionary):
			continue
		if str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id:
			u = x
			break
	if u.is_empty():
		return {"ok": false, "为什么": "这一方没有这台单位（%s）" % unit_id, "单位": unit_id}
	var 生命 := float(u.get("hp", 0.0))
	var 满 := float(u.get("maxHp", 1.0))
	if 满 <= 0.0:
		满 = 1.0
	var d := {
		"ok": true, "键": str(u.get("key", "")), "模板": str(u.get("tplKey", "")), "名": str(u.get("name", unit_id)),
		"方": 方, "位": int(float(u.get("slot", -1))), "位名": Fm.位名(float(u.get("slot", 0.0))),
		"职业": str(Reach.战斗分类Of(u)), "势力": str(Fac.势力名(u)),
		"等级": int(float(u.get("lv", 0.0))),
		"HP": 生命, "最大HP": 满, "血比": clampf(生命 / 满, 0.0, 1.0),
		"护盾": float(u.get("shield", 0.0)),
		"标定层数": int(Calc.标定经济层数(u)),
		"增益": _增益文字们(session, u.get("buffs")), "减益": _增益文字们(session, u.get("debuffs")),
		"状态": _状态行(session, 方, u), "开关": _开关行(session, u),
		"活着": 生命 > 0.0,
	}
# ★ COL-4b：觉醒徽章的类型（表现层按它配色：SEED 蓝 / ZERO 绿 / 隐身半透明）。
	if 方 == "ally" and ColonialV01.是殖民卫星军(u):
		var 觉型 := ColonialV01.当前觉醒类型(u)
		if 觉型 != "":
			d["觉醒类型"] = 觉型
# ★ DECK-2 / DECK-3：单机牌组模式下再补「战意 / 主武状态 / 选中 / 意图预告」这几样。
	if not session.battle_ctx.is_empty():
		d["战意"] = Btl.战意(u)
		d["战意上限"] = Params.战意上限()
		d["主武器已销毁"] = session._真(u.get("主武器已销毁"))
		d["主武器状态"] = "〔已打主武〕" if session._真(u.get("主武器已销毁")) else "〔主武就绪〕"
		var λ文 := DeckFlow.λ文案(u)
		d["λ状态"] = λ文
		d["λ觉醒"] = DeckFlow.λ觉醒(u)
		d["λ开启"] = DeckFlow.λ开启(u)
		d["力场"] = session._读数(u.get("shieldHp"))
		d["选中"] = (方 == "ally" and str(u.get("key", "")) == session.selected_unit_id)
		if Calc.九死一生_闪(u):
			d["闪"] = true
			d["本阶段轮转"] = Calc.九死一生_本阶段轮转(u)
# ★ A4：赌神开启中（响介身上）—— 同样只在真的开着时才加这个键，纯布尔 + 一个结算读数。
		if AtxGodsbet.是响介(u) and AtxGodsbet.赌神开启(session.battle_ctx):
			d["赌神"] = true
			d["赌神翻盘段数"] = AtxGodsbet.赌神本场翻盘段数(session.battle_ctx)
			d["赌神续注"] = float(AtxGodsbet.续注)
# ★ A5a：拉米亚的「烟雾」—— 该单位所在的那一列有雾才加这个键（纯表现，纯读）。
		if AtxSmoke.单位在雾里(session.battle_ctx, u):
			d["雾"] = true
			d["雾列"] = int(Fm.colOfSlot(float(u.slot))) + 1 if u.get("slot") != null else 0
# ★ A5b：武器「段数改写」槽 —— 只在真的挂着牌时才加这个键（预告层；空槽 = 快照一个字节都不多）。
		var 改写文 := AtxRewrite.槽文字(u)
		if 改写文 != "":
			d["改写"] = 改写文
		if 方 == "enemy":
			d["意图"] = session.unit_intent_lines("enemy", str(u.get("key", "")))
		else:
			d["威胁"] = session.unit_intent_lines("ally", str(u.get("key", "")))
	d["悬停说明"] = session._单位说明文字(方, u, true)
	return d

static func topbar_state(session: GameSession) -> Dictionary:
	session._data_ready()
	var s := session.run_state
	if s == null:
		return {"有局": false, "屏幕": session.screen}
	var 账 := MapGenerator.propellant_detail(s) if not s.map_data.is_empty() else {}
	var 门槛: Variant = RosterManager.升级门槛(s.level)
	return {
		"有局": true, "屏幕": session.screen, "层": s.floor_num, "状态": s.status,
		"当前格": s.node_id, "节点类型": str(s.map_data.get("当前节点类型", s.current_type())),
		"推进剂": s.propellant, "推进剂上限": s.propellant_max, "推进剂明细": 账,
		"源碳": s.carbon, "希望": s.hope,
		"基地耐久": s.base_hp, "基地最大耐久": s.base_max_hp,
		"等级": s.level, "经验": s.exp_val, "升级门槛": 门槛,
		"出击上限": RosterManager.deploy_limit(s), "出击数": s.lineup.size(),
		"名册数": s.roster.size(), "券数": s.tickets.size(),
		"藏品数": s.relics.size(), "藏品": s.relics.duplicate(),
		"零件数": s.parts.size(), "零件": s.parts.duplicate(true),
		"战术牌库": s.tactical_deck.duplicate(), "待选战术牌": s.pending_card_picks.duplicate(),
		"已清节点": s.nodes_cleared, "场次": s.battles_fought, "胜场": s.battles_won,
		"QTE模式": session.get_qte_mode(),
	}

## 结算面板的数据（三层反馈的「结算」那一层）：胜负 / 回血前后 / 战利品 / 战斗日志行数
static func result_summary(session: GameSession) -> Dictionary:
	session._data_ready()
	if session._result_cache.is_empty() and session.battle_ctx.is_empty() and session.run_state == null:
		return {"有结果": false}
	var r := session._result_cache
	var 结算: Dictionary = r.get("结算") if r.get("结算") is Dictionary else {}
	var 回血: Variant = r.get("回血", {})
	var 前: Dictionary = r.get("名册回血前", {})
	var 后 := session._名册血比()
	return {
		"有结果": not r.is_empty(),
		"胜": bool(r.get("胜", false)), "负": not bool(r.get("胜", false)),
		"结果": str(r.get("结果", "未知")), "原因": str(r.get("原因", "")),
		"回合数": int(r.get("回合数", 0)), "格类型": str(r.get("格类型", "")),
		"触发连携次数": int(r.get("触发连携次数", 0)),
		"打出TDD1数": int(r.get("打出TDD1数", 0)),
		"秘银v02": bool(r.get("秘银v02", false)),
		"通关": bool(r.get("通关", false)), "结束": bool(r.get("结束", false)),
		"耐久扣": int(r.get("扣", 0)),
		"战利品": {
			"希望": int(r.get("希望", 0)), "源碳": int(r.get("源碳", 0)),
			"券": r.get("券", null), "券名": RosterManager.券名(r["券"]) if r.get("券") is Dictionary else "",
			"藏品": r.get("藏品", null), "额外编制": r.get("额外编制", null), "零件": r.get("零件", null),
			"额外": r.get("额外", {}),
		},
		"回血": {
			"台数": int(回血.get("台数", 0)) if 回血 is Dictionary else 0,
			"回复比例": float(回血.get("回复比例", 0.0)) if 回血 is Dictionary else 0.0,
			"名字们": 回血.get("名字们", []) if 回血 is Dictionary else [],
			"文本": str(回血.get("文本", "")) if 回血 is Dictionary else "",
		},
		"血比前": 前, "血比后": 后,
		"带伤": int(r.get("带伤", 0)), "倒下": int(r.get("倒下", 0)), "奖励档": str(r.get("奖励档", "")),
		"换层": r.get("换层", {}), "冲击追击": bool(r.get("追击", false)),
		"战斗日志行数": battle_log_lines(session, 0).size(),
		"日志": session._tail_logs(4),
	}

static func _存活数(session: GameSession, 方: String) -> int:
	if session.battle_ctx.is_empty():
		return 0
	var 池: Variant = session.battle_ctx.get("allies") if 方 == "ally" else session.battle_ctx.get("enemies")
	if not (池 is Array):
		return 0
	var n := 0
	for u in (池 as Array):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			n += 1
	return n

static func _战果文字(session: GameSession) -> String:
	if session.battle_ctx.is_empty():
		return ""
	var r: Variant = session.battle_ctx.get("result")
	if r is Dictionary:
		return str(r.get("结果", ""))
	return ""

static func 战果文字(session: GameSession) -> String:
	return _战果文字(session)

static func _增益文字们(session: GameSession, v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for b in (v as Array):
		if not (b is Dictionary):
			continue
		var 段 := []
		段.append(str(b.get("src", "增益")))
		for k in b.keys():
			if k == "src" or k == "剩余":
				continue
			var 值: Variant = b[k]
			if 值 is int or 值 is float:
				段.append("%s %s%s" % [str(k), "+" if float(值) > 0.0 else "", str(int(JsCompat.js_round(float(值))))])
		out.append("：".join([段[0], "、".join(段.slice(1))]) if 段.size() > 1 else str(段[0]))
	return out

static func _状态行(session: GameSession, 方: String, u: Dictionary) -> Array:
	var out: Array = []
# ★ A2：ATX【九死一生】的「闪」先占一格（悬停说明里的「状态：…」也走这一行，一处改两处都看得到）。
	if Calc.九死一生_闪(u):
		out.append("闪")
# ★ A4：赌神开启中 → 状态行里一个「赌神」标记（照「闪」同一写法：只在真的开着时才出现）。
	if 方 == "ally" and AtxGodsbet.是响介(u) and AtxGodsbet.赌神开启(session.battle_ctx):
		out.append("赌神")
# ★ A5a：拉米亚的「烟雾」—— 站在雾里的那一列 → 状态行里一个「雾」标记（只在真的在雾里时才出现）。
	if AtxSmoke.单位在雾里(session.battle_ctx, u):
		out.append("雾")
# ★ A5b：武器「段数改写」的**预告层** —— 槽里挂着牌时状态行里露一句「改写：满弦（下一张【弓】武器牌）」；
	var 改写文 := AtxRewrite.槽文字(u)
	if 改写文 != "":
		out.append("改写：" + 改写文)
	if bool(u.get("holdUlt", false)):
		out.append("憋大招")
	var 标 := int(Calc.标定经济层数(u))
	if 标 > 0:
		out.append("标定 %d 层" % 标)
# ★ CB-4：天人机体卡的**紧凑状态标签** —— 〔TRANS-AM 剩N〕/〔粒子耗尽〕/〔出鞘 n/7〕/
	if 方 == "ally" and CelestialV01.开(session.battle_ctx) and CelestialV01.是天人(u):
		for 条 in CelestialV01.标签行(u, session.battle_ctx):
			out.append(str(条))
	# ★ COL-4：殖民卫星军的紧凑状态标签（〔觉醒中·SEED〕/〔锁定×N〕）。
	if 方 == "ally" and ColonialV01.有成员(session.battle_ctx) and ColonialV01.是殖民卫星军(u):
		for 条 in ColonialV01.标签行(u, session.battle_ctx):
			out.append(str(条))
	if 方 == "enemy" and bool(u.get("词条全场", false)):
		out.append("全场词条")
	if float(u.get("shield", 0.0)) > 0.0:
		out.append("护盾 %d" % int(JsCompat.js_round(float(u.get("shield", 0.0)))))
	if out.is_empty():
		out.append("正常")
	return out

static func 太阳炉明细(session: GameSession) -> Array:
	if session.battle_ctx.is_empty():
		return []
	return CelestialV01.太阳炉明细(session.battle_ctx)

static func 太阳炉左栏文(session: GameSession) -> String:
	if session.battle_ctx.is_empty():
		return ""
	return CelestialV01.太阳炉左栏文(session.battle_ctx)

## 这台敌机现在要不要挂青色 **`〔介入〕`**（我方有天人成员，且它本回合还没挨打 / 是任务目标）
static func 介入标记(session: GameSession, 单位键: String) -> bool:
	if session.battle_ctx.is_empty():
		return false
	return CelestialV01.介入吗(session.battle_ctx, Btl.找单位(session.battle_ctx, 单位键, "enemy"))

## 左栏那张出鞘剑牌的标记文（`〔出鞘 · 剑×N〕`
static func 出鞘标记文(session: GameSession, 卡: Variant) -> String:
	var n := CelestialV01.剑数Of(卡)
	if n <= 0 or not (卡 is Dictionary) or not bool((卡 as Dictionary).get("出鞘", false)):
		return ""
	return "〔出鞘 · 剑×%d〕" % n

static func 卡出鞘文(session: GameSession, 卡id: String) -> String:
	if session.battle_ctx.is_empty() or 卡id.is_empty():
		return ""
	var 友: Array = session.battle_ctx.get("allies") if session.battle_ctx.get("allies") is Array else []
	for u in 友:
		if not (u is Dictionary):
			continue
		for c in CelestialV01.剑牌们(u):
			if str((c as Dictionary).get("id", "")) == 卡id:
				return 出鞘标记文(session, c)
	return ""

## 「拔刀」的默认目标（第一张出鞘的剑牌 id
static func 默认拔刀目标(session: GameSession, 单位键: String) -> String:
	var u: Variant = _找我方(session, 单位键)
	if not (u is Dictionary):
		return ""
	for c in CelestialV01.剑牌们(u):
		if bool((c as Dictionary).get("出鞘", false)):
			return str((c as Dictionary).get("id", ""))
	return ""

static func 默认太阳炉牌(session: GameSession, 只要veda: bool = false) -> String:
	for e in 太阳炉明细(session):
		if int(e.get("级", 1)) >= 3:
			continue
		if 只要veda and not bool(e.get("veda", false)):
			continue
		return str(e.get("id"))
	return ""

static func _找我方(session: GameSession, 单位键: String) -> Dictionary:
	if session.battle_ctx.is_empty():
		return {}
	var u: Variant = Btl.找单位(session.battle_ctx, 单位键, "ally")
	return u if u is Dictionary else {}

static func _开关行(session: GameSession, u: Dictionary) -> Array:
	var out: Array = []
	out.append("保留大招：%s" % ("开" if bool(u.get("holdUlt", false)) else "关"))
	return out

## 脚下这一格的**真实**类型（判据只此一处：格表优先，认不出来才退回 `map_data["当前节点类型"]`）
static func _脚下类型(session: GameSession, s: RunState) -> String:
	var t := str(s.cell_at(s.node_id).get("类型", ""))
	if not t.is_empty():
		return t
	return str(s.map_data.get("当前节点类型", ""))
