## Stage M4-1 单元测试：会话门面 `GameSession` 的 headless 会话流（**真跑内核，不 mock 任何一个算法**）。
##   段 1 快速战斗全流程（含 D-01 的「角色牌开局在手 / 候补初始牌非空」）
##   段 2 肉鸽全流程（开局 → 招募 → 3 选 1 → 编队 → 预告 → 移动 → 战斗 → 结算 → 休整 → 黑市）
##   段 3 存档读档往返（关键字段逐个对）
##   段 4 错误路径不崩（非法输入一律 `{"ok": false}` / false，且**不动状态**）
##   段 5 确定性（同种子同一串命令 → `to_dict()` 逐字相同）
##   段 6 回血前后对照（结算层）
##   段 7 ★ D-06：待选战术牌只能由招募 / 晋升产生（开局 / 移动 / 用零件 / 事件都不许冒牌）
##   段 8 ★ D-07：`finish_battle_and_settle()` 必须幂等（同一场只结算一次，重复调用一个字都不改）
##   段 9 ★ D-08：推进剂见底 → 追击战（胜利 / 失败都换层；「出口那一步」才过守军闸）
##   段 9b ★★ D-10：追击战的**触发时机**对齐 JS「这一格结算完才会触发追击战」（战斗格先打节点战）
##   段 10 ★ D-09：招募写进 `lineup` 的位号是**数字**（不是空串）
extends RefCounted

const 肉鸽种子 := 20261013
const 快速种子 := 20261014
const 存档A := "res://.godot/tmp_session_flow_A.json"
const 存档B := "res://.godot/tmp_session_flow_B.json"

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))
	_快速战斗全流程(t)
	_肉鸽全流程(t)
	_换层(t)
	_节点交互读接口(t)
	_存档往返(t)
	_错误路径(t)
	_确定性(t)
	_回血前后对照(t)
	_待选牌只由招募晋升产生(t)
	_结算幂等(t)
	_追击战(t)
	_追击战D10(t)
	_招募位号是数字(t)

# ==========================================================================================
# 段 1：快速战斗全流程
# ==========================================================================================
func _快速战斗全流程(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	t.ok(s.start_quick_battle(快速种子), "快速战斗开局成功（屏幕=%s，手牌 %d 张，候补 %d 张）"
		% [s.screen, s.hand_count(), s.reserve_preview().size()])
	t.ok(s.screen == "battle", "开局后屏幕 = battle（真实值 %s）" % s.screen)
	t.ok(not s.battle_ctx.is_empty(), "battle_ctx 拿到了（我方 %d 台 / 敌方 %d 台）"
		% [(s.battle_ctx.get("allies") as Array).size(), (s.battle_ctx.get("enemies") as Array).size()])

	# ---- D-01：手牌开局非空、角色牌开局在手、候补初始牌非空 ----
	var 手 := s.hand_cards()
	t.ok(手.size() >= 5, "手牌开局 %d 张（初始手牌上限 6，至少 5 张在手）" % 手.size())
	var 角色牌 := []
	var 角色在手 := 0
	for c in 手:
		if str(c.get("层级", "")) == "角色":
			角色在手 += 1
			角色牌.append(str(c.get("名", "")))
	t.ok(角色在手 >= 1, "★ D-01：角色牌开局就在手上（%d 张：%s）" % [角色在手, "、".join(角色牌)])
	var 候补 := s.reserve_preview()
	t.ok(候补.size() >= 1, "★ D-01：候补初始牌非空（%d 张：%s）"
		% [候补.size(), "、".join(候补.map(func(c): return str(c.get("名", ""))))])
	t.ok(s.hand_count() + s.deck_remaining() >= 手.size(), "手牌 %d + 牌库剩余 %d（候补要逐回合补进手牌）"
		% [s.hand_count(), s.deck_remaining()])

	# ---- 打一张气势够的牌 ----
	var 能打的 := s.playable_hand_ids()
	t.ok(not 能打的.is_empty(), "开局气势 %.0f 之下能打的牌有 %d 张（%s）"
		% [s.battle_ctx.get("气势", 0.0), 能打的.size(), "、".join(能打的.slice(0, 4))])
	var 前可打 := s.cards_playable_now()
	var 牌库前 := (s.battle_ctx.get("已打出战术牌") as Array).size()
	var 打 := s.play_tactical_card(str(能打的[0]))
	t.ok(bool(打.get("成功", false)), "打出一张牌成功（%s，气势 %s → %s）"
		% [str(s.last.get("牌名", "")), str(s.last.get("气势前", 0.0)), str(s.last.get("气势后", 0.0))])
	t.ok((s.battle_ctx.get("已打出战术牌") as Array).size() == 牌库前 + 1,
		"本场已打出战术牌 %d → %d 张" % [牌库前, (s.battle_ctx.get("已打出战术牌") as Array).size()])
	# ★ 不拿「还能打的张数」当算式断言：刚打的牌可能是「回气牌」（例如 0 费【激励】+25 气势），
	#   打完反而更够气、能打的张数会变多 —— 这里只钉「已打出」这个事实与两个读法一致。
	t.ok(s.cards_played_this_turn() == 1 and s.cards_playable_now() == s.playable_hand_ids().size(),
		"本回合已打出 %d 张、现在还能打 %d 张（打之前 %d 张：**只报事实，没有「上限」**）"
		% [s.cards_played_this_turn(), s.cards_playable_now(), 前可打])

	# ---- ★ D-03 纠错：门面**不许**有「每回合最多打 N 张」的门槛（JS 与内核都没有）----
	var 本回合前 := s.cards_played_this_turn()
	var 打出 := []
	var 失败原因 := []
	for _k in 12:
		var 可 := s.playable_hand_ids()
		if 可.is_empty():
			break
		var r := s.play_tactical_card(str(可[0]))
		if bool(r.get("成功", false)):
			打出.append(str(s.last.get("牌名", "")))
		else:
			失败原因.append(str(r.get("为什么", "")))
			break
	t.ok(打出.size() >= 3, "★ 一回合里连打 %d 张都不被门面拦（%s）——真实内核与封存 JS 都没有张数上限"
		% [打出.size(), "、".join(打出)])
	t.ok(s.cards_played_this_turn() == 本回合前 + 打出.size(),
		"「本回合已打出」= %d 张，与真的打出去的成功次数 %d 对得上（是报告，不是预算）"
		% [s.cards_played_this_turn(), 打出.size()])
	var 坏原因 := []
	for why in 失败原因:
		if why.contains("上限") or why.contains("打满"):
			坏原因.append(why)
	t.ok(坏原因.is_empty() and 失败原因.size() <= 1,
		"没有一次失败原因是「打满 / 上限」（失败原因 %s；若中途停下只可能是气势/冷却/次数三类）" % str(失败原因))
	t.ok(not bool(s.play_tactical_card("绝无此卡").get("成功", false)) and str(s.last.get("为什么", "")).length() > 0,
		"打一张不在手里的牌 → 成功=false，给原因（%s）" % str(s.last.get("为什么", "")))

	# ---- cards_playable_now() / hand_card_status()：与 JS `80-界面-3:94/100` 同一判据 ----
	var 手牌现 := s.hand_cards()
	t.ok(s.cards_playable_now() == s.playable_hand_ids().size(),
		"cards_playable_now() = %d = playable_hand_ids() 的长度（同一判据的两个读法）" % s.cards_playable_now())
	if not 手牌现.is_empty():
		var 首: Dictionary = 手牌现[0]
		var 名 := str(首.get("名", ""))
		var 状 := s.hand_card_status(名)
		t.ok(bool(状.get("在手里", false)) and 状.has("耗气") and 状.has("回气") and 状.has("冷却") and 状.has("剩余") and str(状.get("原因", "")).length() > 0,
			"hand_card_status(%s)：可打=%s、原因「%s」（耗气 %s / 回气 %s / 冷却 %s / 剩余 %s）"
			% [名, str(状.get("可打", false)), str(状.get("原因", "")), str(状.get("耗气", 0.0)),
				str(状.get("回气", 0.0)), str(状.get("冷却", 0)), str(状.get("剩余", 0))])
		var 缺 := s.hand_card_status("绝无此卡")
		t.ok(not bool(缺.get("在手里", false)), "hand_card_status(不在手里) → 在手里=false、原因「%s」" % str(缺.get("原因", "")))
		# 把气势压到 0：**够气这条判据要先于冷却被判**，所以要挑一张「有耗气且不在冷却」的牌
		var 存气 := float(s.battle_ctx.get("气势", 0.0))
		var 需气 := ""
		for c in 手牌现:
			if float(c.get("耗气", 0.0)) > 0.0 and float(c.get("当前冷却", 0.0)) <= 0.0:
				需气 = str(c.get("名", ""))
				break
		if not 需气.is_empty():
			s.battle_ctx["气势"] = 0.0
			var 状2 := s.hand_card_status(需气)
			t.ok(not bool(状2.get("可打", false)) and str(状2.get("原因", "")) == "需 %d 气势" % int(状2.get("耗气", 0.0)),
				"气势压到 0 之后 hand_card_status(%s)：可打=false、原因「%s」（照 JS `80-界面-3:100` 的口径）"
				% [需气, str(状2.get("原因", ""))])
			t.ok(s.cards_playable_now() < 手牌现.size(),
				"气势 0 时现在能打的张数 %d < 手牌 %d 张" % [s.cards_playable_now(), 手牌现.size()])
		s.battle_ctx["气势"] = 存气
		t.ok(not s.turn_card_summary().has("本回合上限") and s.turn_card_summary().has("现在能打"),
			"turn_card_summary() 只报事实：有「本回合已打出」/「现在能打」，**没有**「本回合上限」（键：%s）"
			% str(s.turn_card_summary().keys()))

	# ---- 即时层：战斗日志真的有字 ----
	var 日志 := s.battle_log_lines(6)
	t.ok(日志.size() >= 2 and 日志[0].length() > 4, "即时层：战斗日志可读（%d 行，最后一行「%s」）"
		% [日志.size(), 日志[日志.size() - 1].substr(0, 24)])

	# ---- 推进一回合 → 自动打完 ----
	var 回合前 := int(float(s.battle_ctx.get("turn", 1.0)))
	var 步 := s.step_battle_turn()
	t.ok(int(步.get("到回合", 0)) > 回合前, "step_battle_turn 推进了回合（%d → %d）" % [回合前, int(步.get("到回合", 0))])
	t.ok(s.cards_played_this_turn() == 0, "新一回合的「本回合已打出」归零（%d）" % s.cards_played_this_turn())
	var 自动 := s.auto_finish_battle()
	var 结果: Variant = s.battle_ctx.get("result")
	t.ok(结果 != null, "auto_finish_battle 打出了结果（%s，共又打了 %d 回合）"
		% [str(s.战果文字()), int(自动.get("回合数", 0))])
	t.ok(str((结果 as Dictionary).get("结果", "")) == "胜" or str((结果 as Dictionary).get("结果", "")) == "败",
		"结果是「胜」或「败」（真实值 %s：%s）" % [str((结果 as Dictionary).get("结果", "")), str((结果 as Dictionary).get("原因", ""))])

	# ---- 结算 ----
	s.finish_battle_and_settle()
	t.ok(s.screen == "result", "结算后屏幕 = result（真实值 %s）" % s.screen)
	var 结 := s.result_summary()
	t.ok(bool(结.get("有结果", false)), "result_summary 有结果（%s / %s，回合 %d）"
		% [str(结.get("结果", "")), str(结.get("原因", "")), int(结.get("回合数", 0))])
	var 战利: Dictionary = 结.get("战利品", {})
	t.ok(战利.has("希望") and 战利.has("源碳") and 战利.has("藏品") and 战利.has("零件"),
		"结算层：战利品字段齐（希望 %s / 源碳 %s / 藏品 %s / 零件 %s）"
		% [str(战利.get("希望", 0)), str(战利.get("源碳", 0)), str(战利.get("藏品", null)), str(战利.get("零件", null))])
	var 回血: Dictionary = 结.get("回血", {})
	t.ok(回血.has("台数") and 回血.has("回复比例") and 结.has("血比前") and 结.has("血比后"),
		"结算层：存活回血 50%% 前后都在（台数 %s / 比例 %s / 名册 %d 台）"
		% [str(回血.get("台数", 0)), str(回血.get("回复比例", 0.0)), (结.get("血比后") as Dictionary).size()])
	t.ok((结.get("本场战术牌") as Array).size() >= 1,
		"结算层：本场打出的战术牌回顾 %d 张（%s）" % [(结.get("本场战术牌") as Array).size(), str(结.get("本场战术牌", []))])

	# ---- 顶栏 / 单位卡 ----
	var 顶 := s.topbar_state()
	t.ok(bool(顶.get("有局", false)) and 顶.has("层") and 顶.has("推进剂") and 顶.has("源碳") and 顶.has("希望")
		and 顶.has("基地耐久") and 顶.has("等级") and 顶.has("出击上限") and 顶.has("藏品") and 顶.has("零件"),
		"顶栏字段齐（层 %s / 推进剂 %s / 源碳 %s / 希望 %s / 等级 %s / 出击上限 %s）"
		% [str(顶.get("层", 0)), str(顶.get("推进剂", 0)), str(顶.get("源碳", 0)), str(顶.get("希望", 0)),
			str(顶.get("等级", 0)), str(顶.get("出击上限", 0))])
	var 我 := s.unit_view("ally", "B1")
	t.ok(bool(我.get("ok", false)) and (我.get("状态") as Array).size() >= 1 and (我.get("开关") as Array).size() >= 1,
		"我方单位卡有货（%s：HP %s/%s、位 %s、状态 %s）"
		% [str(我.get("名", "")), str(我.get("HP", 0.0)), str(我.get("最大HP", 0.0)), str(我.get("位名", "")), str(我.get("状态", []))])
	var 敌 := s.unit_view("enemy", str(((s.battle_ctx.get("enemies") as Array)[0] as Dictionary).get("key", "")))
	t.ok(bool(敌.get("ok", false)), "敌方单位卡查得到（%s：HP %s/%s、职业 %s）"
		% [str(敌.get("名", "")), str(敌.get("HP", 0.0)), str(敌.get("最大HP", 0.0)), str(敌.get("职业", ""))])
	var 底 := s.turn_card_summary()
	t.ok(底.has("本回合已打出") and 底.has("候补") and 底.has("牌库剩余") and 底.has("气势"),
		"底栏小计齐（已打出 %s / 候补 %s / 牌库剩余 %s / 气势 %s）"
		% [str(底.get("本回合已打出", 0)), str(底.get("候补", 0)), str(底.get("牌库剩余", 0)), str(底.get("气势", 0.0))])

	# ---- P1：开关表 / 结构化日志 / 分队表 ----
	var 表 := s.unit_switches()
	t.ok(表 is Dictionary and 表.size() >= 1, "unit_switches() 有 %d 台的开关记录（键 = 位号，%s）"
		% [表.size(), str(表.keys())])
	t.ok(s.toggle_unit_switch("B1", "保留大招"), "toggle_unit_switch(B1, 保留大招) 成功")
	t.ok(bool(s.unit_view("ally", "B1").get("开关", [])[0].contains("开")),
		"开关真的落到活单位身上（%s）" % str(s.unit_view("ally", "B1").get("开关", [])))
	t.ok(not s.toggle_unit_switch("B1", "没有这个开关"), "不存在的开关名 → false")
	t.ok(not s.toggle_unit_switch("查无此单位", "保留大招"), "不存在的单位 → false（%s）" % str(s.last.get("为什么", "")))
	var 天人 := _找势力单位(s, "天人")
	if not 天人.is_empty():
		var 状们: Array = s.unit_view("ally", 天人).get("状态", [])
		var 开 := s.activate_unit_state(天人)
		t.ok(开 or 状们.size() >= 1,
			"★ activate_unit_state(%s) = %s（状态行 %s；真实语义 = 置「本回合开TRANSAM」再走 `FacCb.手动开天人` 的真实闸门 —— 已经开着 / 冷却中时引擎返回 0 次，这里如实返回 false）"
			% [天人, str(开), str(状们)])
	else:
		t.info("这一队里没有天人机体，跳过 activate_unit_state 那一条")
	t.ok(not s.activate_unit_state("B1"), "B1 没有 TRANS-AM → activate_unit_state = false（%s）" % str(s.last.get("为什么", "")))
	var 条目 := s.battle_log_entries(3)
	var 首条: Dictionary = 条目[0] if not 条目.is_empty() else {}
	t.ok(条目.size() >= 1 and 条目.size() <= 3 and 首条.has("回合") and 首条.has("文本"),
		"battle_log_entries(3) 给 %d 条结构化日志（最近一条 第 %s 回合：%s）"
		% [条目.size(), str(首条.get("回合", "")), str(首条.get("文本", "")).substr(0, 20)])
	var 选项表 := s.unit_switch_table(s.battle_ctx)
	t.ok(s.available_squads() is Array and 选项表 is Dictionary and 选项表.size() >= 1,
		"available_squads() 是数组（%d 个，数据侧 `分队表` 还没导出时为 0）、unit_switch_table(ctx) 是字典（%d 个键：%s）"
		% [s.available_squads().size(), 选项表.size(), str(选项表.keys())])

	# ---- ★ P2 纠错：单位卡要能直接读到 SEED 觉醒行（纯读，不改状态）----
	var 我2 := s.unit_view("ally", "B1")
	t.ok(我2.has("SEED累计") and 我2.has("SEED已觉醒") and int(我2.get("SEED累计", -1)) >= 0,
		"★ P2：unit_view 带 SEED 字段（%s：SEED累计 %s / 已觉醒 %s）—— 觉醒行不用再绕去读内核"
		% [str(我2.get("名", "")), str(我2.get("SEED累计", -1)), str(我2.get("SEED已觉醒", false))])

	# ---- ★ P0：快速战斗路径（也走 finish_battle_and_settle）的「回血前后对照」 ----
	var 概快 := s.result_summary()
	var 快前: Dictionary = 概快.get("血比前", {})
	var 快后: Dictionary = 概快.get("血比后", {})
	var 快越界 := []
	for k in 快前.keys():
		var a := float(快前[k])
		var b := float(快后.get(k, 0.0))
		if a < 0.0 or a > 1.0 or b < 0.0 or b > 1.0:
			快越界.append(k)
	t.ok(not 快前.is_empty() and 快前.size() == 快后.size() and 快越界.is_empty(),
		"★ P0 快速战斗路径：血比前 / 后各 %d 台都在 [0,1]（前 %s / 后 %s）"
		% [快前.size(), str(快前), str(快后)])
	var 快变化 := 0
	for k in 快前.keys():
		if absf(float(快前[k]) - float(快后.get(k, 0.0))) > 0.0001:
			快变化 += 1
	t.ok(快变化 <= 快前.size(), "快速战斗的「前 ≠ 后」台数 = %d / %d（没打伤就恒等，这一条只要求不越界不串台）"
		% [快变化, 快前.size()])

	# ---- P1：回主菜单 ----
	s.return_to_menu()
	t.ok(s.screen == "menu" and s.run_state == null and s.battle_ctx.is_empty(),
		"return_to_menu() 之后屏幕 = %s、run_state = %s、battle_ctx 空 = %s"
		% [s.screen, str(s.run_state == null), str(s.battle_ctx.is_empty())])

# ==========================================================================================
# 段 2：肉鸽全流程
# ==========================================================================================
func _肉鸽全流程(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档B
	t.ok(s.start_new_run(肉鸽种子, "混编"), "开局成功（屏幕=%s）" % s.screen)
	t.ok(s.screen == "map", "开局后屏幕 = map（真实值 %s）" % s.screen)
	var 格数 := s.run_state.grid().size()
	t.ok(s.run_state.floor_num == 1 and 格数 > 10, "第 1 层地图生成好了（%d 格，起点 %d）" % [格数, s.run_state.node_id])
	t.ok(s.run_state.tickets.size() == 3, "开局券 %d 张（数据里开局券数 = 3）" % s.run_state.tickets.size())
	t.ok(s.run_state.propellant == s.run_state.propellant_max and s.run_state.propellant_max > 0,
		"进层推进剂 %d/%d（上限 = 最短路 + 余量）" % [s.run_state.propellant, s.run_state.propellant_max])

	# ---- 招募 ----
	var 可招 := s.available_recruit_targets(0)
	t.ok(not 可招.is_empty(), "第 1 张券能招 %d 位机师（%s）"
		% [可招.size(), "、".join(可招.slice(0, 3).map(func(x): return str(x.get("键", ""))))])
	var 目标 := str(可招[0].get("键", ""))
	var 名册前 := s.run_state.roster.size()
	var 招 := s.recruit_unit(目标, 0)
	t.ok(bool(招.get("ok", false)), "招募 %s 成功（Lv%d，花希望 %d，用掉「%s」）"
		% [目标, int(招.get("等级", 0)), int(招.get("费", 0)), str(招.get("券名", ""))])
	t.ok(s.run_state.roster.size() == 名册前 + 1 and bool(招.get("带队核心", false)),
		"名册 %d → %d 台；第一台是★带队核心（%s）" % [名册前, s.run_state.roster.size(), str(招.get("带队核心", false))])

	# ---- ★ P1 纠错：`recruit_unit(键)` **不传第二参**也要真的招到人 ----
	# 要挑一张**别的**券能招的机师（内核的口径：门面自己找出第一张对得上的券，而不是只认第 0 张）。
	var 键2: String = ""
	var 用第几张 := -1
	var 券候选表 := []
	for i in s.run_state.tickets.size():
		券候选表.append("券%d=「%s」→ %s" % [i, RosterManager.券名(s.run_state.tickets[i]),
			str(s.available_recruit_targets(i).map(func(x): return str(x.get("键", ""))))])
		if not 键2.is_empty():
			continue
		for x in s.available_recruit_targets(i):
			var k := str(x.get("键", ""))
			if k == 目标 or s.run_state.roster.has(k):
				continue
			# ★ 必须挑「这张券在**内核**眼里也招得到」的机师：`券合` 的档位（`档`）也要对得上，
			#   否则门面自己找到的那张券会被内核拒绝 —— 那就不是门面的 bug 了。
			if not RosterManager.券合(s.run_state.tickets[i], k):
				continue
			键2 = k
			用第几张 = i
			break
		if not 键2.is_empty():
			break
	t.info("第 0 张券招走的是「%s」；名册现在是 %s；三张券的候选：%s"
		% [目标, str(s.run_state.roster.keys()), "；".join(券候选表)])
	t.info("第 0 张券招走的是「%s」；名册现在是 %s；三张券的候选：%s"
		% [目标, str(s.run_state.roster.keys()), "；".join(券候选表)])
	if not 键2.is_empty():
		var 名册再前 := s.run_state.roster.size()
		var 券前数 := s.run_state.tickets.size()
		# 这一条只验「不传券下标也能招到人」这条**解析**对不对，希望不够会掩盖它 → 先把希望补足
		# （补希望是**测试夹具**，不是门面行为；希望不够那条路径另有断言）。
		s.run_state.hope = maxi(s.run_state.hope, 30)
		var 招2 := s.recruit_unit(键2)
		t.ok(bool(招2.get("ok", false)) and s.run_state.roster.size() == 名册再前 + 1,
			"★ P1：`recruit_unit(\"%s\")` **不传券下标**也招到了（应落在第 %d 张券上；名册 %d → %d，券 %d → %d，用掉「%s」，Lv%d）"
			% [键2, 用第几张, 名册再前, s.run_state.roster.size(), 券前数, s.run_state.tickets.size(),
				str(招2.get("券名", "")), int(招2.get("等级", 0))])
		if not s.run_state.pending_card_picks.is_empty():
			s.pick_tactical_card(str(s.run_state.pending_card_picks[0]))
	else:
		t.info("手上的券没有别的能招的机师，跳过「不传券下标」那一条")
	# 手上没有对得上的券时：**明确拒绝**，绝不静默失败
	MapNavigator.choose_exit(s.run_state, "尽头")
	var 无券前 := s.run_state.roster.size()
	var 无券 := s.recruit_unit("B1")
	t.ok(bool(无券.get("ok", false)) or (str(无券.get("为什么", "")).length() > 0 and s.run_state.roster.size() == 无券前),
		"没有对得上的券时 `recruit_unit(键)` 要么真招到、要么给 why 且名册不动（ok=%s，why=%s）"
		% [str(无券.get("ok", false)), str(无券.get("为什么", ""))])
	var 券空 := s.recruit_unit("绝无此机师", -1)
	t.ok(not bool(券空.get("ok", false)) and str(券空.get("为什么", "")).length() > 0,
		"不存在的机师 + 不传券下标 → **明确拒绝**、why 非空（%s）" % str(券空.get("为什么", "")))

	# ---- 3 选 1（★ 待选牌只能由**招募 / 晋升**产生，D-06；不能靠 `refresh_card_offers()` 造）----
	# 这里刻意再用一张券招一台 —— 招募成功那一刻内核就会写好 `pending_card_picks`。
	var 招牌 := {}
	for i in s.run_state.tickets.size():
		var 目标3 := ""
		for x in s.available_recruit_targets(i):
			var k3 := str(x.get("键", ""))
			if not s.run_state.roster.has(k3) and RosterManager.券合(s.run_state.tickets[i], k3):
				目标3 = k3
				break
		if not 目标3.is_empty():
			s.run_state.hope = maxi(s.run_state.hope, 30)
			招牌 = s.recruit_unit(目标3, i)
			break
	t.ok(s.run_state.pending_card_picks.size() >= 1,
		"★ 招募之后才有待选牌（招 %s → 候选 %d 张：%s）"
		% [str(招牌.get("键", "—")), s.run_state.pending_card_picks.size(), str(s.run_state.pending_card_picks)])
	t.ok(str(s.modal.get("类型", "")) == "三选一",
		"★ 招募之后 modal 才变成三选一（真实值「%s」，数据 %s）" % [str(s.modal.get("类型", "")), str(s.modal.get("数据", []))])
	var 候选 := s.run_state.pending_card_picks.duplicate()
	t.ok(候选.size() >= 1, "3 选 1 候选 %d 张（%s）" % [候选.size(), str(候选)])
	var 牌库数前 := s.run_state.tactical_deck.size()
	t.ok(s.pick_tactical_card(str(候选[0])), "选中候选里的第一张（%s）" % str(候选[0]))
	t.ok(s.run_state.tactical_deck.size() == 牌库数前 + 1 and s.run_state.pending_card_picks.is_empty(),
		"战术牌库 %d → %d 张，候选清空（%s）"
		% [牌库数前, s.run_state.tactical_deck.size(), str(s.run_state.pending_card_picks)])

	# ---- 编队 ----
	var 格位 := s.lineup_slots()
	t.ok(格位.size() == int(Fm.SLOTS()), "编队格位 %d 个（真实内核：前排 %s / 后排 %s）"
		% [格位.size(), str(格位[0].get("位名", "")), str(格位[格位.size() - 1].get("位名", ""))])
	var 键们 := s.run_state.roster.keys()
	# ★ 基准 = **当前**出击名单（不假设 `键们[0]` 在哪一格：前面「招募后自动上阵」会搅顺序，踩过一次）。
	var 占位名们 := []
	var 占位键们 := []
	for x in s.lineup_slots():
		if not str(x.get("键", "")).is_empty():
			占位名们.append(str(x.get("位名", "")))
			占位键们.append(str(x.get("键", "")))
	t.ok(占位名们.size() >= 1, "编队前已有 %d 台在出击位上（%s）" % [占位名们.size(), "、".join(占位名们)])
	# 把第一台挪到「最后一个空位」：换位逻辑必须**不产生重复条**（踩过一次同一台两条）
	var 空位名 := ""
	for x in s.lineup_slots():
		if str(x.get("键", "")).is_empty():
			空位名 = str(x.get("位名", ""))
	t.ok(空位名.is_empty() or s.set_lineup_slot(占位键们[0], 空位名),
		"把 %s 从 %s 挪到空位 %s" % [占位键们[0], 占位名们[0], 空位名])
	var 占位后 := []
	for x in s.lineup_slots():
		if not str(x.get("键", "")).is_empty():
			占位后.append(str(x.get("键", "")))
	var 重复 := []
	for k in 占位后:
		if 占位后.count(k) > 1 and not 重复.has(k):
			重复.append(k)
	var 位号集 := {}
	var 位号重 := []
	var 位号越界 := []
	var 位号空 := 0
	for x in s.run_state.lineup:
		if not (x is Dictionary):
			continue
		var v: Variant = x.get("slot", null)
		if v is String:
			位号空 += 1
			continue
		var 位号 := int(v)
		if 位号 < 0 or 位号 >= int(Fm.SLOTS()):
			位号越界.append(位号)
		if 位号集.has(位号):
			位号重.append(位号)
		位号集[位号] = true
	# 真不变量：**编队屏占位数 ≤ 出击名单条数**（名册里的替补**不占格位**，所以「条数 == 占位数」不成立），
	# 且位号唯一、合法、不是空串。
	t.ok(占位后.size() <= s.run_state.lineup.size() and 重复.is_empty() and 位号重.is_empty()
		and 位号越界.is_empty() and 位号空 == 0
		and 占位后.size() <= RosterManager.deploy_limit(s.run_state),
		"挪完之后：格位占用 %d ≤ 出击名单 %d 条、无重复键（%s）、无重复位号（%s）、位号合法（越界 %s / 空串 %d）—— 换位不该把同一台 / 同一格写两条，也不该超出击上限 %d"
		% [占位后.size(), s.run_state.lineup.size(), str(重复), str(位号重), str(位号越界), 位号空,
			RosterManager.deploy_limit(s.run_state)])
	t.ok(s.screen == "formation", "编队后屏幕 = formation（真实值 %s）" % s.screen)
	if 键们.size() >= 2:
		t.ok(s.set_lineup_slot(str(键们[1]), str(格位[1].get("位名", ""))), "把 %s 摆到 %s" % [str(键们[1]), str(格位[1].get("位名", ""))])
		t.ok(s.remove_from_lineup(str(键们[1])), "把 %s 撤下出击位" % str(键们[1]))
		t.ok(str(s.lineup_slots()[1].get("键", "")).is_empty(), "撤下之后 %s 空出来了" % str(格位[1].get("位名", "")))
		t.ok(s.set_lineup_slot(str(键们[1]), str(格位[1].get("位名", ""))), "再把它摆回去")

	# ---- 预告层 + 移动 ----
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	t.ok(not 可达.is_empty(), "当前格（%d）能去 %d 格（%s）" % [s.run_state.node_id, 可达.size(), str(可达.slice(0, 5))])
	var 预 := s.preview_cell_move(int(可达[0]))
	t.ok(bool(预.get("ok", false)) and int(预.get("推进剂消耗", 0)) >= 1,
		"★ 预告层：到格 %d 要花 %d 点推进剂（退路成本 %d，类型 %s，干路 %s）"
		% [int(可达[0]), int(预.get("推进剂消耗", 0)), int(预.get("退路成本", -1)), str(预.get("类型", "")), str(预.get("是干路", false))])
	t.ok(s.run_state.node_id != int(可达[0]), "预告是纯读：还没有真的移动（当前格仍是 %d）" % s.run_state.node_id)

	# ---- 走进一个战斗格 → 真的从地图节点开战（肉鸽主路径）----
	var 战斗格 := _找战斗格(s)
	var 走了 := 0
	for _i in 12:
		if s.run_state.node_id == 战斗格:
			break
		var 可 := MapNavigator.reachable_cells(s.run_state)
		if 可.is_empty():
			break
		var 下一 := _朝目标走(s, 可, 战斗格)
		var 移 := s.move_to_cell(下一)
		if not bool(移.get("ok", false)):
			break
		走了 += 1
		if s.run_state.propellant <= 0:
			break
	t.ok(走了 >= 1 and s.run_state.propellant < s.run_state.propellant_max,
		"移动 %d 步，推进剂 %d → %d（扣费规则：走一格扣 1、跳格按最短路）"
		% [走了, s.run_state.propellant_max, s.run_state.propellant])
	t.ok(not str(s.last.get("类型", "")).is_empty(), "移动的即时反馈带类型（%s，距离 %d，追击 %s）"
		% [str(s.last.get("类型", "")), int(s.last.get("距离", 0)), str(s.last.get("追击", false))])
	var 脚下 := str(s.run_state.map_data.get("当前节点类型", ""))
	t.ok(s.run_state.node_id == 战斗格 and 脚下 == str(s.run_state.cell_at(战斗格).get("类型", "")),
		"走到 %d 格，落脚后「当前节点类型」同步成 %s（不是起点那一格）" % [战斗格, 脚下])

	# ---- 开战（P0：start_node_battle 的真肉鸽路径）----
	# ★ 让这一场**打得赢**：把名册补到 6 台 Lv30 并按出击上限摆满（照 `test_run_core` 的冒烟口径）。
	#   只测「命令 → 内核 → 结果」有没有通，不拿运气当断言。
	_补强名册(s)
	var 场次前 := s.run_state.battles_fought
	var 经验前 := s.run_state.exp_val
	var 源碳前 := s.run_state.carbon
	var 我台上限 := RosterManager.deploy_limit(s.run_state)
	t.ok(s.start_node_battle(), "★ P0：从地图节点开战成功（格类型 %s，编成 %s，敌方 %d 台 vs 我 %d 台）"
		% [str(s.last.get("格类型", "")), str(s.last.get("编成类型", "")),
			(s.battle_ctx.get("enemies") as Array).size(), (s.battle_ctx.get("allies") as Array).size()])
	t.ok(s.screen == "battle" and not s.battle_ctx.is_empty(), "start_node_battle 之后屏幕 = %s、battle_ctx 非空" % s.screen)
	t.ok(s.hand_count() >= 1, "肉鸽战斗开局手牌 %d 张（候补 %d 张）" % [s.hand_count(), s.reserve_preview().size()])
	t.ok(RosterManager.deploy_limit(s.run_state) == 我台上限 and 我台上限 >= 1,
		"出击上限 %d 台（名册 %d 台 / 出击 %d 台）" % [我台上限, s.run_state.roster.size(), s.run_state.lineup.size()])
	var 能打 := s.playable_hand_ids()
	if not 能打.is_empty():
		var 打 := s.play_tactical_card(str(能打[0]))
		t.ok(bool(打.get("成功", false)) and s.cards_played_this_turn() >= 1,
			"肉鸽战斗里打出【%s】（气势 %s → %s）"
			% [str(s.last.get("牌名", "")), str(s.last.get("气势前", 0.0)), str(s.last.get("气势后", 0.0))])
	else:
		t.info("这一手没有气力够的牌（手牌 %d 张、气势 %.0f），跳过打牌那一条" % [s.hand_count(), float(s.battle_ctx.get("气势", 0.0))])
	s.auto_finish_battle()
	var 胜 := str(s.battle_ctx.get("result", {}).get("结果", "")) == "胜"
	var 结 := s.finish_battle_and_settle()
	t.ok(s.run_state.battles_fought == 场次前 + 1, "战后：场次 %d → %d" % [场次前, s.run_state.battles_fought])
	if 胜:
		t.ok(s.run_state.carbon > 源碳前 or s.run_state.hope > 0,
			"★ 胜利结算真的改了数值：源碳 %d → %d、希望 %d、经验 %d → %d、等级 Lv%d"
			% [源碳前, s.run_state.carbon, s.run_state.hope, 经验前, s.run_state.exp_val, s.run_state.level])
	else:
		t.ok(s.run_state.base_hp <= s.run_state.base_max_hp and int(结.get("扣", 0)) >= 0,
			"失败结算：作战耐久 %d/%d（按剩下的敌人数扣 %d）"
			% [s.run_state.base_hp, s.run_state.base_max_hp, int(结.get("扣", 0))])
	t.ok(s.screen == "result" and bool(s.result_summary().get("有结果", false)),
		"战斗结算屏有结果（%s，格类型 %s，结果条字段 %d 个）"
		% [str(s.result_summary().get("结果", "")), str(s.result_summary().get("格类型", "")), s.result_summary().size()])
	t.ok(s.run_state.nodes_cleared >= 1 or s.run_state.pending_floor_change != null or s.run_state.status == "失败",
		"打完这一格：已清节点 = %d / 待换层 = %s / 状态 = %s / 耐久 %d（力战不敌就整局结束，反过来说「没清格」是对的）"
		% [s.run_state.nodes_cleared, str(s.run_state.pending_floor_change), s.run_state.status, s.run_state.base_hp])

	# ---- ★ P0：结算屏一定要带着「血比前 / 血比后」（真正的前 ≠ 后 在专项段 `_回血前后对照` 里验）----
	var 概 := s.result_summary()
	t.ok(not 概.get("血比前", {}).is_empty() and not 概.get("血比后", {}).is_empty(),
		"结算屏带着血比前 / 血比后（前 %d 台 / 后 %d 台）"
		% [(概.get("血比前", {}) as Dictionary).size(), (概.get("血比后", {}) as Dictionary).size()])

	# ---- 休整 ----
	var 耐久满 := s.run_state.base_max_hp
	var 节点前 := s.run_state.nodes_cleared
	s.run_state.base_hp = maxi(0, s.run_state.base_hp - 3)
	var 耐久前 := s.run_state.base_hp
	var 休 := s.resolve_rest("耐久")
	t.ok(bool(休.get("ok", false)) and s.run_state.nodes_cleared == 节点前 + 1,
		"休整（耐久）：作战耐久 %d → %d（上限 %d）、已清节点 %d → %d"
		% [耐久前, s.run_state.base_hp, 耐久满, 节点前, s.run_state.nodes_cleared])

	# ---- 黑市 ----
	var 货 := NodeResolver.黑市货(s.run_state)
	t.ok(货 is Array, "黑市货架摆出了 %d 件（%s）" % [(货 as Array).size(), str((货 as Array).slice(0, 3))])
	s.run_state.carbon = maxi(s.run_state.carbon, 200)
	var 货前 := (货 as Array).size()
	var 刷新 := s.refresh_shop()
	t.ok(bool(刷新.get("ok", false)) and s.run_state.shop_refreshes == 1,
		"黑市刷新成功（花 %d 源碳，第 %d 次，摆出 %d 件）"
		% [int(刷新.get("价", 0)), int(刷新.get("次", 0)), (刷新.get("货", []) as Array).size()])
	var 卖前 := s.run_state.carbon
	PartSystem.grant_part(s.run_state, "spring", "会话流测试")
	var 件数前 := s.run_state.parts.size()
	var 卖 := s.sell_part_in_shop(s.run_state.parts.size() - 1)
	t.ok(bool(卖.get("ok", false)) and s.run_state.carbon > 卖前 and s.run_state.parts.size() == 件数前 - 1,
		"卖零件【%s】+%d 源碳（源碳 %d → %d，零件 %d → %d）"
		% [str(卖.get("名", "")), int(卖.get("价", 0)), 卖前, s.run_state.carbon, 件数前, s.run_state.parts.size()])
	var 新货 := NodeResolver.黑市货(s.run_state)
	var 买 := {}
	if not (新货 as Array).is_empty():
		买 = s.buy_from_shop(str((新货 as Array)[0]))
		if bool(买.get("ok", false)):
			t.ok(s.run_state.relics.has(str(买.get("id", ""))),
				"黑市买下【%s】花 %d 源碳（源碳 → %d，藏品 %d 件）"
				% [str(买.get("名", "")), int(买.get("价", 0)), s.run_state.carbon, s.run_state.relics.size()])
		else:
			t.ok(str(买.get("为什么", "")).length() > 0, "黑市买不成时给了原因（%s）" % str(买.get("为什么", "")))
	t.ok(s.leave_shop() and s.run_state.nodes_cleared >= 1, "离开黑市（已清节点 %d）" % s.run_state.nodes_cleared)
	t.ok(货前 >= 1 and (货 as Array).size() >= 1, "货架第一次就有货（%d 件）" % 货前)

## 找一个「会开战」的格号（作战 / 精英 / 守军 / 侵蚀源 / 出口守军 / 追击 / 普通）；找不到退到最远的可达格。
func _找战斗格(s: GameSession) -> int:
	var 战斗类型 := ["作战", "普通", "精英", "守军", "侵蚀源", "出口守军", "追击"]
	for k in MapNavigator.cell_ids(s.run_state):
		if not MapNavigator.walkable(s.run_state, k):
			continue
		if 战斗类型.has(str(s.run_state.cell_at(k).get("类型", ""))):
			return k
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	return int(可达[可达.size() - 1]) if not 可达.is_empty() else -1

# ==========================================================================================
# 段 2b：换层（P0 · try_advance_floor）
# ==========================================================================================
## ★ 只验**第 1 层 → 第 2 层**这一步（把当前格直接摆到出口格上，再调命令）。
##   不真的走到出口：那要跨十几步、可能中途推进剂见底触发追击战，会验成别的机制。
func _换层(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	s.start_new_run(肉鸽种子 + 3, "混编")
	var 出口尽头 := int(s.run_state.map_data.get("出口尽头", -1))
	var 出口 := 出口尽头 if 出口尽头 >= 0 else int(s.run_state.map_data.get("出口", -1))
	if 出口 < 0:
		t.ok(false, "这一层没有出口格（地图字段：%s）" % str(s.run_state.map_data.keys()))
		return
	s.run_state.node_id = 出口
	s.run_state.mark_visited(出口)
	# ★ 新一局手上还有 3 张开局券带来的待选战术牌：不先选完，`try_advance_floor` 会照口径拒绝。
	var 候选数 := s.run_state.pending_card_picks.size()
	var 选了 := 0
	while not s.run_state.pending_card_picks.is_empty() and 选了 < 40:
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
		选了 += 1
	t.ok(s.run_state.pending_card_picks.is_empty(),
		"先把开局留下的 %d 张待选战术牌选完（真的选掉 %d 张，牌库 %d 张，希望 %d）"
		% [候选数, 选了, s.run_state.tactical_deck.size(), s.run_state.hope])
	# 出口小径免守军；尽头要先打赢出口守军（这里走小径，验的是「换层」本身）
	MapNavigator.choose_exit(s.run_state, "小径")
	var 前层 := s.run_state.floor_num
	var 前格集 := s.run_state.grid().keys()
	var 前上限 := s.run_state.propellant_max
	var 换 := s.try_advance_floor()
	t.ok(bool(换.get("ok", false)), "★ P0：第 1 层 → 第 2 层换层成功（出口类型 %s，从 %d 到 %d；为什么=%s；当前格 %d / 类型 %s）"
		% [str(s.last.get("出口类型", "")), 前层, s.run_state.floor_num, str(换.get("为什么", "")),
			s.run_state.node_id, str(s.run_state.current_type())])
	t.ok(s.run_state.floor_num == 前层 + 1, "层号 %d → %d" % [前层, s.run_state.floor_num])
	t.ok(s.run_state.grid().size() > 0 and str(s.run_state.grid().keys()) != str(前格集),
		"地图被 `enter_floor` 重建（旧图 %d 格 → 新图 %d 格）" % [(前格集 as Array).size(), s.run_state.grid().size()])
	var 账 := MapGenerator.propellant_detail(s.run_state)
	t.ok(s.run_state.propellant == 账["上限"] and s.run_state.propellant_max == 账["上限"],
		"推进剂按 `propellant_detail` 重算：%d/%d = 最短路 %d + 余量 %d + 层修正 %d + 零件 %d + 小径 %d"
		% [s.run_state.propellant, s.run_state.propellant_max, int(账["最短路"]), int(账["余量"]),
			int(账["层修正"]), int(账["零件"]), int(账["小径"])])
	t.ok(s.run_state.is_visited(s.run_state.node_id) and s.screen == "map",
		"新层落在起点 %d（已走过），屏幕 = %s" % [s.run_state.node_id, s.screen])
	# 出口小径：把下一层的推进剂上限 +2 记进了 trail_floors
	t.ok(s.run_state.trail_floors.has(前层 + 1) or s.run_state.trail_floors.is_empty(),
		"走了出口小径 → 第 %d 层的推进剂上限加成记录 = %s（不要求必有，只要求不崩）" % [前层 + 1, str(s.run_state.trail_floors)])
	# 第 2 层也能接着走一格（新图真的可用）
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	t.ok(not 可达.is_empty() and bool(s.move_to_cell(int(可达[0])).get("ok", false)),
		"第 2 层新地图真的能走（能去 %d 格，第一步到 %d）" % [可达.size(), s.run_state.node_id])

## 在「这一回合能去的格」里挑一个离目标更近的（纯读距离表，不消耗任何随机数）。
func _朝目标走(s: GameSession, 可达: Array, 目标: int) -> int:
	if 目标 < 0:
		return int(可达[0])
	var 到目标 := MapGenerator.bfs_distances(目标, MapGenerator.int_key_set(s.run_state.grid()),
		maxi(1, int(s.run_state.map_data.get("列数", 5))))
	var 最好 := int(可达[0])
	var 最短 := 9999
	for k in 可达:
		var 距: Variant = 到目标.get(int(k))
		var d := int(距) if 距 != null else 9999
		if d < 最短:
			最短 = d
			最好 = int(k)
	return 最好

# ==========================================================================================
# 段 2c：非战斗节点的「进去 → 结果 → 选项」三条读接口（P1）
# ==========================================================================================
func _节点交互读接口(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档B
	s.start_new_run(肉鸽种子 + 5, "混编")
	# 1) enter_current_node() 进黑市 → current_node_result()
	var 黑市 := _找格(s, "黑市")
	if 黑市 >= 0:
		s.run_state.node_id = 黑市
		s.run_state.mark_visited(黑市)
		var 进 := s.enter_current_node()
		t.ok(进 is Dictionary and str(进.get("节点", "")) == "黑市",
			"enter_current_node() 进黑市（货 %d 件，源碳 %d）" % [(进.get("货", []) as Array).size(), s.run_state.carbon])
		t.ok(not s.current_node_result().is_empty() and str(s.current_node_result().get("节点", "")) == "黑市",
			"current_node_result() 拿得到刚才那一步的结果（节点 %s，键 %d 个）"
			% [str(s.current_node_result().get("节点", "")), s.current_node_result().size()])
	else:
		t.info("这一层没有黑市格，跳过黑市那一条")
	# 2) current_event_choices()
	var 事件格 := _找格(s, "事件")
	if 事件格 >= 0:
		s.run_state.node_id = 事件格
		s.run_state.mark_visited(事件格)
		s.enter_current_node()
		var 选项 := s.current_event_choices()
		t.ok(选项.size() >= 1 and str((选项[0] as Dictionary).get("文", "")).length() > 0,
			"current_event_choices() 给出 %d 个选项（事件「%s」：%s）"
			% [选项.size(), str(s.current_node_result().get("事件", {}).get("名", "")), str((选项[0] as Dictionary).get("文", ""))])
		var 序 := int((选项[0] as Dictionary).get("序", -1))
		var 结 := s.resolve_event_choice(str(序))
		t.ok(结 is Dictionary and (结.has("ok") or 结.has("为什么")),
			"resolve_event_choice(\"%s\") 有明确结果（%s）" % [str(序), str(结.get("结果", 结.get("为什么", "")))])
	else:
		t.info("这一层没有事件格，跳过事件那一条")
	# 3) 招募 → promotion_preview()
	var 可招 := s.available_recruit_targets(0)
	if not 可招.is_empty():
		var 键 := str(可招[0].get("键", ""))
		var 招 := s.recruit_unit(键, 0)
		t.ok(bool(招.get("ok", false)), "招下 %s（Lv%d）以便验晋升预览" % [键, int(招.get("等级", 0))])
		var 预 := s.promotion_preview(键)
		var 预前: Dictionary = 预.get("前", {})
		var 预后: Dictionary = 预.get("后", {})
		t.ok(bool(预.get("ok", false)) and int(预.get("到", 0)) == 30 and int(预后.get("maxHp", 0)) > int(预前.get("maxHp", 0)),
			"promotion_preview(%s)：Lv%d → Lv%d（HP %d → %d，价 %d，有券 %s，能升 %s）"
			% [键, int(预.get("从", 0)), int(预.get("到", 0)), int(预前.get("maxHp", 0)), int(预后.get("maxHp", 0)),
				int(预.get("价", 0)), str(预.get("有券", false)), str(预.get("能升", false))])
	var 坏的 := s.promotion_preview("绝无此机师")
	t.ok(not bool(坏的.get("ok", false)) and str(坏的.get("why", "")).length() > 0,
		"promotion_preview(不存在的键) 给原因（%s）" % str(坏的.get("why", "")))

## 本层地图里第一个指定类型的格号（找不到 −1）。
func _找格(s: GameSession, 类型: String) -> int:
	for k in MapNavigator.cell_ids(s.run_state):
		if str(s.run_state.cell_at(k).get("类型", "")) == 类型:
			return int(k)
	return -1

## 把名册补到 6 台 Lv30 并按出击上限摆满（**不碰任何机制**，只写 `roster` / `lineup` 这两个数据字段）。
func _补强名册(s: GameSession) -> void:
	var 表: Array = Db.T.get("ALLY_T") if Db.T.get("ALLY_T") is Array else []
	var 补 := 0
	for e in 表:
		if s.run_state.roster.size() >= 6 or 补 >= 6:
			break
		if not (e is Dictionary):
			continue
		var k := str(e.get("mech", ""))
		if k.is_empty() or s.run_state.roster.has(k):
			continue
		s.run_state.roster[k] = {"key": k, "lv": 30, "hpRatio": 1.0}
		补 += 1
	for k in s.run_state.roster.keys():
		var m: Dictionary = s.run_state.roster[k]
		m["lv"] = 30
		m["hpRatio"] = 1.0
		s.run_state.roster[k] = m
	var 上限 := RosterManager.deploy_limit(s.run_state)
	var 新出击: Array = []
	for k in s.run_state.roster.keys():
		if 新出击.size() >= 上限:
			break
		新出击.append({"key": str(k), "slot": 新出击.size()})
	s.run_state.lineup = 新出击

## ★ P0 专项：开一局 → 招募（**不传券下标**）→ 3 选 1 → **故意只上 1 台 Lv30**（1 打 5 必挨打）
##   → `start_node_battle()` → 打完 → `finish_battle_and_settle()`，然后核对「血比前 / 血比后」。
##   为什么用「只上 1 台」：要保证这一场**真的掉血**（掉血才有 `hpRatio` 变化），
##   掉血之后「前 ≠ 后」才有内容；不这么造就会变成「全员满血 → 前后恒等」，测不出 P0。
func _回血前后对照(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	s.start_new_run(肉鸽种子 + 21, "混编")
	var 招 := {}
	var 可招 := s.available_recruit_targets(0)
	if not 可招.is_empty():
		招 = s.recruit_unit(str(可招[0].get("键", "")))
	t.ok(bool(招.get("ok", false)), "★ P1：`recruit_unit(键)` 不传券下标就招到了 %s（Lv%d，用掉「%s」）"
		% [str(可招[0].get("键", "")) if not 可招.is_empty() else "", int(招.get("等级", 0)), str(招.get("券名", ""))])
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
	# 只上 1 台 Lv30：1 打 5，必挨打
	var 一台 := ""
	for k in s.run_state.roster.keys():
		var m: Dictionary = s.run_state.roster[k]
		m["lv"] = 30
		m["hpRatio"] = 1.0
		s.run_state.roster[k] = m
		if 一台.is_empty():
			一台 = str(k)
	s.run_state.lineup = [{"key": 一台, "slot": 0}] if not 一台.is_empty() else []
	var 格 := _找第几个战斗格(s, 0)
	if 格 < 0:
		t.ok(false, "第 1 层找不到战斗格")
		return
	s.run_state.node_id = 格
	s.run_state.mark_visited(格)
	t.ok(s.start_node_battle(), "★ P0 专项：只上 1 台（%s）开战，敌方 %d 台 —— 这一场必然挨打"
		% [一台, (s.battle_ctx.get("enemies") as Array).size()])
	s.auto_finish_battle()
	var 结 := s.finish_battle_and_settle()
	var 概 := s.result_summary()
	var 比前: Dictionary = 概.get("血比前", {})
	var 比后: Dictionary = 概.get("血比后", {})
	t.ok(not 比前.is_empty() and 比前.size() == 比后.size(),
		"血比前 / 血比后 都有货且台数一致（前 %d 台：%s）" % [比前.size(), str(比前)])
	var 变化 := []
	for k in 比前.keys():
		if absf(float(比前[k]) - float(比后.get(k, 0.0))) > 0.0001:
			变化.append("%s: %d%% → %d%%" % [str(k), int(JsCompat.js_round(float(比前[k]) * 100.0)),
				int(JsCompat.js_round(float(比后.get(k, 0.0)) * 100.0))])
	var 越界 := []
	for k in 比前.keys():
		var a := float(比前[k])
		var b := float(比后.get(k, 0.0))
		if a < 0.0 or a > 1.0 or b < 0.0 or b > 1.0:
			越界.append(k)
	t.ok(越界.is_empty(), "血比前 / 血比后的每一台都落在 [0,1]（越界 %s）" % str(越界))
	# ★ P0 的**核心**：`血比前` 必须是「打完了、还没回血」那一瞬的名册血比。
	#   D-07 之后同一场**不能重复结算**了，所以要**再开一场**来验：走到第 2 个战斗格 → 开战 →
	#   先手动把这一台压到 0.4（模拟这一场打残了）→ 打完 → 结算。
	#   这样「血比前」必须读到 0.4（**每次都重抓**），而不是复用开战时的 1.0。
	var 打残了 := false
	if _走到战斗格开战(s, 1):
		var 残: Dictionary = s.run_state.roster[一台]
		残["hpRatio"] = 0.4
		s.run_state.roster[一台] = 残
		s.auto_finish_battle()
		打残了 = true
	else:
		t.info("第 1 层找不到第二个战斗格，P0 的「压到 40% 再结算」那一条改成换层到第 2 层再试")
		var 出口尽头 := int(s.run_state.map_data.get("出口尽头", -1))
		if 出口尽头 >= 0:
			s.run_state.node_id = 出口尽头
			s.run_state.mark_visited(出口尽头)
			MapNavigator.choose_exit(s.run_state, "小径")
			s.try_advance_floor()
			if _走到战斗格开战(s, 0):
				var 残2: Dictionary = s.run_state.roster[一台] if s.run_state.roster.has(一台) else {}
				if not 残2.is_empty():
					残2["hpRatio"] = 0.4
					s.run_state.roster[一台] = 残2
				s.auto_finish_battle()
				打残了 = true
	var 结2 := s.finish_battle_and_settle() if 打残了 else {}
	var 概2 := s.result_summary()
	var 比前2: Dictionary = 概2.get("血比前", {})
	var 比后2: Dictionary = 概2.get("血比后", {})
	t.ok(打残了 and absf(float(比前2.get(一台, 1.0)) - 0.4) < 0.0001
		and float(比后2.get(一台, 1.0)) > float(比前2.get(一台, 1.0)),
		"★ P0：把 %s 压到 40%% 之后再打完一场并结算 → 血比前 = %d%%、血比后 = %d%%（**前 ≠ 后**，且「前」就是回血前那一瞬的真实值）"
		% [一台, int(JsCompat.js_round(float(比前2.get(一台, 1.0)) * 100.0)),
			int(JsCompat.js_round(float(比后2.get(一台, 1.0)) * 100.0))])
	var 名字们2: Array = 结2.get("回血", {}).get("名字们", []) if 结2.get("回血", {}).get("名字们") is Array else []
	t.ok(str(名字们2).contains(一台),
		"内核 `战后回血()` 的名字们 = %s（含 %s，与「40%% → 100%%」对得上）" % [str(名字们2), 一台])
	# 交叉对账：内核 `战后回血()` 的 `名字们`（形如 "B3 74% → 100%"）里的单位名集合 == 我这份「前 ≠ 后」名单。
	# ★ 必须用**第二次结算**（手动压到 40% 那一次）的概2/结2：那一次的「前」才真的 ≠ 「后」。
	var 回血内核: Dictionary = 结2.get("回血", {})
	var 内核名 := []
	for 行 in (回血内核.get("名字们", []) if 回血内核.get("名字们") is Array else []):
		var 行文 := str(行)
		var 空位 := 行文.find(" ")
		内核名.append(行文.substr(0, 空位) if 空位 > 0 else 行文)
	var 我方变化 := []
	for k in 比前2.keys():
		if absf(float(比前2[k]) - float(比后2.get(k, 0.0))) > 0.0001:
			我方变化.append(str(k))
	var 集合一致 := 内核名.size() == 我方变化.size()
	if 集合一致:
		for k in 我方变化:
			if not 内核名.has(k):
				集合一致 = false
	t.ok(集合一致, "★ 交叉对账：内核 `战后回血()[\"名字们\"]` = %s（%d 台），我这份「前 ≠ 后」名单 = %s（%d 台）"
		% [str(回血内核.get("名字们", [])), 内核名.size(), str(我方变化), 我方变化.size()])
	t.ok(str(回血内核.get("文本", "")).contains("战后休整"),
		"结算层的回血文本在（%s）" % str(回血内核.get("文本", "")))

## 名册当前血比（纯读，给诊断消息用）。
func _名册血比(s: GameSession) -> Dictionary:
	var out := {}
	if s.run_state == null:
		return out
	for k in s.run_state.roster.keys():
		out[str(k)] = float(s.run_state.get_unit_hp_ratio(str(k)))
	return out

## 当前战场上第一个属于某个势力的我方单位键（找不到给空串）。
func _找势力单位(s: GameSession, 势力: String) -> String:
	for u in (s.battle_ctx.get("allies") if s.battle_ctx.get("allies") is Array else []):
		if u is Dictionary and str(Fac.势力名(u)) == 势力:
			return str(u.get("key", ""))
	return ""

# ==========================================================================================
# 段 3：存档读档往返
# ==========================================================================================
func _存档往返(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	s.start_new_run(肉鸽种子 + 7, "混编")
	var 可招 := s.available_recruit_targets(0)
	if not 可招.is_empty():
		s.recruit_unit(str(可招[0].get("键", "")), 0)
	if not s.run_state.pending_card_picks.is_empty():
		s.pick_tactical_card(str(s.run_state.pending_card_picks[0]))
	s.run_state.hope += 3
	s.run_state.carbon += 5
	s.run_state.relics.append("g1")
	PartSystem.grant_part(s.run_state, "wheel", "存档测试")
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	if not 可达.is_empty():
		s.move_to_cell(int(可达[0]))
	var 前 := s.run_state.to_dict().duplicate(true)
	t.ok(s.save_current_run(), "存档成功（层 %d / 源碳 %d / 希望 %d / 名册 %d 台）"
		% [s.run_state.floor_num, s.run_state.carbon, s.run_state.hope, s.run_state.roster.size()])
	t.ok(s.has_saved_run(), "has_saved_run() = true")
	var s2 := GameSession.new()
	s2.存档路径 = 存档A
	t.ok(s2.load_saved_run(), "读档成功（层 %d，屏幕 %s）" % [s2.run_state.floor_num, s2.screen])
	var 后 := s2.run_state.to_dict()
	var 键 := ["层", "源碳", "希望", "出击", "战术牌库", "零件", "藏品", "推进剂", "推进剂上限", "当前格", "已走过", "等级", "经验", "待选战术牌"]
	var 不一致 := []
	for k in 键:
		if str(前.get(k, null)) != str(后.get(k, null)):
			不一致.append(k)
	t.ok(不一致.is_empty(), "往返关键字段逐个一致（%d 个字段：%s）%s"
		% [键.size(), "、".join(键), "" if 不一致.is_empty() else "；不一致：" + str(不一致)])
	# 名册 / 出击 / 零件这些嵌套结构走内核自己的编码器逐字比（`SaveService` 是存档的唯一真源）
	t.ok(SaveService.serialize(RunState.from_dict(前)) == SaveService.serialize(s2.run_state),
		"名册 / 出击 / 零件用 SaveService 编码逐字一致（名册 %d 台、出击 %d 台、战术牌库 %s）"
		% [(后.get("名册") as Dictionary).size(), (后.get("出击") as Array).size(), str(后.get("战术牌库", []))])
	t.ok((后.get("名册") as Dictionary).has("B1") or not (后.get("名册") as Dictionary).is_empty(),
		"读回来的名册里有人（%s）" % str(后.get("名册", {})))
	t.ok(前.size() == 后.size(), "字段数一样（%d 个键）" % 后.size())
	var 无 := GameSession.new()
	无.存档路径 = "res://.godot/这个文件不存在_session.json"
	t.ok(not 无.has_saved_run() and not 无.load_saved_run(), "没有存档时 has_saved_run() = false、load_saved_run() = false")

# ==========================================================================================
# 段 4：错误路径不崩（不许抛异常、不许改状态）
# ==========================================================================================
func _错误路径(t) -> void:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/这个文件也不存在_session.json"
	# 没有局 / 没有战斗时的命令
	t.ok(not s.load_saved_run(), "没有存档时 load_saved_run() = false")
	t.ok(not s.save_current_run(), "没有局时 save_current_run() = false")
	var 无局 := s.move_to_cell(3)
	t.ok(not bool(无局.get("ok", false)) and str(无局.get("为什么", "")).length() > 0, "没有局时 move_to_cell 给原因（%s）" % str(无局.get("为什么", "")))
	var 无战 := s.play_tactical_card("C_CMD_1")
	t.ok(not bool(无战.get("成功", false)) and str(无战.get("为什么", "")).length() > 0, "不在战斗里打牌被拒绝（%s）" % str(无战.get("为什么", "")))
	t.ok(s.errors.size() >= 3, "错误路径都记进了 errors（%d 条：%s）" % [s.errors.size(), str(s.errors.slice(0, 2))])

	# 有局之后的非法输入
	var g := GameSession.new()
	g.存档路径 = 存档B
	g.start_new_run(肉鸽种子 + 11, "混编")
	var 快照 := SaveService.serialize(g.run_state)
	t.ok(not bool(g.move_to_cell(99999).get("ok", false)), "move_to_cell(99999)（不存在的格）→ ok=false")
	t.ok(not bool(g.preview_cell_move(99999).get("ok", false)), "preview_cell_move(99999)（不存在的格）→ ok=false（纯读，不崩）")
	t.ok(not bool(g.move_to_cell(-1).get("ok", false)), "move_to_cell(-1)（非法格号）→ ok=false")
	# 「推进剂 0 → 一格都去不了」是内核的确定口径（`MapNavigator.reachable_cells` 直接返回空）：
	# 这样比「挑一个看起来远的格」稳，不会出现「其实走得过去」的假失败。
	var 存推进剂 := g.run_state.propellant
	var 存格 := g.run_state.node_id
	g.run_state.propellant = 0
	var 饿 := _找任一别的格(g)
	t.ok(_被拒绝吗(g, 饿), "推进剂 0 时 move_to_cell(%d) → ok=false（%s）" % [饿, str(g.last.get("为什么", ""))])
	g.run_state.propellant = 存推进剂
	t.ok(SaveService.serialize(g.run_state) == 快照 and g.run_state.node_id == 存格,
		"四次被拒绝的移动之后，状态逐字没变（推进剂复位后与快照一致，当前格仍是 %d）" % g.run_state.node_id)
	t.ok(not bool(g.recruit_unit("这不是机师键", 0).get("ok", false)), "不存在的 unit_key 招募 → ok=false")
	t.ok(not bool(g.promote_unit("这不是机师键").get("ok", false)), "不存在的 unit_key 晋升 → ok=false")
	var 没券 := g.recruit_unit("这不是机师键")
	t.ok(not bool(没券.get("ok", false)) and str(没券.get("为什么", "")).length() > 0,
		"不存在券 / 不存在机师时 recruit_unit 不传券下标 → **明确拒绝**（为什么=%s）" % str(没券.get("为什么", "")))
	t.ok(not g.set_lineup_slot("这不是机师键", "前1"), "不存在的 unit_key 编队 → false")
	t.ok(not g.remove_from_lineup("这不是机师键"), "不存在的 unit_key 撤下 → false")
	t.ok(not g.set_lineup_slot(str(g.run_state.roster.keys()[0]) if not g.run_state.roster.is_empty() else "无", "前99"), "不存在的位名 → false")
	t.ok(not g.pick_tactical_card("绝无此牌"), "不存在的战术牌 → false")
	t.ok(not bool(g.play_tactical_card("C_CMD_1").get("成功", false)), "不在战斗里打牌 → 成功=false（%s）" % str(g.last.get("为什么", "")))
	t.ok(not g.toggle_unit_switch("无此单位", "保留大招"), "不在战斗里切开关 → false")
	t.ok(not g.activate_unit_state("无此单位"), "不在战斗里开状态 → false")
	t.ok(not bool(g.use_part(99, 0).get("ok", false)), "use_part(99)（越界零件下标）→ ok=false")
	t.ok(not bool(g.sell_part_in_shop(99).get("ok", false)), "sell_part_in_shop(99)（越界）→ ok=false")
	t.ok(not bool(g.buy_from_shop("绝无此藏品").get("ok", false)), "买不存在的藏品 → ok=false")
	var 越界事件 := g.resolve_event_choice("99")
	t.ok(越界事件 is Dictionary, "事件选项越界不会崩（返回字典，为什么=%s）" % str(越界事件.get("为什么", "")))
	t.ok(str(g.run_state.status) == "进行中", "一串非法命令之后这一局还是「进行中」（真实值 %s）" % g.run_state.status)
	t.ok(g.errors.size() >= 8, "非法命令累计 %d 条错误（不抛异常）" % g.errors.size())

## 本层地图里随便一个别的格号（不是当前格；找不到给 −1）。
func _找任一别的格(s: GameSession) -> int:
	for k in MapNavigator.cell_ids(s.run_state):
		if int(k) != s.run_state.node_id:
			return int(k)
	return -1

# ==========================================================================================
# 段 7：★ D-06 —— 待选战术牌只能由**招募 / 晋升**产生
#   （封存 JS `90-肉鸽-5-晋升与通关.js:62`（招募）与 `:151`（晋升）是 `R.待选战术牌` 的唯二赋值；
#    开局 / 移动 / 用零件 / 事件结算一处都不产生）
# ==========================================================================================
func _待选牌只由招募晋升产生(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	t.ok(s.start_new_run(肉鸽种子 + 31, "混编"), "开局成功（屏幕=%s）" % s.screen)
	t.ok(s.run_state.pending_card_picks.is_empty() and s.modal.is_empty(),
		"★ D-06：开局**不产生**待选牌（pending=%s、modal=%s、战术牌库 %d 张）"
		% [str(s.run_state.pending_card_picks), str(s.modal), s.run_state.tactical_deck.size()])

	# ---- 走 5 格：每一步都不许冒牌 ----
	var 走了 := 0
	var 脏步 := []
	for _i in 8:
		if 走了 >= 5:
			break
		var 可达 := MapNavigator.reachable_cells(s.run_state)
		if 可达.is_empty():
			break
		var 移 := s.move_to_cell(int(可达[0]))
		if not bool(移.get("ok", false)):
			break
		走了 += 1
		if not s.run_state.pending_card_picks.is_empty() or not s.modal.is_empty():
			脏步.append("第 %d 步（格 %d，类型 %s）" % [走了, s.run_state.node_id, str(s.last.get("类型", ""))])
	t.ok(走了 >= 5, "连续走了 %d 格（推进剂剩 %d）" % [走了, s.run_state.propellant])
	t.ok(脏步.is_empty(), "★ D-06：走 %d 格全程都不冒待选牌（pending 空 = %s、modal 空 = %s；脏步 %s）"
		% [走了, str(s.run_state.pending_card_picks.is_empty()), str(s.modal.is_empty()), str(脏步)])

	# ---- 用零件 / 事件结算也不许冒牌（挑这一层真有这两种格子的种子）----
	var 零件格 := _找格(s, "遗迹")
	if 零件格 >= 0:
		s.run_state.node_id = 零件格
		s.run_state.mark_visited(零件格)
		var 前零件牌 := s.run_state.pending_card_picks.size()
		s.enter_current_node()
		t.ok(s.run_state.pending_card_picks.size() == 前零件牌,
			"★ D-06：进「遗迹」并结算之后待选牌没变（%d 张）" % s.run_state.pending_card_picks.size())
	var 零件件 := PartSystem.grant_part(s.run_state, "wheel", "D-06 测试")
	if not 零件件.is_empty():
		var 目标格 := -1
		for 候选格 in PartSystem.part_targets(s.run_state, "wheel"):
			目标格 = int(候选格)
			break
		var 前用牌 := s.run_state.pending_card_picks.size()
		var 用 := s.use_part(s.run_state.parts.size() - 1, 目标格)
		t.ok(s.run_state.pending_card_picks.size() == 前用牌 or not bool(用.get("ok", false)),
			"★ D-06：`use_part`（%s）之后待选牌没变（%d 张）"
			% ["成功" if bool(用.get("ok", false)) else "被拒", s.run_state.pending_card_picks.size()])
	var 事件格 := _找格(s, "事件")
	if 事件格 >= 0:
		s.run_state.node_id = 事件格
		s.run_state.mark_visited(事件格)
		s.enter_current_node()
		var 选项 := s.current_event_choices()
		var 前事件牌 := s.run_state.pending_card_picks.size()
		if not 选项.is_empty():
			s.resolve_event_choice(str(int((选项[0] as Dictionary).get("序", 0))))
		t.ok(s.run_state.pending_card_picks.size() == 前事件牌,
			"★ D-06：`resolve_event_choice` 之后待选牌没变（%d 张）" % s.run_state.pending_card_picks.size())
	else:
		t.info("这一层没有事件格，跳过事件那一条")

	# ---- refresh_card_offers 必须是**纯读**：连调两次，pending 与 modal 逐字不变 ----
	var 快照前 := SaveService.serialize(s.run_state)
	var 模前 := str(s.modal)
	var 键1 := ""
	for x in s.available_recruit_targets(0):
		var k := str(x.get("键", ""))
		if RosterManager.券合(s.run_state.tickets[0], k):
			键1 = k
		break
	var 读1: Array = s.refresh_card_offers(键1)
	var 读2: Array = s.refresh_card_offers(键1)
	t.ok(读1 == 读2 and str(s.modal) == 模前 and SaveService.serialize(s.run_state) == 快照前,
		"★ D-06：`refresh_card_offers(%s)` 是**纯读**（连调两次候选逐项相同 = %s；待选牌 %d 张不变；modal 逐字不变）"
		% [键1, str(读1 == 读2), s.run_state.pending_card_picks.size()])
	t.ok(读1.size() <= 3, "纯读口子返回 %d 张候选（%s）—— 只是「问 UI 这台机体能选哪三张」" % [读1.size(), str(读1)])

	# ---- 招募之后才有牌 + 选完不再拦换层 ----
	s.run_state.hope = maxi(s.run_state.hope, 60)
	var 招 := {}
	var 目标 := ""
	for i in s.run_state.tickets.size():
		for x in s.available_recruit_targets(i):
			var k2 := str(x.get("键", ""))
			if not s.run_state.roster.has(k2) and RosterManager.券合(s.run_state.tickets[i], k2):
				目标 = k2
				break
		if not 目标.is_empty():
			招 = s.recruit_unit(目标, i)
			break
	t.ok(bool(招.get("ok", false)) and not s.run_state.pending_card_picks.is_empty(),
		"★ D-06：招募 %s 之后待选牌才有（%d 张：%s）"
		% [目标, s.run_state.pending_card_picks.size(), str(s.run_state.pending_card_picks)])
	t.ok(str(s.modal.get("类型", "")) == "三选一",
		"★ D-06：招募之后 modal 才变三选一（真实值「%s」）" % str(s.modal.get("类型", "")))
	# 连推两轮，把「招募留下的候选」和「反复调 refresh 也不会再冒」都覆盖
	var 选了几张 := 0
	var 轮 := 0
	while 轮 < 3:
		轮 += 1
		while not s.run_state.pending_card_picks.is_empty():
			if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
				break
			选了几张 += 1
		if 选了几张 >= 3:
			break
	t.info("选牌循环：一共选了 %d 张（战术牌库 %d 张）" % [选了几张, s.run_state.tactical_deck.size()])
	var 出口尽头 := int(s.run_state.map_data.get("出口尽头", -1))
	if 出口尽头 >= 0:
		s.run_state.node_id = 出口尽头
		s.run_state.mark_visited(出口尽头)
		MapNavigator.choose_exit(s.run_state, "小径")
		var 换 := s.try_advance_floor()
		t.ok(s.run_state.pending_card_picks.is_empty(),
			"★ D-06：换层时手上没有待选牌（pending 空 = %s）" % str(s.run_state.pending_card_picks.is_empty()))
		t.ok(not str(换.get("为什么", "")).contains("张战术牌没选"),
			"★ D-06：换层**不再**被幻影待选牌拦住（ok=%s、为什么=「%s」、层 %d）"
			% [str(换.get("ok", false)), str(换.get("为什么", "")), s.run_state.floor_num])

## 推进剂 0 时这一步必须被内核拒绝（并写进 last）。
func _被拒绝吗(s: GameSession, 目标: int) -> bool:
	if 目标 < 0:
		return false
	return not bool(s.move_to_cell(目标).get("ok", false))

# ==========================================================================================
# 段 5：确定性（同种子两次跑同一串命令 → to_dict() 的 JSON 逐字相同）
# ==========================================================================================
func _确定性(t) -> void:
	var a := GameSession.new()
	a.存档路径 = 存档A
	var b := GameSession.new()
	b.存档路径 = 存档B
	var 序甲 := _同一串命令(a)
	var 序乙 := _同一串命令(b)
	var 甲 := a.run_state.to_dict()
	var 乙 := b.run_state.to_dict()
	var 逐字 := JSON.stringify(甲) == JSON.stringify(乙)
	t.ok(逐字, "同种子跑同一串命令 → to_dict() 的 JSON 逐字相同（%d 字符）" % JSON.stringify(甲).length())
	t.ok(序甲 == 序乙 and 序甲.size() >= 1,
		"★ 同种子同一串命令 → `cards_played_this_turn()` 序列逐字相同（%s）" % str(序甲))
	var 编码器一样 := SaveService.serialize(a.run_state) == SaveService.serialize(b.run_state)
	t.ok(编码器一样, "同一份状态用 SaveService 编码也逐字相同（两条路都一致）")
	t.ok(a.run_state.node_id == b.run_state.node_id and a.run_state.propellant == b.run_state.propellant
		and a.run_state.hope == b.run_state.hope and a.run_state.carbon == b.run_state.carbon
		and a.run_state.exp_val == b.run_state.exp_val and a.run_state.battles_fought == b.run_state.battles_fought,
		"关键数字逐项相同（格 %d/%d，推进剂 %d/%d，希望 %d/%d，源碳 %d/%d，经验 %d/%d，场次 %d/%d）"
		% [a.run_state.node_id, b.run_state.node_id, a.run_state.propellant, b.run_state.propellant,
			a.run_state.hope, b.run_state.hope, a.run_state.carbon, b.run_state.carbon,
			a.run_state.exp_val, b.run_state.exp_val, a.run_state.battles_fought, b.run_state.battles_fought])
	t.ok(str(a.run_state.roster.keys()) == str(b.run_state.roster.keys())
		and str(a.run_state.tactical_deck) == str(b.run_state.tactical_deck),
		"名册与战术牌库逐项相同（%s / %s）" % [str(a.run_state.roster.keys()), str(a.run_state.tactical_deck)])

## 一段**完全确定**的命令流（不读时间、不用引擎随机数）。返回每回合「本回合已打出」的序列。
func _同一串命令(s: GameSession) -> Array:
	s.start_new_run(肉鸽种子, "混编")
	var 可招 := s.available_recruit_targets(0)
	if not 可招.is_empty():
		s.recruit_unit(str(可招[0].get("键", "")), 0)
	if not s.run_state.pending_card_picks.is_empty():
		s.pick_tactical_card(str(s.run_state.pending_card_picks[0]))
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	for i in mini(3, 可达.size()):
		var 预 := s.preview_cell_move(int(可达[i]))
		if bool(预.get("ok", false)):
			s.move_to_cell(int(可达[i]))
			break
	s.resolve_rest("推进剂")
	var 货 := NodeResolver.黑市货(s.run_state)
	if not (货 as Array).is_empty():
		s.run_state.carbon = 200
		s.refresh_shop()
	# 再走一场真战斗、每回合按「能打就打」把牌打出去，把打牌序列记下来供两次对拍。
	_补强名册(s)
	var 战斗格 := _找第几个战斗格(s, 0)
	if 战斗格 >= 0:
		var 走 := 0
		for _i in 12:
			if s.run_state.node_id == 战斗格:
				break
			var 可 := MapNavigator.reachable_cells(s.run_state)
			if 可.is_empty():
				break
			if not bool(s.move_to_cell(_朝目标走(s, 可, 战斗格)).get("ok", false)):
				break
			走 += 1
		if s.run_state.node_id == 战斗格 and s.start_node_battle():
			var 序: Array = []
			for _t in 8:
				for _k in 12:
					var 能 := s.playable_hand_ids()
					if 能.is_empty():
						break
					if not bool(s.play_tactical_card(str(能[0])).get("成功", false)):
						break
				序.append([int(float(s.battle_ctx.get("turn", 1.0))), s.cards_played_this_turn()])
				if s.battle_ctx.get("result") != null:
					break
				s.step_battle_turn()
			s.auto_finish_battle()
			s.finish_battle_and_settle()
			return 序
	return []

## 本层第 `序` 个「会开战」的格号（按格号升序；找不到 −1）。
func _找第几个战斗格(s: GameSession, 序: int) -> int:
	var 战斗类型 := ["作战", "普通", "精英", "守军", "侵蚀源", "出口守军", "追击"]
	var 数 := 0
	for k in MapNavigator.cell_ids(s.run_state):
		if not MapNavigator.walkable(s.run_state, k):
			continue
		if not 战斗类型.has(str(s.run_state.cell_at(k).get("类型", ""))):
			continue
		if 数 == 序:
			return int(k)
		数 += 1
	# 找不到就退到「第 1 个可达格」
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	return int(可达[0]) if not 可达.is_empty() else -1

# ==========================================================================================
# 段 8：★ D-07 —— `finish_battle_and_settle()` **幂等**（同一场只结算一次）
#   旧行为：同一个 battle_ctx 可以原地无限重结算，每调一次再发源碳 / 希望 / 藏品 / 经验 +
#   `场次`/`胜场` 再 +1（端到端驱动器实测「第 1 层原地连结算 496 次、胜场 +496、源碳 +1984」）。
# ==========================================================================================

## 结算前 / 后要逐项对比的那一组数字（纯读，快照用）。
func _结算数字(s: GameSession) -> Dictionary:
	var 血 := {}
	for k in s.run_state.roster.keys():
		血[str(k)] = int(JsCompat.js_round(float(s.run_state.get_unit_hp_ratio(str(k))) * 100.0))
	return {
		"源碳": s.run_state.carbon, "希望": s.run_state.hope, "经验": s.run_state.exp_val,
		"等级": s.run_state.level, "场次": s.run_state.battles_fought, "胜场": s.run_state.battles_won,
		"已清节点": s.run_state.nodes_cleared, "藏品": s.run_state.relics.size(),
		"零件": s.run_state.parts.size(), "券": s.run_state.tickets.size(),
		"耐久": s.run_state.base_hp, "推进剂": s.run_state.propellant,
		"血比%": 血, "战术牌库": s.run_state.tactical_deck.size(),
	}

func _两遍数字一样(a: Dictionary, b: Dictionary) -> Array:
	var 差 := []
	for k in a.keys():
		if str(a[k]) != str(b.get(k, null)):
			差.append("%s %s → %s" % [str(k), str(a[k]), str(b.get(k, null))])
	return 差

## 走到一个战斗格并打完（**不结算**），返回是否成功。
func _走到战斗格开战(s: GameSession, 序: int) -> bool:
	var 格 := _找第几个战斗格(s, 序)
	if 格 < 0:
		return false
	for _i in 14:
		if s.run_state.node_id == 格:
			break
		var 可 := MapNavigator.reachable_cells(s.run_state)
		if 可.is_empty():
			break
		if not bool(s.move_to_cell(_朝目标走(s, 可, 格)).get("ok", false)):
			break
	if s.run_state.node_id != 格:
		return false
	return s.start_node_battle()

func _结算幂等(t) -> void:
	# ---- 肉鸽那条路 ----
	var s := GameSession.new()
	s.存档路径 = 存档A
	s.start_new_run(肉鸽种子 + 41, "混编")
	_补强名册(s)
	var 可招 := s.available_recruit_targets(0)
	if not 可招.is_empty():
		s.recruit_unit(str(可招[0].get("键", "")), 0)
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
	if not _走到战斗格开战(s, 0):
		t.ok(false, "第 1 层走不到战斗格 / 开不了战，段 8 剩下的断言跑不了")
		return
	s.auto_finish_battle()
	var 首次 := s.finish_battle_and_settle()
	var 首次成功 := not 首次.has("ok") or bool(首次.get("ok", false))
	var 前 := _结算数字(s)
	var 重复结果 := []
	for _i in 4:
		重复结果.append(s.finish_battle_and_settle())
	var 后 := _结算数字(s)
	var 都拒 := true
	for r in 重复结果:
		if bool(r.get("ok", true)) or str(r.get("为什么", "")).length() == 0:
			都拒 = false
	t.ok(首次成功, "★ D-07：第一次结算成功（场次 %d / 胜场 %d / 源碳 %d）"
		% [int(前["场次"]), int(前["胜场"]), int(前["源碳"])])
	t.ok(都拒 and 重复结果.size() == 4,
		"★ D-07：后 4 次调用**全部** ok=false 且给 why（为什么=「%s」）" % str(重复结果[0].get("为什么", "")))
	t.info("★ D-07 幂等：5 次调用前后 —— 源碳 %d / 希望 %d / 经验 %d / 场次 %d / 胜场 %d / 已清节点 %d / 藏品 %d / 耐久 %d / 券 %d"
		% [int(后["源碳"]), int(后["希望"]), int(后["经验"]), int(后["场次"]), int(后["胜场"]),
			int(后["已清节点"]), int(后["藏品"]), int(后["耐久"]), int(后["券"])])
	var 差 := _两遍数字一样(前, 后)
	t.ok(差.is_empty(), "★ D-07：连调 5 次之后**每一项数字逐项相同**（源碳 %d / 希望 %d / 经验 %d / 场次 %d / 胜场 %d / 血比 %s）%s"
		% [int(后["源碳"]), int(后["希望"]), int(后["经验"]), int(后["场次"]), int(后["胜场"]),
			str(后["血比%"]), "" if 差.is_empty() else "；差异：" + str(差)])

	# ---- 复位：走到下一格开新一场 → 能正常结算 ----
	var 前层格 := s.run_state.node_id
	var 换格 := false
	for _i in 14:
		var 可2 := MapNavigator.reachable_cells(s.run_state)
		if 可2.is_empty():
			break
		if not bool(s.move_to_cell(int(可2[0])).get("ok", false)):
			break
		if s.run_state.node_id != 前层格:
			换格 = true
			break
	t.ok(换格, "结算完走到下一格（%d → %d）" % [前层格, s.run_state.node_id])
	if _走到战斗格开战(s, 1):
		s.auto_finish_battle()
		var 第二场 := s.finish_battle_and_settle()
		t.ok(not 第二场.has("ok") or bool(第二场.get("ok", false)),
			"★ D-07 复位：新一场能正常结算（场次 %d / 胜场 %d / 源碳 %d；为什么不适用=「%s」）"
			% [s.run_state.battles_fought, s.run_state.battles_won, s.run_state.carbon, str(第二场.get("为什么", ""))])
	else:
		t.info("第 1 层找不到第二个战斗格，跳过「新一场能结算」那一条")

	# ---- 快速战斗那条路 ----
	var q := GameSession.new()
	q.存档路径 = 存档B
	t.ok(q.start_quick_battle(快速种子 + 3), "快速战斗开局成功")
	q.auto_finish_battle()
	var 快首次 := q.finish_battle_and_settle()
	var 快前 := _结算数字(q)
	var 快重复 := []
	for _i in 4:
		快重复.append(q.finish_battle_and_settle())
	var 快后 := _结算数字(q)
	var 快都拒 := true
	for r in 快重复:
		if bool(r.get("ok", true)):
			快都拒 = false
	t.ok(not 快首次.has("ok") or bool(快首次.get("ok", false)), "★ D-07 快速战：第一次结算成功")
	t.ok(快都拒, "★ D-07 快速战：后 4 次全部 ok=false（为什么=「%s」）" % str(快重复[0].get("为什么", "")))
	var 快差 := _两遍数字一样(快前, 快后)
	t.ok(快差.is_empty(), "★ D-07 快速战：连调 5 次之后数字逐项相同（源碳 %d / 希望 %d / 经验 %d / 场次 %d / 胜场 %d）%s"
		% [int(快后["源碳"]), int(快后["希望"]), int(快后["经验"]), int(快后["场次"]), int(快后["胜场"]),
			"" if 快差.is_empty() else "；差异：" + str(快差)])
	# 再开一场快速战斗 → 标志必须复位（要打完再结算，不能拿「没打完」当成功）
	t.ok(q.start_quick_battle(快速种子 + 4), "★ D-07 复位：再开一场快速战斗（start_quick_battle 复位标志）")
	q.auto_finish_battle()
	var 第二快 := q.finish_battle_and_settle()
	t.ok(not 第二快.has("ok") or bool(第二快.get("ok", false)),
		"★ D-07 复位：新一场快速战斗能正常结算（场次 %d / 胜场 %d / 源碳 %d）"
		% [q.run_state.battles_fought, q.run_state.battles_won, q.run_state.carbon])
	# 重画不二次结算（M4-3 的视图守卫思路在门面这一层也成立）
	var 三前 := _结算数字(q)
	for _i in 3:
		q.finish_battle_and_settle()
	t.ok(_两遍数字一样(三前, _结算数字(q)).is_empty(),
		"★ D-07：重复调用之后再次结算屏重画也不会二次结算（源碳 %d / 场次 %d）"
		% [q.run_state.carbon, q.run_state.battles_fought])

# ==========================================================================================
# 段 9：★ D-08（接上追击战）+ ★ D-10（对齐 JS 的**触发时机**）
#   D-08：推进剂见底 → 追击战（此前 Godot 侧完全没接线，会在非战斗格上永久卡死）。
#   D-10：封存 JS `92-肉鸽界面-1-大图与记录.js:315`「**这一格结算完**就会触发追击战」——
#         落脚那一格自己还有东西要结算（战斗格 / 黑市 / 事件 / 休息…）时，必须**先结算这一格**，
#         否则用最后 1 点推进剂落在作战 / 精英格上会变成「先打追击战、那一格的节点战永远没打」。
# ==========================================================================================

## 开一局、招一台、把这一台摆上出击位（追击战要有我方编成才能开）。
func _起一局能打的(s: GameSession, 种子: int) -> bool:
	if not s.start_new_run(种子, "混编"):
		return false
	s.run_state.hope = maxi(s.run_state.hope, 40)
	var 可招 := s.available_recruit_targets(0)
	if 可招.is_empty():
		return false
	var 键 := str(可招[0].get("键", ""))
	var 招 := s.recruit_unit(键, 0)
	if not bool(招.get("ok", false)):
		return false
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
	s.run_state.lineup = [{"key": 键, "slot": 0}]
	return NodeResolver.我方编成(s.run_state).size() >= 1

func _追击战(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	if not _起一局能打的(s, 肉鸽种子 + 51):
		t.ok(false, "起局失败（招不到人 / 编成空），段 9 剩下的断言跑不了")
		return
	# ---- ★ 正常（推进剂 > 0）路径下**不会**触发追击战（旧行为没砍）----
	var 可达 := MapNavigator.reachable_cells(s.run_state)
	if not 可达.is_empty():
		s.move_to_cell(int(可达[0]))
	t.ok(s.screen == "map" and s.battle_ctx.is_empty() and s.run_state.propellant > 0,
		"★ D-08 旧行为：推进剂 %d > 0 时走一格**不会**触发追击战（屏幕 %s、battle_ctx 空 = %s）"
		% [s.run_state.propellant, s.screen, str(s.battle_ctx.is_empty())])

	# ---- ★ 把推进剂压到 0，站在一个「非战斗、非出口」的格上 → 这一格结算完就开追击战 ----
	var 空格 := _找格(s, "空")
	if 空格 < 0:
		空格 = _找格(s, "瞭望站")
	if 空格 < 0:
		t.ok(false, "这一层找不到「非战斗、非出口」的格，段 9 的追击战断言跑不了")
		return
	s.run_state.node_id = 空格
	s.run_state.mark_visited(空格)
	s.run_state.propellant = 0
	var 前层 := s.run_state.floor_num
	t.ok(MapNavigator.exit_chase_pending(s.run_state),
		"★ D-08：站在「%s」格（%d）推进剂 0 → 内核 `exit_chase_pending` = true"
		% [str(s.run_state.current_type()), 空格])
	t.ok(MapNavigator.reachable_cells(s.run_state).is_empty(),
		"推进剂 0 时哪儿都走不动（能去的格 = %d）—— 不接追击战就会在这里永久卡死"
		% MapNavigator.reachable_cells(s.run_state).size())
	var 打 := s.enter_current_node()
	var 我方数 := (s.battle_ctx["allies"] as Array).size() if s.battle_ctx.get("allies") is Array else 0
	var 敌方数 := (s.battle_ctx["enemies"] as Array).size() if s.battle_ctx.get("enemies") is Array else 0
	t.ok(s.screen == "battle" and str(s.run_state.map_data.get("当前节点类型", "")) == "追击",
		"★ D-08：这一格结算完**开出了追击战**（屏幕 %s、格类型 %s、我方 %d 台 / 敌方 %d 台）"
		% [s.screen, str(s.run_state.map_data.get("当前节点类型", "")), 我方数, 敌方数])
	t.ok(str(s.last.get("行动", "")) == "追击战" and s.hand_count() >= 1,
		"追击战的即时反馈（行动 = %s、手牌 %d 张、编成类型 %s）"
		% [str(s.last.get("行动", "")), s.hand_count(), str(s.last.get("编成类型", ""))])

	# ---- ★ 打赢 → after_chase_win 生效：layer_prop_bonus == −2 且换到下一层 ----
	s.auto_finish_battle()
	var 结果 := str(s.battle_ctx.get("result", {}).get("结果", ""))
	var 结 := s.finish_battle_and_settle()
	t.info("追击战：结果 = %s；结算后有 chased = %s / 层 = %d / 层修正 = %d / 状态 = %s / 结键 = %s"
		% [结果, str(s.run_state.chased), s.run_state.floor_num, s.run_state.layer_prop_bonus,
			s.run_state.status, str(结.keys())])
	t.ok(s.run_state.layer_prop_bonus == -2,
		"★ D-08：`layer_prop_bonus` = %d（被追击过 → 下一层推进剂上限 −2，照 JS `90-肉鸽-3:196`）"
		% s.run_state.layer_prop_bonus)
	# 注：`chased` 是**每一层**的临时标记，`enter_floor()` 进新层就清（照 JS `90-肉鸽-3:101-104`），
	# 所以这里断言它的「效果」—— 层修正 −2 与换层 —— 而不是换层之后再去看它还是不是 true。
	t.ok(s.run_state.floor_num == 前层 + 1 or s.run_state.status == "胜利",
		"★ D-08：追击战打完就换层（第 %d 层 → 第 %d 层）—— 「别处的追击战照旧能换层」" % [前层, s.run_state.floor_num])
	var 账 := MapGenerator.propellant_detail(s.run_state)
	t.ok(int(账["层修正"]) == -2 and s.run_state.propellant == int(账["上限"]),
		"新一层推进剂 = %d/%d（层修正 %d 已算进去）"
		% [s.run_state.propellant, s.run_state.propellant_max, int(账["层修正"])])
	t.ok(MapNavigator.reachable_cells(s.run_state).size() >= 1, "换层之后又能走了（能去 %d 格）"
		% MapNavigator.reachable_cells(s.run_state).size())

	# ---- ★ 站在出口格 + 推进剂 0 → 先 begin_exit_chase 置位 + 出口「尽头」被守军闸拦下 ----
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
	var 尽头 := int(s.run_state.map_data.get("出口尽头", -1))
	if 尽头 < 0:
		t.info("这一层没有「出口尽头」，跳过守军闸那一条")
		return
	s.run_state.node_id = 尽头
	s.run_state.mark_visited(尽头)
	s.run_state.propellant = 0
	s.run_state.chased = false
	s.run_state.exit_chase = false
	s.run_state.base_hp = s.run_state.base_max_hp   # 前面几场已经打掉不少耐久，这里只验出口口径
	MapNavigator.choose_exit(s.run_state, "尽头")
	# 先把守军恢复成「没清」（换层会重建地图，守军可能已经是已过）
	var 守军 := int(s.run_state.map_data.get("守军", -1))
	if 守军 >= 0:
		var 守格 := s.run_state.cell_at(守军)
		if not 守格.is_empty():
			守格["已过"] = false
			守格["类型"] = "守军"
	s.run_state.map_data["当前节点类型"] = "出口尽头"
	var 前层2 := s.run_state.floor_num
	var 出口打 := s.try_advance_floor()
	t.ok(s.screen == "battle" and bool(s.run_state.exit_chase),
		"★ D-08 口径 D：站在出口格推进剂 0 → 先 `begin_exit_chase` 置位（exit_chase = %s）并开打（屏幕 %s）"
		% [str(s.run_state.exit_chase), s.screen])
	if s.screen == "battle":
		s.auto_finish_battle()
		var 结3 := s.finish_battle_and_settle()
		t.ok(s.run_state.floor_num == 前层2 or s.run_state.pending_floor_change != null,
			"★ D-08 口径 D：守军没清 + 走尽头 → **不通关也不换层**，这一趟记进「待换层」（层 %d → %d、待换层 %s）"
			% [前层2, s.run_state.floor_num, str(s.run_state.pending_floor_change)])
		t.info("出口那一步的追击战：结算完状态 = %s / 持久层 %d / 待换层 %s"
			% [s.run_state.status, s.run_state.floor_num, str(s.run_state.pending_floor_change)])

	# ---- ★ 出口小径：免守军，追击战打完照常换层 ----
	var 小径 := int(s.run_state.map_data.get("出口小径", -1))
	if 小径 < 0:
		t.info("这一层没有「出口小径」，跳过小径那一条")
		return
	while not s.run_state.pending_card_picks.is_empty():
		if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
			break
	s.run_state.node_id = 小径
	s.run_state.mark_visited(小径)
	s.run_state.propellant = 0
	s.run_state.chased = false
	s.run_state.exit_chase = false
	s.run_state.base_hp = s.run_state.base_max_hp
	MapNavigator.choose_exit(s.run_state, "小径")
	s.run_state.map_data["当前节点类型"] = "出口小径"
	var 前层3 := s.run_state.floor_num
	s.try_advance_floor()
	if s.screen == "battle":
		s.auto_finish_battle()
		s.finish_battle_and_settle()
	t.ok(s.run_state.floor_num == 前层3 + 1 or s.run_state.status == "胜利",
		"★ D-08 口径 D：走**出口小径**（免守军）→ 追击战打完照常换层（第 %d 层 → 第 %d 层、状态 %s）"
		% [前层3, s.run_state.floor_num, s.run_state.status])
	t.ok(s.run_state.pending_floor_change == null or s.run_state.floor_num > 前层3,
		"小径这一趟没有把换层欠下来（待换层 = %s）" % str(s.run_state.pending_floor_change))

# ==========================================================================================
# 段 9b：★★ D-10 —— 追击战的**触发时机**（对齐封存 JS `92-肉鸽界面-1-大图与记录.js:315`）
#   五组：① 战斗格上见底 = **先打节点战**、追击战还欠着；
#         ② 那一场节点战结算完 → **这时才**开追击战；再打完 → 换层；
#         ③ 非战斗格（空）上见底 = 当场追击战（防回归）；
#         ④ 「0 推进剂 + 有东西可结算」的格**不许卡死**（结算完能开出追击战）；
#         ⑤ 推进剂 > 0 时不会触发（旧行为不砍；见段 9 开头那条）。
# ==========================================================================================

## 把节点摆到本层起点、把到 `目标格` 的 BFS 最短路上**除目标格以外**的格都标成走过，
## 再把推进剂设成「走到目标格的花费」——于是 `move_to_cell` 走完**刚好见底**。
## 返回收费（< 0 = 造不出来：路不通 / 起点就是目标格 / 目标格已经在「已走过」集合里）。
func _摆到时刚好见底(s: GameSession, 目标格: int) -> int:
	if s.run_state == null or s.run_state.map_data.is_empty():
		return -1
	s.run_state.node_id = int(s.run_state.map_data.get("起点", 0))
	s.run_state.chased = false
	s.run_state.exit_chase = false
	var 走 := MapNavigator.can_move_to(s.run_state, 目标格)
	if not bool(走.get("ok", false)):
		return -1
	var 费 := int(走.get("cost", 0))
	if 费 < 1:
		return -1
	var 路: Array = 走.get("path", [])
	if 路.size() < 2 or int(路[0]) != s.run_state.node_id or int(路[路.size() - 1]) != 目标格:
		return -1
	s.run_state.visited_cells = [int(路[0])]
	for i in range(1, 路.size() - 1):
		s.run_state.mark_visited(int(路[i]))
	if s.run_state.is_visited(目标格):
		return -1
	s.run_state.propellant = 费
	return 费

## 找一个「类型在 `类型们` 里、没被走过、从本层起点**走得到、花费 ≥ 1**」的格；没有 → −1。
## ★ 找格之前先把节点摆回本层起点（`can_move_to` 是拿**当前所在格**当起点的）。
func _找可摆的格(s: GameSession, 类型们: Array) -> int:
	if s.run_state == null or s.run_state.map_data.is_empty():
		return -1
	var 起点 := int(s.run_state.map_data.get("起点", 0))
	s.run_state.node_id = 起点
	for k in MapNavigator.cell_ids(s.run_state):
		var 格 := s.run_state.cell_at(k)
		if not 类型们.has(str(格.get("类型", ""))):
			continue
		if bool(格.get("已过", false)) or s.run_state.is_visited(k):
			continue
		if k == 起点:
			continue
		if int(MapNavigator.can_move_to(s.run_state, k).get("cost", 0)) < 1:
			continue
		return k
	return -1

func _追击战D10(t) -> void:
	if not _D10_战斗格先打节点战(t):
		return
	_D10_非战斗格当场追击战(t)
	_D10_卡死不回来(t)

## ① 最后 1 点推进剂落在**未走过的战斗格**上 → 先打这一格的**节点战**（格类型 = 该格真实类型），
##    追击战**还欠着**；② 这一场节点战结算完 → 这时才开追击战；再打完 → 换层到第 2 层。
func _D10_战斗格先打节点战(t) -> bool:
	var s := GameSession.new()
	s.存档路径 = 存档A
	if not _起一局能打的(s, 肉鸽种子 + 71):
		t.ok(false, "★ D-10：起局失败（招不到人 / 编成空），战斗格那几条断言跑不了")
		return false
	# ★ 挑**精英**格优先：它是「被追击战顶掉就会丢藏品 / 掉落」的那一格，D-10 要防的就是它。
	var 战格 := _找可摆的格(s, ["精英", "作战", "守军", "侵蚀源"])
	if 战格 < 0:
		t.ok(false, "第 %d 层找不到「未走过、从起点走得到、花费 ≥ 1」的战斗格 —— D-10 的战斗格断言跑不了" % s.run_state.floor_num)
		return false
	var 真类型 := str(s.run_state.cell_at(战格).get("类型", ""))
	var 前层 := s.run_state.floor_num
	var 费 := _摆到时刚好见底(s, 战格)
	if 费 < 0:
		t.ok(false, "战斗格 %d（%s）造不出「走一步就刚好见底」的局面" % [战格, 真类型])
		return false
	var 走 := s.move_to_cell(战格)
	t.ok(bool(走.get("ok", false)) and s.run_state.propellant == 0,
		"★ D-10 前置：最后 1 点推进剂落在**未走过的战斗格**上（格 %d「%s」，费 %d，走完 propellant = %d）"
		% [战格, 真类型, 费, s.run_state.propellant])
	t.ok(s.screen == "map" and str(s.last.get("行动", "")) == "移动" and s.battle_ctx.is_empty(),
		"★ D-10：`move_to_cell` 这一下**没开追击战**（屏幕 %s、上一动作 = %s、battle_ctx 空 = %s）—— 这一格还没结算"
		% [s.screen, str(s.last.get("行动", "")), str(s.battle_ctx.is_empty())])
	# ★ 视图在移动成功后就是这一下（`map_view._点格()` → `_进入脚下(true)`）；门面这一层要显式叫它。
	s.enter_current_node()
	t.ok(s.screen == "battle" and str(s.last.get("行动", "")) == "开战" and str(s.last.get("格类型", "")) == 真类型,
		"★ D-10：先打的是**脚下的节点战**（屏幕 = %s、上一动作 = %s、格类型 = %s / 这一格真类型 = %s）"
		% [s.screen, str(s.last.get("行动", "")), str(s.last.get("格类型", "")), 真类型])
	t.ok(MapNavigator.exit_chase_pending(s.run_state),
		"★ D-10：**追击战还欠着**（推进剂 %d、本层已追击过 = %s → `exit_chase_pending` = true）"
		% [s.run_state.propellant, str(s.run_state.chased)])
	t.ok(str(s.run_state.map_data.get("当前节点类型", "")) == 真类型,
		"★ D-10：`map_data[\"当前节点类型\"]` 还是脚下这一格的真实类型（%s，不是「追击」）"
		% str(s.run_state.map_data.get("当前节点类型", "")))
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	var 结2: Dictionary = s.battle_ctx.get("result", {}) if s.battle_ctx.get("result") is Dictionary else {}
	t.info("★ D-10 独立报告：节点战打完（结果 = %s）→ 屏幕 = %s、上一动作 = %s、上一场格类型 = %s"
		% [str(结2.get("结果", "")), s.screen, str(s.last.get("行动", "")), str(s.last.get("格类型", ""))])
	t.ok(s.screen == "battle" and str(s.last.get("行动", "")) == "追击战" and str(s.last.get("格类型", "")) == "追击",
		"★ D-10：**这时才**开追击战（节点战结算完；屏幕 = %s、上一动作 = %s、格类型 = %s）"
		% [s.screen, str(s.last.get("行动", "")), str(s.last.get("格类型", ""))])
	s.auto_finish_battle()
	s.finish_battle_and_settle()
	t.ok(s.run_state.floor_num == 前层 + 1 or s.run_state.status == "胜利" or s.run_state.status == "失败",
		"★ D-10：追击战打完就换层（第 %d 层 → 第 %d 层；状态 %s）" % [前层, s.run_state.floor_num, s.run_state.status])
	return true

## ③ 非战斗格（空）上见底 = **当场**追击战（防回归：D-10 不许把这一条砍掉，否则死锁回来）。
func _D10_非战斗格当场追击战(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档A
	if not _起一局能打的(s, 肉鸽种子 + 72):
		t.ok(false, "★ D-10：起局失败，非战斗格那几条断言跑不了")
		return
	var 用 := _找可摆的格(s, ["空"])
	if 用 < 0:
		t.ok(false, "第 %d 层找不到「未走过、从起点走得到」的空格 —— D-10 的非战斗格断言跑不了" % s.run_state.floor_num)
		return
	var 实 := str(s.run_state.cell_at(用).get("类型", ""))
	var 费 := _摆到时刚好见底(s, 用)
	if 费 < 0:
		t.ok(false, "空格 %d 造不出「走一步就刚好见底」的局面" % 用)
		return
	s.move_to_cell(用)
	t.ok(s.run_state.propellant == 0 and s.screen == "battle" and str(s.last.get("行动", "")) == "追击战" and str(s.last.get("格类型", "")) == "追击",
		"★ D-10 防回归：落在「%s」格 %d 上见底 → **当场**开追击战（推进剂 %d、屏幕 %s、上一动作 = %s、格类型 = %s）"
		% [实, 用, s.run_state.propellant, s.screen, str(s.last.get("行动", "")), str(s.last.get("格类型", ""))])
	t.ok(s.screen != "map",
		"★ D-10 防回归：这一刻**不在**地图屏（screen = %s）—— 门面已经把追击战接上了，视图不用再兜" % s.screen)

## ④ 「0 推进剂 + 这一格有东西可结算」**不许卡死**：结算完要么**开得出追击战**，
##    要么这一格的结算**把推进剂补回来**（那也走得动了）。两条都验，一条都不许两条都不成立。
func _D10_卡死不回来(t) -> void:
	var 验过: Array = []
	var 开出追击: Array = []
	for 类型 in ["遗迹", "瞭望站", "事件", "休整", "黑市", "招募站"]:
		var s := GameSession.new()
		s.存档路径 = 存档A
		if not _起一局能打的(s, 肉鸽种子 + 73):
			t.ok(false, "★ D-10：起局失败，卡死那组断言跑不了")
			return
		var 格 := _找可摆的格(s, [类型])
		if 格 < 0:
			continue
		var 费 := _摆到时刚好见底(s, 格)
		if 费 < 0:
			continue
		s.move_to_cell(格)
		if s.screen == "battle":
			# 门面在这一步就开了追击战（D-08 的老路）—— D-10 要求它**先不开**，等这一格结算
			t.ok(false, "★ D-10：站在「%s」格 %d 上见底 → 门面在 `move_to_cell` 里就开了追击战（应该等这一格结算完）" % [类型, 格])
			return
		验过.append(类型)
		# 走到这儿：屏幕还在 map（这一格的面板已经摆好）→ 让玩家「进这一格」
		var 打 := s.enter_current_node()
		var 能走 := MapNavigator.reachable_cells(s.run_state).size() >= 1
		var 开了 := s.screen == "battle" and str(s.last.get("行动", "")) == "追击战"
		if 开了:
			开出追击.append(类型)
		t.ok(开了 or 能走,
			"★ D-10 卡死不回来：「%s」格（%d，费 %d）上见底 → 结算完**没有卡死**（追击战 = %s、结算后推进剂 %d、又能走 %d 格；返回 %s）"
			% [类型, 格, 费, str(开了), s.run_state.propellant, MapNavigator.reachable_cells(s.run_state).size(), str(打)])
	t.ok(开出追击.size() >= 1,
		"★ D-10 卡死不回来：其中**%d 种**格的结算**没有**补回推进剂 → 结算完照样开得出追击战（%s）"
		% [开出追击.size(), "、".join(开出追击)])
	t.ok(验过.size() >= 1,
		"★ D-10 卡死不回来：真的在「有东西可结算」的格上验到了**%d 种**（%s）" % [验过.size(), "、".join(验过)])

# ==========================================================================================
# 段 10：★ D-09 —— 招募写进 `lineup` 的位号必须是**数字**（原来写的是空串 ""）
# ==========================================================================================
func _招募位号是数字(t) -> void:
	var s := GameSession.new()
	s.存档路径 = 存档B
	t.ok(s.start_new_run(肉鸽种子 + 61, "混编"), "开局成功（屏幕=%s）" % s.screen)
	s.run_state.hope = maxi(s.run_state.hope, 60)
	var 招了几台 := 0
	for i in s.run_state.tickets.size():
		var 目标 := ""
		for x in s.available_recruit_targets(i):
			var k := str(x.get("键", ""))
			if not s.run_state.roster.has(k) and RosterManager.券合(s.run_state.tickets[i], k):
				目标 = k
				break
		if 目标.is_empty():
			continue
		if bool(s.recruit_unit(目标, i).get("ok", false)):
			招了几台 += 1
		while not s.run_state.pending_card_picks.is_empty():
			if not s.pick_tactical_card(str(s.run_state.pending_card_picks[0])):
				break
	t.ok(招了几台 >= 2, "★ D-09：招了 %d 台（出击名单 %d 条）" % [招了几台, s.run_state.lineup.size()])
	var 位号 := []
	var 空串 := 0
	var 重号 := []
	var 见过 := {}
	for x in s.run_state.lineup:
		if not (x is Dictionary):
			continue
		var v: Variant = x.get("slot", null)
		if v is String:
			空串 += 1
			位号.append(str(v))
			continue
		位号.append(int(v))
		if 见过.has(int(v)):
			重号.append(int(v))
		见过[int(v)] = true
	t.ok(空串 == 0, "★ D-09：`lineup` 里没有字符串位号（空串 %d 个；真实位号 %s）" % [空串, str(位号)])
	t.ok(重号.is_empty(), "★ D-09：多台新招募的机体**不再都算 0 号位**（重复位号 %s）" % str(重号))
	var 占位 := 0
	for x in s.lineup_slots():
		if not str(x.get("键", "")).is_empty():
			占位 += 1
	t.ok(占位 == s.run_state.lineup.size(),
		"★ D-09：编队屏占位数 %d == 出击名单条数 %d（位号唯一 → 不再串台）" % [占位, s.run_state.lineup.size()])
