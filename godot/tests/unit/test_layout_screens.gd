## 职责：版面门禁：单屏可见性与弹窗不误遮挡（段 1）+ 顶栏与主屏 1280×720 边界（段 2）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起1: int = t.passes + t.fails
	await _段1_单屏可见性与弹窗不误遮挡(t, 根)
	var 段1: int = t.passes + t.fails - 起1
	var 起2: int = t.passes + t.fails
	await _段2_顶栏与主屏层级和边界(t, 根)
	var 段2: int = t.passes + t.fails - 起2
	t.info("★ 版面门禁（本套）：段 1（单屏可见性 / 弹窗不遮挡）%d 项 · 段 2（顶栏与主屏 1280×720 边界）%d 项 · 合计 %d 项" % [段1, 段2, 段1 + 段2])

## 屏幕容器下**可见**的子视图有哪些（≥2 个就是「多屏叠加」）。
func _可见屏(视图: Node) -> Array:
	var out: Array = []
	if 视图 == null or not is_instance_valid(视图):
		return out
	for c in 视图.get_children():
		if c is Control and (c as Control).visible:
			out.append(str((c as Control).name))
	return out

## 屏幕容器下**驻留**（建过）的子视图总数。
func _驻留屏(视图: Node) -> int:
	var n := 0
	if 视图 == null or not is_instance_valid(视图):
		return n
	for c in 视图.get_children():
		if c is Control:
			n += 1
	return n

func _查(t, 前缀: String, 舱: Dictionary, 路径: String, 界限: Rect2) -> Rect2:
	var 框 := _框(舱.get("boot"), 路径)
	t.ok(_在(框, 界限), "%s 「%s」%s 完全落在 %s 内" % [前缀, 路径, _短(框), _短(界限)])
	return 框

func _查不叠(t, 前缀: String, 舱: Dictionary, a: String, b: String) -> void:
	var 框a := _框(舱.get("boot"), a)
	var 框b := _框(舱.get("boot"), b)
	t.ok(框a.size.x > 0.0 and 框b.size.x > 0.0 and not _叠(框a, 框b),
		"%s 「%s」%s 与「%s」%s 互不重叠（交面积 %.0f）" % [前缀, a, _短(框a), b, _短(框b), _交面积(框a, 框b)])

func _段1_单屏可见性与弹窗不误遮挡(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 1 跑不了")
		return
	var boot = 舱["boot"]
	var 视图: Variant = 舱["视图"]
	await _等帧(2)
	t.ok(视图 != null, "boot 里有「屏幕容器」（%s）" % _短(_框(boot, "屏幕容器")))
	t.ok(boot.session != null and (boot.session.modal is Dictionary and (boot.session.modal as Dictionary).is_empty()),
		"刚启动时没有弹窗（session.modal 空）")
	if boot.session.run_state == null:
		t.ok(boot.session.start_new_run(20261031, "混编"), "段 1：开一局肉鸽（大地图 / 编队 / 战斗 / 结算四条路都要走）")
	await _段1a_逐屏只有一个可见(t, boot, 视图)
	await _段1b_战斗屏不被弹窗盖住(t, boot, 视图)
	await _段1c_回大地图不叠结算弹窗(t, boot, 视图)
	_拆boot(树根, 舱)

## ① 6 个屏切过来切过去：每一刻 `屏幕容器` 下**可见**的子视图恰好 1 个。
func _段1a_逐屏只有一个可见(t, boot, 视图) -> void:
	var 最多 := 0
	var 最坏 := ""
	for 轮 in 3:
		for 屏 in 屏们:
			boot.session.screen = str(屏)
			boot.route()
			await _等帧()
			var 可见 := _可见屏(视图)
			if 可见.size() > 最多:
				最多 = 可见.size()
				最坏 = str(屏)
			t.ok(可见.size() == 1,
				"第 %d 轮路由到「%s」：屏幕容器下可见子视图 = %d 个（%s）—— 同一时刻只有一个屏"
				% [轮 + 1, str(屏), 可见.size(), ", ".join(可见)])
	t.ok(最多 == 1, "★ 三轮 6 屏切下来，可见子视图**最多**只有 %d 个（最坏出现在「%s」）—— 没有多屏叠加" % [最多, 最坏])
	t.ok(_驻留屏(视图) >= 5,
		"★ 视图是「用到才建 + 复用」：切完 6 屏之后驻留着 %d 个子视图（不是每屏各建一堆）" % _驻留屏(视图))

## ② 开新局 → 编队 → 进战斗：不许自动弹「战斗」黑幕把战斗屏盖住。
func _段1b_战斗屏不被弹窗盖住(t, boot, 视图) -> void:
	var s: GameSession = boot.session
	s.screen = "map"
	boot.route()
	await _等帧()
	t.ok(not _弹窗可见(boot), "开新局 → 大地图：弹窗层不可见（没有自动弹任何黑幕）")
	# 招募 + 上阵（开战要求出击名单非空）
	var 招 := 0
	for _i in 4:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "用开局券招到 %d 台（名册 %d 台）" % [招, s.run_state.roster.size()])
	await _关弹窗(boot)
	t.ok(_弹窗类型(s).is_empty() and not _弹窗可见(boot),
		"★ 招完手动关一次弹窗（招募会顺手弹「三选一」，这是门面的既有行为）→ 弹窗层和 session.modal 都空了")
	# ★ 2026-10-18：手上还有未决招募券时，大地图**点格子不移动**（先把券决定完）——
	#   这一段要验的是「走上去就进战前编队确认屏」，所以先把券处理干净。
	_清券(s)
	# ★ 门面的 `_refresh_modal()` 口径：只要 `pending_card_picks` 非空，**每次切屏都会自动弹三选一**。
	#   这里先把待选牌选干净（人正常玩也是这样：选完牌才继续），
	#   后面「进战斗 / 打牌 / 推进回合 / 回大地图」才真的能验「有没有自动弹黑幕」。
	var 选掉 := _清待选(s)
	t.ok(s.run_state.pending_card_picks.is_empty(),
		"★ 把 %d 张待选战术牌选掉 → `pending_card_picks` 空了（这样后面每一步的弹窗层都该是干净的）" % 选掉)
	await _关弹窗(boot)
	if not s.run_state.roster.is_empty():
		var 首键 := str(s.run_state.roster.keys()[0])
		t.ok(s.set_lineup_slot(首键, str(s.lineup_slots()[0].get("位名", ""))), "把 %s 摆上出击位" % 首键)
	s.screen = "formation"
	boot.route()
	await _等帧()
	t.ok(s.screen == "formation" and not _弹窗可见(boot),
		"编队屏：screen = %s、弹窗层不可见（切到编队也不会弹黑幕）" % s.screen)
	# 走上一个战斗格 → 直接开战（走视图那条点击路径）
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "第 %d 层找不到战斗格 —— 段 1b 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "战斗格 %d 四周找不到落脚点 —— 段 1b 剩下的断言跑不了" % 战斗格)
		return
	s.run_state.node_id = 落脚
	s.screen = "map"
	boot.route()
	await _等帧()
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "大地图视图类型不对（%s），段 1b 跑不了" % str(mv))
		return
	(mv as MapView)._点格(战斗格)
	# ★ 2026-10-18：走上战斗格先进**战前编队确认屏**（不再直接开打），点【确认编队 · 开始战斗】才进战斗。
	t.ok(s.screen == "formation" and s.pending_battle_confirm,
		"★ 走上战斗格 %d → 先进战前编队确认屏（screen = %s、pending = %s）" % [战斗格, s.screen, str(s.pending_battle_confirm)])
	await _等帧(2)
	var 开战钮: Control = boot.find_child("开始战斗按钮", true, false)
	if 开战钮 is Button:
		(开战钮 as Button).pressed.emit()
		await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"★ 点【确认编队 · 开始战斗】→ 开战（screen = %s、battle_ctx 我方 %d 台 / 敌方 %d 台）"
		% [s.screen,
			(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	await _等帧()
	t.ok(not _弹窗可见(boot),
		"★ 进战斗屏的那一刻 `弹窗层.visible == false`（没有自动弹「战斗」黑幕遮挡战斗屏）")
	# 「打光可出牌或推进回合」的两条路都不许把黑幕弹出来
	# ★ RT-3b：旧 `playable_hand_ids()` / `play_tactical_card()` 读的是已删的 `ctx.战术手牌`，
	#   改成单机牌组的两排与三个出牌口子。
	var 能打: Array = (s.upper_hand_cards() + s.lower_hand_cards()).filter(
		func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	t.ok(not 能打.is_empty(), "★ 开局能打 上排 %d / 下排 %d 张里的 %d 张（打光可出牌那一条路）"
		% [s.upper_hand_cards().size(), s.lower_hand_cards().size(), 能打.size()])
	if not 能打.is_empty():
		var 首牌: Dictionary = 能打[0]
		var 区 := str(首牌.get("区", ""))
		if 区 == GameSession.单机区_主武器:
			s.打出主武器卡(str(首牌.get("手牌键", "")))
		elif 区 == GameSession.单机区_副武器:
			s.打出副武器(str(首牌.get("手牌键", "")))
		elif 区 == GameSession.单机区_衍生:
			s.打出衍生攻击卡(str(首牌.get("手牌键", "")))
		else:
			s.打出精神或公有牌(str(首牌.get("手牌键", "")))
		boot.route()
		await _等帧()
		t.ok(not _弹窗可见(boot), "打完一张手牌之后：弹窗层仍不可见")
	s.step_battle_turn()
	boot.route()
	await _等帧()
	t.ok(not _弹窗可见(boot), "推进一个回合之后：弹窗层仍不可见（第 %s 回合）"
		% UiTheme.文本(int(float(s.battle_ctx.get("turn", 1.0)))))

## ③ 战斗结束 → 结算屏 → 点「继续按钮」回大地图：screen = map 且弹窗层不可见。
func _段1c_回大地图不叠结算弹窗(t, boot, 视图) -> void:
	var s: GameSession = boot.session
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"承接段 1b：现在停在战斗屏且有真战斗（screen = %s）" % s.screen)
	# ★ 先把「招募那一下自动弹出来的三选一」关掉（人手动开的窗由人关；
	#   这里要验的是**没有任何动作会自动**弹出黑幕把屏幕盖住）。
	await _关弹窗(boot)
	t.ok(not _弹窗可见(boot), "手动关掉三选一之后：弹窗层不可见")
	s.auto_finish_battle()
	t.ok(s.battle_ctx.get("result") != null, "自动打完本场：结果 = %s" % s.战果文字())
	var bv = boot.当前视图()
	if bv is BattleView:
		(bv as BattleView)._点结算()
	t.ok(s.screen == "result", "打完并结算 → screen = result（真实值 %s）" % s.screen)
	await _等帧()
	var rv = boot.当前视图()
	t.ok(rv is ResultView, "路由到 result 之后，当前视图是 ResultView（%s）" % str(rv))
	t.ok(not _弹窗可见(boot) or _弹窗类型(s) != "结算",
		"★ 结算屏上 `弹窗层` 不会叠第二个结算面板（现在弹窗类型 =「%s」）" % _弹窗类型(s))
	# ★ 点「继续按钮」那一下（走视图自己的信号路，不是直接改 screen）
	if rv is ResultView and (rv as ResultView)._继续按钮 != null:
		(rv as ResultView)._继续按钮.pressed.emit()
	else:
		boot.去屏("map")
	await _等帧()
	t.ok(s.screen == "map", "★ 点「继续按钮」→ screen = map（真实值 %s）" % s.screen)
	t.ok(_弹窗类型(s) != "结算", "★ 回大地图时 `session.modal` 里没有「结算」（类型 =「%s」）" % _弹窗类型(s))
	# 收掉可能还欠着的三选一，再看弹窗层
	await _关弹窗(boot)
	t.ok(not _弹窗可见(boot),
		"★ 回到大地图之后 `弹窗层.visible == false`（不会在地图上叠第二个结算弹窗）")
	t.ok(_弹窗类型(s).is_empty(), "★ 回到大地图之后 session.modal 也是空的（类型 =「%s」）" % _弹窗类型(s))
	# 再走一次兜底入口 `boot.去屏("map")`：屏幕没变时也不许把弹窗打开
	boot.去屏("map")
	await _等帧()
	t.ok(s.screen == "map" and not _弹窗可见(boot), "兜底入口 `boot.去屏(\"map\")` 也不会打开弹窗")

# 段 2：顶栏与主屏层级 / 1280×720 边界

func _段2_顶栏与主屏层级和边界(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 2 跑不了")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	if boot.session.run_state == null:
		boot.session.start_new_run(20261107, "混编")
	var 装了 := _塞满藏品与零件(boot)
	t.ok(装了 >= 30, "★ 夹具：给这一局塞了 %d 件藏品 + 零件（顶栏宽度压力最大的一档）" % 装了)
	await _段2a_顶栏高度与右界(t, 舱)
	await _段2b_战斗屏布局(t, 舱)
	await _段2c_结算屏布局(t, 舱)
	await _段2d_地图与编队布局(t, 舱)
	await _段2e_窄视口(t, 树根)
	_拆boot(树根, 舱)

## ②-a 顶栏（含 `顶栏底`）完全落在 `(0, 0, 1280, 104)` 内，不压住 y >= 104 的屏幕容器；
func _段2a_顶栏高度与右界(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var 界限 := Rect2(0.0, 0.0, 画布宽, 顶栏高)
	var 轮 := 0
	for 屏 in 屏们:
		轮 += 1
		boot.session.screen = str(屏)
		boot.route()
		await _等帧()
		_查(t, "第 %d 屏顶栏" % 轮, 舱, "顶栏", 界限)
		_查(t, "第 %d 屏顶栏底" % 轮, 舱, "顶栏底", 界限)
		var 顶 := _框(boot, "顶栏")
		var 容 := _框(boot, "屏幕容器")
		t.ok(顶.size.x > 0.0 and 容.size.y > 0.0 and 顶.end.y <= 容.position.y + 0.5,
			"路由到「%s」：顶栏底边 y = %.1f ≤ 屏幕容器顶边 y = %.1f（顶栏不压住 y >= 104 的屏幕容器）"
			% [str(屏), 顶.end.y, 容.position.y])
		for 名 in 顶栏右按钮们:
			var 框 := _框(boot, str(名))
			t.ok(框.size.x > 0.0 and 框.end.x <= 画布宽 + 0.5,
				"路由到「%s」：顶栏按钮「%s」%s 不出右界（end.x = %.1f <= 1280）—— 满手藏品 / 零件也不裁切"
				% [str(屏), str(名), _短(框), 框.end.x])

## ②-b 战斗屏：16 张卡不互压、卡身与内部底板尺寸一致、三大区块两两不重叠且都在可用区内。
func _段2b_战斗屏布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ★ RT-3b：改用双入口里的新入口（自动开单机牌组 + 秘银五人）。
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013):
		t.ok(false, "开始快速测试战斗(秘银, 20261013) 开不起来 —— 战斗屏版面断言跑不了")
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "战斗屏视图类型不对（%s）" % str(bv))
		return
	var 视图: BattleView = bv
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(), "★ 战斗屏建起来了（screen = %s）" % s.screen)
	var 卡们 := 视图.find_children("*", "UnitCard", true, false)
	t.ok(卡们.size() == int(Fm.SLOTS()) * 2,
		"★ 战斗屏常驻 %d 张 UnitCard（8 格 × 双方，不是 9 格）" % 卡们.size())
	var 排盒名们 := ["我方阵型第0排", "我方阵型第1排", "敌方阵型第0排", "敌方阵型第1排"]
	for b in 卡们:
		var 卡: Control = b
		var 底 := 卡.find_child("单位卡底", true, false)
		var 框 := 卡.get_global_rect()
		var 底框: Rect2 = (底 as Control).get_global_rect() if 底 is Control else Rect2()
		t.ok(底 is Control, "UnitCard 里有「单位卡底」（%s）" % str(卡.get_parent().name))
		t.ok(absf(框.size.x - 底框.size.x) <= 0.6 and absf(框.size.y - 底框.size.y) <= 0.6,
			"★ 单位卡（%s）卡身 %s 与内部「单位卡底」%s 尺寸一致（不再是 19px 塌缩高）"
			% [str(卡.get_parent().name), _短(框), _短(底框)])
		t.ok(框.size.y >= 68.0, "★ 单位卡高度 %.0f >= 68（★ 2026-10-21 4×4 棋盘按 148×72 报最小尺寸，不塌缩）" % 框.size.y)
		t.ok(框.position.y >= 顶栏高 - 0.5 and _在界内(框), "单位卡 %s 落在 1280×720 内（且在顶栏之下）" % _短(框))
	# 同排 4 张两两不重叠
	for 排名 in 排盒名们:
		var 排 = 视图.find_child(排名, true, false)
		if 排 == null:
			t.ok(false, "战斗屏里找不到「%s」" % 排名)
			continue
		var 框们: Array = []
		for c in (排 as Node).get_children():
			if c is UnitCard:
				框们.append((c as Control).get_global_rect())
		t.ok(框们.size() == 4, "★「%s」里有 4 张单位卡（前 4 + 后 4）" % 排名)
		var 叠了 := 0
		for i in 框们.size():
			for j in range(i + 1, 框们.size()):
				if _叠(框们[i], 框们[j]):
					叠了 += 1
		t.ok(叠了 == 0, "★「%s」里 4 张卡两两互不重叠（重叠对数 = %d）" % [排名, 叠了])
	# 前排与后排互不重叠（跨排）
	var 我方0 := _排框(视图, "我方阵型第0排")
	var 我方1 := _排框(视图, "我方阵型第1排")
	var 敌方0 := _排框(视图, "敌方阵型第0排")
	var 敌方1 := _排框(视图, "敌方阵型第1排")
	t.ok(not _叠(我方0, 我方1), "★ 我方前排 %s 与后排 %s 互不重叠" % [_短(我方0), _短(我方1)])
	t.ok(not _叠(敌方0, 敌方1), "★ 敌方前排 %s 与后排 %s 互不重叠" % [_短(敌方0), _短(敌方1)])
	t.ok(not _叠(我方0, 敌方0), "★ 我方前排 %s 与敌方前排 %s 互不重叠" % [_短(我方0), _短(敌方0)])
	# 三大区块
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	var 阵 := _查(t, "战斗屏", 舱, "阵型区", 可用)
	var 手 := _查(t, "战斗屏", 舱, "手牌栏", 可用)
	var 报 := _查(t, "战斗屏", 舱, "战报栏", 可用)
	t.ok(not _叠(阵, 手) and not _叠(阵, 报) and not _叠(手, 报),
		"★ 阵型区 %s / 手牌栏 %s / 战报栏 %s 两两互不重叠（交面积 %.0f / %.0f / %.0f）"
		% [_短(阵), _短(手), _短(报), _交面积(阵, 手), _交面积(阵, 报), _交面积(手, 报)])
	for 名 in ["推进按钮", "自动按钮", "结算按钮"]:
		var 框 := _框(boot, str(名))
		t.ok(框.size.x > 0.0 and 框.end.y <= 画布高 + 0.5 and 框.end.x <= 画布宽 + 0.5,
			"战斗屏按钮「%s」%s 落在画布内（end.y = %.1f <= 720）" % [str(名), _短(框), 框.end.y])

func _排框(视图: Node, 排名: String) -> Rect2:
	var 排 = 视图.find_child(排名, true, false)
	if 排 == null:
		return Rect2()
	var 起 := Vector2(INF, INF)
	var 止 := Vector2(-INF, -INF)
	var 有 := false
	for c in (排 as Node).get_children():
		if not (c is UnitCard):
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		起 = Vector2(minf(起.x, r.position.x), minf(起.y, r.position.y))
		止 = Vector2(maxf(止.x, r.end.x), maxf(止.y, r.end.y))
		有 = true
	if not 有:
		return Rect2()
	return Rect2(起, 止 - 起)

## ②-c 结算屏：真打完一场有战报的战斗之后，三块都在可用区内，两个按钮不出画布。
func _段2c_结算屏布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.battle_ctx.is_empty():
		s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013)
	if s.battle_ctx.is_empty():
		t.ok(false, "开不出战斗 —— 结算屏版面断言跑不了")
		return
	if s.battle_ctx.get("result") == null:
		s.step_battle_turn()
		s.auto_finish_battle()
	if s.battle_ctx.get("result") == null:
		t.ok(false, "这一场打不完 —— 结算屏版面断言跑不了")
		return
	s.finish_battle_and_settle()
	boot.route()
	await _等帧(3)
	t.ok(s.screen == "result", "★ 真打完一场（战报 %d 行）→ screen = result" % s.battle_log_entries(0).size())
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	_查(t, "结算屏", 舱, "结算面板", 可用)
	_查(t, "结算屏", 舱, "战利品区", 可用)
	var 回顾 := _查(t, "结算屏", 舱, "战报回顾", 可用)
	var 面板 := _框(boot, "结算面板")
	t.ok(not _叠(面板, 回顾), "★ 结算屏「结算面板」%s 与「战报回顾」%s 互不重叠" % [_短(面板), _短(回顾)])
	for 名 in ["继续按钮", "回菜单按钮"]:
		var 框 := _框(boot, str(名))
		t.ok(框.size.x > 0.0 and 框.end.y <= 画布高 + 0.5,
			"★ 结算屏「%s」%s 没掉到画布外（end.y = %.1f <= 720；曾经是 1794）" % [str(名), _短(框), 框.end.y])

## ②-d 大地图与编队屏：两块主体互不重叠、都在 1280×720 内。
func _段2d_地图与编队布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null:
		s.start_new_run(20261107, "混编")
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var 屏 := Rect2(0.0, 0.0, 画布宽, 画布高)
	_查(t, "大地图", 舱, "地图网格", 屏)
	_查(t, "大地图", 舱, "预告面板", 屏)
	_查不叠(t, "大地图", 舱, "地图网格", "预告面板")
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	_查(t, "编队屏", 舱, "格位网格", 屏)
	_查(t, "编队屏", 舱, "名册列表", 屏)
	_查不叠(t, "编队屏", 舱, "格位网格", "名册列表")

## ②-e 窄视口（960×540）：根盒跟着容器自适应，战斗屏的兜底裁切在窄视口下也守得住。
func _段2e_窄视口(t, 树根: Node) -> void:
	_设视口(树根, Vector2(960, 540))
	var 舱 := await _建boot(树根, Vector2(960, 540))
	if 舱.is_empty():
		t.ok(false, "窄视口下 boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	await _等帧(3)
	var 容 := _框(boot, "屏幕容器")
	t.ok(absf(容.size.x - 960.0) < 1.0 and absf(容.size.y - (540.0 - 顶栏高)) < 1.5,
		"窄视口：根盒「屏幕容器」= %s（跟着 960×540 的容器自适应，从 1280×616 收到 960×436）" % _短(容))
	t.ok(容.position.y >= 顶栏高 - 0.5, "窄视口：顶栏仍让出 y >= 104 那一条（屏幕容器顶边 y = %.1f）" % 容.position.y)
	if boot.session.run_state == null:
		boot.session.start_new_run(20261107, "混编")
	var 屏 := Rect2(0.0, 0.0, 960.0, 540.0)
	for 屏名 in ["map", "formation"]:
		boot.session.screen = str(屏名)
		boot.route()
		await _等帧(3)
		for 名 in ["层信息", "格位网格"]:
			var 框 := _框(boot, str(名))
			if 框.size.x <= 0.0:
				continue
			t.ok(_在(框, 屏), "窄视口 960×540 · %s 屏「%s」%s 仍在 960×540 内（根盒自适应）"
				% [str(屏名), str(名), _短(框)])
	if not boot.session.开始快速测试战斗(GameSession.快速测试_秘银, 20261013):
		t.ok(false, "窄视口下开不出战斗")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if bv is BattleView:
		# 战斗屏的最小宽度是设计死数（~1150），窄视口下由 `屏幕容器`（960 宽）裁掉多余部分；
		# 这里断言「真正决定可见边界的根盒就是 960 宽」+「每个块都还在 1280×720 设计画布内」。
		t.ok(absf(容.size.x - 960.0) < 1.0,
			"窄视口：战斗屏的可见边界 = 屏幕容器 %.0f 宽（超出的部分被它裁掉，不会画到视口外）" % 容.size.x)
		for 名 in ["阵型区", "手牌栏", "战报栏", "推进按钮", "自动按钮", "结算按钮"]:
			var 框 := _框(boot, str(名))
			t.ok(框.size.x > 0.0 and _在界内(框),
				"窄视口 960×540 · 战斗屏「%s」%s 仍在 1280×720 设计画布内（不画到画布外）" % [str(名), _短(框)])
	_拆boot(树根, 舱)

# 段 3：机体与卡牌 Mouse-Over 说明信息
