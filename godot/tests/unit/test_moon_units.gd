## 月球王国 v0.2.1 五人：刀枪切换（站位层）/ 拘束与重力网 / 月华溢流护盾 / 换位牌走 BattleSwap / 全卡冒烟 / 整场自动战斗。
## 全部走 `Setup.开局(..., {"月球v02": true})`；打牌走与界面同一套入口（`DeckFlow` / `Btl` / `BattleCardExec`）。
extends RefCounted

const 种子 := 20261021
const 开 := {"月球v02": true}

var _场: Dictionary = {}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_刀枪切换(t)
	_段2_拘束与重力网(t)
	_段3_月华溢流(t)
	_段4_换位牌(t)
	_段5_全卡冒烟(t)
	_段6_整场自动战斗(t)

# ---- ① 刀枪切换：排位不满足的主武器不在武器栏里 ----
func _段1_刀枪切换(t) -> void:
	var ctx := _开局(_阵())
	var 凪 = _找(ctx, "M4")
	t.ok(_名(凪) == ["月光狙击枪", "牵制射击"], "① Nagi 在后排：狙击枪可用、居合收起（%s）" % str(_名(凪)))
	凪["战意"] = 100.0
	var 狙: Dictionary = 凪.武器栏[0]
	Btl.打出武器栏卡(ctx, 凪.key, 狙, null)
	t.ok(float(狙.get("当前冷却", 0.0)) == 1.0, "① 打出狙击枪 → 冷却 1")
	BattleSwap.换位(ctx, "ally", 6, 3, {"来源": "测试"})
	t.ok(_名(凪) == ["小太刀·居合", "牵制射击"], "① 换到前排：居合可用、狙击枪收起（%s）" % str(_名(凪)))
	凪["主武器已销毁"] = false
	t.ok(Btl.武器栏不可打原因(ctx, 凪, 凪.武器栏[0]) == "", "① 前排的居合打得出来")
	MoonV02.我方阶段初_后(ctx)
	t.ok(float(狙.get("当前冷却", 0.0)) == 0.0, "① 收在站位层底下的狙击枪照样走冷却")
	BattleSwap.换位(ctx, "ally", 3, 6, {"来源": "测试"})
	t.ok(_名(凪) == ["月光狙击枪", "牵制射击"] and is_same(凪.武器栏[0], 狙), "① 换回后排：还是原来那张狙击枪对象")
	var 阿 = _找(ctx, "M2")
	BattleSwap.换位(ctx, "ally", 1, 7, {"来源": "测试"})
	t.ok(not _名(阿).has("打桩臂"), "① 阿布拉德到后排：打桩臂收起")
	阿["战意"] = 100.0
	t.ok(DeckFlow.副武器不可打原因(ctx, 阿, 阿.副武器栏[0]).find("前排") >= 0, "① 阿布拉德到后排：不动如山（前排限定）不可打")
	var 顶 := _开局([{"键": "M1", "位": 5}, {"键": "M4", "位": 6}])
	t.ok(Fm.是否顶位(顶, "ally") and _名(_找(顶, "M4")).size() == 3, "① 我方前排全空（顶位）：Nagi 狙击枪与居合都可用")

# ---- ② 拘束 / 重力网 ----
func _段2_拘束与重力网(t) -> void:
	var ctx := _开局(_阵())
	var 苏 = _找(ctx, "M5")
	var 敌: Dictionary = ctx.enemies[0]
	MoonV02.武器攻击后(ctx, 苏, 敌, 1, 苏.武器栏[0].武器)
	t.ok(MoonPhase.有拘束(敌) and Calc.buffSum(敌, "def") == -20.0 and Calc.buffSum(敌, "eva") == -15.0,
		"② 牵引锚命中 → 【拘束】防御 -20、闪避 -15")
	var 敌2: Dictionary = ctx.enemies[1]
	MoonV02.武器攻击后(ctx, 苏, 敌2, 0, 苏.武器栏[0].武器)
	t.ok(not MoonPhase.有拘束(敌2), "② 打空 → 不挂拘束")
	var 网 := _开局([{"键": "M1", "位": 5}, {"键": "M5", "位": 1}, {"键": "M2", "位": 2}])
	网.turn = 2.0
	DeckFlow.阶段初_检查(网)
	var 苏2 = _找(网, "M5")
	苏2["战意"] = 100.0
	var 前血: Array = 网.enemies.map(func(e): return float(e.hp))
	var 果 := DeckFlow.打出大招(网, 苏2.key, "MOON_M5_ULT", null)
	t.ok(J.truthy(果.get("成功")) and J.every(网.enemies, func(e): return MoonPhase.有拘束(e)),
		"② 重力网：敌方前排全体挂上拘束（%s）" % str(果.get("原因", "")))
	t.ok(float(网.enemies[0].hp) == 前血[0] - 1100.0, "② 重力网：每台 1100 点")
	t.ok(J.same(MoonPhase.状态(网).get("拘束必中回合"), 网.turn), "② 随侍达成 → 本回合打拘束目标必中")
	t.ok(MoonV02.命中修正(苏2, 网.enemies[0], {"name": "x"}, 网) >= 1000.0, "② 必中：命中修正 +1000（命中率封顶 100）")
	t.ok(MoonV02.命中修正(苏2, 网.enemies[0], {}, 网) == 0.0, "② 不带武器的结算不加命中")

# ---- ③ 月华溢流：溢出转护盾（上限 20%）、下个我方阶段初到期 ----
func _段3_月华溢流(t) -> void:
	var ctx := _开局(_阵())
	var 菲 = _找(ctx, "M1")
	var 伊 = _找(ctx, "M3")
	菲["shieldHp"] = 0.0
	伊["战意"] = 100.0
	var 果 := DeckFlow.打出副武器(ctx, 伊.key, "MOON_M3_SUB1", 菲.key)
	var 上限 := J.round(float(菲.maxHp) * 0.2)
	t.ok(J.truthy(果.get("成功")) and float(菲.shieldHp) == 上限, "③ 修理装置修满血的 Feena：溢出 25%% → 护盾封顶 20%%（%s）" % J.s(菲.shieldHp))
	t.ok(Btl.战意(伊) == 95.0 and Calc.buffSum(菲, "def") >= 15.0, "③ 修理装置扣 5 战意、目标防御 +15")
	MoonPhase.治疗(ctx, 伊, 菲, 0.25, 1.0)
	t.ok(float(菲.shieldHp) == 上限, "③ 同一回合再溢出 → 不超过 20% 上限")
	菲["shieldHp"] = float(菲.shieldHp) + 100.0
	MoonV02.我方阶段初_后(ctx)
	t.ok(float(菲.shieldHp) == 100.0 and not 菲.has("月球护盾"), "③ 下个我方阶段初：只扣掉本模块给的护盾（别处的 100 留着）")
	var 苏 = _找(ctx, "M5")
	苏["hp"] = float(苏.maxHp) * 0.5
	var 前 := float(苏.hp)
	MoonUnits._修理装置(_带目标(ctx, 伊, 苏), 伊, "修理装置")
	t.ok(float(苏.hp) - 前 == J.round(float(苏.maxHp) * 0.125), "③ 目标不与 Iris 十字相邻 → 回复减半（12.5%）")
	var 盾前 := float(苏.get("shieldHp", 0.0))
	MoonPhase.治疗(ctx, null, 苏, 0.9, 0.0)
	t.ok(float(苏.get("shieldHp", 0.0)) == 盾前, "③ 不是 Iris 的回复 → 溢出不转护盾")

# ---- ④ 换位牌一律走 BattleSwap ----
func _段4_换位牌(t) -> void:
	var ctx := _开局(_阵())
	var 菲 = _找(ctx, "M1")
	var 阿 = _找(ctx, "M2")
	var 牌 := _势力牌("MOON_FAC_3")
	ctx.公有手牌.append(牌)
	菲["战意"] = 100.0
	var 果: Dictionary = BattleCardExec.打出精神或公有牌(ctx, 菲.key, 牌, 阿.key)
	t.ok(J.truthy(果.get("成功")) and float(菲.slot) == 1.0 and float(阿.slot) == 5.0, "④ 战线轮换：第 2 列前后对调（%s）" % str(果))
	t.ok(_有换位日志(ctx, "★ 王国之盾") == false and _有换位日志(ctx, "战线轮换"), "④ 换位写的是 BattleSwap 的〔换位〕战报")
	t.ok(Calc.buffSum(菲, "eva") >= 15.0 and Calc.buffSum(阿, "eva") >= 15.0, "④ 两名单位闪避 +15")
	t.ok(MoonPhase.月相(ctx) == "残月", "④ 换位不改月相")
	var 苏 = _找(ctx, "M5")
	苏["战意"] = 100.0
	var 果2 := DeckFlow.打出副武器(ctx, 苏.key, "MOON_M5_SUB1", null)
	t.ok(J.truthy(果2.get("成功")) and float(苏.slot) == 1.0 and float(菲.slot) == 2.0 and _有换位日志(ctx, "锚链调度"),
		"④ 锚链调度：苏菲与 Feena 交换位置")
	var 伊 = _找(ctx, "M3")
	阿["hp"] = 1000.0
	伊["战意"] = 100.0
	var 回 := MoonUnits._空中回收(ctx, 伊, "空中回收")
	t.ok(not 回.is_empty() and Fm.rowOfSlot(float(伊.slot)) == Fm.ROW_FRONT, "④ 空中回收：Iris 换到前排（%s）" % str(回))
	var 二 := _开局(_阵())
	var 阿2 = _找(二, "M2")
	阿2["hp"] = float(阿2.maxHp) * 0.3
	var 阵: Dictionary = _势力牌("MOON_FAC_2")
	二.公有手牌.append(阵)
	_找(二, "M1")["战意"] = 100.0
	BattleCardExec.打出精神或公有牌(二, "M1", 阵, null)
	t.ok(float(阿2.slot) == 5.0 and _有换位日志(二, "阵形变换"), "④ 阵形变换：前排最残的阿布拉德换到后排")
	var 挺: Dictionary = _势力牌("MOON_FAC_9")
	二.公有手牌.append(挺)
	var 菲2 = _找(二, "M1")
	var 果3: Dictionary = BattleCardExec.打出精神或公有牌(二, "M1", 挺, null)
	t.ok(J.truthy(果3.get("成功")) and float(菲2.slot) == 5.0 and float(阿2.slot) == 1.0 and float(菲2.shieldHp) > 0.0,
		"④ 公主挺身：Feena 与最残的阿布拉德换位并获得护盾（%s）" % str(果3))

# ---- ⑤ 每张牌都能打出来（不卡死、不报错）----
func _段5_全卡冒烟(t) -> void:
	var 坏: Array = []
	var ctx := _开局(_阵())
	ctx.turn = 3.0
	_场 = ctx
	for u in ctx.allies:
		for 槽 in u.大招槽:
			_满状态(u)
			槽["已解锁"] = true
			槽["实时门槛满足"] = true
			槽["cd"] = 0.0
			var 果 := DeckFlow.打出大招(ctx, u.key, 槽.卡.id, null)
			if not J.truthy(果.get("成功")):
				坏.append("%s：%s" % [槽.卡.名, 果.get("原因")])
		for e in u.副武器栏:
			_满状态(u)
			e["cd"] = 0.0
			e["禁用"] = false
			e["本回合已用"] = 0
			if str(e.卡.id) == "MOON_M2_SUB1" and not Fm.是前排有效(u, ctx):
				continue
			var 果2 := DeckFlow.打出副武器(ctx, u.key, e.卡.id, null)
			if not J.truthy(果2.get("成功")):
				坏.append("%s：%s" % [e.卡.名, 果2.get("原因")])
		for c in u.武器栏.duplicate():
			_满状态(u)
			var 果3 := Btl.打出武器栏卡(ctx, u.key, c, null)
			if not J.truthy(果3.get("成功")):
				坏.append("%s：%s" % [c.名, 果3.get("原因")])
		for c in MoonUnits.角色牌们(MoonPhase.键(u)).filter(func(x): return str(x.卡类) == "专属精神牌"):
			_满状态(u)
			var 张: Dictionary = c.duplicate(true)
			u.专属手牌.append(张)
			var 果4: Dictionary = BattleCardExec.打出精神或公有牌(ctx, u.key, 张, null)
			if not J.truthy(果4.get("成功")):
				坏.append("%s：%s" % [c.名, 果4.get("原因")])
	var 菲 = _找(ctx, "M1")
	for c in MoonDeck.月光牌们() + MoonDeck.势力牌们():
		_满状态(菲)
		var 张2: Dictionary = c.duplicate(true)
		ctx.公有手牌.append(张2)
		var 目标 = ctx.enemies[0].key if str(c.get("目标")) == "敌机" else null
		var 果5: Dictionary = BattleCardExec.打出精神或公有牌(ctx, 菲.key, 张2, 目标)
		if not J.truthy(果5.get("成功")):
			坏.append("%s：%s" % [c.名, 果5.get("原因")])
	t.ok(坏.is_empty(), "⑤ 五人全部牌 + 8 张月光牌 + 7 张势力牌都打得出来%s" % ("" if 坏.is_empty() else "：" + "；".join(坏)))
	t.ok(MoonPhase.到过(ctx).size() == 3 and int(MoonPhase.状态(ctx).get("切换次数", 0)) >= 3, "⑤ 三张月相大招都切过月相：%s" % str(MoonPhase.到过(ctx)))

# ---- ⑥ 整场自动战斗：选项开着能打完、确定性 ----
func _段6_整场自动战斗(t) -> void:
	var 敌 := [{"键": "ironwall", "位": 0, "等级": 8}, {"键": "raider", "位": 1, "等级": 8},
		{"键": "artillery", "位": 5, "等级": 8}, {"键": "sniper", "位": 6, "等级": 8}]
	for 种 in [种子, 种子 + 1, 种子 + 2]:
		var ctx := Setup.跑完(_阵(), 敌, 种, 开)
		var 共鸣 := 0
		for l in ctx.log:
			if str(l.get("文本", "")).find("打出【月光共鸣】") >= 0:
				共鸣 += 1
		t.ok(ctx.result is Dictionary and 共鸣 > 0, "⑥ 种子 %d：打完（%s，%d 回合），Feena 自动补打月光共鸣 %d 次" % [
			种, str(ctx.result.get("结果")), int(ctx.turn), 共鸣])
	var 甲 := Setup.跑完(_阵(), 敌, 种子, 开)
	var 乙 := Setup.跑完(_阵(), 敌, 种子, 开)
	t.ok(甲.log.size() == 乙.log.size() and str(甲.result) == str(乙.result) and 甲.turn == 乙.turn, "⑥ 同种子两次结果一致")

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

func _名(u: Dictionary) -> Array:
	return (u.武器栏 as Array).map(func(c): return str(c.get("名")))

func _势力牌(id: String) -> Dictionary:
	for c in MoonDeck.势力牌们():
		if str(c.get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

func _满状态(u: Dictionary) -> void:
	for e in _场.enemies:
		e["hp"] = float(e.maxHp)
	u["战意"] = 100.0
	u["主武器已销毁"] = false

func _带目标(ctx: Dictionary, 打者: Dictionary, 目标: Dictionary) -> Dictionary:
	ctx["_当前出牌者"] = 打者.key
	ctx["_当前目标"] = 目标.key
	return ctx

func _有换位日志(ctx: Dictionary, 来源: String) -> bool:
	for l in ctx.log:
		if str(l.get("类型", "")) == "换位" and str(l.get("来源", "")) == 来源:
			return true
	return false
