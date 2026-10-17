## Stage M4-2 表现层 UI 冒烟（契约 §7）。
##
## 覆盖段 1 / 2 / 3 / 4 / 5 / 6。
## ★ Stage M4-3 **追加**（不改 M4-2 的任何一条断言）：
##   段 3b / 3c —— `BattleView` / `ResultView` 能 `new()` → `setup(session)` → `refresh()`；
##   段 4b / 4c —— 战斗屏「阵型区 / 手牌栏 / 候补区 / 战报栏」与结算屏「结算面板 / 战利品区 / 战报回顾」；
##   段 7       —— 真开一局战斗：手牌栏有牌、候补区有内容（D-01）、打一张牌、推进一步、
##                 自动打完、`finish_battle_and_settle()`、结算面板里有胜负文字。
##
## 纪律：`extends RefCounted` + `func run(t)`（`t.ok(cond, "中文说明")`），放在
## `godot/tests/unit/` 顶层即自动被发现；**不动 `run_tests.gd`、不用 `t._suite`**。
## headless 下 `run_tests.gd` 是 `SceneTree`，所以这里把 `Control` 真的挂进
## `(Engine.get_main_loop() as SceneTree).root`（`_ready` 与 `find_child` 才正常），用完必 `free()`。
extends RefCounted

const BOOT_GD := "res://presentation/boot/boot.gd"
const BOOT_TSCN := "res://presentation/boot/boot.tscn"
## 6 个屏名（契约 §4 的路由表）。
const 屏们 := ["menu", "squad", "map", "formation", "battle", "result"]

func run(t) -> void:
	_段1_冒烟契约(t)
	var session := _段2_会话(t)
	if session == null:
		return
	var 树根 := _根()
	_段3_视图能建能刷(t, session, 树根)
	_段4_关键节点(t, session, 树根)
	_段5_路由(t, 树根)
	# ★ Stage M4-3 追加（契约 §7 的段 3 / 4 里「战斗屏与结算屏」那一半）。
	#   **M4-2 已有的断言一条都没动、一条都没删**，这里只是在后面接着补。
	_段3b_战斗屏能建能刷(t, session, 树根)
	_段3c_结算屏能建能刷(t, session, 树根)
	_段4b_战斗屏关键节点(t, session, 树根)
	_段4c_结算屏关键节点(t, session, 树根)
	_段7_真打一场(t, 树根)
	_段7b_肉鸽战后回血(t, 树根)
	# ★ M4-2 追加（ARGON 2026-10-16 复核：大地图「点格子」必须是**原子动作** —— 走上去就结算）。
	#   **M4-3 与 M4-2 已有的断言一条都没动、一条都没删**，这里只是在后面接着补。
	_段8_走上去就结算(t, 树根)
	# ★ M4-2 追加（ARGON D-08：门面接了「推进剂见底 → 追击战」，视图不许把刚开的这一场顶掉）。
	_段9_追击战(t, 树根)
	_段6_静默(t, session)

# ==========================================================================================
# 段 1：boot.gd 的两条既有契约
# ==========================================================================================

func _段1_冒烟契约(t) -> void:
	var 脚本: Variant = load(BOOT_GD)
	var 值: Variant = 脚本.smoke_checksum() if 脚本 != null else -1
	t.ok(脚本 != null and int(值) == 182751003,
		"boot.gd 的 smoke_checksum() 仍是 182751003（tests/unit/test_rng.gd:25 直接依赖它）")
	var 源码 := FileAccess.get_file_as_string(BOOT_GD)
	t.ok(not 源码.is_empty(), "读得到 boot.gd 的源码文本（%d 字符）" % 源码.length())
	t.ok(源码.contains("MECHA_SMOKE"), "boot.gd 源码里还有 MECHA_SMOKE 那一行（Web 冒烟与 Pages 门禁依赖）")
	t.ok(源码.contains("JSON.stringify"), "MECHA_SMOKE 那一行仍走 JSON.stringify（web_smoke.mjs 要 JSON.parse）")
	for 键 in ["\"checksum\"", "\"version\"", "\"data\"", "ALLY_T", "编成表", "战术卡牌表"]:
		t.ok(源码.contains(键), "MECHA_SMOKE 那行里的键 / 计数 %s 还在" % 键)
	# 结构守卫：那一行必须在 _ready() 里（不在某个只在主菜单才建的节点里）
	var i_ready := 源码.find("func _ready() -> void:")
	# 注意：文档注释里也提到了 MECHA_SMOKE，所以从 `_ready()` 之后开始找
	var i_print := 源码.find("MECHA_SMOKE", maxi(0, i_ready))
	t.ok(i_ready >= 0 and i_print > i_ready, "MECHA_SMOKE 那一行在 _ready() 里（位置 %d > %d）" % [i_print, i_ready])
	t.ok(FileAccess.file_exists(BOOT_TSCN), "主场景 boot.tscn 的路径没被改（project.godot 的 main_scene 指向它）")
	var 场景: Variant = load(BOOT_TSCN)
	t.ok(场景 != null and 场景.can_instantiate(), "boot.tscn 能加载并实例化")

# ==========================================================================================
# 段 2：数据 + 会话 + 开局
# ==========================================================================================

func _段2_会话(t) -> GameSession:
	var errors := []
	var 装好 := DataLoader.install(errors)
	t.ok(装好 and errors.is_empty(), "DataLoader.install(errors) 成功%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var session := GameSession.new()
	t.ok(session != null, "GameSession.new() 能建出来（表现层自己 new，无 autoload）")
	t.ok(session.screen == "menu" and session.run_state == null, "新会话从 menu 屏开始、没有进行中的局")
	var 开了 := session.start_new_run(20261016, "混编")
	t.ok(开了 and session.run_state != null, "start_new_run(20261016, \"混编\") 能开局")
	if session.run_state == null:
		return session
	t.ok(not session.run_state.map_data.is_empty(), "开局后大地图已经生成（第 %d 层）" % session.run_state.floor_num)
	t.ok(session.run_state.tickets.size() > 0, "开局发了 %d 张招募券" % session.run_state.tickets.size())
	var 顶 := session.topbar_state()
	t.ok(bool(顶.get("有局", false)) and int(顶.get("层", 0)) == 1, "topbar_state() 有局：第 %s 层" % UiTheme.文本(顶.get("层", 0)))
	return session

# ==========================================================================================
# 段 3：每个视图都能 new() → (add_child) → setup(session) → refresh()
# ==========================================================================================

func _段3_视图能建能刷(t, session: GameSession, 树根: Node) -> void:
	# 视图 → 它自己该有的那个节点名（用来证明树真的建出来了）
	var 视图们: Array = [
		["MenuView", MenuView.new(), "主菜单"],
		["RosterView", RosterView.new(), "招募面板"],
		["PickCardView", PickCardView.new(), "选牌面板"],
		["ShopView", ShopView.new(), "黑市面板"],
		["RestView", RestView.new(), "休整面板"],
		["EventView", EventView.new(), "奇遇面板"],
		["MapView", MapView.new(), "大地图"],
		["FormationView", FormationView.new(), "编队"],
		["TopBar", TopBar.new(), "顶栏"],
		["ModalLayer", ModalLayer.new(), "弹窗层"],
		["UnitCard", UnitCard.new(), "单位卡"],
		["BattleView", BattleView.new(), "战斗屏"],
		["ResultView", ResultView.new(), "结算屏"],
	]
	for 条 in 视图们:
		var 名 := str(条[0])
		# 无类型标注 = Variant：各视图是不同类，只能动态调它们的 setup / refresh
		var v = 条[1]
		树根.add_child(v)
		if v is UnitCard:
			# UnitCard 是**组件**，接口是 setup(data: Dictionary)（契约留给 M4-3 的那一个）
			(v as UnitCard).setup(session.unit_view("ally", ""))
			(v as UnitCard).refresh()
		else:
			v.setup(session)
			v.refresh()
			v.refresh()
		t.ok(v.get_child_count() > 0, "%s：setup(session) + refresh() 不报错，节点树建出 %d 个子节点" % [名, v.get_child_count()])
		t.ok(str(v.name) == str(条[2]), "%s 的节点名是「%s」（find_child 靠它）" % [名, str(条[2])])
		树根.remove_child(v)
		v.free()
	# 第二遍：视图复用（同一个实例再 refresh 一次不该炸，也不该多长节点）
	var m := MapView.new()
	树根.add_child(m)
	m.setup(session)
	var n1 := m.get_child_count()
	m.refresh()
	m.refresh()
	t.ok(m.get_child_count() == n1, "MapView.refresh() 幂等：子节点数 %d 没变（不是每帧 new）" % n1)
	树根.remove_child(m)
	m.free()

# ==========================================================================================
# 段 4：关键节点真的存在
# ==========================================================================================

func _段4_关键节点(t, session: GameSession, 树根: Node) -> void:
	var 场景: Variant = load(BOOT_TSCN)
	# 无类型标注 = Variant：boot 的脚本是自己挂上去的，`Control` 基类上没有 session/route
	var boot = 场景.instantiate() if 场景 != null else null
	t.ok(boot != null, "boot.tscn 能实例化出 Control")
	if boot == null:
		return
	树根.add_child(boot)
	# ★ headless 下 `add_child` 不会触发 boot 的 `_ready()`（root 还没 ready，测试全在
	#   `SceneTree._initialize()` 里跑完就 quit），所以这里显式调公开入口 `启动()`。
	boot.启动()
	t.ok(boot.session != null and boot.session != session, "boot 自己 new 了一个会话（不是段 2 那个实例）")
	for 名 in ["顶栏", "屏幕容器", "弹窗层"]:
		t.ok(boot.find_child(名, true, false) != null, "boot 里有节点「%s」" % 名)
	# 逐屏路由后，容器里真的挂着那一屏的关键节点
	var 要查 := {
		"menu": ["主菜单", "菜单按钮组", "继续游戏按钮", "开始新肉鸽按钮", "快速测试战斗按钮", "存档提示"],
		"map": ["大地图", "地图网格", "预告面板", "节点说明", "进入当前格按钮", "换层按钮"],
		"formation": ["编队", "格位网格", "名册列表"],
		"battle": ["手牌栏", "候补区"],
		"result": ["结算面板"],
	}
	for 屏 in 要查.keys():
		boot.session.screen = str(屏)
		boot.route()
		for 名 in 要查[屏]:
			t.ok(boot.find_child(str(名), true, false) != null, "路由到 %s 之后找得到「%s」" % [str(屏), str(名)])
	树根.remove_child(boot)
	boot.free()

# ==========================================================================================
# 段 5：6 个屏 + 弹窗 → 路由不崩
# ==========================================================================================

func _段5_路由(t, 树根: Node) -> void:
	var 场景: Variant = load(BOOT_TSCN)
	var boot = 场景.instantiate() if 场景 != null else null
	if boot == null:
		t.ok(false, "boot.tscn 实例化失败，段 5 跑不了")
		return
	树根.add_child(boot)
	boot.启动()
	t.ok(boot.session != null, "boot 自己 new 了 GameSession（没有 autoload；headless 下由测试显式调 启动()）")
	# 先开一局，路由才有东西可画
	var 开局: bool = boot.session.start_new_run(20261017, "混编")
	t.ok(开局, "boot 的会话能开局（段 5 用）")
	for 屏 in 屏们:
		boot.session.screen = str(屏)
		boot.route()
		var 容器 = boot.find_child("屏幕容器", true, false)
		var 数: int = 容器.get_child_count() if 容器 != null else -1
		t.ok(容器 != null and 数 >= 1, "路由到 %s：屏幕容器子节点数 = %d（合理）" % [str(屏), 数])
		t.ok(str(boot.session.screen) == str(屏), "路由到 %s 之后 session.screen 就是它" % str(屏))
	# 逐个弹窗类型（走顶层那一个 ModalLayer）
	var 弹窗们 := ["招募", "晋升", "三选一", "黑市", "休整", "奇遇", "战术牌库", "战斗", "结算"]
	for 类型 in 弹窗们:
		boot.打开弹窗(str(类型), {})
		var 层 = boot.find_child("弹窗层", true, false)
		t.ok(层 != null, "弹窗「%s」：弹窗层还在" % str(类型))
		t.ok(层 != null and 层.find_child("弹窗面板", true, false) != null,
			"弹窗「%s」：面板节点「弹窗面板」在" % str(类型))
	boot.关闭弹窗()
	t.ok(boot.session.modal.is_empty(), "关闭弹窗之后 session.modal 是空的")
	# 再乱设一次：认不出来的屏 / 认不出来的弹窗都不许崩
	boot.session.screen = "不存在的屏"
	boot.route()
	t.ok(true, "认不出来的屏名（不存在的屏）→ 路由不崩")
	boot.打开弹窗("不存在的弹窗", {})
	t.ok(true, "认不出来的弹窗类型 → 弹窗层不崩")
	boot.关闭弹窗()
	树根.remove_child(boot)
	boot.free()

# ==========================================================================================
# 段 3b / 3c：战斗屏与结算屏能 new() → setup(session) → refresh()（Stage M4-3 追加）
# ==========================================================================================

func _段3b_战斗屏能建能刷(t, session: GameSession, 树根: Node) -> void:
	var v := BattleView.new()
	树根.add_child(v)
	v.setup(session)
	v.refresh()
	v.refresh()
	t.ok(v.get_child_count() > 0, "BattleView：setup(session) + refresh() 不报错，节点树建出 %d 个子节点" % v.get_child_count())
	t.ok(str(v.name) == "战斗屏", "BattleView 的节点名是「战斗屏」（find_child 靠它）")
	var n1 := v.get_child_count()
	v.refresh()
	t.ok(v.get_child_count() == n1, "BattleView.refresh() 幂等：顶层子节点数 %d 没变（不是每帧 new）" % n1)
	# 没有战斗上下文时也不许崩，而且结构照样在（段 4b 再逐个查名字）
	t.ok(_数单位卡(v) == int(Fm.SLOTS()) * 2,
		"BattleView 里常驻 %d 张 UnitCard（★ 8 格 × 双方，不是 9 格）" % _数单位卡(v))
	树根.remove_child(v)
	v.free()

func _段3c_结算屏能建能刷(t, session: GameSession, 树根: Node) -> void:
	var v := ResultView.new()
	树根.add_child(v)
	v.setup(session)
	v.refresh()
	v.refresh()
	t.ok(v.get_child_count() > 0, "ResultView：setup(session) + refresh() 不报错，节点树建出 %d 个子节点" % v.get_child_count())
	t.ok(str(v.name) == "结算屏", "ResultView 的节点名是「结算屏」（find_child 靠它）")
	# 没有战果时也要稳（有结果 / 没结果两条路都不能崩）
	t.ok(v.find_child("结算标题", true, false) != null, "没有战果时「结算标题」照样在（画一行提示）")
	var n1 := v.get_child_count()
	v.refresh()
	t.ok(v.get_child_count() == n1, "ResultView.refresh() 幂等：顶层子节点数 %d 没变" % n1)
	树根.remove_child(v)
	v.free()

# ==========================================================================================
# 段 4b / 4c：战斗屏与结算屏的关键节点名（Stage M4-3 追加）
# ==========================================================================================

func _段4b_战斗屏关键节点(t, session: GameSession, 树根: Node) -> void:
	var v := BattleView.new()
	树根.add_child(v)
	v.setup(session)
	v.refresh()
	for 名 in ["阵型区", "手牌栏", "候补区", "战报栏"]:
		t.ok(v.find_child(str(名), true, false) != null, "BattleView 里有节点「%s」（契约 §3 第 4 条）" % str(名))
	for 名 in ["阵型提示", "我方阵型", "敌方阵型", "手牌标题", "手牌气势", "候补文",
			"手牌列表", "操作结果", "战斗按钮组", "推进按钮", "自动按钮", "结算按钮",
			"战报提示", "战报滚动"]:
		t.ok(v.find_child(str(名), true, false) != null, "BattleView 里有节点「%s」" % str(名))
	树根.remove_child(v)
	v.free()

func _段4c_结算屏关键节点(t, session: GameSession, 树根: Node) -> void:
	var v := ResultView.new()
	树根.add_child(v)
	v.setup(session)
	v.refresh()
	for 名 in ["结算面板", "战利品区", "战报回顾"]:
		t.ok(v.find_child(str(名), true, false) != null, "ResultView 里有节点「%s」（契约 §3 第 4 条）" % str(名))
	for 名 in ["结算标题", "结算明细", "回血对照", "战利品文字", "战术牌回顾", "日志回顾", "继续按钮"]:
		t.ok(v.find_child(str(名), true, false) != null, "ResultView 里有节点「%s」" % str(名))
	树根.remove_child(v)
	v.free()

# ==========================================================================================
# 段 7：真开一局战斗再验（手牌 / 候补 / 打牌 / 推进 / 自动打完 / 结算）
# ==========================================================================================

func _段7_真打一场(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke.json"
	t.ok(s.start_quick_battle(20261013), "★ start_quick_battle(20261013) 开起来了（手牌 %d 张 / 候补 %d 张）"
		% [s.hand_count(), s.reserve_preview().size()])
	t.ok(s.screen == "battle", "开战之后 screen = battle（真实值 %s）" % s.screen)
	if s.battle_ctx.is_empty():
		t.ok(false, "battle_ctx 是空的 → 段 7 剩下的断言跑不了")
		return
	var bv := BattleView.new()
	树根.add_child(bv)
	bv.setup(s)
	bv.refresh()
	# ---- 手牌栏里真的有牌，而且每张牌都挂着「置灰原因」----
	t.ok(bv.find_child("手牌栏", true, false) != null, "战斗屏建起来后有「手牌栏」")
	var 卡数 := bv.find_children("手牌卡*", "", true, false).size()
	t.ok(卡数 == s.hand_count() and 卡数 > 0,
		"★ 手牌栏里有牌：画出 %d 张（门面 hand_count() = %d）" % [卡数, s.hand_count()])
	var 原因数 := bv.find_children("手牌原因", "", true, false).size()
	t.ok(原因数 == 卡数 and 原因数 > 0, "★ 每张手牌都带一行「手牌原因」（hand_card_status 的原因原文写在卡上）：%d 行" % 原因数)
	var 层级数 := bv.find_children("手牌层级", "", true, false).size()
	t.ok(层级数 == 卡数, "每张手牌都带一行「手牌层级」（层级 / 耗气 / 回气 / 冷却 / 剩余）：%d 行" % 层级数)
	# ---- D-01：候补区里有内容 ----
	var 候补 = bv.find_child("候补区", true, false)
	var 候补文 = bv.find_child("候补文", true, false)
	var 候补字 := str(候补文.text) if 候补文 != null else ""
	t.ok(候补 != null and 候补.get_child_count() > 0 and 候补字.length() > 0,
		"★ D-01 候补区里有内容：%s" % 候补字.substr(0, 48))
	var 候数 := s.reserve_preview().size()
	t.ok(候补字.contains("候补初始牌：%d 张" % 候数),
		"★ D-01 候补区写出了张数「候补初始牌：%d 张」（门面 reserve_preview() 同一个数）" % 候数)
	if 候数 > 0:
		var 首名 := str((s.reserve_preview()[0] as Dictionary).get("名", ""))
		t.ok(候补字.contains(首名), "★ D-01 候补区列出了牌名（第一张【%s】看得见）" % 首名)
	# ---- 阵型：8 格 × 双方 ----
	t.ok(_数单位卡(bv) == int(Fm.SLOTS()) * 2,
		"阵型区里正好 %d 张单位卡（★ 8 格 × 双方）" % _数单位卡(bv))
	# ---- 敌方意图预告 / Boss 阶段预告 ----
	var 意图行们 := bv.find_children("意图行", "", true, false)
	var 有意图 := 0
	for l in 意图行们:
		if l is Label and str((l as Label).text).length() > 0:
			有意图 += 1
	t.ok(意图行们.size() == int(Fm.SLOTS()) * 2, "每张单位卡都有「意图行」（%d 张 = 8 格 × 双方）" % 意图行们.size())
	t.ok(有意图 >= 1, "★ 至少有 1 台敌机写出了下一拍行动意图预告（%d 张有字）" % 有意图)
	var 战报栏0 = bv.find_child("战报栏", true, false)
	t.ok(战报栏0 != null, "战斗屏里有「战报栏」")
	# ---- ★ 纯读纪律：意图预告 / Boss 阶段预告一次随机数都不许抽，也不许改 ctx ----
	var rng: Variant = s.battle_ctx.get("rng")
	var 步前 := int(rng.steps) if rng != null else -1
	var 快前 := _快照(s)
	bv.refresh()
	var 步后 := int(rng.steps) if rng != null else -1
	var 快后 := _快照(s)
	t.ok(步前 >= 0 and 步后 == 步前,
		"★ 战斗屏 refresh()（含敌方下一拍意图预告）一次随机数都没抽（rng.steps %d → %d）" % [步前, 步后])
	t.ok(快前.length() > 200 and 快前 == 快后,
		"★ 战斗屏 refresh() 是纯读：双方单位 / 气势 / 手牌 / 候补的快照逐字没变（%d 字符）" % 快前.length())
	# ---- 打一张牌 ----
	var 能打 := s.playable_hand_ids()
	t.ok(not 能打.is_empty(), "开局气势 %s 之下能打 %d 张（门面 playable_hand_ids）"
		% [str(s.battle_ctx.get("气势", 0.0)), 能打.size()])
	if not 能打.is_empty():
		var 打 := s.play_tactical_card(str(能打[0]))
		t.ok(bool(打.get("成功", false)), "点一张手牌 → play_tactical_card 成功（%s）" % str(s.last.get("牌名", "")))
		bv.refresh()
		t.ok(bv.find_children("手牌卡*", "", true, false).size() == s.hand_count(),
			"打完一张之后手牌栏重画成 %d 张（门面 hand_count() = %d）"
			% [bv.find_children("手牌卡*", "", true, false).size(), s.hand_count()])
	# ---- 推进一回合 ----
	var 前回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	s.step_battle_turn()
	var 后回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	t.ok(后回合 > 前回合, "推进下一回合：第 %d 回合 → 第 %d 回合" % [前回合, 后回合])
	bv.refresh()
	var 战报行数 := bv.find_children("战报行*", "", true, false).size()
	t.ok(战报行数 > 0, "战报栏里画出了结构化日志 %d 行" % 战报行数)
	t.ok(bv.find_child("战报提示", true, false) != null
		and str((bv.find_child("战报提示", true, false) as Label).text).contains("本回合已打出"),
		"战报提示里写清了「本回合已打出」（是事实，不是上限）")
	# ---- 自动打完 + 结算 ----
	s.auto_finish_battle()
	t.ok(s.battle_ctx.get("result") != null, "自动打完本场：结果 = %s" % s.战果文字())
	bv.refresh()
	s.finish_battle_and_settle()
	t.ok(s.screen == "result", "finish_battle_and_settle() 之后 screen = result（真实值 %s）" % s.screen)
	# ---- 结算屏 ----
	var rv := ResultView.new()
	树根.add_child(rv)
	rv.setup(s)
	rv.refresh()
	for 名 in ["结算面板", "战利品区", "战报回顾"]:
		t.ok(rv.find_child(str(名), true, false) != null, "打完一场之后结算屏里有「%s」" % str(名))
	var 标题 = rv.find_child("结算标题", true, false)
	var 标题字 := str(标题.text) if 标题 != null else ""
	t.ok(标题 != null and (标题字.contains("胜") or 标题字.contains("败")),
		"★ 结算面板里有胜负文字：「%s」" % 标题字)
	var 战利品 = rv.find_child("战利品文字", true, false)
	t.ok(战利品 != null and str(战利品.text).length() > 0,
		"战利品区里有内容：「%s」" % (str(战利品.text).substr(0, 40) if 战利品 != null else ""))
	var 回顾 = rv.find_child("战术牌回顾", true, false)
	t.ok(回顾 != null and str(回顾.text).contains("战术牌"), "战报回顾里有「本场打出的战术牌」那一段")
	var 回血 = rv.find_child("回血对照", true, false)
	t.ok(回血 != null and str(回血.text).contains("%"),
		"回血前后按百分比显示（D-04：不依赖 int/float 区分）：「%s」"
		% (str(回血.text).substr(0, 48) if 回血 != null else ""))
	树根.remove_child(rv)
	rv.free()
	树根.remove_child(bv)
	bv.free()

# ==========================================================================================
# 段 7b：真肉鸽路径 —— 战后 +50% 回血的前后对照（回血数字全部来自门面 / 内核）
# ==========================================================================================

func _段7b_肉鸽战后回血(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke2.json"
	t.ok(s.start_new_run(20261013 + 7, "混编"), "★ 第二个会话开一局肉鸽（第 %d 层大地图）" % s.run_state.floor_num)
	if s.run_state == null:
		return
	# 用开局那几张券招几台（只为了拿到「名册 + 出击」；招谁不影响这里要验的东西）
	var 招 := 0
	var 最后一拒 := ""
	for _i in 3:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		var 招结果 := s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0)
		if bool(招结果.get("ok", false)):
			招 += 1
		else:
			最后一拒 = str(招结果.get("为什么", ""))
			break
	t.ok(招 >= 2 and s.run_state.roster.size() >= 2,
		"用开局券招到 %d 台（名册 %d 台%s）" % [招, s.run_state.roster.size(),
			"" if 最后一拒.is_empty() else "；最后一次被拒：" + 最后一拒])
	if s.run_state.roster.size() < 2:
		return
	var 键们 := s.run_state.roster.keys()
	# ★ 造数据（不是表现层算的）：把名册血比压到 20%。
	#   只把第一台摆上出击位 → 另外几台这一场不上阵，`记战斗HP` 不会覆盖它们，
	#   战后回血 +50% 之后它们一定从 20% 变成 70% —— 前后差异是**内核**给的。
	for k in 键们:
		var m: Dictionary = s.run_state.roster[k]
		m["hpRatio"] = 0.2
		s.run_state.roster[k] = m
	var 首位名 := str(s.lineup_slots()[0].get("位名", ""))
	t.ok(s.set_lineup_slot(str(键们[0]), 首位名), "只把 %s 摆到 %s（其余留在名册里不参战）" % [str(键们[0]), 首位名])
	var 格 := _找战斗格(s)
	if 格 < 0:
		t.ok(false, "第 %d 层找不到战斗格" % s.run_state.floor_num)
		return
	s.run_state.node_id = 格
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(格).get("类型", ""))
	t.ok(s.start_node_battle(), "从战斗格 %d（%s）开战 —— 真肉鸽路径，不是快速战斗"
		% [格, str(s.run_state.map_data["当前节点类型"])])
	if s.battle_ctx.is_empty():
		t.ok(false, "肉鸽路径开战失败，段 7b 剩下的断言跑不了")
		return
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	var r := s.result_summary()
	t.ok(s.screen == "result" and bool(r.get("有结果", false)), "肉鸽一场打完 → 结算屏（结果 %s）" % str(r.get("结果", "")))
	var 回血: Dictionary = r.get("回血") if r.get("回血") is Dictionary else {}
	t.ok(int(回血.get("台数", 0)) >= 2,
		"★ 战后回血真的发生：%d 台（回复比例 %s）" % [int(回血.get("台数", 0)), str(回血.get("回复比例", 0.0))])
	var rv := ResultView.new()
	树根.add_child(rv)
	rv.setup(s)
	rv.refresh()
	var 行 = rv.find_child("回血对照", true, false)
	var 行字 := str(行.text) if 行 != null else ""
	# ★ **不写死任何百分比**：只断言「前后对照」这个**形状** —— 含 `→`、含 `%`，
	#   而且至少有一台的「前 ≠ 后」（这才是「前后对照」真正要守的东西）。
	#   具体数值跟着内核走（门面 / `RosterManager.战后回血` 给的那段原文），界面改口径时这条不会假红。
	var 有真对照 := false
	for 段 in 行字.split("、"):
		var 两半 := str(段).split("→")
		if 两半.size() == 2 and str(两半[0]).strip_edges() != str(两半[1]).strip_edges():
			有真对照 = true
			break
	t.ok(行字.contains("→") and 行字.contains("%") and 有真对照,
		"★ 回血前后对照是「前%% → 后%%」的形状、且至少一台前 ≠ 后（不写死血量）：%s" % 行字.substr(0, 72))
	t.ok(行字.contains(str(回血.get("文本", "")).substr(0, 6)),
		"回血对照里贴了门面给的原文（%s…）" % str(回血.get("文本", "")).substr(0, 16))
	var 战利品 = rv.find_child("战利品文字", true, false)
	t.ok(战利品 != null and str(战利品.text).contains("希望 +") and str(战利品.text).contains("源碳 +"),
		"战利品区有内容：「%s」" % (str(战利品.text).substr(0, 40) if 战利品 != null else ""))
	树根.remove_child(rv)
	rv.free()

# ==========================================================================================
# 段 8（M4-2 追加）：★「点格子」是原子动作 —— 走上去就结算，不许绕开战斗直接通关
#   ARGON 2026-10-16 复核：JS `80-界面-5-肉鸽接线与节点.js:207-277` 的 `去节点(k)` = 移动 + 按类型结算，
#   所以 JS 里**无法路过一个战斗格而不打**。旧版 M4-2 把两者拆成「点格子」+「进入当前格」两个动作，
#   可以一路走到出口、0 场战斗直接「胜利」。这一段的断言就是钉住这个行为。
# ==========================================================================================

func _段8_走上去就结算(t, 树根: Node) -> void:
	_段8a_空格与已过不切屏(t, 树根)
	_段8b_战斗格走上去就开打(t, 树根)
	_段8c_出口走上去就换层(t, 树根)
	_段8d_兜底按钮不重复结算(t, 树根)

## ① 名册为空要有提示；② 走空格 / 走已过的格**不切屏**。
func _段8a_空格与已过不切屏(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke3.json"
	t.ok(s.start_new_run(20261013 + 11, "混编"), "★ 段 8a：开一局（第 %d 层）" % s.run_state.floor_num)
	if s.run_state == null:
		return
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	mv.refresh()
	# ---- 名册为空 → 大地图上必须有醒目提示（内核设计：先招募） ----
	t.ok(s.run_state.roster.is_empty(), "开局名册是空的（`RosterManager.new_run` 的设计：先招募）")
	var 提示 = mv.find_child("名册提示", true, false)
	var 提示字 := str((提示 as Label).text) if 提示 != null else ""
	t.ok(提示 != null and (提示 as Label).visible and 提示字.contains("名册是空的") and 提示字.contains("招募"),
		"★ 名册为空时大地图上给提示：「%s」" % 提示字)
	# ★ 2026-10-18：有未决招募券时点格子不移动（先把券决定完）—— 这一段要验「走空格 / 走已过的格」，
	#   所以先把开局那几张券决定掉（走的是门面公开口子 `discard_ticket()`）。
	_清券(s)
	var 起点 := s.run_state.node_id
	# ---- 走一个「没走过的林间空地」：只刷屏，不切屏 ----
	var 空格 := _找可达的格(s, ["空"], false)
	if 空格 < 0:
		t.ok(false, "第 %d 层找不到可达的未走过空格 —— 段 8a 剩下的断言跑不了" % s.run_state.floor_num)
		树根.remove_child(mv)
		mv.free()
		return
	mv._点格(空格)
	t.ok(s.run_state.node_id == 空格, "点了空格 %d → 真的走过去了（门面 node_id = %d）" % [空格, s.run_state.node_id])
	t.ok(s.screen == "map", "★ 走「林间空地」不切屏（screen 仍是 %s）" % s.screen)
	t.ok(str(s.last.get("提示", "")).contains("林间空地"),
		"★ 走的是「空格落脚」那条路（内核提示原文：%s）" % str(s.last.get("提示", "")))
	# ---- 走回「已过的格」：也只刷屏 ----
	mv._点格(起点)
	t.ok(s.run_state.node_id == 起点, "点回起点 %d → 走回去了" % 起点)
	t.ok(s.screen == "map", "★ 走「走过的格」不切屏（screen 仍是 %s）" % s.screen)
	t.ok(bool(s.run_state.cell_at(起点).get("已过", false)) and str(s.last.get("提示", "")).is_empty(),
		"★ 走的是「已过」那条路（那一格 已过 = true、没有新提示）")
	树根.remove_child(mv)
	mv.free()

## ③ ★ 核心断言：把 node_id 摆到战斗格的相邻可达格上，**通过视图那条点击路径**走上去
##    → 应当**不需要第二次点击**就进战斗屏（`screen == "battle"` 且 `battle_ctx` 非空）。
func _段8b_战斗格走上去就开打(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke4.json"
	t.ok(s.start_new_run(20261013 + 13, "混编"), "★ 段 8b：开一局（第 %d 层）" % s.run_state.floor_num)
	if s.run_state == null:
		return
	# 先招募 + 编队到「能打」（出击名单空的话 `start_node_battle` 会拒绝）
	var 招 := 0
	for _i in 3:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "用开局券招到 %d 台（名册 %d 台）" % [招, s.run_state.roster.size()])
	if s.run_state.roster.is_empty():
		return
	var 键 := str(s.run_state.roster.keys()[0])
	t.ok(s.set_lineup_slot(键, str(s.lineup_slots()[0].get("位名", ""))), "把 %s 摆上出击位" % 键)
	# 找一个战斗格 + 一个能一步走过去的落脚点
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "第 %d 层找不到战斗格 —— 段 8b 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "战斗格 %d 四周找不到「还没走过、推进剂也够」的落脚点" % 战斗格)
		return
	s.run_state.node_id = 落脚
	t.ok(s.run_state.node_id == 落脚 and MapNavigator.can_move_to(s.run_state, 战斗格).get("ok", false),
		"把 node_id 摆到战斗格 %d 的落脚点 %d 上（推进剂 %d，走得过去）"
		% [战斗格, 落脚, s.run_state.propellant])
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	mv.refresh()
	# 编队那一步把屏切到了 formation（门面 `set_lineup_slot` 自己切），这里摆回大地图再点格
	s.screen = "map"
	t.ok(s.screen == "map" and s.battle_ctx.is_empty(), "点之前：停在大地图、还没有战斗 ctx")
	# ★ 只点这一下 —— ★ 2026-10-18：视图内部先把这一格接到**战前编队确认屏**，
	#   再由【确认编队 · 开始战斗】真的开打（不再是「点一下就进战斗屏」那一步到位）。
	mv._点格(战斗格)
	t.ok(s.run_state.node_id == 战斗格, "★ 点战斗格 %d → 真的走到了（node_id = %d）" % [战斗格, s.run_state.node_id])
	t.ok(s.screen == "formation" and s.pending_battle_confirm,
		"★ 走上去先接战前编队确认屏：screen = %s、pending = %s（格类型 %s）"
		% [s.screen, str(s.pending_battle_confirm), str(s.run_state.cell_at(战斗格).get("类型", ""))])
	t.ok(s.battle_ctx.is_empty(), "★ 确认之前还没开战（battle_ctx 空）")
	# ★ 再点【确认编队 · 开始战斗】→ 这时才真的开打
	s.confirm_formation_and_start_battle()
	t.ok(s.screen == "battle",
		"★ 确认之后**不需要第三次点击**就进战斗：screen 变成 %s（格类型 %s）"
		% [s.screen, str(s.run_state.cell_at(战斗格).get("类型", ""))])
	t.ok(not s.battle_ctx.is_empty(),
		"★ battle_ctx 非空：我方 %d 台 / 敌方 %d 台"
		% [(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	t.ok(s.battle_ctx.get("result") == null, "★ 是**真开战**（这一场还没打完，result 是空）")
	树根.remove_child(mv)
	mv.free()

## ⑤ 兜底按钮「进入当前格」不许让同一格重复结算（防止站在瞭望站 / 遗迹 / 休整上刷资源）。
##   ★ 为什么需要它：JS 里点格子是**唯一**入口，根本没有第二个按钮，所以不存在这条路。
func _段8d_兜底按钮不重复结算(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke6.json"
	if not s.start_new_run(20261013 + 19, "混编"):
		t.ok(false, "★ 段 8d：开一局失败，剩下的断言跑不了")
		return
	if s.run_state == null:
		return
	# 找一个「走上去就会当场结算、而且不给弹窗」的格（瞭望站 +1 推进剂 / 遗迹给源碳或藏品 / 招募站给券）
	var 格 := _找可达的格(s, ["瞭望站", "遗迹", "招募站"], false)
	if 格 < 0:
		t.ok(false, "第 %d 层找不到可达的瞭望站 / 遗迹 / 招募站格 —— 段 8d 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 类型 := str(s.run_state.cell_at(格).get("类型", ""))
	# ★ 2026-10-18：有未决招募券时点格子不移动 —— 这一段验的是「兜底按钮不重复结算」，先把券清掉。
	_清券(s)
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	mv.refresh()
	mv._点格(格)
	t.ok(s.run_state.node_id == 格 and str(s.last.get("行动", "")) == 类型,
		"点上 %s 格 %d → 走上去就自动结算（门面记的上一动作 = %s）" % [类型, 格, str(s.last.get("行动", ""))])
	var 前推进 := s.run_state.propellant
	var 前源碳 := s.run_state.carbon
	var 前券 := s.run_state.tickets.size()
	mv._点进入()
	t.ok(s.run_state.propellant == 前推进 and s.run_state.carbon == 前源碳 and s.run_state.tickets.size() == 前券,
		"★ 兜底按钮对同一格不重复结算（推进剂 %d · 源碳 %d · 券 %d 一个都没变）" % [前推进, 前源碳, 前券])
	var 面板 = mv.find_child("预告面板内容", true, false)
	var 有提示 := false
	if 面板 != null:
		for c in (面板 as Node).get_children():
			if c is Label and str((c as Label).text).contains("已经结算过"):
				有提示 = true
	t.ok(有提示, "★ 兜底按钮被挡下时写清了原因（面板里出现「已经结算过」）")
	树根.remove_child(mv)
	mv.free()

## ④ 出口也是原子动作：走上去就自动换层（「出口 → 清了下一层」），不再等玩家点「换层」。
func _段8c_出口走上去就换层(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke5.json"
	if not s.start_new_run(20261013 + 17, "混编"):
		t.ok(false, "★ 段 8c：开一局失败，剩下的断言跑不了")
		return
	if s.run_state == null:
		return
	# 换层要求「待选战术牌」是空的（门面口径）。★ D-06 之后 `start_new_run()` / `move_to_cell()`
	# 都不再自造待选牌（待选只由招募 / 晋升产生），所以这里正常是空转 —— 留着以防别的路径塞回来。
	var 清了 := 0
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		清了 += 1
		if 清了 > 8:
			break
	var 出 := _找可达的格(s, ["出口尽头", "出口小径"], false)
	if 出 < 0:
		t.ok(false, "第 %d 层找不到「现在走得过去」的出口格 —— 段 8c 剩下的断言跑不了" % s.run_state.floor_num)
		return
	# ★ 2026-10-18：有未决招募券时点格子不移动（先把券决定完）—— 这一段要验「走出口就自动换层」，
	#   所以先把开局那几张券决定掉。
	_清券(s)
	var 前层 := s.run_state.floor_num
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	mv.refresh()
	t.ok(s.screen == "map", "点出口之前：停在大地图（screen = %s）" % s.screen)
	mv._点格(出)
	# ★ 走上去就**自动换层**（不再等玩家点「换层」按钮）。
	#   ★ D-06 之后的口径（ARGON 裁定）：`move_to_cell()` / `start_new_run()` 不再自造待选战术牌，
	#     所以这一步不会被 `try_advance_floor()` 的「还有 N 张战术牌没选」拦下 —— 正常就是当场换层。
	#   ★ 断言**不写死** node_id（换层之后它在下一层的起点）：要么停在出口格、要么已经换层。
	var 自动换层 := s.run_state.floor_num == 前层 + 1
	var 自动不给 := str(s.last.get("为什么", ""))
	t.ok(s.run_state.node_id == 出 or 自动换层,
		"点出口格 %d → 要么停在出口格、要么已经换到下一层（node_id = %d，第 %d 层）"
		% [出, s.run_state.node_id, s.run_state.floor_num])
	if 自动换层:
		t.ok(true, "★ 走上去就自动换层：第 %d 层 → 第 %d 层（上一动作 = %s，推进剂 %d）"
			% [前层, s.run_state.floor_num, str(s.last.get("行动", "")), s.run_state.propellant])
		t.ok(s.run_state.node_id == int(s.run_state.map_data.get("起点", -1)),
			"★ 换层之后落在新一层的「起点」上（node_id = %d = 地图起点 %d）"
			% [s.run_state.node_id, int(s.run_state.map_data.get("起点", -1))])
	else:
		t.ok(自动不给.length() > 0,
			"★ 走上去就自动尝试换层（不是无声无息）：门面拦下 → 「%s」" % 自动不给)
		# 被拦下时补一刀：把待选牌选掉，再走一次兜底按钮 → 这次应该真的换层
		var 补选 := 0
		while not s.run_state.pending_card_picks.is_empty() and 补选 < 8:
			if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
				break
			补选 += 1
		_清券(s)
		s.screen = "map"
		mv._点进入()
		t.ok(s.run_state.floor_num == 前层 + 1,
			"★ 把待选牌选掉之后再点一次兜底按钮 → 真的换层：第 %d 层 → 第 %d 层（上一动作 = %s）"
			% [前层, s.run_state.floor_num, str(s.last.get("行动", ""))])
	树根.remove_child(mv)
	mv.free()

# ==========================================================================================
# 段 9（M4-2 追加 · D-08 / D-10）：推进剂见底 → 追击战 —— 视图不许把门面开的那一场顶掉
#   背景（★ D-10 后的现行口径）：封存 JS `92-肉鸽界面-1-大图与记录.js:315`「**这一格结算完**
#   就会触发追击战」。所以顺序是：原地结算这一格（战斗格 → 打脚下的节点战）→ 结算完才开追击战。
#   旧版 `_点格` 无论怎样都继续 `_进入脚下(true)` → 顺手结算脚下这个节点 →
#   （实测）脚下是遗迹 / 瞭望站 / 招募站 / 休整 / 黑市 / 事件这类格时，屏幕被切回 "map"，
#   那一场追击战就再也没人管 → 推进剂 0、走不动也打不了。这一段就是钉住这个守卫。
# ==========================================================================================

func _段9_追击战(t, 树根: Node) -> void:
	_段9a_走上去就开追击战且不被顶掉(t, 树根)
	_段9b_证据_不设守卫会怎样(t, 树根)
	_段9c_打追击战按钮(t, 树根)

## ① 这一步走完推进剂刚好见底，落脚的是**战斗格** → ★ D-10：**这一格先结算**（打脚下的节点战），
##   结算完**才**开追击战；视图必须停手（不许抢着结算、也不许把刚开的那一场顶掉）。
##   打完追击战不许卡在「0 推进剂 + 没打追击战」。
func _段9a_走上去就开追击战且不被顶掉(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke7.json"
	if not s.start_new_run(20261013 + 23, "混编"):
		t.ok(false, "★ 段 9a：开一局失败，剩下的断言跑不了")
		return
	if s.run_state == null:
		return
	if not _招募并上阵(s, 3):
		t.ok(false, "★ 段 9a：招募 / 上阵没做成（追击战要求出击名单非空），剩下的断言跑不了")
		return
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "第 %d 层找不到战斗格 —— 段 9a 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 真类型 := str(s.run_state.cell_at(战斗格).get("类型", ""))
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "战斗格 %d 找不到相邻落脚点 —— 造不出「走一步就刚好见底」的局面" % 战斗格)
		return
	# ★ 夹具：把节点摆到相邻落脚点（**本层起点**，不标任何中间格）+ 推进剂 = 走到战斗格的花费
	s.run_state.node_id = int(s.run_state.map_data.get("起点", 0))
	s.run_state.chased = false
	s.run_state.exit_chase = false
	var 费 := int(MapNavigator.can_move_to(s.run_state, 战斗格).get("cost", 0))
	if 费 < 1:
		t.ok(false, "战斗格 %d 走一步的花费 = %d（要 ≥ 1）—— 段 9a 剩下的断言跑不了" % [战斗格, 费])
		return
	s.run_state.propellant = 费
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	s.screen = "map"
	mv.refresh()
	t.ok(str(s.last.get("行动", "")) != "追击战" and s.battle_ctx.is_empty(),
		"点之前：还没开打（推进剂被夹具设成 %d = 走这一格的花费）" % 费)
	# ★ 只点这一下 —— ★ 2026-10-18：战斗格走上去**先进战前编队确认屏**（不是直接开打）；
	#   点【确认编队 · 开始战斗】才真的走 `enter_current_node()` 结算这一格。
	#   ★ D-10 的前提不变：门面**不在 `move_to_cell` 里开追击战** —— 这一格自己还有没结算的东西，
	#     所以先结算这一格（战斗格 → `battle` 屏打脚下的节点战），结算完才轮到追击战。
	mv._点格(战斗格)
	t.ok(s.run_state.propellant == 0, "★ 这一步走完推进剂见底（propellant = %d）" % s.run_state.propellant)
	t.ok(s.screen == "formation" and s.pending_battle_confirm,
		"★ 2026-10-18：战斗格走上去先进战前编队确认屏（screen = %s、pending = %s；脚下这一格类型 = %s）"
		% [s.screen, str(s.pending_battle_confirm), 真类型])
	t.ok(str(s.run_state.map_data.get("当前节点类型", "")) == 真类型 and s.battle_ctx.is_empty(),
		"★ 确认之前还没开打、也没有被改成「追击」（`map_data[\"当前节点类型\"]` 仍是 %s、battle_ctx 空 = %s）"
		% [str(s.run_state.map_data.get("当前节点类型", "")), str(s.battle_ctx.is_empty())])
	s.confirm_formation_and_start_battle()
	t.ok(s.screen == "battle",
		"★ D-10：确认之后才结算这一格：screen = %s（脚下这一格类型 = %s）" % [s.screen, 真类型])
	t.ok(str(s.last.get("行动", "")) == "开战" and str(s.last.get("格类型", "")) == 真类型,
		"★ D-10：先打的是**脚下的节点战**（上一动作 = %s / 格类型 = %s / 这一格真类型 = %s）"
		% [str(s.last.get("行动", "")), str(s.last.get("格类型", "")), 真类型])
	t.ok(MapNavigator.exit_chase_pending(s.run_state),
		"★ D-10：**追击战还欠着**（推进剂 %d、本层已追击过 = %s → `exit_chase_pending` = true）"
		% [s.run_state.propellant, str(s.run_state.chased)])
	t.ok(str(s.run_state.map_data.get("当前节点类型", "")) == 真类型,
		"★ D-10：视图没有再往下结算别的（`map_data[\"当前节点类型\"]` 仍是 %s，不是「追击」）"
		% str(s.run_state.map_data.get("当前节点类型", "")))
	t.ok(not s.battle_ctx.is_empty(), "★ 这场节点战有真 ctx（我方 %d 台 / 敌方 %d 台）"
		% [(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	# ★ D-10 补的第一步：结算这场**节点战**（打完 + 结算）。
	#   两条分支都要认识（口径 D · 内核那一支一个字没动）：
	#     · **打赢**了 → `finish_battle_and_settle()` 里 `s.propellant <= 0` 那一支走内核
	#       `after_chase_win` → **已经换层**（屏幕进结算屏、新一层推进剂回满）；
	#     · **没打赢** → 那一支不碰推进剂，于是 D-10 补的 `_接追击战(s, true)` 接着把追击战开出来。
	s.auto_finish_battle()
	var 节点战胜 := str(s.battle_ctx.get("result", {}).get("结果", "")) == "胜" if s.battle_ctx.get("result") is Dictionary else false
	s.finish_battle_and_settle()
	if 节点战胜:
		t.ok(s.screen == "result" and s.run_state.floor_num == 2,
			"★ D-10：节点战**打赢** → 内核 `after_chase_win` 那一支当场换层（screen = %s、第 1 层 → 第 %d 层）"
			% [s.screen, s.run_state.floor_num])
		t.ok(not MapNavigator.exit_chase_pending(s.run_state) and s.run_state.propellant > 0,
			"★ D-10：换层之后不再欠着追击战（exit_chase_pending = %s、推进剂 %d > 0 → 又能走了）"
			% [str(MapNavigator.exit_chase_pending(s.run_state)), s.run_state.propellant])
	else:
		t.ok(s.screen == "battle" and str(s.last.get("行动", "")) == "追击战" and str(s.last.get("格类型", "")) == "追击",
			"★ D-10：节点战**没打赢** → 这一格结算完**这时才**开追击战（screen = %s、上一动作 = %s、格类型 = %s）"
			% [s.screen, str(s.last.get("行动", "")), str(s.last.get("格类型", ""))])
		# ★ D-10 补的第二步：结算这场**追击战** → 不许卡在「0 推进剂 + 没打追击战」
		s.auto_finish_battle()
		s.finish_battle_and_settle()
	t.ok(not MapNavigator.exit_chase_pending(s.run_state) or s.run_state.status == "失败",
		"★ 打完追击战之后不再欠着（exit_chase_pending = %s · 状态 = %s · 第 %d 层 · 推进剂 %d）"
		% [str(MapNavigator.exit_chase_pending(s.run_state)), s.run_state.status,
			s.run_state.floor_num, s.run_state.propellant])
	t.ok(s.run_state.floor_num == 2,
		"★ 追击战结束就被赶到下一层（第 1 层 → 第 %d 层）" % s.run_state.floor_num)
	树根.remove_child(mv)
	mv.free()

## ② 正向断言（★ D-10 改口径）：点完这一格、再把这一格结算掉（= 关掉面板那一下）——
##   屏幕必须切到 `battle`（那一场追击战真的开出来了），而且**不会**被顶回 `map`。
##   ★ 为什么这条要改：原来这里是「**不设守卫**（复刻旧行为）会怎样」的取证，前提是「门面在
##     `move_to_cell` 里当场开追击战、随后 `enter_current_node()` 又顺手把脚下这一格结算掉」——
##     D-10 之后这个旧行为**已经不存在了**（门面自己就把顺序摆对了：先结算这一格、结算完才追击），
##     所以那条取证没有前提了。这里改成**正向**断言：门面这一层已经把顺序摆对，
##     `enter_current_node()` 只会把「这一格结算完该开的那场」开出来，不会把任何一场顶掉。
##   ★ 函数名保留 `_段9b_证据_不设守卫会怎样`（段 9 的调用点与「这一段在验什么」的对应关系不动）。
func _段9b_证据_不设守卫会怎样(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke8.json"
	if not s.start_new_run(20261013 + 29, "混编"):
		t.ok(false, "★ 段 9b：开一局失败，剩下的断言跑不了")
		return
	if s.run_state == null:
		return
	if not _招募并上阵(s, 3):
		t.ok(false, "★ 段 9b：招募 / 上阵没做成，剩下的断言跑不了")
		return
	var 格 := _找可达的格(s, ["遗迹", "瞭望站", "招募站", "休整", "黑市", "事件"], false)
	if 格 < 0:
		t.ok(false, "第 %d 层找不到可达的「非战斗、非出口」格 —— 段 9b 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 类型 := str(s.run_state.cell_at(格).get("类型", ""))
	if _摆到一步见底(s, 格) < 0:
		t.ok(false, "%s 格 %d 造不出「走一步就刚好见底」的局面" % [类型, 格])
		return
	# ★ 弹窗类节点（黑市 / 休整 / 事件）视图**不当场**结算 —— 它只发 `请求弹窗`，
	#   等玩家**关掉面板**那一下才算「这一格结算完」。所以这里先按视图的真实行为断言。
	#   （判据照视图自己的常量 `MapView.弹窗节点`，不在这里另抄一份。）
	var 弹窗类 := bool(MapView.弹窗节点.has(类型))
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	s.screen = "map"
	mv.refresh()
	mv._点格(格)
	# ★ 先确认：**只点这一下** —— 门面**不**开追击战，而是先结算这一格。
	#   （三种格都成立：**弹窗类**节点视图不当场结算、屏幕留在 map；
	#     **当场结算类**节点视图自己 `_进入脚下(true)` → 结算完 **才**开出追击战。）
	#   判据读**视图自己手里的会话**（`mv.session`），不是我们自己那个引用 —— 免得测的是别的东西。
	var vs := mv.session
	t.ok(s.screen == "map" and vs.battle_ctx.is_empty(),
		"先确认：★ D-10 门面**不在 `move_to_cell` 里开追击战** —— 点完这一下屏幕还在 %s、`battle_ctx` 空 = %s"
		% [s.screen, str(vs.battle_ctx.is_empty())])
	if 弹窗类:
		t.ok(vs.battle_ctx.is_empty() and _行动(vs) != "追击战",
			"先确认：走上**弹窗类**「%s」格 %d → 视图留在 map 发弹窗、门面也**没**开追击战（上一动作 = %s、battle_ctx 空 = %s）"
			% [类型, 格, _行动(vs), str(vs.battle_ctx.is_empty())])
	else:
		t.ok(s.screen == "battle" and _行动(vs) == "追击战",
			"先确认：走上 %s 格 %d → 这一格结算完**才**当场开出追击战（screen = %s、上一动作 = %s）"
			% [类型, 格, s.screen, _行动(vs)])
	# ★ 正向（这就是「关掉面板」那一下）：门面这一层已经把顺序摆对了 ——
	#   直接 `enter_current_node()` 结算这一格（推进剂 0 已经把追击战欠下了）→ 屏幕切到 `battle`；
	#   那一场**不会被顶掉**（`map_data["当前节点类型"]` 已经是「追击」，`start_node_battle()`
	#   会照着它再走一次追击战，屏幕仍然停在 `battle`）。
	s.enter_current_node()
	t.ok(s.screen == "battle" and _行动(s) == "追击战",
		"★ 正向：`enter_current_node()`（= 关掉面板那一下）→ 这一格结算完照样开得出追击战（screen = %s、上一动作 = %s）"
		% [s.screen, _行动(s)])
	t.ok(not s.battle_ctx.is_empty() and str(s.run_state.map_data.get("当前节点类型", "")) == "追击",
		"★ 正向：那一场是**真**打起来了（ctx 我方 %d 台 / 敌方 %d 台），而且 `map_data[\"当前节点类型\"]` = %s（视图没有把脚下那一格结算掉、也没把这一场顶掉）"
		% [(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0,
			str(s.run_state.map_data.get("当前节点类型", ""))])
	树根.remove_child(mv)
	mv.free()

## `last["行动"]` 的短读（段 9b 的断言要打真实值）。
func _行动(s: GameSession) -> String:
	return str(s.last.get("行动", ""))

## ③ 「打追击战」兜底按钮：★ 2026-10-18 起**只在推进剂为 0 时可见**；够格时点它进「战前编队确认屏」，
##   再点【确认编队 · 开始战斗】才真的走门面 `fight_chase_battle()` 进战斗；
##   不够格时不可点（或藏起来），点了也不打（并给原因）。
func _段9c_打追击战按钮(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke9.json"
	if not s.start_new_run(20261013 + 31, "混编"):
		t.ok(false, "★ 段 9c：开一局失败，剩下的断言跑不了")
		return
	if s.run_state == null:
		return
	if not _招募并上阵(s, 3):
		t.ok(false, "★ 段 9c：招募 / 上阵没做成（追击战要求出击名单非空），剩下的断言跑不了")
		return
	# ★ 门面那道「有未决招募券不许开新战斗」的闸会挡住这一段的点击路 —— 先把券决定完。
	var 丢 := 0
	while s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	s.screen = "map"
	mv.refresh()
	var 按钮 = mv.find_child("打追击战按钮", true, false)
	t.ok(按钮 != null, "大地图上有「打追击战按钮」（节点还在树里，靠 `visible` 控制露面）")
	t.ok(按钮 != null and not bool((按钮 as Button).visible),
		"★★ 段 9c：推进剂还够（%d）→ 「打追击战」按钮**藏起来**（visible = false，不再常驻误导玩家）" % s.run_state.propellant)
	# ★ 不够格时点了也不许开打（并要给出原因）
	mv._点打追击()
	t.ok(s.battle_ctx.is_empty() and s.screen == "map",
		"★ 不够格时点它 → 不开打（screen 仍是 %s，battle_ctx 仍空）" % s.screen)
	t.ok(_面板里有(mv, "用不上"), "★ 不够格时写清了为什么用不上")
	# 造出「推进剂见底 + 本层没被追击过 + 不在战斗里」→ 按钮应当露面且可点
	s.run_state.propellant = 0
	s.run_state.chased = false
	s.run_state.node_id = int(s.run_state.map_data.get("起点", 0))
	s.screen = "map"
	mv.refresh()
	var 按钮2 = mv.find_child("打追击战按钮", true, false)
	t.ok(按钮2 != null and bool((按钮2 as Button).visible) and not bool((按钮2 as Button).disabled),
		"★★ 段 9c：推进剂见底（%d）+ 本层没追击过 → 按钮露面且可点（判据 = 内核 exit_chase_pending）" % s.run_state.propellant)
	# ★ 2026-10-18：点它进的是**战前编队确认屏**（不是直接开打）
	mv._点打追击()
	t.ok(s.screen == "formation" and s.pending_battle_confirm and str(s.pending_battle_kind) == "chase",
		"★★ 段 9c：点「打追击战」→ 进战前编队确认屏（screen = %s、pending = %s、kind = %s）"
		% [s.screen, str(s.pending_battle_confirm), str(s.pending_battle_kind)])
	t.ok(s.battle_ctx.is_empty(), "★★ 段 9c：确认之前还没开打（battle_ctx 空）")
	# ★ 再点【确认编队 · 开始战斗】→ 这时才真的走 `fight_chase_battle()`
	s.confirm_formation_and_start_battle()
	t.ok(s.screen == "battle" and str(s.last.get("行动", "")) == "追击战",
		"★★ 段 9c：点【确认编队 · 开始战斗】→ 进门面的 `fight_chase_battle()`：screen = %s、上一动作 = %s"
		% [s.screen, str(s.last.get("行动", ""))])
	t.ok(not s.battle_ctx.is_empty(), "★ 这一场真的有 ctx（敌方 %d 台）"
		% [(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	树根.remove_child(mv)
	mv.free()

# ==========================================================================================
# 段 6：静默纪律
# ==========================================================================================

func _段6_静默(t, session: GameSession) -> void:
	t.ok(session.errors is Array, "session.errors 是数组")

# ==========================================================================================
# 工具
# ==========================================================================================

## 数一棵树里有几张 `UnitCard`。
## ★ 为什么按**类型**数而不是按名字：同一行里 4 张卡都叫「单位卡」，Godot 会给同父同名
##   的后来者自动加后缀，`find_children("单位卡")` 只能数到每行的第一张（实测 4 张）。
func _数单位卡(v: Node) -> int:
	var n := 0
	for c in v.find_children("*", "Control", true, false):
		if c is UnitCard:
			n += 1
	return n

## 战斗状态的纯读快照（用来证明「表现层 refresh() 不改状态」）。
func _快照(s: GameSession) -> String:
	return JSON.stringify({
		"allies": s.battle_ctx.get("allies"), "enemies": s.battle_ctx.get("enemies"),
		"气势": s.battle_ctx.get("气势"), "手牌": s.battle_ctx.get("战术手牌"),
		"候补": s.battle_ctx.get("候补初始牌"), "已打出": s.battle_ctx.get("已打出战术牌"),
	})

## 在当前层找一个战斗格（照 test_session_flow.gd 的同一口径）。
## ★ 跳过「出口格」：站在出口格上时追击战那一步归 `try_advance_floor()` 管（先 `begin_exit_chase`），
##   D-10 段 9a 要的是**普通的**战斗格（作战 / 精英 / 守军 / 侵蚀源）。
func _找战斗格(s: GameSession) -> int:
	var 战斗类型 := ["作战", "普通", "精英", "守军", "侵蚀源"]
	if s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if not MapNavigator.walkable(s.run_state, k):
			continue
		if 战斗类型.has(str(s.run_state.cell_at(k).get("类型", ""))):
			return k
	return -1

## 找一格「类型在 `类型们` 里、现在走得过去、并且（`要走过` 为真时）已经走过」的格；没有 → −1。
## 「走得过去」直接用门面的纯读预告 `preview_cell_move().ok`，不自己算推进剂。
## ★ 跳过**脚下这一格**（起点）：D-10 段 9a / 9b 的夹具要「走一步就刚好见底」，
##   而走到自己脚下那一步的内核口径是「已经在那一格」被拒（花费 0、`_摆到一步见底()` 也造不出来）。
func _找可达的格(s: GameSession, 类型们: Array, 要走过: bool) -> int:
	if s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if k == s.run_state.node_id:
			continue
		var 格 := s.run_state.cell_at(k)
		if not 类型们.has(str(格.get("类型", ""))):
			continue
		if 要走过 != s.run_state.is_visited(k):
			continue
		if bool(s.preview_cell_move(k).get("ok", false)):
			return k
	return -1

## 找战斗格 `格` 的一个「相邻、还没走过、走得过去」的落脚点（把 node_id 摆上去再走一格）；没有 → −1。
func _找相邻落脚点(s: GameSession, 格: int) -> int:
	if s.run_state == null:
		return -1
	var 列数 := maxi(1, int(s.run_state.map_data.get("列数", 5)))
	for k in MapGenerator.neighbors_of(格, 列数):
		if not s.run_state.has_cell(k):
			continue
		if s.run_state.is_visited(k) or bool(s.run_state.cell_at(k).get("已过", false)):
			continue
		var 备份 := s.run_state.node_id
		s.run_state.node_id = k
		var 行 := bool(MapNavigator.can_move_to(s.run_state, 格).get("ok", false))
		s.run_state.node_id = 备份
		if 行:
			return k
	return -1

## ★ 造一个「走一步就刚好见底」的局面（段 9 的夹具）：把 `node_id` 摆回本层起点、`chased` 清掉，
## 再把推进剂设成「从起点走到 `目标格` 的花费」——走完就是 0。返回收费（<0 = 造不出来）。
## 注意：这里动 `run_state` 是**测试夹具**（造局面），不是表现层在算数值。
func _摆到一步见底(s: GameSession, 目标格: int) -> int:
	if s.run_state == null:
		return -1
	s.run_state.node_id = int(s.run_state.map_data.get("起点", 0))
	s.run_state.chased = false
	var 走 := MapNavigator.can_move_to(s.run_state, 目标格)
	if not bool(走.get("ok", false)):
		return -1
	var 费 := int(走.get("cost", 0))
	if 费 < 1:
		return -1
	s.run_state.propellant = 费
	return 费

## 用开局券招几台并把第一台摆上出击位（追击战要求「出击名单非空」）。**不动表现层**。
func _招募并上阵(s: GameSession, 最多: int) -> bool:
	for _i in 最多:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0)
	if s.run_state == null or s.run_state.roster.is_empty():
		return false
	# ★ 2026-10-18：招募会带出「三选一」，先选掉（免得待选牌影响后面的换层 / 结算路径）。
	var 选 := 0
	while not s.run_state.pending_card_picks.is_empty() and 选 < 12:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选 += 1
	var 键 := str(s.run_state.roster.keys()[0])
	return s.set_lineup_slot(键, str(s.lineup_slots()[0].get("位名", "")))

## ★ 把手上**没决定的招募券**全部放弃（2026-10-18 起：有未决券时大地图点格子不移动、
## 也不许手动开新战斗）。夹具专用 —— 走的是门面公开口子 `discard_ticket()`。返回丢了几张。
func _清券(s: GameSession) -> int:
	var 丢 := 0
	while s != null and s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	return 丢

## 视图的「预告面板」里有没有含 `关键词` 的那一行字（用来证明「写清了为什么」）。
func _面板里有(v: Node, 关键词: String) -> bool:
	var 面板 = v.find_child("预告面板内容", true, false)
	if 面板 == null:
		return false
	for c in (面板 as Node).get_children():
		if c is Label and str((c as Label).text).contains(关键词):
			return true
	return false

func _根() -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root if 树 != null else null
