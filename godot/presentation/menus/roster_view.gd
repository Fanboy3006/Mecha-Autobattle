## 招募与晋升面板（Stage M4-2）。
##
## 单向数据流：
##   左半 = 手上的招募券（`run_state.tickets`）→ 选中后列 `available_recruit_targets(券下标)`
##          （★带队核心要标出来：名册为空时招第一台直接 Lv20 入队）；
##   右半 = 名册机师 + `promotion_preview(键)`（Lv10 → 20 → 30 的价格与前后属性）。
## 动作只调 `GameSession` 的命令方法：`recruit_unit(键, 券下标)` / `promote_unit(键)`。
class_name RosterView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _选中券: int = 0
var _说明: Label
var _券列表: VBoxContainer
var _候选列表: VBoxContainer
var _名册列表: VBoxContainer
var _决定提示: Label
var _放弃券按钮: Button
var _去编队按钮: Button
## ★ 【完成 · 返回大地图】/【完成招募 · 去编队】（`ticket_count() == 0` 且没有待选牌时才现身）。
var _完成按钮: Button
var _结果: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _券列表 == null:
		return
	var s: RunState = session.run_state if session != null else null
	if s == null:
		_说明.text = "还没有进行中的局 —— 先回主菜单开一局。"
		_清空(_券列表)
		_清空(_候选列表)
		_清空(_名册列表)
		if _决定提示 != null:
			_决定提示.text = ""
		_结果.text = ""
		return
	_说明.text = "希望 %s · 源碳 %s · 名册 %s 台 · 出击上限 %s 台。用券招募（招一台同时吃掉券与希望），或花希望把 Lv10 → 20 → 30 晋升。" % [
		UiTheme.文本(s.hope), UiTheme.文本(s.carbon), UiTheme.文本(s.roster.size()),
		UiTheme.文本(RosterManager.deploy_limit(s))]
	if _选中券 >= s.tickets.size():
		_选中券 = 0
	_建券列表(s)
	_建候选列表(s)
	_建名册列表(s)
	_刷决定行(s)
	_结果.text = _结果文字()

## ★ 决定入口（2026-10-16 作者试玩反馈「招募券要求做出决定才能进入下一个选择」）：
##   有券时醒目提示「必须做出决定」，并把【放弃此券】放开；
##   ★ 2026-10-18：券全部决定完 + 没有待选牌之后，把
##   【完成 · 返回大地图】（刚开局 0 场战斗时是【完成招募 · 去编队】）换成**唯一**现身的那颗醒目按钮；
##   还有券时它藏起来（继续走【去编队出击】那条不关窗的路）。
func _刷决定行(s: RunState) -> void:
	var 券数 := s.tickets.size()
	var 待选 := s.pending_card_picks.size()
	var 完事 := 券数 == 0 and 待选 == 0
	if _决定提示 != null:
		if 券数 > 0:
			_决定提示.text = "★ 当前有 %d 张招募券待决定：请点击下方候选机体招募，或点击【放弃此券】。" % 券数
			_决定提示.add_theme_color_override("font_color", UiTheme.高亮)
		elif 待选 > 0:
			_决定提示.text = "★ 还有 %d 次「三选一」没选完 —— 先把它选掉。" % 待选
			_决定提示.add_theme_color_override("font_color", UiTheme.高亮)
		else:
			_决定提示.text = "★ 招募券已经全部决定完 —— 点下面的按钮收尾，再去大地图开打。"
			_决定提示.add_theme_color_override("font_color", UiTheme.正面)
	if _放弃券按钮 != null:
		_放弃券按钮.disabled = 券数 <= 0
		_放弃券按钮.tooltip_text = "丢掉当前选中的这张招募券（只写一条日志，不退不换）%s" % \
			("" if 券数 > 0 else "（现在手上没有券）")
	if _去编队按钮 != null:
		_去编队按钮.visible = 券数 > 0
		_去编队按钮.add_theme_color_override("font_color", UiTheme.高亮 if 券数 == 0 else UiTheme.次要文字)
		_去编队按钮.tooltip_text = ("券都决定完了：关掉招募窗并切到编队屏摆出击位%s"
			% "（推荐走这一步）") if 券数 == 0 else "手上还有 %d 张券没决定；也可以先去编队屏看看" % 券数
	if _完成按钮 != null:
		_完成按钮.visible = 完事
		if 完事:
			var 刚开局 := session != null and session.还没走过格()
			_完成按钮.text = "完成招募 · 去编队" if 刚开局 else "完成 · 返回大地图"
			_完成按钮.tooltip_text = ("刚开局、还没打过一场：去编队屏把出击位摆好%s" % "（推荐走这一步）") if 刚开局 \
				else "这一轮的招募处理完了，关掉面板回大地图继续走"

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "招募面板"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "名册上下列", true, UiTheme.间距_小)
	UiTheme.占满留边(列)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	var 主体 := UiTheme.建盒(列, "名册主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var 左列 := UiTheme.建盒(主体, "招募左列", true, UiTheme.间距_小)
	左列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	左列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(左列, "手上的招募券", UiTheme.字号_小节, UiTheme.高亮)
	_券列表 = UiTheme.建滚动(左列, "券列表", 160.0)
	UiTheme.建标签(左列, "这张券能招谁", UiTheme.字号_小节, UiTheme.高亮)
	_候选列表 = UiTheme.建滚动(左列, "候选列表", 220.0)

	var 右列 := UiTheme.建盒(主体, "招募右列", true, UiTheme.间距_小)
	右列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	右列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(右列, "名册与晋升", UiTheme.字号_小节, UiTheme.高亮)
	_名册列表 = UiTheme.建滚动(右列, "名册列表", 380.0)

	# ★ 决定入口（作者试玩反馈：招募券必须「做出决定」）：放弃这张券 / 券决定完去编队。
	_决定提示 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.高亮)
	_决定提示.name = "招募决定提示"
	var 决定行 := UiTheme.建盒(列, "招募决定行", false, UiTheme.间距)
	_放弃券按钮 = UiTheme.建按钮(决定行, "放弃此券", _点放弃券)
	_放弃券按钮.name = "放弃此券按钮"
	_去编队按钮 = UiTheme.建按钮(决定行, "去编队出击", _点去编队)
	_去编队按钮.name = "去编队出击按钮"
	# ★ 2026-10-18：只保留**名字**（`find_child("去编队出击按钮")` 的老断言照旧找得到），
	#   显示与否交给 `_刷决定行()` —— 券全部决定完时它让位给下面那颗【完成 · 返回大地图】。
	_去编队按钮.visible = false
	_完成按钮 = UiTheme.建按钮(决定行, "完成 · 返回大地图", _点完成)
	_完成按钮.name = "完成返回地图按钮"
	_完成按钮.visible = false
	_完成按钮.add_theme_color_override("font_color", UiTheme.正面)

	_结果 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)
	_结果.name = "招募结果行"

# ==========================================================================================
# 券列表
# ==========================================================================================

func _建券列表(s: RunState) -> void:
	_清空(_券列表)
	if s.tickets.is_empty():
		UiTheme.建标签(_券列表, "手上没有招募券。开局会发券，作战 / 精英 / Boss 战后也可能掉；招募站那一格也发。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in s.tickets.size():
		var 券: Variant = s.tickets[i]
		var 名 := RosterManager.券名(券)
		var 可招 := RosterManager.券合机师们(券).size()
		var 标记 := "◆ " if i == _选中券 else ""
		var b := UiTheme.建按钮(_券列表, "%s%s（可招 %d 位）" % [标记, 名, 可招], _点券.bind(i))
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.tooltip_text = "%s\n来源：%s\n用掉它就少一张 —— 招募与晋升共用券池" % [
			RosterManager.券文字(券), str((券 as Dictionary).get("来源", "未知"))]

func _点券(下标: int) -> void:
	_选中券 = 下标
	refresh()

# ==========================================================================================
# 候选列表（★带队核心直上 Lv20）
# ==========================================================================================

func _建候选列表(s: RunState) -> void:
	_清空(_候选列表)
	if s.tickets.is_empty():
		UiTheme.建标签(_候选列表, "先有一张券，这里才会列出能招的机师。", UiTheme.字号_小, UiTheme.弱文字)
		return
	var 候选 := session.available_recruit_targets(_选中券)
	if 候选.is_empty():
		UiTheme.建标签(_候选列表, "这张券现在招不到人（对应的机师可能都已经在名册里了）。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for 条 in 候选:
		if not (条 is Dictionary):
			continue
		var 键 := str(条.get("键", ""))
		var 带队 := bool(条.get("带队核心", false))
		var 标记 := "★带队核心 " if 带队 else ""
		var b := UiTheme.建按钮(_候选列表, "%s%s（%s · %s · %s 档）" % [标记, str(条.get("名", 键)),
			str(条.get("职业", "")), str(条.get("势力", "")), RosterManager.档名(键)], _点招募.bind(键))
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		var 费 := int(条.get("费", 0)) if 条.get("费") != null else 0
		b.tooltip_text = "%s入队 Lv%s · 花 %d 希望 + 1 张券" % [
			"★带队核心：这一台直接 Lv20（分队特权）\n" if 带队 else "", UiTheme.文本(条.get("等级", 10)), 费]
		# ★ Mouse Over：这台候选机体的整段说明（门面 `template_unit_hover_text`）
		HoverTooltip.bind(b, session.template_unit_hover_text(键, int(条.get("等级", 10))), "机体")

func _点招募(键: String) -> void:
	if session == null:
		return
	session.recruit_unit(键, _选中券)

## ★ 决定之二：不想要这张券的候选机体 → 明确放弃它（门面 `discard_ticket()`，内核只写一条日志）。
## 重画不做：`discard_ticket()` 内部 `_emit()` → `boot.route()` → 弹窗层**原地** `refresh()` 这个视图。
func _点放弃券() -> void:
	if session == null:
		return
	session.discard_ticket(_选中券)

## ★ 券全部决定完之后的那一步：关掉招募弹窗 + 切到编队屏
##   （两个信号都由 `ModalLayer._接信号` 转给 `boot` 的 `关闭弹窗` / `去屏`）。
func _点去编队() -> void:
	请求关闭弹窗.emit()
	请求屏幕.emit("formation")

## ★ 2026-10-18：【完成 · 返回大地图】/【完成招募 · 去编队】。
##   只有「手上 0 张券 + 0 次待选牌」时才现身 —— 刚开局 0 场战斗时去编队，否则直接回大地图。
func _点完成() -> void:
	请求关闭弹窗.emit()
	if session != null and session.还没走过格():
		请求屏幕.emit("formation")
		return
	请求屏幕.emit("map")

# ==========================================================================================
# 名册列表（五维 + 晋升预览）
# ==========================================================================================

func _建名册列表(s: RunState) -> void:
	_清空(_名册列表)
	if s.roster.is_empty():
		UiTheme.建标签(_名册列表, "名册还是空的。先用券招一台 —— 第一台是带队核心，直接 Lv20 入队。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for 键 in s.roster.keys():
		var k := str(键)
		var 模板 := RosterManager.模板(k)
		var 名 := str(模板.get("名", k))
		var 标签 := RosterManager.标签(k)
		var 级 := s.get_unit_level(k)
		var 血比 := s.get_unit_hp_ratio(k)
		var box := UiTheme.建盒(_名册列表, "名册条_" + k, true, 2)
		var 头 := UiTheme.建标签(box, "%s · Lv%s · %s · %s · HP %s%%" % [名, UiTheme.文本(级),
			str(标签.get("战斗分类", "")), str(标签.get("势力", "")),
			UiTheme.文本(int(JsCompat.js_round(血比 * 100.0)))], UiTheme.字号_小, UiTheme.主文字)
		头.tooltip_text = "HP 比例来自名册记录（跨战继承）"
		# ★ Mouse Over：这台**已有机体**的整段说明（门面 `template_unit_hover_text`）
		var 悬停 := session.template_unit_hover_text(k, 级)
		HoverTooltip.bind(box, 悬停, "机体")
		HoverTooltip.bind(头, 悬停, "机体")
		var 预 := session.promotion_preview(k)
		if not bool(预.get("ok", false)):
			UiTheme.建标签(box, "升不了：%s" % str(预.get("why", "到顶了")), UiTheme.字号_小, UiTheme.弱文字)
			continue
		var 前维: Dictionary = 预.get("前", {}) if 预.get("前") is Dictionary else {}
		var 后维: Dictionary = 预.get("后", {}) if 预.get("后") is Dictionary else {}
		UiTheme.建标签(box, "现在　%s" % _五维文字(前维), UiTheme.字号_小, UiTheme.次要文字)
		UiTheme.建标签(box, "Lv%s 后 %s" % [UiTheme.文本(预.get("到", 0)), _五维文字(后维)], UiTheme.字号_小, UiTheme.正面)
		var 能升 := bool(预.get("能升", false))
		var 价 := int(预.get("价", 0))
		var 理由 := ""
		if not 能升:
			var 缺券 := not bool(预.get("有券", false))
			var 缺希望 := int(预.get("希望", 0)) < 价
			var 段: Array = []
			if 缺券:
				段.append("没有同类券")
			if 缺希望:
				段.append("希望不够：要 %d，只有 %d" % [价, int(预.get("希望", 0))])
			if 段.is_empty():
				段.append("现在升不了")
			理由 = "（%s）" % "；".join(段)
		var b := UiTheme.建按钮(box, "晋升到 Lv%s（−%d 希望 + 1 张同类券）%s" % [
			UiTheme.文本(预.get("到", 0)), 价, 理由], _点晋升.bind(k))
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.disabled = not 能升
		b.tooltip_text = "同职业 / 同势力的券都算；休整选「晋升」会让下一次减 1 希望"
		HoverTooltip.bind(b, 悬停, "机体")

func _点晋升(键: String) -> void:
	if session == null:
		return
	session.promote_unit(键)

# ==========================================================================================
# 小工具
# ==========================================================================================

func _五维文字(v: Dictionary) -> String:
	if v.is_empty():
		return "（没有属性数据）"
	return "HP %s · 装甲 %s · 防御 %s · 机动 %s · 速度 %s" % [
		UiTheme.文本(v.get("maxHp", 0)), UiTheme.文本(v.get("armor", 0)), UiTheme.文本(v.get("defense", 0)),
		UiTheme.文本(v.get("mov", 0)), UiTheme.文本(v.get("速度", 0))]

## 上一动作的即时反馈（数值全部来自 `session.last`，表现层不自己算）。
func _结果文字() -> String:
	if session == null:
		return ""
	var 末 := session.last
	var 行动 := str(末.get("行动", ""))
	match 行动:
		"招募":
			return "招到了：%s Lv%s（花 %s 希望；券 %s → %s；名册 %s → %s）%s" % [
				str(末.get("键", "")), UiTheme.文本(末.get("等级", 0)), UiTheme.文本(末.get("费", 0)),
				UiTheme.文本(末.get("券前", 0)), UiTheme.文本(末.get("券后", 0)),
				UiTheme.文本(末.get("名册前", 0)), UiTheme.文本(末.get("名册后", 0)),
				"　★带队核心直接 Lv20" if bool(末.get("带队核心", false)) else ""]
		"晋升":
			return "晋升成功：%s Lv%s → Lv%s（−%s 希望，剩 %s）" % [str(末.get("键", "")),
				UiTheme.文本(末.get("从", 0)), UiTheme.文本(末.get("到", 0)),
				UiTheme.文本(末.get("价", 0)), UiTheme.文本(末.get("希望", 0))]
		"丢券":
			return "放弃了一张「%s」（券 %s → %s；名册还是 %s 台）" % [str(末.get("券名", "")),
				UiTheme.文本(末.get("券前", 0)), UiTheme.文本(末.get("券后", 0)),
				UiTheme.文本(末.get("名册", 0))]
	if not session.当前动作错误().is_empty():
		return "上一次没做成：%s" % UiTheme.文本(session.当前动作错误())
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
