## 职责：殖民卫星军的**唯一注册点** —— 成员识别、入口（装填 / 公有牌）与全部规则钩子的转发（觉醒在 `ColonialAwaken`、牌库在 `ColonialDeck`）。
## 约定：内核只经 `RuleHooks` 找本文件；本文件不写规则细节，只判「归不归我管」再转出去。
class_name ColonialV01
extends RefCounted

const 势力 := "殖民卫星军"
const 成员键: Array = ["S1", "S2", "W1", "W2", "W3", "W4", "W5"]
const 处理者名 := "ColonialV01"
const 入场ID前缀 := "COL_"

# ---- 零、卡表（入场牌；五人的卡池在 `ColonialUnits`）----
static func 卡包() -> Dictionary:
	return ColonialDeck.卡包()

static var _入场表: Array = []
static var _入场代: int = -1

## 3 张觉醒入场牌（SEED / ZERO / 隐身），按 `觉醒` / `角色` 装进对应成员的大招槽。
static func 入场牌们() -> Array:
	if _入场代 != Db.代:
		var 表: Array = []
		var 条们 = 卡包().get("入场牌")
		for 条目 in (条们 as Array) if 条们 is Array else []:
			if not (条目 is Dictionary):
				continue
			var 牌 := {
				"id": str(条目.get("id", "")), "名": str(条目.get("名", "")),
				"卡类": "大招槽卡", "类型": "战术", "层级": "角色", "种类": "觉醒",
				"归属": 势力, "角色": str(条目.get("角色", "")), "角色们": [], "占行动": [],
				"耗气": float(J.or_(条目.get("耗气"), 10.0)), "回气": 0.0, "限次": 99.0, "冷却": 0.0,
				"回库": false, "衍生": false, "入库条件": null,
				"获取": str(J.or_(条目.get("获取"), "初始")), "等级需求": 10,
				"效果说明": str(条目.get("效果说明", "")), "效果": [],
				"武器牌": false, "觉醒": str(条目.get("觉醒", "")),
				"入场门": (条目.get("入场门") as Dictionary) if 条目.get("入场门") is Dictionary else {},
				"角色所属势力": 势力,
			}
			表.append(牌)
		_入场表 = 表
		_入场代 = Db.代
	return _入场表

## 按成员键拿那一张入场牌（没有 = 空）。
static func 入场牌(键: String) -> Dictionary:
	for c in 入场牌们():
		if str((c as Dictionary).get("角色", "")) == 键:
			return c
	return {}

## 大招槽条目（与 `DeckFlow` / `MithrilV03Cards._槽` 同一形状）。
static func _槽(卡: Dictionary) -> Dictionary:
	return {
		"卡": 卡, "cd": 0.0, "cd_max": float(J.or_(卡.get("冷却"), 0.0)),
		"is_weapon": J.truthy(卡.get("武器牌")), "已解锁": true, "解锁说明": "",
		"实时门槛满足": true, "门槛说明": "", "本回合已打": false, "已移出": false,
		"处理者": 处理者名,
	}

# ---- 一、开关与成员识别（纯读）----
static func 开(ctx: Variant) -> bool:
	return 有成员(ctx)

static func 有成员(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if u is Dictionary and float((u as Dictionary).get("hp", 0.0)) > 0.0 and 是殖民卫星军(u):
			return true
	return false

static func 是殖民卫星军(u: Variant) -> bool:
	return ColonialAwaken.是殖民卫星军(u)

static func 键(u: Variant) -> String:
	return ColonialAwaken.键(u)

static func 觉醒类型Of(u: Variant) -> String:
	return str(ColonialUnits.觉醒.get(键(u), ""))

# ---- 二、入口：装填（`Setup.初始化单机牌组` 经 `RuleHooks` 调的四个口子）----
## 【开局初始化】：全队一份的感应牌库 + `本场有人觉醒过`。
static func 开局初始化(ctx: Dictionary) -> void:
	if not 有成员(ctx):
		return
	ColonialDeck.初始化(ctx)

## 五名成员的专属牌（主武器 / 副武器 / 大招 / 精神牌）—— 卡池在 `ColonialUnits`。
static func 装填单位(u: Variant, 等级: int, ctx: Variant) -> Array:
	if not 开(ctx) or not (u is Dictionary) or not 是殖民卫星军(u):
		return []
	return ColonialUnits.装填单位(u, 等级, ctx)

## 给三名有觉醒的成员各装一张觉醒入场牌（大招槽卡，绝不进抽牌堆）。
static func 装填大招槽(ctx: Dictionary, u: Variant) -> void:
	if not 开(ctx) or not (u is Dictionary) or not 是殖民卫星军(u):
		return
	var 卡 := 入场牌(键(u))
	if 卡.is_empty():
		return
	if not (u.get("大招槽") is Array):
		u["大招槽"] = []
	for 槽 in u.大招槽:
		if 槽 is Dictionary and str(((槽.get("卡") if 槽.get("卡") is Dictionary else {}) as Dictionary).get("id", "")) == str(卡.get("id", "")):
			return
	u.大招槽.append(_槽(卡))

## 9 张势力牌（公有排）—— 队里没有殖民卫星军成员时一张都不装。
static func 公有扩展牌(ctx: Variant) -> Array:
	return ColonialDeck.公有扩展牌(ctx)

## 公有牌打出：感应牌 / 势力牌归本模块（`{终局:false}` = 不归我管）。
static func 公有牌打出(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (卡 is Dictionary):
		return {"终局": false}
	return ColonialDeck.打出(ctx, u, 卡, target_id)

## 算子（`CardEffects` 的 `"colonial"` 分支转进来）：先问感应 / 势力牌，再问五人的牌。
static func 执行算子(名: String, 运行: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	var 回 := ColonialDeck.执行算子(名, 运行, 表, 目标们)
	if not 回.is_empty():
		return 回
	return ColonialUnits.执行算子(名, 运行, 表, 目标们)

# ---- 三、大招槽：按处理者分派（入场牌 + 觉醒大招）----
static func 认领大招槽(ctx: Dictionary, u: Variant, 槽: Dictionary) -> String:
	if not 开(ctx) or not (u is Dictionary) or not (槽 is Dictionary):
		return ""
	if not 是殖民卫星军(u):
		return ""
	var 卡 = (槽 as Dictionary).get("卡")
	if not (卡 is Dictionary) or str((卡 as Dictionary).get("卡类", "")) != "大招槽卡":
		return ""
	return 处理者名

## 这一张现在为什么打不出来（空串 = 能打）。
static func _不可打原因(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> String:
	var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
	if J.truthy(槽.get("已移出", false)):
		return "这一张已经用过了"
	if str(卡.get("觉醒", "")) != "":
		return ColonialAwaken.入场门原因(ctx, u, 卡)
	if not ColonialAwaken.觉醒中(u):
		return "要先进觉醒中才打得出来"
	var 需 := str(卡.get("需要觉醒", ""))
	if 需 != "" and ColonialAwaken.类型Of(u) != 需:
		return "要【觉醒中·%s】才打得出来" % 需
	var 条 = DeckFlow.入库条件Of(卡)
	if 条 is Dictionary and not DeckFlow.条件满足(ctx, u, 条):
		return "亮起条件未满足：%s" % str((条 as Dictionary).get("说明", ""))
	var 费 := 大招费用(u, 卡)
	if Btl.战意(u) < 费:
		return "战意不够（要 %d，现在 %d）" % [int(费), int(Btl.战意(u))]
	if J.truthy(u.get("主武器已销毁")) and J.truthy(卡.get("武器牌")):
		return "本回合主武器已销毁（武器型大招一起灰）"
	return ""

## 规则钩子【大招不可打原因】：本模块的槽由自己判（还要处理【强制觉醒】/【极限超频】的豁免）。
static func 大招不可打原因(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> Dictionary:
	var 因 := _不可打原因(ctx, u, 槽)
	return {"终局": true, "原因": 因}

## 规则钩子【大招阶段初】：冷却 −1、清 `本回合已打`、刷新亮起（返回 true = 通用逻辑别再动它）。
static func 大招阶段初(ctx: Dictionary, u: Dictionary, 槽: Dictionary) -> bool:
	if not 是殖民卫星军(u) or not (槽.get("卡") is Dictionary):
		return false
	if float(槽.get("cd", 0.0)) > 0.0:
		槽["cd"] = maxf(0.0, float(槽["cd"]) - 1.0)
	槽["本回合已打"] = false
	var 因 := _不可打原因(ctx, u, 槽)
	槽["实时门槛满足"] = 因 == ""
	槽["门槛说明"] = 因
	槽["已解锁"] = true
	槽["解锁说明"] = ""
	return true

## 规则钩子【打出大招】：入场牌开觉醒 / 武器大招走 QTE 与攻击 / 其余走效果算子。
static func 打出大招(ctx: Dictionary, u: Dictionary, 槽: Dictionary, target_id: Variant) -> Dictionary:
	var 卡: Dictionary = 槽.get("卡") if 槽.get("卡") is Dictionary else {}
	var 费 := 大招费用(u, 卡)
	u["战意"] = maxf(0.0, Btl.战意(u) - 费)
	槽["本回合已打"] = true
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	ctx["_当前牌"] = 卡
	RuleHooks.广播("大招打出前", [ctx, u, 卡, 槽, target_id])
	ColonialDeck.触发觉醒感应(ctx, u, 卡)
	var 摘要: Array = []
	var 结果: Dictionary = {"击破": 0.0}
	if str(卡.get("觉醒", "")) != "":
		摘要 = _打入场牌(ctx, u, 槽, 卡)
	elif 卡.get("武器") is Dictionary and not (卡.get("武器") as Dictionary).is_empty():
		结果 = _打觉醒大招(ctx, u, 卡, target_id)
		摘要 = Btl.攻击结果摘要(结果)
	else:
		摘要 = CardEffects.execute(ctx, 卡)
	RuleHooks.广播("大招打出后", [ctx, u, 卡, 槽])
	槽["cd"] = maxf(float(槽.get("cd_max", 0.0)), 0.0)
	if J.truthy(卡.get("武器牌")) and not Btl._不销毁主武器(卡):
		u["主武器已销毁"] = true
		RuleHooks.广播("大招结算后", [ctx, u, 卡])
		if ColonialAwaken.是隐身中(u):
			ColonialAwaken.结束(ctx, u, "打出武器牌破隐")
	ColonialUnits.大招收尾(ctx, u, 卡, 卡.get("武器"))
	if str(卡.get("id", "")) == "COL_W2_ULT_AMBUSH":
		u["本场打过破隐一击"] = true
	u["本场已打大招"] = true
	RuleHooks.广播("大招收尾后", [ctx, u, 卡])
	Btl.pushLog(ctx, "〔觉醒大招〕%s 打出【%s】（战意 -%s，剩 %s；冷却 %d%s）%s" % [
		str(u.get("name", "")), str(卡.get("名", "")), J.s(费), J.s(J.num0(u.get("战意"))), int(槽.get("cd", 0.0)),
		"；主武器本回合销毁" if J.truthy(卡.get("武器牌")) else "；不算武器牌", Btl.效果摘要文(摘要)],
		J.merged({"类型": "觉醒大招", "单位": u.key, "卡牌ID": 卡.get("id"), "卡牌": 卡.get("名"),
			"战意": u.get("战意"), "cd": 槽.get("cd"), "效果摘要": 摘要}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(卡.get("名", "")), "战意": J.num0(u.get("战意")),
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")), "效果摘要": 摘要,
		"主武器已销毁": J.truthy(u.get("主武器已销毁")), "cd": float(槽.get("cd", 0.0))}

static func _打入场牌(ctx: Dictionary, u: Dictionary, 槽: Dictionary, 卡: Dictionary) -> Array:
	var 类型 := str(卡.get("觉醒", ""))
	ColonialAwaken.开启(ctx, u, 类型, str(卡.get("名", "")))
	if 类型 == ColonialAwaken.SEED:
		槽["已移出"] = true
	return ["进入【觉醒中·%s】" % 类型]

static func _打觉醒大招(ctx: Dictionary, u: Dictionary, 卡: Dictionary, target_id: Variant) -> Dictionary:
	var w0 = 卡.get("武器")
	if not (w0 is Dictionary) or (w0 as Dictionary).is_empty():
		var 摘要 := CardEffects.execute(ctx, 卡)
		return {"击破": 0.0, "效果摘要": 摘要}
	var QTE := ColonialAwaken.取QTE结果(ctx, u, 卡, str(ctx.get("QTE指定", "")))
	ColonialAwaken.开QTE(ctx, u, QTE)
	var w: Dictionary = (w0 as Dictionary).duplicate(true)
	# ZERO 的 QTE 完美 → 这一发每段必暴（必中武器要额外允许暴击）
	if QTE == "perfect" and ColonialAwaken.是ZERO中(u):
		w["critMod"] = 100.0
		if J.truthy(w.get("必中")):
			w["必中可暴击"] = true
	if J.truthy(卡.get("必中")):
		w["必中"] = true
	if J.truthy(卡.get("必暴")):
		w["critMod"] = 100.0
		w["必中可暴击"] = true
	ColonialUnits.本发标记(ctx, w)
	var 结果 := Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, target_id)
	ColonialAwaken.清QTE(ctx)
	ctx.erase("_本发敌闪避减半")
	return 结果

# ---- 四、规则钩子（数值 / 阶段 / 出牌门槛 / 目标筛选）----
static func 闪避加成(def: Variant, ctx: Variant) -> float:
	return ColonialAwaken.闪避加成(def, ctx) + ColonialUnits.闪避加成(def, ctx)

static func 命中修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	return ColonialAwaken.命中修正(att, def, w, ctx) + ColonialUnits.命中修正(att, def, w, ctx)

static func 暴击修正(att: Variant, def: Variant, w: Variant, ctx: Variant) -> float:
	return ColonialAwaken.暴击修正(att, def, w, ctx) + ColonialUnits.暴击修正(att, def, w, ctx)

static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	return ColonialAwaken.攻方伤害倍率(ctx, att, def, w) * ColonialUnits.攻方伤害倍率(ctx, att, def, w)

static func 受方伤害倍率(ctx: Variant, att: Variant, def: Variant, w: Variant) -> float:
	return ColonialAwaken.受方伤害倍率(ctx, att, def, w) * ColonialUnits.受方伤害倍率(def, w)

static func 受击前(ctx: Dictionary, att: Variant, def: Variant) -> void:
	ColonialAwaken.受击前(ctx, att, def)

static func 受击后(ctx: Dictionary, def: Variant, att: Variant, rec: Variant, w: Variant) -> void:
	if not (def is Dictionary):
		return
	var 伤 := 0.0
	if rec is Dictionary and (rec as Dictionary).get("字段") is Dictionary:
		伤 = float(J.num0(((rec as Dictionary).get("字段") as Dictionary).get("伤害")))
	ColonialUnits.受击后(ctx, def, att, 伤, w)
	ColonialDeck.受击后转伤(ctx, def, 伤)
	ColonialAwaken.检查系统拒绝(ctx, def)

static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, w: Variant) -> void:
	ColonialAwaken.武器攻击后(ctx, att, def, landed, w)
	ColonialUnits.武器攻击后(ctx, att, def, landed, w)

static func 我方阶段初_后(ctx: Variant) -> void:
	if not (ctx is Dictionary) or not 有成员(ctx):
		return
	ColonialAwaken.阶段初(ctx, false)
	ColonialUnits.阶段初(ctx)

## 【我方阶段末】：METEOR 锁定链「回合结束还没发射就自动发射」。
static func 我方阶段末(ctx: Variant) -> void:
	if not (ctx is Dictionary) or not 有成员(ctx):
		return
	ColonialUnits.阶段末(ctx)

## 【区规则门槛】/【副武器门槛】：主武器与副武器的额外条件（依赖未冷却 / 本回合不能打武器）。
static func 区规则门槛(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> Dictionary:
	if 区 != CardPlay.区_主武器:
		return {"终局": false}
	if not ColonialDeck.是殖民卫星军牌(卡) and str(卡.get("角色所属势力", "")) != 势力:
		return {"终局": false}
	var 因 := ColonialUnits.武器门槛(ctx, u, 卡)
	return {"终局": 因 != "", "接手": 因 != "", "原因": 因}

static func 副武器门槛(ctx: Dictionary, u: Dictionary, 条目: Dictionary) -> Dictionary:
	var 卡: Dictionary = 条目.get("卡") if 条目.get("卡") is Dictionary else {}
	if str(卡.get("角色所属势力", "")) != 势力:
		return {"终局": false}
	var 因 := ColonialUnits.武器门槛(ctx, u, 卡)
	return {"终局": 因 != "", "原因": 因}

## 觉醒大招的实际费用（入场牌另走 `ColonialAwaken.实际费用`）。
static func 大招费用(u: Dictionary, 卡: Dictionary) -> float:
	if str(卡.get("觉醒", "")) != "":
		return ColonialAwaken.实际费用(u, 卡)
	return ColonialUnits.大招费用(u, 卡)

## 【牌打出后】：两条规则都挂在这里 —— 【觉醒感应】与「打出武器牌即破隐」。
static func 牌打出后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> void:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (卡 is Dictionary):
		return
	ColonialDeck.触发觉醒感应(ctx, u, 卡)
	ColonialUnits.牌打出后(ctx, u, 卡, 区)
	if J.truthy(卡.get("每场一次")) and 区 == CardPlay.区_精神:
		卡["已用"] = true
	if ColonialAwaken.是隐身中(u) and [CardPlay.区_主武器, CardPlay.区_副武器, CardPlay.区_大招槽].has(区):
		if J.truthy(卡.get("武器牌")) or 区 != CardPlay.区_大招槽:
			ColonialAwaken.结束(ctx, u, "打出武器牌破隐")

## 【卡不可打原因】：势力牌只有殖民卫星军成员能打；「正规军掩护」还有两条自带的门槛。
static func 卡不可打原因(_ctx: Dictionary, u: Dictionary, 卡: Dictionary, _区: String) -> Dictionary:
	if not ColonialDeck.是殖民卫星军牌(卡):
		return {"终局": false}
	if not 是殖民卫星军(u):
		return {"终局": true, "原因": "只有殖民卫星军成员能打这张牌"}
	if J.truthy(卡.get("已用")):
		return {"终局": true, "原因": "这一张每场只能用一次"}
	var id := str(卡.get("id", ""))
	if id == "COL_FAC_4":
		if ColonialAwaken.觉醒中(u):
			return {"终局": true, "原因": "正规军掩护只能由没在觉醒中的成员打出"}
		var 有 := false
		for a in J.or_(_ctx.get("allies"), []):
			if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and ColonialAwaken.觉醒中(a):
				有 = true
		if not 有:
			return {"终局": true, "原因": "场上没有在觉醒中的成员可以掩护"}
	if id == "COL_FAC_5" or id == "COL_SD1_EMPATHY" or id == "COL_SD2_CHAIN":
		var 有2 := false
		for a in J.or_(_ctx.get("allies"), []):
			if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and 是殖民卫星军(a) and not ColonialAwaken.觉醒中(a):
				有2 = true
		if not 有2:
			return {"终局": true, "原因": "场上没有没在觉醒中的成员"}
	return {"终局": false}

## 【条件值】：殖民卫星军专属的入库 / 亮起条件。
static func 条件值(ctx: Variant, _u: Variant, t: String, 条: Variant) -> Dictionary:
	if not (ctx is Dictionary):
		return {"终局": false}
	match t:
		"本场有人觉醒过":
			return {"终局": true, "值": J.truthy((ctx as Dictionary).get("本场有人觉醒过"))}
		"本场开过":
			var 觉 := str((条 as Dictionary).get("觉醒", "")) if 条 is Dictionary else ""
			return {"终局": true, "值": _u is Dictionary and J.truthy((_u as Dictionary).get("本场已开" + 觉))}
		"觉醒中":
			var 觉2 := str((条 as Dictionary).get("觉醒", "")) if 条 is Dictionary else ""
			return {"终局": true, "值": ColonialAwaken.是类型(_u, 觉2)}
		"打出过破隐一击":
			return {"终局": true, "值": _u is Dictionary and J.truthy((_u as Dictionary).get("本场打过破隐一击"))}
		"有人血低于":
			var 阈 := float(J.num0((条 as Dictionary).get("阈值"))) if 条 is Dictionary else 0.0
			for a in J.or_((ctx as Dictionary).get("allies"), []):
				if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and 是殖民卫星军(a) \
					and ColonialAwaken.血比(a) <= 阈 / 100.0:
					return {"终局": true, "值": true}
			return {"终局": true, "值": false}
		"有大招冷却中":
			for a in J.or_((ctx as Dictionary).get("allies"), []):
				if a is Dictionary and 是殖民卫星军(a):
					for 槽 in J.or_((a as Dictionary).get("大招槽"), []):
						if 槽 is Dictionary and float((槽 as Dictionary).get("cd", 0.0)) > 0.0:
							return {"终局": true, "值": true}
			return {"终局": true, "值": false}
	return {"终局": false}

## 【可选目标】：隐身中的迪奥在还有其他非隐身队友时不可被敌方单体选中。
static func 可选目标(ctx: Dictionary, actor: Variant, target: Variant, w: Variant) -> Dictionary:
	return ColonialAwaken.可选目标(ctx, actor, target, w)

## 【AI 自动出牌跳过】：结束回合时不许替隐身中的迪奥补打主武器。
static func AI自动出牌跳过(ctx: Dictionary, u: Variant) -> Dictionary:
	return ColonialAwaken.AI自动出牌跳过(ctx, u)

## 【致命保留_后】：势力牌【不杀】—— 会把目标打死的那一下改为保留 1 HP。
static func 致命保留_后(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (att is Dictionary) or not (def is Dictionary):
		return
	# 麦斯威尔教会的十字架（每场一次）
	ColonialUnits.致命保留_后(ctx, att, def)
	if float((def as Dictionary).get("hp", 0.0)) > 0.0:
		return
	if not 是殖民卫星军(att) or not J.truthy((att as Dictionary).get("本回合不杀")):
		return
	if float((def as Dictionary).get("hp", 0.0)) > 0.0:
		return
	(def as Dictionary)["hp"] = 1.0
	(def as Dictionary)["下阶段不能攻击"] = true
	(att as Dictionary).erase("本回合不杀")
	Btl.pushLog(ctx, "〔不杀〕%s 留手：%s 保留 1 HP，下个敌方阶段不能攻击" % [str((att as Dictionary).get("name", "")),
		str((def as Dictionary).get("name", ""))],
		J.merged({"类型": "不杀", "保留": 1.0}, Btl.谁目标(def)))

# ---- 五、表现层读接口 ----
static func 状态行(u: Variant) -> Array:
	return ColonialAwaken.状态行(u)

static func 徽章文字(u: Variant) -> String:
	return ColonialAwaken.徽章文字(u)

## 机体卡上的紧凑标签：〔觉醒中·SEED〕/〔锁定×N〕/〔破隐一击已打〕/〔强制觉醒〕。
static func 标签行(u: Variant, _ctx: Variant = null) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 徽 := ColonialAwaken.徽章文字(u)
	if 徽 != "":
		出.append(徽)
	var 锁: Array = J.or_((u as Dictionary).get("METEOR锁定"), [])
	if not 锁.is_empty():
		出.append("〔锁定×%d〕" % 锁.size())
	if J.truthy((u as Dictionary).get("本场打过破隐一击")):
		出.append("〔破隐一击已打〕")
	if J.truthy((u as Dictionary).get("本回合强制觉醒")):
		出.append("〔强制觉醒〕")
	return 出

## 未觉醒成员手里那张带【觉醒感应】的牌要不要亮金边（表现层读它）。
static func 该亮金边(u: Variant, 卡: Variant) -> bool:
	if not (卡 is Dictionary) or not J.truthy((卡 as Dictionary).get("觉醒感应")):
		return false
	return ColonialAwaken.是殖民卫星军(u) and not ColonialAwaken.觉醒中(u)

## 这一发大招要不要玩家自己选一档 QTE（= 武器型觉醒大招：有武器、算武器牌、不是入场牌）。
static func 走QTE(卡: Variant) -> bool:
	if not (卡 is Dictionary):
		return false
	var d: Dictionary = 卡
	if not J.truthy(d.get("武器牌")) or str(d.get("觉醒", "")) != "":
		return false
	if not (d.get("武器") is Dictionary) or (d.get("武器") as Dictionary).is_empty():
		return false
	return str(d.get("角色所属势力", "")) == 势力 or str(d.get("归属", "")) == 势力

## 现在**真正**在觉醒中的类型（没觉醒 = 空串）—— 表现层按它给徽章配色。
static func 当前觉醒类型(u: Variant) -> String:
	return ColonialAwaken.类型Of(u)
