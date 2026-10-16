## 71-改动-3-难度调整.js 的运行期函数：回合上限、AI 站位权重、敌方强度。
class_name Diff
extends RefCounted

static func 回合上限(敌方们: Variant) -> float:
	var 表 = Db.T.难度调整.get("回合上限")
	var 序 := ["杂兵", "精锐", "头目", "Boss"]
	var 最高 := 0
	for u in J.or_(敌方们, []):
		var 键 = J.or_(J.or_(u.get("key"), u.get("键")), u.get("mech")) if u != null else null
		if not J.truthy(键):
			continue
		var i := 序.find(DataFn.tierOfEnemy(键))
		if i > 最高:
			最高 = i
	var 名: String = 序[最高]
	if 表 is Dictionary and 表.get(名) != null:
		return float(表[名])
	var d = J.g(表, "默认")
	return float(d) if J.truthy(d) else 12.0

static func 站位权重(att: Variant, t: Variant) -> float:
	var c = Db.T.难度调整.get("AI站位权重")
	if not J.truthy(c) or c.get("开") == false or not J.truthy(t):
		return 1.0
	if c.get("只给敌人") != false and not (att != null and att.get("side") == "enemy"):
		return 1.0
	var w
	if Units.unitRow(t) == Fm.ROW_FRONT:
		w = c.get("前排") if c.get("前排") != null else 1.0
	else:
		w = c.get("后排") if c.get("后排") != null else 1.0
	return float(w) if (J.finite(w) and float(w) >= 0) else 1.0

static func 敌方强度倍率(层: Variant, 梯队: Variant) -> Dictionary:
	var c: Dictionary = Db.T.难度调整.敌方强度
	var l := J.num(层)
	var 层基础 = J.at(c.get("层"), l) if (c.get("层") != null and is_finite(l)) else null
	if 层基础 == null:
		层基础 = 1.0
	var 权重 = J.at(c.get("档位权重"), 梯队) if c.get("档位权重") != null else null
	if 权重 == null:
		权重 = 1.0
	var 倍率 := minf(float(c.上限), maxf(1.0, 1.0 + (float(层基础) - 1.0) * float(权重)))
	return {"倍率": 倍率, "是否强化": 倍率 > 1.0001, "层基础": 层基础, "权重": 权重, "梯队": J.or_(梯队, "杂兵"),
		"层": l if is_finite(l) else null}

static func 应用敌方强化(u: Dictionary, 倍率: float, 详情: Variant) -> Dictionary:
	var c: Dictionary = Db.T.难度调整.敌方强度
	var f: Dictionary = J.or_(c.get("分项"), {})
	var 层 = J.num(详情.get("层")) if (详情 is Dictionary and 详情.get("层") != null) else null
	var 逐层 := func(k: String) -> Variant:
		var 表 = c.get("层HP系数") if k == "HP" else c.get("层威力系数")
		return J.at(表, 层) if (层 != null and 表 != null) else null
	var 系数 := func(k: String) -> float:
		var 覆盖 = 逐层.call(k)
		var 基 = 覆盖 if 覆盖 != null else (f.get(k) if f.get(k) != null else 1.0)
		return 1.0 + (倍率 - 1.0) * float(基)
	var 威力倍: float = 系数.call("威力")
	var 精准倍: float = 系数.call("精准")
	var 新武器 := []
	for e in J.or_(u.get("weapons"), []):
		var t: Dictionary = J.merged(e.t)
		var 这把 = c.特殊威力系数 if (t.get("dmgType") == "特殊" or J.truthy(t.get("ignoreDef"))) else 1.0
		var 乘 := func(p: float) -> float: return maxf(1.0, J.round(p * (1.0 + (威力倍 - 1.0) * float(这把))))
		if J.num(t.get("power")) > 0:
			t.power = 乘.call(float(t.power))
		if J.is_arr(t.get("upgrades")):
			t.upgrades = t.upgrades.map(func(up): return J.merged(up, {"power": 乘.call(float(up.power))}) if J.num(up.get("power")) > 0 else up)
		新武器.append(J.merged(e, {"t": t}))
	u.weapons = 新武器
	u.armor = J.round(float(u.armor) * 系数.call("装甲"))
	u.defense = J.round(J.num0(u.get("defense")) * 系数.call("防御"))
	u.aim = J.round(float(u.aim if u.get("aim") != null else 160.0) * 精准倍)
	u.maxHp = maxf(1.0, J.round(float(u.maxHp) * 系数.call("HP")))
	u.hp = u.maxHp
	u.敌方强度 = J.merged({"倍率": snappedf(倍率, 0.001)}, 详情 if 详情 is Dictionary else {})
	return u
