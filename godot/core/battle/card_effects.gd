## 战术卡牌效果的声明式执行器。
##
## 封存版把 32 张牌的效果写死在 Btl.打战术牌 的 match card.id 里（200 多行）；这里改成
##   CARD_OPS（卡牌 id → 一串「组」） + execute()（通用执行器）
## 组 = {"选": <选择器>, "效果": [<算子>…]}（按选出来的单位逐个执行）或 {"全局": [<算子>…]}（只动 ctx）。
## 约定：「选」一个都没选中 → 整组不做（所以按单位的算子必须真的遍历 目标们）；
##       只动 ctx、跟选谁无关的算子（战术…）一律写进「全局」，别混进按单位的组里。
## 加新牌 = 在 CARD_OPS 里加一条；加新玩法 = 加一个算子 / 一个选择条件，不用再动 btl.gd。
##
## 选择器（字典，条件「与」，任一成立用 "任一"）：
##   方 ally|enemy（缺省 ally）· 任一 [{条件}…] · 职业 · 势力 · 键 · 排 front|back · 有标定 · 要战况计数
##   否则全体 true（过滤后为空就取整池）· 取一 最低血比|重装否则最低血比|后排并最高血
##   同路于 <选择器>（对每个锚点找同列敌人；找不到用 enemies[0]——U_B1 的「对位敌机」）
## 算子：
##   增益{源,增益} 护盾{比} 回血{比} 减冷却{值,清零} 标定{层数,来源名,补满}
##   清减益 清负面增益 计数{键,加} 激活势力状态{势力,持续} 战术{值}
## 参数里的令牌：@源 → "卡牌:<id>"、@牌名 → 卡牌名（执行时解析）。
##
## 语义与封存版 JS 参考版逐字一致；数值语义一律走 JsCompat，本文件不用 J.* 宏。
class_name CardEffects
extends RefCounted

const 令牌_源 := "@源"
const 令牌_牌名 := "@牌名"

## ★ MITH-1：内置的 TDD-1 衍生牌模板（「呼叫达纳号」「火力支援请求」等按 id 取它）。
## `效果` 里的选谁 / 打多少都写在数据里；这里只给一份能跑的默认（打敌方生命最低的一台 1200 定伤）。
const TDD1_TEMPLATE: Dictionary = {
	"id": "TDD-1", "名": "TDD-1 导弹", "归属": "秘银", "是TDD1": true, "衍生": true,
	"耗气": 0.0, "回气": 0.0, "限次": 1.0, "冷却": 0.0, "层级": "势力",
	"说明": "衍生牌：对敌方造成导弹伤害，打出后移除且推进秘银连携计数",
	"效果说明": "对敌方一台单位造成 1200 固定伤害（衍生牌，打出后移除）",
	"效果": [{"选": {"方": "enemy", "取一": "最低血比"}, "效果": [{"算子": "固定伤害", "值": 1200.0}]}],
}

const CARD_OPS: Dictionary = {
	# 旧版 24 张 C_* / F_* 战术牌（12 职业 + 12 势力）的效果条目已退役 —— 它们只有旧手牌模式打得出来；
	# 数据仍在 data/js/71-改动-5-参数入口.json 的 战术卡牌表 里（红线 5：卡牌数据一张不删），以后要复用得按新体系重写效果。
	# ---------------- 角色牌 ----------------
	"U_CB1": [
		{"选": {"方": "ally", "键": "CB1"},
			"效果": [
				{"算子": "减冷却", "值": 99.0, "清零": true},
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.40, "hit": 25.0, "剩余": 1.0}},
			]},
	],
	"U_CB2": [
		{"选": {"方": "ally", "键": "CB2"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"crit": 40.0, "dmgMul": 0.35, "剩余": 1.0}}]},
	],
	"U_M1": [
		{"选": {"方": "ally"},
			"效果": [
				{"算子": "回血", "比": 0.15},
				{"算子": "增益", "源": 令牌_源, "增益": {"hit": 15.0, "剩余": 1.0}},
			]},
		{"选": {"方": "ally", "键": "M1"},
			"效果": [{"算子": "减冷却", "值": 2.0}]},
	],
	"U_A1": [
		{"选": {"方": "ally", "键": "A1"},
			"效果": [
				{"算子": "减冷却", "值": 99.0, "清零": true},
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.50, "剩余": 1.0}},
			]},
	],
	"U_S1": [
		{"选": {"方": "ally"},
			"效果": [
				{"算子": "回血", "比": 0.25},
				{"算子": "清减益"},
				{"算子": "清负面增益"},
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.25, "剩余": 1.0}},
			]},
	],
	"U_B1": [
		{"选": {"方": "ally", "键": "B1"},
			"效果": [
				{"算子": "护盾", "比": 0.20},
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.25, "剩余": 1.0}},
			]},
		{"选": {"同路于": {"方": "ally", "键": "B1"}},
			"效果": [{"算子": "标定", "层数": 2.0, "来源名": 令牌_牌名}]},
	],
	# ---------------- 统帅牌 ----------------
	"CMD_ALL_OUT": [
		{"全局": [{"算子": "战术", "值": "总攻"}]},
		{"选": {"方": "ally"},
			"效果": [
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.35, "hit": 15.0, "剩余": 1.0}},
				{"算子": "减冷却", "值": 1.0},
			]},
	],
	"CMD_COVER": [
		{"全局": [{"算子": "战术", "值": "掩护"}]},
		{"选": {"方": "ally"},
			"效果": [
				{"算子": "护盾", "比": 0.25},
				{"算子": "清减益"},
			]},
	],
}

## ★ MITH-1：非 CARD_OPS 的衍生牌模板（id → 卡牌定义）。按 id 传进来时先查这里。
const 衍生牌模板: Dictionary = {
	"TDD-1": TDD1_TEMPLATE,
}

# ======================== 入口 ========================
## 打出一张牌的全部效果。返回「效果摘要」（一行一条：算子名 + 实际打到的单位），给三层反馈的「即时」用。
## 牌不在 CARD_OPS 里（只有耗气 / 回气 / 记档的牌）= 无效果，与封存版的 match 无分支一致。
static func execute(ctx: Dictionary, card: Dictionary) -> Array:
	var 运行: Dictionary = {
		"ctx": ctx,
		"card": card,
		"源": "卡牌:%s" % String(card.get("id")),
		"allies": Units.livingOf("ally", ctx),
		"enemies": Units.livingOf("enemy", ctx),
	}
	var 摘要: Array = []
	for 组 in 组表(card):
		if not (组 is Dictionary):
			continue
		if 组.has("全局"):
			for 算子 in 组.get("全局", []):
				摘要.append_array(执行算子(运行, 算子, []))
			continue
		var 目标们 := 选单位(运行, 组.get("选"))
		if 目标们.is_empty():
			# 按单位的组：一个都没选到就整组不做（防住「忘了遍历 目标们」的算子空跑）。
			# 只动 ctx 的算子（战术…）一律写在「全局」那一支，别放这儿。
			continue
		for 算子 in 组.get("效果", []):
			摘要.append_array(执行算子(运行, 算子, 目标们))
	return 摘要

## ★ MITH-1：单独执行一串算子（`btl.gd` 的连携分支用它，与 `execute` 共用同一套执行器 / 同一套选择器）。
static func execute_ops(ctx: Dictionary, card: Dictionary, ops: Variant) -> Array:
	if ctx == null or card == null or not (ops is Array):
		return []
	var 运行: Dictionary = {
		"ctx": ctx,
		"card": card,
		"源": "卡牌:%s" % String(card.get("id")),
		"allies": Units.livingOf("ally", ctx),
		"enemies": Units.livingOf("enemy", ctx),
	}
	var 摘要: Array = []
	for 组 in ops:
		if not (组 is Dictionary):
			continue
		if 组.has("全局"):
			for 算子 in 组.get("全局", []):
				摘要.append_array(执行算子(运行, 算子, []))
			continue
		var 目标们 := 选单位(运行, 组.get("选"))
		if 目标们.is_empty():
			continue
		for 算子 in 组.get("效果", []):
			摘要.append_array(执行算子(运行, 算子, 目标们))
	return 摘要

# ======================== 衍生牌通道（★ MITH-1） ========================
## 牌的效果组表：CARD_OPS 里的牌按 id 查；衍生牌（带 `效果` 字段的模板 / 实例）直接用它自己的。
static func 组表(card: Dictionary) -> Array:
	if card.get("效果") is Array:
		return card.get("效果")
	var 组们 = CARD_OPS.get(String(card.get("id")))
	return 组们 if 组们 is Array else []

## 模板 / id → 一张完整的衍生牌定义（找不到就退回内置 TDD-1 模板）。
static func 衍生牌定义(tpl_or_id: Variant) -> Dictionary:
	if tpl_or_id is Dictionary:
		return _并(TDD1_TEMPLATE, tpl_or_id)
	var 键 := String(tpl_or_id)
	var 命 = 衍生牌模板.get(键)
	if 命 is Dictionary:
		return _并(TDD1_TEMPLATE, 命)
	var 表 = Db.T.战术卡牌表
	if 表 is Array:
		for c in 表:
			if c is Dictionary and String(c.get("id")) == 键:
				return c
	return TDD1_TEMPLATE

## 后写的盖前面的（不改原字典）
static func _并(底: Dictionary, 盖: Dictionary) -> Dictionary:
	var o := 底.duplicate(true)
	for k in 盖.keys():
		o[k] = 盖[k]
	return o

## ★ 衍生牌置入手牌（「呼叫达纳号」「火力支援请求」等）。
## 断路器 2（单回合生成上限）：`每回合上限 > 0` 时按 `来源卡牌 id` 记 `本回合衍生牌生成计数`，超出的不生成。
## 手牌满（>= 手牌总上限，默认 10）→ **直接作废丢弃**（不进待触发池、不走「记满手牌推迟」），并写一条日志。
## 返回「效果摘要」：置入的逐张一条，被上限截住的一条「生成受限」。
static func grant_derived_card(ctx: Dictionary, tpl_or_id: Variant, count: int = 1, max_per_turn: int = 0, source_key: String = "") -> Array:
	var 摘要: Array = []
	if ctx == null or count <= 0:
		return 摘要
	var tpl: Dictionary = 衍生牌定义(tpl_or_id)
	# ★ DECK-4：衍生攻击卡一律进**下排公有手牌**（硬上限 8 张），不进上排战术手牌。
	#   TDD-1 因此带 `卡类: "衍生攻击卡"`；打出后**不销毁主武器卡**、且推进秘银连携计数（见 btl.gd）。
	return _置入公有手牌(ctx, tpl, count, max_per_turn, source_key)

## ★ DECK-4：单机牌组模式的衍生攻击卡通道 —— 置入 `ctx.公有手牌`（下排），硬上限 `公有手牌硬上限()`（8 张）。
## 断路器 2（单回合生成上限）与老通道同一本账（`本回合衍生牌生成计数` 按来源卡牌 id 记），不会因为换了个池子就放开。
static func _置入公有手牌(ctx: Dictionary, tpl: Dictionary, count: int, max_per_turn: int, source_key: String) -> Array:
	var 摘要: Array = []
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 上限 := int(Params.公有手牌硬上限())
	var 限次 := count
	if max_per_turn > 0:
		if not (ctx.get("本回合衍生牌生成计数") is Dictionary):
			ctx["本回合衍生牌生成计数"] = {}
		var 计: Dictionary = ctx["本回合衍生牌生成计数"]
		var 已 := int(计.get(source_key, 0))
		var 余 := maxi(0, max_per_turn - 已)
		if count > 余:
			摘要.append("生成受限：【%s】本回合上限 %d 张（已生成 %d，本次要求 %d，只做 %d）" % [
				str(tpl.get("名", "")), max_per_turn, 已, count, 余])
		限次 = mini(count, 余)
		计[source_key] = 已 + 限次
	var 牌名 := str(tpl.get("名", ""))
	for _i in range(限次):
		if ctx.公有手牌.size() >= 上限:
			Btl.记(ctx, {"类型": "衍生牌作废", "卡牌": 牌名,
				"文本": "〔衍生牌〕公有手牌已满（%d/%d），【%s】作废" % [上限, 上限, 牌名]})
			摘要.append("衍生牌作废：【%s】公有手牌已满（%d/%d）" % [牌名, 上限, 上限])
			continue
		var 实例 = Btl.克隆战术牌(tpl, ctx)
		实例["衍生"] = true
		实例["是TDD1"] = bool(tpl.get("是TDD1", str(tpl.get("id", "")) == "TDD-1"))
		实例["卡类"] = "衍生攻击卡"
		实例["剩余次数"] = 1.0
		ctx.公有手牌.append(实例)
		var 记条: Dictionary = {"类型": "衍生牌置入", "卡牌": 牌名, "公有手牌": true,
			"文本": "〔衍生牌〕置入公有手牌：【%s】" % 牌名}
		if 实例.get("_实例号") != null:
			记条["实例号"] = 实例["_实例号"]
		Btl.记(ctx, 记条)
		摘要.append("衍生牌置入公有手牌：【%s】" % 牌名)
	return 摘要

# ======================== 选择器 ========================
static func 选单位(运行: Dictionary, 选: Variant) -> Array:

	var 表: Dictionary = 选 if 选 is Dictionary else {}
	if 表.has("同路于"):
		return _同路单位(运行, 表["同路于"])
	var 池 := _池(运行, 表)
	if 表.has("取一"):
		return _取一(池, String(表["取一"]))
	var 出: Array = []
	for u in 池:
		if _匹配(运行, u, 表):
			出.append(u)
	if 出.is_empty() and 表.get("否则全体") == true:
		return 池
	return 出

static func _池(运行: Dictionary, 表: Dictionary) -> Array:
	var 方 := String(表.get("方")) if 表.get("方") != null else "ally"
	return 运行.get("enemies") if 方 == "enemy" else 运行.get("allies")

## 条件全部成立（"任一" 里任一成立）；不认识的条件当场报错，不静默放过
static func _匹配(运行: Dictionary, u: Dictionary, 表: Dictionary) -> bool:
	for k in 表.keys():
		var 键 := String(k)
		if 键 == "方" or 键 == "取一" or 键 == "否则全体" or 键 == "同路于":
			continue
		var 值 = 表[k]
		if 键 == "任一":
			var 成立 := false
			for 子 in 值:
				if 子 is Dictionary and _匹配(运行, u, 子):
					成立 = true
					break
			if not 成立:
				return false
		elif 键 == "职业":
			if not Reach.职业是(u, String(值)):
				return false
		elif 键 == "势力":
			if _势力(u) != String(值):
				return false
		elif 键 == "键":
			if not Btl._是(u, String(值)):
				return false
		elif 键 == "排":
			if Units.unitRow(u) != _排号(String(值)):
				return false
		elif 键 == "有标定":
			if Calc.标定经济层数(u) <= 0.0:
				return false
		elif 键 == "要战况计数":
			var ctx = 运行.get("ctx")
			if not (ctx is Dictionary and _真(ctx.get("战况计数"))):
				return false
		else:
			push_error("CardEffects：未知的选择条件「%s」" % 键)
			return false
	return true

static func _取一(池: Array, 类型: String) -> Array:
	if 类型 == "重装否则最低血比":
		var 重装们 := 池.filter(func(u): return Reach.职业是(u, "重装"))
		if not 重装们.is_empty():
			return 重装们
		if 池.is_empty():
			return []
		var 排 := _稳定排序(池, func(a, b): return _血比(a) - _血比(b))
		return [排[0]]
	if 类型 == "最低血比":
		if 池.is_empty():
			return []
		var 排2 := _稳定排序(池, func(a, b):
			var d := _血比(a) - _血比(b)
			return d if d != 0.0 else float(a.slot) - float(b.slot))
		return [排2[0]]
	if 类型 == "后排并最高血":
		var 靶集: Array = 池.filter(func(e): return Units.unitRow(e) == Fm.ROW_BACK)
		var 排3 := _稳定排序(池, func(a, b):
			var d := float(b.hp) - float(a.hp)
			return d if d != 0.0 else float(a.slot) - float(b.slot))
		if not 排3.is_empty() and not _含同物(靶集, 排3[0]):
			靶集.append(排3[0])
		return 靶集
	push_error("CardEffects：未知的取一规则「%s」" % 类型)
	return []

## 对每个锚点找「同路敌机」（同列；一个都没有就用 enemies[0]）——U_B1 的「对位敌机」
static func _同路单位(运行: Dictionary, 锚选: Variant) -> Array:
	var 出: Array = []
	var 敌们: Array = 运行.get("enemies")
	for 锚 in 选单位(运行, 锚选):
		var 同路 = null
		for e in 敌们:
			if Fm.colOfSlot(e.slot) == Fm.colOfSlot(锚.slot):
				同路 = e
				break
		if 同路 == null and not 敌们.is_empty():
			同路 = 敌们[0]
		if 同路 != null:
			出.append(同路)
	return 出

# ======================== 原子效果算子 ========================
static func 执行算子(运行: Dictionary, 算子: Variant, 目标们: Array) -> Array:
	var 表: Dictionary = 算子 if 算子 is Dictionary else {}
	var 名 := String(表.get("算子"))
	if 名 == "增益":
		var 源 = _解令牌(运行, 表.get("源"))
		var 增益: Dictionary = 表.get("增益") if 表.get("增益") is Dictionary else {}
		for u in 目标们:
			Btl.换同源增益(u, 源, 增益)
	elif 名 == "护盾":
		var 盾比 := _数(表.get("比"))
		for u in 目标们:
			Btl.加卡牌护盾(u, JsCompat.js_round(float(u.maxHp) * 盾比))
	elif 名 == "回血":
		var 血比 := _数(表.get("比"))
		for u in 目标们:
			_回血(u, 血比)
	elif 名 == "减冷却":
		var 清零: bool = 表.get("清零") == true
		for u in 目标们:
			Btl.减单位大招冷却(u, 表.get("值"), 清零)
	elif 名 == "标定":
		var 来源名 = _解令牌(运行, 表.get("来源名"))
		var 补满: bool = 表.get("补满") == true
		for u in 目标们:
			Btl.卡牌加标定(u, 表.get("层数"), 来源名, 补满)
	elif 名 == "清减益":
		for u in 目标们:
			u.debuffs = []
			u.armorCut = 0.0
	elif 名 == "清负面增益":
		for u in 目标们:
			if u.get("buffs") is Array:
				u.buffs = u.buffs.filter(func(b): return not (b != null and (_数(b.get("hit")) < 0.0 or _数(b.get("def")) < 0.0)))
	elif 名 == "计数":
		# 按单位算子：一个匹配单位加一次（封存版也是「在 for u in allies 里逐台判断」）
		for _u in 目标们:
			_加计数(运行, String(表.get("键")), _数(表.get("加")))
	elif 名 == "激活势力状态":
		for u in 目标们:
			_激活势力状态(运行, u, String(表.get("势力")), _数(表.get("持续")))
	elif 名 == "战术":
		var ctx = 运行.get("ctx")
		if ctx is Dictionary:
			ctx["当前战术"] = String(表.get("值"))
	# ---------------- ★ MITH-1 新增算子 ----------------
	elif 名 == "置入衍生牌":
		var ctx2 = 运行.get("ctx")
		if not (ctx2 is Dictionary):
			return []
		var 牌 = 运行.get("card")
		var 源键 := str(表.get("来源", ""))
		if 源键 == "":
			源键 = String(牌.get("id")) if 牌 is Dictionary else ""
		目标们 = grant_derived_card(ctx2, 表.get("模板", "TDD-1"), int(表.get("数量", 1)), int(表.get("每回合上限", 0)), 源键)
	elif 名 == "双倍连携":
		var ctx3 = 运行.get("ctx")
		if not (ctx3 is Dictionary):
			return []
		# 断路器 4：封顶 2 倍 —— 同名 / 多次打出绝不叠加成 4 倍
		ctx3["本回合连携触发倍率"] = clampi(int(表.get("倍率", 2)), 1, 2)
	elif 名 == "减秘银牌冷却":
		var ctx5 = 运行.get("ctx")
		if not (ctx5 is Dictionary):
			return []
		Btl.减秘银牌冷却(ctx5, 运行.get("card"), int(表.get("值", 1)))
	elif 名 == "固定伤害":
		var ctx6 = 运行.get("ctx")
		var 打掉 := 0.0
		for u in 目标们:
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
				打掉 += _固定伤害(ctx6, u, _数(表.get("值")))
		return ["固定伤害：%s（合计 %d）" % ["、".join(目标们.map(func(u): return str(u.get("name", "")))), int(打掉)]]
	# ---------------- ★ DECK-4：ATX v0.2 专属算子（全部转给 FacAtx 执行） ----------------
	elif 名 == "atx":
		var ctx8 = 运行.get("ctx")
		if not (ctx8 is Dictionary):
			return []
		return FacAtx.执行算子(运行, 表, 目标们)
	# ---------------- ★ MITH3-3：秘银 v0.3 专属算子（全部转给 MithrilV03Cards 执行） ----------------
	elif 名 == "v03":
		var ctx9 = 运行.get("ctx")
		if not (ctx9 is Dictionary):
			return []
		return MithrilV03Cards.执行算子(运行, 表, 目标们)
	# ---------------- ★ A6a：三套职业分类牌（近卫 / 尖兵 / 重装，18 张） ----------------
	#   由 ClassCards.执行算子 执行。
	elif 名 == "职业牌":
		var ctx10 = 运行.get("ctx")
		if not (ctx10 is Dictionary):
			return []
		return ClassCards.执行算子(运行, 表, 目标们)
	# ---------------- 第 7 职业【维修】的 6 张分类牌 ----------------
	#   由 `RepairCards.执行算子` 执行（含【过量整备】）。
	elif 名 == "维修牌":
		var ctxR = 运行.get("ctx")
		if not (ctxR is Dictionary):
			return []
		return RepairCards.执行算子(运行, 表, 目标们)
	# ---------------- ★ A6b：塔斯克 / 雷欧娜（A6 / A7）的精神牌 ----------------
	#   交给 `AtxDuo.执行算子`（算子的语义只写在那一边）。
	elif 名 == "duo":
		var ctx11 = 运行.get("ctx")
		if not (ctx11 is Dictionary):
			return []
		return AtxDuo.执行算子(运行, 表, 目标们)
	# ---------------- ★ A6c：响介 / 艾克赛琳 / 拉米亚（A1 / A2 / A3）v0.1 的精神牌 ----------------
	#   交给 `AtxThree.执行算子`。
	elif 名 == "atx3":
		var ctx12 = 运行.get("ctx")
		if not (ctx12 is Dictionary):
			return []
		return AtxThree.执行算子(运行, 表, 目标们)
	# ---------------- ★ CB-1：天人 v0.1（太阳炉 / 天人势力牌 / 拉塞 / TRANS-AM） ----------------
	#   并且队里得有天人成员（`CelestialV01.开` 自己判）。
	elif 名 == "cb":
		var ctx13 = 运行.get("ctx")
		if not (ctx13 is Dictionary) or not CelestialV01.开(ctx13):
			return []
		return CelestialV01.执行算子(运行, 表, 目标们)
	# ---------------- 殖民卫星军 / 月球王国 / 影世界的算子 ----------------
	#   派发走 `RuleHooks.执行算子`（模块返回非空摘要 = 认领这张牌）。
	elif 名 in ["colonial", "moon", "shadow"]:
		var ctx14 = 运行.get("ctx")
		if not (ctx14 is Dictionary):
			return []
		return RuleHooks.执行算子(名, 运行, 表, 目标们)
	else:
		push_error("CardEffects：未知的算子「%s」" % 名)
		return []
	return [_摘要(运行, 名, 目标们)]

## ★ MITH-1：「固定伤害」—— 直接扣血、**不消耗 ctx.rng**（方便确定性单元测试），也不走命中 / 暴击 / 减伤。
## 打死了照旧记一条攻击事件并走 `Fac.势力击破`。
static func _固定伤害(ctx: Variant, 目标: Dictionary, 值: float) -> float:
	if not (值 > 0.0) or float(目标.get("hp", 0.0)) <= 0.0:
		return 0.0
	var 前 := float(目标.hp)
	var 实 := minf(前, JsCompat.js_round(值))
	目标.hp = 前 - 实
	if ctx is Dictionary:
		var 字段: Dictionary = {
			"类型": "攻击", "单位": "", "目标": 目标.get("key"), "武器": "固定伤害", "伤害": 实, "命中": true,
			"固定伤害": true, "目标剩余HP": 目标.hp,
		}
		if 目标.get("side") != null and 目标.get("slot") != null:
			字段["目标方"] = 目标.side
			字段["目标位"] = 目标.slot
		Btl.pushLog(ctx, "〔固定伤害〕%s 受到 %d 点伤害（不掷命中 / 不消耗随机数）" % [str(目标.get("name", "")), int(实)], 字段)
		if 前 > 0.0 and float(目标.hp) <= 0.0:
			Fac.势力击破(ctx, null, 目标)
	return 实

static func _加计数(运行: Dictionary, 键: String, 加: float) -> void:
	var ctx = 运行.get("ctx")
	if not (ctx is Dictionary):
		return
	var 计 = ctx.get("战况计数")
	if not (计 is Dictionary):
		return
	计[键] = _数(计.get(键)) + 加

## F_CB_1 的 TRANS-AM 解放：直接按「激活 + 持续 N 回合」写势力状态
static func _激活势力状态(运行: Dictionary, u: Dictionary, 势力: String, 持续: float) -> void:
	var 状 := Fac.势力状态(u, 势力)
	var ctx = 运行.get("ctx")
	var 回合 := float(ctx.get("turn")) if (ctx is Dictionary and _真(ctx.get("turn"))) else 1.0
	状.激活 = true
	状.剩余回合 = 持续
	状.启动回合 = 回合
	状.结束回合 = 回合 + 持续

# ======================== 小工具（数值语义一律走 JsCompat） ========================
## ★ 2026-10-22（任务单 P3-4）：**不再写 `（0 台）` 这种空尾缀** ——
##   目标为空时只说「作用于：全场 / 无指定目标」，有目标时写清名字（超过 4 台才截断）。
static func _摘要(运行: Dictionary, 算子名: String, 目标们: Array) -> String:
	var 名们: Array = []
	for u in 目标们:
		if u is Dictionary:
			名们.append(String(u.get("name")))
	var 牌 = 运行.get("card")
	var 牌名 := String(牌.get("名")) if 牌 is Dictionary else ""
	if 名们.is_empty():
		return "【%s】%s → 作用于：全场（没有单独的指定目标）" % [牌名, 算子名]
	return "【%s】%s → 作用于【%s】" % [牌名, 算子名,
		"、".join(名们.slice(0, 4)) + ("…（共 %d 台）" % 名们.size() if 名们.size() > 4 else "")]

## 解析参数里的令牌：@源 → "卡牌:<id>"、@牌名 → 卡牌名；别的原样返回
static func _解令牌(运行: Dictionary, v: Variant) -> Variant:
	if v is String:
		if v == 令牌_源:
			return 运行.get("源")
		if v == 令牌_牌名:
			var 牌 = 运行.get("card")
			return String(牌.get("名")) if 牌 is Dictionary else ""
	return v

## JS 的 Number(v) || 0（数据里的这些字段要么是数、要么没有）
static func _数(v: Variant) -> float:
	if v is float or v is int:
		var f := float(v)
		return 0.0 if (is_nan(f) or f == 0.0) else f
	if v is bool:
		return 1.0 if v else 0.0
	if v is String or v is StringName:
		var s := String(v).strip_edges()
		return s.to_float() if s.is_valid_float() else 0.0
	return 0.0

## JS 真假（只覆盖这里用得到的类型；空字典 / 空数组在 JS 里为真）
static func _真(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is float or v is int:
		return float(v) != 0.0
	if v is String or v is StringName:
		return String(v) != ""
	return true

## J.sort 的等价物：稳定排序，返回排好序的新数组（原数组不动）
static func _稳定排序(arr: Array, 比较: Callable) -> Array:
	return JsCompat.stable_sort(arr, func(a, b): return float(比较.call(a, b)) < 0.0)

## J.inc 的等价物（容器按同一个对象算相等）
static func _含同物(arr: Array, v: Variant) -> bool:
	for x in arr:
		if is_same(x, v):
			return true
	return false

static func _排号(名: String) -> float:
	return Fm.ROW_FRONT if 名 == "front" else Fm.ROW_BACK

static func _势力(u: Dictionary) -> Variant:
	return Btl.提取单位三层信息(u).势力

static func _血比(u: Dictionary) -> float:
	return float(u.hp) / float(u.maxHp)

static func _回血(u: Dictionary, 比: float) -> void:
	u.hp = minf(float(u.maxHp), float(u.hp) + JsCompat.js_round(float(u.maxHp) * 比))
