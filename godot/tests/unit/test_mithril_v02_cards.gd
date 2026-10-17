## MITH-2 验收：秘银 v0.2 数据落表（26 张牌）+ 旧机制退役。
## 规格 = 《秘银势力卡牌设计 v0.2.md》+《评审-秘银连携作战-v0.2与派生任务单-ARGON.md》§3 MITH-2。
##
## 八段：
##   ① 旧机制退役（标定 / 兑现 / 取消被挡 / 倒下接力 / 毛的 markBreak 线）+ 开关关着时 v0.1 照旧
##   ② 26 张牌数据完整性（15 角色 + 1 合体技 + 9 势力 + 1 衍生 TDD-1）+ 8 张连携牌
##   ③ 牌池装填（旧 F_MITH_1/2 被替换 / 每人 3 张 / 合体技三人条件 / 初始手牌 ≤ 6 / 条件牌进待触发）
##   ④ 占行动 / 每台机体每回合 1 张 / 合体技占三人
##   ⑤ 动态降费（数据链 −5 / 专业军人 −10 / 消费）
##   ⑥ 8 张连携牌的【连携】/【连携·N】实际效果
##   ⑦ 其余基础效果（TDD-1 / 抽牌 / 隐身 / 换位 / 泰莎 / 饱和攻击 / ECM / 阵亡移除 …）
##   ⑧ 默认开关关着：一条 v0.2 行为都不产出（硬性红线 2）
extends RefCounted

const 我方 := [
	{"键": "U7", "位": 0, "等级": 10}, {"键": "U6", "位": 1, "等级": 10},
	{"键": "U2", "位": 2, "等级": 10}, {"键": "U1", "位": 3, "等级": 10},
	{"键": "U8", "位": 4, "等级": 10},
]
const 敌方 := [{"键": "flagship", "位": 0, "等级": 1}, {"键": "bluefish", "位": 1, "等级": 1}]
const 种子 := 20261016

# ======================== 小工具 ========================
func _ctx(气: float = 999.0) -> Dictionary:
	var c := Setup.开局(我方, 敌方, 种子, null, {"战术卡牌": true, "秘银v02": true})
	c.气势 = 气
	return c

func _ctx关(气: float = 999.0) -> Dictionary:
	var c := Setup.开局(我方, 敌方, 种子, null, {"战术卡牌": true})
	c.气势 = 气
	return c

func _单位(c: Dictionary, 键: String) -> Variant:
	for u in c.allies:
		if u != null and str(u.get("key")) == 键:
			return u
	return null

func _卡(id: String, c: Variant = null) -> Dictionary:
	var d := MithrilV02Cards.卡(id)
	if d.is_empty():
		var 表 = Db.T.战术卡牌表
		for x in (表 if 表 is Array else []):
			if x is Dictionary and str(x.get("id")) == id:
				d = x
				break
	return Btl.克隆战术牌(d, c)

func _装手牌(c: Dictionary, ids: Array) -> void:
	c.战术手牌 = []
	for id in ids:
		c.战术手牌.append(_卡(str(id), c))

func _找手牌(c: Dictionary, id: String) -> Variant:
	return J.find(c.战术手牌, func(x): return x != null and str(x.get("id")) == id)

func _手牌数(c: Dictionary, id: String) -> int:
	return c.战术手牌.filter(func(x): return x != null and str(x.get("id")) == id).size()

func _打(c: Dictionary, id: String, 满气: bool = true) -> Dictionary:
	var 卡 = _找手牌(c, id)
	if 卡 == null:
		return {"成功": false, "原因": "手牌里没有 %s" % id}
	if 满气:
		c.气势 = 999.0
	return Btl.打战术牌(c, str(卡.get("_实例号", id)))

func _日志有(c: Dictionary, 片段: String) -> bool:
	return J.some(c.log, func(e): return e != null and str(e.get("文本", "")).contains(片段))

func _攻击事件(c: Dictionary, 卡ID: String) -> Array:
	return c.log.filter(func(e): return e != null and e.get("类型") == "攻击" and str(e.get("战术牌", "")) == 卡ID)

func _首攻击(c: Dictionary, 卡ID: String) -> Variant:
	return J.find(c.log, func(e): return e != null and e.get("类型") == "攻击" and str(e.get("战术牌", "")) == 卡ID)

func _友好血量(c: Dictionary) -> void:
	for e in c.enemies:
		e.hp = 50000.0
		e.maxHp = 50000.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else str(errors)))

	# ==================== ① 旧机制退役 ====================
	var c1 := _ctx()
	var 毛 = _单位(c1, "U2")
	var 敌 = c1.enemies[0]
	t.ok(Params.秘银v02开(c1), "① 开关：ctx.选项.秘银v02 = true → Params.秘银v02开(ctx) = true")
	t.ok(FacMith.旧机制退役(c1), "① 开关：FacMith.旧机制退役(ctx) = true")
	t.ok(J.truthy(c1.秘银.get("v02")), "① `秘银开局` 初始化了 v0.2 状态（ctx.秘银.v02 = true）")
	t.ok(_日志有(c1, "Uruz 连携作战"), "① `秘银开局` 记了一条开局日志（〔势力〕秘银 v0.2「Uruz 连携作战」开局…）")
	t.ok(J.every(我方, func(x): return J.truthy(_单位(c1, x.键).get("秘银v02"))),
		"① 5 台秘银成员都被打上 `秘银v02` 标记（没有 ctx 的老路径据此退役）")
	t.ok(c1.战况计数.has("秘银受击") and c1.战况计数.has("宗介受击") and c1.战况计数.has("克鲁佐击破")
			and c1.战况计数.has("打出秘银大招") and c1.战况计数.has("触发连携") and c1.战况计数.has("打出TDD1"),
		"① 开局预置 6 个 v0.2 计数键（受击 / 宗介受击 / 击破 / 秘银大招 / 触发连携 / 打出TDD1）")

	var 挂 := FacMith.秘银挂标定(c1, 毛, 敌, null)
	t.ok(挂 == 0.0 and FacMith.标定条目们(敌).is_empty(),
		"① v0.2 开：毛（情报岗）攻击不再挂 v0.1 标定（返回 0，目标身上没有标定条目）")
	var 兑 := FacMith.秘银兑现(c1, _单位(c1, "U7"), 敌, null)
	t.ok(兑 == 0.0 and absf(Calc.defMul(敌) - 1.0) < 0.0001,
		"① v0.2 开：作战岗不再兑现破防（返回 0，defMul 仍是 1 —— 毛那条 markBreak −20% 破防线整条下线）")
	t.ok(not FacMith.秘银取消被挡(_单位(c1, "U7"), 敌, c1), "① v0.2 开：`秘银取消被挡` 退役（有 ctx 的路径）")
	t.ok(not FacMith.秘银取消被挡(_单位(c1, "U7"), 敌), "① v0.2 开：`秘银取消被挡` 退役（没有 ctx 的老路径也认）")
	var 死者 = _单位(c1, "U8")
	var 原位数 := float(死者.slot)
	死者.hp = 0.0
	c1.log = []
	var 接力 := FacMith.倒下接力(c1, 死者, null)
	t.ok(接力 == 0.0 and not _日志有(c1, "倒下接力"), "① v0.2 开：`倒下接力` 不触发（返回 0，日志里没有倒下接力）")
	t.ok(J.every(c1.allies.filter(func(u): return u.hp > 0), func(u): return float(u.slot) != 原位数),
		"① v0.2 开：没有队友接管倒下者的站位")

	# 对照：开关关着 → v0.1 照旧
	var c0 := _ctx关()
	var 敌0 = c0.enemies[0]
	t.ok(not Params.秘银v02开(c0), "① 对照：开关关着 → Params.秘银v02开(ctx) = false")
	t.ok(not _日志有(c0, "Uruz"), "① 对照：开关关着 → 没有 v0.2 开局日志")
	t.ok(not c0.战况计数.has("打出秘银大招") and not c0.战况计数.has("秘银受击"),
		"① 对照：开关关着 → 战况计数一个 v0.2 键都不多")
	var 挂0 := FacMith.秘银挂标定(c0, _单位(c0, "U2"), 敌0, null)
	t.ok(挂0 >= 1.0 and FacMith.标定条目们(敌0).size() == 1 and _日志有(c0, "标定"),
		"① 对照：开关关着 → 情报岗照旧挂标定（≥1 层，日志里有〔势力〕…标定…）")
	var 兑0 := FacMith.秘银兑现(c0, _单位(c0, "U7"), 敌0, null)
	t.ok(兑0 >= 1.0 and Calc.defMul(敌0) < 1.0, "① 对照：开关关着 → 作战岗照旧兑现破防（defMul < 1）")
	t.ok(FacMith.秘银取消被挡(_单位(c0, "U7"), 敌0), "① 对照：开关关着 → 兑现过的标定照旧取消被挡")
	var 死0 = _单位(c0, "U8")
	var 位0 := float(死0.slot)
	死0.hp = 0.0
	var 接力0 := FacMith.倒下接力(c0, 死0, null)
	t.ok(接力0 == 1.0 and _日志有(c0, "倒下接力"), "① 对照：开关关着 → 倒下接力照旧生效（1.0 + 日志）")
	t.ok(J.some(c0.allies.filter(func(u): return u.hp > 0), func(u): return float(u.slot) == 位0),
		"① 对照：开关关着 → 有队友接管了倒下者的站位")

	# ==================== ② 26 张牌的数据完整性 ====================
	var 表 := MithrilV02Cards.卡表()
	t.ok(表.size() == 26, "② 卡表共 %d 张（25 张正式牌 + 1 张衍生牌）" % 表.size())
	var 按种类 := {}
	for x in 表:
		按种类[str(x.get("种类", ""))] = int(按种类.get(str(x.get("种类", "")), 0)) + 1
	t.ok(int(按种类.get("角色", 0)) == 15 and int(按种类.get("合体技", 0)) == 1
			and int(按种类.get("势力", 0)) == 9 and int(按种类.get("衍生", 0)) == 1,
		"② 分类：角色牌 15 张 + 合体技 1 张 + 势力牌 9 张 + 衍生牌 1 张（%s）" % [按种类])
	var id集 := {}
	for x in 表:
		id集[str(x.get("id", ""))] = true
	t.ok(id集.size() == 26, "② 26 个 id 互不重复")

	var 缺字段 := []
	var 归属错 := []
	for x in 表:
		for k in ["id", "名", "类型", "层级", "种类", "归属", "耗气", "冷却", "限次", "回库", "效果说明"]:
			if not x.has(k):
				缺字段.append("%s.%s" % [x.get("id"), k])
		if str(x.get("归属", "")) != "秘银":
			归属错.append(x.get("id"))
	t.ok(缺字段.is_empty(), "② 每张牌都写齐了 id / 名 / 类型 / 层级 / 种类 / 归属 / 耗气 / 冷却 / 限次 / 回库 / 效果说明%s" % ("" if 缺字段.is_empty() else "；缺：" + str(缺字段)))
	t.ok(归属错.is_empty(), "② 26 张牌全部 `归属 = 秘银`（%s）" % [归属错])
	t.ok(J.every(MithrilV02Cards.角色牌们(), func(x): return str(x.get("角色所属势力", "")) == "秘银" and x.get("回库") == true),
		"② 15 张角色牌全部 `角色所属势力 = 秘银` 且 `回库 = true`")
	t.ok(J.every(MithrilV02Cards.势力牌们(), func(x): return str(x.get("归属", "")) == "秘银" and str(x.get("种类", "")) == "势力" and x.get("回库") == true),
		"② 9 张势力牌全部 `归属 = 秘银` / `种类 = 势力` / `回库 = true`")

	# 逐张对规格表（耗气 / 冷却 / 触发条件 / 占行动）
	var 规格 := {
		"U_U7_1": [20, 3, "开局在手", ["U7"]], "U_U7_2": [35, 5, "宗介HP或受击", ["U7"]], "U_U7_3": [5, 2, "开局在手", []],
		"U_U6_1": [5, 1, "开局在手", ["U6"]], "U_U6_2": [25, 4, "第N回合起", ["U6"]], "U_U6_3": [5, 2, "开局在手", []],
		"U_U2_1": [10, 3, "开局在手", []], "U_U2_2": [5, 1, "开局在手", ["U2"]], "U_U2_3": [25, 4, "触发连携", ["U2"]],
		"U_U1_1": [25, 4, "克鲁佐击破或回合", ["U1"]], "U_U1_2": [5, 2, "开局在手", []], "U_U1_3": [5, 1, "开局在手", ["U1"]],
		"U_U8_1": [0, 1, "开局在手", []], "U_U8_2": [5, 3, "开局在手", []], "U_U8_3": [15, 3, "第N回合起", ["U8"]],
		"U_URUZ_TRI": [40, 6, "乌鲁兹三角", ["U7", "U2", "U6"]],
		"F_MITH_V2_1": [0, 2, "开局在手", []], "F_MITH_V2_2": [10, 3, "第N回合起", []], "F_MITH_V2_3": [15, 4, "打出TDD1", []],
		"F_MITH_V2_4": [5, 2, "开局在手", []], "F_MITH_V2_5": [10, 3, "秘银受击", []], "F_MITH_V2_6": [0, 3, "秘银低血", []],
		"F_MITH_V2_7": [5, 3, "第N回合起", []], "F_MITH_V2_8": [10, 3, "开局在手", []], "F_MITH_V2_9": [15, 4, "打出过秘银大招", []],
	}
	var 不符 := []
	for id in 规格.keys():
		var x := MithrilV02Cards.卡(id)
		var 规: Array = 规格[id]
		var 条件 = x.get("触发条件")
		var 类型 := str(条件.get("类型", "")) if 条件 is Dictionary else ""
		if int(x.get("耗气", -1)) != int(规[0]) or int(x.get("冷却", -1)) != int(规[1]) or 类型 != str(规[2]) \
				or J.or_(x.get("占行动"), []) != 规[3]:
			不符.append("%s(耗%s/冷%s/%s/%s)" % [id, x.get("耗气"), x.get("冷却"), 类型, [x.get("占行动")]])
	t.ok(不符.is_empty(), "② 25 张正式牌的耗气 / 冷却 / 触发条件类型 / 占行动与规格表逐张一致%s" % ("" if 不符.is_empty() else "；不符：" + str(不符)))

	var 合 := MithrilV02Cards.合体技卡()
	t.ok(合.get("合体技") == true and J.or_(合.get("角色们"), []) == ["U7", "U2", "U6"]
			and int(合.get("触发条件", {}).get("触发连携", 0)) == 6 and int(合.get("连携阈值", 0)) == 1,
		"② 合体技【乌鲁兹·三角】：角色们 = U7/U2/U6、触发条件 = 触发连携 ≥ 6、连携阈值 1")
	var tdd := MithrilV02Cards.卡("TDD-1")
	t.ok(str(tdd.get("全名")) == "TDD-1·巡航导弹" and str(tdd.get("兼容名")) == "TDD-1 导弹" and str(tdd.get("名")) == "TDD-1 导弹",
		"② TDD-1：正式名「TDD-1·巡航导弹」/ 兼容名「TDD-1 导弹」（牌面 `名` 保持兼容名，MITH-1 日志不变）")
	t.ok(tdd.get("衍生") == true and tdd.get("是TDD1") == true and int(tdd.get("耗气", -1)) == 0
			and int(tdd.get("冷却", -1)) == 0 and J.or_(tdd.get("占行动"), []).is_empty() and str(tdd.get("归属")) == "秘银",
		"② TDD-1：衍生 / 是TDD1 / 耗气 0 / 冷却 0 / 不占行动 / 归属秘银")

	var 连携缺 := []
	for id in MithrilV02Cards.连携牌:
		var x := MithrilV02Cards.卡(id)
		if x.is_empty() or int(x.get("连携阈值", 0)) <= 0:
			连携缺.append(id)
	t.ok(MithrilV02Cards.连携牌.size() == 8 and 连携缺.is_empty(),
		"② 8 张连携牌（超长距离狙击 / 呼叫达纳号 / 导弹齐射·饱和 / 单分子刀·猎鹰 / 反坦克导弹 / 合体技 / 火力支援请求 / 再装填）全都有连携阈值%s" % ("" if 连携缺.is_empty() else "；缺：" + str(连携缺)))
	t.ok(J.every(表, func(x): return int(x.get("连携阈值", 0)) > 0 == J.inc(MithrilV02Cards.连携牌, x.get("id"))),
		"② 且**只有**这 8 张带连携阈值（其余 17 张 = 0）")
	t.ok(int(MithrilV02Cards.卡("U_U6_2").get("连携阈值")) == 2 and int(MithrilV02Cards.卡("U_U2_1").get("连携阈值")) == 1
			and int(MithrilV02Cards.卡("U_U1_1").get("连携阈值")) == 2 and int(MithrilV02Cards.卡("F_MITH_V2_8").get("连携阈值")) == 3,
		"② 连携阈值逐张对：超长距离狙击 2 / 呼叫达纳号 1 / 单分子刀·猎鹰 2 / 再装填 3")

	# ==================== ③ 牌池装填 ====================
	var c3 := _ctx()
	var 池id: Array = c3.战术牌池.map(func(x): return str(x.get("id")))
	t.ok(not J.inc(池id, "F_MITH_1") and not J.inc(池id, "F_MITH_2"),
		"③ 旧版 F_MITH_1 / F_MITH_2 被替换掉（牌池里没有它们）")
	t.ok(J.inc(池id, "U_U7_1") and J.inc(池id, "U_U6_1") and J.inc(池id, "U_U2_1")
			and J.inc(池id, "U_U1_1") and J.inc(池id, "U_U8_1"),
		"③ 5 名在场成员的角色牌都进了牌池")
	t.ok(池id.filter(func(x): return MithrilV02Cards.有(x)).size() == 25,
		"③ 牌池里装进 25 张 v0.2 牌（26 张里 TDD-1 是衍生牌，只由别的牌置入、不装进牌池；%d）" % 池id.filter(func(x): return MithrilV02Cards.有(x)).size())
	t.ok(J.inc(池id, "U_URUZ_TRI"), "③ U7 / U2 / U6 三人都在场 → 合体技进牌池")
	var 手牌v02: int = c3.战术手牌.filter(func(x): return MithrilV02Cards.有(x)).size()
	t.ok(c3.战术手牌.size() <= 6 and c3.战术手牌.size() > 0 and 手牌v02 >= 5,
		"③ 初始手牌 %d 张（上限 6 张），其中 v0.2 牌 %d 张（剩下的名额是开局保底的「激励」）" % [c3.战术手牌.size(), 手牌v02])
	t.ok(J.some(c3.待触发战术牌, func(x): return MithrilV02Cards.有(x)),
		"③ 条件型 v0.2 牌（第N回合起 / 触发连携 / 秘银受击 …）进了待触发战术牌（v0.2 %d 张 / 共 %d 张）" % [
			c3.待触发战术牌.filter(func(x): return MithrilV02Cards.有(x)).size(), c3.待触发战术牌.size()])
	t.ok(J.some(c3.待触发战术牌, func(x): return str(x.get("id")) == "U_URUZ_TRI"),
		"③ 合体技在待触发池里等「触发连携 ≥ 6」")

	var c3b := Setup.开局([{"键": "U7", "位": 0, "等级": 10}], 敌方, 种子, null, {"战术卡牌": true, "秘银v02": true})
	var 池b: Array = c3b.战术牌池.map(func(x): return str(x.get("id")))
	t.ok(not J.inc(池b, "U_URUZ_TRI"), "③ 只有 U7 在场 → 合体技**不**进牌池")
	t.ok(J.inc(池b, "U_U7_1") and not J.inc(池b, "U_U6_1"), "③ 只有 U7 在场 → 只装 U7 的 3 张角色牌")
	t.ok(池b.filter(func(x): return MithrilV02Cards.有(x)).size() == 12, "③ 单人队伍：3 张角色牌 + 9 张势力牌 = 12（%d）" % 池b.filter(func(x): return MithrilV02Cards.有(x)).size())

	var c3c := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], 敌方, 种子, null, {"战术卡牌": true, "秘银v02": true})
	var 池c: Array = c3c.战术牌池.map(func(x): return str(x.get("id")))
	t.ok(not J.some(池c, func(x): return MithrilV02Cards.有(x)), "③ 队伍里没有秘银成员 → 一张 v0.2 牌都不装")

	# ==================== ④ 占行动 / 每台每回合 1 张 / 合体技三人 ====================
	var c4 := _ctx()
	c4.待触发战术牌 = []
	_装手牌(c4, ["U_U7_1"])
	var 打1 := _打(c4, "U_U7_1")
	t.ok(打1.成功, "④ 打出【λ 驱动·散弹炮】成功")
	t.ok(int(_单位(c4, "U7").get("actedTurn", -1)) == int(c4.turn),
		"④ 占行动：打出后 U7.actedTurn = 本回合（%d），替代它本回合的普通自动行动" % int(c4.turn))
	t.ok(int(c4.战况计数["打出秘银大招"]) == 1, "④ 战况计数.打出秘银大招 +1（1）")
	c4.战术手牌.append(_卡("U_U7_2", c4))
	var 打2 := _打(c4, "U_U7_2")
	t.ok(not 打2.成功 and str(打2.原因).contains("已行动"),
		"④ 同一台机体本回合第 2 张大招牌打不出（原因：%s）" % str(打2.原因))
	t.ok(not Btl.卡可打吗(c4, _找手牌(c4, "U_U7_2")), "④ `Btl.卡可打吗` 也判它不可打（门面可复用）")
	c4.turn = float(c4.turn) + 1.0
	Flow.回合开始(c4)
	t.ok(Btl.卡可打吗(c4, _找手牌(c4, "U_U7_2")), "④ 下一回合（turn = %d）同一张牌又能打了" % int(c4.turn))

	var c4b := _ctx()
	c4b.待触发战术牌 = []
	c4b["本回合秘银牌数"] = 1
	c4b.战况计数["触发连携"] = 6
	_装手牌(c4b, ["U_URUZ_TRI"])
	var 合卡 = _找手牌(c4b, "U_URUZ_TRI")
	t.ok(Btl.卡可打吗(c4b, 合卡), "④ 合体技：三人都在场且本回合都没行动 → 可打")
	_单位(c4b, "U2").actedTurn = int(c4b.turn)
	t.ok(not Btl.卡可打吗(c4b, 合卡), "④ 合体技：三人中有一人（U2）本回合已行动 → 不可打")
	_单位(c4b, "U2").actedTurn = -1
	_单位(c4b, "U7").hp = 0.0
	t.ok(not Btl.卡可打吗(c4b, 合卡), "④ 合体技：三人中有一人（U7）阵亡 → 不可打")
	_单位(c4b, "U7").hp = 5000.0
	_友好血量(c4b)
	var 打合 := _打(c4b, "U_URUZ_TRI")
	t.ok(打合.成功, "④ 三人齐、都没行动 → 合体技打出成功")
	t.ok(J.every(["U7", "U2", "U6"], func(k): return int(_单位(c4b, k).get("actedTurn", -1)) == int(c4b.turn)),
		"④ 合体技一次占用 U7 / U2 / U6 三人的行动")
	t.ok(J.some(c4b.log, func(e): return e != null and str(e.get("文本", "")).contains("达纳号"))
			and J.some(c4b.log, func(e): return e != null and str(e.get("文本", "")).contains("超长距离狙击"))
			and J.some(c4b.log, func(e): return e != null and str(e.get("文本", "")).contains("λ 驱动·极限放出")),
		"④ 合体技三步都结算了（① 达纳号巡航导弹 ② 克鲁兹狙击 ③ 宗介极限放出）")

	# ==================== ⑤ 动态降费 ====================
	var c5 := _ctx()
	c5.待触发战术牌 = []
	_装手牌(c5, ["F_MITH_V2_4", "U_U7_1"])
	c5.气势 = 60.0
	t.ok(Btl.实际耗气(c5, _找手牌(c5, "U_U7_1")) == 20, "⑤ 没有降费时：λ 驱动·散弹炮 实际耗气 = 20")
	var 打链 := _打(c5, "F_MITH_V2_4", false)
	t.ok(打链.成功 and int(c5.下张秘银牌降费) == 5, "⑤ 「数据链」→ ctx.下张秘银牌降费 = 5")
	t.ok(Btl.实际耗气(c5, _找手牌(c5, "U_U7_1")) == 15, "⑤ 实际耗气 20 − 5 = 15")
	c5.气势 = 60.0
	var 气势前 := float(c5.气势)
	var 打散 := _打(c5, "U_U7_1", false)
	t.ok(打散.成功 and int(c5.下张秘银牌降费) == 0, "⑤ 打出之后降费状态被消费（归 0）")
	t.ok(absf(float(c5.气势) - (气势前 - 15.0)) < 0.01, "⑤ 真的只扣了 15 点气势（%d → %d）" % [int(气势前), int(c5.气势)])

	var c5b := _ctx()
	c5b.待触发战术牌 = []
	_装手牌(c5b, ["U_U7_3", "U_U7_2"])
	c5b.气势 = 80.0
	t.ok(_打(c5b, "U_U7_3", false).成功 and int(c5b.下张宗介大招降费) == 10,
		"⑤ 「专业军人」→ ctx.下张宗介大招降费 = 10")
	t.ok(Btl.实际耗气(c5b, _找手牌(c5b, "U_U7_2")) == 25, "⑤ 宗介大招 35 − 10 = 25")
	t.ok(_打(c5b, "U_U7_2", false).成功 and int(c5b.下张宗介大招降费) == 0, "⑤ 打出宗介大招后降费被消费")
	var c5c := _ctx关()
	t.ok(Btl.实际耗气(c5c, _卡("U_U7_1", c5c)) == 20, "⑤ 对照：开关关着 → 实际耗气 = 基础耗气（不减）")

	# ==================== ⑥ 8 张连携牌 ====================
	# ① 超长距离狙击（连携·2：必中 + 必暴击）
	var c6 := _ctx()
	c6.turn = 2.0
	c6.待触发战术牌 = []
	_装手牌(c6, ["U_U6_2"])
	c6["本回合秘银牌数"] = 2
	_友好血量(c6)
	var 打狙 := _打(c6, "U_U6_2")
	var 狙击事件 = _首攻击(c6, "U_U6_2")
	t.ok(打狙.成功 and 狙击事件 != null and 狙击事件.get("连携") == true,
		"⑥-1 超长距离狙击：n_before = 2 ≥ 连携阈值 2 → 连携成立")
	t.ok(狙击事件 != null and 狙击事件.get("命中") == true and float(狙击事件.get("暴击", 0)) >= 1.0,
		"⑥-1 连携·2：必中 + 必暴击（命中 = true / 暴击 次 ≥ 1）")
	t.ok(int(c6.战况计数["触发连携"]) == 1, "⑥-1 触发连携 计数 +1")
	var c6b := _ctx()
	c6b.turn = 2.0
	c6b.待触发战术牌 = []
	_装手牌(c6b, ["U_U6_2"])
	c6b["本回合秘银牌数"] = 1
	_友好血量(c6b)
	_打(c6b, "U_U6_2")
	t.ok(int(c6b.战况计数["触发连携"]) == 0 and not _日志有(c6b, "〔连携·2〕"),
		"⑥-1 对照：n_before = 1 < 2 → 连携不成立（触发连携 仍是 0）")

	# ② 呼叫达纳号（连携：改为 2 张 TDD-1）
	var c6c := _ctx()
	c6c.待触发战术牌 = []
	_装手牌(c6c, ["U_U2_1"])
	t.ok(_打(c6c, "U_U2_1").成功 and _手牌数(c6c, "TDD-1") == 1, "⑥-2 呼叫达纳号（第 1 张）：置入 1 张 TDD-1")
	var c6d := _ctx()
	c6d.待触发战术牌 = []
	_装手牌(c6d, ["U_U2_1"])
	c6d["本回合秘银牌数"] = 1
	t.ok(_打(c6d, "U_U2_1").成功 and _手牌数(c6d, "TDD-1") == 2,
		"⑥-2 呼叫达纳号（连携·1）：改为 2 张 TDD-1（1 + 连携 1）")

	# ③ 导弹齐射·饱和（连携·N：多打 n_before 轮，最多 +4）
	var c6e := _ctx()
	c6e.待触发战术牌 = []
	_装手牌(c6e, ["U_U2_3"])
	c6e["本回合秘银牌数"] = 2
	c6e.战况计数["触发连携"] = 3
	_友好血量(c6e)
	_打(c6e, "U_U2_3")
	var 齐射事件 := _攻击事件(c6e, "U_U2_3")
	t.ok(齐射事件.size() == 6, "⑥-3 导弹齐射·饱和：连携·N（n_before = 2）→ 1 + 2 = 3 轮 × 2 台敌机 = 6 发（%d）" % 齐射事件.size())
	var c6f := _ctx()
	c6f.待触发战术牌 = []
	_装手牌(c6f, ["U_U2_3"])
	_友好血量(c6f)
	_打(c6f, "U_U2_3")
	t.ok(_攻击事件(c6f, "U_U2_3").size() == 2, "⑥-3 对照：n_before = 0 → 只有 1 轮 × 2 台 = 2 发")
	var c6g := _ctx()
	c6g.待触发战术牌 = []
	_装手牌(c6g, ["U_U2_3"])
	c6g["本回合秘银牌数"] = 9
	_友好血量(c6g)
	_打(c6g, "U_U2_3")
	t.ok(_攻击事件(c6g, "U_U2_3").size() == 10, "⑥-3 上限：n_before = 9 也只加 4 轮 → 5 轮 × 2 台 = 10 发（%d）" % _攻击事件(c6g, "U_U2_3").size())

	# ④ 单分子刀·猎鹰（连携·2：伤害 ×1.5；击破 → 下一张秘银牌 −10）
	var c6h := _ctx()
	c6h.待触发战术牌 = []
	_装手牌(c6h, ["U_U1_1"])
	c6h["本回合秘银牌数"] = 2
	_友好血量(c6h)
	_打(c6h, "U_U1_1")
	var 刀事件 = _首攻击(c6h, "U_U1_1")
	t.ok(刀事件 != null and 刀事件.get("连携") == true and absf(float(刀事件.get("连携加成", 0.0)) - 1.5) < 0.001,
		"⑥-4 单分子刀·猎鹰 连携·2：本次伤害 ×1.5（连携加成 1.5）")
	t.ok(J.some(_单位(c6h, "U1").get("buffs", []), func(b): return b != null and float(b.get("受伤Mul", 0.0)) > 0.0),
		"⑥-4 打完本回合克鲁佐受到伤害 +20%（受伤Mul buff）")
	var c6i := _ctx()
	c6i.待触发战术牌 = []
	_装手牌(c6i, ["U_U1_1"])
	c6i["本回合秘银牌数"] = 2
	# 挑蓝鱼当脆皮（旗舰有 barrier，会把 ≤2500 的伤害整个吃掉，不适合验「击破」）
	var 脆皮 = c6i.enemies[1]
	脆皮.hp = 1.0
	_打(c6i, "U_U1_1")
	t.ok(float(脆皮.hp) <= 0.0 and int(c6i.下张秘银牌降费) == 10,
		"⑥-4 连携·2 击破目标 → 本回合下一张秘银牌费用 −10（下张秘银牌降费 = %d）" % int(c6i.下张秘银牌降费))

	# ⑤ 反坦克导弹（连携：置入 1 张 TDD-1）+ 两发曲射
	var c6j := _ctx()
	c6j.turn = 2.0
	c6j.待触发战术牌 = []
	_装手牌(c6j, ["U_U8_3"])
	c6j["本回合秘银牌数"] = 1
	_友好血量(c6j)
	var 打反 := _打(c6j, "U_U8_3")
	t.ok(打反.成功 and _攻击事件(c6j, "U_U8_3").size() == 2, "⑥-5 反坦克导弹：两发曲射导弹（2 条攻击事件）")
	t.ok(_手牌数(c6j, "TDD-1") == 1, "⑥-5 连携·1：置入 1 张 TDD-1")

	# ⑥ 合体技（连携·N：第 ① 步多打 n_before 轮，最多 +3）
	var c6k := _ctx()
	c6k.待触发战术牌 = []
	c6k["本回合秘银牌数"] = 3
	c6k.战况计数["触发连携"] = 6
	_装手牌(c6k, ["U_URUZ_TRI"])
	_友好血量(c6k)
	_打(c6k, "U_URUZ_TRI")
	var 达纳号事件: Array = c6k.log.filter(func(e): return e != null and str(e.get("战术牌", "")) == "U_URUZ_TRI" and str(e.get("文本", "")).contains("达纳号"))
	t.ok(达纳号事件.size() == 8, "⑥-6 合体技 连携·N（n_before = 3）→ 第 ① 步 1 + 3 = 4 轮 × 2 台 = 8 发（%d）" % 达纳号事件.size())

	# ⑦ 火力支援请求（连携：改为 2 张）
	var c6l := _ctx()
	c6l.turn = 2.0
	c6l.待触发战术牌 = []
	_装手牌(c6l, ["F_MITH_V2_2"])
	c6l["本回合秘银牌数"] = 1
	t.ok(_打(c6l, "F_MITH_V2_2").成功 and _手牌数(c6l, "TDD-1") == 2,
		"⑥-7 火力支援请求 连携·1：置入 2 张 TDD-1（1 + 连携 1）")

	# ⑧ 再装填（连携·3：一张冷却中的秘银角色牌冷却 −2；没有连携·3 就没效果）
	var c6m := _ctx()
	c6m.待触发战术牌 = []
	var 冷却牌 := _卡("U_U7_1", c6m)
	冷却牌["当前冷却"] = 3
	c6m.战术手牌 = [冷却牌, _卡("F_MITH_V2_8", c6m)]
	c6m["本回合秘银牌数"] = 3
	t.ok(_打(c6m, "F_MITH_V2_8").成功 and int(冷却牌.get("当前冷却", -1)) == 1,
		"⑥-8 再装填 连携·3：冷却中的秘银角色牌冷却 3 → 1（−2）")
	var c6n := _ctx()
	c6n.待触发战术牌 = []
	var 冷却牌2 := _卡("U_U7_1", c6n)
	冷却牌2["当前冷却"] = 3
	c6n.战术手牌 = [冷却牌2, _卡("F_MITH_V2_8", c6n)]
	c6n["本回合秘银牌数"] = 2
	t.ok(_打(c6n, "F_MITH_V2_8").成功 and int(冷却牌2.get("当前冷却", -1)) == 3,
		"⑥-8 对照：n_before = 2 < 3 → 没有连携·3，一点冷却都不减（仍是 3）")

	# ==================== ⑦ 其余基础效果 ====================
	# TDD-1：打敌方 HP 最高的存活单位（260 点物理伤害），走护盾抵消
	var c7 := _ctx()
	c7.待触发战术牌 = []
	_装手牌(c7, ["TDD-1"])
	# 旗舰有 barrier（会把 ≤2500 的伤害整个吃掉），所以「最高血」的目标挑蓝鱼来验伤害
	var 高血 = c7.enemies[1]
	var 低血 = c7.enemies[0]
	高血.hp = 4000.0
	低血.hp = 1000.0
	var 高血前 := float(高血.hp)
	var 低血前 := float(低血.hp)
	var 打弹 := _打(c7, "TDD-1")
	t.ok(打弹.成功 and float(高血.hp) < 高血前 and absf(float(低血.hp) - 低血前) < 0.001,
		"⑦ TDD-1：只打「敌方当前 HP 最高」的那台（高血 %d → %d，低血不动）" % [int(高血前), int(高血.hp)])
	t.ok(not J.inc(c7.战术手牌.map(func(x): return str(x.get("id"))), "TDD-1"), "⑦ TDD-1 打出后从手牌移除、不回库")
	t.ok(not J.some(c7.待触发战术牌, func(x): return str(x.get("id")) == "TDD-1"), "⑦ TDD-1 不回牌库")
	t.ok(int(c7.战况计数["打出TDD1"]) == 1 and int(c7.本回合秘银牌数) == 1, "⑦ TDD-1 推进连携（秘银牌数 +1 / 打出TDD1 +1）")
	t.ok(J.every(["U7", "U6", "U2", "U1", "U8"], func(k): return int(_单位(c7, k).get("actedTurn", -1)) != int(c7.turn)),
		"⑦ TDD-1 不占任何人的行动（没人 actedTurn = 本回合）")

	var c7b := _ctx()
	c7b.待触发战术牌 = []
	_装手牌(c7b, ["TDD-1"])
	var 带盾 = c7b.enemies[1]
	带盾.hp = 3000.0
	c7b.enemies[0].hp = 1000.0
	Btl.加卡牌护盾(带盾, 99999.0)
	var 盾前 := float(带盾.get("shieldHp", 0.0))
	var 血前 := float(带盾.hp)
	_打(c7b, "TDD-1")
	t.ok(absf(float(带盾.hp) - 血前) < 0.001 and float(带盾.get("shieldHp", 0.0)) < 盾前,
		"⑦ TDD-1 的物理伤害先被护盾吃掉（HP 不动，护盾 %d → %d）" % [int(盾前), int(带盾.get("shieldHp", 0.0))])

	# 饱和攻击：本回合之后每张 TDD-1 追加一发
	var c7c := _ctx()
	c7c.待触发战术牌 = []
	_装手牌(c7c, ["F_MITH_V2_3", "TDD-1"])
	_友好血量(c7c)
	t.ok(_打(c7c, "F_MITH_V2_3").成功 and int(c7c.本回合饱和攻击) == 1,
		"⑦ 「饱和攻击」→ ctx.本回合饱和攻击 = 1")
	_打(c7c, "TDD-1")
	var 弹事件 := _攻击事件(c7c, "TDD-1")
	t.ok(弹事件.size() == 2 and J.some(弹事件, func(e): return e.get("饱和追加") == true),
		"⑦ 饱和攻击生效时，1 张 TDD-1 打出 2 发（本体 + 饱和追加，%d）" % 弹事件.size())
	t.ok(int(c7c.战况计数["打出TDD1"]) == 1, "⑦ 追加的那一发**不**再记一次「打出TDD1」（仍是 1）")

	# 泰莎的指令：下一张牌的连携效果触发两次，触发后倍率清回 1
	var c7d := _ctx()
	c7d.待触发战术牌 = []
	_装手牌(c7d, ["F_MITH_V2_9", "U_U2_1"])
	_打(c7d, "F_MITH_V2_9")
	t.ok(int(c7d.本回合连携触发倍率) == 2, "⑦ 「泰莎的指令」→ 本回合连携触发倍率 = 2")
	_打(c7d, "U_U2_1")
	t.ok(_手牌数(c7d, "TDD-1") == 3, "⑦ 下一张牌（呼叫达纳号）的连携效果触发两次 → 1 + 2 = 3 张 TDD-1")
	t.ok(int(c7d.本回合连携触发倍率) == 1, "⑦ 触发过之后倍率清回 1（只对「下一张牌」有效）")

	# 抽牌（作战开始）+ 卡里宁的判断
	var c7e := _ctx()
	c7e.待触发战术牌 = []
	_装手牌(c7e, ["F_MITH_V2_1"])
	var 抽前: int = c7e.战术手牌.size()
	t.ok(_打(c7e, "F_MITH_V2_1").成功, "⑦ 「作战开始」打出成功")
	var c7f := _ctx()
	c7f.待触发战术牌 = []
	var 牌库顶 := _卡("F_MITH_V2_7", c7f)
	牌库顶["当前冷却"] = 0
	var 冷却中的旧牌 := _卡("C_HEAVY_1", c7f)
	冷却中的旧牌["当前冷却"] = 2
	c7f.待触发战术牌 = [冷却中的旧牌, 牌库顶]
	_装手牌(c7f, ["F_MITH_V2_1"])
	t.ok(_打(c7f, "F_MITH_V2_1").成功 and _手牌数(c7f, "F_MITH_V2_7") == 1,
		"⑦ 抽牌：从待触发池挑第 1 张冷却已归零的牌发入手牌（跳过冷却中的那张）")
	t.ok(c7f.待触发战术牌.size() == 2,
		"⑦ 抽牌把那张牌从待触发池里取走了（池里剩：冷却中的旧牌 1 张 + 「作战开始」自己回库 1 张 = %d）" % c7f.待触发战术牌.size())
	var c7g := _ctx()
	c7g.turn = 2.0
	c7g.待触发战术牌 = []
	var 顶1 := _卡("C_HEAVY_1", c7g)
	var 顶2 := _卡("C_VANG_1", c7g)
	var 顶3 := _卡("F_MITH_V2_3", c7g)
	c7g.待触发战术牌 = [顶1, 顶2, 顶3]
	_装手牌(c7g, ["F_MITH_V2_7"])
	t.ok(_打(c7g, "F_MITH_V2_7").成功 and _手牌数(c7g, "F_MITH_V2_3") == 1,
		"⑦ 卡里宁的判断：看牌库顶 3 张，优先选走那张秘银牌（F_MITH_V2_3）")

	# 「看见了」/ 激光引导 / 专业军人 / 冷血
	var c7h := _ctx()
	c7h.待触发战术牌 = []
	_装手牌(c7h, ["U_U6_3"])
	t.ok(_打(c7h, "U_U6_3").成功 and int(c7h.get("下一次秘银攻击命中加成", 0)) == 15,
		"⑦ 「看见了」→ ctx.下一次秘银攻击命中加成 = 15")
	_装手牌(c7h, ["U_U6_1"])
	_友好血量(c7h)
	_打(c7h, "U_U6_1")
	t.ok(not c7h.has("下一次秘银攻击命中加成"), "⑦ 下一次秘银攻击真的吃掉了这 +15（加成被消费）")
	var c7i := _ctx()
	c7i.待触发战术牌 = []
	_装手牌(c7i, ["U_U8_1"])
	_打(c7i, "U_U8_1")
	t.ok(J.every(["U7", "U6", "U2", "U1", "U8"], func(k): return Calc.buffSum(_单位(c7i, k), "hit") >= 10.0),
		"⑦ 「激光引导」→ 本回合所有秘银成员命中 +10")

	var c7j := _ctx()
	c7j.待触发战术牌 = []
	_装手牌(c7j, ["U_U1_2"])
	_打(c7j, "U_U1_2")
	t.ok(absf(Calc.buffSum(_单位(c7j, "U1"), "dmgMul") - 0.25) < 0.001, "⑦ 「冷血」→ 克鲁佐本回合伤害 +25%")
	t.ok(int(_单位(c7j, "U1").get("_本回合不援护", -1)) == int(c7j.turn), "⑦ 「冷血」→ 本回合克鲁佐不援护队友（标记 = 本回合）")

	# ECS 隐形（隐身 + 本回合不攻击 + 抽 1 张牌）
	var c7k := _ctx()
	c7k.待触发战术牌 = []
	c7k.待触发战术牌 = [_卡("C_HEAVY_1", c7k)]
	_装手牌(c7k, ["U_U8_2"])
	var 手前: int = c7k.战术手牌.size()
	var 打隐 := _打(c7k, "U_U8_2")
	t.ok(打隐.成功 and J.truthy(_单位(c7k, "U8").get("_隐身")), "⑦ 「ECS 隐形」→ 杨._隐身 = true")
	t.ok(int(_单位(c7k, "U8").get("actedTurn", -1)) == int(c7k.turn), "⑦ 「ECS 隐形」→ 杨本回合不攻击（actedTurn = 本回合）")
	t.ok(c7k.战术手牌.size() == 手前, "⑦ 「ECS 隐形」抽 1 张牌（打出前 %d 张 → 打出后 %d 张：−1 打出 +1 抽到）" % [手前, c7k.战术手牌.size()])
	var 敌7 = c7k.enemies[0]
	for u in c7k.allies:
		u["_隐身"] = true
	_单位(c7k, "U8")["_隐身"] = true
	_单位(c7k, "U7")["_隐身"] = false
	var 选 = Ai.enemyAction(敌7, c7k)
	t.ok(选 != null and str(选.target.get("key")) == "U7", "⑦ 隐身：只有 U7 可见时，敌人只能选 U7")

	# ECM 干扰（敌方打秘银成员命中 −15）
	var c7l := _ctx()
	c7l.待触发战术牌 = []
	_装手牌(c7l, ["F_MITH_V2_5"])
	var 敌武: Dictionary = c7l.enemies[0].weapons[0].t
	var 命前 := float(Calc.hitRate(c7l.enemies[0], 敌武, _单位(c7l, "U7"), {"ctx": c7l}).raw)
	t.ok(_打(c7l, "F_MITH_V2_5").成功 and int(c7l.本回合敌方命中秘银减命中) == 15,
		"⑦ 「ECM 干扰」→ ctx.本回合敌方命中秘银减命中 = 15")
	var 命后 := float(Calc.hitRate(c7l.enemies[0], 敌武, _单位(c7l, "U7"), {"ctx": c7l}).raw)
	t.ok(absf(命前 - 命后 - 15.0) < 0.001, "⑦ ECM 干扰真的进了命中公式（%d → %d）" % [int(命前), int(命后)])

	# 紧急回收（HP 最低的秘银成员与对位换位）
	var c7m := _ctx()
	c7m.待触发战术牌 = []
	_装手牌(c7m, ["F_MITH_V2_6"])
	var 伤员 = _单位(c7m, "U8")
	伤员.hp = float(伤员.maxHp) * 0.3
	var 伤员位 := float(伤员.slot)
	var 对位们: Array = Fm.对位(伤员位)
	var 对位友 = J.find(c7m.allies, func(u): return u != null and u.hp > 0 and not is_same(u, 伤员) and J.inc(对位们, float(u.get("slot"))))
	t.ok(对位友 != null, "⑦ 紧急回收：U8（%d 号位）有对位队友（%s）" % [int(伤员位), "有" if 对位友 != null else "没有"])
	var 对位友位 := float(对位友.slot) if 对位友 != null else 0.0
	t.ok(_打(c7m, "F_MITH_V2_6").成功 and absf(float(伤员.slot) - 对位友位) < 0.001 and absf(float(对位友.slot) - 伤员位) < 0.001,
		"⑦ 紧急回收：两人站位真的换了（%d ↔ %d）" % [int(伤员位), int(对位友位)])
	t.ok(absf(float(伤员.get("pos", -1)) - float(伤员.slot)) < 0.001, "⑦ 紧急回收：`pos` 一起更新了")

	# 阵亡移除（绑定角色阵亡 → 从手牌 / 待触发池移除，且不可打出）
	var c7n := _ctx()
	c7n.待触发战术牌 = []
	_装手牌(c7n, ["U_U7_1"])
	var 待触 := _卡("U_U7_2", c7n)
	c7n.待触发战术牌 = [待触]
	_单位(c7n, "U7").hp = 0.0
	Btl.检查条件发牌(c7n, "回合开始", {"回合": c7n.turn})
	t.ok(_手牌数(c7n, "U_U7_1") == 0, "⑦ U7 阵亡 → 它的大招牌从战术手牌里被移除")
	t.ok(not J.some(c7n.待触发战术牌, func(x): return str(x.get("id")) == "U_U7_2"),
		"⑦ U7 阵亡 → 它的另一张角色牌从待触发池里被移除")
	t.ok(_日志有(c7n, "已阵亡"), "⑦ 移除时记了一条〔秘银 v0.2〕…已阵亡…日志（三层反馈的「即时」）")
	_单位(c7n, "U7").hp = 5000.0
	var 牌7 := _卡("U_U7_1", c7n)
	t.ok(Btl.不可打原因(c7n, 牌7) == "", "⑦ 复活之后这张牌又能打了（不可打原因 = 空）")
	_单位(c7n, "U7").hp = 0.0
	t.ok(str(Btl.不可打原因(c7n, 牌7)).contains("阵亡"), "⑦ 阵亡时 `不可打原因` 说得清楚（角色已阵亡）")
	_单位(c7n, "U7").hp = 5000.0

	# 合体技的三人条件（触发条件求值）
	var c7o := _ctx()
	c7o.战况计数["触发连携"] = 5
	var 合牌 := _卡("U_URUZ_TRI", c7o)
	t.ok(not Btl.是否满足卡牌触发条件(合牌, c7o, "回合开始", {}), "⑦ 合体技触发：触发连携 5 < 6 → 不发牌")
	c7o.战况计数["触发连携"] = 6
	t.ok(Btl.是否满足卡牌触发条件(合牌, c7o, "回合开始", {}), "⑦ 合体技触发：触发连携 6 且三人都在场 → 满足")
	_单位(c7o, "U6").hp = 0.0
	t.ok(not Btl.是否满足卡牌触发条件(合牌, c7o, "回合开始", {}), "⑦ 合体技触发：三人缺一个（U6 阵亡）→ 不满足")

	# ==================== ⑨ 整场压测（真的打一场 + 同种子确定性）====================
	# 每回合：把手里「能打的 v0.2 牌」依次打出去（上限 12 张，防死循环）→ 再走一遍自动行动。
	# 这一段是把开关真正开到底跑完整场，用来兜住其它 8 段没走到的运行时分支（合体技 / 饱和攻击 / 阵亡移除 …）。
	var 结果们 := []
	var 事件数们 := []
	for 遍 in range(2):
		var c9 := _ctx()
		var 护栏 := 0
		while c9.result == null and 护栏 < 40:
			护栏 += 1
			var 打了 := 0
			while 打了 < 12:
				var 目标 = null
				for x in c9.战术手牌:
					if x != null and Btl.卡可打吗(c9, x):
						目标 = x
						break
				if 目标 == null:
					break
				var r := Btl.打战术牌(c9, str(目标.get("_实例号", 目标.get("id"))))
				if not r.get("成功", false):
					break
				打了 += 1
			Setup.打一回合(c9)
		# 每层（遍）都存一份摘要用的事件数
		结果们.append(c9.result)
		事件数们.append(c9.log.size())
		t.ok(c9.result != null, "⑨ 第 %d 遍整场跑得完：%s / %s（第 %s 回合，事件 %d 条）" % [
			遍 + 1, str(c9.result.get("结果")) if c9.result != null else "没结果",
			str(c9.result.get("原因")) if c9.result != null else "", int(c9.turn), c9.log.size()])
		t.ok(J.some(c9.log, func(e): return e != null and str(e.get("文本", "")).contains("Uruz 连携作战")),
			"⑨ 第 %d 遍：整场里真的有 v0.2 的开局日志" % (遍 + 1))
		t.ok(J.some(c9.log, func(e): return e != null and e.get("类型") == "战术牌" and MithrilV02Cards.有(e.get("卡牌ID"))),
			"⑨ 第 %d 遍：整场里真的打出了 v0.2 战术牌" % (遍 + 1))
	t.ok(事件数们[0] == 事件数们[1], "⑨ 同种子（%d）两遍事件条数逐字相同（%d == %d）—— 开 v0.2 也是确定性的" % [种子, 事件数们[0], 事件数们[1]])
	t.ok(str(结果们[0]) == str(结果们[1]), "⑨ 同种子两遍的结果完全一致（%s）" % str(结果们[0]))

	# ==================== ⑧ 默认开关关着 ====================
	var c8 := _ctx关()
	t.ok(not Params.秘银v02开(c8), "⑧ 默认（不传 秘银v02）：Params.秘银v02开(ctx) = false")
	var 池8: Array = c8.战术牌池.map(func(x): return str(x.get("id")))
	t.ok(J.inc(池8, "F_MITH_1") and J.inc(池8, "F_MITH_2") and not J.some(池8, func(x): return MithrilV02Cards.有(x)),
		"⑧ 关着 → 装的是旧的 F_MITH_1 / F_MITH_2，一张 v0.2 牌都不装")
	t.ok(not c8.has("下张秘银牌降费") and not c8.has("本回合饱和攻击") and not c8.has("下张宗介大招降费"),
		"⑧ 关着 → 一个 v0.2 的 ctx 字段都不多（168 场黄金样例的 ctx 逐字不变）")
	t.ok(str(c8.战术手牌.map(func(x): return str(x.get("id")))).find("U_U") < 0, "⑧ 关着 → 初始手牌里没有 v0.2 角色牌")
	t.ok(not MithrilV02Cards.是旧秘银牌({"id": "C_HEAVY_1", "层级": "职业", "归属": "重装"}),
		"⑧ 旧牌识别不误伤：C_HEAVY_1 不是旧秘银牌")
	t.ok(MithrilV02Cards.是旧秘银牌({"id": "F_MITH_1", "层级": "势力", "归属": "秘银"}), "⑧ 旧牌识别：F_MITH_1 是旧秘银牌")
	# 关着时 MithrilV02Cards 的装填 / 效果执行器全部不产出
	t.ok(MithrilV02Cards.装填(c8, ["U7", "U2", "U6"]).size() > 0, "⑧ 装填函数本身还能算（但 btl 只在开关开着时调它）")
	c8.战术手牌 = [_卡("U_U7_1", c8)]
	c8.气势 = 999.0
	var 关打 := Btl.打战术牌(c8, "U_U7_1")
	t.ok(关打.成功 and not c8.战况计数.has("打出秘银大招")
			and int(_单位(c8, "U7").get("actedTurn", -1)) != int(c8.turn),
		"⑧ 关着时手动把 v0.2 牌塞进手牌打出：**没有**占行动、没有秘银大招牌计数（v0.2 效果一条都不产出）")
