## 职责：演出帧构建（发牌 / 攻击 / 修理 / 战术牌 / 事件 / 横幅）、弹道与飘字、卡片反馈。
extends RefCounted

## 把本拍日志拆成串行演出帧并**存进 `_演出队列`**（headless 下也存 —— 自动化测试直接查它）。
static func _构建演出队列(宿主, entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array:
	宿主._演出队列 = 宿主.构建单拍演出帧(entries, prev_hand, curr_hand)
	宿主._当前演出总帧数 = 宿主._演出队列.size()
	宿主._已播帧数 = 0
	return 宿主._演出队列

## 公共拆帧入口（**单元测试可以直接调它验拆帧逻辑**，不依赖节点树 / 不依赖 headless）：
static func 构建单拍演出帧(宿主, entries: Array, prev_hand: Array = [], curr_hand: Array = []) -> Array:
	var 帧们: Array = []
	var 已认领: Array = []
	if entries is Array:
		for e in entries:
			if not (e is Dictionary):
				continue
			var 事件: Dictionary = e
			match str(事件.get("类型", "")):
				"发牌":
					帧们.append(宿主._发牌帧(事件, prev_hand, curr_hand, 已认领))
				"攻击", "镜甲":
					帧们.append(宿主._攻击帧(事件))
				"修理":
					帧们.append(宿主._修理帧(事件))
				"战术牌", "连携":
					帧们.append(宿主._战术牌帧(事件))
				"专属精神牌", "公有牌", "大招槽", "连携牌", "筹码牌", "秘银v03":
					帧们.append(宿主._非攻击牌帧(事件))
				"Boss", "增援", "势力", "连斩", "击破", "结束":
					帧们.append(宿主._事件帧(事件))
				_:
					pass
	for idx in 宿主._手牌新增索引(prev_hand, curr_hand):
		if 已认领.has(idx):
			continue
		var c: Variant = curr_hand[idx]
		if not (c is Dictionary):
			continue
		帧们.append(宿主._手牌补帧(c, idx))
	return 帧们

## 队列现在有几帧 / 已经播了几帧（自动化测试与「跳过」按钮都读它）。
static func 演出帧数(宿主) -> int:
	return 宿主._演出队列.size()

static func 已播帧数(宿主) -> int:
	return 宿主._已播帧数

## 一帧的**终态**（headless 直接用它 / 跳过时补最后一帧）：
static func _应用帧终态(宿主, 帧: Dictionary, 序: int, 总: int) -> void:
	宿主._写演出横幅(帧, 序, 总, false)
	match str(帧.get("类别", "")):
		"card_deal":
			宿主._上发牌终态(帧)
		"attack":
			宿主._上动作终态(帧, false)
		"heal":
			宿主._上动作终态(帧, true)
		"card_fx":
			宿主._上卡牌终态(帧)
		_:
			pass

## 发牌帧的终态：来源卡亮青金脉冲 + 目标手牌直接落到「已获得」的脉冲余韵。
static func _上发牌终态(宿主, 帧: Dictionary) -> void:
	var 位 := int(帧.get("来源位", -1))
	if 位 >= 0:
		var 源卡 = 宿主._卡(宿主.我方, 位)
		if 源卡 != null:
			源卡.播放发牌脉冲()
	var 目标 = 宿主._手牌卡控件(int(帧.get("手牌索引", -1)))
	if 目标 != null:
		宿主._脉冲手牌(目标)

## 动作帧的终态：弹道 + 飘字 + 出手 / 受击卡反馈一次写到位（headless 走这里）。
static func _上动作终态(宿主, 帧: Dictionary, 治疗: bool) -> void:
	var e: Variant = 帧.get("日志")
	if not (e is Dictionary):
		return
	var 事件: Dictionary = e
	var 轨: Array = []
	var 飘: Array = []
	var 反馈: Dictionary = {}
	if 治疗:
		宿主._加修理动画(事件, 轨, 飘, 反馈)
	else:
		宿主._加攻击动画(事件, 轨, 飘, 反馈)
	宿主._清全部卡片反馈()
	宿主._应用卡片反馈(反馈)
	if 宿主._战斗动画层 != null:
		宿主._战斗动画层.set_trajectories(轨)
		宿主._战斗动画层.set_popups(飘)

## ★ 2026-10-22（任务单 P3-4）：非攻击牌帧的**终态**（headless 走这里 / 跳帧补最后一帧）——…
static func _上卡牌终态(宿主, 帧: Dictionary) -> void:
	var e: Variant = 帧.get("日志")
	if not (e is Dictionary):
		return
	宿主._清全部卡片反馈()
	var 飘: Array = []
	var 脉冲卡们: Array = []
	宿主._加卡牌演出(e, 飘, 脉冲卡们)
	宿主._播脉冲(脉冲卡们)
	if 宿主._战斗动画层 != null:
		宿主._战斗动画层.set_trajectories([])
		宿主._战斗动画层.set_popups(飘)

## ★ 2026-10-22（任务单 P3-4）：非攻击牌帧的**正常速度播放** ——…
static func _播卡牌帧(宿主, 帧: Dictionary) -> void:
	var e: Variant = 帧.get("日志")
	if not (e is Dictionary):
		return
	宿主._清全部卡片反馈()
	var 飘: Array = []
	var 脉冲卡们: Array = []
	宿主._加卡牌演出(e, 飘, 脉冲卡们)
	宿主._播脉冲(脉冲卡们)
	if 宿主._战斗动画层 != null:
		宿主._战斗动画层.set_trajectories([])
		宿主._战斗动画层.set_popups(飘)
		if not 飘.is_empty():
			宿主._战斗动画层.开始淡出(宿主.飘字停留秒)

## 写演出横幅（`带进度 = true` 时前面挂 `〔演出中 i/N〕`）。
static func _写演出横幅(宿主, 帧: Dictionary, 序: int, 总: int, 带进度: bool = true) -> void:
	var 文 := str(帧.get("横幅", ""))
	if 文.is_empty():
		return
	var 色: Color = 帧.get("颜色") if 帧.get("颜色") is Color else UiTheme.高亮
	if 带进度 and 总 > 0:
		宿主._写播报条("〔演出中 %d/%d〕%s" % [序, 总, 文], 色)
	else:
		宿主._写播报条(文, 色)

## 一条「发牌」日志 → 一个 `card_deal` 帧（每发一张牌 1 帧）。
static func _发牌帧(宿主, e: Dictionary, prev_hand: Array, curr_hand: Array, 已认领: Array) -> Dictionary:
	var 牌名 := str(e.get("牌名", ""))
	var 源文 := str(e.get("来源文本", ""))
	var 源位们: Array = e.get("来源位") if e.get("来源位") is Array else []
	var 源位 := -1
	if not 源位们.is_empty():
		源位 = 宿主._位名到位号(str(源位们[0]))
	var 源名 = 宿主._来源名(源文)
	if 源名.is_empty() and 源位 >= 0:
		源名 = 宿主._单位名(宿主.我方, 源位, "")
	if 源名.is_empty():
		源名 = "指挥官"
	var 索引 = 宿主._认领手牌(牌名, prev_hand, curr_hand, 已认领)
	if 索引 >= 0:
		已认领.append(索引)
	var 键 := ""
	if 源位 >= 0:
		键 = str(宿主._位号到键(宿主.我方).get(源位, ""))
	return {
		"类别": "card_deal", "回合": int(float(e.get("回合", 0.0))),
		"来源名": 源名, "来源位": 源位, "来源键": 键,
		"卡牌名": 牌名, "手牌索引": 索引, "日志": e,
		"横幅": "〔发牌〕来自【%s】 -> 获得战术牌【%s】" % [源名, 牌名],
		"颜色": UiTheme.高亮,
	}

## 手牌差集补出来的发牌帧（内核这一拍没给逐张「发牌」日志时用）。
static func _手牌补帧(宿主, c: Dictionary, idx: int) -> Dictionary:
	var 牌名 := str(c.get("名", ""))
	var 源文 := str(c.get("source_unit_text", ""))
	var 源位们: Array = c.get("source_slots") if c.get("source_slots") is Array else []
	var 源位 := -1
	if not 源位们.is_empty():
		源位 = 宿主._位名到位号(str(源位们[0]))
	var 源名 = 宿主._来源名(源文)
	if 源名.is_empty() and 源位 >= 0:
		源名 = 宿主._单位名(宿主.我方, 源位, "")
	if 源名.is_empty():
		源名 = "指挥官"
	var 键 := ""
	if 源位 >= 0:
		键 = str(宿主._位号到键(宿主.我方).get(源位, ""))
	return {
		"类别": "card_deal", "回合": 0,
		"来源名": 源名, "来源位": 源位, "来源键": 键,
		"卡牌名": 牌名, "手牌索引": idx, "日志": c,
		"横幅": "〔发牌〕来自【%s】 -> 获得战术牌【%s】" % [源名, 牌名],
		"颜色": UiTheme.高亮,
	}

## 本拍**新增**的手牌下标（多重集差集：同名牌各算各的）。
static func _手牌新增索引(宿主, prev_hand: Array, curr_hand: Array) -> Array:
	var 旧 := {}
	for c in prev_hand:
		if c is Dictionary:
			var k = 宿主._牌签名(c)
			旧[k] = int(旧.get(k, 0)) + 1
	var 新: Array = []
	for i in curr_hand.size():
		var c: Variant = curr_hand[i]
		if not (c is Dictionary):
			continue
		var k = 宿主._牌签名(c)
		var 剩 = int(旧.get(k, 0))
		if 剩 > 0:
			旧[k] = 剩 - 1
			continue
		新.append(i)
	return 新

## 一张手牌的签名（有内核实例号就用实例号，否则退成 `id|名|层级`）。
static func _牌签名(宿主, c: Dictionary) -> String:
	var 实例值: Variant = c.get("_实例号")
	if 实例值 is int or 实例值 is float:
		var 实例 := int(实例值)
		if 实例 > 0:
			return "i:%d" % 实例
	return "n:%s|%s|%s" % [str(c.get("id", "")), str(c.get("名", "")), str(c.get("层级", ""))]

## 本拍新增手牌里认领一张（按牌名；先只在「新增」里找，找不到再退回全手牌）。
static func _认领手牌(宿主, 牌名: String, prev_hand: Array, curr_hand: Array, 已认领: Array) -> int:
	for i in 宿主._手牌新增索引(prev_hand, curr_hand):
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
static func _来源名(宿主, 源文: String) -> String:
	var 文 := 源文.replace("来自：", "").strip_edges()
	var p := 文.find("（")
	if p > 0:
		文 = 文.substr(0, p)
	return 文.strip_edges()

## 位名（`"前1"` / `"后4"`）→ 位号（0..7）；认不出来 → −1。
static func _位名到位号(宿主, 位名: String) -> int:
	if 位名.is_empty():
		return -1
	for i in int(Fm.SLOTS()):
		if Fm.位名(float(i)) == 位名:
			return i
	return -1

## 一条攻击日志 → 一个 `attack` 帧（攻击 / 大招 / 镜甲反弹 / 连斩追加，每次出手 1 帧）。
static func _攻击帧(宿主, e: Dictionary) -> Dictionary:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 攻名 = 宿主._单位名(攻方, 攻位, str(e.get("单位", "")))
	var 目名 = 宿主._单位名(目方, 目位, str(e.get("目标", "")))
	return {
		"类别": "attack", "回合": int(float(e.get("回合", 0.0))),
		"出手方": 攻方, "出手位": 攻位, "出手名": 攻名,
		"目标方": 目方, "目标位": 目位, "目标名": 目名,
		"武器": str(e.get("武器", "")), "大招": 宿主._是大招(e),
		"镜甲": str(e.get("类型", "")) == "镜甲", "日志": e,
		"横幅": 宿主._攻击横幅(e, 攻名, 目名), "颜色": 宿主._本拍色([e]),
	}

## 一条修理日志 → 一个 `heal` 帧。
static func _修理帧(宿主, e: Dictionary) -> Dictionary:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 修名 = 宿主._单位名(修方, 修位, str(e.get("单位", "")))
	var 目名 = 宿主._单位名(目方, 目位, str(e.get("目标", "")))
	return {
		"类别": "heal", "回合": int(float(e.get("回合", 0.0))),
		"出手方": 修方, "出手位": 修位, "出手名": 修名,
		"目标方": 目方, "目标位": 目位, "目标名": 目名, "日志": e,
		"横幅": "【修理】%s【%s】 -> %s【%s】 · 回复 +%s 耐久" % [宿主._方中文(修方), 修名,
			宿主._方中文(目方), 目名, 宿主._数字(float(e.get("回复", 0.0)))],
		"颜色": UiTheme.支援色,
	}

## 一条战术牌 / 连携日志 → 一个 `tactic_card` 帧。
static func _战术牌帧(宿主, e: Dictionary) -> Dictionary:
	var 文 := ""
	if str(e.get("类型", "")) == "连携":
		文 = "【连携】%s" % str(e.get("文本", "")).strip_edges()
		if 文 == "【连携】":
			文 = "【连携】打出【%s】" % str(e.get("牌名", ""))
	else:
		文 = 宿主._战术牌摘要(e)
	return {
		"类别": "tactic_card", "回合": int(float(e.get("回合", 0.0))),
		"日志": e, "横幅": 文, "颜色": UiTheme.高亮,
	}

## ★ 2026-10-22（任务单 P3-4）：一条**非攻击牌**日志（精神 / 公有 / 大招 / 连携 / 筹码 / 秘银v03）
static func _非攻击牌帧(宿主, e: Dictionary) -> Dictionary:
	var 文 := str(e.get("文本", "")).strip_edges()
	if 文.is_empty():
		文 = "【%s】打出【%s】" % [str(e.get("类型", "")), str(e.get("牌名", ""))]
	return {
		"类别": "card_fx", "回合": int(float(e.get("回合", 0.0))),
		"日志": e, "横幅": 文, "颜色": UiTheme.高亮,
	}

## 一条重要战场事件（Boss / 增援 / 势力 / 击破 / 结束）→ 一个 `event` 帧。
static func _事件帧(宿主, e: Dictionary) -> Dictionary:
	var 文 := str(e.get("文本", "")).strip_edges()
	var 类 := str(e.get("类型", ""))
	if 文.is_empty():
		文 = "【%s】" % 类
	elif not 文.begins_with("〔"):
		文 = "【%s】%s" % [类, 文]
	return {
		"类别": "event", "回合": int(float(e.get("回合", 0.0))),
		"日志": e, "横幅": 文, "颜色": 宿主._日志色(e),
	}

## 攻击帧的横幅（★ UX-5 规格：`【出手方】使用【武器名】 -> 【受击方】 · 造成 XXX 伤害`）。
static func _攻击横幅(宿主, e: Dictionary, 攻名: String, 目名: String) -> String:
	var 攻方 := str(e.get("单位方", ""))
	var 目方 := str(e.get("目标方", ""))
	var 武器 := str(e.get("武器", ""))
	if 武器.is_empty():
		武器 = "普通攻击"
	var 行 := ""
	if str(e.get("类型", "")) == "镜甲":
		行 = "【镜甲】%s【%s】反弹 -> %s【%s】" % [宿主._方中文(攻方), 攻名, 宿主._方中文(目方), 目名]
	else:
		var 头 = "【大招】" if 宿主._是大招(e) else "【攻击】"
		行 = "%s%s【%s】使用【%s】 -> %s【%s】" % [头, 宿主._方中文(攻方), 攻名, 武器, 宿主._方中文(目方), 目名]
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
			行 += " · 造成 %s 伤害" % 宿主._数字(伤害)
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

## 每次 `refresh()` 结算一次「本拍」：取新增日志 → 写播报条 → 出弹道与飘字 → 给卡片打反馈。
static func _画战斗动画(宿主, 在战斗: bool) -> void:
	if 宿主._动作播报条 == null:
		return
	if not 在战斗:
		宿主._已播日志数 = 0
		宿主._已播日志引用 = null
		宿主._表演中止()
		宿主._清拖拽状态()
		if 宿主._战斗动画层 != null:
			宿主._战斗动画层.清空()
		宿主._清全部卡片反馈()
		宿主._写播报条("【战斗开始】现在不在战斗里 —— 开战之后这一条会播报每一拍谁打了谁、造成多少伤害",
			UiTheme.弱文字)
		return
	if 宿主._演出进行中:
		return
	if 宿主._演出预热:
		return
	var 日志: Variant = 宿主.session.battle_ctx.get("log")
	if not is_same(日志, 宿主._已播日志引用):
		宿主._表演中止()
	var 新们 = 宿主._取本拍事件()
	if 新们.is_empty():
		return
	var 有开始 := false
	for e in 新们:
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "开始":
			有开始 = true
			break
	if 有开始:
		宿主._写播报条("【战斗开始】等待推进下一拍或点击自动播放", UiTheme.高亮)
		if 宿主._战斗动画层 != null:
			宿主._战斗动画层.清空()
		宿主._清全部卡片反馈()
		return
	宿主._应用本拍(新们)

## 取「本拍」新增的战斗日志事件。
static func _取本拍事件(宿主) -> Array:
	var 全部 = 宿主.session.battle_log_entries(0)
	var 日志: Variant = 宿主.session.battle_ctx.get("log")
	if not is_same(日志, 宿主._已播日志引用):
		宿主._已播日志引用 = 日志
		宿主._已播日志数 = 0
	var n = 全部.size()
	if n < 宿主._已播日志数:
		宿主._已播日志数 = 0
	if n == 0:
		return []
	var 起: int = 宿主._已播日志数
	if 起 == 0:
		起 = n - 宿主._收窄到最后一拍(全部).size()
	宿主._已播日志数 = n
	if 起 >= n:
		return []
	return 宿主._收窄到最后一拍(全部.slice(起, n))

## 只留**最后一个回合号**那一组事件（一拍 = 一个回合号；自动打完时会跨很多回合，…
static func _收窄到最后一拍(宿主, 事件们: Array) -> Array:
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

## 把本拍事件翻译成「弹道数组 + 飘字数组 + 卡片反馈」，然后一次写进动画层与卡片。
static func _应用本拍(宿主, 新们: Array) -> void:
	var 轨: Array = []
	var 飘: Array = []
	var 反馈: Dictionary = {}
	var 脉冲卡们: Array = []
	for e in 新们:
		if not (e is Dictionary):
			continue
		match str(e.get("类型", "")):
			"攻击":
				宿主._加攻击动画(e, 轨, 飘, 反馈)
			"镜甲":
				宿主._加镜甲动画(e, 轨, 飘, 反馈)
			"修理":
				宿主._加修理动画(e, 轨, 飘, 反馈)
			"势力":
				宿主._加势力胶囊(e, 飘)
			"专属精神牌", "公有牌", "大招槽", "连携牌", "筹码牌", "秘银v03":
				宿主._加卡牌演出(e, 飘, 脉冲卡们)
			_:
				pass
	宿主._清全部卡片反馈()
	宿主._应用卡片反馈(反馈)
	宿主._播脉冲(脉冲卡们)
	if 宿主._战斗动画层 != null:
		宿主._战斗动画层.set_trajectories(轨)
		宿主._战斗动画层.set_popups(飘)
		if not UiTheme.无声模式() and not (轨.is_empty() and 飘.is_empty()):
			宿主._战斗动画层.开始淡出(0.7)
	宿主._写播报条(宿主._本拍摘要(新们), 宿主._本拍色(新们))

static func _加卡牌演出(宿主, e: Dictionary, 飘: Array, 脉冲卡们: Array) -> void:
	var 牌名 := str(e.get("牌名", ""))
	if 牌名.is_empty():
		牌名 = str(e.get("卡牌", ""))
	if 牌名.is_empty():
		牌名 = "这张牌"
	var 细 = 宿主._卡牌摘要尾(e)
	var 文 = "【%s】%s" % [牌名, 细] if not 细.is_empty() else "【%s】" % 牌名
	var 施卡 = 宿主._事件卡(e, false)
	if 施卡 != null:
		飘.append(宿主._卡上胶囊(施卡, 文, UiTheme.高亮, 1))
		脉冲卡们.append(施卡)
	var 目卡 = 宿主._事件卡(e, true)
	if 目卡 != null and 目卡 != 施卡:
		var 目方 := str(e.get("目标方", ""))
		var 名 = str((目卡 as UnitCard).数据.get("名", ""))
		if 名.is_empty():
			名 = "目标"
		飘.append(宿主._卡上胶囊(目卡, "→ 作用于【%s】" % 名,
			UiTheme.希望色 if 目方 == 宿主.我方 else UiTheme.负面, 2))
		脉冲卡们.append(目卡)

## 事件字典里这台单位对应的 `UnitCard`（`是目标` = 取 `目标方 / 目标位` 那一侧）。
static func _事件卡(宿主, e: Dictionary, 是目标: bool) -> UnitCard:
	if 是目标:
		var 方 := str(e.get("目标方", ""))
		var 位 := int(float(e.get("目标位", -1.0)))
		if not 方.is_empty() and 位 >= 0:
			return 宿主._卡(方, 位)
		return null
	var 施方 := str(e.get("单位方", e.get("方", "")))
	var 施位 := int(float(e.get("单位位", e.get("位", -1.0))))
	if not 施方.is_empty() and 施位 >= 0:
		return 宿主._卡(施方, 施位)
	var 键 := str(e.get("单位", ""))
	if not 键.is_empty():
		var 卡 = 宿主._阵型卡Of键(键)
		if 卡 != null:
			return 卡
	var 拥有 = 宿主._拥有者位()
	return 宿主._卡(宿主.我方, 拥有) if 拥有 >= 0 else null

## 直接钉在**某张卡**上的胶囊（`_胶囊()` 只能按 方 / 位 找卡，这里已经有卡了）。
static func _卡上胶囊(宿主, 卡: Variant, 文: String, 色: Color, 层: int) -> Dictionary:
	return {"文本": 文, "颜色": 色, "字号": 13, "卡": 卡, "上移": 22.0 * float(层), "alpha": 1.0,
		"类型": "胶囊"}

## 给这几张卡播一次脉冲高亮（去重；`_清全部卡片反馈()` 之后才调）。
static func _播脉冲(宿主, 卡们: Array) -> void:
	var 见 := {}
	for c in 卡们:
		if not (c is UnitCard) or not is_instance_valid(c):
			continue
		var id := (c as UnitCard).get_instance_id()
		if 见.has(id):
			continue
		见[id] = true
		(c as UnitCard).播放发牌脉冲()

static func _加攻击动画(宿主, e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 攻方 := str(e.get("单位方", ""))
	var 攻位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	var 伤害 := float(e.get("伤害", 0.0))
	var 命中 := bool(e.get("命中", true))
	var 暴击 := int(float(e.get("暴击", 0.0)))
	var 大招 = 宿主._是大招(e)
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
	轨.append(宿主._弹道(攻方, 攻位, 目方, 目位, 色, 类型, 宽, 虚))
	宿主._记反馈(反馈, 攻方, 攻位, "大招" if 大招 else "出手")
	var 段数 := int(float(e.get("段数", 1.0)))
	var 中段 := int(float(e.get("命中段数", 1.0)))
	var 文 := ""
	if not 命中:
		文 = "未命中"
	elif 段数 > 1:
		文 = "[%d/%d中] -%s" % [中段, 段数, 宿主._数字(伤害)]
	else:
		文 = "-%s" % 宿主._数字(伤害)
	if 暴击 > 0:
		文 = "【暴击】%s!" % 文
	飘.append(宿主._飘字(目方, 目位, 文, UiTheme.暴击色 if 暴击 > 0 else (UiTheme.未命中色 if not 命中 else UiTheme.负面),
		22 if 暴击 > 0 else (15 if not 命中 else 20), 0.0))
	宿主._记反馈(反馈, 目方, 目位, "受击")
	if bool(e.get("总攻", false)):
		飘.append(宿主._胶囊(目方, 目位, "〔总攻〕", UiTheme.高亮, 1))
	if float(e.get("特种破甲", 0.0)) > 0.0:
		飘.append(宿主._胶囊(目方, 目位, "〔破甲〕", UiTheme.难度色, 1))
	if bool(e.get("连斩追击", false)):
		飘.append(宿主._胶囊(攻方, 攻位, "〔连携追击〕", UiTheme.连携色, 1))
	if 伤害 > 0.0 and e.get("目标剩余HP") != null and float(e.get("目标剩余HP")) <= 0.0:
		飘.append(宿主._胶囊(目方, 目位, "【击破】", UiTheme.高亮, 2))
		宿主._记反馈(反馈, 目方, 目位, "击破")

static func _加镜甲动画(宿主, e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 守方 := str(e.get("单位方", ""))
	var 守位 := int(float(e.get("单位位", -1.0)))
	var 攻方 := str(e.get("目标方", ""))
	var 攻位 := int(float(e.get("目标位", -1.0)))
	轨.append(宿主._弹道(守方, 守位, 攻方, 攻位, UiTheme.暴击色, "镜甲", 4.0, false))
	var 伤害 := float(e.get("伤害", float(e.get("反弹", 0.0))))
	飘.append(宿主._飘字(攻方, 攻位, "-%s" % 宿主._数字(伤害), UiTheme.暴击色, 18, 0.0))
	飘.append(宿主._胶囊(攻方, 攻位, "〔镜甲〕", UiTheme.暴击色, 1))
	宿主._记反馈(反馈, 守方, 守位, "出手")
	宿主._记反馈(反馈, 攻方, 攻位, "受击")
	if e.get("目标剩余HP") != null and float(e.get("目标剩余HP")) <= 0.0:
		飘.append(宿主._胶囊(攻方, 攻位, "【击破】", UiTheme.高亮, 2))
		宿主._记反馈(反馈, 攻方, 攻位, "击破")

static func _加修理动画(宿主, e: Dictionary, 轨: Array, 飘: Array, 反馈: Dictionary) -> void:
	var 修方 := str(e.get("单位方", ""))
	var 修位 := int(float(e.get("单位位", -1.0)))
	var 目方 := str(e.get("目标方", ""))
	var 目位 := int(float(e.get("目标位", -1.0)))
	轨.append(宿主._弹道(修方, 修位, 目方, 目位, UiTheme.支援色, "修理", 2.5, false))
	var 回 := float(e.get("回复", 0.0))
	飘.append(宿主._飘字(目方, 目位, "+%s 耐久" % 宿主._数字(回), UiTheme.支援色, 18, 0.0))
	宿主._记反馈(反馈, 修方, 修位, "修理")
	宿主._记反馈(反馈, 目方, 目位, "治疗")

## 势力触发（SEED 觉醒 / TRANS-AM / 秘银连携 …）：在发起者卡上弹一枚胶囊标签。
static func _加势力胶囊(宿主, e: Dictionary, 飘: Array) -> void:
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
	飘.append(宿主._胶囊(方, 位, 标签, UiTheme.希望色, 1))

## 一条弹道（起点 / 终点都记**槽位**，卡片引用只给 `_draw()` 用）。
static func _弹道(宿主, 起方: String, 起位: int, 止方: String, 止位: int,
		色: Color, 类型: String, 宽: float, 虚: bool) -> Dictionary:
	return {
		"起点方": 起方, "起点位": 起位, "终点方": 止方, "终点位": 止位,
		"起点卡": 宿主._卡(起方, 起位), "终点卡": 宿主._卡(止方, 止位),
		"颜色": 色, "类型": 类型, "宽度": 宽, "虚线": 虚, "alpha": 1.0,
	}

## 一条头顶飘字（`上移` = 在卡片上方再叠几层，给多枚胶囊用）。
static func _飘字(宿主, 方: String, 位: int, 文: String, 色: Color, 字号: int, 上移: float) -> Dictionary:
	return {"文本": 文, "颜色": 色, "字号": 字号, "卡": 宿主._卡(方, 位), "上移": 上移, "alpha": 1.0, "类型": "飘字"}

## 一枚效果胶囊（〔被挡 -20〕/〔破甲〕/〔觉醒〕/〔连携追击〕/【击破】）。
static func _胶囊(宿主, 方: String, 位: int, 文: String, 色: Color, 层: int) -> Dictionary:
	return {"文本": 文, "颜色": 色, "字号": 13, "卡": 宿主._卡(方, 位), "上移": 22.0 * float(层), "alpha": 1.0,
		"类型": "胶囊"}

static func _记反馈(宿主, 表: Dictionary, 方: String, 位: int, kind: String) -> void:
	if 方.is_empty() or 位 < 0:
		return
	var k := "%s:%d" % [方, 位]
	var 旧 := str(表.get(k, ""))
	if 宿主._反馈优先级(kind) >= 宿主._反馈优先级(旧):
		表[k] = kind

static func _反馈优先级(宿主, kind: String) -> int:
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

static func _应用卡片反馈(宿主, 表: Dictionary) -> void:
	for k in 表.keys():
		var 段 := str(k).split(":")
		if 段.size() != 2:
			continue
		var 方 := str(段[0])
		var 卡 = 宿主._卡(方, int(str(段[1])))
		if 卡 != null:
			卡.set_combat_fx(str(表[k]), 1.0 if 方 == 宿主.我方 else -1.0)

static func _清全部卡片反馈(宿主) -> void:
	for c in 宿主._我方卡:
		if c is UnitCard:
			(c as UnitCard).clear_combat_fx()
			(c as UnitCard).清发牌脉冲()
	for c in 宿主._敌方卡:
		if c is UnitCard:
			(c as UnitCard).clear_combat_fx()
			(c as UnitCard).清发牌脉冲()
