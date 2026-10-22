## 20-战斗计算.js：命中 / 暴击 / 伤害管线（弱点 → 装甲 → 防御 → 公式 → 屏障 → λ力场 → 护盾）/ 武器冷却 / 标定经济 / resolveAttack。
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

## 一次攻击里装甲能抵消多少（老公式与装甲池同一口径）。
static func 抵消甲(def: Dictionary, w: Dictionary) -> float:
	if w.get("dmgType") == "特殊" or J.truthy(w.get("ignoreDef")):
		return 0.0
	var A := J.round(effArmor(def) * defMul(def))
	var 甲免 := float(J.num0(w.get("ignoreArmorPct")))
	if 甲免 > 0.0 and 甲免 <= 1.0:
		A = J.round(A * (1.0 - 甲免))
	return A

static func critMul(att: Variant) -> float:
	return maxf(1.0, 2.0 + buffSum(att, "critX"))

static func 残月必中(w: Variant) -> bool:
	return w != null and J.truthy(w.get("友军攻击后追加"))

static func isSure(w: Dictionary) -> bool:
	# [必中] 武器自带 `必中` 键（拉米亚【Code：ATA】）也算必中。
	return w.get("fire") == "map" or w.get("fire") == "passive" or 残月必中(w) or J.truthy(w.get("必中"))

static func abilOn(u: Variant, k: Variant) -> bool:
	return u != null and J.is_arr(u.get("abilities")) and J.inc(u.abilities, k)

static func shieldOn(u: Variant) -> bool:
	return u != null and J.num(u.get("shield")) > 0 and J.num(u.get("shieldHp")) > 0

static func lsLeft(u: Dictionary, turn: Variant, ctx: Variant = null) -> float:
	var 顶 := λ次数上限(u, ctx)
	return 顶 if not J.same(u.get("lsTurn"), turn) else 顶 - J.num0(u.get("lsCount"))

## N3 λ 共振：同侧活着的「λ 力场 + λ共振」≥2 台 → 每回合减免 3 次（否则 2 次）。
static func λ次数上限(u: Dictionary, ctx: Variant) -> float:
	if not J.truthy(u.get("λ共振")) or not (ctx is Dictionary):
		return 2.0
	var 同侧: Array = J.or_(ctx.get("enemies") if u.get("side") == "enemy" else ctx.get("allies"), [])
	var n := 0
	for x in 同侧:
		if x is Dictionary and float(x.get("hp", 0.0)) > 0.0 and J.truthy(x.get("λ共振")) and abilOn(x, "lambdaShield"):
			n += 1
	return 3.0 if n >= 2 else 2.0

## λ 力场每下的减免量：单位写了 `λ减免` 就按它，否则 3000。
static func λ减免量(u: Dictionary) -> float:
	var v := J.num(u.get("λ减免"))
	return v if (is_finite(v) and v > 0.0) else 3000.0

static func hitRate(att: Dictionary, w: Dictionary, def: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if isSure(w):
		return {"hit": 100.0, "raw": 100.0, "eva": 0.0, "sure": true}
	var 尖兵闪 := 0.0
	if Reach.职业是(def, "尖兵") and not J.same(def.get("尖兵闪避Turn"), opts.get("turn")):
		尖兵闪 = Params.尖兵首闪值(def)
	var eva := maxf(0.0, float(def.eva) - J.num0(def.get("dodgePen"))) + buffSum(def, "eva") + J.num0(def.get("moveEva")) + 尖兵闪 + Fac.势力闪避(def)
	# [艾克赛琳·天然] 每个敌方阶段**第一次**被攻击时闪避 +30。
	eva += RuleHooks.汇总("闪避加成", [def, opts.get("ctx")])
	var 隐匿 := Params.隐匿惩罚值(def, w)
	var ctx = opts.get("ctx")
	var 兰斯命中 := Params.兰斯命中修正(att, def, w, ctx)
	var 总攻命中 := 0.0
	if Params.气势总攻开() and ctx != null and ctx.get("当前战术") == "总攻" and att.get("side") == "ally":
		总攻命中 = J.num0(Params.气势总攻参数().get("总攻命中加"))
	var 职排命中 := Params.职业排位命中修正(att, def, w, ctx)
	var base = J.nz(opts.get("baseHit"), w.get("hit"))
	var h := float(base) - eva + J.round((float(J.nz(att.get("aim"), 160.0)) - 160.0) / 2.0) + buffSum(att, "hit") + J.num0(opts.get("blockPenalty")) - 隐匿 + 总攻命中 + 兰斯命中 + 职排命中
	# 命中修正：赌神 −10 / 烟雾 −30 / 职业分类牌 / 塔斯克 / 响介·正面突破 / 天人（TRANS-AM + Veda 行动预测）。
	# **加法汇总后由下面 `J.round(h)` 统一 round 一次**，顺序见 `RuleHooks.顺序`。
	h += RuleHooks.汇总("命中修正", [att, def, w, ctx])
	h += RuleHooks.汇总("命中修正_附加", [att, def, w, ctx])
	# [秘银·ECM] 本回合敌方攻击秘银成员命中 −15。
	if ctx != null and att.get("side") == "enemy" and def.get("side") == "ally":
		h -= J.num0(ctx.get("本回合敌方命中秘银减命中"))
		# [武器范围v0.1·ECM] 前排 / 秘银两条防守型减命中。
		h -= J.num0(ctx.get("v3前排减命中"))
		if FacMith.是秘银(def):
			h -= J.num0(ctx.get("v3秘银减命中"))
	return {"hit": J.clamp(J.round(h), 0, 100), "raw": J.round(h), "eva": eva, "尖兵闪": 尖兵闪, "隐匿": 隐匿, "兰斯命中": 兰斯命中}

static func critRate(w: Dictionary, att: Variant, def: Variant = null, ctx: Variant = null) -> float:
	# [必中可暴击] 必中武器默认不暴击，带这个键的（洛克昂「最后的狙击」）例外。
	if isSure(w) and not J.truthy(w.get("必中可暴击")):
		return 0.0
	var 兰斯暴击 := Params.兰斯暴击修正(att, w)
	var 职排暴击 := Params.职业排位暴击修正(att, w)
	# [响介·正面突破] 近战打**对位（同列）**目标暴击 +10。
	var a6c暴击 := RuleHooks.汇总("暴击修正", [att, def, w, ctx]) if def != null else 0.0
	return J.clamp(10.0 + (J.num0(att.get("critBase")) if att != null else 0.0) + J.num0(w.get("critMod")) + buffSum(att, "crit") + (10.0 if Reach.职业是(att, "狙击") else 0.0) + 兰斯暴击 + 职排暴击 + a6c暴击, 0, 100)

## 「无视抗性」增益（艾克赛琳）。纯读；没有这个 buff = false。
static func 无视抗性(att: Variant) -> bool:
	if att == null or not (att is Dictionary):
		return false
	return buffSum(att, "无视抗性") > 0.0

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

# [武器范围v0.1] 见 协作/设计/武器范围规则 v0.1.md

## 攻击方 + 目标之间的真实距离（`1..6`）；任一侧没有 `slot` → 0。
static func 攻击距离(att: Variant, def: Variant) -> int:
	if not (att is Dictionary) or not (def is Dictionary):
		return 0
	if att.get("slot") == null or def.get("slot") == null:
		return 0
	return Fm.真实距离(float(att.slot), float(def.slot))

## 武器的【远距·N】词条 → `{触发, 阈值, 暴伤加成, 伤害倍率}`（没写 → 全默认）。
static func 远距判定(_ctx: Variant, att: Variant, def: Variant, w: Variant) -> Dictionary:
	var 空 := {"触发": false, "阈值": 0, "暴伤加成": 0.0, "伤害倍率": 1.0, "距离": 0}
	if not (w is Dictionary) or not (w.get("远距") is Dictionary):
		return 空
	var 词: Dictionary = w.远距
	var 阈 := int(J.or_(词.get("阈值"), 0))
	if 阈 <= 0:
		return 空
	var 距 := 攻击距离(att, def)
	var 触发: bool = 距 > 0 and 距 >= 阈
	return {
		"触发": 触发, "阈值": 阈, "距离": 距,
		"暴伤加成": float(J.or_(词.get("暴伤加成"), 0.0)) if 触发 else 0.0,
		"伤害倍率": float(J.or_(词.get("伤害倍率"), 1.0)) if 触发 else 1.0,
	}

## 被动「狙击之王」（克鲁兹）：目标距离 ≥ 4 时命中 +20、暴击 +20。
static func 狙击之王加成(_ctx: Variant, att: Variant, def: Variant) -> Dictionary:
	if not (att is Dictionary) or not J.truthy(att.get("狙击之王")):
		return {"命中": 0.0, "暴击": 0.0, "距离": 0, "触发": false}
	var 距 := 攻击距离(att, def) + int(att.get("v3远距判定加", 0))
	var 触: bool = 距 >= 4
	return {"命中": 20.0 if 触 else 0.0, "暴击": 20.0 if 触 else 0.0, "距离": 距, "触发": 触}

## v0.3 被动 / 状态伤害倍率：冷血 / 专业军人 / 隔空 λ 拳 / 邦太君。
## [规则钩子·特例] 原因：本单**不动**它（避免同时搬两处），CR-3 再挪成 `MithrilV03Cards` 的钩子。
static func v03伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	if not (att is Dictionary) or not (def is Dictionary):
		return 1.0
	var 倍 := 1.0
	if J.truthy(att.get("冷血")) and float(def.get("maxHp", 0.0)) > 0.0 \
		and float(def.get("hp", 0.0)) <= float(def.get("maxHp", 0.0)) * 0.5:
		倍 *= 1.2
	if J.truthy(att.get("专业军人")) and J.num0(def.get("size")) >= 2.0:
		倍 *= 1.2
	if w is Dictionary and J.truthy(w.get("隔空拳翻倍")):
		var 前有 := false
		if att.get("slot") != null and ctx is Dictionary:
			var 自己正前 := Fm.另一排同位(att.slot)
			if Fm.rowOfSlot(float(att.slot)) == Fm.ROW_FRONT:
				if Fm.格被占(ctx, str(att.get("side", "ally")), 自己正前):
					前有 = true
		if not 前有 and def.get("slot") != null and ctx is Dictionary:
			var 目标正前 := Fm.另一排同位(def.slot)
			if Fm.rowOfSlot(float(def.slot)) == Fm.ROW_BACK:
				if Fm.格被占(ctx, str(def.get("side", "enemy")), 目标正前):
					前有 = true
		if 前有:
			倍 *= 2.0
	if J.truthy(att.get("v3邦太君")):
		倍 *= 0.5
	var 百分 := buffSum(att, "dmgMulPct")
	if 百分 != 0.0:
		倍 *= 1.0 + 百分 / 100.0
	return 倍

static func statCoef(atk: float, D: float) -> float:
	return 1.0 + (atk - D) / 100.0

## 伤害管线。返回 c；preview 时屏障 / 力场 / 护盾不扣次数与数值。
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
	# [武器范围v0.1] `特殊` 伤害无视抗性（只被屏障 / λ 力场 / 护盾抵消）。
	# [无视抗性] 打出者带这个增益时整张抗性表都跳过。
	var 抗性免: bool = (special and J.truthy(o.get("特殊无视抗性"))) or 无视抗性(att)
	var wk: Array = [] if 抗性免 else weakList(def, w, c)
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
		# [赌神] 翻盘段暴击倍率 ×3（平时 ×2）；调用方传 `暴击倍率` 才覆盖。
		var 乘 := critMul(att)
		if o.get("暴击倍率") != null:
			乘 = float(J.num0(o.get("暴击倍率")))
		W *= 乘
	W = J.round(W)
	var A := 抵消甲(def, w)
	var 免减: bool = J.truthy(w.get("无视减伤"))
	var 伤害加成 := buffSum(att, "dmg") if (useStat and att != null) else 0.0
	var atk := (atkStat(att, w) if (useStat and att != null) else 0.0) + 伤害加成
	var D := 0.0
	if not special and not ign and not 免减:
		if useStat and J.truthy(def.get("defense")):
			D += float(def.defense)
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
	# [装甲共享池] 一次攻击内**共享**一个抵消池，只有命中段才扣。
	var 池共享: bool = J.truthy(o.get("装甲池共享"))
	if not 池共享 and w.has("_装甲池") and not c.preview:
		池共享 = true
	if not c.preview and 池共享:
		# 注意：池扣到 0 之后**不能**回落到 A（`J.or_` 会把 0.0 当假值）—— 这里按 `??` 取。
		var 池值 = o.get("装甲池") if o.get("装甲池") != null else w.get("_装甲池")
		var 池 := float(池值) if 池值 != null else A
		var 吸 := minf(maxf(0.0, 池), W)
		c.装甲池剩余 = maxf(0.0, 池 - 吸)
		base = maxf(0.0, W - 吸)
		# [散布] 按目标建池的核对口（只有 `_散布结算` 传）。
		var 池录 = o.get("_装甲池记录")
		if 池录 is Array:
			(池录 as Array).append({"目标": def.get("key"), "甲": 池, "本段吸收": 吸,
				"剩余": float(c.装甲池剩余), "本段威力": W})
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
	# [秘银v0.2] `受伤Mul`；[无视减伤] `GN 剑·贯穿` 跳过这一层，装甲照算。
	var 受伤乘 := 0.0 if 免减 else buffSum(def, "受伤Mul")
	if 受伤乘 != 0.0:
		c.dmg = maxf(0.0, J.round(float(c.dmg) * (1.0 + 受伤乘)))
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
	if float(c.dmg) > 0 and abilOn(def, "lambdaShield") and lsLeft(def, c.turn, c.get("ctx")) > 0 \
			and not (att is Dictionary and J.inc(J.or_(def.get("_无视力场键"), []), str(J.or_(att.get("tplKey"), att.get("key"))))):
		var a := J.round(λ减免量(def) * c.defMul)
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

static func wv(u: Variant, w: Dictionary, key: String) -> Variant:
	var v = w.get(key)
	for up in J.or_(w.get("upgrades"), []):
		if float(u.lv) >= float(up.lv) and up.get(key) != null:
			v = up[key]
	return v

static func expectedDamage(att: Dictionary, def: Dictionary, w: Dictionary, opts: Dictionary = {}) -> float:
	var hits := maxf(1.0, J.num0(w.get("hits")) if J.truthy(w.get("hits")) else 1.0)
	var hr := float(hitRate(att, w, def, {"blockPenalty": J.num0(opts.get("blockPenalty")), "ctx": opts.get("ctx")}).hit) / 100.0
	var crit := 1.0 + critRate(w, att, def, opts.get("ctx")) / 100.0
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

## 一次攻击（多段逐段结算）。返回 {文本, 字段}。
## 武器带 `散布` → `_散布结算`（每段独立换目标），否则 `_单体结算`。
static func resolveAttack(att: Dictionary, def: Dictionary, w: Dictionary, ctx: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if 散布适用(w, ctx, opts):
		return _散布结算(att, def, w, ctx, opts)
	return _单体结算(att, def, w, ctx, opts)

## 单体管线（`_散布结算` 的每个目标各调一次）。
static func _单体结算(att: Dictionary, def: Dictionary, w: Dictionary, ctx: Dictionary, opts: Dictionary = {}) -> Dictionary:
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
	# [逐段威力] 空表 = 每段都用本发威力。
	var 段威力表: Array = w.get("段威力") if w.get("段威力") is Array else []
	var sure := isSure(w) or J.truthy(opts.get("必中"))
	var hits := maxf(1.0, J.num0(w.get("hits")) if J.truthy(w.get("hits")) else 1.0)
	var rolls := []
	var total := 0.0
	var landed := 0.0
	var crits := 0.0
	# [九死一生] 本次攻击**按目标记账**的 命中段 / 打空段。
	var 本次记账 := {"命中段": 0.0, "打空段": 0.0}
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
	# [武器范围v0.1] 距离类词条（全部纯读、不掷随机数）。
	var 远距 := 远距判定(ctx, att, def, w)
	var 狙击 := 狙击之王加成(ctx, att, def)
	# [规则钩子·特例] 原因：这一发只为了在详情里标出「（烟雾 −30）」，`hitRate` 里已经算过一次；
	# 它是纯读，不进注册表（进了就会在 `命中修正` 之外多算一次）。
	var 烟雾罚 := AtxSmoke.命中惩罚(att, def, ctx)
	var 烟雾尾 := "" if 烟雾罚 <= 0.0 else "（烟雾 −%s）" % J.s(烟雾罚)
	if Params.动作QTE开() or J.truthy(opts.get("强制QTE")):
		push_error("动作QTE 已不迁移（数据里应为关闭）")
	# [装甲共享池] 本次攻击开始时算一次 A；**池不跨攻击**。
	# `无视防御` / `特殊` 伤害整条跳过这个池。
	var 装甲池开: bool = w.get("dmgType") != "特殊" and not J.truthy(w.get("ignoreDef"))
	var 装甲池 := 0.0
	if 装甲池开:
		装甲池 = 抵消甲(def, w)
	# [筹码·幸运女神] 本回合**第一次**被攻击时闪避 +20（用掉后清标记）。
	if not J.truthy(opts.get("preview")):
		RuleHooks.广播("受击前", [ctx, att, def])
	# [赌神] 这一发里翻了几段（一次攻击只写一行记录）。
	var 翻盘段数 := 0
	for i in int(hits):
		var 步长 := 命中段步长(att, w, {"段号": float(i + 1), "段数": hits})
		var 本段威 := 本发威力
		if not 段威力表.is_empty():
			本段威 = float(J.num0(段威力表[mini(i, 段威力表.size() - 1)]))
		var 率 := hitRate(att, w, def, {"baseHit": p, "blockPenalty": blockPenalty, "turn": ctx.turn, "ctx": ctx})
		var q := float(率.hit)
		q = J.clamp(J.round(q + float(狙击.命中)), 0, 100)
		# [规则钩子·特例] 原因：`狙い撃つ` 的溢出暴击**不是**一个独立钩子（没有模块名可注册），
		# 它由 `CelestialV01.狙溢暴击` 一处实现，本单不动。
		var 狙溢 := CelestialV01.狙溢暴击(att, w, def, ctx, float(率.get("raw", q)) + float(狙击.命中))
		var hit := sure or rng.next_float() * 100.0 < q
		# [赌神·翻盘] 每打空 1 段掷一次，50% → 改为命中并暴击 ×3，但**仍记为打空**。
		# [规则钩子·特例] 原因：翻盘会**消耗随机数**、还会把打空段改判，不能做成「纯汇总」的钩子。
		var 翻盘 := false
		if not hit and not J.truthy(opts.get("preview")) and AtxGodsbet.可翻盘(ctx, att):
			翻盘 = AtxGodsbet.掷翻盘(ctx, att)
		if hit or 翻盘:
			var cr := false
			if 翻盘:
				cr = true
			elif J.truthy(opts.get("必暴")):
				cr = true
			elif not sure or J.truthy(w.get("必中可暴击")):
				cr = rng.next_float() * 100.0 < critRate(w, att, def, ctx) + float(狙击.暴击) + 狙溢
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
			var 段倍 := float(段标.伤害倍率) if 段标 != null else 1.0
			var 无防 := 0.0
			if 按防:
				无防 = float(dmgCore(att, w, def, {"power": 本段威 * 威力倍率, "crit": cr, "preview": true, "turn": ctx.turn, "不带防御加成": true, "ctx": ctx, "被挡": 被挡}).dmg)
			var 段参 := {"power": 本段威 * 威力倍率, "crit": cr, "preview": false, "turn": ctx.turn, "defending": opts.get("defending"), "ctx": ctx, "被挡": 被挡, "特殊无视抗性": true}
			# [赌神·翻盘] 这一段的暴击倍率 **×3**（平时 ×2）。
			if 翻盘:
				段参["暴击倍率"] = AtxGodsbet.翻盘暴击倍率
			if 装甲池开:
				段参["装甲池共享"] = true
				段参["装甲池"] = 装甲池
				# [散布] 按目标建池的核对口。
				if opts.get("_装甲池记录") != null:
					段参["_装甲池记录"] = opts.get("_装甲池记录")
			var c := dmgCore(att, w, def, 段参)
			if 装甲池开:
				装甲池 = J.num0(c.get("装甲池剩余"))
			var d := J.round(float(c.dmg) * 倍率 * 段倍)
			# [武器范围v0.1·远距] 伤害倍率整发乘；暴伤加成只在暴击时再乘一次。
			if 远距.触发:
				d = J.round(float(d) * float(远距.伤害倍率))
				if cr and float(远距.暴伤加成) != 0.0:
					d = J.round(float(d) * (1.0 + float(远距.暴伤加成)))
			# [武器范围v0.3] 冷血 / 专业军人 / 隔空 λ 拳 / 全员突击。
			# [规则钩子·特例] 原因：`v03伤害倍率` 是 `calc.gd` 自己的内部函数（不是势力模块的钩子），
			# 本单不搬；CR-3 再把它挪成 `MithrilV03Cards` 的钩子。
			var v03倍 := v03伤害倍率(ctx, att, def, w)
			if v03倍 != 1.0:
				d = J.round(float(d) * v03倍)
			# [职业分类牌] / [天人·伤害] 攻方伤害倍率：逐模块相乘，**每一步** `J.round`。
			d = RuleHooks.依次乘("攻方伤害倍率", d, [ctx, att, def, w])
			# [GN 全盾·哈罗] / [塔斯克·引力墙] 受方伤害倍率：同上。
			d = RuleHooks.依次乘("受方伤害倍率", d, [ctx, att, def, w])
			var 掩 := 0.0 if J.truthy(opts.get("preview")) else Params.兰斯掩护减免(def, w, ctx, 被挡)
			if 掩 > 0:
				var 原 := dmgCore(att, w, def, {"power": 本段威 * 威力倍率, "crit": cr, "preview": true, "turn": ctx.turn, "defending": opts.get("defending"), "ctx": ctx, "被挡": 被挡, "不带掩护": true})
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
			if 翻盘:
				# [赌神·翻盘] 翻盘的段仍记为打空，伤害按命中并暴击算。
				翻盘段数 += 1
				crits += 1.0
				本次记账["打空段"] = float(本次记账["打空段"]) + 1.0
				# 势力钩子照常走（`状.打空` 按段计数不许因为翻盘就少记）
				Fac.势力逐段未命中(ctx, att, def, w, {"段号": float(i + 1), "段数": hits, "本段命中率": q})
			else:
				landed += 1.0
				本次记账["命中段"] = float(本次记账["命中段"]) + 1.0
				if cr:
					crits += 1.0
			if 段标 != null:
				段标.消耗伤害 = float(段标.消耗伤害) + maxf(0.0, d - J.round(float(c.dmg) * 倍率))
				标定记号 = 段标
			if 翻盘:
				rolls.append("第 %d 段（%s%%）翻盘 → 暴击 ×%d %s%s" % [
					i + 1, J.s(q), int(AtxGodsbet.翻盘暴击倍率), J.s(d), 烟雾尾])
			else:
				rolls.append("第 %d 段（%s）%s%s%s" % [i + 1, "必中" if sure else J.s(q) + "%",
					"暴击 " if cr else ("狙い撃つ → 暴击 +%s " % J.s(狙溢) if 狙溢 > 0 else ""), J.s(d), 烟雾尾])
			if c.nullified:
				break
			var 减2 := 步长 if 步长 != 0 else J.num0(w.get("step"))
			if 减2 != 0:
				p -= 减2
		else:
			rolls.append("第 %d 段（%s%%）未中%s" % [i + 1, J.s(q), 烟雾尾])
			本次记账["打空段"] = float(本次记账["打空段"]) + 1.0
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
	# [筹码·死里逃生] 本回合第一次致命伤害保留 1 HP，并算作闪开。
	if not J.truthy(opts.get("preview")):
		RuleHooks.广播("致命保留_前", [ctx, att, def])
	# [DECK-1] 单机战意：命中 +2 / 被击 +2 / 闪避 +2 / 击破 +10。
	if not J.truthy(opts.get("preview")):
		_结算单机牌组战意(att, def, landed, ctx, 原HP, J.truthy(opts.get("_散布后续")))
	# [死守前线/不倒] 致命伤害保留 1 HP；放在战意之后 → 不算击破。
	if not J.truthy(opts.get("preview")):
		RuleHooks.广播("致命保留_后", [ctx, att, def])
	# [反冲] **每次攻击事件一次**（不是每段）；后面接各模块的攻击后记账（原顺序不变）。
	if not J.truthy(opts.get("preview")):
		RuleHooks.广播("武器攻击后", [ctx, att, def, landed, w])
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
	# [赌神·翻盘] 整段靠翻盘打出的伤害：命中段数仍是 0，文案走「命中」。
	if landed != 0 or total > 0:
		文本 = "%s【%s】→ %s：%s伤害 %s%s%s%s%s" % [att.name, w.name, def.name, 段, J.s(total),
			"（暴击 %s 次）" % J.s(crits) if crits != 0 else "",
			"（翻盘 %d 段，仍记为打空）" % 翻盘段数 if 翻盘段数 > 0 else "",
			"（特种：对方命中 −%s，到下回合结束）" % J.s(特种减命中) if 特种减命中 != 0 else "",
			"（%s）" % debuff文字(挂上的debuff) if 挂上的debuff != null else ""]
	else:
		文本 = "%s【%s】→ %s：未命中（%s）" % [att.name, w.name, def.name, "；".join(rolls)]
	var 字段 := {
		"命中": landed > 0, "伤害": total, "段数": hits, "命中段数": landed, "暴击": crits, "目标剩余HP": def.hp,
		"特种减命中": 特种减命中, "debuff": 挂上的debuff, "详情": "；".join(rolls),
	}
	if 翻盘段数 > 0:
		字段["翻盘段数"] = 翻盘段数
		字段["翻盘暴击倍率"] = AtxGodsbet.翻盘暴击倍率
	if J.truthy(远距.get("触发")):
		字段.远距 = float(远距.阈值)
		字段.攻击距离 = float(远距.距离)
		if float(远距.伤害倍率) != 1.0:
			字段.远距伤害倍率 = float(远距.伤害倍率)
		if float(远距.暴伤加成) != 0.0 and crits > 0.0:
			字段.远距暴伤 = float(远距.暴伤加成)
	if J.truthy(狙击.get("触发")):
		字段.狙击之王 = true
		字段.攻击距离 = float(狙击.距离)
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
	# [九死一生] 一次攻击后按目标判一次（出手 / 反击 / 自爆 都过这里）。
	if not J.truthy(opts.get("preview")):
		九死一生_判定(ctx, att, def, 本次记账)
	# [赌神] 一次攻击 = 一条记录：翻盘段数与 `ctx.上一次攻击` 在末尾汇总。
	# [规则钩子·特例] 原因：与上面那个「掷翻盘」是同一件事的记账半边，一起留在 `calc.gd`。
	if not J.truthy(opts.get("preview")):
		if 翻盘段数 > 0:
			AtxGodsbet.记翻盘(ctx, att, 翻盘段数)
		AtxGodsbet.记上一次攻击(ctx, att, def, 本次记账)
	return {"文本": 文本, "字段": 字段}

# [散布] 每段独立掷 `ctx.rng` 换目标：合法落点 = 主目标 + 十字相邻的存活敌机。
#   命中 / 暴击 / 打空按实际落点记；装甲池按目标建；一次攻击一条记录。
#   规则原文见 协作/设计/武器范围规则 v0.1.md（散布一节）。

## 这一发是不是要走「散布」管线（纯读）。
static func 散布适用(w: Variant, _ctx: Variant, opts: Dictionary) -> bool:
	if not (w is Dictionary) or not J.truthy((w as Dictionary).get("散布")):
		return false
	# 范围武器（`fire = map`）由 `Flow.resolveAction` 的落点循环负责。
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		return false
	# 预览口径**不掷随机数**、不换目标 → 走改前那条路。
	return not J.truthy(opts.get("preview"))

## 合法落点：`[主目标, 十字相邻的存活敌机…]`。
static func 散布候选(def: Dictionary, ctx: Variant) -> Array:
	var 出: Array = [def]
	if not (ctx is Dictionary) or def.get("slot") == null:
		return 出
	var 位们 := Fm.十字相邻位(float(def.slot))
	if 位们.is_empty():
		return 出
	for t in Units.livingOf(def.get("side"), ctx):
		if not (t is Dictionary) or is_same(t, def) or t.get("slot") == null:
			continue
		if J.inc(位们, int(t.get("slot"))):
			出.append(t)
	return 出

## 散布的一次攻击：分数结算 → 合并成**一条**记录。
static func _散布结算(att: Dictionary, def: Dictionary, w: Dictionary, ctx: Dictionary, opts: Dictionary) -> Dictionary:
	var 候选 := 散布候选(def, ctx)
	var 段数 := maxi(1, AtxRewrite.段数Of(w))
	# 主目标的血量在开打前记下来（击破判定 / 「散布击破」用）
	var 血前 := {}
	for t in 候选:
		血前[str((t as Dictionary).get("key"))] = float((t as Dictionary).get("hp", 0.0))
	var 池录: Array = []
	# 每个目标的池初值：**统一走 `抵消甲(被, w)`**（含 `ignoreArmorPct` / 无视防御 / 特殊），
	# 与 `_单体结算` 里真正建池那一次同一口径 —— 否则报出来的 `甲` 比实建的池大。
	var 甲表 := {}
	for t in 候选:
		甲表[str((t as Dictionary).get("key"))] = 抵消甲(t, w)
	# ---- 没有十字相邻的存活敌机 → 全部打主目标（不掷随机数）----
	if 候选.size() <= 1:
		var 子参: Dictionary = opts.duplicate(true)
		子参["_装甲池记录"] = 池录
		var r0 := _单体结算(att, def, w, ctx, 子参)
		_落字段(r0, [{"目标": def.get("key"), "名": str(def.get("name", "")), "段数": 段数}], 0, 池录, 甲表)
		return r0
	# ---- 逐段独立掷一次：在「主目标 + 十字相邻存活敌机」里挑 ----
	var rng: Mulberry32 = ctx.rng
	var 组段: Array = []
	for i in 候选.size():
		组段.append(0)
	for i in 段数:
		var 下标 := clampi(int(floorf(rng.next_float() * float(候选.size()))), 0, 候选.size() - 1)
		组段[下标] = int(组段[下标]) + 1
	# ---- 每个目标各自结算一次（各自一个装甲池、各自一次闪开）----
	var 总伤害 := 0.0
	var 命中段 := 0.0
	var 暴击 := 0.0
	var 翻盘 := 0.0
	var 详情们: Array = []
	var 主字段: Dictionary = {}
	var 落点: Array = []
	for i in 候选.size():
		var 本段 := int(组段[i])
		if 本段 <= 0:
			continue
		var 子武: Dictionary = w.duplicate(true)
		子武["hits"] = float(本段)
		var 子参: Dictionary = opts.duplicate(true)
		子参["_装甲池记录"] = 池录
		if i > 0:
				# 攻击方的「命中 +2」「击破 +10」按**一次攻击**只记一次
			子参["_散布后续"] = true
		var r := _单体结算(att, 候选[i], 子武, ctx, 子参)
		var f: Dictionary = r.get("字段") if (r.get("字段") is Dictionary) else {}
		if i == 0:
			主字段 = f.duplicate(true)
		总伤害 += J.num0(f.get("伤害"))
		命中段 += J.num0(f.get("命中段数"))
		暴击 += J.num0(f.get("暴击"))
		翻盘 += J.num0(f.get("翻盘段数"))
		var 名前 := str((候选[i] as Dictionary).get("name", ""))
		for e in str(f.get("详情", "")).split("；"):
			if str(e) != "":
				详情们.append("〈%s〉%s" % [名前, str(e)])
		落点.append({"目标": (候选[i] as Dictionary).get("key"), "名": 名前, "段数": 本段})
	var 打空 := maxf(0.0, float(段数) - 命中段)
	var 偏移 := 段数 - int(组段[0])
	# ---- 合并成一条文本 ----
	var 尾 := ""
	if 偏移 > 0:
		var 名们: Array = []
		for i in range(1, 候选.size()):
			if int(组段[i]) > 0:
				名们.append("%s×%d" % [str((候选[i] as Dictionary).get("name", "")), int(组段[i])])
		尾 = " · 散布 %d 段偏移（%s → %s）" % [偏移, str(def.get("name", "")), "、".join(名们)]
	var 文本 := "%s【%s】%d 段 → 命中 %d / 打空 %d · 伤害 %s%s%s%s" % [
		str(att.get("name", "")), str(w.get("name", "")), 段数, int(命中段), int(打空), J.s(总伤害),
		"（暴击 %s 次）" % J.s(暴击) if 暴击 != 0.0 else "",
		"（翻盘 %d 段，仍记为打空）" % int(翻盘) if 翻盘 > 0.0 else "", 尾]
	# ---- 合并成一个字段（主目标那一组打底；聚合项覆盖）----
	var 字段 := 主字段
	字段["命中"] = 命中段 > 0.0
	字段["伤害"] = 总伤害
	字段["段数"] = float(段数)
	字段["命中段数"] = 命中段
	字段["打空段数"] = 打空
	字段["暴击"] = 暴击
	字段["目标剩余HP"] = def.get("hp")
	字段["详情"] = "；".join(详情们)
	if 翻盘 > 0.0:
		字段["翻盘段数"] = 翻盘
	_落字段({"字段": 字段}, 落点, 偏移, 池录, 甲表)
	var 死们: Array = []
	for t in 候选:
		var k := str((t as Dictionary).get("key"))
		if float(血前.get(k, 0.0)) > 0.0 and float((t as Dictionary).get("hp", 0.0)) <= 0.0:
			死们.append(k)
	if not 死们.is_empty():
		字段["散布击破"] = 死们
	# 一次攻击只记**一次**「上一次攻击」：合并后的合计。
	if not J.truthy(opts.get("preview")):
		AtxGodsbet.记上一次攻击(ctx, att, def, {"命中段": 命中段, "打空段": 打空})
	return {"文本": 文本, "字段": 字段}

## 把 `散布 / 散布偏移段数 / 散布落点 / 散布池` 落进字段。
static func _落字段(r: Dictionary, 落点: Array, 偏移: int, 池录: Array, 甲表: Dictionary) -> void:
	var f = r.get("字段")
	if not (f is Dictionary):
		return
	(f as Dictionary)["散布"] = true
	(f as Dictionary)["散布偏移段数"] = float(偏移)
	(f as Dictionary)["散布落点"] = 落点
	(f as Dictionary)["散布池"] = _聚合池(池录, 落点, 甲表)

## 逐段池记录按目标聚合成 `[{目标, 名, 甲, 吸收, 剩余, 命中段}]`。
static func _聚合池(池录: Array, 落点: Array, 甲表: Dictionary) -> Array:
	var 出: Array = []
	for e in 落点:
		var k = (e as Dictionary).get("目标")
		var 初甲 := float(甲表.get(str(k), 0.0))
		var 甲 := 初甲
		var 吸 := 0.0
		var 剩 := 初甲
		var 次 := 0
		for x in 池录:
			if not (x is Dictionary) or str((x as Dictionary).get("目标")) != str(k):
				continue
			甲 = maxf(甲, float((x as Dictionary).get("甲", 0.0)))
			吸 += float((x as Dictionary).get("本段吸收", 0.0))
			剩 = float((x as Dictionary).get("剩余", 0.0))
			次 += 1
		出.append({"目标": k, "名": (e as Dictionary).get("名"), "甲": 甲, "吸收": 吸,
			"剩余": 剩, "命中段": 次})
	return 出

# [九死一生] 一次攻击后按被打的我方 ATX 成员判：打空段数 >= 命中段数 → 闪开。
#   每闪一次大招槽冷却中的牌各 −1（每张牌每次最多 −1，每敌方阶段最多 3 次）；总开关 `Params.九死一生开(ctx)`。
const 九死一生_每阶段上限 := 3

static func 九死一生_闪(u: Variant) -> bool:
	return (u is Dictionary) and u.get("闪") == true

static func 九死一生_本阶段轮转(u: Variant) -> int:
	return int(J.num0(J.g(u, "轮转本阶段")))

static func 九死一生_本阶段合计(ctx: Variant) -> int:
	var 总 := 0
	for u in J.or_(J.g(ctx, "allies"), []):
		总 += 九死一生_本阶段轮转(u)
	return 总

## 我方阶段结束（= 敌方阶段开始）：统一清空「闪」，轮转计数归零。
static func 九死一生_阶段切换(ctx: Dictionary) -> void:
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		u.erase("闪")
		u.erase("轮转本阶段")

## 一次攻击结算完之后判一次（`记账` = {命中段, 打空段}）。
static func 九死一生_判定(ctx: Dictionary, att: Variant, def: Variant, 记账: Dictionary) -> Dictionary:
	var 空 := int(J.num0(J.g(记账, "打空段")))
	var 中 := int(J.num0(J.g(记账, "命中段")))
	var 否 := {"触发": false, "闪": false, "打空段": 空, "命中段": 中, "轮转": 0, "本阶段轮转": 0}
	if not (def is Dictionary):
		return 否
	if def.get("side") != "ally" or Fac.势力名(def) != "ATX":   # 只算我方 ATX 成员
		return 否
	if att is Dictionary and str(att.get("side")) == str(def.get("side")):
		return 否                          # 只判「敌方打我方」这一条路（同侧不判）
	if 空 + 中 < 1:                        # 防御性下限：0 打空 0 命中不算一次攻击
		return 否
	if 空 < 中:                            # 判据：打空段数 >= 命中段数
		return 否
	var 塔: Dictionary = def
	塔["闪"] = true                        # 纯布尔，不叠层
	# [筹码·庄家通吃] 闪开一次 → 攻击者受 600 物理伤害。
	AtxChips.闪开后(ctx, att, def)
	var 轮 := 九死一生_轮转(塔)
	var 头 := "〔九死一生〕%s 闪开（打空 %d ≥ 命中 %d）" % [str(塔.get("name", "")), 空, 中]
	var 文: String
	if not 轮.is_empty():
		文 = "%s→ 大招槽冷却 −1：%s" % [头, "、".join(轮.map(func(e): return "%s %s→%s" % [str(e.牌), J.s(e.前), J.s(e.后)]))]
	elif 九死一生_本阶段轮转(def) >= 九死一生_每阶段上限:
		文 = "%s→（本阶段每张牌已轮转 %d 次，不再减）" % [头, 九死一生_每阶段上限]
	else:
		文 = "%s→（无冷却中的牌）" % 头
	Btl.pushLog(ctx, 文, {
		"类型": "九死一生", "势力": "ATX", "特色": "九死一生",
		"单位": J.g(def, "key"), "单位方": def.get("side"), "单位位": J.g(def, "slot"),
		"攻击者": J.g(att, "key"), "打空段": 空, "命中段": 中, "闪": true,
		"轮转次数": 轮.size(), "本阶段轮转": 九死一生_本阶段轮转(def),
	})
	return {"触发": true, "闪": true, "打空段": 空, "命中段": 中,
		"轮转": 轮.size(), "本阶段轮转": 九死一生_本阶段轮转(def)}

## 轮转：大招槽里冷却中的牌各 −1，返回 `[{牌, 前, 后}]`。
## 每张牌每次攻击最多 −1；每敌方阶段上限 3 次。
static func 九死一生_轮转(u: Dictionary) -> Array:
	var 次 := 九死一生_本阶段轮转(u)
	if 次 >= 九死一生_每阶段上限:
		return []
	var 扣: Array = []
	for 槽 in J.or_(u.get("大招槽"), []):
		if not (槽 is Dictionary):
			continue
		var 前 := J.num0(槽.get("cd"))
		if 前 <= 0.0:
			continue
		槽["cd"] = maxf(0.0, 前 - 1.0)
		扣.append({"牌": str(J.g(J.g(槽, "卡"), "名")), "前": 前, "后": float(槽["cd"])})
	if not 扣.is_empty():
		u["轮转本阶段"] = 次 + 1
	return 扣

## [DECK-1] 单机战意结算（按「攻击行动」计，不按段数乘算）。
## `跳过攻击方奖励` = `散布` 的副目标不重复记「命中 +2」。
static func _结算单机牌组战意(att: Variant, def: Variant, landed: float, ctx: Dictionary, 原HP: float,
		跳过攻击方奖励: bool = false) -> void:
	if not (att is Dictionary) or not (def is Dictionary):
		return
	if landed > 0.0:
		if not 跳过攻击方奖励:
			Btl.加战意(att, Params.命中战意(), ctx, "命中")
		Btl.加战意(def, Params.被击战意(), ctx, "被击")
		# 重装【铁壁护卫】期间每次被击额外 +2
		if J.same(def.get("铁壁护卫中"), ctx.get("turn")):
			Btl.加战意(def, 2.0, ctx, "铁壁被击")
		if 原HP > 0.0 and float(def.hp) <= 0.0:
			Btl.加战意(att, Params.击破战意(), ctx, "击破")
	else:
		Btl.加战意(def, Params.闪避战意(), ctx, "闪避")
		# 尖兵【机动脱离】期间每次成功闪避额外 +2
		if J.same(def.get("机动脱离中"), ctx.get("turn")):
			Btl.加战意(def, 2.0, ctx, "机动脱离")

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
