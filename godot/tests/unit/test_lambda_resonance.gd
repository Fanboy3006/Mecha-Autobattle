## 职责：N3【λ 共振】—— λ 力场减免量按单位读；同侧 ≥2 台带「λ共振」的 λ 机在场时，每回合减免次数 2 → 3。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 劣1 := Units.makeUnit("hg_lambda_lite", "enemy", 0.0, 1.0)
	var 劣2 := Units.makeUnit("hg_lambda_lite", "enemy", 1.0, 1.0)
	var 毒 := Units.makeUnit("hg_venom", "enemy", 2.0, 1.0)
	var 旧 := Units.makeUnit("venom", "enemy", 3.0, 1.0)
	var ctx := {"turn": 1.0, "allies": [], "enemies": [劣1, 劣2, 毒, 旧]}
	t.ok(Calc.λ减免量(劣1) == 1200.0 and Calc.λ减免量(毒) == 3000.0 and Calc.λ减免量(旧) == 3000.0, "减免量按单位读：劣化型 1200、毒液 3000、旧 venom 默认 3000")
	t.ok(Calc.λ次数上限(劣1, ctx) == 3.0 and Calc.λ次数上限(毒, ctx) == 3.0, "3 台共振机在场：每回合 3 次")
	t.ok(Calc.λ次数上限(旧, ctx) == 2.0, "没有共振标记的旧 venom 不吃共振：2 次")
	t.ok(Calc.lsLeft(劣1, 1.0, ctx) == 3.0 and Calc.lsLeft(劣1, 1.0) == 2.0, "lsLeft 带 ctx 才算共振，不带 ctx 维持旧口径 2")
	劣2.hp = 0.0
	毒.hp = 0.0
	t.ok(Calc.λ次数上限(劣1, ctx) == 2.0, "共振机只剩 1 台：回到 2 次")
	# 真打：同回合往劣化型身上打 4 下，前 3 下各减 1200
	劣2.hp = float(劣2.maxHp)
	var 我 := Units.makeUnit("B1", "ally", 0.0, 30.0)
	ctx.allies = [我]
	var w := {"name": "测试刀", "power": 3000.0, "fire": "melee", "stat": "格斗", "dmgType": "物理", "hit": 100.0, "range": [1.0, 1.0]}
	var 减们 := []
	for i in 4:
		var 有 := Calc.dmgCore(我, w, 劣1, {"power": 3000.0, "preview": false, "turn": 1.0, "ctx": ctx})
		var 裸: Dictionary = 劣1.duplicate(true)
		裸.abilities = []
		var 无 := Calc.dmgCore(我, w, 裸, {"power": 3000.0, "preview": true, "turn": 1.0, "ctx": ctx})
		减们.append(float(无.dmg) - float(有.dmg))
	t.ok(减们[3] < 减们[0] and 减们[2] == 减们[0], "同回合前 3 下都被减免、第 4 下不减（每下减免 %s）" % str(减们))
