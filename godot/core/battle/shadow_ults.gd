## 职责：影世界五张大招的效果本体（传送斩 / ★影界·万刃归一 / ★影凤凰 / ★影之森 / ★连锁投掷）。
## 约定：大招槽走 `DeckFlow` 通用路径（不写处理者）：亮起靠卡上的 `实时门槛`，本文件只管打出之后的结算。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §4
class_name ShadowUlts
extends RefCounted

static func 执行算子(运行: Dictionary, 表: Dictionary) -> Array:
	var ctx: Dictionary = 运行.get("ctx")
	var 卡: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 打者 = ShadowV02.施放者(ctx)
	if 打者 == null:
		return []
	match str(表.get("动作", "")):
		"影·传送斩":
			return _传送斩(ctx, 打者, 卡, 表)
		"影·万刃归一":
			return _万刃归一(ctx, 打者, 卡, 表)
		"影·影凤凰":
			return _影凤凰(ctx, 打者, 卡, 表)
		"影·影之森":
			return _影之森(ctx, 打者, 卡, 表)
		"影·连锁投掷":
			return _连锁投掷(ctx, 打者, 卡, 表)
	return []

static func _打(ctx: Dictionary, u: Dictionary, w: Dictionary, e: Dictionary) -> Dictionary:
	if not ShadowV02.活(e):
		return {"击破": 0.0}
	return Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, e)

static func _武(卡: Dictionary, 类型: String, 伤害: String, 威力: float, 距离: Array, 属性: String = "射击") -> Dictionary:
	return ShadowUnits.武器(str(卡.get("名", "")), {"类型": 类型, "伤害": 伤害, "威力": 威力, "距离": 距离, "属性": 属性})

## 雷萨先换到目标所在列的我方前排（已在那儿就与同列后排互换），再按硬币 / 〔错位〕取伤害。
static func _传送斩(ctx: Dictionary, 雷: Dictionary, 卡: Dictionary, 表: Dictionary) -> Array:
	var 敌 = ShadowV02.敌目标(ctx, "最高血")
	if 敌 == null:
		return ["没有目标"]
	var 牌名 := str(卡.get("名", ""))
	var 落 := int(Fm.slotOf(Fm.ROW_FRONT, Fm.colOfSlot(float(敌.slot))))
	if int(雷.slot) == 落:
		落 = Fm.另一排同位(落)
	var k := ShadowV02.换位(ctx, "ally", 雷.slot, 落, 牌名)
	var 定 := float(J.num0(表.get("固定")))
	var 比 := J.round(float(敌.hp) * float(J.num0(表.get("比例"))))
	if Boss.取Boss脚本(敌) != null:
		比 = minf(比, float(J.num0(表.get("Boss上限"))))
	var 值 := maxf(定, 比)
	var 方式 := "目标已〔错位〕→ 取较高值"
	if not BattleSwap.已错位(敌):
		var 正 := ctx.get("rng") == null or float(ctx.rng.next_float()) < 0.5
		值 = 定 if 正 else 比
		方式 = "硬币：%s" % ("定额" if 正 else "当前 HP 比例")
	var 实 := ShadowV02.真伤(ctx, 雷, 敌, 值)
	ShadowV02.记(ctx, 牌名, 雷, "换位（移位 %d）后斩 %s：%s，造成 %s 点无视防御伤害" % [k, ShadowV02.名(敌), 方式, J.s(实)])
	return ["传送斩 → %s（%s）" % [ShadowV02.名(敌), J.s(实)]]

static func _万刃归一(ctx: Dictionary, 雷: Dictionary, 卡: Dictionary, 表: Dictionary) -> Array:
	var 错们 := ShadowDeck.错位敌们(ctx)
	var w := _武(卡, "indirect", "特殊", float(J.num0(表.get("威力"))), [1, 6], "格斗")
	var 击破 := 0.0
	for e in Units.livingOf("enemy", ctx):
		var w2 := w.duplicate(true)
		if J.inc(错们, e):
			w2["影倍"] = float(J.num0(表.get("错位倍率")))
		击破 += J.num0(_打(ctx, 雷, w2, e).get("击破"))
	if not 错们.is_empty():
		ShadowDeck.错位触发(ctx, 卡)
	return ["万刃归一：敌方全体（%d 台已错位 ×%s）" % [错们.size(), J.s(表.get("错位倍率"))]]

## 敌方前排全体受击 → 受击的前排 1⇄2、3⇄4 互换 → 蕾卡换到同列前排。
static func _影凤凰(ctx: Dictionary, 蕾: Dictionary, 卡: Dictionary, 表: Dictionary) -> Array:
	var 牌名 := str(卡.get("名", ""))
	var 错们 := ShadowDeck.错位敌们(ctx)
	var w := _武(卡, "indirect", "特殊", float(J.num0(表.get("威力"))), [1, 6])
	var 受击位 := {}
	for e in Units.livingOf("enemy", ctx).filter(func(x): return Fm.rowOfSlot(float(x.slot)) == Fm.ROW_FRONT):
		受击位[int(e.slot)] = true
		var w2 := w.duplicate(true)
		if J.inc(错们, e):
			w2["影倍"] = float(J.num0(表.get("错位倍率")))
		_打(ctx, 蕾, w2, e)
	for 对 in [[0, 1], [2, 3]]:
		if 受击位.has(对[0]) or 受击位.has(对[1]):
			ShadowV02.换位(ctx, "enemy", 对[0], 对[1], 牌名)
	if ShadowV02.活(蕾) and Fm.rowOfSlot(float(蕾.slot)) == Fm.ROW_BACK:
		ShadowV02.换位(ctx, "ally", 蕾.slot, ShadowV02.对位格(蕾), 牌名)
	if not 错们.is_empty():
		ShadowDeck.错位触发(ctx, 卡)
	return ["影凤凰：敌方前排 %d 台" % 受击位.size()]

## 全体削甲 → 全体特殊伤害 → 带〔影种〕的敌机与同列对位互换（每列最多换一次）→ 每层〔影种〕追加定额伤害。
static func _影之森(ctx: Dictionary, 维: Dictionary, 卡: Dictionary, 表: Dictionary) -> Array:
	var 牌名 := str(卡.get("名", ""))
	var 错们 := ShadowDeck.错位敌们(ctx)
	for e in Units.livingOf("enemy", ctx):
		e["armorCut"] = J.num0(e.get("armorCut")) + float(J.num0(表.get("削甲")))
	var w := _武(卡, "indirect", "特殊", float(J.num0(表.get("威力"))), [1, 6])
	for e in Units.livingOf("enemy", ctx):
		_打(ctx, 维, w.duplicate(true), e)
	var 换过列 := {}
	var 带种 := Units.livingOf("enemy", ctx).filter(func(x): return J.num0(x.get("影种层数")) > 0.0)
	for e in 带种:
		var 列 := int(Fm.colOfSlot(float(e.slot)))
		if 换过列.has(列) or not ShadowV02.活(e):
			continue
		换过列[列] = true
		ShadowV02.换位(ctx, "enemy", e.slot, ShadowV02.对位格(e), 牌名)
	var 合 := 0.0
	for e in 带种:
		合 += ShadowV02.真伤(ctx, 维, e, float(J.num0(表.get("每层"))) * J.num0(e.get("影种层数")))
	ShadowV02.记(ctx, 牌名, 维, "〔影种〕融毁共鸣：%d 台，合计 %s" % [带种.size(), J.s(合)])
	if not 错们.is_empty():
		ShadowDeck.错位触发(ctx, 卡)
	return ["影之森：融毁 %d 台" % 带种.size()]

## 打指定目标，再依次弹向其余已〔错位〕的敌机（连首目标最多 `上限` 台）；弹射必中、无视遮挡。
static func _连锁投掷(ctx: Dictionary, 比: Dictionary, 卡: Dictionary, 表: Dictionary) -> Array:
	var 首 = ShadowV02.敌目标(ctx, "最高血")
	if 首 == null:
		return ["没有目标"]
	var 错们 := ShadowDeck.错位敌们(ctx)
	var w := _武(卡, "indirect", "物理", float(J.num0(表.get("威力"))), [1, 5])
	_打(ctx, 比, w.duplicate(true), 首)
	var n := 1
	for e in 错们:
		if n >= int(J.num0(表.get("上限"))):
			break
		if is_same(e, 首) or not ShadowV02.活(e):
			continue
		var w2 := w.duplicate(true)
		w2["必中"] = true
		w2["ignore_block"] = true
		_打(ctx, 比, w2, e)
		n += 1
	if not 错们.is_empty():
		ShadowDeck.错位触发(ctx, 卡)
	return ["连锁投掷：%d 台" % n]
