## 弹窗层（Stage M4-2）—— **所有弹窗都走这一个层**，不要每屏各弹各的。
##
## 数据源：`GameSession.modal` = `{"类型": String, "数据": Variant}`。
##   类型 为 三选一 / 招募 / 晋升 / 黑市 / 休整 / 奇遇 / 结算 / 战术牌库 / 战斗。
## 空字典 = 关掉。
##
## 纪律：本层**不画业务数值**，只把对应视图挂进来并把它的三个信号转发给 boot：
##   `请求弹窗` / `请求屏幕` / `请求关闭弹窗`（关窗就是 `session.modal = {}`，由 boot 执行）。
class_name ModalLayer
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _黑幕: ColorRect
var _面板: PanelContainer
var _标题: Label
var _关闭: Button
var _内容: VBoxContainer
var _当前类型: String = ""
## ★ 当前这个弹窗是不是「必须先做出决定」（决定之前不给关）—— 由 `_是必须做决定的()` 算。
var _必须决定: bool = false
## 当前挂着的视图。**特意不标 `Control`** —— 基类上没有 `refresh`，动态调才不会撞类型检查。
var _当前视图: Variant = null

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()
	refresh()

func refresh() -> void:
	if _面板 == null:
		return
	var 类型 := _应该弹的类型()
	if 类型.is_empty():
		_收起()
		return
	visible = true
	_标题.text = 标题Of(类型)
	# ★ 2026-10-16（作者试玩反馈「出现招募券要求做出决定才能进入下一个选择」）：
	#   招募类型在「名册空 + 手上还有券」时**不给关** —— 一关就直接进大地图 0 机体裸奔。
	_必须决定 = _是必须做决定的(类型)
	_关闭.visible = 类型 != "三选一" and not _必须决定
	if _必须决定:
		_标题.tooltip_text = "名册是空的、或手上券超过 %d 张：先招募或按【放弃此券】才能离开这个面板" % RosterManager.券留存上限()
	else:
		_标题.tooltip_text = ""
	if 类型 != _当前类型:
		_换内容(类型)
	_当前类型 = 类型
	if _当前视图 != null:
		_当前视图.refresh()

## 这一层其实是个覆盖全屏的 `Control`，自己不需要吃点击事件（黑幕会吃）。
func _build() -> void:
	name = "弹窗层"
	UiTheme.占满(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_黑幕 = ColorRect.new()
	_黑幕.name = "弹窗黑幕"
	_黑幕.color = UiTheme.黑幕
	UiTheme.占满(_黑幕)
	_黑幕.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_黑幕)

	var 居中 := CenterContainer.new()
	居中.name = "弹窗居中"
	UiTheme.占满(居中)
	居中.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(居中)

	_面板 = UiTheme.建面板(居中, "弹窗面板", UiTheme.面板底, UiTheme.边框_亮)
	# ★ 尺寸纪律：最小 820×480、由内容自然长大但**绝不越过 1160×620**
	#   （内部各视图的说明一律走 `UiTheme.建说明`（自动换行）+ `ScrollContainer`，
	#    单行长文本再也不会把面板撑到 1075px 宽）。
	_面板.custom_minimum_size = Vector2(820, 480)
	_面板.clip_contents = true

	var 列 := UiTheme.建盒(_面板, "弹窗上下列", true, UiTheme.间距)
	var 标题行 := UiTheme.建盒(列, "弹窗标题行", false, UiTheme.间距)
	_标题 = UiTheme.建标题(标题行, "弹窗", UiTheme.字号_标题)
	_标题.name = "弹窗标题"
	_标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_关闭 = UiTheme.建按钮(标题行, "关闭", _点关闭)
	_关闭.name = "关闭按钮"
	_关闭.tooltip_text = "关掉这个面板（已经做过的事不会退回去）"
	UiTheme.建分隔(列)
	_内容 = UiTheme.建盒(列, "弹窗内容", true, UiTheme.间距_小)
	_内容.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_内容.clip_contents = true
	visible = false

# ==========================================================================================
# 内容视图
# ==========================================================================================

func 标题Of(类型: String) -> String:
	match 类型:
		"三选一":
			return "战术牌构筑 · 三选一"
		"招募":
			return "名册 · 招募机师"
		"晋升":
			return "名册 · 晋升"
		"黑市":
			return "黑市"
		"休整":
			return "休整"
		"奇遇", "事件":
			return "奇遇"
		"结算":
			return "战后结算"
		"战术牌库":
			return "战术牌库"
		"战斗":
			return "战斗提示"
	return "面板"

func _换内容(类型: String) -> void:
	_清空(_内容)
	_当前视图 = null
	# 无类型标注 = Variant → 动态调视图的 setup/refresh（各视图类自己声明那两个入口）
	var v = _造视图(类型)
	if v != null:
		_接信号(v)
		# ★ 视图外面套一层**有界**的滚动区：视图自己再高的最小尺寸也只让内容滚，
		#   不会把 `弹窗面板` 顶过 1160×620（`ScrollContainer` 的最小高度 = `custom_minimum_size`）。
		var 滚 := ScrollContainer.new()
		滚.name = "弹窗滚动"
		滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		滚.clip_contents = true
		滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
		滚.custom_minimum_size = Vector2(0, 400)
		_内容.add_child(滚)
		滚.add_child(v)
		v.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if session != null:
			v.setup(session)
		_当前视图 = v
		return
	_填内置内容(类型)

func _造视图(类型: String) -> Variant:
	match 类型:
		"三选一":
			return PickCardView.new()
		"招募", "晋升":
			return RosterView.new()
		"黑市":
			return ShopView.new()
		"休整":
			return RestView.new()
		"奇遇", "事件":
			return EventView.new()
		"结算":
			return ResultView.new()
	return null

## 只有「没有专属视图」的类型才在这里现画（战术牌库 / 战斗提示 / 认不出来的类型）。
## ★ 一律塞进 `ScrollContainer` + 用会自动换行的 `UiTheme.建说明`（长文本不许把面板撑宽）。
func _填内置内容(类型: String) -> void:
	if session == null:
		return
	var 滚 := ScrollContainer.new()
	滚.name = "内置滚动"
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 360)
	_内容.add_child(滚)
	var 盒 := UiTheme.建盒(滚, "内置内容", true, UiTheme.间距_小)
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if 类型 == "战术牌库":
		var 牌库: Array = []
		if session.run_state != null:
			牌库 = session.run_state.tactical_deck
		if 牌库.is_empty():
			UiTheme.建说明(盒, "牌库里还没有战术牌。招募 / 晋升机师时会弹三选一，选到的牌进这里。", UiTheme.字号_正文, UiTheme.次要文字)
			return
		for id in 牌库:
			var c := DeckBuilder.找到(UiTheme.文本(id))
			var l := UiTheme.建说明(盒, "【%s】%s · %s" % [UiTheme.文本(c.get("名", id)), UiTheme.文本(c.get("层级", "")), UiTheme.文本(c.get("归属", ""))],
				UiTheme.字号_正文, UiTheme.高亮)
			# ★ Mouse Over：整张牌的说明（耗气 / 冷却 / 限次 / 触发 / 效果 / 当前手牌状态）
			var 说明 := session.card_hover_text(c if not c.is_empty() else UiTheme.文本(id))
			l.tooltip_text = 说明
			HoverTooltip.bind(l, 说明, "战术牌")
		return
	if 类型 == "战斗":
		UiTheme.建说明(盒, "手牌打不出来的时候看一眼：一张牌能不能打，只看「气势够不够 / 冷却到没到 / 剩余次数还有没有」—— 内核没有「每回合最多打几张」这条规则。",
			UiTheme.字号_小节, UiTheme.高亮)
		return
	UiTheme.建说明(盒, "认不出来的弹窗类型（%s）。" % 类型, UiTheme.字号_正文, UiTheme.负面)

func _接信号(v: Control) -> void:
	if v.has_signal("请求弹窗"):
		v.connect("请求弹窗", _转发弹窗)
	if v.has_signal("请求屏幕"):
		v.connect("请求屏幕", _转发屏幕)
	if v.has_signal("请求关闭弹窗"):
		v.connect("请求关闭弹窗", _转发关闭)

# ==========================================================================================
# 小工具
# ==========================================================================================

## 现在该弹什么：读 `session.modal`；`结算` 类型在结算屏上不重复弹（那一屏自己就是结算面板）。
func _应该弹的类型() -> String:
	if session == null:
		return ""
	var m := session.modal
	if not (m is Dictionary) or (m as Dictionary).is_empty():
		return ""
	var t := str((m as Dictionary).get("类型", ""))
	if t.is_empty():
		return ""
	if t == "结算" and session.screen == "result":
		return ""
	return t

func _收起() -> void:
	visible = false
	_当前类型 = ""
	_当前视图 = null
	_必须决定 = false
	_清空(_内容)

## ★ 哪些类型「必须先把决定做掉」才放行：
##   · 三选一：内核口径就是必须选一张（关闭按钮一直不给）；
##   · 招募：★ 2026-10-18 收紧 —— **只要手上还有没决定的招募券就不给关**
##     （`session.ticket_count() > 0`）：玩家要么点候选机体招一台，要么按【放弃此券】，
##     两条决定做完之后「关闭」按钮才回来。从前只在「名册 0 台」时才拦，于是
##     「招到 1 台之后剩下的券可以一直拖着」，拖着拖着就忘了。
##   其余类型（晋升 / 黑市 / 休整 / 奇遇 / 战术牌库 / 战斗 / 结算）一律可以关。
func _是必须做决定的(类型: String) -> bool:
	if 类型 == "三选一":
		return true
	if 类型 == "招募" and session != null and session.有未决的招募券():
		return true
	return false

func _点关闭() -> void:
	# 按钮在「必须决定」时是隐藏的；这里再兜一道（键盘 / 程序直接调也不许绕过去）。
	if _必须决定:
		_标题.text = 标题Of(_当前类型) + ("（必须先选 1 张牌）" if _当前类型 == "三选一"
			else "（最多留 %d 张券：先招募或按【放弃此券】）" % RosterManager.券留存上限())
		return
	请求关闭弹窗.emit()

func _转发弹窗(类型: String, 数据: Dictionary) -> void:
	请求弹窗.emit(类型, 数据)

func _转发屏幕(屏名: String) -> void:
	请求屏幕.emit(屏名)

func _转发关闭() -> void:
	请求关闭弹窗.emit()

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
