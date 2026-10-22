## 职责：影世界四人（雷萨 / 蕾卡 / 维诺 / 比格特拉克）的卡池（`data/cards/影世界.json` 的「驾驶员」）与独有机制（门之力 / 幻影机动 / 影种侵蚀 / 命中后换位 / 四张位移类副武器）。
## 约定：卡表只读 `Db.T.卡包`；影门牌库与势力牌在 `ShadowDeck`，五张大招在 `ShadowUlts`。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §4
class_name ShadowUnits
extends RefCounted

const 势力 := "影世界"
const 档位 := {"初始": 10, "剧情": 20, "肉鸽三选一": 30}
## 雷萨〔错位〕时的换装层（下个我方阶段初撤掉）。
const 错位换装来源 := "错位·影刃斩"
const 幻影机动每次 := 10.0
const 幻影机动上限 := 30.0

# ---- 一、卡表（JSON → 卡字典）----
static func 武器(名: String, 参: Dictionary) -> Dictionary:
	var w := {
		"name": 名, "fire": str(J.or_(参.get("类型"), "direct")),
		"power": float(J.or_(参.get("威力"), 1000.0)), "hit": float(J.or_(参.get("命中"), 100.0)),
		"critMod": float(J.or_(参.get("暴击"), 0.0)), "stat": str(J.or_(参.get("属性"), "射击")),
		"dmgType": str(J.or_(参.get("伤害"), "物理")), "cd": 0.0, "uses": null,
		"unlock": 1.0, "upgrades": [], "ignoreDef": false, "special": null, "area": "single",
		"距离": J.or_(参.get("距离"), [1, 6]),
	}
	var 段 := int(J.num0(参.get("段数")))
	if 段 > 1:
		w["hits"] = float(段)
		w["special"] = "multi"
	if J.truthy(参.get("无视遮挡")):
		w["ignore_block"] = true
	if J.truthy(参.get("无视前排")):
		w["无视前排"] = true
	if J.truthy(参.get("必中")):
		w["必中"] = true
	if str(J.or_(参.get("影效"), "")) != "":
		w["影效"] = str(参.get("影效"))
	return w

static func _卡(键名: String, 条目: Dictionary) -> Dictionary:
	var 获取 := str(J.or_(条目.get("获取"), "初始"))
	var 卡 := {
		"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
		"卡类": str(条目.get("卡类", "专属精神牌")), "类型": "战术", "层级": "角色", "种类": "角色",
		"归属": 键名, "角色": 键名, "角色们": [键名], "占行动": [],
		"耗气": float(J.or_(条目.get("耗气"), 0.0)), "回气": 0.0, "限次": 99.0,
		"冷却": float(J.or_(条目.get("冷却"), 0.0)), "回库": false, "衍生": false, "入库条件": null,
		"获取": 获取, "等级需求": int(档位.get(获取, 10)),
		"效果说明": str(条目.get("效果说明", "")), "目标": str(条目.get("目标", "")), "效果": [],
		"武器牌": J.truthy(条目.get("武器牌")), "连携": false, "角色所属势力": 势力,
		"错位": str(J.or_(条目.get("错位"), "")), "错位放入": str(J.or_(条目.get("错位放入"), "")),
	}
	for k in ["实时门槛", "错位变体"]:
		if 条目.get(k) is Dictionary:
			卡[k] = (条目[k] as Dictionary).duplicate(true)
	if 条目.get("武器参") is Dictionary:
		卡["武器"] = 武器(卡.名, 条目.get("武器参"))
	if str(J.or_(条目.get("动作"), "")) != "":
		卡["动作"] = str(条目.get("动作"))
		卡["效果"] = ShadowDeck.效果组(条目)
	return 卡

## 某人的全卡池（四人 16 张）。
static func 角色牌们(键名: String) -> Array:
	var 出: Array = []
	var 包: Variant = ShadowDeck.卡包().get("驾驶员")
	var 条们: Variant = (包 as Dictionary).get(键名) if 包 is Dictionary else null
	for 条目 in (条们 as Array) if 条们 is Array else []:
		if 条目 is Dictionary:
			出.append(_卡(键名, 条目))
	return 出

static func 装填单位(u: Variant, 等级: int) -> Array:
	var 出: Array = []
	for c in 角色牌们(ShadowV02.键(u)):
		if 等级 >= int(c.get("等级需求", 10)):
			出.append(c)
	return 出

static func 是影世界动作牌(卡: Variant) -> bool:
	return 卡 is Dictionary and str((卡 as Dictionary).get("角色所属势力", "")) == 势力 \
		and str((卡 as Dictionary).get("动作", "")) != "" and str((卡 as Dictionary).get("卡类", "")) == "副武器卡"

static func 是(u: Variant, 键名: String) -> bool:
	return ShadowV02.键(u) == 键名 and ShadowV02.是主成员(u)

## 本人大招槽的 `实时门槛` 现算一次（开局用；之后由 `DeckFlow` 在阶段初 / 换位后刷新）。
static func 刷新本人门槛(ctx: Dictionary, u: Dictionary) -> void:
	for 槽 in J.or_(u.get("大招槽"), []):
		var 门 = J.or_((槽 as Dictionary).get("卡"), {}).get("实时门槛") if 槽 is Dictionary else null
		if 门 is Dictionary:
			var 满足 := DeckFlow.条件满足(ctx, u, 门)
			槽["实时门槛满足"] = 满足
			槽["门槛说明"] = "" if 满足 else str((门 as Dictionary).get("说明", ""))

# ---- 二、副武器（无武器数据，由 `副武器特殊打出` 接手）----
static func 副武器门槛(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> String:
	if Btl.战意(u) < Btl.战意费用(卡):
		return "战意不足（要 %d，现在 %d）" % [int(Btl.战意费用(卡)), int(Btl.战意(u))]
	if str(卡.get("动作", "")) == "影·抓投" and _敌前排(ctx).is_empty():
		return "敌方前排没有敌机"
	return ""

static func 打出副武器(ctx: Dictionary, u: Dictionary, 条目: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	var 费 := Btl.战意费用(卡)
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	条目["本回合已用"] = int(条目.get("本回合已用", 0)) + 1
	if float(条目.get("cd_max", 0.0)) > 0.0:
		条目["cd"] = float(条目.get("cd_max", 0.0))
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	var 摘要 := CardEffects.execute(ctx, 卡)
	DeckFlow.记上张打出牌(ctx, u, 卡)
	Btl.pushLog(ctx, "〔副武器〕%s 打出【%s】（战意 -%s，不销毁主武器，本回合已用 %d/%d；冷却 %d）%s" % [
		str(u.get("name", "")), str(卡.get("名", "")), J.s(费), int(条目.get("本回合已用", 0)),
		int(条目.get("本回合可用", 1)), int(条目.get("cd", 0.0)), Btl.效果摘要文(摘要)],
		J.merged({"类型": "副武器", "单位": u.get("key"), "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"主武器已销毁": J.truthy(u.get("主武器已销毁")), "效果摘要": 摘要, "cd": 条目.get("cd")}, Btl.谁(u)))
	DeckFlow.刷新实时门槛(ctx)
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "击破": 0.0, "效果摘要": 摘要,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "cd": float(条目.get("cd", 0.0))}

static func 执行算子(运行: Dictionary, 表: Dictionary) -> Array:
	var ctx: Dictionary = 运行.get("ctx")
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(卡.get("名", ""))
	var 打者 = ShadowV02.施放者(ctx)
	if 打者 == null:
		return []
	match str(表.get("动作", "")):
		"影·门之力":
			var 低 = ShadowV02.按血挑(Units.livingOf("ally", ctx), false)
			var 去: Variant = ShadowV02.对位格(打者) if (低 == null or is_same(低, 打者)) else 低.slot
			var k := ShadowV02.换位(ctx, "ally", 打者.slot, 去, 牌名)
			Btl.换同源增益(打者, "门之力", {"eva": float(J.num0(表.get("闪避"))), "剩余": 1.0})
			ShadowV02.记(ctx, 牌名, 打者, "换位（移位 %d），本回合闪避 +%d" % [k, int(J.num0(表.get("闪避")))])
			if BattleSwap.已错位(打者):
				ShadowDeck.错位触发(ctx, 卡)
			return ["门之力 → %s" % ShadowV02.名(打者)]
		"影·游刃有余":
			var 去2 := _游刃落点(ctx, 打者)
			var k2 := ShadowV02.换位(ctx, "ally", 打者.slot, 去2, 牌名) if 去2 >= 0 else 0
			var 抽 := Setup.抽专属牌(打者, 1)
			ShadowV02.记(ctx, 牌名, 打者, "与相邻格换位（移位 %d），抽 %d 张专属牌" % [k2, 抽.size()])
			return ["游刃有余 → %s" % ShadowV02.名(打者)]
		"影·播种":
			var 成立 := BattleSwap.已错位(打者)
			var 置 := 0
			for i in (2 if 成立 else 1):
				if J.or_(ctx.get("公有手牌"), []).size() < int(Params.公有手牌自然上限()):
					var 种: Dictionary = ShadowDeck.影门牌("SHD_GATE_SEED").duplicate(true)
					种["置入副本"] = true
					(ctx["公有手牌"] as Array).append(种)
					置 += 1
			ShadowV02.记(ctx, 牌名, 打者, "置入 %d 张【影之种】到公有手牌%s" % [置, "（满手作废 %d 张）" % ((2 if 成立 else 1) - 置) if 置 < (2 if 成立 else 1) else ""])
			if 成立:
				ShadowDeck.错位触发(ctx, 卡)
			return ["播种 ×%d" % 置]
		"影·抓投":
			var 敌 = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
			if not ShadowV02.活(敌) or Fm.rowOfSlot(float(敌.slot)) != Fm.ROW_FRONT:
				敌 = ShadowV02.按血挑(_敌前排(ctx), true)
			if 敌 == null:
				return ["敌方前排没有敌机"]
			var 列 := int(Fm.colOfSlot(float(敌.slot)))
			var k3 := ShadowV02.换位(ctx, "enemy", 敌.slot, int(Fm.slotOf(Fm.ROW_FRONT, 3.0 if 列 < 2 else 0.0)), 牌名)
			Btl.换同源增益(敌, "抓投", {"armorPct": float(J.num0(表.get("防御"))), "剩余": 1.0})
			ShadowV02.记(ctx, 牌名, 敌, "甩到同排最远列（移位 %d），本回合有效防御 %d%%" % [k3, int(J.num0(表.get("防御")))])
			return ["抓投 → %s" % ShadowV02.名(敌)]
	return []

static func _敌前排(ctx: Dictionary) -> Array:
	return Units.livingOf("enemy", ctx).filter(func(e): return Fm.rowOfSlot(float(e.slot)) == Fm.ROW_FRONT)

## 【游刃有余】的落点：指定的十字相邻队友 → 第一个相邻队友 → 第一个相邻空格。
static func _游刃落点(ctx: Dictionary, u: Dictionary) -> int:
	var 邻: Array = Fm.十字相邻位(float(u.slot))
	var 指 = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if ShadowV02.活(指) and J.inc(邻, float(指.slot)):
		return int(指.slot)
	for s in 邻:
		if BattleSwap.格上单位(ctx, "ally", s) != null:
			return int(s)
	return int(邻[0]) if not 邻.is_empty() else -1

# ---- 三、换位后 / 阶段初 ----
## 雷萨挂上〔错位〕→ 影刃斩换成错位版；蕾卡每被移位一次 → 【幻影机动】闪避 +10（最多 +30）。
static func 换位后(ctx: Dictionary, side: String, 移动的: Array) -> void:
	if side != "ally":
		return
	for u in 移动的:
		if 是(u, "B1") and BattleSwap.已错位(u):
			_换上错位影刃斩(ctx, u)
		if 是(u, "B2"):
			var 记 = (u as Dictionary).get("幻影机动")
			var 值 := float((记 as Dictionary).get("值", 0.0)) if 记 is Dictionary and J.same((记 as Dictionary).get("回合"), ctx.get("turn")) else 0.0
			值 = minf(幻影机动上限, 值 + 幻影机动每次)
			u["幻影机动"] = {"回合": ctx.get("turn"), "值": 值}
			ShadowV02.记(ctx, "幻影机动", u, "被移位 → 闪避 +%d（本回合累计）" % int(值))

static func _换上错位影刃斩(ctx: Dictionary, u: Dictionary) -> void:
	if DeckFlow.当前换装来源(u).has(错位换装来源):
		return
	var 新表: Array = []
	var 换了 := false
	for c in J.or_(u.get("武器栏"), []):
		if c is Dictionary and (c as Dictionary).get("错位变体") is Dictionary:
			新表.append(错位变体(c))
			换了 = true
		else:
			新表.append(c)
	if not 换了:
		return
	DeckFlow.压栈武器栏(u, 新表, 错位换装来源, false, ctx)
	ShadowV02.记(ctx, "门之力·折跃", u, "已〔错位〕→ 影刃斩换成【影刃斩·错位】（距离 1–4、无视遮挡）")

static func 错位变体(c: Dictionary) -> Dictionary:
	var 变: Dictionary = c.get("错位变体")
	var v := c.duplicate(true)
	v.erase("错位变体")
	v["id"] = str(变.get("id", ""))
	v["名"] = str(变.get("名", ""))
	var w: Dictionary = v.get("武器") if v.get("武器") is Dictionary else {}
	w["name"] = v["名"]
	if 变.get("距离") is Array:
		w["距离"] = (变["距离"] as Array).duplicate()
	if J.truthy(变.get("无视遮挡")):
		w["ignore_block"] = true
	if J.truthy(变.get("无视前排")):
		w["无视前排"] = true
	if str(J.or_(变.get("影效"), "")) != "":
		w["影效"] = str(变.get("影效"))
	return v

static func 阶段初(ctx: Dictionary) -> void:
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		if DeckFlow.弹栈武器栏(u, 错位换装来源):
			ShadowV02.记(ctx, "门之力·折跃", u, "〔错位〕结束 → 武器栏换回【影刃斩】")
		for k in ["门扉折光命中", "换形回合", "换形伤害"]:
			(u as Dictionary).erase(k)
	for e in J.or_(ctx.get("影世界禁护卫"), []):
		if e is Dictionary:
			(e as Dictionary).erase("禁用护卫")
	ctx.erase("影世界禁护卫")

# ---- 四、数值钩子 ----
static func 闪避加成(def: Variant, ctx: Variant) -> float:
	var 记 = (def as Dictionary).get("幻影机动") if def is Dictionary else null
	if 记 is Dictionary and J.same((记 as Dictionary).get("回合"), (ctx as Dictionary).get("turn")):
		return float((记 as Dictionary).get("值", 0.0))
	return 0.0

## 【影种侵蚀】维诺命中 +10 × 带〔影种〕的敌机数；【门扉折光】下一张武器牌命中 +20。
static func 命中修正(att: Variant, _def: Variant, w: Variant, ctx: Variant) -> float:
	if not (att is Dictionary) or not (w is Dictionary):
		return 0.0
	var 修 := float(J.num0((att as Dictionary).get("门扉折光命中")))
	if 是(att, "B3"):
		var n := Units.livingOf("enemy", ctx).filter(func(e): return J.num0(e.get("影种层数")) > 0.0).size()
		修 += 10.0 * float(n)
	return 修

## 【门之力·折跃】雷萨〔错位〕时近战暴击 +15；【抛射弹】对〔错位〕目标暴击 +20。
static func 暴击修正(att: Variant, def: Variant, w: Variant) -> float:
	if not (w is Dictionary):
		return 0.0
	var 修 := 0.0
	if 是(att, "B1") and BattleSwap.已错位(att) and Reach.rangeKindOf(w) == Reach.KIND_MELEE():
		修 += 15.0
	if str((w as Dictionary).get("影效", "")) == "抛射弹" and BattleSwap.已错位(def):
		修 += 20.0
	return 修

## 【换形】本回合伤害 +15%；大招对〔错位〕目标的倍率写在武器实例的 `影倍` 上。
static func 攻方伤害倍率(ctx: Variant, att: Variant, _def: Variant, w: Variant) -> float:
	var 倍 := 1.0
	if att is Dictionary and J.same((att as Dictionary).get("换形回合"), (ctx as Dictionary).get("turn")):
		倍 *= 1.0 + float(J.num0((att as Dictionary).get("换形伤害")))
	if w is Dictionary and float(J.num0((w as Dictionary).get("影倍"))) > 0.0:
		倍 *= float((w as Dictionary).get("影倍"))
	return 倍

## 命中后：【影缚】/〔错位〕时的【曲射弹】把目标与同列对位换位；【影刃斩·错位】战意 +5。
static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if not (w is Dictionary) or float(J.num0(landed)) <= 0.0 or not (att is Dictionary):
		return
	match str((w as Dictionary).get("影效", "")):
		"影缚":
			if ShadowV02.活(def):
				ShadowV02.换位(ctx, "enemy", def.slot, ShadowV02.对位格(def), "影缚")
		"曲射弹":
			if ShadowV02.活(def) and BattleSwap.已错位(att):
				ShadowV02.换位(ctx, "enemy", def.slot, ShadowV02.对位格(def), "曲射弹")
		"影刃错位":
			Btl.加战意(att, 5.0, ctx, "影刃斩·错位")

## 【牌打出后】：〔错位〕的曲射弹抽影门；武器牌消费门扉折光；记「打出过影世界大招」。
static func 牌打出后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> void:
	if 区 == CardPlay.区_主武器 or (区 == CardPlay.区_大招槽 and J.truthy(卡.get("武器牌"))):
		u.erase("门扉折光命中")
	if 区 == CardPlay.区_主武器 and str(卡.get("错位", "")) == "自" and str(卡.get("角色所属势力", "")) == 势力 \
		and BattleSwap.已错位(u):
		ShadowDeck.错位触发(ctx, 卡)
	if 区 == CardPlay.区_大招槽 and str(卡.get("角色所属势力", "")) == 势力:
		ctx["本场影世界大招"] = true
		DeckFlow.检查公有待入库(ctx)

## 结束回合的 AI 补打：影世界四人只打自己武器栏里的牌（没有能打的就不补，不回落到旧武器）。
static func AI补打(ctx: Dictionary, u: Dictionary) -> void:
	var 卡 = Btl._自动武器栏卡(ctx, u, null)
	if 卡 is Dictionary:
		Btl.打出武器栏卡(ctx, u.get("key"), 卡, null)
