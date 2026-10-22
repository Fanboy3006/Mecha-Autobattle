## 天人 v0.1：TRANS-AM / 太阳炉牌库 / 9 张势力牌 / 拉塞 CB5 / 四名驾驶员的完整卡池与独有机制。
## 卡表是数据（`data/cards/天人.json` → `Db.T.卡包["天人"]`）；本文件只留构建函数、算子与状态机。
## 纯读纪律：状态行 / 标签行 / 伤害倍率 / 命中修正 / 狙溢暴击 / 演算满足 / 公有牌可打 不改状态、不掷随机数。
## 规则原文见 协作/设计/天人势力卡牌设计 v0.1.md 与 势力与职业卡牌设计规范 v0.3.md。
class_name CelestialV01
extends RefCounted

const 势力 := "天人"
const 成员键: Array = ["CB1", "CB2", "CB3", "CB4", "CB5"]
## 四名高达驾驶员（拥有 `TRANS-AM·启动`）。
const 驾驶员键: Array = ["CB1", "CB2", "CB3", "CB4"]
## `TRANS-AM·启动` 的入场牌 id（大招槽卡）。
const 大招ID := "CB_ULT_TRANSAM"
const 公有上限 := 6
## TRANS-AM / 粒子耗尽的回合数与倍率（数值全部照任务单 §1.2 第 2 条）。
const TRANSAM回合 := 3
const TRANSAM伤害倍率 := 1.3
const TRANSAM闪避 := 15.0
const 粒子耗尽伤害倍率 := 0.7
## 太阳炉牌库的等级键（`SubDeck` 用它判「回库 / 移出」与断路器 1）。
const 炉等级键 := "太阳炉等级"

# ---- 零、卡表数据：本文件只读 `Db.T`，IO 只在 `session/data_loader.gd`。 ----
## 天人卡包（整个 JSON）；没装入就报错并给空字典（绝不静默回退）。
static func 卡包() -> Dictionary:
	var 包们 = Db.T.get("卡包")
	var 包 = (包们 as Dictionary).get(势力) if 包们 is Dictionary else null
	if not (包 is Dictionary):
		push_error("天人卡表没装入：缺 Db.T.卡包[\"%s\"]（见 session/data_loader.gd 与 data/cards/天人.json）" % 势力)
		return {}
	return 包

static func _额外(条目: Dictionary, 参键们: Array, 算子额外: Dictionary = {}, 卡名: String = "") -> Dictionary:
	var 名 := 卡名 if 卡名 != "" else str(条目.get("名", ""))
	var 武名 := str(条目.get("武器名", 名))
	var 出 := {}
	for k in 条目.keys():
		if k in 参键们 or k == "算子" or k == "武器名" or k == "+" or k == "加号后缀":
			continue
		if k == "武器参":
			出["武器"] = _武(武名, _武参(条目[k]))
		elif k == "剑数" or k == "等级需求":
			出[k] = int(条目[k])
		elif 条目[k] is Array or 条目[k] is Dictionary:
			出[k] = 条目[k].duplicate(true)
		else:
			出[k] = 条目[k]
	if 条目.has("算子"):
		出["效果"] = _炉算子(str(条目["算子"]), 算子额外)
	return 出

static func _武参(参: Dictionary) -> Dictionary:
	if not (参.get("距离") is Array):
		return 参
	var 出 := 参.duplicate(true)
	var 距: Array = []
	for x in 出["距离"]:
		距.append(int(x))
	出["距离"] = 距
	return 出

static func _合并加号(条目: Dictionary, 加号: bool) -> Dictionary:
	var 出 := 条目.duplicate(true)
	出.erase("+")
	var 覆盖 = 条目.get("+")
	if 加号 and 覆盖 is Dictionary:
		_深并(出, 覆盖)
	return 出

static func _深并(目标: Dictionary, 覆盖: Dictionary) -> void:
	for k in 覆盖.keys():
		var v = 覆盖[k]
		if 目标.get(k) is Dictionary and v is Dictionary:
			_深并(目标[k], v)
		elif v is Array or v is Dictionary:
			目标[k] = v.duplicate(true)
		else:
			目标[k] = v

# ---- 一、开关与成员识别（全部纯读） ----
## 本件是否生效：`Params.单机牌组_开(ctx)` **且** 场上有天人成员。
static func 开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	if 选 is Dictionary and (选 as Dictionary).get("天人v01") == false:
		return false
	return 有成员(ctx)

static func 有成员(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 and 是天人(u):
			return true
	return false

static func _键Of(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var k := str((u as Dictionary).get("key", ""))
	if k != "":
		return k
	return str((u as Dictionary).get("tplKey", ""))

## 这台机体是不是天人成员（`tags.势力 == "天人"`，或者 key 就是 `CB1..CB5`）。
static func 是天人(u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if J.inc(Units.势力们(u), 势力):
		return true
	return J.inc(成员键, _键Of(u))

static func 是驾驶员(u: Variant) -> bool:
	return u is Dictionary and J.inc(驾驶员键, _键Of(u))

static func 是拉塞(u: Variant) -> bool:
	return u is Dictionary and _键Of(u) == "CB5"

## 这台机体是不是掩护的承担者（塔斯克与拉塞 CB5 同一口径）。
static func 是掩护者(u: Variant) -> bool:
	return 是拉塞(u)

# ---- 二、TRANS-AM / 粒子耗尽（纯读 + 两个状态机入口） ----
static func transam中(u: Variant) -> bool:
	return u is Dictionary and int(J.num0((u as Dictionary).get("transam剩余回合", 0))) > 0

static func 粒子耗尽中(u: Variant) -> bool:
	return u is Dictionary and int(J.num0((u as Dictionary).get("粒子耗尽剩余回合", 0))) > 0

static func 伤害倍率(ctx: Variant, att: Variant, w: Variant) -> float:
	if not 开(ctx) or not (att is Dictionary) or not (w is Dictionary):
		return 1.0
	var kind = Reach.rangeKindOf(w)
	if kind == Reach.KIND_HEAL() or kind == Reach.KIND_SUPPORT() or kind == null:
		return 1.0
	if transam中(att):
		return TRANSAM伤害倍率
	if 粒子耗尽中(att):
		return 粒子耗尽伤害倍率
	return 1.0

## 命中修正（预告与真结算同源）：TRANS-AM 中闪避 +15 ⇒ 打它的人 −15。
static func 命中修正(_att: Variant, def: Variant, _w: Variant, ctx: Variant) -> float:
	if not 开(ctx) or not (def is Dictionary):
		return 0.0
	var 修 := 0.0
	if transam中(def):
		修 -= TRANSAM闪避
	# [双人格] 哈雷路亚人格闪避 +10（打它的人每段命中 −10）。
	if 哈雷路亚中(def):
		修 -= 10.0
	return 修

## 拉塞【GN 力场】：替队友承受的光束伤害 −40%。
static func 掩护力场倍率(ctx: Variant, action: Variant, def: Variant, w: Variant) -> float:
	if not 开(ctx) or not (action is Dictionary) or not (def is Dictionary):
		return 1.0
	if not J.truthy((action as Dictionary).get("掩护接管")):
		return 1.0
	if not 是拉塞(def):
		return 1.0
	if str(J.g(w, "dmgType")) != "光束":
		return 1.0
	return 0.6

## 真的开启 TRANS-AM（大招算子入口，也被各人被动复用）。
static func 开启TRANSAM(ctx: Dictionary, u: Dictionary) -> Array:
	if not 开(ctx):
		return []
	if not 是驾驶员(u):
		return ["只有四名高达驾驶员能开 TRANS-AM"]
	if J.truthy(u.get("本场已开TRANSAM")):
		return ["本场已经开过 TRANS-AM（每场 1 次）"]
	u["本场已开TRANSAM"] = true
	ctx["本场有人开过TRANSAM"] = true
	u["transam剩余回合"] = TRANSAM回合
	u["粒子耗尽剩余回合"] = 0
	# [阿雷路亚] TRANS-AM 一开就点亮「超兵同调」。
	if _键Of(u) == "CB3":
		u["超兵同调"] = true
	Btl.pushLog(ctx, "〔TRANS-AM〕%s 启动！接下来 %d 个我方阶段：武器伤害 ×%s、闪避 +%s、武力介入必触发" % [
		str(u.get("name", "")), TRANSAM回合, J.s(TRANSAM伤害倍率), J.s(TRANSAM闪避)],
		J.merged({"类型": "TRANS-AM", "动作": "启动", "单位": u.get("key"),
			"剩余回合": TRANSAM回合, "伤害倍率": TRANSAM伤害倍率, "闪避加": TRANSAM闪避}, Btl.谁(u)))
	return ["作用于【%s】：TRANS-AM 启动（%d 个我方阶段内 伤害 ×%s、闪避 +%s、武力介入必触发）" % [
		str(u.get("name", "")), TRANSAM回合, J.s(TRANSAM伤害倍率), J.s(TRANSAM闪避)]]

# ---- 三、初始化与阶段时序 ----
static func 初始化(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	ctx["本场有人开过TRANSAM"] = false
	ctx["本回合打过Veda"] = false
	ctx["太阳炉移出"] = []
	ctx["cb行动预测回合"] = 0
	ctx["cb行动预测已用"] = true
	ctx["太阳炉牌库"] = SubDeck.新建()
	for c in 太阳炉卡表():
		if int(J.num0(c.get(炉等级键))) != 1:
			continue
		SubDeck.放入(ctx["太阳炉牌库"], c.duplicate(true), null, "", 炉等级键, SubDeck.移出下限)
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		u.erase("transam剩余回合")
		u.erase("粒子耗尽剩余回合")
		u.erase("本场已开TRANSAM")
		# 四名驾驶员的「本场」状态在这里清干净。
		u.erase("出鞘")
		u.erase("本场七剑齐出过")
		u.erase("本场脱装过")
		u.erase("右眼负伤")
		u.erase("本场两人格都出现过")
		u.erase("超兵同调")
		if _键Of(u) == "CB3":
			u["人格"] = 人格阿雷路亚
			u["本场出现过人格"] = [人格阿雷路亚]
		if 是拉塞(u):
			u["掩护上限"] = 2
			u["掩护剩余"] = 2
	Btl.pushLog(ctx, "〔天人〕太阳炉牌库就位：%s（一至三级共 %d 张，全队一份、0 费、不占主武器）" % [
		SubDeck.各级张数(ctx["太阳炉牌库"], 炉等级键), 牌数Of(ctx.get("太阳炉牌库"))],
		{"类型": "太阳炉", "动作": "初始化",
			"牌库": 太阳炉名们(ctx)})

static func 阶段初(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	for e in J.or_(ctx.get("enemies"), []):
		if not (e is Dictionary):
			continue
		e["本回合被攻击过"] = false
		e["本回合任务目标"] = false
	ctx["本回合打过Veda"] = false
	# [脱装] 「不能攻击」只活一个敌方阶段，每个我方阶段初清掉。
	清脱装不能攻击(ctx)
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary):
			continue
		u.erase("cb下张")
		u.erase("cb下张武器命中")
		u.erase("cb下张武器目标")
		u.erase("cb根除目标")
		u.erase("cb根除回合")
		u.erase("cb专注中")
		u.erase("本回合剑牌已打")
		u.erase("剑舞中")
		u.erase("剑舞减伤")
		u.erase("本回合命中罚")
		u.erase("本回合近战命中罚")
		u.erase("本回合禁援护")
		u.erase("本回合不被动切换")
		u.erase("狙击直觉回合")
		u.erase("独自判断回合")
		u.erase("双重思考回合")
		u.erase("本回合不能打武器牌")
		u.erase("cb援护满伤目标")
		# [贯穿] 代价：下个我方阶段粒子耗尽。
		if J.truthy(u.get("下场粒子耗尽")):
			u["下场粒子耗尽"] = false
			u["粒子耗尽剩余回合"] = 1
			Btl.pushLog(ctx, "〔粒子耗尽〕%s 因为「GN 剑·贯穿」的代价，这个我方阶段伤害 ×%s" % [
				str(u.get("name", "")), J.s(粒子耗尽伤害倍率)],
				J.merged({"类型": "TRANS-AM", "动作": "粒子耗尽", "单位": u.get("key"),
					"粒子耗尽": 1, "伤害倍率": 粒子耗尽伤害倍率}, Btl.谁(u)))
		# [爆裂模式] 炮管过热：下个我方阶段武器牌全消。
		if J.truthy(u.get("下回合武器全消")):
			u["下回合武器全消"] = false
			u["主武器已销毁"] = true
			Btl.pushLog(ctx, "〔过热〕%s 的炮管过热 → 这个我方阶段的武器牌全部消掉" % str(u.get("name", "")),
				J.merged({"类型": "过热", "单位": u.get("key")}, Btl.谁(u)))

## 敌方阶段开始：拉塞的掩护额度回到满（基础 2/2，装甲焊补可 +1）。
static func 敌方阶段初(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and 是拉塞(u):
			u["掩护上限"] = BattleGuard.掩护额度(u)
			u["掩护剩余"] = BattleGuard.掩护额度(u)

static func 我方阶段末(ctx: Dictionary) -> void:
	if not 开(ctx):
		return
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary) or not 是驾驶员(u):
			continue
		var 剩 := int(J.num0(u.get("transam剩余回合", 0)))
		if 剩 > 0:
			u["transam剩余回合"] = 剩 - 1
			if 剩 - 1 <= 0:
				u["粒子耗尽剩余回合"] = 1
				# TRANS-AM 结束 → 「超兵同调」一起结束。
				u.erase("超兵同调")
				Btl.pushLog(ctx, "〔TRANS-AM〕%s 的 TRANS-AM 结束 → 进入**粒子耗尽**（接下来 1 个我方阶段 伤害 ×%s）" % [
					str(u.get("name", "")), J.s(粒子耗尽伤害倍率)],
					J.merged({"类型": "TRANS-AM", "动作": "结束", "单位": u.get("key"),
						"粒子耗尽": 1, "伤害倍率": 粒子耗尽伤害倍率}, Btl.谁(u)))
			else:
				Btl.pushLog(ctx, "〔TRANS-AM〕%s 又过完 1 个我方阶段（还剩 %d 个）" % [
					str(u.get("name", "")), 剩 - 1],
					J.merged({"类型": "TRANS-AM", "动作": "递减", "单位": u.get("key"),
						"剩余回合": 剩 - 1}, Btl.谁(u)))
			continue
		var 粒 := int(J.num0(u.get("粒子耗尽剩余回合", 0)))
		if 粒 > 0:
			u["粒子耗尽剩余回合"] = 粒 - 1
			Btl.pushLog(ctx, "〔TRANS-AM〕%s 的**粒子耗尽**结束（恢复正常）" % str(u.get("name", "")),
				J.merged({"类型": "TRANS-AM", "动作": "粒子耗尽结束", "单位": u.get("key")}, Btl.谁(u)))

static func 状态行(u: Variant, _ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary) or not 是天人(u):
		return 出
	var 名 := str((u as Dictionary).get("name", ""))
	if transam中(u):
		出.append("%s〔TRANS-AM 剩%d回〕伤害 ×%s、闪避 +%s、武力介入必触发" % [
			名, int(J.num0(u.get("transam剩余回合"))), J.s(TRANSAM伤害倍率), J.s(TRANSAM闪避)])
	if 粒子耗尽中(u):
		出.append("%s〔粒子耗尽〕伤害 ×%s（剩 %d 个我方阶段）" % [
			名, J.s(粒子耗尽伤害倍率), int(J.num0(u.get("粒子耗尽剩余回合")))])
	if J.truthy((u as Dictionary).get("本场已开TRANSAM")) and not transam中(u) and not 粒子耗尽中(u):
		出.append("%s〔TRANS-AM 已用完（本场 1 次）〕" % 名)
	# 四名驾驶员的紧凑标签（`〔出鞘 n/7〕` / `〔哈雷路亚〕` / …）。
	for 标 in 标签行(u, _ctx):
		出.append("%s%s" % [名, str(标)])
	return 出

# ---- 四、敌机「本回合被攻击过」+【武力介入】 ----
## 被选为目标或结算过的敌机 → 本回合被攻击过（打空也算）。
static func 标记被攻击(ctx: Variant, 敌机: Variant) -> void:
	if not (ctx is Dictionary) or not (敌机 is Dictionary):
		return
	if str((敌机 as Dictionary).get("side", "")) != "enemy":
		return
	(敌机 as Dictionary)["本回合被攻击过"] = true

static func 标记被攻击们(ctx: Variant, 敌机们: Variant) -> void:
	for e in J.or_(敌机们, []):
		标记被攻击(ctx, e)

## 【武力介入】是否满足（纯读）。
static func 武力介入满足吗(ctx: Variant, 施放者: Variant, 目标敌机: Variant) -> bool:
	if not 开(ctx):
		return false
	if transam中(施放者):
		return true
	if not (目标敌机 is Dictionary):
		return false
	if not J.truthy((目标敌机 as Dictionary).get("本回合被攻击过", false)):
		return true
	return J.truthy((目标敌机 as Dictionary).get("本回合任务目标", false))

## 触发【武力介入】：随机抽 1 张进公有手牌（满 6 张不抽），再放入 `介入放入` 的牌。
static func 触发武力介入(ctx: Dictionary, 施放者: Variant, 目标敌机: Variant, card: Variant) -> Dictionary:
	var 记 := {"触发": false, "抽到": "", "放入": "", "原因": ""}
	if not 开(ctx):
		return 记
	if not 武力介入满足吗(ctx, 施放者, 目标敌机):
		记["原因"] = "目标本回合已经被打过（【武力介入】不再触发）"
		return 记
	记["触发"] = true
	var 抽 := 抽太阳炉(ctx)
	if not 抽.is_empty():
		记["抽到"] = str(抽.get("名", ""))
	# `介入放入`：先看打出的那张牌，再看抽到的那张。
	var 放 := ""
	if card is Dictionary:
		放 = str(J.or_((card as Dictionary).get("介入放入"), ""))
	if 放 == "" and not 抽.is_empty():
		放 = str(J.or_(抽.get("介入放入"), ""))
	if 放 != "":
		if 放入太阳炉(ctx, 放):
			记["放入"] = 放
			Btl.pushLog(ctx, "〔武力介入〕把【%s】放进太阳炉牌库（本场有效）" % _炉名(放),
				{"类型": "武力介入", "动作": "放入", "卡牌ID": 放, "卡牌": _炉名(放)})
	var 名 := str((目标敌机 as Dictionary).get("name", "")) if 目标敌机 is Dictionary else "（无指定目标）"
	var 尾 := []
	if str(记["抽到"]) != "":
		尾.append("抽到【%s】" % str(记["抽到"]))
	elif 公有手牌满(ctx):
		尾.append("公有手牌已满 %d 张 → 牌留在太阳炉牌库" % 公有上限)
	if str(记["放入"]) != "":
		尾.append("并把【%s】放进太阳炉牌库" % _炉名(str(记["放入"])))
	Btl.pushLog(ctx, "〔武力介入〕%s 打 %s → 触发！（%s）" % [
		str((施放者 as Dictionary).get("name", "")) if 施放者 is Dictionary else "天人成员", 名,
		"；".join(尾) if not 尾.is_empty() else "太阳炉牌库空了 / 手牌满，没有新牌"],
		J.merged({"类型": "武力介入", "动作": "触发", "单位": J.g(施放者, "key"),
			"目标": J.g(目标敌机, "key"), "抽到": 记["抽到"], "放入": 记["放入"]},
			Btl.谁(施放者) if 施放者 is Dictionary else {}))
	return 记

## 打出带【武力介入】的牌之前判一次（各类牌共用）。
static func 打出前介入(ctx: Dictionary, u: Variant, card: Variant, target_id: Variant) -> Dictionary:
	if not 开(ctx) or not (card is Dictionary):
		return {}
	if not J.truthy((card as Dictionary).get("武力介入")):
		return {}
	var 目标 = Btl._存活敌(ctx, u, target_id) if u is Dictionary else null
	return 触发武力介入(ctx, u, 目标, card)

## 记「这一张牌打过了」（`veda` 牌 → 全队 `本回合打过Veda`）。
static func 记打出(ctx: Variant, card: Variant) -> void:
	if not (ctx is Dictionary) or not (card is Dictionary):
		return
	if J.truthy((card as Dictionary).get("veda")):
		(ctx as Dictionary)["本回合打过Veda"] = true

static func 本回合打过Veda(ctx: Variant) -> bool:
	return ctx is Dictionary and J.truthy((ctx as Dictionary).get("本回合打过Veda"))

# ---- 五、太阳炉牌库 10 张（一级 4 / 二级 4 / 三级 2） ----
static func _炉底(id: String, 名: String, 级: int, 目标: String, 额外: Dictionary) -> Dictionary:
	var d := {
		"id": id, "名": 名, "卡类": "公有牌", "类型": "战术", "层级": "势力", "种类": "太阳炉",
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": 0.0, "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": 级 <= 2, 炉等级键: 级, "衍生": false, "入库条件": null,
		"获取": "初始", "等级需求": 10, "效果说明": "", "效果": [], "连携": false, "连携放入": null,
		"武器牌": false, "不占主武器": true, "目标": 目标, "veda": false, "太阳炉": true,
	}
	return _并(d, 额外)

static func _并(d: Dictionary, 额外: Variant) -> Dictionary:
	if 额外 is Dictionary:
		for k in (额外 as Dictionary).keys():
			d[k] = 额外[k]
	return d

static func _炉算子(动作: String, 额外: Dictionary = {}) -> Array:
	var 表 := {"算子": "cb", "动作": 动作}
	_并(表, 额外)
	return [{"全局": [表]}]

static var _炉表: Array = []
static var _炉代: int = -1

static func 太阳炉卡表() -> Array:
	if _炉代 != Db.代:
		_炉表 = _构建太阳炉()
		_炉代 = Db.代
	return _炉表

static func _构建太阳炉() -> Array:
	var 表: Array = []
	for 条目 in 卡包().get("太阳炉", []):
		表.append(_炉底(str(条目.get("id", "")), str(条目.get("名", "")),
			int(条目.get("级", 0)), str(条目.get("目标", "")), _额外(条目, ["id", "名", "级", "目标"])))
	return 表

static func 太阳炉卡(id: Variant) -> Dictionary:
	var 键 := str((id as Dictionary).get("id", "")) if id is Dictionary else str(id)
	for c in 太阳炉卡表():
		if str(c.get("id")) == 键:
			return c.duplicate(true)
	return {}

static func 是太阳炉牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return J.truthy((c as Dictionary).get("太阳炉")) or str((c as Dictionary).get("id", "")).begins_with("CB_SD")

static func 牌数Of(库: Variant) -> int:
	return SubDeck.牌们(库).size()

static func 太阳炉名们(ctx: Variant) -> Array:
	var 库 = (ctx as Dictionary).get("太阳炉牌库") if ctx is Dictionary else null
	return SubDeck.牌们(库).map(func(c): return str(c.get("名", "")))

## 抽 1 张太阳炉牌进 `ctx.公有手牌`（满 6 张不抽，牌留在库里）。
static func 抽太阳炉(ctx: Dictionary) -> Dictionary:
	var 库 = ctx.get("太阳炉牌库")
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var 抽 := SubDeck.抽一张(库, 手, 公有上限, ctx.get("rng"))
	if not 抽.is_empty():
		ctx["公有手牌"] = 手
		Btl.pushLog(ctx, "〔太阳炉〕抽到【%s】（%s 级；公有手牌 %d/%d）" % [
			str(抽.get("名", "")), _级名(int(J.num0(抽.get(炉等级键)))), 手.size(), 公有上限],
			{"类型": "太阳炉", "动作": "抽到", "卡牌ID": 抽.get("id"), "卡牌": 抽.get("名"),
				"级": int(J.num0(抽.get(炉等级键))), "手牌数": 手.size()})
	return 抽

## 把一张牌放进太阳炉牌库（三级牌每场限 1 次，由 `SubDeck.放入` 判）。
static func 放入太阳炉(ctx: Dictionary, id: Variant) -> bool:
	if not 开(ctx):
		return false
	var 卡 := 太阳炉卡(id)
	if 卡.is_empty():
		return false
	if not (ctx.get("太阳炉牌库") is Dictionary):
		ctx["太阳炉牌库"] = SubDeck.新建()
	return SubDeck.放入(ctx["太阳炉牌库"], 卡, null, "", 炉等级键, SubDeck.移出下限)

static func 太阳炉状态(ctx: Variant) -> Dictionary:
	var 库 = (ctx as Dictionary).get("太阳炉牌库") if ctx is Dictionary else null
	var 计 := SubDeck.各级张数(库, 炉等级键)
	return {"张数": 牌数Of(库), "一级": int(计["一级"]), "二级": int(计["二级"]),
		"三级": int(计["三级"]), "卡牌": 太阳炉名们(ctx)}

static func 公有手牌满(ctx: Variant) -> bool:
	return ctx is Dictionary and J.or_((ctx as Dictionary).get("公有手牌"), []).size() >= 公有上限

static func _级名(级: int) -> String:
	match 级:
		1: return "一"
		2: return "二"
		3: return "三"
	return str(级)

static func _炉名(id: Variant) -> String:
	var 卡 := 太阳炉卡(id)
	return str(卡.get("名", "")) if not 卡.is_empty() else str(id)

# ---- 六、太阳炉牌 / 势力牌 的打出入口 ----
## 打出太阳炉牌：0 费、不占主武器、一级 / 二级回库、三级移出本场。
static func 打出太阳炉牌(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	if not 开(ctx):
		return {"成功": false, "原因": "天人 v0.1 未开启"}
	if not 是天人(u):
		return {"成功": false, "原因": "太阳炉牌只有天人成员能打"}
	# ★ CR-2 Batch B（P2-2）：卡级门槛的唯一真源（门面「亮不亮」调的是同一个函数）
	var 门因 := CardPlay.不可打原因(ctx, u, card, CardPlay.区_公有)
	if 门因 != "":
		return {"成功": false, "原因": 门因}
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	if not _在手牌(手, card):
		return {"成功": false, "原因": "公有手牌里没有这张太阳炉牌"}
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	var 摘要: Array = []
	记打出(ctx, card)
	打出前介入(ctx, u, card, target_id)
	if card.get("效果") is Array:
		摘要 = CardEffects.execute(ctx, card)
	_离手(ctx, card)
	# 一级 / 二级回库、三级移出本场（断路器 1 只约束**放入**）
	var 级 := int(J.num0(card.get(炉等级键)))
	var 移出表: Array = J.or_(ctx.get("太阳炉移出"), [])
	var 去处 := SubDeck.回库或移出(ctx.get("太阳炉牌库"), 移出表, card, 炉等级键, "回库")
	if 去处 == "移出":
		ctx["太阳炉移出"] = 移出表
	Btl.pushLog(ctx, "〔太阳炉牌〕%s 打出【%s】（0 费；%s）%s" % [str(u.get("name", "")), str(card.get("名", "")),
		"三级 → 移出本场" if 去处 == "移出" else "回太阳炉牌库", Btl.效果摘要文(摘要)],
		J.merged({"类型": "太阳炉牌", "单位": u.get("key"), "卡牌ID": card.get("id"),
			"卡牌": card.get("名"), "级": 级, "去处": 去处, "效果摘要": 摘要,
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "太阳炉": true, "级": 级,
		"去处": 去处, "效果摘要": 摘要, "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

## 打出天人势力牌（公有排、按牌面扣战意、离手进公有弃牌堆）。
static func 打出势力牌(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	if not 开(ctx):
		return {"成功": false, "原因": "天人 v0.1 未开启"}
	if not 是天人(u):
		return {"成功": false, "原因": "天人势力牌只有天人成员能打"}
	# ★ CR-2 Batch B（P2-2）：卡级门槛（含 `入库条件` / 战意）的唯一真源
	var 门因 := CardPlay.不可打原因(ctx, u, card, CardPlay.区_公有)
	if 门因 != "":
		return {"成功": false, "原因": 门因}
	var 费 := Btl.战意费用(card)
	if Btl.战意(u) < 费:
		return {"成功": false, "原因": "战意不够（要 %d，现在 %d）" % [int(费), int(Btl.战意(u))]}
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	var 摘要: Array = []
	记打出(ctx, card)
	打出前介入(ctx, u, card, target_id)
	if card.get("武器") is Dictionary and not (card.get("武器") as Dictionary).is_empty():
		摘要.append_array(Btl.攻击结果摘要(Btl._执行武器攻击(ctx, u,
			{"t": card.get("武器"), "cd": 0.0, "uses": null}, target_id)))
	if card.get("效果") is Array:
		摘要.append_array(CardEffects.execute(ctx, card))
	# 离手：公有手牌 → 公有弃牌堆
	_离手(ctx, card)
	if not (ctx.get("公有弃牌堆") is Array):
		ctx["公有弃牌堆"] = []
	ctx.公有弃牌堆.append(card)
	Btl.pushLog(ctx, "〔天人势力牌〕%s 打出【%s】（战意 -%s，剩 %s）%s" % [str(u.get("name", "")),
		str(card.get("名", "")), J.s(费), J.s(Btl.战意(u)), Btl.效果摘要文(摘要)],
		J.merged({"类型": "天人势力牌", "单位": u.get("key"), "卡牌ID": card.get("id"),
			"卡牌": card.get("名"), "战意": u.get("战意"), "效果摘要": 摘要}, Btl.谁(u)))
	DeckFlow.记上张打出牌(ctx, u, card)
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": Btl.战意(u), "费用": 费,
		"效果摘要": 摘要, "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

static func _在手牌(手: Array, card: Dictionary) -> bool:
	for c in 手:
		if is_same(c, card):
			return true
	return false

static func _离手(ctx: Dictionary, card: Dictionary) -> void:
	ctx["公有手牌"] = J.or_(ctx.get("公有手牌"), []).filter(func(c): return not is_same(c, card))

# ---- 七、天人势力牌 9 张（公有排） ----
static func _势力底(id: String, 名: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var d := {
		"id": id, "名": 名, "卡类": "公有牌", "类型": "战术", "层级": "势力", "种类": "势力",
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": 耗气, "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": true, "衍生": false, "入库条件": null, "获取": "初始", "等级需求": 10,
		"效果说明": "", "效果": [], "连携": false, "连携放入": null, "武器牌": false,
		"势力牌": true, "武力介入": false,
	}
	return _并(d, 额外)

static func _回合(n: int) -> Dictionary:
	return {"类型": "回合至少", "阈值": float(n), "说明": "第 %d 回合起" % n}

static func _武(名: String, 参: Dictionary) -> Dictionary:
	var w := {
		"name": 名, "fire": str(J.or_(参.get("武器类型"), "direct")),
		"power": float(J.or_(参.get("威力"), 1000.0)), "hit": float(J.or_(参.get("命中"), 100.0)),
		"critMod": float(J.or_(参.get("暴击"), 0.0)), "stat": str(J.or_(参.get("属性"), "射击")),
		"dmgType": str(J.or_(参.get("伤害类型"), "物理")), "cd": 0.0, "uses": null,
		"unlock": 1.0, "upgrades": [], "ignoreDef": J.truthy(参.get("无视防御")), "special": null,
		"area": str(J.or_(参.get("area"), "single")), "距离": J.or_(参.get("距离"), [1, 6]),
	}
	if J.truthy(参.get("段数")):
		var n := int(参.get("段数"))
		if n > 1:
			w["hits"] = float(n)
			w["special"] = "multi"
	if J.truthy(参.get("无视遮挡")):
		w["ignore_block"] = true
	if J.truthy(参.get("散布")):
		w["散布"] = true
	# 新武器键（没传 = 一个键都不加）：
	if 参.get("步长") != null:
		w["step"] = float(参.get("步长"))
	if J.truthy(参.get("必中")):
		w["必中"] = true
	if J.truthy(参.get("必中可暴击")):
		w["必中可暴击"] = true
	if J.truthy(参.get("狙い撃つ")):
		w["狙い撃つ"] = true
	if J.truthy(参.get("无视减伤")):
		w["无视减伤"] = true
	if 参.get("splash_mul") != null:
		w["splash_mul"] = float(参.get("splash_mul"))
	if 参.get("pierce_mul") != null:
		w["pierce_mul"] = float(参.get("pierce_mul"))
	return w

static var _势力表: Array = []
static var _势力代: int = -1

static func 势力牌们() -> Array:
	if _势力代 != Db.代:
		_势力表 = _构建势力牌()
		_势力代 = Db.代
	return _势力表

static func _构建势力牌() -> Array:
	var 表: Array = []
	for 条目 in 卡包().get("势力牌", []):
		var 名 := str(条目.get("名", ""))
		表.append(_势力底(str(条目.get("id", "")), 名,
			float(条目.get("耗气", 0.0)), _额外(条目, ["id", "名", "耗气"], {}, 名)))
	return 表

static func 是势力牌(c: Variant) -> bool:
	if not (c is Dictionary):
		return false
	return J.truthy((c as Dictionary).get("势力牌")) or str((c as Dictionary).get("id", "")).begins_with("CB_FAC_")

# ---- 八、拉塞 CB5：7 张牌 + 被动 ----
static func _拉塞(id: String, 名: String, 卡类: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var d := {
		"id": id, "名": 名, "卡类": 卡类, "类型": "战术", "层级": "角色", "种类": "角色",
		"归属": "CB5", "角色": "CB5", "角色们": ["CB5"], "占行动": [] if 卡类 != "主武器卡" else ["CB5"],
		"耗气": 耗气, "回气": 0.0, "限次": 99.0, "冷却": 0.0,
		"回库": false, "衍生": false, "入库条件": null, "获取": "初始", "等级需求": 10,
		"效果说明": "", "效果": [], "连携": false, "连携放入": null, "武器牌": false,
		"角色所属势力": 势力,
	}
	return _并(d, 额外)

## 拉塞的 7 张（`加号` = Lv20 起的 `+` 版，JSON 里是显式覆盖）。
static func 拉塞卡表(加号: bool = false) -> Array:
	var 表: Array = []
	for 原始 in 卡包().get("拉塞", []):
		var 条目 := _合并加号(原始, 加号)
		var 名 := str(条目.get("名", ""))
		if 加号 and J.truthy(条目.get("加号后缀", true)):
			名 += "+"
		表.append(_拉塞(str(条目.get("id", "")), 名, str(条目.get("卡类", "")),
			float(条目.get("耗气", 0.0)), _额外(条目, ["id", "名", "卡类", "耗气"], {}, 名)))
	return 表

## 给每台机体装专属牌时调（返回要追加进 `专属牌库` 的牌）。
static func 装填单位(u: Variant, 等级: int, ctx: Variant) -> Array:
	var 出: Array = []
	if not 开(ctx) or not (u is Dictionary):
		return 出
	# 四名驾驶员的完整卡池（主武器 / 副武器 / 大招 / 精神牌）。
	if 是驾驶员(u):
		return 装填驾驶员(u, 等级, ctx)
	if not 是拉塞(u):
		return 出
	for c in 拉塞卡表(等级 >= 20):
		出.append(c.duplicate(true))
	return 出

## 给四名驾驶员装 `TRANS-AM·启动`（大招槽卡，不进抽牌堆）。
static func 装填大招槽(ctx: Dictionary, u: Variant) -> void:
	if not 开(ctx) or not (u is Dictionary) or not 是驾驶员(u):
		return
	if J.truthy(ctx.get("禁止TRANSAM入场")):
		return
	for 槽 in J.or_(u.get("大招槽"), []):
		if 槽 is Dictionary and str((槽.get("卡") if 槽.get("卡") is Dictionary else {}).get("id", "")) == 大招ID:
			return
	if not (u.get("大招槽") is Array):
		u["大招槽"] = []
	u.大招槽.append(_大招槽条目(u))

## `TRANS-AM·启动` 的入场牌；数据在 JSON 的 `大招`。
static func 大招卡() -> Dictionary:
	var 条 = 卡包().get("大招")
	if not (条 is Dictionary) or (条 as Dictionary).is_empty():
		return {}
	var 出 := {}
	for k in (条 as Dictionary).keys():
		var v = (条 as Dictionary)[k]
		if k == "算子":
			出["效果"] = _炉算子(str(v))
		elif k == "等级需求":
			出[k] = int(v)
		elif v is Array or v is Dictionary:
			出[k] = v.duplicate(true)
		else:
			出[k] = v
	return 出

static func _大招槽条目(u: Variant) -> Dictionary:
	var 卡 := 大招卡()
	if u is Dictionary:
		卡["角色"] = _键Of(u)
	return {
		"卡": 卡, "cd": 0.0, "cd_max": 0.0, "is_weapon": false,
		"已解锁": true, "解锁说明": "", "实时门槛满足": true, "门槛说明": "", "本回合已打": false,
		"处理者": "CelestialV01",
	}

# ---------------- ★ CR-3 Batch B：大招槽按处理者分派（`DeckFlow` 只认 `处理者`） ----------------
## 这个槽归本模块吗（纯读）：天人驾驶员 / 拉塞 的任意 `大招槽卡`。
static func 认领大招槽(ctx: Dictionary, u: Variant, 槽: Dictionary) -> String:
	if not 开(ctx) or not (槽 is Dictionary) or not (u is Dictionary):
		return ""
	if not (是驾驶员(u) or 是拉塞(u)):
		return ""
	var 卡 = (槽 as Dictionary).get("卡")
	if not (卡 is Dictionary) or str((卡 as Dictionary).get("卡类", "")) != "大招槽卡":
		return ""
	return "CelestialV01"

## 规则钩子【大招不可打原因】：额外可打条件（只在真给出原因时 `终局`，否则交给通用门槛）。
static func 大招不可打原因(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> Dictionary:
	var 因 := 大招卡不可打原因(ctx, u, (槽 as Dictionary).get("卡"))
	return {"终局": 因 != "", "原因": 因}

## 规则钩子【大招打出前】：「这一张打过了」（veda）+【武力介入】先判定、再打。
static func 大招打出前(ctx: Dictionary, u: Variant, 卡: Dictionary, _槽: Variant, target_id: Variant) -> void:
	记打出(ctx, 卡)
	打出前介入(ctx, u, 卡, target_id)

## 规则钩子【条件值】：天人专属的入库 / 亮起条件（认不出来 → 不接手）。
static func 条件值(ctx: Variant, u: Variant, t: String, 条: Variant) -> Dictionary:
	var v = 条件满足(ctx, u, t, 条, 0.0)
	if v == null:
		return {"终局": false}
	return {"终局": true, "值": J.truthy(v)}

# ---- 九、算子实现（`CardEffects.执行算子` 的 `"cb"` 分支） ----
static func _ctxOf(运行: Dictionary) -> Dictionary:
	var c = 运行.get("ctx")
	return c if c is Dictionary else {}

static func _施放者(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 键 := str(ctx.get("_当前出牌者", ""))
	if 键 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key", "")) == 键:
				return u
	return null

static func _友军(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "ally")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	return _施放者(运行)

static func _敌方(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var t = Btl.找单位(ctx, ctx.get("_当前目标"), "enemy")
	if t is Dictionary and float((t as Dictionary).get("hp", 0.0)) > 0.0:
		return t
	var 敌们 := Units.livingOf("enemy", ctx)
	J.sort(敌们, func(a, b): return float(a.slot) - float(b.slot))
	return 敌们[0] if not 敌们.is_empty() else null

static func _名(u: Variant) -> String:
	return str((u as Dictionary).get("name", "（无）")) if u is Dictionary else "（无）"

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String, 额外: Dictionary = {}) -> void:
	var 谁 := J.merged({"类型": "天人", "牌名": 牌名}, 额外)
	if u is Dictionary:
		谁 = J.merged(谁, Btl.谁(u))
	Btl.pushLog(ctx, "〔%s〕%s%s" % [牌名, ("%s " % _名(u)) if u is Dictionary else "", 文], 谁)

static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx := _ctxOf(运行)
	if ctx.is_empty() or not 开(ctx):
		return []
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(card.get("名", ""))
	var 施 = _施放者(运行)
	match 动作:
		# ---------------- TRANS-AM ----------------
		"TRANSAM启动":
			if not (施 is Dictionary):
				return ["没有能开 TRANS-AM 的机体"]
			return 开启TRANSAM(ctx, 施)
		# ---------------- 太阳炉（一级） ----------------
		"粒子散布":
			var e = _敌方(运行)
			if not (e is Dictionary):
				return ["没有能散布粒子的敌机"]
			var 排 := Fm.rowOfSlot(float((e as Dictionary).slot))
			var 中 := 0
			for x in Units.livingOf("enemy", ctx):
				if x is Dictionary and Fm.rowOfSlot(float((x as Dictionary).slot)) == 排:
					Btl.换同源增益(x, "GN 粒子散布", {"hit": -10.0, "剩余": 1.0})
					中 += 1
			_记(ctx, 牌名, e, "所在整排 %d 台命中 −10（到下个我方阶段前）" % 中)
			return ["作用于【%s】：它所在整排（%d 台）命中 −10" % [_名(e), 中]]
		"粒子补充":
			var t1 = _友军(运行)
			if not (t1 is Dictionary):
				return ["没有能补充的天人成员"]
			Btl.加战意(t1, 10.0, ctx, 牌名)
			_记(ctx, 牌名, t1, "战意 +10（现 %s）" % J.s(Btl.战意(t1)))
			return ["作用于【%s】：战意 +10（现 %s）" % [_名(t1), J.s(Btl.战意(t1))]]
		"哈罗修理":
			var t2 = _友军(运行)
			if not (t2 is Dictionary):
				return ["没有能修理的天人成员"]
			var 上 := float((t2 as Dictionary).get("maxHp", 0.0))
			var 前 := float((t2 as Dictionary).get("hp", 0.0))
			(t2 as Dictionary)["hp"] = minf(上, 前 + J.round(上 * 0.10))
			_记(ctx, 牌名, t2, "回复 %s HP（%s → %s）" % [
				J.s(J.round(float((t2 as Dictionary).get("hp", 0.0)) - 前)), J.s(前), J.s((t2 as Dictionary).get("hp"))])
			return ["作用于【%s】：回复 %s HP" % [_名(t2),
				J.s(J.round(float((t2 as Dictionary).get("hp", 0.0)) - 前))]]
		"Veda战况分析":
			var t3 = _友军(运行)
			if not (t3 is Dictionary):
				return ["没有能分析的天人成员"]
			var 抽 := Setup.抽专属牌(t3, 1)
			_记(ctx, 牌名, t3, "抽 %d 张精神牌" % 抽.size())
			return ["作用于【%s】：抽 %d 张精神牌" % [_名(t3), 抽.size()]]
		# ---------------- 太阳炉（二级） ----------------
		"Veda任务计划":
			var e2 = _敌方(运行)
			if not (e2 is Dictionary):
				return ["没有能指定的敌机"]
			(e2 as Dictionary)["本回合任务目标"] = true
			_记(ctx, 牌名, e2, "本回合的任务目标：对它打出的【武力介入】必定满足")
			return ["作用于【%s】：本回合任务目标（武力介入必触发）" % _名(e2)]
		"Veda行动预测":
			ctx["cb行动预测回合"] = float(ctx.get("turn", 1.0))
			ctx["cb行动预测已用"] = false
			_记(ctx, 牌名, 施, "本回合敌方阶段，敌方第一次攻击命中 −30")
			return ["本回合敌方阶段：敌方第一次攻击命中 −30"]
		"GN全盾哈罗":
			var t4 = _友军(运行)
			if not (t4 is Dictionary):
				return ["没有能加盾的天人成员"]
			(t4 as Dictionary)["cb首击减伤"] = 0.40
			(t4 as Dictionary)["cb首击减伤剩余"] = 1
			_记(ctx, 牌名, t4, "到下个我方阶段前受到的第一次攻击伤害 −40%")
			return ["作用于【%s】：第一次受到的攻击伤害 −40%%" % _名(t4)]
		"超兵反应":
			var t5 = _友军(运行)
			if not (t5 is Dictionary):
				return ["没有能加闪避的天人成员"]
			Btl.换同源增益(t5, "超兵反应", {"eva": 20.0, "剩余": 1.0})
			_记(ctx, 牌名, t5, "闪避 +20（到下个我方阶段前）")
			return ["作用于【%s】：闪避 +20" % _名(t5)]
		# ---------------- 太阳炉（三级） ----------------
		"伊奥利亚遗产":
			var t6 = _友军(运行)
			if not (t6 is Dictionary):
				return ["没有能指定的天人成员"]
			if not J.truthy((t6 as Dictionary).get("本场已开TRANSAM")):
				return ["作用于【%s】：它本场还没用过 TRANS-AM（遗产用不上）" % _名(t6)]
			(t6 as Dictionary)["本场已开TRANSAM"] = false
			(t6 as Dictionary)["粒子耗尽剩余回合"] = 0
			_记(ctx, 牌名, t6, "TRANS-AM·启动 重新可用，粒子耗尽立刻解除")
			return ["作用于【%s】：`TRANS-AM·启动` 重新可用，粒子耗尽解除" % _名(t6)]
		"Veda最优解":
			var 拿 := _拿太阳炉卡(ctx, 2)
			_记(ctx, 牌名, 施, "从太阳炉牌库拿 %d 张进公有手牌（三级除外）" % 拿.size())
			return ["查看太阳炉牌库：拿 %d 张进公有手牌（%s）" % [拿.size(),
				"、".join(拿) if not 拿.is_empty() else "没有可拿的"]]
		# ---------------- 势力牌 ----------------
		"出击抽牌":
			var 抽2 := Setup.抽公有牌(ctx, 1)
			_记(ctx, 牌名, 施, "抽 %d 张公有牌" % 抽2.size())
			return ["抽 %d 张公有牌" % 抽2.size()]
		"同时多发介入":
			var e3 = _敌方(运行)
			if not (e3 is Dictionary) or not (施 is Dictionary):
				return ["没有能指的敌机"]
			(施 as Dictionary)["cb下张武器命中"] = 15.0
			(施 as Dictionary)["cb下张武器目标"] = (e3 as Dictionary).get("key")
			_记(ctx, 牌名, 施, "下一张武器牌对【%s】命中 +15" % _名(e3))
			return ["作用于【%s】：%s 下一张武器牌对它命中 +15" % [_名(e3), _名(施)]]
		"通讯支援":
			var t7 = _友军(运行)
			if not (t7 is Dictionary):
				return ["没有能指定的天人成员"]
			var 抽3 := Setup.抽专属牌(t7, 1)
			_记(ctx, 牌名, t7, "抽 %d 张精神牌" % 抽3.size())
			return ["作用于【%s】：抽 %d 张精神牌" % [_名(t7), 抽3.size()]]
		"战术预报":
			var t8 = _友军(运行)
			if not (t8 is Dictionary):
				return ["没有能指定的天人成员"]
			Btl.换同源增益(t8, "战术预报", {"eva": 20.0, "剩余": 1.0})
			_记(ctx, 牌名, t8, "闪避 +20（到下个我方阶段前）")
			return ["作用于【%s】：闪避 +20" % _名(t8)]
		"伊安的整备":
			var t9 = _友军(运行)
			if not (t9 is Dictionary):
				return ["没有能指定的天人成员"]
			var 修 := _减一张大招冷却(ctx, t9)
			if 修 == "":
				return ["作用于【%s】：没有冷却中的天人大招（`TRANS-AM·启动` 除外）" % _名(t9)]
			_记(ctx, 牌名, t9, "【%s】冷却 −1" % 修)
			return ["作用于【%s】：【%s】冷却 −1" % [_名(t9), 修]]
		"紧急补给":
			var t10 = _友军(运行)
			if not (t10 is Dictionary):
				return ["没有能指定的天人成员"]
			if not 粒子耗尽中(t10):
				return ["作用于【%s】：它现在不在粒子耗尽中" % _名(t10)]
			(t10 as Dictionary)["粒子耗尽剩余回合"] = 0
			_记(ctx, 牌名, t10, "粒子耗尽立刻解除")
			return ["作用于【%s】：粒子耗尽解除" % _名(t10)]
		"王留美情报":
			var 拿1 := _拿太阳炉卡(ctx, 1)
			_记(ctx, 牌名, 施, "从太阳炉牌库拿 %d 张进公有手牌（三级除外）" % 拿1.size())
			return ["查看太阳炉牌库：拿 %d 张进公有手牌（%s）" % [拿1.size(),
				"、".join(拿1) if not 拿1.is_empty() else "没有可拿的"]]
		"根除战争":
			var e4 = _敌方(运行)
			if not (e4 is Dictionary):
				return ["没有能指定的敌机"]
			ctx["cb根除目标"] = (e4 as Dictionary).get("key")
			ctx["cb根除回合"] = float(ctx.get("turn", 1.0))
			_记(ctx, 牌名, e4, "本回合天人成员打它伤害 +15%")
			return ["作用于【%s】：本回合天人成员打它伤害 +15%%" % _名(e4)]
		# ---------------- 拉塞精神牌 ----------------
		"GN装甲护卫":
			var t11 = _友军(运行)
			if not (t11 is Dictionary):
				return ["没有能指定的机体"]
			Btl.换同源增益(t11, "GN装甲护卫", {"受伤Mul": -0.30, "剩余": 1.0})
			_记(ctx, 牌名, t11, "受到的伤害 −30%（到下个我方阶段前）")
			return ["作用于【%s】：受到的伤害 −30%%" % _名(t11)]
		"专注":
			if not (施 is Dictionary):
				return ["没有能专注的机体"]
			(施 as Dictionary)["cb专注中"] = true
			_记(ctx, 牌名, 施, "下一张主武器牌每段命中 +20")
			return ["作用于【%s】：下一张主武器牌每段命中 +20" % _名(施)]
		"去吧刹那":
			var t12 = _友军(运行)
			if not (t12 is Dictionary):
				return ["没有能指定的天人成员"]
			Btl.加战意(t12, 10.0, ctx, 牌名)
			_记(ctx, 牌名, t12, "战意 +10（现 %s）" % J.s(Btl.战意(t12)))
			return ["作用于【%s】：战意 +10（现 %s）" % [_名(t12), J.s(Btl.战意(t12))]]
	# 四名驾驶员的算子（认不出来 = `null` → 落到下面的报错）
	var 驾驶: Variant = 执行驾驶员算子(ctx, 动作, 运行, 表)
	if 驾驶 != null:
		return 驾驶
	push_error("CelestialV01：未知的天人动作「%s」" % 动作)
	return []

static func _拿太阳炉卡(ctx: Dictionary, 张数: int) -> Array:
	var 拿: Array = []
	var 库 = ctx.get("太阳炉牌库")
	var 牌们: Array = SubDeck.牌们(库)
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var 走: Array = []
	for c in 牌们:
		if 拿.size() >= 张数:
			走.append(c)
			continue
		if c is Dictionary and int(J.num0((c as Dictionary).get(炉等级键))) >= 3:
			走.append(c)
			continue
		if 手.size() >= 公有上限:
			走.append(c)
			continue
		手.append(c)
		拿.append(str((c as Dictionary).get("名", "")))
	if not (库 is Dictionary):
		ctx["公有手牌"] = 手
		return 拿
	(库 as Dictionary)[SubDeck.牌键] = 走
	ctx["公有手牌"] = 手
	return 拿

static func _减一张大招冷却(ctx: Dictionary, u: Dictionary) -> String:
	for 槽 in J.or_(u.get("大招槽"), []):
		if not (槽 is Dictionary):
			continue
		var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
		if str(卡.get("id", "")) == 大招ID:
			continue
		if float(槽.get("cd", 0.0)) > 0.0:
			槽["cd"] = maxf(0.0, float(槽["cd"]) - 1.0)
			return str(卡.get("名", ""))
	return ""

# ---- 十、战斗管线上的几个钩子（纯读或只动自己那一台） ----
## `同时多发介入` 的一次性命中加成（开打前调）。
static func 攻击前命中(ctx: Variant, u: Variant, w: Dictionary, 目标: Variant) -> float:
	if not 开(ctx) or not (u is Dictionary):
		return 0.0
	var 加 := float(J.num0((u as Dictionary).get("cb下张武器命中", 0)))
	if 加 <= 0.0:
		return 0.0
	var 要 := str((u as Dictionary).get("cb下张武器目标", ""))
	if 要 != "" and 目标 is Dictionary and str((目标 as Dictionary).get("key", "")) != 要:
		return 0.0
	(u as Dictionary).erase("cb下张武器命中")
	(u as Dictionary).erase("cb下张武器目标")
	return 加

## 拉塞【专注】：下一张主武器牌每段命中 +20（吃一次就清）。
static func 主武器命中加成(ctx: Variant, u: Variant) -> float:
	if not 开(ctx) or not (u is Dictionary):
		return 0.0
	if not J.truthy((u as Dictionary).get("cb专注中")):
		return 0.0
	(u as Dictionary).erase("cb专注中")
	return 20.0

## 根除战争：本回合天人成员打这台敌机伤害 +15%。
static func 根除战争倍率(ctx: Variant, att: Variant, def: Variant) -> float:
	if not 开(ctx) or not (def is Dictionary) or not (att is Dictionary):
		return 1.0
	if not 是天人(att):
		return 1.0
	if str((ctx as Dictionary).get("cb根除目标", "")) != str((def as Dictionary).get("key", "")):
		return 1.0
	if not J.same((ctx as Dictionary).get("cb根除回合"), (ctx as Dictionary).get("turn", 1.0)):
		return 1.0
	return 1.15

## `Veda·行动预测`：本回合敌方阶段第一次攻击命中 −30。
static func 行动预测命中修正(ctx: Variant, att: Variant) -> float:
	if not 开(ctx) or not (att is Dictionary):
		return 0.0
	if str((att as Dictionary).get("side", "")) != "enemy":
		return 0.0
	if not J.same((ctx as Dictionary).get("cb行动预测回合"), (ctx as Dictionary).get("turn", 1.0)):
		return 0.0
	if J.truthy((ctx as Dictionary).get("cb行动预测已用", true)):
		return 0.0
	return -30.0

static func 消费行动预测(ctx: Variant, att: Variant) -> void:
	if not (ctx is Dictionary) or not (att is Dictionary):
		return
	if str((att as Dictionary).get("side", "")) != "enemy":
		return
	(ctx as Dictionary)["cb行动预测已用"] = true

## 规则钩子转发【命中修正_附加】（`RuleHooks.汇总("命中修正_附加")`）：Veda·行动预测的那一条。
static func 命中修正_附加(att: Variant, _def: Variant, _w: Variant, ctx: Variant) -> float:
	return 行动预测命中修正(ctx, att)

## 规则钩子转发【攻方伤害倍率】（`RuleHooks.依次乘("攻方伤害倍率")`）：
## TRANS-AM / 粒子耗尽 **×** 根除战争，先相乘再 `J.round` 一次（与迁移前完全一致）。
static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	return 伤害倍率(ctx, att, w) * 根除战争倍率(ctx, att, def)

## 规则钩子转发【受方伤害倍率】（`RuleHooks.依次乘("受方伤害倍率")`）：`GN 全盾·哈罗` 的首击减伤。
static func 受方伤害倍率(_ctx: Variant, _att: Variant, def: Variant, _w: Variant) -> float:
	return 首击减伤倍率(def)

## 规则钩子转发【我方阶段初_后】（`RuleHooks.广播("我方阶段初_后")`）。
static func 我方阶段初_后(ctx: Variant) -> void:
	阶段初(ctx)

## `GN 全盾·哈罗`：受到的**第一次**攻击伤害 −40%。
static func 首击减伤倍率(def: Variant) -> float:
	if not (def is Dictionary):
		return 1.0
	var 比 := float(J.num0((def as Dictionary).get("cb首击减伤", 0.0)))
	if 比 <= 0.0 or int(J.num0((def as Dictionary).get("cb首击减伤剩余", 0))) <= 0:
		return 1.0
	return maxf(0.0, 1.0 - 比)

static func 消费首击减伤(def: Variant) -> void:
	if def is Dictionary:
		(def as Dictionary).erase("cb首击减伤")
		(def as Dictionary).erase("cb首击减伤剩余")

# ---- 十一、四名高达驾驶员的卡池（CB1 / CB2 / CB3 / CB4） ----
const 人格阿雷路亚 := "阿雷路亚"
const 人格哈雷路亚 := "哈雷路亚"
## 刹那一共 5 张剑牌、7 把剑（剑数 1/1/1/2/2）。
const 剑牌张数 := 5
const 七剑总数 := 7

static func _驾驶员(id: String, 名: String, 卡类: String, 角色: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var d := {
		"id": id, "名": 名, "卡类": 卡类, "类型": "大招" if 卡类 == "大招槽卡" else "战术",
		"层级": "角色", "种类": "角色", "归属": 角色, "角色": 角色, "角色们": [角色],
		"占行动": [角色] if 卡类 == "主武器卡" else [],
		"耗气": 耗气, "回气": 0.0, "限次": 1.0, "冷却": 0.0,
		"回库": false, "衍生": false, "入库条件": null, "获取": "初始", "等级需求": 10,
		"效果说明": "", "效果": [], "连携": false, "连携放入": null, "武器牌": false,
		"角色所属势力": 势力, "天人卡": true,
	}
	d = _并(d, 额外)
	# 「每场 N 次」= 限次（会变成武器栏卡上的 `剩余次数`）。
	if 额外.get("每场次数") != null:
		d["限次"] = float(额外.get("每场次数"))
	return d

## 这台机体的驾驶员卡表（`加号` = Lv20 起的 `+` 版；空 = 不是驾驶员）。
static func 驾驶员卡表(键: Variant, 加号: bool = false) -> Array:
	var 组们 = 卡包().get("驾驶员")
	var 条目们 = (组们 as Dictionary).get(str(键)) if 组们 is Dictionary else null
	if not (条目们 is Array):
		return []
	var 表: Array = []
	for 原始 in 条目们:
		var 条目 := _合并加号(原始, 加号)
		var 名 := str(条目.get("名", ""))
		if 加号 and J.truthy(条目.get("加号后缀", true)):
			名 += "+"
		表.append(_驾驶员(str(条目.get("id", "")), 名, str(条目.get("卡类", "")), str(键),
			float(条目.get("耗气", 0.0)),
			_额外(条目, ["id", "名", "卡类", "耗气", "角色"], {"加号": 加号}, 名)))
	return 表

## 全部驾驶员卡（四人的 + 版与普通版；给测试用）。
static func 驾驶员全卡() -> Array:
	var 出: Array = []
	for k in 驾驶员键:
		出.append_array(驾驶员卡表(k, false))
		出.append_array(驾驶员卡表(k, true))
	return 出

static func 纳德雷武器表(键: String = "CB4") -> Array:
	var 出: Array = []
	for c in 驾驶员卡表(键, false):
		if J.truthy((c as Dictionary).get("纳德雷武器")):
			出.append((c as Dictionary).duplicate(true))
	return 出

## 给一台驾驶员装他的全部专属牌（按 `等级需求` 裁）。
static func 装填驾驶员(u: Variant, 等级: int, ctx: Variant) -> Array:
	var 出: Array = []
	if not 开(ctx) or not (u is Dictionary) or not 是驾驶员(u):
		return 出
	var 加号 := 等级 >= 20
	for c in 驾驶员卡表(_键Of(u), 加号):
		if int((c as Dictionary).get("等级需求", 10)) > 等级:
			continue
		# 纳德雷那 3 把**不单独抽**：只在「脱装·纳德雷」时整套换进武器栏。
		if J.truthy((c as Dictionary).get("纳德雷武器")):
			continue
		出.append((c as Dictionary).duplicate(true))
	return 出

# ---- 十二、【七剑】：剑数 / 出鞘 / 七剑齐出 / 收剑 / 拔刀 ----
static func 剑数Of(c: Variant) -> int:
	return int(J.num0((c as Dictionary).get("剑数", 0))) if c is Dictionary else 0

static func 剑牌吗(c: Variant) -> bool:
	return 剑数Of(c) > 0

## 这台机体身上的剑牌（武器栏 4 张 + 副武器栏 1 张 = 5 张 7 把）。
static func 剑牌们(u: Variant) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	for c in J.or_((u as Dictionary).get("武器栏"), []):
		if 剑牌吗(c):
			出.append(c)
	for e in J.or_((u as Dictionary).get("副武器栏"), []):
		if e is Dictionary and 剑牌吗((e as Dictionary).get("卡")):
			出.append((e as Dictionary).get("卡"))
	return 出

static func 出鞘剑数(u: Variant) -> int:
	var n := 0
	for c in 剑牌们(u):
		if J.truthy((c as Dictionary).get("出鞘")):
			n += 剑数Of(c)
	return n

static func 出鞘张数(u: Variant) -> int:
	var n := 0
	for c in 剑牌们(u):
		if J.truthy((c as Dictionary).get("出鞘")):
			n += 1
	return n

## 七剑齐出 = 5 张剑牌全部出鞘（7 把剑）。**实时判定**，收剑后自动解除。
static func 七剑齐出吗(u: Variant) -> bool:
	return 出鞘剑数(u) >= 七剑总数 and 出鞘张数(u) >= 剑牌张数

## 出鞘变化后判一次「七剑齐出」；第一次成立时点亮 `本场七剑齐出过`。
static func 判定七剑齐出(ctx: Dictionary, u: Variant) -> void:
	if not (u is Dictionary) or not 七剑齐出吗(u):
		return
	if J.truthy((u as Dictionary).get("本场七剑齐出过")):
		return
	(u as Dictionary)["本场七剑齐出过"] = true
	Btl.pushLog(ctx, "〔七剑齐出〕%s 的 5 张剑牌全部出鞘（7 把剑）→ 【七剑·TRANS-AM 乱舞】改为**完全版**！" % _名(u),
		J.merged({"类型": "七剑齐出", "单位": J.g(u, "key"), "剑数": 出鞘剑数(u)}, Btl.谁(u)))

## 收剑：`全部 == false` 时只收 `指定id` 那一张（拔刀）。
static func 收剑(ctx: Dictionary, u: Variant, 全部: bool = true, 指定id: String = "") -> Array:
	var 收: Array = []
	if not (u is Dictionary):
		return 收
	for c in 剑牌们(u):
		if not J.truthy((c as Dictionary).get("出鞘")):
			continue
		if not 全部 and str((c as Dictionary).get("id", "")) != 指定id:
			continue
		(c as Dictionary)["出鞘"] = false
		收.append(str((c as Dictionary).get("名", "")))
	if 收.is_empty():
		return 收
	Btl.pushLog(ctx, "〔收剑〕%s 收回 %d 张剑牌：%s（出鞘 剩 %d/7；**已收起的主武器不弹回**）" % [
		_名(u), 收.size(), "、".join(收.map(func(x): return "【%s】" % str(x))), 出鞘剑数(u)],
		J.merged({"类型": "收剑", "单位": J.g(u, "key"), "剑牌": 收, "出鞘": 出鞘剑数(u)}, Btl.谁(u)))
	return 收

## 一张剑牌出鞘（打出剑牌后调）。返回是否**这一次**刚好凑成七剑齐出。
static func 剑牌出鞘(u: Variant, 卡: Variant) -> bool:
	if not 剑牌吗(卡):
		return false
	(卡 as Dictionary)["出鞘"] = true
	return 七剑齐出吗(u)

static func 全部剑牌出鞘(u: Variant) -> void:
	for c in 剑牌们(u):
		(c as Dictionary)["出鞘"] = true

static func 出鞘文(u: Variant) -> String:
	if not (u is Dictionary) or _键Of(u) != "CB1":
		return ""
	if 七剑齐出吗(u):
		return "〔★七剑齐出〕"
	var n := 出鞘剑数(u)
	if n <= 0:
		return ""
	return "〔出鞘 %d/7〕" % n

# ---- 十三、【双人格】/【狙い撃つ】/【演算】/ 右眼负伤 的纯读状态 ----
static func 当前人格(u: Variant) -> String:
	if not (u is Dictionary):
		return 人格阿雷路亚
	return str(J.or_((u as Dictionary).get("人格"), 人格阿雷路亚))

static func 哈雷路亚中(u: Variant) -> bool:
	return 当前人格(u) == 人格哈雷路亚

## 「哈雷路亚：」加强段现在生效吗（人格 / 双重思考 / 超兵同调）。
static func 哈雷加成生效(ctx: Variant, u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if 哈雷路亚中(u):
		return true
	if ctx is Dictionary and J.same((u as Dictionary).get("双重思考回合"), (ctx as Dictionary).get("turn", 1.0)):
		return true
	return false

## 能不能打公有排的牌（势力牌 / 分类牌 / 太阳炉牌）：阿雷路亚永远能；
static func 公有牌可打(ctx: Variant, u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if not 哈雷路亚中(u):
		return true
	if transam中(u) or J.truthy((u as Dictionary).get("超兵同调")):
		return true
	if ctx is Dictionary and J.same((u as Dictionary).get("双重思考回合"), (ctx as Dictionary).get("turn", 1.0)):
		return true
	return false

## 【演算】满足吗：本回合全队打过 `veda` 牌，或本回合打了「独自判断」。
static func 演算满足(ctx: Variant, u: Variant) -> bool:
	if not (u is Dictionary):
		return false
	if ctx is Dictionary and J.same((u as Dictionary).get("独自判断回合"), (ctx as Dictionary).get("turn", 1.0)):
		return true
	return 本回合打过Veda(ctx)

## 【狙い撃つ】溢出的命中差转暴击（默认 1:1，狙击手的直觉 1:2）。
static func 狙溢暴击(att: Variant, w: Variant, def: Variant, ctx: Variant, 最终: float) -> float:
	if not (w is Dictionary) or not J.truthy((w as Dictionary).get("狙い撃つ")):
		return 0.0
	if not (att is Dictionary) or _键Of(att) != "CB2":
		return 0.0
	if float(最终) <= 100.0:
		return 0.0
	var 倍 := 1.0
	if ctx is Dictionary and J.same((att as Dictionary).get("狙击直觉回合"), (ctx as Dictionary).get("turn", 1.0)):
		倍 = 2.0
	return J.round((float(最终) - 100.0) * 倍)

## 「右眼负伤」的命中罚（本场持续；`+` 版 −10）。
static func 右眼命中罚(u: Variant) -> float:
	return float(J.num0((u as Dictionary).get("右眼负伤", 0.0))) if u is Dictionary else 0.0

# ---- 十四、战斗管线钩子（武器改写 / 出鞘 / 人格切换 / 形态） ----
static func _应用修正(ctx: Dictionary, u: Dictionary, w0: Variant, 元: Dictionary = {}) -> Dictionary:
	var w: Dictionary = (w0 as Dictionary).duplicate(true) if w0 is Dictionary else {}
	if w.is_empty():
		return w
	var kind = Reach.rangeKindOf(w)
	var 名们: Array = []
	# —— 一次性加成（`u.cb下张`：指定目标才吃，不吃就留着给下一张）——
	var 下 = u.get("cb下张")
	if 下 is Dictionary and not (下 as Dictionary).is_empty():
		var 要 := str((下 as Dictionary).get("目标", ""))
		if 要 == "" or str(元.get("目标", "")) == 要:
			var 命中 := float(J.num0((下 as Dictionary).get("命中")))
			var 暴击 := float(J.num0((下 as Dictionary).get("暴击")))
			var 乘 := float(J.num0((下 as Dictionary).get("伤害乘")))
			var 甲 := float(J.num0((下 as Dictionary).get("近战无视装甲")))
			if 命中 != 0.0:
				w["hit"] = float(J.num0(w.get("hit", 100.0))) + 命中
				名们.append("命中 %+d" % int(命中))
			if 暴击 != 0.0:
				w["critMod"] = float(J.num0(w.get("critMod"))) + 暴击
				名们.append("暴击 %+d" % int(暴击))
			if 乘 > 0.0 and absf(乘 - 1.0) > 0.0001:
				w["power"] = float(J.num0(w.get("power"))) * 乘
				名们.append("伤害 ×%s" % J.s(乘))
			if 甲 > 0.0 and kind == Reach.KIND_MELEE():
				w["ignoreArmorPct"] = maxf(甲, float(J.num0(w.get("ignoreArmorPct"))))
				名们.append("无视 %d%% 装甲" % int(甲 * 100.0))
			u.erase("cb下张")
	# —— 本回合的命中罚（GN 盾 / 反射神经 / 哈罗·回避 / 高机动回避）——
	var 罚 := float(J.num0(u.get("本回合命中罚")))
	if 罚 != 0.0:
		w["hit"] = float(J.num0(w.get("hit", 100.0))) + 罚
		名们.append("命中 %+d（本回合代价）" % int(罚))
	var 近罚 := float(J.num0(u.get("本回合近战命中罚")))
	if 近罚 != 0.0 and kind == Reach.KIND_MELEE():
		w["hit"] = float(J.num0(w.get("hit", 100.0))) + 近罚
		名们.append("近战命中 %+d" % int(近罚))
	# —— 右眼负伤（本场）——
	var 盲 := 右眼命中罚(u)
	if 盲 > 0.0:
		w["hit"] = float(J.num0(w.get("hit", 100.0))) - 盲
		名们.append("右眼负伤 −%d 命中" % int(盲))
	# —— 【演算】——
	var 演 = 元.get("演算")
	if 演 is Dictionary and 演算满足(ctx, u):
		if J.truthy((演 as Dictionary).get("无视遮挡")):
			w["ignore_block"] = true
			名们.append("演算：无视遮挡")
		var 演命 := float(J.num0((演 as Dictionary).get("命中")))
		if 演命 != 0.0:
			w["hit"] = float(J.num0(w.get("hit", 100.0))) + 演命
			名们.append("演算：命中 %+d" % int(演命))
	# —— 「哈雷路亚：」加强段 ——
	var 哈 = 元.get("哈雷")
	if 哈 is Dictionary and 哈雷加成生效(ctx, u):
		var 哈命 := float(J.num0((哈 as Dictionary).get("命中")))
		if 哈命 != 0.0:
			w["hit"] = float(J.num0(w.get("hit", 100.0))) + 哈命
			名们.append("哈雷路亚：命中 %+d" % int(哈命))
		var 哈暴 := float(J.num0((哈 as Dictionary).get("暴击")))
		if 哈暴 != 0.0:
			w["critMod"] = float(J.num0(w.get("critMod"))) + 哈暴
			名们.append("哈雷路亚：暴击 %+d" % int(哈暴))
		var 哈乘 := float(J.num0((哈 as Dictionary).get("伤害乘")))
		if 哈乘 > 0.0 and absf(哈乘 - 1.0) > 0.0001:
			w["power"] = float(J.num0(w.get("power"))) * 哈乘
			名们.append("哈雷路亚：伤害 ×%s" % J.s(哈乘))
	# —— 洛克昂 TRANS-AM 专属【高速狙击】：所有直射武器**无视遮挡** ——
	if _键Of(u) == "CB2" and transam中(u) and kind == Reach.KIND_DIRECT() and not J.truthy(w.get("ignore_block")):
		w["ignore_block"] = true
		名们.append("高速狙击：无视遮挡")
	# —— 「交给我吧，刹那」：刹那本回合打过的敌机，洛克昂打它命中 +20 ——
	if _键Of(u) == "CB2" and ctx.has("cb交给刹那回合") \
		and J.same(ctx.get("cb交给刹那回合"), ctx.get("turn", 1.0)):
		var 敌 = _目标敌(ctx, u)
		if 敌 is Dictionary and J.truthy((敌 as Dictionary).get("本回合被刹那打")):
			w["hit"] = float(J.num0(w.get("hit", 100.0))) + 20.0
			名们.append("交给我吧，刹那：命中 +20")
	if not 名们.is_empty():
		w["修正说明"] = "、".join(名们)
	return w

static func _目标敌(ctx: Dictionary, u: Dictionary) -> Variant:
	return Btl._存活敌(ctx, u, ctx.get("_当前目标"))

## 武器栏卡打出**之前**：返回 `{武器, 不销毁主武器}`。
static func 武器打出前(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> Dictionary:
	var 出 := {"武器": null, "不销毁主武器": false}
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary) or not 是天人(u):
		return 出
	var w0 = (卡 as Dictionary).get("武器")
	if not (w0 is Dictionary) or (w0 as Dictionary).is_empty():
		return 出
	var 敌 = _目标敌(ctx, u)
	var w := _应用修正(ctx, u, w0, {"演算": (卡 as Dictionary).get("演算"), "哈雷": (卡 as Dictionary).get("哈雷"),
		"目标": str((敌 as Dictionary).get("key", "")) if 敌 is Dictionary else ""})
	var 剑: bool = 剑牌吗(卡)
	if 剑 and J.truthy(u.get("剑舞中")):
		# 【剑舞】：这一张剑牌不消掉其余主武器，但伤害 −30%。
		出["不销毁主武器"] = true
		var 减 := float(J.num0(u.get("剑舞减伤", 1.0)))
		if 减 > 0.0 and absf(减 - 1.0) > 0.0001:
			w["power"] = float(J.num0(w.get("power"))) * 减
			w["剑舞减伤"] = 减
		u.erase("剑舞中")
		u.erase("剑舞减伤")
	elif 剑 and _键Of(u) == "CB1" and transam中(u) and not J.truthy(u.get("本回合剑牌已打")):
		# TRANS-AM 专属【迅击】：每回合第一张剑牌不收起其余主武器。
		出["不销毁主武器"] = true
		w["迅击"] = true
	if 剑:
		u["本回合剑牌已打"] = true
	出["武器"] = w
	return 出

## 副武器打出之前（洛克昂的援护射击）：继承【狙い撃つ】等。
static func 副武器打出前(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> Dictionary:
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary) or not 是天人(u):
		return {}
	var w0 = (卡 as Dictionary).get("武器")
	if not (w0 is Dictionary) or (w0 as Dictionary).is_empty():
		return {}
	var w: Dictionary = (w0 as Dictionary).duplicate(true)
	var 敌 = _目标敌(ctx, u)
	var 敌键 := str((敌 as Dictionary).get("key", "")) if 敌 is Dictionary else ""
	# 「预判射击」：本回合援护射击打**那一台**伤害改为 100%
	if str(u.get("cb援护满伤目标", "")) != "" and (敌键 == "" or 敌键 == str(u.get("cb援护满伤目标"))):
		var 基 := float(J.num0((卡 as Dictionary).get("援护基础威", 0.0)))
		if 基 > 0.0:
			w["power"] = 基
			w["援护满伤"] = true
		else:
			w["power"] = float(J.num0(w.get("power"))) / 0.7
		u.erase("cb援护满伤目标")
	w = _应用修正(ctx, u, w, {"目标": 敌键})
	return w

# ---------------- ★ CR-3 Batch B：副武器打出流程的钩子（`DeckFlow` 只认钩子） ----------------
## 规则钩子【副武器门槛】：洛克昂的「狙い撃つぜ」/「GN 全盾」代价等（只在真给出原因时 `终局`）。
static func 副武器门槛(ctx: Dictionary, u: Variant, 条目: Dictionary) -> Dictionary:
	var 因 := 副武器不可打原因(ctx, u, (条目 as Dictionary).get("卡"))
	return {"终局": 因 != "", "原因": 因}

## 规则钩子【副武器武器实例】：记打出 +【武力介入】+ 把这一发的武器实例换成算好的那份（原地改 `w`）。
static func 副武器武器实例(ctx: Dictionary, u: Variant, 卡: Dictionary, target_id: Variant, w: Dictionary) -> void:
	记打出(ctx, 卡)
	打出前介入(ctx, u, 卡, target_id)
	var 新 := 副武器打出前(ctx, u, 卡)
	if 新.is_empty():
		return
	w.clear()
	w.merge(新, true)

## 规则钩子【副武器记账后】：剑牌出鞘 / 钳爪命中减 / 刹那标记 / 双人格（打完之后的收尾）。
static func 副武器记账后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, _条目: Variant,
		_援护敌: Variant, 结果: Variant, _援护吃: bool) -> void:
	武器打完后(ctx, u, 卡, 结果)

## 武器栏卡打出之后：剑牌出鞘 / 钳爪命中减 / 刹那标记 / 被动切换。
## `结果` = `Btl._执行武器攻击` 交回来的**真实结算结果**（`结算目标们`：每项含 `实际目标` / `命中段数`）。
static func 武器打完后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 结果: Variant = null) -> void:
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary) or not 是天人(u):
		return
	# 剑牌打出 → 出鞘（不收剑；「GN 剑·全力斩+」那种不走这里）
	if 剑牌吗(卡):
		(卡 as Dictionary)["出鞘"] = true
		判定七剑齐出(ctx, u)
	# 这一发**真的挨打了**的那几台（援护把攻击接走时，这里就是援护者，不是原目标）
	var 挨打们 := _实际命中目标们(结果)
	# 【GN 盾·钳爪】：命中后目标下个敌方阶段命中 −20（哈雷路亚 −40）
	var 减 := float(J.num0((卡 as Dictionary).get("命中减", 0.0)))
	if 减 != 0.0 and 哈雷加成生效(ctx, u):
		减 = float(J.num0((卡 as Dictionary).get("哈雷", {}).get("命中减", 减)))
	if 减 != 0.0:
		for 敌 in 挨打们:
			Btl.换同源增益(敌, str((卡 as Dictionary).get("名", "GN 盾·钳爪")), {"hit": 减, "剩余": 1.0})
			Btl.pushLog(ctx, "〔GN 盾·钳爪〕%s 被夹住 → 下个敌方阶段命中 %d" % [_名(敌), int(减)],
				J.merged({"类型": "钳爪", "目标": J.g(敌, "key"), "命中": 减}, Btl.谁(u)))
	if _键Of(u) == "CB1":
		for 敌2 in 挨打们:
			(敌2 as Dictionary)["本回合被刹那打"] = true
	# 【双人格】：攻击结算后掷一次 20%（一次攻击只掷 1 次）。
	_攻击后切换(ctx, u)

## `结果` 里**实际被命中（`命中段数 > 0`）的 `实际目标`**，按结算顺序。没有结果 = 空数组。
## 倒扫战报推不出「谁挨打了」（援护 / 掩护会把攻击接走），所以只认这份真实结果。
static func _实际命中目标们(结果: Variant) -> Array:
	var 出: Array = []
	if not (结果 is Dictionary):
		return 出
	var 们 = (结果 as Dictionary).get("结算目标们")
	if 们 == null:
		们 = (结果 as Dictionary).get("实际目标")
	if not (们 is Array):
		return 出
	for 项 in 们:
		if not (项 is Dictionary):
			continue
		var 敌 = (项 as Dictionary).get("实际目标")
		if not (敌 is Dictionary):
			continue
		if J.num0((项 as Dictionary).get("命中段数")) <= 0.0:
			continue
		出.append(敌)
	return 出

## 受击结算后：阿雷路亚掷 20%。
static func 受击后(ctx: Dictionary, def: Variant) -> void:
	if not 开(ctx) or not (def is Dictionary) or not 是天人(def):
		return
	_掷切换(ctx, def, "受击")

static func _攻击后切换(ctx: Dictionary, u: Dictionary) -> void:
	if _键Of(u) == "CB3":
		_掷切换(ctx, u, "攻击")

static func _掷切换(ctx: Dictionary, u: Dictionary, 时机: String) -> bool:
	if _键Of(u) != "CB3":
		return false
	if transam中(u) or J.truthy(u.get("超兵同调")):
		return false
	if J.truthy(u.get("本回合不被动切换")):
		return false
	var 模式 := str(ctx.get("双人格切换模式", "rng"))
	if 模式 == "never":
		return false
	var 成 := 模式 == "always"
	if not 成 and 模式 != "always":
		成 = ctx.rng.next_float() < 0.2
	if not 成:
		return false
	切换人格(ctx, u, "被动切换（%s后 20%%）" % 时机)
	return true

## 真的换人格（主动 / 被动 20% 都走这一处）。
static func 切换人格(ctx: Dictionary, u: Dictionary, 原因: String = "") -> String:
	if not (u is Dictionary):
		return ""
	var 新 := 人格阿雷路亚 if 哈雷路亚中(u) else 人格哈雷路亚
	u["人格"] = 新
	if not (u.get("本场出现过人格") is Array):
		u["本场出现过人格"] = []
	var 过: Array = u.本场出现过人格
	if not J.inc(过, 新):
		过.append(新)
	u["本场出现过人格"] = 过
	if 过.size() >= 2:
		u["本场两人格都出现过"] = true
	var 尾 := "" if 原因.is_empty() else "（%s）" % 原因
	var 闪文 := "闪避 +10" if 新 == 人格哈雷路亚 else "闪避 +0"
	Btl.pushLog(ctx, "〔人格交替〕%s → **%s**%s（%s）" % [_名(u), 新, 尾, 闪文],
		J.merged({"类型": "人格", "单位": J.g(u, "key"), "人格": 新, "原因": 原因}, Btl.谁(u)))
	return 新

## 【脱装】不能攻击：敌方前排全体下个敌方阶段不能攻击。
static func 脱装不能攻击(u: Variant) -> bool:
	return u is Dictionary and J.truthy((u as Dictionary).get("脱装不能攻击"))

## 清掉「脱装不能攻击」标记（每个我方阶段初清；敌方阶段用完就没了）。
static func 清脱装不能攻击(ctx: Dictionary) -> void:
	for e in J.or_(ctx.get("enemies"), []):
		if e is Dictionary and (e as Dictionary).has("脱装不能攻击"):
			(e as Dictionary).erase("脱装不能攻击")

# ---- 十五、可打判定 / 条件 / 展示（全部纯读） ----
## 规则钩子【卡不可打原因】：太阳炉牌 / 天人势力牌 / 天人的精神牌级条件，一律由这边给结论。
static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> Dictionary:
	if not 开(ctx):
		return {"终局": false}
	var 是炉 := 是太阳炉牌(card)
	if 是炉 or 是势力牌(card):
		return {"终局": true, "原因": _牌门槛原因(ctx, u, card, 是炉)}
	var 因 := 精神牌原因(ctx, u, card, 区 == CardPlay.区_公有)
	if 因 == "":
		return {"终局": false}
	return {"终局": true, "原因": 因}

## 太阳炉牌（0 费、不判入库条件）/ 天人势力牌（要判入库条件与战意）的门槛（空串 = 能打）。
static func _牌门槛原因(ctx: Dictionary, u: Dictionary, card: Dictionary, 是炉: bool) -> String:
	if 是炉:
		if not 是天人(u):
			return "太阳炉牌只有天人成员能打"
		return 精神牌原因(ctx, u, card, true)
	if not 是天人(u):
		return "天人势力牌只有天人成员能打"
	var 因 := 精神牌原因(ctx, u, card, true)
	if 因 != "":
		return 因
	var 条 = (card as Dictionary).get("入库条件")
	if 条 is Dictionary and not DeckFlow.条件满足(ctx, u, 条):
		return "入库条件未满足：%s" % str((条 as Dictionary).get("说明", "条件没达成"))
	var 费 := Btl.战意费用(card)
	if Btl.战意(u) < 费:
		return "战意不够（要 %d，现在 %d）" % [int(费), int(Btl.战意(u))]
	return ""

## 精神牌 / 势力牌 / 太阳炉牌的额外可打条件（空串 = 能打）。
static func 精神牌原因(ctx: Variant, u: Variant, card: Variant, 从公有: bool = false) -> String:
	if not 开(ctx) or not (u is Dictionary) or not (card is Dictionary) or not 是天人(u):
		return ""
	var 卡: Dictionary = card
	if J.truthy(卡.get("本场已用")):
		return "这张牌本场已经用过了（每场 1 次）"
	var 限 := str(J.or_(卡.get("只限人格"), ""))
	if 限 != "" and 当前人格(u) != 限:
		return "只限%s人格（现在是%s）" % [限, 当前人格(u)]
	if 从公有 and not 公有牌可打(ctx, u):
		return "哈雷路亚人格打不了公有排的牌（TRANS-AM 中 / 双重思考 时才例外）"
	if J.truthy(卡.get("脱装后不可用")) and J.truthy((u as Dictionary).get("本场脱装过")):
		return "纳德雷形态用不了这张牌"
	if J.truthy((u as Dictionary).get("本回合不能打武器牌")) \
		and (str(卡.get("卡类", "")) == "主武器卡" or J.truthy(卡.get("武器牌"))):
		return "本回合不能打武器牌（Veda 权限 的代价）"
	return ""

## 武器栏卡的额外可打条件：出鞘中的剑牌不能打。
static func 武器栏不可打原因(ctx: Variant, u: Variant, 卡: Variant) -> String:
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary) or not 是天人(u):
		return ""
	if J.truthy((卡 as Dictionary).get("出鞘")):
		return "**出鞘中**（要「收剑」/「拔刀」/ 乱舞 才能恢复；不参加每回合初恢复）"
	if J.truthy((u as Dictionary).get("本回合不能打武器牌")):
		return "本回合不能打武器牌（Veda 权限 的代价）"
	if J.truthy((卡 as Dictionary).get("脱装后不可用")) and J.truthy((u as Dictionary).get("本场脱装过")):
		return "纳德雷形态用不了这张牌"
	return ""

## 天人大招的额外可打条件（哈雷路亚人格 / 本回合不能打武器牌 …；不是天人的牌 = 空串）。
static func 大招卡不可打原因(ctx: Variant, u: Variant, 卡: Variant) -> String:
	if not 开(ctx) or not (u is Dictionary) or not (卡 is Dictionary) or not 是天人(u):
		return ""
	if J.truthy((u as Dictionary).get("本回合不能打武器牌")) and J.truthy((卡 as Dictionary).get("武器牌")):
		return "本回合不能打武器牌（Veda 权限 的代价）"
	if J.truthy((卡 as Dictionary).get("脱装后不可用")) and J.truthy((u as Dictionary).get("本场脱装过")):
		return "纳德雷形态用不了这张牌"
	# 每场 1 次的武器型大招（「最后的狙击」冷却 0，只靠这一条限制）
	if J.truthy((卡 as Dictionary).get("本场已用")):
		return "这张大招本场已经用过了（每场 1 次）"
	return ""

## 副武器的额外可打条件：洛克昂的「狙い撃つぜ」/「GN 全盾」代价。
static func 副武器不可打原因(ctx: Variant, u: Variant, 卡: Variant) -> String:
	if not 开(ctx) or not (u is Dictionary) or not 是天人(u):
		return ""
	# 刹那的 `GN 光束匕首` 也是剑牌（剑 ×2）：出鞘后同样要先收剑。
	if J.truthy((卡 as Dictionary).get("出鞘")):
		return "**出鞘中**（要「收剑」/「拔刀」/ 乱舞 才能恢复）"
	if _键Of(u) != "CB2":
		return ""
	if J.truthy((u as Dictionary).get("本回合禁援护")):
		return "本回合不能打援护射击（「狙い撃つぜ」/「GN 全盾」的代价）"
	return ""

## 天人专属的入库 / 亮起条件（认不出来返回 `null`）。
static func 条件满足(ctx: Variant, u: Variant, 类型: String, 条: Variant, _阈: float) -> Variant:
	match 类型:
		"剑未出鞘":
			if not (u is Dictionary):
				return false
			var id := str((条 as Dictionary).get("剑", ""))
			for c in 剑牌们(u):
				if str((c as Dictionary).get("id", "")) == id:
					return not J.truthy((c as Dictionary).get("出鞘"))
			return true
		"TRANSAM中":
			return transam中(u)
		"人格":
			return 当前人格(u) == str((条 as Dictionary).get("值", ""))
		"七剑齐出过":
			return u is Dictionary and J.truthy((u as Dictionary).get("本场七剑齐出过"))
		"脱装过":
			return u is Dictionary and J.truthy((u as Dictionary).get("本场脱装过"))
		"双人格都出现过":
			return u is Dictionary and J.truthy((u as Dictionary).get("本场两人格都出现过"))
	return null

static func 标签行(u: Variant, _ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary) or not 是天人(u):
		return 出
	if transam中(u):
		出.append("〔TRANS-AM 剩%d〕" % int(J.num0(u.get("transam剩余回合"))))
	if 粒子耗尽中(u):
		出.append("〔粒子耗尽〕")
	var 鞘 := 出鞘文(u)
	if 鞘 != "":
		出.append(鞘)
	if _键Of(u) == "CB3":
		出.append("〔%s〕" % 当前人格(u))
	if J.truthy((u as Dictionary).get("本场脱装过")):
		出.append("〔纳德雷〕")
	if 右眼命中罚(u) > 0.0:
		出.append("〔右眼负伤〕")
	return 出

## 这台敌机要不要挂青色 `〔介入〕`（我方有天人成员且本回合还没挨打 / 任务目标）。
static func 介入吗(ctx: Variant, e: Variant) -> bool:
	if not 开(ctx) or not (e is Dictionary):
		return false
	if str((e as Dictionary).get("side", "")) != "enemy":
		return false
	if J.truthy((e as Dictionary).get("本回合任务目标")):
		return true
	return not J.truthy((e as Dictionary).get("本回合被攻击过"))

## 左栏「太阳炉牌库明细」：`[{id, 名, 级, 级名}]`（纯读；空库 = []）。
static func 太阳炉明细(ctx: Variant) -> Array:
	var 出: Array = []
	if not (ctx is Dictionary):
		return 出
	for c in SubDeck.牌们((ctx as Dictionary).get("太阳炉牌库")):
		if not (c is Dictionary):
			continue
		var 级 := int(J.num0((c as Dictionary).get(炉等级键)))
		出.append({"id": (c as Dictionary).get("id"), "名": str((c as Dictionary).get("名", "")),
			"级": 级, "级名": _级名(级), "veda": J.truthy((c as Dictionary).get("veda"))})
	return 出

static func 太阳炉左栏文(ctx: Variant) -> String:
	var 明 := 太阳炉明细(ctx)
	if 明.is_empty():
		return "太阳炉牌库：空"
	return "太阳炉牌库 %d 张：%s" % [明.size(), "、".join(明.map(func(e): return "%s(%s)" % [str(e.名), str(e.级名)]))]

# ---- 十六、四名驾驶员的算子实现 ----
static func _下张(u: Dictionary, 加: Dictionary) -> void:
	var 旧: Dictionary = (u.get("cb下张") if u.get("cb下张") is Dictionary else {}).duplicate(true)
	for k in 加.keys():
		if str(k) == "目标" and str(加[k]) == "":
			continue
		旧[k] = 加[k]
	u["cb下张"] = 旧

static func _增益(目标: Variant, 源: String, 增: Dictionary) -> void:
	if 目标 is Dictionary:
		Btl.换同源增益(目标, 源, 增)

static func _算子攻击(ctx: Dictionary, u: Dictionary, 名: String, 参: Dictionary, 元: Dictionary = {}) -> Dictionary:
	var 敌 = _目标敌(ctx, u)
	var 元2: Dictionary = 元.duplicate(true)
	元2["目标"] = str((敌 as Dictionary).get("key", "")) if 敌 is Dictionary else ""
	var w := _应用修正(ctx, u, _武(名, 参), 元2)
	var r = Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, ctx.get("_当前目标"))
	_攻击后切换(ctx, u)
	return r if r is Dictionary else {"击破": 0.0}

static func _是头目(e: Variant) -> bool:
	if not (e is Dictionary):
		return false
	return J.truthy((e as Dictionary).get("boss")) or J.truthy((e as Dictionary).get("头目")) \
		or str((e as Dictionary).get("kind", "")) == "boss"

static func 执行驾驶员算子(ctx: Dictionary, 动作: String, 运行: Dictionary, 表: Dictionary) -> Variant:
	var 施 = _施放者(运行)
	if not (施 is Dictionary):
		return []
	var u: Dictionary = 施
	var 加号 := J.truthy(表.get("加号"))
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(card.get("名", ""))
	var 敌 = _敌方(运行)
	var 键 := str((敌 as Dictionary).get("key", "")) if 敌 is Dictionary else ""
	match 动作:
		# ---------------------------------- 刹那 CB1 ----------------------------------
		"武力介入开始":
			_下张(u, {"命中": 15.0, "伤害乘": 1.10, "目标": 键})
			_记(ctx, 牌名, u, "下一张武器牌对【%s】命中 +15、伤害 +10%%" % _名(敌))
			return ["作用于【%s】：下一张武器牌命中 +15、伤害 +10%%" % _名(敌)]
		"刹那收剑":
			var 收 := 收剑(ctx, u, true)
			if not 加号:
				u["连续攻击已用"] = true
			_记(ctx, 牌名, u, "收回 %d 张出鞘的剑牌%s" % [收.size(),
				"" if 加号 else "（本回合不能用连续攻击）"])
			return ["收剑 %d 张%s（出鞘 剩 %d/7）" % [收.size(), "" if 加号 else "；本回合不能用连续攻击",
				出鞘剑数(u)]]
		"剑舞":
			u["剑舞中"] = true
			u["剑舞减伤"] = 1.0 if 加号 else 0.7
			_记(ctx, 牌名, u, "下一张剑牌打出后**不消掉其余主武器**%s" % ("" if 加号 else "（那张剑牌伤害 −30%）"))
			return ["本回合下一张剑牌不消掉其余主武器%s" % ("" if 加号 else "（伤害 −30%）")]
		"GN盾刹那":
			_增益(u, "GN 盾", {"受伤Mul": -0.30, "剩余": 1.0})
			u["本回合近战命中罚"] = -10.0
			_记(ctx, 牌名, u, "受到的伤害 −30%（到下个我方阶段前）；本回合近战命中 −10")
			return ["作用于【%s】：受伤 −30%%；本回合近战命中 −10" % _名(u)]
		"拔刀":
			var 拔 := ""
			for c in 剑牌们(u):
				if J.truthy((c as Dictionary).get("出鞘")):
					拔 = str((c as Dictionary).get("id", ""))
					break
			if 拔 == "":
				_记(ctx, 牌名, u, "现在没有出鞘的剑牌（拔刀没得收）")
				return ["作用于【%s】：没有出鞘的剑牌" % _名(u)]
			var 收2 := 收剑(ctx, u, false, 拔)
			_记(ctx, 牌名, u, "收回【%s】（出鞘 剩 %d/7）" % ["、".join(收2), 出鞘剑数(u)])
			return ["作用于【%s】：拔刀收回 1 张（出鞘 剩 %d/7）" % [_名(u), 出鞘剑数(u)]]
		"斩断扭曲":
			_下张(u, {"近战无视装甲": 0.5, "目标": 键})
			_记(ctx, 牌名, u, "下一张近战武器牌对【%s】无视 50%% 装甲" % _名(敌))
			return ["作用于【%s】：下一张近战武器牌无视 50%% 装甲" % _名(敌)]
		"我就是高达":
			Btl.加战意(u, 20.0, ctx, 牌名)
			_增益(u, "「我就是高达」", {"eva": 20.0, "剩余": 1.0})
			card["本场已用"] = true
			_记(ctx, 牌名, u, "战意 +20（现 %s）；闪避 +20（每场 1 次，已移出本场）" % J.s(Btl.战意(u)))
			return ["作用于【%s】：战意 +20、闪避 +20（每场 1 次）" % _名(u)]
		"库尔吉斯":
			_增益(u, "库尔吉斯的少年兵", {"dmgMulPct": 30.0, "剩余": 1.0})
			_增益(u, "库尔吉斯的少年兵:代价", {"eva": -20.0, "剩余": 1.0})
			_记(ctx, 牌名, u, "本回合武器伤害 +30%；到下个我方阶段前闪避 −20")
			return ["作用于【%s】：本回合武器伤害 +30%%（代价：闪避 −20）" % _名(u)]
		"七剑全开":
			Btl.加战意(u, 15.0, ctx, 牌名)
			var 抽 := Setup.抽专属牌(u, 1)
			_记(ctx, 牌名, u, "战意 +15（现 %s），抽 %d 张精神牌" % [J.s(Btl.战意(u)), 抽.size()])
			return ["作用于【%s】：战意 +15、抽 %d 张精神牌" % [_名(u), 抽.size()]]
		"刹那全力斩":
			var r1 := _算子攻击(ctx, u, "GN 剑·全力斩", {"武器类型": "melee", "威力": 3600.0, "命中": 100.0,
				"距离": [1, 2], "伤害类型": "光束", "属性": "格斗"})
			var 剑卡 := _武器栏卡(u, "CB1_W2")
			var 出鞘文 := ""
			if 剑卡.is_empty():
				出鞘文 = "（GN 剑（剑模式）不在武器栏里）"
			elif 加号:
				出鞘文 = "（`+` 版：GN 剑（剑模式）**不出鞘**）"
			else:
				(剑卡 as Dictionary)["出鞘"] = true
				判定七剑齐出(ctx, u)
				出鞘文 = "GN 剑（剑模式）出鞘（出鞘 %d/7）" % 出鞘剑数(u)
			_记(ctx, 牌名, u, 出鞘文)
			return ["打出【GN 剑·全力斩】：%s" % 出鞘文, Btl.效果摘要文(Btl.攻击结果摘要(r1))]
		"刹那乱舞":
			var 齐 := 七剑齐出吗(u)
			var 每段 := 1600.0 if 齐 else (1200.0 if 加号 else 1000.0)
			var 参 := {"武器类型": "melee", "威力": 每段, "命中": 95.0, "段数": 7, "步长": 10.0,
				"距离": [1, 2], "伤害类型": "光束", "属性": "格斗"}
			if 齐:
				参["暴击"] = 20.0
			var r2 := _算子攻击(ctx, u, "七剑·TRANS-AM 乱舞", 参)
			var 收3 := 收剑(ctx, u, true)
			if 齐:
				放入太阳炉(ctx, "CB_SD3_HERITAGE")
			_记(ctx, 牌名, u, "%s 每段 %d，打完全部收剑（%d 张）%s" % [
				"**七剑齐出·完全版**" if 齐 else "（未齐出）", int(每段), 收3.size(),
				"；并把「伊奥利亚的遗产」放进太阳炉牌库" if 齐 else ""])
			return ["打出【七剑·TRANS-AM 乱舞】：每段 %d（七剑齐出 = %s）" % [int(每段), str(齐)],
				Btl.效果摘要文(Btl.攻击结果摘要(r2))]
		"刹那贯穿":
			var r3 := _算子攻击(ctx, u, "GN 剑·贯穿", {"武器类型": "melee", "威力": 5500.0, "命中": 100.0,
				"距离": [1, 2], "伤害类型": "光束", "属性": "格斗", "无视减伤": true})
			全部剑牌出鞘(u)
			判定七剑齐出(ctx, u)
			u["下场粒子耗尽"] = true
			_记(ctx, 牌名, u, "5 张剑牌全部出鞘（出鞘 %d/7）；下个我方阶段刹那**粒子耗尽**" % 出鞘剑数(u))
			return ["打出【GN 剑·贯穿】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r3)),
				"5 张剑牌全部出鞘；下个我方阶段粒子耗尽"]
		# ---------------------------------- 洛克昂 CB2 ----------------------------------
		"乱れ撃つ":
			var 段 := 8 if 加号 else 6
			var r4 := _算子攻击(ctx, u, "「乱れ撃つぜ」", {"武器类型": "indirect", "威力": 500.0, "命中": 100.0,
				"段数": 段, "距离": [2, 5], "伤害类型": "物理", "属性": "射击", "散布": true})
			_记(ctx, 牌名, u, "曲射 · 物理 500 × %d 段 · 散布" % 段)
			return ["打出【「乱れ撃つぜ」】：500 × %d 段 · 散布" % 段, Btl.效果摘要文(Btl.攻击结果摘要(r4))]
		"TA狙击":
			var r5 := _算子攻击(ctx, u, "TRANS-AM 狙击", {"武器类型": "direct", "威力": 6000.0, "命中": 140.0,
				"距离": [2, 6], "伤害类型": "光束", "属性": "射击", "狙い撃つ": true})
			var 破 := 0.30 if 加号 else 0.20
			# 破防只认**真实受击结果**（`结算一个目标` 返回的 `实际目标` + `命中段数`）：援护把攻击接走时
			# 挨打的不是 敌，这时不挂破防 —— 不倒扫战报去猜。
			if 敌 is Dictionary and J.some(_实际命中目标们(r5), func(x): return is_same(x, 敌)):
				_增益(敌, "破防", {"受伤Mul": 破, "剩余": 1.0})
				_记(ctx, 牌名, u, "【%s】**破防**：到下个我方阶段前受到的伤害 +%d%%" % [_名(敌), int(破 * 100.0)])
			return ["打出【TRANS-AM 狙击】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r5)),
				"命中则破防 +%d%%" % int(破 * 100.0)]
		"最后的狙击":
			var r6 := _算子攻击(ctx, u, "最后的狙击", {"武器类型": "direct", "威力": 6500.0, "命中": 100.0,
				"距离": [1, 6], "伤害类型": "光束", "属性": "射击", "必中": true, "必中可暴击": true,
				"暴击": 50.0, "无视防御": true})
			u["右眼负伤"] = 10.0 if 加号 else 20.0
			card["本场已用"] = true
			_记(ctx, 牌名, u, "必中 · 无视防御 · 暴击 +50；打出后**右眼负伤**：本场命中 −%d"
				% int(右眼命中罚(u)))
			return ["打出【最后的狙击】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r6)),
				"右眼负伤：本场命中 −%d" % int(右眼命中罚(u))]
		"狙い撃つぜ":
			_下张(u, {"命中": 20.0, "目标": 键})
			u["本回合禁援护"] = true
			_记(ctx, 牌名, u, "下一张武器牌对【%s】命中 +20；本回合不能打援护射击" % _名(敌))
			return ["作用于【%s】：下一张武器牌命中 +20（本回合不能打援护射击）" % _名(敌)]
		"精密射击":
			_下张(u, {"命中": 30.0, "伤害乘": 1.0 if 加号 else 0.9})
			_记(ctx, 牌名, u, "下一张武器牌命中 +30%s" % ("" if 加号 else "；那张牌伤害 −10%"))
			return ["下一张武器牌命中 +30%s" % ("" if 加号 else "（伤害 −10%）")]
		"GN全盾洛克昂":
			_增益(u, "GN 全盾", {"受伤Mul": -0.30, "剩余": 1.0})
			u["本回合禁援护"] = true
			_记(ctx, 牌名, u, "受到的伤害 −30%（到下个我方阶段前）；本回合不能打援护射击")
			return ["作用于【%s】：受伤 −30%%（本回合不能打援护射击）" % _名(u)]
		"哈罗回避":
			_增益(u, "哈罗·回避", {"eva": 25.0, "剩余": 1.0})
			u["本回合命中罚"] = -5.0 if 加号 else -15.0
			_记(ctx, 牌名, u, "闪避 +25（到下个我方阶段前）；本回合命中 −%d" % (5 if 加号 else 15))
			return ["作用于【%s】：闪避 +25（代价：本回合命中 −%d）" % [_名(u), 5 if 加号 else 15]]
		"预判射击":
			u["cb援护满伤目标"] = 键
			_记(ctx, 牌名, u, "本回合的援护射击打【%s】伤害改为 100%%" % _名(敌))
			return ["作用于【%s】：本回合援护射击对它伤害 100%%" % _名(敌)]
		"狙击手的直觉":
			u["狙击直觉回合"] = float(ctx.get("turn", 1.0))
			_记(ctx, 牌名, u, "本回合【狙い撃つ】改为 **1:2**（溢出 1 点命中 = 暴击 +2）")
			return ["作用于【%s】：本回合【狙い撃つ】1:2" % _名(u)]
		"交给刹那":
			ctx["cb交给刹那回合"] = float(ctx.get("turn", 1.0))
			_记(ctx, 牌名, u, "本回合刹那攻击过的敌机，洛克昂打它命中 +20")
			return ["本回合：刹那打过的敌机，洛克昂命中 +20"]
		"为了家人":
			Btl.加战意(u, 20.0, ctx, 牌名)
			card["本场已用"] = true
			_记(ctx, 牌名, u, "战意 +20（现 %s；每场 1 次，已移出本场）" % J.s(Btl.战意(u)))
			return ["作用于【%s】：战意 +20（每场 1 次）" % _名(u)]
		"百发百中":
			_增益(u, "百发百中", {"hit": 40.0, "剩余": 1.0})
			_记(ctx, 牌名, u, "本回合所有攻击命中 +40")
			return ["作用于【%s】：本回合命中 +40" % _名(u)]
		# ---------------------------------- 阿雷路亚 CB3 ----------------------------------
		"人格交替":
			切换人格(ctx, u, "主动（人格交替）")
			var 抽2: Array = []
			if 加号:
				抽2 = Setup.抽专属牌(u, 1)
			return ["切换到【%s】%s" % [当前人格(u), "，抽 1 张精神牌" if not 抽2.is_empty() else ""]]
		"导弹全弹":
			var 段2 := 10 if 加号 else 8
			if 哈雷加成生效(ctx, u):
				段2 = 14 if 加号 else 12
			var r7 := _算子攻击(ctx, u, "GN 导弹·全弹", {"武器类型": "indirect", "威力": 450.0, "命中": 100.0,
				"段数": 段2, "距离": [2, 5], "伤害类型": "物理", "属性": "射击", "散布": true})
			_记(ctx, 牌名, u, "曲射 · 物理 450 × %d 段（%s）· 散布" % [段2, 当前人格(u)])
			return ["打出【GN 导弹·全弹】：450 × %d 段" % 段2, Btl.效果摘要文(Btl.攻击结果摘要(r7))]
		"极限机动":
			var 段3 := 8 if 加号 else 6
			var r8 := _算子攻击(ctx, u, "超兵·极限机动", {"武器类型": "melee", "威力": 1100.0, "命中": 100.0,
				"段数": 段3, "暴击": 15.0, "距离": [1, 2], "伤害类型": "光束", "属性": "格斗"})
			_记(ctx, 牌名, u, "近战 · 光束 1100 × %d 段 · 每段暴击 +15" % 段3)
			return ["打出【超兵·极限机动】：1100 × %d 段" % 段3, Btl.效果摘要文(Btl.攻击结果摘要(r8))]
		"双人格同步":
			var r9 := _算子攻击(ctx, u, "GN 冲撞·双人格同步", {"武器类型": "melee", "威力": 5500.0, "命中": 100.0,
				"距离": [1, 3], "伤害类型": "物理", "属性": "格斗", "必中": true, "无视遮挡": true})
			if not 加号:
				var 反 := J.round(float(u.get("maxHp", 0.0)) * 0.15)
				u["hp"] = maxf(0.0, float(u.get("hp", 0.0)) - 反)
				_记(ctx, 牌名, u, "反冲伤害 %s（最大 HP 的 15%%）" % J.s(反))
			return ["打出【GN 冲撞·双人格同步】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r9))]
		"目标确认":
			_下张(u, {"命中": 15.0, "暴击": 15.0 if 哈雷加成生效(ctx, u) else 0.0, "目标": 键})
			_记(ctx, 牌名, u, "下一张武器牌对【%s】命中 +15%s" % [_名(敌),
				"、暴击 +15（哈雷路亚）" if 哈雷加成生效(ctx, u) else ""])
			return ["作用于【%s】：下一张武器牌命中 +15%s" % [_名(敌),
				"、暴击 +15" if 哈雷加成生效(ctx, u) else ""]]
		"反射神经":
			_增益(u, "反射神经", {"eva": 40.0 if 哈雷加成生效(ctx, u) else 25.0, "剩余": 1.0})
			if not 加号:
				u["本回合命中罚"] = -10.0
			_记(ctx, 牌名, u, "闪避 +%d；%s" % [40 if 哈雷加成生效(ctx, u) else 25,
				"" if 加号 else "本回合命中 −10"])
			return ["作用于【%s】：闪避 +%d%s" % [_名(u), 40 if 哈雷加成生效(ctx, u) else 25,
				"" if 加号 else "（代价：命中 −10）"]]
		"GN盾阿雷路亚":
			_增益(u, "GN 盾", {"受伤Mul": -0.30, "剩余": 1.0})
			_记(ctx, 牌名, u, "受到的伤害 −30%（到下个我方阶段前；只限阿雷路亚）")
			return ["作用于【%s】：受伤 −30%%（只限阿雷路亚）" % _名(u)]
		"不想再杀人":
			Btl.加战意(u, 10.0, ctx, 牌名)
			_增益(u, "「我不想再杀人了」:代价", {"dmgMulPct": -20.0, "剩余": 1.0})
			_记(ctx, 牌名, u, "战意 +10（现 %s）；本回合武器伤害 −20%%" % J.s(Btl.战意(u)))
			return ["作用于【%s】：战意 +10（本回合武器伤害 −20%%）" % _名(u)]
		"交给阿雷路亚":
			_下张(u, {"伤害乘": 1.30, "目标": 键})
			_增益(u, "「交给我吧，阿雷路亚！」:代价", {"受伤Mul": 0.20, "剩余": 1.0})
			_记(ctx, 牌名, u, "下一张武器牌对【%s】伤害 +30%%；到下个我方阶段前受到的伤害 +20%%" % _名(敌))
			return ["作用于【%s】：下一张武器牌伤害 +30%%（代价：受伤 +20%%）" % _名(敌)]
		"脑量子波":
			var 抽3 := Setup.抽专属牌(u, 1)
			u["本回合不被动切换"] = true
			_记(ctx, 牌名, u, "抽 %d 张精神牌；本回合不会被动切换" % 抽3.size())
			return ["抽 %d 张精神牌；本回合不会被动切换" % 抽3.size()]
		"超兵记忆":
			Btl.加战意(u, 20.0, ctx, 牌名)
			切换人格(ctx, u, "超兵的记忆")
			card["本场已用"] = true
			_记(ctx, 牌名, u, "战意 +20（现 %s）；立刻切换到【%s】（每场 1 次）" % [
				J.s(Btl.战意(u)), 当前人格(u)])
			return ["作用于【%s】：战意 +20、立刻切换到【%s】" % [_名(u), 当前人格(u)]]
		"哈哈哈哈":
			if not 哈雷路亚中(u):
				切换人格(ctx, u, "「哈哈哈哈！」")
			Btl.加战意(u, 10.0, ctx, 牌名)
			_记(ctx, 牌名, u, "→【%s】；战意 +10（现 %s）" % [当前人格(u), J.s(Btl.战意(u))])
			return ["立刻切换到【%s】、战意 +10" % 当前人格(u)]
		"双重思考":
			u["双重思考回合"] = float(ctx.get("turn", 1.0))
			_记(ctx, 牌名, u, "本回合同时拿到两边的好处：「哈雷路亚：」生效 + 能打公有排")
			return ["作用于【%s】：本回合哈雷路亚加强 + 可打公有排" % _名(u)]
		# ---------------------------------- 提耶利亚 CB4 ----------------------------------
		"数据检索":
			_下张(u, {"命中": 10.0})
			var 抽4: Array = []
			if 加号:
				抽4 = Setup.抽专属牌(u, 1)
			_记(ctx, 牌名, u, "下一张武器牌命中 +10%s" % ("；再抽 1 张精神牌" if not 抽4.is_empty() else ""))
			return ["下一张武器牌命中 +10%s（算 Veda 牌）" % ("、抽 1 张精神牌" if not 抽4.is_empty() else "")]
		"弱点解析":
			if 敌 is Dictionary:
				var 破: Array = J.or_((敌 as Dictionary).get("debuffs"), [])
				破 = 破.filter(func(b): return str((b as Dictionary).get("src", "")) != "Veda·弱点解析")
				破.append({"src": "Veda·弱点解析", "pct": 30.0, "剩余": 1.0})
				(敌 as Dictionary)["debuffs"] = 破
			_记(ctx, 牌名, u, "本回合我方对【%s】的攻击无视 30%% 装甲" % _名(敌))
			return ["作用于【%s】：本回合我方攻击无视 30%% 装甲" % _名(敌)]
		"目标捕捉":
			var 乘 := 1.30 if 演算满足(ctx, u) else 1.15
			_下张(u, {"伤害乘": 乘, "目标": 键})
			_记(ctx, 牌名, u, "下一张武器牌对【%s】伤害 +%d%%%s" % [_名(敌), int((乘 - 1.0) * 100.0),
				"（演算满足）" if 乘 > 1.2 else ""])
			return ["作用于【%s】：下一张武器牌伤害 +%d%%%s" % [_名(敌), int((乘 - 1.0) * 100.0),
				"（演算：+30%）" if 乘 > 1.2 else ""]]
		"GN场展开":
			_增益(u, "GN 场展开", {"受伤Mul": -0.40, "剩余": 1.0})
			_增益(u, "GN 场展开:代价", {"dmgMulPct": -10.0 if 加号 else -20.0, "剩余": 1.0})
			_记(ctx, 牌名, u, "受到的伤害 −40%%；本回合武器伤害 −%d%%" % (10 if 加号 else 20))
			return ["作用于【%s】：受伤 −40%%（代价：本回合武器伤害 −%d%%）" % [_名(u), 10 if 加号 else 20]]
		"目标共享":
			if 敌 is Dictionary:
				(敌 as Dictionary)["cb天人命中加"] = 15.0
			_记(ctx, 牌名, u, "本回合天人成员打【%s】命中 +15" % _名(敌))
			return ["作用于【%s】：本回合天人成员打它命中 +15" % _名(敌)]
		"独自判断":
			u["独自判断回合"] = float(ctx.get("turn", 1.0))
			_记(ctx, 牌名, u, "本回合提耶利亚的【演算】视为满足")
			return ["作用于【%s】：本回合【演算】视为满足" % _名(u)]
		"高机动回避":
			_增益(u, "高机动回避", {"eva": 30.0, "剩余": 1.0})
			u["本回合命中罚"] = -10.0
			_记(ctx, 牌名, u, "闪避 +30（到下个我方阶段前）；本回合命中 −10")
			return ["作用于【%s】：闪避 +30（代价：命中 −10）" % _名(u)]
		"我是提耶利亚":
			Btl.加战意(u, 20.0, ctx, 牌名)
			card["本场已用"] = true
			_记(ctx, 牌名, u, "战意 +20（现 %s；每场 1 次，已移出本场）" % J.s(Btl.战意(u)))
			return ["作用于【%s】：战意 +20（每场 1 次）" % _名(u)]
		"Veda权限":
			var 拿 := _拿太阳炉Veda(ctx, 1)
			u["本回合不能打武器牌"] = true
			_记(ctx, 牌名, u, "从太阳炉牌库拿 %d 张 Veda 牌进公有手牌；本回合不能打武器牌" % 拿.size())
			return ["查看太阳炉牌库：拿 %d 张 Veda 牌（%s）" % [拿.size(),
				"、".join(拿) if not 拿.is_empty() else "没有可拿的"]]
		"脱装纳德雷":
			if J.truthy(u.get("本场脱装过")):
				_记(ctx, 牌名, u, "已经脱装过（每场 1 次、不能换回）")
				return ["作用于【%s】：本场已经脱装过" % _名(u)]
			u["本场脱装过"] = true
			u["形态"] = "纳德雷"
			var 停: Array = []
			for e in Units.livingOf("enemy", ctx):
				if not (e is Dictionary) or (e as Dictionary).get("slot") == null:
					continue
				if Fm.rowOfSlot(float((e as Dictionary).slot)) != Fm.ROW_FRONT:
					continue
				if _是头目(e):
					_增益(e, "脱装·纳德雷", {"hit": -30.0, "剩余": 1.0})
					停.append("%s（头目 → 命中 −30）" % _名(e))
				else:
					(e as Dictionary)["脱装不能攻击"] = true
					停.append(_名(e))
			# ★ CR-3 Batch C：换装走武器栏栈 —— 来源 `"脱装"`、**永久层**（本场不能弹回）。
			DeckFlow.压栈武器栏(u, 纳德雷武器表("CB4"), "脱装", true, ctx)
			var 比 := 0.30 if 加号 else 0.50
			u["armor"] = J.round(float(u.get("armor", 0.0)) * (1.0 - 比))
			u["eva"] = float(u.get("eva", 0.0)) + 25.0
			_记(ctx, 牌名, u, "脱装！敌方前排 %d 台下个敌方阶段不能攻击；武器栏换成纳德雷；装甲 −%d%%、闪避 +25"
				% [停.size(), int(比 * 100.0)])
			return ["脱装·纳德雷：%s 下个敌方阶段不能攻击" % ("、".join(停) if not 停.is_empty() else "（没有敌方前排）"),
				"武器栏整套换成纳德雷（装甲 −%d%%、闪避 +25，本场有效）" % int(比 * 100.0)]
		"高压全弹":
			var 参2 := {"武器类型": "direct", "威力": 3600.0, "命中": 100.0, "距离": [2, 6],
				"伤害类型": "光束", "属性": "射击"}
			if transam中(u):
				参2["横扫"] = true
			else:
				参2["area"] = "pierce"
				参2["pierce_mul"] = 1.0
			var 演算中 := 演算满足(ctx, u)
			if 演算中:
				参2["威力"] = 3600.0 * (1.35 if 加号 else 1.20)
			var r10 := _算子攻击(ctx, u, "GN 火箭筒·高压全弹", 参2)
			_记(ctx, 牌名, u, "直射 · 光束 %d · %s%s" % [int(参2["威力"]),
				"横扫（TRANS-AM 中）" if transam中(u) else "贯穿",
				"；演算：伤害 +%d%%" % (35 if 加号 else 20) if 演算中 else "（演算未满足）"])
			return ["打出【GN 火箭筒·高压全弹】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r10)),
				"射程形状 = %s" % ("横扫（TRANS-AM 中）" if transam中(u) else "贯穿")]
		"爆裂模式":
			var 参3 := {"武器类型": "direct", "威力": 6500.0, "命中": 100.0, "距离": [2, 6],
				"伤害类型": "光束", "属性": "射击", "area": "pierce", "pierce_mul": 1.0, "无视遮挡": true}
			var 演算中2 := 演算满足(ctx, u)
			if 演算中2:
				参3["威力"] = 6500.0 * 1.30
			var r11 := _算子攻击(ctx, u, "GN 火箭筒·爆裂模式", 参3)
			if not 加号:
				u["下回合武器全消"] = true
			_记(ctx, 牌名, u, "直射 · 光束 %d · 贯穿 · 无视遮挡%s%s" % [int(参3["威力"]),
				"；演算：伤害 +30%" if 演算中2 else "（演算未满足）",
				"" if 加号 else "；下个我方阶段武器牌全部消掉（过热）"])
			return ["打出【GN 火箭筒·爆裂模式】：%s" % Btl.效果摘要文(Btl.攻击结果摘要(r11)),
				"" if 加号 else "下个我方阶段炮管过热（武器全消）"]
	return null

static func _武器栏卡(u: Dictionary, id: String) -> Dictionary:
	for c in J.or_(u.get("武器栏"), []):
		if c is Dictionary and str((c as Dictionary).get("id", "")) == id:
			return c
	return {}

static func _拿太阳炉Veda(ctx: Dictionary, 张数: int) -> Array:
	var 拿: Array = []
	var 库 = ctx.get("太阳炉牌库")
	var 牌们: Array = SubDeck.牌们(库)
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var 走: Array = []
	for c in 牌们:
		if 拿.size() >= 张数 or 手.size() >= 公有上限 or not (c is Dictionary) \
			or int(J.num0((c as Dictionary).get(炉等级键))) >= 3 or not J.truthy((c as Dictionary).get("veda")):
			走.append(c)
			continue
		手.append(c)
		拿.append(str((c as Dictionary).get("名", "")))
	if 库 is Dictionary:
		(库 as Dictionary)[SubDeck.牌键] = 走
	ctx["公有手牌"] = 手
	return 拿


