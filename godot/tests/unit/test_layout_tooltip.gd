## 职责：版面门禁：Mouse-Over 说明信息（段 3：机体卡 / 编队格位 / 名册 / 招募候选 / 手牌 / 候补 / 三选一 / 战术牌库）。
##   ★ RT-3b：原「段 10 UX-2 发牌来源 / 悬停联动」整段删除（见文件末尾说明）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起3: int = t.passes + t.fails
	await _段3_悬停说明信息(t, 根)
	var 段3: int = t.passes + t.fails - 起3
	t.info("★ 版面门禁（本套）：段 3（Mouse-Over 说明信息）%d 项（段 10 已在 RT-3b 随旧手牌链路删除）" % 段3)

func _提示含(控件: Node, 片段: String) -> bool:
	if 控件 == null or not is_instance_valid(控件):
		return false
	if 控件 is Control and str((控件 as Control).tooltip_text).contains(片段):
		return true
	for c in 控件.get_children():
		if _提示含(c, 片段):
			return true
	return false

func _提示文(控件: Node) -> String:
	if 控件 is Control:
		return str((控件 as Control).tooltip_text)
	return ""

func _段3_悬停说明信息(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 3 跑不了")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	var 层 = boot.find_child("悬停说明层", true, false)
	t.ok(层 is HoverTooltip, "★ boot 下有「悬停说明层」（HoverTooltip，整局只有一层）")
	var 面板 = boot.find_child("悬停面板", true, false)
	t.ok(面板 is Control, "悬停说明层里有「悬停面板」")
	t.ok(面板 is Control and not (面板 as Control).visible, "★ 初始 `悬停面板.visible == false`（不悬停就不显示）")
	if not (层 is HoverTooltip):
		_拆boot(树根, 舱)
		return
	var 悬停: HoverTooltip = 层
	await _段3a_机体悬停(t, 舱, 悬停)
	await _段3b_卡牌悬停(t, 舱, 悬停)
	_拆boot(树根, 舱)

func _段3a_机体悬停(t, 舱: Dictionary, 悬停: HoverTooltip) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ---------- 战斗屏 ----------
	# ★ RT-3d：只是「借入口开一场战斗」→ 改走新入口（断言不动）。
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013):
		t.ok(false, "段 3a：开始快速测试战斗(秘银, 20261013) 开不起来")
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "段 3a：战斗屏视图类型不对（%s）" % str(bv))
		return
	var 视图: BattleView = bv
	var 占位 := _位号到键(s, "ally")
	var 敌位 := _位号到键(s, "enemy")
	t.ok(视图.find_children("*", "UnitCard", true, false).size() == int(Fm.SLOTS()) * 2,
		"段 3a：战斗屏有 %d 张 UnitCard（我方 %d 台 / 敌方 %d 台在场）"
		% [int(Fm.SLOTS()) * 2, 占位.size(), 敌位.size()])
	var 查过 := 0
	for 位号 in 占位.keys():
		var 卡: Control = 视图._我方卡[int(位号)]
		var 键 := str(占位[位号])
		var 名 := str((s.unit_view("ally", 键) as Dictionary).get("名", 键))
		var 前缀 := "战斗屏我方 %s（%s）" % [Fm.位名(float(位号)), 名]
		_机器卡断言(t, 卡, 名, 前缀)
		_悬停断言(t, 悬停, 卡, 前缀)
		查过 += 1
		if 查过 >= 4:
			break
	for 位号 in 敌位.keys():
		var 卡: Control = 视图._敌方卡[int(位号)]
		var 键 := str(敌位[位号])
		var 名 := str((s.unit_view("enemy", 键) as Dictionary).get("名", 键))
		var 前缀 := "战斗屏敌方 %s（%s）" % [Fm.位名(float(位号)), 名]
		_机器卡断言(t, 卡, 名, 前缀)
		_悬停断言(t, 悬停, 卡, 前缀)
		break
	# ---------- 编队屏 ----------
	# ★ 招募弹窗的「候选机体」必须**先用券之前**量（券用光之后就招不到人了，候选列表自然是空的）；
	var 券前候选 := s.available_recruit_targets(0).size()
	boot.打开弹窗("招募", {})
	await _等帧(3)
	var 候选 = boot.find_child("候选列表", true, false)
	var 候选钮 := _找按钮(候选)
	t.ok(候选钮 != null and 券前候选 > 0,
		"★ 招募弹窗：候选机体的每条都是一个可悬停按钮（这张券现在能招 %d 位）" % 券前候选)
	if 候选钮 != null:
		_机器卡断言(t, 候选钮, "", "招募弹窗候选机体")
		_悬停断言(t, 悬停, 候选钮, "招募弹窗候选机体")
	await _关弹窗(boot)
	var 招 := 0
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "段 3a：用开局券招到 %d 台来做编队屏的悬停断言（名册 %d 台）"
		% [招, s.run_state.roster.size()])
	var 键们 := s.run_state.roster.keys()
	# ★ 摆哪几台就查哪几台：格位按钮的文本是「位名\n显示名」，照**显示名**找回那一颗按钮，
	var 上阵: Array = []
	var 上阵名: Array = []
	for i in mini(2, 键们.size()):
		var 键 := str(键们[i])
		if s.set_lineup_slot(键, str(s.lineup_slots()[i].get("位名", ""))):
			var 显 := str(RosterManager.模板(键).get("pilot", RosterManager.模板(键).get("name", 键)))
			if 显.is_empty():
				显 = 键
			上阵.append(键)
			上阵名.append(显)
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	t.ok(上阵.size() >= 1, "★ 编队屏：摆了 %d 台到出击位（%s）" % [上阵.size(), "、".join(上阵名)])
	var 位格: Control = null
	var 上阵显示名 := ""
	for 排名 in ["第0排", "第1排"]:
		var 排 = boot.find_child(排名, true, false)
		if 排 == null:
			continue
		for k in (排 as Node).get_children():
			if not (k is Button):
				continue
			var 文 := str((k as Button).text)
			if 文.contains("（空）"):
				continue
			for j in 上阵名.size():
				var 键 := str(上阵[j])
				var 显 := str(上阵名[j])
				# ★ 格位按钮正文在**这台机体的模板里没有 `名` 字段**时会退成机体键（B1 / B2），
				#   所以正文与机体键、显示名任一相符都算找到。
				if 文.contains(显) or 文.contains(键):
					位格 = k
					上阵显示名 = 显 if 文.contains(显) else 键
					break
			if 位格 != null:
				break
		if 位格 != null:
			break
	t.ok(位格 != null, "★ 编队屏：找得到「已上阵的格位按钮」（上阵了 %s）" % "、".join(上阵名))
	if 位格 != null:
		_机器卡断言(t, 位格, 上阵显示名, "编队屏已上阵格位［%s］" % 上阵显示名)
		_悬停断言(t, 悬停, 位格, "编队屏已上阵格位［%s］" % 上阵显示名)
	var 列表 = boot.find_child("名册列表", true, false)
	var 名册钮 := _找按钮(列表)
	t.ok(名册钮 != null, "★ 编队屏：找得到「名册列表」里机体按钮（名册 %d 台）" % s.run_state.roster.size())
	if 名册钮 != null:
		_机器卡断言(t, 名册钮, "", "编队屏名册列表")
		_悬停断言(t, 悬停, 名册钮, "编队屏名册列表")
	# ---------- 招募弹窗（名册区）----------
	boot.打开弹窗("招募", {})
	await _等帧(3)
	var 名单 = boot.find_child("名册列表", true, false)
	var 名册条: Control = null
	var 名册钮2: Control = null
	if 名单 != null:
		for c in (名单 as Node).get_children():
			if c is Control:
				if 名册条 == null:
					名册条 = c
				for g in (c as Node).get_children():
					if g is Button and 名册钮2 == null:
						名册钮2 = g
	t.ok(名册条 != null, "★ 招募弹窗：名册区每条也有机体说明")
	if 名册条 != null:
		t.ok(_提示含(名册条, "武器"), "★★ 招募弹窗名册条目 tooltip 含「武器」段（机体属性 + 武器说明齐全）")
		t.ok(_提示含(名册条, "装甲") and _提示含(名册条, "防御") and _提示含(名册条, "机动"),
			"★★ 招募弹窗名册条目 tooltip 含装甲 / 防御 / 机动（机体属性）")
	t.ok(名册钮2 != null, "★ 招募弹窗：名册条目里有「晋升」按钮，也挂着同一段机体说明")
	if 名册钮2 != null:
		_悬停断言(t, 悬停, 名册钮2, "招募弹窗名册按钮")
	await _关弹窗(boot)

func _机器卡断言(t, 卡: Control, 名: String, 前缀: String) -> void:
	var 文 := _提示文(卡)
	t.ok(not 文.strip_edges().is_empty(), "★ %s 的 `tooltip_text` 非空" % 前缀)
	t.ok(文.contains("HP") or 文.contains("生命"), "★ %s 的 tooltip 写清了 HP（「HP」或「生命」）" % 前缀)
	for 片段 in ["装甲", "防御", "机动", "武器"]:
		t.ok(文.contains(片段), "★ %s 的 tooltip 含「%s」" % [前缀, 片段])
	t.ok(名.is_empty() or 文.contains(名) or _短名在(文, 名) or _键在(文, 名),
		"★ %s 的 tooltip 里有这台机体名（%s；tooltip %d 字）" % [前缀, 名, 文.length()])
	t.ok(文.split("\n").size() >= 6, "★ %s 的 tooltip 是多行说明（%d 行）" % [前缀, 文.split("\n").size()])

func _短名在(文: String, 名: String) -> bool:
	return 名.length() >= 2 and 文.contains(名.substr(0, 2))

func _键在(文: String, 键: String) -> bool:
	if 键.length() < 2:
		return false
	var 模 := RosterManager.模板(键)
	var 显 := str(模.get("pilot", 模.get("name", "")))
	if 显.is_empty() or 显 == 键:
		return false
	return 文.contains(显) or _短名在(文, 显)

func _悬停断言(t, 悬停: HoverTooltip, 卡: Control, 前缀: String) -> void:
	悬停.show_for_control(卡)
	var 面板 = 悬停.find_child("悬停面板", true, false)
	var 框: Rect2 = (面板 as Control).get_global_rect() if 面板 is Control else Rect2()
	t.ok(面板 is Control and (面板 as Control).visible,
		"★ %s：`show_for_control()` 之后「悬停面板.visible == true」" % 前缀)
	t.ok(not 悬停.当前文本().strip_edges().is_empty() and _提示文(卡).contains(悬停.当前文本().strip_edges()),
		"★ %s：`当前文本()` 非空（%d 字），且就是贴在这张卡上的那段说明" % [前缀, 悬停.当前文本().length()])
	t.ok(_在界内(框), "★ %s：悬停面板 %s 完全落在 1280×720 内" % [前缀, _短(框)])
	悬停.hide_tip()

func _段3b_卡牌悬停(t, 舱: Dictionary, 悬停: HoverTooltip) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ★ RT-3b：旧入口开出来的那一场没有单机牌组（手牌栏是空的），改用双入口里的新入口。
	if s.screen != "battle" or s.battle_ctx.is_empty() or (s.upper_hand_cards() + s.lower_hand_cards()).is_empty():
		if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261013):
			t.ok(false, "段 3b：开不出战斗")
			return
		boot.route()
		await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(), "段 3b：手上有一场真战斗（screen = %s）" % s.screen)
	# ---------- 单机牌（上排 `专属卡N` / 下排 `公有卡N`）----------
	var 手牌卡 = boot.find_child("专属卡1", true, false)
	if 手牌卡 == null:
		手牌卡 = boot.find_child("公有卡1", true, false)
	t.ok(手牌卡 is Control, "★ 战斗屏有单机牌（专属卡1 / 公有卡1）")
	if 手牌卡 is Control:
		_单机牌断言(t, 悬停, 手牌卡, "战斗屏手牌栏第 1 张")
	var 手牌钮 = boot.find_child("单机卡按钮", true, false)
	t.ok(手牌钮 is Control, "★ 战斗屏有「单机卡按钮」")
	if 手牌钮 is Control:
		_单机牌断言(t, 悬停, 手牌钮, "战斗屏单机卡按钮")
	# ★ RT-3b：原「候补区里有候补卡1 + 它的 tooltip」两条随旧「候补初始牌」链路一起删
	#   （候补区节点与 `reserve_preview()` 已在 RT-4 一并删掉）。
	# ---------- 三选一 ----------
	var 候选: Array = s.run_state.pending_card_picks.duplicate() if s.run_state != null else []
	if 候选.is_empty() and s.run_state != null and not s.run_state.roster.is_empty():
		s.refresh_card_offers(str(s.run_state.roster.keys()[0]))
		候选 = s.run_state.pending_card_picks.duplicate()
	t.ok(not 候选.is_empty(), "★ 三选一有候选（%d 张：%s）" % [候选.size(), ", ".join(候选.map(func(x): return str(x)))])
	if not 候选.is_empty():
		var 卡id := str(候选[0])
		boot.打开弹窗("三选一", {})
		await _等帧(3)
		var 面板 = boot.find_child("候选卡_" + 卡id, true, false)
		t.ok(面板 != null, "★ 三选一弹窗里有「候选卡_%s」" % 卡id)
		if 面板 is Control:
			_牌文断言(t, _提示文(面板), "三选一候选卡_%s" % 卡id)
			_悬停断言(t, 悬停, 面板, "三选一候选卡_%s" % 卡id)
		var 选中钮 := _找按钮(面板)
		t.ok(选中钮 != null, "★ 三选一候选卡里有「选这张」按钮")
		if 选中钮 != null:
			_牌断言(t, 悬停, 选中钮, "三选一「选这张」")
		await _关弹窗(boot)
	# ---------- 战术牌库 ----------
	if s.run_state != null and s.run_state.tactical_deck.is_empty():
		for 卡id in 候选:
			s.pick_tactical_card(str(卡id))
		if s.run_state.tactical_deck.is_empty():
			s.pick_tactical_card("CMD_ALL_OUT")
	boot.打开弹窗("战术牌库", {})
	await _等帧(3)
	var 内置 = boot.find_child("内置内容", true, false)
	var 牌库条: Control = null
	if 内置 != null:
		for c in (内置 as Node).get_children():
			if c is Control and not _提示文(c).strip_edges().is_empty():
				牌库条 = c
				break
	t.ok(牌库条 != null, "★ 战术牌库弹窗里每张牌条目都挂了悬停说明（牌库 %d 张）"
		% (s.run_state.tactical_deck.size() if s.run_state != null else 0))
	if 牌库条 != null:
		_牌断言(t, 悬停, 牌库条, "战术牌库条目")
	await _关弹窗(boot)

func _牌断言(t, 悬停: HoverTooltip, 卡: Control, 前缀: String) -> void:
	_牌文断言(t, _提示文(卡), 前缀)
	_悬停断言(t, 悬停, 卡, 前缀)

## ★ RT-3b：单机牌（`专属卡N` / `公有卡N` / `单机卡按钮`）的悬停说明口径。
##   旧手牌那套写的是「耗气 / 冷却 / 触发条件 / 效果说明」（`card_hover_text` 的旧版式），
##   单机牌走的是 `hand_card_item._单机卡悬停()`：`【区】名 / 战意消耗 / 归属 / 描述 / 现在：…`。
func _单机牌断言(t, 悬停: HoverTooltip, 卡: Control, 前缀: String) -> void:
	var 文 := _提示文(卡)
	t.ok(not 文.strip_edges().is_empty(), "★ %s 的 `tooltip_text` 非空" % 前缀)
	t.ok(文.contains("战意消耗"), "★ %s 的 tooltip 写清了战意消耗（%s）" % [前缀, 文.split("\n")[0]])
	t.ok(文.contains("现在："), "★ %s 的 tooltip 写了「现在：能打 / 打不了」（%s）"
		% [前缀, 文.split("\n")[文.split("\n").size() - 1]])
	t.ok(文.contains("（") and 文.contains("）"), "★ %s 的 tooltip 在括号里给出了原因原文" % 前缀)
	t.ok(文.split("\n").size() >= 3, "★ %s 的 tooltip 是多行说明（%d 行）" % [前缀, 文.split("\n").size()])
	_悬停断言(t, 悬停, 卡, 前缀)

func _牌文断言(t, 文: String, 前缀: String) -> void:
	t.ok(not 文.strip_edges().is_empty(), "★ %s 的 `tooltip_text` 非空" % 前缀)
	for 片段 in ["耗气", "冷却", "触发条件", "效果说明"]:
		t.ok(文.contains(片段), "★ %s 的 tooltip 含「%s」" % [前缀, 片段])

# 段 4：★ 2026-10-16 作者试玩反馈的四个修复（永久门禁）
#   ① 战斗还没分出胜负时点「结束并结算」→ **自动打完**并切到 result 屏（从前按钮被置灰、点了没反应）；
#   ② 选完分队点「开这一局」→ 立刻弹【招募】；招募 / 放弃此券 / 三选一 / 回招募 / 去编队 闭环走通；
#   ③ Mouse Over 面板在**鼠标右边**（给定 mp 时断言位置），贴右边缘时翻到左侧。

func _位号到键(s: GameSession, 方: String) -> Dictionary:
	var out := {}
	if s == null or s.battle_ctx.is_empty():
		return out
	var 池: Variant = s.battle_ctx.get("allies") if 方 == "ally" else s.battle_ctx.get("enemies")
	if not (池 is Array):
		return out
	for x in (池 as Array):
		if x is Dictionary:
			out[int(float((x as Dictionary).get("slot", -1.0)))] = str((x as Dictionary).get("key", ""))
	return out

# ★ RT-3b：原「段 10 ★ UX-2 发牌来源 / 悬停联动」整段删除（14 条断言）—— 它测的全都长在旧手牌链路上：
#   ① 手牌卡面上的 `【来自：…】` 标签（`hand_card_item` 的旧手牌卡已删，`专属卡N` / `公有卡N` 不写来源）；
#   ② 候补牌上的 `候补来源*` 角标（`reserve_preview()` 恒空）；
#   ③ 手牌栏顶部的「【新发牌】获得战术牌…」提示条与 `新发牌角标`（闸门 G 起内核不再发 `发牌` 事件，
#      `_手牌快照()` 又恒空 → 永远没有「本拍新发牌」）；
#   ④ 悬停联动高亮（`_悬停来源()` / `联动高亮中()`）只在旧手牌卡上绑了钩子；
#   ⑤ 最后那条夹具 `Btl.候补补位()`（API 已删，编不过）。
#   同一条缺口记在回执「发牌动画缺口：本单不做新动画」那一节。
