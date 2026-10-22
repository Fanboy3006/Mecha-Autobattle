## 职责：版面门禁：棋盘（段 14 4×4 棋盘与援护连线 / 段 15 敌方前后排按真实 slot 对齐与友方目标选中）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起14: int = t.passes + t.fails
	await _段14_4x4棋盘与援护连线(t, 根)
	var 段14: int = t.passes + t.fails - 起14
	var 起15: int = t.passes + t.fails
	await _段15_敌方前后排与友方目标选中(t, 根)
	var 段15: int = t.passes + t.fails - 起15
	t.info("★ 版面门禁（本套）：段 14（4×4 棋盘与援护连线）%d 项 · 段 15（敌方前后排与友方目标选中）%d 项 · 合计 %d 项" % [段14, 段15, 段14 + 段15])

func _段14_4x4棋盘与援护连线(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 14：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ---------- (a) 艾克赛琳 / 克鲁兹各自只有 1 张【援护射击】 ----------
	if not s.开始快速测试战斗(GameSession.快速测试_ATX, 20261021):
		t.ok(false, "★ 段 14(a)：ATX 五人快速测试开不起来")
		_拆boot(树根, 舱)
		return
	t.ok(_张数ByName(s.upper_hand_cards("A2"), "援护射击") == 1,
		"★★ 段 14(a)：艾克赛琳（A2）上排只有 **1 张**【援护射击】（实际 %d 张）"
		% _张数ByName(s.upper_hand_cards("A2"), "援护射击"))
	var 艾 := _单位Of键(s, "A2")
	t.ok(not 艾.is_empty() and _张数ByName(艾.get("衍生手牌"), "援护射击") == 0,
		"★★ 段 14(a)：她身上**没有**旧版 `D_援护射击` 衍生卡（副武器栏那张才是唯一的一张）")
	t.ok(not 艾.is_empty() and _张数ByName(艾.get("副武器栏"), "援护射击") == 1,
		"★★ 段 14(a)：她的 `副武器栏` 里正好 1 张【援护射击】")
	# 克鲁兹（U6）：换一场秘银五人，同一条口径再验一遍
	if s.开始快速测试战斗(GameSession.快速测试_秘银, 20261021):
		t.ok(_张数ByName(s.upper_hand_cards("U6"), "援护射击") == 1,
			"★★ 段 14(a)：克鲁兹（U6）上排也只有 **1 张**【援护射击】（实际 %d 张）"
			% _张数ByName(s.upper_hand_cards("U6"), "援护射击"))
		var 克 := _单位Of键(s, "U6")
		t.ok(not 克.is_empty() and _张数ByName(克.get("衍生手牌"), "援护射击") == 0,
			"★★ 段 14(a)：克鲁兹身上也没有旧版 `D_援护射击` 衍生卡")
	else:
		t.ok(false, "★ 段 14(a)：秘银五人快速测试开不起来 —— 克鲁兹那一条跑不了")
	# 回到 ATX 五人那场，接着验界面（4×4 棋盘 / 援护连线）
	if not s.开始快速测试战斗(GameSession.快速测试_ATX, 20261021):
		t.ok(false, "★ 段 14：ATX 五人那场重开不起来")
		_拆boot(树根, 舱)
		return
	# ---------- 界面：4×4 棋盘 + 纯可打手牌 + 左牌库 + 援护连线 ----------
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "★ 段 14：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var v: BattleView = bv
	# ---------- (b) 4×4 棋盘：4 行 × 4 列、同列对齐、互不重叠 ----------
	var 排名们 := ["敌方阵型第1排", "敌方阵型第0排", "我方阵型第0排", "我方阵型第1排"]
	var 行框们: Array = []
	var 齐 := true
	for 排名 in 排名们:
		var 排 = v.find_child(str(排名), true, false)
		if 排 == null:
			齐 = false
			t.ok(false, "★ 段 14(b)：战斗屏里找不到「%s」" % str(排名))
			continue
		var 卡框: Array = []
		for c in (排 as Node).get_children():
			if c is UnitCard:
				卡框.append((c as Control).get_global_rect())
		t.ok(卡框.size() == 4, "★★ 段 14(b)：「%s」里有 4 张单位卡（4 列）" % str(排名))
		if 卡框.size() != 4:
			齐 = false
		行框们.append(卡框)
	t.ok(齐 and 行框们.size() == 4, "★★ 段 14(b)：4×4 棋盘 = 4 行 × 4 列")
	if 齐 and 行框们.size() == 4:
		# 同列纵向严格对齐（4 行里第 j 张卡的 x 与宽都一样）
		var 对齐坏 := 0
		for j in 4:
			var 基准: Rect2 = 行框们[0][j]
			for i in range(1, 4):
				var r: Rect2 = 行框们[i][j]
				if absf(r.position.x - 基准.position.x) > 0.8 or absf(r.size.x - 基准.size.x) > 0.8:
					对齐坏 += 1
		t.ok(对齐坏 == 0, "★★ 段 14(b)：4 列纵向严格对齐（不对齐的格数 = %d）" % 对齐坏)
		# 全 16 张两两不重叠
		var 全框: Array = []
		for 行 in 行框们:
			全框.append_array(行)
		var 叠 := 0
		for i in 全框.size():
			for j in range(i + 1, 全框.size()):
				if _叠(全框[i], 全框[j]):
					叠 += 1
		t.ok(全框.size() == 16 and 叠 == 0,
			"★★ 段 14(b)：16 张单位卡两两互不重叠（重叠对数 = %d）" % 叠)
		# 4 行 × 72 = 288 装得进阵型区；4 列 × 148 ≤ 中栏
		var 阵框 := _框(boot, "阵型区")
		var 总高 := 0.0
		for 行 in 行框们:
			总高 += float((行[0] as Rect2).size.y)
		t.ok(总高 <= 阵框.size.y + 0.5, "★★ 段 14(b)：4 行卡高合计 %.0f ≤ 阵型区 %.0f" % [总高, 阵框.size.y])
		var 宽 := float((行框们[0][0] as Rect2).size.x) * 4.0
		t.ok(宽 <= BattleView.中栏宽 + 0.5, "★★ 段 14(b)：4 列卡宽合计 %.0f ≤ 中栏 %.0f" % [宽, BattleView.中栏宽])
	# ---------- (c) 手牌栏全部可打 / 打不了的在左牌库 ----------
	var 手按钮坏 := 0
	for 上排 in [true, false]:
		for c in v.手牌卡控件们(上排):
			var b := (c as Node).find_child("单机卡按钮", true, false) as Button
			if b == null or b.disabled:
				手按钮坏 += 1
	t.ok(手按钮坏 == 0, "★★ 段 14(c)：中下手牌栏（_专属排 + _公有排）所有卡按钮 `disabled == false`（坏 %d 个）"
		% 手按钮坏)
	t.ok(v.左库卡控件们().size() > 0,
		"★★ 段 14(c)：左牌库栏写出了 %d 条「未激活 / 冷却」条目" % v.左库卡控件们().size())
	t.ok(_左库按钮全禁用(v), "★★ 段 14(c)：左牌库栏里的卡一律不可点（`disabled == true`）")
	var 选中 := _单位Of键(s, s.selected_unit_id)
	var 槽们 = 选中.get("大招槽")
	var 造冷 := false
	if 槽们 is Array and not (槽们 as Array).is_empty():
		var 槽: Dictionary = (槽们 as Array)[0]
		槽["cd"] = 3.0
		槽["cd_max"] = 3.0
		造冷 = true
	v.refresh()
	await _等帧(2)
	if 造冷:
		t.ok(_左库有标签(v, "回合后进入手牌"),
			"★★ 段 14(c)：冷却中的牌在左牌库栏写着「〔3 回合后进入手牌〕」")
		t.ok(v._左牌库副标题.text.contains("牌库"),
			"★★ 段 14(c)：左牌库栏顶部写着牌库 / 弃牌 / 待入库张数：%s" % v._左牌库副标题.text)
	# ---------- (d) 靶机只 1 个援护设定 + 援护连线 ----------
	var 敌援护: Array = []
	var 我援护: Array = []
	for l in s.guard_links():
		if not (l is Dictionary):
			continue
		if str((l as Dictionary).get("side", "")) == "enemy":
			敌援护.append(l)
		else:
			我援护.append(l)
	t.ok(敌援护.size() == 1, "★★ 段 14(d)：靶机**只有 1 个**援护设定（实际 %d 条）" % 敌援护.size())
	if 敌援护.size() == 1:
		var 条: Dictionary = 敌援护[0]
		t.ok(str(条.get("from_name", "")).contains("盾卫"),
			"★★ 段 14(d)：那一条是 `盾卫·靶机` 保护同列后排（%s → %s）" % [str(条.get("from_name", "")), str(条.get("to_name", ""))])
		t.ok(int(条.get("remaining", -1)) == 2 and int(条.get("max_count", -1)) == 2
			and str(条.get("label", "")) == "援护 2/2",
			"★★ 段 14(d)：写着「%s」（剩余 %s / 上限 %s）" % [str(条.get("label", "")),
				str(条.get("remaining", -1)), str(条.get("max_count", -1))])
		t.ok(int(条.get("from_slot", -1)) == 0 and int(条.get("to_slot", -1)) == 4,
			"★★ 段 14(d)：援护者在前排 slot 0、被护者在正后方同列 slot 4")
	t.ok(我援护.size() >= 1,
		"★★ 段 14(d)：我方也有援护连线（塔斯克【掩护】等，%d 条）" % 我援护.size())
	var 有掩护标签 := false
	for l in 我援护:
		if str((l as Dictionary).get("label", "")).begins_with("掩护"):
			有掩护标签 = true
	t.ok(有掩护标签, "★★ 段 14(d)：我方那条写着「掩护 X/2」")
	t.ok(v.援护连线数() >= 1, "★★ 段 14(d)：`战斗动画层` 真的画出了 %d 条援护连线" % v.援护连线数())
	var 层 = v.find_child("战斗动画层", true, false)
	t.ok(层 != null and 层.get("active_guards") is Array and (层.get("active_guards") as Array).size() >= 1,
		"★★ 段 14(d)：动画层的 `active_guards` 里真的有连线数据（%s 条）" % str((层.get("active_guards") as Array).size() if 层 != null else 0))
	# 卡面上也有提示（`〔护→…〕` / `〔护←…〕`）
	var 有护标 := false
	for c in v.find_children("*", "UnitCard", true, false):
		if (c as Node).find_child("护卫标", true, false) is Label \
			and (c as Node).find_child("护卫标", true, false).visible:
			有护标 = true
			break
	t.ok(有护标, "★★ 段 14(d)：机体卡上显示「〔护→X 援护 2/2〕」那样的简短提示")
	# ---------- (e) 精神牌的效果摘要进日志 ----------
	var 精神 := {}
	for c in s.upper_hand_cards():
		if c is Dictionary and str((c as Dictionary).get("区", "")) == "专属精神牌" \
			and bool((c as Dictionary).get("可打", false)):
			精神 = c
			break
	if 精神.is_empty():
		t.ok(false, "★ 段 14(e)：选中机体没有能打的精神牌 —— 效果摘要那一条跑不了")
	else:
		var 前 := s.battle_log_entries(0).size()
		var r := s.play_unit_spirit_or_public_card(str(精神.get("手牌键", "")), "")
		await _等帧(1)
		t.ok(bool(r.get("ok", false)), "★ 段 14(e)：打出一张精神牌【%s】" % str(精神.get("名", "")))
		var 有新 := s.battle_log_entries(0).size() > 前
		var 摘要文 := ""
		for e in s.battle_log_entries(0):
			if e is Dictionary and str((e as Dictionary).get("类型", "")).begins_with("专属精神牌") \
				and str((e as Dictionary).get("卡牌ID", "")) == str(精神.get("id", "")):
				摘要文 = str((e as Dictionary).get("文本", ""))
		t.ok(有新 and not 摘要文.is_empty(),
			"★★ 段 14(e)：日志里留下这一行的原文：%s" % 摘要文.substr(0, 90))
		t.ok(摘要文.contains("→"),
			"★★ 段 14(e)：那一行带**具体效果摘要**（含 `→`）：%s" % 摘要文.substr(0, 90))
	# ---------- 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 14：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆boot(树根, 舱)

func _段15_敌方前后排与友方目标选中(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 15：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 20261022):
		t.ok(false, "★ 段 15：秘银五人快速测试开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "★ 段 15：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var v: BattleView = bv
	# ---------- ① 4×4 四行盒：上下顺序 + 按真实 slot 落位 ----------
	var 名到节点 := {"敌后排": "敌方阵型第1排", "敌前排": "敌方阵型第0排",
		"我前排": "我方阵型第0排", "我后排": "我方阵型第1排"}
	var 盒 := {}
	var 缺 := 0
	for 称呼 in 名到节点.keys():
		var 节点 = v.find_child(str(名到节点[称呼]), true, false)
		if 节点 == null or not (节点 is Control):
			缺 += 1
			continue
		盒[称呼] = 节点
	t.ok(缺 == 0 and 盒.size() == 4, "★ 段 15 ①：4×4 的四个行盒都在（缺 %d 个）" % 缺)
	if 缺 == 0:
		var 框 := {}
		for 称呼 in 盒.keys():
			框[称呼] = (盒[称呼] as Control).get_global_rect()
		t.ok(float((框["敌后排"] as Rect2).position.y) < float((框["敌前排"] as Rect2).position.y),
			"★★ 段 15 ①：**敌后排在最上、敌前排在下（贴战线）** —— y %.1f < %.1f"
			% [float((框["敌后排"] as Rect2).position.y), float((框["敌前排"] as Rect2).position.y)])
		t.ok(float((框["我前排"] as Rect2).position.y) < float((框["我后排"] as Rect2).position.y),
			"★★ 段 15 ①：我前排在上（贴战线）、我后排在下 —— y %.1f < %.1f"
			% [float((框["我前排"] as Rect2).position.y), float((框["我后排"] as Rect2).position.y)])
		t.ok(float((框["敌前排"] as Rect2).end.y) <= float((框["我前排"] as Rect2).position.y) + 0.5,
			"★★ 段 15 ①：上到下严格是 敌后排 → 敌前排 → 我前排 → 我后排（中央战线夹在敌前排 / 我前排之间）")
		t.ok(str(盒["敌后排"].get_meta("row_label", "")) == "敌后排"
			and str(盒["敌前排"].get_meta("row_label", "")) == "敌前排"
			and str(盒["我前排"].get_meta("row_label", "")) == "我前排"
			and str(盒["我后排"].get_meta("row_label", "")) == "我后排",
			"★ 段 15 ①：四个行盒的 `row_label` = 敌后排 / 敌前排 / 我前排 / 我后排")
		var 首槽图 := {"敌后排": 4, "敌前排": 0, "我前排": 0, "我后排": 4}
		var 方图 := {"敌后排": "enemy", "敌前排": "enemy", "我前排": "ally", "我后排": "ally"}
		for 称呼 in 首槽图.keys():
			var 卡们 := _排卡们(盒[称呼])
			var 首: int = int(首槽图[称呼])
			var 坏 := 0
			var 详情 := ""
			for j in 卡们.size():
				var 卡: UnitCard = 卡们[j]
				var 位: int = 首 + j
				if int(卡.get_meta("slot", -1)) != 位:
					坏 += 1
					详情 += " [slot %d] meta=%s" % [位, str(卡.get_meta("slot", -1))]
					continue
				var 望 := _内核键Of(s, str(方图[称呼]), 位)
				var 实 := str(卡.数据.get("键", ""))
				if 望 != 实:
					坏 += 1
					详情 += " [slot %d] 望=%s 实=%s" % [位, 望, 实]
			t.ok(卡们.size() == 4 and 坏 == 0,
				"★★ 段 15 ①：%s 的 4 张卡按**真实位号 %d..%d** 落位（错 %d 处%s）"
				% [称呼, 首, 首 + 3, 坏, 详情.substr(0, 120)])
		var 盾键 := _内核键Of(s, "enemy", 0)
		var 后键 := _内核键Of(s, "enemy", 4)
		t.ok(not 盾键.is_empty() and _排有键(盒["敌前排"], 盾键),
			"★★ 段 15 ①：敌方 slot 0（%s）画在**敌前排**（贴战线那一排）" % 盾键)
		t.ok(not 后键.is_empty() and _排有键(盒["敌后排"], 后键),
			"★★ 段 15 ①：敌方 slot 4（%s）画在**敌后排**（最上那一排）" % 后键)
		t.ok(not 盾键.is_empty() and not _排有键(盒["敌后排"], 盾键)
			and not 后键.is_empty() and not _排有键(盒["敌前排"], 后键),
			"★★ 段 15 ①：两排**没有互串** —— 槽位翻转（slot 0..3 ↔ 4..7）已修好")
	# ---------- ② 友方目标牌：目标方 / 可拖拽 / 拖拽目标方 ----------
	var u2 := _单位Of键(s, "U2")
	var u7 := _单位Of键(s, "U7")
	var u6 := _单位Of键(s, "U6")
	t.ok(not u2.is_empty() and not u7.is_empty() and not u6.is_empty(),
		"★ 段 15 ②：毛（U2）/ 宗介（U7）/ 克鲁兹（U6）都在场")
	if u2.is_empty() or u7.is_empty() or u6.is_empty():
		t.ok(false, "★ 段 15 ②：秘银三人缺人 —— 友方目标那几条跑不了")
		_拆boot(树根, 舱)
		return
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 50.0
	var 补给 := MithrilV03Cards.卡("V3_U2_S2").duplicate(true)
	补给["_实例号"] = 9201
	if not (u2.get("专属手牌") is Array):
		u2["专属手牌"] = []
	(u2["专属手牌"] as Array).append(补给)
	var 选 := s.select_battle_unit("U2")
	t.ok(bool(选.get("ok", false)), "★ 段 15 ②：选中毛（%s）" % str(选.get("名", "")))
	v.refresh()
	await _等帧(2)
	var 视 := _手牌视图ById(s, "V3_U2_S2")
	t.ok(not 视.is_empty(), "★ 段 15 ②：上排画出了【%s】" % "【指令】补给")
	if not 视.is_empty():
		t.ok(str(视.get("目标", "")) == "友军", "★ 段 15 ②：门面透传卡面 `目标` 原文（%s）" % str(视.get("目标", "")))
		t.ok(str(视.get("目标方", "")) == "友方",
			"★★ 段 15 ②：【指令】补给导出的 `目标方` = **友方**（不再被当成敌方）")
		t.ok(bool(视.get("可打", false)), "★ 段 15 ②：这张牌现在可打（%s）" % str(视.get("原因", "")))
		t.ok(v.可拖拽释放(视, "专属精神牌"),
			"★★ 段 15 ②：`目标方 == 友方` 的**精神牌也支持拖拽释放**（从前精神牌一律点一下）")
		t.ok(not v.可拖拽释放({"可打": true, "目标方": "无"}, "专属精神牌"),
			"★★ 段 15 ②：`目标方 == 无`（自身 / 全队 / 敌方全体）**仍旧点一下就放**、不走拖拽")
		t.ok(v._拖拽目标方(视) == BattleView.我方,
			"★★ 段 15 ②：`_拖拽目标方()` = **我方**（从前一律默认敌方！）")
		t.ok(v._拖拽目标方({"目标": "友军"}) == BattleView.我方,
			"★ 段 15 ②：老口径兜底 —— 卡面 `目标 == 友军` 也判我方")
		t.ok(v._拖拽目标方({"目标": "秘银成员"}) == BattleView.我方,
			"★ 段 15 ②：卡面 `目标 == 秘银成员`（补给弹匣）也判我方")
		t.ok(v._拖拽目标方({"目标方": "敌方"}) == BattleView.敌方, "★ 段 15 ②：`目标方 == 敌方` 仍判敌方")
	# 拖到宗介（U7）卡上松手 → 效果准确落在他身上
	var 卡U2 := _卡By键(v, "ally", "U2")
	var 卡U7 := _卡By键(v, "ally", "U7")
	t.ok(卡U2 != null and 卡U7 != null, "★ 段 15 ②：毛与宗介的 `UnitCard` 都在场上")
	if not 视.is_empty() and 卡U2 != null and 卡U7 != null:
		var 毛前 := float(u2.get("战意", 0.0))
		var 宗前 := float(u7.get("战意", 0.0))
		var 日志前: int = s.battle_log_entries(0).size()
		var r0 := v.开始拖拽("专属精神牌", str(视.get("手牌键", "")), true, _心(卡U2) + Vector2(0.0, 6.0), 视)
		t.ok(bool(r0.get("可拖拽", false)), "★★ 段 15 ②：按住这张友方 Buff 牌 → 进入拖拽准备态（%s）" % str(r0.get("原因", "")))
		var r1 := v.拖拽到(_心(卡U7))
		t.ok(bool(r1.get("已启动", false)) and str(r1.get("目标键", "")) == "U7",
			"★★ 段 15 ②：拖到宗介卡上 → **吸附到友军 U7**（目标 = %s）" % str(r1.get("目标键", "")))
		var 线 := v.拖拽瞄准线()
		t.ok(线.get("颜色") == BattleView.瞄准色_维修 and bool(线.get("维修", false)),
			"★★ 段 15 ②：友方目标牌的瞄准线是**翠绿**（瞄准色_维修），不是攻击橙红")
		t.ok(str(线.get("目标方", "")) == BattleView.我方, "★★ 段 15 ②：瞄准线的 `目标方` = 我方")
		t.ok(卡U7.瞄准高亮中(), "★★ 段 15 ②：被瞄准的宗介卡亮着翠绿「可投放」框")
		# ★ 2026-10-23（任务单 UI-2）：拖动友军牌时**所有存活我方**都点亮成可投放框
		t.ok(卡U2.瞄准高亮中() and v.友军可投放高亮中(),
			"★★ 段 15 ② ★ UI-2：拖动友军牌时**所有存活我方**都点亮翠绿可投放框（毛也亮着）")
		var r2 := v.结束拖拽(_心(卡U7))
		t.ok(bool(r2.get("释放", false)) and str(r2.get("目标键", "")) == "U7",
			"★★ 段 15 ②：松手 → 把宗介的键当 `target_id` 打出去（%s）" % str(r2.get("原因", "")))
		t.ok(absf(float(u2.get("战意", 0.0)) - (毛前 - 10.0)) < 0.001,
			"★★ 段 15 ②：毛付了 10 点战意（%.0f → %.0f）" % [毛前, float(u2.get("战意", 0.0))])
		t.ok(float(u7.get("战意", 0.0)) >= 宗前 + 14.0,
			"★★ 段 15 ②：**指定的宗介**战意 +15（10 + 小队长 5）：%.0f → %.0f"
			% [宗前, float(u7.get("战意", 0.0))])
		var 末文 := _末日志文(s, "专属精神牌")
		t.ok(s.battle_log_entries(0).size() > 日志前 and 末文.contains("作用于【"),
			"★★ 段 15 ②：战报写明作用对象：%s" % 末文.substr(0, 110))
		t.ok(末文.contains(str(u7.get("name", ""))),
			"★★ 段 15 ②：战报里点名的是**宗介**（%s），不是敌人" % str(u7.get("name", "")))
		# ---------- ③ 非攻击牌的棋盘演出（P3-4）----------
		var 层 = v._战斗动画层
		var 飘数 := int(层.飘字数()) if 层 != null else 0
		t.ok(飘数 >= 1, "★★ 段 15 ③：精神牌打出后棋盘上弹出 %d 枚飘字胶囊（从前什么都没有）" % 飘数)
		var 有牌名 := false
		if 层 != null and 层.active_popups is Array:
			for p in (层.active_popups as Array):
				if p is Dictionary and str((p as Dictionary).get("文本", "")).contains("补给"):
					有牌名 = true
		t.ok(有牌名, "★★ 段 15 ③：胶囊文案带牌名（【指令】补给）与具体效果")
		t.ok(卡U2.发牌脉冲中(), "★★ 段 15 ③：施放者（毛）的机体卡播了一次脉冲高亮")
	var 补给2 := MithrilV03Cards.卡("V3_U2_S2").duplicate(true)
	补给2["_实例号"] = 9202
	(u2["专属手牌"] as Array).append(补给2)
	var 点 := _手牌视图ById(s, "V3_U2_S2")
	t.ok(not 点.is_empty(), "★ 段 15 ②b：第二张【指令】补给也进了手牌")
	if not 点.is_empty():
		var r3 := s.play_unit_spirit_or_public_card(str(点.get("手牌键", "")), "")
		t.ok(bool(r3.get("ok", false)), "★ 段 15 ②b：直接点一下打出（%s）" % str(r3.get("为什么", "")))
		var 末文2 := _末日志文(s, "专属精神牌")
		t.ok(末文2.contains("作用于【"),
			"★★ 段 15 ②b：点打着也写明「→ 作用于【X】」（绝不让玩家以为打到了敌方）：%s" % 末文2.substr(0, 110))
	var 护 := MithrilV03Cards.卡("V3_F_6").duplicate(true)
	护["_实例号"] = 9301
	if not (s.battle_ctx.get("公有手牌") is Array):
		s.battle_ctx["公有手牌"] = []
	(s.battle_ctx["公有手牌"] as Array).append(护)
	v.refresh()
	await _等帧(2)
	var 视护 := _手牌视图ById(s, "V3_F_6")
	t.ok(not 视护.is_empty(), "★ 段 15 ②c：下排画出了公有牌【紧急防护】")
	if not 视护.is_empty():
		t.ok(str(视护.get("目标方", "")) == "友方",
			"★★ 段 15 ②c：公有【紧急防护】的 `目标方` = **友方**（%s）" % str(视护.get("目标方", "")))
		t.ok(v.可拖拽释放(视护, "公有牌") and v._拖拽目标方(视护) == BattleView.我方,
			"★★ 段 15 ②c：它可以拖、并且吸附我方")
		var 卡U6 := _卡By键(v, "ally", "U6")
		if bool(视护.get("可打", false)) and 卡U6 != null:
			v.开始拖拽("公有牌", str(视护.get("手牌键", "")), false, _心(卡U2) + Vector2(0.0, 6.0), 视护)
			var rp := v.拖拽到(_心(卡U6))
			t.ok(bool(rp.get("已启动", false)) and str(rp.get("目标键", "")) == "U6",
				"★★ 段 15 ②c：拖到克鲁兹卡上 → 吸附 U6（%s）" % str(rp.get("目标键", "")))
			var rr := v.结束拖拽(_心(卡U6))
			t.ok(bool(rr.get("释放", false)) and str(rr.get("目标键", "")) == "U6",
				"★★ 段 15 ②c：松手 → 指定克鲁兹释放")
			var 护文 := _末日志文(s, "公有牌")
			t.ok(护文.contains("作用于【") and 护文.contains(str(u6.get("name", ""))),
				"★★ 段 15 ②c：战报写明「作用于【克鲁兹】… −50%%」：%s" % 护文.substr(0, 110))
		else:
			t.ok(false, "★ 段 15 ②c：【紧急防护】这一下打不出来（%s）—— 拖拽那两条跑不了"
				% str(视护.get("原因", "")))
	# ---------- ② d 免指派牌（全队 / 自身）不会被误判成要选目标 ----------
	var 全 := MithrilV03Cards.卡("V3_L3_SUPPORT").duplicate(true)
	全["_实例号"] = 9401
	(s.battle_ctx["公有手牌"] as Array).append(全)
	v.refresh()
	await _等帧(1)
	var 视全 := _手牌视图ById(s, "V3_L3_SUPPORT")
	t.ok(not 视全.is_empty() and str(视全.get("目标", "")) == "全队",
		"★ 段 15 ②d：连携【达纳号·紧急支援】的卡面 `目标` = 全队")
	if not 视全.is_empty():
		t.ok(str(视全.get("目标方", "")) == "无",
			"★★ 段 15 ②d：`目标 == 全队` → `目标方 == 无`（免指派，点一下就放）")
	# ---------- ④ 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 15 ④：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆boot(树根, 舱)

func _排卡们(排: Node) -> Array:
	var 出: Array = []
	if 排 == null or not is_instance_valid(排):
		return 出
	for c in (排 as Node).get_children():
		if c is UnitCard:
			出.append(c)
	return 出

func _排有键(排: Node, 键: String) -> bool:
	if 键.is_empty():
		return false
	for c in _排卡们(排):
		if str((c as UnitCard).数据.get("键", "")) == 键:
			return true
	return false

func _内核键Of(s: GameSession, 方: String, 位: int) -> String:
	if s == null or s.battle_ctx.is_empty():
		return ""
	var 池: Variant = s.battle_ctx.get("allies") if 方 == "ally" else s.battle_ctx.get("enemies")
	if not (池 is Array):
		return ""
	for u in (池 as Array):
		if u is Dictionary and int(float((u as Dictionary).get("slot", -1.0))) == 位:
			return str((u as Dictionary).get("key", ""))
	return ""

func _末日志文(s: GameSession, 类型: String) -> String:
	var 出 := ""
	for e in s.battle_log_entries(0):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == 类型:
			出 = str((e as Dictionary).get("文本", ""))
	return 出

func _张数ByName(们: Variant, 名: String) -> int:
	if not (们 is Array):
		return 0
	var 数 := 0
	for c in (们 as Array):
		if not (c is Dictionary):
			continue
		var d: Dictionary = c
		if str(d.get("名", "")) == 名:
			数 += 1
			continue
		var 卡 = d.get("卡")
		if 卡 is Dictionary and str((卡 as Dictionary).get("名", "")) == 名:
			数 += 1
	return 数

# ★ 段 16（2026-10-23 任务单「手牌三栏自适应缩放与友军拖拽绿线箭头」UI-1 / UI-2）
#
#   UI-1 —— 中下手牌栏彻底重排：
#     ① **上排 = 并列三栏**【主武器】｜【副武器】｜【精神】，每栏自带小标题 + 卡行，
#        `size_flags_stretch_ratio == max(1, 该栏张数)`（哪栏牌多就自动分到更宽的空间）；
#     ② **下排 = 【公有牌】** + 一条平铺卡行；
#     ③ **零横向滚动**：两排都没有 `ScrollContainer`（`_专属排滚动` / `_公有排滚动` 都是 null），
#        卡最小宽 36px、横纵 `SIZE_EXPAND_FILL` → 1280×720 视口里**不用横向滚动**就全看得见；
#     ④ 两排纵向都 `SIZE_EXPAND_FILL`，把 `手牌栏` 的 248px **填满**（底部空白 < 12px）；
#     ⑤ 卡面三行（牌名 / 费用·状态 / 威力·简短效果）+ 字号随张数自适应（10~12px）。
#
#   UI-2 —— 天人 11 张友方牌：
#     ⑥ `目标方 == "友方"`、`可拖拽释放() == true`、`_拖拽目标方() == 我方`；
#     ⑦ 单纯点击友军牌**不出牌**（日志 / 战意都不动），只给「请按住…拖动到上方我方机体上释放」
#        提示并把所有存活我方点亮成翠绿可投放框；
#     ⑧ 拖到我方受伤机体上松手 → 瞄准线 `维修 == true`（翠绿）+ 箭头，效果准确落在它身上；
#     ⑨ 起点兜底：连 `所属键` / `发动键` / 选中机体都没有时，起点 = **被拖手牌自己的中心**。
#
#   UI-3（2026-10-23 任务单 §1.3）—— 左牌库栏：
#     ⑩ **彻底去掉 `ScrollContainer`**：`_左牌库列表` 直接 `SIZE_EXPAND_FILL` 铺满左栏剩余高度，
#        分成【武器 / 大招】【精神 / 待入库】【公有 / 势力副牌库】三个子区块（各带标题、按
#        `max(1, ceil(条目数 / 2.0))` 分高度），每块内部 2 列 `GridContainer` 平铺高密度小卡；
#        所有 `左库卡` 的 `get_global_rect()` **100% 落在 `左牌库栏` 内部**（零滚动条、零溢出）。
