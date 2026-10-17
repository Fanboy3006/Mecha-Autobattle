## DECK-1 / DECK-2 内核验收：单机牌组（阶段制 + 单机战意 + 主武器卡 / 衍生攻击卡 + 7 职业 + 敌方意图）。
## 全部在 `选项.单机牌组 = true` 的沙盒里做；关着的那条路径只验「一个字段都不多」。
extends RefCounted

const 我方 := [
	{"键": "B1", "位": 0, "等级": 10}, {"键": "B2", "位": 1, "等级": 10},
	{"键": "B3", "位": 2, "等级": 10}, {"键": "M2", "位": 3, "等级": 10},
	{"键": "M1", "位": 4, "等级": 10}, {"键": "CB2", "位": 5, "等级": 10},
	{"键": "B4", "位": 6, "等级": 10},
]
const 敌方 := [
	{"键": "fighter", "位": 0, "等级": 1}, {"键": "tank", "位": 1, "等级": 1},
	{"键": "sniper", "位": 4, "等级": 1},
]

func _ctx(额外: Dictionary = {}) -> Dictionary:
	var 选项 := {"单机牌组": true}
	for k in 额外.keys():
		选项[k] = 额外[k]
	return Setup.开局(我方, 敌方, 20261017, null, 选项)

func _单人(键: String) -> Dictionary:
	return Setup.开局([{"键": 键, "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 20261018, null, {"单机牌组": true})

func _必中(威力: float = 200.0) -> Dictionary:
	return DataFn.wp({"name": "测试必中", "fire": "map", "power": 威力, "hit": 100.0, "dmgType": "物理", "stat": "射击"})

func _白刃(hit: float = 100.0) -> Dictionary:
	return DataFn.wp({"name": "测试直射", "fire": "direct", "power": 200.0, "hit": hit, "dmgType": "物理", "stat": "射击"})

func _有日志(c: Dictionary, 片段: String) -> bool:
	return J.some(c.log, func(e): return e != null and str(e.get("文本", "")).contains(片段))

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db")
	_开关(t)
	_初始化(t)
	_阶段开始(t)
	_战意增减(t)
	_自由切机与主武互毁(t)
	_七职业(t)
	_结束回合(t)
	_意图与压制射击(t)
	# ---- DECK-4：秘银 v0.2 & ATX v0.2 卡表接入双排与双轨肉鸽成长 ----
	_秘银v02卡类分流(t)
	_秘银v02单机牌组(t)
	_ATXv02卡类分流(t)
	_ATXv02单机牌组(t)
	_ATX轮盘双响(t)
	_晋升解锁专属牌(t)
	_公有牌池与黑市(t)

## 一支队伍的沙盒 ctx（默认单机牌组；`ATXv02` 跟着单机牌组默认开）
func _队伍ctx(键们: Array, 等级: int = 10, 额外: Dictionary = {}) -> Dictionary:
	var 编成 := []
	for k in 键们:
		编成.append({"键": k, "位": 编成.size(), "等级": 等级})
	var 选项 := {"单机牌组": true}
	for k in 额外.keys():
		选项[k] = 额外[k]
	return Setup.开局(编成, [{"键": "fighter", "位": 0, "等级": 1}], 20261019, null, 选项)

## 一台机体「已解锁的专属牌」（牌库 + 手牌 + 弃牌堆三处都算：起手会抽走 2 张）
func _专属牌(u: Dictionary) -> Array:
	var 全: Array = []
	for 池键 in ["专属牌库", "专属手牌", "专属弃牌堆"]:
		for c in J.or_(u.get(池键), []):
			if c is Dictionary and c.get("等级需求") != null:
				全.append(c)
	return 全

## ==================== ⑨ 秘银 v0.2：每张牌都有 `卡类`，且三分类规则逐张成立 ====================
func _秘银v02卡类分流(t) -> void:
	var 表 := MithrilV02Cards.卡表()
	t.ok(表.size() == 26, "⑨ 秘银 v0.2 卡表 %d 张" % 表.size())
	var 允许 := ["主武器卡", "专属精神牌", "衍生攻击卡", "公有牌"]
	var 缺 := []
	var 错 := []
	for c in 表:
		var 类 := str(c.get("卡类", ""))
		if not 允许.has(类):
			缺.append(str(c.get("id")))
			continue
		var 种 := str(c.get("种类", ""))
		var 占: Variant = J.or_(c.get("占行动"), [])
		var 期望 := "公有牌"
		if 种 == "衍生" or bool(c.get("衍生", false)):
			期望 = "衍生攻击卡"
		elif 种 == "势力":
			期望 = "公有牌"
		elif 占 is Array and not (占 as Array).is_empty():
			期望 = "主武器卡"
		else:
			期望 = "专属精神牌"
		if 类 != 期望:
			错.append("%s(卡类=%s 期望=%s)" % [c.get("id"), 类, 期望])
	t.ok(缺.is_empty(), "⑨ 26 张牌**每一张**都带合法 `卡类`（主武器卡 / 专属精神牌 / 衍生攻击卡 / 公有牌）%s" % ("" if 缺.is_empty() else "；缺：" + str(缺)))
	t.ok(错.is_empty(), "⑨ 三分类规则逐张成立（占行动非空 → 主武器卡、占行动空 → 专属精神牌、势力 → 公有牌、衍生 → 衍生攻击卡）%s" % ("" if 错.is_empty() else "；错：" + str(错)))
	# 逐张点名（任务单点名的那几张）
	t.ok(MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U7_1"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U7_2"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U6_1"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U6_2"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U2_2"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U1_1"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U1_3"))
		and MithrilV02Cards.是主武器卡(MithrilV02Cards.卡("U_U8_3")),
		"⑨ 占行动的攻击牌 / 大招牌都是主武器卡（U7_1 / U7_2 / U6_1 / U6_2 / U2_2 / U1_1 / U1_3 / U8_3）")
	t.ok(MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U7_3"))
		and MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U6_3"))
		and MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U2_1"))
		and MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U1_2"))
		and MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U8_1"))
		and MithrilV02Cards.是专属精神牌(MithrilV02Cards.卡("U_U8_2")),
		"⑨ 纯增益 / 回战意 / 战术牌都是专属精神牌（U7_3 / U6_3 / U2_1 / U1_2 / U8_1 / U8_2）")
	t.ok(MithrilV02Cards.是衍生攻击卡(MithrilV02Cards.卡("TDD-1")), "⑨ TDD-1 导弹 = 衍生攻击卡")
	t.ok(FacMith.卡类(MithrilV02Cards.卡("U_U7_1")) == "主武器卡" and FacMith.是专属牌(MithrilV02Cards.卡("U_U7_3"))
		and not FacMith.是专属牌(MithrilV02Cards.卡("F_MITH_V2_1")),
		"⑨ 势力侧别名 `FacMith.卡类 / 是专属牌` 与卡表口径一致")
	t.ok(MithrilV02Cards.是主武器卡(MithrilV02Cards.合体技卡()), "⑨ 合体技【乌鲁兹·三角】= 主武器卡")
	var 势力全公有 := J.every(MithrilV02Cards.势力牌们(), func(c): return MithrilV02Cards.是公有牌(c))
	t.ok(势力全公有 and MithrilV02Cards.势力牌们().size() == 9, "⑨ 9 张秘银势力牌全部 = 公有牌")
	# 每台机体的专属牌候选（角色牌 + 合体技）
	t.ok(MithrilV02Cards.角色专属牌们("U7").size() == 4 and MithrilV02Cards.角色专属牌们("U2").size() == 4,
		"⑨ 角色专属牌：U7 / U2 各 3 张角色牌 + 合体技（占行动 U7/U2/U6）= 4 张")

## ==================== ⑩ 秘银 v0.2 接入单机牌组双排 + TDD-1 进公有手牌 ====================
func _秘银v02单机牌组(t) -> void:
	var c := _队伍ctx(["U7", "U6", "U2"], 10, {"秘银v02": true})
	t.ok(Params.秘银v02开(c) and Params.单机牌组_开(c), "⑩ 秘银 v0.2 + 单机牌组 两个开关都开着")
	var u7 = c.allies[0]
	var u2 = c.allies[2]
	var 库7 := _专属牌(u7)
	t.ok(not 库7.is_empty() and J.every(库7, func(x): return MithrilV02Cards.有(x.get("id"))),
		"⑩ U7 的 `专属牌库` 里装的是秘银 v0.2 的角色牌（%d 张）" % 库7.size())
	t.ok(J.some(库7, func(x): return str(x.get("卡类")) == "主武器卡")
		or J.some(库7, func(x): return str(x.get("卡类")) == "专属精神牌"),
		"⑩ 上排专属牌带 `卡类`（主武器卡 / 专属精神牌）")
	# 合体技跟着晋升出现在参与者（U7）的专属候选里
	t.ok(J.some(MithrilV02Cards.角色专属牌们("U7"), func(x): return str(x.get("id")) == "U_URUZ_TRI"),
		"⑩ 合体技【乌鲁兹·三角】在 U7 的专属候选里（占行动 U7/U2/U6）")
	# 下排：9 张秘银势力牌进公有牌库
	var 公有id: Array = c.公有牌库.map(func(x): return str(x.get("id")))
	var 势力数 := 0
	for i in range(1, 10):
		if J.inc(公有id, "F_MITH_V2_%d" % i):
			势力数 += 1
	t.ok(势力数 == 9, "⑩ 9 张秘银势力牌进了 `ctx.公有牌库`（%d）" % 势力数)
	t.ok(J.some(c.公有牌库, func(x): return str(x.get("id")) == "F_MITH_V2_1" and str(x.get("卡类")) == "公有牌"),
		"⑩ 公有牌库里的秘银势力牌 `卡类 = 公有牌`")
	# ---- TDD-1：置入 `公有手牌`，标 衍生攻击卡 ----
	c.公有手牌 = []
	var 置 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(c.公有手牌.size() == 1 and 置.size() == 1, "⑩ 置入 1 张 TDD-1 → `ctx.公有手牌` 1 张（下排）")
	var tdd = c.公有手牌[0]
	t.ok(str(tdd.get("id")) == "TDD-1" and str(tdd.get("卡类")) == "衍生攻击卡" and bool(tdd.get("是TDD1", false)),
		"⑩ TDD-1 在公有手牌里，`卡类 = 衍生攻击卡` / 是TDD1")
	t.ok(_有日志(c, "〔衍生牌〕置入公有手牌：【TDD-1 导弹】"), "⑩ 置入写了「公有手牌」日志")
	# 打出 TDD-1：不销毁主武器卡、自己销毁、推进秘银连携计数
	var 战意前 := float(u2.get("战意"))
	var 秘银牌数前 := int(c.get("本回合秘银牌数", 0))
	var TDD1前 := int(c.战况计数.get("打出TDD1", 0))
	u2["战意"] = 30.0
	var r打 := Btl.打出衍生攻击卡(c, u2.key, str(tdd.get("_实例号")))
	t.ok(r打.get("成功") == true, "⑩ 用 `打出衍生攻击卡` 打出公有手牌里的 TDD-1（%s）" % str(r打.get("原因", "")))
	t.ok(u2.get("主武器已销毁") == false, "⑩ 打 TDD-1 **不销毁主武器卡**（主武器已销毁 仍是 false）")
	t.ok(c.公有手牌.is_empty(), "⑩ TDD-1 打出后自己销毁（公有手牌空了）")
	t.ok(int(c.get("本回合秘银牌数", 0)) == 秘银牌数前 + 1, "⑩ 打 TDD-1 推进秘银连携计数：本回合秘银牌数 %d → %d" % [秘银牌数前, int(c.get("本回合秘银牌数", 0))])
	t.ok(int(c.战况计数.get("打出TDD1", 0)) == TDD1前 + 1, "⑩ 战况计数.打出TDD1 %d → %d" % [TDD1前, int(c.战况计数.get("打出TDD1", 0))])
	t.ok(u2.get("战意") == 30.0 - _战意费(tdd), "⑩ 只扣打出者自己的战意（30 → %s）" % u2.get("战意"))
	t.ok(战意前 == 0.0, "⑩ 对照：U2 开场战意 0")
	# 第三条路：`打战术牌` 也认公有手牌里的衍生攻击卡（同样不销毁主武器、自己销毁、推进连携计数）
	var 置三 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(置三.size() == 1 and c.公有手牌.size() == 1, "⑩ 再置入 1 张 TDD-1（公有手牌 1 张）")
	var 秘前 := int(c.get("本回合秘银牌数", 0))
	var 气前 := J.num0(u2.get("战意"))
	u2["战意"] = 20.0
	var r战术 := Btl.打战术牌(c, "TDD-1")
	t.ok(r战术.get("成功") == true and c.公有手牌.is_empty(),
		"⑩ `打战术牌` 也能打公有手牌里的 TDD-1（自己销毁；%s）" % str(r战术.get("原因", "")))
	t.ok(int(c.get("本回合秘银牌数", 0)) == 秘前 + 1, "⑩ 走 `打战术牌` 同样推进秘银连携计数（%d → %d）" % [秘前, int(c.get("本回合秘银牌数", 0))])
	t.ok(u2.get("主武器已销毁") == false, "⑩ 走 `打战术牌` 也不销毁主武器卡")
	t.ok(气前 >= 0.0, "⑩ 对照：上一张 TDD-1 打完后 U2 的战意 %s" % 气前)
	# 第四条路：`打出精神或公有牌` 也认公有手牌里的衍生攻击卡（自动转去衍生攻击卡那条路）
	var 置四 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(置四.size() == 1 and c.公有手牌.size() == 1, "⑩ 再置入 1 张 TDD-1（公有手牌 1 张）")
	var 秘前2 := int(c.get("本回合秘银牌数", 0))
	u2["战意"] = 20.0
	var r精神 := Btl.打出精神或公有牌(c, u2.key, "TDD-1")
	t.ok(r精神.get("成功") == true and c.公有手牌.is_empty(),
		"⑩ `打出精神或公有牌` 也能打公有手牌里的 TDD-1（自己销毁；%s）" % str(r精神.get("原因", "")))
	t.ok(int(c.get("本回合秘银牌数", 0)) == 秘前2 + 1 and u2.get("主武器已销毁") == false,
		"⑩ 走 `打出精神或公有牌` 同样推进秘银连携计数（%d → %d）且不销毁主武器卡" % [秘前2, int(c.get("本回合秘银牌数", 0))])
	# 公有手牌硬上限 8：满了就作废
	c.公有手牌 = []
	for i in range(8):
		c.公有手牌.append(Btl.克隆战术牌({"id": "JUNK_%d" % i, "名": "垫牌", "层级": "势力", "归属": "秘银", "耗气": 0.0}, c))
	t.ok(c.公有手牌.size() == 8, "⑩ 先把公有手牌垫到硬上限 8 张")
	var 置2 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(c.公有手牌.size() == 8 and J.some(置2, func(s): return str(s).contains("作废")),
		"⑩ 公有手牌满 8 张 → 再置入 TDD-1 直接作废（仍是 8 张）")
	# 场上没有秘银成员 → 秘银 v0.2 势力牌一张都不进公有牌库
	var c外 := _队伍ctx(["B1"], 10, {"秘银v02": true})
	t.ok(not J.some(c外.公有牌库, func(x): return str(x.get("id")).begins_with("F_MITH_V2_")),
		"⑩ 队伍里没有秘银成员 → 公有牌库里没有秘银 v0.2 势力牌")

func _战意费(card: Dictionary) -> float:
	return J.num0(card.get("战意", card.get("耗气")))

## 一张牌最外层 `效果` 组里第一个算子的 `威力`（倍率断言用；没有 = 0）
func _首个威力(card: Dictionary) -> float:
	var 效果: Array = card.get("效果") if card.get("效果") is Array else []
	if 效果.is_empty() or not (效果[0] is Dictionary):
		return 0.0
	var 组: Dictionary = 效果[0]
	var 全局: Array = 组.get("全局") if 组.get("全局") is Array else []
	if 全局.is_empty() or not (全局[0] is Dictionary):
		return 0.0
	return J.num0((全局[0] as Dictionary).get("威力"))

## ==================== ⑪ ATX v0.2：每张牌都有 `卡类`，且分类与规格表逐张对得上 ====================
func _ATXv02卡类分流(t) -> void:
	var 表 := FacAtx.卡表()
	t.ok(表.size() == 25, "⑪ ATX v0.2 卡表 %d 张（15 张角色牌 + 1 张合体技 + 9 张势力牌）" % 表.size())
	t.ok(FacAtx.角色牌们().size() == 15 and FacAtx.势力牌们().size() == 9, "⑪ 15 张角色牌 + 9 张势力牌")
	var 允许 := ["主武器卡", "专属精神牌", "衍生攻击卡", "公有牌"]
	var 缺 := []
	var 错 := []
	var 主武 := 0
	var 精神 := 0
	var 公有 := 0
	for c in 表:
		var 类 := str(c.get("卡类", ""))
		if not 允许.has(类):
			缺.append(str(c.get("id")))
			continue
		var 种 := str(c.get("种类", ""))
		var 占: Variant = J.or_(c.get("占行动"), [])
		var 期望 := "公有牌"
		if 种 == "势力":
			期望 = "公有牌"
		elif 种 == "合体技":
			期望 = "主武器卡"
		elif 占 is Array and not (占 as Array).is_empty():
			期望 = "主武器卡"
		else:
			期望 = "专属精神牌"
		if 类 != 期望:
			错.append("%s(卡类=%s 期望=%s)" % [c.get("id"), 类, 期望])
		match 类:
			"主武器卡": 主武 += 1
			"专属精神牌": 精神 += 1
			"公有牌": 公有 += 1
	t.ok(缺.is_empty(), "⑪ 25 张牌**每一张**都带合法 `卡类`%s" % ("" if 缺.is_empty() else "；缺：" + str(缺)))
	t.ok(错.is_empty(), "⑪ ATX 三分类规则逐张成立%s" % ("" if 错.is_empty() else "；错：" + str(错)))
	t.ok(主武 == 8 and 精神 == 8 and 公有 == 9,
		"⑪ 分类计数：主武器卡 8（7 张攻击大招 + 合体技）/ 专属精神牌 8 / 公有牌 9（实际 %d / %d / %d）" % [主武, 精神, 公有])
	# 任务单点名的攻击大招 + 合体技
	var 攻击大招 := ["U_ATX_1", "U_ATX_2", "U_ATX_4", "U_ATX_7", "U_ATX_10", "U_ATX_13", "U_ATX_14"]
	var 漏 := []
	for id in 攻击大招:
		if not FacAtx.是主武器卡(FacAtx.卡(id)):
			漏.append(id)
	t.ok(漏.is_empty() and FacAtx.是主武器卡(FacAtx.合体技卡()),
		"⑪ 全部攻击大招 + 合体技【轮盘双响】= 主武器卡%s" % ("" if 漏.is_empty() else "；漏：" + str(漏)))
	var 战术排 := ["U_ATX_3", "U_ATX_5", "U_ATX_6", "U_ATX_8", "U_ATX_9", "U_ATX_11", "U_ATX_12", "U_ATX_15"]
	var 漏2 := []
	for id in 战术排:
		if not FacAtx.是专属精神牌(FacAtx.卡(id)):
			漏2.append(id)
	t.ok(漏2.is_empty(), "⑪ 战术 / 增益 / 回战意牌 = 专属精神牌%s" % ("" if 漏2.is_empty() else "；漏：" + str(漏2)))
	var 合 := FacAtx.合体技卡()
	t.ok(J.or_(合.get("占行动"), []) == ["A1", "A2"] and int(合.get("耗气")) == 35 and int(合.get("冷却")) == 5,
		"⑪ 合体技【轮盘双响】占行动 A1+A2、费用 35、冷却 5")
	var 势力全公有 := J.every(FacAtx.势力牌们(), func(c): return FacAtx.是公有牌(c) and str(c.get("归属")) == "ATX")
	t.ok(势力全公有, "⑪ 9 张 ATX 势力牌全部 `卡类 = 公有牌` / `归属 = ATX`")
	# ATX 角色专属候选
	t.ok(FacAtx.角色专属牌们("A1").size() == 4 and FacAtx.角色专属牌们("A3").size() == 3,
		"⑪ 角色专属牌：A1 = 3 张 ATX 角色牌 + 合体技 = 4 张；A3 = 3 张")

## ==================== ⑫ ATX v0.2 接入单机牌组双排 + 读牌 / W17·中继 ====================
func _ATXv02单机牌组(t) -> void:
	var c := _队伍ctx(["A1", "A2", "A3"], 10)
	t.ok(Params.ATXv02开(c), "⑫ 单机牌组模式默认开着 ATX v0.2（`Params.ATXv02开`）")
	var a1 = c.allies[0]
	var a3 = c.allies[2]
	var 库1 := _专属牌(a1)
	t.ok(J.every(库1, func(x): return FacAtx.有(x.get("id"))), "⑫ A1 上排专属牌库装的是 ATX v0.2 角色牌（%d 张）" % 库1.size())
	t.ok(J.some(库1, func(x): return str(x.get("id")) == "U_ATX_1" and str(x.get("卡类")) == "主武器卡"),
		"⑫ A1 的 Lv10 专属牌是【左轮打桩机·全弹】（主武器卡）")
	t.ok(J.some(_专属牌(a3), func(x): return str(x.get("id")) == "U_ATX_8" and str(x.get("卡类")) == "专属精神牌"),
		"⑫ A3 的 Lv10 专属牌是【烟雾弹】（专属精神牌）")
	var 公有id: Array = c.公有牌库.map(func(x): return str(x.get("id")))
	var 势力数 := 0
	for i in range(1, 10):
		if J.inc(公有id, "F_ATX_V2_%d" % i):
			势力数 += 1
	t.ok(势力数 == 9, "⑫ 9 张 ATX 势力牌进了 `ctx.公有牌库`（%d）" % 势力数)
	# 关掉 ATX v0.2 → 一张都不装（开关有效）
	var c关 := _队伍ctx(["A1", "A2"], 10, {"ATXv02": false})
	t.ok(not Params.ATXv02开(c关) and J.every(c关.allies, func(u): return not J.some(_专属牌(u), func(x): return FacAtx.有(x.get("id")))),
		"⑫ `ATXv02: false` → ATX v0.2 一张都不装进上排")
	t.ok(not J.some(c关.公有牌库, func(x): return str(x.get("id")).begins_with("F_ATX_V2_")),
		"⑫ `ATXv02: false` → 公有牌库里也没有 ATX v0.2 势力牌")
	# ---- 读牌：用 `Btl.算意图` 给瞄准 ATX 的敌人 −30 命中 ----
	var c2 := _队伍ctx(["A1", "A2"], 10)
	var a1b = c2.allies[0]
	a1b["战意"] = 30.0
	var 意图 := Btl.算意图(c2)
	var 瞄ATX := {}
	for 条 in 意图:
		if 条 is Dictionary and 条.get("目标") != null:
			瞄ATX[str(条.get("单位"))] = true
	c2.公有手牌.append(Btl.克隆战术牌(FacAtx.卡("F_ATX_V2_4"), c2))
	var r读 := Btl.打出精神或公有牌(c2, a1b.key, "F_ATX_V2_4")
	t.ok(r读.get("成功") == true, "⑫ 打出【读牌】成功（%s）" % str(r读.get("原因", "")))
	t.ok(not 瞄ATX.is_empty() and J.every(瞄ATX.keys(), func(k):
		var e = J.find(c2.enemies, func(x): return str(x.get("key")) == str(k))
		return e != null and J.some(e.get("buffs"), func(b): return b.get("src") == "读牌" and J.num0(b.get("hit")) == -30.0)),
		"⑫ 读牌用 `Btl.算意图` 找到瞄准 ATX 的敌人（%s），给它们挂 hit −30" % [瞄ATX.keys()])
	t.ok(_有日志(c2, "〔读牌〕"), "⑫ 读牌写了日志")
	# ---- W17·中继：速度最高的另一名 ATX 成员再动（主武器卡回手），每回合 1 次 ----
	var c3 := _队伍ctx(["A1", "A2", "A3"], 10)
	var a3c = c3.allies[2]
	var 甲 = c3.allies[0]
	var 乙 = c3.allies[1]
	a3c["战意"] = 40.0
	甲["主武器已销毁"] = true
	乙["主武器已销毁"] = true
	var 牌 = Btl.克隆战术牌(FacAtx.卡("U_ATX_9"), c3)
	a3c.专属手牌.append(牌)
	var r再 := Btl.打出精神或公有牌(c3, a3c.key, "U_ATX_9")
	t.ok(r再.get("成功") == true, "⑫ 打出【W17·中继】成功（%s）" % str(r再.get("原因", "")))
	var 再动条: Array = c3.log.filter(func(e): return e is Dictionary and e.get("类型") == "再动")
	t.ok(再动条.size() == 1, "⑫ W17·中继触发了 1 次再动")
	var 目标键 := str(再动条[0].get("目标")) if 再动条.size() == 1 else ""
	var 目标 = J.find(c3.allies, func(u): return str(u.get("key")) == 目标键)
	t.ok(目标 != null and 目标.get("主武器已销毁") == false and int(目标.get("被W17再动回合", -1)) == int(c3.turn),
		"⑫ 被再动的 ATX 成员（%s）`主武器已销毁 = false`（主武器卡回手）" % 目标键)
	var 速度们: Array = J.or_(c3.allies, []).filter(func(u): return not is_same(u, a3c)).map(func(u): return Units.speedOf(u))
	t.ok(目标 != null and Units.speedOf(目标) >= J.max_of(速度们),
		"⑫ 被再动的是「速度最高的另一名 ATX 成员」（速度 %s）" % (Units.speedOf(目标) if 目标 != null else -1))
	t.ok(int(a3c.get("W17已触发回合", -1)) == int(c3.turn), "⑫ 本回合 W17·中继已经触发过（每回合只能 1 次）")
	# 同回合再打一张：不再触发（每回合 1 次）
	甲["主武器已销毁"] = true
	var 牌2 = Btl.克隆战术牌(FacAtx.卡("U_ATX_9"), c3)
	a3c.专属手牌.append(牌2)
	a3c["战意"] = 40.0
	Btl.打出精神或公有牌(c3, a3c.key, "U_ATX_9")
	t.ok(c3.log.filter(func(e): return e is Dictionary and e.get("类型") == "再动").size() == 1,
		"⑫ 同一回合再打一次 W17·中继：再动日志仍是 1 条（每回合只能 1 次）")
	# ATX 每回合重置：本回合 / 上回合的打空基准都翻新，一次性标记（二次下注 / 庄家通吃）清掉
	var c4 := _队伍ctx(["A1"], 10)
	Btl.开始我方阶段(c4)
	c4["ATX二次下注"] = true
	Btl.开始我方阶段(c4)
	t.ok(c4.has("ATX本回合起始打空") and c4.has("ATX上回合打空") and not c4.has("ATX二次下注"),
		"⑫ ATX 每回合重置：打空基准翻新、一次性标记（二次下注）清掉")
	# 幸运连号：下一张 ATX 角色牌费用 −10（吃一次就清）
	var c5 := _队伍ctx(["A1"], 20)
	var a1d = c5.allies[0]
	c5.公有手牌.append(Btl.克隆战术牌(FacAtx.卡("F_ATX_V2_9"), c5))
	var r运 := Btl.打出精神或公有牌(c5, a1d.key, "F_ATX_V2_9")
	t.ok(r运.get("成功") == true and int(c5.get("下张ATX角色牌降费", 0)) == 10,
		"⑫ 打出【幸运连号】→ 下一张 ATX 角色牌降费 10（%s）" % str(r运.get("原因", "")))
	a1d.专属手牌.append(Btl.克隆战术牌(FacAtx.卡("U_ATX_3"), c5))
	a1d["战意"] = 3.0
	var r孤 := Btl.打出精神或公有牌(c5, a1d.key, "U_ATX_3")
	t.ok(r孤.get("成功") == true and int(c5.get("下张ATX角色牌降费", 0)) == 0,
		"⑫ 降费真的生效：耗气 5 的【孤注一掷】按 0 费打出（战意 3 → %s），降费状态已清" % a1d.get("战意"))

## ==================== ⑬ ATX【轮盘双响】合体技：两人都要活着且都没动过 ====================
func _ATX轮盘双响(t) -> void:
	var c := _队伍ctx(["A1", "A2"], 30)
	var a1 = c.allies[0]
	var a2 = c.allies[1]
	a1["战意"] = 60.0
	a2["战意"] = 0.0
	var 合 = Btl.克隆战术牌(FacAtx.合体技卡(), c)
	a1.专属手牌.append(合)
	var r := Btl.打出主武器卡(c, a1.key, "U_ATX_COMBO")
	t.ok(r.get("成功") == true, "⑬ 打出合体技【轮盘双响】成功（%s）" % str(r.get("原因", "")))
	t.ok(r.get("合体技") == true and J.or_(r.get("参与者"), []) == ["A1", "A2"], "⑬ 参与者 = A1 + A2")
	t.ok(a1.get("主武器已销毁") == true and a2.get("主武器已销毁") == true,
		"⑬ 打完把**两名**参与者的 `主武器已销毁` 都置为 true")
	# 只扣发起者的战意（命中 / 击破回战意照 DECK-1 的 +2 / +10 照常算，所以给一个上界）
	var 命中回: float = Params.命中战意() * 3.0 + Params.击破战意()
	t.ok(float(a2.get("战意")) == 0.0 and float(a1.get("战意")) >= 60.0 - 35.0
		and float(a1.get("战意")) <= 60.0 - 35.0 + 命中回,
		"⑬ 只扣**发起者** A1 的战意（60 − 35 = 25，命中 / 击破回战意后 %s）；A2 一分不扣（%s）" % [a1.get("战意"), a2.get("战意")])
	t.ok(_有日志(c, "〔合体技〕"), "⑬ 合体技写了日志")
	# 参与者已动过 → 打不出
	a1["主武器已销毁"] = false
	a2["主武器已销毁"] = true
	a1["战意"] = 60.0
	var 合2 = Btl.克隆战术牌(FacAtx.合体技卡(), c)
	a1.专属手牌.append(合2)
	var r2 := Btl.打出主武器卡(c, a1.key, "U_ATX_COMBO")
	t.ok(r2.get("成功") == false and str(r2.get("原因", "")).contains("已销毁"),
		"⑬ A2 本回合已经动过 → 合体技打不出（原因：%s）" % str(r2.get("原因", "")))
	# 参与者阵亡 → 打不出
	a2["hp"] = 0.0
	a1["主武器已销毁"] = false
	var 合3 = Btl.克隆战术牌(FacAtx.合体技卡(), c)
	a1.专属手牌.append(合3)
	var r3 := Btl.打出主武器卡(c, a1.key, "U_ATX_COMBO")
	t.ok(r3.get("成功") == false and str(r3.get("原因", "")).contains("不在场"),
		"⑬ A2 已阵亡 → 合体技打不出（原因：%s）" % str(r3.get("原因", "")))
	t.ok(a1.get("主武器已销毁") == false, "⑬ 打不出时一个状态都不改（A1 主武器已销毁 仍为 false）")
	# ---- 秘银合体技【乌鲁兹·三角】走同一条合体技路：三人全销毁 ----
	var c2 := _队伍ctx(["U7", "U2", "U6"], 30, {"秘银v02": true})
	var u7 = c2.allies[0]
	u7["战意"] = 60.0
	var 秘合 = Btl.克隆战术牌(MithrilV02Cards.合体技卡(), c2)
	u7.专属手牌.append(秘合)
	var r秘 := Btl.打出主武器卡(c2, u7.key, "U_URUZ_TRI")
	t.ok(r秘.get("成功") == true, "⑬ 秘银合体技【乌鲁兹·三角】也走合体技那条路（%s）" % str(r秘.get("原因", "")))
	t.ok(J.every(c2.allies, func(u): return u.get("主武器已销毁") == true),
		"⑬ 秘银合体技打完：U7 / U2 / U6 三人的 `主武器已销毁` 都是 true")

## ==================== ⑭ 晋升 Lv10 → Lv20 → Lv30：解锁专属牌 + 抬倍率 ====================
func _晋升解锁专属牌(t) -> void:
	# A3 没有数据库里的老角色牌 → 专属牌正好 3 张，逐档解锁
	var 十 := DeckBuilder.unit_exclusive_cards("A3", 10)
	var 二十 := DeckBuilder.unit_exclusive_cards("A3", 20)
	var 三十 := DeckBuilder.unit_exclusive_cards("A3", 30)
	t.ok(十.size() == 1 and 二十.size() == 2 and 三十.size() == 3,
		"⑭ Lv10 / Lv20 / Lv30 的专属牌张数 = 1 / 2 / 3（实际 %d / %d / %d）" % [十.size(), 二十.size(), 三十.size()])
	t.ok(float(十[0].get("倍率")) == 1.0 and float(二十[0].get("倍率")) == 1.2 and float(三十[0].get("倍率")) == 1.4,
		"⑭ 卡牌威力倍率随等级抬升：1.0 → 1.2 → 1.4")
	t.ok(J.every(十, func(x): return int(x.get("等级需求")) == 10)
		and J.every(二十.filter(func(x): return int(x.get("等级需求")) == 20), func(x): return x.get("名") != null)
		and DeckBuilder.新解锁专属牌("A3", 20).size() == 1
		and DeckBuilder.新解锁专属牌("A3", 30).size() == 1,
		"⑭ 「新解锁」只报这一次晋升新拿到的那 1 张（Lv20 / Lv30 各 1 张）")
	t.ok(str(十[0].get("卡类")) == "专属精神牌" and str(二十[0].get("卡类")) == "专属精神牌"
		and str(三十[2].get("卡类")) == "主武器卡",
		"⑭ 三分类逐档带出来：Lv10【烟雾弹】= 精神牌、Lv30【幻影凤凰】= 主武器卡（%s / %s / %s）" % [十[0].get("卡类"), 二十[1].get("卡类"), 三十[2].get("卡类")])
	# 倍率真的乘进了牌面威力
	var 牌 := DeckBuilder.应用等级倍率(FacAtx.卡("U_ATX_13"), 1.4)
	var 原威力: float = _首个威力(FacAtx.卡("U_ATX_13"))
	var 新威力: float = _首个威力(牌)
	t.ok(absf(新威力 - 原威力 * 1.4) < 0.01 and float(牌.get("等级倍率")) == 1.4,
		"⑭ 倍率真的乘进了 `效果` 里的威力（%s → %s）" % [原威力, 新威力])
	# 晋升：只写返回字典，不污染名册 / 存档
	var s := RosterManager.new_run(20261010, "无")
	s.roster["A3"] = {"key": "A3", "lv": 10, "hpRatio": 1.0}
	s.hope = 99
	s.tickets.append({"id": 1, "类": "势力", "名": "ATX", "档": null, "来源": "测试"})
	s.tickets.append({"id": 2, "类": "势力", "名": "ATX", "档": null, "来源": "测试"})
	var 键前: Array = s.roster["A3"].keys()
	var 存档前: int = s.to_dict().size()
	var 升 := RosterManager.promote(s, "A3")
	t.ok(升.get("ok") == true and int(升.get("到")) == 20, "⑭ A3 Lv10 → Lv20 晋升成功")
	var 键后: Array = s.roster["A3"].keys()
	键前.sort()
	键后.sort()
	t.ok(键前 == 键后 and 键后 == ["hpRatio", "key", "lv"],
		"⑭ 名册条目仍是 `{key, lv, hpRatio}` 三个键（晋升没有污染存档契约）%s" % [键后])
	t.ok(s.to_dict().size() == 存档前, "⑭ `state.to_dict()` 的键数不变（%d）" % 存档前)
	t.ok(J.or_(升.get("解锁专属牌"), []).size() == 1
		and str(J.or_(升.get("解锁专属牌"), [])[0].get("id")) == "U_ATX_9",
		"⑭ 晋升结果里报了「解锁专属牌」：Lv20 解锁【W17·中继】")
	t.ok(float(升.get("等级倍率")) == 1.2 and J.or_(升.get("专属牌库"), []).size() == 2,
		"⑭ 晋升结果里带着倍率 1.2 与新的专属牌库（2 张）")
	var 再升 := RosterManager.promote(s, "A3")
	t.ok(再升.get("ok") == true and int(再升.get("到")) == 30
		and str(J.or_(再升.get("解锁专属牌"), [])[0].get("id")) == "U_ATX_7"
		and float(再升.get("等级倍率")) == 1.4,
		"⑭ Lv20 → Lv30：解锁【幻影凤凰】、倍率 1.4")
	# Setup 按等级把专属牌装进 `专属牌库`（Lv10 vs Lv30）
	var c10 := _队伍ctx(["A3"], 10)
	var c30 := _队伍ctx(["A3"], 30)
	var 专10 := _专属牌(c10.allies[0])
	var 专30 := _专属牌(c30.allies[0])
	t.ok(专10.size() == 1 and 专30.size() == 3,
		"⑭ 开战时按 `u.lv` 装专属牌库：Lv10 = 1 张、Lv30 = 3 张（%d / %d）" % [专10.size(), 专30.size()])
	t.ok(J.every(专30, func(x): return float(x.get("等级倍率", 0.0)) == 1.4),
		"⑭ Lv30 的专属牌全部带 `等级倍率 = 1.4`")
	t.ok(not J.some(专10, func(x): return float(x.get("等级倍率", 1.0)) != 1.0),
		"⑭ Lv10 的专属牌倍率仍是 1.0（没有提前抬）")
	t.ok(J.every(专30, func(x): return str(x.get("卡类")) != ""), "⑭ 装进专属牌库的每张牌都带 `卡类`")

## ==================== ⑮ 下排公有牌池：三选一只出公有牌 + 黑市买牌 / 删牌 ====================
func _公有牌池与黑市(t) -> void:
	var s := RosterManager.new_run(20261010, "无")
	# 老口径不变（public_only = false 且这一局没开单机牌组）→ 仍会出角色牌
	var 老 := DeckBuilder.offer_cards(s, "A1", 3)
	t.ok(老.size() == 3 and J.inc(老, "U_A1"), "⑮ 老口径三选一照旧会出角色牌（%s）" % [老])
	var 公 := DeckBuilder.offer_public_cards(s, "A1", 3)
	t.ok(公.size() == 3 and not J.inc(公, "U_A1"), "⑮ `offer_public_cards` 不出角色牌（%s）" % [公])
	var 全公有 := true
	for id in 公:
		var c := DeckBuilder.找到(str(id))
		if str(c.get("层级")) == "角色" or not DeckBuilder.是公有牌(c):
			全公有 = false
	t.ok(全公有, "⑮ 公有牌三选一里每张都是 职业 / 势力 / 统帅 层级")
	# 这一局标了单机牌组 → 默认三选一也自动只出公有牌
	s.map_data["_rogue"] = {"单机牌组": true}
	var 自带 := DeckBuilder.offer_cards(s, "A1", 3)
	t.ok(not J.inc(自带, "U_A1"), "⑮ 这一局开了单机牌组 → 默认三选一自动只出公有牌（%s）" % [自带])
	# 黑市买牌：只碰公有牌池
	var s2 := RosterManager.new_run(20261010, "无")
	s2.carbon = 40
	var 价 := NodeResolver.黑市牌价(s2, "F_ATX_1")
	var 买 := NodeResolver.黑市买牌(s2, "F_ATX_1")
	t.ok(买.get("ok") == true and s2.tactical_deck.has("F_ATX_1") and s2.carbon == 40 - 价,
		"⑮ 黑市买牌成功：公有牌池多 1 张、源碳 40 → %d（价 %d）" % [s2.carbon, 价])
	var 买角 := NodeResolver.黑市买牌(s2, "U_A1")
	t.ok(买角.get("ok") == false and str(买角.get("why", "")).contains("公有牌"),
		"⑮ 黑市不卖角色牌（%s）" % str(买角.get("why", "")))
	var 买重 := NodeResolver.黑市买牌(s2, "F_ATX_1")
	t.ok(买重.get("ok") == false, "⑮ 同一张公有牌不会重复买（%s）" % str(买重.get("why", "")))
	# 黑市删牌
	var 碳前 := s2.carbon
	var 删价 := NodeResolver.黑市删牌价(s2)
	var 删 := NodeResolver.黑市删牌(s2, "F_ATX_1")
	t.ok(删.get("ok") == true and not s2.tactical_deck.has("F_ATX_1") and s2.carbon == 碳前 - 删价,
		"⑮ 黑市删牌成功：公有牌池少 1 张、源碳 −%d" % 删价)
	var 删无 := NodeResolver.黑市删牌(s2, "F_ATX_1")
	t.ok(删无.get("ok") == false, "⑮ 删不存在的牌被拒（%s）" % str(删无.get("why", "")))
	# 三选一 / 黑市都不消耗随机数（纯函数口径）
	var s3 := RosterManager.new_run(20261010, "无")
	var a := DeckBuilder.offer_public_cards(s3, "A1", 3)
	var b := DeckBuilder.offer_public_cards(s3, "A1", 3)
	t.ok(a == b, "⑮ 公有牌三选一是纯函数（连算两遍逐项相同）")

# ==================== ① 总开关与标尺 ====================
func _开关(t) -> void:
	t.ok(Params.单机牌组_开(null) == false, "① 总开关默认关：单机牌组_开(null) == false")
	t.ok(Params.单机牌组_开({}) == false, "① 空 ctx 也是关")
	t.ok(Params.单机牌组_开({"单机牌组": true}) == true, "① ctx.单机牌组 == true → 开")
	t.ok(Params.单机牌组_开({"选项": {"单机牌组": true}}) == true, "① ctx.选项.单机牌组 == true → 开")
	t.ok(Params.战意上限() == 100.0 and Params.开场战意() == 0.0 and Params.回合初战意() == 5.0,
		"① 战意标尺：上限 100 / 开场 0 / 回合初 +5")
	t.ok(Params.命中战意() == 2.0 and Params.被击战意() == 2.0 and Params.闪避战意() == 2.0 and Params.击破战意() == 10.0,
		"① 战意标尺：命中 / 被击 / 闪避 +2、击破 +10")
	t.ok(Params.专属起手() == 2.0 and Params.专属每回合抽() == 1.0 and Params.专属手牌上限() == 4.0,
		"① 上排：起手 2 / 每回合 1 / 上限 4")
	t.ok(Params.公有起手() == 3.0 and Params.公有每回合抽() == 1.0 and Params.公有手牌自然上限() == 6.0 and Params.公有手牌硬上限() == 8.0,
		"① 下排：起手 3 / 每回合 1 / 自然上限 6 / 硬上限 8")
	t.ok(Params.指挥公有减费() == 5.0, "① 指挥机打公有牌：战意 -5")
	# 关着 = 一个字段都不多（黄金样例与旧测试零改动）
	var 关 := Setup.开局(我方, 敌方, 20261017, null, {})
	t.ok(not 关.has("单机牌组") and not 关.has("公有手牌") and not 关.has("敌方意图"),
		"① 关着时 ctx 不多出 单机牌组 / 公有手牌 / 敌方意图 字段")
	t.ok(J.every(关.allies, func(u): return not u.has("战意") and not u.has("主武器已销毁")),
		"① 关着时单位不多出 战意 / 主武器已销毁 字段")

# ==================== ② 开局初始化 ====================
func _初始化(t) -> void:
	var c := _ctx()
	t.ok(c.get("单机牌组") == true and str(c.get("阶段")) == "PLAYER_MAIN",
		"② 开局：ctx.单机牌组 == true、阶段 = PLAYER_MAIN")
	t.ok(c.公有手牌.size() == 3 and c.公有弃牌堆.is_empty() and c.公有牌库.size() > 0,
		"② 公有牌：起手 3 张、弃牌堆空、牌库有货")
	var 全对 := true
	for u in c.allies:
		var ok: bool = (u.get("战意") == 0.0 and u.get("战意上限") == 100.0
			and u.get("主武器已销毁") == false and u.get("连续攻击已用") == false
			and u.专属手牌.size() == 2 and u.专属弃牌堆.is_empty()
			and u.专属牌库.size() >= 0 and (u.专属牌库.size() + u.专属手牌.size()) >= 2
			and u.get("衍生手牌") is Array)
		if not ok:
			全对 = false
	t.ok(全对, "② 每台我方：战意 0 / 主武器已销毁 false / 连续攻击已用 false / 专属起手 2 张 / 双库齐备")
	t.ok(Units.unit_class(c.allies[2], c) == "维修" and str(c.allies[2].get("tags", {}).get("战斗分类", "")) == "维修",
		"② 维诺（B3）在单机牌组下归【维修】（tags.战斗分类 也改成维修）")
	t.ok(Units.unit_class(c.allies[0], c) == "近卫" and Units.unit_class(c.allies[1], c) == "尖兵"
		and Units.unit_class(c.allies[3], c) == "重装" and Units.unit_class(c.allies[4], c) == "指挥"
		and Units.unit_class(c.allies[5], c) == "狙击" and Units.unit_class(c.allies[6], c) == "特种",
		"② 其余职业不变：近卫 / 尖兵 / 重装 / 指挥 / 狙击 / 特种")
	t.ok(Params.单机牌组_职业("B3", c) == "维修" and Params.单机牌组_职业("M2", c) == "重装",
		"② Params.单机牌组_职业：键也能查（B3 → 维修；M2 仍为重装）")
	t.ok(not Units.unit_class("B3", null) == "维修", "② 关着时 B3 仍是原职业（不自动变维修）")
	var b3 = c.allies[2]
	t.ok(J.some(b3.weapons, func(e): return e is Dictionary and e.t.name == "紧急修理"),
		"② 维修机有常驻主武器卡【紧急修理】")
	t.ok(J.some(b3.衍生手牌, func(x): return str(x.get("名", "")) == "应急补丁"), "② 维修机起手带衍生卡【应急补丁】")
	t.ok(str(c.allies[3].weapons[-1].t.name) == "铁壁护卫", "② 重装机有常驻主武器卡【铁壁护卫】")
	# A5（库斯哈）带治疗武器但保留【指挥】
	var a5 := Setup.开局([{"键": "A5", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 3, null, {"单机牌组": true})
	t.ok(Units.unit_class(a5.allies[0], a5) == "指挥" and not J.some(a5.allies[0].weapons, func(e): return e.t.name == "紧急修理"),
		"② A5（库斯哈）带治疗武器但保留【指挥】，不变成维修")
	# 单台单位也能改（显式标记）
	var m2: Dictionary = Units.makeUnit("M2", "ally", 1.0, 10.0)
	m2["单机牌组职业"] = "维修"
	t.ok(Units.unit_class(m2, {"单机牌组": true}) == "维修", "② 显式标记 单机牌组职业 = 维修 的 M2 也能变维修")

# ==================== ③ 开始我方阶段 ====================
func _阶段开始(t) -> void:
	var c := _ctx()
	var 前回合: float = c.turn
	var 前公手: int = c.公有手牌.size()
	Btl.开始我方阶段(c)
	t.ok(c.turn == 前回合 + 1.0, "③ 开始我方阶段：回合 +1（%s → %s）" % [前回合, c.turn])
	t.ok(J.every(c.allies, func(u): return u.get("战意") == 5.0), "③ 全体战意 0 → 5")
	t.ok(J.every(c.allies, func(u): return u.专属手牌.size() == 3), "③ 专属手牌各抽 1 张（2 → 3）")
	t.ok(c.公有手牌.size() == 前公手 + 1, "③ 公有手牌抽 1 张（3 → 4）")
	t.ok(str(c.get("阶段")) == "PLAYER_MAIN", "③ 抽完牌回到 PLAYER_MAIN")
	var 狙 = c.allies[5]
	t.ok(J.some(狙.衍生手牌, func(x): return str(x.get("名", "")) == "援护射击"), "③ 狙击每回合派发【援护射击】")
	t.ok(J.some(c.allies[6].衍生手牌, func(x): return str(x.get("名", "")) == "战术副武"), "③ 特种每回合派发【战术副武】")
	var 数量: int = 狙.衍生手牌.size()
	Btl.开始我方阶段(c)
	t.ok(c.turn == 前回合 + 2.0 and J.every(c.allies, func(u): return u.get("战意") == 10.0),
		"③ 再来一次：回合 +1、战意 5 → 10")
	t.ok(狙.衍生手牌.size() == 数量, "③ 衍生卡「只补不叠」（同一张不会重复置入）")

# ==================== ④ 战意增减 ====================
func _战意增减(t) -> void:
	var c := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 11, null, {"单机牌组": true})
	var u = c.allies[0]
	var e = c.enemies[0]
	e["hp"] = 999999.0
	e["maxHp"] = 999999.0
	u["战意"] = 0.0
	Calc.resolveAttack(u, e, _必中(), c, {})
	t.ok(u.get("战意") == 2.0, "④ 攻击行动命中（至少 1 段）：+2 战意（当前 %s）" % u.get("战意"))
	u["战意"] = 0.0
	Calc.resolveAttack(e, u, _必中(), c, {})
	t.ok(u.get("战意") == 2.0, "④ 被敌方攻击命中：+2 战意")
	u["战意"] = 0.0
	Calc.resolveAttack(e, u, _白刃(0.0), c, {})
	t.ok(u.get("战意") == 2.0, "④ 成功闪避敌方攻击：+2 战意")
	u["战意"] = 0.0
	e["hp"] = 1.0
	Calc.resolveAttack(u, e, _必中(99999.0), c, {})
	t.ok(u.get("战意") == 12.0, "④ 击破敌机：命中 +2 与击破 +10 都算（合计 +12，当前 %s）" % u.get("战意"))
	u["战意"] = 100.0
	e["hp"] = 999999.0
	Calc.resolveAttack(u, e, _必中(), c, {})
	t.ok(u.get("战意") == 100.0, "④ 战意上限 100（超出不再加）")
	# 打牌扣的是「当前选中机体」自己的战意
	var c2 := _ctx()
	var b1 = c2.allies[0]
	var m1 = c2.allies[4]
	b1["战意"] = 30.0
	m1["战意"] = 30.0
	var 牌 = b1.专属手牌[0]
	var 费 := J.num0(牌.get("耗气"))
	var r := Btl.打出精神或公有牌(c2, b1.key, 牌.get("id"))
	t.ok(r.get("成功") == true and b1.get("战意") != 30.0 and m1.get("战意") == 30.0,
		"④ 打精神牌只扣打出者自己的战意（B1 %s / M1 不动 %s）" % [b1.get("战意"), m1.get("战意")])
	t.ok(费 > 0.0 and b1.get("战意") == 30.0 - 费 + J.num0(牌.get("值")),
		"④ 扣费准确（%s - %s）再按卡面回战意" % [30.0, 费])

# ==================== ⑤ 自由切机 / 主武互毁 / 衍生不互毁 ====================
func _自由切机与主武互毁(t) -> void:
	var c := _ctx()
	Btl.开始我方阶段(c)
	for e in c.enemies:
		e["hp"] = 999999.0
		e["maxHp"] = 999999.0
		e["eva"] = 0.0
	var b4 = c.allies[6]
	var b1 = c.allies[0]
	var 首武 := str(b1.weapons[0].t.name)
	var r1 := Btl.打出主武器卡(c, b4.key, b4.weapons[0].t.name, c.enemies[0].key)
	t.ok(r1.get("成功") == true and b4.get("主武器已销毁") == true, "⑤ 先选后2（特种）打主武器卡：成功、主武器已销毁 = true")
	var r2 := Btl.打出主武器卡(c, b1.key, 首武, c.enemies[0].key)
	t.ok(r2.get("成功") == true and b1.get("主武器已销毁") == true, "⑤ 再切到前1（近卫）打主武器卡：成功")
	var r3 := Btl.打出主武器卡(c, b4.key, b4.weapons[0].t.name, c.enemies[0].key)
	t.ok(r3.get("成功") == false and str(r3.get("原因", "")).contains("销毁"), "⑤ 同一台本回合不能再打第 2 张主武器卡")
	# 切回后2 打精神牌 / 衍生卡
	var 精神 = b4.专属手牌[0]
	var r4 := Btl.打出精神或公有牌(c, b4.key, 精神.get("id"))
	t.ok(r4.get("成功") == true and b4.get("主武器已销毁") == true, "⑤ 切回已打过主武的后2 还能打精神牌，且不改变主武器销毁状态")
	var 衍生 = b4.衍生手牌[0]
	var r5 := Btl.打出衍生攻击卡(c, b4.key, 衍生.get("id"), c.enemies[0].key)
	t.ok(r5.get("成功") == true and b4.get("主武器已销毁") == true, "⑤ 衍生攻击卡照打，主武器销毁状态不变")
	# 先打衍生卡不会销毁主武器
	var c2 := _ctx()
	var b4b = c2.allies[6]
	t.ok(b4b.衍生手牌.size() >= 1, "⑤ 特种开局就有 1 张衍生卡")
	var r6 := Btl.打出衍生攻击卡(c2, b4b.key, b4b.衍生手牌[0].get("id"), c2.enemies[0].key)
	t.ok(r6.get("成功") == true and b4b.get("主武器已销毁") == false, "⑤ 先打衍生攻击卡：主武器已销毁 仍为 false")
	var r7 := Btl.打出主武器卡(c2, b4b.key, b4b.weapons[0].t.name, c2.enemies[0].key)
	t.ok(r7.get("成功") == true, "⑤ 打完衍生卡还能正常打主武器卡")

# ==================== ⑥ 七大职业标志性机制 ====================
func _七职业(t) -> void:
	# 近卫【连续攻击】
	var c1 := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 21, null, {"单机牌组": true})
	var b1 = c1.allies[0]
	c1.enemies[0]["hp"] = 1.0
	var 武 := str(b1.weapons[0].t.name)
	c1.enemies[0]["eva"] = 0.0
	var r1 := Btl.打出主武器卡(c1, b1.key, 武, c1.enemies[0].key)
	t.ok(r1.get("成功") == true and b1.get("连续攻击已用") == true and b1.get("主武器已销毁") == false,
		"⑥ 近卫击破 →【连续攻击】触发：连续攻击已用 = true、主武器卡全部回手")
	var r2 := Btl.打出主武器卡(c1, b1.key, 武, null)
	t.ok(r2.get("成功") == true, "⑥ 连续攻击后能再打第 2 发主武器卡")
	t.ok(_有日志(c1, "〔近卫·连续攻击〕"), "⑥ 连续攻击写了日志")
	# 重装【铁壁护卫】
	var c2 := Setup.开局([{"键": "M2", "位": 1, "等级": 10}, {"键": "M1", "位": 5, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 22, null, {"单机牌组": true})
	var m2 = c2.allies[0]
	m2["hp"] = 100.0
	var r3 := Btl.打出主武器卡(c2, m2.key, "铁壁护卫", null)
	t.ok(r3.get("成功") == true and m2.get("铁壁护卫中") == c2.turn and m2.get("主武器已销毁") == true,
		"⑥ 重装【铁壁护卫】是主武器卡：打出后主武器销毁、进入铁壁状态")
	t.ok(J.some(m2.buffs, func(b): return b.get("src") == "铁壁护卫" and J.num0(b.get("def")) >= 50.0),
		"⑥ 铁壁护卫给 +50 防御")
	t.ok(float(m2.hp) > 100.0, "⑥ 铁壁护卫回复 5%% HP（100 → %s）" % m2.hp)
	var 嘲讽 = Btl.嘲讽(c2, c2.enemies[0], c2.allies[1])
	t.ok(is_same(嘲讽, m2), "⑥ 铁壁护卫期间替后排队友挡枪（必然触发，不掷随机数）")
	# 指挥【战术统筹】
	var c3 := Setup.开局([{"键": "M1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 23, null, {"单机牌组": true})
	var m1 = c3.allies[0]
	c3["公有手牌"] = [Btl.克隆战术牌({"id": "X_CMD", "名": "统帅测试", "层级": "统帅", "归属": "", "耗气": 10.0, "效果": []}, c3)]
	m1["战意"] = 10.0
	var r4 := Btl.打出精神或公有牌(c3, m1.key, "X_CMD")
	t.ok(r4.get("成功") == true and m1.get("战意") == 5.0, "⑥ 指挥机打公有牌：战意 10 - (10 - 5) = 5")
	var c4 := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 24, null, {"单机牌组": true})
	c4["公有手牌"] = [Btl.克隆战术牌({"id": "X_CMD2", "名": "统帅测试2", "层级": "统帅", "归属": "", "耗气": 10.0, "效果": []}, c4)]
	c4.allies[0]["战意"] = 10.0
	Btl.打出精神或公有牌(c4, c4.allies[0].key, "X_CMD2")
	t.ok(c4.allies[0].get("战意") == 0.0, "⑥ 非指挥机打同一张公有牌：按原价扣 10")
	# 维修【紧急修理】+【应急补丁】
	var c5 := Setup.开局([{"键": "B3", "位": 0, "等级": 10}, {"键": "B1", "位": 1, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 25, null, {"单机牌组": true})
	var b3 = c5.allies[0]
	var b1b = c5.allies[1]
	b1b["hp"] = 100.0
	var r5 := Btl.打出主武器卡(c5, b3.key, "紧急修理", b1b.key)
	t.ok(r5.get("成功") == true and float(b1b.hp) > 100.0, "⑥ 维修【紧急修理】回复大量 HP（100 → %s）" % b1b.hp)
	b1b["hp"] = 100.0
	var r6 := Btl.打出衍生攻击卡(c5, b3.key, "应急补丁", b1b.key)
	t.ok(r6.get("成功") == true and float(b1b.hp) > 100.0 and b3.get("主武器已销毁") == true,
		"⑥ 维修【应急补丁】顺发抬血，且不改变主武器销毁状态")
	# 狙击【援护射击】/ 特种【战术副武】
	var c6 := Setup.开局([{"键": "CB2", "位": 0, "等级": 10}, {"键": "B4", "位": 1, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 26, null, {"单机牌组": true})
	var 狙 = c6.allies[0]
	var 特 = c6.allies[1]
	t.ok(J.some(狙.衍生手牌, func(x): return str(x.get("名", "")) == "援护射击"), "⑥ 狙击有【援护射击】衍生卡")
	t.ok(J.some(特.衍生手牌, func(x): return str(x.get("名", "")) == "战术副武"), "⑥ 特种有【战术副武】衍生卡")
	var r7 := Btl.打出衍生攻击卡(c6, 特.key, "战术副武", c6.enemies[0].key)
	t.ok(r7.get("成功") == true and J.some(c6.enemies[0].buffs, func(b): return b.get("src") == "战术副武"),
		"⑥ 战术副武挂上干扰（命中 -15）")

# ==================== ⑦ 结束回合 ====================
func _结束回合(t) -> void:
	var c := _ctx()
	Btl.开始我方阶段(c)
	for e in c.enemies:
		e["hp"] = 999999.0
		e["maxHp"] = 999999.0
		e["eva"] = 0.0
	var 回合前: float = c.turn
	Btl.结束我方回合(c)
	t.ok(c.turn == 回合前 + 1.0 and str(c.get("阶段")) == "PLAYER_MAIN",
		"⑦ 结束我方回合 → 敌方阶段 → 自动进入下一回合（%s → %s）" % [回合前, c.turn])
	var 打过 := {}
	for e in c.log:
		if e is Dictionary and e.get("类型") == "主武器卡" and e.get("单位方") == "ally":
			打过[str(e.get("单位"))] = true
	var 都打 := true
	for u in c.allies:
		if float(u.hp) > 0.0 and not 打过.has(str(u.key)):
			都打 = false
	t.ok(都打, "⑦ Step A：每台没打过主武器的存活机体都由 AI 补打了 1 张（日志 %d 条主武器卡）" % 打过.size())
	var 我方末 := -1
	var 敌方首 := 99999
	for i in c.log.size():
		var e = c.log[i]
		if not (e is Dictionary):
			continue
		if e.get("类型") == "主武器卡" and e.get("单位方") == "ally":
			我方末 = maxi(我方末, i)
		if e.get("类型") == "攻击" and e.get("单位方") == "enemy" and 敌方首 == 99999:
			敌方首 = i
	t.ok(我方末 >= 0 and 敌方首 < 99999 and 我方末 < 敌方首, "⑦ Step A（我方补打）在 Step B（敌方行动）之前")
	var 位序 := []
	for e in c.log:
		if e is Dictionary and (e.get("类型") == "攻击" or e.get("类型") == "Boss") and e.get("单位方") == "enemy":
			if e.get("单位位") != null:
				位序.append(int(e.单位位))
	var 有序 := true
	for i in range(1, 位序.size()):
		if 位序[i] < 位序[i - 1]:
			有序 = false
	t.ok(有序, "⑦ 敌方严格按格位 0..7 顺序行动（实际 %s）" % [位序])

# ==================== ⑧ 敌方意图 / 压制射击 ====================
func _意图与压制射击(t) -> void:
	var c := _ctx()
	var rng前: int = c.rng.steps
	var log前: int = c.log.size()
	var keys前 := {}
	for k in c.keys():
		keys前[k] = true
	var 意: Array = Btl.算意图(c)
	t.ok(意.size() == Units.livingOf("enemy", c).size(), "⑧ 算意图：每台存活敌机一条（%d 条）" % 意.size())
	var 字段齐 := true
	for 条 in 意:
		for k in ["目标位", "目标名", "武器名", "预计伤害", "是大招", "范围类型"]:
			if not 条.has(k):
				字段齐 = false
	t.ok(字段齐, "⑧ 每条都含 目标位 / 目标名 / 武器名 / 预计伤害 / 是大招 / 范围类型")
	t.ok(c.rng.steps == rng前 and c.log.size() == log前 and c.keys().size() == keys前.size(),
		"⑧ 算意图是纯读：不抽随机数、不写日志、不多字段")
	t.ok(not J.some(意, func(条): return str(条).contains("压制")), "⑧ 算意图里没有任何压制射击标记")
	# ctx.敌方意图 被刷新
	Btl.刷新敌方意图(c)
	t.ok(c.get("敌方意图") is Array and c.敌方意图.size() == 意.size(), "⑧ 刷新敌方意图挂进 ctx.敌方意图")
	# 旧数据带 overwatch 的敌机，在单机牌组模式下绝不抢先开火
	var c2 := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], [{"键": "sniper", "位": 0, "等级": 1}], 31, null, {"单机牌组": true})
	t.ok(Ai.hasOverwatch(c2.enemies[0], c2) == false, "⑧ 单机牌组模式下 hasOverwatch 直接假")
	t.ok(Ai.hasOverwatch(c2.enemies[0]) == true, "⑧ 关着时 sniper 的 overwatch 照旧认（旧路径没改坏）")
	var 没压制 := true
	for _i in range(3):
		Setup.打一回合(c2)
		if c2.get("result") != null:
			break
	t.ok(没压制 and not _有日志(c2, "〔压制射击〕"), "⑧ 打 3 个回合都不出现〔压制射击〕")
	t.ok(not _有日志(c2, "压制射击"), "⑧ 日志里根本没有「压制射击」四个字")
