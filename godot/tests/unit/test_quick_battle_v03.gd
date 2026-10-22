## ★ A7 收官批验收：「快速测试战斗」双入口（秘银五人 Lv30 / ATX 五人 Lv30）+ 筹码牌库 UI 展示 +
## 统一再动断路器 3 + `set_meta` 警告清理 + 敌方多段武器在「装甲共享池」下的平衡性抽查。
##
## 权威依据：`协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A7 行、§2.1（装甲池）、§5（红线）。
##
## 分段：
##   ① 双入口：`开始快速测试战斗("秘银")` / `("ATX")` 都能**一键开战**，且自己把单机牌组 + 卡牌流转打开
##   ② 秘银五人：Lv30 / 站位 / 连携牌库 4 张一级牌
##   ③ ATX 五人：站位（艾克赛琳在塔斯克正后方同列）/ 筹码牌库 4 张小筹码 / 公有手牌起手 3 张 /
##      各台上排非空 / 主武器·副武器·大招 / 关键牌在位
##   ④ 打牌与推回合：主武器 / 副武器（烟雾弹）/ 精神牌 各打一张 + 「结束我方回合」
##   ⑤ 统一再动断路器 3：W17·中继 → 大满贯，同一台同一回合第二次必被拦
##   ⑥ 筹码牌库 UI 展示：门面 `chip_library_state()` + `unit_card.gd` 的 闪 / 雾 / 赌神 三个标
##   ⑦ 敌方多段武器 × 装甲共享池：`hits >= 2` 的敌方模板盘点 + 旧公式 / 新公式单发对照（只测不改）
extends RefCounted

const 种子 := 20261013
## 敌方模板里 `hits >= 2` 的两把武器（`data/js/10-数据.json` 的 `ENEMY_T.funnel`，
## 另有 `data/js/71-改动-4-战斗结构.json` 把它改成「浮游炮·齐射 900×5 · 开场冷却 3 / 冷却 5」）。
const 浮游炮 := {"名": "浮游炮", "威力": 392.0, "段数": 3}
const 浮游炮齐射 := {"名": "浮游炮·齐射", "威力": 900.0, "段数": 5}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段2_双入口(t)
	_段3_秘银五人(t)
	_段4_ATX五人站位与装填(t)
	_段5_打牌与推回合(t)
	_段6_统一再动断路器(t)
	_段7_UI展示(t)
	_段8_装甲池对照(t)

# ==========================================================================================
# 小工具
# ==========================================================================================
func _会话() -> GameSession:
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_a7_快速战斗.json"
	return s

func _单位(c: Dictionary, 键: String) -> Dictionary:
	for u in (c.get("allies") as Array):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

func _上排(s: GameSession, 键: String) -> Array:
	return s.upper_hand_cards(键)

func _有区(上排: Array, 区: String) -> Array:
	return 上排.filter(func(x): return str(x.get("区", "")) == 区)

func _有牌(上排: Array, 名: String) -> bool:
	for x in 上排:
		if x is Dictionary and str(x.get("名", "")) == 名:
			return true
	return false

func _段串(记录: Array) -> String:
	return "\n".join(记录.map(func(x): return str(x)))

# ==========================================================================================
# ② 双入口都能一键开战，且自己把「单机牌组 + 卡牌流转」打开
# ==========================================================================================
func _段2_双入口(t) -> void:
	var 秘 := _会话()
	t.ok(秘.开始快速测试战斗(GameSession.快速测试_秘银, 种子), "② 一键开战：`开始快速测试战斗(\"秘银\")` 成功")
	var c1 := 秘.battle_ctx
	t.ok(秘.screen == "battle" and not c1.is_empty(), "② 秘银入口直接进战斗屏（screen = %s）" % 秘.screen)
	t.ok(str(秘.action_history[秘.action_history.size() - 1].get("action", "")) == "start_quick_test_battle",
		"② 实时监视：`live_actions.jsonl` 里记的是 `start_quick_test_battle`（args 阵容 = 秘银）")
	var atx := _会话()
	t.ok(atx.开始快速测试战斗("ATX", 种子), "② 一键开战：`开始快速测试战斗(\"ATX\")` 成功")
	var c2 := atx.battle_ctx
	t.ok(atx.screen == "battle" and not c2.is_empty(), "② ATX 入口直接进战斗屏（screen = %s）" % atx.screen)
	t.ok(str(atx.last.get("阵容", "")) == GameSession.快速测试_ATX,
		"② ATX 入口的 `last.阵容` = %s" % str(atx.last.get("阵容", "")))
	# 大小写 / 空格都能认（`atx` / ` ATX `）
	var 别名 := _会话()
	t.ok(别名.开始快速测试战斗(" atx ", 种子 + 1), "② 阵容名大小写 / 空格不敏感（\" atx \" 也开 ATX 五人）")
	t.ok(str(别名.last.get("阵容", "")) == GameSession.快速测试_ATX, "② 归一化后 `last.阵容` = ATX")

# ==========================================================================================
# ③ 秘银五人：Lv30 / 站位 / 连携牌库 4 张一级牌
# ==========================================================================================
func _段3_秘银五人(t) -> void:
	var s := _会话()
	t.ok(s.开始快速测试战斗(GameSession.快速测试_秘银, 种子), "③ 秘银五人测试战开得起来")
	var c := s.battle_ctx
	var 键们: Array = (c.get("allies") as Array).map(func(u): return str((u as Dictionary).get("key", "")))
	t.ok(键们 == ["U7", "U1", "U6", "U2", "U8"],
		"③ 秘银五人 = 宗介 / 毛 / 克鲁佐 / 库尔茨 / 泰莎（实际 %s）" % str(键们))
	var 位们: Array = (c.get("allies") as Array).map(func(u): return int(float((u as Dictionary).get("slot", -1))))
	t.ok(位们 == [0, 1, 5, 6, 7], "③ 站位与设计稿一致（位 %s）" % str(位们))
	var 全30 := true
	for u in c.allies:
		if int(float((u as Dictionary).get("lv", 0.0))) != 30:
			全30 = false
	t.ok(全30, "③ 全员 Lv30（剧情 + 肉鸽池全解锁）")
	t.ok((c.get("连携牌库") as Array).size() == 4,
		"③ `ctx.连携牌库` 初始化 4 张一级牌（%d）" % (c.get("连携牌库") as Array).size())

# ==========================================================================================
# ④ ATX 五人：站位 / 筹码牌库 / 公有手牌 / 装填
# ==========================================================================================
func _段4_ATX五人站位与装填(t) -> void:
	var s := _会话()
	t.ok(s.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "④ ATX 五人测试战开得起来")
	var c := s.battle_ctx
	# ---- 站位：前排 A1 / A6，后排 A3 / A7 / A2（A2 在 A6 正后方同列）----
	var a1 := _单位(c, "A1")
	var a2 := _单位(c, "A2")
	var a3 := _单位(c, "A3")
	var a6 := _单位(c, "A6")
	var a7 := _单位(c, "A7")
	t.ok(not a1.is_empty() and not a2.is_empty() and not a3.is_empty() and not a6.is_empty() and not a7.is_empty(),
		"④ 五个人都在场：响介 A1 / 艾克赛琳 A2 / 拉米亚 A3 / 塔斯克 A6 / 雷欧娜 A7")
	t.ok(int(a1.slot) == 0 and int(a6.slot) == 3,
		"④ 前排 = 响介（位 %d）+ 塔斯克（位 %d）" % [int(a1.slot), int(a6.slot)])
	t.ok(int(a3.slot) == 4 and int(a7.slot) == 5 and int(a2.slot) == 7,
		"④ 后排 = 拉米亚（位 %d）/ 雷欧娜（位 %d）/ 艾克赛琳（位 %d）" % [int(a3.slot), int(a7.slot), int(a2.slot)])
	t.ok(Fm.rowOfSlot(float(a2.slot)) == Fm.ROW_BACK and Fm.rowOfSlot(float(a6.slot)) == Fm.ROW_FRONT
		and Fm.colOfSlot(float(a2.slot)) == Fm.colOfSlot(float(a6.slot)) and Fm.另一排同位(float(a2.slot)) == int(a6.slot),
		"★ ④ 艾克赛琳（位 %d）站在塔斯克（位 %d）**正后方同列** —— 列 %d" % [
			int(a2.slot), int(a6.slot), int(Fm.colOfSlot(float(a2.slot)))])
	t.ok(str((AtxDuo.正后方队友(c, a2) as Dictionary).get("key", "")) == "A6",
		"★ ④ 内核的【掩护】判据 `AtxDuo.正后方队友(A2)` 真的指回塔斯克")
	var 全30 := true
	for u in c.allies:
		if int(float((u as Dictionary).get("lv", 0.0))) != 30:
			全30 = false
	t.ok(全30, "④ 全员 Lv30")
	# ---- 筹码牌库：开场 4 张小筹码 ----
	var 库: Array = c.get("筹码牌库")
	t.ok(库 is Array and 库.size() == 4, "④ `ctx.筹码牌库` 开场 4 张（%d）" % (库 as Array).size())
	var 全小 := true
	for x in 库:
		if not (x is Dictionary) or AtxChips.等级(x) != 1:
			全小 = false
	t.ok(全小, "④ 4 张全是**小筹码**（等级 1；大筹码 / 头奖不入场）")
	# ---- 公有手牌起手 3 张（★ M2：不再补抽到 6/6 —— 留 3 个空位给「呼叫达纳号」与〔连携〕抽牌）----
	# ★ M4：敌机已换成「高耐久、低攻击」试玩靶机（这一段的其余断言不受影响）
	t.ok((c.get("公有手牌") as Array).size() == 3,
		"④ 公有手牌**起手 3 张**（%d/6；M2 起不再补满，给〔连携〕抽牌留空位）" % (c.get("公有手牌") as Array).size())
	# ---- 每台上排非空 + 五区齐备 ----
	var 空台: Array = []
	var 主武 := 0
	var 副武 := 0
	var 大招 := 0
	var 精神 := 0
	for u in c.allies:
		var k := str((u as Dictionary).get("key", ""))
		var 上 := _上排(s, k)
		if 上.is_empty():
			空台.append(k)
		主武 += _有区(上, "主武器卡").size()
		副武 += _有区(上, "副武器卡").size()
		大招 += _有区(上, "大招槽卡").size()
		精神 += _有区(上, "专属精神牌").size()
	t.ok(空台.is_empty(), "④ 五台上排**全非空**（空的是 %s）" % str(空台))
	t.ok(主武 >= 3, "④ 主武器卡共 %d 张（塔斯克 / 雷欧娜的 6 张单机武器 + 响介/艾克赛琳的合体技）" % 主武)
	t.ok(副武 >= 1, "④ 副武器卡共 %d 张（拉米亚的烟雾弹）" % 副武)
	t.ok(大招 >= 3, "④ 大招槽卡共 %d 张" % 大招)
	t.ok(精神 >= 3, "④ 专属精神牌共 %d 张" % 精神)
	# ---- 关键牌在位 ----
	var 全上: Array = []
	for u in c.allies:
		全上.append_array(_上排(s, str((u as Dictionary).get("key", ""))))
	t.ok(_有牌(全上, "赌神·入局"), "④ 大招槽里有【赌神·入局】（响介）")
	t.ok(_有牌(全上, "千兆宽域爆破"), "④ 大招槽里有【千兆宽域爆破】（塔斯克）")
	t.ok(_有牌(全上, "T-Link 突击"), "④ 大招槽里有【T-Link 突击】（雷欧娜）")
	t.ok(_有牌(全上, "轮盘双响"), "④ 有【轮盘双响】（响介 / 艾克赛琳的合体技）")
	t.ok(_有牌(全上, "援护射击"), "④ 艾克赛琳有【援护射击】（副武器 / 衍生）")
	t.ok(_有牌(全上, "烟雾弹"), "④ 拉米亚有【烟雾弹】（副武器，冷却 3）")
	# ---- 公有排：ATX v0.3 势力牌 + 近卫/尖兵/重装分类牌 ----
	var 下: Array = s.lower_hand_cards("A1")
	var 公有库: Array = c.get("公有牌库")
	var 有分类 := 0
	var 有势力 := 0
	for x in 公有库:
		if not (x is Dictionary):
			continue
		if ["近卫", "尖兵", "重装"].has(str((x as Dictionary).get("归属", ""))):
			有分类 += 1
		if str((x as Dictionary).get("归属", "")) == "ATX":
			有势力 += 1
	t.ok(有分类 >= 3, "④ 公有牌库里带**近卫 / 尖兵 / 重装**分类牌（%d 张）" % 有分类)
	t.ok(有势力 >= 3, "④ 公有牌库里带 **ATX v0.3 势力牌**（%d 张）" % 有势力)
	t.ok(下.size() == (c.get("公有手牌") as Array).size(),
		"④ 下排画出的张数 = 公有手牌张数（%d）" % 下.size())

# ==========================================================================================
# ⑤ 打牌 + 推回合：主武器 / 副武器 / 精神牌 各一张，再「结束我方回合」
# ==========================================================================================
func _段5_打牌与推回合(t) -> void:
	var s := _会话()
	t.ok(s.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "⑤ ATX 五人测试战开得起来")
	var c := s.battle_ctx
	var 敌 := ""
	for e in c.enemies:
		if e is Dictionary and float((e as Dictionary).get("hp", 0.0)) > 0.0:
			敌 = str((e as Dictionary).get("key", ""))
			break
	t.ok(not 敌.is_empty(), "⑤ 找得到一台活着的敌机（%s）" % 敌)
	# ---- 主武器：全队里第一张**真的打得出去**的主武器卡（够不着 / 距离不符的跳过）----
	#   ★ 第 5 项修复后 ATX 五人是「全卡池体验」（Lv30 抓到 4 把主武器），
	#     第一张「可打」未必够得着目标 → 逐张试，第一张成功的算数。
	var 主: Dictionary = {}
	var 主台 := ""
	var r主 := {}
	for u in c.allies:
		var k := str((u as Dictionary).get("key", ""))
		for x in _有区(_上排(s, k), "主武器卡"):
			if not bool((x as Dictionary).get("可打", false)):
				continue
			var 试 := s.play_unit_main_weapon(str((x as Dictionary).get("手牌键", "")), 敌, k)
			if bool(试.get("ok", false)):
				主 = x
				主台 = k
				r主 = 试
				break
		if not 主.is_empty():
			break
	t.ok(not 主.is_empty(), "⑤ 有一张「可打」的主武器卡（%s 的【%s】）" % [主台, str(主.get("名", ""))])
	if not 主.is_empty():
		t.ok(bool(r主.get("ok", false)), "⑤ 打出一张主武器卡：%s" % str(r主.get("牌", r主.get("为什么", ""))))
		t.ok(bool(_单位(c, 主台).get("主武器已销毁", false)), "⑤ 主武器打完 → `主武器已销毁 = true`（本回合其余武器灰掉）")
	# ---- 副武器：拉米亚的烟雾弹 ----
	var 副 := _有区(_上排(s, "A3"), "副武器卡")
	t.ok(not 副.is_empty(), "⑤ 拉米亚上排有副武器卡（%s）" % str(副.map(func(x): return str(x.get("名")))))
	if not 副.is_empty():
		var r2 := s.play_unit_sub_weapon(str((副[0] as Dictionary).get("手牌键", "")), 敌, "A3")
		t.ok(bool(r2.get("ok", false)) and not bool(_单位(c, "A3").get("主武器已销毁", true)),
			"⑤ 打出副武器【%s】成功，且**不销毁主武器**" % str((副[0] as Dictionary).get("名", "")))
	# ---- 精神牌：雷欧娜的【冷静判断】----
	var 精 := _有区(_上排(s, "A7"), "专属精神牌")
	t.ok(not 精.is_empty(), "⑤ 雷欧娜上排有专属精神牌")
	if not 精.is_empty():
		var r3 := s.play_unit_spirit_or_public_card(str((精[0] as Dictionary).get("手牌键", "")), "", "A7")
		t.ok(bool(r3.get("ok", false)), "⑤ 打出一张专属精神牌【%s】" % str((精[0] as Dictionary).get("名", "")))
	# ---- 推回合：1 → 2 ----
	# ★ M4：敌机已经换成「高耐久·低攻击」试玩靶机，AI 的索敌口径（`targetScore` 的击杀判定）随之变成
	#   「按伤害比挑最脆的」—— 默认满血时它会去啃前排，【掩护】接管就看不到。这里把艾克赛琳压到 10% HP
	#   还原「敌人想打塔斯克正后方那台」的局面（靶机每击只有十几点伤害，不会真的把人打死）。
	var 艾 := _单位(c, "A2")
	if not 艾.is_empty():
		艾["hp"] = maxf(1.0, float(艾.get("maxHp", 1.0)) * 0.1)
	Btl.刷新敌方意图(c)
	var 前回合 := int(float(c.get("turn", 0.0)))
	var r4 := s.end_player_turn()
	t.ok(bool(r4.get("ok", false)) and int(float(c.get("turn", 0.0))) == 前回合 + 1,
		"⑤ 「结束我方回合」把回合从 %d 推到 %d（阶段 = %s）" % [前回合, int(float(c.get("turn", 0.0))),
			str(c.get("阶段", ""))])
	t.ok(int(r4.get("新日志", 0)) > 0, "⑤ 敌方阶段真的跑了（新增 %d 条战斗记录）" % int(r4.get("新日志", 0)))
	# ★ 掩护在真实回合里的即时反馈（三层反馈的「即时」那一层）
	var 有掩护 := false
	for x in (c.get("log") as Array):
		if str(x).contains("〔援护防御〕"):
			有掩护 = true
			break
	t.ok(有掩护, "★ ⑤ 第 1 个敌方阶段里出现了〔援护防御〕记录（塔斯克替正后方的艾克赛琳接了一击，写明剩余次数）")

# ==========================================================================================
# ⑥ 统一再动断路器 3：W17·中继（精神牌系）→ 大满贯（筹码牌系），同一台同一回合第二次被拦
# ==========================================================================================
func _段6_统一再动断路器(t) -> void:
	var s := _会话()
	t.ok(s.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "⑥ 开一场 ATX 五人测试战")
	var c := s.battle_ctx
	var a6 := _单位(c, "A6")
	t.ok(not a6.is_empty(), "⑥ 塔斯克在场")
	# ---- 第一把：精神牌系（W17·中继）→ 成功 ----
	a6["本回合再动已用"] = false
	a6["主武器已销毁"] = true
	t.ok(DeckFlow.再动(c, a6, "W17·中继"), "⑥ 第一次再动（来源 = W17·中继）：成功")
	t.ok(not bool(a6.get("主武器已销毁", true)) and bool(a6.get("本回合再动已用", false)),
		"⑥ 第一次后：`主武器已销毁 = false`、`本回合再动已用 = true`")
	# ---- 第二把：筹码牌系（大满贯）→ 必被拦 ----
	a6["主武器已销毁"] = true
	var 大满贯 := AtxChips.卡("ATX_CHIP_SLAM")
	(c.get("公有手牌") as Array).append(大满贯)
	var 拦前 := (c.get("log") as Array).size()
	var r := AtxChips.打出筹码牌(c, "A1", "ATX_CHIP_SLAM")
	t.ok(bool(r.get("成功", false)), "⑥ 【大满贯】本身打得出来（打出者是响介，塔斯克只是目标之一）")
	t.ok(bool(a6.get("主武器已销毁", false)),
		"★ ⑥ 塔斯克的主武器**没有被恢复**（`主武器已销毁` 仍是 true）—— 大满贯绕不过断路器 3")
	var 新行: Array = (c.get("log") as Array).slice(拦前)
	var 断言行 := 新行.filter(func(x): return x is Dictionary and str((x as Dictionary).get("类型", "")) == "再动" \
		and bool((x as Dictionary).get("断路器", false)))
	t.ok(not 断言行.is_empty(), "★ ⑥ 记录里明写「断路器 3」（新增里共 %d 条）" % 断言行.size())
	t.ok((c.get("筹码牌库") as Array).size() == 4,
		"⑥ 头奖【大满贯】打完**移出本场**，筹码牌库仍是 4 张（%d）" % (c.get("筹码牌库") as Array).size())
	# ---- 闸门放宽的另一半：单机牌组 ctx 生效 ----
	var 单开 := {"单机牌组": true}
	var 靶 := {"key": "T1", "name": "靶", "side": "ally", "slot": 0, "hp": 100.0, "maxHp": 100.0,
		"本回合再动已用": false, "主武器已销毁": true}
	单开["allies"] = [靶]
	单开["enemies"] = []
	单开["log"] = []
	单开["turn"] = 1.0
	t.ok(DeckFlow.再动(单开, 靶), "★ ⑥ `DeckFlow.再动` 生效")
	t.ok(not DeckFlow.再动(单开, 靶), "⑥ 同一台第二次仍被拦（同一个 `本回合再动已用`）")
	# ---- ★ CB-0 断路器 3 的另一半：**近卫连续攻击** 与 **再动** 是同一把锁 ----
	var 连 := {"key": "T2", "name": "连", "side": "ally", "slot": 0, "hp": 100.0, "maxHp": 100.0,
		"本回合再动已用": false, "连续攻击已用": false, "主武器已销毁": true, "武器栏": []}
	var 单开2 := {"单机牌组": true, "allies": [连], "enemies": [], "log": [], "turn": 1.0}
	t.ok(Btl.连续攻击可用(连, 单开2), "⑥ 前置：连续攻击额度还没用")
	Btl.连续攻击记(连, 单开2)
	t.ok(J.truthy(连.get("连续攻击已用")) and J.truthy(连.get("本回合再动已用")),
		"★ ⑥ 触发一次【连续攻击】→ `连续攻击已用` 与 `本回合再动已用` **两个字段一起置真**")
	连["主武器已销毁"] = true
	t.ok(not DeckFlow.再动(单开2, 连),
		"★ ⑥ 同一回合紧接着再动 → **被同一把锁拦下**（`连续攻击已用` 也算数）")
	t.ok(not Btl.连续攻击可用(连, 单开2), "⑥ 反过来：再动之后连续攻击额度也没了")
	# ---- ★ CB-0 断路器 3 的注意项：**出鞘的剑牌绝不恢复** ----
	var 剑 := {"key": "T3", "name": "剑", "side": "ally", "slot": 0, "hp": 100.0, "maxHp": 100.0,
		"本回合再动已用": false, "连续攻击已用": false, "主武器已销毁": true,
		"武器栏": [{"id": "W_SHEATH", "名": "出鞘的剑", "出鞘": true},
			{"id": "W_NORMAL", "名": "普通炮", "出鞘": false}]}
	var 单开3 := {"单机牌组": true, "allies": [剑], "enemies": [], "log": [], "turn": 1.0}
	t.ok(DeckFlow.再动(单开3, 剑), "⑥ 再动成功（主武器栏里一把出鞘的剑 + 一把普通炮）")
	var 栏: Array = 剑["武器栏"]
	t.ok(J.truthy((栏[0] as Dictionary).get("已收纳")) and not J.truthy((栏[1] as Dictionary).get("已收纳")),
		"★ ⑥ **出鞘的剑牌绝不恢复**（`已收纳` %s）、普通炮正常恢复（`已收纳` %s）" % [
			str((栏[0] as Dictionary).get("已收纳")), str((栏[1] as Dictionary).get("已收纳"))])
	t.ok(not J.truthy(剑.get("主武器已销毁")), "⑥ 有可恢复的普通武器 → `主武器已销毁 = false`")
	# 全是出鞘的剑 → 一张都恢复不了，「主武器已销毁」必须保持 true
	var 全剑 := {"key": "T4", "name": "全剑", "side": "ally", "slot": 0, "hp": 100.0, "maxHp": 100.0,
		"本回合再动已用": false, "连续攻击已用": false, "主武器已销毁": true,
		"武器栏": [{"id": "W_S1", "名": "剑一", "出鞘": true}, {"id": "W_S2", "名": "剑二", "出鞘": true}]}
	var 单开4 := {"单机牌组": true, "allies": [全剑], "enemies": [], "log": [], "turn": 1.0}
	DeckFlow.再动(单开4, 全剑)
	t.ok(J.truthy(全剑.get("主武器已销毁")),
		"★ ⑥ 武器栏**全是出鞘的剑** → 一张都不恢复，`主武器已销毁` 仍是 %s" % str(全剑.get("主武器已销毁")))
	t.ok(_日志含(单开4, "出鞘"), "⑥ 记录里写清了「出鞘中的…绝不恢复」：%s" % str(_日志行们(单开4)))

## 一组日志文本（`ctx.log` 里的 `文本`）。
func _日志行们(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			out.append(str((e as Dictionary).get("文本", "")))
	return out

func _日志含(c: Dictionary, 子串: String) -> bool:
	for 行 in _日志行们(c):
		if str(行).contains(子串):
			return true
	return false

# ==========================================================================================
# ⑦ UI 展示：筹码牌库徽章 + 单位卡的 闪 / 雾 / 赌神 三个标
# ==========================================================================================
func _段7_UI展示(t) -> void:
	var s := _会话()
	t.ok(s.开始快速测试战斗(GameSession.快速测试_ATX, 种子), "⑦ 开一场 ATX 五人测试战")
	var 筹 := s.chip_library_state()
	t.ok(bool(筹.get("启用", false)), "⑦ 门面 `chip_library_state().启用` = true（场上有 ATX 成员）")
	t.ok(int(筹.get("小", 0)) == 4 and int(筹.get("大", 0)) == 0 and int(筹.get("头奖", 0)) == 0,
		"⑦ 张数：小 %d / 大 %d / 头奖 %d" % [int(筹.get("小", 0)), int(筹.get("大", 0)), int(筹.get("头奖", 0))])
	t.ok(str(筹.get("文案", "")) == "筹码 4（小4/大0/头奖0）",
		"★ ⑦ 文案口径「筹码 N（小a/大b/头奖c）」：%s" % str(筹.get("文案", "")))
	t.ok(str(筹.get("悬停", "")).contains("一枚硬币"), "⑦ 悬停明细里列出库内卡牌：%s" % str(筹.get("悬停", "")))
	# 秘银那一场不该画筹码角标（张数 0 且没有 ATX 成员 → 启用 = false）
	var 秘 := _会话()
	秘.开始快速测试战斗(GameSession.快速测试_秘银, 种子)
	t.ok(not bool(秘.chip_library_state().get("启用", true)),
		"⑦ 秘银五人那一场**不画**筹码角标（`启用` = false），连携牌库角标照旧")
	t.ok(int(秘.link_library_state().get("一级", 0)) == 4, "⑦ 秘银那一场的连携牌库角标仍是 4 张一级牌")
	# ---- 单位卡：把三个标记注进真实快照，再走一遍 `UnitCard` 的渲染 ----
	var d := s.unit_view("ally", "A2")
	t.ok(bool(d.get("ok", false)), "⑦ 拿到艾克赛琳的真实单位快照")
	var 卡 := UnitCard.new()
	卡.setup(d)
	t.ok(卡._闪标 != null and 卡._雾标 != null and 卡._赌神标 != null,
		"⑦ `UnitCard` 上三个标记节点都在：闪标 / 雾标 / 赌神标")
	t.ok(not 卡._闪标.visible and not 卡._雾标.visible and not 卡._赌神标.visible,
		"⑦ 三个标记默认都**藏着**（快照里没有对应的键 → 一个标都不亮）")
	卡.free()
	d["闪"] = true
	d["雾"] = true
	d["赌神"] = true
	var 卡2 := UnitCard.new()
	卡2.setup(d)
	t.ok(卡2._闪标.visible and 卡2._雾标.visible and 卡2._赌神标.visible,
		"★ ⑦ 快照带 `闪 / 雾 / 赌神` 时三个标记**真的画出来**（闪=%s 雾=%s 赌神=%s）" % [
			str(卡2._闪标.visible), str(卡2._雾标.visible), str(卡2._赌神标.visible)])
	卡2.free()
	# ---- 源码级：菜单上两个按钮都在 ----
	var 源 := ""
	var f := FileAccess.open("res://presentation/menus/menu_view.gd", FileAccess.READ)
	if f != null:
		源 = f.get_as_text()
		f.close()
	t.ok(源.contains("快速测试：秘银五人") and 源.contains("快速测试：ATX 五人"),
		"★ ⑦ 主菜单上挂着两个按钮：「快速测试：秘银五人」/「快速测试：ATX 五人」")
	t.ok(源.contains("快速测试_秘银") and 源.contains("快速测试_ATX") and 源.contains("开始快速测试战斗"),
		"⑦ 两个按钮都调门面的 `开始快速测试战斗(阵容)`")

# ==========================================================================================
# ⑧ 敌方多段武器 × 装甲共享池：只测量、不改数值
# ==========================================================================================
func _段8_装甲池对照(t) -> void:
	# ---- 盘点：敌方模板（`ENEMY_T` 29 台）里 `hits >= 2` 的武器只有 `funnel` 那两把 ----
	var 多段: Array = []
	for k in (Db.T.ENEMY_T as Dictionary).keys():
		var tpl: Variant = (Db.T.ENEMY_T as Dictionary).get(k)
		if not (tpl is Dictionary):
			continue
		for w in ((tpl as Dictionary).get("weapons") if (tpl as Dictionary).get("weapons") is Array else []):
			if w is Dictionary and float((w as Dictionary).get("hits", 1.0)) >= 2.0:
				多段.append({"键": str(k), "武器": str((w as Dictionary).get("name", "")),
					"威力": float((w as Dictionary).get("power", 0.0)),
					"段数": int(float((w as Dictionary).get("hits", 1.0)))})
	t.ok(多段.size() == 2, "⑧ 敌方模板里 `hits >= 2` 的武器共 %d 把（%s）" % [
		多段.size(), str(多段.map(func(x): return "%s·%s %s×%s" % [x["键"], x["武器"], x["威力"], x["段数"]]))])
	# ---- 受控对照：coef == 1（攻方射击 == 守方防御）、defMul == 1、只换武器与装甲 ----
	_对照(t, 浮游炮, 600.0, 30, 586)
	_对照(t, 浮游炮, 1000.0, 30, 196)
	_对照(t, 浮游炮齐射, 600.0, 1500, 3900)
	_对照(t, 浮游炮齐射, 1000.0, 50, 3510)

## 一次受控检验：`装甲共享池`（一次攻击共享一个池）。
func _对照(t, 武: Dictionary, 甲: float, _旧期望: int, 新期望: int) -> void:
	var 新 := _打一发(武, 甲)
	t.ok(新 == 新期望,
		"⑧ %s（%s × %s 段）vs 装甲 %s：装甲共享池 = %s" % [
			武["名"], J.s(武["威力"]), J.s(武["段数"]), J.s(甲), J.s(新)])

## 一发（全段必中、coef == 1、defMul == 1）。攻方射击 = 守方防御 = 0 → `statCoef = 1`。
func _打一发(武: Dictionary, 甲: float) -> int:
	var att := {
		"key": "敌", "name": "敌", "side": "enemy", "slot": 0.0, "lv": 10.0,
		"maxHp": 999999.0, "hp": 999999.0, "melee": 0.0, "shoot": 0.0, "awaken": 0.0,
		"defense": 0.0, "armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0, "buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0, "tags": {}, "weapons": [],
	}
	var def := {
		"key": "我", "name": "我", "side": "ally", "slot": 0.0, "lv": 10.0,
		"maxHp": 999999.0, "hp": 999999.0, "melee": 0.0, "shoot": 0.0, "awaken": 0.0,
		"defense": 0.0, "armor": 甲, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0, "buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0, "tags": {}, "weapons": [],
	}
	var w := {
		"name": str(武["名"]), "fire": "indirect", "dmgType": "光束", "power": float(武["威力"]),
		"hit": 100.0, "stat": "射击", "hits": float(武["段数"]), "cd": 0.0, "upgrades": [],
	}
	var c := {
		"turn": 1.0, "种子": 20261017.0, "rng": Mulberry32.new(20261017),
		"allies": [def], "enemies": [att], "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0,
	}
	var r := Calc.resolveAttack(att, def, w, c, {})
	var 字 = r.get("字段")
	return int(float((字 as Dictionary).get("伤害"))) if 字 is Dictionary else -1
