## 休整（Stage M4-2）。
##
## 内核三选一（互斥）：`耐久` 作战耐久 +2 / `晋升` 下次晋升 −1 希望 / `推进剂` 推进剂 +2；
## **无论选哪一项都回血**（比例由内核的 `休整回血` 给，表现层不算）。
## 动作只调 `GameSession.resolve_rest(选项)`；结果文字只读门面返回的字典 / `current_node_result()`。
class_name RestView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _说明: Label
var _选项按钮组: HBoxContainer
var _休整结果: VBoxContainer
## ★ 2026-10-18：这一格是不是已经结算过（结算成功后置位；刷新时据此藏掉选项按钮）。
var _已结算: bool = false

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _选项按钮组 == null:
		return
	var s: RunState = null
	if session != null:
		s = session.run_state
	if s == null:
		_说明.text = "还没有进行中的局。"
		_清空(_休整结果)
		return
	var 回血比 := _回血比例文字()
	_说明.text = "现在：作战耐久 %s / %s · 推进剂 %s / %s · 希望 %s。\n三选一互斥；不管选哪个，全队都会回血（比例 %s）。" % [
		UiTheme.文本(s.base_hp), UiTheme.文本(s.base_max_hp), UiTheme.文本(s.propellant),
		UiTheme.文本(s.propellant_max), UiTheme.文本(s.hope), 回血比]
	_清空(_休整结果)
	var r := session.current_node_result()
	if str(r.get("节点", "")) != "休整":
		UiTheme.建标签(_休整结果, "在上面选一项：", UiTheme.字号_正文, UiTheme.次要文字)
		return
	_已结算 = true
	# ★ 2026-10-18：这一格结算完就**没有第二次**了 —— 选项按钮藏起来（门面那一层也会拒绝第二次）。
	# ★ UX-1 第 6 项：顺手**置灰**（藏起来 + 置灰，两条腿都不许它被第二次点中）。
	_隐藏选项按钮()
	_填结果(r)

## 休整回血比例的文字（**纯读** `战斗结构.HP继承.休整回血比例`；读不到就写「内核默认」）。
## 返回 String 而不是 Variant：`inference_on_variant` 在这个工程里是**当错误报的**。
func _回血比例文字() -> String:
	var 战斗结构: Variant = Db.T.get("战斗结构")
	if 战斗结构 is Dictionary:
		var 继承: Variant = (战斗结构 as Dictionary).get("HP继承")
		if 继承 is Dictionary:
			var 比例: Variant = (继承 as Dictionary).get("休整回血比例")
			if 比例 != null:
				return UiTheme.文本(比例)
	return "内核默认"

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "休整面板"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "休整上下列", true, UiTheme.间距)
	UiTheme.占满留边(列)
	UiTheme.建标签(列, "休整：坐下来修一修", UiTheme.字号_小节, UiTheme.高亮)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	_选项按钮组 = UiTheme.建盒(列, "选项按钮组", false, UiTheme.间距_小)
	var b1 := UiTheme.建按钮(_选项按钮组, "耐久 +2", _点选.bind("耐久"))
	b1.tooltip_text = "作战耐久（基地那一格血）+2 —— 耐久归零就输了"
	var b2 := UiTheme.建按钮(_选项按钮组, "下次晋升 −1 希望", _点选.bind("晋升"))
	b2.tooltip_text = "让下一次晋升便宜 1 点希望（只用一次）"
	var b3 := UiTheme.建按钮(_选项按钮组, "推进剂 +2", _点选.bind("推进剂"))
	b3.tooltip_text = "这一层多走两步（上限 +1 之内）"
	_休整结果 = UiTheme.建滚动(列, "休整结果", 260.0)

## ★ 2026-10-18（作者试玩反馈第 3 条）：休整是**单次幂等**的 ——
##   点一下结算成功就**立刻关窗回大地图**（不再留在面板上，于是也不可能连点 6 次刷属性）。
##   选的是「晋升减价」时，那一条已经在门面 `last` / 日志里写清了（面板关掉也查得到）。
## ★ UX-1 第 6 项（2026-10-19）补两道：
##   ① 结算成功之后把三个动作按钮**置灰**（不只是藏起来）—— 自动化 / 键盘走到也点不出第二次；
##   ② 本屏自己记的 `_已结算` 先兜一道：第二次点击直接静默返回，**不再往门面送一条报错**。
func _点选(choice: String) -> void:
	if session == null:
		return
	if _已结算:
		return
	var r := session.resolve_rest(choice)
	if not bool(r.get("ok", false)):
		# 被门面拦下（例如「当前节点已结算完毕」）→ 留在面板上如实显示原因，不关窗。
		refresh()
		return
	_已结算 = true
	_隐藏选项按钮()
	请求关闭弹窗.emit()

func _隐藏选项按钮() -> void:
	if _选项按钮组 == null:
		return
	_选项按钮组.visible = false
	for c in _选项按钮组.get_children():
		if c is Button:
			(c as Button).disabled = true

## 结果页那个「回大地图」按钮：只关弹窗，不再动任何状态。
func _点关闭结果页() -> void:
	请求关闭弹窗.emit()

# ==========================================================================================
# 结果文字（数值一律从内核返回的字典读）
# ==========================================================================================

func _填结果(r: Dictionary) -> void:
	var 前: Dictionary = r.get("前", {}) if r.get("前") is Dictionary else {}
	var 后: Dictionary = r.get("后", {}) if r.get("后") is Dictionary else {}
	UiTheme.建标签(_休整结果, "选了：%s" % UiTheme.文本(r.get("选", "")), UiTheme.字号_小节, UiTheme.正面)
	var 回血: Dictionary = r.get("回血", {}) if r.get("回血") is Dictionary else {}
	UiTheme.建标签(_休整结果, "全队回血：%s 台，比例 %s" % [UiTheme.文本(回血.get("台数", 0)),
		UiTheme.文本(回血.get("回复比例", 0.0))], UiTheme.字号_正文, UiTheme.正面)
	UiTheme.建标签(_休整结果, "作战耐久 %s → %s" % [UiTheme.文本(前.get("耐久", 0)), UiTheme.文本(后.get("耐久", 0))],
		UiTheme.字号_小, UiTheme.耐久色)
	UiTheme.建标签(_休整结果, "推进剂 %s → %s" % [UiTheme.文本(前.get("推进剂", 0)), UiTheme.文本(后.get("推进剂", 0))],
		UiTheme.字号_小, UiTheme.推进剂色)
	var 减价文 := ""
	if bool(r.get("减价", false)):
		减价文 = "（下一次晋升 −1 希望）"
	UiTheme.建标签(_休整结果, "希望 %s → %s%s" % [UiTheme.文本(前.get("希望", 0)), UiTheme.文本(后.get("希望", 0)), 减价文],
		UiTheme.字号_小, UiTheme.希望色)
	UiTheme.建按钮(_休整结果, "休整好了，回大地图", _点关闭结果页)

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
