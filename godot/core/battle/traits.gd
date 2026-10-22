## 70-编成.js 的词条层（运行期）：把编成上的词条落到单位上。
class_name Traits
extends RefCounted

static func 编成词条(条目: Variant) -> Array:
	var 出 := []
	for t in J.or_(J.g(条目, "词条"), []):
		出.append(t)
	var 挂 = J.g(条目, "挂载")
	if J.truthy(挂) and J.truthy(J.at(Db.T.词条组表, 挂)):
		for t in J.at(Db.T.词条组表, 挂):
			出.append(J.merged(t, {"来自挂载": 挂}))
	return 出

static func 词条作用在(词条: Variant, 单位: Dictionary) -> bool:
	if not J.truthy(词条):
		return false
	var 作用 = J.or_(词条.get("作用"), "全体")
	if 作用 == "全体":
		return true
	if 作用 != "单台":
		return false
	return Fm.位名(单位.slot) == J.s(J.or_(词条.get("位"), ""))

## JS 用 Map 按键合并；这里用有序字典（插入顺序与 Map 一致）
static func 词条汇总(条目: Variant, 单位: Dictionary) -> Array:
	var 命中 := 编成词条(条目).filter(func(t): return 词条作用在(t, 单位))
	var 表 := {}
	for t in 命中:
		var k = J.g(t, "键")
		if not J.truthy(k):
			continue
		var 旧 = 表.get(k)
		if 旧 != null and t.get("叠加") == "叠" and J.is_num(t.get("值")) and J.is_num(旧.get("值")):
			表[k] = J.merged(t, {"值": float(旧.值) + float(t.值)})
		else:
			表[k] = J.merged(t)
	return 表.values()

static func 词条夹(键: String, 值: Variant) -> float:
	var 限 = Params.词条上限(键)
	var v := J.num(值)
	if not is_finite(v):
		return 0.0
	return v if 限 == null else maxf(-float(限), minf(float(限), v))

static func 词条增益(u: Dictionary, 键: String, 值: float) -> void:
	var src := "词条·%s" % 键
	u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != src)
	u.buffs.append({"src": src, "剩余": 9999.0, 键: 值})

static func 词条加能力(u: Dictionary, 键: String) -> void:
	u.abilities = (u.abilities as Array).duplicate() if J.is_arr(u.get("abilities")) else []
	if not J.inc(u.abilities, 键):
		u.abilities.append(键)

static func 词条加武器(u: Dictionary, 值: Variant, 层: Variant) -> void:
	if not J.truthy(值) or not J.truthy(值.get("name")):
		return
	if J.some(J.or_(u.get("weapons"), []), func(e): return J.truthy(e.get("t")) and e.t.get("name") == 值.name):
		return
	var 规: Dictionary = J.merged(值)
	规.erase("随强化")
	var 倍 := 词条威力系数(层, DataFn.tierOfEnemy(u.key))
	if J.num(规.get("power")) > 0:
		规.power = maxf(1.0, J.round(float(规.power) * 倍))
	var w := DataFn.wp(规)
	u.weapons = J.concat(J.or_(u.get("weapons"), []), [{"t": w, "cd": 0.0, "uses": w.get("uses"), "readyTurn": 1.0 + Calc.startCdOf(w)}])

static func 词条威力系数(层: Variant, 梯队: String) -> float:
	var c: Dictionary = J.or_(J.g(Db.T.难度调整, "敌方强度"), {})
	var 倍率 := float(Diff.敌方强度倍率(层, 梯队).倍率)
	var f: Dictionary = J.or_(c.get("分项"), {})
	var 逐层 = J.at(c.get("层威力系数"), 层) if (c.get("层威力系数") != null and 层 != null) else null
	var 基 = 逐层 if 逐层 != null else (f.get("威力") if f.get("威力") != null else 1.0)
	return 1.0 + (倍率 - 1.0) * float(基)

static func 应用词条到单位(u: Variant, t: Variant, 层: Variant) -> Variant:
	if not J.truthy(u) or not J.truthy(t) or not J.truthy(t.get("键")):
		return u
	var 键: String = t.键
	var 原值 = t.get("值")
	var 数 := 词条夹(键, 原值)
	var 比例: bool = t.get("方式") == "比例"
	match 键:
		"闪避":
			u.eva = maxf(0.0, J.round(float(u.eva) * (1.0 + 数 / 100.0) if 比例 else J.num0(u.get("eva")) + 数))
		"命中":
			词条增益(u, "hit", J.round(数))
		"暴击":
			u.critBase = J.num0(u.get("critBase")) + J.round(数)
		"装甲":
			u.armor = maxf(0.0, J.round(J.num0(u.get("armor")) * (1.0 + 数 / 100.0) if 比例 else J.num0(u.get("armor")) + 数))
		"防御":
			u.defense = maxf(0.0, J.num0(u.get("defense")) + J.round(数))
		"减伤":
			词条增益(u, "red", J.round(数))
		"物理减免":
			词条增益(u, "physRed", J.round(数))
		"攻击力加成":
			词条增益(u, "dmg", J.round(数))
		"护盾":
			u.shieldHp = maxf(0.0, J.round(J.num0(u.get("shieldHp")) + 数))
			u.shield = maxf(J.num0(u.get("shield")), 1.0)
		"能量屏障":
			词条加能力(u, "barrier")
			u.barrierLeft = maxf(J.num0(u.get("barrierLeft")), J.or_(J.round(数), 3.0) if J.truthy(J.round(数)) else 3.0)
		"λ力场":
			词条加能力(u, "lambdaShield")
		"隐匿":
			词条加能力(u, "stealth")
		"速度":
			u.mov = maxf(0.0, J.num0(u.get("mov")) + J.round(数))
		"弱点":
			u.weak = J.merged(J.or_(u.get("weak"), {}))
			var 原: Dictionary = J.or_(原值, {})
			for k in 原.keys():
				u.weak[k] = J.num0(u.weak.get(k)) + 词条夹("弱点", 原[k])
		"反弹":
			词条加能力(u, "beamReflect")
			u.词条反弹 = true
			u.反弹比例 = maxf(0.0, minf(1.0, 数 / 100.0))
			if J.truthy(t.get("仅近战")):
				u.反弹仅近战 = true
		"自爆":
			词条加能力(u, "selfDestruct")
			u.词条自爆 = true
			if 数 > 0:
				u.词条自爆倍率 = 数
		"自爆溅射两侧":
			词条加能力(u, "selfDestruct")
			u.词条自爆 = true
			u.自爆两侧 = true
		"自爆回合":
			u.词条自爆回合 = true
			u.自爆回合 = maxf(1.0, J.round(数))
		"冷却延长":
			var n := J.round(数)
			u.冷却延长 = maxf(1.0, n if J.truthy(n) else 1.0)
		"武器debuff":
			var 规: Dictionary = J.or_(原值, {})
			var 像规格 := J.some(["hit", "pct", "armorCut", "cd", "自身", "剩余", "src"], func(k): return 规.get(k) != null)
			var 表: Dictionary = J.or_(u.get("词条武器debuff"), {})
			if 像规格:
				表["*"] = J.merged(J.or_(表.get("*"), {}), 规)
			else:
				for 名 in 规.keys():
					表[名] = J.merged(J.or_(表.get(名), {}), 规[名])
			u.词条武器debuff = 表
		"全员命中":
			u.词条全场 = J.merged(J.or_(u.get("词条全场"), {}), {"命中": J.round(数)})
		"免直射物理":
			var n2 := J.round(数)
			u.免直射物理 = minf(95.0, maxf(1.0, n2 if J.truthy(n2) else 95.0))
		"护卫减伤":
			var n3 := J.round(数)
			u.护卫减伤 = maxf(0.0, n3 if J.truthy(n3) else 90.0)
		"隐身刷新":
			u.隐身刷新 = true
		"加武器":
			词条加武器(u, 原值, 层)
		"Boss脚本":
			u.词条Boss = J.merged(J.or_(原值, {}))
		"战斗分类":
			u.tags = J.merged(J.or_(u.get("tags"), {}), {"战斗分类": J.s(原值)})
		_:
			pass
	u.词条键们 = J.concat(J.or_(u.get("词条键们"), []), [键])
	return u

static func 词条到单位(单位们: Variant, 条目: Variant) -> Array:
	var 列表: Array = J.or_(单位们, [])
	if 列表.is_empty() or not Params.词条开():
		return 列表
	var 层 = (条目.get("层") if 条目.get("层") != null else null) if J.truthy(条目) else null
	for u in 列表:
		for t in 词条汇总(条目, u):
			应用词条到单位(u, t, 层)
	return 列表
