## 职责：左栏牌库三分区（武器大招 / 精神待入库 / 公有副牌库）、高密度左库卡与副牌库概览。
extends RefCounted

static func _建左牌库栏(宿主, 父: Node) -> void:
	宿主._左牌库栏 = UiTheme.建面板(父, "左牌库栏", UiTheme.面板底, UiTheme.边框)
	宿主._左牌库栏.custom_minimum_size = Vector2(宿主.左栏宽, 0)
	宿主._左牌库栏.size_flags_horizontal = Control.SIZE_FILL
	宿主._左牌库栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._左牌库栏.clip_contents = true
	var 列 = UiTheme.建盒(宿主._左牌库栏, "左牌库栏上下列", true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._左牌库标题 = 宿主._建单行标签(列, "左牌库标题", "【未激活 / 冷却牌库】", UiTheme.字号_小, UiTheme.推进剂色)
	宿主._左牌库副标题 = 宿主._建单行标签(列, "左牌库副标题", "（牌库 / 弃牌 / 待入库）", UiTheme.字号_小, UiTheme.次要文字)
	# ★ COL-4b：感应牌库明细入口（只有队里有殖民卫星军、真装了感应牌库时才露出来）。
	宿主._感应牌库按钮 = UiTheme.建按钮(列, "查看感应牌库", 宿主.开感应牌库面板)
	宿主._感应牌库按钮.name = "感应牌库按钮"
	宿主._感应牌库按钮.add_theme_font_size_override("font_size", UiTheme.字号_小)
	宿主._感应牌库按钮.visible = false
	宿主._左牌库太阳炉 = 宿主._建单行标签(列, "太阳炉牌库明细", "", UiTheme.字号_小, UiTheme.连携色)
	宿主._左牌库太阳炉.visible = false
	宿主._左牌库列表 = UiTheme.建盒(列, "左牌库列表", true, 2) as VBoxContainer
	宿主._左牌库列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._左牌库列表.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._左牌库列表.clip_contents = true
	宿主._左库区块节点 = {}
	宿主._左库网格们 = {}
	宿主._左库副牌概览 = []
	for 组 in 宿主.左库区块们:
		宿主._建左库区块(宿主._左牌库列表, 组)
	var 留白 := Control.new()
	留白.name = "左库底部留白"
	留白.mouse_filter = Control.MOUSE_FILTER_IGNORE
	留白.size_flags_vertical = Control.SIZE_EXPAND_FILL
	留白.size_flags_stretch_ratio = 100.0
	宿主._左牌库列表.add_child(留白)
	宿主._左牌库滚动 = null

## ★ UI-3：一个分类子区块 = 小标题 +（区块 C 额外的副牌库概览小行）+ 2 列高密度 `GridContainer`…
static func _建左库区块(宿主, 父: Node, 组: String) -> void:
	var 块 := UiTheme.建盒(父, "左库区块-%s" % 组, true, 1) as VBoxContainer
	块.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	块.size_flags_vertical = Control.SIZE_EXPAND_FILL
	块.size_flags_stretch_ratio = 1.0
	块.clip_contents = true
	var 题 = 宿主._建单行标签(块, "左库区块标题-%s" % 组, str(宿主.左库区块题.get(组, 组)), 10, UiTheme.连携色)
	题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	宿主._左库区块节点[组] = 块
	if 组 == "公有副牌库":
		var 概览区 := UiTheme.建盒(块, "左库副牌概览区", true, 0) as VBoxContainer
		概览区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in 宿主.左库概览行数:
			var 行 = 宿主._建单行标签(概览区, "左库副牌概览-%d" % i, "", 9, UiTheme.弱文字)
			行.visible = false
			行.mouse_filter = Control.MOUSE_FILTER_PASS
			宿主._左库副牌概览.append(行)
	var 网 := GridContainer.new()
	网.name = "左库网格-%s" % 组
	网.columns = 2
	网.add_theme_constant_override("h_separation", 3)
	网.add_theme_constant_override("v_separation", 1)
	网.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	网.size_flags_vertical = Control.SIZE_FILL
	块.add_child(网)
	宿主._左库网格们[组] = 网
	var 余 = 宿主._建单行标签(块, "左库余量-%s" % 组, "", 9, UiTheme.弱文字)
	余.visible = false
	余.mouse_filter = Control.MOUSE_FILTER_PASS

## 左栏要列出来的条目（全部来自门面，表现层不自己判能不能打）：
static func _左库条目们(宿主) -> Array:
	var 出: Array = []
	if 宿主.session == null or not 宿主._单机牌组() or 宿主.session.battle_ctx.is_empty():
		return 出
	for c in 宿主.session.upper_hand_cards():
		if c is Dictionary and not bool((c as Dictionary).get("可打", false)):
			出.append(宿主._左库条目(c, "专属"))
	for c in 宿主.session.lower_hand_cards():
		if c is Dictionary and not bool((c as Dictionary).get("可打", false)):
			出.append(宿主._左库条目(c, "公有"))
	for c in 宿主.session.pending_cards():
		if c is Dictionary:
			出.append(宿主._左库条目(c, "待入库"))
	return 出

## 一条左栏条目：`{名, 区, 归属, 状态, 冷却, 描述, 悬停, 来源, 公有}`。
static func _左库条目(宿主, c: Dictionary, 来源: String) -> Dictionary:
	var 区 := str(c.get("区", ""))
	var 冷 := int(JsCompat.js_round(float(c.get("冷却", 0.0))))
	var 原因 := str(c.get("原因", ""))
	var 状 := ""
	if 来源 == "待入库":
		状 = "〔待激活〕%s" % 原因
	elif 冷 > 0:
		状 = "〔%d 回合后进入手牌〕" % 冷
	elif 区 == "主武器卡" and 原因.contains("销毁"):
		状 = "〔本回合已打〕下回合初自动回手"
	elif 原因.is_empty():
		状 = "〔暂不可用〕"
	else:
		状 = "〔暂不可用〕%s" % 原因
	var 鞘 = 宿主.session.卡出鞘文(str(c.get("id", "")))
	if not 鞘.is_empty():
		状 = "%s%s" % [鞘, 状]
	return {"名": str(c.get("名", "")), "区": 区 if not 区.is_empty() else 来源,
		"归属": str(c.get("归属", "")), "状态": 状, "冷却": 冷,
		"描述": str(c.get("描述", "")), "悬停": 宿主._左库悬停(c, 状, 来源), "来源": 来源,
		"公有": bool(c.get("公有", false)), "亮金边": bool(c.get("亮金边", false))}

static func _左库悬停(宿主, c: Dictionary, 状: String, 来源: String) -> String:
	var 段: Array = []
	段.append("【%s】%s" % [str(c.get("区", 来源)), str(c.get("名", ""))])
	段.append("战意消耗：%d" % int(JsCompat.js_round(float(c.get("战意", 0.0)))))
	if not str(c.get("归属", "")).is_empty():
		段.append("归属：%s（%s）" % [str(c.get("归属", "")), str(c.get("层级", ""))])
	var 描 := str(c.get("描述", ""))
	if not 描.is_empty():
		段.append(描)
	段.append("进手牌条件：%s" % 状)
	段.append("现在：打不了（%s）" % str(c.get("原因", "")))
	return "\n".join(段)

## 左栏主体：把条目分进 3 个分类子区块，每块内部 2 列网格平铺。
static func _画左牌库(宿主) -> void:
	if 宿主._左牌库标题 == null:
		return
	if 宿主.session == null or not 宿主._单机牌组() or 宿主.session.battle_ctx.is_empty():
		宿主._左牌库标题.text = "未激活 / 冷却牌库（0 张）"
		宿主._左牌库副标题.text = "（单机牌组模式下才列出冻结的牌）"
		if 宿主._感应牌库按钮 != null:
			宿主._感应牌库按钮.visible = false
		宿主._刷左库副牌概览()
		宿主._摆左库区块({})
		return
	var 条们 = 宿主._左库条目们()
	宿主._左牌库标题.text = "未激活 / 冷却牌库（%d 张）" % 条们.size()
	var 计 = 宿主.session.deck_counts()
	宿主._左牌库副标题.text = "牌库 %d · 弃牌 %d · 待入库 %d　%s" % [
		int(计.get("牌库", 0)), int(计.get("弃牌", 0)), int(计.get("待入库", 0)), 宿主._副牌库徽章文()]
	# ★ COL-4b：感应牌库按钮 + 悬停明细（这一场真装了感应牌库才露）。
	if 宿主._感应牌库按钮 != null:
		var 感 = 宿主.session.感应牌库状态()
		宿主._感应牌库按钮.visible = bool(感.get("有", false))
		宿主._感应牌库按钮.tooltip_text = str(感.get("文案", ""))
	if 宿主._左牌库太阳炉 != null:
		var 炉文 = 宿主.session.太阳炉左栏文()
		宿主._左牌库太阳炉.text = 炉文
		宿主._左牌库太阳炉.visible = not 炉文.is_empty()
		宿主._左牌库太阳炉.tooltip_text = 炉文 if 炉文.is_empty() else ("%s（全队一份、0 费、不占主武器）" % 炉文)
	var 公有待入: Array = []
	var 分 := {}
	for 组 in 宿主.左库区块们:
		分[组] = []
	for e in 条们:
		if str(e.get("来源", "")) == "待入库" and bool(e.get("公有", false)):
			公有待入.append(e)
		else:
			(分[宿主._左库组Of(e)] as Array).append(e)
	宿主._刷左库副牌概览(公有待入)
	宿主._摆左库区块(分)

## ★ UI-3：一条左库条目该归哪个子区块。
static func _左库组Of(宿主, e: Dictionary) -> String:
	var 区 := str(e.get("区", ""))
	var 源 := str(e.get("来源", ""))
	if 区 == "公有牌" or 区 == "连携牌" or 区 == "筹码牌" or 源 == "公有":
		return "公有副牌库"
	if 源 == "待入库" or 区 == "待入库":
		return "公有副牌库" if bool(e.get("公有", false)) else "精神待入库"
	if 区 == "专属精神牌":
		return "精神待入库"
	return "武器大招"

## ★ UI-3：左库卡字号按左栏**总条目数**自适应（条目越多字越小，区间 9~11px）。
static func _左库字号(宿主, 总条数: int) -> int:
	if 总条数 <= 8:
		return 11
	if 总条数 <= 16:
		return 10
	return 9

## ★ UI-3：把三堆条目摆进各自的网格，并按 `max(1, ceil(实际摆出的卡数 / 2.0))` 分区块高度。
static func _摆左库区块(宿主, 分: Dictionary) -> void:
	var 总 := 0
	for 组 in 宿主.左库区块们:
		总 += (分.get(组, []) as Array).size()
	var 字号 = 宿主._左库字号(总)
	var 余行 = 宿主.左库总行预算
	for 组 in 宿主.左库区块们:
		var 网: GridContainer = 宿主._左库网格们.get(组)
		if 网 == null or not is_instance_valid(网):
			continue
		宿主._清空(网)
		var 条: Array = 分.get(组, [])
		var 需行 := int(ceil(float(条.size()) / 2.0))
		var 块行 = mini(需行, 宿主.左库每块最多行)
		if 块行 > 余行:
			块行 = maxi(mini(1, 需行), 余行)
		余行 = maxi(0, 余行 - 块行)
		var 摆出 = mini(条.size(), 块行 * 2)
		for i in 摆出:
			宿主._建左库卡(网, 条[i], 字号)
		if 条.is_empty():
			var 空 = 宿主._建单行标签(网, "左库空提示-%s" % 组, "（空）", 9, UiTheme.弱文字)
			空.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var 块 = 宿主._左库区块节点.get(组)
		if 块 is Control:
			(块 as Control).size_flags_stretch_ratio = float(maxi(1, int(ceil(float(摆出) / 2.0))))
		var 余 = (块 as Node).find_child("左库余量-%s" % 组, true, false) if 块 is Node else null
		if 余 is Label:
			var 另 = 条.size() - 摆出
			if 另 > 0:
				var 名们: Array = []
				for i in range(摆出, 条.size()):
					名们.append(str((条[i] as Dictionary).get("名", "")))
				(余 as Label).text = "…另 %d 张（悬停看全部）" % 另
				(余 as Label).tooltip_text = "、".join(名们)
				(余 as Label).visible = true
				(余 as Label).mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				(余 as Label).text = ""
				(余 as Label).tooltip_text = ""
				(余 as Label).visible = false

## ★ UI-3：区块 C 的「副牌库 / 待入库池可抽卡名概览」——…
static func _刷左库副牌概览(宿主, 公有待入: Array = []) -> void:
	var 行文: Array = []
	if not 公有待入.is_empty():
		var 名们: Array = []
		for e in 公有待入:
			if e is Dictionary:
				名们.append(str((e as Dictionary).get("名", "")))
		var 首 := "、".join(名们.slice(0, mini(6, 名们.size())))
		行文.append("公有待入库 %d 张：%s" % [名们.size(), 首])
	if 宿主.session != null and not 宿主.session.battle_ctx.is_empty():
		var 明细 = 宿主.session.太阳炉明细()
		if not (明细 as Array).is_empty():
			var 名们: Array = []
			for d in 明细:
				if not (d is Dictionary):
					continue
				var 级名 := str((d as Dictionary).get("级名", ""))
				名们.append(str((d as Dictionary).get("名", "")) + ("(%s)" % 级名 if not 级名.is_empty() else ""))
			行文.append("太阳炉 %d 张：%s" % [名们.size(), "、".join(名们)])
		var 链 = 宿主.session.link_library_state()
		if int(链.get("张数", 0)) > 0:
			行文.append(str(链.get("悬停", "")))
		var 筹 = 宿主.session.chip_library_state()
		if bool(筹.get("启用", false)):
			行文.append(str(筹.get("悬停", "")))
	for i in (宿主._左库副牌概览 as Array).size():
		var l: Label = 宿主._左库副牌概览[i]
		if l == null or not is_instance_valid(l):
			continue
		var 有 := i < 行文.size()
		l.text = str(行文[i]) if 有 else ""
		l.visible = 有
		l.tooltip_text = l.text

## 左栏顶部那行「副牌库」徽章：连携牌库（一 / 二 / 三级）+ 筹码牌库。
static func _副牌库徽章文(宿主) -> String:
	if 宿主.session == null:
		return ""
	var 段: Array = []
	var 链 = 宿主.session.link_library_state()
	if int(链.get("张数", 0)) > 0:
		段.append("连携牌库 一%d/二%d/三%d" % [int(链.get("一级", 0)), int(链.get("二级", 0)), int(链.get("三级", 0))])
	var 筹 = 宿主.session.chip_library_state()
	if bool(筹.get("启用", false)):
		段.append(str(筹.get("文案", "")))
	# ★ COL-4：感应牌库（全队一份，一 / 二 / 三级张数 + 移出）。
	var 感应 := str(宿主.session.感应牌库左栏文())
	if 感应 != "":
		段.append(感应)
	return "" if 段.is_empty() else "〔%s〕" % " · ".join(段)

## ★ UI-3：左栏一张高密度小卡（双列网格里的一格）：
static func _建左库卡(宿主, 父: Node, e: Dictionary, 字号: int = 11) -> void:
	var 金边 := bool(e.get("亮金边", false))
	var 卡 := PanelContainer.new()
	卡.name = "左库卡"
	卡.clip_contents = true
	卡.custom_minimum_size = 宿主.左库卡最小
	卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	卡.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ★ COL-4b：未觉醒成员手里那张【觉醒感应】牌在左牌库里也亮金边（它就躺在这儿等觉醒）。
	卡.add_theme_stylebox_override("panel", 宿主._紧面板样式(UiTheme.卡片底,
		UiTheme.金边 if 金边 else UiTheme.边框, 2 if 金边 else 1, 3, 2))
	父.add_child(卡)
	var 列 := UiTheme.建盒(卡, "左库卡内容", true, 0)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 按 := UiTheme.建按钮(列, "【%s】%s" % [str(e.get("区", "")), str(e.get("名", ""))], null)
	按.name = "左库卡按钮"
	按.disabled = true
	按.clip_text = true
	按.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	按.add_theme_font_size_override("font_size", 字号)
	按.add_theme_color_override("font_disabled_color", UiTheme.禁用文字)
	按.add_theme_stylebox_override("disabled", 宿主._紧面板样式(UiTheme.卡片底, UiTheme.边框, 1, 3, 0))
	var l = 宿主._建单行标签(列, "左库卡状态", str(e.get("状态", "")), clampi(字号 - 1, 9, 10), UiTheme.难度色)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	卡.mouse_filter = Control.MOUSE_FILTER_PASS
	var 悬 := str(e.get("悬停", ""))
	HoverTooltip.bind(按, 悬, "战术牌")
	HoverTooltip.bind(卡, 悬, "战术牌")
	卡.set_meta("left_library_entry", e)
	卡.set_meta("gold_edge", 金边)

## ★ UI-3：左栏里**所有** `左库卡`（递归穿过三个子区块 / 网格）—— 自动化测试数卡、量边界用。
static func 左库卡控件们(宿主) -> Array:
	var 出: Array = []
	宿主._收左库卡控件(宿主._左牌库列表, 出)
	return 出

## 递归把 `根` 子树里所有挂 `left_library_entry` meta 的 `左库卡` 收进 `出`（深度优先，顺序稳定）。
static func _收左库卡控件(宿主, 根: Node, 出: Array) -> void:
	if 根 == null or not is_instance_valid(根):
		return
	for c in 根.get_children():
		if c is Node and (c as Node).has_meta("left_library_entry"):
			出.append(c)
			continue
		宿主._收左库卡控件(c, 出)
