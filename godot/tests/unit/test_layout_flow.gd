## 职责：版面门禁：肉鸽流程（段 4 试玩反馈四个修复 / 段 6 战前编队确认与顶栏锁 / 段 7 幂等休整与战后给券）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起4: int = t.passes + t.fails
	await _段4_试玩反馈四个修复(t, 根)
	var 段4: int = t.passes + t.fails - 起4
	var 起6: int = t.passes + t.fails
	await _段6_战前编队确认与顶栏锁(t, 根)
	var 段6: int = t.passes + t.fails - 起6
	var 起7: int = t.passes + t.fails
	await _段7_幂等休整与战后九十概率(t, 根)
	var 段7: int = t.passes + t.fails - 起7
	t.info("★ 版面门禁（本套）：段 4（试玩反馈四个修复）%d 项 · 段 6（战前编队确认与顶栏锁）%d 项 · 段 7（幂等休整与战后 90%% 给券）%d 项 · 合计 %d 项" % [段4, 段6, 段7, 段4 + 段6 + 段7])

func _段4_试玩反馈四个修复(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	await _段4a_未打完也能结算(t, 树根)
	await _段4b_开局直达招募与券闭环(t, 树根)
	await _段4c_悬停在鼠标右侧(t, 树根)

func _段4a_未打完也能结算(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4a：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ★ RT-3b：改用双入口里的新入口（自动开单机牌组）—— 旧入口那场战斗打不出牌，
	#   「没打完就结算」那条路会一路推到超回合上限，就不是这里要验的东西了。
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013):
		t.ok(false, "段 4a：开始快速测试战斗(秘银, 20261013) 开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "段 4a：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var 按钮 := _找按文(bv, "结束并结算")
	t.ok(按钮 != null, "段 4a：战斗屏上有「结束并结算」按钮")
	if 按钮 == null:
		_拆boot(树根, 舱)
		return
	t.ok(s.battle_ctx is Dictionary and s.battle_ctx.get("result") == null,
		"★ 段 4a：点之前这一场**确实还没分出胜负**（result = %s）" % str(s.battle_ctx.get("result")))
	t.ok(not 按钮.disabled,
		"★★ 段 4a：战斗没打完时「结算按钮」**不是灰的**（disabled = %s）—— 从前这里是 `not 打完`，于是点了没反应"
		% str(按钮.disabled))
	按钮.pressed.emit()
	await _等帧(3)
	t.ok(s.battle_ctx is Dictionary and s.battle_ctx.get("result") != null,
		"★★ 段 4a：点一下「结束并结算」就**自动把本场打完**了（result = %s）" % str(s.battle_ctx.get("result")))
	t.ok(s.screen == "result", "★★ 段 4a：点完 → screen = result（真实值「%s」）" % s.screen)
	t.ok(boot.当前视图() is ResultView, "★★ 段 4a：结算屏真的路由出来了（当前视图 = %s）" % str(boot.当前视图()))
	t.ok(bool((s.result_summary() as Dictionary).get("有结果", false)),
		"★ 段 4a：结算屏读到的门面结果「有结果」= true")
	# 再点一次不该重复结算（幂等闸 D-07 照旧）
	var 再点 := _找按文(boot, "结束并结算")
	if 再点 != null:
		再点.pressed.emit()
		await _等帧(2)
	t.ok(int(s.run_state.battles_fought) <= 1, "★ 段 4a：重复点「结算」不会原地刷场次（场次 = %d）" % int(s.run_state.battles_fought))
	_拆boot(树根, 舱)

## ④-b「选完小队没有招募页面 / 招募券要求做出决定」：开局直达招募 + 券闭环。
func _段4b_开局直达招募与券闭环(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4b：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	s.screen = "squad"
	boot.route()
	await _等帧(3)
	var mv = boot.当前视图()
	if not (mv is MenuView):
		t.ok(false, "段 4b：分队屏视图类型不对（%s）" % str(mv))
		_拆boot(树根, 舱)
		return
	var 开局 := _找按文(mv, "开这一局")
	t.ok(开局 != null, "★ 段 4b：分队屏上有「开局按钮」")
	if 开局 == null:
		_拆boot(树根, 舱)
		return
	var 种子框 = mv.find_child("种子输入", true, false)
	if 种子框 is LineEdit:
		(种子框 as LineEdit).text = "20261016"  # 菜单默认随机种子（10-22），这里钉住保证可复现
	开局.pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "map" and s.run_state != null,
		"★ 段 4b：点「开这一局」→ 开出一局（screen「%s」/ 第 %d 层）"
		% [s.screen, int(s.run_state.floor_num) if s.run_state != null else 0])
	# ★ 「门面的默认值没被改」那一半要**直接调门面**来验（点按钮之后 modal 已经被视图层打开了）。
	var 干净会话 := GameSession.new()
	干净会话.存档路径 = "res://.godot/tmp_layout_段4b.json"
	t.ok(干净会话.start_new_run(20261017, "混编"), "★ 段 4b（对照）：直接调门面 `start_new_run()` 也开得出局")
	t.ok(干净会话.modal is Dictionary and (干净会话.modal as Dictionary).is_empty(),
		"★★ 段 4b：门面 `start_new_run()` 的默认值**一个字都没改**：直接调它之后 `modal` 仍是空的（%s）—— 弹招募是视图层发的信号" % str(干净会话.modal))
	t.ok(干净会话.screen == "map" and 干净会话.ticket_count() > 0,
		"★ 段 4b（对照）：`screen` 仍是 map（「%s」）、券 %d 张 —— test_session_flow / test_session_run 的既有断言照旧"
		% [干净会话.screen, 干净会话.ticket_count()])
	t.ok(s.ticket_count() > 0, "★ 段 4b：开局发了 %d 张招募券、名册 %d 台" % [s.ticket_count(), s.roster_count()])
	# 开局那一下的弹窗是视图层信号打开的：此时弹窗层已经挂上【招募】
	t.ok(_弹窗类型(s) == "招募" and _弹窗可见(boot),
		"★★ 段 4b：选完分队点「开这一局」**立刻弹出【招募】弹窗**（类型 =「%s」，层可见 = %s）"
		% [_弹窗类型(s), str(_弹窗可见(boot))])
	var 关闭: Control = boot.find_child("关闭按钮", true, false)
	t.ok(关闭 != null and not 关闭.visible,
		"★★ 段 4b：名册 0 台 + 手上还有券 → 「关闭」按钮被收起来（不许 0 机体裸奔进大地图）")
	# ---- 决定之一：招一台 ----
	var 候选 = boot.find_child("候选列表", true, false)
	var 候选钮 := _找按钮(候选)
	t.ok(候选钮 is Button, "★ 段 4b：招募面板「这张券能招谁」里列出了可点的候选机体")
	if 候选钮 is Button:
		var 券前 := s.ticket_count()
		(候选钮 as Button).pressed.emit()
		await _等帧(3)
		t.ok(s.roster_count() == 1, "★★ 段 4b：点候选机体 → 招到 1 台（名册 %d 台）" % s.roster_count())
		t.ok(s.ticket_count() == 券前 - 1, "★ 段 4b：招募吃掉 1 张券（%d → %d）" % [券前, s.ticket_count()])
		t.ok(_弹窗类型(s) == "三选一", "★★ 段 4b：招完自动接「三选一」（类型 =「%s」）" % _弹窗类型(s))
	# ---- 三选一选完 → 还有券就**自动回招募** ----
	if s.run_state != null and not s.run_state.pending_card_picks.is_empty():
		var 选这张 := _找按文(boot, "选这张")
		t.ok(选这张 != null, "★ 段 4b：三选一里有「选这张」按钮")
		if 选这张 != null:
			var 券在 := s.ticket_count()
			选这张.pressed.emit()
			await _等帧(3)
			t.ok(s.run_state.pending_card_picks.is_empty(),
				"★ 段 4b：选完牌 → `pending_card_picks` 空了")
			if 券在 > 0:
				t.ok(_弹窗类型(s) == "招募",
					"★★ 段 4b：三选一选完、**手上还有 %d 张券** → 自动回到【招募】页面（类型 =「%s」）"
					% [券在, _弹窗类型(s)])
	# ---- 决定之二：把剩下的券全部「放弃此券」 ----
	var 放弃 := _找按文(boot, "放弃此券")
	t.ok(放弃 != null and not 放弃.disabled, "★★ 段 4b：招募面板上有可点的【放弃此券】（做出的第二个决定）")
	var 丢 := 0
	while s.ticket_count() > 0 and 丢 < 8:
		var 券前2 := s.ticket_count()
		if 放弃 == null or 放弃.disabled:
			放弃 = _找按文(boot, "放弃此券")
		if 放弃 == null:
			break
		放弃.pressed.emit()
		await _等帧(2)
		if s.ticket_count() >= 券前2:
			break
		丢 += 1
	t.ok(s.ticket_count() == 0, "★★ 段 4b：连点【放弃此券】%d 次 → 券全部决定完（剩 %d 张）" % [丢, s.ticket_count()])
	关闭 = boot.find_child("关闭按钮", true, false)
	t.ok(关闭 != null and 关闭.visible,
		"★ 段 4b：名册非空 + 券已决定完 → 「关闭」按钮又回来了")
	# ---- 决定做完之后的收尾按钮 ----
	# ★ 2026-10-18：券全部决定完（且没有待选牌）之后，现身的**唯一**那颗醒目按钮是
	#   【完成招募 · 去编队】（刚开局 0 场战斗时）/【完成 · 返回大地图】；
	#   【去编队出击】只在「还有券没决定」时现身。这里两类都认，两边都验。
	var 完成钮: Control = boot.find_child("完成返回地图按钮", true, false)
	t.ok(完成钮 is Button and (完成钮 as Button).visible,
		"★★ 段 4b：券全部决定完 → 【%s】现身（`完成返回地图按钮`）"
		% (str((完成钮 as Button).text) if 完成钮 is Button else "—"))
	var 去编队钮: Control = boot.find_child("去编队出击按钮", true, false)
	t.ok(去编队钮 is Control and not (去编队钮 as Control).visible,
		"★ 段 4b：还有券时才现身的【去编队出击】此时藏起来（节点还在树里，`find_child` 照旧找得到）")
	var 去编队 := 完成钮
	t.ok(去编队 != null, "★ 段 4b：招募面板底部有收尾按钮")
	if 去编队 != null:
		(去编队 as Button).pressed.emit()
		await _等帧(3)
	t.ok(s.screen == "formation", "★★ 段 4b：点收尾按钮 → screen = formation（真实值「%s」）" % s.screen)
	t.ok(_弹窗类型(s).is_empty() and not _弹窗可见(boot),
		"★★ 段 4b：同时把招募弹窗关掉了（modal 类型 =「%s」、层可见 = %s）" % [_弹窗类型(s), str(_弹窗可见(boot))])
	_拆boot(树根, 舱)

func _段4c_悬停在鼠标右侧(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4c：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	var 层 = boot.find_child("悬停说明层", true, false)
	if not (层 is HoverTooltip):
		t.ok(false, "段 4c：找不到「悬停说明层」")
		_拆boot(树根, 舱)
		return
	var 悬停: HoverTooltip = 层
	悬停.show_text("段 4c 测试说明：把面板摆到鼠标右边，绝不压住指针本身。", "悬停定位", null)
	await _等帧(1)
	var 面板: Control = 悬停.find_child("悬停面板", true, false)
	t.ok(面板 != null and 面板.visible, "★ 段 4c：`show_text()` 之后「悬停面板」显示出来了")
	if 面板 == null:
		_拆boot(树根, 舱)
		return
	var mp := Vector2(400.0, 300.0)
	悬停._夹紧(mp)
	t.ok(面板.position.x >= mp.x + 20.0,
		"★★ 段 4c：鼠标在 %s 时面板位于鼠标**右侧**（面板.x = %.1f >= %.1f）—— 不在鼠标中间"
		% [str(mp), 面板.position.x, mp.x + 20.0])
	t.ok(面板.position.y < mp.y,
		"★ 段 4c：纵向也从鼠标上方一点点起（面板.y = %.1f < %.1f）" % [面板.position.y, mp.y])
	t.ok(_在界内(面板.get_global_rect()),
		"★ 段 4c：右侧定位之后面板 %s 仍然完全落在 1280×720 内" % _短(面板.get_global_rect()))
	# 鼠标贴右边缘：右边放不下 → 翻到左边，且不出右界
	var 靠右 := Vector2(画布宽 - 4.0, 300.0)
	悬停._夹紧(靠右)
	t.ok(面板.position.x < 靠右.x,
		"★★ 段 4c：鼠标贴右边缘（%s）时面板翻到鼠标**左边**（面板.x = %.1f）" % [str(靠右), 面板.position.x])
	t.ok(面板.position.x + 面板.size.x <= 画布宽 - 8.0 + 0.5,
		"★ 段 4c：翻到左边之后右边缘也没出界（面板 %s）" % _短(面板.get_global_rect()))
	悬停.hide_tip()
	_拆boot(树根, 舱)

# 段 5：★ 实时监视（2026-10-16 新增）—— 局面快照 + 全动作记录 + 信号触发
#
#   规格（主会话靠 `F:\DSH-mecha\.tools\smoke\live_state.json` / `live_actions.jsonl` 看作者
#   在本地网页里的每一步）：这一段钉三件事，**全部 headless 可验**（Web 发送那一层靠
#   `OS.has_feature("web")` 关掉，桌面 / headless 一个字节都不发 → 这里只验「记录」这一层）：
#     ① `snapshot_for_monitor()` 的字段齐（顶层 + 有局 + 战斗中三档）；
#     ② 每一个核心玩家动作走完都**自动追加** `action_history` 一条，且 `action_recorded` 真的发；
#     ③ 记录本身**不改返回值**（同一次调用的返回值与私下直调内部实现逐字相同）。

func _段6_战前编队确认与顶栏锁(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 6：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)
	if s.run_state == null:
		t.ok(s.start_new_run(20261111, "混编"), "★ 段 6：开一局（第 1 层）")
	# ---- 先招募 / 上阵（战斗格要出击名单非空）----
	var 招 := 0
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "★ 段 6：用开局券招到 %d 台（名册 %d 台、券 %d 张）" % [招, s.roster_count(), s.ticket_count()])
	_清待选(s)
	var 丢 := _清券(s)
	t.ok(s.ticket_count() == 0, "★ 段 6：把没决定的券处理完（券 %d 张）" % s.ticket_count())
	var 上阵 := _编队第一台(s)
	t.ok(上阵, "★ 段 6：把一台摆上出击位（出击 %d 台）" % s.run_state.lineup.size())
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "★ 段 6：第 %d 层找不到战斗格" % s.run_state.floor_num)
		_拆boot(树根, 舱)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "★ 段 6：战斗格 %d 四周找不到落脚点" % 战斗格)
		_拆boot(树根, 舱)
		return
	s.run_state.node_id = 落脚
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(落脚).get("类型", ""))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 6：大地图视图类型不对（%s）" % str(mv))
		_拆boot(树根, 舱)
		return
	# ---- ① 走上战斗格 → 战前编队确认屏（**不是**直接开打）----
	(mv as MapView)._点格(战斗格)
	await _等帧(3)
	t.ok(s.screen == "formation", "★★ 段 6：走上战斗格 %d → screen = %s（**先进战前编队确认屏**，不是直接开打）" % [战斗格, s.screen])
	t.ok(s.pending_battle_confirm, "★★ 段 6：`session.pending_battle_confirm == true`（战前确认态）")
	t.ok(str(s.pending_battle_kind) == "node", "★ 段 6：`pending_battle_kind = %s`（脚下这一格的节点战）" % str(s.pending_battle_kind))
	t.ok(s.battle_ctx.is_empty(), "★★ 段 6：确认之前**一场都还没开**（battle_ctx 空 = %s）" % str(s.battle_ctx.is_empty()))
	var 开始钮: Control = boot.find_child("开始战斗按钮", true, false)
	var 回钮: Control = boot.find_child("回地图按钮", true, false)
	var 标: Control = boot.find_child("战前编队标题", true, false)
	t.ok(开始钮 is Button and (开始钮 as Button).visible,
		"★★ 段 6：【确认编队 · 开始战斗】按钮 `visible == true`（文案「%s」）" % (str((开始钮 as Button).text) if 开始钮 is Button else "—"))
	t.ok(回钮 is Control and not (回钮 as Control).visible,
		"★★ 段 6：【回地图按钮】`visible == false` —— 不许退回大地图逃避当前格战斗")
	t.ok(标 is Label and (标 as Label).visible and str((标 as Label).text).contains("战前编队确认"),
		"★★ 段 6：顶部标题醒目写出「【战前编队确认】…」（%s）"
		% (str((标 as Label).text).substr(0, 28) if 标 is Label else "—"))
	# ---- ② 点【确认编队 · 开始战斗】→ 才进 battle ----
	var bv = (开始钮 as Button)
	bv.pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "battle", "★★ 段 6：点【确认编队 · 开始战斗】→ screen = %s" % s.screen)
	t.ok(not s.pending_battle_confirm and not s.battle_ctx.is_empty(),
		"★★ 段 6：确认态放掉、真开起来了（pending = %s、我方 %d 台 / 敌方 %d 台）"
		% [str(s.pending_battle_confirm),
			(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "confirm_formation_and_start_battle",
		"★ 段 6：这一步记进了全动作记录（动作名 = %s）" % str(s.action_history[s.action_history.size() - 1].get("action", "")))
	# ---- ③ 战斗中顶栏两个跳转按钮都置灰 ----
	boot.route()
	await _等帧(2)
	var 招募钮: Control = boot.find_child("招募按钮", true, false)
	var 编队钮: Control = boot.find_child("编队按钮", true, false)
	var 牌库钮: Control = boot.find_child("战术牌库按钮", true, false)
	t.ok(招募钮 is Button and (招募钮 as Button).disabled,
		"★★ 段 6：战斗中「招募按钮」`disabled == true`（文案「%s」）" % (str((招募钮 as Button).text) if 招募钮 is Button else "—"))
	t.ok(编队钮 is Button and (编队钮 as Button).disabled,
		"★★ 段 6：战斗中「编队按钮」`disabled == true`")
	t.ok(牌库钮 is Button and (牌库钮 as Button).disabled,
		"★ 段 6：战斗中「战术牌库按钮」也是灰的")
	# ---- ④ 状态机守卫：不许把战斗打一半切去编队屏 ----
	var 屏前 := str(s.screen)
	boot.去屏("formation")
	await _等帧(2)
	t.ok(str(s.screen) == 屏前 and str(s.screen) == "battle",
		"★★ 段 6：战斗中调 `boot.去屏(\"formation\")` 被守卫拦下（screen 仍是 %s，不是切换后的 formation）" % s.screen)
	boot.去屏("map")
	await _等帧(2)
	t.ok(str(s.screen) == "battle",
		"★★ 段 6：战斗中调 `boot.去屏(\"map\")` 同样被拦下（screen 仍是 %s）—— 杜绝孤儿战斗死锁" % s.screen)
	# ---- ⑤ 结算之后守卫放行：能正常回大地图 ----
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	await _等帧(2)
	t.ok(s.screen == "result", "★ 段 6：打完并结算 → screen = %s" % s.screen)
	boot.去屏("map")
	await _等帧(2)
	t.ok(s.screen == "map", "★★ 段 6：结算之后 `去屏(\"map\")` 放行（screen = %s）—— 守卫只拦「打一半」" % s.screen)
	_拆boot(树根, 舱)

# 段 7：★ 2026-10-18 作者试玩反馈第 2 / 3 条 —— 同一格幂等 + 战后严格 90% 给 1 张券

func _段7_幂等休整与战后九十概率(t, 树根: Node) -> void:
	await _段7a_同一休整格只结算一次(t)
	await _段7b_战后九十概率给券(t)

## 开一局并**换层找到一格带「休整」的层**，返回那一格的编号（找不到 → −1）。
func _找一格带休整的局(s: GameSession) -> int:
	for i in 20:
		if not s.start_new_run(20261204 + i * 97, "混编"):
			continue
		if s.run_state == null:
			continue
		for 层 in 3:
			if s.run_state == null:
				break
			var 是 := _找一个类型格(s, ["休整"])
			if 是 < 0:
				是 = _找可达的格(s, ["休整"])
			if 是 >= 0:
				return 是
			# 这一层没有休整 → 直接换一层看看（推进剂 / 出口都不要紧，这是造局面）
			if not MapNavigator.advance_floor(s.run_state).get("ok", false):
				break
	return -1

func _段7a_同一休整格只结算一次(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段7a.json"
	# 找一个**真的有休整格**的局面（★ 第 1 层的「休整」计划数 = 0，休整从第 2 层起才有；
	# 所以这里靠 `_找一格带休整的局()` 直接换层找，找不到也不假绿）。
	var 休 := _找一格带休整的局(s)
	if 休 < 0 or s.run_state == null:
		t.ok(false, "★ 段 7a：换到第 4 层都找不到休整格 —— 断言跑不了")
		return
	var mv := MapView.new()
	# 把脚下摆到休整格上（造局面；表现层不参与）
	s.run_state.node_id = 休
	s.run_state.map_data["当前节点类型"] = "休整"
	t.ok(str(s.run_state.current_type()) == "休整", "★ 段 7a：脚下这一格是休整（格 %d）" % 休)
	var 前耐 := int(s.run_state.base_hp)
	var 前推 := int(s.run_state.propellant)
	var 前希 := int(s.run_state.hope)
	var 一 := s.resolve_rest("推进剂")
	t.ok(bool(一.get("ok", false)), "★★ 段 7a：第 1 次 `resolve_rest(\"推进剂\")` 成功（%s）" % str(一.get("选", "")))
	var 中耐 := int(s.run_state.base_hp)
	var 中推 := int(s.run_state.propellant)
	var 中希 := int(s.run_state.hope)
	t.ok(中耐 >= 前耐 and 中推 >= 前推,
		"★ 段 7a：第 1 次真的结算了（耐久 %d → %d、推进剂 %d → %d、希望 %d → %d）"
		% [前耐, 中耐, 前推, 中推, 前希, 中希])
	var 二 := s.resolve_rest("推进剂")
	t.ok(not bool(二.get("ok", false)), "★★ 段 7a：同一格第 2 次 `resolve_rest` 被幂等拦下（ok = %s）" % str(二.get("ok", false)))
	t.ok(str(二.get("为什么", "")) == "当前节点已结算完毕",
		"★★ 段 7a：拦下的原因写清了（「%s」）" % str(二.get("为什么", "")))
	t.ok(int(s.run_state.base_hp) == 中耐 and int(s.run_state.propellant) == 中推 and int(s.run_state.hope) == 中希,
		"★★ 段 7a：第 2 次一个字都没改（耐久 %d · 推进剂 %d · 希望 %d 与第 1 次之后逐项相同）"
		% [int(s.run_state.base_hp), int(s.run_state.propellant), int(s.run_state.hope)])
	# 再连点 4 次也不许刷（原作者反馈里的「连点 6 次刷属性」）
	var 全拦 := true
	for _i in 4:
		if bool(s.resolve_rest("耐久").get("ok", false)):
			全拦 = false
	t.ok(全拦, "★★ 段 7a：再连点 4 次 `resolve_rest` 也全被拦下（总共 6 次里只有第 1 次生效）")
	mv.free()

func _段7b_战后九十概率给券(t) -> void:
	var 场次 := 50
	var 给券场 := 0
	var 多给场 := 0
	var 跑通 := 0
	var 坏 := ""
	for i in 场次:
		var r := _跑一场数券(20270001 + i * 137)
		if not bool(r.get("ok", false)):
			坏 = str(r.get("为什么", ""))
			continue
		跑通 += 1
		var n := int(r.get("本场券", 0))
		if n >= 1:
			给券场 += 1
		if n > 1:
			多给场 += 1
	t.ok(跑通 >= 45, "★ 段 7b：50 个种子里跑通了 %d 场参与统计（失败样例：%s）" % [跑通, 坏 if not 坏.is_empty() else "无"])
	var 率 := float(给券场) / float(maxi(1, 跑通))
	t.ok(率 >= 0.80 and 率 <= 0.98,
		"★★ 段 7b：战后给券率 = %d / %d = %.1f%% 落在 80%%–98%% 之间（规格 = 90%%）"
		% [给券场, 跑通, 率 * 100.0])
	t.ok(多给场 == 0,
		"★★ 段 7b：没有任何一场发了**2 张以上**券（多给场次 = %d）—— 每次战斗最多 1 张" % 多给场)

func _跑一场数券(种子: int) -> Dictionary:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段7b.json"
	if not s.start_new_run(种子, "混编"):
		return {"ok": false, "为什么": "开局失败"}
	if s.run_state == null:
		return {"ok": false, "为什么": "没有 run_state"}
	# 招募 + 上阵（走门面；名额与券都由内核给）
	for _i in 4:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if not bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			break
	if s.run_state.roster.is_empty():
		return {"ok": false, "为什么": "招不到人"}
	var 键们 := s.run_state.roster.keys()
	for j in mini(2, 键们.size()):
		s.set_lineup_slot(str(键们[j]), str(s.lineup_slots()[j].get("位名", "")))
	if s.run_state.lineup.is_empty():
		return {"ok": false, "为什么": "上不了阵"}
	# 招募会带出「三选一」：先选掉，免得待选牌影响后面的换层 / 结算路径。
	var 选 := 0
	while s.run_state != null and not s.run_state.pending_card_picks.is_empty() and 选 < 12:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选 += 1
	# 把还没决定的券全部放弃（不然门面会拦住「开新战斗」，见 `_打追击战()` 那道闸）
	var 丢 := 0
	while s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	var 格 := _找战斗格(s)
	if 格 < 0:
		return {"ok": false, "为什么": "找不到战斗格"}
	s.run_state.node_id = 格
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(格).get("类型", ""))
	var 券前 := s.ticket_count()
	if not s.start_node_battle():
		return {"ok": false, "为什么": "开战失败"}
	if s.battle_ctx.is_empty():
		return {"ok": false, "为什么": "battle_ctx 空"}
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	if s.screen != "result":
		return {"ok": false, "为什么": "没有进结算屏（screen = %s）" % s.screen}
	var 战: Dictionary = (s.result_summary() as Dictionary).get("战利品", {})
	var 有券 := 战.get("券") is Dictionary
	var 券后 := s.ticket_count()
	var 本场 := 券后 - 券前
	# 交叉核对：战利品那一格与券池的增减必须一致（补发 / 保留 / 撤回三条路都要对得上）
	if int(本场) != (1 if 有券 else 0):
		return {"ok": false, "为什么": "战利品券与券池增减对不上（券池 %d、战利品有券 = %s）" % [本场, str(有券)]}
	return {"ok": true, "本场券": int(本场), "战利品有名": str(战.get("券名", ""))}

func _找可达的格(s: GameSession, 类型们: Array) -> int:
	if s == null or s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if not 类型们.has(str(s.run_state.cell_at(k).get("类型", ""))):
			continue
		if bool(s.preview_cell_move(k).get("ok", false)):
			return int(k)
	return -1

func _找一个类型格(s: GameSession, 类型们: Array) -> int:
	if s == null or s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if 类型们.has(str(s.run_state.cell_at(k).get("类型", ""))):
			return int(k)
	return -1
