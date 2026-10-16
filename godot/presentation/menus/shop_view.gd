## 黑市（Stage M4-2）。
##
## 单向数据流（全部**纯读**目录 + 门面命令）：
##   货架 = `NodeResolver.黑市货(run_state)`；价格 = `NodeResolver.黑市价(run_state, id)`
##          （`f1` 藏品打 7 折 —— 这里把「原价 → 折后价」写出来，让打折看得出来）；
##   刷新 = `NodeResolver.黑市刷新价` / `黑市刷新次数`（显示刷新价与已刷新次数）；
##   卖零件 = `PartSystem.sell_price(件)`（自然物按当前估价，加工品 / 概念体 6 折）。
## 动作只调 `GameSession`：`buy_from_shop` / `refresh_shop` / `sell_part_in_shop` / `leave_shop`。
class_name ShopView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _说明: Label
var _货架: VBoxContainer
var _刷新栏: HBoxContainer
var _零件区: VBoxContainer
var _结果: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _货架 == null:
		return
	var s: RunState = session.run_state if session != null else null
	if s == null:
		_说明.text = "还没有进行中的局。"
		_清空(_货架)
		_清空(_刷新栏)
		_清空(_零件区)
		return
	var 打折 := s.relics.has(PartSystem.打折藏品)
	var 折文 := ""
	if 打折:
		折文 = "　★ 手上有【%s】：黑市买价打 7 折" % RelicSystem.名(PartSystem.打折藏品)
	_说明.text = "源碳 %s · 藏品 %s 件%s。买藏品花源碳；刷新库存要源碳（次数越多越花钱）；用不上的零件可以在这里卖掉。" % [
		UiTheme.文本(s.carbon), UiTheme.文本(s.relics.size()), 折文]
	_建货架(s, 打折)
	_建刷新栏(s)
	_建零件区(s)
	_结果.text = _结果文字()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "黑市面板"
	UiTheme.占满(self)
	var 列 := UiTheme.建盒(self, "黑市上下列", true, UiTheme.间距_小)
	UiTheme.建标签(列, "黑市", UiTheme.字号_小节, UiTheme.高亮)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	_货架 = UiTheme.建滚动(列, "货架", 250.0)
	_刷新栏 = UiTheme.建盒(列, "刷新栏", false, UiTheme.间距_小)
	UiTheme.建标签(列, "手上的零件（卖掉换源碳）", UiTheme.字号_小节, UiTheme.高亮)
	_零件区 = UiTheme.建滚动(列, "零件区", 150.0)
	var 底部 := UiTheme.建盒(列, "黑市底部", false, UiTheme.间距_小)
	var 走 := UiTheme.建按钮(底部, "离开黑市", _点离开)
	走.name = "离开按钮"
	走.tooltip_text = "离开这一格（这一格就算清掉了）"
	_结果 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)

# ==========================================================================================
# 货架
# ==========================================================================================

func _建货架(s: RunState, 打折: bool) -> void:
	_清空(_货架)
	var 货: Array = NodeResolver.黑市货(s)
	if 货.is_empty():
		UiTheme.建标签(_货架, "货架空了（能抽的藏品都刷完 / 都买光了）。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for id in 货:
		var 键 := UiTheme.文本(id)
		var 名 := RelicSystem.名(键)
		var 价 := NodeResolver.黑市价(s, 键)
		var 卡 := UiTheme.建面板(_货架, "货_" + 键, UiTheme.卡片底, UiTheme.边框)
		var 行 := UiTheme.建盒(卡, "货行_" + 键, false, UiTheme.间距)
		var 左 := UiTheme.建盒(行, "货左_" + 键, true, 2)
		左.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var 件 := RelicSystem.件(键)
		UiTheme.建标签(左, "【%s】%s" % [名, UiTheme.文本(件.get("稀有", ""))], UiTheme.字号_正文, UiTheme.高亮)
		UiTheme.建说明(左, RelicSystem.说明(键), UiTheme.字号_小, UiTheme.次要文字)
		var 价文 := "黑市价 %d 源碳" % 价
		if 打折:
			var 原: Variant = Db.catalog.relic_prices().get(str(件.get("稀有", "")))
			价文 = "黑市价 %d 源碳（原价 %s → f1 藏品打 7 折）" % [价, UiTheme.文本(原)]
		var 价标签 := UiTheme.建标签(左, 价文, UiTheme.字号_小, UiTheme.源碳色 if s.carbon >= 价 else UiTheme.负面)
		价标签.tooltip_text = "买价 = round(基础价 × (有 f1 藏品 ? 0.7 : 1.0))，基础价按稀有度查「藏品价格」表"
		var 买 := UiTheme.建按钮(行, "买下", _点买.bind(键))
		买.disabled = s.carbon < 价
		if s.carbon >= 价:
			买.tooltip_text = "花 %d 源碳买下" % 价
		else:
			买.tooltip_text = "源碳不够：要 %d，只有 %d" % [价, s.carbon]

func _点买(id: String) -> void:
	if session == null:
		return
	session.buy_from_shop(id)

# ==========================================================================================
# 刷新栏
# ==========================================================================================

func _建刷新栏(s: RunState) -> void:
	_清空(_刷新栏)
	var 次 := NodeResolver.黑市刷新次数(s)
	var 价: Variant = NodeResolver.黑市刷新价(s)
	var 文 := "已刷新 %d 次" % 次
	if 价 == null:
		文 += " · 这一格已经刷新满了"
	else:
		文 += " · 下一次要 %d 源碳" % int(价)
	var l := UiTheme.建标签(_刷新栏, 文, UiTheme.字号_小, UiTheme.次要文字)
	l.tooltip_text = "刷新价 = 基价 + 次数 × 加价；刷新次数每一格黑市单独算，换层归零"
	var 按 := UiTheme.建按钮(_刷新栏, "刷新库存", _点刷新)
	按.disabled = 价 == null or s.carbon < int(价)
	if 按.disabled:
		按.tooltip_text = "刷不了（钱不够或者已经刷满）"
	else:
		按.tooltip_text = "花钱换一批货"

func _点刷新() -> void:
	if session == null:
		return
	session.refresh_shop()

# ==========================================================================================
# 零件区（卖）
# ==========================================================================================

func _建零件区(s: RunState) -> void:
	_清空(_零件区)
	if s.parts.is_empty():
		UiTheme.建标签(_零件区, "手上没有零件。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in s.parts.size():
		var 件: Variant = s.parts[i]
		if not (件 is Dictionary):
			continue
		var 键 := PartSystem.part_key(件)
		var 信息 := PartSystem.part_info(键)
		var 名 := str(信息.get("名", 键))
		var 价 := PartSystem.sell_price(件)
		var 行 := UiTheme.建盒(_零件区, "零件行_%d" % i, false, UiTheme.间距_小)
		var l := UiTheme.建标签(行, "%s ×%s · 卖价 %d 源碳" % [名, UiTheme.文本((件 as Dictionary).get("uses", "—")), 价],
			UiTheme.字号_小, UiTheme.主文字)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = "%s\n自然物按当前估价卖；加工品 / 概念体按 6 折卖" % str(信息.get("说明", 信息.get("效果", "")))
		UiTheme.建按钮(行, "卖掉", _点卖.bind(i))

func _点卖(下标: int) -> void:
	if session == null:
		return
	session.sell_part_in_shop(下标)

# ==========================================================================================
# 离开 + 即时反馈
# ==========================================================================================

func _点离开() -> void:
	if session == null:
		return
	session.leave_shop()
	请求关闭弹窗.emit()

func _结果文字() -> String:
	if session == null:
		return ""
	var 末 := session.last
	var 行动 := str(末.get("行动", ""))
	match 行动:
		"黑市买":
			return "买到【%s】，花 %s 源碳（源碳 %s → %s，藏品 %s 件）。" % [str(末.get("名", "")),
				UiTheme.文本(末.get("价", 0)), UiTheme.文本(末.get("源碳前", 0)),
				UiTheme.文本(末.get("源碳后", 0)), UiTheme.文本(末.get("藏品数", 0))]
		"黑市刷新":
			var 货数: int = (末.get("货") as Array).size() if 末.get("货") is Array else 0
			return "刷新了第 %s 次（花 %s 源碳），摆出 %s 件。" % [UiTheme.文本(末.get("次", 0)),
				UiTheme.文本(末.get("价", 0)), UiTheme.文本(货数)]
		"卖零件":
			return "卖掉【%s】+%s 源碳（源碳 %s → %s）。" % [str(末.get("名", "")), UiTheme.文本(末.get("价", 0)),
				UiTheme.文本(末.get("源碳前", 0)), UiTheme.文本(末.get("源碳后", 0))]
	if not session.errors.is_empty():
		return "上一次没做成：%s" % UiTheme.文本(session.errors[session.errors.size() - 1])
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
