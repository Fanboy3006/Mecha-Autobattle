## 战斗屏（Stage M4-3 实装）：双方 8 格阵型 + 底部战术手牌栏 + 战报栏。
##
## 契约（`协作/架构/M4-表现层接口契约.md` §3 / §5）：
##   · `extends Control`，只有 `setup(session)` / `refresh()` 两个入口；`_ready()` 里不读 session；
##   · 节点树 headless 能建起来（`new()` + `setup()`，不 load 只有编辑器里才有的资源）；
##   · 关键节点名固定（`find_child` 靠它）：`战斗屏` / `阵型区` / `手牌栏` / `候补区` / `战报栏`；
##   · 数据只从门面读（`hand_cards()` / `hand_card_status()` / `reserve_preview()` /
##     `turn_card_summary()` / `unit_view()` / `battle_log_entries()` …），动作只调门面命令；
##   · ★ **不发明规则**：手牌能不能打只有一个判据 —— 门面 `hand_card_status()` 的 `可打` / `原因`。
##     这里**不写任何张数上限**（内核与封存 JS 都没有「每回合最多打 N 张」这条规则）。
##
## ★ 版面纪律（2026-10-13，「战斗屏单位卡互压 / 手牌栏压单位卡 / 战报栏出画布」的根治）：
##   `屏幕容器` 的可用区是 **1280×616**（y = 104..720），本屏按这个尺寸切两半：
##     · **上半区 `阵型区`**（`SIZE_EXPAND_FILL`，约 380px）：顶部 `阵型提示`，
##       下面左右并排 `我方阵型` / `敌方阵型`（各约 620px 宽、每排 4 张 `UnitCard`，
##       每张 `custom_minimum_size = Vector2(132, 148)`，纵向居中不拉伸）；
##     · **下半区**（一个水平 `HBoxContainer`，高约 215px）：左边 `手牌栏`（约 760px），
##       右边 `战报栏`（`custom_minimum_size = Vector2(460, 215)`）。
##   这样阵型区（y 约 108..490）与下半区（y 约 494..712）**完全不重叠**，且 100% 落在 1280×720 里。
##
## 站位几何**照 `Fm` 现场生成**（前 4 + 后 4 · 正交 4×2 = 8 格；★ 不是 9 格），
## 与 `run_map/formation_view.gd` 同一套读法（`Fm.ROWS()` / `Fm.行列数(行)` / `Fm.slotOf` / `Fm.位名`）。
##
## 只有三处「越过门面的**纯读**」，用的全是 `core/` 里现成的纯函数，表现层自己一个数都不算：
##   ① 敌方下一拍行动意图预告 —— `Boss.bossAction(u, ctx)`；
##   ② Boss 阶段预告 —— `Boss.Boss参数` / `Boss.Boss本回合放大技能` / `Boss.Boss下次技能回合`；
##   ③ SEED 觉醒 —— `FacSeed.SEED累计` / `FacSeed.SEED已觉醒`。
##
## ★ Mouse Over（2026-10-13）：`手牌卡N` / `手牌按钮` 与 `候补卡N` 都挂 `HoverTooltip.bind`，
##   说明文本一律取门面 `session.card_hover_text(牌字典)`（表现层不自己拼卡面文案）。
##
## ★ UX-2（2026-10-19，作者反馈第 4 条「发牌需要做一些示意，牌来自哪些机体」）：
##   ① 每张手牌 / 候补牌的卡面都写 **`【来自：XXX】`**（取门面 `source_unit_text`，这里一个字都不拼）；
##   ② 悬停手牌 / 候补牌 → `联动高亮(source_slots, true)`：场上那几台 `UnitCard` 亮起青色联动外框
##      + 〔卡牌来源〕角标；移开 → `联动高亮([], false)` 全灭（纯表现，零状态修改）；
##   ③ 本拍新发牌（`新触发` 且 `触发回合 == 当前回合`）→ 卡上挂【新发牌】角标 + 金色亮框，
##      手牌栏最上面弹出 `【新发牌】获得战术牌【名】（来自：XXX）` 提示条（没新牌时 `visible = false`，
##      所以既有版面一个像素都不变）。
##
## ★ UX-3（2026-10-19，作者反馈第 6 条「需要一点基本的示意性质的战斗动画，让我理解一下谁打了谁、
##   造成了多少伤害、造成了什么效果」）—— 全部落在这一个文件 + `widgets/unit_card.gd`：
##   ① **动作播报条**（`name = "动作播报条"`）：战场区顶部一条紧凑高对比横条（单行、约 24px），
##      每推进一拍把本拍核心事件摘要写成一行；开战初始是 `【战斗开始】等待推进下一拍或点击自动播放`；
##   ② **战斗动画层**（`class 战斗动画层 extends Control`，`name = "战斗动画层"`，
##      `mouse_filter = MOUSE_FILTER_IGNORE`）：**直接挂在 `战斗屏` 上、不进任何容器** →
##      完全不参与自动排版（版面门禁一个像素都不变）；`_draw()` 画指向弹道连线 + 头顶浮动飘字；
##   ③ 出手方 / 受击方 `UnitCard` 的动作反馈（亮金外框 + 角标 + 前冲 / 红闪）走 `UnitCard.set_combat_fx()`。
##   ★ 红线：**纯表现层** —— 只消费 `session.battle_log_entries()` 里的既有字段，
##     零改动战斗内核 RNG 与数值、零 `J.*` 调用；headless 下一切 Tween 跳过（测试毫秒级跑完）。
##
## ★ UX-5（2026-10-19，作者反馈第 2 / 3 条「一回合十几条事件一帧闪完、看不清先后」+「自动战斗直接跳结算」）：
##   ① **串行演出队列**（`STEP_DURATION = 0.5` 秒/步）：点「推进下一回合」后把本拍**新增**日志
##      拆成独立演出帧（发牌 / 攻击·大招·镜甲·连斩 / 修理 / 战术牌 / Boss·增援·势力·结束），
##      一帧一帧地播，横幅写 `〔演出中 i/N〕`；
##   ② 发牌帧：来源机体卡 `UnitCard.播放发牌脉冲()` + 动画层一道金色流光卡背飞向底部手牌栏 →
##      落地那一下目标手牌 `1.15x → 1.0x` 脉冲放大；
##   ③ 攻击 / 修理帧：前 0.15 秒出手方亮金框 + 朝目标前冲 14px + 指向箭头光束；
##      后 0.35 秒受击方红闪 + 左右震动 + 头顶大号飘字（0.65 秒让玩家看清数字），出手方回弹；
##   4) 控制栏：「自动播放 / 暂停连播」（每一回演完停 0.3 秒自动接下一拍）
##      +「2x 加速 / 1x 正常」+（正在演时才露面的）「跳过本回演出」
##      +「结束并结算」（= **跳过直达结算**：`auto_finish_battle()` 算完再进结算）；
##   5) **Headless 零回归**：`DisplayServer.get_name() == "headless"`（= `UiTheme.无声模式()`）时
##      一帧一帧**同步**应用、**不建任何 `create_timer` / Tween**；拆出来的帧仍然留在
##      `_演出队列` 里供自动化测试检查（`STEP_DURATION >= 0.45`）。
##
## ★ UX-6（2026-10-19，作者反馈第 4 条）：战斗屏不再显示「憋大招」按钮
##   （`GameSession.toggle_hold_ultimate()` 等底层方法保留不动，大招状态照旧写在单位卡的「开关行」文字里）。
class_name BattleView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

const 我方 := "ally"
const 敌方 := "enemy"

## 版面常量（只在这里出现，别散落魔数）。
const 卡宽 := 132.0
const 卡高 := 148.0
const 下半区高 := 215.0
const 手牌滚动高 := 125.0
const 战报滚动高 := 135.0
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

var session: GameSession = null

# ---------------- 阵型区 ----------------
var _阵型区: VBoxContainer
var _阵型提示: Label
var _我方列: VBoxContainer
var _敌方列: VBoxContainer
## 位号 → UnitCard（每方 8 张，`_build()` 只建一次，`refresh()` 只换数据）
var _我方卡: Array = []
var _敌方卡: Array = []
## 已经调过 `finish_battle_and_settle()`（避免重画时二次结算）
var _已结算: bool = false

# ---------------- 手牌栏 / 候补区 ----------------
var _下半区: HBoxContainer
var _手牌栏: PanelContainer
var _手牌顶行: HBoxContainer
var _手牌标题: Label
var _手牌气势: Label
var _候补区: PanelContainer
var _候补文: Label
var _候补卡行: HBoxContainer
var _手牌列表: HBoxContainer
var _操作结果: Label
## ★ UX-2 第 3 项：新发牌提示条（只在真有新牌入栏时露面，平时 `visible = false` 不占高度）
var _新发牌提示: Label

# ---------------- ★ DECK-3 单机牌组：上下双排手牌栏 ----------------
## 旧口径（战术手牌）那一行的滚动容器 —— 单机牌组模式下**整行收起来**（节点留着、不删）。
var _手牌滚动: ScrollContainer
## 上排：当前选中机体的专属牌（左 主武器卡 / 中 衍生攻击卡 / 右 专属精神牌）。
var _专属排: PanelContainer
var _专属排标题: Label
var _专属排滚动: ScrollContainer
var _专属排列表: HBoxContainer
## 下排：全队公有牌（势力牌 / 职业牌 / 统帅牌 / 公共衍生牌）。
var _公有排: PanelContainer
var _公有排标题: Label
var _公有排滚动: ScrollContainer
var _公有排列表: HBoxContainer

# ---------------- 战报栏 ----------------
var _战报栏: PanelContainer
var _战报提示: Label
var _战报滚: VBoxContainer
var _推进按钮: Button
var _自动按钮: Button
var _结算按钮: Button
## ★ UX-5 新增的两个控制按钮（「2x 加速 / 1x 正常」与演出期间的「跳过本回演出」）。
var _倍速按钮: Button
var _跳过演出按钮: Button

# ---------------- ★ UX-3 战斗动画层 ----------------
## 战场区顶部那条紧凑播报条（`name = "动作播报条"`）。
var _动作播报条: Label
## 弹道连线 + 浮动飘字的独立覆盖层（`name = "战斗动画层"`，不参与任何容器排版）。
var _战斗动画层 = null
## 已经播过几条战斗日志（每推进一拍只播**新增**的那一段；换一场 / 日志变短就归零）。
var _已播日志数: int = 0
## 上一次看到的 `ctx.log` 数组本体（换一场 = 换数组 → 归零重播）。
var _已播日志引用 = null

## 上一条命令的反馈（三层反馈里「即时 + 为什么」那一小块）
var _反馈文字: String = ""
var _反馈是好消息: bool = true

# ---------------- ★ UX-5 串行演出队列（0.5 秒/步） ----------------
## 本拍拆出来的串行演出帧（`构建单拍演出帧()` 的产物）。**headless 下也留着** —— 测试直接查它。
var _演出队列: Array = []
## 是不是正在一帧一帧地演（演出期间 `refresh()` 不抢日志、不一次性叠画）。
var _演出进行中: bool = false
## 玩家点了「跳过本回演出」→ 这一回立刻跳到终态。
var _演出跳过请求: bool = false
## 演出倍速（1.0 = 正常 / 2.0 = 「2x 加速」，每步 `STEP_DURATION / _演出倍速` 秒）。
var _演出倍速: float = 1.0
## 「自动播放 / 暂停连播」开关：每一回演完停 0.3 秒自动接下一拍。
var _自动连播开启: bool = false
## 已经播到第几帧 / 本回一共几帧（横幅写 `〔演出中 i/N〕`）。
var _已播帧数: int = 0
var _当前演出总帧数: int = 0
## 演出序号：换场 / 中止 / 重开一场时 +1，旧的协程看到序号变了就自己退出（不留野协程）。
var _演出序号: int = 0
## 当前这一帧已经等掉的秒数（让「一步 = STEP_DURATION」而不是「一步 = 0.5 + 前段」）。
var _帧已耗时: float = 0.0
## 正在「推内核这一拍」的预热窗：`step_battle_turn()` 内部会 `changed.emit()` → 壳会顺手
## `refresh()` 一次；这时队列还没建好，若让 `_画战斗动画()` 干活，就会把这十几条事件
## **一次性叠在同一帧**（作者反馈的那锅粥）。所以预热窗里一律不画。
var _演出预热: bool = false
## ★ UX-5 规格里的「特效画布」= 现有的《战斗动画层》（弹道 / 飘字 / 飞卡都画在它上面）。
var _特效画布 = null

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _手牌标题 == null:
		return
	if session == null:
		_阵型提示.visible = true
		_我方列.visible = false
		_敌方列.visible = false
		_手牌标题.text = "手牌栏：没有会话。"
		_手牌气势.text = ""
		_候补文.text = "候补区：没有会话。"
		_战报提示.text = "战报栏：没有会话。"
		_操作结果.text = ""
		_写作战画面空态()
		_清空(_手牌列表)
		_清空(_候补卡行)
		_清空(_战报滚)
		return
	var 在战斗 := not session.battle_ctx.is_empty()
	if not 在战斗:
		_已结算 = false
	elif session.battle_ctx.get("result") == null:
		# ★ 修复「点击结算没有反应」（2026-10-16 作者试玩反馈）：
		#   只要这一场**还没分出胜负**，就把「已结算」这道闸重新放开 ——
		#   「结束并结算」现在任何时候都能点：没打完的话 `_点结算()` 会先 `auto_finish_battle()`
		#   把本场打完，再 `finish_battle_and_settle()`。
		_已结算 = false
	_阵型提示.visible = not 在战斗
	_我方列.visible = 在战斗
	_敌方列.visible = 在战斗
	_画阵型(在战斗)
	_画手牌(在战斗)
	_画战报(在战斗)
	# ★ UX-3：本拍新增日志 → 播报条 + 弹道 + 飘字 + 出手 / 受击卡反馈。
	#   放在阵型之后（卡的数据已经刷新完），纯表现、零状态修改。
	_画战斗动画(在战斗)
	# ★ UX-5：控制栏按钮文字 / 可见性跟着「正在演 / 自动连播 / 倍速」走。
	_刷新控制按钮()
	_操作结果.text = _反馈文字
	_操作结果.add_theme_color_override("font_color", UiTheme.正面 if _反馈是好消息 else UiTheme.负面)

# ==========================================================================================
# 建节点树（只在 setup 里跑一次）
# ==========================================================================================

func _build() -> void:
	name = "战斗屏"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "战斗屏上下列", true, UiTheme.间距_小)
	# ★ 直接子容器必须铺满父区域（`self` 是普通 `Control`，不 `占满` 就塌缩成最小尺寸）。
	UiTheme.占满(列)
	列.offset_left = 6
	列.offset_right = -6
	列.offset_top = 3
	列.offset_bottom = -3
	# 兜底：万一某一屏的内容最小高度超了 616，也不让它画到画布外。
	列.clip_contents = true
	_建阵型区(列)
	_建下半区(列)
	# ★ UX-3 第 2 / 3 项：战斗动画层（弹道连线 + 浮动飘字）。
	#   它是**独立覆盖层**：直接挂在 `战斗屏` 上、`占满(self)`、`MOUSE_FILTER_IGNORE`、
	#   不是任何 `Container` 的子节点 → 完全不参与自动排版（不会把阵型 / 手牌栏挤走，也不会造成卡片重叠）。
	#   放在最后建 → 画在所有内容的上面。
	_建动画层()
	_反馈文字 = "点手牌发动战术牌；点「推进下一回合」让内核打一个完整回合。"

## 上半区：顶部提示 + 左右双方阵型。
func _建阵型区(父: Node) -> void:
	_阵型区 = UiTheme.建盒(父, "阵型区", true, UiTheme.间距_小)
	_阵型区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_阵型区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.占满(_阵型区)
	_阵型提示 = UiTheme.建说明(_阵型区, "现在不在战斗里 —— 从主菜单点「快速测试战斗」，或者在大地图的作战格上点「开战」。",
		UiTheme.字号_小, UiTheme.弱文字)
	_阵型提示.name = "阵型提示"
	# ★ UX-3 第 1 项：中央动作播报条（战场区顶部一条紧凑高对比横条，单行、约 24px）。
	#   高度是**硬约束**：它要把底部手牌栏留在 720 内，所以只用一行 + 极小内边距。
	_建播报条(_阵型区)
	var 主体 := UiTheme.建盒(_阵型区, "阵型主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_我方列 = _建一方(主体, "我方阵型", "我方阵型（前 4 + 后 4，正交 4×2 = 8 格）", 我方)
	_敌方列 = _建一方(主体, "敌方阵型", "敌方阵型（前 4 + 后 4，正交 4×2 = 8 格）", 敌方)

## 一方阵型：行数 / 每行列数全部读 `Fm`（8 格 = 前 4 + 后 4）。
## ★ UX-3 版面调整：原来每一方顶上有一行「我方阵型（前 4 + 后 4，正交 4×2 = 8 格）」标题，
##   现在**这一行的位置让给《动作播报条》**，标题文字改挂成 `列.tooltip_text`（悬停照样看得到）。
##   为什么必须让：1280×720 下「阵型区 + 手牌栏」的最小高度实测只差 20 余像素，
##   再多留这一行 22px 的标题 + 4px 间距，就会把底部手牌栏挤出 720 底边
##   （`test_presentation_layout.gd` 的「手牌栏 / 战报栏完全落在可用区内」会直接红）。
func _建一方(父: Node, 名: String, 标题: String, 方: String) -> VBoxContainer:
	var 列 := UiTheme.建盒(父, 名, true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	列.tooltip_text = 标题
	var 卡们: Array = _我方卡 if 方 == 我方 else _敌方卡
	for 行 in int(Fm.ROWS()):
		var 行盒 := UiTheme.建盒(列, "%s第%d排" % [名, 行], false, UiTheme.间距_小)
		行盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行盒.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UiTheme.建标签(行盒, Fm.行名(float(行)), UiTheme.字号_小, UiTheme.次要文字)
		for 列号 in int(Fm.行列数(float(行))):
			var 卡 := UnitCard.new()
			行盒.add_child(卡)
			# ★ 卡的尺寸由 `UnitCard._get_minimum_size()` 报给布局（132×148）；
			#   纵向 `SHRINK_CENTER` 让它**不随行高拉伸**，行再高也不会压到别人。
			卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			卡.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			卡.custom_minimum_size = Vector2(卡宽, 卡高)
			卡.setup({"ok": false, "为什么": "现在不在战斗里"})
			卡.开关切换.connect(_点开关)
			卡.开状态.connect(_点开状态)
			# ★ DECK-3 §1：点我方任意一张机体卡 = 把它设成当前操作的机体（敌方卡不接）。
			if 方 == 我方:
				卡.点选.connect(_点选机体)
			卡们.append(卡)
	return 列

# ==========================================================================================
# ★ UX-3 第 1 项：中央动作播报条（紧凑单行横条）
# ==========================================================================================

## 建那条播报条：`PanelContainer`（高对比金边深底）+ 里面**一个**单行裁切 `Label`。
## ★ 高度纪律：内边距上下各 3、字号 13（`字号_正文`）、`clip_text` + `OVERRUN_TRIM_ELLIPSIS`
##   → 最小高度恒为一行（实测约 24px），绝不把底部手牌栏挤出 720 底边。
## ★ 节点名 `动作播报条` 挂在**那个 Label** 上（`find_child("动作播报条")` 直接取到文本）。
func _建播报条(父: Node) -> void:
	var 底 := PanelContainer.new()
	底.name = "动作播报条底"
	底.clip_contents = true
	底.mouse_filter = Control.MOUSE_FILTER_PASS
	底.custom_minimum_size = Vector2(0, 播报条高)
	var 样 := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 2)
	样.content_margin_left = 8
	样.content_margin_right = 8
	样.content_margin_top = 2
	样.content_margin_bottom = 2
	底.add_theme_stylebox_override("panel", 样)
	父.add_child(底)
	_动作播报条 = _建单行标签(底, "动作播报条", "【战斗开始】等待推进下一拍或点击自动播放",
		UiTheme.字号_正文, UiTheme.高亮)

## 建战斗动画层（弹道连线 + 浮动飘字 + 发牌飞卡）。**只建一次**，`refresh()` 只换数据。
func _建动画层() -> void:
	_战斗动画层 = 战斗动画层.new()
	_战斗动画层.name = "战斗动画层"
	_战斗动画层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_战斗动画层.z_index = 8
	add_child(_战斗动画层)
	UiTheme.占满(_战斗动画层)
	# ★ UX-5：规格里叫它「特效画布」—— 同一块覆盖层，两个名字都指它。
	_特效画布 = _战斗动画层

## 下半区：一个水平盒子并排容纳 `手牌栏` 与 `战报栏`（★ 原来两者是上下叠着的，会互相压）。
func _建下半区(父: Node) -> void:
	_下半区 = UiTheme.建盒(父, "战斗屏下半区", false, UiTheme.间距)
	_下半区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_下半区.custom_minimum_size = Vector2(0, 下半区高)
	_建手牌栏(_下半区)
	_建战报栏(_下半区)

func _建手牌栏(父: Node) -> void:
	_手牌栏 = UiTheme.建面板(父, "手牌栏", UiTheme.面板底, UiTheme.边框_亮)
	_手牌栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_手牌栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_手牌栏.custom_minimum_size = Vector2(0, 下半区高)
	_手牌栏.clip_contents = true
	var 列 := UiTheme.建盒(_手牌栏, "手牌栏上下列", true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ★ UX-2 第 3 项：新发牌提示条（手牌栏最上面那一条）。
	#   平时 `visible = false`（容器不给隐藏子节点留位置），所以既有版面**一个像素都不变**。
	_新发牌提示 = _建单行标签(列, "新发牌提示", "", UiTheme.字号_小, UiTheme.高亮)
	_新发牌提示.visible = false
	# ---- 顶行：标题 + 气势 + 操作结果 + 右侧紧凑候补区 ----
	_手牌顶行 = UiTheme.建盒(列, "手牌顶行", false, UiTheme.间距_小)
	_手牌顶行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_手牌标题 = _建单行标签(_手牌顶行, "手牌标题", "手牌栏", UiTheme.字号_小, UiTheme.高亮)
	_手牌气势 = _建单行标签(_手牌顶行, "手牌气势", "", UiTheme.字号_小, UiTheme.希望色)
	_操作结果 = _建单行标签(_手牌顶行, "操作结果", "", UiTheme.字号_小, UiTheme.正面)
	# ★ D-01 重点展示区：候补初始牌（角色牌开局在手、职业牌排队进候补 —— 作者要在这里一眼看到）
	_候补区 = UiTheme.建面板(_手牌顶行, "候补区", UiTheme.卡片底, UiTheme.边框_亮)
	_候补区.custom_minimum_size = Vector2(250, 0)
	_候补区.clip_contents = true
	var 候补列 := UiTheme.建盒(_候补区, "候补区上下列", true, 1)
	# ★ `候补文` 保留**原有汇总文字**（smoke 断言逐字查它），但改成单行裁切显示 ——
	#   完整内容在悬停说明里；这样候补区不会因为牌多而把整块版面撑高。
	_候补文 = _建单行标签(候补列, "候补文", "候补区：还没开战。", UiTheme.字号_小, UiTheme.主文字)
	# 每张候补牌一个独立小标签（带 `session.card_hover_text` 悬停说明）。
	var 候补滚 := ScrollContainer.new()
	候补滚.name = "候补滚动"
	候补滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	候补滚.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	候补滚.clip_contents = true
	候补滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	候补滚.custom_minimum_size = Vector2(0, 20)
	候补列.add_child(候补滚)
	_候补卡行 = UiTheme.建盒(候补滚, "候补卡行", false, UiTheme.间距_小)
	# ---- 手牌滚动 ----
	_手牌列表 = _建滚动盒(列, "手牌滚动", "手牌列表", 手牌滚动高)
	_手牌滚动 = _手牌列表.get_parent() as ScrollContainer
	# ★ DECK-3：单机牌组的上下双排手牌栏（默认隐藏 —— 旧口径版面一个像素都不变）。
	_建单机双排(列)

# ==========================================================================================
# ★ DECK-3：上下双排手牌栏（上排 = 选中机体的专属牌 / 下排 = 全队公有牌）
#
#   · 只在 `session.单机牌组开()` 为真时露面；这时旧那行「战术手牌」整行收起（节点不删）；
#   · 两排共用同一块高度预算（各 `单机排高`），所以底部手牌栏 / 战报栏的版面门禁照旧；
#   · 卡片文字**全部来自门面** `upper_hand_cards()` / `lower_hand_cards()`，表现层一个判据都不自己写。
# ==========================================================================================

## 一排（标题 + 横向滚动卡行）的高度预算。两排 + 顶行仍装得进 `下半区高`。
const 单机排高 := 58.0
const 单机卡宽 := 108.0

func _建单机双排(父: Node) -> void:
	var 上 := _建单机一排(父, "专属排", "专属排标题", "专属排滚动", "专属排列表", UiTheme.高亮)
	_专属排 = 上["面"]
	_专属排标题 = 上["标题"]
	_专属排滚动 = 上["滚动"]
	_专属排列表 = 上["卡行"]
	_专属排.visible = false
	var 下 := _建单机一排(父, "公有排", "公有排标题", "公有排滚动", "公有排列表", UiTheme.边框_亮)
	_公有排 = 下["面"]
	_公有排标题 = 下["标题"]
	_公有排滚动 = 下["滚动"]
	_公有排列表 = 下["卡行"]
	_公有排.visible = false

## 建一排：`PanelContainer`（亮边框）+ 单行标题 + 横向滚动卡行。返回四个节点的字典。
func _建单机一排(父: Node, 名: String, 标题名: String, 滚动名: String, 卡行名: String, 边色: Color) -> Dictionary:
	var 面 := UiTheme.建面板(父, 名, UiTheme.卡片底, 边色)
	面.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	面.clip_contents = true
	var 列 := UiTheme.建盒(面, 名 + "上下列", true, 1)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 题 := _建单行标签(列, 标题名, "", UiTheme.字号_小, 边色)
	var 卡行 := _建滚动盒(列, 滚动名, 卡行名, 单机排高 - 20.0)
	var 滚 := 卡行.get_parent() as ScrollContainer
	return {"面": 面, "标题": 题, "滚动": 滚, "卡行": 卡行}

func _建战报栏(父: Node) -> void:
	_战报栏 = UiTheme.建面板(父, "战报栏", UiTheme.面板底, UiTheme.边框)
	_战报栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_战报栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_战报栏.custom_minimum_size = Vector2(460, 下半区高)
	_战报栏.clip_contents = true
	var 列 := UiTheme.建盒(_战报栏, "战报栏上下列", true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 按钮行 := UiTheme.建盒(列, "战斗按钮组", false, UiTheme.间距)
	_推进按钮 = UiTheme.建按钮(按钮行, "推进下一回合", _下一拍)
	_推进按钮.name = "推进按钮"
	_推进按钮.tooltip_text = "让内核真的打一个完整回合（门面 step_battle_turn()），再按 0.5 秒一步把这一回演出来"
	# ★ UX-5 第 4 项：原来的「自动打完」拆成「自动播放 / 暂停连播」+「结束并结算（= 跳过直达结算）」，
	#   另加一个「2x 加速 / 1x 正常」和一个只在演出期间露面的「跳过本回演出」。
	_自动按钮 = UiTheme.建按钮(按钮行, "自动播放", _点自动)
	_自动按钮.name = "自动按钮"
	_自动按钮.tooltip_text = "自动连播：每一回 0.5×N 秒演完 → 停 0.3 秒 → 自动推进下一回合（再点一次 = 暂停连播）"
	_倍速按钮 = UiTheme.建按钮(按钮行, "2x 加速", _点倍速)
	_倍速按钮.name = "倍速按钮"
	_倍速按钮.tooltip_text = "切换演出倍速：1x 正常 <-> 2x 加速（每步 0.5 秒 → 0.25 秒）"
	_跳过演出按钮 = UiTheme.建按钮(按钮行, "跳过本回演出", _点跳过本回演出)
	_跳过演出按钮.name = "跳过演出按钮"
	_跳过演出按钮.tooltip_text = "本回正在演：点它立刻跳到这一回的终态（不必等 0.5×N 秒）"
	_跳过演出按钮.visible = false
	_结算按钮 = UiTheme.建按钮(按钮行, "结束并结算", _点结算)
	_结算按钮.name = "结算按钮"
	_结算按钮.tooltip_text = "跳过直达结算：没打完就先 auto_finish_battle() 算完，再 finish_battle_and_settle() 进结算屏"
	_战报提示 = _建单行标签(列, "战报提示", "战报栏", UiTheme.字号_小, UiTheme.次要文字)
	_战报滚 = UiTheme.建滚动(列, "战报滚动", 战报滚动高)

# ==========================================================================================
# 阵型（读 Fm 的 8 格几何 + 门面 unit_view）
# ==========================================================================================

func _画阵型(在战斗: bool) -> void:
	if not 在战斗:
		_填一方(_我方卡, 我方, {}, false)
		_填一方(_敌方卡, 敌方, {}, false)
		return
	_填一方(_我方卡, 我方, _位号到键(我方), true)
	_填一方(_敌方卡, 敌方, _位号到键(敌方), true)

func _填一方(卡们: Array, 方: String, 占位: Dictionary, 在战斗: bool) -> void:
	for 位号 in 卡们.size():
		var 卡: UnitCard = 卡们[位号]
		if not 在战斗:
			卡.数据 = {"ok": false, "为什么": "现在不在战斗里"}
			卡.设为选中(false)
			卡.refresh()
			continue
		var 键 := str(占位.get(位号, ""))
		if 键.is_empty():
			卡.数据 = {"ok": false, "为什么": "%s 空着（这一格没有机体）" % Fm.位名(float(位号))}
			卡.设为选中(false)
			卡.refresh()
			continue
		var d := session.unit_view(方, 键)
		d["开关提示"] = _开关提示(d)
		if 方 == 敌方:
			# ★ DECK-2：单机牌组模式下敌方意图**由门面 `unit_view()` 给**（= 内核 `算意图` 的
			#   逐台预告，含目标 / 预计伤害 / 大招 / 范围）；旧口径仍然用本视图自己那条 `_敌意()`。
			if not _单机牌组():
				d["意图"] = _敌意(位号)
		elif _单机牌组():
			# ★ DECK-2：我方被瞄准提示（门面给的 `威胁` 行）—— 挂到卡片的意图行上。
			#   ★ 版面纪律：多行会按行数把 Label 的最小高度顶高（实测 5 行 = 107px，卡片会被撑到 268），
			#     所以这里**只占一行**（用「；」连起来，超长由 `clip_text` 裁掉，全文在悬停说明里）。
			var 威胁: Array = d.get("威胁") if d.get("威胁") is Array else []
			if not 威胁.is_empty():
				d["意图"] = ["；".join(威胁.map(func(x): return str(x)))]
		if str(d.get("势力", "")) == "卫星国防军":
			var 醒 := _SEED行(位号)
			if not 醒.is_empty():
				d["觉醒"] = 醒
		卡.数据 = d
		# ★ DECK-3 §1：选中态（金色醒目外框）由门面 `unit_view()["选中"]` 决定，表现层不算。
		卡.设为选中(方 == 我方 and bool(d.get("选中", false)))
		卡.refresh()

## 这一场是不是单机牌组（判据只问门面：`session.单机牌组开()`，它再问内核 `Params.单机牌组_开`）。
func _单机牌组() -> bool:
	return session != null and session.单机牌组开()

## ★ DECK-3 §1：点我方机体卡 → 门面 `select_battle_unit()`（纯表现层选择，不改内核）。
func _点选机体(单位键: String) -> void:
	if session == null:
		return
	var r := session.select_battle_unit(单位键)
	if bool(r.get("ok", false)):
		_回话("选中 【%s】：战意 %s / %s · 上排 %d 张 · 下排 %d 张" % [
			str(r.get("名", 单位键)), UiTheme.文本(r.get("战意", 0.0)),
			UiTheme.文本(Params.战意上限()), int(r.get("上排", 0)), int(r.get("下排", 0))], true)
	else:
		_回话("选不了：%s" % _为什么(r), false)
	refresh()

## `位号 → 机体键`：直接读 `battle_ctx` 的 `allies` / `enemies`（纯读，一个数都不算）。
func _位号到键(方: String) -> Dictionary:
	var out := {}
	if session == null or session.battle_ctx.is_empty():
		return out
	var 池: Variant = session.battle_ctx.get("allies") if 方 == 我方 else session.battle_ctx.get("enemies")
	if not (池 is Array):
		return out
	for x in (池 as Array):
		if x is Dictionary:
			out[int(float((x as Dictionary).get("slot", -1.0)))] = str((x as Dictionary).get("key", ""))
	return out

func _单位字典(方: String, 位号: int) -> Dictionary:
	if session == null or session.battle_ctx.is_empty():
		return {}
	var 池: Variant = session.battle_ctx.get("allies") if 方 == 我方 else session.battle_ctx.get("enemies")
	if not (池 is Array):
		return {}
	for x in (池 as Array):
		if x is Dictionary and int(float((x as Dictionary).get("slot", -1.0))) == 位号:
			return x
	return {}

## 开关按钮的文字**取短的**（"TA" / "开TA"）；当前状态在单位卡的状态行里，
## 完整原因在按钮自己的 tooltip 里。短按钮加起来也不会把卡宽撑过 132px。
## ★ UX-6（2026-10-19，作者反馈第 4 条）：**「憋大招」不再给可点按钮** ——
##   大招状态（`开关行` 里的「保留大招：开 / 关」）与冷却、武器信息仍然照常展示；
##   内核 `toggle_hold_ultimate()` / `toggle_unit_switch("保留大招")` 保留不动（防旧测试报错）。
func _开关提示(d: Dictionary) -> Dictionary:
	var out := {}
	if str(d.get("势力", "")) == "天人":
		out["TRANSAM"] = {
			"文字": "TA", "可点": true,
			"为什么": "点它 = 在「自动 / 手动」之间切换（当前值写在单位卡的状态行里）",
		}
		out["开状态"] = {
			"文字": "开TA", "可点": true,
			"为什么": "没解锁 / 冷却中 / 已经开着 → 这一下开不出来，原因会写在手牌栏下面",
		}
	return out

## 敌方下一拍行动意图预告：`Boss.bossAction()` 是内核现成的纯函数（JS `算意图()` 内层就是它）。
func _敌意(位号: int) -> Array:
	var 条: Array = []
	if session == null or session.battle_ctx.is_empty():
		return 条
	var u := _单位字典(敌方, 位号)
	if u.is_empty():
		return 条
	var ctx: Dictionary = session.battle_ctx
	var 动作: Variant = Boss.bossAction(u, ctx)
	if not (动作 is Dictionary):
		条.append("下一拍：这一拍打不到人")
	else:
		var a: Dictionary = 动作
		var w: Variant = a.get("weapon")
		var 目标: Variant = a.get("target")
		var 段 := "下一拍："
		if w is Dictionary:
			段 += "【%s】" % str((w as Dictionary).get("name", ""))
		else:
			段 += "普通攻击"
		if 目标 is Dictionary:
			段 += " → %s（%s）" % [str((目标 as Dictionary).get("name", "")),
				Fm.位名(float((目标 as Dictionary).get("slot", 0.0)))]
		var 期望 := float(a.get("expected", 0.0))
		if 期望 > 0.0:
			段 += " · 期望 %d" % int(JsCompat.js_round(期望))
		if bool(a.get("被挡", false)):
			段 += " · 被挡 -20"
		if w is Dictionary and Ai.isUltimate(w):
			段 += " · 大招"
		if bool(a.get("大技能", false)):
			段 += " · Boss 大技能"
		条.append(段)
		var 落点: Array = a.get("hit") if a.get("hit") is Array else []
		if not 落点.is_empty():
			var 名们: Array = []
			for t in 落点:
				if t is Dictionary:
					名们.append(Fm.位名(float((t as Dictionary).get("slot", 0.0))))
			条.append("落点：" + "、".join(名们))
	# Boss 阶段预告（`Boss.Boss参数` 对非 Boss 返回 null）
	var 参: Variant = Boss.Boss参数(u)
	if 参 is Dictionary:
		var p: Dictionary = 参
		var 文 := "Boss 第 %d 阶段 · 伤害倍率 ×%s" % [int(float(p.get("第几阶段", 1.0))),
			UiTheme.文本(p.get("伤害倍率", 1.0))]
		var 间隔 := float(p.get("大技能间隔", 0.0))
		var 武器: Variant = p.get("大技能武器")
		if 间隔 > 0.0 and 武器 != null:
			if Boss.Boss本回合放大技能(u, ctx):
				文 += " · 这一拍放【%s】" % str(武器)
			else:
				var 下: Variant = Boss.Boss下次技能回合(u, ctx)
				if 下 != null:
					文 += " · 第 %s 回合放【%s】" % [UiTheme.文本(int(float(下))), str(武器)]
				else:
					文 += " · 蓄力中"
		条.append(文)
	return 条

## SEED 觉醒（门面 `unit_view()` 也有这两项；这里保留战斗屏自己的读法，不改既有断言）。
func _SEED行(位号: int) -> String:
	var u := _单位字典(我方, 位号)
	if u.is_empty():
		return ""
	if FacSeed.SEED已觉醒(u):
		return "SEED 已觉醒 · 觉醒值 %s" % UiTheme.文本(int(JsCompat.js_round(Fac.势力觉醒值(u))))
	var 累 := FacSeed.SEED累计(u)
	if 累 > 0.0:
		return "SEED 累计 %s" % UiTheme.文本(int(JsCompat.js_round(累)))
	return ""

# ==========================================================================================
# 手牌栏 / 候补区
# ==========================================================================================

func _画手牌(在战斗: bool) -> void:
	_清空(_手牌列表)
	_清空(_候补卡行)
	# 重画手牌把上一张牌的联动高亮一起收掉（否则会有一张机体一直亮着）。
	联动高亮([], false)
	if not 在战斗:
		_手牌标题.text = "手牌栏：现在不在战斗里。"
		_手牌气势.text = ""
		_候补文.text = "候补区：还没开战，没有候补初始牌。"
		_收新发牌提示()
		_切单机双排(false)
		return
	# ★ DECK-3：单机牌组模式下，手牌栏换成**上下双排**（旧那行战术手牌整行收起，节点留在树上）。
	var 单机 := session.单机牌组开()
	_切单机双排(单机)
	if 单机:
		_画单机双排()
		return
	var 小结 := session.turn_card_summary()
	_手牌标题.text = "手牌 %d / %d 张（初始手牌上限 %d）· 牌库剩余 %d 张 · 本回合已打出 %d 张（事实报告，内核没有张数上限）· 现在能打 %d 张 · 第 %d 回合" % [
		int(小结.get("手牌", 0)), _手牌总上限(), _初始手牌上限(), int(小结.get("牌库剩余", 0)),
		int(小结.get("本回合已打出", 0)), int(小结.get("现在能打", 0)), int(小结.get("回合", 0))]
	# ★ MITH-3 预告层：手牌栏实时显示本回合秘银连携计数（数字与「双倍连携」都取门面 `mithril_link_state()`；
	#   表现层一个数都不算）。秘银 v0.2 关着且这场没有秘银成员 / 秘银牌时**一个字都不加**（既有版面照旧）。
	var 连携态: Dictionary = session.mithril_link_state()
	var 气势文 := "我方气势 %d / %d" % [int(JsCompat.js_round(float(小结.get("气势", 0.0)))),
		int(JsCompat.js_round(Btl.气势上限()))]
	if bool(连携态.get("启用", false)) or int(连携态.get("本回合秘银牌数", 0)) > 0:
		var 连携数 := int(连携态.get("本回合秘银牌数", 0))
		if bool(连携态.get("双倍连携", false)):
			气势文 += " · 〔秘银连携：%d · 双倍连携〕" % 连携数
		else:
			气势文 += " · 〔秘银连携：%d〕" % 连携数
	_手牌气势.text = 气势文
	_画候补()
	var idx := 0
	var 新牌们: Array = []
	var 回合 := int(float(session.battle_ctx.get("turn", 1.0)))
	for c in session.hand_cards():
		if c is Dictionary:
			if _是新发牌(c, 回合):
				新牌们.append(c)
			_建手牌卡(c, idx)
			idx += 1
	if _手牌列表.get_child_count() == 0:
		UiTheme.建标签(_手牌列表, "手牌是空的 —— 推进一回合，候补初始牌会按序补进来。", UiTheme.字号_小, UiTheme.弱文字)
	_刷新新发牌提示(新牌们)

## ★ DECK-3：切换「旧那行战术手牌」与「单机双排」的可见性（两套节点都常驻，只换显隐）。
## 这样 `find_child("手牌列表" / "候补区")` 在任何时候都找得到（smoke 段 4 的断言照旧）。
func _切单机双排(单机: bool) -> void:
	if _手牌滚动 != null:
		_手牌滚动.visible = not 单机
	if _候补区 != null:
		_候补区.visible = not 单机
	if _专属排 != null:
		_专属排.visible = 单机
	if _公有排 != null:
		_公有排.visible = 单机

## ★ DECK-3：画上下双排。数字**全部来自门面** `deck_turn_summary()` / `upper_hand_cards()` /
## `lower_hand_cards()`；表现层只排版，不判「能不能打」（`可打` / `原因` 是门面给的）。
func _画单机双排() -> void:
	_清空(_专属排列表)
	_清空(_公有排列表)
	_收新发牌提示()
	var 结 := session.deck_turn_summary()
	var 回合 := int(结.get("回合", 0))
	var 选名 := str(结.get("选中名", ""))
	var 职业 := str(结.get("选中职业", ""))
	var 势力 := str(结.get("选中势力", ""))
	var 战意 := int(JsCompat.js_round(float(结.get("战意", 0.0))))
	var 上限 := int(JsCompat.js_round(float(结.get("战意上限", 100.0))))
	_手牌标题.text = "第 %d 回合 · 阶段 %s · 选中 %s（%s·%s）· 战意 %d / %d · 本回合已打出 %d 张" % [
		回合, _阶段中文(str(结.get("阶段", ""))), 选名 if not 选名.is_empty() else "—",
		职业, 势力, 战意, 上限, int(结.get("本回合已打出", 0))]
	_手牌气势.text = "上排 %d 张（能打 %d）· 下排 %d 张（能打 %d）· 我方气势 %d / %d" % [
		int(结.get("上排", 0)), int(结.get("上排能打", 0)), int(结.get("下排", 0)), int(结.get("下排能打", 0)),
		int(JsCompat.js_round(float(结.get("气势", 0.0)))), int(JsCompat.js_round(Btl.气势上限()))]
	if _专属排标题 != null:
		_专属排标题.text = "【当前选中机体：%s（%s·%s）· 战意 %d / %d】专属排　左【主武器卡】中【衍生攻击卡】右【专属精神牌】" % [
			选名 if not 选名.is_empty() else "未选中", 职业, 势力, 战意, 上限]
	if _公有排标题 != null:
		_公有排标题.text = "【全队公有排（势力牌 / 职业牌 / 统帅牌 / 公共衍生牌）】%s" % (
			"　当前指挥机：公有牌战意 -5" if 职业 == "指挥" else "")
	var 上 := session.upper_hand_cards()
	var 下 := session.lower_hand_cards()
	var i := 0
	for c in 上:
		if c is Dictionary:
			_建单机卡(_专属排列表, c, true, i)
			i += 1
	if _专属排列表.get_child_count() == 0:
		UiTheme.建标签(_专属排列表, "这一台现在没有专属牌（先点一张我方机体卡）", UiTheme.字号_小, UiTheme.弱文字)
	i = 0
	for c in 下:
		if c is Dictionary:
			_建单机卡(_公有排列表, c, false, i)
			i += 1
	if _公有排列表.get_child_count() == 0:
		UiTheme.建标签(_公有排列表, "公有手牌是空的（每回合初抽 1 张）", UiTheme.字号_小, UiTheme.弱文字)

## 阶段代码 → 中文（只做展示，不改状态）。
func _阶段中文(阶段: String) -> String:
	match 阶段:
		"PLAYER_START":
			return "我方阶段开始"
		"PLAYER_MAIN":
			return "我方阶段"
		"ENEMY_PHASE":
			return "敌方阶段"
	return 阶段 if not 阶段.is_empty() else "—"

## ★ DECK-3：一张单机手牌卡（紧凑两行：牌名按钮 + 状态行）。
## `上排 = true` 时按 `区` 上色：主武器卡金 / 衍生攻击卡青 / 专属精神牌紫；
## 下排公有牌：对口 = 亮边、不对口 = 灰边 + `〔需：XX〕`（原因文字就是门面给的原文）。
func _建单机卡(父: Node, c: Dictionary, 上排: bool, idx: int) -> void:
	var 区 := str(c.get("区", ""))
	var 可打 := bool(c.get("可打", false))
	var 原因 := str(c.get("原因", ""))
	var 边色 := UiTheme.边框
	var 主色 := UiTheme.禁用文字
	if 可打:
		边色 = UiTheme.高亮
		主色 = UiTheme.高亮
	if 区 == "衍生攻击卡":
		边色 = UiTheme.连携色 if 可打 else UiTheme.边框
		主色 = UiTheme.连携色 if 可打 else UiTheme.禁用文字
	elif 区 == "专属精神牌":
		边色 = UiTheme.希望色 if 可打 else UiTheme.边框
		主色 = UiTheme.希望色 if 可打 else UiTheme.禁用文字
	elif 区 == "公有牌":
		边色 = UiTheme.边框_亮 if 可打 else UiTheme.边框
		主色 = UiTheme.高亮 if 可打 else UiTheme.禁用文字
	var 卡 := PanelContainer.new()
	卡.name = ("专属卡%d" if 上排 else "公有卡%d") % (idx + 1)
	卡.custom_minimum_size = Vector2(单机卡宽, 0)
	卡.clip_contents = true
	卡.add_theme_stylebox_override("panel", UiTheme.底样式(
		UiTheme.卡片底_亮 if 可打 else UiTheme.卡片底, 边色, 2 if 可打 else 1))
	父.add_child(卡)
	var 列 := UiTheme.建盒(卡, "单机卡内容", true, 1)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 名 := str(c.get("名", ""))
	var 键 := str(c.get("手牌键", 名))
	var 按 := UiTheme.建按钮(列, 名, _点单机卡.bind(区, 键, 上排))
	按.name = "单机卡按钮"
	按.disabled = not 可打
	按.tooltip_text = str(c.get("描述", "")) if not str(c.get("描述", "")).is_empty() else 原因
	按.add_theme_color_override("font_color", 主色)
	按.add_theme_color_override("font_disabled_color", UiTheme.禁用文字)
	按.add_theme_font_size_override("font_size", UiTheme.字号_小)
	var 副 := _单机卡副行(c, 区)
	var l := _建单行标签(列, "单机卡状态", 副, UiTheme.字号_小, 主色)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	卡.mouse_filter = Control.MOUSE_FILTER_PASS
	HoverTooltip.bind(按, _单机卡悬停(c, 区), "战术牌")
	HoverTooltip.bind(卡, _单机卡悬停(c, 区), "战术牌")

## 单机卡的第二行（一行写清：费用 + 状态 / 原因）。
func _单机卡副行(c: Dictionary, 区: String) -> String:
	var 费 := int(JsCompat.js_round(float(c.get("战意", 0.0))))
	var 原因 := str(c.get("原因", ""))
	if 区 == "主武器卡":
		var 状 := "〔主武就绪〕"
		if not bool(c.get("可打", false)):
			# ★ DECK-3 §2：本回合打过了 → 所有主武器卡标「〔本回合已销毁〕」并置灰。
			if 原因.contains("销毁"):
				状 = "〔本回合已销毁〕"
			elif 原因.contains("冷却"):
				状 = "〔冷却中〕"
			else:
				状 = "〔打不出来〕"
		elif bool(c.get("单机牌组_铁壁")):
			状 = "〔铁壁护卫〕"
		elif bool(c.get("是修理")):
			状 = "〔紧急修理〕"
		return "战意 %d · %s · %s" % [费, 状, 原因]
	if 区 == "衍生攻击卡":
		return "〔衍生·不毁主武〕战意 %d · %s" % [费, 原因]
	if 区 == "公有牌":
		var 减 := int(JsCompat.js_round(float(c.get("减费", 0.0))))
		if 减 > 0:
			return "战意 %d（原 %d，指挥 -%d）· %s" % [费, int(JsCompat.js_round(float(c.get("原费", 0.0)))), 减, 原因]
		return "战意 %d · %s%s" % [费, ("〔衍生〕" if bool(c.get("是衍生", false)) else ""), 原因]
	return "战意 %d · %s" % [费, 原因]

## 单机卡的悬停说明（整张牌：区 / 费用 / 状态 / 描述 / 归属）。
func _单机卡悬停(c: Dictionary, 区: String) -> String:
	var 段: Array = []
	段.append("【%s】%s" % [区, str(c.get("名", ""))])
	段.append("战意消耗：%d" % int(JsCompat.js_round(float(c.get("战意", 0.0)))))
	if c.get("归属") != null and not str(c.get("归属", "")).is_empty():
		段.append("归属：%s（%s）" % [str(c.get("归属", "")), str(c.get("层级", ""))])
	var 描 := str(c.get("描述", ""))
	if not 描.is_empty():
		段.append(描)
	段.append("现在：%s（%s）" % ["能打" if bool(c.get("可打", false)) else "打不了", str(c.get("原因", ""))])
	return "\n".join(段)

## ★ DECK-3：点一张单机手牌 → 立刻走内核那三个口子之一，然后**马上播这一下的 0.5 秒演出**。
func _点单机卡(区: String, 键: String, 上排: bool) -> void:
	if session == null:
		return
	var 前日志 := session.battle_log_entries(0).size()
	var 前手 := _手牌快照()
	var r := {}
	if 区 == "主武器卡":
		r = session.play_unit_main_weapon(键)
	elif 区 == "衍生攻击卡":
		r = session.play_unit_derived_card(键)
	else:
		r = session.play_unit_spirit_or_public_card(键)
	if not bool(r.get("ok", false)):
		_回话("打不出来：%s" % _为什么(r), false)
		refresh()
		return
	_回话("打出【%s】（战意 %s → %s）" % [str(session.last.get("牌", 键)),
		UiTheme.文本(session.last.get("战意前", 0.0)), UiTheme.文本(session.last.get("战意后", 0.0))], true)
	_演本拍新增(前日志, 前手)

## ★ DECK-3 ③：**每次打牌立即播放 0.5s 单步攻击动画**（复用 UX-5 的串行演出队列）。
## `前日志` = 打牌之前的日志条数；`前手` = 打牌之前的手牌快照（发牌帧要用差集）。
## headless 下队列同步播完（不建定时器），`_已播帧数` 仍然记满，自动化测试直接查。
func _演本拍新增(前日志: int, 前手: Array) -> void:
	var 全部 := session.battle_log_entries(0)
	var 新增: Array = 全部.slice(前日志, 全部.size()) if 前日志 < 全部.size() else []
	var 后手 := _手牌快照()
	_标记日志已播到末尾()
	_构建演出队列(新增, 前手, 后手)
	_演出跳过请求 = false
	refresh()
	_消费演出队列()


## ★ UX-2 第 3 项：这张牌是不是**本拍刚发进来的**。
## 判据全来自内核字段（纯读）：`新触发 == true` 且 `触发回合 == 当前回合`。
## 开局就在手上的初始牌没有这两个值（`新触发 = false`），所以不会误挂【新发牌】。
func _是新发牌(c: Dictionary, 回合: int) -> bool:
	if not bool(c.get("新触发", false)):
		return false
	var t: Variant = c.get("触发回合")
	return t != null and int(float(t)) == 回合

## ★ UX-2 第 3 项：把手牌栏顶部那条提示条写成
## `【新发牌】获得战术牌【牌名】（来自：XXX）`；没有新牌就收起来（不占高度）。
func _刷新新发牌提示(新牌们: Array) -> void:
	if _新发牌提示 == null:
		return
	if 新牌们.is_empty():
		_收新发牌提示()
		return
	var 段: Array = []
	for c in 新牌们.slice(0, 3):
		段.append("【%s】（%s）" % [str((c as Dictionary).get("名", "")),
			str((c as Dictionary).get("source_unit_text", ""))])
	var 多 := ""
	if 新牌们.size() > 3:
		多 = " 等 %d 张" % 新牌们.size()
	_新发牌提示.text = "【新发牌】获得战术牌%s%s" % ["、".join(段), 多]
	_新发牌提示.visible = true

func _收新发牌提示() -> void:
	if _新发牌提示 == null:
		return
	_新发牌提示.text = ""
	_新发牌提示.visible = false

## ★ D-01 的地方：候补初始牌的数量 + 列表（带层级），让作者一眼看出「谁开局在手、谁在排队」。
## `候补文` 的文本**照旧是原来那段汇总文字**（smoke 逐字查它）；另外每张候补牌再给一个小标签，
## 挂 `session.card_hover_text()` 的悬停说明。
func _画候补() -> void:
	var 候 := session.reserve_preview()
	if 候.is_empty():
		_候补文.text = "候补初始牌：0 张 —— 初始牌全部进了手牌（没有超出「初始手牌上限」的）。"
		return
	var 名们: Array = []
	for c in 候:
		if c is Dictionary:
			名们.append("【%s】%s" % [str((c as Dictionary).get("名", "")), str((c as Dictionary).get("层级", ""))])
	_候补文.text = "候补初始牌：%d 张（%s）\n%s" % [候.size(),
		"开局超出初始手牌上限的初始牌，每回合开始手牌有空位就按序补进来", "、".join(名们)]
	for i in 候.size():
		var c: Variant = 候[i]
		if not (c is Dictionary):
			continue
		var 牌: Dictionary = c
		var b := UiTheme.建按钮(_候补卡行, str(牌.get("名", "")), _点候补.bind(str(牌.get("id", ""))))
		b.name = "候补卡%d" % (i + 1)
		b.add_theme_font_size_override("font_size", UiTheme.字号_小)
		b.tooltip_text = "【%s】%s" % [str(牌.get("层级", "")), str(牌.get("效果说明", ""))]
		# ★ Mouse Over：整张牌的说明
		HoverTooltip.bind(b, session.card_hover_text(牌), "战术牌")
		# ★ UX-2 第 2 项：候补牌也在卡面写清「这张牌是谁带来的」+ 悬停联动高亮场上机体。
		候补联动(b, 牌)
		var 源 := str(牌.get("source_unit_text", ""))
		if not 源.is_empty():
			var 源标 := UiTheme.建标签(_候补卡行, "【%s】" % 源, UiTheme.字号_小, UiTheme.推进剂色)
			源标.name = "候补来源%d" % (i + 1)
			源标.mouse_filter = Control.MOUSE_FILTER_PASS
			HoverTooltip.bind(源标, session.card_hover_text(牌), "战术牌")
			候补联动(源标, 牌)

## 给一张候补牌控件挂上「悬停 → 点亮来源机体」的两条信号（进 / 出）。
func 候补联动(控件: Control, 牌: Dictionary) -> void:
	if 控件 == null:
		return
	var 位们: Array = 牌.get("source_slots") if 牌.get("source_slots") is Array else []
	控件.mouse_filter = Control.MOUSE_FILTER_PASS
	控件.mouse_entered.connect(_悬停来源.bind(位们))
	控件.mouse_exited.connect(_移开来源)

## 候补区里的小标签点了不做事（候补牌得等内核按回合补进手牌）—— 只把原因说清楚。
func _点候补(_id: String) -> void:
	_回话("候补初始牌要等内核按回合补进手牌（手牌上限 %d）；现在能打的只有手牌里的牌。" % _手牌总上限(), false)
	refresh()

func _建手牌卡(c: Dictionary, idx: int = -1) -> void:
	var id := str(c.get("id", ""))
	# ★ MITH-3：传**卡牌字典**而不是 id —— 手里两张同名 TDD-1 衍生牌时，状态按 `_实例号` 各算各的。
	var 状 := session.hand_card_status(c)
	var 可打 := bool(状.get("可打", false))
	var 原因 := str(状.get("原因", ""))
	var 亮边 := bool(状.get("可连携亮边", false))
	var 衍生 := bool(c.get("衍生", false))
	var 卡 := PanelContainer.new()
	卡.name = "手牌卡%d" % ((idx + 1) if idx >= 0 else (_手牌列表.get_child_count() + 1))
	卡.custom_minimum_size = Vector2(手牌卡宽, 0)
	卡.clip_contents = true
	# ★ UX-2 第 3 项：本拍刚发进来的牌 → 挂【新发牌】亮框（金色 2px，比「可打」更醒目）。
	#   判据与手牌栏顶部那条提示条同一个（`_是新发牌()`），不另立口径。
	var 新牌 := _是新发牌(c, int(float(session.battle_ctx.get("turn", 1.0))))
	# ★ MITH-3 预告层：可连携的牌给 2px `UiTheme.高亮` 金色亮边（连携就绪 + 可打）。
	#   没就绪时照旧：可打 = 1px 高亮边，打不出来 = 普通边框。
	if 亮边 or 新牌:
		卡.add_theme_stylebox_override("panel", UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 2))
	else:
		卡.add_theme_stylebox_override("panel", UiTheme.底样式(
			UiTheme.卡片底_亮 if 可打 else UiTheme.卡片底,
			UiTheme.高亮 if 可打 else UiTheme.边框))
	_手牌列表.add_child(卡)
	# ★ UX-2 第 2 项：悬停这张牌 → 场上带出它的机体亮起青色联动框（移开就灭）。
	var 源位们: Array = c.get("source_slots") if c.get("source_slots") is Array else []
	卡.mouse_filter = Control.MOUSE_FILTER_PASS
	卡.mouse_entered.connect(_悬停来源.bind(源位们))
	卡.mouse_exited.connect(_移开来源)
	var 列 := UiTheme.建盒(卡, "手牌内容", true, 2)
	# ★ 点击键：有 `_实例号` 就传实例号（内核按实例号精确找牌，绝不打错同名衍生牌）；
	#   没有（旧数据 / 非 v0.2）就退回 id —— 与改前一致。
	var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
	var 牌键 := str(实例) if 实例 > 0 else id
	var 按 := UiTheme.建按钮(列, str(c.get("名", "")), _点手牌.bind(牌键))
	按.name = "手牌按钮"
	按.disabled = not 可打
	按.tooltip_text = str(c.get("效果说明", ""))
	按.add_theme_color_override("font_color", UiTheme.高亮 if 可打 else UiTheme.禁用文字)
	按.add_theme_color_override("font_disabled_color", UiTheme.禁用文字)
	# ★ 按钮吃掉了鼠标事件（`Button` 是 STOP），所以「进入」这条联动信号这里再挂一次；
	#   离开只认外层那张卡（移到卡内别的标签上不算离开）。
	按.mouse_entered.connect(_悬停来源.bind(源位们))
	# ★ 悬停说明（整张牌：耗气 / 回气 / 冷却 / 限次 / 触发 / 效果 / 当前手牌状态 + 来源机体）
	var 悬停 := session.card_hover_text(c)
	HoverTooltip.bind(按, 悬停, "战术牌")
	HoverTooltip.bind(卡, 悬停, "战术牌")
	# ★ UX-2 第 2 项：卡面醒目位置写清「这张牌是谁带来的」。
	var 源文 := str(c.get("source_unit_text", ""))
	if not 源文.is_empty():
		var 源标 := _建单行标签(列, "手牌来源", "【%s】" % 源文, UiTheme.字号_小, UiTheme.推进剂色)
		源标.name = "手牌来源"
		HoverTooltip.bind(源标, 悬停, "战术牌")
	# ★ UX-2 第 3 项：本拍新发牌的角标。
	if 新牌:
		var 新标 := _建单行标签(列, "新发牌角标", "【新发牌】", UiTheme.字号_小, UiTheme.高亮)
		新标.name = "新发牌角标"
	# 层级 / 耗气 / 冷却 / 剩余 —— **单行裁切**（不换行、不撑高度；全文在悬停说明里）
	_建单行标签(列, "手牌层级", "%s · 耗气 %s · 回气 %s · 冷却 %s 回合 · 剩余 %s 次" % [
		_层级文字(c), UiTheme.文本(int(JsCompat.js_round(float(状.get("耗气", 0.0))))),
		UiTheme.文本(int(JsCompat.js_round(float(状.get("回气", 0.0))))),
		UiTheme.文本(状.get("冷却", 0)), UiTheme.文本(状.get("剩余", 0))], UiTheme.字号_小, UiTheme.次要文字)
	# ★ MITH-3：连携就绪 / 衍生牌两个醒目小标签（颜色取 `UiTheme` 常量，别写死）。
	if 亮边:
		var 就绪 := _建单行标签(列, "连携就绪", "【连携就绪】", UiTheme.字号_小, UiTheme.高亮)
		就绪.name = "连携就绪"
	if 衍生:
		var 衍生标 := _建单行标签(列, "衍生牌", "【衍生牌】", UiTheme.字号_小, UiTheme.希望色)
		衍生标.name = "衍生牌"
	# ★ 置灰的原因 = 门面 hand_card_status()["原因"] 的**原文**，一个字都不改
	_建单行标签(列, "手牌原因", "【%s】%s" % [原因, str(c.get("效果说明", ""))],
		UiTheme.字号_小, UiTheme.高亮 if 可打 else UiTheme.禁用文字)

func _层级文字(c: Dictionary) -> String:
	var 层 := str(c.get("层级", ""))
	var 归 := str(c.get("归属", ""))
	if 归.is_empty():
		return 层 if not 层.is_empty() else "基础"
	return "%s·%s" % [层, 归]

# ==========================================================================================
# ★ UX-2 第 2 项：卡牌 → 场上机体的**联动高亮**（纯表现，零状态修改）
# ==========================================================================================

## 把 `位们`（位名数组，例如 `["前1", "后2"]`）对应到我方阵型里的 `UnitCard` 并点亮 / 熄灭。
## 有牌在手就要能一眼看懂「这张牌是谁带来的」—— 悬停手牌 / 候补牌时调用它。
## `on = false` 时**一律全灭**（不按 `位们` 过滤），这样「移开」永远收得干净。
func 联动高亮(位们: Array, on: bool) -> void:
	var 集 := {}
	for x in 位们:
		集[str(x)] = true
	for i in _我方卡.size():
		var 卡: Variant = _我方卡[i]
		if not (卡 is UnitCard) or not is_instance_valid(卡):
			continue
		(卡 as UnitCard).set_card_source_highlight(on and 集.has(Fm.位名(float(i))))

## 悬停一张手牌 / 候补牌 → 点亮它 `source_slots` 上的我方机体。
func _悬停来源(位们: Array) -> void:
	联动高亮(位们, true)

## 鼠标离开 → 全部熄灭。
func _移开来源() -> void:
	联动高亮([], false)

## 手牌总上限 / 初始手牌上限：纯读数据目录（不写死数字）
func _手牌总上限() -> int:
	var v: Variant = _卡牌参数().get("手牌总上限")
	return int(float(v)) if v != null else 10
func _初始手牌上限() -> int:
	var v: Variant = _卡牌参数().get("初始手牌上限")
	return int(float(v)) if v != null else 6
func _卡牌参数() -> Dictionary:
	var b := Db.catalog.battle_config()
	var t: Variant = b.get("战术卡牌")
	return t if t is Dictionary else {}

# ==========================================================================================
# 战报栏（即时那一层）
# ==========================================================================================

func _画战报(在战斗: bool) -> void:
	_清空(_战报滚)
	if not 在战斗:
		_战报提示.text = "战报栏：现在不在战斗里。"
		_推进按钮.disabled = true
		_自动按钮.disabled = true
		_结算按钮.disabled = true
		if _倍速按钮 != null:
			_倍速按钮.disabled = true
		if _跳过演出按钮 != null:
			_跳过演出按钮.disabled = true
		return
	var 打完 := session.battle_ctx.get("result") != null
	var 小结 := session.turn_card_summary()
	if _单机牌组():
		var 单结 := session.deck_turn_summary()
		_战报提示.text = "第 %d 回合 · %s · 选中 %s（战意 %d / %d）· 上排 %d 张（能打 %d）· 下排 %d 张（能打 %d）%s" % [
			int(单结.get("回合", 0)), _阶段中文(str(单结.get("阶段", ""))), str(单结.get("选中名", "")),
			int(JsCompat.js_round(float(单结.get("战意", 0.0)))), int(JsCompat.js_round(float(单结.get("战意上限", 100.0)))),
			int(单结.get("上排", 0)), int(单结.get("上排能打", 0)), int(单结.get("下排", 0)), int(单结.get("下排能打", 0)),
			"  · 这一场已经打完了，点「结束并结算」" if 打完 else ""]
	else:
		_战报提示.text = "第 %d 回合 · 本回合已打出 %d 张 · 现在能打 %d 张 · 手牌 %d · 候补 %d · 本场已打出 %d 张%s" % [
			int(小结.get("回合", 0)), int(小结.get("本回合已打出", 0)), int(小结.get("现在能打", 0)),
			int(小结.get("手牌", 0)), int(小结.get("候补", 0)), int(小结.get("本场已打出", 0)),
			"  · 这一场已经打完了，点「结束并结算」" if 打完 else ""]
	_推进按钮.disabled = 打完
	_自动按钮.disabled = 打完
	# ★ UX-5：倍速随时可切；「跳过本回演出」只在真的在演时可点（平时根本不可见）。
	if _倍速按钮 != null:
		_倍速按钮.disabled = false
	if _跳过演出按钮 != null:
		_跳过演出按钮.disabled = not _演出进行中
	# ★ 修复「点击结算没有反应」：从前这里是 `_结算按钮.disabled = not 打完`，于是战斗还没
	#   分出胜负时按钮被置灰、`pressed` 信号根本不触发（作者点了没反应就是这么来的）。
	#   现在判据改成「在不在战斗里」—— 只要在战斗里就永远可点；点下去会自动打完再结算。
	_结算按钮.disabled = not (session != null and session.in_battle())
	# 结构化日志（要按「类型」高亮）；文本用门面给的那一份，不自己拼
	var 条们 := session.battle_log_entries(60)
	var 行们 := session.battle_log_lines(60)
	if 条们.is_empty():
		UiTheme.建标签(_战报滚, "还没有战报 —— 点「推进下一回合」开打。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in 条们.size():
		var e: Dictionary = 条们[i] if 条们[i] is Dictionary else {}
		var 文 := str(行们[i]) if i < 行们.size() else str(e.get("文本", ""))
		var 色 := _日志色(e)
		var l := UiTheme.建说明(_战报滚, 文, UiTheme.字号_正文 if _是高亮(e) else UiTheme.字号_小, 色)
		l.name = "战报行%d" % (i + 1)

## 高亮判据全部来自日志条目自己的字段（只读字段，不编）：
## `类型` = 战术牌 / 势力 / Boss / 发牌（`触发条件码 == "候补补位"` 就是补位）。
func _日志色(e: Dictionary) -> Color:
	var 类 := str(e.get("类型", ""))
	var 文 := str(e.get("文本", ""))
	if 类 == "战术牌":
		return UiTheme.高亮
	if 类 == "势力":
		return UiTheme.希望色
	if 类 == "Boss":
		return UiTheme.负面
	if 类 == "发牌":
		if str(e.get("触发条件码", "")) == "候补补位" or 文.contains("候补"):
			return UiTheme.推进剂色
		return UiTheme.次要文字
	if 类 == "回合" or 类 == "开始" or 类 == "结束":
		return UiTheme.主文字
	return UiTheme.次要文字

func _是高亮(e: Dictionary) -> bool:
	var 类 := str(e.get("类型", ""))
	return 类 == "战术牌" or 类 == "势力" or 类 == "Boss" or 类 == "回合"

# ==========================================================================================
# 动作（一律调门面命令；失败就把 why 显示出来）
# ==========================================================================================

func _点手牌(id: String) -> void:
	if session == null:
		return
	var r := session.play_tactical_card(id)
	if bool(r.get("成功", false)):
		_回话("打出【%s】：%s（本回合已打出 %d 张）" % [str(session.last.get("牌名", id)),
			str(session.last.get("效果摘要", "")), session.cards_played_this_turn()], true)
	else:
		_回话("打不出来：%s" % _为什么(r), false)
	refresh()

func _点开关(单位键: String, 开关键: String) -> void:
	if session == null:
		return
	if session.toggle_unit_switch(单位键, 开关键):
		_回话("已切【%s】的「%s」→ %s" % [单位键, 开关键, str(session.last.get("值", ""))], true)
	else:
		_回话("开关点不动：%s" % _为什么(session.last), false)
	refresh()

func _点开状态(单位键: String) -> void:
	if session == null:
		return
	if session.activate_unit_state(单位键):
		_回话("%s 的 TRANS-AM 开了（第 %s 回合起）" % [单位键, UiTheme.文本(session.last.get("启动回合", 0.0))], true)
	else:
		_回话("开不出来：%s" % _为什么(session.last), false)
	refresh()

## 点「推进下一回合（下一拍）」：真的推一回合，然后把**本拍新增日志**拆成串行演出帧播出去。
## ★ UX-5：从前这里推完就直接 `refresh()` —— 十几条攻击 / 受击 / 发牌事件在同一帧叠画，
##   0.7 秒内一锅粥闪完（作者反馈第 2 条）。现在改成 `0.5 秒 × N` 的一帧一帧演。
func _下一拍() -> void:
	if session == null:
		return
	if _演出进行中:
		_回话("这一回还在演（%d/%d 帧）—— 想直接看终态就点「跳过本回演出」" % [_已播帧数, _当前演出总帧数], false)
		refresh()
		return
	if session.battle_ctx.get("result") != null:
		_点结算()
		return
	# 上一回的残留（正常情况下已经播完）先收干净，再拍这一拍。
	_表演中止(false)
	var 前 := int(float(session.battle_ctx.get("turn", 1.0)))
	# ★ 发牌帧要「本拍前后手牌差集」：推之前先拍一张快照（纯读，`hand_cards()` 已经是深拷贝）。
	var 前手 := _手牌快照()
	var 前日志 := session.battle_log_entries(0).size()
	# ★ 预热窗：`step_battle_turn()` 里的 `changed.emit()` 会顺手 `refresh()` 一次，
	#   这时队列还没建好 —— 让它别把这批事件一次性叠画出来。
	_演出预热 = true
	# ★ DECK-3 ③：单机牌组模式下这颗按钮叫「结束我方回合」——推的是内核 `Btl.结束我方回合`
	#   （Step A 未操作机体 AI 补打 → Step B 敌方 0..7 → Step C 下一回合）。旧口径照旧推一整回合。
	var 单机 := _单机牌组()
	var r := session.end_player_turn() if 单机 else session.step_battle_turn()
	_演出预热 = false
	if not bool(r.get("ok", true)):
		_回话("推不动：%s" % _为什么(r), false)
		refresh()
		return
	var 后 := int(float(session.battle_ctx.get("turn", 1.0)))
	var 全部 := session.battle_log_entries(0)
	var 新增: Array = 全部.slice(前日志, 全部.size()) if 前日志 < 全部.size() else []
	var 后手 := _手牌快照()
	# ★ 先把「已播」推到日志末尾：否则下面 `refresh()` 里的 `_画战斗动画()` 会把这**一整批**
	#   事件一次性叠在同一帧画出来 —— 正是作者反馈「一锅粥闪完」的那条老路。
	_标记日志已播到末尾()
	_构建演出队列(新增, 前手, 后手)
	_演出跳过请求 = false
	if 单机:
		_回话("结束我方回合（现在第 %d 回合）· 上排 %d 张 / 下排 %d 张 · 这一回要演 %d 步" % [
			后, session.upper_hand_cards().size(), session.lower_hand_cards().size(), _演出队列.size()], true)
	else:
		_回话("第 %d 回合打完了（现在第 %d 回合）· 本回合已打出 %d 张 · 现在能打 %d 张 · 这一回要演 %d 步" % [
			前, 后, session.cards_played_this_turn(), session.cards_playable_now(), _演出队列.size()], true)
	refresh()
	_消费演出队列()

## 兼容旧名字（既有调用点 / 测试仍可以叫 `_点推进()`）。
func _点推进() -> void:
	_下一拍()

## 「自动播放 / 暂停连播」（★ UX-5 第 4 项）：原来的「自动打完」拆出来的那一半。
## 开启后（非 headless）：不在演出中时立刻推一拍；每一回 `0.5×N` 演完且战斗没结束，
## 停 `连播停顿秒` 再自动接下一次 `_下一拍()`。headless 下不开定时连锁（否则一次点击会把整场同步跑完）。
func _点自动() -> void:
	if session == null:
		return
	if session.battle_ctx.get("result") != null:
		_点结算()
		return
	_自动连播开启 = not _自动连播开启
	_刷新控制按钮()
	var 推进名 := "结束我方回合" if _单机牌组() else "推进下一回合"
	if not _自动连播开启:
		_回话("已暂停连播：想继续就点「%s」或再开「自动播放」" % 推进名, true)
		refresh()
		return
	if UiTheme.无声模式():
		# headless：不做定时连锁，但仍然推进一拍 —— 测试照样能检查 `_演出队列` 的拆帧结果。
		_回话("自动播放已开（headless：这一拍立即同步播完，不做定时连锁）", true)
		_下一拍()
		return
	if _演出进行中:
		_回话("自动播放已开：这一回演完就接下一回合", true)
	else:
		_回话("自动播放已开：每一拍按 0.5 秒一步顺着演；再点一次 = 暂停连播", true)
		_下一拍()

## 「2x 加速 / 1x 正常」（★ UX-5 第 4 项）：切 `_演出倍速`（1.0 <-> 2.0）。
func _点倍速() -> void:
	_演出倍速 = 1.0 if _演出倍速 > 1.5 else 2.0
	_刷新控制按钮()
	_回话("演出倍速：%s（每步 %.2f 秒）" % ["2x 加速" if _演出倍速 > 1.5 else "1x 正常",
		STEP_DURATION / _演出倍速], true)
	refresh()

## 「跳过本回演出」：不等剩下的帧，直接跳到这一回的终态（不改战斗结果）。
func _点跳过本回演出() -> void:
	if not _演出进行中:
		_回话("现在没有正在演的回合 —— 点「%s」才会开始演" % ("结束我方回合" if _单机牌组() else "推进下一回合"), false)
		refresh()
		return
	_演出跳过请求 = true
	_回话("已请求跳过这一回剩下的帧（直接到终态）", true)
	refresh()

## ★ UX-5 第 4 项：「跳过直达结算」—— 不想看动画时一键算完进结算。
## （控制栏那颗「结束并结算」走的就是这条路；`_点结算()` 本身也会先 `auto_finish_battle()`。）
func _跳过直达结算() -> void:
	if session == null:
		return
	_表演中止()
	_自动连播开启 = false
	if session.battle_ctx is Dictionary and session.battle_ctx.get("result") == null:
		session.auto_finish_battle()
	_回话("跳过演出、直接结算：%s · 一共打了 %s 个回合" % [session.战果文字(),
		UiTheme.文本(session.last.get("回合数", 0))], true)
	_点结算()

## 「自动打完」的旧名字（保留兼容）：headless / 旧调用点仍然可以叫它 = 跳过直达结算。
func _点自动打完() -> void:
	_跳过直达结算()

## 同上（规格里点名的那个旧名字）。
func _自动打完() -> void:
	_跳过直达结算()

func _点结算() -> void:
	if session == null:
		return
	# ★ UX-5：结算 = 这一回的演出到此为止（旧协程看到 `_演出序号` 变了会自己退出）。
	_表演中止(false)
	_自动连播开启 = false
	_刷新控制按钮()
	# ★ 修复「点击结算没有反应」（2026-10-16 作者试玩反馈）：这一场还没产生结果时
	#   **先自动把本场打完**（`auto_finish_battle()` 带护栏，内核口径），再走战后结算。
	#   从前这里直接 `_回话("这一场还没打完…")` 就返回了 —— 玩家看到的就是「点了没反应」。
	# ★ UX-5：这中间会 `changed.emit()` → `refresh()` 一次；用预热窗挡住一次性叠画。
	_演出预热 = true
	if session.battle_ctx is Dictionary and session.battle_ctx.get("result") == null:
		session.auto_finish_battle()
	_演出预热 = false
	if _已结算:
		refresh()
		return
	var r := session.finish_battle_and_settle()
	if not bool(r.get("ok", true)):
		_回话("结算没做成：%s" % _为什么(r), false)
		refresh()
		return
	_已结算 = true
	# `finish_battle_and_settle()` 已经 `_set_screen("result")` —— 壳收到 `changed` 就路由到结算屏。
	_回话("战后已结算：%s（屏幕已经切到结算屏）" % str(session.result_summary().get("结果", "")), true)
	refresh()

# ==========================================================================================
# ★ UX-5 串行演出队列（0.5 秒/步）：拆帧 → 一帧一帧播 → 跳过 / 自动连播
#
#   数据来源**仍然只有一处**：门面 `battle_log_entries()` 里「本拍新增」的那几条事件。
#   本段一个数都不自己算：伤害 / 命中段 / 暴击 / 回复 / 剩余 HP 全部照日志条目里已有的字段；
#   机体名走 `battle_ctx` 的 `name`、位名走 `Fm.位名()`（纯读）。
#   ★ 零 RNG、零状态修改、零 `J.*`；headless 下不建任何 `create_timer` / Tween。
# ==========================================================================================

## 中止正在演的这一回：`_演出序号 + 1` → 旧协程看到序号变了就自己退出（不留野协程）。
## `清队列 = true` 时连 `_演出队列` 一起清（换场 / 空态用）；结算时传 false，把拆帧结果留给测试查。
func _表演中止(清队列: bool = true) -> void:
	_演出序号 += 1
	_演出进行中 = false
	_演出跳过请求 = false
	_帧已耗时 = 0.0
	if 清队列:
		_演出队列 = []
		_当前演出总帧数 = 0
		_已播帧数 = 0
	_刷新控制按钮()

## ★ UX-5 控制栏：按钮文字 / 可见性跟着「自动连播 / 倍速 / 正在演」走（纯表现，不调门面）。
func _刷新控制按钮() -> void:
	var 单机 := _单机牌组()
	if _推进按钮 != null:
		# ★ DECK-3 ③：单机牌组模式下「下一回合」→「结束我方回合」（旧口径一个字都不改）。
		_推进按钮.text = "结束我方回合" if 单机 else "推进下一回合"
		_推进按钮.tooltip_text = ("结束我方回合：没打过主武器的机体由 AI 补打 1 张 → 敌方按格位 0..7 依次行动 → 进入下一回合"
			if 单机 else "让内核真的打一个完整回合（门面 step_battle_turn()），再按 0.5 秒一步把这一回演出来")
	if _自动按钮 != null:
		# 「全员自动回合」= 同一件事（内核 Step A 本来就是「全员托管补打」），只换一个说人话的名字。
		var 关名 := "全员自动回合" if 单机 else "自动播放"
		_自动按钮.text = "暂停连播" if _自动连播开启 else 关名
	if _倍速按钮 != null:
		_倍速按钮.text = "1x 正常" if _演出倍速 > 1.5 else "2x 加速"
	if _跳过演出按钮 != null:
		_跳过演出按钮.visible = _演出进行中
		_跳过演出按钮.disabled = not _演出进行中

## 这一拍之前 / 之后的手牌快照（纯读；用于「内核没给逐张发牌日志」时补出 `card_deal` 帧）。
func _手牌快照() -> Array:
	var out: Array = []
	if session == null:
		return out
	for c in session.hand_cards():
		if c is Dictionary:
			out.append((c as Dictionary).duplicate(true))
	return out

## 把「已经播到第几条日志」推到当前末尾 —— 这样 `refresh()` 里的 `_画战斗动画()` 不会
## 再把这一整批事件一次性叠在同一帧画出来（那些人肉演出交给队列）。
func _标记日志已播到末尾() -> void:
	if session == null or session.battle_ctx.is_empty():
		return
	_已播日志引用 = session.battle_ctx.get("log")
	_已播日志数 = session.battle_log_entries(0).size()

## 公共拆帧入口（**单元测试可以直接调它验拆帧逻辑**，不依赖节点树 / 不依赖 headless）：
##   `entries`   = 本拍新增的战斗日志（按时间先后）
##   `prev_hand` / `curr_hand` = 这一拍前后的手牌快照（内核日志没给逐张发牌时用它补 `card_deal` 帧）
## 返回串行演出帧数组：每帧一个 Dictionary，`类别` 取
##   `card_deal`（发牌 / 每张牌 1 帧）、`attack`（攻击·大招·镜甲·连斩 / 每次出手 1 帧）、
##   `heal`（修理·治疗）、`tactic_card`（战术牌生效）、`event`（Boss / 增援 / 势力 / 击破 / 结束）。
## ★ 纯调试噪音（`回合` / `开始`）不出帧；**只要这一拍真的发了牌，就一定有 `card_deal` 帧**。
func 构建单拍演出帧(entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array:
	var 帧们: Array = []
	var 已认领: Array = []
	if entries is Array:
		for e in entries:
			if not (e is Dictionary):
				continue
			var 事件: Dictionary = e
			match str(事件.get("类型", "")):
				"发牌":
					帧们.append(_发牌帧(事件, prev_hand, curr_hand, 已认领))
				"攻击", "镜甲":
					# 攻击 / 大招 / 镜甲（反弹反击）/ 连斩追加 —— 每次出手一帧。
					帧们.append(_攻击帧(事件))
				"修理":
					帧们.append(_修理帧(事件))
				"战术牌", "连携":
					帧们.append(_战术牌帧(事件))
				"Boss", "增援", "势力", "连斩", "击破", "结束":
					帧们.append(_事件帧(事件))
				_:
					pass   # 回合 / 开始 / 纯调试噪音 → 不出独立帧
	# ★ 兜底：本拍手牌确实多了新牌，但内核没给（或只给了部分）逐张「发牌」日志 →
	#   按手牌差集补出 `card_deal` 帧，确保「只要这一拍发了牌，就有对应的发牌演出」。
	for idx in _手牌新增索引(prev_hand, curr_hand):
		if 已认领.has(idx):
			continue
		var c: Variant = curr_hand[idx]
		if not (c is Dictionary):
			continue
		帧们.append(_手牌补帧(c, idx))
	return 帧们

## 把本拍日志拆成串行演出帧并**存进 `_演出队列`**（headless 下也存 —— 自动化测试直接查它）。
func _构建演出队列(entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array:
	_演出队列 = 构建单拍演出帧(entries, prev_hand, curr_hand)
	_当前演出总帧数 = _演出队列.size()
	_已播帧数 = 0
	return _演出队列

## 队列现在有几帧 / 已经播了几帧（自动化测试与「跳过」按钮都读它）。
func 演出帧数() -> int:
	return _演出队列.size()

func 已播帧数() -> int:
	return _已播帧数

## 串行播放 `_演出队列`：一帧一帧按 `STEP_DURATION / _演出倍速` 走。
## ★ Headless：**不建任何 `create_timer` / Tween**，一帧一帧同步应用（终态写进横幅与浮字），
##   把 `_已播帧数` 记成总帧数就返回 —— 1700+ 项自动化测试照样几秒跑完。
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
		# 跳到这一回的终态：把最后一帧的横幅与浮字一次性补上（不重播前面的）。
		if not _演出队列.is_empty() and _演出队列[_演出队列.size() - 1] is Dictionary:
			_应用帧终态(_演出队列[_演出队列.size() - 1], _当前演出总帧数, _当前演出总帧数)
	_演出跳过请求 = false
	_演出进行中 = false
	_刷新控制按钮()
	# 这一场打完了 → 最后一帧演完再进结算屏（让玩家看完最后一刀）。
	if session != null and session.battle_ctx.get("result") != null:
		if not 静默 and is_inside_tree():
			await get_tree().create_timer(结算前停顿秒 / maxf(_演出倍速, 1.0)).timeout
			if 我的序号 != _演出序号:
				return
		_自动连播开启 = false
		_点结算()
		return
	refresh()
	# ★ 自动连播：这一回演完停 0.3 秒，接着自动推下一拍（战斗结束 / 暂停 / 换场就不接）。
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
		_:
			# 战术牌 / 事件帧：横幅写出来就够了（不额外改动弹道 / 卡片状态）。
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
	# 飞卡落地：手牌脉冲高亮 + 收掉横幅上的「飞行中」感（横幅仍是发牌那句）。
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
	# ---- 前段（0.00s–0.15s）：出手方亮金框 + 朝目标方向前冲 14px + 指向箭头光束 ----
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
	# ---- 后段（0.15s–0.50s）：受击方红闪 + 左右震动 + 头顶大号飘字（飘 0.65 秒）----
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

## 一帧的**终态**（headless 直接用它 / 跳过时补最后一帧）：
## 横幅 + 浮字 + 卡片反馈全部写到位，但不建任何 Tween。
func _应用帧终态(帧: Dictionary, 序: int, 总: int) -> void:
	_写演出横幅(帧, 序, 总, false)
	match str(帧.get("类别", "")):
		"card_deal":
			_上发牌终态(帧)
		"attack":
			_上动作终态(帧, false)
		"heal":
			_上动作终态(帧, true)
		_:
			pass

## 发牌帧的终态：来源卡亮青金脉冲 + 目标手牌直接落到「已获得」的脉冲余韵。
func _上发牌终态(帧: Dictionary) -> void:
	var 位 := int(帧.get("来源位", -1))
	if 位 >= 0:
		var 源卡 := _卡(我方, 位)
		if 源卡 != null:
			源卡.播放发牌脉冲()
	var 目标 := _手牌卡控件(int(帧.get("手牌索引", -1)))
	if 目标 != null:
		_脉冲手牌(目标)

## 动作帧的终态：弹道 + 飘字 + 出手 / 受击卡反馈一次写到位（headless 走这里）。
func _上动作终态(帧: Dictionary, 治疗: bool) -> void:
	var e: Variant = 帧.get("日志")
	if not (e is Dictionary):
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
	_应用卡片反馈(反馈)
	if _战斗动画层 != null:
		_战斗动画层.set_trajectories(轨)
		_战斗动画层.set_popups(飘)

## 写演出横幅（`带进度 = true` 时前面挂 `〔演出中 i/N〕`）。
func _写演出横幅(帧: Dictionary, 序: int, 总: int, 带进度: bool = true) -> void:
	var 文 := str(帧.get("横幅", ""))
	if 文.is_empty():
		return
	var 色: Color = 帧.get("颜色") if 帧.get("颜色") is Color else UiTheme.高亮
	if 带进度 and 总 > 0:
		_写播报条("〔演出中 %d/%d〕%s" % [序, 总, 文], 色)
	else:
		_写播报条(文, 色)

## 当前这一帧还要等 `秒`（按倍速折算），并把它记进 `_帧已耗时`（一步的总时长仍 = STEP_DURATION）。
func _等演出(秒: float) -> void:
	_帧已耗时 += 秒
	if not is_inside_tree():
		return
	await get_tree().create_timer(秒 / maxf(_演出倍速, 0.25)).timeout

## 手牌栏里第 `索引` 张牌的目标控件（优先它里面的「手牌按钮」，索引 −1 / 越界 → null）。
func _手牌卡控件(索引: int) -> Control:
	if _手牌列表 == null or 索引 < 0 or 索引 >= _手牌列表.get_child_count():
		return null
	var 卡 := _手牌列表.get_child(索引)
	if not (卡 is Control) or not is_instance_valid(卡):
		return null
	var 按 := (卡 as Node).find_child("手牌按钮", true, false)
	if 按 is Control:
		return 按
	return 卡 as Control

## 手牌落地脉冲：1.15x → 1.0x。
## ★ 只动 `scale`（不动 rect / 最小尺寸），所以版面门禁（1280×720 / 两两不重叠）完全不受影响。
## ★ Tween 建在**目标控件自己**身上：手牌栏一重画（控件被 free）它跟着销毁，不会留下野 Tween。
func _脉冲手牌(目标: Control) -> void:
	if 目标 == null or not is_instance_valid(目标):
		return
	目标.scale = Vector2.ONE
	if UiTheme.无声模式() or not is_inside_tree() or not 目标.is_inside_tree():
		return
	目标.pivot_offset = 目标.size * 0.5
	var t := 目标.create_tween()
	t.tween_property(目标, "scale", Vector2(1.15, 1.15), 0.10)
	t.tween_property(目标, "scale", Vector2.ONE, 0.16)

# ---------------------------------------------------------------- 拆帧：发牌 ----------------—

## 一条「发牌」日志 → 一个 `card_deal` 帧（每发一张牌 1 帧）。
## `来源文本` / `来源位` 是内核 `Btl.牌来源机体()` 给的**纯展示**字段（不掷随机数）。
func _发牌帧(e: Dictionary, prev_hand: Array, curr_hand: Array, 已认领: Array) -> Dictionary:
	var 牌名 := str(e.get("牌名", ""))
	var 源文 := str(e.get("来源文本", ""))
	var 源位们: Array = e.get("来源位") if e.get("来源位") is Array else []
	var 源位 := -1
	if not 源位们.is_empty():
		源位 = _位名到位号(str(源位们[0]))
	var 源名 := _来源名(源文)
	if 源名.is_empty() and 源位 >= 0:
		源名 = _单位名(我方, 源位, "")
	if 源名.is_empty():
		源名 = "指挥官"
	var 索引 := _认领手牌(牌名, prev_hand, curr_hand, 已认领)
	if 索引 >= 0:
		已认领.append(索引)
	var 键 := ""
	if 源位 >= 0:
		键 = str(_位号到键(我方).get(源位, ""))
	return {
		"类别": "card_deal", "回合": int(float(e.get("回合", 0.0))),
		"来源名": 源名, "来源位": 源位, "来源键": 键,
		"卡牌名": 牌名, "手牌索引": 索引, "日志": e,
		"横幅": "〔发牌〕来自【%s】 -> 获得战术牌【%s】" % [源名, 牌名],
		"颜色": UiTheme.高亮,
	}

## 手牌差集补出来的发牌帧（内核这一拍没给逐张「发牌」日志时用）。
func _手牌补帧(c: Dictionary, idx: int) -> Dictionary:
	var 牌名 := str(c.get("名", ""))
	var 源文 := str(c.get("source_unit_text", ""))
	var 源位们: Array = c.get("source_slots") if c.get("source_slots") is Array else []
	var 源位 := -1
	if not 源位们.is_empty():
		源位 = _位名到位号(str(源位们[0]))
	var 源名 := _来源名(源文)
	if 源名.is_empty() and 源位 >= 0:
		源名 = _单位名(我方, 源位, "")
	if 源名.is_empty():
		源名 = "指挥官"
	var 键 := ""
	if 源位 >= 0:
		键 = str(_位号到键(我方).get(源位, ""))
	return {
		"类别": "card_deal", "回合": 0,
		"来源名": 源名, "来源位": 源位, "来源键": 键,
		"卡牌名": 牌名, "手牌索引": idx, "日志": c,
		"横幅": "〔发牌〕来自【%s】 -> 获得战术牌【%s】" % [源名, 牌名],
		"颜色": UiTheme.高亮,
	}

## 本拍**新增**的手牌下标（多重集差集：同名牌各算各的）。
func _手牌新增索引(prev_hand: Array, curr_hand: Array) -> Array:
	var 旧 := {}
	for c in prev_hand:
		if c is Dictionary:
			var k := _牌签名(c)
			旧[k] = int(旧.get(k, 0)) + 1
	var 新: Array = []
	for i in curr_hand.size():
		var c: Variant = curr_hand[i]
		if not (c is Dictionary):
			continue
		var k := _牌签名(c)
		var 剩 := int(旧.get(k, 0))
		if 剩 > 0:
			旧[k] = 剩 - 1
			continue
		新.append(i)
	return 新

## 一张手牌的签名（有内核实例号就用实例号，否则退成 `id|名|层级`）。
func _牌签名(c: Dictionary) -> String:
	var 实例值: Variant = c.get("_实例号")
	if 实例值 is int or 实例值 is float:
		var 实例 := int(实例值)
		if 实例 > 0:
			return "i:%d" % 实例
	return "n:%s|%s|%s" % [str(c.get("id", "")), str(c.get("名", "")), str(c.get("层级", ""))]

## 本拍新增手牌里认领一张（按牌名；先只在「新增」里找，找不到再退回全手牌）。
func _认领手牌(牌名: String, prev_hand: Array, curr_hand: Array, 已认领: Array) -> int:
	for i in _手牌新增索引(prev_hand, curr_hand):
		if 已认领.has(i) or int(i) < 0 or int(i) >= curr_hand.size():
			continue
		var c: Variant = curr_hand[int(i)]
		if c is Dictionary and str((c as Dictionary).get("名", "")) == 牌名:
			return int(i)
	for i in curr_hand.size():
		if 已认领.has(i):
			continue
		var c: Variant = curr_hand[i]
		if c is Dictionary and str((c as Dictionary).get("名", "")) == 牌名:
			return i
	return -1

## 发牌来源的机体名：`来自：刹那（前1）` → `刹那`；`来自：刹那·近卫` → `刹那·近卫`。
func _来源名(源文: String) -> String:
	var 文 := 源文.replace("来自：", "").strip_edges()
	var p := 文.find("（")
	if p > 0:
		文 = 文.substr(0, p)
	return 文.strip_edges()

## 位名（`"前1"` / `"后4"`）→ 位号（0..7）；认不出来 → −1。
func _位名到位号(位名: String) -> int:
	if 位名.is_empty():
		return -1
	for i in int(Fm.SLOTS()):
		if Fm.位名(float(i)) == 位名:
			return i
	return -1

# ---------------------------------------------------------------- 拆帧：动作 / 事件 -------—

## 一条攻击日志 → 一个 `attack` 帧（攻击 / 大招 / 镜甲反弹 / 连斩追加，每次出手 1 帧）。
func _攻击帧(e: Dictionary) -> Dictionary:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 攻名 := _单位名(攻方, 攻位, str(e.get("单位", "")))
	var 目名 := _单位名(目方, 目位, str(e.get("目标", "")))
	return {
		"类别": "attack", "回合": int(float(e.get("回合", 0.0))),
		"出手方": 攻方, "出手位": 攻位, "出手名": 攻名,
		"目标方": 目方, "目标位": 目位, "目标名": 目名,
		"武器": str(e.get("武器", "")), "大招": _是大招(e),
		"镜甲": str(e.get("类型", "")) == "镜甲", "日志": e,
		"横幅": _攻击横幅(e, 攻名, 目名), "颜色": _本拍色([e]),
	}

## 一条修理日志 → 一个 `heal` 帧。
func _修理帧(e: Dictionary) -> Dictionary:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 修名 := _单位名(修方, 修位, str(e.get("单位", "")))
	var 目名 := _单位名(目方, 目位, str(e.get("目标", "")))
	return {
		"类别": "heal", "回合": int(float(e.get("回合", 0.0))),
		"出手方": 修方, "出手位": 修位, "出手名": 修名,
		"目标方": 目方, "目标位": 目位, "目标名": 目名, "日志": e,
		"横幅": "【修理】%s【%s】 -> %s【%s】 · 回复 +%s 耐久" % [_方中文(修方), 修名,
			_方中文(目方), 目名, _数字(float(e.get("回复", 0.0)))],
		"颜色": UiTheme.支援色,
	}

## 一条战术牌 / 连携日志 → 一个 `tactic_card` 帧。
func _战术牌帧(e: Dictionary) -> Dictionary:
	var 文 := ""
	if str(e.get("类型", "")) == "连携":
		文 = "【连携】%s" % str(e.get("文本", "")).strip_edges()
		if 文 == "【连携】":
			文 = "【连携】打出【%s】" % str(e.get("牌名", ""))
	else:
		文 = _战术牌摘要(e)
	return {
		"类别": "tactic_card", "回合": int(float(e.get("回合", 0.0))),
		"日志": e, "横幅": 文, "颜色": UiTheme.高亮,
	}

## 一条重要战场事件（Boss / 增援 / 势力 / 击破 / 结束）→ 一个 `event` 帧。
func _事件帧(e: Dictionary) -> Dictionary:
	var 文 := str(e.get("文本", "")).strip_edges()
	var 类 := str(e.get("类型", ""))
	if 文.is_empty():
		文 = "【%s】" % 类
	elif not 文.begins_with("〔"):
		文 = "【%s】%s" % [类, 文]
	return {
		"类别": "event", "回合": int(float(e.get("回合", 0.0))),
		"日志": e, "横幅": 文, "颜色": _日志色(e),
	}

## 攻击帧的横幅（★ UX-5 规格：`【出手方】使用【武器名】 -> 【受击方】 · 造成 XXX 伤害`）。
func _攻击横幅(e: Dictionary, 攻名: String, 目名: String) -> String:
	var 攻方 := str(e.get("单位方", ""))
	var 目方 := str(e.get("目标方", ""))
	var 武器 := str(e.get("武器", ""))
	if 武器.is_empty():
		武器 = "普通攻击"
	var 行 := ""
	if str(e.get("类型", "")) == "镜甲":
		行 = "【镜甲】%s【%s】反弹 -> %s【%s】" % [_方中文(攻方), 攻名, _方中文(目方), 目名]
	else:
		var 头 := "【大招】" if _是大招(e) else "【攻击】"
		行 = "%s%s【%s】使用【%s】 -> %s【%s】" % [头, _方中文(攻方), 攻名, 武器, _方中文(目方), 目名]
	var 伤害 := float(e.get("伤害", 0.0))
	var 命中 := bool(e.get("命中", true))
	if not 命中:
		行 += " · 未命中"
	else:
		var 段数 := int(float(e.get("段数", 1.0)))
		var 中段 := int(float(e.get("命中段数", 1.0)))
		if 段数 > 1:
			行 += " · 命中 %d/%d 段" % [中段, 段数]
		if int(float(e.get("暴击", 0.0))) > 0:
			行 += " · 〔暴击〕"
		if 伤害 > 0.0:
			行 += " · 造成 %s 伤害" % _数字(伤害)
		else:
			行 += " · 伤害 0"
	if bool(e.get("总攻", false)):
		行 += " · 〔总攻〕"
	if float(e.get("特种破甲", 0.0)) > 0.0:
		行 += " · 〔破防〕"
	if bool(e.get("连斩追击", false)):
		行 += " · 〔连携追击〕"
	if e.get("目标剩余HP") != null and float(e.get("目标剩余HP")) <= 0.0 and 伤害 > 0.0:
		行 += " · 【击破】"
	return 行

func _回话(文: String, 好消息: bool) -> void:
	_反馈文字 = 文
	_反馈是好消息 = 好消息

func _为什么(r: Dictionary) -> String:
	var w := str(r.get("为什么", ""))
	if not w.is_empty():
		return w
	if not session.当前动作错误().is_empty():
		return str(session.当前动作错误())
	return "门面没有给出原因"

# ==========================================================================================
# 小工具
# ==========================================================================================

## 单行裁切标签：文本属性是**全文**（断言照旧查得到），显示上裁成一行不换行 —— 高度恒为一行。
func _建单行标签(父: Node, 名: String, 文本: String, 大小: int = UiTheme.字号_小, 色: Color = UiTheme.主文字) -> Label:
	var l := UiTheme.建标签(父, 文本, 大小, 色)
	l.name = 名
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## 往 `父` 上挂一个左右滚动的 `ScrollContainer` + 里面的 `HBoxContainer`，返回那个盒。
## ★ 纵向滚动的**默认模式**（AUTO）会让 `ScrollContainer` 的最小高度等于 `高`（不含内容），
##   这正是我们要的「版面有界」；换成 DISABLED 就会把内容高度报上去、把版面顶开。
func _建滚动盒(父: Node, 滚动名: String, 盒名: String, 高: float) -> HBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = 滚动名
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 高)
	sc.clip_contents = true
	父.add_child(sc)
	var 盒 := UiTheme.建盒(sc, 盒名, false, UiTheme.间距_小)
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return 盒

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()

# ==========================================================================================
# ★ UX-3：示意性战斗动画层 —— 谁打了谁、多少伤害、什么效果
#
#   数据来源**只有一处**：门面 `session.battle_log_entries()` 里新增的那几条事件。
#   本段一个数都不自己算：伤害 / 命中段 / 暴击 / 回复 / 剩余 HP 全部照日志条目里已有的字段；
#   位名走 `Fm.位名()`、机体名走 `battle_ctx` 里的 `name`（纯读）。
#   ★ 零 RNG、零状态修改、零 `J.*`；headless 下所有 Tween 一律跳过（测试毫秒级跑完）。
# ==========================================================================================

## 每次 `refresh()` 结算一次「本拍」：取新增日志 → 写播报条 → 出弹道与飘字 → 给卡片打反馈。
## ★ UX-5：正在一帧一帧演的时候**不抢**日志（那些人肉演出已经交给 `_消费演出队列()`）。
func _画战斗动画(在战斗: bool) -> void:
	if _动作播报条 == null:
		return
	if not 在战斗:
		_已播日志数 = 0
		_已播日志引用 = null
		_表演中止()
		if _战斗动画层 != null:
			_战斗动画层.清空()
		_清全部卡片反馈()
		_写播报条("【战斗开始】现在不在战斗里 —— 开战之后这一条会播报每一拍谁打了谁、造成多少伤害",
			UiTheme.弱文字)
		return
	if _演出进行中:
		return
	if _演出预热:
		# ★ UX-5：`step_battle_turn()` 里的 `changed.emit()` 会把我们叫回来一次 ——
		#   这一下**什么都不画**，等 `_下一拍()` 把队列建好再由队列一帧一帧演。
		return
	var 日志: Variant = session.battle_ctx.get("log")
	if not is_same(日志, _已播日志引用):
		# 换了一场 / 重开一场：上一回的演出队列作废（旧协程看到 `_演出序号` 变了会自己退出）。
		_表演中止()
	var 新们 := _取本拍事件()
	if 新们.is_empty():
		return
	var 有开始 := false
	for e in 新们:
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "开始":
			有开始 = true
			break
	if 有开始:
		# 开战初始：规格要求的那一句原文（本拍不会再有攻击事件）。
		_写播报条("【战斗开始】等待推进下一拍或点击自动播放", UiTheme.高亮)
		if _战斗动画层 != null:
			_战斗动画层.清空()
		_清全部卡片反馈()
		return
	_应用本拍(新们)

## 取「本拍」新增的战斗日志事件。
## 规则（与规格一字对应）：
##   · `_已播日志数` 记住已经播到第几条；新日志 = `entries.slice(_已播日志数)`；
##   · 换了新的一场（`ctx.log` 数组本体变了）或日志条数变少 → 归零重头算；
##   · **首次打开就已经有日志**时只取**最新一拍**（不把整场战斗重播一遍）。
func _取本拍事件() -> Array:
	var 全部 := session.battle_log_entries(0)
	var 日志: Variant = session.battle_ctx.get("log")
	if not is_same(日志, _已播日志引用):
		_已播日志引用 = 日志
		_已播日志数 = 0
	var n := 全部.size()
	if n < _已播日志数:
		_已播日志数 = 0
	if n == 0:
		return []
	var 起: int = _已播日志数
	if 起 == 0:
		起 = n - _收窄到最后一拍(全部).size()
	_已播日志数 = n
	if 起 >= n:
		return []
	return _收窄到最后一拍(全部.slice(起, n))

## 只留**最后一个回合号**那一组事件（一拍 = 一个回合号；自动打完时会跨很多回合，
## 这里只播最后一拍，免得一次刷出几百条弹道）。
func _收窄到最后一拍(事件们: Array) -> Array:
	var n := 事件们.size()
	if n <= 1:
		return 事件们
	var 末 := -1
	if 事件们[n - 1] is Dictionary:
		末 = int(float((事件们[n - 1] as Dictionary).get("回合", -1.0)))
	var 起 := n - 1
	while 起 > 0:
		var e: Variant = 事件们[起 - 1]
		if not (e is Dictionary):
			break
		if int(float((e as Dictionary).get("回合", -1.0))) != 末:
			break
		起 -= 1
	return 事件们.slice(起)

## 写播报条（文本为空时**保留上一拍**，不清成空白）。
func _写播报条(文: String, 色: Color = UiTheme.高亮) -> void:
	if _动作播报条 == null or 文.is_empty():
		return
	_动作播报条.text = 文
	_动作播报条.add_theme_color_override("font_color", 色)

## 播报条当前文本（自动化测试与别处读它）。
func 播报文本() -> String:
	return "" if _动作播报条 == null else str(_动作播报条.text)

## 没有会话时的空态：播报条写一行提示、动画层收干净（不建任何 Tween）。
func _写作战画面空态() -> void:
	_已播日志数 = 0
	_已播日志引用 = null
	_表演中止()
	if _战斗动画层 != null:
		_战斗动画层.清空()
	_写播报条("【战斗开始】没有会话 —— 开一局战斗之后这一条会播报每一拍谁打了谁", UiTheme.弱文字)

# ---------------- 本拍摘要（播报条那一行） ----------------

## 把本拍事件压成一行：攻击 / 大招 / 修理 / 战术牌 / 势力 谁先有就播谁，
## 末尾再挂上「【击破】XXX！」之类的短标签。
func _本拍摘要(新们: Array) -> String:
	var 攻 := {}
	var 修 := {}
	var 牌 := {}
	var 势 := {}
	var 击破们: Array = []
	for e in 新们:
		if not (e is Dictionary):
			continue
		var 类 := str(e.get("类型", ""))
		match 类:
			"攻击", "镜甲":
				if 攻.is_empty():
					攻 = e
			"修理":
				if 修.is_empty():
					修 = e
			"战术牌":
				if 牌.is_empty():
					牌 = e
			"势力", "连携":
				if 势.is_empty():
					势 = e
		if (类 == "攻击" or 类 == "镜甲") and float(e.get("目标剩余HP", 1.0)) <= 0.0:
			击破们.append(e)
	var 行 := ""
	if not 攻.is_empty():
		行 = _攻击摘要(攻)
	elif not 修.is_empty():
		行 = _修理摘要(修)
	elif not 牌.is_empty():
		行 = _战术牌摘要(牌)
	elif not 势.is_empty():
		行 = _势力摘要(势)
	elif 新们[0] is Dictionary:
		行 = _通用摘要(新们[0])
	if 行.is_empty():
		return ""
	var 尾: Array = []
	for e in 击破们:
		var 名 := _单位名(str((e as Dictionary).get("目标方", "")),
			int(float((e as Dictionary).get("目标位", -1.0))), str((e as Dictionary).get("目标", "")))
		var 条 := "【击破】%s！" % 名
		if not 尾.has(条) and not 行.contains(条):
			尾.append(条)
	if not 势.is_empty() and str(势.get("类型", "")) == "连携":
		尾.append("〔连携追击〕")
	if not 尾.is_empty():
		行 += " · " + " · ".join(尾)
	return 行

## 播报条该用哪个颜色（与摘要同一条判据，不另立口径）。
func _本拍色(新们: Array) -> Color:
	for e in 新们:
		if not (e is Dictionary):
			continue
		var 类 := str(e.get("类型", ""))
		if 类 == "攻击" or 类 == "镜甲":
			if not bool(e.get("命中", true)) or float(e.get("伤害", 0.0)) <= 0.0:
				return UiTheme.未命中色
			if int(float(e.get("暴击", 0.0))) > 0 or _是大招(e):
				return UiTheme.暴击色
			return UiTheme.高亮
	for e in 新们:
		if not (e is Dictionary):
			continue
		match str(e.get("类型", "")):
			"修理":
				return UiTheme.支援色
			"战术牌":
				return UiTheme.高亮
			"势力", "连携":
				return UiTheme.希望色
	return UiTheme.主文字

func _攻击摘要(e: Dictionary) -> String:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 攻名 := _单位名(攻方, 攻位, str(e.get("单位", "")))
	var 目名 := _单位名(目方, 目位, str(e.get("目标", "")))
	var 武器 := str(e.get("武器", ""))
	var 伤害 := float(e.get("伤害", 0.0))
	var 命中 := bool(e.get("命中", true))
	var 有伤 := 伤害 > 0.0
	if str(e.get("类型", "")) == "镜甲":
		return "【镜甲】%s%s 的镜甲 -> 反弹给%s%s · 反弹 %s 伤害！" % [_位文字(攻方, 攻位), 攻名,
			_位文字(目方, 目位), 目名, _数字(伤害)]
	var 头 := "【大招】" if _是大招(e) else "【攻击】"
	var 行 := "%s%s%s -> 使用【%s】攻击%s%s" % [头, _位文字(攻方, 攻位), 攻名, 武器,
		_位文字(目方, 目位), 目名]
	var 段数 := int(float(e.get("段数", 1.0)))
	var 中段 := int(float(e.get("命中段数", 1.0)))
	if not 命中:
		行 += " · 未命中"
	else:
		if 段数 > 1:
			行 += " · 命中 %d/%d 段" % [中段, 段数]
		else:
			行 += " · 命中"
		var 暴击 := int(float(e.get("暴击", 0.0)))
		if 暴击 > 0:
			行 += " · 暴击 %d 次" % 暴击
		if 有伤:
			行 += " · 造成 %s 伤害！" % _数字(伤害)
		else:
			行 += " · 伤害 0"
	if bool(e.get("总攻", false)):
		行 += " · 〔总攻〕"
	if float(e.get("特种破甲", 0.0)) > 0.0:
		行 += " · 〔破甲〕"
	if bool(e.get("连斩追击", false)):
		行 += " · 〔连携追击〕"
	return 行

func _修理摘要(e: Dictionary) -> String:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	return "【修理】%s%s -> 修理%s%s · 回复 +%s 耐久" % [_位文字(修方, 修位),
		_单位名(修方, 修位, str(e.get("单位", ""))), _位文字(目方, 目位),
		_单位名(目方, 目位, str(e.get("目标", ""))), _数字(float(e.get("回复", 0.0)))]

func _战术牌摘要(e: Dictionary) -> String:
	var 效 := str(e.get("效果说明", ""))
	if 效.is_empty():
		效 = "已发动"
	return "【战术牌】打出【%s】 -> %s" % [str(e.get("牌名", "")), 效]

func _势力摘要(e: Dictionary) -> String:
	var 文 := str(e.get("文本", "")).strip_edges()
	文 = 文.trim_prefix("〔势力〕")
	if 文.is_empty():
		return ""
	return "【势力】%s" % 文

func _通用摘要(e: Dictionary) -> String:
	return str(e.get("文本", "")).strip_edges()

# ---------------- 本拍 → 弹道 / 飘字 / 卡片反馈 ----------------

## 把本拍事件翻译成「弹道数组 + 飘字数组 + 卡片反馈」，然后一次写进动画层与卡片。
func _应用本拍(新们: Array) -> void:
	var 轨: Array = []
	var 飘: Array = []
	var 反馈: Dictionary = {}
	for e in 新们:
		if not (e is Dictionary):
			continue
		match str(e.get("类型", "")):
			"攻击":
				_加攻击动画(e, 轨, 飘, 反馈)
			"镜甲":
				_加镜甲动画(e, 轨, 飘, 反馈)
			"修理":
				_加修理动画(e, 轨, 飘, 反馈)
			"势力":
				_加势力胶囊(e, 飘)
			_:
				pass
	_清全部卡片反馈()
	_应用卡片反馈(反馈)
	if _战斗动画层 != null:
		_战斗动画层.set_trajectories(轨)
		_战斗动画层.set_popups(飘)
		if not UiTheme.无声模式() and not (轨.is_empty() and 飘.is_empty()):
			# 非 headless：约 0.7 秒平滑淡出（headless 下一律不建 Tween，测试毫秒级跑完）。
			_战斗动画层.开始淡出(0.7)
	_写播报条(_本拍摘要(新们), _本拍色(新们))

func _加攻击动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 伤害 := float(e.get("伤害", 0.0))
	var 命中 := bool(e.get("命中", true))
	var 暴击 := int(float(e.get("暴击", 0.0)))
	var 大招 := _是大招(e)
	var 色 := UiTheme.弹道色
	var 类型 := "攻击"
	var 宽 := 2.5
	var 虚 := false
	if not 命中:
		色 = UiTheme.未命中色
		类型 = "未命中"
		宽 = 1.5
		虚 = true
	elif 暴击 > 0 or 大招:
		色 = UiTheme.暴击色
		类型 = "大招"
		宽 = 5.0
	轨.append(_弹道(攻方, 攻位, 目方, 目位, 色, 类型, 宽, 虚))
	_记反馈(反馈, 攻方, 攻位, "大招" if 大招 else "出手")
	var 段数 := int(float(e.get("段数", 1.0)))
	var 中段 := int(float(e.get("命中段数", 1.0)))
	var 文 := ""
	if not 命中:
		文 = "未命中"
	elif 段数 > 1:
		文 = "[%d/%d中] -%s" % [中段, 段数, _数字(伤害)]
	else:
		文 = "-%s" % _数字(伤害)
	if 暴击 > 0:
		文 = "【暴击】%s!" % 文
	飘.append(_飘字(目方, 目位, 文, UiTheme.暴击色 if 暴击 > 0 else (UiTheme.未命中色 if not 命中 else UiTheme.负面),
		22 if 暴击 > 0 else (15 if not 命中 else 20), 0.0))
	_记反馈(反馈, 目方, 目位, "受击")
	if bool(e.get("总攻", false)):
		飘.append(_胶囊(目方, 目位, "〔总攻〕", UiTheme.高亮, 1))
	if float(e.get("特种破甲", 0.0)) > 0.0:
		飘.append(_胶囊(目方, 目位, "〔破甲〕", UiTheme.难度色, 1))
	if bool(e.get("连斩追击", false)):
		飘.append(_胶囊(攻方, 攻位, "〔连携追击〕", UiTheme.连携色, 1))
	if 伤害 > 0.0 and e.get("目标剩余HP") != null and float(e.get("目标剩余HP")) <= 0.0:
		飘.append(_胶囊(目方, 目位, "【击破】", UiTheme.高亮, 2))
		_记反馈(反馈, 目方, 目位, "击破")

func _加镜甲动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 守方 := str(e.get("单位方", ""))
	var 守位 := int(float(e.get("单位位", -1.0)))
	var 攻方 := str(e.get("目标方", ""))
	var 攻位 := int(float(e.get("目标位", -1.0)))
	轨.append(_弹道(守方, 守位, 攻方, 攻位, UiTheme.暴击色, "镜甲", 4.0, false))
	var 伤害 := float(e.get("伤害", float(e.get("反弹", 0.0))))
	飘.append(_飘字(攻方, 攻位, "-%s" % _数字(伤害), UiTheme.暴击色, 18, 0.0))
	飘.append(_胶囊(攻方, 攻位, "〔镜甲〕", UiTheme.暴击色, 1))
	_记反馈(反馈, 守方, 守位, "出手")
	_记反馈(反馈, 攻方, 攻位, "受击")
	if e.get("目标剩余HP") != null and float(e.get("目标剩余HP")) <= 0.0:
		飘.append(_胶囊(攻方, 攻位, "【击破】", UiTheme.高亮, 2))
		_记反馈(反馈, 攻方, 攻位, "击破")

func _加修理动画(e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	轨.append(_弹道(修方, 修位, 目方, 目位, UiTheme.支援色, "修理", 2.5, false))
	var 回 := float(e.get("回复", 0.0))
	飘.append(_飘字(目方, 目位, "+%s 耐久" % _数字(回), UiTheme.支援色, 18, 0.0))
	_记反馈(反馈, 修方, 修位, "修理")
	_记反馈(反馈, 目方, 目位, "治疗")

## 势力触发（SEED 觉醒 / TRANS-AM / 秘银连携 …）：在发起者卡上弹一枚胶囊标签。
func _加势力胶囊(e: Dictionary, 飘: Array) -> void:
	var 方 := str(e.get("单位方", e.get("方", "")))
	var 位 := int(float(e.get("单位位", e.get("位", -1.0))))
	if 方.is_empty() or 位 < 0:
		return
	var 文 := str(e.get("文本", ""))
	var 标签 := ""
	if 文.contains("觉醒"):
		标签 = "〔觉醒〕"
	elif 文.contains("TRANS"):
		标签 = "〔TRANS-AM〕"
	elif 文.contains("连携"):
		标签 = "〔连携〕"
	if 标签.is_empty():
		return
	飘.append(_胶囊(方, 位, 标签, UiTheme.希望色, 1))

## 一条弹道（起点 / 终点都记**槽位**，卡片引用只给 `_draw()` 用）。
func _弹道(起方: String, 起位: int, 止方: String, 止位: int,
		色: Color, 类型: String, 宽: float, 虚: bool) -> Dictionary:
	return {
		"起点方": 起方, "起点位": 起位, "终点方": 止方, "终点位": 止位,
		"起点卡": _卡(起方, 起位), "终点卡": _卡(止方, 止位),
		"颜色": 色, "类型": 类型, "宽度": 宽, "虚线": 虚, "alpha": 1.0,
	}

## 一条头顶飘字（`上移` = 在卡片上方再叠几层，给多枚胶囊用）。
func _飘字(方: String, 位: int, 文: String, 色: Color, 字号: int, 上移: float) -> Dictionary:
	return {"文本": 文, "颜色": 色, "字号": 字号, "卡": _卡(方, 位), "上移": 上移, "alpha": 1.0, "类型": "飘字"}

## 一枚效果胶囊（〔被挡 -20〕/〔破甲〕/〔觉醒〕/〔连携追击〕/【击破】）。
func _胶囊(方: String, 位: int, 文: String, 色: Color, 层: int) -> Dictionary:
	return {"文本": 文, "颜色": 色, "字号": 13, "卡": _卡(方, 位), "上移": 22.0 * float(层), "alpha": 1.0,
		"类型": "胶囊"}

# ---------------- 卡片反馈 ----------------

func _记反馈(表: Dictionary, 方: String, 位: int, kind: String) -> void:
	if 方.is_empty() or 位 < 0:
		return
	var k := "%s:%d" % [方, 位]
	var 旧 := str(表.get(k, ""))
	if _反馈优先级(kind) >= _反馈优先级(旧):
		表[k] = kind

func _反馈优先级(kind: String) -> int:
	match kind:
		"击破":
			return 6
		"受击":
			return 5
		"治疗":
			return 4
		"大招":
			return 3
		"修理":
			return 2
		"出手":
			return 1
		_:
			return 0

func _应用卡片反馈(表: Dictionary) -> void:
	for k in 表.keys():
		var 段 := str(k).split(":")
		if 段.size() != 2:
			continue
		var 方 := str(段[0])
		var 卡 := _卡(方, int(str(段[1])))
		if 卡 != null:
			卡.set_combat_fx(str(表[k]), 1.0 if 方 == 我方 else -1.0)

func _清全部卡片反馈() -> void:
	for c in _我方卡:
		if c is UnitCard:
			(c as UnitCard).clear_combat_fx()
			(c as UnitCard).清发牌脉冲()
	for c in _敌方卡:
		if c is UnitCard:
			(c as UnitCard).clear_combat_fx()
			(c as UnitCard).清发牌脉冲()

## 某方某一格上的 `UnitCard`（越界 / 空格 → null）。
func _卡(方: String, 位号: int) -> UnitCard:
	var 池: Array = _我方卡 if (方 == 我方 or 方 == "ally") else _敌方卡
	if 位号 < 0 or 位号 >= 池.size():
		return null
	var c: Variant = 池[位号]
	return c as UnitCard if (c is UnitCard) else null

## `〔我方·前1〕` 这样的位标（位名走 `Fm.位名()`，表现层不自己拼编号）。
func _位文字(方: String, 位号: int) -> String:
	if 位号 < 0:
		return "〔%s〕" % _方中文(方)
	return "〔%s·%s〕" % [_方中文(方), Fm.位名(float(位号))]

func _方中文(方: String) -> String:
	return "我方" if (方 == 我方 or 方 == "ally") else "敌方"

## 机体显示名：读 `battle_ctx` 里那一台单位的 `name`（纯读；查不到就退回日志里的键）。
func _单位名(方: String, 位号: int, 键: String) -> String:
	var u := _单位字典(方, 位号)
	if not u.is_empty():
		var n := str(u.get("name", ""))
		if not n.is_empty():
			return n
	return 键

## 这一发攻击是不是大招：拿日志里的 `武器` 名回到出手方身上找那件武器，再问内核 `Ai.isUltimate`。
## （纯读、不掷随机数：`test_presentation_smoke` 会验 `refresh()` 前后 `rng.steps` 不变。）
func _是大招(e: Dictionary) -> bool:
	var 武器名 := str(e.get("武器", ""))
	if 武器名.is_empty():
		return false
	var u := _单位字典(str(e.get("单位方", "")), int(float(e.get("单位位", -1.0))))
	var 们: Variant = u.get("weapons")
	if not (们 is Array):
		return false
	for x in (们 as Array):
		if not (x is Dictionary):
			continue
		var w: Variant = (x as Dictionary).get("t")
		if w is Dictionary and str((w as Dictionary).get("name", "")) == 武器名:
			return Ai.isUltimate(w)
	return false

## 伤害 / 回复取整（表现层只要数字；取整统一走 `JsCompat.js_round`，与门面同一口径）。
func _数字(值: float) -> String:
	return str(int(JsCompat.js_round(值)))

# ==========================================================================================
# ★ UX-3：战场弹道与浮动飘字层
#
#   为什么是**独立 Control 覆盖层**：它是 `战斗屏` 的直接子节点、`占满(self)`、
#   `MOUSE_FILTER_IGNORE`，**不是任何 `Container` 的子节点** → 一个像素都不参与自动排版，
#   所以 `test_presentation_layout.gd` 的「1280×720 不越界 / 同级控件不重叠 / UnitCard 尺寸合理」
#   三条门禁完全不受影响。
#   弹道与飘字的**位置**在 `_draw()` 里按 `UnitCard` 的**当场**矩形换算 —— 布局变了也跟着走，不存死坐标。
# ==========================================================================================

class 战斗动画层 extends Control:
	## 当前这一拍的弹道（含起点槽位、终点槽位、颜色、类型、alpha）。
	var active_trajectories: Array = []
	## 当前这一拍的头顶飘字 / 效果胶囊（同上，带颜色、字号、alpha）。
	var active_popups: Array = []
	## ★ UX-5：发牌帧的一条「金色流光 + 飞行卡背」（来源机体卡中心 → 底部手牌栏目标卡中心）。
	var active_flycards: Array = []
	var _字体缓存: Font = null
	var _淡出补间: Tween = null
	var _飞卡补间: Tween = null

	## 清空这一拍的所有表现（离场 / 换场 / 淡出结束时调）。
	func 清空() -> void:
		active_trajectories = []
		active_popups = []
		active_flycards = []
		if _飞卡补间 != null and _飞卡补间.is_valid():
			_飞卡补间.kill()
		_飞卡补间 = null
		queue_redraw()

	func set_trajectories(列: Array) -> void:
		active_trajectories = 列
		queue_redraw()

	func set_popups(列: Array) -> void:
		active_popups = 列
		queue_redraw()

	## 非 headless：把这一拍的表现整体淡出（0.7 秒）后清空。
	func 开始淡出(秒: float) -> void:
		if not is_inside_tree():
			return
		if _淡出补间 != null and _淡出补间.is_valid():
			_淡出补间.kill()
		_淡出补间 = create_tween()
		_淡出补间.tween_method(_设透明度, 1.0, 0.0, 秒)
		_淡出补间.tween_callback(清空)

	func _设透明度(a: float) -> void:
		for t in active_trajectories:
			if t is Dictionary:
				(t as Dictionary)["alpha"] = a
		for p in active_popups:
			if p is Dictionary:
				(p as Dictionary)["alpha"] = a
		queue_redraw()

	func 弹道数() -> int:
		return active_trajectories.size()

	func 飘字数() -> int:
		return active_popups.size()

	func 飞卡数() -> int:
		return active_flycards.size()

	## ★ UX-5：播一道发牌流光 / 飞行卡背（`起卡` 来源机体卡 → `止卡` 底部手牌栏那张牌）。
	## 非 headless 时用 Tween 把 `进度` 从 0 推到 1（画面上就是一枚卡背沿金色流光飞过去）；
	## headless 下只留一帧静态数据（不建 Tween，测试毫秒级跑完）。
	func 播放飞卡(起卡: Variant, 止卡: Variant, 秒: float) -> void:
		if not (起卡 is Control) or not (止卡 is Control):
			return
		active_flycards = [{"起点卡": 起卡, "终点卡": 止卡, "进度": 1.0, "alpha": 1.0}]
		queue_redraw()
		if UiTheme.无声模式() or not is_inside_tree():
			return
		_set_飞卡进度(0.0)
		if _飞卡补间 != null and _飞卡补间.is_valid():
			_飞卡补间.kill()
		_飞卡补间 = create_tween()
		_飞卡补间.tween_method(_set_飞卡进度, 0.0, 1.0, maxf(秒, 0.05))
		_飞卡补间.tween_callback(清空)

	func _set_飞卡进度(v: float) -> void:
		for x in active_flycards:
			if x is Dictionary:
				(x as Dictionary)["进度"] = v
		queue_redraw()

	## 一个控件中心点 → 本层局部坐标（拿不到有效矩形 → null）。
	func _卡心(卡: Variant) -> Variant:
		if not (卡 is Control) or not is_instance_valid(卡):
			return null
		var r: Rect2 = (卡 as Control).get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return null
		var 心 := r.position + r.size * 0.5
		return get_global_transform().affine_inverse() * 心

	func _字体() -> Font:
		if _字体缓存 == null:
			_字体缓存 = get_theme_default_font()
			if _字体缓存 == null:
				_字体缓存 = ThemeDB.fallback_font
		return _字体缓存

	func _draw() -> void:
		for t in active_trajectories:
			if t is Dictionary:
				_画弹道(t)
		for f in active_flycards:
			if f is Dictionary:
				_画飞卡(f)
		for p in active_popups:
			if p is Dictionary:
				_画飘字(p)

	## 一条带发光描边 + 箭头的指向连线（未命中 = 灰蓝细虚线）。
	func _画弹道(t: Dictionary) -> void:
		var 起: Variant = _卡心(t.get("起点卡"))
		var 止: Variant = _卡心(t.get("终点卡"))
		if 起 == null or 止 == null:
			return
		var a := clampf(float(t.get("alpha", 1.0)), 0.0, 1.0)
		if a <= 0.0:
			return
		var 色: Color = t.get("颜色") if t.get("颜色") is Color else UiTheme.弹道色
		var 宽 := float(t.get("宽度", 2.5))
		var 虚 := bool(t.get("虚线", false))
		var 主 := Color(色.r, 色.g, 色.b, 色.a * a)
		var 晕 := Color(色.r, 色.g, 色.b, 色.a * a * 0.28)
		var 甲: Vector2 = 起 as Vector2
		var 乙: Vector2 = 止 as Vector2
		# 发光描边（先画粗的低透明底线，再画细的实线）
		if 虚:
			draw_dashed_line(甲, 乙, 晕, 宽 + 5.0, 6.0, true)
			draw_dashed_line(甲, 乙, 主, 宽, 6.0, true)
		else:
			draw_line(甲, 乙, 晕, 宽 + 5.0, true)
			draw_line(甲, 乙, 主, 宽, true)
		# 箭头（指向受击方）
		var 向 := (乙 - 甲).normalized()
		if 向.length() <= 0.0:
			return
		var 头 := 乙 - 向 * 12.0
		var 左 := 头 + Vector2(-向.y, 向.x) * 7.0
		var 右 := 头 - Vector2(-向.y, 向.x) * 7.0
		if 虚:
			draw_dashed_line(头, 左, 主, 宽, 4.0, true)
			draw_dashed_line(头, 右, 主, 宽, 4.0, true)
		else:
			draw_line(头, 左, 主, 宽, true)
			draw_line(头, 右, 主, 宽, true)

	## ★ UX-5：一道金色流光 + 一枚沿流光飞行的卡背（来源机体卡中心 → 底部手牌栏目标卡中心）。
	## 位置按两张卡**当场**的矩形换算（布局变了也跟着走，不存死坐标）。
	func _画飞卡(f: Dictionary) -> void:
		var 起: Variant = _卡心(f.get("起点卡"))
		var 止: Variant = _卡心(f.get("终点卡"))
		if 起 == null or 止 == null:
			return
		var a := clampf(float(f.get("alpha", 1.0)), 0.0, 1.0)
		if a <= 0.0:
			return
		var 甲: Vector2 = 起 as Vector2
		var 乙: Vector2 = 止 as Vector2
		var p := clampf(float(f.get("进度", 0.0)), 0.0, 1.0)
		var 色 := UiTheme.高亮
		var 主 := Color(色.r, 色.g, 色.b, a * 0.9)
		var 晕 := Color(色.r, 色.g, 色.b, a * 0.20)
		# 金色流光（粗晕 + 细虚线，指向底部手牌栏）
		draw_line(甲, 乙, 晕, 5.0, true)
		draw_dashed_line(甲, 乙, Color(主.r, 主.g, 主.b, 主.a * 0.55), 1.5, 8.0, true)
		# 飞行卡背（小小一枚，沿流光从甲飞到乙）
		var 位 := 甲.lerp(乙, p)
		var 背 := Rect2(位 - Vector2(5.0, 7.0), Vector2(10.0, 14.0))
		draw_rect(背, Color(色.r, 色.g, 色.b, a * 0.9), true)
		draw_rect(背, Color(1.0, 1.0, 1.0, a * 0.85), false, 1.5)

	## 一条头顶飘字（描边 + 正文，居中在卡片正上方）。
	func _画飘字(p: Dictionary) -> void:
		var 心: Variant = _卡心(p.get("卡"))
		if 心 == null:
			return
		var a := clampf(float(p.get("alpha", 1.0)), 0.0, 1.0)
		if a <= 0.0:
			return
		var 字 := str(p.get("文本", ""))
		if 字.is_empty():
			return
		var 色: Color = p.get("颜色") if p.get("颜色") is Color else UiTheme.主文字
		var 字号 := int(p.get("字号", 16))
		var 上移 := float(p.get("上移", 0.0))
		var 位: Vector2 = (心 as Vector2) + Vector2(0.0, -88.0 - 18.0 - 上移)
		var 方 := _字体()
		var 宽 := 方.get_string_size(字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
		var 起 := 位 - Vector2(宽 * 0.5, 0.0)
		var 正 := 色
		正.a = a
		var 描 := UiTheme.底色
		描.a = a * 0.92
		draw_string_outline(方, 起, 字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, 5, 描)
		draw_string(方, 起, 字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, 正)
