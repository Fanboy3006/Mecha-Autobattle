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
## ★ Stage M4-3 的扩展（**只加不删**；下面这些节点名是既有契约，一个都没动）：
##   `单位卡/单位名/单位职属/生命条/生命数值/气势/护盾/状态行/增益行/开关行/开关按钮组`
##   **新增**：`意图行`（敌方下一拍意图预告 / Boss 阶段预告）、`觉醒行`（SEED 累计 / 已觉醒）。
##   新增的两个可选数据键（由持有 session 的一方填好、这里只把它画出来）：
##     · `数据["意图"]`：Array[String] —— 每行一句（内核纯函数算出来的事实）；
##     · `数据["觉醒"]`：String；
##     · `数据["开关提示"]`：Dictionary —— 开关键 → `{文字, 可点, 为什么}`（没有就按 M4-2 的老样子建按钮）。
class_name UnitCard
extends Control

## 切一个开关键（`"保留大招"` / `"TRANSAM"`）。
signal 开关切换(单位键: String, 开关键: String)
## 手动激活势力状态（今天只有天人 TRANS-AM 这一条路）。
signal 开状态(单位键: String)

var 数据: Dictionary = {}

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
		_清空(_开关组)
		return
	_名.text = "%s · %s" % [str(数据.get("名", "?")), str(数据.get("位名", ""))]
	_职属.text = "Lv%s · %s · %s · %s" % [UiTheme.文本(数据.get("等级", 0)), str(数据.get("职业", "")),
		str(数据.get("势力", "")), "在场" if bool(数据.get("活着", false)) else "已倒下"]
	var 血 := float(数据.get("HP", 0.0))
	var 满 := float(数据.get("最大HP", 1.0))
	var 比 := float(数据.get("血比", 0.0))
	_血条.value = 比
	_血条.add_theme_stylebox_override("fill", UiTheme.底样式(_血条色(比), _血条色(比), 0))
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
	_建开关()
	visible = true

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "单位卡"
	custom_minimum_size = Vector2(190, 0)
	var 底 := UiTheme.建面板(self, "单位卡底", UiTheme.卡片底, UiTheme.边框)
	UiTheme.占满(底)
	var 列 := UiTheme.建盒(底, "单位卡上下列", true, UiTheme.间距_小)

	_名 = UiTheme.建标签(列, "（没有这台单位）", UiTheme.字号_小节, UiTheme.主文字)
	_名.name = "单位名"
	_职属 = UiTheme.建标签(列, "", UiTheme.字号_小, UiTheme.次要文字)
	_职属.name = "单位职属"
	_血条 = UiTheme.建比例条(列, "生命条", 0.0, UiTheme.正面)
	_血值 = UiTheme.建标签(列, "HP —", UiTheme.字号_小, UiTheme.主文字)
	_血值.name = "生命数值"
	var 数值行 := UiTheme.建盒(列, "数值行", false, UiTheme.间距)
	_气势 = UiTheme.建标签(数值行, "气势 —", UiTheme.字号_小, UiTheme.希望色)
	_气势.name = "气势"
	_护盾 = UiTheme.建标签(数值行, "护盾 —", UiTheme.字号_小, UiTheme.推进剂色)
	_护盾.name = "护盾"
	_状态行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	_状态行.name = "状态行"
	_增益行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.高亮)
	_增益行.name = "增益行"
	_开关行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.弱文字)
	_开关行.name = "开关行"
	# ★ M4-3 新增（不改上面任何一个已有节点名）
	_意图行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.难度色)
	_意图行.name = "意图行"
	_觉醒行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.希望色)
	_觉醒行.name = "觉醒行"
	_开关组 = UiTheme.建盒(列, "开关按钮组", false, UiTheme.间距_小)

func _建开关() -> void:
	_清空(_开关组)
	var 键 := str(数据.get("键", 数据.get("模板", "")))
	if 键.is_empty():
		return
	var 提示: Dictionary = 数据.get("开关提示") if 数据.get("开关提示") is Dictionary else {}
	_加开关按钮(键, "保留大招", false, 提示.get("保留大招"))
	if str(数据.get("势力", "")) == "天人":
		_加开关按钮(键, "TRANSAM", false, 提示.get("TRANSAM"))
		_加开关按钮(键, "开 TRANS-AM", true, 提示.get("开状态"))

## 建一个开关按钮。`提示`（M4-3 的新数据键，可缺）给 `{文字, 可点, 为什么}`；
## 没有提示 = M4-2 的老样子（按钮可点、文字用默认的）。
## ★ 表现层不自己判「能不能点」：`可点` 由持有 session 的一方按内核事实填；点不动的原因走 `为什么`。
func _加开关按钮(键: String, 题: String, 是开状态: bool, 提示: Variant) -> void:
	var 文 := 题
	var 可点 := true
	var 为什么 := ""
	if 提示 is Dictionary:
		文 = str((提示 as Dictionary).get("文字", 题))
		可点 = bool((提示 as Dictionary).get("可点", true))
		为什么 = str((提示 as Dictionary).get("为什么", ""))
	var b: Button
	if 是开状态:
		b = UiTheme.建按钮(_开关组, 文, _点开状态.bind(键))
		b.tooltip_text = 为什么 if not 为什么.is_empty() else "没解锁 / 冷却中 / 已经开着 → 这次开不出来（原因在状态行）"
	else:
		b = UiTheme.建按钮(_开关组, 文, _点开关.bind(键, 题))
		b.tooltip_text = 为什么 if not 为什么.is_empty() else "点一下切换（内核那边是整表替换）"
	b.disabled = not 可点
	b.add_theme_font_size_override("font_size", UiTheme.字号_小)

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
