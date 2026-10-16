## 零件系统（PartSystem）—— 对齐封存 JS 参考版 `src/js/94-零件.js`（战棋 `23-零件.js` 13 件全表）。
##
## 覆盖：13 件零件的数据查询 / 获取（`grant_part`，★ 箱满「保留新的、丢掉参考价最低的旧件」）/
## 重算推进剂上限加成（河谷祭祈）/ 11 件主动零件的目标格枚举（`part_targets`）/
## 使用主动零件位移（`use_part`，含 `thaw` +2 希望 +3 经验、`bagua` 探明四邻 +1 推进剂）/
## `bloodcap` 战后估价 +2（封顶 15）/ `wave` 移动后估价在 2~8 间确定性波动（**不消耗 rng**）/
## 黑市买卖折算（自然物按当前估价；加工品 / 概念体 `max(2, floor(价 × 0.6))`）。
##
## 组织约定：零件条目的主键字段是 **`id`**（与 `RunState.parts` / `NodeResolver` 一致），
## 读数时也接受 JS 的 `k`。原生 Godot 强类型实现：**零 `J.*`**。
class_name PartSystem
extends RefCounted

const 零件箱初值兜底 := 8
const 血蕈估价上限兜底 := 15
const 非战斗节点兜底: Array = ["空", "黑市", "休整", "招募站", "事件", "瞭望站", "遗迹", "隧道"]
## 黑市打折藏品（`94-零件.js:411` 的 `f1`：`price × 0.7`）。
const 打折藏品 := "f1"

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

## 能在地图上真的**用出来**的零件（`用: true`，11 件）。
static func active_part_ids() -> Array:
	var out: Array = []
	for k in part_table().keys():
		if bool((part_table()[k] as Dictionary).get("用", false)):
			out.append(String(k))
	return out

## 能掉落 / 能买到的零件（`用` 或 `可买`，13 件）。
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

## 血蕈估价上限（15，`94-零件.js:215`）。
static func 血蕈估价上限() -> int:
	var v: Variant = Db.T.get("血蕈估价上限")
	return int(v) if v != null else 血蕈估价上限兜底

## 非战斗节点集合（`94-零件.js:306`）。
static func non_combat_types() -> Array:
	var v: Variant = Db.T.get("非战斗节点")
	return (v as Array) if v is Array else 非战斗节点兜底

## 新零件实例（战棋 `newPart`）：`{"id", "uses", "value"}`；次数 / 估价没有就是 null。
static func new_part(part_id: String) -> Dictionary:
	var P := part_info(part_id)
	if P.is_empty():
		return {}
	return {
		"id": part_id,
		"uses": int(P["次数"]) if P.get("次数") != null else null,
		"value": int(P["估价"]) if P.get("估价") != null else null,
	}

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

## 这一件在表里的初始估价（自然物：血蕈 3 / 浪花 4）。
static func _table_value(part_id: String) -> int:
	var v: Variant = part_info(part_id).get("估价")
	return int(v) if v != null else 0

## 这一件当前的有效估价（手上那件的 `value`，坏值 / null → 表里的估价）。
static func current_value(p: Variant) -> int:
	var key := part_key(p)
	var 表 := _table_value(key)
	if not (p is Dictionary):
		return 表
	var v: Variant = (p as Dictionary).get("value")
	if v == null:
		return 表
	var f := float(v)
	return int(f) if f > 0.0 else 表

## 抽一个零件（`94-零件.js:277-284`）：`种子 + 层×211 + 格号×23 + 场次×29`。
static func draw_part(state: RunState, cell_id: int = -1) -> String:
	var 池 := tradable_part_ids()
	if 池.is_empty():
		return ""
	var 格 := state.node_id if cell_id < 0 else cell_id
	var rng := Mulberry32.new((state.seed_val + state.floor_num * 211 + 格 * 23 + state.battles_fought * 29) & 0xFFFFFFFF)
	return String(池[mini(池.size() - 1, floori(rng.next_float() * float(池.size())))])

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
# 三、动态估价（★ 都不消耗 rng）
# ==========================================================================================

## 血蕈：每次**战斗胜利后**估价 +2（封顶 15，战棋 `31-战斗.js:283`）。返回涨过价的文本。
static func bloodcap_appreciate(state: RunState, cap: int = -1) -> Array:
	var 顶 := 血蕈估价上限() if cap < 0 else cap
	var 涨: Array = []
	for p in state.parts:
		if not (p is Dictionary) or part_key(p) != "bloodcap":
			continue
		var d: Dictionary = p
		var 旧 := current_value(d)
		var 新 := mini(顶, 旧 + 2)
		d["value"] = 新
		涨.append("【血蕈】%d → %d 源碳" % [旧, 新])
	return 涨

## 浪花：每次**移动成功后**在 2~8 之间波动（确定性公式，**绝不消耗 rng**）。返回变过价的文本。
static func wave_fluctuate(state: RunState, cell_id: int) -> Array:
	var v := ((state.seed_val + state.floor_num * 31 + cell_id * 17 + state.visited_cells.size() * 13) & 0xFFFFFFFF) % 7 + 2
	var 变: Array = []
	for p in state.parts:
		if not (p is Dictionary) or part_key(p) != "wave":
			continue
		var d: Dictionary = p
		var 旧 := current_value(d)
		d["value"] = v
		if 旧 != v:
			变.append("【浪花】%d → %d 源碳" % [旧, v])
	return 变

# ==========================================================================================
# 四、目标格（照战棋 `30-移动与节点.js:6-16` 的 partTargets）
# ==========================================================================================

## 本层的黑市格号（坎诺特的触须用）；没有 → −1。
static func black_market_cell(state: RunState) -> int:
	for k in MapNavigator.cell_ids(state):
		if String(state.cell_at(k).get("类型", "")) == "黑市":
			return k
	return -1

## 用某一件零件**能点哪些格**（界面靠它高亮，测试靠它验规则）。返回格号数组（升序）。
static func part_targets(state: RunState, part_id: String) -> Array:
	var P := part_info(part_id)
	if P.is_empty() or not bool(P.get("用", false)):
		return []
	var 移动 := String(P.get("移动", ""))
	if 移动 == "shop":
		var s := black_market_cell(state)
		return [s] if s >= 0 else []
	var 距离 := MapNavigator.full_distances(state)
	var 非战斗 := non_combat_types()
	var out: Array = []
	for k in MapNavigator.cell_ids(state):
		if not MapNavigator.walkable(state, k):
			continue
		var d: Variant = 距离.get(k)
		var dd := int(d) if d != null else -1
		if 移动 == "ring":
			if k != state.node_id and dd == 1:
				out.append(k)
		elif 移动 == "ringline":
			if k != state.node_id and (dd == 1 or dd == 2):
				out.append(k)
		elif 移动 == "line2":
			if dd == 2:
				out.append(k)
		elif 移动 == "line3":
			if dd == 2 or dd == 3:
				out.append(k)
		elif 移动 == "step":
			if dd == 1 or dd == 2:
				out.append(k)
		elif 移动 == "any":
			if k != state.node_id:
				out.append(k)
		elif 移动 == "fly":
			if k != state.node_id and 非战斗.has(String(state.cell_at(k).get("类型", ""))) and MapNavigator.is_known(state, k):
				out.append(k)
	return out

# 中文别名
static func 零件目标(state: RunState, part_id: String) -> Array:
	return part_targets(state, part_id)
static func 黑市格(state: RunState) -> int:
	return black_market_cell(state)

# ==========================================================================================
# 五、用掉一件（不消耗推进剂）
# ==========================================================================================

## 用掉这一件零件的**一次**（`94-零件.js:353-399`）：扣次数、不花推进剂、落地即「走过」。
## 附加效果：`thaw` +2 希望 +3 经验；`bagua` 探明落点四邻格 + 回复 1 推进剂。
static func use_part(state: RunState, part_index: int, target_id: int) -> Dictionary:
	if part_index < 0 or part_index >= state.parts.size():
		return {"ok": false, "为什么": "没有这件零件"}
	var p: Variant = state.parts[part_index]
	var key := part_key(p)
	var P := part_info(key)
	if P.is_empty() or not bool(P.get("用", false)):
		return {"ok": false, "为什么": "【%s】这一版用不了（%s）" % [
			String(P.get("名", key)), String(P.get("用不了", "没有实现"))]}
	var target := int(target_id)
	var 距离 := MapNavigator.full_distances(state)
	var 目标 := part_targets(state, key)
	if not 目标.has(target):
		return {"ok": false, "为什么": "【%s】到不了那一格（这一格不在它的目标里）" % String(P["名"])}
	var d: Variant = 距离.get(target)
	# 扣次数（战棋 30:10：`p.uses--; if (p.uses <= 0) RUN.parts.splice(...)`）
	var pd: Dictionary = p
	if pd.get("uses") != null:
		pd["uses"] = int(pd["uses"]) - 1
		if int(pd["uses"]) <= 0:
			state.parts.remove_at(part_index)
	var 旧 := state.node_id
	state.node_id = target
	state.mark_visited(target)
	if String(P.get("移动", "")) == "shop" or String(P.get("移动", "")) == "any":
		state.mark_revealed(target)
	var cell := state.cell_at(target)
	state.add_log("使用零件【%s】：(%d, %d) → (%d, %d)（%s%s），不消耗推进剂" % [
		String(P["名"]), int(state.cell_at(旧).get("列", 0)) + 1, int(state.cell_at(旧).get("行", 0)) + 1,
		int(cell.get("列", 0)) + 1, int(cell.get("行", 0)) + 1, String(cell.get("类型", "")),
		"" if d == null else "，%d 步" % int(d)])
	var 额外 := {"希望": 0, "经验": 0, "推进剂": 0, "探明": 0}
	if key == "thaw":
		state.hope += 2
		额外["希望"] = 2
		额外["经验"] = 3
		state.gain_exp(3, "老妈的融雪")
		state.add_log("【老妈的融雪】：飞跃到已知的非战斗格，额外获得 +2 希望（现在 %d）、+3 经验" % state.hope)
	elif key == "bagua":
		state.revealed_cells = state.revealed_cells if state.revealed_cells is Array else []
		var cols := MapNavigator.columns(state)
		var 探 := 0
		for x in MapGenerator.neighbors_of(target, cols):
			if not state.has_cell(x):
				continue
			if state.mark_revealed(x):
				探 += 1
		额外["探明"] = 探
		var 上限 := MapGenerator.propellant_max(state)
		state.propellant = mini(上限, state.propellant + 1)
		额外["推进剂"] = 1
		state.add_log("【小八界】：落地探明周边 %d 格，并回复 +1 推进剂（现在 %d / %d）" % [探, state.propellant, 上限])
	return {"ok": true, "到": target, "类型": String(cell.get("类型", "")), "距离": (int(d) if d != null else -1),
		"零件": String(P["名"]), "从": 旧, "额外": 额外}

static func 用零件(state: RunState, part_index: int, target_id: int) -> Dictionary:
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

## 一件零件卖掉能换多少源碳（`94-零件.js:422-432`）：
## 自然物按**这一件自己的估价**；加工品 / 概念体 `max(2, floor(价 × 0.6))`。
static func sell_price(p: Variant) -> int:
	var key := part_key(p)
	var P := part_info(key)
	if P.is_empty():
		return 0
	if String(P.get("类", "")) == "自然物":
		var 表 := _table_value(key)
		var v := current_value(p)
		if v > 0:
			return v
		return 表 if 表 > 0 else 0
	var 价: Variant = P.get("价")
	var n := int(价) if 价 != null else 4
	return maxi(2, floori(float(n) * 0.6))

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
