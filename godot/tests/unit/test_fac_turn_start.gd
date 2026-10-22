## 职责：BR-1 / BR-1.1 正面断言 —— 「我方阶段初」这一拍真的在干活：
##   月球王国月光环绕（BR-1-c）、指挥职业被动（BR-1-d）、增援 + 词条到点自爆（BR-1-e）、
##   敌方词条「电磁干扰」冷却延长 + 「隐身刷新」（BR-1.1-c）。（流星小队单独行动随旧势力退役，COL-1 删掉）
## 旧毛病：回合初那几条规则只跑一次或根本不跑，第 2 回合起就没了 / 从来不触发。
extends RefCounted

const 种子 := 20261019
const 到第几回合 := 3

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	if not errors.is_empty():
		return
	_月球王国(t)
	_指挥被动(t)
	_增援与到点自爆(t)
	_敌方词条(t)

## 一个我方阶段推进一步（不跑 AI / 敌方出手，专验「我方阶段初」这一钩子）。
func _推进(ctx: Dictionary) -> void:
	Setup.endTurn(ctx)
	BattlePhaseFlow.开始我方阶段(ctx)

func _开(我: Array) -> Dictionary:
	return Setup.开局(我, [{"键": "fighter", "位": 0, "等级": 1}], 种子, null, SessionBattleOptions.生产(null))

# ---- 二、月球王国旧版（`月球v02 = false`）：Feena 的月光环绕（相邻位队友吃月光祝福） ----
func _月球王国(t) -> void:
	var 邻 := float(Fm.相邻位(0.0)[0])
	var 旧版 := SessionBattleOptions.生产(null)
	旧版["月球v02"] = false
	var ctx := Setup.开局([{"键": "M1", "位": 0, "等级": 30}, {"键": "M2", "位": 邻, "等级": 30}], [{"键": "fighter", "位": 0, "等级": 1}], 种子, null, 旧版)
	var 菲 = Btl.找单位(ctx, "M1", "ally")
	var 受 = Btl.找单位(ctx, "M2", "ally")
	if not (菲 is Dictionary) or not (受 is Dictionary):
		t.ok(false, "月球王国：M1（Feena）/ M2（阿布拉德）没进场")
		return
	var 参 := Fac.势力参数("月球王国")
	var 数 := FacMoon.月光祝福数值(菲, 参)
	t.ok(not 数.is_empty(), "② M1 身上有【月光祝福】武器（数值 %s）" % str(数))
	t.ok(not FacMoon.月球光环受益(菲, ctx, 参).is_empty(),
		"② M2 站在相邻位（%s），是月光环绕的受益者" % Fm.位名(邻))
	t.ok(_光环条(受, 数) != null,
		"② 第 1 回合：月光祝福真的挂在 M2 身上（命中 +%s）" % J.s(数.get("hit", 0.0)))
	Setup.endTurn(ctx)
	t.ok(_光环条(受, 数) == null,
		"② 第 1 回合结束：月光祝福按设计清掉（1 回合的增益）")
	for _i in 2:
		_推进(ctx)
	t.ok(int(ctx.turn) == 到第几回合, "② 推进到了第 %d 回合（%d）" % [到第几回合, int(ctx.turn)])
	t.ok(_光环条(受, 数) != null,
		"★ ② 第 %d 回合的我方阶段初**重新判定**过 → 月光祝福还在（命中 +%s）" % [到第几回合, J.s(数.get("hit", 0.0))])
	var 名单: Array = Fac.势力状态(菲, "月球王国").get("光环名单", [])
	t.ok(名单.has("M2"), "★ ② 第 %d 回合的光环名单里还是 M2（%s）" % [到第几回合, str(名单)])

## 单位身上那条「势力·月球王国」的增益（没有 → null）。注意 M1 自己也是**指挥**，
## 所以 `buffSum` 里还会混进指挥被动给的 +10，这里按来源单挑那一条。
func _光环条(u: Dictionary, 数: Dictionary) -> Variant:
	for b in J.or_(u.get("buffs"), []):
		if b is Dictionary and b.get("src") == FacMoon.月球光环来源:
			if is_equal_approx(float(b.get("hit", 0.0)), float(数.get("hit", 0.0))):
				return b
	return null

# ---- 三、指挥职业被动：同排队友命中 +10（本回合） ----
func _指挥被动(t) -> void:
	var ctx := _开([{"键": "S2", "位": 0, "等级": 30}, {"键": "S1", "位": 1, "等级": 30}])
	var 指 = Btl.找单位(ctx, "S2", "ally")
	var 友 = Btl.找单位(ctx, "S1", "ally")
	if not (指 is Dictionary) or not (友 is Dictionary):
		t.ok(false, "指挥被动：S2（卡嘉莉 · 指挥）/ S1（拉克丝）没进场")
		return
	t.ok(Reach.职业是(指, "指挥"), "③ S2（卡嘉莉）职业 = 指挥")
	t.ok(Calc.buffSum(友, "hit") == 0.0,
		"③ 开局时还没有这个增益（回合初才给；buffSum hit = %s）" % J.s(Calc.buffSum(友, "hit")))
	BattlePhaseFlow.开始我方阶段(ctx)
	t.ok(is_equal_approx(Calc.buffSum(友, "hit"), 10.0),
		"★ ③ 我方阶段初：同排队友命中 +10（buffSum hit = %s）" % J.s(Calc.buffSum(友, "hit")))
	var 有记录 := J.some(ctx.get("log"), func(e): return e is Dictionary and str(e.get("类型", "")) == "指挥")
	t.ok(有记录, "★ ③ 战报里有一行〔指挥〕（三层反馈的「即时」那一条）")
	Setup.endTurn(ctx)
	BattlePhaseFlow.开始我方阶段(ctx)
	t.ok(int(ctx.turn) == 到第几回合 and is_equal_approx(Calc.buffSum(友, "hit"), 10.0),
		"★ ③ 第 %d 回合还是 +10（每回合重给，buffSum hit = %s）" % [到第几回合, J.s(Calc.buffSum(友, "hit"))])

# ---- 四、增援 / 词条「到点自爆」（都在我方阶段初，顺序 = 增援 → 自爆 → 势力 → 指挥） ----
func _增援与到点自爆(t) -> void:
	var 选项 := SessionBattleOptions.生产(null)
	选项["波次"] = [{"回合": 2.0, "来": [{"键": "fighter", "等级": 1.0}]}]
	var ctx := Setup.开局([{"键": "W1", "位": 0, "等级": 30}], [{"键": "shield", "位": 0, "等级": 1}], 种子, null, 选项)
	t.ok((ctx.get("enemies") as Array).size() == 1,
		"④ 开局敌方只有 1 台（%d）" % (ctx.get("enemies") as Array).size())
	var 老 = Btl.找单位(ctx, "shield", "enemy")
	if not (老 is Dictionary):
		t.ok(false, "④ 没找到敌方 shield")
		return
	# 给在场的那台挂「到点自爆 · 第 2 回合」（词条系统自己的入口）
	Traits.词条到单位([老], {"词条": [{"键": "自爆回合", "值": 2.0}]})
	t.ok(J.num0(老.get("自爆回合")) == 2.0, "④ 词条挂上了：自爆回合 = %s" % J.s(老.get("自爆回合")))
	BattlePhaseFlow.开始我方阶段(ctx)
	t.ok(int(ctx.turn) == 2, "④ 推进到第 2 回合（%d）" % int(ctx.turn))
	t.ok((ctx.get("enemies") as Array).size() == 2,
		"★ ④ 增援：敌方 1 → 2 台（%d）" % (ctx.get("enemies") as Array).size())
	t.ok(J.some(ctx.get("log"), func(e): return e is Dictionary and str(e.get("类型", "")) == "增援"),
		"★ ④ 战报里有〔增援〕事件")
	t.ok(float(老.hp) <= 0.0,
		"★ ④ 到点自爆：第 2 回合那台真的炸了并退场（hp = %s）" % J.s(老.hp))
	t.ok(J.some(ctx.get("log"), func(e): return e is Dictionary and str(e.get("类型", "")) == "自爆" \
			and str(e.get("自爆缘由", "")) == "到点自爆"),
		"★ ④ 战报里有一行〔自爆〕，缘由 = 到点自爆")
	var 意图表: Dictionary = ctx.get("敌方意图表") if ctx.get("敌方意图表") is Dictionary else {}
	t.ok(意图表.has("fighter"),
		"④ 新来的 fighter 也进了本回合的**敌方意图**（意图表键：%s）" % str(意图表.keys()))

# ---- 五、敌方词条「电磁干扰」（冷却延长）与「隐身刷新」 ----
func _敌方词条(t) -> void:
	var ctx := _开([{"键": "W1", "位": 0, "等级": 30}])
	var 敌 = Btl.找单位(ctx, "fighter", "enemy")
	var 我 = Btl.找单位(ctx, "W1", "ally")
	if not (敌 is Dictionary) or not (我 is Dictionary):
		t.ok(false, "⑤ 场没搭起来")
		return
	# 给那台敌机挂两条词条（词条系统自己的入口：`冷却延长` = 电磁干扰、`隐身刷新` = 每回合重新隐身）
	Traits.词条到单位([敌], {"词条": [{"键": "冷却延长", "值": 2.0}, {"键": "隐身刷新", "值": 1.0}]})
	t.ok(J.num0(敌.get("冷却延长")) == 2.0 and J.truthy(敌.get("隐身刷新")), "⑤ 两条词条挂上了（冷却延长 = %s）" % J.s(敌.get("冷却延长")))
	# 挑一把「带冷却 / 大招」的武器，先手动置成冷却中（2 回合），再推一个我方阶段
	var 武 = _第一把带冷却的武器(我)
	if 武 == null:
		t.ok(false, "⑤ W1 身上没有带冷却 / 大招的武器")
		return
	武.cd = 2.0
	武.erase("词条已延")
	BattlePhaseFlow.开始我方阶段(ctx)
	t.ok(is_equal_approx(float(武.cd), 4.0),
		"★ ⑤ 电磁干扰：那件武器冷却 2 → %s 回合（+2，正好是词条的 `冷却延长`）" % J.s(武.cd))
	t.ok(J.some(ctx.get("log"), func(e): return e is Dictionary and str(e.get("类型", "")) == "冷却延长"),
		"★ ⑤ 战报里有一行〔电磁干扰〕（类型 = 冷却延长）")
	t.ok(J.truthy(敌.get("隐身中")),
		"★ ⑤ 隐身刷新：带该词条的敌机在我方阶段初重新进入隐身（隐身中 = %s）" % str(敌.get("隐身中")))
	# 每件武器只延一次：同一个我方阶段里再广播一次，不该再 +2
	RuleHooks.广播("我方阶段初_词条", [ctx])
	t.ok(is_equal_approx(float(武.cd), 4.0), "⑤ 同一件武器只延一次（再广播一次仍是 %s）" % J.s(武.cd))

## 身上「带冷却 / 是大招」的第一件武器实例（`u.weapons` 里那种 `{t, cd}` 条目）。
func _第一把带冷却的武器(u: Dictionary) -> Variant:
	for e in J.or_(u.get("weapons"), []):
		if e is Dictionary and J.truthy(e.get("t")) and (J.num0(e.t.get("cd")) > 0 or Ai.isUltimate(e.t)):
			return e
	return null
