## 职责：原生黄金样例的**确定性出牌策略** —— 替玩家把每回合能打的牌按固定顺序打完（不掷任何随机数）。
## 约定：只读判定走 `CardPlay.不可打原因`（界面置灰用的同一个函数）；出牌一律调门面背后的核心函数。
class_name NativeGoldenPolicy
extends RefCounted

## 每个我方阶段最多出这么多张牌（护栏；正常情况打不出牌就停）。
const 每阶段上限 := 30

## 主武器轮换游标：单位键 → 下一回合从武器栏第几张开始看。
## **只活在本对象里** —— 不进 `ctx`、不落存档、不抽随机数；一场一个实例（`NativeGoldenRunner` 每场新建）。
var _主武器轮换 := {}

## 一个我方阶段：按槽位从小到大轮一遍，每台机体按「大招槽 → 副武器 → 衍生 → 精神 → 连携 → 筹码 → 公有 → 主武器」看牌。
## 返回 `{出牌: [{区, 单位, 牌, 牌名}], 选择rng: int, 失败: String}`。
## `选择rng` = **只有选牌判定**（`CardPlay` / `Reach` 那一侧）花掉的随机数步数，必须恒为 0；
## 真正打出牌当然会掷骰（那是内核的攻击结算，不是策略）。`失败` 非空 = 策略选中的牌打不出来（要停下查）。
func 出牌阶段(ctx: Dictionary) -> Dictionary:
	var 外 := {"出牌": [], "选择rng": 0, "失败": ""}
	if ctx == null or ctx.is_empty() or ctx.get("result") != null:
		return 外
	if str(ctx.get("阶段", "")) != Btl.阶段_我方主:
		return 外
	var 次 := 0
	while 次 < 每阶段上限 and ctx.get("result") == null:
		次 += 1
		var 前 := int(ctx.rng.steps)
		var 选 := 找下一张(ctx)
		外["选择rng"] = int(外["选择rng"]) + int(ctx.rng.steps) - 前
		if 选.is_empty():
			break
		var r := 打出(ctx, 选)
		if not bool(r.get("成功", false)):
			外["失败"] = "%s 打不出来（%s）" % [str((选["牌"] as Dictionary).get("名", "")), str(r.get("原因", ""))]
			break
		if str(选["区"]) == CardPlay.区_主武器:
			var 键 := str((选["单位"] as Dictionary).get("key", ""))
			var 张 := (J.or_((选["单位"] as Dictionary).get("武器栏"), []) as Array).size()
			_主武器轮换[键] = (int(选["序号"]) + 1) % 张 if 张 > 0 else 0
		(外["出牌"] as Array).append({"区": str(选["区"]), "单位": str((选["单位"] as Dictionary).get("key", "")),
			"牌": str((选["牌"] as Dictionary).get("id", "")), "牌名": str((选["牌"] as Dictionary).get("名", ""))})
	return 外

## 找这一拍要打的第一张牌（没有 = 空字典）。顺序：机体槽位 → 区 → 牌表序。
func 找下一张(ctx: Dictionary) -> Dictionary:
	for u in 按槽位(ctx.get("allies")):
		if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 选 := _该机体的第一张可打(ctx, u)
		if not 选.is_empty():
			return 选
	return {}

func _该机体的第一张可打(ctx: Dictionary, u: Dictionary) -> Dictionary:
	for 槽 in J.or_(u.get("大招槽"), []):
		if not (槽 is Dictionary) or not ((槽 as Dictionary).get("卡") is Dictionary):
			continue
		var 卡: Dictionary = (槽 as Dictionary).卡
		if CardPlay.不可打原因(ctx, u, 卡, CardPlay.区_大招槽) == "":
			return {"区": CardPlay.区_大招槽, "单位": u, "牌": 卡}
	for e in J.or_(u.get("副武器栏"), []):
		if not (e is Dictionary) or not ((e as Dictionary).get("卡") is Dictionary):
			continue
		var 卡2: Dictionary = (e as Dictionary).卡
		if CardPlay.不可打原因(ctx, u, 卡2, CardPlay.区_副武器) == "":
			return {"区": CardPlay.区_副武器, "单位": u, "牌": 卡2}
	for 卡3 in _衍生卡们(ctx, u):
		if CardPlay.不可打原因(ctx, u, 卡3, CardPlay.区_衍生) == "":
			return {"区": CardPlay.区_衍生, "单位": u, "牌": 卡3}
	for 卡4 in J.or_(u.get("专属手牌"), []):
		if not (卡4 is Dictionary) or Btl.是衍生攻击卡(卡4):
			continue
		if CardPlay.不可打原因(ctx, u, 卡4, CardPlay.区_精神) == "":
			return {"区": CardPlay.区_精神, "单位": u, "牌": 卡4}
	for 卡5 in _公有手牌里的(ctx, "连携"):
		if CardPlay.不可打原因(ctx, u, 卡5, CardPlay.区_连携) == "":
			return {"区": CardPlay.区_连携, "单位": u, "牌": 卡5}
	for 卡6 in _公有手牌里的(ctx, "筹码"):
		if CardPlay.不可打原因(ctx, u, 卡6, CardPlay.区_筹码) == "":
			return {"区": CardPlay.区_筹码, "单位": u, "牌": 卡6}
	for 卡7 in _公有手牌里的(ctx, "普通"):
		if CardPlay.不可打原因(ctx, u, 卡7, CardPlay.区_公有) == "":
			return {"区": CardPlay.区_公有, "单位": u, "牌": 卡7}
	var 武们: Array = J.or_(u.get("武器栏"), [])
	if not 武们.is_empty():
		var 键 := str(u.get("key", ""))
		var 起 := int(_主武器轮换.get(键, 0)) % 武们.size()
		for k in 武们.size():
			var i := (起 + k) % 武们.size()
			var 卡8 = 武们[i]
			if not (卡8 is Dictionary):
				continue
			if CardPlay.不可打原因(ctx, u, 卡8, CardPlay.区_主武器) == "":
				return {"区": CardPlay.区_主武器, "单位": u, "牌": 卡8, "序号": i}
	return {}

func _衍生卡们(ctx: Dictionary, u: Dictionary) -> Array:
	var 出: Array = []
	for c in J.or_(u.get("衍生手牌"), []):
		if c is Dictionary and Btl.是衍生攻击卡(c):
			出.append(c)
	for c in J.or_(ctx.get("公有手牌"), []):
		if c is Dictionary and Btl.是衍生攻击卡(c):
			出.append(c)
	return 出

## 公有手牌按「品类」分桶：`连携` / `筹码` / `普通`（衍生卡不进这三桶，它们走 `_衍生卡们`）。
func _公有手牌里的(ctx: Dictionary, 品类: String) -> Array:
	var 出: Array = []
	for c in J.or_(ctx.get("公有手牌"), []):
		if not (c is Dictionary):
			continue
		if Btl.是衍生攻击卡(c):
			continue
		var 是连携: bool = str((c as Dictionary).get("种类", "")) == "连携"
		var 是筹码: bool = AtxChips.是筹码牌(c)
		if 品类 == "连携" and 是连携:
			出.append(c)
		elif 品类 == "筹码" and 是筹码 and not 是连携:
			出.append(c)
		elif 品类 == "普通" and not 是连携 and not 是筹码:
			出.append(c)
	return 出

static func 按槽位(们: Variant) -> Array:
	var arr: Array = []
	for u in (们 if 们 is Array else []):
		if u is Dictionary:
			arr.append(u)
	arr.sort_custom(func(a, b): return float((a as Dictionary).get("slot", 0.0)) < float((b as Dictionary).get("slot", 0.0)))
	return arr

## 目标：`CardPlay.目标方` 那一侧、按槽位从小到大第一个合法目标（无目标 = null）。
static func 挑目标(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> Variant:
	var 方 := CardPlay.目标方(卡, 区)
	if 方 == CardPlay.目标方_无:
		return null
	var 池 := 按槽位(Units.livingOf("enemy" if 方 == CardPlay.目标方_敌方 else "ally", ctx))
	var w: Variant = 卡.get("武器")
	for t in 池:
		if not (t is Dictionary) or (t as Dictionary).is_empty():
			continue
		if 方 != CardPlay.目标方_敌方 or not (w is Dictionary) or (w as Dictionary).is_empty():
			return (t as Dictionary).get("key")
		if J.truthy(Reach.武器可达吗(ctx, u, w, t).get("ok")):
			return (t as Dictionary).get("key")
	return null

## 真正出牌：调 `session/battle_deck_view.gd` 那五个门面背后的核心函数（不另写结算）。
static func 打出(ctx: Dictionary, 选: Dictionary) -> Dictionary:
	var u: Dictionary = 选["单位"]
	var 卡: Dictionary = 选["牌"]
	var 区 := str(选["区"])
	var 目标 = 挑目标(ctx, u, 卡, 区)
	var 键 := str(u.get("key", ""))
	match 区:
		CardPlay.区_大招槽:
			return DeckFlow.打出大招(ctx, 键, str(卡.get("id", "")), 目标)
		CardPlay.区_副武器:
			return DeckFlow.打出副武器(ctx, 键, str(卡.get("id", "")), 目标)
		CardPlay.区_衍生:
			return Btl.打出衍生攻击卡(ctx, 键, 卡, 目标)
		CardPlay.区_精神, CardPlay.区_公有:
			return Btl.打出精神或公有牌(ctx, 键, 卡, 目标)
		CardPlay.区_连携:
			return DeckFlow.打出连携牌(ctx, 键, str(卡.get("id", "")), 目标)
		CardPlay.区_筹码:
			return AtxChips.打出筹码牌(ctx, 键, str(卡.get("id", "")), 目标)
		CardPlay.区_主武器:
			# 门面 `_打主武器卡` 传的就是 `手牌键`（= 卡 id）；**不能传字典** ——
			# `BattleWeaponExec._找武器栏卡` 的「字典按引用比」分支在循环里直接 return，只认第一张（见回执「发现」）。
			return Btl.打出武器栏卡(ctx, 键, str(卡.get("id", "")), 目标)
	return {"成功": false, "原因": "策略不认识这个区（%s）" % 区}
