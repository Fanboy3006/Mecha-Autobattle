## 职责：N1【封锁线】—— 敌方前排 4 格都有活着的机体、且场上有带「封锁线」的敌机时，
## 我方直射打不到敌方后排（曲射 / 范围照打）；前排倒下一台，缺口打开，立即失效。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 前们 := []
	for i in 4:
		前们.append(Units.makeUnit("cw_police", "enemy", float(i), 1.0, 1.0, null, null, "cw_police#%d" % (i + 1)))
	var 后 := Units.makeUnit("cw_welder", "enemy", 4.0, 1.0)
	var 我 := Units.makeUnit("CB2", "ally", 4.0, 30.0)
	var ctx := {"turn": 1.0, "allies": [我], "enemies": 前们 + [后]}
	var 直 := {"name": "直射测试", "power": 1000.0, "fire": "direct", "range": [1.0, 9.0], "dmgType": "物理"}
	var 曲 := {"name": "曲射测试", "power": 1000.0, "fire": "indirect", "range": [1.0, 9.0], "dmgType": "物理"}
	t.ok(Reach.封锁线成立(ctx, "enemy"), "前排 4 格塞满 + 有封锁线敌机 → 封锁线成立")
	var r := Reach.武器可达吗(ctx, 我, 直, 后)
	t.ok(not J.truthy(r.ok) and str(r.why).begins_with("封锁线"), "直射打敌后排：被封锁线挡下（%s）" % str(r.why))
	t.ok(Reach.够得着吗(ctx, 我, 曲, 后), "曲射照打后排")
	t.ok(Reach.够得着吗(ctx, 我, 直, 前们[0]), "直射打前排不受影响")
	前们[2].hp = 0.0
	t.ok(not Reach.封锁线成立(ctx, "enemy") and Reach.够得着吗(ctx, 我, 直, 后), "前排倒下一台：缺口打开，直射能打后排")
	前们[2].hp = float(前们[2].maxHp)
	# 没有带封锁线的敌机 → 塞满也不成立（旧编成行为不变）
	var 旧们 := []
	for i in 4:
		旧们.append(Units.makeUnit("grunt", "enemy", float(i), 1.0, 1.0, null, null, "grunt#%d" % (i + 1)))
	var ctx2 := {"turn": 1.0, "allies": [我], "enemies": 旧们 + [Units.makeUnit("sniper", "enemy", 4.0, 1.0)]}
	t.ok(not Reach.封锁线成立(ctx2, "enemy"), "旧敌机塞满前排：没有封锁线（行为不变）")
	t.ok(Reach.封锁线状态(ctx, "enemy") == "完整" and Reach.封锁线状态(ctx2, "enemy") == "", "封锁线状态：完整 / 无")
	# 棋盘悬停提示（UI-1）：封锁线机体写出当前状态
	var 板 = load("res://presentation/battle/board_panel.gd")
	var 提: Array = 板._机制提示(前们[0], ctx)
	t.ok(提.any(func(x): return str(x).begins_with("封锁线：完整")), "悬停提示：封锁线完整（%s）" % str(提))
	前们[1].hp = 0.0
	t.ok((板._机制提示(前们[0], ctx) as Array).any(func(x): return str(x).begins_with("封锁线：已破")), "悬停提示：前排倒下一台 → 已破")
	var 散 := Units.makeUnit("tr_spreader", "enemy", 5.0, 1.0)
	t.ok((板._机制提示(散, ctx) as Array).any(func(x): return str(x).begins_with("粒子抑制")), "悬停提示：粒子散布机写抑制效果")
