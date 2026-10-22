## CR-2 Batch A（**红灯复现**）：P2-2 / P2-3 / P2-4 / P2-5 的门禁。
##
## 四段各自守的不变量（破了就是红灯）：
##   A1 门面 `可打` 与内核出牌判定必须同源 —— 不同源就「门面亮着、点下去打不出来」。
##   A2 直调 `Calc.resolveAttack` 也要标 `本回合被攻击过` —— 否则刹那【武力介入】能对同一台重复触发。
##   A3 钳爪命中减益 / 「本回合被刹那打」要认**实际挨打**的那台，不是原目标。
##   A4 `算意图` 与 `嘲讽` 必须同源 —— 预告目标与实际挨打目标要一致。
extends RefCounted

const 种子 := 20261018
const 阶段数 := 3
## 每个我方阶段最多真打多少张（防「0 费回库 / 无限抽牌」把阶段跑成死循环）。
const 每阶段步数上限 := 40
## 靶机 HP（够厚，打不穿，方便逐条重置）。
const 靶HP := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	if not errors.is_empty():
		return
	_A1_手牌纯可打门禁(t)
	_A2_直调攻击也要标被攻击过(t)
	_A3_钳爪与刹那标记认准实际挨打那台(t)
	_A4_意图预告与改目标同源(t)
	_A3b_旁路攻击计入战况计数(t)
	_A4b_自爆也消费首击减伤(t)
	_C1_λ驱动保留原武器运行期冷却(t)
	_C2_永久层加临时层嵌套栈(t)
	_C3_λ觉醒不重复压栈并保住原武器(t)

## 四场战斗都走 `GameSession` 的**正式入口**（秘银 / ATX / 天人 五人 + 混编队），每场跑 3 个我方阶段；
## 每阶段把门面说 `可打 == true` 的牌逐张真打，任何一张失败 = 门面与内核不一致（✗ 带牌名 / 执行机体 / 原因）。
func _A1_手牌纯可打门禁(t) -> void:
	var 场们: Array = [
		["秘银五人", _开快速("秘银")],
		["ATX五人", _开快速("ATX")],
		["天人五人", _开天人()],
		["混编队", _开混编()],
	]
	for 一 in 场们:
		var 名 := str((一 as Array)[0])
		var s = (一 as Array)[1]
		if not (s is GameSession) or (s as GameSession).battle_ctx.is_empty():
			t.ok(false, "A1 P2-2 ★ %s：这一场战斗没开起来%s" % [名,
				"" if not (s is GameSession) else "（errors：%s）" % str((s as GameSession).errors)])
			continue
		_A1_跑一场(t, 名, s)

## 一场战斗的 3 个我方阶段全量扫描。返回 `{真打, 违规}`。
func _A1_跑一场(t, 名: String, s: GameSession) -> void:
	var 违规: Array = []
	var 真打 := 0
	var 已试 := {}
	for _阶段 in 阶段数:
		if s.battle_ctx.is_empty() or s.battle_ctx.get("result") != null:
			break
		_补满战意(s)
		var 步 := 0
		while 步 < 每阶段步数上限:
			步 += 1
			if not _A1_打一张可打的(t, s, 已试, 违规):
				break
			真打 += 1
		if s.battle_ctx.is_empty() or s.battle_ctx.get("result") != null:
			break
		s.end_player_turn()
	for v in 违规:
		t.ok(false, "A1 P2-2 ★ 手牌纯可打违规：%s" % str(v))
	if 违规.is_empty():
		t.ok(true, "A1 P2-2 ★ 手牌纯可打（%s）：门面标 `可打` 的牌真打 %d 张，%d 张全部 ok=true" %
			[名, 真打, 真打])

## 找到并真打**一张** `可打 == true` 的牌。返回 false = 这一阶段已经没有可打的牌了。
func _A1_打一张可打的(t, s: GameSession, 已试: Dictionary, 违规: Array) -> bool:
	for u in (s.battle_ctx.get("allies") as Array):
		if not (u is Dictionary) or float((u as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 键 := str((u as Dictionary).get("key", ""))
		for 上排 in [true, false]:
			var 列: Array = s.upper_hand_cards(键) if 上排 else s.lower_hand_cards(键)
			for c in 列:
				if not (c is Dictionary) or not bool((c as Dictionary).get("可打", false)):
					continue
				var 区 := str((c as Dictionary).get("区", ""))
				var 卡键 := str((c as Dictionary).get("手牌键", ""))
				var 印 := "%s|%s|%s" % [键, 区, 卡键]
				if 已试.has(印):
					continue
				已试[印] = true
				var 挑 := _A1_挑目标(s, u as Dictionary, c as Dictionary)
				if not bool(挑.get("可挑", false)):
					t.ok(false, "A1 P2-2 ★ 门面说可打，但没有合法目标：【%s】区=%s 执行机体=%s" % [
						str((c as Dictionary).get("名", "")), 区, 键])
					违规.append("门面说可打，但没有合法目标：【%s】区=%s 执行机体=%s 目标方=%s" % [
						str((c as Dictionary).get("名", "")), 区, 键, str((c as Dictionary).get("目标方", ""))])
					continue
				var 目标 := str(挑.get("目标", ""))
				s.select_battle_unit(键)
				var r: Dictionary = _A1_出牌(s, 区, 卡键, 目标)
				if not bool(r.get("ok", false)):
					违规.append("【%s】区=%s 执行机体=%s 目标方=%s 目标=%s → 门面说可打，内核拒绝：%s" % [
						str((c as Dictionary).get("名", "")), 区, 键,
						str((c as Dictionary).get("目标方", "")),
						("（免指派）" if 目标.is_empty() else 目标),
						str(r.get("为什么", str(r)))])
				return true
	return false

## 按门面给的 `目标方` 挑一个**合法**目标：友方 → 受伤最重的活队友，无 → 空（免指派），
## 敌方 → 用内核 `Reach.武器可达吗` 挑一台真打得到的敌机。
func _A1_挑目标(s: GameSession, u: Dictionary, 视图: Dictionary) -> Dictionary:
	var 方 := str(视图.get("目标方", "敌方"))
	var ctx: Dictionary = s.battle_ctx
	if 方 == "友方":
		var 首选 := ""
		for x in (ctx.get("allies") as Array):
			if not (x is Dictionary) or float((x as Dictionary).get("hp", 0.0)) <= 0.0:
				continue
			var 键 := str((x as Dictionary).get("key", ""))
			if 首选.is_empty():
				首选 = 键
			if float((x as Dictionary).get("hp", 0.0)) < float((x as Dictionary).get("maxHp", 0.0)):
				return {"可挑": true, "目标": 键}
		return {"可挑": not 首选.is_empty(), "目标": 首选}
	if 方 == "无":
		return {"可挑": true, "目标": ""}
	# ---- 敌方：真卡片上的武器决定「打得到哪几台」----
	var 活敌: Array = []
	for x in (ctx.get("enemies") as Array):
		if x is Dictionary and float((x as Dictionary).get("hp", 0.0)) > 0.0:
			活敌.append(x)
	if 活敌.is_empty():
		return {"可挑": false, "目标": ""}
	var 卡 := _A1_真卡(ctx, u, str(视图.get("手牌键", "")))
	var w = 卡.get("武器") if 卡 is Dictionary else null
	if not (w is Dictionary):
		return {"可挑": true, "目标": str((活敌[0] as Dictionary).get("key", ""))}
	for x in 活敌:
		if J.truthy(Reach.武器可达吗(ctx, u, w, x).get("ok")):
			return {"可挑": true, "目标": str((x as Dictionary).get("key", ""))}
	return {"可挑": false, "目标": ""}

## 视图 → 真卡片（`武器栏` / `副武器栏[].卡` / `大招槽[].卡` / `专属手牌` / `公有手牌` 都认）。
func _A1_真卡(ctx: Dictionary, u: Dictionary, 手牌键: String) -> Dictionary:
	var 池: Array = []
	for 名 in ["武器栏", "专属手牌"]:
		for x in J.or_(u.get(名), []):
			池.append(x)
	for e in J.or_(u.get("副武器栏"), []):
		if e is Dictionary and (e as Dictionary).get("卡") is Dictionary:
			池.append((e as Dictionary).get("卡"))
	for e in J.or_(u.get("大招槽"), []):
		if e is Dictionary and (e as Dictionary).get("卡") is Dictionary:
			池.append((e as Dictionary).get("卡"))
	for x in J.or_(ctx.get("公有手牌"), []):
		池.append(x)
	for x in 池:
		if x is Dictionary and str((x as Dictionary).get("id", "")) == 手牌键:
			return x
	return {}

func _A1_出牌(s: GameSession, 区: String, 卡键: String, 目标: String) -> Dictionary:
	match 区:
		"主武器卡":
			return s.play_unit_main_weapon(卡键, 目标)
		"副武器卡":
			return s.play_unit_sub_weapon(卡键, 目标)
		"大招槽卡":
			return s.play_unit_ultimate(卡键, 目标)
		"连携牌":
			return s.play_link_card(卡键, 目标)
		"衍生攻击卡":
			return s.play_unit_derived_card(卡键, 目标)
		_:
			return s.play_unit_spirit_or_public_card(卡键, 目标)

## 每个我方阶段开始先给满战意（门面 / 内核共用同一台单位的 `战意`，这不是门槛本身）。
func _补满战意(s: GameSession) -> void:
	for u in (s.battle_ctx.get("allies") as Array):
		if u is Dictionary:
			(u as Dictionary)["战意"] = 100.0

# ---- 四场战斗的「正式入口」 ----

func _开快速(阵容: String) -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_cr2_a1_%s.json" % 阵容
	s.start_quick_test_battle(阵容, 种子)
	return s

func _开天人() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_cr2_a1_cb.json"
	s.start_quick_battle_celestial(种子)
	return s

## 混编队：`start_new_run` → 造名册 / 出击 → `start_node_battle()`（都是门面正式命令）。
func _开混编() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_cr2_a1_mixed.json"
	if not s.start_new_run(种子, "混编"):
		return s
	var rs = s.run_state
	if rs == null:
		return s
	rs.level = 10                                    # 出击上限 → 6，五台都摆得上
	rs.roster.clear()
	rs.lineup.clear()
	for e in [["CB1", 0], ["CB3", 1], ["A1", 2], ["A6", 3], ["A7", 4]]:
		rs.roster[str(e[0])] = {"key": str(e[0]), "lv": 30, "hpRatio": 1.0}
		rs.lineup.append({"key": str(e[0]), "slot": int(e[1])})
	var 格 := _战斗格(s)
	if 格 < 0:
		return s
	rs.node_id = 格
	rs.map_data["当前节点类型"] = str(rs.cell_at(格).get("类型", ""))
	s.start_node_battle()
	if s.battle_ctx.is_empty():
		return s
	# 双人格切 `always`：保证至少出现一次哈雷路亚，「哈雷路亚能不能打下排公有牌」这条路才被扫到。
	s.battle_ctx["双人格切换模式"] = "always"
	# 有入库条件 / 每回合限次的公有牌门面 `可打` 与内核判定最容易不一致，所以手工塞进手牌。
	var 公: Array = s.battle_ctx["公有手牌"] if s.battle_ctx.get("公有手牌") is Array else []
	for 卡 in ClassCards.职业牌们():
		公.append((卡 as Dictionary).duplicate(true))
	for 卡 in CelestialV01.太阳炉卡表():
		公.append((卡 as Dictionary).duplicate(true))
	for 卡 in CelestialV01.势力牌们():
		公.append((卡 as Dictionary).duplicate(true))
	for 卡 in FacAtx.势力牌们():
		公.append((卡 as Dictionary).duplicate(true))
	s.battle_ctx["公有手牌"] = 公
	return s

## 找一个「走得过去、类型是战斗格」的格号（照 `test_presentation_smoke.gd` 的 `_找战斗格`）。
func _战斗格(s: GameSession) -> int:
	var 类型们 := ["作战", "普通", "精英", "守军", "侵蚀源"]
	if s.run_state == null:
		return -1
	for k in MapNavigator.cell_ids(s.run_state):
		var 格 = s.run_state.cell_at(k)
		if 格 is Dictionary and 类型们.has(str((格 as Dictionary).get("类型", ""))):
			return int(k)
	return -1

## 6 处直调（`atx_three.gd` 5 处 + `fac_atx.gd` 1 处）各一条，每条打一台**新鲜靶机**
## （重建场并抹掉 `本回合被攻击过`）——直调 `Calc.resolveAttack` 也算「打过它」。
func _A2_直调攻击也要标被攻击过(t) -> void:
	_A2_一条(t, "① AtxThree._贯穿打", "响介【左轮打桩机·全弹】(ATX1_W1)",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_1_贯穿打(c, 场))
	_A2_一条(t, "② AtxThree._多锁", "艾克赛琳【全开·嚎叫发射器】(ATX2_U2)",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_2_多锁(c, 场))
	_A2_一条(t, "③ AtxThree._切札", "响介【切札】(ATX1_U3)",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_3_切札(c, 场))
	_A2_一条(t, "④ AtxThree._再来一把", "响介【再来一把】(ATX1_S6)",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_4_再来一把(c, 场))
	_A2_一条(t, "⑤ AtxThree._追加段", "艾克赛琳【分裂导弹·齐射】(ATX2_U1) 的【强运】分支",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_5_追加段(c, 场))
	_A2_一条(t, "⑥ FacAtx._一发", "拉米亚【幻影凤凰】(U_ATX_7)",
		func(c: Dictionary, 场: Dictionary) -> void: _A2_6_一发(c, 场))

func _A2_一条(t, 函数名: String, 牌名: String, 打: Callable) -> void:
	var 场 := _A2_场()
	var c: Dictionary = 场["c"]
	var 靶: Dictionary = 场["靶"]
	var 刹: Dictionary = 场["刹"]
	靶["hp"] = 靶HP
	靶["maxHp"] = 靶HP
	靶.erase("本回合被攻击过")
	靶.erase("本回合被刹那打")
	打.call(c, 场)
	var 被攻 := J.truthy(靶.get("本回合被攻击过", false))
	var 武力 := CelestialV01.武力介入满足吗(c, 刹, 靶)
	t.ok(被攻 and 武力 == false,
		"A2 P2-3 ★ %s → %s：直调 `Calc.resolveAttack` 也算「打过它」——`靶.本回合被攻击过` = %s（期望 true）、`武力介入满足吗` = %s（期望 false）" %
		[函数名, 牌名, str(被攻), str(武力)])

## A2 的场：刹那是**非 TRANS-AM**（刚开局没开），这样【武力介入】的判据只剩「本回合被攻击过」。
func _A2_场() -> Dictionary:
	var 刹 := _单位("CB1", "ally", 0.0, "近卫", "天人")
	var 响 := _单位("A1", "ally", 1.0, "近卫", "ATX")
	var 艾 := _单位("A2", "ally", 2.0, "狙击", "ATX")
	var 拉 := _单位("A3", "ally", 3.0, "尖兵", "ATX")
	var 靶 := _靶("靶", 4.0)
	var c := _场([刹, 响, 艾, 拉], [靶])
	_装天人(c, 刹)
	_装ATX(c, 响)
	_装ATX(c, 艾)
	_装ATX(c, 拉)
	c["turn"] = 3.0
	_放开(刹)
	_放开(响)
	_放开(艾)
	_放开(拉)
	return {"c": c, "刹": 刹, "响": 响, "艾": 艾, "拉": 拉, "靶": 靶}

func _A2_1_贯穿打(c: Dictionary, 场: Dictionary) -> void:
	var 响: Dictionary = 场["响"]
	var 靶: Dictionary = 场["靶"]
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, _ATX卡("ATX1_W1"), 靶.get("key"))

func _A2_2_多锁(c: Dictionary, 场: Dictionary) -> void:
	var 艾: Dictionary = 场["艾"]
	var 靶: Dictionary = 场["靶"]
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 艾, _ATX卡("ATX2_U2"), 靶.get("key"))

func _A2_3_切札(c: Dictionary, 场: Dictionary) -> void:
	var 响: Dictionary = 场["响"]
	var 靶: Dictionary = 场["靶"]
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, _ATX卡("ATX1_U3"), 靶.get("key"))

## ④ 先打一发**故意全打空**的主武器（把命中打成 0），让【再来一把】有「打空的段」可重打。
func _A2_4_再来一把(c: Dictionary, 场: Dictionary) -> void:
	var 响: Dictionary = 场["响"]
	var 靶: Dictionary = 场["靶"]
	var 卡 := _ATX卡("ATX1_W1")
	(卡["武器"] as Dictionary)["hit"] = 0.0
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, 卡, 靶.get("key"))
	响["主武器已销毁"] = false
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, _ATX卡("ATX1_S6"), 靶.get("key"))

## ⑤【分裂导弹·齐射】的【强运】分支（数据里就是 `{"算子": "atx3", "动作": "追加段", "段数": 4}`）。
##    强运是掷硬币（会消耗随机数、受种子影响），红灯测试要**确定性**，所以直接走同一个
##    `AtxThree.执行算子` 把「关掉硬币、只留追加段」这一步拨出来（效果本体一字未改）。
func _A2_5_追加段(c: Dictionary, 场: Dictionary) -> void:
	var 艾: Dictionary = 场["艾"]
	var 靶: Dictionary = 场["靶"]
	c["_当前出牌者"] = 艾.get("key")
	c["_当前目标"] = 靶.get("key")
	AtxThree.执行算子({"ctx": c, "u": 艾, "card": _ATX卡("ATX2_U1")}, {"动作": "追加段", "段数": 4}, [])

## ⑥ 拉米亚【幻影凤凰】：旧「攻击」算子已随 7 张旧卡退役，这里直接喂管线本体 `_一发`。
func _A2_6_一发(c: Dictionary, 场: Dictionary) -> void:
	var 拉: Dictionary = 场["拉"]
	var 靶: Dictionary = 场["靶"]
	c["_当前出牌者"] = 拉.get("key")
	c["_当前目标"] = 靶.get("key")
	FacAtx._一发(c, 拉, 靶, _武(2600.0, 1), false)

## 援护把攻击接走以后，标记与减益必须挂在**实际挨打**的那台上（这里 = 前排 靶B，替正后方 靶A 接走）。
## 用例 1 = 刹那的「本回合被刹那打」；用例 2 = `GN 盾·钳爪` 的命中减益。
func _A3_钳爪与刹那标记认准实际挨打那台(t) -> void:
	# ---- 用例 1：刹那的「本回合被刹那打」----
	var 一 := _A3_场()
	if 一.is_empty():
		t.ok(false, "A3 P2-4 ★ 用例 1 的场没搭起来")
	else:
		var c: Dictionary = 一["c"]
		var 靶A: Dictionary = 一["靶A"]
		var 靶B: Dictionary = 一["靶B"]
		var r: Dictionary = Btl.打出武器栏卡(c, "CB1", "CB1_W1", 靶A.get("key"))
		t.ok(J.truthy(靶B.get("本回合被刹那打")) and not J.truthy(靶A.get("本回合被刹那打")),
			"A3 P2-4 ★ 用例 1（刹那 CB1_W1 打 靶A，被 靶B 援护接走）：`靶B.本回合被刹那打` = %s（期望 true）、`靶A.本回合被刹那打` = %s（期望 false）｜出牌结果 %s" %
			[str(J.truthy(靶B.get("本回合被刹那打"))), str(J.truthy(靶A.get("本回合被刹那打"))), str(r.get("原因", r.get("成功")))])
	# ---- 用例 2：GN 盾·钳爪 的命中减益 ----
	var 二 := _A3_场()
	if 二.is_empty():
		t.ok(false, "A3 P2-4 ★ 用例 2 的场没搭起来")
	else:
		var c2: Dictionary = 二["c"]
		var A: Dictionary = 二["靶A"]
		var B: Dictionary = 二["靶B"]
		var r2: Dictionary = Btl.打出武器栏卡(c2, "CB3", "CB3_W3", A.get("key"))
		var B减 := _命中减益(B, "GN 盾·钳爪")
		var A减 := _命中减益(A, "GN 盾·钳爪")
		t.ok(B减 != 0.0 and A减 == 0.0,
			"A3 P2-4 ★ 用例 2（阿雷路亚 CB3_W3 钳爪打 靶A，被 靶B 援护接走）：命中减益挂在 靶B = %s（期望非 0）、挂在 靶A = %s（期望 0）｜出牌结果 %s" %
			[J.s(B减), J.s(A减), str(r2.get("原因", r2.get("成功")))])

## 这条 `src` 里含 `子串` 的命中减益值（没有 = 0）。`src` = 卡名（`GN 盾·钳爪` / `GN 盾·钳爪+` 都认）。
func _命中减益(u: Dictionary, 子串: String) -> float:
	for b in J.or_(u.get("buffs"), []):
		if b is Dictionary and str((b as Dictionary).get("src", "")).contains(子串):
			return J.num0((b as Dictionary).get("hit"))
	return 0.0

## A3 的场：刹那（slot 0）/ 阿雷路亚（slot 1）+ 靶B（前排 slot 0）/ 靶A（后排同列 slot 4）。
func _A3_场() -> Dictionary:
	var 刹 := _单位("CB1", "ally", 1.0, "近卫", "天人")
	var 雷 := _单位("CB3", "ally", 0.0, "特种", "天人")
	var 靶B := _靶("靶B", 0.0)
	var 靶A := _靶("靶A", 4.0)
	靶B["靶机援护"] = true
	靶B["靶机援护槽"] = 0
	靶B["靶机被护槽"] = 4
	靶B["靶机援护上限"] = 2
	靶B["靶机援护剩余"] = 2
	var c := _场([刹, 雷], [靶B, 靶A])
	_装天人(c, 刹)
	_装天人(c, 雷)
	c["turn"] = 2.0
	_放开(刹)
	_放开(雷)
	# 用例 2 要「近战指定打后排」而 靶B 还站在前排，所以只放宽「打得到」，不碰 命中减 / 援护 判定：
	#   ① 【后方渗透】增益（`Reach.有后方渗透` 认的就是它）；② 本牌武器距离临时放宽到 1–7（同列前↔后 = 2）。
	Btl.换同源增益(雷, "后方渗透", {"渗透": true, "剩余": 1.0})
	for 卡 in J.or_(雷.get("武器栏"), []):
		if 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == "CB3_W3":
			((卡 as Dictionary)["武器"] as Dictionary)["距离"] = [1, 7]
			((卡 as Dictionary)["武器"] as Dictionary)["range"] = [1, 7]
	return {"c": c, "刹": 刹, "雷": 雷, "靶A": 靶A, "靶B": 靶B}

## 改目标（横向掩护 / 铁壁护卫）必须在预告和实际结算里同源：预告目标 == 实际挨打目标；
## 且 `算意图` 是纯读 —— 预告前后护卫状态不许被扣。两个用例只是开牌方式不同。
func _A4_意图预告与改目标同源(t) -> void:
	_A4_一条(t, "用例 1（CC_H3 横向掩护）", true)
	_A4_一条(t, "用例 2（铁壁护卫）", false)

func _A4_一条(t, 名: String, 用横向掩护: bool) -> void:
	var 场 := _A4_场()
	var c: Dictionary = 场["c"]
	var 重: Dictionary = 场["重"]
	var X: Dictionary = 场["X"]
	var 敌: Dictionary = 场["敌"]
	# ---- 前置：不打牌的时候，预告目标天然就是 X ----
	var 自然 := _意图目标(c, 敌)
	t.ok(自然 == str(X.get("key")),
		"A4 P2-5 %s 前置：没改目标时 `算意图` 的 `目标` == X（%s）" % [名, 自然])
	# ---- 开牌：横向掩护 / 铁壁护卫 ----
	if 用横向掩护:
		var 卡 := ClassCards.按名("横向掩护").duplicate(true)
		(c["公有手牌"] as Array).append(卡)
		var r: Dictionary = Btl.打出精神或公有牌(c, str(重.get("key")), str(卡.get("id")))
		t.ok(J.truthy(r.get("成功")), "A4 P2-5 %s 前置：塔斯克打出【横向掩护】%s" % [名, str(r.get("原因", ""))])
	else:
		# `Btl._执行铁壁护卫` 的本体就是这两句：一条同源增益 + `铁壁护卫中 = ctx.turn`。
		重["铁壁护卫中"] = c.turn
	# ---- ① 预告目标 == 护卫者 ----
	var 预告 := _意图目标(c, 敌)
	# ---- ② 预告不许扣次数 / 状态（`算意图` 是纯读：这两次前后必须一模一样）----
	if 用横向掩护:
		var 前 = 重.get("横向掩护Turn")
		var 后 = 重.get("横向掩护Turn")
		t.ok(str(前) == str(后) and J.same(后, c.get("turn")),
			"A4 P2-5 %s ②：预告前后【横向掩护】状态没被扣（`横向掩护Turn` %s → %s，期望都 = 本回合 %s）" %
			[名, str(前), str(后), str(c.get("turn"))])
	else:
		var 铁前 = 重.get("铁壁护卫中")
		var 铁后 = 重.get("铁壁护卫中")
		t.ok(str(铁前) == str(铁后) and J.same(铁后, c.get("turn")),
			"A4 P2-5 %s ②：预告前后【铁壁护卫】状态没被扣（`铁壁护卫中` %s → %s，期望都 = 本回合 %s）" %
			[名, str(铁前), str(铁后), str(c.get("turn"))])
	# ---- ③ 实际挨打的是护卫者 ----
	var 实 := _打一轮(敌, c)
	t.ok(预告 == str(重.get("key")) and 实 == str(重.get("key")),
		"A4 P2-5 %s ①③：预告目标 = %s（期望 %s）、实际受击 = %s（期望 %s）" %
		[名, 预告, str(重.get("key")), 实, str(重.get("key"))])

## `算意图` 里这台敌机的预告目标键。
func _意图目标(c: Dictionary, 敌: Dictionary) -> String:
	for 条 in Btl.算意图(c):
		if 条 is Dictionary and str((条 as Dictionary).get("单位", "")) == str(敌.get("key", "")):
			var v = (条 as Dictionary).get("目标")
			return str(v) if v != null else ""
	return ""

## A4 的场：塔斯克 A6（重装·前排 slot 1）+ X（近卫·前排 slot 0，血更低 → AI 天然打它）
##         + 1 台单体攻击敌机（近战，`pickLowestHp` 会挑血最低的那个）。
func _A4_场() -> Dictionary:
	var 重 := _单位("A6", "ally", 1.0, "重装", "ATX")
	重["hp"] = 8000.0
	重["maxHp"] = 8000.0
	重["lv"] = 30.0
	var X := _单位("X", "ally", 0.0, "近卫", "ATX")
	X["hp"] = 3000.0
	X["maxHp"] = 3000.0
	X["lv"] = 30.0
	var 敌 := _靶("敌", 0.0)
	敌["weapons"] = [{"t": _武(1000.0, 1, 100.0, "melee"), "cd": 0.0, "uses": null, "readyTurn": 0.0}]
	var c := _场([重, X], [敌])
	c["turn"] = 2.0
	return {"c": c, "重": 重, "X": X, "敌": 敌}

## 跑一轮敌方行动，返回它实际打的那个目标键（`Flow.actOnce` + 最后一条攻击记录）。
func _打一轮(敌: Dictionary, c: Dictionary) -> String:
	Flow.actOnce(敌, c)
	for i in range((J.or_(c.get("log"), []) as Array).size() - 1, -1, -1):
		var e = (c["log"] as Array)[i]
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
			var v = (e as Dictionary).get("目标")
			return str(v) if v != null else ""
	return ""

## 响介把 `hit` 改成 0 打空 N 段，再用【再来一把】重打一次：旁路重打那一发也要计入 `战况计数.未命中段`。
func _A3b_旁路攻击计入战况计数(t) -> void:
	var 场 := _A2_场()
	var c: Dictionary = 场["c"]
	var 响: Dictionary = 场["响"]
	var 靶: Dictionary = 场["靶"]
	var 卡 := _ATX卡("ATX1_W1")
	(卡["武器"] as Dictionary)["hit"] = 0.0
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, 卡, 靶.get("key"))
	响["主武器已销毁"] = false
	var 段 := AtxThree.上次打空段(响)
	var 前 := J.num0((c["战况计数"] as Dictionary).get("未命中段"))
	c["_当前目标"] = 靶.get("key")
	AtxThree.打出牌(c, 响, _ATX卡("ATX1_S6"), 靶.get("key"))
	var 后 := J.num0((c["战况计数"] as Dictionary).get("未命中段"))
	t.ok(段 > 0 and int(后 - 前) == 段,
		"CR-3 A3 ★ 旁路【再来一把·重打】也计入 `战况计数`：重打 %d 段、`未命中段` %s → %s（期望精确 +%d）" %
		[段, J.s(前), J.s(后), 段])

## 两场同种子对照（挂 / 不挂 `GN 全盾·哈罗`，`cb首击减伤 = 0.4`）：走 `旁路攻击` 的【自爆】
## 也要吃到 −40%，并且把「首击减伤」消费掉 —— 之后那发普通攻击不再享受减伤。
func _A4b_自爆也消费首击减伤(t) -> void:
	var 有盾 := _A4b_场(true)
	var 无盾 := _A4b_场(false)
	var 伤有 := _A4b_打一发(有盾, true)
	var 伤无 := _A4b_打一发(无盾, true)
	var 期望 := J.round(float(伤无) * 0.6)
	t.ok(float(伤有) > 0.0 and absf(float(伤有) - 期望) <= 1.0,
		"CR-3 A4 ★ 旁路【自爆】照样吃到 −40%% 首击减伤：有哈罗 %s、没哈罗 %s（期望 %s）" %
		[J.s(伤有), J.s(伤无), J.s(期望)])
	var 盾清 := not (有盾["天人"] as Dictionary).has("cb首击减伤") \
		and int(J.num0((有盾["天人"] as Dictionary).get("cb首击减伤剩余", 0.0))) <= 0
	t.ok(盾清, "CR-3 A4 ★ 自爆那一发就消费掉 `首击减伤`（`cb首击减伤` / `cb首击减伤剩余` 已清空）")
	var 普有 := _A4b_打一发(有盾, false)
	var 普无 := _A4b_打一发(无盾, false)
	t.ok(absf(float(普有) - float(普无)) <= 1.0,
		"CR-3 A4 ★ 紧接着的普通攻击不再享受 −40%%：有哈罗 %s、没哈罗 %s（期望相等）" %
		[J.s(普有), J.s(普无)])

## A4 的场：天人机体站 slot 4（与敌机 slot 0 同列），挨敌机【自爆】的 `col` 落点。
func _A4b_场(有盾: bool) -> Dictionary:
	var 天 := _单位("CB1", "ally", 4.0, "近卫", "天人")
	天["hp"] = 靶HP
	天["maxHp"] = 靶HP
	var 敌 := _靶("敌", 0.0)
	敌["weapons"] = [{"t": _武(1000.0, 1, 100.0, "direct"), "cd": 0.0, "uses": null, "readyTurn": 0.0}]
	var c := _场([天], [敌])
	c["turn"] = 2.0
	if 有盾:
		天["cb首击减伤"] = 0.40
		天["cb首击减伤剩余"] = 1
	return {"c": c, "天人": 天, "敌": 敌}

## 打一发并返回天人机体掉了多少 HP。`自爆 = true` → 走 `Btl.自爆`（`旁路攻击` 那条路）；
## 否则走一发普通攻击（`改目标: false`，不让援护把它接走）。
func _A4b_打一发(场: Dictionary, 自爆: bool) -> float:
	var c: Dictionary = 场["c"]
	var 天: Dictionary = 场["天人"]
	var 敌: Dictionary = 场["敌"]
	var 前 := float(天.get("hp", 0.0))
	if 自爆:
		Btl.自爆(c, 敌, 敌, null, true)
	else:
		Flow.结算一个目标(c, 敌, 天, _武(1000.0, 1, 100.0, "direct"), {"改目标": false})
	return 前 - float(天.get("hp", 0.0))

## λ 还原必须给回**原来那个卡对象**（`is_same`），不许拿卡表重建 —— 重建会把运行期 `cd` 清零；
## 这里先给主武器写上 `cd = 2`、再换装 / 还原，冷却必须还是 2。
func _C1_λ驱动保留原武器运行期冷却(t) -> void:
	var c := Setup.开局([{"键": "U7", "位": 0, "等级": 30}],
		[{"键": "fighter", "位": 0, "等级": 1}], 种子, null, {"单机牌组": true, "秘银v03": true})
	var u7 := {}
	for x in J.or_(c.get("allies"), []):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == "U7":
			u7 = x
	if u7.is_empty():
		t.ok(false, "CR-3 C1 ★ 宗介 U7 没开起来（`Setup.开局` 没给出这台机体）")
		return
	var 栏: Array = J.or_(u7.get("武器栏"), [])
	var 位 := -1
	for i in 栏.size():
		if 栏[i] is Dictionary and str((栏[i] as Dictionary).get("id", "")) == "V3_U7_W1":
			位 = i
	if 位 < 0:
		t.ok(false, "CR-3 C1 ★ 宗介武器栏里找不到 V3_U7_W1（%s）" % str(_id们(栏)))
		return
	var 原卡: Dictionary = 栏[位]
	原卡["cd"] = 2.0
	DeckFlow.λ换武器(c, u7)
	var λid: Array = _id们(J.or_(u7.get("武器栏"), []))
	t.ok(λid.has("V3_U7_LW1") and λid.has("V3_U7_LW2") and λid.has("V3_U7_LW3"),
		"CR-3 C1 ★ λ 换武器：武器栏换成 LW1 / LW2 并新增 LW3（%s）" % str(λid))
	t.ok(DeckFlow.当前换装来源(u7) == ["λ驱动"],
		"CR-3 C1 ★ λ 层进了 `武器栏栈`（当前换装来源 = %s）" % str(DeckFlow.当前换装来源(u7)))
	DeckFlow.λ还原武器(u7)
	var 回栏: Array = J.or_(u7.get("武器栏"), [])
	t.ok(回栏.size() == 栏.size() and 位 < 回栏.size() and is_same(回栏[位], 原卡),
		"CR-3 C1 ★ λ 还原后 `u.武器栏[%d]` 与压栈前是**同一个 Dictionary 引用**（is_same）" % 位)
	t.ok(位 < 回栏.size() and absf(float((回栏[位] as Dictionary).get("cd", -1.0)) - 2.0) < 0.001,
		"CR-3 C1 ★ 原武器的运行期冷却 `cd = 2` **没有被重置**（现 %s）" %
		(J.s((回栏[位] as Dictionary).get("cd")) if 位 < 回栏.size() else "?"))
	t.ok(DeckFlow.当前换装来源(u7).is_empty(),
		"CR-3 C1 ★ λ 还原后换装栈清空（当前换装来源 = %s）" % str(DeckFlow.当前换装来源(u7)))

## 永久层（`"脱装"`）之下再压一层临时层（`"METEOR"`）：弹掉临时层要回到**永久层那张表**（纳德雷），
## 不是最初始的德天使表；永久层本身弹不掉（`弹栈武器栏` 返回 false）。
func _C2_永久层加临时层嵌套栈(t) -> void:
	var u := _单位("CB4", "ally", 4.0, "重装", "天人")
	var c := _场([u], [_靶("靶前", 0.0)])
	for x in CelestialV01.装填单位(u, 30, c):
		(u["专属牌库"] as Array).append(x)
	DeckFlow.拆分单位牌(u, c)
	CelestialV01.装填大招槽(c, u)
	var 原表: Array = (u.get("武器栏") as Array).duplicate(false)
	var 原id: Array = _id们(原表)
	t.ok(原id == ["CB4_W1", "CB4_W2", "CB4_W3"],
		"CR-3 C2 ★ 提耶利亚脱装前武器栏 = 德天使 %d 把（%s）" % [原id.size(), str(原id)])
	DeckFlow.压栈武器栏(u, CelestialV01.纳德雷武器表("CB4"), "脱装", true, c)
	var 纳德雷: Array = u["武器栏"]
	var 纳id: Array = _id们(纳德雷)
	t.ok(纳id == ["CB4_NW1", "CB4_NW2", "CB4_NW3"],
		"CR-3 C2 ★ 压 `\"脱装\"` 永久层 → 纳德雷 %d 把（%s）" % [纳id.size(), str(纳id)])
	var 临时卡 := {"id": "CR3_METEOR_W1", "名": "METEOR 试作炮", "卡类": "主武器卡", "id前缀": "CR3",
		"武器": {"name": "METEOR 试作炮", "fire": "direct", "dmgType": "物理", "power": 3000.0,
			"hit": 100.0, "stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": []}}
	DeckFlow.压栈武器栏(u, [临时卡], "METEOR", false, c)
	t.info("武器栏栈（脱装 + 一层临时层）= " + _栈快照(u.get("武器栏栈")))
	t.ok(DeckFlow.当前换装来源(u) == ["脱装", "METEOR"],
		"CR-3 C2 ★ 栈底 → 栈顶 = %s" % str(DeckFlow.当前换装来源(u)))
	DeckFlow.压栈武器栏(u, [临时卡], "METEOR", false, c)
	t.ok(DeckFlow.当前换装来源(u).size() == 2,
		"CR-3 C2 ★ 同一来源重复压栈被忽略（栈仍 %d 层）" % DeckFlow.当前换装来源(u).size())
	t.ok(DeckFlow.弹栈武器栏(u, "METEOR"), "CR-3 C2 ★ `弹栈武器栏(u, \"METEOR\")` = true")
	var 回栏: Array = J.or_(u.get("武器栏"), [])
	t.ok(回栏.size() == 3 and is_same(回栏[0], 纳德雷[0]) and _id们(回栏) == 纳id,
		"CR-3 C2 ★ 弹掉临时层 → 回到**纳德雷武器表**（%d 把、同一批卡对象；%s）" %
		[回栏.size(), str(_id们(回栏))])
	t.ok(_id们(回栏) != 原id, "CR-3 C2 ★ 没有回到德天使原表（%s ≠ %s）" %
		[str(_id们(回栏)), str(原id)])
	t.ok(DeckFlow.当前换装来源(u) == ["脱装"],
		"CR-3 C2 ★ 当前换装来源 = %s" % str(DeckFlow.当前换装来源(u)))
	t.ok(not DeckFlow.弹栈武器栏(u, "脱装"), "CR-3 C2 ★ `弹栈武器栏(u, \"脱装\") == false`（永久层弹不掉）")
	t.ok(DeckFlow.当前换装来源(u) == ["脱装"], "CR-3 C2 ★ 永久层还在栈里")

## 宗介先 `开启λ` 再 `λ觉醒触发`：栈里已有 `"λ驱动"` 层时必须**先弹栈再压**，不许叠成两层，
## 也不许多写「重复压栈被忽略」那一行战报；常驻【隔空 λ 拳】LW3 照旧拿得到。
## `λ还原武器` 仍要回到**最初始那个原武器对象**（`is_same`）且运行期冷却不重置。
func _C3_λ觉醒不重复压栈并保住原武器(t) -> void:
	var c := Setup.开局([{"键": "U7", "位": 0, "等级": 30}],
		[{"键": "fighter", "位": 0, "等级": 1}], 种子, null, {"单机牌组": true, "秘银v03": true})
	var u7 := {}
	for x in J.or_(c.get("allies"), []):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == "U7":
			u7 = x
	if u7.is_empty():
		t.ok(false, "CR-3 C3 ★ 宗介 U7 没开起来（`Setup.开局` 没给出这台机体）")
		return
	var 栏: Array = J.or_(u7.get("武器栏"), [])
	var 位 := -1
	for i in 栏.size():
		if 栏[i] is Dictionary and str((栏[i] as Dictionary).get("id", "")) == "V3_U7_W1":
			位 = i
	if 位 < 0:
		t.ok(false, "CR-3 C3 ★ 宗介武器栏里找不到 V3_U7_W1（%s）" % str(_id们(栏)))
		return
	var 原卡: Dictionary = 栏[位]
	原卡["cd"] = 3.0
	var 原张数 := 栏.size()
	DeckFlow.开启λ(c, u7)
	var 开id: Array = _id们(J.or_(u7.get("武器栏"), []))
	t.ok(DeckFlow.λ开启(u7) and not DeckFlow.λ觉醒(u7),
		"CR-3 C3 ★ 先 `λ开启`：λ 开启中、还没觉醒")
	t.ok(开id.has("V3_U7_LW1") and 开id.has("V3_U7_LW2"),
		"CR-3 C3 ★ 开启后武器栏换上 LW1 / LW2（%s）" % str(开id))
	t.ok(DeckFlow.当前换装来源(u7) == ["λ驱动"] and str(u7.get("武器栏切换模式")) == "overlay",
		"CR-3 C3 ★ 换装栈一层 `λ驱动`、兼容镜像 `武器栏切换模式 == \"overlay\"`（现 %s）" %
		str(u7.get("武器栏切换模式")))
	var 基线: int = J.or_(c.get("log"), []).size()
	t.ok(DeckFlow.λ觉醒触发(c, u7), "CR-3 C3 ★ `λ觉醒触发` 返回 true（真的触发了 λ 觉醒）")
	var 醒id: Array = _id们(J.or_(u7.get("武器栏"), []))
	t.ok(DeckFlow.λ觉醒(u7) and 醒id.has("V3_U7_LW3"),
		"CR-3 C3 ★ 觉醒后武器栏里仍有 `V3_U7_LW3`（隔空 λ 拳；%s）" % str(醒id))
	t.ok(DeckFlow.当前换装来源(u7) == ["λ驱动"],
		"CR-3 C3 ★ 觉醒没有把 `λ驱动` 叠成两层（当前换装来源 = %s）" % str(DeckFlow.当前换装来源(u7)))
	var 新行: Array = J.or_(c.get("log"), []).slice(基线)
	var 重复行: Array = 新行.filter(func(行): return str(行).contains("重复压栈被忽略"))
	t.ok(重复行.is_empty(),
		"CR-3 C3 ★ 觉醒这一段没有「重复压栈被忽略」的战报行（新增 %d 行全查过）" % 新行.size())
	DeckFlow.λ还原武器(u7)
	var 回栏: Array = J.or_(u7.get("武器栏"), [])
	t.ok(回栏.size() == 原张数 and 位 < 回栏.size() and is_same(回栏[位], 原卡),
		"CR-3 C3 ★ λ 还原 → `u.武器栏[%d]` 仍是最初始那个原武器 Dictionary（is_same）" % 位)
	t.ok(位 < 回栏.size() and absf(float((回栏[位] as Dictionary).get("cd", -1.0)) - 3.0) < 0.001,
		"CR-3 C3 ★ 原武器的运行期冷却 `cd = 3` 没有被重置（现 %s）" %
		(J.s((回栏[位] as Dictionary).get("cd")) if 位 < 回栏.size() else "?"))
	t.ok(DeckFlow.当前换装来源(u7).is_empty() and u7.get("武器栏切换模式") == null,
		"CR-3 C3 ★ 换装栈清空、兼容镜像 `武器栏切换模式` 一并抹掉")

## 一组武器卡 / 卡 id 的字符串清单（回执与断言里看得懂）。
func _id们(表: Variant) -> Array:
	var 出: Array = []
	for c in (表 if 表 is Array else []):
		出.append(str((c as Dictionary).get("id", "?")) if c is Dictionary else str(c))
	return 出

## `u.武器栏栈` 的紧凑可读快照（每层 = 来源 / 永久 / 原表的卡 id）。
func _栈快照(栈: Variant) -> String:
	var 出: Array = []
	for 层 in (栈 if 栈 is Array else []):
		if not (层 is Dictionary):
			continue
		出.append('{"来源": "%s", "永久": %s, "原表": [%s]}' % [
			str((层 as Dictionary).get("来源", "")),
			"true" if J.truthy((层 as Dictionary).get("永久")) else "false",
			"、".join(_id们((层 as Dictionary).get("原表")))])
	return "[" + "，".join(出) + "]"

# 夹具
func _单位(键: String, side: String, 位: float, 职业: String, 势力: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 30.0,
		"maxHp": 8000.0, "hp": 8000.0,
		"melee": 200.0, "shoot": 200.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": ({"战斗分类": 职业, "势力": 势力} if not 职业.is_empty() else {}), "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _靶(键: String, 位: float) -> Dictionary:
	var e := _单位(键, "enemy", 位, "", "")
	e["tags"] = {}
	e["hp"] = 靶HP
	e["maxHp"] = 靶HP
	e["melee"] = 0.0
	e["shoot"] = 0.0
	return e

func _场(我方: Array, 敌方: Array) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	CelestialV01.初始化(c)
	return c

func _武(威力: float, 段数: int, 命中率: float = 100.0, fire: String = "direct") -> Dictionary:
	return {"name": "测试武器", "fire": fire, "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

## 给一台天人机体装满 v0.1 卡（装填 → 拆分 → 大招槽），与正式开局同一条路。
func _装天人(c: Dictionary, u: Dictionary) -> void:
	for x in CelestialV01.装填单位(u, 30, c):
		(u["专属牌库"] as Array).append(x)
	DeckFlow.拆分单位牌(u, c)
	CelestialV01.装填大招槽(c, u)

## 给一台 ATX 机体装满 v0.1 卡（同上）。
func _装ATX(c: Dictionary, u: Dictionary) -> void:
	for x in AtxThree.装填单位(u, 30, c):
		(u["专属牌库"] as Array).append(x)
	DeckFlow.拆分单位牌(u, c)
	AtxThree.装填大招槽(c, u, 30)

## 把一台机体的出牌门槛全部放开（战意 / 主武器 / 大招槽解锁 / 冷却）—— 这是夹具，不是被验的门槛。
func _放开(u: Dictionary) -> void:
	u["战意"] = 100.0
	u["主武器已销毁"] = false
	for 槽 in J.or_(u.get("大招槽"), []):
		if 槽 is Dictionary:
			(槽 as Dictionary)["已解锁"] = true
			(槽 as Dictionary)["本回合已打"] = false
			(槽 as Dictionary)["cd"] = 0.0
	for e in J.or_(u.get("副武器栏"), []):
		if e is Dictionary:
			(e as Dictionary)["本回合已用"] = 0
			(e as Dictionary)["本回合可用"] = 99

## `AtxThree` 卡表里按 id 取一张**副本**。
func _ATX卡(id: String) -> Dictionary:
	for c in AtxThree.卡表():
		if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	return {}
