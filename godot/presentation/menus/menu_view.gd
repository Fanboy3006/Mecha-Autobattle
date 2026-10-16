## 主菜单 + 分队选择屏（Stage M4-2；`session.screen` 为 `"menu" | "squad"`）。
##
## 三个入口（契约 §「C. menus」）：
##   继续游戏（读档，`has_saved_run()` 为假时点不动并写原因）
##   开始新肉鸽（选分队 `available_squads()` + 可选种子输入）
##   快速测试战斗（默认五人队，`start_quick_battle()` —— 作者试玩 D-01 手牌的入口）
##
## 单向数据流：读 `GameSession` 的展示辅助（`has_saved_run` / `available_squads`），
## 动作只调命令方法（`load_saved_run` / `start_new_run` / `start_quick_battle`）。
class_name MenuView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _继续: Button
var _存档提示: Label
var _分队面板: PanelContainer
var _分队列表: OptionButton
var _种子输入: LineEdit
var _分队说明: Label
var _菜单说明: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _继续 == null:
		return
	_菜单说明.text = "版本 %s · 规则参考 %s\n点「快速测试战斗」可以直接打一场默认五人队（不用先开肉鸽）—— 这是试玩 D-01 手牌的入口。" % [
		GameVersion.GAME_VERSION, GameVersion.RULES_REFERENCE]
	var 有档 := session != null and session.has_saved_run()
	_继续.disabled = not 有档
	_继续.tooltip_text = "从存档接着打" if 有档 else "还没有存档"
	if 有档:
		_存档提示.text = "有存档：可以继续上一次的局。"
		_存档提示.add_theme_color_override("font_color", UiTheme.正面)
	else:
		_存档提示.text = "「继续游戏」为什么是点不动的：现在读不到存档（存档要在局内点顶栏的「保存并返回主菜单」才会写）。"
		_存档提示.add_theme_color_override("font_color", UiTheme.弱文字)
	_分队面板.visible = session != null and session.screen == "squad"
	if _分队面板.visible:
		_刷新分队列表()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "主菜单"
	UiTheme.占满(self)
	var 居中 := CenterContainer.new()
	居中.name = "菜单居中"
	UiTheme.占满(居中)
	add_child(居中)
	var 底 := UiTheme.建面板(居中, "菜单底", UiTheme.面板底, UiTheme.边框)
	底.custom_minimum_size = Vector2(680, 0)
	var 列 := UiTheme.建盒(底, "菜单上下列", true, UiTheme.间距)

	UiTheme.建标题(列, "机甲指挥", UiTheme.字号_大标题)
	_菜单说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	UiTheme.建分隔(列)

	var 按钮组 := UiTheme.建盒(列, "菜单按钮组", true, UiTheme.间距_小)
	_继续 = UiTheme.建按钮(按钮组, "继续游戏（读档）", _点继续)
	_继续.name = "继续游戏按钮"
	var 新 := UiTheme.建按钮(按钮组, "开始新肉鸽", _点开始新)
	新.name = "开始新肉鸽按钮"
	新.tooltip_text = "选一个分队、给一个种子，开一局新的"
	var 快速 := UiTheme.建按钮(按钮组, "快速测试战斗", _点快速战斗)
	快速.name = "快速测试战斗按钮"
	快速.tooltip_text = "默认五人队（Lv10）打第 1 层普通编成 —— 不动存档、不用先开肉鸽"
	_存档提示 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.弱文字)
	_存档提示.name = "存档提示"

	_分队面板 = UiTheme.建面板(列, "分队选择", UiTheme.卡片底, UiTheme.边框_亮)
	var 分队列 := UiTheme.建盒(_分队面板, "分队上下列", true, UiTheme.间距_小)
	UiTheme.建标题(分队列, "分队选择", UiTheme.字号_小节)
	_分队列表 = OptionButton.new()
	_分队列表.name = "分队列表"
	_分队列表.custom_minimum_size = Vector2(280, 0)
	分队列.add_child(_分队列表)
	var 种子行 := UiTheme.建盒(分队列, "种子行", false, UiTheme.间距)
	UiTheme.建标签(种子行, "种子：", UiTheme.字号_正文, UiTheme.次要文字)
	_种子输入 = LineEdit.new()
	_种子输入.name = "种子输入"
	_种子输入.text = "20261016"
	_种子输入.custom_minimum_size = Vector2(180, 0)
	_种子输入.tooltip_text = "同一个种子 + 同一个分队 = 同一局（确定性）；留空或乱填就用默认种子"
	种子行.add_child(_种子输入)
	var 开局键 := UiTheme.建按钮(分队列, "开这一局", _点开局)
	开局键.name = "开局按钮"
	开局键.tooltip_text = "立刻开一局新肉鸽，进第 1 层大地图"
	_分队说明 = UiTheme.建说明(分队列, "", UiTheme.字号_小, UiTheme.次要文字)
	_分队面板.visible = false

# ==========================================================================================
# 动作（一律只调 GameSession 的命令方法）
# ==========================================================================================

func _点继续() -> void:
	if session == null:
		return
	session.load_saved_run()

func _点开始新() -> void:
	请求屏幕.emit("squad")

func _点快速战斗() -> void:
	if session == null:
		return
	session.start_quick_battle()

func _点开局() -> void:
	if session == null:
		return
	session.start_new_run(_读种子(), _选中的分队())

func _读种子() -> int:
	var 文 := _种子输入.text.strip_edges()
	if 文.is_valid_int():
		return int(文.to_int())
	return 20261016

func _选中的分队() -> String:
	if _分队列表.item_count <= 0:
		return GameSession.默认分队
	return _分队列表.get_item_text(maxi(0, _分队列表.selected))

# ==========================================================================================
# 分队列表（数据侧没有「分队表」时用职业 / 势力兜底，绝不空着）
# ==========================================================================================

func _候选分队() -> Array:
	var 出: Array = []
	if session != null:
		出 = session.available_squads()
	if not 出.is_empty():
		return 出
	出.append(GameSession.默认分队)
	for 类 in RosterManager.类们():
		出.append(str(类))
	for 势力 in RosterManager.势力们():
		出.append(str(势力))
	return 出

func _刷新分队列表() -> void:
	var 候选 := _候选分队()
	if _分队列表.item_count != 候选.size():
		var 旧 := _选中的分队()
		_分队列表.clear()
		for 名 in 候选:
			_分队列表.add_item(str(名))
		for i in _分队列表.item_count:
			if _分队列表.get_item_text(i) == 旧:
				_分队列表.selected = i
				break
	var 数据侧有表 := session != null and not session.available_squads().is_empty()
	_分队说明.text = "分队一共 %d 个%s。\n职业分队（近卫 / 尖兵 / 指挥 / 重装 / 狙击 / 特种）开局第 1 张券必是本分队券；" % [
		候选.size(), "" if 数据侧有表 else "（数据侧还没导出「分队表」，这里用职业 + 势力兜底）"]
	_分队说明.text += "势力分队同理。选「混编」就是纯随机。"
