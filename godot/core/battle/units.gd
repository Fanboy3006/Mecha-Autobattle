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

## 同一场里同一个敌人键第二次出现就发 `键#2`、`键#3`…（内部 `key` 唯一，`tplKey` 还是原键，显示名不变）。
## `已用` = 这个键已经发过几台，由调用方维护（开局编成 / 增援共用这一份口径）。
static func 下一个键(键: String, 已用: Dictionary) -> String:
	var n := int(已用.get(键, 0)) + 1
	已用[键] = n
	return 键 if n == 1 else "%s#%d" % [键, n]

## 场上一批单位用过的键计数（`#n` 后缀按 `tplKey` / 原键归一）。
static func 已用键表(单位们: Variant) -> Dictionary:
	var 出 := {}
	for u in J.or_(单位们, []):
		if not (u is Dictionary):
			continue
		var 基 := str((u as Dictionary).get("tplKey")) if J.truthy((u as Dictionary).get("tplKey")) else str((u as Dictionary).get("key", ""))
		出[基] = int(出.get(基, 0)) + 1
	return 出

static func makeUnit(键: Variant, side: String, slot: float, lv: float, 强化: Variant = 1.0, 当前HP比: Variant = null, 层: Variant = null, 实例键: Variant = null) -> Dictionary:
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
		"key": 键 if 实例键 == null else 实例键, "side": side, "slot": slot, "lv": 1.0,
		"maxHp": tpl.hp, "hp": tpl.hp,
		"aim": aim,
		"shieldHp": J.or_(tpl.get("shield"), 0.0),
		"buffs": [], "debuffs": [], "armorCut": 0.0,
		"barrierLeft": 3.0,
		"name": tpl.pilot if side == "ally" else tpl.mech,
		"weapons": weapons,
	})
	if 实例键 != null and str(实例键) != str(键):
		u["tplKey"] = 键
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

## ======================== 单机牌组（DECK-1）职业判读 ========================
## ★ 把 Iris（M3）等带治疗武器的机体映射为第 7 职业【维修】
##   （单机牌组是唯一模式，职业判读一律走这一套）。
##   显式写了 `tags.战斗分类 == "维修"` / `职业 == "维修"` / `维修 == true` 的单位，任何模式下都认。
##   A5（库斯哈）保留【指挥】、B3（维诺）/ M5（苏菲）保留【特种】（都带治疗武器），见数据里的「不转维修机体」。
static func _键Of(u: Variant) -> String:
	if u == null:
		return ""
	if u is String or u is StringName:
		return str(u)
	if u is Dictionary:
		return str(J.or_(J.or_(J.or_(J.or_(u.get("tplKey"), u.get("key")), u.get("mech")), u.get("键")), ""))
	return ""

static func _标签Of(u: Variant, tpl: Variant) -> Dictionary:
	if u is Dictionary and u.get("tags") is Dictionary:
		return u.tags
	if tpl != null and tpl.get("tags") is Dictionary:
		return tpl.tags
	return {}

static func 模板有治疗武器(tpl: Variant) -> bool:
	if tpl == null or not (tpl.get("weapons") is Array):
		return false
	for w in tpl.weapons:
		if w is Dictionary and w.get("fire") == "heal":
			return true
	return false

static func 单位有治疗武器(u: Variant) -> bool:
	if not (u is Dictionary) or not (u.get("weapons") is Array):
		return false
	for e in u.weapons:
		if not (e is Dictionary):
			continue
		var w = e.get("t") if e.get("t") is Dictionary else e
		if w is Dictionary and w.get("fire") == "heal":
			return true
	return false

static func 是维修机体(u: Variant, ctx: Variant = null) -> bool:
	var 键 := _键Of(u)
	var tpl = DataFn.tplOf(键) if 键 != "" else null
	var 维修名 := Params.单机牌组_维修职业()
	if str(_标签Of(u, tpl).get("战斗分类", "")) == 维修名:
		return true
	if u is Dictionary:
		if str(u.get("职业", "")) == 维修名 or str(u.get("单机牌组职业", "")) == 维修名:
			return true
		if J.truthy(u.get("维修")) or J.truthy(u.get("单机牌组维修")):
			return true
	if 键 == "":
		return false
	# ctx 里可以临时加名单（测试 / 事件用），优先级最高
	if ctx is Dictionary and ctx.get("维修机体") is Array and J.inc(ctx.维修机体, 键):
		return true
	if J.inc(Params.单机牌组_不转维修机体(), 键):
		return false
	if J.inc(Params.单机牌组_维修机体(), 键):
		return true
	if 模板有治疗武器(tpl) or 单位有治疗武器(u):
		return true
	return false

## 这台单位的职业。`u` 可以是单位字典、角色键（String）或模板键。
static func unit_class(u: Variant, ctx: Variant = null) -> String:
	if u == null:
		return ""
	var 键 := _键Of(u)
	var tpl = DataFn.tplOf(键) if 键 != "" else null
	var 显式 := str(_标签Of(u, tpl).get("战斗分类", ""))
	var 维修名 := Params.单机牌组_维修职业()
	if 显式 == 维修名:
		return 维修名
	if u is Dictionary:
		if str(u.get("职业", "")) == 维修名 or str(u.get("单机牌组职业", "")) == 维修名:
			return 维修名
		if J.truthy(u.get("维修")) or J.truthy(u.get("单机牌组维修")):
			return 维修名
	if 是维修机体(u, ctx):
		return 维修名
	if 显式 != "":
		return 显式
	if u is Dictionary and J.truthy(u.get("职业")):
		return str(u.get("职业"))
	return ""

## 别名（调用点想写「职业Of」的用这个）。
static func 职业Of(u: Variant, ctx: Variant = null) -> String:
	return unit_class(u, ctx)

## ======================== ★ A6a：拉米亚双势力（主 ATX / 副 影世界） ========================
## 数据里已经是这个形状（`data/js/10-数据.json` 的 A3：`tags.势力 = ATX` / `tags.副势力 = 影世界`），
## 这里只把「副势力」读出来给**势力牌能不能打**的判定用（最小改动，不动任何既有势力判定）。
## 三种认法：单位上的 `副势力` → `tags.副势力` → 模板上的 `副势力`。
static func 副势力(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	if J.truthy((u as Dictionary).get("副势力")):
		return str((u as Dictionary).get("副势力"))
	var ut = (u as Dictionary).get("tags")
	if ut is Dictionary and J.truthy((ut as Dictionary).get("副势力")):
		return str((ut as Dictionary).get("副势力"))
	var 键 := _键Of(u)
	var tpl = DataFn.tplOf(键) if 键 != "" else null
	var tt = tpl.get("tags") if tpl != null else null
	if tt is Dictionary and J.truthy((tt as Dictionary).get("副势力")):
		return str((tt as Dictionary).get("副势力"))
	return ""

## 这台机体能打的**势力牌归属们**：`[主势力, 副势力]`（副势力为空 / 与主势力相同 → 只有一个）。
static func 势力们(u: Variant) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 主 := str(J.or_(J.or_(J.g((u as Dictionary).get("tags"), "势力"), (u as Dictionary).get("势力")), ""))
	if 主 == "":
		var 键 := _键Of(u)
		var tpl = DataFn.tplOf(键) if 键 != "" else null
		var tt = tpl.get("tags") if tpl != null else null
		主 = str(J.or_(J.g(tt, "势力"), ""))
	if J.truthy(主):
		出.append(主)
	var 副 := 副势力(u)
	if J.truthy(副) and not J.inc(出, 副):
		出.append(副)
	return 出

static func makeUnits(编成: Array, side: String) -> Array:
	var out := []
	var 已用 := {}
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
		var 实例键: Variant = 下一个键(str(键), 已用) if side == "enemy" else null
		var u := makeUnit(键, side, float(位), float(等级), 强化, 比例, 层, 实例键)
		if J.truthy(s.get("词条")):
			Traits.词条到单位([u], {"词条": s.词条, "层": 层})
		out.append(u)
	return out
