## Battle Core 的正式规则（与 JS 参考版有意不同的地方，见 tests/golden/已接受差异表.md）与确定性。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db")
	var data := GoldenIO.load_json("res://tests/golden/battle/default.json")
	var smp: Dictionary = data["样例"][0]
	var 输入: Dictionary = GoldenCompare.decode(smp["输入"])

	# ---- D-01 初始手牌装填 ----
	var 旧 := Setup.开局(输入["我方"], 输入["敌方规格"], 输入["种子"], null, J.merged(输入["选项"], {"手牌装填": Btl.手牌装填_JS参考}))
	var 新 := Setup.开局(输入["我方"], 输入["敌方规格"], 输入["种子"], null, 输入["选项"])
	var ids := func(arr): return arr.map(func(c): return c.id)
	var 旧手: Array = ids.call(旧.战术手牌)
	var 新手: Array = ids.call(新.战术手牌)
	var 新候补: Array = ids.call(新.候补初始牌)
	t.info("默认五人队 · JS 参考版初始手牌：%s" % [旧手])
	t.info("默认五人队 · 正式规则初始手牌：%s · 候补：%s" % [新手, 新候补])
	var 角色初始 := (Db.T.战术卡牌表 as Array).filter(func(c): return c.层级 == "角色" and c.入牌 == "初始" \
		and J.some(新.allies, func(u): return u.key == c.归属)).map(func(c): return c.id)
	t.ok(not 角色初始.is_empty() and J.every(角色初始, func(id): return J.inc(新手, id)), "D-01：在场机师的角色初始牌全部进了初始手牌 %s" % [角色初始])
	t.ok(J.some(角色初始, func(id): return not J.inc(旧手, id)), "D-01 对照：JS 参考版会吞掉角色牌（确认差异真实存在）")
	t.ok(新手.size() == 旧手.size() and 新手.has("C_CMD_1"), "D-01：手牌数仍是初始上限 %d，基础激励保底在手" % 新手.size())
	var 全初始: Array = ids.call(新.战术牌池.filter(func(c): return c.入牌 == "初始"))
	t.ok(新手.size() + 新候补.size() == 全初始.size() and J.every(全初始, func(id): return J.inc(新手, id) or J.inc(新候补, id)),
		"D-01：没有初始牌被丢弃（手牌 %d + 候补 %d = 初始牌 %d）" % [新手.size(), 新候补.size(), 全初始.size()])
	# 手牌腾出两个空位 → 回合开始按序补位（不超过初始上限）
	if 新候补.size() >= 2:
		新.战术手牌 = 新.战术手牌.slice(0, 新手.size() - 2)
		var 补 := Btl.候补补位(新)
		t.ok(ids.call(补) == 新候补.slice(0, 2) and 新.战术手牌.size() == 新手.size(), "D-01：空出 2 位 → 按序补入 %s，手牌回到 %d 张" % [ids.call(补), 新手.size()])
		t.ok(Btl.候补补位(新).is_empty(), "D-01：手牌满上限时不再补")
		t.ok(新.log[-1].get("触发条件码") == "候补补位", "D-01：补位记一条「发牌」事件（触发条件码 = 候补补位）")

	# ---- 确定性：同输入同种子，两次跑出的事件逐条相同 ----
	var a := GoldenRunner.run(smp)
	var b := GoldenRunner.run(smp)
	t.ok(GoldenCompare.diff(a.events, b.events) == "" and a.events.size() > 0, "确定性：同一场跑两次，%d 条事件逐条相同" % a.events.size())

	# ---- 正式规则整场跑通：138 场输入全部能打完、不报错 ----
	var 场 := 0
	var 胜 := 0
	var 坏 := []
	for g in ["default", "faction", "character", "card_baseline"]:
		for s in GoldenIO.load_json("res://tests/golden/battle/%s.json" % g)["样例"]:
			var inp: Dictionary = GoldenCompare.decode(s["输入"])
			var ctx := Setup.跑完(inp["我方"], inp["敌方规格"], inp["种子"], inp["选项"])
			场 += 1
			if ctx.result == null or ctx.log.is_empty() or ctx.log[-1].get("类型") != "结束":
				坏.append(s["id"])
			elif ctx.result.结果 == "胜":
				胜 += 1
	t.ok(坏.is_empty(), "正式规则：%d 场全部正常结束（胜 %d）%s" % [场, 胜, "" if 坏.is_empty() else str(坏.slice(0, 5))])
