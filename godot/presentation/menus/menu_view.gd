## 主菜单 + 分队选择屏（Stage M4-2；`session.screen` 为 `"menu" | "squad"`）。
##
## 入口（契约 §「C. menus」）：
##   继续游戏（读档，`has_saved_run()` 为假时点不动并写原因）
##   开始新肉鸽（选分队 `available_squads()` + 可选种子输入）
##   ★ A7 双入口：**快速测试：秘银五人**（`开始快速测试战斗("秘银")`）/ **快速测试：ATX 五人**
##     （`开始快速测试战斗("ATX")`）—— 两个入口点进去都**自动开单机牌组 + 卡牌流转**，
##     分别是秘银五小强 Lv30 与 ATX 五人 Lv30，作者点进来就能直接试玩 v0.3 全套新机制。
##
## 单向数据流：读 `GameSession` 的展示辅助（`has_saved_run` / `available_squads`），
## 动作只调命令方法（`load_saved_run` / `start_new_run` / `开始快速测试战斗`）。
class_name MenuView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

var session: GameSession = null

var _继续: Button
var _存档提示: Label
var _分队面板: PanelContainer
var _分队列表: OptionButton
var _种子输入: LineEdit
var _分队说明: Label
var _菜单说明: Label
var _秘银键: Button
var _ATX键: Button
## ★ CB-4：「快速测试战斗（天人五人）」按钮。
var _天人键: Button
## ★ COL-4：「快速测试战斗（殖民卫星军五人）」按钮。
var _殖民卫星军键: Button
## 月球王国 / 影世界 v0.2.1 试玩版的快速测试按钮。
var _月球王国键: Button
var _影世界键: Button

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _继续 == null:
		return
	_菜单说明.text = "版本 %s%s · 规则参考 %s\n三个「快速测试」入口都能直接开一场 Lv30 的测试战（不用先开肉鸽）：秘银五人 / ATX 五人走 v0.3 全套新机制，天人五人是 TRANS-AM + 七剑 / 双人格 / 脱装 的全套试玩。" % [
		GameVersion.GAME_VERSION, GameVersion.构建串(), GameVersion.RULES_REFERENCE]
	var 有档 := session != null and session.has_saved_run()
	_继续.disabled = not 有档
	_继续.tooltip_text = "从存档接着打" if 有档 else "还没有存档"
	if 有档:
		_存档提示.text = "有存档：可以继续上一次的局。"
		_存档提示.add_theme_color_override("font_color", UiTheme.正面)
	else:
		_存档提示.text = "「继续游戏」为什么是点不动的：现在读不到存档（存档要在局内点顶栏的「保存并返回主菜单」才会写）。"
		_存档提示.add_theme_color_override("font_color", UiTheme.弱文字)
	_分队面板.visible = session != null and session.screen == "squad"
	if _分队面板.visible:
		_刷新分队列表()

# ==========================================================================================
# 建节点树
# ==========================================================================================

func _build() -> void:
	name = "主菜单"
	UiTheme.占满(self)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 居中 := CenterContainer.new()
	居中.name = "菜单居中"
	UiTheme.占满(居中)
	add_child(居中)
	var 底 := UiTheme.建面板(居中, "菜单底", UiTheme.面板底, UiTheme.边框)
	底.custom_minimum_size = Vector2(680, 0)
	var 列 := UiTheme.建盒(底, "菜单上下列", true, UiTheme.间距)

	UiTheme.建标题(列, "机甲指挥", UiTheme.字号_大标题)
	_菜单说明 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.次要文字)
	UiTheme.建分隔(列)

	var 按钮组 := UiTheme.建盒(列, "菜单按钮组", true, UiTheme.间距_小)
	_继续 = UiTheme.建按钮(按钮组, "继续游戏（读档）", _点继续)
	_继续.name = "继续游戏按钮"
	var 新 := UiTheme.建按钮(按钮组, "开始新肉鸽", _点开始新)
	新.name = "开始新肉鸽按钮"
	新.tooltip_text = "选一个分队、给一个种子，开一局新的"
	# ★ A7：两个快速测试入口（文字写清是哪五个人；点进去自动开单机牌组 + 卡牌流转）。
	_秘银键 = UiTheme.建按钮(按钮组, "快速测试：秘银五人", _点快速秘银)
	_秘银键.name = "快速测试战斗按钮"
	_秘银键.tooltip_text = "秘银五人（Lv30：宗介 / 毛 / 克鲁佐 / 库尔茨 / 泰莎）打第 1 层普通编成 —— 单机牌组 + 卡牌流转全开，不动存档"
	_ATX键 = UiTheme.建按钮(按钮组, "快速测试：ATX 五人", _点快速ATX)
	_ATX键.name = "快速测试ATX按钮"
	_ATX键.tooltip_text = "ATX 五人（Lv30：响介 / 塔斯克 / 艾克赛琳 / 拉米亚 / 雷欧娜）打第 1 层普通编成 —— 单机牌组 + 卡牌流转 + 筹码牌库全开，不动存档"
	# ★ CB-4：天人五人入口（前排 刹那 / 阿雷路亚 / 拉塞，后排 洛克昂 / 提耶利亚）。
	_天人键 = UiTheme.建按钮(按钮组, "快速测试战斗（天人五人）", _点快速天人)
	_天人键.name = "快速测试天人按钮"
	_天人键.tooltip_text = "天人五人（Lv30：刹那 / 阿雷路亚 / 拉塞 / 洛克昂 / 提耶利亚）对战 5 台高耐久单援护试玩靶机 —— 单机牌组 + 卡牌流转 + TRANS-AM / 七剑 / 双人格 / 脱装全开，不动存档"
	# ★ COL-4：殖民卫星军五人入口（前排 迪奥 / 特洛瓦 / 拉克丝，后排 卡嘉莉 / 希罗）。
	_殖民卫星军键 = UiTheme.建按钮(按钮组, "快速测试战斗（殖民卫星军五人）", _点快速殖民卫星军)
	_殖民卫星军键.name = "快速测试殖民卫星军按钮"
	_殖民卫星军键.tooltip_text = "殖民卫星军五人（Lv30：拉克丝 / 卡嘉莉 / 希罗 / 迪奥 / 特洛瓦）对战 5 台高耐久单援护试玩靶机 —— 单机牌组 + 觉醒（SEED / ZERO / 隐身）+ 感应牌库 + METEOR + QTE 全开，不动存档"
	_月球王国键 = UiTheme.建按钮(按钮组, "快速测试战斗（月球王国五人）", _点快速月球王国)
	_月球王国键.name = "快速测试月球王国按钮"
	_月球王国键.tooltip_text = "月球王国五人（Lv30：前排 阿布拉德 / Feena / 苏菲，后排 Iris / Nagi）对战试玩靶机 —— 月相 / 随侍 / 月光牌库 / 刀枪切换 全开，不动存档"
	_影世界键 = UiTheme.建按钮(按钮组, "快速测试战斗（影世界五人）", _点快速影世界)
	_影世界键.name = "快速测试影世界按钮"
	_影世界键.tooltip_text = "影世界四人 + 拉米亚（Lv30：前排 雷萨 / 比格特拉克，后排 拉米亚 / 蕾卡 / 维诺）对战试玩靶机 —— 移位 / 错位 / 影门牌库 / 影种 / 深渊之门 全开，不动存档"
	_存档提示 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.弱文字)
	_存档提示.name = "存档提示"

	_分队面板 = UiTheme.建面板(列, "分队选择", UiTheme.卡片底, UiTheme.边框_亮)
	var 分队列 := UiTheme.建盒(_分队面板, "分队上下列", true, UiTheme.间距_小)
	UiTheme.建标题(分队列, "分队选择", UiTheme.字号_小节)
	_分队列表 = OptionButton.new()
	_分队列表.name = "分队列表"
	_分队列表.custom_minimum_size = Vector2(280, 0)
	分队列.add_child(_分队列表)
	var 种子行 := UiTheme.建盒(分队列, "种子行", false, UiTheme.间距)
	UiTheme.建标签(种子行, "种子：", UiTheme.字号_正文, UiTheme.次要文字)
	_种子输入 = LineEdit.new()
	_种子输入.name = "种子输入"
	# ★ 10-22 作者：开局种子默认随机；想重打同一局就记下号码填回来（大地图左上「第 N 层」悬停可看本局种子）。
	_种子输入.text = str(随机种子())
	_种子输入.custom_minimum_size = Vector2(180, 0)
	_种子输入.tooltip_text = "每次打开随机给一个号码；同一个种子 + 同一个分队 = 同一局。留空也会随机"
	种子行.add_child(_种子输入)
	var 开局键 := UiTheme.建按钮(分队列, "开这一局", _点开局)
	开局键.name = "开局按钮"
	开局键.tooltip_text = "立刻开一局新肉鸽：开局先弹【招募】窗（名册是空的，先招 1 台再进第 1 层大地图）"
	_分队说明 = UiTheme.建说明(分队列, "", UiTheme.字号_小, UiTheme.次要文字)
	_分队面板.visible = false

# ==========================================================================================
# 动作（一律只调 GameSession 的命令方法）
# ==========================================================================================

func _点继续() -> void:
	if session == null:
		return
	session.load_saved_run()

func _点开始新() -> void:
	请求屏幕.emit("squad")

func _点快速战斗() -> void:
	_点快速秘银()

## ★ A7：快速测试：秘银五人 —— 门面自己会把 `单机牌组模式` 打开（R1：数据里的主开关仍是 false）。
func _点快速秘银() -> void:
	if session == null:
		return
	session.开始快速测试战斗(GameSession.快速测试_秘银)

## ★ A7：快速测试：ATX 五人（筹码牌库 / 闪标 / 赌神 / 烟 / 掩护 都在这一场里）。
func _点快速ATX() -> void:
	if session == null:
		return
	session.开始快速测试战斗(GameSession.快速测试_ATX)

## ★ CB-4：快速测试战斗（天人五人）—— TRANS-AM / 太阳炉 / 七剑 / 双人格 / 脱装 全在这里。
func _点快速天人() -> void:
	if session == null:
		return
	session.start_quick_battle_celestial()

## ★ COL-4：快速测试战斗（殖民卫星军五人）—— 觉醒 / 感应牌库 / METEOR / QTE 全在这里。
func _点快速殖民卫星军() -> void:
	if session == null:
		return
	session.start_quick_battle_colonial()

func _点快速月球王国() -> void:
	if session == null:
		return
	session.开始快速测试战斗("月球王国")

func _点快速影世界() -> void:
	if session == null:
		return
	session.开始快速测试战斗("影世界")

func _点开局() -> void:
	if session == null:
		return
	if not session.start_new_run(_读种子(), _选中的分队()):
		return
	# ★ 修复「选完小队没有招募页面」（2026-10-16 作者试玩反馈）：
	#   开局会发 3 张招募券，可名册是**空的** —— 不开招募窗就直接进大地图，玩家会 0 机体裸奔。
	#   所以这里开完局立刻请求弹「招募」。
	#   ★ 走**视图层信号**（`_接视图信号` 把它接到 `boot.打开弹窗`），
	#     不改门面 `start_new_run()` 的默认 `screen = "map"` / `modal = {}`
	#     —— `test_session_flow.gd:264/956` 与 `test_session_run.gd:72` 钉着那两条断言。
	if session.ticket_count() > 0:
		请求弹窗.emit("招募", {})

func _读种子() -> int:
	var 文 := _种子输入.text.strip_edges()
	if 文.is_valid_int():
		return int(文.to_int())
	return 随机种子()

static func 随机种子() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi_range(10000000, 99999999)

func _选中的分队() -> String:
	if _分队列表.item_count <= 0:
		return GameSession.默认分队
	return _分队列表.get_item_text(maxi(0, _分队列表.selected))

# ==========================================================================================
# 分队列表（数据侧没有「分队表」时用「混编 + 势力」兜底，绝不空着）
# ==========================================================================================

func _候选分队() -> Array:
	var 出: Array = []
	if session != null:
		出 = session.available_squads()
	if not 出.is_empty():
		return 出
	# 只给「混编」和势力分队：职业分队试玩下来不好用，作者 10-21 定删掉（旧存档里的职业分队照常能读）。
	出.append(GameSession.默认分队)
	for 势力 in RosterManager.势力们():
		出.append(str(势力))
	return 出

func _刷新分队列表() -> void:
	var 候选 := _候选分队()
	if _分队列表.item_count != 候选.size():
		var 旧 := _选中的分队()
		_分队列表.clear()
		for 名 in 候选:
			_分队列表.add_item(str(名))
		for i in _分队列表.item_count:
			if _分队列表.get_item_text(i) == 旧:
				_分队列表.selected = i
				break
	var 数据侧有表 := session != null and not session.available_squads().is_empty()
	_分队说明.text = "分队一共 %d 个%s。\n势力分队开局第 1 张券必是本势力的招募券；选「混编」就是纯随机。" % [
		候选.size(), "" if 数据侧有表 else "（混编 + 六个势力）"]
