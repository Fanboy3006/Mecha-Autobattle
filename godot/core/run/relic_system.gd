## 58 藏品系统（局外逻辑）——原生 Godot，**零 `J.*`**。
##
## 逐字对齐封存 JS 参考版 `src/js/93-藏品.js` 的「获取 / 发奖 / 编制 / 每层希望」那几段
## （战斗内注入在 `core/battle/relic_battle.gd`，本文件只管大地图这一侧）：
##   · `藏品可抽池()` / `藏品候选()`：只抽 `抽: true` 的件，已持有的一律剔除（**不重复**）；
##   · `抽藏品(run, rng, 节点序)`：种子 = `种子 + 层×613 + 场次×37 + 格号×11`；
##   · `拿藏品(id, 来源)`：重复 → `null`；`数值.希望` 立刻到账；`数值.出击上限` 立刻生效（现算）；
##   · `战斗胜利发藏品(类型, 节点)`：精英 / Boss 才发；抽干 / 已持有 → 转源碳 `+5`；
##   · `编制类额外掉落(格类型, 节点)`：每场战斗胜利额外掷一次（15%，`d1/d2/c1/c2`）；
##   · `藏品每层希望(R, 层)`：`d3 战线收缩令` 每进一层 `+2` 希望；
##   · 编制类（`d1/d2/c1/c2/f4/d3`）对出击上限的修正走 `RosterManager.deploy_limit_bonus()`。
class_name RelicSystem
extends RefCounted

const 藏品转源碳 := 5
const 编制类额外掉率 := 0.15
const 编制类藏品 := ["d1", "d2", "c1", "c2"]

static func 表() -> Dictionary:
	return Db.catalog.relics()

static func 件(id: String) -> Dictionary:
	return Db.catalog.relic(id)

static func 名(id: String) -> String:
	var r := 件(id)
	return String(r.get("名")) if not r.is_empty() else id

static func 说明(id: String) -> String:
	var r := 件(id)
	return String(r.get("说明")) if not r.is_empty() else ""

static func 数值(r: Dictionary) -> Dictionary:
	return r.get("数值") if r.get("数值") is Dictionary else {}

static func 是编制类(id: String) -> bool:
	var v: Variant = 数值(件(id)).get("出击上限")
	return v is int or v is float

## 能进随机池的藏品（`抽: true`；键顺序 = 表里的插入顺序 = JS 的遍历顺序）。
static func 可抽池() -> Array:
	var 出 := []
	for id in 表().keys():
		var r: Variant = 表()[id]
		if r is Dictionary and r.get("抽") == true:
			出.append(String(id))
	return 出

static func 候选(已有: Array) -> Array:
	var 出 := []
	for id in 可抽池():
		if not 已有.has(id):
			出.append(id)
	return 出

## 抽一件（确定性：不传 rng 时按「种子 + 层×613 + 场次×37 + 格号×11」自己造）。
static func 抽藏品(state: RunState, rng: Variant = null, 格号: int = 0) -> Variant:
	var 池 := 候选(state.relics)
	if 池.is_empty():
		return null
	var r: Mulberry32 = rng
	if r == null:
		r = Mulberry32.new(state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + 格号 * 11)
	var i := mini(池.size() - 1, int(floor(r.next_float() * float(池.size()))))
	return 池[i]

## 拿到一件藏品（重复 → 空字典；成功时写日志 + 立刻结算「希望 / 出击上限」）。
static func 拿藏品(state: RunState, id: String, 来源: String = "战斗胜利") -> Dictionary:
	if state == null:
		return {}
	var r := 件(id)
	if r.is_empty() or state.relics.has(id):
		return {}
	state.relics.append(id)
	state.add_log("获得藏品【%s】：%s（%s）" % [名(id), 说明(id), 来源])
	var 值 := 数值(r)
	var 加希望: Variant = 值.get("希望")
	if 加希望 is int or 加希望 is float:
		state.hope += int(加希望)
		RosterManager.记希望来源(state, "藏品", int(加希望))
		state.add_log("藏品【%s】：希望 +%d（立刻到账，现在 %d）" % [名(id), int(加希望), state.hope])
	if 是编制类(id):
		var 加 := int(值.get("出击上限"))
		state.add_log("藏品【%s】：出击上限 %s%d 台（现在 %d 台，编制类共 %d 件）"
			% [名(id), "+" if 加 > 0 else "", 加, RosterManager.deploy_limit(state), 编制件数(state)])
	return r

static func 编制件数(state: RunState) -> int:
	var n := 0
	for id in state.relics:
		if 是编制类(String(id)):
			n += 1
	return n

## 「每进一层 +N 希望」类藏品（`d3 战线收缩令`）。返回这一次给了几点。
static func 藏品每层希望(state: RunState, 层: int) -> int:
	if state == null:
		return 0
	var n := 0
	var 名们 := []
	for id in state.relics:
		var r := 件(String(id))
		var v: Variant = 数值(r).get("每层希望")
		if v is int or v is float:
			n += int(v)
			名们.append(名(String(id)))
	if n == 0:
		return 0
	state.hope += n
	RosterManager.记希望来源(state, "藏品", n)
	state.add_log("藏品【%s】：进入第 %d 层，希望 +%d（现在 %d）" % ["、".join(名们), 层, n, state.hope])
	return n

## 精英 / Boss 战胜利发 1 件；拿满（或算出来的那件已在手上）→ 转源碳 `+5`。
static func 战斗胜利发藏品(state: RunState, 类型: String, 格号: int = 0) -> Dictionary:
	if state == null:
		return {}
	if 类型 != "精英" and 类型 != "Boss":
		return {}
	var id: Variant = 抽藏品(state, null, 格号)
	if id != null:
		var r := 拿藏品(state, String(id), "Boss 战胜利" if 类型 == "Boss" else "精英战胜利")
		if not r.is_empty():
			return {"id": String(id), "名": 名(String(id)), "说明": 说明(String(id))}
	state.carbon += 藏品转源碳
	state.add_log("%s战胜利：藏品已经拿全了，转成源碳结晶 +%d" % [类型, 藏品转源碳])
	return {"id": null, "源碳": 藏品转源碳}

## 编制类「低概率额外出现」：每场战斗胜利额外掷一次（15%）。
static func 编制类额外掉落(state: RunState, 格类型: String, 格号: int = 0) -> Dictionary:
	if state == null:
		return {}
	var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + 格号 * 17)
	if not (r.next_float() < 编制类额外掉率):
		return {}
	var 池 := []
	for id in 编制类藏品:
		if not 件(id).is_empty() and not state.relics.has(id):
			池.append(id)
	if 池.is_empty():
		return {}
	var id := String(池[mini(池.size() - 1, int(floor(r.next_float() * float(池.size()))))])
	var 件获 := 拿藏品(state, id, "编制类额外掉落")
	if 件获.is_empty():
		return {}
	state.add_log("编制类额外掉落（%d%% 额外掷一次，%s胜利）：【%s】%s"
		% [int(JsCompat.js_round(编制类额外掉率 * 100.0)), 格类型 if not 格类型.is_empty() else "战斗", 名(id), 说明(id)])
	return {"id": id, "名": 名(id), "说明": 说明(id), "额外": true, "掉率": 编制类额外掉率}

## 构建开战选项（交给 `Setup.开局` 的第四 / 第五参数）。
static func build_battle_options(state: RunState) -> Dictionary:
	return {
		"战术卡牌": true,
		"已选战术牌": state.tactical_deck.duplicate(),
		"藏品": state.relics.duplicate(),
	}
