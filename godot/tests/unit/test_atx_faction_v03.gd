## ★ A6d 验收：① 新旧同名卡退场（7 张旧卡一张都不进牌池）；② 势力牌 9 张按 v0.3 重写；
##   ③ 合体技【轮盘双响】按 v0.3。
##
## 权威依据（数值一个都不许改）：
##   · `协作/设计/ATX势力卡牌设计 v0.3.md` §5（9 张势力牌）· §4（轮盘双响）· §1（九死一生 / 赌局）
##   · 同文件 §2（筹码牌库 / 大满贯）
##
## 受控单位：攻击方 `aim = 160`、目标 `eva = 0` → 命中率 = 武器 `hit`，
##   所以「必闪 +20 / 加注 −15 / 读牌 +15 / 止损 +15」这类修正都能贴两个精确百分比。
## 本文件跑完把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_新旧同名卡(t)
	_段2_Lv10牌库组成(t)
	_段3_九张势力牌(t)
	_段4_必闪(t)
	_段5_诱敌(t)
	_段6_读牌(t)
	_段7_加注(t)
	_段8_止损(t)
	_段9_二次下注(t)
	_段10_幸运连号(t)
	_段11_上头(t)
	_段12_轮盘双响进入条件(t)
	_段13_轮盘双响补段(t)
	_段14_轮盘双响赌局(t)
	_段15_轮盘双响收尾(t)
	_段17_同种子两遍(t)

# ==========================================================================================
# ① 新旧同名卡：v0.1 在、v0.2 同名旧卡不在；按名字取只拿到 v0.1
# ==========================================================================================
func _段1_新旧同名卡(t) -> void:
	var c := _队伍ctx(["A1", "A2", "A3"], 10)
	var 池: Array = []
	for u in c.allies:
		for x in _单位全牌(u):
			池.append(x)
	var ids: Array = 池.map(func(x): return str(x.get("id")))
	t.ok(J.inc(ids, "ATX1_U1") and J.inc(ids, "ATX2_W1") and J.inc(ids, "ATX3_W1"),
		"① v0.1 新卡在牌池里（左轮打桩机·全弹 / 嚎叫发射器 / 幻影弓 都在：%d 张）" % 池.size())
	t.ok(FacAtx.有("U_ATX_1") and AtxThree.有("ATX1_U1") and AtxThree.有("ATX2_U2") and AtxThree.有("ATX3_U2"),
		"① 新旧两张都还在**卡表**里（旧卡只是不进牌池：U_ATX_1 / ATX1_U1 同一个名字）")
	var 旧们 := ["U_ATX_1", "U_ATX_3", "U_ATX_4", "U_ATX_5", "U_ATX_6", "U_ATX_7", "U_ATX_9"]
	var 混进: Array = 旧们.filter(func(x): return J.inc(ids, x))
	t.ok(混进.is_empty(), "① ★ v0.2 **同名旧卡 7 张一张都没进牌池**（混进：%s）" % str(混进))
	t.ok(J.inc(ids, "U_ATX_2") and J.inc(ids, "U_ATX_8"),
		"① 不复用的两张 v0.2 牌仍在（U_ATX_2 赌神·入局 / U_ATX_8 烟雾弹 —— 不是同名卡，不退场）")
	# 按**名字**取：只可能拿到 v0.1 版
	var 名卡 := FacAtx.按名取("左轮打桩机·全弹")
	t.ok(str(名卡.get("id")) == "ATX1_U1",
		"① ★ 按名字取【左轮打桩机·全弹】只拿到 v0.1 版（%s / id %s）" % [str(名卡.get("名")), str(名卡.get("id"))])
	var id卡 := FacAtx.按id取("ATX1_U1")
	t.ok(str(id卡.get("id")) == "ATX1_U1" and str(id卡.get("名")) == "左轮打桩机·全弹",
		"① 按 id 取 ATX1_U1 = 【左轮打桩机·全弹】（v0.1）")
	t.ok(FacAtx.按id取("U_ATX_1").is_empty(),
		"① 旧 id `U_ATX_1` 在主开关开着时**取不到**（旧版不出现）")
	t.ok(str(FacAtx.按名取("烟雾弹").get("id")) == "U_ATX_8",
		"① 按名字取【烟雾弹】= U_ATX_8（v0.1 卡表复用的就是它，不算旧版）")
	var 名数 := {}
	for x in 池:
		var n := str(x.get("名"))
		名数[n] = int(名数.get(n, 0)) + 1
	var 重名: Array = 名数.keys().filter(func(k): return int(名数[k]) > 1)
	t.ok(重名.is_empty(), "① 牌池里**同名牌 0 张**（重名：%s）—— 按名字取牌不再有歧义" % str(重名))

# ==========================================================================================
# ② Lv10 实际牌库张数与名单（逐张硬对）—— 对应 `test_unit_deck_system` 的 ⑭ 新组成
# ==========================================================================================
func _段2_Lv10牌库组成(t) -> void:
	var c := _队伍ctx(["A1", "A2", "A3"], 10)
	var 望 := {
		"A1": ["ATX1_S1", "ATX1_S2", "ATX1_S3", "ATX1_S4", "ATX1_U1", "ATX1_W1", "ATX1_W2", "ATX1_W3", "U_ATX_2"],
		"A2": ["ATX2_D1", "ATX2_S1", "ATX2_S2", "ATX2_S3", "ATX2_S4", "ATX2_U1", "ATX2_W1", "ATX2_W2",
			"ATX2_W3", "U_ATX_COMBO"],
		"A3": ["ATX3_S1", "ATX3_S2", "ATX3_S5", "ATX3_U1", "ATX3_W1", "ATX3_W2", "ATX3_W3", "ATX_RW_MANXIAN",
			"U_ATX_8"],
	}
	for u in c.allies:
		var 实: Array = _单位全牌(u).map(func(x): return str(x.get("id")))
		实.sort()
		var 期: Array = (望[str((u as Dictionary).get("key"))] as Array).duplicate()
		期.sort()
		t.ok(实 == 期, "② Lv10 %s 专属牌 **%d 张**逐张硬对：%s" % [str(u.get("key")), 实.size(), str(实)])

func _单位全牌(u: Dictionary) -> Array:
	var 全: Array = []
	var 已 := {}
	var 候选: Array = []
	for k in ["专属牌库", "专属手牌", "专属弃牌堆", "武器栏", "待入库"]:
		候选.append_array(J.or_(u.get(k), []))
	for k in ["副武器栏", "大招槽"]:
		for e in J.or_(u.get(k), []):
			if e is Dictionary and e.get("卡") is Dictionary:
				候选.append(e.get("卡"))
	for x in 候选:
		if not (x is Dictionary):
			continue
		var id := str(x.get("id", ""))
		if id == FacAtx.合体技ID and str(u.get("key", "")) != "A2":
			continue
		if not 已.has(id) and (FacAtx.有(id) or AtxThree.有(id)):
			已[id] = true
			全.append(x)
	return 全

# ==========================================================================================
# ③ 9 张势力牌：注册成功 / 非 ATX 成员打不出来 / ATX 成员能打且扣自己战意
# ==========================================================================================
func _段3_九张势力牌(t) -> void:
	var 们 := FacAtx.势力牌们()
	var 名们: Array = 们.map(func(x): return str(x.get("名")))
	var 费们: Array = 们.map(func(x): return int(float(x.get("耗气"))))
	t.ok(们.size() == 9 and 名们 == ["「又是送死的任务」", "必闪", "诱敌", "加注", "止损", "读牌",
		"二次下注", "幸运连号", "「上头又想让我们去死」"],
		"③ 9 张势力牌名逐张对稿：%s" % str(名们))
	t.ok(费们 == [0, 10, 5, 5, 0, 10, 10, 0, 15],
		"③ 费用逐张对稿（0 / 10 / 5 / 5 / 0 / 10 / 10 / 0 / 15）：%s" % str(费们))
	var 赌局们: Array = 们.filter(func(x): return J.truthy(x.get("赌局"))).map(func(x): return str(x.get("名")))
	t.ok(赌局们 == ["诱敌", "二次下注", "幸运连号"],
		"③ 带【赌局】的正好 3 张（★ 诱敌 / ★ 二次下注 / ★ 幸运连号）：%s" % str(赌局们))
	t.ok(J.every(们, func(x): return FacAtx.是公有牌(x) and str(x.get("归属")) == "ATX"),
		"③ 9 张全部 `卡类 = 公有牌` / `归属 = ATX`（公有排）")

	# 非 ATX 成员打不出来（贴失败原因）
	var c1 := _场([_单位("B1", "ally", 0.0), _友(1.0, "A1")], [_靶(0.0)])
	c1.allies[0]["tags"] = {"势力": "影世界", "战斗分类": "近卫"}
	c1.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.必闪), c1))
	var r否 := Btl.打出精神或公有牌(c1, "B1", AtxFaction.必闪)
	t.ok(r否.get("成功") == false and str(r否.get("原因", "")).contains("只有 ATX 成员能打"),
		"③ 非 ATX 成员（影世界 B1）打【必闪】→ 失败：%s" % str(r否.get("原因", "")))
	# ATX 成员能打，且扣**自己**的战意
	var c2 := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_靶(0.0)])
	var a1 = c2.allies[0]
	var a2 = c2.allies[1]
	a1["战意"] = 100.0
	a2["战意"] = 100.0
	c2.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.送死), c2))
	var r送 := Btl.打出精神或公有牌(c2, a1.key, AtxFaction.送死)
	t.ok(r送.get("成功") == true and float(a1.get("战意")) == 100.0,
		"③ ATX 成员打【又是送死的任务】（0 费）成功，战意仍 100（%s）" % str(r送.get("原因", "")))
	c2.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.必闪), c2))
	var r必 := Btl.打出精神或公有牌(c2, a1.key, AtxFaction.必闪)
	t.ok(r必.get("成功") == true and float(a1.get("战意")) == 90.0 and float(a2.get("战意")) == 100.0,
		"③ 【必闪】10 费：**打出者自己**扣（A1 100 → %s；A2 一分不动 = %s）" % [a1.get("战意"), a2.get("战意")])

# ==========================================================================================
# ④ 必闪：ATX 全体闪避 +20 真的进公式 / 代价「本回合 ATX 伤害 −20%」真的生效
# ==========================================================================================
func _段4_必闪(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	var 敌 = c.enemies[0]
	var 枪 := _武(500.0, 1, 80.0)
	var 前命中 := int(Calc.hitRate(敌, 枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	var 前伤害 := J.round(float(Calc.dmgCore(a1, _武(1000.0, 1, 100.0), 敌,
		{"power": 1000.0, "ctx": c}).dmg))
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.必闪), c))
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.必闪)
	t.ok(r.get("成功") == true, "④ 打出【必闪】成功（%s）" % str(r.get("原因", "")))
	var 后命中 := int(Calc.hitRate(敌, 枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(前命中 - 后命中 == 20, "④ 敌方打 A1 的每段命中率 %d%% → %d%%（ATX 全体闪避 +20 真的进 `hitRate`）" % [前命中, 后命中])
	var 后命中2 := int(Calc.hitRate(敌, 枪, c.allies[1], {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(后命中2 == 后命中, "④ ATX **全体**都吃到（A2 也是 %d%%）" % 后命中2)
	var 倍 := Params.战术卡牌伤害倍率(a1, _武(1000.0, 1, 100.0))
	var 后伤害 := J.round(float(Calc.dmgCore(a1, _武(1000.0, 1, 100.0), 敌, {"power": 1000.0, "ctx": c}).dmg))
	t.ok(absf(倍 - 0.8) < 0.0001 and 后伤害 == J.round(前伤害 * 0.8),
		"④ 代价生效：ATX 伤害倍率 %s；同一发 %d → %d（×0.8）" % [J.s(倍), 前伤害, 后伤害])

# ==========================================================================================
# ⑤ ★ 诱敌：预告同源（`算意图` 预告目标 == 实际挨打目标；生效 / 不生效 两局面）
# ==========================================================================================
func _段5_诱敌(t) -> void:
	# ---- 局面 A：不生效（场上没有诱敌）→ 预告 == 实际 ----
	var a := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	a["阶段"] = Btl.阶段_我方主
	var 预A := _预告(a)
	var 实A := _打一个敌方阶段(a)
	t.ok(预A != "" and 预A == 实A,
		"⑤ 不生效局面（没有诱敌）：`算意图` 预告 %s == 实际挨打 %s" % [预A, 实A])
	# ---- 局面 B：生效（A2 亮着诱敌）→ 预告 == 实际 == A2 ----
	var b := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var b1 = b.allies[0]
	var b2 = b.allies[1]
	b1["战意"] = 100.0
	b["公有手牌"].append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.诱敌), b))
	var r诱 := Btl.打出精神或公有牌(b, b1.key, AtxFaction.诱敌, b2.key)
	t.ok(r诱.get("成功") == true and str(AtxFaction.诱敌预告(b)) == str(b2.get("key")),
		"⑤ 打出【诱敌】指定 A2 → `诱敌预告` = %s（%s）" % [str(AtxFaction.诱敌预告(b)), str(r诱.get("原因", ""))])
	b["阶段"] = Btl.阶段_我方主
	var 预B := _预告(b)
	var 实B := _打一个敌方阶段(b)
	t.ok(预B == str(b2.get("key")) and 预B == 实B,
		"⑤ 生效局面：`算意图` 预告 %s == 实际挨打 %s == 诱敌者 A2（同源，R4）" % [预B, 实B])

# ==========================================================================================
# ⑥ ★ 读牌：显示的目标 == 实际目标；被选中的成员闪避 +15
# ==========================================================================================
func _段6_读牌(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	c["turn"] = 2.0
	var 枪 := _武(500.0, 1, 80.0)
	var 前 := int(Calc.hitRate(c.enemies[0], 枪, c.allies[0], {"baseHit": 80.0, "ctx": c}).hit)
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.读牌), c))
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.读牌)
	t.ok(r.get("成功") == true, "⑥ 打出【读牌】成功（%s）" % str(r.get("原因", "")))
	var 表: Dictionary = c.get("ATX读牌目标") if c.get("ATX读牌目标") is Dictionary else {}
	var 显 := str(表.get(str(c.enemies[0].get("key")), ""))
	var 被瞄 = Btl.找单位(c, 显, "ally")
	t.ok(显 != "" and 被瞄 is Dictionary, "⑥ 读牌显示：%s → %s" % [str(c.enemies[0].get("name")), 显])
	var 后 := int(Calc.hitRate(c.enemies[0], 枪, 被瞄, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(前 - 后 == 15, "⑥ 被选中的成员闪避 +15：命中率 %d%% → %d%%" % [前, 后])
	c["阶段"] = Btl.阶段_我方主
	var 实 := _打一个敌方阶段(c)
	t.ok(实 == 显, "⑥ 读牌显示的目标 %s == 实际挨打目标 %s（只读 `Btl.算意图`，不另算一套）" % [显, 实])

# ==========================================================================================
# ⑦ 加注：敌我**都**每段命中 −15；同回合第二次 → 失败 + 原因
# ==========================================================================================
func _段7_加注(t) -> void:
	var c := _场([_友(0.0, "A1")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	var 敌 = c.enemies[0]
	var 我枪 := _武(500.0, 1, 80.0)
	var 敌枪 := _武(500.0, 1, 80.0)
	var 我前 := int(Calc.hitRate(a1, 我枪, 敌, {"baseHit": 80.0, "ctx": c}).hit)
	var 敌前 := int(Calc.hitRate(敌, 敌枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.加注), c))
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.加注)
	t.ok(r.get("成功") == true, "⑦ 打出【加注】成功（%s）" % str(r.get("原因", "")))
	var 我后 := int(Calc.hitRate(a1, 我枪, 敌, {"baseHit": 80.0, "ctx": c}).hit)
	var 敌后 := int(Calc.hitRate(敌, 敌枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(我前 - 我后 == 15 and 敌前 - 敌后 == 15,
		"⑦ **敌我全体**每段命中 −15：我方 %d%% → %d%%、敌方 %d%% → %d%%" % [我前, 我后, 敌前, 敌后])
	var 次 := int(AtxFaction.本场计数(c).get("加注回合", 0))
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.加注), c))
	var r2 := Btl.打出精神或公有牌(c, a1.key, AtxFaction.加注)
	t.ok(r2.get("成功") == false and str(r2.get("原因", "")).contains("每回合限 1 次"),
		"⑦ 同回合第二次打【加注】→ 失败：%s（本回合加注记在回合 %d）" % [str(r2.get("原因", "")), 次])

# ==========================================================================================
# ⑧ 止损：HP 41% → 不可打；40% → 可打；战意 +15 / 闪避 +15
# ==========================================================================================
func _段8_止损(t) -> void:
	var c := _场([_友(0.0, "A1")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["maxHp"] = 1000.0
	a1["战意"] = 0.0
	a1["hp"] = 410.0
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.止损), c))
	var r否 := Btl.打出精神或公有牌(c, a1.key, AtxFaction.止损)
	t.ok(r否.get("成功") == false and str(r否.get("原因", "")).contains("40%"),
		"⑧ HP 41%% → 不可打：%s" % str(r否.get("原因", "")))
	a1["hp"] = 400.0
	var 枪 := _武(500.0, 1, 80.0)
	var 前 := int(Calc.hitRate(c.enemies[0], 枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.止损)
	t.ok(r.get("成功") == true, "⑧ HP 40%% → 可打（%s）" % str(r.get("原因", "")))
	var 后 := int(Calc.hitRate(c.enemies[0], 枪, a1, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(float(a1.get("战意")) == 15.0 and 前 - 后 == 15,
		"⑧ 该成员战意 0 → %s（+15）、闪避 +15（命中率 %d%% → %d%%）" % [a1.get("战意"), 前, 后])

# ==========================================================================================
# ⑨ ★ 二次下注：把**打空的段**重打一次、每段 50%
# ==========================================================================================
func _段9_二次下注(t) -> void:
	var c := _场([_友(0.0, "A1")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	c["turn"] = 2.0
	c.enemies[0]["eva"] = 40.0            # 命中 80 − 40 = 40% → 一定打空几段
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.二次下注), c))
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.二次下注)
	t.ok(r.get("成功") == true, "⑨ 打出【二次下注】成功（%s）" % str(r.get("原因", "")))
	a1.专属手牌.append(_给牌(a1, "ATX1_U1"))     # 左轮打桩机·全弹：12 段 × 500（命中 75）
	var r攻 := Btl.打出精神或公有牌(c, a1.key, "ATX1_U1")
	t.ok(r攻.get("成功") == true, "⑨ 打出武器牌【左轮打桩机·全弹】（%s）" % str(r攻.get("原因", "")))
	var 条 := _找日志(c, "二次下注账")
	var 打空 := int(J.num0(条.get("打空段")))
	t.ok(打空 > 0 and int(J.num0(条.get("重打段"))) == 打空,
		"⑨ 原攻击打空 **%d 段** → 重打 **%d 段**" % [打空, int(J.num0(条.get("重打段")))])
	t.ok(J.round(J.num0(条.get("重打威力"))) == 250.0,
		"⑨ 每段 50%%：500 × 50%% = **%s**（重打伤害 %s）" % [J.s(J.round(J.num0(条.get("重打威力")))),
			J.s(J.round(J.num0(条.get("重打伤害"))))])
	var 重 := _找攻击(c, "·二次下注")
	t.ok(not 重.is_empty() and int(J.num0(重.get("段数"))) == 打空,
		"⑨ 重打独立成**一条**攻击记录（一次攻击 = 一条记录，R5）：%d 段、命中 %d 段" % [
			int(J.num0(重.get("段数"))), int(J.num0(重.get("命中段数")))])
	t.ok(int(J.num0(条.get("重打命中段"))) == 打空 and J.num0(条.get("重打伤害")) > 0,
		"⑨ ★ 重打真的落下去了（不是空转）：命中 **%d/%d 段**、总伤害 **%s**（3 段 × 250 的口径）" % [
			int(J.num0(条.get("重打命中段"))), 打空, J.s(J.round(J.num0(条.get("重打伤害"))))])

# ==========================================================================================
# ⑩ ★ 幸运连号：下一张 ATX 大招费用 −10（贴扣费前后）
# ==========================================================================================
func _段10_幸运连号(t) -> void:
	var c := _场([_友(0.0, "A1")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	c["turn"] = 2.0                       # 【左轮打桩机·全弹】是「第 2 回合起」的大招
	a1["战意"] = 10.0
	var r否 := _打幸运连号(c, a1)
	t.ok(r否.get("成功") == false and str(r否.get("原因", "")).contains("大招"),
		"⑩ 本场还没打出过 ATX 大招 → 【幸运连号】打不出：%s" % str(r否.get("原因", "")))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	var r := _打幸运连号(c, a1)
	t.ok(r.get("成功") == true and int(c.get("下张ATX大招降费")) == 10,
		"⑩ 打出【幸运连号】→ 下一张 ATX 大招降费 10（%s）" % str(r.get("原因", "")))
	a1.专属手牌.append(_给牌(a1, "ATX1_U1"))     # 左轮打桩机·全弹：耗气 20
	var 前 := float(a1.get("战意"))
	var r大 := Btl.打出精神或公有牌(c, a1.key, "ATX1_U1")
	t.ok(r大.get("成功") == true and J.round(float(r大.get("费用"))) == 10.0 and int(c.get("下张ATX大招降费")) == 0,
		"⑩ 降费真的生效：耗气 **20 → 10**（战意 %s → %s），降费状态已清" % [J.s(前), J.s(a1.get("战意"))])

# ==========================================================================================
# ⑪ ★「上头又想让我们去死」：两个成员亮闪字 → 各抽 1 张；公有手牌满 6 → 不抽
# ==========================================================================================
func _段11_上头(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	c["turn"] = 3.0
	c.allies[0]["闪"] = true
	c.allies[1]["闪"] = true
	c["筹码牌库"] = AtxChips.初始筹码牌库()
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.上头), c))
	var 手前: int = c.公有手牌.size()
	var r := Btl.打出精神或公有牌(c, a1.key, AtxFaction.上头)
	t.ok(r.get("成功") == true and int(c.公有手牌.size()) == 手前 - 1 + 2,
		"⑪ 两个成员亮闪字 → **各抽 1 张（合计 2 张）**：公有手牌 %d → %d（%s）" % [
			手前, int(c.公有手牌.size()), str(r.get("原因", ""))])
	t.ok(int(AtxChips.赌局触发次数(c)) == 0 and int(c["筹码牌库"].size()) == 2,
		"⑪ 抽的是**筹码牌**（库 4 → %d 张，不算【赌局】触发）" % int(c["筹码牌库"].size()))
	# 公有手牌已满 6 → 不抽
	var d := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	d.allies[0]["战意"] = 100.0
	d["turn"] = 3.0
	d.allies[0]["闪"] = true
	d.allies[1]["闪"] = true
	d["筹码牌库"] = AtxChips.初始筹码牌库()
	d["公有手牌"] = []
	for _i in range(5):
		d.公有手牌.append(Btl.克隆战术牌(FacAtx.卡("F_ATX_V2_1"), d))
	d.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.上头), d))
	var 满前: int = d.公有手牌.size()
	var r2 := Btl.打出精神或公有牌(d, d.allies[0].key, AtxFaction.上头)
	t.ok(r2.get("成功") == true and int(d.公有手牌.size()) == 满前 - 1 and int(d["筹码牌库"].size()) == 4,
		"⑪ 公有手牌已满 6 张 → **不抽**：%d → %d、筹码牌库仍 4 张" % [满前, int(d.公有手牌.size())])

# ==========================================================================================
# ⑫ ★ 轮盘双响进入条件：只有一人打过大招 → 不可；两人都打过 → 可；费用各付 15
# ==========================================================================================
func _段12_轮盘双响进入条件(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	var a2 = c.allies[1]
	a1["战意"] = 100.0
	a2["战意"] = 100.0
	var r0 := _打合体技(c, a1)
	t.ok(r0.get("成功") == false and str(r0.get("原因", "")).contains("各打出过 1 次"),
		"⑫ 两个人都没打过大招 → 合体技打不出：%s" % str(r0.get("原因", "")))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	var r1 := _打合体技(c, a1)
	t.ok(r1.get("成功") == false and str(r1.get("原因", "")).contains("A2"),
		"⑫ **只有响介一人**打过大招 → 仍打不出：%s" % str(r1.get("原因", "")))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX2_U2"))
	var r2 := _打合体技(c, a1)
	t.ok(r2.get("成功") == true, "⑫ 两人都打过大招 → 可打（%s）" % str(r2.get("原因", "")))
	t.ok(float(a1.get("战意")) >= 85.0 and float(a2.get("战意")) >= 85.0
		and float(a1.get("战意")) <= 85.0 + Params.命中战意() * 12.0 + Params.击破战意()
		and float(a2.get("战意")) <= 85.0 + Params.命中战意() * 12.0 + Params.击破战意(),
		"⑫ **各付 15 战意**：A1 100 → %s、A2 100 → %s（各扣 15，命中回战意后不超过上界）" % [a1.get("战意"), a2.get("战意")])

# ==========================================================================================
# ⑬ ★ 轮盘双响补段：多段打空 → 补段数 ≤ 6 且补的段必暴击；总段数正确
# ==========================================================================================
func _段13_轮盘双响补段(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	var a2 = c.allies[1]
	a1["战意"] = 100.0
	a2["战意"] = 100.0
	c.enemies[0]["maxHp"] = 999999.0
	c.enemies[0]["hp"] = 999999.0
	c.enemies[0]["eva"] = 40.0                    # 先射 90−40=50% / 冲锋 75−40=35% → 必定多段打空
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX2_U2"))
	var r := _打合体技(c, a1)
	t.ok(r.get("成功") == true, "⑬ 打出【轮盘双响】（%s）" % str(r.get("原因", "")))
	var 条 := _找日志(c, "轮盘双响")
	var 先段 := int(J.num0(条.get("先射段")))
	var 冲段 := int(J.num0(条.get("冲锋段")))
	var 补 := int(J.num0(条.get("补段")))
	var 打空 := int(J.num0(条.get("打空段")))
	var 总 := int(J.num0(条.get("总段数")))
	var 暴 := int(J.num0(条.get("补段暴击")))
	t.ok(先段 == 4 and 冲段 == 8, "⑬ 先射 **%d 段** + 冲锋 **%d 段**" % [先段, 冲段])
	t.ok(打空 > 0 and 补 == mini(打空, 6) and 补 <= 6,
		"⑬ 打空 **%d 段** → 补段 **%d 段**（≤ 6，与打空段数取小）" % [打空, 补])
	t.ok(补 > 0 and 暴 == 补, "⑬ ★ 补的段**必暴击**：补 %d 段 / 暴击 **%d 段**" % [补, 暴])
	t.ok(总 == 先段 + 冲段 + 补, "⑬ 总段数 **%d** = %d + %d + 补段 %d" % [总, 先段, 冲段, 补])

# ==========================================================================================
# ⑭ ★ 轮盘双响赌局：两人**任一**亮闪字即触发 → 抽 1 张 + 「大满贯」进筹码库
# ==========================================================================================
func _段14_轮盘双响赌局(t) -> void:
	# 只有 A2 亮闪字 → 也触发
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	c.allies[0]["战意"] = 100.0
	c.allies[1]["战意"] = 100.0
	c.allies[1]["闪"] = true
	c["筹码牌库"] = AtxChips.初始筹码牌库()
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX2_U2"))
	var 手前: int = c.公有手牌.size()
	_打合体技(c, a1)
	var 库id: Array = (c["筹码牌库"] as Array).map(func(x): return str(x.get("id")))
	t.ok(int(AtxChips.赌局触发次数(c)) == 1 and int(c.公有手牌.size()) == 手前 + 1,
		"⑭ **任一**亮闪字（只有 A2 亮）→ 赌局触发 %d 次、抽 1 张（公有手牌 %d → %d）" % [
			int(AtxChips.赌局触发次数(c)), 手前, int(c.公有手牌.size())])
	t.ok(J.inc(库id, "ATX_CHIP_SLAM"),
		"⑭ 头奖「大满贯」进筹码牌库（库 %d 张：%s）" % [库id.size(), str(库id)])
	# 两人都不亮闪字 → 不触发
	var d := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	d.allies[0]["战意"] = 100.0
	d.allies[1]["战意"] = 100.0
	d["筹码牌库"] = AtxChips.初始筹码牌库()
	AtxFaction.记打出大招(d, AtxThree.卡("ATX1_U1"))
	AtxFaction.记打出大招(d, AtxThree.卡("ATX2_U2"))
	_打合体技(d, d.allies[0])
	var 库2: Array = (d["筹码牌库"] as Array).map(func(x): return str(x.get("id")))
	t.ok(int(AtxChips.赌局触发次数(d)) == 0 and not J.inc(库2, "ATX_CHIP_SLAM"),
		"⑭ 两人都**没亮闪字** → 赌局不触发（触发 0 次、库里没有大满贯）")

# ==========================================================================================
# ⑮ ★ 轮盘双响收尾：两人主武器全消 / 留在两人大招槽且 cd=5 / 任一人被击破 → 移出本场
# ==========================================================================================
func _段15_轮盘双响收尾(t) -> void:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))])
	var a1 = c.allies[0]
	var a2 = c.allies[1]
	a1["战意"] = 100.0
	a2["战意"] = 100.0
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX2_U2"))
	var r := _打合体技(c, a1)
	t.ok(r.get("成功") == true and J.truthy(a1.get("主武器已销毁")) and J.truthy(a2.get("主武器已销毁")),
		"⑮ 打出后**两人的主武器全部消掉**（A1 %s / A2 %s）" % [str(a1.get("主武器已销毁")), str(a2.get("主武器已销毁"))])
	var 槽1 := _找槽(a1, FacAtx.合体技ID)
	var 槽2 := _找槽(a2, FacAtx.合体技ID)
	t.ok(not 槽1.is_empty() and not 槽2.is_empty() and J.round(J.num0(槽1.get("cd"))) == 5
		and J.round(J.num0(槽2.get("cd"))) == 5,
		"⑮ ★ 留在**两人的大招槽**里且 cd = **5**（A1 %s / A2 %s）" % [
			J.s(J.num0(槽1.get("cd"))), J.s(J.num0(槽2.get("cd")))])
	# 任一人被击破 → 移出本场
	a2["hp"] = 0.0
	Btl.记击破(c, c.enemies[0], a2)
	var 移出id: Array = J.or_(c.get("移出牌"), []).map(func(x): return str(x.get("id")))
	t.ok(_找槽(a1, FacAtx.合体技ID).is_empty() and _找槽(a2, FacAtx.合体技ID).is_empty()
		and J.inc(移出id, FacAtx.合体技ID),
		"⑮ 艾克赛琳被击破 → 这张牌**移出本场**（两人大招槽都空了、`ctx.移出牌` 里有它：%s）" % str(移出id))

# ==========================================================================================
# ⑯ 开关关：9 张势力牌与轮盘双响均不生效、`ctx.rng` 步数与改前逐字相同
# ==========================================================================================
func _段16_开关关(t) -> void:
	var a := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))], 20261017, false)
	a["ATX大招打出人"] = {"A1": true, "A2": true}
	a.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.加注), a))
	a.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.必闪), a))
	a.allies[0].专属手牌.append(Btl.克隆战术牌(FacAtx.合体技卡(), a))
	var rng0 := int((a.get("rng") as Mulberry32).steps)
	var n0: int = a.log.size()
	var r加 := Btl.打出精神或公有牌(a, a.allies[0].key, AtxFaction.加注)
	var r必 := Btl.打出精神或公有牌(a, a.allies[0].key, AtxFaction.必闪)
	var r合 := Btl.打出主武器卡(a, a.allies[0].key, "U_ATX_COMBO")
	var rng1 := int((a.get("rng") as Mulberry32).steps)
	t.ok(r加.get("成功") == false and r必.get("成功") == false and r合.get("成功") == false,
		"⑯ 单机牌组关着 → 9 张势力牌与轮盘双响**一张都打不出来**（%s / %s / %s）" % [
			str(r加.get("原因", "")), str(r必.get("原因", "")), str(r合.get("原因", ""))])
	t.ok(rng0 == rng1 and a.log.size() == n0,
		"⑯ 开关关：`ctx.rng` 步数 **%d → %d**、记录 %d → %d 行（逐字相同）" % [rng0, rng1, n0, a.log.size()])
	var 公有 := []
	var c2 := Setup.开局([{"键": "A1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261017, null, {})
	for x in J.or_(c2.get("公有牌库"), []):
		if x is Dictionary and str(x.get("id")).begins_with("F_ATX_V2_"):
			公有.append(str(x.get("id")))
	t.ok(公有.is_empty(), "⑯ 不带 ATX v0.3 选项开一局：`ctx.公有牌库` 里 0 张 ATX v0.3 势力牌（%s）" % str(公有))

# ==========================================================================================
# ⑰ 同种子两遍逐字相同
# ==========================================================================================
func _段17_同种子两遍(t) -> void:
	var a := _整场脚本(20261017)
	var b := _整场脚本(20261017)
	t.ok(str(a.get("日志")) == str(b.get("日志")) and int(a.get("rng")) == int(b.get("rng")),
		"⑰ 同种子两遍**逐字相同**（记录 %d 行、`ctx.rng` 步数 %d）" % [int(a.get("行数")), int(a.get("rng"))])

func _整场脚本(种子: int) -> Dictionary:
	var c := _场([_友(0.0, "A1"), _友(1.0, "A2")], [_敌(0.0, _武(500.0, 1, 80.0))], 种子)
	var a1 = c.allies[0]
	a1["战意"] = 100.0
	c.allies[1]["战意"] = 100.0
	c.enemies[0]["maxHp"] = 999999.0
	c.enemies[0]["hp"] = 999999.0
	c.enemies[0]["eva"] = 40.0
	c["筹码牌库"] = AtxChips.初始筹码牌库()
	c["turn"] = 2.0
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.必闪), c))
	Btl.打出精神或公有牌(c, a1.key, AtxFaction.必闪)
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.二次下注), c))
	Btl.打出精神或公有牌(c, a1.key, AtxFaction.二次下注)
	a1.专属手牌.append(_给牌(a1, "ATX1_W1"))
	Btl.打出精神或公有牌(c, a1.key, "ATX1_W1")
	AtxFaction.记打出大招(c, AtxThree.卡("ATX1_U1"))
	AtxFaction.记打出大招(c, AtxThree.卡("ATX2_U2"))
	c.allies[0]["主武器已销毁"] = false
	c.allies[1]["主武器已销毁"] = false
	c.allies[0]["闪"] = true
	_打合体技(c, a1)
	var 行们: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			行们.append(str(e.get("文本", "")))
	return {"日志": "\n".join(行们), "rng": int((c.get("rng") as Mulberry32).steps), "行数": 行们.size()}

# ==========================================================================================
# 小工具
# ==========================================================================================
func _队伍ctx(键们: Array, 等级: int = 10) -> Dictionary:
	var 编成 := []
	for k in 键们:
		编成.append({"键": k, "位": 编成.size(), "等级": 等级})
	return Setup.开局(编成, [{"键": "fighter", "位": 0, "等级": 1}], 20261019, null, {"单机牌组": true})

func _场(我方: Array, 敌方: Array, 种子: int = 20261017, 单机: bool = true) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "串": "",
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "已放入头奖": {}, "烟雾": [], "again": [], "移出牌": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	if 单机:
		c["单机牌组"] = true
	return c

func _单位(键: String, side: String, 位: float) -> Dictionary:
	return {
		"key": 键, "name": 键, "tplKey": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [], "weapons": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"势力": "ATX"},
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _友(位: float, 键: String) -> Dictionary:
	var d := _单位(键, "ally", 位)
	d["name"] = "响介" if 键 == "A1" else ("艾克赛琳" if 键 == "A2" else 键)
	d["trait"] = "gambler" if 键 == "A1" else ("lucky" if 键 == "A2" else "wSeries")
	d["tags"] = {"势力": "ATX", "战斗分类": "近卫"}
	return d

func _靶(位: float) -> Dictionary:
	var d := _单位("靶_%d" % int(位), "enemy", 位)
	d["name"] = "靶机%s" % str(int(位) + 1)
	d["tags"] = {}
	return d

func _敌(位: float, w: Dictionary) -> Dictionary:
	var e := _靶(位)
	e["weapons"] = [{"t": w, "cd": 0.0, "uses": null, "readyTurn": 0.0}]
	return e

func _武(威力: float, 段数: int, 命中率: float = 100.0) -> Dictionary:
	return {"name": "测试武器", "fire": "direct", "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

func _给牌(u: Dictionary, id: String) -> Dictionary:
	var 卡 := AtxThree.卡(id)
	if 卡.is_empty():
		push_error("测试里取不到牌：%s" % id)
		return {}
	卡["入手等级"] = int(卡.get("入手等级", 10))
	(u["专属手牌"] as Array).append(卡)
	return 卡

func _打幸运连号(c: Dictionary, u: Dictionary) -> Dictionary:
	c.公有手牌.append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.幸运连号), c))
	return Btl.打出精神或公有牌(c, u.key, AtxFaction.幸运连号)

func _打合体技(c: Dictionary, u: Dictionary) -> Dictionary:
	(u["专属手牌"] as Array).append(Btl.克隆战术牌(FacAtx.合体技卡(), c))
	return Btl.打出主武器卡(c, u.key, FacAtx.合体技ID)

## `算意图` 里那台敌机的**预告目标**（键）
func _预告(c: Dictionary) -> String:
	for 条 in Btl.算意图(c):
		if 条 is Dictionary and str(条.get("单位", "")) == str(c.enemies[0].get("key")):
			return str(条.get("目标", "")) if 条.get("目标") != null else ""
	return ""

## 真的走一个敌方阶段（Step A 补打 → Step B 敌方行动），返回那台敌机**实际打中的目标键**
func _打一个敌方阶段(c: Dictionary) -> String:
	Btl.结束我方回合(c)
	for i in range(J.or_(c.get("log"), []).size() - 1, -1, -1):
		var e = c.log[i]
		if not (e is Dictionary) or str(e.get("类型", "")) != "攻击":
			continue
		if str(e.get("单位", "")) != str(c.enemies[0].get("key")):
			continue
		return str(e.get("目标", ""))
	return ""

func _找日志(c: Dictionary, 键: String) -> Dictionary:
	for i in range(J.or_(c.get("log"), []).size() - 1, -1, -1):
		var e = c.log[i]
		if e is Dictionary and e.has(键):
			return e
	return {}

func _找攻击(c: Dictionary, 武器含: String) -> Dictionary:
	for i in range(J.or_(c.get("log"), []).size() - 1, -1, -1):
		var e = c.log[i]
		if e is Dictionary and str(e.get("类型", "")) == "攻击" and str(e.get("武器", "")).contains(武器含):
			return e
	return {}

func _找槽(u: Dictionary, id: String) -> Dictionary:
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if 槽 is Dictionary:
			var 卡 = J.g(槽, "卡")
			if 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == id:
				return 槽
	return {}
