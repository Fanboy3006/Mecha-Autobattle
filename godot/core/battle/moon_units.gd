## 职责：月球王国五名成员的卡池（`data/cards/月球王国.json` 的「驾驶员」）、精神牌 / 大招 / 副武器算子与个人被动。
## 约定：主武器的排位限定（[刀枪切换] 等）用换装栈的 `月球站位` 层实现：不满足排位的主武器不在武器栏里。
class_name MoonUnits
extends RefCounted

const 势力 := "月球王国"
const 成员键: Array = ["M1", "M2", "M3", "M4", "M5"]
const 档位 := {"初始": 10, "剧情": 20, "肉鸽三选一": 30}
const 站位层 := "月球站位"
const 打桩大招 := "MOON_M2_ULT"
const 修理装置 := "MOON_M3_SUB1"

# ---- 一、卡表 ----
static func _武(名: String, 参: Dictionary) -> Dictionary:
	var w := {
		"name": 名, "fire": str(J.or_(参.get("类型"), "direct")),
		"power": float(J.or_(参.get("威力"), 1000.0)), "hit": float(J.or_(参.get("命中"), 100.0)),
		"critMod": float(J.or_(参.get("暴击"), 0.0)), "stat": "射击",
		"dmgType": str(J.or_(参.get("伤害"), "物理")), "cd": 0.0, "uses": null,
		"unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null, "area": "single",
		"距离": J.or_(参.get("距离"), [1, 6]),
	}
	if int(J.num0(参.get("段数"))) > 1:
		w["hits"] = float(参.段数)
		w["special"] = "multi"
	if J.truthy(参.get("无视遮挡")):
		w["ignore_block"] = true
	for k in ["命中减大招冷却", "命中后治疗最低", "命中后拘束", "前排增伤", "命中后破防"]:
		if 参.get(k) != null:
			w[k] = 参[k]
	return w

static func _卡(键名: String, 条目: Dictionary) -> Dictionary:
	var 获取 := str(J.or_(条目.get("获取"), "初始"))
	var 卡 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": str(条目.get("卡类", "专属精神牌")), "类型": "战术", "层级": "角色", "种类": "角色",
		"归属": 键名, "角色": 键名, "角色们": [键名], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0,
		"冷却": float(J.or_(条目.get("冷却"), 0.0)), "回库": false, "衍生": false,
		"入库条件": (条目.入库条件 as Dictionary).duplicate(true) if 条目.get("入库条件") is Dictionary else null,
		"获取": 获取, "等级需求": int(档位.get(获取, 10)),
		"效果说明": str(条目.get("效果说明", "")), "效果": [], "目标": str(条目.get("目标", "")),
		"武器牌": J.truthy(条目.get("武器牌")), "连携": false,
		"随侍": J.truthy(条目.get("随侍")), "随侍放入": str(J.or_(条目.get("随侍放入"), "")),
		"角色所属势力": 势力,
	}
	for k in ["排位", "实时门槛", "打出后抽精神", "放入随侍数"]:
		if 条目.get(k) != null:
			卡[k] = (条目[k] as Dictionary).duplicate(true) if 条目[k] is Dictionary else 条目[k]
	if 条目.get("武器参") is Dictionary:
		卡["武器"] = _武(卡.名, 条目.武器参)
	if 条目.get("月武器") is Dictionary:
		卡["月武器"] = _武(卡.名, 条目.月武器)
	if str(条目.get("动作", "")) != "":
		卡["效果"] = MoonDeck.效果组(条目)
	return 卡

static var _表: Dictionary = {}
static var _代: int = -1

## 某人的全卡池（按 JSON 顺序）。
static func 角色牌们(键名: String) -> Array:
	if _代 != Db.代:
		_表 = {}
		var 包: Variant = MoonDeck.卡包().get("驾驶员")
		for k in 成员键:
			var 条们: Variant = (包 as Dictionary).get(k) if 包 is Dictionary else null
			var 出: Array = []
			for 条目 in (条们 as Array) if 条们 is Array else []:
				if 条目 is Dictionary:
					出.append(_卡(k, 条目))
			_表[k] = 出
		_代 = Db.代
	return _表.get(键名, [])

static func 装填单位(u: Dictionary, 等级: int) -> Array:
	var 出: Array = []
	for c in 角色牌们(MoonPhase.键(u)):
		if 等级 >= int((c as Dictionary).get("等级需求", 10)):
			出.append((c as Dictionary).duplicate(true))
	return 出

static func 是月球牌(c: Variant) -> bool:
	return c is Dictionary and str((c as Dictionary).get("角色所属势力", "")) == 势力

# ---- 二、排位：主武器换装层 / 副武器门槛 / 大招亮起条件 ----
static func 排位满足(ctx: Variant, u: Dictionary, 卡: Variant) -> bool:
	match str((卡 as Dictionary).get("排位", "")) if 卡 is Dictionary else "":
		"前排":
			return Fm.是前排有效(u, ctx)
		"后排":
			return Fm.rowOfSlot(float(u.slot)) == Fm.ROW_BACK
	return true

## 撤掉旧的站位层，按当前排位重压一层（全部满足 = 不压层）。
static func 刷新站位武器栏(ctx: Dictionary, u: Dictionary) -> void:
	if not MoonPhase.活着(u) or not MoonPhase.是月球王国(u):
		return
	DeckFlow.弹栈武器栏(u, 站位层)
	var 全: Array = J.or_(u.get("武器栏"), [])
	var 留: Array = 全.filter(func(c): return 排位满足(ctx, u, c))
	if 留.size() != 全.size():
		DeckFlow.压栈武器栏(u, 留, 站位层)

## 收在站位层底下的主武器也要照常走冷却（`DeckFlow` 只减当前武器栏里的）。
static func 阶段初(ctx: Dictionary) -> void:
	for u in Units.livingOf("ally", ctx):
		if not MoonPhase.是月球王国(u):
			continue
		for 层 in J.or_(u.get("武器栏栈"), []):
			if 层 is Dictionary and str(层.get("来源", "")) == 站位层:
				for c in J.or_(层.get("原表"), []):
					if c is Dictionary and not MoonPhase.含(u.武器栏, c) and float(c.get("当前冷却", 0.0)) > 0.0:
						c["当前冷却"] = maxf(0.0, float(c.当前冷却) - 1.0)
		刷新站位武器栏(ctx, u)

## 开局：站位层 + 大招的实时门槛（通用流程只在阶段初 / 换位后才刷）。
static func 装填后(ctx: Dictionary, u: Dictionary) -> void:
	刷新站位武器栏(ctx, u)
	for 槽 in J.or_(u.get("大招槽"), []):
		var 门 = ((槽 as Dictionary).get("卡") as Dictionary).get("实时门槛") if 槽 is Dictionary and 槽.get("卡") is Dictionary else null
		if 门 is Dictionary:
			var 满足 := DeckFlow.条件满足(ctx, u, 门)
			槽["实时门槛满足"] = 满足
			槽["门槛说明"] = "" if 满足 else str(门.get("说明", ""))

static func 副武器门槛(ctx: Dictionary, u: Dictionary, 条目: Dictionary) -> Dictionary:
	var 卡: Dictionary = 条目.get("卡") if 条目.get("卡") is Dictionary else {}
	if not 是月球牌(卡):
		return {"终局": false}
	if not 排位满足(ctx, u, 卡):
		return {"终局": true, "原因": "%s限定（现在不满足）" % str(卡.get("排位", ""))}
	if str(卡.get("id", "")) == "MOON_M5_SUB1":
		var 菲 = MoonPhase.王女(ctx)
		if 菲 == null or is_same(菲, u):
			return {"终局": true, "原因": "Feena 不在场"}
	if Btl.战意(u) < Btl.战意费用(卡):
		return {"终局": true, "原因": "战意不足"}
	return {"终局": false}

## 月球王国的副武器都没有武器数据：扣费、记账、执行算子、写一行战报。
static func 副武器特殊打出(ctx: Dictionary, u: Dictionary, 条目: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not 是月球牌(卡) or 卡.get("武器") is Dictionary:
		return {"终局": false}
	var 费 := Btl.战意费用(卡)
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	条目["本回合已用"] = int(条目.get("本回合已用", 0)) + 1
	if float(条目.get("cd_max", 0.0)) > 0.0:
		条目["cd"] = float(条目.cd_max)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	var 摘要 := CardEffects.execute(ctx, 卡)
	DeckFlow.记上张打出牌(ctx, u, 卡)
	Btl.pushLog(ctx, "〔副武器〕%s 打出【%s】（战意 -%s，不销毁主武器；冷却 %d）%s" % [u.name, str(卡.get("名", "")),
		J.s(费), int(条目.get("cd", 0.0)), Btl.效果摘要文(摘要)],
		J.merged({"类型": "副武器", "单位": u.key, "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"), "效果摘要": 摘要}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"终局": true, "结果": {"成功": true, "卡牌": str(卡.get("名", "")), "击破": 0.0, "效果摘要": 摘要,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "cd": float(条目.get("cd", 0.0))}}

static func 条件值(ctx: Variant, u: Variant, t: String, 条: Variant) -> Dictionary:
	var 阈 := float(J.num0((条 as Dictionary).get("阈值"))) if 条 is Dictionary else 0.0
	match t:
		"月球前排":
			return {"终局": true, "值": u is Dictionary and Fm.是前排有效(u, ctx)}
		"月球后排":
			return {"终局": true, "值": u is Dictionary and Fm.rowOfSlot(float(u.slot)) == Fm.ROW_BACK}
		"月球打桩就绪":
			return {"终局": true, "值": u is Dictionary and Fm.是前排有效(u, ctx) and float(u.get("月球受击", 0.0)) >= 阈}
		"月球打出过大招":
			return {"终局": true, "值": ctx is Dictionary and J.truthy(MoonPhase.状态(ctx).get("打出过大招"))}
		"月球有人血低于":
			for a in Units.livingOf("ally", ctx):
				if MoonPhase.是月球王国(a) and float(a.hp) * 100.0 <= float(a.maxHp) * 阈:
					return {"终局": true, "值": true}
			return {"终局": true, "值": false}
	return {"终局": false}

# ---- 三、算子（五人的精神牌 / 大招 / 副武器）----
static func 执行算子(运行: Dictionary, 表: Dictionary) -> Array:
	var ctx: Dictionary = 运行.get("ctx") if 运行.get("ctx") is Dictionary else {}
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var u = Btl.找单位(ctx, ctx.get("_当前出牌者"), "ally")
	if not MoonPhase.活着(u):
		return []
	var 牌名 := str(卡.get("名", ""))
	match str(表.get("动作", "")):
		"月·月光共鸣":
			return MoonPhase.释放月相(ctx, false)
		"月·月相大招":
			MoonPhase.切换月相(ctx, str(表.get("月相", "")), 牌名)
			var 摘 := MoonPhase.释放月相(ctx, true)
			MoonDeck.随侍结算(ctx, u, 卡)
			return 摘
		"月·王女的祈愿":
			Btl.加战意(u, 15.0, ctx, 牌名)
			var 抽 := Setup.抽专属牌(u, 1) if MoonPhase.随侍数(ctx) >= 2 else []
			return [MoonDeck._记(ctx, 牌名, u, "战意 +15%s" % ("；随侍 ≥ 2，抽 1 张精神牌" if not 抽.is_empty() else ""))]
		"月·月华流转":
			var 摘2 := MoonPhase.释放月相(ctx, false)
			MoonDeck.随侍结算(ctx, u, 卡)
			return 摘2
		"月·不动如山":
			u["不动如山中"] = true
			MoonDeck.随侍结算(ctx, u, 卡)
			return [MoonDeck._记(ctx, 牌名, u, "到下个我方阶段开始前受到的伤害 ×0.8")]
		"月·修理装置":
			return _修理装置(ctx, u, 牌名)
		"月·空中回收":
			return _空中回收(ctx, u, 牌名)
		"月·月华再生":
			var 随 := MoonPhase.随侍达成(ctx, u)
			for a in Units.livingOf("ally", ctx):
				MoonPhase.治疗(ctx, u, a, 0.15, 2.0 if 随 else 1.0)
			MoonDeck.随侍结算(ctx, u, 卡)
			for e in J.or_(u.get("副武器栏"), []):
				if e is Dictionary and str(((e.get("卡") if e.get("卡") is Dictionary else {}) as Dictionary).get("id", "")) == 修理装置:
					e["禁用"] = true
			return [MoonDeck._记(ctx, 牌名, null, "我方全体回复 15%%%s" % ("（随侍：溢流转化 ×2）" if 随 else ""))]
		"月·弦月一闪":
			return _弦月一闪(ctx, u, 卡)
		"月·锚链调度":
			return _锚链调度(ctx, u, 牌名)
		"月·重力网":
			if MoonDeck.随侍结算(ctx, u, 卡):
				MoonPhase.状态(ctx)["拘束必中回合"] = ctx.get("turn")
			var 敌们: Array = Units.livingOf("enemy", ctx).filter(func(e): return Units.unitRow(e) == Fm.ROW_FRONT)
			if 敌们.is_empty():
				敌们 = Units.livingOf("enemy", ctx)
			var 打: Array = []
			for e in 敌们:
				打.append("%s −%s" % [e.name, J.s(CardEffects._固定伤害(ctx, e, 1100.0))])
				if MoonPhase.活着(e):
					MoonPhase.挂拘束(ctx, e)
			return ["重力网：%s" % "、".join(打)]
	return []

static func _修理装置(ctx: Dictionary, u: Dictionary, 牌名: String) -> Array:
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if not MoonPhase.活着(t) or is_same(t, u):
		var 们: Array = Units.livingOf("ally", ctx).filter(func(a): return not is_same(a, u))
		J.sort(们, func(a, b): return float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp))
		t = 们[0] if not 们.is_empty() else null
	if t == null:
		return []
	var 邻 := Fm.十字相邻位(float(u.slot)).has(int(t.slot))
	var 回 := MoonPhase.治疗(ctx, u, t, 0.25 if 邻 else 0.125, 1.0)
	Btl.换同源增益(t, "修理装置", {"def": 15.0, "剩余": 1.0})
	return [MoonDeck._记(ctx, 牌名, t, "回复 %s HP%s，防御 +15" % [J.s(回), "" if 邻 else "（不相邻，减半）"])]

static func _空中回收(ctx: Dictionary, u: Dictionary, 牌名: String) -> Array:
	var 前们: Array = Units.livingOf("ally", ctx).filter(func(a):
		return not is_same(a, u) and Fm.rowOfSlot(float(a.slot)) == Fm.ROW_FRONT)
	if 前们.is_empty():
		return [MoonDeck._记(ctx, 牌名, u, "前排没有队友")]
	J.sort(前们, func(a, b): return float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp))
	var t: Dictionary = 前们[0]
	if Fm.rowOfSlot(float(u.slot)) == Fm.ROW_BACK:
		BattleSwap.换位(ctx, "ally", u.slot, t.slot, {"来源": 牌名})
	var 回 := MoonPhase.治疗(ctx, u, t, 0.15, 1.0)
	return [MoonDeck._记(ctx, 牌名, t, "回复 %s HP（现在在%s）" % [J.s(回), Fm.位名(float(t.slot))])]

static func _弦月一闪(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> Array:
	var 随 := MoonPhase.随侍达成(ctx, u)
	var w: Dictionary = (卡.get("月武器") as Dictionary).duplicate(true)
	if 随:
		w["必中"] = true
	var 结果 := Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, ctx.get("_当前目标"))
	var 摘要 := Btl.攻击结果摘要(结果)
	if 随 and MoonPhase.月相(ctx) == MoonPhase.残月 and MoonPhase.王女(ctx) != null:
		摘要.append_array(MoonPhase.余响(ctx, 900.0))
	MoonDeck.随侍结算(ctx, u, 卡)
	return 摘要

static func _锚链调度(ctx: Dictionary, u: Dictionary, 牌名: String) -> Array:
	var 菲 = MoonPhase.王女(ctx)
	if 菲 == null or is_same(菲, u):
		return []
	var 换 = 菲
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if MoonPhase.是随侍(ctx, u) and MoonPhase.活着(t) and not is_same(t, u) and not is_same(t, 菲) \
		and not Fm.十字相邻位(float(菲.slot)).has(int(t.slot)):
		换 = t
	BattleSwap.换位(ctx, "ally", u.slot, 换.slot, {"来源": 牌名})
	return [MoonDeck._记(ctx, 牌名, u, "与 %s 交换位置（现在在%s）" % [换.name, Fm.位名(float(u.slot))])]

# ---- 四、被动与数值钩子 ----
static func 命中修正(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	if not MoonPhase.是月球王国(att) or not (w is Dictionary) or (w as Dictionary).is_empty():
		return 0.0
	var 修 := float(J.num0((att as Dictionary).get("月球下张命中")))
	if ctx is Dictionary and MoonPhase.有拘束(def) and J.same(MoonPhase.状态(ctx).get("拘束必中回合"), ctx.get("turn")):
		修 += 1000.0
	return 修

static func 攻方伤害倍率(ctx: Variant, att: Variant, w: Variant) -> float:
	if w is Dictionary and float(J.num0((w as Dictionary).get("前排增伤"))) > 0.0 and MoonPhase.是月球王国(att) \
		and Fm.是前排有效(att, ctx):
		return 1.0 + float(w.前排增伤)
	return 1.0

static func 受击后(def: Dictionary) -> void:
	if MoonPhase.键(def) == "M2" and MoonPhase.是月球王国(def):
		def["月球受击"] = float(def.get("月球受击", 0.0)) + 1.0

static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if not MoonPhase.是月球王国(att) or not (def is Dictionary) or not (w is Dictionary):
		return
	if J.truthy(att.get("月球余响共鸣")):
		att.erase("月球余响共鸣")
		if MoonPhase.王女(ctx) != null and MoonPhase.活着(def):
			var 实 := CardEffects._固定伤害(ctx, def, 700.0)
			Btl.pushLog(ctx, "〔余响共鸣〕Feena 追加 %s → %s" % [J.s(实), def.name], J.merged({"类型": "余响共鸣"}, Btl.谁目标(def)))
	if float(J.num0(landed)) <= 0.0:
		return
	if J.truthy(w.get("命中后拘束")) and MoonPhase.活着(def):
		MoonPhase.挂拘束(ctx, def)
	if float(J.num0(w.get("命中后破防"))) > 0.0:
		Btl.换同源增益(def, "破防", {"def": -float(w.命中后破防), "剩余": 1.0})
	var 减id := str(J.or_(w.get("命中减大招冷却"), ""))
	for 槽 in J.or_(att.get("大招槽"), []) if 减id != "" else []:
		if 槽 is Dictionary and str(((槽.get("卡") if 槽.get("卡") is Dictionary else {}) as Dictionary).get("id", "")) == 减id:
			槽["cd"] = maxf(0.0, float(槽.get("cd", 0.0)) - 1.0)
	var 比 := float(J.num0(w.get("命中后治疗最低")))
	if 比 > 0.0:
		var 们: Array = Units.livingOf("ally", ctx)
		J.sort(们, func(a, b): return float(a.hp) / float(a.maxHp) - float(b.hp) / float(b.maxHp))
		if not 们.is_empty():
			MoonPhase.治疗(ctx, att, 们[0], 比, 1.0)

## 主武器冷却 / 打出后抽牌 / 「下张武器」消费 / 本场打出过大招。
static func 牌打出后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> void:
	if 区 == CardPlay.区_主武器 or 区 == CardPlay.区_副武器 or 区 == CardPlay.区_大招槽:
		u.erase("月球下张命中")
	if not 是月球牌(卡):
		return
	if 区 == CardPlay.区_主武器 and float(卡.get("冷却", 0.0)) > 0.0:
		卡["当前冷却"] = float(卡.冷却)
	if int(J.num0(卡.get("打出后抽精神"))) > 0:
		Setup.抽专属牌(u, int(卡.打出后抽精神))
	if 区 == CardPlay.区_大招槽:
		MoonPhase.状态(ctx)["打出过大招"] = true

## 结束回合的 AI 补打：月球王国成员只打自己武器栏里的牌（没有能打的就不补，不回落到旧武器）。
static func AI补打(ctx: Dictionary, u: Dictionary) -> void:
	var 卡 = Btl._自动武器栏卡(ctx, u, null)
	if 卡 is Dictionary:
		Btl.打出武器栏卡(ctx, u.get("key"), 卡, null)
