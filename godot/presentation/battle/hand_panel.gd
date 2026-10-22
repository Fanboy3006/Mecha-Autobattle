## 职责：手牌三栏 + 公有排的双排手牌栏、卡牌缩放、分组标签与联动高亮。
extends RefCounted

## 下半区（中栏下）：只装 `手牌栏`（战报栏已经挪到右栏）。
static func _建下半区(宿主, 父: Node) -> void:
	宿主._下半区 = UiTheme.建盒(父, "战斗屏下半区", true, 0) as VBoxContainer
	宿主._下半区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._下半区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._下半区.custom_minimum_size = Vector2(0, 宿主.手牌区高)
	宿主._建手牌栏(宿主._下半区)

static func _建手牌栏(宿主, 父: Node) -> void:
	宿主._手牌栏 = UiTheme.建面板(父, "手牌栏", UiTheme.面板底, UiTheme.边框_亮)
	宿主._手牌栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._手牌栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._手牌栏.custom_minimum_size = Vector2(0, 宿主.手牌区高)
	宿主._手牌栏.clip_contents = true
	宿主._手牌栏.add_theme_stylebox_override("panel", 宿主._紧面板样式(UiTheme.面板底, UiTheme.边框_亮, 1, 6, 4))
	var 列 = UiTheme.建盒(宿主._手牌栏, "手牌栏上下列", true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._新发牌提示 = 宿主._建单行标签(列, "新发牌提示", "", UiTheme.字号_小, UiTheme.高亮)
	宿主._新发牌提示.visible = false
	宿主._手牌顶行 = UiTheme.建盒(列, "手牌顶行", false, UiTheme.间距_小)
	宿主._手牌顶行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._手牌标题 = 宿主._建单行标签(宿主._手牌顶行, "手牌标题", "手牌栏", UiTheme.字号_小, UiTheme.高亮)
	宿主._手牌气势 = 宿主._建单行标签(宿主._手牌顶行, "手牌气势", "", UiTheme.字号_小, UiTheme.希望色)
	宿主._操作结果 = 宿主._建单行标签(宿主._手牌顶行, "操作结果", "", UiTheme.字号_小, UiTheme.正面)
	宿主._建单机双排(列)

static func _建单机双排(宿主, 父: Node) -> void:
	var 上 = 宿主._建单机一排(父, "专属排", "专属排标题", "专属排列表", UiTheme.高亮, 宿主.单机上排占比)
	宿主._专属排 = 上["面"]
	宿主._专属排标题 = 上["标题"]
	宿主._专属排列表 = 上["卡行"]
	宿主._专属排滚动 = null
	宿主._专属排.visible = false
	宿主._专属牌盒 = 宿主._专属排列表
	var 下 = 宿主._建单机一排(父, "公有排", "公有排标题", "公有排列表", UiTheme.边框_亮, 宿主.单机下排占比)
	宿主._公有排 = 下["面"]
	宿主._公有排标题 = 下["标题"]
	宿主._公有排列表 = 下["卡行"]
	宿主._公有排滚动 = null
	宿主._公有排.visible = false
	宿主._公有牌盒 = 宿主._公有排列表

## 建一排：`PanelContainer`（亮边框，纵向 `SIZE_EXPAND_FILL` + `stretch_ratio`）+ 单行标题 + **平铺卡行**。
static func _建单机一排(宿主, 父: Node, 名: String, 标题名: String, 卡行名: String, 边色: Color, 占比: float) -> Dictionary:
	var 面 := UiTheme.建面板(父, 名, UiTheme.卡片底, 边色)
	面.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	面.size_flags_vertical = Control.SIZE_EXPAND_FILL
	面.size_flags_stretch_ratio = 占比
	面.custom_minimum_size = Vector2(0, 0)
	面.clip_contents = true
	面.add_theme_stylebox_override("panel", 宿主._紧面板样式(UiTheme.卡片底, 边色, 1, 4, 2))
	var 列 := UiTheme.建盒(面, 名 + "上下列", true, 1)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 题 = 宿主._建单行标签(列, 标题名, "", UiTheme.字号_小, 边色)
	var 卡行 := UiTheme.建盒(列, 卡行名, false, UiTheme.间距_小) as HBoxContainer
	卡行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	卡行.size_flags_vertical = Control.SIZE_EXPAND_FILL
	卡行.clip_contents = true
	return {"面": 面, "标题": 题, "滚动": null, "卡行": 卡行}

## ★ UI-1：紧内边距的面板样式（手牌栏里的三层嵌套全靠它把 248px 让给卡面）。
static func _紧面板样式(宿主, 色: Color, 边色: Color, 边宽: int, 内距横: int, 内距纵: int) -> StyleBoxFlat:
	var s := UiTheme.底样式(色, 边色, 边宽)
	s.content_margin_left = 内距横
	s.content_margin_right = 内距横
	s.content_margin_top = 内距纵
	s.content_margin_bottom = 内距纵
	return s

static func _画手牌(宿主, 在战斗: bool) -> void:
	宿主.联动高亮([], false)
	if not 在战斗:
		宿主._手牌标题.text = "手牌栏：现在不在战斗里。"
		宿主._手牌气势.text = ""
		宿主._收新发牌提示()
		宿主._切单机双排(false)
		return
	宿主._切单机双排(true)
	宿主._画单机双排()
	宿主._画左牌库()

## 单机双排的显隐（只有进战斗时才露出来）。
static func _切单机双排(宿主, 显示: bool) -> void:
	if 宿主._专属排 != null:
		宿主._专属排.visible = 显示
	if 宿主._公有排 != null:
		宿主._公有排.visible = 显示

## ★ DECK-3：画上下双排。
static func _画单机双排(宿主) -> void:
	宿主._清空(宿主._专属排列表)
	宿主._清空(宿主._公有排列表)
	宿主._收新发牌提示()
	var 结 = 宿主.session.deck_turn_summary()
	var 回合 = int(结.get("回合", 0))
	var 选名 = str(结.get("选中名", ""))
	var 职业 = str(结.get("选中职业", ""))
	var 势力 = str(结.get("选中势力", ""))
	var 战意 = int(JsCompat.js_round(float(结.get("战意", 0.0))))
	var 上限 = int(JsCompat.js_round(float(结.get("战意上限", 100.0))))
	var 卡流开 = 宿主.session != null and 宿主.session.v03_active()
	var 上 = 宿主.session.upper_hand_cards()
	var 下 = 宿主.session.lower_hand_cards()
	var 上可打 = 上.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	var 下可打 = 下.filter(func(c): return c is Dictionary and bool((c as Dictionary).get("可打", false)))
	宿主._手牌标题.text = "第 %d 回合 · 阶段 %s · 选中 %s（%s·%s）· 战意 %d / %d · 本回合已打出 %d 张" % [
		回合, 宿主._阶段中文(str(结.get("阶段", ""))), 选名 if not 选名.is_empty() else "—",
		职业, 势力, 战意, 上限, int(结.get("本回合已打出", 0))]
	宿主._手牌气势.text = "手牌栏全部可打：上排 %d / %d 张 · 下排 %d / %d 张 · 左牌库 %d 张" % [
		上可打.size(), 上.size(), 下可打.size(), 下.size(), 宿主._左库条目们().size()]
	if 宿主._专属排标题 != null:
		var 计 = 宿主.session.deck_counts()
		宿主._专属排标题.text = "【%s（%s·%s）· 战意 %d / %d】专属排：【主武器牌】%d · 【副武器牌】%d · 【精神牌】%d　牌库 %d · 弃牌 %d · 待入库 %d" % [
			选名 if not 选名.is_empty() else "未选中", 职业, 势力, 战意, 上限,
			宿主._分到组(上可打, "主武器").size(), 宿主._分到组(上可打, "副武器").size(), 宿主._分到组(上可打, "精神").size(),
			int(计.get("牌库", 0)), int(计.get("弃牌", 0)), int(计.get("待入库", 0))]
	if 宿主._公有排标题 != null:
		var 公 = "【公有牌】全队公有手牌 %d 张（能打 %d 张）%s" % [下.size(), 下可打.size(),
			"　当前指挥机：公有牌战意 -5" if 职业 == "指挥" else ""]
		if 卡流开:
			var 链 = 宿主.session.link_library_state()
			var 上张 = 宿主.session.last_card_state()
			var 有连携 = int(链.get("张数", 0)) > 0 or bool(链.get("就绪", false))
			var 筹 = 宿主.session.chip_library_state()
			var 有筹码 = bool(筹.get("启用", false))
			var 悬停们: Array = []
			if 有连携:
				公 += "　〔连携牌库 一%d / 二%d / 三%d〕%s" % [
					int(链.get("一级", 0)), int(链.get("二级", 0)), int(链.get("三级", 0)),
					("　★ 连携就绪！" if bool(链.get("就绪", false)) else "")]
				悬停们.append(str(链.get("悬停", "")))
			if 有筹码:
				公 += "　〔%s〕" % str(筹.get("文案", ""))
				悬停们.append(str(筹.get("悬停", "")))
			if bool(上张.get("有", false)):
				公 += "　%s" % str(上张.get("文案", ""))
			宿主._公有排标题.tooltip_text = "\n".join(悬停们)
			宿主._公有排标题.mouse_filter = Control.MOUSE_FILTER_PASS
		宿主._公有排标题.text = 公
	var i := 0
	宿主._专属栏们 = {}
	var 上全空 = 上可打.is_empty()
	for 组 in 宿主.单机三栏:
		var 组牌 = 宿主._分到组(上可打, 组)
		var 空文 := "（无）"
		if 组 == "主武器" and 上全空:
			空文 = "这一台现在没有能打的专属牌（都在左边牌库）"
		i = 宿主._建单机子栏(宿主._专属排列表, 组, 组牌, true, i, 空文)
	i = 0
	for c in 下可打:
		宿主._建单机卡(宿主._公有排列表, c, false, i, 下可打.size())
		i += 1
	if 宿主._公有排列表.get_child_count() == 0:
		UiTheme.建标签(宿主._公有排列表, "（公有手牌里现在没有能打的牌）", UiTheme.字号_小, UiTheme.弱文字)

## ★ UI-1：上排的一栏 —— 浅色边框子面板 + 小标题（`【主武器】N 张`）+ 平铺卡行。
static func _建单机子栏(宿主, 父: Node, 组: String, 组牌: Array, 上排: bool, 起序: int, 空文: String = "（无）") -> int:
	var 栏名 := "%s栏" % 组
	var 栏 := UiTheme.建面板(父, 栏名, UiTheme.卡片底_亮, UiTheme.边框)
	栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	栏.size_flags_stretch_ratio = float(maxi(1, 组牌.size()))
	栏.custom_minimum_size = Vector2(0, 0)
	栏.clip_contents = true
	栏.add_theme_stylebox_override("panel", 宿主._紧面板样式(UiTheme.卡片底_亮, UiTheme.边框, 1, 3, 1))
	var 列 := UiTheme.建盒(栏, 栏名 + "上下列", true, 1)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 题 = 宿主._建单行标签(列, "%s栏标题" % 组, "【%s】%d 张" % [组, 组牌.size()],
		UiTheme.字号_小, UiTheme.连携色)
	题.tooltip_text = "【%s】这一栏现在能打 %d 张（按张数自动分配宽度，再多也不用横向滚动）" % [组, 组牌.size()]
	var 盒 := UiTheme.建盒(列, "%s栏卡盒" % 组, false, UiTheme.间距_小) as HBoxContainer
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	盒.size_flags_vertical = Control.SIZE_EXPAND_FILL
	盒.clip_contents = true
	宿主._专属栏们[组] = 盒
	var 序 := 起序
	if 组牌.is_empty():
		var 空 := UiTheme.建标签(盒, 空文, UiTheme.字号_小, UiTheme.弱文字)
		空.name = "%s栏空文" % 组
		空.clip_text = true
		空.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		空.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return 序
	for c in 组牌:
		宿主._建单机卡(盒, c, 上排, 序, 组牌.size())
		序 += 1
	return 序

## 一张单机牌属于四个分区里的哪一组（纯表现层的分组，只按门面的 `区` 字段分）。
static func _分到组(宿主, 牌们: Array, 组: String) -> Array:
	var 出: Array = []
	for c in 牌们:
		if not (c is Dictionary):
			continue
		var 区 := str((c as Dictionary).get("区", ""))
		var 归 := "精神"
		if 区 == "主武器卡" or 区 == "衍生攻击卡" or 区 == "大招槽卡":
			归 = "主武器"
		elif 区 == "副武器卡" or 区 == "连携牌":
			归 = "副武器"
		if 归 == 组:
			出.append(c)
	return 出

## 一条分区标题（`【主武器牌】` 这种），**不是卡**（测试用 `手牌卡控件们()` 数卡，别数它）。
static func _建分组标(宿主, 父: Node, 文: String) -> Label:
	var l := UiTheme.建标签(父, 文, UiTheme.字号_小, UiTheme.连携色)
	l.name = "分组标"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 手牌栏里**真正的卡**（跳过 `【主武器】` 这类小标题 / 空文标签）—— 自动化测试数卡 / 取按钮用。
static func 手牌卡控件们(宿主, 上排: bool) -> Array:
	var 出: Array = []
	var 列: Node = 宿主._专属牌盒 if 上排 else 宿主._公有牌盒
	if 列 == null or not is_instance_valid(列):
		列 = 宿主._专属排列表 if 上排 else 宿主._公有排列表
	if 列 == null or not is_instance_valid(列):
		return 出
	宿主._收卡控件(列, 出)
	return 出

## 递归把 `根` 子树里所有「挂了 `unit_card_data` 的 `PanelContainer`」收进 `出`（深度优先，顺序稳定）。
static func _收卡控件(宿主, 根: Node, 出: Array) -> void:
	if 根 == null or not is_instance_valid(根):
		return
	for c in 根.get_children():
		if c is PanelContainer and (c as Node).has_meta("unit_card_data"):
			出.append(c)
			continue
		宿主._收卡控件(c, 出)

## 把 `位们`（位名数组，例如 `["前1", "后2"]`）对应到我方阵型里的 `UnitCard` 并点亮 / 熄灭。
static func 联动高亮(宿主, 位们: Array, on: bool) -> void:
	var 集 := {}
	for x in 位们:
		集[str(x)] = true
	for i in 宿主._我方卡.size():
		var 卡: Variant = 宿主._我方卡[i]
		if not (卡 is UnitCard) or not is_instance_valid(卡):
			continue
		(卡 as UnitCard).set_card_source_highlight(on and 集.has(Fm.位名(float(i))))

## 悬停一张手牌 / 候补牌 → 点亮它 `source_slots` 上的我方机体。
static func _悬停来源(宿主, 位们: Array) -> void:
	宿主.联动高亮(位们, true)

## 鼠标离开 → 全部熄灭。
static func _移开来源(宿主) -> void:
	宿主.联动高亮([], false)

## 点亮**所有在场存活我方**机体卡（翠绿「可投放」框）。`秒 > 0` = 到点自动熄灭。
static func _亮友军可投放(宿主, 秒: float = 0.0) -> void:
	宿主._友军目标亮着 = true
	宿主._友军提示秒 = maxf(0.0, 秒)
	for 卡 in 宿主._我方卡:
		if not (卡 is UnitCard) or not is_instance_valid(卡):
			continue
		var d: Dictionary = (卡 as UnitCard).数据
		if bool(d.get("ok", false)) and float(d.get("HP", 0.0)) > 0.0:
			(卡 as UnitCard).set_aim_highlight(true, true)

## 熄灭所有我方机体卡上的「可投放」高亮。
static func _灭友军可投放(宿主) -> void:
	宿主._友军目标亮着 = false
	宿主._友军提示秒 = 0.0
	for 卡 in 宿主._我方卡:
		if 卡 is UnitCard and is_instance_valid(卡):
			(卡 as UnitCard).set_aim_highlight(false)

## 自动化测试读它：现在是不是把所有存活我方点亮成可投放框。
static func 友军可投放高亮中(宿主) -> bool:
	return 宿主._友军目标亮着

## 手牌总上限 / 初始手牌上限：纯读数据目录（不写死数字）
static func _手牌总上限(宿主) -> int:
	var v: Variant = 宿主._卡牌参数().get("手牌总上限")
	return int(float(v)) if v != null else 10

static func _初始手牌上限(宿主) -> int:
	var v: Variant = 宿主._卡牌参数().get("初始手牌上限")
	return int(float(v)) if v != null else 6

## ★ DECK-3 ③：**每次打牌立即播放 0.5s 单步攻击动画**（复用 UX-5 的串行演出队列）。
static func _演本拍新增(宿主, 前日志: int, 前手: Array) -> void:
	var 全部 = 宿主.session.battle_log_entries(0)
	var 新增: Array = 全部.slice(前日志, 全部.size()) if 前日志 < 全部.size() else []
	var 后手 = 宿主._手牌快照()
	宿主._标记日志已播到末尾()
	宿主._构建演出队列(新增, 前手, 后手)
	宿主._演出跳过请求 = false
	宿主.refresh()
	宿主._消费演出队列()

static func _收新发牌提示(宿主) -> void:
	if 宿主._新发牌提示 == null:
		return
	宿主._新发牌提示.text = ""
	宿主._新发牌提示.visible = false

## 手牌栏里第 `索引` 张牌的目标控件 —— 旧手牌栏已删，单机卡走 `_点单机卡` 的即时演出，这里恒 null。
static func _手牌卡控件(_宿主, _索引: int) -> Control:
	return null

## 手牌落地脉冲：1.15x → 1.0x。
static func _脉冲手牌(宿主, 目标: Control) -> void:
	if 目标 == null or not is_instance_valid(目标):
		return
	目标.scale = Vector2.ONE
	if UiTheme.无声模式() or not 宿主.is_inside_tree() or not 目标.is_inside_tree():
		return
	目标.pivot_offset = 目标.size * 0.5
	var t := 目标.create_tween()
	t.tween_property(目标, "scale", Vector2(1.15, 1.15), 0.10)
	t.tween_property(目标, "scale", Vector2.ONE, 0.16)

## 这一拍之前 / 之后的手牌快照（纯读；用于「内核没给逐张发牌日志」时补出 `card_deal` 帧）。
## 单机牌组没有「全队共用战术手牌」这一层，快照恒空 —— 发牌帧走日志里的逐张记录（见已知缺口）。
static func _手牌快照(_宿主) -> Array:
	return []
