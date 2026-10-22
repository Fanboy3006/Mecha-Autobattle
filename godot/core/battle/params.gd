## 71-改动-5-参数入口.js：所有「读战斗结构参数」的函数与兰斯战线 / 职业排位 / 卡牌伤害等纯计算。
## 规则数值全部来自 Db.T.战斗结构（JS 里的全局 战斗结构），这里只读不改。
class_name Params
extends RefCounted

static func _S() -> Dictionary:
	return Db.T.战斗结构

static func _块(名: String) -> Dictionary:
	var v = _S().get(名)
	return v if v is Dictionary else {}

# ---------------- 词条 ----------------
static func 词条参数() -> Dictionary:
	return _块("词条")

static func 词条开() -> bool:
	return not (词条参数().get("开") == false)

static func 词条上限(键: String) -> Variant:
	var 表 = 词条参数().get("上限")
	var v = J.at(表, 键) if 表 != null else null
	return v if (J.finite(v) and float(v) > 0) else null

# ---------------- 大招冷却 / 职业 ----------------
static func 大招开场冷却() -> float:
	var v = J.g(_S().get("大招冷却"), "开场")
	return float(v) if (J.finite(v) and float(v) >= 0) else 3.0

static func 大招普攻冷却() -> float:
	var v = J.g(_S().get("大招冷却"), "普通")
	return float(v) if (J.finite(v) and float(v) >= 0) else 0.0

static func 对称职业特色开() -> bool:
	return not (_S().get("对称职业特色") == false)

static func 敌方职业(键: Variant) -> Variant:
	var t = _S().get("敌方职业")
	var v = J.at(t, 键) if (t != null and 键 != null) else null
	return v if J.truthy(v) else null

# ---------------- 敌人机制 ----------------
static func 敌人机制参数() -> Dictionary:
	return _块("敌人机制")

static func 敌人机制开() -> bool:
	return not (敌人机制参数().get("开") == false)

static func 是敌人机制单位(u: Variant) -> bool:
	if u == null:
		return false
	var c := 敌人机制参数()
	return not (c.get("只给敌人") != false and u.get("side") != "enemy")

static func 有敌人机制(u: Variant, 键: Variant) -> bool:
	return u != null and J.truthy(键) and 敌人机制开() and 是敌人机制单位(u) and Calc.abilOn(u, 键)

static func 隐匿命中惩罚() -> float:
	var c: Dictionary = J.or_(敌人机制参数().get("隐匿"), {})
	var v := J.num(c.get("命中惩罚"))
	return maxf(0.0, J.round(v)) if is_finite(v) else 0.0

static func 隐匿吃惩罚(武器: Variant) -> bool:
	var c: Dictionary = J.or_(敌人机制参数().get("隐匿"), {})
	var 吃: Array = c.吃惩罚的射程 if (J.is_arr(c.get("吃惩罚的射程")) and not c.吃惩罚的射程.is_empty()) else ["直射", "曲射"]
	var k = Reach.rangeKindOf(武器)
	return J.truthy(k) and J.inc(吃, k)

static func 隐匿惩罚值(def: Variant, 武器: Variant) -> float:
	if not (有敌人机制(def, "stealth") or (def != null and J.truthy(def.get("隐身中")))):
		return 0.0
	return 隐匿命中惩罚() if 隐匿吃惩罚(武器) else 0.0

static func 镜甲反弹比例() -> float:
	var c: Dictionary = J.or_(敌人机制参数().get("镜甲"), {})
	var v := J.num(c.get("反弹比例"))
	return maxf(0.0, v) if is_finite(v) else 0.0

static func 自爆参数() -> Dictionary:
	var c: Dictionary = J.or_(敌人机制参数().get("自爆"), {})
	var 倍 := J.num(c.get("威力倍率"))
	var 线 := J.num(c.get("濒死线"))
	return {
		"威力倍率": maxf(0.0, 倍) if is_finite(倍) else 1.5,
		"濒死线": 线 if is_finite(线) else 0.35,
		"范围": J.or_(c.get("范围"), "col"),
		"武器名": J.or_(c.get("武器名"), "濒死自爆"),
	}

static func 武器debuff(单位键: Variant, 武器名: Variant, 单位: Variant) -> Variant:
	var 自定义 = J.g(单位, "词条武器debuff")
	if J.truthy(自定义):
		var 规 = J.or_(自定义.get("*"), J.at(自定义, 武器名))
		if J.truthy(规):
			return 规
	var t = _S().get("敌方debuff")
	var 招 = J.at(t, 单位键) if (t != null and 单位键 != null) else null
	var r = J.at(招, 武器名) if J.truthy(招) else null
	return r if J.truthy(r) else null

# ---------------- HP 继承 ----------------
static func HP继承参数() -> Dictionary:
	return _块("HP继承")

static func 按比例算HP(maxHp: float, 比: Variant, 参数: Variant) -> float:
	var c: Dictionary = 参数 if J.truthy(参数) else HP继承参数()
	var 最低 := J.num(c.get("最低HP")) if is_finite(J.num(c.get("最低HP"))) else 1.0
	if 比 == null or not is_finite(J.num(比)):
		return maxHp
	return maxf(最低, minf(maxHp, J.round(maxHp * J.num(比))))

# ---------------- 气势 ----------------
static func 气势总攻参数() -> Dictionary:
	return _块("气势总攻")

static func 气势总攻开() -> bool:
	return 气势总攻参数().get("开") != false

# ---------------- Feena 主动攻击 / 残月 ----------------
static func Feena主动攻击参数() -> Dictionary:
	return _块("Feena主动攻击")

static func Feena主动攻击开() -> bool:
	return Feena主动攻击参数().get("开") != false

static func 是残月的余响(w: Variant) -> bool:
	return w != null and J.truthy(w.get("友军攻击后追加")) and J.truthy(w.get("残月下放"))

static func 残月武器可主动(w: Variant) -> bool:
	if w == null or not J.truthy(w.get("友军攻击后追加")):
		return true
	return Feena主动攻击开()

## JS 里是运行期取值器（unlock 随开关变）；导出的数据已按「开关开着」求过值，这里直接读字段
static func 残月武器运行期解锁(w: Variant) -> Variant:
	return w.get("unlock") if w != null else null

static func 残月武器运行期威力(u: Variant, w: Variant) -> Variant:
	if u == null or not 是残月的余响(w) or not Feena主动攻击开():
		return Calc.wv(u, w, "power")
	if not (float(u.lv) < 20):
		return Calc.wv(u, w, "power")
	var v := J.num(w.lv10Power if (w != null and w.get("lv10Power") != null) else Feena主动攻击参数().get("残月Lv10威力"))
	return v if is_finite(v) else 2200.0

static func 威力取档(u: Variant, w: Variant, key: Variant) -> Variant:
	return 残月武器运行期威力(u, w) if (key == "power" or key == null) else Calc.wv(u, w, key)

# ---------------- 兰斯战线 ----------------
static func 兰斯战线参数() -> Dictionary:
	return _块("兰斯战线")

static func 兰斯战线开() -> bool:
	return 兰斯战线参数().get("开") != false

static func 兰斯数(键: String, 默认值: float) -> float:
	var v := J.num(兰斯战线参数().get(键))
	return v if is_finite(v) else 默认值

static func 前排近战增伤() -> float: return 兰斯数("前排近战增伤", 0.15)
static func 前排远程命中惩罚() -> float: return 兰斯数("前排远程命中惩罚", 15)
static func 后排隔排近战惩罚() -> float: return 兰斯数("后排隔排近战惩罚", 0.25)
static func 后排远程增伤() -> float: return 兰斯数("后排远程增伤", 0.10)
static func 后排远程命中() -> float: return 兰斯数("后排远程命中", 10)
static func 侧翼闪避加成() -> float: return 兰斯数("侧翼闪避加成", 10)
static func 侧翼暴击加成() -> float: return 兰斯数("侧翼暴击加成", 10)
static func 中枢重装防御() -> float: return 兰斯数("中枢重装防御", 15)
static func 同路索敌权重() -> float: return 兰斯数("同路索敌权重", 1.35)
static func 相邻路索敌权重() -> float: return 兰斯数("相邻路索敌权重", 1.10)

static func 在外侧两路(u: Variant) -> bool:
	return u != null and u.get("slot") != null and (Fm.colOfSlot(u.slot) == 0 or Fm.colOfSlot(u.slot) == 3)

static func 是侧翼游击(u: Variant) -> bool:
	return u != null and Reach.职业是(u, "尖兵")

static func 是远程排位手(att: Variant, w: Variant) -> bool:
	return w != null and (w.get("fire") == "indirect" or Reach.职业是(att, "狙击") or Reach.职业是(att, "指挥"))

static func 是远程贴脸手(att: Variant, w: Variant) -> bool:
	return w != null and (w.get("fire") == "indirect" or Reach.职业是(att, "狙击"))

static func 中枢重装防御加成(u: Variant) -> float:
	if u == null or not 兰斯战线开():
		return 0.0
	if not (u.slot == 1 or u.slot == 2):
		return 0.0
	if not Reach.职业是(u, "重装"):
		return 0.0
	var v := 中枢重装防御()
	return v if (is_finite(v) and v > 0) else 0.0

static func 兰斯命中修正(att: Variant, def: Variant, w: Variant, _ctx: Variant) -> float:
	if not 兰斯战线开():
		return 0.0
	var n := 0.0
	if att != null and att.get("slot") != null:
		if Fm.rowOfSlot(att.slot) == Fm.ROW_FRONT and 是远程贴脸手(att, w):
			n -= 前排远程命中惩罚()
		if Fm.rowOfSlot(att.slot) == Fm.ROW_BACK and 是远程排位手(att, w):
			n += 后排远程命中()
	if def != null and 在外侧两路(def) and 是侧翼游击(def):
		n -= 侧翼闪避加成()
	return n

static func 兰斯暴击修正(att: Variant, _w: Variant) -> float:
	if not 兰斯战线开():
		return 0.0
	if not 在外侧两路(att) or not 是侧翼游击(att):
		return 0.0
	return 侧翼暴击加成()

static func 兰斯掩护减免(def: Variant, w: Variant, ctx: Variant, 被挡: Variant) -> float:
	if not 兰斯战线开():
		return 0.0
	if def == null or not J.truthy(兰斯战线参数().get("同路掩护减伤")):
		return 0.0
	if Reach.rangeKindOf(w) != Reach.KIND_DIRECT():
		return 0.0
	if Fm.rowOfSlot(def.slot) != Fm.ROW_BACK:
		return 0.0
	var 真被挡: bool
	if 被挡 != null:
		真被挡 = J.truthy(被挡)
	else:
		真被挡 = ctx != null and Fm.被挡吗(def.slot, Units.livingOf(def.side, ctx).map(func(x): return x.slot))
	if not 真被挡:
		return 0.0
	return 兰斯数("同路掩护减伤", 0.30)

static func 同路索敌倍率(att: Variant, t: Variant) -> float:
	if not 兰斯战线开() or att == null or t == null or att.get("slot") == null or t.get("slot") == null:
		return 1.0
	var d := absf(Fm.colOfSlot(att.slot) - Fm.colOfSlot(t.slot))
	if d == 0:
		return 同路索敌权重()
	if d == 1:
		return 相邻路索敌权重()
	return 1.0

static func 兰斯破阵暴露(target: Variant, 敌方活位们: Variant, ctx: Variant) -> bool:
	if not 兰斯战线开() or 兰斯战线参数().get("破阵近战突袭") == false:
		return false
	if target == null or target.get("slot") == null:
		return false
	if Fm.rowOfSlot(target.slot) != Fm.ROW_BACK:
		return false
	var 方 = J.or_(target.get("side"), "enemy")
	var 活位
	if 敌方活位们 != null:
		活位 = 敌方活位们
	elif ctx != null:
		活位 = Units.livingOf(方, ctx).map(func(x): return x.slot)
	else:
		活位 = []
	return not Fm.被挡吗(target.slot, 活位)

static func 同路铁壁护卫(ctx: Variant, _攻击者: Variant, target: Variant) -> Variant:
	if ctx == null or target == null:
		return null
	if not 兰斯战线开() or 兰斯战线参数().get("同路重装必护卫") == false:
		return null
	if target.get("slot") == null or Fm.rowOfSlot(target.slot) != Fm.ROW_BACK:
		return null
	var 遮: Array = Fm.遮挡位(target.slot)
	var 位 = 遮[0] if not 遮.is_empty() else null
	if 位 == null:
		return null
	var 候选 := Units.livingOf(target.side, ctx).filter(func(u): return u.slot == 位 and Reach.职业是(u, "重装") and not is_same(u, target) and u.hp > 0)
	return 候选[0] if not 候选.is_empty() else null

static func _排(u: Variant) -> Variant:
	return Fm.rowOfSlot(u.slot) if (u != null and u.get("slot") != null) else null

static func 兰斯伤害倍率(att: Variant, def: Variant, w: Variant, o: Variant) -> float:
	if not 兰斯战线开():
		return 1.0
	var ctx = J.g(o, "ctx")
	var kind = Reach.rangeKindOf(w)
	var m := 1.0
	var att排 = _排(att)
	var def排 = _排(def)
	if kind == Reach.KIND_MELEE():
		if att排 == Fm.ROW_FRONT:
			m *= 1.0 + 前排近战增伤()
		if att排 == Fm.ROW_BACK and ctx != null and att != null and att.get("slot") != null:
			var 同路前: Array = J.or_(ctx.allies if att.side == "ally" else ctx.enemies, [])
			if J.some(同路前, func(x): return x != null and not is_same(x, att) and x.hp > 0 and x.slot == att.slot - 4):
				m *= 1.0 - 后排隔排近战惩罚()
	if att排 == Fm.ROW_BACK and 是远程排位手(att, w) and not (职业排位开() and Reach.职业是(att, "狙击")):
		m *= 1.0 + 后排远程增伤()
	if not (o != null and J.truthy(o.get("不带掩护"))):
		var 掩护 := 兰斯掩护减免(def, w, ctx, o.get("被挡") if o != null else null)
		if 掩护 > 0 and not Reach.职业是(att, "狙击") and not FacMith.秘银取消被挡(att, def, ctx):
			m *= 1.0 - 掩护
	return m

static func 掩护减免值(未乘: Variant, 实: Variant) -> float:
	var a := J.num(未乘)
	var b := J.num(实)
	if not is_finite(a) or not is_finite(b):
		return 0.0
	return maxf(0.0, J.round(a - b))

# ---------------- 职业排位 ----------------
static func 职业排位参数() -> Dictionary:
	return _块("职业排位")

static func 职业排位开() -> bool:
	return 兰斯战线开() and 职业排位参数().get("开") != false

static func 职业排位数(键: String, 默认值: float) -> float:
	if not 职业排位开():
		return 默认值
	var v = 职业排位参数().get(键)
	return float(v) if (J.is_num(v) and not is_nan(float(v))) else 默认值

static func 职业排位命中修正(att: Variant, def: Variant, _w: Variant, _ctx: Variant) -> float:
	if not 职业排位开():
		return 0.0
	var n := 0.0
	if att != null and J.is_int(att.get("slot")) and Fm.rowOfSlot(att.slot) == Fm.ROW_BACK:
		if Reach.职业是(att, "重装"):
			n -= 职业排位数("重装后排命中惩罚", 15)
		if Reach.职业是(att, "尖兵"):
			n += 职业排位数("尖兵后排命中", 15)
		if Reach.职业是(att, "特种"):
			n += 职业排位数("特种后排命中", 10)
	if def != null and J.is_int(def.get("slot")) and Fm.rowOfSlot(def.slot) == Fm.ROW_FRONT and Reach.职业是(def, "尖兵"):
		n -= 职业排位数("尖兵前排常驻闪避", 10)
	return n

static func 尖兵首闪值(def: Variant) -> float:
	if 职业排位开() and def != null and J.is_int(def.get("slot")) and Fm.rowOfSlot(def.slot) == Fm.ROW_FRONT:
		return 职业排位数("尖兵前排首闪", 30)
	return 20.0

static func 职业排位暴击修正(att: Variant, _w: Variant) -> float:
	if not 职业排位开() or att == null or not J.is_int(att.get("slot")):
		return 0.0
	if Fm.rowOfSlot(att.slot) == Fm.ROW_BACK:
		if Reach.职业是(att, "狙击"):
			return 职业排位数("狙击后排额外暴击", 5)
		if Reach.职业是(att, "尖兵"):
			return 职业排位数("尖兵后排暴击", 15)
	return 0.0

static func 战术卡牌伤害倍率(att: Variant, w: Variant) -> float:
	if att == null or not J.is_arr(att.get("buffs")) or att.buffs.is_empty():
		return 1.0
	var m := 1.0
	var kind = Reach.rangeKindOf(w) if w != null else null
	for b in att.buffs:
		if not J.truthy(b):
			continue
		var dm = b.get("dmgMul")
		if J.finite(dm) and float(dm) != 0:
			m *= 1.0 + float(dm)
		var mm = b.get("meleeDmgMul")
		if J.finite(mm) and float(mm) != 0 and (kind == "melee" or Reach.职业是(att, "近卫")):
			m *= 1.0 + float(mm)
	return m

static func 职业排位伤害倍率(att: Variant, def: Variant, w: Variant, o: Variant) -> float:
	var 卡牌倍 := 战术卡牌伤害倍率(att, w)
	if not 职业排位开():
		return 卡牌倍
	var ctx = J.g(o, "ctx")
	var kind = Reach.rangeKindOf(w) if w != null else null
	var 已吃兰斯近战: bool = 兰斯战线开() and kind == Reach.KIND_MELEE()
	var m := 1.0
	if att != null and J.is_int(att.get("slot")):
		var attRow := Fm.rowOfSlot(att.slot)
		if Reach.职业是(att, "重装") and attRow == Fm.ROW_BACK:
			m *= 1.0 - 职业排位数("重装后排伤害惩罚", 0.20)
		if Reach.职业是(att, "近卫") and attRow == Fm.ROW_FRONT:
			if not 已吃兰斯近战:
				m *= 1.0 + 职业排位数("近卫前排增伤", 0.15)
			if ctx != null and att.get("近卫连斩追击Turn") != null and att.近卫连斩追击Turn == ctx.turn:
				m *= 1.0 + 职业排位数("近卫连斩追击增伤", 0.20)
		if Reach.职业是(att, "近卫") and attRow == Fm.ROW_BACK:
			if not 已吃兰斯近战 and ctx != null and J.some(J.or_(ctx.allies if att.side == "ally" else ctx.enemies, []),
					func(x): return x != null and not is_same(x, att) and x.hp > 0 and x.slot == att.slot - 4):
				m *= 1.0 - 职业排位数("近卫后排隔排惩罚", 0.25)
		if Reach.职业是(att, "狙击") and attRow == Fm.ROW_BACK:
			m *= 1.0 + maxf(后排远程增伤() if 兰斯战线开() else 0.0, 职业排位数("狙击后排增伤", 0.15))
		if Reach.职业是(att, "尖兵") and attRow == Fm.ROW_BACK:
			m *= 1.0 + 职业排位数("尖兵后排增伤", 0.15)
		if Reach.职业是(att, "特种") and attRow == Fm.ROW_FRONT:
			if not 已吃兰斯近战:
				m *= 1.0 + 职业排位数("特种前排增伤", 0.15)
	if def != null and J.is_int(def.get("slot")) and Fm.rowOfSlot(def.slot) == Fm.ROW_FRONT:
		if Reach.职业是(def, "重装"):
			m *= 1.0 - 职业排位数("重装前排减伤", 0.20)
		if Reach.职业是(def, "尖兵"):
			m *= 1.0 - 职业排位数("尖兵前排减伤", 0.15)
		if Reach.职业是(def, "特种"):
			m *= 1.0 - 职业排位数("特种前排减伤", 0.10)
		if Reach.职业是(def, "狙击"):
			m *= 1.0 + 职业排位数("狙击前排易伤", 0.15)
		if Reach.职业是(def, "指挥"):
			m *= 1.0 + 职业排位数("指挥前排易伤", 0.15)
	return m * 卡牌倍

static func 职业排位修理倍率(u: Variant) -> float:
	if 职业排位开() and u != null and J.is_int(u.get("slot")) and Fm.rowOfSlot(u.slot) == Fm.ROW_BACK:
		if Reach.职业是(u, "指挥"):
			return 1.0 + 职业排位数("指挥后排修理加成", 0.20)
		if Reach.职业是(u, "特种"):
			return 1.0 + 职业排位数("特种后排修理加成", 0.20)
	return 1.0

static func 特种产标层数(att: Variant) -> float:
	if 职业排位开() and att != null and J.is_int(att.get("slot")) and Fm.rowOfSlot(att.slot) == Fm.ROW_BACK and Reach.职业是(att, "特种"):
		return 职业排位数("特种后排产标层数", 2)
	return 1.0

## 动作 QTE 已关闭（不迁移）：数据里是 false
static func 动作QTE开() -> bool:
	return J.truthy(J.g(_S().get("动作QTE"), "开"))

# ---------------- 战术卡牌 ----------------
static func 战术卡牌参数() -> Dictionary:
	return _块("战术卡牌")

## 手牌上限：`手牌总上限` / `初始手牌上限` 等（数据里是数；没有 / 是 0 就给默认值）
static func 手牌上限(_ctx: Variant, 键: String = "手牌总上限", 默认值: int = 10) -> int:
	var v = 战术卡牌参数().get(键)
	if (v is float or v is int) and not is_nan(float(v)) and float(v) > 0:
		return int(v)
	return 默认值

## 大招槽卡牌的费用门槛用的是「战意」，与 `_战意费用` 同一份真源（这里只是给表现层一个别名）。
static func 大招槽亮起条件(槽: Variant) -> String:
	if not (槽 is Dictionary):
		return "无效的大招槽条目"
	if int(槽.get("本回合已打", 0)) > 0:
		return "本回合已经打过这张大招"
	if float(槽.get("cd", 0.0)) > 0.0:
		return "冷却中（还剩 %d 回合）" % int(槽.get("cd", 0.0))
	if not J.truthy(槽.get("已解锁", false)):
		return "获取条件未满足：%s" % str(槽.get("解锁说明", "永久解锁条件没达成"))
	if not J.truthy(槽.get("实时门槛满足", true)):
		return "亮起条件未满足：%s" % str(槽.get("门槛说明", "状态门槛没达成"))
	return ""

# ---------------- 单机牌组（DECK-1：阶段制 / 战意 / 主武器卡 / 七职业，唯一模式） ----------------
## 单机牌组是**唯一模式**（RT-4），不再有总开关；这里只留它的参数块。
static func 单机牌组参数() -> Dictionary:
	return _块("单机牌组")

static func _单机数(键: String, 默认值: float) -> float:
	var v := J.num(单机牌组参数().get(键))
	return v if is_finite(v) else 默认值

static func 单机牌组_维修职业() -> String:
	var v = 单机牌组参数().get("维修职业")
	return str(v) if J.truthy(v) else "维修"

static func 单机牌组_维修机体() -> Array:
	var v = 单机牌组参数().get("维修机体")
	return v if v is Array else ["M3"]

static func 单机牌组_不转维修机体() -> Array:
	var v = 单机牌组参数().get("不转维修机体")
	return v if v is Array else ["A5", "B3", "M5"]

## ★ 战意（Will）：每个我方单位自己的资源，从 0 起算、上限 100。
static func 战意上限() -> float: return _单机数("战意上限", 100.0)
static func 开场战意() -> float: return _单机数("开场战意", 0.0)
static func 回合初战意() -> float: return _单机数("回合初战意", 5.0)
static func 命中战意() -> float: return _单机数("命中战意", 2.0)
static func 被击战意() -> float: return _单机数("被击战意", 2.0)
static func 闪避战意() -> float: return _单机数("闪避战意", 2.0)
static func 击破战意() -> float: return _单机数("击破战意", 10.0)

## ★ 上排（单机专属牌）与下排（全队公有牌）的容量标尺。
static func 专属起手() -> float: return _单机数("专属起手", 2.0)
static func 专属每回合抽() -> float: return _单机数("专属每回合抽", 1.0)
static func 专属手牌上限() -> float: return _单机数("专属手牌上限", 4.0)
static func 公有起手() -> float: return _单机数("公有起手", 3.0)
static func 公有每回合抽() -> float: return _单机数("公有每回合抽", 1.0)
static func 公有手牌自然上限() -> float: return _单机数("公有手牌自然上限", 6.0)
static func 公有手牌硬上限() -> float: return _单机数("公有手牌硬上限", 8.0)
static func 指挥公有减费() -> float: return _单机数("指挥公有减费", 5.0)

## 别名（带完整前缀，方便调用点一眼看出属于哪套规则）
static func 单机牌组_战意上限() -> float: return 战意上限()
static func 单机牌组_开场战意() -> float: return 开场战意()
static func 单机牌组_回合初战意() -> float: return 回合初战意()
static func 单机牌组_命中战意() -> float: return 命中战意()
static func 单机牌组_被击战意() -> float: return 被击战意()
static func 单机牌组_闪避战意() -> float: return 闪避战意()
static func 单机牌组_击破战意() -> float: return 击破战意()
static func 单机牌组_专属起手() -> float: return 专属起手()
static func 单机牌组_专属每回合抽() -> float: return 专属每回合抽()
static func 单机牌组_专属手牌上限() -> float: return 专属手牌上限()
static func 单机牌组_公有起手() -> float: return 公有起手()
static func 单机牌组_公有每回合抽() -> float: return 公有每回合抽()
static func 单机牌组_公有手牌自然上限() -> float: return 公有手牌自然上限()
static func 单机牌组_公有手牌硬上限() -> float: return 公有手牌硬上限()
static func 单机牌组_指挥公有减费() -> float: return 指挥公有减费()

## 单机牌组模式下这台单位算哪个职业（键或单位都认）。
## 非模式：与原来完全一样（读 tags.战斗分类 / 职业字段 / 模板）。
## 模式：维修机体（Iris 等带治疗武器、且不在「不转维修」名单里）归【维修】。
static func 单机牌组_职业(键或单位: Variant, ctx: Variant = null) -> String:
	return Units.unit_class(键或单位, ctx)
