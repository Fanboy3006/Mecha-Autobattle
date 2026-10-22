## 职责：版面门禁：左牌库与手牌栏（段 16 手牌栏三栏零滚动自适应 / 左牌库三分类 / 天人 11 张友方目标 / 友军牌强制拖动绿线箭头）。
extends "res://tests/unit/layout_fixtures.gd"

func 走一遍(t, 根: Node) -> void:
	var 起16: int = t.passes + t.fails
	await _段16_手牌三栏零滚动与友军拖动绿线(t, 根)
	var 段16: int = t.passes + t.fails - 起16
	t.info("★ 版面门禁（本套）：段 16（手牌三栏零滚动 / 左库三分类 / 友军拖动绿线）%d 项 · 合计 %d 项" % [段16, 段16])

## 段 16 夹具：天人 11 张「目标 = 天人成员」的友方牌 id（太阳炉 6 + 势力 4 + 拉塞精神 1）。
const 天人友方牌们 := ["CB_SD1_HARO_HEAL", "CB_SD1_REFILL", "CB_SD1_VEDA_SCAN",
	"CB_SD2_HARO_SHIELD", "CB_SD2_SUPER_REFLEX", "CB_SD3_HERITAGE",
	"CB_FAC_3", "CB_FAC_4", "CB_FAC_6", "CB_FAC_7", "CB5_S3"]

func _段16_手牌三栏零滚动与友军拖动绿线(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 16：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if not s.start_quick_battle_celestial(20261023):
		t.ok(false, "★ 段 16：天人五人快速测试开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "★ 段 16：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var v: BattleView = bv
	# ---------- ① 上排 = 并列三栏（【主武器】｜【副武器】｜【精神】）----------
	var 栏们: Array = v._专属栏们.keys()
	t.ok(栏们.size() == 3 and 栏们.has("主武器") and 栏们.has("副武器") and 栏们.has("精神"),
		"★★ 段 16 ①：上排拆成**并列三栏**，三个卡盒都在（%s）" % str(栏们))
	var 标题齐 := true
	var 栏详情 := ""
	for 组 in BattleView.单机三栏:
		var 栏 = v._专属排列表.get_node_or_null("%s栏" % 组)
		if not (栏 is Control):
			标题齐 = false
			栏详情 += " [缺 %s栏]" % 组
			continue
		var 题 = (栏 as Node).find_child("%s栏标题" % 组, true, false)
		if not (题 is Label) or not str((题 as Label).text).contains("【%s】" % 组):
			标题齐 = false
			栏详情 += " [%s 的标题不对]" % 组
	t.ok(标题齐, "★★ 段 16 ①：每栏都有**独立小标题**「【主武器】/【副武器】/【精神】」%s" % 栏详情)
	# `stretch_ratio = max(1, 该栏张数)` —— 哪一栏牌多就自动分到更宽的空间
	var 比对齐 := true
	var 比详情 := ""
	for 组 in BattleView.单机三栏:
		var 栏 = v._专属排列表.get_node_or_null("%s栏" % 组)
		var 张 := 0
		if v._专属栏们.has(组):
			张 = (v._专属栏们[组] as Node).get_child_count()
		var 望 := float(maxi(1, 张))
		var 实 := -1.0
		if 栏 is Control:
			实 = float((栏 as Control).size_flags_stretch_ratio)
		if absf(实 - 望) > 0.01:
			比对齐 = false
			比详情 += " %s(张 %d: 望 %.0f 实 %.2f)" % [组, 张, 望, 实]
	t.ok(比对齐, "★★ 段 16 ①：每栏 `size_flags_stretch_ratio == max(1, 张数)`（牌多的栏自动更宽）%s" % 比详情)
	# ---------- ② 零横向滚动：两排都不再有 ScrollContainer ----------
	t.ok(v._专属排滚动 == null and v._公有排滚动 == null,
		"★★ 段 16 ②：上/下两排**彻底去掉横向滚动条**（`_专属排滚动` / `_公有排滚动` 都不再是 ScrollContainer）")
	var 滚动数 := _数滚动容器(v._专属排) + _数滚动容器(v._公有排)
	t.ok(滚动数 == 0, "★★ 段 16 ②：上排 / 下排子树里一个 `ScrollContainer` 都没有（实际 %d 个）" % 滚动数)
	t.ok(v._专属排.size_flags_vertical & Control.SIZE_EXPAND != 0
		and v._公有排.size_flags_vertical & Control.SIZE_EXPAND != 0,
		"★★ 段 16 ②：两排纵向都设了 `SIZE_EXPAND_FILL`（不是写死 58px）")
	# ---------- ③ 所有卡都装在手牌栏里（不溢出右边界、不溢出下边界）----------
	var 手框: Rect2 = v._手牌栏.get_global_rect()
	var 卡们: Array = v.手牌卡控件们(true) + v.手牌卡控件们(false)
	var 出界 := 0
	var 越界详情 := ""
	for 卡 in 卡们:
		var r: Rect2 = (卡 as Control).get_global_rect()
		if (卡 as Control).size.x < 35.0 or (卡 as Control).size.y < 47.0:
			r = Rect2()   # 尺寸退化（塌成一条）也算不合格
		if r.size.x <= 0.0 or r.end.x > 手框.end.x + 0.5 or r.end.y > 手框.end.y + 0.5 \
			or r.position.x < 手框.position.x - 0.5 or r.position.y < 手框.position.y - 0.5:
			出界 += 1
			越界详情 += " %s" % _短(r)
	t.ok(卡们.size() > 0 and 出界 == 0,
		"★★ 段 16 ③：%d 张手牌**全部落在手牌栏 %s 之内**（零横向滚动、不溢出右/下边界；越界 %d 张%s）"
		% [卡们.size(), _短(手框), 出界, 越界详情.substr(0, 150)])
	# ---------- ④ 底部空白消灭：两排合起来填满 248px ----------
	var 底空 := 手框.end.y - v._公有排.get_global_rect().end.y
	t.ok(底空 >= 0.0 and 底空 <= 12.0,
		"★★ 段 16 ④：手牌栏底部**没有大块空白**（公有排下沿距手牌栏下沿 %.1fpx，从前空 ~90px）" % 底空)
	t.ok(v._专属排.get_global_rect().size.y >= 80.0 and v._公有排.get_global_rect().size.y >= 70.0,
		"★★ 段 16 ④：上排 %.0fpx / 下排 %.0fpx 都真的长高了（填满手牌栏）"
		% [v._专属排.get_global_rect().size.y, v._公有排.get_global_rect().size.y])
	# ---------- ⑤ 卡面：最小宽 36 / 横纵 EXPAND_FILL / 字号 10~12 / 三行文字 ----------
	var 首卡: Control = 卡们[0] as Control
	t.ok(首卡.custom_minimum_size.x <= 36.5 and 首卡.custom_minimum_size.y <= 48.5
		and 首卡.size_flags_horizontal & Control.SIZE_EXPAND != 0
		and 首卡.size_flags_vertical & Control.SIZE_EXPAND != 0,
		"★★ 段 16 ⑤：卡不再写死 108px 宽 —— 最小 %s、横纵都 `SIZE_EXPAND_FILL`（可自由收缩）"
		% str(首卡.custom_minimum_size))
	var 字号 := 0
	var 信息文 := ""
	var 有裁切 := true
	for ch in 首卡.get_child(0).get_children():
		var ctl: Control = ch as Control
		if ctl == null:
			continue
		if str(ctl.name) == "单机卡按钮":
			字号 = int((ctl as Button).get_theme_font_size("font_size"))
		if str(ctl.name) == "单机卡信息":
			信息文 = str((ctl as Label).text)
			有裁切 = (ctl as Label).clip_text and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
	t.ok(字号 >= 10 and 字号 <= 12, "★★ 段 16 ⑤：字号按张数自适应（这一栏 %dpx，区间 10~12）" % 字号)
	t.ok(信息文.contains("费") and 有裁切,
		"★★ 段 16 ⑤：卡面多出一行关键信息（`%s`，`clip_text` + 自动换行都在）" % 信息文.substr(0, 40))
	# ---------- ⑥ 天人 11 张友方牌：塞进手牌 → 目标方 = 友方 ----------
	var 公手: Array = []
	var 公原 = s.battle_ctx.get("公有手牌")
	if 公原 is Array:
		公手 = 公原
	for id in 天人友方牌们:
		if id == "CB5_S3":
			continue
		var 卡 := _天人牌(id)
		if not 卡.is_empty():
			公手.append(卡)
	s.battle_ctx["公有手牌"] = 公手
	# 拉塞（CB5）在队里 → 选中他，把「去吧，刹那」放进他的专属手牌
	var u5 := _单位Of键(s, "CB5")
	t.ok(not u5.is_empty(), "★ 段 16 ⑥：拉塞（CB5）在场上（拿去他的精神牌）")
	if not u5.is_empty():
		if not (u5.get("专属手牌") is Array):
			u5["专属手牌"] = []
		(u5["专属手牌"] as Array).append(_天人牌("CB5_S3"))
		s.select_battle_unit("CB5")
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 100.0
	# ★ CR-2 Batch B：`可打` 现在是**内核同一份判定**（含卡面 `入库条件`）——
	#   【伊安的整备】(CB_FAC_6) 要「第 2 回合起」、【托勒密号·紧急补给】(CB_FAC_7) 要
	#   「本场有人开过 TRANS-AM」。本段验的是「`目标方 == 友方` + 可拖」，所以先把这两条入库条件
	#   摆平（把回合推到第 5 回合、标一次 TRANS-AM），别让门槛把牌挡在手牌栏外。
	s.battle_ctx["turn"] = 5.0
	s.battle_ctx["本场有人开过TRANSAM"] = true
	v.refresh()
	await _等帧(2)
	var 号数 := 0
	var 缺们: Array = []
	for id in 天人友方牌们:
		var 视 := _手牌视图ById(s, id)
		if 视.is_empty():
			缺们.append(id)
			continue
		var 区 := str(视.get("区", ""))
		var 目标方 := str(视.get("目标方", ""))
		var 可拖 := v.可拖拽释放(视, 区)
		var 拖方 := v._拖拽目标方(视)
		if 目标方 == "友方" and 可拖 and 拖方 == BattleView.我方:
			号数 += 1
		else:
			缺们.append("%s(目标方=%s 可拖=%s 拖方=%s 原因=%s)" % [id, 目标方, str(可拖), 拖方, str(视.get("原因", ""))])
	t.ok(号数 == 11,
		"★★ 段 16 ⑥：天人 11 张友方牌 **全部** `目标方 == 友方` + `可拖拽释放 == true` + `_拖拽目标方 == 我方`（%d/11 %s）"
		% [号数, str(缺们)])
	t.ok(str(_手牌视图ById(s, "CB_SD1_HARO_HEAL").get("目标", "")) == "天人成员",
		"★ 段 16 ⑥：门面透传的卡面 `目标` 原文 = 天人成员（不是被算成敌方）")
	t.ok(v._拖拽目标方({"目标": "殖民卫星军成员"}) == BattleView.我方,
		"★★ 段 16 ⑥：以后的新势力 `…成员`（殖民卫星军成员）也自动判我方")
	t.ok(v._拖拽目标方({"目标": "全队"}) == BattleView.敌方
		or v._拖拽目标方({"目标方": "无"}) == BattleView.敌方,
		"★ 段 16 ⑥：`全队 / 自身`（免指派）没有被误判成友军拖拽")
	# ---------- ⑦ 单纯点击友军牌 → **不出牌**，只提示「请按住拖动」----------
	var 视哈 := _手牌视图ById(s, "CB_SD1_HARO_HEAL")
	t.ok(not 视哈.is_empty(), "★ 段 16 ⑦：下排画出了【哈罗·紧急修理】")
	if not 视哈.is_empty():
		var 日志前: int = s.battle_log_entries(0).size()
		var 战意前 := _战意总(s)
		var 键哈 := str(视哈.get("手牌键", ""))
		v._点单机卡("公有牌", 键哈, false)
		await _等帧(1)
		t.ok(s.battle_log_entries(0).size() == 日志前 and absf(_战意总(s) - 战意前) < 0.001,
			"★★ 段 16 ⑦：单纯点击友军牌**没有出牌**（日志 %d 条不变、全队战意不动）—— 不再乱奶满血自己"
			% 日志前)
		t.ok(str(v._操作结果.text).contains("请按住") and str(v._操作结果.text).contains("拖动到上方我方机体上释放"),
			"★★ 段 16 ⑦：操作提示改成「%s」" % str(v._操作结果.text))
		t.ok(str(v._操作结果.text).contains("绿色箭头"), "★★ 段 16 ⑦：提示里写明「绿色箭头指向目标」")
		t.ok(v.友军可投放高亮中(), "★★ 段 16 ⑦：场上的我方机体卡被点亮成**翠绿可投放框**")
		var 亮着 := 0
		for 卡 in v._我方卡:
			if 卡 is UnitCard and (卡 as UnitCard).瞄准高亮中():
				亮着 += 1
		t.ok(亮着 >= 2, "★★ 段 16 ⑦：所有存活我方都亮着（%d 张）" % 亮着)
	# ---------- ⑧ 拖到我方受伤机体上松手 → 翠绿连线 + 箭头 + 精确治疗 ----------
	var 伤台 := _单位Of键(s, "CB3")
	var 目标卡 := _卡By键(v, "ally", "CB3")
	t.ok(not 伤台.is_empty() and 目标卡 != null, "★ 段 16 ⑧：找到阿雷路亚（CB3）与他的 `UnitCard`")
	if not 伤台.is_empty() and 目标卡 != null:
		var 满 := float(伤台.get("maxHp", 1.0)) if float(伤台.get("maxHp", 0.0)) > 0.0 else float(伤台.get("hp", 1.0))
		伤台["hp"] = 满 * 0.4
		v.refresh()
		await _等帧(2)
		目标卡 = _卡By键(v, "ally", "CB3")
		var 哈卡 := _手牌卡ByID(v, "CB_SD1_HARO_HEAL")
		var 视哈2 := _手牌视图ById(s, "CB_SD1_HARO_HEAL")
		t.ok(哈卡 != null and not 视哈2.is_empty(), "★ 段 16 ⑧：手牌栏里找得到【哈罗·紧急修理】那张卡")
		if 哈卡 != null and 目标卡 != null and not 视哈2.is_empty():
			var 键 := str(视哈2.get("手牌键", ""))
			var 血前 := float(伤台.get("hp", 0.0))
			var 起 := v.开始拖拽("公有牌", 键, false, _心(哈卡), 视哈2, 哈卡)
			t.ok(bool(起.get("可拖拽", false)), "★★ 段 16 ⑧：按住友军牌 → 进入拖拽准备态")
			var 拖 := v.拖拽到(_心(目标卡))
			t.ok(bool(拖.get("已启动", false)) and str(拖.get("目标键", "")) == "CB3",
				"★★ 段 16 ⑧：拖到我方机体上 → **吸附 CB3**（目标 = %s）" % str(拖.get("目标键", "")))
			var 线 := v.拖拽瞄准线()
			t.ok(not 线.is_empty() and bool(线.get("维修", false)) and 线.get("颜色") == BattleView.瞄准色_维修,
				"★★★ 段 16 ⑧：友军牌的瞄准线是**翠绿维修色 + 维修标记**（绿色发光连线 + 实心箭头）")
			var 起点: Vector2 = 线.get("起点", Vector2.ZERO)
			t.ok(起点 != Vector2.ZERO and 起点.distance_to(_心(目标卡)) > 1.0,
				"★★ 段 16 ⑧：绿色连线的起点在自己的机体卡上（%s，不是原点）" % str(起点))
			t.ok(目标卡.瞄准高亮中() and v.友军可投放高亮中(),
				"★★ 段 16 ⑧：目标我方机体准星高亮 + 全体可投放框都在")
			t.ok(v._战斗动画层 != null and bool(v._战斗动画层.瞄准中()),
				"★★ 段 16 ⑧：瞄准线真的推到了特效画布上（`瞄准中()` = true）")
			var 松 := v.结束拖拽(_心(目标卡))
			t.ok(bool(松.get("释放", false)) and str(松.get("目标键", "")) == "CB3",
				"★★ 段 16 ⑧：松手 → 指定 CB3 释放（%s）" % str(松.get("原因", "")))
			t.ok(float(伤台.get("hp", 0.0)) > 血前 + 1.0,
				"★★★ 段 16 ⑧：**指定的那台友军**真的回了血（%.0f → %.0f）" % [血前, float(伤台.get("hp", 0.0))])
			t.ok(not v.拖拽中() and not v.友军可投放高亮中() and not 目标卡.瞄准高亮中(),
				"★★ 段 16 ⑧：松手后拖拽状态 / 可投放框 / 目标高亮全部收干净")
	# ---------- ⑨ 起点兜底：连拥有者都没有时 = 被拖手牌自己的中心 ----------
	var 哈卡2 := _手牌卡ByID(v, "CB_SD1_REFILL")
	if 哈卡2 != null:
		# 极端情况：这张牌上没有 `所属键` / `发动键`，而且**一台机体都没选中**（没有拥有者卡）。
		var 记住选中 := s.selected_unit_id
		s.selected_unit_id = ""
		var 手造 := {"可打": true, "目标方": "友方", "名": "临时友军测试牌"}
		v.开始拖拽("公有牌", "临时友军测试牌", false, _心(哈卡2), 手造, 哈卡2)
		v.拖拽到(_心(哈卡2) + Vector2(0.0, -30.0))
		var 线2 := v.拖拽瞄准线()
		var 望心 := _心(哈卡2)
		var 起点2: Vector2 = 线2.get("起点", Vector2.ZERO)
		t.ok(not 线2.is_empty() and 线2.get("起始卡") == null and 起点2.distance_to(望心) < 1.5,
			"★★★ 段 16 ⑨：连 `所属键` / `发动键` / 选中机体都没有时，绿色连线起点 = **被拖那张手牌自己的中心**")
		t.ok(bool(线2.get("维修", false)), "★★ 段 16 ⑨：这条兜底线仍然是翠绿维修色")
		s.selected_unit_id = 记住选中
	v.取消拖拽()
	await _等帧(1)
	# ---------- ⑩ 左牌库栏：三分类子区块 + 双列网格 + 零滚动 / 零溢出 ----------
	await _等帧(2)
	var 左栏框: Rect2 = v._左牌库栏.get_global_rect()
	t.ok(v._左牌库滚动 == null and _数滚动容器(v._左牌库栏) == 0,
		"★★ 段 16 ⑩：左牌库栏**彻底去掉 ScrollContainer**（`_左牌库滚动` = null、子树里 0 个滚动条）")
	t.ok(v._左牌库列表 != null and (v._左牌库列表.size_flags_vertical & Control.SIZE_EXPAND) != 0,
		"★★ 段 16 ⑩：`_左牌库列表` 直接 `SIZE_EXPAND_FILL` 铺满左栏剩余高度（%.0fpx）"
		% (v._左牌库列表.get_global_rect().size.y if v._左牌库列表 != null else 0.0))
	var 区块齐 := true
	var 区块详情 := ""
	for 组 in BattleView.左库区块们:
		var 块 = v._左库区块节点.get(组)
		var 网 = v._左库网格们.get(组)
		var 题控 = (块 as Node).find_child("左库区块标题-%s" % 组, true, false) if 块 is Node else null
		var 望题 := str(BattleView.左库区块题.get(组, ""))
		if not (块 is Control) or not (网 is GridContainer) or int((网 as GridContainer).columns) != 2 \
			or not (题控 is Label) or str((题控 as Label).text) != 望题:
			区块齐 = false
			区块详情 += " [%s 缺块 / 标题 / 2 列网格]" % 组
	t.ok(区块齐, "★★ 段 16 ⑩：左栏分成【武器 / 大招】【精神 / 待入库】【公有 / 势力副牌库】三块，各带标题 + 2 列 `GridContainer`%s" % 区块详情)
	var 左比齐 := true
	var 左比详情 := ""
	for 组 in BattleView.左库区块们:
		var 块 = v._左库区块节点.get(组)
		var 张 := _左库区块卡数(v, 组)
		var 望 := float(maxi(1, int(ceil(float(张) / 2.0))))
		var 实 := float((块 as Control).size_flags_stretch_ratio) if 块 is Control else -1.0
		if absf(实 - 望) > 0.01:
			左比齐 = false
			左比详情 += " %s(卡 %d: 望 %.0f 实 %.2f)" % [组, 张, 望, 实]
	t.ok(左比齐, "★★ 段 16 ⑩：三块高度按 `max(1, ceil(条目数 / 2.0))` 分配%s" % 左比详情)
	# 三个分类真的把条目**分开**了：每张卡都落在「它那个区该去的块」里
	var 许区 := {
		"武器大招": ["主武器卡", "副武器卡", "衍生攻击卡", "大招槽卡"],
		"精神待入库": ["专属精神牌", "待入库"],
		"公有副牌库": ["公有牌", "连携牌", "筹码牌"],
	}
	var 有卡块 := 0
	var 归类对 := true
	var 归类详情 := ""
	for 组 in BattleView.左库区块们:
		var 网 = v._左库网格们.get(组)
		var 本块 := 0
		if 网 is Node:
			for c in (网 as Node).get_children():
				if not (c as Node).has_meta("left_library_entry"):
					continue
				本块 += 1
				var e: Dictionary = (c as Node).get_meta("left_library_entry")
				if not (许区[组] as Array).has(str(e.get("区", ""))):
					归类对 = false
					归类详情 += " %s→%s" % [组, str(e.get("区", ""))]
		if 本块 > 0:
			有卡块 += 1
	t.ok(有卡块 >= 1, "★★ 段 16 ⑩：左栏真的装着这一台当前打不了的牌（%d 块有卡）" % 有卡块)
	t.ok(归类对, "★★ 段 16 ⑩：每张卡都落在**性质对应的子区块**里（武器/大招 · 精神/待入库 · 公有/副牌库）%s" % 归类详情)
	# 分类口径本身（纯函数）：区 → 子区块，七种区逐一钉住（待入库按「是否公有」分流）
	var 分流对 := v._左库组Of({"区": "主武器卡"}) == "武器大招" \
		and v._左库组Of({"区": "副武器卡"}) == "武器大招" \
		and v._左库组Of({"区": "衍生攻击卡"}) == "武器大招" \
		and v._左库组Of({"区": "大招槽卡"}) == "武器大招" \
		and v._左库组Of({"区": "专属精神牌"}) == "精神待入库" \
		and v._左库组Of({"区": "待入库", "来源": "待入库", "公有": false}) == "精神待入库" \
		and v._左库组Of({"区": "待入库", "来源": "待入库", "公有": true}) == "公有副牌库" \
		and v._左库组Of({"区": "公有牌"}) == "公有副牌库" \
		and v._左库组Of({"区": "连携牌"}) == "公有副牌库" \
		and v._左库组Of({"区": "筹码牌"}) == "公有副牌库"
	t.ok(分流对, "★★ 段 16 ⑩：`_左库组Of()` 把七种区正确分流到三块（主/副/衍生/大招→武器大招 · 精神/待入库→精神待入库 · 公有/连携/筹码/公有待入库→公有副牌库）")
	t.ok(str(v._左牌库标题.text).begins_with("未激活 / 冷却牌库（") and str(v._左牌库标题.text).ends_with("张）"),
		"★★ 段 16 ⑩：`左牌库标题` 是紧凑摘要「%s」" % str(v._左牌库标题.text))
	var 概览行 := 0
	var 有太阳炉 := false
	for l in v._左库副牌概览:
		if l is Label and (l as Label).visible and not str((l as Label).text).is_empty():
			概览行 += 1
			if str((l as Label).text).contains("太阳炉"):
				有太阳炉 = true
	t.ok(概览行 >= 1 and 有太阳炉,
		"★★ 段 16 ⑩：区块 C 画出了势力副牌库概览（%d 行可见，含太阳炉 = %s）" % [概览行, str(有太阳炉)])
	var 左卡们: Array = v.左库卡控件们()
	var 左出界 := 0
	var 左详情 := ""
	for 卡 in 左卡们:
		var r: Rect2 = (卡 as Control).get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0 or r.position.x < 左栏框.position.x - 0.5 \
			or r.position.y < 左栏框.position.y - 0.5 or r.end.x > 左栏框.end.x + 0.5 \
			or r.end.y > 左栏框.end.y + 0.5:
			左出界 += 1
			左详情 += " %s" % _短(r)
	t.ok(左卡们.size() > 0 and 左出界 == 0,
		"★★★ 段 16 ⑩：%d 张 `左库卡` **100%% 落在左牌库栏 %s 之内**（零滚动条、零溢出；越界 %d 张%s）"
		% [左卡们.size(), _短(左栏框), 左出界, 左详情.substr(0, 150)])
	if 左卡们.size() > 0:
		var 首左: Control = 左卡们[0] as Control
		var 左按: Button = 首左.find_child("左库卡按钮", true, false) as Button
		var 左态: Label = 首左.find_child("左库卡状态", true, false) as Label
		t.ok(首左.custom_minimum_size.x <= 36.5 and 首左.custom_minimum_size.y <= 20.5
			and 首左.size_flags_horizontal & Control.SIZE_EXPAND != 0
			and 首左.size_flags_vertical & Control.SIZE_EXPAND != 0,
			"★★ 段 16 ⑩：左库卡最小 %s、横纵都 `SIZE_EXPAND_FILL`（双列里可自由收缩）"
			% str(首左.custom_minimum_size))
		var 左字号 := int(左按.get_theme_font_size("font_size")) if 左按 != null else -1
		t.ok(左按 != null and 左按.disabled and 左按.clip_text and 左字号 >= 9 and 左字号 <= 11,
			"★★ 段 16 ⑩：`左库卡按钮` 一律 `disabled` + `clip_text`、字号 %dpx（自适应 9~11）" % 左字号)
		var 态字号 := int(左态.get_theme_font_size("font_size")) if 左态 != null else -1
		t.ok(左态 != null and 左态.clip_text and 态字号 >= 9 and 态字号 <= 10,
			"★★ 段 16 ⑩：`左库卡状态` 单行裁切、字号 %dpx（9~10）" % 态字号)
	# ---------- ⑪ 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 16 ⑪：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆boot(树根, 舱)

## 段 16 用：左栏某个子区块的网格里有几张 `左库卡`（`（空）` 提示标签不算）。
func _左库区块卡数(v: BattleView, 组: String) -> int:
	var 网 = v._左库网格们.get(组)
	if not (网 is Node):
		return 0
	var 数 := 0
	for c in (网 as Node).get_children():
		if c is Node and (c as Node).has_meta("left_library_entry"):
			数 += 1
	return 数

## 段 16 用：一棵子树里 `ScrollContainer` 的个数（`0` = 没有任何可拖的滚动条）。
func _数滚动容器(根: Node) -> int:
	if 根 == null or not is_instance_valid(根):
		return 0
	var 数 := 1 if 根 is ScrollContainer else 0
	for c in 根.get_children():
		数 += _数滚动容器(c)
	return 数

## 段 16 用：`id` 那张天人牌的数据原件（太阳炉 / 势力 / 拉塞精神，三种都在这里找）。
func _天人牌(id: String) -> Dictionary:
	for c in CelestialV01.太阳炉卡表():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	for c in CelestialV01.势力牌们():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	for c in CelestialV01.拉塞卡表():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

## 段 16 用：手牌栏里 `id` 匹配的那张卡控件（三栏 / 公有行都认；找不到 = null）。
func _手牌卡ByID(v: BattleView, id: String) -> Control:
	for 上排 in [true, false]:
		for 卡 in v.手牌卡控件们(上排):
			var d = (卡 as Node).get_meta("unit_card_data")
			if d is Dictionary and str((d as Dictionary).get("id", "")) == id:
				return 卡 as Control
	return null

## 段 16 用：全队战意合计（验「点了友军牌但没出牌」用）。
func _战意总(s: GameSession) -> float:
	var 总 := 0.0
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary:
			总 += float(Btl.战意(u))
	return 总
