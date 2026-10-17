## 3 选 1 战术牌构筑弹窗（Stage M4-2）。
##
## 候选来源：`run_state.pending_card_picks`（内核 `DeckBuilder.offer_cards` / 门面
## `GameSession.refresh_card_offers(机体键)` 写下的那 3 张），每张的详情用
## **纯读**的 `DeckBuilder.找到(id)` 取（`Db.catalog.card`），表现层不自己编候选。
##
## 每张显示：层级 / 归属 / 气势消耗 / 冷却 / 触发条件 / 效果说明。
## 点一张即 `GameSession.pick_tactical_card(card_id)`（并入牌库 + 清空待选）。
class_name PickCardView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _说明: Label
var _候选列表: VBoxContainer
var _结果: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _候选列表 == null:
		return
	var s: RunState = session.run_state if session != null else null
	if s == null:
		_说明.text = "还没有进行中的局。"
		_清空(_候选列表)
		return
	var 候选: Array = s.pending_card_picks
	_说明.text = "牌库现在 %s 张。下面 %s 张候选里选 1 张并进牌库；候选从「职业 + 势力 + 角色」三层池里剔掉已有牌后各取一张（纯函数、不掷随机数）。" % [
		UiTheme.文本(s.tactical_deck.size()), UiTheme.文本(候选.size())]
	_清空(_候选列表)
	if 候选.is_empty():
		UiTheme.建标签(_候选列表, "现在没有待选的战术牌。招募一台新机师、或者晋升一台上 Lv20 / Lv30，都会给一批候选。", UiTheme.字号_正文, UiTheme.次要文字)
		UiTheme.建按钮(_候选列表, "现在就生成一批候选", _点生成).tooltip_text = "调 GameSession.refresh_card_offers()（内部是纯函数式的候选枚举）"
		_结果.text = ""
		return
	for id in 候选:
		_建候选卡(UiTheme.文本(id))
	_结果.text = _结果文字()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "选牌面板"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "选牌上下列", true, UiTheme.间距_小)
	UiTheme.占满留边(列)
	UiTheme.建标签(列, "选 1 张并进战术牌库", UiTheme.字号_小节, UiTheme.高亮)
	_说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	_候选列表 = UiTheme.建滚动(列, "候选列表", 380.0)
	_结果 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)

func _建候选卡(id: String) -> void:
	var c := DeckBuilder.找到(id)
	var 卡 := UiTheme.建面板(_候选列表, "候选卡_" + id, UiTheme.卡片底, UiTheme.边框)
	卡.clip_contents = true
	var 列 := UiTheme.建盒(卡, "候选卡上下列_" + id, true, 2)
	if c.is_empty():
		UiTheme.建标签(列, "【%s】（数据表里找不到这张牌）" % id, UiTheme.字号_正文, UiTheme.负面)
		return
	var 头 := UiTheme.建标签(列, "【%s】%s · %s" % [UiTheme.文本(c.get("名", id)), UiTheme.文本(c.get("层级", "")),
		UiTheme.文本(c.get("归属", ""))], UiTheme.字号_小节, UiTheme.高亮)
	头.tooltip_text = "层级：%s / 归属：%s（候选按「职业 → 势力 → 角色」各取一张）" % [
		UiTheme.文本(c.get("层级", "")), UiTheme.文本(c.get("归属", ""))]
	UiTheme.建标签(列, "气势消耗 %s（回气 %s） · 冷却 %s 回合 · 限次 %s" % [
		UiTheme.文本(c.get("耗气", 0)), UiTheme.文本(c.get("回气", 0)),
		UiTheme.文本(c.get("冷却", 0)), UiTheme.文本(c.get("限次", "不限"))], UiTheme.字号_小, UiTheme.次要文字)
	UiTheme.建标签(列, "触发条件：%s（%s）" % [UiTheme.文本(c.get("触发说明", "—")), UiTheme.文本(c.get("触发条件码", "—"))],
		UiTheme.字号_小, UiTheme.推进剂色)
	UiTheme.建说明(列, "效果：%s" % UiTheme.文本(c.get("效果说明", "—")), UiTheme.字号_小, UiTheme.主文字)
	var 选 := UiTheme.建按钮(列, "选这张", _点选.bind(id))
	选.tooltip_text = "并进战术牌库，之后在战斗手牌里出现"
	# ★ Mouse Over：整张牌的说明（门面 `card_hover_text` 的原文）
	var 悬停 := session.card_hover_text(c) if session != null else ""
	HoverTooltip.bind(选, 悬停, "战术牌")
	HoverTooltip.bind(卡, 悬停, "战术牌")
	HoverTooltip.bind(头, 悬停, "战术牌")

## 点「选这张」：并进牌库之后把「招募券闭环」接上。
## ★ 重画一律**不做**：`pick_tactical_card()` 内部会 `_emit()` → `boot.route()` → `弹窗层.refresh()`
##   → 要么原地 `refresh()` 这个视图（还有待选牌）、要么换成下一个弹窗（下面的两条分支）。
func _点选(id: String) -> void:
	if session == null:
		return
	if not session.pick_tactical_card(id):
		return
	var s: RunState = session.run_state
	if s == null or not s.pending_card_picks.is_empty():
		return
	# ★ 修复「招募券要求做出决定才能进入下一个选择」（2026-10-16 作者试玩反馈）——
	#   三选一选完之后把闭环接上（都在**视图层**发信号，不动门面默认值）：
	#   ① 手上还有没决定的招募券 → 立刻回【招募】页面继续做决定（招募一台，或「放弃此券」）；
	#   ② 券都决定完、而且这一局一格都还没走过（刚开局招完人）→ 送去【编队】屏。
	#   两个信号都由 `ModalLayer._接信号` → `boot` 转发（`请求弹窗` / `请求屏幕`）。
	if session.ticket_count() > 0:
		请求弹窗.emit("招募", {})
		return
	if session.screen == "map" and session.还没走过格():
		请求屏幕.emit("formation")

func _点生成() -> void:
	if session == null:
		return
	session.refresh_card_offers()
	refresh()

# ==========================================================================================
# 小工具
# ==========================================================================================

func _结果文字() -> String:
	if session == null:
		return ""
	var 末 := session.last
	if str(末.get("行动", "")) == "选战术牌":
		return "选好了：【%s】已经并进牌库（牌库 %s → %s 张）。" % [str(末.get("牌", "")),
			UiTheme.文本(末.get("牌库前", 0)), UiTheme.文本(末.get("牌库后", 0))]
	if not session.当前动作错误().is_empty():
		return "上一次没选成：%s" % UiTheme.文本(session.当前动作错误())
	return ""

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
