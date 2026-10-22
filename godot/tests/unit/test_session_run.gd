## ★ 端到端回归：**用门面（`GameSession`）完整打通一局肉鸽**（固定种子 20261016 / 分队「混编」）。
##
## 为什么非要有这一条（M4 交付后 ARGON 用一次性脚本跑出来的两个缺陷，当时 713 项断言**一条都没抓到**）：
##   · **D-06**：门面在 `start_new_run` / `move_to_cell` / `use_part` / `resolve_event_choice` 四处
##     **自造「三选一」**（每走一格弹一次，还把换层永久拦住）—— 封存 JS 里 `R.待选战术牌` 只由
##     **招募**（`90-肉鸽-5-晋升与通关.js:62`）与**晋升**（同文件 `:151`）两处产生。
##   · **D-07**：`finish_battle_and_settle()` **不幂等** —— 实测第 1 层原地连结算 496 次、一步没走、
##     胜场 +496、源碳 +1984。
## 这两个缺陷的共性是「**门面比内核多做一点事**」，而**门面不在黄金样例的覆盖面上** ——
## 只有「把一整局真的跑完」这种**消费方式**才照得出来。本文件就是把这种跑法固化成门禁。
##
## 策略（照 ARGON 跑通的那一份）：固定种子 → 每层「招募 → 编队 → 隔离平衡 → 走格 / 进节点 /
##   打一场就当场结算 / 走到出口换层」→ 最多 500 步；**只走相邻格**（不跳格：跳格是内核规则，
##   但会直接跳过中间节点，那样「进节点」这条链就测不到了）。
##
## 纪律：固定种子、**零随机数调用**（`randi` / `randf` / `randomize` 一个都没有）、零 `J.*`。
##   随机性全部落在内核自己的 `Mulberry32(种子)` 里，所以整条轨迹逐项可复现 ——
##   文件末尾**同种子跑第二遍**并逐项对账（这一趟只多花 ~1.6 秒，不拖慢门禁）。
extends RefCounted

const 种子 := 20261016
const 分队 := "混编"
const 最大步数 := 500
## 隔离平衡用：把名册等级统一到 30。
##   ★ **这一条测的是「接线能不能走通」，不是平衡。** 不隔离的话「打不打得赢」会跟着数值变动，
##   门禁就会因为一次数值调整变成假红 —— 那不是这条测试要照的东西。
const 平衡等级 := 30

## 会开战的节点类型（与 `core/run/node_resolver.gd` 的 `节点战斗类型` 同一批）。
const 战斗类型 := ["作战", "精英", "守军", "侵蚀源", "出口守军", "追击"]
## 两型出口（换层的落脚点）。
const 出口类型 := ["出口尽头", "出口小径"]

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	# 第一遍：真跑 + 全部断言（D-06 / D-07 就地验）；第二遍：同种子重跑，只对关键数字
	var 甲 := _跑一局(t, true)
	var 乙 := _跑一局(t, false)
	var 差 := []
	for k in 甲.keys():
		if str(甲[k]) != str(乙.get(k, null)):
			差.append("%s %s → %s" % [str(k), str(甲[k]), str(乙.get(k, null))])
	t.ok(甲["状态"] == 乙["状态"] and 差.is_empty(),
		"★ 确定性：同种子（%d）两遍跑出来的关键数字**逐项相同**（状态 %s / 层 %d / 步 %d / 走 %d / 场次 %d / 胜场 %d / 源碳 %d / 希望 %d / 经验 %d / 节点 %d）%s"
		% [种子, str(甲["状态"]), int(甲["层"]), int(甲["步"]), int(甲["走"]), int(甲["场次"]), int(甲["胜场"]),
			int(甲["源碳"]), int(甲["希望"]), int(甲["经验"]), int(甲["节点"]),
			"" if 差.is_empty() else "；差异：" + str(差)])
	t.ok(str(甲["轨迹"]) == str(乙["轨迹"]) and int(甲["步"]) == int(乙["步"]) and int(甲["最大连续不冒牌"]) == int(乙["最大连续不冒牌"]),
		"★ 确定性：两遍的**逐层轨迹**（各 %d 行）逐字相同，步数（%d）与「最长连续不冒牌」（%d）也相同"
		% [int(甲["轨迹行数"]), int(甲["步"]), int(甲["最大连续不冒牌"])])

# ==========================================================================================
# 主流程：一局跑到底
# ==========================================================================================
## 跑一局。`验` = 是否做断言 / 打轨迹（第二遍只取数字，不重复断言、不重复打日志）。
## 返回一份**用于对账的摘要**（同种子两遍要逐项相同）。
func _跑一局(t, 验: bool) -> Dictionary:
	var s := GameSession.new()
	s.存档路径 = "user://test_session_run.json"   # 只用内存态，全程不存档（不写任何文件）
	var 开局 := s.start_new_run(种子, 分队)
	if 验:
		t.ok(开局, "★ 端到端：种子 %d + 分队「%s」开局成功（屏幕 %s / 第 %d 层 / 起点格 %d）"
			% [种子, 分队, s.screen, s.run_state.floor_num, s.run_state.node_id])
	var st: RunState = s.run_state

	# ---- 断言 1 / D-06：开局的三件事 ----
	if 验:
		t.ok(st.roster.is_empty() and st.tickets.size() == 3,
			"★ 开局：名册 %d 台（**空**）、券 %d 张、希望 %d、源碳 %d、推进剂 %d/%d"
			% [st.roster.size(), st.tickets.size(), st.hope, st.carbon, st.propellant, st.propellant_max])
		t.ok(st.pending_card_picks.is_empty() and s.modal.is_empty(),
			"★ D-06：开局 `pending_card_picks` = %s、`modal` = %s（**都是空的** —— 门面不自己造三选一）"
			% [str(st.pending_card_picks), str(s.modal)])
		t.ok(st.status == "进行中" and st.battles_fought == 0 and st.battles_won == 0,
			"★ 开局：状态「%s」、场次 %d / 胜场 %d" % [st.status, st.battles_fought, st.battles_won])

	# ---- 第 1 层准备：招募 → 编队 → 隔离平衡 ----
	var 行 := _新行(st)
	_层准备(s, 行)
	行["名册"] = st.roster.size()
	行["出击"] = st.lineup.size()
	if 验:
		t.ok(int(行["招募"]) >= 1 and not st.roster.is_empty(),
			"★ 招募：第 1 层花掉券招到 %d 台（名册 %s；剩券 %d、剩希望 %d）"
			% [int(行["招募"]), str(st.roster.keys()), st.tickets.size(), st.hope])
		# ★ D-06 正向：**只有招募之后**才会出现待选战术牌
		t.ok(st.pending_card_picks.size() >= 1,
			"★ D-06 正向：招募之后 `pending_card_picks` **非空**（%d 张：%s）" % [st.pending_card_picks.size(), str(st.pending_card_picks)])
		t.ok(str(s.modal.get("类型", "")) == "三选一",
			"★ D-06 正向：招募之后 `modal` 才变成三选一（真实值「%s」，数据 %s）" % [str(s.modal.get("类型", "")), str(s.modal.get("数据", []))])

	# ---- 主循环 ----
	var 步 := 0
	var 走成功 := 0
	var 连续不冒牌 := 0
	var 最大连续不冒牌 := 0
	var 选牌 := 0
	var 结算成功 := 0
	var 结算失败 := []
	var 开战失败 := 0
	var 换层失败 := 0
	var 名册空跳过 := 0
	var 停滞 := 0
	var 已验幂等 := false
	var 已验纯读 := false
	var 已验事件负向 := false
	var 事件格数 := 0
	var 最高层 := st.floor_num
	var 结算过格 := {}
	var 层结算数 := 0
	var 轨迹: Array = []
	var 结束原因 := "跑满上限 %d 步" % 最大步数
	while 步 < 最大步数:
		步 += 1
		var 前层 := st.floor_num
		var 前节点 := st.node_id
		var 本轮有动作 := false

		# ---- (a) 有待选牌先选掉（每层最多张数由内核给；这里不做任何上限假设）----
		if not st.pending_card_picks.is_empty():
			var 牌 := str(st.pending_card_picks[0])
			if s.pick_tactical_card(牌):
				选牌 += 1
				本轮有动作 = true
				if 验 and not 已验纯读:
					已验纯读 = true
					_验纯读口子(t, s)
			else:
				结算失败.append("选牌被拒：%s" % str(s.last.get("为什么", "")))

		# ---- (b) 战斗打完了 → 当场结算（并记这一格已经结算过）----
		if s.screen == "battle" and not s.battle_ctx.is_empty():
			s.auto_finish_battle()
			var 结: Dictionary = s.finish_battle_and_settle()
			var 结成功 := not 结.has("ok") or bool(结.get("ok", false))
			if 结成功:
				结算成功 += 1
				层结算数 += 1
				本轮有动作 = true
				if 验 and not 已验幂等:
					已验幂等 = true
					_验结算幂等(t, s)
			else:
				结算失败.append(str(结.get("为什么", "")))
			结算过格[st.node_id] = true

		if st.floor_num == 前层:
			# ---- (c) 进脚下这一格（没结算过、且不是「空 / 起点 / 出口」）----
			var 类型 := _脚下类型(st)
			if not 结算过格.has(st.node_id) and 类型 != "空" and 类型 != "起点" and not 出口类型.has(类型):
				结算过格[st.node_id] = true
				本轮有动作 = true
				if 战斗类型.has(类型):
					if st.lineup.is_empty():
						名册空跳过 += 1
						if 验:
							t.info("脚下是 %s 但出击名单是空的 → 记已结算跳过（第 %d 层格 %d）" % [类型, st.floor_num, st.node_id])
					else:
						s.enter_current_node()
						if s.screen != "battle":
							开战失败 += 1
							if 验:
								t.info("开战失败（第 %d 层格 %d 类型 %s）：%s" % [st.floor_num, st.node_id, 类型, str(s.last.get("为什么", ""))])
				elif 类型 == "黑市":
					s.leave_shop()
				elif 类型 == "事件":
					var 待选前 := str(st.pending_card_picks)
					s.resolve_event_choice("")
					事件格数 += 1
					if 验 and not 已验事件负向:
						已验事件负向 = true
						t.ok(str(st.pending_card_picks) == 待选前,
							"★ D-06 负向：`resolve_event_choice(\"\")` 之后 `pending_card_picks` **不变**（%s；事件「%s」→ %s）"
							% [str(st.pending_card_picks), str(s.last.get("事件", "")), str(s.last.get("结果", ""))])
				else:
					s.enter_current_node()

		# ---- (d) 站在出口格上 → 换层 ----
		var 出口 := _最近出口(st)
		if st.floor_num == 前层 and s.screen != "battle" and 出口 >= 0 and st.node_id == 出口:
			var 换: Dictionary = s.try_advance_floor()
			if not bool(换.get("ok", false)):
				换层失败 += 1
				if 验:
					t.info("在出口格 %d（%s）换层被拒：%s" % [st.node_id, _脚下类型(st), str(换.get("为什么", ""))])

		# ---- (e) 只走**相邻**格（不跳格）；正在开战（screen == battle）时不许抢着走 ----
		if st.floor_num == 前层 and st.node_id == 前节点 and s.screen != "battle":
			var 下一 := _选下一格(s, 结算过格)
			if 下一 >= 0:
				var 移: Dictionary = s.move_to_cell(下一)
				if bool(移.get("ok", false)):
					走成功 += 1
					本轮有动作 = true
					if st.pending_card_picks.is_empty():
						连续不冒牌 += 1
						最大连续不冒牌 = maxi(最大连续不冒牌, 连续不冒牌)
					else:
						连续不冒牌 = 0
					if 验 and 走成功 == 5:
						t.ok(st.pending_card_picks.is_empty(),
							"★ D-06：连续 `move_to_cell` 走满 5 格之后 `pending_card_picks` **仍为空**（%s）—— 移动不自己造三选一"
							% str(st.pending_card_picks))

		# ---- 换层：收尾本层 → 新层准备 ----
		if st.floor_num != 前层:
			最高层 = maxi(最高层, st.floor_num)
			_收尾本层(行, st, 层结算数)
			轨迹.append(行)
			结算过格 = {}
			层结算数 = 0
			停滞 = 0
			行 = _新行(st)
			_层准备(s, 行)
			行["名册"] = st.roster.size()
			行["出击"] = st.lineup.size()
			if st.status != "进行中":
				结束原因 = "状态 = %s" % st.status
				break
			continue

		# ---- 停滞检测：这一轮什么都没干（推进剂见底 / 走不动了）----
		if 本轮有动作:
			停滞 = 0
		else:
			停滞 += 1
		if 停滞 >= 5:
			结束原因 = "连续 %d 步没有进展（推进剂 %d、脚下格 %d 类型 %s）" % [停滞, st.propellant, st.node_id, _脚下类型(st)]
			break
		if st.status != "进行中":
			结束原因 = "状态 = %s" % st.status
			break

	_收尾本层(行, st, 层结算数)
	轨迹.append(行)

	if 验:
		# ---- 那一趟的真实轨迹（本任务的核心证据，逐层打出来）----
		for r in 轨迹:
			t.info("★ 端到端轨迹：第 %d 层 · 招募 %d 台（补位 %d）· 名册 %d · 出击 %d 台 · 打 %d 场（胜 %d）· 结算 %d 格 · 已清节点 +%d · 推进剂 %d/%d → 剩 %d · 状态 %s"
				% [int(r["层"]), int(r["招募"]), int(r["补位"]), int(r["名册"]), int(r["出击"]), int(r["场次"]), int(r["胜场"]),
					int(r["结算"]), int(r["已清节点"]), int(r["开场推进剂"]), int(r["推进剂上限"]),
					int(r["层末推进剂"]), str(r["状态"])])
		t.info("★ 端到端汇总：%d 步 / 走 %d 格 / 选牌 %d 张 / 结算 %d 场（胜 %d）/ 换层到第 %d 层 / 事件格 %d / 名册空跳过 %d / 结束原因：%s"
			% [步, 走成功, 选牌, 结算成功, st.battles_won, st.floor_num, 事件格数, 名册空跳过, 结束原因])

		# ---- 断言 8：有界（D-07 类回归 —— 不许跑满上限还在原地打转）----
		t.ok(步 < 最大步数, "★ 有界：整个 while 循环 **%d 步**就退出了（上限 %d；结束原因：%s）—— 没有跑满上限还在原地打转"
			% [步, 最大步数, 结束原因])
		# ---- 断言 4：真的走了 ----
		t.ok(走成功 >= 10, "★ 真的走了：全程成功 `move_to_cell` **%d 次**（≥ 10）" % 走成功)
		# ---- 断言 3：走多格都不冒牌（D-06 回归）----
		t.ok(最大连续不冒牌 >= 5, "★ D-06：最长「连续走格而 `pending_card_picks` 保持为空」= **%d** 格（≥ 5）" % 最大连续不冒牌)
		# ---- 断言 5：真的打了，且每一场都结算成功 ----
		t.ok(st.battles_fought >= 3, "★ 真的打了：全程 **%d 场**（≥ 3），胜 %d 场，已清节点 %d" % [st.battles_fought, st.battles_won, st.nodes_cleared])
		t.ok(结算失败.is_empty() and 结算成功 == st.battles_fought,
			"★ 每一场都结算成功：结算成功 %d 次 == 场次 %d，失败 0 条%s"
			% [结算成功, st.battles_fought, "" if 结算失败.is_empty() else "；失败：%s" % str(结算失败)])
		t.ok(开战失败 == 0, "★ 战斗类节点一次都没开战失败（失败 %d 次）" % 开战失败)
		# ---- 断言 6：能换层 ----
		t.ok(最高层 >= 3 and 换层失败 == 0 and 轨迹.size() == 最高层,
			"★ 能换层：最高走到**第 %d 层**（轨迹 %d 行 = 层数），换层被拒 %d 次" % [最高层, 轨迹.size(), 换层失败])
		# ---- 断言 7 ★ 完整打通（M4 的出口条件）----
		t.ok(st.status == "胜利" and st.floor_num == 4,
			"★ 完整打通：最终 `status` = 「%s」、`floor_num` = **%d**（要的是「胜利」+ 第 4 层）"
			% [st.status, st.floor_num])

	# ---- 对账摘要：★ 必须在「跑完那一刻」抓 ----
	#   下面的 D-06 负向断言**会真的动状态**（`use_part` 把落脚点搬到目标格、事件会结算推进剂 / 希望）——
	#   那些是**跑完之后**的额外动作，不属于这一局的终点，不能混进「同种子两遍对账」里。
	var 摘要 := {
		"状态": st.status, "层": st.floor_num, "步": 步, "走": 走成功, "选牌": 选牌,
		"结算": 结算成功, "场次": st.battles_fought, "胜场": st.battles_won,
		"源碳": st.carbon, "希望": st.hope, "经验": st.exp_val, "等级": st.level,
		"已清节点": st.nodes_cleared, "藏品": st.relics.size(), "零件": st.parts.size(),
		"券": st.tickets.size(), "耐久": st.base_hp, "节点": st.node_id,
		"名册": str(st.roster.keys()), "牌库": str(st.tactical_deck),
		"轨迹": 轨迹.duplicate(true), "轨迹行数": 轨迹.size(),
		"最大连续不冒牌": 最大连续不冒牌, "事件格": 事件格数, "名册空跳过": 名册空跳过,
		"结束原因": 结束原因,
	}
	if 验:
		# ---- 断言 9：D-06 负向（用零件 / 事件之后不许冒牌）----
		_验用零件不冒牌(t, s, 已验事件负向)
	return 摘要

# ==========================================================================================
# 每层准备：① 花券招募 ② 编队摆满 ③ 隔离平衡（等级统一到 30）
# ==========================================================================================
func _层准备(s: GameSession, 行: Dictionary) -> void:
	var st: RunState = s.run_state
	# ① 招募：手上的券全花掉（同一张券招不到人就停，不硬凑）
	while not st.tickets.is_empty():
		var 可招: Array = s.available_recruit_targets(0)
		if 可招.is_empty():
			break
		var 条: Dictionary = 可招[0]
		var 键 := str(条.get("键", ""))
		if 键.is_empty():
			break
		var 招: Dictionary = s.recruit_unit(键, 0)
		if not bool(招.get("ok", false)):
			break
		行["招募"] = int(行["招募"]) + 1
	# ② 编队：名册里还没上阵的、且出击位没满 → 塞进第一个空位
	var 已上: Dictionary = {}
	for x in st.lineup:
		if x is Dictionary:
			已上[str(x.get("key", ""))] = true
	for k in st.roster.keys():
		if 已上.has(str(k)):
			continue
		if st.lineup.size() >= RosterManager.deploy_limit(st):
			break
		var 空位 := ""
		for 格 in s.lineup_slots():
			if str(格.get("键", "")).is_empty():
				空位 = str(格.get("位名", ""))
				break
		if 空位.is_empty():
			break
		if s.set_lineup_slot(str(k), 空位):
			已上[str(k)] = true
			行["补位"] = int(行["补位"]) + 1
	# ③ 隔离平衡（见文件头 `平衡等级` 的说明：测接线，不测平衡）
	for k in st.roster.keys():
		var m: Dictionary = st.roster[k]
		m["lv"] = 平衡等级
		st.roster[k] = m

# ==========================================================================================
# 选下一格：**只走相邻格**（`move_distances` 距离 == 1），优先未结算的战斗类邻格
# ==========================================================================================
## ① 先按「未结算的战斗类邻格」挑（否则只走最短路一场都打不到）；
## ② 再退化成「到出口 BFS 距离最小」；
## ③ ★ 额外加一条**可行性闸门**：走完这一步剩下的推进剂必须 ≥ 从那一格到出口的最短路。
##    为什么要有 ③：门面**没有**「推进剂见底 → 触发追击战」这条口子（封存 JS 有），
##    推进剂一旦在非战斗格上见底，`move_distances` 就空了 —— 走不动、也打不了，只能原地卡死。
##    这一闸门保证「永远还走得到出口」，同时把绕路额度自然限制在余量之内。
func _选下一格(s: GameSession, 结算过格: Dictionary) -> int:
	var st: RunState = s.run_state
	var cols := MapNavigator.columns(st)
	var 出口 := _最近出口(st)
	if 出口 < 0:
		return -1
	var 到出口 := MapGenerator.bfs_distances(出口, MapGenerator.int_key_set(st.grid()), cols)
	var 移动距离 := MapNavigator.move_distances(st)
	var 候选: Array = []
	for k in 移动距离.keys():
		if int(移动距离[k]) == 1:
			候选.append(int(k))
	if 候选.is_empty():
		return -1
	候选.sort()   # 固定次序 → 同种子走出同一条路
	var 战斗候选: Array = []
	var 普通候选: Array = []
	for k in 候选:
		var 距: Variant = 到出口.get(int(k))
		var 剩余 := st.propellant - 1
		# ③ 可行性闸门（走得到出口才走）
		if 距 != null and 剩余 < int(距):
			continue
		if 战斗类型.has(str(st.cell_at(int(k)).get("类型", ""))) and not 结算过格.has(int(k)):
			战斗候选.append(int(k))
		else:
			普通候选.append(int(k))
	if not 战斗候选.is_empty():
		return _最靠近出口(战斗候选, 到出口)
	if not 普通候选.is_empty():
		return _最靠近出口(普通候选, 到出口)
	# 兜底（理论到不了）：推进剂已经不够回到出口了，那就先挑离出口最近的邻格，别停着不动
	return _最靠近出口(候选, 到出口)

## 一组格号里「到出口 BFS 距离最小」的那个（同距离取小格号 → 确定性）。
func _最靠近出口(候选: Array, 到出口: Dictionary) -> int:
	var 最好 := int(候选[0])
	var 最好距 := 9999
	for k in 候选:
		var 距: Variant = 到出口.get(int(k))
		var d := int(距) if 距 != null else 9999
		if d < 最好距 or (d == 最好距 and int(k) < 最好):
			最好距 = d
			最好 = int(k)
	return 最好

# ==========================================================================================
# 出口：地图上两型出口里「离当前格最近」的那一个
# ==========================================================================================
func _最近出口(st: RunState) -> int:
	var cols := MapNavigator.columns(st)
	var 全图 := MapGenerator.int_key_set(st.grid())
	var 从脚下 := MapGenerator.bfs_distances(st.node_id, 全图, cols)
	var 最好 := -1
	var 最好距 := 9999
	for k in MapNavigator.cell_ids(st):
		if not 出口类型.has(str(st.cell_at(int(k)).get("类型", ""))):
			continue
		if int(k) == st.node_id:
			return int(k)
		var 距: Variant = 从脚下.get(int(k))
		var d := int(距) if 距 != null else 9999
		if d < 最好距 or (d == 最好距 and (最好 < 0 or int(k) < 最好)):
			最好距 = d
			最好 = int(k)
	return 最好

# ==========================================================================================
# 就地验两条 D-06 / D-07 回归（都在真跑的那一局里验，不另起夹具）
# ==========================================================================================
## ★ D-07：同一场结算完之后再连调 3 次 —— 必须**全部 ok=false**，且所有数字**逐项不变**。
func _验结算幂等(t, s: GameSession) -> void:
	var 前 := _结算数字(s)
	var 重复: Array = []
	for _i in 3:
		重复.append(s.finish_battle_and_settle())
	var 后 := _结算数字(s)
	var 都拒 := true
	for r in 重复:
		var r2: Dictionary = r
		if bool(r2.get("ok", true)):
			都拒 = false
	var 首: Dictionary = 重复[0]
	t.ok(都拒 and 重复.size() == 3,
		"★ D-07：同一场结算完之后再连调 3 次 `finish_battle_and_settle()` **全部 ok=false**（为什么=「%s」）—— 不是「原地反复结算同一场」在刷场次"
		% str(首.get("为什么", "")))
	var 差 := _两遍数字一样(前, 后)
	t.ok(差.is_empty(),
		"★ D-07：后 3 次调用**一个数字都不改**（源碳 %d / 希望 %d / 经验 %d / 场次 %d / 胜场 %d / 等级 %d）%s"
		% [int(后["源碳"]), int(后["希望"]), int(后["经验"]), int(后["场次"]), int(后["胜场"]), int(后["等级"]),
			"" if 差.is_empty() else "；差异：" + str(差)])

## ★ D-06：`refresh_card_offers()` 是**纯读口子** —— 连调两次候选逐项相同，且不动 `pending_card_picks` / `modal`。
func _验纯读口子(t, s: GameSession) -> void:
	var st: RunState = s.run_state
	var 键 := ""
	if not st.roster.is_empty():
		键 = str(st.roster.keys()[0])
	var 待前 := str(st.pending_card_picks)
	var 模前 := str(s.modal)
	var 甲: Array = s.refresh_card_offers(键)
	var 乙: Array = s.refresh_card_offers(键)
	t.ok(甲.size() >= 1 and str(甲) == str(乙),
		"★ 纯读口子：`refresh_card_offers(%s)` 连调两次候选**逐项相同**（%d 张：%s）" % [键, 甲.size(), str(甲)])
	t.ok(str(st.pending_card_picks) == 待前 and str(s.modal) == 模前 and st.pending_card_picks.is_empty(),
		"★ D-06：这个纯读口子**不写** `pending_card_picks`（%s → %s）、也不动 `modal`（%s → %s）"
		% [待前, str(st.pending_card_picks), 模前, str(s.modal)])

## ★ D-06 负向：`use_part()` 之后 `pending_card_picks` 不变（拿这一局真打出来的零件验；没有就明说不跑）。
func _验用零件不冒牌(t, s: GameSession, 已验事件: bool) -> void:
	var st: RunState = s.run_state
	var 下标 := -1
	var 目标 := -1
	for i in st.parts.size():
		var p: Variant = st.parts[i]
		var 键 := PartSystem.part_key(p)
		var 目标们: Array = PartSystem.part_targets(st, 键)
		if not 目标们.is_empty():
			下标 = i
			目标 = int(目标们[0])
			break
	if 下标 >= 0:
		var 待前 := str(st.pending_card_picks)
		var 用: Dictionary = s.use_part(下标, 目标)
		t.ok(str(st.pending_card_picks) == 待前 and st.pending_card_picks.is_empty(),
			"★ D-06 负向：`use_part(%d, %d)`（零件【%s】，ok=%s）之后 `pending_card_picks` **不变**（%s）"
			% [下标, 目标, str(用.get("零件", "")), str(用.get("ok", false)), str(st.pending_card_picks)])
	else:
		t.info("这一局没留下「目标格非空」的零件（手上 %d 件），跳过 `use_part` 那条负向断言（不硬凑）" % st.parts.size())
	# 事件那条：真跑到事件格就在那一刻验过了；没跑到就**照实说明**（不再另造夹具）
	if 已验事件:
		return
	if s.current_event_choices().is_empty():
		t.info("这一局没走到事件格、内核也没给出事件，跳过 `resolve_event_choice` 那条负向断言")
		return
	var 待前2 := str(st.pending_card_picks)
	s.resolve_event_choice("")
	t.ok(str(st.pending_card_picks) == 待前2,
		"★ D-06 负向（退路，本局没走到事件格）：在终点原地 `resolve_event_choice(\"\")`（事件「%s」）之后 `pending_card_picks` **不变**（%s）"
		% [str(s.last.get("事件", "")), str(st.pending_card_picks)])

# ==========================================================================================
# 小工具
# ==========================================================================================
func _新行(st: RunState) -> Dictionary:
	return {"层": st.floor_num, "招募": 0, "补位": 0, "名册": st.roster.size(), "出击": st.lineup.size(),
		"开场推进剂": st.propellant, "推进剂上限": st.propellant_max,
		"场次起": st.battles_fought, "胜场起": st.battles_won, "已清节点起": st.nodes_cleared,
		"场次": 0, "胜场": 0, "结算": 0, "已清节点": 0, "层末推进剂": st.propellant, "状态": st.status}

func _收尾本层(行: Dictionary, st: RunState, 层结算数: int) -> void:
	行["场次"] = st.battles_fought - int(行["场次起"])
	行["胜场"] = st.battles_won - int(行["胜场起"])
	行["结算"] = 层结算数
	行["已清节点"] = st.nodes_cleared - int(行["已清节点起"])
	行["层末推进剂"] = st.propellant
	行["状态"] = st.status

## 脚下这一格的类型（空字符串一律当「空」，与门面 `_脚下类型()` 同一口径）。
func _脚下类型(st: RunState) -> String:
	var 类 := str(st.cell_at(st.node_id).get("类型", ""))
	return 类 if not 类.is_empty() else "空"

## 结算前后要逐项对的那一组数字（纯读，快照用）。
func _结算数字(s: GameSession) -> Dictionary:
	var st: RunState = s.run_state
	return {"源碳": st.carbon, "希望": st.hope, "经验": st.exp_val, "等级": st.level,
		"场次": st.battles_fought, "胜场": st.battles_won, "已清节点": st.nodes_cleared,
		"藏品": st.relics.size(), "零件": st.parts.size(), "券": st.tickets.size(),
		"耐久": st.base_hp, "推进剂": st.propellant, "战术牌库": st.tactical_deck.size()}

func _两遍数字一样(a: Dictionary, b: Dictionary) -> Array:
	var 差 := []
	for k in a.keys():
		if str(a[k]) != str(b.get(k, null)):
			差.append("%s %s → %s" % [str(k), str(a[k]), str(b.get(k, null))])
	return 差
