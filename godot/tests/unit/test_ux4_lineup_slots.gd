## ★ UX-4（M4 二轮试玩反馈第 1 条）：**编队屏摆成什么样，进战斗就站什么样**，
##   而且**绝不把玩家特意下阵的名册机体补回战场**。
##
## 这一段守三件事（都是作者实机踩到的）：
##   ① 在编队屏把 `B1` 放到 `后4`（位 7）、另一台放到 `前1`（位 0）→ 开战之后
##      `battle_ctx.allies` 里就是这两个位号（**严禁弹回默认位 0 / 4**）；
##   ② 名册里另外 4 台**没上阵**的机体，一个都不许出现在 `allies` 里；
##   ③ 只带键的名单口径（`lineup` 是纯字符串 / `slot == ""` / 空名单）**逐项不变**
##      （仍是 `_默认位` + 从名册补到 `deploy_limit`）。
##
## 纪律：固定种子、零 `randi` / `randf`，全程不写文件。
extends RefCounted

const 种子 := 20261016

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	_玩家站位(t)
	_显式B1M1站位(t)
	_旧写法不变(t)
	_槽位解析(t)

## ① / ② 玩家摆的格位真的生效 + 未上阵的机体不被补进战场。
func _玩家站位(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "user://test_ux4_lineup.json"   # 只用内存态，全程不存档
	t.ok(s.start_new_run(种子, "混编"), "开一局（种子 %d / 分队「混编」）" % 种子)
	var rs: RunState = s.run_state
	var 名册键: Array = []
	for e in (Db.T["ALLY_T"] as Array):
		if 名册键.size() >= 6:
			break
		var k := str(e.get("mech", ""))
		if k.is_empty() or rs.roster.has(k):
			continue
		rs.roster[k] = {"key": k, "lv": 10, "hpRatio": 1.0}
		名册键.append(k)
	rs.lineup = []
	t.ok(名册键.size() >= 2, "第一次开局的券招出来的名册补到 %d 台（用来造「名册里有人没上阵」的局面）" % 名册键.size())
	var 甲 := str(名册键[0])
	var 乙 := str(名册键[1])
	t.ok(s.set_lineup_slot(甲, "后4"), "在编队屏把 %s 摆到 后4（位 7）" % 甲)
	t.ok(s.set_lineup_slot(乙, "前1"), "在编队屏把 %s 摆到 前1（位 0）" % 乙)
	t.ok(rs.lineup.size() == 2 and int((rs.lineup[0] as Dictionary).get("slot")) == 0,
		"出击名单只留 2 台、每一条都带明确整数位号（%s）" % str(rs.lineup))
	# ---- 内核那条路（NodeResolver.开战）----
	var 条目: Dictionary = NodeResolver.抽编成兜底(1, "普通", Mulberry32.new(1)).get("条目", {})
	var ctx := NodeResolver.开战(rs, 条目)
	var 位表 := _位表(ctx)
	t.info("内核开战 allies = %s" % str(位表))
	t.ok((ctx.get("allies") as Array).size() == 2,
		"★ UX-4 ①：战斗里只有玩家上了阵的 2 台（实际 %d 台）—— 名册里没上阵的 4 台一个都没被塞进来"
		% (ctx.get("allies") as Array).size())
	t.ok(int(位表.get(甲, -1)) == 7 and int(位表.get(乙, -1)) == 0,
		"★ UX-4 ①：%s 站 后4（位 7）、%s 站 前1（位 0）—— 玩家摆的格位真的生效（实际 %s）"
		% [甲, 乙, str(位表)])
	t.ok(int(位表.get(甲, -1)) != 0 or int(位表.get(乙, -1)) != 4,
		"★ UX-4 ①：没有弹回 `默认五人队` 的写死位（B1 → 0 / M1 → 4 那种）")
	# ---- 门面那条路（战前编队确认 → 确认开战）----
	var 战斗格 := -1
	for k in rs.map_data.get("格", {}).keys():
		var 类型 := str(rs.cell_at(int(k)).get("类型", ""))
		if 类型 == "作战" or 类型 == "精英" or 类型 == "守军" or 类型 == "侵蚀源":
			战斗格 = int(k)
			break
	if 战斗格 < 0:
		t.ok(false, "第 1 层找不到战斗格，段「战前编队确认」跑不了")
		return
	rs.node_id = 战斗格
	rs.mark_visited(战斗格)
	var 预 := s.prepare_battle_formation("node")
	t.ok(int(预.get("自动补", -1)) == 0 and rs.lineup.size() == 2,
		"★ UX-4 ②：进战前编队确认屏时**一台都不自动补**（自动补 %s，出击 %d 台）"
		% [str(预.get("自动补", -1)), rs.lineup.size()])
	s.confirm_formation_and_start_battle()
	var 门面位 := _位表(s.battle_ctx)
	t.info("门面开战 allies = %s（screen = %s）" % [str(门面位), s.screen])
	t.ok(str(s.screen) == "battle" and 门面位.size() == 2
		and int(门面位.get(甲, -1)) == 7 and int(门面位.get(乙, -1)) == 0,
		"★ UX-4 ①：走门面「确认编队 · 开始战斗」也是 %s → 7、%s → 0、只有 2 台（实际 %s）"
		% [甲, 乙, str(门面位)])
	# ---- 编队屏看到的站位 == 开战用的站位（旧档 `slot == ""` 会在进屏时补成明确位号）----
	rs.lineup = [{"key": 甲, "slot": ""}, {"key": 乙, "slot": ""}]
	t.ok(s.normalize_lineup_slots(), "★ UX-4 ③：旧档 `slot == \"\"` 进编队屏后被补成明确位号（%s）" % str(rs.lineup))
	var 屏上 := {}
	for 条 in s.lineup_slots():
		if 条 is Dictionary and not str(条.get("键", "")).is_empty():
			屏上[str(条.get("键"))] = str(条.get("位名", ""))
	var 战场 := {}
	for x in NodeResolver.我方编成(rs):
		战场[str(x.get("键"))] = Fm.位名(float(x.get("位", -1)))
	t.ok(屏上 == 战场 and not 屏上.is_empty(),
		"★ UX-4 ③：编队屏画出来的格位 == 进战斗用的格位（编队屏 %s / 战斗 %s）" % [str(屏上), str(战场)])

## ★ 任务单 §2 门禁 ①的**字面用例**：`B1` 放 `后4`（位 7）、`M1` 放 `前1`（位 0），
##   名册里另外 4 台（含第 6 台 `B3`）没上阵 → 一台都不许出现在 `battle_ctx.allies` 里。
##   （`_玩家站位()` 那张用例的第二台不一定是 M1，所以这一条**显式点名** B1 / M1。）
func _显式B1M1站位(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "user://test_ux4_b1m1.json"   # 只用内存态，全程不存档
	t.ok(s.start_new_run(种子 + 1, "混编"),
		"★ UX-4 ①：为「B1 + M1」这条字面用例再开一局（种子 %d）" % (种子 + 1))
	var rs: RunState = s.run_state
	if rs == null:
		t.ok(false, "没有 run_state → 「B1 + M1」这段跑不了")
		return
	# 造一份「6 台在名册、只上阵 2 台」的局面（与 `_造旧状态()` 用同一批机体键）。
	var 六台 := ["B1", "M1", "B2", "CB4", "CB2", "B3"]
	rs.roster = {}
	for k in 六台:
		rs.roster[k] = {"key": k, "lv": 10, "hpRatio": 1.0}
	rs.lineup = []
	t.ok(s.set_lineup_slot("B1", "后4"), "★ UX-4 ①：编队屏把 B1 拖到 后4（位 7）")
	t.ok(s.set_lineup_slot("M1", "前1"), "★ UX-4 ①：编队屏把 M1 拖到 前1（位 0）")
	t.ok(rs.lineup.size() == 2, "★ UX-4 ①：出击名单正好 2 台（%s）" % str(rs.lineup))
	# ---- 内核那条路：直接问 `NodeResolver.我方编成()` ----
	var 内核 := {}
	for x in NodeResolver.我方编成(rs):
		内核[str(x.get("键"))] = int(float(x.get("位", -1)))
	t.info("内核 我方编成 = %s" % str(内核))
	t.ok(int(内核.get("B1", -1)) == 7,
		"★ UX-4 ①：内核编成里 B1 站 后4（位 7，实际 %s）—— 没弹回默认位 0" % str(内核.get("B1", -1)))
	t.ok(int(内核.get("M1", -1)) == 0,
		"★ UX-4 ①：内核编成里 M1 站 前1（位 0，实际 %s）—— 没弹回默认位 4" % str(内核.get("M1", -1)))
	# ---- 门面那条路：编队屏确认 → 真的开战 → `battle_ctx.allies` ----
	var 战斗格 := -1
	for k in rs.map_data.get("格", {}).keys():
		var 类型 := str(rs.cell_at(int(k)).get("类型", ""))
		if 类型 == "作战" or 类型 == "精英" or 类型 == "守军" or 类型 == "侵蚀源":
			战斗格 = int(k)
			break
	if 战斗格 < 0:
		t.ok(false, "第 1 层找不到战斗格 → 「B1 + M1」的开战那一步跑不了")
		return
	rs.node_id = 战斗格
	rs.mark_visited(战斗格)
	var 预 := s.prepare_battle_formation("node")
	t.ok(int(预.get("自动补", -1)) == 0,
		"★ UX-4 ①：战前编队确认屏一台都不自动补（自动补 %s）" % str(预.get("自动补", -1)))
	s.confirm_formation_and_start_battle()
	var 门面位 := _位表(s.battle_ctx)
	t.info("门面开战 battle_ctx.allies = %s（screen = %s）" % [str(门面位), s.screen])
	var 台数 := (s.battle_ctx.get("allies") as Array).size() if s.battle_ctx.get("allies") is Array else 0
	t.ok(str(s.screen) == "battle" and 台数 == 2,
		"★ UX-4 ①：确认开战之后 `battle_ctx.allies` 正好 2 台（实际 %d 台 / screen %s）" % [台数, str(s.screen)])
	t.ok(int(门面位.get("B1", -1)) == 7,
		"★ UX-4 ①：`battle_ctx.allies` 里 B1.slot == 7（后4）—— 严禁弹回默认位 0（实际 %s）"
		% str(门面位.get("B1", "没这台")))
	t.ok(int(门面位.get("M1", -1)) == 0,
		"★ UX-4 ①：`battle_ctx.allies` 里 M1.slot == 0（前1）—— 严禁弹回默认位 4（实际 %s）"
		% str(门面位.get("M1", "没这台")))
	# ---- 未上阵的另外 4 台（含第 6 台 B3）一台都不许混进来 ----
	var 未上阵 := ["B2", "CB4", "CB2", "B3"]
	var 混进来 := 未上阵.filter(func(k): return 门面位.has(k))
	t.ok(混进来.is_empty(),
		"★ UX-4 ①：名册里没上阵的 4 台（含第 6 台 B3）一台都没被塞进 `battle_ctx.allies`（混进来：%s）" % str(混进来))
	t.ok(门面位.size() == 2 and int(门面位.get("B3", -1)) == -1,
		"★ UX-4 ①：`battle_ctx.allies` 的键就只有 B1 / M1 两台（实际 %s）" % str(门面位.keys()))

## `battle_ctx.allies` → `{键: 位号}`。
func _位表(ctx: Dictionary) -> Dictionary:
	var out := {}
	for u in (ctx.get("allies") if ctx.get("allies") is Array else []):
		if u is Dictionary:
			out[str(u.get("key", ""))] = int(float(u.get("slot", -1)))
	return out

## ③ 只带键的名单逐项不变：`lineup` 是纯字符串 / `slot == ""` / 空名单 / 混写 / 超上限
##     → 与 `_默认位` + 从 `roster` 补到 `deploy_limit` 的口径**逐项相同**。
func _旧写法不变(t) -> void:
	var 样例 := {
		"空名单": [],
		"空串槽位": [{"key": "B3", "slot": ""}, {"key": "B1", "slot": ""}],
		"纯字符串": ["B2", "M1"],
		"混写": [{"key": "CB2", "slot": ""}, "CB4", {"key": "M1"}],
		"超出上限": [{"key": "B1", "slot": ""}, {"key": "B2", "slot": ""}, {"key": "CB4", "slot": ""},
			{"key": "M1", "slot": ""}, {"key": "CB2", "slot": ""}, {"key": "B3", "slot": ""}],
	}
	var 分叉 := []
	for 名 in 样例.keys():
		var h := _造旧状态(样例[名])
		var 新 := NodeResolver.我方编成(h)
		var 旧 := _旧实现编成(h)
		t.info("[%s] %s" % [名, str(新)])
		if str(旧) != str(新):
			分叉.append(名)
	t.ok(分叉.is_empty(),
		"★ UX-4 ③：旧写法（空名单 / 空串槽位 / 纯字符串 / 混写 / 超上限）与改动前**逐项相同**（不同：%s）"
		% str(分叉))

func _造旧状态(出击: Array) -> RunState:
	var h := RosterManager.new_run(20261010, "无")
	h.roster = {
		"B1": {"key": "B1", "lv": 10, "hpRatio": 1.0}, "B2": {"key": "B2", "lv": 10, "hpRatio": 1.0},
		"CB4": {"key": "CB4", "lv": 10, "hpRatio": 1.0}, "M1": {"key": "M1", "lv": 10, "hpRatio": 1.0},
		"CB2": {"key": "CB2", "lv": 10, "hpRatio": 1.0}, "B3": {"key": "B3", "lv": 10, "hpRatio": 1.0},
	}
	h.lineup = 出击
	return h

## 改动前的 `我方编成()`（逐字照抄，只用于对拍）。
func _旧实现编成(state: RunState) -> Array:
	var 名册键 := state.roster.keys()
	var 出击 := []
	for x in state.lineup:
		if x is Dictionary:
			出击.append(str(x.get("key")))
		elif x is String:
			出击.append(str(x))
	var 缺 := []
	for k in 名册键:
		if not 出击.has(k):
			缺.append(k)
	var 排位: Array = Db.T.get("默认五人队") if Db.T.get("默认五人队") is Array else []
	var 出 := []
	var 已用 := {}
	for k in 出击:
		if not state.roster.has(k) or 已用.has(k):
			continue
		已用[k] = true
		var 位 := _旧默认位(排位, k, 出.size())
		出.append({"键": k, "位": 位, "等级": float(RosterManager.整数(state.roster[k].get("lv"), 10)), "hp比": state.roster[k].get("hpRatio")})
	for k in 缺:
		if 出.size() >= RosterManager.deploy_limit(state):
			break
		已用[k] = true
		出.append({"键": k, "位": _旧默认位(排位, k, 出.size()), "等级": float(RosterManager.整数(state.roster[k].get("lv"), 10)), "hp比": state.roster[k].get("hpRatio")})
	return 出

func _旧默认位(排位: Array, 键: String, 序: int) -> float:
	for e in 排位:
		if e is Dictionary and str(e.get("键")) == 键:
			return float(e.get("位", 序))
	return float(序 % int(Fm.SLOTS()))

## 槽位名 → 位号 的统一映射表（含 `后5` 兼容与整数 / 数字字符串）。
func _槽位解析(t) -> void:
	var 表 := {"前1": 0, "前2": 1, "前3": 2, "前4": 3, "后1": 4, "后2": 5, "后3": 6, "后4": 7, "后5": 8}
	var 坏 := []
	for k in 表.keys():
		if NodeResolver.解析槽位(k) != int(表[k]):
			坏.append(k)
	t.ok(坏.is_empty(), "★ UX-4：槽位名 → 战斗格位号 的映射逐项对（错：%s）" % str(坏))
	t.ok(NodeResolver.解析槽位(7) == 7 and NodeResolver.解析槽位("7") == 7 and NodeResolver.解析槽位(7.0) == 7,
		"★ UX-4：整数 `7` / 数字字符串 `\"7\"` / 浮点整值 `7.0` 都认成 7")
	t.ok(NodeResolver.解析槽位("") == -1 and NodeResolver.解析槽位(null) == -1
		and NodeResolver.解析槽位("乱写") == -1 and NodeResolver.解析槽位(9) == -1,
		"★ UX-4：空串 / null / 认不出 / 越界（9）一律返回 −1（→ 调用方走 `_默认位` 兜底）")
