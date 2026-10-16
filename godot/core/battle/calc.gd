## 20-战斗计算.js：命中 / 暴击 / 伤害管线（弱点 → 装甲 → 防御 → 公式 → 屏障 → λ力场 → 护盾）/ 武器冷却 / 标定经济 / resolveAttack。
## 「步骤说明文字」（c.steps，只给界面预告用）没有移植；规则与副作用一条不少。
class_name Calc
extends RefCounted

const STAT_KEY := {"格斗": "melee", "射击": "shoot", "觉醒": "awaken", "防御": "defense"}

static func statNames(w: Dictionary) -> PackedStringArray:
	return J.s(J.or_(w.get("stat"), "射击")).split("+")

static func statVal(u: Dictionary, k: String) -> float:
	if k == "觉醒":
		return Fac.势力觉醒值(u)
	var key = STAT_KEY.get(k)
	var v = u.get(key) if key != null else null
	return float(v) if v != null else 100.0

static func atkStat(u: Dictionary, w: Dictionary) -> float:
	var t := 0.0
	for k in statNames(w):
		t += statVal(u, k)
	return J.round(t * float(J.or_(w.get("statMul"), 1.0)))

static func buffSum(u: Variant, k: String) -> float:
	return J.sum_field(J.or_(u.get("buffs"), []) if u != null else [], k)

static func effArmor(u: Dictionary) -> float:
	return maxf(0.0, J.round(float(u.armor) * (1.0 + Fac.势力装甲(u) / 100.0) * maxf(0.0, 1.0 + buffSum(u, "armorPct") / 100.0)) - J.num0(u.get("armorCut")))

static func breakSum(u: Dictionary) -> float:
	var t := 0.0
	for b in J.or_(u.get("debuffs"), []):
		t += J.num(b.get("pct"))
	return t

static func defMul(u: Dictionary) -> float:
	return maxf(0.0, 1.0 - breakSum(u) / 100.0)

static func critMul(att: Variant) -> float:
	return maxf(1.0, 2.0 + buffSum(att, "critX"))

static func 残月必中(w: Variant) -> bool:
	return w != null and J.truthy(w.get("友军攻击后追加"))

static func isSure(w: Dictionary) -> bool:
	return w.get("fire") == "map" or w.get("fire") == "passive" or 残月必中(w)

static func abilOn(u: Variant, k: Variant) -> bool:
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, k)

static func shieldOn(u: Variant) -> bool:
	return u != null and J.num(u.get("shield")) > 0 and J.num(u.get("shieldHp")) > 0

static func lsLeft(u: Dictionary, turn: Variant) -> float:
	return 2.0 if not J.same(u.get("lsTurn"), turn) else 2.0 - J.num0(u.get("lsCount"))

static func hitRate(att: Dictionary, w: Dictionary, def: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if isSure(w):
		return {"hit": 100.0, "raw": 100.0, "eva": 0.0, "sure": true}
	var 尖兵闪 := 0.0
	if Reach.职业是(def, "尖兵") and not J.same(def.get("尖兵闪避Turn"), opts.get("turn")):
		尖兵闪 = Params.尖兵首闪值(def)
	var eva := maxf(0.0, float(def.eva) - J.num0(def.get("dodgePen"))) + buffSum(def, "eva") + J.num0(def.get("moveEva")) + 尖兵闪 + Fac.势力闪避(def)
	var 隐匿 := Params.隐匿惩罚值(def, w)
	var ctx = opts.get("ctx")
	var 兰斯命中 := Params.兰斯命中修正(att, def, w, ctx)
	var 总攻命中 := 0.0
	if Params.气势总攻开() and ctx != null and ctx.get("当前战术") == "总攻" and att.get("side") == "ally":
		总攻命中 = J.num0(Params.气势总攻参数().get("总攻命中加"))
	var 职排命中 := Params.职业排位命中修正(att, def, w, ctx)
	var base = J.nz(opts.get("baseHit"), w.get("hit"))
	var h := float(base) - eva + J.round((float(J.nz(att.get("aim"), 160.0)) - 160.0) / 2.0) + buffSum(att, "hit") + J.num0(opts.get("blockPenalty")) - 隐匿 + 总攻命中 + 兰斯命中 + 职排命中
	return {"hit": J.clamp(J.round(h), 0, 100), "raw": J.round(h), "eva": eva, "尖兵闪": 尖兵闪, "隐匿": 隐匿, "兰斯命中": 兰斯命中}

static func critRate(w: Dictionary, att: Variant) -> float:
	if isSure(w):
		return 0.0
	var 兰斯暴击 := Params.兰斯暴击修正(att, w)
	var 职排暴击 := Params.职业排位暴击修正(att, w)
	return J.clamp(10.0 + (J.num0(att.get("critBase")) if att != null else 0.0) + J.num0(w.get("critMod")) + buffSum(att, "crit") + (10.0 if Reach.职业是(att, "狙击") else 0.0) + 兰斯暴击 + 职排暴击, 0, 100)

static func weakList(def: Dictionary, w: Variant, o: Dictionary = {}) -> Array:
	if w == null:
		return []
	var out := []
	var 免直 := J.num(def.get("免直射物理"))
	if is_finite(免直) and 免直 > 0 and w.get("fire") == "direct" and w.get("dmgType") == "物理":
		out.append(["直射物理", -minf(95.0, 免直)])
	if not J.truthy(def.get("weak")):
		return out
	var weak: Dictionary = def.weak
	for k in weak.keys():
		var v = weak[k]
		var ok := false
		if k == "光束" or k == "物理":
			ok = w.get("dmgType") == k
		elif k == "近战":
			ok = w.get("fire") == "melee"
		elif k == "直射":
			ok = w.get("fire") == "direct"
		elif k == "曲射":
			ok = w.get("fire") == "indirect" and not isSure(w)
		elif k == "范围":
			ok = isSure(w)
		elif k == "暴击":
			ok = J.truthy(o.get("crit"))
		elif k == "多段":
			ok = w.get("special") == "multi" or J.num(w.get("hits")) > 1
		if ok:
			out.append([k, v])
	return out

static func 护卫减伤值(u: Variant) -> float:
	var v = u.get("护卫减伤") if u != null else null
	var n := J.num(v)
	return n if (is_finite(n) and n > 0) else 0.0

static func 同侧还有别人(u: Variant, ctx: Variant) -> bool:
	if u == null or ctx == null:
		return false
	var 们: Array = J.or_(ctx.allies if u.side == "ally" else ctx.enemies, [])
	return J.some(们, func(x): return not is_same(x, u) and x != null and x.hp > 0)

static func statCoef(atk: float, D: float) -> float:
	return 1.0 + (atk - D) / 100.0

## 伤害管线。返回 c（含 dmg / nullified / 兰斯倍率 等）。preview 为真时屏障 / 力场 / 护盾不扣次数与数值。
static func dmgCore(att: Variant, w: Dictionary, def: Dictionary, o: Dictionary = {}) -> Dictionary:
	var ctx = J.or_(o.get("ctx"), null)
	var defending: bool
	if J.truthy(o.get("不带防御加成")):
		defending = false
	else:
		defending = J.truthy(o.get("defending")) or J.truthy(def.get("defending")) or Btl.按防御结算(def, ctx)
	var c := {
		"att": att, "def": def, "w": w, "preview": o.get("preview") != false, "crit": J.truthy(o.get("crit")),
		"turn": J.or_(o.get("turn"), 0.0), "defMul": defMul(def), "nullified": false, "ctx": ctx, "defending": defending,
	}
	var special: bool = w.get("dmgType") == "特殊"
	var ign := J.truthy(w.get("ignoreDef"))
	var useStat: bool = o.get("useStat") != false
	var W := float(o.power)
	var wk := weakList(def, w, c)
	if not wk.is_empty():
		var pos := 0.0
		var neg := 0.0
		for e in wk:
			if float(e[1]) > 0:
				pos += float(e[1])
			elif float(e[1]) < 0:
				neg += float(e[1])
		neg *= 0.0 if ign else c.defMul
		var v := maxf(-95.0, pos + neg)
		if v != 0:
			W *= 1.0 + v / 100.0
	if c.crit:
		W *= critMul(att)
	W = J.round(W)
	var A := 0.0
	if not special and not ign:
		A = J.round(effArmor(def) * c.defMul)
	var 伤害加成 := buffSum(att, "dmg") if (useStat and att != null) else 0.0
	var atk := (atkStat(att, w) if (useStat and att != null) else 0.0) + 伤害加成
	var D := 0.0
	if not special and not ign:
		if useStat and J.truthy(def.get("defense")):
			D += float(def.defense)
		# —— REDUCTIONS 第 2 段（防御值类，顺序与 JS 表一致）——
		if c.defending:
			D += 50.0                                                       # guard 防御姿态
		if w.get("dmgType") == "物理" and buffSum(def, "physRed") > 0:
			D += buffSum(def, "physRed")                                    # physRed 物理减免
		if buffSum(def, "def") != 0:
			D += buffSum(def, "def")                                        # buffDef 防御增益
		if buffSum(def, "red") > 0:
			D += minf(90.0, buffSum(def, "red"))                            # relicRed 减伤
		if Fac.势力防御(def) > 0:
			D += Fac.势力防御(def)                                          # factionDef 势力防御
		if 护卫减伤值(def) > 0 and 同侧还有别人(def, ctx):
			D += 护卫减伤值(def)                                            # guardRed 护卫减伤
		if Params.中枢重装防御加成(def) > 0:
			D += Params.中枢重装防御加成(def)                                # lanceDef 中枢固守
		if c.defMul < 1 and D != 0:
			D = J.round(D * c.defMul)
	var coef := statCoef(atk, D)
	var base := maxf(0.0, W - A)
	c.dmg = maxf(10.0, J.round(base * coef))
	if not c.nullified:
		var 兰斯倍 := Params.兰斯伤害倍率(att, def, w, o)
		var 职排倍 := Params.职业排位伤害倍率(att, def, w, o)
		var 排位倍 := 兰斯倍 * 职排倍
		if 排位倍 != 1:
			c.dmg = maxf(10.0, J.round(float(c.dmg) * 排位倍))
			c.兰斯倍率 = 兰斯倍
			if 职排倍 != 1:
				c.职业排位倍率 = 职排倍
	if ign:
		return c
	# —— REDUCTIONS 第 1 / 3 / 4 段（按 1 → 3 → 4 的顺序）——
	# 1 能量屏障：≤2500 无效化
	if abilOn(def, "barrier") and J.num(def.get("barrierLeft")) > 0 and float(c.dmg) <= 2500:
		c.dmg = 0.0
		c.nullified = true
		if not c.preview:
			def.barrierLeft = float(def.barrierLeft) - 1.0
		c.dmg = maxf(0.0, J.round(c.dmg))
		return c
	# 3 λ 力场
	if float(c.dmg) > 0 and abilOn(def, "lambdaShield") and lsLeft(def, c.turn) > 0:
		var a := J.round(3000.0 * c.defMul)
		c.dmg = maxf(0.0, float(c.dmg) - a)
		if not c.preview:
			if not J.same(def.get("lsTurn"), c.turn):
				def.lsTurn = c.turn
				def.lsCount = 0.0
			def.lsCount = J.num0(def.get("lsCount")) + 1.0
		c.dmg = maxf(0.0, J.round(c.dmg))
	# 4 护盾
	if float(c.dmg) > 0 and shieldOn(def):
		var a2 := minf(float(c.dmg), float(def.shieldHp))
		c.dmg = float(c.dmg) - a2
		if not c.preview:
			def.shieldHp = float(def.shieldHp) - a2
		c.dmg = maxf(0.0, J.round(c.dmg))
	return c

## 按等级取武器的某项（升级档覆盖）
static func wv(u: Variant, w: Dictionary, key: String) -> Variant:
	var v = w.get(key)
	for up in J.or_(w.get("upgrades"), []):
		if float(u.lv) >= float(up.lv) and up.get(key) != null:
			v = up[key]
	return v

static func expectedDamage(att: Dictionary, def: Dictionary, w: Dictionary, opts: Dictionary = {}) -> float:
	var hits := maxf(1.0, J.num0(w.get("hits")) if J.truthy(w.get("hits")) else 1.0)
	var hr := float(hitRate(att, w, def, {"blockPenalty": J.num0(opts.get("blockPenalty")), "ctx": opts.get("ctx")}).hit) / 100.0
	var crit := 1.0 + critRate(w, att) / 100.0
	var dmg := float(dmgCore(att, w, def, {"power": Params.威力取档(att, w, "power"), "preview": true, "turn": J.or_(opts.get("turn"), 0.0), "ctx": opts.get("ctx")}).dmg)
	return hr * dmg * crit * hits

static func startCdOf(w: Dictionary) -> float:
	if w.get("startCd") != null:
		return float(w.startCd)
	return Params.大招开场冷却() if J.num(w.get("unlock")) >= 20 else 0.0

static func weaponPlayable(w: Variant) -> bool:
	if w != null and J.truthy(w.get("友军攻击后追加")) and not Params.残月武器可主动(w):
		return false
	var fire = J.g(w, "fire")
	var special = null if (w != null and J.truthy(w.get("友军攻击后追加"))) else J.g(w, "special")
	if fire == "passive" or fire == "device":
		return false
	if J.truthy(special) and special != "multi" and special != "chain":
		return false
	if fire == "support" and not Reach.hasSupportField(w):
		return false
	return true

static func usableWeapons(u: Dictionary, ctx: Variant) -> Array:
	return J.filter(J.or_(u.get("weapons"), []), func(e):
		var w = e.t
		if not weaponPlayable(w):
			return false
		if float(u.lv) < J.num(Params.残月武器运行期解锁(w)):
			return false
		if e.get("uses") != null and float(e.uses) <= 0:
			return false
		if J.num(e.get("cd")) > 0:
			return false
		if ctx != null and ctx.get("turn") != null and float(ctx.turn) < float(e.readyTurn):
			return false
		if not (J.num(w.get("power")) > 0) and not Reach.isHealKind(Reach.rangeKindOf(w)) and not Reach.isSupportKind(Reach.rangeKindOf(w)):
			return false
		return true)

static func spendWeapon(_u: Dictionary, entry: Variant) -> void:
	if entry == null:
		return
	var 门 := J.num(Params.残月武器运行期解锁(entry.t))
	var 冷却 := maxf(J.num0(entry.t.get("cd")), Params.大招普攻冷却()) if 门 >= 20 else J.num0(entry.t.get("cd"))
	if 冷却 != 0:
		entry.cd = 冷却
	if entry.get("uses") != null:
		entry.uses = float(entry.uses) - 1.0
	entry.词条已延 = false

static func healAmount(u: Dictionary, w: Dictionary) -> float:
	return J.round(float(w.power) * float(u.shoot) / 100.0 * Params.职业排位修理倍率(u))

# ======================== 标定经济 ========================
static func 标定经济参数() -> Dictionary:
	var v = Db.T.战斗结构.get("标定经济")
	return v if v is Dictionary else {}

static func 标定经济开() -> bool:
	return not (标定经济参数().get("开") == false)

static func 标定数(键: String, 默认值: float) -> float:
	var v := J.num(标定经济参数().get(键))
	return v if is_finite(v) else 默认值

static func 标定层数上限() -> float:
	return maxf(1.0, J.round(标定数("层数上限", 3)))

static func _子(名: String) -> Dictionary:
	return J.or_(标定经济参数().get(名), {})

static func 标定狙击暴击() -> float:
	var v := J.num(_子("狙击").get("暴击加成"))
	return v if is_finite(v) else 25.0

static func 标定狙击倍率() -> float:
	var v := J.num(_子("狙击").get("伤害倍率"))
	return v if (is_finite(v) and v > 0) else 1.3

static func 标定范围每层() -> float:
	var v := J.num(_子("范围引爆").get("每层比例"))
	return v if (is_finite(v) and v > 0) else 0.15

static func 标定狙击消耗层() -> float:
	var v := J.num(_子("狙击").get("消耗层数"))
	return maxf(1.0, J.round(v)) if is_finite(v) else 1.0

static func 标定点名全场上限() -> float:
	var v := J.num(_子("指挥点名").get("每回合全场上限"))
	return maxf(1.0, J.round(v)) if is_finite(v) else 1.0

static func 标定经济条(u: Variant) -> Variant:
	var 列 = J.or_(u.get("标定经济") if u != null else null, [])
	return 列[0] if not 列.is_empty() and 列[0] != null else null

static func 标定经济层数(u: Variant) -> float:
	var d = 标定经济条(u)
	return maxf(0.0, J.num0(d.get("层数"))) if d != null else 0.0

static func 标定经济拿条(u: Variant) -> Variant:
	if u == null:
		return null
	var 有 = 标定经济条(u)
	if 有 != null:
		return 有
	var d := {"层数": 0.0, "上限": 标定层数上限(), "来源们": []}
	u.标定经济 = J.concat(J.or_(u.get("标定经济"), []), [d])
	return d

static func 标定来源名(d: Variant) -> Array:
	var 名们 := []
	for g in J.or_(J.g(d, "来源们"), []):
		var n = J.or_(J.or_(J.g(g, "名"), J.g(g, "键")), "") if g != null else ""
		if J.truthy(n):
			名们.append(n)
	return J.uniq(名们)

static func 标定经济产标(ctx: Variant, 攻击者: Variant, 目标: Variant) -> float:
	if ctx == null or 攻击者 == null or 目标 == null:
		return 0.0
	if not 标定经济开():
		return 0.0
	if not Reach.职业是(攻击者, "特种"):
		return 0.0
	if 目标.side == 攻击者.side:
		return 0.0
	var 上限 := 标定层数上限()
	var d = 标定经济拿条(目标)
	if d == null:
		return 0.0
	d.上限 = 上限
	var 前 := maxf(0.0, J.num0(d.get("层数")))
	if 前 >= 上限:
		Btl.pushLog(ctx, "〔标定〕%s（特种）又标定了 %s，但它已经到层数上限 %s 层了（不再加）" % [攻击者.name, 目标.name, J.s(上限)], {
			"类型": "标定", "事件": "预定到上限", "结果": "到上限",
			"单位": 攻击者.key, "单位方": 攻击者.side, "单位位": 攻击者.slot,
			"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot, "层数": 前, "层数上限": 上限, "生产": "特种",
		})
		return 前
	if not J.some(J.or_(d.get("来源们"), []), func(g): return g != null and g.get("键") == 攻击者.key):
		d.来源们 = J.concat(J.or_(d.get("来源们"), []), [{"键": 攻击者.key, "名": 攻击者.name, "方": 攻击者.side, "怎么来的": "特种"}])
	d.层数 = 前 + Params.特种产标层数(攻击者)
	Btl.pushLog(ctx, "〔标定〕%s（特种）命中 → %s +1 层标定：%s/%s 层（来自 %s）" % [攻击者.name, 目标.name, J.s(d.层数), J.s(上限), "、".join(标定来源名(d))], {
		"类型": "标定", "事件": "产标", "结果": "挂标定", "生产": "特种",
		"单位": 攻击者.key, "单位方": 攻击者.side, "单位位": 攻击者.slot,
		"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot,
		"层数": d.层数, "层数上限": 上限, "来源": 标定来源名(d), "来源键": J.or_(d.get("来源们"), []).map(func(g): return g.get("键")),
	})
	return float(d.层数)

static func 标定经济点名(ctx: Variant) -> float:
	if ctx == null or not 标定经济开():
		return 0.0
	var 上限 := 标定层数上限()
	var 全场上限 := 标定点名全场上限()
	var 点名了 := 0.0
	var 已点 := 0.0
	for 方 in ["ally", "enemy"]:
		if 已点 >= 全场上限:
			break
		for c in Units.livingOf(方, ctx):
			if 已点 >= 全场上限:
				break
			if not Reach.职业是(c, "指挥"):
				continue
			var 候选 := Units.livingOf(Units.otherSide(方), ctx).filter(func(t): return t.hp > 0 and 标定经济层数(t) < 上限)
			J.sort(候选, func(a, b):
				var d1 := 标定经济层数(a) - 标定经济层数(b)
				return d1 if d1 != 0 else float(a.slot) - float(b.slot))
			if 候选.is_empty():
				continue
			var t = 候选[0]
			var d = 标定经济拿条(t)
			if d == null:
				continue
			d.上限 = 上限
			var 前 := maxf(0.0, J.num0(d.get("层数")))
			if not J.some(J.or_(d.get("来源们"), []), func(g): return g != null and g.get("键") == c.key):
				d.来源们 = J.concat(J.or_(d.get("来源们"), []), [{"键": c.key, "名": c.name, "方": c.side, "怎么来的": "指挥号令"}])
			d.层数 = 前 + 1.0
			已点 += 1.0
			var 尾 := "；每回合全场只点名 %s 台" % J.s(全场上限) if 全场上限 > 0 else ""
			Btl.pushLog(ctx, "〔标定〕%s（指挥）号令点名 → %s +1 层标定：%s/%s 层（来自 %s%s）" % [c.name, t.name, J.s(d.层数), J.s(上限), "、".join(标定来源名(d)), 尾], {
				"类型": "标定", "事件": "点名", "结果": "指挥点名", "生产": "指挥",
				"单位": c.key, "单位方": c.side, "单位位": c.slot,
				"目标": t.key, "目标方": t.side, "目标位": t.slot,
				"层数": d.层数, "层数上限": 上限, "来源": 标定来源名(d), "来源键": J.or_(d.get("来源们"), []).map(func(g): return g.get("键")),
				"全场上限": 全场上限,
			})
			点名了 = float(d.层数)
	return 点名了

static func 标定经济狙击加成(目标: Variant) -> Variant:
	if 目标 == null or not 标定经济开():
		return null
	if 标定经济层数(目标) <= 0:
		return null
	return {"暴击加成": 标定狙击暴击(), "伤害倍率": 标定狙击倍率()}

static func 标定经济消耗一(目标: Variant) -> Dictionary:
	var d = 标定经济条(目标)
	var 要 := 标定狙击消耗层()
	if d == null:
		return {"消耗": 0.0, "剩": 0.0}
	var 前 := maxf(0.0, J.num0(d.get("层数")))
	var 消耗 := minf(前, 要)
	d.层数 = 前 - 消耗
	return {"消耗": 消耗, "剩": d.层数}

static func 标定经济引爆(ctx: Variant, 攻击者: Variant, 目标: Variant, w: Variant, 主伤害: Variant) -> Variant:
	if ctx == null or 攻击者 == null or 目标 == null:
		return null
	if not 标定经济开():
		return null
	if 目标.side == 攻击者.side:
		return null
	var kind = Reach.rangeKindOf(w) if w != null else null
	if not J.truthy(kind) or not Reach.isAreaKind(kind):
		return null
	var d = 标定经济条(目标)
	if d == null:
		return null
	var 层数 := maxf(0.0, J.num0(d.get("层数")))
	if 层数 <= 0:
		return null
	var 每层 := 标定范围每层()
	var 总 := J.round(J.num0(主伤害) * 每层 * 层数)
	var 来源 := 标定来源名(d)
	d.层数 = 0.0
	var 剩HP := maxf(0.0, float(目标.hp) - 总)
	var 公式 := "%s × %s × %s 层 = %s" % [J.s(主伤害), J.s(每层), J.s(层数), J.s(总)]
	if Params.气势总攻开() and 攻击者.side == "ally":
		Btl.加气势(ctx, J.or_(J.num0(Params.气势总攻参数().get("标定引爆加")), 10.0) if J.num0(Params.气势总攻参数().get("标定引爆加")) != 0 else 10.0)
	Btl.pushLog(ctx, "〔标定〕%s 的标定 → %s【%s】引爆 %s 层，溅射 %s（%s）" % [J.or_("、".join(来源), "（无来源）"), 攻击者.name, w.name, J.s(层数), J.s(总), 公式], {
		"类型": "标定", "事件": "引爆", "结果": "范围引爆",
		"单位": 攻击者.key, "单位方": 攻击者.side, "单位位": 攻击者.slot,
		"目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot,
		"层数": 层数, "消耗层数": 层数, "标定伤害": 总, "伤害": 总, "来源": 来源, "剩余HP": 剩HP, "公式": 公式, "武器": w.name,
		"产标方们": J.or_(d.get("来源们"), []).map(func(g): return g.get("方") if g != null else null),
		"产标位们": J.or_(d.get("来源们"), []).map(func(g): return J.or_(g.get("键"), null) if g != null else null),
	})
	return {"层数": 层数, "伤害": 总, "来源": 来源, "剩余HP": 剩HP, "公式": 公式}

static func 标定来源词(d: Variant) -> String:
	var 名 := 标定来源名(d)
	return "%s 的标定" % "、".join(名) if not 名.is_empty() else "标定"

static func 标定连锁文本(引爆者: Dictionary, _目标: Variant, 来源词: String, 伤害: Variant, 打死了: bool) -> String:
	return "%s → %s 引爆 %s%s" % [来源词, 引爆者.name, J.s(伤害), "!" if 打死了 else ""]

static func 标定经济记录(ctx: Variant, 攻击者: Variant, 目标: Variant, 一: Variant, 记号: Variant) -> void:
	if ctx == null or not J.truthy(记号) or not J.truthy(记号.get("消耗")):
		return
	var 死: bool = 目标 != null and float(目标.hp) <= 0
	var 范围: bool = 记号.get("怎么引爆") == "范围"
	Btl.pushLog(ctx, "〔标定〕%s" % 标定连锁文本(攻击者, 目标, J.or_(记号.get("来源词"), "标定"), J.or_(记号.get("消耗伤害"), 0.0), 死), {
		"类型": "标定", "事件": "引爆连锁" if 范围 else "狙击连锁",
		"结果": "范围引爆" if 范围 else "狙击引爆",
		"单位": 记号.引爆键 if 记号.get("引爆键") != null else J.g(攻击者, "key"),
		"单位方": 记号.引爆方 if 记号.get("引爆方") != null else J.g(攻击者, "side"),
		"单位位": 记号.引爆位 if 记号.get("引爆位") != null else J.g(攻击者, "slot"),
		"目标": J.g(目标, "key"), "目标方": J.g(目标, "side"), "目标位": J.g(目标, "slot"),
		"层数": 记号.消耗, "消耗层数": 记号.消耗, "标定伤害": J.or_(记号.get("消耗伤害"), 0.0),
		"来源": J.or_(记号.get("来源"), []), "武器": J.or_(J.g(一, "武器"), null), "剩余HP": 目标.hp if 目标 != null else null,
		"暴击加成": J.or_(记号.get("暴击加成"), 0.0), "伤害倍率": J.or_(记号.get("伤害倍率"), 1.0), "公式": J.or_(记号.get("公式"), null),
	})

static func 命中段步长(att: Dictionary, w: Dictionary, 段: Dictionary) -> float:
	return Fac.段内命中加成(att, w, 段)

## 一次攻击（多段逐段结算）。返回 {文本, 字段}。随机数只在命中判定（非必中）与暴击判定时抽取。
static func resolveAttack(att: Dictionary, def: Dictionary, w: Dictionary, ctx: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var rng: Mulberry32 = ctx.rng
	var blockPenalty := J.num0(opts.get("blockPenalty"))
	var 原HP := float(def.hp)
	var 是总攻: bool = Params.气势总攻开() and ctx.get("当前战术") == "总攻" and att.get("side") == "ally"
	var 总攻乘子 := 1.0
	if 是总攻:
		总攻乘子 = J.num0(Params.气势总攻参数().get("总攻伤害倍率"))
		if 总攻乘子 == 0:
			总攻乘子 = 1.35
	var 倍率 := 总攻乘子 if opts.get("伤害倍率") == null else float(opts.伤害倍率)
	var 基准倍率 := (倍率 / 总攻乘子) if (是总攻 and 总攻乘子 > 0) else 倍率
	var 总攻增伤合计 := 0.0
	var 掩护吸收合计 := 0.0
	var 掩护减伤合计 := 0.0
	var 威力倍率 := 1.0 if opts.get("威力倍率") == null else float(opts.威力倍率)
	var 本发威力 := float(Params.威力取档(att, w, "power"))
	var sure := isSure(w)
	var hits := maxf(1.0, J.num0(w.get("hits")) if J.truthy(w.get("hits")) else 1.0)
	var rolls := []
	var total := 0.0
	var landed := 0.0
	var crits := 0.0
	var p := float(w.hit)
	var 尖兵加成 := 0.0
	if Reach.职业是(def, "尖兵") and not J.same(def.get("尖兵闪避Turn"), ctx.turn):
		尖兵加成 = Params.尖兵首闪值(def)
	var 按防: bool = J.truthy(opts.get("defending")) or J.truthy(def.get("defending")) or Btl.按防御结算(def, ctx)
	var 少挨合计 := 0.0
	var 隐匿罚 := Params.隐匿惩罚值(def, w)
	var 被挡 := false
	if def.get("slot") != null and Reach.rangeKindOf(w) == Reach.KIND_DIRECT():
		被挡 = Fm.被挡吗(def.slot, Units.livingOf(def.side, ctx).map(func(x): return x.slot))
	var 加成 = 标定经济狙击加成(def) if (not sure and Reach.职业是(att, "狙击")) else null
	var 标定记号 = null
	if Params.动作QTE开() or J.truthy(opts.get("强制QTE")):
		push_error("动作QTE 已不迁移（数据里应为关闭）")
	for i in int(hits):
		var 步长 := 命中段步长(att, w, {"段号": float(i + 1), "段数": hits})
		var q := float(hitRate(att, w, def, {"baseHit": p, "blockPenalty": blockPenalty, "turn": ctx.turn, "ctx": ctx}).hit)
		var hit := sure or rng.next_float() * 100.0 < q
		if hit:
			var cr := (not sure) and rng.next_float() * 100.0 < critRate(w, att)
			var 段标 = null
			if cr and 加成 != null and 标定记号 == null:
				var 条 = 标定经济条(def)
				段标 = {"怎么引爆": "狙击", "暴击加成": 加成.暴击加成, "伤害倍率": 加成.伤害倍率, "消耗": 0.0, "消耗伤害": 0.0,
					"层数": 标定经济层数(def), "来源": 标定来源名(条), "来源词": 标定来源词(条),
					"引爆键": att.key, "引爆方": att.side, "引爆位": att.slot}
				var 消 := 标定经济消耗一(def)
				段标.消耗 = 消.消耗
				段标.标定剩 = 消.剩
				段标.公式 = "（暴击段 ×%s）" % J.s(段标.伤害倍率)
			if 段标 != null and Params.气势总攻开() and att.get("side") == "ally":
				var 加 := J.num0(Params.气势总攻参数().get("标定引爆加"))
				Btl.加气势(ctx, 加 if 加 != 0 else 10.0)
			var 段倍 := float(段标.伤害倍率) if 段标 != null else 1.0
			var 无防 := 0.0
			if 按防:
				无防 = float(dmgCore(att, w, def, {"power": 本发威力 * 威力倍率, "crit": cr, "preview": true, "turn": ctx.turn, "不带防御加成": true, "ctx": ctx, "被挡": 被挡}).dmg)
			var c := dmgCore(att, w, def, {"power": 本发威力 * 威力倍率, "crit": cr, "preview": false, "turn": ctx.turn, "defending": opts.get("defending"), "ctx": ctx, "被挡": 被挡})
			var d := J.round(float(c.dmg) * 倍率 * 段倍)
			var 掩 := 0.0 if J.truthy(opts.get("preview")) else Params.兰斯掩护减免(def, w, ctx, 被挡)
			if 掩 > 0:
				var 原 := dmgCore(att, w, def, {"power": 本发威力 * 威力倍率, "crit": cr, "preview": true, "turn": ctx.turn, "defending": opts.get("defending"), "ctx": ctx, "被挡": 被挡, "不带掩护": true})
				var 基 := J.round(float(原.dmg) * 倍率 * 段倍)
				var 减 := Params.掩护减免值(基, d)
				if 减 > 0:
					掩护减伤合计 += 减
			if 是总攻:
				var 基准d := J.round(float(c.dmg) * 基准倍率 * 段倍)
				总攻增伤合计 += maxf(0.0, d - 基准d)
			if 按防:
				少挨合计 += maxf(0.0, J.round(无防 * 倍率) - d)
			if J.num(def.get("掩护盾")) > 0 and d > 0:
				var 吸 := minf(float(def.掩护盾), d)
				d -= 吸
				if not J.truthy(opts.get("preview")):
					def.掩护盾 = float(def.掩护盾) - 吸
				掩护吸收合计 += 吸
			total += d
			landed += 1.0
			if cr:
				crits += 1.0
			if 段标 != null:
				段标.消耗伤害 = float(段标.消耗伤害) + maxf(0.0, d - J.round(float(c.dmg) * 倍率))
				标定记号 = 段标
			rolls.append("第 %d 段（%s）%s%s" % [i + 1, "必中" if sure else J.s(q) + "%", "暴击 " if cr else "", J.s(d)])
			if c.nullified:
				break
			var 减2 := 步长 if 步长 != 0 else J.num0(w.get("step"))
			if 减2 != 0:
				p -= 减2
		else:
			rolls.append("第 %d 段（%s%%）未中" % [i + 1, J.s(q)])
			Fac.势力逐段未命中(ctx, att, def, w, {"段号": float(i + 1), "段数": hits, "本段命中率": q})
			var 加2 := 步长 if 步长 != 0 else J.num0(w.get("step"))
			if 加2 != 0:
				p += 加2
		var 溅 := J.num0(标定记号.get("溅射")) if 标定记号 != null else 0.0
		if float(def.hp) - total - 溅 <= 0:
			break
	def.hp = maxf(0.0, float(def.hp) - total)
	var 引爆 = 标定经济引爆(ctx, att, def, w, total)
	if 引爆 != null:
		def.hp = 引爆.剩余HP
	if not J.truthy(opts.get("preview")) and Params.气势总攻开():
		var 气参 := Params.气势总攻参数()
		var 阈 := J.num0(气参.get("受重击阈值"))
		if def.get("side") == "ally" and float(def.maxHp) > 0 and total >= float(def.maxHp) * (阈 if 阈 != 0 else 0.25):
			var 加3 := J.num0(气参.get("受重击加"))
			Btl.加气势(ctx, 加3 if 加3 != 0 else 10.0)
		if att.get("side") == "ally" and def.get("side") == "enemy" and 原HP > 0 and float(def.hp) <= 0:
			var 加4 := J.num0(气参.get("击破加"))
			Btl.加气势(ctx, 加4 if 加4 != 0 else 15.0)
	if 尖兵加成 != 0:
		def.尖兵闪避Turn = ctx.turn
	if landed > 0 and J.truthy(def.get("隐身中")):
		def.隐身中 = false
	var 特种减命中 := 0.0
	var 特种破甲 := 0.0
	if landed != 0 and Reach.职业是(att, "特种"):
		特种减命中 = float(Db.T.特种降命中值)
		def.buffs = J.or_(def.get("buffs"), []).filter(func(b): return b.get("src") != "特种")
		def.buffs.append({"src": "特种", "hit": -特种减命中, "剩余": 2.0})
		if Params.职业排位开() and J.is_int(att.get("slot")) and Fm.rowOfSlot(att.slot) == Fm.ROW_FRONT:
			特种破甲 = Params.职业排位数("特种前排破甲值", 25)
			if 特种破甲 > 0:
				def.buffs = J.or_(def.get("buffs"), []).filter(func(b): return b.get("src") != "特种破甲")
				def.buffs.append({"src": "特种破甲", "def": -特种破甲, "剩余": 2.0, "turns": 2.0})
	var 标定产 := 标定经济产标(ctx, att, def) if landed != 0 else 0.0
	var 挂上的debuff = null
	if landed != 0:
		挂上的debuff = Params.武器debuff(att.key, w.name, att)
		if 挂上的debuff != null:
			应用武器debuff(def, 挂上的debuff, w.name, att)
	var 段 := "%s/%s 段 " % [J.s(landed), J.s(hits)] if hits > 1 else ""
	var 文本: String
	if landed != 0:
		文本 = "%s【%s】→ %s：%s伤害 %s%s%s%s" % [att.name, w.name, def.name, 段, J.s(total),
			"（暴击 %s 次）" % J.s(crits) if crits != 0 else "",
			"（特种：对方命中 −%s，到下回合结束）" % J.s(特种减命中) if 特种减命中 != 0 else "",
			"（%s）" % debuff文字(挂上的debuff) if 挂上的debuff != null else ""]
	else:
		文本 = "%s【%s】→ %s：未命中（%s）" % [att.name, w.name, def.name, "；".join(rolls)]
	var 字段 := {
		"命中": landed > 0, "伤害": total, "段数": hits, "命中段数": landed, "暴击": crits, "目标剩余HP": def.hp,
		"特种减命中": 特种减命中, "debuff": 挂上的debuff, "详情": "；".join(rolls),
	}
	if 少挨合计 > 0:
		字段.防御少挨 = 少挨合计
	if 掩护吸收合计 > 0:
		字段.掩护吸收 = 掩护吸收合计
	if 掩护减伤合计 > 0:
		字段.掩护减伤 = 掩护减伤合计
	if 是总攻 and landed > 0:
		字段.总攻 = true
		字段.总攻增伤 = 总攻增伤合计
	if 隐匿罚 > 0 and landed == 0:
		字段.隐匿 = true
		字段.隐匿惩罚 = 隐匿罚
	if 特种破甲 > 0:
		字段.特种破甲 = 特种破甲
	if landed > 0 and att.get("近卫连斩追击Turn") != null and J.same(att.近卫连斩追击Turn, ctx.turn) and Params.职业排位开():
		字段.连斩追击 = true
	if 标定记号 != null or 引爆 != null or 标定产 != 0:
		if 标定记号 != null:
			字段.标定 = 标定记号
			字段.标定伤害 = 标定记号.消耗伤害
			字段.标定剩 = 标定记号.get("标定剩")
		elif 引爆 != null:
			字段.标定溅射 = 引爆.伤害
			字段.标定引爆 = 引爆.层数
			字段.标定来源 = 引爆.来源
		if 标定产 != 0:
			字段.标定产 = 标定产
	return {"文本": 文本, "字段": 字段}

static func 应用武器debuff(def: Dictionary, d: Dictionary, 武器名: Variant, att: Variant) -> String:
	var 源: String = J.s(d.src) if J.truthy(d.get("src")) else "%s(敌)" % J.s(武器名)
	var 剩余 := J.num(d.get("剩余")) if is_finite(J.num(d.get("剩余"))) else 2.0
	for b in J.or_(def.get("debuffs"), []):
		if b.get("src") == 源 and J.truthy(b.get("armorCut")):
			def.armorCut = maxf(0.0, J.num0(def.get("armorCut")) - float(b.armorCut))
	def.debuffs = J.or_(def.get("debuffs"), []).filter(func(b): return b.get("src") != 源)
	def.buffs = J.or_(def.get("buffs"), []).filter(func(b): return b.get("src") != 源)
	if J.truthy(d.get("hit")):
		def.buffs.append({"src": 源, "hit": d.hit, "剩余": 剩余})
	if J.truthy(d.get("pct")) or J.truthy(d.get("armorCut")):
		var 条 := {"src": 源, "pct": J.or_(d.get("pct"), 0.0), "剩余": 剩余}
		if J.truthy(d.get("armorCut")):
			条.armorCut = d.armorCut
			def.armorCut = J.num0(def.get("armorCut")) + float(d.armorCut)
		def.debuffs.append(条)
	if J.truthy(d.get("cd")):
		var n := maxf(1.0, J.round(J.num(d.cd)))
		for e in J.or_(def.get("weapons"), []):
			if Ai.isUltimate(e.t):
				e.cd = maxf(0.0, J.num0(e.get("cd")) + n)
	if J.truthy(d.get("自身")) and att != null:
		var 旧 = J.find(J.or_(att.get("buffs"), []), func(b): return b.get("src") == 源)
		if 旧 != null:
			for k in d.自身.keys():
				旧[k] = J.num0(旧.get(k)) + J.num(d.自身[k])
			旧.剩余 = 剩余
		else:
			att.buffs = J.concat(J.or_(att.get("buffs"), []), [J.merged({"src": 源, "剩余": 剩余}, d.自身)])
	return 源

static func debuff文字(d: Dictionary) -> String:
	var 们 := []
	if J.truthy(d.get("hit")):
		们.append("命中 %s" % J.s(d.hit))
	if J.truthy(d.get("pct")):
		们.append("破甲 −%s%%" % J.s(d.pct))
	if J.truthy(d.get("armorCut")):
		们.append("削装甲 %s" % J.s(d.armorCut))
	if J.truthy(d.get("cd")):
		们.append("大招冷却 +%s" % J.s(J.round(J.num(d.cd))))
	if J.truthy(d.get("自身")):
		var 项 := []
		for k in d.自身.keys():
			项.append(" %s +%s" % [k, J.s(d.自身[k])])
		们.append("自身%s" % "、".join(项))
	return "挂上 debuff：%s，到下回合结束" % "、".join(们)
