## ★ A4（响介 v0.3「赌神」+ 艾克赛琳【强运】）—— 内核验收。
##
## 权威依据：`协作/设计/响介卡牌设计 v0.1.md` §1/§2 · `协作/设计/艾克赛琳卡牌设计 v0.1.md`（【强运】）
##          · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A4 行
##
## 受控单位（不走 `Setup.开局`，直接造裸字典）：攻击方 `aim = 160`、目标 `eva` 可控 →
##   命中率 = `w.hit − eva`。所以「12 段里中几段」完全由种子决定（`_找种子()`，与 `resolveAttack`
##   的抽数顺序逐字一致：每段先抽命中、中了再抽一次暴击）。
## 本文件跑完会把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_上一把输了(t)
	_段2_入局门槛(t)
	_段3_入局不算武器(t)
	_段4_命中减十(t)
	_段5_翻盘(t)
	_段6_续注(t)
	_段7_关闭后不可打(t)
	_段8_概率覆盖(t)
	_段9_强运硬币(t)
	_段10_强运不留状态(t)
	_段11_旧机制停用(t)
	_段13_同种子两遍(t)
	_段14_三层反馈(t)

# ==========================================================================================
# ① 「上一把输了」：`打空 >= 命中` 且 `打空 + 命中 >= 1`（敌我都算 / 跨阶段保留）
# ==========================================================================================
func _段1_上一把输了(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	var 表 := [
		[5, 4, true, "打空 5 ≥ 命中 4"],
		[4, 5, false, "打空 4 < 命中 5"],
		[6, 6, true, "平手也算输（6 ≥ 6）"],
		[0, 0, false, "0/0 不算一次攻击"],
		[12, 0, true, "全空"],
		[0, 12, false, "全中"],
	]
	for 行 in 表:
		var 空: int = int(行[0])
		var 中: int = int(行[1])
		AtxGodsbet.记上一次攻击(c, a1, 靶, {"命中段": 中, "打空段": 空})
		t.ok(AtxGodsbet.上一把输了(c) == bool(行[2]),
			"① 上一次攻击 打空 %d / 命中 %d → 上一把输了 = %s（%s）" % [空, 中, str(AtxGodsbet.上一把输了(c)), str(行[3])])
	# 真实 12 段攻击（命中率 50%，用种子精确造出「打空 8 / 命中 4」与「打空 4 / 命中 8」）
	var 种子4 := _找种子(4)
	var c2 := _新场([a1], [靶], 种子4)
	Calc.resolveAttack(a1, 靶, _武(10.0, 12), c2, {})
	t.ok(AtxGodsbet.上一把输了(c2) and int(AtxGodsbet.上一次攻击(c2).get("打空段")) == 8,
		"① 真打一发：12 段里**打空 8 / 命中 4** → 真（种子 %d、账 = %s）" % [种子4, str(AtxGodsbet.上一次攻击(c2))])
	var c3 := _新场([a1], [靶], _找种子(8))
	Calc.resolveAttack(a1, 靶, _武(10.0, 12), c3, {})
	t.ok(not AtxGodsbet.上一把输了(c3) and int(AtxGodsbet.上一次攻击(c3).get("打空段")) == 4,
		"① 真打一发：12 段里**打空 4 / 命中 8** → 假（账 = %s）" % str(AtxGodsbet.上一次攻击(c3)))
	# ---- 跨阶段保留：敌方阶段打完 → 进入我方阶段仍为真，直到下一次攻击覆盖 ----
	var c4 := Setup.开局([{"键": "A1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261017, null, {"单机牌组": true})
	if (c4.get("allies") as Array).is_empty() or (c4.get("enemies") as Array).is_empty():
		t.ok(false, "① 开局失败（造不出 A1 的战场）")
		return
	var 甲: Dictionary = c4.allies[0]
	var 敌: Dictionary = c4.enemies[0]
	Calc.resolveAttack(敌, 甲, _武(10.0, 4, "direct", {}, 0.0), c4, {})
	t.ok(AtxGodsbet.上一把输了(c4),
		"① 敌方阶段打空 4 段 → 上一把输了 = 真（账 = %s）" % str(AtxGodsbet.上一次攻击(c4)))
	Btl.开始我方阶段(c4)
	t.ok(AtxGodsbet.上一把输了(c4) and int(AtxGodsbet.上一次攻击(c4).get("打空段")) == 4,
		"① **跨阶段保留**：进入下一个我方阶段仍为真（账没被清 = %s）" % str(AtxGodsbet.上一次攻击(c4)))
	Calc.resolveAttack(甲, 敌, _武(10.0, 2, "direct", {}, 200.0), c4, {})
	t.ok(not AtxGodsbet.上一把输了(c4),
		"① 下一次攻击（命中 2 / 打空 0）把它覆盖 → 假（%s）" % str(AtxGodsbet.上一次攻击(c4)))

# ==========================================================================================
# ② 入局门槛三态：上一把没输 / 输了但战意 39 / 输了且战意 40
# ==========================================================================================
func _段2_入局门槛(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	t.ok(not AtxGodsbet.找入局槽(a1).is_empty(),
		"② 装填：响介的大招槽里有【%s】（cd = %s、is_weapon = %s）" % [
			AtxGodsbet.入局名, str(AtxGodsbet.找入局槽(a1).get("cd")), str(AtxGodsbet.找入局槽(a1).get("is_weapon"))])
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 5, "打空段": 2})
	t.ok(not AtxGodsbet.入局可用吗(c, a1) and AtxGodsbet.入局不可打原因(c, a1).contains("上一把没输"),
		"② 上一把没输（命中 5 > 打空 2）→ 不可入局：「%s」" % AtxGodsbet.入局不可打原因(c, a1))
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	a1["战意"] = 39.0
	t.ok(not AtxGodsbet.入局可用吗(c, a1) and AtxGodsbet.入局不可打原因(c, a1).contains("战意不够"),
		"② 输了但战意 39 → 不可入局：「%s」" % AtxGodsbet.入局不可打原因(c, a1))
	a1["战意"] = 40.0
	t.ok(AtxGodsbet.入局可用吗(c, a1),
		"② 输了且战意 40 → 可入局（原因 = 「%s」）" % AtxGodsbet.入局不可打原因(c, a1))
	# 预告层：`DeckFlow.大招不可打原因` 走同一个口子（卡牌流转开着时界面读的是它）
	var c2 := _新场([_响介(0.0, 40.0, "A1b")], [_靶(0.0)])
	c2["卡牌流转"] = true
	var a1b: Dictionary = c2.allies[0]
	a1b["key"] = "A1"
	a1b["tplKey"] = "A1"
	AtxGodsbet.装填大招槽(c2)
	t.ok(DeckFlow.大招不可打原因(c2, a1b, AtxGodsbet.找入局槽(a1b)).contains("上一把没输"),
		"② 预告：`DeckFlow.大招不可打原因` 也给出「上一把没输」这一条（置灰能看出原因）")

# ==========================================================================================
# ③ 入局后：`is_weapon == false`（不算武器牌）+ `主武器已销毁` 不被置 true
# ==========================================================================================
func _段3_入局不算武器(t) -> void:
	var 卡 := FacAtx.卡(AtxGodsbet.入局ID)
	t.ok(卡.get("is_weapon") == false and 卡.get("武器牌") == false and str(卡.get("卡类", "")) == "大招槽卡",
		"③ 牌面：【%s】卡类 = %s、is_weapon = %s（不算武器牌）" % [
			str(卡.get("名")), str(卡.get("卡类")), str(卡.get("is_weapon"))])
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	var r := AtxGodsbet.打出入局(c, a1)
	t.ok(J.truthy(r.get("成功")) and AtxGodsbet.赌神开启(c),
		"③ 入局成功、赌神开启（战意 50 → %d、费用 %d）" % [int(Btl.战意(a1)), int(AtxGodsbet.费用)])
	t.ok(J.truthy(a1.get("主武器已销毁")) == false and J.truthy(r.get("主武器已销毁")) == false,
		"③ 入局后 `主武器已销毁` **仍是 false**（不算武器牌、不销毁武器）")
	t.ok(bool(AtxGodsbet.找入局槽(a1).get("is_weapon")) == false and J.num0(AtxGodsbet.找入局槽(a1).get("cd")) == 0.0,
		"③ 大招槽条目：is_weapon = false、cd = 0（入局本身不进冷却）")
	# 端到端：从专属手牌打出（`Btl.打出精神或公有牌` 的门面那条路）
	var a1b := _响介(0.0, 50.0, "A1b")
	var c2 := _新场([a1b], [_靶(0.0)])
	a1b["key"] = "A1"
	a1b["tplKey"] = "A1"
	AtxGodsbet.装填大招槽(c2)
	a1b["专属手牌"] = [Btl.克隆战术牌(FacAtx.卡(AtxGodsbet.入局ID), c2)]
	AtxGodsbet.记上一次攻击(c2, c2.enemies[0], a1b, {"命中段": 4, "打空段": 5})
	var r2 := Btl.打出精神或公有牌(c2, "A1", AtxGodsbet.入局ID)
	t.ok(J.truthy(r2.get("成功")) and AtxGodsbet.赌神开启(c2) and J.truthy(a1b.get("主武器已销毁")) == false,
		"③ 端到端 `打出精神或公有牌`：[%s] 成功、赌神开启、主武器没被销毁" % str(r2.get("原因", "ok")))

# ==========================================================================================
# ④ 每段命中 −10 真的进公式（同一发攻击开 / 关赌神，贴每段命中率数字）
# ==========================================================================================
func _段4_命中减十(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var a2 := _艾克赛琳(1.0)
	var c := _新场([a1, a2], [靶])
	AtxGodsbet.装填大招槽(c)
	var w := _武(300.0, 12, "direct", {}, 80.0)
	var 关 := int(Calc.hitRate(a1, w, 靶, {"baseHit": 80.0, "ctx": c}).hit)
	var 关记 := Calc.resolveAttack(a1, 靶, w, c, {})
	t.ok(关 == 80 and str(关记.字段.详情).contains("（80%）"),
		"④ 赌神关着：12 段每段命中 = %d%%（记录里也是「80%%」）" % 关)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	var r入 := AtxGodsbet.打出入局(c, a1)
	t.ok(J.truthy(r入.get("成功")), "④ 入局成功（战意 %d）" % int(Btl.战意(a1)))
	var 开 := int(Calc.hitRate(a1, w, 靶, {"baseHit": 80.0, "ctx": c}).hit)
	var 开记 := Calc.resolveAttack(a1, 靶, w, c, {})
	t.ok(开 == 70 and 关 - 开 == 10,
		"④ 赌神开着：同一发攻击每段命中 = %d%%（80 − 10 = 70，−10 真的进公式）" % 开)
	t.ok(str(开记.字段.详情).contains("（70%）"),
		"④ 真攻击的每段数字也变成 70%%（详情首段 = 「%s」）" % str(开记.字段.详情).split("；")[0])
	t.ok(int(Calc.hitRate(a2, w, 靶, {"baseHit": 80.0, "ctx": c}).hit) == 80,
		"④ 只压响介：艾克赛琳同样的武器仍是 80%（每段命中 −10 不外溢）")

# ==========================================================================================
# ⑤ 翻盘：该段伤害 = 暴击 ×3，且**打空计数仍然 +1**
# ==========================================================================================
func _段5_翻盘(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0, 200.0)          # eva 200 → 命中率被压到 0 → 全段打空
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	c["赌神翻盘概率"] = 1.0            # 测试用覆盖口子：必翻
	var 状 := Fac.势力状态(a1, "ATX")
	状["打空"] = 0.0
	var r := Calc.resolveAttack(a1, 靶, _武(1000.0, 1), c, {})
	var 字段: Dictionary = r.字段
	t.ok(字段.get("命中") == false and int(J.num0(字段.get("命中段数"))) == 0 and int(J.num0(字段.get("段数"))) == 1,
		"⑤ 这一发**全段打空**（命中段数 = %d、段数 = %d）" % [int(J.num0(字段.get("命中段数"))), int(J.num0(字段.get("段数")))])
	t.ok(int(J.num0(字段.get("翻盘段数"))) == 1 and int(J.num0(字段.get("翻盘暴击倍率"))) == 3,
		"⑤ 翻盘真的发生：翻盘段数 = %d、暴击倍率 = ×%d" % [
			int(J.num0(字段.get("翻盘段数"))), int(J.num0(字段.get("翻盘暴击倍率")))])
	t.ok(int(J.num0(字段.get("伤害"))) == 3000,
		"⑤ 该段伤害 = 威力 1000 × **3** = %d（不是平时暴击的 2000）" % int(J.num0(字段.get("伤害"))))
	t.ok(int(J.num0(状.get("打空"))) == 1,
		"⑤ 打空计数仍然 +1：`状.打空` 0 → %d（翻盘的段仍记为打空）" % int(J.num0(状.get("打空"))))
	t.ok(int(AtxGodsbet.上一次攻击(c).get("打空段")) == 1 and int(AtxGodsbet.上一次攻击(c).get("命中段")) == 0,
		"⑤ 全局账也是「打空 1 / 命中 0」→ 翻盘**仍然喂给「上一把输了」**（%s）" % str(AtxGodsbet.上一次攻击(c)))
	t.ok(AtxGodsbet.上一把输了(c) and AtxGodsbet.赌神本场翻盘段数(c) == 1,
		"⑤ 结算读口 `赌神本场翻盘段数` = %d；上一把输了 = %s" % [
			AtxGodsbet.赌神本场翻盘段数(c), str(AtxGodsbet.上一把输了(c))])
	t.ok(_有行(c, "〔赌神〕翻盘 ×1 段") and _有行(c, "仍记为打空"),
		"⑤ 即时那一行：%s" % _找行(c, "〔赌神〕翻盘"))
	# 每次打空段各掷一次：12 段全空 + 必翻 → 12 个翻盘段、随机数 12（命中）+ 12（翻盘）
	var c2 := _新场([_响介(0.0, 50.0)], [_靶(0.0, 200.0)])
	c2.allies[0]["key"] = "A1"
	AtxGodsbet.装填大招槽(c2)
	AtxGodsbet.记上一次攻击(c2, c2.enemies[0], c2.allies[0], {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c2, c2.allies[0])
	c2["赌神翻盘概率"] = 1.0
	var r2 := Calc.resolveAttack(c2.allies[0], c2.enemies[0], _武(100.0, 12), c2, {})
	t.ok(int(J.num0(r2.字段.get("翻盘段数"))) == 12 and AtxGodsbet.赌神本场翻盘段数(c2) == 12,
		"⑤ 每打空 1 段各掷一次：12 段全空 → 翻盘 %d 段（本场累计 %d）" % [
			int(J.num0(r2.字段.get("翻盘段数"))), AtxGodsbet.赌神本场翻盘段数(c2)])
	t.ok(int((c2.get("rng") as Mulberry32).steps) == 24,
		"⑤ 随机数 = 12（每段命中）+ 12（每段翻盘）= %d 次（一次攻击一条记录，绝不逐段写行）" % int((c2.get("rng") as Mulberry32).steps))

# ==========================================================================================
# ⑥ 续注：我方阶段开始先扣 10；扣不出（余 6）→ 关闭 + 入局冷却 2
# ==========================================================================================
func _段6_续注(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	a1["战意"] = 34.0
	AtxGodsbet.阶段初(c)
	t.ok(int(Btl.战意(a1)) == 24 and AtxGodsbet.赌神开启(c),
		"⑥ 我方阶段开始续注：战意 34 → %d（−%d）、赌神仍开着" % [int(Btl.战意(a1)), int(AtxGodsbet.续注)])
	t.ok(_有行(c, "〔赌神〕续注 −10 战意（余 24）"),
		"⑥ 即时那一行：%s" % _找行(c, "〔赌神〕续注"))
	a1["战意"] = 6.0
	AtxGodsbet.阶段初(c)
	t.ok(not AtxGodsbet.赌神开启(c) and int(J.num0(AtxGodsbet.找入局槽(a1).get("cd"))) == 2,
		"⑥ 扣不出 10（余 6）→ 赌神关闭、入局冷却 = %s" % str(AtxGodsbet.找入局槽(a1).get("cd")))
	t.ok(int(J.num0(Btl.战意(a1))) == 6,
		"⑥ 扣不出就**不扣**：战意仍是 %d（不是扣成 0）" % int(Btl.战意(a1)))
	t.ok(_有行(c, "扣不出 10 战意（余 6）→ 赌神关闭，入局冷却 2"),
		"⑥ 即时那一行：%s" % _找行(c, "〔赌神〕续注扣不出"))

# ==========================================================================================
# ⑦ 关闭后：入局不再可打（cd 未归零）→ 两个我方阶段后才重新亮起
# ==========================================================================================
func _段7_关闭后不可打(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	a1["战意"] = 1.0
	DeckFlow.阶段初_冷却与维持(c)
	AtxGodsbet.阶段初(c)                       # 扣不出 → 关闭、cd = 2
	a1["战意"] = 80.0
	t.ok(not AtxGodsbet.入局可用吗(c, a1) and AtxGodsbet.入局不可打原因(c, a1).contains("冷却中"),
		"⑦ 关闭后（cd = 2）入局不可打：「%s」" % AtxGodsbet.入局不可打原因(c, a1))
	t.ok(not J.truthy(AtxGodsbet.打出入局(c, a1).get("成功")),
		"⑦ 真打一次也被拦下（%s）" % str(AtxGodsbet.打出入局(c, a1).get("原因")))
	DeckFlow.阶段初_冷却与维持(c)
	AtxGodsbet.阶段初(c)                       # cd 2 → 1
	t.ok(not AtxGodsbet.入局可用吗(c, a1) and int(J.num0(AtxGodsbet.找入局槽(a1).get("cd"))) == 1,
		"⑦ 一个我方阶段后 cd = 1，仍然不可打：「%s」" % AtxGodsbet.入局不可打原因(c, a1))
	DeckFlow.阶段初_冷却与维持(c)
	AtxGodsbet.阶段初(c)                       # cd 1 → 0
	t.ok(AtxGodsbet.入局可用吗(c, a1),
		"⑦ 两个我方阶段后 cd 归零 → 重新亮起（可入局）")

# ==========================================================================================
# ⑧ 概率覆盖：默认 50%，「响介，交给你了」→ 60%（同种子翻盘段数不同）
# ==========================================================================================
func _段8_概率覆盖(t) -> void:
	var 数50 := _掷翻盘次数(0.5)
	var 数60 := _掷翻盘次数(0.6)
	t.ok(数50 >= 80 and 数50 <= 120,
		"⑧ 50%%：200 次掷出翻盘 %d 次（落在 80–120 的合理区间）" % 数50)
	t.ok(数60 >= 100 and 数60 <= 145,
		"⑧ 60%%：200 次掷出翻盘 %d 次（落在 100–145 的合理区间）" % 数60)
	t.ok(数60 > 数50,
		"⑧ 同种子下 60%% 的翻盘段数 **与 50%% 不同**（%d > %d）" % [数60, 数50])
	# 单位上的临时覆盖键优先于 ctx
	var a1 := _响介(0.0, 50.0)
	var c := _新场([a1], [_靶(0.0)])
	c["赌神翻盘概率"] = 0.5
	a1["赌神翻盘概率"] = 0.6
	t.ok(absf(AtxGodsbet.翻盘概率(c, a1) - 0.6) < 0.0001,
		"⑧ 单位上的 `赌神翻盘概率` 覆盖 ctx（读到 %.2f）" % AtxGodsbet.翻盘概率(c, a1))
	a1.erase("赌神翻盘概率")
	t.ok(absf(AtxGodsbet.翻盘概率(c, a1) - 0.5) < 0.0001 and absf(AtxGodsbet.翻盘概率(_新场([], []), null) - 0.5) < 0.0001,
		"⑧ 没有覆盖键 → 默认 50%%（ctx 覆盖 = %.2f、全默认 = %.2f）" % [
			AtxGodsbet.翻盘概率(c, a1), AtxGodsbet.翻盘概率(_新场([], []), null)])

# ==========================================================================================
# ⑨ 【强运】：正面触发 / 反面不触发，且同一张牌**只掷一次**硬币
# ==========================================================================================
func _段9_强运硬币(t) -> void:
	var 卡 := _强运卡()
	t.ok(AtxLuck.是强运牌(卡) and AtxLuck.强运文字(卡).contains("再指定"),
		"⑨ 牌面：带【强运】（「%s」）" % AtxLuck.强运文字(卡))
	# 正面
	var a2 := _艾克赛琳(0.0)
	var c正 := _新场([a2], [], _找硬币种子(true))
	var r正 := AtxLuck.打出时(c正, a2, 卡)
	t.ok(r正.掷 and r正.正面 and r正.触发,
		"⑨ 正面 → 触发（硬币 = %s、概率 = %.2f）" % [str(r正.摘要), float(r正.概率)])
	t.ok(int((c正.get("rng") as Mulberry32).steps) == 1,
		"⑨ **同一张牌只掷一次硬币**：`ctx.rng` 步数 = %d" % int((c正.get("rng") as Mulberry32).steps))
	t.ok(_有行(c正, "〔强运〕") and _找行(c正, "〔强运〕").contains("正面（触发）"),
		"⑨ 即时那一行：%s" % _找行(c正, "〔强运〕"))
	t.ok(AtxLuck.强运本场正反面次数(c正).正面 == 1 and AtxLuck.强运本场正反面次数(c正).反面 == 0,
		"⑨ 结算读口 `强运本场正反面次数` = %s" % str(AtxLuck.强运本场正反面次数(c正)))
	# 反面
	var a2b := _艾克赛琳(0.0)
	var c反 := _新场([a2b], [], _找硬币种子(false))
	var r反 := AtxLuck.打出时(c反, a2b, 卡)
	t.ok(r反.掷 and not r反.正面 and not r反.触发,
		"⑨ 反面 → **什么也不发生**（硬币 = %s）" % str(r反.摘要))
	t.ok(int((c反.get("rng") as Mulberry32).steps) == 1 and AtxLuck.强运本场正反面次数(c反).反面 == 1,
		"⑨ 反面同样只掷一次（步数 = %d、反面计数 = %d）" % [
			int((c反.get("rng") as Mulberry32).steps), AtxLuck.强运本场正反面次数(c反).反面])
	t.ok(_找行(c反, "〔强运〕").contains("反面（未触发）"),
		"⑨ 即时那一行：%s" % _找行(c反, "〔强运〕"))
	# 「必定触发」口子（如「好运连连」）：必为正面、且不掷随机数
	var c必 := _新场([_艾克赛琳(0.0)], [], 20261017)
	var 必卡 := _强运卡()
	必卡["强运必触发"] = true
	var r必 := AtxLuck.打出时(c必, c必.allies[0], 必卡)
	t.ok(r必.正面 and int((c必.get("rng") as Mulberry32).steps) == 0,
		"⑨ 「必定触发」口子：硬币必为正面、且**不消耗随机数**（步数 = %d）" % int((c必.get("rng") as Mulberry32).steps))
	# 概率覆盖口子
	var c概 := _新场([_艾克赛琳(0.0)], [], 20261017)
	var 概卡 := _强运卡()
	概卡["强运概率"] = 0.9
	t.ok(absf(AtxLuck.概率(c概, c概.allies[0], 概卡) - 0.9) < 0.0001,
		"⑨ 概率覆盖口子：牌上的 `强运概率` 读成 %.2f（默认 %.2f）" % [
			AtxLuck.概率(c概, c概.allies[0], 概卡), AtxLuck.默认概率])

# ==========================================================================================
# ⑩ 【强运】不留状态：单位字典前后逐字相同、grep 不到任何 `强运` 相关键
# ==========================================================================================
func _段10_强运不留状态(t) -> void:
	var a2 := _艾克赛琳(0.0)
	var c := _新场([a2], [], _找硬币种子(true))
	# 用一张「强运分支为空」的牌：这样唯一可能变化的就只有「硬币状态」——
	# 判定完若不留状态，单位字典必须**逐字相同**。
	var 空卡 := _强运卡()
	空卡["强运分支"] = []
	var 前 := str(a2.duplicate(true))
	var r := AtxLuck.打出时(c, a2, 空卡)
	t.ok(r.触发 and str(a2.duplicate(true)) == 前,
		"⑩ 触发之后**单位字典前后逐字相同**（不留任何状态）")
	# 带分支的牌也一样：只挂「牌面效果」本身，绝不多出一个「强运」键
	AtxLuck.打出时(c, a2, _强运卡())
	var 命中: Array = []
	for k in a2.keys():
		if str(k).contains("强运"):
			命中.append(str(k))
	t.ok(命中.is_empty(), "⑩ 单位上 grep 不到任何 `强运` 相关键（命中：%s）" % str(命中))
	var 禁 := ["强运" + "层数", "强运" + "剩余", "强运" + "已触发"]
	var 源命中: Array = []
	for 根 in ["res://core", "res://session", "res://presentation"]:
		_扫源码(根, 禁, 源命中)
	t.ok(源命中.is_empty(), "⑩ 源码里搜不到 `强运` + 层数 / 剩余 / 已触发 这类持久字段（命中：%s）" % str(源命中))

# ==========================================================================================
# ⑪ ★ 旧机制停用：「打空 8 段」**不会**再让 ATX 角色牌冷却 −1
# ==========================================================================================
func _段11_旧机制停用(t) -> void:
	var 攻 := _靶(0.0)
	var 条 := {"类型": "打空", "阈值": 8}
	# ---- 旧机制整体停用（但打空计数照常记）----
	var 守2 := _ATX带赌徒(0.0)
	var c开 := _新场([守2], [攻])
	for i in 8:
		Fac.势力逐段未命中(c开, 攻, 守2, _武(10.0, 1), {"段号": float(i + 1), "段数": 8.0})
	t.ok(absf(_武器冷却(守2) - 5.0) < 0.0001,
		"⑪ 开关**开**：同样打空 8 段 → 冷却仍是 %s（一个数字都不减）" % str(_武器冷却(守2)))
	t.ok(int(J.num0(Fac.势力状态(守2, "ATX").get("打空"))) == 8,
		"⑪ 但**打空计数照常记**：`状.打空` = %d（赌神翻盘的段要靠它）" % int(J.num0(Fac.势力状态(守2, "ATX").get("打空"))))
	t.ok(not Btl._声明式触发(条, c开, "开局", {"未命中段": 8}),
		"⑪ 开关开：「本场打空 ≥ 8 段」这个**卡牌触发条件**不再成立（v0.3 删了该口径）")

# ==========================================================================================
# ==========================================================================================
# ⑬ 同种子两遍：记录文本 + 所有数字逐字相同
# ==========================================================================================
func _段13_同种子两遍(t) -> void:
	var 一 := _整场脚本()
	var 二 := _整场脚本()
	t.ok(一.日志 == 二.日志 and 一.文 == 二.文 and 一.账 == 二.账 and 一.翻盘 == 二.翻盘
		and 一.硬币 == 二.硬币 and 一.rng == 二.rng and 一.战意 == 二.战意,
		"⑬ 同种子两遍**逐字相同**（日志 %d 行 / rng %d 次 / 翻盘 %d 段 / 硬币 %s / 战意 %d）" % [
			_行数(一.日志), 一.rng, 一.翻盘, 一.硬币, 一.战意])

# ==========================================================================================
# ⑭（额外）三层反馈：即时 / 预告 / 结算
# ==========================================================================================
func _段14_三层反馈(t) -> void:
	var a1 := _响介(0.0, 50.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶])
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	# 即时：入局那一行
	t.ok(_有行(c, "〔赌神〕响介 入局（上一把输了：打空 5 ≥ 命中 4 · 战意 50）"),
		"⑭ 即时（入局）：%s" % _找行(c, "〔赌神〕响介 入局"))
	# 预告：机体卡 / 状态行上的「赌神」
	var s := GameSession.new()
	s.battle_ctx = c
	s.screen = "battle"
	var 图 := s.unit_view("ally", "A1")
	t.ok(bool(图.get("赌神", false)) and (图.get("状态") as Array).has("赌神"),
		"⑭ 预告：`unit_view` 里有 `赌神 = true`、状态行含「赌神」（%s）" % str(图.get("状态")))
	# 对照：赌神没开启时同一个快照里没有这个键、状态行也没有「赌神」
	var c关 := _新场([_响介(0.0, 50.0)], [_靶(0.0)])
	var s关 := GameSession.new()
	s关.battle_ctx = c关
	s关.screen = "battle"
	var 关图 := s关.unit_view("ally", "A1")
	t.ok(关图.get("赌神") == null and not (关图.get("状态") as Array).has("赌神"),
		"⑭ 预告对照：赌神没开启 → 快照里没有 `赌神` 键、状态行也没有（%s）" % str(关图.get("状态")))
	# 结算：两个纯读口
	var c2 := _新场([_艾克赛琳(0.0)], [], _找硬币种子(true))
	AtxLuck.打出时(c2, c2.allies[0], _强运卡())
	t.ok(AtxGodsbet.赌神本场翻盘段数(c) == 0 and AtxLuck.强运本场正反面次数(c2).正面 == 1,
		"⑭ 结算读口：`赌神本场翻盘段数` = %d、`强运本场正反面次数` = %s" % [
			AtxGodsbet.赌神本场翻盘段数(c), str(AtxLuck.强运本场正反面次数(c2))])
	# ---- 真管线：`Btl.开始我方阶段` 里真的会续注（不是只有直接调 `AtxGodsbet.阶段初` 才会）----
	var c3 := Setup.开局([{"键": "A1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261018, null, {"单机牌组": true})
	if (c3.get("allies") as Array).is_empty():
		t.ok(false, "⑭ 开局失败（真管线那一段）")
		return
	var 甲: Dictionary = c3.allies[0]
	甲["战意"] = 60.0
	AtxGodsbet.记上一次攻击(c3, c3.enemies[0], 甲, {"命中段": 4, "打空段": 5})
	var r入 := AtxGodsbet.打出入局(c3, 甲)
	t.ok(J.truthy(r入.get("成功")) and int(Btl.战意(甲)) == 50,
		"⑭ 真管线：入局扣 10（战意 60 → %d）" % int(Btl.战意(甲)))
	Btl.开始我方阶段(c3)
	t.ok(AtxGodsbet.赌神开启(c3) and int(Btl.战意(甲)) == 50 and _有行(c3, "〔赌神〕续注 −10 战意（余 45）"),
		"⑭ 真管线：`Btl.开始我方阶段` 续注 −10、回合初战意结算后 → 战意 %d、赌神仍开着" % int(Btl.战意(甲)))

# ==========================================================================================
# 小工具
# ==========================================================================================
func _响介(位: float, 战意: float = 50.0, 键: String = "A1") -> Dictionary:
	var d := _单位(键, "ally", 位, 0.0)
	d["战意"] = 战意
	d["战意上限"] = 100.0
	d["name"] = "响介"
	d["abilities"] = ["gamblerSense"]
	d["weapons"] = [{"t": {"name": "左轮打桩机", "evadeCd": true, "unlock": 1.0, "cd": 0.0}, "cd": 0.0, "readyTurn": 0.0}]
	return d

func _艾克赛琳(位: float) -> Dictionary:
	var d := _单位("A2", "ally", 位, 0.0)
	d["战意"] = 50.0
	d["战意上限"] = 100.0
	d["name"] = "艾克赛琳"
	return d

func _靶(位: float, 闪避: float = 0.0) -> Dictionary:
	var d := _单位("靶_%d" % int(位), "enemy", 位, 闪避)
	d["name"] = "靶机"
	return d

## 带「赌徒的直觉」的 ATX 成员 + 一件 `evadeCd` 武器（冷却 5）—— 对照组用
func _ATX带赌徒(位: float) -> Dictionary:
	var d := _单位("ATX_%d" % int(位), "ally", 位, 0.0)
	d["name"] = "ATX 测试机"
	d["abilities"] = ["gamblerSense"]
	d["weapons"] = [{"t": {"name": "左轮打桩机", "evadeCd": true, "unlock": 1.0, "cd": 0.0}, "cd": 5.0, "readyTurn": 0.0}]
	return d

func _武器冷却(u: Dictionary) -> float:
	var 们: Array = J.or_(u.get("weapons"), [])
	if 们.is_empty():
		return -1.0
	return J.num0((们[0] as Dictionary).get("cd"))

func _单位(键: String, side: String, 位: float, 闪避: float) -> Dictionary:
	return {
		"key": 键, "name": 键, "tplKey": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 闪避, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [], "weapons": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"势力": "ATX"},
	}

## `fire` 一律用 "direct"（"map" 是必中，会把「打空」这条线关掉）。
func _武(威力: float, 段数: int, fire: String = "direct", 额外: Dictionary = {}, 命中率: float = 50.0) -> Dictionary:
	var w := {
		"name": "测试武器", "fire": fire, "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": [],
	}
	for k in 额外.keys():
		w[k] = 额外[k]
	return w

func _新场(我方: Array, 敌方: Array, 种子: int = 20261017) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0,
		"选项": {"势力手感v01": false},
	}

## 一张带【强运】的测试牌（分支 = 给 ATX 全体挂 critX +1）
func _强运卡() -> Dictionary:
	return {
		"id": "T_LUCK", "名": "好运加护", "卡类": "专属精神牌", "归属": "ATX", "层级": "角色",
		"耗气": 0.0, "强运": true, "强运效果": "强运：再指定一台友军，效果相同",
		"强运分支": [{"全局": [{"算子": "atx", "动作": "光环", "范围": "ATX",
			"增益": {"critX": 1.0, "剩余": 1.0}}]}],
	}

func _找种子(k: int) -> int:
	for s in range(1, 200001):
		var r := Mulberry32.new(s)
		var 中 := 0
		for i in 12:
			if r.next_float() * 100.0 < 50.0:
				中 += 1
				r.next_float()
		if 中 == k:
			return s
	return 0

## 第一抽就是硬币：找一个「第一抽 < 0.5（正面） / >= 0.5（反面）」的种子
func _找硬币种子(要正面: bool) -> int:
	for s in range(1, 5000):
		var r := Mulberry32.new(s)
		var v := float(r.next_float())
		if (v < 0.5) == 要正面:
			return s
	return 0

func _掷翻盘次数(概: float) -> int:
	var a1 := _响介(0.0, 60.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1], [靶], 20261017)
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	c["赌神翻盘概率"] = 概
	var 中 := 0
	for _i in 200:
		if AtxGodsbet.掷翻盘(c, a1):
			中 += 1
	return 中

## 一整段脚本（⑬ 同种子两遍用）：入局 → 一发 12 段（50% 翻盘）→ 续注 → 强运硬币
func _整场脚本() -> Dictionary:
	var a1 := _响介(0.0, 60.0)
	var a2 := _艾克赛琳(1.0)
	var 靶 := _靶(0.0)
	var c := _新场([a1, a2], [靶], 20261017)
	AtxGodsbet.装填大招槽(c)
	AtxGodsbet.记上一次攻击(c, 靶, a1, {"命中段": 4, "打空段": 5})
	AtxGodsbet.打出入局(c, a1)
	var r := Calc.resolveAttack(a1, 靶, _武(120.0, 12, "direct", {}, 40.0), c, {})
	AtxGodsbet.阶段初(c)
	AtxLuck.打出时(c, a2, _强运卡())
	var 行们: Array = _行们(c)
	return {
		"日志": "\n".join(行们), "文": str(r.get("文本")) + "|" + str(r.get("字段")),
		"账": str(AtxGodsbet.上一次攻击(c)), "翻盘": AtxGodsbet.赌神本场翻盘段数(c),
		"硬币": str(AtxLuck.强运本场正反面次数(c)), "rng": int((c.get("rng") as Mulberry32).steps),
		"战意": int(Btl.战意(a1)),
	}

func _行数(s: String) -> int:
	return s.split("\n").size()

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

func _找行(c: Dictionary, 子串: String) -> String:
	for 行 in _行们(c):
		if str(行).contains(子串):
			return str(行)
	return "（没有这一行）"

## 递归扫源码，把出现的禁用子串记进 `出`（`out.append("文件 ⟵ 子串")`）。
func _扫源码(根: String, 禁: Array, 出: Array) -> void:
	var d := DirAccess.open(根)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var p := 根.path_join(f)
		var 文 := FileAccess.get_file_as_string(p)
		for k in 禁:
			if 文.contains(str(k)):
				出.append("%s ⟵ %s" % [p, str(k)])
	for 子 in d.get_directories():
		_扫源码(根.path_join(子), 禁, 出)
