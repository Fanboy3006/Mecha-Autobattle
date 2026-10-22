## 职责：第 1～4 层代号 Boss 池（守关 / 终点 / 精英头目）的数据落地与开战冒烟。
## 验：旧守军与 bluefish 编成标「退役」后不再进抽取池；每条新编成能真打完；Boss 脚本挂上；
## 阶段换大技能武器时，别的阶段那把平时不能当普通武器用。
extends RefCounted

const 守关 := ["1-G甲", "1-G乙", "1-G丙", "2-G甲", "2-G乙", "2-G丙", "3-G甲", "3-G乙", "3-G丙"]
const 终点 := ["4-B甲", "4-B乙", "4-B丙", "4-B丁"]
const 头目 := ["1-H1", "2-H1", "3-H1", "4-H1"]

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_抽取池(t)
	for 号 in 守关 + 终点 + 头目:
		_开战冒烟(t, 号)
	_阶段武器收起(t)
	_大技能预告(t)

func _条目(号: String) -> Dictionary:
	for e in Db.catalog.stages():
		if e is Dictionary and str(e.get("编号", "")) == 号:
			return e
	return {}

func _抽取池(t) -> void:
	for 层 in [1, 2, 3]:
		var 池 := NodeResolver.选编成(层, "守军")
		t.ok(池.size() == 3 and 池.all(func(e): return str(e.get("编号", "")).begins_with("%d-G" % 层)),
			"第 %d 层守军池只剩 3 条代号守关" % 层)
	var 终 := NodeResolver.选编成(4, "Boss")
	t.ok(终.size() == 4 and 终.all(func(e): return not (e.前 as Array).has("bluefish")), "第 4 层终点池 4 条、没有 bluefish")
	var 退 := (Db.catalog.stages() as Array).filter(func(e): return e is Dictionary and e.get("退役") == true and str(e.get("类型")) in ["守军", "Boss"])
	t.ok(退.size() == 12, "退役的守军 / Boss 编成 12 条（数据保留、不进池）")
	for k in ["g4a", "g4b", "g4c", "g4d"]:
		t.ok(DataFn.tierOfEnemy(k) == "Boss", "%s 梯队 = Boss" % k)
	for k in ["g1a", "g2b", "g3c", "h1"]:
		t.ok(DataFn.tierOfEnemy(k) == "头目", "%s 梯队 = 头目" % k)

func _开战冒烟(t, 号: String) -> void:
	var e := _条目(号)
	t.ok(not e.is_empty(), "%s 在编成表里" % 号)
	if e.is_empty():
		return
	var s := RosterManager.new_run(20261022, "无")
	for t2 in (Db.T["ALLY_T"] as Array):
		if s.roster.size() >= 6:
			break
		var k := String(t2["mech"])
		s.roster[k] = {"key": k, "lv": 30, "hpRatio": 1.0}
		s.lineup.append({"key": k, "slot": ""})
	s.floor_num = int(e.get("层", 1))
	var 格类型: String = str({"守军": "守军", "Boss": "出口守军", "精英": "精英"}.get(str(e.get("类型")), "作战"))
	s.map_data["当前节点类型"] = 格类型
	var ctx := NodeResolver.开战(s, e, 格类型, {"单机牌组": true})
	var 敌: Array = ctx.get("enemies", [])
	if 头目.has(号):
		t.ok(敌.any(func(u): return str(u.get("key", "")).begins_with("h")), "%s 开场有头目" % 号)
	else:
		var 首 := 敌.filter(func(u): return Boss.取Boss脚本(u) != null)
		t.ok(首.size() == 1, "%s 开场正好 1 台挂着 Boss 脚本（%s）" % [号, str(首.map(func(u): return u.key))])
	var 顶 := float(ctx.get("回合上限", 12.0)) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		Setup.打一回合(ctx)
	t.ok(ctx.result != null, "%s 一场打得完（%s，%d 回合）" % [号, J.s(ctx.result.get("结果") if ctx.result != null else "未结束"), int(ctx.get("turn", 0))])

func _阶段武器收起(t) -> void:
	var e := _条目("1-G乙")
	var s := RosterManager.new_run(1, "无")
	s.roster["B1"] = {"key": "B1", "lv": 10, "hpRatio": 1.0}
	s.lineup.append({"key": "B1", "slot": ""})
	s.floor_num = 1
	s.map_data["当前节点类型"] = "守军"
	var ctx := NodeResolver.开战(s, e, "守军", {"单机牌组": true})
	var 甲: Variant = null
	for u in ctx.enemies:
		if str(u.key) == "g1b":
			甲 = u
	t.ok(甲 != null, "1-G乙 里有 g1b")
	if 甲 == null:
		return
	var 乱 := {"name": "骑士冲锋·乱"}
	var 冲 := {"name": "骑士冲锋"}
	ctx.turn = 2.0
	t.ok(Boss.Boss本回合禁用(甲, ctx, 乱) and Boss.Boss本回合禁用(甲, ctx, 冲), "P1 非技能回合：两把大技能武器都收着")
	ctx.turn = 4.0
	t.ok(not Boss.Boss本回合禁用(甲, ctx, 冲) and Boss.Boss本回合禁用(甲, ctx, 乱), "P1 技能回合：只放当前阶段那把")
	甲.hp = float(甲.maxHp) * 0.3
	t.ok(Boss.Boss本回合禁用(甲, ctx, 冲), "进 P2 后：P1 那把平时也不能当普通武器用")
	ctx.turn = 5.0
	t.ok(not Boss.Boss本回合禁用(甲, ctx, 乱), "P2 间隔 2：第 5 回合放十字乱冲")

## B 稿 N5：意图 / 棋盘上的大技能倒计时要算上武器的开场冷却（之前第 1 回合会误报「这一拍放」）。
func _大技能预告(t) -> void:
	var 甲 := Units.makeUnit("g1a", "enemy", 4.0, 1.0)
	var ctx := {"turn": 1.0, "allies": [], "enemies": [甲]}
	t.ok(float(Boss.大技能预告回合(甲, ctx)) == 4.0, "g1a 落锤 startCd 3、间隔 3：第 1 回合预告「第 4 回合放」")
	ctx.turn = 4.0
	t.ok(float(Boss.大技能预告回合(甲, ctx)) == 4.0, "第 4 回合：这一拍放")
	ctx.turn = 5.0
	t.ok(float(Boss.大技能预告回合(甲, ctx)) == 7.0, "第 5 回合：预告第 7 回合")
	var 意 := BattleIntent.算意图({"turn": 1.0, "allies": [Units.makeUnit("B1", "ally", 0.0, 10.0)], "enemies": [甲]})
	t.ok(意.size() == 1 and float(意[0].get("大技能回合", 0.0)) == 4.0, "意图条带「大技能回合」字段")
