## 影世界 v0.2.1 试玩 MVP：开关 / 移位计数 / ★错位抽牌 / 影门牌库三级断路器 / 影种 / 深渊之门 / 大招亮起 / 错位换装 / 拉米亚 / 关开关零影响 / 结束回合 AI 补打。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md；对局走真的 `Setup.开局`（`选项.影世界v02 = true`）。
extends RefCounted

const 种子 := 20261021
const 开 := {"影世界v02": true}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_一_开关与装填(t)
	_二_移位计数(t)
	_三_错位抽牌(t)
	_四_影门牌库断路器(t)
	_五_影种(t)
	_六_深渊之门(t)
	_七_大招亮起(t)
	_八_错位换装(t)
	_九_拉米亚(t)
	_十_关开关零影响(t)
	_十一_AI补打(t)

# ---- ① 开关 / 装填 ----
func _一_开关与装填(t) -> void:
	var c := _开局()
	t.ok(ShadowV02.开(c), "① B1–B4 + 选项开 → 影世界开启")
	t.ok(SubDeck.牌们(c.get("影门牌库")).size() == 4, "① 开局影门牌库只有一级牌 4 张（%d）" % SubDeck.牌们(c.get("影门牌库")).size())
	var 势 := 0
	for 卡 in c.公有牌库 + c.公有待入库 + c.公有手牌:
		if ShadowDeck.是势力牌(卡):
			势 += 1
	t.ok(势 == 8, "① 8 张势力牌全部进下排（牌库 + 待入库 + 手牌 = %d）" % 势)
	var 张 := 0
	for k in ShadowV02.成员键:
		var u = _我(c, k)
		张 += (u.武器栏 as Array).size() + (u.副武器栏 as Array).size() + (u.大招槽 as Array).size()
	t.ok(张 == 16, "① 四人成员牌 16 张都装进了武器栏 / 副武器栏 / 大招槽（%d）" % 张)
	t.ok(ShadowDeck.影门牌们().size() == 8, "① 影门牌 8 张（一级 4 / 二级 3 / 三级 1）")

# ---- ② 移位计数 ----
func _二_移位计数(t) -> void:
	var c := _开局()
	var 雷 = _我(c, "B1")
	var 蕾 = _我(c, "B2")
	BattleSwap.换位(c, "ally", 雷.slot, 蕾.slot)
	BattleSwap.换位(c, "ally", 雷.slot, 蕾.slot)
	t.ok(J.num0(c.get("turnShiftCount")) == 0.0, "② 非影世界牌换位 → 0 次移位")
	_放手牌(c, "SHD_GATE_STEP")
	var 果 := BattleCardExec.打出精神或公有牌(c, "B1", "SHD_GATE_STEP", "B1")
	t.ok(J.truthy(果.get("成功")), "② 影步打得出来（%s）" % str(果.get("原因", "")))
	t.ok(J.num0(c.get("turnShiftCount")) == 2.0, "② 影步与同列对位队友互换 → 本回合移位 +2（%d）" % int(J.num0(c.get("turnShiftCount"))))
	var 维 = _我(c, "B3")
	var 维对位 := Fm.另一排同位(float(维.slot))
	t.ok(BattleSwap.格上单位(c, "ally", 维对位) == null, "② 维诺同列对位是空格")
	_放手牌(c, "SHD_GATE_STEP")
	BattleCardExec.打出精神或公有牌(c, "B3", "SHD_GATE_STEP", "B3")
	t.ok(J.num0(c.get("turnShiftCount")) == 3.0 and J.num0(c.get("battleShiftCount")) == 3.0,
		"② 移入空格 → 只 +1（本回合 %d / 本场 %d）" % [int(J.num0(c.get("turnShiftCount"))), int(J.num0(c.get("battleShiftCount")))])
	t.ok(BattleSwap.已错位(维), "② 被影世界牌挪过的单位挂〔错位〕")

# ---- ③ ★错位：条件成立才抽；满 6 张不抽，放入照常 ----
func _三_错位抽牌(t) -> void:
	var c := _开局()
	c["公有手牌"] = []
	var 果 := DeckFlow.打出副武器(c, "B1", "SHD_B1_SUB")
	t.ok(J.truthy(果.get("成功")), "③ 门之力打得出来（%s）" % str(果.get("原因", "")))
	t.ok(BattleSwap.已错位(_我(c, "B1")), "③ 门之力换位后雷萨〔错位〕")
	t.ok((c.公有手牌 as Array).size() == 1 and ShadowDeck.是影门牌(c.公有手牌[0]), "③ 错位（自）成立 → 从影门牌库抽 1 张进公有手牌")
	t.ok(_库有(c, "SHD_GATE_REACTOR"), "③ 炉心逆流放入影门牌库")
	var c2 := _开局()
	c2["公有手牌"] = []
	for i in 6:
		(c2.公有手牌 as Array).append({"id": "占位%d" % i, "名": "占位"})
	var 库前 := SubDeck.牌们(c2.get("影门牌库")).size()
	DeckFlow.打出副武器(c2, "B1", "SHD_B1_SUB")
	t.ok((c2.公有手牌 as Array).size() == 6, "③ 公有手牌已满 6 张 → 不抽")
	t.ok(_库有(c2, "SHD_GATE_REACTOR") and SubDeck.牌们(c2.get("影门牌库")).size() == 库前 + 1, "③ 满手时「放入」照常执行")
	var c3 := _开局()
	c3["公有手牌"] = []
	var 蕾 = _我(c3, "B2")
	t.ok(not BattleSwap.已错位(蕾), "③ 蕾卡没有〔错位〕")
	ShadowUnits.牌打出后(c3, 蕾, _武器栏卡(蕾, "SHD_B2_W1"), CardPlay.区_主武器)
	t.ok((c3.公有手牌 as Array).is_empty() and not _库有(c3, "SHD_GATE_FAULT"), "③ 条件不成立 → 不抽、不放入")
	蕾[BattleSwap.错位键] = true
	ShadowUnits.牌打出后(c3, 蕾, _武器栏卡(蕾, "SHD_B2_W1"), CardPlay.区_主武器)
	t.ok((c3.公有手牌 as Array).size() == 1 and _库有(c3, "SHD_GATE_FAULT"), "③ 〔错位〕的曲射弹 → 抽 1 张并放入空间断层")

# ---- ④ 影门牌库：三级牌每场限放入 1 次、打出后移出；一级打完回库 ----
func _四_影门牌库断路器(t) -> void:
	var c := _开局()
	t.ok(ShadowDeck.放入影门牌(c, "SHD_GATE_COLLAPSE"), "④ 次元崩落第一次放入成功")
	t.ok(not ShadowDeck.放入影门牌(c, "SHD_GATE_COLLAPSE"), "④ 次元崩落第二次放入被断路器拦下")
	var 卡 := _从库拿(c, "SHD_GATE_COLLAPSE")
	(c.公有手牌 as Array).append(卡)
	var 敌 = Units.livingOf("enemy", c)[0]
	敌[BattleSwap.错位键] = true
	var 前 := float(敌.hp)
	var 果 := BattleCardExec.打出精神或公有牌(c, "B1", "SHD_GATE_COLLAPSE")
	t.ok(J.truthy(果.get("成功")) and float(敌.hp) == maxf(0.0, 前 - 1800.0), "④ 次元崩落对〔错位〕敌机造成 1800（%s → %s）" % [J.s(前), J.s(敌.hp)])
	t.ok(str(果.get("去处")) == "移出" and not _库有(c, "SHD_GATE_COLLAPSE"), "④ 三级牌打出后移出本场")
	t.ok(not ShadowDeck.放入影门牌(c, "SHD_GATE_COLLAPSE"), "④ 移出后也不能再放入")
	_放手牌(c, "SHD_GATE_STEP")
	var 库前 := SubDeck.牌们(c.get("影门牌库")).size()
	BattleCardExec.打出精神或公有牌(c, "B2", "SHD_GATE_STEP", "B2")
	t.ok(SubDeck.牌们(c.get("影门牌库")).size() == 库前 + 1, "④ 一级牌打完回影门牌库")

# ---- ⑤ 〔影种〕：armorCut 可叠、层数可读 ----
func _五_影种(t) -> void:
	var c := _开局()
	var 敌 = Units.livingOf("enemy", c)[0]
	敌["armor"] = 1000.0
	var 甲前 := Calc.effArmor(敌)
	for i in 2:
		_放手牌(c, "SHD_GATE_SEED")
		BattleCardExec.打出精神或公有牌(c, "B3", "SHD_GATE_SEED", 敌)
	t.ok(J.num0(敌.get("armorCut")) == 200.0 and int(J.num0(敌.get("影种层数"))) == 2, "⑤ 两次影之种：armorCut 200、〔影种〕×2")
	t.ok(Calc.effArmor(敌) == 甲前 - 200.0, "⑤ 有效装甲 %s → %s" % [J.s(甲前), J.s(Calc.effArmor(敌))])
	t.ok(J.num0(c.get("本场影种")) == 2.0, "⑤ 本场影种计数 2")
	t.ok(ShadowV02.标签行(敌).has("〔影种×2〕"), "⑤ 标签行显示〔影种×2〕")
	var 维 = _我(c, "B3")
	t.ok(ShadowUnits.命中修正(维, 敌, {"name": "x"}, c) == 10.0, "⑤ 影种侵蚀：1 台带影种的敌机 → 维诺命中 +10")

# ---- ⑥ 深渊之门：每台每回合最多 3 次；击破记账；下个我方阶段关闭 ----
func _六_深渊之门(t) -> void:
	var c := _开局()
	_放手牌(c, "SHD_FAC_8")
	_我(c, "B1")["战意"] = 100.0
	var 果 := BattleCardExec.打出精神或公有牌(c, "B1", "SHD_FAC_8")
	t.ok(J.truthy(果.get("成功")) and J.truthy(c.get("abyssGateActive")), "⑥ 深渊之门打出 → 开启（%s）" % str(果.get("原因", "")))
	var 敌 = Units.livingOf("enemy", c)[0]
	敌["hp"] = 99999.0
	敌["maxHp"] = 99999.0
	for i in 4:
		ShadowV02.换位(c, "enemy", 敌.slot, Fm.另一排同位(float(敌.slot)), "测试")
	t.ok(float(敌.hp) == 99999.0 - 2100.0, "⑥ 移位 4 次只吃 3 次 700（剩 %s）" % J.s(敌.hp))
	var 敌2 = Units.livingOf("enemy", c)[1]
	敌2["hp"] = 500.0
	var 记前 := (c.log as Array).size()
	ShadowV02.换位(c, "enemy", 敌2.slot, Fm.另一排同位(float(敌2.slot)), "测试")
	var 有击破 := false
	for i in range(记前, (c.log as Array).size()):
		var 条 = c.log[i]
		if 条 is Dictionary and str(J.g(条, "类型")) == "击破":
			有击破 = true
	t.ok(float(敌2.hp) <= 0.0 and 有击破, "⑥ 深渊之门打死的敌机记击破")
	var 用过 := _势力牌实例(c, "SHD_FAC_8")
	t.ok(J.truthy(用过.get("已用")) and bool(ShadowDeck.不可打原因(c, _我(c, "B1"), 用过).get("终局")),
		"⑥ 深渊之门每场 1 次（打出后已用、移出本场）")
	Setup.打一回合(c)
	t.ok(c.get("result") != null or not J.truthy(c.get("abyssGateActive")), "⑥ 下个我方阶段初深渊之门关闭")

# ---- ⑦ 大招按移位门槛亮起（实时门槛，不写处理者）----
func _七_大招亮起(t) -> void:
	var c := _开局()
	var 蕾 = _我(c, "B2")
	蕾["战意"] = 100.0
	var 槽 := DeckFlow.找大招槽(蕾, "SHD_B2_ULT")
	t.ok(not J.truthy(槽.get("实时门槛满足")), "⑦ 开局影凤凰未亮（本回合移位 0）")
	t.ok(DeckFlow.大招不可打原因(c, 蕾, 槽).begins_with("亮起条件未满足"), "⑦ 不可打原因 = 亮起条件未满足")
	DeckFlow.打出副武器(c, "B1", "SHD_B1_SUB")
	t.ok(J.num0(c.get("turnShiftCount")) >= 2.0 and J.truthy(槽.get("实时门槛满足")), "⑦ 门之力换位后本回合移位 %d → 影凤凰亮起" % int(J.num0(c.get("turnShiftCount"))))
	t.ok(DeckFlow.大招不可打原因(c, 蕾, 槽) == "", "⑦ 影凤凰可打")
	var 果 := DeckFlow.打出大招(c, "B2", "SHD_B2_ULT")
	t.ok(J.truthy(果.get("成功")) and J.truthy(c.get("本场影世界大招")), "⑦ 影凤凰打出成功，记「本场打出过影世界大招」")
	var 雷 = _我(c, "B1")
	雷["战意"] = 100.0
	var 斩 := DeckFlow.找大招槽(雷, "SHD_B1_ULT1")
	var 敌 = ShadowV02.按血挑(Units.livingOf("enemy", c), true)
	var 前 := float(敌.hp) if 敌 != null else 0.0
	var 果2 := DeckFlow.打出大招(c, "B1", "SHD_B1_ULT1", 敌)
	t.ok(J.truthy(果2.get("成功")) and (敌 == null or float(敌.hp) < 前), "⑦ 传送斩开战即亮、打得出来并造成伤害")
	t.ok(DeckFlow.大招不可打原因(c, 雷, DeckFlow.找大招槽(雷, "SHD_B1_ULT2")).begins_with("亮起条件") or J.num0(c.get("battleShiftCount")) >= 6.0,
		"⑦ 万刃归一要本场移位 ≥ 6（现在 %d）" % int(J.num0(c.get("battleShiftCount"))))

# ---- ⑧ 雷萨〔错位〕→ 影刃斩换成错位版，下个我方阶段初换回 ----
func _八_错位换装(t) -> void:
	var c := _开局()
	var 雷 = _我(c, "B1")
	var 原 = 雷.武器栏[0]
	DeckFlow.打出副武器(c, "B1", "SHD_B1_SUB")
	t.ok(DeckFlow.当前换装来源(雷).has(ShadowUnits.错位换装来源) and str(雷.武器栏[0].get("名")) == "影刃斩·错位",
		"⑧ 错位后武器栏 = 【影刃斩·错位】")
	var w: Dictionary = 雷.武器栏[0].武器
	t.ok(Reach.武器距离(w) == Vector2i(1, 4) and Reach.无视遮挡(w), "⑧ 错位版距离 1–4、无视遮挡")
	t.ok(ShadowUnits.暴击修正(雷, null, w) == 15.0, "⑧ 门之力·折跃：〔错位〕近战暴击 +15")
	Setup.打一回合(c)
	if c.get("result") == null:
		t.ok(is_same(雷.武器栏[0], 原) and not DeckFlow.当前换装来源(雷).has(ShadowUnits.错位换装来源), "⑧ 下个我方阶段初弹栈 → 换回原来那张影刃斩")
		t.ok(not BattleSwap.已错位(雷) and J.num0(c.get("turnShiftCount")) == 0.0, "⑧ 回合初清〔错位〕与本回合移位")

# ---- ⑨ 拉米亚：单独不开；和 B1 一起时能打影世界势力牌 ----
func _九_拉米亚(t) -> void:
	var 只 := Setup.开局([{"键": "A3", "位": 0, "等级": 10}], _敌编成(), 种子, null, 开)
	t.ok(not ShadowV02.开(只) and not 只.has("影门牌库"), "⑨ 只有拉米亚 → 影世界不开")
	var c := Setup.开局([{"键": "A3", "位": 0, "等级": 10}, {"键": "B1", "位": 1, "等级": 10}], _敌编成(), 种子, null, 开)
	var 拉 = _我(c, "A3")
	var 卡 := _放手牌(c, "SHD_FAC_1")
	t.ok(CardPlay.不可打原因(c, 拉, 卡, CardPlay.区_公有) == "", "⑨ 拉米亚（副势力影世界）能打影界的低语")
	var 果 := BattleCardExec.打出精神或公有牌(c, "A3", "SHD_FAC_1")
	t.ok(J.truthy(果.get("成功")), "⑨ 拉米亚打出影界的低语")

# ---- ⑩ 默认开；显式 `影世界v02 = false` 才关：一字不多 ----
func _十_关开关零影响(t) -> void:
	var 默认 := Setup.开局(_我编成(), _敌编成(), 种子)
	t.ok(ShadowV02.开(默认) and 默认.has("影门牌库"), "⑩ 不写选项 → 影世界默认开")
	var 默只 := Setup.开局([{"键": "A3", "位": 0, "等级": 10}], _敌编成(), 种子)
	t.ok(not ShadowV02.开(默只) and not 默只.has("影门牌库"), "⑩ 默认开但只有拉米亚 → 影世界照样不开")
	var c := Setup.开局(_我编成(), _敌编成(), 种子, null, {"影世界v02": false})
	t.ok(not ShadowV02.开(c) and not c.has("影门牌库") and not c.has("turnShiftCount"), "⑩ 选项不开 → 影世界关、ctx 不多字段")
	t.ok((_我(c, "B1").武器栏 as Array).is_empty() and (_我(c, "B1").大招槽 as Array).is_empty(), "⑩ 选项不开 → 不装成员牌")
	var 势 := 0
	for 卡 in c.公有牌库 + c.公有待入库 + c.公有手牌:
		if ShadowDeck.是势力牌(卡):
			势 += 1
	t.ok(势 == 0, "⑩ 选项不开 → 不装势力牌")
	var 雷 = _我(c, "B1")
	雷[BattleSwap.错位键] = true
	t.ok(ShadowV02.暴击修正(雷, null, {"fire": "melee"}, c) == 0.0 and ShadowV02.攻方伤害倍率(c, 雷, null, {"影倍": 2.0}) == 1.0,
		"⑩ 选项不开 → 数值钩子返回中性值")

# ---- ⑪ 结束回合的 AI 补打：只打自己武器栏里的牌，不回落到旧机体武器 ----
func _十一_AI补打(t) -> void:
	var c := _开局()
	Btl.开始我方阶段(c)
	var 起: int = c.log.size()
	Btl.结束我方回合(c)
	var 栏 := {}
	var 旧 := []
	for i in range(起, c.log.size()):
		var e = c.log[i]
		if not (e is Dictionary) or e.get("单位方") != "ally" or not ShadowV02.成员键.has(str(e.get("单位", ""))):
			continue
		if e.get("类型") == "武器栏":
			var u = _我(c, str(e.单位))
			if not _武器栏卡(u, str(e.get("卡牌ID", ""))).is_empty():
				栏[str(e.单位)] = true
		elif e.get("类型") == "主武器卡":
			旧.append(str(e.单位))
	t.ok(栏.size() == 4 and 旧.is_empty(), "⑪ 四人各由 AI 补打 1 张自己武器栏里的牌（%s），旧武器 0 张（%s）" % [str(栏.keys()), str(旧)])

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

func _势力牌实例(c: Dictionary, id: String) -> Dictionary:
	for x in J.or_(c.get("影门移出"), []):
		if x is Dictionary and str(x.get("id")) == id:
			return x
	return {}

func _库有(c: Dictionary, id: String) -> bool:
	for x in SubDeck.牌们(c.get("影门牌库")):
		if x is Dictionary and str(x.get("id")) == id:
			return true
	return false

func _从库拿(c: Dictionary, id: String) -> Dictionary:
	var 们: Array = SubDeck.牌们(c.get("影门牌库"))
	for i in 们.size():
		if str(们[i].get("id")) == id:
			var 卡: Dictionary = 们[i]
			们.remove_at(i)
			return 卡
	return {}

func _武器栏卡(u: Dictionary, id: String) -> Dictionary:
	for x in u.武器栏:
		if str(x.get("id")) == id:
			return x
	return {}
