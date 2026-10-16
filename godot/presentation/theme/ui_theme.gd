## 表现层视觉常量与建控件小工具（Stage M4-2）。
##
## 纪律：
##   · 配色 / 字号 / 间距**只在本文件里定义**，各 view 里不许再出现写死的数字；
##   · 基调照 `presentation/boot/boot.tscn`：深蓝黑底 + 白字 + 半透明次要信息；
##   · 界面文字**只用 GB2312 一级常用字**（`test_font_coverage.gd` 是硬门禁）；
##   · 本文件在 `res://presentation` 下，受 `test_boundary.gd` 的「零 Js 宏」约束。
## 本文件是纯常量 + 建节点的小工具，不持有会话、不读 `GameSession`。
class_name UiTheme
extends RefCounted

# ==========================================================================================
# 一、配色（深蓝黑底系）
# ==========================================================================================
const 底色 := Color(0.07, 0.09, 0.13)
const 面板底 := Color(0.105, 0.135, 0.19)
const 卡片底 := Color(0.145, 0.18, 0.25)
const 卡片底_亮 := Color(0.20, 0.25, 0.34)
const 黑幕 := Color(0.02, 0.03, 0.05, 0.72)
const 边框 := Color(0.30, 0.39, 0.52)
const 边框_亮 := Color(0.55, 0.70, 0.92)

const 主文字 := Color(0.93, 0.96, 1.00)
const 次要文字 := Color(1.0, 1.0, 1.0, 0.62)
const 弱文字 := Color(1.0, 1.0, 1.0, 0.38)
const 禁用文字 := Color(1.0, 1.0, 1.0, 0.26)

const 正面 := Color(0.36, 0.85, 0.55)
const 负面 := Color(0.93, 0.38, 0.34)
const 高亮 := Color(1.00, 0.82, 0.35)

const 推进剂色 := Color(0.45, 0.78, 1.00)
const 希望色 := Color(0.78, 0.68, 1.00)
const 源碳色 := Color(0.99, 0.72, 0.35)
const 耐久色 := Color(0.36, 0.85, 0.55)
const 经验色 := Color(0.62, 0.82, 1.00)
const 难度色 := Color(1.00, 0.55, 0.45)

# 大地图状态色
const 已走过色 := Color(0.40, 0.46, 0.55)
const 当前格色 := Color(1.00, 0.95, 0.60)
const 必经点色 := Color(0.96, 0.55, 0.42)
const 可移动色 := Color(0.36, 0.85, 0.55)
const 揭开色 := Color(0.62, 0.72, 0.86)
const 零件目标色 := Color(1.00, 0.62, 0.90)

# 节点类型兜底色（Db 里没有 `节点类型表` 时用）
const 节点兜底色 := {
	"起点": Color(0.54, 0.60, 0.67),
	"空": Color(0.34, 0.38, 0.42),
	"作战": Color(0.85, 0.34, 0.29),
	"精英": Color(1.00, 0.48, 0.42),
	"事件": Color(0.79, 0.66, 1.00),
	"黑市": Color(0.91, 0.64, 0.23),
	"休整": Color(0.36, 0.75, 0.54),
	"招募站": Color(0.56, 0.77, 1.00),
	"隧道": Color(0.70, 0.62, 0.86),
	"瞭望站": Color(1.00, 0.82, 0.40),
	"遗迹": Color(1.00, 0.82, 0.40),
	"侵蚀源": Color(1.00, 0.37, 0.77),
	"出口守军": Color(1.00, 0.48, 0.42),
	"出口尽头": Color(0.36, 0.75, 0.54),
	"出口小径": Color(0.48, 0.82, 0.66),
	"追击": Color(1.00, 0.55, 0.30),
}

# 节点类型短标签（按钮上只用一两个字；全部是常用字）
const 节点短名 := {
	"起点": "起",
	"空": "空",
	"作战": "战",
	"精英": "精",
	"事件": "事",
	"黑市": "市",
	"休整": "休",
	"招募站": "招",
	"隧道": "隧",
	"瞭望站": "望",
	"遗迹": "遗",
	"侵蚀源": "蚀",
	"出口守军": "守",
	"出口尽头": "尽",
	"出口小径": "径",
	"追击": "追",
}

# ==========================================================================================
# 二、字号 / 间距 / 大小
# ==========================================================================================
const 字号_大标题 := 34
const 字号_标题 := 21
const 字号_小节 := 16
const 字号_正文 := 13
const 字号_小 := 11

const 间距_大 := 14
const 间距 := 8
const 间距_小 := 4
const 面板内距 := 10
const 角半径 := 6
const 格边长 := 58
const 顶栏高 := 104

# ==========================================================================================
# 三、节点类型 → 展示
# ==========================================================================================

## 节点类型的中文名（Db 的 `节点类型表` 优先，没有就原样返回）。
static func 节点全名(类型: String) -> String:
	var t: Variant = Db.T.get("节点类型表")
	if t is Dictionary:
		var e: Variant = (t as Dictionary).get(类型)
		if e is Dictionary and (e as Dictionary).has("名"):
			return str((e as Dictionary)["名"])
	return 类型

## 节点类型的短标签（地图格子上的那一个字）。
static func 节点短名Of(类型: String) -> String:
	return str(节点短名.get(类型, 类型.substr(0, 1) if not 类型.is_empty() else "?"))

## 节点类型用哪个色（Db 的 `节点类型表.色` 优先）。
static func 节点色(类型: String) -> Color:
	var t: Variant = Db.T.get("节点类型表")
	if t is Dictionary:
		var e: Variant = (t as Dictionary).get(类型)
		if e is Dictionary and (e as Dictionary).has("色"):
			return Color.from_string(str((e as Dictionary)["色"]), 次要文字)
	var 兜: Variant = 节点兜底色.get(类型)
	return 兜 if 兜 is Color else 次要文字

# ==========================================================================================
# 四、建控件小工具（view 里只用这些，不自己写样式）
# ==========================================================================================

## 纯色实心块（面板 / 卡片底）。
static func 底样式(色: Color = 卡片底, 边色: Color = 边框, 边宽: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = 色
	s.border_color = 边色
	s.set_border_width_all(边宽)
	s.set_corner_radius_all(角半径)
	s.content_margin_left = 面板内距
	s.content_margin_right = 面板内距
	s.content_margin_top = 面板内距
	s.content_margin_bottom = 面板内距
	return s

## 往 `父` 上挂一个带底色的面板（`PanelContainer`），返回它。
static func 建面板(父: Node, 名: String, 色: Color = 面板底, 边色: Color = 边框) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = 名
	p.add_theme_stylebox_override("panel", 底样式(色, 边色))
	父.add_child(p)
	return p

## 往 `父` 上挂一个盒子（默认上下），返回它。
static func 建盒(父: Node, 名: String, 上下: bool = true, 间隔: int = 间距) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if 上下 else HBoxContainer.new()
	b.name = 名
	b.add_theme_constant_override("separation", 间隔)
	父.add_child(b)
	return b

## 往 `父` 上挂一个标签。
static func 建标签(父: Node, 文本: String, 大小: int = 字号_正文, 色: Color = 主文字) -> Label:
	var l := Label.new()
	l.text = 文本
	l.add_theme_font_size_override("font_size", 大小)
	l.add_theme_color_override("font_color", 色)
	父.add_child(l)
	return l

## 往 `父` 上挂一个会自动换行的说明标签（长文本用这个，别把面板占开）。
static func 建说明(父: Node, 文本: String, 大小: int = 字号_小, 色: Color = 次要文字) -> Label:
	var l := 建标签(父, 文本, 大小, 色)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## 往 `父` 上挂一个标题标签。
static func 建标题(父: Node, 文本: String, 大小: int = 字号_标题) -> Label:
	return 建标签(父, 文本, 大小, 主文字)

## 往 `父` 上挂一个按钮；`处理` 给了就接上 `pressed`（用 Variant + null 默认值，避免默认参数写 Callable）。
static func 建按钮(父: Node, 文本: String, 处理: Variant = null) -> Button:
	var b := Button.new()
	b.text = 文本
	b.add_theme_font_size_override("font_size", 字号_正文)
	if 处理 is Callable and (处理 as Callable).is_valid():
		b.pressed.connect(处理)
	父.add_child(b)
	return b

## 往 `父` 上挂一个「进度条 + 数值」的进度条。
static func 建比例条(父: Node, 名: String, 比例: float, 色: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.name = 名
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(比例, 0.0, 1.0)
	p.custom_minimum_size = Vector2(0, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 满 := StyleBoxFlat.new()
	满.bg_color = 色
	满.set_corner_radius_all(3)
	var 空 := StyleBoxFlat.new()
	空.bg_color = Color(1, 1, 1, 0.14)
	空.set_corner_radius_all(3)
	p.add_theme_stylebox_override("fill", 满)
	p.add_theme_stylebox_override("background", 空)
	父.add_child(p)
	return p

## 往 `父` 上挂一个 `ScrollContainer`，里面再挂一个上下盒；返回里面的那个盒。
static func 建滚动(父: Node, 名: String, 高: float = 0.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = 名
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if 高 > 0.0:
		sc.custom_minimum_size = Vector2(0, 高)
	父.add_child(sc)
	var 内 := 建盒(sc, 名 + "内容", true, 间距_小)
	内.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return 内

## 一个固定高度的空行（占开间距用）。
static func 建空行(父: Node, 高: int = 间距) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 高)
	父.add_child(c)
	return c

## 一条分隔线。
static func 建分隔(父: Node) -> HSeparator:
	var s := HSeparator.new()
	父.add_child(s)
	return s

## 把 `节点` 占满父矩形（顶栏 / 屏幕容器 / 弹窗层都用它）。
static func 占满(节点: Control) -> void:
	节点.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## 顶栏那种「顶部一条」的锚定。
static func 顶部一条(节点: Control, 高: float) -> void:
	节点.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	节点.offset_bottom = 高

# ==========================================================================================
# 五、文本小工具
# ==========================================================================================

## 任意 Variant → 字符串（GDScript 4 的 `String(int)` 会报构造器错误，一律走 `str`）。
static func 文本(v: Variant) -> String:
	return str(v) if v != null else ""

## `当前 / 上限` 这种比值的文字。
static func 比值(当前: Variant, 上限: Variant) -> String:
	return "%s / %s" % [文本(当前), 文本(上限)]

## 一层层的键值行文字（`键：值`）。
static func 键值(键: String, 值: Variant) -> String:
	return "%s：%s" % [键, 文本(值)]
