## 40-单位.js：造单位（模板 → 运行期单位）、升级、按方取单位。单位就是 Dictionary（与 JS 对象一一对应）。
class_name Units
extends RefCounted

static func otherSide(s: Variant) -> String:
	return "enemy" if s == "ally" else "ally"

static func unitRow(u: Dictionary) -> float:
	return Fm.rowOfSlot(u.slot)

static func speedOf(u: Dictionary) -> float:
	return J.round(float(u.mov) * 10.0 + float(u.eva) / 2.0)

static func sideUnits(side: Variant, ctx: Dictionary) -> Array:
	return ctx.allies if side == "ally" else ctx.enemies

static func livingOf(side: Variant, ctx: Dictionary) -> Array:
	return sideUnits(side, ctx).filter(func(u): return u.hp > 0)

static func livingUnits(ctx: Dictionary) -> Array:
	return (ctx.allies + ctx.enemies).filter(func(u): return u.hp > 0)

static func frontAlive(units: Array) -> bool:
	return J.some(units, func(u): return unitRow(u) == Fm.ROW_FRONT)

static func levelUp(u: Dictionary, heal: bool = false) -> void:
	u.lv = float(u.lv) + 1.0
	u.maxHp = float(u.maxHp) + 200.0
	if heal:
		u.hp = float(u.hp) + 200.0
	u.melee = float(u.melee) + 2.0
	u.shoot = float(u.shoot) + 2.0
	u.awaken = float(J.nz(u.get("awaken"), 100.0)) + 2.0
	u.defense = J.num0(u.get("defense")) + (0.0 if u.get("side") == "neutral" else 2.0)
	if u.get("side") == "ally" and (u.lv == 20 or u.lv == 30):
		var add := J.round(float(u.maxHp) * 0.25)
		u.maxHp = float(u.maxHp) + add
		if heal:
			u.hp = float(u.hp) + add
		u.armor = J.round(float(u.armor) * 1.25)
		u.melee = float(u.melee) + 25.0
		u.shoot = float(u.shoot) + 25.0
		u.awaken = float(u.awaken) + 25.0
		u.defense = float(u.defense) + 25.0
		u.eva = float(u.eva) + 8.0
		u.aim = float(u.aim) + 10.0
		if u.lv == 30:
			u.mov = float(u.mov) + 1.0

static func makeUnit(键: Variant, side: String, slot: float, lv: float, 强化: Variant = 1.0, 当前HP比: Variant = null, 层: Variant = null) -> Dictionary:
	var tpl = DataFn.tplOf(键) if side == "ally" else J.at(Db.T.ENEMY_T, 键)
	if tpl == null:
		push_error("编成里出现了不认识的%s：%s" % ["角色键" if side == "ally" else "敌人键", 键])
		return {}
	var aim = tpl.get("aim")
	if aim == null:
		if side == "ally":
			var tags = J.or_(tpl.get("tags"), {})
			aim = J.nz(J.at(Db.T.AIM_BY_CLASS, tags.get("战斗分类")), 160.0)
		else:
			aim = 160.0
	var weapons := []
	for w in tpl.weapons:
		weapons.append({"t": w, "cd": 0.0, "uses": w.get("uses"), "readyTurn": 1.0 + Calc.startCdOf(w)})
	var u: Dictionary = J.merged(tpl, {
		"key": 键, "side": side, "slot": slot, "lv": 1.0,
		"maxHp": tpl.hp, "hp": tpl.hp,
		"aim": aim,
		"shieldHp": J.or_(tpl.get("shield"), 0.0),
		"buffs": [], "debuffs": [], "armorCut": 0.0,
		"barrierLeft": 3.0,
		"name": tpl.pilot if side == "ally" else tpl.mech,
		"weapons": weapons,
	})
	while float(u.lv) < lv:
		levelUp(u, true)
	u.hp = u.maxHp
	u.强化 = 1.0
	if side == "enemy" and J.num(强化) > 1.0001:
		Diff.应用敌方强化(u, J.num(强化), {"来源": "编成（层 × 梯队）", "层": 层})
		u.强化 = J.num(强化)
		u.层 = 层
	u.hp = Params.按比例算HP(u.maxHp, 当前HP比, Params.HP继承参数())
	return u

## 11-敌方梯队.js runEnemyLv()
static func runEnemyLv(kind: String, layer: int, layerBattles: Variant) -> float:
	var base = [0, 1, 4, 8, 13][layer]
	var span = [0, 2, 3, 4, 5][layer]
	var n := J.num0(layerBattles)
	var extra := 0
	if kind == "elite" or kind == "guard" or kind == "source":
		extra = 1 if layer == 1 else 2
	return float(base) + minf(span, n) + extra + (1.0 if kind == "chase" else 0.0)

static func 默认等级(键: Variant, side: String) -> float:
	if side == "ally":
		return 10.0
	return runEnemyLv("battle", 1, 0) + float(Db.T.TIER_LV[DataFn.tierOfEnemy(键)])

static func makeUnits(编成: Array, side: String) -> Array:
	var out := []
	for i in 编成.size():
		var s: Dictionary = 编成[i]
		var 键 = J.or_(J.or_(s.get("键"), s.get("key")), s.get("mech"))
		var 位 = s.get("位") if s.get("位") != null else (s.get("slot") if s.get("slot") != null else float(i))
		var 等级 = J.or_(J.or_(s.get("等级"), s.get("lv")), null)
		if not J.truthy(等级):
			等级 = 默认等级(键, side)
		if float(位) < 0 or float(位) >= Fm.SLOTS():
			push_error("编成里的位置 %s 越界" % [位])
		var 强度 = s.get("敌方强度")
		var 强化 = s.get("强化") if s.get("强化") != null else J.or_(J.g(强度, "倍率"), 1.0)
		var 层 = s.get("层") if s.get("层") != null else (强度.get("层") if 强度 is Dictionary and 强度.get("层") != null else null)
		var 比例 = s.get("hp") if s.get("hp") != null else (s.get("hp比") if s.get("hp比") != null else null)
		var u := makeUnit(键, side, float(位), float(等级), 强化, 比例, 层)
		if J.truthy(s.get("词条")):
			Traits.词条到单位([u], {"词条": s.词条, "层": 层})
		out.append(u)
	return out
