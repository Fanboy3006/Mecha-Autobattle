## 名册 / 招募券 / 晋升（原生 Godot，**零 `J.*`**）。
##
## 这是封存 JS 参考版这几个口子的 GDScript 移植（逐字对齐语义，只是换成强类型写法）：
##   · `src/js/90-肉鸽-2-招募券与晋升.js`：`券偏移` / `券合` / `归一券` / `发券` / `随机券`
##     / `掷战后券` / `发开局券` / `找同类券` / `晋升要多少` / `晋升预览` / `催选战术牌`
##   · `src/js/90-肉鸽-5-晋升与通关.js`：`晋升()` / `招募()`
##   · `src/js/90-肉鸽-1-数据与规则.js`：`招募等级()` / `带队核心*` / `升级门槛()` / `加经验()`
##   · `src/js/90-肉鸽-6-存档与收尾.js`：`战后回血()` / `记战斗HP()`
##   · `src/js/05-阵型.js`：`出击上限()` / `藏品部署位加成()`
##
## 随机数一律 `Mulberry32`（禁 `randi` / `Math.random` 等价物）；
## 四舍五入一律 `JsCompat.js_round`；排序用 `JsCompat.stable_sort`。
##
## 额外态（黑市货架 / 事件已选 / 招募站已领券 / 每层小径 …）**不进 RunState 的顶层字段**，
## 统一放在 `state.map_data["_rogue"]` 这个子字典里 —— 这样 `RunState.to_dict()` / `from_dict()`
## 一个字都不用改，存档也能把这些态一起带上（`map_data.duplicate(true)`）。
class_name RosterManager
extends RefCounted

const 券偏移 := {
	"发券": 331,
	"随机": 197,
	"开局职业基": 401,
	"通用": 20261011,
	"事件": 839,
	"事后掷": 1073,
}
const 晋升价格 := {
	"S": {"p20": 3, "p30": 4},
	"A": {"p20": 2, "p30": 3},
	"B": {"p20": 1, "p30": 2},
}
const 带队核心等级 := 20
const 带队核心标记 := "★带队核心"
const 带队核心预告 := "带队核心：这一台直接 Lv20（分队特权）"

# ======================== 取数工具 ========================
static func cfg() -> Dictionary:
	return Db.catalog.roguelike_config()

static func 数(v: Variant, 默认: float = 0.0) -> float:
	if v is int or v is float:
		return float(v)
	if v is String:
		var s: String = (v as String).strip_edges()
		return s.to_float() if s.is_valid_float() else 默认
	return 默认

static func 整数(v: Variant, 默认: int = 0) -> int:
	return int(数(v, float(默认)))

static func 字符串(v: Variant, 默认: String = "") -> String:
	return str(v) if (v is String or v is StringName) else 默认

static func 表(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

static func 列(v: Variant) -> Array:
	return v if v is Array else []

static func 类们() -> Array:
	return 列(Db.T.get("CLASSES"))

static func 势力们() -> Array:
	return 列(Db.T.get("FACTIONS"))

static func 是自定义类(名: String) -> bool:
	return 类们().has(名) or 势力们().has(名)

static func 模板(键: Variant) -> Dictionary:
	var t = DataFn.tplOf(键)
	return t if t is Dictionary else {}

static func 标签(键: Variant) -> Dictionary:
	var t := 模板(键)
	return 表(t.get("tags"))

static func 档(键: Variant) -> String:
	var t: Dictionary = Db.T.get("TIER") if Db.T.get("TIER") is Dictionary else {}
	var v: Variant = t.get(键)
	return str(v) if v != null else "B"

static func 档名(键: Variant) -> String:
	var t: Dictionary = Db.T.get("TIER_NAME") if Db.T.get("TIER_NAME") is Dictionary else {}
	var v: Variant = t.get(档(键))
	return str(v) if v != null else "普通"

# ======================== 额外态（挂在 state.map_data["_rogue"]） ========================
static func 特记(state: RunState) -> Dictionary:
	if not (state.map_data.get("_rogue") is Dictionary):
		state.map_data["_rogue"] = {}
	return state.map_data["_rogue"]

static func 特取值(state: RunState, 键: String, 默认: Variant = null) -> Variant:
	var v: Variant = 特记(state).get(键)
	return 默认 if v == null else v

static func 特置(state: RunState, 键: String, 值: Variant) -> void:
	特记(state)[键] = 值

static func 记希望来源(state: RunState, 来源: String, n: int) -> void:
	if n == 0:
		return
	var 账: Dictionary = 特记(state).get("希望来源") if 特记(state).get("希望来源") is Dictionary else {}
	账[来源] = 整数(账.get(来源)) + n
	特记(state)["希望来源"] = 账

# ======================== 招募券 ========================
## 归一一张券（照 `归一券()`）：认不出来 → 空字典（调用方丢掉这一条）。
static func 归一券(x: Variant) -> Dictionary:
	if x is String:
		var s: String = (x as String).strip_edges()
		if s.is_empty() or not 是自定义类(s):
			return {}
		return {"类": "职业" if 类们().has(s) else "势力", "名": s, "档": null, "来源": "旧存档"}
	if not (x is Dictionary):
		return {}
	var 名 := 字符串(x.get("名")).strip_edges()
	if 名.is_empty() or not 是自定义类(名):
		return {}
	var 类 := 字符串(x.get("类"))
	if 类 != "职业" and 类 != "势力":
		类 = "职业" if 类们().has(名) else "势力"
	var 档值: Variant = x.get("档")
	var 档出: Variant = null
	if 档值 == "S" or 档值 == "A" or 档值 == "B":
		档出 = 档值
	var 来源 := 字符串(x.get("来源"))
	if 来源.is_empty():
		来源 = "旧存档"
	return {"类": 类, "名": 名, "档": 档出, "来源": 来源}

## 把 `state.tickets` 归一成干净数组（坏条目丢掉、顺序保持）。
static func 归一券们(券们: Variant, 来源: String = "") -> Array:
	var 出 := []
	for x in 列(券们):
		var c := 归一券(x)
		if c.is_empty():
			continue
		if not 来源.is_empty() and (字符串(c.get("来源")).is_empty() or c.get("来源") == "旧存档"):
			c["来源"] = 来源
		出.append(c)
	return 出

static func 券类(券: Variant) -> String:
	if not (券 is Dictionary):
		return ""
	var 类 := 字符串(券.get("类"))
	if 类 == "职业" or 类 == "势力":
		return 类
	var 名 := 字符串(券.get("名"))
	if 类们().has(名):
		return "职业"
	if 势力们().has(名):
		return "势力"
	return ""

static func 券名(券: Variant) -> String:
	if not (券 is Dictionary) or 字符串(券.get("名")).is_empty():
		return "招募券"
	var 类 := 券类(券)
	if 类.is_empty():
		类 = "势力"
	return ("%s招募券" % 券["名"]) if 类 == "职业" else ("%s势力招募券" % 券["名"])

static func 券文字(券: Variant) -> String:
	if not (券 is Dictionary):
		return "招募券"
	var 类 := 券类(券)
	var 来源 := 字符串(券.get("来源"))
	return "「%s」（%s%s）" % [券名(券), 类 if not 类.is_empty() else "", (" · 来源：%s" % 来源) if not 来源.is_empty() else ""]

## 这张券能不能招 / 晋升这台机体（照 `券合()` = 战棋的 `ticketOk`）。
static func 券合(券: Variant, 键: Variant) -> bool:
	if not (券 is Dictionary):
		return false
	var 名 := 字符串(券.get("名"))
	if 名.is_empty() or not 是自定义类(名):
		return false
	var tags := 标签(键)
	if tags.is_empty():
		return false
	var 类 := 券类(券)
	if 类.is_empty():
		return false
	var 本类 := (str(tags.get("战斗分类")) == 名) if 类 == "职业" else (str(tags.get("势力")) == 名)
	var 券档: Variant = 券.get("档")
	var 本档: bool = (券档 == null) or (str(券档) == 档(键))
	return 本类 and 本档

static func 券合机师们(券: Variant) -> Array:
	var 出 := []
	for t in 列(Db.T.get("ALLY_T")):
		if t is Dictionary and 券合(券, t.get("mech")):
			出.append(str(t.get("mech")))
	return 出

## 发一张券（**唯一**往 `state.tickets` 里推的口子）。
static func 发券(state: RunState, 类: String, 来源: String, 名: Variant = null, 偏移: Variant = null) -> Variant:
	if state == null:
		return null
	var 上限 := maxi(0, 整数(cfg().get("券上限")))
	if 上限 > 0 and state.tickets.size() >= 上限:
		return null
	var 池: Array = 势力们() if 类 == "势力" else 类们()
	if 池.is_empty():
		return null
	var 抽 := ""
	if 名 == null or 字符串(名).is_empty():
		var 偏 := 整数(偏移, 整数(券偏移["发券"]))
		var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + state.node_id * 17 + 偏)
		var i := mini(池.size() - 1, int(floor(r.next_float() * float(池.size()))))
		抽 = str(池[i])
	else:
		抽 = 字符串(名)
	var 券 := {"id": state.next_ticket_id, "类": "职业" if 类.is_empty() else 类, "名": 抽, "档": null, "来源": 来源 if not 来源.is_empty() else "未知"}
	state.next_ticket_id += 1
	state.tickets.append(券)
	return 券

## 战棋 `anyTicket()` 的「类」那一半（60% 职业 / 40% 势力）。
static func anyTicket类(state: RunState, 允许势力: bool, 偏移: Variant = null) -> String:
	if not 允许势力:
		return "职业"
	var 偏 := 整数(偏移, 整数(券偏移["通用"]))
	var r := Mulberry32.new(state.seed_val + 偏)
	var 比 := 数(cfg().get("随机券职业比"), 0.6)
	return "职业" if r.next_float() < 比 else "势力"

## 战棋 `randTicket()`：先抽「本分队券」那一签（50%），没中就 60/40 再抽类 + 名。
## **纯函数**：不发券、不写 state（返回 `{类, 名}` 或 `{}`）。
static func 随机券(state: RunState, 偏移: Variant = null) -> Dictionary:
	var 基 := 整数(偏移, 整数(券偏移["随机"]))
	var 种子基 := state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + state.node_id * 17
	var 分队 := state.squad
	if not 分队.is_empty() and 是自定义类(分队):
		var r := Mulberry32.new(种子基 + 基 + 31)
		var 比 := 数(cfg().get("分队券比"), 0.5)
		if r.next_float() < 比:
			return {"类": "职业" if 类们().has(分队) else "势力", "名": 分队}
	var r2 := Mulberry32.new(种子基 + 基)
	var 职比 := 数(cfg().get("随机券职业比"), 0.6)
	var 类: String = "职业" if r2.next_float() < 职比 else "势力"
	var 池: Array = 势力们() if 类 == "势力" else 类们()
	if 池.is_empty():
		return {}
	var i := mini(池.size() - 1, int(floor(r2.next_float() * float(池.size()))))
	return {"类": 类, "名": str(池[i])}

static func 发随机券(state: RunState, 来源: String, 偏移: Variant = null) -> Variant:
	var 选 := 随机券(state, 偏移)
	if 选.is_empty():
		return null
	return 发券(state, str(选["类"]), 来源, 选["名"], 整数(券偏移["随机"]) + 31)

## ★ 战后那张券按档掷一次（`肉鸽数值.战后券率`）。返回发出去的券或 `null`。
static func 掷战后券(state: RunState, 奖: String) -> Variant:
	if state == null:
		return null
	var 档: String = 奖
	if (Db.T.get("节点奖励类型") is Dictionary) and Db.T["节点奖励类型"].has(奖):
		档 = str(Db.T["节点奖励类型"][奖])
	var 表: Dictionary = cfg().get("战后券率") if cfg().get("战后券率") is Dictionary else {}
	var 率 := 数(表.get(档), 1.0)
	var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + state.node_id * 17 + 整数(券偏移["事后掷"]))
	var 掷 := r.next_float()
	if not (掷 < 率):
		return null
	return 发随机券(state, "战后")

## 开局发 3 张券（第 1 张 = 本分队券，其余随机职业券）。**幂等**：手上已经有券就原样返回。
static func 发开局券(state: RunState) -> Array:
	if state == null:
		return []
	if not state.tickets.is_empty():
		return state.tickets
	var 数券 := maxi(0, 整数(cfg().get("开局券数")))
	var 必有: bool = cfg().get("开局必有分队券") != false
	var 是分队券: bool = 必有 and not state.squad.is_empty() and state.squad != "无" and 是自定义类(state.squad)
	var 出 := []
	for i in 数券:
		var 券: Variant = null
		if i == 0 and 是分队券:
			券 = 发券(state, "职业" if 类们().has(state.squad) else "势力", "开局", state.squad, 整数(券偏移["发券"]))
		else:
			券 = 发券(state, "职业", "开局", null, 整数(券偏移["开局职业基"]) + i * 7)
		if 券 != null:
			出.append(券)
	return 出

## 手上第一张对得上这台机体的券 → `{下标, 券}`；找不到返回 `{}`。
static func 找同类券(state: RunState, 键: Variant) -> Dictionary:
	for i in state.tickets.size():
		if 券合(state.tickets[i], 键):
			return {"下标": i, "券": state.tickets[i]}
	return {}

static func 券汇总文字(state: RunState) -> String:
	var 序 := []
	var 数 := {}
	for c in state.tickets:
		if not (c is Dictionary):
			continue
		var 名 := 券名(c)
		if not 数.has(名):
			数[名] = 0
			序.append(名)
		数[名] = int(数[名]) + 1
	var 段 := []
	for 名 in 序:
		段.append("%s ×%d" % [名, int(数[名])])
	return "、".join(段)

# ======================== 招募 ========================
static func 招募等级(层: int) -> int:
	return mini(30, 10 * maxi(1, mini(3, 层)))

static func 是带队核心(state: RunState) -> bool:
	return state.roster.is_empty()

static func 带队核心入队文字(键: String) -> String:
	return "带队核心：%s 直接 Lv%d 入队（分队特权）" % [键, 带队核心等级]

## 招募一台（券 + 希望，二者同时消耗）。`券下标` = 手上的第几张券；`-1` = 没选券（拒绝）。
## 返回 `{ok, ...}` 或 `{ok:false, why}`。
static func recruit(state: RunState, 键: String, 券下标: int = -1) -> Dictionary:
	if state == null:
		return {"ok": false, "why": "没有进行中的局"}
	var 上限 := maxi(0, 整数(cfg().get("队伍上限"), 12))
	if state.roster.size() >= 上限:
		return {"ok": false, "why": "队伍已经满了（%d 台）" % 上限}
	if state.roster.has(键):
		return {"ok": false, "why": "这位机师已经在队里了"}
	if 模板(键).is_empty():
		return {"ok": false, "why": "没有这位机师（%s）" % 键}
	if 券下标 < 0 or 券下标 >= state.tickets.size():
		var 找 := 找同类券(state, 键)
		if 找.is_empty():
			return {"ok": false, "why": "没有可用的券（招募要用掉一张同类券：去战斗 / 招募站拿）"}
		return {"ok": false, "why": "没有选券：招募要用掉一张同类券（手上有「%s」对得上 %s）" % [券名(找["券"]), 键]}
	var 用券: Dictionary = state.tickets[券下标]
	if not 券合(用券, 键):
		var tags := 标签(键)
		return {"ok": false, "why": "%s招不了 %s（%s / %s 对不上）" % [券名(用券), 键, tags.get("战斗分类"), tags.get("势力")]}
	var 费表: Dictionary = cfg().get("招募费") if cfg().get("招募费") is Dictionary else {}
	var 费 := 整数(费表.get(档(键)))
	if state.hope < 费:
		return {"ok": false, "why": "希望不够（要 %d，只有 %d）" % [费, state.hope]}
	var 是核 := 是带队核心(state)
	var 入队等级 := 带队核心等级 if 是核 else 招募等级(state.floor_num)
	# 顺序照战棋：先删券 → 再扣希望 → 再给人
	state.tickets.remove_at(券下标)
	state.hope -= 费
	记希望来源(state, "支出", 费)
	state.roster[键] = {"key": 键, "lv": 入队等级, "hpRatio": 1.0}
	# ★ D-09（2026-10-13）：原来这里写的是 `{"key": 键, "slot": ""}` —— **字符串空值**。
	#   封存 JS 的名册（`R.队伍`）**根本没有「位」这个字段**（`90-肉鸽-5-晋升与通关.js:133`
	#   只 push `{键, 等级, hp比}`；出击位是另一份 `R.出击阵 = [{键, 位}]`），所以空串是
	#   **Godot 移植时自己塞的占位**，不是从 JS 继承来的问题；而全仓库都按 `int(slot)` 读它
	#   → `int("") == 0` → 多台新招募的机体都会被当成 0 号位，编队屏的占位 / 换位会串。
	#   改法：写「下一个空闲位号」（= 当前出击人数），与 `NodeResolver.我方编成()` 的
	#   兜底排位（按添加顺序 0,1,2…）逐位一致；`deploy_limit ≤ 7 < Fm.SLOTS() = 8`，不会越界。
	if state.lineup.size() < deploy_limit(state):
		state.lineup.append({"key": 键, "slot": state.lineup.size()})
	state.add_log("招募 %s（Lv%d，花希望 %d，用掉一张 %s）" % [键, 入队等级, 费, 券名(用券)])
	if 是核:
		state.add_log(带队核心入队文字(键))
	DeckBuilder.offer_cards(state, 键)
	return {"ok": true, "费": 费, "键": 键, "券": 用券, "券名": 券名(用券), "券下标": 券下标,
		"用券": true, "带队核心": 是核, "等级": 入队等级}

## 丢一张券（只写日志，不退不换）。
static func 丢券(state: RunState, 券下标: int) -> Dictionary:
	if state == null:
		return {"ok": false, "why": "没有进行中的局"}
	if 券下标 < 0 or 券下标 >= state.tickets.size():
		return {"ok": false, "why": "这张券不在手上了"}
	var 券: Dictionary = state.tickets[券下标]
	state.tickets.remove_at(券下标)
	state.add_log("丢弃了一张 %s（来源：%s），剩 %d 张" % [券名(券), 字符串(券.get("来源"), "未知"), state.tickets.size()])
	return {"ok": true, "券": 券, "剩": state.tickets.size()}

## 招募站领券（每个「层:格号」只领一次）。
static func 招募站领券(state: RunState) -> Dictionary:
	if state == null:
		return {"ok": false, "why": "没有进行中的局"}
	var 格键 := "%d:%d" % [state.floor_num, state.node_id]
	var 已领: Array = 特记(state).get("招募站已领券") if 特记(state).get("招募站已领券") is Array else []
	if 已领.has(格键):
		return {"ok": true, "重复": true, "券": null, "已有": state.tickets.size()}
	var 券: Variant = 发随机券(state, "招募站")
	已领.append(格键)
	特记(state)["招募站已领券"] = 已领
	state.add_log("招募站：获得【%s】（第 %d 层这一格，随机券）" % [券名(券), state.floor_num] if 券 != null else "招募站：这次没有发出券（券的种类池是空的）")
	return {"ok": true, "券": 券, "券名": 券名(券) if 券 != null else "", "重复": false, "已有": state.tickets.size()}

# ======================== 晋升 ========================
static func 晋升目标(lv: int) -> int:
	if lv == 10:
		return 20
	if lv == 20:
		return 30
	return 0

## 晋升要花多少希望（`22-输入.js:446`；战棋里后两项恒为 0）。
static func 晋升要多少(键: String, 到: int, state: RunState = null) -> int:
	var 表: Dictionary = 晋升价格.get(档(键), 晋升价格["B"])
	var 基 := 整数(表.get("p20")) if 到 == 20 else 整数(表.get("p30"))
	var 减 := 1 if (state != null and 特记(state).get("下次晋升减价") == true) else 0
	return maxi(0, 基 - 减)

static func 五维(u: Dictionary) -> Dictionary:
	return {
		"lv": 整数(u.get("lv")), "maxHp": 整数(u.get("maxHp")), "armor": 整数(u.get("armor")),
		"defense": 整数(u.get("defense")), "eva": 整数(u.get("eva")), "aim": 整数(u.get("aim")),
		"melee": 整数(u.get("melee")), "shoot": 整数(u.get("shoot")), "awaken": 整数(u.get("awaken")),
		"mov": 整数(u.get("mov")),
		"速度": 整数(JsCompat.js_round(数(u.get("mov")) * 10.0 + 数(u.get("eva")) / 2.0)),
	}

## 晋升前后的五维面板（数字**全部**来自 `Units.makeUnit()`，不在这里自己造公式）。
static func 晋升预览(键: String, 等级: int) -> Dictionary:
	var 前 := 五维(Units.makeUnit(键, "ally", 0.0, float(等级)))
	var 到 := 晋升目标(等级)
	var 后 := 五维(Units.makeUnit(键, "ally", 0.0, float(到))) if 到 != 0 else 前.duplicate(true)
	return {"键": 键, "前": 前, "后": 后, "到": 到}

## 真的晋升（先判完再动手；失败时券与希望一分不扣）。
static func promote(state: RunState, 键: String) -> Dictionary:
	if state == null:
		return {"ok": false, "why": "没有进行中的局"}
	if not state.roster.has(键):
		return {"ok": false, "why": "名册里没有这台机体"}
	var m: Dictionary = state.roster[键]
	var 从 := 整数(m.get("lv"), 10)
	var 到 := 晋升目标(从)
	if 到 == 0:
		return {"ok": false, "why": "%s 已经 Lv%d，到顶了" % [键, 从]}
	var 找 := 找同类券(state, 键)
	if 找.is_empty():
		return {"ok": false, "why": "没有可用的同类券（要一张同职业 / 同势力的招募券）"}
	var 价 := 晋升要多少(键, 到, state)
	if state.hope < 价:
		return {"ok": false, "why": "希望不够（要 %d，只有 %d）" % [价, state.hope]}
	var 前: Dictionary = 晋升预览(键, 从)["前"]
	state.tickets.remove_at(int(找["下标"]))
	state.hope -= 价
	记希望来源(state, "支出", 价)
	m["lv"] = 到
	state.roster[键] = m
	if 特记(state).get("下次晋升减价") == true:
		特记(state)["下次晋升减价"] = false
	var 后: Dictionary = 晋升预览(键, 到)["前"]
	state.add_log("%s 晋升到 Lv%d（−%d 希望，剩 %d；用掉一张 %s）：HP %d → %d、装甲 %d → %d、防御 %d → %d、机动 %d → %d"
		% [键, 到, 价, state.hope, 券名(找["券"]), 前["maxHp"], 后["maxHp"], 前["armor"], 后["armor"],
			前["defense"], 后["defense"], 前["mov"], 后["mov"]])
	DeckBuilder.offer_cards(state, 键)
	return {"ok": true, "键": 键, "从": 从, "到": 到, "价": 价, "前": 前, "后": 后,
		"券": 找["券"], "券下标": int(找["下标"]), "希望": state.hope}

## 名册上每台的晋升情况（界面 / 测试读它）。
static func 晋升清单(state: RunState) -> Array:
	var 出 := []
	var i := 0
	for 键 in state.roster.keys():
		var m: Dictionary = state.roster[键]
		var 从 := 整数(m.get("lv"), 10)
		var 到 := 晋升目标(从)
		var 价 := 晋升要多少(键, 到, state) if 到 != 0 else 0
		var 找 := 找同类券(state, 键) if 到 != 0 else {}
		var 能升: bool = 到 != 0 and state.hope >= 价 and not 找.is_empty()
		var 理由 := ""
		if 到 == 0:
			理由 = "已经 Lv30（到顶了）"
		elif 找.is_empty():
			理由 = "没有可用的同类券"
		elif not 能升:
			理由 = "希望不够（要 %d，只有 %d）" % [价, state.hope]
		出.append({"键": 键, "等级": 从, "到": 到, "价": 价, "能升": 能升, "理由": 理由,
			"带队核心": i == 0, "档": 档(键), "档名": 档名(键), "有券": not 找.is_empty(),
			"券名": 券名(找["券"]) if not 找.is_empty() else "", "券下标": int(找.get("下标", -1)),
			"属性": 晋升预览(键, 从) if 到 != 0 else {}})
		i += 1
	return 出

# ======================== 出击上限 / 经验 ========================
static func deploy_limit_bonus(state: RunState) -> int:
	var 表: Dictionary = Db.catalog.relics()
	var n := 0
	for id in state.relics:
		var 件: Dictionary = 表.get(id) if 表.get(id) is Dictionary else {}
		var 数值: Dictionary = 件.get("数值") if 件.get("数值") is Dictionary else {}
		var 加: Variant = 数值.get("出击上限")
		if 加 is int or 加 is float:
			n += int(加)
	return n

## 肉鸽等级 + 藏品加成 → 出击上限（Lv1→4 / Lv4→5 / Lv7→6，藏品可到 7，下限 1）。
static func deploy_limit(state: RunState) -> int:
	var 初 := 整数(Db.T.get("出击上限初值"), 4)
	var 成长顶 := 整数(Db.T.get("等级成长顶"), 6)
	var 绝对顶 := 整数(Db.T.get("绝对顶"), 7)
	var 每几级 := maxi(1, 整数(Db.T.get("每几级加一台"), 3))
	var 等级那条 := mini(成长顶, 初 + int(floor(float(state.level - 1) / float(每几级))))
	var n := 等级那条 + deploy_limit_bonus(state)
	return clampi(n, 1, 绝对顶)

## 下一级要多少经验（`27-开局.js:102` 的 `LV_NEED`；已经到表尾 → `null` = 升不动了）。
## ★ 表在 `肉鸽数值.等级门槛` 里（不在顶层常量里），所以要经由 `cfg()` 取。
static func 升级门槛(等级: int) -> Variant:
	var 表: Array = cfg().get("等级门槛") if cfg().get("等级门槛") is Array else []
	var i := maxi(0, 等级) + 1
	return 整数(表[i]) if i < 表.size() else null

static func 升到这一级给多少希望(等级: int) -> int:
	if 等级 <= 1:
		return 0
	var 表: Dictionary = cfg().get("每级希望表") if cfg().get("每级希望表") is Dictionary else {}
	if 表.has(str(等级)):
		return 整数(表[str(等级)])
	return 整数(cfg().get("每级希望封顶")) if 等级 > 10 else 0

## 加经验 + 自动升阶（升 1 级按分级表加希望；可能连升）。
static func 加经验(state: RunState, x: int, 来源: String = "作战") -> Dictionary:
	var 升了 := 0
	state.exp_val += x
	state.add_log("%s：经验 +%d（部队 Lv%d %d / %s）" % [来源, x, state.level, state.exp_val, str(升级门槛(state.level)) if 升级门槛(state.level) != null else "—"])
	while 升级门槛(state.level) != null and state.exp_val >= int(升级门槛(state.level)):
		state.level += 1
		var 这一点 := 升到这一级给多少希望(state.level)
		state.hope += 这一点
		记希望来源(state, "升级", 这一点)
		升了 += 1
		state.add_log("部队升到 Lv%d：希望 +%d" % [state.level, 这一点])
	return {"等级": state.level, "升了": 升了} if 升了 > 0 else {"等级": state.level, "升了": 0}

# ======================== HP 继承 / 战后回血 ========================
static func 记战斗HP(state: RunState, 战报: Variant) -> int:
	if state == null or not (战报 is Dictionary):
		return 0
	var 我方: Array = 战报.get("我方") if 战报.get("我方") is Array else []
	var n := 0
	for u in 我方:
		if not (u is Dictionary):
			continue
		var 键 := str(u.get("key"))
		if not state.roster.has(键):
			continue
		var 满 := 数(u.get("maxHp"), 1.0)
		if 满 <= 0.0:
			满 = 1.0
		var m: Dictionary = state.roster[键]
		m["hpRatio"] = clampf(maxf(0.0, 数(u.get("hp"))) / 满, 0.0, 1.0)
		state.roster[键] = m
		n += 1
	return n

## 战后回血：名册上**每一台** `hpRatio = min(1, hpRatio + 50%)`（含 0 HP 的阵亡机体）。
static func 战后回血(state: RunState) -> Dictionary:
	if state == null:
		return {}
	var c: Dictionary = Db.T.get("战斗结构") if Db.T.get("战斗结构") is Dictionary else {}
	var hp: Dictionary = c.get("HP继承") if c.get("HP继承") is Dictionary else {}
	if hp.get("开") == false:
		return {}
	var 比例 := 数(hp.get("战后回血比例"), 0.5)
	var 名字们 := []
	for 键 in state.roster.keys():
		var m: Dictionary = state.roster[键]
		var 旧 := clampf(数(m.get("hpRatio"), 1.0), 0.0, 1.0)
		var 新 := minf(1.0, 旧 + 比例)
		m["hpRatio"] = 新
		state.roster[键] = m
		if 新 > 旧:
			名字们.append("%s %d%% → %d%%" % [键, int(JsCompat.js_round(旧 * 100.0)), int(JsCompat.js_round(新 * 100.0))])
	var 文本 := "战后休整：全队回复 %d%% 最大 HP%s" % [int(JsCompat.js_round(比例 * 100.0)),
		"（%s）" % "、".join(名字们) if not 名字们.is_empty() else "（全队已满）"]
	state.add_log(文本)
	return {"台数": 名字们.size(), "回复比例": 比例, "名字们": 名字们, "有变化": not 名字们.is_empty(), "文本": 文本}

# ======================== 开局 ========================
## 开局（选分队 → 名册空 → 发 3 张券）。返回 state。
static func new_run(种子: int, 分队: String = "无", 分队类型: String = "混编") -> RunState:
	var state := RunState.new()
	var c := cfg()
	state.seed_val = 种子 if 种子 != 0 else 1
	state.squad = 分队 if not 分队.is_empty() else "无"
	state.squad_kind = 分队类型
	state.hope = 整数(c.get("起始希望"), 8)
	state.carbon = 整数(c.get("起始源碳"), 18)
	state.base_max_hp = 整数(c.get("起始耐久"), 10)
	state.base_hp = state.base_max_hp
	state.level = 1
	state.exp_val = 0
	state.propellant_max = 整数(c.get("推进剂"), 8)
	state.propellant = state.propellant_max
	state.roster = {}
	state.lineup = []
	state.tickets = []
	state.next_ticket_id = 1
	state.relics = []
	state.parts = []
	state.tactical_deck = []
	state.pending_card_picks = []
	记希望来源(state, "初始", state.hope)
	_进层(state, 1)
	var 券 := 发开局券(state)   # ★ 必须在 `_进层()` 之后：券的种子带「当前格号」（JS 的 `新的一局` 就是先 `进层(1)` 再发券）
	state.add_log("第 1 层：出发（名册是空的、分队不带机体；开局发 %d 张招募券：%s —— 去招募屏用券招人）"
		% [券.size(), 券汇总文字(state)] if not 券.is_empty() else "第 1 层：出发（名册是空的、分队不带机体；开局没有发出券）")
	return state

## 探测一个**全局类名**（`class_name`）的脚本 —— `ClassDB.class_exists()` 只认引擎 C++ 类，
## GDScript 的 `class_name` 要查 `ProjectSettings.get_global_class_list()`。
## 找不到返回 `null`（调用方一律走本地兜底，**绝不崩**）。
static func 全局脚本(类名: String) -> Variant:
	for e in ProjectSettings.get_global_class_list():
		if str(e.get("class")) == 类名:
			return load(str(e.get("path")))
	return null

## 进层：生成地图 → 落起点 → 重置推进剂与场次。
## ★ 地图生成归 `MapGenerator`（另一条线）；这里**只做能力探测**，它不在时退化成空地图（不崩）。
static func _进层(state: RunState, n: int) -> void:
	state.floor_num = n
	state.battles_fought = 0
	state.node_id = 0
	state.propellant_max = 整数(cfg().get("推进剂"), 8)
	state.propellant = state.propellant_max
	var 脚本: Variant = 全局脚本("MapGenerator")
	if 脚本 == null:
		state.map_data = {}
		return
	var 地图: Dictionary = 脚本.generate_floor(n, state.seed_val)
	state.map_data = 地图.duplicate(true)
	# ★ 把「格」的键统一成**字符串**：JSON 的对象键本来就是字符串，统一之后
	#   「存档 → 读档」的键顺序与键集逐字节一致（`MapGenerator` 生成时用的是 int 键）。
	var 格原: Variant = state.map_data.get("格")
	if 格原 is Dictionary:
		var 格新 := {}
		for k in (格原 as Dictionary).keys():
			格新[str(k)] = 格原[k]
		state.map_data["格"] = 格新
	state.node_id = 整数(地图.get("起点"), 0)
	state.propellant_max = int(脚本.propellant_max(state))
	state.propellant = state.propellant_max
	var 格: Dictionary = 地图.get("格") if 地图.get("格") is Dictionary else {}
	var 起格: Dictionary = 格.get(str(state.node_id)) if 格.get(str(state.node_id)) is Dictionary else {}
	state.map_data["当前节点类型"] = str(起格.get("类型", "普通"))
