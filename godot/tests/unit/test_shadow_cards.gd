## 影世界 v0.2.1 卡牌效果：四人的副武器 / 命中后换位 / 被动，五张大招，势力牌；外加开选项的整场冒烟。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §4 / §6；对局走真的 `Setup.开局`（`选项.影世界v02 = true`）。
extends RefCounted

const 种子 := 20261021
const 开 := {"影世界v02": true}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_一_副武器(t)
	_二_命中后与被动(t)
	_三_大招(t)
	_四_势力牌(t)
	_五_冒烟(t)

func _一_副武器(t) -> void:
	var c := _开局()
	var 蕾 = _我(c, "B2")
	var 前 := int(蕾.slot)
	DeckFlow.打出副武器(c, "B2", "SHD_B2_SUB")
	t.ok(int(蕾.slot) != 前 and J.inc(Fm.十字相邻位(float(前)), float(蕾.slot)), "① 游刃有余：蕾卡换到十字相邻格（%d → %d）" % [前, int(蕾.slot)])
	t.ok(float(J.g(蕾.get("幻影机动"), "值")) == 10.0 and ShadowUnits.闪避加成(蕾, c) == 10.0, "① 幻影机动：被移位一次闪避 +10")
	for i in 4:
		ShadowV02.换位(c, "ally", 蕾.slot, Fm.另一排同位(float(蕾.slot)), "测试")
	t.ok(ShadowUnits.闪避加成(蕾, c) == 30.0, "① 幻影机动最多 +30")

	var c2 := _开局()
	c2["公有手牌"] = []
	_我(c2, "B3")["战意"] = 100.0
	DeckFlow.打出副武器(c2, "B3", "SHD_B3_SUB")
	t.ok((c2.公有手牌 as Array).size() == 1 and str(c2.公有手牌[0].get("id")) == "SHD_GATE_SEED", "① 播种（未错位）：置入 1 张影之种")
	var c3 := _开局()
	c3["公有手牌"] = []
	var 维 = _我(c3, "B3")
	维["战意"] = 100.0
	维[BattleSwap.错位键] = true
	DeckFlow.打出副武器(c3, "B3", "SHD_B3_SUB")
	var 种 := (c3.公有手牌 as Array).filter(func(x): return str(x.get("id")) == "SHD_GATE_SEED" and J.truthy(x.get("置入副本")))
	t.ok(种.size() == 2 and (c3.公有手牌 as Array).size() == 3, "① 播种（错位）：置入 2 张影之种 + 抽 1 张影门牌")
	t.ok(_库有(c3, "SHD_GATE_SEED2"), "① 播种（错位）：寄生影种·改放入影门牌库")
	var 库前 := SubDeck.牌们(c3.get("影门牌库")).size()
	BattleCardExec.打出精神或公有牌(c3, "B3", 种[0], Units.livingOf("enemy", c3)[0])
	t.ok(SubDeck.牌们(c3.get("影门牌库")).size() == 库前, "① 置入的影之种副本打完不回库")

	var c4 := _开局()
	var 比 = _我(c4, "B4")
	比["战意"] = 100.0
	var 敌 = BattleSwap.格上单位(c4, "enemy", 0)
	DeckFlow.打出副武器(c4, "B4", "SHD_B4_SUB", 敌)
	t.ok(int(敌.slot) == 3 and Calc.buffSum(敌, "armorPct") == -15.0, "① 抓投：第 1 列甩到同排最远的第 4 列，有效防御 −15%%")
	t.ok(J.num0(c4.get("turnShiftCount")) == 1.0, "① 抓投移入空格记 1 次移位")

func _二_命中后与被动(t) -> void:
	var c := _开局()
	var 维 = _我(c, "B3")
	var 敌 = BattleSwap.格上单位(c, "enemy", 5)
	var w: Dictionary = _武器栏卡(维, "SHD_B3_W1").武器
	ShadowUnits.武器攻击后(c, 维, 敌, 0.0, w)
	t.ok(int(敌.slot) == 5, "② 影缚没命中 → 不换位")
	ShadowUnits.武器攻击后(c, 维, 敌, 1.0, w)
	t.ok(int(敌.slot) == 1, "② 影缚命中 → 目标与同列对位互换（5 → %d）" % int(敌.slot))
	var 蕾 = _我(c, "B2")
	var 曲: Dictionary = _武器栏卡(蕾, "SHD_B2_W1").武器
	var 敌2 = BattleSwap.格上单位(c, "enemy", 0)
	ShadowUnits.武器攻击后(c, 蕾, 敌2, 1.0, 曲)
	t.ok(int(敌2.slot) == 0, "② 曲射弹：蕾卡未错位 → 命中也不换位")
	蕾[BattleSwap.错位键] = true
	ShadowUnits.武器攻击后(c, 蕾, 敌2, 1.0, 曲)
	t.ok(int(敌2.slot) == 4, "② 曲射弹：蕾卡〔错位〕→ 命中后目标换到同列对位")
	var 比 = _我(c, "B4")
	var 抛: Dictionary = _武器栏卡(比, "SHD_B4_W1").武器
	t.ok(ShadowUnits.暴击修正(比, 敌2, 抛) == 20.0 and ShadowUnits.暴击修正(比, {"hp": 1.0}, 抛) == 0.0,
		"② 抛射弹对〔错位〕目标暴击 +20，其余 +0")
	var 雷 = _我(c, "B1")
	var 战前 := Btl.战意(雷)
	ShadowUnits.武器攻击后(c, 雷, 敌2, 1.0, {"影效": "影刃错位"})
	t.ok(Btl.战意(雷) == minf(战前 + 5.0, J.num0(雷.get("战意上限")) if J.num0(雷.get("战意上限")) > 0.0 else 战前 + 5.0), "② 影刃斩·错位命中后战意 +5")

func _三_大招(t) -> void:
	var c := _开局()
	var 雷 = _我(c, "B1")
	雷["战意"] = 100.0
	var 敌 = BattleSwap.格上单位(c, "enemy", 1)
	敌[BattleSwap.错位键] = true
	var 前 := float(敌.hp)
	DeckFlow.打出大招(c, "B1", "SHD_B1_ULT1", 敌)
	t.ok(float(敌.hp) == 前 - maxf(3200.0, J.round(前 * 0.45)), "③ 传送斩打〔错位〕目标取较高值（%s → %s）" % [J.s(前), J.s(敌.hp)])
	t.ok(int(雷.slot) == 1, "③ 传送斩：雷萨换到目标所在列的我方前排（%d）" % int(雷.slot))
	t.ok(J.truthy(雷.get("主武器已销毁")), "③ 武器型大招占主武器")

	var c2 := _开局()
	var 雷2 = _我(c2, "B1")
	雷2["战意"] = 100.0
	c2["battleShiftCount"] = 6.0
	DeckFlow.刷新实时门槛(c2)
	BattleSwap.格上单位(c2, "enemy", 0)[BattleSwap.错位键] = true
	var 果 := DeckFlow.打出大招(c2, "B1", "SHD_B1_ULT2")
	t.ok(J.truthy(果.get("成功")) and _库有(c2, "SHD_GATE_COLLAPSE"), "③ 万刃归一（本场移位 6）打出，错位（敌）→ 次元崩落放入影门牌库（%s）" % str(果.get("原因", "")))
	t.ok(ShadowUnits.攻方伤害倍率(c2, 雷2, null, {"影倍": 1.5}) == 1.5, "③ 对〔错位〕敌机 ×1.5 写在武器实例上")

	var c3 := _开局()
	var 维 = _我(c3, "B3")
	维["战意"] = 100.0
	var 敌3 = BattleSwap.格上单位(c3, "enemy", 0)
	ShadowDeck.叠影种(敌3, 100.0)
	c3["本场影种"] = 3.0
	DeckFlow.刷新实时门槛(c3)
	var 甲前 := J.num0(敌3.get("armorCut"))
	var 果3 := DeckFlow.打出大招(c3, "B3", "SHD_B3_ULT")
	t.ok(J.truthy(果3.get("成功")) and J.num0(敌3.get("armorCut")) == 甲前 + 150.0, "③ 影之森：全体再削甲 150（%s）" % str(果3.get("原因", "")))
	t.ok(int(敌3.slot) == 4 and J.num0(c3.get("turnShiftCount")) >= 1.0, "③ 影之森：带影种的敌机与同列对位互换")

	var c4 := _开局()
	var 比 = _我(c4, "B4")
	比["战意"] = 100.0
	c4["turnShiftCount"] = 3.0
	DeckFlow.刷新实时门槛(c4)
	for e in Units.livingOf("enemy", c4):
		e[BattleSwap.错位键] = true
	var 前们 := Units.livingOf("enemy", c4).map(func(e): return float(e.hp))
	var 果4 := DeckFlow.打出大招(c4, "B4", "SHD_B4_ULT", Units.livingOf("enemy", c4)[0])
	var 掉 := 0
	var 活们 := Units.livingOf("enemy", c4)
	for i in 活们.size():
		if float(活们[i].hp) < float(前们[i]):
			掉 += 1
	t.ok(J.truthy(果4.get("成功")) and 掉 >= 2, "③ 连锁投掷弹向其他〔错位〕敌机（掉血 %d 台）" % 掉)
	t.ok(_库有(c4, "SHD_GATE_SEED2"), "③ 连锁投掷错位（敌）→ 寄生影种·改放入")

	var c5 := _开局()
	_我(c5, "B2")["战意"] = 100.0
	c5["turnShiftCount"] = 2.0
	DeckFlow.刷新实时门槛(c5)
	var 前排 := [BattleSwap.格上单位(c5, "enemy", 0), BattleSwap.格上单位(c5, "enemy", 1)]
	DeckFlow.打出大招(c5, "B2", "SHD_B2_ULT")
	t.ok(int(前排[0].slot) == 1 and int(前排[1].slot) == 0, "③ 影凤凰：受击的前排 1⇄2 互换")

func _四_势力牌(t) -> void:
	var c := _开局()
	var 雷 = _我(c, "B1")
	雷["战意"] = 100.0
	var 低 = _我(c, "B2")
	低["hp"] = 100.0
	_放手牌(c, "SHD_FAC_2")
	BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_2")
	t.ok(Fm.rowOfSlot(float(低.slot)) == Fm.ROW_BACK and J.num0(低.get("shieldHp")) > 0.0, "④ 门扉轮转：前排最低血换到后排并得护盾")
	_放手牌(c, "SHD_FAC_3")
	var 雷位 := int(雷.slot)
	BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_3")
	t.ok(int(低.slot) == 雷位 and ShadowUnits.攻方伤害倍率(c, 雷, null, {}) == 1.15, "④ 换形：与最低血队友换位，本回合伤害 +15%%")
	var 敌们 := Units.livingOf("enemy", c)
	敌们[0]["hp"] = 100.0
	var 高 = ShadowV02.按血挑(敌们, true)
	var 高位 := int(高.slot)
	_放手牌(c, "SHD_FAC_4")
	BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_4")
	t.ok(int(敌们[0].slot) == 高位 and Calc.buffSum(高, "hit") == -15.0, "④ 错乱：最高血与最低血互换，命中 −15")
	_放手牌(c, "SHD_FAC_6")
	c["公有手牌"] = (c.公有手牌 as Array).slice(-1)
	BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_6", 高)
	t.ok(J.truthy(高.get("禁用护卫")) and _库有(c, "SHD_GATE_FAULT"), "④ 影缝（目标已错位）：错位敌机禁援护，空间断层放入")
	var 槽 := DeckFlow.找大招槽(雷, "SHD_B1_ULT1")
	槽["cd"] = 3.0
	_放手牌(c, "SHD_FAC_7")
	BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_7", "B1")
	t.ok(float(槽.cd) == 1.0 and _库有(c, "SHD_GATE_REACTOR"), "④ 影返（场上有错位敌机）：冷却 −2，炉心逆流放入")
	Setup.打一回合(c)
	if c.get("result") == null:
		t.ok(not J.truthy(高.get("禁用护卫")), "④ 下个我方阶段初解除禁援护")

func _五_冒烟(t) -> void:
	var c := Setup.跑完(_我编成(), _敌编成(), 种子, 开)
	t.ok(c.get("result") != null, "⑤ 开选项整场自动战斗跑完：%s" % str(J.g(c.get("result"), "结果")))
	var c2 := Setup.开局(_我编成(), _敌编成(), 种子 + 1, null, 开)
	for e in Units.livingOf("enemy", c2):
		e["hp"] = 30000.0
		e["maxHp"] = 30000.0
	var 打出 := 0
	for 回 in 12:
		if c2.get("result") != null:
			break
		for u in Units.livingOf("ally", c2):
			for e in (u.副武器栏 as Array).duplicate():
				if J.truthy(DeckFlow.打出副武器(c2, u.key, e.卡.get("id")).get("成功")):
					打出 += 1
			for 槽 in (u.大招槽 as Array).duplicate():
				if DeckFlow.大招可用吗(c2, u, 槽) and J.truthy(DeckFlow.打出大招(c2, u.key, 槽.卡.get("id")).get("成功")):
					打出 += 1
		for 卡 in (c2.公有手牌 as Array).duplicate():
			var 谁 := CardPlay.找执行机体(c2, 卡, CardPlay.区_公有)
			if not 谁.is_empty() and J.truthy(BattleCardExec.打出精神或公有牌(c2, 谁.key, 卡).get("成功")):
				打出 += 1
		for u in Units.livingOf("ally", c2):
			Btl.打出武器栏卡(c2, u.key)
		c2["result"] = Setup.checkResult(c2) if c2.get("result") == null else c2.result
		if c2.get("result") == null:
			Setup.打一回合(c2)
	t.ok(打出 > 10, "⑤ 逐回合把能打的影世界牌都打一遍：共 %d 张、%s" % [打出, "已分胜负" if c2.get("result") != null else "12 回合未分胜负"])
	t.ok(J.num0(c2.get("battleShiftCount")) > 0.0, "⑤ 本场移位 %d 次" % int(J.num0(c2.get("battleShiftCount"))))

# ---- 辅助 ----
func _我编成() -> Array:
	return [{"键": "B1", "位": 0, "等级": 10}, {"键": "B2", "位": 1, "等级": 10},
		{"键": "B3", "位": 6, "等级": 10}, {"键": "B4", "位": 4, "等级": 10}]

func _敌编成() -> Array:
	return [{"键": "grunt", "位": 0, "等级": 1}, {"键": "grunt", "位": 1, "等级": 1},
		{"键": "grunt", "位": 5, "等级": 1}]

func _开局() -> Dictionary:
	var c := Setup.开局(_我编成(), _敌编成(), 种子, null, 开)
	for e in Units.livingOf("enemy", c):
		e["hp"] = 50000.0
		e["maxHp"] = 50000.0
	return c

func _我(c: Dictionary, 键: String) -> Variant:
	for u in c.get("allies", []):
		if u is Dictionary and str(u.get("key", "")) == 键:
			return u
	return null

func _放手牌(c: Dictionary, id: String) -> Dictionary:
	var 源 := ShadowDeck.影门牌(id)
	if 源.is_empty():
		for x in ShadowDeck.势力牌们():
			if str(x.get("id")) == id:
				源 = x
	var 卡: Dictionary = 源.duplicate(true)
	(c["公有手牌"] as Array).append(卡)
	return 卡

func _库有(c: Dictionary, id: String) -> bool:
	for x in SubDeck.牌们(c.get("影门牌库")):
		if x is Dictionary and str(x.get("id")) == id:
			return true
	return false

func _武器栏卡(u: Dictionary, id: String) -> Dictionary:
	for x in u.武器栏:
		if str(x.get("id")) == id:
			return x
	return {}
