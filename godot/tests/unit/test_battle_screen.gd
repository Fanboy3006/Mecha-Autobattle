## 职责：战斗屏端到端冒烟 —— 真开一局战斗再验（专属排 / 公有排 / 打牌 / 推进 / 自动打完 / 结算）。
##
## 纪律：`extends RefCounted` + `func run(t)`，放在 `godot/tests/unit/` 顶层即自动被发现；**不动 `run_tests.gd`**。
## headless 下 `run_tests.gd` 是 `SceneTree`，所以必须把 `Control` 真的挂进 `(Engine.get_main_loop() as SceneTree).root`，用完必 `free()`。
## 本文件 = 原 `test_presentation_smoke.gd` 段 7 整段搬出来的（RT-3b 体积拆分，纯搬家：段号与断言文字一个字没改）。
extends RefCounted

func run(t) -> void:
	var 错误 := []
	DataLoader.install(错误)
	_段7_真打一场(t, _根())

# ---- 段 7：真开一局战斗再验（专属排 / 公有排 / 打牌 / 推进 / 自动打完 / 结算） ----

func _段7_真打一场(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_presentation_smoke.json"
	t.ok(s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013),
		"★ 开始快速测试战斗(秘银, 20261013) 开起来了（上排 %d 张 / 下排 %d 张）"
		% [s.upper_hand_cards().size(), s.lower_hand_cards().size()])
	t.ok(s.screen == "battle", "开战之后 screen = battle（真实值 %s）" % s.screen)
	if s.battle_ctx.is_empty():
		t.ok(false, "battle_ctx 是空的 → 段 7 剩下的断言跑不了")
		return
	var bv := BattleView.new()
	树根.add_child(bv)
	bv.setup(s)
	bv.refresh()
	t.ok(bv.find_child("手牌栏", true, false) != null, "战斗屏建起来后有「手牌栏」")
	var 上排 := s.upper_hand_cards()
	var 下排 := s.lower_hand_cards()
	var 可打上 := 上排.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	var 可打下 := 下排.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	t.ok(not (可打上 + 可打下).is_empty(), "开局战意 %s 之下能打 上排 %d / 下排 %d 张（门面「可打」）"
		% [str(s.battle_ctx.get("战意", 0.0)), 可打上.size(), 可打下.size()])
	# ★ 单机牌组只把「能打」的牌摆上卡行（打不动的留在左边牌库），所以卡数 = 可打张数。
	var 卡数 := _单机卡数(bv)
	t.ok(卡数 == 可打上.size() + 可打下.size() and 卡数 > 0,
		"★ 手牌栏里有牌：画出 %d 张（门面上排 %d 张 / 下排 %d 张里能打 %d / %d 张）"
		% [卡数, 上排.size(), 下排.size(), 可打上.size(), 可打下.size()])
	var 原因数 := bv.find_children("单机卡状态", "", true, false).size()
	t.ok(原因数 == 卡数 and 原因数 > 0,
		"★ 每张单机卡都带一行状态（「点击发动」/ 打不出来的原因原文写在卡上）：%d 行" % 原因数)
	var 层级数 := bv.find_children("单机卡信息", "", true, false).size()
	t.ok(层级数 == 卡数, "每张单机卡都带一行关键信息（战意 / 威力 / 段数 / 目标）：%d 行" % 层级数)
	t.ok(_数单位卡(bv) == int(Fm.SLOTS()) * 2,
		"阵型区里正好 %d 张单位卡（★ 8 格 × 双方）" % _数单位卡(bv))
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
		"★ 战斗屏 refresh() 是纯读：双方单位 / 气势 / 公有手牌的快照逐字没变（%d 字符）" % 快前.length())
	var 打 := {}
	for 组 in [[可打上, true], [可打下, false]]:
		if not 打.is_empty():
			break
		for c in (组[0] as Array):
			if not (c is Dictionary):
				continue
			var 区 := str((c as Dictionary).get("区", ""))
			var 键 := str((c as Dictionary).get("手牌键", ""))
			var r: Dictionary = {}
			if 区 == GameSession.单机区_主武器:
				r = s.打出主武器卡(键)
			elif 区 == GameSession.单机区_副武器:
				r = s.打出副武器(键)
			elif 区 == GameSession.单机区_衍生:
				r = s.打出衍生攻击卡(键)
			elif 区 == "连携牌":
				r = s.打出连携牌(键)
			else:
				r = s.打出精神或公有牌(键)
			if bool(r.get("ok", false)):
				打 = r
				break
	t.ok(not 打.is_empty(), "点一张单机手牌 → 门面出牌口子返回 ok（打出的是 %s）" % str(s.last.get("牌", "")))
	bv.refresh()
	var 后可打上 := s.upper_hand_cards().filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	var 后可打下 := s.lower_hand_cards().filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	var 后卡数 := _单机卡数(bv)
	t.ok(后卡数 == 后可打上.size() + 后可打下.size(),
		"打完一张之后手牌栏重画成 %d 张（门面现在能打 上排 %d / 下排 %d 张）"
		% [后卡数, 后可打上.size(), 后可打下.size()])
	var 前回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	s.step_battle_turn()
	var 后回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	t.ok(后回合 > 前回合, "推进下一回合：第 %d 回合 → 第 %d 回合" % [前回合, 后回合])
	bv.refresh()
	var 战报行数 := bv.find_children("战报行*", "", true, false).size()
	t.ok(战报行数 > 0, "战报栏里画出了结构化日志 %d 行" % 战报行数)
	# ★ RT-3b：单机牌组下 `战报提示` 写的是「上排 N 张（能打 M）· 下排 N 张（能打 M）」，
	#   「本回合已打出 N 张」那一句挪到了手牌栏标题上 —— 两处一起验，断言的意图不变
	#   （都是**事实**陈述，不是「本回合最多能打几张」的上限）。
	var 战报提示 = bv.find_child("战报提示", true, false)
	var 提示文 := str((战报提示 as Label).text) if 战报提示 is Label else ""
	var 手牌标题 = bv.find_child("手牌标题", true, false)
	var 标题文 := str((手牌标题 as Label).text) if 手牌标题 is Label else ""
	t.ok(战报提示 != null and 提示文.contains("上排") and 提示文.contains("能打")
		and 手牌标题 != null and 标题文.contains("本回合已打出"),
		"两处提示都写清了本回合的事实（战报栏：%s / 手牌栏：%s）"
		% [提示文.substr(0, 48), 标题文.substr(0, 72)])
	s.auto_finish_battle()
	t.ok(s.battle_ctx.get("result") != null, "自动打完本场：结果 = %s" % s.战果文字())
	bv.refresh()
	s.finish_battle_and_settle()
	t.ok(s.screen == "result", "finish_battle_and_settle() 之后 screen = result（真实值 %s）" % s.screen)
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
	var 回顾 = rv.find_child("日志回顾", true, false)
	t.ok(回顾 != null and str(回顾.text).contains("战斗日志"), "战报回顾里有「战斗日志一共 N 行」那一段")
	var 回血 = rv.find_child("回血对照", true, false)
	t.ok(回血 != null and str(回血.text).contains("%"),
		"回血前后按百分比显示（D-04：不依赖 int/float 区分）：「%s」"
		% (str(回血.text).substr(0, 48) if 回血 != null else ""))
	树根.remove_child(rv)
	rv.free()
	树根.remove_child(bv)
	bv.free()

# ---- 工具 ----

## 数一棵树里有几张 `UnitCard`。为什么按**类型**数而不是按名字：同一行 4 张卡都叫「单位卡」，
## Godot 会给同父同名的后来者自动加后缀，`find_children("单位卡")` 只能数到每行的第一张（实测 4 张）。
func _数单位卡(v: Node) -> int:
	var n := 0
	for c in v.find_children("*", "Control", true, false):
		if c is UnitCard:
			n += 1
	return n

func _单机卡数(v: Node) -> int:
	if v == null or not is_instance_valid(v):
		return 0
	return v.find_children("专属卡*", "", true, false).size() \
		+ v.find_children("公有卡*", "", true, false).size()

## 战斗状态的纯读快照（用来证明「表现层 refresh() 不改状态」）。
func _快照(s: GameSession) -> String:
	return JSON.stringify({
		"allies": s.battle_ctx.get("allies"), "enemies": s.battle_ctx.get("enemies"),
		"气势": s.battle_ctx.get("气势"), "公有手牌": s.battle_ctx.get("公有手牌"),
	})

func _根() -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root if 树 != null else null
