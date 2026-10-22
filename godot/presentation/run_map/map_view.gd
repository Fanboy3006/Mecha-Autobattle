## 正方形大地图（Stage M4-2，本单最难的一块）。
##
## 全部按 `MapGenerator.shape(层)` 的 `列数 × 行数` 画格：**格子缺失处留空**（不是实心方块）。
## 每个格的展示信息只来自**纯读**接口：
##   `RunState.grid()` / `cell_at` / `is_visited` / `is_revealed`、`MapNavigator.is_known` /
##   `reachable_cells` / `tunnel_other_end` / `retreat_cost_preview`。
##
## ★ UX-6（2026-10-19，作者反馈第 5 条）：本屏**不再显示「必经点」**（摘要数字 / `[必]` 旗标 /
##   橙色边框覆盖 / 悬停说明那一行全部下线）。`MapGenerator.must_pass()` 内核函数保留不动 ——
##   生成地图放守军时它还在用（内核口径，本屏只是不显示）。
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
## ★ 2026-10-18：**战斗类节点**（走上去不再直接开打，而是先进战前编队确认屏）。
const 战斗节点类型 := ["作战", "精英", "守军", "侵蚀源", "出口守军"]

var session: GameSession = null

var _层信息: Label
## ★ UX-1 第 4 项：零件瞄准态的**金色引导横幅**（平时 `visible == false`，不占版面）。
var _瞄准横幅: PanelContainer
var _瞄准横幅文: Label
var _瞄准横幅按钮: Button
var _地图网格: GridContainer
var _图例: Label
var _节点说明: Label
var _预告面板: VBoxContainer
var _按钮组: HBoxContainer
var _取消瞄准: Button
var _打追击: Button
var _进入当前格: Button
var _换层: Button
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
		_刷新瞄准横幅()
		return
	if s.floor_num != _层:
		_层 = s.floor_num
		_已结算 = -1
	var 形状 := MapGenerator.shape(s.floor_num)
	var 列数 := int(形状.get("列数", 5))
	var 行数 := int(形状.get("行数", 5))
	var 可达 := _可达集合(s)
	# ★ UX-6（2026-10-19，作者反馈第 5 条）：顶栏摘要**不再写「· 必经点 N 个」** ——
	#   作者的原话是这一串数字纯属干扰。`MapGenerator.must_pass()` 内核函数保留不动
	#   （放守军时内核还会调它），只是这一屏不显示、不拿它染色。
	_层信息.text = "第 %s 层 · %s×%s 正方形 · 推进剂 %s / %s · 当前格 %s（%s）· 出口 %s" % [
		UiTheme.文本(s.floor_num), UiTheme.文本(列数), UiTheme.文本(行数),
		UiTheme.文本(s.propellant), UiTheme.文本(s.propellant_max), UiTheme.文本(s.node_id),
		UiTheme.节点全名(s.current_type()), MapNavigator.current_exit_kind(s)]
	# ★ 名册空 = 出击 0 台 = 任何战斗格都进不去（`start_node_battle` 会拒绝「出击名单是空的」）。
	#   内核设计就是「开局先招募」（`RosterManager.new_run` 的注释），所以这里必须说清楚。
	_名册提示.visible = s.roster.is_empty()
	if _名册提示.visible:
		_名册提示.text = "名册是空的 —— 先去顶栏「名册 / 招募 / 晋升」用招募券招人，再编队，才能开战。"
	_图例.text = "图例：起=起点 战=作战 精=精英 休=休整 市=黑市 事=奇遇 望=瞭望站 遗=遗迹 蚀=侵蚀源 隧=废弃隧道 守=出口守军 尽=出口尽头 径=出口小径 空=林间空地；★=当前所在格 可=现在走得到 过=走过 知=已揭开"
	_建网格(s, 列数, 行数, 可达)
	_取消瞄准.visible = not _瞄准.is_empty()
	_刷新瞄准横幅()
	# ★ 2026-10-18（作者试玩反馈第 3 条）：按钮按状态精简，不再常驻误导玩家。
	#   · 「打追击战」**只在推进剂为 0 时**才露面（判据仍用内核 `exit_chase_pending` 来置灰 / 放行）；
	#   · 「进入当前格」在起点 / 已结算的格上置灰，并写明「当前格已结算」；
	#   · 「走出口 / 换层」只在**脚下是出口格且守军已清**时可见 + 高亮。
	_打追击.visible = float(s.propellant) <= 0.0
	_打追击.disabled = not _够格打追击(s)
	_刷新进入按钮(s)
	_刷新换层按钮(s)
	_刷新预告(s)
	_刷新节点说明(s)
	_结果行.text = _结果文字()

## 「进入当前格」按状态精简：起点 / 已经结算过的格 → 置灰 + 文案写清「当前格已结算」。
func _刷新进入按钮(s: RunState) -> void:
	if _进入当前格 == null:
		return
	var 类型 := s.current_type()
	var 起点 := int(s.map_data.get("起点", -1)) == s.node_id
	# 「这一格的事已经做过」：视图自己记的 `_已结算`，或门面记的「已结算节点键」（休整 / 奇遇那两格）。
	var 做过 := (_已结算 == s.node_id) or session.节点已结算过()
	var 空 := 类型.is_empty()
	var 无内容 := 空 or 类型 == "起点"
	_进入当前格.disabled = 起点 or 做过 or 无内容
	if _进入当前格.disabled:
		_进入当前格.text = "当前格已结算"
	elif 战斗节点类型.has(类型):
		_进入当前格.text = "进入当前格（先确认编队）"
	else:
		_进入当前格.text = "进入当前格"

## 「走出口 / 换层」按状态精简：**只有脚下是出口格**时才可见；
## 守军已清（`MapNavigator.is_guard_cleared`）且这一型出口要求守军 → 高亮放行，否则置灰写明原因。
func _刷新换层按钮(s: RunState) -> void:
	if _换层 == null:
		return
	var 出口类 := MapGenerator.exit_kinds()
	var 脚下 := s.current_type()
	var 是出口 := 出口类.has(脚下)
	var 出口型 := str(出口类.get(脚下, "")) if 是出口 else ""
	var 要守军 := MapNavigator.exit_requires_guard(出口型)
	var 守军清了 := MapNavigator.is_guard_cleared(s)
	_换层.visible = 是出口
	_换层.disabled = not 是出口 or (要守军 and not 守军清了)
	if not 是出口:
		_换层.text = "走出口 / 换层（走到出口格可用）"
		_换层.add_theme_color_override("font_color", UiTheme.弱文字)
	elif _换层.disabled:
		_换层.text = "走出口 / 换层（出口守军还没清）"
		_换层.add_theme_color_override("font_color", UiTheme.负面)
	else:
		_换层.text = "走出口 / 换层"
		_换层.add_theme_color_override("font_color", UiTheme.高亮)

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "大地图"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "地图上下列", true, UiTheme.间距_小)
	UiTheme.占满留边(列)
	_层信息 = UiTheme.建标签(列, "", UiTheme.字号_小节, UiTheme.高亮)
	_层信息.name = "层信息"
	# ★ UX-1 第 4 项（2026-10-19，作者试玩反馈第 1 条「零件点击了无法使用」）：
	#   进入零件瞄准态时，在大地图**正上方**顶一条醒目的金色引导横幅 + 一个「取消瞄准」按钮。
	#   平时 `visible == false` —— 容器不给它留位置，不占版面（版面门禁照旧）。
	_瞄准横幅 = UiTheme.建面板(列, "零件瞄准横幅", UiTheme.卡片底_亮, UiTheme.高亮)
	_瞄准横幅.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_瞄准横幅.visible = false
	var 横幅行 := UiTheme.建盒(_瞄准横幅, "零件瞄准横幅行", false, UiTheme.间距_小)
	_瞄准横幅文 = UiTheme.建标签(横幅行, "", UiTheme.字号_正文, UiTheme.高亮)
	_瞄准横幅文.name = "零件瞄准横幅文字"
	_瞄准横幅文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_瞄准横幅文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_瞄准横幅按钮 = UiTheme.建按钮(横幅行, "取消瞄准", _点取消瞄准)
	_瞄准横幅按钮.name = "横幅取消瞄准按钮"
	_瞄准横幅按钮.tooltip_text = "退出零件瞄准，回到普通移动（再点一次同一件零件也能退出）"
	_名册提示 = UiTheme.建说明(列, "", UiTheme.字号_正文, UiTheme.负面)
	_名册提示.name = "名册提示"
	_名册提示.visible = false
	var 主体 := UiTheme.建盒(列, "地图主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var 左列 := UiTheme.建盒(主体, "地图左列", true, UiTheme.间距_小)
	左列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	左列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ★ 地图网格放进 `ScrollContainer`：换到 7×7 的大图也不会顶出屏幕。
	var 地图滚 := ScrollContainer.new()
	地图滚.name = "地图滚动"
	地图滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	地图滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	地图滚.clip_contents = true
	左列.add_child(地图滚)
	_地图网格 = GridContainer.new()
	_地图网格.name = "地图网格"
	_地图网格.columns = 5
	_地图网格.add_theme_constant_override("h_separation", UiTheme.间距_小)
	_地图网格.add_theme_constant_override("v_separation", UiTheme.间距_小)
	_地图网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_地图网格.size_flags_vertical = Control.SIZE_EXPAND_FILL
	地图滚.add_child(_地图网格)
	_图例 = UiTheme.建说明(左列, "", UiTheme.字号_小, UiTheme.弱文字)
	_图例.name = "图例"

	var 右列 := UiTheme.建盒(主体, "地图侧栏", true, UiTheme.间距_小)
	右列.custom_minimum_size = Vector2(330, 0)
	右列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(右列, "这一格", UiTheme.字号_小节, UiTheme.高亮)
	_节点说明 = UiTheme.建说明(右列, "", UiTheme.字号_小, UiTheme.主文字)
	_节点说明.name = "节点说明"
	UiTheme.建标签(右列, "预告（走过去会发生什么）", UiTheme.字号_小节, UiTheme.高亮)
	_预告面板 = UiTheme.建滚动(右列, "预告面板", 250.0)
	_按钮组 = UiTheme.建盒(右列, "地图按钮组", false, UiTheme.间距_小)
	var 进 := UiTheme.建按钮(_按钮组, "进入当前格", _点进入)
	进.name = "进入当前格按钮"
	进.tooltip_text = "兜底 / 重试用：正常玩法是**点格子**，走上去就自动结算（战斗格会先进战前编队确认屏）。同一格不会重复结算。"
	_进入当前格 = 进
	var 换 := UiTheme.建按钮(_按钮组, "走出口 / 换层", _点换层)
	换.name = "换层按钮"
	换.tooltip_text = "站在出口尽头 / 出口小径上时才能换层（有牌没选完会被拦下）"
	_换层 = 换
	_取消瞄准 = UiTheme.建按钮(_按钮组, "取消零件瞄准", _点取消瞄准)
	_取消瞄准.name = "取消瞄准按钮"
	_取消瞄准.tooltip_text = "不再用零件瞄准，回到普通移动"
	_取消瞄准.visible = false
	# ★ D-08 兜底：推进剂见底、门面又还没开打时，给玩家一条路（不然这一刻既走不动也打不了）。
	#   判据一律用内核的 `MapNavigator.exit_chase_pending`，**不自己写「推进剂 <= 0」**。
	# ★ 2026-10-18：按钮**只在推进剂为 0 时可见**（平时藏起来，不再常驻在地图底下误导玩家）；
	#   节点仍然留在树里（只是 `visible = false`），`find_child("打追击战按钮")` 照旧找得到。
	_打追击 = UiTheme.建按钮(_按钮组, "打追击战（推进剂用光，甩掉追兵才能继续前进）", _点打追击)
	_打追击.name = "打追击战按钮"
	_打追击.tooltip_text = "只在「推进剂见底 + 本层还没被追击过 + 现在不在战斗里」时可点；点它先进战前编队确认屏，确认后走 GameSession.fight_chase_battle()"
	_打追击.visible = false
	_结果行 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)
	_结果行.name = "结果行"

# ==========================================================================================
# 网格
# ==========================================================================================

func _建网格(s: RunState, 列数: int, 行数: int, 可达: Dictionary) -> void:
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
			_地图网格.add_child(_造格按钮(s, id, 可达))

func _造格按钮(s: RunState, id: int, 可达: Dictionary) -> Button:
	var 格 := s.cell_at(id)
	var 类型 := str(格.get("类型", ""))
	var 色 := UiTheme.节点色(类型)
	# ★ UX-6（2026-10-19，作者反馈第 5 条）：格子上的 `[必]` 字标记**删掉** ——
	#   只留 ★ 当前格 / 可 / 过 / 知 这几个真正影响玩家下一步的旗标。
	var 旗: Array = []
	if id == s.node_id:
		旗.append("★")
	if 可达.has(id):
		旗.append("可")
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
	# ★ UX-6：边框颜色**纯粹反映**「当前格 / 可走格 / 零件目标格 / 节点类型」——
	#   从前那层 `UiTheme.必经点色` 橙色覆盖已经撤掉（它会盖住节点类型色，纯干扰）。
	# ★ PART-3：零件目标格这一层**不查迷雾** —— 老妈的融雪（`thaw`）的目标集本来就把
	#   `not is_known` 的非战斗格算进来，这里照实高亮（迷雾只压字色，不压边框）。
	var 边色 := 色
	var 边宽 := 1
	if 可达.has(id):
		边色 = UiTheme.可移动色
		边宽 = 2
	if id == s.node_id:
		边色 = UiTheme.当前格色
		边宽 = 3
	if _瞄准.has("目标") and (_瞄准["目标"] as Dictionary).has(id):
		边色 = UiTheme.零件目标色
		边宽 = 3
	b.add_theme_stylebox_override("normal", UiTheme.底样式(UiTheme.卡片底, 边色, 边宽))
	b.tooltip_text = _格子提示(s, id, 可达)
	b.mouse_entered.connect(选中预告.bind(id))
	b.focus_entered.connect(选中预告.bind(id))
	b.pressed.connect(_点格.bind(id))
	return b

func _格子提示(s: RunState, id: int, 可达: Dictionary) -> String:
	var 格 := s.cell_at(id)
	var 段: Array = ["（%d, %d）%s" % [int(格.get("列", 0)) + 1, int(格.get("行", 0)) + 1, UiTheme.节点全名(str(格.get("类型", "")))]]
	if id == s.node_id:
		段.append("你现在在这里")
	if s.is_visited(id):
		段.append("已经走过")
	elif MapNavigator.is_known(s, id):
		段.append("已经揭开")
	if 可达.has(id):
		var 预 := session.preview_cell_move(id)
		段.append("可以走：花 %s 点推进剂" % UiTheme.文本(预.get("推进剂消耗", 0)))
	if _瞄准.has("目标") and (_瞄准["目标"] as Dictionary).has(id):
		段.append("【%s】能点这一格" % str(_瞄准.get("名", _瞄准.get("键", ""))))
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
		UiTheme.建说明(_预告面板, "零件【%s】%s" % [str(_瞄准.get("名", _瞄准.get("键", ""))),
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
	# ★ 2026-10-18（作者试玩反馈第 1 条）：战斗类节点**不再直接开打** —— 先进战前编队确认屏。
	#   这一支同时兜住两条路：① 点格子走上去（`自动 = true`）；
	#   ② 兜底按钮「进入当前格」（`自动 = false`，脚下就是战斗格时同样先确认编队）。
	if 战斗节点类型.has(类型):
		_已结算 = 格
		session.prepare_battle_formation("node")
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
	if _瞄准.is_empty():
		return
	var 名 := str(_瞄准.get("名", _瞄准.get("键", "")))
	_瞄准 = {}
	_清空(_预告面板)
	if not 名.is_empty():
		UiTheme.建说明(_预告面板, "已经退出零件【%s】的瞄准，回到普通移动。" % 名, UiTheme.字号_小, UiTheme.高亮)
	refresh()

## 零件瞄准横幅（★ UX-1 第 4 项）：只有 `_瞄准` 非空时才露出来，文字里写清「下一步点哪」。
##
## ★ 任务单 PART-3：横幅必须写明这件零件**免推进剂**还是**消耗 1 推进剂**
##   （读数来自门面 `part_can_use_now().free`）；瞄准老妈的融雪（`thaw`）时再点明
##   「迷雾里的非战斗格也能直接点」（原版口径：迷雾不拦非战斗格）。
func _刷新瞄准横幅() -> void:
	if _瞄准横幅 == null or _瞄准横幅文 == null:
		return
	var 在瞄准 := not _瞄准.is_empty()
	_瞄准横幅.visible = 在瞄准
	if not 在瞄准:
		_瞄准横幅文.text = ""
		return
	var 名 := str(_瞄准.get("名", _瞄准.get("键", "")))
	var 费文 := "免推进剂" if bool(_瞄准.get("免", false)) else "消耗 1 推进剂"
	var 目标: Dictionary = _瞄准.get("目标") if _瞄准.get("目标") is Dictionary else {}
	var 注 := ""
	if str(_瞄准.get("键", "")) == "thaw":
		注 = "；老妈的融雪可以直接落到迷雾里的非战斗格"
	_瞄准横幅文.text = "【正在使用零件：%s（%s）— 请点击下方粉色边框的高亮目标格生效，再点同一件零件或点右侧「取消瞄准」退出】（这一版有 %d 个合法目标格%s）" % [
		名, 费文, 目标.size(), 注]

## 这一格 / 这一刻够不够格打追击战（**判据全部来自门面与内核**，不自己写「推进剂 <= 0」）：
## 现在不在战斗里、没有未决的招募券，而且内核的 `MapNavigator.exit_chase_pending` 说是时机。
func _够格打追击(s: RunState) -> bool:
	return session.battle_ctx.is_empty() and not session.有未决的招募券() and MapNavigator.exit_chase_pending(s)

## 「打追击战」按钮：★ 2026-10-18 改为**先进战前编队确认屏**（`prepare_battle_formation("chase")`），
## 玩家点【确认编队 · 开始战斗】才真的走门面的 `GameSession.fight_chase_battle()`（D-08）。
func _点打追击() -> void:
	if session == null:
		return
	var s := session.run_state
	if s == null:
		return
	if not _够格打追击(s):
		_清空(_预告面板)
		UiTheme.建说明(_预告面板, "现在用不上「打追击战」：推进剂 %s（要见底）、本层已追击过 = %s、现在在战斗里 = %s。" % [
			UiTheme.文本(s.propellant), str(s.chased), str(not session.battle_ctx.is_empty())], UiTheme.字号_小, UiTheme.高亮)
		return
	session.prepare_battle_formation("chase")
	refresh()

## 由 boot 接 `TopBar.零件瞄准` 调到这儿。
##
## ★ 任务单 PART-3（黑流树海原版对齐）新增一条分支：**不用选落点的一键零件**（小八界 `bagua`，
##   门面 `part_can_use_now().instant == true`）点一下就直接让门面随机传送 —— 不进瞄准态、
##   不等玩家点格子；落点之后照旧走本屏统一的 `_进入脚下()` 结算（与走格 / 点目标格同一条路）。
## ★ UX-1 第 4 项：**再点同一件零件 = 退出瞄准**（横幅里那句「再点零件…退出」就是这一句实现的）。
func 瞄准零件(下标: int, 零件键: String, 目标格: Array) -> void:
	var 状: Dictionary = session.part_can_use_now(下标) if session != null else {}
	var 一键 := 零件键 == "bagua" or bool(状.get("instant", false))
	if 一键:
		if session == null or not bool(状.get("ok", false)):
			# 门面说这一件现在不能一键发动（次数用尽 / 不在大地图 / 本层没有可落的非战斗格）：
			# 表现层不发明规则，只把它那句 `why` 原样摊出来。
			_瞄准 = {}
			refresh()
			_清空(_预告面板)
			var 因 := str(状.get("why", ""))
			if 因.is_empty():
				因 = session.当前动作错误() if session != null else "还没有进行中的局"
			UiTheme.建说明(_预告面板, "这件零件现在用不了（%s）。" % UiTheme.文本(因),
				UiTheme.字号_小, UiTheme.负面)
			return
		_一键零件(下标, 零件键)
		return
	if not _瞄准.is_empty() and int(_瞄准.get("下标", -1)) == 下标 and str(_瞄准.get("键", "")) == 零件键:
		_点取消瞄准()
		return
	var 集: Dictionary = {}
	for k in 目标格:
		集[int(k)] = true
	_瞄准 = {"下标": 下标, "键": 零件键, "名": str(状.get("name", 零件键)),
		"免": bool(状.get("free", false)), "目标": 集}
	refresh()

## 一键发动（小八界）：**不选落点**，直接 `session.use_part(下标, -1)` 让内核带种子抽一个落点，
## 然后按「用掉一件零件」的普通落点流程收尾 —— 即时反馈 + `_进入脚下()`（黑市 / 休整 / 奇遇
## 由本屏发信号开弹窗，战斗类节点进战前编队确认屏，出口格走门面 `try_advance_floor()`）。
## 落点结算**全部复用**既有那两条路：表现层不自己挑格子、不改状态。
func _一键零件(下标: int, 零件键: String) -> void:
	_瞄准 = {}
	if session == null:
		refresh()
		return
	var 件名 := 零件键
	var 状 := session.part_can_use_now(下标)
	if not (状 as Dictionary).is_empty():
		件名 = str((状 as Dictionary).get("name", 零件键))
	# 门面自己会校验次数 / 推进剂 / 候选池（`bagua` 免推进剂），这里只转述结果。
	var r: Dictionary = session.use_part(下标, -1)
	refresh()
	if not bool(r.get("ok", false)):
		_用掉反馈(r, 件名)
		return
	# ★ D-08 同款守卫：门面可能在这一步就开了追击战 / 切到战前编队确认屏 —— 这时不能再往下结算。
	var 先收 := str(session.screen) == "battle" or str(session.screen) == "formation" or session.pending_battle_confirm
	if not 先收:
		# 落点这一格的东西照常结算（一键发动也不许「传送过去就不管了」）。
		_进入脚下(true)
	# ★ 即时反馈放在**最后**写：节点结算那一下会触发重画（`refresh()` 会清空预告面板），
	#   先写就会被冲掉 —— 放到后面，玩家看到的才是「这件零件用掉了、落到哪」。
	_用掉反馈(r, 件名)

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
		var 件名 := str(_瞄准.get("名", _瞄准.get("键", "")))
		_瞄准 = {}
		# ★ UX-1 第 4 项：点合法目标格 → **立刻**执行，成功后退出瞄准态并给即时反馈
		#   （从前这里调完 `use_part` 就 `return`，界面不刷新：既看不到结果，也看不出已经用掉了）。
		# ★ PART-3：老妈的融雪（`thaw`）的目标集**含迷雾里的非战斗格**（门面 `part_targets` 给的），
		#   这里只认「在目标集里」这一条判据 —— **不查 `is_known`**，所以迷雾格照点不误。
		var r := session.use_part(下标, id)
		refresh()
		_用掉反馈(r, 件名)
		return
	if _瞄准.has("目标"):
		_清空(_预告面板)
		UiTheme.建说明(_预告面板, "现在正在用零件瞄准：只能点粉色高亮的合法目标格（点「取消瞄准」或再点那件零件回到普通移动）。",
			UiTheme.字号_小, UiTheme.零件目标色)
		return
	# ★ 2026-10-18（作者试玩反馈第 2 条）：手上还有没决定的招募券 → **不移动**，
	#   直接把招募弹窗弹出来，先把这张券处理掉（招一台，或者按【放弃此券】）。
	if session.有未决的招募券():
		_清空(_预告面板)
		UiTheme.建说明(_预告面板, "手上还有 %d 张招募券没决定 —— 先把它们处理掉（招募一台，或者按【放弃此券】）再走格子。" % session.ticket_count(),
			UiTheme.字号_小, UiTheme.高亮)
		请求弹窗.emit("招募", {})
		return
	var 走 := session.move_to_cell(id)
	if not bool(走.get("ok", false)):
		refresh()
		return
	# ★ D-08 守卫：门面可能在**这一步**就开了一场（推进剂见底 → 追击战），它已经把屏幕切成 "battle"。
	#   这时**绝不能再往下走** `_进入脚下()` —— 那会顺手把脚下这个节点结算掉，把刚开的那一场丢在一边
	#   （实测：脚下是遗迹/瞭望站/招募站/休整/黑市/事件这类格，屏幕会被切回 "map"，
	#    而 `battle_ctx` 里那一场追击战就再也没人管 → 推进剂 0、走不动也打不了）。
	#   交给 boot 按 `screen` 路由到战斗屏就是了。
	if str(session.screen) == "battle":
		refresh()
		return
	# ★ 2026-10-18：战斗类节点走上去会**切到战前编队确认屏**（`prepare_battle_formation`）——
	#   同样不能再往下走 `_进入脚下()`（那会把确认屏顶掉、直接开打）。
	if str(session.screen) == "formation" or session.pending_battle_confirm:
		refresh()
		return
	# ★ 林间空地 / 走过的格：只刷一次屏 —— 不弹任何框、不进任何屏（JS `:220-221` 逐字同口径）
	if bool(走.get("空格落脚", false)) or bool(走.get("已过", false)):
		refresh()
		return
	_进入脚下(true)

## 用掉一件零件之后那段**统一的即时反馈**（点目标格用掉 / 一键发动都走它）。
##
## 文本里的零件名、落点格号、落点类型、额外收益**全部来自门面返回的 `Dictionary`**，
## 表现层只负责排版（「用掉了」这几个字是版面门禁 9d 认的那句，别改）。
func _用掉反馈(r: Dictionary, 件名: String) -> void:
	_清空(_预告面板)
	if session == null:
		return
	if not bool(r.get("ok", false)):
		UiTheme.建说明(_预告面板, "这件零件没使出来（%s）。" % UiTheme.文本(session.当前动作错误()),
			UiTheme.字号_小, UiTheme.负面)
		return
	var 额外: Variant = r.get("额外") if r.get("额外") is Dictionary else {}
	var 附 := ""
	if not (额外 as Dictionary).is_empty():
		var 段: Array = []
		for k in (额外 as Dictionary).keys():
			if int((额外 as Dictionary)[k]) != 0:
				段.append("%s +%s" % [str(k), UiTheme.文本((额外 as Dictionary)[k])])
		if not 段.is_empty():
			附 = "（额外：" + "、".join(段) + "）"
	var 落: Variant = r.get("到", session.run_state.node_id if session.run_state != null else 0)
	UiTheme.建说明(_预告面板, "零件【%s】用掉了：落到第 %s 格（%s）%s。" % [
		str(r.get("零件", 件名)), UiTheme.文本(落),
		UiTheme.节点全名(str(r.get("类型", ""))), 附], UiTheme.字号_小, UiTheme.正面)

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

## ★ UX-6（2026-10-19，作者反馈第 5 条）：**「必经点」的视觉与文案全部下线** ——
##   顶栏摘要不再写「· 必经点 N 个」、格子不再挂 `[必]` 与橙色边框、悬停说明不再有那一行；
##   所以 `_必经集合()`（读 `MapGenerator.must_pass`）也从本屏删掉了。
##   ★ 内核 `MapGenerator.must_pass()` **保留不动**：生成地图放守军时它还在用（本屏只是不显示）。

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
	if not session.当前动作错误().is_empty():
		return "上一次没做成（%s）：%s" % [屏, UiTheme.文本(session.当前动作错误())]
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
