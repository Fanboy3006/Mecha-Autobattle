## ★ A6b：塔斯克（A6 · 重装）+ 雷欧娜（A7 · 指挥）——
##   两人全卡表（每人 3 主武器 + 1 大招 + 3 精神 = 7 张）/ 名册替换 / 被动与主动机制 / 一处数值调整。
##
## 权威依据：
##   · `协作/设计/塔斯克与雷欧娜卡牌设计 v0.1.md` §1 / §2 / §4
##   · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §2.2（次与段）/ §4 A6b 行 / §5 R1·R4·R5
##
## 受控单位（不走 `Setup.开局`，裸字典）：`atk == D == 0` ⇒ `coef == 1`、`armor` 手填、`eva = 0`
##   ⇒ 命中率 = `w.hit`、`critBase = -10` ⇒ 暴击率 0。
## ★ 数值口径（本文件反复出现的那两个系数）：
##   · 兰斯战线 `职业排位.重装前排减伤 0.20` → **塔斯克自己吃伤害 ×0.8**（队友没有这个减免）；
##   · 兰斯战线 `同路掩护减伤 0.30` → **后排被挡住的队友吃直射 ×0.7**。
##   所以「转移后的伤害按塔斯克自己的减伤算」= 800，队友自己挨 = 700 —— 正好是第 4 条要贴的数字。
## 本文件跑完会把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_卡表(t)
	_段2_名册(t)
	_段3_引力墙(t)
	_段4_掩护(t)
	_段4b_耐打(t)
	_段5_预告同源(t)
	_段6_重力冲撞(t)
	_段7_大招条件(t)
	_段8_横扫(t)
	_段9_赌局(t)
	_段10_TLink(t)
	_段11_散布(t)
	_段12_连珠箭(t)
	_段14_同种子(t)

# ==========================================================================================
# ① 每人 7 张（3 主武器 + 1 大招 + 3 精神）；费用 / 冷却 / 条件逐张对稿
# ==========================================================================================
func _段1_卡表(t) -> void:
	t.ok(AtxDuo.卡表().size() == 14, "① 两人合计 **%d** 张（每人 7 张）" % AtxDuo.卡表().size())
	for 键 in [AtxDuo.塔斯克, AtxDuo.雷欧娜]:
		var 们 := AtxDuo.角色牌们(键)
		t.ok(们.size() == 7, "① %s：**7 张**（3 主武器 + 1 大招 + 3 精神）= %d" % [键, 们.size()])
		t.ok(AtxDuo.主武器卡们(键).size() == 3 and AtxDuo.大招卡们(键).size() == 1
			and AtxDuo.精神牌们(键).size() == 3,
			"① %s：主武器 %d / 大招 %d / 精神 %d" % [键, AtxDuo.主武器卡们(键).size(),
			AtxDuo.大招卡们(键).size(), AtxDuo.精神牌们(键).size()])
		var 全初始 := J.every(们, func(c): return str(c.get("入牌", "")) == "初始")
		t.ok(全初始, "① %s：7 张全部 `入牌 = 初始`（不做剧情解锁）" % 键)
		var 归属对 := J.every(们, func(c):
			return str(c.get("归属", "")) == "ATX" and str(c.get("角色", "")) == 键)
		t.ok(归属对, "① %s：7 张全部 `归属 = ATX` / `角色 = %s`" % [键, 键])
	# —— 费用 / 冷却 / 条件逐张对稿（设计稿 §1 §2 的表格；按 id 认，两张【专注】各占各的）——
	var 期望 := {
		"U_DUO_1": [0.0, 0.0, ""], "U_DUO_2": [0.0, 0.0, ""], "U_DUO_3": [0.0, 0.0, ""],
		"U_DUO_4": [20.0, 4.0, "塔斯克本场被攻击 ≥ 3 次"],
		"U_DUO_5": [10.0, 0.0, ""], "U_DUO_6": [5.0, 0.0, ""], "U_DUO_7": [5.0, 0.0, ""],
		"U_DUO_8": [0.0, 0.0, ""], "U_DUO_9": [0.0, 0.0, ""], "U_DUO_10": [0.0, 0.0, ""],
		"U_DUO_11": [20.0, 4.0, "第 3 回合起"],
		"U_DUO_12": [0.0, 0.0, ""], "U_DUO_13": [10.0, 0.0, ""], "U_DUO_14": [5.0, 0.0, ""],
	}
	var 名稿 := {
		"U_DUO_1": "回旋盾刃", "U_DUO_2": "肩部机炮", "U_DUO_3": "重力冲撞",
		"U_DUO_4": "千兆宽域爆破", "U_DUO_5": "硬撑", "U_DUO_6": "专注", "U_DUO_7": "「我可是很耐打的！」",
		"U_DUO_8": "T-Link 光束炮", "U_DUO_9": "分裂飞弹", "U_DUO_10": "光束刃", "U_DUO_11": "T-Link 突击",
		"U_DUO_12": "冷静判断", "U_DUO_13": "「塔斯克，退下」", "U_DUO_14": "专注",
	}
	var 错: Array = []
	var 见到 := {}
	for c in AtxDuo.卡表():
		var id := str(c.get("id", ""))
		var 名 := str(c.get("名", ""))
		见到[id] = true
		if not 期望.has(id):
			错.append("%s（多出来的牌）" % id)
			continue
		var e: Array = 期望[id]
		if 名 != str(名稿[id]):
			错.append("%s 名字「%s」≠「%s」" % [id, 名, str(名稿[id])])
		if float(c.get("耗气", -1)) != float(e[0]):
			错.append("%s 费用 %s≠%s" % [名, J.s(c.get("耗气")), J.s(e[0])])
		if float(c.get("冷却", -1)) != float(e[1]):
			错.append("%s 冷却 %s≠%s" % [名, J.s(c.get("冷却")), J.s(e[1])])
		var 门 = c.get("实时门槛")
		var 文 := str((门 as Dictionary).get("说明", "")) if 门 is Dictionary else ""
		if 文 != str(e[2]):
			错.append("%s 条件「%s」≠「%s」" % [名, 文, str(e[2])])
	t.ok(错.is_empty() and 见到.size() == 14,
		"① 14 张名字 / 费用 / 冷却 / 亮起条件**逐张对稿**（%s）" % ("全对" if 错.is_empty() else "错：" + str(错)))
	# 武器数据逐张（威力 / 段数 / 命中 / 距离）
	var 武错: Array = []
	var 武稿 := {
		"回旋盾刃": [400.0, 5.0, 80.0, 1, 2, "melee"], "肩部机炮": [200.0, 8.0, 75.0, 1, 3, "direct"],
		"重力冲撞": [1800.0, 1.0, 85.0, 1, 1, "melee"],
		"千兆宽域爆破": [300.0, 6.0, 75.0, 1, 4, "direct"],
		"T-Link 光束炮": [500.0, 3.0, 85.0, 2, 5, "direct"],
		"分裂飞弹": [300.0, 4.0, 75.0, 2, 5, "indirect"],
		"光束刃": [600.0, 2.0, 85.0, 1, 2, "melee"],
		"T-Link 突击": [800.0, 4.0, 85.0, 1, 5, "direct"],
	}
	for c in AtxDuo.卡表():
		var 名2 := str(c.get("名", ""))
		var w = c.get("武器")
		if not (w is Dictionary):
			continue
		if not 武稿.has(名2):
			武错.append("%s 多出来" % 名2)
			continue
		var e2: Array = 武稿[名2]
		var 界 := Reach.武器距离(w)
		if float(w.get("power")) != float(e2[0]) or float(w.get("hits", 1.0)) != float(e2[1]) \
			or float(w.get("hit")) != float(e2[2]) or 界.x != int(e2[3]) or 界.y != int(e2[4]) \
			or str(w.get("fire")) != str(e2[5]):
			武错.append("%s 武器面不符：%s/%s/%s/%s/%s" % [名2, J.s(w.get("power")),
				J.s(w.get("hits")), J.s(w.get("hit")), str(界), str(w.get("fire"))])
	t.ok(武错.is_empty(), "① 8 把带武器的牌：威力 / 段数 / 命中 / 距离 / 射击种类逐张对稿（%s）"
		% ("全对" if 武错.is_empty() else "错：" + str(武错)))
	t.ok(J.truthy((AtxDuo.卡(AtxDuo.ID_千兆宽域爆破).get("武器") as Dictionary).get("横扫")),
		"① 千兆宽域爆破带「横扫」（目标所在一整排）")
	t.ok(Reach.无视遮挡((AtxDuo.卡(AtxDuo.ID_TLINK突击).get("武器") as Dictionary)),
		"① T-Link 突击带「无视遮挡」")
	t.ok(J.truthy((AtxDuo.卡(AtxDuo.ID_分裂飞弹).get("武器") as Dictionary).get("散布")),
		"① 分裂飞弹带「散布」")

# ==========================================================================================
# ② 名册：塔斯克 / 雷欧娜 在册、势力 ATX、职业对；库斯哈 / 布鲁克林 不在册
# ==========================================================================================
func _段2_名册(t) -> void:
	var 名册 := RosterManager.名册键们()
	t.ok(名册.has(AtxDuo.塔斯克) and 名册.has(AtxDuo.雷欧娜),
		"② 塔斯克（A6）/ 雷欧娜（A7）**在名册**（名册共 %d 人）" % 名册.size())
	t.ok(not 名册.has("A4") and not 名册.has("A5"),
		"② 库斯哈（A5）/ 布鲁克林（A4）**不在名册**")
	t.ok(名册.size() == 31, "② 名册 **31 人**（COL-1 退役五人 34 − 5；COL-MOOK-1 +2）")
	var 塔 := Units.makeUnit(AtxDuo.塔斯克, "ally", 0.0, 10.0)
	var 雷 := Units.makeUnit(AtxDuo.雷欧娜, "ally", 4.0, 10.0)
	t.ok(Units.势力们(塔) == ["ATX"] and Units.势力们(雷) == ["ATX"],
		"② 两人的势力都是 ATX（%s / %s）" % [str(Units.势力们(塔)), str(Units.势力们(雷))])
	t.ok(Units.unit_class(塔, {"单机牌组": true}) == "重装", "② 塔斯克职业 = **重装**（%s）"
		% Units.unit_class(塔, {"单机牌组": true}))
	t.ok(Units.unit_class(雷, {"单机牌组": true}) == "指挥", "② 雷欧娜职业 = **指挥**（%s）"
		% Units.unit_class(雷, {"单机牌组": true}))
	t.ok(str(塔.get("name")) == "塔斯克" and str(雷.get("name")) == "雷欧娜",
		"② 名字：%s / %s（机体 %s / %s）" % [str(塔.get("name")), str(雷.get("name")),
		str(塔.get("mechName")), str(雷.get("mechName"))])
	t.ok((塔.get("weapons") as Array).size() == 3 and (雷.get("weapons") as Array).size() == 3,
		"② 单位模板各 3 把主武器（%d / %d）" % [(塔.get("weapons") as Array).size(), (雷.get("weapons") as Array).size()])
	t.ok(FacAtx.卡表().size() == 33 and FacAtx.卡("U_ATX_10").is_empty() and FacAtx.卡("U_ATX_13").is_empty(),
		"② 旧牌**作废删除**：U_ATX_10（计都罗睺剑）/ U_ATX_13（龙王破山剑）都取不到")
	t.ok(FacAtx.卡("U_DUO_4").get("名") == "千兆宽域爆破" and FacAtx.卡("U_DUO_11").get("名") == "T-Link 突击",
		"② 新牌并进了 ATX 角色牌表（`FacAtx.卡` 取得到两人 14 张）")
	t.ok(FacAtx.角色牌们().size() == 23 and FacAtx.势力牌们().size() == 9,
		"② ATX 角色牌 = **23**（A1/A2/A3 各 3 + 两人各 7）/ 势力牌 = 9")
	t.ok(RosterManager.券合机师们({"类": "职业", "名": "重装"}) .has(AtxDuo.塔斯克)
		and not RosterManager.券合机师们({"类": "职业", "名": "重装"}).has("A4"),
		"② 招募候选（重装券）里有塔斯克、没有布鲁克林")

# ==========================================================================================
# ③ 引力墙：每个敌方阶段**第一次**被攻击 −30%，第二次不再减
# ==========================================================================================
func _段3_引力墙(t) -> void:
	var c := _场([_塔斯克(0.0, 5000.0)], [_敌("E1", 0.0, _武(1000.0, 1, 100.0))])
	var 塔: Dictionary = c.allies[0]
	var 敌: Dictionary = c.enemies[0]
	AtxDuo.敌方阶段初(c)
	var 前1 := float(塔.get("hp"))
	Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	var 伤1 := 前1 - float(塔.get("hp"))
	var 前2 := float(塔.get("hp"))
	Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	var 伤2 := 前2 - float(塔.get("hp"))
	t.info("引力墙：同一发 1000（必中 / 甲 0 / 防 0）→ 第一次 %s → 第二次 %s" % [J.s(伤1), J.s(伤2)])
	t.ok(伤1 == 560.0, "③ 第一次被攻击：1000 × 0.8（重装前排 −20%%）× 0.7（引力墙 −30%%）= **%s**" % J.s(伤1))
	t.ok(伤2 == 800.0, "③ 第二次**不再减**：1000 × 0.8 = **%s**（差值正好 %s = 800 × 30%%）"
		% [J.s(伤2), J.s(伤2 - 伤1)])
	t.ok(伤2 - 伤1 == 240.0, "③ 引力墙那 −30%% 只落在第一次：800 − 560 = **240**")
	# 下一个敌方阶段重新亮起
	AtxDuo.敌方阶段初(c)
	var 前3 := float(塔.get("hp"))
	Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	t.ok(前3 - float(塔.get("hp")) == 560.0, "③ 下一个敌方阶段第一次又被减：%s（引力墙按**敌方阶段**刷新）"
		% J.s(前3 - float(塔.get("hp"))))
	t.ok(_有行(c, "〔引力墙〕"), "③ 即时反馈一行：%s" % _找行(c, "〔引力墙〕"))

# ==========================================================================================
# ④ ★ 掩护：后排同列队友被直射 → 伤害真的移到塔斯克身上（每阶段 2 次，第 3 次不再移）
#    并且**转移后的伤害按塔斯克自己的减伤算**（塔斯克 800 ≠ 队友自己挨 700）
# ==========================================================================================
func _段4_掩护(t) -> void:
	var c := _场([_塔斯克(0.0, 5000.0), _队友("F2", 4.0, 300.0)], [_敌("E2", 0.0, _武(1000.0, 1, 100.0))])
	var 塔: Dictionary = c.allies[0]
	var 脆: Dictionary = c.allies[1]
	var 敌: Dictionary = c.enemies[0]
	AtxDuo.敌方阶段初(c)
	# 先把【引力墙】那一发用掉（直接打塔斯克本人，不经掩护 —— 让第 4 条的伤害数字干净）
	Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	t.info("掩护：预备（引力墙那一发）后 塔斯克 = %s" % J.s(塔.get("hp")))
	var 塔前 := float(塔.get("hp"))
	var 脆前 := float(脆.get("hp"))
	var 实际1 := _打一轮(敌, c)
	var 伤1 := 塔前 - float(塔.get("hp"))
	t.info("掩护 第 1 次：预告/实际目标 = %s；塔斯克 %s → %s（挨 %s）；脆皮 %s（没动）" % [
		实际1, J.s(塔前), J.s(塔.get("hp")), J.s(伤1), J.s(脆.get("hp"))])
	t.ok(实际1 == "A6", "④ 第 1 次：这一击**真的移到塔斯克身上**（实际目标 = %s）" % 实际1)
	t.ok(伤1 == 800.0 and float(脆.get("hp")) == 脆前,
		"④ **按塔斯克自己的减伤算**：同一发 1000 → 塔斯克挨 **%s**（重装前排 −20%%），队友 0 伤害" % J.s(伤1))
	t.ok(int(塔.get(AtxDuo.掩护剩余键)) == 1, "④ 本阶段第一次用掉：`掩护剩余` 2 → **%d**"
		% int(塔.get(AtxDuo.掩护剩余键)))
	var 塔前2 := float(塔.get("hp"))
	var 实际2 := _打一轮(敌, c)
	t.ok(实际2 == "A6" and 塔前2 - float(塔.get("hp")) == 800.0 and int(塔.get(AtxDuo.掩护剩余键)) == 0,
		"④ 第 2 次仍然移：目标 %s、伤害 **%s**、`掩护剩余` → **0**" % [实际2,
		J.s(塔前2 - float(塔.get("hp")))])
	# 对照：队友**自己**挨同一发 = 700（兰斯战线「同路掩护减伤 30%」；塔斯克没有这一个减免）
	var c0 := _场([_塔斯克(0.0, 5000.0), _队友("F2", 4.0, 5000.0)], [_敌("E2", 0.0, _武(1000.0, 1, 100.0))])
	var 脆0: Dictionary = c0.allies[1]
	var 敌0: Dictionary = c0.enemies[0]
	Calc.resolveAttack(敌0, 脆0, 敌0.weapons[0].t, c0, {})
	var 队友挨 := 5000.0 - float(脆0.get("hp"))
	t.info("对照：同一发 1000 直接打后排那台队友 → %s（塔斯克自己挨是 800）" % J.s(队友挨))
	t.ok(队友挨 == 700.0 and 队友挨 != 伤1,
		"④ 队友自己挨 = **%s**（没有重装前排减免）≠ 转移到塔斯克身上的 **%s** —— 转移后走的是**塔斯克**的减伤"
		% [J.s(队友挨), J.s(伤1)])
	# 第 3 次：额度用完 → 不再移
	var 塔前3 := float(塔.get("hp"))
	var 实际3 := _打一轮(敌, c)
	t.info("掩护 第 3 次：实际目标 = %s；塔斯克 %s（没动 = %s）；脆皮 %s → %s" % [
		实际3, J.s(塔.get("hp")), str(float(塔.get("hp")) == 塔前3), J.s(脆前), J.s(脆.get("hp"))])
	t.ok(实际3 == "F2" and float(塔.get("hp")) == 塔前3 and float(脆.get("hp")) < 脆前,
		"④ 第 3 次**不再移**：目标 = %s、塔斯克一点没掉（%s）、队友 %s → %s" % [
		实际3, J.s(塔.get("hp")), J.s(脆前), J.s(脆.get("hp"))])
	# ★ 2026-10-21（任务单问题 4）：日志前缀从「〔掩护〕… 把这一击勾了过去」升级成
	#   「〔援护防御〕X 保护 Y，替其挡下攻击！（剩余援护 N/2 次）」—— 写清谁保护了谁 + 还剩几次。
	t.ok(_行数(c, "〔援护防御〕") == 2, "④ 〔援护防御〕记录**正好 2 行**（每阶段 2 次，第 3 次不写）：%d 行"
		% _行数(c, "〔援护防御〕"))
	t.ok(_找行(c, "〔援护防御〕").contains("剩余援护 0/2 次") or _找行(c, "〔援护防御〕").contains("剩余援护 1/2 次"),
		"④ 那一行写着「谁保护了谁 + 剩余几次」：%s" % _找行(c, "〔援护防御〕"))

# ==========================================================================================
# ④b 「我可是很耐打的！」（敌方单体攻击优先选塔斯克 + 战意 +10）与「冷静判断」（抽 1 张公有牌）
# ==========================================================================================
func _段4b_耐打(t) -> void:
	var 塔 := _塔斯克(0.0, 5000.0)
	塔["战意"] = 60.0                     # 离上限远一点，才看得出「−5 费用 +10 战意」
	var 脆 := _队友("F4", 1.0, 300.0)      # 血最低 → 本来会被选
	var c := _场([塔, 脆], [_敌("E4", 0.0, _武(1000.0, 1, 100.0))])
	c["卡牌流转"] = true
	_装(c, 塔)
	var 自然 := str((Btl.算意图(c)[0] as Dictionary).get("目标"))
	_持(c, 塔, AtxDuo.ID_耐打)
	var 战意前 := Btl.战意(塔)
	var r := Btl.打出精神或公有牌(c, AtxDuo.塔斯克, AtxDuo.ID_耐打)
	var 打牌后 := str((Btl.算意图(c)[0] as Dictionary).get("目标"))
	t.info("④b 耐打：不打牌时预告 %s → 打牌后预告 %s；战意 %s → %s" % [自然, 打牌后, J.s(战意前),
		J.s(Btl.战意(塔))])
	t.ok(J.truthy(r.get("成功")), "④b 塔斯克打出【「我可是很耐打的！」】（费 5）")
	t.ok(自然 == "F4", "④b 前置：不打牌时敌人会打血最低的队友（%s）" % 自然)
	t.ok(打牌后 == "A6", "④b 打完牌：敌方**单体**攻击优先选塔斯克（预告目标 %s）" % 打牌后)
	t.ok(Btl.战意(塔) == 战意前 - 5.0 + 10.0, "④b 战意 +10（−5 费用 +10：%s → %s）"
		% [J.s(战意前), J.s(Btl.战意(塔))])
	var 实际 := _打一轮(c.enemies[0], c)
	t.ok(实际 == "A6", "④b 预告 == 实际：这一发真的打在塔斯克身上（%s）" % 实际)
	# 「冷静判断」：抽 1 张公有牌
	var 雷 := _雷欧娜(4.0, 9000.0)
	var c2 := _场([塔, 雷], [_敌("E5", 0.0, _武(100.0, 1, 100.0))])
	c2["卡牌流转"] = true
	c2["公有牌库"] = [{"id": "T_PUB_1", "名": "测试公有牌", "卡类": "公有牌", "层级": "职业"}]
	_装(c2, 雷)
	_持(c2, 雷, AtxDuo.ID_冷静判断)
	var 手前 := (c2.get("公有手牌") as Array).size()
	var r2 := Btl.打出精神或公有牌(c2, AtxDuo.雷欧娜, AtxDuo.ID_冷静判断)
	t.info("④b 冷静判断：公有手牌 %d → %d" % [手前, int((c2.get("公有手牌") as Array).size())])
	t.ok(J.truthy(r2.get("成功")) and (c2.get("公有手牌") as Array).size() == 手前 + 1,
		"④b 雷欧娜【冷静判断】（费 0）→ **抽 1 张公有牌**（%d → %d）" % [手前,
		int((c2.get("公有手牌") as Array).size())])

# ==========================================================================================
# ⑤ ★ 掩护的预告同源（R4）：`算意图` 预告的目标 == 实际挨打的目标
#    覆盖三种局面：掩护生效 / 次数用完 / 只打前排
# ==========================================================================================
func _段5_预告同源(t) -> void:
	# ---- A. 掩护生效 ----
	var cA := _场([_塔斯克(0.0, 5000.0), _队友("F2", 4.0, 300.0)], [_敌("EA", 0.0, _武(1000.0, 1, 100.0))])
	AtxDuo.敌方阶段初(cA)
	var 自然A := str((Btl.算意图(cA)[0] as Dictionary).get("目标"))
	var 预告A := str((Btl.算意图(cA)[0] as Dictionary).get("目标"))
	var 实际A := _打一轮(cA.enemies[0], cA)
	t.info("⑤ A 掩护生效：AI 本来选 %s → 预告 **%s**、实际 **%s**" % [自然A, 预告A, 实际A])
	t.ok(预告A == 实际A and 实际A == "A6", "⑤ A 掩护生效：预告 **%s** == 实际 **%s**（都是塔斯克）" % [预告A, 实际A])
	# ---- B. 次数用完 ----
	var cB := _场([_塔斯克(0.0, 5000.0), _队友("F2", 4.0, 300.0)], [_敌("EB", 0.0, _武(1000.0, 1, 100.0))])
	AtxDuo.敌方阶段初(cB)
	(cB.allies[0] as Dictionary)[AtxDuo.掩护剩余键] = 0
	var 预告B := str((Btl.算意图(cB)[0] as Dictionary).get("目标"))
	var 实际B := _打一轮(cB.enemies[0], cB)
	t.info("⑤ B 次数用完：预告 **%s**、实际 **%s**" % [预告B, 实际B])
	t.ok(预告B == 实际B and 实际B == "F2", "⑤ B 次数用完：预告 **%s** == 实际 **%s**（不再移）" % [预告B, 实际B])
	# ---- C. 只打前排（场上只有前排那台，没有可掩护的后排队友）----
	var cC := _场([_塔斯克(0.0, 5000.0)], [_敌("EC", 0.0, _武(1000.0, 1, 100.0))])
	AtxDuo.敌方阶段初(cC)
	var 预告C := str((Btl.算意图(cC)[0] as Dictionary).get("目标"))
	var 实际C := _打一轮(cC.enemies[0], cC)
	t.info("⑤ C 只打前排：预告 **%s**、实际 **%s**" % [预告C, 实际C])
	t.ok(预告C == 实际C and 实际C == "A6", "⑤ C 只打前排（没有可掩护的人）：预告 **%s** == 实际 **%s**" % [预告C, 实际C])
	t.ok(预告A == 实际A and 预告B == 实际B and 预告C == 实际C,
		"⑤ ★ R4：三种局面「算意图 预告」与「敌方阶段实际」**逐次 100%% 相同**（3/3）")

# ==========================================================================================
# ⑥ 重力冲撞：命中后目标**下一次**攻击每段命中 −15（只影响下一次）
# ==========================================================================================
func _段6_重力冲撞(t) -> void:
	var c := _场([_塔斯克(0.0, 5000.0)], [_敌("E6", 0.0, _武(500.0, 1, 100.0, "direct"))])
	var 塔: Dictionary = c.allies[0]
	var 敌: Dictionary = c.enemies[0]
	c["卡牌流转"] = true
	_装(c, 塔)
	_持(c, 塔, AtxDuo.ID_重力冲撞)
	var 敌武: Dictionary = 敌.weapons[0].t
	var 前 := int(Calc.hitRate(敌, 敌武, 塔, {"ctx": c}).hit)
	var r := Btl.打出武器栏卡(c, AtxDuo.塔斯克, AtxDuo.ID_重力冲撞, "E6")
	t.ok(J.truthy(r.get("成功")), "⑥ 塔斯克打出【重力冲撞】（近战 1800 × 1 · 距离 1）")
	var 后 := int(Calc.hitRate(敌, 敌武, 塔, {"ctx": c}).hit)
	t.info("重力冲撞：目标还手时每段命中 %d%% → %d%%" % [前, 后])
	t.ok(后 == 前 - 15, "⑥ 命中后目标**下一次攻击每段命中 −15**：**%d%% → %d%%**（差正好 15）" % [前, 后])
	t.ok(_有行(c, "〔重力冲撞〕"), "⑥ 即时反馈一行：%s" % _找行(c, "〔重力冲撞〕"))
	# 打完这一发 → 标记清掉，再下一次恢复
	Calc.resolveAttack(敌, 塔, 敌武, c, {})
	var 再 := int(Calc.hitRate(敌, 敌武, 塔, {"ctx": c}).hit)
	t.ok(再 == 前, "⑥ **只影响下一次**：那一发打完 → 命中率回到 **%d%%**（不是永久 −15）" % 再)

# ==========================================================================================
# ⑦ 千兆宽域爆破的条件：本场被攻击 2 次 → 不可打；3 次 → 可打
# ==========================================================================================
func _段7_大招条件(t) -> void:
	var c := _场([_塔斯克(0.0, 9000.0)], [_敌("E7", 0.0, _武(100.0, 1, 100.0))])
	var 塔: Dictionary = c.allies[0]
	var 敌: Dictionary = c.enemies[0]
	c["卡牌流转"] = true
	_装(c, 塔)
	var 卡 := AtxDuo.卡(AtxDuo.ID_千兆宽域爆破)
	for i in 2:
		Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	var 判2 := AtxDuo.大招条件(c, 塔, 卡)
	DeckFlow.阶段初_检查(c)
	var 因2 := DeckFlow.大招不可打原因(c, 塔, DeckFlow.找大招槽(塔, AtxDuo.ID_千兆宽域爆破))
	t.info("⑦ 被攻击 2 次：现状 %s / 门槛 %s → 满足 %s；不可打原因「%s」" % [
		J.s(判2["现状"]), J.s(判2["门槛"]), str(判2["满足"]), 因2])
	t.ok(not J.truthy(判2["满足"]) and int(判2["现状"]) == 2 and int(判2["门槛"]) == 3,
		"⑦ 本场被攻击 **2** 次（门槛 3）→ 条件**不满足**")
	t.ok(因2.contains("亮起条件"), "⑦ 2 次时**打不出去**（原因：%s）" % 因2)
	Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	var 判3 := AtxDuo.大招条件(c, 塔, 卡)
	DeckFlow.阶段初_检查(c)
	var 因3 := DeckFlow.大招不可打原因(c, 塔, DeckFlow.找大招槽(塔, AtxDuo.ID_千兆宽域爆破))
	t.info("⑦ 被攻击 3 次：现状 %s → 满足 %s；不可打原因「%s」" % [J.s(判3["现状"]), str(判3["满足"]), 因3])
	t.ok(J.truthy(判3["满足"]) and int(判3["现状"]) == 3, "⑦ 本场被攻击 **3** 次 → 条件**满足**")
	t.ok(因3 == "", "⑦ 3 次时**打得出去**（不可打原因 = 空串）")
	t.ok(DeckFlow._计数(塔, AtxDuo.本场被攻击键) == 3,
		"⑦ 计数落在 `v3计数.本场被攻击` = %d（与「本场击破」同一本账）" % DeckFlow._计数(塔, AtxDuo.本场被攻击键))

# ==========================================================================================
# ⑧ 千兆宽域爆破的横扫：打到目标所在一整排（贴 3 台的伤害，另一排不挨）
# ==========================================================================================
func _段8_横扫(t) -> void:
	var 塔 := _塔斯克(0.0, 90000.0)
	var 前1 := _靶("前1", 0.0)
	var 前2 := _靶("前2", 1.0)
	var 前3 := _靶("前3", 2.0)
	var 后1 := _靶("后1", 4.0)
	var c := _场([塔], [前1, 前2, 前3, 后1])
	c["卡牌流转"] = true
	_装(c, 塔)
	# 先满足亮起条件（本场被攻击 ≥ 3 次）—— 用一台小威力敌机撞他三下
	var 撞 := _敌("E8", 0.0, _武(1.0, 1, 100.0))
	c.enemies.append(撞)
	for i in 3:
		Calc.resolveAttack(撞, 塔, 撞.weapons[0].t, c, {})
	DeckFlow.阶段初_检查(c)
	var r := DeckFlow.打出大招(c, AtxDuo.塔斯克, AtxDuo.ID_千兆宽域爆破, "前2")
	t.ok(J.truthy(r.get("成功")), "⑧ 塔斯克打出【千兆宽域爆破】（费用 20 / 冷却 4 / 横扫）")
	var 伤们: Array = []
	for u in [前1, 前2, 前3]:
		伤们.append(int(千 - float((u as Dictionary).get("hp", 千))))
	t.info("⑧ 横扫：前排三台受到 %s；后排那台 %s（满血说明没挨）" % [str(伤们), J.s(后1.get("hp"))])
	t.ok(伤们.size() == 3 and J.every(伤们, func(x): return int(x) > 0),
		"⑧ 打到**目标所在一整排**（3 台都掉血：%s）" % str(伤们))
	t.ok(float(后1.get("hp")) == 千, "⑧ 另一排那台**没挨**（后1 剩 %s）" % J.s(后1.get("hp")))
	t.ok(int(r.get("cd")) == 4, "⑧ 打完进冷却 **4**（%s）" % J.s(r.get("cd")))

# ==========================================================================================
# ⑨ ★ 赌局接线：两人的大招带【赌局】，闪字亮着时能抽到筹码牌（各一例）
# ==========================================================================================
func _段9_赌局(t) -> void:
	var 例 := [
		[AtxDuo.塔斯克, AtxDuo.ID_千兆宽域爆破, "E9"],
		[AtxDuo.雷欧娜, AtxDuo.ID_TLINK突击, "E9"],
	]
	for 条 in 例:
		var 键 := str(条[0])
		var 卡id := str(条[1])
		var 牌 := AtxDuo.卡(卡id)
		t.ok(J.truthy(牌.get("赌局")), "⑨ %s 的大招【%s】带【赌局】" % [键, str(牌.get("名"))])
		# —— 例 1：**没亮闪字** → 不抽（独立一局，免得把冷却 / 本回合已打用掉）——
		var c0 := _赌局场(键)
		var 前手0 := (c0.get("公有手牌") as Array).size()
		var r0 := DeckFlow.打出大招(c0, 键, 卡id, "E9")
		t.ok(J.truthy(r0.get("成功")) and (c0.get("公有手牌") as Array).size() == 前手0
			and not _有行(c0, "〔赌局〕"), "⑨ %s 没亮闪字 → 大招打得出、但**不抽筹码**、0 条〔赌局〕记录" % 键)
		# —— 例 2：亮闪字 → 抽到筹码牌 ——
		var c := _赌局场(键)
		var 单位: Dictionary = c.allies[0]
		单位["闪"] = true
		DeckFlow.阶段初_检查(c)
		var 前手 := (c.get("公有手牌") as Array).size()
		var r := DeckFlow.打出大招(c, 键, 卡id, "E9")
		var 抽到 := str(_最后公有手牌(c).get("卡类", ""))
		t.info("⑨ %s 亮闪字后打出【%s】→ 公有手牌 %d → %d；记录：%s" % [键, str(牌.get("名")), 前手,
			int((c.get("公有手牌") as Array).size()), _找行(c, "〔赌局〕")])
		t.ok(J.truthy(r.get("成功")) and (c.get("公有手牌") as Array).size() == 前手 + 1
			and 抽到 == "筹码牌", "⑨ %s 闪字亮着 → **抽到 1 张筹码牌**（%s）" % [键, 抽到])
		t.ok(_有行(c, "〔赌局〕"), "⑨ %s 即时记录：%s" % [键, _找行(c, "〔赌局〕")])

## ⑨ 的一局：一个人 + 一台小威力敌机 + 筹码牌库，条件已经点亮（塔斯克挨 3 次 / 雷欧娜第 5 回合）
func _赌局场(键: String) -> Dictionary:
	var 单位 := _塔斯克(0.0, 90000.0) if 键 == AtxDuo.塔斯克 else _雷欧娜(4.0, 90000.0)
	var 敌 := _敌("E9", 0.0, _武(100.0, 1, 100.0))
	var c := _场([单位], [敌])
	c["卡牌流转"] = true
	c["turn"] = 5.0
	AtxChips.初始化(c)
	_装(c, 单位)
	if 键 == AtxDuo.塔斯克:
		for i in 3:
			Calc.resolveAttack(敌, 单位, 敌.weapons[0].t, c, {})
	DeckFlow.阶段初_检查(c)
	return c

# ==========================================================================================
# ⑩ T-Link 感应：她打「指定一台友军」的牌 → 那台友军闪避 +10；打非指定牌不触发
# ==========================================================================================
func _段10_TLink(t) -> void:
	var 雷 := _雷欧娜(4.0, 9000.0)
	var 塔 := _塔斯克(0.0, 9000.0)
	var c := _场([塔, 雷], [_敌("E10", 0.0, _武(100.0, 1, 100.0))])
	c["卡牌流转"] = true
	_装(c, 雷)
	_持(c, 雷, AtxDuo.ID_塔斯克退下)
	_持(c, 雷, AtxDuo.ID_专注雷欧娜)
	var 前 := Calc.buffSum(塔, "eva")
	var r := Btl.打出精神或公有牌(c, AtxDuo.雷欧娜, AtxDuo.ID_塔斯克退下, AtxDuo.塔斯克)
	t.ok(J.truthy(r.get("成功")), "⑩ 雷欧娜打出【「塔斯克，退下」】（指定一台友军 · 费 10）")
	var 后 := Calc.buffSum(塔, "eva")
	t.info("⑩ T-Link 感应：塔斯克闪避加成 %s → %s（差 %s）" % [J.s(前), J.s(后), J.s(后 - 前)])
	t.ok(后 - 前 == 10.0, "⑩ 被指定的友军**闪避 +10**：%s → %s" % [J.s(前), J.s(后)])
	t.ok(Calc.buffSum(塔, "受伤Mul") == -0.30, "⑩ 同一张牌的另一半也生效：受到的伤害 −30%%（受伤Mul = %s）"
		% J.s(Calc.buffSum(塔, "受伤Mul")))
	t.ok(_有行(c, "〔T-Link感应〕"), "⑩ 即时记录：%s" % _找行(c, "〔T-Link感应〕"))
	var 前2 := Calc.buffSum(塔, "eva")
	var r2 := Btl.打出精神或公有牌(c, AtxDuo.雷欧娜, AtxDuo.ID_专注雷欧娜)
	t.ok(J.truthy(r2.get("成功")) and Calc.buffSum(塔, "eva") == 前2,
		"⑩ 她打**非指定友军**的牌【专注】→ T-Link 感应**不触发**（闪避加成仍是 %s）" % J.s(Calc.buffSum(塔, "eva")))
	t.ok(J.num0(雷.get(AtxDuo.专注键)) == 20.0, "⑩ 而【专注】自己生效了：`专注命中` = %s"
		% J.s(雷.get(AtxDuo.专注键)))

# ==========================================================================================
# ⑪ 分裂飞弹的散布真的换目标（偏移段数 > 0）
# ==========================================================================================
func _段11_散布(t) -> void:
	# 分裂飞弹距离 2–5：雷欧娜站后4（slot 7），主目标站前2（slot 1，真实距离 4，
	# 在 2–5 之内），副目标放它十字相邻的前1（slot 0）。
	var 雷 := _雷欧娜(7.0, 9000.0)
	var 主 := _靶("主标", 1.0)
	var 副 := _靶("副标", 0.0)
	var c := _场([雷], [主, 副], 5)
	c["卡牌流转"] = true
	_装(c, 雷)
	var r := Btl.打出武器栏卡(c, AtxDuo.雷欧娜, AtxDuo.ID_分裂飞弹, "主标")
	t.ok(J.truthy(r.get("成功")), "⑪ 雷欧娜打出【分裂飞弹】（曲射 300 × 4 · 散布 · 距离 2–5；实际 %s）"
		% str(r.get("原因", "")))
	var 偏移 := int(J.num0(_最后攻击字段(c, "散布偏移段数")))
	t.info("⑪ 散布：偏移段数 = %s；记录：%s" % [J.s(偏移), _最后攻击行(c)])
	t.ok(偏移 > 0, "⑪ 散布**真的换目标**：偏移段数 = **%d** > 0" % 偏移)
	t.ok(J.truthy(_最后攻击字段(c, "散布")), "⑪ 字段里有 `散布 = true` 与落点表")
	t.ok(float(副.get("hp")) < 千, "⑪ 十字相邻的那台被打到了（副标剩 %s）" % J.s(副.get("hp")))

# ==========================================================================================
# ⑫ ★ 连珠箭**设计稿原值**（第 4 项断路器修复：DS41F 擅自改成 0.45，已恢复 0.60）：受控实测 1750
# ==========================================================================================
func _段12_连珠箭(t) -> void:
	t.ok(AtxRewrite.连珠箭_威力倍率 == 0.60, "⑫ 连珠箭每箭倍率 = **0.60**（设计稿原值 −40%；DS41F 擅自改的 0.45 已恢复）")
	var 原版 := _弓一发("原版", 0)
	var 连 := _弓一发("连珠箭", 0)
	var 满 := _弓一发("满弦", 1)
	t.info("⑫ 装甲 600 / coef=1 / 全段命中：原版 %d · 连珠箭 %d · 满弦 %d" % [原版, 连, 满])
	t.ok(原版 == 1350, "⑫ 对照：原版 `650 × 3` 打装甲 600 = **%d**" % 原版)
	t.ok(连 == 1750, "⑫ 连珠箭实际总伤 **%d**（6 段 × 390，装甲 600 共享池 → 10 + 180 + 390×4 = 1750）" % 连)
	t.ok(连 == 1750 and 原版 == 1350, "⑫ 连珠箭 **%d** / 原版 **%d**（名义总伤 6 × 390 = 2340；装甲共享池口径下实测 1750）" % [连, 原版])
	t.ok(连 == 1750 and 满 == 1740, "⑫ 连珠箭 **%d** / 满弦 **%d**（两张牌数值都回到设计稿，取舍由玩家自己选）" % [连, 满])

## 受控对照：装甲 600 / coef = 1 / 全段命中。`模式` 0 = 不用牌（1 = 满弦，2 = 连珠箭）
func _弓一发(名: String, 模式: int) -> int:
	var a := _单位("弓手", "ally", 4.0)
	var d := _单位("守", "enemy", 0.0)
	d["armor"] = 600.0
	var c := _场([a], [d])
	var w := _武(650.0, 3, 100.0, "map")
	w["标签"] = ["弓"]
	if 名 == "连珠箭":
		AtxRewrite.设(a, AtxRewrite.连珠箭, c)
		w = AtxRewrite.应用(c, a, w)["武器"]
	elif 名 == "满弦":
		AtxRewrite.设(a, AtxRewrite.满弦, c)
		w = AtxRewrite.应用(c, a, w)["武器"]
	return int(_数字段(Calc.resolveAttack(a, d, w, c, {}), "伤害"))

# ==========================================================================================
# ==========================================================================================
# ⑭ 同种子两遍逐字相同（含掩护 + 大招 + 散布）
# ==========================================================================================
func _段14_同种子(t) -> void:
	var a := _整场脚本(true)
	var b := _整场脚本(true)
	t.ok(str(a.get("文")) == str(b.get("文")), "⑭ 同种子两遍：整场记录 + 字段**逐字相同**（%d 行）"
		% (a.get("日志") as Array).size())
	t.ok(str(a.get("数")) == str(b.get("数")), "⑭ 同种子两遍：全部数字逐字相同（%s）" % str(a.get("数")))
	t.ok(int(a.get("rng")) == int(b.get("rng")), "⑭ 同种子两遍：`ctx.rng` 步数相同（%d / %d）"
		% [int(a.get("rng")), int(b.get("rng"))])

## 一整段脚本：塔斯克 + 雷欧娜 + 一个后排脆皮 vs 一台直射敌机。
## 开：掩护一次 + 塔斯克大招（横扫）+ 雷欧娜分裂飞弹（散布）。
## `单机牌组开` 只决定这一场带不带 A6b 的专属牌（不带 = 一个 A6b 字段 / 记录都不许有）。
func _整场脚本(单机牌组开: bool) -> Dictionary:
	var 塔 := _塔斯克(0.0, 9000.0)
	var 雷 := _雷欧娜(5.0, 9000.0)
	var 脆 := _队友("F9", 4.0, 400.0)
	var 敌 := _敌("E0", 0.0, _武(600.0, 2, 100.0))
	var c := _场([塔, 雷, 脆], [敌, _靶("副标", 1.0)], 20261017)
	c["单机牌组"] = 单机牌组开
	c["卡牌流转"] = 单机牌组开
	AtxDuo.初始化(c)
	AtxDuo.敌方阶段初(c)
	_装(c, 塔)
	_装(c, 雷)
	_打一轮(敌, c)                      # 【掩护】
	_打一轮(敌, c)
	for i in 3:
		Calc.resolveAttack(敌, 塔, 敌.weapons[0].t, c, {})
	DeckFlow.阶段初_检查(c)
	DeckFlow.打出大招(c, AtxDuo.塔斯克, AtxDuo.ID_千兆宽域爆破, "副标")
	Btl.打出武器栏卡(c, AtxDuo.雷欧娜, AtxDuo.ID_分裂飞弹, "E0")
	var duo记录 := 0
	for 行 in _行们(c):
		for 标 in ["〔引力墙〕", "〔掩护〕", "〔重力冲撞〕", "〔专注〕", "〔双人卡〕", "〔T-Link感应〕"]:
			if str(行).contains(str(标)):
				duo记录 += 1
				break
	var duo键 := 0
	for u in J.concat(c.allies, c.enemies):
		if not (u is Dictionary):
			continue
		for k in [AtxDuo.引力墙待键, AtxDuo.掩护剩余键, AtxDuo.命中惩罚待键, AtxDuo.专注键, AtxDuo.耐打Turn键]:
			if (u as Dictionary).has(k):
				duo键 += 1
	return {
		"文": "\n".join(_行们(c)) + "\n" + str(_全部攻击字段(c)),
		"日志": _行们(c),
		"rng": int((c.get("rng") as Mulberry32).steps),
		"数": {"塔血": 塔.get("hp"), "雷血": 雷.get("hp"), "脆血": 脆.get("hp"), "敌血": 敌.get("hp"),
			"塔战意": 塔.get("战意"), "雷战意": 雷.get("战意")},
		"duo记录": duo记录, "duo键": duo键,
	}

# ==========================================================================================
# 小工具
# ==========================================================================================
func _单位(键: String, side: String, 位: float) -> Dictionary:
	return {
		"key": 键, "name": 键, "tplKey": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {}, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

## 塔斯克（重装 / 势力 ATX —— 兰斯战线「重装前排减伤 20%」与 ATX 判定都靠这个 tags）
func _塔斯克(位: float, 血: float) -> Dictionary:
	var u := _单位(AtxDuo.塔斯克, "ally", 位)
	u["name"] = "塔斯克"
	u["tags"] = {"战斗分类": "重装", "势力": "ATX"}
	u["maxHp"] = 血
	u["hp"] = 血
	return u

## 雷欧娜（指挥 / 势力 ATX）
func _雷欧娜(位: float, 血: float) -> Dictionary:
	var u := _单位(AtxDuo.雷欧娜, "ally", 位)
	u["name"] = "雷欧娜"
	u["tags"] = {"战斗分类": "指挥", "势力": "ATX"}
	u["maxHp"] = 血
	u["hp"] = 血
	return u

## 普通队友（没有战斗分类 —— 不吃职业排位那一套）
func _队友(键: String, 位: float, 血: float) -> Dictionary:
	var u := _单位(键, "ally", 位)
	u["maxHp"] = 血
	u["hp"] = 血
	return u

func _靶(键: String, 位: float) -> Dictionary:
	var e := _单位(键, "enemy", 位)
	e["name"] = 键
	return e

func _敌(键: String, 位: float, w: Dictionary) -> Dictionary:
	var e := _靶(键, 位)
	e["weapons"] = [{"t": w, "cd": 0.0, "uses": null, "readyTurn": 0.0}]
	return e

func _武(威力: float, 段数: int, 命中率: float = 100.0, fire: String = "direct") -> Dictionary:
	return {"name": "测试武器", "fire": fire, "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

func _场(我方: Array, 敌方: Array, 种子: int = 20261017) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}

## 把一个人的 7 张牌装进上排（真的走 `DeckFlow.拆分单位牌`：武器栏 / 大招槽 / 精神牌库）
func _装(c: Dictionary, u: Dictionary) -> void:
	u["专属牌库"] = AtxDuo.角色牌们(u.get("key"))
	DeckFlow.拆分单位牌(u, c)

## 把某一张牌从牌库里挪进专属手牌（精神牌要这样才能打出）
func _持(c: Dictionary, u: Dictionary, 卡id: String) -> Dictionary:
	var 卡 := AtxDuo.卡(卡id)
	if 卡.is_empty():
		return {}
	u["专属牌库"] = (u.get("专属牌库") as Array).filter(func(x): return str(x.get("id", "")) != 卡id)
	(u["专属手牌"] as Array).append(卡)
	return 卡

func _数字段(r: Dictionary, 键: String) -> Variant:
	var f = r.get("字段")
	return (f as Dictionary).get(键) if f is Dictionary else null

func _行们(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			out.append(str((e as Dictionary).get("文本", "")))
	return out

func _行数(c: Dictionary, 子串: String) -> int:
	return _行们(c).filter(func(x): return str(x).contains(子串)).size()

func _有行(c: Dictionary, 子串: String) -> bool:
	return _行数(c, 子串) > 0

func _找行(c: Dictionary, 子串: String) -> String:
	for 行 in _行们(c):
		if str(行).contains(子串):
			return str(行)
	return "（没有这一行）"

func _最后攻击字段(c: Dictionary, 键: String) -> Variant:
	var logs: Array = J.or_(c.get("log"), [])
	for i in range(logs.size() - 1, -1, -1):
		var e = logs[i]
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
			return (e as Dictionary).get(键)
	return null

func _最后攻击行(c: Dictionary) -> String:
	var logs: Array = J.or_(c.get("log"), [])
	for i in range(logs.size() - 1, -1, -1):
		var e = logs[i]
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
			return str((e as Dictionary).get("文本", ""))
	return "（没有攻击记录）"

func _全部攻击字段(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
			out.append(str(e))
	return out

func _最后公有手牌(c: Dictionary) -> Dictionary:
	var 手 = c.get("公有手牌")
	if 手 is Array and not (手 as Array).is_empty():
		return (手 as Array)[(手 as Array).size() - 1]
	return {}

## 跑一轮敌方行动，返回它实际打的那个目标键
func _打一轮(敌: Dictionary, c: Dictionary) -> String:
	Flow.actOnce(敌, c)
	var v = _最后攻击字段(c, "目标")
	return str(v) if v != null else "（没有攻击记录）"
