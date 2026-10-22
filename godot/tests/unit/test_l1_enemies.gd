## 职责：第 1 层新敌机（lr_ 六台）与三条编成（1-L1~1-L3）的数据与开战冒烟。
## 只验数据落地：模板改项、梯队、敌方职业、编成词条能挂上、每条编成都能真打完一场。
extends RefCounted

const 新键 := ["lr_miner", "lr_lancer", "lr_guard", "lr_catapult", "lr_knight", "lr_ballista"]
const 新编成 := ["1-L1", "1-L2", "1-L3", "1-L4", "1-L5", "1-L6", "1-L7", "1-L8"]

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_模板(t)
	_梯队与职业(t)
	for 号 in 新编成:
		_开战冒烟(t, 号)
	# 作者 10-22：第 1 层普通 / 精英只抽新设计敌机，旧 10 条退役
	for 类 in ["普通", "精英"]:
		var 池 := NodeResolver.选编成(1, 类)
		t.ok(池.all(func(e): return str(e.get("编号", "")).begins_with("1-L") or str(e.get("编号", "")).begins_with("1-H")),
			"第 1 层%s池只剩新编成（%d 条）" % [类, 池.size()])

func _tpl(k: String) -> Dictionary:
	return (Db.T.ENEMY_T as Dictionary).get(k, {})

func _大招(k: String) -> Array:
	return (_tpl(k).get("weapons", []) as Array).filter(func(w): return J.truthy(w.get("大招")))

func _模板(t) -> void:
	for k in 新键:
		t.ok(not _tpl(k).is_empty() and str(_tpl(k).get("key")) == k, "%s 模板存在且 key 对得上" % k)
	var 钻: Array = _tpl("lr_miner").weapons
	t.ok(钻.size() == 1 and str(钻[0].fire) == "melee" and float(钻[0].power) == 1700.0, "lr_miner 只有近战钻头 1700")
	t.ok(float(_tpl("lr_lancer").mov) == 7.0, "lr_lancer 速度 7（先手）")
	t.ok(_大招("lr_guard").is_empty() and float(_tpl("lr_guard").hp) == 4200.0, "lr_guard 杂兵档：HP 4200、无大招")
	t.ok(str(_tpl("lr_catapult").weapons[0].fire) == "indirect", "lr_catapult 曲射")
	var 冲: Array = _大招("lr_knight")
	t.ok(冲.size() == 1 and str(冲[0].fire) == "map" and str(冲[0].get("area")) == "col",
		"lr_knight 大招是整列阻挡束（map·col）")
	var 弩: Dictionary = _tpl("lr_ballista").weapons[0]
	t.ok(str(弩.dmgType) == "物理" and float(弩.power) == 2200.0 and _大招("lr_ballista").size() == 1,
		"lr_ballista 主武器物理重弩 2200 + 一把大招")

func _梯队与职业(t) -> void:
	for k in ["lr_miner", "lr_lancer", "lr_guard", "lr_catapult"]:
		t.ok(DataFn.tierOfEnemy(k) == "杂兵", "%s 梯队 = 杂兵" % k)
	for k in ["lr_knight", "lr_ballista"]:
		t.ok(DataFn.tierOfEnemy(k) == "精锐", "%s 梯队 = 精锐" % k)
	var 职 := {"lr_lancer": "近卫", "lr_guard": "重装", "lr_knight": "重装", "lr_ballista": "狙击"}
	for k in 职.keys():
		t.ok(Params.敌方职业(k) == 职[k], "%s 敌方职业 = %s" % [k, 职[k]])

func _条目(号: String) -> Dictionary:
	for e in Db.catalog.stages():
		if e is Dictionary and str(e.get("编号", "")) == 号:
			return e
	return {}

func _开战冒烟(t, 号: String) -> void:
	var e := _条目(号)
	t.ok(not e.is_empty() and int(e.get("层", 0)) == 1, "%s 在第 1 层编成表里" % 号)
	if e.is_empty():
		return
	var s := RosterManager.new_run(20261022, "无")
	for t2 in (Db.T["ALLY_T"] as Array):
		if s.roster.size() >= 5:
			break
		var k := String(t2["mech"])
		s.roster[k] = {"key": k, "lv": 10, "hpRatio": 1.0}
		s.lineup.append({"key": k, "slot": ""})
	s.floor_num = 1
	var 格类型 := "精英" if str(e.get("类型")) == "精英" else "作战"
	s.map_data["当前节点类型"] = 格类型
	var ctx := NodeResolver.开战(s, e, 格类型, {"单机牌组": true})
	var 敌: Array = ctx.get("enemies", [])
	var 减 := NodeResolver.第一层减负(e)
	t.ok(敌.size() == (减.前 as Array).size() + (减.后 as Array).size(), "%s 开场敌机数 = 第一层减负后的前 + 后（%d 台）" % [号, 敌.size()])
	t.ok(敌.all(func(u): return str(J.or_(u.get("tplKey"), u.get("key"))).begins_with("lr_")), "%s 开场全是 lr_ 敌机" % 号)
	# 位名词条要挂到对应格（修 NodeResolver.词条作用在 之前，只有「前1」挂得上）
	var 护卫位 := (e.词条 as Array).filter(func(w): return str(w.键) == "护卫减伤").map(func(w): return NodeResolver.解析槽位(w.位))
	var 实护卫位 := 敌.filter(func(u): return float(J.num0(u.get("护卫减伤"))) == 20.0).map(func(u): return int(u.slot))
	护卫位.sort()
	实护卫位.sort()
	t.ok(护卫位 == 实护卫位, "%s 护卫减伤 20 挂在格 %s" % [号, str(实护卫位)])
	var 狙位 := (e.词条 as Array).filter(func(w): return str(w.键) == "战斗分类").map(func(w): return NodeResolver.解析槽位(w.位))
	for u in 敌:
		if 狙位.has(int(u.slot)):
			t.ok(str(J.g(u.get("tags"), "战斗分类")) == "狙击", "%s 格 %d 拿到战斗分类·狙击" % [号, int(u.slot)])
	var 顶 := float(ctx.get("回合上限", 12.0)) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		Setup.打一回合(ctx)
	t.ok(ctx.result != null, "%s 一场打得完（%s）" % [号, J.s(ctx.result.get("结果") if ctx.result != null else "未结束")])
