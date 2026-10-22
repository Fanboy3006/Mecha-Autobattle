## ★ A3b：ATX「筹码牌库」10 张牌 + 【赌局】触发管线 + 「放入 X」。
##
## 权威依据（数值逐条照抄，一个数都不许改）：
##   · `协作/设计/ATX势力卡牌设计 v0.3.md` §2「筹码牌库」（小筹码 4 / 大筹码 4 / 头奖 2）
##   · 同文件 §1「势力机制【九死一生】」里的 4 条（闪开 / 闪字 / 轮转 / 赌局 · 放入 X · 筹码牌库 · 筹码牌）
##   · `协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md` A3b
##
## 三条设计口径（逐字照设计稿）：
##   ① **筹码牌库全队一份**（`ctx.筹码牌库`，元素是与秘银连携牌库同构的卡 Dictionary）；
##      **开场只有小筹码 4 张**，大筹码与头奖**不入场**，只能被【赌局】「放入」。
##   ② **打出后归库**：等级 1 / 2 → 回 `ctx.筹码牌库`；等级 3（头奖）→ 移出本场，进 `ctx.移出牌`。
##      **公有手牌满 6 张时不抽**（筹码牌留在库里，不浪费）。
##   ③ 卡上三级用 `筹码等级`（int）：1 = 小筹码 / 2 = 大筹码 / 3 = 头奖。
##      全部 `费用 = 0`、`不占武器`（打出后**不置** `主武器已销毁`）、**任何 ATX 成员都能打**、
##      **算 ATX 牌**（`is_atx_card = true`）、**本身不带【赌局】**（防递归）。
##
## 秘银那一侧的同构实现请看 `SubDeck`（A3a 抽出来的通用存取层：抽一张 / 回库或移出 / 放入 / 等级）。
##   **库的存取一律走 `SubDeck`，不要另写一份。**
##
## ★ 三层反馈（缺一层不算做完）：
##   即时 = 一行 `〔赌局〕…` / `〔筹码牌〕…` 记录（抽 + 放合成一行）；
##   预告 = `筹码牌库张数(ctx)` 纯读口（A7 的徽章用，本轮不做界面）；
##   结算 = `赌局触发次数(ctx)` / `赌局放入次数(ctx)` 两个纯读口。
class_name AtxChips
extends RefCounted

const 势力 := "ATX"
## 卡上的字段名（= 筹码牌 schema；库的存取全部交给 `SubDeck`）。
const 等级键 := "筹码等级"
const 回库键 := "回库"
## 公有手牌上限（满手不抽；与 `DeckFlow.公有上限` 同一个数字，但这里不依赖那一层）。
const 手牌上限 := 6

# ---- 10 张牌的 id（小筹码 4 / 大筹码 4 / 头奖 2）----
const 小筹码: Array = ["ATX_CHIP_COIN", "ATX_CHIP_LUCK", "ATX_CHIP_SHOT", "ATX_CHIP_SWAP"]
const 大筹码: Array = ["ATX_CHIP_RESPIN", "ATX_CHIP_GODDESS", "ATX_CHIP_ESCAPE", "ATX_CHIP_DEALER"]
const 头奖: Array = ["ATX_CHIP_SHOWHAND", "ATX_CHIP_SLAM"]
const 全部ID: Array = ["ATX_CHIP_COIN", "ATX_CHIP_LUCK", "ATX_CHIP_SHOT", "ATX_CHIP_SWAP",
	"ATX_CHIP_RESPIN", "ATX_CHIP_GODDESS", "ATX_CHIP_ESCAPE", "ATX_CHIP_DEALER",
	"ATX_CHIP_SHOWHAND", "ATX_CHIP_SLAM"]

const _整数路径们 := ["张数", "段数", "筹码等级"]

static var _表: Array = []
static var _表代: int = -1

# ==========================================================================================
# 一、读表（从 `data/cards/ATX.json` 读入）
# ==========================================================================================
static func _还原值(v: Variant, 路径: String) -> Variant:
	if v is Dictionary:
		var 出 := {}
		for k in (v as Dictionary).keys():
			var 子路径 := str(k) if 路径 == "" else "%s.%s" % [路径, str(k)]
			出[k] = _还原值(v[k], 子路径)
		return 出
	if v is Array:
		var 组: Array = []
		var 子路径 := "%s[]" % 路径
		for x in (v as Array):
			组.append(_还原值(x, 子路径))
		return 组
	if typeof(v) == TYPE_FLOAT and 路径 in _整数路径们:
		return int(v)
	return v

static func _读表() -> Array:
	var 表: Array = []
	var 包: Dictionary = Db.T.get("卡包", {}).get(势力, {})
	for 条 in 包.get("筹码", []):
		if 条 is Dictionary:
			表.append(_还原值(条, ""))
	return 表

static func 卡表() -> Array:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读表()
		_表代 = Db.代
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return c.duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id", "")) == 键:
			return c.duplicate(true)
	return {}

static func 有(id: Variant) -> bool:
	return not 卡(str(id)).is_empty()

## 这张牌是不是筹码牌（`卡类` 唯一口径；不认卡名）。
static func 是筹码牌(card: Variant) -> bool:
	return card is Dictionary and str(card.get("卡类", "")) == "筹码牌"

## 卡上的档位（1 小 / 2 大 / 3 头奖 / 0 读不到）—— 交给 `SubDeck` 读，别自己再写一份。
static func 等级(card: Variant) -> int:
	return SubDeck.等级(card, 等级键)

## 开场的库：**只有小筹码 4 张**（大筹码与头奖不入场）。
static func 初始筹码牌库() -> Array:
	var 出: Array = []
	for id in 小筹码:
		出.append(卡(id))
	return 出

static func _是ATX(u: Variant) -> bool:
	return u is Dictionary and u.get("side") == "ally" and str(Fac.势力名(u)) == 势力

static func _有ATX成员(ctx: Dictionary) -> bool:
	for u in J.or_(ctx.get("allies"), []):
		if _是ATX(u):
			return true
	return false

# ==========================================================================================
# 三、初始化 / 阶段初（每场、每回合一次性状态）
# ==========================================================================================
## 开场：造出「只有 4 张小筹码」的库 + 断路器集合 + 两个结算计数。
## ★ 由 `Setup.初始化单机牌组` 的 ATX 那一段里调。
static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx["筹码牌库"] = 初始筹码牌库() if _有ATX成员(ctx) else []
	ctx["已放入头奖"] = {}
	ctx["赌局触发次数"] = 0
	ctx["赌局放入次数"] = 0
	if not (ctx.get("移出牌") is Array):
		ctx["移出牌"] = []
	ctx.erase("筹码庄家通吃")
	for u in J.or_(ctx.get("allies"), []):
		if _是ATX(u):
			u["本回合再动已用"] = false
			u.erase("筹码保命")
			u.erase("筹码首闪")

## 我方阶段初（由 `Btl.开始我方阶段` 的 ATX 那一段调）：
## 「到下个我方阶段前」的东西在这里统一过期（庄家通吃 / 死里逃生 / 幸运女神首闪），
## 并给每台 ATX 机体清掉「本回合再动已用」（断路器 3 的每回合额度）。
static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	ctx.erase("筹码庄家通吃")
	for u in J.or_(ctx.get("allies"), []):
		if _是ATX(u):
			u["本回合再动已用"] = false
			u.erase("筹码保命")
			u.erase("筹码首闪")

## 规则钩子转发【我方阶段初_前】（`RuleHooks.广播("我方阶段初_前")`）。
static func 我方阶段初_前(ctx: Variant) -> void:
	阶段初(ctx)

# ==========================================================================================
# 四、三层反馈：预告 + 结算（三个纯读口，一个状态都不改、一个随机数都不掷）
# ==========================================================================================
## 预告：筹码牌库还剩什么（`{小, 大, 头奖}`；A7 的徽章直接读这一个）。
static func 筹码牌库张数(ctx: Variant) -> Dictionary:
	var 小 := 0
	var 大 := 0
	var 头 := 0
	for c in J.or_(J.g(ctx, "筹码牌库"), []):
		match 等级(c):
			1: 小 += 1
			2: 大 += 1
			3: 头 += 1
	return {"小": 小, "大": 大, "头奖": 头}

## 结算：本场累计【赌局】触发次数（纯读）。
static func 赌局触发次数(ctx: Variant) -> int:
	return int(J.num0(J.g(ctx, "赌局触发次数")))

## 结算：本场累计「放入次数」（纯读）。
static func 赌局放入次数(ctx: Variant) -> int:
	return int(J.num0(J.g(ctx, "赌局放入次数")))

# ==========================================================================================
# 五、【赌局】触发管线（Step 1 抽一张 → Step 2 放入 X）
# ==========================================================================================
## 打出一张带【赌局】的牌之后调（`Btl.打出精神或公有牌` / `DeckFlow.打出大招` 各一处钩子）。
## 打出者**亮着闪字**（`u.闪 == true`）才发生任何事；**没亮 → 什么都不发生、也不报错**（不写记录）。
## ★ A6d：合体技【轮盘双响】的赌局口径是「**两人任一亮闪字即可**」→ 由调用方 `视为亮闪 = true`
##   指定一个「已判定为亮闪」的打出者进来（其它牌一律不传，逐字走原口径）。
##   Step 1：`SubDeck.抽一张(ctx.筹码牌库, ctx.公有手牌, 6, ctx.rng)`（满 6 不抽、不消耗库、不掷随机数）
##   Step 2：牌上有 `放入` → `SubDeck.放入(...)`，**头奖每种每场最多放入 1 次**（断路器 1），大筹码不限次
## 立即与放入合成**一行**记录（例：`〔赌局〕响介 已闪开 → 抽到「侥幸」（筹码牌库剩 3 张：小 3 / 大 0 / 头奖 0）`）。
static func 触发赌局(ctx: Variant, u: Variant, card: Variant, 视为亮闪: bool = false) -> Dictionary:
	var 记 := {"触发": false, "抽到": "", "放入": "", "原因": ""}
	if not (ctx is Dictionary) or not (card is Dictionary):
		return 记
	if not J.truthy(card.get("赌局")):
		记["原因"] = "这张牌不带【赌局】"
		return 记
	if not (u is Dictionary) or not (J.truthy(u.get("闪")) or 视为亮闪):
		# 没亮闪字：不抽、不放、不报错、一行记录都不写
		记["原因"] = "打出者没亮闪字"
		return 记
	记["触发"] = true
	ctx["赌局触发次数"] = 赌局触发次数(ctx) + 1
	if not (ctx.get("筹码牌库") is Array):
		ctx["筹码牌库"] = []
	if not (ctx.get("公有手牌") is Array):
		ctx["公有手牌"] = []
	var 谁 := str(u.get("name", ""))
	var 文 := "〔赌局〕%s 已闪开" % 谁
	# ---- Step 1：先抽 ----
	var 抽 := SubDeck.抽一张(ctx["筹码牌库"], ctx["公有手牌"], 手牌上限, ctx.get("rng"))
	if 抽.is_empty():
		if (ctx["公有手牌"] as Array).size() >= 手牌上限:
			文 += " → 公有手牌已满（%d/%d）→ 不抽" % [手牌上限, 手牌上限]
		else:
			文 += " → 筹码牌库空了 → 不抽"
	else:
		记["抽到"] = str(抽.get("id", ""))
		文 += " → 抽到「%s」" % str(抽.get("名", ""))
	var 计 := 筹码牌库张数(ctx)
	文 += "（筹码牌库剩 %d 张：小 %d / 大 %d / 头奖 %d）" % [
		int((ctx["筹码牌库"] as Array).size()), int(计["小"]), int(计["大"]), int(计["头奖"])]
	# ---- Step 2：再放（头奖每种每场限 1 次 = 断路器 1；大筹码不限次）----
	var 放 := str(J.or_(card.get("放入"), ""))
	if 放 != "":
		var 放卡 := 卡(放)
		if 放卡.is_empty():
			记["原因"] = "放入的牌不认识：%s" % 放
			文 += " → 放入失败（不认识的牌：%s）" % 放
		else:
			if not (ctx.get("已放入头奖") is Dictionary):
				ctx["已放入头奖"] = {}
			# ★ 断路器集合按**卡自己的 id** 登记（不是字面的「筹码」）：设计稿写的是
			#   「头奖**每种**每场最多放入 1 次」——「梭哈」与「大满贯」各占各的额度。
			if SubDeck.放入(ctx["筹码牌库"], 放卡, ctx["已放入头奖"],
					str(放卡.get("id", "")), 等级键, SubDeck.移出下限):
				记["放入"] = str(放卡.get("id", ""))
				ctx["赌局放入次数"] = 赌局放入次数(ctx) + 1
				文 += " → 放入「%s」" % str(放卡.get("名", ""))
			else:
				记["原因"] = "头奖【%s】本场已经放入过一次（断路器 1）" % str(放卡.get("名", ""))
				文 += " → 头奖「%s」本场已放过（每种每场限 1 次）" % str(放卡.get("名", ""))
	Btl.pushLog(ctx, 文, {
		"类型": "赌局", "势力": 势力, "单位": u.get("key"), "卡牌ID": card.get("id"),
		"卡牌": card.get("名"), "抽到": 记["抽到"], "放入": 记["放入"],
		"筹码牌库": 计, "筹码牌库张数": (ctx["筹码牌库"] as Array).size(),
		"赌局触发次数": 赌局触发次数(ctx), "赌局放入次数": 赌局放入次数(ctx),
	})
	return 记

## 钩子别名：打出任意一张牌之后调；不带【赌局】→ 立刻返回（一个字段都不动）。
static func 打出后赌局(ctx: Variant, u: Variant, card: Variant) -> Dictionary:
	return 触发赌局(ctx, u, card)

## 规则钩子【大招收尾后】：通用大招打出之后的那一次【赌局】（`DeckFlow` 只认钩子）。
static func 大招收尾后(ctx: Dictionary, u: Dictionary, 卡: Dictionary) -> void:
	打出后赌局(ctx, u, 卡)

# ==========================================================================================
# 六、打出筹码牌（0 费 / 不占武器 / 任何 ATX 成员都能打）
# ==========================================================================================
## 规则钩子【卡不可打原因】：筹码牌由这边给结论；别的牌一律不接手。
static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	if not 是筹码牌(card):
		return {"终局": false}
	return {"终局": true, "原因": 不可打原因(ctx, u, card)}

## 规则钩子【区规则门槛】：筹码区一律由这边接管（不是筹码牌也给出「这不是筹码牌」）。
static func 区规则门槛(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> Dictionary:
	if 区 != CardPlay.区_筹码:
		return {"终局": false}
	return {"终局": true, "接手": true, "原因": 不可打原因(ctx, u, card)}

## 这张筹码牌现在打不打得出来（空串 = 能打；否则是**给玩家看的理由**，纯读）。
static func 不可打原因(ctx: Dictionary, u: Dictionary, card: Variant) -> String:
	if not 是筹码牌(card):
		return "这不是筹码牌"
	if not _是ATX(u):
		return "筹码牌只有 ATX 成员能打"
	if float(u.get("hp", 0.0)) <= 0.0:
		return "这台机体已经阵亡"
	return ""

static func 打出筹码牌(ctx: Dictionary, unit_id: Variant, 牌标识: Variant = null, target_id: Variant = null) -> Dictionary:
	if not (ctx is Dictionary):
		return {"成功": false, "原因": "没有战斗上下文"}
	var u = Btl.找单位(ctx, unit_id, "ally")
	if not (u is Dictionary):
		return {"成功": false, "原因": "找不到这台我方机体"}
	var 手: Array = J.or_(ctx.get("公有手牌"), [])
	var card = null
	for c in 手:
		if not 是筹码牌(c):
			continue
		if 牌标识 == null or str(c.get("id", "")) == str(牌标识) or str(c.get("名", "")) == str(牌标识):
			card = c
			break
	if not (card is Dictionary):
		return {"成功": false, "原因": "公有手牌里没有这张筹码牌"}
	# ★ CR-2 Batch B（P2-2）：筹码牌门槛的唯一真源（门面「亮不亮」调的是同一个函数）
	var 因 := CardPlay.不可打原因(ctx, u, card, CardPlay.区_筹码)
	if 因 != "":
		return {"成功": false, "原因": 因}
	var 级 := 等级(card)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	# ---- 效果（0 费；不置 `主武器已销毁`）----
	var 结果 := 执行效果(ctx, u, card, target_id)
	# ---- 离手 ----
	ctx["公有手牌"] = 手.filter(func(c): return not is_same(c, card))
	# ---- 归库 / 移出本场（★ A3a 的通用层裁决，阈值 1 / 3 不变）----
	if not (ctx.get("筹码牌库") is Array):
		ctx["筹码牌库"] = []
	if not (ctx.get("移出牌") is Array):
		ctx["移出牌"] = []
	var 去处 := SubDeck.回库或移出(ctx["筹码牌库"], ctx["移出牌"], card, 等级键, 回库键)
	var 计 := 筹码牌库张数(ctx)
	Btl.pushLog(ctx, "〔筹码牌〕%s 打出【%s】（0 费；%s；不占武器）%s" % [
		str(u.get("name", "")), str(card.get("名", "")),
		"头奖 → 移出本场" if 去处 == "移出" else "回筹码牌库",
		"；" + str(结果.get("摘要", "")) if str(结果.get("摘要", "")) != "" else ""],
		J.merged({"类型": "筹码牌", "势力": 势力, "单位": u.get("key"), "卡牌ID": card.get("id"),
			"卡牌": card.get("名"), "筹码等级": float(级), "去处": 去处,
			"筹码牌库": 计, "筹码牌库张数": int((ctx["筹码牌库"] as Array).size()),
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	if str(card.get("动作", "")) == "攻击":
		Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "筹码等级": 级, "去处": 去处,
		"目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")),
		"主武器已销毁": J.truthy(u.get("主武器已销毁"))}

# ==========================================================================================
# 七、效果执行器（10 张，一张一个分支；数值全部从卡面读，不在代码里写死）
# ==========================================================================================
static func 执行效果(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant = null) -> Dictionary:
	match str(card.get("动作", "")):
		"战意": return _战意(ctx, u, card, target_id)
		"闪避": return _闪避(ctx, u, card, target_id)
		"攻击": return _攻击(ctx, u, card, target_id)
		"抽精神": return _抽精神(ctx, u, card, target_id)
		"减冷却": return _减冷却(ctx, u, card, target_id)
		"暴击闪避": return _幸运女神(ctx, card)
		"保命": return _死里逃生(ctx, u, card, target_id)
		"通吃": return _庄家通吃(ctx, card)
		"清冷却": return _梭哈(ctx, card)
		"再动": return _大满贯(ctx, card)
	push_error("AtxChips：未知的筹码牌动作「%s」" % str(card.get("动作", "")))
	return {"摘要": "", "击破": 0.0}

## 指定一台**我方 ATX 成员**（不指定 / 指向别人 → 退到打出者自己；确定性，不掷随机数）。
static func _ATX目标(ctx: Dictionary, u: Dictionary, target_id: Variant) -> Dictionary:
	var t = Btl.找单位(ctx, target_id, "ally")
	if t is Dictionary and _是ATX(t) and float(t.get("hp", 0.0)) > 0.0:
		return t
	return u

## 一枚硬币：指定一台 ATX 成员，战意 +8。
static func _战意(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var t := _ATX目标(ctx, u, target_id)
	var 加 := J.num0(card.get("战意加"))
	var 后 := Btl.加战意(t, 加, ctx, "筹码·%s" % str(card.get("名", "")))
	return {"摘要": "%s 战意 +%d（现在 %d）" % [str(t.get("name", "")), int(加), int(后)], "击破": 0.0}

## 侥幸：指定一台 ATX 成员，到下个我方阶段前闪避 +15。
static func _闪避(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var t := _ATX目标(ctx, u, target_id)
	var 加 := J.num0(card.get("闪避加"))
	Btl.换同源增益(t, "筹码:%s" % str(card.get("名", "")), {"eva": 加, "剩余": 1.0})
	return {"摘要": "%s 闪避 +%d（到下个我方阶段前）" % [str(t.get("name", "")), int(加)], "击破": 0.0}

## 冷枪：直射·物理 300 × 4 段 · 每段命中 70 · 无视距离（**一次攻击 = 一条记录**，绝不逐段写行）。
static func _攻击(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var 段 := maxi(1, int(card.get("段数", 1)))
	var w := {
		"name": str(card.get("名", "冷枪")), "fire": "direct",
		"power": J.num0(card.get("威力")), "hit": J.num0(card.get("命中")),
		"critMod": 0.0, "stat": "射击", "dmgType": str(card.get("伤害类型", "物理")),
		"cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [], "ignoreDef": false,
		# 4×4 全图最远就是 6 格 → `1..6` = 无视距离（不再按站位缩距离）
		"距离": [1, 6], "无视距离": J.truthy(card.get("无视距离")),
	}
	if 段 > 1:
		w["hits"] = float(段)
		w["special"] = "multi"
	var r = Btl._执行武器攻击(ctx, u, {"t": w, "cd": 0.0, "uses": null}, target_id)
	# ★ 一次攻击 = 一条记录（攻击本身由 `Flow.resolveAction` → `Calc.resolveAttack` 那条路写**一条**，
	#   这里只回一句**摘要**给〔筹码牌〕总账行，绝不逐段再写行）。数字从刚写下的那一条记录里读，不另算一遍。
	var 末: Dictionary = {}
	var 日志: Array = J.or_(ctx.get("log"), [])
	if not 日志.is_empty() and 日志[日志.size() - 1] is Dictionary:
		var e: Dictionary = 日志[日志.size() - 1]
		if str(e.get("类型", "")) == "攻击" and str(e.get("武器", "")) == str(w.name):
			末 = e
	return {"摘要": "%d 段 · 命中 %d 段 · 伤害 %s" % [段, int(J.num0(末.get("命中段数"))),
		J.s(J.round(J.num0(末.get("伤害"))))],
		"击破": J.num0(r.get("击破")) if r is Dictionary else 0.0,
		"目标": J.g(r, "目标")}

## 换牌：指定一台 ATX 成员，抽 1 张精神牌（走 `Setup.抽专属牌`，满手不抽）。
static func _抽精神(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var t := _ATX目标(ctx, u, target_id)
	var 抽 := Setup.抽专属牌(t, maxi(1, int(card.get("张数", 1))))
	if 抽.is_empty():
		return {"摘要": "%s 的专属手牌已满（%d/%d）→ 不抽" % [str(t.get("name", "")),
			int(J.or_(t.get("专属手牌"), []).size()), int(Params.专属手牌上限())], "击破": 0.0}
	return {"摘要": "%s 抽到精神牌【%s】" % [str(t.get("name", "")), str(抽[0].get("名", ""))], "击破": 0.0}

## 再转一轮：指定一台 ATX 成员，**一张**冷却中的大招冷却 −2（取冷却最久的那一张，确定性）。
static func _减冷却(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var t := _ATX目标(ctx, u, target_id)
	var 减 := J.num0(card.get("冷却减"))
	var 槽们: Array = J.or_(t.get("大招槽"), [])
	var 选中 = null
	for 槽 in 槽们:
		if not (槽 is Dictionary) or J.num0(槽.get("cd")) <= 0.0:
			continue
		if 选中 == null or J.num0(槽.get("cd")) > J.num0(选中.get("cd")):
			选中 = 槽
	if 选中 == null:
		return {"摘要": "%s 没有冷却中的大招 → 没得转" % str(t.get("name", "")), "击破": 0.0}
	var 前 := J.num0(选中.get("cd"))
	选中["cd"] = maxf(0.0, 前 - 减)
	return {"摘要": "%s 的【%s】冷却 %s→%s" % [str(t.get("name", "")),
		str(J.g(J.g(选中, "卡"), "名")), J.s(前), J.s(选中.get("cd"))], "击破": 0.0}

## 幸运女神：本回合 ATX 全体暴击 +20；到下个我方阶段前，每人第一次被攻击时闪避 +20。
## 「第一次被攻击」不做成 buff，只挂一个**每回合一次性标记**（`u.筹码首闪`），
## 由 `Calc.resolveAttack` 里那一道钩子（`AtxChips.首次被攻击`）在真的挨打时兑现并消费掉。
static func _幸运女神(ctx: Dictionary, card: Dictionary) -> Dictionary:
	var 暴击 := J.num0(card.get("暴击加"))
	var 台 := 0
	for a in J.or_(ctx.get("allies"), []):
		if not _是ATX(a) or float(a.get("hp", 0.0)) <= 0.0:
			continue
		Btl.换同源增益(a, "筹码:幸运女神", {"crit": 暴击, "剩余": 1.0})
		a["筹码首闪"] = int(ctx.get("turn", 1))
		台 += 1
	return {"摘要": "ATX 全体 %d 台本回合暴击 +%d；每人第一次被攻击时闪避 +%d" % [台, int(暴击), int(J.num0(card.get("首闪加")))],
		"击破": 0.0}

## 死里逃生：指定一台 ATX 成员，到下个我方阶段前第一次致命伤保留 1 HP 并算作闪开。
static func _死里逃生(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	var t := _ATX目标(ctx, u, target_id)
	t["筹码保命"] = int(ctx.get("turn", 1))
	return {"摘要": "%s 挂上「死里逃生」（第一次致命伤保留 %d HP，算作闪开）" % [
		str(t.get("name", "")), int(J.num0(card.get("保留HP")))], "击破": 0.0}

## 庄家通吃：到下个我方阶段前，ATX 成员每闪开一次攻击，攻击者受 600 物理伤害。
static func _庄家通吃(ctx: Dictionary, card: Dictionary) -> Dictionary:
	ctx["筹码庄家通吃"] = int(ctx.get("turn", 1))
	return {"摘要": "ATX 成员每闪开一次 → 攻击者受 %d 物理伤害（到下个我方阶段前）" % int(J.num0(card.get("反伤"))),
		"击破": 0.0}

## 梭哈（头奖）：ATX 全体大招槽里所有牌冷却清零。
## ★ CB-0 断路器 2（任务单 §1.1 第 2 条）：除了清 `u.大招槽` 的 `cd`，**同步清空 `u["v01冷却"]`**
##   字典里对应大招的 CD（响介 / 艾克赛琳 / 拉米亚的 v0.1 大招槽是 `v01别名`，冷却的唯一真源
##   在 `v01冷却` 里 —— 只清槽上的显示值等于没清）。
##   注意：**只清冷却，不清「本回合已打」** —— 本回合刚打过的那张因断路器 2 仍打不出第二次，
##   下回合起才可打（任务单原文）。
static func _梭哈(ctx: Dictionary, _card: Dictionary) -> Dictionary:
	var 清 := 0
	var 台 := 0
	var 清别名 := 0
	for a in J.or_(ctx.get("allies"), []):
		if not _是ATX(a) or float(a.get("hp", 0.0)) <= 0.0:
			continue
		var 本台 := 0
		for 槽 in J.or_(a.get("大招槽"), []):
			if 槽 is Dictionary and J.num0(槽.get("cd")) > 0.0:
				本台 += 1
			槽["cd"] = 0.0
		# ★ CB-0：`v01冷却`（v0.1 卡表大招的真实冷却字典）一起清零
		var 冷 = (a as Dictionary).get("v01冷却")
		if 冷 is Dictionary:
			for k in (冷 as Dictionary).keys():
				if int(J.num0((冷 as Dictionary)[k])) > 0:
					(冷 as Dictionary)[k] = 0
					清别名 += 1
		if 本台 > 0:
			清 += 本台
		台 += 1
	var 尾 := "；`v01冷却` 里另有 %d 张清零" % 清别名 if 清别名 > 0 else ""
	return {"摘要": "ATX 全体 %d 台的大招槽冷却全部清零（清了 %d 张%s）" % [台, 清, 尾], "击破": 0.0}

## 大满贯（头奖）：本回合所有 ATX 成员主武器全部恢复（再动），大招除外。
## ★ 必须受**断路器 3** 约束：每台机体每个我方回合最多 1 次再动（`u.本回合再动已用`）——
##   头奖也绕不过去（同一台第二次一律被拦下，主武器不被恢复）。
static func _大满贯(ctx: Dictionary, _card: Dictionary) -> Dictionary:
	var 成 := 0
	var 拦 := 0
	for a in J.or_(ctx.get("allies"), []):
		if not _是ATX(a) or float(a.get("hp", 0.0)) <= 0.0:
			continue
		if _再动一人(ctx, a):
			成 += 1
		else:
			拦 += 1
	return {"摘要": "再动 %d 台（大招除外）%s" % [成, "；断路器 3 拦下 %d 台" % 拦 if 拦 > 0 else ""], "击破": 0.0}

## 单台再动：★ A7 起**不再自己写一份**，统一走 `DeckFlow.再动` 那唯一一把闸
## （`u.本回合再动已用` = 断路器 3；闸门已放宽成「卡牌流转 **或** 单机牌组 任一开着」）。
## `来源 = "大满贯"` 只进记录括注，不参与判定 —— 秘银牌 / 筹码牌 / 精神牌同一台同一回合合计只能 1 次。
static func _再动一人(ctx: Dictionary, a: Dictionary) -> bool:
	return DeckFlow.再动(ctx, a, "大满贯")

# ==========================================================================================
# 八、两条「挨打时」的钩子（只有筹码牌自己挂上的标记才会进来；没有标记 = 一行都不进）
# ==========================================================================================
## 幸运女神的首闪：本次攻击里给该成员补一条 `eva +20` 的增益，然后把标记消费掉（每回合只一次）。
static func 首次被攻击(ctx: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return
	if def.get("筹码首闪") == null:
		return
	if int(J.num0(def.get("筹码首闪"))) != int(ctx.get("turn", 1)):
		def.erase("筹码首闪")          # 跨回合的旧标记直接作废（「到下个我方阶段前」）
		return
	def.erase("筹码首闪")
	Btl.换同源增益(def, "筹码:幸运女神·首闪", {"eva": 20.0, "剩余": 1.0})
	Btl.pushLog(ctx, "〔筹码·幸运女神〕%s 本回合第一次被攻击 → 闪避 +20" % str(def.get("name", "")),
		J.merged({"类型": "筹码保命", "势力": 势力, "首次被攻击": true, "闪避加": 20.0}, Btl.谁(def)))

## 死里逃生：第一次受到致命伤害时保留 1 HP，并**算作闪开**（闪字亮起 + 大招槽轮转）。
static func 致命保留(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (def is Dictionary):
		return
	if def.get("筹码保命") == null:
		return
	if int(J.num0(def.get("筹码保命"))) != int(ctx.get("turn", 1)):
		def.erase("筹码保命")
		return
	if float(def.get("hp", 0.0)) > 0.0:
		return                          # 这一下不致命 → 留着，等真正的那一次
	def.erase("筹码保命")
	def["hp"] = 1.0
	def["闪"] = true                    # 算作闪开（纯布尔，与 A2 同一个字段）
	var 轮 := Calc.九死一生_轮转(def)
	Btl.pushLog(ctx, "〔筹码·死里逃生〕%s 本应被击坠 → 保留 1 HP，并算作闪开%s" % [
		str(def.get("name", "")),
		"（大招槽冷却 −1：%s）" % "、".join(轮.map(func(e): return "%s %s→%s" % [str(e.牌), J.s(e.前), J.s(e.后)])) if not 轮.is_empty() else ""],
		J.merged({"类型": "筹码保命", "势力": 势力, "单位": def.get("key"),
			"攻击者": J.g(att, "key"), "保命": true, "闪": true, "轮转次数": 轮.size()}, Btl.谁(def)))

## 规则钩子转发【受击前】（`RuleHooks.广播("受击前")`）。
static func 受击前(ctx: Variant, att: Variant, def: Variant) -> void:
	首次被攻击(ctx, def)

## 规则钩子转发【致命保留_前】（`RuleHooks.广播("致命保留_前")`，在「单机牌组战意」之前）。
static func 致命保留_前(ctx: Variant, att: Variant, def: Variant) -> void:
	致命保留(ctx, att, def)

## 庄家通吃：某台 ATX 成员闪开一次攻击 → 攻击者受 600 物理伤害（由 `Calc.九死一生_判定` 调）。
static func 闪开后(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not (att is Dictionary) or not (def is Dictionary):
		return
	var 回合 = ctx.get("筹码庄家通吃")
	if 回合 == null:
		return
	if int(J.num0(回合)) != int(ctx.get("turn", 1)):
		ctx.erase("筹码庄家通吃")
		return
	var 反 := 600.0
	var 前 := float(att.get("hp", 0.0))
	if 前 <= 0.0:
		return
	att["hp"] = maxf(0.0, 前 - 反)
	Btl.pushLog(ctx, "〔筹码·庄家通吃〕%s 闪开 → 攻击者 %s 受 %d 物理伤害（%s → %s）" % [
		str(def.get("name", "")), str(att.get("name", "")), int(反), J.s(J.round(前)), J.s(J.round(float(att.get("hp", 0.0))))],
		J.merged({"类型": "筹码反伤", "势力": 势力, "单位": def.get("key"), "攻击者": att.get("key"),
			"反伤": 反, "攻击者剩余HP": float(att.get("hp", 0.0))}, Btl.谁目标(att)))
