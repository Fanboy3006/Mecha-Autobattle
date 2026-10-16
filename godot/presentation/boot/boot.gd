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

	route()

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

## `menu` 与 `squad` 共用同一个 `MenuView`（它自己按 `session.screen` 决定显示分队面板）。
func 视图键(屏名: String) -> String:
	if 屏名 == "squad":
		return "menu"
	return 屏名

## 请求换屏（视图 / 顶栏发信号，本壳统一执行）。
func 去屏(屏名: String) -> void:
	if session == null:
		return
	session.screen = 屏名
	route()

## 请求开弹窗（`类型` 为 招募 / 晋升 / 三选一 / 黑市 / 休整 / 奇遇 / 结算 / 战术牌库 / 战斗）。
func 打开弹窗(类型: String, 数据: Dictionary) -> void:
	if session == null:
		return
	session.modal = {"类型": 类型, "数据": 数据}
	if 弹窗层 != null:
		弹窗层.refresh()

## 关掉弹窗（`session.modal = {}`）。
func 关闭弹窗() -> void:
	if session == null:
		return
	session.modal = {}
	if 弹窗层 != null:
		弹窗层.refresh()

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
