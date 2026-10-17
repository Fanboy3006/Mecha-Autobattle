## 单位卡（Stage M4-2 建骨架，**Stage M4-3 的战斗屏复用 / 扩展**）。
##
## 数据源：`GameSession.unit_view(side, unit_id)` 的返回字典（**纯读**，表现层自己一个数都不算）。
##
## ★ 给 M4-3 固定下来的接口（别改签名）：
##     `setup(data: Dictionary) -> void`   —— 递进一张单位快照
##     `refresh() -> void`                 —— 用同一份 data 重画
##   另外提供一个方便的重载：`setup_unit(session, side, unit_id)`（内部就是
##   `setup(session.unit_view(...))`，M4-3 想直接用会话门面时用它）。
##   开关类动作**不自己调内核**，只发信号，由持有 session 的一方转发给 `GameSession`。
##
## ★ 尺寸纪律（「战斗屏单位卡互压」的根治，2026-10-13）：
##   根因是 `UnitCard extends Control` 从前**没有** `_get_minimum_size()` —— 它对父容器报高 0
##   （只有 `custom_minimum_size` 的 116×19），而内部 `单位卡底` 实画到 270×264，
##   于是同一排 / 跨排的卡片严重互压。现在：
##     · 重写 `_get_minimum_size()`，返回 `单位卡底` 的最小尺寸与 `custom_minimum_size` 的**较大者**；
##     · `clip_contents = true`（内容绝不越出卡片）；
##     · `单位卡底` 内边距 4、行间距 1、字号紧凑（名字 13pt、其余 11pt）、生命条高 6；
##     · `状态行` / `增益行` / `开关行` **空或默认时 `visible = false`**（★ 节点仍留在树上，
##       `find_child` 断言照样找得到，只是不占高度）；
##     · 开关按钮用 11pt + 左右内边距 4 的紧凑样式，绝不把卡宽撑到 270px。
##     目标：1280×616 下双排 8 格阵型里每张卡约 132×148。
##
## ★ Mouse Over：`refresh()` 末尾按 `数据["悬停说明"]` 给**卡片自身与内部按钮**挂悬停说明
##   （`HoverTooltip.bind`）；所有非按钮子节点 `mouse_filter = PASS`，
##   所以鼠标停在卡片任意位置都能把整台机体的说明弹出来。
##
## ★ UX-2（2026-10-19）：新增 `set_card_source_highlight(on)` —— 卡牌来源联动高亮。
##   开 = `单位卡底` 换成 2px 青色外框 + 右上角〔卡牌来源〕角标；关 = 复原。
##   **纯表现**：不动 `数据`、不动文本、不动最小尺寸（角标是 `self` 的直接子节点，不进布局容器），
##   所以战斗屏的版面门禁（132×148 / 两两不重叠）一字不改。
##
## ★ UX-3（2026-10-19）：新增 `set_combat_fx(kind, dir_x)` / `play_action_feedback(kind, dir_x)` /
##   `clear_combat_fx()` —— 「谁打了谁、造成了什么效果」的卡片侧反馈：
##     · `kind` 取 `"出手"` / `"大招"` / `"修理"` / `"受击"` / `"治疗"` / `"击破"`；
##     · `单位卡底` 换 2px 反馈外框（出手 / 大招 / 修理 = 亮金，受击 = 红，治疗 = 绿）；
##     · 右下角亮起 `〔出手〕` / `〔大招〕` / `〔修理〕` / `〔受击〕` / `〔回复〕` / `〔击破〕` 角标；
##     · **非 headless** 时用 Tween 让内部视觉层 `单位卡底` 朝敌方方向短促前冲 12px 后回弹。
##   ★ 红线：**绝不改变 `UnitCard` 自己在 `GridContainer` / `HBoxContainer` 里的 `position` / `rect`**
##     —— 前冲只动 `单位卡底` 的 `offset_left` / `offset_right`（尺寸不变、布局尺寸不变），
##     所以 `test_presentation_layout.gd` 的「卡身与卡底尺寸一致 / 1280×720 内 / 两两不重叠」全部照旧。
##
## ★ UX-5（2026-10-19，作者反馈第 2 条「一回合十几条事件一帧闪完」）：
##   新增 `播放发牌脉冲()` —— 发牌演出时来源机体卡亮起**青金色**发光边框并向上轻跳 8px
##   （非 headless 才有 Tween）。★ 红线：轻跳只动 `单位卡底` 的 `offset_top` / `offset_bottom`
##   （两个 offset 一起动 → 高度与布局尺寸不变），卡本身的 rect 一个像素都不动。
##
## ★ UX-6（2026-10-19，作者反馈第 4 条）：我方机体卡**不再显示「憋大招 / 放大招」切换按钮**
##   （大招状态 / 冷却 / 武器信息仍然写在「开关行」文字与悬停说明里；
##    `GameSession.toggle_hold_ultimate()` / `toggle_unit_switch("保留大招")` 保留不动）。
class_name UnitCard
extends Control

## 切一个开关键（`"保留大招"` / `"TRANSAM"`）。
signal 开关切换(单位键: String, 开关键: String)
## 手动激活势力状态（今天只有天人 TRANS-AM 这一条路）。
signal 开状态(单位键: String)
## ★ DECK-3 §1：点这张卡 → 把它设成「当前操作的我方机体」（只有我方卡会发这个信号）。
signal 点选(单位键: String)

## 一张卡的目标尺寸（1280×616 下双排 8 格阵型）。
const 卡宽 := 132.0
const 卡高 := 148.0
## 生命条的最小高度（`ProgressBar` 的默认样式会把最小高度顶到 20，见 `_条样式`）。
const 生命条高 := 6
## ★ UX-3：合法的动作反馈类型（其余字符串一律当「清空」处理）。
const 反馈类型们 := ["出手", "大招", "修理", "受击", "治疗", "击破"]
## ★ UX-3：前冲距离（像素）。规格 10~12px，取 12。
const 前冲距离 := 12.0
## ★ UX-5：战斗演出里的出手前冲距离（规格 14px；单独调 `set_combat_fx()` 不传时仍用 12）。
const 演出前冲距离 := 14.0
## ★ UX-5：发牌脉冲的**青金色**（外框 glow + 轻跳）。
const 发牌脉冲色 := Color(0.55, 0.95, 0.82)
## ★ UX-5：发牌轻跳的高度（像素）。
const 发牌轻跳 := 8.0

var 数据: Dictionary = {}

var _底: PanelContainer
var _列: VBoxContainer
var _数值行: HBoxContainer
var _名: Label
var _职属: Label
var _血条: ProgressBar
var _血值: Label
var _气势: Label
var _护盾: Label
var _状态行: Label
var _增益行: Label
var _开关行: Label
var _开关组: HBoxContainer
## M4-3 新增
var _意图行: Label
var _觉醒行: Label
## ★ UX-2 第 2 项：卡牌来源联动高亮
var _联动标: Label
var _联动中: bool = false
## ★ UX-3：动作反馈（出手 / 受击 / 治疗）
var _动作标: Label
var _战斗反馈: String = ""
var _前冲补间: Tween = null
## ★ UX-5：发牌脉冲（青金外框 + 轻跳）与它的补间槽位（与前冲互斥，一起归零）。
var _发牌脉冲中: bool = false
var _跳动补间: Tween = null
## ★ DECK-3 §1：选中态（金色醒目外框）与「战意 / 主武器状态」两样新读数。
##   `_选中` 是**纯表现**（谁被选中由门面 `unit_view()["选中"]` 给）；
##   `_战意行` / `_战意条` 只在数据里带 `战意`（= 单机牌组模式）时才占高度；
##   `_主武标` 是**右下角覆盖标签**（不进布局容器 → 卡片最小尺寸一个像素都不变）。
var _选中: bool = false
var _战意行: HBoxContainer
var _战意文: Label
var _战意条: ProgressBar
var _主武标: Label

func setup(data: Dictionary) -> void:
	数据 = data if data is Dictionary else {}
	_build()
	refresh()

## 便利重载：直接从会话门面取快照（M4-3 可用）。
func setup_unit(session: GameSession, side: String, unit_id: String) -> void:
	if session == null:
		setup({})
		return
	setup(session.unit_view(side, unit_id))

## ★ 关键：对父容器报出**真实**的最小尺寸（就是 `单位卡底` 要占的那一块）。
## 从前没有它 → 卡片对布局报高 0 → 同排卡片互相压在一起。
func _get_minimum_size() -> Vector2:
	var 内 := Vector2.ZERO
	if _底 != null:
		内 = _底.get_combined_minimum_size()
	return Vector2(maxf(内.x, custom_minimum_size.x), maxf(内.y, custom_minimum_size.y))

func refresh() -> void:
	if _名 == null:
		return
	if 数据.is_empty() or not bool(数据.get("ok", false)):
		_名.text = "（没有这台单位）"
		_职属.text = str(数据.get("为什么", "现在不在战斗里")) if not 数据.is_empty() else "没有数据"
		_血条.value = 0.0
		_血值.text = "HP —"
		_气势.text = "气势 —"
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
		# ★ UX-3：这一格没机体 → 动作反馈一并收掉（不留一条挂空的〔出手〕角标）。
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
	# ★ `fill` 的样式必须**不带内边距**：`UiTheme.底样式()` 的 content_margin = 10 会让
	#   `ProgressBar` 的最小高度变成 20（实测），生命条就吃掉一整行的高度。
	_血条.add_theme_stylebox_override("fill", _条样式(_血条色(比)))
	# ★ D-04：一律按百分比显示，不依赖 int/float 区分
	_血值.text = "HP %s / %s（%s%%）" % [UiTheme.文本(int(JsCompat.js_round(血))),
		UiTheme.文本(int(JsCompat.js_round(满))), UiTheme.文本(int(JsCompat.js_round(比 * 100.0)))]
	_气势.text = "气势 %s" % UiTheme.文本(int(JsCompat.js_round(float(数据.get("气势", 0.0)))))
	_气势.add_theme_color_override("font_color", UiTheme.希望色)
	_护盾.text = "护盾 %s" % UiTheme.文本(int(JsCompat.js_round(float(数据.get("护盾", 0.0)))))
	_护盾.add_theme_color_override("font_color", UiTheme.推进剂色)
	var 状态: Array = 数据.get("状态") if 数据.get("状态") is Array else []
	_状态行.text = " · ".join(状态.map(func(x): return UiTheme.文本(x)))
	_状态行.add_theme_color_override("font_color", UiTheme.次要文字)
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
	# ★ M4-3 新增两行：意图预告（敌方下一拍 / Boss 阶段）与 SEED 觉醒
	var 意图: Array = 数据.get("意图") if 数据.get("意图") is Array else []
	_意图行.text = "\n".join(意图.map(func(x): return UiTheme.文本(x)))
	_意图行.add_theme_color_override("font_color", UiTheme.难度色)
	_意图行.visible = not 意图.is_empty()
	_觉醒行.text = str(数据.get("觉醒", ""))
	_觉醒行.add_theme_color_override("font_color", UiTheme.希望色)
	_觉醒行.visible = not _觉醒行.text.is_empty()
	# ★ 空 / 默认的行**只隐藏、不删**（不占高度，`find_child` 照样找得到）。
	_状态行.visible = not _状态行.text.is_empty() and _状态行.text != "正常"
	_增益行.visible = not _增益行.text.is_empty()
	_开关行.visible = not _开关行.text.is_empty() and not _开关是默认()
	_建开关()
	_绑悬停(str(数据.get("悬停说明", "")))
	# ★ DECK-3 §1：战意（N / 100 + 进度条）与「主武就绪 / 已打主武」角标。
	_画战意()
	# ★ UX-3：卡底样式由「战斗反馈 > 卡牌来源联动 > 选中 > 默认」四级算出来（`refresh()` 不碰文本以外的东西）。
	_刷新卡底样式()
	visible = true

## ★ DECK-3 §1：`战意：N / 100`（金色进度条）与本回合主武器状态。
## **只在数据里带 `战意` 时才占高度** —— 旧口径（没有战意字段）整行 `visible = false`，
## 卡片的最小尺寸因此一个像素都不变（`test_presentation_layout.gd` 段 2b 的版面门禁照旧）。
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
		var 文 := str(数据.get("主武器状态", ""))
		_主武标.text = 文
		_主武标.visible = not 文.is_empty()
		_主武标.add_theme_color_override("font_color",
			UiTheme.禁用文字 if bool(数据.get("主武器已销毁", false)) else UiTheme.高亮)

## 现在是不是「选中」态（自动化测试读它）。
func 选中中() -> bool:
	return _选中

## ★ DECK-3 §1：设选中态 —— 开 = 2px 金色醒目外框（压过「卡牌来源联动」，被动作反馈压过）。
## 纯表现：只换 `单位卡底` 的样式，`数据` / 文本 / 最小尺寸一概不动。
func 设为选中(on: bool) -> void:
	if _选中 == on:
		return
	_选中 = on
	_刷新卡底样式()

## 点一下卡片（鼠标左键）→ 发 `点选` 信号（由战斗屏转发给门面 `select_battle_unit()`）。
## 开关按钮 / 手牌按钮那些子控件会先吃掉自己的点击，所以这里只会收到「卡面空白处」的点击。
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

## 开关行是不是「全是默认值」（保留大招关 / TRANSAM 自动 / 待机）。
## 是 → 这行不占高度（状态一眼就能看出来，不值得占一条卡面）。
func _开关是默认() -> bool:
	if _开关行 == null or _开关行.text.is_empty():
		return true
	for 条 in _开关行.text.split(" · "):
		var t := str(条)
		if t.ends_with("：开") or t.ends_with("：手动"):
			return false
	return true

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "单位卡"
	custom_minimum_size = Vector2(卡宽, 卡高)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	# ★ 内边距 4（四边）：从前是 UiTheme.面板内距 = 10，光内边距就吃掉 20px。
	var 底样式 := _卡底样式(UiTheme.卡片底, UiTheme.边框, 1)
	_底 = PanelContainer.new()
	_底.name = "单位卡底"
	_底.clip_contents = true
	_底.mouse_filter = Control.MOUSE_FILTER_PASS
	_底.add_theme_stylebox_override("panel", 底样式)
	add_child(_底)
	UiTheme.占满(_底)
	_列 = UiTheme.建盒(_底, "单位卡上下列", true, 1)
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
	_气势 = UiTheme.建标签(_数值行, "气势 —", UiTheme.字号_小, UiTheme.希望色)
	_气势.name = "气势"
	_气势.mouse_filter = Control.MOUSE_FILTER_PASS
	_护盾 = UiTheme.建标签(_数值行, "护盾 —", UiTheme.字号_小, UiTheme.推进剂色)
	_护盾.name = "护盾"
	_护盾.mouse_filter = Control.MOUSE_FILTER_PASS
	# ★ DECK-3 §1：战意条（金色进度条）+ 一行 `战意 N / 100`。
	#   只有单机牌组模式的单位快照才带 `战意` —— 旧口径下这一行 `visible = false`（不占高度）。
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
	# ★ 下面这些「状态 / 增益 / 开关 / 意图 / 觉醒」一律是**单行裁切**标签：
	#   节点照旧留在树上（`find_child` 找得到）、文本属性是**全文**，只是显示上不换行 ——
	#   于是每行的最小高度恒为一行，卡片不会被长文本撑高（完整内容在悬停说明里）。
	_状态行 = _单行(_列, "状态行", "", UiTheme.字号_小, UiTheme.次要文字)
	_增益行 = _单行(_列, "增益行", "", UiTheme.字号_小, UiTheme.高亮)
	_开关行 = _单行(_列, "开关行", "", UiTheme.字号_小, UiTheme.弱文字)
	# ★ M4-3 新增（不改上面任何一个已有节点名）
	_意图行 = _单行(_列, "意图行", "", UiTheme.字号_小, UiTheme.难度色)
	_觉醒行 = _单行(_列, "觉醒行", "", UiTheme.字号_小, UiTheme.希望色)
	_开关组 = UiTheme.建盒(_列, "开关按钮组", false, UiTheme.间距_小)
	_开关组.mouse_filter = Control.MOUSE_FILTER_PASS
	# ★ UX-2 第 2 项：来源联动角标。**直接挂在 `self` 上**（不进 `单位卡上下列`），
	#   所以它不参与任何容器布局 —— 卡片的最小尺寸一个像素都不变（版面门禁照旧）。
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
	# ★ UX-3 第 2 / 3 项：动作反馈角标（〔出手〕/〔大招〕/〔修理〕/〔受击〕/〔回复〕/〔击破〕）。
	#   同样**直接挂在 `self` 上**（右下角、不进布局容器）→ 卡片最小尺寸一个像素都不变，
	#   版面门禁（132×148 / 两两不重叠 / 卡身与卡底尺寸一致）照旧。
	#   描边用的是 `font_outline_color` + `outline_size`，压在任何内容上都看得清，不用再加底色块。
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
	# ★ DECK-3 §1：本回合主武器状态标签（左上角覆盖，**不进布局容器** → 最小尺寸不变）。
	#   `〔主武就绪〕` 亮金 / `〔已打主武〕` 暗灰；只有单机牌组模式的快照才带 `主武器状态`。
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

## 卡底样式（内边距 4、圆角、边框宽可调）—— `_build()` 与来源联动高亮共用一处。
func _卡底样式(色: Color, 边色: Color, 边宽: int) -> StyleBoxFlat:
	var s := UiTheme.底样式(色, 边色, 边宽)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

# ==========================================================================================
# ★ UX-2 第 2 项：卡牌来源联动高亮（悬停手牌 / 候补牌 → 场上带出这张牌的机体亮起来）
# ==========================================================================================

## 开 / 关「联动高亮」：开 = 青色 2px 外框 + 右上角〔卡牌来源〕角标。
## **纯表现**：只换 `单位卡底` 的样式与角标可见性，`数据`、文本、最小尺寸一概不动；
## 所以 `refresh()` 之后再调一次也不会打架（`refresh()` 不碰 `单位卡底` 的样式）。
func set_card_source_highlight(on: bool) -> void:
	_联动中 = on
	_刷新卡底样式()
	if _联动标 != null:
		_联动标.visible = on

## 现在是不是正被「卡牌来源」点亮（自动化测试与视图清理都用它读）。
func 联动高亮中() -> bool:
	return _联动中

# ==========================================================================================
# ★ UX-3 第 2 / 3 项：动作反馈（出手高亮 / 受击红闪 / 治疗绿闪）
# ==========================================================================================

## 设一个动作反馈。`kind` 见 `反馈类型们`；给空串 / 不认识的字符串 = 清空。
## `dir_x` 只用于前冲方向（我方朝右 +1 / 敌方朝左 -1），非 headless 时才真的动。
## ★ UX-5：`距离` > 0 时用它代替默认的前冲距离（战斗演出里传 14px；不传 = 老的 12px）。
func set_combat_fx(kind: String, dir_x: float = 0.0, 距离: float = 0.0) -> void:
	if not 反馈类型们.has(kind):
		clear_combat_fx()
		return
	_战斗反馈 = kind
	# ★ UX-5：动作反馈盖过发牌脉冲 —— 脉冲状态在这里收掉（外框不再停在青金色）。
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

## 别名（规格里给的第二个签名）：出手方高亮 + 朝敌方方向前冲。
func play_action_feedback(kind: String, dir_x: float) -> void:
	set_combat_fx(kind, dir_x)

## 收掉这一张卡上的动作反馈（样式回到「卡牌来源联动 > 默认」那一级）。
func clear_combat_fx() -> void:
	_战斗反馈 = ""
	_重置位移()
	_刷新卡底样式()
	if _动作标 != null:
		_动作标.visible = false

## 当前反馈类型（自动化测试读它；空串 = 没有反馈）。
func combat_fx_kind() -> String:
	return _战斗反馈

## 现在这张卡是不是正显示动作反馈。
func 战斗反馈中() -> bool:
	return not _战斗反馈.is_empty()

## 反馈 → 角标文字与颜色。
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

## 卡底样式：**战斗反馈 > 发牌脉冲 > 卡牌来源联动 > 选中 > 默认**，五级一处算完
## （`set_*` / `播放发牌脉冲()` / `设为选中()` / `refresh()` 都走这里）。
func _刷新卡底样式() -> void:
	if _底 == null:
		return
	var 色 := UiTheme.卡片底
	var 边 := UiTheme.边框
	var 宽 := 1
	# ★ DECK-3 §1：选中态 = 金色 2px 醒目外框（最底层的「有态度」样式）。
	if _选中:
		色 = UiTheme.卡片底_亮
		边 = UiTheme.高亮
		宽 = 2
	if _联动中:
		色 = UiTheme.卡片底_亮
		边 = UiTheme.推进剂色
		宽 = 2
	# ★ UX-5：发牌脉冲（青金色 glow）盖过「卡牌来源联动」，被下面的动作反馈盖过。
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

## 朝 `dir_x` 方向短促前冲 `距离` 像素（默认 12；战斗演出传 14）后回弹。
## ★ 只动 `单位卡底` 的左右 offset（宽度不变、`_get_minimum_size()` 不变、卡本身的 rect 不变），
##   所以绝不影响版面测量与两两不重叠的断言。
func _前冲(dir_x: float, 距离: float = 12.0) -> void:
	if UiTheme.无声模式() or _底 == null:
		return
	if dir_x == 0.0:
		return
	if not is_inside_tree():
		# 没进树就不建 Tween（`Node.create_tween()` 在树外拿不到 SceneTree）。
		return
	_重置位移()
	var 像素 := 距离 * signf(dir_x)
	_前冲补间 = create_tween()
	_前冲补间.tween_method(_设偏移, 0.0, 像素, 0.09)
	_前冲补间.tween_method(_设偏移, 像素, 0.0, 0.16)
	_前冲补间.tween_callback(_重置位移)

## ★ UX-5：受击「左右震动」（规格：受击方红闪 + 左右震动）。
## 只动 `单位卡底` 的 `offset_left` / `offset_right`（两个一起动 → 宽度不变、卡不挪位）。
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

## 受击 / 治疗的「闪一下」：角标与卡片内部视觉层短促明暗一下（不改布局）。
func _闪一下() -> void:
	if UiTheme.无声模式() or _动作标 == null:
		return
	if not is_inside_tree():
		return
	_动作标.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var t := create_tween()
	t.tween_property(_动作标, "modulate:a", 0.35, 0.08)
	t.tween_property(_动作标, "modulate:a", 1.0, 0.14)

## 给 `单位卡底` 一个左右偏移（两个 offset 一起动 → 宽度不变）。
func _设偏移(v: float) -> void:
	if _底 == null or not is_instance_valid(_底):
		return
	_底.offset_left = v
	_底.offset_right = v

## ★ UX-5：给 `单位卡底` 一个纵向偏移（上下两个 offset 一起动 → 高度不变）。
func _设纵偏移(v: float) -> void:
	if _底 == null or not is_instance_valid(_底):
		return
	_底.offset_top = v
	_底.offset_bottom = v

## 位移归零（前冲结束 / 清空反馈 / 拆前先回到干净状态）。
func _重置位移() -> void:
	if _前冲补间 != null and _前冲补间.is_valid():
		_前冲补间.kill()
	_前冲补间 = null
	if _跳动补间 != null and _跳动补间.is_valid():
		_跳动补间.kill()
	_跳动补间 = null
	_设偏移(0.0)
	_设纵偏移(0.0)

# ==========================================================================================
# ★ UX-5：发牌脉冲（来源机体卡亮青金外框 + 向上轻跳）
# ==========================================================================================

## 发牌演出时叫一下：青金色 2px 发光外框 + 向上轻跳 8px。
## **纯表现**：`数据` / 文本 / 最小尺寸一概不动，只换 `单位卡底` 的样式与纵偏移
## → 战斗屏的版面门禁（132×148 / 两两不重叠 / 卡身与卡底尺寸一致）一个像素都不变。
func 播放发牌脉冲() -> void:
	if _底 == null:
		return
	_发牌脉冲中 = true
	_刷新卡底样式()
	if UiTheme.无声模式() or not is_inside_tree():
		return
	_轻跳()

## 收掉发牌脉冲（换场 / 下一次动作反馈之前调）。
func 清发牌脉冲() -> void:
	_重置位移()
	if not _发牌脉冲中:
		return
	_发牌脉冲中 = false
	_刷新卡底样式()

## 现在是不是正亮着发牌脉冲（自动化测试读它）。
func 发牌脉冲中() -> bool:
	return _发牌脉冲中

## 向上轻跳 8px 后落回（只动 `单位卡底` 的纵偏移，高度不变）。
func _轻跳() -> void:
	if _底 == null:
		return
	if _跳动补间 != null and _跳动补间.is_valid():
		_跳动补间.kill()
	_跳动补间 = create_tween()
	_跳动补间.tween_method(_设纵偏移, 0.0, -发牌轻跳, 0.10)
	_跳动补间.tween_method(_设纵偏移, -发牌轻跳, 0.0, 0.14)
	_跳动补间.tween_callback(_设纵偏移.bind(0.0))

## 单行裁切标签（最小高度恒为一行；全文留在 `text` 里，悬停说明给完整内容）。
func _单行(父: Node, 名: String, 文本: String, 大小: int, 色: Color) -> Label:
	var l := UiTheme.建标签(父, 文本, 大小, 色)
	l.name = 名
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

## 不带内边距的进度条样式（`content_margin` 一律 0 —— 否则最小高度会是 20）。
func _条样式(色: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = 色
	s.set_corner_radius_all(3)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

## ★ UX-6（2026-10-19，作者反馈第 4 条）：**「憋大招」切换按钮下线** ——
## 内核的 `GameSession.toggle_hold_ultimate()` / `toggle_unit_switch("保留大招")` 保留不动
## （防旧内核测试报错），大招状态 / 冷却仍写在「开关行」文字与悬停说明里，
## 但界面上不再显示那个可点的小按钮。这里只剩天人的 TRANS-AM 两个按钮。
func _建开关() -> void:
	_清空(_开关组)
	var 键 := str(数据.get("键", 数据.get("模板", "")))
	if 键.is_empty():
		return
	var 提示: Dictionary = 数据.get("开关提示") if 数据.get("开关提示") is Dictionary else {}
	if str(数据.get("势力", "")) == "天人":
		_加开关按钮(键, "TRANSAM", false, 提示.get("TRANSAM"), "TA")
		_加开关按钮(键, "开 TRANS-AM", true, 提示.get("开状态"), "开TA")

## 建一个开关按钮。`提示`（M4-3 的新数据键，可缺）给 `{文字, 可点, 为什么}`；
## 没有提示 = M4-2 的老样子（按钮可点、文字用默认的）。
## ★ 表现层不自己判「能不能点」：`可点` 由持有 session 的一方按内核事实填；点不动的原因走 `为什么`。
## ★ 文案取**短的**（`短题`），11pt + 左右内边距 4 —— 三个按钮加起来也不会把卡宽撑过 132px。
func _加开关按钮(键: String, 题: String, 是开状态: bool, 提示: Variant, 短题: String) -> void:
	var 可点 := true
	var 为什么 := ""
	if 提示 is Dictionary:
		可点 = bool((提示 as Dictionary).get("可点", true))
		为什么 = str((提示 as Dictionary).get("为什么", ""))
	var b: Button
	if 是开状态:
		b = UiTheme.建按钮(_开关组, 短题, _点开状态.bind(键))
		b.tooltip_text = 为什么 if not 为什么.is_empty() else "没解锁 / 冷却中 / 已经开着 → 这次开不出来（原因在状态行）"
	else:
		b = UiTheme.建按钮(_开关组, 短题, _点开关.bind(键, 题))
		b.tooltip_text = 为什么 if not 为什么.is_empty() else "点一下切换（内核那边是整表替换）"
	b.disabled = not 可点
	b.add_theme_font_size_override("font_size", UiTheme.字号_小)
	b.add_theme_stylebox_override("normal", _紧凑按钮())
	b.add_theme_stylebox_override("hover", _紧凑按钮())
	b.add_theme_stylebox_override("pressed", _紧凑按钮())
	b.add_theme_stylebox_override("focus", _紧凑按钮())
	b.add_theme_stylebox_override("disabled", _紧凑按钮())

## 紧凑按钮样式（左右内边距 4、上下 1 + 亮边框）。
func _紧凑按钮() -> StyleBoxFlat:
	var s := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.边框)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	s.set_corner_radius_all(3)
	return s

# ==========================================================================================
# Mouse Over（悬停说明）
# ==========================================================================================

## 把同一段说明挂到卡片自身、`单位卡底`、`单位卡上下列`、生命条、数值行与所有标签 / 开关按钮上。
## 为什么挂这么多处：Godot 的 `mouse_entered` 只发给**鼠标底下最深的那一个**非 IGNORE 控件，
## 而这些子节点都是 `MOUSE_FILTER_PASS`（要求如此），所以每一处都接一次才真的「任意位置都能弹」。
func _绑悬停(文: String) -> void:
	if 文.strip_edges().is_empty():
		return
	for c in [self, _底, _列, _血条, _数值行, _名, _职属, _血值, _气势, _护盾,
			_状态行, _增益行, _开关行, _意图行, _觉醒行, _开关组, _战意行, _战意条]:
		if c is Control:
			HoverTooltip.bind(c, 文, "机体")
	for b in _开关组.get_children():
		if b is Control:
			HoverTooltip.bind(b, 文, "机体")

# ==========================================================================================
# 开关（不自己调内核，只发信号）
# ==========================================================================================

func _点开关(键: String, 开关键: String) -> void:
	开关切换.emit(键, 开关键)

func _点开状态(键: String) -> void:
	开状态.emit(键)

# ==========================================================================================
# 小工具
# ==========================================================================================

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
