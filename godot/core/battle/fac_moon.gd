## 72-势力-3：月球王国（月光环绕 / 残月的余响 / 不动如山 / 战地急救 / 连射残心）。
class_name FacMoon
extends RefCounted

const 月球光环来源 := "势力·月球王国"
const 光环属性名 := {"hit": "命中", "eva": "闪避", "def": "防御", "crit": "暴击"}

## `MoonV02` 接手时（默认）→ 旧版特色全部让位；成员打上 `月球v02` 标记，给不带 ctx 的数值钩子判。
static func v02让位(ctx: Variant) -> bool:
	if not MoonV02.开(ctx):
		return false
	for u in Fac.势力在场("月球王国", ctx):
		u["月球v02"] = true
	return true

static func 月球参数() -> Dictionary:
	return Fac.势力参数("月球王国")

static func 有月光共鸣(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 月球参数()
	return u != null and u.get("side") == "ally" and u.get("trait") == J.or_(参.get("光环特技"), "autoCast")

static func 是残月武器(w: Variant) -> bool:
	return w != null and J.truthy(w.get("友军攻击后追加"))

static func 月光祝福数值(u: Variant, p: Variant) -> Dictionary:
	var 参 = p if J.truthy(p) else 月球参数()
	var 名 = J.or_(参.get("光环武器"), "月光祝福")
	var w = null
	for e in J.or_(u.get("weapons") if u != null else null, []):
		var x = J.or_(e.get("t"), e) if e != null else e
		if x != null and x.get("name") == 名:
			w = x
			break
	if w == null:
		return {}
	return J.merged(J.or_(J.or_(Calc.wv(u, w, "buff"), w.get("buff")), {}))

static func 光环文字(数: Variant) -> String:
	var 们 := []
	for k in ["hit", "eva", "def", "crit"]:
		if 数 != null and J.truthy(数.get(k)):
			们.append("%s +%s" % [光环属性名[k], J.s(数[k])])
	return "、".join(们) if not 们.is_empty() else "（没有数值）"

static func 月球光环受益(f: Dictionary, ctx: Dictionary, p: Dictionary) -> Array:
	var 位们 := Fm.相邻位(f.slot)
	var 候选 := Units.livingOf("ally", ctx).filter(func(t): return not is_same(t, f) and J.inc(位们, t.slot))
	return 候选.filter(func(t): return Fac.是我方势力(t, "月球王国")) if J.truthy(p.get("光环只要同势力")) else 候选

static func 判定月球王国光环(ctx: Variant, p: Dictionary) -> void:
	if ctx == null or v02让位(ctx):
		return
	var 参 := p
	for u in Units.livingOf("ally", ctx):
		u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != 月球光环来源)
	for f in Fac.势力在场("月球王国", ctx).filter(func(u): return 有月光共鸣(u, 参)):
		var 状 := Fac.势力状态(f, "月球王国")
		var 数 := 月光祝福数值(f, 参)
		var 受益 := 月球光环受益(f, ctx, 参)
		状.光环数值 = 数
		状.光环名单 = 受益.map(func(u): return u.key)
		状.光环位 = 受益.map(func(u): return u.slot)
		for t in 受益:
			t.buffs.append(J.merged({"src": 月球光环来源, "剩余": 1.0}, 数))
		var 签名 := J.json([f.slot, 数, 状.光环位])
		var 变了: bool = 状.get("光环签名") != 签名
		状.光环签名 = 签名
		if not 变了:
			continue
		var 相邻 := Fm.相邻位(f.slot)
		var 面: String = "、".join(相邻.map(func(s): return Fm.位名(s))) if not 相邻.is_empty() else "（没有相邻位）"
		var 文: String
		if not 受益.is_empty():
			文 = "月球王国 %s 的月光环绕：相邻位（%s）上的队友 %s 吃到 %s" % [f.name, 面, "、".join(受益.map(func(u): return "%s %s" % [Fm.位名(u.slot), u.name])), 光环文字(数)]
		else:
			文 = "月球王国 %s 的月光环绕：相邻位（%s）上没有队友，这一条不生效" % [f.name, 面]
		Fac.势力记录(ctx, 文, {
			"势力": "月球王国", "特色": "月光环绕", "结果": "生效" if not 受益.is_empty() else "失效",
			"单位": f.key, "单位方": f.side, "单位位": f.slot, "相邻位": 相邻,
			"受益": 受益.map(func(u): return u.key), "受益位": 受益.map(func(u): return u.slot), "数值": 数,
		})

static func 残月可追加(f: Variant, e: Variant) -> bool:
	if f == null or e == null or not J.truthy(e.get("t")):
		return false
	return float(f.lv) >= J.num(Params.残月武器运行期解锁(e.t))

static func 残月武器(f: Variant, ctx: Variant, _p: Variant) -> Variant:
	var 回 := float(ctx.turn) if (ctx != null and ctx.get("turn") != null) else 0.0
	var pool = J.or_(f.get("weapons") if f != null else null, []).filter(func(e):
		return e != null and J.truthy(e.get("t")) and 是残月武器(e.t) and 残月可追加(f, e) and J.num(e.cd) <= 0 \
			and (e.get("readyTurn") == null or float(e.readyTurn) <= 回))
	if pool.is_empty():
		return null
	J.sort(pool, func(a, b): return J.num(Params.残月武器运行期解锁(a.t)) - J.num(Params.残月武器运行期解锁(b.t)))
	return pool[pool.size() - 1]

static func 残月追加攻击(ctx: Variant, 攻击者: Variant, 目标: Variant, 一击: Variant, p: Variant) -> float:
	var 参 = p if J.truthy(p) else 月球参数()
	if ctx == null or 攻击者 == null or 目标 == null or v02让位(ctx):
		return 0.0
	if 攻击者.side != "ally":
		return 0.0
	if 目标.side == 攻击者.side:
		return 0.0
	if not (一击 != null and J.num(一击.get("伤害")) > 0):
		return 0.0
	if 有月光共鸣(攻击者, 参):
		return 0.0
	var 原目标 = null
	if float(目标.hp) <= 0:
		var 活敌 := Units.livingOf("enemy", ctx).filter(func(u): return u.hp > 0)
		J.sort(活敌, func(a, b):
			var d := float(a.hp) / maxf(1.0, float(a.maxHp)) - float(b.hp) / maxf(1.0, float(b.maxHp))
			return d if d != 0 else float(a.slot) - float(b.slot))
		if 活敌.is_empty():
			return 0.0
		原目标 = 目标
		目标 = 活敌[0]
	var 菲娜 = J.find(Fac.势力在场("月球王国", ctx).filter(func(u): return 有月光共鸣(u, 参)), func(u): return 残月武器(u, ctx, 参) != null)
	if 菲娜 == null:
		return 0.0
	var 状 := Fac.势力状态(菲娜, "月球王国")
	if not J.same(状.get("追加回合"), ctx.turn):
		状.追加回合 = ctx.turn
		状.追加次数 = 0.0
	var 上限 := maxf(0.0, J.num0(参.get("残月余响每回合上限")))
	if float(状.追加次数) >= 上限:
		return 0.0
	var 挑 = 残月武器(菲娜, ctx, 参)
	if 挑 == null:
		return 0.0
	状.追加次数 = float(状.追加次数) + 1.0
	# 攻击结算统一走 `Flow.结算一个目标`（击破 / 势力击破 / 记击破 / 标记被攻击 都在那里）；
	# `不写标准攻击日志` = 下面这条 `Fac.势力记录` 自己那一行（否则一次追加会写两条）。
	var 结算: Dictionary = Flow.结算一个目标(ctx, 菲娜, 目标, 挑.t, {"改目标": false, "不写标准攻击日志": true, "旁路攻击": true})
	var rec: Dictionary = 结算.rec
	if J.truthy(挑.t.get("cd")):
		挑.cd = 挑.t.cd
	var 文 := "%s 的残月的余响：队友【%s】攻击后追加一发【%s】→ %s%s：%s 伤害（本回合第 %s/%s 次）" % [
		菲娜.name, 攻击者.name, 挑.t.name, 目标.name,
		"（原目标 %s 已倒下 → 改砸剩余 HP 比例最低的活敌）" % 原目标.name if 原目标 != null else "",
		J.s(rec.字段.伤害), J.s(状.追加次数), J.s(上限)]
	Fac.势力记录(ctx, 文, J.merged(J.merged({
		"类型": "残月余响", "势力": "月球王国", "特色": "残月的余响", "队友": 攻击者.key,
		"单位": 菲娜.key, "单位位": 菲娜.slot, "目标": 目标.key, "武器": 挑.t.name,
		"本回合第几次": 状.追加次数, "每回合上限": 上限,
		"原目标": 原目标.key if 原目标 != null else null, "换目标": 原目标 != null,
	}, J.merged(Btl.谁(菲娜), Btl.谁目标(目标))), rec.字段))
	# 击破记账与 `残月或月国命中` 都已经在 `Flow.结算一个目标` 里做过，这里不再补一遍。
	return float(rec.字段.伤害)

# ---------------- 不动如山 / 战地急救 / 连射残心 ----------------
static func 有不动如山(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 月球参数()
	var 特技 = "steadfast"
	if J.truthy(参.get("不动如山")) and J.truthy(参.不动如山.get("特技")):
		特技 = 参.不动如山.特技
	return u != null and u.get("trait") == 特技

static func 有战地急救(u: Variant, p: Variant) -> bool:
	var 参 = p if J.truthy(p) else 月球参数()
	var 特技 = "fieldAid"
	if J.truthy(参.get("战地急救")) and J.truthy(参.战地急救.get("特技")):
		特技 = 参.战地急救.特技
	return u != null and u.get("trait") == 特技

static func 有残心(u: Variant, pt: Variant) -> bool:
	var 参 := 月球残心参数(pt)
	if u == null or not J.is_arr(u.get("abilities")):
		return false
	var 门 := J.num(参.get("残心解锁等级"))
	if float(u.lv) < (门 if J.truthy(门) else 20.0):
		return false
	return J.inc(u.abilities, J.or_(参.get("特技"), "zanshin"))

static func 是连射武器(w: Variant, pt: Variant) -> bool:
	return w != null and w.get("special") == J.or_(月球残心参数(pt).get("武器特技"), "chain")

static func 月球不动(u: Variant) -> bool:
	if u == null or not J.truthy(u.get("势力状态")):
		return false
	var s = u.势力状态.get("月球王国")
	return s != null and J.truthy(s.get("不动如山"))

static func 不动装甲(u: Variant, p: Variant) -> float:
	if not 月球不动(u) or J.truthy(u.get("月球v02")):
		return 0.0
	var 参 = p if J.truthy(p) else 月球参数()
	return J.num0(J.or_(参.get("不动如山"), {}).get("装甲加成"))

static func 连射步长(u: Dictionary, w: Variant, pt: Variant) -> float:
	var 参 := 月球残心参数(pt)
	if 有残心(u, 参):
		var v := J.num(参.残心步长30) if float(u.lv) >= 30 else J.num(参.残心步长)
		return v if J.truthy(v) else 0.0
	var a := J.num(w.get("chainStep")) if w != null else 0.0
	if J.truthy(a):
		return a
	var b := J.num(参.get("连射步长"))
	return b if J.truthy(b) else 0.0

# 待接回新模式（见 RT回执「已知缺口」），勿当死代码删
static func 判定月球不动(ctx: Variant, p: Dictionary) -> void:
	if ctx == null or v02让位(ctx):
		return
	for u in Fac.势力在场("月球王国", ctx):
		if not 有不动如山(u, p):
			continue
		var 状 := Fac.势力状态(u, "月球王国")
		状.不动如山 = true
		状.不动如山文字 = "本回合没有移动（战斗中已无任何位移）→ 装甲 +30%"

static func 战地急救(ctx: Variant, 修理者: Variant, 目标: Variant, _武器: Variant, 回复: Variant, p: Variant) -> float:
	var 参: Dictionary = J.or_((p if J.truthy(p) else 月球参数()).get("战地急救"), {})
	if ctx == null or 修理者 == null or 目标 == null or v02让位(ctx):
		return 0.0
	if not 有战地急救(修理者, p):
		return 0.0
	var 来源 = J.or_(参.get("来源"), "战地急救")
	var 值 := J.num0(参.get("防御加成"))
	if 值 == 0:
		return 0.0
	目标.buffs = J.or_(目标.get("buffs"), []).filter(func(b): return b.get("src") != 来源)
	目标.buffs.append({"src": 来源, "def": 值, "剩余": 1.0})
	Fac.势力记录(ctx, "月球王国 %s 的【战地急救】：%s 被修理 %s，额外防御 +%s（到本回合结束）" % [修理者.name, 目标.name, J.s(回复), J.s(值)],
		{"势力": "月球王国", "特色": "战地急救", "结果": "生效", "单位": 修理者.key, "目标": 目标.key, "目标方": 目标.side, "目标位": 目标.slot, "回复": 回复, "防御加成": 值})
	return 值

static func 连射残心(att: Variant, w: Variant, pt: Variant) -> float:
	if att == null or att.get("side") != "ally" or J.truthy(att.get("月球v02")):
		return 0.0
	var 段表 := 月球残心参数(pt)
	if not 是连射武器(w, 段表):
		return 0.0
	return 连射步长(att, w, 段表)

static func 月球残心参数(pt: Variant) -> Dictionary:
	if not (pt is Dictionary):
		return J.or_(月球参数().get("连射残心"), {})
	if pt.get("连射残心") is Dictionary:
		return pt.连射残心
	if pt.get("残心步长") != null or pt.get("连射段数") != null or pt.get("武器特技") != null:
		return pt
	return J.or_(月球参数().get("连射残心"), {})
