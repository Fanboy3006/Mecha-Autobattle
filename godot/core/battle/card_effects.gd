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
## 语义与封存版 JS 参考版逐字一致（黄金样例里 32 张牌全部走到）；数值语义一律走 JsCompat，本文件不用 J.* 宏。
class_name CardEffects
extends RefCounted

const 令牌_源 := "@源"
const 令牌_牌名 := "@牌名"

const CARD_OPS: Dictionary = {
	# ---------------- 职业牌 ----------------
	"C_HEAVY_1": [
		{"选": {"方": "ally", "任一": [{"排": "front"}, {"职业": "重装"}]},
			"效果": [
				{"算子": "增益", "源": 令牌_源, "增益": {"def": 40.0, "剩余": 1.0}},
				{"算子": "护盾", "比": 0.15},
			]},
	],
	"C_HEAVY_2": [
		{"选": {"方": "ally", "取一": "重装否则最低血比"},
			"效果": [
				{"算子": "回血", "比": 0.25},
				{"算子": "增益", "源": 令牌_源, "增益": {"def": 30.0, "剩余": 2.0}},
			]},
	],
	"C_GUARD_1": [
		{"选": {"方": "ally", "职业": "近卫"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.35, "hit": 15.0, "剩余": 1.0}}]},
	],
	"C_GUARD_2": [
		{"选": {"方": "ally"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"meleeDmgMul": 0.20, "剩余": 1.0}}]},
		{"选": {"方": "ally", "职业": "近卫"},
			"效果": [{"算子": "减冷却", "值": 1.0}]},
	],
	"C_VANG_1": [
		{"选": {"方": "ally", "职业": "尖兵"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"eva": 25.0, "hit": 15.0, "crit": 15.0, "剩余": 1.0}}]},
	],
	"C_VANG_2": [
		{"选": {"方": "ally", "职业": "尖兵"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"crit": 35.0, "dmgMul": 0.20, "剩余": 1.0}}]},
	],
	"C_SNIPE_1": [
		{"选": {"方": "ally", "职业": "狙击"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"hit": 40.0, "crit": 20.0, "dmgMul": 0.20, "剩余": 1.0}}]},
	],
	"C_SNIPE_2": [
		{"选": {"方": "enemy", "有标定": true, "否则全体": true},
			"效果": [
				{"算子": "增益", "源": 令牌_源, "增益": {"def": -30.0, "剩余": 2.0}},
				{"算子": "标定", "层数": 3.0, "来源名": 令牌_牌名, "补满": true},
			]},
	],
	"C_CMD_1": [
		{"选": {"方": "ally"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"hit": 10.0, "剩余": 1.0}}]},
	],
	"C_CMD_2": [
		{"选": {"方": "enemy", "取一": "后排并最高血"},
			"效果": [
				{"算子": "标定", "层数": 1.0, "来源名": 令牌_牌名},
				{"算子": "增益", "源": 令牌_源, "增益": {"hit": -15.0, "剩余": 1.0}},
			]},
	],
	"C_SPEC_1": [
		{"选": {"方": "enemy"},
			"效果": [{"算子": "增益", "源": "卡牌扰乱", "增益": {"hit": -20.0, "turns": 1.0, "剩余": 1.0}}]},
	],
	"C_SPEC_2": [
		{"选": {"方": "enemy", "有标定": true, "否则全体": true},
			"效果": [{"算子": "增益", "源": "破甲引信", "增益": {"def": -25.0, "turns": 2.0, "剩余": 2.0}}]},
	],
	# ---------------- 势力牌 ----------------
	"F_SEED_1": [
		{"选": {"方": "ally", "任一": [{"势力": "卫星国防军"}, {"排": "front"}]},
			"效果": [{"算子": "护盾", "比": 0.15}]},
	],
	"F_SEED_2": [
		{"选": {"方": "ally", "势力": "卫星国防军"},
			"效果": [
				{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.30, "eva": 20.0, "剩余": 1.0}},
				{"算子": "减冷却", "值": 1.0},
			]},
	],
	"F_METEOR_1": [
		{"选": {"方": "ally", "势力": "流星小队"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"eva": 25.0, "dmg": 25.0, "剩余": 1.0}}]},
	],
	"F_METEOR_2": [
		{"选": {"方": "ally", "势力": "流星小队"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"crit": 30.0, "dmgMul": 0.30, "剩余": 1.0}}]},
	],
	"F_MOON_1": [
		{"选": {"方": "ally", "取一": "最低血比"},
			"效果": [{"算子": "回血", "比": 0.30}]},
	],
	"F_MOON_2": [
		{"选": {"方": "ally", "势力": "月球王国"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.25, "def": 20.0, "剩余": 1.0}}]},
	],
	"F_CB_1": [
		{"选": {"方": "ally", "势力": "天人"},
			"效果": [
				{"算子": "激活势力状态", "势力": "天人", "持续": 2.0},
				# 注意：封存版里这一句在 `if … and _是(u,"CB1")` **外面**（缩进与 if 齐平），
				# 所以增益给全部天人、只有「计数」限 CB1 —— 别照着注释「顺眼」挪进 if 里。
				{"算子": "增益", "源": 令牌_源, "增益": {"eva": 15.0, "dmgMul": 0.30, "剩余": 2.0}},
			]},
		{"选": {"方": "ally", "势力": "天人", "键": "CB1", "要战况计数": true},
			"效果": [{"算子": "计数", "键": "刹那命中或TA", "加": 1.0}]},
	],
	"F_CB_2": [
		{"选": {"方": "ally", "势力": "天人"},
			"效果": [
				{"算子": "护盾", "比": 0.25},
				{"算子": "减冷却", "值": 1.0},
			]},
	],
	"F_ATX_1": [
		{"选": {"方": "ally", "势力": "ATX"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"eva": 25.0, "crit": 20.0, "剩余": 1.0}}]},
	],
	"F_ATX_2": [
		{"选": {"方": "ally"},
			"效果": [
				{"算子": "减冷却", "值": 2.0},
				{"算子": "增益", "源": 令牌_源, "增益": {"hit": 25.0, "剩余": 1.0}},
			]},
	],
	"F_MITH_1": [
		{"选": {"方": "ally", "势力": "秘银"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"eva": 25.0, "hit": 15.0, "剩余": 1.0}}]},
	],
	"F_MITH_2": [
		{"选": {"方": "ally", "势力": "秘银"},
			"效果": [{"算子": "增益", "源": 令牌_源, "增益": {"dmgMul": 0.25, "剩余": 1.0}}]},
		{"选": {"方": "enemy"},
			"效果": [{"算子": "标定", "层数": 1.0, "来源名": 令牌_牌名}]},
	],
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
	var 组们 = CARD_OPS.get(String(card.get("id")))
	if not (组们 is Array):
		return 摘要
	for 组 in 组们:
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
	else:
		push_error("CardEffects：未知的算子「%s」" % 名)
		return []
	return [_摘要(运行, 名, 目标们)]

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
static func _摘要(运行: Dictionary, 算子名: String, 目标们: Array) -> String:
	var 名们: Array = []
	for u in 目标们:
		if u is Dictionary:
			名们.append(String(u.get("name")))
	var 牌 = 运行.get("card")
	var 牌名 := String(牌.get("名")) if 牌 is Dictionary else ""
	return "【%s】%s → %s（%d 台）" % [牌名, 算子名, "、".join(名们.slice(0, 4)) + ("…" if 名们.size() > 4 else ""), 名们.size()]

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
