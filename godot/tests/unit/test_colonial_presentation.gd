## ★ COL-4b（施工单 §2 COL-4）：表现层接线 —— QTE 手动弹窗 / 感应牌金边 / 觉醒徽章配色 / 感应牌库面板。
## 纪律：`extends RefCounted` + `func run(t)`，放 `tests/unit/` 顶层自动发现；Control 真挂进 headless 根节点，用完 free()。
extends RefCounted

func run(t) -> void:
	var 错误 := []
	DataLoader.install(错误)
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_colonial_presentation.json"
	t.ok(s.开始快速测试战斗_殖民卫星军(20261013),
		"★ 殖民卫星军快速测试开起来了（screen = %s）" % s.screen)
	if s.battle_ctx.is_empty():
		t.ok(false, "battle_ctx 是空的 → 表现层断言跑不了")
		return
	var bv := BattleView.new()
	_根().add_child(bv)
	bv.setup(s)
	bv.refresh()
	_段1_金边(t, s, bv)
	_段2_徽章配色(t, s)
	_段3_感应牌库面板(t, s, bv)
	_段4_QTE手动弹窗(t, s, bv)
	_段5_顶栏QTE模式键(t, s)
	_根().remove_child(bv)
	bv.free()

# ---- 段 1：未觉醒成员手里的【觉醒感应】牌亮金边（判据接到了卡控件上） ----
func _段1_金边(t, s: GameSession, bv: BattleView) -> void:
	t.ok(s.select_battle_unit("W2").get("ok", false), "段 1：选中迪奥（W2，还没觉醒）")
	bv.refresh()
	var 带感应 := s.upper_hand_cards().filter(func(c): return c is Dictionary and bool((c as Dictionary).get("觉醒感应", false)))
	t.ok(not 带感应.is_empty(), "段 1：迪奥上排有 %d 张带【觉醒感应】的牌" % 带感应.size())
	var 亮 := 带感应.filter(func(c): return bool((c as Dictionary).get("亮金边", false)))
	t.ok(not 亮.is_empty(), "段 1：未觉醒 → 门面给这些牌亮金边（亮 %d / 带感应 %d）" % [亮.size(), 带感应.size()])
	# ① 打不出来的那些躺在左牌库：左库卡也要金边（觉醒大招就在这儿等觉醒）。
	var 左亮 := false
	for 卡 in bv.左库卡控件们():
		var e: Variant = (卡 as Node).get_meta("left_library_entry")
		if not (e is Dictionary) or not bool((e as Dictionary).get("亮金边", false)):
			continue
		var 样 := (卡 as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if 样 != null and 样.border_color.is_equal_approx(UiTheme.金边) and 样.border_width_left >= 2:
			左亮 = true
			break
	t.ok(左亮, "★ 段 1：左牌库里那张【觉醒感应】大招亮着金边（2px）")
	# ② 可打的那种（精神牌）画在手牌栏里：手牌控件也要金边。把一张从专属牌库挪进手牌。
	var 迪 := _我方单位(s, "W2")
	var 挪 := {}
	for c in 迪.get("专属牌库") if 迪.get("专属牌库") is Array else []:
		if c is Dictionary and str((c as Dictionary).get("id", "")) == "COL_W2_SP1":
			挪 = c
	if 挪.is_empty():
		t.ok(false, "段 1：迪奥的专属牌库里找不到【逃跑和躲藏是我的特长】（夹具失效）")
		return
	(迪["专属牌库"] as Array).erase(挪)
	(迪["专属手牌"] as Array).append(挪)
	bv.refresh()
	var 手亮 := 0
	for c in s.upper_hand_cards():
		if c is Dictionary and str((c as Dictionary).get("id", "")) == "COL_W2_SP1":
			t.ok(bool(c.get("可打", false)) and bool(c.get("亮金边", false)),
				"段 1：抽到手里的【%s】能打、且亮金边" % str(c.get("名", "")))
	var 目标键 := "COL_W2_SP1"
	var 卡控件 := {}
	for 卡 in bv.手牌卡控件们(true):
		var d: Variant = (卡 as Node).get_meta("unit_card_data")
		if d is Dictionary and str((d as Dictionary).get("手牌键", "")) == 目标键:
			卡控件 = {"卡": 卡, "数据": d}
	if 卡控件.is_empty():
		t.ok(false, "段 1：手牌栏里找不到这张牌的控件")
		return
	var 样2 := (卡控件["卡"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	t.ok(样2 != null and 样2.border_color.is_equal_approx(UiTheme.金边) and 样2.border_width_left >= 2,
		"★ 段 1：手牌控件边框是金边（色 = %s · 宽 %d）" % [str(样2.border_color if 样2 != null else Color.BLACK), int(样2.border_width_left if 样2 != null else 0)])
	t.ok(bool(卡控件["卡"].get_meta("gold_edge", false)), "段 1：手牌控件上挂了「gold_edge」meta（自动化可查）")
	# ③ 觉醒之后 → 同一张不再亮金边。
	迪["觉醒中"] = true
	迪["觉醒类型"] = "隐身"
	bv.refresh()
	var 后亮度 := 0
	for c in s.upper_hand_cards() + bv._左库条目们():
		if c is Dictionary and bool((c as Dictionary).get("亮金边", false)):
			后亮度 += 1
	t.ok(后亮度 == 0, "★ 段 1：迪奥进入隐身之后，同一批【觉醒感应】牌不再亮金边（亮 %d 张）" % 后亮度)
	迪["觉醒中"] = false
	迪["觉醒类型"] = ""

# ---- 段 2：觉醒徽章配色（SEED 蓝 / ZERO 绿 / 隐身半透明） ----
func _段2_徽章配色(t, s: GameSession) -> void:
	var 期望 := [["SEED", UiTheme.觉醒色_SEED, "蓝"], ["ZERO", UiTheme.觉醒色_ZERO, "绿"], ["隐身", UiTheme.觉醒色_隐身, "半透明"]]
	for 项 in 期望:
		var 型 := str(项[0])
		var 卡 := UnitCard.new()
		_根().add_child(卡)
		卡.setup({"ok": true, "名": "配色测试", "位名": "前1", "等级": 30, "职业": "射击", "势力": "殖民卫星军",
			"活着": true, "HP": 100.0, "最大HP": 100.0, "血比": 1.0,
			"状态": ["〔觉醒中·%s〕" % 型], "觉醒类型": 型})
		var 行 = 卡.find_child("状态行", true, false)
		var 色: Color = (行 as Label).get_theme_color("font_color") if 行 is Label else Color.BLACK
		var 好 := 行 is Label and 色.is_equal_approx(项[1])
		if 型 == "隐身":
			好 = 好 and 色.a < 0.8
		t.ok(好, "★ 段 2：〔觉醒中·%s〕的徽章字色 = %s（%s）" % [型, str(项[2]), str(色)])
		_根().remove_child(卡)
		卡.free()
	# 门面那条链：`unit_view` 真的把「现在在觉醒中的类型」带出来。
	var 迪 := _我方单位(s, "W2")
	迪["觉醒中"] = true
	迪["觉醒类型"] = "隐身"
	var 图 := s.unit_view("ally", "W2")
	t.ok(str(图.get("觉醒类型", "")) == "隐身", "★ 段 2：unit_view 带出觉醒类型（%s）" % str(图.get("觉醒类型", "")))
	迪["觉醒中"] = false
	迪["觉醒类型"] = ""
	t.ok(str(s.unit_view("ally", "W2").get("觉醒类型", "")) == "", "段 2：没觉醒时 unit_view 不带觉醒类型")

# ---- 段 3：左栏「查看感应牌库」→ 面板逐张列出库内牌 ----
func _段3_感应牌库面板(t, s: GameSession, bv: BattleView) -> void:
	bv.refresh()
	var 态 := s.感应牌库状态()
	t.ok(bool(态.get("有", false)) and (态.get("明细") as Array).size() > 0,
		"★ 段 3：这一场装了感应牌库（库内 %d 张）" % (态.get("明细") as Array).size())
	var 钮 = bv.find_child("感应牌库按钮", true, false)
	t.ok(钮 is Button and (钮 as Button).visible, "★ 段 3：左栏那颗「查看感应牌库」按钮露出来了")
	bv.开感应牌库面板()
	t.ok(bv.感应面板显示中(), "段 3：点开之后面板是显示的")
	var 行数 := bv.find_children("感应牌库行*", "", true, false).size()
	t.ok(行数 == (态.get("明细") as Array).size(),
		"★ 段 3：面板里逐张列出了库内的 %d 张牌" % 行数)
	var 题 = bv.find_child("感应面板标题", true, false)
	t.ok(题 is Label and str((题 as Label).text).contains("一级"),
		"段 3：面板标题写了各级张数（%s）" % (str((题 as Label).text) if 题 != null else "—"))
	bv.关感应牌库面板()
	t.ok(not bv.感应面板显示中(), "段 3：关掉之后面板收起")

# ---- 段 4：manual 模式下大招先等选择，选「完美」之后才结算 ----
func _段4_QTE手动弹窗(t, s: GameSession, bv: BattleView) -> void:
	var 拉 := _我方单位(s, "S1")
	拉["觉醒中"] = true
	拉["觉醒类型"] = "SEED"
	拉["战意"] = 100.0
	s.battle_ctx["turn"] = 3.0
	for 槽 in 拉.get("大招槽") if 拉.get("大招槽") is Array else []:
		if 槽 is Dictionary:
			槽["cd"] = 0.0
			槽["本回合已打"] = false
	t.ok(s.select_battle_unit("S1").get("ok", false), "段 4：选中拉克丝（S1，已开 SEED）")
	s.set_qte_mode("manual")
	bv.refresh()
	var 键 := ""
	var 牌名 := ""
	for c in s.upper_hand_cards():
		if c is Dictionary and str((c as Dictionary).get("区", "")) == GameSession.单机区_大招槽 \
			and bool((c as Dictionary).get("可打", false)) and bool((c as Dictionary).get("QTE", false)):
			键 = str((c as Dictionary).get("手牌键", ""))
			牌名 = str((c as Dictionary).get("名", ""))
			break
	t.ok(not 键.is_empty(), "★ 段 4：门面认得出这一张是「要选 QTE 的武器型觉醒大招」（%s）" % 牌名)
	if 键.is_empty():
		return
	var 战意前 := float(拉.get("战意", 0.0))
	var 日志前 := s.battle_log_entries(0).size()
	var r := bv._打单机卡(GameSession.单机区_大招槽, 键, true, "")
	t.ok(bool(r.get("等待QTE", false)) and bv.QTE弹窗显示中(),
		"★ 段 4：manual 模式下点大招 → **先弹 QTE 弹窗**、这一发还没结算")
	t.ok(absf(float(拉.get("战意", 0.0)) - 战意前) < 0.01 and s.battle_log_entries(0).size() == 日志前,
		"★ 段 4：等选择期间战意 / 战报一个字都没动（战意 %s）" % str(拉.get("战意", 0.0)))
	var 有完美钮 = bv.find_child("QTE完美按钮", true, false)
	t.ok(有完美钮 is Button and (有完美钮 as Button).text == "完美", "段 4：弹窗里有「完美」按钮")
	bv._QTE选("perfect")
	t.ok(not bv.QTE弹窗显示中(), "段 4：选完弹窗收起")
	var 文 := ""
	var 日志: Array = s.battle_log_entries(0)
	for i in range(maxi(0, 日志.size() - 12), 日志.size()):
		文 += str((日志[i] as Dictionary).get("文本", ""))
	t.ok(文.contains("QTE·完美"), "★ 段 4：结算日志里写着「QTE·完美」（%s）" % 文.substr(0, 80))
	t.ok(float(拉.get("QTE闪避加", 0.0)) >= 20.0,
		"★ 段 4：完美档的加成落地了（闪避 +%s）" % str(拉.get("QTE闪避加", 0.0)))
	t.ok(float(拉.get("战意", 0.0)) < 战意前, "段 4：这一发现在真的打了（战意 %s → %s）" % [str(战意前), str(拉.get("战意", 0.0))])

# ---- 段 5：顶栏那颗 QTE 模式键循环切换 ----
func _段5_顶栏QTE模式键(t, s: GameSession) -> void:
	var 顶 := TopBar.new()
	_根().add_child(顶)
	顶.setup(s)
	顶.refresh()
	var 钮 = 顶.find_child("QTE模式按钮", true, false)
	t.ok(钮 is Button and (钮 as Button).disabled == false, "★ 段 5：战斗里顶栏有可点的「QTE模式」按钮")
	if not (钮 is Button):
		_根().remove_child(顶)
		顶.free()
		return
	var 起 := s.get_qte_mode()
	t.ok(str((钮 as Button).text) == "QTE：%s" % GameSession.QTE模式文(起),
		"段 5：按钮文案跟会话模式一致（%s）" % str((钮 as Button).text))
	var 序 := ["manual", "perfect", "good", "miss", "random"]
	var 对 := true
	for i in 序.size():
		顶._点QTE模式()
		if s.get_qte_mode() != str(序[(序.find(起) + i + 1) % 序.size()]):
			对 = false
			break
	t.ok(对, "★ 段 5：点 5 下循环转一圈（%s → … → 回 %s）" % [起, 起])
	t.ok(s.get_qte_mode() == 起, "段 5：循环一圈正好回到原来的模式（%s）" % s.get_qte_mode())
	t.ok(str((钮 as Button).text) == "QTE：%s" % GameSession.QTE模式文(起), "段 5：按钮文案跟着刷新")
	_根().remove_child(顶)
	顶.free()

# ---- 工具 ----
func _我方单位(s: GameSession, 键: String) -> Dictionary:
	for u in s.battle_ctx.get("allies") if s.battle_ctx.get("allies") is Array else []:
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

func _根() -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root if 树 != null else null
