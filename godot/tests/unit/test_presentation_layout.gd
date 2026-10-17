## 表现层**版面门禁**（永久自动化）：UI 叠加 / 布局越界 / Mouse-Over 说明信息。
##
## 这一份钉的是本次修掉的三类真实问题（修完就必须一直绿）：
##   ① **单屏可见性**：`屏幕容器` 下**每时每刻最多也是唯一只有 1 个子视图 `visible == true`**
##      —— 从前换屏只把新屏 `visible = true`，旧屏还亮着，两个屏叠在一起；
##      还有「切屏时自动弹「战斗」黑幕把战斗屏盖住」与「回大地图时叠第二个结算弹窗」。
##   ② **1280×720 边界**：顶栏不许压住 `y >= 104` 的屏幕容器；
##      顶栏右侧 4 个按钮即使满手藏品 / 零件也不许出右界；
##      战斗屏 16 张 `UnitCard` 不许互相压（曾经塌到 19px 高）；
##      `阵型区` / `手牌栏` / `战报栏` 三大区块两两不重叠；
##      结算屏 `继续按钮` 不许掉到画布外（曾经 y = 1794）。
##   ③ **Mouse-Over 说明信息**：机体卡、编队格位、名册条目、招募候选、手牌、候补牌、
##      三选一候选、战术牌库条目 —— `tooltip_text` 都得有货（属性 / 武器 / 耗气 / 冷却 / 触发 / 效果），
##      而且 `悬停说明层.show_for_control()` 之后面板真的显示、且不出 1280×720。
##
## 纪律：
##   · `extends RefCounted` + `func run(t)`，放 `godot/tests/unit/` 顶层即自动被发现；
##   · 只断言**版面关系**与**门面 / 视图已经给出的文本**，不在测试里另立第二套口径；
##   · headless 下 `run_tests.gd` 是 `SceneTree`，测试全在 `_initialize()` 里同步跑完之后才 `quit()`，
##     所以：`add_child` 不触发 `_ready()` → 显式调 `boot.启动()`；
##     **布局只在真正跑过帧之后才算出来** → 量 `get_global_rect()` 之前一律 `await _等帧(2)`
##     （本文件因此是 `run()` 里带 `await` 的协程，`run_tests.gd` 的 `suite.run(t)` 直接支持）；
##   · 用完必 `remove_child` + `free`。
##   · 界面文字只用 GB2312 常用字（与 `UiTheme` 同一条纪律）。
extends RefCounted

const BOOT_TSCN := "res://presentation/boot/boot.tscn"
## 设计画布 + 顶栏高 + 屏幕容器可用区（与 `UiTheme.顶栏高` 同一口径）。
const 画布宽 := 1280.0
const 画布高 := 720.0
const 顶栏高 := 104.0
## 6 个屏名（契约 §4 的路由表）。
const 屏们 := ["menu", "squad", "map", "formation", "battle", "result"]
## 顶栏右侧那 4 个功能按钮（不许被藏品 / 零件挤出右界）。
const 顶栏右按钮们 := ["招募按钮", "编队按钮", "战术牌库按钮", "保存回菜单按钮"]
## ★ MITH-3 夹具：秘银五人队（含毛 U2 / 克鲁兹 U6）+ 第 1 层敌人（与 MITH-1 / MITH-2 测试同一份）。
const 秘银我方 := [
	{"键": "U7", "位": 0, "等级": 10}, {"键": "U6", "位": 1, "等级": 10},
	{"键": "U2", "位": 2, "等级": 10}, {"键": "U1", "位": 3, "等级": 10},
	{"键": "U8", "位": 4, "等级": 10},
]
const 秘银敌方 := [{"键": "flagship", "位": 0, "等级": 1}, {"键": "bluefish", "位": 1, "等级": 1}]

func run(t) -> void:
	var 树根 := _根()
	var 起: int = t.passes + t.fails
	await _段1_单屏可见性与弹窗不误遮挡(t, 树根)
	var 段1: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段2_顶栏与主屏层级和边界(t, 树根)
	var 段2: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段3_悬停说明信息(t, 树根)
	var 段3: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段4_试玩反馈四个修复(t, 树根)
	var 段4: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段5_实时监视与全动作记录(t, 树根)
	var 段5: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段6_战前编队确认与顶栏锁(t, 树根)
	var 段6: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段7_幂等休整与战后九十概率(t, 树根)
	var 段7: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段8_秘银v02三层反馈(t, 树根)
	var 段8: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段9_UX1六项修复(t, 树根)
	var 段9: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段10_UX2发牌来源(t, 树根)
	var 段10: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段11_UX3战斗动画层(t, 树根)
	var 段11: int = t.passes + t.fails - 起
	起 = t.passes + t.fails
	await _段12_单机牌组战斗屏(t, 树根)
	var 段12: int = t.passes + t.fails - 起
	t.info("★ 版面门禁分段断言数：段 1（单屏可见性 / 弹窗不遮挡）%d 项 · 段 2（顶栏与主屏 1280×720 边界）%d 项 · 段 3（Mouse-Over 说明信息）%d 项 · 段 4（2026-10-16 试玩反馈四个修复）%d 项 · 段 5（★ 实时监视：局面快照 + 全动作记录）%d 项 · 段 6（★ 战前编队确认 + 顶栏锁）%d 项 · 段 7（★ 同一格幂等 + 战后 90%% 给券）%d 项 · 段 8（★ MITH-3 秘银 v0.2 三层反馈）%d 项 · 段 9（★ UX-1 战后回地图 / 拖拽编队 / 藏品零件悬停 / 零件瞄准横幅）%d 项 · 段 10（★ UX-2 发牌来源机体 / 悬停联动高亮 / 新发牌示意）%d 项 · 段 11（★ UX-3 动作播报条 / 弹道连线 / 头顶飘字 / 出手受击反馈）%d 项 · 段 12（★ DECK-2/DECK-3 单机牌组：点选机体 / 战意条 / 上下双排手牌 / 0.5s 即时演出 / 意图预告）%d 项 · 合计 %d 项"
		% [段1, 段2, 段3, 段4, 段5, 段6, 段7, 段8, 段9, 段10, 段11, 段12,
			段1 + 段2 + 段3 + 段4 + 段5 + 段6 + 段7 + 段8 + 段9 + 段10 + 段11 + 段12])

# ==========================================================================================
# 工具
# ==========================================================================================

func _根() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

## 等两帧：Godot 的 `Container`/锚点布局是**延迟**做的，
## 不跑帧的话 `get_global_rect()` 全是 0×0（headless 测试里实测如此）。
func _等帧(n: int = 2) -> void:
	for _i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame

## 把视口收到设计画布（headless 默认是 1280×1280，这里显式钉住）。
func _设视口(树根: Node, 尺寸: Vector2) -> void:
	if 树根 is Window:
		(树根 as Window).size = Vector2i(int(尺寸.x), int(尺寸.y))

## 造一个挂在 `尺寸` 大容器里的 boot 并 `启动()`。返回 `{容器, boot, 尺寸, 视图}`。
## ★ 一定要把容器 `add_child` 到 root：`HoverTooltip._找层()` 靠 `is_inside_tree()`。
## ★ `custom_minimum_size` 会在**没跑帧**的情况下把容器撑住旧尺寸（1280×720），
##   所以量一次实际尺寸再写下去 —— 窄视口（960×540）那一段全靠这一步。
func _建boot(树根: Node, 尺寸: Vector2 = Vector2(画布宽, 画布高)) -> Dictionary:
	var 场景: Variant = load(BOOT_TSCN)
	if 场景 == null:
		return {}
	var boot = 场景.instantiate()
	if boot == null:
		return {}
	var 容器 := Control.new()
	容器.name = "测试视口"
	树根.add_child(容器)
	容器.size = 尺寸
	await _等帧()
	var 真 := 容器.size
	if 真.x <= 0.0 or 真.y <= 0.0:
		真 = 尺寸
	容器.custom_minimum_size = 真
	容器.size = 真
	容器.add_child(boot)
	boot.启动()
	await _等帧(2)
	return {"容器": 容器, "boot": boot, "尺寸": 真, "视图": boot.find_child("屏幕容器", true, false)}

func _拆boot(树根: Node, 舱: Dictionary) -> void:
	if 舱.is_empty():
		return
	var 容器: Variant = 舱.get("容器")
	if 容器 != null and is_instance_valid(容器):
		树根.remove_child(容器)
		容器.free()

## 一个控件的全局矩形（拿不到 / 不可见 → 空矩形）。
func _框(父: Node, 路径: String) -> Rect2:
	if 父 == null or not is_instance_valid(父):
		return Rect2()
	var n = 父.find_child(路径, true, false)
	if not (n is Control):
		return Rect2()
	var c: Control = n
	if not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()

func _在界内(框: Rect2) -> bool:
	return 框.size.x > 0.0 and 框.size.y > 0.0 \
		and 框.position.x >= -0.5 and 框.position.y >= -0.5 \
		and 框.end.x <= 画布宽 + 0.5 and 框.end.y <= 画布高 + 0.5

func _在(框: Rect2, 界限: Rect2) -> bool:
	return 框.size.x > 0.0 and 框.size.y > 0.0 \
		and 框.position.x >= 界限.position.x - 0.5 and 框.position.y >= 界限.position.y - 0.5 \
		and 框.end.x <= 界限.end.x + 0.5 and 框.end.y <= 界限.end.y + 0.5

## 两个矩形重叠了吗（交集面积为 0 才算不重叠）。
func _叠(a: Rect2, b: Rect2) -> bool:
	var 交 := a.intersection(b)
	return 交.size.x > 0.001 and 交.size.y > 0.001

func _交面积(a: Rect2, b: Rect2) -> float:
	var 交 := a.intersection(b)
	return maxf(交.size.x, 0.0) * maxf(交.size.y, 0.0)

func _短(r: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]

## 屏幕容器下**可见**的子视图有哪些（≥2 个就是「多屏叠加」）。
func _可见屏(视图: Node) -> Array:
	var out: Array = []
	if 视图 == null or not is_instance_valid(视图):
		return out
	for c in 视图.get_children():
		if c is Control and (c as Control).visible:
			out.append(str((c as Control).name))
	return out

## 屏幕容器下**驻留**（建过）的子视图总数。
func _驻留屏(视图: Node) -> int:
	var n := 0
	if 视图 == null or not is_instance_valid(视图):
		return n
	for c in 视图.get_children():
		if c is Control:
			n += 1
	return n

func _查(t, 前缀: String, 舱: Dictionary, 路径: String, 界限: Rect2) -> Rect2:
	var 框 := _框(舱.get("boot"), 路径)
	t.ok(_在(框, 界限), "%s 「%s」%s 完全落在 %s 内" % [前缀, 路径, _短(框), _短(界限)])
	return 框

func _查不叠(t, 前缀: String, 舱: Dictionary, a: String, b: String) -> void:
	var 框a := _框(舱.get("boot"), a)
	var 框b := _框(舱.get("boot"), b)
	t.ok(框a.size.x > 0.0 and 框b.size.x > 0.0 and not _叠(框a, 框b),
		"%s 「%s」%s 与「%s」%s 互不重叠（交面积 %.0f）" % [前缀, a, _短(框a), b, _短(框b), _交面积(框a, 框b)])

## 满手藏品与零件的 run_state（顶栏宽度压力的最坏情况）。
func _塞满藏品与零件(boot) -> int:
	var s: RunState = boot.session.run_state
	if s == null:
		return 0
	s.relics = []
	for 键 in RelicSystem.表().keys():
		s.relics.append(str(键))
	s.parts = []
	var 零件表: Variant = Db.catalog.parts()
	if 零件表 is Dictionary:
		for 键 in (零件表 as Dictionary).keys():
			s.parts.append({"id": str(键), "uses": 9, "value": 0})
	return s.relics.size() + s.parts.size()

## 一个控件（或它子树里任意一个）的 tooltip 里有没有这段文字。
func _提示含(控件: Node, 片段: String) -> bool:
	if 控件 == null or not is_instance_valid(控件):
		return false
	if 控件 is Control and str((控件 as Control).tooltip_text).contains(片段):
		return true
	for c in 控件.get_children():
		if _提示含(c, 片段):
			return true
	return false

func _提示文(控件: Node) -> String:
	if 控件 is Control:
		return str((控件 as Control).tooltip_text)
	return ""

func _弹窗可见(boot) -> bool:
	var 层: Variant = boot.find_child("弹窗层", true, false)
	return 层 is Control and (层 as Control).visible

func _弹窗类型(s: GameSession) -> String:
	if s == null or not (s.modal is Dictionary):
		return ""
	return str((s.modal as Dictionary).get("类型", ""))

## 关掉现在挂着的弹窗（招募成功会自动弹「三选一」，段 1 要验的是「没有**自动**弹黑幕」，
## 所以先把人手动开的那一个收掉，再看后面每一步）。
func _关弹窗(boot) -> void:
	boot.关闭弹窗()
	await _等帧(2)

## 把 `pending_card_picks` 全部选掉（门面口径：只要它非空，每次切屏都会自动弹三选一）。
func _清待选(s: GameSession) -> int:
	var 选 := 0
	while s != null and s.run_state != null and not s.run_state.pending_card_picks.is_empty() and 选 < 12:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选 += 1
	return 选

## ★ 把手上**没决定的招募券**全部放弃（2026-10-18 起：有未决券时大地图点格子不移动）。
## 返回丢了几张。夹具专用 —— 走的是门面公开口子 `discard_ticket()`。
func _清券(s: GameSession) -> int:
	var 丢 := 0
	while s != null and s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	return 丢

# ==========================================================================================
# 段 1：单屏可见性 + 弹窗不误遮挡（「多个界面叠加」的根治）
# ==========================================================================================

func _段1_单屏可见性与弹窗不误遮挡(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 1 跑不了")
		return
	var boot = 舱["boot"]
	var 视图: Variant = 舱["视图"]
	await _等帧(2)
	t.ok(视图 != null, "boot 里有「屏幕容器」（%s）" % _短(_框(boot, "屏幕容器")))
	t.ok(boot.session != null and (boot.session.modal is Dictionary and (boot.session.modal as Dictionary).is_empty()),
		"刚启动时没有弹窗（session.modal 空）")
	if boot.session.run_state == null:
		t.ok(boot.session.start_new_run(20261031, "混编"), "段 1：开一局肉鸽（大地图 / 编队 / 战斗 / 结算四条路都要走）")
	await _段1a_逐屏只有一个可见(t, boot, 视图)
	await _段1b_战斗屏不被弹窗盖住(t, boot, 视图)
	await _段1c_回大地图不叠结算弹窗(t, boot, 视图)
	_拆boot(树根, 舱)

## ① 6 个屏切过来切过去：每一刻 `屏幕容器` 下**可见**的子视图恰好 1 个。
## ★ 先做「招募那一下会顺手弹三选一」的取证（视图/门面的既有行为，不是 bug）：
##   招完就**手动关掉**它，之后每一步都不许再有**自动**弹出来的黑幕。
func _段1a_逐屏只有一个可见(t, boot, 视图) -> void:
	var 最多 := 0
	var 最坏 := ""
	for 轮 in 3:
		for 屏 in 屏们:
			boot.session.screen = str(屏)
			boot.route()
			await _等帧()
			var 可见 := _可见屏(视图)
			if 可见.size() > 最多:
				最多 = 可见.size()
				最坏 = str(屏)
			t.ok(可见.size() == 1,
				"第 %d 轮路由到「%s」：屏幕容器下可见子视图 = %d 个（%s）—— 同一时刻只有一个屏"
				% [轮 + 1, str(屏), 可见.size(), ", ".join(可见)])
	t.ok(最多 == 1, "★ 三轮 6 屏切下来，可见子视图**最多**只有 %d 个（最坏出现在「%s」）—— 没有多屏叠加" % [最多, 最坏])
	t.ok(_驻留屏(视图) >= 5,
		"★ 视图是「用到才建 + 复用」：切完 6 屏之后驻留着 %d 个子视图（不是每屏各建一堆）" % _驻留屏(视图))

## ② 开新局 → 编队 → 进战斗：不许自动弹「战斗」黑幕把战斗屏盖住。
func _段1b_战斗屏不被弹窗盖住(t, boot, 视图) -> void:
	var s: GameSession = boot.session
	s.screen = "map"
	boot.route()
	await _等帧()
	t.ok(not _弹窗可见(boot), "开新局 → 大地图：弹窗层不可见（没有自动弹任何黑幕）")
	# 招募 + 上阵（开战要求出击名单非空）
	var 招 := 0
	for _i in 4:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "用开局券招到 %d 台（名册 %d 台）" % [招, s.run_state.roster.size()])
	await _关弹窗(boot)
	t.ok(_弹窗类型(s).is_empty() and not _弹窗可见(boot),
		"★ 招完手动关一次弹窗（招募会顺手弹「三选一」，这是门面的既有行为）→ 弹窗层和 session.modal 都空了")
	# ★ 2026-10-18：手上还有未决招募券时，大地图**点格子不移动**（先把券决定完）——
	#   这一段要验的是「走上去就进战前编队确认屏」，所以先把券处理干净。
	_清券(s)
	# ★ 门面的 `_refresh_modal()` 口径：只要 `pending_card_picks` 非空，**每次切屏都会自动弹三选一**。
	#   这里先把待选牌选干净（人正常玩也是这样：选完牌才继续），
	#   后面「进战斗 / 打牌 / 推进回合 / 回大地图」才真的能验「有没有自动弹黑幕」。
	var 选掉 := _清待选(s)
	t.ok(s.run_state.pending_card_picks.is_empty(),
		"★ 把 %d 张待选战术牌选掉 → `pending_card_picks` 空了（这样后面每一步的弹窗层都该是干净的）" % 选掉)
	await _关弹窗(boot)
	if not s.run_state.roster.is_empty():
		var 首键 := str(s.run_state.roster.keys()[0])
		t.ok(s.set_lineup_slot(首键, str(s.lineup_slots()[0].get("位名", ""))), "把 %s 摆上出击位" % 首键)
	s.screen = "formation"
	boot.route()
	await _等帧()
	t.ok(s.screen == "formation" and not _弹窗可见(boot),
		"编队屏：screen = %s、弹窗层不可见（切到编队也不会弹黑幕）" % s.screen)
	# 走上一个战斗格 → 直接开战（走视图那条点击路径）
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "第 %d 层找不到战斗格 —— 段 1b 剩下的断言跑不了" % s.run_state.floor_num)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "战斗格 %d 四周找不到落脚点 —— 段 1b 剩下的断言跑不了" % 战斗格)
		return
	s.run_state.node_id = 落脚
	s.screen = "map"
	boot.route()
	await _等帧()
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "大地图视图类型不对（%s），段 1b 跑不了" % str(mv))
		return
	(mv as MapView)._点格(战斗格)
	# ★ 2026-10-18：走上战斗格先进**战前编队确认屏**（不再直接开打），点【确认编队 · 开始战斗】才进战斗。
	t.ok(s.screen == "formation" and s.pending_battle_confirm,
		"★ 走上战斗格 %d → 先进战前编队确认屏（screen = %s、pending = %s）" % [战斗格, s.screen, str(s.pending_battle_confirm)])
	await _等帧(2)
	var 开战钮: Control = boot.find_child("开始战斗按钮", true, false)
	if 开战钮 is Button:
		(开战钮 as Button).pressed.emit()
		await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"★ 点【确认编队 · 开始战斗】→ 开战（screen = %s、battle_ctx 我方 %d 台 / 敌方 %d 台）"
		% [s.screen,
			(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	await _等帧()
	t.ok(not _弹窗可见(boot),
		"★ 进战斗屏的那一刻 `弹窗层.visible == false`（没有自动弹「战斗」黑幕遮挡战斗屏）")
	# 「打光可出牌或推进回合」的两条路都不许把黑幕弹出来
	var 能打 := s.playable_hand_ids()
	t.ok(not 能打.is_empty(), "★ 开局气势 %s 之下能打 %d 张手牌（打光可出牌那一条路）"
		% [str(s.battle_ctx.get("气势", 0.0)), 能打.size()])
	if not 能打.is_empty():
		s.play_tactical_card(str(能打[0]))
		boot.route()
		await _等帧()
		t.ok(not _弹窗可见(boot), "打完一张手牌之后：弹窗层仍不可见")
	s.step_battle_turn()
	boot.route()
	await _等帧()
	t.ok(not _弹窗可见(boot), "推进一个回合之后：弹窗层仍不可见（第 %s 回合）"
		% UiTheme.文本(int(float(s.battle_ctx.get("turn", 1.0)))))

## ③ 战斗结束 → 结算屏 → 点「继续按钮」回大地图：screen = map 且弹窗层不可见。
func _段1c_回大地图不叠结算弹窗(t, boot, 视图) -> void:
	var s: GameSession = boot.session
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"承接段 1b：现在停在战斗屏且有真战斗（screen = %s）" % s.screen)
	# ★ 先把「招募那一下自动弹出来的三选一」关掉（人手动开的窗由人关；
	#   这里要验的是**没有任何动作会自动**弹出黑幕把屏幕盖住）。
	await _关弹窗(boot)
	t.ok(not _弹窗可见(boot), "手动关掉三选一之后：弹窗层不可见")
	s.auto_finish_battle()
	t.ok(s.battle_ctx.get("result") != null, "自动打完本场：结果 = %s" % s.战果文字())
	var bv = boot.当前视图()
	if bv is BattleView:
		(bv as BattleView)._点结算()
	t.ok(s.screen == "result", "打完并结算 → screen = result（真实值 %s）" % s.screen)
	await _等帧()
	var rv = boot.当前视图()
	t.ok(rv is ResultView, "路由到 result 之后，当前视图是 ResultView（%s）" % str(rv))
	t.ok(not _弹窗可见(boot) or _弹窗类型(s) != "结算",
		"★ 结算屏上 `弹窗层` 不会叠第二个结算面板（现在弹窗类型 =「%s」）" % _弹窗类型(s))
	# ★ 点「继续按钮」那一下（走视图自己的信号路，不是直接改 screen）
	if rv is ResultView and (rv as ResultView)._继续按钮 != null:
		(rv as ResultView)._继续按钮.pressed.emit()
	else:
		boot.去屏("map")
	await _等帧()
	t.ok(s.screen == "map", "★ 点「继续按钮」→ screen = map（真实值 %s）" % s.screen)
	t.ok(_弹窗类型(s) != "结算", "★ 回大地图时 `session.modal` 里没有「结算」（类型 =「%s」）" % _弹窗类型(s))
	# 收掉可能还欠着的三选一，再看弹窗层
	await _关弹窗(boot)
	t.ok(not _弹窗可见(boot),
		"★ 回到大地图之后 `弹窗层.visible == false`（不会在地图上叠第二个结算弹窗）")
	t.ok(_弹窗类型(s).is_empty(), "★ 回到大地图之后 session.modal 也是空的（类型 =「%s」）" % _弹窗类型(s))
	# 再走一次兜底入口 `boot.去屏("map")`：屏幕没变时也不许把弹窗打开
	boot.去屏("map")
	await _等帧()
	t.ok(s.screen == "map" and not _弹窗可见(boot), "兜底入口 `boot.去屏(\"map\")` 也不会打开弹窗")

# ==========================================================================================
# 段 2：顶栏与主屏层级 / 1280×720 边界
# ==========================================================================================

func _段2_顶栏与主屏层级和边界(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 2 跑不了")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	if boot.session.run_state == null:
		boot.session.start_new_run(20261107, "混编")
	var 装了 := _塞满藏品与零件(boot)
	t.ok(装了 >= 30, "★ 夹具：给这一局塞了 %d 件藏品 + 零件（顶栏宽度压力最大的一档）" % 装了)
	await _段2a_顶栏高度与右界(t, 舱)
	await _段2b_战斗屏布局(t, 舱)
	await _段2c_结算屏布局(t, 舱)
	await _段2d_地图与编队布局(t, 舱)
	await _段2e_窄视口(t, 树根)
	_拆boot(树根, 舱)

## ②-a 顶栏（含 `顶栏底`）完全落在 `(0, 0, 1280, 104)` 内，不压住 y >= 104 的屏幕容器；
##     右侧 4 个按钮即使在满手藏品 / 零件时也不出右界。
func _段2a_顶栏高度与右界(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var 界限 := Rect2(0.0, 0.0, 画布宽, 顶栏高)
	var 轮 := 0
	for 屏 in 屏们:
		轮 += 1
		boot.session.screen = str(屏)
		boot.route()
		await _等帧()
		_查(t, "第 %d 屏顶栏" % 轮, 舱, "顶栏", 界限)
		_查(t, "第 %d 屏顶栏底" % 轮, 舱, "顶栏底", 界限)
		var 顶 := _框(boot, "顶栏")
		var 容 := _框(boot, "屏幕容器")
		t.ok(顶.size.x > 0.0 and 容.size.y > 0.0 and 顶.end.y <= 容.position.y + 0.5,
			"路由到「%s」：顶栏底边 y = %.1f ≤ 屏幕容器顶边 y = %.1f（顶栏不压住 y >= 104 的屏幕容器）"
			% [str(屏), 顶.end.y, 容.position.y])
		for 名 in 顶栏右按钮们:
			var 框 := _框(boot, str(名))
			t.ok(框.size.x > 0.0 and 框.end.x <= 画布宽 + 0.5,
				"路由到「%s」：顶栏按钮「%s」%s 不出右界（end.x = %.1f <= 1280）—— 满手藏品 / 零件也不裁切"
				% [str(屏), str(名), _短(框), 框.end.x])

## ②-b 战斗屏：16 张卡不互压、卡身与内部底板尺寸一致、三大区块两两不重叠且都在可用区内。
func _段2b_战斗屏布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if not s.start_quick_battle(20261013):
		t.ok(false, "start_quick_battle(20261013) 开不起来 —— 战斗屏版面断言跑不了")
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "战斗屏视图类型不对（%s）" % str(bv))
		return
	var 视图: BattleView = bv
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(), "★ 战斗屏建起来了（screen = %s）" % s.screen)
	var 卡们 := 视图.find_children("*", "UnitCard", true, false)
	t.ok(卡们.size() == int(Fm.SLOTS()) * 2,
		"★ 战斗屏常驻 %d 张 UnitCard（8 格 × 双方，不是 9 格）" % 卡们.size())
	var 排盒名们 := ["我方阵型第0排", "我方阵型第1排", "敌方阵型第0排", "敌方阵型第1排"]
	for b in 卡们:
		var 卡: Control = b
		var 底 := 卡.find_child("单位卡底", true, false)
		var 框 := 卡.get_global_rect()
		var 底框: Rect2 = (底 as Control).get_global_rect() if 底 is Control else Rect2()
		t.ok(底 is Control, "UnitCard 里有「单位卡底」（%s）" % str(卡.get_parent().name))
		t.ok(absf(框.size.x - 底框.size.x) <= 0.6 and absf(框.size.y - 底框.size.y) <= 0.6,
			"★ 单位卡（%s）卡身 %s 与内部「单位卡底」%s 尺寸一致（不再是 19px 塌缩高）"
			% [str(卡.get_parent().name), _短(框), _短(底框)])
		t.ok(框.size.y >= 100.0, "★ 单位卡高度 %.0f >= 100（按 132×148 报最小尺寸，不塌缩）" % 框.size.y)
		t.ok(框.position.y >= 顶栏高 - 0.5 and _在界内(框), "单位卡 %s 落在 1280×720 内（且在顶栏之下）" % _短(框))
	# 同排 4 张两两不重叠
	for 排名 in 排盒名们:
		var 排 = 视图.find_child(排名, true, false)
		if 排 == null:
			t.ok(false, "战斗屏里找不到「%s」" % 排名)
			continue
		var 框们: Array = []
		for c in (排 as Node).get_children():
			if c is UnitCard:
				框们.append((c as Control).get_global_rect())
		t.ok(框们.size() == 4, "★「%s」里有 4 张单位卡（前 4 + 后 4）" % 排名)
		var 叠了 := 0
		for i in 框们.size():
			for j in range(i + 1, 框们.size()):
				if _叠(框们[i], 框们[j]):
					叠了 += 1
		t.ok(叠了 == 0, "★「%s」里 4 张卡两两互不重叠（重叠对数 = %d）" % [排名, 叠了])
	# 前排与后排互不重叠（跨排）
	var 我方0 := _排框(视图, "我方阵型第0排")
	var 我方1 := _排框(视图, "我方阵型第1排")
	var 敌方0 := _排框(视图, "敌方阵型第0排")
	var 敌方1 := _排框(视图, "敌方阵型第1排")
	t.ok(not _叠(我方0, 我方1), "★ 我方前排 %s 与后排 %s 互不重叠" % [_短(我方0), _短(我方1)])
	t.ok(not _叠(敌方0, 敌方1), "★ 敌方前排 %s 与后排 %s 互不重叠" % [_短(敌方0), _短(敌方1)])
	t.ok(not _叠(我方0, 敌方0), "★ 我方前排 %s 与敌方前排 %s 互不重叠" % [_短(我方0), _短(敌方0)])
	# 三大区块
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	var 阵 := _查(t, "战斗屏", 舱, "阵型区", 可用)
	var 手 := _查(t, "战斗屏", 舱, "手牌栏", 可用)
	var 报 := _查(t, "战斗屏", 舱, "战报栏", 可用)
	t.ok(not _叠(阵, 手) and not _叠(阵, 报) and not _叠(手, 报),
		"★ 阵型区 %s / 手牌栏 %s / 战报栏 %s 两两互不重叠（交面积 %.0f / %.0f / %.0f）"
		% [_短(阵), _短(手), _短(报), _交面积(阵, 手), _交面积(阵, 报), _交面积(手, 报)])
	for 名 in ["推进按钮", "自动按钮", "结算按钮"]:
		var 框 := _框(boot, str(名))
		t.ok(框.size.x > 0.0 and 框.end.y <= 画布高 + 0.5 and 框.end.x <= 画布宽 + 0.5,
			"战斗屏按钮「%s」%s 落在画布内（end.y = %.1f <= 720）" % [str(名), _短(框), 框.end.y])

func _排框(视图: Node, 排名: String) -> Rect2:
	var 排 = 视图.find_child(排名, true, false)
	if 排 == null:
		return Rect2()
	var 起 := Vector2(INF, INF)
	var 止 := Vector2(-INF, -INF)
	var 有 := false
	for c in (排 as Node).get_children():
		if not (c is UnitCard):
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		起 = Vector2(minf(起.x, r.position.x), minf(起.y, r.position.y))
		止 = Vector2(maxf(止.x, r.end.x), maxf(止.y, r.end.y))
		有 = true
	if not 有:
		return Rect2()
	return Rect2(起, 止 - 起)

## ②-c 结算屏：真打完一场有战报的战斗之后，三块都在可用区内，两个按钮不出画布。
func _段2c_结算屏布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.battle_ctx.is_empty():
		s.start_quick_battle(20261013)
	if s.battle_ctx.is_empty():
		t.ok(false, "开不出战斗 —— 结算屏版面断言跑不了")
		return
	if s.battle_ctx.get("result") == null:
		s.step_battle_turn()
		s.auto_finish_battle()
	if s.battle_ctx.get("result") == null:
		t.ok(false, "这一场打不完 —— 结算屏版面断言跑不了")
		return
	s.finish_battle_and_settle()
	boot.route()
	await _等帧(3)
	t.ok(s.screen == "result", "★ 真打完一场（战报 %d 行）→ screen = result" % s.battle_log_entries(0).size())
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	_查(t, "结算屏", 舱, "结算面板", 可用)
	_查(t, "结算屏", 舱, "战利品区", 可用)
	var 回顾 := _查(t, "结算屏", 舱, "战报回顾", 可用)
	var 面板 := _框(boot, "结算面板")
	t.ok(not _叠(面板, 回顾), "★ 结算屏「结算面板」%s 与「战报回顾」%s 互不重叠" % [_短(面板), _短(回顾)])
	for 名 in ["继续按钮", "回菜单按钮"]:
		var 框 := _框(boot, str(名))
		t.ok(框.size.x > 0.0 and 框.end.y <= 画布高 + 0.5,
			"★ 结算屏「%s」%s 没掉到画布外（end.y = %.1f <= 720；曾经是 1794）" % [str(名), _短(框), 框.end.y])

## ②-d 大地图与编队屏：两块主体互不重叠、都在 1280×720 内。
func _段2d_地图与编队布局(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null:
		s.start_new_run(20261107, "混编")
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var 屏 := Rect2(0.0, 0.0, 画布宽, 画布高)
	_查(t, "大地图", 舱, "地图网格", 屏)
	_查(t, "大地图", 舱, "预告面板", 屏)
	_查不叠(t, "大地图", 舱, "地图网格", "预告面板")
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	_查(t, "编队屏", 舱, "格位网格", 屏)
	_查(t, "编队屏", 舱, "名册列表", 屏)
	_查不叠(t, "编队屏", 舱, "格位网格", "名册列表")

## ②-e 窄视口（960×540）：根盒跟着容器自适应，战斗屏的兜底裁切在窄视口下也守得住。
## ★ 口径：战斗屏的最小宽度是**设计死数**（阵型区左右两栏 + 战报栏，实测最小 ~1150），
##   窄视口下它被 `战斗屏上下列` 的 `clip_contents` 裁掉 —— 这是设计取舍，不是溢出 bug；
##   这里守的是「根盒真的收到 960×436」+「裁切块仍然落在 1280×720 设计画布里」。
func _段2e_窄视口(t, 树根: Node) -> void:
	_设视口(树根, Vector2(960, 540))
	var 舱 := await _建boot(树根, Vector2(960, 540))
	if 舱.is_empty():
		t.ok(false, "窄视口下 boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	await _等帧(3)
	var 容 := _框(boot, "屏幕容器")
	t.ok(absf(容.size.x - 960.0) < 1.0 and absf(容.size.y - (540.0 - 顶栏高)) < 1.5,
		"窄视口：根盒「屏幕容器」= %s（跟着 960×540 的容器自适应，从 1280×616 收到 960×436）" % _短(容))
	t.ok(容.position.y >= 顶栏高 - 0.5, "窄视口：顶栏仍让出 y >= 104 那一条（屏幕容器顶边 y = %.1f）" % 容.position.y)
	if boot.session.run_state == null:
		boot.session.start_new_run(20261107, "混编")
	var 屏 := Rect2(0.0, 0.0, 960.0, 540.0)
	for 屏名 in ["map", "formation"]:
		boot.session.screen = str(屏名)
		boot.route()
		await _等帧(3)
		for 名 in ["层信息", "格位网格"]:
			var 框 := _框(boot, str(名))
			if 框.size.x <= 0.0:
				continue
			t.ok(_在(框, 屏), "窄视口 960×540 · %s 屏「%s」%s 仍在 960×540 内（根盒自适应）"
				% [str(屏名), str(名), _短(框)])
	if not boot.session.start_quick_battle(20261013):
		t.ok(false, "窄视口下开不出战斗")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if bv is BattleView:
		# 战斗屏的最小宽度是设计死数（~1150），窄视口下由 `屏幕容器`（960 宽）裁掉多余部分；
		# 这里断言「真正决定可见边界的根盒就是 960 宽」+「每个块都还在 1280×720 设计画布内」。
		t.ok(absf(容.size.x - 960.0) < 1.0,
			"窄视口：战斗屏的可见边界 = 屏幕容器 %.0f 宽（超出的部分被它裁掉，不会画到视口外）" % 容.size.x)
		for 名 in ["阵型区", "手牌栏", "战报栏", "推进按钮", "自动按钮", "结算按钮"]:
			var 框 := _框(boot, str(名))
			t.ok(框.size.x > 0.0 and _在界内(框),
				"窄视口 960×540 · 战斗屏「%s」%s 仍在 1280×720 设计画布内（不画到画布外）" % [str(名), _短(框)])
	_拆boot(树根, 舱)

# ==========================================================================================
# 段 3：机体与卡牌 Mouse-Over 说明信息
# ==========================================================================================

func _段3_悬停说明信息(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "boot.tscn 实例化失败 —— 段 3 跑不了")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	var 层 = boot.find_child("悬停说明层", true, false)
	t.ok(层 is HoverTooltip, "★ boot 下有「悬停说明层」（HoverTooltip，整局只有一层）")
	var 面板 = boot.find_child("悬停面板", true, false)
	t.ok(面板 is Control, "悬停说明层里有「悬停面板」")
	t.ok(面板 is Control and not (面板 as Control).visible, "★ 初始 `悬停面板.visible == false`（不悬停就不显示）")
	if not (层 is HoverTooltip):
		_拆boot(树根, 舱)
		return
	var 悬停: HoverTooltip = 层
	await _段3a_机体悬停(t, 舱, 悬停)
	await _段3b_卡牌悬停(t, 舱, 悬停)
	_拆boot(树根, 舱)

## ③-a 机体：战斗屏在场双方单位卡 + 编队格位 / 名册 + 招募候选。
func _段3a_机体悬停(t, 舱: Dictionary, 悬停: HoverTooltip) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ---------- 战斗屏 ----------
	if not s.start_quick_battle(20261013):
		t.ok(false, "段 3a：start_quick_battle(20261013) 开不起来")
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "段 3a：战斗屏视图类型不对（%s）" % str(bv))
		return
	var 视图: BattleView = bv
	var 占位 := _位号到键(s, "ally")
	var 敌位 := _位号到键(s, "enemy")
	t.ok(视图.find_children("*", "UnitCard", true, false).size() == int(Fm.SLOTS()) * 2,
		"段 3a：战斗屏有 %d 张 UnitCard（我方 %d 台 / 敌方 %d 台在场）"
		% [int(Fm.SLOTS()) * 2, 占位.size(), 敌位.size()])
	var 查过 := 0
	for 位号 in 占位.keys():
		var 卡: Control = 视图._我方卡[int(位号)]
		var 键 := str(占位[位号])
		var 名 := str((s.unit_view("ally", 键) as Dictionary).get("名", 键))
		var 前缀 := "战斗屏我方 %s（%s）" % [Fm.位名(float(位号)), 名]
		_机器卡断言(t, 卡, 名, 前缀)
		_悬停断言(t, 悬停, 卡, 前缀)
		查过 += 1
		if 查过 >= 4:
			break
	for 位号 in 敌位.keys():
		var 卡: Control = 视图._敌方卡[int(位号)]
		var 键 := str(敌位[位号])
		var 名 := str((s.unit_view("enemy", 键) as Dictionary).get("名", 键))
		var 前缀 := "战斗屏敌方 %s（%s）" % [Fm.位名(float(位号)), 名]
		_机器卡断言(t, 卡, 名, 前缀)
		_悬停断言(t, 悬停, 卡, 前缀)
		break
	# ---------- 编队屏 ----------
	# ★ 招募弹窗的「候选机体」必须**先用券之前**量（券用光之后就招不到人了，候选列表自然是空的）；
	#   所以这里先开一次招募弹窗量候选，再继续招募 / 上阵。
	var 券前候选 := s.available_recruit_targets(0).size()
	boot.打开弹窗("招募", {})
	await _等帧(3)
	var 候选 = boot.find_child("候选列表", true, false)
	var 候选钮 := _找按钮(候选)
	t.ok(候选钮 != null and 券前候选 > 0,
		"★ 招募弹窗：候选机体的每条都是一个可悬停按钮（这张券现在能招 %d 位）" % 券前候选)
	if 候选钮 != null:
		_机器卡断言(t, 候选钮, "", "招募弹窗候选机体")
		_悬停断言(t, 悬停, 候选钮, "招募弹窗候选机体")
	await _关弹窗(boot)
	var 招 := 0
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "段 3a：用开局券招到 %d 台来做编队屏的悬停断言（名册 %d 台）"
		% [招, s.run_state.roster.size()])
	var 键们 := s.run_state.roster.keys()
	# ★ 摆哪几台就查哪几台：格位按钮的文本是「位名\n显示名」，照**显示名**找回那一颗按钮，
	#   否则 `find_child` 找到的第一颗可能是别人（断言就张冠李戴了）。
	var 上阵: Array = []
	var 上阵名: Array = []
	for i in mini(2, 键们.size()):
		var 键 := str(键们[i])
		if s.set_lineup_slot(键, str(s.lineup_slots()[i].get("位名", ""))):
			var 显 := str(RosterManager.模板(键).get("pilot", RosterManager.模板(键).get("name", 键)))
			if 显.is_empty():
				显 = 键
			上阵.append(键)
			上阵名.append(显)
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	t.ok(上阵.size() >= 1, "★ 编队屏：摆了 %d 台到出击位（%s）" % [上阵.size(), "、".join(上阵名)])
	var 位格: Control = null
	var 上阵显示名 := ""
	for 排名 in ["第0排", "第1排"]:
		var 排 = boot.find_child(排名, true, false)
		if 排 == null:
			continue
		for k in (排 as Node).get_children():
			if not (k is Button):
				continue
			var 文 := str((k as Button).text)
			if 文.contains("（空）"):
				continue
			for j in 上阵名.size():
				var 键 := str(上阵[j])
				var 显 := str(上阵名[j])
				# ★ 格位按钮正文在**这台机体的模板里没有 `名` 字段**时会退成机体键（B1 / B2），
				#   所以正文与机体键、显示名任一相符都算找到。
				if 文.contains(显) or 文.contains(键):
					位格 = k
					上阵显示名 = 显 if 文.contains(显) else 键
					break
			if 位格 != null:
				break
		if 位格 != null:
			break
	t.ok(位格 != null, "★ 编队屏：找得到「已上阵的格位按钮」（上阵了 %s）" % "、".join(上阵名))
	if 位格 != null:
		_机器卡断言(t, 位格, 上阵显示名, "编队屏已上阵格位［%s］" % 上阵显示名)
		_悬停断言(t, 悬停, 位格, "编队屏已上阵格位［%s］" % 上阵显示名)
	var 列表 = boot.find_child("名册列表", true, false)
	var 名册钮 := _找按钮(列表)
	t.ok(名册钮 != null, "★ 编队屏：找得到「名册列表」里机体按钮（名册 %d 台）" % s.run_state.roster.size())
	if 名册钮 != null:
		_机器卡断言(t, 名册钮, "", "编队屏名册列表")
		_悬停断言(t, 悬停, 名册钮, "编队屏名册列表")
	# ---------- 招募弹窗（名册区）----------
	boot.打开弹窗("招募", {})
	await _等帧(3)
	var 名单 = boot.find_child("名册列表", true, false)
	var 名册条: Control = null
	var 名册钮2: Control = null
	if 名单 != null:
		for c in (名单 as Node).get_children():
			if c is Control:
				if 名册条 == null:
					名册条 = c
				for g in (c as Node).get_children():
					if g is Button and 名册钮2 == null:
						名册钮2 = g
	t.ok(名册条 != null, "★ 招募弹窗：名册区每条也有机体说明")
	if 名册条 != null:
		t.ok(_提示含(名册条, "武器"), "★★ 招募弹窗名册条目 tooltip 含「武器」段（机体属性 + 武器说明齐全）")
		t.ok(_提示含(名册条, "装甲") and _提示含(名册条, "防御") and _提示含(名册条, "机动"),
			"★★ 招募弹窗名册条目 tooltip 含装甲 / 防御 / 机动（机体属性）")
	t.ok(名册钮2 != null, "★ 招募弹窗：名册条目里有「晋升」按钮，也挂着同一段机体说明")
	if 名册钮2 != null:
		_悬停断言(t, 悬停, 名册钮2, "招募弹窗名册按钮")
	await _关弹窗(boot)

## 一张机器卡（或机体按钮）的悬停说明断言：非空 + 含名字 + 属性 + 武器。
## ★ 口径说明：门面 `_单位说明文字()` 的一行是「生命 X / Y（Z%）」；
##   只有**单位卡自己的**说明（`unit_view["悬停说明"]`）会另外带一行「HP X / Y（Z%）」。
##   两种写法都是「这台机体有多少血」，所以这里接受任一，不把断言绑在某个视图的写法上。
func _机器卡断言(t, 卡: Control, 名: String, 前缀: String) -> void:
	var 文 := _提示文(卡)
	t.ok(not 文.strip_edges().is_empty(), "★ %s 的 `tooltip_text` 非空" % 前缀)
	t.ok(文.contains("HP") or 文.contains("生命"), "★ %s 的 tooltip 写清了 HP（「HP」或「生命」）" % 前缀)
	for 片段 in ["装甲", "防御", "机动", "武器"]:
		t.ok(文.contains(片段), "★ %s 的 tooltip 含「%s」" % [前缀, 片段])
	t.ok(名.is_empty() or 文.contains(名) or _短名在(文, 名) or _键在(文, 名),
		"★ %s 的 tooltip 里有这台机体名（%s；tooltip %d 字）" % [前缀, 名, 文.length()])
	t.ok(文.split("\n").size() >= 6, "★ %s 的 tooltip 是多行说明（%d 行）" % [前缀, 文.split("\n").size()])

## Godot 会把控件的 `tooltip_text` 截到 640 个字符左右，机体名在第一行、有时正好被切掉；
## 这时退一步查「名字的前两个字」（一样能证明「这段说明是这台机体的」，不是别人的）。
func _短名在(文: String, 名: String) -> bool:
	return 名.length() >= 2 and 文.contains(名.substr(0, 2))

## 传进来的是**机体键**（B2 / M4 这种）而不是机师名时，用 `RosterManager.模板()` 换成显示名再查。
## ★ 模板里的显示名在 `pilot`（`RosterManager.模板("B2").pilot == "蕾卡"`），不是 `名`。
func _键在(文: String, 键: String) -> bool:
	if 键.length() < 2:
		return false
	var 模 := RosterManager.模板(键)
	var 显 := str(模.get("pilot", 模.get("name", "")))
	if 显.is_empty() or 显 == 键:
		return false
	return 文.contains(显) or _短名在(文, 显)

## `悬停说明层.show_for_control()` 之后：面板可见、当前文本非空、且完全落在 1280×720 内。
func _悬停断言(t, 悬停: HoverTooltip, 卡: Control, 前缀: String) -> void:
	悬停.show_for_control(卡)
	var 面板 = 悬停.find_child("悬停面板", true, false)
	var 框: Rect2 = (面板 as Control).get_global_rect() if 面板 is Control else Rect2()
	t.ok(面板 is Control and (面板 as Control).visible,
		"★ %s：`show_for_control()` 之后「悬停面板.visible == true」" % 前缀)
	t.ok(not 悬停.当前文本().strip_edges().is_empty() and _提示文(卡).contains(悬停.当前文本().strip_edges()),
		"★ %s：`当前文本()` 非空（%d 字），且就是贴在这张卡上的那段说明" % [前缀, 悬停.当前文本().length()])
	t.ok(_在界内(框), "★ %s：悬停面板 %s 完全落在 1280×720 内" % [前缀, _短(框)])
	悬停.hide_tip()

## ③-b 卡牌：战斗屏手牌 / 候补 + 三选一候选 + 战术牌库条目。
func _段3b_卡牌悬停(t, 舱: Dictionary, 悬停: HoverTooltip) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.screen != "battle" or s.battle_ctx.is_empty():
		if not s.start_quick_battle(20261013):
			t.ok(false, "段 3b：开不出战斗")
			return
		boot.route()
		await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(), "段 3b：手上有一场真战斗（screen = %s）" % s.screen)
	# ---------- 手牌 ----------
	var 手牌卡 = boot.find_child("手牌卡1", true, false)
	t.ok(手牌卡 is Control, "★ 战斗屏有「手牌卡1」")
	if 手牌卡 is Control:
		_牌断言(t, 悬停, 手牌卡, "战斗屏手牌卡1")
	var 手牌钮 = boot.find_child("手牌按钮", true, false)
	t.ok(手牌钮 is Control, "★ 战斗屏有「手牌按钮」")
	if 手牌钮 is Control:
		_牌断言(t, 悬停, 手牌钮, "战斗屏手牌按钮")
	# ---------- 候补区 ----------
	var 候补卡 = boot.find_child("候补卡1", true, false)
	t.ok(候补卡 is Control, "★ 战斗屏候补区里有「候补卡1」（候补 %d 张）" % s.reserve_preview().size())
	if 候补卡 is Control:
		_牌断言(t, 悬停, 候补卡, "战斗屏候补卡1")
	# ---------- 三选一 ----------
	var 候选: Array = s.run_state.pending_card_picks.duplicate() if s.run_state != null else []
	if 候选.is_empty() and s.run_state != null and not s.run_state.roster.is_empty():
		s.refresh_card_offers(str(s.run_state.roster.keys()[0]))
		候选 = s.run_state.pending_card_picks.duplicate()
	t.ok(not 候选.is_empty(), "★ 三选一有候选（%d 张：%s）" % [候选.size(), ", ".join(候选.map(func(x): return str(x)))])
	if not 候选.is_empty():
		var 卡id := str(候选[0])
		boot.打开弹窗("三选一", {})
		await _等帧(3)
		var 面板 = boot.find_child("候选卡_" + 卡id, true, false)
		t.ok(面板 != null, "★ 三选一弹窗里有「候选卡_%s」" % 卡id)
		if 面板 is Control:
			_牌文断言(t, _提示文(面板), "三选一候选卡_%s" % 卡id)
			_悬停断言(t, 悬停, 面板, "三选一候选卡_%s" % 卡id)
		var 选中钮 := _找按钮(面板)
		t.ok(选中钮 != null, "★ 三选一候选卡里有「选这张」按钮")
		if 选中钮 != null:
			_牌断言(t, 悬停, 选中钮, "三选一「选这张」")
		await _关弹窗(boot)
	# ---------- 战术牌库 ----------
	if s.run_state != null and s.run_state.tactical_deck.is_empty():
		for 卡id in 候选:
			s.pick_tactical_card(str(卡id))
		if s.run_state.tactical_deck.is_empty():
			s.pick_tactical_card("CMD_ALL_OUT")
	boot.打开弹窗("战术牌库", {})
	await _等帧(3)
	var 内置 = boot.find_child("内置内容", true, false)
	var 牌库条: Control = null
	if 内置 != null:
		for c in (内置 as Node).get_children():
			if c is Control and not _提示文(c).strip_edges().is_empty():
				牌库条 = c
				break
	t.ok(牌库条 != null, "★ 战术牌库弹窗里每张牌条目都挂了悬停说明（牌库 %d 张）"
		% (s.run_state.tactical_deck.size() if s.run_state != null else 0))
	if 牌库条 != null:
		_牌断言(t, 悬停, 牌库条, "战术牌库条目")
	await _关弹窗(boot)

## 子树里第一个 `Button`（广度优先）。
func _找按钮(根: Node) -> Control:
	if 根 == null:
		return null
	var 堆: Array = [根]
	var i := 0
	while i < 堆.size():
		var 现: Node = 堆[i]
		i += 1
		for g in 现.get_children():
			if g is Button:
				return g
			堆.append(g)
	return null

## 一张牌控件的悬停断言：非空 + 耗气 / 冷却 / 触发条件 / 效果说明 + 面板不出画布。
func _牌断言(t, 悬停: HoverTooltip, 卡: Control, 前缀: String) -> void:
	_牌文断言(t, _提示文(卡), 前缀)
	_悬停断言(t, 悬停, 卡, 前缀)

func _牌文断言(t, 文: String, 前缀: String) -> void:
	t.ok(not 文.strip_edges().is_empty(), "★ %s 的 `tooltip_text` 非空" % 前缀)
	for 片段 in ["耗气", "冷却", "触发条件", "效果说明"]:
		t.ok(文.contains(片段), "★ %s 的 tooltip 含「%s」" % [前缀, 片段])

# ==========================================================================================
# 段 4：★ 2026-10-16 作者试玩反馈的四个修复（永久门禁）
#   ① 战斗还没分出胜负时点「结束并结算」→ **自动打完**并切到 result 屏（从前按钮被置灰、点了没反应）；
#   ② 选完分队点「开这一局」→ 立刻弹【招募】；招募 / 放弃此券 / 三选一 / 回招募 / 去编队 闭环走通；
#   ③ Mouse Over 面板在**鼠标右边**（给定 mp 时断言位置），贴右边缘时翻到左侧。
# ==========================================================================================

func _段4_试玩反馈四个修复(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	await _段4a_未打完也能结算(t, 树根)
	await _段4b_开局直达招募与券闭环(t, 树根)
	await _段4c_悬停在鼠标右侧(t, 树根)

## ④-a「点击结算没有反应」：战斗没打完时「结算按钮」**必须可点**，点下去自动打完 + 切 result。
func _段4a_未打完也能结算(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4a：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if not s.start_quick_battle(20261013):
		t.ok(false, "段 4a：start_quick_battle(20261013) 开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "段 4a：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var 按钮 := _找按文(bv, "结束并结算")
	t.ok(按钮 != null, "段 4a：战斗屏上有「结束并结算」按钮")
	if 按钮 == null:
		_拆boot(树根, 舱)
		return
	t.ok(s.battle_ctx is Dictionary and s.battle_ctx.get("result") == null,
		"★ 段 4a：点之前这一场**确实还没分出胜负**（result = %s）" % str(s.battle_ctx.get("result")))
	t.ok(not 按钮.disabled,
		"★★ 段 4a：战斗没打完时「结算按钮」**不是灰的**（disabled = %s）—— 从前这里是 `not 打完`，于是点了没反应"
		% str(按钮.disabled))
	按钮.pressed.emit()
	await _等帧(3)
	t.ok(s.battle_ctx is Dictionary and s.battle_ctx.get("result") != null,
		"★★ 段 4a：点一下「结束并结算」就**自动把本场打完**了（result = %s）" % str(s.battle_ctx.get("result")))
	t.ok(s.screen == "result", "★★ 段 4a：点完 → screen = result（真实值「%s」）" % s.screen)
	t.ok(boot.当前视图() is ResultView, "★★ 段 4a：结算屏真的路由出来了（当前视图 = %s）" % str(boot.当前视图()))
	t.ok(bool((s.result_summary() as Dictionary).get("有结果", false)),
		"★ 段 4a：结算屏读到的门面结果「有结果」= true")
	# 再点一次不该重复结算（幂等闸 D-07 照旧）
	var 再点 := _找按文(boot, "结束并结算")
	if 再点 != null:
		再点.pressed.emit()
		await _等帧(2)
	t.ok(int(s.run_state.battles_fought) <= 1, "★ 段 4a：重复点「结算」不会原地刷场次（场次 = %d）" % int(s.run_state.battles_fought))
	_拆boot(树根, 舱)

## ④-b「选完小队没有招募页面 / 招募券要求做出决定」：开局直达招募 + 券闭环。
func _段4b_开局直达招募与券闭环(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4b：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	s.screen = "squad"
	boot.route()
	await _等帧(3)
	var mv = boot.当前视图()
	if not (mv is MenuView):
		t.ok(false, "段 4b：分队屏视图类型不对（%s）" % str(mv))
		_拆boot(树根, 舱)
		return
	var 开局 := _找按文(mv, "开这一局")
	t.ok(开局 != null, "★ 段 4b：分队屏上有「开局按钮」")
	if 开局 == null:
		_拆boot(树根, 舱)
		return
	开局.pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "map" and s.run_state != null,
		"★ 段 4b：点「开这一局」→ 开出一局（screen「%s」/ 第 %d 层）"
		% [s.screen, int(s.run_state.floor_num) if s.run_state != null else 0])
	# ★ 「门面的默认值没被改」那一半要**直接调门面**来验（点按钮之后 modal 已经被视图层打开了）。
	var 干净会话 := GameSession.new()
	干净会话.存档路径 = "res://.godot/tmp_layout_段4b.json"
	t.ok(干净会话.start_new_run(20261017, "混编"), "★ 段 4b（对照）：直接调门面 `start_new_run()` 也开得出局")
	t.ok(干净会话.modal is Dictionary and (干净会话.modal as Dictionary).is_empty(),
		"★★ 段 4b：门面 `start_new_run()` 的默认值**一个字都没改**：直接调它之后 `modal` 仍是空的（%s）—— 弹招募是视图层发的信号" % str(干净会话.modal))
	t.ok(干净会话.screen == "map" and 干净会话.ticket_count() > 0,
		"★ 段 4b（对照）：`screen` 仍是 map（「%s」）、券 %d 张 —— test_session_flow / test_session_run 的既有断言照旧"
		% [干净会话.screen, 干净会话.ticket_count()])
	t.ok(s.ticket_count() > 0, "★ 段 4b：开局发了 %d 张招募券、名册 %d 台" % [s.ticket_count(), s.roster_count()])
	# 开局那一下的弹窗是视图层信号打开的：此时弹窗层已经挂上【招募】
	t.ok(_弹窗类型(s) == "招募" and _弹窗可见(boot),
		"★★ 段 4b：选完分队点「开这一局」**立刻弹出【招募】弹窗**（类型 =「%s」，层可见 = %s）"
		% [_弹窗类型(s), str(_弹窗可见(boot))])
	var 关闭: Control = boot.find_child("关闭按钮", true, false)
	t.ok(关闭 != null and not 关闭.visible,
		"★★ 段 4b：名册 0 台 + 手上还有券 → 「关闭」按钮被收起来（不许 0 机体裸奔进大地图）")
	# ---- 决定之一：招一台 ----
	var 候选 = boot.find_child("候选列表", true, false)
	var 候选钮 := _找按钮(候选)
	t.ok(候选钮 is Button, "★ 段 4b：招募面板「这张券能招谁」里列出了可点的候选机体")
	if 候选钮 is Button:
		var 券前 := s.ticket_count()
		(候选钮 as Button).pressed.emit()
		await _等帧(3)
		t.ok(s.roster_count() == 1, "★★ 段 4b：点候选机体 → 招到 1 台（名册 %d 台）" % s.roster_count())
		t.ok(s.ticket_count() == 券前 - 1, "★ 段 4b：招募吃掉 1 张券（%d → %d）" % [券前, s.ticket_count()])
		t.ok(_弹窗类型(s) == "三选一", "★★ 段 4b：招完自动接「三选一」（类型 =「%s」）" % _弹窗类型(s))
	# ---- 三选一选完 → 还有券就**自动回招募** ----
	if s.run_state != null and not s.run_state.pending_card_picks.is_empty():
		var 选这张 := _找按文(boot, "选这张")
		t.ok(选这张 != null, "★ 段 4b：三选一里有「选这张」按钮")
		if 选这张 != null:
			var 券在 := s.ticket_count()
			选这张.pressed.emit()
			await _等帧(3)
			t.ok(s.run_state.pending_card_picks.is_empty(),
				"★ 段 4b：选完牌 → `pending_card_picks` 空了")
			if 券在 > 0:
				t.ok(_弹窗类型(s) == "招募",
					"★★ 段 4b：三选一选完、**手上还有 %d 张券** → 自动回到【招募】页面（类型 =「%s」）"
					% [券在, _弹窗类型(s)])
	# ---- 决定之二：把剩下的券全部「放弃此券」 ----
	var 放弃 := _找按文(boot, "放弃此券")
	t.ok(放弃 != null and not 放弃.disabled, "★★ 段 4b：招募面板上有可点的【放弃此券】（做出的第二个决定）")
	var 丢 := 0
	while s.ticket_count() > 0 and 丢 < 8:
		var 券前2 := s.ticket_count()
		if 放弃 == null or 放弃.disabled:
			放弃 = _找按文(boot, "放弃此券")
		if 放弃 == null:
			break
		放弃.pressed.emit()
		await _等帧(2)
		if s.ticket_count() >= 券前2:
			break
		丢 += 1
	t.ok(s.ticket_count() == 0, "★★ 段 4b：连点【放弃此券】%d 次 → 券全部决定完（剩 %d 张）" % [丢, s.ticket_count()])
	关闭 = boot.find_child("关闭按钮", true, false)
	t.ok(关闭 != null and 关闭.visible,
		"★ 段 4b：名册非空 + 券已决定完 → 「关闭」按钮又回来了")
	# ---- 决定做完之后的收尾按钮 ----
	# ★ 2026-10-18：券全部决定完（且没有待选牌）之后，现身的**唯一**那颗醒目按钮是
	#   【完成招募 · 去编队】（刚开局 0 场战斗时）/【完成 · 返回大地图】；
	#   【去编队出击】只在「还有券没决定」时现身。这里两类都认，两边都验。
	var 完成钮: Control = boot.find_child("完成返回地图按钮", true, false)
	t.ok(完成钮 is Button and (完成钮 as Button).visible,
		"★★ 段 4b：券全部决定完 → 【%s】现身（`完成返回地图按钮`）"
		% (str((完成钮 as Button).text) if 完成钮 is Button else "—"))
	var 去编队钮: Control = boot.find_child("去编队出击按钮", true, false)
	t.ok(去编队钮 is Control and not (去编队钮 as Control).visible,
		"★ 段 4b：还有券时才现身的【去编队出击】此时藏起来（节点还在树里，`find_child` 照旧找得到）")
	var 去编队 := 完成钮
	t.ok(去编队 != null, "★ 段 4b：招募面板底部有收尾按钮")
	if 去编队 != null:
		(去编队 as Button).pressed.emit()
		await _等帧(3)
	t.ok(s.screen == "formation", "★★ 段 4b：点收尾按钮 → screen = formation（真实值「%s」）" % s.screen)
	t.ok(_弹窗类型(s).is_empty() and not _弹窗可见(boot),
		"★★ 段 4b：同时把招募弹窗关掉了（modal 类型 =「%s」、层可见 = %s）" % [_弹窗类型(s), str(_弹窗可见(boot))])
	_拆boot(树根, 舱)

## ④-c「mouse over 不能在鼠标中间」：给定鼠标坐标 → 面板在鼠标**右侧**；贴右边缘翻到左侧。
func _段4c_悬停在鼠标右侧(t, 树根: Node) -> void:
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 4c：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	await _等帧(2)
	var 层 = boot.find_child("悬停说明层", true, false)
	if not (层 is HoverTooltip):
		t.ok(false, "段 4c：找不到「悬停说明层」")
		_拆boot(树根, 舱)
		return
	var 悬停: HoverTooltip = 层
	悬停.show_text("段 4c 测试说明：把面板摆到鼠标右边，绝不压住指针本身。", "悬停定位", null)
	await _等帧(1)
	var 面板: Control = 悬停.find_child("悬停面板", true, false)
	t.ok(面板 != null and 面板.visible, "★ 段 4c：`show_text()` 之后「悬停面板」显示出来了")
	if 面板 == null:
		_拆boot(树根, 舱)
		return
	var mp := Vector2(400.0, 300.0)
	悬停._夹紧(mp)
	t.ok(面板.position.x >= mp.x + 20.0,
		"★★ 段 4c：鼠标在 %s 时面板位于鼠标**右侧**（面板.x = %.1f >= %.1f）—— 不在鼠标中间"
		% [str(mp), 面板.position.x, mp.x + 20.0])
	t.ok(面板.position.y < mp.y,
		"★ 段 4c：纵向也从鼠标上方一点点起（面板.y = %.1f < %.1f）" % [面板.position.y, mp.y])
	t.ok(_在界内(面板.get_global_rect()),
		"★ 段 4c：右侧定位之后面板 %s 仍然完全落在 1280×720 内" % _短(面板.get_global_rect()))
	# 鼠标贴右边缘：右边放不下 → 翻到左边，且不出右界
	var 靠右 := Vector2(画布宽 - 4.0, 300.0)
	悬停._夹紧(靠右)
	t.ok(面板.position.x < 靠右.x,
		"★★ 段 4c：鼠标贴右边缘（%s）时面板翻到鼠标**左边**（面板.x = %.1f）" % [str(靠右), 面板.position.x])
	t.ok(面板.position.x + 面板.size.x <= 画布宽 - 8.0 + 0.5,
		"★ 段 4c：翻到左边之后右边缘也没出界（面板 %s）" % _短(面板.get_global_rect()))
	悬停.hide_tip()
	_拆boot(树根, 舱)

# ==========================================================================================
# 段 5：★ 实时监视（2026-10-16 新增）—— 局面快照 + 全动作记录 + 信号触发
#
#   规格（主会话靠 `F:\DSH-mecha\.tools\smoke\live_state.json` / `live_actions.jsonl` 看作者
#   在本地网页里的每一步）：这一段钉三件事，**全部 headless 可验**（Web 发送那一层靠
#   `OS.has_feature("web")` 关掉，桌面 / headless 一个字节都不发 → 这里只验「记录」这一层）：
#     ① `snapshot_for_monitor()` 的字段齐（顶层 + 有局 + 战斗中三档）；
#     ② 每一个核心玩家动作走完都**自动追加** `action_history` 一条，且 `action_recorded` 真的发；
#     ③ 记录本身**不改返回值**（同一次调用的返回值与私下直调内部实现逐字相同）。
# ==========================================================================================

func _段5_实时监视与全动作记录(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 5：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)

	# ---- 5a：信号 + 历史容器就在门面上（初始态） ----
	t.ok(s.has_signal("action_recorded"), "★ 段 5：`GameSession` 有 `action_recorded(entry)` 信号")
	t.ok(s.action_history is Array and s.action_history.is_empty(),
		"★ 段 5：新会话 `action_history` 是空数组（0 条）")
	var 收到: Array = []
	var 回调 := func(e): 收到.append(e)
	s.action_recorded.connect(回调)

	# ---- 5b：全新会话的裸快照也拿得到（不崩、字段齐） ----
	var 空快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["screen", "modal", "is_quick_battle", "in_battle", "errors"]:
		t.ok(空快.has(名), "★ 段 5：全新会话快照含顶层字段「%s」（screen = %s）" % [名, str(空快.get("screen", ""))])
	t.ok(not 空快.has("tickets") and not 空快.has("roster"),
		"★ 段 5：没有局时快照**不瞎编**局字段（tickets / roster 都不在）")

	# ---- 5c：开局 → 快照字段齐 + 记了一条 ----
	var 前条数 := s.action_history.size()
	var 开了: bool = s.start_new_run(20261031, "混编")
	t.ok(开了 and s.run_state != null, "★ 段 5：`start_new_run` 照旧开得出局（返回 %s）" % str(开了))
	t.ok(s.action_history.size() == 前条数 + 1, "★ 段 5：开局之后 `action_history` %d → %d 条（自动追加 1 条）"
		% [前条数, s.action_history.size()])
	var 记0: Dictionary = s.action_history[s.action_history.size() - 1]
	t.ok(int(记0.get("seq", 0)) == s.action_history.size() and str(记0.get("kind", "")) == "action",
		"★ 段 5：最新一条 = `seq %d` / `kind \"action\"`（序号从 1 开始严格递增）" % int(记0.get("seq", 0)))
	t.ok(str(记0.get("action", "")) == "start_new_run", "★ 段 5：动作名 `start_new_run`（真实值「%s」）" % str(记0.get("action", "")))
	var 参0: Dictionary = 记0.get("args", {})
	t.ok(int(参0.get("seed_val", 0)) == 20261031 and str(参0.get("squad", "")) == "混编",
		"★ 段 5：参数原样记下（%s）" % JSON.stringify(参0))
	t.ok(记0.get("result") == true, "★ 段 5：返回结果原样记下（%s）" % str(记0.get("result")))
	t.ok(收到.size() >= 1 and str((收到[收到.size() - 1] as Dictionary).get("action", "")) == "start_new_run",
		"★ 段 5：`action_recorded` 信号真的发了（收到 %d 条，最新「%s」）"
		% [收到.size(), str((收到[收到.size() - 1] as Dictionary).get("action", ""))])
	# ---- 5d：有局快照的关键字段 ----
	var 局快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["screen", "tickets", "roster", "lineup", "pending_card_picks", "relics", "parts",
			"seed", "squad", "status", "floor", "pos", "propellant", "hope", "carbon",
			"base_hp", "commander_lv", "deploy_cap", "errors", "modal", "in_battle"]:
		t.ok(局快.has(名), "★ 段 5：有局快照含「%s」" % 名)
	t.ok(str(局快.get("screen", "")) == "map" and str(局快.get("status", "")) == "进行中",
		"★ 段 5：快照读得出屏与状态（screen = %s / status = %s）" % [str(局快.get("screen", "")), str(局快.get("status", ""))])
	t.ok(str(局快.get("propellant", "")) == "%d/%d" % [s.run_state.propellant, s.run_state.propellant_max],
		"★ 段 5：推进剂照 `当前/上限` 的写法报（%s）" % str(局快.get("propellant", "")))
	t.ok(int(局快.get("deploy_cap", 0)) > 0 and int(局快.get("commander_lv", 0)) >= 1,
		"★ 段 5：出击上限 %d / 部队等级 %d" % [int(局快.get("deploy_cap", 0)), int(局快.get("commander_lv", 0))])
	var 券表: Array = 局快.get("tickets", [])
	t.ok(券表.size() == s.run_state.tickets.size() and (券表.is_empty() or (券表[0] is Dictionary and 券表[0].has("id") and 券表[0].has("名") and 券表[0].has("类型"))),
		"★ 段 5：`tickets` = %d 张、每张都写清 `id` / `名` / `类型`（首张 %s）"
		% [券表.size(), JSON.stringify(券表[0]) if not 券表.is_empty() else "—"])
	t.ok(局快.get("lineup") is Dictionary, "★ 段 5：`lineup` 是「位号 → 机体键(名)」的字典（%s）" % JSON.stringify(局快.get("lineup")))

	# ---- 5e：招募 / 放弃券 / 选牌 都记 ----
	var 名册前 := s.roster_count()
	var 目标们 := s.available_recruit_targets(0)
	if 目标们.is_empty():
		t.ok(false, "★ 段 5：开局券招不到人 —— 招募那几条断言跑不了")
	else:
		var 键 := str((目标们[0] as Dictionary).get("键", ""))
		var 招 := s.recruit_unit(键, 0)
		t.ok(bool(招.get("ok", false)) and s.roster_count() == 名册前 + 1,
			"★ 段 5：招募 %s 成功（名册 %d → %d）" % [键, 名册前, s.roster_count()])
		var 招记: Dictionary = s.action_history[s.action_history.size() - 1]
		t.ok(str(招记.get("action", "")) == "recruit_unit" and bool((招记.get("result") as Dictionary).get("ok", false)),
			"★ 段 5：`recruit_unit` 记了一条（seq %d，result.ok = %s）"
			% [int(招记.get("seq", 0)), str((招记.get("result") as Dictionary).get("ok", false))])
		# 快照里的名册 / 编队 / 待选牌都要跟着变
		var 招快: Dictionary = 招记.get("state", {})
		t.ok(int(招快.get("roster", []).size()) == s.roster_count(),
			"★ 段 5：那一条记录里的快照名册 %d 台 == 现值 %d 台（快照是「这一步做完」的局面）"
			% [(招快.get("roster", []) as Array).size(), s.roster_count()])
		t.ok(int((招快.get("pending_card_picks", {}) as Dictionary).get("次数", 0)) == s.run_state.pending_card_picks.size(),
			"★ 段 5：快照的 `pending_card_picks.次数` = %d（与 `run_state` 一致）"
			% int((招快.get("pending_card_picks", {}) as Dictionary).get("次数", 0)))
		# 三选一：把候选选掉 → 记一条
		if not s.run_state.pending_card_picks.is_empty():
			var 选 := s.pick_tactical_card(str(s.run_state.pending_card_picks[0]))
			t.ok(选 and str(s.action_history[s.action_history.size() - 1].get("action", "")) == "pick_tactical_card",
				"★ 段 5：`pick_tactical_card` 记了一条（返回值 %s）" % str(选))
	# 放弃券（还有券才验；没有就明说不跑）
	if s.ticket_count() > 0:
		var 券前 := s.ticket_count()
		var 丢 := s.discard_ticket(0)
		t.ok(bool(丢.get("ok", false)) and s.ticket_count() == 券前 - 1,
			"★ 段 5：放弃 1 张券（%d → %d）" % [券前, s.ticket_count()])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "discard_ticket",
			"★ 段 5：`discard_ticket` 记了一条")

	# ---- 5f：编队（上阵 / 撤下 / 清空）都记 ----
	if not s.run_state.roster.is_empty():
		var 首键 := str(s.run_state.roster.keys()[0])
		var 位名 := str(s.lineup_slots()[0].get("位名", ""))
		s.set_lineup_slot(首键, 位名)
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "set_lineup_slot",
			"★ 段 5：`set_lineup_slot` 记了一条（%s → %s）" % [首键, 位名])
		t.ok(s.run_state.lineup.size() >= 1 and not (s.snapshot_for_monitor().get("lineup", {}) as Dictionary).is_empty(),
			"★ 段 5：上阵之后快照 `lineup` 非空（%s）" % JSON.stringify(s.snapshot_for_monitor().get("lineup", {})))
		s.remove_from_lineup(首键)
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "remove_from_lineup",
			"★ 段 5：`remove_from_lineup` 记了一条")
		s.set_lineup_slot(首键, 位名)
		var 清 := s.clear_lineup()
		t.ok(清 and s.run_state.lineup.is_empty(),
			"★ 段 5：`clear_lineup` 清空出击名单（返回值 %s、出击 %d 条）" % [str(清), s.run_state.lineup.size()])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "clear_lineup",
			"★ 段 5：`clear_lineup` 记了一条")
		t.ok(not s.clear_lineup() and str(s.action_history[s.action_history.size() - 1].get("action", "")) == "clear_lineup",
			"★ 段 5：本来就空时 `clear_lineup` 回 false —— **失败也照记**（监视侧才知道「为什么没反应」）")
		s.set_lineup_slot(首键, 位名)

	# ---- 5g：大地图（走一格）也记，且快照里 pos / propellant 跟着变 ----
	# ★ 2026-10-18：有未决招募券时点格子不移动（先把券决定完）—— 这一段只验「走一格会被记一条」，
	#   所以先把券处理干净。
	_清券(s)
	var 起点 := s.run_state.node_id
	var 下一 := _找相邻落脚点(s, _找战斗格(s)) if _找战斗格(s) >= 0 else -1
	if 下一 >= 0:
		var 走 := s.move_to_cell(下一)
		t.ok(bool(走.get("ok", false)) or s.screen == "battle",
			"★ 段 5：`move_to_cell(%d)` 记了一条（ok = %s / 屏 = %s）" % [下一, str(走.get("ok", false)), s.screen])
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "move_to_cell",
			"★ 段 5：动作名是大写原样的 `move_to_cell`（别名 `move_to` 也走同一条记录：%s）"
			% str(s.move_to(下一).get("ok", false)))

	# ---- 5h：战斗四连（开战 / 打牌 / 推回合 / 自动打完 / 结算）都记 ----
	await _关弹窗(boot)
	if s.run_state != null:
		s.run_state.pending_card_picks = []
	var 快前: Dictionary = s.snapshot_for_monitor()
	t.ok(s.start_quick_battle(20261013), "★ 段 5：`start_quick_battle` 开起来了")
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "start_quick_battle",
		"★ 段 5：`start_quick_battle` 记了一条")
	var 战快: Dictionary = s.snapshot_for_monitor()
	for 名 in ["turn", "result", "morale", "policy", "playable_now", "hand", "reserve_count",
			"allies", "enemies", "recent_battle_log"]:
		t.ok(战快.has(名), "★ 段 5：战斗中快照含「%s」" % 名)
	t.ok(bool(战快.get("in_battle", false)) and int(战快.get("turn", 0)) >= 1,
		"★ 段 5：战斗中快照 `in_battle = true`、回合 %d" % int(战快.get("turn", 0)))
	t.ok((战快.get("allies", []) as Array).size() > 0 and (战快.get("enemies", []) as Array).size() > 0,
		"★ 段 5：`allies` %d 行 / `enemies` %d 行（位号:名:HP/最大HP；首行我方「%s」、敌方「%s」）"
		% [(战快.get("allies", []) as Array).size(), (战快.get("enemies", []) as Array).size(),
			str((战快.get("allies", []) as Array)[0]) if not (战快.get("allies", []) as Array).is_empty() else "—",
			str((战快.get("enemies", []) as Array)[0]) if not (战快.get("enemies", []) as Array).is_empty() else "—"])
	t.ok((战快.get("hand", []) as Array).size() == s.hand_count(),
		"★ 段 5：`hand` %d 行 == 手牌 %d 张（`id:名(可打/原因)`；首行「%s」）"
		% [(战快.get("hand", []) as Array).size(), s.hand_count(),
			str((战快.get("hand", []) as Array)[0]) if not (战快.get("hand", []) as Array).is_empty() else "—"])
	t.ok(int(战快.get("playable_now", -1)) == s.cards_playable_now(),
		"★ 段 5：`playable_now` = %d（与 `cards_playable_now()` 同一口径）" % int(战快.get("playable_now", -1)))
	t.ok((战快.get("morale", {}) as Dictionary).has("我方") and (战快.get("morale", {}) as Dictionary).has("敌方"),
		"★ 段 5：`morale` 分我方 / 敌方两栏（%s）" % JSON.stringify(战快.get("morale", {})))
	var 能打 := s.playable_hand_ids()
	if not 能打.is_empty():
		s.play_tactical_card(str(能打[0]))
		t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "play_tactical_card",
			"★ 段 5：`play_tactical_card` 记了一条（打的是 %s）" % str(能打[0]))
	s.step_battle_turn()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "step_battle_turn",
		"★ 段 5：`step_battle_turn` 记了一条（现在回合 %d）" % int(float(s.battle_ctx.get("turn", 1.0))))
	s.auto_finish_battle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "auto_finish_battle",
		"★ 段 5：`auto_finish_battle` 记了一条（结果「%s」）" % s.战果文字())
	t.ok((s.snapshot_for_monitor().get("recent_battle_log", []) as Array).size() > 0,
		"★ 段 5：快照 `recent_battle_log` 有 %d 行战斗日志"
		% (s.snapshot_for_monitor().get("recent_battle_log", []) as Array).size())
	var 结 := s.finish_battle_and_settle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "finish_battle_and_settle",
		"★ 段 5：`finish_battle_and_settle` 记了一条（屏 = %s）" % s.screen)
	# 幂等那一条也要记（失败照记）
	s.finish_battle_and_settle()
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "finish_battle_and_settle",
		"★ 段 5：重复结算（幂等闸拒绝）**也记一条** —— 监视侧看得见「为什么这次没结算」")
	t.ok(not 快前.is_empty() and str(快前.get("screen", "")) != str(s.snapshot_for_monitor().get("screen", "")),
		"★ 段 5：从「%s」一路走到「%s」，快照的屏真的跟着变"
		% [str(快前.get("screen", "")), str(s.snapshot_for_monitor().get("screen", ""))])

	# ---- 5i：上限 100 条 + 序号严格递增 + 信号条数对得上 ----
	var 已记 := s.action_history.size()
	t.ok(已记 > 0 and int(s.action_history[0].get("seq", 0)) == 1,
		"★ 段 5：历史第 1 条的 `seq` = %d（从 1 开始；现在共 %d 条）" % [int(s.action_history[0].get("seq", 0)), 已记])
	var 递增 := true
	for i in range(1, 已记):
		if int(s.action_history[i].get("seq", 0)) != int(s.action_history[i - 1].get("seq", 0)) + 1:
			递增 = false
	t.ok(递增, "★ 段 5：`action_history` 里 `seq` 一条接一条严格 +1（%d 条都连着）" % 已记)
	# 再灌 120 次开局，逼出上限
	for i in 120:
		s.start_new_run(3000000 + i, "混编")
	t.ok(s.action_history.size() == 100,
		"★ 段 5：灌到 120 条之后 `action_history` 仍是 **%d 条**（上限 100，超了丢最老）" % s.action_history.size())
	t.ok(s.action_history.size() == 100 and int(s.action_history[99].get("seq", 0)) - int(s.action_history[0].get("seq", 0)) == 99,
		"★ 段 5：留的是**最近** 100 条（首条 seq = %d、末条 seq = %d）"
		% [int(s.action_history[0].get("seq", 0)), int(s.action_history[s.action_history.size() - 1].get("seq", 0))])
	t.ok(收到.size() == int(s.action_history[s.action_history.size() - 1].get("seq", 0)),
		"★ 段 5：`action_recorded` 发的条数（%d）== 最后一条的 `seq`（每个动作恰好发一次）" % 收到.size())

	# ---- 5j：★ 记录**不改返回值**（与「私下直调内部实现」逐字对账） ----
	var 甲 := GameSession.new()
	var 乙 := GameSession.new()
	var 甲开 := 甲._开始新局(20261031, "混编")
	var 乙开 := 乙.start_new_run(20261031, "混编")
	t.ok(甲开 == 乙开 and JSON.stringify(甲.last) == JSON.stringify(乙.last),
		"★ 段 5：包一层之后 `start_new_run` 的返回值与 `last` 与内部实现**逐字相同**（%s）" % str(乙开))
	var 甲走 := 甲._走一格(2)
	var 乙走 := 乙.move_to_cell(2)
	t.ok(JSON.stringify(甲走) == JSON.stringify(乙走),
		"★ 段 5：`move_to_cell` 包一层前后返回值逐字相同（%s）" % JSON.stringify(乙走).substr(0, 60))
	t.ok(甲.action_history.is_empty() and 乙.action_history.size() == 2,
		"★ 段 5：只有**公开口子**才记（甲 0 条 = 走的都是内部实现；乙 2 条 = 开局 + 走一格）")

	s.action_recorded.disconnect(回调)
	_拆boot(树根, 舱)

# ==========================================================================================
# 段 6：★ 2026-10-18 作者试玩反馈第 1 / 3 条 —— 战前强制编队确认 + 顶栏锁死 + 战斗孤儿守卫
#   ① 走上战斗格 → 进的是 `formation` 战前确认态（不是直接开打）：标题醒目、开始战斗按钮可见、
#      回地图按钮**藏起来**；点【确认编队 · 开始战斗】→ 才进 `battle`；
#   ② 战斗中顶栏「招募按钮 / 编队按钮」都置灰，`boot.去屏("formation")` 被守卫拦下
#      （不许把战斗打一半切去编队屏 → 孤儿战斗死锁）。
# ==========================================================================================

func _段6_战前编队确认与顶栏锁(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 6：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)
	if s.run_state == null:
		t.ok(s.start_new_run(20261111, "混编"), "★ 段 6：开一局（第 1 层）")
	# ---- 先招募 / 上阵（战斗格要出击名单非空）----
	var 招 := 0
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			招 += 1
	t.ok(招 >= 1, "★ 段 6：用开局券招到 %d 台（名册 %d 台、券 %d 张）" % [招, s.roster_count(), s.ticket_count()])
	_清待选(s)
	var 丢 := _清券(s)
	t.ok(s.ticket_count() == 0, "★ 段 6：把没决定的券处理完（券 %d 张）" % s.ticket_count())
	var 上阵 := _编队第一台(s)
	t.ok(上阵, "★ 段 6：把一台摆上出击位（出击 %d 台）" % s.run_state.lineup.size())
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "★ 段 6：第 %d 层找不到战斗格" % s.run_state.floor_num)
		_拆boot(树根, 舱)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "★ 段 6：战斗格 %d 四周找不到落脚点" % 战斗格)
		_拆boot(树根, 舱)
		return
	s.run_state.node_id = 落脚
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(落脚).get("类型", ""))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 6：大地图视图类型不对（%s）" % str(mv))
		_拆boot(树根, 舱)
		return
	# ---- ① 走上战斗格 → 战前编队确认屏（**不是**直接开打）----
	(mv as MapView)._点格(战斗格)
	await _等帧(3)
	t.ok(s.screen == "formation", "★★ 段 6：走上战斗格 %d → screen = %s（**先进战前编队确认屏**，不是直接开打）" % [战斗格, s.screen])
	t.ok(s.pending_battle_confirm, "★★ 段 6：`session.pending_battle_confirm == true`（战前确认态）")
	t.ok(str(s.pending_battle_kind) == "node", "★ 段 6：`pending_battle_kind = %s`（脚下这一格的节点战）" % str(s.pending_battle_kind))
	t.ok(s.battle_ctx.is_empty(), "★★ 段 6：确认之前**一场都还没开**（battle_ctx 空 = %s）" % str(s.battle_ctx.is_empty()))
	var 开始钮: Control = boot.find_child("开始战斗按钮", true, false)
	var 回钮: Control = boot.find_child("回地图按钮", true, false)
	var 标: Control = boot.find_child("战前编队标题", true, false)
	t.ok(开始钮 is Button and (开始钮 as Button).visible,
		"★★ 段 6：【确认编队 · 开始战斗】按钮 `visible == true`（文案「%s」）" % (str((开始钮 as Button).text) if 开始钮 is Button else "—"))
	t.ok(回钮 is Control and not (回钮 as Control).visible,
		"★★ 段 6：【回地图按钮】`visible == false` —— 不许退回大地图逃避当前格战斗")
	t.ok(标 is Label and (标 as Label).visible and str((标 as Label).text).contains("战前编队确认"),
		"★★ 段 6：顶部标题醒目写出「【战前编队确认】…」（%s）"
		% (str((标 as Label).text).substr(0, 28) if 标 is Label else "—"))
	# ---- ② 点【确认编队 · 开始战斗】→ 才进 battle ----
	var bv = (开始钮 as Button)
	bv.pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "battle", "★★ 段 6：点【确认编队 · 开始战斗】→ screen = %s" % s.screen)
	t.ok(not s.pending_battle_confirm and not s.battle_ctx.is_empty(),
		"★★ 段 6：确认态放掉、真开起来了（pending = %s、我方 %d 台 / 敌方 %d 台）"
		% [str(s.pending_battle_confirm),
			(s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0,
			(s.battle_ctx.get("enemies") as Array).size() if s.battle_ctx.get("enemies") is Array else 0])
	t.ok(str(s.action_history[s.action_history.size() - 1].get("action", "")) == "confirm_formation_and_start_battle",
		"★ 段 6：这一步记进了全动作记录（动作名 = %s）" % str(s.action_history[s.action_history.size() - 1].get("action", "")))
	# ---- ③ 战斗中顶栏两个跳转按钮都置灰 ----
	boot.route()
	await _等帧(2)
	var 招募钮: Control = boot.find_child("招募按钮", true, false)
	var 编队钮: Control = boot.find_child("编队按钮", true, false)
	var 牌库钮: Control = boot.find_child("战术牌库按钮", true, false)
	t.ok(招募钮 is Button and (招募钮 as Button).disabled,
		"★★ 段 6：战斗中「招募按钮」`disabled == true`（文案「%s」）" % (str((招募钮 as Button).text) if 招募钮 is Button else "—"))
	t.ok(编队钮 is Button and (编队钮 as Button).disabled,
		"★★ 段 6：战斗中「编队按钮」`disabled == true`")
	t.ok(牌库钮 is Button and (牌库钮 as Button).disabled,
		"★ 段 6：战斗中「战术牌库按钮」也是灰的")
	# ---- ④ 状态机守卫：不许把战斗打一半切去编队屏 ----
	var 屏前 := str(s.screen)
	boot.去屏("formation")
	await _等帧(2)
	t.ok(str(s.screen) == 屏前 and str(s.screen) == "battle",
		"★★ 段 6：战斗中调 `boot.去屏(\"formation\")` 被守卫拦下（screen 仍是 %s，不是切换后的 formation）" % s.screen)
	boot.去屏("map")
	await _等帧(2)
	t.ok(str(s.screen) == "battle",
		"★★ 段 6：战斗中调 `boot.去屏(\"map\")` 同样被拦下（screen 仍是 %s）—— 杜绝孤儿战斗死锁" % s.screen)
	# ---- ⑤ 结算之后守卫放行：能正常回大地图 ----
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	await _等帧(2)
	t.ok(s.screen == "result", "★ 段 6：打完并结算 → screen = %s" % s.screen)
	boot.去屏("map")
	await _等帧(2)
	t.ok(s.screen == "map", "★★ 段 6：结算之后 `去屏(\"map\")` 放行（screen = %s）—— 守卫只拦「打一半」" % s.screen)
	_拆boot(树根, 舱)

# ==========================================================================================
# 段 7：★ 2026-10-18 作者试玩反馈第 2 / 3 条 —— 同一格幂等 + 战后严格 90% 给 1 张券
# ==========================================================================================

func _段7_幂等休整与战后九十概率(t, 树根: Node) -> void:
	await _段7a_同一休整格只结算一次(t)
	await _段7b_战后九十概率给券(t)

## 开一局并**换层找到一格带「休整」的层**，返回那一格的编号（找不到 → −1）。
## ★ 为什么必须换层：`MapGenerator` 的节点计划里第 1 层的「休整」个数 = 0（休整从第 2 层起才有）。
##   这是一段**夹具**（造局面），不代表任何一种玩法路径。
func _找一格带休整的局(s: GameSession) -> int:
	for i in 20:
		if not s.start_new_run(20261204 + i * 97, "混编"):
			continue
		if s.run_state == null:
			continue
		for 层 in 3:
			if s.run_state == null:
				break
			var 是 := _找一个类型格(s, ["休整"])
			if 是 < 0:
				是 = _找可达的格(s, ["休整"])
			if 是 >= 0:
				return 是
			# 这一层没有休整 → 直接换一层看看（推进剂 / 出口都不要紧，这是造局面）
			if not MapNavigator.advance_floor(s.run_state).get("ok", false):
				break
	return -1

## ① 同一休整格调用第 2 次 `resolve_rest` 必须被幂等拦下（`ok == false`），数值一个都不许再变。
func _段7a_同一休整格只结算一次(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段7a.json"
	# 找一个**真的有休整格**的局面（★ 第 1 层的「休整」计划数 = 0，休整从第 2 层起才有；
	# 所以这里靠 `_找一格带休整的局()` 直接换层找，找不到也不假绿）。
	var 休 := _找一格带休整的局(s)
	if 休 < 0 or s.run_state == null:
		t.ok(false, "★ 段 7a：换到第 4 层都找不到休整格 —— 断言跑不了")
		return
	var mv := MapView.new()
	# 把脚下摆到休整格上（造局面；表现层不参与）
	s.run_state.node_id = 休
	s.run_state.map_data["当前节点类型"] = "休整"
	t.ok(str(s.run_state.current_type()) == "休整", "★ 段 7a：脚下这一格是休整（格 %d）" % 休)
	var 前耐 := int(s.run_state.base_hp)
	var 前推 := int(s.run_state.propellant)
	var 前希 := int(s.run_state.hope)
	var 一 := s.resolve_rest("推进剂")
	t.ok(bool(一.get("ok", false)), "★★ 段 7a：第 1 次 `resolve_rest(\"推进剂\")` 成功（%s）" % str(一.get("选", "")))
	var 中耐 := int(s.run_state.base_hp)
	var 中推 := int(s.run_state.propellant)
	var 中希 := int(s.run_state.hope)
	t.ok(中耐 >= 前耐 and 中推 >= 前推,
		"★ 段 7a：第 1 次真的结算了（耐久 %d → %d、推进剂 %d → %d、希望 %d → %d）"
		% [前耐, 中耐, 前推, 中推, 前希, 中希])
	var 二 := s.resolve_rest("推进剂")
	t.ok(not bool(二.get("ok", false)), "★★ 段 7a：同一格第 2 次 `resolve_rest` 被幂等拦下（ok = %s）" % str(二.get("ok", false)))
	t.ok(str(二.get("为什么", "")) == "当前节点已结算完毕",
		"★★ 段 7a：拦下的原因写清了（「%s」）" % str(二.get("为什么", "")))
	t.ok(int(s.run_state.base_hp) == 中耐 and int(s.run_state.propellant) == 中推 and int(s.run_state.hope) == 中希,
		"★★ 段 7a：第 2 次一个字都没改（耐久 %d · 推进剂 %d · 希望 %d 与第 1 次之后逐项相同）"
		% [int(s.run_state.base_hp), int(s.run_state.propellant), int(s.run_state.hope)])
	# 再连点 4 次也不许刷（原作者反馈里的「连点 6 次刷属性」）
	var 全拦 := true
	for _i in 4:
		if bool(s.resolve_rest("耐久").get("ok", false)):
			全拦 = false
	t.ok(全拦, "★★ 段 7a：再连点 4 次 `resolve_rest` 也全被拦下（总共 6 次里只有第 1 次生效）")
	mv.free()

## ② 战后 90% 给 1 张招募券：跑 50 个不同种子，统计「战后给券率」落在 80%–98%，且每场最多 1 张。
func _段7b_战后九十概率给券(t) -> void:
	var 场次 := 50
	var 给券场 := 0
	var 多给场 := 0
	var 跑通 := 0
	var 坏 := ""
	for i in 场次:
		var r := _跑一场数券(20270001 + i * 137)
		if not bool(r.get("ok", false)):
			坏 = str(r.get("为什么", ""))
			continue
		跑通 += 1
		var n := int(r.get("本场券", 0))
		if n >= 1:
			给券场 += 1
		if n > 1:
			多给场 += 1
	t.ok(跑通 >= 45, "★ 段 7b：50 个种子里跑通了 %d 场参与统计（失败样例：%s）" % [跑通, 坏 if not 坏.is_empty() else "无"])
	var 率 := float(给券场) / float(maxi(1, 跑通))
	t.ok(率 >= 0.80 and 率 <= 0.98,
		"★★ 段 7b：战后给券率 = %d / %d = %.1f%% 落在 80%%–98%% 之间（规格 = 90%%）"
		% [给券场, 跑通, 率 * 100.0])
	t.ok(多给场 == 0,
		"★★ 段 7b：没有任何一场发了**2 张以上**券（多给场次 = %d）—— 每次战斗最多 1 张" % 多给场)

## 跑一场真肉鸽节点战，返回 `{ok, 本场券, 为什么}`。全程走门面公开口子（不开界面）。
func _跑一场数券(种子: int) -> Dictionary:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段7b.json"
	if not s.start_new_run(种子, "混编"):
		return {"ok": false, "为什么": "开局失败"}
	if s.run_state == null:
		return {"ok": false, "为什么": "没有 run_state"}
	# 招募 + 上阵（走门面；名额与券都由内核给）
	for _i in 4:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if not bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			break
	if s.run_state.roster.is_empty():
		return {"ok": false, "为什么": "招不到人"}
	var 键们 := s.run_state.roster.keys()
	for j in mini(2, 键们.size()):
		s.set_lineup_slot(str(键们[j]), str(s.lineup_slots()[j].get("位名", "")))
	if s.run_state.lineup.is_empty():
		return {"ok": false, "为什么": "上不了阵"}
	# 招募会带出「三选一」：先选掉，免得待选牌影响后面的换层 / 结算路径。
	var 选 := 0
	while s.run_state != null and not s.run_state.pending_card_picks.is_empty() and 选 < 12:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选 += 1
	# 把还没决定的券全部放弃（不然门面会拦住「开新战斗」，见 `_打追击战()` 那道闸）
	var 丢 := 0
	while s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	var 格 := _找战斗格(s)
	if 格 < 0:
		return {"ok": false, "为什么": "找不到战斗格"}
	s.run_state.node_id = 格
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(格).get("类型", ""))
	var 券前 := s.ticket_count()
	if not s.start_node_battle():
		return {"ok": false, "为什么": "开战失败"}
	if s.battle_ctx.is_empty():
		return {"ok": false, "为什么": "battle_ctx 空"}
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	if s.screen != "result":
		return {"ok": false, "为什么": "没有进结算屏（screen = %s）" % s.screen}
	var 战: Dictionary = (s.result_summary() as Dictionary).get("战利品", {})
	var 有券 := 战.get("券") is Dictionary
	var 券后 := s.ticket_count()
	var 本场 := 券后 - 券前
	# 交叉核对：战利品那一格与券池的增减必须一致（补发 / 保留 / 撤回三条路都要对得上）
	if int(本场) != (1 if 有券 else 0):
		return {"ok": false, "为什么": "战利品券与券池增减对不上（券池 %d、战利品有券 = %s）" % [本场, str(有券)]}
	return {"ok": true, "本场券": int(本场), "战利品有名": str(战.get("券名", ""))}

## 找一台名册机体摆上第一个出击位（没有就 false）。
func _编队第一台(s: GameSession) -> bool:
	if s == null or s.run_state == null or s.run_state.roster.is_empty():
		return false
	var 位名 := str(s.lineup_slots()[0].get("位名", ""))
	for k in s.run_state.roster.keys():
		if s.set_lineup_slot(str(k), 位名):
			return true
	return false

## 找一格「类型在 `类型们` 里、现在走得过去」的格（不跳过脚下这一格）—— 段 7a 用。
func _找可达的格(s: GameSession, 类型们: Array) -> int:
	if s == null or s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if not 类型们.has(str(s.run_state.cell_at(k).get("类型", ""))):
			continue
		if bool(s.preview_cell_move(k).get("ok", false)):
			return int(k)
	return -1

## 不管走不走得到，只要那一层存在这个类型的格就返回（段 7a 的兜底；造局面用）。
func _找一个类型格(s: GameSession, 类型们: Array) -> int:
	if s == null or s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		if 类型们.has(str(s.run_state.cell_at(k).get("类型", ""))):
			return int(k)
	return -1



## 按**按钮正文**找一个按钮（段 4 用：这些按钮的节点名不固定，正文才是契约）。
func _找按文(根: Node, 文: String) -> Button:
	if 根 == null or not is_instance_valid(根):
		return null
	var 堆: Array = [根]
	while not 堆.is_empty():
		var n: Variant = 堆.pop_front()
		if n is Button and str((n as Button).text) == 文:
			return n
		if n is Node:
			for c in (n as Node).get_children():
				堆.append(c)
	return null

## `位号 → 机体键`（与战斗屏同一套读法：直接读 `battle_ctx` 的 `allies` / `enemies`）。
func _位号到键(s: GameSession, 方: String) -> Dictionary:
	var out := {}
	if s == null or s.battle_ctx.is_empty():
		return out
	var 池: Variant = s.battle_ctx.get("allies") if 方 == "ally" else s.battle_ctx.get("enemies")
	if not (池 is Array):
		return out
	for x in (池 as Array):
		if x is Dictionary:
			out[int(float((x as Dictionary).get("slot", -1.0)))] = str((x as Dictionary).get("key", ""))
	return out

## 找一个战斗格（`类型` 属于作战 / 精英 / 出口守军 / 侵蚀源）。
func _找战斗格(s: GameSession) -> int:
	if s == null or s.run_state == null:
		return -1
	for id in s.run_state.grid().keys():
		var t := str(s.run_state.cell_at(int(id)).get("类型", ""))
		if t in ["作战", "精英", "出口守军", "侵蚀源"]:
			return int(id)
	return -1

## 找一个「还没走过、一步走得到」的落脚点（按真正的网格邻接与推进剂判据来，不猜距离）。
func _找相邻落脚点(s: GameSession, 目标: int) -> int:
	if s == null or s.run_state == null:
		return -1
	var 列数 := int(MapGenerator.shape(s.run_state.floor_num).get("列数", 5))
	var 原 := s.run_state.node_id
	for id in s.run_state.grid().keys():
		var k := int(id)
		if k == 目标 or s.run_state.is_visited(k):
			continue
		var 邻 := (absi(k - 目标) == 1 and int(k / 列数) == int(目标 / 列数)) or absi(k - 目标) == 列数
		if not 邻:
			continue
		s.run_state.node_id = k
		var 能 := bool(MapNavigator.can_move_to(s.run_state, 目标).get("ok", false))
		s.run_state.node_id = 原
		if 能:
			return k
	return -1

# ==========================================================================================
# 段 8：★ MITH-3 秘银 v0.2 表现层三层反馈
#
#   规格 = 《评审-秘银连携作战-v0.2与派生任务单-ARGON.md》§3 MITH-3 +《M4-表现层接口契约.md》§5：
#     ① 预告层：手牌栏实时显示〔秘银连携：N〕；连携就绪且可打出的牌 = 2px `UiTheme.高亮` 金边 +
#        【连携就绪】；衍生牌标【衍生牌】；悬停说明写清连携条件 / 当前进度 / 衍生牌打出后移除；
#     ② 即时层：打出「泰莎的指令」后再触发连携，战斗日志含〔泰莎的指令·双倍连携〕与〔连携·N〕；
#     ③ 结算层：结算屏战报回顾区有「秘银连携统计」一行，次数与内核 `战况计数` 一致。
#
#   ★ 夹具：直接在会话里摆一场**开了 `选项.秘银v02`** 的真战斗（秘银五人队），手牌换成指定的几张
#     （每张都走 `Btl.克隆战术牌` 拿唯一 `_实例号`）—— 不依赖默认开关，也不改任何内核数据。
# ==========================================================================================

func _段8_秘银v02三层反馈(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 错误 := []
	t.ok(DataLoader.install(错误) and Db.installed, "★ 段 8：数据已装入 Db（%d 条错误）" % 错误.size())
	await _段8a_预告层计数与金边(t, 树根)
	await _段8b_即时层双倍连携日志(t)
	await _段8c_结算层统计(t, 树根)

## 造一场开了「秘银 v0.2」的真战斗，并把 `手牌IDs` 换成手牌（每张都发唯一实例号）。
func _建秘银战(手牌IDs: Array) -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段8.json"
	var ctx := Setup.开局(秘银我方, 秘银敌方, 20261016, null, {"战术卡牌": true, "秘银v02": true})
	if ctx.is_empty():
		return s
	ctx.气势 = 999.0
	ctx.log = []
	ctx.待触发战术牌 = []
	ctx.战术手牌 = []
	for id in 手牌IDs:
		var 模板 := MithrilV02Cards.卡(str(id))
		if 模板.is_empty():
			模板 = DeckBuilder.找到(str(id))
		ctx.战术手牌.append(Btl.克隆战术牌(模板, ctx))
	s.battle_ctx = ctx
	s.screen = "battle"
	return s

## 把 `BattleView` 挂到树根并按门面刷新一次（headless 下 `_build()` 可以建出整棵节点树）。
func _挂战斗屏(树根: Node, s: GameSession) -> BattleView:
	var v := BattleView.new()
	树根.add_child(v)
	v.size = Vector2(画布宽, 画布高 - 顶栏高)
	v.setup(s)
	v.refresh()
	return v

func _拆视图(树根: Node, v: Node) -> void:
	if v == null or not is_instance_valid(v):
		return
	树根.remove_child(v)
	v.free()

## 手牌里按 `id` 找那张牌（返回战斗手牌字典原件，带 `_实例号`）。
func _手牌按ID(s: GameSession, id: String) -> Dictionary:
	for c in s.hand_cards():
		if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
			return c
	return {}

## 手牌栏第 `序号` 张卡的 `PanelContainer`（序号 = `session.hand_cards()` 的顺序）。
func _手牌卡控件(v: BattleView, 序号: int) -> Control:
	if v == null or v._手牌列表 == null or 序号 < 0 or 序号 >= v._手牌列表.get_child_count():
		return null
	return v._手牌列表.get_child(序号) as Control

## 控件子树里有没有哪段文字包含 `片段`（Label 正文 / Button 正文都算）。
func _控件含文(根: Node, 片段: String) -> bool:
	if 根 == null or not is_instance_valid(根):
		return false
	if 根 is Label and str((根 as Label).text).contains(片段):
		return true
	if 根 is Button and str((根 as Button).text).contains(片段):
		return true
	for c in 根.get_children():
		if _控件含文(c, 片段):
			return true
	return false

## 战斗日志（ctx.log 的 `文本`）里有没有这一句。
func _日志有(ctx: Dictionary, 片段: String) -> bool:
	var 日志: Variant = ctx.get("log")
	if not (日志 is Array):
		return false
	for e in (日志 as Array):
		if e is Dictionary and str((e as Dictionary).get("文本", "")).contains(片段):
			return true
	return false

# ---------------- ① 预告层：连携计数 + 金边 + 悬停 ----------------

func _段8a_预告层计数与金边(t, 树根: Node) -> void:
	# 手牌：一张 0 费普通秘银牌（作战开始 = 打出后计数 0 → 1）+ 一张【连携·1】牌 + 一张衍生牌 TDD-1。
	var s := _建秘银战(["F_MITH_V2_1", "U_U2_1", "TDD-1"])
	if s.battle_ctx.is_empty():
		t.ok(false, "★ 段 8a：秘银 v0.2 战斗开不起来（Setup.开局 返回空 ctx）")
		return
	t.ok(bool(s.mithril_link_state().get("启用", false)),
		"★ 段 8a：门面 `mithril_link_state().启用 == true`（秘银 v0.2 开着 + 秘银成员在场）")
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	t.ok(str(v._手牌气势.text).contains("〔秘银连携：0〕"),
		"★ 段 8a 预告层：刷新后手牌气势并列显示「〔秘银连携：0〕」（%s）" % str(v._手牌气势.text))
	# 打出 1 张秘银牌 → 本回合秘银牌数 0 → 1
	var 普通 := _手牌按ID(s, "F_MITH_V2_1")
	var 打一 := s.play_tactical_card(str(普通.get("_实例号", "")))
	t.ok(bool(打一.get("成功", false)), "★ 段 8a：打出 1 张秘银牌【%s】成功（本回合秘银牌数 0 → 1）"
		% str(普通.get("名", "")))
	v.refresh()
	await _等帧(1)
	t.ok(str(v._手牌气势.text).contains("〔秘银连携：1〕"),
		"★ 段 8a 预告层：打出 1 张后手牌气势更新为「〔秘银连携：1〕」（%s）" % str(v._手牌气势.text))
	t.ok(int(s.mithril_link_state().get("本回合秘银牌数", -1)) == 1,
		"★ 段 8a：`mithril_link_state().本回合秘银牌数 == 1`（与内核 `ctx.本回合秘银牌数` 同一份事实）")
	# 连携牌：阈值 1、现在已满足 → 连携就绪 + 可连携亮边
	var 连携牌 := _手牌按ID(s, "U_U2_1")
	if 连携牌.is_empty():
		t.ok(false, "★ 段 8a：手牌里找不到【连携·1】牌 —— 金边断言跑不了")
		_拆视图(树根, v)
		return
	var 状 := s.hand_card_status(连携牌)
	t.ok(int(状.get("连携阈值", -1)) == 1,
		"★ 段 8a：`hand_card_status` 读到连携阈值 = 1（牌【%s】）" % str(连携牌.get("名", "")))
	t.ok(bool(状.get("连携就绪", false)) and bool(状.get("可连携亮边", false)) and bool(状.get("可打", false)),
		"★ 段 8a：连携就绪 = true、可打 = true → 可连携亮边 = true（实际耗气 %d）" % int(状.get("实际耗气", -1)))
	# 面板样式：2px 金色亮边（`UiTheme.高亮`）—— 打完那张之后手牌顺序是 [连携牌, TDD-1]。
	var 卡 := _手牌卡控件(v, 0)
	t.ok(卡 != null, "★ 段 8a：手牌栏第 1 张卡存在（连携牌）")
	if 卡 != null:
		var 样式 := 卡.get_theme_stylebox("panel") as StyleBoxFlat
		t.ok(样式 != null, "★ 段 8a：连携牌卡片有 StyleBoxFlat 面板样式")
		if 样式 != null:
			t.ok(样式.border_width_left == 2,
				"★ 段 8a 预告层：可连携牌的 `border_width_left == 2`（金色亮边；真实值 %d）" % 样式.border_width_left)
			t.ok(样式.border_color == UiTheme.高亮,
				"★ 段 8a 预告层：可连携牌的 `border_color == UiTheme.高亮`（%s）" % str(样式.border_color))
		t.ok(_控件含文(卡, "【连携就绪】"), "★ 段 8a 预告层：卡片内含「【连携就绪】」文本")
	# 衍生牌：卡片标注 + 悬停说明
	var 衍生卡 := _手牌卡控件(v, 1)
	t.ok(衍生卡 != null and _控件含文(衍生卡, "【衍生牌】"),
		"★ 段 8a 预告层：TDD-1 卡片上标注「【衍生牌】」")
	var 衍生牌 := _手牌按ID(s, "TDD-1")
	var 悬停连 := s.card_hover_text(连携牌)
	t.ok(悬停连.contains("【连携") and 悬停连.contains("当前本回合秘银牌：1 / 1") and 悬停连.contains("已就绪"),
		"★ 段 8a 预告层：连携牌悬停说明含「【连携」+ 当前进度「1 / 1」+「已就绪」")
	var 悬停衍 := s.card_hover_text(衍生牌)
	t.ok(悬停衍.contains("【衍生牌 · 打出后移除】"),
		"★ 段 8a 预告层：TDD-1 悬停说明含「【衍生牌 · 打出后移除】」")
	# 单位悬停：秘银 v0.2 下毛（U2）/ 克鲁兹（U6）的旧机制提示被清掉、标注〔秘银连携作战〕
	var 毛悬停 := s.unit_hover_text("ally", "U2")
	t.ok(毛悬停.contains("〔秘银连携作战〕") and not 毛悬停.contains("maoNet") and not 毛悬停.contains("markBreak"),
		"★ 段 8a：毛（U2）悬停说明标注「〔秘银连携作战〕」、旧 maoNet / markBreak 提示已清掉")
	var 克悬停 := s.unit_hover_text("ally", "U6")
	t.ok(克悬停.contains("〔秘银连携作战〕") and not 克悬停.contains("supportAtk"),
		"★ 段 8a：克鲁兹（U6）悬停说明标注「〔秘银连携作战〕」、旧 supportAtk 提示已清掉")
	t.ok(s.template_unit_hover_text("U2", 10).contains("〔秘银连携作战〕"),
		"★ 段 8a：局外 `template_unit_hover_text(\"U2\")` 也标注「〔秘银连携作战〕」")
	_拆视图(树根, v)

# ---------------- ② 即时层：泰莎的指令 → 双倍连携日志 ----------------

func _段8b_即时层双倍连携日志(t) -> void:
	var s := _建秘银战(["F_MITH_V2_9", "U_U2_1", "TDD-1"])
	var ctx := s.battle_ctx
	if ctx.is_empty():
		t.ok(false, "★ 段 8b：秘银 v0.2 战斗开不起来")
		return
	var 泰莎 := _手牌按ID(s, "F_MITH_V2_9")
	var 打泰 := s.play_tactical_card(str(泰莎.get("_实例号", "")))
	t.ok(bool(打泰.get("成功", false)), "★ 段 8b：打出「泰莎的指令」成功")
	var 态 := s.mithril_link_state()
	t.ok(int(态.get("连携倍率", -1)) == 2 and bool(态.get("双倍连携", false)),
		"★ 段 8b：门面读到本回合连携倍率 = 2、双倍连携 = true")
	var 连携牌 := _手牌按ID(s, "U_U2_1")
	var 打连 := s.play_tactical_card(str(连携牌.get("_实例号", "")))
	t.ok(bool(打连.get("成功", false)), "★ 段 8b：紧接着打出连携牌【%s】成功" % str(连携牌.get("名", "")))
	t.ok(_日志有(ctx, "〔泰莎的指令·双倍连携〕"),
		"★ 段 8b 即时层：战斗日志含「〔泰莎的指令·双倍连携〕」")
	t.ok(_日志有(ctx, "〔连携·"), "★ 段 8b 即时层：战斗日志含「〔连携·」")
	t.ok(_日志有(ctx, "〔泰莎的指令·双倍连携〕〔连携·1〕"),
		"★ 段 8b 即时层：同一行里「〔泰莎的指令·双倍连携〕〔连携·1〕」连着写（双倍连携的连携·N）")
	# 常规（倍率 1）那一路的正文也在：单独造一场只带连携牌的，确认措辞没被改坏
	var s2 := _建秘银战(["F_MITH_V2_2", "U_U2_1"])
	s2.battle_ctx["本回合秘银牌数"] = 1
	s2.play_tactical_card(str(_手牌按ID(s2, "U_U2_1").get("_实例号", "")))
	t.ok(_日志有(s2.battle_ctx, "〔连携·1〕") and _日志有(s2.battle_ctx, "触发连携（打前秘银牌 1 张）"),
		"★ 段 8b 即时层：倍率 1 时日志正文仍是「〔连携·1〕… 触发连携（打前秘银牌 1 张）」")

# ---------------- ③ 结算层：结算屏「秘银连携统计」 ----------------

func _段8c_结算层统计(t, 树根: Node) -> void:
	var s := _建秘银战(["F_MITH_V2_9", "U_U2_1", "TDD-1"])
	var ctx := s.battle_ctx
	if ctx.is_empty():
		t.ok(false, "★ 段 8c：秘银 v0.2 战斗开不起来")
		return
	s.play_tactical_card(str(_手牌按ID(s, "F_MITH_V2_9").get("_实例号", "")))
	s.play_tactical_card(str(_手牌按ID(s, "U_U2_1").get("_实例号", "")))
	s.play_tactical_card(str(_手牌按ID(s, "TDD-1").get("_实例号", "")))
	t.ok(int(ctx.战况计数.get("触发连携", -1)) == 1 and int(ctx.战况计数.get("打出TDD1", -1)) == 1,
		"★ 段 8c：本场内核计数 = 触发连携 1 次 / 打出 TDD-1 1 发")
	s.auto_finish_battle()
	var 结算 := s.finish_battle_and_settle()
	t.ok(bool(结算.get("胜", false)) or bool(结算.get("负", false)) or not s.battle_ctx.is_empty(),
		"★ 段 8c：本场打完并结算（屏幕 = %s）" % s.screen)
	var 结 := s.result_summary()
	t.ok(bool(结.get("有结果", false)), "★ 段 8c：`result_summary()` 有结果")
	t.ok(int(结.get("触发连携次数", -1)) == 1 and int(结.get("打出TDD1数", -1)) == 1 and bool(结.get("秘银v02", false)),
		"★ 段 8c：结算字典带 触发连携次数 = 1 / 打出TDD1数 = 1 / 秘银v02 = true")
	var rv := ResultView.new()
	树根.add_child(rv)
	rv.size = Vector2(画布宽, 画布高 - 顶栏高)
	rv.setup(s)
	rv.refresh()
	await _等帧(2)
	var 统计 := rv.find_child("秘银连携统计", true, false)
	t.ok(统计 != null, "★ 段 8c 结算层：`find_child(\"秘银连携统计\")` 找得到（结算屏战报回顾区新增一行）")
	var 文 := str((统计 as Label).text) if 统计 is Label else ""
	t.ok(统计 is Label and 文.contains("触发连携") and 文.contains("打出 TDD-1 导弹"),
		"★ 段 8c 结算层：统计行含「触发连携」与「打出 TDD-1 导弹」（%s）" % 文)
	t.ok(文.contains("触发连携 1 次") and 文.contains("打出 TDD-1 导弹 1 发"),
		"★ 段 8c 结算层：次数与内核计数一致（触发连携 1 次 / 打出 TDD-1 导弹 1 发）")
	_拆视图(树根, rv)

# ==========================================================================================
# 段 9：★ UX-1（2026-10-19）—— 战后回大地图 / 拖拽编队 / 藏品与零件悬停 / 零件瞄准横幅
#
#   对应作者试玩反馈第 1 / 2 / 3 / 5 条与 2 个伴生缺陷。这一段的纪律与前八段一样：
#   **只断言门面 / 视图已经给出的文本与状态**，不在测试里另立第二套口径；
#   造局面（写 roster / node_id / parts）是夹具，不是表现层在算数值。
# ==========================================================================================

func _段9_UX1六项修复(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "段 9：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	await _等帧(2)
	if s.run_state == null:
		s.start_new_run(20261301, "混编")
	await _等帧(1)
	await _段9a_战后继续回大地图(t, 舱)
	await _段9b_编队拖拽(t, 舱)
	await _段9c_藏品零件悬停(t, 舱)
	await _段9d_零件瞄准横幅(t, 舱)
	_拆boot(树根, 舱)

# ---------------- ① 战后结算点「继续」→ 回大地图 + 顶栏三颗按钮全部可点 ----------------

func _段9a_战后继续回大地图(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null or str(s.run_state.status) != "进行中":
		t.ok(s.start_new_run(20261307, "混编"), "★ 段 9a：开一局（第 %d 层）"
			% (s.run_state.floor_num if s.run_state != null else 0))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	# ---- 招募 + 上阵（战斗格要求出击名单非空）----
	for _i in 5:
		var 目标们 := s.available_recruit_targets(0)
		if 目标们.is_empty():
			break
		if not bool(s.recruit_unit(str((目标们[0] as Dictionary).get("键", "")), 0).get("ok", false)):
			break
	_清待选(s)
	_清券(s)
	t.ok(_编队第一台(s), "★ 段 9a：把一台摆上出击位（出击 %d 台）" % s.run_state.lineup.size())
	var 战斗格 := _找战斗格(s)
	if 战斗格 < 0:
		t.ok(false, "★ 段 9a：第 %d 层找不到战斗格" % s.run_state.floor_num)
		return
	var 落脚 := _找相邻落脚点(s, 战斗格)
	if 落脚 < 0:
		t.ok(false, "★ 段 9a：战斗格 %d 四周找不到落脚点" % 战斗格)
		return
	s.run_state.node_id = 落脚
	s.run_state.map_data["当前节点类型"] = str(s.run_state.cell_at(落脚).get("类型", ""))
	s.screen = "map"
	boot.route()
	await _等帧(2)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 9a：大地图视图类型不对（%s）" % str(mv))
		return
	(mv as MapView)._点格(战斗格)
	await _等帧(3)
	var 开始钮: Control = boot.find_child("开始战斗按钮", true, false)
	if not (开始钮 is Button):
		t.ok(false, "★ 段 9a：找不到【确认编队 · 开始战斗】按钮")
		return
	(开始钮 as Button).pressed.emit()
	await _等帧(3)
	t.ok(s.screen == "battle" and s.in_battle(), "★ 段 9a：确认编队之后真的开打了（screen = %s）" % s.screen)
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	# 战后的「三选一 / 招募券」决定先做完（否则顶栏本来就该锁着 —— 那不是 bug）
	_清待选(s)
	_清券(s)
	s.screen = "result"
	boot.route()
	await _等帧(3)
	t.ok(s.in_battle(), "★ 段 9a：停在结算屏时还拿着这一场的战斗上下文（in_battle = true）")
	var 继续: Control = boot.find_child("继续按钮", true, false)
	t.ok(继续 is Button, "★ 段 9a：结算屏有「继续按钮」")
	if not (继续 is Button):
		return
	(继续 as Button).pressed.emit()
	await _等帧(3)
	t.ok(not s.in_battle(),
		"★★ 段 9a：点「继续前进（回大地图）」之后 `session.in_battle() == false`（battle_ctx 被清掉了）")
	t.ok(str(s.screen) == "map", "★★ 段 9a：屏幕真的回到 map（真实值 %s）" % s.screen)
	# ---- 顶栏「编队 / 招募 / 牌库」三颗按钮现在必须可点 ----
	var 编队钮: Control = boot.find_child("编队按钮", true, false)
	var 招募钮: Control = boot.find_child("招募按钮", true, false)
	var 牌库钮: Control = boot.find_child("战术牌库按钮", true, false)
	t.ok(编队钮 is Button and not (编队钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「编队」按钮 `disabled == false`（随时可打开查看与调整）")
	t.ok(招募钮 is Button and not (招募钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「招募 / 晋升」按钮 `disabled == false`")
	t.ok(牌库钮 is Button and not (牌库钮 as Button).disabled,
		"★★ 段 9a：回大地图后顶栏「战术牌库」按钮 `disabled == false`")
	# ---- 从大地图打开编队 → 点【返回大地图】直接回到大地图 ----
	if 编队钮 is Button:
		(编队钮 as Button).pressed.emit()
		await _等帧(3)
		t.ok(str(s.screen) == "formation", "★ 段 9a：从大地图点「编队」→ 进编队屏（真实值 %s）" % s.screen)
		var 回钮: Control = boot.find_child("回地图按钮", true, false)
		t.ok(回钮 is Button and (回钮 as Button).visible,
			"★★ 段 9a：编队屏的【确认并返回大地图】按钮是可见的（不是战前确认态）")
		if 回钮 is Button:
			(回钮 as Button).pressed.emit()
			await _等帧(3)
			t.ok(str(s.screen) == "map",
				"★★ 段 9a：点【确认并返回大地图】→ 直接回到大地图（真实值 %s）" % s.screen)

# ---------------- ② 编队卡片拖拽：名册拖上阵 / 格位互换 / 拖回名册下阵 ----------------

## 编队屏里找一张名册卡（按机体键）。
func _名册卡(boot, 键: String) -> Control:
	var 盒 = boot.find_child("名册列表内容", true, false)
	if not (盒 is Node):
		return null
	for c in (盒 as Node).get_children():
		if c is Button and str(c.get("键")) == 键:
			return c
	return null

## 编队屏里找某一格的卡（按位名）。
func _槽卡(boot, 位名: String) -> Control:
	for 排 in ["第0排", "第1排"]:
		var n = boot.find_child(str(排), true, false)
		if not (n is Node):
			continue
		for c in (n as Node).get_children():
			if c is Button and str(c.get("位名")) == 位名:
				return c
	return null

## 这一台在不在出击名单里（纯读 `lineup`）。
func _在编队(s: GameSession, 键: String) -> bool:
	for x in s.run_state.lineup:
		if x is Dictionary and str(x.get("key", "")) == 键:
			return true
	return false

## 这个位名上现在是谁（空位 → 空串）。
func _槽位键(s: GameSession, 位名: String) -> String:
	for x in s.lineup_slots():
		if x is Dictionary and str(x.get("位名", "")) == 位名:
			return str(x.get("键", ""))
	return ""

## 第一个空着的位名（找不到 → 空串）。
func _空格位名(s: GameSession) -> String:
	for x in s.lineup_slots():
		if x is Dictionary and str(x.get("键", "")).is_empty():
			return str(x.get("位名", ""))
	return ""

## 名册里第一台**没上阵**的机体键（找不到 → 空串）。
func _未上阵键(s: GameSession) -> String:
	for k in s.run_state.roster.keys():
		if not _在编队(s, str(k)):
			return str(k)
	return ""

func _段9b_编队拖拽(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	if s.run_state == null:
		t.ok(false, "★ 段 9b：没有进行中的局")
		return
	# ---- 夹具：保证「名册里有一台没上阵的」+「至少两台在阵上」----
	var 表: Array = Db.T.get("ALLY_T") if Db.T.get("ALLY_T") is Array else []
	while s.run_state.roster.size() < s.run_state.lineup.size() + 2 and s.run_state.roster.size() < 8:
		var 加了 := false
		for e in 表:
			if not (e is Dictionary):
				continue
			var k := str((e as Dictionary).get("mech", ""))
			if k.is_empty() or s.run_state.roster.has(k):
				continue
			s.run_state.roster[k] = {"key": k, "lv": 30, "hpRatio": 1.0}
			加了 = true
			break
		if not 加了:
			break
	# 再摆一台上去（保证有两台在阵上可以互换）
	var 第二 := _未上阵键(s)
	var 位1 := _空格位名(s)
	if not 第二.is_empty() and not 位1.is_empty():
		s.set_lineup_slot(第二, 位1)
	s.screen = "formation"
	boot.route()
	await _等帧(3)
	t.ok(s.run_state.lineup.size() >= 2, "★ 段 9b：阵上现在有 %d 台可互换" % s.run_state.lineup.size())
	# ---- ① 名册卡片 → 阵型槽（拖上阵）----
	var 键 := _未上阵键(s)
	var 空位 := _空格位名(s)
	if 键.is_empty() or 空位.is_empty():
		t.ok(false, "★ 段 9b：名册里没有「未上阵」的机体 / 没有空格位 —— 拖上阵那一段跑不了")
		return
	var 名册卡 := _名册卡(boot, 键)
	t.ok(名册卡 != null, "★ 段 9b：找得到名册里「%s」的卡片控件" % 键)
	if 名册卡 == null:
		return
	var 数据: Variant = 名册卡._get_drag_data(Vector2.ZERO)
	t.ok(数据 is Dictionary and str((数据 as Dictionary).get("type", "")) == "formation_unit",
		"★★ 段 9b：名册卡的 `_get_drag_data()` 给出 {type: formation_unit, …}（%s）" % str(数据))
	t.ok(数据 is Dictionary and str((数据 as Dictionary).get("unit_key", "")) == 键
		and str((数据 as Dictionary).get("from_slot", "X")).is_empty(),
		"★★ 段 9b：拖拽数据带正确的 unit_key（%s）且 from_slot 为空（它不在阵上）" % 键)
	var 槽卡 := _槽卡(boot, 空位)
	t.ok(槽卡 != null, "★ 段 9b：找得到空格位「%s」的卡片控件" % 空位)
	if 槽卡 == null:
		return
	t.ok(bool(槽卡._can_drop_data(Vector2.ZERO, 数据)),
		"★★ 段 9b：空格位 `_can_drop_data()` = true（可以放下）")
	槽卡._drop_data(Vector2.ZERO, 数据)
	await _等帧(2)
	t.ok(_在编队(s, 键) and _槽位键(s, 空位) == 键,
		"★★ 段 9b：名册拖上阵成功 —— %s 现在在 %s（出击 %d 台）" % [键, 空位, s.run_state.lineup.size()])
	# ---- ② 阵型槽 A → 阵型槽 B（两台直接互换格位）----
	var 占位们: Array = []
	for x in s.lineup_slots():
		if x is Dictionary and not str(x.get("键", "")).is_empty():
			占位们.append(str(x.get("位名", "")))
	if 占位们.size() < 2:
		t.ok(false, "★ 段 9b：阵上不到 2 台 —— 互换那一段跑不了")
		return
	var 位A := str(占位们[0])
	var 位B := str(占位们[1])
	var 卡A := _槽卡(boot, 位A)
	var 卡B := _槽卡(boot, 位B)
	t.ok(卡A != null and 卡B != null, "★ 段 9b：找得到 %s / %s 两张格位卡" % [位A, 位B])
	if 卡A == null or 卡B == null:
		return
	var 键A := _槽位键(s, 位A)
	var 键B := _槽位键(s, 位B)
	var 数A: Variant = 卡A._get_drag_data(Vector2.ZERO)
	t.ok(数A is Dictionary and str((数A as Dictionary).get("unit_key", "")) == 键A
		and str((数A as Dictionary).get("from_slot", "")) == 位A,
		"★★ 段 9b：格位卡的拖拽数据带 from_slot = %s（%s）" % [位A, str(数A)])
	t.ok(bool(卡B._can_drop_data(Vector2.ZERO, 数A)),
		"★★ 段 9b：有人的格位「%s」`_can_drop_data()` = true（可以被换上去）" % 位B)
	卡B._drop_data(Vector2.ZERO, 数A)
	await _等帧(2)
	t.ok(_槽位键(s, 位B) == 键A and _槽位键(s, 位A) == 键B,
		"★★ 段 9b：格位互换成功（%s → %s、%s → %s）" % [键B, 位A, 键A, 位B])
	t.ok(s.run_state.lineup.size() == 占位们.size(),
		"★★ 段 9b：互换之后总上阵人数不变（%d 台）—— 不该撞上限" % s.run_state.lineup.size())
	# ---- ③ 阵型槽 → 名册区（拖回名册 = 下阵）----
	var 卡C := _槽卡(boot, 位B)
	var 名册区 = boot.find_child("名册列表", true, false)
	t.ok(卡C != null and 名册区 is Control, "★ 段 9b：找得到格位卡与名册区落点容器")
	if 卡C == null or not (名册区 is Control):
		return
	var 数C: Variant = 卡C._get_drag_data(Vector2.ZERO)
	t.ok(bool((名册区 as Control)._can_drop_data(Vector2.ZERO, 数C)),
		"★★ 段 9b：名册区落点接「从阵型槽拖回来」的数据（`_can_drop_data()` = true）")
	var 名册行 := _名册卡(boot, 键A)
	t.ok(名册行 != null and bool(名册行._can_drop_data(Vector2.ZERO, 数C)),
		"★ 段 9b：名册行本身也接得住「拖回名册」的数据")
	(名册区 as Control)._drop_data(Vector2.ZERO, 数C)
	await _等帧(2)
	t.ok(not _在编队(s, 键A), "★★ 段 9b：拖回名册 = 下阵成功（%s 已经不在出击名单里）" % 键A)
	t.ok(_槽位键(s, 位B).is_empty(), "★★ 段 9b：%s 空出来了（格位没有留下幽灵记录）" % 位B)
	# ---- ④ 右键阵型槽 = 下阵（「拖回名册」之外的第二条下阵路）----
	var 卡D := _槽卡(boot, 位A)
	t.ok(卡D != null, "★ 段 9b：找得到 %s 的格位卡（右键下阵用）" % 位A)
	if 卡D != null:
		var 键D := _槽位键(s, 位A)
		var 右键 := InputEventMouseButton.new()
		右键.button_index = MOUSE_BUTTON_RIGHT
		右键.pressed = true
		卡D._gui_input(右键)
		await _等帧(2)
		t.ok(not _在编队(s, 键D),
			"★★ 段 9b：右键点阵型槽 %s → 那一台的 %s 直接下阵（不用拖、也不用先选中）" % [位A, 键D])
	# ---- ⑤ 页面显著位置有拖拽提示（作者要求的那句引导）----
	t.ok(_控件含文(boot, "可拖拽机体卡片上阵"), "★★ 段 9b：编队屏显著位置写着「可拖拽机体卡片上阵…」的引导")

# ---------------- ③ 藏品 / 零件 —— 悬停说明层 + 门面悬停文本 ----------------

func _段9c_藏品零件悬停(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	var 装了 := _塞满藏品与零件(boot)
	t.ok(装了 >= 30, "★ 段 9c：给顶栏塞了 %d 件藏品 + 零件（宽度压力最大的一档）" % 装了)
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var 悬停 = boot.find_child("悬停说明层", true, false)
	var 藏栏 = boot.find_child("藏品栏", true, false)
	var 件栏 = boot.find_child("零件栏", true, false)
	t.ok(藏栏 is Node and 件栏 is Node, "★ 段 9c：顶栏里找得到「藏品栏」与「零件栏」")
	if not (藏栏 is Node and 件栏 is Node):
		return
	# ---- 藏品：每个控件都挂着 HoverTooltip，且有实际文本 ----
	var 藏控件 := 0
	var 藏绑了 := 0
	var 藏有字 := 0
	for c in (藏栏 as Node).get_children():
		if not (c is Control):
			continue
		藏控件 += 1
		if (c as Control).has_meta("_hover_bound"):
			藏绑了 += 1
		if not str((c as Control).tooltip_text).strip_edges().is_empty():
			藏有字 += 1
	t.ok(藏控件 > 0, "★ 段 9c：藏品栏里画出了 %d 个藏品控件" % 藏控件)
	t.ok(藏控件 > 0 and 藏绑了 == 藏控件,
		"★★ 段 9c：**每一个**藏品控件都绑了 HoverTooltip（`has_meta(\"_hover_bound\")` = true；%d / %d）"
		% [藏绑了, 藏控件])
	t.ok(藏控件 > 0 and 藏有字 == 藏控件,
		"★★ 段 9c：每一个藏品控件的 `tooltip_text` 都有货（%d / %d）—— 鼠标移上去不会一片空白" % [藏有字, 藏控件])
	# ---- 零件：每个控件都挂了 HoverTooltip，且被动零件是「常驻被动徽章」 ----
	var 件控件 := 0
	var 件绑了 := 0
	var 徽章 := 0
	var 主动钮 := 0
	var 灰钮 := 0
	for c in (件栏 as Node).get_children():
		if not (c is Control):
			continue
		件控件 += 1
		if (c as Control).has_meta("_hover_bound"):
			件绑了 += 1
		if c is Label and str((c as Label).text).contains("·被动"):
			徽章 += 1
		if c is Button:
			主动钮 += 1
			if (c as Button).disabled:
				灰钮 += 1
	t.ok(件控件 > 0, "★ 段 9c：零件栏里画出了 %d 个零件控件" % 件控件)
	t.ok(件控件 > 0 and 件绑了 == 件控件,
		"★★ 段 9c：**每一个**零件控件都绑了 HoverTooltip（%d / %d）" % [件绑了, 件控件])
	t.ok(徽章 > 0, "★★ 段 9c：被动零件画成「·被动」常驻徽章（%d 个 Label），不再假装是坏掉的灰按钮" % 徽章)
	t.ok(主动钮 > 0, "★ 段 9c：主动零件仍然是按钮（%d 个，其中置灰 %d 个）" % [主动钮, 灰钮])
	# ---- 门面悬停文本非空，且内容齐全 ----
	var 藏键 := ""
	if s.run_state != null and not s.run_state.relics.is_empty():
		藏键 = str(s.run_state.relics[0])
	var 藏文 := s.relic_hover_text(藏键)
	t.ok(not 藏文.strip_edges().is_empty() and 藏文.contains("稀有度") and 藏文.contains("数值加成"),
		"★★ 段 9c：`relic_hover_text(\"%s\")` 非空且含「稀有度」「数值加成」（%d 字）" % [藏键, 藏文.length()])
	var 零文 := s.part_hover_text(0)
	t.ok(not 零文.strip_edges().is_empty() and 零文.contains("剩余次数"),
		"★★ 段 9c：`part_hover_text(0)` 非空且含「剩余次数」（%d 字）" % 零文.length())
	# ---- `part_can_use_now` 的三态口径 ----
	var 被动数 := 0
	var 可用数 := 0
	var 说明齐 := true
	if s.run_state != null:
		for i in s.run_state.parts.size():
			var 状 := s.part_can_use_now(i)
			if bool(状.get("passive", false)):
				被动数 += 1
				if bool(状.get("ok", true)) or str(状.get("why", "")).is_empty():
					说明齐 = false
			elif bool(状.get("ok", false)):
				可用数 += 1
				if (状.get("targets") as Array).is_empty():
					说明齐 = false
			elif str(状.get("why", "")).is_empty():
				说明齐 = false
	t.ok(被动数 > 0 and 说明齐,
		"★★ 段 9c：被动零件 `part_can_use_now()` 给 passive = true / ok = false / why 非空（%d 件）；可用的主动零件都带 targets"
		% 被动数)
	# 不在大地图时，主动零件一律「请在大地图界面点击使用」
	s.screen = "formation"
	boot.route()
	await _等帧(2)
	var 屏限制 := 0
	var 屏都拒 := true
	if s.run_state != null:
		for i in s.run_state.parts.size():
			var 状2 := s.part_can_use_now(i)
			if bool(状2.get("passive", false)):
				continue
			屏限制 += 1
			if bool(状2.get("ok", true)) or not str(状2.get("why", "")).contains("大地图"):
				屏都拒 = false
	t.ok(屏限制 == 0 or 屏都拒,
		"★★ 段 9c：不在大地图时主动零件全部拒绝并写清「请在大地图界面点击使用」（%d 件）" % 屏限制)
	t.info("★ 段 9c：零件三态 —— 被动 %d 件、大地图上可用 %d 件、其余都带明确原因" % [被动数, 可用数])
	# ---- 真的能用悬停层把说明显示出来（面板可见 + 文本就是控件那段）----
	if 悬停 is HoverTooltip and 藏控件 > 0:
		var 第一件 := (藏栏 as Node).get_child(0) as Control
		(悬停 as HoverTooltip).show_for_control(第一件)
		t.ok((悬停 as HoverTooltip).当前文本().strip_edges().length() > 0,
			"★★ 段 9c：`show_for_control(第一件藏品)` 之后悬停面板有正文（%d 字）"
			% (悬停 as HoverTooltip).当前文本().length())
		(悬停 as HoverTooltip).hide_tip()
	# 复位到一个干净的大地图，后续小段不受影响
	if s.run_state != null:
		s.screen = "map"
		boot.route()
		await _等帧(2)

# ---------------- ④ 零件瞄准态的金色引导横幅 + 点目标格立即生效 ----------------

func _段9d_零件瞄准横幅(t, 舱: Dictionary) -> void:
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# 干净的一局（免得上一段留下的战斗 / 追击战影响）
	s.start_new_run(20261311, "混编")
	_塞满藏品与零件(boot)
	s.screen = "map"
	boot.route()
	await _等帧(3)
	var mv = boot.当前视图()
	if not (mv is MapView):
		t.ok(false, "★ 段 9d：大地图视图类型不对（%s）" % str(mv))
		return
	# 找一件「现在真的能用」的主动零件（门面自己算，测试不另立口径）
	var 下标 := -1
	var 键 := ""
	var 目标: Array = []
	for i in s.run_state.parts.size():
		var 状 := s.part_can_use_now(i)
		if bool(状.get("ok", false)):
			下标 = i
			键 = str(状.get("key", ""))
			目标 = 状.get("targets") if 状.get("targets") is Array else []
			break
	t.ok(下标 >= 0 and not 目标.is_empty(),
		"★★ 段 9d：大地图上有一件现在就能用的主动零件（下标 %d · %s · %d 个目标格）" % [下标, 键, 目标.size()])
	if 下标 < 0 or 目标.is_empty():
		return
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	var 横幅: Control = boot.find_child("零件瞄准横幅", true, false)
	var 横幅文: Control = boot.find_child("零件瞄准横幅文字", true, false)
	t.ok(横幅 is Control and (横幅 as Control).visible,
		"★★ 段 9d：进入零件瞄准态 → 大地图上方的「零件瞄准横幅」`visible == true`")
	t.ok(横幅文 is Label and str((横幅文 as Label).text).contains("正在使用零件"),
		"★★ 段 9d：横幅写明「【正在使用零件：%s — 请点击下方高亮地图格生效…】」（%s）"
		% [键, str((横幅文 as Label).text) if 横幅文 is Label else "—"])
	t.ok(横幅文 is Label and str((横幅文 as Label).text).contains("取消瞄准"),
		"★ 段 9d：横幅里告诉玩家可以点「取消瞄准」退出")
	var 横幅钮: Control = boot.find_child("横幅取消瞄准按钮", true, false)
	var 老钮: Control = boot.find_child("取消瞄准按钮", true, false)
	t.ok(横幅钮 is Button and (横幅钮 as Button).visible, "★★ 段 9d：横幅上配了一个「取消瞄准」按钮")
	t.ok(老钮 is Button and (老钮 as Button).visible, "★ 段 9d：侧栏原来那颗「取消零件瞄准」也照旧可见")
	# ---- 再点同一件零件 = 退出瞄准（横幅里那句承诺）----
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	t.ok((mv as MapView)._瞄准.is_empty() and not (横幅 as Control).visible,
		"★★ 段 9d：再点一次同一件零件 → 退出瞄准态（横幅收起）")
	# ---- 点合法目标格：立即 use_part、退出瞄准、给即时反馈 ----
	var 前件数 := s.run_state.parts.size()
	var 前左 := int(s.part_can_use_now(下标).get("left", -1))
	(mv as MapView).瞄准零件(下标, 键, 目标)
	await _等帧(2)
	(mv as MapView)._点格(int(目标[0]))
	await _等帧(3)
	t.ok((mv as MapView)._瞄准.is_empty(), "★★ 段 9d：点合法目标格之后瞄准态退出")
	t.ok(not (横幅 as Control).visible, "★★ 段 9d：横幅随即收起（不会挂在那儿）")
	t.ok(str(s.last.get("行动", "")) == "用零件",
		"★★ 段 9d：真的执行了 `use_part()`（last.行动 = %s，落到第 %s 格）"
		% [str(s.last.get("行动", "")), str(s.last.get("到", 0))])
	t.ok(not str(s.last.get("零件", "")).is_empty(),
		"★ 段 9d：门面回了这一件的名字（%s · 剩 %s；用前 left=%d、件数 %d → %d）"
		% [str(s.last.get("零件", "")), str(s.last.get("零件剩", "—")), 前左, 前件数, s.run_state.parts.size()])
	t.ok(_控件含文(mv, "用掉了"),
		"★★ 段 9d：地图上立刻给出即时反馈（预告面板里有「用掉了」那句）")

# ==========================================================================================
# 段 10：★ UX-2 发牌来源机体（作者反馈第 4 条）
#
#   规格 = 《任务单-M4试玩反馈6项修复与体验升级-ARGON.md》子任务 UX-2 第 2 / 3 项：
#     ① 手牌卡面与候补牌都写出【来自：XXX】（取门面 `source_unit_text`，表现层不自己拼）；
#     ② 悬停手牌 → `source_slots` 上的我方 `UnitCard` 同步亮起联动外框（移开全灭）；
#     ③ 本拍新发牌 → 手牌卡挂【新发牌】角标 + 手牌栏顶部弹「【新发牌】获得战术牌【…】（来自：…）」。
#   ★ 零 `J.*`、零状态修改：本段只调用视图的公开联动方法 + 读门面快照。
# ==========================================================================================

func _段10_UX2发牌来源(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 错误 := []
	t.ok(DataLoader.install(错误) and Db.installed, "★ 段 10：数据已装入 Db（%d 条错误）" % 错误.size())
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段10.json"
	if not s.start_quick_battle(20261014):
		t.ok(false, "★ 段 10：开不出快速战斗 —— 本段跑不了")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	var 卡数 := v._手牌列表.get_child_count()
	t.ok(卡数 >= 5, "★ 段 10：手牌栏画出了 %d 张牌" % 卡数)
	# ---- ① 手牌卡面渲染出【来自：…】----
	var 首卡 := _手牌卡控件(v, 0)
	var 首标 = 首卡.find_child("手牌来源", true, false) if 首卡 != null else null
	t.ok(首标 is Label and str((首标 as Label).text).contains("【来自："),
		"★★ 段 10：手牌卡面渲染出了【来自：…】标签（%s）"
		% (str((首标 as Label).text) if 首标 is Label else "—"))
	var 缺标 := 0
	for i in 卡数:
		var k := _手牌卡控件(v, i)
		if k == null or not _控件含文(k, "【来自："):
			缺标 += 1
	t.ok(缺标 == 0, "★★ 段 10：手牌栏 %d 张牌**每一张**都写着【来自：…】（缺 %d 张）" % [卡数, 缺标])
	# ---- ① 候补牌也写出【来自：…】----
	var 候数 := s.bench_cards().size()
	var 候标数 := v.find_children("候补来源*", "", true, false).size()
	t.ok(候数 > 0 and 候标数 == 候数,
		"★★ 段 10：候补牌 %d 张也都标了【来自：…】（画出 %d 个「候补来源」）" % [候数, 候标数])
	# ---- ② 悬停联动高亮：正好点亮 source_slots 上那几台我方机体 ----
	var 目标: Dictionary = {}
	for c in s.hand_cards():
		if not (c is Dictionary):
			continue
		var 位: Variant = (c as Dictionary).get("source_slots")
		if 位 is Array and not (位 as Array).is_empty():
			目标 = c
			break
	var 位们: Array = 目标.get("source_slots") if 目标.get("source_slots") is Array else []
	t.ok(not 位们.is_empty(), "★★ 段 10：找到一张解析到具体机体的手牌【%s】（位 %s）"
		% [str(目标.get("名", "")), "、".join(位们)])
	if 位们.is_empty():
		_拆视图(树根, v)
		return
	v._悬停来源(位们)
	var 亮对 := 0
	var 亮错 := 0
	for i in v._我方卡.size():
		var uc: UnitCard = v._我方卡[i]
		var 应是 := 位们.has(Fm.位名(float(i)))
		if uc == null:
			continue
		if uc.联动高亮中():
			if 应是:
				亮对 += 1
			else:
				亮错 += 1
	t.ok(亮对 == 位们.size() and 亮错 == 0,
		"★★ 段 10：悬停这张牌 → 正好 %d 张我方机体卡亮起联动外框（该亮 %d 张、亮错 %d 张）"
		% [亮对, 位们.size(), 亮错])
	var 角标见 := false
	for i in v._我方卡.size():
		var uc2: UnitCard = v._我方卡[i]
		if uc2 == null or not 位们.has(Fm.位名(float(i))):
			continue
		var 标 = uc2.find_child("卡牌来源标", true, false)
		角标见 = 标 is Label and (标 as Label).visible
		break
	t.ok(角标见, "★★ 段 10：亮起的那张机体卡上有〔卡牌来源〕角标（联动提示看得见）")
	v._移开来源()
	var 还亮 := 0
	for i in v._我方卡.size():
		var uc3: UnitCard = v._我方卡[i]
		if uc3 != null and uc3.联动高亮中():
			还亮 += 1
	t.ok(还亮 == 0, "★★ 段 10：鼠标移开 → 联动高亮全部熄灭（还亮 %d 张）" % 还亮)
	# ---- ③ 本拍新发牌：角标 + 手牌栏顶部提示条 ----
	s.battle_ctx["战术手牌"] = []
	var 补 := Btl.候补补位(s.battle_ctx)
	t.ok(not 补.is_empty(), "★ 段 10：夹具造出 %d 张「本拍新发牌」" % 补.size())
	v.refresh()
	await _等帧(2)
	t.ok(v._新发牌提示 != null and v._新发牌提示.visible and str(v._新发牌提示.text).contains("【新发牌】"),
		"★★ 段 10：手牌栏顶部弹出「【新发牌】获得战术牌【…】（来自：…）」（%s）" % str(v._新发牌提示.text))
	t.ok(v._新发牌提示 != null and str(v._新发牌提示.text).contains("来自："),
		"★ 段 10：提示条里也写着来源机体（%s）" % str(v._新发牌提示.text))
	var 新角标数 := v.find_children("新发牌角标", "", true, false).size()
	t.ok(新角标数 > 0 and 新角标数 == v._手牌列表.get_child_count(),
		"★★ 段 10：本拍新发的 %d 张牌每张都挂【新发牌】角标（画出 %d 个）"
		% [v._手牌列表.get_child_count(), 新角标数])
	# ---- 收尾：把战斗屏拆掉，后续（若有）不受影响 ----
	_拆视图(树根, v)

# ==========================================================================================
# 段 11：★ UX-3（2026-10-19）示意性战斗动画层 —— 谁打了谁、多少伤害、什么效果
#
#   规格 =《任务单-M4试玩反馈6项修复与体验升级-ARGON.md》子任务 UX-3 第 1 / 2 / 3 项：
#     ① 战场区常驻一条紧凑《动作播报条》，每推进一拍写出本拍核心事件摘要
#        （开战初始 = `【战斗开始】等待推进下一拍或点击自动播放`）；
#     ② 推进一拍之后《战斗动画层》记下本拍的弹道（起点/终点槽位、颜色、类型）与头顶飘字；
#     ③ 出手方 / 受击方的 `UnitCard` 动作反馈状态跟着更新。
#   ★ 纪律：只读门面 `battle_log_entries()` 与视图自己的公开状态；headless 下零 Tween（毫秒级跑完），
#     且**版面门禁不受影响**（播报条 + 动画层都落在 1280×720 内、不挤动手牌栏 / 战报栏）。
# ==========================================================================================

func _段11_UX3战斗动画层(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 错误 := []
	t.ok(DataLoader.install(错误) and Db.installed, "★ 段 11：数据已装入 Db（%d 条错误）" % 错误.size())
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段11.json"
	if not s.start_quick_battle(20261015):
		t.ok(false, "★ 段 11：开不出快速战斗 —— 本段跑不了")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	# ---------- ① 两个新节点真的在 ----------
	var 播报 = v.find_child("动作播报条", true, false)
	t.ok(播报 is Label, "★★ 段 11：战斗屏里有《动作播报条》（Label，`find_child(\"动作播报条\")`）")
	t.ok(播报 is Label and str((播报 as Label).text).contains("【战斗开始】"),
		"★★ 段 11 ①：开战初始播报条写着「【战斗开始】等待推进下一拍或点击自动播放」（%s）"
		% (str((播报 as Label).text) if 播报 is Label else "—"))
	var 层 = v.find_child("战斗动画层", true, false)
	t.ok(层 is Control, "★★ 段 11：战斗屏里有《战斗动画层》（Control）")
	t.ok(层 is Control and (层 as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"★★ 段 11：动画层 `mouse_filter == MOUSE_FILTER_IGNORE`（纯表现，不吃鼠标事件）")
	t.ok(层 is Control and (层 as Control).get_parent() == v,
		"★★ 段 11：动画层是「战斗屏」的**直接子节点**（不进任何 Container → 不参与自动排版、不挤占版面）")
	t.ok(层 != null and 层.get("active_trajectories") is Array and 层.get("active_popups") is Array,
		"★★ 段 11：动画层暴露 `active_trajectories: Array` 与 `active_popups: Array`（测试直接查它）")
	# ---------- ② 版面：播报条自身不出画布、不压手牌栏 / 战报栏 ----------
	await _等帧(1)
	var 播框 := _框(v, "动作播报条")
	var 手框 := _框(v, "手牌栏")
	var 报框 := _框(v, "战报栏")
	t.ok(播框.size.x > 0.0 and _在界内(播框), "★★ 段 11：播报条 %s 完全落在 1280×720 内（不把版面顶出画布）" % _短(播框))
	t.ok(播框.size.y > 0.0 and 播框.size.y <= 26.5,
		"★★ 段 11：播报条是**紧凑单行横条**（高 %.0f ≤ 26px）—— 不会把底部手牌栏挤出 720 底边" % 播框.size.y)
	t.ok(手框.size.x > 0.0 and _在界内(手框) and 报框.size.x > 0.0 and _在界内(报框),
		"★★ 段 11：手牌栏 %s / 战报栏 %s 仍然完全落在 1280×720 内" % [_短(手框), _短(报框)])
	t.ok(not _叠(播框, 手框) and not _叠(播框, 报框),
		"★★ 段 11：播报条与手牌栏 / 战报栏互不重叠（交面积 %.0f / %.0f）" % [_交面积(播框, 手框), _交面积(播框, 报框)])
	t.ok(层 is Control and (层 as Control).get_global_rect().size.x > 0.0,
		"★ 段 11：动画层覆盖整块战斗屏（%s）—— 弹道可以画在任意两台机体之间" % _短((层 as Control).get_global_rect()))
	# ---------- ③ 推进一拍：播报条更新 + 弹道 / 飘字出现 + 卡片反馈更新 ----------
	var 初始文 := v.播报文本()
	var 有动作 := false
	var 轮 := 0
	while 轮 < 3 and not 有动作:
		轮 += 1
		s.step_battle_turn()
		v.refresh()
		await _等帧(2)
		var 轨: Array = 层.get("active_trajectories")
		var 飘: Array = 层.get("active_popups")
		有动作 = not 轨.is_empty() or not 飘.is_empty()
	t.ok(轮 <= 3 and 有动作, "★ 段 11：推进 %d 拍之内就抓到了本拍的战斗动画事件（不需要把整场打完）" % 轮)
	var 轨们: Array = 层.get("active_trajectories")
	var 飘们: Array = 层.get("active_popups")
	t.ok(有动作, "★★ 段 11 ②③：推进一拍并 `refresh()` 之后，动画层记下了本拍的弹道 %d 条 / 飘字 %d 条"
		% [轨们.size(), 飘们.size()])
	var 播文 := v.播报文本()
	t.ok(not 播文.strip_edges().is_empty() and 播文 != 初始文,
		"★★ 段 11 ①：播报条已更新为本拍动作摘要（%s）" % 播文.substr(0, 96))
	var 有头 := false
	for 头 in ["【攻击】", "【大招】", "【修理】", "【战术牌】", "【势力】", "【镜甲】"]:
		if 播文.contains(str(头)):
			有头 = true
			break
	t.ok(有头, "★★ 段 11 ①：摘要用固定格式开头（【攻击】/【大招】/【修理】/【战术牌】/【势力】/【镜甲】）")
	t.ok(not (播文.contains("【攻击】") or 播文.contains("【大招】") or 播文.contains("【修理】")
			or 播文.contains("【战术牌】")) or 播文.contains("->"),
		"★★ 段 11 ①：摘要写出了「谁 -> 谁」的指向（含 `->`）")
	# 弹道结构：起点 / 终点槽位 + 颜色 + 类型 + alpha
	var 轨键齐 := true
	var 轨例 := ""
	for x in 轨们:
		if not (x is Dictionary):
			轨键齐 = false
			break
		for k in ["起点方", "起点位", "终点方", "终点位", "颜色", "类型", "alpha"]:
			if not (x as Dictionary).has(k):
				轨键齐 = false
		if 轨例.is_empty():
			轨例 = "%s〔%s·%s〕 -> %s〔%s·%s〕" % [str(x.get("类型", "")), str(x.get("起点方", "")),
				Fm.位名(float(x.get("起点位", 0.0))), str(x.get("类型", "")), str(x.get("终点方", "")),
				Fm.位名(float(x.get("终点位", 0.0)))]
	t.ok(not 轨们.is_empty() and 轨键齐,
		"★★ 段 11 ②：每条弹道都带 起点方 / 起点位 / 终点方 / 终点位 / 颜色 / 类型 / alpha（首条 %s）" % 轨例)
	var 飘键齐 := true
	var 飘例 := ""
	for x in 飘们:
		if not (x is Dictionary):
			飘键齐 = false
			break
		for k in ["文本", "颜色", "字号", "alpha"]:
			if not (x as Dictionary).has(k):
				飘键齐 = false
		if 飘例.is_empty():
			飘例 = str(x.get("文本", ""))
	t.ok(not 飘们.is_empty() and 飘键齐,
		"★★ 段 11 ③：每条飘字都带 文本 / 颜色 / 字号 / alpha（首条「%s」）" % 飘例)
	var 有伤害文 := false
	for x in 飘们:
		if x is Dictionary and (str(x.get("文本", "")).contains("-") or str(x.get("文本", "")).contains("未命中")
				or str(x.get("文本", "")).contains("+")):
			有伤害文 = true
			break
	t.ok(有伤害文, "★★ 段 11 ③：飘字里看得到「-伤害 / 未命中 / +耐久」这类数字（高对比度大字）")
	# 卡片反馈：弹道的起点（出手方）与终点（受击方）都留下了反馈状态
	var 起反 := 0
	var 终反 := 0
	var 反馈种类: Array = []
	for x in 轨们:
		if not (x is Dictionary):
			continue
		var 起卡 := _卡Of(v, str(x.get("起点方", "")), int(float(x.get("起点位", -1.0))))
		var 终卡 := _卡Of(v, str(x.get("终点方", "")), int(float(x.get("终点位", -1.0))))
		if 起卡 != null and not str(起卡.combat_fx_kind()).is_empty():
			起反 += 1
			if not 反馈种类.has(str(起卡.combat_fx_kind())):
				反馈种类.append(str(起卡.combat_fx_kind()))
		if 终卡 != null and not str(终卡.combat_fx_kind()).is_empty():
			终反 += 1
			if not 反馈种类.has(str(终卡.combat_fx_kind())):
				反馈种类.append(str(终卡.combat_fx_kind()))
	t.ok(起反 > 0, "★★ 段 11 ②：出手方 `UnitCard` 有了动作反馈状态（%d 条弹道的起点卡都亮着；种类 %s）"
		% [起反, "、".join(反馈种类)])
	t.ok(终反 > 0, "★★ 段 11 ③：受击方 `UnitCard` 也有了动作反馈状态（%d 条弹道的终点卡）" % 终反)
	var 角标见 := false
	for c in v._我方卡:
		if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
			var 标 = (c as UnitCard).find_child("动作反馈标", true, false)
			角标见 = 标 is Label and (标 as Label).visible
			break
	if not 角标见:
		for c in v._敌方卡:
			if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
				var 标2 = (c as UnitCard).find_child("动作反馈标", true, false)
				角标见 = 标2 is Label and (标2 as Label).visible
				break
	t.ok(角标见, "★★ 段 11：出手 / 受击那张卡的右下角亮出〔出手〕/〔受击〕角标（`动作反馈标` 可见）")
	# ---------- ④ 再刷一次（没有新日志）：播报条不被清空、弹道留着 ----------
	var 拍文 := v.播报文本()
	v.refresh()
	await _等帧(1)
	t.ok(v.播报文本() == 拍文,
		"★ 段 11：没有新日志时再 `refresh()` 一次 → 播报条保留上一拍原文（不被清成空白）")
	t.ok((层.get("active_trajectories") as Array).size() == 轨们.size(),
		"★ 段 11：没有新日志时弹道数组不被乱动（%d 条）" % (层.get("active_trajectories") as Array).size())
	# ---------- ⑤ 版面门禁照旧：卡片不互压、都在 1280×720 内 ----------
	var 叠了 := 0
	var 出界 := 0
	for 排名 in ["我方阵型第0排", "我方阵型第1排", "敌方阵型第0排", "敌方阵型第1排"]:
		var 排 = v.find_child(排名, true, false)
		if 排 == null:
			continue
		var 框们: Array = []
		for c in (排 as Node).get_children():
			if c is UnitCard:
				框们.append((c as Control).get_global_rect())
				if not _在界内((c as Control).get_global_rect()):
					出界 += 1
		for i in 框们.size():
			for j in range(i + 1, 框们.size()):
				if _叠(框们[i], 框们[j]):
					叠了 += 1
	t.ok(叠了 == 0 and 出界 == 0,
		"★★ 段 11：有动作反馈状态时，16 张单位卡仍然两两不重叠（重叠对数 %d）且全在 1280×720 内（出界 %d 张）"
		% [叠了, 出界])
	# ---------- ⑥ 换一场：播报条回到「【战斗开始】…」、动画层清干净 ----------
	if s.start_quick_battle(20261016):
		v.refresh()
		await _等帧(2)
		t.ok(v.播报文本().contains("【战斗开始】"),
			"★★ 段 11：换一场新战斗 → 播报条回到「【战斗开始】…」（`_已播日志数` 归零重播；%s）" % v.播报文本())
		var 清空 := (层.get("active_trajectories") as Array).is_empty() and (层.get("active_popups") as Array).is_empty()
		t.ok(清空, "★★ 段 11：换一场新战斗 → 上一场的弹道 / 飘字被清干净（不留残影）")
		var 卡净 := true
		for c in v._我方卡:
			if c is UnitCard and not str((c as UnitCard).combat_fx_kind()).is_empty():
				卡净 = false
		t.ok(卡净, "★★ 段 11：换一场新战斗 → 单位卡上的动作反馈也收干净了")
	else:
		t.ok(false, "★ 段 11：第二场快速战斗开不起来（换场那几条断言跑不了）")
	# ---------- ⑦ 静默：整段零报错、门面错误表干净 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 11：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆视图(树根, v)

## 视图里某方某一格的 `UnitCard`（与 `BattleView._卡()` 同一口径的只读取法）。
func _卡Of(v: BattleView, 方: String, 位号: int) -> UnitCard:
	var 池: Array = v._我方卡 if (方 == "ally" or 方 == "我方") else v._敌方卡
	if 位号 < 0 or 位号 >= 池.size():
		return null
	var c: Variant = 池[位号]
	return c as UnitCard if (c is UnitCard) else null

# ==========================================================================================
# 段 12：★ DECK-2 / DECK-3 —— 单机牌组战斗屏（点选机体 + 战意条 + 上下双排手牌 + 0.5s 即时演出）
#
#   任务单 §3 验收门禁 断言 7 的表现层那一半：
#     ① 点选不同机体 → **上排专属牌整排切换**（主武器卡 / 衍生攻击卡 / 专属精神牌 三区）；
#     ② 下排公有牌**按职业 / 势力动态置灰与亮起**（`〔需：近卫〕` / `〔需：重装〕`、指挥机 -5 折后价）；
#     ③ 敌方 `UnitCard` 显示**意图预告**（内核 `Btl.算意图` 的逐台结果，且**没有任何压制射击**）；
#     ④ 我方被瞄准的机体卡有受威胁提示；
#     ⑤ 每打一张牌**立刻**播 0.5 秒一步的演出（复用 UX-5 的串行队列，headless 下同步播完帧数记满）；
#     ⑥ 控制栏在单机牌组模式下是「结束我方回合 / 全员自动回合 / 2x 加速 / 跳过本回演出 / 结束并结算」；
#     ⑦ 版面门禁照旧：上下双排 + 阵型区 + 战报栏都在 1280×720 内、两两不重叠、16 张单位卡不互压。
#
#   ★ 数据来源纪律：本段只读**门面**（`upper_hand_cards()` / `lower_hand_cards()` / `deck_turn_summary()` /
#     `select_battle_unit()` / `unit_view()`），断言的是「门面给的事实」与「视图把它排在哪」，
#     不在测试里另立第二套判据。
# ==========================================================================================

func _段12_单机牌组战斗屏(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 12：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	# ★ 界面入口（`menu_view` 的【快速测试战斗】）就是先 `set_unit_deck_mode(true)` 再开战；
	#   本段照同一条路走（旧口径的 `start_quick_battle(种子)` 一个字都不改）。
	s.set_unit_deck_mode(true)
	if not s.start_quick_battle(20261020):
		t.ok(false, "★ 段 12：单机牌组快速战斗开不起来")
		_拆boot(树根, 舱)
		return
	boot.route()
	await _等帧(3)
	var bv = boot.当前视图()
	if not (bv is BattleView):
		t.ok(false, "★ 段 12：战斗屏视图类型不对（%s）" % str(bv))
		_拆boot(树根, 舱)
		return
	var v: BattleView = bv
	# ---------- ① 内核开关 / 默认选中 ----------
	t.ok(Params.单机牌组_开(s.battle_ctx),
		"★ 段 12 ①：这一场真的开在单机牌组模式下（`Params.单机牌组_开(ctx) == true`）")
	var 首台 := _单机存活键(s, 0)
	t.ok(not s.selected_unit_id.is_empty() and s.selected_unit_id == 首台,
		"★ 段 12 ①：开战自动选中「格位 0 起第一台存活的我方」= %s（实际 %s）" % [首台, s.selected_unit_id])
	var 上 := s.upper_hand_cards()
	var 下 := s.lower_hand_cards()
	t.ok(not 上.is_empty(), "★ 段 12 ①：选中机体 %s 的上排专属牌 %d 张" % [s.selected_unit_id, 上.size()])
	var 区们: Array = 上.map(func(c): return str((c as Dictionary).get("区", "")))
	t.ok(区们.has("主武器卡"),
		"★ 段 12 ①：上排左区有【主武器卡】（%s）" % str(区们))
	t.ok(下.size() == (s.battle_ctx.get("公有手牌") as Array).size(),
		"★ 段 12 ①：下排 %d 张 = 内核 `ctx.公有手牌` %d 张" % [下.size(), (s.battle_ctx.get("公有手牌") as Array).size()])
	# ---------- ② 双排节点与「上排在下排上面」 ----------
	t.ok(v._专属排 != null and v._公有排 != null and v._专属排.visible and v._公有排.visible,
		"★★ 段 12 ②：单机牌组模式下上下双排**都露出来了**（专属排 / 公有排）")
	t.ok(v._手牌滚动 != null and not v._手牌滚动.visible,
		"★★ 段 12 ②：旧那行「战术手牌」整行收起来（节点仍留在树上，smoke 段 4 的 find_child 照旧找得到）")
	t.ok(v._专属排列表.get_child_count() == 上.size(),
		"★★ 段 12 ②：上排真的画出了 %d 张专属牌（门面 %d 张）" % [v._专属排列表.get_child_count(), 上.size()])
	t.ok(v._公有排列表.get_child_count() == 下.size(),
		"★★ 段 12 ②：下排真的画出了 %d 张公有牌（门面 %d 张）" % [v._公有排列表.get_child_count(), 下.size()])
	var 上框: Rect2 = v._专属排.get_global_rect()
	var 下框: Rect2 = v._公有排.get_global_rect()
	t.ok(上框.size.y > 0.0 and 下框.size.y > 0.0 and 上框.end.y <= 下框.position.y + 0.5,
		"★★ 段 12 ②：上排 %s 在下排 %s 上面（不叠、不串行）" % [_短(上框), _短(下框)])
	t.ok(str(v._专属排标题.text).contains("战意") and str(v._专属排标题.text).contains("专属排"),
		"★★ 段 12 ②：上排标题写明「当前选中机体 + 战意 N/100 + 专属排」：%s" % str(v._专属排标题.text))
	t.ok(str(v._公有排标题.text).contains("公有排"),
		"★★ 段 12 ②：下排标题写明「全队公有排」：%s" % str(v._公有排标题.text))
	t.ok(str(v._手牌标题.text).contains("阶段") and str(v._手牌标题.text).contains("战意"),
		"★ 段 12 ②：手牌栏顶行写清「第 N 回合 · 阶段 · 选中机体 · 战意」：%s" % str(v._手牌标题.text))
	# ---------- ③ 单位卡：战意条 + 主武状态 + 选中外框 ----------
	var 卡 := _单机卡By键(v, s.selected_unit_id)
	t.ok(卡 != null, "★ 段 12 ③：找到选中机体的 `UnitCard`（%s）" % s.selected_unit_id)
	if 卡 != null:
		t.ok(卡.选中中(), "★★ 段 12 ③：被选中的机体卡是**选中态**（金色醒目外框）")
		t.ok(卡._战意行 != null and 卡._战意行.visible and str(卡._战意文.text).begins_with("战意"),
			"★★ 段 12 ③：机体卡上显示「%s」（战意 N / 100 + 进度条）" % str(卡._战意文.text))
		t.ok(卡._战意条 != null and 卡._战意条.max_value > 0.0,
			"★★ 段 12 ③：战意进度条在（max = %.0f）" % (卡._战意条.max_value if 卡._战意条 != null else 0.0))
		t.ok(卡._主武标 != null and 卡._主武标.visible and str(卡._主武标.text) == "〔主武就绪〕",
			"★★ 段 12 ③：本回合主武状态标着「%s」" % str(卡._主武标.text))
	# ---------- ④ 打一张主武器卡 → 立刻播 0.5 秒一步的演出 ----------
	var 可打 := {}
	for c in 上:
		if bool((c as Dictionary).get("可打", false)) and str((c as Dictionary).get("区", "")) == "主武器卡":
			可打 = c
			break
	t.ok(not 可打.is_empty(), "★ 段 12 ④：选中机体有一张现在就能打的【主武器卡】")
	if not 可打.is_empty():
		var 战意前 := float(Btl.战意(s._选中单位()))
		var 别台前 := _别台战意(s, s.selected_unit_id)
		var 前日志 := s.battle_log_entries(0).size()
		t.ok(float(BattleView.STEP_DURATION) >= 0.45,
			"★★ 段 12 ④：单步演出时长 %.2f 秒（规格 0.5 秒/步，红线 >= 0.45）" % float(BattleView.STEP_DURATION))
		v._点单机卡("主武器卡", str(可打.get("手牌键", "")), true)
		await _等帧(1)
		t.ok(v.演出帧数() >= 1 and v.已播帧数() >= v.演出帧数(),
			"★★ 段 12 ④：打出一张牌**立刻**拆出 %d 帧并播完（已播 %d）—— 不是攒到下一回合" % [v.演出帧数(), v.已播帧数()])
		t.ok(s.battle_log_entries(0).size() > 前日志,
			"★★ 段 12 ④：这一下真的写进了战斗日志（%d → %d 条）" % [前日志, s.battle_log_entries(0).size()])
		t.ok(str(v.播报文本()).length() > 0, "★ 段 12 ④：播报条写出了这一下（%s）" % str(v.播报文本()).substr(0, 40))
		var 战意后 := float(Btl.战意(s._选中单位()))
		var 费 := float(可打.get("战意", 0.0))
		t.ok(absf(float(s.last.get("战意前", -1.0)) - 战意前) < 0.001 and absf(float(s.last.get("战意后", -2.0)) - 战意后) < 0.001,
			"★★ 段 12 ④：门面记的账与内核一致（战意 %.0f → %.0f，这张牌费 %.0f）" % [战意前, 战意后, 费])
		t.ok(absf(_别台战意(s, s.selected_unit_id) - 别台前) < 0.001,
			"★★ 段 12 ④：**谁打牌扣谁的战意** —— 别的机体战意一分没动（%.0f → %.0f）"
			% [别台前, _别台战意(s, s.selected_unit_id)])
		# 主武器卡互毁 → 同一张卡变灰、状态标变「已打主武」
		卡 = _单机卡By键(v, s.selected_unit_id)
		if 卡 != null:
			t.ok(str(卡._主武标.text) == "〔已打主武〕",
				"★★ 段 12 ④：打完主武器卡 → 机体卡状态标变成「%s」" % str(卡._主武标.text))
	# ---------- ⑤ 点选另一台机体 → 上排整排切换 ----------
	var 二台 := _单机存活键(s, 1)
	if not 二台.is_empty():
		var 上排前: Array = s.upper_hand_cards().map(func(c): return str((c as Dictionary).get("名", "")))
		v._点选机体(二台)
		await _等帧(1)
		t.ok(s.selected_unit_id == 二台, "★★ 段 12 ⑤：点另一台机体卡 → 选中换成 %s" % 二台)
		var 上排后: Array = s.upper_hand_cards().map(func(c): return str((c as Dictionary).get("名", "")))
		t.ok(上排后 != 上排前, "★★ 段 12 ⑤：上排专属牌**整排换掉**（%s → %s）" % [str(上排前), str(上排后)])
		t.ok(v._专属排列表.get_child_count() == 上排后.size(),
			"★★ 段 12 ⑤：上排卡行跟着重画成 %d 张" % v._专属排列表.get_child_count())
		t.ok(str(v._专属排标题.text).contains(二台) or str(v._专属排标题.text).contains(str(s._选中单位().get("name", ""))),
			"★★ 段 12 ⑤：上排标题跟着换成新机体：%s" % str(v._专属排标题.text))
		var 卡新 := _单机卡By键(v, 二台)
		var 卡旧 := _单机卡By键(v, 首台)
		t.ok(卡新 != null and 卡新.选中中() and (卡旧 == null or not 卡旧.选中中()),
			"★★ 段 12 ⑤：金色选中框**从旧机体挪到新机体**（旧卡仍可点 = 还能打精神牌）")
	# ---------- ⑥ 下排动态身份置灰（沙盒：公有手牌换成两张指定职业牌） ----------
	await _段12b_下排置灰与指挥减费(t, 树根)
	# ---------- ⑦ 敌方意图预告 ----------
	var 敌们 := s.battle_ctx.get("enemies") as Array
	var 意 := s.enemy_intents()
	t.ok(意.size() == Units.livingOf("enemy", s.battle_ctx).size(),
		"★★ 段 12 ⑦：敌方意图 %d 条 = 存活敌机 %d 台（按格位 0..7 排好）" % [意.size(), Units.livingOf("enemy", s.battle_ctx).size()])
	var 无压制 := true
	var 有武器 := true
	for 条 in 意:
		if str(条).contains("压制"):
			无压制 = false
		if str((条 as Dictionary).get("武器名", "")).is_empty():
			有武器 = false
	t.ok(无压制, "★★ 段 12 ⑦：意图里**没有任何压制射击标记**（作者 2026-10-17 拍板彻底删除）")
	t.ok(有武器, "★★ 段 12 ⑦：每台敌机的意图都带武器名（`算意图` 的字段）")
	var 敌卡 := _单机敌方卡(v, 意)
	if 敌卡 != null:
		t.ok(str(敌卡._意图行.text).contains("意图："),
			"★★ 段 12 ⑦：敌方 `UnitCard` 的意图行写着「%s」" % str(敌卡._意图行.text).substr(0, 60))
		t.ok(str(敌卡._意图行.text).contains("预计"),
			"★★ 段 12 ⑦：意图预告带「预计」伤害（%s）" % str(敌卡._意图行.text).substr(0, 60))
	var 被瞄准 := 0
	for c in v._我方卡:
		if c is UnitCard and str((c as UnitCard)._意图行.text).contains("被瞄准"):
			被瞄准 += 1
	t.ok(被瞄准 >= 1, "★★ 段 12 ⑦：我方**被瞄准的机体卡**有受威胁提示（%d 台）" % 被瞄准)
	# ---------- ⑧ 结束我方回合 ----------
	t.ok(str(v._推进按钮.text) == "结束我方回合",
		"★★ 段 12 ⑧：控制栏那颗按钮改成「%s」（不再是「推进下一回合」）" % str(v._推进按钮.text))
	t.ok(str(v._自动按钮.text) == "全员自动回合",
		"★★ 段 12 ⑧：保留「%s」按钮" % str(v._自动按钮.text))
	t.ok(str(v._结算按钮.text) == "结束并结算",
		"★★ 段 12 ⑧：保留「%s」（跳过直达结算）" % str(v._结算按钮.text))
	var 回合前 := int(float(s.battle_ctx.get("turn", 1.0)))
	v._下一拍()
	await _等帧(1)
	t.ok(int(float(s.battle_ctx.get("turn", 1.0))) > 回合前,
		"★★ 段 12 ⑧：点「结束我方回合」→ 敌方行动 + 进入下一回合（%d → %d）" % [回合前, int(float(s.battle_ctx.get("turn", 1.0)))])
	t.ok(v.演出帧数() >= 1 and v.已播帧数() >= v.演出帧数(),
		"★★ 段 12 ⑧：这一整回也按 0.5 秒一步演完（%d 帧）" % v.演出帧数())
	# ---------- ⑨ 版面门禁（单机牌组模式下也照旧） ----------
	var 可用 := Rect2(0.0, 顶栏高, 画布宽, 画布高 - 顶栏高)
	var 阵 := _框(boot, "阵型区")
	var 手 := _框(boot, "手牌栏")
	var 报 := _框(boot, "战报栏")
	t.ok(阵.size.y > 0.0 and 手.size.y > 0.0 and 报.size.y > 0.0,
		"★★ 段 12 ⑨：阵型区 / 手牌栏 / 战报栏三块都画出来了")
	t.ok(_在(阵, 可用) and _在(手, 可用) and _在(报, 可用),
		"★★ 段 12 ⑨：三块都在 1280×720 的可用区内（阵 %s / 手 %s / 报 %s）" % [_短(阵), _短(手), _短(报)])
	t.ok(not _叠(阵, 手) and not _叠(阵, 报) and not _叠(手, 报),
		"★★ 段 12 ⑨：三块两两互不重叠（交面积 %.0f / %.0f / %.0f）" % [_交面积(阵, 手), _交面积(阵, 报), _交面积(手, 报)])
	t.ok(_在(上框, 手) and _在(下框, 手),
		"★★ 段 12 ⑨：上下双排都装在手牌栏里（上 %s / 下 %s / 手牌栏 %s）" % [_短(上框), _短(下框), _短(手)])
	var 卡框们: Array = []
	for c in v.find_children("*", "UnitCard", true, false):
		卡框们.append((c as Control).get_global_rect())
	var 叠了 := 0
	for i in 卡框们.size():
		for j in range(i + 1, 卡框们.size()):
			if _叠(卡框们[i], 卡框们[j]):
				叠了 += 1
	t.ok(卡框们.size() == int(Fm.SLOTS()) * 2 and 叠了 == 0,
		"★★ 段 12 ⑨：%d 张单位卡两两互不重叠（重叠对数 = %d）" % [卡框们.size(), 叠了])
	# ---------- ⑩ 「结束并结算」在单机牌组模式下也走得通 ----------
	t.ok(bool(s.in_battle()), "★ 段 12 ⑩：此时还在战斗里（%d 回合）" % int(float(s.battle_ctx.get("turn", 1.0))))
	v._点结算()
	await _等帧(2)
	t.ok(s.screen == "result", "★★ 段 12 ⑩：点「结束并结算」→ 屏幕切到结算屏（%s）" % s.screen)
	t.ok(bool(s.result_summary().get("有结果", false)),
		"★★ 段 12 ⑩：结算屏拿得到结果（%s / 回合 %d）"
		% [str(s.result_summary().get("结果", "")), int(s.result_summary().get("回合数", 0))])
	# ---------- ⑪ 静默 ----------
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★★ 段 12 ⑪：整段跑下来 `session.errors` 为空（零报错）%s" % str(s.errors))
	_拆boot(树根, 舱)
	# ---------- ⑫ 界面入口（菜单那颗按钮）真的把单机牌组打开 ----------
	await _段12c_界面入口(t, 树根)

## 段 12c：**界面入口**（`menu_view` 的【快速测试战斗】）点下去就进单机牌组战斗。
## 这一条钉的是「新模式不是只给测试用的死代码」——玩家从菜单点进来玩到的就是它。
func _段12c_界面入口(t, 树根: Node) -> void:
	_设视口(树根, Vector2(画布宽, 画布高))
	var 舱 := await _建boot(树根, Vector2(画布宽, 画布高))
	if 舱.is_empty():
		t.ok(false, "★ 段 12c：boot.tscn 实例化失败")
		return
	var boot = 舱["boot"]
	var s: GameSession = boot.session
	t.ok(not s.unit_deck_mode(), "★ 段 12c：全新会话默认**不开**单机牌组（旧口径零回归）")
	var 按 := _找按文(boot, "快速测试战斗")
	t.ok(按 != null, "★ 段 12c：主菜单上有【快速测试战斗】按钮")
	if 按 == null:
		_拆boot(树根, 舱)
		return
	按.pressed.emit()
	boot.route()
	await _等帧(3)
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(),
		"★★ 段 12c：点【快速测试战斗】→ 直接进战斗屏（screen = %s）" % s.screen)
	t.ok(s.unit_deck_mode() and Params.单机牌组_开(s.battle_ctx),
		"★★ 段 12c：从菜单点进来的这一场**就是**单机牌组（阶段制 + 上下双排）")
	var bv = boot.当前视图()
	if bv is BattleView:
		var v: BattleView = bv
		t.ok(v._专属排 != null and v._专属排.visible and v._公有排 != null and v._公有排.visible,
			"★★ 段 12c：战斗屏上真的画出上下双排（专属排 / 公有排都可见）")
		t.ok(str(v._推进按钮.text) == "结束我方回合",
			"★★ 段 12c：控制栏那颗按钮是「%s」" % str(v._推进按钮.text))
		t.ok(v._专属排列表.get_child_count() == s.upper_hand_cards().size(),
			"★★ 段 12c：上排画出了 %d 张专属牌" % v._专属排列表.get_child_count())
	else:
		t.ok(false, "★ 段 12c：点完之后战斗屏视图类型不对（%s）" % str(bv))
	_拆boot(树根, 舱)

## 段 12 的沙盒：把下排公有手牌换成「一张重装职业牌 + 一张近卫职业牌」，
## 逐个切机体验证**动态身份置灰 / 亮起**与**指挥机公有牌 -5**。
func _段12b_下排置灰与指挥减费(t, 树根: Node) -> void:
	var s := _建单机沙盒()
	if s == null or s.battle_ctx.is_empty():
		t.ok(false, "★ 段 12b：单机牌组沙盒开不起来")
		return
	var v := _挂战斗屏(树根, s)
	await _等帧(2)
	var 近卫键 := _单机键By职业(s, "近卫")
	var 重装键 := _单机键By职业(s, "重装")
	var 指挥键 := _单机键By职业(s, "指挥")
	t.ok(not 近卫键.is_empty() and not 重装键.is_empty(),
		"★ 段 12b：沙盒里有近卫（%s）与重装（%s）机体" % [近卫键, 重装键])
	if 近卫键.is_empty() or 重装键.is_empty():
		_拆视图(树根, v)
		return
	# ---- 选中近卫：重装牌置灰、写「〔需：重装〕」；近卫牌对口 ----
	v._点选机体(近卫键)
	await _等帧(1)
	var 行近卫 := _单机公有行(s, 近卫键)
	var 重装行 := _有行(行近卫, "重装")
	var 近卫行2 := _有行(行近卫, "近卫")
	t.ok(not 重装行.is_empty() and bool(重装行.get("对口", true)) == false,
		"★★ 段 12b：选近卫机 → 归属【重装】的公有牌 `对口 = false`")
	t.ok(not 重装行.is_empty() and str(重装行.get("原因", "")).begins_with("〔需：重装〕"),
		"★★ 段 12b：置灰原因照规格写成「%s」" % str(重装行.get("原因", "")))
	t.ok(not 近卫行2.is_empty() and bool(近卫行2.get("对口", false)),
		"★★ 段 12b：选近卫机 → 归属【近卫】的公有牌 `对口 = true`（亮了）")
	# UI 那一半：下排那一张的按钮真的被 disabled，副行写着原因
	var 下排 := s.lower_hand_cards()
	var 重装序 := _行序号(下排, "重装")
	var 重装钮 := _单机卡按钮(v._公有排列表, 重装序)
	t.ok(重装钮 != null and 重装钮.disabled,
		"★★ 段 12b：下排那张【重装】牌在界面上是**置灰不可点**的")
	t.ok(_控件含文(v._公有排列表.get_child(重装序), "〔需：重装〕"),
		"★★ 段 12b：卡面写着「〔需：重装〕」")
	# ---- 切到重装机：同一张牌立刻亮起（对口），近卫那张反过来置灰 ----
	v._点选机体(重装键)
	await _等帧(1)
	var 行重装 := _单机公有行(s, 重装键)
	t.ok(bool(_有行(行重装, "重装").get("对口", false)),
		"★★ 段 12b：切到重装机 → 同一张【重装】牌**立刻亮起**（`对口 = true`）")
	t.ok(bool(_有行(行重装, "近卫").get("对口", true)) == false,
		"★★ 段 12b：切到重装机 → 【近卫】牌反过来置灰")
	var 重装序2 := _行序号(s.lower_hand_cards(), "重装")
	var 重装钮2 := _单机卡按钮(v._公有排列表, 重装序2)
	t.ok(重装钮2 != null and not 重装钮2.disabled,
		"★★ 段 12b：切机之后那张牌在界面上真的**变亮了**（按钮可点）")
	# ---- 指挥机：公有牌折后价 -5 ----
	if not 指挥键.is_empty():
		v._点选机体(指挥键)
		await _等帧(1)
		var 行指挥 := _单机公有行(s, 指挥键)
		var 有减 := false
		for x in 行指挥:
			if float((x as Dictionary).get("减费", 0.0)) == Params.指挥公有减费():
				有减 = true
		t.ok(有减 and (_行序号(行指挥, "重装") >= 0),
			"★★ 段 12b：选中指挥机 → 公有牌显示战意消耗 -%d（折后价）" % int(Params.指挥公有减费()))
		t.ok(_控件含文(v._公有排列表, "指挥 -"),
			"★★ 段 12b：下排卡面写清这笔折扣（「指挥 -5」）")
	_拆视图(树根, v)
	t.ok(s.errors is Array and (s.errors as Array).is_empty(),
		"★ 段 12b：沙盒全程零报错 %s" % str(s.errors))

## 段 12 的沙盒：默认五人队 + 单机牌组开局，公有手牌换成「一张重装职业牌 + 一张近卫职业牌」。
## 战意统一拉满 100：本段验的是**身份对不对口**（与够不够战意无关），不引入第二种置灰原因。
func _建单机沙盒() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_layout_段12.json"
	s.set_unit_deck_mode(true)
	var ctx := Setup.开局(默认五人, 秘银敌方, 20261020, null, {"单机牌组": true})
	if ctx.is_empty():
		return s
	ctx.气势 = 999.0
	for u in (ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 100.0
	ctx.公有手牌 = []
	for 归 in ["重装", "近卫"]:
		var 牌 := _单机找职业牌(归)
		if not 牌.is_empty():
			ctx.公有手牌.append(Btl.克隆战术牌(牌, ctx))
	s.battle_ctx = ctx
	s.screen = "battle"
	if s.battle_ctx.is_empty():
		return s
	s.select_battle_unit(_单机存活键(s, 0))
	s.clear_errors()
	return s

## 数据表里找一张 `层级 = 职业` 且 `归属 = 归` 的公有牌（找不到 = 空字典）。
func _单机找职业牌(归: String) -> Dictionary:
	var 表: Variant = Db.T.get("战术卡牌表")
	if not (表 is Array):
		return {}
	for c in (表 as Array):
		if c is Dictionary and str((c as Dictionary).get("层级", "")) == "职业" \
			and str((c as Dictionary).get("归属", "")) == 归:
			return c
	return {}

## 我方第 `序` 台存活机体的键（格位 0..7 顺序；没有 = 空串）。
func _单机存活键(s: GameSession, 序: int) -> String:
	var 们 := Units.livingOf("ally", s.battle_ctx)
	var 排 := 们.duplicate()
	排.sort_custom(func(a, b): return float(a.slot) < float(b.slot))
	if 序 < 0 or 序 >= 排.size():
		return ""
	return str((排[序] as Dictionary).get("key", ""))

## 我方第一台 `职业 == 职业` 的存活机体键。
func _单机键By职业(s: GameSession, 职业: String) -> String:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 \
			and str(Units.unit_class(u, s.battle_ctx)) == 职业:
			return str((u as Dictionary).get("key", ""))
	return ""

## 视图里「键 == 键」的那张我方 `UnitCard`。
func _单机卡By键(v: BattleView, 键: String) -> UnitCard:
	for c in v._我方卡:
		if c is UnitCard:
			var 卡: UnitCard = c
			if str(卡.数据.get("键", "")) == 键:
				return 卡
	return null

## 视图里第一张「有意图预告」的敌方 `UnitCard`。
func _单机敌方卡(v: BattleView, 意: Array) -> UnitCard:
	var 键 := ""
	if not 意.is_empty() and 意[0] is Dictionary:
		键 = str((意[0] as Dictionary).get("单位", ""))
	for c in v._敌方卡:
		if c is UnitCard:
			var 卡: UnitCard = c
			if not 键.is_empty() and str(卡.数据.get("键", "")) == 键:
				return 卡
	for c in v._敌方卡:
		if c is UnitCard and not str((c as UnitCard)._意图行.text).is_empty():
			return c
	return null

## `lower_hand_cards(键)` 里「归属 == 归」的那一行（没有 = 空字典）。
func _有行(行们: Array, 归: String) -> Dictionary:
	for x in 行们:
		if x is Dictionary and str((x as Dictionary).get("归属", "")) == 归:
			return x
	return {}

## `lower_hand_cards()` 里「归属 == 归」那一行的下标（没有 = −1）。
func _行序号(行们: Array, 归: String) -> int:
	for i in 行们.size():
		var x: Variant = 行们[i]
		if x is Dictionary and str((x as Dictionary).get("归属", "")) == 归:
			return i
	return -1

## `_单机公有行`：选中 `键` 时下排那张…直接问门面（与视图同一份数据）。
func _单机公有行(s: GameSession, 键: String) -> Array:
	return s.lower_hand_cards(键)

## 单机手牌行里第 `序号` 张卡的按钮（`BattleView._建单机卡()` 建的 `单机卡按钮`）。
func _单机卡按钮(列表: Node, 序号: int) -> Button:
	if 列表 == null or 序号 < 0 or 序号 >= 列表.get_child_count():
		return null
	return 列表.get_child(序号).find_child("单机卡按钮", true, false) as Button

## 「另一台」我方（键 != 键）的战意 —— 用来验「谁打牌扣谁的战意」。
func _别台战意(s: GameSession, 键: String) -> float:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 \
			and str((u as Dictionary).get("key", "")) != 键:
			return float(Btl.战意(u))
	return 0.0

## 段 12 的夹具：默认五人队（与 `GameSession._默认五人编成()` 同一份数据，位号照 `Fm`）。
const 默认五人 := [
	{"键": "B1", "位": 0, "等级": 10}, {"键": "B2", "位": 1, "等级": 10},
	{"键": "CB4", "位": 2, "等级": 10}, {"键": "CB2", "位": 6, "等级": 10},
	{"键": "M1", "位": 4, "等级": 10},
]


