## 职责：4×4 棋盘（敌方 / 战线 / 我方）、双方机体卡填充、援护连线、动作播报条与本拍摘要。
extends RefCounted

## 上半区（中栏上）：顶部提示 + 播报条 + 上下对峙的 4×4 棋盘。
static func _建阵型区(宿主, 父: Node) -> void:
	宿主._阵型区 = UiTheme.建盒(父, "阵型区", true, UiTheme.间距_小)
	宿主._阵型区.custom_minimum_size = Vector2(0, 宿主.阵型区高)
	宿主._阵型区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._阵型区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.占满(宿主._阵型区)
	宿主._阵型提示 = UiTheme.建说明(宿主._阵型区, "现在不在战斗里 —— 从主菜单点「快速测试：秘银五人 / ATX 五人」，或者在大地图的作战格上点「开战」。",
		UiTheme.字号_小, UiTheme.弱文字)
	宿主._阵型提示.name = "阵型提示"
	宿主._建播报条(宿主._阵型区)
	var 主体 = UiTheme.建盒(宿主._阵型区, "阵型主体", true, 2)
	主体.size_flags_vertical = Control.SIZE_EXPAND_FILL
	主体.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	宿主._敌方列 = 宿主._建一方(主体, "敌方阵型", "敌方阵型（前排 4 + 后排 4，4×4 棋盘上半；敌前排紧贴战线）", 宿主.敌方, true)
	宿主._战线分隔(主体)
	宿主._我方列 = 宿主._建一方(主体, "我方阵型", "我方阵型（前排 4 + 后排 4，4×4 棋盘下半；我前排紧贴战线）", 宿主.我方, false)

## 敌我之间的前线接触线（高 4px 的亮色横条，悬停写着「距离 1」）。
static func _战线分隔(宿主, 父: Node) -> void:
	var 条 := PanelContainer.new()
	条.name = "战线分隔条"
	条.clip_contents = true
	条.mouse_filter = Control.MOUSE_FILTER_PASS
	条.custom_minimum_size = Vector2(0, 宿主.战线条高)
	条.tooltip_text = "前线接触线（距离 1）：上下紧贴它的两排就是双方前排"
	var 样 := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 1)
	样.content_margin_left = 0
	样.content_margin_right = 0
	样.content_margin_top = 0
	样.content_margin_bottom = 0
	条.add_theme_stylebox_override("panel", 样)
	父.add_child(条)
	宿主._战线分隔条 = 条

## 一方阵型：4 列 × 2 排。
static func _建一方(宿主, 父: Node, 名: String, 标题: String, 方: String, 反序: bool) -> VBoxContainer:
	var 列 := UiTheme.建盒(父, 名, true, 2) as VBoxContainer
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	列.tooltip_text = 标题
	var 卡们: Array = 宿主._我方卡 if 方 == 宿主.我方 else 宿主._敌方卡
	卡们.resize(int(Fm.SLOTS()))
	var 行序: Array = []
	for 行 in int(Fm.ROWS()):
		行序.append(行)
	if 反序:
		行序.reverse()
	for 行 in 行序:
		var 称呼 = ("我" if 方 == 宿主.我方 else "敌") + ("前排" if int(行) == int(Fm.ROW_FRONT) else "后排")
		var 行盒 := UiTheme.建盒(列, "%s第%d排" % [名, 行], false, 2)
		行盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行盒.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		行盒.tooltip_text = "%s（%s · 第 %d 排 · 4 列 · slot %d..%d）" % [Fm.行名(float(行)), 称呼,
			int(行) + 1, int(Fm.slotOf(float(行), 0.0)), int(Fm.slotOf(float(行), 3.0))]
		行盒.set_meta("row_label", 称呼)
		行盒.set_meta("first_slot", int(Fm.slotOf(float(行), 0.0)))
		for 列号 in int(Fm.行列数(float(行))):
			var 卡 := UnitCard.new()
			行盒.add_child(卡)
			卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			卡.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			卡.setup({"ok": false, "为什么": "现在不在战斗里"})
			卡.设紧凑棋盘(true)
			卡.开关切换.connect(宿主._点开关)
			if 方 == 宿主.我方:
				卡.点选.connect(宿主._点选机体)
			var 格位 := int(Fm.slotOf(float(行), float(列号)))
			卡.set_meta("slot", 格位)
			卡们[格位] = 卡
	return 列

## 建那条播报条：`PanelContainer`（高对比金边深底）+ 里面**一个**单行裁切 `Label`。
static func _建播报条(宿主, 父: Node) -> void:
	var 底 := PanelContainer.new()
	底.name = "动作播报条底"
	底.clip_contents = true
	底.mouse_filter = Control.MOUSE_FILTER_PASS
	底.custom_minimum_size = Vector2(0, 宿主.播报条高)
	var 样 := UiTheme.底样式(UiTheme.卡片底_亮, UiTheme.高亮, 2)
	样.content_margin_left = 8
	样.content_margin_right = 8
	样.content_margin_top = 2
	样.content_margin_bottom = 2
	底.add_theme_stylebox_override("panel", 样)
	父.add_child(底)
	宿主._动作播报条 = 宿主._建单行标签(底, "动作播报条", "【战斗开始】等待推进下一拍或点击自动播放",
		UiTheme.字号_正文, UiTheme.高亮)

static func _画阵型(宿主, 在战斗: bool) -> void:
	if not 在战斗:
		宿主._填一方(宿主._我方卡, 宿主.我方, {}, false)
		宿主._填一方(宿主._敌方卡, 宿主.敌方, {}, false)
		return
	宿主._填一方(宿主._我方卡, 宿主.我方, 宿主._位号到键(宿主.我方), true)
	宿主._填一方(宿主._敌方卡, 宿主.敌方, 宿主._位号到键(宿主.敌方), true)

static func _算援护(宿主, 在战斗: bool) -> void:
	宿主._护卫提示 = {}
	宿主._护卫线们 = []
	if not 在战斗 or 宿主.session == null or 宿主.session.battle_ctx.is_empty():
		return
	for l in 宿主.session.guard_links():
		if not (l is Dictionary):
			continue
		var 键甲 := str((l as Dictionary).get("from_key", ""))
		var 键乙 := str((l as Dictionary).get("to_key", ""))
		if 键甲.is_empty() or 键乙.is_empty():
			continue
		var 标 := str((l as Dictionary).get("label", ""))
		var 尾 := 标
		if 尾.is_empty():
			尾 = "援护"
		宿主._护卫提示[键甲] = "〔护→%s %s〕" % [str((l as Dictionary).get("to_name", "")), 尾]
		宿主._护卫提示[键乙] = "〔护←%s %s〕" % [str((l as Dictionary).get("from_name", "")), 尾]
		var 卡甲 = 宿主._阵型卡Of键(键甲)
		var 卡乙 = 宿主._阵型卡Of键(键乙)
		if 卡甲 != null and 卡乙 != null:
			宿主._护卫线们.append({"起点卡": 卡甲, "终点卡": 卡乙, "文案": 尾})

## 把算好的援护连线推到动画层（`战斗动画层` = 规格里的「特效画布」）。
static func _推援护线(宿主) -> void:
	if 宿主._战斗动画层 == null or not is_instance_valid(宿主._战斗动画层):
		return
	宿主._战斗动画层.set_guard_links(宿主._护卫线们)

## ★ IT-5：敌方意图连线（读门面 `enemy_intents()`；只在我方阶段、战斗没结束时画）。
static func _推意图线(宿主, 在战斗: bool) -> void:
	if 宿主._战斗动画层 == null or not is_instance_valid(宿主._战斗动画层):
		return
	var 线们: Array = []
	if 在战斗 and 宿主.session != null and 宿主.session.battle_ctx.get("result") == null:
		for x in 宿主.session.enemy_intents():
			if not (x is Dictionary) or str((x as Dictionary).get("动作类型", "")) != "攻击":
				continue
			var 卡甲 = 宿主._阵型卡Of键(str((x as Dictionary).get("键", "")))
			var 卡乙 = 宿主._阵型卡Of键(str((x as Dictionary).get("目标", "")))
			if 卡甲 == null or 卡乙 == null:
				continue
			var 大 := bool((x as Dictionary).get("大招", false)) or bool((x as Dictionary).get("大技能", false))
			线们.append({"起点卡": 卡甲, "终点卡": 卡乙, "大招": 大,
				"文案": "%s%d" % ["大招 " if 大 else "", int((x as Dictionary).get("期望", 0.0))]})
	宿主._战斗动画层.set_intent_links(线们)

## 场上一张 `UnitCard`（我方 + 敌方都找；找不到 = null）。
static func _阵型卡Of键(宿主, 键: String) -> UnitCard:
	if 键.is_empty():
		return null
	for 列表 in [宿主._我方卡, 宿主._敌方卡]:
		for 卡 in (列表 as Array):
			if 卡 is UnitCard and str((卡 as UnitCard).数据.get("键", "")) == 键:
				return 卡
	return null

## 现在画着几条援护连线（自动化测试读它）。
static func 援护连线数(宿主) -> int:
	if 宿主._战斗动画层 == null or not is_instance_valid(宿主._战斗动画层):
		return 0
	return (宿主._战斗动画层 as Node).call("护卫连线数")

## ★ P3-1：`卡们` 的下标 `位号` **就是真实 `slot (0..7)`**（`_建一方` 已按 `Fm.slotOf()` 落位），…
static func _填一方(宿主, 卡们: Array, 方: String, 占位: Dictionary, 在战斗: bool) -> void:
	for 位号 in 卡们.size():
		var 卡: UnitCard = 卡们[位号] if 卡们[位号] is UnitCard else null
		if 卡 == null:
			continue
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
		var d = 宿主.session.unit_view(方, 键)
		d["护卫提示"] = str(宿主._护卫提示.get(键, ""))
		if 方 == 宿主.敌方:
			if not 宿主._单机牌组():
				d["意图"] = 宿主._敌意(位号)
			d["介入"] = 宿主.session.介入标记(键)
		elif 宿主._单机牌组():
			var 威胁: Array = d.get("威胁") if d.get("威胁") is Array else []
			if not 威胁.is_empty():
				d["意图"] = ["；".join(威胁.map(func(x): return str(x)))]
		卡.数据 = d
		卡.设为选中(方 == 宿主.我方 and bool(d.get("选中", false)))
		卡.refresh()

## 这一场是不是单机牌组（判据只问门面：`session.单机牌组开()`，它再问内核 `Params.单机牌组_开`）。
static func _单机牌组(宿主) -> bool:
	return 宿主.session != null and 宿主.session.单机牌组开()

## ★ DECK-3 §1：点我方机体卡 → 门面 `select_battle_unit()`（纯表现层选择，不改内核）。
static func _点选机体(宿主, 单位键: String) -> void:
	if 宿主.session == null:
		return
	var r = 宿主.session.select_battle_unit(单位键)
	if bool(r.get("ok", false)):
		宿主._回话("选中 【%s】：战意 %s / %s · 上排 %d 张 · 下排 %d 张" % [
			str(r.get("名", 单位键)), UiTheme.文本(r.get("战意", 0.0)),
			UiTheme.文本(Params.战意上限()), int(r.get("上排", 0)), int(r.get("下排", 0))], true)
	else:
		宿主._回话("选不了：%s" % 宿主._为什么(r), false)
	宿主.refresh()

## `位号 → 机体键`：直接读 `battle_ctx` 的 `allies` / `enemies`（纯读，一个数都不算）。
static func _位号到键(宿主, 方: String) -> Dictionary:
	var out := {}
	if 宿主.session == null or 宿主.session.battle_ctx.is_empty():
		return out
	var 池: Variant = 宿主.session.battle_ctx.get("allies") if 方 == 宿主.我方 else 宿主.session.battle_ctx.get("enemies")
	if not (池 is Array):
		return out
	for x in (池 as Array):
		if x is Dictionary:
			out[int(float((x as Dictionary).get("slot", -1.0)))] = str((x as Dictionary).get("key", ""))
	return out

static func _单位字典(宿主, 方: String, 位号: int) -> Dictionary:
	if 宿主.session == null or 宿主.session.battle_ctx.is_empty():
		return {}
	var 池: Variant = 宿主.session.battle_ctx.get("allies") if 方 == 宿主.我方 else 宿主.session.battle_ctx.get("enemies")
	if not (池 is Array):
		return {}
	for x in (池 as Array):
		if x is Dictionary and int(float((x as Dictionary).get("slot", -1.0))) == 位号:
			return x
	return {}

## 敌方下一拍行动意图预告：`Boss.bossAction()` 是内核现成的纯函数（JS `算意图()` 内层就是它）。
static func _敌意(宿主, 位号: int) -> Array:
	var 条: Array = []
	if 宿主.session == null or 宿主.session.battle_ctx.is_empty():
		return 条
	var u = 宿主._单位字典(宿主.敌方, 位号)
	if u.is_empty():
		return 条
	var ctx: Dictionary = 宿主.session.battle_ctx
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

## 写播报条（文本为空时**保留上一拍**，不清成空白）。
static func _写播报条(宿主, 文: String, 色: Color = UiTheme.高亮) -> void:
	if 宿主._动作播报条 == null or 文.is_empty():
		return
	宿主._动作播报条.text = 文
	宿主._动作播报条.add_theme_color_override("font_color", 色)

## 播报条当前文本（自动化测试与别处读它）。
static func 播报文本(宿主) -> String:
	return "" if 宿主._动作播报条 == null else str(宿主._动作播报条.text)

## 没有会话时的空态：播报条写一行提示、动画层收干净（不建任何 Tween）。
static func _写作战画面空态(宿主) -> void:
	宿主._已播日志数 = 0
	宿主._已播日志引用 = null
	宿主._表演中止()
	if 宿主._战斗动画层 != null:
		宿主._战斗动画层.清空()
	宿主._写播报条("【战斗开始】没有会话 —— 开一局战斗之后这一条会播报每一拍谁打了谁", UiTheme.弱文字)

## 把本拍事件压成一行：攻击 / 大招 / 修理 / 战术牌 / 势力 谁先有就播谁，…
static func _本拍摘要(宿主, 新们: Array) -> String:
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
		行 = 宿主._攻击摘要(攻)
	elif not 修.is_empty():
		行 = 宿主._修理摘要(修)
	elif not 牌.is_empty():
		行 = 宿主._战术牌摘要(牌)
	elif not 势.is_empty():
		行 = 宿主._势力摘要(势)
	elif 新们[0] is Dictionary:
		行 = 宿主._通用摘要(新们[0])
	if 行.is_empty():
		return ""
	var 尾: Array = []
	for e in 击破们:
		var 名 = 宿主._单位名(str((e as Dictionary).get("目标方", "")),
			int(float((e as Dictionary).get("目标位", -1.0))), str((e as Dictionary).get("目标", "")))
		var 条 = "【击破】%s！" % 名
		if not 尾.has(条) and not 行.contains(条):
			尾.append(条)
	if not 势.is_empty() and str(势.get("类型", "")) == "连携":
		尾.append("〔连携追击〕")
	if not 尾.is_empty():
		行 += " · " + " · ".join(尾)
	return 行

## 播报条该用哪个颜色（与摘要同一条判据，不另立口径）。
static func _本拍色(宿主, 新们: Array) -> Color:
	for e in 新们:
		if not (e is Dictionary):
			continue
		var 类 := str(e.get("类型", ""))
		if 类 == "攻击" or 类 == "镜甲":
			if not bool(e.get("命中", true)) or float(e.get("伤害", 0.0)) <= 0.0:
				return UiTheme.未命中色
			if int(float(e.get("暴击", 0.0))) > 0 or 宿主._是大招(e):
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

static func _攻击摘要(宿主, e: Dictionary) -> String:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 攻名 = 宿主._单位名(攻方, 攻位, str(e.get("单位", "")))
	var 目名 = 宿主._单位名(目方, 目位, str(e.get("目标", "")))
	var 武器 := str(e.get("武器", ""))
	var 伤害 := float(e.get("伤害", 0.0))
	var 命中 := bool(e.get("命中", true))
	var 有伤 := 伤害 > 0.0
	if str(e.get("类型", "")) == "镜甲":
		return "【镜甲】%s%s 的镜甲 -> 反弹给%s%s · 反弹 %s 伤害！" % [宿主._位文字(攻方, 攻位), 攻名,
			宿主._位文字(目方, 目位), 目名, 宿主._数字(伤害)]
	var 头 = "【大招】" if 宿主._是大招(e) else "【攻击】"
	var 行 = "%s%s%s -> 使用【%s】攻击%s%s" % [头, 宿主._位文字(攻方, 攻位), 攻名, 武器,
		宿主._位文字(目方, 目位), 目名]
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
			行 += " · 造成 %s 伤害！" % 宿主._数字(伤害)
		else:
			行 += " · 伤害 0"
	if bool(e.get("总攻", false)):
		行 += " · 〔总攻〕"
	if float(e.get("特种破甲", 0.0)) > 0.0:
		行 += " · 〔破甲〕"
	if bool(e.get("连斩追击", false)):
		行 += " · 〔连携追击〕"
	return 行

static func _修理摘要(宿主, e: Dictionary) -> String:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	return "【修理】%s%s -> 修理%s%s · 回复 +%s 耐久" % [宿主._位文字(修方, 修位),
		宿主._单位名(修方, 修位, str(e.get("单位", ""))), 宿主._位文字(目方, 目位),
		宿主._单位名(目方, 目位, str(e.get("目标", ""))), 宿主._数字(float(e.get("回复", 0.0)))]

static func _战术牌摘要(宿主, e: Dictionary) -> String:
	var 效 := str(e.get("效果说明", ""))
	if 效.is_empty():
		效 = "已发动"
	return "【战术牌】打出【%s】 -> %s" % [str(e.get("牌名", "")), 效]

static func _势力摘要(宿主, e: Dictionary) -> String:
	var 文 := str(e.get("文本", "")).strip_edges()
	文 = 文.trim_prefix("〔势力〕")
	if 文.is_empty():
		return ""
	return "【势力】%s" % 文

static func _通用摘要(宿主, e: Dictionary) -> String:
	return str(e.get("文本", "")).strip_edges()

## `〔牌名〕…` / `〔大招槽〕毛 打出【X】（…）→ 细节` → 只留「细节」那一段。
static func _剥文本前缀(宿主, 文: String) -> String:
	var s := 文.strip_edges()
	var i := s.find(" → ")
	if i >= 0:
		return s.substr(i + 3).strip_edges()
	if s.begins_with("〔"):
		var j := s.find("〕")
		if j >= 0:
			s = s.substr(j + 1).strip_edges()
	if s.contains("打出【"):
		var k := s.find("）")
		if k >= 0:
			s = s.substr(k + 1).strip_edges()
		elif s.contains("】"):
			s = s.substr(s.find("】") + 1).strip_edges()
	return s

## 这一条事件里「具体效果」那一段（`效果摘要` 字段优先，否则从 `文本` 里剥前缀）。
static func _卡牌摘要尾(宿主, e: Dictionary) -> String:
	var 段: Array = []
	var 摘: Variant = e.get("效果摘要")
	if 摘 is Array:
		for x in (摘 as Array):
			var t := str(x).strip_edges()
			if not t.is_empty():
				段.append(t)
	var s := "、".join(段)
	if s.is_empty():
		s = 宿主._剥文本前缀(str(e.get("文本", "")))
	if s.length() > 30:
		s = s.substr(0, 30) + "…"
	return s

## 某方某一格上的 `UnitCard`（越界 / 空格 → null）。
static func _卡(宿主, 方: String, 位号: int) -> UnitCard:
	var 池: Array = 宿主._我方卡 if (方 == 宿主.我方 or 方 == "ally") else 宿主._敌方卡
	if 位号 < 0 or 位号 >= 池.size():
		return null
	var c: Variant = 池[位号]
	return c as UnitCard if (c is UnitCard) else null

## 机体显示名：读 `battle_ctx` 里那一台单位的 `name`（纯读；查不到就退回日志里的键）。
static func _单位名(宿主, 方: String, 位号: int, 键: String) -> String:
	var u = 宿主._单位字典(方, 位号)
	if not u.is_empty():
		var n = str(u.get("name", ""))
		if not n.is_empty():
			return n
	return 键

## 这一发攻击是不是大招：拿日志里的 `武器` 名回到出手方身上找那件武器，再问内核 `Ai.isUltimate`。
static func _是大招(宿主, e: Dictionary) -> bool:
	var 武器名 := str(e.get("武器", ""))
	if 武器名.is_empty():
		return false
	var u = 宿主._单位字典(str(e.get("单位方", "")), int(float(e.get("单位位", -1.0))))
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
static func _数字(宿主, 值: float) -> String:
	return str(int(JsCompat.js_round(值)))

static func _为什么(宿主, r: Dictionary) -> String:
	var w := str(r.get("为什么", ""))
	if not w.is_empty():
		return w
	if not 宿主.session.当前动作错误().is_empty():
		return str(宿主.session.当前动作错误())
	return "门面没有给出原因"
