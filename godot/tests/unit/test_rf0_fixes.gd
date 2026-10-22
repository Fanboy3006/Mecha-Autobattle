## 职责：RF-0 三处缺陷修复的回归测试。
##
## 0a：`ColonialV01.区规则门槛` 只交 `{接手}`、不带 `终局`，`RuleHooks.首个结论` 看不见它
## → 殖民卫星军的「本回合不能打武器 / 依赖未冷却」门槛从来没生效。
## 主武器卡取卡包里的 `COL_S1_W1`「光束军刀」（耗气 5，战意费用 > 0）。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var 拉 := _c单位("S1", "ally", 0.0, "特种")
	var 场 := _c场([拉], [_c靶("靶1", 0.0)])
	var 卡 := _c主武器卡("COL_S1_W1")
	t.ok(not 卡.is_empty() and str(卡.get("卡类")) == "主武器卡" and Btl.战意费用(卡) > 0.0,
		"0a `COL_S1_W1`「光束军刀」：主武器卡、战意费用 %s > 0" % J.s(Btl.战意费用(卡)))

	# (a) 潜入准备：本回合不能打武器 → 门槛生效（旧写法在这里返回空串 = 能打）。
	拉["本回合不能打武器"] = true
	t.ok(CardPlay.主武器门槛(场, 拉, 卡) == "本回合不能打武器牌（潜入准备）",
		"0a(a) `本回合不能打武器` → 主武器门槛拦下")

	# (b) 能打时必须返回 `终局: false`：不再「接手」，通用战意检查照常。
	拉.erase("本回合不能打武器")
	拉["战意"] = Btl.战意费用(卡) - 1.0
	t.ok(CardPlay.主武器门槛(场, 拉, 卡) == "战意不足", "0a(b) 战意低于费用 → 仍由通用检查报「战意不足」")

	# (c) 条件都满足 → 能打。
	拉["战意"] = Btl.战意费用(卡)
	t.ok(CardPlay.主武器门槛(场, 拉, 卡) == "", "0a(c) 战意足够 → 主武器打得出来")

	# (d) 非主武器区一律不接手。
	var 规 := ColonialV01.区规则门槛(场, 拉, 卡, CardPlay.区_筹码)
	t.ok(bool(规.get("终局")) == false, "0a(d) 筹码区 → `终局 = false`（不替通用规则做主）")

	_段_0b(t)
	_段_0c(t)

# 0b：秘银「回血比」回复量不取整 → HP 出现小数。回复量 = round(maxHp × 比)。
# 沙盒照 `test_mithril_v03.gd` 的做法（`Setup.开局` + `{"单机牌组": true, "秘银v03": true}`）；
# 目标走 `执行算子` 显式认的 `ctx["_当前目标"]`（键名与 `MithrilV03Cards._友军` 一致，用单位 key）。
func _段_0b(t) -> void:
	var 场 := Setup.开局([{"键": "U7", "位": 0, "等级": 30}],
		[{"键": "fighter", "位": 0, "等级": 1}], 20261017, null,
		{"单机牌组": true, "秘银v03": true})
	var 友: Dictionary = {}
	for u in 场.get("allies", []):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == "U7":
			友 = u
	t.ok(not 友.is_empty(), "0b 沙盒里找到秘银友军 U7")
	友["maxHp"] = 1001.0
	友["hp"] = 500.0
	场["_当前目标"] = str(友.get("key", ""))
	MithrilV03Cards.执行算子({"ctx": 场, "card": {"名": "测试"}}, {"动作": "回血比", "比": 0.25}, [])
	t.ok(absf(float(友.get("hp", 0.0)) - 750.0) < 0.001,
		"0b 回血比 maxHp 1001 × 25%% = 250.25 → 取整 250，hp 500 → 750（实测 %s）" % str(友.get("hp", 0.0)))
	t.ok(float(友.get("hp", 0.0)) == floorf(float(友.get("hp", 0.0))), "0b 回复后 HP 是整数（不再出现小数）")
	友["hp"] = 990.0
	MithrilV03Cards.执行算子({"ctx": 场, "card": {"名": "测试"}}, {"动作": "回血比", "比": 0.25}, [])
	t.ok(absf(float(友.get("hp", 0.0)) - 1001.0) < 0.001,
		"0b 990 + 250 → 封顶 1001（实测 %s）" % str(友.get("hp", 0.0)))

# 0c：秘银「阵型调整」改走 `BattleSwap.换位`：slot 互换、换位战报与钩子照常、不挂〔错位〕。
func _段_0c(t) -> void:
	var 场 := Setup.开局([{"键": "U7", "位": 0, "等级": 30}, {"键": "U6", "位": 1, "等级": 30}],
		[{"键": "fighter", "位": 0, "等级": 1}], 20261017, null,
		{"单机牌组": true, "秘银v03": true})
	var 活 := Units.livingOf("ally", 场)
	t.ok(活.size() >= 2, "0c 沙盒里我方至少两台存活机体（实测 %d）" % 活.size())
	if 活.size() < 2:
		return
	var a: Dictionary = 活[0]
	var b: Dictionary = 活[1]
	var 甲位 := float(a.get("slot", -1.0))
	var 乙位 := float(b.get("slot", -1.0))
	场["敌方意图表"] = {"fighter": {"武器": "", "目标": ""}}
	MithrilV03Cards.执行算子({"ctx": 场, "card": {"名": "测试"}}, {"动作": "阵型调整"}, [])
	t.ok(absf(float(a.get("slot", -1.0)) - 乙位) < 0.001 and absf(float(b.get("slot", -1.0)) - 甲位) < 0.001,
		"0c 两台的 slot 互换（%s ⇄ %s）" % [J.s(甲位), J.s(乙位)])
	var 换位条: Dictionary = {}
	for e in 场.get("log", []):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "换位" \
			and str((e as Dictionary).get("来源", "")) == "阵型调整":
			换位条 = e
	t.ok(not 换位条.is_empty(), "0c 战报里有一条「类型=换位、来源=阵型调整」")
	var 增益齐 := true
	for u in [a, b]:
		var 有 := false
		for 条 in (u as Dictionary).get("buffs", []):
			if 条 is Dictionary and str((条 as Dictionary).get("src", "")) == "阵型调整" \
				and is_equal_approx(float((条 as Dictionary).get("hit", 0.0)), -10.0):
				有 = true
		增益齐 = 增益齐 and 有
	t.ok(增益齐, "0c 两台都带「阵型调整」增益（hit −10）")
	t.ok(not a.has(BattleSwap.错位键) and not b.has(BattleSwap.错位键),
		"0c 不是影世界牌 → 两台都没有〔错位〕")

	var 场2 := Setup.开局([{"键": "U7", "位": 0, "等级": 30}, {"键": "U6", "位": 1, "等级": 30}],
		[{"键": "fighter", "位": 0, "等级": 1}], 20261017, null,
		{"单机牌组": true, "秘银v03": true})
	var 活2 := Units.livingOf("ally", 场2)
	if 活2.size() >= 2:
		(活2[1] as Dictionary)["hp"] = 0.0
	var 剩位 := float((活2[0] as Dictionary).get("slot", -1.0))
	var 回 := MithrilV03Cards.执行算子({"ctx": 场2, "card": {"名": "测试"}}, {"动作": "阵型调整"}, [])
	t.ok(回 == ["只有一台机体，换不了位"],
		"0c 只剩 1 台存活 → 返回「只有一台机体，换不了位」（实测 %s）" % str(回))
	t.ok(absf(float((活2[0] as Dictionary).get("slot", -1.0)) - 剩位) < 0.001,
		"0c 只剩 1 台 → slot 不变（%s）" % J.s(剩位))

func _c单位(键: String, side: String, 位: float, 职业: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 30.0,
		"maxHp": 3000.0, "hp": 3000.0,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"战斗分类": 职业, "势力": "殖民卫星军"}, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _c靶(键: String, 位: float) -> Dictionary:
	var e := _c单位(键, "enemy", 位, "")
	e["tags"] = {}
	e["hp"] = 999999.0
	e["maxHp"] = 999999.0
	return e

func _c场(我方: Array, 敌方: Array, 种子号: int = 20261018) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": float(种子号), "rng": Mulberry32.new(种子号),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	ColonialDeck.初始化(c)
	return c

## 按 id 取一张主武器卡副本（避免测试改动污染静态卡表）。
func _c主武器卡(id: String) -> Dictionary:
	for c in ColonialUnits.卡表():
		if c is Dictionary and str((c as Dictionary).get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}
