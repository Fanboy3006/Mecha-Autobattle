## 单位卡（Stage M4-2 建骨架，**Stage M4-3 的战斗屏复用 / 扩展**）。
## 约定：只读 `GameSession.unit_view(side, unit_id)` 快照，开关与点选只发信号；前冲/轻跳只改 `_底` 的 offset，不改自身 rect 与最小尺寸。
class_name UnitCard
extends Control

signal 开关切换(单位键: String, 开关键: String)
signal 点选(单位键: String)

const 卡宽 := 132.0
const 卡高 := 148.0
const 紧凑宽 := 148.0
const 紧凑高 := 72.0
const 生命条高 := 6
const 反馈类型们 := ["出手", "大招", "修理", "受击", "治疗", "击破"]
const 前冲距离 := 12.0
const 演出前冲距离 := 14.0
const 发牌脉冲色 := Color(0.55, 0.95, 0.82)
const 发牌轻跳 := 8.0

var 数据: Dictionary = {}
var 紧凑棋盘: bool = false

var _底: Panel
var _列: VBoxContainer
var _数值行: HBoxContainer
var _名: Label
var _职属: Label
var _血条: ProgressBar
var _血值: Label
var _护盾: Label
var _状态行: Label
var _增益行: Label
var _开关行: Label
var _开关组: HBoxContainer
var _意图行: Label
var _觉醒行: Label
var _联动标: Label
var _联动中: bool = false
var _瞄准标: Label
var _瞄准中: bool = false
var _瞄准维修: bool = false
var _动作标: Label
var _战斗反馈: String = ""
var _前冲补间: Tween = null
var _发牌脉冲中: bool = false
var _跳动补间: Tween = null
var _选中: bool = false
var _战意行: HBoxContainer
var _战意文: Label
var _战意条: ProgressBar
var _主武标: Label
var _闪标: Label
var _雾标: Label
var _赌神标: Label
var _护卫标: Label
var _介入标: Label

func setup(data: Dictionary) -> void:
	数据 = data if data is Dictionary else {}
	_build()
	refresh()

func setup_unit(session: GameSession, side: String, unit_id: String) -> void:
	if session == null:
		setup({})
		return
	setup(session.unit_view(side, unit_id))

func _get_minimum_size() -> Vector2:
	return custom_minimum_size

## 切换 4×4 棋盘紧凑格（148×72）/ 常规卡（132×148），保留文本只切显隐。
func 设紧凑棋盘(开: bool) -> void:
	if 紧凑棋盘 == 开:
		return
	紧凑棋盘 = 开
	custom_minimum_size = Vector2(紧凑宽, 紧凑高) if 开 else Vector2(卡宽, 卡高)
	if _职属 != null:
		_职属.visible = not 开
	if _数值行 != null:
		_数值行.visible = not 开
	if _血值 != null:
		_血值.visible = not 开
	if _觉醒行 != null and 开:
		_觉醒行.visible = false
	update_minimum_size()
	refresh()
	_刷新卡底样式()

func refresh() -> void:
	if _名 == null:
		return
	if 数据.is_empty() or not bool(数据.get("ok", false)):
		_名.text = "（没有这台单位）"
		_职属.text = str(数据.get("为什么", "现在不在战斗里")) if not 数据.is_empty() else "没有数据"
		_血条.value = 0.0
		_血值.text = "HP —"
		_护盾.text = "护盾 —"
		_状态行.text = ""
		_增益行.text = ""
		_开关行.text = ""
		_意图行.text = ""
		_觉醒行.text = ""
		_状态行.visible = false
		_增益行.visible = false
		_开关行.visible = false
		_意图行.visible = false
		_觉醒行.visible = false
		_清空(_开关组)
		_战斗反馈 = ""
		_重置位移()
		if _动作标 != null:
			_动作标.visible = false
		if _战意行 != null:
			_战意行.visible = false
			_战意文.text = ""
			_战意条.value = 0.0
		if _主武标 != null:
			_主武标.visible = false
			_主武标.text = ""
		if _闪标 != null:
			_闪标.visible = false
		if _雾标 != null:
			_雾标.visible = false
		if _赌神标 != null:
			_赌神标.visible = false
		if _护卫标 != null:
			_护卫标.visible = false
			_护卫标.text = ""
		if _介入标 != null:
			_介入标.visible = false
		_刷新卡底样式()
		_绑悬停(str(数据.get("悬停说明", "")))
		return
	_名.text = str(数据.get("名", "?"))
	_职属.text = "%s · Lv%s · %s · %s · %s" % [str(数据.get("位名", "")), UiTheme.文本(数据.get("等级", 0)),
		str(数据.get("职业", "")), str(数据.get("势力", "")), "在场" if bool(数据.get("活着", false)) else "已倒下"]
	var 血 := float(数据.get("HP", 0.0))
	var 满 := float(数据.get("最大HP", 1.0))
	var 比 := float(数据.get("血比", 0.0))
	_血条.value = 比
	# content_margin > 0 会把 ProgressBar 最小高度撑到 20，故用无内边距样式
	_血条.add_theme_stylebox_override("fill", _条样式(_血条色(比)))
	_血值.text = "HP %s / %s（%s%%）" % [UiTheme.文本(int(JsCompat.js_round(血))),
		UiTheme.文本(int(JsCompat.js_round(满))), UiTheme.文本(int(JsCompat.js_round(比 * 100.0)))]
	_护盾.text = "护盾 %s" % UiTheme.文本(int(JsCompat.js_round(float(数据.get("护盾", 0.0)))))
	_护盾.add_theme_color_override("font_color", UiTheme.推进剂色)
	var 状态: Array = 数据.get("状态") if 数据.get("状态") is Array else []
	_状态行.text = " · ".join(状态.map(func(x): return UiTheme.文本(x)))
# ★ COL-4b：觉醒徽章配色 —— 状态行首位那枚〔觉醒中·SEED / ZERO / 隐身〕按类型上色（隐身半透明）。
	_状态行.add_theme_color_override("font_color", UiTheme.觉醒色(UiTheme.文本(数据.get("觉醒类型"))))
	var 增益: Array = 数据.get("增益") if 数据.get("增益") is Array else []
	var 减益: Array = 数据.get("减益") if 数据.get("减益") is Array else []
	var 段: Array = []
	if not 增益.is_empty():
		段.append("增益：" + "、".join(增益.map(func(x): return UiTheme.文本(x))))
	if not 减益.is_empty():
		段.append("减益：" + "、".join(减益.map(func(x): return UiTheme.文本(x))))
	_增益行.text = "；".join(段)
	_开关行.text = " · ".join((数据.get("开关") as Array).map(func(x): return UiTheme.文本(x))) \
		if 数据.get("开关") is Array else ""
	var 意图: Array = 数据.get("意图") if 数据.get("意图") is Array else []
	_意图行.text = "\n".join(意图.map(func(x): return UiTheme.文本(x)))
	_意图行.add_theme_color_override("font_color", UiTheme.难度色)
	_意图行.visible = not 意图.is_empty()
	_觉醒行.text = str(数据.get("觉醒", ""))
	_觉醒行.add_theme_color_override("font_color", UiTheme.希望色)
	_觉醒行.visible = not _觉醒行.text.is_empty()
	# 空或默认行只隐藏不删除，保持 find_child 可查且不占高度
	_状态行.visible = not _状态行.text.is_empty() and _状态行.text != "正常"
	_增益行.visible = not _增益行.text.is_empty()
	_开关行.visible = not _开关行.text.is_empty() and not _开关是默认()
	_建开关()
	_绑悬停(str(数据.get("悬停说明", "")))
	if _闪标 != null:
		_闪标.visible = bool(数据.get("闪", false))
	if _雾标 != null:
		_雾标.visible = bool(数据.get("雾", false))
	if _赌神标 != null:
		_赌神标.visible = bool(数据.get("赌神", false))
	if _护卫标 != null:
		var 护文 := str(数据.get("护卫提示", ""))
		_护卫标.text = 护文
		_护卫标.visible = not 护文.is_empty()
	if _介入标 != null:
		_介入标.visible = bool(数据.get("介入", false))
	_画战意()
	_刷新卡底样式()
	visible = true

func _画战意() -> void:
	if _战意行 == null:
		return
	if 数据.get("战意") == null:
		_战意行.visible = false
		if _主武标 != null:
			_主武标.visible = false
		return
	var 值 := float(数据.get("战意", 0.0))
	var 上 := float(数据.get("战意上限", 100.0))
	if 上 <= 0.0:
		上 = 100.0
	_战意行.visible = true
	_战意文.text = "战意 %s / %s" % [UiTheme.文本(int(JsCompat.js_round(值))), UiTheme.文本(int(JsCompat.js_round(上)))]
	_战意文.add_theme_color_override("font_color", UiTheme.高亮 if 值 > 0.0 else UiTheme.推进剂色)
	_战意条.value = clampf(值 / 上, 0.0, 1.0)
	if _主武标 != null:
		var λ文 := str(数据.get("λ状态", ""))
		var 文 := λ文 if not λ文.is_empty() else str(数据.get("主武器状态", ""))
		_主武标.text = 文
		_主武标.visible = not 文.is_empty()
		if not λ文.is_empty():
			_主武标.add_theme_color_override("font_color",
				UiTheme.希望色 if 数据.get("λ觉醒") == true else UiTheme.连携色)
		else:
			_主武标.add_theme_color_override("font_color",
				UiTheme.禁用文字 if bool(数据.get("主武器已销毁", false)) else UiTheme.高亮)

func 选中中() -> bool:
	return _选中

func 设为选中(on: bool) -> void:
	if _选中 == on:
		return
	_选中 = on
	_刷新卡底样式()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var 鼠: InputEventMouseButton = event
	if 鼠.button_index != MOUSE_BUTTON_LEFT or not 鼠.pressed:
		return
	var 键 := str(数据.get("键", 数据.get("模板", "")))
	if 键.is_empty():
		return
	点选.emit(键)

func _开关是默认() -> bool:
	if _开关行 == null or _开关行.text.is_empty():
		return true
	for 条 in _开关行.text.split(" · "):
		var t := str(条)
		if t.ends_with("：开") or t.ends_with("：手动"):
			return false
	return true

# ---- 一、建节点树 ----

func _build() -> void:
	name = "单位卡"
	custom_minimum_size = Vector2(紧凑宽, 紧凑高) if 紧凑棋盘 else Vector2(卡宽, 卡高)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	var 底样式 := _卡底样式(UiTheme.卡片底, UiTheme.边框, 1)
	# 用普通 Panel 而非 PanelContainer，避免内部行组合最小高度撑破 148×72 紧凑格
	_底 = Panel.new()
	_底.name = "单位卡底"
	_底.clip_contents = true
	_底.mouse_filter = Control.MOUSE_FILTER_PASS
	_底.add_theme_stylebox_override("panel", 底样式)
	add_child(_底)
	UiTheme.占满(_底)
	_列 = UiTheme.建盒(_底, "单位卡上下列", true, 1)
	UiTheme.占满(_列)
	_列.offset_left = 0
	_列.offset_right = 0
	_列.offset_top = 0
	_列.offset_bottom = 0
	_列.mouse_filter = Control.MOUSE_FILTER_PASS

	_名 = _单行(_列, "单位名", "（没有这台单位）", UiTheme.字号_正文, UiTheme.主文字)
	_职属 = _单行(_列, "单位职属", "", UiTheme.字号_小, UiTheme.次要文字)
	_血条 = UiTheme.建比例条(_列, "生命条", 0.0, UiTheme.正面)
	_血条.custom_minimum_size = Vector2(40, 生命条高)
	_血条.add_theme_stylebox_override("background", _条样式(Color(1, 1, 1, 0.14)))
	_血条.mouse_filter = Control.MOUSE_FILTER_PASS
	_血值 = _单行(_列, "生命数值", "HP —", UiTheme.字号_小, UiTheme.主文字)
	_数值行 = UiTheme.建盒(_列, "数值行", false, UiTheme.间距_小)
	_数值行.mouse_filter = Control.MOUSE_FILTER_PASS
	_护盾 = UiTheme.建标签(_数值行, "护盾 —", UiTheme.字号_小, UiTheme.推进剂色)
	_护盾.name = "护盾"
	_护盾.mouse_filter = Control.MOUSE_FILTER_PASS
	_战意行 = UiTheme.建盒(_列, "战意行", false, UiTheme.间距_小)
	_战意行.mouse_filter = Control.MOUSE_FILTER_PASS
	_战意文 = _单行(_战意行, "战意文", "", UiTheme.字号_小, UiTheme.推进剂色)
	_战意条 = UiTheme.建比例条(_战意行, "战意条", 0.0, UiTheme.推进剂色)
	_战意条.custom_minimum_size = Vector2(30, 生命条高)
	_战意条.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_战意条.add_theme_stylebox_override("background", _条样式(Color(1, 1, 1, 0.14)))
	_战意条.add_theme_stylebox_override("fill", _条样式(UiTheme.高亮))
	_战意条.mouse_filter = Control.MOUSE_FILTER_PASS
	_战意行.visible = false
	_状态行 = _单行(_列, "状态行", "", UiTheme.字号_小, UiTheme.次要文字)
	_增益行 = _单行(_列, "增益行", "", UiTheme.字号_小, UiTheme.高亮)
	_开关行 = _单行(_列, "开关行", "", UiTheme.字号_小, UiTheme.弱文字)
	_意图行 = _单行(_列, "意图行", "", UiTheme.字号_小, UiTheme.难度色)
	_觉醒行 = _单行(_列, "觉醒行", "", UiTheme.字号_小, UiTheme.希望色)
	_开关组 = UiTheme.建盒(_列, "开关按钮组", false, UiTheme.间距_小)
	_开关组.mouse_filter = Control.MOUSE_FILTER_PASS
	# 角标一律直接挂在 self 上，不进入容器布局，不改变卡片最小尺寸
	_联动标 = Label.new()
	_联动标.name = "卡牌来源标"
	_联动标.text = "〔卡牌来源〕"
	_联动标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_联动标.add_theme_color_override("font_color", UiTheme.推进剂色)
	_联动标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_联动标.visible = false
	_联动标.anchor_left = 1.0
	_联动标.anchor_right = 1.0
	_联动标.anchor_top = 0.0
	_联动标.anchor_bottom = 0.0
	_联动标.offset_left = -76.0
	_联动标.offset_right = -3.0
	_联动标.offset_top = 1.0
	_联动标.offset_bottom = 18.0
	add_child(_联动标)
	_瞄准标 = Label.new()
	_瞄准标.name = "瞄准目标标"
	_瞄准标.text = "〔瞄准〕"
	_瞄准标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_瞄准标.add_theme_color_override("font_color", UiTheme.出手色)
	_瞄准标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_瞄准标.add_theme_constant_override("outline_size", 4)
	_瞄准标.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_瞄准标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_瞄准标.visible = false
	_瞄准标.anchor_left = 0.0
	_瞄准标.anchor_right = 0.0
	_瞄准标.anchor_top = 0.0
	_瞄准标.anchor_bottom = 0.0
	_瞄准标.offset_left = 3.0
	_瞄准标.offset_right = 76.0
	_瞄准标.offset_top = 1.0
	_瞄准标.offset_bottom = 18.0
	add_child(_瞄准标)
	_动作标 = Label.new()
	_动作标.name = "动作反馈标"
	_动作标.text = ""
	_动作标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_动作标.add_theme_color_override("font_color", UiTheme.出手色)
	_动作标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_动作标.add_theme_constant_override("outline_size", 4)
	_动作标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_动作标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_动作标.visible = false
	_动作标.anchor_left = 1.0
	_动作标.anchor_right = 1.0
	_动作标.anchor_top = 1.0
	_动作标.anchor_bottom = 1.0
	_动作标.offset_left = -76.0
	_动作标.offset_right = -3.0
	_动作标.offset_top = -19.0
	_动作标.offset_bottom = -2.0
	add_child(_动作标)
	_主武标 = Label.new()
	_主武标.name = "主武标"
	_主武标.text = ""
	_主武标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_主武标.add_theme_color_override("font_color", UiTheme.高亮)
	_主武标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_主武标.add_theme_constant_override("outline_size", 4)
	_主武标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_主武标.visible = false
	_主武标.anchor_left = 0.0
	_主武标.anchor_right = 0.0
	_主武标.anchor_top = 0.0
	_主武标.anchor_bottom = 0.0
	_主武标.offset_left = 3.0
	_主武标.offset_right = 80.0
	_主武标.offset_top = 1.0
	_主武标.offset_bottom = 18.0
	add_child(_主武标)
	_闪标 = Label.new()
	_闪标.name = "闪标"
	_闪标.text = "闪"
	_闪标.add_theme_font_size_override("font_size", UiTheme.字号_标题)
	_闪标.add_theme_color_override("font_color", UiTheme.高亮)
	_闪标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_闪标.add_theme_constant_override("outline_size", 6)
	_闪标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_闪标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_闪标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_闪标.visible = false
	_闪标.anchor_left = 0.5
	_闪标.anchor_right = 0.5
	_闪标.anchor_top = 0.0
	_闪标.anchor_bottom = 0.0
	_闪标.offset_left = -24.0
	_闪标.offset_right = 24.0
	_闪标.offset_top = 26.0
	_闪标.offset_bottom = 52.0
	add_child(_闪标)
	_雾标 = Label.new()
	_雾标.name = "雾标"
	_雾标.text = "雾"
	_雾标.add_theme_font_size_override("font_size", UiTheme.字号_标题)
	_雾标.add_theme_color_override("font_color", UiTheme.次要文字)
	_雾标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_雾标.add_theme_constant_override("outline_size", 6)
	_雾标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_雾标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_雾标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_雾标.visible = false
	_雾标.anchor_left = 1.0
	_雾标.anchor_right = 1.0
	_雾标.anchor_top = 0.0
	_雾标.anchor_bottom = 0.0
	_雾标.offset_left = -52.0
	_雾标.offset_right = -4.0
	_雾标.offset_top = 26.0
	_雾标.offset_bottom = 52.0
	add_child(_雾标)
	_赌神标 = Label.new()
	_赌神标.name = "赌神标"
	_赌神标.text = "赌神"
	_赌神标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_赌神标.add_theme_color_override("font_color", UiTheme.高亮)
	_赌神标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_赌神标.add_theme_constant_override("outline_size", 6)
	_赌神标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_赌神标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_赌神标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_赌神标.visible = false
	_赌神标.anchor_left = 0.0
	_赌神标.anchor_right = 0.0
	_赌神标.anchor_top = 0.0
	_赌神标.anchor_bottom = 0.0
	_赌神标.offset_left = 4.0
	_赌神标.offset_right = 60.0
	_赌神标.offset_top = 52.0
	_赌神标.offset_bottom = 74.0
	add_child(_赌神标)
	_护卫标 = Label.new()
	_护卫标.name = "护卫标"
	_护卫标.text = ""
	_护卫标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_护卫标.add_theme_color_override("font_color", UiTheme.连携色)
	_护卫标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_护卫标.add_theme_constant_override("outline_size", 4)
	_护卫标.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_护卫标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_护卫标.visible = false
	_护卫标.anchor_left = 0.0
	_护卫标.anchor_right = 1.0
	_护卫标.anchor_top = 1.0
	_护卫标.anchor_bottom = 1.0
	_护卫标.offset_left = 3.0
	_护卫标.offset_right = -72.0
	_护卫标.offset_top = -19.0
	_护卫标.offset_bottom = -2.0
	add_child(_护卫标)
	_介入标 = Label.new()
	_介入标.name = "介入标"
	_介入标.text = "〔介入〕"
	_介入标.add_theme_font_size_override("font_size", UiTheme.字号_小)
	_介入标.add_theme_color_override("font_color", UiTheme.连携色)
	_介入标.add_theme_color_override("font_outline_color", UiTheme.底色)
	_介入标.add_theme_constant_override("outline_size", 4)
	_介入标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_介入标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_介入标.visible = false
	_介入标.anchor_left = 1.0
	_介入标.anchor_right = 1.0
	_介入标.anchor_top = 1.0
	_介入标.anchor_bottom = 1.0
	_介入标.offset_left = -84.0
	_介入标.offset_right = -3.0
	_介入标.offset_top = -19.0
	_介入标.offset_bottom = -2.0
	add_child(_介入标)

func _卡底样式(色: Color, 边色: Color, 边宽: int) -> StyleBoxFlat:
	var s := UiTheme.底样式(色, 边色, 边宽)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

# ---- 二、卡牌来源联动与拖拽瞄准高亮 ----

func set_card_source_highlight(on: bool) -> void:
	_联动中 = on
	_刷新卡底样式()
	if _联动标 != null:
		_联动标.visible = on

func 联动高亮中() -> bool:
	return _联动中

func set_aim_highlight(on: bool, 维修: bool = false) -> void:
	_瞄准中 = on
	_瞄准维修 = 维修
	if _瞄准标 != null:
		_瞄准标.visible = on
		_瞄准标.text = "〔瞄准·修〕" if 维修 else "〔瞄准〕"
		_瞄准标.add_theme_color_override("font_color", UiTheme.正面 if 维修 else UiTheme.出手色)
	_刷新卡底样式()

func 瞄准高亮中() -> bool:
	return _瞄准中

# ---- 三、动作反馈与发牌脉冲 ----

## `kind` 见 `反馈类型们`，其余字符串视为清空；`dir_x` 为前冲方向（+1 朝右 / -1 朝左）。
func set_combat_fx(kind: String, dir_x: float = 0.0, 距离: float = 0.0) -> void:
	if not 反馈类型们.has(kind):
		clear_combat_fx()
		return
	_战斗反馈 = kind
	_发牌脉冲中 = false
	_刷新卡底样式()
	_刷新动作标()
	var 冲 := 距离 if 距离 > 0.0 else 前冲距离
	if kind == "出手" or kind == "大招" or kind == "修理":
		_前冲(dir_x, 冲)
	elif kind == "受击":
		_闪一下()
		_震动()
	elif kind == "治疗":
		_闪一下()

func play_action_feedback(kind: String, dir_x: float) -> void:
	set_combat_fx(kind, dir_x)

func clear_combat_fx() -> void:
	_战斗反馈 = ""
	_重置位移()
	_刷新卡底样式()
	if _动作标 != null:
		_动作标.visible = false

func combat_fx_kind() -> String:
	return _战斗反馈

func 战斗反馈中() -> bool:
	return not _战斗反馈.is_empty()

func _刷新动作标() -> void:
	if _动作标 == null:
		return
	if _战斗反馈.is_empty():
		_动作标.text = ""
		_动作标.visible = false
		return
	_动作标.text = "〔%s〕" % _反馈短名(_战斗反馈)
	_动作标.add_theme_color_override("font_color", _反馈色(_战斗反馈))
	_动作标.visible = true

func _反馈短名(kind: String) -> String:
	match kind:
		"治疗":
			return "回复"
		_:
			return kind

func _反馈色(kind: String) -> Color:
	match kind:
		"受击":
			return UiTheme.负面
		"治疗":
			return UiTheme.正面
		"击破":
			return UiTheme.暴击色
		_:
			return UiTheme.出手色

## 样式优先级：战斗反馈 > 发牌脉冲 > 拖拽瞄准 > 卡牌来源联动 > 选中 > 默认。
func _刷新卡底样式() -> void:
	if _底 == null:
		return
	var 色 := UiTheme.卡片底
	var 边 := UiTheme.边框
	var 宽 := 1
	if _选中:
		色 = UiTheme.卡片底_亮
		边 = UiTheme.高亮
		宽 = 2
	if _联动中:
		色 = UiTheme.卡片底_亮
		边 = UiTheme.推进剂色
		宽 = 2
	if _瞄准中:
		色 = UiTheme.卡片底_亮
		边 = UiTheme.正面 if _瞄准维修 else UiTheme.出手色
		宽 = 2
	if _发牌脉冲中:
		色 = UiTheme.卡片底_亮
		边 = 发牌脉冲色
		宽 = 2
	match _战斗反馈:
		"出手", "大招", "修理":
			色 = UiTheme.卡片底_亮
			边 = UiTheme.出手色
			宽 = 2
		"受击":
			色 = UiTheme.卡片底_亮
			边 = UiTheme.负面
			宽 = 2
		"治疗":
			色 = UiTheme.卡片底_亮
			边 = UiTheme.正面
			宽 = 2
		"击破":
			色 = UiTheme.卡片底_亮
			边 = UiTheme.暴击色
			宽 = 2
	_底.add_theme_stylebox_override("panel", _卡底样式(色, 边, 宽))

func _前冲(dir_x: float, 距离: float = 12.0) -> void:
	if UiTheme.无声模式() or _底 == null:
		return
	if dir_x == 0.0:
		return
	if not is_inside_tree():
		return
	_重置位移()
	var 像素 := 距离 * signf(dir_x)
	_前冲补间 = create_tween()
	_前冲补间.tween_method(_设偏移, 0.0, 像素, 0.09)
	_前冲补间.tween_method(_设偏移, 像素, 0.0, 0.16)
	_前冲补间.tween_callback(_重置位移)

func _震动() -> void:
	if UiTheme.无声模式() or _底 == null:
		return
	if not is_inside_tree():
		return
	_重置位移()
	_前冲补间 = create_tween()
	_前冲补间.tween_method(_设偏移, 0.0, -4.0, 0.05)
	_前冲补间.tween_method(_设偏移, -4.0, 4.0, 0.08)
	_前冲补间.tween_method(_设偏移, 4.0, -3.0, 0.06)
	_前冲补间.tween_method(_设偏移, -3.0, 0.0, 0.05)

func _闪一下() -> void:
	if UiTheme.无声模式() or _动作标 == null:
		return
	if not is_inside_tree():
		return
	_动作标.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var t := create_tween()
	t.tween_property(_动作标, "modulate:a", 0.35, 0.08)
	t.tween_property(_动作标, "modulate:a", 1.0, 0.14)

func _设偏移(v: float) -> void:
	if _底 == null or not is_instance_valid(_底):
		return
	_底.offset_left = v
	_底.offset_right = v

func _设纵偏移(v: float) -> void:
	if _底 == null or not is_instance_valid(_底):
		return
	_底.offset_top = v
	_底.offset_bottom = v

func _重置位移() -> void:
	if _前冲补间 != null and _前冲补间.is_valid():
		_前冲补间.kill()
	_前冲补间 = null
	if _跳动补间 != null and _跳动补间.is_valid():
		_跳动补间.kill()
	_跳动补间 = null
	_设偏移(0.0)
	_设纵偏移(0.0)

func 播放发牌脉冲() -> void:
	if _底 == null:
		return
	_发牌脉冲中 = true
	_刷新卡底样式()
	if UiTheme.无声模式() or not is_inside_tree():
		return
	_轻跳()

func 清发牌脉冲() -> void:
	_重置位移()
	if not _发牌脉冲中:
		return
	_发牌脉冲中 = false
	_刷新卡底样式()

func 发牌脉冲中() -> bool:
	return _发牌脉冲中

func _轻跳() -> void:
	if _底 == null:
		return
	if _跳动补间 != null and _跳动补间.is_valid():
		_跳动补间.kill()
	_跳动补间 = create_tween()
	_跳动补间.tween_method(_设纵偏移, 0.0, -发牌轻跳, 0.10)
	_跳动补间.tween_method(_设纵偏移, -发牌轻跳, 0.0, 0.14)
	_跳动补间.tween_callback(_设纵偏移.bind(0.0))

func _单行(父: Node, 名: String, 文本: String, 大小: int, 色: Color) -> Label:
	var l := UiTheme.建标签(父, 文本, 大小, 色)
	l.name = 名
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

func _条样式(色: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = 色
	s.set_corner_radius_all(3)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

func _建开关() -> void:
	_清空(_开关组)

func _紧凑按钮() -> StyleBoxFlat:
	var s := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.边框)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	s.set_corner_radius_all(3)
	return s

# ---- 四、悬停说明与信号转发 ----

## 子节点均为 MOUSE_FILTER_PASS，`mouse_entered` 只发给最深控件，故每个子节点都要绑定。
func _绑悬停(文: String) -> void:
	if 文.strip_edges().is_empty():
		return
	for c in [self, _底, _列, _血条, _数值行, _名, _职属, _血值, _护盾,
			_状态行, _增益行, _开关行, _意图行, _觉醒行, _开关组, _战意行, _战意条]:
		if c is Control:
			HoverTooltip.bind(c, 文, "机体")
	for b in _开关组.get_children():
		if b is Control:
			HoverTooltip.bind(b, 文, "机体")

func _点开关(键: String, 开关键: String) -> void:
	开关切换.emit(键, 开关键)

func _血条色(比: float) -> Color:
	if 比 <= 0.25:
		return UiTheme.负面
	if 比 <= 0.6:
		return UiTheme.高亮
	return UiTheme.正面

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
