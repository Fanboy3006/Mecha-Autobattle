## 月球王国 / 影世界 v0.2.1 的快速测试入口：门面开得起来、新模块接手、战斗画面能画、连打几回合不报错。
extends RefCounted

func run(t) -> void:
	var 错误 := []
	DataLoader.install(错误)
	_一场(t, "月球王国", ["M1", "M2", "M3", "M4", "M5"])
	_一场(t, "影世界", ["B1", "B2", "B3", "B4", "A3"])

func _一场(t, 阵容: String, 键们: Array) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_quick_%s.json" % 阵容
	t.ok(s.开始快速测试战斗(阵容), "%s 快速测试开起来了（screen = %s）" % [阵容, s.screen])
	var ctx: Dictionary = s.battle_ctx
	if ctx.is_empty():
		t.ok(false, "%s：battle_ctx 是空的" % 阵容)
		return
	var 在场 := []
	for u in (ctx.get("allies") as Array):
		在场.append(str((u as Dictionary).get("key", "")))
	在场.sort()
	var 要 := 键们.duplicate()
	要.sort()
	t.ok(在场 == 要, "%s：出场 %s" % [阵容, str(在场)])
	var 接手 := MoonV02.开(ctx) if 阵容 == "月球王国" else ShadowV02.开(ctx)
	t.ok(接手, "%s：v0.2 模块接手" % 阵容)
	var 有新牌 := false
	for u in (ctx.get("allies") as Array):
		for c in J.or_((u as Dictionary).get("武器栏"), []):
			var id := str((c as Dictionary).get("id", ""))
			有新牌 = 有新牌 or id.begins_with("MOON_") or id.begins_with("SHD_")
	t.ok(有新牌, "%s：武器栏里装的是新卡" % 阵容)
	var bv := BattleView.new()
	_根().add_child(bv)
	bv.setup(s)
	bv.refresh()
	t.ok(bv.get_child_count() > 0, "%s：战斗画面画得出来（%d 个子节点）" % [阵容, bv.get_child_count()])
	_根().remove_child(bv)
	bv.free()
	s.clear_errors()
	for _i in 3:
		if not s.battle_ctx.is_empty() and s.screen == "battle":
			s.step_battle_turn()
	t.ok(s.errors.is_empty(), "%s：连打 3 回合没有门面错误（%s）" % [阵容, str(s.errors)])

func _根() -> Node:
	return (Engine.get_main_loop() as SceneTree).root
