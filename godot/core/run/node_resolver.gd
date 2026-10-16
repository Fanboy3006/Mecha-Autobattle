## 7 类节点结算 ——原生 Godot，**零 `J.*`**。
##
## 逐字对齐封存 JS 参考版：
##   · `src/js/70-编成.js`：`选编成()` / `抽编成()` / `抽编成兜底()` / `编成到单位()` /
##     `敌方规格()` / `编成波次到单位()` / `编成词条()` / `词条汇总()`
##   · `src/js/90-肉鸽-3-开局与移动.js`：`当前战斗类型()` / `本场奖励档()` / `增援波次()`
##   · `src/js/90-肉鸽-4-节点结算.js`：`战斗结束()`（奖励 / 经验 / 券 / 藏品 / 零件 / 耐久扣减）
##     + `黑市*` / `结算休整()` / `结算瞭望站()` / `结算遗迹()` / `结算隧道()` / `结算侵蚀源*()` / `补给()`
##   · `src/js/90-肉鸽-5-晋升与通关.js`：`失败耐久()` / `清空格()`
##   · `src/js/90-肉鸽-1-数据与规则.js`：`事件表`
##
## 随机数一律 `Mulberry32`；同一局同一种子同一步**逐字可复现**。
## 例外的「非确定性外部块」（`PartSystem` / 地图生成）一律先做能力探测，探测不到就走本地兜底。
class_name NodeResolver
extends RefCounted

const 兜底类型顺序 := ["普通", "精英", "守军", "侵蚀源", "Boss"]

# ======================== 基础映射 ========================
static func 战斗类型表() -> Dictionary:
	return Db.T.get("节点战斗类型") if Db.T.get("节点战斗类型") is Dictionary else {}

static func 奖励类型表() -> Dictionary:
	return Db.T.get("节点奖励类型") if Db.T.get("节点奖励类型") is Dictionary else {}

static func 编成到奖励档表() -> Dictionary:
	return Db.T.get("编成类型到奖励档") if Db.T.get("编成类型到奖励档") is Dictionary else {}

static func 类型到Kind表() -> Dictionary:
	return Db.T.get("类型到Kind") if Db.T.get("类型到Kind") is Dictionary else {}

static func cfg() -> Dictionary:
	return Db.catalog.roguelike_config()

## 节点类型 → 编成表的「类型」（第 4 层的出口守军 = 终点 Boss）。
static func 战斗类型Of(state: RunState, 覆盖类型: String = "") -> String:
	var 类型 := 覆盖类型 if not 覆盖类型.is_empty() else str(state.map_data.get("当前节点类型", "普通"))
	if 类型 == "出口守军" and state.floor_num >= 4:
		return "Boss"
	return str(战斗类型表().get(类型, "普通"))

## 节点类型 → 发奖档（战斗 / 精英 / Boss）。
static func 奖励类型Of(state: RunState, 覆盖类型: String = "") -> String:
	var 类型 := 覆盖类型 if not 覆盖类型.is_empty() else str(state.map_data.get("当前节点类型", "战斗"))
	if 类型 == "出口守军" and state.floor_num >= 4:
		return "Boss"
	return str(奖励类型表().get(类型, "战斗"))

## 编成类型 → 发奖档（兜底那一场按**实际用的那一档**发奖）。
static func 本场奖励档(state: RunState, 格类型: String) -> String:
	var 档序 := {"战斗": 0, "精英": 1, "Boss": 2}
	var 节点档 := str(奖励类型表().get(格类型, "战斗"))
	var 兜: Variant = state.map_data.get("本场兜底")
	if not (兜 is Dictionary):
		return 节点档
	if int(兜.get("层", -1)) != state.floor_num or int(兜.get("格", -1)) != state.node_id:
		return 节点档
	var 实际档: Variant = 编成到奖励档表().get(str(兜.get("到")))
	if 实际档 == null:
		return 节点档
	var 实 := str(实际档)
	var 实序 := int(档序.get(实, 0))
	var 节序 := int(档序.get(节点档, 0))
	return 实 if 实序 < 节序 else 节点档

# ======================== 抽取编成 ========================
## 这一场抽编成用的**确定性种子**（`抽当前编成详情()` 那一行的口径）。
## 测试要在开战**之前**算好它（「第 N 场」的计数在胜利结算里才 +1），所以单独开一个口子。
static func 编成种子(state: RunState, 层: int) -> int:
	return state.seed_val + 层 * 131 + state.battles_fought * 17 + state.node_id * 7

static func 选编成(层: int, 类型: String) -> Array:
	var 出 := []
	for e in Db.catalog.stages():
		if e is Dictionary and int(e.get("层", 0)) == 层 and str(e.get("类型")) == 类型:
			出.append(e)
	return 出

static func 抽一条(层: int, 类型: String, rng: Mulberry32) -> Variant:
	var 候选 := 选编成(层, 类型)
	if 候选.is_empty():
		return null
	var i := mini(候选.size() - 1, int(floor(rng.next_float() * float(候选.size()))))
	return 候选[i]

## 抽一条编成，**永远抽得到**（返回 `{条目, 层, 类型, 兜底, 日志}`）。
static func 抽编成兜底(层: int, 类型: String, rng: Mulberry32) -> Dictionary:
	var 日志 := []
	var 第一: Variant = 抽一条(层, 类型, rng)
	if 第一 != null:
		return {"条目": 第一, "层": 层, "类型": 类型, "兜底": null, "日志": 日志}
	var 退到 := func(条目: Variant, 实际层: int, 实际类型: String, 原因: String) -> Dictionary:
		日志.append("编成兜底：第 %d 层没有「%s」编成 → 改用第 %d 层「%s」编成（%s）" % [层, 类型, 实际层, 实际类型, 原因])
		return {"条目": 条目, "层": 实际层, "类型": 实际类型, "兜底": 原因, "日志": 日志}
	if 类型 != "普通":
		var 普通条: Variant = 抽一条(层, "普通", rng)
		if 普通条 != null:
			return 退到.call(普通条, 层, "普通", "这一层没有这个类型的编成，退回同层普通")
	for t in 兜底类型顺序:
		if t == 类型 or t == "普通":
			continue
		var 条: Variant = 抽一条(层, t, rng)
		if 条 != null:
			return 退到.call(条, 层, t, "这一层连普通都没有")
	var 层们 := []
	for e in Db.catalog.stages():
		if e is Dictionary and int(e.get("层", 0)) != 层 and not 层们.has(int(e.get("层", 0))):
			层们.append(int(e.get("层", 0)))
	层们 = JsCompat.stable_sort(层们, func(a, b): return absi(int(a) - 层) < absi(int(b) - 层) or (absi(int(a) - 层) == absi(int(b) - 层) and int(a) < int(b)))
	for l in 层们:
		var 条2: Variant = 抽一条(int(l), 类型, rng)
		if 条2 != null:
			return 退到.call(条2, int(l), 类型, "这一层什么编成都没有")
	var 最后: Dictionary = Db.catalog.stage(0)
	return 退到.call(最后, int(最后.get("层", 1)), str(最后.get("类型", "普通")), "全表都没有这个类型")

# ======================== 词条 ========================
static func 词条开() -> bool:
	return Params.词条开()

static func 词条组(挂: String) -> Array:
	var g := Db.catalog.trait_group(挂)
	return g if g is Array else []

## 一条编成的完整词条单（条目自带的 + `挂载` 无条件叠一份词条组）。
static func 编成词条(条目: Dictionary) -> Array:
	var 出 := []
	for t in (条目.get("词条") if 条目.get("词条") is Array else []):
		出.append(t)
	var 挂 := str(条目.get("挂载")) if 条目.get("挂载") != null else ""
	if not 挂.is_empty():
		for t in 词条组(挂):
			if t is Dictionary:
				var 条: Dictionary = t.duplicate(true)
				条["来自挂载"] = 挂
				出.append(条)
	return 出

static func 词条作用在(t: Dictionary, 位: float) -> bool:
	var 作用 := str(t.get("作用"))
	if 作用 == "全体":
		return true
	if 作用 != "单台":
		return false
	var v: Variant = t.get("位")
	if v == null:
		return false
	return float(v) == 位

## 这一台实际吃到的词条（按位过滤）。
static func 词条汇总(条目: Dictionary, 位: float) -> Array:
	var 出 := []
	for t in 编成词条(条目):
		if t is Dictionary and 词条作用在(t, 位):
			出.append(t)
	return 出

# ======================== 编成 → 敌方规格 / 波次 ========================
static func 等级Of(条目: Dictionary, 键: String, 场次: int) -> float:
	var kind := str(类型到Kind表().get(str(条目.get("类型")), "battle"))
	var 梯队 := DataFn.tierOfEnemy(键)
	var lv表: Dictionary = Db.T.get("TIER_LV") if Db.T.get("TIER_LV") is Dictionary else {}
	return Units.runEnemyLv(kind, int(条目.get("层", 1)), float(场次)) + float(lv表.get(梯队, 0))

static func 强化Of(条目: Dictionary, 键: String) -> float:
	var d := Diff.敌方强度倍率(int(条目.get("层", 1)), DataFn.tierOfEnemy(键))
	return float(d.get("倍率", 1.0))

## 一条编成 → 敌方规格数组（`{键, 位, 等级, 强化, 层, 词条}`）。
static func 编成到规格(条目: Dictionary, 场次: int = 0) -> Array:
	var 层 := int(条目.get("层", 1))
	var 行序 := [["前", Fm.ROW_FRONT], ["后", Fm.ROW_BACK]]
	var 出 := []
	for pair in 行序:
		var 键们: Array = 条目.get(pair[0]) if 条目.get(pair[0]) is Array else []
		var 行: float = pair[1]
		var 列数 := int(Fm.行列数(行))
		for i in mini(键们.size(), 列数):
			var 键 := str(键们[i])
			var 位 := Fm.slotOf(行, float(i))
			出.append({
					"键": 键, "位": 位, "等级": 等级Of(条目, 键, 场次), "强化": 强化Of(条目, 键),
					"层": 层, "词条": 词条汇总(条目, 位),
				})
	return 出

## 增援波次（`{回合, 来:[{键, 等级, 强化, 层, 词条}]}`）。
static func 增援波次(条目: Dictionary, 场次: int = 0) -> Array:
	var 层 := int(条目.get("层", 1))
	var 全部词条 := 编成词条(条目)
	var 出 := []
	for w in (条目.get("波次") if 条目.get("波次") is Array else []):
		if not (w is Dictionary):
			continue
		var 来 := []
		for 键 in (w.get("来") if w.get("来") is Array else []):
			var k := str(键)
			来.append({"键": k, "等级": 等级Of(条目, k, 场次), "强化": 强化Of(条目, k), "层": 层, "词条": 全部词条.duplicate(true)})
		出.append({"回合": w.get("回合"), "来": 来})
	return 出

# ======================== 我方参战编成 ========================
## 出击名单 → 我方编成（按 `05-阵型.js` 的默认职业排位摆位；名册里记的 `hpRatio` 带上）。
static func 我方编成(state: RunState) -> Array:
	var 名册键 := state.roster.keys()
	var 出击 := []
	for x in state.lineup:
		if x is Dictionary:
			出击.append(str(x.get("key")))
		elif x is String:
			出击.append(str(x))
	var 缺 := []
	for k in 名册键:
		if not 出击.has(k):
			缺.append(k)
	var 排位: Array = Db.T.get("默认五人队") if Db.T.get("默认五人队") is Array else []
	var 出 := []
	var 已用 := {}
	for k in 出击:
		if not state.roster.has(k) or 已用.has(k):
			continue
		已用[k] = true
		var 位 := _默认位(排位, k, 出.size())
		出.append({"键": k, "位": 位, "等级": float(RosterManager.整数(state.roster[k].get("lv"), 10)), "hp比": state.roster[k].get("hpRatio")})
	for k in 缺:
		if 出.size() >= RosterManager.deploy_limit(state):
			break
		已用[k] = true
		出.append({"键": k, "位": _默认位(排位, k, 出.size()), "等级": float(RosterManager.整数(state.roster[k].get("lv"), 10)), "hp比": state.roster[k].get("hpRatio")})
	return 出

static func _默认位(排位: Array, 键: String, 序: int) -> float:
	for e in 排位:
		if e is Dictionary and str(e.get("键")) == 键:
			return float(e.get("位", 序))
	return float(序 % int(Fm.SLOTS()))

# ======================== 开战 / 战后结算 ========================
## 开一场真战斗（`Setup.开局`），返回 ctx。
static func 开战(state: RunState, 条目: Dictionary, 覆盖类型: String = "") -> Dictionary:
	var 我方 := 我方编成(state)
	var 敌方 := 编成到规格(条目, state.battles_fought)
	var 选项 := RelicSystem.build_battle_options(state)
	选项["波次"] = 增援波次(条目, state.battles_fought)
	选项["侵蚀源强攻加成"] = 0.0
	var 种子 := state.seed_val + state.floor_num * 131 + state.battles_fought * 17 + state.node_id * 7
	return Setup.开局(我方, 敌方, 种子, null, 选项)

## 打一整场（打一回合直到出结果，带护栏）。
static func 打完一场(ctx: Dictionary) -> void:
	var 顶 := maxf(float(Db.T.get("MAX_TURN", 12.0)), float(ctx.get("回合上限", 12.0))) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		Setup.打一回合(ctx)
	if ctx.result == null:
		ctx.result = {"结果": "败", "原因": "超出回合上限"}
	Btl.pushLog(ctx, "战斗结束：%s（%s）" % [ctx.result.结果, ctx.result.原因], {"类型": "结束"})

## 敌方还活着几台（`失败耐久()`）。
static func 失败耐久(ctx: Dictionary) -> int:
	var 剩 := 0
	for u in (ctx.get("enemies") if ctx.get("enemies") is Array else []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			剩 += 1
	return maxi(1, 剩)

## 名册「倒下」台数（`hpRatio <= 0`；战后回血前才有意义）。
static func 倒下单位数(state: RunState) -> int:
	var n := 0
	for k in state.roster.keys():
		if RosterManager.数(state.roster[k].get("hpRatio"), 1.0) <= 0.0:
			n += 1
	return n

## 战后结算（唯一汇合点）。返回完整结果字典。
static func resolve_battle(state: RunState, ctx: Dictionary, 格类型: String = "") -> Dictionary:
	if state == null or ctx == null:
		return {}
	var 类型 := 格类型 if not 格类型.is_empty() else str(state.map_data.get("当前节点类型", "作战"))
	var 是胜: bool = str(ctx.result.get("结果")) == "胜"
	state.battles_fought += 1
	state.battles_won += 1 if 是胜 else 0
	var 带伤 := RosterManager.记战斗HP(state, {"我方": ctx.get("allies", [])})
	var 倒下 := 倒下单位数(state)          # ★ 战后回血**之前**的阵亡数（阵亡机体永不永久死亡）
	var 回血 := RosterManager.战后回血(state)
	if not 是胜:
		var 扣 := 失败耐久(ctx)
		state.base_hp -= 扣
		state.add_log("战斗失败：作战耐久 −%d（按剩下的敌人数算，剩 %d）" % [扣, state.base_hp])
		if state.base_hp <= 0:
			state.status = "失败"
			state.add_log("本局结束：作战耐久耗尽")
			return {"胜": false, "结束": true, "扣": 扣, "券": null, "带伤": 带伤, "回血": 回血, "倒下": 倒下}
		RosterManager.加经验(state, 经验Of(类型), "%s结算" % 类型)
		var 败券: Variant = RosterManager.掷战后券(state, 类型)
		if 败券 != null:
			state.add_log("战斗结束（败）：获得【%s】" % RosterManager.券名(败券))
		return {"胜": false, "扣": 扣, "券": 败券, "带伤": 带伤, "回血": 回血, "倒下": 倒下}

	RosterManager.加经验(state, 经验Of(类型), "%s结算" % 类型)
	var 奖 := 本场奖励档(state, 类型)
	var 希望加: int = Boss希望() if 奖 == "Boss" else (精英希望() if 奖 == "精英" else 胜利希望())
	var 源碳加: int = 胜利源碳()
	state.hope += 希望加
	state.carbon += 源碳加
	RosterManager.记希望来源(state, "战斗", 希望加)
	state.add_log("%s胜利：希望 +%d、源碳 +%d" % [类型, 希望加, 源碳加])
	var 战后券: Variant = RosterManager.掷战后券(state, 类型)
	if 战后券 != null:
		state.add_log("战斗结束：获得【%s】（战后那一档给到了，胜败都给）" % RosterManager.券名(战后券))
	var 藏品 := RelicSystem.战斗胜利发藏品(state, 奖, state.node_id)
	var 额外编制 := RelicSystem.编制类额外掉落(state, 类型, state.node_id)
	var 零件获: Variant = 发零件(state, 奖, "%s战利品" % 奖)
	var 拦路: Dictionary = {}
	if 类型 == "出口守军":
		var 关口 := 整数(Db.T.get("守军奖励", {}).get("额外源碳") if Db.T.get("守军奖励") is Dictionary else null, 4)
		state.carbon += 关口
		var 守军零件: Variant = 发零件(state, "精英", "出口守军战利品")
		清空格(state)
		state.add_log("出口守军已被击溃：出口放行；关口奖励 源碳 +%d" % 关口)
		拦路 = {"额外源碳": 关口, "守军零件": 守军零件, "守军已清": true}
	elif 类型 == "侵蚀源":
		var 侵蚀 := 整数(cfg().get("侵蚀源源碳"), 8)
		state.carbon += 侵蚀
		var 侵蚀藏品: Variant = RelicSystem.抽藏品(state, null, state.node_id)
		if 侵蚀藏品 != null:
			RelicSystem.拿藏品(state, str(侵蚀藏品), "侵蚀源")
		state.add_log("侵蚀源：额外奖励 源碳 +%d" % 侵蚀)
		拦路 = {"侵蚀源源碳": 侵蚀}
	state.nodes_cleared += 1
	return {"胜": true, "希望": 希望加, "源碳": 源碳加, "券": 战后券, "藏品": 藏品, "额外编制": 额外编制,
		"零件": 零件获, "带伤": 带伤, "回血": 回血, "倒下": 倒下, "奖励档": 奖, "额外": 拦路}

# ======================== 奖励参数 ========================
static func 胜利希望() -> int:
	return 整数(cfg().get("胜利希望"), 2)

static func 精英希望() -> int:
	return 整数(cfg().get("精英希望"), 3)

static func Boss希望() -> int:
	return 整数(cfg().get("Boss希望"), 5)

static func 胜利源碳() -> int:
	return 整数(cfg().get("胜利源碳"), 4)

static func 经验Of(格类型: String) -> int:
	var 表: Dictionary = cfg().get("战斗经验") if cfg().get("战斗经验") is Dictionary else {}
	return 整数(表.get(格类型))

static func 整数(v: Variant, 默认: int = 0) -> int:
	return RosterManager.整数(v, 默认)

# ======================== 零件（探测 PartSystem，探测不到走本地兜底） ========================
## 零件箱上限（★ 与另一条线的 `PartSystem` 分开：探测得到就用它的，探测不到用数据表初值）。
static func 零件箱上限() -> int:
	var 脚本: Variant = RosterManager.全局脚本("PartSystem")
	if 脚本 != null:
		return int(脚本.零件箱上限())
	return 整数(Db.T.get("零件箱初值"), 8)

## 抽一个零件键（同种子可复现）；抽不到 / 箱满 → 返回 `""`。
static func 抽零件(state: RunState, 格号: int) -> String:
	var 表: Dictionary = Db.catalog.parts()
	if 表.is_empty():
		return ""
	var 键们 := 表.keys()
	var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + 格号 * 37 + 7)
	return str(键们[mini(键们.size() - 1, int(floor(r.next_float() * float(键们.size()))))])

static func 发零件(state: RunState, 奖: String, 来源: String) -> Variant:
	var 必给: bool = 奖 == "精英" or 奖 == "Boss"
	var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + state.battles_fought * 37 + state.node_id * 17 + 909)
	var 概率 := 1.0 if 必给 else RosterManager.数(Db.T.get("战利品概率"), 0.35)
	if not (r.next_float() < 概率):
		return null
	if state.parts.size() >= 零件箱上限():
		state.add_log("%s：零件箱满了（%d 件），这一件没拿到" % [来源, 零件箱上限()])
		return null
	var 键 := 抽零件(state, state.node_id)
	if 键.is_empty():
		return null
	var 表 := Db.catalog.part(键)
	var 件 := {"id": 键, "uses": RosterManager.整数(表.get("次数"), 1), "value": null}
	state.parts.append(件)
	state.add_log("%s：获得零件【%s】" % [来源, str(表.get("名", 键))])
	return {"id": 键, "名": str(表.get("名", 键))}

# ======================== 非战斗节点 ========================
static func 清空格(state: RunState) -> void:
	state.map_data["当前节点类型"] = "空"
	state.map_data["当前格已过"] = true
	var 格: Variant = state.map_data.get("格")
	if 格 is Dictionary and 格.has(str(state.node_id)) and 格[str(state.node_id)] is Dictionary:
		格[str(state.node_id)]["已过"] = true
		格[str(state.node_id)]["类型"] = "空"

static func 格键(state: RunState) -> String:
	return "%d:%d" % [state.floor_num, state.node_id]

## 休整（互斥三选一：耐久 +2 / 下次晋升 −1 希望 / 推进剂 +2）；无论选哪一项都回血。
static func 结算休整(state: RunState, 选: String = "耐久") -> Dictionary:
	if state == null:
		return {}
	var c := cfg()
	var 上限 := state.propellant_max + 1
	var 回血 := 休整回血(state)
	if 选 == "晋升":
		特置(state, "下次晋升减价", true)
		state.add_log("休整：下次晋升 −1 希望")
		state.nodes_cleared += 1
		return {"ok": true, "选": "晋升", "减价": true, "回血": 回血}
	if 选 == "推进剂":
		var 加 := 整数(c.get("休整推进剂"), 2)
		state.propellant = mini(上限, state.propellant + 加)
		state.add_log("休整：把这一格让出来 → 推进剂 +%d（现在 %d/%d）" % [加, state.propellant, 上限])
		state.nodes_cleared += 1
		return {"ok": true, "选": 选, "推进剂": state.propellant, "回血": 回血}
	var 耐 := 整数(c.get("休整耐久"), 2)
	state.base_hp = mini(state.base_max_hp, state.base_hp + 耐)
	state.add_log("休整：坐下休息 → 作战耐久 +%d（现在 %d）" % [耐, state.base_hp])
	state.nodes_cleared += 1
	return {"ok": true, "选": "耐久", "耐久": state.base_hp, "回血": 回血}

static func 休整回血(state: RunState) -> Dictionary:
	var c: Dictionary = Db.T.get("战斗结构") if Db.T.get("战斗结构") is Dictionary else {}
	var hp: Dictionary = c.get("HP继承") if c.get("HP继承") is Dictionary else {}
	var 比例 := RosterManager.数(hp.get("休整回血比例"), 0.5)
	var 名字们 := []
	for 键 in state.roster.keys():
		var m: Dictionary = state.roster[键]
		var 前 := clampf(RosterManager.数(m.get("hpRatio"), 1.0), 0.0, 1.0)
		if 前 >= 1.0:
			continue
		m["hpRatio"] = minf(1.0, 前 + 比例)
		state.roster[键] = m
		名字们.append(键)
	if not 名字们.is_empty():
		state.add_log("休整：全队回血 %d%% 最大 HP（%s）" % [int(JsCompat.js_round(比例 * 100.0)), "、".join(名字们)])
	return {"台数": 名字们.size(), "回复比例": 比例}

## 补给（老接口）：源碳 +6。
static func 补给(state: RunState) -> int:
	var n := 整数(cfg().get("补给源碳"), 6)
	state.carbon += n
	state.add_log("补给：源碳 +%d" % n)
	state.nodes_cleared += 1
	return n

## 黑市货架（4 件；刷新次数多带一个种子项）。
static func 黑市货(state: RunState) -> Array:
	var 已有: Variant = state.map_data.get("黑市货")
	if 已有 is Dictionary and int(已有.get("层", -1)) == state.floor_num and int(已有.get("格", -1)) == state.node_id:
		return 已有.get("列表") if 已有.get("列表") is Array else []
	var 次 := 黑市刷新次数(state)
	var r := Mulberry32.new(state.seed_val + state.floor_num * 613 + state.node_id * 37 + 5 + 次 * 1013)
	var 池 := RelicSystem.候选(state.relics)
	var 列表 := []
	var 件数 := 整数(cfg().get("黑市货件数"), 4)
	while not 池.is_empty() and 列表.size() < 件数:
		列表.append(池.pop_at(mini(池.size() - 1, int(floor(r.next_float() * float(池.size()))))))
	state.map_data["黑市货"] = {"层": state.floor_num, "格": state.node_id, "列表": 列表, "刷新": 次}
	return 列表

static func 黑市刷新次数(state: RunState) -> int:
	return maxi(0, mini(99, RosterManager.整数(特取(state, "黑市刷新次数", 0))))

static func 黑市价(state: RunState, id: String) -> int:
	var r := RelicSystem.件(id)
	var 价格: Dictionary = Db.catalog.relic_prices()
	var 基 := 整数(价格.get(str(r.get("稀有"))))
	var 打折 := 0.7 if state.relics.has("f1") else 1.0
	return int(JsCompat.js_round(float(基) * 打折))

static func 黑市买(state: RunState, id: String) -> Dictionary:
	if RelicSystem.件(id).is_empty():
		return {"ok": false, "why": "没有这件藏品"}
	if state.relics.has(id):
		return {"ok": false, "why": "这件藏品已经在手上了"}
	var 价 := 黑市价(state, id)
	if state.carbon < 价:
		return {"ok": false, "why": "源碳不够（要 %d，只有 %d）" % [价, state.carbon]}
	state.carbon -= 价
	var 件 := RelicSystem.拿藏品(state, id, "黑市")
	var 货: Variant = state.map_data.get("黑市货")
	if 货 is Dictionary and 货.get("列表") is Array:
		(货["列表"] as Array).erase(id)
	state.add_log("黑市：花 %d 源碳买下【%s】" % [价, RelicSystem.名(id)])
	return {"ok": true, "id": id, "价": 价, "名": RelicSystem.名(id), "藏品": 件}

static func 黑市刷新价(state: RunState) -> Variant:
	var 次 := 黑市刷新次数(state)
	var 上限 := 整数(cfg().get("黑市刷新上限"), 4)
	if 次 >= 上限:
		return null
	return 整数(cfg().get("黑市刷新基价"), 4) + 次 * 整数(cfg().get("黑市刷新加价"), 4)

static func 黑市刷新(state: RunState) -> Dictionary:
	var 价: Variant = 黑市刷新价(state)
	if 价 == null:
		return {"ok": false, "why": "这一格已经刷新满了"}
	if state.carbon < int(价):
		return {"ok": false, "why": "源碳不够（刷新要 %d，只有 %d）" % [int(价), state.carbon]}
	state.carbon -= int(价)
	特置(state, "黑市刷新次数", 黑市刷新次数(state) + 1)
	state.map_data.erase("黑市货")
	var 货 := 黑市货(state)
	state.shop_refreshes += 1
	state.add_log("黑市：花 %d 源碳刷新库存（第 %d 次），摆出 %d 件" % [int(价), 黑市刷新次数(state), 货.size()])
	return {"ok": true, "价": int(价), "次": 黑市刷新次数(state), "货": 货, "下次价": 黑市刷新价(state)}

static func 黑市离开(state: RunState) -> bool:
	state.nodes_cleared += 1
	return true

## 瞭望站：远眺（4 格）/ 登高（12 格 + 1 推进剂）。
static func 结算瞭望站(state: RunState, 选: String = "登高") -> Dictionary:
	var 登高 := 选 != "远眺"
	var 半径 := 整数(cfg().get("瞭望站登高"), 12) if 登高 else 整数(cfg().get("瞭望站远眺"), 4)
	var 加推进剂 := 整数(cfg().get("瞭望站推进剂"), 1) if 登高 else 0
	var 上限 := state.propellant_max + 1
	if 加推进剂 > 0:
		state.propellant = mini(上限, state.propellant + 加推进剂)
	var 揭开 := 0
	var 已揭: Array = state.map_data.get("已揭开") if state.map_data.get("已揭开") is Array else []
	var 格: Dictionary = state.map_data.get("格") if state.map_data.get("格") is Dictionary else {}
	var 列数: int = maxi(1, 整数(state.map_data.get("列数"), 5))
	var 我列: int = state.node_id % 列数
	var 我行: int = int(floor(float(state.node_id) / float(列数)))
	for k in 格.keys():
		# ★ `格` 的键可能是 int（`MapGenerator` 原样生成）也可能是 String（存档 / 归一后）：
		#   一律走 `str()` —— `String(int)` 在 GDScript 4 会报「Nonexistent 'String' constructor」。
		var kk: int = int(k) if k is int else int(str(k))
		if absi(kk % 列数 - 我列) + absi(int(floor(float(kk) / float(列数))) - 我行) <= 半径:
			if not 已揭.has(str(kk)):
				已揭.append(str(kk))
				揭开 += 1
	state.map_data["已揭开"] = 已揭
	var 希望 := 整数(cfg().get("瞭望站希望"))
	if 希望 > 0:
		state.hope += 希望
		RosterManager.记希望来源(state, "节点", 希望)
	state.add_log("瞭望站%s：揭开周围 %d 格（本次新揭开 %d 格）" % ["（登高）" if 登高 else "（只远眺）", 半径, 揭开])
	state.nodes_cleared += 1
	return {"推进剂": state.propellant, "揭开": 揭开, "半径": 半径, "希望": 希望, "选": "登高" if 登高 else "远眺"}

## 废弃隧道：花 1 推进剂传到另一头。
static func 结算隧道(state: RunState) -> Dictionary:
	var 隧道: Array = state.map_data.get("隧道") if state.map_data.get("隧道") is Array else []
	var 那头 := -1
	for k in 隧道:
		if int(k) != state.node_id:
			那头 = int(k)
			break
	if 那头 < 0:
		state.add_log("废弃隧道：另一头已经塌了（这一格没有配对隧道）")
		state.nodes_cleared += 1
		return {"ok": false, "传送": false, "why": "这一格没有配对隧道"}
	var 花 := 整数(cfg().get("隧道花费"), 1)
	if state.propellant < 花:
		return {"ok": false, "传送": false, "why": "推进剂不够：进隧道要花 %d 点（现在 %d）" % [花, state.propellant]}
	state.propellant -= 花
	state.node_id = 那头
	state.nodes_cleared += 1
	state.add_log("废弃隧道：花 %d 推进剂（剩 %d），传送过去" % [花, state.propellant])
	return {"ok": true, "传送": true, "到": 那头, "花费": 花, "推进剂": state.propellant}

## 遗迹：三选一（清理藤蔓 −2 耐久 / 交流 −8 源碳 / 离开），成功后源碳 +3 + 一件零件。
static func 结算遗迹(state: RunState, 选: String = "藤蔓") -> Dictionary:
	var 走 := 选
	if 走 != "离开" and 走 != "交流":
		走 = "藤蔓"
	if 走 == "离开":
		state.add_log("遗迹：看了看就走了 —— 什么也没拿到")
		state.nodes_cleared += 1
		return {"ok": true, "选": "离开", "源碳": 0, "零件": null}
	var 耐久价 := 整数(cfg().get("遗迹耐久价"), 2)
	var 源碳价 := 整数(cfg().get("遗迹源碳价"), 8)
	if 走 == "藤蔓" and state.base_hp < 耐久价:
		return {"ok": false, "why": "作战耐久不够（清理藤蔓要 %d，只有 %d）" % [耐久价, state.base_hp]}
	if 走 == "交流" and state.carbon < 源碳价:
		return {"ok": false, "why": "源碳不够（交流要 %d，只有 %d）" % [源碳价, state.carbon]}
	if 走 == "藤蔓":
		state.base_hp -= 耐久价
	else:
		state.carbon -= 源碳价
	var 得 := 整数(cfg().get("遗迹源碳"), 3)
	state.carbon += 得
	var 零件: Variant = 发零件(state, "精英", "遗迹")
	state.add_log("遗迹（%s）：源碳 +%d%s" % ["清理门口的藤蔓" if 走 == "藤蔓" else "试着和它交流", 得,
		"，零件【%s】" % str(零件.get("名")) if 零件 != null else "（零件箱满了）"])
	state.nodes_cleared += 1
	return {"ok": true, "选": 走, "源碳": 得, "零件": 零件, "耐久": state.base_hp}

## 侵蚀源代价：硬闯（本场敌方 +15%）/ 净化（花 8 源碳）。
static func 结算侵蚀源代价(state: RunState, 选: String) -> Dictionary:
	if 选 != "硬闯" and 选 != "净化":
		return {"ok": false, "why": "侵蚀源只有「硬闯」与「花源碳净化」两条路"}
	var 已: Dictionary = state.map_data.get("侵蚀源已净化") if state.map_data.get("侵蚀源已净化") is Dictionary else {}
	var 键 := 格键(state)
	if 选 == "净化":
		if 已.get(键) == "净化":
			return {"ok": true, "选": "净化", "敌方加成": 0.0, "花源碳": 0, "重复": true}
		var 价 := 整数(cfg().get("侵蚀源净化价"), 8)
		if state.carbon < 价:
			return {"ok": false, "why": "源碳不够（净化要 %d，只有 %d）" % [价, state.carbon]}
		state.carbon -= 价
		已[键] = "净化"
		state.map_data["侵蚀源已净化"] = 已
		state.add_log("侵蚀源：花 %d 源碳买净化（剩 %d），这一场正常打" % [价, state.carbon])
		return {"ok": true, "选": "净化", "敌方加成": 0.0, "花源碳": 价}
	已[键] = "硬闯"
	state.map_data["侵蚀源已净化"] = 已
	var 加成 := RosterManager.数(cfg().get("侵蚀源强攻加成"), 0.15)
	state.add_log("侵蚀源：硬闯 —— 这一场敌方全体攻防 +%d%%" % int(JsCompat.js_round(加成 * 100.0)))
	return {"ok": true, "选": "硬闯", "敌方加成": 加成, "花源碳": 0}

## 奇遇：按事件表结算（同一格只结算一次）。
static func 结算奇遇(state: RunState, 选: String = "") -> Dictionary:
	var 键 := 格键(state)
	var 已: Dictionary = state.map_data.get("事件已选") if state.map_data.get("事件已选") is Dictionary else {}
	if 已.has(键):
		state.nodes_cleared += 1
		return {"ok": true, "重复": true, "选": str(已[键])}
	var 事 := 当前事件(state)
	if 事.is_empty():
		return {"ok": false, "why": "没有事件可看"}
	var 序 := 0
	if not 选.is_empty():
		序 = clampi(int(选.to_int()), 0, maxi(0, (事.get("选") as Array).size() - 1)) if 选.is_valid_int() else 0
	var 选项们: Array = 事.get("选") if 事.get("选") is Array else []
	if 选项们.is_empty():
		return {"ok": false, "why": "这个事件没有选项"}
	var 选项: Dictionary = 选项们[序]
	var 文 := str(选项.get("文"))
	var 结果 := ""
	match str(事.get("名")):
		"漂流的补给舱":
			if 序 == 1:
				RosterManager.加经验(state, 5, "补给舱")
				结果 = "经验 +5"
			else:
				state.propellant += 3
				结果 = "推进剂 +3"
		"平行宇宙的回声":
			if 序 == 0:
				state.base_hp -= 1
				var p: Variant = 发零件(state, "精英", "回声")
				结果 = "作战耐久 −1%s" % ("，零件【%s】" % str(p.get("名")) if p != null else "（零件箱满了）")
			else:
				结果 = "离开"
		"迷路的机师":
			if 序 == 0:
				var 价 := 整数(cfg().get("机师换券源碳"), 4)
				if state.carbon < 价:
					return {"ok": false, "why": "源碳结晶不够：要 %d 个，手上只有 %d 个" % [价, state.carbon]}
				var 券: Variant = RosterManager.发随机券(state, "事件", 整数(RosterManager.券偏移["事件"]))
				if 券 == null:
					return {"ok": false, "why": "券池空 / 到券上限"}
				state.carbon -= 价
				结果 = "花 %d 源碳结晶，收下%s" % [价, RosterManager.券文字(券)]
			else:
				结果 = "离开"
		"扭曲的时钟":
			if 序 == 0:
				state.propellant = maxi(0, state.propellant - 2)
				RosterManager.加经验(state, 10, "扭曲的时钟")
				结果 = "推进剂 −2、经验 +10"
			else:
				结果 = "离开"
		"黑箱":
			if 序 == 0:
				if state.carbon < 3:
					return {"ok": false, "why": "做不成：花 3 源碳结晶打开（钱不够）"}
				state.carbon -= 3
				var r := Mulberry32.new(state.seed_val + state.floor_num * 811 + state.node_id * 23 + 17)
				if r.next_float() < 0.5:
					RosterManager.加经验(state, 6, "黑箱")
					结果 = "花 3 源碳：经验 +6"
				else:
					var 池 := ["wheel", "limb", "spring", "engine", "exo"]
					var k := str(池[mini(池.size() - 1, int(floor(r.next_float() * float(池.size()))))])
					var 表 := Db.catalog.part(k)
					state.parts.append({"id": k, "uses": 整数(表.get("次数"), 1), "value": null})
					结果 = "花 3 源碳：零件【%s】" % str(表.get("名", k))
			else:
				结果 = "不碰它"
		"沉重的契约":
			if 序 == 0:
				state.propellant += 2
				结果 = "推进剂 +2"
			elif 序 == 1:
				var 半 := maxi(1, state.base_hp / 2)
				state.base_hp = maxi(0, state.base_hp - 半)
				state.propellant += 5
				结果 = "作战耐久 −%d（一半）、推进剂 +5" % 半
			else:
				结果 = "离开"
		"桑尼的邀请":
			if 序 == 0:
				state.hope += 3
				RosterManager.记希望来源(state, "节点", 3)
				结果 = "希望 +3"
			else:
				state.carbon += 10
				结果 = "源碳结晶 +10"
		_:
			结果 = 文
	已[键] = "%s：%s" % [str(事.get("名")), 文]
	state.map_data["事件已选"] = 已
	state.add_log("事件「%s」：%s → %s" % [str(事.get("名")), 文, 结果])
	state.nodes_cleared += 1
	return {"ok": true, "事件": str(事.get("名")), "选": 文, "结果": 结果}

## 这一格遇到哪个事件（同一局同一格可复现）。**事件表没导出** → 走内置的 7 条。
static func 当前事件(state: RunState) -> Dictionary:
	var 表: Array = Db.catalog.events()
	if 表.is_empty():
		表 = 内置事件表()
	var r := Mulberry32.new(state.seed_val + state.floor_num * 811 + state.node_id * 23)
	if 表.is_empty():
		return {}
	return 表[mini(表.size() - 1, int(floor(r.next_float() * float(表.size()))))]

static func 内置事件表() -> Array:
	return [
		{"名": "漂流的补给舱", "选": [{"文": "推进剂 +3"}, {"文": "经验 +5"}]},
		{"名": "平行宇宙的回声", "选": [{"文": "作战耐久 −1，获得随机零件"}, {"文": "离开"}]},
		{"名": "迷路的机师", "选": [{"文": "花 4 源碳结晶 → 一张随机招募券"}, {"文": "离开"}]},
		{"名": "扭曲的时钟", "选": [{"文": "推进剂 −2，经验 +10"}, {"文": "离开"}]},
		{"名": "黑箱", "选": [{"文": "花 3 源碳结晶打开"}, {"文": "不碰它"}]},
		{"名": "沉重的契约", "选": [{"文": "上去帮个小忙（推进剂 +2）"}, {"文": "推翻石磨（推进剂 +5）"}, {"文": "离开"}]},
		{"名": "桑尼的邀请", "选": [{"文": "收下 3 希望"}, {"文": "收下 10 源碳结晶"}]},
	]

# ======================== 额外态小工具 ========================
static func 特记(state: RunState) -> Dictionary:
	return RosterManager.特记(state)

static func 特取(state: RunState, 键: String, 默认: Variant) -> Variant:
	return RosterManager.特取值(state, 键, 默认)

static func 特置(state: RunState, 键: String, 值: Variant) -> void:
	RosterManager.特置(state, 键, 值)
