## 职责：殖民卫星军「快速测试战斗（五人）」的**无头连跑自检** —— 不同种子各开一局、自动打完，
##       打印每局胜负 / 回合数，最后给胜负合计与平均回合数（COL-5 收尾自检）。
## 用法（仓库根目录）：godot --headless --path godot --script res://tools/smoke_colonial_quick.gd
##   · 走的是玩家点「自动打完」同一条路（`GameSession.auto_finish_battle`），不是录样例那套策略；
##   · 任何一局开不起来 / 打完没有结算结果 / 跑出运行时错误 → 退出码 1。
extends SceneTree

## 局数（不同种子：20261013 起连号）。
const 局数 := 10
const 起始种子 := 20261013

func _initialize() -> void:
	var 错误: Array = []
	if not DataLoader.install(错误):
		print("✗ 数据装不进去：%s" % str(错误))
		quit(1)
		return
	var 胜 := 0
	var 败 := 0
	var 坏 := 0
	var 回合和 := 0.0
	for i in 局数:
		var 种 := 起始种子 + i
		var s := GameSession.new()
		s.存档路径 = "res://.godot/tmp_smoke_colonial.json"
		if not s.开始快速测试战斗_殖民卫星军(种):
			print("✗ 第 %d 局（种子 %d）开不起来" % [i + 1, 种])
			坏 += 1
			continue
		s.auto_finish_battle()
		var 结 = s.battle_ctx.get("result")
		if not (结 is Dictionary):
			print("✗ 第 %d 局（种子 %d）打完没有结算结果（可能卡死）" % [i + 1, 种])
			坏 += 1
			continue
		var 果 := str((结 as Dictionary).get("结果", ""))
		var 回合 := int(float(s.battle_ctx.get("turn", 0.0)))
		var 存活 := "%d/%d" % [s._存活数("ally"), s._存活数("enemy")]
		回合和 += float(回合)
		if 果 == "胜":
			胜 += 1
		else:
			败 += 1
		print("  第 %2d 局 · 种子 %d · %s（%s）· 回合 %d · 存活 %s" % [
			i + 1, 种, 果, str((结 as Dictionary).get("原因", "")), 回合, 存活])
	var 总 := 胜 + 败
	print("==========================================")
	print("殖民卫星军快速测试自检：%d 局 · %d 胜 / %d 败 · 失败 %d · 平均 %.1f 回合" % [
		总, 胜, 败, 坏, (回合和 / float(总)) if 总 > 0 else 0.0])
	quit(0 if 坏 == 0 and 总 == 局数 else 1)
