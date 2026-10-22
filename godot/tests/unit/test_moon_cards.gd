## 月球王国 v0.2.1 单卡细节：螺旋式打桩机亮起 / 不动如山 / 弦月·一闪随侍必中 / 自卫激光枪 / 陨石召唤 / 王国之盾 / 月相仪典 / 月光一级牌。
## 全部走 `Setup.开局(..., {"月球v02": true})`；默认阵：Feena 后2，阿布拉德 前2，Iris 后1，Nagi 后3，苏菲 前3。
extends RefCounted

const 种子 := 20261021
const 开 := {"月球v02": true}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_螺旋式打桩机(t)
	_段2_不动如山(t)
	_段3_弦月一闪(t)
	_段4_自卫激光枪与余响共鸣(t)
	_段5_陨石召唤(t)
	_段6_王国之盾(t)
	_段7_月相仪典(t)
	_段8_精神牌与月影校射(t)

func _段1_螺旋式打桩机(t) -> void:
	var ctx := _开局(_阵())
	var 阿 = _找(ctx, "M2")
	t.ok(not _槽可打(ctx, 阿, "MOON_M2_ULT"), "① 开局（受击 0 次）螺旋式打桩机不亮")
	for i in 3:
		Flow.结算一个目标(ctx, ctx.enemies[0], 阿, _连射(1), {"改目标": false})
	t.ok(float(阿.get("月球受击", 0.0)) == 3.0, "① 被打 3 次 → 本场受击计数 3")
	DeckFlow.阶段初_检查(ctx)
	t.ok(_槽可打(ctx, 阿, "MOON_M2_ULT"), "① 阶段初刷新后亮起")
	BattleSwap.换位(ctx, "ally", 1, 7, {"来源": "测试"})
	t.ok(not _槽可打(ctx, 阿, "MOON_M2_ULT"), "① 换到后排 → 立即熄灭")
	var 槽 := DeckFlow.找大招槽(阿, "MOON_M2_ULT")
	槽["cd"] = 3.0
	MoonV02.武器攻击后(ctx, 阿, ctx.enemies[0], 1, MoonUnits.角色牌们("M2")[0].武器)
	t.ok(float(槽.cd) == 2.0, "① 打桩臂命中 → 螺旋式打桩机冷却 -1")

func _段2_不动如山(t) -> void:
	var ctx := _开局(_阵())
	var 阿 = _找(ctx, "M2")
	阿["战意"] = 100.0
	var 果 := DeckFlow.打出副武器(ctx, 阿.key, "MOON_M2_SUB1", null)
	t.ok(J.truthy(果.get("成功")) and Btl.战意(阿) == 95.0 and J.truthy(阿.get("不动如山中")), "① 不动如山：扣 5 战意、本回合挂上")
	t.ok(absf(MoonV02.受方伤害倍率(ctx, null, 阿, {}) - 0.8) < 0.0001, "② 不动如山：受到伤害 ×0.8")
	t.ok(MoonDeck.各级张数(ctx)["二级"] == 1, "② 阿布拉德与 Feena 同列相邻 → 随侍：月面偏导盾放入月光牌库")
	MoonV02.我方阶段初_后(ctx)
	t.ok(not 阿.has("不动如山中"), "② 下个我方阶段初到期")

func _段3_弦月一闪(t) -> void:
	var 随 := _弦月(_阵())
	t.ok(随.伤 > 0.0, "③ Nagi 是随侍 → 必中（闪避 999 的目标也打中了，伤害 %s）" % J.s(随.伤))
	t.ok(随.余响 and 随.破防 and 随.坍缩, "③ 随侍 + 残月：追加半额余响；命中挂破防；引力坍缩放入月光牌库")
	var 不 := _弦月([{"键": "M1", "位": 5}, {"键": "M2", "位": 1}, {"键": "M4", "位": 7}])
	t.ok(不.伤 == 0.0 and not 不.余响 and not 不.坍缩, "③ Nagi 不与 Feena 相邻 → 不必中（打空）、不余响、不放入")

func _段4_自卫激光枪与余响共鸣(t) -> void:
	var ctx := _开局(_阵())
	var 伊 = _找(ctx, "M3")
	var 苏 = _找(ctx, "M5")
	苏["hp"] = float(苏.maxHp) * 0.5
	var 前 := float(苏.hp)
	MoonV02.武器攻击后(ctx, 伊, ctx.enemies[0], 2, 伊.武器栏[0].武器)
	t.ok(float(苏.hp) - 前 == J.round(float(苏.maxHp) * 0.05), "④ 自卫激光枪命中 → HP 最低的苏菲回复 5%")
	var 凪 = _找(ctx, "M4")
	var 卡 := MoonDeck.月光牌("MOON_LT1_ECHO")
	ctx.公有手牌.append(卡)
	BattleCardExec.打出精神或公有牌(ctx, 伊.key, 卡, 凪.key)
	var 敌: Dictionary = ctx.enemies[0]
	var 敌前 := float(敌.hp)
	MoonV02.武器攻击后(ctx, 凪, 敌, 0, {"name": "x"})
	t.ok(敌前 - float(敌.hp) == 700.0 and not 凪.has("月球余响共鸣"), "④ 余响共鸣：下一次武器攻击后 Feena 追加 700（用掉即清）")

func _段5_陨石召唤(t) -> void:
	var ctx := _开局(_阵())
	var 菲 = _找(ctx, "M1")
	var 阿 = _找(ctx, "M2")
	菲["战意"] = 100.0
	var 卡 := _势力牌("MOON_FAC_6")
	ctx.公有手牌.append(卡)
	var 敌前: Array = ctx.enemies.map(func(e): return float(e.hp))
	var 阿前 := float(阿.hp)
	var 果: Dictionary = BattleCardExec.打出精神或公有牌(ctx, 菲.key, 卡, null)
	t.ok(J.truthy(果.get("成功")) and float(ctx.enemies[0].hp) == 敌前[0] - 2200.0 and float(阿.hp) == 阿前 - 400.0,
		"⑤ 陨石召唤：敌方前排各 2200、我方前排各 400")
	t.ok(J.truthy(卡.get("已用")) and not (ctx.公有弃牌堆 as Array).has(卡), "⑤ 每场 1 次：移出本场、不进弃牌堆")
	ctx.公有手牌.append(卡)
	t.ok(CardPlay.不可打原因(ctx, 菲, 卡, CardPlay.区_公有).find("每场") >= 0, "⑤ 再拿到也打不出来")
	var 外 := _开局([{"键": "M1", "位": 5}, {"键": "U1", "位": 1}])
	var 宗 = _找(外, "U1")
	宗["战意"] = 100.0
	t.ok(CardPlay.不可打原因(外, 宗, _势力牌("MOON_FAC_1"), CardPlay.区_公有) != "", "⑤ 非月球王国成员打不了月球王国势力牌")

func _段6_王国之盾(t) -> void:
	var ctx := _开局(_阵())
	var 伊 = _找(ctx, "M3")
	var 阿 = _找(ctx, "M2")
	var 苏 = _找(ctx, "M5")
	DeckFlow.找大招槽(阿, "MOON_M2_ULT")["cd"] = 4.0
	DeckFlow.找大招槽(苏, "MOON_M5_ULT")["cd"] = 4.0
	伊["战意"] = 100.0
	for 目标 in [阿, 苏]:
		var 卡 := _势力牌("MOON_FAC_8")
		ctx.公有手牌.append(卡)
		BattleCardExec.打出精神或公有牌(ctx, 伊.key, 卡, 目标.key)
	t.ok(float(DeckFlow.找大招槽(阿, "MOON_M2_ULT").cd) == 2.0, "⑥ 王国之盾：Iris 随侍触发、目标阿布拉德也是随侍 → 冷却 -2")
	t.ok(float(DeckFlow.找大招槽(苏, "MOON_M5_ULT").cd) == 3.0, "⑥ 目标苏菲不是随侍 → 只 -1")
	t.ok(MoonDeck.各级张数(ctx)["二级"] >= 1, "⑥ 随侍：朔望流转放入月光牌库")
	t.ok(not _条件(ctx, "月球打出过大招"), "⑥ 入库条件：还没打过大招 → 不满足")
	ctx.turn = 2.0
	DeckFlow.阶段初_检查(ctx)
	_找(ctx, "M1")["战意"] = 100.0
	DeckFlow.打出大招(ctx, "M1", "MOON_M1_ULT_BLESS", null)
	t.ok(_条件(ctx, "月球打出过大招"), "⑥ 打出月相·祝福后 → 满足")

func _段7_月相仪典(t) -> void:
	var ctx := _开局(_阵())
	var 菲 = _找(ctx, "M1")
	菲["战意"] = 50.0
	var 卡 := _势力牌("MOON_FAC_4")
	ctx.公有手牌.append(卡)
	var 果: Dictionary = BattleCardExec.打出精神或公有牌(ctx, 菲.key, 卡, null)
	t.ok(J.truthy(果.get("成功")) and MoonPhase.月相(ctx) == "盈月", "⑦ 月相仪典：残月 → 盈月")
	t.ok(Btl.战意(菲) == 50.0, "⑦ 指挥 -5 后 5 费，Feena 在后排返还 5 → 战意不变（%s）" % J.s(Btl.战意(菲)))
	var 赠: Array = (ctx.公有手牌 as Array).filter(func(c): return J.truthy(c.get("月球赠牌")))
	t.ok(赠.size() == 1 and str(赠[0].id) == "MOON_LT1_ECHO", "⑦ 余响共鸣进公有手牌")
	var 一级前: int = MoonDeck.各级张数(ctx)["一级"]
	BattleCardExec.打出精神或公有牌(ctx, 菲.key, 赠[0], 菲.key)
	t.ok(MoonDeck.各级张数(ctx)["一级"] == 一级前, "⑦ 赠牌打出后不进月光牌库")
	for 相 in ["祝福", "残月"]:
		var 卡2 := _势力牌("MOON_FAC_4")
		ctx.公有手牌.append(卡2)
		BattleCardExec.打出精神或公有牌(ctx, 菲.key, 卡2, null)
		t.ok(MoonPhase.月相(ctx) == 相, "⑦ 继续轮转 → 【%s】" % 相)
	var 无菲 := _开局([{"键": "M2", "位": 1}, {"键": "M3", "位": 4}])
	t.ok(CardPlay.不可打原因(无菲, _找(无菲, "M2"), _势力牌("MOON_FAC_4"), CardPlay.区_公有).find("Feena") >= 0
		and MoonPhase.月相(无菲) == "", "⑦ 没有 Feena：没有月相、月相仪典打不出来")

func _段8_精神牌与月影校射(t) -> void:
	var ctx := _开局(_阵())
	var 菲 = _找(ctx, "M1")
	菲["战意"] = 50.0
	菲.专属牌库.push_front({"id": "垫", "名": "垫牌", "卡类": "专属精神牌"})
	var 祈: Dictionary = (MoonUnits.角色牌们("M1")[4] as Dictionary).duplicate(true)
	菲.专属手牌.append(祈)
	var 手前: int = 菲.专属手牌.size()
	BattleCardExec.打出精神或公有牌(ctx, 菲.key, 祈, null)
	t.ok(Btl.战意(菲) == 60.0 and 菲.专属手牌.size() == 手前, "⑧ 王女的祈愿：战意 +15（净 +10）；随侍 3 人 → 抽 1 张补回手牌")
	var 苏 = _找(ctx, "M5")
	苏["月球下张命中"] = 15.0
	t.ok(MoonV02.命中修正(苏, ctx.enemies[0], {"name": "x"}, ctx) == 15.0, "⑧ 月影校射：下一张武器牌命中 +15")
	MoonV02.牌打出后(ctx, 苏, 苏.武器栏[0], CardPlay.区_主武器)
	t.ok(not 苏.has("月球下张命中") and float(苏.武器栏[0].get("当前冷却", 0.0)) == 1.0, "⑧ 打出武器牌后用掉；牵引锚进入冷却 1")

# ---- 小工具 ----
func _阵() -> Array:
	return [{"键": "M1", "位": 5}, {"键": "M2", "位": 1}, {"键": "M3", "位": 4}, {"键": "M4", "位": 6}, {"键": "M5", "位": 2}]

func _开局(阵: Array) -> Dictionary:
	var 出: Array = 阵.map(func(x): return J.merged(x, {"等级": 10}))
	return Setup.开局(出, [{"键": "ironwall", "位": 0, "等级": 5}, {"键": "ironwall", "位": 2, "等级": 5}], 种子, null, 开)

func _找(ctx: Dictionary, 键: String) -> Variant:
	for u in ctx.allies:
		if str(u.get("key", "")) == 键:
			return u
	return null

func _势力牌(id: String) -> Dictionary:
	for c in MoonDeck.势力牌们():
		if str(c.get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

func _槽可打(ctx: Dictionary, u: Dictionary, id: String) -> bool:
	u["战意"] = 100.0
	var 槽 := DeckFlow.找大招槽(u, id)
	return not 槽.is_empty() and DeckFlow.大招不可打原因(ctx, u, 槽) == ""

func _条件(ctx: Dictionary, 类型: String) -> bool:
	return DeckFlow.条件满足(ctx, null, {"类型": 类型})

func _连射(段: int) -> Dictionary:
	return {"name": "测试", "fire": "direct", "dmgType": "物理", "power": 300.0, "hit": 100.0, "critMod": 0.0,
		"stat": "射击", "hits": float(段), "special": "multi" if 段 > 1 else null, "必中": true, "cd": 0.0, "uses": null,
		"unlock": 1.0, "upgrades": [], "ignoreDef": false, "area": "single", "距离": [1, 6]}

## 第 2 回合打一发弦月·一闪（目标闪避 999），返回 {伤, 余响, 破防, 坍缩}。
func _弦月(阵: Array) -> Dictionary:
	var ctx := _开局(阵)
	ctx.turn = 2.0
	DeckFlow.阶段初_检查(ctx)
	var 凪 = _找(ctx, "M4")
	凪["战意"] = 100.0
	var 敌: Dictionary = ctx.enemies[0]
	敌["eva"] = 999.0
	var 前 := float(敌.hp)
	var 余前 := float(MoonPhase.状态(ctx).get("余响总伤", 0.0))
	var 果 := DeckFlow.打出大招(ctx, 凪.key, "MOON_M4_ULT", 敌.key)
	var 坍 := false
	for c in SubDeck.牌们(MoonDeck.库(ctx)):
		坍 = 坍 or str(c.get("id")) == "MOON_LT2_COLLAPSE"
	return {"伤": 前 - float(敌.hp) if J.truthy(果.get("成功")) else -1.0,
		"余响": float(MoonPhase.状态(ctx).get("余响总伤", 0.0)) > 余前,
		"破防": Calc.buffSum(敌, "def") <= -20.0, "坍缩": 坍}
