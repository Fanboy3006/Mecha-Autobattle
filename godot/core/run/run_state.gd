## 肉鸽单局状态领域模型（RunState）
## 原生 Godot 强类型 RefCounted 对象（严禁调用 J.*）。
## 同时提供 to_dict() / from_dict() 供 SaveService 存档与黄金样例对拍使用。
class_name RunState
extends RefCounted

var version: int = 4
var seed_val: int = 1
var squad: String = "混编"
var squad_kind: String = "混编" # "职业" | "势力" | "混编"
var squad_leader: String = ""   # 带队核心机师键（如 "B1"）

var floor_num: int = 1
var node_id: int = 0
var map_data: Dictionary = {}

var propellant: int = 8
var propellant_max: int = 8
var layer_prop_bonus: int = 0
var part_prop_bonus: int = 0
var trail_floors: Array = []    # 走过出口小径的层号列表（使下一层推进剂上限 +2）

## ★ M3-Core-A 补充（对齐封存 JS `90-肉鸽-3-开局与移动.js` 的 `RUN.已走过 / RUN.已揭开 / RUN.层出口选择`）：
##   这三个字段是大地图移动与出口结算必需的；不补就只能拿 `格.已过` 二次推断，语义会错
##   （「走过但没落脚」与「这一格的事做完了」是两件事）。
var visited_cells: Array = []   # 已走过的格号（JS RUN.已走过）
var revealed_cells: Array = []  # 已揭开的格号（JS RUN.已揭开）
var exit_choices: Dictionary = {} # 层号 → "尽头" | "小径"（JS RUN.层出口选择）

var chased: bool = false        # 本层是否触发过追击
var exit_chase: bool = false    # 本次追击是否在出口格触发（需过守军闸）
var pending_floor_change: Variant = null # null 或 {"层": int, "追击": bool}
var pending_event: Variant = null        # null 或 {"层": int, "格号": int, "事件id": String, ...}

var carbon: int = 18
var hope: int = 6
var base_hp: int = 10
var base_max_hp: int = 10
var level: int = 1
var exp_val: int = 0

## 名册：key -> {"key": String, "lv": int, "hpRatio": float}
var roster: Dictionary = {}
## 出击位：[{"key": String, "slot": String}]
var lineup: Array = []
## 招募券：[{"id": int, "类": String, "名": String, "源": String}]
var tickets: Array = []
var next_ticket_id: int = 1

## 藏品与零件
var relics: Array = []          # Array[String] 藏品 id 列表
var parts: Array = []           # Array[Dictionary] {"id": String, "uses": int, "value": int}
var active_part_index: int = -1 # 当前正在瞄准使用的大地图零件下标

## 战术卡牌构筑
var tactical_deck: Array = []       # Array[String] 已选入牌库的战术牌 id
var pending_card_picks: Array = []  # Array[String] 当前 3 选 1 候选战术牌 id

## 统计与状态标记
var battles_fought: int = 0
var battles_won: int = 0
var nodes_cleared: int = 0
var shop_refreshes: int = 0
var shop_bought: Dictionary = {}
var used_compositions: Dictionary = {} # key: "层-类型" -> Array[String]
var status: String = "进行中"          # "进行中" | "胜利" | "失败"
var logs: Array = []                   # Array[String]

func add_log(msg: String, max_logs: int = 120) -> void:
	if msg.is_empty():
		return
	logs.append("[第%d层] %s" % [floor_num, msg])
	if logs.size() > max_logs:
		logs = logs.slice(logs.size() - max_logs)

# ======================== 大地图辅助（M3-Core-A） ========================
## 地图格表：键在生成时是 int，从 JSON 存档读回来会变成 String —— 两个都认。
func grid() -> Dictionary:
	if map_data.has("格") and map_data["格"] is Dictionary:
		return map_data["格"]
	return {}

func cell_at(cell_id: int) -> Dictionary:
	var g := grid()
	if g.has(cell_id):
		var v: Variant = g[cell_id]
		return v if v is Dictionary else {}
	var s: Variant = g.get(str(cell_id))
	return s if s is Dictionary else {}

func has_cell(cell_id: int) -> bool:
	return not cell_at(cell_id).is_empty()

func current_cell() -> Dictionary:
	return cell_at(node_id)

func current_type() -> String:
	return String(current_cell().get("类型", ""))

## 标记「走过这一格」；返回 true = 这一次真的新加进去的（对齐 JS 的 `if (!R.已走过.includes(k)) R.已走过.push(k)`）。
func mark_visited(cell_id: int) -> bool:
	if visited_cells.has(cell_id):
		return false
	visited_cells.append(cell_id)
	return true

func is_visited(cell_id: int) -> bool:
	return visited_cells.has(cell_id)

func mark_revealed(cell_id: int) -> bool:
	if revealed_cells.has(cell_id):
		return false
	revealed_cells.append(cell_id)
	return true

func is_revealed(cell_id: int) -> bool:
	return revealed_cells.has(cell_id)

## 加经验 + 升级（**逐字照抄**封存 JS `90-肉鸽-1-数据与规则.js:514-533` 的 `加经验()`）：
##   `经验 += x` → 经验够门槛就 `等级++` 并且 **按升到的那一级查表** 给希望（可能连升好几级）。
##   等级门槛 / 每级希望表从 Db 读（`肉鸽数值`），读不到就用战棋原表兜底。返回升了几级。
func gain_exp(x: int, source: String = "作战") -> int:
	if level < 1:
		level = 1
	if exp_val < 0:
		exp_val = 0
	exp_val += x
	var 门槛 := _level_need()
	add_log("%s：经验 +%d（部队 Lv%d %d / %s）" % [source, x, level, exp_val,
		"—" if 门槛 < 0 else str(门槛)])
	var 升了 := 0
	while true:
		var need := _level_need()
		if need < 0 or exp_val < need:
			break
		level += 1
		var 希望 := _hope_for_level(level)
		hope += 希望
		升了 += 1
		add_log("部队升到 Lv%d：希望 +%d" % [level, 希望])
	return 升了

const 等级门槛兜底: Array = [0, 0, 8, 18, 30, 44, 60, 78, 98, 120, 144, 170]
const 每级希望兜底: Dictionary = {2: 4, 3: 4, 4: 5, 5: 6, 6: 6, 7: 6, 8: 7, 9: 8, 10: 8}
const 每级希望封顶兜底: int = 8

## 下一级要多少经验；已经到表尾 → −1（= JS 的 `null`，升不动了）。
func _level_need() -> int:
	var 表: Array = 等级门槛兜底
	if Db.installed and Db.T.get("肉鸽数值") is Dictionary:
		var 门槛: Variant = (Db.T["肉鸽数值"] as Dictionary).get("等级门槛")
		if 门槛 is Array and not (门槛 as Array).is_empty():
			表 = 门槛
	var i := maxi(0, level) + 1
	if i >= 表.size():
		return -1
	return int(表[i])

func _hope_for_level(lv: int) -> int:
	if lv <= 1:
		return 0
	var 表: Dictionary = 每级希望兜底
	var 封顶: int = 每级希望封顶兜底
	if Db.installed and Db.T.get("肉鸽数值") is Dictionary:
		var 肉: Dictionary = Db.T["肉鸽数值"]
		if 肉.get("每级希望表") is Dictionary:
			表 = 肉["每级希望表"]
		if 肉.get("每级希望封顶") != null:
			封顶 = int(肉["每级希望封顶"])
	if 表.has(lv):
		return int(表[lv])
	return 封顶 if lv > 10 else 0

func has_relic(relic_id: String) -> bool:
	return relics.has(relic_id)

func roster_keys() -> Array:
	return roster.keys()

func is_in_roster(unit_key: String) -> bool:
	return roster.has(unit_key)

func get_unit_level(unit_key: String) -> int:
	if not roster.has(unit_key):
		return 10
	var info: Dictionary = roster[unit_key]
	return int(info.get("lv", 10))

func get_unit_hp_ratio(unit_key: String) -> float:
	if not roster.has(unit_key):
		return 1.0
	var info: Dictionary = roster[unit_key]
	return clampf(float(info.get("hpRatio", 1.0)), 0.01, 1.0)

func to_dict() -> Dictionary:
	return {
		"版本": version,
		"种子": seed_val,
		"分队": squad,
		"分队类型": squad_kind,
		"带队核心": squad_leader,
		"层": floor_num,
		"当前格": node_id,
		"地图": map_data.duplicate(true),
		"推进剂": propellant,
		"推进剂上限": propellant_max,
		"层推进剂修正": layer_prop_bonus,
		"零件推进剂加成": part_prop_bonus,
		"层出口小径": trail_floors.duplicate(),
		"已走过": visited_cells.duplicate(),
		"已揭开": revealed_cells.duplicate(),
		"层出口选择": exit_choices.duplicate(true),
		"追击": chased,
		"出口追击": exit_chase,
		"待换层": pending_floor_change.duplicate(true) if pending_floor_change is Dictionary else null,
		"待奇遇": pending_event.duplicate(true) if pending_event is Dictionary else null,
		"源碳": carbon,
		"希望": hope,
		"基地耐久": base_hp,
		"基地最大耐久": base_max_hp,
		"等级": level,
		"经验": exp_val,
		"名册": roster.duplicate(true),
		"出击": lineup.duplicate(true),
		"券": tickets.duplicate(true),
		"下一张券ID": next_ticket_id,
		"藏品": relics.duplicate(),
		"零件": parts.duplicate(true),
		"当前零件": active_part_index,
		"战术牌库": tactical_deck.duplicate(),
		"待选战术牌": pending_card_picks.duplicate(),
		"场次": battles_fought,
		"胜场": battles_won,
		"已清节点": nodes_cleared,
		"黑市刷新": shop_refreshes,
		"黑市已买": shop_bought.duplicate(true),
		"已用编成": used_compositions.duplicate(true),
		"状态": status,
		"日志": logs.duplicate(),
	}

static func from_dict(d: Dictionary) -> RunState:
	var s := RunState.new()
	if d.is_empty():
		return s
	s.version = int(d.get("版本", 4))
	s.seed_val = int(d.get("种子", 1))
	s.squad = String(d.get("分队", "混编"))
	s.squad_kind = String(d.get("分队类型", "混编"))
	s.squad_leader = String(d.get("带队核心", ""))
	s.floor_num = maxi(1, int(d.get("层", 1)))
	s.node_id = int(d.get("当前格", 0))
	s.map_data = (d.get("地图", {}) as Dictionary).duplicate(true) if d.get("地图") is Dictionary else {}
	s.propellant = maxi(0, int(d.get("推进剂", 8)))
	s.propellant_max = maxi(1, int(d.get("推进剂上限", 8)))
	s.layer_prop_bonus = int(d.get("层推进剂修正", 0))
	s.part_prop_bonus = int(d.get("零件推进剂加成", 0))
	s.trail_floors = (d.get("层出口小径", []) as Array).duplicate() if d.get("层出口小径") is Array else []
	s.visited_cells = (d.get("已走过", []) as Array).duplicate() if d.get("已走过") is Array else []
	s.revealed_cells = (d.get("已揭开", []) as Array).duplicate() if d.get("已揭开") is Array else []
	s.exit_choices = (d.get("层出口选择", {}) as Dictionary).duplicate(true) if d.get("层出口选择") is Dictionary else {}
	s.chased = bool(d.get("追击", false))
	s.exit_chase = bool(d.get("出口追击", false))
	var pfc = d.get("待换层", null)
	s.pending_floor_change = (pfc as Dictionary).duplicate(true) if pfc is Dictionary else null
	var pev = d.get("待奇遇", null)
	s.pending_event = (pev as Dictionary).duplicate(true) if pev is Dictionary else null
	s.carbon = maxi(0, int(d.get("源碳", 18)))
	s.hope = maxi(0, int(d.get("希望", 6)))
	s.base_max_hp = maxi(1, int(d.get("基地最大耐久", 10)))
	s.base_hp = clampi(int(d.get("基地耐久", s.base_max_hp)), 0, s.base_max_hp)
	s.level = clampi(int(d.get("等级", 1)), 1, 10)
	s.exp_val = maxi(0, int(d.get("经验", 0)))
	s.roster = (d.get("名册", {}) as Dictionary).duplicate(true) if d.get("名册") is Dictionary else {}
	s.lineup = (d.get("出击", []) as Array).duplicate(true) if d.get("出击") is Array else []
	s.tickets = (d.get("券", []) as Array).duplicate(true) if d.get("券") is Array else []
	s.next_ticket_id = maxi(1, int(d.get("下一张券ID", s.tickets.size() + 1)))
	s.relics = (d.get("藏品", []) as Array).duplicate() if d.get("藏品") is Array else []
	s.parts = (d.get("零件", []) as Array).duplicate(true) if d.get("零件") is Array else []
	s.active_part_index = int(d.get("当前零件", -1))
	s.tactical_deck = (d.get("战术牌库", []) as Array).duplicate() if d.get("战术牌库") is Array else []
	s.pending_card_picks = (d.get("待选战术牌", []) as Array).duplicate() if d.get("待选战术牌") is Array else []
	s.battles_fought = maxi(0, int(d.get("场次", 0)))
	s.battles_won = maxi(0, int(d.get("胜场", 0)))
	s.nodes_cleared = maxi(0, int(d.get("已清节点", 0)))
	s.shop_refreshes = maxi(0, int(d.get("黑市刷新", 0)))
	s.shop_bought = (d.get("黑市已买", {}) as Dictionary).duplicate(true) if d.get("黑市已买") is Dictionary else {}
	s.used_compositions = (d.get("已用编成", {}) as Dictionary).duplicate(true) if d.get("已用编成") is Dictionary else {}
	s.status = String(d.get("状态", "进行中"))
	s.logs = (d.get("日志", []) as Array).duplicate() if d.get("日志") is Array else []
	return s
