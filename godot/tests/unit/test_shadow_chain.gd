## 职责：N5【影锁拽位】—— 锁链抓投机用「影锁」打中我方后排 → 和同列前排换位；打前排、别的武器、旧敌机都不拽。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 锁 := Units.makeUnit("sw_chain", "enemy", 0.0, 1.0)
	var 前 := Units.makeUnit("B1", "ally", 1.0, 30.0)
	var 后 := Units.makeUnit("CB2", "ally", 5.0, 30.0)
	var ctx := {"turn": 1.0, "allies": [前, 后], "enemies": [锁], "log": [], "again": []}
	var 影锁: Dictionary = 锁.weapons[0].t
	var 绞杀: Dictionary = 锁.weapons[1].t
	t.ok(str(影锁.name) == "影锁" and str(锁.get("影锁武器")) == "影锁", "锁链机的主武器是「影锁」")
	t.ok(Fm.另一排同位(5.0) == 1, "后2（5）同列前排是前2（1）")
	EnemyMech.武器攻击后(ctx, 锁, 后, 1000.0, 绞杀)
	t.ok(float(后.slot) == 5.0, "别的武器打中后排：不拽")
	EnemyMech.武器攻击后(ctx, 锁, 后, 0.0, 影锁)
	t.ok(float(后.slot) == 5.0, "没打中（伤害 0）：不拽")
	EnemyMech.武器攻击后(ctx, 锁, 后, 1000.0, 影锁)
	t.ok(float(后.slot) == 1.0 and float(前.slot) == 5.0, "影锁打中后排：和同列前排互换（后 %s / 前 %s）" % [J.s(后.slot), J.s(前.slot)])
	EnemyMech.武器攻击后(ctx, 锁, 后, 1000.0, 影锁)
	t.ok(float(后.slot) == 1.0, "目标已经在前排：不再拽")
	var 旧 := Units.makeUnit("beetle", "enemy", 1.0, 1.0)
	EnemyMech.武器攻击后(ctx, 旧, 前, 1000.0, 旧.weapons[0].t)
	t.ok(float(前.slot) == 5.0, "旧甲虫机不带影锁：不拽")
