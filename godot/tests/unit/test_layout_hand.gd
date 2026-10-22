## 职责：版面门禁：手牌（段 12 DECK-2/DECK-3 单机牌组战斗屏：点选机体 / 战意条 / 上下双排 / 即时演出 / 意图预告）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起12: int = t.passes + t.fails
	await _段12_单机牌组战斗屏(t, 根)
	var 段12: int = t.passes + t.fails - 起12
	t.info("★ 版面门禁（本套）：段 12（DECK-2/DECK-3 单机牌组战斗屏）%d 项 · 合计 %d 项" % [段12, 段12])

func _段12_单机牌组战斗屏(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 12：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ★ 界面入口（`menu_view` 的【快速测试战斗】）就是 `开始快速测试战斗(秘银)`。
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261020):
		t.ok(false, "★ 段 12：单机牌组快速战斗开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "★ 段 12：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var v: BattleView = bv
	# ---------- ① 内核开关 / 默认选中 ----------
	var 首台 := _单机存活键(s, 0)
	t.ok(not s.selected_unit_id.is_empty() and s.selected_unit_id == 首台,
		"★ 段 12 ①：开战自动选中「格位 0 起第一台存活的我方」= %s（实际 %s）" % [首台, s.selected_unit_id])
	var 上 := s.upper_hand_cards()
	var 下 := s.lower_hand_cards()
	t.ok(not 上.is_empty(), "★ 段 12 ①：选中机体 %s 的上排专属牌 %d 张" % [s.selected_unit_id, 上.size()])
	var 区们: Array = 上.map(func(c): return str((c as Dictionary).get("区", "")))
	t.ok(区们.has("主武器卡"),
		"★ 段 12 ①：上排左区有【主武器卡】（%s）" % str(区们))
	t.ok(下.size() == (s.battle_ctx.get("公有手牌") as Array).size(),
		"★ 段 12 ①：下排 %d 张 = 内核 `ctx.公有手牌` %d 张" % [下.size(), (s.battle_ctx.get("公有手牌") as Array).size()])
	# ---------- ② 双排节点与「上排在下排上面」 ----------
	t.ok(v._专属排 != null and v._公有排 != null and v._专属排.visible and v._公有排.visible,
		"★★ 段 12 ②：单机牌组模式下上下双排**都露出来了**（专属排 / 公有排）")
	var 上可打: Array = 上.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	var 下可打: Array = 下.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	t.ok(v.手牌卡控件们(true).size() == 上可打.size() and v.手牌卡控件们(false).size() == 下可打.size(),
		"★★ 段 12 ② ★ 铁律：手牌栏**只放能打的牌**（上排 %d/%d · 下排 %d/%d）"
		% [v.手牌卡控件们(true).size(), 上.size(), v.手牌卡控件们(false).size(), 下.size()])
	var 上框: Rect2 = v._专属排.get_global_rect()
	var 下框: Rect2 = v._公有排.get_global_rect()
	t.ok(上框.size.y > 0.0 and 下框.size.y > 0.0 and 上框.end.y <= 下框.position.y + 0.5,
		"★★ 段 12 ②：上排 %s 在下排 %s 上面（不叠、不串行）" % [_短(上框), _短(下框)])
	t.ok(str(v._专属排标题.text).contains("战意") and str(v._专属排标题.text).contains("专属排"),
		"★★ 段 12 ②：上排标题写明「当前选中机体 + 战意 N/100 + 专属排」：%s" % str(v._专属排标题.text))
	t.ok(str(v._公有排标题.text).contains("公有牌"),
		"★★ 段 12 ② ★ 四类分区：下排标题写明【公有牌】：%s" % str(v._公有排标题.text))
	t.ok(str(v._专属排标题.text).contains("主武器牌") and str(v._专属排标题.text).contains("副武器牌")
		and str(v._专属排标题.text).contains("精神牌"),
		"★★ 段 12 ② ★ 四类分区：上排标题写明【主武器牌】/【副武器牌】/【精神牌】：%s" % str(v._专属排标题.text))
	t.ok(str(v._手牌标题.text).contains("阶段") and str(v._手牌标题.text).contains("战意"),
		"★ 段 12 ②：手牌栏顶行写清「第 N 回合 · 阶段 · 选中机体 · 战意」：%s" % str(v._手牌标题.text))
	# ---------- ③ 单位卡：战意条 + 主武状态 + 选中外框 ----------
	var 卡 := _单机卡By键(v, s.selected_unit_id)
	t.ok(卡 != null, "★ 段 12 ③：找到选中机体的 `UnitCard`（%s）" % s.selected_unit_id)
	if 卡 != null:
		t.ok(卡.选中中(), "★★ 段 12 ③：被选中的机体卡是**选中态**（金色醒目外框）")
		t.ok(卡._战意行 != null and 卡._战意行.visible and str(卡._战意文.text).begins_with("战意"),
			"★★ 段 12 ③：机体卡上显示「%s」（战意 N / 100 + 进度条）" % str(卡._战意文.text))
		t.ok(卡._战意条 != null and 卡._战意条.max_value > 0.0,
			"★★ 段 12 ③：战意进度条在（max = %.0f）" % (卡._战意条.max_value if 卡._战意条 != null else 0.0))
		t.ok(卡._主武标 != null and 卡._主武标.visible and str(卡._主武标.text) == "〔主武就绪〕",
			"★★ 段 12 ③：本回合主武状态标着「%s」" % str(卡._主武标.text))
	# ---------- ④ 打一张主武器卡 → 立刻播 0.5 秒一步的演出 ----------
	var 可打 := {}
	for c in 上:
		if bool((c as Dictionary).get("可打", false)) and str((c as Dictionary).get("区", "")) == "主武器卡":
			可打 = c
			break
	t.ok(not 可打.is_empty(), "★ 段 12 ④：选中机体有一张现在就能打的【主武器卡】")
	if not 可打.is_empty():
		var 战意前 := float(Btl.战意(s._选中单位()))
		var 别台前 := _别台战意(s, s.selected_unit_id)
		var 前日志 := s.battle_log_entries(0).size()
		t.ok(float(BattleView.STEP_DURATION) >= 0.45,
			"★★ 段 12 ④：单步演出时长 %.2f 秒（规格 0.5 秒/步，红线 >= 0.45）" % float(BattleView.STEP_DURATION))
		v._点单机卡("主武器卡", str(可打.get("手牌键", "")), true)
		await _等帧(1)
		t.ok(v.演出帧数() >= 1 and v.已播帧数() >= v.演出帧数(),
			"★★ 段 12 ④：打出一张牌**立刻**拆出 %d 帧并播完（已播 %d）—— 不是攒到下一回合" % [v.演出帧数(), v.已播帧数()])
		t.ok(s.battle_log_entries(0).size() > 前日志,
			"★★ 段 12 ④：这一下真的写进了战斗日志（%d → %d 条）" % [前日志, s.battle_log_entries(0).size()])
		t.ok(str(v.播报文本()).length() > 0, "★ 段 12 ④：播报条写出了这一下（%s）" % str(v.播报文本()).substr(0, 40))
		var 战意后 := float(Btl.战意(s._选中单位()))
		var 费 := float(可打.get("战意", 0.0))
		t.ok(absf(float(s.last.get("战意前", -1.0)) - 战意前) < 0.001 and absf(float(s.last.get("战意后", -2.0)) - 战意后) < 0.001,
			"★★ 段 12 ④：门面记的账与内核一致（战意 %.0f → %.0f，这张牌费 %.0f）" % [战意前, 战意后, 费])
		t.ok(absf(_别台战意(s, s.selected_unit_id) - 别台前) < 0.001,
			"★★ 段 12 ④：**谁打牌扣谁的战意** —— 别的机体战意一分没动（%.0f → %.0f）"
			% [别台前, _别台战意(s, s.selected_unit_id)])
		# 主武器卡互毁 → 同一张卡变灰、状态标变「已打主武」
		卡 = _单机卡By键(v, s.selected_unit_id)
		if 卡 != null:
			t.ok(str(卡._主武标.text) == "〔已打主武〕",
				"★★ 段 12 ④：打完主武器卡 → 机体卡状态标变成「%s」" % str(卡._主武标.text))
	# ---------- ⑤ 点选另一台机体 → 上排整排切换 ----------
	var 二台 := _单机存活键(s, 1)
	if not 二台.is_empty():
		var 上排前: Array = s.upper_hand_cards().map(func(c): return str((c as Dictionary).get("名", "")))
		v._点选机体(二台)
		await _等帧(1)
		t.ok(s.selected_unit_id == 二台, "★★ 段 12 ⑤：点另一台机体卡 → 选中换成 %s" % 二台)
		var 上排后: Array = s.upper_hand_cards().map(func(c): return str((c as Dictionary).get("名", "")))
		t.ok(上排后 != 上排前, "★★ 段 12 ⑤：上排专属牌**整排换掉**（%s → %s）" % [str(上排前), str(上排后)])
		var 上排后可打: int = s.upper_hand_cards().filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false))).size()
		t.ok(v.手牌卡控件们(true).size() == 上排后可打,
			"★★ 段 12 ⑤：上排卡行跟着重画成 %d 张（= 新机体「能打」的 %d 张）" % [v.手牌卡控件们(true).size(), 上排后可打])
		t.ok(str(v._专属排标题.text).contains(二台) or str(v._专属排标题.text).contains(str(s._选中单位().get("name", ""))),
			"★★ 段 12 ⑤：上排标题跟着换成新机体：%s" % str(v._专属排标题.text))
		var 卡新 := _单机卡By键(v, 二台)
		var 卡旧 := _单机卡By键(v, 首台)
		t.ok(卡新 != null and 卡新.选中中() and (卡旧 == null or not 卡旧.选中中()),
			"★★ 段 12 ⑤：金色选中框**从旧机体挪到新机体**（旧卡仍可点 = 还能打精神牌）")
	# ---------- ⑥ 下排动态身份置灰（沙盒：公有手牌换成两张指定职业牌） ----------
	await _段12b_下排置灰与指挥减费(t, 树根)
	# ---------- ⑦ 敌方意图预告 ----------
	var 敌们 := s.battle_ctx.get("enemies") as Array
	var 意 := s.enemy_intents()
	t.ok(意.size() == Units.livingOf("enemy", s.battle_ctx).size(),
		"★★ 段 12 ⑦：敌方意图 %d 条 = 存活敌机 %d 台（按格位 0..7 排好）" % [意.size(), Units.livingOf("enemy", s.battle_ctx).size()])
	var 无压制 := true
	var 有武器 := true
	for 条 in 意:
		if str(条).contains("压制"):
			无压制 = false
		if str((条 as Dictionary).get("武器名", "")).is_empty():
			有武器 = false
	t.ok(无压制, "★★ 段 12 ⑦：意图里**没有任何压制射击标记**（作者 2026-10-17 拍板彻底删除）")
	t.ok(有武器, "★★ 段 12 ⑦：每台敌机的意图都带武器名（`算意图` 的字段）")
	var 敌卡 := _单机敌方卡(v, 意)
	if 敌卡 != null:
		t.ok(str(敌卡._意图行.text).contains("意图："),
			"★★ 段 12 ⑦：敌方 `UnitCard` 的意图行写着「%s」" % str(敌卡._意图行.text).substr(0, 60))
		t.ok(str(敌卡._意图行.text).contains("预计"),
			"★★ 段 12 ⑦：意图预告带「预计」伤害（%s）" % str(敌卡._意图行.text).substr(0, 60))
	var 被瞄准 := 0
	for c in v._我方卡:
		if c is UnitCard and str((c as UnitCard)._意图行.text).contains("被瞄准"):
			被瞄准 += 1
	t.ok(被瞄准 >= 1, "★★ 段 12 ⑦：我方**被瞄准的机体卡**有受威胁提示（%d 台）" % 被瞄准)
	# ---------- ⑧ 结束我方回合 ----------
	t.ok(str(v._推进按钮.text) == "结束我方回合",
		"★★ 段 12 ⑧：控制栏那颗按钮改成「%s」（不再是「推进下一回合」）" % str(v._推进按钮.text))
	t.ok(str(v._自动按钮.text) == "全员自动回合",
		"★★ 段 12 ⑧：保留「%s」按钮" % str(v._自动按钮.text))
	t.ok(str(v._结算按钮.text) == "结束并结算",
		"★★ 段 12 ⑧：保留「%s」（跳过直达结算）" % str(v._结算按钮.text))
	var 回合前 := int(float(s.battle_ctx.get("turn", 1.0)))
	v._下一拍()
	await _等帧(1)
	t.ok(int(float(s.battle_ctx.get("turn", 1.0))) > 回合前,
		"★★ 段 12 ⑧：点「结束我方回合」→ 敌方行动 + 进入下一回合（%d → %d）" % [回合前, int(float(s.battle_ctx.get("turn", 1.0)))])
	t.ok(v.演出帧数() >= 1 and v.已播帧数() >= v.演出帧数(),
		"★★ 段 12 ⑧：这一整回也按 0.5 秒一步演完（%d 帧）" % v.演出帧数())
	# ---------- ⑨ 版面门禁（单机牌组模式下也照旧） ----------
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	var 阵 := _框(boot, "阵型区")
	var 手 := _框(boot, "手牌栏")
	var 报 := _框(boot, "战报栏")
	t.ok(阵.size.y > 0.0 and 手.size.y > 0.0 and 报.size.y > 0.0,
		"★★ 段 12 ⑨：阵型区 / 手牌栏 / 战报栏三块都画出来了")
	t.ok(_在(阵, 可用) and _在(手, 可用) and _在(报, 可用),
		"★★ 段 12 ⑨：三块都在 1280×720 的可用区内（阵 %s / 手 %s / 报 %s）" % [_短(阵), _短(手), _短(报)])
	t.ok(not _叠(阵, 手) and not _叠(阵, 报) and not _叠(手, 报),
		"★★ 段 12 ⑨：三块两两互不重叠（交面积 %.0f / %.0f / %.0f）" % [_交面积(阵, 手), _交面积(阵, 报), _交面积(手, 报)])
	t.ok(_在(上框, 手) and _在(下框, 手),
		"★★ 段 12 ⑨：上下双排都装在手牌栏里（上 %s / 下 %s / 手牌栏 %s）" % [_短(上框), _短(下框), _短(手)])
	var 卡框们: Array = []
	for c in v.find_children("*", "UnitCard", true, false):
		卡框们.append((c as Control).get_global_rect())
	var 叠了 := 0
	for i in 卡框们.size():
		for j in range(i + 1, 卡框们.size()):
			if _叠(卡框们[i], 卡框们[j]):
				叠了 += 1
	t.ok(卡框们.size() == int(Fm.SLOTS()) * 2 and 叠了 == 0,
		"★★ 段 12 ⑨：%d 张单位卡两两互不重叠（重叠对数 = %d）" % [卡框们.size(), 叠了])
	# ---------- ⑩ 「结束并结算」在单机牌组模式下也走得通 ----------
	t.ok(bool(s.in_battle()), "★ 段 12 ⑩：此时还在战斗里（%d 回合）" % int(float(s.battle_ctx.get("turn", 1.0))))
	v._点结算()
	await _等帧(2)
	t.ok(s.screen == "result", "★★ 段 12 ⑩：点「结束并结算」→ 屏幕切到结算屏（%s）" % s.screen)
	t.ok(bool(s.result_summary().get("有结果", false)),
		"★★ 段 12 ⑩：结算屏拿得到结果（%s / 回合 %d）"
		% [str(s.result_summary().get("结果", "")), int(s.result_summary().get("回合数", 0))])
	# ---------- ⑪ 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 12 ⑪：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆boot(树根, 舱)
	# ---------- ⑫ 界面入口（菜单那颗按钮）真的把单机牌组打开 ----------
	await _段12c_界面入口(t, 树根)

func _段12c_界面入口(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 12c：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	var atx按 := _找按文(boot, "快速测试：ATX 五人")
	t.ok(atx按 != null, "★ 段 12c：主菜单上有【快速测试：ATX 五人】按钮（A7 双入口）")
	var 按 := _找按文(boot, "快速测试：秘银五人")
	t.ok(按 != null, "★ 段 12c：主菜单上有【快速测试：秘银五人】按钮")
	if 按 == null:
		_拆boot(树根, 舱)
		return
	按.pressed.emit()
	boot.route()
	await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"★★ 段 12c：点【快速测试：秘银五人】→ 直接进战斗屏（screen = %s）" % s.screen)
	var bv = boot.当前视图()
	if bv is BattleView:
		var v: BattleView = bv
		t.ok(v._专属排 != null and v._专属排.visible and v._公有排 != null and v._公有排.visible,
			"★★ 段 12c：战斗屏上真的画出上下双排（专属排 / 公有排都可见）")
		t.ok(str(v._推进按钮.text) == "结束我方回合",
			"★★ 段 12c：控制栏那颗按钮是「%s」" % str(v._推进按钮.text))
		t.ok(v.手牌卡控件们(true).size() == s.upper_hand_cards().filter(
			func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false))).size(),
			"★★ 段 12c：上排画出了 %d 张专属牌（= 门面「能打」的张数）" % v.手牌卡控件们(true).size())
	else:
		t.ok(false, "★ 段 12c：点完之后战斗屏视图类型不对（%s）" % str(bv))
	_拆boot(树根, 舱)

func _段12b_下排置灰与指挥减费(t, 树根: Node) -> void:
	var s := _建单机沙盒()
	if s == null or s.battle_ctx.is_empty():
		t.ok(false, "★ 段 12b：单机牌组沙盒开不起来")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	var 近卫键 := _单机键By职业(s, "近卫")
	var 重装键 := _单机键By职业(s, "重装")
	var 指挥键 := _单机键By职业(s, "指挥")
	t.ok(not 近卫键.is_empty() and not 重装键.is_empty(),
		"★ 段 12b：沙盒里有近卫（%s）与重装（%s）机体" % [近卫键, 重装键])
	if 近卫键.is_empty() or 重装键.is_empty():
		_拆视图(树根, v)
		return
	# ---- 选中近卫：重装牌「不对口」但队里有重装队友 → 由队友发动、真的可打 ----
	v._点选机体(近卫键)
	await _等帧(1)
	var 行近卫 := _单机公有行(s, 近卫键)
	var 重装行 := _有行(行近卫, "重装")
	var 近卫行2 := _有行(行近卫, "近卫")
	t.ok(not 重装行.is_empty() and bool(重装行.get("对口", true)) == false,
		"★★ 段 12b ①：选近卫机 → 归属【重装】的公有牌 `对口 = false`（选中机体确实不对口）")
	t.ok(not 重装行.is_empty() and bool(重装行.get("可打", false)),
		"★★ 段 12b ① ★ M2：队里有重装队友 → 这张【重装】牌**依然可打**（不再因为是「选中的是近卫」而置灰）")
	t.ok(not 重装行.is_empty() and str(重装行.get("原因", "")).begins_with("〔由 "),
		"★★ 段 12b ① ★ M2：卡面写明由谁发动：「%s」" % str(重装行.get("原因", "")))
	t.ok(not 重装行.is_empty() and bool(重装行.get("由队友发动", false))
		and str(重装行.get("发动键", "")) == 重装键,
		"★★ 段 12b ① ★ M2：`发动键` 指回重装队友（%s）" % str(重装行.get("发动键", "")))
	t.ok(not 近卫行2.is_empty() and bool(近卫行2.get("对口", false)),
		"★★ 段 12b ①：选近卫机 → 归属【近卫】的公有牌 `对口 = true`（亮了）")
	# UI 那一半：那张【重装】牌在**手牌栏里**，按钮**可点**，卡面写着「〔由 … 发动〕」
	t.ok(_手牌里有名(v, false, str(重装行.get("名", ""))),
		"★★ 段 12b ① ★ M2：那张【重装】牌真的出现在中下手牌栏里（%s）" % str(重装行.get("名", "")))
	var 重装钮 := _按钮ByName(v, false, str(重装行.get("名", "")))
	t.ok(重装钮 != null and not 重装钮.disabled,
		"★★ 段 12b ① ★ M2：下排那张【重装】牌在界面上**可以点**（自动由重装队友发动）")
	t.ok(_控件含文(v._公有排列表, "〔由 "),
		"★★ 段 12b ① ★ M2：卡面写着「〔由 … 发动〕」")
	# ---- ② 把**对口队友**的战意扣光 → 全队没人打得起 → 这张牌**移出手牌栏、落进左牌库栏** ----
	var 重装台 := _单位Of键(s, 重装键)
	var 重装战意前 := float(Btl.战意(重装台))
	重装台["战意"] = 0.0
	v.refresh()                      # 卡行是上一次渲染画的 —— 改完战意要重画一次才看得到
	await _等帧(1)
	var 行近卫2 := _单机公有行(s, 近卫键)
	var 重装行2 := _有行(行近卫2, "重装")
	t.ok(not 重装行2.is_empty() and bool(重装行2.get("可打", true)) == false,
		"★★ 段 12b ② ★ M2：对口队友战意扣光 → 【重装】牌**变成不可打**（%s）" % str(重装行2.get("原因", "")))
	t.ok(not 重装行2.is_empty() and str(重装行2.get("原因", "")).begins_with("〔需：重装〕"),
		"★★ 段 12b ② ★ M2：原因回落到「%s」" % str(重装行2.get("原因", "")))
	t.ok(not _手牌里有名(v, false, str(重装行2.get("名", ""))),
		"★★ 段 12b ② ★ 铁律：打不了的牌**不再留在中下手牌栏**里（%s）" % str(重装行2.get("名", "")))
	t.ok(_左库里有名(v, str(重装行2.get("名", ""))) and _左库有标签(v, "〔暂不可用〕"),
		"★★ 段 12b ② ★ 铁律：它出现在**左侧「未激活 / 冷却牌库」**里，并写明为什么进不了手牌")
	t.ok(_左库按钮全禁用(v), "★★ 段 12b ②：左牌库栏里的卡一律不可点（`disabled == true`）")
	重装台["战意"] = 重装战意前
	# ---- ③ 恢复战意 → 同一张牌**自动回到手牌栏**且可点 ----
	v.refresh()
	await _等帧(1)
	t.ok(_手牌里有名(v, false, str(重装行2.get("名", ""))),
		"★★ 段 12b ③ ★ 铁律：战意恢复 → 那张牌**自动回到中下手牌栏**（下一回合 CD 归零 / 条件满足时同一口径）")
	var 重装钮3 := _按钮ByName(v, false, str(重装行2.get("名", "")))
	t.ok(重装钮3 != null and not 重装钮3.disabled,
		"★★ 段 12b ③：回到手牌栏之后按钮**可点**")
	# ---- ③b 切到重装机：同一张牌 `对口 = true`；近卫那张改成「由近卫队友发动」 ----
	v._点选机体(重装键)
	await _等帧(1)
	var 行重装 := _单机公有行(s, 重装键)
	t.ok(bool(_有行(行重装, "重装").get("对口", false)),
		"★★ 段 12b ③：切到重装机 → 同一张【重装】牌 `对口 = true`（亮了）")
	t.ok(bool(_有行(行重装, "近卫").get("对口", true)) == false,
		"★★ 段 12b ③：切到重装机 → 【近卫】牌 `对口 = false`")
	t.ok(bool(_有行(行重装, "近卫").get("可打", false)),
		"★★ 段 12b ③ ★ M2：但队里有近卫队友 → 【近卫】牌仍可打（`对口` 只描述「选中机体对不对口」）")
	# ---- 指挥机：公有牌折后价 -5（★ M2：折后价按**实际发动者**算，所以用统帅牌 —— 谁都打得出，
	#      选中的指挥机就是它的发动者）----
	if not 指挥键.is_empty():
		v._点选机体(指挥键)
		await _等帧(1)
		var 行指挥 := _单机公有行(s, 指挥键)
		var 统帅行 := _有行(行指挥, "统帅")
		t.ok(not 统帅行.is_empty() and str(统帅行.get("发动键", "")) == 指挥键,
			"★★ 段 12b：选中指挥机 → 统帅牌的发动者就是它自己（%s）" % str(统帅行.get("发动键", "")))
		t.ok(float(统帅行.get("减费", 0.0)) == Params.指挥公有减费(),
			"★★ 段 12b：选中指挥机 → 公有牌显示战意消耗 -%d（折后价，费 %s / 原 %s）" % [
				int(Params.指挥公有减费()), J.s(统帅行.get("费")), J.s(统帅行.get("原费"))])
		t.ok(_控件含文(v._公有排列表, "指挥 -"),
			"★★ 段 12b：下排卡面写清这笔折扣（「指挥 -5」）")
	_拆视图(树根, v)
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★ 段 12b：沙盒全程零报错 %s" % str(s.errors))

func _建单机沙盒() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段12.json"
	var ctx := Setup.开局(默认五人, 秘银敌方, 20261020, null, {"单机牌组": true})
	if ctx.is_empty():
		return s
	for u in (ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 100.0
	ctx.公有手牌 = []
	for 归 in ["重装", "近卫"]:
		var 牌 := _单机找职业牌(归)
		if not 牌.is_empty():
			ctx.公有手牌.append(Btl.克隆战术牌(牌, ctx))
	var 统帅牌 := _单机找统帅牌()
	if not 统帅牌.is_empty():
		ctx.公有手牌.append(Btl.克隆战术牌(统帅牌, ctx))
	s.battle_ctx = ctx
	s.screen = "battle"
	if s.battle_ctx.is_empty():
		return s
	s.select_battle_unit(_单机存活键(s, 0))
	s.clear_errors()
	return s

## 数据表里找一张 `层级 = 统帅` 的公有牌（找不到 = 空字典）。
func _单机找统帅牌() -> Dictionary:
	var 表: Variant = Db.T.get("战术卡牌表")
	if not (表 is Array):
		return {}
	for c in (表 as Array):
		if c is Dictionary and str((c as Dictionary).get("层级", "")) == "统帅":
			return c
	return {}

func _单机找职业牌(归: String) -> Dictionary:
	var 表: Variant = Db.T.get("战术卡牌表")
	if not (表 is Array):
		return {}
	for c in (表 as Array):
		if c is Dictionary and str((c as Dictionary).get("层级", "")) == "职业" \
			and str((c as Dictionary).get("归属", "")) == 归:
			return c
	return {}

## 我方第一台 `职业 == 职业` 的存活机体键。
func _单机键By职业(s: GameSession, 职业: String) -> String:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 \
			and str(Units.unit_class(u, s.battle_ctx)) == 职业:
			return str((u as Dictionary).get("key", ""))
	return ""

## 视图里「键 == 键」的那张我方 `UnitCard`。
func _单机卡By键(v: BattleView, 键: String) -> UnitCard:
	for c in v._我方卡:
		if c is UnitCard:
			var 卡: UnitCard = c
			if str(卡.数据.get("键", "")) == 键:
				return 卡
	return null

## 视图里第一张「有意图预告」的敌方 `UnitCard`。
func _单机敌方卡(v: BattleView, 意: Array) -> UnitCard:
	var 键 := ""
	if not 意.is_empty() and 意[0] is Dictionary:
		键 = str((意[0] as Dictionary).get("单位", ""))
	for c in v._敌方卡:
		if c is UnitCard:
			var 卡: UnitCard = c
			if not 键.is_empty() and str(卡.数据.get("键", "")) == 键:
				return 卡
	for c in v._敌方卡:
		if c is UnitCard and not str((c as UnitCard)._意图行.text).is_empty():
			return c
	return null

## `lower_hand_cards(键)` 里「归属 == 归」的那一行（没有 = 空字典）。
func _有行(行们: Array, 归: String) -> Dictionary:
	for x in 行们:
		if x is Dictionary and str((x as Dictionary).get("归属", "")) == 归:
			return x
	return {}

## `lower_hand_cards()` 里「归属 == 归」那一行的下标（没有 = −1）。
func _行序号(行们: Array, 归: String) -> int:
	for i in 行们.size():
		var x: Variant = 行们[i]
		if x is Dictionary and str((x as Dictionary).get("归属", "")) == 归:
			return i
	return -1

func _单机公有行(s: GameSession, 键: String) -> Array:
	return s.lower_hand_cards(键)

func _分区标数(v: BattleView, 上排: bool) -> int:
	var 列: Node = v._专属排列表 if 上排 else v._公有排列表
	if 列 == null:
		return 0
	var 数 := 0
	for c in 列.get_children():
		if c is Label and str((c as Node).name) == "分组标":
			数 += 1
	return 数

## 中下手牌栏里有没有这张牌（按门面 `名`）。
func _手牌里有名(v: BattleView, 上排: bool, 名: String) -> bool:
	if 名.is_empty():
		return false
	for 卡 in v.手牌卡控件们(上排):
		var d = (卡 as Node).get_meta("unit_card_data")
		if d is Dictionary and str((d as Dictionary).get("名", "")) == 名:
			return true
	return false

## 中下手牌栏里那张牌的按钮（按门面 `名` 找；找不到 = null）。
func _按钮ByName(v: BattleView, 上排: bool, 名: String) -> Button:
	if 名.is_empty():
		return null
	for 卡 in v.手牌卡控件们(上排):
		var d = (卡 as Node).get_meta("unit_card_data")
		if d is Dictionary and str((d as Dictionary).get("名", "")) == 名:
			return (卡 as Node).find_child("单机卡按钮", true, false) as Button
	return null

func _左库里有名(v: BattleView, 名: String) -> bool:
	if 名.is_empty():
		return false
	for c in v.左库卡控件们():
		var e = (c as Node).get_meta("left_library_entry")
		if e is Dictionary and str((e as Dictionary).get("名", "")) == 名:
			return true
	return false

## ★ 2026-10-21：单机手牌栏里 `【主武器牌】` 这类**分区标题**不是卡；
func _单机卡按钮(v: BattleView, 上排: bool, 序号: int) -> Button:
	var 卡们: Array = v.手牌卡控件们(上排)
	if 序号 < 0 or 序号 >= 卡们.size():
		return null
	return (卡们[序号] as Node).find_child("单机卡按钮", true, false) as Button

func _单机卡按钮Old(列表: Node, 序号: int) -> Button:
	if 列表 == null or 序号 < 0 or 序号 >= 列表.get_child_count():
		return null
	return 列表.get_child(序号).find_child("单机卡按钮", true, false) as Button

func _别台战意(s: GameSession, 键: String) -> float:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 \
			and str((u as Dictionary).get("key", "")) != 键:
			return float(Btl.战意(u))
	return 0.0

const 默认五人 := [
	{"键": "B1", "位": 0, "等级": 10}, {"键": "B2", "位": 1, "等级": 10},
	{"键": "CB4", "位": 2, "等级": 10}, {"键": "CB2", "位": 6, "等级": 10},
	{"键": "M1", "位": 4, "等级": 10},
]

# 段 13：★ 武器卡「按住拖动 → 松手落在目标机体卡上」+ 拥有者→目标瞄准连线（作者 2026-10-20 要求）
#
#   钉的是一整条交互链：
#     ① 可拖拽判据（主武器卡 / 衍生攻击卡 / 公有攻击衍生卡 可以；精神牌、铁壁、打不出来的不行）；
#     ② 移动超过 8px 才进瞄准 —— 原地按一下**不**画线（松手仍走点击那条自动选目标的路）；
#     ③ 瞄准连线：**起点 = 武器拥有者（当前选中机体）的 `UnitCard` 中心**，
#        终点 = 鼠标位置；鼠标落在存活目标 `UnitCard` 上 → 吸附到那张卡中心 + 高亮它；
#        颜色区分攻击橙红 / 维修翠绿；线画在特效画布（`战斗动画层`）上；
#     ④ 松手在目标卡上 → 把那张卡的 `键` 当 `target_id` 传给门面 → **伤害当场落在指定的那台**；
#     ⑤ 松手在空白处 → 取消（不误出牌）；
#     ⑥ 双排手牌悬停 → 高亮拥有者机体卡（作者顺手要补齐的那一项）。
#
#   ★ 数据纪律：只调视图自己的接口 + 读门面的数，不在测试里另立第二套判据。
