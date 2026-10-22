## 职责：右栏战报、推进 / 自动 / 倍速 / 跳过 / 结算按钮、牌库点打与顶部状态叠层。
extends RefCounted

static func _建战报栏(宿主, 父: Node) -> void:
	宿主._战报栏 = UiTheme.建面板(父, "战报栏", UiTheme.面板底, UiTheme.边框)
	宿主._战报栏.custom_minimum_size = Vector2(宿主.右栏宽, 0)
	宿主._战报栏.size_flags_horizontal = Control.SIZE_FILL
	宿主._战报栏.size_flags_vertical = Control.SIZE_EXPAND_FILL
	宿主._战报栏.clip_contents = true
	var 列 = UiTheme.建盒(宿主._战报栏, "战报栏上下列", true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var 按钮行 := GridContainer.new()
	按钮行.name = "战斗按钮组"
	按钮行.columns = 2
	按钮行.add_theme_constant_override("h_separation", UiTheme.间距)
	按钮行.add_theme_constant_override("v_separation", 2)
	列.add_child(按钮行)
	宿主._推进按钮 = UiTheme.建按钮(按钮行, "推进下一回合", 宿主._下一拍)
	宿主._推进按钮.name = "推进按钮"
	宿主._推进按钮.tooltip_text = "让内核真的打一个完整回合（门面 step_battle_turn()），再按 0.5 秒一步把这一回演出来"
	宿主._自动按钮 = UiTheme.建按钮(按钮行, "自动播放", 宿主._点自动)
	宿主._自动按钮.name = "自动按钮"
	宿主._自动按钮.tooltip_text = "自动连播：每一回 0.5×N 秒演完 → 停 0.3 秒 → 自动推进下一回合（再点一次 = 暂停连播）"
	宿主._倍速按钮 = UiTheme.建按钮(按钮行, "2x 加速", 宿主._点倍速)
	宿主._倍速按钮.name = "倍速按钮"
	宿主._倍速按钮.tooltip_text = "切换演出倍速：1x 正常 <-> 2x 加速（每步 0.5 秒 → 0.25 秒）"
	宿主._跳过演出按钮 = UiTheme.建按钮(按钮行, "跳过本回演出", 宿主._点跳过本回演出)
	宿主._跳过演出按钮.name = "跳过演出按钮"
	宿主._跳过演出按钮.tooltip_text = "本回正在演：点它立刻跳到这一回的终态（不必等 0.5×N 秒）"
	宿主._跳过演出按钮.visible = false
	宿主._结算按钮 = UiTheme.建按钮(按钮行, "结束并结算", 宿主._点结算)
	宿主._结算按钮.name = "结算按钮"
	宿主._结算按钮.tooltip_text = "跳过直达结算：没打完就先 auto_finish_battle() 算完，再 finish_battle_and_settle() 进结算屏"
	宿主._战报提示 = 宿主._建单行标签(列, "战报提示", "战报栏", UiTheme.字号_小, UiTheme.次要文字)
	宿主._战报滚 = UiTheme.建滚动(列, "战报滚动", 宿主.战报滚动高)

static func _画战报(宿主, 在战斗: bool) -> void:
	宿主._清空(宿主._战报滚)
	if not 在战斗:
		宿主._战报提示.text = "战报栏：现在不在战斗里。"
		宿主._推进按钮.disabled = true
		宿主._自动按钮.disabled = true
		宿主._结算按钮.disabled = true
		if 宿主._倍速按钮 != null:
			宿主._倍速按钮.disabled = true
		if 宿主._跳过演出按钮 != null:
			宿主._跳过演出按钮.disabled = true
		return
	var 打完 = 宿主.session.battle_ctx.get("result") != null
	var 单结 = 宿主.session.deck_turn_summary()
	宿主._战报提示.text = "第 %d 回合 · %s · 选中 %s（战意 %d / %d）· 上排 %d 张（能打 %d）· 下排 %d 张（能打 %d）%s" % [
		int(单结.get("回合", 0)), 宿主._阶段中文(str(单结.get("阶段", ""))), str(单结.get("选中名", "")),
		int(JsCompat.js_round(float(单结.get("战意", 0.0)))), int(JsCompat.js_round(float(单结.get("战意上限", 100.0)))),
		int(单结.get("上排", 0)), int(单结.get("上排能打", 0)), int(单结.get("下排", 0)), int(单结.get("下排能打", 0)),
		"  · 这一场已经打完了，点「结束并结算」" if 打完 else ""]
	宿主._推进按钮.disabled = 打完
	宿主._自动按钮.disabled = 打完
	if 宿主._倍速按钮 != null:
		宿主._倍速按钮.disabled = false
	if 宿主._跳过演出按钮 != null:
		宿主._跳过演出按钮.disabled = not 宿主._演出进行中
	宿主._结算按钮.disabled = not (宿主.session != null and 宿主.session.in_battle())
	var 条们 = 宿主.session.battle_log_entries(150)
	var 行们 = 宿主.session.battle_log_lines(150)
	if 条们.is_empty():
		UiTheme.建标签(宿主._战报滚, "还没有战报 —— 点「推进下一回合」开打。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in 条们.size():
		var e: Dictionary = 条们[i] if 条们[i] is Dictionary else {}
		var 文 = str(行们[i]) if i < 行们.size() else str(e.get("文本", ""))
		var 色 = 宿主._日志色(e)
		var l = UiTheme.建说明(宿主._战报滚, 文, UiTheme.字号_正文 if 宿主._是高亮(e) else UiTheme.字号_小, 色)
		l.name = "战报行%d" % (i + 1)

## 高亮判据全部来自日志条目自己的字段（只读字段，不编）：
static func _日志色(宿主, e: Dictionary) -> Color:
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

static func _是高亮(宿主, e: Dictionary) -> bool:
	var 类 := str(e.get("类型", ""))
	return 类 == "战术牌" or 类 == "势力" or 类 == "Boss" or 类 == "回合"

## ★ UX-5 控制栏：按钮文字 / 可见性跟着「自动连播 / 倍速 / 正在演」走（纯表现，不调门面）。
static func _刷新控制按钮(宿主) -> void:
	var 单机 = 宿主._单机牌组()
	if 宿主._推进按钮 != null:
		宿主._推进按钮.text = "结束我方回合" if 单机 else "推进下一回合"
		宿主._推进按钮.tooltip_text = ("结束我方回合：没打过主武器的机体由 AI 补打 1 张 → 敌方按格位 0..7 依次行动 → 进入下一回合"
			if 单机 else "让内核真的打一个完整回合（门面 step_battle_turn()），再按 0.5 秒一步把这一回演出来")
	if 宿主._自动按钮 != null:
		var 关名 = "全员自动回合" if 单机 else "自动播放"
		宿主._自动按钮.text = "暂停连播" if 宿主._自动连播开启 else 关名
	if 宿主._倍速按钮 != null:
		宿主._倍速按钮.text = "1x 正常" if 宿主._演出倍速 > 1.5 else "2x 加速"
	if 宿主._跳过演出按钮 != null:
		宿主._跳过演出按钮.visible = 宿主._演出进行中
		宿主._跳过演出按钮.disabled = not 宿主._演出进行中

## 兼容旧名字（既有调用点 / 测试仍可以叫 `_点推进()`）。
static func _点推进(宿主) -> void:
	宿主._下一拍()

## 「自动播放 / 暂停连播」（★ UX-5 第 4 项）：原来的「自动打完」拆出来的那一半。
static func _点自动(宿主) -> void:
	if 宿主.session == null:
		return
	if 宿主.session.battle_ctx.get("result") != null:
		宿主._点结算()
		return
	宿主._自动连播开启 = not 宿主._自动连播开启
	宿主._刷新控制按钮()
	var 推进名 = "结束我方回合" if 宿主._单机牌组() else "推进下一回合"
	if not 宿主._自动连播开启:
		宿主._回话("已暂停连播：想继续就点「%s」或再开「自动播放」" % 推进名, true)
		宿主.refresh()
		return
	if UiTheme.无声模式():
		宿主._回话("自动播放已开（headless：这一拍立即同步播完，不做定时连锁）", true)
		宿主._下一拍()
		return
	if 宿主._演出进行中:
		宿主._回话("自动播放已开：这一回演完就接下一回合", true)
	else:
		宿主._回话("自动播放已开：每一拍按 0.5 秒一步顺着演；再点一次 = 暂停连播", true)
		宿主._下一拍()

## 「2x 加速 / 1x 正常」（★ UX-5 第 4 项）：切 `_演出倍速`（1.0 <-> 2.0）。
static func _点倍速(宿主) -> void:
	宿主._演出倍速 = 1.0 if 宿主._演出倍速 > 1.5 else 2.0
	宿主._刷新控制按钮()
	宿主._回话("演出倍速：%s（每步 %.2f 秒）" % ["2x 加速" if 宿主._演出倍速 > 1.5 else "1x 正常",
		宿主.STEP_DURATION / 宿主._演出倍速], true)
	宿主.refresh()

## 「跳过本回演出」：不等剩下的帧，直接跳到这一回的终态（不改战斗结果）。
static func _点跳过本回演出(宿主) -> void:
	if not 宿主._演出进行中:
		宿主._回话("现在没有正在演的回合 —— 点「%s」才会开始演" % ("结束我方回合" if 宿主._单机牌组() else "推进下一回合"), false)
		宿主.refresh()
		return
	宿主._演出跳过请求 = true
	宿主._回话("已请求跳过这一回剩下的帧（直接到终态）", true)
	宿主.refresh()

## ★ UX-5 第 4 项：「跳过直达结算」—— 不想看动画时一键算完进结算。
static func _跳过直达结算(宿主) -> void:
	if 宿主.session == null:
		return
	宿主._表演中止()
	宿主._自动连播开启 = false
	if 宿主.session.battle_ctx is Dictionary and 宿主.session.battle_ctx.get("result") == null:
		宿主.session.auto_finish_battle()
	宿主._回话("跳过演出、直接结算：%s · 一共打了 %s 个回合" % [宿主.session.战果文字(),
		UiTheme.文本(宿主.session.last.get("回合数", 0))], true)
	宿主._点结算()

## 「自动打完」的旧名字（保留兼容）：headless / 旧调用点仍然可以叫它 = 跳过直达结算。
static func _点自动打完(宿主) -> void:
	宿主._跳过直达结算()

## 同上（规格里点名的那个旧名字）。
static func _自动打完(宿主) -> void:
	宿主._跳过直达结算()

static func _点结算(宿主) -> void:
	if 宿主.session == null:
		return
	宿主._表演中止(false)
	宿主._自动连播开启 = false
	宿主._刷新控制按钮()
	宿主._演出预热 = true
	if 宿主.session.battle_ctx is Dictionary and 宿主.session.battle_ctx.get("result") == null:
		宿主.session.auto_finish_battle()
	宿主._演出预热 = false
	if 宿主._已结算:
		宿主.refresh()
		return
	var r = 宿主.session.finish_battle_and_settle()
	if not bool(r.get("ok", true)):
		宿主._回话("结算没做成：%s" % 宿主._为什么(r), false)
		宿主.refresh()
		return
	宿主._已结算 = true
	宿主._回话("战后已结算：%s（屏幕已经切到结算屏）" % str(宿主.session.result_summary().get("结果", "")), true)
	宿主.refresh()

## 中止正在演的这一回：`_演出序号 + 1` → 旧协程看到序号变了就自己退出（不留野协程）。
static func _表演中止(宿主, 清队列: bool = true) -> void:
	宿主._演出序号 += 1
	宿主._演出进行中 = false
	宿主._演出跳过请求 = false
	宿主._帧已耗时 = 0.0
	if 清队列:
		宿主._演出队列 = []
		宿主._当前演出总帧数 = 0
		宿主._已播帧数 = 0
	宿主._刷新控制按钮()

## 点「推进下一回合（下一拍）」：真的推一回合，然后把**本拍新增日志**拆成串行演出帧播出去。
static func _下一拍(宿主) -> void:
	if 宿主.session == null:
		return
	if 宿主._演出进行中:
		宿主._回话("这一回还在演（%d/%d 帧）—— 想直接看终态就点「跳过本回演出」" % [宿主._已播帧数, 宿主._当前演出总帧数], false)
		宿主.refresh()
		return
	if 宿主.session.battle_ctx.get("result") != null:
		宿主._点结算()
		return
	宿主._表演中止(false)
	var 前手 = 宿主._手牌快照()
	var 前日志 = 宿主.session.battle_log_entries(0).size()
	宿主._演出预热 = true
	var 单机 = 宿主._单机牌组()
	var r = 宿主.session.end_player_turn() if 单机 else 宿主.session.step_battle_turn()
	宿主._演出预热 = false
	if not bool(r.get("ok", true)):
		宿主._回话("推不动：%s" % 宿主._为什么(r), false)
		宿主.refresh()
		return
	var 后 = int(float(宿主.session.battle_ctx.get("turn", 1.0)))
	var 全部 = 宿主.session.battle_log_entries(0)
	var 新增: Array = 全部.slice(前日志, 全部.size()) if 前日志 < 全部.size() else []
	var 后手 = 宿主._手牌快照()
	宿主._标记日志已播到末尾()
	宿主._构建演出队列(新增, 前手, 后手)
	宿主._演出跳过请求 = false
	if 单机:
		宿主._回话("结束我方回合（现在第 %d 回合）· 上排 %d 张 / 下排 %d 张 · 这一回要演 %d 步" % [
			后, 宿主.session.upper_hand_cards().size(), 宿主.session.lower_hand_cards().size(), 宿主._演出队列.size()], true)
	宿主.refresh()
	宿主._消费演出队列()

static func _点开关(宿主, 单位键: String, 开关键: String) -> void:
	if 宿主.session == null:
		return
	if 宿主.session.toggle_unit_switch(单位键, 开关键):
		宿主._回话("已切【%s】的「%s」→ %s" % [单位键, 开关键, str(宿主.session.last.get("值", ""))], true)
	else:
		宿主._回话("开关点不动：%s" % 宿主._为什么(宿主.session.last), false)
	宿主.refresh()

## 把「已经播到第几条日志」推到当前末尾 —— 这样 `refresh()` 里的 `_画战斗动画()` 不会…
static func _标记日志已播到末尾(宿主) -> void:
	if 宿主.session == null or 宿主.session.battle_ctx.is_empty():
		return
	宿主._已播日志引用 = 宿主.session.battle_ctx.get("log")
	宿主._已播日志数 = 宿主.session.battle_log_entries(0).size()
