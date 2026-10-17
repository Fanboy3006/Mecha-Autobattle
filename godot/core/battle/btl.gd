## 60-战斗-1-方针与记录.js：战斗记录、气势、嘲讽 / 镜甲 / 自爆、敌方词条的回合效果、战术卡牌（牌池 / 发牌 / 打牌）。
## ★ R1：32 张战术牌的**效果本体**搬到了 core/battle/card_effects.gd（CARD_OPS 声明式表 + 通用算子执行器）；这里只管牌池 / 发牌 / 打牌流程。
## 「行动方针」已取消（作者 2026-10-15）：当前方针恒为「全军突击」，禁止攻击恒为假；
## 旧的「设战术 / 预约战术」不迁移（ARGON 2026-10-16：由战术牌 CMD_ALL_OUT / CMD_COVER 取代）。
class_name Btl
extends RefCounted

static func 默认方针() -> Dictionary:
	return {"类型": "全军突击", "目标位": null}

## 记一条事件。_rng_at 与 log 一一对应：记这一条时随机数已经抽了几次（只给对账用，不进事件本身）。
static func pushLog(ctx: Dictionary, text: String, extra: Variant = null) -> void:
	var r := {"回合": ctx.turn, "文本": text}
	if extra is Dictionary:
		for k in extra.keys():
			r[k] = extra[k]
	ctx.log.append(r)
	if ctx.has("_rng_at"):
		var rng = ctx.get("rng")
		ctx._rng_at.append(rng.steps if rng != null else -1)

## ★ MITH-1：按事件字典记一条 —— `文本` 走文案、其余键原样进事件（衍生牌置入 / 作废用）。
static func 记(ctx: Dictionary, 事件: Dictionary) -> void:
	if ctx == null or not (事件 is Dictionary):
		return
	var 文本 := str(事件.get("文本", ""))
	var 余 := 事件.duplicate()
	余.erase("文本")
	pushLog(ctx, 文本, 余)

static func 谁(u: Dictionary) -> Dictionary:
	return {"单位方": u.side, "单位位": u.slot}

static func 谁目标(u: Dictionary) -> Dictionary:
	return {"目标方": u.side, "目标位": u.slot}

static func 设单位开关(ctx: Dictionary, 开关表: Variant) -> void:
	for u in ctx.allies:
		var c = J.at(开关表, u.slot) if 开关表 != null else null
		if not J.truthy(c):
			continue
		if c.get("保留大招") != null:
			u.holdUlt = J.truthy(c.保留大招)
		if c.get("TRANSAM") != null:
			u.TRANSAM手动 = c.TRANSAM == "手动"
		if c.get("本回合开TRANSAM") != null:
			u.本回合开TRANSAM = J.truthy(c.本回合开TRANSAM)

static func 禁止攻击(_u: Variant, _ctx: Variant) -> bool:
	return false   # 只有「全军防御 / 前守后攻」方针会禁止攻击；方针已取消

static func 按防御结算(u: Variant, _ctx: Variant) -> bool:
	return u != null and J.truthy(u.get("defending"))

# ======================== 气势 ========================
static func 气势上限() -> float:
	var v := J.num0(Params.气势总攻参数().get("上限"))
	return v if v != 0 else 100.0

static func 加气势(ctx: Variant, 值: Variant) -> float:
	if ctx == null or not Params.气势总攻开():
		return 0.0
	var 增 := J.num0(值)
	if not (增 > 0):
		return J.num0(ctx.get("气势"))
	var 上限 := 气势上限()
	var 前 := J.num0(ctx.get("气势"))
	var 后 := maxf(0.0, minf(上限, 前 + 增))
	ctx.气势 = 后
	if 后 >= 上限 and ctx.get("曾满气势回合") == null:
		ctx.曾满气势回合 = ctx.turn if J.truthy(ctx.turn) else 1.0
	if 后 > 前:
		气势变动后发牌(ctx)
	return 后

static func 设全队憋大招(ctx: Variant, 布尔: Variant) -> void:
	if ctx == null or not Params.气势总攻开():
		return
	ctx.全队憋大招 = J.truthy(布尔)

## 回合开始时的战术段：只剩「当局全队憋大招」（旧的预约战术已移除）
static func 战术回合(ctx: Variant) -> void:
	if ctx == null or not Params.气势总攻开():
		return
	if ctx.has("当局全队憋大招"):
		ctx.全队憋大招 = J.truthy(ctx.当局全队憋大招)

static func actionOrder(ctx: Dictionary) -> Array:
	var arr := Units.livingUnits(ctx)
	J.sort(arr, func(a, b):
		var d := Units.speedOf(b) - Units.speedOf(a)
		if d != 0:
			return d
		if a.side != b.side:
			return -1.0 if a.side == "ally" else 1.0
		var c := Fm.colOfSlot(a.slot) - Fm.colOfSlot(b.slot)
		if c != 0:
			return c
		return float(a.slot) - float(b.slot))
	return arr

static func 嘲讽(ctx: Dictionary, 攻击者: Dictionary, 原目标: Dictionary) -> Variant:
	var 守方 := Units.otherSide(攻击者.side)
	if 原目标.side != 守方:
		return null
	var 卫 = Params.同路铁壁护卫(ctx, 攻击者, 原目标)
	if 卫 != null:
		return 卫
	# ★ DECK-1：重装【铁壁护卫】那一回合**必然**替队友挡枪（同列优先，不掷随机数）
	var 铁壁候选 := Units.livingOf(守方, ctx).filter(func(u):
		return Reach.职业是(u, "重装") and not is_same(u, 原目标) and u.hp > 0 and J.same(u.get("铁壁护卫中"), ctx.turn))
	if not 铁壁候选.is_empty():
		var 同列 := 铁壁候选.filter(func(u): return 原目标.get("slot") != null and Fm.colOfSlot(u.slot) == Fm.colOfSlot(原目标.slot))
		var 用: Array = 同列 if not 同列.is_empty() else 铁壁候选
		J.sort(用, func(a, b): return float(a.slot) - float(b.slot))
		return 用[0]
	var 候选 := Units.livingOf(守方, ctx).filter(func(u): return Reach.职业是(u, "重装") and Units.unitRow(u) == Fm.ROW_FRONT and not is_same(u, 原目标) and u.hp > 0)
	if 候选.is_empty():
		return null
	if ctx.rng.next_float() >= 0.5:
		return null
	J.sort(候选, func(a, b):
		var d := float(b.hp) - float(a.hp)
		return d if d != 0 else float(a.slot) - float(b.slot))
	return 候选[0]

static func 镜甲反弹(ctx: Dictionary, 攻击者: Variant, 防御者: Variant, 一击: Variant, 武器: Variant) -> float:
	var 自带: bool = 防御者 != null and J.truthy(防御者.get("词条反弹"))
	var 比 := J.num0(防御者.get("反弹比例")) if 自带 else Params.镜甲反弹比例()
	if not (比 > 0) or not (Params.有敌人机制(防御者, "beamReflect") or 自带):
		return 0.0
	if 自带 and J.truthy(防御者.get("反弹仅近战")) and Reach.rangeKindOf(武器) != Reach.KIND_MELEE():
		return 0.0
	var 受伤 := J.num0(一击.get("伤害")) if 一击 != null else 0.0
	if not (受伤 > 0) or 攻击者 == null or is_same(攻击者, 防御者):
		return 0.0
	if float(攻击者.hp) <= 0:
		return 0.0
	var 反弹 := maxf(0.0, J.round(受伤 * 比))
	var 还没死: bool = float(攻击者.hp) > 0
	攻击者.hp = maxf(0.0, float(攻击者.hp) - 反弹)
	pushLog(ctx, "〔镜甲〕%s 的镜甲把 %s 反弹给 %s（这一下受到 %s × %s%%）" % [防御者.name, J.s(反弹), 攻击者.name, J.s(受伤), J.s(J.round(比 * 100.0))],
		J.merged({"类型": "镜甲", "单位": 防御者.key, "目标": 攻击者.key, "反弹": 反弹, "伤害": 反弹, "原伤害": 受伤,
			"反弹比例": 比, "目标剩余HP": 攻击者.hp}, 谁(防御者), 谁目标(攻击者)))
	if 还没死 and float(攻击者.hp) <= 0:
		Fac.势力击破(ctx, 防御者, 攻击者)
	return 反弹

static func 主武器威力(u: Variant) -> float:
	var 最高 := 0.0
	for e in J.or_(u.get("weapons") if u != null else null, []):
		var w = e.get("t") if e != null else null
		if w == null:
			continue
		var k = Reach.rangeKindOf(w)
		if not J.truthy(k) or Reach.isHealKind(k) or Reach.isSupportKind(k):
			continue
		var p := J.num0(Calc.wv(u, w, "power"))
		if p > 最高:
			最高 = p
	return 最高

static func 自爆(ctx: Dictionary, _击破者: Variant, 死者: Variant, 缘由: Variant = null, 强制: bool = false) -> Variant:
	var 词条自爆: bool = 死者 != null and J.truthy(死者.get("词条自爆"))
	if 死者 != null and J.truthy(死者.get("自爆过")):
		return null
	if not 强制 and not (Params.有敌人机制(死者, "selfDestruct") or 词条自爆):
		return null
	死者.自爆过 = true
	var c := Params.自爆参数()
	var 倍 := (J.num(死者.get("词条自爆倍率")) if J.truthy(死者.get("词条自爆倍率")) else 1.0) if 词条自爆 else 1.0
	var 威力 := J.round(主武器威力(死者) * float(c.威力倍率) * 倍)
	var 落点 := Reach.areaSlots({"fire": "map", "area": c.范围}, Fm.rowOfSlot(死者.slot), Fm.colOfSlot(死者.slot))
	var 武器 := {
		"name": c.武器名, "fire": "map", "area": c.范围, "power": 威力, "hit": 100.0, "critMod": 0.0,
		"stat": "射击", "dmgType": "物理", "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null,
	}
	var 目标方们 := [Units.otherSide(死者.side), 死者.side] if J.truthy(死者.get("自爆两侧")) else [Units.otherSide(死者.side)]
	var 靶子 := []
	for s in 目标方们:
		for t in Units.livingOf(s, ctx):
			if not is_same(t, 死者) and J.inc(落点, t.slot):
				靶子.append(t)
	var 记录们 := []
	var 打死的 := []
	var 合计 := 0.0
	var 少挨 := 0.0
	for t in 靶子:
		var rec := Calc.resolveAttack(死者, t, 武器, ctx, {})
		合计 += J.num0(rec.字段.get("伤害"))
		少挨 += J.num0(rec.字段.get("防御少挨"))
		记录们.append([t, rec])
		if float(t.hp) <= 0:
			打死的.append(t)
	var 缘由文字 = J.or_(缘由, "被击破的瞬间自爆")
	pushLog(ctx, "〔自爆〕%s %s：落点 %s（打掉你 %s%s）" % [死者.name, 缘由文字, "、".join(落点.map(func(s): return Fm.位名(s))), J.s(合计), "，防御少挨 %s" % J.s(少挨) if 少挨 > 0 else ""],
		J.merged(J.merged({
			"类型": "自爆", "单位": 死者.key, "武器": 武器.name, "威力": 威力, "落点们": 落点, "自爆": true,
			"自爆伤害": 合计, "自爆少挨": 少挨, "命中数": float(靶子.size()),
			"目标位们": 落点, "目标方们": 落点.map(func(_s): return Units.otherSide(死者.side)),
		}, {"自爆缘由": 缘由} if J.truthy(缘由) else null), 谁(死者)))
	for pair in 记录们:
		var t = pair[0]
		var rec = pair[1]
		pushLog(ctx, "〔%s〕%s" % [武器.name, rec.文本],
			J.merged(J.merged({"类型": "攻击", "单位": 死者.key, "目标": t.key, "武器": 武器.name, "自爆": true, "自爆落点": 落点}, 谁(死者), 谁目标(t)), rec.字段))
	for t in 打死的:
		Fac.势力击破(ctx, 死者, t)
	return {"落点": 落点, "威力": 威力, "合计": 合计, "少挨": 少挨, "台数": float(靶子.size())}

# ======================== 敌方词条的回合效果 ========================
static func 词条到点自爆(ctx: Dictionary, 在场的: Array) -> float:
	if not Params.词条开():
		return 0.0
	var 次 := 0.0
	for u in Units.livingOf("enemy", ctx):
		if not (J.num(u.get("自爆回合")) > 0) or J.truthy(u.get("自爆过")):
			continue
		if float(ctx.turn) < J.num(u.自爆回合):
			continue
		if not J.inc(在场的, u):
			continue
		自爆(ctx, null, u, "到点自爆", true)
		u.hp = 0.0
		次 += 1.0
	if 次 != 0:
		ctx.result = J.or_(ctx.result, Setup.checkResult(ctx))
	return 次

static func 词条冷却延长(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 数 := 0.0
	for e in Units.livingOf("enemy", ctx):
		var v := J.num(e.get("冷却延长"))
		if is_finite(v) and v > 0:
			数 = maxf(数, minf(2.0, J.round(v)))
	if 数 == 0:
		return 0.0
	var 受影响 := []
	for u in Units.livingOf("ally", ctx):
		for e in J.or_(u.get("weapons"), []):
			if e == null or not J.truthy(e.get("t")):
				continue
			var 大招 := Ai.isUltimate(e.t)
			if not (J.num0(e.t.get("cd")) > 0 or 大招):
				continue
			var 冷却中 := J.num0(e.get("cd")) > 0
			var 本回合能用 := not 冷却中 and float(ctx.turn) >= (J.num0(e.get("readyTurn")) if J.truthy(e.get("readyTurn")) else 1.0)
			if not 冷却中 and not 本回合能用:
				continue
			if J.truthy(e.get("词条已延")):
				continue
			e.cd = J.num0(e.get("cd")) + 数
			e.词条已延 = true
			受影响.append("%s【%s】" % [u.name, e.t.name])
	if not 受影响.is_empty():
		pushLog(ctx, "〔电磁干扰〕第 %s 回合：我方 %d 把带冷却的武器被延长 %s 回合（%s%s）" % [J.s(ctx.turn), 受影响.size(), J.s(数), "、".join(受影响.slice(0, 4)), "…" if 受影响.size() > 4 else ""],
			{"类型": "冷却延长", "延长数": 数, "台数": float(受影响.size()), "武器们": 受影响})
	return float(受影响.size())

static func 词条隐身刷新(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 次 := 0.0
	for u in Units.livingOf("enemy", ctx):
		if not J.truthy(u.get("隐身刷新")):
			continue
		u.隐身中 = true
		次 += 1.0
	return 次

static func 应用全场词条(ctx: Dictionary) -> float:
	if not Params.词条开():
		return 0.0
	var 生效 = null
	for e in J.or_(ctx.get("enemies"), []):
		if J.truthy(e.get("词条全场")):
			生效 = e.词条全场
			break
	if 生效 == null:
		return 0.0
	var 持续 := J.num(J.or_(Params.词条参数(), {}).get("全员命中持续"))
	var 剩余 := 持续 if (is_finite(持续) and 持续 > 0) else 9999.0
	var 台 := 0.0
	for u in Units.livingUnits(ctx):
		u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != "烟幕")
		var 条 := {"src": "烟幕", "剩余": 剩余}
		if J.truthy(生效.get("命中")):
			条.hit = 生效.命中
		u.buffs.append(条)
		台 += 1.0
	return 台

static func 换同源增益(u: Dictionary, src: Variant, buff: Dictionary) -> void:
	u.buffs = J.or_(u.get("buffs"), []).filter(func(b): return b.get("src") != src)
	u.buffs.append(J.merged({"src": src, "剩余": 1.0}, buff))

# ======================== 战术卡牌 ========================
## ★ MITH-1：卡牌实例号兜底计数器（没有 ctx 可发号时用；只在秘银 v0.2 开着时会动）
static var _实例号计数: int = 0

## ★ MITH-1：这张牌算不算「秘银连携计入口径」。
## 秘银势力牌（归属 == 秘银）、秘银角色牌（角色所属势力 == 秘银）、TDD-1 衍生牌（是TDD1 == true）算；
## 其他势力牌 / 通用统帅牌 / 职业牌都不算 —— 打出它们既**不加** `本回合秘银牌数`、也**不清零**。
static func 是秘银计入牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if str(card.get("归属", "")) == "秘银":
		return true
	if str(card.get("角色所属势力", "")) == "秘银":
		return true
	return bool(card.get("是TDD1", false))

## ★ MITH-2：动态降费 —— 实际耗气 = 基础耗气 − 下张秘银牌降费 −（下一张宗介大招牌降费，仅 U7 大招）。
## 只在**秘银 v0.2 开着**且这张牌算秘银计入牌时才减（下限 0）；关着时 = 基础耗气，既有路径逐字不变。
static func 实际耗气(ctx: Variant, card: Variant) -> int:
	if not (card is Dictionary):
		return 0
	var 耗 := int(J.round(J.num0(card.get("耗气"))))
	if not Params.秘银v02开(ctx) or not 是秘银计入牌(card):
		return maxi(0, 耗)
	var 降 := int(ctx.get("下张秘银牌降费", 0))
	if str(card.get("角色", "")) == "U7" and str(card.get("类型", "")) == "大招":
		降 += int(ctx.get("下张宗介大招降费", 0))
	return maxi(0, 耗 - 降)

## ★ MITH-2：这张牌现在能不能打（门面 / 测试复用的**纯读**口子：冷却 / 次数 / 断路器 3 / 绑定角色 /
## 占行动 / 气势全查一遍，一个字节的状态都不改）。
static func 卡可打吗(ctx: Variant, card: Variant) -> bool:
	if ctx == null or not (card is Dictionary):
		return false
	if card.get("剩余次数") != null and float(card.剩余次数) <= 0:
		return false
	if J.num0(card.get("当前冷却")) > 0:
		return false
	if not bool(card.get("衍生", false)) and int(card.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
		return false
	var 耗 := J.num0(card.get("耗气"))
	if Params.秘银v02开(ctx):
		if 不可打原因(ctx, card) != "":
			return false
		耗 = float(实际耗气(ctx, card))
	return J.num0(ctx.get("气势")) >= 耗

## ★ MITH-2：秘银 v0.2 专属的「不可打出」原因（空串 = 可打）。
##   ① 绑定的角色（占行动 / 角色们 / 角色）任一人阵亡 → 不可打；
##   ② 占行动的角色本回合已经行动过 → 不可打（合体技因此要三个人本回合都没动）。
static func 不可打原因(ctx: Dictionary, card: Dictionary) -> String:
	for k in MithrilV02Cards.涉及角色键(card):
		if _找队友(ctx, str(k)) == null:
			return "角色已阵亡（%s）" % str(k)
	for k in MithrilV02Cards.占行动键(card):
		var u = _找队友(ctx, str(k))
		if u != null and int(u.get("actedTurn", -1)) == int(ctx.get("turn", 1)):
			return "角色本回合已行动（%s）" % str(k)
	return ""

static func _找队友(ctx: Variant, 键: String) -> Variant:
	if not (ctx is Dictionary):
		return null
	for u in J.or_(ctx.get("allies"), []):
		if u != null and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key")) == 键:
			return u
	return null

## ★ MITH-2：打出占行动的牌 → 这些角色本回合的普通自动行动被这一张牌替代。
static func _占用行动(ctx: Dictionary, card: Dictionary) -> Array:
	var 占了: Array = []
	for k in MithrilV02Cards.占行动键(card):
		var u = _找队友(ctx, str(k))
		if u == null:
			continue
		u["actedTurn"] = int(ctx.get("turn", 1))
		占了.append(str(k))
	return 占了

## ★ MITH-2：消费降费状态（只有真的吃了降费的秘银牌才清 —— 打非秘银牌不清）。
static func _消费降费(ctx: Dictionary, card: Dictionary) -> void:
	if not Params.秘银v02开(ctx) or not 是秘银计入牌(card):
		return
	ctx["下张秘银牌降费"] = 0
	if str(card.get("角色", "")) == "U7" and str(card.get("类型", "")) == "大招":
		ctx["下张宗介大招降费"] = 0

static func 提取单位三层信息(u: Variant) -> Dictionary:
	if not J.truthy(u):
		return {"键": "", "职业": "", "势力": ""}
	var 键
	if u is String:
		键 = u
	else:
		键 = J.or_(J.or_(J.or_(J.or_(u.get("tplKey"), u.get("key")), u.get("mech")), u.get("键")), "")
	var tpl = DataFn.tplOf(键) if J.truthy(键) else null
	var ut = u.get("tags") if u is Dictionary else null
	var tt = tpl.get("tags") if tpl != null else null
	var 职业 = J.or_(J.or_(J.or_(J.g(ut, "战斗分类"), J.g(u, "职业")), J.g(tt, "战斗分类")), "")
	var 势力 = J.or_(J.or_(J.or_(J.g(ut, "势力"), J.g(u, "势力")), J.g(tt, "势力")), "")
	return {"键": 键, "职业": 职业, "势力": 势力}

# ==========================================================================================
# ★ UX-2（对应作者反馈第 4 条「发牌需要做一些示意，牌来自哪些机体」）：
#   一张战术牌「来自我方哪台机体」的**纯读**解析。
#
#   纪律（硬性红线 3）：
#     · 一个随机数都不掷（`ctx.rng` 一次都不碰）；
#     · 不改任何状态（只读 `card` 与自己传进来的单位数组，连 `ctx` 都不进）；
#     · 老数据（没有 `角色` / `角色们` 字段的 32 张牌）照样能解析 —— 退回 `归属`。
#   调用点：`发牌` 日志条目（本文件两处）+ 门面 `GameSession.hand_cards()` / `card_hover_text()`。
# ==========================================================================================

## 一张战术牌「来自我方哪台机体」。`单位们` = 我方单位数组（战斗里就是 `ctx.allies`；
## 局外可以由编队名册造同样形状的伪单位，字段只用 `key` / `name` / `slot` / `tags` / `hp`）。
##
## 返回 `{文本, 位, 类别}`：
##   · `文本` 一律以 `来自：` 开头 ——
##       角色牌 / 专属牌：`来自：刹那（前1）`（合体技多台 = `来自：宗介/克鲁兹（前1/后2）`）
##       职业牌：        `来自：刹那·近卫`（多台 = `来自：刹那/洛克昂·狙击`）
##       势力牌：        `来自：宗介/毛·秘银`
##       统帅通用牌：    `来自：指挥官（统帅）`
##       场上没有对应机体（阵亡 / 没上阵）：`来自：近卫（职业）`
##   · `位`   = 对应机体的位名数组（`["前1"]`；统帅牌 / 匹配不到 = `[]`）——表现层拿它做联动高亮
##   · `类别` = `角色` / `职业` / `势力` / `统帅` / `未知`
static func 牌来源机体(card: Variant, 单位们: Variant) -> Dictionary:
	if not (card is Dictionary):
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "未知"}
	var c: Dictionary = card
	var 层 := str(c.get("层级", ""))
	var 归 := str(c.get("归属", ""))
	var 表: Array = 单位们 if 单位们 is Array else []
	if 层 == "统帅":
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "统帅"}
	var 命中: Array = []
	if 层 == "角色":
		var 角色们: Array = c.get("角色们") if c.get("角色们") is Array else []
		if 角色们.is_empty():
			var 单 := str(c.get("角色", ""))
			角色们 = [单 if not 单.is_empty() else 归]
		for u in 表:
			if _单位键属于(u, 角色们):
				命中.append(u)
	elif 层 == "职业":
		if not 归.is_empty():
			for u in 表:
				if _单位职业(u) == 归:
					命中.append(u)
	elif 层 == "势力":
		if not 归.is_empty():
			for u in 表:
				if _单位势力(u) == 归:
					命中.append(u)
	else:
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "未知"}
	var 活: Array = 命中.filter(func(u): return float(u.get("hp", 1.0)) > 0.0)
	var 用: Array = 活 if not 活.is_empty() else 命中
	if 用.is_empty():
		# 场上没有对应机体：只报这张牌挂在哪个角色 / 职业 / 势力上（不编名字）。
		if 层 == "角色":
			var 谁 := str(c.get("角色", ""))
			if 谁.is_empty():
				谁 = 归
			return {"文本": "来自：%s（角色）" % 谁, "位": [], "类别": 层}
		return {"文本": "来自：%s（%s）" % [归, 层], "位": [], "类别": 层}
	var 名们: Array = []
	var 位们: Array = []
	for u in 用:
		名们.append(_单位显示名(u))
		var s: Variant = u.get("slot", null)
		位们.append(Fm.位名(float(s)) if s != null else "")
	var 已阵亡 := 活.is_empty()
	var 名字 := "/".join(名们)
	if 层 == "角色":
		var 位文 := "/".join(位们)
		if 已阵亡:
			位文 = (位文 + " · 已阵亡") if not 位文.is_empty() else "已阵亡"
		return {"文本": "来自：%s（%s）" % [名字, 位文], "位": 位们, "类别": 层}
	var 文 := "来自：%s·%s" % [名字, 归]
	if 已阵亡:
		文 += "（已阵亡）"
	return {"文本": 文, "位": 位们, "类别": 层}

## 单位键（`tplKey` → `key` → `mech`，与 `提取单位三层信息` 同一套认法）。
static func _单位键(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var d: Dictionary = u
	for k in ["tplKey", "key", "mech"]:
		var v: Variant = d.get(k)
		if v != null and str(v) != "":
			return str(v)
	return ""

static func _单位键属于(u: Variant, 键们: Array) -> bool:
	var k := _单位键(u)
	if k.is_empty():
		return false
	for x in 键们:
		if str(x) == k:
			return true
	return false

## 单位的战斗分类（`tags.战斗分类` 优先，其次 `职业` 字段）—— 职业牌按它归位。
static func _单位职业(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var 标: Variant = (u as Dictionary).get("tags")
	if 标 is Dictionary:
		var a := str((标 as Dictionary).get("战斗分类", ""))
		if not a.is_empty():
			return a
	var b: Variant = (u as Dictionary).get("职业")
	return str(b) if b != null else ""

## 单位的势力（`tags.势力` 优先，其次 `势力` 字段）—— 势力牌按它归位。
static func _单位势力(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var 标: Variant = (u as Dictionary).get("tags")
	if 标 is Dictionary:
		var a := str((标 as Dictionary).get("势力", ""))
		if not a.is_empty():
			return a
	var b: Variant = (u as Dictionary).get("势力")
	return str(b) if b != null else ""

## 单位在卡面上该被叫成什么（机师名 → 短名 → 机体键）。
static func _单位显示名(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var n := str((u as Dictionary).get("name", ""))
	if not n.is_empty():
		return n
	var 短 := str((u as Dictionary).get("short", ""))
	return 短 if not 短.is_empty() else _单位键(u)

static func 克隆战术牌(c: Variant, ctx: Variant = null) -> Variant:
	if c == null:
		return null
	var 牌 = J.merged(c, {"剩余次数": J.num(c.限次) if c.get("限次") != null else 1.0, "当前冷却": 0.0, "新触发": false, "触发回合": null})
	# ★ MITH-1：给每张克隆出来的牌发一个**唯一实例号**（手里同时有两张 `id` 都是 "TDD-1" 的衍生牌时，
	#   按实例号找牌 / 只删那一个下标，不会一次全删）。秘银 v0.2 关着 = 一张牌都不多发字段。
	if Params.秘银v02开(ctx):
		if ctx is Dictionary:
			# 惰性起号：`_下个卡牌实例号` 从 0（初始值）起算，第一张牌的实例号就是 1；
			# 这样开局装填阶段别的克隆调用不会把号段提前吃掉。
			var n := int(ctx.get("_下个卡牌实例号", 0))
			if n < 1:
				牌["_实例号"] = 1
				ctx["_下个卡牌实例号"] = 2
			else:
				牌["_实例号"] = n
				ctx["_下个卡牌实例号"] = n + 1
		else:
			_实例号计数 += 1
			牌["_实例号"] = _实例号计数
	return 牌

static func 生成队伍牌池(allies: Variant, 选项: Variant, ctx: Variant = null) -> Dictionary:
	var 列表: Array = allies if allies is Array else []
	var 职业集 := []
	var 势力集 := []
	var 角色集 := []
	for u in 列表:
		var info := 提取单位三层信息(u)
		if J.truthy(info.职业) and not J.inc(职业集, info.职业):
			职业集.append(info.职业)
		if J.truthy(info.势力) and not J.inc(势力集, info.势力):
			势力集.append(info.势力)
		if J.truthy(info.键) and not J.inc(角色集, info.键):
			角色集.append(info.键)
	var 全表: Array = Db.T.战术卡牌表 if Db.T.战术卡牌表 is Array else []
	var 已选原始: Array = 选项.已选战术牌 if (选项 != null and 选项.get("已选战术牌") is Array) else []
	var 已选Ids := 已选原始.map(func(x): return x if x is String else (x.get("id") if x != null else null)).filter(func(x): return J.truthy(x))
	var 已收 := {}
	var 全部牌池 := []
	for id in 已选Ids:
		var found = J.find(全表, func(c): return c != null and c.id == id)
		if found != null and not 已收.has(found.id):
			已收[found.id] = true
			全部牌池.append(克隆战术牌(found, ctx))
	for c in 全表:
		if c == null or 已收.has(c.id):
			continue
		var 匹配: bool = (c.层级 == "职业" and J.inc(职业集, c.归属)) \
			or (c.层级 == "势力" and J.inc(势力集, c.归属)) \
			or (c.层级 == "角色" and J.inc(角色集, c.归属)) \
			or (c.层级 == "统帅" and (选项 == null or 选项.get("含统帅牌") != false))
		if 匹配:
			已收[c.id] = true
			全部牌池.append(克隆战术牌(c, ctx))
	if 选项 != null and J.truthy(选项.get("补齐基础激励")) and not 已收.has("C_CMD_1"):
		var 基础激励 = J.find(全表, func(c): return c != null and c.id == "C_CMD_1")
		if 基础激励 != null:
			已收["C_CMD_1"] = true
			全部牌池.push_front(克隆战术牌(基础激励, ctx))
	# ★ MITH-2：秘银 v0.2 牌池装填 —— 开关开着、且队伍里有秘银成员时，把 v0.1 的旧秘银牌
	#   （F_MITH_1 / F_MITH_2 / 旧版秘银角色牌）换成本模块的 26 张 v0.2 牌：
	#   在场成员的角色牌（每人 3 张）+ 合体技（U7 / U2 / U6 都在场时）+ 9 张势力牌。
	#   装填之后照旧走「初始手牌上限 6 张 + 其余进待触发战术牌」这条现成通道。
	#   关着（默认）= 这一段一行都不执行（硬性红线 2）。
	var 秘银v02: bool = Params.秘银v02开(ctx) and J.inc(势力集, "秘银")
	if 秘银v02:
		全部牌池 = 全部牌池.filter(func(c): return not MithrilV02Cards.是旧秘银牌(c))
		全部牌池.append_array(MithrilV02Cards.装填(ctx, 角色集))
	var 初始上限 := J.num0(J.or_(选项.get("初始手牌上限") if 选项 != null else null, Params.战术卡牌参数().get("初始手牌上限")))
	if 初始上限 == 0:
		初始上限 = 6.0
	var 初始候选 := 全部牌池.filter(func(c): return c.get("入牌") == "初始")
	var 免费回气先 := func(a, b):
		var a0 := 0.0 if (J.num(a.get("耗气")) == 0 and J.num(a.get("回气")) > 0) else 1.0
		var b0 := 0.0 if (J.num(b.get("耗气")) == 0 and J.num(b.get("回气")) > 0) else 1.0
		return a0 - b0
	var 初始手牌: Array
	var 候补初始牌 := []
	if 选项 != null and 选项.get("手牌装填") == 手牌装填_JS参考:
		# JS 参考版（js-reference-final）原样：职业 → 势力 → 角色的表序，满上限后其余初始牌直接丢弃。只给黄金样例对账用。
		J.sort(初始候选, 免费回气先)
		初始手牌 = 初始候选.slice(0, int(初始上限)).map(func(c): return 克隆战术牌(c, ctx))
	else:
		# 正式规则（已接受差异 D-01，ARGON 2026-10-16）：玩家已选 → 基础激励 → 角色 → 势力 → 职业 → 统帅；
		# 超出上限的初始牌不丢弃，进「候补初始牌」，每回合开始按序补到上限（Flow.候补补位）。
		var 已选 := 已选Ids
		J.sort(初始候选, func(a, b): return float(_装填档(a, 已选)) - float(_装填档(b, 已选)))
		初始手牌 = 初始候选.slice(0, int(初始上限)).map(func(c): return 克隆战术牌(c, ctx))
		J.sort(初始手牌, 免费回气先)
		候补初始牌 = 初始候选.slice(int(初始上限)).map(func(c): return 克隆战术牌(c, ctx))
	var 待触发牌 := 全部牌池.filter(func(c): return c.get("入牌") == "条件").map(func(c): return 克隆战术牌(c, ctx))
	return {
		"全部牌池": 全部牌池, "初始手牌": 初始手牌, "待触发牌": 待触发牌, "候补初始牌": 候补初始牌,
		"职业牌池": 全部牌池.filter(func(c): return c.层级 == "职业"),
		"势力牌池": 全部牌池.filter(func(c): return c.层级 == "势力"),
		"角色牌池": 全部牌池.filter(func(c): return c.层级 == "角色"),
	}

## 选项.手牌装填 取这个值 = 按 JS 参考版装填（黄金样例对账开关）；不写 = 正式规则
const 手牌装填_JS参考 := "JS参考"

## 正式装填顺序的档位（越小越先进手牌；同档按牌表顺序）
static func _装填档(c: Dictionary, 已选Ids: Array) -> int:
	if J.inc(已选Ids, c.id):
		return 0
	if c.id == "C_CMD_1":
		return 1          # 基础激励（开局补齐的 0 耗 +25 回气牌）保底在手
	match c.get("层级"):
		"角色": return 2
		"势力": return 3
		"职业": return 4
	return 5

## 每回合开始：手牌不到初始上限时，从候补初始牌按序补入（不超过手牌总上限）
static func 候补补位(ctx: Dictionary) -> Array:
	var 候补 = ctx.get("候补初始牌")
	if not (候补 is Array) or 候补.is_empty() or not Params.战术卡牌开(ctx):
		return []
	var 上限 := J.num0(Params.战术卡牌参数().get("初始手牌上限"))
	if 上限 == 0:
		上限 = 6.0
	var 总上限 := J.num0(Params.战术卡牌参数().get("手牌总上限"))
	if 总上限 == 0:
		总上限 = 10.0
	var 补了 := []
	while not 候补.is_empty() and float(ctx.战术手牌.size()) < minf(上限, 总上限):
		var card = 候补.pop_front()
		# ★ MITH-1 断路器 3 / Loop-3：本回合已打出过的、或冷却没归零的候补牌跳过（本回合内不再入手）
		#   —— 老数据里没有这两个字段，一个都跳不掉（候补装填行为与改前逐字一致）。
		if int(card.get("上次打出回合", -1)) == int(ctx.get("turn", 1)) or int(card.get("当前冷却", 0)) > 0:
			continue
		card.新触发 = true
		card.触发回合 = ctx.turn
		ctx.战术手牌.append(card)
		补了.append(card)
		# ★ UX-2：发牌来源（纯读，不掷随机数）。`来源文本` / `来源位` 是**只给展示**的字段
		#   （黄金样例对拍把它们当 DISPLAY_ONLY 跳过，见 tests/golden_runner.gd）。
		var 源 := 牌来源机体(card, ctx.get("allies"))
		pushLog(ctx, "〔发牌〕手牌有空位 → 补入初始牌【%s】· %s" % [J.s(card.get("名")), 源.文本], {
			"类型": "发牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
			"触发条件码": "候补补位", "精神标签": card.get("精神标签"), "回合": ctx.turn,
			"来源文本": 源.文本, "来源位": 源.位,
		})
	return 补了

static func _是(u: Variant, k: String) -> bool:
	return u != null and (u.get("key") == k or u.get("tplKey") == k)

static func 是否满足卡牌触发条件(card: Variant, ctx: Variant, 事件类型: Variant, 载荷: Variant) -> bool:
	if card == null or ctx == null:
		return false
	var code = card.get("触发条件码")
	if J.truthy(事件类型) and 事件类型 == code:
		return true
	var 计: Dictionary = ctx.战况计数 if ctx.get("战况计数") is Dictionary else {}
	var allies = J.or_(ctx.get("allies"), []).filter(func(u): return u != null and u.hp > 0)
	var enemies = J.or_(ctx.get("enemies"), []).filter(func(e): return e != null and e.hp > 0)
	var p: Dictionary = 载荷 if 载荷 is Dictionary else {}
	# ★ MITH-1：声明式触发条件表（大招牌化 F1；秘银 v0.2 的「触发连携 >= N」「打出TDD1 >= N」用它）。
	#   老数据里没有 `触发条件` 这个键 → 一个字节都不变（黄金样例的 14 个 code 分支完全不动）。
	var 触发条件 = card.get("触发条件")
	if 触发条件 is Dictionary:
		return _声明式触发(触发条件, ctx, 事件类型, 计, card)
	var 攻 = p.get("攻击者")
	var 目 = p.get("目标")
	match code:
		"HEAVY_LOW_HP":
			if 目 != null and 目.side == "ally" and Reach.职业是(目, "重装") and float(目.maxHp) > 0 and float(目.hp) / float(目.maxHp) < 0.65:
				return true
			return J.some(J.or_(ctx.get("allies"), []), func(u): return u != null and float(u.maxHp) > 0 and Reach.职业是(u, "重装") and u.hp > 0 and float(u.hp) / float(u.maxHp) < 0.65)
		"GUARD_KILL_OR_CRIT":
			return 攻 != null and 攻.side == "ally" and Reach.职业是(攻, "近卫") and (J.truthy(p.get("击破")) or J.num0(p.get("暴击")) > 0)
		"ANY_MISS":
			return J.num0(计.get("未命中段")) >= 1 or J.num0(p.get("未命中段数")) >= 1
		"ENEMY_MARK_2":
			if J.num0(p.get("层数")) >= 2:
				return true
			return J.some(enemies, func(e):
				var 经 := Calc.标定经济层数(e)
				var 秘 = J.or_(e.get("debuffs"), []).filter(func(b): return b != null and J.s(J.or_(b.get("src"), "")).contains("秘银")).size()
				return 经 >= 2 or 秘 >= 2 or J.num0(e.get("标定层数")) >= 2)
		"CMD_TURN2_OR_ENEMY3":
			var t := J.num0(ctx.get("turn"))
			return (t if t != 0 else 1.0) >= 2 or enemies.size() >= 3
		"SPEC_HIT":
			return 攻 != null and 攻.side == "ally" and Reach.职业是(攻, "特种") and J.truthy(p.get("命中"))
		"SEED_30":
			if J.num0(p.get("SEED累计")) >= 30:
				return true
			return J.some(J.or_(ctx.get("allies"), []), func(u):
				if u == null:
					return false
				return FacSeed.SEED累计(u) >= 30 or FacSeed.SEED已觉醒(u) or J.num0(u.get("seed")) >= 30)
		"METEOR_SOLO":
			return J.some(allies, func(u):
				if 提取单位三层信息(u).势力 != "流星小队":
					return false
				var 状 = J.g(J.g(u, "势力状态"), "流星小队")
				if 状 != null and J.truthy(状.get("单独行动")):
					return true
				if u.get("slot") == null:
					return false
				var 禁 := J.concat(Fm.相邻位(u.slot), Fm.遮挡位(u.slot))
				return not J.some(allies, func(o): return not is_same(o, u) and J.inc(禁, o.slot)))
		"MOON_ECHO_OR_HIT":
			if J.num0(计.get("残月或月国命中")) >= 1:
				return true
			return 攻 != null and 攻.side == "ally" and 提取单位三层信息(攻).势力 == "月球王国" and J.num0(p.get("伤害")) > 0
		"CB_TRANSAM_OR_HIT":
			if 目 != null and 目.side == "ally" and 提取单位三层信息(目).势力 == "天人" and J.num0(p.get("伤害")) > 0:
				return true
			return J.some(J.or_(ctx.get("allies"), []), func(u):
				return u != null and 提取单位三层信息(u).势力 == "天人" and (FacCb.天人激活(u) or (float(u.maxHp) > 0 and float(u.hp) < float(u.maxHp))))
		"ATX_MISS_2":
			return J.num0(计.get("未命中段")) >= 2 or J.num0(p.get("未命中段数")) >= 2
		# ★ MITH-1 说明（偏离任务单原文一处，以硬性红线 2 为准）：任务单建议「删除废弃的 MITH_MARK」，
		#   但**黄金样例里 F_MITH_2 的触发条件码就是 MITH_MARK，而且它真的会在秘银队伍里发牌**
		#   （实测：删掉它 → 秘银 15 场对拍全挂，事件少一条「发牌」）。所以这一支**原样保留**，
		#   只把新的两个码 MITH_LINK / MITH_TDD1 挂在旁边。
		"MITH_MARK":
			if J.num0(计.get("秘银标定")) >= 1:
				return true
			return 攻 != null and 攻.side == "ally" and 提取单位三层信息(攻).势力 == "秘银" and J.truthy(p.get("命中"))
		# ★ MITH-1：秘银 v0.2 的两个新触发码。
		"MITH_LINK", "触发连携":
			return J.num0(计.get("触发连携")) >= _触发阈值(card)
		"MITH_TDD1", "打出TDD1":
			return J.num0(计.get("打出TDD1")) >= _触发阈值(card)
		"CB1_HIT_OR_TA":
			if J.num0(计.get("刹那命中或TA")) >= 1:
				return true
			if _是(攻, "CB1") and J.num0(p.get("伤害")) > 0:
				return true
			return J.some(J.or_(ctx.get("allies"), []), func(u): return u != null and u.hp > 0 and _是(u, "CB1") and FacCb.天人激活(u))
		"A1_HIT_OR_MISS":
			if J.num0(计.get("响介受击或打空")) >= 1:
				return true
			if 目 != null and 目.side == "ally" and _是(目, "A1") and J.num0(p.get("伤害")) > 0:
				return true
			return J.some(J.or_(ctx.get("allies"), []), func(u): return u != null and u.hp > 0 and float(u.maxHp) > 0 and _是(u, "A1") and float(u.hp) < float(u.maxHp))
		"MORALE_75":
			return J.num0(ctx.get("气势")) >= 75
	return false

## ★ MITH-1 / MITH-2：声明式触发条件表求值（`card["触发条件"] = {类型, 阈值, …}`）。认不出来 = 不满足（不静默放行）。
## 老数据（32 张牌）没有 `触发条件` 这个键 → 一段都走不到；这里的新类型全部是秘银 v0.2 的牌在用。
static func _声明式触发(cond: Dictionary, ctx: Variant, 事件类型: Variant, 计: Dictionary, card: Variant = null) -> bool:
	var 类型 := str(cond.get("类型", ""))
	var 阈值 := int(cond.get("阈值", 1))
	if 阈值 < 1:
		阈值 = 1
	match 类型:
		"开局在手":
			# 首发资格由装填（`入牌 = 初始`）负责；**回库型** v0.2 牌回到待触发池之后，
			# 「开局在手」就表示「这张牌本来就该在手上」——冷却归零 + 断路器 3 放行的任意发牌时机都该发回来。
			if card is Dictionary and J.truthy(card.get("回库")):
				return true
			return str(事件类型) == "开局"
		"触发连携":
			return int(计.get("触发连携", 0)) >= 阈值
		"打出TDD1":
			return int(计.get("打出TDD1", 0)) >= 阈值
		"未命中段", "打空":
			return int(计.get("未命中段", 0)) >= 阈值
		"第N回合起":
			return int(ctx.get("turn", 1)) >= 阈值
		"气势":
			return int(ctx.get("气势", 0)) >= 阈值
		# ---------------- ★ MITH-2：秘银 v0.2 的 6 个新事件类型 ----------------
		"宗介HP或受击":
			return MithrilV02Cards.宗介低血或受击(ctx, J.num0(cond.get("hp_pct")), int(cond.get("受击", 4)))
		"克鲁佐击破或回合":
			return MithrilV02Cards.克鲁佐击破或回合(ctx, int(cond.get("击破", 1)), int(cond.get("回合", 3)))
		"乌鲁兹三角":
			var 要 := int(cond.get("触发连携", 6))
			return int(计.get("触发连携", 0)) >= maxi(1, 要) and MithrilV02Cards.三人都在场(ctx)
		"秘银受击":
			return int(计.get("秘银受击", 0)) >= 阈值
		"秘银低血":
			return MithrilV02Cards.秘银低血(ctx, J.num0(cond.get("hp_pct")))
		"打出过秘银大招":
			return int(计.get("打出秘银大招", 0)) >= 阈值
	return false

## ★ MITH-1：`触发阈值` 字段（缺省 1，最小 1）
static func _触发阈值(card: Dictionary) -> float:
	var v := J.num(card.get("触发阈值"))
	return v if (is_finite(v) and v >= 1.0) else 1.0

static func 气势变动后发牌(ctx: Variant) -> Array:
	if ctx == null or not Params.战术卡牌开(ctx):
		return []
	return 检查条件发牌(ctx, "气势变动", {"回合": ctx.turn if J.truthy(ctx.turn) else 1.0})

static func 检查条件发牌(ctx: Variant, 事件类型: Variant, 载荷: Variant) -> Array:
	if ctx == null or not Params.战术卡牌开(ctx):
		return []
	# ★ MITH-2：秘银 v0.2 开着时，绑定角色已阵亡的秘银角色牌 / 合体技先从手牌与待触发池里移除
	#   （「检查时移除」就在这一句；关着时一行都不执行）。
	if Params.秘银v02开(ctx):
		MithrilV02Cards.清理阵亡卡牌(ctx)
	if not (ctx.get("待触发战术牌") is Array) or ctx.待触发战术牌.is_empty():
		return []
	if not (ctx.get("战术手牌") is Array):
		ctx.战术手牌 = []
	var 手牌总上限 := J.num0(Params.战术卡牌参数().get("手牌总上限"))
	if 手牌总上限 == 0:
		手牌总上限 = 10.0
	var 新发牌们 := []
	var 剩余待触发 := []
	for card in ctx.待触发战术牌:
		if card == null:
			continue
		# ★ MITH-1 断路器 3（最关键铁律）：非衍生牌本回合已经打出过 → 本回合内绝不再发入手牌
		#   （每张非衍生牌每回合最多打出 1 次）。关着秘银 v0.2 时没有牌带 `上次打出回合`，一个都跳不掉。
		if not bool(card.get("衍生", false)) and int(card.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
			剩余待触发.append(card)   # 只是这一回合不发，牌必须留在待触发池里（下回合冷却归零还能回来）
			continue
		# ★ MITH-1 Loop-3 断路器：冷却没归零不发牌
		if int(card.get("当前冷却", 0)) > 0:
			剩余待触发.append(card)
			continue
		if not 是否满足卡牌触发条件(card, ctx, 事件类型, 载荷):
			剩余待触发.append(card)
			continue
		if float(ctx.战术手牌.size()) >= 手牌总上限:
			记满手牌推迟(ctx, card)
			剩余待触发.append(card)
			continue
		card.新触发 = true
		card.触发回合 = ctx.turn if J.truthy(ctx.turn) else 1.0
		ctx.战术手牌.append(card)
		新发牌们.append(card)
		# ★ UX-2：发牌来源（纯读，不掷随机数；只多两个展示字段 + 文本尾巴）。
		var 源 := 牌来源机体(card, ctx.get("allies"))
		pushLog(ctx, "〔发牌〕满足「%s」→ 获得战术牌【%s】· %s" % [J.s(card.get("触发说明")), J.s(card.get("名")), 源.文本], {
			"类型": "发牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
			"触发条件码": card.get("触发条件码"), "触发说明": card.get("触发说明"), "精神标签": card.get("精神标签"),
			"回合": ctx.turn if J.truthy(ctx.turn) else 1.0,
			"来源文本": 源.文本, "来源位": 源.位,
		})
	ctx.待触发战术牌 = 剩余待触发
	return 新发牌们

static func 记满手牌推迟(ctx: Variant, card: Variant) -> bool:
	if ctx == null or card == null:
		return false
	var 计 = ctx.get("战况计数")
	if not (计 is Dictionary):
		return false
	if not (ctx.get("满手牌推迟记录") is Array):
		ctx.满手牌推迟记录 = []
	var 回合 := J.num0(ctx.get("turn"))
	if 回合 == 0:
		回合 = 1.0
	for x in ctx.满手牌推迟记录:
		if x != null and J.num(x.get("回合")) == 回合 and x.get("id") == card.id:
			return false
	if not is_finite(J.num(计.get("满手牌推迟数"))):
		计.满手牌推迟数 = 0.0
	计.满手牌推迟数 = J.num(计.满手牌推迟数) + 1.0
	ctx.满手牌推迟记录.append({"回合": 回合, "id": card.id, "名": card.get("名"), "触发说明": J.or_(card.get("触发说明"), "")})
	return true

static func 加卡牌护盾(u: Variant, 盾值: float) -> float:
	if u == null or not (盾值 > 0):
		return 0.0
	var v := J.round(盾值)
	u.shield = maxf(J.num0(u.get("shield")), v)
	u.shieldHp = J.num0(u.get("shieldHp")) + v
	return v

static func 减单位大招冷却(u: Variant, 减值: Variant, 清零: bool = false) -> void:
	if u == null or not J.is_arr(u.get("weapons")):
		return
	for e in u.weapons:
		if e == null or not J.truthy(e.get("t")):
			continue
		var 是大: bool = Ai.isUltimate(e.t) or J.num(e.t.get("unlock")) >= 20 or J.num(e.t.get("cd")) > 0
		if not 是大:
			continue
		if 清零:
			e.cd = 0.0
			if J.truthy(e.get("readyTurn")) and float(e.readyTurn) > 1:
				e.readyTurn = 1.0
			u.holdUlt = false
		else:
			var n := J.num0(减值)
			if n == 0:
				n = 1.0
			if J.num(e.get("cd")) > 0:
				e.cd = maxf(0.0, float(e.cd) - n)
			if J.truthy(e.get("readyTurn")) and float(e.readyTurn) > 1:
				e.readyTurn = maxf(1.0, float(e.readyTurn) - n)

## ★ MITH-1：「减秘银牌冷却」算子 —— 对**手牌**与**待触发池**里满足秘银口径的牌减当前冷却。
## 排除牌自己（`_实例号 != card._实例号`）：否则一张回库牌打出后当拍就把自己的冷却减回去。
static func 减秘银牌冷却(ctx: Variant, card: Variant, 值: int = 1) -> int:
	if not (ctx is Dictionary) or 值 <= 0:
		return 0
	var 自己 := str(card.get("_实例号", "")) if card is Dictionary else ""
	var 减了 := 0
	for 池 in [ctx.get("战术手牌"), ctx.get("待触发战术牌")]:
		if not (池 is Array):
			continue
		for c in 池:
			if not (c is Dictionary) or not 是秘银计入牌(c):
				continue
			if 自己 != "" and str(c.get("_实例号", "")) == 自己:
				continue
			if int(c.get("当前冷却", 0)) > 0:
				c["当前冷却"] = maxi(0, int(c["当前冷却"]) - 值)
				减了 += 1
	return 减了

static func 卡牌加标定(目标: Variant, 层数: Variant, 来源名: Variant = "战术牌", 补满: bool = false) -> float:
	if 目标 == null:
		return 0.0
	var 上限 := Calc.标定层数上限()
	var d = Calc.标定经济拿条(目标)
	if d == null:
		return 0.0
	d.上限 = 上限
	var 前 := maxf(0.0, J.num0(d.get("层数")))
	var 加 := J.num0(层数)
	d.层数 = 上限 if 补满 else minf(上限, 前 + (加 if 加 != 0 else 1.0))
	if not J.some(J.or_(d.get("来源们"), []), func(g): return g != null and g.get("名") == 来源名):
		d.来源们 = J.concat(J.or_(d.get("来源们"), []), [{"键": "CARD", "名": 来源名, "方": "ally", "怎么来的": "战术牌"}])
	return float(d.层数)

## ★ MITH-1：在手牌里按**身份**找这张牌的下标（提示下标 `提示` 命中就直接用它；否则线性找）。找不到 = -1。
static func _手牌下标(手牌: Array, card: Variant, 提示: int = -1) -> int:
	if 提示 >= 0 and 提示 < 手牌.size() and is_same(手牌[提示], card):
		return 提示
	for i in range(手牌.size()):
		if is_same(手牌[i], card):
			return i
	return -1

static func 打战术牌(ctx: Variant, cardId: Variant) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "无战斗上下文"}
	if not (ctx.get("战术手牌") is Array):
		ctx.战术手牌 = []
	# 找牌：先按 `_实例号` 精确匹配（手里有两张同名 TDD-1 衍生牌时不会打错），否则按 `id` 匹配手牌里的第一张
	# （记录下标 `hand_idx` —— 后面只删这一张，绝不按 id 误删同名衍生牌）。
	var card = null
	var hand_idx := -1
	for i in range(ctx.战术手牌.size()):
		var c = ctx.战术手牌[i]
		if c == null:
			continue
		if str(c.get("_实例号", "")) == str(cardId):
			card = c
			hand_idx = i
			break
	if card == null:
		for i in range(ctx.战术手牌.size()):
			var c = ctx.战术手牌[i]
			if c != null and (str(c.get("id", "")) == str(cardId) or str(c.get("名", "")) == str(cardId)):
				card = c
				hand_idx = i
				break
	if card == null:
		# ★ DECK-4：单机牌组模式下，`公有手牌`（下排）里的衍生攻击卡（秘银 TDD-1 等）也认这条老口子 ——
		#   转到 `打出衍生攻击卡`：不销毁主武器卡、自己销毁、推进秘银连携计数。
		#   关着单机牌组 = 这一个分支一行都不执行（MITH-1 / MITH-2 的老路径逐字不变）。
		if Params.单机牌组_开(ctx):
			var 公牌 = _找公有手牌卡(ctx, cardId)
			if 公牌 is Dictionary and _是衍生卡(公牌):
				var 出 = null
				for u in Units.livingOf("ally", ctx):
					出 = u
					break
				if 出 != null:
					var 转 := 打出衍生攻击卡(ctx, 出.key, 公牌.get("id") if 公牌.get("id") != null else 公牌)
					if J.truthy(转.get("成功")):
						return {"成功": true, "牌": 公牌, "气势": J.num0(ctx.get("气势")),
							"效果摘要": ["公有手牌衍生攻击卡：%s（不销毁主武器卡）" % str(公牌.get("名", ""))],
							"单机牌组": true}
		return {"成功": false, "原因": "手牌中不存在该战术牌"}
	if card.get("剩余次数") != null and float(card.剩余次数) <= 0:
		return {"成功": false, "原因": "使用次数已用尽"}
	if J.num0(card.get("当前冷却")) > 0:
		return {"成功": false, "原因": "冷却中"}
	# ★ MITH-1 断路器 3 前置校验：非衍生牌本回合已经打出过 → 拒绝再打（每张非衍生牌每回合最多 1 次）
	if not bool(card.get("衍生", false)) and int(card.get("上次打出回合", -1)) == int(ctx.get("turn", 1)):
		return {"成功": false, "原因": "本回合已经打出过这张牌"}
	# ★ MITH-2：秘银 v0.2 的角色牌 / 合体技 —— 绑定角色必须都在场存活，占行动的角色本回合尚未行动。
	#   合体技因此天然要求 U7 / U2 / U6 三人都没动过（三人中任一人本回合已行动 → 打不出）。
	if Params.秘银v02开(ctx):
		var 不可 := 不可打原因(ctx, card)
		if 不可 != "":
			return {"成功": false, "原因": 不可}
	var 耗 := J.num0(card.get("耗气"))
	# ★ MITH-2：动态降费（也是秘银 v0.2 才生效；关着时 实际耗气 = 基础耗气）
	if Params.秘银v02开(ctx):
		耗 = float(实际耗气(ctx, card))
	var 回 := J.num0(card.get("回气"))
	var 气势前 := J.num0(ctx.get("气势"))
	if 气势前 < 耗:
		return {"成功": false, "原因": "气势不足"}
	ctx.气势 = maxf(0.0, minf(气势上限(), 气势前 - 耗 + 回))
	# ★ MITH-2：占行动 —— 打出即占用这些角色本回合的行动（替代它们的普通自动行动；
	#   每台机体每回合最多打 1 张占行动的牌 / 大招牌，合体技一次占三人）。
	#   降费状态也在**效果执行之前**消费：这张牌吃掉的是「上一张牌留下的」降费，它自己新给的降费要留给下一张。
	if Params.秘银v02开(ctx):
		_占用行动(ctx, card)
		_消费降费(ctx, card)
	# ★ MITH-1：在效果执行**之前**取「本牌打出前」的连携计数快照 —— 这样第 1 张秘银牌 n_before == 0，
	#   绝不会自己触发自己的【连携·1】（防自触发）。
	var n_before: int = int(ctx.get("本回合秘银牌数", 0))
	if Params.秘银v02开(ctx):
		ctx["_本牌连携前计数"] = n_before
	# 效果按声明式表执行（core/battle/card_effects.gd 的 CARD_OPS）
	var 效果摘要: Array = CardEffects.execute(ctx, card)
	# ---- 【连携】/【连携·N】（断路器 1：衍生牌绝不带连携、绝不触发、绝不加「触发连携」计数）----
	if not bool(card.get("衍生", false)) and int(card.get("连携阈值", 0)) > 0 and card.has("连携效果"):
		var 阈值: int = maxi(1, int(card.get("连携阈值", 1)))
		if n_before >= 阈值:
			# 断路器 4：泰莎的双倍连携封顶 2 倍，同名 / 多次打出绝不叠加成 4 倍
			var 连携倍率: int = clampi(int(ctx.get("本回合连携触发倍率", 1)), 1, 2)
			if not (ctx.get("战况计数") is Dictionary):
				ctx.战况计数 = {}
			ctx["战况计数"]["触发连携"] = int(ctx["战况计数"].get("触发连携", 0)) + 1
			# ★ MITH-3 即时层：日志正文**只有这一处**产出（表现层不自己拼日志文本）。
			#   倍率 1 = 常规【连携】；倍率 ≥ 2 = 吃过「泰莎的指令」，前缀写清是双倍连携。
			var 连携文 := ""
			if 连携倍率 >= 2:
				连携文 = "〔泰莎的指令·双倍连携〕〔连携·%d〕%s 连携效果触发 %d 次（打前秘银牌 %d 张）" % [
					阈值, J.s(card.get("名")), 连携倍率, n_before]
			else:
				连携文 = "〔连携·%d〕%s 触发连携（打前秘银牌 %d 张）" % [阈值, J.s(card.get("名")), n_before]
			pushLog(ctx, 连携文, {
				"类型": "连携", "卡牌ID": card.id, "牌名": card.get("名"), "归属": card.get("归属"),
				"连携阈值": 阈值, "连携前计数": n_before, "连携倍率": 连携倍率, "触发连携": true,
				"双倍连携": 连携倍率 >= 2,
				"回合": ctx.turn if J.truthy(ctx.turn) else 1.0,
			})
			for _i in range(连携倍率):
				效果摘要.append_array(CardEffects.execute_ops(ctx, card, card.get("连携效果", [])))
			# ★ MITH-2：「泰莎的指令」的双倍连携是**下一张牌一次性**的 —— 真触发过这一次就把倍率清回 1
			#   （断路器 4 仍然成立：连着打两张泰莎的指令，倍率封顶仍是 2）。
			if J.truthy(ctx.get("_连携倍率待清")):
				ctx["本回合连携触发倍率"] = 1
				ctx.erase("_连携倍率待清")
	# ---- 效果与连携全部执行完毕之后，再更新计数 ----
	if 是秘银计入牌(card):
		ctx["本回合秘银牌数"] = int(ctx.get("本回合秘银牌数", 0)) + 1
	if bool(card.get("是TDD1", false)):
		if not (ctx.get("战况计数") is Dictionary):
			ctx.战况计数 = {}
		ctx["战况计数"]["打出TDD1"] = int(ctx["战况计数"].get("打出TDD1", 0)) + 1
	# ★ MITH-2：打出秘银大招牌计数（「泰莎的指令」的触发条件用）
	if Params.秘银v02开(ctx):
		if 是秘银计入牌(card) and str(card.get("类型", "")) == "大招":
			if not (ctx.get("战况计数") is Dictionary):
				ctx.战况计数 = {}
			ctx["战况计数"]["打出秘银大招"] = int(ctx["战况计数"].get("打出秘银大招", 0)) + 1
	# ★ MITH-1 断路器 3：记下「本回合已经打出过」——本回合内任何发牌口子都不再把它发回手牌
	if Params.秘银v02开(ctx):
		card["上次打出回合"] = int(ctx.get("turn", 1))
	if not (ctx.get("已打出战术牌") is Array):
		ctx.已打出战术牌 = []
	ctx.已打出战术牌.append(card.id)
	# ---- 卡牌回收 / 衍生牌销毁 ----
	var 回库: bool = Params.秘银v02开(ctx) and bool(card.get("回库", false)) and not bool(card.get("衍生", false))
	if bool(card.get("衍生", false)) or 回库:
		# 只删 hand_idx 那一张（手里另一张同名 TDD-1 留着）；衍生牌打出后**绝不回库**。
		# `hand_idx` 之后按牌**身份**复核一次：效果执行期间若动过手牌（比如置入衍生牌 / 别的牌离手），
		# 下标会漂；漂了就按身份重新定位，绝不误删同名衍生牌。
		var 删位 := _手牌下标(ctx.战术手牌, card, hand_idx)
		if 删位 >= 0:
			ctx.战术手牌.remove_at(删位)
		card.剩余次数 = 0.0
		card.新触发 = false
		if 回库:
			# Loop-3 断路器：基础冷却至少 1（且在本次打牌效果之后才设 —— 当拍不吃自己连携的减冷却）
			card["当前冷却"] = maxi(1, int(card.get("冷却", 1)))
			# ★ MITH-2：回库牌回到待触发池时把次数补满（否则下次发回手里会撞「使用次数已用尽」）
			card["剩余次数"] = float(card.get("限次", 1.0))
			ctx.待触发战术牌.append(card)
	else:
		# ---- 旧版常规战术牌：一字不改 ----
		card.剩余次数 = (J.num(card.剩余次数) if card.get("剩余次数") != null else 1.0) - 1.0
		var 冷 := J.num0(card.get("冷却"))
		card.当前冷却 = 冷 if 冷 != 0 else 1.0
		card.新触发 = false
		if float(card.剩余次数) <= 0:
			var 删位2 := _手牌下标(ctx.战术手牌, card, hand_idx)
			if 删位2 >= 0:
				ctx.战术手牌.remove_at(删位2)
			else:
				ctx.战术手牌 = ctx.战术手牌.filter(func(c): return not is_same(c, card))
	var 气势字 := "-%s/+%s" % [J.s(耗), J.s(回)] if 回 > 0 else "-%s" % J.s(耗)
	pushLog(ctx, "〔战术牌〕发动【%s】（气势 %s）：%s" % [J.s(card.get("名")), 气势字, J.s(card.get("效果说明"))], {
		"类型": "战术牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
		"精神标签": card.get("精神标签"), "耗气": 耗, "回气": 回, "气势前": 气势前, "气势后": ctx.气势,
		"效果说明": card.get("效果说明"), "回合": ctx.turn if J.truthy(ctx.turn) else 1.0,
	})
	检查条件发牌(ctx, "打战术牌", {"cardId": card.id})
	return {"成功": true, "牌": card, "气势": ctx.气势, "效果摘要": 效果摘要}

# ==========================================================================================
# ★ DECK-1 / DECK-2：单机牌组（阶段制 · 单机战意 · 主武器卡 / 衍生攻击卡 · 七职业底座）
#
#   纪律：这一整段**只在 `Params.单机牌组_开(ctx) == true` 时才会被调用**；
#   关着的时候既有代码一步都不经过这里，黄金样例与旧测试因此零改动。
# ==========================================================================================

const 阶段_我方开始 := "PLAYER_START"
const 阶段_我方主 := "PLAYER_MAIN"
const 阶段_敌方 := "ENEMY_PHASE"

## 这台单位是不是单机牌组单位（初始化过战意字段）
static func 是单机牌组单位(u: Variant) -> bool:
	return u is Dictionary and u.get("战意") != null

static func 战意(u: Variant) -> float:
	return J.num0(u.get("战意")) if u is Dictionary else 0.0

static func 战意Of(u: Variant) -> float:
	return 战意(u)

## 直接设战意（带上限 / 最低 0；不是单机牌组单位就什么都不做）
static func 设战意(u: Variant, 值: Variant) -> float:
	if not 是单机牌组单位(u):
		return 0.0
	var 上 := J.num0(u.get("战意上限"))
	if 上 <= 0.0:
		上 = Params.战意上限()
	u["战意"] = maxf(0.0, minf(上, J.num0(值)))
	return u["战意"]

## 加 / 减战意（带上限，最低 0）。不是单机牌组单位 = 什么都不做（旧路径零影响）。
static func 加战意(u: Variant, 值: Variant, _ctx: Variant = null, _原因: String = "") -> float:
	if not 是单机牌组单位(u):
		return 0.0
	var 上 := J.num0(u.get("战意上限"))
	if 上 <= 0.0:
		上 = Params.战意上限()
	var 前 := J.num0(u.get("战意"))
	var 后 := maxf(0.0, minf(上, 前 + J.num0(值)))
	u["战意"] = 后
	return 后

## 单机牌组单位找目标：键 / 位号 / 位名（"前1"）都认
static func 找单位(ctx: Dictionary, 标识: Variant, 方: String) -> Variant:
	if ctx == null or 标识 == null:
		return null
	var 们 := Units.sideUnits(方, ctx)
	if 标识 is float or 标识 is int:
		for u in 们:
			if u != null and int(u.slot) == int(标识):
				return u
		return null
	if 标识 is Dictionary:
		return 标识 if J.inc(们, 标识) else null
	var 文 := str(标识)
	for u in 们:
		if u == null:
			continue
		if str(u.get("key", "")) == 文 or str(u.get("tplKey", "")) == 文:
			return u
	for u in 们:
		if u != null and Fm.位名(float(u.slot)) == 文:
			return u
	return null

static func _按位单位(们: Array, 位号: int) -> Variant:
	for u in 们:
		if u != null and int(u.slot) == 位号:
			return u
	return null

static func _卡匹配(c: Variant, 标识: Variant) -> bool:
	if not (c is Dictionary) or 标识 == null:
		return false
	if 标识 is Dictionary:
		return is_same(c, 标识)
	var 文 := str(标识)
	return (c.get("_实例号") != null and str(c._实例号) == 文) \
		or str(c.get("id", "")) == 文 or str(c.get("名", "")) == 文

static func _找手牌卡(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("专属手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		return null   # 数字参数一律当武器下标，不当手牌下标（避免歧义）
	for c in u.专属手牌:
		if _卡匹配(c, 标识):
			return c
	return null

static func _找公有手牌卡(ctx: Dictionary, 标识: Variant) -> Variant:
	if not (ctx.get("公有手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		return null
	for c in ctx.公有手牌:
		if _卡匹配(c, 标识):
			return c
	return null

static func _找衍生卡(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("衍生手牌") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		var i := int(标识)
		return u.衍生手牌[i] if (i >= 0 and i < u.衍生手牌.size()) else null
	for c in u.衍生手牌:
		if _卡匹配(c, 标识):
			return c
	return null

## 武器条目：下标 / 名字 / 条目字典都认
static func _找武器(u: Dictionary, 标识: Variant) -> Variant:
	if not (u.get("weapons") is Array) or 标识 == null:
		return null
	if 标识 is float or 标识 is int:
		var i := int(标识)
		return u.weapons[i] if (i >= 0 and i < u.weapons.size()) else null
	if 标识 is Dictionary:
		if 标识.get("t") is Dictionary:
			return 标识 if J.inc(u.weapons, 标识) else null
		var 名 := str(标识.get("name", 标识.get("武器名", "")))
		标识 = 名
	var 文 := str(标识)
	for e in u.weapons:
		if e is Dictionary and e.get("t") is Dictionary and str(e.t.get("name", "")) == 文:
			return e
	return null

static func _战意费用(d: Variant) -> float:
	if not (d is Dictionary):
		return 0.0
	if d.get("战意") != null:
		return maxf(0.0, J.num0(d.get("战意")))
	return maxf(0.0, J.num0(d.get("耗气")))

## ★ DECK-3：`_战意费用` 的**公开**读法（门面 / 表现层要显示「这张牌要多少战意」时用同一处真源）。
static func 战意费用(d: Variant) -> float:
	return _战意费用(d)

## ★ DECK-3：`_身份对口` 的**公开**读法（下排公有牌「归属对不对口」的置灰判据）。
static func 身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	return _身份对口(u, card, ctx)

## ★ DECK-3：`_是衍生卡` 的**公开**读法（下排公有牌里「这是不是衍生攻击卡」）。
static func 是衍生攻击卡(c: Variant) -> bool:
	return _是衍生卡(c)

static func _不销毁主武器(w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	return J.truthy(w.get("不被销毁")) or J.truthy(w.get("不销毁其他武器")) or str(w.get("卡类", "")) == "衍生攻击卡"

## 这张牌算不算【衍生攻击卡】（卡类 / 衍生标记 / 秘银 TDD-1 三种认法）
static func _是衍生卡(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return str(c.get("卡类", "")) == "衍生攻击卡" or J.truthy(c.get("衍生")) or str(c.get("id", "")) == "TDD-1"

## 目标没传就自动挑一个：打人 → 血最低的活敌；修理 → 血比最低的活队友
static func _自动目标(ctx: Dictionary, u: Dictionary, 打人: bool) -> Variant:
	if 打人:
		var 敌 := Units.livingOf("enemy", ctx)
		if 敌.is_empty():
			return null
		var 排 := 敌.duplicate()
		J.sort(排, func(a, b):
			var d := float(a.hp) - float(b.hp)
			return d if d != 0.0 else float(a.slot) - float(b.slot))
		return 排[0]
	var 友 := Units.livingOf("ally", ctx)
	if 友.is_empty():
		return null
	var 排2 := 友.duplicate()
	J.sort(排2, func(a, b):
		var ra := float(a.hp) / maxf(1.0, float(a.maxHp))
		var rb := float(b.hp) / maxf(1.0, float(b.maxHp))
		var d := ra - rb
		return d if d != 0.0 else float(a.slot) - float(b.slot))
	return 排2[0]

# ======================== 敌方意图预告（DECK-2） ========================
## 纯读：按敌方格位 0..7 顺序，对每台存活敌机用影子判断算一次行动。
## 一次 `ctx.rng` 都不抽、一个状态都不改（`Calc.expectedDamage` 走预览口径）。
## 每条同时给出两套叫法：
##   · 与 JS 参考版同名：单位 / 单位位 / 名称 / 武器 / 目标 / 目标位 / 目标名 / 期望 / 被挡 / 命中修正 /
##     落点们 / 形状 / 大招 / 大技能 / Boss / Boss阶段 / 蓄力；
##   · 本任务单的字段：武器名 / 预计伤害 / 是大招 / 范围类型。
## **绝不输出任何压制射击标记**（作者 2026-10-17 拍板彻底删除）。
static func 算意图(ctx: Dictionary) -> Array:
	var 出 := []
	if ctx == null:
		return 出
	var 敌们 := Units.livingOf("enemy", ctx)
	J.sort(敌们, func(a, b): return float(a.slot) - float(b.slot))
	for e in 敌们:
		if e == null:
			continue
		var 动作 = Boss.bossAction(e, ctx)
		var bp = Boss.Boss参数(e)
		var 条 := {
			"单位": e.key, "单位位": e.slot, "名称": e.name, "键": e.key, "位": e.slot, "位名": Fm.位名(float(e.slot)),
			"动作类型": "无", "武器": null, "武器名": null, "目标": null, "目标位": null, "目标位名": "",
			"目标名": null, "期望": 0.0, "预计伤害": 0.0, "被挡": false, "命中修正": 0.0,
			"落点们": [], "落点": [], "形状": null, "大招": false, "是大招": false, "范围类型": null,
			"大技能": false, "是大技能": false, "Boss": bp != null, "Boss阶段": null, "蓄力": false,
		}
		var w = 动作.get("weapon") if 动作 is Dictionary else null
		var t = 动作.get("target") if 动作 is Dictionary else null
		if bp != null:
			条["Boss阶段"] = bp.get("第几阶段")
		if w is Dictionary:
			var 期望 := J.round(J.num0(动作.get("expected")))
			条["动作类型"] = "攻击"
			条["武器"] = str(w.get("name", ""))
			条["武器名"] = str(w.get("name", ""))
			条["期望"] = 期望
			条["预计伤害"] = 期望
			条["被挡"] = J.truthy(动作.get("被挡"))
			条["命中修正"] = -20.0 if J.truthy(动作.get("被挡")) else 0.0
			条["大招"] = Ai.isUltimate(w)
			条["是大招"] = 条.大招
			条["范围类型"] = str(Reach.rangeKindOf(w))
			条["大技能"] = J.truthy(动作.get("大技能"))
			条["是大技能"] = 条.大技能
			var 区 := Reach.isAreaKind(Reach.rangeKindOf(w))
			条["形状"] = (str(w.get("area", "row")) if 区 else "单格")
		if t is Dictionary:
			条["目标"] = t.key
			条["目标位"] = t.slot
			条["目标位名"] = Fm.位名(float(t.slot))
			条["目标名"] = t.name
		# 这一发会打到哪几个位（范围武器用落点；单体只有一个位）
		var 落点们 := []
		if w is Dictionary:
			if Reach.isAreaKind(Reach.rangeKindOf(w)):
				var 命中 = 动作.get("hit") if 动作 is Dictionary else null
				if 命中 is Array and not (命中 as Array).is_empty():
					for x in 命中:
						if x is Dictionary:
							落点们.append(x.slot)
				else:
					var 落位 = 动作.get("slot") if 动作 is Dictionary else null
					if 落位 == null and t is Dictionary:
						落位 = t.slot
					if 落位 != null:
						落点们 = Reach.areaSlots(w, Fm.rowOfSlot(float(落位)), Fm.colOfSlot(float(落位)))
			elif t is Dictionary:
				落点们 = [t.slot]
		落点们 = J.sort_num(J.uniq(落点们))
		条["落点们"] = 落点们
		条["落点"] = 落点们
		if 动作 == null and bp != null:
			条["蓄力"] = true
		出.append(条)
	return 出

## 另一种取法：按单位键索引的字典（`算意图` 本身返回的是按格位 0..7 排好的数组）
static func 算意图表(ctx: Dictionary) -> Dictionary:
	var 表 := {}
	for 条 in 算意图(ctx):
		表[str(条.get("单位", ""))] = 条
	return 表

## 算完挂进 ctx（数组 + 两张按单位键 / 格位索引的表，表现层三种取法都能用）
static func 刷新敌方意图(ctx: Dictionary) -> Array:
	var 意图 := 算意图(ctx)
	if ctx != null:
		ctx["敌方意图"] = 意图
		var 表 := {}
		var 位表 := {}
		for 条 in 意图:
			表[str(条.get("单位", ""))] = 条
			位表[int(条.get("单位位", 0))] = 条
		ctx["敌方意图表"] = 表
		ctx["敌方意图位"] = 位表
	return 意图

# ======================== 阶段流转（DECK-1） ========================
## 我方阶段开始：回合 +1、全体 +5 战意、主武器回手、双排各抽 1 张、派发本回合衍生卡、算意图。
static func 开始我方阶段(ctx: Dictionary) -> void:
	if ctx == null or not Params.单机牌组_开(ctx):
		return
	ctx["阶段"] = 阶段_我方开始
	ctx["turn"] = float(ctx.get("turn", 0.0)) + 1.0
	# ★ DECK-4：ATX v0.2 的一次性光环 / 标记每回合清一次，并按「打空」的差分记下上回合打空了多少段。
	if Params.ATXv02开(ctx):
		FacAtx.本回合重置(ctx)
	var 加 := Params.回合初战意()
	for u in Units.livingOf("ally", ctx):
		# 兜底：ctx 是手工搭出来的（没走 Setup.开局）时，第一次进阶段也把单位补齐
		if not 是单机牌组单位(u):
			Setup.初始化单机牌组单位(u, ctx)
		if J.num0(u.get("战意上限")) <= 0.0:
			u["战意上限"] = Params.战意上限()
		加战意(u, 加, ctx, "回合初")
		u["主武器已销毁"] = false
		u["连续攻击已用"] = false
		u["铁壁护卫中"] = false
		u["机动脱离中"] = false
		Setup.抽专属牌(u, int(Params.专属每回合抽()))
		Setup.派发衍生卡(u, ctx)
	Setup.抽公有牌(ctx, int(Params.公有每回合抽()))
	ctx["阶段"] = 阶段_我方主
	刷新敌方意图(ctx)
	pushLog(ctx, "—— 第 %s 回合 · 我方阶段 ——" % J.s(ctx.turn),
		{"类型": "回合", "阶段": 阶段_我方主, "战意加": 加})

# ======================== 主武器卡 ========================
## 打出一张【主武器卡】。`weapon_or_card_id` 可以是 u.weapons 的下标 / 武器名 / 专属手牌里的牌。
static func 打出主武器卡(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null or not Params.单机牌组_开(ctx):
		return {"成功": false, "原因": "单机牌组未开启"}
	var u = 找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	if J.truthy(u.get("主武器已销毁")):
		return {"成功": false, "原因": "本回合主武器卡已销毁（下回合初回手）"}
	# ① 专属手牌里的牌（大招牌 / 角色牌）
	var 手牌 = _找手牌卡(u, weapon_or_card_id)
	if 手牌 is Dictionary:
		if str(手牌.get("卡类", "")) == "衍生攻击卡":
			return {"成功": false, "原因": "这是衍生攻击卡（请用打出衍生攻击卡）"}
		return _打出手牌主武器(ctx, u, 手牌, target_id)
	# ② u.weapons 里的常规武器卡（没指定就按可用顺序挑第一张）
	if weapon_or_card_id == null:
		var 候选 := Calc.usableWeapons(u, ctx).filter(func(e): return e is Dictionary and e.get("t") is Dictionary and Calc.weaponPlayable(e.t))
		if not 候选.is_empty():
			weapon_or_card_id = 候选[0].t.get("name")
	var entry = _找武器(u, weapon_or_card_id)
	if not (entry is Dictionary) or not (entry.get("t") is Dictionary):
		return {"成功": false, "原因": "没有这张主武器卡"}
	var w: Dictionary = entry.t
	if not Calc.weaponPlayable(w):
		return {"成功": false, "原因": "这张武器不能主动打出"}
	if entry.get("uses") != null and float(entry.uses) <= 0.0:
		return {"成功": false, "原因": "使用次数已用尽"}
	if J.num0(entry.get("cd")) > 0.0:
		return {"成功": false, "原因": "冷却中"}
	if float(u.get("lv", 1.0)) < J.num(Params.残月武器运行期解锁(w)):
		return {"成功": false, "原因": "等级不够"}
	if J.num0(entry.get("readyTurn")) > float(ctx.get("turn", 1.0)):
		return {"成功": false, "原因": "还没到解锁回合"}
	var 费 := _战意费用(w)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	var 名 := str(w.get("name", ""))
	if 名 == "铁壁护卫" or J.truthy(w.get("单机牌组_铁壁")):
		结果 = _执行铁壁护卫(ctx, u, entry)
	elif Reach.isHealKind(Reach.rangeKindOf(w)):
		结果 = _执行修理卡(ctx, u, entry, target_id)
	elif Reach.isSupportKind(Reach.rangeKindOf(w)):
		结果 = _执行支援卡(ctx, u, entry, target_id)
	else:
		结果 = _执行武器攻击(ctx, u, entry, target_id)
	# 尖兵【机动脱离】：本回合打出主武器卡后自身闪避 +15%
	if Units.unit_class(u, ctx) == "尖兵":
		换同源增益(u, "机动脱离", {"eva": 15.0, "剩余": 1.0})
		u["机动脱离中"] = ctx.turn
	# 主武器卡互毁（带「不被销毁」标签的除外）
	if not _不销毁主武器(w):
		u["主武器已销毁"] = true
	# 近卫【连续攻击】：击破后主武器卡全部回手（每回合 1 次）
	if J.num0(结果.get("击破")) > 0.0 and Units.unit_class(u, ctx) == "近卫" and not J.truthy(u.get("连续攻击已用")):
		u["连续攻击已用"] = true
		u["主武器已销毁"] = false
		pushLog(ctx, "〔近卫·连续攻击〕【%s】主武器卡全部回手！" % str(w.get("name", "")),
			J.merged({"类型": "连续攻击", "单位": u.key, "武器": w.get("name")}, 谁(u)))
	pushLog(ctx, "〔主武器卡〕%s 打出【%s】（战意 -%s，剩 %s）" % [u.name, str(w.get("name", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "主武器卡", "单位": u.key, "武器": w.get("name"), "战意": u.get("战意"),
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "武器": str(w.get("name", "")), "战意": J.num0(u.get("战意")),
		"目标": 目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 别名（评审稿里的英文写法）
static func play_unit_weapon_card(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出主武器卡(ctx, unit_id, weapon_or_card_id, target_id)

static func 目标名Of(结果: Variant) -> Variant:
	return 结果.get("目标") if 结果 is Dictionary else null

static func _执行武器攻击(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 敌 = 找单位(ctx, target_id, "enemy")
	if not (敌 is Dictionary):
		敌 = _自动目标(ctx, u, true)
	if not (敌 is Dictionary):
		return {"击破": 0.0}
	var action := {"kind": "attack", "weapon": w, "target": 敌, "entry": entry}
	if Reach.isAreaKind(Reach.rangeKindOf(w)):
		var 落点: Array = Reach.areaSlots(w, Fm.rowOfSlot(float(敌.slot)), Fm.colOfSlot(float(敌.slot)))
		var 命中 := Units.livingOf("enemy", ctx).filter(func(t): return J.inc(落点, t.slot))
		action["hit"] = 命中
	var r = Flow.resolveAction(u, action, ctx)
	if r is Dictionary:
		r["目标"] = 敌.key
		return r
	return {"击破": 0.0, "目标": 敌.key}

static func _执行修理卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 目标 = 找单位(ctx, target_id, "ally")
	if not (目标 is Dictionary):
		目标 = _自动目标(ctx, u, false)
	if not (目标 is Dictionary):
		return {"击破": 0.0}
	var r = Flow.resolveAction(u, {"kind": "heal", "weapon": w, "target": 目标, "entry": entry}, ctx)
	# 【紧急修理】：回复大量 HP 并清除负面状态
	目标["debuffs"] = []
	目标["armorCut"] = 0.0
	return {"击破": 0.0, "回复": r.get("回复", 0.0) if r is Dictionary else 0.0, "目标": 目标.key}

## 支援类主武器卡（buff / grant）：走现成的 Flow.resolveAction 支援分支
static func _执行支援卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	var w: Dictionary = entry.t
	var 目标 = 找单位(ctx, target_id, "ally")
	if J.truthy(w.get("grant")):
		if not (目标 is Dictionary):
			目标 = Ai.grantTargetOf(u, ctx)
		if not (目标 is Dictionary):
			return {"击破": 0.0}
		return Flow.resolveAction(u, {"kind": "grant", "weapon": w, "target": 目标, "entry": entry}, ctx)
	var 们 := Units.livingOf("ally", ctx)
	if 目标 is Dictionary:
		们 = [目标]
	else:
		们 = 们.filter(func(x): return not is_same(x, u))
	if 们.is_empty():
		们 = [u]
	var r = Flow.resolveAction(u, {"kind": "buff", "weapon": w, "targets": 们, "entry": entry}, ctx)
	return r if r is Dictionary else {"击破": 0.0}

static func _执行铁壁护卫(ctx: Dictionary, u: Dictionary, entry: Dictionary) -> Dictionary:
	var 前 := float(u.hp)
	var 加 := J.round(float(u.maxHp) * 0.05)
	u["hp"] = minf(float(u.maxHp), float(u.hp) + 加)
	换同源增益(u, "铁壁护卫", {"def": 50.0, "受伤Mul": -0.30, "剩余": 1.0})
	u["铁壁护卫中"] = ctx.turn
	Calc.spendWeapon(u, entry)
	pushLog(ctx, "〔铁壁护卫〕%s 架起铁壁：防御 +50、受到伤害 -30%%、回复 %s（替同列后排挡枪）" % [u.name, J.s(J.round(float(u.hp) - 前))],
		J.merged({"类型": "铁壁护卫", "单位": u.key, "回复": J.round(float(u.hp) - 前)}, 谁(u)))
	return {"击破": 0.0}

## 这张牌算不算【合体技】（合体技标记 / `种类 == 合体技` / `占行动` ≥ 2 三种认法）
static func 是合体技牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if J.truthy(card.get("合体技")) or str(card.get("种类", "")) == "合体技":
		return true
	var 占 = card.get("占行动")
	return 占 is Array and (占 as Array).size() >= 2

## 合体技的**全部参与者键**（`占行动` 优先，其次 `角色们`，最后 `角色`）
static func 合体技参与者(card: Variant) -> Array:
	var 出: Array = []
	if not (card is Dictionary):
		return 出
	for k in J.or_(card.get("占行动"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	for k in J.or_(card.get("角色们"), []):
		if not J.inc(出, str(k)):
			出.append(str(k))
	var 单 := str(card.get("角色", ""))
	if 单 != "" and not J.inc(出, 单):
		出.append(单)
	return 出

## ★ DECK-4：ATX「幸运连号」的降费 —— 只对 **ATX 角色牌**（`归属 == ATX` 且 `层级 == 角色`）生效，吃一次就清。
## 开关关着 / 不是 ATX 牌 = 一分钱都不减（老路径逐字不变）。
static func _ATX实际战意(ctx: Dictionary, card: Dictionary) -> float:
	var 费 := _战意费用(card)
	if not Params.ATXv02开(ctx) or str(card.get("归属", "")) != "ATX" or str(card.get("层级", "")) != "角色":
		return 费
	var 降 := int(ctx.get("下张ATX角色牌降费", 0))
	if 降 <= 0:
		return 费
	ctx["下张ATX角色牌降费"] = 0
	pushLog(ctx, "〔幸运连号〕【%s】费用 −%d（%s → %s）" % [str(card.get("名", "")), 降, J.s(费),
		J.s(maxf(0.0, 费 - float(降)))],
		{"类型": "降费", "势力": "ATX", "卡牌ID": card.get("id"), "降费": 降, "回合": ctx.turn})
	return maxf(0.0, 费 - float(降))

static func _打出手牌主武器(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	# ★ DECK-4：合体技（如 ATX【轮盘双响】/ 秘银【乌鲁兹·三角】）走单独的一条路：
	#   要求**全部参与者存活且本回合都还没销毁主武器卡**；打出后扣发起者的战意，
	#   并把**所有参与者**的 `主武器已销毁` 置为 true（作者 2026-10-17 拍板）。
	if 是合体技牌(card):
		return _打出手牌合体技(ctx, u, card, target_id)
	var 费 := _ATX实际战意(ctx, card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	if card.get("武器") is Dictionary:
		结果 = _执行武器攻击(ctx, u, {"t": card.武器, "cd": 0.0, "uses": null}, target_id)
	else:
		CardEffects.execute(ctx, card)
	if Units.unit_class(u, ctx) == "尖兵":
		换同源增益(u, "机动脱离", {"eva": 15.0, "剩余": 1.0})
		u["机动脱离中"] = ctx.turn
	u["主武器已销毁"] = true
	if J.num0(结果.get("击破")) > 0.0 and Units.unit_class(u, ctx) == "近卫" and not J.truthy(u.get("连续攻击已用")):
		u["连续攻击已用"] = true
		u["主武器已销毁"] = false
		pushLog(ctx, "〔近卫·连续攻击〕【%s】主武器卡全部回手！" % str(card.get("名", "")),
			J.merged({"类型": "连续攻击", "单位": u.key, "武器": card.get("名")}, 谁(u)))
	# 从专属手牌 → 专属弃牌堆
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	u["专属弃牌堆"].append(card)
	pushLog(ctx, "〔主武器卡〕%s 打出【%s】（战意 -%s，剩 %s）" % [u.name, str(card.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "主武器卡", "单位": u.key, "武器": card.get("名"), "卡牌ID": card.get("id"),
			"战意": u.get("战意"), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "武器": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": 目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## ★ DECK-4：合体技（`占行动` ≥ 2 人 / `合体技 == true`）。
## 规则（作者 2026-10-17 拍板）：
##   · **全部参与者都要在场存活**，且**都没销毁主武器卡**（= 本回合还没行动过）；
##   · 战意只扣**发起者** `u` 的；
##   · 效果照牌面执行；
##   · 打完把**所有参与者**的 `主武器已销毁` 置为 true（各自本回合的行动就此用掉）。
static func _打出手牌合体技(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var 参与者: Array = []
	for k in 合体技参与者(card):
		var v = _找队友(ctx, str(k))
		if v == null:
			return {"成功": false, "原因": "合体技参与者 %s 不在场（要全部存活才打得出来）" % str(k)}
		参与者.append(v)
	if 参与者.is_empty():
		参与者 = [u]
	for v in 参与者:
		if J.truthy(v.get("主武器已销毁")):
			return {"成功": false, "原因": "合体技参与者 %s 本回合主武器卡已销毁（要都没动过才打得出）" % str(v.get("name", ""))}
	var 费 := _ATX实际战意(ctx, card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := {"击破": 0.0}
	CardEffects.execute(ctx, card)
	for v in 参与者:
		v["主武器已销毁"] = true
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	u["专属弃牌堆"].append(card)
	var 名们: Array = 参与者.map(func(v): return str(v.get("name", "")))
	pushLog(ctx, "〔合体技〕%s 打出【%s】（战意 -%s，剩 %s；参与者 %s 的主武器卡本回合全部销毁）" % [
		u.name, str(card.get("名", "")), J.s(费), J.s(u.get("战意")), "、".join(名们)],
		J.merged({"类型": "合体技", "单位": u.key, "卡牌ID": card.get("id"), "卡牌": card.get("名"),
			"战意": u.get("战意"), "参与者": 合体技参与者(card)}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"合体技": true, "参与者": 合体技参与者(card), "目标": 目标名Of(结果),
		"击破": J.num0(结果.get("击破")), "主武器已销毁": true}

# ======================== 衍生攻击卡 ========================
static func 打出衍生攻击卡(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null or not Params.单机牌组_开(ctx):
		return {"成功": false, "原因": "单机牌组未开启"}
	var u = 找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var card = _找衍生卡(u, card_inst_id)
	var 从公有 := false
	if not (card is Dictionary):
		# 下排公有手牌里的衍生攻击卡（如秘银 TDD-1）也认
		var 公牌 = _找公有手牌卡(ctx, card_inst_id) if card_inst_id != null else null
		if 公牌 is Dictionary and _是衍生卡(公牌):
			card = 公牌
			从公有 = true
	if not (card is Dictionary) and card_inst_id == null:
		# 没指定牌：先看这台机的衍生手牌，再看公有手牌里第一张衍生卡
		if not u.衍生手牌.is_empty():
			card = u.衍生手牌[0]
		elif ctx.get("公有手牌") is Array and not ctx.公有手牌.is_empty():
			for c in ctx.公有手牌:
				if _是衍生卡(c):
					card = c
					从公有 = true
					break
	if not (card is Dictionary):
		return {"成功": false, "原因": "手里没有这张衍生攻击卡"}
	var 费 := _战意费用(card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := _执行衍生效果(ctx, u, card, target_id)
	# ★ DECK-4：单机牌组模式下，公有手牌里的秘银衍生牌（TDD-1）打出也**推进秘银连携计数**
	#   （`本回合秘银牌数` +1；TDD-1 再加 `战况计数.打出TDD1` +1）。
	#   断路器 1 不变：它仍然**绝不触发连携**（`连携阈值` 不加、也不进 `触发连携` 计数）。
	#   `单机牌组_开 == false` 的老路径（MITH-1 / MITH-2 的 4 道断路器）一个字节都不受影响。
	if Params.秘银v02开(ctx) and 是秘银计入牌(card):
		ctx["本回合秘银牌数"] = int(ctx.get("本回合秘银牌数", 0)) + 1
		if bool(card.get("是TDD1", false)):
			if not (ctx.get("战况计数") is Dictionary):
				ctx.战况计数 = {}
			ctx["战况计数"]["打出TDD1"] = int(ctx["战况计数"].get("打出TDD1", 0)) + 1
	# 衍生卡打出后直接销毁；**绝不修改主武器已销毁**
	if 从公有:
		ctx["公有手牌"] = ctx.公有手牌.filter(func(c): return not is_same(c, card))
		ctx["公有弃牌堆"].append(card)
	else:
		u["衍生手牌"] = u.衍生手牌.filter(func(c): return not is_same(c, card))
	pushLog(ctx, "〔衍生攻击卡〕%s 打出【%s】（战意 -%s，剩 %s；不影响主武器卡）" % [u.name, str(card.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "衍生攻击卡", "单位": u.key, "卡牌ID": card.get("id"), "卡牌": card.get("名"),
			"战意": u.get("战意")}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": 目标名Of(结果), "击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

static func play_derived_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出衍生攻击卡(ctx, unit_id, card_inst_id, target_id)

static func _衍生假武器(名: String, 威力: float) -> Dictionary:
	return {"name": 名, "fire": "direct", "dmgType": "物理", "stat": "射击", "hit": 100.0, "critMod": 0.0,
		"hits": 1.0, "power": 威力, "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"ignoreDef": false, "special": null, "range": [1.0, 8.0]}

static func _执行衍生效果(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	# 数据驱动的衍生牌（如秘银 TDD-1，带 `效果` 组表）→ 走统一的效果执行器
	if card.get("效果") is Array and not (card.get("效果") as Array).is_empty():
		CardEffects.execute(ctx, card)
		return {"击破": 0.0}
	var 种 := str(card.get("种类", card.get("名", "")))
	if 种 == "应急补丁":
		var 目标 = 找单位(ctx, target_id, "ally")
		if not (目标 is Dictionary):
			目标 = _自动目标(ctx, u, false)
		if not (目标 is Dictionary):
			return {"击破": 0.0}
		var 量 := maxf(300.0, J.round(float(目标.maxHp) * 0.15))
		var 前 := float(目标.hp)
		目标["hp"] = minf(float(目标.maxHp), float(目标.hp) + 量)
		pushLog(ctx, "〔应急补丁〕%s → %s：回复 %s" % [u.name, 目标.name, J.s(J.round(float(目标.hp) - 前))],
			J.merged({"类型": "修理", "单位": u.key, "目标": 目标.key, "回复": J.round(float(目标.hp) - 前)}, 谁(u)))
		return {"击破": 0.0, "目标": 目标.key}
	var w := _衍生假武器(种, maxf(300.0, J.num0(card.get("威力"))))
	if 种 == "战术副武":
		w["power"] = maxf(300.0, J.round(主武器威力(u) * 0.35))
	var 敌 = 找单位(ctx, target_id, "enemy")
	if not (敌 is Dictionary):
		敌 = _自动目标(ctx, u, true)
	if not (敌 is Dictionary):
		return {"击破": 0.0}
	var r = Flow.resolveAction(u, {"kind": "attack", "weapon": w, "target": 敌, "entry": {"t": w, "cd": 0.0, "uses": null}}, ctx)
	if 种 == "战术副武" and float(敌.hp) > 0.0:
		敌["buffs"] = J.or_(敌.get("buffs"), []).filter(func(b): return b.get("src") != "战术副武")
		敌.buffs.append({"src": "战术副武", "hit": -15.0, "剩余": 2.0})
	return {"击破": r.get("击破", 0.0) if r is Dictionary else 0.0, "目标": 敌.key}

# ======================== 精神牌 / 公有牌 ========================
## 打出专属精神牌或下排公有牌。指挥机打公有牌享受 `费用 - 5`（最低 0）。
## 打出精神 / 公有牌**不修改**主武器已销毁；若牌是主武器卡或衍生攻击卡会自动转交对应口子。
static func 打出精神或公有牌(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null or not Params.单机牌组_开(ctx):
		return {"成功": false, "原因": "单机牌组未开启"}
	var u = 找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var card = _找手牌卡(u, card_inst_id)
	var 从公有 := false
	if not (card is Dictionary):
		card = _找公有手牌卡(ctx, card_inst_id)
		从公有 = card is Dictionary
	if not (card is Dictionary) and card_inst_id == null:
		# 没指定牌：先取专属手牌第一张，再取下排公有手牌第一张
		if not u.专属手牌.is_empty():
			card = u.专属手牌[0]
		elif ctx.get("公有手牌") is Array and not ctx.公有手牌.is_empty():
			card = ctx.公有手牌[0]
			从公有 = true
	if not (card is Dictionary):
		return {"成功": false, "原因": "手里没有这张牌"}
	var 类 := str(card.get("卡类", ""))
	if 类 == "主武器卡":
		return 打出主武器卡(ctx, unit_id, card_inst_id, target_id)
	if _是衍生卡(card):
		if 从公有:
			return 打出衍生攻击卡(ctx, unit_id, card.get("id") if card.get("id") != null else card, target_id)
		return _打出专属手牌衍生(ctx, u, card, target_id)
	if 从公有 and not _身份对口(u, card, ctx):
		return {"成功": false, "原因": "这台机体的职业 / 势力与牌面归属不对口"}
	var 费 := _ATX实际战意(ctx, card)
	if 从公有 and Units.unit_class(u, ctx) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	_执行精神效果(ctx, u, card)
	# 离手：专属手牌 → 专属弃牌堆；公有手牌 → 公有弃牌堆
	if 从公有:
		ctx["公有手牌"] = ctx.公有手牌.filter(func(c): return not is_same(c, card))
		ctx["公有弃牌堆"].append(card)
	else:
		u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
		u["专属弃牌堆"].append(card)
	pushLog(ctx, "〔%s〕%s 打出【%s】（战意 -%s，剩 %s）" % ["公有牌" if 从公有 else "专属精神牌", u.name,
		str(card.get("名", "")), J.s(费), J.s(u.get("战意"))],
		J.merged({"类型": "公有牌" if 从公有 else "专属精神牌", "单位": u.key, "卡牌ID": card.get("id"),
			"牌名": card.get("名"), "战意": u.get("战意"), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")), "费用": 费,
		"主武器已销毁": J.truthy(u.get("主武器已销毁"))}

static func play_spirit_or_public_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return 打出精神或公有牌(ctx, unit_id, card_inst_id, target_id)

static func _打出专属手牌衍生(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var 费 := _战意费用(card)
	if J.num0(u.get("战意")) < 费:
		return {"成功": false, "原因": "战意不足"}
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	var 结果 := _执行衍生效果(ctx, u, card, target_id)
	u["专属手牌"] = u.专属手牌.filter(func(c): return not is_same(c, card))
	u["专属弃牌堆"].append(card)
	pushLog(ctx, "〔衍生攻击卡〕%s 打出【%s】（不影响主武器卡）" % [u.name, str(card.get("名", ""))],
		J.merged({"类型": "衍生攻击卡", "单位": u.key, "卡牌": card.get("名")}, 谁(u)))
	刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": 目标名Of(结果), "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

static func _身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	var 层 := str(card.get("层级", ""))
	var 归 := str(card.get("归属", ""))
	if 归 == "" or 层 == "统帅":
		return true
	match 层:
		"职业":
			return Units.unit_class(u, ctx) == 归
		"势力":
			return str(提取单位三层信息(u).势力) == 归
		"角色":
			return str(u.get("key", "")) == 归
	return true

static func _执行精神效果(ctx: Dictionary, u: Dictionary, card: Dictionary) -> void:
	match str(card.get("单机牌组效果", "")):
		"回战意":
			加战意(u, card.get("值", 0.0), ctx, "精神牌")
		"增益":
			换同源增益(u, "卡牌:%s" % str(card.get("id", "")), card.get("增益", {}))
		_:
			CardEffects.execute(ctx, card)

# ======================== 结束我方回合 ========================
## 惰性取 AI 选牌器脚本：这里用 `load` 而不是全局类名，是为了避免 btl 与 ai_deck 双向依赖
## （ai_deck.gd 里要静态调 Btl / Ai，反过来 btl 再静态认 AiDeck 会构成循环依赖，GDScript 编译不过）。
static var _AI选牌器缓存: Variant = null

static func _AI选牌器() -> Variant:
	if _AI选牌器缓存 == null:
		_AI选牌器缓存 = load("res://core/battle/ai_deck.gd")
	return _AI选牌器缓存

## Step A 未打过主武器的我方机体由 AI 补打 → Step B 敌方按格位 0..7 行动 → Step C 回合末结算 + 下一回合。
static func 结束我方回合(ctx: Dictionary) -> void:
	if ctx == null or not Params.单机牌组_开(ctx):
		return
	if ctx.get("result") != null:
		return
	if str(ctx.get("阶段", "")) != 阶段_我方主:
		return
	ctx["阶段"] = 阶段_敌方
	# ---- Step A：AI 给没打过主武器的机体补打 1 张主武器卡（不碰精神牌与公有牌）----
	for s in range(int(Fm.SLOTS())):
		if ctx.get("result") != null:
			return
		var u = _按位单位(Units.livingOf("ally", ctx), s)
		if not (u is Dictionary):
			continue
		if J.truthy(u.get("主武器已销毁")):
			continue
		_AI选牌器().auto_play_unit_main_weapon(ctx, u)
	ctx["result"] = Setup.checkResult(ctx)
	if ctx.get("result") != null:
		return
	# ---- Step B：敌方严格按格位 0..7 依次行动 ----
	for s in range(int(Fm.SLOTS())):
		if ctx.get("result") != null:
			break
		var e = _按位单位(Units.livingOf("enemy", ctx), s)
		if not (e is Dictionary):
			continue
		Flow.actOnce(e, ctx)
		Setup.drainAgain(ctx)
		ctx["result"] = Setup.checkResult(ctx)
	if ctx.get("result") != null:
		return
	# ---- Step C：回合末结算；没分出胜负就进下一回合 ----
	Setup.endTurn(ctx)
	var 上限 := J.num0(ctx.get("回合上限"))
	if 上限 == 0.0:
		上限 = float(Db.T.MAX_TURN)
	if float(ctx.turn) >= 上限:
		ctx["result"] = {"结果": "败", "原因": "第 %s 回合结束还没分出胜负（按撤退处理）" % J.s(上限)}
		return
	开始我方阶段(ctx)
