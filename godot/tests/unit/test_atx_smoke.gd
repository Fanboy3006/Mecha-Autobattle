## ★ A5a（拉米亚 v0.1）：「烟雾」场上状态 + 【雾袭】关键词 + 烟雾弹副武器 —— 内核验收。
##
## 权威依据：`协作/设计/拉米亚卡牌设计 v0.1.md` §0 / §1 / §2 / §3.2 / §6
##          · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` §4 的 A5a 行
##
## 受控单位（不走 `Setup.开局` 的那些段直接造裸字典）：攻击方 `aim = 160`、目标 `eva = 0` →
##   命中率 = `w.hit`，所以「−30 真的进公式」可以贴两个精确百分比（80% → 50%）。
##   **拉米亚的识别口径 = 单位上的 `trait == "wSeries"`**（数据里 A3 拉米亚就是这个；测试里手搭的
##   `_拉米亚()` 也照这个字段写，**不改 `data/js`**）。
## 本文件跑完会把 `Db.T.战斗结构.单机牌组.开` 还原成进来时的值（后面的测试仍走改前口径）。
extends RefCounted

const 千 := 999999.0

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	_段1_放烟(t)
	_段2_命中减三十(t)
	_段3_敌我都算(t)
	_段4_拉米亚豁免(t)
	_段5_刷新不叠加(t)
	_段6_消失时机(t)
	_段7_不同列独立(t)
	_段8_烟雾弹副武器(t)
	_段9_雾袭攻击牌(t)
	_段10_雾袭非攻击牌(t)
	_段11_只判定一次(t)
	_段12_不留状态(t)
	_段14_同种子两遍(t)
	_段15_三层反馈(t)

# ==========================================================================================
# ① 放烟：`ctx.烟雾` 长度 1、列正确、记录 1 行
# ==========================================================================================
func _段1_放烟(t) -> void:
	var c := _新场([_队友(0.0)], [_靶(0.0), _靶(3.0)])
	AtxSmoke.初始化(c)
	t.ok(c.get("烟雾") is Array and (c.get("烟雾") as Array).is_empty(),
		"① 开关开：开局 `ctx.烟雾 = []`（空数组，不是「层数」）")
	var 行前 := _行数(c)
	var r := AtxSmoke.放烟(c, _拉米亚(1.0), 1, "enemy")
	t.ok(int(r.get("列")) == 1 and not J.truthy(r.get("刷新")),
		"① 放烟：列参数 = 1（显示为「第 2 列」）、这一次是**新增**")
	t.ok((c.get("烟雾") as Array).size() == 1, "① `ctx.烟雾` 长度 = 1（%s）" % str(c.get("烟雾")))
	var 片: Dictionary = c.烟雾[0]
	t.ok(int(J.num0(片.get("列"))) == 1 and str(片.get("方", "")) == "enemy",
		"① 元素带 `列 = 1` / `方 = enemy`（敌方一列 = 前后 2 格）")
	t.ok(int(J.num0(片.get("消失阶段"))) == 3 and int(J.num0(片.get("放出阶段"))) == 1,
		"① 元素带 `消失阶段 = 3`（放出阶段 1 + 2）/ `放出阶段 = 1`（%s）" % str(片.keys()))
	t.ok(not 片.has("层数") and not 片.has("层"),
		"① 元素里**没有** `层数` / `层` 这类键（只有 列 / 方 / 消失阶段 / 放出阶段 / 来源）")
	t.ok(_行数(c) - 行前 == 1 and _有行(c, "〔烟雾〕拉米亚 在第 2 列放出烟雾（前后 2 格 · 每段命中 −30）"),
		"① 只记 **1 行**：%s" % _找行(c, "〔烟雾〕"))

# ==========================================================================================
# ② 命中 −30 真的进公式：同一发攻击「目标在雾中」vs「不在」每段命中率差正好 30
# ==========================================================================================
func _段2_命中减三十(t) -> void:
	var 甲 := _队友(2.0)
	var 靶A := _靶(0.0)
	var 靶B := _靶(3.0)
	var c := _新场([甲], [靶A, 靶B])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var w := _武(300.0, 3, 80.0)
	var 不在 := int(Calc.hitRate(甲, w, 靶B, {"baseHit": 80.0, "ctx": c}).hit)
	var 在 := int(Calc.hitRate(甲, w, 靶A, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(不在 == 80 and 在 == 50 and 不在 - 在 == 30,
		"② 同一发攻击（基础 80%%）：目标**不在**雾里 = %d%% / 目标**在**雾里 = %d%% → 差 %d（正好 30）" % [
			不在, 在, 不在 - 在])
	var r在 := Calc.resolveAttack(甲, 靶A, w, c, {})
	var r不在 := Calc.resolveAttack(甲, 靶B, w, c, {})
	t.ok(str(r在.字段.详情).contains("（50%）") and str(r在.字段.详情).contains("烟雾 −30"),
		"② 打雾里的目标：「详情」首段 = 「%s」（能看出 −30 的来源）" % str(r在.字段.详情).split("；")[0])
	t.ok(str(r不在.字段.详情).contains("（80%）") and not str(r不在.字段.详情).contains("烟雾"),
		"② 打雾外的目标：「详情」首段 = 「%s」（一个「烟雾」字都没有）" % str(r不在.字段.详情).split("；")[0])
	t.ok(float(r在.字段.段数) == 3.0 and str(r在.文本).find("\n") == -1
		and str(r在.字段.详情).split("；").size() == 3 and str(r不在.文本).find("\n") == -1,
		"② 3 段都吃了 −30，而**一次攻击 = 一条记录**（`文本` 单行、`详情` 正好 3 段）：%s" % str(r在.文本))

# ==========================================================================================
# ③ 敌我都算：我方从雾里开火也 −30（敌方从雾里开火同样）
# ==========================================================================================
func _段3_敌我都算(t) -> void:
	var 甲 := _队友(0.0)
	var 靶A := _靶(0.0)
	var 靶B := _靶(3.0)
	var w := _武(300.0, 2, 80.0)
	# 敌方在我的雾里开火 → −30
	var c := _新场([甲], [靶A, 靶B])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var 敌在 := int(Calc.hitRate(靶A, w, 甲, {"baseHit": 80.0, "ctx": c}).hit)
	var 敌外 := int(Calc.hitRate(靶B, w, 甲, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(敌在 == 50 and 敌外 == 80,
		"③ **敌方从雾里开火**：%d%%；没在雾里的那台 %d%%（−30 也压敌人）" % [敌在, 敌外])
	# 我方从雾里开火 → −30（把一片雾放到我方一侧：规则只读「方 + 列」，不区分敌我）
	var c2 := _新场([甲], [靶B])
	AtxSmoke.初始化(c2)
	AtxSmoke.放烟(c2, _拉米亚(1.0), 0, "ally")
	var 我在 := int(Calc.hitRate(甲, w, 靶B, {"baseHit": 80.0, "ctx": c2}).hit)
	t.ok(我在 == 50, "③ **我方从雾里开火**：%d%%（80 − 30 = 50；敌我都算）" % 我在)
	t.ok(AtxSmoke.命中惩罚(甲, 靶B, c2) == 30.0,
		"③ 纯读口 `命中惩罚` = %s（来源：%s）" % [str(AtxSmoke.命中惩罚(甲, 靶B, c2)),
			AtxSmoke.惩罚来源(甲, 靶B, c2)])

# ==========================================================================================
# ④ 拉米亚豁免（被动「W 系列」）：从雾里开火不吃、打雾里的目标也不吃（两头都不吃）
# ==========================================================================================
func _段4_拉米亚豁免(t) -> void:
	var w := _武(300.0, 2, 80.0)
	# ---- 打雾里的目标：队友 50% / 拉米亚 80% ----
	var c := _新场([_队友(2.0), _拉米亚(1.0)], [_靶(0.0), _靶(3.0)])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, c.allies[1], 0, "enemy")
	var 甲: Dictionary = c.allies[0]
	var 拉: Dictionary = c.allies[1]
	var 靶A: Dictionary = c.enemies[0]
	var 靶B: Dictionary = c.enemies[1]
	t.ok(AtxSmoke.是拉米亚(拉) and not AtxSmoke.是拉米亚(甲),
		"④ 识别口径：拉米亚 `trait = %s`、队友 `trait = %s`" % [str(拉.get("trait", "")), str(甲.get("trait", ""))])
	var 队友打 := int(Calc.hitRate(甲, w, 靶A, {"baseHit": 80.0, "ctx": c}).hit)
	var 拉打 := int(Calc.hitRate(拉, w, 靶A, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(队友打 == 50 and 拉打 == 80,
		"④ **打雾里的目标**：队友 %d%% vs 拉米亚 %d%%（拉米亚不吃 −30）" % [队友打, 拉打])
	# ---- 从雾里开火：队友 50% / 拉米亚 80%（把雾放到我方一侧，让两人都站在雾里）----
	var c2 := _新场([_队友(0.0)], [_靶(3.0)])
	AtxSmoke.初始化(c2)
	AtxSmoke.放烟(c2, _拉米亚(1.0), 0, "ally")
	var 队友从 := int(Calc.hitRate(c2.allies[0], w, c2.enemies[0], {"baseHit": 80.0, "ctx": c2}).hit)
	var c3 := _新场([_拉米亚(1.0)], [_靶(3.0)])
	AtxSmoke.初始化(c3)
	AtxSmoke.放烟(c3, c3.allies[0], 1, "ally")
	var 拉从 := int(Calc.hitRate(c3.allies[0], w, c3.enemies[0], {"baseHit": 80.0, "ctx": c3}).hit)
	t.ok(队友从 == 50 and 拉从 == 80,
		"④ **从雾里开火**：队友 %d%% vs 拉米亚 %d%%（她站在雾里也不吃）" % [队友从, 拉从])
	# ---- 拉米亚当目标：敌人打雾里的她也不吃 ----
	var c4 := _新场([_队友(5.0), _拉米亚(1.0)], [_靶(0.0), _靶(3.0)])
	AtxSmoke.初始化(c4)
	AtxSmoke.放烟(c4, c4.allies[1], 1, "ally")
	var 甲4: Dictionary = c4.allies[0]
	var 拉4: Dictionary = c4.allies[1]
	var 靶4: Dictionary = c4.enemies[1]
	var 打队友 := int(Calc.hitRate(靶4, w, 甲4, {"baseHit": 80.0, "ctx": c4}).hit)
	var 打拉米亚 := int(Calc.hitRate(靶4, w, 拉4, {"baseHit": 80.0, "ctx": c4}).hit)
	t.ok(打队友 == 50 and 打拉米亚 == 80,
		"④ **拉米亚当目标**（两人都站在同一片雾里）：打队友 %d%% vs 打拉米亚 %d%%（两头都不吃）" % [打队友, 打拉米亚])
	t.ok(AtxSmoke.命中惩罚(靶4, 拉4, c4) == 0.0 and AtxSmoke.命中惩罚(靶4, 甲4, c4) == 30.0,
		"④ 纯读口 `命中惩罚`：对拉米亚 = %s / 对队友 = %s" % [
			str(AtxSmoke.命中惩罚(靶4, 拉4, c4)), str(AtxSmoke.命中惩罚(靶4, 甲4, c4))])

# ==========================================================================================
# ⑤ 同列再放一次：**刷新持续、不叠加**（仍只 −30，不是 −60）
# ==========================================================================================
func _段5_刷新不叠加(t) -> void:
	var 甲 := _队友(3.0)
	var 靶0 := _靶(0.0)
	var c := _新场([甲], [靶0])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var w := _武(300.0, 2, 80.0)
	var 一次 := int(Calc.hitRate(甲, w, 靶0, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok((c.get("烟雾") as Array).size() == 1 and 一次 == 50,
		"⑤ 第 1 列一片雾 → 长度 1、打这一列 = %d%%" % 一次)
	# 同一列在**第 3 个我方阶段**再放一次 → 只刷新，不叠加
	c["turn"] = 3.0
	var 前: Variant = _片Of(c, 0).get("消失阶段")
	var r := AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var 片 := _片Of(c, 0)
	t.ok(J.truthy(r.get("刷新")) and (c.get("烟雾") as Array).size() == 1,
		"⑤ 同列再放一次：`刷新 = true`、**还是那一片**（总数仍 1）")
	t.ok(int(J.num0(片.get("消失阶段"))) == 5,
		"⑤ 持续时间被刷新：消失阶段 %s → %d（放到第 5 个我方阶段开始）" % [str(前), int(J.num0(片.get("消失阶段")))])
	var 两次 := int(Calc.hitRate(甲, w, 靶0, {"baseHit": 80.0, "ctx": c}).hit)
	t.ok(两次 == 50 and 两次 != 20,
		"⑤ 两次之后打同一列仍是 **%d%%**（80 − 30；**不是 20%%**，惩罚不叠加）" % 两次)
	t.ok(_有行(c, "〔烟雾〕第 1 列刷新（持续到第 5 个我方阶段开始，惩罚不叠加）"),
		"⑤ 刷新那一行：%s" % _找行(c, "〔烟雾〕第 1 列刷新"))
	# 三片雾落到同一列也只 −30（结构性保证：一片雾一列，绝不叠加）
	var c2 := _新场([甲], [靶0])
	AtxSmoke.初始化(c2)
	AtxSmoke.放烟(c2, _拉米亚(1.0), 0, "enemy")
	AtxSmoke.放烟(c2, _拉米亚(1.0), 0, "ally")
	t.ok(int(Calc.hitRate(甲, w, 靶0, {"baseHit": 80.0, "ctx": c2}).hit) == 50 and AtxSmoke.片数(c2) == 2,
		"⑤ 同一列两片雾（敌方一片 + 我方一片，2 条）→ 仍是 50%（只 −30，不是 −60）")

# ==========================================================================================
# ⑥ 消失时机：放出后的第 2 个我方阶段**开始时**消失；第 1 个我方阶段结束时**仍在**
# ==========================================================================================
func _段6_消失时机(t) -> void:
	var c := Setup.开局([{"键": "A3", "位": 0, "等级": 10}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261017, null, {"单机牌组": true, "卡牌流转": true, "ATXv02": true})
	if (c.get("allies") as Array).is_empty() or (c.get("enemies") as Array).is_empty():
		t.ok(false, "⑥ 开局失败（造不出 A3 的战场）")
		return
	var 拉: Dictionary = c.allies[0]
	t.ok(c.get("烟雾") is Array, "⑥ 真开局：`ctx.烟雾` 已建好（%s）" % str(c.get("烟雾")))
	AtxSmoke.放烟(c, 拉, 1, "enemy")
	t.ok(int(J.num0(c.烟雾[0].get("消失阶段"))) == 3,
		"⑥ 第 1 回合放烟 → 消失阶段 = 3（放出阶段 1 + 2）")
	Btl.开始我方阶段(c)
	t.ok(int(J.num0(c.get("turn"))) == 2.0 and (c.get("烟雾") as Array).size() == 1,
		"⑥ 第 1 个我方阶段（第 %d 回合）开始时**仍在**（长度 %d）" % [int(c.get("turn")), c.烟雾.size()])
	t.ok(not _有行(c, "〔烟雾〕第 2 列刷新"), "⑥ 这个阶段没刷新过（活下来不是靠刷新）")
	Btl.开始我方阶段(c)
	t.ok(int(J.num0(c.get("turn"))) == 3.0 and (c.get("烟雾") as Array).size() == 0,
		"⑥ 第 2 个我方阶段（第 %d 回合）开始时**散去**（长度 %d）" % [int(c.get("turn")), c.烟雾.size()])
	t.ok(_有行(c, "〔烟雾〕第 2 列烟雾散去（第 3 个我方阶段开始）"),
		"⑥ 散去那一行：%s" % _找行(c, "〔烟雾〕"))

# ==========================================================================================
# ⑦ 不同列各自独立（第 1 列与第 3 列各一片雾，互不影响）
# ==========================================================================================
func _段7_不同列独立(t) -> void:
	var 甲 := _队友(3.0)
	var 靶0 := _靶(0.0)
	var 靶2 := _靶(2.0)
	var 靶3 := _靶(3.0)
	var c := _新场([甲], [靶0, 靶2, 靶3])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	AtxSmoke.放烟(c, _拉米亚(1.0), 2, "enemy")
	var w := _武(300.0, 2, 80.0)
	t.ok(int(Calc.hitRate(甲, w, 靶0, {"baseHit": 80.0, "ctx": c}).hit) == 50
		and int(Calc.hitRate(甲, w, 靶2, {"baseHit": 80.0, "ctx": c}).hit) == 50
		and int(Calc.hitRate(甲, w, 靶3, {"baseHit": 80.0, "ctx": c}).hit) == 80,
		"⑦ 第 1 列 50% / 第 3 列 50% / 第 4 列（没雾）80%")
	# 只刷新第 1 列 → 第 3 列的消失阶段一个数字都不动
	c["turn"] = 2.0
	var 前2 := int(J.num0(_片Of(c, 2).get("消失阶段")))
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var 后2 := int(J.num0(_片Of(c, 2).get("消失阶段")))
	t.ok(前2 == 3 and 后2 == 3,
		"⑦ 刷新第 1 列不动第 3 列：它的消失阶段 %d → %d（各片独立记）" % [前2, 后2])
	t.ok((c.get("烟雾") as Array).size() == 2,
		"⑦ 两片雾各自一条（长度仍 2，没有合并成一片、也没有多加一层）")

# ==========================================================================================
# ⑧ 烟雾弹 = 副武器：不置 `主武器已销毁`、主武器仍可打；cd 3 → 当回合不可再放、3 个我方阶段后可再放
# ==========================================================================================
func _段8_烟雾弹副武器(t) -> void:
	var c := Setup.开局([{"键": "A3", "位": 0, "等级": 30}], [{"键": "fighter", "位": 0, "等级": 1}],
		20261018, null, {"单机牌组": true, "卡牌流转": true, "ATXv02": true})
	if (c.get("allies") as Array).is_empty() or (c.get("enemies") as Array).is_empty():
		t.ok(false, "⑧ 开局失败（造不出 A3 的战场）")
		return
	var 拉: Dictionary = c.allies[0]
	var 敌: Dictionary = c.enemies[0]
	var 条目 := DeckFlow.找副武器(拉, "U_ATX_8")
	t.ok(not 条目.is_empty() and str(条目.get("卡", {}).get("卡类", "")) == "副武器卡",
		"⑧ A3 的【烟雾弹】在**副武器栏**里，`卡类 = 副武器卡`")
	t.ok(float(条目.get("cd_max", 0.0)) == 3.0 and float(条目.get("cd", 0.0)) == 0.0,
		"⑧ 牌面冷却 3（`cd_max = %s`；开局 `cd = %s`）" % [str(条目.get("cd_max")), str(条目.get("cd"))])
	t.ok(J.num0(条目.get("卡", {}).get("加版冷却")) == 2.0,
		"⑧ 「+」版只留字段：牌面 `加版冷却 = 2`（升级流程本轮不做）")
	拉["战意"] = 100.0
	拉["主武器已销毁"] = false
	var 行前 := _行数(c)
	var 列 := int(Fm.colOfSlot(float(敌.slot)))
	var r := Btl.打出武器栏卡(c, "A3", "U_ATX_8", 敌.key)
	t.ok(J.truthy(r.get("成功")) and int(J.num0(r.get("列"))) == 列,
		"⑧ 打到第 %d 列（目标所在的列）：%s" % [列 + 1, str(r.get("成功"))])
	t.ok(拉.get("主武器已销毁") == false and J.truthy(r.get("主武器已销毁")) == false,
		"⑧ 打出后 `u.主武器已销毁 == false`（副武器不销毁主武器）")
	t.ok((c.get("烟雾") as Array).size() == 1 and float(条目.get("cd", 0.0)) == 3.0,
		"⑧ 场上一片雾；副武器自己的 `cd = 3`（不动大招槽的 cd）")
	t.ok(_行数(c) - 行前 >= 2 and _有行(c, "〔烟雾〕拉米亚 在第 %d 列放出烟雾" % (列 + 1)),
		"⑧ 记录里有〔烟雾〕那一行：%s" % _找行(c, "〔烟雾〕"))
	# 主武器仍可打（给武器栏插一张确定性的测试主武器）
	var 刀 := {"id": "T_SMOKE_MAIN", "名": "测试主武器", "卡类": "主武器卡", "占行动": ["A3"], "耗气": 0.0,
		"武器": {"name": "测试主武器", "fire": "direct", "dmgType": "物理", "power": 100.0, "hit": 100.0,
			"stat": "射击", "hits": 1.0, "cd": 0.0, "upgrades": []}}
	拉["武器栏"] = [刀]
	var r2 := Btl.打出武器栏卡(c, "A3", "T_SMOKE_MAIN", 敌.key)
	t.ok(J.truthy(r2.get("成功")) and 拉.get("主武器已销毁") == true,
		"⑧ 放完雾**主武器仍可打**（先放雾再开火；打完才置 `主武器已销毁 = true`）")
	# 当回合不可再放（cd 3）
	var 因 := DeckFlow.副武器不可打原因(c, 拉, 条目)
	t.ok(因.contains("冷却中") and 因.contains("3"), "⑧ 当回合不可再放：「%s」" % 因)
	var r3 := DeckFlow.打出副武器(c, "A3", "U_ATX_8", 敌.key)
	t.ok(J.truthy(r3.get("成功")) == false and str(r3.get("原因", "")).contains("冷却中"),
		"⑧ 再打一次被拦（原因：%s）" % str(r3.get("原因", "")))
	# 走 3 个我方阶段 → cd 归 0 → 可再放
	var 每次: Array = []
	for i in 3:
		Btl.开始我方阶段(c)
		每次.append(float(条目.get("cd", 0.0)))
	t.ok(每次 == [2.0, 1.0, 0.0] and DeckFlow.副武器不可打原因(c, 拉, 条目) == "",
		"⑧ 3 个我方阶段里 cd 逐次 %s → 第 3 个之后可再放（原因 = 「%s」）" % [str(每次), DeckFlow.副武器不可打原因(c, 拉, 条目)])
	var r4 := DeckFlow.打出副武器(c, "A3", "U_ATX_8", 敌.key)
	t.ok(J.truthy(r4.get("成功")) and float(条目.get("cd", 0.0)) == 3.0,
		"⑧ 第 3 个我方阶段之后真的能再放（`cd` 又回 3）")

# ==========================================================================================
# ⑨ 【雾袭】攻击牌：目标在雾里 → 触发；目标不在雾里 → 不触发
# ==========================================================================================
func _段9_雾袭攻击牌(t) -> void:
	var 甲 := _队友(0.0)
	var 靶A := _靶(0.0)
	var 靶B := _靶(3.0)
	var c := _新场([甲], [靶A, 靶B])
	AtxSmoke.初始化(c)
	c["卡牌流转"] = true
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	甲["战意"] = 100.0
	甲["武器栏"] = [_雾袭武器()]
	var r := Btl.打出武器栏卡(c, "A1", "T_FOG_ATK", 靶A.key)
	t.ok(J.truthy(r.get("成功")), "⑨ 打出雾袭攻击牌（%s）" % str(r.get("原因", "ok")))
	t.ok(_有行(c, "〔雾袭〕甲「雾袭箭」→ 目标在烟雾里，触发：伤害 +25%"),
		"⑨ 目标在雾里 → 触发：%s" % _找行(c, "〔雾袭〕"))
	t.ok(AtxSmoke.雾袭本场触发次数(c) == 1, "⑨ 触发计数 = 1")
	甲["主武器已销毁"] = false
	var 触发前 := AtxSmoke.雾袭本场触发次数(c)
	var r2 := Btl.打出武器栏卡(c, "A1", "T_FOG_ATK", 靶B.key)
	t.ok(J.truthy(r2.get("成功")) and AtxSmoke.雾袭本场触发次数(c) == 触发前,
		"⑨ 目标不在雾里 → **不触发**（计数仍是 %d）" % AtxSmoke.雾袭本场触发次数(c))
	t.ok(_行数(c, "〔雾袭〕") == 1, "⑨ 记录里仍只有那 1 行 〔雾袭〕")

# ==========================================================================================
# ⑩ 【雾袭】非攻击牌：场上有雾 → 触发；没雾 → 不触发
# ==========================================================================================
func _段10_雾袭非攻击牌(t) -> void:
	var c := _新场([_队友(0.0)], [_靶(0.0)])
	AtxSmoke.初始化(c)
	c["卡牌流转"] = true
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var 甲: Dictionary = c.allies[0]
	甲["战意"] = 100.0
	甲["专属牌库"] = [_占位卡("X1"), _占位卡("X2")]
	甲["专属手牌"] = [_雾袭精神()]
	甲["专属弃牌堆"] = []
	var r := Btl.打出精神或公有牌(c, "A1", "T_FOG_SPIRIT")
	t.ok(J.truthy(r.get("成功")), "⑩ 打出非攻击牌（%s）" % str(r.get("原因", "ok")))
	t.ok(_有行(c, "〔雾袭〕甲「解析完毕」→ 场上有烟雾，触发：再抽 1 张"),
		"⑩ 场上有雾 → 触发：%s" % _找行(c, "〔雾袭〕"))
	t.ok((甲.get("专属手牌") as Array).size() == 1 and (甲.get("专属牌库") as Array).size() == 1,
		"⑩ 「雾袭分支」真的执行了：`抽牌` 抽到 1 张（手牌 %d / 牌库 %d）" % [
			甲.专属手牌.size(), 甲.专属牌库.size()])
	t.ok(AtxSmoke.雾袭本场触发次数(c) == 1, "⑩ 触发计数 = 1")
	# 没雾 → 不触发
	var c2 := _新场([_队友(0.0)], [_靶(0.0)])
	AtxSmoke.初始化(c2)
	c2["卡牌流转"] = true
	var 甲2: Dictionary = c2.allies[0]
	甲2["战意"] = 100.0
	甲2["专属牌库"] = [_占位卡("X1"), _占位卡("X2")]
	甲2["专属手牌"] = [_雾袭精神()]
	甲2["专属弃牌堆"] = []
	Btl.打出精神或公有牌(c2, "A1", "T_FOG_SPIRIT")
	t.ok(AtxSmoke.雾袭本场触发次数(c2) == 0 and _行数(c2, "〔雾袭〕") == 0,
		"⑩ 没雾 → 不触发（计数 0、0 行记录）")
	t.ok((甲2.get("专属牌库") as Array).size() == 2,
		"⑩ 没触发时「雾袭分支」一张都不抽（牌库仍是 %d 张）" % 甲2.专属牌库.size())

# ==========================================================================================
# ⑪ 只判定一次（不按段、不重复）；不掷随机数（`ctx.rng` 步数 = 0）
# ==========================================================================================
func _段11_只判定一次(t) -> void:
	var 甲 := _队友(0.0)
	var 靶A := _靶(0.0)
	var c := _新场([甲], [靶A])
	AtxSmoke.初始化(c)
	c["卡牌流转"] = true
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	甲["战意"] = 100.0
	var 卡 := _雾袭武器(6)
	甲["武器栏"] = [卡]
	var 步前 := int((c.get("rng") as Mulberry32).steps)
	var r := Btl.打出武器栏卡(c, "A1", "T_FOG_ATK", 靶A.key)
	var 步后 := int((c.get("rng") as Mulberry32).steps)
	t.ok(J.truthy(r.get("成功")), "⑪ 一发 6 段打雾里的目标")
	t.ok(AtxSmoke.雾袭本场触发次数(c) == 1 and _行数(c, "〔雾袭〕") == 1,
		"⑪ 6 段 → 【雾袭】**只判 1 次**（计数 %d、记录 %d 行）" % [AtxSmoke.雾袭本场触发次数(c), _行数(c, "〔雾袭〕")])
	t.ok(步后 - 步前 >= 6,
		"⑪ 整发攻击的随机数只来自 6 次命中判定（+命中段的暴击）：共 %d 次" % (步后 - 步前))
	var 只判 := AtxSmoke.打出时(c, 甲, 卡, 靶A)
	t.ok(bool(只判.get("攻击牌")), "⑪ 这张牌被认成**攻击牌**（看「目标在不在雾里」）")
	var 步A := int((c.get("rng") as Mulberry32).steps)
	AtxSmoke.打出时(c, 甲, 卡, 靶A)
	var 步B := int((c.get("rng") as Mulberry32).steps)
	t.ok(bool(只判.get("触发")) and 步B - 步A == 0,
		"⑪ 【雾袭】不掷随机数：`ctx.rng` 步数 %d → %d（差 0）" % [步A, 步B])

# ==========================================================================================
# ⑫ 打完不留状态：单位字典前后逐字相同 + 源码扫不到 `雾袭` 类持久键
# ==========================================================================================
func _段12_不留状态(t) -> void:
	var 甲 := _队友(0.0)
	var 靶A := _靶(0.0)
	var c := _新场([甲], [靶A])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, _拉米亚(1.0), 0, "enemy")
	var 卡 := _雾袭武器(3)
	卡["雾袭分支"] = []
	var 前 := str(甲.duplicate(true))
	var r := AtxSmoke.打出时(c, 甲, 卡, 靶A)
	t.ok(J.truthy(r.get("触发")) and str(甲.duplicate(true)) == 前,
		"⑫ 触发之后**单位字典前后逐字相同**（一个持久键都没写）")
	var 命中: Array = []
	for k in 甲.keys():
		if str(k).contains("雾袭"):
			命中.append(str(k))
	t.ok(命中.is_empty(), "⑫ 单位上 grep 不到任何 `雾袭` 相关键（命中：%s）" % str(命中))
	var 禁 := ["雾袭" + "层数", "雾袭" + "已用"]
	var 源命中: Array = []
	for 根 in ["res://core", "res://presentation", "res://session", "res://tests"]:
		_扫源码(根, 禁, 源命中)
	t.ok(源命中.is_empty(), "⑫ 源码（core / presentation / session / tests）里 `雾袭` + 层数 / 已用 命中 **%d** 条%s" % [
		源命中.size(), "" if 源命中.is_empty() else "：" + str(源命中)])
	t.ok(not c.get("烟雾计数").has("雾袭" + "层数") and not c.get("烟雾计数").has("雾袭" + "已用"),
		"⑫ `ctx.烟雾计数` 只有 `放出` / `雾袭` 两个整数（%s）" % str(c.get("烟雾计数")))

# ==========================================================================================
# ⑬ 开关关：无 `ctx.烟雾`、命中率与改前逐字相同、0 条 〔烟雾〕〔雾袭〕
# ==========================================================================================
# ==========================================================================================
# ⑭ 同种子两遍：记录文本与所有数字逐字相同
# ==========================================================================================
func _段14_同种子两遍(t) -> void:
	var 一 := _整场脚本()
	var 二 := _整场脚本()
	t.ok(一.日志 == 二.日志 and 一.文 == 二.文 and 一.命中 == 二.命中
		and 一.放出 == 二.放出 and 一.触发 == 二.触发 and 一.rng == 二.rng,
		"⑭ 同种子两遍**逐字相同**（日志 %d 行 / rng %d 次 / 放出 %d 次 / 触发 %d 次）" % [
			str(一.日志).split("\n").size(), 一.rng, 一.放出, 一.触发])
	t.ok(一.文.contains("（50%）") and 一.文.contains("烟雾 −30"),
		"⑭ 脚本里那一发确实吃了 −30（%s）" % str(一.文).split("|")[0].split("；")[0])

# ==========================================================================================
# ⑮ 三层反馈：即时 / 预告（「雾」标）/ 结算（两个纯读口）
# ==========================================================================================
func _段15_三层反馈(t) -> void:
	var c := _新场([_队友(0.0), _拉米亚(2.0)], [_靶(0.0), _靶(3.0)])
	AtxSmoke.初始化(c)
	AtxSmoke.放烟(c, c.allies[1], 0, "enemy")
	t.ok(_有行(c, "〔烟雾〕拉米亚 在第 1 列放出烟雾（前后 2 格 · 每段命中 −30）"),
		"⑮ 即时：%s" % _找行(c, "〔烟雾〕"))
	# 预告：站在雾里的那一台，快照带 `雾 = true`、状态行含「雾」
	var s := GameSession.new()
	s.battle_ctx = c
	s.screen = "battle"
	var 敌图 := s.unit_view("enemy", "靶_0")
	t.ok(bool(敌图.get("雾", false)) and (敌图.get("状态") as Array).has("雾"),
		"⑮ 预告（在雾里的靶机）：`雾 = true`、状态行含「雾」（%s）" % str(敌图.get("状态")))
	var 我图 := s.unit_view("ally", "A1")
	t.ok(我图.get("雾") == null and not (我图.get("状态") as Array).has("雾"),
		"⑮ 预告对照（不在那列的队友）：快照里没有 `雾` 键、状态行也没有（%s）" % str(我图.get("状态")))
	var 拉图 := s.unit_view("ally", "A3")
	t.ok(拉图.get("雾") == null,
		"⑮ 预告对照（第 3 列的拉米亚）：没有 `雾` 键（雾只罩它自己那一列）")
	# 结算
	t.ok(AtxSmoke.烟雾本场放出次数(c) == 1 and AtxSmoke.雾袭本场触发次数(c) == 0,
		"⑮ 结算读口：`烟雾本场放出次数` = %d / `雾袭本场触发次数` = %d" % [
			AtxSmoke.烟雾本场放出次数(c), AtxSmoke.雾袭本场触发次数(c)])

# ==========================================================================================
# 小工具
# ==========================================================================================
func _队友(位: float) -> Dictionary:
	var d := _单位("A1", "ally", 位)
	d["name"] = "甲"
	d["trait"] = "gambler"
	return d

## 拉米亚：识别口径 = `trait == "wSeries"`（数据里 A3 拉米亚就是这个字段）
func _拉米亚(位: float) -> Dictionary:
	var d := _单位("A3", "ally", 位)
	d["name"] = "拉米亚"
	d["trait"] = "wSeries"
	return d

func _靶(位: float) -> Dictionary:
	var d := _单位("靶_%d" % int(位), "enemy", 位)
	d["name"] = "靶机%s" % str(int(位) + 1)
	return d

func _单位(键: String, side: String, 位: float) -> Dictionary:
	return {
		"key": 键, "name": 键, "tplKey": 键, "side": side, "slot": 位, "lv": 10.0,
		"maxHp": 千, "hp": 千,
		"melee": 0.0, "shoot": 0.0, "awaken": 0.0, "defense": 0.0,
		"armor": 0.0, "armorCut": 0.0, "eva": 0.0, "aim": 160.0,
		"critBase": -10.0, "critMod": 0.0, "mov": 5.0,
		"buffs": [], "debuffs": [], "abilities": [], "weapons": [],
		"shield": 0.0, "shieldHp": 0.0, "barrierLeft": 0.0,
		"tags": {"势力": "ATX"},
	}

func _武(威力: float, 段数: int, 命中率: float = 50.0) -> Dictionary:
	return {"name": "测试武器", "fire": "direct", "dmgType": "物理", "power": 威力, "hit": 命中率,
		"stat": "射击", "hits": float(段数), "cd": 0.0, "upgrades": []}

func _新场(我方: Array, 敌方: Array, 种子: int = 20261017) -> Dictionary:
	return {
		"turn": 1.0, "种子": float(种子), "rng": Mulberry32.new(种子),
		"allies": 我方, "enemies": 敌方, "log": [], "_rng_at": [],
		"当前战术": null, "气势": 0.0,
	}

## 找 `ctx.烟雾` 里某一列的那一片（找不到回空字典）
func _片Of(c: Dictionary, 列: int) -> Dictionary:
	for e in J.or_(c.get("烟雾"), []):
		if e is Dictionary and int(J.num0(e.get("列"))) == 列:
			return e
	return {}

## 一张带【雾袭】的攻击牌（目标在雾里就触发）
func _雾袭武器(段数: int = 2) -> Dictionary:
	return {
		"id": "T_FOG_ATK", "名": "雾袭箭", "卡类": "主武器卡", "占行动": ["A1"], "耗气": 0.0,
		"归属": "ATX", "层级": "角色", "雾袭": true, "雾袭效果": "伤害 +25%",
		"雾袭分支": [],
		"武器": _武(200.0, 段数, 90.0),
	}

## 一张带【雾袭】的非攻击牌（场上有雾就触发；分支 = 抽 1 张）
func _雾袭精神() -> Dictionary:
	return {
		"id": "T_FOG_SPIRIT", "名": "解析完毕", "卡类": "专属精神牌", "归属": "ATX", "层级": "角色",
		"占行动": [], "耗气": 0.0, "雾袭": true, "雾袭效果": "再抽 1 张",
		"雾袭分支": [{"全局": [{"算子": "抽牌", "数量": 1}]}],
	}

func _占位卡(id: String) -> Dictionary:
	return {"id": id, "名": "占位 %s" % id, "卡类": "专属精神牌", "耗气": 0.0, "效果": []}

## 一整段脚本（⑭ 同种子两遍用）：放烟 → 刷新 → 两发攻击 → 雾袭精神牌
func _整场脚本() -> Dictionary:
	var c := _新场([_队友(0.0), _拉米亚(2.0)], [_靶(0.0), _靶(3.0)], 20261017)
	AtxSmoke.初始化(c)
	c["卡牌流转"] = true
	AtxSmoke.放烟(c, c.allies[1], 0, "enemy")
	c["turn"] = 2.0
	AtxSmoke.放烟(c, c.allies[1], 0, "enemy")
	var r1 := Calc.resolveAttack(c.allies[0], c.enemies[0], _武(300.0, 3, 80.0), c, {})
	var r2 := Calc.resolveAttack(c.allies[0], c.enemies[1], _武(300.0, 3, 80.0), c, {})
	var 甲: Dictionary = c.allies[0]
	甲["战意"] = 100.0
	甲["专属牌库"] = [_占位卡("X1")]
	甲["专属手牌"] = [_雾袭精神()]
	甲["专属弃牌堆"] = []
	Btl.打出精神或公有牌(c, "A1", "T_FOG_SPIRIT")
	var w := _武(300.0, 2, 80.0)
	var 命中 := "%d/%d" % [
		int(Calc.hitRate(甲, w, c.enemies[0], {"baseHit": 80.0, "ctx": c}).hit),
		int(Calc.hitRate(甲, w, c.enemies[1], {"baseHit": 80.0, "ctx": c}).hit)]
	return {
		"日志": "\n".join(_行们(c)),
		"文": str(r1.get("文本")) + "|" + str(r1.get("字段")) + "|" + str(r2.get("文本")) + "|" + str(r2.get("字段")),
		"命中": 命中,
		"放出": AtxSmoke.烟雾本场放出次数(c), "触发": AtxSmoke.雾袭本场触发次数(c),
		"rng": int((c.get("rng") as Mulberry32).steps),
	}

func _行数(c: Dictionary, 子串: String = "") -> int:
	if 子串 == "":
		return _行们(c).size()
	var n := 0
	for 行 in _行们(c):
		if str(行).contains(子串):
			n += 1
	return n

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
