## 职责：会话门面 —— 玩家命令的唯一入口；表现为**零 `J.*`**、**零引擎依赖**的纯逻辑对象。
##
## 本文件是**门面 + 转发层**：只留成员变量 / 信号 / 「一」开局与存档 /「一之二」状态读数 /
##   「五」战斗命令入口 /「七」内部工具，以及全部搬迁函数的**同名一行转发**。
##   各章实现落在 `session/` 下的子模块（`SessionLiveMonitor` / `SessionRunFacade` / `SessionRosterFacade` /
##   `SessionBattleFlow` / `SessionBattleHandView` / `SessionBattleDeckView` / `SessionDisplayHelpers` /
##   `SessionTooltipText`），参数显式传 `session: GameSession`，不反向持有门面。
##
## 纪律：零 `J.*`（四舍五入 `JsCompat.js_round`、稳定排序 `JsCompat.stable_sort`、随机 `Mulberry32`）；
##   唯一存档 IO 出口 = `SaveService`；任意 Variant 转字符串一律 `str(x)`；
##   从不直接改内核语义 —— 所有规则调 `core/` 的真实函数，本文件只做「命令 → 内核 → 快照」。
##   历史纠错记录（D-03 / D-06 / D-07 / D-08 / D-10 等）见提交记录与任务单，不在代码里复述。
class_name GameSession
extends RefCounted

signal changed()
signal errored(msg: String)
signal action_recorded(entry: Dictionary)

const 存档文件名 := "user://save.json"
const 快速战斗种子偏移 := 8801
const 默认分队 := "混编"
const 动作历史上限 := 100
const 错误上限 := 50

var run_state: RunState = null
var battle_ctx: Dictionary = {}
var screen: String = "menu"
var modal: Dictionary = {}
var last: Dictionary = {}
var errors: Array = []
var pending_battle_confirm: bool = false
var pending_battle_kind: String = ""
var selected_unit_id: String = ""
var _当前错误: String = ""
var _action_seq: int = 0
var action_history: Array = []
var _在看快照: bool = false
var 存档路径: String = 存档文件名
var _unit_switches: Dictionary = {}
var _node_result: Dictionary = {}
var _result_cache: Dictionary = {}
var _血比战前: Dictionary = {}
var _quick_battle: bool = false
var _全卡池体验: bool = false
var _快速测试局: bool = false
var _本场格类型: String = ""
var _本场已结算: bool = false
var _已结算节点键: Dictionary = {}

## D-10 的判据表（只有「节点类型」这一项输入 
const _要先结算的类型 := [
	"作战", "精英", "守军", "侵蚀源", "出口守军",
	"休整", "黑市", "事件", "瞭望站", "遗迹", "隧道", "招募站",
]
const 快速测试_秘银 := "秘银"
const 快速测试_ATX := "ATX"
const 快速测试_天人 := "天人"
const 快速测试_殖民卫星军 := "殖民卫星军"
## ★ COL-4：殖民卫星军五人的快速试玩编成（全员 Lv30；站位同旧单 §1.7：迪奥 / 特洛瓦 / 拉克丝在前排，卡嘉莉 / 希罗在后排）。
const 殖民卫星军快速编成 := [
	{"键": "W2", "位": 0, "等级": 30},
	{"键": "W3", "位": 1, "等级": 30},
	{"键": "S1", "位": 2, "等级": 30},
	{"键": "S2", "位": 4, "等级": 30},
	{"键": "W1", "位": 5, "等级": 30},
]
## ★ CB-4：天人五人的快速试玩编成（全员 Lv30）
const 天人快速编成 := [
	{"键": "CB1", "位": 0, "等级": 30},
	{"键": "CB3", "位": 1, "等级": 30},
	{"键": "CB5", "位": 2, "等级": 30},
	{"键": "CB2", "位": 4, "等级": 30},
	{"键": "CB4", "位": 5, "等级": 30},
]
## ★ A7：ATX 五人的快速试玩编成（全员 Lv30）
const ATX快速编成 := [
	{"键": "A1", "位": 0, "等级": 30},
	{"键": "A6", "位": 3, "等级": 30},
	{"键": "A3", "位": 4, "等级": 30},
	{"键": "A7", "位": 5, "等级": 30},
	{"键": "A2", "位": 7, "等级": 30},
]
const 战后给券率 := 0.90
const 单机区_主武器 := "主武器卡"
const 单机区_衍生 := "衍生攻击卡"
const 单机区_精神 := "专属精神牌"
const 单机区_公有 := "公有牌"
const 单机区_副武器 := "副武器卡"
const 单机区_大招槽 := "大招槽卡"
const 单机区_筹码 := "筹码牌"
const 目标方_友方 := "友方"
const 目标方_敌方 := "敌方"
const 目标方_无 := "无"
## ★ MITH3-4 / 任务单 §1.5：秘银五小强的「完整体验池」编成（宗介 / 克鲁兹 / 毛 / 克鲁佐 / 杨）
const 秘银快速编成 := [
	{"键": "U7", "位": 0, "等级": 30},
	{"键": "U1", "位": 1, "等级": 30},
	{"键": "U6", "位": 5, "等级": 30},
	{"键": "U2", "位": 6, "等级": 30},
	{"键": "U8", "位": 7, "等级": 30},
]

# 一、开局与存档

func start_new_run(seed_val: int, squad: String = 默认分队) -> bool:
	return _record_action("start_new_run", {"seed_val": seed_val, "squad": squad}, _开始新局(seed_val, squad))

func _开始新局(seed_val: int, squad: String = 默认分队) -> bool:
	_data_ready()
	var s := RosterManager.new_run(seed_val, squad if not squad.is_empty() else 默认分队)
	if s == null:
		_fail("开局失败：内核没有给出 RunState", {"ok": false})
		return false
	run_state = s
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_全卡池体验 = false
	_快速测试局 = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	# 单机牌组是唯一模式 → 这一局的名册标记永远写 true（`DeckBuilder` 的三选一口径读它）。
	RosterManager.特置(run_state, "单机牌组", true)
# ★ D-06 纠错：**开局不产生待选战术牌**。封存 JS 里 `R.待选战术牌` 只在
	last = {"行动": "开新局", "种子": seed_val, "分队": run_state.squad,
		"层": run_state.floor_num, "起源碳": run_state.carbon, "起希望": run_state.hope,
		"券": run_state.tickets.size(), "日志": _tail_logs(3)}
	_set_screen("map")
	return true

func save_current_run() -> bool:
	return _record_action("save_current_run", {}, _存当前局())

func _存当前局() -> bool:
	if run_state == null:
		_fail("没有进行中的局，存不了", {"ok": false})
		return false
	var ok := SaveService.save_to_file(run_state, 存档路径)
	last = {"行动": "存档", "成功": ok, "路径": 存档路径, "层": run_state.floor_num}
	if not ok:
		_fail("存档写不进去（%s）" % 存档路径, last)
	_emit()
	return ok

func load_saved_run() -> bool:
	return _record_action("load_saved_run", {}, _读存档())

func _读存档() -> bool:
	var s := SaveService.load_from_file(存档路径)
	if s == null:
		_fail("没有可读的存档（%s）" % 存档路径, {"ok": false})
		return false
	run_state = s
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_全卡池体验 = false
	_快速测试局 = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	last = {"行动": "读档", "路径": 存档路径, "层": run_state.floor_num,
		"源碳": run_state.carbon, "希望": run_state.hope, "名册": run_state.roster.size(),
		"日志": _tail_logs(3)}
	_set_screen("map")
	return true

func has_saved_run() -> bool:
	return SaveService.load_from_file(存档路径) != null

func available_squads() -> Array:
	_data_ready()
	var out: Array = []
	var 表 := Db.catalog.squads()
	if 表.is_empty():
		return out
	for e in 表:
		if e is Dictionary:
			var 名 := str(e.get("名", e.get("id", "")))
			if not 名.is_empty():
				out.append(名)
		elif e is String:
			out.append(str(e))
	return out

# 一之二、给 UI 用的状态读数（纯读）

func in_battle() -> bool:
	return not battle_ctx.is_empty()

func is_quick_battle() -> bool:
	return _quick_battle

func ticket_count() -> int:
	return run_state.tickets.size() if run_state != null else 0

func roster_count() -> int:
	return run_state.roster.size() if run_state != null else 0

func 还没走过格() -> bool:
	if run_state == null:
		return false
	return run_state.nodes_cleared == 0 and run_state.battles_fought == 0

func 有未决的招募券() -> bool:
	return ticket_count() > 0

func 战前编队确认中() -> bool:
	return pending_battle_confirm

func 当前动作错误() -> String:
	return _当前错误

## 这一格的「结算键」（`"层:格"`）
func 当前节点结算键() -> String:
	if run_state == null:
		return ""
	return "%d:%d" % [run_state.floor_num, run_state.node_id]

func 节点已结算过() -> bool:
	var 键 := 当前节点结算键()
	return not 键.is_empty() and _已结算节点键.has(键)

func return_to_menu() -> void:
	_回主菜单()
	_record_action("return_to_menu", {}, null)

func _回主菜单() -> void:
# ★ 第 7 项断路器修复（DS41F）：快速测试战斗顺手造的「假肉鸽」**不落盘** ——
	var 别存 := _快速测试局
	if not 别存 and run_state != null and run_state.status == "进行中":
		SaveService.save_to_file(run_state, 存档路径)
	run_state = null
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_全卡池体验 = false
	_快速测试局 = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	modal = {}
	_set_screen("menu")

# 一之二之三、战后回大地图（唯一实现）

func return_to_map_after_battle() -> Dictionary:
	return _record_action("return_to_map_after_battle", {}, _回大地图清战斗())

func _回大地图清战斗() -> Dictionary:
	if not battle_ctx.is_empty() and not _本场已结算:
		return _fail("这一场还没结算完（先在结算屏点「结算这一场」）", {"ok": false})
	var 清过 := not battle_ctx.is_empty()
	battle_ctx = {}
	_本场已结算 = false
	_本场格类型 = ""
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	last = {"行动": "回大地图", "清了战斗上下文": 清过, "屏幕": "map"}
	_set_screen("map")
	return {"ok": true, "清了战斗上下文": 清过, "屏幕": str(screen)}

# 五、战斗命令入口（实现见 SessionBattleFlow）

## 一键开 ATX 五人测试战（Lv30）
func 开始快速测试战斗(阵容: String = 快速测试_秘银, seed_val: int = 20261013) -> bool:
	var 种 := _规范快速阵容(阵容)
	return _record_action("start_quick_test_battle", {"阵容": 种, "seed_val": seed_val},
		_开快速测试战(种, seed_val))

func start_quick_test_battle(阵容: String = 快速测试_秘银, seed_val: int = 20261013) -> bool:
	return 开始快速测试战斗(阵容, seed_val)

func start_quick_battle_celestial(seed_val: int = 20261018) -> bool:
	return _record_action("start_quick_battle_celestial", {"seed_val": seed_val},
		_开快速测试战(快速测试_天人, seed_val))

## ★ COL-4：快速测试战斗（殖民卫星军五人）—— 觉醒 / 感应牌库 / METEOR 全在这里。
func start_quick_battle_colonial(seed_val: int = 20261018) -> bool:
	return _record_action("start_quick_battle_colonial", {"seed_val": seed_val},
		_开快速测试战(快速测试_殖民卫星军, seed_val))

func 开始快速测试战斗_殖民卫星军(seed_val: int = 20261018) -> bool:
	return start_quick_battle_colonial(seed_val)

func 开始快速测试战斗_天人(seed_val: int = 20261018) -> bool:
	return start_quick_battle_celestial(seed_val)

func start_node_battle() -> bool:
	return _record_action("start_node_battle", {}, _开节点战())

func prepare_battle_formation(kind: String = "node") -> Dictionary:
	return _record_action("prepare_battle_formation", {"kind": kind}, _准备战前编队(kind))

func 准备战斗编队(kind: String = "node") -> Dictionary:
	return prepare_battle_formation(kind)

func confirm_formation_and_start_battle() -> Dictionary:
	return _record_action("confirm_formation_and_start_battle", {}, _确认编队开战())

func 确认编队并开战() -> Dictionary:
	return confirm_formation_and_start_battle()

func toggle_unit_switch(unit_id: String, switch_key: String) -> bool:
	return _record_action("toggle_unit_switch", {"unit_id": unit_id, "switch_key": switch_key}, _切开关(unit_id, switch_key))

func step_battle_turn() -> Dictionary:
	return _record_action("step_battle_turn", {}, _打一回合())

func auto_finish_battle() -> Dictionary:
	return _record_action("auto_finish_battle", {}, _自动打完())

func finish_battle_and_settle() -> Dictionary:
	return _record_action("finish_battle_and_settle", {}, _结算这一场())

# 七、内部工具：状态出口 / 选项 / 找单位 / 编队与结算

func unit_switches() -> Dictionary:
	return _unit_switches.duplicate(true)

func current_node_result() -> Dictionary:
	return _node_result.duplicate(true)

func _set_screen(v: String) -> void:
	var 前屏 := screen
	screen = v
# ★ 切屏时把「常驻盖屏」的那两类弹窗收掉（`结算` / `战斗`）：
	if v != 前屏:
		var 类 := str(modal.get("类型", ""))
		if 类 == "结算" or 类 == "战斗":
			modal = {}
	_refresh_modal()
	_emit()

func _emit() -> void:
	changed.emit()

func _fail(msg: String, extra: Dictionary) -> Dictionary:
	if msg.is_empty():
		msg = "命令被拒绝"
	_记错误(msg)
	_当前错误 = msg
	var d := {"ok": false, "为什么": msg, "屏幕": screen}
	for k in extra.keys():
		d[k] = extra[k]
	last = d.duplicate(true)
	errored.emit(msg)
	_emit()
	return d

## 记一条错误流水（★ UX-1 第 6 项：**保留最近 `错误上限` 条**，最老的先丢）
func _记错误(msg: String) -> void:
	errors.append(msg)
	while errors.size() > 错误上限:
		errors.remove_at(0)

func clear_errors() -> void:
	errors.clear()
	_当前错误 = ""

func _need_run() -> RunState:
	_data_ready()
	return run_state

func _data_ready() -> void:
	if Db.installed:
		return
	var errs: Array = []
	DataLoader.install(errs)

## `_unit_switches` 的兼容读法：优先用自己那张表，其次读 ctx["选项"]（内核存在那儿的选项）
func 表(ctx: Dictionary, 键: String) -> Dictionary:
	var v: Variant = ctx.get(键)
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return _unit_switches.duplicate(true)

func unit_switch_table(ctx: Dictionary, 键: String = "选项") -> Dictionary:
	return 表(ctx, 键)

func _build_battle_options() -> Dictionary:
	return SessionBattleOptions.生产(run_state, _全卡池体验)

## ★ DECK-2：`NodeResolver.开战()` 那条路（节点战 / 追击战）并进选项里的那一份 ——
## 与 `_build_battle_options()` **同一个来源**（`SessionBattleOptions.生产`），不再只写两个键。
func _附加战斗选项() -> Dictionary:
	return SessionBattleOptions.生产(run_state, false)

func _默认五人编成() -> Array:
	_data_ready()
	var 表队: Variant = Db.T.get("默认五人队")
	if not (表队 is Array):
		return []
	var out: Array = []
	for e in (表队 as Array):
		if not (e is Dictionary):
			continue
		var 键 := str(e.get("键", ""))
		if 键.is_empty():
			continue
		var 等级 := float(e.get("等级", 10)) if e.get("等级") != null else 10.0
		out.append({"键": 键, "等级": 等级, "hp比": 1.0})
	return out

func _秘银五人编成() -> Array:
	var out: Array = []
	for e in 秘银快速编成:
		out.append({"键": str(e["键"]), "等级": float(e["等级"]), "位": float(e["位"]), "hp比": 1.0})
	return out

## ★ A7：ATX 五人的快速试玩编成（全员 Lv30
func _ATX五人编成() -> Array:
	var out: Array = []
	for e in ATX快速编成:
		out.append({"键": str(e["键"]), "等级": float(e["等级"]), "位": float(e["位"]), "hp比": 1.0})
	return out

## ★ CB-4：天人五人的快速试玩编成（全员 Lv30
func _天人五人编成() -> Array:
	var out: Array = []
	for e in 天人快速编成:
		out.append({"键": str(e["键"]), "等级": float(e["等级"]), "位": float(e["位"]), "hp比": 1.0})
	return out

## ★ COL-4：殖民卫星军五人的快速试玩编成。
func _殖民卫星军五人编成() -> Array:
	var out: Array = []
	for e in 殖民卫星军快速编成:
		out.append({"键": str(e["键"]), "等级": float(e["等级"]), "位": float(e["位"]), "hp比": 1.0})
	return out

## ★ COL-4：感应牌库左栏那行（全队一份，一 / 二 / 三级张数 + 移出）。
func 感应牌库左栏文() -> String:
	if battle_ctx.is_empty():
		return ""
	return ColonialDeck.感应牌库左栏文(battle_ctx)

## ★ COL-4b：感应牌库明细（左栏那个「可点开看库内牌」的面板读它）。
## `有 = false` = 这一场没有殖民卫星军（没装感应牌库），面板不给开。
func 感应牌库状态() -> Dictionary:
	if battle_ctx.is_empty() or ColonialDeck.库(battle_ctx) == null:
		return {"有": false, "明细": [], "移出": [], "各级": {}, "文案": ""}
	return {
		"有": true, "明细": ColonialDeck.感应牌库明细(battle_ctx),
		"移出": ColonialDeck.感应移出明细(battle_ctx),
		"各级": ColonialDeck.各级张数(battle_ctx),
		"文案": ColonialDeck.感应牌库左栏文(battle_ctx),
	}

## ★ COL-4：QTE 结果模式（`manual` / `perfect` / `good` / `miss` / `random`）。
func get_qte_mode() -> String:
	if battle_ctx.is_empty():
		return "manual"
	var 选 = battle_ctx.get("选项")
	if 选 is Dictionary and (选 as Dictionary).get("QTE结果") != null:
		return str((选 as Dictionary).get("QTE结果"))
	return "manual"

func set_qte_mode(mode: String) -> void:
	if battle_ctx.is_empty():
		return
	if not battle_ctx.get("选项") is Dictionary:
		battle_ctx["选项"] = {}
	battle_ctx["选项"]["QTE结果"] = mode

## 手动选择 → 固定完美 → 固定成功 → 固定失手 → 随机（顶栏那个紧凑按钮循环用）。
func cycle_qte_mode() -> String:
	var 序 := ["manual", "perfect", "good", "miss", "random"]
	var 现 := 序.find(get_qte_mode())
	var 下 := str(序[(现 + 1) % 序.size()] if 现 >= 0 else "manual")
	set_qte_mode(下)
	return 下

## QTE 模式的中文标签（顶栏按钮文案）。
static func QTE模式文(mode: String) -> String:
	return {"manual": "手动选择", "perfect": "固定完美", "good": "固定成功", "miss": "固定失手", "random": "随机"}.get(mode, "手动选择")

func _第几层普通编成(层: int):
	var 表 := Db.catalog.stages()
	for e in 表:
		if e is Dictionary and int(e.get("层", 0)) == 层 and str(e.get("类型", "")) == "普通":
			return e
# 该层没有「普通」→ 退到全表第一条（兜底，不崩）
	for e in 表:
		if e is Dictionary:
			return e
	return {}

func _找单位(unit_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return {}
	var 池: Variant = battle_ctx.get("allies")
	if 池 is Array:
		for x in (池 as Array):
			if x is Dictionary and (str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id):
				return x
	池 = battle_ctx.get("enemies")
	if 池 is Array:
		for x in (池 as Array):
			if x is Dictionary and (str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id):
				return x
	return {}

func _位名合法(slot_name: String) -> bool:
	return _位号(slot_name) >= 0

## 格位 → 位号
func _位号(slot_name: String) -> int:
	var n := int(Fm.SLOTS())
	for i in n:
		if Fm.位名(float(i)) == slot_name:
			return i
	var v := NodeResolver.解析槽位(slot_name)
	if v >= 0 and v < n:
		return v
	return -1

func _条位号(x: Variant) -> int:
	if x is Dictionary:
		return NodeResolver.解析槽位((x as Dictionary).get("slot"))
	return -1

func _在出击里(s: RunState, unit_key: String) -> bool:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return true
	return false

## 这一台在出击名单里占的位号（不在 → −1）
func _在出击的第几格(s: RunState, unit_key: String) -> int:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return _条位号(x)
	return -1

func _压实出击位(s: RunState) -> Dictionary:
	var 位表 := {}
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var k := str(x.get("key", ""))
		var 位 := _条位号(x)
		if k.is_empty() or 位 < 0 or 位 >= int(Fm.SLOTS()):
			continue
		位表[位] = k
	return 位表

func _清理重复占格(s: RunState = null) -> bool:
	return _规范编队槽位(s)

## ★ UX-4（M4 二轮试玩反馈 1）：把出击名单压成
func _规范编队槽位(s: RunState = null) -> bool:
	var 局 := s if s != null else run_state
	if 局 == null:
		return false
	var 上限 := int(Fm.SLOTS())
	var 见过键 := {}
	var 已占 := {}
	var 清: Array = []
	var 脏 := false
	for x in 局.lineup:
		var 键 := ""
		var 槽: Variant = null
		var 是字典 := x is Dictionary
		if 是字典:
			键 = str((x as Dictionary).get("key", ""))
			槽 = (x as Dictionary).get("slot")
		elif x is String:
			键 = str(x)
		else:
			脏 = true
			continue
		if 键.is_empty() or 见过键.has(键):
			脏 = true
			continue
		见过键[键] = true
		var 位 := NodeResolver.解析槽位(槽)
		if 位 >= 0 and 位 < 上限 and not 已占.has(位):
# ★ 玩家指定的格位**原样保留**；只有「写法不标准」才改写同一数值。
			if not 是字典 or not (槽 is int) or int(槽) != 位:
				脏 = true
		else:
			位 = _空位兜底(键, 清.size(), 已占)
			脏 = true
		if 位 < 0:
			清.append({"key": 键, "slot": -1})
			continue
		已占[位] = true
		清.append({"key": 键, "slot": 位})
	if not 脏:
		return false
	局.lineup = 清
	return true

func _空位兜底(键: String, 序: int, 已占: Dictionary) -> int:
	var 上限 := int(Fm.SLOTS())
	var 位 := NodeResolver.默认位号(键, 序)
	if 位 >= 0 and 位 < 上限 and not 已占.has(位):
		return 位
	for i in 上限:
		if not 已占.has(i):
			return i
	return -1

func _位表到出击(位表: Dictionary) -> Array:
	var 位们 := []
	for 位 in 位表.keys():
		位们.append(int(位))
	位们 = JsCompat.stable_sort(位们, func(a, b): return int(a) < int(b))
	var out: Array = []
	for 位 in 位们:
		out.append({"key": str(位表[位]), "slot": int(位)})
	return out

## `位表` 里没用掉的最小格位（诊断 / 兜底用）
func _第一个空位(位表: Dictionary) -> int:
	for i in int(Fm.SLOTS()):
		if not 位表.has(i):
			return i
	return 0

func _名册血比() -> Dictionary:
	var out := {}
	if run_state == null:
		return out
	for k in run_state.roster.keys():
		out[str(k)] = float(run_state.get_unit_hp_ratio(str(k)))
	return out

func _tail_logs(n: int) -> Array:
	if run_state == null:
		return []
	var 全: Array = run_state.logs
	var 起 := maxi(0, 全.size() - maxi(0, n))
	var out: Array = []
	for i in range(起, 全.size()):
		out.append(str(全[i]))
	return out

## 每回合打牌的即时小计（UI 底栏那一行）—— 只报回合；单机牌组的其余小计由 `deck_turn_summary()` 补。
func turn_card_summary() -> Dictionary:
	return {
		"回合": int(float(battle_ctx.get("turn", 0.0))) if not battle_ctx.is_empty() else 0,
	}

func _build_result_cache(内核: Dictionary) -> Dictionary:
# 在调内核之前抓），`血比后` 用结算之后的现值。绝不能在这里现取「前」——那时内核已经回完血了。
	var 前: Dictionary = _血比战前.duplicate() if not _血比战前.is_empty() else _名册血比()
# ★ MITH-3 结算层：本场「触发连携次数 / 打出 TDD-1 数」直接抄内核 `战况计数`（表现层不自己算）。
	var 计: Dictionary = battle_ctx.get("战况计数") if battle_ctx.get("战况计数") is Dictionary else {}
	var 结算: Dictionary = 内核
	return {
		"胜": bool(结算.get("胜", false)), "结果": _战果文字(),
		"原因": str((battle_ctx.get("result") as Dictionary).get("原因", "")) if battle_ctx.get("result") is Dictionary else "",
		"回合数": int(float(battle_ctx.get("turn", 0.0))) if not battle_ctx.is_empty() else 0,
		"触发连携次数": int(计.get("触发连携", 0)),
		"打出TDD1数": int(计.get("打出TDD1", 0)),
		"秘银v02": false,
		"格类型": str(结算.get("格类型", "")), "通关": bool(run_state.status == "胜利") if run_state != null else false,
		"结束": bool(结算.get("结束", false)), "扣": int(结算.get("扣", 0)),
		"希望": int(结算.get("希望", 0)), "源碳": int(结算.get("源碳", 0)),
		"券": 结算.get("券", null), "藏品": 结算.get("藏品", null), "额外编制": 结算.get("额外编制", null),
		"零件": 结算.get("零件", null), "额外": 结算.get("额外", {}), "奖励档": str(结算.get("奖励档", "")),
		"带伤": int(结算.get("带伤", 0)), "倒下": int(结算.get("倒下", 0)),
		"回血": 结算.get("回血", {}), "名册回血前": 前, "结算": 结算,
	}

## 自动弹窗的**唯一**判据（D-06 / 「面板溢出与叠加」根治）：
func _refresh_modal() -> void:
	if run_state != null and not run_state.pending_card_picks.is_empty():
		modal = {"类型": "三选一", "数据": run_state.pending_card_picks.duplicate()}
		return
	if str(modal.get("类型", "")) == "三选一":
		modal = {}

## 界面文本：本文件是**唯一**持有表现层依赖的地方（复用纯格式化函数 `UiTheme.文本()`，见 RouteMap §4.2 层间豁免）。
func _界面文本(v: Variant) -> String:
	return UiTheme.文本(v)

# ==========================================================================================
# 转发层：以下函数体已搬进 `session/` 子模块，这里只保留同名一行转发（调用点一行不用改）。

# ---- 转发 → SessionLiveMonitor（一之三 实时监视） ----
func snapshot_for_monitor() -> Dictionary:
	return SessionLiveMonitor.snapshot_for_monitor(self)

func _监控券表(s: RunState) -> Array:
	return SessionLiveMonitor._监控券表(self, s)

func _监控待选牌(s: RunState) -> Dictionary:
	return SessionLiveMonitor._监控待选牌(self, s)

func _监控名册(s: RunState) -> Array:
	return SessionLiveMonitor._监控名册(self, s)

func _监控编队(s: RunState) -> Dictionary:
	return SessionLiveMonitor._监控编队(self, s)

func _监控藏品(s: RunState) -> Dictionary:
	return SessionLiveMonitor._监控藏品(self, s)

func _监控零件(s: RunState) -> Dictionary:
	return SessionLiveMonitor._监控零件(self, s)

func _收在场(out: Array, 池名: String) -> void:
	SessionLiveMonitor._收在场(self, out, 池名)

func _监控名(键: String) -> String:
	return SessionLiveMonitor._监控名(self, 键)

func _record_action(act: String, args: Dictionary, res: Variant) -> Variant:
	return SessionLiveMonitor._record_action(self, act, args, res)

# ---- 转发 → SessionRunFacade（二 大地图与零件 / 四 非战斗节点） ----
func preview_cell_move(cell_id: int) -> Dictionary:
	return SessionRunFacade.preview_cell_move(self, cell_id)

func move_to_cell(cell_id: int) -> Dictionary:
	return SessionRunFacade.move_to_cell(self, cell_id)

func move_to(cell_id: int) -> Dictionary:
	return SessionRunFacade.move_to(self, cell_id)

func _走一格(cell_id: int) -> Dictionary:
	return SessionRunFacade._走一格(self, cell_id)

func use_part(part_idx: int, target_cell: int = -1) -> Dictionary:
	return SessionRunFacade.use_part(self, part_idx, target_cell)

func use_part_on_cell(idx: int, cell_id: int = -1) -> Dictionary:
	return SessionRunFacade.use_part_on_cell(self, idx, cell_id)

func _用零件(part_idx: int, target_cell: int) -> Dictionary:
	return SessionRunFacade._用零件(self, part_idx, target_cell)

func _这一格要先结算吗(s: RunState) -> bool:
	return SessionRunFacade._这一格要先结算吗(self, s)

func _接追击战(s: RunState, 已结算: bool = false) -> bool:
	return SessionRunFacade._接追击战(self, s, 已结算)

func _收尾这一格(s: RunState) -> bool:
	return SessionRunFacade._收尾这一格(self, s)

func fight_chase_battle() -> bool:
	return SessionRunFacade.fight_chase_battle(self)

func trigger_pursuit_battle() -> bool:
	return SessionRunFacade.trigger_pursuit_battle(self)

func _打追击战() -> bool:
	return SessionRunFacade._打追击战(self)

func _开追击战(s: RunState, 在出口: bool) -> bool:
	return SessionRunFacade._开追击战(self, s, 在出口)

func enter_current_node() -> Dictionary:
	return SessionRunFacade.enter_current_node(self)

func _进当前格() -> Dictionary:
	return SessionRunFacade._进当前格(self)

func try_advance_floor() -> Dictionary:
	return SessionRunFacade.try_advance_floor(self)

func advance_floor() -> Dictionary:
	return SessionRunFacade.advance_floor(self)

func _换层() -> Dictionary:
	return SessionRunFacade._换层(self)

func resolve_rest(choice: String = "耐久") -> Dictionary:
	return SessionRunFacade.resolve_rest(self, choice)

func rest_action(choice: String = "耐久") -> Dictionary:
	return SessionRunFacade.rest_action(self, choice)

func _结算休整(choice: String = "耐久") -> Dictionary:
	return SessionRunFacade._结算休整(self, choice)

func buy_from_shop(relic_id: String) -> Dictionary:
	return SessionRunFacade.buy_from_shop(self, relic_id)

func shop_buy(relic_id: String) -> Dictionary:
	return SessionRunFacade.shop_buy(self, relic_id)

func _黑市买(relic_id: String) -> Dictionary:
	return SessionRunFacade._黑市买(self, relic_id)

func refresh_shop() -> Dictionary:
	return SessionRunFacade.refresh_shop(self)

func _黑市刷新() -> Dictionary:
	return SessionRunFacade._黑市刷新(self)

func sell_part_in_shop(part_idx: int) -> Dictionary:
	return SessionRunFacade.sell_part_in_shop(self, part_idx)

func _黑市卖零件(part_idx: int) -> Dictionary:
	return SessionRunFacade._黑市卖零件(self, part_idx)

func leave_shop() -> bool:
	return SessionRunFacade.leave_shop(self)

func _离开黑市() -> bool:
	return SessionRunFacade._离开黑市(self)

func resolve_event_choice(choice: String = "") -> Dictionary:
	return SessionRunFacade.resolve_event_choice(self, choice)

func event_choose(choice: String = "") -> Dictionary:
	return SessionRunFacade.event_choose(self, choice)

func _结算奇遇(choice: String = "") -> Dictionary:
	return SessionRunFacade._结算奇遇(self, choice)

func current_event_choices() -> Array:
	return SessionRunFacade.current_event_choices(self)

# ---- 转发 → SessionRosterFacade（三 名册 / 招募 / 晋升 / 编队） ----
func recruit_unit(unit_key: String, ticket_idx: int = -1) -> Dictionary:
	return SessionRosterFacade.recruit_unit(self, unit_key, ticket_idx)

func _招募(unit_key: String, ticket_idx: int = -1) -> Dictionary:
	return SessionRosterFacade._招募(self, unit_key, ticket_idx)

func discard_ticket(ticket_idx: int = 0) -> Dictionary:
	return SessionRosterFacade.discard_ticket(self, ticket_idx)

func _丢券(ticket_idx: int = 0) -> Dictionary:
	return SessionRosterFacade._丢券(self, ticket_idx)

func promote_unit(unit_key: String) -> Dictionary:
	return SessionRosterFacade.promote_unit(self, unit_key)

func _晋升(unit_key: String) -> Dictionary:
	return SessionRosterFacade._晋升(self, unit_key)

func pick_tactical_card(card_id: String) -> bool:
	return SessionRosterFacade.pick_tactical_card(self, card_id)

func _选战术牌(card_id: String) -> bool:
	return SessionRosterFacade._选战术牌(self, card_id)

func refresh_card_offers(unit_key: String = "") -> Array:
	return SessionRosterFacade.refresh_card_offers(self, unit_key)

func _刷新候选(unit_key: String = "") -> Array:
	return SessionRosterFacade._刷新候选(self, unit_key)

func lineup_slots() -> Array:
	return SessionRosterFacade.lineup_slots(self)

func normalize_lineup_slots() -> bool:
	return SessionRosterFacade.normalize_lineup_slots(self)

func 规范编队槽位() -> bool:
	return SessionRosterFacade.规范编队槽位(self)

func _标记编队已调整(s: RunState) -> void:
	SessionRosterFacade._标记编队已调整(self, s)

func set_lineup_slot(unit_key: String, slot_name: String) -> bool:
	return SessionRosterFacade.set_lineup_slot(self, unit_key, slot_name)

func deploy_unit(unit_key: String, slot_name: String) -> bool:
	return SessionRosterFacade.deploy_unit(self, unit_key, slot_name)

func _摆上阵(unit_key: String, slot_name: String) -> bool:
	return SessionRosterFacade._摆上阵(self, unit_key, slot_name)

func remove_from_lineup(unit_key: String) -> bool:
	return SessionRosterFacade.remove_from_lineup(self, unit_key)

func undeploy_unit(unit_key: String) -> bool:
	return SessionRosterFacade.undeploy_unit(self, unit_key)

func _撤下来(unit_key: String) -> bool:
	return SessionRosterFacade._撤下来(self, unit_key)

func clear_lineup() -> bool:
	return SessionRosterFacade.clear_lineup(self)

func _清空编队() -> bool:
	return SessionRosterFacade._清空编队(self)

func available_recruit_targets(ticket_idx: int = -1) -> Array:
	return SessionRosterFacade.available_recruit_targets(self, ticket_idx)

func promotion_preview(unit_key: String) -> Dictionary:
	return SessionRosterFacade.promotion_preview(self, unit_key)

# ---- 转发 → SessionBattleFlow（五 战斗重实现） ----
func _规范快速阵容(阵容: String) -> String:
	return SessionBattleFlow._规范快速阵容(self, 阵容)

func _开快速测试战(阵容: String, seed_val: int) -> bool:
	return SessionBattleFlow._开快速测试战(self, 阵容, seed_val)

func _开快速战(seed_val: int = 20261013, 阵容: String = "") -> bool:
	return SessionBattleFlow._开快速战(self, seed_val, 阵容)

func _把敌机改成试玩靶机(ctx: Dictionary) -> void:
	SessionBattleFlow._把敌机改成试玩靶机(self, ctx)

func _布置靶机援护(ctx: Dictionary) -> void:
	SessionBattleFlow._布置靶机援护(self, ctx)

func _靶机挪位(敌们: Array, 目标: Variant, 位: int) -> void:
	SessionBattleFlow._靶机挪位(self, 敌们, 目标, 位)

func _开节点战() -> bool:
	return SessionBattleFlow._开节点战(self)

func _准备战前编队(kind: String = "node") -> Dictionary:
	return SessionBattleFlow._准备战前编队(self, kind)

func _确认编队开战() -> Dictionary:
	return SessionBattleFlow._确认编队开战(self)

func _出击存活数(s: RunState) -> int:
	return SessionBattleFlow._出击存活数(self, s)

func _自动补满编队(s: RunState) -> int:
	return SessionBattleFlow._自动补满编队(self, s)

func _切开关(unit_id: String, switch_key: String) -> bool:
	return SessionBattleFlow._切开关(self, unit_id, switch_key)

func _打一回合() -> Dictionary:
	return SessionBattleFlow._打一回合(self)

func _自动打完() -> Dictionary:
	return SessionBattleFlow._自动打完(self)

func _结算这一场() -> Dictionary:
	return SessionBattleFlow._结算这一场(self)

func _战后按率给券(s: RunState, r: Dictionary, 场次前: int) -> void:
	SessionBattleFlow._战后按率给券(self, s, r, 场次前)

func _战后给券掷签(s: RunState, 场次前: int) -> float:
	return SessionBattleFlow._战后给券掷签(self, s, 场次前)

func _撤回刚发的券(s: RunState, 券: Variant) -> void:
	SessionBattleFlow._撤回刚发的券(self, s, 券)

# ---- 转发 → SessionBattleHandView（五之三 单机牌组上半） ----
func _目标原文(c: Dictionary) -> String:
	return SessionBattleHandView._目标原文(self, c)

func _武器是修理(w: Variant) -> bool:
	return SessionBattleHandView._武器是修理(self, w)

func _武器威力Of(c: Variant) -> float:
	return SessionBattleHandView._武器威力Of(self, c)

func _武器段数Of(c: Variant) -> float:
	return SessionBattleHandView._武器段数Of(self, c)

func 卡目标方(c: Dictionary, 区: String = "", 是修理: bool = false) -> String:
	return SessionBattleHandView.卡目标方(self, c, 区, 是修理)

func 单机牌组开() -> bool:
	return SessionBattleHandView.单机牌组开(self)

func deck_mode_active() -> bool:
	return SessionBattleHandView.deck_mode_active(self)

func _选中默认机体() -> String:
	return SessionBattleHandView._选中默认机体(self)

func _找我方单位(unit_id: String) -> Dictionary:
	return SessionBattleHandView._找我方单位(self, unit_id)

func _选中单位(unit_id: String = "") -> Dictionary:
	return SessionBattleHandView._选中单位(self, unit_id)

func select_battle_unit(unit_id: String) -> Dictionary:
	return SessionBattleHandView.select_battle_unit(self, unit_id)

func 点选机体(unit_id: String) -> Dictionary:
	return SessionBattleHandView.点选机体(self, unit_id)

func _点选机体(unit_id: String) -> Dictionary:
	return SessionBattleHandView._点选机体(self, unit_id)

func selected_unit_view() -> Dictionary:
	return SessionBattleHandView.selected_unit_view(self)

func selected_unit() -> String:
	return SessionBattleHandView.selected_unit(self)

func upper_hand_cards(unit_id: String = "") -> Array:
	return SessionBattleHandView.upper_hand_cards(self, unit_id)

func 衍生视图们(u: Dictionary) -> Array:
	return SessionBattleHandView.衍生视图们(self, u)

func _衍生该跳过(u: Dictionary, c: Dictionary) -> bool:
	return SessionBattleHandView._衍生该跳过(self, u, c)

func _武器牌视图(u: Dictionary, entry: Dictionary, w: Dictionary) -> Dictionary:
	return SessionBattleHandView._武器牌视图(self, u, entry, w)

func _读数(v: Variant) -> float:
	return SessionBattleHandView._读数(self, v)

func _真(v: Variant) -> bool:
	return SessionBattleHandView._真(self, v)

func pending_cards(unit_id: String = "") -> Array:
	return SessionBattleHandView.pending_cards(self, unit_id)

func _专属牌视图(u: Dictionary, c: Dictionary, 区: String) -> Dictionary:
	return SessionBattleHandView._专属牌视图(self, u, c, 区)

func lower_hand_cards(unit_id: String = "") -> Array:
	return SessionBattleHandView.lower_hand_cards(self, unit_id)

func _这台能打公有牌(u: Dictionary, c: Dictionary) -> bool:
	return SessionBattleHandView._这台能打公有牌(self, u, c)

func _找公有牌可打机体(c: Dictionary, 首选: Dictionary = {}) -> Dictionary:
	return SessionBattleHandView._找公有牌可打机体(self, c, 首选)

func _发动原因(u: Dictionary, 机: Dictionary) -> String:
	return SessionBattleHandView._发动原因(self, u, 机)

func _公有手牌里的牌(card_inst_id: String) -> Dictionary:
	return SessionBattleHandView._公有手牌里的牌(self, card_inst_id)

func _换给能打的队友(u: Dictionary, card_inst_id: String) -> Dictionary:
	return SessionBattleHandView._换给能打的队友(self, u, card_inst_id)

func _公有牌判定(u: Dictionary, c: Dictionary) -> Dictionary:
	return SessionBattleHandView._公有牌判定(self, u, c)

func _公有牌视图(u: Dictionary, c: Dictionary) -> Dictionary:
	return SessionBattleHandView._公有牌视图(self, u, c)

# ---- 转发 → SessionBattleDeckView（五之三 单机牌组下半） ----
func v03_active() -> bool:
	return SessionBattleDeckView.v03_active(self)

func 卡牌流转开() -> bool:
	return SessionBattleDeckView.卡牌流转开(self)

func weapon_bar_cards(unit_id: String = "") -> Array:
	return SessionBattleDeckView.weapon_bar_cards(self, unit_id)

func sub_weapon_cards(unit_id: String = "") -> Array:
	return SessionBattleDeckView.sub_weapon_cards(self, unit_id)

func ultimate_slots(unit_id: String = "") -> Array:
	return SessionBattleDeckView.ultimate_slots(self, unit_id)

func spirit_hand_cards(unit_id: String = "") -> Array:
	return SessionBattleDeckView.spirit_hand_cards(self, unit_id)

func 精神手牌(unit_id: String = "") -> Array:
	return SessionBattleDeckView.精神手牌(self, unit_id)

func deck_counts(unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.deck_counts(self, unit_id)

func link_library_state() -> Dictionary:
	return SessionBattleDeckView.link_library_state(self)

func chip_library_state() -> Dictionary:
	return SessionBattleDeckView.chip_library_state(self)

func _ctx有ATX(ctx: Dictionary) -> bool:
	return SessionBattleDeckView._ctx有ATX(self, ctx)

func last_card_state() -> Dictionary:
	return SessionBattleDeckView.last_card_state(self)

func lambda_state_of(unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.lambda_state_of(self, unit_id)

func weapon_range_check(unit_id: String, card_or_id: String, target_id: String) -> Dictionary:
	return SessionBattleDeckView.weapon_range_check(self, unit_id, card_or_id, target_id)

func _距离文(c: Dictionary) -> String:
	return SessionBattleDeckView._距离文(self, c)

func _武器类型文(c: Dictionary) -> String:
	return SessionBattleDeckView._武器类型文(self, c)

func play_unit_ultimate(slot_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_ultimate(self, slot_ident, target_id, unit_id)

func 打出大招(slot_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出大招(self, slot_ident, target_id, unit_id)

## ★ COL-4b：手动 QTE 三档 → 大招（表现层弹窗选完走这一条）。
func play_unit_ultimate_qte(slot_ident: String, target_id: String = "", qte: String = "",
		unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_ultimate_qte(self, slot_ident, target_id, qte, unit_id)

func _打大招(slot_ident: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打大招(self, slot_ident, target_id, unit_id)

func play_unit_sub_weapon(card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_sub_weapon(self, card_ident, target_id, unit_id)

func 打出副武器(card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出副武器(self, card_ident, target_id, unit_id)

func _打副武器(card_ident: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打副武器(self, card_ident, target_id, unit_id)

func play_link_card(card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_link_card(self, card_ident, target_id, unit_id)

func 打出连携牌(card_ident: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出连携牌(self, card_ident, target_id, unit_id)

func _打连携牌(card_ident: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打连携牌(self, card_ident, target_id, unit_id)

func play_unit_main_weapon(weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_main_weapon(self, weapon_or_card_id, target_id, unit_id)

func 打出主武器卡(weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出主武器卡(self, weapon_or_card_id, target_id, unit_id)

func _打主武器卡(weapon_or_card_id: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打主武器卡(self, weapon_or_card_id, target_id, unit_id)

func play_unit_derived_card(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_derived_card(self, card_inst_id, target_id, unit_id)

func 打出衍生攻击卡(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出衍生攻击卡(self, card_inst_id, target_id, unit_id)

func _打衍生卡(card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打衍生卡(self, card_inst_id, target_id, unit_id)

func play_unit_spirit_or_public_card(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.play_unit_spirit_or_public_card(self, card_inst_id, target_id, unit_id)

func 打出精神或公有牌(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return SessionBattleDeckView.打出精神或公有牌(self, card_inst_id, target_id, unit_id)

func _打精神或公有卡(card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	return SessionBattleDeckView._打精神或公有卡(self, card_inst_id, target_id, unit_id)

func _单机出牌门(unit_id: String) -> Dictionary:
	return SessionBattleDeckView._单机出牌门(self, unit_id)

func _出牌成功(行动: String, 区: String, 牌名: String, u: Dictionary, 战意前: float, 内核: Dictionary) -> Dictionary:
	return SessionBattleDeckView._出牌成功(self, 行动, 区, 牌名, u, 战意前, 内核)

func end_player_turn() -> Dictionary:
	return SessionBattleDeckView.end_player_turn(self)

func 结束我方回合() -> Dictionary:
	return SessionBattleDeckView.结束我方回合(self)

func auto_play_all_units() -> Dictionary:
	return SessionBattleDeckView.auto_play_all_units(self)

func _结束我方回合() -> Dictionary:
	return SessionBattleDeckView._结束我方回合(self)

func deck_turn_summary() -> Dictionary:
	return SessionBattleDeckView.deck_turn_summary(self)

func guard_links() -> Array:
	return SessionBattleDeckView.guard_links(self)

func enemy_intents() -> Array:
	return SessionBattleDeckView.enemy_intents(self)

func unit_intent_lines(side: String, unit_id: String) -> Array:
	return SessionBattleDeckView.unit_intent_lines(self, side, unit_id)

func _意图一行文本(c: Dictionary) -> String:
	return SessionBattleDeckView._意图一行文本(self, c)

func _数文(v: Variant) -> String:
	return SessionBattleDeckView._数文(self, v)

func _在敌方(u: Dictionary) -> bool:
	return SessionBattleDeckView._在敌方(self, u)

# ---- 转发 → SessionDisplayHelpers（六 展示辅助） ----
func _我方阵() -> Array:
	return SessionDisplayHelpers._我方阵(self)

func mithril_link_state() -> Dictionary:
	return SessionDisplayHelpers.mithril_link_state(self)

func _ctx有秘银(ctx: Dictionary) -> bool:
	return SessionDisplayHelpers._ctx有秘银(self, ctx)

func battle_log_lines(limit: int = 40) -> Array:
	return SessionDisplayHelpers.battle_log_lines(self, limit)

func _单条战斗日志转文本(e: Dictionary) -> String:
	return SessionDisplayHelpers._单条战斗日志转文本(self, e)

func battle_log_entries(limit: int = 40) -> Array:
	return SessionDisplayHelpers.battle_log_entries(self, limit)

func unit_view(side: String, unit_id: String) -> Dictionary:
	return SessionDisplayHelpers.unit_view(self, side, unit_id)

func topbar_state() -> Dictionary:
	return SessionDisplayHelpers.topbar_state(self)

func result_summary() -> Dictionary:
	return SessionDisplayHelpers.result_summary(self)

func _存活数(方: String) -> int:
	return SessionDisplayHelpers._存活数(self, 方)

func _战果文字() -> String:
	return SessionDisplayHelpers._战果文字(self)

func 战果文字() -> String:
	return SessionDisplayHelpers.战果文字(self)

func _增益文字们(v: Variant) -> Array:
	return SessionDisplayHelpers._增益文字们(self, v)

func _状态行(方: String, u: Dictionary) -> Array:
	return SessionDisplayHelpers._状态行(self, 方, u)

func 太阳炉明细() -> Array:
	return SessionDisplayHelpers.太阳炉明细(self)

func 太阳炉左栏文() -> String:
	return SessionDisplayHelpers.太阳炉左栏文(self)

func 介入标记(单位键: String) -> bool:
	return SessionDisplayHelpers.介入标记(self, 单位键)

func 出鞘标记文(卡: Variant) -> String:
	return SessionDisplayHelpers.出鞘标记文(self, 卡)

func 卡出鞘文(卡id: String) -> String:
	return SessionDisplayHelpers.卡出鞘文(self, 卡id)

func 默认拔刀目标(单位键: String) -> String:
	return SessionDisplayHelpers.默认拔刀目标(self, 单位键)

func 默认太阳炉牌(只要veda: bool = false) -> String:
	return SessionDisplayHelpers.默认太阳炉牌(self, 只要veda)

func _找我方(单位键: String) -> Dictionary:
	return SessionDisplayHelpers._找我方(self, 单位键)

func _开关行(u: Dictionary) -> Array:
	return SessionDisplayHelpers._开关行(self, u)

func _脚下类型(s: RunState) -> String:
	return SessionDisplayHelpers._脚下类型(self, s)

# ---- 转发 → SessionTooltipText（六之二 悬停说明） ----
func unit_hover_text(side: String, unit_key: String) -> String:
	return SessionTooltipText.unit_hover_text(self, side, unit_key)

func template_unit_hover_text(unit_key: String, level: int = 10, is_enemy: bool = false) -> String:
	return SessionTooltipText.template_unit_hover_text(self, unit_key, level, is_enemy)

func card_hover_text(card_or_id: Variant) -> String:
	return SessionTooltipText.card_hover_text(self, card_or_id)

func part_can_use_now(idx: int) -> Dictionary:
	return SessionTooltipText.part_can_use_now(self, idx)

func part_hover_text(idx: int) -> String:
	return SessionTooltipText.part_hover_text(self, idx)

func relic_hover_text(relic_id: String) -> String:
	return SessionTooltipText.relic_hover_text(self, relic_id)

func _藏品数值文字(v: Variant, 前缀: String = "") -> String:
	return SessionTooltipText._藏品数值文字(self, v, 前缀)

func _单位说明文字(方: String, u: Dictionary, 战斗中: bool) -> String:
	return SessionTooltipText._单位说明文字(self, 方, u, 战斗中)

func _武器行文字(条目: Variant, 战斗中: bool) -> String:
	return SessionTooltipText._武器行文字(self, 条目, 战斗中)

func _意图行(u: Dictionary) -> Array:
	return SessionTooltipText._意图行(self, u)

func _限次文字(v: Variant) -> String:
	return SessionTooltipText._限次文字(self, v)

func _数(v: Variant) -> String:
	return SessionTooltipText._数(self, v)


