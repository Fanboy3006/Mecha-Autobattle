## 职责：版面门禁的公共夹具（原 `test_presentation_layout.gd` 顶部「工具」一节 + 各段共用的造局面 / 读控件辅助）。
class_name LayoutFixtures
extends RefCounted

## 子套件的 `run()` 是空实现（见下）：每一段一律由 `test_presentation_layout.gd` 按原顺序调 `走一遍()`，保证只跑一次。
func run(_t) -> void:
	pass

const BOOT_TSCN := "res://presentation/boot/boot.tscn"
const 画布宽 := 1280.0
const 画布高 := 720.0
const 顶栏高 := 104.0
const 屏们 := ["menu", "squad", "map", "formation", "battle", "result"]
const 顶栏右按钮们 := ["招募按钮", "编队按钮", "战术牌库按钮", "保存回菜单按钮"]
const 秘银我方 := [
	{"键": "U7", "位": 0, "等级": 10}, {"键": "U6", "位": 1, "等级": 10},
	{"键": "U2", "位": 2, "等级": 10}, {"键": "U1", "位": 3, "等级": 10},
	{"键": "U8", "位": 4, "等级": 10},
]
const 秘银敌方 := [{"键": "flagship", "位": 0, "等级": 1}, {"键": "bluefish", "位": 1, "等级": 1}]

func _根() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

func _等帧(n: int = 2) -> void:
	for _i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame

func _设视口(树根: Node, 尺寸: Vector2) -> void:
	if 树根 is Window:
		(树根 as Window).size = Vector2i(int(尺寸.x), int(尺寸.y))

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

func _叠(a: Rect2, b: Rect2) -> bool:
	var 交 := a.intersection(b)
	return 交.size.x > 0.001 and 交.size.y > 0.001

func _交面积(a: Rect2, b: Rect2) -> float:
	var 交 := a.intersection(b)
	return maxf(交.size.x, 0.0) * maxf(交.size.y, 0.0)

func _短(r: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]

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

func _弹窗可见(boot) -> bool:
	var 层: Variant = boot.find_child("弹窗层", true, false)
	return 层 is Control and (层 as Control).visible

func _弹窗类型(s: GameSession) -> String:
	if s == null or not (s.modal is Dictionary):
		return ""
	return str((s.modal as Dictionary).get("类型", ""))

func _关弹窗(boot) -> void:
	boot.关闭弹窗()
	await _等帧(2)

func _清待选(s: GameSession) -> int:
	var 选 := 0
	while s != null and s.run_state != null and not s.run_state.pending_card_picks.is_empty() and 选 < 12:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选 += 1
	return 选

func _清券(s: GameSession) -> int:
	var 丢 := 0
	while s != null and s.ticket_count() > 0 and 丢 < 12:
		if not bool(s.discard_ticket(0).get("ok", false)):
			break
		丢 += 1
	return 丢

# 段 1：单屏可见性 + 弹窗不误遮挡（「多个界面叠加」的根治）

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

func _编队第一台(s: GameSession) -> bool:
	if s == null or s.run_state == null or s.run_state.roster.is_empty():
		return false
	var 位名 := str(s.lineup_slots()[0].get("位名", ""))
	for k in s.run_state.roster.keys():
		if s.set_lineup_slot(str(k), 位名):
			return true
	return false

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

func _找战斗格(s: GameSession) -> int:
	if s == null or s.run_state == null:
		return -1
	for id in s.run_state.grid().keys():
		var t := str(s.run_state.cell_at(int(id)).get("类型", ""))
		if t in ["作战", "精英", "出口守军", "侵蚀源"]:
			return int(id)
	return -1

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

func _日志有(ctx: Dictionary, 片段: String) -> bool:
	var 日志: Variant = ctx.get("log")
	if not (日志 is Array):
		return false
	for e in (日志 as Array):
		if e is Dictionary and str((e as Dictionary).get("文本", "")).contains(片段):
			return true
	return false

# ---------------- ① 预告层：连携计数 + 金边 + 悬停 ----------------

func _单机存活键(s: GameSession, 序: int) -> String:
	var 们 := Units.livingOf("ally", s.battle_ctx)
	var 排 := 们.duplicate()
	排.sort_custom(func(a, b): return float(a.slot) < float(b.slot))
	if 序 < 0 or 序 >= 排.size():
		return ""
	return str((排[序] as Dictionary).get("key", ""))

func _左库有标签(v: BattleView, 片段: String) -> bool:
	if v._左牌库列表 == null:
		return false
	for c in v._左牌库列表.get_children():
		if _控件含文(c, 片段):
			return true
	return false

func _左库按钮全禁用(v: BattleView) -> bool:
	for c in v.左库卡控件们():
		var b := (c as Node).find_child("左库卡按钮", true, false) as Button
		if b != null and not b.disabled:
			return false
	return true

func _单位Of键(s: GameSession, 键: String) -> Dictionary:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

func _卡By键(v: BattleView, 方: String, 键: String) -> UnitCard:
	var 池: Array = v._我方卡 if 方 == "ally" else v._敌方卡
	for c in 池:
		if c is UnitCard and str((c as UnitCard).数据.get("键", "")) == 键:
			return c
	return null

func _心(卡: Control) -> Vector2:
	var r: Rect2 = 卡.get_global_rect()
	return r.position + r.size * 0.5

func _手牌视图ById(s: GameSession, id: String) -> Dictionary:
	for 列 in [s.upper_hand_cards(), s.lower_hand_cards()]:
		for c in (列 as Array):
			if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
				return c
	return {}
