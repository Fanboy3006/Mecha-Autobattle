## 60-战斗-1-方针与记录.js：战斗记录、气势、嘲讽 / 镜甲 / 自爆、敌方词条的回合效果、战术卡牌（牌池 / 发牌 / 打牌）。
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

static func 克隆战术牌(c: Variant) -> Variant:
	if c == null:
		return null
	return J.merged(c, {"剩余次数": J.num(c.限次) if c.get("限次") != null else 1.0, "当前冷却": 0.0, "新触发": false, "触发回合": null})

static func 生成队伍牌池(allies: Variant, 选项: Variant) -> Dictionary:
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
			全部牌池.append(克隆战术牌(found))
	for c in 全表:
		if c == null or 已收.has(c.id):
			continue
		var 匹配: bool = (c.层级 == "职业" and J.inc(职业集, c.归属)) \
			or (c.层级 == "势力" and J.inc(势力集, c.归属)) \
			or (c.层级 == "角色" and J.inc(角色集, c.归属)) \
			or (c.层级 == "统帅" and (选项 == null or 选项.get("含统帅牌") != false))
		if 匹配:
			已收[c.id] = true
			全部牌池.append(克隆战术牌(c))
	if 选项 != null and J.truthy(选项.get("补齐基础激励")) and not 已收.has("C_CMD_1"):
		var 基础激励 = J.find(全表, func(c): return c != null and c.id == "C_CMD_1")
		if 基础激励 != null:
			已收["C_CMD_1"] = true
			全部牌池.push_front(克隆战术牌(基础激励))
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
		初始手牌 = 初始候选.slice(0, int(初始上限)).map(func(c): return 克隆战术牌(c))
	else:
		# 正式规则（已接受差异 D-01，ARGON 2026-10-16）：玩家已选 → 基础激励 → 角色 → 势力 → 职业 → 统帅；
		# 超出上限的初始牌不丢弃，进「候补初始牌」，每回合开始按序补到上限（Flow.候补补位）。
		var 已选 := 已选Ids
		J.sort(初始候选, func(a, b): return float(_装填档(a, 已选)) - float(_装填档(b, 已选)))
		初始手牌 = 初始候选.slice(0, int(初始上限)).map(func(c): return 克隆战术牌(c))
		J.sort(初始手牌, 免费回气先)
		候补初始牌 = 初始候选.slice(int(初始上限)).map(func(c): return 克隆战术牌(c))
	var 待触发牌 := 全部牌池.filter(func(c): return c.get("入牌") == "条件").map(func(c): return 克隆战术牌(c))
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
		card.新触发 = true
		card.触发回合 = ctx.turn
		ctx.战术手牌.append(card)
		补了.append(card)
		pushLog(ctx, "〔发牌〕手牌有空位 → 补入初始牌【%s】" % J.s(card.get("名")), {
			"类型": "发牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
			"触发条件码": "候补补位", "精神标签": card.get("精神标签"), "回合": ctx.turn,
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
		"MITH_MARK":
			if J.num0(计.get("秘银标定")) >= 1:
				return true
			return 攻 != null and 攻.side == "ally" and 提取单位三层信息(攻).势力 == "秘银" and J.truthy(p.get("命中"))
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

static func 气势变动后发牌(ctx: Variant) -> Array:
	if ctx == null or not Params.战术卡牌开(ctx):
		return []
	return 检查条件发牌(ctx, "气势变动", {"回合": ctx.turn if J.truthy(ctx.turn) else 1.0})

static func 检查条件发牌(ctx: Variant, 事件类型: Variant, 载荷: Variant) -> Array:
	if ctx == null or not Params.战术卡牌开(ctx):
		return []
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
		pushLog(ctx, "〔发牌〕满足「%s」→ 获得战术牌【%s】" % [J.s(card.get("触发说明")), J.s(card.get("名"))], {
			"类型": "发牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
			"触发条件码": card.get("触发条件码"), "触发说明": card.get("触发说明"), "精神标签": card.get("精神标签"),
			"回合": ctx.turn if J.truthy(ctx.turn) else 1.0,
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

static func _血比(u: Dictionary) -> float:
	return float(u.hp) / float(u.maxHp)

static func _回血(u: Dictionary, 比: float) -> void:
	u.hp = minf(float(u.maxHp), float(u.hp) + J.round(float(u.maxHp) * 比))

static func 打战术牌(ctx: Variant, cardId: Variant) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "无战斗上下文"}
	if not (ctx.get("战术手牌") is Array):
		ctx.战术手牌 = []
	var card = J.find(ctx.战术手牌, func(c): return c != null and (c.id == cardId or c.get("名") == cardId))
	if card == null:
		return {"成功": false, "原因": "手牌中不存在该战术牌"}
	if card.get("剩余次数") != null and float(card.剩余次数) <= 0:
		return {"成功": false, "原因": "使用次数已用尽"}
	if J.num0(card.get("当前冷却")) > 0:
		return {"成功": false, "原因": "冷却中"}
	var 耗 := J.num0(card.get("耗气"))
	var 回 := J.num0(card.get("回气"))
	var 气势前 := J.num0(ctx.get("气势"))
	if 气势前 < 耗:
		return {"成功": false, "原因": "气势不足"}
	ctx.气势 = maxf(0.0, minf(气势上限(), 气势前 - 耗 + 回))
	var allies := Units.livingOf("ally", ctx)
	var enemies := Units.livingOf("enemy", ctx)
	var src := "卡牌:%s" % card.id
	var 势 := func(u): return 提取单位三层信息(u).势力
	match card.id:
		"C_HEAVY_1":
			for u in allies:
				if Units.unitRow(u) == Fm.ROW_FRONT or Reach.职业是(u, "重装"):
					换同源增益(u, src, {"def": 40.0, "剩余": 1.0})
					加卡牌护盾(u, J.round(float(u.maxHp) * 0.15))
		"C_HEAVY_2":
			var 重装们 := allies.filter(func(u): return Reach.职业是(u, "重装"))
			var 目标们 := 重装们
			if 重装们.is_empty():
				目标们 = []
				if not allies.is_empty():
					var 排 := allies.duplicate()
					J.sort(排, func(a, b): return _血比(a) - _血比(b))
					目标们 = [排[0]]
			for u in 目标们:
				_回血(u, 0.25)
				换同源增益(u, src, {"def": 30.0, "剩余": 2.0})
		"C_GUARD_1":
			for u in allies:
				if Reach.职业是(u, "近卫"):
					换同源增益(u, src, {"dmgMul": 0.35, "hit": 15.0, "剩余": 1.0})
		"C_GUARD_2":
			for u in allies:
				换同源增益(u, src, {"meleeDmgMul": 0.20, "剩余": 1.0})
				if Reach.职业是(u, "近卫"):
					减单位大招冷却(u, 1.0)
		"C_VANG_1":
			for u in allies:
				if Reach.职业是(u, "尖兵"):
					换同源增益(u, src, {"eva": 25.0, "hit": 15.0, "crit": 15.0, "剩余": 1.0})
		"C_VANG_2":
			for u in allies:
				if Reach.职业是(u, "尖兵"):
					换同源增益(u, src, {"crit": 35.0, "dmgMul": 0.20, "剩余": 1.0})
		"C_SNIPE_1":
			for u in allies:
				if Reach.职业是(u, "狙击"):
					换同源增益(u, src, {"hit": 40.0, "crit": 20.0, "dmgMul": 0.20, "剩余": 1.0})
		"C_SNIPE_2":
			var 带标 := enemies.filter(func(e): return Calc.标定经济层数(e) > 0)
			for e in (带标 if not 带标.is_empty() else enemies):
				换同源增益(e, src, {"def": -30.0, "剩余": 2.0})
				卡牌加标定(e, 3.0, card.名, true)
		"C_CMD_1":
			for u in allies:
				换同源增益(u, src, {"hit": 10.0, "剩余": 1.0})
		"C_CMD_2":
			var 排 := enemies.duplicate()
			J.sort(排, func(a, b):
				var d := float(b.hp) - float(a.hp)
				return d if d != 0 else float(a.slot) - float(b.slot))
			var 靶集 := enemies.filter(func(e): return Units.unitRow(e) == Fm.ROW_BACK)
			if not 排.is_empty() and not J.inc(靶集, 排[0]):
				靶集.append(排[0])
			for e in 靶集:
				卡牌加标定(e, 1.0, card.名)
				换同源增益(e, src, {"hit": -15.0, "剩余": 1.0})
		"C_SPEC_1":
			for e in enemies:
				换同源增益(e, "卡牌扰乱", {"hit": -20.0, "turns": 1.0, "剩余": 1.0})
		"C_SPEC_2":
			var 带标 := enemies.filter(func(e): return Calc.标定经济层数(e) > 0)
			for e in (带标 if not 带标.is_empty() else enemies):
				换同源增益(e, "破甲引信", {"def": -25.0, "turns": 2.0, "剩余": 2.0})
		"F_SEED_1":
			for u in allies:
				if 势.call(u) == "卫星国防军" or Units.unitRow(u) == Fm.ROW_FRONT:
					加卡牌护盾(u, J.round(float(u.maxHp) * 0.15))
		"F_SEED_2":
			for u in allies:
				if 势.call(u) == "卫星国防军":
					换同源增益(u, src, {"dmgMul": 0.30, "eva": 20.0, "剩余": 1.0})
					减单位大招冷却(u, 1.0)
		"F_METEOR_1":
			for u in allies:
				if 势.call(u) == "流星小队":
					换同源增益(u, src, {"eva": 25.0, "dmg": 25.0, "剩余": 1.0})
		"F_METEOR_2":
			for u in allies:
				if 势.call(u) == "流星小队":
					换同源增益(u, src, {"crit": 30.0, "dmgMul": 0.30, "剩余": 1.0})
		"F_MOON_1":
			if not allies.is_empty():
				var 排 := allies.duplicate()
				J.sort(排, func(a, b):
					var d := _血比(a) - _血比(b)
					return d if d != 0 else float(a.slot) - float(b.slot))
				_回血(排[0], 0.30)
		"F_MOON_2":
			for u in allies:
				if 势.call(u) == "月球王国":
					换同源增益(u, src, {"dmgMul": 0.25, "def": 20.0, "剩余": 1.0})
		"F_CB_1":
			for u in allies:
				if 势.call(u) == "天人":
					var 状 := Fac.势力状态(u, "天人")
					var 回合 := float(ctx.turn) if J.truthy(ctx.turn) else 1.0
					状.激活 = true
					状.剩余回合 = 2.0
					状.启动回合 = 回合
					状.结束回合 = 回合 + 2.0
					if J.truthy(ctx.get("战况计数")) and _是(u, "CB1"):
						ctx.战况计数.刹那命中或TA = float(ctx.战况计数.刹那命中或TA) + 1.0
					换同源增益(u, src, {"eva": 15.0, "dmgMul": 0.30, "剩余": 2.0})
		"F_CB_2":
			for u in allies:
				if 势.call(u) == "天人":
					加卡牌护盾(u, J.round(float(u.maxHp) * 0.25))
					减单位大招冷却(u, 1.0)
		"F_ATX_1":
			for u in allies:
				if 势.call(u) == "ATX":
					换同源增益(u, src, {"eva": 25.0, "crit": 20.0, "剩余": 1.0})
		"F_ATX_2":
			for u in allies:
				减单位大招冷却(u, 2.0)
				换同源增益(u, src, {"hit": 25.0, "剩余": 1.0})
		"F_MITH_1":
			for u in allies:
				if 势.call(u) == "秘银":
					换同源增益(u, src, {"eva": 25.0, "hit": 15.0, "剩余": 1.0})
		"F_MITH_2":
			for u in allies:
				if 势.call(u) == "秘银":
					换同源增益(u, src, {"dmgMul": 0.25, "剩余": 1.0})
			for e in enemies:
				卡牌加标定(e, 1.0, card.名)
		"U_CB1":
			for u in allies:
				if _是(u, "CB1"):
					减单位大招冷却(u, 99.0, true)
					换同源增益(u, src, {"dmgMul": 0.40, "hit": 25.0, "剩余": 1.0})
		"U_CB2":
			for u in allies:
				if _是(u, "CB2"):
					换同源增益(u, src, {"crit": 40.0, "dmgMul": 0.35, "剩余": 1.0})
		"U_M1":
			for u in allies:
				_回血(u, 0.15)
				换同源增益(u, src, {"hit": 15.0, "剩余": 1.0})
				if _是(u, "M1"):
					减单位大招冷却(u, 2.0)
		"U_A1":
			for u in allies:
				if _是(u, "A1"):
					减单位大招冷却(u, 99.0, true)
					换同源增益(u, src, {"dmgMul": 0.50, "剩余": 1.0})
		"U_S1":
			for u in allies:
				_回血(u, 0.25)
				u.debuffs = []
				u.armorCut = 0.0
				if J.is_arr(u.get("buffs")):
					u.buffs = u.buffs.filter(func(b): return not (b != null and (J.num0(b.get("hit")) < 0 or J.num0(b.get("def")) < 0)))
				换同源增益(u, src, {"dmgMul": 0.25, "剩余": 1.0})
		"U_B1":
			for u in allies:
				if _是(u, "B1"):
					加卡牌护盾(u, J.round(float(u.maxHp) * 0.20))
					换同源增益(u, src, {"dmgMul": 0.25, "剩余": 1.0})
					var 同路敌 = J.find(enemies, func(e): return Fm.colOfSlot(e.slot) == Fm.colOfSlot(u.slot))
					if 同路敌 == null and not enemies.is_empty():
						同路敌 = enemies[0]
					if 同路敌 != null:
						卡牌加标定(同路敌, 2.0, card.名)
		"CMD_ALL_OUT":
			ctx.当前战术 = "总攻"
			for u in allies:
				换同源增益(u, src, {"dmgMul": 0.35, "hit": 15.0, "剩余": 1.0})
				减单位大招冷却(u, 1.0)
		"CMD_COVER":
			ctx.当前战术 = "掩护"
			for u in allies:
				加卡牌护盾(u, J.round(float(u.maxHp) * 0.25))
				u.debuffs = []
				u.armorCut = 0.0
	card.剩余次数 = (J.num(card.剩余次数) if card.get("剩余次数") != null else 1.0) - 1.0
	var 冷 := J.num0(card.get("冷却"))
	card.当前冷却 = 冷 if 冷 != 0 else 1.0
	card.新触发 = false
	if float(card.剩余次数) <= 0:
		ctx.战术手牌 = ctx.战术手牌.filter(func(c): return not is_same(c, card))
	if not (ctx.get("已打出战术牌") is Array):
		ctx.已打出战术牌 = []
	ctx.已打出战术牌.append(card.id)
	var 气势字 := "-%s/+%s" % [J.s(耗), J.s(回)] if 回 > 0 else "-%s" % J.s(耗)
	pushLog(ctx, "〔战术牌〕发动【%s】（气势 %s）：%s" % [J.s(card.get("名")), 气势字, J.s(card.get("效果说明"))], {
		"类型": "战术牌", "卡牌ID": card.id, "牌名": card.get("名"), "层级": card.get("层级"), "归属": card.get("归属"),
		"精神标签": card.get("精神标签"), "耗气": 耗, "回气": 回, "气势前": 气势前, "气势后": ctx.气势,
		"效果说明": card.get("效果说明"), "回合": ctx.turn if J.truthy(ctx.turn) else 1.0,
	})
	检查条件发牌(ctx, "打战术牌", {"cardId": card.id})
	return {"成功": true, "牌": card, "气势": ctx.气势}
