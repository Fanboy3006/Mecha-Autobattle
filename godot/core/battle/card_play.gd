## 职责：出牌判定（唯一真源）—— 能不能打 / 打谁 / 由谁打。**纯读**。
## 约定：势力 / 职业模块的门槛一律经 `RuleHooks` 顺序表派发，本文件不点名任何模块。
class_name CardPlay
extends RefCounted

# ---- 一、区 ----
const 区_主武器 := "主武器卡"
const 区_副武器 := "副武器卡"
const 区_大招槽 := "大招槽卡"
const 区_精神 := "专属精神牌"
const 区_公有 := "公有牌"
const 区_连携 := "连携牌"
const 区_筹码 := "筹码牌"
const 区_衍生 := "衍生攻击卡"

# ---- 二、不可打原因 ----
## 空串 = 能打；否则是给玩家看的理由。
static func 不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> String:
	if not (ctx is Dictionary):
		return "现在不在战斗里"
	if not (u is Dictionary) or (u as Dictionary).is_empty():
		return "找不到这台我方机体"
	if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
		return "这台机体已经阵亡"
	if not (card is Dictionary) or (card as Dictionary).is_empty():
		return "没有这张牌"
	var 因 := _区门槛(ctx, u, card, 区)
	if 因 != "":
		return 因
	return _无合法目标原因(ctx, u, card, 区)

static func _区门槛(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> String:
	var 区因 := _通用门槛(ctx, u, card, 区)
	if 区因 != "":
		return 区因
	var 从公有 := 区 == 区_公有
	if 从公有 or 区 == 区_精神:
		var 模 := RuleHooks.首个结论("卡不可打原因", [ctx, u, card, 区])
		if bool((模 as Dictionary).get("终局", false)):
			return str((模 as Dictionary).get("原因", ""))
	var 类 := _卡类转交(ctx, u, card)
	if bool((类 as Dictionary).get("接手", false)):
		return str((类 as Dictionary).get("原因", ""))
	return _收尾(ctx, u, card, 区, 从公有)

## 这张牌打谁（表现层拖拽 / 点击的唯一判据）。
static func 目标方(card: Dictionary, 区: String = "", 是修理: bool = false) -> String:
	if not (card is Dictionary) or (card as Dictionary).is_empty():
		return 目标方_敌方
	var 目 := str((card as Dictionary).get("目标", ""))
	if 是修理 or _武器是修理((card as Dictionary).get("武器")) or str((card as Dictionary).get("种类", "")) == "应急补丁":
		return 目标方_友方
	if 要指定友军(目):
		return 目标方_友方
	if 目标_免指派集.has(目):
		return 目标方_无
	match 区:
		区_主武器, 区_副武器, 区_衍生:
			return 目标方_敌方
		区_大招槽:
			if _有武器(card):
				return 目标方_敌方
			if 目.is_empty() or 目标_免指派集.has(目):
				return 目标方_无
			return 目标方_敌方
		区_连携:
			return 目标方_敌方 if _有武器(card) else 目标方_无
		区_筹码:
			if 目.is_empty():
				return 目标方_无
			return 目标方_敌方 if 目 == "敌机" else 目标方_友方
	if 目 == "敌机" or 目 == "自动" or 目 == "最高血" or 目 == "最低血" \
		or 目 == "前排优先" or 目 == "一排":
		return 目标方_敌方
	if 目.is_empty():
		return 目标方_无
	return 目标方_敌方

## 要不要指定一名友军。
static func 是要指定友军(card: Dictionary, 区: String = "") -> bool:
	return 目标方(card, 区) == 目标方_友方

## 由谁来打；`{}` = 全队都打不了。
static func 找执行机体(ctx: Dictionary, card: Dictionary, 区: String, 首选: Dictionary = {}) -> Dictionary:
	if not (ctx is Dictionary) or not (card is Dictionary) or (card as Dictionary).is_empty():
		return {}
	if 首选 is Dictionary and not (首选 as Dictionary).is_empty():
		if 不可打原因(ctx, 首选, card, 区) == "":
			return 首选
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if not (u is Dictionary):
			continue
		if 首选 is Dictionary and not (首选 as Dictionary).is_empty() and is_same(u, 首选):
			continue
		if 不可打原因(ctx, u, card, 区) == "":
			return u
	return {}

# ---- 三、目标方口径 ----
const 目标方_友方 := "友方"
const 目标方_敌方 := "敌方"
const 目标方_无 := "无"

## 要指定友军的目标值（白名单）。
const 目标_友方集 := ["友军", "秘银成员", "ATX成员", "天人成员", "殖民卫星军成员",
	"月球王国成员", "影世界成员", "U7", "U6"]
## 免指派的目标值。
const 目标_免指派集 := ["自身", "全队", "敌方全体", "冷却中的秘银大招"]

## 白名单 + `…成员` / `…队员` / 「友…」/ 我方 / 己方都算友军（新势力不必再补常量表）。
static func 要指定友军(目: String) -> bool:
	if 目.is_empty():
		return false
	if 目标_友方集.has(目):
		return true
	if 目.ends_with("成员") or 目.ends_with("队员"):
		return true
	if 目.begins_with("友"):
		return true
	return 目 == "我方" or 目 == "己方"

# ---- 四、1) 通用门槛（按区） ----
static func _通用门槛(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> String:
	match 区:
		区_主武器:
			return 主武器门槛(ctx, u, card)
		区_副武器:
			return 副武器门槛(ctx, u, card)
		区_大招槽:
			return 大招门槛(ctx, u, card)
		区_连携:
			return _连携门槛(ctx, u, card)
		区_筹码:
			return str(RuleHooks.首个结论("区规则门槛", [ctx, u, card, 区]).get("原因", ""))
		区_衍生:
			return 衍生门槛(ctx, u, card)
	return ""

## 主武器卡：武器栏 → `Btl.武器栏不可打原因`；否则先问模块的 `区规则门槛`。
static func 主武器门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	if _在武器栏(u, card):
		return Btl.武器栏不可打原因(ctx, u, card)
	var 模 := RuleHooks.首个结论("区规则门槛", [ctx, u, card, 区_主武器])
	if bool((模 as Dictionary).get("接手", false)):
		return str((模 as Dictionary).get("原因", ""))
	if J.truthy((u as Dictionary).get("主武器已销毁")):
		return "本回合主武器卡已销毁（下回合初回手）"
	if Btl.是合体技牌(card):
		return _合体技门槛(ctx, u, card)
	if Btl.战意(u) < Btl.战意费用(card):
		return "战意不足"
	return ""

## 合体技：参与者存活 / 都没销毁主武器 / 进入条件 / 各付。
static func _合体技门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	var 参与者: Array = []
	for k in Btl.合体技参与者(card):
		var v = Btl.找单位(ctx, str(k), "ally")
		if not (v is Dictionary) or float((v as Dictionary).get("hp", 0.0)) <= 0.0:
			return "合体技参与者 %s 不在场（要全部存活才打得出来）" % str(k)
		参与者.append(v)
	if 参与者.is_empty():
		参与者 = [u]
	for v in 参与者:
		if J.truthy((v as Dictionary).get("主武器已销毁")):
			return "合体技参与者 %s 本回合主武器卡已销毁（要都没动过才打得出）" % str((v as Dictionary).get("name", ""))
	var 条 := RuleHooks.首个结论("合体技门槛", [ctx, card])
	var 进入 := str((条 as Dictionary).get("进入原因", ""))
	if 进入 != "":
		return 进入
	var 各付 := float((条 as Dictionary).get("各付", 0.0))
	if 各付 > 0.0:
		for v in 参与者:
			if J.num0((v as Dictionary).get("战意")) < 各付:
				return "%s 的战意不足（要各付 %s，现在 %s）" % [
					str((v as Dictionary).get("name", "")), J.s(各付), J.s(J.num0((v as Dictionary).get("战意")))]
		return ""
	if Btl.战意(u) < Btl.战意费用(card):
		return "战意不足"
	return ""

## 副武器卡 → `DeckFlow.副武器不可打原因`。
static func 副武器门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	var 条目 := {}
	for e in J.or_((u as Dictionary).get("副武器栏"), []):
		if e is Dictionary and is_same((e as Dictionary).get("卡"), card):
			条目 = e
			break
	if 条目.is_empty():
		return "副武器栏里没有这张牌"
	return DeckFlow.副武器不可打原因(ctx, u, 条目)

## 大招槽卡 → `DeckFlow.大招不可打原因`。
static func 大招门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	var 槽 := {}
	for s in J.or_((u as Dictionary).get("大招槽"), []):
		if s is Dictionary and is_same((s as Dictionary).get("卡"), card):
			槽 = s
			break
	if 槽.is_empty():
		return "大招槽里没有这张牌"
	return DeckFlow.大招不可打原因(ctx, u, 槽)

## 衍生牌：在衍生手牌 / 公有手牌里 + 战意够。
static func 衍生门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	if not Btl.是衍生攻击卡(card):
		return "这不是衍生攻击卡"
	var 在手 := false
	for c in J.or_((u as Dictionary).get("衍生手牌"), []):
		if is_same(c, card):
			在手 = true
			break
	if not 在手:
		for c in J.or_((ctx as Dictionary).get("公有手牌"), []):
			if is_same(c, card):
				在手 = true
				break
	if not 在手:
		return "手里没有这张衍生攻击卡"
	if Btl.战意(u) < Btl.战意费用(card):
		return "战意不足"
	return ""

## 连携牌：成员归属问 `RuleHooks`。
static func _连携门槛(ctx: Dictionary, u: Dictionary, card: Dictionary) -> String:
	return str(RuleHooks.首个结论("卡不可打原因", [ctx, u, card, 区_连携]).get("原因", ""))

# ---- 五、3) 卡类转交 ----
static func _卡类转交(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Dictionary:
	match str((card as Dictionary).get("卡类", "")):
		区_主武器:
			return {"接手": true, "原因": 主武器门槛(ctx, u, card)}
		区_大招槽:
			return {"接手": true, "原因": 大招门槛(ctx, u, card)}
		区_副武器:
			return {"接手": true, "原因": 副武器门槛(ctx, u, card)}
	if Btl.是衍生攻击卡(card):
		return {"接手": true, "原因": 衍生门槛(ctx, u, card)}
	return {"接手": false, "原因": ""}

## 需要敌机目标的牌：没活敌 / 射程内一台都打不到 → 不可打。
static func _无合法目标原因(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> String:
	if 目标方(card, 区) != 目标方_敌方:
		return ""
	var 活敌: Array = Units.livingOf("enemy", ctx)
	if 活敌.is_empty():
		return "场上没有能打的敌机"
	var w = (card as Dictionary).get("武器")
	if not (w is Dictionary) or (w as Dictionary).is_empty():
		return ""
	for e in 活敌:
		if J.truthy(Reach.武器可达吗(ctx, u, w, e).get("ok")):
			return ""
	return "射程内没有能打的敌机"

# ---- 六、4) 通用收尾 ----
static func _收尾(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String, 从公有: bool) -> String:
	if 从公有 and not Btl.身份对口(u, card, ctx):
		return "这台机体的职业 / 势力与牌面归属不对口"
	if Btl.战意(u) < _实际费(ctx, u, card, 区, 从公有):
		return "战意不足"
	return ""

## 实际战意门槛（纯读预览，不消费任何降费）。
static func _实际费(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String, 从公有: bool) -> float:
	var 费 := Btl.战意费用(card)
	if 区 == 区_公有 or 区 == 区_精神:
		if str((card as Dictionary).get("归属", "")) == "ATX" \
			and str((card as Dictionary).get("层级", "")) == "角色":
			if str((card as Dictionary).get("类型", "")) == "大招":
				费 = RuleHooks.汇总("大招费用预览", [ctx, card])
			else:
				费 = maxf(0.0, 费 - float(int((ctx as Dictionary).get("下张ATX角色牌降费", 0))))
	if 从公有 and str(Units.unit_class(u, ctx)) == "指挥":
		费 = maxf(0.0, 费 - Params.指挥公有减费())
	return 费

# ---- 七、小工具（纯读） ----
static func _在武器栏(u: Dictionary, card: Dictionary) -> bool:
	for c in J.or_((u as Dictionary).get("武器栏"), []):
		if is_same(c, card):
			return true
	return false

static func _有武器(card: Dictionary) -> bool:
	var w = (card as Dictionary).get("武器")
	return w is Dictionary and not (w as Dictionary).is_empty()

static func _武器是修理(w: Variant) -> bool:
	if not (w is Dictionary):
		return false
	return Reach.isHealKind(Reach.rangeKindOf(w))
