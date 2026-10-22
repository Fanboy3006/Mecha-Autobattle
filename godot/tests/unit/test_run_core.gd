## Stage M3-Core-B 单元测试：
##   ① 黄金样例对拍（`tests/golden/run_vectors.json` 的「招募券」8 局 / 「晋升面板」68 条 / 「战术牌三选一」34 条）
##   ② 1~4 层整局 Headless 通关冒烟（真调 Battle Core `Setup.开局` + `Setup.打一回合`）
##   ③ 同种子跑两遍 `state.to_dict()` 逐字节一致
##   ④ 存档往返（第 2 层中途存 → 读 → 继续打完）与不中断连打逐字节相同
##   ⑤ 藏品 / 节点结算 / 坏档兜底
## 本文件属于 J.* 禁令地盘（`res://core/run`、`res://session` 之外），但**只用原生 GDScript**。
extends RefCounted

const 种子们 := [20261010, 20261011, 20261012, 20261013, 20261014, 20261015, 20261016, 20261017]

func run(t) -> void:
	var errors := []
	DataLoader.install(errors)
	t.ok(Db.installed, "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	_对拍招募券(t)
	_对拍晋升面板(t)
	_对拍战术牌三选一(t)
	_整局通关(t)
	_存档往返(t)
	_藏品与节点(t)

# ======================== ① 招募券 ========================
func _对拍招募券(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 块: Array = data.get("招募券", [])
	t.ok(块.size() == 8, "招募券样例 8 局")
	var 坏 := 0
	var 首错 := ""
	for raw in 块:
		var v: Dictionary = GoldenCompare.decode(raw)
		var 种子 := int(v["种子"])
		# 1) 开局 3 张 + 分队券
		var s := RosterManager.new_run(种子, "无")
		var 开局 := []
		for c in s.tickets:
			开局.append({"类": RosterManager.券类(c), "名": String(c["名"]), "档": c.get("档"), "来源": String(c["来源"])})
		var d1 := GoldenCompare.diff(_券列表(v["开局券"]), _券列表(开局), "第 %d 种子 开局券" % 种子)
		if d1 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d1
		var d2 := GoldenCompare.diff(s.tickets.size(), 3, "开局券张数")
		if d2 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d2
		# 2) `随机券` 5 个偏移（纯函数）
		var 随机 := []
		for i in 5:
			var 选 := RosterManager.随机券(s, i)
			随机.append({"偏移": i, "类": String(选.get("类")) if not 选.is_empty() else null,
				"名": String(选.get("名")) if not 选.is_empty() else null})
		var d3 := GoldenCompare.diff(_随机列表(v["随机"]), _随机列表(随机), "第 %d 种子 随机券" % 种子)
		if d3 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d3
		# 3) `掷战后券` 三档（有副作用：三档都掷，且都往 `券` 里推）
		var 战后 := []
		for 档 in ["战斗", "精英", "Boss"]:
			var 券: Variant = RosterManager.掷战后券(s, 档)
			if 券 == null:
				战后.append({"档": 档, "券": null})
			else:
				战后.append({"档": 档, "券": {"类": RosterManager.券类(券), "名": String(券["名"]), "档": null, "来源": String(券["来源"])}})
		var d4 := GoldenCompare.diff(v["战后"], 战后, "第 %d 种子 战后掷" % 种子)
		if d4 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d4
		# 4) 「发券后手上」（开局 3 + 战后掷中的那几张）
		var 手上 := []
		for c in s.tickets:
			手上.append({"类": RosterManager.券类(c), "名": String(c["名"]), "档": c.get("档"), "来源": String(c["来源"])})
		var d5 := GoldenCompare.diff(_券列表(v["发券后手上"]), _券列表(手上), "第 %d 种子 发券后手上" % 种子)
		if d5 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d5
		# 5) 分队券（第 1 张 = 分队名）
		var 分队 := String(String((v["分队券"] as Dictionary)["分队"]))
		var s2 := RosterManager.new_run(种子, 分队)
		var 队券 := []
		for c in s2.tickets:
			队券.append({"类": RosterManager.券类(c), "名": String(c["名"]), "档": c.get("档"), "来源": String(c["来源"])})
		var d6 := GoldenCompare.diff(v["分队券"]["开局券"], 队券, "第 %d 种子 分队券（%s）" % [种子, 分队])
		if d6 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d6
	t.ok(坏 == 0, "招募券 8 局逐字段对齐（8 局 × 开局 3 张 + 随机 5 偏移 + 战后 3 档 + 分队券）：%s"
		% ("全对" if 坏 == 0 else "有 %d 处分叉，首处：%s" % [坏, 首错]))

func _券列表(a: Variant) -> Array:
	var 出 := []
	for c in (a if a is Array else []):
		var d: Dictionary = c
		var 条 := {"类": d.get("类"), "名": d.get("名"), "档": d.get("档"), "来源": d.get("来源")}
		出.append(条)
	return 出

func _随机列表(a: Variant) -> Array:
	var 出 := []
	for c in (a if a is Array else []):
		var d: Dictionary = c
		出.append({"偏移": d.get("偏移"), "类": d.get("类"), "名": d.get("名")})
	return 出

# ======================== ② 晋升面板 ========================
func _对拍晋升面板(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 面板: Array = data.get("晋升面板", [])
	var 名册 := {}
	for k in RosterManager.名册键们():
		名册[k] = true
	t.ok(面板.size() == 名册.size() * 2, "晋升面板 %d 条 = %d 名机师 × Lv10/Lv20" % [面板.size(), 名册.size()])
	var 坏 := 0
	var 首错 := ""
	var 键集 := {}
	var 孤儿 := 0
	for raw in 面板:
		var p: Dictionary = GoldenCompare.decode(raw)
		var 键 := String(p["键"])
		键集[键] = true
		var 前等级 := int(p["前"]["lv"])
		if not 名册.has(键):
			孤儿 += 1
			坏 += 1
			if 首错.is_empty():
				首错 = "晋升面板里的「%s」不在当前名册（样例与数据脱节）" % 键
			continue
		var 预 := RosterManager.晋升预览(键, 前等级)
		if not (预.get("前") is Dictionary) or (预["前"] as Dictionary).is_empty() or not (预.get("后") is Dictionary) or (预["后"] as Dictionary).is_empty():
			坏 += 1
			if 首错.is_empty():
				首错 = "晋升预览（%s @ Lv%d）拿不到模板 —— 名册与数据脱节" % [键, 前等级]
			continue
		var 价 := RosterManager.晋升要多少(键, int(p["到"]), null)
		var 实际 := {"职业": String(RosterManager.标签(键).get("战斗分类")), "势力": String(RosterManager.标签(键).get("势力")),
			"键": 键, "前": 预["前"], "后": 预["后"], "到": 预["到"], "价": 价}
		var 期望 := {"职业": p["职业"], "势力": p["势力"], "键": p["键"], "前": p["前"], "后": p["后"], "到": p["到"], "价": p["价"]}
		var d := GoldenCompare.diff(期望, 实际, "晋升面板[%s@Lv%d]" % [键, 前等级])
		if d != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d
	t.ok(孤儿 == 0, "★ 晋升面板每一条的角色都在当前名册里（孤儿 %d 条）" % 孤儿)
	t.ok(坏 == 0, "晋升面板 %d 条逐字段对齐（五维 + 速度 + 价格）：%s" % [面板.size(), ("全对" if 坏 == 0 else "有 %d 处分叉，首处：%s" % [坏, 首错])])
	t.ok(键集.size() == 名册.size(), "覆盖 %d 名机师（= 当前名册）" % 名册.size())
	# 券门槛 / 不能跳级 / 希望不够（真实晋升路径）
	var s := RosterManager.new_run(20261010, "无")
	var 招B1 := RosterManager.recruit(s, "B1", _找券(s, "B1"))
	t.ok(招B1["ok"], "用对得上的券招募成功（%s）" % str(招B1.get("why", "")))
	var m: Dictionary = s.roster["B1"]
	t.ok(int(m.get("lv")) == 20, "带队核心（名册第一台）直接 Lv20 入队")
	t.ok(s.lineup.size() == 1, "招募成功后自动编入出击位")
	t.ok(s.pending_card_picks.size() == 3, "招募成功后自动生成 3 选 1 候选")
	var 升1 := RosterManager.promote(s, "B1")
	t.ok(not 升1["ok"], "Lv20 不可跳级 / 无同类券 → 拒绝（%s）" % 升1.get("why", ""))
	var s2 := RosterManager.new_run(20261010, "无")
	var r := RosterManager.recruit(s2, "CB4", _找券(s2, "CB4"))
	t.ok(r["ok"] and int(r["等级"]) == 20, "带队核心判据 = 名册下标 0（第一个招的无论用哪张券都是它）")
	var r2 := RosterManager.recruit(s2, "B1", -1)
	t.ok(not r2["ok"], "没选券 → 招募被拒绝（%s）" % r2.get("why", ""))
	t.ok(s2.roster.size() == 1, "被拒绝时名册与希望一分不动")

## 手上第一张对得上这台机体的券的下标（找不到 -1）。
func _找券(s: RunState, 键: String) -> int:
	for i in s.tickets.size():
		if RosterManager.券合(s.tickets[i], 键):
			return i
	return -1

# ======================== ③ 战术牌三选一 ========================
func _对拍战术牌三选一(t) -> void:
	var data := GoldenIO.load_json("res://tests/golden/run_vectors.json")
	var 块: Array = data.get("战术牌三选一", [])
	t.ok(块.size() == RosterManager.名册键们().size(), "战术牌三选一 %d 条（= 当前名册人数）" % 块.size())
	var 坏 := 0
	var 首错 := ""
	for raw in 块:
		var c: Dictionary = GoldenCompare.decode(raw)
		var 键 := String(c["键"])
		var s := RosterManager.new_run(20261010, "无")
		var 候选 := DeckBuilder.offer_cards(s, 键, 3)
		var 实际 := {"键": 键, "职业": String(RosterManager.标签(键).get("战斗分类")),
			"势力": String(RosterManager.标签(键).get("势力")), "候选": 候选}
		var 期望 := {"键": c["键"], "职业": c["职业"], "势力": c["势力"], "候选": c["候选"]}
		var d := GoldenCompare.diff(期望, 实际, "三选一[%s]" % 键)
		if d != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d
		# 「选走第一张之后再候选」
		var s2 := RosterManager.new_run(20261010, "无")
		var 第一次 := DeckBuilder.offer_cards(s2, 键, 3)
		var 选了 := DeckBuilder.select_card(s2, String(第一次[0])) if not 第一次.is_empty() else false
		var 再来 := DeckBuilder.offer_cards(s2, 键, 3)
		var 实际2 := {"第一次": 第一次, "选成功": 选了, "选后再候选": 再来}
		var 期望2 := {"第一次": c["第一次"], "选成功": c["选成功"], "选后再候选": c["选后再候选"]}
		var d2 := GoldenCompare.diff(期望2, 实际2, "三选一选后[%s]" % 键)
		if d2 != "":
			坏 += 1
			if 首错.is_empty():
				首错 = d2
	t.ok(坏 == 0, "三选一 %d 条逐字段对齐（含「选走第一张后再候选」、0 次随机数）：%s" % [块.size(),
		("全对" if 坏 == 0 else "有 %d 处分叉，首处：%s" % [坏, 首错])])

	# 随机数 0 次的硬证据：拿同一个 state 连算两遍，中间不消耗随机数
	var s3 := RosterManager.new_run(20261010, "无")
	var a := DeckBuilder.offer_cards(s3, "B1", 3)
	var b := DeckBuilder.offer_cards(s3, "B1", 3)
	t.ok(a == b, "候选是纯函数（同一局连算两遍逐项相同）")

# ======================== ④ 整局通关 ========================
## 从「选分队开新局」一路打到第 4 层终点 Boss 通关。返回 `{state, 日志}`。
## `存档点` > 0 时在第 N 层**打完那一场之后**存档 → 读档 → 用读回来的那一份接着打。
## ★ 编成种子在**开战前**用 `NodeResolver.编成种子(s, 层)` 固定算好，所以「存档 → 读档 → 接着打」
##   抽到的编成与不中断连打完全一样（两遍才能逐字节对得上）。
func _跑一整局(t, 存档点: int = -1) -> Dictionary:
	var s := RosterManager.new_run(20261010, "无")
	var 记 := []
	_自动招募(s, 记)
	# ★ 冒烟测试的「玩家侧」：**故意把名册按玩法补几名机师**（三张券只够招 2~3 台，
	#   第 1 层普通编成摆 5 台 = 开局 2 打 5 必输，这是**平衡问题**不是内核 bug）。
	#   补位走的是同一套 `state.roster` 结构（Lv10 = 这一层的招募等级），**不碰任何机制**。
	var 补 := 0
	for t2 in (Db.T["ALLY_T"] as Array):
		if s.roster.size() >= 6 or 补 >= 6:
			break
		var k := String(t2["mech"])
		if s.roster.has(k):
			continue
		s.roster[k] = {"key": k, "lv": 10, "hpRatio": 1.0}
		if s.lineup.size() < RosterManager.deploy_limit(s):
			s.lineup.append({"key": k, "slot": ""})
		补 += 1
	记.append("开局名册 %d 台 %s" % [s.roster.size(), str(s.roster.keys())])
	# 每一层：进层 → 打一场真战斗 → 战后结算（回血 / 券 / 藏品 / 源碳 / 经验）→ 招募与晋升
	var 战斗场次 := 0
	var 各层战果 := {}
	for 层 in range(1, 5):
		s.floor_num = 层
		s.battles_fought = 0
		s.node_id = 层
		# 打之前先把这一层的「招募等级」补到名册（照 `RosterManager.招募等级(层)`：1 层 Lv10 / 2 层 Lv20 / 3 层以上 Lv30）
		# ★ 第 1 层收着点（Lv10，别把「带队核心」那条线的意义抹掉），第 2 层起按招募等级补齐
		var 层等级 := RosterManager.招募等级(层)
		for k in s.roster.keys():
			var m: Dictionary = s.roster[k]
			if int(m.get("lv", 10)) < 层等级:
				m["lv"] = 层等级
				s.roster[k] = m
		var 格类型 := "出口守军" if 层 == 4 else ("精英" if 层 == 2 else "作战")
		s.map_data["当前节点类型"] = 格类型
		var 类型 := NodeResolver.战斗类型Of(s, 格类型)
		var rng := Mulberry32.new(NodeResolver.编成种子(s, 层))
		var 详情 := NodeResolver.抽编成兜底(层, 类型, rng)
		s.map_data["本场兜底"] = ({"层": s.floor_num, "格": s.node_id, "到": String(详情["类型"])} if 详情["兜底"] != null else null)
		# ★ RT-3b：`NodeResolver.开战()` 的默认附加选项里**没有** `单机牌组`（生产上由
		#   `GameSession._build_battle_options()` 按「这一局开的是不是单机牌组」补上）。
		#   旧战术手牌链路删掉之后，不带单机牌组的战斗一张牌都打不出来（`Setup.打一回合()` 直接 return），
		#   四层全败 —— 所以这里按施工单第 12 行的口径**带上 `单机牌组` 开局**。
		var ctx := NodeResolver.开战(s, 详情["条目"], 格类型, {"单机牌组": true})
		_打完一场(ctx)
		战斗场次 += 1
		NodeResolver.resolve_battle(s, ctx, 格类型)
		各层战果[层] = String(ctx.result.get("结果"))
		记.append("第 %d 层 %s（编成 %s，%d 台敌人）→ %s，回合 %d，剩我 %d 台 · 源碳 %d 希望 %d 等级 Lv%d"
			% [层, 格类型, 类型, (ctx.get("enemies") as Array).size(), String(ctx.result.get("结果")),
				int(ctx.get("turn", 0)), (ctx.get("allies") as Array).filter(func(u): return float(u.get("hp", 0.0)) > 0.0).size(),
				s.carbon, s.hope, s.level])
		if s.status == "失败":
			break
		_自动招募(s, 记)
		_自动晋升(s, 记)
		# 每一层的**编队**：把名册里等级最高的几台摆满出击位（照编队屏的口径，最多 `出击上限()` 台）
		_重新编队(s)
		if 存档点 == 层:
			var 路径 := "user://test_run_core_存档点.json"
			if not SaveService.save_to_file(s, 路径):
				记.append("★ 存档失败")
			var 回 := SaveService.load_from_file(路径)
			if 回 == null:
				记.append("★ 读档失败")
			else:
				var 同 := _逐字节相同(s.to_dict(), 回.to_dict())
				记.append("★ 第 %d 层存档往返一致=%s" % [层, "是" if 同 == "" else "否：" + 同])
				s = 回
	# 打赢第 4 层终点 Boss → 通关（★ 判据用**最后一战的真实战果**，不是随便置状态）
	if s.status != "失败":
		NodeResolver.清空格(s)
		s.status = "胜利"
		s.add_log("通关！走了 %d 层、打了 %d 场" % [s.floor_num, 战斗场次])
	return {"state": s, "日志": 记, "场次": 战斗场次, "各层战果": 各层战果}

## 摆满出击位（按名册顺序，最多 `RosterManager.deploy_limit()` 台）—— 照编队屏的口径。
func _重新编队(s: RunState) -> void:
	var 上限 := RosterManager.deploy_limit(s)
	var 新 := []
	for k in s.roster.keys():
		if 新.size() >= 上限:
			break
		新.append({"key": String(k), "slot": ""})
	s.lineup = 新

## 打一整场（`Setup.打一回合` 一直推到出结果为止）。
## ★ RT-3b：旧「战术手牌」字段已随旧模式一起删除，这里不再每回合先打一张战术牌
##   （那条路读的 `ctx.战术手牌` 在新模式下恒为 null，本来也一张都打不出去）。
func _打完一场(ctx: Dictionary) -> void:
	var 顶 := maxf(float(Db.T.get("MAX_TURN", 12.0)), float(ctx.get("回合上限", 12.0))) + 2.0
	var 护栏 := 0.0
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		Setup.打一回合(ctx)
	if ctx.result == null:
		ctx.result = {"结果": "败", "原因": "超出回合上限"}
	Btl.pushLog(ctx, "战斗结束：%s（%s）" % [ctx.result.结果, ctx.result.原因], {"类型": "结束"})

## 把所有手上的券用掉（每次招募成功都顺手把 3 选 1 选掉第一张）。
func _自动招募(s: RunState, 记: Array) -> void:
	var 上限 := 8
	var 招 := 0
	while 招 < 上限 and not s.tickets.is_empty():
		var 目标 := ""
		var 下标 := -1
		for i in s.tickets.size():
			for t2 in (Db.T["ALLY_T"] as Array):
				var k := String(t2["mech"])
				if s.roster.has(k):
					continue
				if RosterManager.券合(s.tickets[i], k):
					目标 = k
					下标 = i
					break
			if 下标 >= 0:
				break
		if 下标 < 0:
			break
		var r := RosterManager.recruit(s, 目标, 下标)
		if not r["ok"]:
			break
		记.append("  招募 %s Lv%d（带队核心=%s，用掉一张 %s）" % [目标, int(r["等级"]), str(r["带队核心"]), String(r["券名"])])
		if s.pending_card_picks.size() > 1:
			DeckBuilder.select_card(s, String(s.pending_card_picks[0]))
		招 += 1

## 名册上每台 Lv10 / Lv20 的都试着升一档（有同类券 + 希望够才成）。
func _自动晋升(s: RunState, 记: Array) -> void:
	for k in s.roster.keys():
		var 键 := String(k)
		var 从 := RosterManager.整数(s.roster[键].get("lv"), 10)
		if 从 >= 30:
			continue
		var r := RosterManager.promote(s, 键)
		if r["ok"]:
			记.append("  晋升 %s Lv%d → Lv%d（−%d 希望）" % [键, int(r["从"]), int(r["到"]), int(r["价"])])

func _整局通关(t) -> void:
	var 一 := _跑一整局(t)
	var s: RunState = 一["state"]
	for 行 in 一["日志"]:
		t.info(String(行))
	t.ok(s.status == "胜利", "整局冒烟：第 1~4 层全打赢、通关（状态=%s，停在第 %d 层）" % [s.status, s.floor_num])
	t.ok(String(一["各层战果"].get(4, "")) == "胜", "★ 第 4 层终点 Boss 是**真打赢**的（四层战果：%s）" % str(一["各层战果"]))
	t.ok(s.roster.size() >= 3, "名册 %d 台、藏品 %d 件、源碳 %d、希望 %d、出击上限 %d、战术牌库 %d 张"
		% [s.roster.size(), s.relics.size(), s.carbon, s.hope, RosterManager.deploy_limit(s), s.tactical_deck.size()])
	t.ok(s.level >= 2 and s.status == "胜利", "战斗把肉鸽等级抬起来了（Lv%d）" % s.level)
	var 探 := RosterManager.new_run(1, "无")
	var 结经 := RosterManager.加经验(探, 9, "测试")
	t.ok(int(结经["等级"]) == 2 and int(结经["升了"]) == 1 and 探.hope > 8,
		"`加经验(9)`：Lv1 → Lv2（升了 %d 级，希望 %d → %d，门槛 8）" % [int(结经["升了"]), 8, 探.hope])
	t.ok(RosterManager.升级门槛(1) == 8 and RosterManager.升级门槛(2) == 18, "等级门槛表从 `肉鸽数值.等级门槛` 读（1→2 要 8、2→3 要 18）")
	var 比 := []
	for k in s.roster.keys():
		比.append("%s=%d%%" % [k, int(RosterManager.数(s.roster[k].get("hpRatio"), 1.0) * 100.0)])
	t.info("通关时的名册 HP 比例：" + "、".join(比))

	# ★ HP 跨战继承 + 战后回血 50% 的**受控**验证（不靠上面的运气）
	var h := RosterManager.new_run(20261010, "无")
	h.roster = {"B1": {"key": "B1", "lv": 10, "hpRatio": 0.5}, "B2": {"key": "B2", "lv": 10, "hpRatio": 0.0}}
	h.lineup = [{"key": "B1", "slot": ""}, {"key": "B2", "slot": ""}]
	h.map_data["当前节点类型"] = "作战"
	var 敌方 := [{"键": "grunt", "位": 0.0, "等级": 10.0, "强化": 1.0, "层": 1}, {"键": "grunt", "位": 1.0, "等级": 10.0, "强化": 1.0, "层": 1}]
	var ctx := Setup.开局([{"键": "B1", "位": 0.0, "等级": 10.0}, {"键": "B2", "位": 1.0, "等级": 10.0}], 敌方, 1, null, {})
	ctx.allies[0].hp = float(ctx.allies[0].maxHp) * 0.2     # 打之前把这台按到 20%
	ctx.allies[1].hp = 0.0                                  # 这一台在第 0 回合就被击坠（阵亡）
	ctx.result = {"结果": "胜", "原因": "测试直接给结果"}
	h.battles_won = 0
	NodeResolver.resolve_battle(h, ctx, "作战")
	t.ok(absf(RosterManager.数(h.roster["B1"].get("hpRatio")) - 0.7) < 0.0001,
		"HP 跨战继承：本场打到 20%% → 记回名册 → 战后回血 50%% → 70%%（实际 %d%%）"
		% int(RosterManager.数(h.roster["B1"].get("hpRatio")) * 100.0))
	t.ok(absf(RosterManager.数(h.roster["B2"].get("hpRatio")) - 0.5) < 0.0001,
		"阵亡机体（0 HP）**永不永久死亡**：战后回到 50%%（实际 %d%%）"
		% int(RosterManager.数(h.roster["B2"].get("hpRatio")) * 100.0))
	t.ok(h.roster.has("B1") and h.roster.has("B2"), "阵亡机体仍然留在名册里")
	t.ok(NodeResolver.倒下单位数(h) == 0, "回血之后名册里没有倒下的")

	t.ok(s.tactical_deck.size() > 0, "战术牌库 %d 张" % s.tactical_deck.size())

	# 同种子两遍逐字节一致
	var 二 := _跑一整局(t)
	var d := _逐字节相同(s.to_dict(), (二["state"] as RunState).to_dict())
	t.ok(d == "", "同种子跑两遍 `to_dict()` 逐字节一致%s" % ("" if d == "" else "：" + d))

# ======================== ⑤ 存档往返 ========================
func _存档往返(t) -> void:
	var 一 := _跑一整局(t, 2)
	var s: RunState = 一["state"]
	for 行 in 一["日志"]:
		if String(行).begins_with("★"):
			t.info(String(行))
	t.ok(s.status == "胜利", "存档往返那一趟也打到了通关（状态=%s）" % s.status)
	var 二 := _跑一整局(t)
	var d := _逐字节相同(s.to_dict(), (二["state"] as RunState).to_dict())
	t.ok(d == "", "第 2 层中途存档 → 读档 → 打完第 2~4 层：与不中断连打逐字节相同%s" % ("" if d == "" else "：" + d))

	# save_to_file / load_from_file 的往返（不经过整局）
	var a := RosterManager.new_run(20261010, "近卫")
	# 序列化器是自写的（不走 `JSON.stringify`），先单测一层：键顺序 / 数值编码 / 整数保住
	t.ok(SaveService.serialize(a).begins_with('{"版本":4,"种子":20261010,"分队":"近卫"'),
		"`serialize` 保持 `to_dict()` 的**键顺序**（头一段逐字对）")
	t.ok(SaveService.serialize({"x": 1}) == '{"x":1}' and SaveService.serialize({"y": 0.5}) == '{"y":{"$f":"000000000000e03f"}}',
		"`serialize` 的数值编码：整数照写、非整数走 `{\"$f\": 16 位十六进制小端}`（%s）" % SaveService.serialize({"y": 0.5}))
	t.ok(_逐字节相同({"x": 1, "y": 0.5}, SaveService.parse_dict('{"x":1,"y":{"$f":"000000000000e03f"}}')) == "",
		'`parse_dict` 把 `{"$f": …}` 还原成 float（0.5）')
	RosterManager.recruit(a, "B1", _找券(a, "B1"))
	a.floor_num = 3
	a.node_id = 12
	a.carbon = 31
	a.hope = 9
	a.relics = ["d3", "f1"]
	a.parts = [{"id": "wheel", "uses": 1, "value": null}]
	a.map_data["当前节点类型"] = "黑市"
	a.map_data["格"] = {"12": {"类型": "黑市", "已过": false}}
	a.map_data["_rogue"] = {"黑市刷新次数": 2, "希望来源": {"初始": 8, "战斗": 3, "支出": 2}}
	var p := "user://test_run_core_往返.json"
	t.ok(SaveService.save_to_file(a, p), "`save_to_file` 写盘成功")
	var b := SaveService.load_from_file(p)
	t.ok(b != null, "`load_from_file` 读得回来")
	if b != null:
		var d2 := _逐字节相同(a.to_dict(), b.to_dict())
		t.ok(d2 == "", "往返后 `to_dict()` 逐字节相同（含 `map_data` 里的额外态）%s" % ("" if d2 == "" else "：" + d2))
		t.ok(typeof(b.carbon) == TYPE_INT and typeof(b.hope) == TYPE_INT and typeof(b.floor_num) == TYPE_INT
			and typeof(b.get_unit_level("B1")) == TYPE_INT and b.carbon == 31 and b.get_unit_level("B1") == 20,
			"往返不带出 float：整数型字段（源碳 %s / 希望 %s / 层 %s / 名册等级 %s）逐字段保住 int"
			% [type_string(typeof(b.carbon)), type_string(typeof(b.hope)), type_string(typeof(b.floor_num)), type_string(typeof(b.get_unit_level("B1")))])
		t.ok(absf(float(SaveService.parse_dict('{"x":0.78}')["x"]) - 0.78) < 1e-15, "非整数值照旧精确往返（0.78）")
	# 坏档兜底
	t.ok(SaveService.deserialize("") == null, "空字符串 → null")
	t.ok(SaveService.deserialize("{坏 JSON") == null, "坏 JSON → null")
	t.ok(SaveService.deserialize("[1,2,3]") == null, "不是对象 → null")
	t.ok(SaveService.deserialize("null") == null, "null → null")
	var 缺 := SaveService.deserialize('{"版本":4}')
	t.ok(缺 != null and 缺.seed_val == 1 and 缺.floor_num == 1 and 缺.carbon == 18, "缺字段 → 补默认值（不崩）")
	var 旧 := SaveService.deserialize('{"版本":1,"种子":7,"层":2,"源碳":-5,"希望":3,"基地耐久":999,"基地最大耐久":10,"等级":0,"经验":-1}')
	t.ok(旧 != null and 旧.carbon == 0 and 旧.base_hp == 10 and 旧.level == 1 and 旧.exp_val == 0, "旧版本号 / 坏值（负数、越界）被夹回默认值，不崩")
	t.ok(SaveService.load_from_file("user://不存在的存档.json") == null, "文件不存在 → null")

## 逐字节比对（递归）：字典的**键顺序与键集**必须一致、数组长度必须一致、字符串逐字一致。
## 数字按数值比（JSON 只认数字，int / float 在这里等价 —— 与 `GoldenCompare.diff` 同一口径）。
func _逐字节相同(a: Variant, b: Variant, 路径: String = "") -> String:
	if (a is int or a is float) and (b is int or b is float):
		return "" if float(a) == float(b) else "%s：%s vs %s" % [路径, str(a), str(b)]
	if typeof(a) != typeof(b):
		return "%s：类型不同（%s vs %s）" % [路径, type_string(typeof(a)), type_string(typeof(b))]
	if a is Dictionary:
		var ka: Array = (a as Dictionary).keys()
		var kb: Array = (b as Dictionary).keys()
		if ka != kb:
			return "%s：键顺序 / 键集不同" % 路径
		for k in ka:
			var d := _逐字节相同(a[k], b[k], "%s.%s" % [路径, k])
			if d != "":
				return d
		return ""
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s：长度不同" % 路径
		for i in (a as Array).size():
			var d2 := _逐字节相同(a[i], b[i], "%s[%d]" % [路径, i])
			if d2 != "":
				return d2
		return ""
	if a is float and b is float:
		return "" if (is_nan(a) and is_nan(b)) or a == b else "%s：%f vs %f" % [路径, a, b]
	return "" if a == b else "%s：%s vs %s" % [路径, str(a), str(b)]

# ======================== ⑥ 藏品与节点 ========================
func _藏品与节点(t) -> void:
	t.ok(Db.catalog.relics().size() == 58, "藏品表 58 件")
	var s := RosterManager.new_run(20261010, "无")
	var 得 := RelicSystem.拿藏品(s, "d3", "测试")
	t.ok(not 得.is_empty() and s.relics.has("d3"), "拿藏品成功并入 `state.relics`")
	t.ok(RosterManager.deploy_limit_bonus(s) == -2, "`d3 战线收缩令` 出击上限 −2")
	t.ok(RosterManager.deploy_limit(s) == maxi(1, 4 - 2), "出击上限被藏品修正（%d 台，下限 1）" % RosterManager.deploy_limit(s))
	var 重复 := RelicSystem.拿藏品(s, "d3", "测试")
	t.ok(重复.is_empty(), "同一件藏品不重复发")
	var 前希望 := s.hope
	t.ok(RelicSystem.藏品每层希望(s, 2) == 2 and s.hope == 前希望 + 2, "`d3` 每进一层 +2 希望")
	# d1/d2/c1/c2 的出击上限修正
	var s2 := RosterManager.new_run(20261010, "无")
	s2.level = 7
	var 底 := RosterManager.deploy_limit(s2)
	for id in ["d1", "d2", "c1", "c2", "f4"]:
		RelicSystem.拿藏品(s2, id, "测试")
	t.ok(底 == 6 and RosterManager.deploy_limit(s2) == 7, "编制类藏品把出击上限抬到绝对顶 7 台（等级线 %d → %d）" % [底, RosterManager.deploy_limit(s2)])
	# 精英 / Boss 发藏品 + 拿满转源碳
	var s3 := RosterManager.new_run(20261011, "无")
	var 发 := RelicSystem.战斗胜利发藏品(s3, "精英", 3)
	t.ok(not 发.is_empty() and s3.relics.size() == 1, "精英战胜利发 1 件藏品（%s）" % str(发.get("id")))
	var 普通 := RelicSystem.战斗胜利发藏品(s3, "战斗", 3)
	t.ok(普通.is_empty(), "普通战不发藏品")
	var s4 := RosterManager.new_run(20261011, "无")
	s4.relics = RelicSystem.可抽池()
	var 碳前 := s4.carbon
	var 转 := RelicSystem.战斗胜利发藏品(s4, "Boss", 3)
	t.ok(int(转.get("源碳", 0)) == 5 and s4.carbon == 碳前 + 5, "池子抽干 → 转源碳 +5")
	# 开战选项
	var 选项 := RelicSystem.build_battle_options(s3)
	t.ok(选项["战术卡牌"] == true and 选项["已选战术牌"] == s3.tactical_deck and 选项["藏品"] == s3.relics,
		"`build_battle_options` 显式返回三项")

	# 休整 / 黑市 / 瞭望站 / 遗迹 / 侵蚀源 / 奇遇
	var s5 := RosterManager.new_run(20261010, "无")
	RosterManager.recruit(s5, "B1", _找券(s5, "B1"))
	s5.roster["B1"]["hpRatio"] = 0.2
	s5.floor_num = 2
	var 休 := NodeResolver.结算休整(s5, "耐久")
	t.ok(休["ok"] and s5.base_hp > 10 - 1 and RosterManager.数(s5.roster["B1"].get("hpRatio")) > 0.2, "休整：耐久 +2 且全队回血")
	var 黑 := NodeResolver.黑市货(s5)
	t.ok(黑.size() == 4, "黑市摆 4 件")
	var 价 := NodeResolver.黑市价(s5, String(黑[0]))
	t.ok(价 == 8 or 价 == 12 or 价 == 16, "黑市价按稀有度（普通 8 / 稀有 12 / 传说 16）")
	s5.carbon = 100
	var 买 := NodeResolver.黑市买(s5, String(黑[0]))
	t.ok(买["ok"], "黑市买藏品成功（%s / %s）" % [str(黑[0]), str(买)])
	var 刷 := NodeResolver.黑市刷新(s5)
	t.ok(刷["ok"] and int(刷["价"]) == 4, "黑市刷新第一次 4 源碳")
	var 眺 := NodeResolver.结算瞭望站(s5, "登高")
	t.ok(眺["揭开"] >= 0 and 眺["半径"] == 12, "瞭望站登高：半径 12 格")
	var 遗 := NodeResolver.结算遗迹(s5, "离开")
	t.ok(遗["ok"] and String(遗["选"]) == "离开", "遗迹：离开什么都不拿")
	s5.carbon = 50
	var 侵 := NodeResolver.结算侵蚀源代价(s5, "净化")
	t.ok(侵["ok"] and s5.carbon == 42, "侵蚀源：净化花 8 源碳")
	var 奇 := NodeResolver.结算奇遇(s5, "0")
	t.ok(奇["ok"], "奇遇结算（第 %d 层第 %d 格，事件=%s）" % [s5.floor_num, s5.node_id, str(奇.get("事件"))])
	var 奇2 := NodeResolver.结算奇遇(s5, "0")
	t.ok(奇2.get("重复") == true, "同一格奇遇只结算一次")
