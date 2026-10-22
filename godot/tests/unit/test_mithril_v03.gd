## ★ MITH3-1 ~ MITH3-4 验收：武器范围规则 v0.1 + 卡牌流转规则 v0.1 + 秘银 v0.3（连携牌库 / λ 驱动 / 全卡表）。
##
## 全部在 `选项 = {"单机牌组": true, "秘银v03": true}` 的沙盒里做。
## 权威规格：`协作/架构/任务单-秘银v0.3与卡牌流转范围规则v1.0-ARGON.md` §1.1 ~ §1.5、§2 的 MITH3-1 ~ MITH3-4。
##
## 距离口径（4×4 战场，跨方阵算）：
##   `dist = |col(u) - col(t)| + row(u) + row(t) + 1`，取值 1..6。
##   我方前排 col0 → 敌方前排 col0 = 1；我方后排 col0 → 敌方前排 col0 = 2；
##   我方后排 col1 → 敌方后排 col0 = 4；我方后排 col0 → 敌方后排 col3 = 6。
extends RefCounted

const 种子 := 20261017

func run(t) -> void:
	var 错误 := []
	DataLoader.install(错误)
	_段1_开关(t)
	_段2_距离与顶位(t)
	_段3_武器可达(t)
	_段4_遮挡(t)
	_段5_范围五型(t)
	_段6_特殊与远距(t)
	_段7_卡表(t)
	_段8_大招槽(t)
	_段9_副武器栏(t)
	_段10_待入库(t)
	_段11_满手停抽(t)
	_段12_连携牌库(t)
	_段13_断路器(t)
	_段14_λ驱动(t)
	_段15_门面(t)
	_段16_整场跑完(t)
	_段17_试玩三轮修复(t)

# ==========================================================================================
# 小工具
# ==========================================================================================
func _敌() -> Array:
	return [{"键": "fighter", "位": 0, "等级": 1}, {"键": "tank", "位": 1, "等级": 1},
		{"键": "sniper", "位": 4, "等级": 1}, {"键": "fighter", "位": 5, "等级": 1},
		{"键": "fighter", "位": 7, "等级": 1}]

func _队(键们: Array, lv: int = 30) -> Array:
	var 出: Array = []
	var 位们 := [0, 1, 5, 6, 7]
	for i in 键们.size():
		出.append({"键": str(键们[i]), "位": 位们[mini(i, 位们.size() - 1)], "等级": lv})
	return 出

func _开(键们: Array, lv: int = 30, 选项: Dictionary = {}) -> Dictionary:
	var o := {"单机牌组": true, "秘银v03": true}
	for k in 选项.keys():
		o[k] = 选项[k]
	return Setup.开局(_队(键们, lv), _敌(), 种子, null, o)

func _单位(ctx: Dictionary, 键: String) -> Dictionary:
	for u in ctx.get("allies", []):
		if u is Dictionary and str(u.get("key", "")) == 键:
			return u
	return {}

func _敌单位(ctx: Dictionary, 位: int) -> Dictionary:
	for u in ctx.get("enemies", []):
		if u is Dictionary and int(u.get("slot", -1)) == 位:
			return u
	return {}

func _日志有(ctx: Dictionary, 文: String) -> bool:
	for e in ctx.get("log", []):
		if e is Dictionary and str(e.get("文本", "")).contains(文):
			return true
	return false

## 日志里**最后一条**指定类型的文本（没有 = 空串）—— 验「主日志行」用。
func _最后文本(ctx: Dictionary, 类型: String) -> String:
	var 出 := ""
	for e in ctx.get("log", []):
		if e is Dictionary and str(e.get("类型", "")) == 类型:
			出 = str(e.get("文本", ""))
	return 出

## 日志里**最后一条**指定类型的整条事件（验字段用）。
func _最后事件(ctx: Dictionary, 类型: String) -> Dictionary:
	var 出: Dictionary = {}
	for e in ctx.get("log", []):
		if e is Dictionary and str(e.get("类型", "")) == 类型:
			出 = e
	return 出

func _有卡(们: Variant, id: String) -> bool:
	for c in 们 if 们 is Array else []:
		if c is Dictionary and str(c.get("id", "")) == id:
			return true
	return false

func _真(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return not (v as String).is_empty()
	return true

# ==========================================================================================
# 段 1：三个开关
# ==========================================================================================
func _段1_开关(t) -> void:
	var c1 := _开(["U7"])
	t.ok((c1.get("连携牌库") as Array).size() == 4, "① 开场 `ctx.连携牌库` 建好了（4 张一级牌）")
	t.ok(Params.大招槽亮起条件({"本回合已打": true}).contains("已经打过"),
		"① `Params.大招槽亮起条件` 给出「本回合已经打过」的理由")

# ==========================================================================================
# 段 2：4×4 距离 `1..6` + 顶位（仅影响近战）
# ==========================================================================================
func _段2_距离与顶位(t) -> void:
	# 跨方阵（我方 slot a / 敌方 slot b）
	t.ok(Fm.真实距离(0, 0) == 1, "② 我方前排 col0 → 敌方前排 col0：距离 1（都在前排）")
	t.ok(Fm.真实距离(4, 0) == 2, "② 我方后排 col0 → 敌方前排 col0：一前一后 → 距离 2")
	t.ok(Fm.真实距离(5, 4) == 4, "② 我方后排 col1 → 敌方后排 col0：横差 1 + 都在后排 3 = 4")
	t.ok(Fm.真实距离(4, 7) == 6, "② 我方后排 col0 → 敌方后排 col3：横差 3 + 3 = 6（全场最远）")
	var 最小 := 99
	var 最大 := -1
	for a in range(8):
		for b in range(8):
			var d := Fm.真实距离(a, b)
			最小 = mini(最小, d)
			最大 = maxi(最大, d)
	t.ok(最小 == 1 and 最大 == 6, "② 全表 64 对里真实距离的取值范围就是 1..6（实测 %d..%d）" % [最小, 最大])
	t.ok(Fm.dist_real(4, 0) == Fm.真实距离(4, 0), "② `dist_real` 与 `真实距离` 同一份实现")
	# 顶位
	var c := _开(["U7", "U6"])
	var u7 := _单位(c, "U7")
	var u6 := _单位(c, "U6")
	u7["slot"] = 4.0
	u6["slot"] = 5.0
	t.ok(Fm.是否顶位(c, "ally"), "② 我方前排 4 格全空（U7 在 slot4、U6 在 slot5）→ 我方顶位")
	t.ok(not Fm.是否顶位(c, "enemy"), "② 敌方前排有人（fighter slot0）→ 敌方不顶位")
	t.ok(Fm.是前排有效(u7, c), "② 顶位单位对近战**视为站在前排**（`是前排有效` = true）")
	t.ok(Fm.is_front_effective(c, u7), "② 任务单写法的 `is_front_effective(ctx, u)` 同一口径")
	t.ok(not Fm.是否顶位(c, "enemy") and Fm.是前排有效(_敌单位(c, 0), c),
		"② 顶位是按**每一方自己**的前排算的：敌方前排有人 → 敌方不顶位（但它的前排单位当然算前排有效）")
	# 顶位只影响近战
	t.ok(Fm.真实距离(4, 0) == 2 and Fm.近战距离(4, 0, true, false) == 1,
		"② 顶位只改近战：真实距离 2，近战距离（顶位按前排算）= 1")
	t.ok(Fm.格距离(4, 0, false, true, false) == 2,
		"② `格距离(…, 是近战 = false)` 忽略顶位参数 —— 直射 / 曲射 / 【远距·N】 一律真实距离")
	t.ok(Fm.格距离(4, 0, true, true, false) == 1, "② `格距离(…, 是近战 = true)` 按顶位算")
	# 掩体也算「占着」
	u7["slot"] = 7.0
	u6["slot"] = 6.0
	c["掩体"] = {"ally": {"0": {"hp": 3000.0}}}
	t.ok(not Fm.是否顶位(c, "ally"), "② 前排 slot0 **有掩体（HP 3000）** → 不算顶位（掩体也算存活单位）")
	c["掩体"]["ally"]["0"]["hp"] = 0.0
	t.ok(Fm.是否顶位(c, "ally"), "② 掩体被打掉（HP 0）→ 又回到顶位")

# ==========================================================================================
# 段 3：`武器可达吗`
# ==========================================================================================
func _段3_武器可达(t) -> void:
	var c := _开(["U7"])
	var u7 := _单位(c, "U7")
	var 前敌 := _敌单位(c, 0)
	var 后敌 := _敌单位(c, 4)
	var 近战 := {"name": "单分子刀", "fire": "melee", "dmgType": "物理", "距离": [1, 2]}
	u7["slot"] = 0.0
	var 判 := Reach.武器可达吗(c, u7, 近战, 前敌)
	t.ok(bool(判.get("ok")) and int(判.get("dist")) == 1, "③ 近战从 slot0 打敌方前排 slot0：可达，距离 1")
	判 = Reach.武器可达吗(c, u7, 近战, 后敌)
	t.ok(not bool(判.get("ok")) and str(判.get("why")).contains("后排"),
		"③ 近战打敌方后排（前排还有人）→ 不可达，理由写明「后排」（%s）" % str(判.get("why")))
	# 敌方前排全灭 → 敌方顶位 → 近战都打得到
	for u in c.get("enemies", []):
		if u is Dictionary and Fm.rowOfSlot(float(u.get("slot", 0))) == Fm.ROW_FRONT:
			(u as Dictionary)["hp"] = 0.0
	判 = Reach.武器可达吗(c, u7, 近战, 后敌)
	t.ok(bool(判.get("ok")) and int(判.get("dist")) == 1,
		"③ 敌方前排全灭（敌方顶位）→ 近战打得到敌方后排（距离按前排算 = 1）")
	# 距离下限 / 上限（重新造一份干净的 ctx）
	var c2 := _开(["U7"])
	var u := _单位(c2, "U7")
	var 狙 := {"name": "76mm 狙击炮", "fire": "direct", "dmgType": "物理", "距离": [2, 6]}
	u["slot"] = 4.0
	判 = Reach.武器可达吗(c2, u, 狙, _敌单位(c2, 0))
	t.ok(bool(判.get("ok")) and int(判.get("dist")) == 2, "③ 狙击距离 2–6 打距离 2 的目标：可达（距离 2）")
	u["slot"] = 0.0
	判 = Reach.武器可达吗(c2, u, 狙, _敌单位(c2, 0))
	t.ok(not bool(判.get("ok")) and str(判.get("why")).contains("太近"),
		"③ 下限 ≥ 2 的狙击打正对面（距离 1）→ 不可达，理由是「太近」（%s）" % str(判.get("why")))
	t.ok(not Reach.够得着吗(c2, u, 狙, _敌单位(c2, 0)), "③ `够得着吗` 便捷读法同口径")
	u["slot"] = 4.0
	判 = Reach.武器可达吗(c2, u, 狙, _敌单位(c2, 7))
	t.ok(int(判.get("dist")) == 6 and bool(判.get("ok")), "③ 上限 6：最远距离刚好可达")
	t.ok(int(Reach.武器距离(狙).x) == 2 and int(Reach.武器距离(狙).y) == 6, "③ `武器距离` 读出 [2, 6]")
	# 无视遮挡 / 后方渗透
	var 拳 := {"name": "隔空 λ 拳", "fire": "melee", "dmgType": "特殊", "距离": [1, 4], "ignore_block": true}
	u["slot"] = 5.0
	判 = Reach.武器可达吗(c2, u, 拳, _敌单位(c2, 5))
	t.ok(bool(判.get("ok")), "③ `ignore_block: true`（隔空 λ 拳）：近战也能打敌方后排（距离 3 ≤ 4）")
	var 渗透者 := {"buffs": [{"src": "后方渗透", "剩余": 1.0}]}
	t.ok(Reach.有后方渗透(渗透者), "③ `后方渗透` 状态读法：`有后方渗透` = true")
	t.ok(Reach.无视遮挡(拳) and not Reach.无视遮挡(近战), "③ `无视遮挡` 读法：隔空拳 true / 单分子刀 false")
	t.ok(absf(Reach.遮挡命中惩罚(c2, u, 近战, _敌单位(c2, 5))) < 0.001, "③ 近战不算遮挡（只有直射才吃 −20）")

# ==========================================================================================
# 段 4：遮挡（直射打敌方后排时同列前排有人 → 命中 −20）
# ==========================================================================================
func _段4_遮挡(t) -> void:
	var c := _开(["U6"])
	var u6 := _单位(c, "U6")
	u6["slot"] = 1.0
	var 后 := _敌单位(c, 5)
	后["hp"] = 5000.0
	t.ok(Fm.另一排同位(5) == 1, "④ 落位换算：敌方后排 slot5 的同列前排 = slot1")
	t.ok(Fm.格被占(c, "enemy", 1), "④ `格被占`：敌方前排 slot1（tank）占着")
	var 直 := {"name": "76mm 狙击炮", "fire": "direct", "dmgType": "物理", "距离": [2, 6]}
	t.ok(absf(Reach.遮挡命中惩罚(c, u6, 直, 后) + 20.0) < 0.001,
		"④ 直射打敌方后排、同列前排有人 → 命中 −20")
	_敌单位(c, 1)["hp"] = 0.0
	t.ok(absf(Reach.遮挡命中惩罚(c, u6, 直, 后)) < 0.001, "④ 同列前排被打掉 → 不再 −20")
	_敌单位(c, 1)["hp"] = 1000.0
	var 穿 := {"name": "超长距离狙击", "fire": "direct", "dmgType": "物理", "距离": [3, 6], "ignore_block": true}
	t.ok(absf(Reach.遮挡命中惩罚(c, u6, 穿, 后)) < 0.001, "④ `ignore_block` 武器（超长距离狙击）不吃 −20")
	var 曲 := {"name": "榴弹发射器", "fire": "indirect", "dmgType": "物理", "距离": [2, 5]}
	t.ok(absf(Reach.遮挡命中惩罚(c, u6, 曲, 后)) < 0.001, "④ 曲射不受遮挡（不 −20）")
	u6["buffs"] = [{"src": "破障射击", "剩余": 1.0}]
	t.ok(Reach.有破障射击(u6) and absf(Reach.遮挡命中惩罚(c, u6, 直, 后)) < 0.001,
		"④ 打出者带「破障射击」→ 直射也无视遮挡（不 −20）")

# ==========================================================================================
# 段 5：`area` 五型
# ==========================================================================================
func _段5_范围五型(t) -> void:
	t.ok(Reach.范围型({"area": "splash"}) == "splash" and Reach.范围型({"area": "single"}) == "single",
		"⑤ `范围型` 认得 single / splash")
	t.ok(Reach.范围型({"area": "col"}) == "pierce" and Reach.范围型({"area": "cross"}) == "splash",
		"⑤ 老写法折进新写法：col → pierce、cross → splash")
	var 目标 := {"slot": 5, "side": "enemy"}
	var 单 := Reach.范围落点({"area": "single"}, 目标)
	t.ok(单.size() == 1 and int(单[0]["位"]) == 5 and absf(float(单[0]["倍率"]) - 1.0) < 0.001,
		"⑤ single：只有目标自己（100%）")
	var 溅 := Reach.范围落点({"area": "splash", "splash_mul": 0.5}, 目标)
	var 位们: Array = 溅.map(func(e): return int(e["位"]))
	t.ok(溅.size() == 4 and 位们.has(1) and 位们.has(4) and 位们.has(6),
		"⑤ splash：目标 + 十字相邻 3 格（同排左右 slot4/6 + 同列另一排 slot1）= 4 格（%s）" % str(位们))
	t.ok(absf(float(溅[0]["倍率"]) - 1.0) < 0.001 and absf(float(溅[1]["倍率"]) - 0.5) < 0.001,
		"⑤ splash：主目标 100%、邻格 50%")
	var 溅75 := Reach.范围落点({"area": "splash", "splash_mul": 0.75}, 目标)
	t.ok(absf(float(溅75[1]["倍率"]) - 0.75) < 0.001, "⑤ splash 的 `+` 版：邻格 75%")
	var 穿 := Reach.范围落点({"area": "pierce", "pierce_mul": 0.5}, 目标)
	t.ok(穿.size() == 2 and int(穿[1]["位"]) == 1 and absf(float(穿[1]["倍率"]) - 0.5) < 0.001,
		"⑤ pierce：目标 + 同列另一排（slot1）50%")
	var 排 := Reach.范围落点({"area": "row"}, 目标)
	t.ok(排.size() == 4, "⑤ row：目标所在排全部 4 格（含主目标，%d）" % 排.size())
	var 全 := Reach.范围落点({"area": "all"}, 目标)
	t.ok(全.size() == 8, "⑤ all：敌方全部 8 格（%d）" % 全.size())
	var c := _开(["U7"])
	var 敌 := _敌单位(c, 1)
	敌["hp"] = 1000.0
	var 目标们 := Reach.范围目标们(c, {"area": "row"}, 敌)
	t.ok(目标们.size() >= 1 and int(目标们[0]["单位"].slot) == 1, "⑤ `范围目标们` 从落点表挑出同方存活单位")
	t.ok(Reach.是范围武器({"area": "row"}) and not Reach.是范围武器({"area": "single"}),
		"⑤ `是范围武器`：row 是、single 不是")
	t.ok(int(Reach.武器距离({"area": "row"}).y) == 6, "⑤ 没写距离的武器 = [1, 6]（整张 4×4 都够）")

# ==========================================================================================
# 段 6：`特殊` 伤害 + 【远距·N】 + 被动「狙击之王」
# ==========================================================================================
func _段6_特殊与远距(t) -> void:
	var c := _开(["U6"])
	var u6 := _单位(c, "U6")
	u6["slot"] = 4.0
	var 靶 := _敌单位(c, 4)
	靶["hp"] = 40000.0
	靶["maxHp"] = 40000.0
	靶["weak"] = {"光束": -50.0}
	var 物理 := {"name": "试射·物理", "fire": "direct", "dmgType": "物理", "power": 3000.0, "hit": 200.0,
		"stat": "射击", "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [], "距离": [1, 6]}
	var 特殊 := 物理.duplicate(true)
	特殊["name"] = "试射·特殊"
	特殊["dmgType"] = "特殊"
	var 物伤 := float(Calc.resolveAttack(u6, 靶, 物理, c, {}).字段.伤害)
	靶["hp"] = 40000.0
	var 特伤 := float(Calc.resolveAttack(u6, 靶, 特殊, c, {}).字段.伤害)
	t.ok(特伤 > 物伤, "⑥ 目标有「光束」弱点时：物理吃到 −50%% 抗性（%d），特殊**无视抗性**（%d）" % [int(物伤), int(特伤)])
	# 远距·4：我方后排 col1 → 敌方后排 col0 = 4
	u6["slot"] = 5.0
	var 远靶 := _敌单位(c, 4)
	远靶["hp"] = 40000.0
	var w远 := {"name": "76mm 狙击炮", "fire": "direct", "dmgType": "物理", "power": 2550.0, "hit": 120.0,
		"距离": [2, 6], "远距": {"阈值": 4, "暴伤加成": 0.2}}
	var 远 := Calc.远距判定(c, u6, 远靶, w远)
	t.ok(bool(远.get("触发")) and int(远.get("距离")) == 4 and absf(float(远.get("暴伤加成")) - 0.2) < 0.001,
		"⑥ 远距·4：距离 4 触发，暴伤加成 +20%")
	u6["slot"] = 4.0
	var 近 := Calc.远距判定(c, u6, 远靶, w远)
	t.ok(not bool(近.get("触发")) and int(近.get("距离")) == 3, "⑥ 远距·4：距离 3 不触发")
	var w魔 := {"name": "魔弹", "远距": {"阈值": 5, "伤害倍率": 1.3}}
	u6["slot"] = 4.0
	var 魔靶 := _敌单位(c, 7)
	魔靶["hp"] = 40000.0
	var 魔 := Calc.远距判定(c, u6, 魔靶, w魔)
	t.ok(bool(魔.get("触发")) and int(魔.get("距离")) == 6 and absf(float(魔.get("伤害倍率")) - 1.3) < 0.001,
		"⑥ 魔弹 远距·5：距离 6 触发，伤害 ×1.3")
	# 狙击之王：距离 ≥ 4
	u6["slot"] = 5.0
	var 王 := Calc.狙击之王加成(c, u6, 远靶)
	t.ok(bool(王.get("触发")) and absf(float(王.get("命中")) - 20.0) < 0.001 and absf(float(王.get("暴击")) - 20.0) < 0.001,
		"⑥ 被动「狙击之王」：距离 4（≥ 4）→ 命中 +20、暴击 +20")
	var 王近 := Calc.狙击之王加成(c, u6, _敌单位(c, 0))
	t.ok(not bool(王近.get("触发")), "⑥ 距离 3（< 4）→ 狙击之王不触发")

# ==========================================================================================
# 段 7：v0.3 卡表
# ==========================================================================================
func _段7_卡表(t) -> void:
	var 表 := MithrilV03Cards.卡表()
	t.ok(表.size() >= 70, "⑦ v0.3 卡表共 %d 张（5 名成员 + 18 张分类牌 + 9 连携 + 9 势力 + 合体技）" % 表.size())
	for k in ["U7", "U6", "U2", "U1", "U8"]:
		var 们 := MithrilV03Cards.角色专属牌们(k)
		t.ok(们.size() >= 7, "⑦ %s 的专属牌 %d 张" % [k, 们.size()])
	t.ok(MithrilV03Cards.连携一级.size() == 4 and MithrilV03Cards.连携二级.size() == 3
		and MithrilV03Cards.连携三级.size() == 2, "⑦ 连携牌库 9 张：一级 4 / 二级 3 / 三级 2")
	t.ok(MithrilV03Cards.连携牌们().size() == 9, "⑦ 卡表里的连携牌真的 9 张（%d）" % MithrilV03Cards.连携牌们().size())
	t.ok(MithrilV03Cards.势力牌们().size() == 9, "⑦ 秘银势力牌 9 张")
	t.ok(MithrilV03Cards.职业牌们().size() == 18, "⑦ 职业分类牌 18 张（特种 6 / 狙击 6 / 指挥 6）")
	var 特种 := MithrilV03Cards.职业牌们().filter(func(c): return str(c.get("归属", "")) == "特种")
	var 狙击 := MithrilV03Cards.职业牌们().filter(func(c): return str(c.get("归属", "")) == "狙击")
	var 指挥 := MithrilV03Cards.职业牌们().filter(func(c): return str(c.get("归属", "")) == "指挥")
	t.ok(特种.size() == 6 and 狙击.size() == 6 and 指挥.size() == 6,
		"⑦ 特种 / 狙击 / 指挥 各 6 张（%d / %d / %d）" % [特种.size(), 狙击.size(), 指挥.size()])
	t.ok(not MithrilV03Cards.合体技卡().is_empty() and str(MithrilV03Cards.合体技卡().get("名")) == "乌鲁兹·三角",
		"⑦ 合体技【乌鲁兹·三角】在表里")
	t.ok(str(MithrilV03Cards.卡("V3_U7_U1").get("卡类")) == "大招槽卡"
		and not _真(MithrilV03Cards.卡("V3_U7_U1").get("武器牌")),
		"⑦ `λ 驱动·启动` 在**大招槽**里，且 `is_weapon = false`（打出不销毁主武器）")
	t.ok(str(MithrilV03Cards.卡("V3_U2_U3").get("卡类")) == "大招槽卡"
		and not _真(MithrilV03Cards.卡("V3_U2_U3").get("武器牌")),
		"⑦ `Uruz 全员突击` 也是 `is_weapon = false` 的大招槽牌")
	t.ok(_真(MithrilV03Cards.卡("V3_U7_U2").get("武器牌")), "⑦ `歼灭作战` 是武器型大招（is_weapon = true）")
	t.ok(str(MithrilV03Cards.卡("V3_U6_SUB").get("卡类")) == "副武器卡", "⑦ `援护射击` = 副武器卡")
	t.ok(MithrilV03Cards.卡("V3_U6_SUB").get("武器") is Dictionary, "⑦ 副武器卡面自带武器数据")
	var 带 := 表.filter(func(c): return _真(c.get("连携")))
	t.ok(带.size() == 8, "⑦ 带【连携】的牌正好 8 张（%d）" % 带.size())
	t.ok(_连携放入数(表) == 6, "⑦ 8 张带【连携】的牌里，6 张写了「连携放入」且指向真牌（实测 %d）" % _连携放入数(表))
	for id in MithrilV03Cards.连携三级:
		t.ok(not MithrilV03Cards.卡(id).is_empty(), "⑦ 三级连携牌 %s 在表里" % id)
	for id in ["V3_U7_LW1", "V3_U7_LW2", "V3_U7_LW3"]:
		t.ok(_真(MithrilV03Cards.卡(id).get("λ版")), "⑦ λ 版武器 %s 带 `λ版` 标记（不进牌库、只由 λ 开启换进来）" % id)
	var u7lv10 := MithrilV03Cards.角色专属牌们按等级("U7", 10)
	var u7lv30 := MithrilV03Cards.角色专属牌们按等级("U7", 30)
	t.ok(u7lv10.size() < u7lv30.size(), "⑦ 肉鸽分层：U7 在 Lv10 解锁 %d 张、Lv30 解锁 %d 张" % [u7lv10.size(), u7lv30.size()])
	var c := _开(["U7", "U6", "U2", "U1", "U8"])
	t.ok(_真(_单位(c, "U7").get("专业军人")) and _真(_单位(c, "U6").get("狙击之王"))
		and _真(_单位(c, "U2").get("小队长")) and _真(_单位(c, "U1").get("冷血"))
		and _真(_单位(c, "U8").get("ECS隐形")),
		"⑦ 五名成员的被动都挂上了（专业军人 / 狙击之王 / 小队长 / 冷血 / ECS 隐形）")

func _连携放入数(表: Array) -> int:
	var n := 0
	for c in 表:
		if not _真(c.get("连携")):
			continue
		var 放 := str(c.get("连携放入", ""))
		if 放 == "":
			continue
		if MithrilV03Cards.卡(放).is_empty():
			continue
		n += 1
	return n

# ==========================================================================================
# 段 8：大招槽
# ==========================================================================================
func _段8_大招槽(t) -> void:
	var c := _开(["U7"])
	var u7 := _单位(c, "U7")
	var 槽们: Array = u7.get("大招槽", [])
	t.ok(槽们.size() == 3, "⑧ 宗介的大招槽里常驻 3 张（%d）" % 槽们.size())
	var 名们: Array = 槽们.map(func(s): return str(s.get("卡", {}).get("名", "")))
	t.ok(名们.has("λ 驱动·启动") and 名们.has("歼灭作战") and 名们.has("λ 驱动·极限放出"),
		"⑧ 三张分别是 λ 驱动·启动 / 歼灭作战 / λ 驱动·极限放出（%s）" % str(名们))
	var 库id: Array = (u7.get("专属牌库") as Array).map(func(c2): return str(c2.get("id", "")))
	var 混了 := false
	for 槽 in 槽们:
		混了 = 混了 or 库id.has(str((槽 as Dictionary).get("卡", {}).get("id", "")))
	t.ok(not 混了, "⑧ 大招槽的牌**一张都没有进 `u.专属牌库`**（抽牌堆里查不到）")
	u7["战意"] = 0.0
	var 启 := DeckFlow.找大招槽(u7, "V3_U7_U1")
	t.ok(str(DeckFlow.大招不可打原因(c, u7, 启)).contains("战意"),
		"⑧ 战意 0 时 λ 驱动·启动 置灰，理由写明「战意」（%s）" % DeckFlow.大招不可打原因(c, u7, 启))
	u7["战意"] = 80.0
	DeckFlow.阶段初_检查(c)
	t.ok(DeckFlow.大招可用吗(c, u7, DeckFlow.找大招槽(u7, "V3_U7_U1")), "⑧ 战意 80 时 λ 驱动·启动 亮起")
	t.ok(str(DeckFlow.大招不可打原因(c, u7, DeckFlow.找大招槽(u7, "V3_U7_U3"))).contains("λ"),
		"⑧ λ 驱动·极限放出 的状态门槛「λ 开启中」未满足 → 置灰")
	var r := DeckFlow.打出大招(c, "U7", "V3_U7_U1")
	t.ok(bool(r.get("成功")), "⑧ 打出 λ 驱动·启动成功（%s）" % str(r.get("原因", "")))
	t.ok(_真(DeckFlow.λ开启(u7)), "⑧ λ 驱动开启")
	t.ok(not _真(u7.get("主武器已销毁")), "⑧ `is_weapon = false` → **不销毁主武器**")
	t.ok(absf(float(DeckFlow.找大招槽(u7, "V3_U7_U1").get("cd")) - 2.0) < 0.001, "⑧ 打出后进冷却（cd = 2）")
	t.ok(_真(DeckFlow.找大招槽(u7, "V3_U7_U1").get("本回合已打")), "⑧ 记「本回合已打」")
	var r2 := DeckFlow.打出大招(c, "U7", "V3_U7_U1")
	t.ok(not bool(r2.get("成功")) and str(r2.get("原因")).contains("本回合"),
		"⑧ 断路器 2：同一张大招**同一回合再打一次 → 拒绝**（%s）" % str(r2.get("原因")))
	t.ok(not _真(DeckFlow.找大招槽(u7, "V3_U7_U2").get("已解锁")), "⑧ 歼灭作战的获取条件「第 2 回合起」未满足 → 未解锁")
	c["turn"] = 2.0
	DeckFlow.阶段初_检查(c)
	t.ok(_真(DeckFlow.找大招槽(u7, "V3_U7_U2").get("已解锁")), "⑧ 到第 2 回合 → 歼灭作战**永久解锁**")
	DeckFlow.阶段初_冷却与维持(c)
	u7["战意"] = 80.0
	var r3 := DeckFlow.打出大招(c, "U7", "V3_U7_U2")
	t.ok(bool(r3.get("成功")), "⑧ 歼灭作战打得出来（%s）" % str(r3.get("原因", "")))
	t.ok(_真(u7.get("主武器已销毁")), "⑧ `is_weapon = true` → 打出后**销毁本回合其余主武器**")
	t.ok(absf(float(DeckFlow.找大招槽(u7, "V3_U7_U2").get("cd")) - 4.0) < 0.001, "⑧ 歼灭作战进 4 回合冷却")
	t.ok(_日志有(c, "〔大招槽〕"), "⑧ 战斗日志里有一条〔大招槽〕")

# ==========================================================================================
# 段 9：副武器栏
# ==========================================================================================
func _段9_副武器栏(t) -> void:
	var c := _开(["U6"])
	var u6 := _单位(c, "U6")
	var 栏: Array = u6.get("副武器栏", [])
	t.ok(栏.size() == 1 and str((栏[0] as Dictionary).get("卡", {}).get("名")) == "援护射击",
		"⑨ 克鲁兹的副武器栏里常驻【援护射击】")
	t.ok(int((栏[0] as Dictionary).get("本回合可用", 0)) == 1, "⑨ 每回合默认可以打 1 次")
	u6["战意"] = 60.0
	u6["slot"] = 4.0
	var 敌 := _敌单位(c, 4)
	敌["hp"] = 40000.0
	敌["maxHp"] = 40000.0
	var r1 := Btl.打出武器栏卡(c, "U6", "V3_U6_W1", str(敌.get("key")))
	t.ok(bool(r1.get("成功")), "⑨ 克鲁兹打出 76mm 狙击炮（%s）" % str(r1.get("原因", "")))
	t.ok(_真(u6.get("主武器已销毁")), "⑨ 打完主武器 → 主武器已销毁")
	t.ok(str(DeckFlow.副武器不可打原因(c, u6, 栏[0])) == "",
		"⑨ 主武器被销毁**不影响副武器**（援护射击仍然可打）")
	var r2 := DeckFlow.打出副武器(c, "U6", "V3_U6_SUB", str(敌.get("key")))
	t.ok(bool(r2.get("成功")), "⑨ 副武器打得出来（%s）" % str(r2.get("原因", "")))
	t.ok(_真(u6.get("主武器已销毁")), "⑨ 副武器**不恢复也不销毁**主武器（仍是已销毁）")
	t.ok(int((栏[0] as Dictionary).get("本回合已用", 0)) == 1, "⑨ 本回合已用 1/1")
	var r3 := DeckFlow.打出副武器(c, "U6", "V3_U6_SUB", str(敌.get("key")))
	t.ok(not bool(r3.get("成功")) and str(r3.get("原因")).contains("次数"),
		"⑨ 同一回合第二次 → 拒绝（%s）" % str(r3.get("原因")))
	t.ok(DeckFlow.副武器可用次数(u6) == 0, "⑨ `副武器可用次数` = 0")
	# 「交叉火力 / 天才狙击手」+1 次
	c["v3副武器加"] = 1
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(int((栏[0] as Dictionary).get("本回合可用", 0)) == 2,
		"⑨ 带 `v3副武器加 = 1`（交叉火力 / 天才狙击手）→ 本回合可用 2 次")
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(int((栏[0] as Dictionary).get("本回合可用", 0)) == 1, "⑨ 下一回合次数重置回 1（加成不残留）")
	# 「屏息」
	(栏[0] as Dictionary)["禁用"] = true
	t.ok(str(DeckFlow.副武器不可打原因(c, u6, 栏[0])).contains("屏息"),
		"⑨ 「屏息」→ 本回合不能打副武器（理由写明屏息）")

# ==========================================================================================
# 段 10：待入库 → push_front
# ==========================================================================================
func _段10_待入库(t) -> void:
	var c := _开(["U7"])
	var u7 := _单位(c, "U7")
	var 有 := false
	for x in u7.get("待入库", []):
		if str((x as Dictionary).get("id", "")) == "V3_U7_S6":
			有 = true
	t.ok(有, "⑩ 「集中想象」（入库条件：宗介战意 ≥ 30）开战时进 `u.待入库`")
	t.ok(not _有卡(u7.get("专属牌库", []), "V3_U7_S6"), "⑩ 它**不在**抽牌堆里（还没入库）")
	u7["战意"] = 40.0
	var 库长前 := (u7.get("专属牌库") as Array).size()
	DeckFlow.阶段初_检查(c)
	t.ok(not _有卡(u7.get("待入库", []), "V3_U7_S6"), "⑩ 条件满足 → 从 `u.待入库` 移出")
	var 库: Array = u7.get("专属牌库", [])
	t.ok(库.size() == 库长前 + 1 and str((库[0] as Dictionary).get("id", "")) == "V3_U7_S6",
		"⑩ **`push_front` 到抽牌堆顶**（下一张抽到的就是它；库 %d → %d，顶上是 %s）" % [
			库长前, 库.size(), str((库[0] as Dictionary).get("名", ""))])
	t.ok(_日志有(c, "〔待入库〕"), "⑩ 记了一条〔待入库〕日志（飘字提示的数据源）")
	DeckFlow.阶段初_检查(c)
	t.ok((u7.get("专属牌库") as Array).size() == 库长前 + 1, "⑩ 条件再满足也不会重复入库（每张只入库一次）")
	# 公有待入库
	var c2 := _开(["U2"])
	var 待: Array = c2.get("公有待入库", [])
	t.ok(not 待.is_empty(), "⑩ 带入库条件的公有牌开战时进 `ctx.公有待入库`（%d 张）" % 待.size())
	var 首 := str((待[0] as Dictionary).get("id", ""))
	c2["turn"] = 3.0
	DeckFlow.检查公有待入库(c2)
	t.ok(str((c2.get("公有牌库") as Array)[0].get("id", "")) == 首,
		"⑩ 公有牌库第一张就是刚入库的牌（%s）" % 首)

# ==========================================================================================
# 段 11：满手停抽（精神 4 / 公有 6）
# ==========================================================================================
func _段11_满手停抽(t) -> void:
	var c := _开(["U7", "U6", "U2"])
	var u7 := _单位(c, "U7")
	u7["专属手牌"] = []
	while (u7.get("专属牌库") as Array).size() < 8:
		(u7.get("专属牌库") as Array).append({"id": "填", "名": "填", "卡类": "专属精神牌", "耗气": 1.0, "限次": 1.0})
	Setup.抽专属牌(u7, 10)
	t.ok((u7.get("专属手牌") as Array).size() == 4,
		"⑪ 精神手牌上限 4：连抽 10 张也只进 4 张（%d）" % (u7.get("专属手牌") as Array).size())
	var 库前 := (u7.get("专属牌库") as Array).size()
	Setup.抽专属牌(u7, 1)
	t.ok((u7.get("专属牌库") as Array).size() == 库前, "⑪ 满 4 张时**停抽**，牌留在牌库顶不烧牌（库还是 %d 张）" % 库前)
	c["公有手牌"] = []
	while (c.get("公有牌库") as Array).size() < 10:
		(c.get("公有牌库") as Array).append({"id": "填公", "名": "填公", "卡类": "公有牌", "层级": "势力", "归属": "秘银"})
	Setup.抽公有牌(c, 10)
	t.ok((c.get("公有手牌") as Array).size() == 6,
		"⑪ 公有手牌上限 6：连抽 10 张只进 6 张（%d）" % (c.get("公有手牌") as Array).size())
	var 公库前 := (c.get("公有牌库") as Array).size()
	Setup.抽公有牌(c, 1)
	t.ok((c.get("公有牌库") as Array).size() == 公库前, "⑪ 满 6 张时停抽（公有牌库还是 %d 张）" % 公库前)

# ==========================================================================================
# 段 12：连携牌库
# ==========================================================================================
func _段12_连携牌库(t) -> void:
	var c := _开(["U7", "U6", "U2"])
	var u2 := _单位(c, "U2")
	var u6 := _单位(c, "U6")
	t.ok((c.get("连携牌库") as Array).size() == 4, "⑫ 开场连携牌库只有 4 张一级牌（%d）" % (c.get("连携牌库") as Array).size())
	var 状 := DeckFlow.连携牌库状态(c)
	t.ok(int(状["一级"]) == 4 and int(状["二级"]) == 0 and int(状["三级"]) == 0, "⑫ 徽章：一 4 / 二 0 / 三 0")
	t.ok(c.get("上张打出牌") == null, "⑫ 我方阶段初 `ctx.上张打出牌` 就是 null")
	u2["战意"] = 100.0
	var 秘银牌 := {"id": "试A", "名": "试A", "归属": "秘银", "种类": "角色", "层级": "角色", "角色所属势力": "秘银"}
	DeckFlow.记上张打出牌(c, u2, 秘银牌)
	t.ok(_真(c.上张打出牌.get("is_mithril_card")), "⑫ 秘银成员打秘银牌 → `is_mithril_card = true`")
	var 职业牌 := {"id": "试B", "名": "试B", "归属": "特种", "种类": "职业", "层级": "职业"}
	DeckFlow.记上张打出牌(c, u2, 职业牌)
	t.ok(not _真(c.上张打出牌.get("is_mithril_card")), "⑫ 通用职业牌（特种）→ `is_mithril_card = false`（连携断开）")
	# 非秘银成员打的秘银牌也不算
	var 非秘银 := {"id": "试D", "名": "试D", "归属": "秘银", "种类": "角色", "层级": "角色"}
	DeckFlow.记上张打出牌(c, {"key": "B1", "slot": 0, "hp": 1, "side": "ally"}, 非秘银)
	t.ok(not _真(c.上张打出牌.get("is_mithril_card")), "⑫ **非秘银成员**打的牌一律不算秘银牌")
	var 连携卡 := MithrilV03Cards.卡("V3_U6_U2")
	t.ok(not DeckFlow.连携就绪(c, 连携卡), "⑫ 上一张不是秘银牌 → 带【连携】的牌不亮金边")
	DeckFlow.记上张打出牌(c, u6, {"id": "试C", "名": "试C", "归属": "秘银", "种类": "势力", "层级": "势力"})
	t.ok(DeckFlow.连携就绪(c, 连携卡), "⑫ 上一张是秘银牌 → 带【连携】的牌亮金边（`连携就绪` = true）")
	var 库前: int = (c.get("连携牌库") as Array).size()
	var 手前: int = (c.get("公有手牌") as Array).size()
	var 记 := DeckFlow.触发连携(c, 连携卡)
	t.ok(_真(记.get("触发")), "⑫ 触发【连携】（%s）" % str(记.get("原因", "")))
	t.ok((c.get("公有手牌") as Array).size() == 手前 + 1,
		"⑫ Step 1 先抽：公有手牌 +1（%d → %d）" % [手前, (c.get("公有手牌") as Array).size()])
	t.ok((c.get("连携牌库") as Array).size() == 库前, "⑫ 抽走 1 张、又放进 1 张（库还是 %d 张）" % 库前)
	t.ok(_有卡(c.get("连携牌库", []), "V3_L2_FIRE"), "⑫ Step 2 后放：更强的【Uruz 各员，开火】进了连携牌库")
	t.ok(_日志有(c, "〔连携〕"), "⑫ 日志里有〔连携〕")
	# 公有手牌满 6 → 不抽（连携牌留在库里）
	c["公有手牌"] = []
	for i in range(6):
		(c.get("公有手牌") as Array).append({"id": "满%d" % i, "名": "满%d" % i})
	var 库前2: int = (c.get("连携牌库") as Array).size()
	DeckFlow.记上张打出牌(c, u6, 秘银牌)
	DeckFlow.触发连携(c, 连携卡)
	t.ok((c.get("公有手牌") as Array).size() == 6, "⑫ 公有手牌满 6 → **不抽**（仍是 6 张）")
	t.ok((c.get("连携牌库") as Array).size() == 库前2 + 1,
		"⑫ 不抽也不浪费：连携牌留在库里，Step 2 的放入照旧（%d → %d）" % [库前2, (c.get("连携牌库") as Array).size()])
	# 打出连携牌
	c["公有手牌"] = [MithrilV03Cards.卡("V3_L1_AMMO")]
	u2["主武器已销毁"] = false
	var r := DeckFlow.打出连携牌(c, "U2", "V3_L1_AMMO")
	t.ok(bool(r.get("成功")), "⑫ 打出连携牌【补给弹匣】成功（%s）" % str(r.get("原因", "")))
	t.ok(not _真(u2.get("主武器已销毁")), "⑫ 连携牌**不占主武器**（不销毁主武器）")
	t.ok(_有卡(c.get("连携牌库", []), "V3_L1_AMMO"), "⑫ 一级连携牌打出后**回连携牌库**")
	c["公有手牌"] = [MithrilV03Cards.卡("V3_L3_SUPPORT")]
	var r3 := DeckFlow.打出连携牌(c, "U2", "V3_L3_SUPPORT")
	t.ok(bool(r3.get("成功")), "⑫ 打出三级连携牌【达纳号·紧急支援】（%s）" % str(r3.get("原因", "")))
	t.ok(not _有卡(c.get("连携牌库", []), "V3_L3_SUPPORT"), "⑫ 三级连携牌打出后**不回库**")
	t.ok(_有卡(c.get("移出牌", []), "V3_L3_SUPPORT"), "⑫ 三级连携牌移出本场（进 `ctx.移出牌`）")
	var c2 := _开(["B1"])
	c2["公有手牌"] = [MithrilV03Cards.卡("V3_L1_AMMO")]
	var rb := DeckFlow.打出连携牌(c2, "B1", "V3_L1_AMMO")
	t.ok(not bool(rb.get("成功")) and str(rb.get("原因")).contains("秘银"),
		"⑫ 非秘银成员打连携牌 → 拒绝（%s）" % str(rb.get("原因")))

# ==========================================================================================
# 段 13：三条防死循环断路器
# ==========================================================================================
func _段13_断路器(t) -> void:
	var c := _开(["U6", "U2"])
	var 放牌 := MithrilV03Cards.卡("V3_U6_U3")
	var 秘银牌 := {"id": "试", "名": "试", "归属": "秘银", "种类": "势力", "层级": "势力"}
	DeckFlow.记上张打出牌(c, _单位(c, "U6"), 秘银牌)
	DeckFlow.触发连携(c, 放牌)
	var 计 := 0
	for x in c.get("连携牌库", []):
		if str((x as Dictionary).get("id", "")) == "V3_L3_SUPPORT":
			计 += 1
	t.ok(计 == 1, "⑬ 断路器 1：三级连携牌第一次放入成功（库里有 1 张）")
	DeckFlow.记上张打出牌(c, _单位(c, "U6"), 秘银牌)
	var 记2 := DeckFlow.触发连携(c, 放牌)
	计 = 0
	for x in c.get("连携牌库", []):
		if str((x as Dictionary).get("id", "")) == "V3_L3_SUPPORT":
			计 += 1
	t.ok(计 == 1, "⑬ 断路器 1：**同一张三级牌不再放入第二次**（库里仍是 1 张）")
	t.ok(str(记2.get("原因")).contains("断路器 1"), "⑬ 拒绝理由写明「断路器 1」（%s）" % str(记2.get("原因")))
	var u7 := _单位(c, "U7")
	if u7.is_empty():
		u7 = _单位(_开(["U7"]), "U7")
	u7["主武器已销毁"] = true
	u7["本回合再动已用"] = false
	t.ok(DeckFlow.再动(c, u7), "⑬ 断路器 3：第一次再动成功（主武器恢复）")
	t.ok(not _真(u7.get("主武器已销毁")), "⑬ 再动后 `主武器已销毁 = false`")
	u7["主武器已销毁"] = true
	t.ok(not DeckFlow.再动(c, u7), "⑬ 断路器 3：**同一回合第二次再动 → 拒绝**")
	t.ok(_日志有(c, "〔断路器 3〕"), "⑬ 日志里写明「〔断路器 3〕」")

# ==========================================================================================
# 段 14：宗介【λ 驱动】状态机
# ==========================================================================================
func _段14_λ驱动(t) -> void:
	var c := _开(["U7", "U2"])
	var u7 := _单位(c, "U7")
	u7["战意"] = 100.0
	DeckFlow.阶段初_检查(c)
	var r := DeckFlow.打出大招(c, "U7", "V3_U7_U1")
	t.ok(bool(r.get("成功")), "⑭ 打出 λ 驱动·启动（%s）" % str(r.get("原因", "")))
	t.ok(_真(DeckFlow.λ开启(u7)), "⑭ λ 开启")
	t.ok(absf(float(u7.get("shieldHp")) - 4000.0) < 0.001 and absf(float(u7.get("护盾上限")) - 4000.0) < 0.001,
		"⑭ 获得 λ 力场 4000（护盾 %d / 上限 %d）" % [int(u7.get("shieldHp")), int(u7.get("护盾上限"))])
	var 栏id: Array = (u7.get("武器栏") as Array).map(func(c2): return str((c2 as Dictionary).get("id", "")))
	t.ok(栏id.has("V3_U7_LW1") and 栏id.has("V3_U7_LW2"),
		"⑭ 武器栏实时替换：57mm 散弹炮 → λ 散弹炮、单分子刀 → λ 单分子刀（%s）" % str(栏id))
	t.ok(栏id.has("V3_U7_LW3"), "⑭ 武器栏新增常驻【隔空 λ 拳】")
	t.ok(not 栏id.has("V3_U7_W1"), "⑭ 普通版 57mm 散弹炮已经被换走")
	t.ok(str(DeckFlow.λ文案(u7)).contains("λ 驱动开启") and str(DeckFlow.λ文案(u7)).contains("4000"),
		"⑭ 展示文案：%s" % DeckFlow.λ文案(u7))
	var 战意前: float = Btl.战意(u7)
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(absf(Btl.战意(u7) - (战意前 - 10.0 + Params.回合初战意())) < 0.001,
		"⑭ 维持：阶段初先扣 10 战意再按回合 +5（%.0f → %.0f）" % [战意前, Btl.战意(u7)])
	t.ok(absf(float(u7.get("shieldHp")) - 4000.0) < 0.001, "⑭ 每个我方阶段初 λ 力场回满 4000")
	DeckFlow.λ状态(u7)["免除下次维持"] = true
	var 战意前2: float = Btl.战意(u7)
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(absf(Btl.战意(u7) - (战意前2 + Params.回合初战意())) < 0.001,
		"⑭ `免除下次维持`（集中想象 / Uruz-7 冷静点）→ 这一回合不扣维持")
	u7["战意"] = 45.0
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(not _真(DeckFlow.λ开启(u7)), "⑭ 扣完维持后战意 < 40 → **λ 关闭**（战意 %d）" % int(u7.get("战意")))
	t.ok(absf(float(u7.get("shieldHp"))) < 0.001, "⑭ 关闭后 λ 力场消失（护盾 0）")
	var 栏id2: Array = (u7.get("武器栏") as Array).map(func(c2): return str((c2 as Dictionary).get("id", "")))
	t.ok(not 栏id2.has("V3_U7_LW1") and 栏id2.has("V3_U7_W1"), "⑭ 武器变回普通版（%s）" % str(栏id2))
	t.ok(float(DeckFlow.找大招槽(u7, "V3_U7_U1").get("cd")) >= 2.0, "⑭ 关闭后 λ 驱动·启动进 2 回合冷却")
	# λ 觉醒
	u7["战意"] = 100.0
	DeckFlow.找大招槽(u7, "V3_U7_U1")["cd"] = 0.0
	DeckFlow.找大招槽(u7, "V3_U7_U1")["本回合已打"] = false
	DeckFlow.阶段初_检查(c)
	DeckFlow.打出大招(c, "U7", "V3_U7_U1")
	t.ok(_真(DeckFlow.λ开启(u7)), "⑭ 再启动一次（前面关闭过）")
	u7["shieldHp"] = 0.0
	t.ok(not DeckFlow.记录力场被破(c, u7, 100.0), "⑭ 第 1 次力场被破：还不觉醒")
	t.ok(int(DeckFlow.λ状态(u7).get("力场被破次数")) == 1, "⑭ 被破次数记到 1")
	DeckFlow.λ回满力场(c, u7)
	u7["shieldHp"] = 0.0
	t.ok(DeckFlow.记录力场被破(c, u7, 100.0), "⑭ 第 2 次力场被破 → **触发 λ 觉醒**")
	t.ok(_真(DeckFlow.λ觉醒(u7)) and _真(DeckFlow.λ开启(u7)), "⑭ λ 觉醒：永久开启")
	t.ok(str(DeckFlow.λ文案(u7)).contains("λ 觉醒"), "⑭ 展示文案：%s" % DeckFlow.λ文案(u7))
	var 战意前3: float = Btl.战意(u7)
	DeckFlow.阶段初_冷却与维持(c)
	t.ok(absf(Btl.战意(u7) - (战意前3 + Params.回合初战意())) < 0.001, "⑭ 觉醒后**不再扣维持**")
	t.ok(absf(float(DeckFlow.找大招槽(u7, "V3_U7_U3").get("cd"))) < 0.001, "⑭ 觉醒时【λ 驱动·极限放出】冷却归 0")

# ==========================================================================================
# 段 15：门面（GameSession）
# ==========================================================================================
func _段15_门面(t) -> void:
	var c := _开(["U7", "U6", "U2"])
	var s := GameSession.new()
	s.存档路径 = "res://.godot/tmp_mith3_门面.json"
	s.battle_ctx = c
	s.screen = "battle"
	s.selected_unit_id = "U7"
	s.clear_errors()
	t.ok(s.v03_active(), "⑮ 门面 `v03_active()` = true")
	var 上 := s.upper_hand_cards()
	var 区们: Array = 上.map(func(x): return str((x as Dictionary).get("区", "")))
	t.ok(区们.size() > 0, "⑮ 上排一共 %d 张（%s）" % [区们.size(), str(区们)])
	t.ok(区们.has("主武器卡"), "⑮ 上排有【武器栏】（主武器卡）")
	t.ok(区们.has("专属精神牌") or 区们.has("大招槽卡"), "⑮ 上排有精神手牌 / 大招槽")
	var 大 := s.ultimate_slots()
	t.ok(大.size() == 3, "⑮ 上排有【大招槽】3 张（%d）" % 大.size())
	var 灰 := 0
	for x in 大:
		if not bool((x as Dictionary).get("可打", false)) and str((x as Dictionary).get("原因", "")) != "":
			灰 += 1
	t.ok(灰 >= 1, "⑮ 大招槽置灰时**写明原因**（%d 张灰着）" % 灰)
	s.selected_unit_id = "U6"
	var 副 := s.sub_weapon_cards()
	t.ok(副.size() == 1, "⑮ 克鲁兹的上排有【副武器栏】1 张（援护射击）")
	var ldc := s.link_library_state()
	t.ok(int(ldc.get("一级", -1)) == 4 and str(ldc.get("文案", "")).contains("连携牌库"),
		"⑮ 连携牌库徽章：%s" % str(ldc.get("文案", "")))
	t.ok(str(ldc.get("悬停", "")).contains("TDD-1"), "⑮ 徽章悬停明细里列出库内卡牌")
	t.ok(not bool(s.last_card_state().get("有", true)), "⑮ 还没出牌时 `last_card_state().有 = false`")
	var u6 := _单位(c, "U6")
	u6["战意"] = 100.0
	u6["slot"] = 4.0
	_敌单位(c, 4)["hp"] = 40000.0
	_敌单位(c, 4)["maxHp"] = 40000.0
	Btl.打出武器栏卡(c, "U6", "V3_U6_W1", str(_敌单位(c, 4).get("key")))
	var 上张2 := s.last_card_state()
	t.ok(bool(上张2.get("有")) and _真(上张2.get("就绪")),
		"⑮ 秘银成员打完主武器后：%s" % str(上张2.get("文案", "")))
	var u7 := _单位(c, "U7")
	u7["战意"] = 100.0
	u7["slot"] = 0.0
	DeckFlow.阶段初_检查(c)
	var rλ := DeckFlow.打出大招(c, "U7", "V3_U7_U1")
	s.selected_unit_id = "U7"
	var λ := s.lambda_state_of("U7")
	t.ok(bool(λ.get("开启")) and str(λ.get("文案", "")).contains("力场"),
		"⑮ `lambda_state_of` 给出 λ 状态与力场：%s（打出结果 %s / λ开启 %s / λ文案 %s）" % [
			str(λ.get("文案", "")), str(rλ), str(DeckFlow.λ开启(u7)), str(DeckFlow.λ文案(u7))])
	# 距离提示：近战（1–2）打距离 3 的敌方后排（λ 开启后武器栏已经是 λ 版，用 λ 单分子刀 1–3 验）
	var 远敌 := _敌单位(c, 4)
	远敌["hp"] = 40000.0
	var 闸 := s.weapon_range_check("U7", "V3_U7_LW2", str(远敌.get("key")))
	t.ok(not bool(闸.get("ok")) and str(闸.get("文案", "")).contains("打不到"),
		"⑮ 近战打敌方后排（前排还有人）→ 门面给出明确提示：%s" % str(闸.get("文案", "")))
	# 隔空 λ 拳 1–4 + 无视遮挡 → 打得到，文案给出「距离 N · 目标名」
	var 闸2 := s.weapon_range_check("U7", "V3_U7_LW3", str(远敌.get("key")))
	t.ok(bool(闸2.get("ok")) and str(闸2.get("文案", "")).contains("距离"),
		"⑮ 打得着时给出「距离 N · 目标名」：%s" % str(闸2.get("文案", "")))
	var 计数 := s.deck_counts("U7")
	t.ok(int(计数.get("手牌上限", 0)) == 4 and int(计数.get("公有上限", 0)) == 6,
		"⑮ `deck_counts` 报出上限 4 / 6（精神 %d / 公有 %d）" % [int(计数.get("手牌上限")), int(计数.get("公有上限"))])
	t.ok(s.errors is Array and (s.errors as Array).is_empty(), "⑮ 整段门面调用零报错%s" % str(s.errors))

# ==========================================================================================
# 段 16：整场跑完
# ==========================================================================================
func _段16_整场跑完(t) -> void:
	var c := _开(["U7", "U6", "U2", "U1", "U8"], 30)
	t.ok((c.get("allies") as Array).size() == 5, "⑯ 我方 5 台")
	var 齐 := true
	for u in c.get("allies", []):
		if u is Dictionary and (u.get("武器栏") as Array).is_empty():
			齐 = false
	t.ok(齐, "⑯ 每台机体的武器栏都非空（常驻主武器卡）")
	var 前 := JSON.stringify(c.get("上张打出牌"))
	DeckFlow.连携牌库状态(c)
	DeckFlow.连携牌库状态(c)
	t.ok(JSON.stringify(c.get("上张打出牌")) == 前, "⑯ `连携牌库状态` 是纯读（连调两遍状态不变）")
	var 局 := Setup.跑完(_队(["U7", "U6", "U2", "U1", "U8"], 30), _敌(), 种子,
		{"单机牌组": true, "秘银v03": true})
	t.ok(局.get("result") != null, "⑯ 整场跑完：%s（%s）" % [
		str((局.get("result") as Dictionary).get("结果", "")), str((局.get("result") as Dictionary).get("原因", ""))])
	var 有战斗 := false
	for e in 局.get("log", []):
		if e is Dictionary and str((e as Dictionary).get("类型", "")) in ["攻击", "武器栏", "大招槽", "连携牌", "副武器"]:
			有战斗 = true
			break
	t.ok(有战斗, "⑯ 战斗日志里有真实出牌记录（类型 ∈ 攻击 / 武器栏 / 大招槽 / 连携牌 / 副武器）")

# ==========================================================================================
# 段 17：★ 2026-10-22「试玩三轮修复」（任务单 P3-3 / P3-4）
#
#   ⑰A `V3_U2_U3 Uruz 全员突击`：
#       · **不销毁毛的主武器栏**（卡面写明「不算武器牌」—— 从前错写了 `施["主武器已销毁"] = true`）；
#       · 战报**主行**里写清「战意+10 / 主武器伤害+20% / 不算武器牌 / 点名吃到增益的队友」，
#         不再只写一个牌名。
#   ⑰B `V3_F_2 火力支援请求`（**公有牌带非空 `武器` 字典**）：从前静默跳过、1500 曲射一发都不打；
#       现在真的结算一次武器攻击，并把攻击摘要并入「打出【XX】 → …」那一行主日志。
#   ⑰C 空 `武器` 字典（`ATX2_U3 好运加护·满开` 的 `"武器": {}`）**不算武器型** —— 不误触发 0 伤害攻击。
#   ⑰D `CardEffects._摘要` 不再产出 `（0 台）` 这种空尾缀。
# ==========================================================================================
func _段17_试玩三轮修复(t) -> void:
	# ---------- ⑰A `Uruz 全员突击`：不销毁主武器栏 + 主行写清具体数值 ----------
	var c := _开(["U7", "U6", "U2"])
	var u2 := _单位(c, "U2")
	var u7 := _单位(c, "U7")
	var u6 := _单位(c, "U6")
	t.ok(not u2.is_empty() and not u7.is_empty() and not u6.is_empty(),
		"⑰A 秘银三人（宗介 / 克鲁兹 / 毛）都在场")
	var 槽 := DeckFlow.找大招槽(u2, "V3_U2_U3")
	t.ok(not 槽.is_empty(), "⑰A 毛的大招槽里有【Uruz 全员突击】")
	if not 槽.is_empty():
		槽["已解锁"] = true
		槽["cd"] = 0.0
		槽["本回合已打"] = false
		u2["战意"] = 100.0
		u7["战意"] = 0.0
		u6["战意"] = 0.0
		u2["主武器已销毁"] = false
		var r := DeckFlow.打出大招(c, "U2", "V3_U2_U3")
		t.ok(_真(r.get("成功")), "⑰A 打出【Uruz 全员突击】成功（%s）" % str(r.get("原因", "")))
		t.ok(not _真(u2.get("主武器已销毁")),
			"★★ ⑰A 打完这张**不销毁毛的主武器栏**（卡面：不算武器牌）")
		t.ok(absf(float(u7.get("战意", 0.0)) - 10.0) < 0.001 and absf(float(u6.get("战意", 0.0)) - 10.0) < 0.001,
			"★★ ⑰A 宗介 / 克鲁兹 战意各 +10（现 %.0f / %.0f）"
			% [float(u7.get("战意", 0.0)), float(u6.get("战意", 0.0))])
		var 主行 := _最后文本(c, "大招槽")
		t.ok(主行.contains("打出【Uruz 全员突击】"), "⑰A 战报主行 = 「%s」" % 主行)
		t.ok(主行.contains("战意+10"), "★★ ⑰A 战报**主行**写明「战意+10」（不再只写牌名）")
		t.ok(主行.contains("主武器伤害+20%"), "★★ ⑰A 战报**主行**写明「主武器伤害+20%」")
		t.ok(主行.contains("不算武器牌"), "⑰A 主行同时说明「不算武器牌，不销毁主武器栏」")
		t.ok(主行.contains(str(u7.get("name", ""))) or 主行.contains(str(u6.get("name", ""))),
			"⑰A 主行里**点名**吃到增益的队友")
		t.ok(主行.contains(" → "), "★★ ⑰A 主行带「 → 具体效果摘要」（不是只有「打出【】」）")
		var 事 := _最后事件(c, "大招槽")
		t.ok(事.get("效果摘要") is Array and not (事.get("效果摘要") as Array).is_empty(),
			"⑰A 事件里也带 `效果摘要` 数组（%d 条）" % ((事.get("效果摘要") as Array).size() if 事.get("效果摘要") is Array else 0))

	# ---------- ⑰B 公有牌带非空 `武器`：`V3_F_2 火力支援请求` 真的打出 1500 曲射 ----------
	var c2 := _开(["U2", "U7"])
	var u2b := _单位(c2, "U2")
	var 敌 := _敌单位(c2, 0)
	t.ok(not u2b.is_empty() and not 敌.is_empty(), "⑰B 毛与第一台敌机都在场")
	if not u2b.is_empty() and not 敌.is_empty():
		if not (c2.get("公有手牌") is Array):
			c2["公有手牌"] = []
		var 牌 := MithrilV03Cards.卡("V3_F_2").duplicate(true)
		牌["_实例号"] = 9001
		(c2["公有手牌"] as Array).append(牌)
		u2b["战意"] = 100.0
		敌["hp"] = 100000.0
		敌["maxHp"] = 100000.0
		# ★ 这一段验的是「带 `武器` 的公有牌**真的结算了一次攻击**」，不是验命中率 ——
		#   把闪避压到负值钉死命中（否则 15% 命中的曲射会随机未命中，断言就变成看运气）。
		敌["eva"] = -900.0
		var 血前 := float(敌.get("hp", 0.0))
		var 日志前 := (c2.get("log") as Array).size()
		var r2 := Btl.打出精神或公有牌(c2, "U2", "9001", str(敌.get("key")))
		t.ok(_真(r2.get("成功")), "⑰B 打出【火力支援请求】成功（%s）" % str(r2.get("原因", "")))
		t.ok(float(敌.get("hp", 0.0)) < 血前 - 0.5,
			"★★ ⑰B 这张**带 `武器` 的公有牌真的打出了伤害**（敌机 HP %.0f → %.0f）"
			% [血前, float(敌.get("hp", 0.0))])
		var 攻行 := ""
		for e in (c2.get("log") as Array).slice(日志前):
			if e is Dictionary and str((e as Dictionary).get("类型", "")) == "攻击":
				攻行 = str((e as Dictionary).get("文本", ""))
		t.ok(not 攻行.is_empty(), "★★ ⑰B 战斗记录里有一条【攻击】（%s）" % 攻行)
		var 主2 := _最后文本(c2, "公有牌")
		t.ok(主2.contains("打出【火力支援请求】"),
			"⑰B 战报主行 = 「%s」" % 主2)
		t.ok(主2.contains(" → "), "★★ ⑰B 主行把攻击摘要并进来了（不再只有「打出【火力支援请求】（战意 -10）」）")

	# ---------- ⑰C 空 `武器` 字典不算武器型（`ATX2_U3 好运加护·满开`） ----------
	var 好运 := AtxThree.卡("ATX2_U3")
	t.ok(not 好运.is_empty() and 好运.get("武器") is Dictionary and (好运.get("武器") as Dictionary).is_empty(),
		"⑰C【好运加护·满开】的 `武器` 是**空字典**（只判 `is Dictionary` 就会误触发一次 0 伤害攻击）")
	t.ok(not (好运.get("武器") is Dictionary and not (好运.get("武器") as Dictionary).is_empty()),
		"★★ ⑰C 新判空口径（`is Dictionary and not is_empty()`）= false → 不会误触发攻击，照旧走 `效果`")
	t.ok(好运.get("动作") is String and str(好运.get("动作", "")) == "好运加护满开",
		"⑰C 它靠 `动作`（好运加护满开）结算，`效果` 本来就是空的 —— 空武器字典必须被跳过，否则会多打一发 0 伤害")

	# ---------- ⑰D `CardEffects._摘要` 不再有 `（0 台）` 空尾缀 ----------
	var 空摘 := CardEffects._摘要({"card": {"名": "测试牌"}}, "测试算子", [])
	t.ok(not 空摘.contains("0 台"), "★★ ⑰D `CardEffects._摘要` 不再产出「（0 台）」：%s" % 空摘)
	t.ok(空摘.contains("全场"), "⑰D 没有指定目标时改写「作用于：全场」")
	var 有摘 := CardEffects._摘要({"card": {"名": "测试牌"}}, "测试算子",
		[{"name": "宗介"}, {"name": "毛"}])
	t.ok(有摘.contains("作用于【宗介、毛】") and not 有摘.contains("2 台"),
		"⑰D 有目标时点名（超过 4 台才写台数）：%s" % 有摘)
	# 模糊返回值全部换成「作用于【谁】：具体数值」——直接读两条最有代表性的算子摘要
	var c3 := _开(["U7", "U6", "U2"])
	var u7c := _单位(c3, "U7")
	if not u7c.is_empty():
		c3["_当前出牌者"] = "U7"
		c3["_当前目标"] = str(u7c.get("key", ""))
		var 运 := {"ctx": c3, "card": {"名": "再动测试"}}
		var 再动摘 := MithrilV03Cards.执行算子(运, {"算子": "v03", "动作": "再动"}, [])
		t.ok(再动摘.size() == 1 and str(再动摘[0]).contains("作用于【")
			and str(再动摘[0]).contains("再动"),
			"★★ ⑰D【再动】的摘要带作用目标名与具体效果：%s" % str(再动摘))
		var 想象摘 := MithrilV03Cards.执行算子(运, {"算子": "v03", "动作": "集中想象", "减免": 20}, [])
		t.ok(想象摘.size() == 1 and str(想象摘[0]).contains("作用于【")
			and str(想象摘[0]).contains("门槛 −20"),
			"★★ ⑰D【集中想象】的摘要带作用目标名与具体数值：%s" % str(想象摘))
		var 支援摘 := MithrilV03Cards.执行算子(运, {"算子": "v03", "动作": "紧急支援"}, [])
		t.ok(支援摘.size() == 1 and (str(支援摘[0]).contains("作用于")
			or str(支援摘[0]).contains("再动") or str(支援摘[0]).contains("恢复")),
			"★★ ⑰D【紧急支援】的摘要不再只回一个词：%s" % str(支援摘))
		var 多抽摘 := MithrilV03Cards.执行算子(运, {"算子": "v03", "动作": "连携多抽", "值": 1}, [])
		t.ok(多抽摘.size() == 1 and str(多抽摘[0]).contains("连携多抽 1 张"),
			"★★ ⑰D【连携多抽】的摘要写明张数：%s" % str(多抽摘))
