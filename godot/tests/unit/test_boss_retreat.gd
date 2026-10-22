## 职责：敌方中途撤退（B 稿 N9）：到线 / 到回合撤离 → 移出战场、判我方胜利；结算希望 / 源碳减半、不发零件。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_到线(t)
	_到回合与条件(t)
	_结算减半(t)

func _开(我方: Array, 敌方: Array) -> Dictionary:
	var 我 := []
	for i in 我方.size():
		我.append({"键": 我方[i], "位": float(i), "等级": 30.0})
	var 敌 := []
	for i in 敌方.size():
		敌.append({"键": 敌方[i], "位": float(i)})
	return Setup.开局(我, 敌, 11)

func _到线(t) -> void:
	var ctx := _开(["B1"], ["h4", "grunt"])
	var 情: Dictionary = ctx.enemies[0]
	t.ok(Setup.checkResult(ctx) == null, "h4 满血：不撤")
	情.hp = float(情.maxHp) * 0.5
	var r = Setup.checkResult(ctx)
	t.ok(r is Dictionary and r.结果 == "胜" and r.get("撤退") == true and r.撤离单位 == "h4", "h4 HP 到 50%%：判我方胜利、带 撤退（%s）" % str(r))
	t.ok(not (ctx.enemies as Array).has(情) and (ctx.enemies as Array).size() == 1, "h4 从战场移除，护卫还在列表里")
	t.ok((ctx.log as Array).any(func(l): return str(l.get("类型", "")) == "撤离"), "写〔撤离〕战报")
	var ctx2 := _开(["B1"], ["h4"])
	ctx2.enemies[0].hp = 0.0
	var r2 = Setup.checkResult(ctx2)
	t.ok(r2 is Dictionary and r2.原因 == "敌方全灭" and r2.get("撤退") == null, "撤离前击破：正常胜利（全额）")
	var ctx3 := _开(["B1"], ["h2", "grunt"])
	ctx3.enemies[0].hp = 1.0
	t.ok(Setup.checkResult(ctx3) == null, "没写 `撤退` 的敌机（h2）残血也不撤")
	var ctx4 := _开(["B1"], ["h4"])
	ctx4.enemies[0].hp = float(ctx4.enemies[0].maxHp) * 0.3
	ctx4.result = {"结果": "败", "原因": "测试"}
	t.ok(Boss.撤离检查(ctx4) == null and (ctx4.enemies as Array).size() == 1, "已经有结果：不再撤离")

func _到回合与条件(t) -> void:
	var ctx := _开(["B1", "M1"], ["h1", "grunt"])
	ctx.turn = 5.0
	t.ok(Setup.checkResult(ctx) == null, "h1：S1 不在场，到第 5 回合也不撤")
	var ctx2 := _开(["S1", "M1"], ["h1", "grunt"])
	ctx2.turn = 2.0
	t.ok(Setup.checkResult(ctx2) == null, "h1：S1 在场，第 2 回合还不撤")
	ctx2.turn = 3.0
	var r = Setup.checkResult(ctx2)
	t.ok(r is Dictionary and r.get("撤退") == true and r.撤离单位 == "h1", "h1：S1 在场，第 3 回合撤离")
	var ctx3 := _开(["S1"], ["h1", "grunt"])
	ctx3.allies[0].hp = 0.0
	ctx3.turn = 3.0
	t.ok(Setup.checkResult(ctx3).结果 == "败", "我方全灭优先于撤退")

func _结算(撤: bool) -> Dictionary:
	var s := RosterManager.new_run(20261022, "无")
	s.roster["B1"] = {"key": "B1", "lv": 30, "hpRatio": 1.0}
	s.lineup.append({"key": "B1", "slot": ""})
	s.floor_num = 4
	s.map_data["当前节点类型"] = "精英"
	var ctx := {"allies": [], "enemies": [], "result": {"结果": "胜", "原因": "测试"}}
	if 撤:
		ctx.result = {"结果": "胜", "原因": "敌方头目撤离", "撤退": true}
	var 前 := {"希望": s.hope, "源碳": s.carbon}
	var r := NodeResolver.resolve_battle(s, ctx, "精英")
	r["_希望差"] = s.hope - int(前.希望)
	return r

func _结算减半(t) -> void:
	var 全 := _结算(false)
	var 半 := _结算(true)
	t.ok(int(半.希望) == floori(int(全.希望) / 2.0) and int(半.源碳) == floori(int(全.源碳) / 2.0),
		"撤离：希望 %s → %s、源碳 %s → %s（减半向下取整）" % [J.s(全.希望), J.s(半.希望), J.s(全.源碳), J.s(半.源碳)])
	t.ok(int(全._希望差) - int(半._希望差) == int(全.希望) - int(半.希望), "局内希望少加的正好是减掉的那一半")
	t.ok(全.get("零件") != null and 半.get("零件") == null, "撤离：不发战利品零件（正常精英战必给）")
	t.ok(半.get("撤退") == true and not 全.has("撤退"), "结算结果带 撤退；正常胜利不多字段")
	t.ok(半.get("胜") == true and 半.get("券") == 全.get("券"), "撤离仍算胜利，战后券照常")
