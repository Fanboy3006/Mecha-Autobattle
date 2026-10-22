## 月球王国 v0.2.1 核心：开关 / 月相开局 / 随侍与换位 / 月面偏导 / ★随侍抽牌 / 月光牌库断路器 / 选项关闭时旧版不变。
## 见 协作/设计/月球王国势力卡牌设计 v0.2.md；全部走真的 `Setup.开局(..., {"月球v02": true})`。
extends RefCounted

const 种子 := 20261021
const 开 := {"月球v02": true}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_卡表(t)
	_段2_开局月相(t)
	_段3_随侍与换位(t)
	_段4_月面偏导(t)
	_段5_随侍抽牌(t)
	_段6_月光牌库断路器(t)
	_段7_选项关闭(t)
	_段8_月相切换与修正(t)

# ---- ① 卡表 ----
func _段1_卡表(t) -> void:
	var 月光 := MoonDeck.月光牌们()
	var 计 := MoonDeck.各级张数({"月光牌库": {"牌": 月光}})
	t.ok(月光.size() == 8 and 计["一级"] == 4 and 计["二级"] == 3 and 计["三级"] == 1,
		"① 月光牌 8 张：一级 4 / 二级 3 / 三级 1（%s）" % str(计))
	t.ok(J.every(月光, func(c): return float(c.get("耗气")) == 0.0 and not J.truthy(c.get("随侍"))),
		"① 月光牌一律 0 费、本身不带【随侍】")
	t.ok(MoonDeck.势力牌们().size() == 7, "① 势力牌 7 张（%d）" % MoonDeck.势力牌们().size())
	var 数 := {}
	var 全id: Array = []
	for k in MoonUnits.成员键:
		数[k] = MoonUnits.角色牌们(k).size()
		全id.append_array(MoonUnits.角色牌们(k).map(func(c): return str(c.get("id"))))
	全id.append_array(月光.map(func(c): return str(c.get("id"))))
	全id.append_array(MoonDeck.势力牌们().map(func(c): return str(c.get("id"))))
	t.ok(数 == {"M1": 6, "M2": 4, "M3": 4, "M4": 4, "M5": 4}, "① 五人卡池张数：%s" % str(数))
	t.ok(J.every(全id, func(id): return str(id).begins_with("MOON_")) and J.uniq(全id).size() == 全id.size(),
		"① 全部卡 id 以 MOON_ 开头且不重复（%d 张）" % 全id.size())

# ---- ② 开局月相按站位 ----
func _段2_开局月相(t) -> void:
	var 后 := _开局(5)
	t.ok(MoonV02.开(后) and MoonPhase.月相(后) == "残月", "② Feena 开战站后排 → 【残月】")
	t.ok(MoonPhase.到过(后) == ["残月"], "② 开局月相计入「进入过」：%s" % str(MoonPhase.到过(后)))
	var 前 := _开局(1)
	t.ok(MoonPhase.月相(前) == "盈月", "② Feena 开战站前排 → 【盈月】")
	var 菲 = MoonPhase.王女(前)
	t.ok(_武器栏名(菲) == ["月光共鸣"], "② Feena 的武器栏只有 0 费【月光共鸣】")
	t.ok(_槽可打(前, 菲, "MOON_M1_ULT_WAX"), "② 前排开局：【★ 月相·盈月】亮起")
	t.ok(not _槽可打(后, MoonPhase.王女(后), "MOON_M1_ULT_WAX"), "② 后排开局：【★ 月相·盈月】不亮")
	t.ok(not _槽可打(后, MoonPhase.王女(后), "MOON_M1_ULT_WANE"), "② 【★ 月相·残月】第 1 回合不亮（第 2 回合起）")

# ---- ③ 随侍与换位：随侍随站位变，月相不变 ----
func _段3_随侍与换位(t) -> void:
	var ctx := _开局(5)
	t.ok(MoonPhase.随侍数(ctx) == 3, "③ Feena 后2，Iris 后1 / Nagi 后3 / 阿布拉德 前2 → 随侍 3 人（%d）" % MoonPhase.随侍数(ctx))
	BattleSwap.换位(ctx, "ally", 1, 0, {"来源": "测试"})
	t.ok(MoonPhase.随侍数(ctx) == 2 and MoonPhase.月相(ctx) == "残月", "③ 阿布拉德挪到前1 → 随侍 2 人、月相仍是【残月】")
	t.ok(_有日志(ctx, "随侍"), "③ 换位后写一条〔随侍〕战报")
	var 菲 = MoonPhase.王女(ctx)
	BattleSwap.换位(ctx, "ally", 5, 1, {"来源": "测试"})
	t.ok(float(菲.slot) == 1.0 and MoonPhase.月相(ctx) == "残月", "③ Feena 换到前排 → 月相不变（仍是【残月】）")
	t.ok(_槽可打(ctx, 菲, "MOON_M1_ULT_WAX"), "③ Feena 到前排后【★ 月相·盈月】立即亮起（换位后刷新实时门槛）")

# ---- ④ 月面偏导：只吃第一个命中段 ----
func _段4_月面偏导(t) -> void:
	var ctx := _开局(5)
	var 阿 = _找(ctx, "M2")
	var 敌 = ctx.enemies[0]
	阿["月面偏导"] = true
	MoonV02.受击前(ctx, 敌, 阿)
	var w := {"name": "测试", "fire": "direct", "dmgType": "物理"}
	t.ok(MoonV02.受方伤害倍率(ctx, 敌, 阿, w) == 0.0, "④ 第 1 个命中段 ×0")
	t.ok(MoonV02.受方伤害倍率(ctx, 敌, 阿, w) == 1.0, "④ 第 2 个命中段照常 ×1")
	t.ok(not 阿.has("月面偏导") and _有日志(ctx, "月面偏导"), "④ 月面偏导用掉即移除，并写〔月面偏导〕战报")
	var 无 := _实打(false)
	var 有 := _实打(true)
	t.ok(有.损 > 0.0 and 有.损 < 无.损 and not 有.偏导剩, "④ 三段必中实打：有偏导 %s < 无偏导 %s，且状态已移除" % [J.s(有.损), J.s(无.损)])
	var 不挂 := _开局(5)
	var 阿2 = _找(不挂, "M2")
	MoonV02.受击前(不挂, 敌, 阿2)
	t.ok(MoonV02.受方伤害倍率(不挂, 敌, 阿2, w) == 1.0, "④ 没有月面偏导 → 不减")

# ---- ⑤ ★随侍：达成才抽；公有手牌满 6 张不抽但「放入」照常 ----
func _段5_随侍抽牌(t) -> void:
	var ctx := _开局(5)
	var 菲 = MoonPhase.王女(ctx)
	var 星 := _卡("M1", "MOON_M1_ULT_WAX")
	var 前 := (ctx.公有手牌 as Array).size()
	t.ok(MoonDeck.随侍结算(ctx, 菲, 星) and ctx.公有手牌.size() == 前 + 1, "⑤ 随侍 3 人 → 触发并抽 1 张月光牌")
	t.ok(MoonDeck.各级张数(ctx)["二级"] == 1, "⑤ 「放入」：月面偏导盾进了月光牌库")
	var 孤 := _开局(5, [{"键": "M1", "位": 5}, {"键": "M2", "位": 0}])
	var 前2 := (孤.公有手牌 as Array).size()
	t.ok(not MoonDeck.随侍结算(孤, MoonPhase.王女(孤), 星) and 孤.公有手牌.size() == 前2, "⑤ 没有随侍 → 不触发、不抽")
	var 阿 = _找(孤, "M2")
	t.ok(not MoonDeck.随侍结算(孤, 阿, _卡("M2", "MOON_M2_SUB1")), "⑤ 阿布拉德不与 Feena 十字相邻 → 不触发")
	while (ctx.公有手牌 as Array).size() < 6:
		ctx.公有手牌.append({"id": "填充", "名": "填充"})
	var 库前: int = SubDeck.牌们(MoonDeck.库(ctx)).size()
	t.ok(MoonDeck.随侍结算(ctx, 菲, 星) and ctx.公有手牌.size() == 6, "⑤ 公有手牌已 6 张 → 触发但不抽")
	t.ok(SubDeck.牌们(MoonDeck.库(ctx)).size() == 库前 + 1, "⑤ 满手时「放入」照常执行")
	var 刃 := _卡("M1", "MOON_M1_ULT_WANE")
	var 二 := _开局(5, [{"键": "M1", "位": 5}, {"键": "M3", "位": 4}])
	MoonDeck.随侍结算(二, MoonPhase.王女(二), 刃)
	t.ok(MoonDeck.各级张数(二)["三级"] == 0, "⑤ 残月：随侍只有 1 人 → 不放入满月·月蚀领域")
	MoonDeck.随侍结算(ctx, 菲, 刃)
	t.ok(MoonDeck.各级张数(ctx)["三级"] == 1, "⑤ 残月：随侍 ≥ 2 → 放入满月·月蚀领域")

# ---- ⑥ 三级牌每场只放入一次、打出移出本场 ----
func _段6_月光牌库断路器(t) -> void:
	var ctx := _开局(5)
	t.ok(MoonDeck.放入(ctx, "MOON_LT3_ECLIPSE"), "⑥ 第一次放入满月·月蚀领域 → 成功")
	t.ok(not MoonDeck.放入(ctx, "MOON_LT3_ECLIPSE"), "⑥ 第二次 → 被断路器 1 拦下")
	t.ok(MoonDeck.放入(ctx, "MOON_LT2_DEFLECT") and MoonDeck.放入(ctx, "MOON_LT2_DEFLECT"), "⑥ 二级牌不限次")
	var 领域: Dictionary = {}
	for c in SubDeck.牌们(MoonDeck.库(ctx)):
		if str(c.get("id")) == "MOON_LT3_ECLIPSE":
			领域 = c
	SubDeck.牌们(MoonDeck.库(ctx)).erase(领域)
	ctx.公有手牌.append(领域)
	var 菲 = MoonPhase.王女(ctx)
	var 果: Dictionary = BattleCardExec.打出精神或公有牌(ctx, 菲.key, 领域, null)
	t.ok(J.truthy(果.get("成功")) and str(果.get("去处")) == "移出本场" and (ctx.月光移出 as Array).size() == 1,
		"⑥ 打出满月·月蚀领域 → 移出本场（%s）" % str(果))
	t.ok(J.same(MoonPhase.状态(ctx).get("领域回合"), ctx.turn) and float(菲.get("shieldHp", 0.0)) > 0.0,
		"⑥ 月蚀领域：本回合余响 ×1.5、全员获得护盾")
	var 敌血: float = ctx.enemies.map(func(e): return float(e.hp)).max()
	MoonPhase.余响(ctx, 900.0)
	t.ok(_有日志(ctx, "× 1350"), "⑥ 领域回合内余响 900 → 1350")
	var 微光 := MoonDeck.月光牌("MOON_LT1_SPARK")
	ctx.公有手牌.append(微光)
	var 一级前: int = MoonDeck.各级张数(ctx)["一级"]
	BattleCardExec.打出精神或公有牌(ctx, 菲.key, 微光, 菲.key)
	t.ok(MoonDeck.各级张数(ctx)["一级"] == 一级前 + 1 and 敌血 > 0.0, "⑥ 一级牌打出后回月光牌库")

# ---- ⑦ 默认开；显式 `月球v02 = false` 才关：MoonV02 不接手、旧版 FacMoon 照旧 ----
func _段7_选项关闭(t) -> void:
	var 默认 := _开局(5, [], {})
	t.ok(MoonV02.开(默认) and 默认.has("月光牌库") and FacMoon.v02让位(默认), "⑦ 不写选项 → MoonV02 默认接手、旧版让位")
	var 关 := _开局(5, [], {"月球v02": false})
	t.ok(not MoonV02.开(关) and not 关.has("月球") and not 关.has("月光牌库"), "⑦ 选项关闭 → MoonV02 不开、ctx 不多字段")
	var 有新牌 := false
	for u in 关.allies:
		for c in (u.专属牌库 + u.专属手牌 + u.武器栏 + u.大招槽.map(func(x): return x.卡)):
			有新牌 = 有新牌 or str(c.get("id", "")).begins_with("MOON_")
		有新牌 = 有新牌 or u.has("月球v02")
	for c in 关.公有牌库 + 关.公有手牌 + 关.公有待入库:
		有新牌 = 有新牌 or str(c.get("id", "")).begins_with("MOON_")
	t.ok(not 有新牌, "⑦ 选项关闭 → 一张 MOON_ 牌都不装、单位不打标记")
	t.ok(MoonV02.公有扩展牌(关).is_empty() and MoonV02.公有扩展牌(null).is_empty(), "⑦ 公有扩展牌：关闭 / 局外预览都不给")
	t.ok(_有光环(关), "⑦ 选项关闭 → 旧版【月光环绕】照常挂在相邻队友身上")
	var 开着 := _开局(5)
	t.ok(not _有光环(开着) and J.truthy(MoonPhase.王女(开着).get("月球v02")), "⑦ 选项开着 → 旧版【月光环绕】让位")
	var 菲 = MoonPhase.王女(开着)
	t.ok(FacMoon.残月追加攻击(开着, _找(开着, "M2"), 开着.enemies[0], {"伤害": 100.0}, null) == 0.0,
		"⑦ 选项开着 → 旧版【残月的余响】追加不触发")
	t.ok(FacMoon.连射残心(_找(开着, "M4"), {"special": "chain"}, null) == 0.0 and 菲 != null, "⑦ 选项开着 → 旧版【连射残心】不触发")
	var 跑 := Setup.跑完(_阵(), [{"键": "grunt", "位": 0, "等级": 1}], 种子, {"月球v02": false})
	t.ok(跑.result is Dictionary and not 跑.has("月球"), "⑦ 选项关闭整场自动战斗：结束且没有 v0.2 状态")

# ---- ⑧ 月相切换 / 受伤修正 / 祝福回战意 ----
func _段8_月相切换与修正(t) -> void:
	var ctx := _开局(5)
	var 菲 = MoonPhase.王女(ctx)
	var w := {"name": "测试"}
	t.ok(absf(MoonV02.受方伤害倍率(ctx, null, 菲, w) - 1.2) < 0.0001, "⑧ 【残月】Feena 受到伤害 ×1.2")
	MoonPhase.切换月相(ctx, "盈月", "测试")
	t.ok(absf(MoonV02.受方伤害倍率(ctx, null, 菲, w) - 0.85) < 0.0001, "⑧ 【盈月】Feena 受到伤害 ×0.85")
	MoonPhase.切换月相(ctx, "祝福", "测试")
	t.ok(MoonV02.受方伤害倍率(ctx, null, 菲, w) == 1.0 and MoonPhase.到过(ctx).size() == 3, "⑧ 【祝福】不改伤害；三种月相都进入过")
	var 战意前 := Btl.战意(菲)
	var 苏 = _找(ctx, "M5")
	var 苏前 := Btl.战意(苏)
	MoonV02.我方阶段初_后(ctx)
	t.ok(Btl.战意(菲) == minf(100.0, 战意前 + 3.0) and Btl.战意(苏) == 苏前, "⑧ 【祝福】阶段初：Feena 与随侍 +3、非随侍不变")
	ctx.turn = 2.0
	DeckFlow.阶段初_检查(ctx)
	菲["战意"] = 100.0
	MoonPhase.切换月相(ctx, "残月", "测试")
	var 果 := DeckFlow.打出大招(ctx, 菲.key, "MOON_M1_ULT_BLESS", null)
	t.ok(J.truthy(果.get("成功")) and MoonPhase.月相(ctx) == "祝福" and J.truthy(菲.get("主武器已销毁")),
		"⑧ 打出【月相·祝福】→ 切入祝福，并收起本回合的【月光共鸣】")
	t.ok(Btl.武器栏不可打原因(ctx, 菲, 菲.武器栏[0]) != "", "⑧ 月光共鸣本回合不可再打")

# ---- 小工具 ----
func _阵() -> Array:
	return [{"键": "M1", "位": 5, "等级": 10}, {"键": "M2", "位": 1, "等级": 10},
		{"键": "M3", "位": 4, "等级": 10}, {"键": "M4", "位": 6, "等级": 10}, {"键": "M5", "位": 2, "等级": 10}]

func _开局(菲位: int, 阵: Array = [], 选项: Dictionary = 开) -> Dictionary:
	var 编: Array = 阵 if not 阵.is_empty() else _阵()
	var 出: Array = []
	for x in 编:
		var y: Dictionary = (x as Dictionary).duplicate()
		y["等级"] = 10
		if str(y.键) == "M1":
			y["位"] = 菲位
		elif 菲位 == 1 and int(y.位) == 1:
			y["位"] = 5
		出.append(y)
	return Setup.开局(出, [{"键": "ironwall", "位": 0, "等级": 5}, {"键": "ironwall", "位": 2, "等级": 5}], 种子, null, 选项)

func _找(ctx: Dictionary, 键: String) -> Variant:
	for u in ctx.allies:
		if str(u.get("key", "")) == 键:
			return u
	return null

func _卡(键: String, id: String) -> Dictionary:
	for c in MoonUnits.角色牌们(键):
		if str(c.get("id")) == id:
			return c
	return {}

func _武器栏名(u: Dictionary) -> Array:
	return (u.武器栏 as Array).map(func(c): return str(c.get("名")))

func _槽可打(ctx: Dictionary, u: Dictionary, id: String) -> bool:
	u["战意"] = 100.0
	var 槽 := DeckFlow.找大招槽(u, id)
	return not 槽.is_empty() and DeckFlow.大招不可打原因(ctx, u, 槽) == ""

func _有日志(ctx: Dictionary, 片段: String) -> bool:
	for l in ctx.log:
		if str(l.get("文本", "")).find(片段) >= 0 or str(l.get("类型", "")) == 片段:
			return true
	return false

func _有光环(ctx: Dictionary) -> bool:
	for u in ctx.allies:
		for b in J.or_(u.get("buffs"), []):
			if str(b.get("src", "")) == FacMoon.月球光环来源:
				return true
	return false

## 敌机用三段必中物理武器打阿布拉德一次，返回 {损, 偏导剩}。
func _实打(挂偏导: bool) -> Dictionary:
	var ctx := _开局(5)
	var 阿 = _找(ctx, "M2")
	var 敌 = ctx.enemies[0]
	阿["shieldHp"] = 0.0
	if 挂偏导:
		阿["月面偏导"] = true
	var w := {"name": "测试连射", "fire": "direct", "dmgType": "物理", "power": 1500.0, "hit": 100.0, "critMod": 0.0,
		"stat": "射击", "hits": 3.0, "special": "multi", "必中": true, "cd": 0.0, "uses": null, "unlock": 1.0,
		"upgrades": [], "ignoreDef": false, "area": "single", "距离": [1, 6]}
	var 前 := float(阿.hp)
	Flow.结算一个目标(ctx, 敌, 阿, w, {"改目标": false})
	return {"损": 前 - float(阿.hp), "偏导剩": 阿.has("月面偏导")}
