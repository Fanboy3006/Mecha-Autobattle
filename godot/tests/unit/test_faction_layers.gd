## 职责：第 2 层起各层阵营敌机（cw_ / ok_ / hg_ / tr_）的数据落地与开战冒烟。
## 每层验：普通 / 精英池只剩本层新编成；每条新编成能真打完；本层阵营模板在梯队表里。
extends RefCounted

## 层 → {前缀: 新编成编号前缀们, 模板: 本层阵营模板键}
const 层表 := {
	2: {"前缀": ["2-C", "2-H"], "模板": ["cw_police", "cw_riot", "cw_welder", "cw_turret", "cw_fortress", "cw_jammer"]},
	3: {"前缀": ["3-K", "3-H"], "模板": ["ok_trooper", "ok_hound", "ok_drone", "ok_mortar", "ok_tank", "ok_herald"]},
	4: {"前缀": ["4-M", "4-T", "4-H"], "模板": ["hg_trooper", "hg_ghost", "hg_lambda_lite", "hg_drone", "hg_venom", "hg_mirror", "tr_pseudo", "tr_guard", "tr_spreader", "tr_lancer", "tr_hunter", "tr_terminal"]},
}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	for 层 in 层表.keys():
		var 规: Dictionary = 层表[层]
		for k in 规.模板:
			t.ok((Db.T.ENEMY_T as Dictionary).has(k) and DataFn.tierOfEnemy(k) in ["杂兵", "精锐"], "第 %d 层模板 %s 在表里、梯队 %s" % [层, k, DataFn.tierOfEnemy(k)])
		for 类 in ["普通", "精英"]:
			var 池 := NodeResolver.选编成(层, 类)
			t.ok(not 池.is_empty() and 池.all(func(e): return _新(e, 规.前缀)), "第 %d 层%s池只剩新编成（%d 条）" % [层, 类, 池.size()])
			for e in 池:
				_开战冒烟(t, e)
	_焊修机会修(t)
	_实战辅助(t)

func _新(e: Dictionary, 前缀们: Array) -> bool:
	for p in 前缀们:
		if str(e.get("编号", "")).begins_with(p):
			return true
	return false

func _开战(e: Dictionary, 种子: int = 20261022) -> Dictionary:
	var s := RosterManager.new_run(种子, "无")
	for t2 in (Db.T["ALLY_T"] as Array):
		if s.roster.size() >= 6:
			break
		var k := String(t2["mech"])
		s.roster[k] = {"key": k, "lv": 20, "hpRatio": 1.0}
		s.lineup.append({"key": k, "slot": ""})
	s.floor_num = int(e.get("层", 1))
	var 格: String = "精英" if str(e.get("类型")) == "精英" else "作战"
	s.map_data["当前节点类型"] = 格
	return NodeResolver.开战(s, e, 格, {"单机牌组": true})

func _打完(ctx: Dictionary) -> void:
	var 顶 := float(ctx.get("回合上限", 12.0)) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		Setup.打一回合(ctx)

func _开战冒烟(t, e: Dictionary) -> void:
	var ctx := _开战(e)
	var 敌: Array = ctx.get("enemies", [])
	t.ok(敌.size() == (e.前 as Array).size() + (e.后 as Array).size(), "%s 开场 %d 台" % [str(e.编号), 敌.size()])
	_打完(ctx)
	t.ok(ctx.result != null, "%s 一场打得完（%s，%d 回合）" % [str(e.编号), J.s(ctx.result.get("结果") if ctx.result != null else "未结束"), int(ctx.get("turn", 0))])

## 敌方修理（引擎早支持、数据第一次用）：友军掉到 60% 以下时，焊修机的行动是「修理」。
func _焊修机会修(t) -> void:
	var e: Dictionary = {}
	for x in Db.catalog.stages():
		if x is Dictionary and str(x.get("编号", "")) == "2-C2":
			e = x
	var ctx := _开战(e)
	var 焊: Variant = null
	var 盾: Variant = null
	for u in ctx.enemies:
		if str(J.or_(u.get("tplKey"), u.get("key"))).begins_with("cw_welder") and 焊 == null:
			焊 = u
		if str(J.or_(u.get("tplKey"), u.get("key"))).begins_with("cw_riot") and 盾 == null:
			盾 = u
	t.ok(焊 != null and 盾 != null, "2-C2 里有焊修机和盾车")
	if 焊 == null or 盾 == null:
		return
	盾.hp = float(盾.maxHp) * 0.3
	var 动 = Ai.aiAction(焊, ctx)
	t.ok(动 is Dictionary and str(动.kind) == "heal" and 动.target == 盾, "盾车掉到 30%%：焊修机这一步是修理盾车（%s）" % (str(动.kind) if 动 is Dictionary else "无"))

## ENEMY-AI-1：敌方修理 / 支援在实战与预告里真的出手（之前敌方只走 Ai.enemyAction，只会攻击）。
func _实战辅助(t) -> void:
	var e2: Dictionary = {}
	var e3: Dictionary = {}
	for x in Db.catalog.stages():
		if x is Dictionary and str(x.get("编号", "")) == "2-C2":
			e2 = x
		if x is Dictionary and str(x.get("编号", "")) == "3-K5":
			e3 = x
	# 修理：盾车掉到 30%，焊修机的预告 = 修理盾车，实战也修了
	var ctx := _开战(e2)
	var 焊: Variant = null
	var 盾: Variant = null
	for u in ctx.enemies:
		var k := str(J.or_(u.get("tplKey"), u.get("key")))
		if k.begins_with("cw_welder") and 焊 == null:
			焊 = u
		if k.begins_with("cw_riot") and 盾 == null:
			盾 = u
	盾.hp = float(盾.maxHp) * 0.3
	var 意 := BattleIntent.算意图(ctx).filter(func(x): return x.键 == 焊.key)
	t.ok(意.size() == 1 and str(意[0].动作类型) == "修理" and 意[0].目标 == 盾.key, "预告：焊修机这一步是「修理」盾车")
	var 动 = Boss.bossTurn(焊, ctx)
	t.ok(动 is Dictionary and str(动.kind) == "heal" and 动.target == 盾, "实战：焊修机出手 = 修理盾车")
	# 再动：指挥车在后排，前排有人行动过之后，它这一步是「再动」
	var ctx3 := _开战(e3)
	var 车: Variant = null
	for u in ctx3.enemies:
		if str(J.or_(u.get("tplKey"), u.get("key"))).begins_with("ok_herald"):
			车 = u
	t.ok(车 != null, "3-K5 里有宣传指挥车")
	if 车 == null:
		return
	for u in ctx3.enemies:
		if not is_same(u, 车) and float(u.slot) < 4.0:
			u.actedTurn = ctx3.turn
	var 动3 = Boss.bossAction(车, ctx3)
	t.ok(动3 is Dictionary and str(动3.kind) == "grant", "前排行动过后：指挥车这一步是「再动」（%s）" % (str(动3.kind) if 动3 is Dictionary else "无"))
	# 实战跑完一整场：至少修过 / 再动过一次
	var 记 := {"修理": 0, "再动": 0}
	for ee in [e2, e3]:
		var c := _开战(ee)
		_打完(c)
		for l in (c.get("log", []) as Array):
			if l is Dictionary and str(l.get("类型", "")) in 记.keys() and str(l.get("单位方", l.get("方", ""))) != "ally":
				记[str(l.类型)] += 1
	t.ok(记["修理"] + 记["再动"] > 0, "整场实战里敌方修理 %d 次、再动 %d 次" % [记["修理"], 记["再动"]])
