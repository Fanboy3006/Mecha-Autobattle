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

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _上限标签: Label
var _说明: Label
var _格位区: VBoxContainer
var _名册列表: VBoxContainer
var _结果: Label
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
		_说明.text = "已选中【%s】：点左边的格位上阵 / 换位。\n" % _名(_选中)
	_说明.text += "上阵满 %s 台就摆不进新的了（先撤一台）。前排会挡住后排的直射 —— 前排通常放抗打的。" % UiTheme.文本(上限)
	_建格位(s)
	_建名册(s)
	_结果.text = _结果文字()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "编队"
	UiTheme.占满(self)
	var 列 := UiTheme.建盒(self, "编队上下列", true, UiTheme.间距_小)
	_上限标签 = UiTheme.建标签(列, "", UiTheme.字号_小节, UiTheme.高亮)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	var 主体 := UiTheme.建盒(列, "编队主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var 左列 := UiTheme.建盒(主体, "编队左列", true, UiTheme.间距_小)
	左列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(左列, "出击阵型（前排在后排前面，后排整体右移半格）", UiTheme.字号_小节, UiTheme.高亮)
	_格位区 = UiTheme.建盒(左列, "格位网格", true, UiTheme.间距_小)
	_格位区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 按钮组 := UiTheme.建盒(左列, "编队按钮组", false, UiTheme.间距_小)
	var 撤 := UiTheme.建按钮(按钮组, "撤下选中的机师", _点撤下)
	撤.name = "撤下按钮"
	撤.tooltip_text = "把选中的这台从出击位拿下来（不删名册）"
	var 清 := UiTheme.建按钮(按钮组, "清空选中", _点清空选中)
	清.tooltip_text = "回到「先选人再点位」的状态"
	var 回 := UiTheme.建按钮(按钮组, "回大地图", _点回地图)
	回.name = "回地图按钮"
	回.tooltip_text = "编好了就回大地图继续走"

	var 右列 := UiTheme.建盒(主体, "编队右列", true, UiTheme.间距_小)
	右列.custom_minimum_size = Vector2(340, 0)
	UiTheme.建标签(右列, "名册（点一台选中）", UiTheme.字号_小节, UiTheme.高亮)
	_名册列表 = UiTheme.建滚动(右列, "名册列表", 320.0)
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
	var b := UiTheme.建按钮(行盒, 文, _点位.bind(位名))
	b.custom_minimum_size = Vector2(UiTheme.格边长 * 1.5, UiTheme.格边长)
	b.add_theme_font_size_override("font_size", UiTheme.字号_小)
	var 段: Array = ["位名 %s" % 位名]
	if 键.is_empty():
		段.append("空着")
		段.append("点它 → 把你选中的机师摆上来")
	else:
		段.append("%s Lv%s" % [_名(键), UiTheme.文本(s.get_unit_level(键))])
		段.append("点它 → 用选中的机师把它换下来（或者选中它自己）")
		段.append("HP %s%%" % UiTheme.文本(int(JsCompat.js_round(s.get_unit_hp_ratio(键) * 100.0))))
	b.tooltip_text = "\n".join(段)
	if 键 == _选中:
		b.add_theme_color_override("font_color", UiTheme.高亮)

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
		var b := UiTheme.建按钮(_名册列表, "%s%s Lv%s · %s · %s · %s" % [标记, _名(k),
			UiTheme.文本(s.get_unit_level(k)), str(标签.get("战斗分类", "")), str(标签.get("势力", "")), 位名],
			_点人.bind(k))
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.tooltip_text = "HP %s%% · 点一下选中它，再去左边点位" % UiTheme.文本(int(JsCompat.js_round(s.get_unit_hp_ratio(k) * 100.0)))

# ==========================================================================================
# 动作（只调门面）
# ==========================================================================================

func _点人(键: String) -> void:
	_选中 = 键
	refresh()

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
	session.set_lineup_slot(_选中, 位名)
	refresh()

func _点撤下() -> void:
	if session == null or _选中.is_empty():
		return
	session.remove_from_lineup(_选中)
	refresh()

func _点清空选中() -> void:
	_选中 = ""
	refresh()

func _点回地图() -> void:
	请求屏幕.emit("map")

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
	if not session.errors.is_empty():
		return "上一次没摆成：%s" % UiTheme.文本(session.errors[session.errors.size() - 1])
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
