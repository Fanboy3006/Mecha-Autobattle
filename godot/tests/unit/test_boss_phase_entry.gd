## 职责：Boss 阶段进场事件（B 稿 N4）：进新阶段只执行一次 —— 叫增援 / 套词条 / 写战报；`除非` 条件；预告不触发。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_叫增援(t)
	_除非与强化增援(t)
	_套词条(t)
	_跳阶段与只报战报(t)
	_旧脚本不变(t)

func _条目(号: String) -> Dictionary:
	for e in Db.catalog.stages():
		if e is Dictionary and str(e.get("编号", "")) == 号:
			return e
	return {}

func _开(号: String, 我方: Array) -> Dictionary:
	var e := _条目(号)
	var s := RosterManager.new_run(20261022, "无")
	for k in 我方:
		s.roster[k] = {"key": k, "lv": 30, "hpRatio": 1.0}
		s.lineup.append({"key": k, "slot": ""})
	s.floor_num = int(e.get("层", 1))
	s.map_data["当前节点类型"] = "守军"
	return {"ctx": NodeResolver.开战(s, e, "守军", {"单机牌组": true}), "条目": e, "场次": s.battles_fought}

func _首(ctx: Dictionary) -> Dictionary:
	for u in ctx.enemies:
		if Boss.取Boss脚本(u) != null:
			return u
	return {}

func _进场条数(ctx: Dictionary) -> int:
	return (ctx.log as Array).filter(func(l): return str(l.get("Boss事件", "")) == "进场").size()

func _叫增援(t) -> void:
	var r := _开("1-G甲", ["B1", "M1"])
	var ctx: Dictionary = r.ctx
	var 首 := _首(ctx)
	t.ok(str(首.get("key", "")) == "g1a", "1-G甲 的 Boss 是 g1a")
	var 前 := (ctx.enemies as Array).size()
	Boss.bossTurn(首, ctx)
	t.ok((ctx.enemies as Array).size() == 前 and _进场条数(ctx) == 0, "满血：只报第 1 阶段，没有进场事件")
	首.hp = float(首.maxHp) * 0.4
	var 预告 = Boss.bossAction(首, ctx)
	t.ok((ctx.enemies as Array).size() == 前 and _进场条数(ctx) == 0, "预告（bossAction）不触发进场（%s）" % J.s(预告 != null))
	Boss.bossTurn(首, ctx)
	var 新: Array = (ctx.enemies as Array).slice(前)
	t.ok(新.size() == 2 and 新.all(func(u): return Rival.键Of(u) == "raider"), "g1a 进 P2：叫来 2 台 raider（%s）" % str(新.map(func(u): return u.key)))
	t.ok(_进场条数(ctx) == 1 and (ctx.log as Array).any(func(l): return str(l.get("类型", "")) == "增援"), "写一行〔Boss〕阶段进场 + 复用〔增援〕战报")
	var 期望等级 := NodeResolver.等级Of(r.条目, "raider", int(r.场次))
	t.ok(新.all(func(u): return float(u.lv) == 期望等级 and float(u.强化) == NodeResolver.强化Of(r.条目, "raider")),
		"增援等级 / 强化与编成里同层同梯队一致（Lv %s）" % J.s(期望等级))
	t.ok(新.all(func(u): return float(u.slot) >= 0.0) and 新[0].key != 新[1].key, "增援占空位、实例键不重复")
	Boss.bossTurn(首, ctx)
	首.hp = float(首.maxHp)
	Boss.bossTurn(首, ctx)
	首.hp = float(首.maxHp) * 0.3
	Boss.bossTurn(首, ctx)
	t.ok((ctx.enemies as Array).size() == 前 + 2 and _进场条数(ctx) == 1, "同一阶段只执行一次（回血再掉下来也不重复）")

func _除非与强化增援(t) -> void:
	var r := _开("4-B丙", ["A1", "B1"])
	var ctx: Dictionary = r.ctx
	var 首 := _首(ctx)
	var 前 := (ctx.enemies as Array).size()
	首.hp = float(首.maxHp) * 0.4
	Boss.bossTurn(首, ctx)
	t.ok((ctx.enemies as Array).size() == 前 and _进场条数(ctx) == 0, "g4c：A1 在场 → 进场不触发")
	var r2 := _开("4-B丙", ["B1", "M1"])
	var ctx2: Dictionary = r2.ctx
	var 首2 := _首(ctx2)
	for u in ctx2.enemies:
		if not is_same(u, 首2):
			u.hp = 0.0
	首2.hp = float(首2.maxHp) * 0.4
	Boss.bossTurn(首2, ctx2)
	var 狂: Array = (ctx2.enemies as Array).filter(func(u): return Rival.键Of(u) == "berserker")
	t.ok(狂.size() == 1, "g4c 进 P2：叫来 1 台 berserker")
	if 狂.size() == 1:
		var 素 := Units.makeUnit("berserker", "enemy", 0.0, float(狂[0].lv), 狂[0].强化, null, 狂[0].get("层"))
		t.ok(float(狂[0].armor) == float(素.armor) + 300.0 and float(狂[0].shieldHp) == float(素.shieldHp) + 3000.0
			and (狂[0].buffs as Array).any(func(b): return J.num0(b.get("dmg")) == 30.0), "强化增援：装甲 +300、护盾 +3000、攻击力 +30")

func _套词条(t) -> void:
	var r := _开("2-G丙", ["B1", "M1"])
	var 首 := _首(r.ctx)
	首.hp = float(首.maxHp) * 0.4
	Boss.bossTurn(首, r.ctx)
	t.ok(J.num(首.get("冷却延长")) == 1.0 and 首.get("隐身刷新") == true, "g2c 进 P2：套上冷却延长 1 + 隐身刷新")
	var r2 := _开("2-G丙", ["S1", "M1"])
	var 首2 := _首(r2.ctx)
	首2.hp = float(首2.maxHp) * 0.4
	Boss.bossTurn(首2, r2.ctx)
	t.ok(J.num(首2.get("冷却延长")) == 1.0 and 首2.get("隐身刷新") != true, "S1 在场：只套冷却延长，隐身刷新那条不触发")

func _跳阶段与只报战报(t) -> void:
	var r := _开("3-G丙", ["B1", "M1"])
	var ctx: Dictionary = r.ctx
	var 首 := _首(ctx)
	var 前 := (ctx.enemies as Array).size()
	首.hp = float(首.maxHp) * 0.2
	Boss.bossTurn(首, ctx)
	var 进们: Array = (ctx.log as Array).filter(func(l): return str(l.get("Boss事件", "")) == "进场")
	t.ok(进们.size() == 2 and float(进们[0].Boss阶段) == 2.0 and float(进们[1].Boss阶段) == 3.0, "g3c 一口气掉到 P3：P2、P3 的进场按顺序补上")
	t.ok((ctx.enemies as Array).size() == 前, "g3c 的进场只写战报，不叫增援")

func _旧脚本不变(t) -> void:
	var ctx := Setup.开局([{"键": "B1", "位": 0.0, "等级": 30.0}], [{"键": "bluefish", "位": 4.0}], 7)
	var 鱼: Dictionary = ctx.enemies[0]
	鱼.hp = float(鱼.maxHp) * 0.3
	Boss.bossTurn(鱼, ctx)
	t.ok(_进场条数(ctx) == 0 and (ctx.enemies as Array).size() == 1, "没写 `进场` 的旧脚本（bluefish）：进第 2 阶段不多做任何事")
