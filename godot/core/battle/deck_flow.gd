## ★ MITH3-2 / MITH3-3：卡牌流转规则 v0.1 的**唯一状态机** + 秘银 v0.3 的连携牌库与 λ 驱动。
# 见 协作/设计/卡牌流转规则 v0.1.md · 协作/设计/秘银势力卡牌设计 v0.3.md
class_name DeckFlow
extends RefCounted

const 精神上限 := 4
const 公有上限 := 6
const 连携等级键 := "连携等级"
const 连携回库键 := "回库"

# ---- 一、初始化与拆分 ----
static func 初始化(ctx: Dictionary) -> void:
	ctx["连携牌库"] = MithrilV03Cards.初始连携牌库() if _有秘银成员(ctx) else []
	ctx["上张打出牌"] = null
	ctx["已放入三级连携牌"] = {}
	ctx["连携牌库曾有三级"] = false
	ctx["连携多抽"] = 0
	ctx["本回合秘银牌"] = 0
	ctx["_v3降费"] = 0
	if not (ctx.get("公有待入库") is Array):
		ctx["公有待入库"] = []
	PublicCooldown.初始化(ctx)
	ctx["v3饱和攻击"] = 0
	ctx["v3秘银减命中"] = 0
	ctx["v3前排减命中"] = 0
	ctx["v3各员开火"] = {"伤害": 0.0, "命中": 0.0}
	ctx["v3副武器加"] = 0
	ctx["v3集中火力"] = 0.0
	ctx["v3战术目标"] = null

static func _有秘银成员(ctx: Dictionary) -> bool:
	for u in ctx.get("allies", []):
		if u is Dictionary and FacMith.是秘银(u):
			return true
	return false

## 把一台机体的牌分进武器栏、副武器栏、大招槽、待入库与专属牌库。
static func 拆分单位牌(u: Dictionary, _ctx: Dictionary) -> void:
	if not (u is Dictionary):
		return
	MithrilV03Cards.挂被动(u)
	u["武器栏"] = []
	u["副武器栏"] = []
	u["大招槽"] = []
	u["待入库"] = []
	u["本回合再动已用"] = false
	u["v3命中加成"] = 0.0
	u["v3伤害加成"] = 0.0
	u["v3暴击加成"] = 0.0
	var 留: Array = []
	for c in J.or_(u.get("专属牌库"), []):
		if not (c is Dictionary):
			continue
		var 类 := str(c.get("卡类", ""))
		if J.truthy(c.get("v01卡")):
			if 类 == "大招槽卡":
				continue
			if 类 == "主武器卡":
				if J.truthy(c.get("λ版")):
					continue
				if c.get("每场次数") != null and c.get("剩余次数") == null:
					c["剩余次数"] = float(J.or_(c.get("每场次数"), 0.0))
				if c.get("当前冷却") == null:
					c["当前冷却"] = 0.0
				u.武器栏.append(c)
				continue
			if 类 == "副武器卡":
				u.副武器栏.append({"卡": c, "本回合可用": 1, "本回合已用": 0, "禁用": false,
					"cd": 0.0, "cd_max": float(J.or_(c.get("冷却"), 0.0))})
				continue
			var 条: Variant = 入库条件Of(c)
			if 条 is Dictionary and str((条 as Dictionary).get("类型", "")) != "开战即入库":
				u.待入库.append(c)
			else:
				留.append(c)
			continue
		if 类 == "大招槽卡":
			var 槽 := MithrilV03Cards._槽(c)
			var 条0: Variant = 入库条件Of(c)
			槽["已解锁"] = (条0 == null)
			槽["解锁说明"] = ""
			if not 槽["已解锁"]:
				槽["解锁说明"] = str((条0 as Dictionary).get("说明", "获取条件未满足")) if 条0 is Dictionary else "获取条件未满足"
			u.大招槽.append(槽)
		elif 类 == "副武器卡":
			u.副武器栏.append({"卡": c, "本回合可用": 1, "本回合已用": 0, "禁用": false,
				"cd": 0.0, "cd_max": float(J.or_(c.get("冷却"), 0.0))})
		elif 类 == "主武器卡":
			if J.truthy(c.get("λ版")):
				continue
			u.武器栏.append(c)
		elif 入库条件Of(c) is Dictionary:
			u.待入库.append(c)
		else:
			留.append(c)
	u["专属牌库"] = 留

## 把带 `入库条件` 的公有牌从 `ctx.公有牌库` 挑进 `ctx.公有待入库`。
static func 初始化公有待入库(ctx: Dictionary) -> void:
	if not (ctx.get("公有牌库") is Array):
		return
	var 留: Array = []
	for c in ctx.公有牌库:
		if c is Dictionary and 入库条件Of(c) is Dictionary:
			ctx.公有待入库.append(c)
		else:
			留.append(c)
	ctx["公有牌库"] = 留

# ---- 二、我方阶段开始 ----
## Step 1 + Step 2：冷却 −1 → 维持与回合初状态结算 → 战意 +5。
static func 阶段初_冷却与维持(ctx: Dictionary) -> void:
	BattleSwap.清回合状态(ctx)
	PublicCooldown.阶段初(ctx)
	for u in Units.livingOf("ally", ctx):
		for 槽 in J.or_(u.get("大招槽"), []):
			if _处理者阶段初(ctx, u, 槽):
				continue
			if float(槽.get("cd", 0.0)) > 0.0:
				槽["cd"] = maxf(0.0, float(槽["cd"]) - 1.0)
			槽["本回合已打"] = false
		for c in J.or_(u.get("武器栏"), []):
			if float(c.get("当前冷却", 0.0)) > 0.0:
				c["当前冷却"] = maxf(0.0, float(c["当前冷却"]) - 1.0)
		λ阶段初(ctx, u)
		Btl.加战意(u, Params.回合初战意(), ctx, "回合初")
		u["本回合再动已用"] = false
		u["连续攻击已用"] = false
		u["v3命中加成"] = 0.0
		u["v3伤害加成"] = 0.0
		u["v3暴击加成"] = 0.0
		for e in J.or_(u.get("副武器栏"), []):
			if e is Dictionary and float(e.get("cd", 0.0)) > 0.0:
				e["cd"] = maxf(0.0, float(e["cd"]) - 1.0)
			e["本回合可用"] = 1 + int(ctx.get("v3副武器加", 0))
			e["本回合已用"] = 0
			e["禁用"] = false
	ctx["v3副武器加"] = 0
	ctx["v3各员开火"] = {"伤害": 0.0, "命中": 0.0}
	ctx["v3集中火力"] = 0.0
	ctx["v3战术目标"] = null
	ctx["上张打出牌"] = null

## Step 3：武器全部恢复 + 副武器次数重置。
static func 阶段初_武器恢复(ctx: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		u["主武器已销毁"] = false
		if J.truthy(λ开启(u)):
			λ回满力场(ctx, u)
		for e in J.or_(u.get("副武器栏"), []):
			e["本回合已用"] = 0
			e["禁用"] = false

## Step 5：检查待入库条件与大招槽亮起条件。
static func 阶段初_检查(ctx: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		检查待入库(ctx, u)
		var 变亮: Array = []
		for 槽 in J.or_(u.get("大招槽"), []):
			if _处理者阶段初(ctx, u, 槽):
				continue
			if not J.truthy(槽.get("已解锁", false)):
				var 条: Variant = 入库条件Of(J.or_(槽.get("卡"), {}))
				if 条 is Dictionary and 条件满足(ctx, u, 条):
					槽["已解锁"] = true
					槽["解锁说明"] = ""
					变亮.append(str(槽.get("卡", {}).get("名", "")))
			var 门 = J.or_(槽.get("卡"), {}).get("实时门槛")
			if 门 is Dictionary:
				var 满足 := 条件满足(ctx, u, 门)
				槽["实时门槛满足"] = 满足
				槽["门槛说明"] = "" if 满足 else str(门.get("说明", "状态门槛未达成"))
			else:
				槽["实时门槛满足"] = true
				槽["门槛说明"] = ""
		if not 变亮.is_empty():
			Btl.pushLog(ctx, "〔大招槽〕%s 解锁：%s" % [u.name, "、".join(变亮)],
				J.merged({"类型": "大招解锁", "单位": u.key, "卡牌": 变亮}, Btl.谁(u)))
	检查公有待入库(ctx)

## 待入库条件首次满足时 `push_front` 到抽牌堆顶（每张只入库一次）。
static func 检查待入库(ctx: Dictionary, u: Dictionary) -> void:
	var 入: Array = []
	for c in J.or_(u.get("待入库"), []):
		if c is Dictionary and 条件满足(ctx, u, 入库条件Of(c)):
			var 库: Array = J.or_(u.get("专属牌库"), [])
			库.push_front(c)
			u["专属牌库"] = 库
			入.append(c)
	if 入.is_empty():
		return
	u["待入库"] = J.or_(u.get("待入库"), []).filter(func(c): return not J.inc(入, c))
	Btl.pushLog(ctx, "〔待入库〕%s 的【%s】条件满足 → 放到抽牌堆顶（下次抽牌必抽到）" % [
		u.name, "】【".join(入.map(func(c): return str(c.get("名", ""))))],
		J.merged({"类型": "待入库", "单位": u.key, "卡牌": 入.map(func(c): return c.get("id")),
			"卡牌名": 入.map(func(c): return c.get("名"))}, Btl.谁(u)))

static func 检查公有待入库(ctx: Dictionary) -> void:
	var 入: Array = []
	for c in J.or_(ctx.get("公有待入库"), []):
		if c is Dictionary and 条件满足(ctx, null, 入库条件Of(c)):
			入.append(c)
	if 入.is_empty():
		return
	ctx["公有待入库"] = J.or_(ctx.get("公有待入库"), []).filter(func(c): return not J.inc(入, c))
	var 库: Array = J.or_(ctx.get("公有牌库"), [])
	for i in range(入.size() - 1, -1, -1):
		库.push_front(入[i])
	ctx["公有牌库"] = 库
	Btl.pushLog(ctx, "〔待入库〕公有牌【%s】条件满足 → 放到公有牌库顶（下次抽牌必抽到）" % [
		"】【".join(入.map(func(c): return str(c.get("名", ""))))],
		{"类型": "待入库", "公有": true, "卡牌": 入.map(func(c): return c.get("id"))})

# ---- 二·补：「实时门槛」刷新（换位后用） ----

## 只重算「大招槽亮起条件」（`实时门槛`）—— 换位后立即调它，把可用性刷到最新。
## 处理者管的槽不重算（它的大招阶段初带副作用）。
static func 刷新实时门槛(ctx: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		for 槽 in J.or_(u.get("大招槽"), []):
			if not (槽 is Dictionary) or str((槽 as Dictionary).get("处理者", "")) != "":
				continue
			var 门 = J.or_((槽 as Dictionary).get("卡"), {}).get("实时门槛")
			if 门 is Dictionary:
				var 满足 := 条件满足(ctx, u, 门)
				(槽 as Dictionary)["实时门槛满足"] = 满足
				(槽 as Dictionary)["门槛说明"] = "" if 满足 else str((门 as Dictionary).get("说明", "状态门槛未达成"))
			else:
				(槽 as Dictionary)["实时门槛满足"] = true
				(槽 as Dictionary)["门槛说明"] = ""

# ---- 三、入库条件 / 亮起条件求值 ----## 兼容 `入库条件` 与 `入牌库条件` 两种字段名。
static func 入库条件Of(c: Variant) -> Variant:
	if not (c is Dictionary):
		return null
	var v: Variant = (c as Dictionary).get("入库条件")
	if v != null:
		return v
	return (c as Dictionary).get("入牌库条件")

static func 条件满足(ctx: Variant, u: Variant, 条: Variant) -> bool:
	if not (条 is Dictionary):
		return true
	var 职 := str((条 as Dictionary).get("职业", ""))
	if 职 != "":
		var 子: Dictionary = (条 as Dictionary).duplicate()
		子.erase("职业")
		if u is Dictionary and Units.unit_class(u, ctx) == 职:
			return 条件满足(ctx, u, 子)
		for a in J.or_(ctx.get("allies") if ctx is Dictionary else [], []):
			if a is Dictionary and float(a.get("hp", 0.0)) > 0.0 and Units.unit_class(a, ctx) == 职 \
				and 条件满足(ctx, a, 子):
				return true
		return false
	var t := str(条.get("类型", ""))
	var 阈 := float(J.or_(条.get("阈值"), 0.0))
	match t:
		"回合至少":
			return float(_回合(ctx)) >= 阈
		"第N回合":
			return float(_回合(ctx)) >= 阈
		"本场赌神开启过":
			var 开过: bool = J.truthy(ctx.get("本场赌神开启过")) if ctx is Dictionary else false
			if u is Dictionary and J.truthy((u as Dictionary).get("本场赌神开启过")):
				开过 = true
			return 开过
		"全部":
			for 子 in J.or_(条.get("们"), []):
				if not 条件满足(ctx, u, 子):
					return false
			return true
		"战意至少":
			return Btl.战意(u) >= 阈
		"生命低于":
			return u is Dictionary and 血比(u) <= 阈 / 100.0
		"力场被破":
			return _力场被破次数(u) >= int(阈 if 阈 > 0.0 else 1.0)
		"本场暴击":
			return _计数(u, "本场暴击") >= int(阈 if 阈 > 0.0 else 1.0)
		"本场击破":
			return _计数(u, "本场击破") >= int(阈 if 阈 > 0.0 else 1.0)
		"友军在场":
			return _队友(ctx, str(条.get("键", ""))) != null
		"友军打出过武器":
			var 友 = _队友(ctx, str(条.get("键", "")))
			return 友 != null and _计数(友, "本场武器牌") > 0
		"打出过秘银大招":
			return int(J.or_(_ctx数(ctx, "v3打出秘银大招"), 0)) > 0
		"打出过 ATX 大招":
			return int(J.or_(_ctx数(ctx, "v3打出ATX大招"), 0)) > 0
		"连携牌库有三级":
			return J.truthy(ctx.get("连携牌库曾有三级")) if ctx is Dictionary else false
		"我方有人低于":
			for a in J.or_(ctx.get("allies") if ctx is Dictionary else [], []):
				if a is Dictionary and 血比(a) <= 阈 / 100.0:
					return true
			return false
		"我方存活有人低于":
			for a in J.or_(ctx.get("allies") if ctx is Dictionary else [], []):
				if a is Dictionary and float(a.get("hp", 0.0)) > 0.0 and 血比(a) <= 阈 / 100.0:
					return true
			return false
		"秘银有人低于":
			for a in J.or_(ctx.get("allies") if ctx is Dictionary else [], []):
				if a is Dictionary and FacMith.是秘银(a) and 血比(a) <= 阈 / 100.0:
					return true
			return false
		"我方有空位":
			return Flow.空位(ctx, "ally") != null
		"场上有敌方陷坑":
			return ctx is Dictionary and not J.or_(ctx.get("敌方陷坑"), []).is_empty()
		"打出者在后排":
			return u is Dictionary and u.get("slot") != null and Fm.rowOfSlot(float(u.slot)) == Fm.ROW_BACK
		"在前排":
			return u is Dictionary and u.get("slot") != null and Fm.rowOfSlot(float(u.slot)) == Fm.ROW_FRONT
		"我方狙击两台":
			var n := 0
			for a in J.or_(ctx.get("allies") if ctx is Dictionary else [], []):
				if a is Dictionary and float(a.get("hp", 0.0)) > 0.0 and Units.unit_class(a, ctx) == "狙击":
					n += 1
			return float(n) >= 阈
		"λ开启":
			return J.truthy(λ开启(u))
		"TRANSAM可入场":
			if not (u is Dictionary):
				return false
			if J.truthy((u as Dictionary).get("本场已开TRANSAM")):
				return false
			return int(J.num0((u as Dictionary).get("transam剩余回合", 0))) <= 0
		"本场有人开过TRANSAM":
			return J.truthy((ctx as Dictionary).get("本场有人开过TRANSAM")) if ctx is Dictionary else false
		"任一":
			for 子 in J.or_(条.get("条件"), []):
				if 条件满足(ctx, u, 子):
					return true
			return false
		"开战即入库", "":
			return true
	var 结 := RuleHooks.首个结论("条件值", [ctx, u, t, 条])
	if bool(结.get("终局", false)):
		return J.truthy(结.get("值"))
	return true


# ---- 四、换装栈与大招槽 ----
## 压一层武器栏（来源唯一，如 "λ驱动" / "脱装" / "METEOR"；永久 = true 的层不可弹出）。
## `原表` 保存压栈前武器卡字典的浅拷贝数组，弹栈时运行期字段原样保留。
static func 压栈武器栏(u: Dictionary, 新表: Array, 来源: String, 永久: bool = false, ctx: Dictionary = {}) -> void:
	if not (u is Dictionary):
		return
	if not (u.get("武器栏栈") is Array):
		u["武器栏栈"] = []
	var 栈: Array = u["武器栏栈"]
	for 层 in 栈:
		if 层 is Dictionary and str((层 as Dictionary).get("来源", "")) == 来源:
			if not ctx.is_empty():
				Btl.pushLog(ctx, "〔换装〕%s 的武器栏已经在「%s」层上，重复压栈被忽略" % [str(u.get("name", "")), 来源],
					J.merged({"类型": "换装", "来源": 来源, "重复": true}, Btl.谁(u)))
			return
	var 原表: Array = []
	if u.get("武器栏") is Array:
		原表 = (u["武器栏"] as Array).duplicate(false)
	栈.append({"来源": 来源, "永久": 永久, "原表": 原表})
	u["武器栏"] = 新表
	u["武器栏切换模式"] = "permanent" if 永久 else "overlay"
	u["武器栏已切换"] = true

## 弹出指定来源层，恢复压栈前的武器卡对象；不在栈顶时将 `原表` 交给上方相邻层。
static func 弹栈武器栏(u: Dictionary, 来源: String) -> bool:
	if not (u is Dictionary) or not (u.get("武器栏栈") is Array):
		return false
	var 栈: Array = u["武器栏栈"]
	var 位 := -1
	for i in 栈.size():
		if 栈[i] is Dictionary and str((栈[i] as Dictionary).get("来源", "")) == 来源:
			位 = i
			break
	if 位 < 0:
		return false
	var 层: Dictionary = 栈[位]
	if J.truthy(层.get("永久")):
		return false
	var 原表: Array = 层.get("原表") if 层.get("原表") is Array else []
	if 位 == 栈.size() - 1:
		u["武器栏"] = 原表
	elif 栈[位 + 1] is Dictionary:
		(栈[位 + 1] as Dictionary)["原表"] = 原表
	栈.remove_at(位)
	u["武器栏已切换"] = not 栈.is_empty()
	同步切换模式镜像(u)
	return true

static func 同步切换模式镜像(u: Dictionary) -> void:
	var 栈: Array = u.get("武器栏栈") if u.get("武器栏栈") is Array else []
	if 栈.is_empty():
		u.erase("武器栏切换模式")
		return
	var 顶: Dictionary = 栈[栈.size() - 1] if 栈[栈.size() - 1] is Dictionary else {}
	u["武器栏切换模式"] = "permanent" if J.truthy(顶.get("永久")) else "overlay"

static func 当前换装来源(u: Dictionary) -> Array:
	var 出: Array = []
	if not (u is Dictionary) or not (u.get("武器栏栈") is Array):
		return 出
	for 层 in u["武器栏栈"]:
		if 层 is Dictionary:
			出.append(str((层 as Dictionary).get("来源", "")))
	return 出

static func 切换武器栏(u: Variant, 新表: Array, 模式: String = "permanent") -> void:
	if not (u is Dictionary):
		return
	压栈武器栏(u as Dictionary, 新表, str(模式), true)

static func 血比(u: Variant) -> float:
	if not (u is Dictionary):
		return 0.0
	var 上 := float(u.get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float(u.get("hp", 0.0)) / 上

static func _回合(ctx: Variant) -> float:
	return float(ctx.get("turn", 1.0)) if ctx is Dictionary else 1.0

static func _队友(ctx: Variant, 键: String) -> Variant:
	if not (ctx is Dictionary) or 键.is_empty():
		return null
	for a in J.or_(ctx.get("allies"), []):
		if a is Dictionary and float(a.get("hp", 0.0)) > 0.0 and str(a.get("key", "")) == 键:
			return a
	return null

static func _计数(u: Variant, 键: String) -> int:
	if not (u is Dictionary):
		return 0
	if not (u.get("v3计数") is Dictionary):
		u["v3计数"] = {}
	return int(u.v3计数.get(键, 0))

static func 计数加(u: Variant, 键: String, 加: int = 1) -> void:
	if not (u is Dictionary):
		return
	if not (u.get("v3计数") is Dictionary):
		u["v3计数"] = {}
	u.v3计数[键] = _计数(u, 键) + 加

static func _ctx数(ctx: Variant, 键: String) -> int:
	if not (ctx is Dictionary):
		return 0
	if not (ctx.get("v3计数") is Dictionary):
		ctx["v3计数"] = {}
	return int(ctx.v3计数.get(键, 0))

static func ctx计数加(ctx: Variant, 键: String, 加: int = 1) -> void:
	if not (ctx is Dictionary):
		return
	if not (ctx.get("v3计数") is Dictionary):
		ctx["v3计数"] = {}
	ctx.v3计数[键] = _ctx数(ctx, 键) + 加

## 大招是否可打：空串表示可打，非空为置灰原因。
static func 大招不可打原因(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> String:
	if not (槽 is Dictionary):
		return "没有这张大招"
	var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
	if 卡.is_empty():
		return "大招槽里没有牌"
	if J.truthy(槽.get("本回合已打", false)):
		return "本回合已使用"
	var 处理者 := RuleHooks.识别大招处理者(ctx, u, 槽)
	var 结 = RuleHooks.按处理者(处理者, "大招不可打原因", [ctx, u, 槽])
	if 结 is Dictionary and bool((结 as Dictionary).get("终局", false)):
		return str((结 as Dictionary).get("原因", ""))
	if float(槽.get("cd", 0.0)) > 0.0:
		return "冷却中（还剩 %d 回合）" % int(槽.get("cd", 0.0))
	if not J.truthy(槽.get("已解锁", false)):
		return "获取条件未满足：%s" % str(槽.get("解锁说明", ""))
	if not J.truthy(槽.get("实时门槛满足", true)):
		return "亮起条件未满足：%s" % str(槽.get("门槛说明", ""))
	var 费 := 大招实际费用(ctx, u, 卡)
	if Btl.战意(u) < 费:
		return "战意不够（要 %d，现在 %d）" % [int(费), int(Btl.战意(u))]
	if J.truthy(卡.get("武器牌")) and J.truthy(u.get("主武器已销毁")):
		return "本回合主武器已销毁（武器型大招一起灰）"
	return ""

static func 大招可用吗(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> bool:
	return 大招不可打原因(ctx, u, 槽) == ""

static func _处理者阶段初(ctx: Dictionary, u: Dictionary, 槽: Variant) -> bool:
	var 处理者 := RuleHooks.识别大招处理者(ctx, u, 槽)
	var 接 = RuleHooks.按处理者(处理者, "大招阶段初", [ctx, u, 槽])
	return 接 is bool and bool(接)

static func 大招实际费用(_ctx: Variant, _u: Variant, 卡: Dictionary) -> float:
	return Btl.战意费用(卡)

static func 找大招槽(u: Dictionary, 标识: Variant) -> Dictionary:
	var 槽们: Array = J.or_(u.get("大招槽"), [])
	if 标识 is int or 标识 is float:
		var i := int(标识)
		return 槽们[i] if (i >= 0 and i < 槽们.size()) else {}
	for 槽 in 槽们:
		if not (槽 is Dictionary):
			continue
		var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
		if str(卡.get("id", "")) == str(标识) or str(卡.get("名", "")) == str(标识):
			return 槽
	return {}

static func 找副武器(u: Dictionary, 标识: Variant) -> Dictionary:
	var 们: Array = J.or_(u.get("副武器栏"), [])
	if 标识 is int or 标识 is float:
		var i := int(标识)
		return 们[i] if (i >= 0 and i < 们.size()) else {}
	for e in 们:
		if not (e is Dictionary):
			continue
		var 卡: Dictionary = e.get("卡") if e.get("卡") is Dictionary else {}
		if str(卡.get("id", "")) == str(标识) or str(卡.get("名", "")) == str(标识):
			return e
	return {}

## 打出大招。`武器牌 == true` 时扣战意并销毁本回合其余主武器。
static func 打出大招(ctx: Dictionary, unit_id: Variant, 标识: Variant = null, target_id: Variant = null) -> Dictionary:
	if ctx == null:
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var 槽 := 找大招槽(u, 标识)
	if 槽.is_empty():
		return {"成功": false, "原因": "大招槽里没有这张牌"}
	var 原因 := 大招不可打原因(ctx, u, 槽)
	if 原因 != "":
		return {"成功": false, "原因": 原因}
	var 卡: Dictionary = 槽.卡
	var 处理者 := RuleHooks.识别大招处理者(ctx, u, 槽)
	var 接 = RuleHooks.按处理者(处理者, "打出大招", [ctx, u, 槽, target_id])
	if 接 is Dictionary:
		return 接
	var 费 := 大招实际费用(ctx, u, 卡)
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	RuleHooks.广播("大招打出前", [ctx, u, 卡, 槽, target_id])
	var 结果 := {"击破": 0.0}
	var 摘要: Array = []
	if 卡.get("武器") is Dictionary and not (卡.get("武器") as Dictionary).is_empty():
		结果 = Btl._执行武器攻击(ctx, u, {"t": 卡.武器, "cd": 0.0, "uses": null}, target_id)
		摘要 = Btl.攻击结果摘要(结果)
	elif 卡.get("效果") is Array:
		摘要 = CardEffects.execute(ctx, 卡)
	RuleHooks.广播("大招打出后", [ctx, u, 卡, 槽])
	槽["本回合已打"] = true
	槽["cd"] = maxf(float(槽.get("cd_max", 0.0)), 0.0)
	if J.truthy(卡.get("武器牌")):
		u["主武器已销毁"] = true
	if J.truthy(卡.get("武器牌")):
		RuleHooks.广播("大招结算后", [ctx, u, 卡])
	u["本场已打大招"] = true
	if str(卡.get("归属", "")) == MithrilV03Cards.势力 \
		or (str(卡.get("角色", "")) == "U7" or J.inc(J.or_(卡.get("角色们"), []), "U7")):
		ctx计数加(ctx, "v3打出秘银大招")
	if J.truthy(卡.get("连携")):
		触发连携(ctx, 卡)
	记上张打出牌(ctx, u, 卡)
	RuleHooks.广播("大招收尾后", [ctx, u, 卡])
	RuleHooks.广播("牌打出后", [ctx, u, 卡, CardPlay.区_大招槽])
	Btl.pushLog(ctx, "〔大招槽〕%s 打出【%s】（战意 -%s，剩 %s；冷却 %d%s）%s" % [
		u.name, str(卡.get("名", "")), J.s(费), J.s(u.get("战意")), int(槽.cd),
		"；主武器本回合销毁" if J.truthy(卡.get("武器牌")) else "；不算武器牌，不销毁武器",
		Btl.效果摘要文(摘要)],
		J.merged({"类型": "大招槽", "单位": u.key, "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"战意": u.get("战意"), "cd": 槽.cd, "is_weapon": J.truthy(卡.get("武器牌")),
			"效果摘要": 摘要,
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "战意": Btl.战意(u),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "效果摘要": 摘要,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "cd": float(槽.cd)}

# ---- 五、副武器栏 ----
static func 副武器不可打原因(ctx: Dictionary, u: Dictionary, 条目: Dictionary) -> String:
	if not (条目 is Dictionary) or not (条目.get("卡") is Dictionary):
		return "没有这张副武器"
	if J.truthy(条目.get("禁用", false)):
		return "本回合不能打副武器（屏息）"
	if float(条目.get("cd", 0.0)) > 0.0:
		return "冷却中（还剩 %d 个我方阶段）" % int(条目.get("cd", 0.0))
	var 结 = RuleHooks.首个结论("副武器门槛", [ctx, u, 条目])
	if 结 is Dictionary and bool(结.get("终局", false)):
		return str(结.get("原因", ""))
	if int(条目.get("本回合已用", 0)) >= int(条目.get("本回合可用", 1)):
		return "本回合副武器次数已用完（%d/%d）" % [int(条目.get("本回合已用", 0)), int(条目.get("本回合可用", 1))]
	return ""

static func 副武器可用次数(u: Dictionary) -> int:
	var 总 := 0
	for e in J.or_(u.get("副武器栏"), []):
		if e is Dictionary and float(e.get("cd", 0.0)) <= 0.0:
			总 += maxi(0, int(e.get("本回合可用", 1)) - int(e.get("本回合已用", 0)))
	return 总

static func 打出副武器(ctx: Dictionary, unit_id: Variant, 标识: Variant = null, target_id: Variant = null) -> Dictionary:
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if float(u.get("hp", 0.0)) <= 0.0:
		return {"成功": false, "原因": "这台机体已经阵亡"}
	var 条目 := 找副武器(u, 标识)
	if 条目.is_empty():
		return {"成功": false, "原因": "副武器栏里没有这张牌"}
	var 原因 := 副武器不可打原因(ctx, u, 条目)
	if 原因 != "":
		return {"成功": false, "原因": 原因}
	var 卡: Dictionary = 条目.卡
	var 特殊 = RuleHooks.首个结论("副武器特殊打出", [ctx, u, 条目, 卡, target_id])
	if 特殊 is Dictionary and bool((特殊 as Dictionary).get("终局", false)):
		var 特殊果 = (特殊 as Dictionary).get("结果")
		return 特殊果 if 特殊果 is Dictionary else {"成功": false, "原因": "打不出来"}
	var w: Dictionary = (卡.get("武器") if 卡.get("武器") is Dictionary else {}).duplicate(true)
	if w.is_empty():
		return {"成功": false, "原因": "这张副武器没有武器数据"}
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	RuleHooks.广播("副武器武器实例", [ctx, u, 卡, target_id, w])
	if J.truthy(u.get("v3援护强化")):
		w["power"] = float(w.get("power", 0.0)) / 0.7
		u.erase("v3援护强化")
	var 援护敌 = Btl._存活敌(ctx, u, target_id)
	var 援 = RuleHooks.首个结论("副武器援护", [ctx, u, 卡, w, 援护敌])
	var 弹种 := str((援 as Dictionary).get("弹种", "")) if 援 is Dictionary else ""
	var 弹种注 := "" if 弹种 == "" else "（%s）" % 弹种
	var 援护吃: bool = bool((援 as Dictionary).get("援护吃", false)) if 援 is Dictionary else false
	if not 援护吃:
		条目["本回合已用"] = int(条目.get("本回合已用", 0)) + 1
	if float(条目.get("cd_max", 0.0)) > 0.0:
		条目["cd"] = float(条目.get("cd_max", 0.0))
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	RuleHooks.广播("副武器攻击前", [ctx, u, 卡, 条目, 援护敌])
	var 结果 := Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, target_id)
	var 摘要 := Btl.攻击结果摘要(结果)
	RuleHooks.广播("副武器攻击后", [ctx, u, 卡, 条目, 援护敌, 结果, 援护吃])
	记上张打出牌(ctx, u, 卡)
	RuleHooks.广播("副武器记账后", [ctx, u, 卡, 条目, 援护敌, 结果, 援护吃])
	RuleHooks.广播("牌打出后", [ctx, u, 卡, CardPlay.区_副武器])
	Btl.pushLog(ctx, "〔副武器〕%s 打出【%s】%s（不销毁主武器，本回合已用 %d/%d）%s" % [
		u.name, str(卡.get("名", "")), 弹种注, int(条目.get("本回合已用", 0)), int(条目.get("本回合可用", 1)),
		Btl.效果摘要文(摘要)],
		J.merged({"类型": "副武器", "单位": u.key, "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"弹种": 弹种, "伤害类型": str(w.get("dmgType", "")), "效果摘要": 摘要,
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "弹种": 弹种,
		"伤害类型": str(w.get("dmgType", "")), "目标": Btl.目标名Of(结果),
		"击破": J.num0(结果.get("击破")), "主武器已销毁": J.truthy(u.get("主武器已销毁")),
		"效果摘要": 摘要, "cd": float(条目.get("cd", 0.0))}


# ---- 六、上张打出牌与连携牌库 ----
static func 是秘银牌(ctx: Variant, u: Variant, card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if str(card.get("种类", "")) == "连携":
		return true
	if J.inc(MithrilV03Cards.连携全覆盖, card.get("id")):
		return true
	if str(card.get("层级", "")) == "职业":
		return false
	if str(card.get("归属", "")) == "统帅" or str(card.get("层级", "")) == "统帅":
		return false
	var 属 := str(card.get("归属", ""))
	if 属 != "" and 属 != MithrilV03Cards.势力:
		return false
	return u is Dictionary and FacMith.是秘银(u)

static func 记上张打出牌(ctx: Dictionary, u: Variant, card: Variant) -> void:
	if not (card is Dictionary):
		return
	var 秘 := 是秘银牌(ctx, u, card)
	ctx["上张打出牌"] = {
		"id": card.get("id"), "名": card.get("名"), "is_mithril_card": 秘,
		"单位": u.get("key") if u is Dictionary else null,
		"回合": ctx.get("turn", 1.0),
	}
	if 秘:
		ctx["本回合秘银牌"] = int(ctx.get("本回合秘银牌", 0)) + 1
	Btl.pushLog(ctx, "〔上一张〕%s（%s）" % [str(card.get("名", "")), "秘银牌 · 连携就绪" if 秘 else "非秘银牌 · 连携断开"],
		{"类型": "上张打出牌", "卡牌ID": card.get("id"), "is_mithril_card": 秘,
			"单位": u.get("key") if u is Dictionary else null})

static func 连携就绪(ctx: Variant, card: Variant) -> bool:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return false
	if not J.truthy(card.get("连携")):
		return false
	var 上 = ctx.get("上张打出牌")
	if not (上 is Dictionary):
		return false
	if str(上.get("id", "")) == str(card.get("id", "")):
		return false
	return J.truthy(上.get("is_mithril_card"))

## 触发连携：先抽后放，三级连携牌每场每种限放入 1 次。
static func 触发连携(ctx: Dictionary, card: Dictionary) -> Dictionary:
	var 记 := {"触发": false, "抽到": [], "放入": null, "原因": ""}
	if not J.truthy(card.get("连携")):
		记["原因"] = "这张牌不带【连携】"
		return 记
	if not 连携就绪(ctx, card):
		记["原因"] = "上一张不是秘银牌（或就是这张牌自己）"
		Btl.pushLog(ctx, "〔连携〕%s：上一张不是秘银牌 → 不触发（连携断开）" % str(card.get("名", "")),
			{"类型": "连携", "卡牌ID": card.get("id"), "触发": false, "原因": 记["原因"]})
		return 记
	记["触发"] = true
	FactionIdentity.连携触发后(ctx)
	var 要多 := 1 + int(ctx.get("连携多抽", 0))
	ctx["连携多抽"] = 0
	var 抽到: Array = []
	var 库: Array = J.or_(ctx.get("连携牌库"), [])
	var 手: Array = ctx.get("公有手牌")
	for _i in range(要多):
		var 抽 := SubDeck.抽一张(库, 手, 公有上限, ctx.get("rng"))
		if 抽.is_empty():
			if 手.size() >= 公有上限:
				记["抽牌作废"] = "公有手牌已满（%d/%d），连携牌留在牌库里" % [公有上限, 公有上限]
			else:
				记["抽牌作废"] = "连携牌库空了"
			break
		抽到.append(抽)
		记["抽到"].append(str(抽.get("名", "")))
		if 连携等级(抽) >= 3:
			ctx["连携牌库曾有三级"] = true
		Btl.pushLog(ctx, "〔连携〕%s → 从连携牌库抽到【%s】（%s 级）" % [
			str(card.get("名", "")), str(抽.get("名", "")), J.s(连携等级(抽))],
			{"类型": "连携抽牌", "来源卡": card.get("id"), "卡牌ID": 抽.get("id"), "卡牌": 抽.get("名"),
				"连携等级": float(连携等级(抽))})
	var 放 := str(J.or_(card.get("连携放入"), ""))
	if 放 != "":
		var 放卡 := MithrilV03Cards.卡(放)
		if 放卡.is_empty():
			记["原因"] = "连携放入的牌不认识：%s" % 放
		else:
			if not (ctx.get("已放入三级连携牌") is Dictionary):
				ctx["已放入三级连携牌"] = {}
			if SubDeck.放入(ctx["连携牌库"], 放卡, ctx.已放入三级连携牌, 放,
					连携等级键, SubDeck.移出下限):
				if 连携等级(放卡) >= 3:
					ctx["连携牌库曾有三级"] = true
				记["放入"] = str(放卡.get("名", ""))
				Btl.pushLog(ctx, "〔连携〕%s → 把【%s】放进连携牌库（本场有效）" % [
					str(card.get("名", "")), str(放卡.get("名", ""))],
					{"类型": "连携放入", "来源卡": card.get("id"), "卡牌ID": 放, "卡牌": 放卡.get("名"), "放入": true})
			else:
				# [断路器1]
				记["原因"] = "三级连携牌【%s】本场已经放入过一次（断路器 1）" % str(放卡.get("名", ""))
				Btl.pushLog(ctx, "〔连携·断路器〕%s 想把【%s】放进连携牌库，但三级牌每场每种只能放 1 次 → 不再放" % [
					str(card.get("名", "")), str(放卡.get("名", ""))],
					{"类型": "连携放入", "卡牌ID": 放, "放入": false, "原因": "三级牌每种每场限 1 次"})
	return 记

static func 连携等级(card: Variant) -> int:
	return SubDeck.等级(card, 连携等级键)

static func _随机下标(ctx: Dictionary, n: int) -> int:
	return SubDeck.随机下标(ctx.get("rng"), n)

static func 连携牌库状态(ctx: Variant) -> Dictionary:
	var 库: Array = J.or_(ctx.get("连携牌库") if ctx is Dictionary else [], [])
	var 计 := SubDeck.各级张数(库, 连携等级键)
	var 名们: Array = 库.map(func(c): return str(c.get("名", "")))
	return {"张数": 库.size(), "一级": int(计["一级"]), "二级": int(计["二级"]), "三级": int(计["三级"]),
		"卡牌": 名们, "就绪": ctx is Dictionary and (ctx.get("上张打出牌") is Dictionary) \
			and J.truthy(ctx.上张打出牌.get("is_mithril_card"))}

## 打出连携牌（0 费、秘银成员可打、不占主武器、一/二级回库、三级移出本场）。
static func 打出连携牌(ctx: Dictionary, unit_id: Variant, 牌标识: Variant = null, target_id: Variant = null) -> Dictionary:
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	if not FacMith.是秘银(u):
		return {"成功": false, "原因": "连携牌只有秘银成员能打"}
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var 卡 = null
	for c in 手:
		if c is Dictionary and str(c.get("种类", "")) == "连携" \
			and (牌标识 == null or str(c.get("id", "")) == str(牌标识) or str(c.get("名", "")) == str(牌标识)
				or (c.get("_实例号") != null and str(c.get("_实例号")) == str(牌标识))):
			卡 = c
			break
	if not (卡 is Dictionary):
		return {"成功": false, "原因": "公有手牌里没有这张连携牌"}
	var 结果 := {"击破": 0.0}
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	var 摘要: Array = []
	if 卡.get("武器") is Dictionary and not (卡.get("武器") as Dictionary).is_empty():
		结果 = Btl._执行武器攻击(ctx, u, {"t": 卡.武器, "cd": 0.0, "uses": null}, target_id)
		摘要 = Btl.攻击结果摘要(结果)
	elif 卡.get("效果") is Array:
		摘要 = CardEffects.execute(ctx, 卡)
	ctx["公有手牌"] = 手.filter(func(c): return not is_same(c, 卡))
	var 级 := 连携等级(卡)
	var 旧移出: Variant = J.or_(ctx.get("移出牌"), [])
	var 移出表: Array = (旧移出 as Array).duplicate() if 旧移出 is Array else []
	if SubDeck.回库或移出(ctx["连携牌库"], 移出表, 卡, 连携等级键, 连携回库键) == "移出":
		ctx["移出牌"] = 移出表
	记上张打出牌(ctx, u, 卡)
	Btl.pushLog(ctx, "〔连携牌〕%s 打出【%s】（0 费；%s）%s" % [u.name, str(卡.get("名", "")),
		"三级 → 移出本场" if 级 >= 3 else "回连携牌库", Btl.效果摘要文(摘要)],
		J.merged({"类型": "连携牌", "单位": u.key, "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"连携等级": float(级), "效果摘要": 摘要,
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "连携等级": 级,
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "效果摘要": 摘要}

# ---- 七、再动与 λ 驱动 ----
# [规范v0.3·断路器3]
static func 再动(ctx: Dictionary, u: Variant, 来源: String = "") -> bool:
	if not (u is Dictionary):
		return false
	var 谁 := str(u.get("name", ""))
	var 尾 := "" if 来源.is_empty() else "（%s）" % 来源
	var 额 := {"类型": "再动", "断路器": true,
		"原因": "每台机体每回合限 1 次（再动 / 连续攻击 / 主武器恢复共用同一把锁）"}
	if not 来源.is_empty():
		额["来源"] = 来源
	if J.truthy(u.get("本回合再动已用")) or J.truthy(u.get("连续攻击已用")):
		Btl.pushLog(ctx, "〔断路器 3〕%s 本回合已经再动 / 连续攻击过一次 → 不再恢复主武器%s" % [谁, 尾],
			J.merged(额, Btl.谁(u)))
		return false
	u["本回合再动已用"] = true
	u["连续攻击已用"] = true
	var 恢复 := 恢复主武器栏(ctx, u)
	var 成额 := {"类型": "再动", "主武器已销毁": J.truthy(u.get("主武器已销毁")),
		"目标": u.get("key"), "目标位": u.get("slot"),
		"恢复": int(恢复.get("恢复", 0)), "出鞘未恢复": 恢复.get("出鞘", [])}
	if not 来源.is_empty():
		成额["来源"] = 来源
	var 尾2 := ""
	var 出鞘们: Array = 恢复.get("出鞘", [])
	if not 出鞘们.is_empty():
		尾2 = "；**出鞘中的 %s 绝不恢复**" % "、".join(出鞘们.map(func(x): return "【%s】" % str(x)))
	Btl.pushLog(ctx, "〔再动〕%s 的主武器全部恢复（本回合可以再打一张；每回合限 1 次）%s%s" % [谁, 尾2, 尾],
		J.merged(成额, Btl.谁(u)))
	return true

## 恢复主武器栏（跳过出鞘中的剑牌）。
static func 恢复主武器栏(_ctx: Dictionary, u: Dictionary) -> Dictionary:
	var 恢复 := 0
	var 出鞘们: Array = []
	for c in J.or_(u.get("武器栏"), []):
		if not (c is Dictionary):
			恢复 += 1
			continue
		var 名 := str(c.get("名", ""))
		if J.truthy(c.get("出鞘")):
			c["已收纳"] = true
			出鞘们.append(名)
			continue
		c["已收纳"] = false
		恢复 += 1
	if 恢复 == 0 and not 出鞘们.is_empty():
		u["本回合已收起"] = 出鞘们
		return {"恢复": 0, "出鞘": 出鞘们}
	u["主武器已销毁"] = false
	u["本回合已收起"] = []
	return {"恢复": 恢复, "出鞘": 出鞘们}

static func λ状态(u: Variant) -> Dictionary:
	if not (u is Dictionary):
		return {"开启": false, "觉醒": false, "开启回合": 0, "力场被破次数": 0, "免除下次维持": false}
	if not (u.get("形态") is Dictionary):
		u["形态"] = {}
	if not (u.形态.get("lambda") is Dictionary):
		u.形态["lambda"] = {"开启": false, "觉醒": false, "开启回合": 0, "力场被破次数": 0, "免除下次维持": false}
	return u.形态["lambda"]

static func λ开启(u: Variant) -> bool:
	var 形: Variant = (u as Dictionary).get("形态") if u is Dictionary else null
	return 形 is Dictionary and 形.get("lambda") is Dictionary and J.truthy(形.lambda.get("开启"))

static func λ觉醒(u: Variant) -> bool:
	var 形: Variant = (u as Dictionary).get("形态") if u is Dictionary else null
	return 形 is Dictionary and 形.get("lambda") is Dictionary and J.truthy(形.lambda.get("觉醒"))

static func _力场被破次数(u: Variant) -> int:
	return int(λ状态(u).get("力场被破次数", 0)) if u is Dictionary else 0

static func 开启λ(ctx: Dictionary, u: Dictionary) -> void:
	var 态 := λ状态(u)
	态["开启"] = true
	态["觉醒"] = J.truthy(态.get("觉醒"))
	态["开启回合"] = int(ctx.get("turn", 1))
	u["护盾"] = 4000.0
	u["shield"] = 4000.0
	u["shieldHp"] = 4000.0
	u["护盾上限"] = 4000.0
	λ换武器(ctx, u)
	Btl.pushLog(ctx, "〔λ 驱动〕%s 开启！获得 λ 力场 4000，武器栏换成 λ 版并新增【隔空 λ 拳】" % u.name,
		J.merged({"类型": "λ驱动", "状态": "开启", "护盾": 4000.0}, Btl.谁(u)))

static func 关闭λ(ctx: Dictionary, u: Dictionary, 原因: String) -> void:
	var 态 := λ状态(u)
	if not J.truthy(态.get("开启")) or J.truthy(态.get("觉醒")):
		return
	态["开启"] = false
	u["护盾"] = 0.0
	u["shieldHp"] = 0.0
	λ还原武器(u)
	for 槽 in J.or_(u.get("大招槽"), []):
		var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
		if str(卡.get("id", "")) == MithrilV03Cards.λ启动ID:
			槽["cd"] = maxf(float(槽.get("cd", 0.0)), 2.0)
	Btl.pushLog(ctx, "〔λ 驱动〕%s 关闭：%s（武器变回普通版、λ 力场消失；启动进 2 回合冷却）" % [u.name, 原因],
		J.merged({"类型": "λ驱动", "状态": "关闭", "原因": 原因}, Btl.谁(u)))

## λ 开启时通过换装栈替换武器栏；若已在栈中则先弹栈再重压，保持单层 `"λ驱动"`。
static func λ换武器(ctx: Dictionary, u: Dictionary) -> void:
	if J.inc(当前换装来源(u), "λ驱动"):
		弹栈武器栏(u, "λ驱动")
	压栈武器栏(u, MithrilV03Cards.λ武器表(u), "λ驱动", false, ctx)

static func λ还原武器(u: Dictionary) -> void:
	弹栈武器栏(u, "λ驱动")

static func λ回满力场(_ctx: Variant, u: Dictionary) -> void:
	if not λ开启(u):
		return
	u["护盾"] = 4000.0
	u["shield"] = 4000.0
	u["shieldHp"] = 4000.0
	u["护盾上限"] = 4000.0

## 每个我方阶段初维持：先扣 10 战意（有免除标记则免扣），扣后 `< 40` 则关闭。
static func λ阶段初(ctx: Dictionary, u: Dictionary) -> void:
	if not λ开启(u):
		return
	var 态 := λ状态(u)
	λ回满力场(ctx, u)
	if J.truthy(态.get("觉醒")):
		return
	if J.truthy(态.get("免除下次维持")):
		态["免除下次维持"] = false
		Btl.pushLog(ctx, "〔λ 驱动〕%s 本回合的维持消耗免除（集中想象 / Uruz-7 冷静点）" % u.name,
			J.merged({"类型": "λ维持", "免除": true, "战意": u.get("战意")}, Btl.谁(u)))
	else:
		u["战意"] = maxf(0.0, Btl.战意(u) - 10.0)
		Btl.pushLog(ctx, "〔λ 驱动〕%s 扣 10 战意维持（剩 %d）" % [u.name, int(u.get("战意"))],
			J.merged({"类型": "λ维持", "免除": false, "战意": u.get("战意")}, Btl.谁(u)))
	if Btl.战意(u) < 40.0:
		关闭λ(ctx, u, "战意不足 40")

## λ 力场被完全击破（护盾从 > 0 打到 0）：累计 2 次触发 λ 觉醒。
static func 记录力场被破(ctx: Dictionary, u: Variant, 之前护盾: float) -> bool:
	if not (u is Dictionary):
		return false
	if not λ开启(u) or 之前护盾 <= 0.0 or float(u.get("shieldHp", 0.0)) > 0.0:
		return false
	var 态 := λ状态(u)
	态["力场被破次数"] = int(态.get("力场被破次数", 0)) + 1
	Btl.pushLog(ctx, "〔λ 力场〕%s 的力场被完全击破（第 %d 次）" % [u.name, int(态.力场被破次数)],
		J.merged({"类型": "λ力场", "被破次数": float(态.力场被破次数)}, Btl.谁(u)))
	if int(态.力场被破次数) >= 2:
		return λ觉醒触发(ctx, u)
	return false

static func λ觉醒触发(ctx: Dictionary, u: Dictionary) -> bool:
	var 态 := λ状态(u)
	if J.truthy(态.get("觉醒")):
		return false
	态["觉醒"] = true
	态["开启"] = true
	λ回满力场(ctx, u)
	λ换武器(ctx, u)
	for 槽 in J.or_(u.get("大招槽"), []):
		var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
		if str(卡.get("id", "")) == MithrilV03Cards.λ极限ID:
			槽["cd"] = 0.0
	Btl.pushLog(ctx, "〔λ 觉醒〕%s 的 λ 力场被击破 2 次 → **λ 驱动永久开启**（不再扣维持、力场每回合回满、极限放出冷却归 0）" % u.name,
		J.merged({"类型": "λ觉醒"}, Btl.谁(u)))
	return true

static func λ文案(u: Variant) -> String:
	if not J.truthy(u.get("形态")):
		return ""
	if λ觉醒(u):
		return "〔λ 觉醒·永久〕力场 %d/4000" % int(u.get("shieldHp", 0.0))
	if λ开启(u):
		return "〔λ 驱动开启 · 力场 %d/4000〕" % int(u.get("shieldHp", 0.0))
	return ""
