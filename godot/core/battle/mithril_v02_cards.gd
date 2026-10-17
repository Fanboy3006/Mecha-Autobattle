## MITH-2：秘银势力卡牌设计 v0.2（「Uruz 连携作战」）—— 26 张牌的数据表 + 装填 + 专属效果执行器。
##
## 规格（唯一真源）：
##   · `协作/设计/秘银势力卡牌设计 v0.2.md`（25 张正式牌 + 1 张衍生牌 TDD-1）
##   · `协作/架构/评审-秘银连携作战-v0.2与派生任务单-ARGON.md` §2 四道断路器 / §3 MITH-2
##
## ★ 开关：本模块的**全部入口**都只在 `Params.秘银v02开(ctx) == true` 时被 `btl.gd` / `card_effects.gd`
##   调用。开关关着（默认）= 本模块一行都不执行 —— 168 场黄金样例与既有 1368 项门禁逐字不变（硬性红线 2）。
##
## 牌面字段口径（与既有 32 张牌共用同一套字段名，多出来的只有 v0.2 自己的）：
##   id / 名 / 类型（大招|战术）/ 层级（角色|势力）/ 种类（角色|势力|合体技|衍生）
##   归属 = 角色所属势力 = "秘银"（术牌只有 归属）/ 角色 / 角色们 / 占行动 / 合体技
##   耗气 / 回气 / 限次 / 冷却 / 回库 / 衍生 / 是TDD1 / 入牌（初始|条件）
##   触发条件（声明式，见 `Btl._声明式触发`）/ 触发说明 / 连携阈值 / 连携效果 / 效果 / 效果说明
##
## 两道「改牌面就炸」的东西（别顺手挪）：
##   1. **连携**：`连携阈值 > 0` 的牌，`btl.gd` 在用 n_before（本牌打出前的秘银牌数）判定后
##      按 `本回合连携触发倍率` 执行 `连携效果`；本文件里 4 张「连携改的是这一次攻击本身」的牌
##      （超长距离狙击 / 导弹齐射·饱和 / 单分子刀·猎鹰 / 乌鲁兹·三角）把连携写进基础效果的算子里
##      按 `ctx["_本牌连携前计数"]` 内联判定，`连携效果` 留空数组 —— 否则同一次伤害会被算两遍。
##   2. **TDD-1 的名字**：`名` 必须保持 "TDD-1 导弹"（既有 MITH-1 验收断言的日志原文），
##      规格里的正式名 "TDD-1·巡航导弹" 放在 `全名` / `兼容名`。
class_name MithrilV02Cards
extends RefCounted

const 势力 := "秘银"
const 成员键: Array = ["U7", "U6", "U2", "U1", "U8"]
const 合体技成员: Array = ["U7", "U2", "U6"]
const TDD1_ID := "TDD-1"
const 合体技ID := "U_URUZ_TRI"

## 规格 §4 的「连携牌统计」：8 / 25（外加衍生牌 TDD-1 不带连携，断路器 1）。
const 连携牌: Array = ["U_U6_2", "U_U2_1", "U_U2_3", "U_U1_1", "U_U8_3", 合体技ID, "F_MITH_V2_2", "F_MITH_V2_8"]

## TDD-1 单发威力（规格「中等物理伤害（如 260 点物理伤害）」）
const TDD1_威力 := 260.0
## 「呼叫达纳号」「火力支援请求」单张卡单回合生成上限（断路器 2）
const 造弹上限 := 4

static var _表: Array = []

# ==========================================================================
# 一、26 张牌的数据定义
# ==========================================================================
static func 卡表() -> Array:
	if _表.is_empty():
		_表 = _构建()
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return c.duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	for c in 卡表():
		if str(c.get("id")) == str(id):
			return c.duplicate(true)
	return {}

## `id` 可以传 id 字符串，也可以直接传一张牌（读它的 `id`）
static func 有(id: Variant) -> bool:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return true
	return false

static func 是连携牌(card: Variant) -> bool:
	return card is Dictionary and int(card.get("连携阈值", 0)) > 0 and J.inc(连携牌, card.get("id"))

static func 是v02牌(card: Variant) -> bool:
	return card is Dictionary and 有(card.get("id"))

static func 角色牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "角色")

static func 势力牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "势力")

static func 合体技卡() -> Dictionary:
	return 卡(合体技ID)

# ---------------- 小工具：牌面拼装 ----------------
static func _底(id: String, 名: String, 耗气: float, 冷却: float) -> Dictionary:
	return {
		"id": id, "名": 名, "归属": 势力, "耗气": 耗气, "回气": 0.0, "限次": 1.0, "冷却": 冷却,
		"回库": true, "衍生": false, "是TDD1": false, "入牌": "初始",
		"触发条件": {"类型": "开局在手"}, "触发说明": "开局在手",
		"连携阈值": 0, "连携效果": [], "效果": [], "效果说明": "",
	}

static func _并入(d: Dictionary, 额外: Variant) -> void:
	if 额外 is Dictionary:
		for k in 额外.keys():
			d[k] = 额外[k]

## 角色牌：绑 1 个角色；`占行动` 由调用方在 `额外` 里写（战术牌不一定占行动）
static func _角色牌(id: String, 名: String, 类: String, 角色: String, 耗气: float, 冷却: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, 耗气, 冷却)
	d["类型"] = 类
	d["层级"] = "角色"
	d["种类"] = "角色"
	d["角色"] = 角色
	d["角色所属势力"] = 势力
	d["占行动"] = [角色]
	_并入(d, 额外)
	_收尾(d)
	return d

## 势力牌：无绑定角色、不占行动
static func _势力牌(id: String, 名: String, 耗气: float, 冷却: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, 耗气, 冷却)
	d["类型"] = "战术"
	d["层级"] = "势力"
	d["种类"] = "势力"
	d["占行动"] = []
	_并入(d, 额外)
	_收尾(d)
	return d

static func _收尾(d: Dictionary) -> void:
	var 条件 = d.get("触发条件")
	var 类型 := str(条件.get("类型", "")) if 条件 is Dictionary else ""
	d["入牌"] = "初始" if 类型 == "开局在手" else "条件"
	if str(d.get("触发说明", "")) == "":
		d["触发说明"] = 类型
	_收尾卡类(d)

## ★ DECK-4：`卡类` 三分类（双排分流口径）——逐张落到字段上，测试逐张断言。
##   · `种类 == 势力`                         → 公有牌（进 `ctx.公有牌库`）
##   · `种类 == 衍生` / `衍生 == true`        → 衍生攻击卡（进 `ctx.公有手牌`，打出不销毁主武器）
##   · `占行动` 非空（占行动的攻击牌 / 大招） → 主武器卡（进对应机体的 `专属牌库`）
##   · `占行动` 为空（纯增益 / 回战意 / 战术）→ 专属精神牌（进 `专属牌库`）
## 卡表里显式写了 `卡类` 的以牌面为准（本函数只兜底）。
static func _收尾卡类(d: Dictionary) -> void:
	if str(d.get("卡类", "")) != "":
		return
	var 种 := str(d.get("种类", ""))
	if 种 == "势力":
		d["卡类"] = "公有牌"
	elif 种 == "衍生" or J.truthy(d.get("衍生")):
		d["卡类"] = "衍生攻击卡"
	elif not J.or_(d.get("占行动"), []).is_empty():
		d["卡类"] = "主武器卡"
	else:
		d["卡类"] = "专属精神牌"

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

static func _开局在手(说明: String) -> Dictionary:
	return {"类型": "开局在手", "说明": 说明}

static func _第N回合(阈: int) -> Dictionary:
	return {"类型": "第N回合起", "阈值": 阈, "说明": "第 %d 回合起" % 阈}

# ---------------- 构建 ----------------
static func _构建() -> Array:
	var 表: Array = []
	# ---- 衍生牌（1 张）----
	表.append({
		"id": TDD1_ID, "名": "TDD-1 导弹", "全名": "TDD-1·巡航导弹", "兼容名": "TDD-1 导弹",
		"类型": "战术", "层级": "势力", "种类": "衍生", "归属": 势力, "占行动": [],
		"卡类": "衍生攻击卡",
		"耗气": 0.0, "回气": 0.0, "限次": 1.0, "冷却": 0.0,
		"回库": false, "衍生": true, "是TDD1": true, "入牌": "衍生",
		"触发条件": null, "触发说明": "衍生牌（由其他牌置入手牌）",
		"连携阈值": 0, "连携效果": [],
		"效果说明": "对敌方当前 HP 最高的存活单位造成 %d 点物理伤害（走护盾抵消与伤害扣减）；若本回合开了「饱和攻击」，再追加一发巡航导弹" % int(TDD1_威力),
		"效果": [{"全局": [{"算子": "v02", "动作": "TDD1", "威力": TDD1_威力}]}],
	})
	# ---- U7 宗介（特种 · ARX-7 强弩）：强力单卡，没有连携 ----
	表.append(_角色牌("U_U7_1", "λ 驱动·散弹炮", "大招", "U7", 20.0, 3.0, {
		"触发条件": _开局在手("开局在手"), "占行动": ["U7"],
		"效果说明": "特殊伤害（无视抗性，只被护盾抵消），命中 90；目标相邻位受 50%",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "λ 驱动·散弹炮", "目标": "自动",
			"威力": 2750.0, "命中": 90.0, "伤害类型": "特殊", "溅射相邻": 0.5}]}],
	}))
	表.append(_角色牌("U_U7_2", "λ 驱动·极限放出", "大招", "U7", 35.0, 5.0, {
		"触发条件": {"类型": "宗介HP或受击", "hp_pct": 50, "受击": 4, "说明": "宗介 HP ≤ 50% 或 受击 ≥ 4"},
		"占行动": ["U7"],
		"效果说明": "特殊伤害（无视抗性，只被护盾抵消），对敌方单体造成巨大一击",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "λ 驱动·极限放出", "目标": "自动",
			"威力": 4300.0, "命中": 95.0, "伤害类型": "特殊"}]}],
	}))
	表.append(_角色牌("U_U7_3", "专业军人", "战术", "U7", 5.0, 2.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [],
		"效果说明": "本回合宗介命中 +20、对大型目标伤害 +20%；下一张宗介大招牌费用 −10",
		"效果": [{"全局": [{"算子": "v02", "动作": "宗介强化", "命中": 20.0, "大型增伤": 0.2, "下张大招降费": 10}]}],
	}))
	# ---- U6 克鲁兹（狙击 · M9 狙击型）----
	表.append(_角色牌("U_U6_1", "76mm 狙击炮", "战术", "U6", 5.0, 1.0, {
		"触发条件": _开局在手("开局在手"), "占行动": ["U6"],
		"效果说明": "单体狙击，高命中；目标本回合已被秘银攻击过则必中",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "76mm 狙击炮", "目标": "自动",
			"威力": 2550.0, "命中": 120.0, "伤害类型": "物理", "被秘银打过必中": true}]}],
	}))
	表.append(_角色牌("U_U6_2", "超长距离狙击", "大招", "U6", 25.0, 4.0, {
		"触发条件": _第N回合(2), "占行动": ["U6"], "连携阈值": 2, "连携效果": [],
		"连携内联": true,
		"效果说明": "无视防御的单体狙击；连携·2：必中、必暴击",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "超长距离狙击", "目标": "自动",
			"威力": 3950.0, "命中": 120.0, "伤害类型": "物理", "无视防御": true, "暴击": 10.0,
			"连携必中": true, "连携必暴": true}]}],
	}))
	表.append(_角色牌("U_U6_3", "「看见了」", "战术", "U6", 5.0, 2.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [],
		"效果说明": "本回合下一次秘银攻击命中 +15；抽 1 张牌",
		"效果": [
			{"全局": [{"算子": "v02", "动作": "命中加成", "范围": "下一次", "值": 15.0}]},
			{"全局": [{"算子": "v02", "动作": "抽牌", "数量": 1}]},
		],
	}))
	# ---- U2 梅丽莎·毛（指挥 · M9 指挥型）：呼叫达纳号的人 ----
	表.append(_角色牌("U_U2_1", "呼叫达纳号", "战术", "U2", 10.0, 3.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [], "连携阈值": 1,
		"连携效果": [{"全局": [{"算子": "v02", "动作": "置入TDD1", "数量": 1, "每回合上限": 造弹上限}]}],
		"效果说明": "置入 1 张 TDD-1；连携：改为 2 张",
		"效果": [{"全局": [{"算子": "v02", "动作": "置入TDD1", "数量": 1, "每回合上限": 造弹上限}]}],
	}))
	表.append(_角色牌("U_U2_2", "导弹发射器", "战术", "U2", 5.0, 1.0, {
		"触发条件": _开局在手("开局在手"), "占行动": ["U2"],
		"效果说明": "攻击敌方目标，溅射相邻位 50%",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "导弹发射器", "目标": "自动",
			"威力": 1600.0, "命中": 100.0, "伤害类型": "物理", "曲射": true, "溅射相邻": 0.5}]}],
	}))
	表.append(_角色牌("U_U2_3", "导弹齐射·饱和", "大招", "U2", 25.0, 4.0, {
		"触发条件": {"类型": "触发连携", "阈值": 3, "说明": "本场触发连携 ≥ 3 次"},
		"占行动": ["U2"], "连携阈值": 1, "连携效果": [], "连携内联": true,
		"效果说明": "敌方全体受 1 轮导弹伤害；连携·N：本回合在它之前每打出 1 张秘银牌多 1 轮（最多 +4）",
		"效果": [{"全局": [{"算子": "v02", "动作": "导弹齐射", "名": "导弹齐射·饱和",
			"威力": 1200.0, "命中": 100.0, "连携上限": 4}]}],
	}))
	# ---- U1 克鲁佐（近卫 · M9 猎鹰）----
	表.append(_角色牌("U_U1_1", "单分子刀·猎鹰", "大招", "U1", 25.0, 4.0, {
		"触发条件": {"类型": "克鲁佐击破或回合", "击破": 1, "回合": 3, "说明": "克鲁佐本场击破 ≥ 1 或 第 3 回合起"},
		"占行动": ["U1"], "连携阈值": 2, "连携效果": [], "连携内联": true,
		"效果说明": "高威力近战；打完本回合克鲁佐受到伤害 +20%；连携·2：本次伤害 ×1.5，击破则本回合下一张秘银牌费用 −10",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "单分子刀·猎鹰", "目标": "前排优先",
			"威力": 2600.0, "命中": 100.0, "伤害类型": "物理", "近战": true,
			"连携威力倍率": 1.5, "连携击破降费": 10, "自受伤加成": 0.2}]}],
	}))
	表.append(_角色牌("U_U1_2", "冷血", "战术", "U1", 5.0, 2.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [],
		"效果说明": "本回合克鲁佐伤害 +25%，且本回合不援护队友",
		"效果": [{"全局": [{"算子": "v02", "动作": "克鲁佐强化", "伤害": 0.25, "不援护": true}]}],
	}))
	表.append(_角色牌("U_U1_3", "散弹枪急袭", "战术", "U1", 5.0, 1.0, {
		"触发条件": _开局在手("开局在手"), "占行动": ["U1"],
		"效果说明": "近距 2 段攻击（优先打前排存活敌人，前排全灭才打后排）",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "散弹枪急袭", "目标": "前排优先",
			"威力": 1300.0, "命中": 100.0, "伤害类型": "物理", "段数": 2, "近战": true}]}],
	}))
	# ---- U8 杨（尖兵 · M9 侦察）：便宜的垫牌 ----
	表.append(_角色牌("U_U8_1", "激光引导", "战术", "U8", 0.0, 1.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [],
		"效果说明": "本回合所有秘银攻击命中 +10",
		"效果": [{"全局": [{"算子": "v02", "动作": "命中加成", "范围": "全秘银", "值": 10.0}]}],
	}))
	表.append(_角色牌("U_U8_2", "ECS 隐形", "战术", "U8", 5.0, 3.0, {
		"触发条件": _开局在手("开局在手"), "占行动": [],
		"效果说明": "到杨下一次攻击之前敌人不能选杨为目标；杨本回合不攻击；抽 1 张牌",
		"效果": [
			{"全局": [{"算子": "v02", "动作": "隐身", "角色": "U8"}]},
			{"全局": [{"算子": "v02", "动作": "抽牌", "数量": 1}]},
		],
	}))
	表.append(_角色牌("U_U8_3", "反坦克导弹", "大招", "U8", 15.0, 3.0, {
		"触发条件": _第N回合(2), "占行动": ["U8"], "连携阈值": 1,
		"连携效果": [{"全局": [{"算子": "v02", "动作": "置入TDD1", "数量": 1, "每回合上限": 造弹上限}]}],
		"效果说明": "对敌方发射两发曲射导弹；连携：置入 1 张 TDD-1",
		"效果": [{"全局": [{"算子": "v02", "动作": "攻击", "名": "反坦克导弹", "目标": "自动",
			"威力": 1900.0, "命中": 100.0, "伤害类型": "物理", "曲射": true, "发数": 2}]}],
	}))
	# ---- 合体技（1 张）----
	表.append({
		"id": 合体技ID, "名": "乌鲁兹·三角", "类型": "大招", "层级": "角色", "种类": "合体技",
		"归属": 势力, "角色所属势力": 势力, "合体技": true, "角色": "", "角色们": 合体技成员.duplicate(),
		"占行动": 合体技成员.duplicate(), "卡类": "主武器卡", "耗气": 40.0, "回气": 0.0, "限次": 1.0, "冷却": 6.0,
		"回库": true, "衍生": false, "是TDD1": false, "入牌": "条件",
		"触发条件": {"类型": "乌鲁兹三角", "触发连携": 6, "说明": "本场触发连携 ≥ 6 次，且 U7 / U2 / U6 都在场存活"},
		"触发说明": "本场触发连携 ≥ 6 次，且 U7 / U2 / U6 都在场存活",
		"连携阈值": 1, "连携效果": [], "连携内联": true,
		"效果说明": "① 达纳号对敌方全体打 1 轮巡航导弹（连携·N：之前每张秘银牌多 1 轮，最多 +3）② 克鲁兹狙击 HP 最低的敌人，必中 ③ 宗介对 HP 最高的敌人打「λ 驱动·极限放出」",
		"效果": [{"全局": [{"算子": "v02", "动作": "合体技", "轰炸轮数": 1, "连携上限": 3,
			"轰炸威力": 1500.0, "狙击威力": 3950.0, "极限威力": 4300.0}]}],
	})
	# ---- 势力牌（9 张）----
	表.append(_势力牌("F_MITH_V2_1", "作战开始", 0.0, 2.0, {
		"触发条件": _开局在手("开局在手"),
		"效果说明": "抽 1 张牌",
		"效果": [{"全局": [{"算子": "v02", "动作": "抽牌", "数量": 1}]}],
	}))
	表.append(_势力牌("F_MITH_V2_2", "火力支援请求", 10.0, 3.0, {
		"触发条件": _第N回合(2), "连携阈值": 1,
		"连携效果": [{"全局": [{"算子": "v02", "动作": "置入TDD1", "数量": 1, "每回合上限": 造弹上限}]}],
		"效果说明": "置入 1 张 TDD-1；连携：改为 2 张",
		"效果": [{"全局": [{"算子": "v02", "动作": "置入TDD1", "数量": 1, "每回合上限": 造弹上限}]}],
	}))
	表.append(_势力牌("F_MITH_V2_3", "饱和攻击", 15.0, 4.0, {
		"触发条件": {"类型": "打出TDD1", "阈值": 3, "说明": "本场打出 TDD-1 ≥ 3 张"},
		"效果说明": "本回合之后每打出 1 张 TDD-1，再对随机存活敌人追加一发导弹伤害",
		"效果": [{"全局": [{"算子": "v02", "动作": "饱和攻击", "值": 1}]}],
	}))
	表.append(_势力牌("F_MITH_V2_4", "数据链", 5.0, 2.0, {
		"触发条件": _开局在手("开局在手"),
		"效果说明": "本回合下一张秘银牌费用 −5",
		"效果": [{"全局": [{"算子": "v02", "动作": "降费", "值": 5, "大类": "秘银"}]}],
	}))
	表.append(_势力牌("F_MITH_V2_5", "ECM 干扰", 10.0, 3.0, {
		"触发条件": {"类型": "秘银受击", "阈值": 3, "说明": "秘银本场受击 ≥ 3"},
		"效果说明": "本回合敌方攻击秘银成员命中 −15",
		"效果": [{"全局": [{"算子": "v02", "动作": "ECM", "命中惩罚": 15.0}]}],
	}))
	表.append(_势力牌("F_MITH_V2_6", "紧急回收", 0.0, 3.0, {
		"触发条件": {"类型": "秘银低血", "hp_pct": 40, "说明": "有秘银成员 HP ≤ 40%"},
		"效果说明": "HP 最低（或 ≤40%）的秘银成员和它的对位队友交换站位",
		"效果": [{"全局": [{"算子": "v02", "动作": "换位"}]}],
	}))
	表.append(_势力牌("F_MITH_V2_7", "卡里宁的判断", 5.0, 3.0, {
		"触发条件": _第N回合(2),
		"效果说明": "看牌库顶 3 张，选 1 张加入手牌（优先秘银牌）",
		"效果": [{"全局": [{"算子": "v02", "动作": "看牌", "张数": 3}]}],
	}))
	表.append(_势力牌("F_MITH_V2_8", "再装填", 10.0, 3.0, {
		"触发条件": _开局在手("开局在手"), "连携阈值": 3,
		"连携效果": [{"全局": [{"算子": "v02", "动作": "减秘银角色牌冷却", "值": 2}]}],
		"效果说明": "连携·3：一张冷却中的秘银角色牌冷却 −2；没有连携·3 则没有效果",
		"效果": [],
	}))
	表.append(_势力牌("F_MITH_V2_9", "泰莎的指令", 15.0, 4.0, {
		"触发条件": {"类型": "打出过秘银大招", "阈值": 1, "说明": "打出过秘银大招牌"},
		"效果说明": "本回合下一张牌的连携效果触发两次（连续两张仍封顶 2 倍）",
		"效果": [{"全局": [{"算子": "v02", "动作": "双倍连携", "倍率": 2}]}],
	}))
	return 表

# ==========================================================================
# 二、装填（由 `Btl.生成队伍牌池` 在秘银 v0.2 开着时调用）
# ==========================================================================
## 在场秘银成员的角色牌（每人 3 张）+ 合体技（U7/U2/U6 都在场）+ 9 张势力牌。
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

## 「这只旧牌是 v0.1 的秘银牌，v0.2 开着时要被替换掉」：F_MITH_1 / F_MITH_2 / 旧版秘银角色牌。
static func 是旧秘银牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if str(card.get("角色所属势力", "")) == 势力:
		return true
	return str(card.get("层级", "")) == "势力" and str(card.get("归属", "")) == 势力

# ==========================================================================
# 三、绑定角色 / 占行动 / 阵亡移除
# ==========================================================================
## 这张牌绑定的**全部**角色（占行动 / 角色们 / 角色）：任一人阵亡 → 不可打出并从手牌 / 待触发池移除。
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

## 打出时**占用谁的回合行动**：`占行动` 优先；没写但 `类型 == 大招` 且绑了角色 → 就占那个角色。
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

static func 绑定已阵亡(ctx: Variant, card: Variant) -> bool:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return false
	for k in 涉及角色键(card):
		if _队友(ctx, str(k)) == null:
			return true
	return false

## 从「战术手牌」与「待触发战术牌」里移除绑定角色已阵亡的秘银牌（v0.2 开着时由
## `Btl.检查条件发牌` / `Flow.回合开始` / `Btl.打战术牌` 调用）。返回被移除的牌。
static func 清理阵亡卡牌(ctx: Variant) -> Array:
	var 移除: Array = []
	if not (ctx is Dictionary):
		return 移除
	var 池名 := {"战术手牌": "手牌", "待触发战术牌": "待触发池", "候补初始牌": "候补初始牌"}
	for 池键 in 池名.keys():
		var 池 = ctx.get(池键)
		if not (池 is Array):
			continue
		var 留: Array = []
		for c in 池:
			if c is Dictionary and 有(c.get("id")) and 绑定已阵亡(ctx, c):
				移除.append(c)
				Btl.记(ctx, {"类型": "秘银v02移除", "卡牌": c.get("名"), "文本": "〔秘银 v0.2〕%s 已阵亡 → 【%s】从%s移除" % [
					"、".join(涉及角色键(c)), str(c.get("名", "")), str(池名[池键])]})
				continue
			留.append(c)
		ctx[池键] = 留
	return 移除

# ==========================================================================
# 四、每回合 / 每场的 v0.2 状态
# ==========================================================================
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["下张秘银牌降费"] = 0
	ctx["下张宗介大招降费"] = 0
	ctx["本回合饱和攻击"] = 0
	ctx["本回合敌方命中秘银减命中"] = 0

static func 本回合重置(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["本回合饱和攻击"] = 0
	ctx["本回合敌方命中秘银减命中"] = 0
	ctx["下张秘银牌降费"] = 0
	ctx["下张宗介大招降费"] = 0

## ★ 衍生牌解析（`CardEffects.grant_derived_card` 在秘银 v0.2 开着时先问这里）：
## 认得的 id 返回 v0.2 的完整牌面；认不出 / 开关关着 返回空字典（调用方退回 MITH-1 的内置模板）。
static func 衍生牌定义(ctx: Variant, tpl_or_id: Variant) -> Dictionary:
	if not Params.秘银v02开(ctx):
		return {}
	var 键 := str(tpl_or_id) if not (tpl_or_id is Dictionary) else str(tpl_or_id.get("id", ""))
	if 键 == TDD1_ID:
		return 卡(TDD1_ID)
	return {}

# ==========================================================================
# 五、效果执行器（由 `CardEffects` 的 `{"算子": "v02", "动作": …}` 分发进来）
# ==========================================================================
## 连携：本牌打出前已经打出过至少 N 张秘银牌（`btl.gd` 在效果执行前写进 ctx）
static func _连携前(ctx: Dictionary) -> int:
	return int(ctx.get("_本牌连携前计数", 0))

static func _连携成立(ctx: Dictionary, card: Dictionary) -> bool:
	var 阈 := int(card.get("连携阈值", 0))
	return 阈 > 0 and _连携前(ctx) >= 阈

## 断路器 4：连携倍率封顶 2（「泰莎的指令」双倍）
static func _连携倍率(ctx: Dictionary) -> int:
	return clampi(int(ctx.get("本回合连携触发倍率", 1)), 1, 2)

static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx = 运行.get("ctx")
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	if not (ctx is Dictionary):
		return []
	match 动作:
		"攻击": return _攻击(ctx, card, 表)
		"导弹齐射": return _导弹齐射(ctx, card, 表)
		"合体技": return _合体技(ctx, card, 表)
		"TDD1": return _TDD1(ctx, card, 表)
		"置入TDD1": return _置入TDD1(ctx, card, 表)
		"抽牌": return 抽牌(ctx, int(表.get("数量", 1)))
		"降费":
			var 前 := int(ctx.get("下张秘银牌降费", 0))
			ctx["下张秘银牌降费"] = 前 + int(表.get("值", 5))
			return ["下一张秘银牌降费 −%d（累计 %d）" % [int(表.get("值", 5)), int(ctx["下张秘银牌降费"])]]
		"命中加成": return _命中加成(ctx, card, 表)
		"隐身": return _隐身(ctx, card, 表)
		"换位": return _换位(ctx)
		"减秘银角色牌冷却": return _减秘银角色牌冷却(ctx, int(表.get("值", 2)))
		"饱和攻击":
			ctx["本回合饱和攻击"] = int(ctx.get("本回合饱和攻击", 0)) + int(表.get("值", 1))
			Btl.pushLog(ctx, "〔饱和攻击〕本回合此后每打出 1 张 TDD-1，追加一发巡航导弹（当前 %d）" % int(ctx["本回合饱和攻击"]),
				{"类型": "饱和攻击", "本回合饱和攻击": int(ctx["本回合饱和攻击"]), "回合": ctx.turn})
			return ["饱和攻击：本回合 TDD-1 追加导弹（%d）" % int(ctx["本回合饱和攻击"])]
		"双倍连携":
			ctx["本回合连携触发倍率"] = clampi(int(表.get("倍率", 2)), 1, 2)
			ctx["_连携倍率待清"] = true
			Btl.pushLog(ctx, "〔泰莎的指令〕本回合下一张牌的连携效果触发两次（倍率 %d，连续两张仍封顶 2）" % int(ctx["本回合连携触发倍率"]),
				{"类型": "双倍连携", "连携倍率": int(ctx["本回合连携触发倍率"]), "回合": ctx.turn})
			return ["双倍连携：本回合下一张牌连携触发 %d 次" % int(ctx["本回合连携触发倍率"])]
		"宗介强化": return _宗介强化(ctx, 表)
		"克鲁佐强化": return _克鲁佐强化(ctx, 表)
		"ECM":
			ctx["本回合敌方命中秘银减命中"] = int(表.get("命中惩罚", 15))
			Btl.pushLog(ctx, "〔ECM 干扰〕本回合敌方攻击秘银成员命中 −%d" % int(ctx["本回合敌方命中秘银减命中"]),
				{"类型": "ECM", "命中惩罚": int(ctx["本回合敌方命中秘银减命中"]), "回合": ctx.turn})
			return ["ECM 干扰：敌方命中 −%d" % int(ctx["本回合敌方命中秘银减命中"])]
		"看牌": return _看牌(ctx, int(表.get("张数", 3)))
	push_error("MithrilV02Cards：未知的 v0.2 动作「%s」" % 动作)
	return []

# ---------------- 单位 / 目标 ----------------
static func _队友(ctx: Dictionary, 键: String) -> Variant:
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key")) == 键:
			return u
	return null

static func _是秘银(u: Variant) -> bool:
	return FacMith.是秘银(u)

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
	var 最好 = null
	for u in J.or_(ctx.get("allies"), []):
		if u == null or float(u.get("hp", 0.0)) <= 0.0 or not _是秘银(u):
			continue
		if 最好 == null or J.num0(u.get("shoot")) > J.num0(最好.get("shoot")):
			最好 = u
	if 最好 != null:
		return 最好
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0:
			return u
	return null

static func _找位(ctx: Dictionary, 方: String, 位: Variant) -> Variant:
	for u in Units.livingOf(方, ctx):
		if u.get("slot") != null and J.same(float(u.get("slot")), float(位)):
			return u
	return null

static func _头(们: Array, 比较: Callable) -> Array:
	if 们.is_empty():
		return []
	var 排 := 们.duplicate()
	J.sort(排, 比较)
	return [排[0]]

## 目标选择（确定性，不消耗随机数）：自动 / 最低血 / 最高血 / 前排优先 / 全体
static func _选目标(ctx: Dictionary, 参: Dictionary) -> Array:
	var 敌 := Units.livingOf("enemy", ctx)
	if 敌.is_empty():
		return []
	match str(参.get("目标", "自动")):
		"全体":
			return 敌
		"最高血":
			return _头(敌, func(a, b):
				var d := float(b.get("hp", 0.0)) - float(a.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"最低血":
			return _头(敌, func(a, b):
				var d := float(a.get("hp", 0.0)) - float(b.get("hp", 0.0))
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		"前排优先":
			var 前 := 敌.filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			return _头(前 if not 前.is_empty() else 敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
		_:
			return _头(敌, func(a, b):
				var d := 血比(a) - 血比(b)
				return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))

static func 血比(u: Variant) -> float:
	var 上 := float(u.get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float(u.get("hp", 0.0)) / 上

## 「大型目标」（敌人模板的 `size` ≥ 2）—— 「专业军人」的对大型增伤判定用
static func 是大型目标(u: Variant) -> bool:
	return u is Dictionary and J.num0(u.get("size")) >= 2.0

# ---------------- 武器 / 一次攻击 ----------------
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

## 一次「牌面攻击」：走 `Calc.resolveAttack`（命中 / 暴击 / 装甲 / 防御 / 护盾 / 掩护全套管线）。
static func _一发(ctx: Dictionary, 攻: Dictionary, t: Dictionary, w: Dictionary, 必中: bool, 必暴: bool) -> Dictionary:
	var 前 := float(t.get("hp", 0.0))
	var 罚 := _被挡罚(ctx, 攻, t, w)
	var rec: Dictionary = Calc.resolveAttack(攻, t, w, ctx, {"blockPenalty": 罚, "必中": 必中, "必暴": 必暴})
	t["_本回合被秘银攻击回合"] = int(ctx.get("turn", 1))
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

# ---------------- 各动作 ----------------
static func _攻击(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 攻 = _施法者(ctx, card)
	if 攻 == null:
		return ["【%s】没有能出手的秘银成员" % str(card.get("名", ""))]
	var 牌名 := str(参.get("名", card.get("名", "")))
	var 连携 := _连携成立(ctx, card)
	var 倍率 := _连携倍率(ctx)
	var 威力 := J.num0(参.get("威力"))
	var 连携加成 := 1.0
	var 连威 := J.num0(参.get("连携威力倍率"))
	if 连携 and 连威 > 0.0:
		for _i in range(倍率):
			连携加成 *= 连威
	var 必中: bool = J.truthy(参.get("必中")) or (连携 and J.truthy(参.get("连携必中")))
	var 必暴: bool = J.truthy(参.get("必暴")) or (连携 and J.truthy(参.get("连携必暴")))
	var 命中 := J.num0(参.get("命中"))
	var 一次性 := int(ctx.get("下一次秘银攻击命中加成", 0))
	if 一次性 > 0:
		命中 += float(一次性)
		ctx.erase("下一次秘银攻击命中加成")
	var 段数 := maxi(1, int(参.get("段数", 1)))
	var 发数 := maxi(1, int(参.get("发数", 1)))
	var 击破了 := false
	var 任意目标 = null
	for _i in range(发数):
		var 目标们 := _选目标(ctx, 参)
		if 目标们.is_empty():
			break
		var t: Dictionary = 目标们[0]
		var 本次必中 := 必中
		if J.truthy(参.get("被秘银打过必中")) and int(t.get("_本回合被秘银攻击回合", -1)) == int(ctx.get("turn", 1)):
			本次必中 = true
		var 本发威力 := 威力 * 连携加成
		var 大型增伤 := Calc.buffSum(攻, "大型DmgMul")
		if 大型增伤 > 0.0 and 是大型目标(t):
			本发威力 *= 1.0 + 大型增伤
		var w := _武器(牌名, 参, 本发威力, 命中, 段数)
		var rec := _一发(ctx, 攻, t, w, 本次必中, 必暴)
		_记攻击(ctx, 牌名, card, 攻, t, rec, {"连携": 连携, "连携加成": 连携加成})
		任意目标 = t
		if float(t.get("hp", 0.0)) <= 0.0:
			击破了 = true
		摘要.append("%s → %s（%s）" % [牌名, str(t.get("name", "")), J.s(J.g(rec.get("字段"), "伤害"))])
		# 溅射相邻位（50%）：邻位算独立一发（不计段数、不算「再打一张牌」）
		var 溅 := J.num0(参.get("溅射相邻"))
		if 溅 > 0.0 and t.get("slot") != null:
			for s in Fm.相邻位(float(t.get("slot"))):
				var 邻 = _找位(ctx, "enemy", s)
				if 邻 == null or is_same(邻, t):
					continue
				var w2 := _武器(牌名 + "·溅射", 参, 本发威力 * 溅, 命中, 1)
				var rec2 := _一发(ctx, 攻, 邻, w2, 本次必中, false)
				_记攻击(ctx, 牌名 + "·溅射", card, 攻, 邻, rec2, {"连携": 连携, "连携加成": 连携加成, "溅射": true})
				if float(邻.get("hp", 0.0)) <= 0.0:
					击破了 = true
	# 打完本回合自己受伤 +N（「冲进敌阵」）
	var 受伤 := J.num0(参.get("自受伤加成"))
	if 受伤 > 0.0 and 攻 != null:
		Btl.换同源增益(攻, 牌名, {"受伤Mul": 受伤, "剩余": 1.0})
		摘要.append("%s 本回合受到伤害 +%d%%" % [str(攻.get("name", "")), int(J.round(受伤 * 100.0))])
	# 连携·2：击破 → 本回合下一张秘银牌费用 −10
	if 连携 and 击破了 and int(参.get("连携击破降费", 0)) > 0:
		ctx["下张秘银牌降费"] = int(ctx.get("下张秘银牌降费", 0)) + int(参.get("连携击破降费", 0))
		摘要.append("连携击破：本回合下一张秘银牌费用 −%d" % int(参.get("连携击破降费", 0)))
	return 摘要

## 导弹齐射·饱和：敌方全体 1 轮 + 连携·N（本回合已打出秘银牌数，最多 +4）
static func _导弹齐射(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 攻 = _施法者(ctx, card)
	if 攻 == null:
		return ["【%s】没有能出手的秘银成员" % str(card.get("名", ""))]
	var 牌名 := str(参.get("名", card.get("名", "")))
	var 连携 := _连携成立(ctx, card)
	var 上限 := int(参.get("连携上限", 4))
	var 轮 := 1
	if 连携:
		轮 += mini(_连携前(ctx), 上限)
		if _连携倍率(ctx) >= 2:
			轮 += mini(_连携前(ctx), 上限)
	var 威力 := J.num0(参.get("威力"))
	var 命中 := J.num0(参.get("命中"))
	for i in range(轮):
		for t in Units.livingOf("enemy", ctx):
			if float(t.get("hp", 0.0)) <= 0.0:
				continue
			var w := _武器(牌名, 参, 威力, 命中, 1)
			var rec := _一发(ctx, 攻, t, w, true, false)
			_记攻击(ctx, 牌名, card, 攻, t, rec, {"连携": 连携, "轮次": float(i + 1), "总轮数": float(轮)})
	摘要.append("%s：%d 轮 × 敌方全体（连携 %s）" % [牌名, 轮, "成立" if 连携 else "未成立"])
	return 摘要

## 乌鲁兹·三角：① 达纳号全体巡航导弹（连携·N：最多 +3 轮）② 克鲁兹狙击 HP 最低 ③ 宗介打 HP 最高
static func _合体技(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 连携 := _连携成立(ctx, card)
	var 轮 := int(参.get("轰炸轮数", 1))
	if 连携:
		轮 += mini(_连携前(ctx), int(参.get("连携上限", 3)))
		if _连携倍率(ctx) >= 2:
			轮 += mini(_连携前(ctx), int(参.get("连携上限", 3)))
	var 达纳号 = _施法者(ctx, card)
	if 达纳号 != null:
		for i in range(轮):
			for t in Units.livingOf("enemy", ctx):
				if float(t.get("hp", 0.0)) <= 0.0:
					continue
				var w := _武器("达纳号·巡航导弹", {"曲射": true}, J.num0(参.get("轰炸威力", 1500.0)), 100.0, 1)
				var rec := _一发(ctx, 达纳号, t, w, true, false)
				_记攻击(ctx, "乌鲁兹·三角·达纳号", card, 达纳号, t, rec, {"连携": 连携, "轮次": float(i + 1), "总轮数": float(轮), "步骤": 1.0})
	摘要.append("① 达纳号：%d 轮 × 敌方全体" % 轮)
	# ② 克鲁兹：狙击 HP 最低的敌人，必中
	var 克 = _队友(ctx, "U6")
	if 克 == null:
		克 = 达纳号
	var 低 := _选目标(ctx, {"目标": "最低血"})
	if 克 != null and not 低.is_empty():
		var t2: Dictionary = 低[0]
		var w2 := _武器("超长距离狙击", {"暴击": 10.0}, J.num0(参.get("狙击威力", 3950.0)), 120.0, 1)
		var rec2 := _一发(ctx, 克, t2, w2, true, false)
		_记攻击(ctx, "乌鲁兹·三角·克鲁兹", card, 克, t2, rec2, {"连携": 连携, "步骤": 2.0})
		摘要.append("② 克鲁兹 → %s（必中）" % str(t2.get("name", "")))
	# ③ 宗介：对 HP 最高的敌人打「λ 驱动·极限放出」（特殊伤害）
	var 宗 = _队友(ctx, "U7")
	if 宗 == null:
		宗 = 达纳号
	var 高 := _选目标(ctx, {"目标": "最高血"})
	if 宗 != null and not 高.is_empty():
		var t3: Dictionary = 高[0]
		var w3 := _武器("λ 驱动·极限放出", {"伤害类型": "特殊"}, J.num0(参.get("极限威力", 4300.0)), 95.0, 1)
		var rec3 := _一发(ctx, 宗, t3, w3, true, false)
		_记攻击(ctx, "乌鲁兹·三角·宗介", card, 宗, t3, rec3, {"连携": 连携, "步骤": 3.0})
		摘要.append("③ 宗介 → %s（λ 驱动·极限放出）" % str(t3.get("name", "")))
	return 摘要

## TDD-1 巡航导弹：敌方当前 HP 最高的存活单位；饱和攻击追加一发（不计再打一张牌）
static func _TDD1(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var 攻 = _施法者(ctx, card)
	if 攻 == null:
		return ["【TDD-1】没有能引导的秘银成员"]
	var 威力 := J.num0(参.get("威力", TDD1_威力))
	var 目标们 := _选目标(ctx, {"目标": "最高血"})
	if 目标们.is_empty():
		return ["【TDD-1】没有可打的目标"]
	var t: Dictionary = 目标们[0]
	var w := _武器("TDD-1 巡航导弹", {"曲射": true}, 威力, 100.0, 1)
	var rec := _一发(ctx, 攻, t, w, true, false)
	_记攻击(ctx, "TDD-1 巡航导弹", card, 攻, t, rec, {"衍生": true, "是TDD1": true})
	摘要.append("TDD-1 巡航导弹 → %s（%s）" % [str(t.get("name", "")), J.s(J.g(rec.get("字段"), "伤害"))])
	# 饱和攻击：追加一发（随机存活敌人；**不**推进连携计数、也不算再打出一张牌）
	if int(ctx.get("本回合饱和攻击", 0)) > 0:
		var 追加 = _随机存活敌人(ctx)
		if 追加 != null:
			var w2 := _武器("TDD-1 巡航导弹·饱和追加", {"曲射": true}, 威力, 100.0, 1)
			var rec2 := _一发(ctx, 攻, 追加, w2, true, false)
			_记攻击(ctx, "TDD-1 巡航导弹·饱和追加", card, 攻, 追加, rec2,
				{"衍生": true, "是TDD1": true, "饱和追加": true})
			摘要.append("饱和攻击：追加一发 → %s（%s）" % [str(追加.get("name", "")), J.s(J.g(rec2.get("字段"), "伤害"))])
	return 摘要

static func _随机存活敌人(ctx: Dictionary) -> Variant:
	var 敌 := Units.livingOf("enemy", ctx)
	if 敌.is_empty():
		return null
	var rng = ctx.get("rng")
	var 位 := 0
	if rng != null:
		位 = int(floorf(float(rng.next_float()) * float(敌.size())))
	return 敌[clampi(位, 0, 敌.size() - 1)]

static func _置入TDD1(ctx: Dictionary, card: Dictionary, 参: Dictionary) -> Array:
	var 数量 := maxi(0, int(参.get("数量", 1)))
	var 上限 := int(参.get("每回合上限", 造弹上限))
	# 断路器 2：单张卡单回合生成上限（按来源卡牌 id 记账，见 `CardEffects.grant_derived_card`）
	return CardEffects.grant_derived_card(ctx, TDD1_ID, 数量, 上限, str(card.get("id", "")))

# ---------------- 抽牌 / 看牌 ----------------
## 抽 1 张牌：从「待触发战术牌」里挑第 1 张**本回合没打出过且冷却 ≤ 0** 的牌发入手牌；
## 若都在冷却则挑冷却最小的 1 张；手牌满 10 张则不发。
static func 抽牌(ctx: Variant, 数量: int = 1) -> Array:
	var 摘要: Array = []
	if not (ctx is Dictionary) or 数量 <= 0:
		return 摘要
	var 主上限 := Params.手牌上限(ctx, "手牌总上限", 10)
	if not (ctx.get("待触发战术牌") is Array):
		ctx.待触发战术牌 = []
	if not (ctx.get("战术手牌") is Array):
		ctx.战术手牌 = []
	for _i in range(数量):
		if ctx.战术手牌.size() >= 主上限:
			Btl.记(ctx, {"类型": "抽牌作废", "文本": "〔抽牌〕手牌已满（%d/%d），这一张作废" % [主上限, 主上限]})
			摘要.append("抽牌作废：手牌已满（%d/%d）" % [主上限, 主上限])
			break
		var 池: Array = ctx.待触发战术牌
		var 选 = null
		for c in 池:
			if c == null or int(c.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
				continue
			if int(c.get("当前冷却", 0)) <= 0:
				选 = c
				break
		if 选 == null:
			var 最小 := 1 << 30
			for c in 池:
				if c == null or int(c.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
					continue
				var 冷 := int(c.get("当前冷却", 0))
				if 冷 < 最小:
					最小 = 冷
					选 = c
		if 选 == null:
			Btl.记(ctx, {"类型": "抽牌作废", "文本": "〔抽牌〕待触发池里没有可抽的牌"})
			摘要.append("抽牌作废：待触发池空")
			break
		var 位 := J.find_index(池, func(c): return is_same(c, 选))
		if 位 >= 0:
			池.remove_at(位)
		选["剩余次数"] = float(选.get("限次", 1.0))
		选["新触发"] = true
		选["触发回合"] = ctx.get("turn", 1.0)
		ctx.战术手牌.append(选)
		Btl.pushLog(ctx, "〔抽牌〕获得战术牌【%s】" % str(选.get("名", "")), {
			"类型": "发牌", "卡牌ID": 选.get("id"), "牌名": 选.get("名"), "层级": 选.get("层级"),
			"归属": 选.get("归属"), "触发说明": "抽牌", "回合": ctx.get("turn", 1.0), "抽牌": true,
		})
		摘要.append("抽牌：【%s】" % str(选.get("名", "")))
	return 摘要

## 卡里宁的判断：看牌库顶 N 张（待触发池前 N 张），优先选秘银牌，否则第 1 张
static func _看牌(ctx: Dictionary, 张数: int) -> Array:
	var 摘要: Array = []
	var 池 = ctx.get("待触发战术牌")
	if not (池 is Array) or 池.is_empty():
		return ["看牌：牌库顶没有牌"]
	var 主上限 := Params.手牌上限(ctx, "手牌总上限", 10)
	if not (ctx.get("战术手牌") is Array):
		ctx.战术手牌 = []
	var 顶: Array = 池.slice(0, mini(maxi(1, 张数), 池.size()))
	var 选 = null
	for c in 顶:
		if c is Dictionary and Btl.是秘银计入牌(c) and int(c.get("上次打出回合", -1)) != int(ctx.get("turn", 1)):
			选 = c
			break
	if 选 == null:
		选 = 顶[0]
	if ctx.战术手牌.size() >= 主上限:
		Btl.记(ctx, {"类型": "看牌作废", "文本": "〔卡里宁的判断〕手牌已满（%d/%d），【%s】留在牌库顶" % [主上限, 主上限, str(选.get("名", ""))]})
		return ["看牌：手牌已满，未取牌"]
	var 位 := J.find_index(池, func(c): return is_same(c, 选))
	if 位 >= 0:
		池.remove_at(位)
	选["剩余次数"] = float(选.get("限次", 1.0))
	ctx.战术手牌.append(选)
	Btl.pushLog(ctx, "〔卡里宁的判断〕从牌库顶 %d 张里选走【%s】" % [顶.size(), str(选.get("名", ""))], {
		"类型": "发牌", "卡牌ID": 选.get("id"), "牌名": 选.get("名"), "层级": 选.get("层级"),
		"归属": 选.get("归属"), "触发说明": "卡里宁的判断", "回合": ctx.get("turn", 1.0), "看牌": true,
	})
	摘要.append("看牌：取走【%s】" % str(选.get("名", "")))
	return 摘要

# ---------------- 其余动作 ----------------
static func _命中加成(ctx: Dictionary, _card: Dictionary, 参: Dictionary) -> Array:
	var 值 := J.num0(参.get("值", 10.0))
	if str(参.get("范围", "全秘银")) == "下一次":
		ctx["下一次秘银攻击命中加成"] = int(值)
		Btl.pushLog(ctx, "〔命中引导〕本回合下一次秘银攻击命中 +%d" % int(值),
			{"类型": "命中加成", "值": 值, "范围": "下一次", "回合": ctx.turn})
		return ["下一次秘银攻击命中 +%d" % int(值)]
	var 打 := 0
	for u in J.or_(ctx.get("allies"), []):
		if u == null or float(u.get("hp", 0.0)) <= 0.0 or not _是秘银(u):
			continue
		Btl.换同源增益(u, "激光引导", {"hit": 值, "剩余": 1.0})
		打 += 1
	Btl.pushLog(ctx, "〔激光引导〕本回合 %d 台秘银成员命中 +%d" % [打, int(值)],
		{"类型": "命中加成", "值": 值, "范围": "全秘银", "台数": float(打), "回合": ctx.turn})
	return ["本回合秘银攻击命中 +%d（%d 台）" % [int(值), 打]]

static func _隐身(ctx: Dictionary, _card: Dictionary, 参: Dictionary) -> Array:
	var 键 := str(参.get("角色", "U8"))
	var u = _队友(ctx, 键)
	if u == null:
		return ["ECS 隐形：%s 不在场" % 键]
	u["_隐身"] = true
	u["actedTurn"] = int(ctx.get("turn", 1))
	Btl.pushLog(ctx, "〔ECS 隐形〕%s 进入隐形（到它下一次攻击之前敌人不能选它为目标），本回合不攻击" % str(u.get("name", "")),
		{"类型": "隐身", "单位": 键, "单位方": u.get("side"), "单位位": u.get("slot"), "回合": ctx.turn})
	return ["ECS 隐形：%s 隐形 + 本回合不攻击" % str(u.get("name", ""))]

static func _换位(ctx: Dictionary) -> Array:
	var 摘要: Array = []
	var 候选: Array = []
	for u in J.or_(ctx.get("allies"), []):
		if u == null or float(u.get("hp", 0.0)) <= 0.0 or not _是秘银(u):
			continue
		候选.append(u)
	if 候选.is_empty():
		return ["紧急回收：没有在场的秘银成员"]
	J.sort(候选, func(a, b):
		var d := 血比(a) - 血比(b)
		return d if d != 0.0 else float(a.get("slot", 0.0)) - float(b.get("slot", 0.0)))
	var 谁: Dictionary = 候选[0]
	if 谁.get("slot") == null:
		return ["紧急回收：%s 没有站位" % str(谁.get("name", ""))]
	var 对位们: Array = Fm.对位(float(谁.get("slot")))
	var 换 = null
	for s in 对位们:
		var o = _找位(ctx, "ally", s)
		if o != null and not is_same(o, 谁):
			换 = o
			break
	if 换 == null:
		return ["紧急回收：%s 没有可换的对位队友" % str(谁.get("name", ""))]
	var 原位 := float(谁.get("slot"))
	var 对位 := float(换.get("slot"))
	谁["slot"] = 对位
	谁["pos"] = 对位
	换["slot"] = 原位
	换["pos"] = 原位
	Btl.pushLog(ctx, "〔紧急回收〕%s（HP %d/%d）与对位的 %s 交换站位：%s 与 %s" % [
		str(谁.get("name", "")), int(谁.get("hp")), int(谁.get("maxHp")), str(换.get("name", "")),
		Fm.位名(原位), Fm.位名(对位)],
		{"类型": "换位", "单位": 谁.get("key"), "目标": 换.get("key"), "原位": 原位, "对位": 对位, "回合": ctx.turn})
	摘要.append("紧急回收：%s 与 %s" % [str(谁.get("name", "")), str(换.get("name", ""))])
	return 摘要

static func _减秘银角色牌冷却(ctx: Dictionary, 值: int) -> Array:
	if 值 <= 0:
		return ["再装填：减冷却值为 0"]
	var 摘要: Array = []
	for 池键 in ["战术手牌", "待触发战术牌"]:
		var 池 = ctx.get(池键)
		if not (池 is Array):
			continue
		for c in 池:
			if not (c is Dictionary) or not 有(c.get("id")):
				continue
			if str(c.get("种类", "")) != "角色":
				continue
			if int(c.get("当前冷却", 0)) <= 0:
				continue
			var 前 := int(c.get("当前冷却", 0))
			c["当前冷却"] = maxi(0, 前 - 值)
			Btl.pushLog(ctx, "〔再装填〕【%s】冷却 %d → %d" % [str(c.get("名", "")), 前, int(c["当前冷却"])],
				{"类型": "减冷却", "卡牌ID": c.get("id"), "牌名": c.get("名"), "冷却前": 前, "冷却后": int(c["当前冷却"]), "回合": ctx.turn})
			摘要.append("再装填：【%s】冷却 %d → %d" % [str(c.get("名", "")), 前, int(c["当前冷却"])])
			return 摘要
	return ["再装填：没有冷却中的秘银角色牌"]

static func _宗介强化(ctx: Dictionary, 参: Dictionary) -> Array:
	var 摘要: Array = []
	var u = _队友(ctx, "U7")
	if u != null:
		var 增益 := {"hit": J.num0(参.get("命中", 20.0)), "剩余": 1.0}
		var 大型 := J.num0(参.get("大型增伤", 0.0))
		if 大型 > 0.0:
			增益["大型DmgMul"] = 大型
		Btl.换同源增益(u, "专业军人", 增益)
		摘要.append("专业军人：宗介命中 +%d、对大型目标伤害 +%d%%" % [int(J.num0(参.get("命中", 20.0))), int(大型 * 100.0)])
	var 降 := int(参.get("下张大招降费", 10))
	if 降 > 0:
		ctx["下张宗介大招降费"] = 降
		摘要.append("下一张宗介大招牌费用 −%d" % 降)
	return 摘要

static func _克鲁佐强化(ctx: Dictionary, 参: Dictionary) -> Array:
	var u = _队友(ctx, "U1")
	if u == null:
		return ["冷血：克鲁佐不在场"]
	var 伤 := J.num0(参.get("伤害", 0.25))
	Btl.换同源增益(u, "冷血", {"dmgMul": 伤, "剩余": 1.0})
	if J.truthy(参.get("不援护")):
		u["_本回合不援护"] = int(ctx.get("turn", 1))
	Btl.pushLog(ctx, "〔冷血〕%s 本回合伤害 +%d%%，且本回合不援护队友" % [str(u.get("name", "")), int(伤 * 100.0)],
		{"类型": "增益", "单位": "U1", "单位方": u.get("side"), "单位位": u.get("slot"), "dmgMul": 伤, "回合": ctx.turn})
	return ["冷血：克鲁佐伤害 +%d%%、本回合不援护" % int(伤 * 100.0)]

# ==========================================================================
# 六、声明式触发条件（`Btl._声明式触发` 在 v0.2 开着时调进来；认不出来 = 不满足）
# ==========================================================================
static func 是秘银在场(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	return not Fac.势力在场(势力, ctx).is_empty()

static func 秘银低血(ctx: Variant, hp_pct: float) -> bool:
	if not (ctx is Dictionary):
		return false
	return J.some(Fac.势力在场(势力, ctx), func(u): return 血比(u) * 100.0 <= hp_pct)

static func 成员存活(ctx: Variant, 键: String) -> bool:
	return (ctx is Dictionary) and _队友(ctx, 键) != null

static func 三人都在场(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	return J.every(合体技成员, func(k): return _队友(ctx, str(k)) != null)

## 「宗介 HP ≤ 50% 或 受击 ≥ 4」（λ 驱动·极限放出的触发条件）
static func 宗介低血或受击(ctx: Variant, hp_pct: float, 受击: int) -> bool:
	if not (ctx is Dictionary):
		return false
	var u = _队友(ctx, "U7")
	if u != null and 血比(u) * 100.0 <= hp_pct:
		return true
	return 战况(ctx, "宗介受击") >= maxi(1, 受击)

## 「克鲁佐本场击破 ≥ 1 或 第 3 回合起」（单分子刀·猎鹰的触发条件）
static func 克鲁佐击破或回合(ctx: Variant, 击破: int, 回合: int) -> bool:
	if not (ctx is Dictionary):
		return false
	return 战况(ctx, "克鲁佐击破") >= maxi(1, 击破) or int(ctx.get("turn", 1)) >= 回合

## 读一个「战况计数」键（缺键 / 没有计数 = 0）
static func 战况(ctx: Variant, 键: String) -> int:
	if not (ctx is Dictionary):
		return 0
	var 计数 = ctx.get("战况计数")
	if not (计数 is Dictionary):
		return 0
	return int(计数.get(键, 0))
