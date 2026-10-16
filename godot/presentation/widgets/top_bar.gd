## 顶栏常驻状态条（Stage M4-2）。
##
## 单向数据流：**只读** `GameSession.topbar_state()`（+ `RelicSystem.名` / `PartSystem.part_info`
## 这类纯读目录），按钮只调 `GameSession` 的命令方法；自己一处数值都不算。
##
## 对外只有两个入口：`setup(session)` / `refresh()`（契约 §3）。
## 自己要开弹窗 / 换屏时**发信号**，由 boot 统一处理（表现层不各自弹各自的框）。
class_name TopBar
extends Control

## 请求 boot 打开一个弹窗（`类型` 为 招募 / 晋升 / 战术牌库 …）。
signal 请求弹窗(类型: String, 数据: Dictionary)
## 请求 boot 换一个屏（`formation` / `menu` …）。
signal 请求屏幕(屏名: String)
## 点了一件主动零件：让大地图高亮合法目标格（`目标格` 来自 `PartSystem.part_targets`）。
signal 零件瞄准(下标: int, 零件键: String, 目标格: Array)

var session: GameSession = null

var _层数: Label
var _推进剂: Label
var _源碳: Label
var _希望: Label
var _基地耐久: Label
var _部队等级: Label
var _出击上限: Label
var _藏品栏: HBoxContainer
var _零件栏: HBoxContainer
var _按钮组: HBoxContainer
var _说明行: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _层数 == null:
		return
	if session == null:
		_清空局态()
		return
	var d := session.topbar_state()
	if not bool(d.get("有局", false)):
		_清空局态()
		return
	_层数.text = "第 %s 层 · %s" % [UiTheme.文本(d.get("层", 1)), UiTheme.节点全名(str(d.get("节点类型", "")))]
	_推进剂.text = "推进剂 %s" % UiTheme.比值(d.get("推进剂", 0), d.get("推进剂上限", 0))
	_推进剂.add_theme_color_override("font_color", UiTheme.推进剂色)
	_推进剂.tooltip_text = _推进剂明细文字(d)
	_源碳.text = "源碳 %s" % UiTheme.文本(d.get("源碳", 0))
	_源碳.add_theme_color_override("font_color", UiTheme.源碳色)
	_希望.text = "希望 %s" % UiTheme.文本(d.get("希望", 0))
	_希望.add_theme_color_override("font_color", UiTheme.希望色)
	_基地耐久.text = "基地耐久 %s" % UiTheme.比值(d.get("基地耐久", 0), d.get("基地最大耐久", 0))
	_基地耐久.add_theme_color_override("font_color", UiTheme.耐久色)
	var 门槛: Variant = d.get("升级门槛")
	_部队等级.text = "部队 Lv%s · 经验 %s%s" % [UiTheme.文本(d.get("等级", 1)), UiTheme.文本(d.get("经验", 0)),
		"" if 门槛 == null else " / %s" % UiTheme.文本(门槛)]
	_部队等级.add_theme_color_override("font_color", UiTheme.经验色)
	_出击上限.text = "出击 %s / %s · 名册 %s · 券 %s" % [UiTheme.文本(d.get("出击数", 0)),
		UiTheme.文本(d.get("出击上限", 0)), UiTheme.文本(d.get("名册数", 0)), UiTheme.文本(d.get("券数", 0))]
	_说明行.text = "藏品 %s 件 · 零件 %s 件 · 战术牌 %s 张 · 已清节点 %s · 场次 %s（胜 %s）" % [
		UiTheme.文本(d.get("藏品数", 0)), UiTheme.文本(d.get("零件数", 0)),
		UiTheme.文本((d.get("战术牌库") as Array).size() if d.get("战术牌库") is Array else 0),
		UiTheme.文本(d.get("已清节点", 0)), UiTheme.文本(d.get("场次", 0)), UiTheme.文本(d.get("胜场", 0))]
	_建藏品栏(d)
	_建零件栏(d)
	_按钮组.visible = true

# ==========================================================================================
# 建节点树（只在 setup 里调一次）
# ==========================================================================================

func _build() -> void:
	name = "顶栏"
	UiTheme.顶部一条(self, UiTheme.顶栏高)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var 底 := UiTheme.建面板(self, "顶栏底", UiTheme.面板底, UiTheme.边框)
	UiTheme.占满(底)
	var 列 := UiTheme.建盒(底, "顶栏上下列", true, UiTheme.间距_小)

	var 状态行 := UiTheme.建盒(列, "状态行", false, UiTheme.间距_大)
	_层数 = UiTheme.建标签(状态行, "第 1 层", UiTheme.字号_小节, UiTheme.高亮)
	_层数.name = "层数"
	_推进剂 = UiTheme.建标签(状态行, "推进剂 0", UiTheme.字号_小节, UiTheme.推进剂色)
	_推进剂.name = "推进剂"
	_源碳 = UiTheme.建标签(状态行, "源碳 0", UiTheme.字号_小节, UiTheme.源碳色)
	_源碳.name = "源碳"
	_希望 = UiTheme.建标签(状态行, "希望 0", UiTheme.字号_小节, UiTheme.希望色)
	_希望.name = "希望"
	_基地耐久 = UiTheme.建标签(状态行, "基地耐久 0", UiTheme.字号_小节, UiTheme.耐久色)
	_基地耐久.name = "基地耐久"
	_部队等级 = UiTheme.建标签(状态行, "部队 Lv1", UiTheme.字号_小节, UiTheme.经验色)
	_部队等级.name = "部队等级"
	_出击上限 = UiTheme.建标签(状态行, "出击 0 / 0", UiTheme.字号_小节, UiTheme.主文字)
	_出击上限.name = "出击上限"

	var 第二行 := UiTheme.建盒(列, "第二行", false, UiTheme.间距_大)
	var 藏品标题 := UiTheme.建标签(第二行, "藏品：", UiTheme.字号_小, UiTheme.次要文字)
	藏品标题.tooltip_text = "本局已经到手的藏品（黑市 / 精英 / Boss / 遗迹发的）"
	_藏品栏 = UiTheme.建盒(第二行, "藏品栏", false, UiTheme.间距_小)
	_藏品栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 零件标题 := UiTheme.建标签(第二行, "零件：", UiTheme.字号_小, UiTheme.次要文字)
	零件标题.tooltip_text = "点一件主动零件 → 大地图会高亮它的合法目标格"
	_零件栏 = UiTheme.建盒(第二行, "零件栏", false, UiTheme.间距_小)
	_按钮组 = UiTheme.建盒(第二行, "按钮组", false, UiTheme.间距_小)
	var 招募键 := UiTheme.建按钮(_按钮组, "名册 / 招募 / 晋升", _点招募)
	招募键.name = "招募按钮"
	招募键.tooltip_text = "用招募券招机师、花希望晋升（Lv10 → 20 → 30）"
	var 编队键 := UiTheme.建按钮(_按钮组, "编队", _点编队)
	编队键.name = "编队按钮"
	编队键.tooltip_text = "摆前排 / 后排的出击位"
	var 牌库键 := UiTheme.建按钮(_按钮组, "战术牌库", _点牌库)
	牌库键.name = "战术牌库按钮"
	牌库键.tooltip_text = "看看已经并进牌库的战术牌"
	var 存档键 := UiTheme.建按钮(_按钮组, "保存并返回主菜单", _点保存回菜单)
	存档键.name = "保存回菜单按钮"
	存档键.tooltip_text = "存下这一局然后回主菜单（存档只走 SaveService）"

	_说明行 = UiTheme.建说明(列, "还没有进行中的局 —— 回主菜单开一局。", UiTheme.字号_小, UiTheme.弱文字)
	_说明行.name = "顶栏说明"

# ==========================================================================================
# 动态列表
# ==========================================================================================

func _建藏品栏(d: Dictionary) -> void:
	_清空(_藏品栏)
	var 藏品: Array = d.get("藏品") if d.get("藏品") is Array else []
	if 藏品.is_empty():
		UiTheme.建标签(_藏品栏, "（空）", UiTheme.字号_小, UiTheme.弱文字)
		return
	for id in 藏品:
		var 键 := UiTheme.文本(id)
		var 名 := RelicSystem.名(键)
		var l := UiTheme.建标签(_藏品栏, "【%s】" % 名, UiTheme.字号_小, UiTheme.高亮)
		l.tooltip_text = "%s\n%s" % [名, RelicSystem.说明(键)]

func _建零件栏(d: Dictionary) -> void:
	_清空(_零件栏)
	var 零件: Array = d.get("零件") if d.get("零件") is Array else []
	if 零件.is_empty():
		UiTheme.建标签(_零件栏, "（空）", UiTheme.字号_小, UiTheme.弱文字)
		return
	var 状态: RunState = session.run_state
	for i in 零件.size():
		var 件: Variant = 零件[i]
		if not (件 is Dictionary):
			continue
		var 键 := PartSystem.part_key(件)
		var 信息 := PartSystem.part_info(键)
		var 名 := str(信息.get("名", 键))
		var 次数 := UiTheme.文本((件 as Dictionary).get("uses", "—"))
		var 能用 := bool(信息.get("用", false))
		var 目标: Array = []
		if 状态 != null and 能用:
			目标 = PartSystem.part_targets(状态, 键)
		var 标签 := "%s ×%s" % [名, 次数] if 能用 else "%s（用不了）" % 名
		var b := UiTheme.建按钮(_零件栏, 标签, _点零件.bind(i, 键, 目标))
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.disabled = not 能用
		b.tooltip_text = "%s\n%s\n这一版能点 %d 格" % [名, str(信息.get("说明", 信息.get("效果", ""))), 目标.size()]

# ==========================================================================================
# 按钮回调（一律只调 GameSession 的命令方法；开窗 / 换屏走信号）
# ==========================================================================================

func _点招募() -> void:
	请求弹窗.emit("招募", {})

func _点编队() -> void:
	请求屏幕.emit("formation")

func _点牌库() -> void:
	请求弹窗.emit("战术牌库", {})

func _点保存回菜单() -> void:
	if session == null:
		return
	if session.run_state != null:
		session.save_current_run()
	session.return_to_menu()

func _点零件(下标: int, 键: String, 目标: Array) -> void:
	零件瞄准.emit(下标, 键, 目标)

# ==========================================================================================
# 小工具
# ==========================================================================================

func _清空局态() -> void:
	_层数.text = "没有进行中的局"
	_推进剂.text = "推进剂 —"
	_源碳.text = "源碳 —"
	_希望.text = "希望 —"
	_基地耐久.text = "基地耐久 —"
	_部队等级.text = "部队 —"
	_出击上限.text = "出击 —"
	_清空(_藏品栏)
	_清空(_零件栏)
	UiTheme.建标签(_藏品栏, "（空）", UiTheme.字号_小, UiTheme.弱文字)
	UiTheme.建标签(_零件栏, "（空）", UiTheme.字号_小, UiTheme.弱文字)
	_说明行.text = "还没有进行中的局 —— 回主菜单开一局。"

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()

## 推进剂的「明细」提示（上限 = 最短路 + 余量 + 层修正 + 零件 + 小径，全部来自内核的账）。
func _推进剂明细文字(d: Dictionary) -> String:
	var 账: Variant = d.get("推进剂明细")
	if not (账 is Dictionary) or (账 as Dictionary).is_empty():
		return "推进剂 %s / %s（还没有大地图，账算不出来）" % [UiTheme.文本(d.get("推进剂", 0)), UiTheme.文本(d.get("推进剂上限", 0))]
	var a: Dictionary = 账
	return "推进剂 %s / %s\n该图最短路 %s + 余量 %s + 层修正 %s + 零件 %s + 小径 %s = 上限 %s" % [
		UiTheme.文本(d.get("推进剂", 0)), UiTheme.文本(d.get("推进剂上限", 0)),
		UiTheme.文本(a.get("最短路", 0)), UiTheme.文本(a.get("余量", 0)), UiTheme.文本(a.get("层修正", 0)),
		UiTheme.文本(a.get("零件", 0)), UiTheme.文本(a.get("小径", 0)), UiTheme.文本(a.get("上限", 0))]
