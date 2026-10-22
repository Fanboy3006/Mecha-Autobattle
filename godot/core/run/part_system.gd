## 零件系统（PartSystem）—— ★ 2026-10-17 按《黑流树海》原版规格全面重写（任务单 PART-1）。
##
## 口径（作者拍板，施工必守）：
##   · 目标格一律用**网格坐标 `(列, 行)` 的几何距离**判定，**无视道路连通与空格障碍**（不用 BFS 距离）；
##   · 范围是 `1 ~ N` 格内：`adj8` = 相邻 8 格（含斜角）、`ring12` = 曼哈顿 1~2 格菱形、
##     `line(n)` = 横竖直线 1~n 格（`LINE_ALLOW_DIAGONAL = false` = 不含斜线）、`any` = 本层任意存在格；
##   · 默认每次位移消耗 **1 点推进剂**（`free: true` 的 spring / jet / bagua 免推进剂）；
##   · 推进剂为 0 时 `free: false` 的零件**严禁使用**；
##   · `bloodcap` 每场战斗（胜败都算）估价 +2、**无上限**；`wave` 每次移动独立随机 `-6 / +8`，夹在 `[0, 999]`；
##   · `spring` / `bagua` 带 `breakOnNextFloor: true` → 进入下一层时自动损坏（`break_on_next_floor`）；
##   · 卖价：自然物按当前估价；加工品 / 概念体**固定 1 源碳**。
##
## 组织约定：零件实例的主键字段是 **`id`**（与 `RunState.parts` / `NodeResolver` 一致），读数时也接受 JS 的 `k`；
## 实例上的估价同时写 `value`（本仓库原有字段）与 `val`（任务单里的字段名）。
## 数据表字段名中英兼容：`free` / `免费`、`breakOnNextFloor` / `跨层损坏`、`rarity` / `稀有度`、`初值` / `估价`。
## 原生 Godot 强类型实现：**零 `J.*`**。
class_name PartSystem
extends RefCounted

## 直线范围是否允许斜线。★ 作者拍板 = **仅横竖 4 方向**（不含斜线）——要放开只改这一个常量。
const LINE_ALLOW_DIAGONAL: bool = false

const 零件箱初值兜底 := 8
## `血蕈估价上限` 已废弃（原版不封顶），保留数据键只为兼容旧读法；这里给一个「够大」的兜底。
const 血蕈估价上限兜底 := 999
## 非战斗节点（数据表 `非战斗节点`；`is_non_combat_cell()` 用的是「排除战斗节点」的反向判据）。
const 非战斗节点兜底: Array = ["空", "黑市", "休整", "招募站", "事件", "瞭望站", "遗迹", "隧道",
	"起点", "出口小径", "出口尽头"]
## 战斗节点类型（命中 = 不是「非战斗格」）：普通战斗 / 精英战斗 / 首领 / 侵蚀源 / 出口守军。
## 地图生成器里对应的实际类型名是 `作战` / `精英` / `出口守军` / `侵蚀源`（另把原版/古称一起收进来）。
const 战斗节点兜底: Array = ["作战", "普通战斗", "精英", "精英战斗", "首领", "Boss", "侵蚀源", "出口守军", "守军"]
## 黑市打折藏品（`94-零件.js:411` 的 `f1`：`price × 0.7`）。
const 打折藏品 := "f1"
## 浪花波动步进计数器存在 `map_data` 的侧信道里（换层/存档都跟着走，不污染 `RunState` 的字段）。
const 浪花步进键 := "浪花步进"

# ==========================================================================================
# 一、数据查询
# ==========================================================================================

static func part_table() -> Dictionary:
	if Db.catalog != null:
		var t := Db.catalog.parts()
		if not t.is_empty():
			return t
	var t2: Variant = Db.T.get("零件表")
	return t2 if t2 is Dictionary else {}

static func part_info(part_id: String) -> Dictionary:
	var t := part_table()
	var v: Variant = t.get(part_id)
	return v if v is Dictionary else {}

## 零件条目的主键（本仓库用 `id`；兼容 JS 的 `k`）。
static func part_key(p: Variant) -> String:
	if not (p is Dictionary):
		return ""
	var d: Dictionary = p
	var v: Variant = d.get("id")
	if v == null:
		v = d.get("k")
	return String(v) if v != null else ""

## 中英字段名兼容读一个布尔（`free` / `免费`、`breakOnNextFloor` / `跨层损坏`）。
static func _info_flag(P: Dictionary, en: String, zh: String, dflt: bool) -> bool:
	var v: Variant = P.get(en)
	if v == null:
		v = P.get(zh)
	return bool(v) if v != null else dflt

## 这一件是否免推进剂（`free: true` 的 spring / jet / bagua）。
static func part_is_free(part_id: String) -> bool:
	return _info_flag(part_info(part_id), "free", "免费", false)

## 这一件是否「进入下一层时自动损坏」。
static func part_breaks_on_next_floor(part_id: String) -> bool:
	return _info_flag(part_info(part_id), "breakOnNextFloor", "跨层损坏", false)

## 稀有度（`"low" | "mid" | "high"`；表里没写按 low）。
static func part_rarity(part_id: String) -> String:
	var P := part_info(part_id)
	var v: Variant = P.get("rarity")
	if v == null:
		v = P.get("稀有度")
	var s := String(v) if v != null else "low"
	return s if not s.is_empty() else "low"

## 稀有度的中文显示名（顶栏 / 悬停说明用）。
static func rarity_name(r: String) -> String:
	if r == "high":
		return "高级"
	if r == "mid":
		return "中级"
	return "普通"

## 能在地图上真的**用出来**的零件（`用: true`）。
static func active_part_ids() -> Array:
	var out: Array = []
	for k in part_table().keys():
		if bool((part_table()[k] as Dictionary).get("用", false)):
			out.append(String(k))
	return out

## 能掉落 / 能买到的零件（`用: true` **或** `可买: true`，13 件 = 全部零件）。
## ★ 零件数据**只有一处真源**：`data/js/94-零件.json` 的 `零件表`（本文件不重复抄数据）。
## ★ 2026-10-17：`rite`（河谷祭祈）改成 `用: false` 被动常驻后，靠数据里的 **`可买: true`**
##   继续留在买卖池里 → 池子仍是 **13 件**（任务单 §4 PART-1「默认 `null` 时从 13 件中等权随机」）。
static func tradable_part_ids() -> Array:
	var out: Array = []
	for k in part_table().keys():
		var P: Dictionary = part_table()[k]
		if bool(P.get("用", false)) or bool(P.get("可买", false)):
			out.append(String(k))
	return out

# 中文别名（别的模块按 JS 里的名字调也认得）
static func 零件表() -> Dictionary: return part_table()
static func 零件池() -> Array: return active_part_ids()
static func 零件买卖池() -> Array: return tradable_part_ids()

## 零件箱上限（战棋 `RUN.partCap` 默认 8；★ `NodeResolver` 会探测这个名字，签名不能改）。
static func 零件箱上限() -> int:
	var v: Variant = Db.T.get("零件箱初值")
	return int(v) if v != null else 零件箱初值兜底

static func part_box_cap() -> int:
	return 零件箱上限()

## ★ 已废弃的「血蕈估价上限」：原版**不设上限**，这个接口只为兼容旧调用保留（恒返回表里的兜底值）。
static func 血蕈估价上限() -> int:
	var v: Variant = Db.T.get("血蕈估价上限")
	return int(v) if v != null else 血蕈估价上限兜底

## 非战斗节点集合（数据表 `非战斗节点`；含起点与两个出口）。
static func non_combat_types() -> Array:
	var v: Variant = Db.T.get("非战斗节点")
	return (v as Array) if v is Array else 非战斗节点兜底

## 这个节点类型是不是**战斗节点**（对应任务单里的 `MapGenerator.是战斗节点`；本仓库内聚在 PartSystem 一处）。
static func is_combat_type(t: String) -> bool:
	return 战斗节点兜底.has(t)

static func 是战斗节点(t: String) -> bool:
	return is_combat_type(t)

## 取一格的类型名（兼容 `类型` 与本仓库外部的 `type`）。
static func cell_type(cell: Dictionary) -> String:
	var t: Variant = cell.get("类型")
	if t == null:
		t = cell.get("type")
	return String(t) if t != null else ""

## 这一格「存在」吗。对外口径是 `cell.get("exists", false)`；本仓库的空格 = 空字典，
## 所以没有 `exists` 键时退化成「字典非空」。
static func cell_exists(cell: Dictionary) -> bool:
	if cell.is_empty():
		return false
	if cell.has("exists"):
		return bool(cell.get("exists", false))
	return true

## ★ 非战斗格：存在，且不是战斗节点（含 `空` / `黑市` / `休整` / `招募站` / `事件` / `瞭望站` /
## `遗迹` / `隧道` / `起点` / `出口小径` / `出口尽头`；排除 `普通战斗` / `精英战斗` / `首领` /
## `侵蚀源` / `出口守军`）。
static func is_non_combat_cell(cell: Dictionary) -> bool:
	if not cell_exists(cell):
		return false
	return not is_combat_type(cell_type(cell))

## 新零件实例（战棋 `newPart`）：`{"id", "uses", "value"}`；次数 / 估价没有就是 null。
## ★ 自然物同时写 `val`（任务单里的字段名）与 `value`（本仓库原有字段），两处永远相等。
static func new_part(part_id: String) -> Dictionary:
	var P := part_info(part_id)
	if P.is_empty():
		return {}
	var 次数: Variant = P.get("次数")
	var 初值: Variant = P.get("初值")
	if 初值 == null:
		初值 = P.get("估价")
	var 值: Variant = int(初值) if 初值 != null else null
	var d := {
		"id": part_id,
		"uses": int(次数) if 次数 != null else null,
		"value": 值,
	}
	if 值 != null:
		d["val"] = 值
	return d

## 参考价（箱满时挑「最不值钱的那件」用它）：有估价用估价，没有用表里的 `价`。
static func reference_price(p: Variant) -> int:
	if not (p is Dictionary):
		return 0
	var d: Dictionary = p
	var v: Variant = d.get("value")
	if v != null:
		return int(v)
	var P := part_info(part_key(d))
	var 价: Variant = P.get("价")
	return int(价) if 价 != null else 0

## 这一件在表里的初始估价（自然物：血蕈 2 / 浪花 3；`初值` 优先，兼容旧的 `估价`）。
static func _table_value(part_id: String) -> int:
	var P := part_info(part_id)
	var v: Variant = P.get("初值")
	if v == null:
		v = P.get("估价")
	return int(v) if v != null else 0

## 这一件当前的有效估价：实例上的 `val` / `value` 优先（0 也是合法值），都没有才用表里的初值。
static func current_value(p: Variant) -> int:
	var key := part_key(p)
	var 表 := _table_value(key)
	if not (p is Dictionary):
		return 表
	var d: Dictionary = p
	for k in ["val", "value", "估价"]:
		if d.has(k) and d[k] != null:
			return int(d[k])
	return 表

## 给一件零件写估价（`val` 与 `value` 同步写，保持两处一致）。
static func _set_value(d: Dictionary, v: int) -> void:
	d["value"] = v
	d["val"] = v

## 抽一个零件（`94-零件.js:277-284`）：`种子 + 层×211 + 格号×23 + 场次×29`。
## ★ `weight_by_rarity`：
##   · `null`（默认）→ **13 件等权**抽取（不读 `rarity`）；
##   · 传 Dictionary（如 `{"low": 50, "mid": 35, "high": 15}`）→ 按每件的 `rarity` 查权重加权抽取
##     （某档没写权重按 `low` 那一档算；全为 0 权重时退回等权）。
static func draw_part(state: RunState, salt: int = -1, weight_by_rarity: Variant = null) -> String:
	var 池 := tradable_part_ids()
	if 池.is_empty():
		return ""
	var 格 := state.node_id if salt < 0 else salt
	var rng := Mulberry32.new((state.seed_val + state.floor_num * 211 + 格 * 23 + state.battles_fought * 29) & 0xFFFFFFFF)
	if not (weight_by_rarity is Dictionary) or (weight_by_rarity as Dictionary).is_empty():
		return String(池[mini(池.size() - 1, floori(rng.next_float() * float(池.size())))])
	var 权表: Dictionary = weight_by_rarity
	var 权们: Array = []
	var 总 := 0
	for k in 池:
		var r := part_rarity(String(k))
		var w := int(权表.get(r, 权表.get("low", 1)))
		w = maxi(0, w)
		权们.append(w)
		总 += w
	if 总 <= 0:
		return String(池[mini(池.size() - 1, floori(rng.next_float() * float(池.size())))])
	var 掷 := rng.next_float() * float(总)
	var 累 := 0
	for i in 池.size():
		累 += int(权们[i])
		if 掷 < float(累):
			return String(池[i])
	return String(池[池.size() - 1])

# ==========================================================================================
# 二、拿到 / 丢掉 / 推进剂加成
# ==========================================================================================

## 拿到一个零件（`94-零件.js:185-212`）。
## ★ 箱满**不再直接丢**：保留新的、换掉**参考价最低**的旧件，并把两边的参考价写进日志。
static func grant_part(state: RunState, part_id: String, source: String = "战利品") -> Dictionary:
	var P := part_info(part_id)
	if P.is_empty():
		return {}
	var 上限 := part_box_cap()
	if state.parts.size() >= 上限:
		var 最便宜 := 0
		for i in range(1, state.parts.size()):
			if reference_price(state.parts[i]) < reference_price(state.parts[最便宜]):
				最便宜 = i
		var 旧的: Variant = state.parts[最便宜]
		var 旧名: String = String(part_info(part_key(旧的)).get("名", part_key(旧的)))
		var 旧价 := reference_price(旧的)
		var 新价 := reference_price(new_part(part_id))
		state.parts.remove_at(最便宜)
		state.parts.append(new_part(part_id))
		recalc_propellant_bonus(state)   # 换掉的可能是河谷祭祈 → 推进剂上限要跟着变
		state.add_log("零件箱已经满了（%d）：收下新的【%s】，换掉参考价最低的旧件【%s】（旧件参考价 %d 是在场最低的；新件参考价 %d）（%s）"
			% [上限, String(P["名"]), String(旧名), 旧价, 新价, source])
		return {"id": part_id, "名": String(P["名"]), "说明": String(P.get("说明", "")), "来源": source,
			"换掉": {"id": part_key(旧的), "名": String(旧名), "参考价": 旧价}, "满了": true}
	state.parts.append(new_part(part_id))
	state.add_log("获得零件【%s】：%s（%s）" % [String(P["名"]), String(P.get("说明", "")), source])
	if part_id == "rite":
		recalc_propellant_bonus(state)
	return {"id": part_id, "名": String(P["名"]), "说明": String(P.get("说明", "")), "来源": source}

## 丢掉某个下标（战棋 `RUN.parts.splice`）。
static func drop_part(state: RunState, index: int) -> Variant:
	if index < 0 or index >= state.parts.size():
		return null
	var p: Variant = state.parts[index]
	state.parts.remove_at(index)
	if part_key(p) == "rite":
		recalc_propellant_bonus(state)
	return p

## 河谷祭祈：手上的零件给的推进剂上限加成（`94-零件.js:267-272`）。
static func recalc_propellant_bonus(state: RunState) -> int:
	var n := 0
	for p in state.parts:
		if part_key(p) == "rite":
			n += 1
	state.part_prop_bonus = n
	return n

# 中文别名（与 JS 同名，方便别的模块直接调）
static func 拿零件(state: RunState, part_id: String, source: String = "战利品") -> Dictionary:
	return grant_part(state, part_id, source)
static func 重算推进剂加成(state: RunState) -> int:
	return recalc_propellant_bonus(state)
static func 零件箱满了吗(state: RunState) -> bool:
	return state.parts.size() >= part_box_cap()

# ==========================================================================================
# 三、动态估价（★ 都不消耗 rng，全部可复现）
# ==========================================================================================

## 血蕈：每打完一场战斗（**胜败都算**）估价 +2，**无上限**。返回涨过价的文本。
static func bloodcap_appreciate(state: RunState, cap: int = -1) -> Array:
	var 涨: Array = []
	for p in state.parts:
		if not (p is Dictionary) or part_key(p) != "bloodcap":
			continue
		var d: Dictionary = p
		var 旧 := current_value(d)
		var 新 := 旧 + 2
		if cap > 0:
			新 = mini(cap, 新)   # 兼容旧调用：显式传了上限才封顶（默认 -1 = 不封顶）
		_set_value(d, 新)
		涨.append("【血蕈】%d → %d 源碳" % [旧, 新])
	return 涨

## 浪花：大地图**每移动一次**（普通移动与零件移动都算），每件浪花独立随机 `-6` 或 `+8`（各 50%），
## 估价夹在 `[0, 999]`。随机数**带种子 + 步进计数器**（确定性可复现，不消耗全局 rng）。
## `_cell_id` 只为兼容旧调用保留（新口径不看落点格，只看「这是第几次移动」）。
static func wave_fluctuate(state: RunState, _cell_id: int = -1) -> Array:
	var 步 := int(state.map_data.get(浪花步进键, state.visited_cells.size()))
	步 += 1
	state.map_data[浪花步进键] = 步
	var rng := Mulberry32.new((state.seed_val + state.floor_num * 7919 + 步 * 104729) & 0xFFFFFFFF)
	var 变: Array = []
	for p in state.parts:
		if not (p is Dictionary) or part_key(p) != "wave":
			continue
		var d: Dictionary = p
		var 旧 := current_value(d)
		var delta := -6 if rng.next_float() < 0.5 else 8
		var 新 := clampi(旧 + delta, 0, 999)
		_set_value(d, 新)
		变.append("【浪花】%d → %d 源碳" % [旧, 新])
	return 变

## 进入下一层：移除所有 `breakOnNextFloor: true` 的零件（重弹簧 / 小八界）。
## 返回被损坏移除的零件**名字**数组（没坏任何东西 = 空数组）。
static func break_on_next_floor(state: RunState) -> Array:
	var 坏名: Array = []
	for i in range(state.parts.size() - 1, -1, -1):
		var p: Variant = state.parts[i]
		var key := part_key(p)
		var P := part_info(key)
		if not _info_flag(P, "breakOnNextFloor", "跨层损坏", false):
			continue
		state.parts.remove_at(i)
		坏名.append(String(P.get("名", key)))
	if not 坏名.is_empty():
		坏名.reverse()
		state.add_log("〔零件〕跨层损坏：%s" % "、".join(坏名))
	return 坏名

# ==========================================================================================
# 四、目标格（★ 几何距离；无视连通与空格障碍）
# ==========================================================================================

## 这一件用哪种范围算子：`adj8` / `ring12` / `line2` / `line3` / `any` / `thaw` / `tentacle` / `bagua` / ""。
## 读数顺序：`range`（新字段）→ `移动`（旧字段），并把旧写法归一化。
static func part_range(part_id: String) -> String:
	var P := part_info(part_id)
	var v: Variant = P.get("range")
	if v == null:
		v = P.get("移动")
	var s := String(v) if v != null else ""
	if s.begins_with("line(") and s.ends_with(")"):
		s = "line" + s.substr(5, s.length() - 6)
	match s:
		"adj8", "adj":
			return "adj8"
		"ring12", "ringline", "step":
			return "ring12"
		"line2", "line3":
			return s
		"any":
			return "any"
		"thaw", "fly":
			return "thaw"
		"tentacle", "shop":
			return "tentacle"
		"bagua":
			return "bagua"
		"ring":
			return "adj8"
	return ""

## 一格的网格坐标 `(列, 行)`。本仓库的格子这两个字段一定有；坏数据退回由格号反算。
static func cell_xy(state: RunState, k: int) -> Dictionary:
	var cell := state.cell_at(k)
	var cols := MapNavigator.columns(state)
	return {
		"x": int(cell.get("列", MapGenerator.cell_col(k, cols))),
		"y": int(cell.get("行", MapGenerator.cell_row(k, cols))),
	}

## 本层的黑市格号（坎诺特的触须用）；没有 → −1。
static func black_market_cell(state: RunState) -> int:
	for k in MapNavigator.cell_ids(state):
		if cell_type(state.cell_at(k)) == "黑市":
			return k
	return -1

## 小八界（bagua）的候选池：
##   ① 本层所有「存在 + 未探明（`not is_known`）+ 非战斗格」；非空就用它；
##   ② 否则退回本层所有「存在 + 非战斗格」（含当前格 —— 极端情况下可能原地不动）。
## 返回格号数组（升序；「当前格必已探明」所以①天然不含当前格）。
static func bagua_candidates(state: RunState) -> Array:
	var 未知: Array = []
	var 全部: Array = []
	for k in MapNavigator.cell_ids(state):
		var cell := state.cell_at(k)
		if not is_non_combat_cell(cell):
			continue
		全部.append(k)
		if not MapNavigator.is_known(state, k):
			未知.append(k)
	return 未知 if not 未知.is_empty() else 全部

## 用某一件零件**能点哪些格**（界面靠它高亮，测试靠它验规则）。返回格号数组（升序）。
static func part_targets(state: RunState, part_id: String) -> Array:
	var P := part_info(part_id)
	if P.is_empty() or not bool(P.get("用", false)):
		return []
	var 范围 := part_range(part_id)
	if 范围 == "bagua":
		return bagua_candidates(state)
	if 范围.is_empty():
		return []
	var 当前 := cell_xy(state, state.node_id)
	var cx := int(当前["x"])
	var cy := int(当前["y"])
	var out: Array = []
	for k in MapNavigator.cell_ids(state):
		var cell := state.cell_at(k)
		if not cell_exists(cell):        # 只认存在的格子（空格 / 不存在的格不能落）
			continue
		if k == state.node_id:           # 除 bagua 外，目标格不能是当前格
			continue
		var xy := cell_xy(state, k)
		var dx := absi(int(xy["x"]) - cx)
		var dy := absi(int(xy["y"]) - cy)
		if 范围 == "adj8":
			if maxi(dx, dy) == 1:
				out.append(k)
		elif 范围 == "ring12":
			if dx + dy >= 1 and dx + dy <= 2:
				out.append(k)
		elif 范围 == "line2":
			if _in_line(dx, dy, 2):
				out.append(k)
		elif 范围 == "line3":
			if _in_line(dx, dy, 3):
				out.append(k)
		elif 范围 == "any":
			out.append(k)
		elif 范围 == "thaw":
			if is_non_combat_cell(cell):   # 全图任意非战斗格，**不要求已探明**
				out.append(k)
		elif 范围 == "tentacle":
			if cell_type(cell) == "黑市" and MapNavigator.is_known(state, k):  # 迷雾黑市不可选
				out.append(k)
	return out

## 直线范围判据：默认只认正横 / 正竖（`LINE_ALLOW_DIAGONAL == false`），1~n 格、不可拐弯。
static func _in_line(dx: int, dy: int, n: int) -> bool:
	var 直线 := dx == 0 or dy == 0 or (LINE_ALLOW_DIAGONAL and dx == dy)
	return 直线 and maxi(dx, dy) >= 1 and maxi(dx, dy) <= n

# 中文别名
static func 零件目标(state: RunState, part_id: String) -> Array:
	return part_targets(state, part_id)
static func 黑市格(state: RunState) -> int:
	return black_market_cell(state)

# ==========================================================================================
# 五、用掉一件（默认消耗 1 点推进剂；free 的三件免推进剂）
# ==========================================================================================

## 小八界内部的**确定性**随机落点（候选池下标）：同种子 + 同局面 → 同结果。
static func _bagua_index(state: RunState, n: int) -> int:
	if n <= 0:
		return -1
	var rng := Mulberry32.new((state.seed_val + state.floor_num * 211 + state.battles_fought * 29
		+ state.visited_cells.size() * 23) & 0xFFFFFFFF)
	return mini(n - 1, floori(rng.next_float() * float(n)))

## 用掉这一件零件的**一次**（核心实现）。
##
## 返回 `{ok, why, target, 到, key, 零件, 类型, 从, 距离, 免费, 推进剂, 揭雾, 额外, 次数剩}`：
##   · `ok: false` → `why` 是给玩家看的原因（推进剂不足 / 目标不在范围里 / 次数用尽 …）；
##   · `target`（= `到`，旧字段名）= **实际落点格号**（bagua 由内部随机抽出后回填在这里）；
##   · `额外` = `{希望, 源碳, 推进剂, 探明, 经验}` 的数值明细（没有的就是 0；`经验` 只是兼容占位，恒 0）。
##
## 目标格规则：`target_cell_id < 0` 或不在目标里 → 非 bagua 直接拒绝；bagua 则从
## `bagua_candidates(state)` 里确定性随机抽一个（同时兼容调用方显式传合法候选格）。
static func use_part(state: RunState, part_index: int, target_cell_id: int = -1) -> Dictionary:
	if state == null:
		return {"ok": false, "why": "还没有进行中的局"}
	if part_index < 0 or part_index >= state.parts.size():
		return {"ok": false, "why": "没有这件零件（下标 %d，手上有 %d 件）" % [part_index, state.parts.size()]}
	var p: Variant = state.parts[part_index]
	if not (p is Dictionary):
		return {"ok": false, "why": "没有这件零件（下标 %d）" % part_index}
	var key := part_key(p)
	var P := part_info(key)
	if P.is_empty():
		return {"ok": false, "why": "数据表里没有这件零件（%s）" % key, "key": key}
	var 名 := String(P.get("名", key))
	if not bool(P.get("用", false)):
		var 缘由 := String(P.get("用不了", "被动常驻，不能主动使用"))
		return {"ok": false, "why": "【%s】不能用（%s）" % [名, 缘由], "key": key, "零件": 名, "passive": true}
	var pd: Dictionary = p
	if pd.get("uses") != null and int(pd["uses"]) <= 0:
		return {"ok": false, "why": "【%s】的使用次数已经用尽" % 名, "key": key, "零件": 名}
	var 免费 := part_is_free(key)
	if not 免费 and int(state.propellant) < 1:
		return {"ok": false, "why": "推进剂不足（需 1 点）", "key": key, "零件": 名,
			"free": false, "推进剂": 0}
	var target := int(target_cell_id)
	var 范围 := part_range(key)
	if 范围 == "bagua":
		var 候选 := bagua_candidates(state)
		if 候选.is_empty():
			return {"ok": false, "why": "本层没有可以传送的非战斗格", "key": key, "零件": 名}
		if target < 0 or not 候选.has(target):
			var i := _bagua_index(state, 候选.size())
			if i < 0:
				return {"ok": false, "why": "本层没有可以传送的非战斗格", "key": key, "零件": 名}
			target = int(候选[i])
	else:
		var 目标 := part_targets(state, key)
		if not 目标.has(target):
			return {"ok": false, "why": "【%s】到不了那一格（这一格不在它的范围内）" % 名, "key": key, "零件": 名}

	# ---- 扣推进剂（免费的三件不扣；扣了就在日志里记账） ----
	var 旧 := state.node_id
	var 耗 := 0
	if not 免费:
		耗 = 1
		var 前推 := int(state.propellant)
		state.propellant = maxi(0, 前推 - 1)
		state.add_log("零件【%s】位移消耗 %d 点推进剂（%d → %d）" % [名, 耗, 前推, state.propellant])

	# ---- 瞬移落点：只揭开落点本身（中间格不触发事件、不揭雾）----
	var 前格 := cell_xy(state, 旧)
	state.node_id = target
	state.mark_visited(target)
	var 揭 := state.mark_revealed(target)
	var cell := state.cell_at(target)
	var 落 := cell_xy(state, target)
	var dx := absi(int(落["x"]) - int(前格["x"]))
	var dy := absi(int(落["y"]) - int(前格["y"]))

	# ---- 大地图移动一次 → 浪花波动 ----
	var 浪变 := wave_fluctuate(state)

	# ---- 特殊奖励 ----
	## ★ `额外` 的键固定给全（没有的就是 0）：UI 只画非 0 的项，旧调用按老键读也不会崩。
	##   `经验` 只是**兼容占位**（原版融雪不再给经验，恒 0）。
	var 额外 := {"希望": 0, "源碳": 0, "推进剂": 0, "探明": 0, "经验": 0}
	if key == "thaw":
		state.hope = int(state.hope) + 2
		额外["希望"] = 2
		state.add_log("【老妈的融雪】：落到非战斗格 (%d, %d)，希望 +2（现在 %d）" % [
			int(落["x"]) + 1, int(落["y"]) + 1, state.hope])
	elif key == "tentacle":
		state.carbon = int(state.carbon) + 4
		额外["源碳"] = 4
		state.add_log("【坎诺特的触须】：直达已探明的黑市，源碳 +4（现在 %d）" % state.carbon)
	elif key == "bagua":
		state.add_log("【小八界】：随机传送到 (%d, %d) %s" % [
			int(落["x"]) + 1, int(落["y"]) + 1, cell_type(cell)])

	# ---- 扣次数（归 0 从手上移除）----
	var 剩 := -1
	if pd.get("uses") != null:
		pd["uses"] = int(pd["uses"]) - 1
		剩 = int(pd["uses"])
		if 剩 <= 0:
			剩 = 0
			state.parts.remove_at(part_index)

	state.add_log("使用零件【%s】：(%d, %d) → (%d, %d)（%s；%s）" % [
		名, int(前格["x"]) + 1, int(前格["y"]) + 1, int(落["x"]) + 1, int(落["y"]) + 1,
		cell_type(cell), "免推进剂" if 免费 else "耗 1 推进剂"])
	if not 浪变.is_empty():
		state.add_log("浪花估价波动：%s（可在黑市按新的估价卖出）" % "、".join(浪变))

	return {
		"ok": true, "why": "", "key": key, "零件": 名, "target": target, "到": target,
		"类型": cell_type(cell), "从": 旧, "距离": dx + dy, "几何距离": maxi(dx, dy),
		"免费": 免费, "推进剂": 耗, "揭雾": 揭, "次数剩": 剩, "额外": 额外,
	}

static func 用零件(state: RunState, part_index: int, target_id: int = -1) -> Dictionary:
	return use_part(state, part_index, target_id)

# ==========================================================================================
# 六、黑市：买 / 卖
# ==========================================================================================

## 黑市买价（`94-零件.js:408-413`）：`round(价 × (有 f1 藏品 ? 0.7 : 1))`。
static func buy_price(state: RunState, part_id: String) -> int:
	var 价: Variant = part_info(part_id).get("价")
	if 价 == null:
		return 0
	var 打折 := 0.7 if state.has_relic(打折藏品) else 1.0
	return int(JsCompat.js_round(float(价) * 打折))

## 一件零件卖掉能换多少源碳：
##   · 自然物 → **当前估价**（血蕈 / 浪花）；
##   · 加工品 / 概念体 → **固定 1 源碳**。
static func sell_price(p: Variant) -> int:
	var key := part_key(p)
	var P := part_info(key)
	if P.is_empty():
		return 0
	if String(P.get("类", "")) == "自然物":
		return maxi(0, current_value(p))
	return 1

## 卖零件（战棋 `30:117-120`）：源碳到账、零件从手上移走、河谷祭祈要重算上限。
static func sell_part(state: RunState, index: int) -> Dictionary:
	if index < 0 or index >= state.parts.size():
		return {}
	var p: Variant = state.parts[index]
	var key := part_key(p)
	var 价 := sell_price(p)
	state.carbon += 价
	state.parts.remove_at(index)
	if key == "rite":
		recalc_propellant_bonus(state)
	var 名 := String(part_info(key).get("名", key))
	state.add_log("卖出零件【%s】+%d 源碳结晶" % [名, 价])
	return {"ok": true, "价": 价, "名": 名}

static func 卖出价(p: Variant) -> int:
	return sell_price(p)
static func 卖零件(state: RunState, index: int) -> Dictionary:
	return sell_part(state, index)
static func 零件价(state: RunState, part_id: String) -> int:
	return buy_price(state, part_id)
