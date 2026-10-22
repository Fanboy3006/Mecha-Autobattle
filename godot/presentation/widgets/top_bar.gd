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
## ★ 2026-10-18：顶栏那 4 个功能按钮要按「大地图自由态」逐个置灰 —— 所以留下引用。
var _招募键: Button
var _编队键: Button
var _牌库键: Button
var _存档键: Button
## ★ COL-4b：QTE 结果模式的循环切换键（只在战斗里可点）。
var _QTE键: Button

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
	_刷按钮可用性(d)

## ★ 2026-10-18（作者试玩反馈第 3 条）：**锁死顶栏在非自由态下的跳转**。
##
## 「大地图自由态」的定义（与门面 / boot 的路由同一套口径，不另立第二套）：
##   `session.screen == "map"` 且 不在战斗里 且 没有战前编队确认 且 没有弹窗。
## 三个按钮的口径：
##   · `招募按钮` —— 只在自由态可点；文案跟着券数走（有券 `招募(N)`、没券 `名册/晋升`）；
##   · `编队按钮` —— 只在自由态、或**普通编队态**（`formation` 且不是战前确认）可点；
##   · `保存回菜单按钮` —— 主菜单 / 选分队（`menu` / `squad`）下置灰。
## 其余情况（战斗 / 结算 / 战前编队确认 / 有弹窗）一律 `disabled = true`。
func _刷按钮可用性(d: Dictionary) -> void:
	if session == null:
		return
	var 屏 := str(session.screen)
	var 自由态: bool = 屏 == "map" and not session.in_battle() \
		and not session.pending_battle_confirm and session.modal.is_empty()
	var 普通编队态: bool = 屏 == "formation" and not session.pending_battle_confirm \
		and not session.in_battle() and session.modal.is_empty()
	if _招募键 != null:
		var 券 := int(d.get("券数", 0))
		_招募键.text = "招募(%d)" % 券 if 券 > 0 else "名册/晋升"
		_招募键.disabled = not 自由态
		_招募键.tooltip_text = "用招募券招机师、花希望晋升（Lv10 → 20 → 30）%s" % \
			("" if 自由态 else "（现在不在大地图上：打完 / 结算完 / 关掉弹窗才能点）")
	if _编队键 != null:
		_编队键.disabled = not (自由态 or 普通编队态)
		_编队键.tooltip_text = "摆前排 / 后排的出击位%s" % \
			("" if (自由态 or 普通编队态) else "（战斗中 / 结算屏 / 战前确认时不许切去编队屏）")
	if _牌库键 != null:
		_牌库键.disabled = not 自由态
	if _QTE键 != null:
		var 模式 := str(d.get("QTE模式", "manual"))
		_QTE键.text = "QTE：%s" % GameSession.QTE模式文(模式)
		_QTE键.disabled = not session.in_battle()
		_QTE键.tooltip_text = "%s%s" % [
			"循环切换 QTE 结果：手动选择 → 固定完美 → 固定成功 → 固定失手 → 随机",
			"" if session.in_battle() else "（只在战斗里能点）"]
	if _存档键 != null:
		_存档键.disabled = 屏 == "menu" or 屏 == "squad"

# ==========================================================================================
# 建节点树（只在 setup 里调一次）
# ==========================================================================================

func _build() -> void:
	name = "顶栏"
	UiTheme.顶部一条(self, UiTheme.顶栏高)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# ★ 高度纪律：`顶栏底` 的**上下内边距收到 4**、行间距收到 3 ——
	#   原来 10/8 的组合让它的最小高度变成 107px，比 `UiTheme.顶栏高`(104) 还高 3px，
	#   于是顶栏往下溢出、把屏幕容器顶部的标题压掉。现在最小高度 ≤ 96 ≤ 104。
	var 底样式 := UiTheme.底样式(UiTheme.面板底, UiTheme.边框)
	底样式.content_margin_top = 4
	底样式.content_margin_bottom = 4
	底样式.content_margin_left = 10
	底样式.content_margin_right = 10
	var 底 := PanelContainer.new()
	底.name = "顶栏底"
	底.clip_contents = true
	底.add_theme_stylebox_override("panel", 底样式)
	self.add_child(底)
	UiTheme.占满(底)
	var 列 := UiTheme.建盒(底, "顶栏上下列", true, 3)

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

	# ★ 宽度纪律：藏品栏 / 零件栏都放进**横向只显示不滚**的 `ScrollContainer` 里
	#   （`SCROLL_MODE_SHOW_NEVER` 对父盒子的最小宽度贡献是 0），
	#   于是右边那 4 个功能按钮**永远**落在 x ≤ 1270 以内，不会被挤出右边界。
	var 第二行 := UiTheme.建盒(列, "第二行", false, UiTheme.间距_大)
	var 藏品标题 := UiTheme.建标签(第二行, "藏品：", UiTheme.字号_小, UiTheme.次要文字)
	藏品标题.tooltip_text = "本局已经到手的藏品（黑市 / 精英 / Boss / 遗迹发的）"
	_藏品栏 = _建窄栏(第二行, "藏品滚动", "藏品栏")
	var 零件标题 := UiTheme.建标签(第二行, "零件：", UiTheme.字号_小, UiTheme.次要文字)
	零件标题.tooltip_text = "点一件主动零件 → 大地图会高亮它的合法目标格"
	_零件栏 = _建窄栏(第二行, "零件滚动", "零件栏")
	_按钮组 = UiTheme.建盒(第二行, "按钮组", false, UiTheme.间距_小)
	_按钮组.size_flags_horizontal = Control.SIZE_SHRINK_END
	var 招募键 := UiTheme.建按钮(_按钮组, "名册/晋升", _点招募)
	招募键.name = "招募按钮"
	招募键.tooltip_text = "用招募券招机师、花希望晋升（Lv10 → 20 → 30）"
	_招募键 = 招募键
	var 编队键 := UiTheme.建按钮(_按钮组, "编队", _点编队)
	编队键.name = "编队按钮"
	编队键.tooltip_text = "摆前排 / 后排的出击位"
	_编队键 = 编队键
	var 牌库键 := UiTheme.建按钮(_按钮组, "战术牌库", _点牌库)
	牌库键.name = "战术牌库按钮"
	牌库键.tooltip_text = "看看已经并进牌库的战术牌"
	_牌库键 = 牌库键
	# ★ COL-4b：QTE 结果模式（顶栏这颗紧凑按钮循环切；战斗里才可点）。
	var QTE键 := UiTheme.建按钮(_按钮组, "QTE：手动选择", _点QTE模式)
	QTE键.name = "QTE模式按钮"
	QTE键.add_theme_font_size_override("font_size", UiTheme.字号_小)
	QTE键.tooltip_text = "循环切换 QTE 结果：手动选择 → 固定完美 → 固定成功 → 固定失手 → 随机"
	_QTE键 = QTE键
	var 存档键 := UiTheme.建按钮(_按钮组, "存盘回菜单", _点保存回菜单)
	存档键.name = "保存回菜单按钮"
	存档键.tooltip_text = "存下这一局然后回主菜单（存档只走 SaveService）"
	_存档键 = 存档键

	_说明行 = UiTheme.建说明(列, "还没有进行中的局 —— 回主菜单开一局。", UiTheme.字号_小, UiTheme.弱文字)
	_说明行.name = "顶栏说明"

## 一条「横向只显示不滚、纵向关掉」的窄栏：对父盒子的最小宽度贡献 = 0（宽度由父盒子分配）。
func _建窄栏(父: Node, 滚动名: String, 盒名: String) -> HBoxContainer:
	var 滚 := ScrollContainer.new()
	滚.name = 滚动名
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	滚.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	滚.clip_contents = true
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	父.add_child(滚)
	var 盒 := UiTheme.建盒(滚, 盒名, false, UiTheme.间距_小)
	盒.clip_contents = true
	盒.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return 盒

# ==========================================================================================
# 动态列表
# ==========================================================================================

## 藏品栏：每件藏品一个标签 + **标准悬停说明层**（★ UX-1 第 5 项，2026-10-19）。
##
## 作者试玩反馈第 5 条原文：「鼠标 hover 藏品需要显示藏品细节」（他在藏品栏点了 4 次没反应）。
## 做法：文本与说明**全部来自门面** `relic_hover_text()`（表现层不自己拼数值），
##   `HoverTooltip.bind()` 挂上统一的悬停层，并把 `mouse_filter` 设成 `STOP`
##   （`Label` 默认是 `IGNORE`，不设的话 `mouse_entered` 永远不发 → 悬停框弹不出来）。
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
		l.name = "藏品_%s" % 键
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var 悬停 := session.relic_hover_text(键) if session != null else "%s\n%s" % [名, RelicSystem.说明(键)]
		HoverTooltip.bind(l, 悬停, "藏品")

## 零件栏：三态画法（★ UX-1 第 4 项，2026-10-19）。
##
## 作者试玩反馈第 1 条原文：「现在零件点击了无法使用」。三个根因在这里各修一处：
##   ① **常驻被动**（`用 == false`）从前画成灰按钮 +「（用不了）」→ 现在画成**常驻被动徽章**，
##      不再假装它是一个坏掉的按钮；
##   ② **主动零件但此刻用不了**（不在大地图 / 次数用尽 / 推进剂不足 / 周围没有合法目标格）→ 按钮
##      `disabled = true`，并在悬停里写清**为什么**（`part_can_use_now().why` 原文），玩家不用点就知道怎么回事；
##   ③ **能用的主动零件** → 按钮亮起，点它发 `零件瞄准`，大地图随即显示金色引导横幅。
## 说明文本一律来自门面 `part_hover_text()` / `part_can_use_now()`，表现层一个数都不算。
##
## ★ 任务单 PART-3（黑流树海原版对齐）在本函数里落三件事：
##   · **自然物**（血蕈 `bloodcap` / 浪花 `wave`）的徽章上直接写出**实时估价**
##     （`%s(估价%d) ·被动`，估价读数来自门面 `part_can_use_now().sell`，表现层一个数都不算）；
##   · **概念体**（河谷祭祈 `rite`）只写 `%s ·被动`，不再当成一件坏掉的按钮；
##   · 两种徽章都保留 `·被动` 这个子串（版面门禁 9c 认它），主动零件在 `ok == false` 时一律置灰。
func _建零件栏(d: Dictionary) -> void:
	_清空(_零件栏)
	var 零件: Array = d.get("零件") if d.get("零件") is Array else []
	if 零件.is_empty():
		UiTheme.建标签(_零件栏, "（空）", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in 零件.size():
		var 件: Variant = 零件[i]
		if not (件 is Dictionary):
			continue
		var 状 := session.part_can_use_now(i) if session != null else {}
		var 键 := str(状.get("key", PartSystem.part_key(件)))
		var 名 := str(状.get("name", PartSystem.part_info(键).get("名", 键)))
		var 类 := str(状.get("类", PartSystem.part_info(键).get("类", "")))
		var 悬停 := session.part_hover_text(i) if session != null else 名
		var 被动 := bool(状.get("passive", false))
		if 被动:
			# 常驻被动：一个**徽章**（Label），不是按钮 —— 样式上就与「可点的主动零件」分开。
			# ★ PART-3：自然物的实时估价直接写在徽章上（估价随战斗 / 移动变动，黑市按它收）。
			var 徽文 := "%s ·被动" % 名
			if 类 == "自然物":
				徽文 = "%s(估价%d) ·被动" % [名, int(状.get("sell", 0))]
			var 徽 := UiTheme.建标签(_零件栏, 徽文, UiTheme.字号_小, UiTheme.次要文字)
			徽.name = "零件徽章_%d" % i
			徽.mouse_filter = Control.MOUSE_FILTER_STOP
			HoverTooltip.bind(徽, 悬停, "零件")
			continue
		var 能用 := bool(状.get("ok", false))
		var 左 := int(状.get("left", -1))
		var 次数 := "常驻" if 左 < 0 else UiTheme.文本(左)
		var 目标: Array = 状.get("targets") if 状.get("targets") is Array else []
		# ★ PART-3：一键零件（小八界）不用选落点 —— 文案上先说明，点下去由大地图直接发动。
		var 钮文 := "%s ×%s" % [名, 次数]
		if bool(状.get("instant", false)):
			钮文 = "%s ×%s（一键发动）" % [名, 次数]
		# 能用的亮起可点；用不了的**仍然是一个按钮（置灰）**，悬停里写清为什么。
		# ★ `ok == false` 的判据全在门面（推进剂不足 / 次数用尽 / 不在大地图 / 没有目标格），
		#   这里的 `disabled` 只是把门面那句话**画出来**，原因原文在 `part_hover_text()` 的末行。
		var b := UiTheme.建按钮(_零件栏, 钮文, _点零件.bind(i, 键, 目标))
		b.name = "零件按钮_%d" % i
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		if 能用:
			b.add_theme_color_override("font_color", UiTheme.高亮)
		else:
			b.disabled = true
		HoverTooltip.bind(b, 悬停, "零件")

# ==========================================================================================
# 按钮回调（一律只调 GameSession 的命令方法；开窗 / 换屏走信号）
# ==========================================================================================

func _点招募() -> void:
	请求弹窗.emit("招募", {})

func _点编队() -> void:
	请求屏幕.emit("formation")

func _点牌库() -> void:
	请求弹窗.emit("战术牌库", {})

## ★ COL-4b：循环切换 QTE 结果模式（手动选择 → 固定完美 → 固定成功 → 固定失手 → 随机）。
func _点QTE模式() -> void:
	if session == null or not session.in_battle():
		return
	session.cycle_qte_mode()
	refresh()

func _点保存回菜单() -> void:
	if session == null:
		return
	if session.run_state != null:
		session.save_current_run()
	session.return_to_menu()

## 点一件零件 → 发 `零件瞄准`，由 boot 转给大地图。
##
## ★ 任务单 PART-3：不用选落点的一键零件（小八界 `bagua`，门面 `part_can_use_now().instant == true`）
##   也发**同一个信号** —— 由大地图的 `瞄准零件()` 统一判「一键发动」，那里才有落点结算
##   （`_进入脚下()`）：从顶栏点、从地图调，走的是同一条结算路。
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
	# 没有局 = 更不自由：三个跳转按钮一律置灰（`_刷按钮可用性()` 那条路走不到这里）。
	for b in [_招募键, _编队键, _牌库键, _QTE键]:
		if b != null:
			(b as Button).disabled = true

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
