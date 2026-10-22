## 试玩反馈迭代（10-21 夜起）的回归测试：一条反馈一段，防止修好的问题回来。
extends RefCounted

func run(t) -> void:
	var 错误 := []
	DataLoader.install(错误)
	_段1_双子开局整套武器(t)
	_段2_招不了的灰掉写原因(t)
	_段3_失败原因留到下一次做成(t)
	_段4_第一层减负(t)
	_段5_响介玻璃大炮与押注(t)
	_段6_连携给宗介充能(t)
	_段7_敌方意图连线(t)
	_段8_集火破绽(t)

## 段 1：塔斯克 / 雷欧娜的牌都标「开局在手」= 初始牌，Lv10 就该拿到 3 把主武器 + 1 张大招；
## 雷欧娜站后排也得有够得着的武器（试玩里她整场只能打精神牌）。
func _段1_双子开局整套武器(t) -> void:
	var 选项 := SessionBattleOptions.生产(null)
	for 键 in ["A6", "A7"]:
		var ctx := Setup.开局([{"键": 键, "位": 5, "等级": 10}], [{"键": "grunt", "位": 0, "等级": 1}], 20261021, null, 选项)
		var u: Dictionary = (ctx.allies as Array)[0]
		var 主 := (J.or_(u.get("武器栏"), []) as Array).size()
		var 大 := (J.or_(u.get("大招槽"), []) as Array).size()
		t.ok(主 == 3 and 大 == 1, "段1 %s Lv10：主武器 %d 张、大招 %d 张（要 3 / 1）" % [键, 主, 大])
		var 后排能打 := 0
		for c in J.or_(u.get("武器栏"), []):
			if str(CardPlay.主武器门槛(ctx, u, c)) == "":
				后排能打 += 1
		t.ok(后排能打 >= 1, "段1 %s 站后排、战意 0：至少 1 张主武器能打（%d 张）" % [键, 后排能打])

## 段 2：希望不够时，候选照样列出来，但标「可招 = false」+ 原因（招募屏据此灰掉）。
func _段2_招不了的灰掉写原因(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_it3_a.json"
	s.start_new_run(20261021, "混编")
	s.run_state.hope = 0
	var 候选 := s.available_recruit_targets(0)
	var 贵的 := 0
	var 都标了 := true
	for 条 in 候选:
		if int(条.get("费", 0)) > 0:
			贵的 += 1
			都标了 = 都标了 and not bool(条.get("可招", true)) and str(条.get("为什么", "")).begins_with("希望不足")
	t.ok(贵的 > 0 and 都标了, "段2 希望 0：%d 位要花希望的候选都标成「希望不足」" % 贵的)

## 段 3：没做成的原因留着（界面能显示），下一次做成了才清掉。
func _段3_失败原因留到下一次做成(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_it3_b.json"
	s.start_new_run(20261021, "混编")
	s.run_state.hope = 0
	var 贵键 := ""
	for 条 in s.available_recruit_targets(0):
		if int(条.get("费", 0)) > 0:
			贵键 = str(条.get("键"))
			break
	s.recruit_unit(贵键, 0)
	t.ok(s.当前动作错误().begins_with("希望不够"), "段3 招不起之后错误还挂着（%s）" % s.当前动作错误())
	s.run_state.hope = 99
	var r := s.recruit_unit(贵键, 0)
	t.ok(bool(r.get("ok", false)) and s.当前动作错误() == "", "段3 做成之后错误清掉（%s）" % s.当前动作错误())

## 段 4：第一层普通战减负（开场 3 台、增援 1 波 1 台）；第二层原样。
func _段4_第一层减负(t) -> void:
	var 条 := {"层": 1, "类型": "普通", "前": ["a", "b", "c"], "后": ["d", "e"],
		"波次": [{"回合": 2, "来": ["f", "g"]}, {"回合": 4, "来": ["h", "i"]}]}
	var 减 := NodeResolver.第一层减负(条)
	t.ok((减["前"] as Array).size() + (减["后"] as Array).size() == 3, "段4 第一层普通：开场 3 台")
	t.ok((减["波次"] as Array).size() == 1 and ((减["波次"][0] as Dictionary)["来"] as Array).size() == 1, "段4 第一层普通：增援 1 波 1 台")
	t.ok((条["前"] as Array).size() == 3, "段4 原条目没被改（截的是副本）")
	var 二 := 条.duplicate(true)
	二["层"] = 2
	t.ok(NodeResolver.第一层减负(二) == 二, "段4 第二层原样")

## 段 5：ATX【王牌】—— 响介开局装甲 / HP 下调；队友出手给响介押注，层数封顶，回合一换就清。
func _段5_响介玻璃大炮与押注(t) -> void:
	var 选项 := SessionBattleOptions.生产(null)
	var 关 := 选项.duplicate(true)
	关[FactionIdentity.选项键] = false
	var 我 := [{"键": "A1", "位": 1, "等级": 20}, {"键": "A2", "位": 5, "等级": 20}]
	var 敌 := [{"键": "grunt", "位": 0, "等级": 3}]
	var ctx := Setup.开局(我, 敌, 7, null, 选项)
	var 原 := Setup.开局(我, 敌, 7, null, 关)
	var 响: Dictionary = ctx.allies[0]
	var 响原: Dictionary = 原.allies[0]
	t.ok(float(响.armor) < float(响原.armor) and float(响.maxHp) < float(响原.maxHp) and float(响.eva) > float(响原.eva),
		"段5 响介玻璃大炮：甲 %d→%d、HP %d→%d、闪 %d→%d" % [响原.armor, 响.armor, 响原.maxHp, 响.maxHp, 响原.eva, 响.eva])
	var 艾: Dictionary = ctx.allies[1]
	var 敌机: Dictionary = ctx.enemies[0]
	var 倍0 := FactionIdentity.攻方伤害倍率(ctx, 响, 敌机, {})
	for _i in 5:
		FactionIdentity.武器攻击后(ctx, 艾, 敌机, 1, {})
	t.ok(FactionIdentity.押注层数(ctx) == FactionIdentity.押注上限, "段5 押注封顶 %d 层" % FactionIdentity.押注层数(ctx))
	var 倍3 := FactionIdentity.攻方伤害倍率(ctx, 响, 敌机, {})
	t.ok(is_equal_approx(倍3, 倍0 * (1.0 + FactionIdentity.押注每层 * FactionIdentity.押注上限)), "段5 押注满层倍率 %s（0 层 %s）" % [倍3, 倍0])
	FactionIdentity.武器攻击后(ctx, 响, 敌机, 1, {})
	t.ok(FactionIdentity.押注层数(ctx) == FactionIdentity.押注上限, "段5 响介自己出手不给自己押注")
	ctx["turn"] = int(ctx.get("turn", 1)) + 1
	t.ok(FactionIdentity.押注层数(ctx) == 0, "段5 换回合押注清零")
	t.ok(FactionIdentity.攻方伤害倍率(原, 响原, 敌机, {}) == 1.0, "段5 开关关掉 → 倍率 1")

## 段 6：秘银【Uruz 待机】—— 连携成功一次，宗介战意 +8。
func _段6_连携给宗介充能(t) -> void:
	var 选项 := SessionBattleOptions.生产(null)
	var ctx := Setup.开局([{"键": "U7", "位": 1, "等级": 20}, {"键": "U2", "位": 5, "等级": 20}],
		[{"键": "grunt", "位": 0, "等级": 3}], 7, null, 选项)
	var 宗: Dictionary = ctx.allies[0]
	var 前 := Btl.战意(宗)
	FactionIdentity.连携触发后(ctx)
	t.ok(is_equal_approx(Btl.战意(宗), 前 + FactionIdentity.连携充能), "段6 连携 → 宗介战意 %d → %d" % [前, Btl.战意(宗)])

## 段 7：战斗屏把敌方下一拍的意图画成连线（敌机 → 目标），条数 = 门面里「攻击」意图里两头都在场的条数。
func _段7_敌方意图连线(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_it5_intent.json"
	s.开始快速测试战斗("月球王国")
	var 要 := 0
	for x in s.enemy_intents():
		if x is Dictionary and str(x.get("动作类型", "")) == "攻击" and not str(x.get("目标", "")).is_empty():
			要 += 1
	var bv := BattleView.new()
	var 根 := (Engine.get_main_loop() as SceneTree).root
	根.add_child(bv)
	bv.setup(s)
	bv.refresh()
	var 画 := int(bv._战斗动画层.意图连线数())
	t.ok(要 > 0 and 画 == 要, "段7 意图连线 %d 条（门面里攻击意图 %d 条）" % [画, 要])
	根.remove_child(bv)
	bv.free()

## 段 8：【破绽】本回合被一台我方打中后，其他我方机体打它 ×1.15；同一台补刀不算；换回合清。
func _段8_集火破绽(t) -> void:
	var ctx := Setup.开局([{"键": "U1", "位": 1, "等级": 20}, {"键": "U2", "位": 2, "等级": 20}],
		[{"键": "grunt", "位": 0, "等级": 3}], 7, null, SessionBattleOptions.生产(null))
	var 甲: Dictionary = ctx.allies[0]
	var 乙: Dictionary = ctx.allies[1]
	var 敌: Dictionary = ctx.enemies[0]
	t.ok(FocusFire.攻方伤害倍率(ctx, 乙, 敌, {}) == 1.0, "段8 没人打过：倍率 1")
	FocusFire.武器攻击后(ctx, 甲, 敌, 0.0, {})
	t.ok(FocusFire.攻方伤害倍率(ctx, 乙, 敌, {}) == 1.0, "段8 打空（0 段命中）不算")
	FocusFire.武器攻击后(ctx, 甲, 敌, 2.0, {})
	t.ok(is_equal_approx(FocusFire.攻方伤害倍率(ctx, 乙, 敌, {}), 1.15), "段8 甲打中后乙 ×1.15")
	t.ok(FocusFire.攻方伤害倍率(ctx, 甲, 敌, {}) == 1.0, "段8 甲自己补刀不算")
	ctx["turn"] = int(ctx.get("turn", 1)) + 1
	t.ok(FocusFire.攻方伤害倍率(ctx, 乙, 敌, {}) == 1.0, "段8 换回合清零")

