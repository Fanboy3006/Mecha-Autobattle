## ★ COL-2（施工单 §2）：殖民卫星军核心 —— 觉醒框架（SEED / ZERO / 隐身）+ QTE 接口 + 感应牌库 + 9 张势力牌。
##
## 权威依据：`协作/设计/殖民卫星军势力卡牌设计 v0.1.md`、`协作/架构/施工单-COL-殖民卫星军落地-DS4.1F.md` §2。
## 受控单位是裸字典（`armor == eva == critBase - 10` ⇒ 命中/暴击干净可算）；「装填 / 开局」那几段走真的 `Setup.开局`。
extends RefCounted

const 千 := 999999.0
const 种子 := 20261018

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_识别与张数(t)
	_段2_开局装填(t)
	_段3_入场牌亮起条件(t)
	_段4_SEED与数值钩子(t)
	_段5_QTE三档(t)
	_段6_觉醒感应(t)
	_段7_感应牌库(t)
	_段8_势力牌(t)
	_段9_隐身(t)
	_段10_ZERO阶段初(t)
	_段11_同种子确定性(t)

# ==========================================================================================
# ① 成员识别 / 卡表张数
# ==========================================================================================
func _段1_识别与张数(t) -> void:
	t.ok(ColonialV01.势力 == "殖民卫星军" and ColonialUnits.成员键.size() == 7,
		"① 殖民卫星军 7 人：%s" % str(ColonialUnits.成员键))
	t.ok(ColonialUnits.成员键 == ["S1", "S2", "W1", "W2", "W3", "W4", "W5"], "① 五人 + COL-MOOK-1 两名大众脸（W4 / W5 重用空号）")
	t.ok(ColonialUnits.职业 == {"S1": "特种", "S2": "指挥", "W1": "狙击", "W2": "近卫", "W3": "重装", "W4": "尖兵", "W5": "特种"},
		"① 战斗分类：S1 特种 / S2 指挥 / W1 狙击 / W2 近卫 / W3 重装 / W4 尖兵 / W5 特种")
	t.ok(ColonialUnits.觉醒.keys().size() == 3, "① 只有三个人有觉醒（%s）" % str(ColonialUnits.觉醒.keys()))

	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 路 := _单位("A1", "ally", 1.0, "近卫")
	路["tags"] = {"战斗分类": "近卫", "势力": "ATX"}
	t.ok(ColonialV01.是殖民卫星军(拉) and not ColonialV01.是殖民卫星军(路),
		"① `是殖民卫星军`：拉克丝 = true、ATX 的响介 = false")
	t.ok(not ColonialV01.开(_场([路], [_靶("靶1", 0.0)])), "① 队里没有殖民卫星军 → `开` = false")

	# —— 感应牌 11 张：一级 4 / 二级 4 / 三级 3 ——
	var 感应 := ColonialDeck.感应牌们()
	var 计 := {"一": 0, "二": 0, "三": 0}
	for c in 感应:
		match int(J.num0((c as Dictionary).get("感应等级"))):
			1: 计["一"] += 1
			2: 计["二"] += 1
			3: 计["三"] += 1
	t.ok(感应.size() == 11 and 计["一"] == 4 and 计["二"] == 4 and 计["三"] == 3,
		"① 感应牌库 11 张（一级 %d / 二级 %d / 三级 %d）" % [计["一"], 计["二"], 计["三"]])
	var 感应都合规 := true
	for c in 感应:
		感应都合规 = 感应都合规 and float((c as Dictionary).get("耗气")) == 0.0 \
			and ColonialDeck.是感应牌(c) and not J.truthy((c as Dictionary).get("觉醒感应"))
	t.ok(感应都合规, "① 感应牌 0 费、算殖民卫星军牌、本身不带【觉醒感应】")

	# —— 势力牌 9 张 ——
	var 势 := ColonialDeck.势力牌们()
	t.ok(势.size() == 9, "① 势力牌 9 张（%d）" % 势.size())
	var 势都合规 := true
	for c in 势:
		势都合规 = 势都合规 and str((c as Dictionary).get("层级")) == "势力" \
			and str((c as Dictionary).get("归属")) == "殖民卫星军" and str((c as Dictionary).get("卡类")) == "公有牌"
	t.ok(势都合规, "① 9 张全部 `层级 = 势力` / `归属 = 殖民卫星军` / `卡类 = 公有牌`")
	var 感应势 := 势.filter(func(c): return J.truthy((c as Dictionary).get("觉醒感应")))
	t.ok(感应势.size() == 4, "① 带【觉醒感应】的势力牌 4 张：%s" % str(感应势.map(func(c): return c.get("名"))))
	t.ok(str(ColonialDeck.感应牌("COL_SD2_FORESIGHT").get("名")) == "零的预见"
		and str(ColonialDeck.感应牌("COL_SD3_FORCE").get("名")) == "强制觉醒", "① 二级「零的预见」/ 三级「强制觉醒」都在库里")

	# —— 入场牌 3 张 ——
	var 入 := ColonialV01.入场牌们()
	t.ok(入.size() == 3, "① 三张觉醒入场牌（%d）" % 入.size())
	t.ok(str(ColonialV01.入场牌("S1").get("觉醒")) == "SEED" and str(ColonialV01.入场牌("W1").get("觉醒")) == "ZERO"
		and str(ColonialV01.入场牌("W2").get("觉醒")) == "隐身", "① S1 = SEED / W1 = ZERO / W2 = 隐身")
	t.ok(J.every(入, func(c): return str(c.get("卡类")) == "大招槽卡" and not J.truthy(c.get("武器牌"))),
		"① 三张都是大招槽卡、不算武器牌（不销毁武器、没有 QTE）")

# ==========================================================================================
# ② 开局装填（`Setup.开局` 真路径）
# ==========================================================================================
func _段2_开局装填(t) -> void:
	var ctx := Setup.开局([
		{"键": "S1", "位": 2, "等级": 30}, {"键": "S2", "位": 4, "等级": 30},
		{"键": "W1", "位": 5, "等级": 30}, {"键": "W2", "位": 0, "等级": 30},
		{"键": "W3", "位": 1, "等级": 30}], [{"键": "grunt", "位": 0, "等级": 1}, {"键": "grunt", "位": 1, "等级": 1}], 种子)
	var 拉 = _找(ctx, "S1")
	var 希 = _找(ctx, "W1")
	var 迪 = _找(ctx, "W2")
	var 卡 = _找(ctx, "S2")
	t.ok(ctx.get("感应牌库") is Dictionary and SubDeck.牌们(ctx.get("感应牌库")).size() == 4,
		"② 开局只有一级感应牌 4 张在库（%d）" % SubDeck.牌们(ctx.get("感应牌库")).size())
	t.ok(ctx.get("本场有人觉醒过") == false, "② 开局 `本场有人觉醒过` = false")
	t.ok(_槽有(拉, "COL_S1_ULT_SEED") and _槽有(希, "COL_W1_ULT_ZERO") and _槽有(迪, "COL_W2_ULT_STEALTH"),
		"② 三个有觉醒的成员各自装到了入场牌")
	var 卡入场: Array = 卡.大招槽.filter(func(x): return str(((x as Dictionary).get("卡") as Dictionary).get("觉醒", "")) != "")
	t.ok(not _槽有(卡, "COL_S1_ULT_SEED") and 卡入场.is_empty(),
		"② 卡嘉莉 / 特洛瓦（燃料）的大招槽没有入场牌")
	var 公有 := 0
	for c in ctx.get("公有牌库") + ctx.get("公有待入库"):
		if c is Dictionary and str(c.get("归属")) == "殖民卫星军":
			公有 += 1
	t.ok(公有 == 9, "② 9 张势力牌全部进了下排（牌库 + 待入库 = %d）" % 公有)

# ==========================================================================================
# ③ 入场牌亮起条件
# ==========================================================================================
func _段3_入场牌亮起条件(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 场 := _场([拉], [_靶("靶1", 0.0)])
	_装入场(拉, "S1")
	var 槽 := ColonialAwaken.入场槽(拉, "SEED")
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) != "", "③ SEED：满血 + 第 1 回合 → 打不出来（HP 与回合都不满足）")
	场["turn"] = 3.0
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) == "", "③ SEED：第 3 回合起 → 打得出来（战意 100 ≥ 50）")
	场["turn"] = 1.0
	拉["hp"] = 拉.maxHp * 0.7
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) == "", "③ SEED：HP ≤ 70% → 也打得出来")
	拉["hp"] = 拉.maxHp
	拉["战意"] = 49.0
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) != "", "③ SEED：战意 49 < 50 → 打不出来")
	拉["hp"] = 拉.maxHp * 0.7
	拉["本回合无视觉醒战意门槛"] = true
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) == "", "③ 战意门槛被【觉醒连锁 / 背水】豁免 → 打得出来")
	拉.erase("本回合无视觉醒战意门槛")
	拉["战意"] = 0.0
	拉["本回合强制觉醒"] = true
	t.ok(DeckFlow.大招不可打原因(场, 拉, 槽) == "" and ColonialAwaken.实际费用(拉, 槽.卡) == 0.0,
		"③ 【强制觉醒】无视 HP / 回合 / 战意 / 冷却，且费用 0")

	var 希 := _单位("W1", "ally", 1.0, "狙击")
	_装入场(希, "W1")
	希["hp"] = 希.maxHp * 0.3
	t.ok(ColonialAwaken.入场门原因(场, 希, ColonialAwaken.入场槽(希, "ZERO").卡) != "",
		"③ ZERO：HP 正好 30% → 开不出来（亮起条件要 HP > 30%）")
	希["hp"] = 希.maxHp * 0.31
	t.ok(ColonialAwaken.入场门原因(场, 希, ColonialAwaken.入场槽(希, "ZERO").卡) == "", "③ ZERO：HP 31% → 打得出来")

# ==========================================================================================
# ④ SEED 开启与数值钩子
# ==========================================================================================
func _段4_SEED与数值钩子(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 靶 := _靶("靶1", 0.0)
	var 场 := _场([拉], [靶])
	_装入场(拉, "S1")
	场["turn"] = 3.0
	var 前 := Btl.战意(拉)
	var 果 := DeckFlow.打出大招(场, "S1", "COL_S1_ULT_SEED", null)
	t.ok(J.truthy(果.get("成功")) and 拉.get("觉醒中") == true and 拉.get("觉醒类型") == "SEED",
		"④ 打出 SEED·爆裂 → `觉醒中 = true` / `觉醒类型 = SEED`")
	t.ok(J.num0(拉.get("战意")) == 前 - 10.0, "④ 付出 10 费（%s → %s）" % [J.s(前), J.s(拉.get("战意"))])
	t.ok(场.get("本场有人觉醒过") == true, "④ `本场有人觉醒过` = true")
	t.ok(J.truthy(ColonialAwaken.入场槽(拉, "SEED").get("已移出")), "④ SEED 入场牌打出后本场移出大招槽")
	t.ok(DeckFlow.打出大招(场, "S1", "COL_S1_ULT_SEED", null).get("成功") == false, "④ 同一张 SEED 打不出第二次")
	t.ok(ColonialAwaken.是SEED中(拉), "④ `是SEED中` = true")
	var w := _武(1000.0, 1)
	t.ok(ColonialV01.命中修正(拉, 靶, w, 场) == 15.0, "④ SEED：命中 +15（命中修正 = %s）" % J.s(ColonialV01.命中修正(拉, 靶, w, 场)))
	t.ok(ColonialV01.闪避加成(拉, 场) == 15.0, "④ SEED：闪避 +15")

	var 希 := _单位("W1", "ally", 1.0, "狙击")
	_装入场(希, "W1")
	DeckFlow.打出大招(_场([希], [_靶("靶1", 0.0)]), "W1", "COL_W1_ULT_ZERO", null)
	t.ok(ColonialAwaken.是ZERO中(希), "④ ZERO 开得起来（战意 100 ≥ 40、HP 满）")
	var 希场 := _场([希], [靶])
	t.ok(ColonialV01.命中修正(希, 靶, w, 希场) == 20.0 and ColonialV01.闪避加成(希, 希场) == 20.0,
		"④ ZERO：命中 / 闪避 +20")
	t.ok(absf(Calc.critMul(希) - 2.5) < 0.001, "④ ZERO：暴击伤害倍率 ×2.5（critMul = %s）" % J.s(Calc.critMul(希)))

# ==========================================================================================
# ⑤ QTE 三档
# ==========================================================================================
func _段5_QTE三档(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 靶 := _靶("靶1", 0.0)
	var 场 := _场([拉], [靶])
	var 卡 := {"id": "T", "名": "测试大招", "武器牌": true}
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡, "miss") == "miss", "⑤ 指定失手 → miss")
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡, "good") == "good", "⑤ 指定成功 → good")
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡, "perfect") == "perfect", "⑤ 指定完美 → perfect")
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡) == "good", "⑤ 没指定（手动选择模式的默认）→ 成功，且不掷随机数")
	场["选项"] = {"QTE结果": "miss"}
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡) == "miss", "⑤ 设置项「QTE 结果 = 固定失手」→ miss")
	场.erase("选项")
	拉["觉醒中"] = true
	拉["觉醒类型"] = "SEED"
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡, "miss") == "good", "⑤ SEED 中：QTE 失手自动视为成功")
	拉["本回合极限超频"] = true
	t.ok(ColonialAwaken.取QTE结果(场, 拉, 卡, "miss") == "perfect", "⑤ 【极限超频】：QTE 视为完美")
	拉.erase("本回合极限超频")
	拉["觉醒中"] = false
	拉["觉醒类型"] = ""

	# 加成数值：成功 = 每段命中 +10 / 伤害 +10%；完美 = +20 / +25% / 闪避 +20
	ColonialAwaken.开QTE(场, 拉, "good")
	var w := _武(1000.0, 3)
	t.ok(ColonialV01.命中修正(拉, 靶, w, 场) == 10.0, "⑤ 成功：每段命中 +10")
	t.ok(absf(ColonialV01.攻方伤害倍率(场, 拉, 靶, w) - 1.1) < 0.0001, "⑤ 成功：伤害 ×1.10")
	ColonialAwaken.清QTE(场)
	ColonialAwaken.开QTE(场, 拉, "perfect")
	t.ok(ColonialV01.命中修正(拉, 靶, w, 场) == 20.0 and absf(ColonialV01.攻方伤害倍率(场, 拉, 靶, w) - 1.25) < 0.0001,
		"⑤ 完美：每段命中 +20、伤害 ×1.25")
	t.ok(J.num0(拉.get("QTE闪避加")) == 20.0 and ColonialV01.闪避加成(拉, 场) >= 20.0, "⑤ 完美：打出者闪避 +20（到下个我方阶段前）")
	ColonialAwaken.清QTE(场)
	ColonialAwaken.开QTE(场, 拉, "miss")
	t.ok(ColonialV01.命中修正(拉, 靶, w, 场) == 0.0 and absf(ColonialV01.攻方伤害倍率(场, 拉, 靶, w) - 1.0) < 0.0001,
		"⑤ 失手：没有加成")
	ColonialAwaken.清QTE(场)
	# 伤害真的进结算：成功 1000 威力 1 段 → 1.1 倍
	var 靶2 := _靶("靶2", 1.0)
	var 场2 := _场([拉], [靶2])
	ColonialAwaken.开QTE(场2, 拉, "good")
	Btl._执行武器攻击(场2, 拉, {"t": 双(w, 1000.0), "cd": 0.0, "uses": null}, 靶2.key)
	ColonialAwaken.清QTE(场2)
	t.ok(J.num0(靶2.maxHp) - J.num0(靶2.hp) >= 1100.0, "⑤ 成功档真的把伤害抬到 1100（实受 %s）" % J.s(千 - J.num0(靶2.hp)))

# ==========================================================================================
# ⑥ 【觉醒感应】
# ==========================================================================================
func _段6_觉醒感应(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 卡 := _单位("S2", "ally", 1.0, "指挥")
	var 场 := _场([拉, 卡], [_靶("靶1", 0.0)])
	ColonialDeck.初始化(场)
	场["公有手牌"] = []
	var 歌声 := _手牌(场, "COL_FAC_2")
	t.ok(not 歌声.is_empty(), "⑥ 歌声进了公有手牌")
	var 库前 := SubDeck.牌们(场.感应牌库).size()
	var 果 := BattleCardExec.打出精神或公有牌(场, "S2", 歌声.id, "S1")
	t.ok(J.truthy(果.get("成功")), "⑥ 卡嘉莉（永远不觉醒）打出带【觉醒感应】的歌声：打出成功")
	t.ok(场.公有手牌.size() == 1 and SubDeck.牌们(场.感应牌库).size() == 库前 - 1,
		"⑥ 未觉醒成员打【觉醒感应】→ 抽 1 张（手牌 %d，库 %d → %d）" % [场.公有手牌.size(),
			库前, SubDeck.牌们(场.感应牌库).size()])
	# 觉醒中的成员打 → 不抽
	拉["觉醒中"] = true
	拉["觉醒类型"] = "SEED"
	var 歌声2 := _手牌(场, "COL_FAC_2")
	var 库前2 := SubDeck.牌们(场.感应牌库).size()
	var 手前: int = (场["公有手牌"] as Array).size()
	BattleCardExec.打出精神或公有牌(场, "S1", 歌声2.id, "S1")
	t.ok(场.公有手牌.size() == 手前 - 1 and SubDeck.牌们(场.感应牌库).size() == 库前2,
		"⑥ 觉醒中的成员打【觉醒感应】→ 不抽（牌打出去 −1，库一张没少）")
	# 满 6 张不抽，「放入」照常
	场["公有手牌"] = []
	for i in 6:
		场.公有手牌.append({"id": "FILL%d" % i, "名": "垫%d" % i, "卡类": "公有牌"})
	var 库前3 := SubDeck.牌们(场.感应牌库).size()
	ColonialDeck.触发觉醒感应(场, 卡, _牌("COL_FAC_7"))
	t.ok(场.公有手牌.size() == 6 and SubDeck.牌们(场.感应牌库).size() == 库前3 + 1,
		"⑥ 公有手牌满 6 张 → 不抽（手牌还是 6 张；只多了「放入」的那一张）")
	t.ok(J.some(SubDeck.牌们(场.感应牌库), func(c): return str(c.get("id")) == "COL_SD2_FORESIGHT"),
		"⑥ 满手时「放入 X」仍然生效：零的预见进了感应牌库")

# ==========================================================================================
# ⑦ 感应牌库：放入断路器 / 回库 / 移出
# ==========================================================================================
func _段7_感应牌库(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 场 := _场([拉], [_靶("靶1", 0.0)])
	ColonialDeck.初始化(场)
	t.ok(ColonialDeck.放入感应牌(场, "COL_SD2_CHAIN"), "⑦ 第一次放入二级「觉醒连锁」→ 成功")
	var 库前 := SubDeck.牌们(场.感应牌库).size()
	t.ok(ColonialDeck.放入感应牌(场, "COL_SD3_FORCE"), "⑦ 第一次放入三级「强制觉醒」→ 成功")
	t.ok(SubDeck.牌们(场.感应牌库).size() == 库前 + 1, "⑦ 放入后库里多 1 张（%d → %d）" % [库前, SubDeck.牌们(场.感应牌库).size()])
	t.ok(ColonialDeck.放入感应牌(场, "COL_SD3_FORCE") == false, "⑦ 三级牌第二次放入被拦住（断路器 1）")
	t.ok(SubDeck.牌们(场.感应牌库).size() == 库前 + 1, "⑦ 被拦住时库张数不变")

	# 打出一级感应牌 → 回库
	var 推进 := _感应到手(场, "COL_SD1_PROP")
	var 库数 := SubDeck.牌们(场.感应牌库).size()
	BattleCardExec.打出精神或公有牌(场, "S1", 推进.id, "S1")
	t.ok(SubDeck.牌们(场.感应牌库).size() == 库数 + 1, "⑦ 一级感应牌打出后回库（库 +1）")
	# 打出三级感应牌 → 移出本场
	var 强制 := _感应到手(场, "COL_SD3_FORCE")
	var 前移: int = (场["感应移出"] as Array).size()
	BattleCardExec.打出精神或公有牌(场, "S1", 强制.id, "S1")
	t.ok(场.感应移出.size() == 前移 + 1, "⑦ 三级感应牌打出后移出本场（移出表 +1）")

# ==========================================================================================
# ⑧ 9 张势力牌：能打 / 数值
# ==========================================================================================
func _段8_势力牌(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 卡 := _单位("S2", "ally", 1.0, "指挥")
	var 靶 := _靶("靶1", 0.0)
	var 场 := _场([拉, 卡], [靶])
	ColonialDeck.初始化(场)
	场["公有手牌"] = []
	场["公有弃牌堆"] = []
	拉["觉醒中"] = true
	拉["觉醒类型"] = "SEED"
	for c in ColonialDeck.势力牌们():
		场.公有手牌.append(Btl.克隆战术牌(c, 场))
	var 打不了: Array = []
	for c in 场.公有手牌.duplicate():
		var 因 := CardPlay.不可打原因(场, 卡, c, CardPlay.区_公有)
		if 因 != "":
			打不了.append("%s（%s）" % [str(c.get("名")), 因])
	t.ok(打不了.is_empty(), "⑧ 9 张势力牌在条件满足时都打得出来%s" % ("" if 打不了.is_empty() else "：" + "、".join(打不了)))
	# 歌声：指定成员战意 +10
	拉["战意"] = 50.0
	var 前 := Btl.战意(拉)
	BattleCardExec.打出精神或公有牌(场, "S2", "COL_FAC_2", "S1")
	t.ok(J.num0(拉.get("战意")) == 前 + 10.0, "⑧ 歌声：指定成员战意 +10（%s → %s）" % [J.s(前), J.s(拉.get("战意"))])
	# 正规军掩护：只给觉醒中成员、打出者必须没觉醒
	t.ok(CardPlay.不可打原因(场, 拉, _牌("COL_FAC_4"), CardPlay.区_公有) != "",
		"⑧ 正规军掩护：觉醒中的成员打不出来")
	var 果 := BattleCardExec.打出精神或公有牌(场, "S2", "COL_FAC_4", "S1")
	t.ok(J.truthy(果.get("成功")) and 拉.get("正规军掩护") is Dictionary, "⑧ 正规军掩护：没觉醒的卡嘉莉替觉醒中的拉克丝挡下 30%")
	var w := _武(1000.0, 1)
	t.ok(absf(ColonialV01.受方伤害倍率(场, 靶, 拉, w) - 0.7) < 0.0001, "⑧ 受方伤害倍率 ×0.7（−30%）")
	var 护前 := float(卡.get("hp"))
	ColonialV01.受击后(场, 拉, 靶, {"字段": {"伤害": 700.0}}, w)
	t.ok(float(卡.get("hp")) == 护前 - 300.0, "⑧ 受击后把减掉的 30% 转给打出者（卡嘉莉 −300）")
	# 不杀：会打死的那一下改为保留 1 HP
	var 靶3 := _靶("靶3", 2.0)
	靶3["hp"] = 100.0
	卡["本回合不杀"] = true
	靶3["hp"] = 0.0
	ColonialV01.致命保留_后(场, 卡, 靶3)
	t.ok(float(靶3.get("hp")) == 1.0 and J.truthy(靶3.get("下阶段不能攻击")),
		"⑧ 不杀：保留 1 HP，且下个敌方阶段不能攻击")
	t.ok(not J.truthy(卡.get("本回合不杀")), "⑧ 不杀用完即清")

# ==========================================================================================
# ⑨ 隐身：目标排除 / AI 跳过 / 破隐
# ==========================================================================================
func _段9_隐身(t) -> void:
	var 迪 := _单位("W2", "ally", 0.0, "近卫")
	var 卡 := _单位("S2", "ally", 1.0, "指挥")
	var 场 := _场([迪, 卡], [_靶("靶1", 0.0)])
	_装入场(迪, "W2")
	DeckFlow.打出大招(场, "W2", "COL_W2_ULT_STEALTH", null)
	t.ok(ColonialAwaken.是隐身中(迪), "⑨ 迪奥进入隐身")
	var w := _武(1000.0, 1)
	var 结 := ColonialV01.可选目标(场, null, 迪, w)
	t.ok(bool(结.get("终局")) and bool(结.get("可选")) == false, "⑨ 还有其他队友存活 → 敌方单体选不中迪奥")
	卡["hp"] = 0.0
	var 结2 := ColonialV01.可选目标(场, null, 迪, w)
	t.ok(bool(结2.get("终局")) == false or bool(结2.get("可选")) == true, "⑨ 只剩迪奥一个人 → 可以被选中（默认规则 1）")
	t.ok(bool(ColonialV01.AI自动出牌跳过(场, 迪).get("终局")), "⑨ 结束回合时 AI 跳过隐身中的迪奥")
	# 范围攻击照打
	var 面 := {"name": "范围", "fire": "map", "dmgType": "物理", "power": 100.0, "hit": 100.0, "stat": "射击", "area": "row"}
	t.ok(not bool(ColonialV01.可选目标(场, null, 迪, 面).get("终局")), "⑨ 范围攻击不受隐身影响")
	# 打出武器牌破隐
	var 武卡 := {"id": "T_W", "名": "光束镰刀", "卡类": "主武器卡", "武器牌": true}
	ColonialV01.牌打出后(场, 迪, 武卡, CardPlay.区_主武器)
	t.ok(not ColonialAwaken.是隐身中(迪), "⑨ 打出武器牌 → 破隐")
	var 槽 := ColonialAwaken.入场槽(迪, "隐身")
	t.ok(float(槽.get("cd")) == 2.0, "⑨ 破隐后入场牌冷却 2（实际 %s）" % J.s(槽.get("cd")))
	# 精神牌不破隐
	迪["觉醒中"] = true
	迪["觉醒类型"] = "隐身"
	ColonialV01.牌打出后(场, 迪, {"id": "T_S", "名": "精神", "卡类": "专属精神牌"}, CardPlay.区_精神)
	t.ok(ColonialAwaken.是隐身中(迪), "⑨ 打精神牌 / 公有牌不破隐")

# ==========================================================================================
# ⑩ ZERO 阶段初：精神负担与系统拒绝
# ==========================================================================================
func _段10_ZERO阶段初(t) -> void:
	var 希 := _单位("W1", "ally", 0.0, "狙击")
	var 场 := _场([希], [_靶("靶1", 0.0)])
	_装入场(希, "W1")
	DeckFlow.打出大招(场, "W1", "COL_W1_ULT_ZERO", null)
	var 满 := float(希.get("maxHp"))
	希["hp"] = 满
	ColonialV01.我方阶段初_后(场)
	t.ok(float(希.get("hp")) == 满 - J.round(满 * 0.10), "⑩ ZERO 每个我方阶段初扣最大 HP 的 10%%（%s → %s）"
		% [J.s(满), J.s(希.get("hp"))])
	希["hp"] = 满 * 0.35
	ColonialV01.我方阶段初_后(场)
	t.ok(not ColonialAwaken.是ZERO中(希), "⑩ 扣到 HP ≤ 30% → 当场被系统拒绝退出 ZERO")
	t.ok(float(ColonialAwaken.入场槽(希, "ZERO").get("cd")) == 3.0, "⑩ 退醒后入场牌冷却 3")
	# 受击后也要检查
	var 希2 := _单位("W1", "ally", 1.0, "狙击")
	var 场2 := _场([希2], [_靶("靶2", 0.0)])
	_装入场(希2, "W1")
	DeckFlow.打出大招(场2, "W1", "COL_W1_ULT_ZERO", null)
	希2["hp"] = 希2.maxHp * 0.29
	ColonialV01.受击后(场2, 希2, _靶("靶3", 2.0), {"字段": {"伤害": 0.0}}, _武(1.0, 1))
	t.ok(not ColonialAwaken.是ZERO中(希2), "⑩ HP 掉到 30% 以下（受击后）→ 立即退醒")

# ==========================================================================================
# ⑪ 同种子：感应牌库抽取序列逐字一致
# ==========================================================================================
func _段11_同种子确定性(t) -> void:
	t.ok(_抽序列(7) == _抽序列(7), "⑪ 同一个种子连抽 5 张 → 序列逐字相同")
	t.ok(_抽序列(7) != _抽序列(8), "⑪ 换种子 → 序列不同（确实用 rng 抽的）")

func _抽序列(种子号: int) -> Array:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 场 := _场([拉], [_靶("靶1", 0.0)], 种子号)
	ColonialDeck.初始化(场)
	var 出: Array = []
	for i in 5:
		var c := ColonialDeck.抽感应牌(场)
		if c.is_empty():
			break
		出.append(str(c.get("id")))
	return 出

# ==========================================================================================
# 辅助
# ==========================================================================================
func _单位(键: String, side: String, 位: float, 职业: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 30.0,
		"maxHp": 3000.0, "hp": 3000.0,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"战斗分类": 职业, "势力": "殖民卫星军"}, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _靶(键: String, 位: float) -> Dictionary:
	var e := _单位(键, "enemy", 位, "")
	e["tags"] = {}
	e["hp"] = 千
	e["maxHp"] = 千
	return e

func _场(我方: Array, 敌方: Array, 种子号: int = 20261018) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": float(种子号), "rng": Mulberry32.new(种子号),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	ColonialDeck.初始化(c)
	return c

func _找(ctx: Dictionary, 键: String) -> Variant:
	for u in ctx.get("allies", []):
		if u is Dictionary and str(u.get("key", "")) == 键:
			return u
	return null

func _槽有(u: Variant, id: String) -> bool:
	if not (u is Dictionary):
		return false
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if 槽 is Dictionary and str(((槽.get("卡") if 槽.get("卡") is Dictionary else {}) as Dictionary).get("id", "")) == id:
			return true
	return false

func _装入场(u: Dictionary, 键: String) -> void:
	var 卡 := ColonialV01.入场牌(键)
	if 卡.is_empty():
		return
	if not (u.get("大招槽") is Array):
		u["大招槽"] = []
	u.大招槽.append(ColonialV01._槽(卡))

func _武(威力: float, 段数: int, 命中率: float = 100.0, fire: String = "direct") -> Dictionary:
	return {"name": "测试武器", "fire": fire, "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

func 双(w: Dictionary, 威力: float) -> Dictionary:
	var d := w.duplicate(true)
	d["power"] = 威力
	return d

func _牌(id: String) -> Dictionary:
	for c in ColonialDeck.势力牌们() + ColonialDeck.感应牌们():
		if str(c.get("id")) == id:
			return c
	return {}

## 往公有手牌里塞指定 id 的那张牌（返回塞进去的实例）。
func _手牌(场: Dictionary, id: String) -> Dictionary:
	var 卡 := _牌(id)
	if 卡.is_empty():
		return {}
	var 例: Dictionary = Btl.克隆战术牌(卡, 场)
	(场["公有手牌"] as Array).append(例)
	return 例

## 从感应牌库直接拿一张同 id 的实例到公有手牌（模拟玩家抽到了它）。
func _感应到手(场: Dictionary, id: String) -> Dictionary:
	for c in SubDeck.牌们(场.get("感应牌库")):
		if c is Dictionary and str(c.get("id")) == id:
			(场["公有手牌"] as Array).append(c)
			return c
	var 卡 := ColonialDeck.感应牌(id)
	if 卡.is_empty():
		return {}
	(场["公有手牌"] as Array).append(卡)
	return 卡
