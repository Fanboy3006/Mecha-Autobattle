## 悬停说明层（Mouse Over Tooltip）—— **整局只有一层**，挂在 boot 的最后一个子节点上。
##
## 契约（`协作/架构/M4-表现层接口契约.md` §1 / §3）：
##   · `extends Control`，自己**不认识** `GameSession`：说明文本由调用方（视图 / 门面）给；
##   · 一个视图文件一个 `class_name`，别的文件直接用类名引用；
##   · 本文件在 `res://presentation` 下，受 `test_boundary.gd` 的「零 `J.*`」约束。
##
## 用法（三种，随便挑一种）：
##   · `HoverTooltip.bind(控件, "多行说明文字")`      —— 静态说明；
##   · `HoverTooltip.bind(控件, func(): return 现取) ` —— 每次悬停现取（会变的状态用这个）；
##   · `HoverTooltip.bind(控件, 说明, "标题")`        —— 顺带给面板一个标题。
##   半路拿到新的说明时调 `HoverTooltip.重绑(控件, 新说明)`（等价于再 `bind` 一次）。
##
## ★ 自动化测试友好：`show_for_control(控件)` 是**公开的编程入口**，headless 下直接调它就能
##   把面板真的显示出来并按视口夹紧位置 —— 不必去伪造鼠标事件。
class_name HoverTooltip
extends Control

## 默认面板宽度上限（超过就自动换行；不会把面板撑出屏）。
const 面板最大宽 := 380.0
## 面板高度上限（说明再长也不会竖着铺满整屏）。
const 面板最大高 := 560.0
## 面板与视口边缘至少留出的空隙。
const 边距 := 8.0
## 标题那一行的高度（估算面板总高时用）。
const 标题行高 := 22.0
## 拿不到视口时的兜底尺寸（工程默认画布）。
const 兜底视口 := Vector2(1280, 720)

## 记在控件上的 meta 键（**必须是 ASCII 标识符**）。
const META_原提示 := "hover_orig_tip"
const META_标题 := "hover_title"
const META_取值 := "hover_value"
const META_已绑 := "hover_layer"
## ★ UX-1 第 5 项（2026-10-19）：**「这个控件已经挂过悬停说明」的对外标记**。
##   自动化门禁与别的视图都可以用 `ctrl.has_meta("_hover_bound")` 一眼查出来（比 `hover_layer`
##   那个要比较实例的键更直观）。`bind()` 每次都会把它置 true。
const META_已绑标记 := "_hover_bound"

## 当前唯一活着的那一层（场景里可能同时有测试造的多个实例，这里只记**最后 bind 过的那个**）。
static var instance: HoverTooltip = null

var _面板: PanelContainer
var _标题: Label
var _滚: ScrollContainer
var _正文: Label
## 现在挂在哪一个控件上（隐藏时清空）。
var _锚: Control = null

func _init() -> void:
	name = "悬停说明层"
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.占满(self)
	_build()
	visible = false

func _build() -> void:
	_面板 = PanelContainer.new()
	_面板.name = "悬停面板"
	_面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_面板.visible = false
	_面板.clip_contents = true
	_面板.custom_minimum_size = Vector2(0, 0)
	var 样式 := UiTheme.底样式(UiTheme.底色, UiTheme.边框_亮)
	样式.content_margin_left = 8
	样式.content_margin_right = 8
	样式.content_margin_top = 6
	样式.content_margin_bottom = 6
	_面板.add_theme_stylebox_override("panel", 样式)
	_面板.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_面板.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_面板)

	var 内容 := UiTheme.建盒(_面板, "悬停内容", true, 2)
	内容.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_标题 = UiTheme.建标签(内容, "", UiTheme.字号_正文, UiTheme.高亮)
	_标题.name = "悬停标题"
	_标题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ★ 正文放进 `ScrollContainer`：`Control.size` **永远不会小于** `get_combined_minimum_size()`，
	#   而自动换行 Label 的最小高度 = 全文排完的高度（一把武器一行就上百字 → 面板能长到 600+）。
	#   有了这个滚动区，面板的最小高度就由它的 `custom_minimum_size` 说了算，指到多少就是多少。
	_滚 = ScrollContainer.new()
	_滚.name = "悬停滚动"
	_滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_滚.clip_contents = true
	_滚.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_滚.custom_minimum_size = Vector2(面板最大宽 - 24.0, 20)
	内容.add_child(_滚)
	_正文 = UiTheme.建说明(_滚, "", UiTheme.字号_小, UiTheme.主文字)
	_正文.name = "悬停正文"
	_正文.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_正文.custom_minimum_size = Vector2(面板最大宽 - 24.0, 0)

# ==========================================================================================
# 绑定（静态入口）
# ==========================================================================================

## 把一个控件挂上悬停说明。`文本或取值` 收 `String`（静态文字）或 `Callable`（悬停那一刻现取）。
## 返回 `文本或取值` 原样（方便链式写）。
## ★ 记在控件上的 meta 键一律用 **ASCII** 名字：Godot 的 `set_meta()` 只收合法标识符，
##   中文键会被拒（`Invalid metadata identifier`）。
static func bind(ctrl: Control, 文本或取值: Variant, 标题: String = "") -> Variant:
	if ctrl == null:
		return 文本或取值
	var 静态 := ""
	if 文本或取值 is Callable:
		pass
	elif 文本或取值 != null:
		静态 = str(文本或取值)
	# ① 顺手写进原生 tooltip（没有悬停层时也不至于什么都没有）。
	#    控件自己原来那句提示**保留**（存在 meta 里，反复 `bind` 也不会越拼越长）。
	if not ctrl.has_meta(META_原提示):
		ctrl.set_meta(META_原提示, ctrl.tooltip_text)
	var 原 := str(ctrl.get_meta(META_原提示, ""))
	var 新 := (标题 + "\n" + 静态) if not 标题.is_empty() else 静态
	ctrl.tooltip_text = 原 if 新.is_empty() else (原 + "\n" + 新 if not 原.is_empty() else 新)
	ctrl.set_meta(META_标题, 标题)
	ctrl.set_meta(META_取值, 文本或取值)
	ctrl.set_meta(META_已绑标记, true)
	var 层 := _找层(ctrl)
	if 层 == null:
		return 文本或取值
	# 同一个控件只接一次信号（`bind` 会被 `refresh()` 反复调到）；
	# 换了一层（例如测试另造了一个）才重新接。
	if not ctrl.has_meta(META_已绑) or ctrl.get_meta(META_已绑, null) != 层:
		ctrl.set_meta(META_已绑, 层)
		ctrl.mouse_entered.connect(层._入.bind(ctrl))
		ctrl.mouse_exited.connect(层._出.bind(ctrl))
		ctrl.gui_input.connect(层._动.bind(ctrl))
		ctrl.tree_exiting.connect(层._出.bind(ctrl))
		# 控件自己被隐藏（换屏 / 关面板）也把面板收掉，免得留一块说明挂在那儿。
		ctrl.visibility_changed.connect(层._视.bind(ctrl))
	return 文本或取值

## 覆盖式重绑：先断掉旧连接再挂新的（视图 `refresh()` 每次重建控件时用得上）。
static func 重绑(ctrl: Control, 文本或取值: Variant, 标题: String = "") -> Variant:
	return bind(ctrl, 文本或取值, 标题)

# ==========================================================================================
# 显示 / 隐藏（公开编程入口：测试直接调它）
# ==========================================================================================

## 用**已经绑定好**的说明显示面板（`bind()` 记录在控件的 meta 里）。
func show_for_control(ctrl: Control) -> void:
	if ctrl == null:
		hide_tip()
		return
	var 取值: Variant = ctrl.get_meta(META_取值, "")
	var 文本 := ""
	if 取值 is Callable:
		var f: Callable = 取值
		文本 = str(f.call()) if f.is_valid() else ""
	elif 取值 != null:
		文本 = str(取值)
	show_text(文本, str(ctrl.get_meta(META_标题, "")), ctrl)

## 直接给文字显示（不经过控件 meta）。位置按 `锚`（可空 = 鼠标位置）夹在视口里。
func show_text(文本: String, 标题: String = "", 锚: Control = null) -> void:
	if 文本.strip_edges().is_empty():
		hide_tip()
		return
	_锚 = 锚
	_标题.text = 标题
	_标题.visible = not 标题.is_empty()
	_正文.text = 文本
	var 宽 := clampf(float(文本.length()) * 3.2, 150.0, 面板最大宽 - 24.0)
	_正文.custom_minimum_size = Vector2(宽, 0)
	# 正文的显示高度 = 「按每行约 26 个汉字估的行数 × 行高」，再夹到面板高度上限以内。
	var 行数 := maxf(1.0, ceilf(float(文本.length()) / 26.0))
	var 正文高 := clampf(行数 * 17.0, 18.0, 面板最大高 - 标题行高 - 30.0)
	_滚.custom_minimum_size = Vector2(宽, 正文高)
	_面板.visible = true
	visible = true
	_夹紧()

func hide_tip() -> void:
	_锚 = null
	_面板.visible = false
	visible = false

## 悬停层的「当前说明」文本（测试断言用）。
func 当前文本() -> String:
	return _正文.text if _正文 != null else ""

# ==========================================================================================
# 内部：找层 / 事件
# ==========================================================================================

## 找到能用的悬停层：① boot 建的那一层（按名字在场景树里找）；② 静态 `instance`。
## ★ headless 测试跑在 `SceneTree._initialize()` 里，那时 `root` **还没进树**
##   （`root.is_inside_tree()` 是 false）→ `get_tree()` 会报错，所以先 `is_inside_tree()` 过一道。
static func _找层(ctrl: Control) -> HoverTooltip:
	if ctrl != null and ctrl.is_inside_tree():
		var 树 := ctrl.get_tree()
		if 树 != null and 树.root != null:
			var n := 树.root.find_child("悬停说明层", true, false)
			if n is HoverTooltip:
				instance = n
				return n
	if instance != null and is_instance_valid(instance):
		return instance
	return null

## 层自己进树时登记成「当前层」（真机上 boot 建的这一层就会走这儿）。
func _ready() -> void:
	instance = self

func _入(ctrl: Control) -> void:
	show_for_control(ctrl)

func _出(_ctrl: Control) -> void:
	hide_tip()

## 控件可见性变了：变不可见就收起来（换屏 / 关面板时不会留一块悬停说明挂在屏幕上）。
func _视(ctrl: Control) -> void:
	if ctrl != null and not ctrl.is_visible_in_tree():
		hide_tip()

func _动(事件: InputEvent, ctrl: Control) -> void:
	if 事件 is InputEventMouseMotion:
		_锚 = ctrl
		if _面板.visible:
			_夹紧()

## ★ 修复「mouse over 压在鼠标中间」（2026-10-16 作者试玩反馈）：
##   从前进来说明面板是跟着**锚控件**在 `gui_input` 里挪的 —— 鼠标停在控件正中时
##   面板就盖在指针上。现在改成**实时跟鼠标**：鼠标一动就按当前坐标重摆一次，
##   于是说明永远在鼠标**右边**（最右缘时翻到左边），绝不压住指针本身。
func _input(event: InputEvent) -> void:
	if _面板 == null or not _面板.visible:
		return
	if event is InputEventMouseMotion:
		_夹紧()

## 视口尺寸。★ 一律**收在设计画布 1280×720 以内**：
##   ① headless 下 `root.get_visible_rect()` 会给出 1280×1280 这种非设计尺寸；
##   ② 要求就是「悬停面板绝不出 1280×720」。
func _视口() -> Vector2:
	var 实 := 兜底视口
	if is_inside_tree():
		var 树 := get_tree()
		if 树 != null and 树.root != null:
			var v := 树.root.get_visible_rect().size
			if v.x > 0.0 and v.y > 0.0:
				实 = v
	return Vector2(minf(实.x, 兜底视口.x), minf(实.y, 兜底视口.y))

## 鼠标在**视口坐标**里的位置（拿不到视口就退回 `get_global_mouse_position()`）。
func _鼠标位置() -> Vector2:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			return vp.get_mouse_position()
	return get_global_mouse_position()

## 把面板摆在**鼠标右边**并夹在视口内（右边放不下就翻到左边）。
##
## ★ 2026-10-16 重写（作者试玩反馈「mouse over 要在鼠标的右边，不能直接在鼠标中间」）：
##   从前这里是「优先用 `_锚.get_global_rect()` 左下角定位」—— 鼠标停在控件正中时，
##   面板的左上角就在鼠标附近，于是整块说明盖住指针。现在的口径：
##     · 正常悬停：`x = 鼠标.x + 24`、`y = 鼠标.y - 8`（**始终在鼠标右侧**）；
##     · 太靠右（`鼠标.x + 24 + 面板宽 > 1280 - 8`）→ 翻到左边 `x = max(8, 鼠标.x - 面板宽 - 20)`；
##     · 纵向 `y` 夹在 `[8, 720 - 面板高 - 8]`；
##     · **只有** headless 测试那种「调 `show_for_control(控件)` 而鼠标恒为 `(0,0)`」的情况，
##       才用 `控件.get_global_rect().end.x + 16`（控件右侧）定位 —— 测试要的是「不出画布」。
##   `基准点` 不给（默认 `(-1, -1)`）就现取鼠标坐标；测试可以显式传一个坐标来钉位置。
func _夹紧(基准点: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if _面板 == null or not _面板.visible:
		return
	var 框 := _视口()
	var 需 := _面板.get_combined_minimum_size()
	var 宽 := minf(maxf(需.x, 160.0), 面板最大宽)
	# ★ 高度也要有上限：说明可能很长（一把武器一行就上百字），
	#   不封顶的话面板会竖着铺满整个屏幕。封在 560（同时不越过视口高 - 上下边距）。
	var 高 := minf(需.y, minf(面板最大高, maxf(40.0, 框.y - 边距 * 2.0)))
	_面板.size = Vector2(宽, 高)
	var mp := 基准点
	if mp.x < 0.0 or mp.y < 0.0:
		mp = _鼠标位置()
	# ---- headless 测试那条特例：鼠标恒为 (0,0) + 有锚控件 → 用控件右侧 ----
	if mp == Vector2.ZERO and _锚 != null and is_instance_valid(_锚):
		var 全 := _锚.get_global_rect()
		_面板.position = Vector2(
			clampf(全.end.x + 16.0, 边距, maxf(边距, 框.x - 宽 - 边距)),
			clampf(全.position.y, 边距, maxf(边距, 框.y - 高 - 边距)))
		return
	# ---- 正常悬停：始终在鼠标右侧；右边放不下才翻到左侧 ----
	var x := mp.x + 24.0
	if x + 宽 > 框.x - 边距:
		x = maxf(边距, mp.x - 宽 - 20.0)
	var y := mp.y - 8.0
	x = clampf(x, 边距, maxf(边距, 框.x - 宽 - 边距))
	y = clampf(y, 边距, maxf(边距, 框.y - 高 - 边距))
	_面板.position = Vector2(x, y)
