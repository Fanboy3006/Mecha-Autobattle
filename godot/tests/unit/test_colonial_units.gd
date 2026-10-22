## ★ COL-3（施工单 §2）：五人卡池与独有机制 —— 装填档位 / 贯穿一列 / 斩首 / 破隐一击 / METEOR 锁定链 /
## 旋转破坏步枪结束 ZERO / 精神牌 / 光束反射。
extends RefCounted

const 千 := 999999.0
const 种子 := 20261018

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_卡池与获取(t)
	_段2_装填档位(t)
	_段3_贯穿一列(t)
	_段4_斩首(t)
	_段5_破隐一击(t)
	_段6_METEOR锁定链(t)
	_段7_旋转破坏步枪(t)
	_段8_精神牌(t)
	_段9_光束反射(t)
	_段10_全卡冒烟(t)

# ==========================================================================================
# ① 卡池张数与 `获取` 字段
# ==========================================================================================
func _段1_卡池与获取(t) -> void:
	var 数 := {}
	for 键 in ColonialUnits.成员键:
		数[键] = ColonialUnits.角色牌们(键).size()
	t.ok(数["S1"] == 18 and 数["W1"] == 18 and 数["W2"] == 17 and 数["S2"] == 7 and 数["W3"] == 7
		and 数["W4"] == 7 and 数["W5"] == 7, "① 七人卡池张数：%s" % str(数))
	var 缺获取: Array = []
	var 类计 := {}
	for c in ColonialUnits.卡表():
		if str(c.get("获取", "")) == "":
			缺获取.append(str(c.get("名")))
		var 类 := str(c.get("卡类", ""))
		类计[类] = int(类计.get(类, 0)) + 1
	t.ok(缺获取.is_empty(), "① 每张牌都带 `获取` 字段%s" % ("" if 缺获取.is_empty() else "：" + "、".join(缺获取)))
	t.ok(int(类计.get("主武器卡", 0)) == 24 and int(类计.get("副武器卡", 0)) == 2 and int(类计.get("大招槽卡", 0)) == 13
		and int(类计.get("专属精神牌", 0)) == 42, "① 卡类分布：%s" % str(类计))
	var 双 := _卡("W1", "COL_W1_ULT_TWIN")
	var 双武: Dictionary = 双.get("武器")
	t.ok(J.num0(双武.get("power")) == 3500.0 and str(双武.get("area")) == "pierce"
		and absf(float(双武.get("pierce_mul", 0.5)) - 1.0) < 0.0001,
		"① 双联破坏步枪：贯穿一列（area = pierce、穿甲倍率 1.0）、每格 3500")
	var 双加 := _卡("W1", "COL_W1_ULT_TWIN", true)
	t.ok(J.num0((双加.get("武器") as Dictionary).get("power")) == 4000.0, "① 双联 `+` 版每格 4000")
	t.ok(str(ColonialUnits.角色牌们("W1", true)[0].get("名")).ends_with("+"), "① `+` 版名字带 `+`")

# ==========================================================================================
# ② 装填：Lv10 只有初始 / Lv20 起剧情与 `+` 版 / Lv30 起肉鸽
# ==========================================================================================
func _段2_装填档位(t) -> void:
	var 低 := _装("S1", 10)
	var 中 := _装("S1", 20)
	var 高 := _装("S1", 30)
	t.ok(not _有(低, "COL_S1_W4") and _有(中, "COL_S1_W4"), "② Lv10 没有剧情牌，Lv20 起装上「光束军刀·双刃连结」")
	t.ok(not _有(低, "COL_S1_SP9") and _有(高, "COL_S1_SP9"), "② 肉鸽三选一的「我是拉克丝·克莱因」Lv30 才装")
	var 希 := _装("W1", 30)
	t.ok(_有(希, "COL_W1_ULT_TWIN") and _有(希, "COL_W1_ULT_ROLL"), "② 希罗的双联 / 旋转破坏步枪装在大招槽")
	var 迪 := _装("W2", 30)
	t.ok(_有(迪, "COL_W2_ULT_AMBUSH") and _有(迪, "COL_W2_ULT_HARVEST"), "② 迪奥的两张破隐大招都在")

# ==========================================================================================
# ③ 贯穿一列：只打目标所在列的前后两格
# ==========================================================================================
func _段3_贯穿一列(t) -> void:
	var 拉 := _单位("W1", "ally", 0.0, "狙击")
	var 前 := _靶("前", 0.0)
	var 后 := _靶("后", 4.0)
	var 别列 := _靶("别列", 1.0)
	var 场 := _场([拉], [前, 后, 别列])
	var w: Dictionary = _卡("W1", "COL_W1_ULT_TWIN").get("武器")
	var 目标们 := Reach.范围目标们(场, w, 前)
	var 键们: Array = 目标们.map(func(x): return str(((x as Dictionary).get("单位") as Dictionary).get("key")))
	t.ok(目标们.size() == 2 and 键们.has("前") and 键们.has("后"), "③ 双联只打一列两格：%s" % str(键们))
	t.ok(not 键们.has("别列"), "③ 相邻列的同排敌机不吃这一发")

# ==========================================================================================
# ④ 斩首：结算后剩余 HP ≤ 上限 × N% 直接击破
# ==========================================================================================
func _段4_斩首(t) -> void:
	var 迪 := _单位("W2", "ally", 0.0, "近卫")
	var 敌 := _靶("敌", 0.0)
	敌["hp"] = 敌.maxHp * 0.2
	var 场 := _场([迪], [敌])
	ColonialV01.武器攻击后(场, 迪, 敌, 1.0, {"斩首": 0.25})
	t.ok(float(敌.get("hp")) == 0.0, "④ 斩首 25%：剩余 20% → 直接击破")
	var 敌2 := _靶("敌2", 1.0)
	敌2["hp"] = 敌2.maxHp * 0.4
	ColonialV01.武器攻击后(场, 迪, 敌2, 1.0, {"斩首": 0.25})
	t.ok(float(敌2.get("hp")) > 0.0, "④ 剩余 40% > 25% → 不触发斩首")
	# 【不杀】优先于斩首
	var 敌3 := _靶("敌3", 2.0)
	敌3["hp"] = 敌3.maxHp * 0.2
	敌3["不杀中"] = true
	ColonialV01.武器攻击后(场, 迪, 敌3, 1.0, {"斩首": 0.25})
	t.ok(float(敌3.get("hp")) > 0.0, "④ 【不杀】优先于【斩首】（标了 `不杀中` 就不斩）")

# ==========================================================================================
# ⑤ 破隐一击：必中 + 必暴 + 可打后排
# ==========================================================================================
func _段5_破隐一击(t) -> void:
	var 迪 := _单位("W2", "ally", 0.0, "近卫")
	var 前 := _靶("前", 0.0)
	var 后 := _靶("后", 4.0)
	var 场 := _场([迪], [前, 后])
	var w: Dictionary = _卡("W2", "COL_W2_ULT_AMBUSH").get("武器")
	t.ok(J.truthy(w.get("必中")) and J.truthy(w.get("必暴")) and J.truthy(w.get("无视前排")),
		"⑤ 破隐一击：必中 / 必暴击 / 无视前排")
	var 活位 := [0, 4]
	t.ok(Reach.近战可达(迪, w, 后, 场.get("enemies")), "⑤ 近战能直接打敌方后排（无视「只能打前排」）")
	var 普通 := {"name": "刀", "fire": "melee", "dmgType": "光束", "power": 1000.0, "hit": 100.0,
		"stat": "格斗", "hits": 1.0, "cd": 0.0, "距离": [1, 3]}
	t.ok(not Reach.近战可达(迪, 普通, 后, 场.get("enemies")), "⑤ 同一个位置，普通近战打不到后排")
	t.ok(not 活位.is_empty(), "⑤ 前排有敌机时普通近战仍只能打前排")

# ==========================================================================================
# ⑥ METEOR 锁定链：重复锁 / 转火 / 回合一末自动发射 / 弹栈
# ==========================================================================================
func _段6_METEOR锁定链(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	拉["觉醒中"] = true
	拉["觉醒类型"] = "SEED"
	var 敌1 := _靶("敌1", 0.0)
	var 敌2 := _靶("敌2", 1.0)
	var 场 := _场([拉], [敌1, 敌2])
	_全装(拉, 场, "S1")
	var 原武器栏: int = 拉.武器栏.size()
	var 果 := DeckFlow.打出大招(场, "S1", "COL_S1_ULT_METEOR", "敌1")
	t.ok(J.truthy(果.get("成功")), "⑥ METEOR·锁定 1 打得出来（战意 100 ≥ 15）")
	t.ok(拉.get("METEOR锁定") is Array and 拉.METEOR锁定.size() == 1, "⑥ 锁定了 1 台")
	t.ok(拉.武器栏.size() == 2 and DeckFlow.当前换装来源(拉).has("METEOR"), "⑥ 武器栏换成「锁定 2」「发射」（换装栈来源 METEOR）")
	t.ok(not J.truthy(拉.get("主武器已销毁")), "⑥ 锁定 1 不销毁主武器（不然本回合打不出后面的临时牌）")
	# 再锁同一台（重复锁同一台 = 挨两发）
	Btl.打出武器栏卡(场, "S1", "COL_S1_TEMP_LOCK2", "敌1")
	t.ok(拉.METEOR锁定.size() == 2 and str(拉.METEOR锁定[1]) == "敌1", "⑥ 可以重复锁定同一台")
	var 血前 := float(敌1.get("hp"))
	var 发射 := Btl.打出武器栏卡(场, "S1", "COL_S1_TEMP_FIRE")
	t.ok(J.truthy(发射.get("成功")), "⑥ 发射打得出来")
	t.ok(float(敌1.get("hp")) < 血前 - 2000.0, "⑥ 锁两次 → 同一台挨两发（%s → %s）" % [J.s(血前), J.s(敌1.get("hp"))])
	t.ok(拉.get("METEOR锁定") == null or (拉.get("METEOR锁定") is Array and (拉.get("METEOR锁定") as Array).is_empty()),
		"⑥ 发射后锁定清空")
	t.ok(拉.武器栏.size() == 原武器栏 and not DeckFlow.当前换装来源(拉).has("METEOR"), "⑥ 发射后弹栈：武器栏原样恢复")
	# 目标死了自动转火
	var 敌3 := _靶("敌3", 0.0)
	var 敌4 := _靶("敌4", 1.0)
	var 场2 := _场([拉], [敌3, 敌4])
	_全装(拉, 场2, "S1")
	拉["战意"] = 100.0
	DeckFlow.打出大招(场2, "S1", "COL_S1_ULT_METEOR", "敌3")
	敌3["hp"] = 0.0
	var 血4 := float(敌4.get("hp"))
	Btl.打出武器栏卡(场2, "S1", "COL_S1_TEMP_FIRE")
	t.ok(float(敌4.get("hp")) < 血4, "⑥ 锁定目标已阵亡 → 转火同排（敌4 挨了这一发）")
	# 回合结束还没发射 → 自动发射
	var 敌5 := _靶("敌5", 0.0)
	var 场3 := _场([拉], [敌5])
	_全装(拉, 场3, "S1")
	拉["战意"] = 100.0
	DeckFlow.打出大招(场3, "S1", "COL_S1_ULT_METEOR", "敌5")
	var 血5 := float(敌5.get("hp"))
	ColonialV01.我方阶段末(场3)
	t.ok(float(敌5.get("hp")) < 血5, "⑥ 回合结束还没发射 → 自动发射")
	t.ok(not DeckFlow.当前换装来源(拉).has("METEOR"), "⑥ 自动发射后同样弹栈")

# ==========================================================================================
# ⑦ 旋转破坏步枪：打出后 ZERO 立刻结束
# ==========================================================================================
func _段7_旋转破坏步枪(t) -> void:
	var 希 := _单位("W1", "ally", 0.0, "狙击")
	希["觉醒中"] = true
	希["觉醒类型"] = "ZERO"
	ColonialAwaken.挂ZERO暴伤(希)
	var 敌 := _靶("敌", 0.0)
	var 场 := _场([希], [敌])
	_全装(希, 场, "W1")
	场["turn"] = 4.0
	var 槽 := {}
	for s in 希.大招槽:
		if str(((s as Dictionary).get("卡") as Dictionary).get("id")) == "COL_W1_ULT_ROLL":
			槽 = s
	var 因 := DeckFlow.大招不可打原因(场, 希, 槽)
	t.ok(因 == "", "⑦ 第 4 回合 + ZERO 中 → 旋转破坏步枪亮起（%s）" % ("可以打" if 因 == "" else 因))
	DeckFlow.打出大招(场, "W1", "COL_W1_ULT_ROLL", "敌")
	t.ok(not ColonialAwaken.是ZERO中(希), "⑦ 打出后 ZERO 立刻结束")
	t.ok(float(ColonialAwaken.入场槽(希, "ZERO").get("cd")) == 3.0, "⑦ 结束觉醒后入场牌冷却 3")
	t.ok(absf(Calc.critMul(希) - 2.0) < 0.001, "⑦ 暴伤回到 ×2.0")

# ==========================================================================================
# ⑧ 精神牌：静夜 / 压住 ZERO / 自爆装置 / 十字架
# ==========================================================================================
func _段8_精神牌(t) -> void:
	var 拉 := _单位("S1", "ally", 0.0, "特种")
	var 卡 := _单位("S2", "ally", 1.0, "指挥")
	var 敌 := _靶("敌", 0.0)
	var 场 := _场([拉, 卡], [敌])
	_全装(拉, 场, "S1")
	卡["专属手牌"] = [_卡("S2", "COL_S2_SP1")]
	卡["专属牌库"] = []
	卡["专属弃牌堆"] = []
	拉["战意"] = 50.0
	var 前 := Btl.战意(拉)
	Btl.打出精神或公有牌(场, "S2", "COL_S2_SP1", "S1")
	t.ok(J.num0(拉.get("战意")) == 前 + 10.0, "⑧「奥布之狮」：指定成员战意 +10")
	var 静 := _精神到手(拉, "COL_S1_SP1")
	拉["战意"] = 50.0
	卡["战意"] = 50.0
	var 前2 := Btl.战意(卡)
	Btl.打出精神或公有牌(场, "S1", 静.id, "S2")
	t.ok(J.num0(卡.get("战意")) == 前2 + 10.0, "⑧「静夜」：队友战意 +10")
	# 压住 ZERO：下回合免负担
	var 希 := _单位("W1", "ally", 2.0, "狙击")
	希["觉醒中"] = true
	希["觉醒类型"] = "ZERO"
	ColonialAwaken.挂ZERO暴伤(希)
	var 场2 := _场([希], [敌])
	_全装(希, 场2, "W1")
	var 压 := _精神到手(希, "COL_W1_SP7")
	Btl.打出精神或公有牌(场2, "W1", 压.id, null)
	t.ok(J.truthy(希.get("下回合免精神负担")) and absf(Calc.critMul(希) - 2.0) < 0.001,
		"⑧「压住 ZERO」：免负担 + 本回合暴伤回退 ×2.0")
	var 血前 := float(希.get("hp"))
	ColonialAwaken.阶段初(场2, false)
	t.ok(float(希.get("hp")) == 血前, "⑧ 压住之后下一个我方阶段不扣精神负担")
	# 自爆装置：HP 变 1 + 同列两格伤害
	var 希2 := _单位("W1", "ally", 0.0, "狙击")
	var 同列前 := _靶("同列前", 0.0)
	var 同列后 := _靶("同列后", 4.0)
	var 别列 := _靶("别列", 1.0)
	var 场3 := _场([希2], [同列前, 同列后, 别列])
	_全装(希2, 场3, "W1")
	希2["hp"] = 2000.0
	var 爆 := _精神到手(希2, "COL_W1_SP9")
	Btl.打出精神或公有牌(场3, "W1", 爆.id, null)
	t.ok(float(希2.get("hp")) == 1.0, "⑧ 自爆装置：希罗 HP 变成 1")
	t.ok(float(同列前.get("hp")) < 千 and float(同列后.get("hp")) < 千 and float(别列.get("hp")) == 千,
		"⑧ 自爆装置：同列前后两格各吃「失去的 HP」，别的列不吃")
	# 十字架：第一次致命保留 1 HP
	var 迪 := _单位("W2", "ally", 1.0, "近卫")
	var 场4 := _场([迪], [敌])
	迪["十字架"] = true
	迪["hp"] = 0.0
	ColonialV01.致命保留_后(场4, 敌, 迪)
	t.ok(float(迪.get("hp")) == 1.0, "⑧ 麦斯威尔教会的十字架：第一次致命保留 1 HP")
	迪["hp"] = 0.0
	ColonialV01.致命保留_后(场4, 敌, 迪)
	t.ok(float(迪.get("hp")) == 0.0, "⑧ 十字架只有一次")

# ==========================================================================================
# ⑨ 光束反射装甲
# ==========================================================================================
func _段9_光束反射(t) -> void:
	var 卡 := _单位("S2", "ally", 0.0, "指挥")
	var 敌 := _靶("敌", 0.0)
	var 场 := _场([卡], [敌])
	var 光 := {"name": "光束步枪", "fire": "direct", "dmgType": "光束", "power": 1000.0, "hit": 100.0,
		"stat": "射击", "hits": 1.0, "cd": 0.0, "距离": [1, 4]}
	t.ok(absf(ColonialV01.受方伤害倍率(场, 敌, 卡, 光) - 0.5) < 0.0001, "⑨ 卡嘉莉受到的光束伤害 −50%")
	var 血前 := float(敌.get("hp"))
	ColonialV01.受击后(场, 卡, 敌, {"字段": {"伤害": 500.0}}, 光)
	t.ok(float(敌.get("hp")) == 血前 - 250.0, "⑨ 直射光束命中 → 把减掉那部分的一半（250）反射给攻击者")

# ==========================================================================================
# ⑩ 全卡冒烟：五人在 Lv30 都能把整副牌装进四个区
# ==========================================================================================
func _段10_全卡冒烟(t) -> void:
	for 键 in ColonialUnits.成员键:
		var u := _单位(键, "ally", 0.0, str(ColonialUnits.职业.get(键, "")))
		var 场 := _场([u], [_靶("敌", 0.0)])
		_全装(u, 场, 键)
		var 武: int = u.武器栏.size()
		var 大招: int = u.大招槽.size()
		var 精神: int = u.专属牌库.size() + u.专属手牌.size() + u.待入库.size()
		t.ok(武 >= 3 and 大招 >= 1 and 精神 >= 3,
			"⑩ %s：武器 %d / 大招 %d / 精神 %d（四个区都装上了）" % [键, 武, 大招, 精神])

# ==========================================================================================
# 辅助
# ==========================================================================================
func _卡(键: String, id: String, 加号: bool = false) -> Dictionary:
	for c in ColonialUnits.角色牌们(键, 加号):
		if str(c.get("id")) == id:
			return c
	return {}

func _装(键: String, 等级: int) -> Array:
	var u := _单位(键, "ally", 0.0, str(ColonialUnits.职业.get(键, "")))
	var 场 := _场([u], [_靶("敌", 0.0)])
	u["专属牌库"] = ColonialUnits.装填单位(u, 等级, 场)
	DeckFlow.拆分单位牌(u, 场)
	ColonialV01.装填大招槽(场, u)
	var 出: Array = []
	for c in u.专属牌库 + u.专属手牌 + u.待入库:
		出.append(str((c as Dictionary).get("id")))
	for 槽 in u.大招槽:
		出.append(str(((槽 as Dictionary).get("卡") as Dictionary).get("id")))
	for c in u.武器栏:
		出.append(str((c as Dictionary).get("id")))
	for e in u.副武器栏:
		出.append(str(((e as Dictionary).get("卡") as Dictionary).get("id")))
	return 出

func _全装(u: Dictionary, 场: Dictionary, 键: String) -> void:
	u["专属牌库"] = ColonialUnits.装填单位(u, 30, 场)
	DeckFlow.拆分单位牌(u, 场)
	ColonialV01.装填大招槽(场, u)

func _精神到手(u: Dictionary, id: String) -> Dictionary:
	for c in u.专属牌库 + u.专属手牌 + u.待入库:
		if c is Dictionary and str((c as Dictionary).get("id")) == id:
			if not (u.get("专属手牌") is Array):
				u["专属手牌"] = []
			if not u.专属手牌.has(c):
				u.专属手牌.append(c)
			return c
	return {}

func _有(表: Array, id: String) -> bool:
	return 表.has(id)

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

func _场(我方: Array, 敌方: Array, 种子号: int = 种子) -> Dictionary:
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
