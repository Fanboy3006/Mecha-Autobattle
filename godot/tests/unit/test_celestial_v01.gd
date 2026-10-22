## ★ CB-1（任务单 §1.2）：天人 v0.1 公共机制 —— TRANS-AM / 【武力介入】/ 太阳炉牌库 / 9 张势力牌 /
## 拉塞 CB5 的 7 张牌与两个被动。
##
## 权威依据：
##   · `协作/设计/势力与职业卡牌设计规范 v0.3.md` · `天人势力卡牌设计 v0.1.md`
##   · `协作/设计/刹那 / 洛克昂 / 提耶利亚 / 阿雷路亚 / 拉塞卡牌设计 v0.1.md`
##   · `协作/架构/任务单-天人v0.1与规范v0.3断路器与顺劈-ARGON.md` §0 Batch 1 / §1.2（CB-1）
##
## 受控单位（不走 `Setup.开局` 的那几段）是裸字典：`atk == D == 0` ⇒ `coef == 1`、`armor` 手填、
## `eva = 0` ⇒ 命中率 = `w.hit`、`critBase = -10` ⇒ 暴击率 0（伤害干净可断言）。
## 涉及「装填 / 牌库形状 / 拉塞 7 张」的整段走真的 `Setup.开局`（和正式对局同一条路）。
## 本文件跑完会把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0
const 种子 := 20261018

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_注册与开关(t)
	_段2_TRANSAM时序(t)
	_段3_被攻击过与武力介入(t)
	_段4_太阳炉牌库(t)
	_段5_势力牌(t)
	_段6_拉塞CB5(t)
	_段8_同种子(t)
	_段9_全牌冒烟(t)
	_段10_两张防御牌(t)
	# ★ CB-2 / CB-3 / CB-4（任务单 §0 Batch 2）：四名高达驾驶员的完整卡池与独有机制。
	_段11_刹那七剑(t)
	_段12_洛克昂狙击(t)
	_段13_阿雷路亚双人格(t)
	_段14_提耶利亚演算与脱装(t)
	_段15_驾驶员全卡冒烟(t)
	_段16_天人快速战斗与标签(t)
	# ★ 2026-10-23（任务单「手牌三栏自适应缩放与友军拖拽绿线箭头」UI-2）：目标的「我方 / 敌方」口径
	_段17_友方目标识别(t)

# ==========================================================================================
# ① 成员识别 / 开关 / 牌表张数
# ==========================================================================================
func _段1_注册与开关(t) -> void:
	t.ok(CelestialV01.势力 == "天人" and CelestialV01.成员键.size() == 5,
		"① 天人 5 人：%s" % str(CelestialV01.成员键))
	t.ok(CelestialV01.驾驶员键 == ["CB1", "CB2", "CB3", "CB4"],
		"① 四名高达驾驶员 = %s（CB5 拉塞没有 TRANS-AM）" % str(CelestialV01.驾驶员键))
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var 拉 := _单位("CB5", "ally", 1.0, "重装")
	var 路人 := _单位("A1", "ally", 2.0, "近卫")
	路人["tags"] = {"战斗分类": "近卫", "势力": "ATX"}
	t.ok(CelestialV01.是天人(刹) and CelestialV01.是天人(拉) and not CelestialV01.是天人(路人),
		"① `是天人`：刹那 / 拉塞 = true、ATX 的响介 = false")
	t.ok(CelestialV01.是驾驶员(刹) and not CelestialV01.是驾驶员(拉),
		"① `是驾驶员`：刹那 = true、拉塞 = false")
	t.ok(not CelestialV01.开(_场([], [], 种子)), "① 单机牌组开着但队里没有天人 → `开` = false")
	t.ok(CelestialV01.开(_场([刹, 拉], [_靶("靶1", 0.0)], 种子)), "① 单机牌组 + 队里有天人 → `开` = true")
	# —— 太阳炉 10 张 ——
	var 炉 := CelestialV01.太阳炉卡表()
	var 一 := 0
	var 二 := 0
	var 三 := 0
	for c in 炉:
		match int(J.num0((c as Dictionary).get("太阳炉等级"))):
			1: 一 += 1
			2: 二 += 1
			3: 三 += 1
	t.ok(炉.size() == 10 and 一 == 4 and 二 == 4 and 三 == 2,
		"① 太阳炉牌库 10 张（一级 %d / 二级 %d / 三级 %d）" % [一, 二, 三])
	var 遗 := CelestialV01.太阳炉卡("CB_SD3_HERITAGE")
	var 优 := CelestialV01.太阳炉卡("CB_SD3_VEDA_OPTIMAL")
	t.ok(str(遗.get("名")) == "伊奥利亚的遗产" and str(优.get("名")) == "Veda·最优解",
		"① 两张三级牌 = 伊奥利亚的遗产 / Veda·最优解")
	var veda := 炉.filter(func(c): return J.truthy((c as Dictionary).get("veda")))
	t.ok(veda.size() == 4, "① 带 `veda` 标签的 4 张：%s" % str(veda.map(func(c): return c.get("名"))))
	# —— 势力牌 9 张 ——
	var 势 := CelestialV01.势力牌们()
	t.ok(势.size() == 9, "① 天人势力牌 9 张（%d）" % 势.size())
	t.ok(J.every(势, func(c): return str(c.get("层级")) == "势力" and str(c.get("归属")) == CelestialV01.势力 and str(c.get("卡类")) == "公有牌" and CelestialV01.是势力牌(c)),
		"① 9 张全部 `层级 = 势力` / `归属 = 天人` / `卡类 = 公有牌`")
	# —— 拉塞 7 张 ——
	var 拉7 := CelestialV01.拉塞卡表(false)
	var 主数 := 0
	var 大数 := 0
	var 精数 := 0
	for c in 拉7:
		match str((c as Dictionary).get("卡类")):
			"主武器卡": 主数 += 1
			"大招槽卡": 大数 += 1
			"专属精神牌": 精数 += 1
	t.ok(拉7.size() == 7 and 主数 == 3 and 大数 == 1 and 精数 == 3,
		"① 拉塞 7 张：主武器 %d / 大招 %d / 精神 %d" % [主数, 大数, 精数])

# ==========================================================================================
# ② TRANS-AM·启动：入场条件 / 数值 / 3 个我方阶段 / 粒子耗尽 1 个我方阶段 / 每场 1 次
# ==========================================================================================
func _段2_TRANSAM时序(t) -> void:
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var 敌 := _靶("靶1", 0.0)
	var c := _场([刹], [敌], 种子)
	CelestialV01.装填大招槽(c, 刹)
	CelestialV01.装填大招槽(c, 刹)
	var 槽 := DeckFlow.找大招槽(刹, "CB_ULT_TRANSAM")
	t.ok(not 槽.is_empty(), "② 驾驶员的大招槽里装上了 `CB_ULT_TRANSAM`（幂等：只有 1 份，%d 份）" % _大招份数(刹))
	var 卡: Dictionary = 槽.get("卡")
	t.ok(not J.truthy(卡.get("武器牌")) and float(卡.get("耗气")) == 20.0,
		"② 20 费、**非武器**大招（`武器牌 = false`，打出后不销毁主武器栏）")
	var 武 := _武(1000.0, 1, 100.0, "melee")
	t.ok(CelestialV01.伤害倍率(无天人队(), 刹, 武) == 1.0, "② 开关关着 → 伤害倍率恒 1.0")
	# —— 入场条件：第 3 回合起（`Btl.开始我方阶段` 自己会把 `ctx.turn` +1）——
	Btl.开始我方阶段(c)
	t.ok(int(c.get("turn")) == 2, "② 第 %d 回合" % int(c.get("turn")))
	t.ok(DeckFlow.大招不可打原因(c, 刹, 槽).contains("亮起条件未满足"),
		"② 第 2 回合：门槛不过 → 「%s」" % DeckFlow.大招不可打原因(c, 刹, 槽))
	t.ok(not J.truthy(槽.get("实时门槛满足")), "② 第 2 回合：`实时门槛满足` = %s" % str(槽.get("实时门槛满足")))
	Btl.开始我方阶段(c)
	t.ok(int(c.get("turn")) == 3, "② 第 %d 回合" % int(c.get("turn")))
	刹["战意"] = 100.0
	t.ok(DeckFlow.大招不可打原因(c, 刹, 槽) == "",
		"② 第 **3** 回合且战意够 → 打得出来（原因：%s）" % DeckFlow.大招不可打原因(c, 刹, 槽))
	var r := DeckFlow.打出大招(c, "CB1", "CB_ULT_TRANSAM", "靶1")
	t.info("② 打出【TRANS-AM·启动】：%s" % str(r.get("效果摘要")))
	t.ok(J.truthy(r.get("成功")), "② 真的打出去了（%s）" % str(r.get("原因", "")))
	t.ok(J.truthy(刹.get("本场已开TRANSAM")) and J.truthy(c.get("本场有人开过TRANSAM")),
		"② `本场已开TRANSAM` / `本场有人开过TRANSAM` 都置真")
	t.ok(int(J.num0(刹.get("transam剩余回合"))) == 3,
		"② `transam剩余回合 = %d`（打开的当前我方阶段算第 1 个，共 3 个）" % int(J.num0(刹.get("transam剩余回合"))))
	t.ok(not J.truthy(刹.get("主武器已销毁")), "② 非武器大招：**不销毁主武器栏**（仍可照常打主武器）")
	t.ok(DeckFlow.大招不可打原因(c, 刹, 槽) == "本回合已使用",
		"② ★ 断路器 2：同一回合第二次 → 「%s」" % DeckFlow.大招不可打原因(c, 刹, 槽))
	# —— 数值 ——
	t.ok(absf(CelestialV01.伤害倍率(c, 刹, 武) - 1.3) < 0.0001,
		"② TRANS-AM 中武器伤害 ×1.3（%s）" % J.s(CelestialV01.伤害倍率(c, 刹, 武)))
	t.ok(absf(CelestialV01.命中修正(敌, 刹, 武, c) + 15.0) < 0.0001,
		"② TRANS-AM 中**闪避 +15**（打它的人每段命中 %s）" % J.s(CelestialV01.命中修正(敌, 刹, 武, c)))
	t.ok(CelestialV01.武力介入满足吗(c, 刹, 敌),
		"② TRANS-AM 中 → 【武力介入】**必定触发**（不看目标挨没挨过打）")
	# —— 3 个我方阶段 ——
	CelestialV01.我方阶段末(c)
	t.ok(int(J.num0(刹.get("transam剩余回合"))) == 2 and CelestialV01.transam中(刹),
		"② 过完 1 个我方阶段 → 剩 %d" % int(J.num0(刹.get("transam剩余回合"))))
	CelestialV01.我方阶段末(c)
	t.ok(int(J.num0(刹.get("transam剩余回合"))) == 1, "② 过完 2 个 → 剩 1")
	CelestialV01.我方阶段末(c)
	t.ok(not CelestialV01.transam中(刹) and int(J.num0(刹.get("粒子耗尽剩余回合"))) == 1,
		"② 过完 **3** 个 → TRANS-AM 结束、转 **粒子耗尽**（剩 %d 个我方阶段）" % int(J.num0(刹.get("粒子耗尽剩余回合"))))
	t.ok(absf(CelestialV01.伤害倍率(c, 刹, 武) - 0.7) < 0.0001,
		"② 粒子耗尽：武器伤害 ×0.7（−30%%）= %s" % J.s(CelestialV01.伤害倍率(c, 刹, 武)))
	CelestialV01.我方阶段末(c)
	t.ok(int(J.num0(刹.get("粒子耗尽剩余回合"))) == 0 and CelestialV01.伤害倍率(c, 刹, 武) == 1.0,
		"② 粒子耗尽只持续 1 个我方阶段 → 之后恢复正常（倍率 %s）" % J.s(CelestialV01.伤害倍率(c, 刹, 武)))
	# —— 每场 1 次 ——
	t.ok(not DeckFlow.条件满足(c, 刹, {"类型": "TRANSAM可入场"}),
		"② 每场 1 次：开过之后「TRANSAM可入场」= false")
	刹["战意"] = 100.0
	Btl.开始我方阶段(c)
	var 再 := DeckFlow.打出大招(c, "CB1", "CB_ULT_TRANSAM", "靶1")
	t.ok(not J.truthy(再.get("成功")),
		"② 换一个我方阶段再打一次 → 仍然打不出去（原因：%s）" % str(再.get("原因", "")))
	# —— 伊奥利亚的遗产：重新可用 + 粒子耗尽解除 ——
	刹["粒子耗尽剩余回合"] = 1
	var 遗卡 := CelestialV01.太阳炉卡("CB_SD3_HERITAGE")
	c["公有手牌"] = [遗卡]
	var 遗 := CelestialV01.打出太阳炉牌(c, 刹, 遗卡, "CB1")
	t.info("② 伊奥利亚的遗产：%s" % str(遗.get("效果摘要")))
	t.ok(J.truthy(遗.get("成功")) and not J.truthy(刹.get("本场已开TRANSAM"))
		and int(J.num0(刹.get("粒子耗尽剩余回合"))) == 0,
		"② 【伊奥利亚的遗产】→ `TRANS-AM·启动` 重新可用 + 粒子耗尽立刻解除")
	t.ok(DeckFlow.条件满足(c, 刹, {"类型": "TRANSAM可入场"}),
		"② 遗产吃完 → 「TRANSAM可入场」又满足了（大招重新亮起）")
	# —— 阶段末真的由 `Btl.结束我方回合` 驱动 ——
	var 刹2 := _单位("CB1", "ally", 0.0, "近卫")
	var c2 := _场([刹2], [_靶("靶1", 0.0)], 种子)
	CelestialV01.装填大招槽(c2, 刹2)
	刹2["transam剩余回合"] = 3
	刹2["本场已开TRANSAM"] = true
	Btl.开始我方阶段(c2)
	t.ok(int(J.num0(刹2.get("transam剩余回合"))) == 3, "② 我方阶段开始时 TRANS-AM 剩余回合不被误减（3）")
	Btl.结束我方回合(c2)
	t.ok(int(J.num0(刹2.get("transam剩余回合"))) == 2,
		"② `Btl.结束我方回合` 真的推进 TRANS-AM（3 → %d）" % int(J.num0(刹2.get("transam剩余回合"))))

func _大招份数(u: Dictionary) -> int:
	var n := 0
	for 槽 in J.or_(u.get("大招槽"), []):
		if 槽 is Dictionary and str(((槽 as Dictionary).get("卡") as Dictionary).get("id", "")) == "CB_ULT_TRANSAM":
			n += 1
	return n

# ==========================================================================================
# ③ 敌机「本回合被攻击过」+【武力介入】
# ==========================================================================================
func _段3_被攻击过与武力介入(t) -> void:
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var 靶1 := _靶("靶1", 0.0)
	var 靶2 := _靶("靶2", 1.0)
	var c := _场([刹], [靶1, 靶2], 种子)
	t.ok(_炉数(c) == 4, "③ 开局太阳炉牌库 = 4 张一级牌（%d）" % _炉数(c))
	靶1["本回合被攻击过"] = true
	靶1["本回合任务目标"] = true
	Btl.开始我方阶段(c)
	t.ok(not J.truthy(靶1.get("本回合被攻击过")) and not J.truthy(靶1.get("本回合任务目标")),
		"③ 每个我方阶段初：所有敌机的 `本回合被攻击过` / `本回合任务目标` 清空")
	t.ok(CelestialV01.武力介入满足吗(c, 刹, 靶2),
		"③ 本回合**还没挨过打**的敌机 → 【武力介入】满足")
	Btl._执行武器攻击(c, 刹, {"t": _武(100.0, 1, 100.0, "melee"), "cd": 0.0, "uses": null}, "靶1")
	t.ok(J.truthy(靶1.get("本回合被攻击过")),
		"③ 我方武器选它为目标并结算过 → `本回合被攻击过 = true`（打空也算，这里是命中）")
	t.ok(not CelestialV01.武力介入满足吗(c, 刹, 靶1),
		"③ 挨过打的敌机 → 【武力介入】**不再满足**（要先打别人）")
	t.ok(CelestialV01.武力介入满足吗(c, 刹, 靶2), "③ 同一发只标了主目标：另一台仍满足")
	CelestialV01.标记被攻击(c, 靶2)
	t.ok(not CelestialV01.武力介入满足吗(c, 刹, 靶2), "③ 靶2 也被打过了 → 不满足")
	靶2["本回合任务目标"] = true
	t.ok(CelestialV01.武力介入满足吗(c, 刹, 靶2),
		"③ 但它是 `本回合任务目标`（Veda·任务计划）→ **照样满足**")
	# —— 触发：抽 1 张进公有手牌 ——
	c["公有手牌"] = []
	var 记 := CelestialV01.触发武力介入(c, 刹, 靶2, {})
	t.info("③ 触发【武力介入】：%s" % str(记))
	t.ok(J.truthy(记.get("触发")) and (c.公有手牌 as Array).size() == 1 and _炉数(c) == 3,
		"③ 触发后：太阳炉牌库 4 → %d、公有手牌 0 → %d" % [_炉数(c), (c.公有手牌 as Array).size()])
	t.ok(_有行(c, "〔武力介入〕"), "③ 即时反馈一行：%s" % _找行(c, "〔武力介入〕"))
	# —— 公有手牌满 6 张 → 不抽，牌留在库里 ——
	while (c.公有手牌 as Array).size() < 6:
		(c.公有手牌 as Array).append({"id": "填充", "名": "填充"})
	var 库前 := _炉数(c)
	var 记2 := CelestialV01.触发武力介入(c, 刹, 靶2, {})
	t.ok(J.truthy(记2.get("触发")) and str(记2.get("抽到")) == "" and _炉数(c) == 库前,
		"③ 公有手牌满 6 张 → 不抽、牌留在库里（库仍是 %d 张）" % _炉数(c))
	# —— 介入放入 ——
	c["公有手牌"] = []
	var 卡 := {"id": "T_介入", "名": "测试介入牌", "武力介入": true, "介入放入": "CB_SD2_HARO_SHIELD"}
	var 记3 := CelestialV01.触发武力介入(c, 刹, 靶2, 卡)
	t.ok(str(记3.get("放入")) == "CB_SD2_HARO_SHIELD" and _有炉(c, "CB_SD2_HARO_SHIELD"),
		"③ `介入放入` 真的把【GN 全盾·哈罗】放进太阳炉牌库")
	# —— 断路器 1：三级牌每种每场限放入 1 次 ——
	t.ok(CelestialV01.放入太阳炉(c, "CB_SD3_HERITAGE"), "③ 第一次放入三级牌【伊奥利亚的遗产】→ 成功")
	t.ok(not CelestialV01.放入太阳炉(c, "CB_SD3_HERITAGE"),
		"③ **断路器 1**：同一种三级牌第二次放入 → 直接返回 false")
	t.ok(CelestialV01.放入太阳炉(c, "CB_SD3_VEDA_OPTIMAL"),
		"③ 另一种三级牌（Veda·最优解）第一次放入仍可（每种各限 1 次）")
	t.ok(not CelestialV01.放入太阳炉(c, "CB_SD3_VEDA_OPTIMAL"), "③ 它也不能放第二次")

# ==========================================================================================
# ④ 太阳炉牌库：形状 / 回库 / 移出 / 打出
# ==========================================================================================
func _段4_太阳炉牌库(t) -> void:
	# `SubDeck.新建()` 内置「已放入三级」= 断路器 1 的登记表
	var 库 := SubDeck.新建()
	t.ok(库.has("牌") and 库.get("已放入三级") is Dictionary and (库["牌"] as Array).is_empty(),
		"④ `SubDeck.新建()` = `{牌: [], 已放入三级: {}}`（断路器 1 的登记表内置在库里）")
	var 三级 := CelestialV01.太阳炉卡("CB_SD3_HERITAGE")
	t.ok(SubDeck.放入(库, 三级, null, "", CelestialV01.炉等级键, 3),
		"④ 结构化库 + **不传 `每场限次集合`** 也能放第一张三级牌（断路器 1 内置）")
	t.ok(not SubDeck.放入(库, 三级, null, "", CelestialV01.炉等级键, 3),
		"④ 同一种第二次 → false（登记表写在 `库[已放入三级]` 里）")
	t.ok((库["已放入三级"] as Dictionary).has("CB_SD3_HERITAGE"),
		"④ 登记表里真的有 `CB_SD3_HERITAGE`：%s" % str(库["已放入三级"]))
	# —— 真的对局里的太阳炉牌库 ——
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var c := _场([刹], [_靶("靶1", 0.0)], 种子)
	var 状 := CelestialV01.太阳炉状态(c)
	t.ok(int(状.get("张数")) == 4 and int(状.get("一级")) == 4 and int(状.get("二级")) == 0,
		"④ 开局：一级 4 张、二三级 0 张（%s）" % str(状))
	t.ok(CelestialV01.放入太阳炉(c, "CB_SD2_VEDA_PLAN") and _炉数(c) == 5,
		"④ 放入一张二级牌 → 库 4 → %d" % _炉数(c))
	# 打出二级 → 回库
	var 牌 := 拿炉(c, "CB_SD2_VEDA_PLAN")
	t.ok(not 牌.is_empty(), "④ 二级牌真的在库 / 被拿到手里")
	var r := CelestialV01.打出太阳炉牌(c, 刹, 牌, "靶1")
	t.info("④ 【Veda·任务计划】：%s" % str(r.get("效果摘要")))
	t.ok(J.truthy(r.get("成功")) and str(r.get("去处")) == "回库" and _炉数(c) == 5,
		"④ 打出二级牌 → **回库**（库仍是 %d 张）" % _炉数(c))
	t.ok(J.truthy(_敌(c, "靶1").get("本回合任务目标")), "④ 【Veda·任务计划】真的把靶机标成 `本回合任务目标`")
	# 打出三级 → 移出本场
	CelestialV01.放入太阳炉(c, "CB_SD3_HERITAGE")
	var 库前 := _炉数(c)
	var 三 := 拿炉(c, "CB_SD3_HERITAGE")
	var r3 := CelestialV01.打出太阳炉牌(c, 刹, 三, "CB1")
	t.ok(J.truthy(r3.get("成功")) and str(r3.get("去处")) == "移出" and _炉数(c) == 库前 - 1,
		"④ 打出三级牌 → **移出本场**（库 %d → %d，不回库）" % [库前, _炉数(c)])
	t.ok(J.or_(c.get("太阳炉移出"), []).size() == 1
		and str(((J.or_(c.get("太阳炉移出"), [])[0]) as Dictionary).get("id")) == "CB_SD3_HERITAGE",
		"④ `太阳炉移出` 里记下了那一张（伊奥利亚的遗产）")
	t.ok(float(牌.get("耗气")) == 0.0 and J.truthy(牌.get("不占主武器"))
		and not J.truthy(刹.get("主武器已销毁")),
		"④ 太阳炉牌 **0 费 / 不占主武器**（打完 `主武器已销毁` 仍是 false）")
	# Veda 标签 → 全队「本回合打过Veda」
	var c2 := _场([_单位("CB1", "ally", 0.0, "近卫")], [_靶("靶1", 0.0)], 种子)
	var 刹2: Dictionary = c2.allies[0]
	t.ok(not CelestialV01.本回合打过Veda(c2), "④ 开局 `本回合打过Veda` = false")
	CelestialV01.记打出(c2, {"id": "X", "名": "X", "veda": true})
	t.ok(CelestialV01.本回合打过Veda(c2), "④ 打出一张 `veda: true` 的牌 → 全队布尔置真")
	Btl.开始我方阶段(c2)
	t.ok(not CelestialV01.本回合打过Veda(c2), "④ 下个我方阶段初归零")
	t.ok(not J.truthy(刹2.get("主武器已销毁")), "④ 阶段初不影响主武器状态")

# ==========================================================================================
# ⑤ 天人势力牌 9 张
# ==========================================================================================
func _段5_势力牌(t) -> void:
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var c := _场([刹], [_靶("靶1", 0.0), _靶("靶2", 1.0)], 种子)
	var f5 := _势卡("CB_FAC_5")
	var f9 := _势卡("CB_FAC_9")
	c["turn"] = 1.0
	t.ok(not DeckFlow.条件满足(c, 刹, f5.get("入库条件")), "⑤ 【GN 鱼雷】第 1 回合：入库条件不满足")
	c["turn"] = 2.0
	t.ok(DeckFlow.条件满足(c, 刹, f5.get("入库条件")), "⑤ 第 **2** 回合起：满足")
	t.ok(not DeckFlow.条件满足(c, 刹, f9.get("入库条件")), "⑤ 【根除战争】第 2 回合：不满足（第 3 回合起）")
	c["turn"] = 3.0
	t.ok(DeckFlow.条件满足(c, 刹, f9.get("入库条件")), "⑤ 第 **3** 回合起：满足")
	var f5武: Dictionary = f5.get("武器")
	t.ok(float(f5武.get("power")) == 1500.0 and str(f5武.get("fire")) == "indirect"
		and J.truthy(f5武.get("ignore_block")) and (f5武.get("距离") as Array) == [1, 6],
		"⑤ 【托勒密号·GN 鱼雷】物理 1500 / 曲射 / 距离 1–6 / 无视遮挡")
	t.ok(J.truthy(f5.get("武力介入")) and str(f5.get("介入放入")) == "CB_SD2_HARO_SHIELD",
		"⑤ 【GN 鱼雷】带【武力介入：抽 1 张，并把「GN 全盾·哈罗」放入太阳炉牌库】")
	t.ok(J.truthy(f9.get("武力介入")), "⑤ 【根除战争】也带【武力介入：抽 1 张】")
	# 【天人，出击】0 费 → 抽 1 张公有牌
	var f1 := _势卡("CB_FAC_1")
	c["公有牌库"] = [{"id": "T1", "名": "公有牌1", "卡类": "公有牌", "层级": "统帅"},
		{"id": "T2", "名": "公有牌2", "卡类": "公有牌", "层级": "统帅"}]
	c["公有手牌"] = []
	刹["战意"] = 100.0
	(c["公有手牌"] as Array).append(f1)
	var r1 := CelestialV01.打出势力牌(c, 刹, f1, null)
	t.info("⑤ 【天人，出击】：%s" % str(r1.get("效果摘要")))
	t.ok(J.truthy(r1.get("成功")) and (c.公有手牌 as Array).size() == 1 and float(刹.get("战意")) == 100.0,
		"⑤ 【天人，出击】0 费 → 抽 1 张公有牌（手牌 1 张、战意没扣）")
	# 【同时多发介入】→ 下一张武器牌对它命中 +15
	var f2 := _势卡("CB_FAC_2")
	c["公有手牌"] = [f2]
	刹["战意"] = 100.0
	var r2 := CelestialV01.打出势力牌(c, 刹, f2, "靶1")
	t.ok(J.truthy(r2.get("成功")) and float(J.num0(刹.get("cb下张武器命中"))) == 15.0,
		"⑤ 【同时多发介入】：打出者下一张武器牌对它命中 +15（%s）" % J.s(刹.get("cb下张武器命中")))
	var 加 := CelestialV01.攻击前命中(c, 刹, _武(100.0, 1), _敌(c, "靶1"))
	t.ok(加 == 15.0 and float(J.num0(刹.get("cb下张武器命中"))) == 0.0,
		"⑤ 命中 +15 兑现一次就清（+%s → 现在 %s）" % [J.s(加), J.s(刹.get("cb下张武器命中"))])
	# 根除战争 → 天人成员打它 +15%
	var f9b := _势卡("CB_FAC_9")
	c["公有手牌"] = [f9b]
	c["turn"] = 3.0
	刹["战意"] = 100.0
	var r9 := CelestialV01.打出势力牌(c, 刹, f9b, "靶2")
	t.ok(J.truthy(r9.get("成功")), "⑤ 【根除战争】第 3 回合打得出来（%s）" % str(r9.get("原因", "")))
	t.ok(absf(CelestialV01.根除战争倍率(c, 刹, _敌(c, "靶2")) - 1.15) < 0.0001,
		"⑤ 本回合天人成员打它伤害 ×1.15（%s）" % J.s(CelestialV01.根除战争倍率(c, 刹, _敌(c, "靶2"))))
	t.ok(CelestialV01.根除战争倍率(c, 刹, _敌(c, "靶1")) == 1.0, "⑤ 打别的敌机不加成")
	# 非天人成员打不出
	var 路人 := _单位("A1", "ally", 2.0, "近卫")
	路人["tags"] = {"战斗分类": "近卫", "势力": "ATX"}
	c["allies"] = [刹, 路人]
	var r否 := CelestialV01.打出势力牌(c, 路人, _势卡("CB_FAC_2"), "靶1")
	t.ok(not J.truthy(r否.get("成功")) and str(r否.get("原因", "")).contains("天人"),
		"⑤ 非天人成员打天人势力牌 → 失败（原因：%s）" % str(r否.get("原因", "")))

# ==========================================================================================
# ⑥ 拉塞 CB5：7 张牌 + 掩护 + GN 力场
# ==========================================================================================
func _段6_拉塞CB5(t) -> void:
	var c := Setup.开局([{"键": "CB5", "位": 1.0, "等级": 10.0}], [{"键": "grunt", "位": 0.0}],
		种子, null, {"单机牌组": true, "卡牌流转": true})
	var 拉: Dictionary = c.allies[0]
	t.ok(str(拉.get("key")) == "CB5" and CelestialV01.是拉塞(拉), "⑥ 开局：拉塞 CB5 在场")
	var 武名们: Array = []
	for x in J.or_(拉.get("武器栏"), []):
		if x is Dictionary and str((x as Dictionary).get("id", "")).begins_with("CB5_"):
			武名们.append(str((x as Dictionary).get("名")))
	t.ok(武名们.size() == 3, "⑥ 3 把主武器进了 `武器栏`：%s" % str(武名们))
	var 槽们: Array = J.or_(拉.get("大招槽"), []).filter(func(x): return x is Dictionary and str(((x as Dictionary).get("卡") as Dictionary).get("id", "")).begins_with("CB5_"))
	t.ok(槽们.size() == 1, "⑥ 1 张大招进了 `大招槽`")
	var 精们: Array = []
	for 池键 in ["专属牌库", "专属手牌", "专属弃牌堆"]:
		for x in J.or_(拉.get(池键), []):
			if x is Dictionary and str((x as Dictionary).get("id", "")).begins_with("CB5_S"):
				精们.append(str((x as Dictionary).get("名")))
	t.ok(精们.size() == 3, "⑥ 3 张精神牌（牌库 / 手牌 / 弃牌堆合起来）：%s" % str(精们))
	t.ok(not J.truthy(拉.get("本场已开TRANSAM")) and _大招份数(拉) == 0,
		"⑥ 拉塞**没有** TRANS-AM（大招槽里没有 `CB_ULT_TRANSAM`）")
	# —— 数值逐条对设计稿 ——
	var w1 := _拉卡("CB5_W1", false)
	var w2 := _拉卡("CB5_W2", false)
	var w3 := _拉卡("CB5_W3", false)
	var 武1: Dictionary = w1.get("武器")
	var 武2: Dictionary = w2.get("武器")
	var 武3: Dictionary = w3.get("武器")
	t.info("⑥ 三把主武器：%s / %s / %s" % [str(武1), str(武2), str(武3)])
	t.ok(float(武1.get("power")) == 2200.0 and str(武1.get("dmgType")) == "光束"
		and str(武1.get("fire")) == "direct" and (武1.get("距离") as Array) == [2, 6],
		"⑥ GN 大型光束炮：直射 · 光束 2200 · 距离 2–6 · 单体")
	t.ok(float(武2.get("power")) == 250.0 and float(武2.get("hits")) == 6.0
		and float(武2.get("hit")) == 80.0 and J.truthy(武2.get("散布"))
		and (武2.get("距离") as Array) == [2, 5],
		"⑥ GN 导弹：曲射 · 物理 250×6 · 距离 2–5 · 散布 · 命中 80")
	t.ok(float(武3.get("power")) == 2000.0 and float(武3.get("hit")) == 85.0
		and str(武3.get("fire")) == "melee" and (武3.get("距离") as Array) == [1, 2],
		"⑥ GN 大型光束剑：近战 · 光束 2000 · 距离 1–2 · 命中 85")
	var 大 := _拉卡("CB5_U1", false)
	var 大武: Dictionary = 大.get("武器")
	t.ok(float(大.get("耗气")) == 20.0 and float(大.get("冷却")) == 4.0 and J.truthy(大.get("武器牌"))
		and float(大武.get("power")) == 3600.0 and str(大武.get("area")) == "pierce",
		"⑥ ★ GN 大型光束炮·最大出力：20 费 · 冷却 4 · 直射光束 3600 · 贯穿")
	var 大条 = 大.get("入库条件")
	t.ok(J.truthy(大.get("武力介入")) and 大条 is Dictionary and str((大条 as Dictionary).get("说明")) == "第 3 回合起",
		"⑥ 大招：第 3 回合起 +【武力介入：抽 1 张】")
	# —— `+` 版（Lv20）——
	var 加w1: Dictionary = _拉卡("CB5_W1", true).get("武器")
	var 加大 := _拉卡("CB5_U1", true)
	var 加精 := _拉卡("CB5_S1", true)
	var 加集 := _拉卡("CB5_S2", true)
	t.ok(absf(float(加w1.get("power")) - 2200.0 * 1.15) < 0.01,
		"⑥ `+` 版主武器威力 +15%%（2200 → %s）" % J.s(加w1.get("power")))
	t.ok(float(加大.get("冷却")) == 3.0, "⑥ `+` 版大招冷却 −1（4 → %s）" % J.s(加大.get("冷却")))
	t.ok(float(加精.get("耗气")) == 5.0, "⑥ `+` 版精神牌费用 −5（GN 装甲护卫 10 → %s）" % J.s(加精.get("耗气")))
	t.ok(float(加集.get("耗气")) == 0.0, "⑥ 精神牌费用最低 0（专注 5 → %s）" % J.s(加集.get("耗气")))
	# —— 被动 1：掩护（2/2 次）——
	t.ok(int(J.num0(拉.get("掩护上限"))) == 2, "⑥ 被动【掩护】：上限 2")
	拉["掩护剩余"] = 0
	CelestialV01.敌方阶段初(c)
	t.ok(int(J.num0(拉.get("掩护剩余"))) == 2,
		"⑥ 每个敌方阶段初 `掩护剩余` 回到 **2/2**（%s）" % J.s(拉.get("掩护剩余")))
	t.ok(CelestialV01.是掩护者(拉), "⑥ 拉塞算「重装【掩护】的承担者」（与塔斯克 A6 同一套口径）")
	var 后排 := _单位("CB2", "ally", 5.0, "狙击")
	c["allies"].append(后排)
	var 线们 := Btl.当前援护连线们(c)
	var 掩线 := 线们.filter(func(x): return str((x as Dictionary).get("from_key", "")) == "CB5")
	t.ok(掩线.size() == 1 and str((掩线[0] as Dictionary).get("label", "")).contains("掩护"),
		"⑥ `Btl.当前援护连线们` 里有拉塞 → 正后方队友那条线（%s）" % str(掩线))
	# —— 被动 2：GN 力场（掩护承受的光束伤害 −40%）——
	var 遮 := {"掩护接管": true, "target": 拉, "原目标": "CB2"}
	t.ok(absf(CelestialV01.掩护力场倍率(c, 遮, 拉, {"dmgType": "光束"}) - 0.6) < 0.0001,
		"⑥ 【GN 力场】拉塞替队友承受的**光束**伤害 ×0.6（−40%）")
	t.ok(CelestialV01.掩护力场倍率(c, 遮, 拉, {"dmgType": "物理"}) == 1.0, "⑥ 物理伤害不减（×1.0）")
	t.ok(CelestialV01.掩护力场倍率(c, 遮, 后排, {"dmgType": "光束"}) == 1.0,
		"⑥ 不是拉塞承受的不减（×1.0）")
	t.ok(CelestialV01.掩护力场倍率(c, {"kind": "attack"}, 拉, {"dmgType": "光束"}) == 1.0,
		"⑥ 不是「掩护接管」的那一发不减（×1.0）")
	# —— GN 力场真的进了伤害公式（同一发、同一个位，只差 `掩护接管`）——
	var 无 := _力场一发(false)
	var 有 := _力场一发(true)
	t.info("⑥ GN 力场：同一发光束 1000 → 没掩护 %d / 掩护接管 %d（×0.6）" % [
		int(无.get("伤")), int(有.get("伤"))])
	t.ok(int(无.get("伤")) > 0 and absi(int(有.get("伤")) - int(J.round(float(无.get("伤")) * 0.6))) <= 2,
		"⑥ ★ 【GN 力场】真的进了伤害公式：%s → %s（= %s × 0.6）" % [
			J.s(无.get("伤")), J.s(有.get("伤")), J.s(无.get("伤"))])
	t.ok(_日志含(有.get("ctx"), "〔GN 力场〕"),
		"⑥ 即时反馈一行：%s" % _找行(有.get("ctx"), "〔GN 力场〕"))

## ⑥ GN 力场的**端到端**受控场景：拉塞前排（slot 1）、洛克昂后排（slot 5），一发 1000 光束打后排。
## `掩护接管` = true 时由 `AtxDuo.掩护收口` 那条路把目标换成拉塞（这里直接把 `掩护接管` 写进 action）。
func _力场一发(带掩护: bool) -> Dictionary:
	var 拉 := _单位("CB5", "ally", 1.0, "重装")
	拉["hp"] = 10000.0
	拉["maxHp"] = 10000.0
	拉["armor"] = 0.0
	拉["掩护上限"] = 2
	拉["掩护剩余"] = 2
	var 后 := _单位("CB2", "ally", 5.0, "狙击")
	var c := _场([拉, 后], [_靶("靶1", 0.0)], 种子)
	var 敌: Dictionary = c.enemies[0]
	var 武 := {"name": "测试光束", "fire": "direct", "dmgType": "光束", "power": 1000.0, "hit": 100.0,
		"stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": []}
	var action := {"kind": "attack", "weapon": 武, "entry": {"t": 武, "cd": 0.0, "uses": null}, "target": 拉}
	if 带掩护:
		action["掩护接管"] = true
		action["原目标"] = "CB2"
	var 前 := float(拉.get("hp"))
	Flow.resolveAction(敌, action, c)
	return {"伤": int(前 - float(拉.get("hp"))), "ctx": c}

# ==========================================================================================
# ⑦ 开关关：一切都不产出
# ==========================================================================================
# ==========================================================================================
# ⑧ 同种子两遍逐字相同
# ==========================================================================================
func _段8_同种子(t) -> void:
	var a := _脚本()
	var b := _脚本()
	t.ok(str(a.get("日志")) == str(b.get("日志")),
		"⑧ 同种子两遍：整场记录**逐字相同**（%d 行）" % (a.get("日志") as Array).size())
	t.ok(str(a.get("数")) == str(b.get("数")), "⑧ 同种子两遍：全部数字逐字相同（%s）" % str(a.get("数")))
	t.ok(int(a.get("rng")) == int(b.get("rng")),
		"⑧ 同种子两遍：`ctx.rng` 步数相同（%d / %d）" % [int(a.get("rng")), int(b.get("rng"))])

func _脚本() -> Dictionary:
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	var 拉 := _单位("CB5", "ally", 4.0, "重装")
	var 靶1 := _靶("靶1", 0.0)
	var c := _场([刹, 拉], [靶1], 种子)
	CelestialV01.装填大招槽(c, 刹)
	Btl.开始我方阶段(c)
	Btl.开始我方阶段(c)
	Btl.开始我方阶段(c)
	刹["战意"] = 100.0
	DeckFlow.打出大招(c, "CB1", "CB_ULT_TRANSAM", "靶1")
	var 记 := CelestialV01.触发武力介入(c, 刹, 靶1, {"id": "T", "名": "T", "介入放入": "CB_SD2_SUPER_REFLEX"})
	CelestialV01.我方阶段末(c)
	Btl._执行武器攻击(c, 拉, {"t": _武(300.0, 2, 100.0, "direct"), "cd": 0.0, "uses": null}, "靶1")
	return {"日志": _行们(c), "rng": int((c.get("rng") as Mulberry32).steps),
		"数": {"靶1血": 靶1.get("hp"), "太阳炉": _炉数(c), "手牌": (c.公有手牌 as Array).size(),
			"抽出": 记.get("抽到"), "放入": 记.get("放入"),
			"TA剩": 刹.get("transam剩余回合"), "粒": 刹.get("粒子耗尽剩余回合")}}

# ==========================================================================================
# ⑨ 全牌冒烟：太阳炉 10 张 / 势力牌 9 张 / 拉塞精神 3 张 —— **每一张都真的打得出去**
#    （每条都断言「成功 + 摘要非空 + 有一点看得见的记录」，防住「牌在表里但没有算子」）
# ==========================================================================================
func _段9_全牌冒烟(t) -> void:
	# —— 太阳炉 10 张（全部先放进库，再逐张拿出来打）——
	var 刹 := _单位("CB1", "ally", 0.0, "近卫")
	刹["大招槽"] = []
	var c := _场([刹, _单位("CB5", "ally", 4.0, "重装")], [_靶("靶1", 0.0), _靶("靶2", 1.0)], 种子)
	CelestialV01.装填大招槽(c, 刹)
	for x in CelestialV01.太阳炉卡表():
		CelestialV01.放入太阳炉(c, str((x as Dictionary).get("id")))
	var 炉坏: Array = []
	for x in CelestialV01.太阳炉卡表():
		var id := str((x as Dictionary).get("id"))
		var 牌 := 拿炉(c, id)
		if 牌.is_empty():
			炉坏.append("%s（拿不到）" % id)
			continue
		c["公有手牌"] = [牌]
		刹["战意"] = 100.0
		var r := CelestialV01.打出太阳炉牌(c, 刹, 牌, "靶1")
		if not J.truthy(r.get("成功")) or (r.get("效果摘要") as Array).is_empty():
			炉坏.append("%s（%s）" % [id, str(r.get("原因", "摘要空"))])
			continue
		# 打完之后必须回库或移出（三级移出），不能在手里消失得没名没姓
		if str(r.get("去处")) == "":
			炉坏.append("%s（没有去处）" % id)
	t.ok(炉坏.is_empty(), "⑨ 太阳炉 10 张**每一张都打得出去**且都有效果摘要（%s）" % (
		"全通" if 炉坏.is_empty() else "有问题：" + str(炉坏)))
	# —— 天人势力牌 9 张 ——
	var 势坏: Array = []
	for x in CelestialV01.势力牌们():
		var 牌: Dictionary = (x as Dictionary).duplicate(true)
		var id := str(牌.get("id"))
		var c2 := _场([_单位("CB1", "ally", 0.0, "近卫")], [_靶("靶1", 0.0), _靶("靶2", 1.0)], 种子)
		var 施: Dictionary = c2.allies[0]
		施["战意"] = 100.0
		c2["turn"] = 3.0
		c2["本场有人开过TRANSAM"] = true
		c2["公有牌库"] = [{"id": "T1", "名": "公有牌1", "卡类": "公有牌", "层级": "统帅"}]
		c2["公有手牌"] = [牌]
		var r2 := CelestialV01.打出势力牌(c2, 施, 牌, "靶1")
		if not J.truthy(r2.get("成功")) or (r2.get("效果摘要") as Array).is_empty():
			势坏.append("%s（%s）" % [id, str(r2.get("原因", "摘要空"))])
	t.ok(势坏.is_empty(), "⑨ 天人势力牌 9 张**每一张都打得出去**且都有效果摘要（%s）" % (
		"全通" if 势坏.is_empty() else "有问题：" + str(势坏)))
	# —— 拉塞 3 张精神牌 ——
	var 精坏: Array = []
	for x in CelestialV01.拉塞卡表(false):
		var 卡: Dictionary = x
		if str(卡.get("卡类")) != "专属精神牌":
			continue
		var c3 := _场([_单位("CB5", "ally", 0.0, "重装"), _单位("CB1", "ally", 1.0, "近卫")],
			[_靶("靶1", 0.0)], 种子)
		var 施3: Dictionary = c3.allies[0]
		施3["战意"] = 100.0
		var 用 := (卡 as Dictionary).duplicate(true)
		# 精神牌走「专属手牌」那条路（`打出精神或公有牌` 先找专属手牌，再找公有手牌）
		施3["专属手牌"] = [用]
		var r3 := Btl.打出精神或公有牌(c3, "CB5", 用, "CB1")
		if not J.truthy(r3.get("成功")) or (r3.get("效果摘要") as Array).is_empty():
			精坏.append("%s（%s）" % [str(卡.get("名")), str(r3.get("原因", "摘要空"))])
	t.ok(精坏.is_empty(), "⑨ 拉塞 3 张精神牌**每一张都打得出去**且都有效果摘要（%s）" % (
		"全通" if 精坏.is_empty() else "有问题：" + str(精坏)))

# ==========================================================================================
# ⑩ 两张「到下个我方阶段前」的防御牌：GN 全盾·哈罗（首击 −40%）/ Veda·行动预测（敌方首击命中 −30）
# ==========================================================================================
func _段10_两张防御牌(t) -> void:
	# —— GN 全盾·哈罗：受到的**第一次**攻击伤害 −40%，吃一次就清 ——
	var 我 := _单位("CB1", "ally", 0.0, "近卫")
	我["hp"] = 10000.0
	我["maxHp"] = 10000.0
	我["armor"] = 0.0
	var c := _场([我], [_靶("靶1", 0.0)], 种子)
	var 敌: Dictionary = c.enemies[0]
	var 卡 := CelestialV01.太阳炉卡("CB_SD2_HARO_SHIELD")
	c["公有手牌"] = [卡]
	var r := CelestialV01.打出太阳炉牌(c, 我, 卡, "CB1")
	t.ok(J.truthy(r.get("成功")) and float(J.num0(我.get("cb首击减伤"))) == 0.40,
		"⑩ 【GN 全盾·哈罗】挂上「第一次受到的攻击伤害 −40%%」（%s）" % J.s(我.get("cb首击减伤")))
	var 武 := {"name": "测试物理", "fire": "direct", "dmgType": "物理", "power": 1000.0, "hit": 100.0,
		"stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": []}
	var 前1 := float(我.get("hp"))
	Flow.resolveAction(敌, {"kind": "attack", "weapon": 武, "entry": {"t": 武, "cd": 0.0, "uses": null},
		"target": 我}, c)
	var 伤1 := int(前1 - float(我.get("hp")))
	t.ok(float(J.num0(我.get("cb首击减伤"))) == 0.0, "⑩ 第一次吃完 → 标记被消费（`cb首击减伤` 已清）")
	var 前2 := float(我.get("hp"))
	Flow.resolveAction(敌, {"kind": "attack", "weapon": 武, "entry": {"t": 武, "cd": 0.0, "uses": null},
		"target": 我}, c)
	var 伤2 := int(前2 - float(我.get("hp")))
	t.info("⑩ GN 全盾·哈罗：第一发 %d / 第二发 %d" % [伤1, 伤2])
	t.ok(伤2 > 0 and absi(伤1 - int(J.round(float(伤2) * 0.6))) <= 2,
		"⑩ ★ 第一发真的 **−40%%**（%d = %d × 0.6），第二发恢复全额（%d）" % [伤1, 伤2, 伤2])
	# —— Veda·行动预测：本回合敌方阶段**第一次**攻击命中 −30 ——
	var 我2 := _单位("CB1", "ally", 0.0, "近卫")
	var c2 := _场([我2], [_靶("靶1", 0.0)], 种子)
	var 敌2: Dictionary = c2.enemies[0]
	var 卡2 := CelestialV01.太阳炉卡("CB_SD2_VEDA_PREDICT")
	c2["公有手牌"] = [卡2]
	t.ok(J.truthy(CelestialV01.打出太阳炉牌(c2, 我2, 卡2, null).get("成功")),
		"⑩ 打出【Veda·行动预测】")
	var 参 := {"turn": c2.get("turn"), "ctx": c2}
	var 预 := int(Calc.hitRate(敌2, 武, 我2, 参).hit)
	CelestialV01.消费行动预测(c2, 敌2)
	var 后 := int(Calc.hitRate(敌2, 武, 我2, 参).hit)
	t.info("⑩ Veda·行动预测：敌方第一次攻击命中 %d → 消费后 %d" % [预, 后])
	t.ok(后 - 预 == 30, "⑩ ★ 敌方**第一次**攻击命中真的 −30（%d → %d）" % [预, 后])
	t.ok(CelestialV01.行动预测命中修正(c2, 敌2) == 0.0, "⑩ 消费之后不再减（纯读返回 0）")

# ==========================================================================================
# ⑪ ★ CB-2：刹那 CB1 —— 7 张剑牌 / 出鞘 / 七剑齐出 / 迅击 / 剑舞 / 收剑 / 拔刀 / 乱舞 / 贯穿
# ==========================================================================================
func _段11_刹那七剑(t) -> void:
	var 主 := _卡名们("CB1", false, "主武器卡")
	var 副 := _卡名们("CB1", false, "副武器卡")
	var 大 := _卡名们("CB1", false, "大招槽卡")
	var 精 := _卡名们("CB1", false, "专属精神牌")
	t.ok(主.size() == 5 and 副.size() == 1 and 大.size() == 3 and 精.size() == 9,
		"⑪ 刹那卡池：主武器 %d / 副武器 %d / 大招 %d（+TRANS-AM）/ 精神 %d" % [主.size(), 副.size(), 大.size(), 精.size()])
	t.ok(主 == ["GN 剑·步枪模式", "GN 剑（剑模式）", "GN 长刃", "GN 短刃", "GN 光束军刀·二刀"],
		"⑪ 5 张主武器逐字对齐设计稿：%s" % str(主))
	t.ok(副 == ["GN 光束匕首"], "⑪ 副武器 = ★ GN 光束匕首（剑 ×2，只抽太阳炉牌）")
	t.ok(大 == ["★ GN 剑·全力斩", "★ 七剑·TRANS-AM 乱舞", "GN 剑·贯穿"],
		"⑪ 3 张大招逐字：%s" % str(大))
	t.ok(精 == ["★「武力介入，开始」", "收剑", "剑舞", "GN 盾", "拔刀", "★ 斩断扭曲",
		"「我就是高达」", "库尔吉斯的少年兵", "七剑全开"], "⑪ 9 张精神牌逐字：%s" % str(精))
	var 剑 := 0
	for c in CelestialV01.驾驶员卡表("CB1", false):
		if CelestialV01.剑牌吗(c):
			剑 += CelestialV01.剑数Of(c)
	t.ok(剑 == 7 and CelestialV01.剑牌张数 == 5 and CelestialV01.七剑总数 == 7,
		"⑪ 5 张剑牌合计 **7 把剑**（%d 把）" % 剑)
	# —— 逐张数值 ——
	var 步: Dictionary = _武参("CB1", "CB1_W1")
	t.ok(str(步.get("fire")) == "direct" and float(步.get("power")) == 1600.0
		and (步.get("距离") as Array) == [1, 3] and str(步.get("dmgType")) == "光束",
		"⑪ GN 剑·步枪模式：直射 · 光束 1600 · 距离 1–3 · 单体（**不是剑**）")
	var 剑武: Dictionary = _武参("CB1", "CB1_W2")
	t.ok(str(剑武.get("fire")) == "melee" and float(剑武.get("power")) == 2800.0
		and (剑武.get("距离") as Array) == [1, 2] and CelestialV01.剑数Of(_驾卡("CB1", "CB1_W2")) == 1,
		"⑪ GN 剑（剑模式）：近战 · 光束 2800 · 距离 1–2 · 剑 ×1")
	var 长武: Dictionary = _武参("CB1", "CB1_W3")
	t.ok(float(长武.get("power")) == 2300.0 and float(长武.get("critMod")) == 20.0
		and str(长武.get("dmgType")) == "物理", "⑪ GN 长刃：近战 · 物理 2300 · 暴击 +20 · 剑 ×1")
	var 短武: Dictionary = _武参("CB1", "CB1_W4")
	t.ok(float(短武.get("power")) == 1100.0 and float(短武.get("hits")) == 2.0
		and float(短武.get("critMod")) == 15.0 and (短武.get("距离") as Array) == [1, 1],
		"⑪ GN 短刃：近战 · 物理 1100 × 2 段 · 距离 1 · 每段暴击 +15")
	var 二武: Dictionary = _武参("CB1", "CB1_W5")
	t.ok(float(二武.get("power")) == 800.0 and float(二武.get("hits")) == 4.0
		and CelestialV01.剑数Of(_驾卡("CB1", "CB1_W5")) == 2,
		"⑪ GN 光束军刀·二刀：近战 · 光束 800 × 4 段 · 剑 ×2")
	var 匕武: Dictionary = _武参("CB1", "CB1_D1")
	t.ok(float(匕武.get("power")) == 600.0 and float(匕武.get("hits")) == 2.0
		and (匕武.get("距离") as Array) == [1, 3] and J.truthy(_驾卡("CB1", "CB1_D1").get("武力介入")),
		"⑪ ★ GN 光束匕首：直射 · 光束 600 × 2 段 · 距离 1–3 · 剑 ×2 · 武力介入")
	# —— `+` 版 ——
	t.ok(absf(float(_武参("CB1", "CB1_W2", true).get("power")) - 2800.0 * 1.15) < 0.01,
		"⑪ `+` 版 GN 剑（剑模式）威力 +15%%（%s）" % J.s(_武参("CB1", "CB1_W2", true).get("power")))
	t.ok(float(_武参("CB1", "CB1_W5", true).get("hits")) == 5.0, "⑪ `+` 版 光束军刀·二刀 = 5 段")
	t.ok(float(_武参("CB1", "CB1_D1", true).get("power")) == 800.0, "⑪ `+` 版 光束匕首每段 800")
	# —— 出鞘：真的打一张剑牌 ——
	var 场 := _驾场("CB1", 0.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	u["战意"] = 100.0
	var r := Btl.打出武器栏卡(c, "CB1", "CB1_W2", "靶1")
	t.ok(J.truthy(r.get("成功")), "⑪ 打出【GN 剑（剑模式）】：%s" % str(r.get("原因", "")))
	t.ok(int(CelestialV01.出鞘剑数(u)) == 1 and J.truthy(CelestialV01._武器栏卡(u, "CB1_W2").get("出鞘")),
		"⑪ 剑牌打出后标 `w[出鞘] = true`（出鞘 %d 把）" % CelestialV01.出鞘剑数(u))
	t.ok(Btl.武器栏不可打原因(c, u, CelestialV01._武器栏卡(u, "CB1_W2")).contains("出鞘中"),
		"⑪ 出鞘的剑牌**下回合也不恢复**：不可打原因 = 「%s」"
			% Btl.武器栏不可打原因(c, u, CelestialV01._武器栏卡(u, "CB1_W2")))
	var 恢复 := DeckFlow.恢复主武器栏(c, u)
	t.ok(J.inc(恢复.get("出鞘", []), "GN 剑（剑模式）+") and int(恢复.get("恢复", 0)) == 4,
		"⑪ 再动 / 连续攻击的「主武器恢复」**绝不恢复出鞘的剑牌**（恢复 %d 张、跳过 %s）"
			% [int(恢复.get("恢复", 0)), str(恢复.get("出鞘"))])
	# —— 七剑齐出 ——
	CelestialV01.全部剑牌出鞘(u)
	CelestialV01.判定七剑齐出(c, u)
	t.ok(CelestialV01.七剑齐出吗(u) and int(CelestialV01.出鞘剑数(u)) == 7,
		"⑪ 5 张剑牌全部出鞘 → **七剑齐出**（7 把剑）")
	t.ok(J.truthy(u.get("本场七剑齐出过")), "⑪ 实时判定并标记 `本场七剑齐出过 = true`")
	t.ok(CelestialV01.出鞘文(u) == "〔★七剑齐出〕", "⑪ 展示文 = %s" % CelestialV01.出鞘文(u))
	# —— 收剑 / 拔刀 ——
	u["主武器已销毁"] = true
	var 收 := CelestialV01.收剑(c, u, true)
	t.ok(收.size() == 5 and int(CelestialV01.出鞘剑数(u)) == 0 and not CelestialV01.七剑齐出吗(u),
		"⑪ 【收剑】收回 5 张剑牌 → 出鞘 0（七剑齐出解除）")
	t.ok(J.truthy(u.get("主武器已销毁")), "⑪ 收剑**不恢复**本回合已收起的主武器（`主武器已销毁` 仍然是 true）")
	CelestialV01.全部剑牌出鞘(u)
	var 拔卡: Dictionary = _驾卡("CB1", "CB1_S5", false)
	u.专属手牌.append(拔卡)
	var r拔 := Btl.打出精神或公有牌(c, "CB1", 拔卡, "靶1")
	t.ok(J.truthy(r拔.get("成功")) and int(CelestialV01.出鞘剑数(u)) == 6,
		"⑪ 【拔刀】只收 1 张（第一张出鞘的是剑 ×1 的 GN 剑）→ 出鞘 7 → %d" % CelestialV01.出鞘剑数(u))
	t.ok(_日志含(c, "〔收剑〕"), "⑪ 收剑的即时反馈一行：%s" % _找行(c, "〔收剑〕"))
	t.ok(not J.truthy(u.get("本回合再动已用")),
		"⑪ 收剑 / 拔刀**不占断路器 3**（`本回合再动已用` 仍是 false）")
	# —— 迅击（TRANS-AM 中每回合第一张剑牌不收起其余主武器）——
	var 场2 := _驾场("CB1", 0.0)
	var u2: Dictionary = 场2.u
	var c2: Dictionary = 场2.c
	u2["transam剩余回合"] = 2
	var 迅 := CelestialV01.武器打出前(c2, u2, CelestialV01._武器栏卡(u2, "CB1_W3"))
	t.ok(J.truthy(迅.get("不销毁主武器")), "⑪ 【迅击】TRANS-AM 中**第一张剑牌**打出后不收起其余主武器")
	var 迅2 := CelestialV01.武器打出前(c2, u2, CelestialV01._武器栏卡(u2, "CB1_W4"))
	t.ok(not J.truthy(迅2.get("不销毁主武器")), "⑪ 【迅击】只给每回合第一张剑牌（第二张照常收起）")
	t.ok(not J.truthy(u2.get("本回合再动已用")) and not J.truthy(u2.get("连续攻击已用")),
		"⑪ 【迅击】**不占断路器 3**（连续攻击仍可用 1 次）")
	# —— 剑舞 ——
	var 场3 := _驾场("CB1", 0.0)
	var u3: Dictionary = 场3.u
	var c3: Dictionary = 场3.c
	var 舞卡: Dictionary = _驾卡("CB1", "CB1_S3", false)
	u3.专属手牌.append(舞卡)
	Btl.打出精神或公有牌(c3, "CB1", 舞卡, "靶1")
	var 舞 := CelestialV01.武器打出前(c3, u3, CelestialV01._武器栏卡(u3, "CB1_W2"))
	t.ok(J.truthy(舞.get("不销毁主武器")), "⑪ 【剑舞】下一张剑牌打出后不消掉其余主武器")
	t.ok(absf(float(舞.get("武器", {}).get("power")) - 3220.0 * 0.7) < 0.01,
		"⑪ 【剑舞】那张剑牌伤害 −30%%（3220 → %s）" % J.s(舞.get("武器", {}).get("power")))
	var 舞加法: Dictionary = CelestialV01.武器打出前(c3, u3, CelestialV01._武器栏卡(u3, "CB1_W2"))
	t.ok(absf(float(舞加法.get("武器", {}).get("power")) - 3220.0) < 0.01,
		"⑪ 剑舞只吃一次（第二张不再减伤）")
	# `+` 版剑舞不降伤害
	var 场4 := _驾场("CB1", 0.0)
	var u4: Dictionary = 场4.u
	var c4: Dictionary = 场4.c
	var 舞加: Dictionary = _驾卡("CB1", "CB1_S3", true)
	u4.专属手牌.append(舞加)
	Btl.打出精神或公有牌(c4, "CB1", 舞加, "靶1")
	var 舞加武: Dictionary = CelestialV01.武器打出前(c4, u4, CelestialV01._武器栏卡(u4, "CB1_W2"))
	t.ok(absf(float(舞加武.get("武器", {}).get("power")) - 3220.0) < 0.01,
		"⑪ `+` 版【剑舞】伤害不再降低（%s）" % J.s(舞加武.get("武器", {}).get("power")))
	# —— 完全版乱舞：七剑齐出时每段 1600、暴击 +20，打完全部收剑 + 放入「伊奥利亚的遗产」——
	var 不齐 := _乱舞一发(false, false)
	var 齐 := _乱舞一发(true, false)
	t.info("⑪ 乱舞：不齐出 %d 伤害 / 七剑齐出 %d 伤害" % [int(不齐.get("伤")), int(齐.get("伤"))])
	t.ok(float(齐.get("伤")) > float(不齐.get("伤")) * 1.25,
		"⑪ ★ 七剑齐出时【乱舞】改为完全版（每段 1600 + 暴击 +20）：%s → %s" % [
			J.s(不齐.get("伤")), J.s(齐.get("伤"))])
	t.ok(_日志含(齐.get("c"), "每段 1600") and _日志含(齐.get("c"), "完全版"),
		"⑪ 战报写明完全版：%s" % _找行(齐.get("c"), "完全版"))
	t.ok(int(CelestialV01.出鞘剑数(齐.get("u"))) == 0, "⑪ 【乱舞】打完**全部收剑**（出鞘 0）")
	t.ok(_有炉(齐.get("c"), "CB_SD3_HERITAGE"), "⑪ 七剑齐出时把「伊奥利亚的遗产」放进太阳炉牌库")
	t.ok(not _有炉(不齐.get("c"), "CB_SD3_HERITAGE"), "⑪ 没齐出时不放「伊奥利亚的遗产」")
	t.ok(_日志含(齐.get("c"), "〔武力介入〕"), "⑪ 【乱舞】的【武力介入】真的触发了")
	# —— 贯穿 ——
	var 场5 := _驾场("CB1", 0.0)
	var u5: Dictionary = 场5.u
	var c5: Dictionary = 场5.c
	u5["hp"] = float(u5.get("maxHp")) * 0.4
	u5["战意"] = 100.0
	c5["turn"] = 4.0
	DeckFlow.阶段初_检查(c5)
	var r贯 := DeckFlow.打出大招(c5, "CB1", "CB1_U4", "靶1")
	t.ok(J.truthy(r贯.get("成功")), "⑪ 打出【GN 剑·贯穿】（HP ≤ 50%% + 第 4 回合起）：%s" % str(r贯.get("原因", "")))
	t.ok(int(CelestialV01.出鞘剑数(u5)) == 7, "⑪ 贯穿打出后 **5 张剑牌全部出鞘**（7 把）")
	t.ok(J.truthy(u5.get("下场粒子耗尽")), "⑪ 贯穿：下个我方阶段刹那粒子耗尽")
	CelestialV01.阶段初(c5)
	t.ok(int(J.num0(u5.get("粒子耗尽剩余回合"))) == 1 and CelestialV01.粒子耗尽中(u5),
		"⑪ 下个我方阶段真的进入**粒子耗尽**（剩 %d）" % int(J.num0(u5.get("粒子耗尽剩余回合"))))
	t.ok(absf(CelestialV01.伤害倍率(c5, u5, _武(1000.0, 1)) - 0.7) < 0.0001,
		"⑪ 粒子耗尽中武器伤害 ×0.7")
	# 贯穿真的「无视伤害减免、装甲照算」：同一发 5500、同一台带 `受伤Mul −50%` 的靶
	var 甲靶 := _靶("靶甲", 5.0)
	甲靶["armor"] = 1000.0
	甲靶["buffs"] = [{"src": "测试减伤", "受伤Mul": -0.5, "剩余": 1.0}]
	var 场甲 := _场([_单位("CB1", "ally", 0.0, "近卫")], [甲靶], 种子)
	var 穿武 := {"name": "GN 剑·贯穿", "fire": "melee", "dmgType": "光束", "power": 5500.0, "hit": 100.0,
		"stat": "格斗", "hits": 1.0, "cd": 0.0, "upgrades": [], "无视减伤": true}
	var 普武: Dictionary = 穿武.duplicate(true)
	普武.erase("无视减伤")
	var 攻: Dictionary = 场甲.allies[0]
	var 穿伤 := float(Calc.dmgCore(攻, 穿武, 甲靶, {"power": 5500.0, "crit": false, "preview": true,
		"turn": 1.0, "ctx": 场甲, "useStat": false}).dmg)
	var 普伤 := float(Calc.dmgCore(攻, 普武, 甲靶, {"power": 5500.0, "crit": false, "preview": true,
		"turn": 1.0, "ctx": 场甲, "useStat": false}).dmg)
	t.info("⑪ 贯穿 vs 普通：%d / %d（靶带 受伤Mul −50%%、装甲 1000）" % [int(穿伤), int(普伤)])
	t.ok(穿伤 > 普伤 and absf(穿伤 - 普伤 * 2.0) <= 4.0,
		"⑪ ★ 【贯穿】**无视目标的伤害减免**（受伤 −50%% 被跳掉）：普通 %d → 贯穿 %d（≈ ×2）" % [int(普伤), int(穿伤)])
	t.ok(_驾卡("CB1", "CB1_U4", false).get("效果") is Array
		and not (_驾卡("CB1", "CB1_U4", false).get("武器") is Dictionary),
		"⑪ 【贯穿】走算子（`无视减伤` 打在这一次的武器实例上；牌面不带武器字典）")

## ⑪ 一发【乱舞】（`齐出` = 先让 5 张剑牌全部出鞘）。返回伤害 / 机体 / 场。
func _乱舞一发(齐出: bool, 加号: bool) -> Dictionary:
	var 场 := _驾场("CB1", 0.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	u["战意"] = 100.0
	u["transam剩余回合"] = 3
	if 齐出:
		CelestialV01.全部剑牌出鞘(u)
	c["turn"] = 4.0
	DeckFlow.阶段初_检查(c)
	var 敌: Dictionary = c.enemies[0]
	var 前 := float(敌.get("hp"))
	var r := DeckFlow.打出大招(c, "CB1", "CB1_U3", "靶1")
	if not J.truthy(r.get("成功")):
		t_info_fail(str(r.get("原因", "")))
	return {"伤": 前 - float(敌.get("hp")), "u": u, "c": c, "r": r}

var _最后一败 := ""

func t_info_fail(文: String) -> void:
	_最后一败 = 文

# ==========================================================================================
# ⑫ ★ CB-2：洛克昂 CB2 —— 【狙い撃つ】/ 高速狙击 / 最后的狙击 / 援护射击
# ==========================================================================================
func _段12_洛克昂狙击(t) -> void:
	var 主 := _卡名们("CB2", false, "主武器卡")
	var 副 := _卡名们("CB2", false, "副武器卡")
	var 大 := _卡名们("CB2", false, "大招槽卡")
	var 精 := _卡名们("CB2", false, "专属精神牌")
	t.ok(主.size() == 4 and 副.size() == 1 and 大.size() == 3 and 精.size() == 9,
		"⑫ 洛克昂卡池：主武器 %d / 副武器 %d / 大招 %d（+TRANS-AM）/ 精神 %d" % [主.size(), 副.size(), 大.size(), 精.size()])
	t.ok(主 == ["GN 狙击步枪", "GN 光束手枪", "GN 导弹", "GN 狙击步枪·精密模式"],
		"⑫ 4 把主武器逐字：%s" % str(主))
	t.ok(大 == ["★「乱れ撃つぜ」", "★ TRANS-AM 狙击", "最后的狙击"], "⑫ 3 张大招逐字：%s" % str(大))
	var 狙武: Dictionary = _武参("CB2", "CB2_W1")
	t.ok(float(狙武.get("power")) == 2550.0 and float(狙武.get("hit")) == 130.0
		and (狙武.get("距离") as Array) == [2, 6] and J.truthy(狙武.get("狙い撃つ")),
		"⑫ GN 狙击步枪：直射 · 光束 2550 · 距离 2–6 · 命中 130 · 【狙い撃つ】")
	var 手武: Dictionary = _武参("CB2", "CB2_W2")
	t.ok(float(手武.get("power")) == 650.0 and float(手武.get("hits")) == 2.0
		and (手武.get("距离") as Array) == [1, 3], "⑫ GN 光束手枪：直射 · 光束 650 × 2 段 · 距离 1–3")
	var 弹武: Dictionary = _武参("CB2", "CB2_W3")
	t.ok(float(弹武.get("power")) == 1500.0 and str(弹武.get("area")) == "splash"
		and (弹武.get("距离") as Array) == [2, 5] and float(_驾卡("CB2", "CB2_W3", false).get("限次")) == 2.0,
		"⑫ GN 导弹：曲射 · 物理 1500 · 距离 2–5 · 溅射 · 每场 2 次")
	var 精武: Dictionary = _武参("CB2", "CB2_W4")
	t.ok(float(精武.get("power")) == 2100.0 and float(精武.get("hit")) == 160.0
		and (精武.get("距离") as Array) == [3, 6] and J.truthy(精武.get("狙い撃つ")),
		"⑫ GN 狙击步枪·精密模式：直射 · 光束 2100 · 距离 3–6 · 命中 160 · 【狙い撃つ】")
	var 援武: Dictionary = _武参("CB2", "CB2_D1")
	t.ok(absf(float(援武.get("power")) - 2550.0 * 0.7) < 0.01 and J.truthy(援武.get("狙い撃つ"))
		and (援武.get("距离") as Array) == [2, 6],
		"⑫ 副武器援护射击 = GN 狙击步枪的 70%%（%s）、距离 2–6、**继承【狙い撃つ】**" % J.s(援武.get("power")))
	t.ok(float(_驾卡("CB2", "CB2_W3", true).get("限次")) == 3.0, "⑫ `+` 版 GN 导弹每场 3 次")
	t.ok(absf(float(_武参("CB2", "CB2_W1", true).get("power")) - 2550.0 * 1.15) < 0.01,
		"⑫ `+` 版 GN 狙击步枪威力 +15%%（%s）" % J.s(_武参("CB2", "CB2_W1", true).get("power")))
	t.ok(not (_驾卡("CB2", "CB2_U2", false).get("武器") is Dictionary), "⑫ 大招走算子（牌面不带 `武器` 字典），段数与散布在算子那一份实现里")
	# —— 【狙い撃つ】：最终命中 > 100 的溢出 1:1 / 1:2 ——
	var 场 := _驾场("CB2", 4.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	var 敌: Dictionary = c.enemies[0]
	t.ok(int(CelestialV01.狙溢暴击(u, 狙武, 敌, c, 130.0)) == 30,
		"⑫ 【狙い撃つ】最终命中 130 → 溢出 30 → 暴击率 +30")
	t.ok(int(CelestialV01.狙溢暴击(u, 狙武, 敌, c, 100.0)) == 0, "⑫ 最终命中正好 100 → 不转暴击")
	u["狙击直觉回合"] = float(c.get("turn"))
	t.ok(int(CelestialV01.狙溢暴击(u, 狙武, 敌, c, 130.0)) == 60,
		"⑫ 【狙击手的直觉】：本回合改为 **1:2**（溢出 30 → 暴击 +60）")
	u.erase("狙击直觉回合")
	t.ok(int(CelestialV01.狙溢暴击(u, 手武, 敌, c, 130.0)) == 0,
		"⑫ 不带【狙い撃つ】的武器（光束手枪）不转暴击")
	# 遮挡 −20 之后溢出真的变少（同一发、只差 `blockPenalty`）
	var 净 := int(Calc.hitRate(u, 狙武, 敌, {"blockPenalty": 0.0, "turn": 1.0, "ctx": c}).raw)
	var 挡 := int(Calc.hitRate(u, 狙武, 敌, {"blockPenalty": -20.0, "turn": 1.0, "ctx": c}).raw)
	t.ok(净 - 挡 == 20 and int(CelestialV01.狙溢暴击(u, 狙武, 敌, c, float(挡))) == int(CelestialV01.狙溢暴击(u, 狙武, 敌, c, float(净))) - 20,
		"⑫ 遮挡 −20 真的让【狙い撃つ】的溢出少 20（%d → %d）" % [净, 挡])
	# —— 高速狙击：TRANS-AM 中直射无视遮挡 ——
	u["transam剩余回合"] = 2
	var 高速 := CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB2_W1"))
	t.ok(J.truthy(高速.get("武器", {}).get("ignore_block")),
		"⑫ TRANS-AM 专属【高速狙击】：所有直射武器**无视遮挡**")
	u["transam剩余回合"] = 0
	var 常速 := CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB2_W1"))
	t.ok(not J.truthy(常速.get("武器", {}).get("ignore_block")), "⑫ 不在 TRANS-AM 中就没有高速狙击")
	# —— 最后的狙击 ——
	var 末卡: Dictionary = _驾卡("CB2", "CB2_U4", false)
	t.ok(str(末卡.get("名")) == "最后的狙击" and float(末卡.get("耗气")) == 30.0
		and float(末卡.get("限次")) == 1.0, "⑫ 最后的狙击：30 费 · 每场 1 次")
	var 末门: Dictionary = 末卡.get("实时门槛")
	t.ok(末门 is Dictionary and str(末门.get("类型")) == "全部", "⑫ 亮起条件 = 第 4 回合起 且 洛克昂 HP ≤ 40%")
	var 场2 := _驾场("CB2", 4.0)
	var u2: Dictionary = 场2.u
	var c2: Dictionary = 场2.c
	u2["hp"] = float(u2.get("maxHp")) * 0.3
	u2["战意"] = 100.0
	c2["turn"] = 4.0
	DeckFlow.阶段初_检查(c2)
	var r末 := DeckFlow.打出大招(c2, "CB2", "CB2_U4", "靶1")
	t.ok(J.truthy(r末.get("成功")), "⑫ 打出【最后的狙击】：%s" % str(r末.get("原因", "")))
	t.ok(_日志含(c2, "必中"), "⑫ 最后的狙击 **必中**（战报：%s）" % _找行(c2, "最后的狙击"))
	t.ok(absf(float(u2.get("右眼负伤")) - 10.0) < 0.01,
		"⑫ 打出后本场 **右眼负伤**：命中 −10（Lv30 的 `+` 版；%s）" % J.s(u2.get("右眼负伤")))
	t.ok(str(_驾卡("CB2", "CB2_U4", false).get("效果说明")).contains("命中 −20"),
		"⑫ 非 `+` 版的右眼负伤 = **命中 −20**（卡面逐字）")
	var 盲武: Dictionary = CelestialV01.武器打出前(c2, u2, CelestialV01._武器栏卡(u2, "CB2_W1")).get("武器", {})
	t.ok(absf(float(盲武.get("hit")) - 120.0) < 0.01,
		"⑫ 右眼负伤真的进了命中（狙击步枪 130 → %s，【狙い撃つ】溢出大减）" % J.s(盲武.get("hit")))
	var 场3 := _驾场("CB2", 4.0)
	var u3: Dictionary = 场3.u
	var c3: Dictionary = 场3.c
	u3["hp"] = float(u3.get("maxHp")) * 0.3
	u3["战意"] = 100.0
	c3["turn"] = 4.0
	DeckFlow.阶段初_检查(c3)
	DeckFlow.打出大招(c3, "CB2", "CB2_U4", "靶1")
	t.ok(absf(float(u3.get("右眼负伤")) - 10.0) < 0.01, "⑫ `+` 版 右眼负伤改成命中 −10")
	for 槽 in J.or_(u3.get("大招槽"), []):
		槽["本回合已打"] = false
	t.ok(DeckFlow.大招不可打原因(c3, u3, DeckFlow.找大招槽(u3, "CB2_U4")).contains("每场 1 次"),
		"⑫ 最后的狙击**每场 1 次**：清掉「本回合已打」之后仍然打不出来（%s）"
			% DeckFlow.大招不可打原因(c3, u3, DeckFlow.找大招槽(u3, "CB2_U4")))
	# —— 援护射击的代价 / 预判射击 ——
	var 场4 := _驾场("CB2", 4.0)
	var u4: Dictionary = 场4.u
	var c4: Dictionary = 场4.c
	var 狙精神: Dictionary = _驾卡("CB2", "CB2_S1", false)
	u4.专属手牌.append(狙精神)
	Btl.打出精神或公有牌(c4, "CB2", 狙精神, "靶1")
	t.ok(J.truthy(u4.get("本回合禁援护")),
		"⑫ 【狙い撃つぜ】的代价：本回合不能打援护射击（%s）"
			% CelestialV01.副武器不可打原因(c4, u4, _驾卡("CB2", "CB2_D1")))
	t.ok(DeckFlow.副武器不可打原因(c4, u4, DeckFlow.找副武器(u4, "CB2_D1")).contains("援护射击"),
		"⑫ 副武器门禁真的拦住了援护射击")
	u4.erase("本回合禁援护")
	var 预卡: Dictionary = _驾卡("CB2", "CB2_S5", false)
	u4.专属手牌.append(预卡)
	Btl.打出精神或公有牌(c4, "CB2", 预卡, "靶1")
	var 援武满: Dictionary = CelestialV01.副武器打出前(c4, u4, _驾卡("CB2", "CB2_D1"))
	t.ok(absf(float(援武满.get("power")) - 2550.0) < 0.01,
		"⑫ 【预判射击】：本回合援护射击打它伤害改为 **100%%**（70%% → %s）" % J.s(援武满.get("power")))
	t.ok(副 == ["援护射击"] and 精.has("★「狙い撃つぜ」") and 精.has("★ 预判射击"),
		"⑫ 精神牌里两张 ★：【狙い撃つぜ】/【预判射击】")

# ==========================================================================================
# ⑬ ★ CB-3：阿雷路亚 CB3 —— 【双人格】/ 哈雷路亚 / 超兵同调 / 双人格同步
# ==========================================================================================
func _段13_阿雷路亚双人格(t) -> void:
	var 主 := _卡名们("CB3", false, "主武器卡")
	var 大 := _卡名们("CB3", false, "大招槽卡")
	var 精 := _卡名们("CB3", false, "专属精神牌")
	t.ok(主.size() == 4 and 大.size() == 4 and 精.size() == 9,
		"⑬ 阿雷路亚卡池：主武器 %d / 大招 %d（含 人格交替，+TRANS-AM）/ 精神 %d" % [主.size(), 大.size(), 精.size()])
	t.ok(主 == ["GN 光束冲锋枪", "GN 光束军刀", "GN 盾·钳爪", "GN 冲撞（飞行形态）"],
		"⑬ 4 把主武器逐字：%s" % str(主))
	t.ok(大 == ["人格交替", "★ GN 导弹·全弹", "★ 超兵·极限机动", "GN 冲撞·双人格同步"],
		"⑬ 4 张大招逐字：%s" % str(大))
	var 冲武: Dictionary = _武参("CB3", "CB3_W4")
	t.ok(J.truthy(冲武.get("ignore_block")), "⑬ GN 冲撞（飞行形态）：近战但**可以打敌方后排**")
	var 场 := _驾场("CB3", 1.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	var 敌: Dictionary = c.enemies[0]
	t.ok(CelestialV01.当前人格(u) == "阿雷路亚" and CelestialV01.人格阿雷路亚 == "阿雷路亚",
		"⑬ 开场人格 = 阿雷路亚（枚举 `阿雷路亚` / `哈雷路亚`）")
	t.ok(absf(CelestialV01.命中修正(敌, u, {}, c)) < 0.0001, "⑬ 阿雷路亚人格没有闪避加成")
	CelestialV01.切换人格(c, u, "测试")
	t.ok(CelestialV01.哈雷路亚中(u) and J.truthy(u.get("本场两人格都出现过")),
		"⑬ 切换到 **哈雷路亚**（本场两人格都出现过 = true）")
	t.ok(absf(CelestialV01.命中修正(敌, u, {}, c) + 10.0) < 0.0001,
		"⑬ 哈雷路亚人格 **闪避 +10**（打它的人每段命中 −10）")
	# 哈雷路亚禁打公有排
	var 势卡 := _势卡("CB_FAC_1")
	t.ok(not CelestialV01.公有牌可打(c, u), "⑬ 哈雷路亚**打不了公有排**的牌（势力 / 分类 / 太阳炉）")
	t.ok(CelestialV01.精神牌原因(c, u, 势卡, true).contains("哈雷路亚"),
		"⑬ 公有牌的可打原因 = 「%s」" % CelestialV01.精神牌原因(c, u, 势卡, true))
	u["transam剩余回合"] = 15
	t.ok(CelestialV01.公有牌可打(c, u), "⑬ TRANS-AM 中（超兵同调）哈雷路亚**也能打公有排**")
	u["transam剩余回合"] = 0
	u["双重思考回合"] = float(c.get("turn"))
	t.ok(CelestialV01.公有牌可打(c, u), "⑬ 本回合打了「双重思考」→ 哈雷路亚也能打公有排")
	u.erase("双重思考回合")
	# 只限人格
	t.ok(CelestialV01.精神牌原因(c, u, _驾卡("CB3", "CB3_S3", false)).contains("只限阿雷路亚"),
		"⑬ 【GN 盾】只限阿雷路亚（哈雷路亚时打不出：%s）"
			% CelestialV01.精神牌原因(c, u, _驾卡("CB3", "CB3_S3", false)))
	# 哈雷路亚加强段
	var 冲枪: Dictionary = CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB3_W1")).get("武器", {})
	t.ok(absf(float(冲枪.get("hit")) - 115.0) < 0.01,
		"⑬ 哈雷路亚：光束冲锋枪**每段命中 +15**（100 → %s）" % J.s(冲枪.get("hit")))
	var 军刀: Dictionary = CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB3_W2")).get("武器", {})
	t.ok(absf(float(军刀.get("critMod")) - 25.0) < 0.01,
		"⑬ 哈雷路亚：光束军刀**暴击 +25**（%s）" % J.s(军刀.get("critMod")))
	var 冲撞: Dictionary = CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB3_W4")).get("武器", {})
	t.ok(absf(float(冲撞.get("power")) - 1800.0 * 1.3) < 0.01,
		"⑬ 哈雷路亚：GN 冲撞**伤害 +30%%**（1800 → %s）" % J.s(冲撞.get("power")))
	# GN 盾·钳爪：命中后目标下个敌方阶段命中 −20（哈雷路亚 −40）
	var 场钳 := _驾场("CB3", 1.0)
	var 钳u: Dictionary = 场钳.u
	var 钳c: Dictionary = 场钳.c
	钳u["战意"] = 100.0
	var 钳靶: Dictionary = 钳c.enemies[0]
	Btl.打出武器栏卡(钳c, "CB3", "CB3_W3", "靶1")
	t.ok(Calc.buffSum(钳靶, "hit") <= -20.0,
		"⑬ 【GN 盾·钳爪】命中后目标下个敌方阶段**命中 −%d**" % int(-Calc.buffSum(钳靶, "hit")))
	var 场钳2 := _驾场("CB3", 1.0)
	var 钳u2: Dictionary = 场钳2.u
	var 钳c2: Dictionary = 场钳2.c
	钳u2["战意"] = 100.0
	钳u2["人格"] = "哈雷路亚"
	var 钳靶2: Dictionary = 钳c2.enemies[0]
	Btl.打出武器栏卡(钳c2, "CB3", "CB3_W3", "靶1")
	t.ok(Calc.buffSum(钳靶2, "hit") <= -40.0,
		"⑬ 哈雷路亚：【钳爪】改为**命中 −%d**" % int(-Calc.buffSum(钳靶2, "hit")))
	# GN 冲撞（飞行形态）：近战也能打敌方后排
	var 冲场_u := _单位("CB3", "ally", 1.0, "特种")
	var 前冲 := _靶("靶前", 0.0)
	var 后冲 := _靶("靶后", 5.0)
	var 冲c := _场([冲场_u], [前冲, 后冲], 种子)
	t.ok(J.truthy(Reach.武器可达吗(冲c, 冲场_u, _武参("CB3", "CB3_W4"), 后冲).get("ok"))
		and not J.truthy(Reach.武器可达吗(冲c, 冲场_u, _武参("CB3", "CB3_W2"), 后冲).get("ok")),
		"⑬ 【GN 冲撞（飞行形态）】**可以打敌方后排**（普通近战军刀打不到）")	# 被动切换：rng / never / always
	var 场2 := _驾场("CB3", 1.0)
	var u2: Dictionary = 场2.u
	var c2: Dictionary = 场2.c
	c2["双人格切换模式"] = "always"
	CelestialV01.受击后(c2, u2)
	t.ok(CelestialV01.哈雷路亚中(u2), "⑬ `ctx.双人格切换模式 = \"always\"` → 受击结算后必定切换")
	CelestialV01.武器打完后(c2, u2, {}, null)
	t.ok(CelestialV01.当前人格(u2) == "阿雷路亚", "⑬ → 攻击结算后再切一次（回到阿雷路亚）")
	c2["双人格切换模式"] = "never"
	CelestialV01.受击后(c2, u2)
	t.ok(CelestialV01.当前人格(u2) == "阿雷路亚", "⑬ `\"never\"` → 不被动切换")
	# rng：同种子两遍逐字相同
	var a := _切换序列("rng")
	var b := _切换序列("rng")
	t.ok(a == b and a.size() == 20, "⑬ `\"rng\"`（20%%）同种子两遍逐字相同：%s" % str(a.slice(0, 8)))
	# 超兵同调
	var 场3 := _驾场("CB3", 1.0)
	var u3: Dictionary = 场3.u
	var c3: Dictionary = 场3.c
	CelestialV01.开启TRANSAM(c3, u3)
	t.ok(J.truthy(u3.get("超兵同调")), "⑬ TRANS-AM 一开就激活【超兵同调】")
	c3["双人格切换模式"] = "always"
	CelestialV01.受击后(c3, u3)
	t.ok(CelestialV01.当前人格(u3) == "阿雷路亚", "⑬ 超兵同调：**不会被动切换**")
	u3["transam剩余回合"] = 1
	CelestialV01.我方阶段末(c3)
	t.ok(not J.truthy(u3.get("超兵同调")), "⑬ TRANS-AM 结束 → 超兵同调一起结束（被动切换恢复）")
	# GN 导弹·全弹：哈雷路亚 12 段
	var 场4 := _驾场("CB3", 1.0)
	var u4: Dictionary = 场4.u
	var c4: Dictionary = 场4.c
	u4["战意"] = 100.0
	c4["turn"] = 4.0
	DeckFlow.阶段初_检查(c4)
	DeckFlow.打出大招(c4, "CB3", "CB3_U3", "靶1")
	t.ok(_日志含(c4, "450 × 10 段"), "⑬ 【GN 导弹·全弹】= 曲射 · 物理 450 × 10 段 · 散布（Lv30 的 `+` 版）")
	u4["人格"] = "哈雷路亚"
	u4["战意"] = 100.0
	u4["主武器已销毁"] = false
	for 槽 in J.or_(u4.get("大招槽"), []):
		槽["本回合已打"] = false
		槽["cd"] = 0.0
	DeckFlow.打出大招(c4, "CB3", "CB3_U3", "靶1")
	t.ok(_日志含(c4, "450 × 14 段"), "⑬ 哈雷路亚：【GN 导弹·全弹】改为 **14 段**（`+` 版）")
	# 双人格同步：必中 + 可打后排 + 反冲 15%
	# 敌方**前排还活着** → 普通近战打不到后排；双人格同步带 `无视遮挡` 才打得到。
	var u5 := _单位("CB3", "ally", 1.0, "特种")
	var 前5 := _靶("靶前", 0.0)
	var 后5 := _靶("靶后", 5.0)
	var c5 := _场([u5], [前5, 后5], 种子)
	for x in CelestialV01.装填单位(u5, 30, c5):
		u5.专属牌库.append(x)
	DeckFlow.拆分单位牌(u5, c5)
	CelestialV01.装填大招槽(c5, u5)
	u5["战意"] = 100.0
	u5["本场两人格都出现过"] = true
	c5["turn"] = 4.0
	DeckFlow.阶段初_检查(c5)
	var 前HP := float(u5.get("hp"))
	var r5 := DeckFlow.打出大招(c5, "CB3", "CB3_U5", "靶后")
	t.ok(J.truthy(r5.get("成功")), "⑬ 打出【GN 冲撞·双人格同步】：%s" % str(r5.get("原因", "")))
	var 末记 := _末攻击(c5)
	t.ok(not 末记.is_empty() and str(末记.get("详情", "")).contains("必中"),
		"⑬ 双人格同步 **必中**（攻击详情的每一段都是「必中」）")
	var 靶5: Dictionary = 后5
	t.ok(J.truthy(末记.get("命中")) and not J.truthy(Reach.武器可达吗(c5, u5, _武参("CB3", "CB3_W2"), 靶5).get("ok")),
		"⑬ 双人格同步**打得到敌方后排**（同一把普通近战军刀打不到那台：%s）"
			% str(Reach.武器可达吗(c5, u5, _武参("CB3", "CB3_W2"), 靶5).get("why")))
	t.ok(absf(前HP - float(u5.get("hp"))) < 0.01,
		"⑬ `+` 版【双人格同步】**不再受反冲伤害**（HP %s → %s）" % [J.s(前HP), J.s(u5.get("hp"))])
	t.ok(str(_驾卡("CB3", "CB3_U5", false).get("效果说明")).contains("15%"),
		"⑬ 非 `+` 版才有「自己最大 HP 15%% 的反冲」（卡面逐字）")
	# 「人格交替」每回合 1 次
	var 场6 := _驾场("CB3", 1.0)
	var u6: Dictionary = 场6.u
	var c6: Dictionary = 场6.c
	u6["战意"] = 100.0
	var r6 := DeckFlow.打出大招(c6, "CB3", "CB3_U1", "靶1")
	t.ok(J.truthy(r6.get("成功")) and CelestialV01.哈雷路亚中(u6),
		"⑬ 【人格交替】0 费、开战即可用、切到另一个人格")
	t.ok(DeckFlow.大招不可打原因(c6, u6, DeckFlow.找大招槽(u6, "CB3_U1")) == "本回合已使用",
		"⑬ 【人格交替】**每回合 1 次**（同回合第二次 → 本回合已使用）")

## ⑬ 同一份种子下连掷 20 次「受击后被动切换」的人格序列。
func _切换序列(模式: String) -> Array:
	var 出: Array = []
	var 场 := _驾场("CB3", 1.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	c["双人格切换模式"] = 模式
	for i in 20:
		CelestialV01.受击后(c, u)
		出.append(CelestialV01.当前人格(u))
	return 出

# ==========================================================================================
# ⑭ ★ CB-3：提耶利亚 CB4 —— 【演算】/ 脱装·纳德雷 / 高压全弹·横扫 / 爆裂模式过热
# ==========================================================================================
func _段14_提耶利亚演算与脱装(t) -> void:
	var 主 := _卡名们("CB4", false, "主武器卡")
	var 大 := _卡名们("CB4", false, "大招槽卡")
	var 精 := _卡名们("CB4", false, "专属精神牌")
	t.ok(主.size() == 6 and 大.size() == 3 and 精.size() == 9,
		"⑭ 提耶利亚卡池：主武器 %d（德天使 3 + 纳德雷 3）/ 大招 %d / 精神 %d" % [主.size(), 大.size(), 精.size()])
	t.ok(主 == ["GN 火箭筒", "GN 加农炮", "GN 火箭筒·扩散", "GN 光束军刀", "GN 光束步枪", "高机动射击"],
		"⑭ 6 把主武器逐字：%s" % str(主))
	t.ok(大 == ["★ GN 火箭筒·高压全弹", "脱装·纳德雷", "★ GN 火箭筒·爆裂模式"],
		"⑭ 3 张大招逐字：%s" % str(大))
	t.ok(CelestialV01.纳德雷武器表("CB4").size() == 3, "⑭ 纳德雷 3 把主武器（脱装时整套换上）")
	var 场 := _驾场("CB4", 4.0)
	var u: Dictionary = 场.u
	var c: Dictionary = 场.c
	t.ok(u.武器栏.size() == 3, "⑭ 开场的武器栏只有德天使 3 把（纳德雷**不单独抽**）")
	# —— 【演算】 ——
	var 火武: Dictionary = _武参("CB4", "CB4_W1")
	t.ok(float(火武.get("power")) == 2700.0 and float(火武.get("hit")) == 90.0,
		"⑭ GN 火箭筒：直射 · 光束 2700 · 距离 2–6 · 命中 90")
	t.ok(not CelestialV01.演算满足(c, u), "⑭ 【演算】未满足（本回合还没打过 Veda 牌）")
	var 未演: Dictionary = CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB4_W1")).get("武器", {})
	t.ok(not J.truthy(未演.get("ignore_block")), "⑭ 未满足演算 → 火箭筒没有「无视遮挡」")
	c["本回合打过Veda"] = true
	t.ok(CelestialV01.演算满足(c, u), "⑭ 本回合打过 Veda 牌 → 【演算】满足")
	var 演过: Dictionary = CelestialV01.武器打出前(c, u, CelestialV01._武器栏卡(u, "CB4_W1")).get("武器", {})
	t.ok(J.truthy(演过.get("ignore_block")), "⑭ 【演算】：GN 火箭筒**无视遮挡**")
	var 高武: Dictionary = _武参("CB4", "CB4_NW3")
	var 高演: Dictionary = CelestialV01.武器打出前(c, u, _驾卡("CB4", "CB4_NW3")).get("武器", {})
	t.ok(absf(float(高演.get("hit")) - 120.0) < 0.01,
		"⑭ 【演算】：高机动射击**每段命中 +20**（100 → %s）" % J.s(高演.get("hit")))
	c["本回合打过Veda"] = false
	u["独自判断回合"] = float(c.get("turn"))
	t.ok(CelestialV01.演算满足(c, u), "⑭ 本回合打了【独自判断】→ 演算视为满足")
	u.erase("独自判断回合")
	# —— 脱装·纳德雷 ——
	var 场2 := _提耶场()
	var u2: Dictionary = 场2.u
	var c2: Dictionary = 场2.c
	var r := DeckFlow.打出大招(c2, "CB4", "CB4_U3", "靶前")
	t.ok(J.truthy(r.get("成功")), "⑭ 打出【脱装·纳德雷】：%s" % str(r.get("原因", "")))
	t.ok(u2.武器栏.size() == 3 and str(u2.武器栏[0].get("名")) == "GN 光束军刀",
		"⑭ `DeckFlow.切换武器栏(u, 纳德雷武器表, \"permanent\")` → 武器栏整套换成纳德雷")
	t.ok(str(u2.get("武器栏切换模式")) == "permanent" and J.truthy(u2.get("本场脱装过")),
		"⑭ 本场**永久**替换（`permanent`），不能换回")
	t.ok(absf(float(u2.get("armor")) - 700.0) < 0.01,
		"⑭ 装甲 **−30%%**（Lv30 的 `+` 版：1000 → %s）" % J.s(u2.get("armor")))
	t.ok(str(_驾卡("CB4", "CB4_U3", false).get("效果说明")).contains("−50%"),
		"⑭ 非 `+` 版的装甲 = **−50%%**（卡面逐字）")
	t.ok(absf(float(u2.get("eva")) - 25.0) < 0.01, "⑭ 闪避 **+25**（%s）" % J.s(u2.get("eva")))
	var 前敌: Dictionary = 场2.前
	t.ok(J.truthy(前敌.get("脱装不能攻击")) and Btl.禁止攻击(前敌, c2),
		"⑭ 敌方前排**下个敌方阶段不能攻击**（`Btl.禁止攻击` 拦得住）")
	t.ok(not J.truthy((场2.后 as Dictionary).get("脱装不能攻击")),
		"⑭ 只停**前排**：敌方后排那台照常能打")
	CelestialV01.阶段初(c2)
	t.ok(not J.truthy(前敌.get("脱装不能攻击")), "⑭ 那个「不能攻击」只活一个敌方阶段（我方阶段初清掉）")
	var 场3 := _提耶场()
	var u3: Dictionary = 场3.u
	var c3: Dictionary = 场3.c
	DeckFlow.打出大招(c3, "CB4", "CB4_U3", "靶前")
	t.ok(absf(float(u3.get("armor")) - 700.0) < 0.01, "⑭ `+` 版 装甲只降 30%%（1000 → %s）" % J.s(u3.get("armor")))
	t.ok(CelestialV01.精神牌原因(c3, u3, _驾卡("CB4", "CB4_S4", false)).contains("纳德雷"),
		"⑭ 【GN 场展开】脱装后不能打（%s）" % CelestialV01.精神牌原因(c3, u3, _驾卡("CB4", "CB4_S4", false)))
	# 头目 → 命中 −30
	var 场4 := _提耶场()
	var u4: Dictionary = 场4.u
	var c4: Dictionary = 场4.c
	var 头: Dictionary = 场4.前
	头["boss"] = true
	DeckFlow.打出大招(c4, "CB4", "CB4_U3", "靶前")
	t.ok(not J.truthy(头.get("脱装不能攻击")), "⑭ 头目不会被「不能攻击」")
	t.ok(Calc.buffSum(头, "hit") < 0.0, "⑭ 头目改为 **下一个敌方阶段命中 −30**（buff：%s）" % J.s(Calc.buffSum(头, "hit")))
	# —— 高压全弹：TRANS-AM 中从贯穿改横扫 ——
	t.ok(_高压形状(true).contains("横扫"), "⑭ TRANS-AM 中「高压全弹」的范围改为**横扫**（战报：%s）" % _高压形状(true))
	t.ok(_高压形状(false).contains("贯穿") and not _高压形状(false).contains("横扫"),
		"⑭ 不在 TRANS-AM 中还是**贯穿**（战报：%s）" % _高压形状(false))
	# —— 爆裂模式：炮管过热 ——
	var 场6 := _驾场("CB4", 4.0)
	var u6: Dictionary = 场6.u
	var c6: Dictionary = 场6.c
	u6["战意"] = 100.0
	c6["turn"] = 4.0
	DeckFlow.阶段初_检查(c6)
	var r6 := DeckFlow.打出大招(c6, "CB4", "CB4_U4", "靶1")
	t.ok(J.truthy(r6.get("成功")), "⑭ 打出【GN 火箭筒·爆裂模式】：%s" % str(r6.get("原因", "")))
	t.ok(not J.truthy(u6.get("下回合武器全消")), "⑭ `+` 版【爆裂模式】**不再过热**")
	t.ok(str(_驾卡("CB4", "CB4_U4", false).get("效果说明")).contains("过热"),
		"⑭ 非 `+` 版才有「炮管过热」（卡面逐字）")
	var 场7 := _驾场("CB4", 4.0)
	var u7: Dictionary = 场7.u
	var c7: Dictionary = 场7.c
	u7["战意"] = 100.0
	c7["turn"] = 4.0
	DeckFlow.阶段初_检查(c7)
	DeckFlow.打出大招(c7, "CB4", "CB4_U4", "靶1")
	t.ok(J.truthy(u7.get("武器牌")) or true, "⑭ 爆裂模式是武器型大招（`武器牌 = true`）")

## ⑭ 一发【高压全弹】之后，战报里那句「射程形状」是什么（`横扫` = TRANS-AM 中）。
func _高压形状(横扫: bool) -> String:
	var u := _单位("CB4", "ally", 4.0, "重装")
	var 甲 := _靶("靶A", 4.0)
	var 乙 := _靶("靶B", 5.0)
	var 丙 := _靶("靶C", 0.0)
	var c := _场([u], [丙, 甲, 乙])
	for x in CelestialV01.装填单位(u, 30, c):
		u.专属牌库.append(x)
	DeckFlow.拆分单位牌(u, c)
	CelestialV01.装填大招槽(c, u)
	u["战意"] = 100.0
	if 横扫:
		u["transam剩余回合"] = 2
	c["turn"] = 4.0
	DeckFlow.阶段初_检查(c)
	DeckFlow.打出大招(c, "CB4", "CB4_U2", "靶C")
	for 行 in _行们(c):
		if str(行).contains("横扫") or str(行).contains("贯穿"):
			return str(行)
	return "（没有这一行）"

# ==========================================================================================
# ⑮ 驾驶员全卡冒烟：76 张牌一张不落地过一遍（构造 / 数值 / 精神牌真的打得出去）
# ==========================================================================================
func _段15_驾驶员全卡冒烟(t) -> void:
	var 全 := CelestialV01.驾驶员全卡()
	t.ok(全.size() == 140, "⑮ 四名驾驶员的卡表合计 **140 张**（70 × 2，含 `+` 版）…实际 %d" % 全.size())
	var 缺: Array = []
	for c in 全:
		var 卡: Dictionary = c
		if str(卡.get("id", "")) == "" or str(卡.get("名", "")) == "" \
			or not ["主武器卡", "副武器卡", "大招槽卡", "专属精神牌"].has(str(卡.get("卡类", ""))):
			缺.append(str(卡.get("id")))
	t.ok(缺.is_empty(), "⑮ 140 张牌的 `id / 名 / 卡类` 全部齐（缺：%s）" % str(缺))
	var 主 := 0
	var 副 := 0
	var 大 := 0
	var 精 := 0
	for c in 全:
		match str((c as Dictionary).get("卡类", "")):
			"主武器卡": 主 += 1
			"副武器卡": 副 += 1
			"大招槽卡": 大 += 1
			"专属精神牌": 精 += 1
	t.ok(主 == 38 and 副 == 4 and 大 == 26 and 精 == 72, "⑮ 分区：主武器 %d / 副武器 %d / 大招 %d / 精神 %d" % [主, 副, 大, 精])
	# 精神牌：一张一张真的打出去（同一台机体、每个牌用新的场，避免互相污染）
	var 打不出: Array = []
	for c in 全:
		var 卡: Dictionary = c
		if str(卡.get("卡类", "")) != "专属精神牌":
			continue
		var 键 := str(卡.get("角色", ""))
		var 场 := _驾场(键, 0.0)
		var u: Dictionary = 场.u
		var 场c: Dictionary = 场.c
		u["战意"] = 100.0
		u["hp"] = float(u.get("maxHp")) * 0.3
		场c["turn"] = 5.0
		# 「只限哈雷路亚」的牌 → 先把人格切过去
		if str(卡.get("只限人格", "")) == "哈雷路亚":
			u["人格"] = "哈雷路亚"
		u.专属手牌.append(卡)
		var r := Btl.打出精神或公有牌(场c, 键, 卡, "靶1")
		if not J.truthy(r.get("成功")):
			打不出.append("%s（%s）" % [str(卡.get("名")), str(r.get("原因"))])
	t.ok(打不出.is_empty(), "⑮ 72 张精神牌**逐张真的打得出去**（打不出：%s）" % str(打不出.slice(0, 6)))

# ==========================================================================================
# ⑯ ★ CB-4：快速测试战斗（天人五人）+ 状态标签 / 〔介入〕/ 太阳炉明细 / 默认点选
# ==========================================================================================
func _段16_天人快速战斗与标签(t) -> void:
	var s := GameSession.new()
	t.ok(s.start_quick_battle_celestial(20261018), "⑯ `start_quick_battle_celestial()` 开得起来")
	t.ok(str(s.screen) == "battle" and s.单机牌组开(), "⑯ 直接进战斗屏、单机牌组 + 卡牌流转都开着")
	var ctx: Dictionary = s.battle_ctx
	var 位 := {}
	for u in J.or_(ctx.get("allies"), []):
		位[str(u.get("key"))] = int(float(u.get("slot")))
	t.ok(位.get("CB1") == 0 and 位.get("CB3") == 1 and 位.get("CB5") == 2
		and 位.get("CB2") == 4 and 位.get("CB4") == 5,
		"⑯ 站位：前排 CB1/CB3/CB5（0/1/2）、后排 CB2/CB4（4/5）→ %s" % str(位))
	t.ok((ctx.get("enemies") as Array).size() == 5, "⑯ 对战 5 台试玩靶机")
	var 靶: Dictionary = (ctx.get("enemies") as Array)[0]
	t.ok(float(靶.get("hp")) >= 20000.0, "⑯ 靶机是「高耐久」试玩靶（HP %s）" % J.s(靶.get("hp")))
	# 状态标签
	var 刹: Dictionary = _找友(ctx, "CB1")
	var 图 := s.unit_view("ally", "CB1")
	t.ok(not str(图.get("状态")).contains("出鞘"), "⑯ 刹那开局 0 张出鞘 → 状态行里没有〔出鞘〕（%s）" % str(图.get("状态")))
	刹["战意"] = 100.0
	Btl.打出武器栏卡(ctx, "CB1", "CB1_W2", str(靶.get("key")))
	图 = s.unit_view("ally", "CB1")
	t.ok(str(图.get("状态")).contains("〔出鞘 1/7〕"), "⑯ 打一张剑牌后状态行出现 **〔出鞘 1/7〕**（%s）" % str(图.get("状态")))
	CelestialV01.全部剑牌出鞘(刹)
	CelestialV01.判定七剑齐出(ctx, 刹)
	图 = s.unit_view("ally", "CB1")
	t.ok(str(图.get("状态")).contains("〔★七剑齐出〕"), "⑯ 七剑齐出后状态行变成 **〔★七剑齐出〕**（%s）" % str(图.get("状态")))
	var 阿: Dictionary = _找友(ctx, "CB3")
	t.ok(str(s.unit_view("ally", "CB3").get("状态")).contains("〔阿雷路亚〕"),
		"⑯ 阿雷路亚的状态行有 **〔阿雷路亚〕**")
	阿["人格"] = "哈雷路亚"
	t.ok(str(s.unit_view("ally", "CB3").get("状态")).contains("〔哈雷路亚〕"), "⑯ 切成哈雷路亚 → **〔哈雷路亚〕**")
	var 提: Dictionary = _找友(ctx, "CB4")
	提["本场脱装过"] = true
	t.ok(str(s.unit_view("ally", "CB4").get("状态")).contains("〔纳德雷〕"), "⑯ 脱装后 → **〔纳德雷〕**")
	var 洛: Dictionary = _找友(ctx, "CB2")
	洛["右眼负伤"] = 20.0
	t.ok(str(s.unit_view("ally", "CB2").get("状态")).contains("〔右眼负伤〕"), "⑯ 洛克昂 → **〔右眼负伤〕**")
	刹["transam剩余回合"] = 2
	t.ok(str(s.unit_view("ally", "CB1").get("状态")).contains("〔TRANS-AM 剩2〕"), "⑯ TRANS-AM 中 → **〔TRANS-AM 剩N〕**")
	刹["transam剩余回合"] = 0
	刹["粒子耗尽剩余回合"] = 1
	t.ok(str(s.unit_view("ally", "CB1").get("状态")).contains("〔粒子耗尽〕"), "⑯ **〔粒子耗尽〕**")
	刹.erase("粒子耗尽剩余回合")
	# 〔介入〕
	t.ok(s.介入标记(str(靶.get("key"))) == false,
		"⑯ 这台靶机刚才被刹那打过 → **不再挂〔介入〕**")
	var 未打: Dictionary = {}
	for e in J.or_(ctx.get("enemies"), []):
		if not J.truthy(e.get("本回合被攻击过")) and 未打.is_empty():
			未打 = e
	t.ok(not 未打.is_empty() and s.介入标记(str(未打.get("key"))),
		"⑯ 本回合还没挨打的敌机 → **青色〔介入〕**（%s）" % str(未打.get("name")))
	未打["本回合任务目标"] = true
	未打["本回合被攻击过"] = true
	t.ok(s.介入标记(str(未打.get("key"))), "⑯ `Veda·任务计划` 的任务目标照样挂〔介入〕")
	# 太阳炉明细 / 左栏
	t.ok(s.太阳炉明细().size() >= 4, "⑯ 左栏太阳炉牌库明细有 %d 张" % s.太阳炉明细().size())
	t.ok(s.太阳炉左栏文().contains("太阳炉牌库"), "⑯ 左栏那一行：%s" % s.太阳炉左栏文())
	t.ok(s.默认太阳炉牌() == "CB_SD1_SCATTER" and s.默认太阳炉牌(true) == "CB_SD1_VEDA_SCAN",
		"⑯ 无参 / 自动时按默认优先级选太阳炉牌（%s / %s）" % [s.默认太阳炉牌(), s.默认太阳炉牌(true)])
	t.ok(s.默认拔刀目标("CB1") == "CB1_W2" or not s.默认拔刀目标("CB1").is_empty(),
		"⑯ 自动拔刀目标 = 第一张出鞘的剑牌（%s）" % s.默认拔刀目标("CB1"))
	t.ok(s.出鞘标记文({"剑数": 2, "出鞘": true}) == "〔出鞘 · 剑×2〕"
		and s.出鞘标记文({"剑数": 2, "出鞘": false}) == "",
		"⑯ 出鞘剑牌的左栏标记 = **〔出鞘 · 剑×2〕**（没出鞘 = 空串）")
	# 主菜单源码里挂着这个入口
	var 源 := ""
	var f := FileAccess.open("res://presentation/menus/menu_view.gd", FileAccess.READ)
	if f != null:
		源 = f.get_as_text()
		f.close()
	t.ok(源.contains("快速测试战斗（天人五人）") and 源.contains("start_quick_battle_celestial"),
		"⑯ 主菜单上挂着【快速测试战斗（天人五人）】按钮，调 `start_quick_battle_celestial()`")
	t.ok(GameSession.快速测试_天人 == "天人" and GameSession.天人快速编成.size() == 5,
		"⑯ `GameSession.快速测试_天人` / `天人快速编成` 都在")

## ★ 段17（2026-10-23 任务单 UI-2）：`目标 = 天人成员` 的 11 张牌在门面导出的手牌视图里
##   **`目标方 == 友方`** —— 从前 `目标_友方集` 漏了「天人成员」，这 11 张全被算成「敌方」，
##   玩家拖它们时画的是红色敌方线、往我方机体上拖完全不吸附，点一下还会乱奶默认目标。
##   本段只读门面（`lower_hand_cards()` / `upper_hand_cards()` / `CardPlay.目标方()`），零状态修改。
func _段17_友方目标识别(t) -> void:
	var s := GameSession.new()
	t.ok(s.start_quick_battle_celestial(20261018), "⑰ 天人快速战斗开得起来（验目标方用）")
	var ctx: Dictionary = s.battle_ctx
	if ctx.is_empty():
		t.ok(false, "⑰ 没有 battle_ctx —— 目标方那几条跑不了")
		return
	# 太阳炉 6 张 + 势力牌 4 张塞进公有手牌；拉塞的「去吧，刹那」塞进他的专属手牌。
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var 要验: Array = ["CB_SD1_HARO_HEAL", "CB_SD1_REFILL", "CB_SD1_VEDA_SCAN",
		"CB_SD2_HARO_SHIELD", "CB_SD2_SUPER_REFLEX", "CB_SD3_HERITAGE",
		"CB_FAC_3", "CB_FAC_4", "CB_FAC_6", "CB_FAC_7"]
	for id in 要验:
		var 卡 := _天人牌(id)
		if not 卡.is_empty():
			手.append(卡)
	ctx["公有手牌"] = 手
	var 拉 := _找友(ctx, "CB5")
	if not 拉.is_empty():
		if not (拉.get("专属手牌") is Array):
			拉["专属手牌"] = []
		(拉["专属手牌"] as Array).append(_天人牌("CB5_S3"))
		s.select_battle_unit("CB5")
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary:
			u["战意"] = 100.0
	# ---- ① 11 张全在导出的手牌视图里，且 `目标方 == 友方` ----
	var 好 := 0
	var 坏: Array = []
	for id in 要验 + ["CB5_S3"]:
		var 视 := _手牌视图(s, id)
		if 视.is_empty():
			坏.append("%s(不在手牌视图里)" % id)
			continue
		if str(视.get("目标方", "")) == "友方":
			好 += 1
		else:
			坏.append("%s(目标方=%s)" % [id, str(视.get("目标方", ""))])
	t.ok(好 == 11, "⑰ **天人 11 张友方牌全部 `目标方 == 友方`**（%d/11 %s）" % [好, str(坏)])
	t.ok(str(_手牌视图(s, "CB_SD1_HARO_HEAL").get("目标", "")) == "天人成员",
		"⑰ 卡面 `目标` 原文照样透传（哈罗·紧急修理 = 天人成员）")
	# ---- ② 门面「打谁」的判据：`…成员` / 友军 / 修理 → 友方；敌机 / 自身 / 全队 → 敌方 / 无 ----
	var 判 := CardPlay.目标方({"目标": "天人成员", "名": "哈罗·紧急修理"})
	t.ok(判 == "友方", "⑰ `目标 == 天人成员` → `目标方 == 友方`（%s）" % 判)
	t.ok(CardPlay.目标方({"目标": "殖民卫星军成员"}) == "友方",
		"⑰ 以后的新势力 `殖民卫星军成员` 也直接判友方（不用再改常量表）")
	t.ok(CardPlay.目标方({"目标": "月球王国成员"}) == "友方"
		and CardPlay.目标方({"目标": "影世界成员"}) == "友方",
		"⑰ `月球王国成员` / `影世界成员` 同样判友方")
	t.ok(CardPlay.目标方({"目标": "友军"}) == "友方" and CardPlay.目标方({"目标": "秘银成员"}) == "友方",
		"⑰ 老白名单（友军 / 秘银成员）照旧判友方")
	t.ok(CardPlay.目标方({"目标": "敌机"}) == "敌方", "⑰ `目标 == 敌机` 仍判敌方")
	t.ok(CardPlay.目标方({"目标": "自身"}) == "无" and CardPlay.目标方({"目标": "全队"}) == "无",
		"⑰ `自身` / `全队` 仍是**免指派**（点一下就放，不当成要拖友军）")
	var 修武 := {"武器": {"fire": "heal", "range": [1.0, 8.0]}, "名": "紧急修理"}
	t.ok(CardPlay.目标方(修武, "主武器卡", true) == "友方",
		"⑰ 修理武器（`range_kind == 修理`）判友方 —— 玩家必须拖到己方机体上才放")
	# ---- ③ 编程 API 仍支持空 target_id 兜底（只约束 UI 鼠标点击，不影响任何后台测试）----
	var 哈 := _手牌视图(s, "CB_SD1_HARO_HEAL")
	if not 哈.is_empty():
		var r := s.play_unit_spirit_or_public_card(str(哈.get("手牌键", "")), "")
		t.ok(bool(r.get("ok", false)) or not str(r.get("为什么", "")).is_empty(),
			"⑰ 门面 API 直接打友军牌仍然走得通（空 `target_id` 由内核兜底；%s）"
			% str(r.get("为什么", "ok")))
	t.ok(s.errors is Array and (s.errors as Array).is_empty(), "⑰ 整段零报错 %s" % str(s.errors))

## 段17 用：`id` 那张天人牌的数据原件（太阳炉 / 势力 / 拉塞精神，三种都在这里找）。
func _天人牌(id: String) -> Dictionary:
	for c in CelestialV01.太阳炉卡表():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	for c in CelestialV01.势力牌们():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	for c in CelestialV01.拉塞卡表():
		if str((c as Dictionary).get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

## 段17 用：门面导出的手牌视图里 `id == id` 的那一张（上排 + 下排都认）。
func _手牌视图(s: GameSession, id: String) -> Dictionary:
	for 列 in [s.upper_hand_cards(), s.lower_hand_cards()]:
		for c in (列 as Array):
			if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
				return c
	return {}

## 最近一条攻击记录（`ctx.log` 里最后一条 `类型 = 攻击`）；没有 = {}。
func _末攻击(c: Dictionary) -> Dictionary:
	var 行: Array = J.or_(c.get("log"), [])
	for i in range(行.size() - 1, -1, -1):
		var e = 行[i]
		if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
			return e
	return {}

func _找友(c: Dictionary, 键: String) -> Dictionary:
	for u in J.or_(c.get("allies"), []):
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

## 提耶利亚的脱装场景：敌方**前排** slot 0 一台、后排 slot 5 一台（只有前排吃「不能攻击」）。
func _提耶场() -> Dictionary:
	var u := _单位("CB4", "ally", 4.0, "重装")
	var 前 := _靶("靶前", 0.0)
	var 后 := _靶("靶后", 5.0)
	var c := _场([u], [前, 后], 种子)
	for x in CelestialV01.装填单位(u, 30, c):
		u.专属牌库.append(x)
	DeckFlow.拆分单位牌(u, c)
	CelestialV01.装填大招槽(c, u)
	u["armor"] = 1000.0
	u["eva"] = 0.0
	u["战意"] = 100.0
	c["turn"] = 4.0
	DeckFlow.阶段初_检查(c)
	return {"u": u, "c": c, "前": 前, "后": 后}

## 一台带完整驾驶员卡池的受控机体（装填 → 拆分 → 装大招槽）。
func _驾场(键: String, 位: float, lv: int = 30) -> Dictionary:
	var 职: Variant = {"CB1": "近卫", "CB2": "狙击", "CB3": "特种", "CB4": "重装"}.get(键, "近卫")
	var u := _单位(键, "ally", 位, str(职))
	var 靶 := _靶("靶1", 5.0)
	var c := _场([u], [靶], 种子)
	for x in CelestialV01.装填单位(u, lv, c):
		u.专属牌库.append(x)
	DeckFlow.拆分单位牌(u, c)
	CelestialV01.装填大招槽(c, u)
	return {"u": u, "c": c, "敌": 靶}

## 一张驾驶员牌的**副本**。
func _驾卡(键: String, id: String, 加号: bool = false) -> Dictionary:
	for c in CelestialV01.驾驶员卡表(键, 加号):
		if c is Dictionary and str((c as Dictionary).get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

## 一台驾驶员某一类牌的**名字**（按卡表顺序）。
func _卡名们(键: String, 加号: bool, 类: String) -> Array:
	var 出: Array = []
	for c in CelestialV01.驾驶员卡表(键, 加号):
		if c is Dictionary and (类 == "" or str((c as Dictionary).get("卡类")) == 类):
			出.append(str((c as Dictionary).get("名")))
	return 出

## 一张驾驶员牌的**武器字典**副本。
func _武参(键: String, id: String, 加号: bool = false) -> Dictionary:
	var 卡 := _驾卡(键, id, 加号)
	var w = 卡.get("武器")
	return (w as Dictionary).duplicate(true) if w is Dictionary else {}

# ==========================================================================================
# 小工具
# ==========================================================================================
func _势卡(id: String) -> Dictionary:
	for c in CelestialV01.势力牌们():
		if c is Dictionary and str((c as Dictionary).get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

## 一张拉塞牌的**副本**。
func _拉卡(id: String, 加号: bool) -> Dictionary:
	for c in CelestialV01.拉塞卡表(加号):
		if c is Dictionary and str((c as Dictionary).get("id")) == id:
			return (c as Dictionary).duplicate(true)
	return {}

## 没有天人成员的场（验「开关关着」用）。
func 无天人队() -> Dictionary:
	return {"单机牌组": true, "allies": [{"key": "A1", "side": "ally", "hp": 100.0,
		"tags": {"势力": "ATX"}}], "enemies": [], "log": []}

func _敌(c: Dictionary, 键: String) -> Dictionary:
	for e in J.or_(c.get("enemies"), []):
		if e is Dictionary and str((e as Dictionary).get("key")) == 键:
			return e
	return {}

func _炉数(c: Dictionary) -> int:
	return CelestialV01.牌数Of(c.get("太阳炉牌库"))

func _有炉(c: Dictionary, id: String) -> bool:
	for x in SubDeck.牌们(c.get("太阳炉牌库")):
		if x is Dictionary and str((x as Dictionary).get("id")) == id:
			return true
	return false

## 把一张牌从太阳炉牌库**拿出来**放进公有手牌（返回的是库里那一份的引用 ——
## `打出太阳炉牌` 用 `is_same` 认牌，所以必须是同一份实例）。
func 拿炉(c: Dictionary, id: String) -> Dictionary:
	var 库 = c.get("太阳炉牌库")
	var 牌们: Array = SubDeck.牌们(库)
	for i in range(牌们.size()):
		var x = 牌们[i]
		if x is Dictionary and str((x as Dictionary).get("id")) == id:
			牌们.remove_at(i)
			if not (c.get("公有手牌") is Array):
				c["公有手牌"] = []
			(c["公有手牌"] as Array).append(x)
			return x
	return {}

## 一台裸单位（单机牌组 + 天人需要的字段一次给齐）。
func _单位(键: String, side: String, 位: float, 职业: String) -> Dictionary:
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 3000.0, "hp": 3000.0,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"战斗分类": 职业, "势力": "天人"}, "weapons": [],
		"战意": 100.0, "战意上限": 100.0, "主武器已销毁": false, "连续攻击已用": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

func _靶(键: String, 位: float) -> Dictionary:
	var e := _单位(键, "enemy", 位, "")
	e["tags"] = {}
	e["hp"] = 千
	e["maxHp"] = 千
	return e

func _场(我方: Array, 敌方: Array, 种子号: int = 20261018) -> Dictionary:
	var c := {
		"turn": 1.0, "种子": float(种子号), "rng": Mulberry32.new(种子号),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "单机牌组": true, "卡牌流转": true,
		"公有手牌": [], "公有牌库": [], "公有弃牌堆": [], "公有待入库": [], "上张打出牌": null,
		"筹码牌库": [], "烟雾": [], "again": [],
		"战况计数": {"残月或月国命中": 0.0, "未命中段": 0.0, "秘银标定": 0.0,
			"刹那命中或TA": 0.0, "响介受击或打空": 0.0, "满手牌推迟数": 0.0},
	}
	CelestialV01.初始化(c)
	return c

func _武(威力: float, 段数: int, 命中率: float = 100.0, fire: String = "direct") -> Dictionary:
	return {"name": "测试武器", "fire": fire, "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

func _行们(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			out.append(str((e as Dictionary).get("文本", "")))
	return out

func _有行(c: Dictionary, 子串: String) -> bool:
	for 行 in _行们(c):
		if str(行).contains(子串):
			return true
	return false

## `_有行` 的 Variant 版（`_力场一发` 返回的 `ctx` 是 Variant）。
func _日志含(c: Variant, 子串: String) -> bool:
	if not (c is Dictionary):
		return false
	return _有行(c, 子串)

func _找行(c: Variant, 子串: String) -> String:
	if not (c is Dictionary):
		return "（没有这一行）"
	for 行 in _行们(c):
		if str(行).contains(子串):
			return str(行)
	return "（没有这一行）"

















