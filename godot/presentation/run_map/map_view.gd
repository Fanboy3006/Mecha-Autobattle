## 正方形大地图（Stage M4-2，本单最难的一块）。
##
## 全部按 `MapGenerator.shape(层)` 的 `列数 × 行数` 画格：**格子缺失处留空**（不是实心方块）。
## 每个格的展示信息只来自**纯读**接口：
##   `RunState.grid()` / `cell_at` / `is_visited` / `is_revealed`、`MapNavigator.is_known` /
##   `reachable_cells` / `tunnel_other_end` / `retreat_cost_preview`、`MapGenerator.must_pass`。
##
## 三层反馈的「预告」落在本屏：
##   移上去 / 选中一格 → 推进剂消耗（`GameSession.preview_cell_move`）+ 退路成本预告
##   （`MapNavigator.retreat_cost_preview`）；
##   点击移动 → `GameSession.move_to_cell(cell_id)`，拿返回的 `Dictionary` 决定反馈，
##   失败时把 `why` 原文显示出来（表现层不自己编原因）。
##
## 换层 / 进节点只调门面：`try_advance_floor()` / `enter_current_node()`。
## ★ 废弃隧道：门面**没有** `use_tunnel` 命令，所以本屏不给独立的「穿隧道」按钮 ——
##   站在隧道格上时，另一头本来就在 `can_move_to` 的合法目标里（`move_to_cell` 会走内核的
##   隧道分支、扣 1 点推进剂），点击那一格就是穿隧道。预告面板会写明「隧道：是」。
class_name MapView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

## 需要开弹窗才能做完的节点类型（其余的直接 `enter_current_node()`）。
const 弹窗节点 := {"黑市": "黑市", "休整": "休整", "事件": "奇遇"}

var session: GameSession = null

var _层信息: Label
var _地图网格: GridContainer
var _图例: Label
var _节点说明: Label
var _预告面板: VBoxContainer
var _按钮组: HBoxContainer
var _取消瞄准: Button
var _结果行: Label
var _名册提示: Label

## 现在预告哪一格（−1 = 当前所在格）。
var _预告格: int = -1
## 正在瞄准的主动零件：`{"下标": int, "键": String, "目标": Dictionary}`；空 = 没在瞄准。
var _瞄准: Dictionary = {}
## 已经自动结算过的格号（−1 = 还没有）。`_进入脚下(false)` 对同一格不再重复结算 ——
## 防止玩家站在「瞭望站 / 遗迹 / 隧道」这类格上反复点兜底按钮刷资源（JS 里根本没有第二个入口）。
var _已结算: int = -1
## 上一次画的是第几层（换层时把 `_已结算` 归零）。
var _层: int = -1

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _地图网格 == null:
		return
	_清空(_地图网格)
	_清空(_预告面板)
	var s: RunState = session.run_state if session != null else null
	if s == null or s.map_data.is_empty():
		_层信息.text = "还没有大地图 —— 先开一局肉鸽。"
		_节点说明.text = ""
		_图例.text = ""
		_结果行.text = ""
		_名册提示.visible = false
		return
	if s.floor_num != _层:
		_层 = s.floor_num
		_已结算 = -1
	var 形状 := MapGenerator.shape(s.floor_num)
	var 列数 := int(形状.get("列数", 5))
	var 行数 := int(形状.get("行数", 5))
	var 可达 := _可达集合(s)
	var 必经 := _必经集合(s, 列数)
	_层信息.text = "第 %s 层 · %s×%s 正方形 · 推进剂 %s / %s · 当前格 %s（%s）· 出口 %s · 必经点 %s 个" % [
		UiTheme.文本(s.floor_num), UiTheme.文本(列数), UiTheme.文本(行数),
		UiTheme.文本(s.propellant), UiTheme.文本(s.propellant_max), UiTheme.文本(s.node_id),
		UiTheme.节点全名(s.current_type()), MapNavigator.current_exit_kind(s), UiTheme.文本(必经.size())]
	# ★ 名册空 = 出击 0 台 = 任何战斗格都进不去（`start_node_battle` 会拒绝「出击名单是空的」）。
	#   内核设计就是「开局先招募」（`RosterManager.new_run` 的注释），所以这里必须说清楚。
	_名册提示.visible = s.roster.is_empty()
	if _名册提示.visible:
		_名册提示.text = "名册是空的 —— 先去顶栏「名册 / 招募 / 晋升」用招募券招人，再编队，才能开战。"
	_图例.text = "图例：起=起点 战=作战 精=精英 休=休整 市=黑市 事=奇遇 望=瞭望站 遗=遗迹 蚀=侵蚀源 隧=废弃隧道 守=出口守军 尽=出口尽头 径=出口小径 空=林间空地；★=当前所在格 可=现在走得到 必=必经点 过=走过 知=已揭开"
	_建网格(s, 列数, 行数, 可达, 必经)
	_取消瞄准.visible = not _瞄准.is_empty()
	_刷新预告(s)
	_刷新节点说明(s)
	_结果行.text = _结果文字()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "大地图"
	UiTheme.占满(self)
	var 列 := UiTheme.建盒(self, "地图上下列", true, UiTheme.间距_小)
	_层信息 = UiTheme.建标签(列, "", UiTheme.字号_小节, UiTheme.高亮)
	_层信息.name = "层信息"
	_名册提示 = UiTheme.建说明(列, "", UiTheme.字号_正文, UiTheme.负面)
	_名册提示.name = "名册提示"
	_名册提示.visible = false
	var 主体 := UiTheme.建盒(列, "地图主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var 左列 := UiTheme.建盒(主体, "地图左列", true, UiTheme.间距_小)
	_地图网格 = GridContainer.new()
	_地图网格.name = "地图网格"
	_地图网格.columns = 5
	_地图网格.add_theme_constant_override("h_separation", UiTheme.间距_小)
	_地图网格.add_theme_constant_override("v_separation", UiTheme.间距_小)
	_地图网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_地图网格.size_flags_vertical = Control.SIZE_EXPAND_FILL
	左列.add_child(_地图网格)
	_图例 = UiTheme.建说明(左列, "", UiTheme.字号_小, UiTheme.弱文字)
	_图例.name = "图例"

	var 右列 := UiTheme.建盒(主体, "地图侧栏", true, UiTheme.间距_小)
	右列.custom_minimum_size = Vector2(330, 0)
	UiTheme.建标签(右列, "这一格", UiTheme.字号_小节, UiTheme.高亮)
	_节点说明 = UiTheme.建说明(右列, "", UiTheme.字号_小, UiTheme.主文字)
	_节点说明.name = "节点说明"
	UiTheme.建标签(右列, "预告（走过去会发生什么）", UiTheme.字号_小节, UiTheme.高亮)
	_预告面板 = UiTheme.建滚动(右列, "预告面板", 250.0)
	_按钮组 = UiTheme.建盒(右列, "地图按钮组", false, UiTheme.间距_小)
	var 进 := UiTheme.建按钮(_按钮组, "进入当前格", _点进入)
	进.name = "进入当前格按钮"
	进.tooltip_text = "兜底 / 重试用：正常玩法是**点格子**，走上去就自动结算（战斗格直接开战）。同一格不会重复结算。"
	var 换 := UiTheme.建按钮(_按钮组, "走出口 / 换层", _点换层)
	换.name = "换层按钮"
	换.tooltip_text = "站在出口尽头 / 出口小径上时才能换层（有牌没选完会被拦下）"
	_取消瞄准 = UiTheme.建按钮(_按钮组, "取消零件瞄准", _点取消瞄准)
	_取消瞄准.name = "取消瞄准按钮"
	_取消瞄准.tooltip_text = "不再用零件瞄准，回到普通移动"
	_取消瞄准.visible = false
	_结果行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)
	_结果行.name = "结果行"

# ==========================================================================================
# 网格
# ==========================================================================================

func _建网格(s: RunState, 列数: int, 行数: int, 可达: Dictionary, 必经: Dictionary) -> void:
	_地图网格.columns = 列数
	for 行 in 行数:
		for 列 in 列数:
			var id := MapGenerator.cell_id(列, 行, 列数)
			if not s.has_cell(id):
				# ★ 形状外 / 不存在的格：留空，绝不画成实心方块
				var 空 := Control.new()
				空.name = "空格_%d" % id
				空.custom_minimum_size = Vector2(UiTheme.格边长, UiTheme.格边长)
				空.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_地图网格.add_child(空)
				continue
			_地图网格.add_child(_造格按钮(s, id, 可达, 必经))

func _造格按钮(s: RunState, id: int, 可达: Dictionary, 必经: Dictionary) -> Button:
	var 格 := s.cell_at(id)
	var 类型 := str(格.get("类型", ""))
	var 色 := UiTheme.节点色(类型)
	var 旗: Array = []
	if id == s.node_id:
		旗.append("★")
	if 可达.has(id):
		旗.append("可")
	if 必经.has(id):
		旗.append("必")
	if s.is_visited(id):
		旗.append("过")
	elif MapNavigator.is_known(s, id):
		旗.append("知")
	var 文 := UiTheme.节点短名Of(类型)
	if not 旗.is_empty():
		文 += "\n" + "·".join(旗)
	var b := Button.new()
	b.name = "格%d" % id
	b.text = 文
	b.custom_minimum_size = Vector2(UiTheme.格边长, UiTheme.格边长)
	b.add_theme_font_size_override("font_size", UiTheme.字号_小)
	var 字色 := 色
	if s.is_visited(id) and id != s.node_id:
		字色 = UiTheme.已走过色
	elif not MapNavigator.is_known(s, id) and not 可达.has(id):
		字色 = UiTheme.禁用文字
	b.add_theme_color_override("font_color", 字色)
	# 边框：当前格金、可走格用可移动色、零件目标粉、其余按节点色
	var 边色 := 色
	var 边宽 := 1
	if 可达.has(id):
		边色 = UiTheme.可移动色
		边宽 = 2
	if 必经.has(id):
		边色 = UiTheme.必经点色
	if id == s.node_id:
		边色 = UiTheme.当前格色
		边宽 = 3
	if _瞄准.has("目标") and (_瞄准["目标"] as Dictionary).has(id):
		边色 = UiTheme.零件目标色
		边宽 = 3
	b.add_theme_stylebox_override("normal", UiTheme.底样式(UiTheme.卡片底, 边色, 边宽))
	b.tooltip_text = _格子提示(s, id, 可达, 必经)
	b.mouse_entered.connect(选中预告.bind(id))
	b.focus_entered.connect(选中预告.bind(id))
	b.pressed.connect(_点格.bind(id))
	return b

func _格子提示(s: RunState, id: int, 可达: Dictionary, 必经: Dictionary) -> String:
	var 格 := s.cell_at(id)
	var 段: Array = ["（%d, %d）%s" % [int(格.get("列", 0)) + 1, int(格.get("行", 0)) + 1, UiTheme.节点全名(str(格.get("类型", "")))]]
	if id == s.node_id:
		段.append("你现在在这里")
	if 必经.has(id):
		段.append("必经点（绕不过去）")
	if s.is_visited(id):
		段.append("已经走过")
	elif MapNavigator.is_known(s, id):
		段.append("已经揭开")
	if 可达.has(id):
		var 预 := session.preview_cell_move(id)
		段.append("可以走：花 %s 点推进剂" % UiTheme.文本(预.get("推进剂消耗", 0)))
	if _瞄准.has("目标") and (_瞄准["目标"] as Dictionary).has(id):
		段.append("【%s】能点这一格" % str(_瞄准.get("键", "")))
	return "\n".join(段)

# ==========================================================================================
# 预告面板（三层反馈的「预告」）
# ==========================================================================================

## 移上去 / 键盘选中 / 点过之后都可以调它 —— **纯读**，不改任何状态、不调命令。
func 选中预告(cell_id: int) -> void:
	_预告格 = cell_id
	if session == null:
		return
	var s: RunState = session.run_state
	if s == null or s.map_data.is_empty():
		return
	_清空(_预告面板)
	_刷新预告(s)

func _刷新预告(s: RunState) -> void:
	var id := _预告格 if _预告格 >= 0 else s.node_id
	var 格 := s.cell_at(id)
	if 格.is_empty():
		UiTheme.建标签(_预告面板, "这一格不存在。", UiTheme.字号_小, UiTheme.弱文字)
		return
	UiTheme.建标签(_预告面板, "（%d, %d）%s" % [int(格.get("列", 0)) + 1, int(格.get("行", 0)) + 1,
		UiTheme.节点全名(str(格.get("类型", "")))], UiTheme.字号_正文, UiTheme.高亮)
	var 预 := session.preview_cell_move(id)
	var 退 := MapNavigator.retreat_cost_preview(s, id)
	var 能去 := bool(预.get("ok", false))
	var 结论 := "能去：花 %s 点推进剂（现在 %s / %s）" % [UiTheme.文本(预.get("推进剂消耗", 0)),
		UiTheme.文本(s.propellant), UiTheme.文本(s.propellant_max)]
	if not 能去:
		结论 = "去不了：%s" % str(预.get("为什么", "（内核没给原因）"))
	UiTheme.建说明(_预告面板, 结论, UiTheme.字号_小, UiTheme.正面 if 能去 else UiTheme.负面)
	if bool(预.get("隧道", false)):
		UiTheme.建标签(_预告面板, "走的是废弃隧道（两端互通，扣 %s 点）" % UiTheme.文本(预.get("推进剂消耗", 0)),
			UiTheme.字号_小, UiTheme.主文字)
	var 退文 := "退路成本：%s 步" % UiTheme.文本(退.get("退路成本", -1))
	if bool(退.get("是干路", false)):
		退文 += "（就在干路上，撤回来不花步数）"
	elif int(退.get("退路成本", -1)) < 0:
		退文 += "（从这一格回不到干路 —— 进去就是单程）"
	UiTheme.建说明(_预告面板, 退文, UiTheme.字号_小, UiTheme.次要文字)
	var 细: Array = ["度数 %s" % UiTheme.文本(退.get("度数", 0))]
	if bool(退.get("是割点", false)):
		细.append("是割点（走进去以后这一片只有这一条路出来）")
	if id == s.node_id:
		细.append("你正在这一格上")
	UiTheme.建说明(_预告面板, "　".join(细), UiTheme.字号_小, UiTheme.弱文字)
	if _瞄准.has("目标"):
		var 目标: Dictionary = _瞄准["目标"]
		UiTheme.建说明(_预告面板, "零件【%s】%s" % [str(_瞄准.get("键", "")),
			"能点这一格（点下去就用掉一次）" if 目标.has(id) else "点不到这一格"], UiTheme.字号_小, UiTheme.零件目标色)

func _刷新节点说明(s: RunState) -> void:
	var 格 := s.cell_at(s.node_id)
	var 段: Array = ["（%d, %d）%s · 节点号 %s" % [int(格.get("列", 0)) + 1, int(格.get("行", 0)) + 1,
		UiTheme.节点全名(str(格.get("类型", ""))), UiTheme.文本(s.node_id)]]
	if s.has_cell(s.node_id):
		段.append("推进剂 %s / %s" % [UiTheme.文本(s.propellant), UiTheme.文本(s.propellant_max)])
		段.append("出口类型：%s" % MapNavigator.current_exit_kind(s))
	if session.current_node_result() is Dictionary and not session.current_node_result().is_empty():
		段.append("上一格结算：%s" % UiTheme.文本(session.current_node_result().get("节点", "")))
	_节点说明.text = "\n".join(段)

# ==========================================================================================
# 按钮
# ==========================================================================================

func _点进入() -> void:
	_进入脚下(false)

## 结算脚下这一格（= JS `80-界面-5-肉鸽接线与节点.js:207-277` 的 `去节点()` 后半段）。
##
## `自动` = true 表示这一次是「走上去」触发的（**默认路径**）；false = 玩家点了兜底按钮。
## 门面 `enter_current_node()` 会自己按类型派发：战斗格 → `battle` 屏；出口 → `try_advance_floor()`；
## 瞭望站 / 遗迹 / 隧道 / 招募站 / 空格 → 当场结算（`last` 里带日志，本屏照实摊开）。
## 黑市 / 休整 / 奇遇 这三类**门面不开弹窗**（它只把结果写进 `_node_result`），所以由本屏发信号开。
func _进入脚下(自动: bool) -> void:
	if session == null:
		return
	var s := session.run_state
	if s == null or s.map_data.is_empty():
		return
	var 格 := s.node_id
	# 兜底按钮：「同一格 + 这一格的事情**已经做过**」就不再重复结算。
	# `last["行动"] == "移动"` = 落脚之后门面还没记下任何节点动作（例如刚开过面板就关掉了）
	# → 这时允许再看一次面板，免得玩家关掉面板就再也进不去。
	# ★ 为什么需要这道闸：JS 里「点格子」是**唯一**入口（`data-act="去节点:k"`），
	#   根本没有第二个按钮，所以不存在「站在瞭望站/遗迹/休整上反复点、反复领」这条刷资源的路。
	if not 自动 and _已结算 == 格 and str(session.last.get("行动", "")) != "移动":
		_清空(_预告面板)
		UiTheme.建说明(_预告面板, "这一格已经结算过了（走上去的那一下就算完）。想再走一次别的格就点格子。",
			UiTheme.字号_小, UiTheme.高亮)
		return
	var 类型 := s.current_type()
	if 弹窗节点.has(类型):
		# 弹窗类节点：门面不开弹窗（它只把结果写进 `_node_result`），由本屏发信号开。
		# 同上，仍然记「已结算」，这样关掉面板之后兜底按钮不会让同一格再领一次。
		if 自动:
			_已结算 = 格
		请求弹窗.emit(str(弹窗节点[类型]), {})
		return
	var r := session.enter_current_node()
	if 自动 and r is Dictionary and bool((r as Dictionary).get("ok", true)):
		_已结算 = 格
	if not 自动:
		refresh()

func _点换层() -> void:
	if session == null:
		return
	session.try_advance_floor()

func _点取消瞄准() -> void:
	_瞄准 = {}
	refresh()

## 由 boot 接 `TopBar.零件瞄准` 调到这儿：只记状态 + 重画高亮，**不调任何内核函数**。
func 瞄准零件(下标: int, 零件键: String, 目标格: Array) -> void:
	var 集: Dictionary = {}
	for k in 目标格:
		集[int(k)] = true
	_瞄准 = {"下标": 下标, "键": 零件键, "目标": 集}
	refresh()

## 点一个格（界面上点格子 / 测试都走这一条路）。
##
## ★ 照 JS `去节点(k)` 的语义：**移动成功之后立刻结算脚下这一格**（不是等玩家再点一次按钮）。
##   JS 里「点格子」是原子动作，所以**根本无法路过一个战斗格而不打**；
##   旧版 M4-2 把「移动」与「进入当前格」拆成两个动作 → 玩家可以一路走到出口、一场都不打
##   （ARGON 2026-10-16 实测：0 场战斗直接通关）。这里修掉。
func _点格(id: int) -> void:
	if session == null:
		return
	_预告格 = id
	if _瞄准.has("目标") and (_瞄准["目标"] as Dictionary).has(id):
		var 下标 := int(_瞄准.get("下标", -1))
		_瞄准 = {}
		session.use_part(下标, id)
		return
	if _瞄准.has("目标"):
		_清空(_预告面板)
		UiTheme.建说明(_预告面板, "现在正在用零件瞄准：只能点粉色高亮的合法目标格（点「取消零件瞄准」回到普通移动）。",
			UiTheme.字号_小, UiTheme.零件目标色)
		return
	var 走 := session.move_to_cell(id)
	if not bool(走.get("ok", false)):
		refresh()
		return
	# ★ 林间空地 / 走过的格：只刷一次屏 —— 不弹任何框、不进任何屏（JS `:220-221` 逐字同口径）
	if bool(走.get("空格落脚", false)) or bool(走.get("已过", false)):
		refresh()
		return
	_进入脚下(true)

# ==========================================================================================
# 集合（全部纯读）
# ==========================================================================================

## 现在走得到的格（推进剂够 + 没走过；隧道另一头也算）。
func _可达集合(s: RunState) -> Dictionary:
	var 集: Dictionary = {}
	if s.propellant <= 0:
		return 集
	for k in MapNavigator.reachable_cells(s):
		集[int(k)] = true
	if s.current_type() == "隧道":
		var 那头 := MapNavigator.tunnel_other_end(s)
		if 那头 >= 0:
			集[那头] = true
	return 集

## 起点 → 出口尽头 的必经点（纯读 `MapGenerator.must_pass`）。
func _必经集合(s: RunState, 列数: int) -> Dictionary:
	var 集: Dictionary = {}
	var 起: Variant = s.map_data.get("起点")
	var 终: Variant = s.map_data.get("出口尽头", s.map_data.get("出口"))
	if 起 == null or 终 == null:
		return 集
	for k in MapGenerator.must_pass(s.grid(), int(起), int(终), 列数):
		集[int(k)] = true
	return 集

# ==========================================================================================
# 即时反馈（数值 / 文案全部来自门面，不自己算）
# ==========================================================================================

func _结果文字() -> String:
	if session == null:
		return ""
	var 末 := session.last
	match str(末.get("行动", "")):
		"移动":
			var 提 := str(末.get("提示", ""))
			return "走到第 %s 格：%s（花 %s 点推进剂，%s → %s）%s" % [UiTheme.文本(末.get("到", 0)),
				UiTheme.节点全名(str(末.get("类型", ""))), UiTheme.文本(末.get("距离", 0)),
				UiTheme.文本(末.get("推进剂前", 0)), UiTheme.文本(末.get("推进剂后", 0)),
				"\n" + 提 if not 提.is_empty() else ""]
		"用零件":
			return "用了零件【%s】，落到第 %s 格。" % [str(末.get("零件", "")), UiTheme.文本(末.get("到", 0))]
		"换层":
			return "换层：第 %s 层 → 第 %s 层（推进剂 %s → %s）%s" % [UiTheme.文本(末.get("从层", 0)),
				UiTheme.文本(末.get("到层", 0)), UiTheme.文本(末.get("推进剂前", 0)),
				UiTheme.文本(末.get("推进剂后", 0)), "　★ 通关了" if bool(末.get("通关", false)) else ""]
		"进黑市", "进事件":
			return "这一格是%s，面板已经打开。" % str(末.get("行动", "")).trim_prefix("进")
		"休整":
			return "休整结算好了（结果在休整面板里）。"
	# 瞭望站 / 遗迹 / 隧道 / 招募站 / 空格 这些「进节点当场结算」的：直接摊内核写的日志行
	# （日志文本由内核产生，表现层不自己拼）
	var 当场 := ["瞭望站", "遗迹", "隧道", "招募站", "空格"]
	if 当场.has(str(末.get("行动", ""))) and 末.get("日志") is Array:
		var 行: Array = (末.get("日志") as Array).map(func(x): return UiTheme.文本(x))
		if not 行.is_empty():
			return "　".join(行)
	var 屏 := UiTheme.节点全名(str(session.run_state.current_type())) if session.run_state != null else ""
	if not session.errors.is_empty():
		return "上一次没做成（%s）：%s" % [屏, UiTheme.文本(session.errors[session.errors.size() - 1])]
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
