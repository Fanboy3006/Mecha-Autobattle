## 职责：殖民卫星军的两个覆盖层 —— QTE 手动弹窗（大招结算前选「失手 / 成功 / 完美」）与感应牌库明细面板。
## 约定：纯静态函数 + 宿主 `BattleView`（与 deck_sidebar / hand_panel 同一种写法）；只读门面，不改战斗结果。
extends RefCounted

## 这一张点下去要不要先弹 QTE：武器型觉醒大招 + 现在打得出来 + 会话处在「手动选择」。
static func 需QTE弹窗(宿主, c: Dictionary) -> bool:
	if 宿主.session == null or c.is_empty() or 宿主._QTE本次选择 != "":
		return false
	if str(c.get("区", "")) != GameSession.单机区_大招槽:
		return false
	if not bool(c.get("QTE", false)) or not bool(c.get("可打", false)):
		return false
	return 宿主.session.get_qte_mode() == "manual"

## 弹「失手 / 成功 / 完美」：先记下这一拍，等玩家选完才真正结算。
static func 弹QTE(宿主, 区: String, 键: String, 上排: bool, 目标键: String) -> void:
	if 宿主._QTE弹层 == null:
		return
	var c = 宿主._单机卡数据(键)
	宿主._QTE待决 = {"区": 区, "键": 键, "上排": 上排, "目标键": 目标键}
	if 宿主._QTE卡片名 != null:
		var 描 := str(c.get("描述", ""))
		宿主._QTE卡片名.text = "【%s】%s" % [str(c.get("名", 键)),
			"这一发结算前先选一档 QTE。" if 描.is_empty() else 描]
	宿主._QTE弹层.visible = true
	宿主._回话("QTE：请在弹窗里选「失手 / 成功 / 完美」", true)
	宿主.refresh()

## 玩家选了一档 → 带这一档重新走同一张牌（`_QTE本次选择` 非空时不会再弹）。
static func 选QTE(宿主, 档: String) -> void:
	if 宿主._QTE待决.is_empty():
		return
	var 待: Dictionary = 宿主._QTE待决
	宿主._QTE待决 = {}
	if 宿主._QTE弹层 != null:
		宿主._QTE弹层.visible = false
	宿主._QTE本次选择 = 档
	宿主._打单机卡(str(待.get("区", "")), str(待.get("键", "")), bool(待.get("上排", true)), str(待.get("目标键", "")))
	宿主._QTE本次选择 = ""

static func 取消QTE(宿主) -> void:
	宿主._QTE待决 = {}
	宿主._QTE本次选择 = ""
	if 宿主._QTE弹层 != null:
		宿主._QTE弹层.visible = false
	宿主._回话("QTE：这一发先不打了（牌还在手里）", true)
	宿主.refresh()

## 建 QTE 弹层：黑幕 + 居中面板 + 三个档位按钮 + 取消。
static func 建QTE弹层(宿主) -> void:
	var 层 := Control.new()
	层.name = "QTE弹层"
	层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.z_index = 20
	宿主.add_child(层)
	UiTheme.占满(层)
	var 黑 := ColorRect.new()
	黑.name = "QTE黑幕"
	黑.color = UiTheme.黑幕
	UiTheme.占满(黑)
	黑.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(黑)
	var 居 := CenterContainer.new()
	居.name = "QTE居中"
	UiTheme.占满(居)
	居.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.add_child(居)
	var 板 := UiTheme.建面板(居, "QTE面板", UiTheme.面板底, UiTheme.金边)
	板.custom_minimum_size = Vector2(420, 0)
	板.clip_contents = true
	var 列 := UiTheme.建盒(板, "QTE上下列", true, UiTheme.间距)
	var 题 := UiTheme.建标签(列, "QTE 判定", UiTheme.字号_小节, UiTheme.金边)
	题.name = "QTE标题"
	宿主._QTE卡片名 = UiTheme.建说明(列, "", UiTheme.字号_正文, UiTheme.主文字)
	宿主._QTE卡片名.name = "QTE卡片"
	var 行 := UiTheme.建盒(列, "QTE按钮行", false, UiTheme.间距)
	行.alignment = BoxContainer.ALIGNMENT_CENTER
	for 组 in [["miss", "失手", "QTE失手按钮"], ["good", "成功", "QTE成功按钮"], ["perfect", "完美", "QTE完美按钮"]]:
		var b := UiTheme.建按钮(行, str(组[1]), 选QTE.bind(宿主, str(组[0])))
		b.name = str(组[2])
		b.custom_minimum_size = Vector2(96, 32)
	var 提 := UiTheme.建说明(列, "选完才会结算这一发：失手 / 成功 / 完美 决定命中与伤害加成。", UiTheme.字号_小, UiTheme.次要文字)
	提.name = "QTE提示"
	var 取 = UiTheme.建按钮(列, "取消（这一发不打）", 取消QTE.bind(宿主))
	取.name = "QTE取消按钮"
	宿主._QTE弹层 = 层
	层.visible = false

## 左栏「感应牌库」按钮点开：把库内牌（一 / 二 / 三级）与本场移出逐张列出来。
static func 开感应面板(宿主) -> void:
	if 宿主.session == null or 宿主._感应面板 == null:
		return
	var 态: Dictionary = 宿主.session.感应牌库状态()
	if not bool(态.get("有", false)):
		宿主._回话("这一场没有感应牌库（队里没有殖民卫星军成员）", false)
		宿主.refresh()
		return
	宿主._清空(宿主._感应面板列表)
	var 计: Dictionary = 态.get("各级", {}) if 态.get("各级") is Dictionary else {}
	var 移出: Array = 态.get("移出", []) if 态.get("移出") is Array else []
	宿主._感应面板标题.text = "感应牌库：一级 %d · 二级 %d · 三级 %d（本场移出 %d）" % [
		int(计.get("一级", 0)), int(计.get("二级", 0)), int(计.get("三级", 0)), 移出.size()]
	var 序 := 0
	for c in (态.get("明细") as Array) if 态.get("明细") is Array else []:
		if not (c is Dictionary):
			continue
		序 += 1
		var l := UiTheme.建标签(宿主._感应面板列表, "%d. %s【%s】" % [序, 级文(int(c.get("级", 0))), str(c.get("名", ""))],
			UiTheme.字号_小, 级色(int(c.get("级", 0))))
		l.name = "感应牌库行"
	if 序 == 0:
		var 空 := UiTheme.建标签(宿主._感应面板列表, "（感应牌库已经抽空了）", UiTheme.字号_小, UiTheme.弱文字)
		空.name = "感应牌库空"
	if not 移出.is_empty():
		var 分 := UiTheme.建标签(宿主._感应面板列表, "—— 本场已移出 ——", UiTheme.字号_小, UiTheme.次要文字)
		分.name = "感应牌库分隔"
		for c2 in 移出:
			if not (c2 is Dictionary):
				continue
			var l2 := UiTheme.建标签(宿主._感应面板列表, "· %s【%s】（不回库）" % [级文(int(c2.get("级", 0))), str(c2.get("名", ""))],
				UiTheme.字号_小, UiTheme.弱文字)
			l2.name = "感应牌库移出行"
	宿主._感应面板.visible = true

static func 关感应面板(宿主) -> void:
	if 宿主._感应面板 != null:
		宿主._感应面板.visible = false

## 建感应牌库明细面板（半透明底 + 滚动列表 + 关闭）。
static func 建感应面板(宿主) -> void:
	var 层 := Control.new()
	层.name = "感应牌库面板"
	层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.z_index = 21
	宿主.add_child(层)
	UiTheme.占满(层)
	var 黑 := ColorRect.new()
	黑.name = "感应黑幕"
	黑.color = UiTheme.黑幕
	UiTheme.占满(黑)
	黑.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(黑)
	var 居 := CenterContainer.new()
	居.name = "感应居中"
	UiTheme.占满(居)
	居.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.add_child(居)
	var 板 := UiTheme.建面板(居, "感应面板体", UiTheme.面板底, UiTheme.连携色)
	板.custom_minimum_size = Vector2(420, 300)
	板.clip_contents = true
	var 列 := UiTheme.建盒(板, "感应上下列", true, UiTheme.间距_小)
	var 顶行 := UiTheme.建盒(列, "感应标题行", false, UiTheme.间距_小)
	宿主._感应面板标题 = UiTheme.建标题(顶行, "感应牌库", UiTheme.字号_小节)
	宿主._感应面板标题.name = "感应面板标题"
	宿主._感应面板标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var 关 := UiTheme.建按钮(顶行, "关闭", 关感应面板.bind(宿主))
	关.name = "感应面板关闭按钮"
	var 滚 := ScrollContainer.new()
	滚.name = "感应列表滚动"
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.custom_minimum_size = Vector2(0, 220)
	列.add_child(滚)
	宿主._感应面板列表 = UiTheme.建盒(滚, "感应列表", true, 1)
	宿主._感应面板列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._感应面板 = 层
	层.visible = false

## 感应牌等级 → 中文 / 颜色（一级白、二级青、三级金）。
static func 级文(级: int) -> String:
	return {1: "一级", 2: "二级", 3: "三级"}.get(级, "衍生")

static func 级色(级: int) -> Color:
	if 级 >= 3:
		return UiTheme.金边
	if 级 == 2:
		return UiTheme.连携色
	return UiTheme.主文字
