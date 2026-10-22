## 职责：殖民卫星军七名成员的卡池（`data/cards/殖民卫星军.json` 的「驾驶员」）与独有机制（METEOR 锁定链 / 斩首 / 贯穿一列 / 自爆装置 / 精神牌算子）。
## 约定：卡表只读 `Db.T.卡包`；觉醒状态在 `ColonialAwaken`，感应牌库与势力牌在 `ColonialDeck`。
class_name ColonialUnits
extends RefCounted

const 势力 := "殖民卫星军"
## 施工单 §1.1 的五人 + COL-MOOK-1 两名大众脸（W4 / W5 重用退役空号，没有觉醒）。
const 成员键: Array = ["S1", "S2", "W1", "W2", "W3", "W4", "W5"]
const 名字 := {"S1": "拉克丝", "S2": "卡嘉莉", "W1": "希罗", "W2": "迪奥", "W3": "特洛瓦", "W4": "卡特尔", "W5": "五飞"}
const 职业 := {"S1": "特种", "S2": "指挥", "W1": "狙击", "W2": "近卫", "W3": "重装", "W4": "尖兵", "W5": "特种"}
## 觉醒类型（没有 = 永远是燃料）。
const 觉醒 := {"S1": ColonialAwaken.SEED, "W1": ColonialAwaken.ZERO, "W2": ColonialAwaken.隐身}
## 获取档 → 解锁等级（与秘银 v0.3 同一口径：初始 10 / 剧情 20 / 肉鸽 30）。
const 档位 := {"初始": 10, "剧情": 20, "肉鸽三选一": 30}
## METEOR 锁定链：默认最多锁 3 台（「永恒号支援」提到 4）。
const METEOR默认上限 := 3

static func 键(u: Variant) -> String:
	return ColonialAwaken.键(u)

static func 是(u: Variant, 键名: String) -> bool:
	return 键(u) == 键名 and ColonialAwaken.是殖民卫星军(u)

# ---- 一、卡表（JSON → 卡字典）----
static func _武(名: String, 参: Dictionary) -> Dictionary:
	var w := {
		"name": 名, "fire": str(J.or_(参.get("类型"), "direct")),
		"power": float(J.or_(参.get("威力"), 1000.0)), "hit": float(J.or_(参.get("命中"), 100.0)),
		"critMod": float(J.or_(参.get("暴击"), 0.0)), "stat": str(J.or_(参.get("属性"), "射击")),
		"dmgType": str(J.or_(参.get("伤害"), "光束")), "cd": 0.0, "uses": null,
		"unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null,
		"area": str(J.or_(参.get("area"), "single")),
		"距离": J.or_(参.get("距离"), [1, 6]),
	}
	var 段 := int(J.num0(参.get("段数")))
	if 段 > 1:
		w["hits"] = float(段)
		w["special"] = "multi"
	if J.truthy(参.get("散布")):
		w["散布"] = true
	if J.truthy(参.get("无视遮挡")):
		w["ignore_block"] = true
	if J.truthy(参.get("无视前排")):
		w["无视前排"] = true
	if J.truthy(参.get("必中")):
		w["必中"] = true
	if J.truthy(参.get("必暴")):
		w["必暴"] = true
		w["必中可暴击"] = true
		w["critMod"] = 100.0
	if 参.get("穿甲倍率") != null:
		w["pierce_mul"] = float(参.get("穿甲倍率"))
	if 参.get("斩首") != null:
		w["斩首"] = float(参.get("斩首"))
	if 参.get("命中后减敌闪避") != null:
		w["命中后减敌闪避"] = float(参.get("命中后减敌闪避"))
	if 参.get("命中后减敌命中") != null:
		w["命中后减敌命中"] = float(参.get("命中后减敌命中"))
	if J.truthy(参.get("敌闪避减半")):
		w["敌闪避减半"] = true
	if 参.get("连带冷却") != null:
		w["连带冷却"] = str(参.get("连带冷却"))
	if 参.get("依赖未冷却") != null:
		w["依赖未冷却"] = str(参.get("依赖未冷却"))
	return w

static func _合并加号(条目: Dictionary, 加号: bool) -> Dictionary:
	var 出 := 条目.duplicate(true)
	出.erase("+")
	var 覆盖 = 条目.get("+")
	if 加号 and 覆盖 is Dictionary:
		for k in (覆盖 as Dictionary).keys():
			出[k] = (覆盖 as Dictionary)[k]
	# 武器参里的 `+` 与顶层的 `+` 同一口径（`威力` / `段数` / `距离` / `穿甲倍率`…）。
	var 参 = 出.get("武器参")
	var 有加 := 条目.has("+")
	if 加号 and 参 is Dictionary and (参 as Dictionary).get("+") is Dictionary:
		var 新参: Dictionary = (参 as Dictionary).duplicate(true)
		var 加参: Dictionary = (参 as Dictionary).get("+")
		新参.erase("+")
		for k2 in 加参.keys():
			新参[k2] = 加参[k2]
		出["武器参"] = 新参
		有加 = true
	出["_加号"] = 加号 and 有加
	return 出

static func _卡(键名: String, 条目: Dictionary) -> Dictionary:
	var 获取 := str(J.or_(条目.get("获取"), "初始"))
	var 卡 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": str(条目.get("卡类", "专属精神牌")), "类型": "战术", "层级": "角色", "种类": "角色",
		"归属": 键名, "角色": 键名, "角色们": [键名], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0,
		"冷却": float(J.or_(条目.get("冷却"), 0.0)), "回库": false, "衍生": false,
		"入库条件": (条目.get("入库条件") as Dictionary) if 条目.get("入库条件") is Dictionary else null,
		"获取": 获取, "等级需求": int(J.or_(条目.get("等级需求"), 档位.get(获取, 10))),
		"效果说明": str(条目.get("效果说明", "")), "效果": [],
		"武器牌": J.truthy(条目.get("武器牌")), "连携": false,
		"觉醒感应": J.truthy(条目.get("觉醒感应")),
		"感应放入": str(J.or_(条目.get("感应放入"), "")),
		"角色所属势力": 势力,
	}
	if J.truthy(条目.get("不销毁主武器")):
		卡["不被销毁"] = true

	for k in 条目.keys():
		if k in ["id", "名", "卡类", "耗气", "冷却", "获取", "等级需求", "入库条件", "效果说明", "武器参", "+", "_加号"]:
			continue
		if 条目[k] is Array or 条目[k] is Dictionary:
			卡[k] = 条目[k].duplicate(true)
		else:
			卡[k] = 条目[k]
	var 参 = 条目.get("武器参")
	if 参 is Dictionary:
		卡["武器"] = _武(str(条目.get("名", "")), 参)
		if 参.get("冷却") != null:
			卡["冷却"] = float(参.get("冷却"))
	# 精神牌 / 大招的「动作」→ `CardEffects` 的一组算子（参数原样带过去）。
	var 动作 := str(条目.get("动作", ""))
	if 动作 != "":
		var 表 := {"算子": "colonial", "动作": 动作}
		for k3 in 条目.keys():
			if k3 in ["id", "名", "卡类", "耗气", "冷却", "获取", "等级需求", "入库条件", "效果说明",
				"武器参", "+", "_加号", "动作", "目标", "觉醒感应", "感应放入", "武器牌",
				"每场一次", "需要觉醒", "结束觉醒", "不销毁主武器"]:
				continue
			表[k3] = 条目[k3]
		卡["效果"] = [{"选": {"方": "enemy" if str(条目.get("目标", "")) == "敌机" else "ally"},
			"效果": [表]}]
	if J.truthy(条目.get("_加号")):
		卡["名"] = str(卡.get("名", "")) + "+"
		卡["加号"] = true
	return 卡

static var _表: Array = []
static var _代: int = -1

## 全卡池（`+` 版不在里面）。
static func 卡表() -> Array:
	if _代 != Db.代:
		var 出: Array = []
		var 包: Variant = ColonialDeck.卡包().get("驾驶员")
		for 键名 in 成员键:
			var 条们: Variant = (包 as Dictionary).get(键名) if 包 is Dictionary else null
			for 条目 in (条们 as Array) if 条们 is Array else []:
				if 条目 is Dictionary:
					出.append(_卡(键名, 条目))
		_表 = 出
		_代 = Db.代
	return _表

## 某人的全卡池（`+` 版按 `加号` 生成、名字带 `+`）。
static func 角色牌们(键名: String, 加号: bool = false) -> Array:
	var 出: Array = []
	var 包: Variant = ColonialDeck.卡包().get("驾驶员")
	var 条们: Variant = (包 as Dictionary).get(键名) if 包 is Dictionary else null
	for 条目 in (条们 as Array) if 条们 is Array else []:
		if not (条目 is Dictionary):
			continue
		var 合 := _合并加号(条目, 加号)
		出.append(_卡(键名, 合))
	return 出

## 装填：按等级装「已经解锁」的卡（`+` 版 Lv20 起）。
static func 装填单位(u: Variant, 等级: int, _ctx: Variant) -> Array:
	var 出: Array = []
	if not (u is Dictionary) or not ColonialAwaken.是殖民卫星军(u):
		return 出
	var 键名 := 键(u)
	if not 成员键.has(键名):
		return 出
	var 加号 := 等级 >= 20
	for c in 角色牌们(键名, false):
		if 等级 >= int(c.get("等级需求", 10)):
			var 新: Dictionary = c.duplicate(true)
			if 加号:
				var 升级 := 角色牌们(键名, true).filter(func(x): return str(x.get("id")) == str(c.get("id")))
				if not 升级.is_empty():
					新 = (升级[0] as Dictionary).duplicate(true)
			出.append(新)
	return 出

## 这副牌里有没有这张（按 id）。
static func 有卡(u: Variant, id: String) -> bool:
	if not (u is Dictionary):
		return false
	for c in J.or_((u as Dictionary).get("专属牌库"), []):
		if c is Dictionary and str(c.get("id", "")) == id:
			return true
	return false

# ---- 二、规则钩子的实现体（由 `ColonialV01` 转发）----
## 【命中修正】：「下张武器」的命中与代价、本回合命中罚、【干扰器扩散】。
static func 命中修正(att: Variant, def: Variant, w: Variant, _ctx: Variant) -> float:
	var 修 := 0.0
	if att is Dictionary:
		var 下 = (att as Dictionary).get("下张武器")
		if 下 is Dictionary and _带武器(w):
			修 += float(J.num0((下 as Dictionary).get("命中")))
		修 += float(J.num0((att as Dictionary).get("殖民命中罚")))
	if def is Dictionary:
		修 -= float(J.num0((def as Dictionary).get("干扰器命中罚")))
	return 修

## 【闪避加成】：本回合闪避罚 / 超级 DRAGOON 的「每段目标闪避减半」。
static func 闪避加成(def: Variant, ctx: Variant) -> float:
	if not (def is Dictionary):
		return 0.0
	var 修 := float(J.num0((def as Dictionary).get("殖民闪避罚")))
	if not (ctx is Dictionary) or not J.truthy((ctx as Dictionary).get("_本发敌闪避减半")):
		return 修
	return 修 - J.round((float((def as Dictionary).get("eva", 0.0)) + Calc.buffSum(def, "eva")) / 2.0)

## 【攻方伤害倍率】：「下张武器」的伤害乘、「我要杀了你」、命中后让目标下阶段攻击 −X%。
static func 攻方伤害倍率(_ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	var 倍 := 1.0
	if not (att is Dictionary) or not _带武器(w):
		return 倍
	var 下 = (att as Dictionary).get("下张武器")
	if 下 is Dictionary:
		var 乘 := float(J.num0((下 as Dictionary).get("伤害乘")))
		if 乘 > 0.0 and absf(乘 - 1.0) > 0.0001:
			倍 *= 乘
		var 低 := float(J.num0((下 as Dictionary).get("对低血伤增")))
		if 低 > 0.0 and def is Dictionary \
			and float((def as Dictionary).get("hp", 0.0)) * 100.0 <= float((def as Dictionary).get("maxHp", 0.0)) * 50.0:
			倍 *= 1.0 + 低
	var 锁 := str((att as Dictionary).get("锁定目标", ""))
	if 锁 != "" and def is Dictionary:
		倍 *= (1.0 + float(J.num0((att as Dictionary).get("锁定加成")))) if str((def as Dictionary).get("key", "")) == 锁 \
			else (1.0 - float(J.num0((att as Dictionary).get("锁定他减"))))
	var 罚 := float(J.num0((att as Dictionary).get("攻击伤害罚")))
	if 罚 > 0.0:
		倍 *= maxf(0.0, 1.0 - 罚)
	return 倍

## 【受方伤害倍率】：`u.减伤` 里按类别记的减伤（物理 / 直射 / 光束 / 全）；卡嘉莉的光束反射装甲 −50%。
static func 受方伤害倍率(def: Variant, w: Variant) -> float:
	if not (def is Dictionary) or not (w is Dictionary):
		return 1.0
	var 倍 := 1.0
	if 是(def, "S2") and str((w as Dictionary).get("dmgType", "")) == "光束":
		倍 *= 0.5
	var 表 = (def as Dictionary).get("减伤")
	if not (表 is Dictionary):
		return 倍
	if float(J.num0((表 as Dictionary).get("全"))) > 0.0:
		倍 *= maxf(0.0, 1.0 - float((表 as Dictionary).get("全")))
	if str((w as Dictionary).get("dmgType", "")) == "物理":
		倍 *= maxf(0.0, 1.0 - float(J.num0((表 as Dictionary).get("物理"))))
	if str((w as Dictionary).get("dmgType", "")) == "光束":
		倍 *= maxf(0.0, 1.0 - float(J.num0((表 as Dictionary).get("光束"))))
	if Reach.rangeKindOf(w) == Reach.KIND_DIRECT():
		倍 *= maxf(0.0, 1.0 - float(J.num0((表 as Dictionary).get("直射"))))
	return 倍

## 【受击后】：卡嘉莉被**直射光束**命中 → 把减掉那部分的一半反射给攻击者。
static func 受击后(ctx: Dictionary, def: Dictionary, att: Variant, 实受: float, w: Variant) -> void:
	if not 是(def, "S2") or not (att is Dictionary) or 实受 <= 0.0:
		return
	if not (w is Dictionary) or str((w as Dictionary).get("dmgType", "")) != "光束":
		return
	if Reach.rangeKindOf(w) != Reach.KIND_DIRECT():
		return
	if float((att as Dictionary).get("hp", 0.0)) <= 0.0:
		return
	var 反 := J.round(实受 * 0.5)
	if 反 <= 0.0:
		return
	(att as Dictionary)["hp"] = maxf(0.0, float((att as Dictionary).get("hp", 0.0)) - 反)
	Btl.pushLog(ctx, "〔光束反射〕%s 把 %s 点光束伤害反射给 %s" % [str(def.get("name", "")), J.s(反),
		str((att as Dictionary).get("name", ""))],
		J.merged(J.merged({"类型": "光束反射", "反射": 反}, Btl.谁(def)), Btl.谁目标(att)))
	if float((att as Dictionary).get("hp", 0.0)) <= 0.0:
		Btl.记击破(ctx, def, att)

## 【暴击修正】：迪奥【死神】—— 打 HP ≤ 50% 的目标暴击 +20。
static func 暴击修正(att: Variant, def: Variant, w: Variant, _ctx: Variant) -> float:
	var 修 := 0.0
	if 是(att, "W2") and def is Dictionary and _带武器(w) \
		and float((def as Dictionary).get("hp", 0.0)) * 100.0 <= float((def as Dictionary).get("maxHp", 0.0)) * 50.0:
		修 += 20.0
	return 修

## 【武器攻击后】：斩首 / 命中后减敌闪避·命中 / 连带冷却（每次攻击 × 每个目标都会来）。
static func 武器攻击后(ctx: Dictionary, _att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if not (def is Dictionary) or not (w is Dictionary):
		return
	var 段 := float(J.num0(landed))
	if 段 <= 0.0:
		return
	var 闪 := float(J.num0((w as Dictionary).get("命中后减敌闪避")))
	if 闪 > 0.0:
		Btl.换同源增益(def, "武装损伤", {"eva": -闪, "剩余": 1.0})
	var 命 := float(J.num0((w as Dictionary).get("命中后减敌命中")))
	if 命 > 0.0:
		Btl.换同源增益(def, "武装损伤", {"hit": -命, "剩余": 1.0})
	var 斩 := float(J.num0((w as Dictionary).get("斩首")))
	if 斩 > 0.0 and not J.truthy((def as Dictionary).get("不杀中")):
		var 后 := float((def as Dictionary).get("hp", 0.0))
		var 上 := float((def as Dictionary).get("maxHp", 0.0))
		if 后 > 0.0 and 后 <= 上 * 斩:
			(def as Dictionary)["hp"] = 0.0
			Btl.pushLog(ctx, "〔斩首〕%s 剩余 HP 已低于 %d%% → 直接击破（剩 %s / %s）" % [
				str((def as Dictionary).get("name", "")), int(斩 * 100.0), J.s(后), J.s(上)],
				J.merged({"类型": "斩首", "目标": (def as Dictionary).get("key"), "斩首": 斩}, Btl.谁目标(def)))
			Btl.记击破(ctx, _att if _att is Dictionary else null, def)

## 【致命保留_后】：麦斯威尔教会的十字架（每场一次，第一次致命保留 1 HP）。
static func 致命保留_后(ctx: Variant, _att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return
	if not J.truthy((def as Dictionary).get("十字架")):
		return
	if float((def as Dictionary).get("hp", 0.0)) > 0.0:
		return
	(def as Dictionary)["hp"] = 1.0
	(def as Dictionary).erase("十字架")
	Btl.pushLog(ctx, "〔麦斯威尔教会的十字架〕%s 保留 1 HP（这一场只有这一次）" % str((def as Dictionary).get("name", "")),
		J.merged({"类型": "十字架", "保留": 1.0}, Btl.谁(def)))

## 【牌打出后】：武器离手 →「下张武器」的一次性加成消费掉。
static func 牌打出后(_ctx: Dictionary, u: Dictionary, _卡: Dictionary, 区: String) -> void:
	if not (u is Dictionary):
		return
	if [CardPlay.区_主武器, CardPlay.区_副武器, CardPlay.区_大招槽].has(区):
		(u as Dictionary).erase("下张武器")

## 【我方阶段初_后】：一次性状态收尾（减伤 / 命中罚 / 锁定目标 / 伏笔）。
static func 阶段初(ctx: Dictionary) -> void:
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		u.erase("减伤")
		u.erase("殖民命中罚")
		u.erase("殖民闪避罚")
		u.erase("干扰器命中罚")
		u.erase("锁定目标")
		u.erase("锁定加成")
		u.erase("锁定他减")
		u.erase("攻击伤害罚")
		u.erase("本回合不能打武器")
		u.erase("破隐降费")
		u.erase("METEOR上限")
	for e in J.or_(ctx.get("enemies"), []):
		if e is Dictionary:
			e.erase("攻击伤害罚")

# ---- 三、精神牌算子（`CardEffects` 的 `"colonial"` 分支转进来）----
static func 执行算子(_名: String, 运行: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	var ctx: Dictionary = 运行.get("ctx") if 运行.get("ctx") is Dictionary else {}
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 动作 := str(表.get("动作", ""))
	var 自己 = _施放者(ctx)
	var 友 = _友(ctx, 目标们)
	var 敌 = _敌(ctx, 目标们)
	var 牌名 := str(卡.get("名", ""))
	# 代价（闪避 / 命中 / 距离上限）：一次性，`我方阶段初_后` 收尾。
	var 代价 = 表.get("代价减伤")
	if 代价 is Dictionary and 自己 != null:
		if (代价 as Dictionary).get("命中") != null:
			自己["殖民命中罚"] = float(J.num0(自己.get("殖民命中罚"))) + float(代价["命中"])
		if (代价 as Dictionary).get("闪避") != null:
			自己["殖民闪避罚"] = float(J.num0(自己.get("殖民闪避罚"))) + float(代价["闪避"])
		if (代价 as Dictionary).get("距离上限") != null:
			自己["v3距离上限加"] = int(J.num0(代价["距离上限"]))
	match 动作:
		"战意":
			if 自己 == null:
				return []
			_加战意(ctx, 自己, float(J.num0(表.get("值"))), 牌名)
			return ["战意 +%d → %s" % [int(J.num0(表.get("值"))), _名(自己)]]
		"友军战意":
			if 友 == null:
				return []
			_加战意(ctx, 友, float(J.num0(表.get("值"))), 牌名)
			return ["战意 +%d → %s" % [int(J.num0(表.get("值"))), _名(友)]]
		"增益":
			var 目 = 友 if J.truthy(表.get("友方目标")) else 自己
			if 目 == null:
				return []
			var 增: Dictionary = 表.get("增益") if 表.get("增益") is Dictionary else {}
			Btl.换同源增益(目, "殖民卫星军:%s" % 牌名, 增)
			_记(ctx, 牌名, 目, Btl._增益摘要(增))
			return ["增益 → %s" % _名(目)]
		"队友增益":
			var 台们: Array = []
			for a in J.or_(ctx.get("allies"), []):
				if a is Dictionary and not is_same(a, 自己) and float((a as Dictionary).get("hp", 0.0)) > 0.0 \
					and ColonialAwaken.是殖民卫星军(a):
					Btl.换同源增益(a, "殖民卫星军:%s" % 牌名, 表.get("增益") if 表.get("增益") is Dictionary else {})
					台们.append(_名(a))
			_记(ctx, 牌名, null, "其他成员闪避 +15：%s" % ("、".join(台们) if not 台们.is_empty() else "没有其他成员"))
			return ["队友增益：%s" % "、".join(台们)]
		"下张武器":
			if 自己 == null:
				return []
			自己["下张武器"] = {"命中": float(J.num0(表.get("命中"))), "暴击": float(J.num0(表.get("暴击"))),
				"伤害乘": float(J.or_(表.get("伤害乘"), 1.0)), "对低血伤增": float(J.num0(表.get("对低血伤增")))}
			if float(J.num0(表.get("敌伤减"))) > 0.0:
				自己["敌伤减"] = float(J.num0(表.get("敌伤减")))
			_记(ctx, 牌名, 自己, "下一张武器牌命中 +%d" % int(J.num0(表.get("命中"))))
			return ["下一张武器牌加成 → %s" % _名(自己)]
		"抽精神":
			if 自己 == null:
				return []
			var 抽 := Setup.抽专属牌(自己, int(J.num0(表.get("张数"))))
			_记(ctx, 牌名, 自己, "抽 %d 张精神牌" % 抽.size())
			return ["抽 %d 张精神牌 → %s" % [抽.size(), _名(自己)]]
		"抽公有":
			var 抽2 := Setup.抽公有牌(ctx, int(J.num0(表.get("张数"))))
			_记(ctx, 牌名, null, "抽 %d 张公有牌" % 抽2.size())
			return ["抽 %d 张公有牌" % 抽2.size()]
		"减伤":
			if 自己 == null:
				return []
			var 目2 = 友 if J.truthy(表.get("友方目标")) else 自己
			if 目2 == null:
				return []
			if not ((目2 as Dictionary).get("减伤") is Dictionary):
				(目2 as Dictionary)["减伤"] = {}
			var 类 := str(J.or_(表.get("类别"), "全"))
			(目2 as Dictionary).减伤[类] = maxf(float(J.num0((目2 as Dictionary).减伤.get(类))), float(J.num0(表.get("值"))))
			_记(ctx, 牌名, 目2, "%s 伤害 −%d%%（到下个我方阶段前）" % [类, int(J.num0(表.get("值")) * 100.0)])
			return ["%s 伤害 −%d%% → %s" % [类, int(J.num0(表.get("值")) * 100.0), _名(目2)]]
		"标记":
			if 自己 == null:
				return []
			var 键2 := str(表.get("键", ""))
			自己[键2] = 表.get("值")
			_记(ctx, 牌名, 自己, "标记 %s" % 键2)
			return ["标记 %s → %s" % [键2, _名(自己)]]
		"锁定目标":
			if 自己 == null or 敌 == null:
				return []
			自己["锁定目标"] = str((敌 as Dictionary).get("key", ""))
			自己["锁定加成"] = float(J.num0(表.get("值")))
			自己["锁定他减"] = float(J.num0(表.get("减")))
			_记(ctx, 牌名, 敌, "本回合打它伤害 +%d%%，打其他目标 −%d%%" % [
				int(J.num0(表.get("值")) * 100.0), int(J.num0(表.get("减")) * 100.0)])
			return ["锁定 %s" % _名(敌)]
		"零的预见":
			if 自己 == null:
				return []
			自己["零的预见层数"] = 1.0
			_记(ctx, 牌名, 自己, "到下个我方阶段前第一次被攻击整次打空")
			return ["零的预见 → %s" % _名(自己)]
		"自损":
			if 自己 == null:
				return []
			var 失 := J.round(float((自己 as Dictionary).get("maxHp", 0.0)) * float(J.num0(表.get("比"))))
			var 后 := maxf(1.0, float((自己 as Dictionary).get("hp", 0.0)) - 失)
			(自己 as Dictionary)["hp"] = 后
			_记(ctx, 牌名, 自己, "失去 %s HP（剩 %s）" % [J.s(失), J.s(后)])
			if 表.get("增益") is Dictionary:
				Btl.换同源增益(自己, "殖民卫星军:%s" % 牌名, 表.get("增益"))
			ColonialAwaken.检查系统拒绝(ctx, 自己)
			return ["自损 %s → %s" % [J.s(失), _名(自己)]]
		"压住ZERO":
			if 自己 == null:
				return []
			自己["下回合免精神负担"] = true
			自己["ZERO暴伤压制"] = true
			ColonialAwaken.摘ZERO暴伤(自己)
			_记(ctx, 牌名, 自己, "下个我方阶段不扣精神负担；本回合 ZERO 暴伤 ×2.5 失效")
			return ["压住 ZERO → %s" % _名(自己)]
		"自爆装置":
			if 自己 == null:
				return []
			return _自爆装置(ctx, 自己, 牌名)
		"干扰器":
			if 友 == null:
				return []
			(友 as Dictionary)["干扰器命中罚"] = float(J.num0(表.get("值")))
			_记(ctx, 牌名, 友, "到下个我方阶段前敌方单体攻击打它命中 −%d" % int(J.num0(表.get("值"))))
			return ["干扰器 → %s" % _名(友)]
		"破隐降费":
			if 自己 == null:
				return []
			自己["破隐降费"] = float(J.num0(表.get("值")))
			_记(ctx, 牌名, 自己, "本回合破隐一击 / 死神的收割费用 −%d" % int(J.num0(表.get("值"))))
			return ["破隐降费 → %s" % _名(自己)]
		"再次潜伏":
			if 自己 == null:
				return []
			var 槽 := ColonialAwaken.入场槽(自己, ColonialAwaken.隐身)
			if not 槽.is_empty():
				槽["cd"] = 0.0
			var 失2 := J.round(float((自己 as Dictionary).get("maxHp", 0.0)) * float(J.num0(表.get("比"))))
			(自己 as Dictionary)["hp"] = maxf(1.0, float((自己 as Dictionary).get("hp", 0.0)) - 失2)
			_记(ctx, 牌名, 自己, "入场牌冷却清零；失去 %s HP" % J.s(失2))
			return ["再次潜伏 → %s" % _名(自己)]
		"METEOR锁定":
			return METEOR锁定(ctx, 自己, 敌, 牌名)
		"METEOR发射":
			return METEOR发射(ctx, 自己, 牌名)
	return []

## 自爆装置：HP 变 1，对同列敌方前后两格造成「失去的 HP」等量物理伤害（必中）。
static func _自爆装置(ctx: Dictionary, u: Dictionary, 牌名: String) -> Array:
	var 失 := maxf(0.0, float(u.get("hp", 0.0)) - 1.0)
	var 列 := Fm.colOfSlot(float(u.get("slot", 0.0)))
	var 目标们: Array = []
	for e in Units.livingOf("enemy", ctx):
		if e is Dictionary and Fm.colOfSlot(float((e as Dictionary).get("slot", 0.0))) == 列:
			目标们.append(e)
	u["hp"] = 1.0
	u["下回合主武器销毁"] = true
	var 打: Array = []
	for e in 目标们:
		var 前 := float((e as Dictionary).get("hp", 0.0))
		(e as Dictionary)["hp"] = maxf(0.0, 前 - 失)
		打.append("%s −%s" % [_名(e), J.s(失)])
		if 前 > 0.0 and float((e as Dictionary).get("hp", 0.0)) <= 0.0:
			Btl.记击破(ctx, u, e)
	ColonialAwaken.检查系统拒绝(ctx, u)
	Btl.pushLog(ctx, "〔自爆装置〕%s HP → 1，同列敌方 %s 各受 %s 物理伤害" % [str(u.get("name", "")),
		("、".join(打) if not 打.is_empty() else "（同列没有敌机）"), J.s(失)],
		J.merged({"类型": "自爆装置", "伤害": 失, "目标们": 目标们.map(func(x): return (x as Dictionary).get("key"))}, Btl.谁(u)))
	return 打

# ---- 四、METEOR 锁定链（临时武器牌走换装栈，来源 `"METEOR"`）----
static func _上限(u: Dictionary) -> int:
	return int(J.num0(u.get("METEOR上限"))) if J.num0(u.get("METEOR上限")) > 0.0 else METEOR默认上限

static func _临时锁定卡(n: int) -> Dictionary:
	return {"id": "COL_S1_TEMP_LOCK%d" % n, "名": "锁定 %d" % n, "卡类": "主武器卡", "类型": "战术",
		"层级": "角色", "种类": "角色", "归属": "S1", "角色": "S1", "角色们": ["S1"], "占行动": [],
		"耗气": 5.0, "回气": 0.0, "限次": 99.0, "冷却": 0.0, "回库": false, "衍生": false,
		"入库条件": null, "获取": "初始", "等级需求": 10, "武器牌": false, "连击": false,
		"不被销毁": true,
		"效果说明": "再锁定 1 台敌机（距离 1–6，可重复锁同一台）。",
		"效果": [{"选": {"方": "enemy"}, "效果": [{"算子": "colonial", "动作": "METEOR锁定", "第几": n}]}]}

static func 发射卡() -> Dictionary:
	return {"id": "COL_S1_TEMP_FIRE", "名": "发射", "卡类": "主武器卡", "类型": "战术",
		"层级": "角色", "种类": "角色", "归属": "S1", "角色": "S1", "角色们": ["S1"], "占行动": [],
		"耗气": 0.0, "回气": 0.0, "限次": 99.0, "冷却": 0.0, "回库": false, "衍生": false,
		"入库条件": null, "获取": "初始", "等级需求": 10, "武器牌": false, "连击": false,
		"不被销毁": true,
		"效果说明": "按锁定顺序逐发攻击（直射 · 光束 2200 · 无视遮挡）；QTE 只判定一次。",
		"效果": [{"选": {"方": "ally"}, "效果": [{"算子": "colonial", "动作": "METEOR发射"}]}]}

static func METEOR锁定(ctx: Dictionary, u: Variant, 敌: Variant, 牌名: String) -> Array:
	if not (u is Dictionary) or not (敌 is Dictionary):
		return ["METEOR 锁定：没有目标"]
	if not ((u as Dictionary).get("METEOR锁定") is Array):
		(u as Dictionary)["METEOR锁定"] = []
	var 锁: Array = (u as Dictionary).METEOR锁定
	var 键 := str((敌 as Dictionary).get("key", ""))
	if 锁.size() < _上限(u):
		锁.append(键)
	Btl.pushLog(ctx, "〔METEOR〕%s 锁定 %s（第 %d 台）" % [str(u.get("name", "")), _名(敌), 锁.size()],
		J.merged({"类型": "METEOR锁定", "目标": 键, "锁定数": 锁.size()}, Btl.谁(u)))
	# 压栈：武器栏换成「锁定 n+1」「发射」
	var 新表: Array = []
	if 锁.size() + 1 <= _上限(u):
		新表.append(_临时锁定卡(锁.size() + 1))
	新表.append(发射卡())
	DeckFlow.弹栈武器栏(u, "METEOR")
	DeckFlow.压栈武器栏(u, 新表, "METEOR", false, ctx)
	return ["锁定 %s（第 %d 台）" % [_名(敌), 锁.size()]]

## 发射：QTE 判定一次 → 按锁定顺序逐发攻击（目标已死则同排转火，再不行打任意存活敌机）。
static func METEOR发射(ctx: Dictionary, u: Variant, _牌名: String, 指定结果: String = "") -> Array:
	if not (u is Dictionary):
		return []
	var 锁: Array = J.or_((u as Dictionary).get("METEOR锁定"), [])
	if 锁.is_empty():
		return ["METEOR：没有锁定的目标"]
	var 假卡 := {"id": "COL_S1_TEMP_FIRE", "名": "发射", "武器牌": true}
	var QTE := ColonialAwaken.取QTE结果(ctx, u, 假卡, 指定结果)
	ColonialAwaken.开QTE(ctx, u, QTE)
	var 打: Array = []
	for 键 in 锁:
		var 目标 = _转火(ctx, u, str(键))
		if 目标 == null:
			continue
		var w := {"name": "METEOR 光束", "fire": "direct", "dmgType": "光束", "stat": "射击",
			"power": 2200.0, "hit": 100.0, "critMod": 0.0, "hits": 1.0, "cd": 0.0, "uses": null,
			"unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null, "area": "single",
			"ignore_block": true, "距离": [1, 6], "无反击": true}
		var 果 := Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, (目标 as Dictionary).get("key"))
		打.append("%s −%s" % [_名(目标), J.s(J.num0(果.get("击破"))) if J.num0(果.get("击破")) > 0.0 else "命中"])
		Btl.换同源增益(目标, "武装损伤", {"hit": -20.0, "剩余": 1.0})
	ColonialAwaken.清QTE(ctx)
	DeckFlow.弹栈武器栏(u, "METEOR")
	(u as Dictionary).erase("METEOR锁定")
	Btl.pushLog(ctx, "〔METEOR〕%s 发射 %d 发（QTE·%s）：%s" % [str(u.get("name", "")), 锁.size(),
		ColonialAwaken._档名(QTE), "、".join(打)],
		J.merged({"类型": "METEOR发射", "发数": 锁.size(), "QTE": QTE}, Btl.谁(u)))
	return 打

## 目标已阵亡 → 同排存活敌机 → 任意存活敌机（默认规则 3：不浪费弹药）。
static func _转火(ctx: Dictionary, u: Dictionary, 键: String) -> Variant:
	var 活 := Units.livingOf("enemy", ctx)
	for e in 活:
		if e is Dictionary and str((e as Dictionary).get("key", "")) == 键:
			return e
	J.sort(活, func(a, b): return float((a as Dictionary).get("slot", 0.0)) - float((b as Dictionary).get("slot", 0.0)))
	return 活[0] if not 活.is_empty() else null

## 回合结束时还没发射 → 自动发射（`我方阶段末` 钩子）。
static func 阶段末(ctx: Dictionary) -> void:
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and not J.or_((u as Dictionary).get("METEOR锁定"), []).is_empty():
			Btl.pushLog(ctx, "〔METEOR〕%s 回合结束还没发射 → 自动发射" % str((u as Dictionary).get("name", "")),
				J.merged({"类型": "METEOR自动发射"}, Btl.谁(u)))
			METEOR发射(ctx, u, "发射")

# ---- 五、费用与门槛（由 `ColonialV01` 转发）----
## 觉醒大招的实际费用：极限超频 → 0；超频 −10；破隐一击 / 死神的收割吃「背后一刀」−10。
static func 大招费用(u: Dictionary, 卡: Dictionary) -> float:
	var 费 := Btl.战意费用(卡)
	if J.truthy(u.get("本回合极限超频")):
		return 0.0
	var 降 := int(J.num0(u.get("本回合觉醒大招降费")))
	if 降 > 0:
		费 = maxf(0.0, 费 - float(降))
	if ["COL_W2_ULT_AMBUSH", "COL_W2_ULT_HARVEST"].has(str(卡.get("id", ""))):
		费 = maxf(0.0, 费 - float(J.num0(u.get("破隐降费"))))
	return 费

## 副武器 / 主武器的额外门槛：`依赖未冷却`（援护射击要单发步枪没在冷却）、`本回合不能打武器`。
static func 武器门槛(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> String:
	if J.truthy(u.get("本回合不能打武器")):
		return "本回合不能打武器牌（潜入准备）"
	var w = 卡.get("武器")
	if not (w is Dictionary):
		return ""
	var 依 := str((w as Dictionary).get("依赖未冷却", ""))
	if 依 != "":
		for c in J.or_(u.get("武器栏"), []):
			if c is Dictionary and str((c as Dictionary).get("id", "")) == 依 and float((c as Dictionary).get("当前冷却", 0.0)) > 0.0:
				return "「%s」冷却中，这张副武器不可用" % str((c as Dictionary).get("名", ""))
	return ""

## 大招打完之后的收尾（`结束觉醒` / `连带冷却`）—— 由 `ColonialV01.打出大招` 调。
static func 大招收尾(ctx: Dictionary, u: Dictionary, 卡: Dictionary, w: Variant) -> void:
	if J.truthy(卡.get("结束觉醒")) and ColonialAwaken.是ZERO中(u):
		ColonialAwaken.结束(ctx, u, "打完了这一发")
	if w is Dictionary:
		var 连 := str((w as Dictionary).get("连带冷却", ""))
		if 连 != "":
			for c in J.or_(u.get("武器栏"), []):
				if c is Dictionary and str((c as Dictionary).get("id", "")) == 连:
					c["当前冷却"] = maxf(float((c as Dictionary).get("当前冷却", 0.0)), 1.0)

## 本发武器对「敌闪避减半」的声明（`ColonialV01._打觉醒大招` 读它）。
static func 本发标记(ctx: Dictionary, w: Variant) -> void:
	if ctx is Dictionary and w is Dictionary and J.truthy((w as Dictionary).get("敌闪避减半")):
		ctx["_本发敌闪避减半"] = true

# ---- 六、小工具 ----
static func _带武器(w: Variant) -> bool:
	return w is Dictionary and not (w as Dictionary).is_empty()

static func _名(u: Variant) -> String:
	return str((u as Dictionary).get("name", "（无）")) if u is Dictionary else "（无）"

static func _施放者(ctx: Dictionary) -> Variant:
	var 键 := str(ctx.get("_当前出牌者", ""))
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and str((a as Dictionary).get("key", "")) == 键:
			return a
	return null

static func _友(ctx: Dictionary, 目标们: Array) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	for u in 目标们:
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0:
			return u
	return _施放者(ctx)

static func _敌(ctx: Dictionary, 目标们: Array) -> Variant:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	for u in 目标们:
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0:
			return u
	return null

static func _加战意(ctx: Dictionary, u: Dictionary, 值: float, 原因: String) -> void:
	Btl.加战意(u, 值, ctx, 原因)
	Btl.pushLog(ctx, "〔%s〕%s 战意 +%d（现在 %d）" % [原因, str(u.get("name", "")), int(值), int(Btl.战意(u))],
		J.merged({"类型": 原因, "战意": u.get("战意")}, Btl.谁(u)))

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String) -> void:
	var 谁 := {"类型": 势力, "牌名": 牌名}
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % _名(u)) if u is Dictionary else "", 文], 谁)
