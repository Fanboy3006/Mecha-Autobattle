## 用 Godot 的 Battle Core 重跑一场黄金样例（测试专用）。流程与 godot/tools/export_golden.mjs 的「跑一场」一致：
## 初始手牌按 JS 参考版装填（已接受差异 D-01 的对账开关）。
## 开局 → 每回合 {先执行本回合命令（打战术牌）→ 打一回合 → 记回合摘要} → 没结果记「败 / 超出回合上限」→ 记结束。
class_name GoldenRunner
extends RefCounted

## 只给玩家看、不参与对拍的字段（黄金样例里没有它们，多了不算分叉）。
## ★ 2026-10-19 UX-2：`发牌` 条目新增 `来源文本` / `来源位`（哪台机体带出来的这张牌）
##   —— 纯展示字段，内核数值与随机数一个都没动，所以进这张表跳过。
const DISPLAY_ONLY := ["文本", "效果说明", "触发说明", "来源文本", "来源位"]

static func run(sample: Dictionary) -> Dictionary:
	var 输入: Dictionary = GoldenCompare.decode(sample["输入"])
	var 命令: Array = GoldenCompare.decode(sample["命令"])
	# 藏品（M3-Prep）：黄金样例把这一局的藏品 id 数组放在 `输入.藏品`（JS 那边是 `肉鸽.RUN.藏品`，
	# Godot 侧走 `选项.藏品` —— DEBT-06）。没有这个键的样例 = 空数组 = 一个字段都不动。
	var 选项: Dictionary = J.merged(输入.get("选项", {}), {"方针": {}, "手牌装填": Btl.手牌装填_JS参考, "藏品": 输入.get("藏品")})
	var ctx := Setup.开局(输入["我方"], 输入["敌方规格"], 输入["种子"], null, 选项)
	var 摘要们 := [摘要(ctx)]
	var 顶 := maxf(float(Db.T.MAX_TURN), J.num0(ctx.get("回合上限")) if J.truthy(ctx.get("回合上限")) else float(Db.T.MAX_TURN)) + 2.0
	var 护栏 := 0.0
	var 命令错误 := []
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		for c in 命令:
			if float(c["回合"]) == float(ctx.turn) and c["类型"] == "打战术牌":
				var r := Btl.打战术牌(ctx, c["参数"])
				if not r.get("成功", false):
					命令错误.append("第 %s 回合打【%s】失败：%s" % [J.s(ctx.turn), c["参数"], r.get("原因", "")])
		Setup.打一回合(ctx)
		摘要们.append(摘要(ctx))
	if ctx.result == null:
		ctx.result = {"结果": "败", "原因": "超出回合上限"}
	Btl.pushLog(ctx, "战斗结束：%s（%s）" % [ctx.result.结果, ctx.result.原因], {"类型": "结束"})
	var events := []
	for i in ctx.log.size():
		var o := {}
		for k in ctx.log[i].keys():
			if not DISPLAY_ONLY.has(String(k)):
				o[String(k)] = 纯数据(ctx.log[i][k])
		o["_rng"] = ctx._rng_at[i]
		events.append(o)
	return {"events": events, "digests": 摘要们, "result": {"结果": ctx.result.结果, "原因": ctx.result.原因, "回合": ctx.turn}, "命令错误": 命令错误}

## 深拷贝成纯数据（事件里不能留对单位的引用；之后的状态变化不能回头改掉已记的事件）
static func 纯数据(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v

static func 摘要(ctx: Dictionary) -> Dictionary:
	var 单位 := []
	for u in ctx.allies + ctx.enemies:
		单位.append({
			"方": u.side, "位": u.slot, "键": u.key, "hp": u.hp, "maxHp": u.maxHp,
			"shieldHp": J.or_(u.get("shieldHp"), 0.0), "掩护盾": J.or_(u.get("掩护盾"), 0.0),
			"buffs": J.or_(u.get("buffs"), []), "debuffs": J.or_(u.get("debuffs"), []),
			"武器": J.or_(u.get("weapons"), []).map(func(w): return [w.get("cd"), w.get("uses"), w.get("readyTurn")]),
			"势力状态": J.or_(u.get("势力状态"), null), "标定经济": J.or_(u.get("标定经济"), null),
			"holdUlt": J.truthy(u.get("holdUlt")), "defending": J.truthy(u.get("defending")),
		})
	var r = ctx.get("result")
	return 纯数据({
		"回合": ctx.turn, "rng": float(ctx.rng.steps), "气势": ctx.get("气势"),
		"结果": {"结果": r.结果, "原因": r.原因} if r != null else null,
		"手牌": J.or_(ctx.get("战术手牌"), []).map(func(c): return c.id),
		"待触发": J.or_(ctx.get("待触发战术牌"), []).map(func(c): return c.id),
		"已打出": J.or_(ctx.get("已打出战术牌"), []),
		"战况计数": J.or_(ctx.get("战况计数"), null),
		"全队憋大招": J.truthy(ctx.get("全队憋大招")),
		"单位": 单位,
	})

## 把期望的回合摘要（第 0 项全量、之后只记单位变化）展开成每回合全量，再与实际逐项比对。返回 "" 或第一处分叉。
static func compare_digests(sample: Dictionary, actual: Array) -> String:
	var expected: Array = sample["期望"]["回合摘要"]
	var 单位们: Array = []
	for i in mini(expected.size(), actual.size()):
		var e: Dictionary = GoldenCompare.decode(expected[i])
		if i == 0:
			单位们 = e["单位"]
		else:
			单位们 = 单位们.duplicate()
			while 单位们.size() < int(e["单位数"]):
				单位们.append(null)
			for pair in e["单位变化"]:
				单位们[int(pair[0])] = pair[1]
			e.erase("单位变化")
			e.erase("单位数")
		e["单位"] = 单位们
		var d := GoldenCompare.diff(e, actual[i], "回合摘要[%d]" % i)
		if d != "":
			return "%s · %s" % [sample["id"], d]
	if expected.size() != actual.size():
		return "%s · 回合摘要数不同（期望 %d，实际 %d）" % [sample["id"], expected.size(), actual.size()]
	return ""
