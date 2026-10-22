## 职责：版面门禁：UX-1 六项修复（段 9：战后回大地图 / 编队拖拽 / 藏品零件悬停 / 零件瞄准横幅）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起9: int = t.passes + t.fails
	await _段9_UX1六项修复(t, 根)
	var 段9: int = t.passes + t.fails - 起9
	t.info("★ 版面门禁（本套）：段 9（UX-1 六项修复）%d 项 · 合计 %d 项" % [段9, 段9])

func _段9_UX1六项修复(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 9：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)
	if s.run_state == null:
		s.start_new_run(20261301, "混编")
	await _等帧(1)
	await _段9a_战后继续回大地图(t, 舱)
	await _段9b_编队拖拽(t, 舱)
	await _段9c_藏品零件悬停(t, 舱)
	await _段9d_零件瞄准横幅(t, 舱)
	_拆boot(树根, 舱)

# ---------------- ① 战后结算点「继续」→ 回大地图 + 顶栏三颗按钮全部可点 ----------------

func _段9a_战后继续回大地图(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null or str(s.run_state.status) != "进行中":
		t.ok(s.start_new_run(20261307, "混编"), "★ 段 9a：开一局（第 %d 层）"
			% (s.run_state.floor_num if s.run_state != null else 0))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	# ---- 招募 + 上阵（战斗格要求出击名单非空）----
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if not bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			break
	_清待选(s)
	_清券(s)
	t.ok(_编队第一台(s), "★ 段 9a：把一台摆上出击位（出击 %d 台）" % s.run_state.lineup.size())
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "★ 段 9a：第 %d 层找不到战斗格" % s.run_state.floor_num)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "★ 段 9a：战斗格 %d 四周找不到落脚点" % 战斗格)
		return
	s.run_state.node_id = 落脚
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(落脚).get("类型", ""))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 9a：大地图视图类型不对（%s）" % str(mv))
		return
	(mv as MapView)._点格(战斗格)
	await _等帧(3)
	var 开始钮: Control = boot.find_child("开始战斗按钮", true, false)
	if not (开始钮 is Button):
		t.ok(false, "★ 段 9a：找不到【确认编队 · 开始战斗】按钮")
		return
	(开始钮 as Button).pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "battle" and s.in_battle(), "★ 段 9a：确认编队之后真的开打了（screen = %s）" % s.screen)
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	# 战后的「三选一 / 招募券」决定先做完（否则顶栏本来就该锁着 —— 那不是 bug）
	_清待选(s)
	_清券(s)
	s.screen = "result"
	boot.route()
	await _等帧(3)
	t.ok(s.in_battle(), "★ 段 9a：停在结算屏时还拿着这一场的战斗上下文（in_battle = true）")
	var 继续: Control = boot.find_child("继续按钮", true, false)
	t.ok(继续 is Button, "★ 段 9a：结算屏有「继续按钮」")
	if not (继续 is Button):
		return
	(继续 as Button).pressed.emit()
	await _等帧(3)
	t.ok(not s.in_battle(),
		"★★ 段 9a：点「继续前进（回大地图）」之后 `session.in_battle() == false`（battle_ctx 被清掉了）")
	t.ok(str(s.screen) == "map", "★★ 段 9a：屏幕真的回到 map（真实值 %s）" % s.screen)
	# ---- 顶栏「编队 / 招募 / 牌库」三颗按钮现在必须可点 ----
	var 编队钮: Control = boot.find_child("编队按钮", true, false)
	var 招募钮: Control = boot.find_child("招募按钮", true, false)
	var 牌库钮: Control = boot.find_child("战术牌库按钮", true, false)
	t.ok(编队钮 is Button and not (编队钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「编队」按钮 `disabled == false`（随时可打开查看与调整）")
	t.ok(招募钮 is Button and not (招募钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「招募 / 晋升」按钮 `disabled == false`")
	t.ok(牌库钮 is Button and not (牌库钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「战术牌库」按钮 `disabled == false`")
	# ---- 从大地图打开编队 → 点【返回大地图】直接回到大地图 ----
	if 编队钮 is Button:
		(编队钮 as Button).pressed.emit()
		await _等帧(3)
		t.ok(str(s.screen) == "formation", "★ 段 9a：从大地图点「编队」→ 进编队屏（真实值 %s）" % s.screen)
		var 回钮: Control = boot.find_child("回地图按钮", true, false)
		t.ok(回钮 is Button and (回钮 as Button).visible,
			"★★ 段 9a：编队屏的【确认并返回大地图】按钮是可见的（不是战前确认态）")
		if 回钮 is Button:
			(回钮 as Button).pressed.emit()
			await _等帧(3)
			t.ok(str(s.screen) == "map",
				"★★ 段 9a：点【确认并返回大地图】→ 直接回到大地图（真实值 %s）" % s.screen)

# ---------------- ② 编队卡片拖拽：名册拖上阵 / 格位互换 / 拖回名册下阵 ----------------

func _名册卡(boot, 键: String) -> Control:
	var 盒 = boot.find_child("名册列表内容", true, false)
	if not (盒 is Node):
		return null
	for c in (盒 as Node).get_children():
		if c is Button and str(c.get("键")) == 键:
			return c
	return null

## 编队屏里找某一格的卡（按位名）。
func _槽卡(boot, 位名: String) -> Control:
	for 排 in ["第0排", "第1排"]:
		var n = boot.find_child(str(排), true, false)
		if not (n is Node):
			continue
		for c in (n as Node).get_children():
			if c is Button and str(c.get("位名")) == 位名:
				return c
	return null

func _在编队(s: GameSession, 键: String) -> bool:
	for x in s.run_state.lineup:
		if x is Dictionary and str(x.get("key", "")) == 键:
			return true
	return false

func _槽位键(s: GameSession, 位名: String) -> String:
	for x in s.lineup_slots():
		if x is Dictionary and str(x.get("位名", "")) == 位名:
			return str(x.get("键", ""))
	return ""

func _空格位名(s: GameSession) -> String:
	for x in s.lineup_slots():
		if x is Dictionary and str(x.get("键", "")).is_empty():
			return str(x.get("位名", ""))
	return ""

func _未上阵键(s: GameSession) -> String:
	for k in s.run_state.roster.keys():
		if not _在编队(s, str(k)):
			return str(k)
	return ""

func _段9b_编队拖拽(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null:
		t.ok(false, "★ 段 9b：没有进行中的局")
		return
	# ---- 夹具：保证「名册里有一台没上阵的」+「至少两台在阵上」----
	var 表: Array = Db.T.get("ALLY_T") if Db.T.get("ALLY_T") is Array else []
	while s.run_state.roster.size() < s.run_state.lineup.size() + 2 and s.run_state.roster.size() < 8:
		var 加了 := false
		for e in 表:
			if not (e is Dictionary):
				continue
			var k := str((e as Dictionary).get("mech", ""))
			if k.is_empty() or s.run_state.roster.has(k):
				continue
			s.run_state.roster[k] = {"key": k, "lv": 30, "hpRatio": 1.0}
			加了 = true
			break
		if not 加了:
			break
	# 再摆一台上去（保证有两台在阵上可以互换）
	var 第二 := _未上阵键(s)
	var 位1 := _空格位名(s)
	if not 第二.is_empty() and not 位1.is_empty():
		s.set_lineup_slot(第二, 位1)
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	t.ok(s.run_state.lineup.size() >= 2, "★ 段 9b：阵上现在有 %d 台可互换" % s.run_state.lineup.size())
	# ---- ① 名册卡片 → 阵型槽（拖上阵）----
	var 键 := _未上阵键(s)
	var 空位 := _空格位名(s)
	if 键.is_empty() or 空位.is_empty():
		t.ok(false, "★ 段 9b：名册里没有「未上阵」的机体 / 没有空格位 —— 拖上阵那一段跑不了")
		return
	var 名册卡 := _名册卡(boot, 键)
	t.ok(名册卡 != null, "★ 段 9b：找得到名册里「%s」的卡片控件" % 键)
	if 名册卡 == null:
		return
	var 数据: Variant = 名册卡._get_drag_data(Vector2.ZERO)
	t.ok(数据 is Dictionary and str((数据 as Dictionary).get("type", "")) == "formation_unit",
		"★★ 段 9b：名册卡的 `_get_drag_data()` 给出 {type: formation_unit, …}（%s）" % str(数据))
	t.ok(数据 is Dictionary and str((数据 as Dictionary).get("unit_key", "")) == 键
		and str((数据 as Dictionary).get("from_slot", "X")).is_empty(),
		"★★ 段 9b：拖拽数据带正确的 unit_key（%s）且 from_slot 为空（它不在阵上）" % 键)
	var 槽卡 := _槽卡(boot, 空位)
	t.ok(槽卡 != null, "★ 段 9b：找得到空格位「%s」的卡片控件" % 空位)
	if 槽卡 == null:
		return
	t.ok(bool(槽卡._can_drop_data(Vector2.ZERO, 数据)),
		"★★ 段 9b：空格位 `_can_drop_data()` = true（可以放下）")
	槽卡._drop_data(Vector2.ZERO, 数据)
	await _等帧(2)
	t.ok(_在编队(s, 键) and _槽位键(s, 空位) == 键,
		"★★ 段 9b：名册拖上阵成功 —— %s 现在在 %s（出击 %d 台）" % [键, 空位, s.run_state.lineup.size()])
	# ---- ② 阵型槽 A → 阵型槽 B（两台直接互换格位）----
	var 占位们: Array = []
	for x in s.lineup_slots():
		if x is Dictionary and not str(x.get("键", "")).is_empty():
			占位们.append(str(x.get("位名", "")))
	if 占位们.size() < 2:
		t.ok(false, "★ 段 9b：阵上不到 2 台 —— 互换那一段跑不了")
		return
	var 位A := str(占位们[0])
	var 位B := str(占位们[1])
	var 卡A := _槽卡(boot, 位A)
	var 卡B := _槽卡(boot, 位B)
	t.ok(卡A != null and 卡B != null, "★ 段 9b：找得到 %s / %s 两张格位卡" % [位A, 位B])
	if 卡A == null or 卡B == null:
		return
	var 键A := _槽位键(s, 位A)
	var 键B := _槽位键(s, 位B)
	var 数A: Variant = 卡A._get_drag_data(Vector2.ZERO)
	t.ok(数A is Dictionary and str((数A as Dictionary).get("unit_key", "")) == 键A
		and str((数A as Dictionary).get("from_slot", "")) == 位A,
		"★★ 段 9b：格位卡的拖拽数据带 from_slot = %s（%s）" % [位A, str(数A)])
	t.ok(bool(卡B._can_drop_data(Vector2.ZERO, 数A)),
		"★★ 段 9b：有人的格位「%s」`_can_drop_data()` = true（可以被换上去）" % 位B)
	卡B._drop_data(Vector2.ZERO, 数A)
	await _等帧(2)
	t.ok(_槽位键(s, 位B) == 键A and _槽位键(s, 位A) == 键B,
		"★★ 段 9b：格位互换成功（%s → %s、%s → %s）" % [键B, 位A, 键A, 位B])
	t.ok(s.run_state.lineup.size() == 占位们.size(),
		"★★ 段 9b：互换之后总上阵人数不变（%d 台）—— 不该撞上限" % s.run_state.lineup.size())
	# ---- ③ 阵型槽 → 名册区（拖回名册 = 下阵）----
	var 卡C := _槽卡(boot, 位B)
	var 名册区 = boot.find_child("名册列表", true, false)
	t.ok(卡C != null and 名册区 is Control, "★ 段 9b：找得到格位卡与名册区落点容器")
	if 卡C == null or not (名册区 is Control):
		return
	var 数C: Variant = 卡C._get_drag_data(Vector2.ZERO)
	t.ok(bool((名册区 as Control)._can_drop_data(Vector2.ZERO, 数C)),
		"★★ 段 9b：名册区落点接「从阵型槽拖回来」的数据（`_can_drop_data()` = true）")
	var 名册行 := _名册卡(boot, 键A)
	t.ok(名册行 != null and bool(名册行._can_drop_data(Vector2.ZERO, 数C)),
		"★ 段 9b：名册行本身也接得住「拖回名册」的数据")
	(名册区 as Control)._drop_data(Vector2.ZERO, 数C)
	await _等帧(2)
	t.ok(not _在编队(s, 键A), "★★ 段 9b：拖回名册 = 下阵成功（%s 已经不在出击名单里）" % 键A)
	t.ok(_槽位键(s, 位B).is_empty(), "★★ 段 9b：%s 空出来了（格位没有留下幽灵记录）" % 位B)
	# ---- ④ 右键阵型槽 = 下阵（「拖回名册」之外的第二条下阵路）----
	var 卡D := _槽卡(boot, 位A)
	t.ok(卡D != null, "★ 段 9b：找得到 %s 的格位卡（右键下阵用）" % 位A)
	if 卡D != null:
		var 键D := _槽位键(s, 位A)
		var 右键 := InputEventMouseButton.new()
		右键.button_index = MOUSE_BUTTON_RIGHT
		右键.pressed = true
		卡D._gui_input(右键)
		await _等帧(2)
		t.ok(not _在编队(s, 键D),
			"★★ 段 9b：右键点阵型槽 %s → 那一台的 %s 直接下阵（不用拖、也不用先选中）" % [位A, 键D])
	# ---- ⑤ 页面显著位置有拖拽提示（作者要求的那句引导）----
	t.ok(_控件含文(boot, "可拖拽机体卡片上阵"), "★★ 段 9b：编队屏显著位置写着「可拖拽机体卡片上阵…」的引导")

# ---------------- ③ 藏品 / 零件 —— 悬停说明层 + 门面悬停文本 ----------------

func _段9c_藏品零件悬停(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	var 装了 := _塞满藏品与零件(boot)
	t.ok(装了 >= 30, "★ 段 9c：给顶栏塞了 %d 件藏品 + 零件（宽度压力最大的一档）" % 装了)
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var 悬停 = boot.find_child("悬停说明层", true, false)
	var 藏栏 = boot.find_child("藏品栏", true, false)
	var 件栏 = boot.find_child("零件栏", true, false)
	t.ok(藏栏 is Node and 件栏 is Node, "★ 段 9c：顶栏里找得到「藏品栏」与「零件栏」")
	if not (藏栏 is Node and 件栏 is Node):
		return
	# ---- 藏品：每个控件都挂着 HoverTooltip，且有实际文本 ----
	var 藏控件 := 0
	var 藏绑了 := 0
	var 藏有字 := 0
	for c in (藏栏 as Node).get_children():
		if not (c is Control):
			continue
		藏控件 += 1
		if (c as Control).has_meta("_hover_bound"):
			藏绑了 += 1
		if not str((c as Control).tooltip_text).strip_edges().is_empty():
			藏有字 += 1
	t.ok(藏控件 > 0, "★ 段 9c：藏品栏里画出了 %d 个藏品控件" % 藏控件)
	t.ok(藏控件 > 0 and 藏绑了 == 藏控件,
		"★★ 段 9c：**每一个**藏品控件都绑了 HoverTooltip（`has_meta(\"_hover_bound\")` = true；%d / %d）"
		% [藏绑了, 藏控件])
	t.ok(藏控件 > 0 and 藏有字 == 藏控件,
		"★★ 段 9c：每一个藏品控件的 `tooltip_text` 都有货（%d / %d）—— 鼠标移上去不会一片空白" % [藏有字, 藏控件])
	# ---- 零件：每个控件都挂了 HoverTooltip，且被动零件是「常驻被动徽章」 ----
	var 件控件 := 0
	var 件绑了 := 0
	var 徽章 := 0
	var 主动钮 := 0
	var 灰钮 := 0
	for c in (件栏 as Node).get_children():
		if not (c is Control):
			continue
		件控件 += 1
		if (c as Control).has_meta("_hover_bound"):
			件绑了 += 1
		if c is Label and str((c as Label).text).contains("·被动"):
			徽章 += 1
		if c is Button:
			主动钮 += 1
			if (c as Button).disabled:
				灰钮 += 1
	t.ok(件控件 > 0, "★ 段 9c：零件栏里画出了 %d 个零件控件" % 件控件)
	t.ok(件控件 > 0 and 件绑了 == 件控件,
		"★★ 段 9c：**每一个**零件控件都绑了 HoverTooltip（%d / %d）" % [件绑了, 件控件])
	t.ok(徽章 > 0, "★★ 段 9c：被动零件画成「·被动」常驻徽章（%d 个 Label），不再假装是坏掉的灰按钮" % 徽章)
	t.ok(主动钮 > 0, "★ 段 9c：主动零件仍然是按钮（%d 个，其中置灰 %d 个）" % [主动钮, 灰钮])
	# ---- 门面悬停文本非空，且内容齐全 ----
	var 藏键 := ""
	if s.run_state != null and not s.run_state.relics.is_empty():
		藏键 = str(s.run_state.relics[0])
	var 藏文 := s.relic_hover_text(藏键)
	t.ok(not 藏文.strip_edges().is_empty() and 藏文.contains("稀有度") and 藏文.contains("数值加成"),
		"★★ 段 9c：`relic_hover_text(\"%s\")` 非空且含「稀有度」「数值加成」（%d 字）" % [藏键, 藏文.length()])
	var 零文 := s.part_hover_text(0)
	t.ok(not 零文.strip_edges().is_empty() and 零文.contains("剩余次数"),
		"★★ 段 9c：`part_hover_text(0)` 非空且含「剩余次数」（%d 字）" % 零文.length())
	# ---- `part_can_use_now` 的三态口径 ----
	var 被动数 := 0
	var 可用数 := 0
	var 说明齐 := true
	if s.run_state != null:
		for i in s.run_state.parts.size():
			var 状 := s.part_can_use_now(i)
			if bool(状.get("passive", false)):
				被动数 += 1
				if bool(状.get("ok", true)) or str(状.get("why", "")).is_empty():
					说明齐 = false
			elif bool(状.get("ok", false)):
				可用数 += 1
				if (状.get("targets") as Array).is_empty():
					说明齐 = false
			elif str(状.get("why", "")).is_empty():
				说明齐 = false
	t.ok(被动数 > 0 and 说明齐,
		"★★ 段 9c：被动零件 `part_can_use_now()` 给 passive = true / ok = false / why 非空（%d 件）；可用的主动零件都带 targets"
		% 被动数)
	# 不在大地图时，主动零件一律「请在大地图界面点击使用」
	s.screen = "formation"
	boot.route()
	await _等帧(2)
	var 屏限制 := 0
	var 屏都拒 := true
	if s.run_state != null:
		for i in s.run_state.parts.size():
			var 状2 := s.part_can_use_now(i)
			if bool(状2.get("passive", false)):
				continue
			屏限制 += 1
			if bool(状2.get("ok", true)) or not str(状2.get("why", "")).contains("大地图"):
				屏都拒 = false
	t.ok(屏限制 == 0 or 屏都拒,
		"★★ 段 9c：不在大地图时主动零件全部拒绝并写清「请在大地图界面点击使用」（%d 件）" % 屏限制)
	t.info("★ 段 9c：零件三态 —— 被动 %d 件、大地图上可用 %d 件、其余都带明确原因" % [被动数, 可用数])
	# ---- 真的能用悬停层把说明显示出来（面板可见 + 文本就是控件那段）----
	if 悬停 is HoverTooltip and 藏控件 > 0:
		var 第一件 := (藏栏 as Node).get_child(0) as Control
		(悬停 as HoverTooltip).show_for_control(第一件)
		t.ok((悬停 as HoverTooltip).当前文本().strip_edges().length() > 0,
			"★★ 段 9c：`show_for_control(第一件藏品)` 之后悬停面板有正文（%d 字）"
			% (悬停 as HoverTooltip).当前文本().length())
		(悬停 as HoverTooltip).hide_tip()
	# 复位到一个干净的大地图，后续小段不受影响
	if s.run_state != null:
		s.screen = "map"
		boot.route()
		await _等帧(2)

# ---------------- ④ 零件瞄准态的金色引导横幅 + 点目标格立即生效 ----------------

func _段9d_零件瞄准横幅(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# 干净的一局（免得上一段留下的战斗 / 追击战影响）
	s.start_new_run(20261311, "混编")
	_塞满藏品与零件(boot)
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 9d：大地图视图类型不对（%s）" % str(mv))
		return
	# 找一件「现在真的能用」的主动零件（门面自己算，测试不另立口径）
	var 下标 := -1
	var 键 := ""
	var 目标: Array = []
	for i in s.run_state.parts.size():
		var 状 := s.part_can_use_now(i)
		if bool(状.get("ok", false)):
			下标 = i
			键 = str(状.get("key", ""))
			目标 = 状.get("targets") if 状.get("targets") is Array else []
			break
	t.ok(下标 >= 0 and not 目标.is_empty(),
		"★★ 段 9d：大地图上有一件现在就能用的主动零件（下标 %d · %s · %d 个目标格）" % [下标, 键, 目标.size()])
	if 下标 < 0 or 目标.is_empty():
		return
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	var 横幅: Control = boot.find_child("零件瞄准横幅", true, false)
	var 横幅文: Control = boot.find_child("零件瞄准横幅文字", true, false)
	t.ok(横幅 is Control and (横幅 as Control).visible,
		"★★ 段 9d：进入零件瞄准态 → 大地图上方的「零件瞄准横幅」`visible == true`")
	t.ok(横幅文 is Label and str((横幅文 as Label).text).contains("正在使用零件"),
		"★★ 段 9d：横幅写明「【正在使用零件：%s — 请点击下方高亮地图格生效…】」（%s）"
		% [键, str((横幅文 as Label).text) if 横幅文 is Label else "—"])
	t.ok(横幅文 is Label and str((横幅文 as Label).text).contains("取消瞄准"),
		"★ 段 9d：横幅里告诉玩家可以点「取消瞄准」退出")
	var 横幅钮: Control = boot.find_child("横幅取消瞄准按钮", true, false)
	var 老钮: Control = boot.find_child("取消瞄准按钮", true, false)
	t.ok(横幅钮 is Button and (横幅钮 as Button).visible, "★★ 段 9d：横幅上配了一个「取消瞄准」按钮")
	t.ok(老钮 is Button and (老钮 as Button).visible, "★ 段 9d：侧栏原来那颗「取消零件瞄准」也照旧可见")
	# ---- 再点同一件零件 = 退出瞄准（横幅里那句承诺）----
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	t.ok((mv as MapView)._瞄准.is_empty() and not (横幅 as Control).visible,
		"★★ 段 9d：再点一次同一件零件 → 退出瞄准态（横幅收起）")
	# ---- 点合法目标格：立即 use_part、退出瞄准、给即时反馈 ----
	var 前件数 := s.run_state.parts.size()
	var 前左 := int(s.part_can_use_now(下标).get("left", -1))
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	(mv as MapView)._点格(int(目标[0]))
	await _等帧(3)
	t.ok((mv as MapView)._瞄准.is_empty(), "★★ 段 9d：点合法目标格之后瞄准态退出")
	t.ok(not (横幅 as Control).visible, "★★ 段 9d：横幅随即收起（不会挂在那儿）")
	t.ok(str(s.last.get("行动", "")) == "用零件",
		"★★ 段 9d：真的执行了 `use_part()`（last.行动 = %s，落到第 %s 格）"
		% [str(s.last.get("行动", "")), str(s.last.get("到", 0))])
	t.ok(not str(s.last.get("零件", "")).is_empty(),
		"★ 段 9d：门面回了这一件的名字（%s · 剩 %s；用前 left=%d、件数 %d → %d）"
		% [str(s.last.get("零件", "")), str(s.last.get("零件剩", "—")), 前左, 前件数, s.run_state.parts.size()])
	t.ok(_控件含文(mv, "用掉了"),
		"★★ 段 9d：地图上立刻给出即时反馈（预告面板里有「用掉了」那句）")

# 段 10：★ UX-2 发牌来源机体（作者反馈第 4 条）
#
#   规格 = 《任务单-M4试玩反馈6项修复与体验升级-ARGON.md》子任务 UX-2 第 2 / 3 项：
#     ① 手牌卡面与候补牌都写出【来自：XXX】（取门面 `source_unit_text`，表现层不自己拼）；
#     ② 悬停手牌 → `source_slots` 上的我方 `UnitCard` 同步亮起联动外框（移开全灭）；
#     ③ 本拍新发牌 → 手牌卡挂【新发牌】角标 + 手牌栏顶部弹「【新发牌】获得战术牌【…】（来自：…）」。
#   ★ 零 `J.*`、零状态修改：本段只调用视图的公开联动方法 + 读门面快照。
