## ★ COL-MOOK-1：殖民卫星军两名大众脸（卡特尔 W4 尖兵 / 五飞 W5 特种）——
## 在 ALLY_T 与名册里、档位 B、势力 / 职业对、殖民卫星军势力券与对应职业券招得到、各带 7 张初始牌且能装进四个区。
## 依据：`协作/设计/殖民卫星军大众脸-卡特尔与五飞-v0.1.md`。
extends RefCounted

const 新人 := {"W4": {"名": "卡特尔", "职业": "尖兵", "远近": "远程"}, "W5": {"名": "五飞", "职业": "特种", "远近": "近战"}}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_模板与档位(t)
	_段2_招募券(t)
	_段3_卡牌(t)
	_段4_精神牌(t)

func _段1_模板与档位(t) -> void:
	var 表: Array = Db.T["ALLY_T"]
	var 末两台: Array = [str((表[表.size() - 2] as Dictionary).get("mech")), str((表[表.size() - 1] as Dictionary).get("mech"))]
	t.ok(末两台 == ["W4", "W5"], "① 两人追加在 ALLY_T 末尾（%s）" % str(末两台))
	for 键 in 新人.keys():
		var tpl := RosterManager.模板(键)
		var tags := RosterManager.标签(键)
		t.ok(str(tpl.get("pilot")) == 新人[键]["名"] and str(tags.get("势力")) == "殖民卫星军"
			and str(tags.get("战斗分类")) == 新人[键]["职业"] and str(tags.get("远近分类")) == 新人[键]["远近"],
			"① %s %s：殖民卫星军 · %s · %s" % [键, 新人[键]["名"], 新人[键]["职业"], 新人[键]["远近"]])
		t.ok(RosterManager.档(键) == "B" and RosterManager.档名(键) == "普通", "① %s 档位 B（普通 = 大众脸）" % 键)
		t.ok(RosterManager.名册键们().has(键), "① %s 在名册里" % 键)
		t.ok(ColonialUnits.成员键.has(键) and ColonialV01.成员键.has(键) and not ColonialUnits.觉醒.has(键),
			"① %s 登记为殖民卫星军成员、没有觉醒（燃料）" % 键)
	# 不比骨干强：主攻属性低于迪奥（格斗）/ 希罗（射击）
	var 迪 := RosterManager.模板("W2")
	var 希 := RosterManager.模板("W1")
	var 卡 := RosterManager.模板("W4")
	var 五 := RosterManager.模板("W5")
	t.ok(float(五.get("melee")) < float(迪.get("melee")) and float(卡.get("shoot")) < float(希.get("shoot"))
		and float(卡.get("melee")) < float(迪.get("melee")),
		"① 主攻属性低于骨干（五飞格斗 %s < 迪奥 %s；卡特尔射击 %s < 希罗 %s）" % [
			J.s(五.get("melee")), J.s(迪.get("melee")), J.s(卡.get("shoot")), J.s(希.get("shoot"))])

func _段2_招募券(t) -> void:
	var 势力券 := {"类": "势力", "名": "殖民卫星军", "档": null, "来源": "测试"}
	var 招得到 := RosterManager.券合机师们(势力券)
	t.ok(招得到.has("W4") and 招得到.has("W5") and 招得到.size() == 7,
		"② 殖民卫星军势力券招得到 7 人（含 W4 / W5）：%s" % str(招得到))
	t.ok(RosterManager.券合({"类": "职业", "名": "尖兵", "档": null}, "W4")
		and RosterManager.券合({"类": "职业", "名": "特种", "档": null}, "W5"),
		"② 尖兵券招得到卡特尔、特种券招得到五飞")
	t.ok(RosterManager.券合({"类": "势力", "名": "殖民卫星军", "档": "B"}, "W4")
		and not RosterManager.券合({"类": "势力", "名": "殖民卫星军", "档": "A"}, "W5"),
		"② 限 B 档的券招得到、限 A 档的券招不到")
	var s := RosterManager.new_run(20261022, "无")
	s.tickets = [{"id": 1, "类": "势力", "名": "殖民卫星军", "档": null, "来源": "测试"}]
	s.hope = 0
	var r := RosterManager.recruit(s, "W5", 0)
	t.ok(bool(r.get("ok")) and s.roster.has("W5") and int(r.get("费", -1)) == 0,
		"② 用势力券真招一次五飞：成功、B 档招募费 0（%s）" % str(r.get("why", "")))

func _段3_卡牌(t) -> void:
	var 期望 := {"W4": ["COL_W4_W1", "COL_W4_W2", "COL_W4_W3", "COL_W4_ULT_CROSS", "COL_W4_SP1", "COL_W4_SP2", "COL_W4_SP3"],
		"W5": ["COL_W5_W1", "COL_W5_W2", "COL_W5_W3", "COL_W5_ULT_FANG", "COL_W5_SP1", "COL_W5_SP2", "COL_W5_SP3"]}
	for 键 in 期望.keys():
		var 牌们 := ColonialUnits.角色牌们(键)
		var ids: Array = 牌们.map(func(c): return str((c as Dictionary).get("id")))
		t.ok(ids == 期望[键], "③ %s 7 张牌：%s" % [键, str(ids)])
		var 计 := {}
		var 全初始 := true
		var 感应 := 0
		for c in 牌们:
			计[str(c.get("卡类"))] = int(计.get(str(c.get("卡类")), 0)) + 1
			全初始 = 全初始 and str(c.get("获取")) == "初始"
			if J.truthy(c.get("觉醒感应")):
				感应 += 1
		t.ok(int(计.get("主武器卡", 0)) == 3 and int(计.get("大招槽卡", 0)) == 1 and int(计.get("专属精神牌", 0)) == 3
			and 全初始 and 感应 == 1, "③ %s 大众脸规格：3 武器 + 1 大招 + 3 精神、全部初始、1 张觉醒感应（%s）" % [键, str(计)])
		# 装填：Lv10 全上；Lv20 起初始武器整包 `+`
		var u := _单位(键, 新人[键]["职业"])
		var 场 := _场([u])
		u["专属牌库"] = ColonialUnits.装填单位(u, 10, 场)
		DeckFlow.拆分单位牌(u, 场)
		ColonialV01.装填大招槽(场, u)
		t.ok(u.武器栏.size() == 3 and u.大招槽.size() == 1 and u.专属牌库.size() + u.专属手牌.size() + u.待入库.size() == 3,
			"③ %s Lv10 四个区：武器 %d / 大招 %d / 精神 %d" % [键, u.武器栏.size(), u.大招槽.size(),
				u.专属牌库.size() + u.专属手牌.size() + u.待入库.size()])
		var 加 := ColonialUnits.装填单位(_单位(键, 新人[键]["职业"]), 20, 场)
		var 加号武器 := 加.filter(func(c): return str(c.get("卡类")) == "主武器卡" and J.truthy(c.get("加号")))
		t.ok(加号武器.size() == 3, "③ %s Lv20：三把初始武器全部换成 `+` 版" % 键)

func _段4_精神牌(t) -> void:
	var 卡 := _单位("W4", "尖兵")
	var 五 := _单位("W5", "特种")
	五["slot"] = 1.0
	var 场 := _场([卡, 五])
	卡["专属手牌"] = [_卡("W4", "COL_W4_SP1")]
	var 前 := Calc.buffSum(五, "eva")
	Btl.打出精神或公有牌(场, "W4", "COL_W4_SP1", "W5")
	t.ok(Calc.buffSum(五, "eva") == 前 + 15.0 and Calc.buffSum(卡, "eva") == 0.0,
		"④「马格纳克队支援」：指定的友军（五飞）闪避 +15，卡特尔自己不吃")
	五["专属手牌"] = [_卡("W5", "COL_W5_SP3")]
	Btl.打出精神或公有牌(场, "W5", "COL_W5_SP3", null)
	t.ok(五.get("减伤") is Dictionary and absf(float((五.get("减伤") as Dictionary).get("物理", 0.0)) - 0.3) < 0.0001,
		"④「龙盾」：五飞物理减伤 30%")
	var 大 := _卡("W5", "COL_W5_ULT_FANG")
	t.ok(float((大.get("武器") as Dictionary).get("命中后减敌命中", 0.0)) == 20.0
		and float((_卡("W4", "COL_W4_ULT_CROSS").get("武器") as Dictionary).get("命中后减敌闪避", 0.0)) == 20.0,
		"④ 两张大招只用现成武器参（命中后减敌命中 / 命中后减敌闪避 20）")

# ---- 辅助（同 test_colonial_units）----
func _卡(键: String, id: String) -> Dictionary:
	for c in ColonialUnits.角色牌们(键):
		if str(c.get("id")) == id:
			return c
	return {}

func _单位(键: String, 职业: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": "ally", "slot": 0.0, "lv": 30.0,
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

func _场(我方: Array) -> Dictionary:
	var e := _单位("敌", "")
	e["side"] = "enemy"
	e["tags"] = {}
	e["hp"] = 999999.0
	e["maxHp"] = 999999.0
	var c := {
		"turn": 1.0, "种子": 20261022.0, "rng": Mulberry32.new(20261022),
		"allies": 我方, "enemies": [e], "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	ColonialDeck.初始化(c)
	return c
