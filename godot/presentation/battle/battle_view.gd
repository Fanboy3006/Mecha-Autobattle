## 职责：战斗屏协调层 —— 建三栏骨架、把各面板 / 演出子模块装起来、对测试与外部保留同名转发。
## 子模块：board_panel / hand_panel / hand_card_item / deck_sidebar / log_panel / drag_aim / battle_fx_player / battle_animation_layer。
## ★ 红线：面板之间只经本文件的一行转发通信；成员变量与控件引用都留在本文件（测试直接读）。
class_name BattleView
extends Control

const BoardPanel := preload("res://presentation/battle/board_panel.gd")
const HandPanel := preload("res://presentation/battle/hand_panel.gd")
const HandCardItem := preload("res://presentation/battle/hand_card_item.gd")
const DeckSidebar := preload("res://presentation/battle/deck_sidebar.gd")
const LogPanel := preload("res://presentation/battle/log_panel.gd")
const DragAim := preload("res://presentation/battle/drag_aim.gd")
const BattleFx := preload("res://presentation/battle/battle_fx_player.gd")
const 动画层 := preload("res://presentation/battle/battle_animation_layer.gd")
## ★ COL-4b：QTE 手动弹窗 + 感应牌库明细面板（覆盖层，纯表现）。
const 覆盖层 := preload("res://presentation/battle/colonial_overlay.gd")

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

const 我方 := "ally"
const 敌方 := "enemy"
const 卡宽 := 148.0
const 卡高 := 72.0
## 三栏宽度：左【未激活 / 冷却牌库】260 · 中【4×4 棋盘 + 手牌】670 · 右【详细战报】324。
const 左栏宽 := 260.0
const 中栏宽 := 670.0
const 右栏宽 := 324.0
## 中栏两段高度：上 `阵型区` 356 · 下 `手牌栏` 248（356 + 248 + 4 = 608 ≤ 可用区 616）。
const 阵型区高 := 356.0
const 手牌区高 := 248.0
## ★ 2026-10-21：中间那条「战线」分隔条（敌我前排紧贴它）。
const 战线条高 := 4.0
const 下半区高 := 248.0
const 战报滚动高 := 440.0
## ★ UI-3（2026-10-23）：左栏**不用滚动条**了 —— 这个常量只留给旧引用（不再参与建树）。
const 左库滚动高 := 470.0
## ★ UI-3：左栏 3 个分类子区块（组名 → 小标题）。
##   A 武器 / 大招 · B 精神 / 待入库 · C 公有 / 势力副牌库。
const 左库区块们 := ["武器大招", "精神待入库", "公有副牌库"]
const 左库区块题 := {
	"武器大招": "【武器 / 大招（冷却·出鞘·收起）】",
	"精神待入库": "【精神 / 待入库条件牌】",
	"公有副牌库": "【公有 / 势力副牌库】",
}
## ★ UI-3：一张 `左库卡` 的最小尺寸 —— 双列网格里**允许自由收缩**，长卡名不会撑宽。
const 左库卡最小 := Vector2(36.0, 20.0)
const 左库每块最多行 := 3
## ★ UI-3：三块合起来最多摆几行卡（双列）。8 行 × ~39px + 3 个区块标题 + 概览行 约 490px，
##   稳稳小于左栏列表的可用高度（1280×720 下 ~520px）—— 极限情况下也不撑开三栏主结构。
const 左库总行预算 := 8
## ★ UI-3：区块 C 最多几行「副牌库 / 待入库池」概览（公有待入库 · 太阳炉 · 连携 · 筹码）。
const 左库概览行数 := 4
const 手牌卡宽 := 138.0
## ★ UX-3：动作播报条的目标高度（紧凑单行 —— 绝不把底部手牌栏挤出 720 底边）。
const 播报条高 := 24.0
## ★ UX-5：串行演出队列的基础步长（秒/步）—— 作者反馈「0.7 秒内一锅粥闪完看不清」。
const STEP_DURATION: float = 0.5
## ★ UX-5：发牌流光 / 飞行卡背的时长（比一步略短，落地后还留一点时间看清手牌脉冲）。
const 发牌流光秒: float = 0.45
## ★ UX-5：攻击帧的前段时长（出手方前冲 + 指向箭头光束）；后段 = STEP_DURATION - 它。
const 出手前段秒: float = 0.15
## ★ UX-5：出手前冲距离（像素，规格 14）。
const 出手前冲像素: float = 14.0
## ★ UX-5：头顶飘字停留时长（规格 0.65 秒，让玩家看清数字）。
const 飘字停留秒: float = 0.65
## ★ UX-5：自动连播时两回之间的停顿（秒）。
const 连播停顿秒: float = 0.3
## ★ UX-5：打完最后一帧到切结算屏之间的停顿（秒）—— 让玩家看完最后一刀。
const 结算前停顿秒: float = 0.35
const 拖拽阈值 := 8.0
## 攻击型武器卡的瞄准线颜色（醒目的橙红）。
const 瞄准色_攻击 := Color(1.0, 0.42, 0.16)
## 维修型武器卡的瞄准线颜色（翠绿）。
const 瞄准色_维修 := Color(0.22, 0.94, 0.55)
## ★ UI-2：点友军牌时那句提示的停留秒数（操作结果栏那一行）。
const 友军提示停留秒 := 1.8
## 一排的高度预算（★ UI-1 起版面按比例分，这两个常量只留给旧引用 / 兼容）。
const 单机排高 := 58.0
const 单机卡宽 := 108.0
## ★ UI-1：上 / 下两排的纵向占比 —— 上排略高（三栏 + 两行字），下排稍矮；合起来填满手牌栏。
const 单机上排占比 := 1.08
const 单机下排占比 := 1.00
## ★ UI-1：一张单机卡的最小尺寸 —— **允许自由收缩**（36 宽），所以张数再多也不会挤出横向滚动条。
const 单机卡最小 := Vector2(36.0, 48.0)
## ★ UI-1：上排三栏的组名（`_分到组()` 用同一份字符串；标题写成 `【主武器】` / `【副武器】` / `【精神】`）。
const 单机三栏 := ["主武器", "副武器", "精神"]

var session: GameSession = null
var _阵型区: VBoxContainer
var _阵型提示: Label
var _战线分隔条: PanelContainer
var _我方列: VBoxContainer
var _敌方列: VBoxContainer
var _我方卡: Array = []
var _敌方卡: Array = []
var _护卫提示: Dictionary = {}
var _护卫线们: Array = []
var _已结算: bool = false
var _中栏: VBoxContainer
var _左牌库栏: PanelContainer
var _左牌库标题: Label
var _左牌库副标题: Label
var _左牌库太阳炉: Label
var _左牌库滚动: ScrollContainer
var _左牌库列表: VBoxContainer
var _左库区块节点: Dictionary = {}
var _左库网格们: Dictionary = {}
var _左库副牌概览: Array = []
var _下半区: VBoxContainer
var _手牌栏: PanelContainer
var _手牌顶行: HBoxContainer
var _手牌标题: Label
var _手牌气势: Label
var _操作结果: Label
var _新发牌提示: Label
var _专属排: PanelContainer
var _专属排标题: Label
var _专属排滚动: ScrollContainer
var _专属排列表: HBoxContainer
var _专属牌盒: Control
var _公有牌盒: Control
var _专属栏们: Dictionary = {}
var _公有排: PanelContainer
var _公有排标题: Label
var _公有排滚动: ScrollContainer
var _公有排列表: HBoxContainer
var _战报栏: PanelContainer
var _战报提示: Label
var _战报滚: VBoxContainer
var _推进按钮: Button
var _自动按钮: Button
var _结算按钮: Button
var _倍速按钮: Button
var _跳过演出按钮: Button
var _动作播报条: Label
var _战斗动画层 = null
var _已播日志数: int = 0
var _已播日志引用 = null
var _反馈文字: String = ""
var _反馈是好消息: bool = true
var _演出队列: Array = []
var _演出进行中: bool = false
var _演出跳过请求: bool = false
var _演出倍速: float = 1.0
var _自动连播开启: bool = false
var _已播帧数: int = 0
var _当前演出总帧数: int = 0
var _演出序号: int = 0
var _帧已耗时: float = 0.0
var _演出预热: bool = false
var _特效画布 = null
var _特效层 = null
var _拖拽区: String = ""
var _拖拽键: String = ""
var _拖拽上排: bool = true
var _拖拽牌: Dictionary = {}
var _拖拽按住点: Vector2 = Vector2.ZERO
var _拖拽当前点: Vector2 = Vector2.ZERO
var _拖拽已启动: bool = false
var _拖拽吸附方: String = ""
var _拖拽吸附位: int = -1
var _拖拽吸附键: String = ""
var _拖拽卡控件: Control = null
var _友军提示秒: float = 0.0
var _友军目标亮着: bool = false
# ★ COL-4b：手牌 QTE 手动弹窗（大招结算前弹「失手 / 成功 / 完美」）
var _QTE弹层: Control = null
var _QTE卡片名: Label = null
var _QTE待决: Dictionary = {}
var _QTE本次选择: String = ""
# ★ COL-4b：感应牌库明细面板（左栏「感应牌库」按钮点开）
var _感应面板: Control = null
var _感应面板标题: Label = null
var _感应面板列表: VBoxContainer = null
var _感应牌库按钮: Button = null

# ---------------- 本文件实现：建树骨架 + 高频小工具 + 演出协程 ----------------
func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

## 每次重画只读门面：先算援护 → 阵型 → 手牌 → 战报 → 演出，最后刷新控制按钮（实现在子模块）。
func refresh() -> void:
	if _手牌标题 == null:
		return
	if session == null:
		_阵型提示.visible = true
		_我方列.visible = false
		_敌方列.visible = false
		_手牌标题.text = "手牌栏：没有会话。"
		_手牌气势.text = ""
		_战报提示.text = "战报栏：没有会话。"
		_操作结果.text = ""
		_写作战画面空态()
		_清空(_战报滚)
		return
	var 在战斗 := not session.battle_ctx.is_empty()
	if not 在战斗:
		_已结算 = false
	elif session.battle_ctx.get("result") == null:
		_已结算 = false
	_阵型提示.visible = not 在战斗
	_我方列.visible = 在战斗
	_敌方列.visible = 在战斗
	_算援护(在战斗)
	_画阵型(在战斗)
	_画手牌(在战斗)
	_画战报(在战斗)
	_画战斗动画(在战斗)
	_推援护线()
	BoardPanel._推意图线(self, 在战斗)
	_刷新控制按钮()
	_操作结果.text = _反馈文字
	_操作结果.add_theme_color_override("font_color", UiTheme.正面 if _反馈是好消息 else UiTheme.负面)

func _build() -> void:
	name = "战斗屏"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列: BoxContainer = UiTheme.建盒(self, "战斗屏上下列", false, 6)
	UiTheme.占满(列)
	列.offset_left = 6
	列.offset_right = -6
	列.offset_top = 3
	列.offset_bottom = -3
	列.clip_contents = true
	_建左牌库栏(列)
	_建中栏(列)
	_建战报栏(列)
	_建动画层()
	_建QTE弹层()
	_建感应面板()
	_反馈文字 = "点手牌发动战术牌；点「结束我方回合」让内核打一个完整回合。"

## 中栏：上 `阵型区`（4×4 棋盘）+ 下 `手牌栏`。
func _建中栏(父: Node) -> void:
	_中栏 = UiTheme.建盒(父, "战斗屏中栏", true, 4) as VBoxContainer
	_中栏.custom_minimum_size = Vector2(中栏宽, 0)
	_中栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_中栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_建阵型区(_中栏)
	_建下半区(_中栏)

## 建战斗动画层（弹道连线 + 浮动飘字 + 发牌飞卡）。**只建一次**，`refresh()` 只换数据。
func _建动画层() -> void:
	_战斗动画层 = 动画层.new()
	_战斗动画层.name = "战斗动画层"
	_战斗动画层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_战斗动画层.z_index = 8
	add_child(_战斗动画层)
	UiTheme.占满(_战斗动画层)
	_特效画布 = _战斗动画层
	_特效层 = _战斗动画层

# ---- ★ COL-4b：QTE 弹窗 / 感应牌库面板（实现在 colonial_overlay.gd） ----
func 需QTE弹窗(c: Dictionary) -> bool: return 覆盖层.需QTE弹窗(self, c)
func _弹QTE弹窗(区: String, 键: String, 上排: bool, 目标键: String) -> void: 覆盖层.弹QTE(self, 区, 键, 上排, 目标键)
func _QTE选(档: String) -> void: 覆盖层.选QTE(self, 档)
func _QTE取消() -> void: 覆盖层.取消QTE(self)
func QTE弹窗显示中() -> bool: return _QTE弹层 != null and _QTE弹层.visible
func _建QTE弹层() -> void: 覆盖层.建QTE弹层(self)
func 开感应牌库面板() -> void: 覆盖层.开感应面板(self)
func 关感应牌库面板() -> void: 覆盖层.关感应面板(self)
func 感应面板显示中() -> bool: return _感应面板 != null and _感应面板.visible
func _建感应面板() -> void: 覆盖层.建感应面板(self)

## 单行裁切标签：文本属性是**全文**（断言照旧查得到），显示上裁成一行不换行 —— 高度恒为一行。
func _建单行标签(父: Node, 名: String, 文本: String, 大小: int = UiTheme.字号_小, 色: Color = UiTheme.主文字) -> Label:
	var l := UiTheme.建标签(父, 文本, 大小, 色)
	l.name = 名
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()

func _回话(文: String, 好消息: bool) -> void:
	_反馈文字 = 文
	_反馈是好消息 = 好消息

## `〔我方·前1〕` 这样的位标（位名走 `Fm.位名()`，表现层不自己拼编号）。
func _位文字(方: String, 位号: int) -> String:
	if 位号 < 0:
		return "〔%s〕" % _方中文(方)
	return "〔%s·%s〕" % [_方中文(方), Fm.位名(float(位号))]

func _方中文(方: String) -> String:
	return "我方" if (方 == 我方 or 方 == "ally") else "敌方"

## 串行播放 `_演出队列`：一帧一帧按 `STEP_DURATION / _演出倍速` 走。
func _消费演出队列() -> void:
	if _演出进行中:
		return
	_演出进行中 = true
	_演出跳过请求 = false
	_当前演出总帧数 = _演出队列.size()
	_已播帧数 = 0
	_演出序号 += 1
	var 我的序号 := _演出序号
	_刷新控制按钮()
	var 静默 := UiTheme.无声模式()
	for i in _演出队列.size():
		if 我的序号 != _演出序号:
			return
		_已播帧数 = i + 1
		var 帧: Variant = _演出队列[i]
		if not (帧 is Dictionary):
			continue
		if 静默:
			_应用帧终态(帧, i + 1, _当前演出总帧数)
			continue
		_帧已耗时 = 0.0
		await _播一帧(帧, i + 1, _当前演出总帧数)
		if 我的序号 != _演出序号:
			return
		if _演出跳过请求:
			break
		var 一步 := STEP_DURATION / maxf(_演出倍速, 0.25)
		var 余 := maxf(0.0, 一步 - _帧已耗时)
		if 余 > 0.0 and is_inside_tree():
			await get_tree().create_timer(余).timeout
		if 我的序号 != _演出序号:
			return
		if _演出跳过请求:
			break
	if 我的序号 != _演出序号:
		return
	_已播帧数 = _当前演出总帧数
	if _演出跳过请求 and not 静默:
		if not _演出队列.is_empty() and _演出队列[_演出队列.size() - 1] is Dictionary:
			_应用帧终态(_演出队列[_演出队列.size() - 1], _当前演出总帧数, _当前演出总帧数)
	_演出跳过请求 = false
	_演出进行中 = false
	_刷新控制按钮()
	if session != null and session.battle_ctx.get("result") != null:
		if not 静默 and is_inside_tree():
			await get_tree().create_timer(结算前停顿秒 / maxf(_演出倍速, 1.0)).timeout
			if 我的序号 != _演出序号:
				return
		_自动连播开启 = false
		_点结算()
		return
	refresh()
	if _自动连播开启 and not 静默 and is_inside_tree():
		await get_tree().create_timer(连播停顿秒 / maxf(_演出倍速, 1.0)).timeout
		if 我的序号 != _演出序号:
			return
		if _自动连播开启 and not _演出进行中 and session != null and session.battle_ctx.get("result") == null:
			_下一拍()

## 播一帧（非 headless 才有分段时间轴）。
func _播一帧(帧: Dictionary, 序: int, 总: int) -> void:
	_写演出横幅(帧, 序, 总, true)
	match str(帧.get("类别", "")):
		"card_deal":
			await _播发牌帧(帧)
		"attack":
			await _播动作帧(帧, false)
		"heal":
			await _播动作帧(帧, true)
		"card_fx":
			await _播卡牌帧(帧)
		_:
			pass

## 发牌帧：来源机体卡青金脉冲 → 金色流光卡背飞到目标手牌 → 落地脉冲 1.15x → 1.0x。
func _播发牌帧(帧: Dictionary) -> void:
	var 源位 := int(帧.get("来源位", -1))
	var 源卡: UnitCard = _卡(我方, 源位) if 源位 >= 0 else null
	if 源卡 != null:
		源卡.播放发牌脉冲()
	var 目标 := _手牌卡控件(int(帧.get("手牌索引", -1)))
	if 目标 != null and 源卡 != null and _战斗动画层 != null:
		_战斗动画层.播放飞卡(源卡, 目标, 发牌流光秒 / maxf(_演出倍速, 0.25))
	await _等演出(发牌流光秒)
	_脉冲手牌(目标)

## 动作帧（攻击 / 修理）：前段出手方亮金框 + 前冲 + 指向箭头光束；后段受击方红闪 + 震动 + 飘字。
func _播动作帧(帧: Dictionary, 治疗: bool) -> void:
	var e: Variant = 帧.get("日志")
	if not (e is Dictionary):
		_应用帧终态(帧, _已播帧数, _当前演出总帧数)
		return
	var 事件: Dictionary = e
	var 轨: Array = []
	var 飘: Array = []
	var 反馈: Dictionary = {}
	if 治疗:
		_加修理动画(事件, 轨, 飘, 反馈)
	else:
		_加攻击动画(事件, 轨, 飘, 反馈)
	_清全部卡片反馈()
	var 出手方 := str(事件.get("单位方", ""))
	var 出手位 := int(float(事件.get("单位位", -1.0)))
	var 目方 := str(事件.get("目标方", ""))
	var 目位 := int(float(事件.get("目标位", -1.0)))
	var 向 := 1.0 if (出手方 == 我方 or 出手方 == "ally") else -1.0
	var 出手卡 := _卡(出手方, 出手位)
	if 出手卡 != null:
		var kind := "修理" if 治疗 else ("大招" if _是大招(事件) else "出手")
		出手卡.set_combat_fx(kind, 向, 出手前冲像素)
	if _战斗动画层 != null:
		_战斗动画层.set_popups([])
		_战斗动画层.set_trajectories(轨)
	await _等演出(出手前段秒)
	var 目卡 := _卡(目方, 目位)
	if 目卡 != null:
		var 受 := "治疗" if 治疗 else "受击"
		if not 治疗 and 事件.get("目标剩余HP") != null and float(事件.get("目标剩余HP")) <= 0.0:
			受 = "击破"
		目卡.set_combat_fx(受, -向)
	if _战斗动画层 != null:
		_战斗动画层.set_popups(飘)
		if not (轨.is_empty() and 飘.is_empty()):
			_战斗动画层.开始淡出(飘字停留秒)

## 当前这一帧还要等 `秒`（按倍速折算），并把它记进 `_帧已耗时`（一步的总时长仍 = STEP_DURATION）。
func _等演出(秒: float) -> void:
	_帧已耗时 += 秒
	if not is_inside_tree():
		return
	await get_tree().create_timer(秒 / maxf(_演出倍速, 0.25)).timeout

# ---- 转发到 board_panel.gd ----
func _建阵型区(父: Node) -> void: BoardPanel._建阵型区(self, 父)
func _战线分隔(父: Node) -> void: BoardPanel._战线分隔(self, 父)
func _建一方(父: Node, 名: String, 标题: String, 方: String, 反序: bool) -> VBoxContainer: return BoardPanel._建一方(self, 父, 名, 标题, 方, 反序)
func _建播报条(父: Node) -> void: BoardPanel._建播报条(self, 父)
func _画阵型(在战斗: bool) -> void: BoardPanel._画阵型(self, 在战斗)
func _算援护(在战斗: bool) -> void: BoardPanel._算援护(self, 在战斗)
func _推援护线() -> void: BoardPanel._推援护线(self)
func _阵型卡Of键(键: String) -> UnitCard: return BoardPanel._阵型卡Of键(self, 键)
func 援护连线数() -> int: return BoardPanel.援护连线数(self)
func _填一方(卡们: Array, 方: String, 占位: Dictionary, 在战斗: bool) -> void: BoardPanel._填一方(self, 卡们, 方, 占位, 在战斗)
func _单机牌组() -> bool: return BoardPanel._单机牌组(self)
func _点选机体(单位键: String) -> void: BoardPanel._点选机体(self, 单位键)
func _位号到键(方: String) -> Dictionary: return BoardPanel._位号到键(self, 方)
func _单位字典(方: String, 位号: int) -> Dictionary: return BoardPanel._单位字典(self, 方, 位号)
func _敌意(位号: int) -> Array: return BoardPanel._敌意(self, 位号)
func _写播报条(文: String, 色: Color = UiTheme.高亮) -> void: BoardPanel._写播报条(self, 文, 色)
func 播报文本() -> String: return BoardPanel.播报文本(self)
func _写作战画面空态() -> void: BoardPanel._写作战画面空态(self)
func _本拍摘要(新们: Array) -> String: return BoardPanel._本拍摘要(self, 新们)
func _本拍色(新们: Array) -> Color: return BoardPanel._本拍色(self, 新们)
func _攻击摘要(e: Dictionary) -> String: return BoardPanel._攻击摘要(self, e)
func _修理摘要(e: Dictionary) -> String: return BoardPanel._修理摘要(self, e)
func _战术牌摘要(e: Dictionary) -> String: return BoardPanel._战术牌摘要(self, e)
func _势力摘要(e: Dictionary) -> String: return BoardPanel._势力摘要(self, e)
func _通用摘要(e: Dictionary) -> String: return BoardPanel._通用摘要(self, e)
func _剥文本前缀(文: String) -> String: return BoardPanel._剥文本前缀(self, 文)
func _卡牌摘要尾(e: Dictionary) -> String: return BoardPanel._卡牌摘要尾(self, e)
func _卡(方: String, 位号: int) -> UnitCard: return BoardPanel._卡(self, 方, 位号)
func _单位名(方: String, 位号: int, 键: String) -> String: return BoardPanel._单位名(self, 方, 位号, 键)
func _是大招(e: Dictionary) -> bool: return BoardPanel._是大招(self, e)
func _数字(值: float) -> String: return BoardPanel._数字(self, 值)
func _为什么(r: Dictionary) -> String: return BoardPanel._为什么(self, r)

# ---- 转发到 hand_panel.gd ----
func _建下半区(父: Node) -> void: HandPanel._建下半区(self, 父)
func _建手牌栏(父: Node) -> void: HandPanel._建手牌栏(self, 父)
func _建单机双排(父: Node) -> void: HandPanel._建单机双排(self, 父)
func _建单机一排(父: Node, 名: String, 标题名: String, 卡行名: String, 边色: Color, 占比: float) -> Dictionary: return HandPanel._建单机一排(self, 父, 名, 标题名, 卡行名, 边色, 占比)
func _紧面板样式(色: Color, 边色: Color, 边宽: int, 内距横: int, 内距纵: int) -> StyleBoxFlat: return HandPanel._紧面板样式(self, 色, 边色, 边宽, 内距横, 内距纵)
func _画手牌(在战斗: bool) -> void: HandPanel._画手牌(self, 在战斗)
func _切单机双排(单机: bool) -> void: HandPanel._切单机双排(self, 单机)
func _画单机双排() -> void: HandPanel._画单机双排(self)
func _建单机子栏(父: Node, 组: String, 组牌: Array, 上排: bool, 起序: int, 空文: String = "（无）") -> int: return HandPanel._建单机子栏(self, 父, 组, 组牌, 上排, 起序, 空文)
func _分到组(牌们: Array, 组: String) -> Array: return HandPanel._分到组(self, 牌们, 组)
func _建分组标(父: Node, 文: String) -> Label: return HandPanel._建分组标(self, 父, 文)
func 手牌卡控件们(上排: bool) -> Array: return HandPanel.手牌卡控件们(self, 上排)
func _收卡控件(根: Node, 出: Array) -> void: HandPanel._收卡控件(self, 根, 出)
func 联动高亮(位们: Array, on: bool) -> void: HandPanel.联动高亮(self, 位们, on)
func _悬停来源(位们: Array) -> void: HandPanel._悬停来源(self, 位们)
func _移开来源() -> void: HandPanel._移开来源(self)
func _亮友军可投放(秒: float = 0.0) -> void: HandPanel._亮友军可投放(self, 秒)
func _灭友军可投放() -> void: HandPanel._灭友军可投放(self)
func 友军可投放高亮中() -> bool: return HandPanel.友军可投放高亮中(self)
func _手牌总上限() -> int: return HandPanel._手牌总上限(self)
func _初始手牌上限() -> int: return HandPanel._初始手牌上限(self)
func _演本拍新增(前日志: int, 前手: Array) -> void: HandPanel._演本拍新增(self, 前日志, 前手)
func _收新发牌提示() -> void: HandPanel._收新发牌提示(self)
func _手牌卡控件(索引: int) -> Control: return HandPanel._手牌卡控件(self, 索引)
func _脉冲手牌(目标: Control) -> void: HandPanel._脉冲手牌(self, 目标)
func _手牌快照() -> Array: return HandPanel._手牌快照(self)

# ---- 转发到 hand_card_item.gd ----
func _阶段中文(阶段: String) -> String: return HandCardItem._阶段中文(self, 阶段)
func _建单机卡(父: Node, c: Dictionary, 上排: bool, idx: int, 同栏张数: int = 0) -> void: HandCardItem._建单机卡(self, 父, c, 上排, idx, 同栏张数)
func _单机卡字号(同栏张数: int, 上限: int = 12) -> int: return HandCardItem._单机卡字号(self, 同栏张数, 上限)
func _建裁切标签(父: Node, 名: String, 文本: String, 字号: int, 色: Color) -> Label: return HandCardItem._建裁切标签(self, 父, 名, 文本, 字号, 色)
func _字号行高(字号: int) -> float: return HandCardItem._字号行高(self, 字号)
func _套紧按钮样式(按: Button, 边色: Color) -> void: HandCardItem._套紧按钮样式(self, 按, 边色)
func _单机卡信息行(c: Dictionary, 区: String) -> String: return HandCardItem._单机卡信息行(self, c, 区)
func _单机卡副行(c: Dictionary, 区: String) -> String: return HandCardItem._单机卡副行(self, c, 区)
func _单机卡悬停(c: Dictionary, 区: String) -> String: return HandCardItem._单机卡悬停(self, c, 区)
func _点单机卡(区: String, 键: String, 上排: bool) -> void: HandCardItem._点单机卡(self, 区, 键, 上排)
func _打单机卡(区: String, 键: String, 上排: bool, 目标键: String) -> Dictionary: return HandCardItem._打单机卡(self, 区, 键, 上排, 目标键)
func _卡牌参数() -> Dictionary: return HandCardItem._卡牌参数(self)

# ---- 转发到 deck_sidebar.gd ----
func _建左牌库栏(父: Node) -> void: DeckSidebar._建左牌库栏(self, 父)
func _建左库区块(父: Node, 组: String) -> void: DeckSidebar._建左库区块(self, 父, 组)
func _左库条目们() -> Array: return DeckSidebar._左库条目们(self)
func _左库条目(c: Dictionary, 来源: String) -> Dictionary: return DeckSidebar._左库条目(self, c, 来源)
func _左库悬停(c: Dictionary, 状: String, 来源: String) -> String: return DeckSidebar._左库悬停(self, c, 状, 来源)
func _画左牌库() -> void: DeckSidebar._画左牌库(self)
func _左库组Of(e: Dictionary) -> String: return DeckSidebar._左库组Of(self, e)
func _左库字号(总条数: int) -> int: return DeckSidebar._左库字号(self, 总条数)
func _摆左库区块(分: Dictionary) -> void: DeckSidebar._摆左库区块(self, 分)
func _刷左库副牌概览(公有待入: Array = []) -> void: DeckSidebar._刷左库副牌概览(self, 公有待入)
func _副牌库徽章文() -> String: return DeckSidebar._副牌库徽章文(self)
func _建左库卡(父: Node, e: Dictionary, 字号: int = 11) -> void: DeckSidebar._建左库卡(self, 父, e, 字号)
func 左库卡控件们() -> Array: return DeckSidebar.左库卡控件们(self)
func _收左库卡控件(根: Node, 出: Array) -> void: DeckSidebar._收左库卡控件(self, 根, 出)

# ---- 转发到 log_panel.gd ----
func _建战报栏(父: Node) -> void: LogPanel._建战报栏(self, 父)
func _画战报(在战斗: bool) -> void: LogPanel._画战报(self, 在战斗)
func _日志色(e: Dictionary) -> Color: return LogPanel._日志色(self, e)
func _是高亮(e: Dictionary) -> bool: return LogPanel._是高亮(self, e)
func _刷新控制按钮() -> void: LogPanel._刷新控制按钮(self)
func _点推进() -> void: LogPanel._点推进(self)
func _点自动() -> void: LogPanel._点自动(self)
func _点倍速() -> void: LogPanel._点倍速(self)
func _点跳过本回演出() -> void: LogPanel._点跳过本回演出(self)
func _跳过直达结算() -> void: LogPanel._跳过直达结算(self)
func _点自动打完() -> void: LogPanel._点自动打完(self)
func _自动打完() -> void: LogPanel._自动打完(self)
func _点结算() -> void: LogPanel._点结算(self)
func _表演中止(清队列: bool = true) -> void: LogPanel._表演中止(self, 清队列)
func _下一拍() -> void: LogPanel._下一拍(self)
func _点开关(单位键: String, 开关键: String) -> void: LogPanel._点开关(self, 单位键, 开关键)
func _标记日志已播到末尾() -> void: LogPanel._标记日志已播到末尾(self)

# ---- 转发到 drag_aim.gd ----
func _必须拖动到友军(c: Dictionary, 区: String = "") -> bool: return DragAim._必须拖动到友军(self, c, 区)
func 可拖拽释放(c: Dictionary, 区: String) -> bool: return DragAim.可拖拽释放(self, c, 区)
func _拖拽目标方(c: Dictionary) -> String: return DragAim._拖拽目标方(self, c)
func _卡目标方(c: Dictionary, 区: String) -> String: return DragAim._卡目标方(self, c, 区)
func _拥有者位() -> int: return DragAim._拥有者位(self)
func _拥有者卡() -> UnitCard: return DragAim._拥有者卡(self)
func _单机卡数据(键: String) -> Dictionary: return DragAim._单机卡数据(self, 键)
func _卡心全局(卡: Variant) -> Vector2: return DragAim._卡心全局(self, 卡)
func _到特效层(全局点: Vector2) -> Vector2: return DragAim._到特效层(self, 全局点)
func _命中机体卡(全局点: Vector2, 方: String = "") -> Dictionary: return DragAim._命中机体卡(self, 全局点, 方)
func _我方卡By键(键: String) -> UnitCard: return DragAim._我方卡By键(self, 键)
func _拖拽起点卡() -> UnitCard: return DragAim._拖拽起点卡(self)
func _拖拽起点() -> Vector2: return DragAim._拖拽起点(self)
func 拖拽瞄准线() -> Dictionary: return DragAim.拖拽瞄准线(self)
func _刷新瞄准() -> void: DragAim._刷新瞄准(self)
func 开始拖拽(区: String, 键: String, 上排: bool, 全局点: Vector2, 牌: Dictionary = {},
		卡控件: Control = null) -> Dictionary: return DragAim.开始拖拽(self, 区, 键, 上排, 全局点, 牌, 卡控件)
func 拖拽到(全局点: Vector2) -> Dictionary: return DragAim.拖拽到(self, 全局点)
func 结束拖拽(全局点: Vector2) -> Dictionary: return DragAim.结束拖拽(self, 全局点)
func 取消拖拽() -> void: DragAim.取消拖拽(self)
func 拖拽中() -> bool: return DragAim.拖拽中(self)
func 拖拽按住点() -> Vector2: return DragAim.拖拽按住点(self)
func _吸附到(命: Dictionary) -> void: DragAim._吸附到(self, 命)
func _清拖拽状态() -> void: DragAim._清拖拽状态(self)
func _单机卡按下(区: String, 键: String, 上排: bool, 卡: Control) -> void: DragAim._单机卡按下(self, 区, 键, 上排, 卡)
func _process(dt: float) -> void: DragAim._process(self, dt)
func _单机卡松开(_区: String, _键: String, _上排: bool, _卡: Control) -> void: DragAim._单机卡松开(self, _区, _键, _上排, _卡)
func _悬停单机卡(卡: Variant) -> void: DragAim._悬停单机卡(self, 卡)
func _移开单机卡() -> void: DragAim._移开单机卡(self)
func _拥有者位名们() -> Array: return DragAim._拥有者位名们(self)
func _鼠标全局() -> Vector2: return DragAim._鼠标全局(self)

# ---- 转发到 battle_fx_player.gd ----
func _构建演出队列(entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array: return BattleFx._构建演出队列(self, entries, prev_hand, curr_hand)
func 构建单拍演出帧(entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array: return BattleFx.构建单拍演出帧(self, entries, prev_hand, curr_hand)
func 演出帧数() -> int: return BattleFx.演出帧数(self)
func 已播帧数() -> int: return BattleFx.已播帧数(self)
func _应用帧终态(帧: Dictionary, 序: int, 总: int) -> void: BattleFx._应用帧终态(self, 帧, 序, 总)
func _上发牌终态(帧: Dictionary) -> void: BattleFx._上发牌终态(self, 帧)
func _上动作终态(帧: Dictionary, 治疗: bool) -> void: BattleFx._上动作终态(self, 帧, 治疗)
func _上卡牌终态(帧: Dictionary) -> void: BattleFx._上卡牌终态(self, 帧)
func _播卡牌帧(帧: Dictionary) -> void: BattleFx._播卡牌帧(self, 帧)
func _写演出横幅(帧: Dictionary, 序: int, 总: int, 带进度: bool = true) -> void: BattleFx._写演出横幅(self, 帧, 序, 总, 带进度)
func _发牌帧(e: Dictionary, prev_hand: Array, curr_hand: Array, 已认领: Array) -> Dictionary: return BattleFx._发牌帧(self, e, prev_hand, curr_hand, 已认领)
func _手牌补帧(c: Dictionary, idx: int) -> Dictionary: return BattleFx._手牌补帧(self, c, idx)
func _手牌新增索引(prev_hand: Array, curr_hand: Array) -> Array: return BattleFx._手牌新增索引(self, prev_hand, curr_hand)
func _牌签名(c: Dictionary) -> String: return BattleFx._牌签名(self, c)
func _认领手牌(牌名: String, prev_hand: Array, curr_hand: Array, 已认领: Array) -> int: return BattleFx._认领手牌(self, 牌名, prev_hand, curr_hand, 已认领)
func _来源名(源文: String) -> String: return BattleFx._来源名(self, 源文)
func _位名到位号(位名: String) -> int: return BattleFx._位名到位号(self, 位名)
func _攻击帧(e: Dictionary) -> Dictionary: return BattleFx._攻击帧(self, e)
func _修理帧(e: Dictionary) -> Dictionary: return BattleFx._修理帧(self, e)
func _战术牌帧(e: Dictionary) -> Dictionary: return BattleFx._战术牌帧(self, e)
func _非攻击牌帧(e: Dictionary) -> Dictionary: return BattleFx._非攻击牌帧(self, e)
func _事件帧(e: Dictionary) -> Dictionary: return BattleFx._事件帧(self, e)
func _攻击横幅(e: Dictionary, 攻名: String, 目名: String) -> String: return BattleFx._攻击横幅(self, e, 攻名, 目名)
func _画战斗动画(在战斗: bool) -> void: BattleFx._画战斗动画(self, 在战斗)
func _取本拍事件() -> Array: return BattleFx._取本拍事件(self)
func _收窄到最后一拍(事件们: Array) -> Array: return BattleFx._收窄到最后一拍(self, 事件们)
func _应用本拍(新们: Array) -> void: BattleFx._应用本拍(self, 新们)
func _加卡牌演出(e: Dictionary, 飘: Array, 脉冲卡们: Array) -> void: BattleFx._加卡牌演出(self, e, 飘, 脉冲卡们)
func _事件卡(e: Dictionary, 是目标: bool) -> UnitCard: return BattleFx._事件卡(self, e, 是目标)
func _卡上胶囊(卡: Variant, 文: String, 色: Color, 层: int) -> Dictionary: return BattleFx._卡上胶囊(self, 卡, 文, 色, 层)
func _播脉冲(卡们: Array) -> void: BattleFx._播脉冲(self, 卡们)
func _加攻击动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void: BattleFx._加攻击动画(self, e, 轨, 飘, 反馈)
func _加镜甲动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void: BattleFx._加镜甲动画(self, e, 轨, 飘, 反馈)
func _加修理动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void: BattleFx._加修理动画(self, e, 轨, 飘, 反馈)
func _加势力胶囊(e: Dictionary, 飘: Array) -> void: BattleFx._加势力胶囊(self, e, 飘)
func _弹道(起方: String, 起位: int, 止方: String, 止位: int,
		色: Color, 类型: String, 宽: float, 虚: bool) -> Dictionary: return BattleFx._弹道(self, 起方, 起位, 止方, 止位, 色, 类型, 宽, 虚)
func _飘字(方: String, 位: int, 文: String, 色: Color, 字号: int, 上移: float) -> Dictionary: return BattleFx._飘字(self, 方, 位, 文, 色, 字号, 上移)
func _胶囊(方: String, 位: int, 文: String, 色: Color, 层: int) -> Dictionary: return BattleFx._胶囊(self, 方, 位, 文, 色, 层)
func _记反馈(表: Dictionary, 方: String, 位: int, kind: String) -> void: BattleFx._记反馈(self, 表, 方, 位, kind)
func _反馈优先级(kind: String) -> int: return BattleFx._反馈优先级(self, kind)
func _应用卡片反馈(表: Dictionary) -> void: BattleFx._应用卡片反馈(self, 表)
func _清全部卡片反馈() -> void: BattleFx._清全部卡片反馈(self)
