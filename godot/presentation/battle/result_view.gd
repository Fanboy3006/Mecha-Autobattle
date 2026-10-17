## 结算屏（Stage M4-3 实装）：胜负 / 战后回血前后对照 / 战利品 / 本场战术牌回顾。
##
## 契约（`协作/架构/M4-表现层接口契约.md` §3 / §5）：
##   · `extends Control`，只有 `setup(session)` / `refresh()` 两个入口；`_ready()` 里不读 session；
##   · 关键节点名固定（`find_child` 靠它）：`结算屏` / `结算面板` / `战利品区` / `战报回顾`；
##   · ★ 数据**全部**来自 `session.result_summary()`（三层反馈的「结算」那一层），
##     表现层自己**一个数都不算**：回血前后、战利品数量、券、藏品、零件、回合数一律照抄；
##   · ★ D-04（`Godot迁移-ARGON验收对照表.md` §8.5）：档往返后 `hpRatio` 可能是 int 也可能是 float，
##     所以 **UI 一律按百分比显示**（`int(JsCompat.js_round(float(v) * 100.0))`），不依赖 int/float 区分。
##
## ★ 版面纪律（2026-10-13，「结算屏内容溢出 / 继续按钮被顶到画布外」的根治）：
##   `结算屏上下列` 调 `UiTheme.占满留边`（从前它是普通 `Control` 下**没铺满**的根盒，
##   实测塌到 293×1744 —— 底部按钮自然就跑到画布外去了）。版面切成三块：
##     · 主体（`SIZE_EXPAND_FILL`）：左边 `结算面板` + `战利品区`（各带滚动），右边 `战报回顾`（带滚动）；
##     · 底部**固定**放 `结算按钮组`（`继续按钮` / `回菜单按钮`）与 `结算结果行`
##       —— 于是「继续前进」永远落在 y ≤ 700 以内，可见可点。
class_name ResultView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

const 战报滚动高 := 190.0

var session: GameSession = null

var _结算面板: PanelContainer
var _结算标题: Label
var _结算明细: Label
var _回血对照: Label
var _战利品区: PanelContainer
var _战利品文字: Label
var _战报回顾: PanelContainer
var _战术牌回顾: Label
var _回顾卡区: VBoxContainer
var _日志回顾: Label
var _继续按钮: Button
var _结果: Label

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _结算标题 == null:
		return
	var r := _拿结果()
	if not bool(r.get("有结果", false)):
		_结算标题.text = "结算屏：现在没有可结算的战果。"
		_结算明细.text = "打完一场（或者从出口换层 / 通关）之后，这里给出胜负、回血前后、战利品与本场战术牌回顾。"
		_回血对照.text = ""
		_战利品文字.text = "战利品：还没有打完的战斗。"
		_战术牌回顾.text = ""
		_日志回顾.text = ""
		_清空(_回顾卡区)
		_继续按钮.text = "返回主菜单（快速测试战斗）" if session != null and session.is_quick_battle() else "回大地图"
		_结果.text = ""
		return
	_画胜负(r)
	_画回血(r)
	_画战利品(r)
	_画战报回顾(r)
	# ★ 快速测试战斗没有肉鸽地图可回 → 「继续前进」其实是「返回主菜单」。
	_继续按钮.text = "返回主菜单（快速测试战斗）" if session != null and session.is_quick_battle() else "继续前进（回大地图）"
	_结果.text = "结算屏读的是门面 result_summary()，一个数字都不是这里算的。"

# ==========================================================================================
# 各块
# ==========================================================================================

func _画胜负(r: Dictionary) -> void:
	var 结果 := str(r.get("结果", ""))
	var 胜负 := 结果
	if 结果 == "胜":
		胜负 = "胜利"
	elif 结果 == "败":
		胜负 = "失败"
	elif 结果.is_empty():
		胜负 = "通关" if bool(r.get("通关", false)) else "未知"
	var 原因 := str(r.get("原因", ""))
	_结算标题.text = "战斗结果：%s%s" % [胜负, "（%s）" % 原因 if not 原因.is_empty() else ""]
	var 段: Array = []
	段.append("共 %d 回合 · 格类型 %s" % [int(r.get("回合数", 0)),
		str(r.get("格类型", "")) if not str(r.get("格类型", "")).is_empty() else "（快速测试战斗）"])
	段.append("带伤 %d 台 · 倒下 %d 台" % [int(r.get("带伤", 0)), int(r.get("倒下", 0))])
	if int(r.get("耐久扣", 0)) != 0:
		段.append("基地耐久 -%d" % int(r.get("耐久扣", 0)))
	var 档 := str(r.get("奖励档", ""))
	if not 档.is_empty():
		段.append("奖励档：%s" % 档)
	var 换: Variant = r.get("换层")
	if 换 is Dictionary and not (换 as Dictionary).is_empty():
		段.append("出口守军已清 → 换层已经结算")
	if bool(r.get("冲击追击", false)):
		段.append("推进剂见底 → 追击战已经结算")
	if bool(r.get("通关", false)):
		段.append("这一层通关了")
	if bool(r.get("结束", false)):
		段.append("这一局到此结束")
	_结算明细.text = "\n".join(段)

func _画回血(r: Dictionary) -> void:
	var 回血: Dictionary = r.get("回血") if r.get("回血") is Dictionary else {}
	var 前: Dictionary = r.get("血比前") if r.get("血比前") is Dictionary else {}
	var 后: Dictionary = r.get("血比后") if r.get("血比后") is Dictionary else {}
	var 段: Array = []
	段.append("门面 result_summary() 的原文：%s" % (str(回血.get("文本", ""))
		if not str(回血.get("文本", "")).is_empty() else "这一场没有回血记录"))
	# ★ 真正的「回血前后对照」= **内核自己给的** `名字们`（形如 `M2 20% → 70%`），表现层一个字都不算
	var 名们: Array = 回血.get("名字们") if 回血.get("名字们") is Array else []
	if not 名们.is_empty():
		段.append("★ 回血前后对照（内核原文，%d 台）：" % 名们.size())
		for x in 名们:
			段.append("· %s" % UiTheme.文本(x))
	var 行们: Array = []
	for 键 in 前.keys():
		var k := str(键)
		行们.append("%s：%s%% → %s%%" % [_机师名(k), _百分比(前.get(键)), _百分比(后.get(k))])
	if not 行们.is_empty():
		段.append("名册血比快照（门面 血比前 / 血比后；★ 门面是在回血**之后**才抓的这两份，所以两边通常一样 —— 真正的「前 → 后」看上面那一段）")
		段.append_array(行们)
	_回血对照.text = "\n".join(段)

func _画战利品(r: Dictionary) -> void:
	var 战: Dictionary = r.get("战利品") if r.get("战利品") is Dictionary else {}
	var 段: Array = []
	段.append("希望 +%d · 源碳 +%d" % [int(战.get("希望", 0)), int(战.get("源碳", 0))])
	var 券名 := str(战.get("券名", ""))
	段.append("招募券：%s" % (券名 if not 券名.is_empty() else "这一场没有"))
	var 藏: Variant = 战.get("藏品")
	if 藏 is Dictionary and not (藏 as Dictionary).is_empty():
		var cd: Dictionary = 藏
		if cd.get("id") != null:
			段.append("藏品：【%s】%s" % [str(cd.get("名", "")), str(cd.get("说明", ""))])
		else:
			段.append("藏品已经拿全 → 转成源碳 +%d" % int(cd.get("源碳", 0)))
	var 编: Variant = 战.get("额外编制")
	if 编 is Dictionary and not (编 as Dictionary).is_empty():
		段.append("编制类额外掉落：【%s】%s" % [str((编 as Dictionary).get("名", "")), str((编 as Dictionary).get("说明", ""))])
	var 零: Variant = 战.get("零件")
	if 零 is Dictionary and not (零 as Dictionary).is_empty():
		var zd: Dictionary = 零
		段.append("零件：【%s】" % str(zd.get("名", zd.get("键", ""))))
	var 额: Variant = 战.get("额外")
	if 额 is Dictionary and not (额 as Dictionary).is_empty():
		for k in (额 as Dictionary).keys():
			段.append("%s：%s" % [str(k), str((额 as Dictionary)[k])])
	_战利品文字.text = "\n".join(段)

func _画战报回顾(结: Dictionary) -> void:
	_清空(_回顾卡区)
	# ★ MITH-3 结算层：本场「触发连携次数 / 打出 TDD-1 导弹数」一行统计。
	#   数字全部抄门面 `result_summary()`（表现层一个数都不算）；只有真的打过
	#   秘银 v0.2 的战斗（开关开着，或两个计数非 0）才出现 —— 默认关时这里一个字都不加。
	var 连携次数 := int(结.get("触发连携次数", 0))
	var 弹数 := int(结.get("打出TDD1数", 0))
	if bool(结.get("秘银v02", false)) or 连携次数 > 0 or 弹数 > 0:
		var 统计 := UiTheme.建标签(_回顾卡区, "秘银连携统计：触发连携 %d 次 · 打出 TDD-1 导弹 %d 发" % [连携次数, 弹数],
			UiTheme.字号_小, UiTheme.高亮)
		统计.name = "秘银连携统计"
	var 打牌: Array = 结.get("本场战术牌") if 结.get("本场战术牌") is Array else []
	var 行们: Array = []
	for id in 打牌:
		var 牌 := DeckBuilder.找到(str(id))
		if 牌.is_empty():
			行们.append("· %s" % str(id))
		else:
			行们.append("· 【%s】%s" % [str(牌.get("名", "")), str(牌.get("效果说明", ""))])
	_战术牌回顾.text = "本场打出的战术牌 %d 张：\n%s" % [打牌.size(),
		"\n".join(行们) if not 行们.is_empty() else "（这一场没有打出战术牌）"]
	# ★ Mouse Over：本场打出的每一张牌都给一个小标签，挂对应卡牌的悬停说明。
	for i in 打牌.size():
		var id := str(打牌[i])
		var 牌 := DeckBuilder.找到(id)
		var 文 := "【%s】" % str(牌.get("名", id)) if not 牌.is_empty() else "【%s】" % id
		var l := UiTheme.建标签(_回顾卡区, 文, UiTheme.字号_小, UiTheme.希望色)
		l.name = "回顾卡%d" % (i + 1)
		if session != null:
			var 悬停 := session.card_hover_text(牌 if not 牌.is_empty() else id)
			l.tooltip_text = 悬停
			HoverTooltip.bind(l, 悬停, "战术牌")
	var 行数 := int(结.get("战斗日志行数", 0))
	var 战报: Array = []
	if session != null:
		战报 = session.battle_log_lines(40)
	var 文们 := 战报.map(func(x): return UiTheme.文本(x))
	_日志回顾.text = "战斗日志一共 %d 行；下面是最近 %d 行：\n%s" % [行数, 文们.size(),
		"\n".join(文们) if not 文们.is_empty() else "（这一场没有可回顾的战斗日志 —— 例如换层通关那条路）"]

# ==========================================================================================
# 建节点树（只在 setup 里跑一次）
# ==========================================================================================

func _build() -> void:
	name = "结算屏"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 列 := UiTheme.建盒(self, "结算屏上下列", true, UiTheme.间距_小)
	# ★ 直接子容器必须铺满父区域（否则整屏按最小尺寸塌缩，底部按钮跑到画布外）。
	UiTheme.占满留边(列)

	# ---- 主体：左（胜负 + 回血 + 战利品）/ 右（战报回顾）----
	var 主体 := UiTheme.建盒(列, "结算主体", false, UiTheme.间距)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var 左滚 := ScrollContainer.new()
	左滚.name = "结算左滚动"
	左滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	左滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	左滚.custom_minimum_size = Vector2(0, 240)
	左滚.clip_contents = true
	主体.add_child(左滚)
	var 左列 := UiTheme.建盒(左滚, "结算左列", true, UiTheme.间距_小)
	左列.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_结算面板 = UiTheme.建面板(左列, "结算面板", UiTheme.面板底, UiTheme.高亮)
	var 胜负列 := UiTheme.建盒(_结算面板, "结算面板上下列", true, UiTheme.间距_小)
	_结算标题 = UiTheme.建标签(胜负列, "结算屏", UiTheme.字号_标题, UiTheme.高亮)
	_结算标题.name = "结算标题"
	_结算明细 = UiTheme.建说明(胜负列, "", UiTheme.字号_小, UiTheme.主文字)
	_结算明细.name = "结算明细"
	_回血对照 = UiTheme.建说明(胜负列, "", UiTheme.字号_小, UiTheme.正面)
	_回血对照.name = "回血对照"

	_战利品区 = UiTheme.建面板(左列, "战利品区", UiTheme.卡片底, UiTheme.边框)
	var 战利列 := UiTheme.建盒(_战利品区, "战利品区上下列", true, UiTheme.间距_小)
	UiTheme.建标签(战利列, "战利品", UiTheme.字号_小节, UiTheme.源碳色)
	_战利品文字 = UiTheme.建说明(战利列, "", UiTheme.字号_小, UiTheme.主文字)
	_战利品文字.name = "战利品文字"

	_战报回顾 = UiTheme.建面板(主体, "战报回顾", UiTheme.面板底, UiTheme.边框)
	_战报回顾.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_战报回顾.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_战报回顾.custom_minimum_size = Vector2(0, 240)
	_战报回顾.clip_contents = true
	var 回顾列 := UiTheme.建盒(_战报回顾, "战报回顾上下列", true, UiTheme.间距_小)
	回顾列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	回顾列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(回顾列, "战报回顾", UiTheme.字号_小节, UiTheme.高亮)
	# ★ 战报回顾（战术牌 + 日志）放进 `ScrollContainer` 并限制高度 —— 再长也不会把版面顶开。
	var 回顾内容 := UiTheme.建滚动(回顾列, "战报滚动", 战报滚动高)
	_战术牌回顾 = UiTheme.建说明(回顾内容, "", UiTheme.字号_小, UiTheme.希望色)
	_战术牌回顾.name = "战术牌回顾"
	_回顾卡区 = UiTheme.建盒(回顾内容, "回顾卡区", true, 1)
	_回顾卡区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_日志回顾 = UiTheme.建说明(回顾内容, "", UiTheme.字号_小, UiTheme.次要文字)
	_日志回顾.name = "日志回顾"

	# ---- 底部固定：按钮组 + 结果行（永远落在 y ≤ 700 以内）----
	var 底部 := UiTheme.建盒(列, "结算底部", true, 2)
	var 按钮行 := UiTheme.建盒(底部, "结算按钮组", false, UiTheme.间距)
	_继续按钮 = UiTheme.建按钮(按钮行, "继续前进（回大地图）", _点继续)
	_继续按钮.name = "继续按钮"
	_继续按钮.tooltip_text = "回大地图接着走（这一局已经结束的话就回主菜单）"
	var 回 := UiTheme.建按钮(按钮行, "回主菜单", _点回菜单)
	回.name = "回菜单按钮"
	回.tooltip_text = "结算完就回主菜单（门面 return_to_menu()）"
	_结果 = UiTheme.建说明(底部, "", UiTheme.字号_小, UiTheme.弱文字)
	_结果.name = "结算结果行"

# ==========================================================================================
# 动作（只调门面）
# ==========================================================================================

func _点继续() -> void:
	if session == null:
		return
	# ★ 修复「快速测试战斗打完点继续，落到一张空的肉鸽地图上」（2026-10-16 作者试玩反馈）：
	#   快速战斗**没有肉鸽地图可以回** —— 这一支就是回主菜单（按钮文案也照这个改）。
	if session.is_quick_battle():
		session.return_to_menu()
		return
	var 局终 := false
	if session.run_state != null and str(session.run_state.status) != "进行中":
		局终 = true
	if 局终:
		session.return_to_menu()
		return
	# ★ UX-1 第 1 项（2026-10-19，作者试玩反馈第 2 条「走地图的时候也需要可以打开查看编队」）：
	#   回大地图这件事**必须先把这一场的战斗上下文清掉** —— 从前这里只发了一个切屏信号，
	#   `battle_ctx` 一直挂着 → 回到大地图后 `in_battle()` 仍为 true → 顶栏「编队 / 招募 / 牌库」
	#   被永久锁成灰的。清理动作的唯一实现在门面 `return_to_map_after_battle()`（表现层不直接改
	#   `battle_ctx`）。这一场还没结算完的话它会拒绝，于是界面停在结算屏（不产生孤儿战斗）。
	var 回 := session.return_to_map_after_battle()
	if not bool(回.get("ok", false)):
		_结果.text = "先点【结算这一场】把这一场结算完，再回大地图（%s）。" % UiTheme.文本(session.当前动作错误())
		return
	请求屏幕.emit("map")
	# ★ 2026-10-18（作者试玩反馈第 2 条）：**只要有没做完的决定，就先把决定做完** ——
	#   顺序照内核的口径：先「三选一」（战术牌是招募 / 晋升带出来的），再「招募券」。
	#   两者都不许拖着去走格子（`map_view._点格()` 也会拦，这里是回到地图那一刻的第一道闸）。
	if session.run_state != null and not session.run_state.pending_card_picks.is_empty():
		请求弹窗.emit("三选一", {})
		return
	# ★ 修复「拿到招募券却没有招募页面」（2026-10-16 作者试玩反馈）：
	#   只要手上还有没决定的招募券，回大地图之后**立刻**把招募页面弹出来，逼玩家把决定做完。
	if session.ticket_count() > 0:
		请求弹窗.emit("招募", {})

func _点回菜单() -> void:
	if session == null:
		return
	session.return_to_menu()

# ==========================================================================================
# 小工具
# ==========================================================================================

func _拿结果() -> Dictionary:
	if session == null:
		return {"有结果": false}
	return session.result_summary()

## D-04：`hpRatio` 可能是 int 也可能是 float → 一律 `float()` 收再转百分比，不依赖类型区分。
func _百分比(v: Variant) -> String:
	return UiTheme.文本(int(JsCompat.js_round(float(v) * 100.0)))

## 机体键 → 显示名（读纯目录；读不到就把键原样显示）。
func _机师名(键: String) -> String:
	if 键.is_empty():
		return ""
	var 模板 := RosterManager.模板(键)
	return str(模板.get("名", 键))

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
