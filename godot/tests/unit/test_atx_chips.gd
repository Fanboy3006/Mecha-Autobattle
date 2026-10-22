## ★ A3b：ATX「筹码牌库」10 张牌 + 【赌局】触发管线 + 「放入 X」—— 内核验收。
##
## 规格（唯一真源）：`协作/设计/ATX势力卡牌设计 v0.3.md` §1 / §2；任务单 A3b。
## 受控单位（不走 `Setup.开局`，直接造裸字典 + `AtxChips.初始化`），
## 这样「库里有几张 / 抽出哪张 / 随机数掷了几次」全都能逐字对账。
##
## 12 段（与任务单的 12 条断言一一对应）：
##   ① 开场 4 张全是小筹码（大 0 / 头奖 0）② 满 6 手不抽（随机数 0 次）③ 未满抽 1 张（库 4→3）
##   ④ 闪字不亮 → 什么都不发生 ⑤ 放入大筹码（4→5→6，不限次）⑥ 放入头奖（第二次被断路器 1 拦下）
##   ⑦ 打出归库 / 头奖移出本场 ⑧ 打出筹码牌不置 `主武器已销毁` ⑨ 梭哈清冷却 / 大满贯再动受断路器 3
##   ⑩ 【赌局】真的会触发（库 4 → 3、随机数 1 次） ⑪ 同种子两遍逐字相同 ⑫ 默认字段名仍成立
## 另外补 4 段（牌面数值 / 一次攻击一条记录 / 经 `Btl` 真实打出牌的钩子 / 非 ATX 成员打不了）。
extends RefCounted

const 千 := 999999.0
const 种子 := 20261022

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	t.ok(AtxChips.卡表().size() == 10 and AtxChips.全部ID.size() == 10,
		"★ 筹码牌一共 10 张（小 4 / 大 4 / 头奖 2）：%d 张" % AtxChips.卡表().size())
	_段1_开场(t)
	_段2_满手不抽(t)
	_段3_未满抽一张(t)
	_段4_闪不亮(t)
	_段5_放入大筹码(t)
	_段6_放入头奖断路器(t)
	_段7_打出归库(t)
	_段8_不占武器(t)
	_段9_头奖两张(t)
	_段10_赌局真触发(t)
	_段11_同种子两遍(t)
	_段12_字段名(t)
	_补1_牌面数值(t)
	_补2_一次攻击一条记录(t)
	_补3_经Btl打出钩子(t)
	_补4_非ATX打不了(t)
	_段13_实战打出筹码牌(t)

# ==========================================================================================
# ① 开场：`ctx.筹码牌库` 正好 4 张、全是等级 1；大筹码 0、头奖 0
# ==========================================================================================
func _段1_开场(t) -> void:
	var c := _场([_单位("A1", 0.0), _单位("A2", 4.0)], [_靶()])
	var 库: Array = c.get("筹码牌库")
	t.ok(库 is Array and 库.size() == 4, "① 开场 `ctx.筹码牌库` 正好 %d 张" % (库 as Array).size())
	var 全一 := true
	var 名们: Array = []
	var id们: Array = []
	for 卡 in 库:
		名们.append(str(卡.get("名", "")))
		id们.append(str(卡.get("id", "")))
		if AtxChips.等级(卡) != 1:
			全一 = false
	t.ok(全一, "① 4 张全是等级 1（小筹码）：%s" % "、".join(名们))
	t.ok(JSON.stringify(名们) == JSON.stringify(["一枚硬币", "侥幸", "冷枪", "换牌"]),
		"① 开场就是这 4 张小筹码（顺序 = 设计稿 §2 小筹码表）：%s" % JSON.stringify(id们))
	var 计 := AtxChips.筹码牌库张数(c)
	t.ok(int(计["小"]) == 4 and int(计["大"]) == 0 and int(计["头奖"]) == 0,
		"① 预告读口 `筹码牌库张数` = 小 %d / 大 %d / 头奖 %d；大筹码与头奖**不入场**" % [
			int(计["小"]), int(计["大"]), int(计["头奖"])])
	t.ok(AtxChips.赌局触发次数(c) == 0 and AtxChips.赌局放入次数(c) == 0,
		"① 结算读口开场都是 0（赌局触发 0 / 放入 0）")

# ==========================================================================================
# ② 满 6 手：带【赌局】的卡打出且闪字亮 → **不抽**，库仍 4 张、手牌仍 6、`ctx.rng` 步数 0
# ==========================================================================================
func _段2_满手不抽(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	for i in 6:
		(c["公有手牌"] as Array).append(_填空牌(i))
	var r := AtxChips.触发赌局(c, u, _赌局卡())
	t.ok(J.truthy(r.get("触发")), "② 闪字亮着 → 管线认了这次【赌局】（触发 = %s）" % str(r.get("触发")))
	t.ok((c["筹码牌库"] as Array).size() == 4 and (c["公有手牌"] as Array).size() == 6,
		"② 满 6 手 → **不抽**：库仍 %d 张、手牌仍 %d 张" % [
			(c["筹码牌库"] as Array).size(), (c["公有手牌"] as Array).size()])
	t.ok(int((c["rng"] as Mulberry32).steps) == 0,
		"② 满 6 手时 `ctx.rng` 一步都没走（steps = %d）" % int((c["rng"] as Mulberry32).steps))
	t.ok(str(r.get("抽到", "")) == "" and _行们(c).any(func(x): return str(x).contains("公有手牌已满")),
		"② 那一行记录明写「公有手牌已满」：%s" % _最后一行(c))

# ==========================================================================================
# ③ 未满手 + 闪字亮 → 抽 1 张，库 4→3、手牌 +1（贴种子与抽到的卡 id）
# ==========================================================================================
func _段3_未满抽一张(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	(c["公有手牌"] as Array).append(_填空牌(0))
	var 前 := (c["筹码牌库"] as Array).size()
	var r := AtxChips.触发赌局(c, u, _赌局卡())
	var 抽到: String = str(r.get("抽到", ""))
	t.ok(not 抽到.is_empty() and (c["筹码牌库"] as Array).size() == 前 - 1
			and (c["公有手牌"] as Array).size() == 2,
		"③ 未满（1/6）→ 抽 1 张：库 %d → %d、手牌 1 → %d（种子 %d、抽到的卡 id = %s、名 = %s）" % [
			前, (c["筹码牌库"] as Array).size(), (c["公有手牌"] as Array).size(), 种子, 抽到,
			str(AtxChips.卡(抽到).get("名", ""))])
	t.ok(int((c["rng"] as Mulberry32).steps) == 1,
		"③ 只掷 1 次随机数（steps = %d）" % int((c["rng"] as Mulberry32).steps))
	t.ok(AtxChips.赌局触发次数(c) == 1 and AtxChips.赌局放入次数(c) == 0,
		"③ 结算读口：赌局触发 %d 次 / 放入 %d 次（这张牌没写「放入」）" % [
			AtxChips.赌局触发次数(c), AtxChips.赌局放入次数(c)])
	t.ok(_最后一行(c).contains("抽到「%s」" % str(AtxChips.卡(抽到).get("名", ""))),
		"③ 即时记录：%s" % _最后一行(c))

# ==========================================================================================
# ④ 闪字**不亮** → 不抽（库 4 张不变）、不报错
# ==========================================================================================
func _段4_闪不亮(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]           # 没有 `闪` 键
	var r := AtxChips.触发赌局(c, u, _赌局卡())
	t.ok(not J.truthy(r.get("触发")) and str(r.get("原因", "")).contains("没亮闪字"),
		"④ 没亮闪字 → 管线不触发（原因：%s；不报错、没有 push_error）" % str(r.get("原因", "")))
	t.ok((c["筹码牌库"] as Array).size() == 4 and (c["公有手牌"] as Array).size() == 0
			and int((c["rng"] as Mulberry32).steps) == 0,
		"④ 库仍是 %d 张、手牌 %d 张、随机数 %d 次（什么都不发生）" % [
			(c["筹码牌库"] as Array).size(), (c["公有手牌"] as Array).size(),
			int((c["rng"] as Mulberry32).steps)])
	t.ok(_行们(c).is_empty(), "④ 一行 〔赌局〕 记录都不写（记录条数 = %d）" % _行们(c).size())

# ==========================================================================================
# ⑤ `放入` 大筹码：库 4→5，等级 2；**可重复放入**（连放两次 → 库 6）
# ==========================================================================================
func _段5_放入大筹码(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var 库: Array = c["筹码牌库"]
	var 卡 := AtxChips.卡("ATX_CHIP_RESPIN")
	t.ok(AtxChips.等级(卡) == 2 and str(卡.get("名", "")) == "再转一轮",
		"⑤ 放的是大筹码【%s】（筹码等级 %d）" % [str(卡.get("名", "")), AtxChips.等级(卡)])
	var 一 := SubDeck.放入(库, 卡, c["已放入头奖"], str(卡.get("id", "")), AtxChips.等级键, SubDeck.移出下限)
	t.ok(一 and 库.size() == 5 and AtxChips.等级(库[库.size() - 1]) == 2,
		"⑤ 放入大筹码：库 4 → %d、最后一张的筹码等级 = %d" % [库.size(), AtxChips.等级(库[库.size() - 1])])
	var 二 := SubDeck.放入(库, AtxChips.卡("ATX_CHIP_RESPIN"), c["已放入头奖"], "ATX_CHIP_RESPIN",
		AtxChips.等级键, SubDeck.移出下限)
	t.ok(二 and 库.size() == 6 and not (c["已放入头奖"] as Dictionary).has("ATX_CHIP_RESPIN"),
		"⑤ **大筹码不限次**：连放两次 → 库 %d 张，而且不登记进「每种每场 1 次」的断路器集合" % 库.size())
	# 端到端：经【赌局】放入（先抽后放）——库 6 → 抽 −1 = 5 → 放入 +1 = 6
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	var r := AtxChips.触发赌局(c, u, _赌局卡("ATX_CHIP_GODDESS"))
	t.ok(str(r.get("放入", "")) == "ATX_CHIP_GODDESS" and AtxChips.赌局放入次数(c) == 1,
		"⑤ 端到端【赌局】放入「幸运女神」：放入次数 = %d、记录 = %s" % [AtxChips.赌局放入次数(c), _最后一行(c)])

# ==========================================================================================
# ⑥ `放入` 头奖：第一次 true；**第二次 false、库长度不变**（断路器 1）
# ==========================================================================================
func _段6_放入头奖断路器(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var 库: Array = c["筹码牌库"]
	var 梭哈 := AtxChips.卡("ATX_CHIP_SHOWHAND")
	var 一 := SubDeck.放入(库, 梭哈, c["已放入头奖"], "ATX_CHIP_SHOWHAND", AtxChips.等级键, SubDeck.移出下限)
	t.ok(一 and 库.size() == 5 and AtxChips.等级(库[库.size() - 1]) == 3,
		"⑥ 放入头奖【梭哈】第一次成功：库 4 → %d 张、等级 %d" % [库.size(), AtxChips.等级(库[库.size() - 1])])
	var 二 := SubDeck.放入(库, AtxChips.卡("ATX_CHIP_SHOWHAND"), c["已放入头奖"], "ATX_CHIP_SHOWHAND",
		AtxChips.等级键, SubDeck.移出下限)
	t.ok(not 二 and 库.size() == 5,
		"⑥ 同一个头奖第二次 → **被断路器 1 拦下**（返回 %s、库仍 %d 张）" % [str(二), 库.size()])
	var 三 := SubDeck.放入(库, AtxChips.卡("ATX_CHIP_SLAM"), c["已放入头奖"], "ATX_CHIP_SLAM",
		AtxChips.等级键, SubDeck.移出下限)
	t.ok(三 and 库.size() == 6,
		"⑥ 断路器按**每种**算：「梭哈」放过后「大满贯」照样能放（库 %d 张）" % 库.size())
	# 端到端：第二次【赌局】放入同一个头奖 → 记录里明写被挡
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	var r := AtxChips.触发赌局(c, u, _赌局卡("ATX_CHIP_SHOWHAND"))
	t.ok(str(r.get("放入", "")) == "" and str(r.get("原因", "")).contains("断路器 1"),
		"⑥ 端到端第二次放入【梭哈】→ 没放进去（原因：%s）" % str(r.get("原因", "")))
	t.ok(_最后一行(c).contains("每种每场限 1 次") and AtxChips.赌局放入次数(c) == 0,
		"⑥ 那一行记录：%s" % _最后一行(c))

# ==========================================================================================
# ⑦ 打出等级 1 / 2 → 回库（库张数先 −1 再 +1 = 不变）；打出等级 3 → 进 `ctx.移出牌`，库 −1 且不回
# ==========================================================================================
func _段7_打出归库(t) -> void:
	# ---- 等级 1：抽走 −1、打出回库 +1 → 回到 4 ----
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var 抽 := _抽指定(c, "ATX_CHIP_COIN")
	var 抽后 := (c["筹码牌库"] as Array).size()
	var r1 := AtxChips.打出筹码牌(c, "A1", 抽.get("id"))
	t.ok(J.truthy(r1.get("成功")) and 抽后 == 3 and (c["筹码牌库"] as Array).size() == 4
			and (c["移出牌"] as Array).is_empty(),
		"⑦ 等级 1【%s】打出 → 回库：库 4 抽走 → %d，打出 → %d（−1 再 +1 = 不变）、移出牌 0 张" % [
			str(抽.get("名", "")), 抽后, (c["筹码牌库"] as Array).size()])
	# ---- 等级 2：放进库 → 抽走 → 打出回库（总数回到含它的那个数）----
	var c2 := _场([_单位("A1", 0.0)], [_靶()])
	SubDeck.放入(c2["筹码牌库"], AtxChips.卡("ATX_CHIP_RESPIN"), c2["已放入头奖"], "ATX_CHIP_RESPIN",
		AtxChips.等级键, SubDeck.移出下限)
	var 有它 := (c2["筹码牌库"] as Array).size()
	var 抽2 := _抽指定(c2, "ATX_CHIP_RESPIN")
	var r2 := AtxChips.打出筹码牌(c2, "A1", 抽2.get("id"))
	t.ok(J.truthy(r2.get("成功")) and 有它 == 5 and (c2["筹码牌库"] as Array).size() == 5
			and (c2["移出牌"] as Array).is_empty() and AtxChips.等级(抽2) == 2,
		"⑦ 等级 2【%s】打出 → 回库：含它 %d 张、抓走 → %d、打出 → %d、移出牌 0 张" % [
			str(抽2.get("名", "")), 有它, 有它 - 1, (c2["筹码牌库"] as Array).size()])
	# ---- 等级 3（头奖）：打出 → 移出本场，库不回来 ----
	var c3 := _场([_单位("A1", 0.0)], [_靶()])
	SubDeck.放入(c3["筹码牌库"], AtxChips.卡("ATX_CHIP_SHOWHAND"), c3["已放入头奖"], "ATX_CHIP_SHOWHAND",
		AtxChips.等级键, SubDeck.移出下限)
	var 有3 := (c3["筹码牌库"] as Array).size()
	var 抽3 := _抽指定(c3, "ATX_CHIP_SHOWHAND")
	var r3 := AtxChips.打出筹码牌(c3, "A1", 抽3.get("id"))
	var 移出们: Array = c3["移出牌"]
	t.ok(str(r3.get("去处", "")) == "移出" and (c3["筹码牌库"] as Array).size() == 有3 - 1
			and 移出们.size() == 1 and str(移出们[0].get("名", "")) == "梭哈",
		"⑦ 等级 3【梭哈】打出 → 移出本场：含它 %d 张、抓走 → %d、打出后库仍 %d（**不回**）、`ctx.移出牌` = %s" % [
			有3, 有3 - 1, (c3["筹码牌库"] as Array).size(),
			str(移出们[0].get("名", "")) if not 移出们.is_empty() else "（空）"])
	t.ok(_行们(c3).any(func(x): return str(x).contains("头奖 → 移出本场")),
		"⑦ 即时记录里明写「头奖 → 移出本场」：%s" % _最后一行(c3))

# ==========================================================================================
# ⑧ 筹码牌打出后 `u.主武器已销毁` **不被置 true**（不占武器）
# ==========================================================================================
func _段8_不占武器(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]
	u["主武器已销毁"] = false
	var 抽 := SubDeck.抽一张(c["筹码牌库"], c["公有手牌"], 6, c["rng"])
	var r := AtxChips.打出筹码牌(c, "A1", 抽.get("id"))
	t.ok(J.truthy(r.get("成功")) and not J.truthy(u.get("主武器已销毁")),
		"⑧ 打出【%s】后 `u.主武器已销毁` = %s（不占武器）" % [
			str(抽.get("名", "")), str(u.get("主武器已销毁"))])
	var 卡 := AtxChips.卡("ATX_CHIP_SHOT")
	t.ok(J.num0(卡.get("费用")) == 0.0 and J.truthy(卡.get("is_atx_card"))
			and not J.truthy(卡.get("赌局")) and J.truthy(卡.get("不占武器")),
		"⑧ 牌面：费用 = %s、`is_atx_card` = %s、本身 `赌局` = %s、`不占武器` = %s" % [
			J.s(卡.get("费用")), str(卡.get("is_atx_card")), str(卡.get("赌局")), str(卡.get("不占武器"))])

# ==========================================================================================
# ⑨ 「梭哈」→ 全体 ATX 大招槽 cd 全变 0；「大满贯」→ 全体主武器恢复，且**绕过不了断路器 3**
# ==========================================================================================
func _段9_头奖两张(t) -> void:
	var a1 := _单位("A1", 0.0)
	var a2 := _单位("A2", 4.0)
	a1["大招槽"] = [_槽("切札", 3.0), _槽("左轮打桩机", 1.0)]
	a2["大招槽"] = [_槽("幻影凤凰", 2.0)]
	# ★ CB-0 断路器 2：v0.1 卡表大招的**真实冷却**在 `u.v01冷却` 字典里（`v01别名` 槽上的 cd 只是镜像）。
	#   梭哈必须把它一起清零 —— 只清槽等于没清。
	a1["v01冷却"] = {"V1_A1_U1": 3, "V1_A1_U2": 1}
	a2["v01冷却"] = {"V1_A2_U1": 2}
	# 本回合刚打过的那张：梭哈**不许**把「本回合已打」清掉（断路器 2 仍然拦第二次）
	(a1["大招槽"] as Array)[0]["本回合已打"] = true
	a1["主武器已销毁"] = true
	a2["主武器已销毁"] = true
	var c := _场([a1, a2], [_靶()])
	(c["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_SHOWHAND"))
	var r := AtxChips.打出筹码牌(c, "A1", "ATX_CHIP_SHOWHAND")
	var 全零 := true
	for u in c.allies:
		for 槽 in J.or_(u.get("大招槽"), []):
			if J.num0(槽.get("cd")) != 0.0:
				全零 = false
	t.ok(J.truthy(r.get("成功")) and 全零,
		"⑨ 打出【梭哈】→ ATX 全体大招槽 cd 全变 0（A1 两张、A2 一张都清零）")
	var 冷零 := true
	for u in c.allies:
		var 冷 = u.get("v01冷却")
		if 冷 is Dictionary:
			for k in (冷 as Dictionary).keys():
				if int(J.num0((冷 as Dictionary)[k])) != 0:
					冷零 = false
	t.ok(冷零, "⑨ ★ 断路器 2：`u.v01冷却`（v0.1 卡表大招的真实冷却）也一起清零：%s / %s" % [
		str(a1.get("v01冷却")), str(a2.get("v01冷却"))])
	t.ok(J.truthy((a1["大招槽"] as Array)[0].get("本回合已打")),
		"⑨ 梭哈**只清冷却、不清「本回合已打」**（本回合刚打过的那张仍打不出第二次 = 断路器 2）")
	# ---- 大满贯：全体主武器恢复 ----
	(c["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_SLAM"))
	var r2 := AtxChips.打出筹码牌(c, "A1", "ATX_CHIP_SLAM")
	t.ok(J.truthy(r2.get("成功")) and not J.truthy(a1.get("主武器已销毁"))
			and not J.truthy(a2.get("主武器已销毁"))
			and J.truthy(a1.get("本回合再动已用")) and J.truthy(a2.get("本回合再动已用")),
		"⑨ 打出【大满贯】→ 两台主武器全部恢复（已销毁 = %s / %s），并记上「本回合再动已用」" % [
			str(a1.get("主武器已销毁")), str(a2.get("主武器已销毁"))])
	# ---- 断路器 3：同一回合第二次再动被拦 ----
	a1["主武器已销毁"] = true
	a2["主武器已销毁"] = true
	(c["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_SLAM"))
	var r3 := AtxChips.打出筹码牌(c, "A1", "ATX_CHIP_SLAM")
	t.ok(J.truthy(r3.get("成功")) and J.truthy(a1.get("主武器已销毁")) and J.truthy(a2.get("主武器已销毁")),
		"⑨ 同一回合第二次【大满贯】→ **绕过不了断路器 3**（每台每回合 1 次）：主武器仍是已销毁 = %s / %s" % [
			str(a1.get("主武器已销毁")), str(a2.get("主武器已销毁"))])
	var 拦行: Array = _行们(c).filter(func(x): return str(x).contains("断路器 3"))
	t.ok(not 拦行.is_empty(), "⑨ 记录里明写「〔断路器 3〕」：%s" % (拦行[0] if not 拦行.is_empty() else "（没有）"))
	# ---- 阶段初：额度回来了（下一回合又能各再动 1 次）----
	AtxChips.阶段初(c)
	t.ok(not J.truthy(a1.get("本回合再动已用")) and not J.truthy(a2.get("本回合再动已用")),
		"⑨ `AtxChips.阶段初` 后「本回合再动已用」归零（下个我方回合的额度回来了）")

# ==========================================================================================
# ⑩ 【赌局】真的会触发：库 4 → 3、随机数 1 次
# ==========================================================================================
func _段10_赌局真触发(t) -> void:
	var 开场 := _裸场([_单位("A1", 0.0)], [_靶()])
	(开场.allies[0] as Dictionary)["闪"] = true
	AtxChips.初始化(开场)
	var r3 := AtxChips.触发赌局(开场, 开场.allies[0], _赌局卡())
	t.ok(J.truthy(r3.get("触发")) and (开场["筹码牌库"] as Array).size() == 3
			and int((开场["rng"] as Mulberry32).steps) == 1,
		"⑩ 触发【赌局】→ 库 4 → %d、随机数 %d 次" % [
			(开场["筹码牌库"] as Array).size(), int((开场["rng"] as Mulberry32).steps)])
# ==========================================================================================
# ⑪ 同种子两遍：抽取序列、记录文本、库张数全部逐字相同
# ==========================================================================================
func _段11_同种子两遍(t) -> void:
	var 一 := _跑赌局场景()
	var 二 := _跑赌局场景()
	t.ok(JSON.stringify(一.抽取) == JSON.stringify(二.抽取) and 一.抽取.size() == 2,
		"⑪ 同种子两遍抽取序列逐字相同：%s" % JSON.stringify(一.抽取))
	t.ok(一.记录 == 二.记录 and not 一.记录.is_empty(),
		"⑪ 记录文本逐字相同（%d 行）：%s" % [一.记录.size(), 一.记录[0]])
	t.ok(JSON.stringify(一.张数) == JSON.stringify(二.张数) and JSON.stringify(一.张数) == JSON.stringify(二.张数),
		"⑪ 库张数逐字相同：%s" % JSON.stringify(一.张数))
	t.ok(一.触发 == 2 and 一.放入 == 2 and JSON.stringify(一.张数) == JSON.stringify(二.张数),
		"⑪ 两次【赌局】都触发、各放入 1 张（大筹码 1 + 头奖 1 = 放入 %d）：触发 %d / 放入 %d" % [一.放入, 一.触发, 一.放入])

func _跑赌局场景() -> Dictionary:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	var 抽取: Array = []
	var r1 := AtxChips.触发赌局(c, u, _赌局卡("ATX_CHIP_RESPIN"))
	抽取.append(str(r1.get("抽到", "")))
	var r2 := AtxChips.触发赌局(c, u, _赌局卡("ATX_CHIP_SHOWHAND"))
	抽取.append(str(r2.get("抽到", "")))
	return {"抽取": 抽取, "记录": _行们(c), "张数": AtxChips.筹码牌库张数(c),
		"触发": AtxChips.赌局触发次数(c), "放入": AtxChips.赌局放入次数(c)}

# ==========================================================================================
# ⑫ `SubDeck.默认等级键 == "连携等级"`（顺手修完那条可读性债后仍成立）
# ==========================================================================================
func _段12_字段名(t) -> void:
	t.ok(SubDeck.默认等级键 == "连携等级" and SubDeck.默认回库键 == "回库",
		"⑫ 默认字段名换回字面中文后仍是卡表 schema：%s / %s" % [SubDeck.默认等级键, SubDeck.默认回库键])
	var 卡 := AtxChips.卡("ATX_CHIP_SHOT")
	t.ok(AtxChips.等级(卡) == 1 and int(卡.get("筹码等级", 0)) == 1,
		"⑫ 筹码牌用 `筹码等级` 这个字段（int）：%s 的筹码等级 = %d" % [str(卡.get("名", "")), int(卡.get("筹码等级", 0))])

# ==========================================================================================
# 补 1：10 张牌的数值逐条对设计稿 §2（一个数都不许改）
# ==========================================================================================
func _补1_牌面数值(t) -> void:
	var 期 := {
		"ATX_CHIP_COIN": [1, "一枚硬币"], "ATX_CHIP_LUCK": [1, "侥幸"],
		"ATX_CHIP_SHOT": [1, "冷枪"], "ATX_CHIP_SWAP": [1, "换牌"],
		"ATX_CHIP_RESPIN": [2, "再转一轮"], "ATX_CHIP_GODDESS": [2, "幸运女神"],
		"ATX_CHIP_ESCAPE": [2, "死里逃生"], "ATX_CHIP_DEALER": [2, "庄家通吃"],
		"ATX_CHIP_SHOWHAND": [3, "梭哈"], "ATX_CHIP_SLAM": [3, "大满贯"],
	}
	var 错: Array = []
	for id in 期.keys():
		var 卡 := AtxChips.卡(id)
		if 卡.is_empty() or AtxChips.等级(卡) != int(期[id][0]) or str(卡.get("名", "")) != str(期[id][1]):
			错.append(id)
	t.ok(错.is_empty(), "补① 10 张牌的 id / 名 / 档位全对（错：%s）" % str(错))
	var 冷 := AtxChips.卡("ATX_CHIP_SHOT")
	t.ok(J.num0(冷.get("威力")) == 300.0 and int(冷.get("段数", 0)) == 4
			and J.num0(冷.get("命中")) == 70.0 and J.truthy(冷.get("无视距离")),
		"补① 冷枪 = 直射·物理 300 × 4 段 · 每段命中 70 · 无视距离")
	t.ok(J.num0(AtxChips.卡("ATX_CHIP_COIN").get("战意加")) == 8.0
			and J.num0(AtxChips.卡("ATX_CHIP_LUCK").get("闪避加")) == 15.0
			and J.num0(AtxChips.卡("ATX_CHIP_RESPIN").get("冷却减")) == 2.0,
		"补① 一枚硬币 战意 +8 / 侥幸 闪避 +15 / 再转一轮 冷却 −2")
	var 幸 := AtxChips.卡("ATX_CHIP_GODDESS")
	t.ok(J.num0(幸.get("暴击加")) == 20.0 and J.num0(幸.get("首闪加")) == 20.0
			and J.num0(AtxChips.卡("ATX_CHIP_ESCAPE").get("保留HP")) == 1.0
			and J.num0(AtxChips.卡("ATX_CHIP_DEALER").get("反伤")) == 600.0,
		"补① 幸运女神 暴击 +20 / 首闪 +20 · 死里逃生 保留 1 HP · 庄家通吃 反伤 600")
	var 放对 := str(AtxChips.卡("ATX_CHIP_RESPIN").get("放入者")) == "左轮打桩机·全弹" \
		and str(AtxChips.卡("ATX_CHIP_GODDESS").get("放入者")) == "好运加护·满开" \
		and str(AtxChips.卡("ATX_CHIP_ESCAPE").get("放入者")) == "幻影凤凰" \
		and str(AtxChips.卡("ATX_CHIP_DEALER").get("放入者")) == "二次下注" \
		and str(AtxChips.卡("ATX_CHIP_SHOWHAND").get("放入者")) == "切札" \
		and str(AtxChips.卡("ATX_CHIP_SLAM").get("放入者")) == "轮盘双响"
	t.ok(放对, "补① 6 张大筹码 / 头奖的「由谁放入」都记在卡上（供 A4 / A6 接）")

# ==========================================================================================
# 补 2：冷枪 = **一次攻击一条记录**（4 段不许逐段写行）
# ==========================================================================================
func _补2_一次攻击一条记录(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	(c["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_SHOT"))
	var r := AtxChips.打出筹码牌(c, "A1", "ATX_CHIP_SHOT", "靶1")
	var 攻行: Array = _行们(c).filter(func(x): return str(x).contains("【冷枪】→"))
	t.ok(J.truthy(r.get("成功")) and 攻行.size() == 1,
		"补② 冷枪 4 段 → **只写 1 条攻击记录**（实际 %d 条）：%s" % [攻行.size(), 攻行[0] if not 攻行.is_empty() else "（没有）"])
	t.ok(not 攻行.is_empty() and str(攻行[0]).contains("段"),
		"补② 那一条记录里带段数：%s" % (攻行[0] if not 攻行.is_empty() else "（没有）"))
	t.ok(_行们(c).any(func(x): return str(x).contains("〔筹码牌〕") and str(x).contains("冷枪")),
		"补② 另外还有 1 条〔筹码牌〕总账记录（不是逐段）：%s" % _最后一行(c))

# ==========================================================================================
# 补 3：经 `Btl.打出精神或公有牌` 真实打出带【赌局】的牌 → 钩子真的接上了
# ==========================================================================================
func _补3_经Btl打出钩子(t) -> void:
	var c := _场([_单位("A1", 0.0)], [_靶()])
	var u: Dictionary = c.allies[0]
	u["闪"] = true
	var 牌 := _赌局卡("ATX_CHIP_RESPIN")
	牌["卡类"] = "公有牌"
	(c["公有手牌"] as Array).append(牌)
	var r := Btl.打出精神或公有牌(c, "A1", "T_赌局_1", null)
	t.ok(J.truthy(r.get("成功")), "补③ 经 `Btl.打出精神或公有牌` 打出一张带【赌局】的公有牌（成功 = %s）" % str(r.get("成功")))
	t.ok(AtxChips.赌局触发次数(c) == 1 and AtxChips.赌局放入次数(c) == 1,
		"补③ 钩子真的接上了：赌局触发 %d 次 / 放入 %d 次" % [
			AtxChips.赌局触发次数(c), AtxChips.赌局放入次数(c)])
	var 局行: Array = _行们(c).filter(func(x): return str(x).contains("〔赌局〕"))
	t.ok(not 局行.is_empty() and str(局行[0]).contains("〔赌局〕A1 已闪开"),
		"补③ 真实记录：%s" % (局行[0] if not 局行.is_empty() else "（没有）"))

# ==========================================================================================
# 补 4：非 ATX 成员打不了筹码牌
# ==========================================================================================
func _补4_非ATX打不了(t) -> void:
	var c := _场([_单位("M1", 0.0, "秘银")], [_靶()])
	(c["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_COIN"))
	var r := AtxChips.打出筹码牌(c, "M1", "ATX_CHIP_COIN")
	t.ok(not J.truthy(r.get("成功")) and str(r.get("原因", "")).contains("ATX"),
		"补④ 秘银成员打筹码牌 → 被拒（原因：%s）；库/手牌一个字节都不动（库 %d 张、手牌 %d 张）" % [
			str(r.get("原因", "")), (c["筹码牌库"] as Array).size(), (c["公有手牌"] as Array).size()])

# ==========================================================================================
# ⑬ ★★ 第 2 项断路器修复（DS41F）：**筹码牌从公有手牌打出去不再「空弹 + 进公有弃牌堆」**
##  1) `Btl.打出精神或公有牌` 端到端打小筹码「一枚硬币」「冷枪」与头奖「梭哈」「大满贯」；
##  2) 效果真的触发、小筹码回 `ctx.筹码牌库`、头奖进 `ctx.移出牌`、**绝不进 `公有弃牌堆`**；
##  3) `GameSession` 那条 UI 门面路（`play_unit_spirit_or_public_card`）同样打得出来。
# ==========================================================================================
func _段13_实战打出筹码牌(t) -> void:
	var c := _场([_单位("A1", 0.0), _单位("A2", 4.0)], [_靶()])
	var a1: Dictionary = c.allies[0]
	a1["战意"] = 20.0
	c["移出牌"] = []
	for id in ["ATX_CHIP_COIN", "ATX_CHIP_SHOT", "ATX_CHIP_SHOWHAND", "ATX_CHIP_SLAM"]:
		(c["公有手牌"] as Array).append(AtxChips.卡(id))
	var 库前: int = (c["筹码牌库"] as Array).size()
	# ---- ① 小筹码「一枚硬币」：战意 +8、回库、不进弃牌堆 ----
	var r1 := Btl.打出精神或公有牌(c, "A1", "ATX_CHIP_COIN", null)
	t.ok(J.truthy(r1.get("成功")), "⑬ 「一枚硬币」从公有手牌打出去了（%s）" % str(r1.get("原因", "成功")))
	t.ok(J.round(float(a1.get("战意"))) == 28.0,
		"⑬ ★ 效果真的触发：A1 战意 20 → %s（硬币 +8，不是空弹）" % J.s(a1.get("战意")))
	t.ok(str(r1.get("去处", "")) == "回库" and (c["筹码牌库"] as Array).size() == 库前 + 1,
		"⑬ 小筹码打完**回筹码牌库**（%d → %d 张，回库 +1）" % [库前, (c["筹码牌库"] as Array).size()])
	t.ok(not J.some(c["公有弃牌堆"], func(x): return str(x.get("id", "")) == "ATX_CHIP_COIN"),
		"⑬ ★ 绝不进 `公有弃牌堆`（弃牌堆 %d 张）" % (c["公有弃牌堆"] as Array).size())
	# ---- ② 小筹码「冷枪」：真的打一发攻击（不指定目标 → 默认第一台存活敌机）----
	var 靶: Dictionary = c.enemies[0]
	靶["hp"] = 千
	var r2 := Btl.打出精神或公有牌(c, "A1", "ATX_CHIP_SHOT", null)
	t.ok(J.truthy(r2.get("成功")), "⑬ 「冷枪」打出去了（%s）" % str(r2.get("原因", "成功")))
	var 攻行: Array = J.or_(c.get("log"), []).filter(func(e):
		return e is Dictionary and str(e.get("类型", "")) == "攻击" and str(e.get("武器", "")) == "冷枪")
	t.ok(攻行.size() == 1 and J.num0((攻行[0] as Dictionary).get("段数")) == 4.0,
		"⑬ ★ 冷枪真的打出 4 段攻击（攻击记录 %d 条、段数 %s）" % [
			攻行.size(), J.s(J.num0((攻行[0] as Dictionary).get("段数"))) if not 攻行.is_empty() else "?"])
	t.ok(float(靶.get("hp")) < 千, "⑬ 冷枪真的打到了**第一台存活敌机**（靶 HP 千 → %s）" % J.s(J.round(float(靶.get("hp")))))
	# ---- ③ 头奖「梭哈」「大满贯」：进 `ctx.移出牌`，不进弃牌堆 ----
	var r3 := Btl.打出精神或公有牌(c, "A1", "ATX_CHIP_SHOWHAND", null)
	var r4 := Btl.打出精神或公有牌(c, "A1", "ATX_CHIP_SLAM", null)
	t.ok(J.truthy(r3.get("成功")) and J.truthy(r4.get("成功")),
		"⑬ 头奖「梭哈」「大满贯」都打得出去（%s / %s）" % [str(r3.get("原因", "成功")), str(r4.get("原因", "成功"))])
	var 移出id: Array = J.or_(c.get("移出牌"), []).map(func(x): return str((x as Dictionary).get("id", "")))
	t.ok(J.inc(移出id, "ATX_CHIP_SHOWHAND") and J.inc(移出id, "ATX_CHIP_SLAM"),
		"⑬ ★ 两张头奖都进 `ctx.移出牌`（%s）" % str(移出id))
	t.ok(not J.some(c["公有弃牌堆"], func(x): return ["ATX_CHIP_SHOWHAND", "ATX_CHIP_SLAM"].has(str(x.get("id", "")))),
		"⑬ ★ 头奖**绝不进** `公有弃牌堆`（弃牌堆 %d 张）" % (c["公有弃牌堆"] as Array).size())
	t.ok(J.num0(a1.get("主武器已销毁")) == 0.0, "⑬ 筹码牌不占武器：`主武器已销毁` 仍为 false")
	# ---- ④ GameSession 门面那条路（UI 点牌走的就是它）----
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_chip_实战.json"
	if not s.开始快速测试战斗(GameSession.快速测试_ATX, 种子):
		t.ok(false, "⑬ GameSession：ATX 五人快速测试战开不起来")
		return
	var ctx: Dictionary = s.battle_ctx
	var 主: Dictionary = {}
	for x in (ctx.get("allies") as Array):
		if x is Dictionary and str((x as Dictionary).get("key", "")) == "A1":
			主 = x
	if 主.is_empty():
		t.ok(false, "⑬ GameSession：场上找不到 A1")
		return
	(ctx["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_COIN"))
	主["战意"] = 30.0
	var 手前: int = (ctx["公有手牌"] as Array).size()
	var r5 := s.play_unit_spirit_or_public_card("ATX_CHIP_COIN")
	t.ok(bool(r5.get("ok", false)),
		"⑬ ★★ `GameSession.play_unit_spirit_or_public_card(ATX_CHIP_COIN)` 真的打出去了（%s）" % str(r5.get("为什么", "ok")))
	t.ok(J.round(Btl.战意(主)) == 38.0,
		"⑬ ★★ 门面那条路也真的触发效果：A1 战意 30 → %s" % J.s(Btl.战意(主)))
	t.ok((ctx["公有手牌"] as Array).size() == 手前 - 1
		and not J.some(ctx["公有弃牌堆"], func(x): return str(x.get("id", "")) == "ATX_CHIP_COIN"),
		"⑬ 门面：牌离手（%d → %d）且没进公有弃牌堆（%d 张）" % [
			手前, (ctx["公有手牌"] as Array).size(), (ctx["公有弃牌堆"] as Array).size()])
	# 下排视图也认得它（`区 = 筹码牌`，0 费，能打）
	(ctx["公有手牌"] as Array).append(AtxChips.卡("ATX_CHIP_SHOT"))
	var 下 := s.lower_hand_cards()
	var 筹卡 := {}
	for x in 下:
		if x is Dictionary and str((x as Dictionary).get("id", "")) == "ATX_CHIP_SHOT":
			筹卡 = x
	t.ok(str(筹卡.get("区", "")) == "筹码牌" and bool(筹卡.get("可打", false))
		and float(筹卡.get("战意", -1.0)) == 0.0,
		"⑬ 下排视图：筹码「冷枪」= 区 `筹码牌` / 0 费 / 可打（区=%s 费=%s 可打=%s）" % [
			str(筹卡.get("区", "?")), J.s(筹卡.get("战意")), str(筹卡.get("可打"))])

# ==========================================================================================
# 小工具
# ==========================================================================================
func _赌局卡(放入: String = "") -> Dictionary:
	var d := {"id": "T_赌局_1", "名": "测试赌局", "赌局": true, "放入": null,
		"归属": "ATX", "层级": "势力", "卡类": "公有牌", "种类": "势力", "耗气": 0.0, "费用": 0.0,
		"效果": [], "效果说明": ""}
	if 放入 != "":
		d["放入"] = 放入
	return d

func _填空牌(i: int) -> Dictionary:
	return {"id": "T_FILL_%d" % i, "名": "填充牌%d" % i, "卡类": "公有牌", "耗气": 0.0,
		"层级": "势力", "归属": "ATX", "效果": [], "效果说明": ""}

func _行们(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			out.append(str((e as Dictionary).get("文本", "")))
	return out

func _最后一行(c: Dictionary) -> String:
	var 行 := _行们(c)
	return str(行[行.size() - 1]) if not 行.is_empty() else "（一行都没有）"

func _槽(牌名: String, cd: float) -> Dictionary:
	return {"cd": cd, "cd_max": maxf(cd, 6.0), "卡": {"名": 牌名, "id": "T_%s" % 牌名},
		"已解锁": true, "实时门槛满足": true, "本回合已打": false}

func _靶() -> Dictionary:
	var e := _单位("靶1", 4.0, "")
	e["side"] = "enemy"
	return e

## 手工把库里的某一张拿到公有手牌（只测「打出之后的去处」，不测抽取随机 —— 抽取那一段在 ③ / ⑪ 里）。
func _抽指定(c: Dictionary, id: String) -> Dictionary:
	var 库: Array = c["筹码牌库"]
	for i in 库.size():
		if str((库[i] as Dictionary).get("id", "")) == id:
			var 卡: Dictionary = 库[i]
			库.remove_at(i)
			(c["公有手牌"] as Array).append(卡)
			return 卡
	return {}

## 一台裸单位：单机牌组需要的字段一次给齐（`AtxChips` / `Calc` 都直接吃这一份）。
func _单位(键: String, 位: float, 势力: String = "ATX") -> Dictionary:
	return {
		"key": 键, "name": 键, "side": "ally", "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 100.0, "shoot": 100.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": ({"势力": 势力} if 势力 != "" else {}), "weapons": [],
		"战意": 0.0, "战意上限": 100.0, "主武器已销毁": false,
		"专属手牌": [], "专属牌库": [], "专属弃牌堆": [], "衍生手牌": [],
		"大招槽": [], "武器栏": [], "副武器栏": [], "待入库": [],
	}

## 一场「筹码牌库开着」的受控战斗（`ctx.单机牌组 = true` 就是 `Params.单机牌组_开` 的那一把开关）。
func _场(我方: Array, 敌: Array, 场种子: int = 种子) -> Dictionary:
	var c := _裸场(我方, 敌, 场种子)
	c["单机牌组"] = true
	AtxChips.初始化(c)
	return c

## 同上一场，但**不**打开开关（「改前」口径）。
func _裸场(我方: Array, 敌: Array, 场种子: int = 种子) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(场种子), "rng": Mulberry32.new(场种子),
		"allies": 我方, "enemies": 敌, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0, "阶段": "PLAYER_MAIN",
		"公有牌库": [], "公有手牌": [], "公有弃牌堆": [], "移出牌": [],
	}
