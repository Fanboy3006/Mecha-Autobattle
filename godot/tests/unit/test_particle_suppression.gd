## 职责：N4【粒子抑制场】—— 敌方每台活着的粒子散布机算 1 层（最多 2 层）：
## 我方战意获得每层 −25%（只压加），精神牌费用 +1（不叠）；散布机全灭即解除；我方天人也不豁免（作者 10-21）。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 散1 := Units.makeUnit("tr_spreader", "enemy", 4.0, 1.0, 1.0, null, null, "tr_spreader#1")
	var 散2 := Units.makeUnit("tr_spreader", "enemy", 5.0, 1.0, 1.0, null, null, "tr_spreader#2")
	var 散3 := Units.makeUnit("tr_spreader", "enemy", 6.0, 1.0, 1.0, null, null, "tr_spreader#3")
	var 我 := {"key": "CB1", "side": "ally", "战意": 0.0, "name": "测试机"}
	var ctx := {"turn": 1.0, "allies": [我], "enemies": [散1]}
	t.ok(BattleMorale.抑制层数(ctx, 我) == 1, "1 台散布机 = 1 层")
	BattleMorale.加战意(我, 8.0, ctx)
	t.ok(float(我.战意) == 6.0, "1 层：+8 战意只拿到 6（实际 %s）" % J.s(我.战意))
	ctx.enemies = [散1, 散2, 散3]
	t.ok(BattleMorale.抑制层数(ctx, 我) == 2, "3 台散布机也只算 2 层")
	BattleMorale.加战意(我, 8.0, ctx)
	t.ok(float(我.战意) == 10.0, "2 层：+8 只拿到 4（实际累计 %s）" % J.s(我.战意))
	BattleMorale.加战意(我, -3.0, ctx)
	t.ok(float(我.战意) == 7.0, "扣战意不受影响")
	for x in [散1, 散2, 散3]:
		x.hp = 0.0
	t.ok(BattleMorale.抑制层数(ctx, 我) == 0, "散布机全灭：解除")
	BattleMorale.加战意(我, 8.0, ctx)
	t.ok(float(我.战意) == 15.0, "解除后 +8 全额")
	var 旧 := Units.makeUnit("jammer", "enemy", 4.0, 1.0)
	t.ok(BattleMorale.抑制层数({"allies": [我], "enemies": [旧]}, 我) == 0, "旧电子战机不带粒子散布：不抑制")
	t.ok(EnemyMech != null and RuleHooks.顺序["牌打出后"].has(EnemyMech), "精神牌加费挂在「牌打出后」钩子上")
