## ★ 第 3 / 5 / 6 / 7 项断路器修复（DS41F）的**端到端**验收。
##
## 权威依据：`协作/设计/ATX势力卡牌设计 v0.3.md` §4（合体技【轮盘双响】）· §5（势力牌）
##          · `协作/设计/拉米亚卡牌设计 v0.1.md` §5 · `协作/设计/艾克赛琳卡牌设计 v0.1.md` §2.2 / §3
##          · `协作/设计/卡牌流转规则 v0.1.md` §1（四区域）
##
## 七段：
##   ① 第 3 项：【轮盘双响】开场就在**两人大招槽**里（共用状态 / cd 0 / 各付 15）；
##   ② 第 3 项：五条进入条件逐条给理由；
##   ③ 第 3 项：从**大招槽**打出 → 各付 15 / 两人主武器全消 / 两人槽同步 cd 5 / 赌局 / 阵亡移出；
##   ④ 第 3 项：【二次下注】在 `打出武器栏卡` 与 `打出大招` 两条路上都恰好结算 1 次；
##   ⑤ 第 5 项：Lv10 / 20 / 30 的大招槽晋升，与「快速测试 = 全卡池体验」的装填；
##   ⑥ 第 6 项：【援护射击】按目标抗性自动选弹种（日志注明（光束）/（实弹））；
##   ⑦ 第 7 项：快速测试战斗不留脏状态（回主菜单 / 开新局）。
##
## ★ 2026-10-17 试玩反馈修复（任务单 M1 / M2 / M3 / M4）追加三段：
##   ⑧ M1：〔连携〕**100% 触发**（时序修正）＋【乌鲁兹·三角】门槛归位 ＋ 快速测试起手保证；
##   ⑨ M3：响介（A1）的主武器真的进了 `u.武器栏`，**开局就能用 `Btl.打出主武器卡` 打出来**；
##   ⑩ M2 / M4：公有牌池按本队过滤 ＋ 下排公有牌**自动匹配对口队友** ＋ 快速测试起手 3 张 ＋ 试玩靶机。
extends RefCounted

const 种子 := 20261013

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_大招槽归位(t)
	_段2_五条进入条件(t)
	_段3_从大招槽打出(t)
	_段4_二次下注恰好一次(t)
	_段5_等级晋升与全卡池(t)
	_段6_援护射击自动弹种(t)
	_段7_不留脏状态(t)
	_段8_秘银连携与URUZ门槛(t)
	_段9_ATX武器栏进栏(t)
	_段10_公有牌自动匹配与靶机(t)

# ==========================================================================================
# ① 开场：A1 / A2 的 `大招槽` 里**都有**【轮盘双响】；共用状态（cd 0 / cd_max 5 / 各付 15）
# ==========================================================================================
func _段1_大招槽归位(t) -> void:
	var s := _快速战()
	if s == null:
		t.ok(false, "① ATX 五人快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var a1 := _单位Of(c, "A1")
	var a2 := _单位Of(c, "A2")
	t.ok(not a1.is_empty() and not a2.is_empty(), "① 场上找得到响介（A1）与艾克赛琳（A2）")
	var 槽1 := AtxFaction.合体技槽(a1)
	var 槽2 := AtxFaction.合体技槽(a2)
	t.ok(not 槽1.is_empty() and not 槽2.is_empty(),
		"① ★ 第 3 项：两人的 `大招槽` 里**都装了**【轮盘双响】（A1 %s / A2 %s）" % [
			"有" if not 槽1.is_empty() else "无", "有" if not 槽2.is_empty() else "无"])
	t.ok(str(J.g(J.g(槽1, "卡"), "id")) == FacAtx.合体技ID
		and str(J.g(J.g(槽2, "卡"), "id")) == FacAtx.合体技ID,
		"① 两张槽条目指向同一张牌 `%s`（共用状态）" % FacAtx.合体技ID)
	t.ok(J.num0(槽1.get("cd")) == 0.0 and J.num0(槽1.get("cd_max")) == 5.0
		and J.num0(槽2.get("cd_max")) == 5.0,
		"① 开场**不在冷却中**（cd %s）、冷却上限 **5**（cd_max %s）" % [
			J.s(J.num0(槽1.get("cd"))), J.s(J.num0(槽1.get("cd_max")))])
	var 合卡 := FacAtx.合体技卡()
	t.ok(int(J.num0(合卡.get("耗气"))) == 15 and int(J.num0(合卡.get("各付"))) == 15
		and J.truthy((合卡.get("占行动") as Array).has("A1"))
		and J.truthy((合卡.get("占行动") as Array).has("A2")),
		"① 费用 = **各付 15 战意**、占行动 = A1 + A2")
	var 堆里有 := false
	for 区 in ["专属牌库", "专属手牌", "专属弃牌堆", "待入库"]:
		for x in J.or_(a1.get(区), []):
			if x is Dictionary and str((x as Dictionary).get("id", "")) == FacAtx.合体技ID:
				堆里有 = true
	t.ok(not 堆里有, "① ★ 响介的四个牌区里**不再**各留一份【轮盘双响】（它归大招槽了）")

# ==========================================================================================
# ② 五条进入条件：UI 上看到的每一条都清清楚楚（不是一句「打不出来」）
# ==========================================================================================
func _段2_五条进入条件(t) -> void:
	var s := _快速战()
	if s == null:
		t.ok(false, "② 快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var a1 := _单位Of(c, "A1")
	var a2 := _单位Of(c, "A2")
	var 槽 := AtxFaction.合体技槽(a1)
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽).contains("各打出过 1 次大招"),
		"② ★ 两人都还没打过大招 → 明确理由：「%s」" % DeckFlow.大招不可打原因(c, a1, 槽))
	c["ATX大招打出人"] = {"A1": true, "A2": true}
	a1["战意"] = 60.0
	a2["战意"] = 60.0
	a1["主武器已销毁"] = true
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽).contains("主武器卡已销毁"),
		"② ★ 两人都打过大招、但响介本回合已打过主武器 → 「%s」" % DeckFlow.大招不可打原因(c, a1, 槽))
	a1["主武器已销毁"] = false
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽) == "",
		"② ★ 三条都满足（在场 / 各打过大招 / 都没打过主武器）→ 打得出来")
	a1["战意"] = 14.0
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽).contains("战意不足"),
		"② ★ 响介战意 14 < 各付 15 → 「%s」" % DeckFlow.大招不可打原因(c, a1, 槽))
	a1["战意"] = 60.0
	槽["cd"] = 2.0
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽).contains("冷却中"),
		"② ★ 槽里 cd = 2 → 「%s」" % DeckFlow.大招不可打原因(c, a1, 槽))
	槽["cd"] = 0.0
	槽["本回合已打"] = true
	t.ok(DeckFlow.大招不可打原因(c, a1, 槽).contains("本回合已使用"),
		"② ★ 本回合已打 → 「%s」" % DeckFlow.大招不可打原因(c, a1, 槽))
	槽["本回合已打"] = false
	a2["hp"] = 0.0
	t.ok(AtxFaction.轮盘双响不可打原因(c, a1).contains("不在场"),
		"② ★ 艾克赛琳阵亡 → 「%s」" % AtxFaction.轮盘双响不可打原因(c, a1))

# ==========================================================================================
# ③ 从**大招槽**打出：各付 15 / 两人主武器全消 / 两人槽同步 cd 5 / 赌局 / 阵亡移出
# ==========================================================================================
func _段3_从大招槽打出(t) -> void:
	var s := _快速战()
	if s == null:
		t.ok(false, "③ 快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var a1 := _单位Of(c, "A1")
	var a2 := _单位Of(c, "A2")
	a1["战意"] = 90.0
	a2["战意"] = 90.0
	c["turn"] = 2.0
	var r1 := DeckFlow.打出大招(c, "A1", "ATX1_U1")
	var r2 := DeckFlow.打出大招(c, "A2", "ATX2_U1")
	t.ok(J.truthy(r1.get("成功")) and J.truthy(r2.get("成功")),
		"③ 两人各打了一次大招（响介 %s / 艾克赛琳 %s）" % [str(r1.get("原因", "ok")), str(r2.get("原因", "ok"))])
	t.ok(J.truthy(a1.get("本场已打大招")) and J.truthy(a2.get("本场已打大招")),
		"③ ★ 第 3 项：按**单位**记了 `本场已打大招`（A1 %s / A2 %s）" % [
			str(a1.get("本场已打大招")), str(a2.get("本场已打大招"))])
	t.ok(int(J.num0(J.g(c.get("v3计数"), "v3打出ATX大招"))) == 2
		and int(J.num0(J.g(c.get("v3计数"), "v3打出秘银大招"))) == 0,
		"③ ★ 记在 **ATX** 的键上（`v3打出ATX大招` = %s / `v3打出秘银大招` = %s，不再误写秘银）" % [
			J.s(J.num0(J.g(c.get("v3计数"), "v3打出ATX大招"))),
			J.s(J.num0(J.g(c.get("v3计数"), "v3打出秘银大招")))])
	# 「下一回合」：主武器恢复、槽的「本回合已打」复位（= 阶段初会做的事）
	c["turn"] = 3.0
	a1["主武器已销毁"] = false
	a2["主武器已销毁"] = false
	a1["战意"] = 90.0
	a2["战意"] = 90.0
	c["筹码牌库"] = AtxChips.初始筹码牌库()
	c["公有手牌"] = []
	a1["闪"] = true                                   # 两人任一亮闪字 → 赌局触发
	var 手前: int = (c["公有手牌"] as Array).size()
	var 槽1 := AtxFaction.合体技槽(a1)
	var 因 := DeckFlow.大招不可打原因(c, a1, 槽1)
	t.ok(因 == "", "③ ★ 三条都满足 → 打得出（%s）" % 因)
	var 敌键 := str((c.enemies[0] as Dictionary).get("key", ""))
	var r := DeckFlow.打出大招(c, "A1", FacAtx.合体技ID, 敌键)
	t.ok(J.truthy(r.get("成功")), "③ ★★ **从大招槽**打出【轮盘双响】（%s）" % str(r.get("原因", "ok")))
	var 上界 := 90.0 - 15.0 + Params.命中战意() * 12.0 + Params.击破战意()
	t.ok(J.round(Btl.战意(a1)) <= 上界 and J.round(Btl.战意(a2)) <= 上界,
		"③ ★ **各扣 15 战意**（A1 90 → %s / A2 90 → %s）" % [J.s(Btl.战意(a1)), J.s(Btl.战意(a2))])
	t.ok(J.truthy(a1.get("主武器已销毁")) and J.truthy(a2.get("主武器已销毁")),
		"③ ★ **两人的 `主武器已销毁` 都置 true**（A1 %s / A2 %s）" % [
			str(a1.get("主武器已销毁")), str(a2.get("主武器已销毁"))])
	var 槽1后 := AtxFaction.合体技槽(a1)
	var 槽2后 := AtxFaction.合体技槽(a2)
	t.ok(J.num0(槽1后.get("cd")) == 5.0 and J.num0(槽2后.get("cd")) == 5.0
		and J.truthy(槽1后.get("本回合已打")) and J.truthy(槽2后.get("本回合已打")),
		"③ ★ 两人大招槽**同步进入 cd = 5**（A1 %s / A2 %s）" % [
			J.s(J.num0(槽1后.get("cd"))), J.s(J.num0(槽2后.get("cd")))])
	var 合行: Array = J.or_(c.get("log"), []).filter(func(e):
		return e is Dictionary and J.truthy((e as Dictionary).get("轮盘双响")))
	t.ok(合行.size() == 1, "③ 一次合体技 = 一条〔轮盘双响〕总账记录（%d 条）" % 合行.size())
	var 库id: Array = J.or_(c.get("筹码牌库"), []).map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(int(AtxChips.赌局触发次数(c)) == 1 and (c["公有手牌"] as Array).size() == 手前 + 1,
		"③ ★ **赌局**（两人任一亮闪字）：触发 %d 次、抽 1 张（手牌 %d → %d）" % [
			int(AtxChips.赌局触发次数(c)), 手前, (c["公有手牌"] as Array).size()])
	t.ok(J.inc(库id, "ATX_CHIP_SLAM"),
		"③ ★ 头奖「大满贯」进了 `ctx.筹码牌库`（库 %d 张）" % 库id.size())
	a2["hp"] = 0.0
	Btl.记击破(c, c.enemies[0], a2)
	var 移出id: Array = J.or_(c.get("移出牌"), []).map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(AtxFaction.合体技槽(a1).is_empty() and AtxFaction.合体技槽(a2).is_empty()
		and J.inc(移出id, FacAtx.合体技ID),
		"③ ★ 艾克赛琳被击破 → 【轮盘双响】从两人大招槽**移出本场**（`ctx.移出牌` 里有它）")

# ==========================================================================================
# ④ 【二次下注】：`打出武器栏卡` 与 `打出大招`（武器型）两条路都恰好结算 1 次
# ==========================================================================================
func _段4_二次下注恰好一次(t) -> void:
	var s := _快速战()
	if s == null:
		t.ok(false, "④ 快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	# 塔斯克（A6）的牌**常驻武器栏**（不是 v01 卡）—— 这才是「打出武器栏卡」那条路
	var 武器栏 := s.weapon_bar_cards("A6")
	t.ok(not 武器栏.is_empty(), "④ 塔斯克上排有武器栏卡（%d 张）" % 武器栏.size())
	if 武器栏.is_empty():
		return
	var a6 := _单位Of(c, "A6")
	a6["战意"] = 90.0
	c["turn"] = 2.0
	(c["公有手牌"] as Array).append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.二次下注), c))
	var r0 := Btl.打出精神或公有牌(c, "A6", AtxFaction.二次下注)
	t.ok(J.truthy(r0.get("成功")) and c.get(AtxFaction.二次下注键) is Dictionary,
		"④ 塔斯克打出【二次下注】、标记挂上（%s）" % str(r0.get("原因", "ok")))
	var 前: int = _二次下注行数(c)
	# 武器栏卡 × 存活敌机：逐个试到第一张真的打得出去的（距离 / 站位都算）
	var r1 := {}
	for x in 武器栏:
		for e in J.or_(c.get("enemies"), []):
			if not (e is Dictionary) or float((e as Dictionary).get("hp", 0.0)) <= 0.0:
				continue
			r1 = Btl.打出武器栏卡(c, "A6", str((x as Dictionary).get("手牌键", "")), str((e as Dictionary).get("key", "")))
			if J.truthy(r1.get("成功")):
				break
		if J.truthy(r1.get("成功")):
			break
	t.ok(J.truthy(r1.get("成功")), "④ 塔斯克打出一张**武器栏卡**（%s）" % str(r1.get("原因", "ok")))
	var 中: int = _二次下注行数(c)
	t.ok(中 == 前 + 1, "④ ★ `打出武器栏卡` 上挂了一次二次下注结算（%d → %d 行）" % [前, 中])
	# 标记消费即清：再打一张武器牌不会再多一行
	a6["主武器已销毁"] = false
	var 武2 := s.weapon_bar_cards("A6")
	var 敌键2 := ""
	for e2 in J.or_(c.get("enemies"), []):
		if e2 is Dictionary and float((e2 as Dictionary).get("hp", 0.0)) > 0.0:
			敌键2 = str((e2 as Dictionary).get("key", ""))
			break
	if not 武2.is_empty() and 敌键2 != "":
		Btl.打出武器栏卡(c, "A6", str((武2[0] as Dictionary).get("手牌键", "")), 敌键2)
	var 后: int = _二次下注行数(c)
	t.ok(后 == 中, "④ ★ 标记**消费即清**：第二张武器牌不再多结算（仍是 %d 行）" % 后)
	# ③ 打出大招（武器型）那条路：重新挂标记 → 武器型大招也恰好 1 次
	c["turn"] = 3.0
	var a1 := _单位Of(c, "A1")
	a1["战意"] = 90.0
	a1["主武器已销毁"] = false
	(c["公有手牌"] as Array).append(Btl.克隆战术牌(FacAtx.卡(AtxFaction.二次下注), c))
	Btl.打出精神或公有牌(c, "A1", AtxFaction.二次下注)
	a1["主武器已销毁"] = false
	var 前2: int = _二次下注行数(c)
	var r3 := DeckFlow.打出大招(c, "A1", "ATX1_U1")
	t.ok(J.truthy(r3.get("成功")), "④ 响介打出一张**武器型大招**（%s）" % str(r3.get("原因", "ok")))
	var 后2: int = _二次下注行数(c)
	t.ok(后2 == 前2 + 1, "④ ★ `打出大招`（is_weapon）上也**恰好**挂一次（%d → %d 行）" % [前2, 后2])

func _二次下注行数(c: Dictionary) -> int:
	var n := 0
	for e in J.or_(c.get("log"), []):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "二次下注":
			n += 1
	return n

# ==========================================================================================
# ⑤ Lv10 / 20 / 30 的大招槽晋升 + 「快速测试 = 全卡池体验」
# ==========================================================================================
func _段5_等级晋升与全卡池(t) -> void:
	for 档 in [[10, ["ATX2_U1"]], [20, ["ATX2_U1", "ATX2_U2"]], [30, ["ATX2_U1", "ATX2_U2", "ATX2_U3"]]]:
		var lv: int = 档[0]
		var c := _裸场()
		var 艾 := _裸单位("A2", 4.0)
		艾["lv"] = float(lv)
		c["allies"] = [艾]
		var 装 := AtxThree.装填大招槽(c, 艾, lv)
		var id们: Array = []
		for 槽 in (艾.get("大招槽") as Array):
			id们.append(str(J.g(J.g(槽, "卡"), "id")))
		J.sort(id们, func(a, b): return -1.0 if str(a) < str(b) else (1.0 if str(a) > str(b) else 0.0))
		t.ok(int(装) == (档[1] as Array).size() and id们 == 档[1],
			"⑤ ★ Lv%d 的大招槽 = %s（装了 %d 张）" % [lv, str(id们), int(装)])
	# 肉鸽起手（没开全卡池体验）→ 只发「初始」（口径与 `装填单位` 一致）
	var 裸 := _裸单位("A1", 0.0)
	裸["lv"] = 30.0
	var 旧场 := _裸场()
	旧场["选项"] = {"单机牌组": true}
	var 只初始 := AtxThree.装填单位(裸, 30, 旧场)
	var 只初始主武 := 0
	for x in 只初始:
		if str((x as Dictionary).get("卡类", "")) == "主武器卡":
			只初始主武 += 1
	t.ok(只初始.size() == 8 and 只初始主武 == 3,
		"⑤ 肉鸽起手（未开全卡池体验）→ 仍然只发 **8 张「初始」**（主武器 3 把），既有预期零回归（实际 %d 张 / 主武 %d）" % [
			只初始.size(), 只初始主武])
	# 全卡池体验 → 4 把主武器 + 10 张精神（含剧情 / 肉鸽档）
	var c全 := _裸场()
	c全["选项"]["全卡池体验"] = true
	var 全档 := AtxThree.装填单位(_裸单位("A1", 0.0), 30, c全)
	var 主武: Array = []
	var 精神 := 0
	for x in 全档:
		if str((x as Dictionary).get("卡类", "")) == "主武器卡":
			主武.append(str((x as Dictionary).get("id", "")))
		elif str((x as Dictionary).get("卡类", "")) == "专属精神牌":
			精神 += 1
	t.ok(主武.size() == 4 and J.inc(主武, "ATX1_W4"),
		"⑤ ★ 全卡池体验：响介的**全部 4 把主武器**都装（含剧情档「热能角」）：%s" % str(主武))
	t.ok(精神 == 10, "⑤ ★ 全卡池体验：响介的**全部 10 张精神牌**都装（实际 %d 张）" % 精神)
	# 真开一场快速测试战：待入库 + 公有排
	var s := _快速战()
	if s == null:
		t.ok(false, "⑤ 快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var a1 := _单位Of(c, "A1")
	var 待入: Array = J.or_(a1.get("待入库"), [])
	t.ok(待入.size() >= 1,
		"⑤ ★ 带条件的精神牌进了 `u.待入库`（%d 张；条件满足时 push_front 置顶）" % 待入.size())
	var 公有: Array = J.concat(J.or_(c.get("公有牌库"), []), J.or_(c.get("公有待入库"), []))
	var 公有id: Array = 公有.map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(J.inc(公有id, AtxFaction.读牌) and J.inc(公有id, AtxFaction.二次下注)
		and J.inc(公有id, AtxFaction.幸运连号) and J.inc(公有id, AtxFaction.上头),
		"⑤ ★ 带条件的 4 张剧情 / 肉鸽势力牌都在公有排（读牌 / 二次下注 / 幸运连号 / 上头）")
	var 分类 := 0
	for x in 公有:
		if x is Dictionary and ["近卫", "尖兵", "重装"].has(str((x as Dictionary).get("归属", ""))):
			分类 += 1
	t.ok(分类 >= 3, "⑤ ★ 近卫 / 尖兵 / 重装分类牌也进了公有排（%d 张）" % 分类)

# ==========================================================================================
# ⑥ 【援护射击】：按目标抗性自动选最优弹种，日志注明（光束）/（实弹）
# ==========================================================================================
func _段6_援护射击自动弹种(t) -> void:
	var c := _裸场()
	var 艾 := _裸单位("A2", 6.0)
	艾["战意"] = 30.0
	var 靶 := _裸单位("靶", 0.0)
	靶["side"] = "enemy"
	靶["weak"] = {"光束": -50, "物理": 20}
	c["allies"] = [艾]
	c["enemies"] = [靶]
	艾["副武器栏"] = [{"卡": AtxThree.卡("ATX2_D1"), "本回合可用": 1, "本回合已用": 0, "禁用": false,
		"cd": 0.0, "cd_max": 0.0}]
	var r := DeckFlow.打出副武器(c, "A2", "ATX2_D1", str(靶.get("key")))
	t.ok(J.truthy(r.get("成功")), "⑥ 打出【援护射击】（%s）" % str(r.get("原因", "ok")))
	t.ok(str(r.get("弹种", "")) == "实弹" and str(r.get("伤害类型", "")) == "物理",
		"⑥ ★ 靶「光束抗性高于物理抗性」→ 自动选 **实弹（物理）**（弹种 = %s / 伤害类型 = %s）" % [
			str(r.get("弹种", "")), str(r.get("伤害类型", ""))])
	t.ok(_有日志文(c, "（实弹）"), "⑥ ★ 战斗日志里注明了「（实弹）」")
	var c2 := _裸场()
	var 艾2 := _裸单位("A2", 6.0)
	艾2["战意"] = 30.0
	var 靶2 := _裸单位("靶", 0.0)
	靶2["side"] = "enemy"
	c2["allies"] = [艾2]
	c2["enemies"] = [靶2]
	艾2["副武器栏"] = [{"卡": AtxThree.卡("ATX2_D1"), "本回合可用": 1, "本回合已用": 0, "禁用": false,
		"cd": 0.0, "cd_max": 0.0}]
	var r2 := DeckFlow.打出副武器(c2, "A2", "ATX2_D1", str(靶2.get("key")))
	t.ok(str(r2.get("弹种", "")) == "光束" and str(r2.get("伤害类型", "")) == "光束",
		"⑥ 没有抗性的靶 → 用 **光束**（弹种 = %s）" % str(r2.get("弹种", "")))
	t.ok(_有日志文(c2, "（光束）"), "⑥ ★ 战斗日志里注明了「（光束）」")

func _有日志文(c: Dictionary, 文: String) -> bool:
	for e in J.or_(c.get("log"), []):
		if e is Dictionary and str((e as Dictionary).get("文本", "")).contains(文):
			return true
	return false

# ==========================================================================================
# ⑦ 快速测试战斗不留脏状态（回主菜单 / 开新局）
# ==========================================================================================
func _段7_不留脏状态(t) -> void:
	var 路径 := "res://.godot/tmp_wiring_存档.json"
	var 全球 := ProjectSettings.globalize_path(路径)
	if FileAccess.file_exists(路径):
		DirAccess.remove_absolute(全球)
	var s := GameSession.new()
	s.存档路径 = 路径
	t.ok(s.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "⑦ 开一场 ATX 五人快速测试战")
	t.ok(s.is_quick_battle(), "⑦ 这一场里 `is_quick_battle` 为真")
	t.ok(bool(s._快速测试局), "⑦ 会话知道「这一局的 run_state 是快速测试顺手造的」")
	s.return_to_menu()
	t.ok(not s.is_quick_battle() and not bool(s._快速测试局),
		"⑦ ★ 回主菜单后 `is_quick_battle` / `_快速测试局` 都复位")
	t.ok(s.run_state == null, "⑦ ★ 回主菜单后 `run_state` 清空")
	t.ok(not FileAccess.file_exists(路径),
		"⑦ ★★ 快速测试战斗顺手造的「假肉鸽」**没有**写进存档（点「继续游戏」不会读回它）")
	var s2 := GameSession.new()
	s2.存档路径 = 路径
	t.ok(s2.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "⑦ 会话 2：再开一场快速测试战")
	t.ok(s2.start_new_run(种子, GameSession.默认分队), "⑦ 会话 2：直接开一局新肉鸽")
	t.ok(not bool(s2._快速测试局) and not bool(s2._全卡池体验) and not s2.is_quick_battle(),
		"⑦ ★★ 开新局后快速测试的三面旗（`_快速测试局` / `_全卡池体验` / `_quick_battle`）全部复位")
	t.ok(s2.run_state != null and int(s2.run_state.floor_num) == 1,
		"⑦ 开新局后 run_state 是**新的一局**（第 %d 层）" % int(s2.run_state.floor_num))

# ==========================================================================================
# ⑧ ★ M1（试玩反馈修复）：〔连携〕100% 触发 + 【乌鲁兹·三角】门槛归位 + 快速测试起手保证
# ==========================================================================================
func _段8_秘银连携与URUZ门槛(t) -> void:
	var s := _秘银快速战()
	if s == null:
		t.ok(false, "⑧ 秘银五人快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var u7 := _单位Of(c, "U7")
	var u2 := _单位Of(c, "U2")
	var u6 := _单位Of(c, "U6")
	t.ok(not u7.is_empty() and not u2.is_empty() and not u6.is_empty(),
		"⑧ 场上找得到宗介（U7）/ 毛（U2）/ 克鲁兹（U6）")
	# ---- 起手保证：毛手里有【呼叫达纳号】、公有起手 3 张里至少 1 张秘银牌 ----
	var 毛手: Array = (u2.get("专属手牌") as Array) if u2.get("专属手牌") is Array else []
	var 毛手id: Array = 毛手.map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(J.inc(毛手id, "V3_U2_S1"),
		"⑧ ★ M1：快速测试起手，毛（U2）的 `专属手牌` 里一定有【呼叫达纳号】（手里 %s）" % str(毛手id))
	var 公手: Array = (c.get("公有手牌") as Array) if c.get("公有手牌") is Array else []
	var 有秘银 := false
	for x in 公手:
		if Setup.是秘银公有牌(x):
			有秘银 = true
	t.ok(公手.size() == 3 and 有秘银,
		"⑧ ★ M1：公有手牌**起手 3 张**且至少 1 张秘银牌（%d 张 / 有秘银牌 = %s）" % [公手.size(), str(有秘银)])
	# ---- 【乌鲁兹·三角】的门槛：连携牌库需出现过三级牌 + U7 / U2 / U6 三人在场存活 ----
	var 三角 := {}
	var 武栏: Array = (u7.get("武器栏") as Array) if u7.get("武器栏") is Array else []
	for x in 武栏:
		if x is Dictionary and str((x as Dictionary).get("id", "")) == MithrilV03Cards.合体技ID:
			三角 = x
	t.ok(not 三角.is_empty(), "⑧ 【乌鲁兹·三角】在宗介的 `u.武器栏` 里（合体技归主武器区）")
	u7["主武器已销毁"] = false
	u7["战意"] = 90.0
	var 因1 := Btl.武器栏不可打原因(c, u7, 三角)
	t.ok(因1.contains("连携牌库需出现过三级牌"),
		"⑧ ★ M1：连携牌库还没出现过三级牌 → 明确理由「%s」" % 因1)
	c["连携牌库曾有三级"] = true
	var 因2 := Btl.武器栏不可打原因(c, u7, 三角)
	t.ok(not 因2.contains("连携牌库需出现过三级牌"),
		"⑧ ★ M1：三级牌放进连携牌库之后这条门槛就过了（现在：%s）" % (因2 if 因2 != "" else "打得出来"))
	var 克血 := float(u6.get("hp", 0.0))
	u6["hp"] = 0.0
	var 因3 := Btl.武器栏不可打原因(c, u7, 三角)
	t.ok(因3.contains("三人必须都在场存活"),
		"⑧ ★ M1：克鲁兹阵亡 → 「%s」" % 因3)
	u6["hp"] = 克血
	c["连携牌库曾有三级"] = false
	# ---- 时序修正：先打一张秘银牌（宗介武器栏卡），再打【呼叫达纳号】→〔连携〕必须触发 ----
	var 敌键 := _第一台活敌键(c)
	u7["战意"] = 90.0
	var r1 := Btl.打出武器栏卡(c, "U7", "V3_U7_W1", 敌键)
	t.ok(J.truthy(r1.get("成功")), "⑧ 宗介先打出【57mm 散弹炮】（%s）" % str(r1.get("原因", "ok")))
	var 上 = c.get("上张打出牌")
	t.ok(上 is Dictionary and J.truthy((上 as Dictionary).get("is_mithril_card")),
		"⑧ ★ M1：`ctx.上张打出牌` = **秘银牌**（连携就绪）")
	u2["战意"] = 90.0
	var r2 := Btl.打出精神或公有牌(c, "U2", "V3_U2_S1")
	t.ok(J.truthy(r2.get("成功")), "⑧ 毛打出【呼叫达纳号】（%s）" % str(r2.get("原因", "ok")))
	var 抽行 := _连携抽牌行们(c, "V3_U2_S1")
	t.ok(not 抽行.is_empty(),
		"⑧ ★★ M1：【呼叫达纳号】打出时〔连携〕**真的触发并抽到连携牌**（%d 条连携抽牌记录）" % 抽行.size())
	var 库: Array = (c.get("连携牌库") as Array) if c.get("连携牌库") is Array else []
	var 库id: Array = 库.map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(J.inc(库id, "V3_L2_SALVO"),
		"⑧ ★ M1：连携「先抽后放」——【TDD-1·饱和齐射】进了连携牌库（库 %d 张）" % 库id.size())
	t.ok(not _有日志文(c, "连携断开"),
		"⑧ ★ M1：日志里**没有**「连携断开」（时序修正前这里恒断开）")

## 日志里「来源卡 == 来源卡」的那几条连携抽牌记录。
func _连携抽牌行们(c: Dictionary, 来源卡: String) -> Array:
	var 出: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "连携抽牌" \
			and str((e as Dictionary).get("来源卡", "")) == 来源卡:
			出.append(e)
	return 出

# ==========================================================================================
# ⑨ ★ M3（试玩反馈修复）：响介（A1）的 v0.1 主武器真的进了 `u.武器栏`，开局就能打
# ==========================================================================================
func _段9_ATX武器栏进栏(t) -> void:
	var s := _快速战()
	if s == null:
		t.ok(false, "⑨ ATX 五人快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var a1 := _单位Of(c, "A1")
	if a1.is_empty():
		t.ok(false, "⑨ 场上找不到响介（A1）")
		return
	var 武栏: Array = (a1.get("武器栏") as Array) if a1.get("武器栏") is Array else []
	var 栏id: Array = 武栏.map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(not 武栏.is_empty(), "⑨ ★ M3：响介（A1）的 `u.武器栏` **非空**（%d 张：%s）" % [武栏.size(), str(栏id)])
	for k in ["ATX1_W1", "ATX1_W2", "ATX1_W3"]:
		t.ok(J.inc(栏id, k), "⑨ ★ M3：`u.武器栏` 里有 %s" % k)
	var 敌键 := _第一台活敌键(c)
	for k in ["ATX1_W1", "ATX1_W2", "ATX1_W3"]:
		var 序 := 栏id.find(k)
		if 序 < 0:
			t.ok(false, "⑨ 武器栏里没有 %s，跳过" % k)
			continue
		a1["主武器已销毁"] = false
		a1["战意"] = 60.0
		var 因 := Btl.武器栏不可打原因(c, a1, 武栏[序])
		t.ok(因 == "", "⑨ ★ M3：%s 现在打得出来（%s）" % [k, 因 if 因 != "" else "无拦截"])
		var r := Btl.打出主武器卡(c, "A1", k, 敌键)
		t.ok(J.truthy(r.get("成功")),
			"⑨ ★★ M3：开局就能用 `Btl.打出主武器卡` 打出 %s（%s）" % [k, str(r.get("原因", "ok"))])
		t.ok(J.truthy(a1.get("主武器已销毁")), "⑨ %s 打完 → `主武器已销毁 = true`（其余武器灰掉）" % k)
	# ---- 副武器：艾克赛琳的【援护射击】进 `u.副武器栏` ----
	var a2 := _单位Of(c, "A2")
	var 副栏: Array = (a2.get("副武器栏") as Array) if a2.get("副武器栏") is Array else []
	var 有援护 := false
	for e in 副栏:
		if e is Dictionary and e.get("卡") is Dictionary and str((e["卡"] as Dictionary).get("id", "")) == "ATX2_D1":
			有援护 = true
	t.ok(有援护, "⑨ ★ M3：艾克赛琳（A2）的【援护射击】在 `u.副武器栏` 里（%d 条）" % 副栏.size())
	# ---- 武器栏的牌**不进** `专属弃牌堆`（常驻上排）----
	var 弃id: Array = ((a1.get("专属弃牌堆") as Array) if a1.get("专属弃牌堆") is Array else []).map(
		func(x): return str((x as Dictionary).get("id", "")))
	t.ok(not J.inc(弃id, "ATX1_W1"),
		"⑨ ★ M3：武器栏卡打完**不进** `专属弃牌堆`（弃牌堆 %s）" % str(弃id))

# ==========================================================================================
# ⑩ ★ M2 / M4：公有牌池按本队过滤 + 下排公有牌自动匹配对口队友 + 快速测试起手 3 张 + 试玩靶机
# ==========================================================================================
func _段10_公有牌自动匹配与靶机(t) -> void:
	# ---- M2-① 公有牌池按本队过滤（秘银五人没有重装 → 一张重装牌都不该在池里）----
	var s := _秘银快速战()
	if s == null:
		t.ok(false, "⑩ 秘银五人快速测试战开不起来")
		return
	var c: Dictionary = s.battle_ctx
	var 池: Array = J.concat(J.or_(c.get("公有牌库"), []), J.or_(c.get("公有待入库"), []))
	池 = J.concat(池, J.or_(c.get("公有手牌"), []))
	var 重装数 := 0
	var 秘银势力 := 0
	var 旧版 := 0
	var 有统帅 := false
	for x in 池:
		if not (x is Dictionary):
			continue
		var d: Dictionary = x
		var 归 := str(d.get("归属", ""))
		var id := str(d.get("id", ""))
		if 归 == "重装":
			重装数 += 1
		if str(d.get("层级", "")) == "势力" and 归 == "秘银":
			秘银势力 += 1
		if id.begins_with("C_") or id.begins_with("F_MITH_") or id.begins_with("F_ATX_"):
			旧版 += 1
		if str(d.get("层级", "")) == "统帅":
			有统帅 = true
	t.ok(重装数 == 0, "⑩ ★ M2：秘银五人（无重装）的公有牌池里**一张【重装】牌都没有**（%d 张）" % 重装数)
	t.ok(秘银势力 >= 1, "⑩ ★ M2：新版秘银势力牌仍在池里（%d 张）" % 秘银势力)
	t.ok(旧版 == 0, "⑩ ★ M2：旧版 M3 占位职业 / 势力牌整批退场（%d 张）" % 旧版)
	t.ok(有统帅, "⑩ ★ M2：统帅牌仍然保留（只滤职业 / 势力）")
	# ---- M2-② 下排公有牌自动匹配对口队友：选中狙击（克鲁兹），塞一张【尖兵】分类牌 → 由杨发动 ----
	var 尖兵牌 = Btl.克隆战术牌(ClassCards.卡("CC_S1"), c)
	(c["公有手牌"] as Array).append(尖兵牌)
	s.select_battle_unit("U6")
	var 行 := _下排行Of(s, "CC_S1")
	t.ok(not 行.is_empty() and bool(行.get("对口", true)) == false,
		"⑩ ★ M2：选中的狙击对【尖兵】牌 `对口 = false`（选中的这台确实不对口）")
	t.ok(not 行.is_empty() and bool(行.get("可打", false)) and str(行.get("原因", "")).begins_with("〔由 "),
		"⑩ ★★ M2：但队里有尖兵队友 → 照样可打，卡面写「%s」" % str(行.get("原因", "")))
	t.ok(not 行.is_empty() and str(行.get("发动键", "")) == "U8",
		"⑩ ★ M2：发动者 = 杨（U8），实际发动键 = %s" % str(行.get("发动键", "")))
	var 杨 := _单位Of(c, "U8")
	var 战意前 := float(Btl.战意(杨))
	var r := s.play_unit_spirit_or_public_card(str(行.get("手牌键", "")), _第一台活敌键(c))
	t.ok(bool(r.get("ok", false)), "⑩ ★★ M2：点下去真的打出来了（%s）" % str(r.get("为什么", "ok")))
	t.ok(str(r.get("单位", "")) == "U8" and s.selected_unit_id == "U8",
		"⑩ ★ M2：自动换到杨（U8）发动，`selected_unit_id` 同步过去（%s）" % s.selected_unit_id)
	t.ok(absf(float(Btl.战意(杨)) - (战意前 - 5.0)) < 0.001,
		"⑩ ★ M2：扣的是**发动者**的战意（%.0f → %.0f，这张费 5）" % [战意前, float(Btl.战意(杨))])
	# 把对口队友的战意扣光 → 全队没人打得起 → 置灰
	(c["公有手牌"] as Array).append(Btl.克隆战术牌(ClassCards.卡("CC_S2"), c))
	杨["战意"] = 0.0
	var 行2 := _下排行Of(s, "CC_S2")
	t.ok(not 行2.is_empty() and bool(行2.get("可打", false)) == false,
		"⑩ ★ M2：对口队友战意扣光 → 【尖兵】牌置灰（%s）" % str(行2.get("原因", "")))
	t.ok(not 行2.is_empty() and str(行2.get("原因", "")) == "战意不足",
		"⑩ ★ M2：置灰原因 =「%s」（选中那台若不对口才回落成〔需：尖兵〕）" % str(行2.get("原因", "")))
	# ---- M4：快速测试局 = 起手 3 张公有牌 + 高耐久低攻试玩靶机 ----
	var sa := _快速战()
	if sa == null:
		t.ok(false, "⑩ ATX 五人快速测试战开不起来")
		return
	var ca: Dictionary = sa.battle_ctx
	t.ok((ca.get("公有手牌") as Array).size() == 3,
		"⑩ ★ M2：【快速测试局】公有手牌**起手 3 张**（%d/6，不再补满）" % (ca.get("公有手牌") as Array).size())
	t.ok((ca.get("波次") as Array).is_empty(), "⑩ ★ M4：`ctx.波次` 清空（靶机开场同台，不靠波次拖节奏）")
	var 血对 := true
	var 攻对 := true
	var 武对 := true
	var 名对 := true
	var 台数 := 0
	for e in (ca.get("enemies") as Array):
		if not (e is Dictionary):
			continue
		var u: Dictionary = e
		台数 += 1
		if not str(u.get("name", "")).ends_with("·靶机"):
			名对 = false
		var 期望 := 20000
		if Fm.rowOfSlot(float(u.get("slot", 0.0))) == Fm.ROW_FRONT:
			期望 = 32000 if str(u.get("mech", "")).contains("重") else 28000
		if int(float(u.get("hp", 0.0))) != 期望 or int(float(u.get("maxHp", 0.0))) != 期望:
			血对 = false
		if int(float(u.get("melee", 0.0))) != 35 or int(float(u.get("shoot", 0.0))) != 35:
			攻对 = false
		for 条 in ((u.get("weapons") as Array) if u.get("weapons") is Array else []):
			if not (条 is Dictionary) or not ((条 as Dictionary).get("t") is Dictionary):
				continue
			var 力 := float((条 as Dictionary).t.get("power", 0.0))
			if 力 < 200.0 or 力 > 1400.0:
				武对 = false
	t.ok(台数 >= 5, "⑩ ★ M4：开场同台 %d 台靶机" % 台数)
	t.ok(名对, "⑩ ★ M4：每台敌机名字后缀「·靶机」")
	t.ok(血对, "⑩ ★ M4：前排靶机 28000 / 重机 32000 / 后排 20000（`hp == maxHp`）")
	t.ok(攻对, "⑩ ★ M4：每台靶机 `melee = shoot = 35`")
	t.ok(武对, "⑩ ★ M4：武器威力缩到 35%（保底 200，最高 ≤ 1400 —— 重型坦克的穿甲主炮 3600 → 1260）")

## `lower_hand_cards()` 里 `id == 牌id` 的那一行（没有 = 空字典）。
func _下排行Of(s: GameSession, 牌id: String) -> Dictionary:
	for x in s.lower_hand_cards():
		if x is Dictionary and str((x as Dictionary).get("id", "")) == 牌id:
			return x
	return {}

## 第一台存活敌机的键（没有 = 空串）。
func _第一台活敌键(c: Dictionary) -> String:
	for e in J.or_(c.get("enemies"), []):
		if e is Dictionary and float((e as Dictionary).get("hp", 0.0)) > 0.0:
			return str((e as Dictionary).get("key", ""))
	return ""

# ==========================================================================================
# 小工具
# ==========================================================================================
func _快速战() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_wiring_战斗.json"
	if not s.开始快速测试战斗(GameSession.快速测试_ATX, 种子):
		return null
	return s

## 秘银五人的快速测试战（M1 / M2 那两段用）。
func _秘银快速战() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_wiring_秘银战斗.json"
	if not s.开始快速测试战斗(GameSession.快速测试_秘银, 种子):
		return null
	return s

func _单位Of(c: Dictionary, 键: String) -> Dictionary:
	for u in J.or_(c.get("allies"), []):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

## 一台裸 ATX 单位（单机牌组 + 卡牌流转要的字段一次给齐）。
func _裸单位(键: String, 位: float) -> Dictionary:
	var 名 := str({"A1": "响介", "A2": "艾克赛琳", "A3": "拉米亚"}.get(键, 键))
	return {
		"key": 键, "name": 名, "side": "ally", "slot": 位, "lv": 10.0,
		"maxHp": 999999.0, "hp": 999999.0,
		"melee": 200.0, "shoot": 200.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": 0.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"势力": "ATX"}, "weapons": [],
		"战意": 0.0, "战意上限": 100.0, "主武器已销毁": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
		"闪": false, "v3计数": {},
	}

func _裸场() -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": [], "enemies": [], "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "阶段": "PLAYER_MAIN", "again": [],
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [],
		"筹码牌库": [], "移出牌": [], "上张打出牌": null,
		"选项": {"单机牌组": true, "卡牌流转": true},
	}
