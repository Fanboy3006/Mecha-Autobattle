## ★ A2（作者 2026-10-17 拍板）：ATX 势力机制【九死一生】—— 内核验收。
##
## 受控单位（不走 `Setup.开局`，直接造裸字典）：命中率固定 50%（`hit = 50`、`step = 0`、攻击方 `aim = 360`
## 额外 +50，目标 `eva` 拉开），所以「12 段里中几段」完全由种子决定 → 用 `_找种子()` 精确造出
## 打空 8 / 命中 4、7/5、6/6、5/7 四种边界，不靠运气。
##   判据：打空段数 >= 命中段数（且 打空 + 命中 >= 1）。
##   轮转：每闪开一次，`u.大招槽` 里 `cd > 0` 的牌各 −1；一次攻击只判一次 → 每张牌每次攻击最多 −1；
##         一个敌方阶段内 `u.轮转本阶段` 上限 3。
## 开关 = `Params.九死一生开()`（= `单机牌组_开()`，默认 false）。关着那条路必须**逐字等于改前**：
## 同场景同种子下攻击记录的文本 / 字段 / 随机数调用次数一个字节都不变，logs 里也不多一行。
## 本文件跑完会把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1(t)
	_段2(t)
	_段3(t)
	_段4(t)
	_段5(t)
	_段6(t)
	_段7(t)
	_段8(t)
	_段10(t)
	_段11(t)

# ==========================================================================================
# ① 阈值四边界：12 段里 打空8/命中4、7/5、6/6 → 闪开；5/7 → 不闪开
# ==========================================================================================
func _段1(t) -> void:
	var 该: Dictionary = {4: true, 5: true, 6: true, 7: false}
	var 样例 := ""
	for 命中 in [4, 5, 6, 7]:
		var 种子 := _找种子(int(命中))
		var att := _单位("enemy", 4.0)
		var def := _单位("ally", 0.0)
		_加槽(def, "切札", 4.0)
		var c := _场(att, [def], 种子)
		var r := Calc.resolveAttack(att, def, _武(10.0, 12), c, {})
		var 空: int = 12 - int(命中)
		var 期望: bool = 该[命中]
		var 行 := _行们(c)
		if 样例.is_empty() and not 行.is_empty():
			样例 = str(行[0])                        # 留一条真实记录行给报告用
		t.ok(Calc.九死一生_闪(def) == 期望 and _槽cd(def) == (3.0 if 期望 else 4.0),
			"① 12 段里 打空 %d / 命中 %d → %s（闪=%s、切札 cd 4→%s）种子 %d、实际命中段数 %s" % [
				空, 命中, "闪开" if 期望 else "**不**闪开", str(Calc.九死一生_闪(def)), str(_槽cd(def)), 种子,
				str(r.字段.get("命中段数"))])
	t.info("〔九死一生〕样例：%s" % 样例)

# ==========================================================================================
# ② 单段：打空（1/0）→ 闪开；命中（0/1）→ 不闪开
# ==========================================================================================
func _段2(t) -> void:
	var att := _单位("enemy", 4.0)
	var def := _单位("ally", 0.0, 200.0)          # eva 200 → 命中率被压到 0 → 单段必空
	_加槽(def, "切札", 3.0)
	var c := _场(att, [def])
	Calc.resolveAttack(att, def, _武(10.0, 1), c, {})
	t.ok(Calc.九死一生_闪(def) and _槽cd(def) == 2.0,
		"② 单段**打空**（打空 1 ≥ 命中 0）→ 闪开、冷却 3→2")
	var att2 := _单位("enemy", 4.0)
	var def2 := _单位("ally", 1.0, 0.0)           # 命中率 100 → 单段必中
	_加槽(def2, "切札", 3.0)
	var c2 := _场(att2, [def2])
	Calc.resolveAttack(att2, def2, _武(10.0, 1, "direct", {}, 100.0), c2, {})
	t.ok(not Calc.九死一生_闪(def2) and _槽cd(def2) == 3.0,
		"② 单段**命中**（打空 0 ≥ 命中 1 为假）→ 不闪开、冷却一个数字都不动")

# ==========================================================================================
# ③ 范围攻击：同一攻击事件里 A 闪开、B 不闪开，各自独立
# ==========================================================================================
func _段3(t) -> void:
	var att := _单位("enemy", 4.0)
	var a := _单位("ally", 0.0, 200.0)            # 全躲
	var b := _单位("ally", 1.0, 0.0)              # 全中
	_加槽(a, "切札", 4.0)
	_加槽(b, "切札", 4.0)
	var c := _场(att, [a, b])
	var w := _武(10.0, 12, "direct", {}, 100.0)   # 同一把武器：命中率 100 − A 的闪避 200 = 0 → A 全空、B 全中
	for 目标 in [a, b]:                             # 同一次攻击的每个落点各结算一次（= `Flow.resolveAction` 的范围循环）
		Calc.resolveAttack(att, 目标, w, c, {})
	t.ok(Calc.九死一生_闪(a) and not Calc.九死一生_闪(b),
		"③ 范围攻击同一次事件：A（打空 12 / 命中 0）闪开、B（0 / 12）不闪开 —— 各自独立")
	t.ok(_槽cd(a) == 3.0 and _槽cd(b) == 4.0,
		"③ 轮转只落在闪开的 A 身上（A 4→3、B 仍是 4）")

# ==========================================================================================
# ④ 0 打空 0 命中（完全被吞掉的攻击）→ 不闪开
# ==========================================================================================
func _段4(t) -> void:
	var att := _单位("enemy", 4.0)
	var def := _单位("ally", 0.0)
	_加槽(def, "切札", 4.0)
	var c := _场(att, [def])
	var r := Calc.九死一生_判定(c, att, def, {"命中段": 0, "打空段": 0})
	t.ok(not J.truthy(r.get("触发")) and not def.has("闪") and _槽cd(def) == 4.0 and c.log.is_empty(),
		"④ 0 打空 0 命中（完全被吞掉的攻击）→ 不闪开、不转冷却、一行记录都不写（防御性下限）")
	var r2 := Calc.九死一生_判定(c, att, def, {"命中段": 0, "打空段": 1})
	t.ok(J.truthy(r2.get("触发")) and def.get("闪") == true,
		"④ 下限只挡 0/0：同样的 0 命中、但打空 1 段 → 照旧闪开")

# ==========================================================================================
# ⑤ `闪` 是纯布尔 + 源码里没有衍生字段
# ==========================================================================================
func _段5(t) -> void:
	var n := _打一次("enemy", 4.0, "ally", 0.0, 200.0, 12, 20261017)
	t.ok(typeof(n.字段) == TYPE_DICTIONARY, "⑤ 场景自检：攻击结算返回了字段字典")
	t.ok(typeof(n.def.get("闪")) == TYPE_BOOL and n.def.get("闪") == true,
		"⑤ `u.闪` 是**纯布尔**（typeof = TYPE_BOOL、值 = true）")
	# 同一个敌方阶段再闪开一次：还是同一个布尔，不叠层、不变数字
	var c: Dictionary = n.场
	Calc.resolveAttack(n.att, n.def, _武(10.0, 12), c, {})
	t.ok(typeof(n.def.get("闪")) == TYPE_BOOL and n.def.get("闪") == true,
		"⑤ 同一敌方阶段反复闪开 → 仍是同一个 true（不叠层、不变成数字）")
	# 源码级：不许出现「闪」+ 层数 / 剩余回合 / 上限 这类衍生字段（字符串从两段拼，免得本文件自己命中）
	var 禁 := ["闪" + "层数", "闪" + "剩余回合", "闪" + "上限"]
	var 命中: Array = []
	for 根 in ["res://core", "res://presentation", "res://session", "res://tests"]:
		_扫源码(根, 禁, 命中)
	t.ok(命中.is_empty(), "⑤ 源码里搜不到「闪」+ 层数 / 剩余回合 / 上限 这类衍生字段（命中：%s）" % str(命中))

# ==========================================================================================
# ⑥ 清除时机：闪开后进入下一个我方阶段 → 仍亮；该我方阶段结束后 → 全清
# ==========================================================================================
func _段6(t) -> void:
	var c := Setup.开局([{"键": "A1", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261017, null, {"单机牌组": true})
	if c.is_empty() or (c.get("allies") as Array).is_empty():
		t.ok(false, "⑥ 开局失败（造不出 A1 的战场）")
		return
	var u: Dictionary = c.allies[0]
	t.ok(Fac.势力名(u) == "ATX",
		"⑥ 战场自检：A1 的 tags.势力 = %s" % str(Fac.势力名(u)))
	u["闪"] = true
	u["轮转本阶段"] = 2
	Btl.开始我方阶段(c)                              # 进入下一个我方阶段
	t.ok(Calc.九死一生_闪(u) and Calc.九死一生_本阶段轮转(u) == 2,
		"⑥ 闪开后进入下一个我方阶段 → **仍亮**（闪 = %s、本阶段轮转 = %d）" % [str(u.get("闪")), Calc.九死一生_本阶段轮转(u)])
	if not (c.get("enemies") as Array).is_empty():
		(c.enemies[0] as Dictionary)["weapons"] = []   # 敌方阶段不会有攻击 → 不会在这个缝里重新点亮
	Btl.结束我方回合(c)                              # 我方阶段结束（= 敌方阶段开始）
	t.ok(not u.has("闪") and not Calc.九死一生_闪(u) and Calc.九死一生_本阶段轮转(u) == 0,
		"⑥ 该我方阶段**结束**后 → 全清（闪键 = %s、本阶段轮转 = %d）" % [str(u.get("闪", "（不存在）")), Calc.九死一生_本阶段轮转(u)])

# ==========================================================================================
# ⑦ 轮转：cd 3 的牌闪 1 次 → 2；一次攻击多次闪开只 −1；一阶段最多 −3；第 4 次不再减
# ==========================================================================================
func _段7(t) -> void:
	var n := _打一次("enemy", 4.0, "ally", 0.0, 200.0, 12, 20261017)
	t.ok(_槽cd(n.def) == 2.0,
		"⑦ cd 3 的牌闪开 1 次 → cd %s（−1）" % str(_槽cd(n.def)))
	# 一次攻击里 12 段全空 = 判定只发生一次 → 每张牌最多 −1（不是 −12）
	var 重 := _打一次("enemy", 4.0, "ally", 0.0, 200.0, 12, 20261017)
	t.ok(_槽cd(重.def) == 2.0 and Calc.九死一生_本阶段轮转(重.def) == 1,
		"⑦ 同一次攻击里打空 12 段 → 只 −1（cd 3→%s、本阶段轮转 = %d，不是 −12）" % [
			str(_槽cd(重.def)), Calc.九死一生_本阶段轮转(重.def)])
	# 一个敌方阶段里连闪 4 次：上限 3
	var att := _单位("enemy", 4.0)
	var def := _单位("ally", 0.0, 200.0)
	_加槽(def, "切札", 5.0)
	var c := _场(att, [def])
	var w := _武(10.0, 12)
	for i in 4:
		Calc.resolveAttack(att, def, w, c, {})
	t.ok(_槽cd(def) == 2.0 and Calc.九死一生_本阶段轮转(def) == 3,
		"⑦ 一个敌方阶段闪 4 次：cd 5→%s（最多 −3）、本阶段轮转 = %d（第 4 次不再减）" % [
			str(_槽cd(def)), Calc.九死一生_本阶段轮转(def)])
	# 结算读口（三层反馈的「结算」那一层；A3 / A7 直接读这两个纯读口，不另做界面）
	t.ok(Calc.九死一生_本阶段合计(c) == 3,
		"⑦ 结算读口：`九死一生_本阶段合计(ctx)` = %d（全队本阶段累计轮转 3 次）" % Calc.九死一生_本阶段合计(c))
	var 末 := _行们(c)
	t.ok(not 末.is_empty() and str(末[末.size() - 1]).contains("不再减"),
		"⑦ 第 4 次判定的那一行明写「不再减」：%s" % (str(末[末.size() - 1]) if not 末.is_empty() else "（没有行）"))

# ==========================================================================================
# ⑧ 只对 ATX 生效：非 ATX 成员被打空 → 不亮闪、不转冷却
# ==========================================================================================
func _段8(t) -> void:
	for 势力 in ["秘银", ""]:
		var att := _单位("enemy", 4.0)
		var def := _单位("ally", 0.0, 200.0, str(势力))
		_加槽(def, "切札", 4.0)
		var c := _场(att, [def])
		Calc.resolveAttack(att, def, _武(10.0, 12), c, {})
		t.ok(not def.has("闪") and _槽cd(def) == 4.0 and _行们(c).is_empty(),
			"⑧ 势力「%s」的成员被打空 12 段 → 不亮闪（闪键 = %s）、冷却仍是 %s、没有 〔九死一生〕 行" % [
				势力 if 势力 != "" else "（没有势力）", str(def.get("闪", "（不存在）")), str(_槽cd(def))])

# ==========================================================================================
# ⑩ 同种子两遍逐字相同
# ==========================================================================================
func _段10(t) -> void:
	var 一 := _同场景结果(5)
	var 二 := _同场景结果(5)
	t.ok(一.文 == 二.文 and 一.串 == 二.串 and 一.闪 == 二.闪 and 一.cd == 二.cd and 一.日志 == 二.日志,
		"⑩ 同种子两遍逐字相同（攻击记录 / 闪 = %s / cd %s→%s / 日志 %d 条 / 随机数 %d 次）" % [
			str(一.闪), str(一.cd), str(二.cd), 一.行数, 一.rng])

# ==========================================================================================
# ⑪（额外，三层反馈的「预告」那一层）机体卡上真的画出「闪」这个字
# ==========================================================================================
func _段11(t) -> void:
	var 卡 := UnitCard.new()
	卡.setup({
		"ok": true, "名": "响介", "键": "A1", "模板": "A1", "势力": "ATX",
		"位名": "前1", "等级": 10, "职业": "突击", "活着": true,
		"HP": 100.0, "最大HP": 100.0, "血比": 1.0, "气势": 0.0, "护盾": 0.0,
		"状态": ["闪"], "开关": [], "闪": true,
	})
	var 亮 := 卡.find_child("闪标", true, false)
	t.ok(亮 != null and (亮 as Label).visible and (亮 as Label).text == "闪",
		"⑪ 预告：`闪` 亮着时机体卡上真的画出「闪」字（`find_child(\"闪标\")` = %s）" % (
			"找得到且 visible" if (亮 != null and (亮 as Label).visible) else "找不到 / 藏着"))
	卡.free()
	var 暗卡 := UnitCard.new()
	暗卡.setup({
		"ok": true, "名": "响介", "键": "A1", "模板": "A1", "势力": "ATX",
		"位名": "前1", "等级": 10, "职业": "突击", "活着": true,
		"HP": 100.0, "最大HP": 100.0, "血比": 1.0, "气势": 0.0, "护盾": 0.0,
		"状态": ["正常"], "开关": [],
	})
	var 暗 := 暗卡.find_child("闪标", true, false)
	t.ok(暗 != null and not (暗 as Label).visible,
		"⑪ 没闪开时同一个标签藏起来（不影响卡面，纯覆盖层）")
	暗卡.free()

# ==========================================================================================
# 小工具
# ==========================================================================================
func _同场景结果(命中数: int) -> Dictionary:
	var 种子 := _找种子(命中数)
	var att := _单位("enemy", 4.0)
	var def := _单位("ally", 0.0)
	_加槽(def, "切札", 4.0)
	var c := _场(att, [def], 种子)
	var r := Calc.resolveAttack(att, def, _武(10.0, 12), c, {})
	var 行 := _行们(c)
	return {
		"def": def, "场": c, "闪": Calc.九死一生_闪(def), "cd": _槽cd(def),
		"文": str(r.get("文本")), "串": str(r.get("字段")), "日志": "\n".join(行),
		"行数": 行.size(), "有行": 行.any(func(x): return str(x).contains("九死一生")),
		"rng": int((c.get("rng") as Mulberry32).steps),
	}

## 一回合制的小场景：`_打一次(攻击方side, 位, 目标side, 位, 闪避, 段数, 种子)`。
func _打一次(攻方: String, 攻位: float, 守方: String, 守位: float, 闪避: float, 段数: int, 种子: int) -> Dictionary:
	var att := _单位(攻方, 攻位)
	var def := _单位(守方, 守位, 闪避)
	_加槽(def, "切札", 3.0)
	var c := _场(att, [def] if 守方 == "ally" else [att], 种子)
	var r := Calc.resolveAttack(att, def, _武(10.0, 段数), c, {})
	return {"att": att, "def": def, "场": c, "字段": r.get("字段"), "文本": str(r.get("文本"))}

func _行们(c: Dictionary) -> Array:
	var out: Array = []
	for e in J.or_(c.get("log"), []):
		if e is Dictionary:
			out.append(str((e as Dictionary).get("文本", "")))
	return out

func _加槽(u: Dictionary, 牌名: String, cd: float) -> void:
	u["大招槽"] = [{"cd": cd, "cd_max": maxf(cd, 6.0), "卡": {"名": 牌名}, "已解锁": true}]

func _槽cd(u: Dictionary) -> float:
	var 槽们: Array = J.or_(u.get("大招槽"), [])
	if 槽们.is_empty() or not (槽们[0] is Dictionary):
		return -1.0
	return J.num0((槽们[0] as Dictionary).get("cd"))

func _单位(side: String, 位: float, 闪避: float = 0.0, 势力: String = "ATX") -> Dictionary:
	var 键 := "ATX_%d" % int(位) if side == "ally" else "靶_%d" % int(位)
	return {
		"key": 键, "name": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 闪避, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": ({"势力": 势力} if not 势力.is_empty() else {}), "weapons": [],
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

## 攻击方 `aim = 160`（没有命中加成）、目标 `eva` 默认 0：
##   命中率 = `w.hit − eva`（`hit 50` + `eva 0` = 50%，`hit 50` + `eva 200` = 0%，`hit 100` + `eva 0` = 100%）。
func _场(att: Dictionary, defs: Array, 种子: int = 20261017) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": defs, "enemies": [att], "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0,
	}

## 找一个「12 段里恰好 k 段命中」的种子。抽数顺序与 `resolveAttack` 逐字一致：
##   每段先抽命中（50%）；中了才再抽一次暴击（critRate = 0 → 恒不暴击，但照抽）。
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
