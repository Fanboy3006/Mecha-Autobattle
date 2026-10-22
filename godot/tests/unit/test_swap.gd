## 换位底座（`BattleSwap`）单元断言：原语 / 合用范围 / 6 项刷新链 / 三步意图规则 / 顶位 / 掩护连线。
## 见 协作/设计/影世界势力卡牌设计 v0.2.md §8（月球王国 v0.2.1 §8 是同一份底座）。
extends RefCounted

const 千 := 50000.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_一_原语与合法性(t)
	_二_移位计数与错位(t)
	_三_意图三步规则(t)
	_四_待机与实战同源(t)
	_五_顶位(t)
	_六_掩护连线跟随(t)
	_七_大招亮起条件刷新(t)
	_八_回合清状态(t)
	_九_与卡牌无关时零影响(t)

# ==========================================================================================
# ① 原语：互换 / 移入空格 / 同格 / 越界 / 空格对空格 / 不认识的方
# ==========================================================================================
func _一_原语与合法性(t) -> void:
	var c := _场([_我(0, "A")], [])
	var b := _我(1, "B")
	(c["allies"] as Array).append(b)
	t.ok(not BattleSwap.合法吗(c, "ally", 0, 0), "① 同一格 → 不合法（swapPos 返回 0 的前提）")
	t.ok(not BattleSwap.合法吗(c, "ally", 0, 8), "① 8 越界 → 不合法（每方只有 8 格，绝不跨阵）")
	t.ok(not BattleSwap.合法吗(c, "ally", 3, 4), "① 两格都是空格 → 不合法")
	t.ok(not BattleSwap.合法吗(c, "neutral", 0, 1), "① 不认识的一方 → 不合法")
	t.ok(BattleSwap.合法吗(c, "ally", 0, 1), "① 两格都有存活单位 → 合法")
	t.ok(BattleSwap.是互换吗(c, "ally", 0, 1), "① 两格都有人 = 互换")
	t.ok(not BattleSwap.是互换吗(c, "ally", 0, 5), "① 一格空 = 移入空格")

	t.ok(BattleSwap.换位(c, "ally", 0, 0) == 0, "① posA == posB → 返回 0（不执行）")
	t.ok(BattleSwap.换位(c, "ally", 3, 4) == 0, "① 两格都空 → 返回 0（不执行）")
	t.ok(BattleSwap.换位(c, "ally", 0, 1) == 2, "① 互换 → 实际改变 2 台")
	t.ok(int(_找(c, "ally", "A").slot) == 1 and int(_找(c, "ally", "B").slot) == 0, "① 互换后 位号 0 ⇄ 1（A→1、B→0）")
	t.ok(BattleSwap.换位(c, "ally", 0, 5) == 1, "① 移入空格 → 实际改变 1 台")
	t.ok(int(_找(c, "ally", "B").slot) == 5, "① 移入空格后 B 在 5（原空格）")
	t.ok(BattleSwap.格上单位(c, "ally", 0) == null, "① 空出来的 0 上没有人")

# ==========================================================================================
# ② 移位计数 / 错位 / 深渊之门
# ==========================================================================================
func _二_移位计数与错位(t) -> void:
	var c := _场([_我(0, "A"), _我(1, "B")], [])
	BattleSwap.换位(c, "ally", 0, 1, {"isShadowCard": false})
	t.ok(J.num0(c.get("turnShiftCount")) == 0.0 and J.num0(c.get("battleShiftCount")) == 0.0,
		"② 非影世界牌（opts 没有 isShadowCard）→ 一次移位都不计")
	t.ok(not BattleSwap.已错位(_找(c, "ally", "A")), "② 非影世界牌 → 不挂〔错位〕")

	BattleSwap.换位(c, "ally", 1, 0, {"isShadowCard": true})
	t.ok(J.num0(c.get("turnShiftCount")) == 2.0, "② 影世界牌互换 → 本回合移位 +2（%d）" % int(J.num0(c.get("turnShiftCount"))))
	t.ok(J.num0(c.get("battleShiftCount")) == 2.0, "② 本场移位同步 +2")
	t.ok(BattleSwap.已错位(_找(c, "ally", "A")) and BattleSwap.已错位(_找(c, "ally", "B")),
		"② 发生位移的两台都挂上〔错位〕")

	BattleSwap.换位(c, "ally", 0, 6, {"isShadowCard": true})
	t.ok(J.num0(c.get("turnShiftCount")) == 3.0, "② 移入空格 → 只 +1（本回合共 %d）" % int(J.num0(c.get("turnShiftCount"))))

	# 深渊之门：移位的敌机各受 700 特殊伤害（每台每回合最多 3 次）
	var c2 := _场([_我(0, "A")], [_敌(0, "E1"), _敌(1, "E2"), _敌(4, "E3")])
	c2["abyssGateActive"] = true
	var hp前 := float(_找(c2, "enemy", "E3").hp)
	BattleSwap.换位(c2, "enemy", 4, 5, {"isShadowCard": true})
	t.ok(is_equal_approx(float(_找(c2, "enemy", "E3").hp), hp前 - 700.0),
		"② 〔深渊之门〕激活时移位的敌机受 700 点特殊伤害（%s → %s）" % [J.s(hp前), J.s(_找(c2, "enemy", "E3").hp)])

# ==========================================================================================
# ③ 三步确定性规则
# ==========================================================================================
func _三_意图三步规则(t) -> void:
	# ---- 第一步：原武器原目标仍合法 → 保持 ----
	var c := _场([_我(0, "A")], [_近战(0, "E1"), _敌(4, "E2"), _敌(5, "E3")])
	Btl.刷新敌方意图(c)
	var 原目标 := str(_意图条(c, "E1").get("目标", ""))
	t.ok(原目标 != "", "③ 换位前 E1（前排近战）已经有预告目标（%s）" % 原目标)
	BattleSwap.换位(c, "enemy", 4, 5)	# 换两台后排敌机，与 E1 的武器 / 目标无关
	Btl.刷新敌方意图(c)
	var 条 := _意图条(c, "E1")
	t.ok(str(条.get("目标", "")) == 原目标 and str(条.get("换位方案", "")) == BattleSwap.方案_保持,
		"③ 第一步：原武器 + 原目标仍合法 → **保持不变**（%s，方案=%s）" % [str(条.get("目标", "")), str(条.get("换位方案", ""))])

	# ---- 第三步：敌方近战被换到后排（前排还有别人）→ 近战不可用 ----
	var c2 := _场([_我(0, "A"), _我(1, "B")], [_近战(0, "E1"), _近战(1, "E2")])
	Btl.刷新敌方意图(c2)
	BattleSwap.换位(c2, "enemy", 0, 4)	# E1 挪到后排；前排还有 E2 在 1
	Btl.刷新敌方意图(c2)
	var 条2 := _意图条(c2, "E1")
	t.ok(str(条2.get("换位方案", "")) == BattleSwap.方案_待机,
		"③ 第三步：纯近战敌机被挪到后排 → 方案 =〔%s〕（实际 %s）" % [BattleSwap.方案_待机, str(条2.get("换位方案", ""))])
	t.ok(J.truthy(条2.get("射程不达待机")) and str(条2.get("动作类型", "")) == "待机",
		"③ 预告里写清〔射程不达 · 待机〕（动作类型=%s）" % str(条2.get("动作类型", "")))

	# ---- 第三步的 3a：近战被挪到后排、但面板上有能用的远程武器 → 改用远程 ----
	var c3 := _场([_我(0, "A")], [_混装(0, "E1"), _近战(1, "E2")])
	Btl.刷新敌方意图(c3)
	t.ok(str(_意图条(c3, "E1").get("武器名", "")) == "斩击", "③ 换位前 E1 预告的是近战【斩击】")
	BattleSwap.换位(c3, "enemy", 0, 4)
	Btl.刷新敌方意图(c3)
	var 条3 := _意图条(c3, "E1")
	t.ok(str(条3.get("换位方案", "")) == BattleSwap.方案_换武器 and str(条3.get("武器名", "")) == "机枪",
		"③ 第三步 3a：改用远程武器【机枪】（方案=%s，武器=%s）" % [str(条3.get("换位方案", "")), str(条3.get("武器名", ""))])

	# ---- 第二步：原武器可用、原目标不可达 → 同武器换目标 ----
	var c4 := _场([_我(0, "A"), _我(1, "B")], [_近战(0, "E1")])
	Btl.刷新敌方意图(c4)
	var 原4 := str(_意图条(c4, "E1").get("目标", ""))
	BattleSwap.换位(c4, "ally", 0, 4)	# 把我方前排被瞄准的那台挪到后排（前排还有 B 在 1）
	Btl.刷新敌方意图(c4)
	var 条4 := _意图条(c4, "E1")
	t.ok(str(条4.get("换位方案", "")) == BattleSwap.方案_换目标,
		"③ 第二步：原目标被挪到后排 → 同武器换目标（方案=%s）" % str(条4.get("换位方案", "")))
	t.ok(str(条4.get("目标", "")) != 原4 and str(条4.get("武器名", "")) == "斩击",
		"③ 第二步：武器仍是【斩击】、目标换成了另一个前排友军（%s → %s）" % [原4, str(条4.get("目标", ""))])

# ==========================================================================================
# ④ 待机：预告与实战同源（`Boss.bossAction` / `Boss.bossTurn` 认同一把锁）
# ==========================================================================================
func _四_待机与实战同源(t) -> void:
	var c := _场([_我(0, "A"), _我(1, "B")], [_近战(0, "E1"), _近战(1, "E2")])
	Btl.刷新敌方意图(c)
	BattleSwap.换位(c, "enemy", 0, 4)
	Btl.刷新敌方意图(c)
	var e1 := _找(c, "enemy", "E1")
	t.ok(str(_意图条(c, "E1").get("动作类型", "")) == "待机", "④ 预告：E1 本回合〔待机〕")
	var 动 = Boss.bossAction(e1, c)
	t.ok(动 is Dictionary and J.truthy((动 as Dictionary).get("待机")),
		"④ 实战：`Boss.bossAction` 返回同一把锁（待机）—— 预告 == 出手")
	var 回 = Boss.bossTurn(e1, c)
	t.ok(回 is Dictionary and str((回 as Dictionary).get("kind", "")) == "none", "④ 敌方阶段：E1 的行动是 `none`（不攻击）")
	t.ok(_有日志(c, "待机", ""), "④ 战报写清〔射程不达 · 待机〕（类型=待机）")

# ==========================================================================================
# ⑤ 顶位
# ==========================================================================================
func _五_顶位(t) -> void:
	var c := _场([_我(0, "A")], [_近战(0, "E1")])
	t.ok(not BattleSwap.顶位(c, "enemy"), "⑤ 敌方前排有人 → 不在顶位")
	BattleSwap.换位(c, "enemy", 0, 4)
	t.ok(BattleSwap.顶位(c, "enemy"), "⑤ 敌方前排被挪空 → 后排进入〔顶位〕")
	t.ok(_有日志(c, "换位顶位", ""), "⑤ 顶位变化写进战报（换位顶位）")
	BattleSwap.换位(c, "enemy", 4, 0)
	t.ok(not BattleSwap.顶位(c, "enemy"), "⑤ 挪回前排 → 解除〔顶位〕")

# ==========================================================================================
# ⑥ 掩护连线跟随新坐标（第 3 项刷新：连线重算，掩护次数保留）
# ==========================================================================================
func _六_掩护连线跟随(t) -> void:
	# ---- (a) 塔斯克挪到别的列 → 同列连线当场断 ----
	var 塔 := _我(0, "A6")
	塔["掩护剩余"] = 2
	var c := _场([塔, _我(1, "A"), _我(4, "U7")], [])
	var 线们 := Btl.当前援护连线们(c)
	var 从0 := int((线们[0] as Dictionary).get("from_slot", -1)) if 线们.size() == 1 else -1
	var 到0 := int((线们[0] as Dictionary).get("to_slot", -1)) if 线们.size() == 1 else -1
	t.ok(线们.size() == 1 and 从0 == 0 and 到0 == 4,
		"⑥ 换位前：1 条掩护连线 塔斯克(%d) → 同列后排友军(%d)" % [从0, 到0])
	BattleSwap.换位(c, "ally", 0, 1)	# 塔斯克挪到 1（列变了）→ 连线必须断
	t.ok(Btl.当前援护连线们(c).is_empty(), "⑥ 塔斯克挪到别的列 → 同列连线当场断掉（连线按新坐标现算）")
	t.ok(int(_找(c, "ally", "A6").get("掩护剩余", 0)) == 2,
		"⑥ 断线不清掩护次数（%d/2）" % int(_找(c, "ally", "A6").get("掩护剩余", 0)))

	# ---- (b) 被护者被换到同列 → 连线跟着新坐标重新接上 ----
	var 塔2 := _我(0, "A6")
	塔2["掩护剩余"] = 2
	var c2 := _场([塔2, _我(5, "U7")], [])
	t.ok(Btl.当前援护连线们(c2).is_empty(), "⑥ 被护者在别的列 → 一开始没有连线")
	BattleSwap.换位(c2, "ally", 4, 5)	# U7 移入 4（塔斯克那一列的后排空格）
	var 线2 := Btl.当前援护连线们(c2)
	var 从 := int((线2[0] as Dictionary).get("from_slot", -1)) if 线2.size() == 1 else -1
	var 到 := int((线2[0] as Dictionary).get("to_slot", -1)) if 线2.size() == 1 else -1
	var 护 := str((线2[0] as Dictionary).get("to_key", "")) if 线2.size() == 1 else ""
	t.ok(线2.size() == 1 and 从 == 0 and 到 == 4 and 护 == "U7",
		"⑥ 换位后：连线按新坐标接上（%d → %d，目标是 %s）" % [从, 到, 护])

# ==========================================================================================
# ⑦ 第 5 项刷新：大招槽「亮起条件」实时同源
# ==========================================================================================
func _七_大招亮起条件刷新(t) -> void:
	var u := _我(4, "A")
	u["大招槽"] = [{"卡": {"名": "测试大招", "实时门槛": {"类型": "在前排", "说明": "要站到前排"}},
		"cd": 0.0, "cd_max": 4.0, "本回合已打": false, "已解锁": true, "解锁说明": "",
		"实时门槛满足": false, "门槛说明": "要站到前排"}]
	var c := _场([u], [_敌(0, "E1")])
	BattleSwap.换位(c, "ally", 4, 0)
	t.ok(J.truthy((u["大招槽"] as Array)[0].get("实时门槛满足")),
		"⑦ 换到前排 → 大招槽的〔亮起条件〕当场刷成满足（不用等到下个我方阶段）")
	BattleSwap.换位(c, "ally", 0, 4)
	t.ok(not J.truthy((u["大招槽"] as Array)[0].get("实时门槛满足")),
		"⑦ 挪回后排 → 亮起条件当场熄灭（%s）" % str((u["大招槽"] as Array)[0].get("门槛说明", "")))

# ==========================================================================================
# ⑧ 回合清状态：锁定 / 错位 / 本回合移位次数
# ==========================================================================================
func _八_回合清状态(t) -> void:
	var c := _场([_我(0, "A")], [_近战(0, "E1"), _近战(1, "E2")])
	Btl.刷新敌方意图(c)
	BattleSwap.换位(c, "enemy", 0, 4, {"isShadowCard": true})
	Btl.刷新敌方意图(c)
	t.ok(BattleSwap.锁定动作(c, _找(c, "enemy", "E1")) != null, "⑧ 本回合：E1 身上有意图锁定")
	c["turn"] = float(c.turn) + 1.0
	t.ok(BattleSwap.锁定动作(c, _找(c, "enemy", "E1")) == null, "⑧ 跨回合：旧锁定自动失效（不再被 `bossAction` 认）")
	BattleSwap.清回合状态(c)
	t.ok(J.num0(c.get("turnShiftCount")) == 0.0 and not BattleSwap.已错位(_找(c, "enemy", "E1")),
		"⑧ `清回合状态` 把本回合移位次数与〔错位〕一起清掉")

# ==========================================================================================
# ⑨ 没有换位时：一个字节都不影响原有 AI（锁定 != null 的场次 = 0）
# ==========================================================================================
func _九_与卡牌无关时零影响(t) -> void:
	var c := _场([_我(0, "A")], [_近战(0, "E1"), _敌(4, "E2")])
	Btl.刷新敌方意图(c)
	for e in c.enemies:
		t.ok(BattleSwap.锁定动作(c, e) == null, "⑨ 没换过位 → %s 身上没有意图锁定（走原 AI）" % str((e as Dictionary).get("key", "")))
	t.ok(BattleSwap.换位(c, "ally", 8, 100) == 0 and J.num0(c.get("turnShiftCount")) == 0.0,
		"⑨ 非法的换位不写任何状态")

# ==========================================================================================
# 小工具
# ==========================================================================================
func _我(位: float, 键: String) -> Dictionary:
	return _单位(键, "ally", 位, {})

func _敌(位: float, 键: String) -> Dictionary:
	var e := _单位(键, "enemy", 位, {})
	e["hp"] = 千
	e["maxHp"] = 千
	return e

func _近战(位: float, 键: String) -> Dictionary:
	var e := _敌(位, 键)
	e["weapons"] = [{"t": _武("斩击", "melee", 500.0, [1, 1]), "cd": 0.0, "uses": null, "readyTurn": 0.0}]
	return e

## 近战 + 机枪（用来验第三步的 3a「改用远程武器」）。
func _混装(位: float, 键: String) -> Dictionary:
	var e := _敌(位, 键)
	e["weapons"] = [
		{"t": _武("斩击", "melee", 500.0, [1, 1]), "cd": 0.0, "uses": null, "readyTurn": 0.0},
		{"t": _武("机枪", "direct", 120.0, [1, 6]), "cd": 0.0, "uses": null, "readyTurn": 0.0},
	]
	return e

func _武(名: String, fire: String, 威力: float, 距离: Array) -> Dictionary:
	return {"name": 名, "fire": fire, "dmgType": "物理", "power": 威力, "hit": 100.0,
		"stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": [], "距离": 距离}

func _单位(键: String, side: String, 位: float, 标: Dictionary) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 1000.0, "hp": 1000.0,
		"melee": 120.0, "shoot": 120.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": 标, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _场(我方: Array, 敌方: Array, 种子: int = 20261020) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "公有冷却": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}

func _找(c: Dictionary, side: String, 键: String) -> Dictionary:
	var 们: Array = c.get("allies") if side == "ally" else c.get("enemies")
	for u in J.or_(们, []):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

func _意图条(c: Dictionary, 键: String) -> Dictionary:
	var 表 = c.get("敌方意图表")
	if 表 is Dictionary and (表 as Dictionary).get(键) is Dictionary:
		return (表 as Dictionary)[键]
	return {}

func _有日志(c: Dictionary, 类型: String, 关键字: String) -> bool:
	for e in J.or_(c.get("log"), []):
		if not (e is Dictionary):
			continue
		if str((e as Dictionary).get("类型", "")) != 类型:
			continue
		if 关键字 == "" or str((e as Dictionary).get("文本", "")).contains(关键字):
			return true
	return false
