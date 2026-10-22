## DECK-1 / DECK-2 内核验收：单机牌组（阶段制 + 单机战意 + 主武器卡 / 衍生攻击卡 + 7 职业 + 敌方意图）。
## 全部在 `选项.单机牌组 = true` 的沙盒里做（单机牌组已是唯一模式，没有「关着」那条路）。
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
	_标尺(t)
	_初始化(t)
	_阶段开始(t)
	_战意增减(t)
	_自由切机与主武互毁(t)
	_七职业(t)
	_结束回合(t)
	_意图与压制射击(t)
	_秘银v02单机牌组(t)
	# ---- ★ MITH3-2 / MITH3-3：卡牌流转规则 v0.1 的四区域分流（v0.3 卡表在单机牌组里的接线）----
	_秘银v03单机牌组(t)
	_ATXv02卡类分流(t)
	_ATXv02单机牌组(t)
	_ATX轮盘双响(t)
	_晋升解锁专属牌(t)
	_公有牌池与黑市(t)
	_击破后继续出牌(t)

## ★ MITH3-2 / MITH3-3：秘银 v0.3 卡表在**单机牌组**里的接线 ——
##   ① 三处卡表联动；② 上排四区域分流（武器栏 / 副武器栏 / 大招槽 / 待入库）；
##   ③ 9 张势力牌 + 18 张职业牌进下排公有牌库；④ 大招槽的牌一张都不在抽牌堆里。
func _秘银v03单机牌组(t) -> void:
	var c := _队伍ctx(["U7", "U6", "U2"], 30, {"秘银v03": true})
	var u7 := {}
	for x in (c.get("allies") as Array):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == "U7":
			u7 = x
	t.ok(not u7.is_empty(), "⑪ v0.3：找到 U7")
	t.ok((u7.get("武器栏") as Array).size() >= 3, "⑪ 武器栏常驻主武器卡 %d 张" % (u7.get("武器栏") as Array).size())
	t.ok((u7.get("大招槽") as Array).size() == 3, "⑪ 大招槽常驻 3 张（宗介）")
	t.ok((u7.get("待入库") as Array).size() >= 1,
		"⑪ 带入牌库条件的精神牌进了 `u.待入库`（%d 张）" % (u7.get("待入库") as Array).size())
	var u6 := {}
	for x in (c.get("allies") as Array):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == "U6":
			u6 = x
	t.ok(u6.get("副武器栏") is Array and (u6.get("副武器栏") as Array).size() == 1,
		"⑪ 克鲁兹的副武器栏常驻 1 张（援护射击）")
	var 槽id: Array = (u7.get("大招槽") as Array).map(func(s): return str((s as Dictionary).get("卡", {}).get("id", "")))
	var 库id: Array = (u7.get("专属牌库") as Array).map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(not J.some(槽id, func(i): return J.inc(库id, i)),
		"⑪ 大招槽的牌**一张都不在 `u.专属牌库` 抽牌堆里**")
	var 公有id: Array = (c.get("公有牌库") as Array).map(func(x): return str((x as Dictionary).get("id", "")))
	var 有势力 := J.some(公有id, func(i): return str(i).begins_with("V3_F_"))
	var 有职业 := J.some(公有id, func(i): return str(i).begins_with("V3_C_"))
	t.ok(有势力 and 有职业, "⑪ 下排公有牌库里有 v0.3 的势力牌与职业分类牌")
	t.ok(not J以(公有id, "F_MITH_V2_1"), "⑪ v0.3 开着时**不再装 v0.2 的旧势力牌**")

func J以(组: Array, v: String) -> bool:
	for x in 组:
		if str(x) == v:
			return true
	return false

func _有键(d: Variant, k: String) -> bool:
	return d is Dictionary and (d as Dictionary).has(k)

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
	for 池键 in ["专属牌库", "专属手牌", "专属弃牌堆", "武器栏", "待入库"]:
		for c in J.or_(u.get(池键), []):
			if c is Dictionary and c.get("等级需求") != null:
				全.append(c)
	for 栏键 in ["副武器栏", "大招槽"]:
		for e in J.or_(u.get(栏键), []):
			var c = e.get("卡") if e is Dictionary else null
			if c is Dictionary and c.get("等级需求") != null:
				全.append(c)
	return 全

## ★ A6d：**全部**专属牌（连 v0.1 新卡一起算 —— 它们的成长档是 `入手等级` 而不是 `等级需求`）
func _专属全部(u: Dictionary) -> Array:
	var 全: Array = []
	var 已 := {}
	var 候选: Array = []
	for 池键 in ["专属牌库", "专属手牌", "专属弃牌堆", "武器栏", "待入库"]:
		候选.append_array(J.or_(u.get(池键), []))
	for 栏键 in ["副武器栏", "大招槽"]:
		for e in J.or_(u.get(栏键), []):
			if e is Dictionary and e.get("卡") is Dictionary:
				候选.append(e.get("卡"))
	for c in 候选:
		if not (c is Dictionary):
			continue
		var id := str(c.get("id", ""))
		if id == FacAtx.合体技ID and str(u.get("key", "")) != "A2":
			continue
		if not 已.has(id) and (FacAtx.有(id) or AtxThree.有(id)):
			已[id] = true
			全.append(c)
	return 全

## ==================== ⑩ TDD-1 衍生攻击卡进公有手牌 ====================
func _秘银v02单机牌组(t) -> void:
	var c := _队伍ctx(["U7", "U6", "U2"], 10)
	var u2 = c.allies[2]
	c.公有手牌 = []
	var 置 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(c.公有手牌.size() == 1 and 置.size() == 1, "⑩ 置入 1 张 TDD-1 → `ctx.公有手牌` 1 张（下排）")
	var tdd = c.公有手牌[0]
	t.ok(str(tdd.get("id")) == "TDD-1" and str(tdd.get("卡类")) == "衍生攻击卡" and bool(tdd.get("是TDD1", false)),
		"⑩ TDD-1 在公有手牌里，`卡类 = 衍生攻击卡` / 是TDD1")
	t.ok(_有日志(c, "〔衍生牌〕置入公有手牌：【TDD-1 导弹】"), "⑩ 置入写了「公有手牌」日志")
	var 战意前 := float(u2.get("战意"))
	u2["战意"] = 30.0
	var r打 := Btl.打出衍生攻击卡(c, u2.key, "TDD-1")
	t.ok(r打.get("成功") == true, "⑩ 用 `打出衍生攻击卡` 打出公有手牌里的 TDD-1（%s）" % str(r打.get("原因", "")))
	t.ok(u2.get("主武器已销毁") == false, "⑩ 打 TDD-1 **不销毁主武器卡**（主武器已销毁 仍是 false）")
	t.ok(c.公有手牌.is_empty(), "⑩ TDD-1 打出后自己销毁（公有手牌空了）")
	t.ok(u2.get("战意") == 30.0 - _战意费(tdd), "⑩ 只扣打出者自己的战意（30 → %s）" % u2.get("战意"))
	t.ok(战意前 == 0.0, "⑩ 对照：U2 开场战意 0")
	var 置四 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(置四.size() == 1 and c.公有手牌.size() == 1, "⑩ 再置入 1 张 TDD-1（公有手牌 1 张）")
	u2["战意"] = 20.0
	var r精神 := Btl.打出精神或公有牌(c, u2.key, "TDD-1")
	t.ok(r精神.get("成功") == true and c.公有手牌.is_empty(),
		"⑩ `打出精神或公有牌` 也能打公有手牌里的 TDD-1（自己销毁；%s）" % str(r精神.get("原因", "")))
	t.ok(u2.get("主武器已销毁") == false,
		"⑩ 走 `打出精神或公有牌` 同样不销毁主武器卡")
	c.公有手牌 = []
	for i in range(8):
		c.公有手牌.append(Btl.克隆战术牌({"id": "JUNK_%d" % i, "名": "垫牌", "层级": "势力", "归属": "秘银", "耗气": 0.0}, c))
	t.ok(c.公有手牌.size() == 8, "⑩ 先把公有手牌垫到硬上限 8 张")
	var 置2 := CardEffects.grant_derived_card(c, "TDD-1", 1)
	t.ok(c.公有手牌.size() == 8 and J.some(置2, func(s): return str(s).contains("作废")),
		"⑩ 公有手牌满 8 张 → 再置入 TDD-1 直接作废（仍是 8 张）")

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
	# ★ A6b：库斯哈 / 布鲁克林 的 6 张旧牌作废删除、塔斯克（A6）/ 雷欧娜（A7）各 7 张并进来
	#   → 角色牌 15 → **23**、卡表 25 → **33**（合体技 1 张 + 势力牌 9 张始终在场）
	t.ok(表.size() == 33, "⑪ ATX v0.3 卡表 %d 张（23 张角色牌 + 1 张合体技 + 9 张势力牌）" % 表.size())
	t.ok(FacAtx.角色牌们().size() == 23 and FacAtx.势力牌们().size() == 9, "⑪ 23 张角色牌 + 9 张势力牌")
	var 允许 := ["主武器卡", "专属精神牌", "衍生攻击卡", "公有牌", "大招槽卡", "副武器卡"]
	var 缺 := []
	var 错 := []
	var 主武 := 0
	var 精神 := 0
	var 公有 := 0
	var 大招槽 := 0
	var 副武 := 0
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
		elif 类 == "大招槽卡":
			期望 = "大招槽卡"
		elif 类 == "副武器卡":
			期望 = "副武器卡"
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
			"大招槽卡": 大招槽 += 1
			"副武器卡": 副武 += 1
	t.ok(缺.is_empty(), "⑪ 33 张牌**每一张**都带合法 `卡类`%s" % ("" if 缺.is_empty() else "；缺：" + str(缺)))
	t.ok(错.is_empty(), "⑪ ATX 三分类规则逐张成立%s" % ("" if 错.is_empty() else "；错：" + str(错)))
	# ★ A6b 后：主武 10（1/4/7 + 合体技 + 两人各 3 主武器卡）/ 精神 10 / 公有 9 / 大招槽 3
	#   （U_ATX_2 赌神·入局 + 两人各 1 张）/ 副武器 1（U_ATX_8 烟雾弹）
	t.ok(主武 == 10 and 精神 == 10 and 公有 == 9 and 大招槽 == 3 and 副武 == 1,
		"⑪ 分类计数：主武器卡 10 / 专属精神牌 10 / 公有牌 9 / 大招槽卡 3 / 副武器卡 1（实际 %d / %d / %d / %d / %d）" % [主武, 精神, 公有, 大招槽, 副武])
	# ★ A4：v0.2 的【赌神】原地改造成【赌神·入局】= **大招槽卡**、`is_weapon = false`（不算武器牌）
	var 入局 := FacAtx.卡("U_ATX_2")
	t.ok(str(入局.get("名", "")) == "赌神·入局" and str(入局.get("卡类", "")) == "大招槽卡"
		and 入局.get("is_weapon") == false and 入局.get("武器牌") == false,
		"⑪ v0.3【赌神·入局】= 大招槽卡 · is_weapon = false（不算武器牌、不销毁武器）")
	t.ok(J.num0(入局.get("耗气")) == 10.0 and J.num0(入局.get("冷却")) == 2.0,
		"⑪ 【赌神·入局】费用 10 / 离场后冷却 2")
	# 任务单点名的攻击大招 + 合体技（`U_ATX_2` 在 A4 变成了大招槽卡 → 不在这张表里）
	# ★ A6b：A4 / A5 的 3 张攻击大招（U_ATX_10 / 13 / 14）作废；两人的 6 张主武器卡顶上。
	var 攻击大招 := ["U_ATX_1", "U_ATX_4", "U_ATX_7",
		"U_DUO_1", "U_DUO_2", "U_DUO_3", "U_DUO_8", "U_DUO_9", "U_DUO_10"]
	var 漏 := []
	for id in 攻击大招:
		if not FacAtx.是主武器卡(FacAtx.卡(id)):
			漏.append(id)
	t.ok(漏.is_empty() and FacAtx.是主武器卡(FacAtx.合体技卡()),
		"⑪ 全部攻击大招 + 合体技【轮盘双响】= 主武器卡%s" % ("" if 漏.is_empty() else "；漏：" + str(漏)))
	var 战术排 := ["U_ATX_3", "U_ATX_5", "U_ATX_6", "U_ATX_9",
		"U_DUO_5", "U_DUO_6", "U_DUO_7", "U_DUO_12", "U_DUO_13", "U_DUO_14"]
	var 漏2 := []
	for id in 战术排:
		if not FacAtx.是专属精神牌(FacAtx.卡(id)):
			漏2.append(id)
	t.ok(漏2.is_empty(), "⑪ 战术 / 增益 / 回战意牌 = 专属精神牌%s" % ("" if 漏2.is_empty() else "；漏：" + str(漏2)))
	# ★ A5a：v0.2 的【烟雾弹】原地改造成**副武器卡**（冷却 3 · 放烟雾 · 不销毁主武器）
	var 烟 := FacAtx.卡("U_ATX_8")
	t.ok(str(烟.get("卡类", "")) == "副武器卡" and J.truthy(烟.get("烟雾"))
		and J.num0(烟.get("冷却")) == 3.0 and str(烟.get("角色", "")) == "A3",
		"⑪ 【烟雾弹】= 副武器卡 · 烟雾弹 · 冷却 3 · 角色 A3（卡类=%s / 冷却=%s）" % [
			str(烟.get("卡类", "")), str(烟.get("冷却"))])
	var 合 := FacAtx.合体技卡()
	# ★ A6d（设计稿 v0.3 §4）：费用改成「**各付 15 战意**」、冷却 5（原 v0.2 是发起者一个人掏 35）。
	t.ok(J.or_(合.get("占行动"), []) == ["A1", "A2"] and int(合.get("耗气")) == 15
		and int(合.get("各付")) == 15 and int(合.get("冷却")) == 5,
		"⑪ 合体技【轮盘双响】占行动 A1+A2、各付 15 战意（耗气 15）、冷却 5")
	var 势力全公有 := J.every(FacAtx.势力牌们(), func(c): return FacAtx.是公有牌(c) and str(c.get("归属")) == "ATX")
	t.ok(势力全公有, "⑪ 9 张 ATX 势力牌全部 `卡类 = 公有牌` / `归属 = ATX`")
	# ATX 角色专属候选（闸门 G2：7 张旧卡退役后只剩不复用的那几张）
	t.ok(FacAtx.角色专属牌们("A1").size() == 2 and FacAtx.角色专属牌们("A3").size() == 1,
		"⑪ 角色专属牌：A1 = 2 张（U_ATX_2 赌神·入局 + 合体技）；A3 = 1 张（U_ATX_8 烟雾弹）")

## ==================== ⑫ ATX v0.2 接入单机牌组双排 + 读牌 ====================
func _ATXv02单机牌组(t) -> void:
	var c := _队伍ctx(["A1", "A2", "A3"], 10)
	var a1 = c.allies[0]
	var a3 = c.allies[2]
	var 库1 := _专属全部(a1)
	# ★ A6d：主开关开着 → 响介的 v0.1 卡表（A6c 的 8 张「初始」档）也进牌库；
	#   与 v0.1 同名的 v0.2 旧卡（U_ATX_1）**退场**，只剩不复用的 U_ATX_2（赌神·入局）。
	t.ok(J.every(库1, func(x): return FacAtx.有(x.get("id")) or AtxThree.有(x.get("id"))),
		"⑫ A1 上排专属牌库装的是 ATX 牌（v0.2 保留牌 + v0.1 新卡，%d 张）" % 库1.size())
	var A1名单: Array = ["ATX1_S1", "ATX1_S2", "ATX1_S3", "ATX1_S4", "ATX1_U1",
		"ATX1_W1", "ATX1_W2", "ATX1_W3", "U_ATX_2"]
	var A1实: Array = 库1.map(func(x): return str(x.get("id")))
	A1实.sort()
	t.ok(A1实 == A1名单, "⑫ A1 Lv10 专属牌 **%d 张**逐张硬对：%s" % [A1实.size(), str(A1实)])
	t.ok(not J.some(库1, func(x): return str(x.get("id")) == "U_ATX_1"),
		"⑫ ★ A6d：与 v0.1 同名的旧卡 U_ATX_1 **不在**牌库里（旧版退场）")
	t.ok(J.some(库1, func(x): return str(x.get("id")) == "ATX1_U1" and str(x.get("卡类")) == "大招槽卡"),
		"⑫ A1 的【左轮打桩机·全弹】是 v0.1 版（ATX1_U1，大招槽卡）")
	t.ok(J.some(_专属全部(a3), func(x): return str(x.get("id")) == "U_ATX_8" and str(x.get("卡类")) == "副武器卡"),
		"⑫ A3 的 Lv10 专属牌是【烟雾弹】（A5a：`卡类 = 副武器卡`）")
	# ★ A5a：副武器卡进 `u.副武器栏`（不再留在专属牌库里）
	var c副 := _队伍ctx(["A3"], 10, {"卡牌流转": true})
	t.ok(J.some(c副.allies[0].get("副武器栏"), func(x): return str(x.get("卡", {}).get("id")) == "U_ATX_8"),
		"⑫ 卡牌流转开着：【烟雾弹】在 `u.副武器栏` 里（副武器卡不再进专属牌库）")
	var 公有id: Array = c.公有牌库.map(func(x): return str(x.get("id")))
	var 势力数 := 0
	for i in range(1, 10):
		if J.inc(公有id, "F_ATX_V2_%d" % i):
			势力数 += 1
	t.ok(势力数 == 9, "⑫ 9 张 ATX 势力牌进了 `ctx.公有牌库`（%d）" % 势力数)
	# ---- 读牌 v0.3：显示敌方下一个攻击目标（**只读 `Btl.算意图`**）+ 被选中的成员闪避 +15 ----
	var c2 := _队伍ctx(["A1", "A2"], 10)
	var a1b = c2.allies[0]
	a1b["战意"] = 30.0
	c2["turn"] = 2.0                      # ★ A6d：读牌是「第 2 回合起」
	var 意图 := Btl.算意图(c2)
	var 瞄ATX := {}
	for 条 in 意图:
		if 条 is Dictionary and 条.get("目标") != null:
			瞄ATX[str(条.get("单位"))] = true
	c2.公有手牌.append(Btl.克隆战术牌(FacAtx.卡("F_ATX_V2_6"), c2))
	var r读 := Btl.打出精神或公有牌(c2, a1b.key, "F_ATX_V2_6")
	t.ok(r读.get("成功") == true, "⑫ 打出【读牌】成功（%s）" % str(r读.get("原因", "")))
	t.ok(not 瞄ATX.is_empty() and c2.get("ATX读牌目标") is Dictionary
		and (c2["ATX读牌目标"] as Dictionary).size() == 瞄ATX.size(),
		"⑫ 读牌显示的目标 = `Btl.算意图` 的结果（%d 条；自己不算第二套）" % [瞄ATX.size()])
	t.ok(_有日志(c2, "〔读牌〕"), "⑫ 读牌写了日志")
	# ATX 每回合重置：本回合 / 上回合的打空基准都翻新，一次性标记（二次下注 / 庄家通吃）清掉
	var c4 := _队伍ctx(["A1"], 10)
	Btl.开始我方阶段(c4)
	c4["ATX二次下注"] = true
	Btl.开始我方阶段(c4)
	t.ok(c4.has("ATX本回合起始打空") and c4.has("ATX上回合打空") and not c4.has("ATX二次下注"),
		"⑫ ATX 每回合重置：打空基准翻新、一次性标记（二次下注）清掉")
	# ---- 幸运连号 v0.3：下一张 **ATX 大招**费用 −10（吃一次就清）----
	var c5 := _队伍ctx(["A1"], 20)
	var a1d = c5.allies[0]
	c5["ATX打出大招"] = true              # 设计稿 §5 第 8 行：入牌库条件「打出过 ATX 大招」
	c5.公有手牌.append(Btl.克隆战术牌(FacAtx.卡("F_ATX_V2_8"), c5))
	var r运 := Btl.打出精神或公有牌(c5, a1d.key, "F_ATX_V2_8")
	t.ok(r运.get("成功") == true and int(c5.get("下张ATX大招降费", 0)) == 10,
		"⑫ 打出【幸运连号】→ 下一张 ATX 大招降费 10（%s）" % str(r运.get("原因", "")))
	a1d.专属手牌.append(Btl.克隆战术牌(AtxThree.卡("ATX1_U1"), c5))
	a1d["战意"] = 10.0
	var r大 := Btl.打出主武器卡(c5, a1d.key, "ATX1_U1")
	t.ok(r大.get("成功") == true and int(c5.get("下张ATX大招降费", 0)) == 0,
		"⑫ 降费真的生效：耗气 20 的【左轮打桩机·全弹】按 10 费打出（战意 → %s），降费状态已清" % a1d.get("战意"))

## ==================== ⑬ ATX【轮盘双响】合体技：两人都要活着且都没动过 ====================
func _ATX轮盘双响(t) -> void:
	var c := _队伍ctx(["A1", "A2"], 30)
	var a1 = c.allies[0]
	var a2 = c.allies[1]
	a1["战意"] = 60.0
	a2["战意"] = 60.0
	# ★ A6d：进入条件「两人的大招牌各打出过 1 次」（真的打出流程见 `test_atx_faction_v03` 第 12 段）
	c["ATX大招打出人"] = {"A1": true, "A2": true}
	var 合 = Btl.克隆战术牌(FacAtx.合体技卡(), c)
	a1.专属手牌.append(合)
	var r := Btl.打出主武器卡(c, a1.key, "U_ATX_COMBO")
	t.ok(r.get("成功") == true, "⑬ 打出合体技【轮盘双响】成功（%s）" % str(r.get("原因", "")))
	t.ok(r.get("合体技") == true and J.or_(r.get("参与者"), []) == ["A1", "A2"], "⑬ 参与者 = A1 + A2")
	t.ok(a1.get("主武器已销毁") == true and a2.get("主武器已销毁") == true,
		"⑬ 打完把**两名**参与者的 `主武器已销毁` 都置为 true")
	# ★ A6d（设计稿 v0.3 §4）：**各付 15 战意** —— 两人各扣 15（命中回战意照 DECK-1 的 +2 / +10 照常算）
	var 命中回: float = Params.命中战意() * 12.0 + Params.击破战意()
	t.ok(float(a1.get("战意")) <= 60.0 - 15.0 + 命中回 and float(a1.get("战意")) >= 60.0 - 15.0
		and float(a2.get("战意")) <= 60.0 - 15.0 + 命中回 and float(a2.get("战意")) >= 60.0 - 15.0,
		"⑬ **各付 15 战意**：A1 60 → %s、A2 60 → %s（都在 45 上下、命中回战意后不超上界）" % [a1.get("战意"), a2.get("战意")])
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

## ==================== ⑭ 晋升 Lv10 → Lv20 → Lv30：解锁专属牌 + 抬倍率 ====================
func _晋升解锁专属牌(t) -> void:
	# ★ 闸门 G2：面板 = 战斗里真正会发的两路（本文件的候选 + `AtxThree.装填单位`）。
	#   响介（A1）有数据库里的老角色牌 U_A1，逐档解锁看得见；拉米亚（A3）那一侧只有「初始」档。
	var 十 := DeckBuilder.unit_exclusive_cards("A1", 10)
	var 二十 := DeckBuilder.unit_exclusive_cards("A1", 20)
	var 三十 := DeckBuilder.unit_exclusive_cards("A1", 30)
	t.ok(十.size() == 9 and 二十.size() == 10 and 三十.size() == 11,
		"⑭ A1 专属牌张数 Lv10 / Lv20 / Lv30 = 9 / 10 / 11（实际 %d / %d / %d）" % [十.size(), 二十.size(), 三十.size()])
	t.ok(float(十[0].get("倍率")) == 1.0 and float(二十[0].get("倍率")) == 1.2 and float(三十[0].get("倍率")) == 1.4,
		"⑭ 卡牌威力倍率随等级抬升：1.0 → 1.2 → 1.4")
	t.ok(J.every(十, func(x): return int(x.get("等级需求")) == 10)
		and J.every(二十.filter(func(x): return int(x.get("等级需求")) == 20), func(x): return x.get("名") != null)
		and DeckBuilder.新解锁专属牌("A1", 20).size() == 1
		and DeckBuilder.新解锁专属牌("A1", 30).size() == 1,
		"⑭ 「新解锁」只报这一次晋升新拿到的那 1 张（Lv20 / Lv30 各 1 张）")
	# ★ 闸门 G2：7 张旧卡（U_ATX_1/3/4/5/6/7/9）的数据还在，但**一张都不该出现在晋升面板里**
	var 旧卡们 := ["U_ATX_1", "U_ATX_3", "U_ATX_4", "U_ATX_5", "U_ATX_6", "U_ATX_7", "U_ATX_9"]
	var 旧名: Array = []
	var 不在表: Array = []
	for lv in [10, 20, 30]:
		for x in DeckBuilder.unit_exclusive_cards("A3", lv):
			var id := str(x.get("id"))
			if J.inc(旧卡们, id):
				旧名.append(id)
			if not (AtxThree.有(id) or FacAtx.有(id)):
				不在表.append(id)
	t.ok(旧名.is_empty(), "⑭ ★ 7 张旧卡一张都不在晋升面板里（混进：%s）" % str(旧名))
	t.ok(不在表.is_empty(), "⑭ A3 面板里每一张都在 `AtxThree` / `FacAtx` 卡表里（越界：%s）" % str(不在表))
	var 三 := DeckBuilder.unit_exclusive_cards("A3", 10)
	t.ok(三.size() == 9 and str(三[0].get("id")) == "U_ATX_8" and str(三[0].get("卡类")) == "副武器卡",
		"⑭ A3 面板 9 张、首张是【烟雾弹】(副武器卡)：%s" % str(三.map(func(x): return x.get("id"))))
	t.ok(J.every(三.filter(func(x): return str(x.get("来源")) == "AtxThree"),
			func(x): return int(x.get("等级需求")) == 10 and float(x.get("倍率")) == 1.0),
		"⑭ `AtxThree` 那一路每张都算 Lv10 就发、倍率 1.0（战斗里这一路不乘等级倍率）")
	# 倍率真的乘进了牌面威力（拿一张**数据仍在**的旧卡当威力桶：旧卡不再发牌，但卡表里的
	# `效果[].全局[].威力` 还在，`应用等级倍率` 的口径照样验得到）
	var 牌 := DeckBuilder.应用等级倍率(FacAtx.卡("U_ATX_7"), 1.4)
	var 原威力: float = _首个威力(FacAtx.卡("U_ATX_7"))
	var 新威力: float = _首个威力(牌)
	t.ok(absf(新威力 - 原威力 * 1.4) < 0.01 and float(牌.get("等级倍率")) == 1.4,
		"⑭ 倍率真的乘进了 `效果` 里的威力（%s → %s）" % [原威力, 新威力])
	# 晋升：只写返回字典，不污染名册 / 存档
	var s := RosterManager.new_run(20261010, "无")
	s.roster["A1"] = {"key": "A1", "lv": 10, "hpRatio": 1.0}
	s.hope = 99
	s.tickets.append({"id": 1, "类": "势力", "名": "ATX", "档": null, "来源": "测试"})
	s.tickets.append({"id": 2, "类": "势力", "名": "ATX", "档": null, "来源": "测试"})
	var 键前: Array = s.roster["A1"].keys()
	var 存档前: int = s.to_dict().size()
	var 升 := RosterManager.promote(s, "A1")
	t.ok(升.get("ok") == true and int(升.get("到")) == 20, "⑭ A1 Lv10 → Lv20 晋升成功")
	var 键后: Array = s.roster["A1"].keys()
	键前.sort()
	键后.sort()
	t.ok(键前 == 键后 and 键后 == ["hpRatio", "key", "lv"],
		"⑭ 名册条目仍是 `{key, lv, hpRatio}` 三个键（晋升没有污染存档契约）%s" % [键后])
	t.ok(s.to_dict().size() == 存档前, "⑭ `state.to_dict()` 的键数不变（%d）" % 存档前)
	t.ok(J.or_(升.get("解锁专属牌"), []).size() == 1
		and str(J.or_(升.get("解锁专属牌"), [])[0].get("id")) == "U_ATX_COMBO",
		"⑭ 晋升结果里报了「解锁专属牌」：Lv20 解锁【轮盘双响】（%s）" % str(J.or_(升.get("解锁专属牌"), []).map(func(x): return x.get("id"))))
	t.ok(float(升.get("等级倍率")) == 1.2 and J.or_(升.get("专属牌库"), []).size() == 10,
		"⑭ 晋升结果里带着倍率 1.2 与新的专属牌库（10 张，实际 %d）" % J.or_(升.get("专属牌库"), []).size())
	var 再升 := RosterManager.promote(s, "A1")
	t.ok(再升.get("ok") == true and int(再升.get("到")) == 30
		and str(J.or_(再升.get("解锁专属牌"), [])[0].get("id")) == "U_A1"
		and float(再升.get("等级倍率")) == 1.4,
		"⑭ Lv20 → Lv30：解锁【王牌决断·魂】、倍率 1.4")
	# Setup 按等级把专属牌装进 `专属牌库`（Lv10 vs Lv30）
	var c10 := _队伍ctx(["A3"], 10)
	var c30 := _队伍ctx(["A3"], 30)
	var 专10 := _专属牌(c10.allies[0])
	var 专30 := _专属牌(c30.allies[0])
	# ★ A6d：主开关开着 → 与 v0.1 同名的 v0.2 旧卡拉米亚牌（U_ATX_7 幻影凤凰 / U_ATX_9 W17·中继）退场，
	#   只剩不复用的 U_ATX_8（烟雾弹）→ Lv10 / Lv30 都是 1 张（新卡在 `AtxThree.装填单位` 那一侧，另计）。
	t.ok(专10.size() == 1 and 专30.size() == 1,
		"⑭ 开战时按 `u.lv` 装专属牌库：Lv10 = 1 张、Lv30 = 1 张（旧版退场后；实际 %d / %d）" % [专10.size(), 专30.size()])
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

# ==================== ① 标尺 ====================
func _标尺(t) -> void:
	t.ok(Params.战意上限() == 100.0 and Params.开场战意() == 0.0 and Params.回合初战意() == 5.0,
		"① 战意标尺：上限 100 / 开场 0 / 回合初 +5")
	t.ok(Params.命中战意() == 2.0 and Params.被击战意() == 2.0 and Params.闪避战意() == 2.0 and Params.击破战意() == 10.0,
		"① 战意标尺：命中 / 被击 / 闪避 +2、击破 +10")
	t.ok(Params.专属起手() == 2.0 and Params.专属每回合抽() == 1.0 and Params.专属手牌上限() == 4.0,
		"① 上排：起手 2 / 每回合 1 / 上限 4")
	t.ok(Params.公有起手() == 3.0 and Params.公有每回合抽() == 1.0 and Params.公有手牌自然上限() == 6.0 and Params.公有手牌硬上限() == 8.0,
		"① 下排：起手 3 / 每回合 1 / 自然上限 6 / 硬上限 8")
	t.ok(Params.指挥公有减费() == 5.0, "① 指挥机打公有牌：战意 -5")

# ==================== ② 开局初始化 ====================
func _初始化(t) -> void:
	var c := _ctx()
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
	var 修 := Setup.开局([{"键": "M3", "位": 0, "等级": 10}, {"键": "B1", "位": 1, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 25, null, {"单机牌组": true})
	var m3 = 修.allies[0]
	t.ok(Units.unit_class(m3, 修) == "维修" and str(m3.get("tags", {}).get("战斗分类", "")) == "维修",
		"② Iris（M3）在单机牌组下归【维修】（tags.战斗分类 也改成维修）")
	t.ok(Units.unit_class(c.allies[2], c) == "特种", "② 维诺（B3）带治疗武器但保留【特种】（不转维修机体）")
	t.ok(Units.unit_class(c.allies[0], c) == "近卫" and Units.unit_class(c.allies[1], c) == "尖兵"
		and Units.unit_class(c.allies[3], c) == "重装" and Units.unit_class(c.allies[4], c) == "指挥"
		and Units.unit_class(c.allies[5], c) == "狙击" and Units.unit_class(c.allies[6], c) == "特种",
		"② 其余职业不变：近卫 / 尖兵 / 重装 / 指挥 / 狙击 / 特种")
	t.ok(Params.单机牌组_职业("M3", c) == "维修" and Params.单机牌组_职业("B3", c) == "特种" and Params.单机牌组_职业("M2", c) == "重装",
		"② Params.单机牌组_职业：键也能查（M3 → 维修；B3 → 特种；M2 仍为重装）")
	t.ok(J.some(m3.weapons, func(e): return e is Dictionary and e.t.name == "紧急修理"),
		"② 维修机有常驻主武器卡【紧急修理】")
	t.ok(J.some(m3.衍生手牌, func(x): return str(x.get("名", "")) == "应急补丁"), "② 维修机起手带衍生卡【应急补丁】")
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
	t.ok(J.every(c.allies, func(u): return u.get("战意") == 10.0), "③ 全体战意 0 → 10")
	t.ok(J.every(c.allies, func(u): return u.专属手牌.size() == 3), "③ 专属手牌各抽 1 张（2 → 3）")
	t.ok(c.公有手牌.size() == 前公手 + 1, "③ 公有手牌抽 1 张（3 → 4）")
	t.ok(str(c.get("阶段")) == "PLAYER_MAIN", "③ 抽完牌回到 PLAYER_MAIN")
	var 特 = c.allies[6]
	t.ok(J.some(特.衍生手牌, func(x): return str(x.get("名", "")) == "战术副武"), "③ 特种每回合派发【战术副武】")
	var 数量: int = 特.衍生手牌.size()
	Btl.开始我方阶段(c)
	t.ok(c.turn == 前回合 + 2.0 and J.every(c.allies, func(u): return u.get("战意") == 20.0),
		"③ 再来一次：回合 +1、战意 10 → 20")
	t.ok(特.衍生手牌.size() == 数量, "③ 衍生卡「只补不叠」（同一张不会重复置入）")

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
	var c5 := Setup.开局([{"键": "M3", "位": 0, "等级": 10}, {"键": "B1", "位": 1, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 25, null, {"单机牌组": true})
	var m3 = c5.allies[0]
	var b1b = c5.allies[1]
	b1b["hp"] = 100.0
	var r5 := Btl.打出主武器卡(c5, m3.key, "紧急修理", b1b.key)
	t.ok(r5.get("成功") == true and float(b1b.hp) > 100.0, "⑥ 维修【紧急修理】回复大量 HP（100 → %s）" % b1b.hp)
	b1b["hp"] = 100.0
	var r6 := Btl.打出衍生攻击卡(c5, m3.key, "应急补丁", b1b.key)
	t.ok(r6.get("成功") == true and float(b1b.hp) > 100.0 and m3.get("主武器已销毁") == true,
		"⑥ 维修【应急补丁】顺发抬血，且不改变主武器销毁状态")
	# 特种【战术副武】
	var c6 := Setup.开局([{"键": "CB2", "位": 0, "等级": 10}, {"键": "B4", "位": 1, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}], 26, null, {"单机牌组": true})
	var 特 = c6.allies[1]
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
		if e is Dictionary and _是主武器出牌(e) and e.get("单位方") == "ally":
			打过[str(e.get("单位"))] = true
	var 都打 := true
	for u in c.allies:
		if float(u.hp) > 0.0 and not 打过.has(str(u.key)):
			都打 = false
	t.ok(都打, "⑦ Step A：每台没打过主武器的存活机体都由 AI 补打了 1 张（%d 台有主武器卡 / 武器栏出牌日志）" % 打过.size())
	var 我方末 := -1
	var 敌方首 := 99999
	for i in c.log.size():
		var e = c.log[i]
		if not (e is Dictionary):
			continue
		if _是主武器出牌(e) and e.get("单位方") == "ally":
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

## 主武器出牌的两种日志：旧武器池走「主武器卡」，月球 / 影世界等新武器栏走「武器栏」。
func _是主武器出牌(e: Dictionary) -> bool:
	return e.get("类型") == "主武器卡" or e.get("类型") == "武器栏"

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
	# 旧数据带 overwatch 的敌机绝不抢先开火（`Ai.hasOverwatch` 已随单机牌组唯一化删除）
	var c2 := Setup.开局([{"键": "B1", "位": 0, "等级": 10}], [{"键": "sniper", "位": 0, "等级": 1}], 31, null, {"单机牌组": true})
	var 没压制 := true
	for _i in range(3):
		Setup.打一回合(c2)
		if c2.get("result") != null:
			break
	t.ok(没压制 and not _有日志(c2, "〔压制射击〕"), "⑧ 打 3 个回合都不出现〔压制射击〕")
	t.ok(not _有日志(c2, "压制射击"), "⑧ 日志里根本没有「压制射击」四个字")

# ==================== ⑯ 击破 enemies[0] 之后继续出牌：当场出伤害，绝不打空气 ====================
## 钉的是 2026-10-20 修掉的严重内核 bug：
##   `找单位(ctx, "", "enemy")` 老写法对**没有 `tplKey`** 的敌机恒为真（`"" == ""`），
##   于是界面「点卡不传目标」永远打到 `enemies[0]`；那台一死就 0 伤害、0 攻击日志，
##   只能等「结束我方回合」AI 补打才出伤害。本段逐条钉死「当场扣血 + 当场出攻击日志」。
func _击破后继续出牌(t) -> void:
	# ---------- ① 根因本身：空标识 / 空白 / null 一律 null；敌机确实没有 tplKey ----------
	var c0 := _ctx()
	t.ok(Btl.找单位(c0, "", "enemy") == null,
		"⑯ 根因：`找单位(ctx, \"\", \"enemy\")` 返回 null（不再误中 enemies[0]）")
	t.ok(Btl.找单位(c0, "   ", "enemy") == null, "⑯ 根因：只有空白的标识也返回 null")
	t.ok(Btl.找单位(c0, null, "enemy") == null, "⑯ 根因：null 标识返回 null")
	t.ok(not (c0.enemies[0] as Dictionary).has("tplKey"),
		"⑯ 前提：敌机 %s 确实没有 `tplKey` 字段（老代码因此 `\"\" == \"\"` 匹配一切）"
		% str((c0.enemies[0] as Dictionary).get("key", "")))
	# 正常标识照旧认得（键 / 位名）
	var c := _ctx()
	for u in c.allies:
		u["战意"] = 100.0
	var 出: Dictionary = c.allies[0]
	var 死: Dictionary = c.enemies[0]
	var 后排: Dictionary = {}
	for e in c.enemies:
		if int(float((e as Dictionary).get("slot", -1.0))) == 4:
			后排 = e
	t.ok(后排 is Dictionary and not 后排.is_empty(), "⑯ 前提：编成里有后排（位 4）那台敌机")
	t.ok(Btl.找单位(c, str(后排.get("key", "")), "enemy") is Dictionary,
		"⑯ 键照旧认得：`找单位(ctx, %s, \"enemy\")` 找得到那台" % str(后排.get("key", "")))
	t.ok(Btl.找单位(c, Fm.位名(4.0), "enemy") is Dictionary,
		"⑯ 位名照旧认得：`找单位(ctx, \"%s\", \"enemy\")` 找得到那台" % Fm.位名(4.0))
	# ---------- ② 先把 enemies[0] 击破 ----------
	死["hp"] = 0.0
	后排["hp"] = 99999.0
	后排["maxHp"] = 99999.0
	var 活敌 := Units.livingOf("enemy", c)
	t.ok(活敌.size() == c.enemies.size() - 1 and not J.some(活敌, func(e): return str(e.key) == str(死.key)),
		"⑯ 前提：enemies[0] 已被击破，场上还剩 %d 台活敌" % 活敌.size())
	# ---------- ③ 不传 target_id 打主武器卡 → 当场扣活敌 HP + 当场出攻击日志 ----------
	var 血前 := _敌血表(c)
	var 日志前: int = c.log.size()
	var r1 := Btl.打出主武器卡(c, str(出.key), null, "")
	t.ok(bool(r1.get("成功", false)),
		"⑯ 击破 enemies[0] 之后主武器卡照打（%s）" % str(r1.get("原因", "")))
	var 扣 := _扣血表(血前, _敌血表(c))
	t.ok(扣.size() >= 1,
		"⑯ 空 `target_id` 的主武器卡**当场**扣了活敌的 HP（%s）—— 不再打在死尸上" % str(扣))
	t.ok(not 扣.has(str(死.key)), "⑯ 这一发绝没落在已死的 enemies[0] 上")
	t.ok(c.log.size() > 日志前 and _有攻击日志(c, 日志前),
		"⑯ 当场产出了攻击日志（%d → %d 条）—— 不用等「结束我方回合」" % [日志前, c.log.size()])
	# ---------- ④ 指定存活敌机（后排 / 槽位 4）→ 伤害精确落在它身上 ----------
	# 用**特种**（B4，曲射）打后排：近卫 / 狙击是直射，只打前排（而且敌方重装会〔嘲讽〕勾走一击），
	# 打不到后排是设计如此，不是这一条要验的东西。
	var 出2: Dictionary = c.allies[6]
	出2["战意"] = 100.0
	出2["主武器已销毁"] = false
	血前 = _敌血表(c)
	var r2 := Btl.打出主武器卡(c, str(出2.key), null, str(后排.get("key", "")))
	t.ok(bool(r2.get("成功", false)), "⑯ 指定后排敌机也打得出来（%s）" % str(r2.get("原因", "")))
	t.ok(str(r2.get("目标", "")) == str(后排.get("key", "")),
		"⑯ 结果里的 `目标` 就是指定的那台（%s）" % str(r2.get("目标", "")))
	扣 = _扣血表(血前, _敌血表(c))
	t.ok(扣.has(str(后排.get("key", ""))),
		"⑯ 伤害**精确**落在指定的后排敌机 %s 上（扣血 %s）" % [str(后排.get("key", "")), str(扣)])
	# ---------- ⑤ 显式指定一台**已死**的敌机 → 当场回退到活敌 ----------
	出["主武器已销毁"] = false
	出["战意"] = 100.0
	血前 = _敌血表(c)
	var r3 := Btl.打出主武器卡(c, str(出.key), null, str(死.key))
	t.ok(bool(r3.get("成功", false)) and str(r3.get("目标", "")) != str(死.key),
		"⑯ 显式指定死敌 → 自动回退到活敌（目标 = %s）" % str(r3.get("目标", "")))
	扣 = _扣血表(血前, _敌血表(c))
	t.ok(扣.size() >= 1 and not 扣.has(str(死.key)),
		"⑯ 回退之后真的打出了伤害（%s），死尸那一格一分没动" % str(扣))
	# ---------- ⑥ 衍生攻击卡：空 target_id / 指定死敌 同样当场出伤害 ----------
	var 特: Dictionary = c.allies[6]
	特["战意"] = 100.0
	var 衍 = 特.衍生手牌[0] if not (特.get("衍生手牌") as Array).is_empty() else null
	t.ok(衍 is Dictionary and str((衍 as Dictionary).get("名", "")) == "战术副武",
		"⑯ 前提：特种手里有【战术副武】衍生攻击卡（%s）"
		% (str((衍 as Dictionary).get("名", "")) if 衍 is Dictionary else "—"))
	if 衍 is Dictionary:
		血前 = _敌血表(c)
		var 衍日志: int = c.log.size()
		var r4 := Btl.打出衍生攻击卡(c, str(特.key), str((衍 as Dictionary).get("id", "")), "")
		t.ok(bool(r4.get("成功", false)), "⑯ 空 `target_id` 的衍生攻击卡照打（%s）" % str(r4.get("原因", "")))
		扣 = _扣血表(血前, _敌血表(c))
		t.ok(扣.size() >= 1, "⑯ 空 `target_id` 的衍生攻击卡**当场**扣血（%s）" % str(扣))
		t.ok(_有攻击日志(c, 衍日志), "⑯ 衍生攻击卡当场产出攻击日志")
	# 再派发一张，专门验「指定死敌」
	Setup.派发衍生卡(特, c)
	特["战意"] = 100.0
	衍 = 特.衍生手牌[0] if not (特.get("衍生手牌") as Array).is_empty() else null
	if 衍 is Dictionary:
		血前 = _敌血表(c)
		var r5 := Btl.打出衍生攻击卡(c, str(特.key), str((衍 as Dictionary).get("id", "")), str(死.key))
		扣 = _扣血表(血前, _敌血表(c))
		t.ok(bool(r5.get("成功", false)) and 扣.size() >= 1 and not 扣.has(str(死.key)),
			"⑯ 衍生卡指定已死敌机 → 自动回退到活敌并当场扣血（%s）" % str(扣))
	else:
		t.ok(false, "⑯ 第二张衍生攻击卡没派发出来（「指定死敌」那一条跑不了）")
	# ---------- ⑦ `找单位` 优先返回存活单位（同模板两台时先给活的那台） ----------
	var c3 := Setup.开局([{"键": "B1", "位": 0, "等级": 10}],
		[{"键": "fighter", "位": 0, "等级": 1}, {"键": "fighter", "位": 1, "等级": 1}], 20261022, null, {"单机牌组": true})
	var 同模板 = Btl.找单位(c3, "fighter", "enemy")
	t.ok(同模板 is Dictionary and str((同模板 as Dictionary).get("key", "")).begins_with("fighter"),
		"⑯ 按模板键找也认得（两台同模板敌机里先给存活的那台：%s）"
		% (str((同模板 as Dictionary).get("key", "")) if 同模板 is Dictionary else "—"))

## 全部敌机的 `键 -> HP` 表（**含已经倒下的**：`_扣血表` 要能看出「这一发把它打死了」）。
func _敌血表(c: Dictionary) -> Dictionary:
	var out := {}
	for e in J.or_(c.get("enemies"), []):
		if e is Dictionary:
			out[str((e as Dictionary).get("key", ""))] = float((e as Dictionary).get("hp", 0.0))
	return out

## 前后两张血表里「HP 真的变少」的键（= 这一发打到了谁；打死也算）。
func _扣血表(前: Dictionary, 后: Dictionary) -> Array:
	var out: Array = []
	for k in 后.keys():
		if float(后[k]) < float(前.get(k, 后[k])):
			out.append(str(k))
	return out

## `c.log` 从 `起` 之后有没有「攻击」类日志（= 真的产出了一条攻击记录）。
func _有攻击日志(c: Dictionary, 起: int) -> bool:
	var 全部: Array = c.log
	if 起 >= 全部.size():
		return false
	return J.some(全部.slice(起, 全部.size()),
		func(e): return e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击")
