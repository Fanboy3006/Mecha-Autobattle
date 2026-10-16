## 奇遇 / 瞭望站 / 遗迹 / 侵蚀源（Stage M4-2）。
##
## 奇遇：选项用 `GameSession.current_event_choices()` 动态列出（它内部走纯读的
## `NodeResolver.当前事件`），点一项即 `resolve_event_choice(选项下标字符串)`，即时显示结果文字。
##
## 瞭望站 / 遗迹 / 侵蚀源：门面**没有**暴露这三者的「选哪一项」口子
## （`enter_current_node()` 会按内核默认项直接结算），所以这里只把内核已经结算出来的
## `current_node_result()` 如实摊开给玩家看（不自己算、也不假装有选项）。
class_name EventView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _标题: Label
var _说明: Label
var _选项按钮组: VBoxContainer
var _事件结果: VBoxContainer

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _选项按钮组 == null:
		return
	var s: RunState = null
	if session != null:
		s = session.run_state
	if s == null:
		_标题.text = "没有进行中的局"
		_说明.text = ""
		_清空(_选项按钮组)
		_清空(_事件结果)
		return
	_清空(_选项按钮组)
	_清空(_事件结果)
	var 类型 := _弹窗类型()
	if 类型 == "奇遇" or 类型 == "事件":
		_填奇遇(s)
		return
	_标题.text = UiTheme.节点全名(类型)
	_说明.text = "这一格的结算已经由内核做好了（门面没有暴露「选哪一项」的口子）：下面是内核返回的结果。"
	_摊开结果(session.current_node_result())
	UiTheme.建按钮(_事件结果, "知道了，回大地图", _点关闭结果页)

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "奇遇面板"
	UiTheme.占满(self)
	var 列 := UiTheme.建盒(self, "奇遇上下列", true, UiTheme.间距)
	_标题 = UiTheme.建标题(列, "奇遇", UiTheme.字号_小节)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	UiTheme.建标签(列, "选一项", UiTheme.字号_小节, UiTheme.高亮)
	_选项按钮组 = UiTheme.建滚动(列, "选项按钮组", 200.0)
	UiTheme.建标签(列, "结果", UiTheme.字号_小节, UiTheme.高亮)
	_事件结果 = UiTheme.建滚动(列, "事件结果", 200.0)

func _点关闭结果页() -> void:
	请求关闭弹窗.emit()

# ==========================================================================================
# 奇遇
# ==========================================================================================

func _填奇遇(s: RunState) -> void:
	var 事 := _当前事件(s)
	_标题.text = "奇遇：%s" % str(事.get("名", "（认不出来的事件）"))
	_说明.text = "选项由内核的事件表动态给出；选完当场结算，同一格只结算一次。"
	var 选 := session.current_event_choices()
	if 选.is_empty():
		UiTheme.建标签(_选项按钮组, "这个事件现在没有选项（可能已经结算过了）。", UiTheme.字号_正文, UiTheme.次要文字)
	else:
		for 条 in 选:
			if not (条 is Dictionary):
				continue
			var 序 := int(条.get("序", 0))
			UiTheme.建按钮(_选项按钮组, "%s" % str(条.get("文", "")), _点选.bind(序))
	var 末 := session.last
	if str(末.get("行动", "")) == "事件":
		UiTheme.建标签(_事件结果, "事件：%s" % str(末.get("事件", "")), UiTheme.字号_正文, UiTheme.高亮)
		UiTheme.建标签(_事件结果, "你选了：%s" % str(末.get("选", "")), UiTheme.字号_正文, UiTheme.主文字)
		UiTheme.建标签(_事件结果, "结果：%s" % str(末.get("结果", "")), UiTheme.字号_小节, UiTheme.正面)
		UiTheme.建按钮(_事件结果, "知道了，回大地图", _点关闭结果页)
	else:
		var 已 := session.current_node_result()
		if str(已.get("节点", "")) == "事件":
			UiTheme.建标签(_事件结果, "这一格已经结算过：%s" % UiTheme.文本(已.get("选", "")), UiTheme.字号_正文, UiTheme.次要文字)

func _点选(序: int) -> void:
	if session == null:
		return
	session.resolve_event_choice(UiTheme.文本(序))

# ==========================================================================================
# 小工具
# ==========================================================================================

## 现在这个弹窗是什么类型（默认按奇遇处理）。
func _弹窗类型() -> String:
	if session == null:
		return "奇遇"
	var m := session.modal
	if m is Dictionary and (m as Dictionary).has("类型"):
		return str((m as Dictionary)["类型"])
	return "奇遇"

## 这一格遇到哪个事件（**纯读** `NodeResolver.当前事件`，不消耗随机数、不改状态）。
func _当前事件(s: RunState) -> Dictionary:
	var 已 := session.current_node_result()
	if 已.get("事件") is Dictionary and not (已.get("事件") as Dictionary).is_empty():
		return 已["事件"]
	return NodeResolver.当前事件(s)

## 把内核返回的结果字典摊成「键：值」的行（表现层不解释、不加工数值）。
func _摊开结果(r: Dictionary) -> void:
	if r.is_empty():
		UiTheme.建标签(_事件结果, "内核没有给出结果。", UiTheme.字号_正文, UiTheme.次要文字)
		return
	for k in r.keys():
		var v: Variant = r[k]
		if v is Dictionary:
			var 内: Array = []
			for k2 in (v as Dictionary).keys():
				内.append("%s %s" % [str(k2), UiTheme.文本((v as Dictionary)[k2])])
			UiTheme.建说明(_事件结果, "%s：%s" % [str(k), "、".join(内)], UiTheme.字号_小, UiTheme.次要文字)
		elif v is Array:
			UiTheme.建说明(_事件结果, "%s：%s" % [str(k), "、".join((v as Array).map(func(x): return UiTheme.文本(x)))],
				UiTheme.字号_小, UiTheme.次要文字)
		else:
			UiTheme.建标签(_事件结果, "%s：%s" % [str(k), UiTheme.文本(v)], UiTheme.字号_小, UiTheme.主文字)

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
