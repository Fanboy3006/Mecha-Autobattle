## 职责：版面门禁：拖拽瞄准（段 13 武器卡拖动释放 / 拥有者→目标瞄准连线 / 指定目标出伤害）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起13: int = t.passes + t.fails
	await _段13_武器卡拖拽瞄准(t, 根)
	var 段13: int = t.passes + t.fails - 起13
	t.info("★ 版面门禁（本套）：段 13（武器卡拖拽瞄准）%d 项 · 合计 %d 项" % [段13, 段13])

## 段 13 的沙盒：M3（维修）+ B1（近卫）在前排，敌机 3 台（含后排 sniper@4）；月球 / 影世界 v0.2 关掉，用通用牌组。
func _建拖拽沙盒() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段13.json"
	var 我方编成 := [{"键": "M3", "位": 0, "等级": 10}, {"键": "B1", "位": 1, "等级": 10}]
	var 敌方编成 := [
		{"键": "fighter", "位": 0, "等级": 1}, {"键": "tank", "位": 1, "等级": 1},
		{"键": "sniper", "位": 4, "等级": 1},
	]
	var ctx := Setup.开局(我方编成, 敌方编成, 20261023, null, {"单机牌组": true, "月球v02": false, "影世界v02": false})
	if ctx.is_empty():
		return s
	for u in (ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 100.0
			if str((u as Dictionary).get("key", "")) == "B1":
				(u as Dictionary)["hp"] = float((u as Dictionary).get("maxHp", 1.0)) * 0.5
	s.battle_ctx = ctx
	s.screen = "battle"
	s.select_battle_unit(_单机存活键(s, 0))
	s.clear_errors()
	return s

## 上排里「区 == 区 且 可打」的第一张（`额外` 用来再挑「是修理 / 是衍生」这类）。
func _上排卡(s: GameSession, 区: String, 额外: String = "") -> Dictionary:
	for c in s.upper_hand_cards():
		if not (c is Dictionary):
			continue
		if str((c as Dictionary).get("区", "")) != 区:
			continue
		if not bool((c as Dictionary).get("可打", false)):
			continue
		if not 额外.is_empty() and not bool((c as Dictionary).get(额外, false)):
			continue
		return c
	return {}

## 某台单位的 HP（直接读内核 `battle_ctx`，与门面 `unit_view()` 同一份数）。
func _单位HP(s: GameSession, 方: String, 键: String) -> float:
	var 池: Variant = s.battle_ctx.get("allies") if 方 == "ally" else s.battle_ctx.get("enemies")
	if not (池 is Array):
		return -1.0
	for x in (池 as Array):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == 键:
			return float((x as Dictionary).get("hp", 0.0))
	return -1.0

func _段13_武器卡拖拽瞄准(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var s := _建拖拽沙盒()
	if s == null or s.battle_ctx.is_empty():
		t.ok(false, "★ 段 13：拖拽沙盒开不起来")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	# ---------- ① 可拖拽判据 ----------
	t.ok(v.可拖拽释放({"可打": true, "是修理": false}, "主武器卡"),
		"★★ 段 13 ①：能打的【主武器卡】**默认可拖拽释放**")
	t.ok(v.可拖拽释放({"可打": true}, "衍生攻击卡"), "★★ 段 13 ①：【衍生攻击卡】也可以拖")
	t.ok(v.可拖拽释放({"可打": true, "是衍生": true}, "公有牌"),
		"★★ 段 13 ①：下排公有手牌里的**攻击型衍生卡**（如 TDD-1）也可以拖")
	t.ok(not v.可拖拽释放({"可打": true, "是衍生": false}, "公有牌"),
		"★ 段 13 ①：公有非衍生牌（增益 / 抽牌）不走拖动，仍然点一下就打")
	t.ok(not v.可拖拽释放({"可打": true}, "专属精神牌"), "★ 段 13 ①：专属精神牌不走拖动")
	t.ok(not v.可拖拽释放({"可打": true, "单机牌组_铁壁": true}, "主武器卡"),
		"★ 段 13 ①：【铁壁护卫】这类无目标牌暂时走点击（拖拽区域是登记在案的待办）")
	t.ok(not v.可拖拽释放({"可打": false}, "主武器卡"), "★ 段 13 ①：现在打不出来的牌一律不能拖")
	# ---------- ② 维修卡：拥有者卡中心 → 受伤队友卡中心，翠绿连线，松手回血 ----------
	var 维修 := _上排卡(s, "主武器卡", "是修理")
	t.ok(not 维修.is_empty(), "★ 段 13 ②：维修机（M3）上排有一张能打的【修理】主武器卡")
	var 维修者 := _卡By键(v, "ally", s.selected_unit_id)
	var 受友 := _卡By键(v, "ally", "B1")
	t.ok(维修者 != null and 受友 != null, "★ 段 13 ②：拥有者卡 M3 与目标队友卡 B1 都在场上")
	if not 维修.is_empty() and 维修者 != null and 受友 != null:
		t.ok(not v.拖拽中(), " ★ 段 13 ②：一开始没有在拖")
		var 按下点 := _心(维修者) + Vector2(0.0, 6.0)
		var r0 := v.开始拖拽("主武器卡", str(维修.get("手牌键", "")), true, 按下点, 维修)
		t.ok(bool(r0.get("可拖拽", false)), "★★ 段 13 ②：按住这张修理卡 → 进入拖拽准备态（%s）" % str(r0.get("原因", "")))
		t.ok(v.拖拽瞄准线().is_empty(), "★★ 段 13 ②：还没移动超过 8px → **不画**瞄准线")
		var r小 := v.拖拽到(按下点 + Vector2(3.0, 0.0))
		t.ok(not bool(r小.get("已启动", false)) and v.拖拽瞄准线().is_empty(),
			"★★ 段 13 ②：只挪了 3px（< 8px）→ 不算拖动，瞄准线仍然是空的")
		var 友心 := _心(受友)
		var r1 := v.拖拽到(友心)
		t.ok(bool(r1.get("已启动", false)) and bool(r1.get("吸附", false)),
			"★★ 段 13 ②：拖到队友 B1 卡上 → 进瞄准并**吸附**（目标 = %s）" % str(r1.get("目标键", "")))
		var 线 := v.拖拽瞄准线()
		t.ok(not 线.is_empty() and bool(线.get("显示", false)), "★★ 段 13 ②：瞄准线已经生成")
		t.ok(线.get("起点") is Vector2 and (线.get("起点") as Vector2).distance_to(_心(维修者)) < 0.5,
			"★★ 段 13 ②：连线**起点 = 武器拥有者（M3）的 `UnitCard` 中心**（%s）" % str(线.get("起点")))
		t.ok(线.get("终点") is Vector2 and (线.get("终点") as Vector2).distance_to(友心) < 0.5,
			"★★ 段 13 ②：连线的**终点吸附到目标卡中心**（%s）" % str(线.get("终点")))
		t.ok(线.get("颜色") == BattleView.瞄准色_维修 and bool(线.get("维修", false)),
			"★★ 段 13 ②：维修卡的连线是**翠绿**（瞄准色_维修）")
		t.ok(v._战斗动画层 != null and v._战斗动画层.瞄准中() and not (v._战斗动画层.aim_line as Dictionary).is_empty(),
			"★★ 段 13 ②：瞄准线画在**特效画布**（战斗动画层）上（`瞄准中()` = true）")
		t.ok(受友.瞄准高亮中(), "★★ 段 13 ②：被瞄准的队友 `UnitCard` 被**高亮**了")
		var 友血前 := _单位HP(s, "ally", "B1")
		var 日志前: int = s.battle_log_entries(0).size()
		var r2 := v.结束拖拽(友心)
		t.ok(bool(r2.get("释放", false)) and str(r2.get("目标键", "")) == "B1",
			"★★ 段 13 ②：松手 → 把 B1 的键当 `target_id` 释放（%s）" % str(r2.get("原因", "")))
		t.ok(not v.拖拽中() and v.拖拽瞄准线().is_empty() and not 受友.瞄准高亮中(),
			"★★ 段 13 ②：松手之后拖拽状态 / 瞄准线 / 卡片高亮全部收干净")
		t.ok(_单位HP(s, "ally", "B1") > 友血前,
			"★★ 段 13 ②：修理**当场生效** —— B1 的 HP %.0f → %.0f" % [友血前, _单位HP(s, "ally", "B1")])
		t.ok(s.battle_log_entries(0).size() > 日志前, "★ 段 13 ②：这一下当场写进了战斗日志")
	# ---------- ③ 攻击卡：指定「自动目标不会挑的那台」→ 伤害精确落在它身上 ----------
	var 近卫键 := "B1"
	var 选 := s.select_battle_unit(近卫键)
	t.ok(bool(选.get("ok", false)), "★ 段 13 ③：切到 B1（%s）" % 近卫键)
	v.refresh()
	await _等帧(2)
	var 攻击 := _上排卡(s, "主武器卡", "")
	t.ok(not 攻击.is_empty(), "★ 段 13 ③：B1 上排有一张能打的【主武器卡】（%s）" % str(攻击.get("名", "")))
	var 攻者 := _卡By键(v, "ally", 近卫键)
	# 坦克血量远高于战斗机：内核自动目标挑「血最低的活敌」= 战斗机，所以「打中坦克」只可能是指定目标生效。
	var 坦 := _卡By键(v, "enemy", "tank")
	var 战 := _卡By键(v, "enemy", "fighter")
	t.ok(攻者 != null and 坦 != null and 战 != null, "★ 段 13 ③：出手卡 / 指定目标（坦克）/ 对照目标（战斗机）都在场上")
	if not 攻击.is_empty() and 攻者 != null and 坦 != null and 战 != null:
		var 按下点2 := _心(攻者) + Vector2(0.0, 8.0)
		var ra := v.开始拖拽("主武器卡", str(攻击.get("手牌键", "")), true, 按下点2, 攻击)
		t.ok(bool(ra.get("可拖拽", false)), "★★ 段 13 ③：按住攻击卡 → 进入拖拽准备态")
		var 坦心 := _心(坦)
		var rb := v.拖拽到(坦心)
		t.ok(bool(rb.get("已启动", false)) and str(rb.get("目标键", "")) == "tank",
			"★★ 段 13 ③：拖到坦克卡上 → 吸附到它（%s）" % str(rb.get("目标键", "")))
		var 线2 := v.拖拽瞄准线()
		t.ok(线2.get("起点") is Vector2 and (线2.get("起点") as Vector2).distance_to(_心(攻者)) < 0.5,
			"★★ 段 13 ③：连线起点 = **B1 的 `UnitCard` 中心**（%s）" % str(线2.get("起点")))
		t.ok(线2.get("终点") is Vector2 and (线2.get("终点") as Vector2).distance_to(坦心) < 0.5,
			"★★ 段 13 ③：连线终点 = **坦克 `UnitCard` 中心**（%s）" % str(线2.get("终点")))
		t.ok(线2.get("颜色") == BattleView.瞄准色_攻击, "★★ 段 13 ③：攻击卡的连线是**橙红**（瞄准色_攻击）")
		t.ok(坦.瞄准高亮中() and not 战.瞄准高亮中(), "★★ 段 13 ③：只有被瞄准的那台被高亮，别台不亮")
		var 坦血前 := _单位HP(s, "enemy", "tank")
		var 战血前 := _单位HP(s, "enemy", "fighter")
		var 日志前3: int = s.battle_log_entries(0).size()
		var rc := v.结束拖拽(坦心)
		t.ok(bool(rc.get("释放", false)) and str(rc.get("目标键", "")) == "tank",
			"★★ 段 13 ③：松手 → 把坦克的键当 `target_id` 释放（%s）" % str(rc.get("原因", "")))
		var 结果: Dictionary = rc.get("结果") if rc.get("结果") is Dictionary else {}
		t.ok(bool(结果.get("ok", false)), "★★ 段 13 ③：门面返回成功（%s）" % str(结果.get("为什么", "")))
		t.ok(_单位HP(s, "enemy", "tank") < 坦血前,
			"★★ 段 13 ③：伤害**当场**落在指定的坦克身上（%.0f → %.0f）" % [坦血前, _单位HP(s, "enemy", "tank")])
		t.ok(absf(_单位HP(s, "enemy", "fighter") - 战血前) < 0.001,
			"★★ 段 13 ③：**自动目标会挑的那台（战斗机）反而没挨打** —— 指定目标真的生效了（%.0f）"
			% _单位HP(s, "enemy", "fighter"))
		t.ok(s.battle_log_entries(0).size() > 日志前3 and _日志有(s.battle_ctx, "坦克"),
			"★★ 段 13 ③：当场产出攻击日志（%d → %d 条，日志里点到坦克）"
			% [日志前3, s.battle_log_entries(0).size()])
		t.ok(v.演出帧数() >= 1 and v.已播帧数() >= v.演出帧数() and not v._演出预热,
			"★★ 段 13 ③：这一下**当场**拆成 %d 帧演出并播完（预热窗已关，不等「结束我方回合」）" % v.演出帧数())
	# ---------- ④ 拖到空白处 → 取消，不误出牌 ----------
	# 切回维修机 M3，拿它的**衍生攻击卡**（【应急补丁】）：主武器卡打完会「本回合已销毁」，
	# 衍生卡不毁主武、一直能拖，正好用来验「拖到空白处不出牌」。
	var 选3 := s.select_battle_unit("M3")
	t.ok(bool(选3.get("ok", false)), "★ 段 13 ④：切回 M3（%s）" % str(选3.get("名", "")))
	v.refresh()
	await _等帧(2)
	var 攻击2 := _上排卡(s, "衍生攻击卡", "")
	t.ok(not 攻击2.is_empty(), "★ 段 13 ④：M3 手里有一张能拖的【衍生攻击卡】（%s）" % str(攻击2.get("名", "")))
	var 攻者2 := _卡By键(v, "ally", "M3")
	var 坦卡 := _卡By键(v, "enemy", "tank")
	if not 攻击2.is_empty() and 攻者2 != null and 坦卡 != null:
		var 坦血前4 := _单位HP(s, "enemy", "tank")
		var 日志前4: int = s.battle_log_entries(0).size()
		var r0 := v.开始拖拽("衍生攻击卡", str(攻击2.get("手牌键", "")), true, _心(攻者2), 攻击2)
		t.ok(bool(r0.get("可拖拽", false)), "★★ 段 13 ④：按住这张衍生卡 → 进入拖拽准备态")
		v.拖拽到(Vector2(4.0, 4.0))
		var rd := v.结束拖拽(Vector2(4.0, 4.0))
		t.ok(not bool(rd.get("释放", false)), "★★ 段 13 ④：拖到空白处松手 → **取消**（%s）" % str(rd.get("原因", "")))
		t.ok(absf(_单位HP(s, "enemy", "tank") - 坦血前4) < 0.001
			and s.battle_log_entries(0).size() == 日志前4,
			"★★ 段 13 ④：取消时**没有**误出牌（坦克 HP 没变、日志没多）")
		t.ok(not v.拖拽中() and v.拖拽瞄准线().is_empty(), "★ 段 13 ④：取消后瞄准线也清了")
		# ---------- ⑤ 原地轻点 → 不在这儿出牌（交给 `pressed` 的点击老路） ----------
		var 点 := _心(攻者2)
		v.开始拖拽("衍生攻击卡", str(攻击2.get("手牌键", "")), true, 点, 攻击2)
		var re := v.结束拖拽(点 + Vector2(2.0, 2.0))
		t.ok(not bool(re.get("释放", false)) and str(re.get("原因", "")).contains("原地轻点"),			"★★ 段 13 ⑤：没拖动就松手 → 交给点击老路（%s）" % str(re.get("原因", "")))
		t.ok(s.battle_log_entries(0).size() == 日志前4, "★★ 段 13 ⑤：原地轻点也**没有**在这儿出牌（日志没多）")
	# ---------- ⑥ 双排手牌悬停 → 高亮拥有者机体卡 ----------
	var 上有 := v._专属排列表
	var 当前拥有者 := _卡By键(v, "ally", s.selected_unit_id)
	if 上有 != null and 上有.get_child_count() > 0 and 当前拥有者 != null:
		var 手牌节点: Control = 上有.get_child(0) as Control
		t.ok(not 当前拥有者.联动高亮中(), "★ 段 13 ⑥：悬停之前拥有者卡没有亮")
		v._悬停单机卡(手牌节点)
		t.ok(当前拥有者.联动高亮中(),
			"★★ 段 13 ⑥：悬停上排某张牌 → **拥有者机体卡**（%s）亮起（联动高亮）" % s.selected_unit_id)
		v._移开单机卡()
		t.ok(not 当前拥有者.联动高亮中(), "★★ 段 13 ⑥：鼠标移开 → 高亮熄灭")
	else:
		t.ok(false, "★ 段 13 ⑥：上排一张牌都没画出来（悬停高亮那两条跑不了）")
	# ---------- ⑦ 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 13 ⑦：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆视图(树根, v)
