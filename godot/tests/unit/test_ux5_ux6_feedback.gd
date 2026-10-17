## M4 试玩反馈二轮修复：UX-5（0.5 秒串行战斗 / 发牌动画队列）+ UX-6（删掉憋大招按钮与必经点文案）。
##
## 这一段守四件事（全部来自任务单 §2 验收门禁的第 ② / ③ 条）：
##   ① 战斗屏推进一回合（`BattleView._下一拍()`）之后，`_演出队列` 里**发牌帧（card_deal）**
##      与**攻击帧（attack）**是两条**独立**的帧，不是压在同一个字典里一起画；
##   ② 每步间隔配置 `BattleView.STEP_DURATION >= 0.45` 秒（规格是 0.5 秒 / 步）；
##   ③ 战斗屏与 `UnitCard` 不再渲染可见的「憋大招」按钮（大招状态仍然当文字展示）；
##   ④ 大地图屏 `MapView` 的顶栏 / 格子 / 悬停说明里不再出现 `[必]` 或 `必经点`，
##      而内核 `MapGenerator.must_pass()` **保留不动**（放守军时它还在用）。
##
## 纪律：固定种子、零 `randi` / `randf`；节点用完必 `remove_child` + `free`；
## 文案只用常规中文与 ASCII 标点。
extends RefCounted

const 种子 := 20261019

## 演出帧允许的类别（`BattleView.构建单拍演出帧()` 的契约）。
const 帧类别们 := ["card_deal", "attack", "heal", "tactic_card", "event"]

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	var 树根 := _根()
	t.ok(树根 != null, "拿得到 SceneTree 根节点（表现层要真的挂进树里）")
	if 树根 == null:
		return
	_步长配置(t)
	_拆帧_合成日志(t)
	_拆帧_真推一拍(t, 树根)
	_战斗屏没有憋大招(t, 树根)
	_机体卡没有憋大招(t)
	_大地图没有必经点(t, 树根)
	_源码红线(t)

# ==========================================================================================
# ② 每步间隔配置：0.5 秒 / 步（验收红线 >= 0.45）
# ==========================================================================================

func _步长配置(t) -> void:
	var 步长 := float(BattleView.STEP_DURATION)
	t.info("BattleView.STEP_DURATION = %.3f 秒" % 步长)
	t.ok(步长 >= 0.45, "★ UX-5 ②：BattleView.STEP_DURATION = %.3f 秒（>= 0.45，规格是 0.5 秒 / 步）" % 步长)
	t.ok(is_equal_approx(步长, 0.5) or (步长 > 0.45 and 步长 <= 0.6),
		"★ UX-5 ②：每步间隔落在 0.5 秒这一档（不是从前那种「一锅粥闪完」的 0.7 秒整回合）")
	# 前段（出手方前冲 + 指向光束）必须**短于**整步，否则「一步」会变成「一步 + 前段」。
	var 前段 := float(BattleView.出手前段秒)
	t.info("出手前段秒 = %.3f 秒" % 前段)
	t.ok(前段 > 0.0 and 前段 < 步长,
		"★ UX-5 ②：攻击帧的前段（出手方前冲 + 指向箭头光束）%.3f 秒 < 整步 %.3f 秒（受击段才吃得满 0.5 秒）" % [前段, 步长])

# ==========================================================================================
# ② 拆帧：同一拍里「发牌」与「攻击」必须是两条独立的帧
# ==========================================================================================

func _拆帧_合成日志(t) -> void:
	var v := BattleView.new()
	# 一条发牌 + 一条攻击 + 一条修理 + 一条纯调试噪音（`回合` 不许出帧）。
	var 条目们: Array = [
		{"类型": "回合", "回合": 1, "文本": "第 1 回合开始"},
		{"类型": "发牌", "回合": 1, "牌名": "测试牌甲", "来源文本": "来自：B1（前1）", "来源位": ["前1"]},
		{"类型": "攻击", "回合": 1, "单位方": "ally", "单位位": 0.0, "目标方": "enemy", "目标位": 0.0,
			"武器": "测试枪", "伤害": 12.0, "命中": true, "段数": 1.0, "命中段数": 1.0, "目标剩余HP": 88.0},
		{"类型": "修理", "回合": 1, "单位方": "ally", "单位位": 1.0, "目标方": "ally", "目标位": 0.0, "回复": 9.0},
	]
	var 帧们: Array = v.构建单拍演出帧(条目们)
	t.info("合成日志拆出 %d 帧：%s" % [帧们.size(), str(帧们.map(func(f): return str(f.get("类别", ""))))])
	t.ok(帧们.size() == 3, "★ UX-5 ②：`构建单拍演出帧()` 把 3 条真事件拆成 3 帧（纯调试噪音「回合」不出帧，实际 %d 帧）" % 帧们.size())
	var 类别们: Array = 帧们.map(func(f): return str(f.get("类别", "")))
	t.ok(类别们.has("card_deal") and 类别们.has("attack") and 类别们.has("heal"),
		"★ UX-5 ②：发牌 / 攻击 / 修理各自成帧（实际 %s）" % str(类别们))
	var 坏类别 := []
	for c in 类别们:
		if not 帧类别们.has(str(c)):
			坏类别.append(str(c))
	t.ok(坏类别.is_empty(), "★ UX-5 ②：每个帧的 `类别` 都落在 %s 里（越界：%s）" % [str(帧类别们), str(坏类别)])
	# 发牌帧：只讲发牌；攻击帧：只讲攻击 —— 两者绝不混在同一帧里。
	var 发牌帧: Dictionary = {}
	var 攻击帧: Dictionary = {}
	for f in 帧们:
		if f is Dictionary and str((f as Dictionary).get("类别", "")) == "card_deal" and 发牌帧.is_empty():
			发牌帧 = f
		if f is Dictionary and str((f as Dictionary).get("类别", "")) == "attack" and 攻击帧.is_empty():
			攻击帧 = f
	var 发牌文 := str(发牌帧.get("横幅", ""))
	var 攻击文 := str(攻击帧.get("横幅", ""))
	t.info("发牌帧横幅：%s" % 发牌文)
	t.info("攻击帧横幅：%s" % 攻击文)
	t.ok(发牌文.contains("〔发牌〕") and 发牌文.contains("获得战术牌")
		and not 发牌文.contains("使用【"),
		"★ UX-5 ②：发牌帧的横幅只有发牌那一句（`〔发牌〕来自【机体名】 -> 获得战术牌【牌名】`），没有混进攻击文案")
	t.ok(攻击文.contains("测试枪") and 攻击文.contains("造成") and 攻击文.contains("伤害")
		and not 攻击文.contains("〔发牌〕"),
		"★ UX-5 ②：攻击帧的横幅只有出手那一句（`【出手方】使用【武器名】 -> 【受击方】 · 造成 XXX 伤害`），没有混进发牌文案")
	t.ok(int(发牌帧.get("手牌索引", -2)) == -1,
		"★ UX-5 ②：手上没有这张牌的实例时，发牌帧的手牌索引是 −1（表现层不瞎指一张牌）")
	v.free()

# ==========================================================================================
# ② 真推一拍：`_下一拍()` 之后 `_演出队列` 里同时有发牌帧与攻击帧
# ==========================================================================================

func _拆帧_真推一拍(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_ux5_queue.json"   # 只用内存态，全程不存档
	t.ok(s.start_quick_battle(种子), "开一场快速战斗（种子 %d）：手牌 %d 张 / 候补 %d 张"
		% [种子, s.hand_count(), s.reserve_preview().size()])
	if s.battle_ctx.is_empty():
		t.ok(false, "battle_ctx 是空的 → 段「真推一拍」跑不了")
		return
	var v := BattleView.new()
	树根.add_child(v)
	v.setup(s)
	v.refresh()
	t.ok(v.演出帧数() == 0, "★ UX-5：刚开战还没推进回合 → `_演出队列` 是空的（%d 帧）" % v.演出帧数())
	# 先打一张牌：手牌空出一格，下一回合开始内核才会「候补补位」发一张牌
	# （不打牌时手牌本来就是满的，那一回合根本不会发牌 —— 那样验不到发牌帧）。
	var 能打 := s.playable_hand_ids()
	var 打了 := ""
	if not 能打.is_empty():
		打了 = str(能打[0])
		t.ok(bool(s.play_tactical_card(打了).get("成功", false)),
			"先打一张手牌【%s】，给下一回的发牌腾出空位" % 打了)
	else:
		t.info("这一拍没有能打的手牌（发牌帧走「手牌差集补帧」那条路）")
	v.refresh()
	# ---- 真推一拍 ----
	var 前回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	var 前日志数 := s.battle_log_entries(0).size()
	v._下一拍()
	var 后回合 := int(float(s.battle_ctx.get("turn", 1.0)))
	var 帧们: Array = v._演出队列
	var 全部日志 := s.battle_log_entries(0)
	var 新增: Array = []
	if 前日志数 < 全部日志.size():
		新增 = 全部日志.slice(前日志数, 全部日志.size())
	t.info("第 %d 回合 → 第 %d 回合，本回演出队列 %d 帧：%s"
		% [前回合, 后回合, 帧们.size(), str(帧们.map(func(f): return str(f.get("类别", ""))))])
	t.ok(后回合 > 前回合, "★ UX-5 ②：`_下一拍()` 真的推进了一回合（第 %d → 第 %d 回合）" % [前回合, 后回合])
	t.ok(帧们.size() >= 2, "★ UX-5 ②：这一回拆出 %d 帧（不是把十几条事件压成 1 帧一次画完）" % 帧们.size())
	var 发牌帧们 := []
	var 攻击帧们 := []
	var 坏帧 := []
	for i in 帧们.size():
		var f: Variant = 帧们[i]
		if not (f is Dictionary):
			坏帧.append("不是字典")
			continue
		var 类 := str((f as Dictionary).get("类别", ""))
		if not 帧类别们.has(类):
			坏帧.append(类)
		if 类 == "card_deal":
			发牌帧们.append(f)
		elif 类 == "attack":
			攻击帧们.append(f)
	t.ok(坏帧.is_empty(), "★ UX-5 ②：每一帧都是带合法 `类别` 的字典（越界：%s）" % str(坏帧))
	t.ok(not 发牌帧们.is_empty(),
		"★ UX-5 ②：本回有 **%d 个独立的发牌帧**（`card_deal`）—— 发牌是单拆出来的一步" % 发牌帧们.size())
	t.ok(not 攻击帧们.is_empty(),
		"★ UX-5 ②：本回有 **%d 个独立的攻击帧**（`attack`）—— 每次出手各占一步" % 攻击帧们.size())
	# ---- 拆帧对账：帧数 == 本拍新增日志里那一类事件的条数（不多画、不并画）----
	var 日志攻击 := []
	var 日志发牌 := 0
	for e in 新增:
		if not (e is Dictionary):
			continue
		var 类 := str((e as Dictionary).get("类型", ""))
		if 类 == "攻击" or 类 == "镜甲":
			日志攻击.append(e)
		elif 类 == "发牌":
			日志发牌 += 1
	t.info("本拍新增日志：攻击 %d 条 / 发牌 %d 条（队列里 %d 个攻击帧 / %d 个发牌帧）"
		% [日志攻击.size(), 日志发牌, 攻击帧们.size(), 发牌帧们.size()])
	t.ok(攻击帧们.size() == 日志攻击.size(),
		"★ UX-5 ②：**每次出手各占一帧** —— 攻击帧数 %d == 本拍「攻击 / 镜甲」日志 %d 条"
		% [攻击帧们.size(), 日志攻击.size()])
	t.ok(发牌帧们.size() >= 日志发牌 and 发牌帧们.size() >= 1,
		"★ UX-5 ②：**发牌单独成帧** —— 发牌帧 %d 个 >= 本拍「发牌」日志 %d 条（内核没给逐张时按手牌差集补）"
		% [发牌帧们.size(), 日志发牌])
	# 攻击帧的出手顺序必须与日志时间顺序逐条对上（发牌帧插在中间也不许打乱出手先后）。
	var 帧序 := []
	for f in 攻击帧们:
		帧序.append("%d>%d" % [int((f as Dictionary).get("出手位", -1)), int((f as Dictionary).get("目标位", -1))])
	var 日志序 := []
	for e in 日志攻击:
		日志序.append("%d>%d" % [int(float((e as Dictionary).get("单位位", -1.0))), int(float((e as Dictionary).get("目标位", -1.0)))])
	t.ok(帧序 == 日志序,
		"★ UX-5 ②：攻击帧的出手顺序与战斗日志逐条对上（帧 %s / 日志 %s）" % [str(帧序), str(日志序)])
	if not 发牌帧们.is_empty() and not 攻击帧们.is_empty():
		t.ok(str((发牌帧们[0] as Dictionary).get("横幅", "")).contains("〔发牌〕"),
			"★ UX-5 ②：队列里的发牌帧横幅写着「〔发牌〕…获得战术牌…」：%s"
			% str((发牌帧们[0] as Dictionary).get("横幅", "")).substr(0, 60))
		t.ok(str((攻击帧们[0] as Dictionary).get("横幅", "")).contains("使用【"),
			"★ UX-5 ②：队列里的攻击帧横幅写着「…使用【武器】-> …」：%s"
			% str((攻击帧们[0] as Dictionary).get("横幅", "")).substr(0, 60))
	# ---- headless 零回归：队列同步播完（不建定时器），帧数记满 ----
	t.ok(v.已播帧数() >= 帧们.size(),
		"★ UX-5：headless 下 `_消费演出队列()` 同步播完不阻塞（已播 %d / 总 %d 帧）" % [v.已播帧数(), 帧们.size()])
	树根.remove_child(v)
	v.free()

# ==========================================================================================
# ③ 战斗屏：不再渲染可见的「憋大招」按钮
# ==========================================================================================

func _战斗屏没有憋大招(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_ux6_battle.json"
	t.ok(s.start_quick_battle(种子 + 1), "再开一场快速战斗（种子 %d）给战斗屏用" % (种子 + 1))
	if s.battle_ctx.is_empty():
		t.ok(false, "battle_ctx 是空的 → 段「战斗屏没有憋大招」跑不了")
		return
	var v := BattleView.new()
	树根.add_child(v)
	v.setup(s)
	v.refresh()
	var 按钮们: Array = _按钮文本们(v)
	var 憋 := 按钮们.filter(func(x): return str(x).contains("憋大招") or str(x).contains("放大招"))
	t.info("战斗屏按钮 %d 个：%s" % [按钮们.size(), str(按钮们)])
	t.ok(not 按钮们.is_empty(), "战斗屏里真的画出了可点的按钮（%d 个，不是一棵空树）" % 按钮们.size())
	t.ok(憋.is_empty(), "★ UX-6 ③：战斗屏里没有任何一个「憋大招 / 放大招」按钮（命中：%s）" % str(憋))
	var 保留 := 按钮们.filter(func(x): return str(x).contains("保留大招"))
	t.ok(保留.is_empty(), "★ UX-6 ③：也没有把「保留大招」做成按钮（命中：%s）" % str(保留))
	# 控制栏：旧「自动打完」那颗字面按钮已经拆成「自动播放 / 暂停连播」+「结束并结算」。
	var 全部文字 := " | ".join(按钮们.map(func(x): return str(x)))
	t.ok(全部文字.contains("推进下一回合") and 全部文字.contains("结束并结算"),
		"★ UX-6 ③：控制栏还是那套「推进下一回合 / 结束并结算」（实际：%s）" % 全部文字)
	t.ok(not 全部文字.contains("自动打完"),
		"★ UX-6 ③：控制栏上不再有「自动打完」那颗一键跳过战斗画面的按钮")
	var 全文本 := " | ".join(_文本们(v))
	t.ok(not 全文本.contains("憋大招"),
		"★ UX-6 ③：战斗屏整棵树（标签 / 按钮 / 悬停说明）里一个「憋大招」字都没有")
	# ---- 只下线 UI，内核那条路照旧能用（防「删按钮顺手把后端也删了」）----
	var 友军们: Array = s.battle_ctx.get("allies") if s.battle_ctx.get("allies") is Array else []
	if not 友军们.is_empty():
		var 第一台: Dictionary = 友军们[0]
		var 键 := str(第一台.get("key", ""))
		var 前 := bool(第一台.get("holdUlt", false))
		var 切了 := s.toggle_unit_switch(键, "保留大招")
		var 后 := false
		for u in (s.battle_ctx.get("allies") as Array):
			if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
				后 = bool((u as Dictionary).get("holdUlt", false))
		t.ok(切了 and 后 != 前,
			"★ UX-6 ③：UI 下线之后 `toggle_unit_switch(键, \"保留大招\")` 照旧生效（%s：%s → %s）" % [键, str(前), str(后)])
		t.ok(bool(s.toggle_unit_switch(键, "保留大招")),
			"★ UX-6 ③：再切一次也能切回来（底层口子两个方向都通）")
	树根.remove_child(v)
	v.free()

# ==========================================================================================
# ③ 机体卡：我方单位卡上不再有「憋大招 / 放大招」切换按钮，但大招状态仍当文字展示
# ==========================================================================================

func _机体卡没有憋大招(t) -> void:
	var 数据 := {
		"ok": true, "名": "测试机体", "键": "B1", "模板": "B1", "势力": "天人",
		"位名": "前1", "等级": 10, "职业": "突击", "活着": true,
		"HP": 100.0, "最大HP": 100.0, "血比": 1.0, "气势": 3.0, "护盾": 0.0,
		"状态": ["正常"], "开关": ["保留大招：关", "TRANS-AM：自动"],
	}
	var 卡 := UnitCard.new()
	卡.setup(数据)
	var 按钮们: Array = _按钮文本们(卡)
	t.info("机体卡按钮 %d 个：%s" % [按钮们.size(), str(按钮们)])
	t.ok(not 按钮们.is_empty(), "这台天人的机体卡上还有 TRANS-AM 两个按钮（%d 个）" % 按钮们.size())
	var 憋 := 按钮们.filter(_是憋大招按钮)
	t.ok(憋.is_empty(), "★ UX-6 ③：机体卡上没有「憋大招 / 放大招 / 保留大招」按钮（命中：%s）" % str(憋))
	var 开关行 := 卡.find_child("开关行", true, false)
	var 开关文 := str((开关行 as Label).text) if 开关行 != null else ""
	t.ok(开关行 != null and 开关文.contains("保留大招"),
		"★ UX-6 ③：大招状态仍然当**文字**展示（开关行：%s）—— 只下线按钮，不下线信息" % 开关文)
	卡.free()

# ==========================================================================================
# ③ 大地图：顶栏 / 格子 / 悬停说明里不再有 `[必]` 或 `必经点`
# ==========================================================================================

func _大地图没有必经点(t, 树根: Node) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_ux6_map.json"
	t.ok(s.start_new_run(种子 + 2, "混编"), "开一局肉鸽（种子 %d）给大地图屏用" % (种子 + 2))
	if s.run_state == null:
		t.ok(false, "没有 run_state → 段「大地图没有必经点」跑不了")
		return
	var mv := MapView.new()
	树根.add_child(mv)
	mv.setup(s)
	mv.refresh()
	var 格按钮们 := mv.find_children("格*", "", true, false)
	t.info("大地图第 %d 层画了 %d 个格子按钮" % [s.run_state.floor_num, 格按钮们.size()])
	t.ok(not 格按钮们.is_empty(), "大地图真的画出了格子（%d 个）" % 格按钮们.size())
	var 坏格 := []
	for b in 格按钮们:
		if not (b is Button):
			continue
		var 字 := str((b as Button).text)
		var 提 := str((b as Button).tooltip_text)
		if 字.contains("[必]") or 字.contains("必经") or 提.contains("[必]") or 提.contains("必经"):
			坏格.append("%s → %s | %s" % [str((b as Button).name), 字.replace("\n", " "), 提])
	t.ok(坏格.is_empty(), "★ UX-6 ③：格子文字 / 悬停说明里没有 `[必]` 或 `必经点`（命中：%s）" % str(坏格))
	# 逐个选中每一格，把「预告面板」（= 玩家看到的悬停说明那一块）也逐格摊开查一遍。
	var 坏预告 := []
	var 查了 := 0
	for k in s.run_state.map_data.get("格", {}).keys():
		mv.选中预告(int(k))
		查了 += 1
		var 文 := " | ".join(_文本们(mv.find_child("预告面板内容", true, false)))
		if 文.contains("[必]") or 文.contains("必经"):
			坏预告.append("%d → %s" % [int(k), 文])
	t.info("把 %d 格的悬停预告都摊开查过" % 查了)
	t.ok(坏预告.is_empty(), "★ UX-6 ③：每一格的悬停预告里都没有 `[必]` / `必经点`（命中：%s）" % str(坏预告))
	# 顶栏摘要 + 图例 + 节点说明：整棵树扫一遍。
	var 全文本 := " | ".join(_文本们(mv))
	t.ok(not 全文本.contains("必经"), "★ UX-6 ③：大地图整棵树（顶栏摘要 / 图例 / 节点说明 / 悬停）里没有「必经」两个字")
	t.ok(not 全文本.contains("[必]"), "★ UX-6 ③：也没有 `[必]` 旗标")
	var 层信息 := mv.find_child("层信息", true, false)
	t.ok(层信息 != null and str((层信息 as Label).text).contains("第"),
		"★ UX-6 ③：顶栏摘要还在（只是不再写「· 必经点 N 个」）：%s"
		% (str((层信息 as Label).text) if 层信息 != null else ""))
	# 内核那一条**不许**跟着删：放守军的内核逻辑还在调它。
	t.ok(MapGenerator.new().has_method("must_pass"),
		"★ UX-6 ③：内核 `MapGenerator.must_pass()` 保留不动（只是大地图屏不再显示它）")
	树根.remove_child(mv)
	mv.free()

# ==========================================================================================
# ③ 源码红线：表现层源码里不再出现那两句文案（防有人「顺手加回来」）
# ==========================================================================================

func _源码红线(t) -> void:
	var 战斗屏源码 := FileAccess.get_file_as_string("res://presentation/battle/battle_view.gd")
	var 机体卡源码 := FileAccess.get_file_as_string("res://presentation/widgets/unit_card.gd")
	var 大地图源码 := FileAccess.get_file_as_string("res://presentation/run_map/map_view.gd")
	t.ok(not 战斗屏源码.is_empty() and not 机体卡源码.is_empty() and not 大地图源码.is_empty(),
		"三份表现层源码都读得到（%d / %d / %d 字符）" % [战斗屏源码.length(), 机体卡源码.length(), 大地图源码.length()])
	# 只查「会不会上屏的字面量」：`憋大招` / `放大招` / `[必]` / `必经点` 三处都不许再当字符串出现。
	for 对 in [["battle_view.gd", 战斗屏源码], ["unit_card.gd", 机体卡源码], ["map_view.gd", 大地图源码]]:
		var 名 := str(对[0])
		var 源 := str(对[1])
		t.ok(not 源.contains("\"憋大招") and not 源.contains("憋大招\""),
			"★ UX-6 ③：%s 里没有「憋大招」的界面字面量" % 名)
		t.ok(not 源.contains("\"[必]\""), "★ UX-6 ③：%s 里没有 `[必]` 字面量" % 名)
		t.ok(not 源.contains("\"必经"), "★ UX-6 ③：%s 里没有「必经…」的界面字面量" % 名)
	# 门面那条底层口子保留（防旧内核测试 / 旧录像调用报错）：真正的入口是
	# `toggle_unit_switch(单位键, "保留大招")`，UI 下线但内核这条路还在。
	var 门面 := GameSession.new()
	t.ok(门面.has_method("toggle_unit_switch"),
		"★ UX-6 ③：门面 `toggle_unit_switch()` 保留不动（只下线 UI）")

# ==========================================================================================
# 工具
# ==========================================================================================

## 这个按钮文字是不是「憋大招 / 放大招 / 保留大招」那一路（UX-6 要下线的那颗按钮）。
func _是憋大招按钮(文字: Variant) -> bool:
	var 文 := str(文字)
	return 文.contains("憋大招") or 文.contains("放大招") or 文.contains("保留大招")

## 一棵树里所有按钮的文字（递归）。
func _按钮文本们(根: Node) -> Array:
	var out: Array = []
	if 根 == null:
		return out
	if 根 is Button:
		out.append(str((根 as Button).text))
	for c in 根.find_children("*", "", true, false):
		if c is Button:
			out.append(str((c as Button).text))
	return out

## 一棵树里所有「会显示出来的文字」：标签 + 按钮 + 悬停说明 + 富文本。
func _文本们(根: Node) -> Array:
	var out: Array = []
	if 根 == null:
		return out
	var 们: Array = [根]
	们.append_array(根.find_children("*", "", true, false))
	for n in 们:
		if n is Label:
			out.append(str((n as Label).text))
		elif n is Button:
			out.append(str((n as Button).text))
		elif n is RichTextLabel:
			out.append(str((n as RichTextLabel).text))
		if n is Control:
			var 提 := str((n as Control).tooltip_text)
			if not 提.is_empty():
				out.append(提)
	return out

func _根() -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root if 树 != null else null
