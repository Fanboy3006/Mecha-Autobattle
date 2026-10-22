## 唯一的标题 / 路由壳（Stage M4-2 重写；`res://presentation/boot/boot.tscn` 这个路径不许改）。
##
## 本壳做什么（契约 §4）：建会话 + 顶栏 + 屏幕容器 + 弹窗层，按 `GameSession.screen` 路由。
## 它**自己不画业务内容**。
##
## ★ 两条既有的硬契约（`协作/Godot迁移-ARGON验收对照表.md` §8.2b，破坏即门禁红）：
##   1. `static func smoke_checksum() -> int` 必须还在、值仍是 `182751003`
##      —— `tests/unit/test_rng.gd:25` 直接 `load(...).smoke_checksum()`；
##   2. `_ready()` 里必须真的执行到那行 `print("MECHA_SMOKE %s" % JSON.stringify(...))`，
##      键名 `checksum` / `version` / `data` 一个都不许改，`data` 里要有
##      `ALLY_T` / `编成表` / `战术卡牌表` 三个计数 —— `tools/web_smoke.mjs` 与 Pages 门禁靠它。
##
## 会话**自己 new**（不加 autoload；全项目没有 `[autoload]` 段，见 §8.2b 第 4 条）。
##
## 路由表：`session.screen` 为 `"menu" | "squad" | "map" | "formation" | "battle" | "result"`
## → 对应视图类，**逐屏用到才建 + 复用**（`menu` 与 `squad` 共用同一个 `MenuView`）。
## `session.modal` 非空 → `ModalLayer` 弹对应面板；空 → 关掉。
extends Control

## 冒烟校验用：Mulberry32(20261015) 前 2000 次抽取的滚动校验和（与 tests/unit/test_rng.gd 同一算法）
static func smoke_checksum() -> int:
	var r := Mulberry32.new(20261015)
	var acc := 0
	for i in 2000:
		acc = (acc * 31 + int(r.next_float() * 4294967296.0)) & 0xFFFFFFFF
	return acc

## 会话门面（**本壳自己持有**，不做 autoload）。
var session: GameSession = null
## 顶栏（常驻）。
var 顶栏: TopBar = null
## 屏幕容器（当前屏的视图挂在它下面）。
var 屏幕容器: Control = null
## 弹窗层（所有弹窗都走它）。
var 弹窗层: ModalLayer = null
## 悬停说明层（Mouse Over；整局只有一层，挂在弹窗层之上）。
var 悬停说明层: HoverTooltip = null
## 用到才建好的视图缓存：`视图键 → Control`。
var 视图缓存: Dictionary = {}
## 当前路由到的屏名。
var 当前屏: String = ""

func _ready() -> void:
	# ① 冒烟那一行必须在 `_ready()` 里真的跑到（Web 冒烟脚本轮询控制台 90 s）
	var checksum := smoke_checksum()
	var errors := []
	DataLoader.install(errors)
	var counts := {}
	for 名 in ["ALLY_T", "编成表", "战术卡牌表"]:
		var v: Variant = Db.T.get(名)
		counts[名] = (v as Array).size() if v is Array else 0
	print("MECHA_SMOKE %s" % JSON.stringify({"checksum": checksum, "version": GameVersion.GAME_VERSION, "data": counts}))

	# ② 建壳
	启动()

## 建会话 + 主题 + 屏幕容器 + 顶栏 + 弹窗层 + 首次路由。
##
## **为什么单独留一个公开入口**：`_ready()` 只在节点真的「进树且父已 ready」时才触发；
## `tests/run_tests.gd` 是 `extends SceneTree`，测试全在 `_initialize()` 里同步跑完就 `quit()`，
## 那时 root 还没 ready → 直接 `add_child(boot.tscn 实例)` 不会触发 `_ready()`。
## 所以测试显式调 `启动()`。**幂等**：`_ready()` 之后再调不会建第二套。
func 启动() -> void:
	if session != null:
		return
	session = GameSession.new()
	session.changed.connect(route)
	# ★ 实时监视：门面每完成一个玩家动作就转发一条给服务端（`kind = "action"`）。
	session.action_recorded.connect(_当动作记录)

	theme = _建主题()
	屏幕容器 = Control.new()
	屏幕容器.name = "屏幕容器"
	UiTheme.占满(屏幕容器)
	屏幕容器.offset_top = UiTheme.顶栏高
	add_child(屏幕容器)

	顶栏 = TopBar.new()
	add_child(顶栏)
	顶栏.setup(session)
	顶栏.请求弹窗.connect(打开弹窗)
	顶栏.请求屏幕.connect(去屏)
	顶栏.零件瞄准.connect(_接零件瞄准)

	弹窗层 = ModalLayer.new()
	add_child(弹窗层)
	弹窗层.setup(session)
	弹窗层.请求弹窗.connect(打开弹窗)
	弹窗层.请求屏幕.connect(去屏)
	弹窗层.请求关闭弹窗.connect(关闭弹窗)

	# ★ 悬停说明层（Mouse Over）：**最后一个子节点**（在弹窗层之上），
	#   整局只有这一层；各视图用 `HoverTooltip.bind(控件, 文字)` 挂说明。
	悬停说明层 = HoverTooltip.new()
	悬停说明层.name = "悬停说明层"
	悬停说明层.z_index = 100
	悬停说明层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(悬停说明层)
	HoverTooltip.instance = 悬停说明层

	route()
	# ★ 最后一条：告诉服务端「浏览器刚刷新 / 刚打开一局新会话」（`kind = "boot"`，带 `state`）。
	_报启动()

# ==========================================================================================
# 路由
# ==========================================================================================

## 按 `session.screen` 把对应视图显示出来（其余隐藏），并刷新顶栏与弹窗层。
## **可以重复调**：视图只建一次，之后只 `refresh()`。
func route() -> void:
	if session == null or 屏幕容器 == null:
		return
	顶栏.refresh()
	var 屏名 := str(session.screen)
	var 键 := 视图键(屏名)
	# 无类型标注 = Variant → 动态调用视图的 setup/refresh（各视图类自己声明那两个入口）
	var v = _拿视图(键)
	for k in 视图缓存.keys():
		var n: Variant = 视图缓存[k]
		if n is Control and is_instance_valid(n):
			(n as Control).visible = (str(k) == 键)
	if v != null:
		v.visible = true
		v.refresh()
	当前屏 = 屏名
	if 弹窗层 != null:
		弹窗层.refresh()
	_上报交互("route", {"到": 屏名, "动作": "路由"})

## `menu` 与 `squad` 共用同一个 `MenuView`（它自己按 `session.screen` 决定显示分队面板）。
func 视图键(屏名: String) -> String:
	if 屏名 == "squad":
		return "menu"
	return 屏名

## 请求换屏（视图 / 顶栏发信号，本壳统一执行）。
## ★ 「结算 / 战斗」这两类弹窗**不许跟着屏幕漂**：真正切了屏就把它们收掉
##   （不然点「继续前进」从结算屏切回大地图时，会有一个 `ResultView` 弹窗叠在大地图上）。
##
## ★ 2026-10-18（作者试玩反馈第 3 条）：**状态机守卫** —— 战斗打一半不许跳去别的屏。
##   判据：`session.in_battle() and session.screen == "battle"` 时，
##   禁止切去 `"formation"` / `"map"`（从前点顶栏「编队」能切走 —— 屏幕进了编队屏，
##   可 `battle_ctx` 还在，战斗既没结算也没人管 → **孤儿战斗死锁**：回不来、也结算不了）。
##   放行的只有：① 到 `"result"`（结算屏 = 战斗已经结算的那一步）；
##   ② `return_to_menu()`（它自己把 `battle_ctx` 清空，不走这里）；③ `"battle"` 本身。
func 去屏(屏名: String) -> void:
	if session == null:
		return
	var 目标 := str(屏名)
	if session.in_battle() and str(session.screen) == "battle" \
			and (目标 == "formation" or 目标 == "map"):
		_上报交互("route", {"动作": "拦下换屏", "到": 目标,
			"原因": "战斗正在打，先结算（或回主菜单）才能离开战斗屏"})
		return
	if 目标 != str(session.screen):
		var 类 := str(session.modal.get("类型", "")) if session.modal is Dictionary else ""
		if 类 == "结算" or 类 == "战斗":
			session.modal = {}
	session.screen = 目标
	route()

## 请求开弹窗（`类型` 为 招募 / 晋升 / 三选一 / 黑市 / 休整 / 奇遇 / 结算 / 战术牌库 / 战斗）。
## ★ 2026-10-18：同样加状态机守卫 —— 战斗打一半不许用弹窗把别的屏调出来
##   （黑市 / 休整 / 奇遇这类**节点弹窗**在战斗里没有任何意义；`战斗` / `结算` 这两类照旧放行）。
func 打开弹窗(类型: String, 数据: Dictionary) -> void:
	if session == null:
		return
	if session.in_battle() and str(session.screen) == "battle" \
			and (类型 == "黑市" or 类型 == "休整" or 类型 == "奇遇" or 类型 == "事件"):
		_上报交互("route", {"动作": "拦下弹窗", "类型": 类型,
			"原因": "战斗正在打，节点弹窗要等结算之后"})
		return
	session.modal = {"类型": 类型, "数据": 数据}
	if 弹窗层 != null:
		弹窗层.refresh()
	_上报交互("route", {"动作": "开弹窗", "类型": 类型})

## 关掉弹窗（`session.modal = {}`）。
func 关闭弹窗() -> void:
	if session == null:
		return
	var 类 := str((session.modal as Dictionary).get("类型", "")) if session.modal is Dictionary else ""
	session.modal = {}
	if 弹窗层 != null:
		弹窗层.refresh()
	_上报交互("route", {"动作": "关弹窗", "类型": 类})

# ==========================================================================================
# ★ 实时监视（2026-10-16 重写；作者要「主会话随时看到我在本地网页里的每一步操作、参数、
#   返回结果与完整局面」）
#
#   两条数据流都走 `godot/tools/serve_site.mjs` 的 `POST /__ui_log`，落到
#   `F:\DSH-mecha\.tools\smoke\` 下：
#     · `live_actions.jsonl` —— 一行一条：`kind = "boot" | "route" | "click" | "action"`
#       （`action` 那一条由门面的 `action_recorded` 信号转发过来，带完整 `args` / `result` / `state`）；
#     · `live_state.json` —— 最新一条事件 + 它带来的完整局面快照 + 最近 40 条事件摘要。
#
#   ★ 编码做法（**千万别改回去**）：先把整条 payload 用 `JSON.stringify` 成 UTF-8 文本，
#     再 `Marshalls.utf8_to_base64()` 变成**纯 ASCII**，最后把这段 Base64 **直接当 POST body**
#     发出去（`body: '<base64>'`），由 `serve_site.mjs` 侧 `Buffer.from(body,'base64').toString('utf8')`
#     还原。这样：① JSON 字符串不进 JS 代码字面量 → 没有引号 / 换行转义风险；
#     ② 不走 JS 的 `atob()` → 中文不会乱码（`atob` 出的是 latin1 字节，中文必崩）。
#
#   纪律：只做观测 ——
#     · 桌面 / headless 里 `OS.has_feature("web")` 为假 → 一个字节都不发（测试里什么都不做）；
#     · Web 里发不出去就 `.catch(()=>{})` —— 不阻塞、不弹窗、不改任何游戏状态。
# ==========================================================================================

## 左键点击：记下鼠标下的控件 / 按钮文案 + 灰按钮（`disabled = true`）**也要抓到** + 当前局面快照。
##
## ★ 为什么必须**遍历可见树**而不只看 `gui_get_hovered_control()`：Godot 里 `disabled = true` 的
##   `Button` 有时不会成为「鼠标下的控件」（事件被上层 / 父容器吃掉），于是作者点了灰按钮却**一条记录都没有**，
##   「为什么点不动」就永远查不出来。这里的兜底口径 = 遍历当前可见树，凡 `Button` 且
##   `get_global_rect().has_point(鼠标位置)` 就算「点到了」，`disabled == true` 照样记下来。
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var 鼠 := event as InputEventMouseButton
	if not 鼠.pressed or 鼠.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := 鼠.position
	var 详情 := {"pos": {"x": int(pos.x), "y": int(pos.y)}}
	var 控件 := _鼠标下的控件()
	if 控件 != null:
		详情["ctrl_name"] = _控件名(控件)
		详情["ctrl_text"] = _控件文本(控件)
		详情["disabled"] = _控件禁用(控件)
		详情["tooltip"] = 控件.tooltip_text
	# ★ 灰按钮兜底：把鼠标位置下**所有**可见 `Button` 都列出来（含 disabled=true 的）。
	var 命中 := _鼠标下的按钮们(pos)
	详情["按钮们"] = 命中
	if not 命中.is_empty() and not 详情.has("ctrl_text"):
		# 没拿到「鼠标下的控件」但确实压在一个按钮上 → 用命中的第一个补全主字段。
		var 首: Dictionary = 命中[0]
		详情["ctrl_name"] = 首.get("name", "")
		详情["ctrl_text"] = 首.get("text", "")
		详情["disabled"] = bool(首.get("disabled", false))
		详情["tooltip"] = 首.get("tooltip", "")
	_发送事件("click", 详情)

## 鼠标底下的第一个 `Control`（拿不到视口 / 没人接鼠标 → null）。
func _鼠标下的控件() -> Control:
	if not is_inside_tree():
		return null
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.gui_get_hovered_control()

## 控件名 / 控件文本 / 是否被置灰 —— 三个通用读法（`Control` 基类上没有 `text` / `disabled`，
## 所以只能按类型判；`name` 是 StringName，别用 `str()`）。
func _控件名(c: Control) -> String:
	return "" if c == null else "%s" % c.name

func _控件文本(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	if c is Label:
		return (c as Label).text
	return ""

func _控件禁用(c: Control) -> bool:
	if c is BaseButton:
		return (c as BaseButton).disabled
	return false

## 鼠标位置下**所有**可见 `Button`（**含 `disabled = true` 的灰按钮**），按「谁画在上面」排好序。
## 遍历顺序 = 本壳的子树顺序（父在子前），倒过来就是「子（叠在上面的）在前」；
## 命中数上限 3 条（一次点击最多报三个，日志不会被一张密集界面刷爆）。
func _鼠标下的按钮们(pos: Vector2) -> Array:
	var 全: Array = []
	_遍历可见按钮(self, pos, 全)
	全.reverse()
	var out: Array = []
	for i in mini(3, 全.size()):
		out.append(全[i])
	return out

func _遍历可见按钮(节点: Node, pos: Vector2, 出: Array) -> void:
	if 节点 is Control and not (节点 as Control).is_visible_in_tree():
		return
	if 节点 is Button and (节点 as Control).get_global_rect().has_point(pos):
		var b: Button = 节点
		出.append({
			"name": "%s" % b.name, "text": b.text,
			"disabled": b.disabled, "tooltip": b.tooltip_text,
			"pos": {"x": int(b.get_global_rect().position.x), "y": int(b.get_global_rect().position.y)},
		})
	for c in 节点.get_children():
		_遍历可见按钮(c, pos, 出)

## 轻量日志上报（旧名保留，别的调用点还在用）：`事件` + 详情 + **当前局面快照**。
func _上报交互(事件类型: String, 详情: Dictionary) -> void:
	_发送事件(事件类型, 详情)

## 把一条事件发出去（内部）：统一加 `kind` / `时间` / `state`（完整局面快照）三样。
func _发送事件(事件类型: String, 详情: Dictionary) -> void:
	var s := session
	var 条 := {
		"kind": 事件类型,
		"事件": 事件类型,
		"时间": Time.get_datetime_string_from_system(false, true),
		"屏": str(s.screen) if s != null else "",
		"弹窗": str((s.modal as Dictionary).get("类型", "")) if (s != null and s.modal is Dictionary) else "",
		"战斗": s.in_battle() if s != null else false,
		"券": s.ticket_count() if s != null else 0,
		"名册": s.roster_count() if s != null else 0,
		# ★ 完整局面快照（纯读）：主会话 / 服务端不用猜状态，直接读这一块。
		"state": s.snapshot_for_monitor() if s != null else {},
	}
	for k in 详情.keys():
		条[str(k)] = 详情[k]
	if not OS.has_feature("web"):
		return
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(条))
	JavaScriptBridge.eval("fetch('/__ui_log',{method:'POST',headers:{'Content-Type':'text/plain'},body:'" + b64 + "'}).catch(()=>{})", true)

## ★ 门面每完成一个玩家动作 → 原样转发给服务端（`kind = "action"`）。
## `entry` 里已经有 `seq` / `action` / `args` / `result` / `state`，这里只补「时间」。
func _当动作记录(entry: Dictionary) -> void:
	_发送事件("action", {"entry": entry})

## 服务端要知道「浏览器刚刷新 / 刚打开一局新会话」：启动完成时发一条 `kind = "boot"`。
func _报启动() -> void:
	_发送事件("boot", {
		"版本": GameVersion.GAME_VERSION,
		"视图": 视图缓存.keys(),
		"存档": session.has_saved_run() if session != null else false,
	})

## 当前屏的视图（没建过就现在建）。返回 Variant：各视图是不同类，只能动态调它的 setup/refresh。
func 当前视图() -> Variant:
	if session == null:
		return null
	return _拿视图(视图键(str(session.screen)))

# ==========================================================================================
# 内部
# ==========================================================================================

## 拿（必要时建）一个视图。**返回类型特意不标注** —— `Control` 基类上没有 `setup/refresh`，
## 标了静态类型就只能靠 `call()`，反而更绕。
func _拿视图(键: String) -> Variant:
	if 视图缓存.has(键):
		var 旧: Variant = 视图缓存[键]
		if 旧 is Control and is_instance_valid(旧):
			return 旧
	var v = _造视图(键)
	if v == null:
		return null
	屏幕容器.add_child(v)
	_接视图信号(v)
	v.setup(session)
	视图缓存[键] = v
	return v

func _造视图(键: String) -> Variant:
	match 键:
		"menu":
			return MenuView.new()
		"map":
			return MapView.new()
		"formation":
			return FormationView.new()
		"battle":
			return BattleView.new()
		"result":
			return ResultView.new()
	return null

func _接视图信号(v: Control) -> void:
	if v.has_signal("请求弹窗"):
		v.connect("请求弹窗", 打开弹窗)
	if v.has_signal("请求屏幕"):
		v.connect("请求屏幕", 去屏)
	if v.has_signal("请求关闭弹窗"):
		v.connect("请求关闭弹窗", 关闭弹窗)

## 顶栏点了零件 → 让大地图高亮合法目标格（地图视图没建过就现在建）。
func _接零件瞄准(下标: int, 零件键: String, 目标格: Array) -> void:
	var v = _拿视图("map")
	if v is MapView:
		(v as MapView).瞄准零件(下标, 零件键, 目标格)

func _建主题() -> Theme:
	var t := Theme.new()
	t.default_font_size = UiTheme.字号_正文
	return t
