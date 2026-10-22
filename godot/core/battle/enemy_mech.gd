## 职责：敌方阵营机制里要挂规则钩子的部分（N4 粒子抑制场的精神牌加费、N2 悬赏令、N5 影锁拽位）。只认单位数据字段，不认势力。
class_name EnemyMech
extends RefCounted

## 精神牌打出后：抑制场成立就多扣 1 点战意（门槛那边 `CardPlay._实际费` 已经按 +1 判过）。
static func 牌打出后(ctx: Dictionary, u: Dictionary, _卡: Dictionary, 区: String) -> void:
	if 区 != CardPlay.区_精神 or BattleMorale.抑制层数(ctx, u) <= 0:
		return
	BattleMorale.设战意(u, BattleMorale.战意(u) - 1.0)
	Btl.pushLog(ctx, "〔粒子抑制场〕%s 的精神牌多耗 1 点战意" % str(u.get("name", "")),
		J.merged({"类型": "粒子抑制", "单位": u.get("key")}, Btl.谁(u)))

# ======================== N2【悬赏令】 ========================
## 场上还有活着的带 `悬赏令` 的敌机吗。
static func 悬赏开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	for x in J.or_(ctx.get("enemies"), []):
		if x is Dictionary and float(x.get("hp", 0.0)) > 0.0 and J.truthy(x.get("悬赏令")):
			return true
	return false

## 当前悬赏目标（活着的我方机体），没有就 null。
static func 悬赏目标(ctx: Variant) -> Variant:
	if not (ctx is Dictionary) or not J.truthy(ctx.get("悬赏目标")):
		return null
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and str(u.get("key", "")) == str(ctx.悬赏目标) and float(u.get("hp", 0.0)) > 0.0:
			return u
	return null

## 敌方阶段开始：先给上一个悬赏目标结赏金（它本回合击破过敌机 → 战意 +10），再按本回合我方输出重新标记。
static func 敌方阶段初(ctx: Dictionary) -> void:
	var 旧 = 悬赏目标(ctx)
	var 输出 := {}
	var 旧击破 := 0
	for l in J.or_(ctx.get("log"), []):
		if not (l is Dictionary) or not J.same(l.get("回合"), ctx.turn) or str(l.get("单位方", "")) != "ally":
			continue
		if str(l.get("类型", "")) == "攻击" and J.num0(l.get("伤害")) > 0.0:
			var k := str(l.get("单位", ""))
			输出[k] = float(输出.get(k, 0.0)) + J.num0(l.get("伤害"))
		if 旧 != null and str(l.get("类型", "")) == "击破" and str(l.get("单位", "")) == str(旧.key):
			旧击破 += 1
	if 旧 != null and 旧击破 > 0:
		Btl.加战意(旧, 10.0, ctx, "悬赏赏金")
		Btl.pushLog(ctx, "〔悬赏令〕%s 顶着悬赏击破了敌机：战意 +10（赏金反咬）" % str(旧.name),
			J.merged({"类型": "悬赏令", "事件": "赏金", "单位": 旧.key}, Btl.谁(旧)))
	ctx.erase("悬赏目标")
	if not 悬赏开(ctx) or 输出.is_empty():
		return
	var 最 := ""
	var 最高 := -1.0
	for u in J.or_(ctx.get("allies"), []):
		var k2 := str(u.get("key", ""))
		if float(u.get("hp", 0.0)) > 0.0 and 输出.has(k2) and float(输出[k2]) > 最高:
			最 = k2
			最高 = float(输出[k2])
	if 最.is_empty():
		return
	ctx["悬赏目标"] = 最
	var 标 = 悬赏目标(ctx)
	Btl.pushLog(ctx, "〔悬赏令〕本回合输出最高的 %s 被悬赏：私兵优先打它、伤害 +20%%" % str(标.name),
		J.merged({"类型": "悬赏令", "事件": "标记", "单位": 最, "输出": 最高}, Btl.谁(标)))

## 带悬赏令的敌机：悬赏目标够得着时只许选它（预告与实战同源，都经 `Ai.bestWeaponOn`）。
static func 可选目标(ctx: Dictionary, actor: Variant, target: Variant, w: Variant) -> Dictionary:
	if not (actor is Dictionary) or not J.truthy(actor.get("悬赏令")):
		return {"终局": false}
	var 标 = 悬赏目标(ctx)
	if 标 == null or is_same(标, target):
		return {"终局": false}
	var 敌们 := Units.livingOf(Units.otherSide(actor.side), ctx)
	if not Reach.近战可达(actor, w, 标, 敌们):
		return {"终局": false}
	return {"终局": true, "可选": false, "原因": "悬赏令：先打悬赏目标"}

## 带悬赏令的敌机打悬赏目标：伤害 +20%。
static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, _w: Variant) -> float:
	if not (att is Dictionary) or not J.truthy(att.get("悬赏令")):
		return 1.0
	var 标 = 悬赏目标(ctx)
	return 1.2 if (标 != null and is_same(标, def)) else 1.0

# ======================== N5【影锁拽位】 ========================
## 带 `影锁武器` 的敌机用那把武器打中我方后排 → 把目标和同列前排换位（前排空着就直接拽进去）。
static func 武器攻击后(ctx: Variant, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	if not (ctx is Dictionary) or not (att is Dictionary) or not (def is Dictionary) or not (w is Dictionary):
		return
	if not J.truthy(att.get("影锁武器")) or str(w.get("name", "")) != str(att.影锁武器):
		return
	if str(def.get("side", "")) != "ally" or float(def.get("hp", 0.0)) <= 0.0 or float(J.num0(landed)) <= 0.0:
		return
	if Fm.rowOfSlot(float(def.slot)) != Fm.ROW_BACK:
		return
	var 前 := Fm.另一排同位(def.slot)
	if 前 < 0:
		return
	var 原 := float(def.slot)
	if BattleSwap.换位(ctx, "ally", 原, float(前), {"来源": "影锁"}) > 0:
		Btl.pushLog(ctx, "〔影锁〕%s 把 %s 从后排拽到了前排" % [str(att.get("name", "")), str(def.get("name", ""))],
			J.merged({"类型": "影锁", "单位": att.get("key"), "目标": def.get("key"), "从": 原, "到": float(前)}, Btl.谁(att)))

# ======================== 界面提示 ========================
## 棋盘悬停用的阵营机制提示（只读）：封锁线、悬赏令、粒子抑制、λ 共振、影锁、宿敌。
static func 机制提示(u: Dictionary, ctx: Dictionary) -> Array:
	var 出: Array = []
	if J.truthy(u.get("封锁线")):
		出.append("封锁线：%s" % ("完整 —— 直射打不到敌方后排" if Reach.封锁线成立(ctx, "enemy") else "已破（前排有缺口）"))
	if J.truthy(u.get("悬赏令")):
		var 标 = 悬赏目标(ctx)
		出.append("悬赏令：%s" % (("优先打 %s、伤害 +20%%" % str(标.get("name", ""))) if 标 is Dictionary else "这回合还没人被悬赏"))
	if J.truthy(u.get("粒子散布")):
		出.append("粒子抑制：每台让我方战意获得 −25%（最多 2 台），精神牌 +1 费")
	if J.truthy(u.get("λ共振")):
		出.append("λ 共振：λ 力场每回合挡 %d 下、每下减 %d" % [int(Calc.λ次数上限(u, ctx)), int(Calc.λ减免量(u))])
	if J.truthy(u.get("影锁武器")):
		出.append("影锁：打中我方后排会把它拽到同列前排")
	if J.truthy(u.get("_宿敌生效")):
		出.append("宿敌：认出了老对手（会优先打名单上的人 / 名单上的人打它更疼）")
	return 出
