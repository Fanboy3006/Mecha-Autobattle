## DECK-4：ATX 势力卡牌设计 v0.2 的卡表（25 张）+ 装填 + 专属效果执行器。
##
## 规格（唯一真源）：`协作/设计/ATX势力卡牌设计 v0.2.md`
##   · 角色牌每人 3 张：A1 响介 / A2 艾克赛琳 / A3 拉米亚 / A4 布鲁克林 / A5 库斯哈 = 15 张；
##   · 合体技 1 张：`U_ATX_COMBO`【轮盘双响】（占行动 = A1 + A2）；
##   · 势力牌 9 张：`F_ATX_V2_1`..`F_ATX_V2_9`（加注 / 梭哈 / 必闪 / 读牌 / 翻倍 / 止损 /
##     二次下注 / 庄家通吃 / 幸运连号）。
##
## ★ 与 `mithril_v02_cards.gd` 同一套牌面字段口径（多出来的只有 ATX 自己的）：
##   id / 名 / 类型（大招|战术）/ 层级（角色|势力）/ 种类（角色|合体技|势力）
##   归属 = "ATX" / 角色 / 角色们 / 占行动 / 合体技
##   耗气 / 冷却 / 限次 / 回库 / 衍生 / 入牌（初始|条件）
##   触发条件（声明式）/ 触发说明 / 效果（声明式算子 `{"算子": "atx", …}`）/ 效果说明
##   **卡类** = 主武器卡 | 专属精神牌 | 公有牌（DECK-4 双排分流口径，见下）
##
## 卡类口径（`_收尾()` 逐张落字段，测试逐张断言）：
##   · `种类 == 势力`                       → `卡类: "公有牌"`（进 `ctx.公有牌库`）
##   · `种类 == 合体技` / `占行动` 非空      → `卡类: "主武器卡"`（进参战机体的 `专属牌库`）
##   · `占行动` 为空（纯增益 / 回战意 / 战术）→ `卡类: "专属精神牌"`（进 `专属牌库`）
##   · 衍生牌（`衍生 == true`）             → `卡类: "衍生攻击卡"`
##
## 开关：本模块由 `单机牌组` 与 `Params.ATXv02开(ctx)` 共同把关 ——
##   两个都开着时 `Setup.初始化单机牌组` 才把 ATX 牌分进上排（专属牌库）/ 下排（公有牌库）。
##   关着 = 本模块一行都不执行（既有 168 场黄金样例与全部旧测试逐字不变）。
class_name FacAtx
extends RefCounted

const 势力 := "ATX"
const 成员键: Array = ["A1", "A2", "A3", "A4", "A5"]
const 合体技成员: Array = ["A1", "A2"]
const 合体技ID := "U_ATX_COMBO"
## 「赌神」段数上限（v0.2：上次打出这张牌以来的打空段数，上限 12）
const 赌神段数上限 := 12
## 「梭哈」清零后冷却最小为 1、每场只能用 1 次
const 梭哈冷却最小 := 1

static var _表: Array = []

# ==========================================================================
# 一、25 张牌的数据定义
# ==========================================================================
static func 卡表() -> Array:
	if _表.is_empty():
		_表 = _构建()
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return c.duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return c.duplicate(true)
	return {}

static func 有(id: Variant) -> bool:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return true
	return false

static func 是v02牌(card: Variant) -> bool:
	return card is Dictionary and 有(card.get("id"))

static func 角色牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "角色")

static func 势力牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "势力")

static func 合体技卡() -> Dictionary:
	return 卡(合体技ID)

## 卡类三分类（DECK-4 双排分流的唯一口径）
static func 卡类(card: Variant) -> String:
	if not (card is Dictionary):
		return ""
	return str(card.get("卡类", ""))

static func 是主武器卡(card: Variant) -> bool:
	return 卡类(card) == "主武器卡"

static func 是专属精神牌(card: Variant) -> bool:
	return 卡类(card) == "专属精神牌"

static func 是衍生攻击卡(card: Variant) -> bool:
	return 卡类(card) == "衍生攻击卡"

static func 是公有牌(card: Variant) -> bool:
	return 卡类(card) == "公有牌"

## 这台机体的**专属牌**（角色牌 + 以它为参与者的合体技）—— 上排「专属牌库」的候选。
static func 角色专属牌们(键: Variant) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 卡表():
		if str(c.get("角色", "")) == k or J.inc(J.or_(c.get("角色们"), []), k):
			出.append(c.duplicate(true))
	return 出

## 全队**公有牌**（9 张势力牌）—— 下排「公有牌库」的候选。
static func 公有牌们() -> Array:
	return 势力牌们()

# ---------------- 小工具：牌面拼装 ----------------
static func _底(id: String, 名: String, 耗气: float, 冷却: float) -> Dictionary:
	return {
		"id": id, "名": 名, "归属": 势力, "耗气": 耗气, "回气": 0.0, "限次": 1.0, "冷却": 冷却,
		"回库": true, "衍生": false, "入牌": "初始",
		"触发条件": {"类型": "开局在手"}, "触发说明": "开局在手",
		"效果": [], "效果说明": "",
	}

static func _并入(d: Dictionary, 额外: Variant) -> void:
	if 额外 is Dictionary:
		for k in 额外.keys():
			d[k] = 额外[k]

## 角色牌：绑 1 个角色，默认占该角色的行动（战术牌用 `占行动: []` 覆盖）
static func _角色牌(id: String, 名: String, 类: String, 角色: String, 耗气: float, 冷却: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, 耗气, 冷却)
	d["类型"] = 类
	d["层级"] = "角色"
	d["种类"] = "角色"
	d["角色"] = 角色
	d["角色所属势力"] = 势力
	d["占行动"] = [角色]
	d["合体技"] = false
	_并入(d, 额外)
	_收尾(d)
	return d

## 势力牌：无绑定角色、不占行动、进全队公有牌库
static func _势力牌(id: String, 名: String, 耗气: float, 冷却: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, 耗气, 冷却)
	d["类型"] = "战术"
	d["层级"] = "势力"
	d["种类"] = "势力"
	d["占行动"] = []
	d["合体技"] = false
	_并入(d, 额外)
	_收尾(d)
	return d

## 收尾：`入牌` / `卡类`（三分类在这里逐张落到字段上，测试逐张断言）
static func _收尾(d: Dictionary) -> void:
	var 条件 = d.get("触发条件")
	var 类型 := str(条件.get("类型", "")) if 条件 is Dictionary else ""
	d["入牌"] = "初始" if 类型 == "开局在手" else "条件"
	if str(d.get("触发说明", "")) == "":
		d["触发说明"] = 类型
	if str(d.get("卡类", "")) != "":
		return
	var 种 := str(d.get("种类", ""))
	if 种 == "势力":
		d["卡类"] = "公有牌"
	elif 种 == "合体技" or J.truthy(d.get("衍生")):
		d["卡类"] = "衍生攻击卡" if J.truthy(d.get("衍生")) else "主武器卡"
	elif not J.or_(d.get("占行动"), []).is_empty():
		d["卡类"] = "主武器卡"
	else:
		d["卡类"] = "专属精神牌"

static func _开局在手() -> Dictionary:
	return {"类型": "开局在手"}

static func _第N回合(阈: int) -> Dictionary:
	return {"类型": "第N回合起", "阈值": 阈, "说明": "第 %d 回合起" % 阈}

static func _打空(阈: int, 说明: String = "") -> Dictionary:
	return {"类型": "打空", "阈值": 阈, "说明": 说明 if 说明 != "" else "本场打空 ≥ %d 段" % 阈}

static func _条件(说明: String) -> Dictionary:
	return {"类型": "条件", "说明": 说明}

# ---------------- 构建 ----------------
static func _构建() -> Array:
	var 表: Array = []
	# ======== A1 响介（近卫）========
	表.append(_角色牌("U_ATX_1", "左轮打桩机·全弹", "大招", "A1", 20.0, 3.0, {
		"触发条件": _开局在手(), "卡类": "主武器卡",
		"效果说明": "近战单体 12 段；攻击结束后，本次打空的段各再判定一次，命中则必暴击",
		"效果": [{"全局": [{"算子": "atx", "动作": "攻击", "名": "左轮打桩机·全弹", "目标": "自动",
			"威力": 620.0, "命中": 95.0, "段数": 12, "近战": true, "打空重判必暴": true}]}],
	}))
	表.append(_角色牌("U_ATX_2", "赌神", "大招", "A1", 30.0, 5.0, {
		"触发条件": _打空(8, "本场打空 ≥ 8 段"), "卡类": "主武器卡",
		"效果说明": "单体攻击；段数 = 上次打出这张牌以来的打空段数（上限 12），每段必暴击、命中 −20",
		"效果": [{"全局": [{"算子": "atx", "动作": "赌神", "名": "赌神", "目标": "自动",
			"威力": 720.0, "命中": -20.0}]}],
	}))
	表.append(_角色牌("U_ATX_3", "孤注一掷", "战术", "A1", 5.0, 2.0, {
		"触发条件": _打空(2, "响介受击或打空 ≥ 2"), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "本回合响介闪避 +30；每闪开一次攻击，气势 +3（最多 +9）",
		"效果": [{"全局": [{"算子": "atx", "动作": "闪避增益", "角色": "A1",
			"增益": {"eva": 30.0, "剩余": 1.0}, "每闪气势": 3, "气势上限": 9}]}],
	}))
	# ======== A2 艾克赛琳（狙击）========
	表.append(_角色牌("U_ATX_4", "全开·嚎叫发射器", "大招", "A2", 20.0, 3.0, {
		"触发条件": _第N回合(2), "卡类": "主武器卡",
		"效果说明": "对敌方一排多段射击；本回合她的暴击倍率 +0.5",
		"效果": [
			{"全局": [{"算子": "atx", "动作": "攻击", "名": "全开·嚎叫发射器", "目标": "一排",
				"威力": 880.0, "命中": 100.0, "段数": 3}]},
			{"全局": [{"算子": "atx", "动作": "自身增益", "角色": "A2",
				"增益": {"critX": 0.5, "剩余": 1.0}}]},
		],
	}))
	表.append(_角色牌("U_ATX_5", "好运加护", "战术", "A2", 10.0, 3.0, {
		"触发条件": _开局在手(), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "2 回合内：我方全体命中 −20、暴击倍率 +1（会大量制造打空；全场光环，每回合限 1 次）",
		"效果": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "我方全体",
			"增益": {"hit": -20.0, "critX": 1.0, "剩余": 2.0}}]}],
	}))
	表.append(_角色牌("U_ATX_6", "眨眼", "战术", "A2", 0.0, 2.0, {
		"触发条件": _打空(3, "本场打空 ≥ 3 段"), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "本回合每打空一段，气势 +2（最多 +10）。回气势牌",
		"效果": [{"全局": [{"算子": "atx", "动作": "打空回气势", "角色": "A2",
			"每段": 2, "上限": 10}]}],
	}))
	# ======== A3 拉米亚（尖兵）========
	表.append(_角色牌("U_ATX_7", "幻影凤凰", "大招", "A3", 25.0, 4.0, {
		"触发条件": _条件("拉米亚本场闪避 ≥ 2 次"), "卡类": "主武器卡",
		"效果说明": "高威力单体；目标本回合已经被打空过的话，伤害 ×1.3",
		"效果": [{"全局": [{"算子": "atx", "动作": "攻击", "名": "幻影凤凰", "目标": "自动",
			"威力": 2600.0, "命中": 100.0, "被打空过增伤": 1.3}]}],
	}))
	表.append(_角色牌("U_ATX_8", "烟雾弹", "战术", "A3", 10.0, 3.0, {
		"触发条件": _开局在手(), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "2 回合内：敌方前排命中 −30（全场光环，每回合限 1 次）",
		"效果": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "敌方前排",
			"增益": {"hit": -30.0, "剩余": 2.0}}]}],
	}))
	表.append(_角色牌("U_ATX_9", "W17·中继", "战术", "A3", 20.0, 4.0, {
		"触发条件": _第N回合(3), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "拉米亚本回合行动后，速度最高的另一名 ATX 成员立即再动一次（主武器卡回手）。每回合只能触发 1 次；被它再动的机体不会再触发它",
		"效果": [{"全局": [{"算子": "atx", "动作": "再动", "角色": "A3"}]}],
	}))
	# ======== A4 布鲁克林（重装）========
	表.append(_角色牌("U_ATX_10", "计都罗睺剑·一刀两断", "大招", "A4", 25.0, 4.0, {
		"触发条件": _条件("布鲁克林 HP ≤ 60% 或 受击 ≥ 3"), "卡类": "主武器卡",
		"效果说明": "单体斩击；伤害随已损失 HP 提高：每损失 10% 伤害 +8%，最多 +40%",
		"效果": [{"全局": [{"算子": "atx", "动作": "攻击", "名": "计都罗睺剑·一刀两断", "目标": "自动",
			"威力": 2400.0, "命中": 100.0, "近战": true, "损失HP增伤": 0.4}]}],
	}))
	表.append(_角色牌("U_ATX_11", "守护", "战术", "A4", 10.0, 2.0, {
		"触发条件": _开局在手(), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "本回合替对位队友承受攻击；每被打空一段，气势 +2",
		"效果": [{"全局": [{"算子": "atx", "动作": "守护", "角色": "A4",
			"增益": {"def": 20.0, "剩余": 1.0}}]}],
	}))
	表.append(_角色牌("U_ATX_12", "硬碰硬", "战术", "A4", 5.0, 2.0, {
		"触发条件": _条件("布鲁克林受击 ≥ 2 次"), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "本回合闪避归零、受到伤害 −30%；每受击一次，自己的大招牌冷却 −1",
		"效果": [{"全局": [{"算子": "atx", "动作": "硬碰硬", "角色": "A4"}]}],
	}))
	# ======== A5 库斯哈（指挥）========
	表.append(_角色牌("U_ATX_13", "龙王破山剑", "大招", "A5", 25.0, 4.0, {
		"触发条件": _第N回合(3), "卡类": "主武器卡",
		"效果说明": "高威力单体近战；命中后，全队下回合命中 +10",
		"效果": [
			{"全局": [{"算子": "atx", "动作": "攻击", "名": "龙王破山剑", "目标": "自动",
				"威力": 2800.0, "命中": 105.0, "近战": true, "命中后全队命中": 10}]},
		],
	}))
	表.append(_角色牌("U_ATX_14", "龙雷闪", "大招", "A5", 15.0, 3.0, {
		"触发条件": _打空(5, "本场打空 ≥ 5 段"), "卡类": "主武器卡",
		"效果说明": "敌方全体低威力；被命中的敌人下回合命中 −10",
		"效果": [{"全局": [{"算子": "atx", "动作": "攻击", "名": "龙雷闪", "目标": "全体",
			"威力": 1300.0, "命中": 100.0, "被命中敌命中惩罚": -10.0}]}],
	}))
	表.append(_角色牌("U_ATX_15", "念动迷彩·治愈", "战术", "A5", 10.0, 3.0, {
		"触发条件": _开局在手(), "占行动": [], "卡类": "专属精神牌",
		"效果说明": "回复 HP 最低的队友 25%；2 回合内敌方打 ATX 命中 −10",
		"效果": [
			{"全局": [{"算子": "atx", "动作": "治疗", "比": 0.25}]},
			{"全局": [{"算子": "atx", "动作": "光环", "范围": "敌方全体",
				"增益": {"hit": -10.0, "剩余": 2.0}}]},
		],
	}))
	# ======== 合体技（1 张）：响介 × 艾克赛琳 ========
	表.append({
		"id": 合体技ID, "名": "轮盘双响", "类型": "大招", "层级": "角色", "种类": "合体技",
		"归属": 势力, "角色所属势力": 势力, "合体技": true, "角色": "",
		"角色们": 合体技成员.duplicate(), "占行动": 合体技成员.duplicate(),
		"耗气": 35.0, "回气": 0.0, "限次": 1.0, "冷却": 5.0,
		"回库": true, "衍生": false, "卡类": "主武器卡", "入牌": "条件",
		"触发条件": {"类型": "ATX双大招", "说明": "本场响介和艾克赛琳的大招牌各打出过 1 次"},
		"触发说明": "本场响介和艾克赛琳的大招牌各打出过 1 次后进入牌库",
		"效果说明": "艾克赛琳先射（4 段），响介再冲锋打桩（6 段）；任一段打空，艾克赛琳立即补射一段（最多 6 段，补射必暴击）",
		"效果": [{"全局": [{"算子": "atx", "动作": "轮盘双响", "先射段数": 4, "先射威力": 820.0,
			"冲锋段数": 6, "冲锋威力": 760.0, "补射上限": 6, "补射威力": 900.0}]}],
	})
	# ======== 势力牌（9 张，全队共用一套）========
	表.append(_势力牌("F_ATX_V2_1", "加注", 5.0, 2.0, {
		"触发条件": _开局在手(),
		"效果说明": "本回合敌我全体命中 −20（全场光环，每回合限 1 次）",
		"效果": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "敌我全体",
			"增益": {"hit": -20.0, "剩余": 1.0}}]}],
	}))
	表.append(_势力牌("F_ATX_V2_2", "梭哈", 0.0, 6.0, {
		"触发条件": _打空(10, "本场打空 ≥ 10 段"),
		"效果说明": "所有冷却中的 ATX 角色牌冷却清零（清零后最小冷却为 1；每场只能用 1 次）；本回合 ATX 命中 −20",
		"效果": [
			{"全局": [{"算子": "atx", "动作": "冷却清零", "最小冷却": 梭哈冷却最小}]},
			{"全局": [{"算子": "atx", "动作": "光环", "范围": "ATX",
				"增益": {"hit": -20.0, "剩余": 1.0}}]},
		],
	}))
	表.append(_势力牌("F_ATX_V2_3", "必闪", 10.0, 2.0, {
		"触发条件": _开局在手(),
		"效果说明": "本回合 ATX 全体闪避 +25；ATX 伤害 −20%",
		"效果": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "ATX",
			"增益": {"eva": 25.0, "dmgMul": -0.20, "剩余": 1.0}}]}],
	}))
	表.append(_势力牌("F_ATX_V2_4", "读牌", 10.0, 3.0, {
		"触发条件": _第N回合(2),
		"效果说明": "本回合意图攻击 ATX 的敌人命中 −30（用 `Btl.算意图` 读敌方意图；意图一变就落空）",
		"效果": [{"全局": [{"算子": "atx", "动作": "读牌"}]}],
	}))
	表.append(_势力牌("F_ATX_V2_5", "翻倍", 10.0, 2.0, {
		"触发条件": _条件("ATX 本场暴击 ≥ 2 次"),
		"效果说明": "本回合 ATX 暴击倍率 +0.5；ATX 命中 −15",
		"效果": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "ATX",
			"增益": {"critX": 0.5, "hit": -15.0, "剩余": 1.0}}]}],
	}))
	表.append(_势力牌("F_ATX_V2_6", "止损", 0.0, 3.0, {
		"触发条件": _打空(4, "本场打空 ≥ 4 段"),
		"效果说明": "气势 + 上回合打空段数（最多 +15）",
		"效果": [{"全局": [{"算子": "atx", "动作": "止损", "上限": 15}]}],
	}))
	表.append(_势力牌("F_ATX_V2_7", "二次下注", 15.0, 3.0, {
		"触发条件": _打空(6, "本场打空 ≥ 6 段"),
		"效果说明": "本回合 ATX 第一次出现打空的攻击结束后，重打它打空的段（只生效一次）",
		"效果": [{"全局": [{"算子": "atx", "动作": "标记", "键": "ATX二次下注"}]}],
	}))
	表.append(_势力牌("F_ATX_V2_8", "庄家通吃", 15.0, 4.0, {
		"触发条件": _条件("ATX 本场闪避 ≥ 3 次"),
		"效果说明": "本回合敌方每打空 ATX 成员一次，该成员立即用普通武器反击一次",
		"效果": [{"全局": [{"算子": "atx", "动作": "标记", "键": "ATX庄家通吃"}]}],
	}))
	表.append(_势力牌("F_ATX_V2_9", "幸运连号", 0.0, 3.0, {
		"触发条件": _条件("打出过 ATX 大招牌"),
		"效果说明": "下一张 ATX 角色牌费用 −10；如果它本回合打空 ≥ 3 段，打出后冷却再 −2",
		"效果": [{"全局": [{"算子": "atx", "动作": "降费", "值": 10}]}],
	}))
	return 表

# ==========================================================================
# 二、装填 / 分流（`Setup.初始化单机牌组` 在 ATX v0.2 开着时调用）
# ==========================================================================
## 在场 ATX 成员的角色牌（每人 3 张）+ 合体技（A1/A2 都在场）+ 9 张势力牌
static func 装填(ctx: Variant, 在场角色键们: Variant) -> Array:
	var 出: Array = []
	var 成员 := J.filter(在场角色键们, func(k): return J.inc(成员键, k))
	if 成员.is_empty():
		return 出
	for k in 成员键:
		if not J.inc(成员, k):
			continue
		for c in 卡表():
			if str(c.get("种类", "")) == "角色" and str(c.get("角色", "")) == k:
				出.append(Btl.克隆战术牌(c, ctx))
	if 合体技在场(成员):
		出.append(Btl.克隆战术牌(合体技卡(), ctx))
	for c in 卡表():
		if str(c.get("种类", "")) == "势力":
			出.append(Btl.克隆战术牌(c, ctx))
	return 出

static func 合体技在场(在场角色键们: Variant) -> bool:
	return J.every(合体技成员, func(k): return J.inc(在场角色键们, k))

## 这张牌绑定的**全部**角色（占行动 / 角色们 / 角色）
static func 涉及角色键(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	for k in J.or_(card.get("角色们"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	var 单 := str(card.get("角色", ""))
	if 单 != "" and not J.inc(出, 单):
		出.append(单)
	return 出

## 打出时占用谁的回合行动：`占行动` 优先；没写但 `类型 == 大招` 且绑了角色 → 就占那个角色。
static func 占行动键(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	if 出.is_empty() and str(card.get("类型", "")) == "大招" and str(card.get("角色", "")) != "":
		出.append(str(card.get("角色")))
	return 出

## 这张牌是不是【合体技】（合体技标记 / 种类 / 占行动 ≥ 2 三种认法）
static func 是合体技(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	return J.truthy(card.get("合体技")) or str(card.get("种类", "")) == "合体技" \
		or J.or_(card.get("占行动"), []).size() >= 2

# ==========================================================================
# 三、效果执行器（`CardEffects` 的 `{"算子": "atx", …}` 分发进来）
# ==========================================================================
static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx = 运行.get("ctx")
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	if not (ctx is Dictionary):
		return []
	match 动作:
		"攻击": return _攻击(ctx, card, 表)
		"赌神": return _赌神(ctx, card, 表)
		"轮盘双响": return _轮盘双响(ctx, card, 表)
		"闪避增益": return _闪避增益(ctx, card, 表)
		"自身增益": return _自身增益(ctx, card, 表)
		"光环": return _光环(ctx, 表)
		"打空回气势": return _打空回气势(ctx, card, 表)
		"再动": return _再动(ctx, card, 表)
		"守护": return _守护(ctx, card, 表)
		"硬碰硬": return _硬碰硬(ctx, card, 表)
		"治疗": return _治疗(ctx, 表)
		"读牌": return 读牌(ctx)
		"冷却清零": return _冷却清零(ctx, 表)
		"止损": return _止损(ctx, 表)
		"标记": return _标记(ctx, 表)
		"降费": return _降费(ctx, 表)
	push_error("FacAtx：未知的 ATX 动作「%s」" % 动作)
	return []

# ---------------- 单位 / 目标 ----------------
static func _队友(ctx: Dictionary, 键: String) -> Variant:
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key")) == 键:
			return u
	return null

static func _是ATX(u: Variant) -> bool:
	return u is Dictionary and str(Btl.提取单位三层信息(u).势力) == 势力

static func ATX成员(ctx: Dictionary) -> Array:
	return Units.livingOf("ally", ctx).filter(func(u): return _是ATX(u))

static func _施法者(ctx: Dictionary, card: Dictionary) -> Variant:
	var 单 := str(card.get("角色", ""))
	if 单 != "":
		var u = _队友(ctx, 单)
		if u != null:
			return u
	for k in 涉及角色键(card):
		var v = _队友(ctx, str(k))
		if v != null:
			return v
	var 们 := ATX成员(ctx)
	if not 们.is_empty():
		var 排 := 们.duplicate()
		J.sort(排, func(a, b):
			var d := J.num0(b.get("shoot")) - J.num0(a.get("shoot"))
			return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		return 排[0]
	for u in Units.livingOf("ally", ctx):
		return u
	return null

static func 血比(u: Variant) -> float:
	var 上 := float(u.get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float(u.get("hp", 0.0)) / 上

static func _头(们: Array, 比较: Callable) -> Array:
	if 们.is_empty():
		return []
	var 排 := 们.duplicate()
	J.sort(排, 比较)
	return [排[0]]

## 目标选择（确定性，不消耗随机数）：自动 / 最低血 / 最高血 / 前排优先 / 全体 / 一排
static func _选目标(ctx: Dictionary, 参: Dictionary) -> Array:
	var 敌 := Units.livingOf("enemy", ctx)
	if 敌.is_empty():
		return []
	match str(参.get("目标", "自动")):
		"全体":
			return 敌
		"一排":
			var 前 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			var 后 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_BACK)
			return 前 if 前.size() >= 后.size() else 后
		"最高血":
			return _头(敌, func(a, b):
				var d := float(b.get("hp", 0.0)) - float(a.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"最低血":
			return _头(敌, func(a, b):
				var d := float(a.get("hp", 0.0)) - float(b.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"前排优先":
			var 前2 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			return _头(前2 if not 前2.is_empty() else 敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		_:
			return _头(敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))

# ---------------- 一次攻击 ----------------
static func _武器(名: String, 参: Dictionary, 威力: float, 命中: float, 段数: int) -> Dictionary:
	var 曲射: bool = J.truthy(参.get("曲射"))
	var 近战: bool = J.truthy(参.get("近战"))
	var w := {
		"name": 名, "fire": "melee" if 近战 else ("indirect" if 曲射 else "direct"),
		"power": 威力, "hit": 命中, "critMod": J.num0(参.get("暴击")),
		"stat": str(参.get("属性", "射击")), "dmgType": str(参.get("伤害类型", "物理")),
		"cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"ignoreDef": J.truthy(参.get("无视防御")), "special": null,
	}
	if 段数 > 1:
		w["hits"] = float(段数)
		w["special"] = "multi"
	return w

static func _被挡罚(ctx: Dictionary, 攻: Variant, t: Variant, w: Dictionary) -> float:
	if t == null or t.get("slot") == null:
		return 0.0
	var kind = Reach.rangeKindOf(w)
	if kind != Reach.KIND_DIRECT():
		return 0.0
	var 活位 = Units.livingOf("enemy", ctx).map(func(x): return x.slot)
	return Reach.rowBlockPenalty(kind, t.get("slot"), 活位, 攻, t)

static func _一发(ctx: Dictionary, 攻: Dictionary, t: Dictionary, w: Dictionary, 必暴: bool = false) -> Dictionary:
	var 前 := float(t.get("hp", 0.0))
	var 罚 := _被挡罚(ctx, 攻, t, w)
	var rec: Dictionary = Calc.resolveAttack(攻, t, w, ctx, {"blockPenalty": 罚, "必暴": 必暴})
	# 打空记录：本回合「被打空过」标记（幻影凤凰的 ×1.3 判定用）
	var 段数 := int(rec.get("段数", 1.0))
	var 中 := int(rec.get("命中段数", 段数))
	if 中 < 段数:
		t["_本回合被打空回合"] = int(ctx.get("turn", 1))
	if 前 > 0.0 and float(t.get("hp", 0.0)) <= 0.0:
		Fac.势力击破(ctx, 攻, t)
	return rec

static func _记攻击(ctx: Dictionary, 牌名: String, card: Dictionary, 攻: Dictionary, t: Dictionary, rec: Dictionary, 额外: Dictionary = {}) -> void:
	var 字段: Dictionary = J.merged(J.merged({
		"类型": "攻击", "单位": 攻.get("key"), "武器": 牌名,
		"战术牌": card.get("id"), "目标": t.get("key"),
	}, Btl.谁(攻)), Btl.谁目标(t))
	字段 = J.merged(字段, rec.get("字段"))
	字段 = J.merged(字段, 额外)
	Btl.pushLog(ctx, "〔%s〕%s → %s：%s" % [牌名, str(攻.get("name", "")), str(t.get("name", "")), rec.get("文本")], 字段)

## 一张牌的攻击（可能多段 / 全体 / 一排）；返回摘要
static func _攻击(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 攻 = _施法者(ctx, card)
	if 攻 == null:
		return ["【%s】没有能出手的 ATX 成员" % str(card.get("名", ""))]
	var 牌名 := str(参.get("名", card.get("名", "")))
	var 命中 := J.num0(参.get("命中", 95.0))
	var 段数 := maxi(1, int(参.get("段数", 1)))
	var 威力 := J.num0(参.get("威力"))
	# 「一刀两断」：伤害随已损失 HP 提高（每损失 10% +8%，最多 +40%）
	var 损增 := J.num0(参.get("损失HP增伤"))
	if 损增 > 0.0:
		var 步 := int(floorf(maxf(0.0, 1.0 - 血比(攻)) * 10.0))
		威力 *= 1.0 + minf(损增, float(步) * 0.08)
	var 目标们 := _选目标(ctx, 参)
	if 目标们.is_empty():
		return ["【%s】没有可打的目标" % 牌名]
	var 打空段 := 0
	for t in 目标们:
		if float(t.get("hp", 0.0)) <= 0.0:
			continue
		var 本威力 := 威力
		if J.num0(参.get("被打空过增伤")) > 0.0 and int(t.get("_本回合被打空回合", -1)) == int(ctx.get("turn", 1)):
			本威力 *= J.num0(参.get("被打空过增伤"))
		var w := _武器(牌名, 参, 本威力, 命中, 段数)
		var rec := _一发(ctx, 攻, t, w, J.truthy(参.get("必暴")))
		_记攻击(ctx, 牌名, card, 攻, t, rec)
		打空段 += maxi(0, 段数 - int(rec.get("命中段数", 段数)))
		# 「龙雷闪」：被命中的敌人下回合命中 −10
		if J.num0(参.get("被命中敌命中惩罚")) != 0.0 and int(rec.get("命中段数", 0)) > 0:
			Btl.换同源增益(t, "卡牌:%s" % str(card.get("id", "")),
				{"hit": J.num0(参.get("被命中敌命中惩罚")), "剩余": 2.0})
		摘要.append("%s → %d 台（打空 %d 段）" % [牌名, 目标们.size(), 打空段])
	# 「龙王破山剑」：命中后全队下回合命中 +10
	if J.num0(参.get("命中后全队命中")) > 0.0:
		for u in ATX成员(ctx):
			Btl.换同源增益(u, "龙王破山剑", {"hit": J.num0(参.get("命中后全队命中")), "剩余": 2.0})
		Btl.pushLog(ctx, "〔龙王破山剑〕命中后全队下回合命中 +%d" % int(J.num0(参.get("命中后全队命中"))),
			{"类型": "增益", "势力": 势力, "命中加成": J.num0(参.get("命中后全队命中")), "回合": ctx.turn})
		摘要.append("全队下回合命中 +%d" % int(J.num0(参.get("命中后全队命中"))))
	# 「左轮打桩机·全弹」：打空的段各再判定一次（必暴击）
	if J.truthy(参.get("打空重判必暴")) and 打空段 > 0:
		var t0: Dictionary = 目标们[0]
		if float(t0.get("hp", 0.0)) > 0.0:
			var w2 := _武器(牌名 + "·打空重判", 参, 威力, 命中, mini(打空段, 12))
			var rec2 := _一发(ctx, 攻, t0, w2, true)
			_记攻击(ctx, 牌名 + "·打空重判", card, 攻, t0, rec2, {"打空重判": true})
		摘要.append("打空重判：%d 段再判定一次（必暴）" % mini(打空段, 12))
	return 摘要

## 「赌神」：段数 = 上次打出这张牌以来的打空段数（上限 12），每段必暴、命中 −20
static func _赌神(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 本场 := int(J.g(ctx.get("战况计数"), "未命中段"))
	var 上次 := int(ctx.get("ATX赌神上次打空", 0))
	var 段 := J.clamp(本场 - 上次, 1, 赌神段数上限)
	ctx["ATX赌神上次打空"] = 本场
	var 表 := 参.duplicate(true)
	表["段数"] = 段
	表["必暴"] = true
	return _攻击(ctx, card, 表)

## 合体技【轮盘双响】：艾克赛琳先射 4 段，响介再冲锋 6 段；任一段打空 → 补射一段（最多 6，必暴）
static func _轮盘双响(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 艾 = _队友(ctx, "A2")
	var 响 = _队友(ctx, "A1")
	if 艾 == null or 响 == null:
		return ["【轮盘双响】响介 / 艾克赛琳 不在场，打不出"]
	var 打空 := 0
	var 步们 := [
		[艾, "轮盘双响·艾克赛琳先射", int(参.get("先射段数", 4)), J.num0(参.get("先射威力", 820.0))],
		[响, "轮盘双响·响介冲锋", int(参.get("冲锋段数", 6)), J.num0(参.get("冲锋威力", 760.0))],
	]
	for 步 in 步们:
		var 谁: Dictionary = 步[0]
		var 敌 = _选目标(ctx, {"目标": "自动"})
		if 敌.is_empty():
			break
		var t: Dictionary = 敌[0]
		var w := _武器(str(步[1]), {"近战": is_same(步[0], 响)}, J.num0(步[3]), 100.0, int(步[2]))
		var rec := _一发(ctx, 谁, t, w, false)
		_记攻击(ctx, str(步[1]), card, 谁, t, rec, {"合体技": true})
		打空 += maxi(0, int(步[2]) - int(rec.get("命中段数", 步[2])))
		摘要.append("%s：%d 段" % [str(步[1]), int(步[2])])
	var 补 := mini(打空, int(参.get("补射上限", 6)))
	if 补 > 0:
		var 敌2 = _选目标(ctx, {"目标": "自动"})
		if not 敌2.is_empty():
			var t2: Dictionary = 敌2[0]
			var w2 := _武器("轮盘双响·补射", {}, J.num0(参.get("补射威力", 900.0)), 100.0, 补)
			var rec2 := _一发(ctx, 艾, t2, w2, true)
			_记攻击(ctx, "轮盘双响·补射", card, 艾, t2, rec2, {"合体技": true, "补射": true})
			摘要.append("补射 %d 段（必暴）" % 补)
	return 摘要

# ---------------- 增益 / 光环 ----------------
static func _增益表(参: Dictionary) -> Dictionary:
	var 出: Dictionary = J.or_(参.get("增益"), {}).duplicate(true)
	if 出.get("剩余") == null:
		出["剩余"] = 1.0
	return 出

static func _光环(ctx: Dictionary, 参: Dictionary) -> Array:
	var 范围 := str(参.get("范围", "ATX"))
	var 增益 := _增益表(参)
	var 源 := "ATX:%s" % 范围
	var 们: Array = []
	match 范围:
		"我方全体", "敌我全体":
			们 = Units.livingOf("ally", ctx)
		"敌方前排":
			们 = Units.livingOf("enemy", ctx).filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
		"敌方全体":
			们 = Units.livingOf("enemy", ctx)
		_:
			们 = ATX成员(ctx)
	for u in 们:
		Btl.换同源增益(u, 源, 增益)
	if 范围 == "敌我全体":
		for e in Units.livingOf("enemy", ctx):
			Btl.换同源增益(e, 源, 增益)
	Btl.pushLog(ctx, "〔ATX 光环·%s〕%s：%d 台（%s）" % [范围, str(参.get("说明", "本回合光环")), 们.size(), str(增益)],
		{"类型": "增益", "势力": 势力, "光环": 范围, "台数": float(们.size()), "回合": ctx.turn})
	return ["ATX 光环·%s：%d 台" % [范围, 们.size()]]

static func _自身增益(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id", "")), _增益表(参))
	return ["%s 获得 %s" % [str(u.get("name", "")), str(参.get("增益"))]]

static func _闪避增益(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要 := _自身增益(ctx, card, 参)
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u != null:
		u["孤注一掷中"] = ctx.turn
		u["孤注一掷每闪"] = J.num0(参.get("每闪气势", 3))
		u["孤注一掷上限"] = J.num0(参.get("气势上限", 9))
	Btl.pushLog(ctx, "〔孤注一掷〕本回合闪避 +30；每闪开一次攻击，气势 +3（最多 +9）",
		{"类型": "增益", "势力": 势力, "单位": 键, "回合": ctx.turn})
	return 摘要

static func _守护(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	u["守护中"] = ctx.turn
	Btl.换同源增益(u, "守护", _增益表(参))
	Btl.pushLog(ctx, "〔守护〕%s 本回合替对位队友承受攻击" % str(u.get("name", "")),
		{"类型": "增益", "势力": 势力, "单位": 键, "守护": true, "回合": ctx.turn})
	return ["守护：%s 替对位队友挡枪" % str(u.get("name", ""))]

static func _硬碰硬(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	u["硬碰硬中"] = ctx.turn
	Btl.换同源增益(u, "硬碰硬", {"受伤Mul": -0.30, "eva": -100.0, "剩余": 1.0})
	Btl.pushLog(ctx, "〔硬碰硬〕%s 本回合闪避归零、受到伤害 −30%%，每受击一次自己的大招牌冷却 −1" % str(u.get("name", "")),
		{"类型": "增益", "势力": 势力, "单位": 键, "回合": ctx.turn})
	return ["硬碰硬：闪避归零、受伤 −30%"]

static func _打空回气势(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", card.get("角色", "")))
	var u = _队友(ctx, 键)
	if u == null:
		return ["%s 不在场" % 键]
	var 段 := _本回合打空(ctx)
	var 加 := mini(int(参.get("上限", 10)), 段 * int(参.get("每段", 2)))
	u["眨眼中"] = ctx.turn
	var 后 := Btl.加气势(ctx, 加)
	Btl.pushLog(ctx, "〔眨眼〕%s 本回合打空 %d 段 → 气势 +%d（现在 %s）" % [str(u.get("name", "")), 段, 加, J.s(后)],
		{"类型": "增益", "势力": 势力, "单位": 键, "气势加": 加, "回合": ctx.turn})
	return ["眨眼：气势 +%d" % 加]

static func _治疗(ctx: Dictionary, 参: Dictionary) -> Array:
	var 们 := Units.livingOf("ally", ctx)
	if 们.is_empty():
		return ["没有可治疗的队友"]
	var 排 := 们.duplicate()
	J.sort(排, func(a, b):
		var d := 血比(a) - 血比(b)
		return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
	var t: Dictionary = 排[0]
	var 前 := float(t.get("hp", 0.0))
	var 量 := J.round(float(t.get("maxHp", 0.0)) * J.num0(参.get("比", 0.25)))
	t["hp"] = minf(float(t.get("maxHp", 0.0)), 前 + 量)
	Btl.pushLog(ctx, "〔念动迷彩·治愈〕%s 回复 %s（%s → %s）" % [str(t.get("name", "")), J.s(J.round(float(t.hp) - 前)),
		J.s(J.round(前)), J.s(J.round(float(t.hp)))],
		{"类型": "修理", "单位": t.get("key"), "回复": J.round(float(t.hp) - 前), "回合": ctx.turn})
	return ["治疗：%s 回复 %d" % [str(t.get("name", "")), J.round(float(t.hp) - 前)]]

# ---------------- 读牌（Btl.算意图） ----------------
## 本回合意图攻击 ATX 的敌人命中 −30。**纯读意图**（`Btl.算意图` 自己不掷随机数），
## 只往敌方挂一条 `hit: -30` 的 buff —— 意图一变（下回合重算）就自然落空。
static func 读牌(ctx: Dictionary) -> Array:
	var 意图: Array = Btl.算意图(ctx)
	var 打 := 0
	var 名们: Array = []
	for 条 in 意图:
		if not (条 is Dictionary):
			continue
		var 目标键 = 条.get("目标")
		var 打ATX := false
		for u in ATX成员(ctx):
			if 目标键 != null and str(u.get("key")) == str(目标键):
				打ATX = true
				break
		if not 打ATX:
			continue
		var 敌 = _找敌(ctx, str(条.get("单位", "")))
		if 敌 == null:
			continue
		Btl.换同源增益(敌, "读牌", {"hit": -30.0, "剩余": 1.0})
		打 += 1
		名们.append(str(敌.get("name", "")))
	Btl.pushLog(ctx, "〔读牌〕本回合意图攻击 ATX 的敌人命中 −30：%s" % ("、".join(名们) if not 名们.is_empty() else "（这一回合没有敌人瞄准 ATX）"),
		{"类型": "增益", "势力": 势力, "读牌": true, "台数": float(打), "命中惩罚": -30.0, "回合": ctx.turn})
	return ["读牌：%d 台敌人命中 −30" % 打]

static func _找敌(ctx: Dictionary, 键: String) -> Variant:
	for e in Units.livingOf("enemy", ctx):
		if str(e.get("key")) == 键:
			return e
	return null

# ---------------- 再动（W17·中继） ----------------
## 速度最高的**另一名** ATX 成员立即再动一次（主武器卡回手，可再打 1 张）。
## 每回合只能触发 1 次；被再动的机体不会再触发它（本回合打上 `被W17再动回合`）。
static func _再动(ctx: Dictionary, card: Dictionary, _参: Dictionary) -> Array:
	var 键 := str(card.get("角色", "A3"))
	var 自己 = _队友(ctx, 键)
	if 自己 == null:
		return ["W17·中继：%s 不在场" % 键]
	if int(自己.get("W17已触发回合", -1)) == int(ctx.get("turn", 1)):
		return ["W17·中继：本回合已经触发过 1 次（每回合只能 1 次）"]
	var 候选 := ATX成员(ctx).filter(func(u):
		return not is_same(u, 自己) and int(u.get("被W17再动回合", -1)) != int(ctx.get("turn", 1)))
	if 候选.is_empty():
		return ["W17·中继：没有可再动的 ATX 队友"]
	J.sort(候选, func(a, b):
		var d := Units.speedOf(b) - Units.speedOf(a)
		return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
	var t: Dictionary = 候选[0]
	自己["W17已触发回合"] = int(ctx.get("turn", 1))
	t["被W17再动回合"] = int(ctx.get("turn", 1))
	# ★ 再动 = 主武器卡回手（作者 2026-10-17 拍板：凡触发【再动】统一置 `主武器已销毁 = false`）
	t["主武器已销毁"] = false
	t["连续攻击已用"] = true
	Btl.pushLog(ctx, "〔W17·中继〕%s 行动后，速度最高的 ATX 队友 %s（速度 %s）立即再动：主武器卡全部回手" % [
		str(自己.get("name", "")), str(t.get("name", "")), J.s(Units.speedOf(t))],
		{"类型": "再动", "势力": 势力, "单位": 键, "目标": t.get("key"),
			"目标位": t.get("slot"), "主武器已销毁": false, "回合": ctx.turn})
	return ["W17·中继：%s 再动（主武器卡回手）" % str(t.get("name", ""))]

# ---------------- 其余势力牌动作 ----------------
static func _冷却清零(ctx: Dictionary, 参: Dictionary) -> Array:
	if J.truthy(ctx.get("ATX梭哈已用")):
		return ["梭哈：本场已经用过 1 次"]
	ctx["ATX梭哈已用"] = true
	var 最小 := maxi(1, int(参.get("最小冷却", 梭哈冷却最小)))
	var 清 := 0
	for u in Units.livingOf("ally", ctx):
		for 池 in [J.or_(u.get("专属手牌"), []), J.or_(u.get("专属牌库"), []), J.or_(u.get("专属弃牌堆"), [])]:
			for c in 池:
				if not (c is Dictionary) or str(c.get("归属", "")) != 势力:
					continue
				var 旧 := int(c.get("当前冷却", 0))
				if 旧 <= 0:
					continue
				c["当前冷却"] = 最小
				清 += 1
	Btl.pushLog(ctx, "〔梭哈〕所有冷却中的 ATX 角色牌冷却清零（清零后最小冷却 %d；本场只能用 1 次，清了 %d 张）" % [最小, 清],
		{"类型": "减冷却", "势力": 势力, "清零": true, "最小冷却": 最小, "张数": float(清), "回合": ctx.turn})
	return ["梭哈：%d 张 ATX 角色牌冷却清零（最小 %d）" % [清, 最小]]

static func _止损(ctx: Dictionary, 参: Dictionary) -> Array:
	var 段 := maxi(0, int(ctx.get("ATX上回合打空", 0)))
	var 加 := mini(int(参.get("上限", 15)), 段)
	var 后 := Btl.加气势(ctx, 加)
	Btl.pushLog(ctx, "〔止损〕上回合打空 %d 段 → 气势 +%d（现在 %s）" % [段, 加, J.s(后)],
		{"类型": "增益", "势力": 势力, "气势加": 加, "回合": ctx.turn})
	return ["止损：气势 +%d" % 加]

static func _标记(ctx: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("键", ""))
	if 键 == "":
		return []
	ctx[键] = true
	Btl.pushLog(ctx, "〔%s〕本回合生效（只生效一次）" % 键,
		{"类型": "增益", "势力": 势力, "标记": 键, "回合": ctx.turn})
	return ["%s：本回合生效" % 键]

static func _降费(ctx: Dictionary, 参: Dictionary) -> Array:
	var 值 := int(参.get("值", 10))
	ctx["下张ATX角色牌降费"] = int(ctx.get("下张ATX角色牌降费", 0)) + 值
	Btl.pushLog(ctx, "〔幸运连号〕下一张 ATX 角色牌费用 −%d（累计 %d）" % [值, int(ctx["下张ATX角色牌降费"])],
		{"类型": "降费", "势力": 势力, "值": 值, "累计": int(ctx["下张ATX角色牌降费"]), "回合": ctx.turn})
	return ["幸运连号：下一张 ATX 角色牌降费 −%d" % 值]

# ==========================================================================
# 四、每回合 / 每场状态
# ==========================================================================
## 本场开始：降费 / 赌神基准 / 梭哈「每场 1 次」/ 打空基准。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["下张ATX角色牌降费"] = 0
	ctx["ATX赌神上次打空"] = 0
	ctx["ATX梭哈已用"] = false
	ctx["ATX本回合起始打空"] = int(J.g(ctx.get("战况计数"), "未命中段"))
	ctx["ATX上回合打空"] = 0

## 我方阶段开始：本回合的一次性光环 / 标记清掉，并按「打空」的差分记下本回合 / 上回合各打空多少段。
static func 本回合重置(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	var 本场 := int(J.g(ctx.get("战况计数"), "未命中段"))
	var 起始 := int(ctx.get("ATX本回合起始打空", 本场))
	ctx["ATX上回合打空"] = maxi(0, 本场 - 起始)
	ctx["ATX本回合起始打空"] = 本场
	ctx["下张ATX角色牌降费"] = 0
	ctx.erase("ATX二次下注")
	ctx.erase("ATX庄家通吃")

## 本回合为止打空了多少段（本场累计 − 本回合起始）
static func _本回合打空(ctx: Dictionary) -> int:
	var 本场 := int(J.g(ctx.get("战况计数"), "未命中段"))
	return maxi(0, 本场 - int(ctx.get("ATX本回合起始打空", 0)))
