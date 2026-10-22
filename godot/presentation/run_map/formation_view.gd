## 8 格编队（前排 4 + 后排 4，正交 4×2 · Stage M4-2）。
##
## ★ 站位几何**不自己造**：全部读 `core/battle/fm.gd` 的
##   `Fm.ROWS()` / `Fm.行列数(行)` / `Fm.行名(行)` / `Fm.行首格(行)` / `Fm.位名(位号)`，
##   以及门面的 `GameSession.lineup_slots()`（它就是照 `Fm.位名()` 现场生成的）。
##   数据侧现在是 **8 格 = 前排 4 + 后排 4**（`SLOTS = 8`），所以这里画 2 行 × 4 列；
##   后排整体右移半格做**错位**（几何本身仍以 `Fm` 为准）。
##
## 动作只调门面：`set_lineup_slot(键, 位名)` / `remove_from_lineup(键)`。
## 出击上限与已上阵数读 `RosterManager.deploy_limit(state)` 与 `run_state.lineup.size()`。
class_name FormationView
extends Control

## ==========================================================================================
## ★ UX-1 第 3 项（2026-10-19，作者试玩反馈第 3 条）：**编队屏支持直接拖拽（Drag & Drop）**
##
##   拖拽数据格式（唯一的契约）：
##     `{"type": "formation_unit", "unit_key": 机体键, "from_slot": 位名或空串}`
##   三条路：
##     · 名册 → 阵型槽：`set_lineup_slot(键, 目标位名)`（槽上有人就替换 / 互换，见门面）；
##     · 阵型槽 A → 阵型槽 B：`set_lineup_slot(键, B)`（B 空 = 移位；B 有人 = 两台直接互换）；
##     · 阵型槽 → 名册区：`set_lineup_slot(键, 空串)` 走门面的 `remove_from_lineup(键)` 下阵。
##   **点击兜底一个字都没删**（点机体选中 → 点格位上阵 / 换位），所以无拖拽环境与旧自动化测试照旧。
## ==========================================================================================

## 拖拽数据的类型标记（ASCII 键名，Godot 只认合法标识符，中文键在 `set_meta` 那边会炸）。
const 拖拽类型 := "formation_unit"

## 一张「编队卡片」（名册条目 / 阵型槽都用它）：可拖、可放、悬停时金边高亮。
## ★ 继承 `Button` 是为了**点击兜底照旧成立**（正文、`pressed` 信号、`is Button` 断言全部不变）。
class 编队卡 extends Button:
	## 所属视图（`FormationView`）。用 Variant 声明，避免内部类对 `class_name` 的循环推断。
	var 视图 = null
	## 这一张卡代表的机体键（空 = 空槽位 / 空名册）。
	var 键: String = ""
	## 阵型槽 = 位名（前1 / 后2…）；名册条目 = 空串（**名册行只接「从阵型槽拖回来」**）。
	var 位名: String = ""
	## 拖拽时给这张卡描的金边（放下 / 取消拖拽之后撤掉）。
	var _亮着 := false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if 视图 == null or 键.is_empty():
			return null
		return 视图._拿起卡片(键, 位名, self)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if 视图 == null:
			return false
		var 行 := bool(视图._能放到卡片上(位名, data))
		_亮(行)
		return 行

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		_亮(false)
		if 视图 == null:
			return
		视图._放到卡片上(位名, data)

	# ★ 拖拽开始 / 悬停时给这张卡描的**金色边框**（拖拽数据本体由 `_get_drag_data` 造）。
	func _notification(what: int) -> void:
		# 拖拽结束（不管放没放下）→ 把金边撤掉，别留一块亮着的格子。
		if what == NOTIFICATION_DRAG_END:
			_亮(false)

	func _gui_input(事件: InputEvent) -> void:
		# ★ 右键阵型槽 = 把这一格上的机体下阵（UX-1 第 3 项里「或右键点击阵型槽」那一条）。
		if 键.is_empty() or 位名.is_empty() or not (事件 is InputEventMouseButton):
			return
		var 鼠 := 事件 as InputEventMouseButton
		if 鼠.pressed and 鼠.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if 视图 != null:
				视图._卸下槽位(位名)

	func _亮(开: bool) -> void:
		if 开 == _亮着:
			return
		_亮着 = 开
		if 开:
			var 框 := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 2)
			add_theme_stylebox_override("normal", 框)
			add_theme_stylebox_override("hover", 框)
		else:
			remove_theme_stylebox_override("normal")
			remove_theme_stylebox_override("hover")

## 名册滚动区（拖拽落点）：把阵型槽上的机体拖回这里 = 下阵。
## ★ 名册每一行本身也是 `编队卡`（`位名 == ""`），所以点在行上放也能接住。
class 编队名册区 extends ScrollContainer:
	var 视图 = null

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return 视图 != null and bool(视图._能放回名册(data))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if 视图 != null:
			视图._放回名册(data)

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _上限标签: Label
var _说明: Label
var _格位区: VBoxContainer
var _名册列表: VBoxContainer
var _结果: Label
## ★ 战前编队确认态的标题（平时藏起来）。
var _战前标题: Label
## ★ 【确认编队 · 开始战斗】按钮（`session.pending_battle_confirm == true` 时显示）。
var _开始战斗按钮: Button
## ★ 【确认并返回大地图】按钮（平时从顶栏「编队」进来调整阵容时显示）。
var _回地图按钮: Button
## 现在选中的名册机体（空 = 没选）。
var _选中: String = ""

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _格位区 == null:
		return
	var s: RunState = null
	if session != null:
		s = session.run_state
	# ★ UX-4（作者反馈第 1 条）：进编队屏**先规范槽位** —— 旧档 / 外部写入的 `slot == ""`、
	#   位名写法、纯字符串条目在这里补成明确位号（默认位 → 第一个空位），玩家自己摆好的格位不动。
	#   这样「编队屏看到的站位」与「`NodeResolver.我方编成()` 进战斗用的站位」是同一个口径。
	if session != null and s != null:
		session.normalize_lineup_slots()
		s = session.run_state
	_刷新战前态()
	if s == null:
		_上限标签.text = "还没有进行中的局"
		_说明.text = "先回主菜单开一局、招募几台机师，再来摆出击位。"
		_清空(_格位区)
		_清空(_名册列表)
		return
	if not s.roster.has(_选中):
		_选中 = ""
	var 上限 := RosterManager.deploy_limit(s)
	_上限标签.text = "出击上限 %s 台 · 已上阵 %s 台 · 名册 %s 台（部队 Lv%s）" % [
		UiTheme.文本(上限), UiTheme.文本(s.lineup.size()), UiTheme.文本(s.roster.size()), UiTheme.文本(s.level)]
	if _选中.is_empty():
		_说明.text = "玩法：点右边的一台机师选中它，再点左边的一个格位 → 上阵（格位被占了就把原来那台换回你原来的位）。\n"
	else:
		_说明.text = "已选中【%s】：点左边的格位上阵 / 换位；再点它自己那一格 = 取消选中。\n" % _名(_选中)
	_说明.text += "★ 可拖拽机体卡片上阵、互换格位或拖回名册下阵（也可点击选择后点击格位）。\n"
	_说明.text += "上阵满 %s 台就摆不进新的了（先撤一台）。前排会挡住后排的直射 —— 前排通常放抗打的。" % UiTheme.文本(上限)
	_建格位(s)
	_建名册(s)
	_结果.text = _结果文字()

## ★ 战前编队确认态（2026-10-18 作者试玩反馈第 1 条）：
##   `pending_battle_confirm == true` → 顶部标题醒目提示、亮【确认编队 · 开始战斗】、**藏掉【回地图】**；
##   平时（从大地图点顶栏「编队」进来调整阵容）→ 反过来。
func _刷新战前态() -> void:
	var 确认 := session != null and session.pending_battle_confirm
	if _战前标题 != null:
		_战前标题.visible = 确认
		if 确认:
			_战前标题.text = "【战前编队确认】即将开始战斗，请确认出击阵容后点击下方【确认编队 · 开始战斗】"
			_战前标题.add_theme_color_override("font_color", UiTheme.高亮)
	if _开始战斗按钮 != null:
		_开始战斗按钮.visible = 确认
		# 文案与颜色是**常量**（只在确认态露面的那一颗），反复 refresh 也不会来回改。
		_开始战斗按钮.text = "确认编队 · 开始战斗"
		_开始战斗按钮.add_theme_color_override("font_color", UiTheme.正面)
	if _回地图按钮 != null:
		# ★ 确认态下**必须**藏掉：不许退回大地图逃避当前格的战斗。
		_回地图按钮.visible = not 确认

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "编队"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "编队上下列", true, UiTheme.间距_小)
	UiTheme.占满留边(列)
	_战前标题 = UiTheme.建标签(列, "", UiTheme.字号_小节, UiTheme.高亮)
	_战前标题.name = "战前编队标题"
	_战前标题.visible = false
	_上限标签 = UiTheme.建标签(列, "", UiTheme.字号_小节, UiTheme.高亮)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	var 主体 := UiTheme.建盒(列, "编队主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var 左列 := UiTheme.建盒(主体, "编队左列", true, UiTheme.间距_小)
	左列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	左列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(左列, "出击阵型（前排在后排前面，后排整体右移半格）", UiTheme.字号_小节, UiTheme.高亮)
	_格位区 = UiTheme.建盒(左列, "格位网格", true, UiTheme.间距_小)
	_格位区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_格位区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 按钮组 := UiTheme.建盒(左列, "编队按钮组", false, UiTheme.间距_小)
	var 撤 := UiTheme.建按钮(按钮组, "撤下选中的机师", _点撤下)
	撤.name = "撤下按钮"
	撤.tooltip_text = "把选中的这台从出击位拿下来（不删名册）"
	var 清 := UiTheme.建按钮(按钮组, "清空选中", _点清空选中)
	清.tooltip_text = "回到「先选人再点位」的状态"
	# ★ 【确认编队 · 开始战斗】（只在战前确认态显示）：点它 = 门面 `confirm_formation_and_start_battle()`。
	_开始战斗按钮 = UiTheme.建按钮(按钮组, "确认编队 · 开始战斗", _点开始战斗)
	_开始战斗按钮.name = "开始战斗按钮"
	_开始战斗按钮.tooltip_text = "确认出击阵容，进这一格的战斗（追击战就走追击战那条）"
	_开始战斗按钮.visible = false
	var 回 := UiTheme.建按钮(按钮组, "确认并返回大地图", _点回地图)
	回.name = "回地图按钮"
	回.tooltip_text = "编好了就回大地图继续走"
	_回地图按钮 = 回

	var 右列 := UiTheme.建盒(主体, "编队右列", true, UiTheme.间距_小)
	右列.custom_minimum_size = Vector2(340, 0)
	右列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(右列, "名册（点一台选中 / 直接拖到左边格位）", UiTheme.字号_小节, UiTheme.高亮)
	# ★ UX-1 第 3 项：名册区容器本身就是**拖拽落点**（把阵型槽上的机体拖回这里 = 下阵）。
	var 名册滚 := 编队名册区.new()
	名册滚.name = "名册列表"
	名册滚.视图 = self
	名册滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	名册滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	名册滚.custom_minimum_size = Vector2(0, 320)
	名册滚.clip_contents = true
	右列.add_child(名册滚)
	_名册列表 = UiTheme.建盒(名册滚, "名册列表内容", true, UiTheme.间距_小)
	_名册列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_结果 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)

# ==========================================================================================
# 格位（几何照 Fm）
# ==========================================================================================

func _建格位(s: RunState) -> void:
	_清空(_格位区)
	var 占位: Dictionary = {}
	for 条 in session.lineup_slots():
		if 条 is Dictionary:
			占位[str(条.get("位名", ""))] = str(条.get("键", ""))
	var 行数 := Fm.ROWS()
	for 行 in 行数:
		var 行盒 := UiTheme.建盒(_格位区, "第%d排" % 行, false, UiTheme.间距_小)
		if int(行) > 0:
			# 后排右移半格 → 错位
			var 错位 := Control.new()
			错位.name = "错位%d" % 行
			错位.custom_minimum_size = Vector2(UiTheme.格边长 * 0.5, 0)
			错位.mouse_filter = Control.MOUSE_FILTER_IGNORE
			行盒.add_child(错位)
		UiTheme.建标签(行盒, Fm.行名(float(行)), UiTheme.字号_小, UiTheme.次要文字)
		var 列数 := int(Fm.行列数(float(行)))
		for 列 in 列数:
			var 位号 := Fm.slotOf(float(行), float(列))
			var 位名 := Fm.位名(位号)
			var 键 := str(占位.get(位名, ""))
			_行盒加格(行盒, 位名, 键, s)

func _行盒加格(行盒: BoxContainer, 位名: String, 键: String, s: RunState) -> void:
	var 文 := "%s\n%s" % [位名, "（空）" if 键.is_empty() else _名(键)]
	var b := 编队卡.new()
	b.视图 = self
	b.键 = 键
	b.位名 = 位名
	b.text = 文
	b.add_theme_font_size_override("font_size", UiTheme.字号_正文)
	b.pressed.connect(_点位.bind(位名))
	b.custom_minimum_size = Vector2(UiTheme.格边长 * 1.5, UiTheme.格边长)
	b.add_theme_font_size_override("font_size", UiTheme.字号_小)
	# ★ UX-1 第 3 项：槽位是**拖拽落点**（空格 / 有人都能放），有人时它自己也能被拖走。
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	行盒.add_child(b)
	var 段: Array = ["位名 %s" % 位名]
	if 键.is_empty():
		段.append("空着")
		段.append("点它 → 把你选中的机师摆上来")
		段.append("或者直接把名册里的机体卡片拖到这一格")
	else:
		段.append("%s Lv%s" % [_名(键), UiTheme.文本(s.get_unit_level(键))])
		段.append("点它 → 用选中的机师把它换下来（或者选中它自己）")
		段.append("拖它到别的格位 = 换位；拖回名册 = 下阵；右键 = 下阵")
		段.append("HP %s%%" % UiTheme.文本(int(JsCompat.js_round(s.get_unit_hp_ratio(键) * 100.0))))
	b.tooltip_text = "\n".join(段)
	if 键 == _选中:
		b.add_theme_color_override("font_color", UiTheme.高亮)
	# ★ Mouse Over：格位上**有单位**时把整台机体的说明挂上去（空位不挂，免得弹一段空的）。
	if not 键.is_empty() and session != null:
		HoverTooltip.bind(b, session.template_unit_hover_text(键, s.get_unit_level(键)), "机体")

# ==========================================================================================
# 名册
# ==========================================================================================

func _建名册(s: RunState) -> void:
	_清空(_名册列表)
	if s.roster.is_empty():
		UiTheme.建标签(_名册列表, "名册是空的 —— 先去「名册 / 招募 / 晋升」用券招人。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for 键 in s.roster.keys():
		var k := str(键)
		var 标签 := RosterManager.标签(k)
		var 位名 := "没上阵"
		for 条 in session.lineup_slots():
			if 条 is Dictionary and str(条.get("键", "")) == k:
				位名 = str(条.get("位名", ""))
		var 标记 := "◆ " if k == _选中 else ""
		# ★ UX-1 第 3 项：名册条目也是 `编队卡`（可拖、且是「拖回名册 = 下阵」的落点）。
		var b := 编队卡.new()
		b.视图 = self
		b.键 = k
		b.位名 = ""
		b.text = "%s%s Lv%s · %s · %s · %s" % [标记, _名(k),
			UiTheme.文本(s.get_unit_level(k)), str(标签.get("战斗分类", "")), str(标签.get("势力", "")), 位名]
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.pressed.connect(_点人.bind(k))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_名册列表.add_child(b)
		b.tooltip_text = "HP %s%% · 点一下选中它，再去左边点位；也可以直接把它拖到左边的格位上阵" % \
			UiTheme.文本(int(JsCompat.js_round(s.get_unit_hp_ratio(k) * 100.0)))
		# ★ Mouse Over：这台名册机体的整段说明
		HoverTooltip.bind(b, session.template_unit_hover_text(k, s.get_unit_level(k)), "机体")

# ==========================================================================================
# 动作（只调门面）
# ==========================================================================================

func _点人(键: String) -> void:
	_选中 = 键
	refresh()

## 点一个格位（★ 2026-10-18 作者试玩反馈第 1 条：**支持直接点格换位**）。
##
## 三条路（`_选中` 已经选中某台机体时）：
##   ① 点的是**自己占着的那一格** → 取消选中（`_选中 = ""`），**不报错、不调门面**；
##   ② 点的是**空格位 B** → `session.set_lineup_slot(_选中, B)`（门面 `_摆上阵()` 会先把这台
##      从原格位 A 移除再放到 B，不会出现「同一位号两条记录」）；
##   ③ 点的是**另一台机体 U2 占着的格位 B** → 同样调 `set_lineup_slot(_选中, B)`，
##      门面 `_摆上阵()` 内部把 U2 挪回 `_选中` 原来的格位 A —— 也就是**两台互换**。
func _点位(位名: String) -> void:
	if session == null:
		return
	var s := session.run_state
	if s == null:
		return
	if _选中.is_empty():
		# 没选人 → 点空位提示，点有人位就选中那台（顺手）
		for 条 in session.lineup_slots():
			if 条 is Dictionary and str(条.get("位名", "")) == 位名:
				var k := str(条.get("键", ""))
				if not k.is_empty():
					_选中 = k
		refresh()
		return
	if not s.roster.has(_选中):
		_选中 = ""
		refresh()
		return
	# ① 再点自己那一格 → 取消选中（**不报错**：从前这一下会走 `set_lineup_slot(自己, 原位)`
	#    并可能在门面留下一条没用的错误串）。
	if _位名上的键(位名) == _选中:
		_选中 = ""
		refresh()
		return
	# ② / ③ 空格位或别人占着的格位：都交给门面 —— 它就是「换位 / 互换」的唯一实现。
	session.set_lineup_slot(_选中, 位名)
	refresh()

## 这个格位上现在是谁（空位 → 空串）。纯读 `lineup_slots()`。
func _位名上的键(位名: String) -> String:
	if session == null:
		return ""
	for 条 in session.lineup_slots():
		if 条 is Dictionary and str(条.get("位名", "")) == 位名:
			return str(条.get("键", ""))
	return ""

## 【确认编队 · 开始战斗】→ 门面 `confirm_formation_and_start_battle()`。
## 屏幕上那一下由 `session.changed` → `boot.route()` 自己接手（它会把屏切到 `"battle"`）。
func _点开始战斗() -> void:
	if session == null:
		return
	session.confirm_formation_and_start_battle()

func _点撤下() -> void:
	if session == null or _选中.is_empty():
		return
	session.remove_from_lineup(_选中)
	refresh()

func _点清空选中() -> void:
	_选中 = ""
	refresh()

func _点回地图() -> void:
	# ★ 战前编队确认态下**不许**退回大地图逃避当前格的战斗（按钮本身也是藏起来的，
	#   这里再兜一道：程序直接调 / 键盘走到也不放行）。
	if session != null and session.pending_battle_confirm:
		return
	请求屏幕.emit("map")

# ==========================================================================================
# ★ UX-1 第 3 项：拖拽（Drag & Drop）—— 数据格式与三条路
#
#   数据：`{"type": "formation_unit", "unit_key": 键, "from_slot": 位名或空串}`
#   落点：阵型槽（`位名 != ""`）接所有人；名册区 / 名册行（`位名 == ""`）只接「从阵型槽拖回来」。
#   动作：**一律只调门面** —— 上阵 / 换位 / 互换 = `set_lineup_slot(键, 位名)`；
#         下阵 = `remove_from_lineup(键)`（与 `set_lineup_slot(键, "")` 同一个效果，门面没有空格位这个位名）。
#   ★ 这几个方法是 `编队卡 / 编队名册区` 的**公开编程入口**：自动化测试直接调它们
#     （`_get_drag_data` / `_can_drop_data` / `_drop_data`），不必伪造鼠标。
# ==========================================================================================

## 造拖拽数据 + 挂半透明预览名片。`位名` 为空的名册行 → `from_slot` 现查（它可能正占着某个格位）。
func _拿起卡片(键: String, 位名: String, 源: Control) -> Variant:
	if 键.is_empty():
		return null
	var 从 := 位名 if not 位名.is_empty() else _该键的位名(键)
	var 数据 := {"type": 拖拽类型, "unit_key": 键, "from_slot": 从}
	# ★ 半透明机体名片（`set_drag_preview`）：**只在真的有一次拖拽在跑时**才挂 ——
	#   ① headless / 无窗口下拿不到视口；② 自动化测试是直接调 `_get_drag_data()` 的，
	#   那时 `gui_is_dragging()` 为假，硬调 `set_drag_preview()` 会报错。
	#   于是「拖拽数据」与「预览名片」拆成两件事：没有名片，数据照样完整可用。
	if 源 != null and is_instance_valid(源) and 源.is_inside_tree():
		var vp := 源.get_viewport()
		if vp != null and vp.gui_is_dragging():
			var 卡 := PanelContainer.new()
			var 样 := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 2)
			样.content_margin_left = 6
			样.content_margin_right = 6
			样.content_margin_top = 4
			样.content_margin_bottom = 4
			卡.add_theme_stylebox_override("panel", 样)
			卡.modulate = Color(1, 1, 1, 0.62)
			var l := UiTheme.建标签(卡, "【%s】" % _名(键), UiTheme.字号_小, UiTheme.高亮)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			源.set_drag_preview(卡)
	return 数据

## 这一张卡（`位名` = 空串时是名册行）能不能接住这份拖拽数据。
func _能放到卡片上(位名: String, 数据: Variant) -> bool:
	if not (数据 is Dictionary):
		return false
	var d: Dictionary = 数据
	if str(d.get("type", "")) != 拖拽类型:
		return false
	var 键 := str(d.get("unit_key", ""))
	var 从 := str(d.get("from_slot", ""))
	if 键.is_empty():
		return false
	if session == null or session.run_state == null:
		return false
	if not session.run_state.roster.has(键):
		return false
	if 位名.is_empty():
		# 名册行 / 名册区：只接「从阵型槽拖回来」（拖自己原来那格等于原地不动，不接）。
		return not 从.is_empty()
	# 阵型槽：空格、有人、拖的是同一台 —— 全都接（门面对「原地不动」是幂等的）。
	return true

## 真的放下：阵型槽 → 上阵 / 换位 / 互换；名册区 → 下阵。
func _放到卡片上(位名: String, 数据: Variant) -> void:
	if not _能放到卡片上(位名, 数据):
		return
	var d: Dictionary = 数据
	var 键 := str(d.get("unit_key", ""))
	if 位名.is_empty():
		_下阵(键)
		return
	_选中 = 键
	session.set_lineup_slot(键, 位名)
	refresh()

## 名册区接不接这份数据（= 是不是「从某个阵型槽拖回来」）。
func _能放回名册(数据: Variant) -> bool:
	if not (数据 is Dictionary):
		return false
	var d: Dictionary = 数据
	if str(d.get("type", "")) != 拖拽类型:
		return false
	return not str(d.get("from_slot", "")).is_empty() and not str(d.get("unit_key", "")).is_empty()

## 放回名册 = 下阵（`remove_from_lineup` 是门面公开口子）。
func _放回名册(数据: Variant) -> void:
	if not _能放回名册(数据):
		return
	_下阵(str((数据 as Dictionary).get("unit_key", "")))

## 按位名卸下那一格上的机体（右键阵型槽走这一条）。
func _卸下槽位(位名: String) -> void:
	var 键 := _位名上的键(位名)
	if 键.is_empty():
		return
	_下阵(键)

## 下阵统一走这里（`_选中` 一起清掉，免得「选中的那台已经不在阵上」）。
func _下阵(键: String) -> void:
	if session == null or 键.is_empty():
		return
	session.remove_from_lineup(键)
	if _选中 == 键:
		_选中 = ""
	refresh()

## 这一台现在占着哪个位名（不在阵上 → 空串）。
func _该键的位名(键: String) -> String:
	if session == null or 键.is_empty():
		return ""
	for 条 in session.lineup_slots():
		if 条 is Dictionary and str(条.get("键", "")) == 键:
			return str(条.get("位名", ""))
	return ""

# ==========================================================================================
# 小工具
# ==========================================================================================

## 机体键 → 显示名（读纯目录；读不到就显示键本身）。
func _名(键: String) -> String:
	if 键.is_empty():
		return ""
	var 模板 := RosterManager.模板(键)
	return str(模板.get("名", 键))

func _结果文字() -> String:
	if session == null:
		return ""
	var 末 := session.last
	match str(末.get("行动", "")):
		"编队":
			var 出: int = 0
			if session.run_state != null:
				出 = session.run_state.lineup.size()
			return "摆好了：%s → %s（出战 %s 台 / 上限 %s 台）" % [str(末.get("键", "")), str(末.get("位名", "")),
				UiTheme.文本(出), UiTheme.文本(末.get("上限", 0))]
		"撤下":
			return "撤下来了：%s（出战 %s → %s 台）" % [str(末.get("键", "")), UiTheme.文本(末.get("出击前", 0)),
				UiTheme.文本(末.get("出击后", 0))]
	if not session.当前动作错误().is_empty():
		return "上一次没摆成：%s" % UiTheme.文本(session.当前动作错误())
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
