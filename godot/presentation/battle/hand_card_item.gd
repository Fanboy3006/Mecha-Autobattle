## 职责：一张手牌 / 单机牌卡面的构建、字号自适应、悬停文案与点击打出（含卡面文字行）。
extends RefCounted

## 阶段代码 → 中文（只做展示，不改状态）。
static func _阶段中文(宿主, 阶段: String) -> String:
	match 阶段:
		"PLAYER_START":
			return "我方阶段开始"
		"PLAYER_MAIN":
			return "我方阶段"
		"ENEMY_PHASE":
			return "敌方阶段"
	return 阶段 if not 阶段.is_empty() else "—"

## ★ DECK-3：一张单机手牌卡（紧凑三行：牌名按钮 + 状态行 + 关键信息行）。
static func _建单机卡(宿主, 父: Node, c: Dictionary, 上排: bool, idx: int, 同栏张数: int = 0) -> void:
	var 区 := str(c.get("区", ""))
	var 可打 := bool(c.get("可打", false))
	var 边色 := UiTheme.边框
	var 主色 := UiTheme.禁用文字
	if 可打:
		边色 = UiTheme.高亮
		主色 = UiTheme.高亮
	if 区 == "衍生攻击卡":
		边色 = UiTheme.连携色 if 可打 else UiTheme.边框
		主色 = UiTheme.连携色 if 可打 else UiTheme.禁用文字
	elif 区 == "专属精神牌":
		边色 = UiTheme.希望色 if 可打 else UiTheme.边框
		主色 = UiTheme.希望色 if 可打 else UiTheme.禁用文字
	elif 区 == "公有牌":
		边色 = UiTheme.边框_亮 if 可打 else UiTheme.边框
		主色 = UiTheme.高亮 if 可打 else UiTheme.禁用文字
	elif 区 == "连携牌":
		边色 = UiTheme.连携色 if 可打 else UiTheme.边框
		主色 = UiTheme.连携色 if 可打 else UiTheme.禁用文字
	elif 区 == "筹码牌":
		边色 = UiTheme.希望色 if 可打 else UiTheme.边框
		主色 = UiTheme.希望色 if 可打 else UiTheme.禁用文字
	if bool(c.get("连携就绪", false)):
		边色 = UiTheme.希望色
		主色 = UiTheme.希望色
# ★ COL-4b：未觉醒成员手里的【觉醒感应】牌亮金边（判据在门面 `亮金边`，这里只上色）。
	var 金边 := bool(c.get("亮金边", false))
	if 金边:
		边色 = UiTheme.金边
		主色 = UiTheme.金边
	var 卡 := PanelContainer.new()
	卡.name = ("专属卡%d" if 上排 else "公有卡%d") % (idx + 1)
	卡.custom_minimum_size = 宿主.单机卡最小
	卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	卡.size_flags_vertical = Control.SIZE_EXPAND_FILL
	卡.clip_contents = true
	var 卡样 := UiTheme.底样式(UiTheme.卡片底_亮 if 可打 else UiTheme.卡片底, 边色, 2 if (可打 or 金边) else 1)
	卡样.content_margin_left = 2
	卡样.content_margin_right = 2
	卡样.content_margin_top = 1
	卡样.content_margin_bottom = 1
	卡.add_theme_stylebox_override("panel", 卡样)
	父.add_child(卡)
	var 列 := UiTheme.建盒(卡, "单机卡内容", true, 1)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 字号 = 宿主._单机卡字号(同栏张数, 11 if 上排 else 12)
	var 名 := str(c.get("名", ""))
	var 键 := str(c.get("手牌键", 名))
	var 按 = UiTheme.建按钮(列, 名, 宿主._点单机卡.bind(区, 键, 上排))
	按.name = "单机卡按钮"
	按.disabled = not 可打
	按.clip_text = true
	按.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	按.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	按.add_theme_color_override("font_color", 主色)
	按.add_theme_color_override("font_disabled_color", UiTheme.禁用文字)
	按.add_theme_font_size_override("font_size", 字号)
	宿主._套紧按钮样式(按, 边色 if 金边 else (主色 if 可打 else UiTheme.边框))
	var 副 = 宿主._单机卡副行(c, 区)
	var 按悬 = 宿主._单机卡悬停(c, 区)
	按.tooltip_text = 按悬
	按.set_meta("unit_card_data", c)
	var l = 宿主._建裁切标签(列, "单机卡状态", 副, 字号, 主色)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	var l2 = 宿主._建裁切标签(列, "单机卡信息", 宿主._单机卡信息行(c, 区), 字号, 主色)
	l2.mouse_filter = Control.MOUSE_FILTER_PASS
	卡.mouse_filter = Control.MOUSE_FILTER_PASS
	HoverTooltip.bind(按, 按悬, "战术牌")
	HoverTooltip.bind(卡, 按悬, "战术牌")
	卡.set_meta("unit_card_data", c)
	卡.set_meta("gold_edge", 金边)
	按.set_meta("unit_card_data", c)
	按.button_down.connect(宿主._单机卡按下.bind(区, 键, 上排, 卡))
	按.button_up.connect(宿主._单机卡松开.bind(区, 键, 上排, 卡))
	按.mouse_entered.connect(宿主._悬停单机卡.bind(卡))
	按.mouse_exited.connect(宿主._移开单机卡)
	卡.mouse_entered.connect(宿主._悬停单机卡.bind(卡))
	卡.mouse_exited.connect(宿主._移开单机卡)

## ★ UI-1：一张单机卡的字号 —— 张数越多越小（12 / 11 / 10），保证再挤也看得全。
static func _单机卡字号(宿主, 同栏张数: int, 上限: int = 12) -> int:
	if 同栏张数 <= 4:
		return mini(上限, 12)
	if 同栏张数 <= 6:
		return mini(上限, 11)
	return 10

## ★ UI-1：卡面固定一行的裁切标签（`clip_text` + 省略号；高度**钉死**为一行，绝不把版面顶开）。
static func _建裁切标签(宿主, 父: Node, 名: String, 文本: String, 字号: int, 色: Color) -> Label:
	var l := UiTheme.建标签(父, 文本, 字号, 色)
	l.name = 名
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 1
	l.custom_minimum_size = Vector2(0, 宿主._字号行高(字号))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l

## 这个字号在项目字体里的**真实行高**（拿不到字体时退回 `字号 + 8`）。
static func _字号行高(宿主, 字号: int) -> float:
	var 字 := ThemeDB.fallback_font
	if 宿主.is_inside_tree():
		var f = 宿主.get_theme_font("font")
		if f != null:
			字 = f
	if 字 == null:
		return float(字号 + 8)
	return ceilf(字.get_height(字号)) + 1.0

## ★ UI-1：把手牌按钮的四套样式全换成 1px 内边距的紧样式（默认主题的内边距会吃掉一行高度）。
static func _套紧按钮样式(宿主, 按: Button, 边色: Color) -> void:
	var 普 = 宿主._紧面板样式(UiTheme.卡片底_亮, 边色, 1, 2, 1)
	var 悬 = 宿主._紧面板样式(UiTheme.卡片底_亮, UiTheme.高亮, 1, 2, 1)
	var 压 = 宿主._紧面板样式(UiTheme.卡片底, UiTheme.高亮, 1, 2, 1)
	按.add_theme_stylebox_override("normal", 普)
	按.add_theme_stylebox_override("hover", 悬)
	按.add_theme_stylebox_override("pressed", 压)
	按.add_theme_stylebox_override("disabled", 普)
	按.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## ★ UI-1：单机卡的第三行 —— 一行写清「费用 · 威力 / 段数 · 简短效果」。
static func _单机卡信息行(宿主, c: Dictionary, 区: String) -> String:
	var 段: Array = []
	if 区 == "连携牌" or 区 == "筹码牌":
		段.append("0 费")
	else:
		段.append("费 %d" % int(JsCompat.js_round(float(c.get("战意", 0.0)))))
	var 威 := int(JsCompat.js_round(float(c.get("威力", 0.0))))
	if 威 > 0:
		var 段数 := int(JsCompat.js_round(float(c.get("段数", 1.0))))
		段.append("威力 %d%s" % [威, ("×%d" % 段数) if 段数 > 1 else ""])
	elif bool(c.get("是修理", false)) or str(c.get("种类", "")) == "应急补丁":
		段.append("修理")
	var 描 := str(c.get("描述", ""))
	if not 描.is_empty():
		段.append(描)
	elif not str(c.get("归属", "")).is_empty():
		段.append(str(c.get("归属", "")))
	return " · ".join(段)

## 单机卡的第二行（一行写清：费用 + 状态 / 原因）。
static func _单机卡副行(宿主, c: Dictionary, 区: String) -> String:
	var 费 := int(JsCompat.js_round(float(c.get("战意", 0.0))))
	var 原因 := str(c.get("原因", ""))
	var 距 := str(c.get("距离", ""))
	if 区 == "主武器卡":
		var 状 := "〔主武就绪〕"
		if not bool(c.get("可打", false)):
			if 原因.contains("销毁"):
				状 = "〔本回合已销毁〕"
			elif 原因.contains("冷却"):
				状 = "〔冷却中〕"
			else:
				状 = "〔打不出来〕"
		elif bool(c.get("单机牌组_铁壁")):
			状 = "〔铁壁护卫〕"
		elif bool(c.get("是修理")):
			状 = "〔紧急修理〕"
		return "战意 %d · %s · %s%s" % [费, 状, (距 + " · ") if not 距.is_empty() else "", 原因]
	if 区 == "副武器卡":
		return "〔副武器 · 不毁主武 %d/%d〕%s%s" % [
			int(c.get("已用", 0)), int(c.get("可用", 1)),
			(距 + " · ") if not 距.is_empty() else "", 原因]
	if 区 == "大招槽卡":
		var 冷 := int(JsCompat.js_round(float(c.get("冷却", 0.0))))
		var 标 := "〔大招〕"
		if bool(c.get("本回合已打", false)):
			标 = "〔本回合已打〕"
		elif 冷 > 0:
			标 = "〔冷却 %d 回合〕" % 冷
		elif not bool(c.get("已解锁", false)):
			标 = "〔未解锁〕"
		elif not bool(c.get("武器牌", false)):
			标 = "〔大招 · 非武器〕"
		elif bool(c.get("武器牌", false)):
			标 = "〔大招 · 武器牌〕"
		return "战意 %d · %s · %s%s" % [费, 标, (距 + " · ") if not 距.is_empty() else "", 原因]
	if 区 == "连携牌":
		return "〔连携 %d 级 · 0 费 · 不占主武〕%s" % [int(c.get("连携等级", 0)), 原因]
	if 区 == "筹码牌":
		var 级 := int(c.get("筹码等级", 0))
		var 档 := "头奖" if 级 >= 3 else ("大筹码" if 级 == 2 else "小筹码")
		var 去 := "移出本场" if 级 >= 3 else "回筹码牌库"
		return "〔筹码·%s · 0 费 · 不占主武 · %s〕%s" % [档, 去, 原因]
	if 区 == "衍生攻击卡":
		return "〔衍生·不毁主武〕战意 %d · %s" % [费, 原因]
	if 区 == "公有牌":
		var 减 := int(JsCompat.js_round(float(c.get("减费", 0.0))))
		if 减 > 0:
			return "战意 %d（原 %d，指挥 -%d）· %s" % [费, int(JsCompat.js_round(float(c.get("原费", 0.0)))), 减, 原因]
		return "战意 %d · %s%s" % [费, ("〔衍生〕" if bool(c.get("是衍生", false)) else ""), 原因]
	return "战意 %d · %s" % [费, 原因]

## 单机卡的悬停说明（整张牌：区 / 费用 / 状态 / 描述 / 归属）。
static func _单机卡悬停(宿主, c: Dictionary, 区: String) -> String:
	var 段: Array = []
	段.append("【%s】%s" % [区, str(c.get("名", ""))])
	段.append("战意消耗：%d" % int(JsCompat.js_round(float(c.get("战意", 0.0)))))
	if c.get("归属") != null and not str(c.get("归属", "")).is_empty():
		段.append("归属：%s（%s）" % [str(c.get("归属", "")), str(c.get("层级", ""))])
	var 描 := str(c.get("描述", ""))
	if not 描.is_empty():
		段.append(描)
	段.append("现在：%s（%s）" % ["能打" if bool(c.get("可打", false)) else "打不了", str(c.get("原因", ""))])
	return "\n".join(段)

## ★ DECK-3：点一张单机手牌 → 立刻走内核那三个口子之一，然后**马上播这一下的 0.5 秒演出**。
static func _点单机卡(宿主, 区: String, 键: String, 上排: bool) -> void:
	var c = 宿主._单机卡数据(键)
	if 宿主._必须拖动到友军(c, 区):
		宿主._回话("请按住【%s】拖动到上方我方机体上释放（绿色箭头指向目标）" % str(c.get("名", 键)), true)
		宿主.refresh()
		宿主._亮友军可投放(宿主.友军提示停留秒)
		return
	宿主._打单机卡(区, 键, 上排, "")

## 出牌执行体（点击 / 拖放两条路都走这里）。返回门面结果字典（`ok` / `成功` / `为什么`）。
static func _打单机卡(宿主, 区: String, 键: String, 上排: bool, 目标键: String) -> Dictionary:
	if 宿主.session == null:
		return {"ok": false, "为什么": "现在没有会话"}
	# ★ COL-4b：QTE = 手动选择时，武器型觉醒大招**先弹三档**；选完（`_QTE本次选择` 非空）才真结算。
	if 宿主._QTE本次选择 == "" and 宿主.需QTE弹窗(宿主._单机卡数据(键)):
		宿主._弹QTE弹窗(区, 键, 上排, 目标键)
		return {"ok": false, "为什么": "等你在 QTE 弹窗里选一档", "等待QTE": true}
	宿主._表演中止(false)
	var 前日志 = 宿主.session.battle_log_entries(0).size()
	var 前手 = 宿主._手牌快照()
	宿主._演出预热 = true
	var r := {}
	if 区 == "主武器卡":
		r = 宿主.session.play_unit_main_weapon(键, 目标键)
	elif 区 == "副武器卡":
		r = 宿主.session.play_unit_sub_weapon(键, 目标键)
	elif 区 == "大招槽卡":
		if 宿主._QTE本次选择 != "":
			r = 宿主.session.play_unit_ultimate_qte(键, 目标键, 宿主._QTE本次选择)
		else:
			r = 宿主.session.play_unit_ultimate(键, 目标键)
	elif 区 == "连携牌":
		r = 宿主.session.play_link_card(键, 目标键)
	elif 区 == "衍生攻击卡":
		r = 宿主.session.play_unit_derived_card(键, 目标键)
	elif 区 == "筹码牌":
		r = 宿主.session.play_unit_spirit_or_public_card(键, 目标键)
	else:
		r = 宿主.session.play_unit_spirit_or_public_card(键, 目标键)
	宿主._演出预热 = false
	if not bool(r.get("ok", false)):
		宿主._回话("打不出来：%s" % 宿主._为什么(r), false)
		宿主.refresh()
		return r
	宿主._回话("打出【%s】%s（战意 %s → %s）" % [str(宿主.session.last.get("牌", 键)),
		"" if 目标键.is_empty() else " → %s " % 目标键,
		UiTheme.文本(宿主.session.last.get("战意前", 0.0)), UiTheme.文本(宿主.session.last.get("战意后", 0.0))], true)
	宿主._演本拍新增(前日志, 前手)
	return r

static func _卡牌参数(宿主) -> Dictionary:
	var b := Db.catalog.battle_config()
	var t: Variant = b.get("战术卡牌")
	return t if t is Dictionary else {}
