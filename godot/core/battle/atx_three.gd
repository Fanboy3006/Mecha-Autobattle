## ★ A6c：响介（A1）/ 艾克赛琳（A2）/ 拉米亚（A3）三人按 **v0.1 稿**补齐卡表。
# 见 协作/设计/响介卡牌设计 v0.1.md · 协作/设计/艾克赛琳卡牌设计 v0.1.md · 协作/设计/拉米亚卡牌设计 v0.1.md
class_name AtxThree
extends RefCounted

const 势力 := "ATX"

const 响介 := "A1"
const 艾克赛琳 := "A2"
const 拉米亚 := "A3"
const 弓 := "弓"

const ID_赌神入局 := "U_ATX_2"
const ID_烟雾弹 := "U_ATX_8"
const ID_满弦 := "ATX_RW_MANXIAN"
const ID_连珠箭 := "ATX_RW_LIANZHU"
const ID_再加一注 := "ATX_RW_JIAYIZHU"

const 正面突破命中 := 10.0
const 正面突破暴击 := 10.0
const 天然闪避 := 30.0
const 烟雾命中惩罚 := 30.0
const 切札段倍率 := 0.6
const 切札段倍率加 := 0.75
const 凤凰雾袭倍率 := 1.3
const 凤凰雾袭倍率加 := 1.5
const 全开锁台 := 3
const 全开锁台加 := 4
const 全开暴击X := 0.5
const 自爆残HP比 := 0.10
const 自爆残HP比加 := 0.30
const 满开暴击X := 1.0
const 满开命中 := -20.0
const 满开费用 := 30.0
const 满开费用加 := 25.0
const 好运加护暴击X := 1.0
const 好运加护命中 := -20.0
const 好运加护命中加 := -15.0

const 下一张键 := "v01下一张武器"
const 冷却键 := "v01冷却"
const 每场次数键 := "v01每场次数"
const 每场一次键 := "v01每场一次"
const 天然待键 := "v01天然待"
const 天然本击键 := "v01天然本击"
const 天然已用回合键 := "v01天然已用回合"
const 本场击破键 := "v01本场击破"
const 上次攻击键 := "v01上次攻击"
const 满开禁主武器键 := "v01满开禁主武器"
const 援护键 := "v01艾克赛琳援护"
const 重打牌名 := "再来一把·重打"

# ---- 一、身份 ----

static func _键Of(u: Variant) -> String:
	if not (u is Dictionary):
		return ""
	var k := str((u as Dictionary).get("key", ""))
	if k != "":
		return k
	return str((u as Dictionary).get("tplKey", ""))

static func 是我方(u: Variant) -> bool:
	return u is Dictionary and str((u as Dictionary).get("side", "ally")) == "ally"

static func 是响介(u: Variant) -> bool:
	return 是我方(u) and (_键Of(u) == 响介 or str((u as Dictionary).get("tplKey", "")) == 响介)

static func 是艾克赛琳(u: Variant) -> bool:
	return 是我方(u) and (_键Of(u) == 艾克赛琳 or str((u as Dictionary).get("tplKey", "")) == 艾克赛琳)

static func 是拉米亚(u: Variant) -> bool:
	return u is Dictionary and str((u as Dictionary).get("trait", "")) == "wSeries"

static func 角色键(角色: Variant) -> String:
	return str(角色)

# ---- 二、武器拼装与卡表读入 ----
static func _并(d: Dictionary, 额外: Variant) -> Dictionary:
	if 额外 is Dictionary:
		for k in (额外 as Dictionary).keys():
			d[k] = 额外[k]
	return d

static func _武(名: String, fire: String, 伤害类型: String, 威力: float, 段数: int, 命中: float,
	距离: Array, 属性: String, 额外: Dictionary = {}) -> Dictionary:
	var w := {
		"name": 名, "fire": fire, "dmgType": 伤害类型, "power": 威力, "hit": 命中,
		"stat": 属性, "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"range": [float(距离[0]), float(距离[1])], "critMod": 0.0, "afterMove": true,
		"ignoreDef": false, "special": null, "desc": "", "v37": true,
	}
	if 段数 > 1:
		w["hits"] = float(段数)
		w["special"] = "multi"
	return _并(w, 额外)

static func _近战(名: String, 威力: float, 段数: int, 命中: float, 距离: Array, 额外: Dictionary = {}) -> Dictionary:
	return _武(名, "melee", "物理", 威力, 段数, 命中, 距离, "格斗", 额外)

const _整数路径们 := [
	"亮起.们[].阈值", "亮起.阈值", "入库条件.阈值", "入手等级", "入牌库条件.阈值",
	"多锁", "强运分支[].全局[].段数", "强运段数", "晋升等级",
	"武器.分段[].威力", "武器.分段[].段数", "每场次数", "雾袭分支[].全局[].数量",
]

static var _表: Array = []
static var _升表: Array = []
static var _表代: int = -1

static func _卡包() -> Dictionary:
	return Db.T.get("卡包", {}).get(势力, {})

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

static func _读段(段名: String) -> Array:
	var 出: Array = []
	for 条 in _卡包().get(段名, []):
		if 条 is Dictionary:
			出.append(_还原值(条, ""))
	return 出

static func _确保缓存() -> void:
	if _表代 != Db.代 or _表.is_empty():
		_表 = _读段("三小强")
		_升表 = _读段("三小强+")
		_表代 = Db.代

static func 卡表() -> Array:
	_确保缓存()
	return _表

# 待接入：肉鸽升级（+ 版），勿当死代码删
static func 升版卡表() -> Array:
	_确保缓存()
	return _升表

static func 全部卡() -> Array:
	var 出: Array = []
	for c in 卡表():
		出.append((c as Dictionary).duplicate(true))
	for c in 升版卡表():
		出.append((c as Dictionary).duplicate(true))
	return 出

static func _按id找(表: Array, id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 表:
		if str((c as Dictionary).get("id", "")) == 键:
			return (c as Dictionary).duplicate(true)
	return {}

static func 卡(id: Variant) -> Dictionary:
	var 一 := _按id找(升版卡表(), id)
	if not 一.is_empty():
		return 一
	return _按id找(卡表(), id)

static func 有(id: Variant) -> bool:
	return not 卡(id).is_empty()

static func 是v01卡(card: Variant) -> bool:
	return card is Dictionary and J.truthy((card as Dictionary).get("v01卡"))

static func 走自家口子(card: Variant) -> bool:
	if not 是v01卡(card):
		return false
	return (card as Dictionary).get("武器改写") == null

static func 角色牌们(键: Variant) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 卡表():
		if str((c as Dictionary).get("角色", "")) == k:
			出.append((c as Dictionary).duplicate(true))
	return 出

# 待接入：肉鸽升级（+ 版），勿当死代码删
static func 角色牌们加版(键: Variant) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 升版卡表():
		if str((c as Dictionary).get("角色", "")) == k:
			出.append((c as Dictionary).duplicate(true))
	return 出

static func 按类(类: String, 键: Variant = "") -> Array:
	var 出: Array = []
	for c in 卡表():
		var d: Dictionary = c
		if str(d.get("卡类", "")) != 类:
			continue
		if str(键) != "" and str(d.get("角色", "")) != str(键):
			continue
		出.append(d.duplicate(true))
	return 出

static func 主武器卡们(键: Variant = "") -> Array: return 按类("主武器卡", 键)
static func 副武器卡们(键: Variant = "") -> Array: return 按类("副武器卡", 键)
static func 大招卡们(键: Variant = "") -> Array: return 按类("大招槽卡", 键)
static func 精神牌们(键: Variant = "") -> Array: return 按类("专属精神牌", 键)

static func 按角色张数() -> Dictionary:
	var 出 := {}
	for k in [响介, 艾克赛琳, 拉米亚]:
		var 们 := 角色牌们(k)
		var 主 := 0
		var 副 := 0
		var 大 := 0
		var 精 := 0
		for c in 们:
			match str((c as Dictionary).get("卡类", "")):
				"主武器卡": 主 += 1
				"副武器卡": 副 += 1
				"大招槽卡": 大 += 1
				"专属精神牌": 精 += 1
		出[k] = {"主武器": 主, "副武器": 副, "大招": 大, "精神": 精, "合计": 们.size()}
	return 出

static func 卡表张数() -> Dictionary:
	return {"普通版": 卡表().size(), "加版": 升版卡表().size()}

# ---- 三、获取档与被动 ----
const 档_初始 := "初始"
const 档_剧情 := "剧情"
const 档_肉鸽 := "肉鸽"

static func 这一档发吗(档: String, 等级: int = 10, 肉鸽: bool = true) -> bool:
	if 肉鸽:
		return 档 == 档_初始
	match 档:
		档_初始: return true
		档_剧情: return 等级 >= 20
		档_肉鸽: return 等级 >= 30
	return false

static func 开局牌库(键: Variant, 等级: int = 10, ctx: Variant = null, 肉鸽: bool = true) -> Array:
	var 出: Array = []
	for c in 角色牌们(键):
		var d: Dictionary = c
		if not J.truthy(d.get("v01卡")):
			continue
		if not 这一档发吗(str(d.get("获取", 档_初始)), 等级, 肉鸽):
			continue
		出.append(d)
	return 出

static func 全卡池体验(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	if 选 is Dictionary:
		if J.truthy((选 as Dictionary).get("全卡池体验")) or J.truthy((选 as Dictionary).get("快速测试")):
			return true
	return J.truthy((ctx as Dictionary).get("全卡池体验")) \
		or J.truthy((ctx as Dictionary).get("快速测试"))

static func 按档名单(键: Variant, 档: String) -> Array:
	var 出: Array = []
	for c in 角色牌们(键):
		if str((c as Dictionary).get("获取", 档_初始)) == 档:
			出.append(str((c as Dictionary).get("名", "")))
	return 出

## 【正面突破】：响介近战攻击同列目标时每段命中 +10、暴击 +10。
static func 正面突破成立(att: Variant, def: Variant, w: Variant, ctx: Variant = null) -> bool:
	if not 是响介(att) or not (def is Dictionary):
		return false
	if not (w is Dictionary) or Reach.rangeKindOf(w) != Reach.KIND_MELEE():
		return false
	if (att as Dictionary).get("slot") == null or (def as Dictionary).get("slot") == null:
		return false
	return int(Fm.colOfSlot(float((att as Dictionary).slot))) == int(Fm.colOfSlot(float((def as Dictionary).slot)))

static func 命中修正(att: Variant, def: Variant, w: Variant, ctx: Variant = null) -> float:
	if not 正面突破成立(att, def, w, ctx):
		return 0.0
	return 正面突破命中

static func 暴击修正(att: Variant, def: Variant, w: Variant, ctx: Variant = null) -> float:
	if not 正面突破成立(att, def, w, ctx):
		return 0.0
	return 正面突破暴击

## 【天然】：艾克赛琳每个敌方阶段第一次被攻击时闪避 +30。
static func 闪避加成(def: Variant, ctx: Variant = null) -> float:
	if not 是艾克赛琳(def) or not (ctx is Dictionary):
		return 0.0
	if not J.same((def as Dictionary).get(天然本击键), (ctx as Dictionary).get("turn")):
		return 0.0
	return 天然闪避

static func 初始化(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	if not (ctx.get("A6c计数") is Dictionary):
		ctx["A6c计数"] = {"攻击": 0, "天然触发": 0, "正面突破": 0}

static func 挂被动(u: Variant) -> void:
	if not (u is Dictionary):
		return
	if 是艾克赛琳(u):
		if (u as Dictionary).get(天然已用回合键) == null:
			(u as Dictionary)[天然已用回合键] = -1

static func 敌方阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if 是艾克赛琳(u):
			(u as Dictionary).erase(天然本击键)

static func 阶段初(ctx: Variant) -> void:
	if not (ctx is Dictionary):
		return
	for u in J.or_((ctx as Dictionary).get("allies"), []):
		if not (u is Dictionary):
			continue
		var 冷 = (u as Dictionary).get(冷却键)
		if 冷 is Dictionary:
			for k in (冷 as Dictionary).keys():
				冷[k] = maxi(0, int(J.num0((冷 as Dictionary)[k])) - 1)
		(u as Dictionary).erase(下一张键)
		(u as Dictionary).erase("v01本次伤害倍率")
		(u as Dictionary).erase("v01无视遮挡本回合")
		(u as Dictionary).erase("v01不能打大招")
		(u as Dictionary).erase("强运必触发")
		(u as Dictionary)["本回合再动已用"] = false
		for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
			if 槽 is Dictionary and J.truthy((槽 as Dictionary).get("v01别名")):
				(槽 as Dictionary)["本回合已打"] = false
		同步大招槽(u)

static func 受击前(ctx: Variant, att: Variant, def: Variant) -> void:
	if not (ctx is Dictionary) or not 是艾克赛琳(def):
		return
	var d: Dictionary = def
	if J.same(d.get(天然本击键), (ctx as Dictionary).get("turn")):
		return
	if J.same(d.get(天然已用回合键), (ctx as Dictionary).get("turn")):
		return
	d[天然本击键] = (ctx as Dictionary).get("turn")
	d[天然已用回合键] = (ctx as Dictionary).get("turn")
	_计数加(ctx, "天然触发", 1)
	Btl.pushLog(ctx, "〔天然〕%s 这个敌方阶段第一次被攻击 → 闪避 +%d" % [
		str(d.get("name", "")), int(天然闪避)],
		J.merged({"类型": "天然", "单位": d.get("key"), "闪避加": 天然闪避,
			"回合": (ctx as Dictionary).get("turn")}, Btl.谁(d)))

static func 攻击后消耗(ctx: Variant, att: Variant, def: Variant, _landed: float = 0.0, _w: Variant = null) -> void:
	if not (ctx is Dictionary):
		return
	var 记 = 援护待触发(ctx)
	if 记 is Dictionary and 是响介(att) and def is Dictionary and not J.truthy((记 as Dictionary).get("已用")):
		var 键 = (def as Dictionary).get("key")
		if 键 != null:
			(记 as Dictionary)["目标"] = 键
			(记 as Dictionary)["单位"] = (att as Dictionary).get("key")
	if not 是艾克赛琳(def):
		return
	(def as Dictionary).erase(天然本击键)

static func 我方阶段初_后(ctx: Variant) -> void:
	阶段初(ctx)

static func 武器攻击后(ctx: Variant, att: Variant, def: Variant, landed: float, w: Variant) -> void:
	攻击后消耗(ctx, att, def, landed, w)

static func _计数加(ctx: Dictionary, 键: String, 加: int) -> void:
	if not (ctx.get("A6c计数") is Dictionary):
		ctx["A6c计数"] = {"攻击": 0, "天然触发": 0, "正面突破": 0}
	var 计: Dictionary = ctx["A6c计数"]
	计[键] = int(J.num0(计.get(键))) + 加

static func 本场计数(ctx: Variant, 键: String = "") -> Variant:
	if not (ctx is Dictionary):
		return 0 if 键 != "" else {}
	var 计 = ctx.get("A6c计数")
	var d: Dictionary = 计 if 计 is Dictionary else {"攻击": 0, "天然触发": 0, "正面突破": 0}
	if 键 == "":
		return d.duplicate(true)
	return int(J.num0(d.get(键)))

# ---- 四、装填与大招槽别名 ----
static func 装填单位(u: Variant, 等级: int, ctx: Variant = null) -> Array:
	var 加: Array = []
	if not (u is Dictionary):
		return 加
	挂被动(u)
	var 键 := _键Of(u)
	if 键 == "" or not [响介, 艾克赛琳, 拉米亚].has(键):
		return 加
	var 肉鸽 := not 全卡池体验(ctx)
	for c in 开局牌库(键, 等级, ctx, 肉鸽):
		var 牌: Dictionary = Btl.克隆战术牌(c, ctx)
		牌["入手等级"] = int((c as Dictionary).get("入手等级", 10))
		加.append(牌)
	return 加

## 按晋升等级装填大招槽（`v01别名 = true`，冷却真源为 `v01冷却`）。
static func 装填大招槽(ctx: Variant, u: Variant, 等级: int = -1) -> int:
	if not (ctx is Dictionary) or not (u is Dictionary):
		return 0
	var 键 := _键Of(u)
	if 键 == "" or not [响介, 艾克赛琳, 拉米亚].has(键):
		return 0
	var lv := 等级
	if lv < 0:
		lv = int(J.num0((u as Dictionary).get("level", (u as Dictionary).get("lv", 10.0))))
	if lv <= 0:
		lv = 10
	if not ((u as Dictionary).get("大招槽") is Array):
		(u as Dictionary)["大招槽"] = []
	var 装 := 0
	for c in 大招卡们(键):
		var d: Dictionary = c
		if str(d.get("id", "")) == FacAtx.赌神入局ID:
			continue
		var 晋升 := int(J.num0(d.get("晋升等级")))
		var 需 := 晋升 if 晋升 > 0 else int(J.num0(d.get("入手等级")))
		if 需 <= 0:
			需 = 10
		if lv < 需:
			continue
		var id := str(d.get("id", ""))
		var 已有 := false
		for 槽 in (u as Dictionary).大招槽:
			var 卡 = J.g(槽, "卡")
			if 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == id:
				已有 = true
				break
		if 已有:
			continue
		var 冷 := float(J.or_(d.get("冷却"), 0.0))
		var 新槽 := MithrilV03Cards._槽(Btl.克隆战术牌(d, ctx), {
			"cd": 0.0, "cd_max": 冷, "已解锁": true, "实时门槛满足": true,
			"本回合已打": false, "门槛说明": "", "解锁说明": "", "v01别名": true,
			"处理者": "AtxThree"})
		(u as Dictionary).大招槽.append(新槽)
		装 += 1
	同步大招槽(u)
	return 装

static func 找别名槽(u: Variant, card: Variant) -> Dictionary:
	if not (u is Dictionary) or not (card is Dictionary):
		return {}
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if not (槽 is Dictionary) or not J.truthy((槽 as Dictionary).get("v01别名")):
			continue
		var 卡 = (槽 as Dictionary).get("卡")
		if 卡 is Dictionary and str((卡 as Dictionary).get("id", "")) == str((card as Dictionary).get("id", "")):
			return 槽
	return {}

static func 同步大招槽(u: Variant) -> void:
	if not (u is Dictionary):
		return
	for 槽 in J.or_((u as Dictionary).get("大招槽"), []):
		if not (槽 is Dictionary) or not J.truthy((槽 as Dictionary).get("v01别名")):
			continue
		var 卡 = (槽 as Dictionary).get("卡")
		if not (卡 is Dictionary):
			continue
		(槽 as Dictionary)["cd"] = float(冷却Of(u, 卡))
		(槽 as Dictionary)["cd_max"] = float(J.or_((卡 as Dictionary).get("冷却"), 0.0))
		(槽 as Dictionary)["已解锁"] = true
		(槽 as Dictionary)["实时门槛满足"] = true
		(槽 as Dictionary)["解锁说明"] = ""
		(槽 as Dictionary)["门槛说明"] = ""

static func 认领大招槽(_ctx: Dictionary, _u: Variant, 槽: Dictionary) -> String:
	if not (槽 is Dictionary):
		return ""
	return "AtxThree" if J.truthy((槽 as Dictionary).get("v01别名")) else ""

static func 大招不可打原因(ctx: Dictionary, u: Variant, 槽: Dictionary) -> Dictionary:
	if not J.truthy((槽 as Dictionary).get("v01别名")):
		return {"终局": false}
	return {"终局": true, "原因": 不可打原因(ctx, u, (槽 as Dictionary).get("卡"))}

static func 打出大招(ctx: Dictionary, u: Variant, 槽: Dictionary, target_id: Variant) -> Dictionary:
	return 打出牌(ctx, u, (槽 as Dictionary).get("卡"), target_id)

static func 大招阶段初(_ctx: Dictionary, u: Variant, 槽: Dictionary) -> bool:
	if not J.truthy((槽 as Dictionary).get("v01别名")):
		return false
	同步大招槽(u)
	return true

static func 卡不可打原因(ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	if not 走自家口子(card):
		return {"终局": false}
	return {"终局": true, "原因": 不可打原因(ctx, u, card)}

static func 区规则门槛(ctx: Dictionary, u: Dictionary, card: Dictionary, 区: String) -> Dictionary:
	if 区 != CardPlay.区_主武器 or not 走自家口子(card):
		return {"终局": false}
	return {"终局": true, "接手": true, "原因": 不可打原因(ctx, u, card)}

# ---- 五、出牌门槛与援护 ----
static func 不可打原因(ctx: Dictionary, u: Variant, card: Variant) -> String:
	if not (u is Dictionary) or not (card is Dictionary):
		return "没有这张牌"
	if float((u as Dictionary).get("hp", 0.0)) <= 0.0:
		return "这台机体已经阵亡"
	var 类 := str((card as Dictionary).get("卡类", ""))
	if 类 == "主武器卡" and 满开禁主武器(u, ctx):
		return "本回合【好运加护·满开】的代价：不能打主武器（下个我方阶段恢复）"
	if 类 == "主武器卡" or 类 == "大招槽卡":
		if J.truthy((u as Dictionary).get("主武器已销毁")):
			return "本回合主武器已销毁（下个我方阶段初恢复）"
	if str((card as Dictionary).get("动作", "")) == "再来一把":
		var 再来因 := _再来一把不可打(ctx, u)
		if 再来因 != "":
			return 再来因
	var 上 := int(J.num0((card as Dictionary).get("每场次数")))
	if 上 > 0:
		var 用 = (u as Dictionary).get(每场次数键)
		var 已 := int(J.num0((用 as Dictionary).get(str(card.get("id"))))) if 用 is Dictionary else 0
		if 已 >= 上:
			return "每场次数已用完（%d/%d）" % [已, 上]
	if J.truthy((card as Dictionary).get("每场一次")):
		var 记 = (u as Dictionary).get(每场一次键)
		if 记 is Dictionary and J.truthy((记 as Dictionary).get(str(card.get("id")))):
			return "每场只能用 1 次（本场已经用过了）"
	var 冷 := 冷却Of(u, card)
	if 冷 > 0:
		return "冷却中（还剩 %d 个我方阶段）" % 冷
	if 类 == "大招槽卡":
		var 因 := 亮起原因(ctx, u, card)
		if 因 != "":
			return "亮起条件未满足：%s" % 因
		if J.same((u as Dictionary).get("v01不能打大招"), ctx.get("turn")):
			return "本回合被 W17·中继 再动过 → 不能再打大招"
	# [规范v0.3·断路器3]
	if str((card as Dictionary).get("动作", "")) == "W17中继":
		if W17候选(ctx, u).is_empty():
			return "受断路器 3 约束：本回合没有可再动的 ATX 友军（每台机体每回合限 1 次）"
	if J.num0((u as Dictionary).get("战意")) < AtxFaction.大招费用预览(ctx, card):
		return "战意不足（要 %d，现在 %d）" % [
			int(AtxFaction.大招费用预览(ctx, card)), int(J.num0((u as Dictionary).get("战意")))]
	return ""

static func 可用吗(ctx: Dictionary, u: Variant, card: Variant) -> bool:
	return 不可打原因(ctx, u, card) == ""

static func 满开禁主武器(u: Variant, ctx: Variant = null) -> bool:
	if not (u is Dictionary):
		return false
	var 记 = (u as Dictionary).get(满开禁主武器键)
	if 记 == null:
		return false
	var 本 := int(J.num0(记))
	if ctx is Dictionary:
		return 本 == int(J.num0((ctx as Dictionary).get("turn", 0)))
	return 本 > 0

static func _再来一把不可打(ctx: Dictionary, u: Variant) -> String:
	if not (u is Dictionary):
		return "没有这台机体"
	var 记 = (u as Dictionary).get(上次攻击键)
	if not (记 is Dictionary) or (记 as Dictionary).is_empty():
		return "本场还没打出过武器牌（或上一张已经重打过了）→ 没有可重打的段"
	var 段 := int(J.num0((记 as Dictionary).get("打空段")))
	if 段 <= 0:
		return "上一张武器牌一段都没打空 → 没有可重打的段"
	var 键 = (记 as Dictionary).get("目标")
	var t = Btl.找单位(ctx, 键, "enemy") if 键 != null else null
	if not (t is Dictionary) or float((t as Dictionary).get("hp", 0.0)) <= 0.0:
		return "上一张武器牌的原目标已被击破 → 没有可重打的对象"
	return ""

static func 上次打空段(u: Variant) -> int:
	if not (u is Dictionary) or not ((u as Dictionary).get(上次攻击键) is Dictionary):
		return 0
	return int(J.num0(((u as Dictionary).get(上次攻击键) as Dictionary).get("打空段")))

static func 援护待触发(ctx: Variant) -> Variant:
	if not (ctx is Dictionary):
		return null
	var 记 = (ctx as Dictionary).get(援护键)
	if not (记 is Dictionary):
		return null
	if int(J.num0((记 as Dictionary).get("回合", -1))) != int(J.num0((ctx as Dictionary).get("turn", 0))):
		return null
	return 记

static func 援护不生效原因(ctx: Variant, u: Variant, card: Variant, 目标: Variant) -> String:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (card is Dictionary):
		return ""
	if not 是艾克赛琳(u):
		return ""
	if str((card as Dictionary).get("id", "")) != "ATX2_D1":
		return ""
	var 记 = (ctx as Dictionary).get(援护键)
	if not (记 is Dictionary):
		return "本回合没打过【艾克赛琳，跟上】"
	if int(J.num0((记 as Dictionary).get("回合", -1))) != int(J.num0((ctx as Dictionary).get("turn", 0))):
		return "【艾克赛琳，跟上】只在本回合有效"
	if J.truthy((记 as Dictionary).get("已用")):
		return "本回合【艾克赛琳，跟上】的援护射击已经用掉了"
	var 键 = (记 as Dictionary).get("目标")
	if 键 == null:
		return "本回合响介还没打过武器牌 → 【艾克赛琳，跟上】还没接上"
	if not (目标 is Dictionary) or str((目标 as Dictionary).get("key", "")) != str(键):
		return "【艾克赛琳，跟上】只对她和响介打的那台目标生效"
	return ""

static func 援护生效(ctx: Variant, u: Variant, card: Variant, 目标: Variant) -> bool:
	if not (u is Dictionary) or not 是艾克赛琳(u):
		return false
	if not (card is Dictionary) or str((card as Dictionary).get("id", "")) != "ATX2_D1":
		return false
	return 援护不生效原因(ctx, u, card, 目标) == ""

static func 援护免次数(ctx: Variant, u: Variant, card: Variant) -> bool:
	if not (ctx is Dictionary) or not (u is Dictionary) or not (card is Dictionary):
		return false
	if not 是艾克赛琳(u):
		return false
	if str((card as Dictionary).get("id", "")) != "ATX2_D1":
		return false
	var 记 = 援护待触发(ctx)
	if not (记 is Dictionary):
		return false
	if J.truthy((记 as Dictionary).get("已用")):
		return false
	return (记 as Dictionary).get("目标") != null

static func 消费援护(ctx: Variant) -> void:
	if not (ctx is Dictionary) or not ((ctx as Dictionary).get(援护键) is Dictionary):
		return
	((ctx as Dictionary)[援护键] as Dictionary)["已用"] = true

static func 副武器门槛(ctx: Dictionary, u: Variant, 条目: Dictionary) -> Dictionary:
	if not 援护免次数(ctx, u, (条目 as Dictionary).get("卡")):
		return {"终局": false}
	return {"终局": true, "原因": ""}

static func 副武器援护(ctx: Variant, u: Variant, 卡: Variant, w: Dictionary, 目标: Variant) -> Dictionary:
	if not (w is Dictionary):
		return {"终局": false}
	var 弹种 := 援护弹种(w, 目标)
	if 弹种 != "":
		w["dmgType"] = 弹种伤害类型(弹种)
	var 吃 := 援护生效(ctx, u, 卡, 目标)
	if 吃:
		w["critMod"] = float(J.num0(w.get("critMod"))) + 30.0
	return {"终局": true, "弹种": 弹种, "援护吃": 吃}

static func 副武器攻击后(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 条目: Dictionary,
		援护敌: Variant, _结果: Variant, 援护吃: bool) -> void:
	if not 援护吃:
		return
	消费援护(ctx)
	Btl.pushLog(ctx, "〔艾克赛琳，跟上〕%s 对 %s 的援护射击：暴击 +30、不算消耗次数（本回合已用 %d/%d）" % [
		str(u.get("name", "")), str((援护敌 as Dictionary).get("name", "")) if 援护敌 is Dictionary else "目标",
		int(条目.get("本回合已用", 0)), int(条目.get("本回合可用", 1))],
		J.merged({"类型": "援护跟上", "单位": u.get("key"), "卡牌ID": 卡.get("id"),
			"卡牌": 卡.get("名"), "暴击加": 30.0, "不算次数": true,
			"本回合已用": int(条目.get("本回合已用", 0)),
			"本回合可用": int(条目.get("本回合可用", 1))}, Btl.谁(u)))

static func 冷却Of(u: Variant, card: Variant) -> int:
	if not (u is Dictionary) or not (card is Dictionary):
		return 0
	var 冷 = (u as Dictionary).get(冷却键)
	if not (冷 is Dictionary):
		return 0
	return int(J.num0((冷 as Dictionary).get(str((card as Dictionary).get("id", "")))))

static func _设冷却(u: Dictionary, card: Dictionary, 值: float) -> void:
	if not (u.get(冷却键) is Dictionary):
		u[冷却键] = {}
	if 值 <= 0.0:
		return
	(u[冷却键] as Dictionary)[str(card.get("id", ""))] = int(J.round(值))

static func 亮起原因(ctx: Dictionary, u: Variant, card: Variant) -> String:
	if not (card is Dictionary):
		return "没有这张牌"
	var 条 = (card as Dictionary).get("亮起")
	if not (条 is Dictionary):
		return ""
	return _条件不满足原因(ctx, u, 条)

static func _条件不满足原因(ctx: Dictionary, u: Variant, 条: Dictionary) -> String:
	match str(条.get("类型", "")):
		"第N回合":
			if float(ctx.get("turn", 1.0)) < float(J.num0(条.get("阈值"))):
				return "第 %d 回合起（现在第 %d 回合）" % [int(J.num0(条.get("阈值"))), int(ctx.get("turn", 1))]
			return ""
		"有烟雾":
			return "" if AtxSmoke.有雾吗(ctx) else "场上有烟雾才亮"
		"在前排":
			return "" if Fm.是前排有效(u, ctx) else "要站到前排（或在顶位）"
		"全部":
			for 子 in J.or_(条.get("们"), []):
				if 子 is Dictionary:
					var 因 := _条件不满足原因(ctx, u, 子)
					if 因 != "":
						return 因
			return ""
	return ""

# ---- 六、出牌与武器攻击 ----
static func 武器栏打出(ctx: Dictionary, u: Dictionary, card: Variant, target_id: Variant = null) -> Dictionary:
	if not (u is Dictionary) or not (card is Dictionary):
		return {"击破": 0.0}
	var 靶 = Btl._存活敌(ctx, u, target_id)
	var 结果 := _打武器牌(ctx, u, card, 靶)
	return 武器栏打出后收尾(ctx, u, card, 靶, 结果)

static func 武器栏打出后收尾(ctx: Dictionary, u: Dictionary, card: Variant, _目标: Variant, 攻击结果: Variant) -> Dictionary:
	var 出: Dictionary = 攻击结果 if 攻击结果 is Dictionary else {"击破": 0.0}
	if not (ctx is Dictionary) or not (u is Dictionary) or not (card is Dictionary):
		return 出
	_记次数与冷却(u, card)
	AtxLuck.打出时(ctx, u, card)
	AtxChips.打出后赌局(ctx, u, card)
	return 出

static func _记次数与冷却(u: Dictionary, card: Dictionary) -> void:
	var 类 := str(card.get("卡类", ""))
	if 类 == "大招槽卡":
		_设冷却(u, card, J.num0(card.get("冷却")))
	if J.num0(card.get("每场次数")) > 0:
		if not (u.get(每场次数键) is Dictionary):
			u[每场次数键] = {}
		var 用: Dictionary = u[每场次数键]
		用[str(card.get("id"))] = int(J.num0(用.get(str(card.get("id"))))) + 1
	if J.truthy(card.get("每场一次")):
		if not (u.get(每场一次键) is Dictionary):
			u[每场一次键] = {}
		(u[每场一次键] as Dictionary)[str(card.get("id"))] = true

static func 打出牌(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant = null) -> Dictionary:
	var 因 := CardPlay.不可打原因(ctx, u, card, CardPlay.区_精神)
	if 因 != "":
		return {"成功": false, "原因": 因}
	var 类 := str(card.get("卡类", ""))
	var 费 := AtxFaction.大招实际费用(ctx, card) if 类 == "大招槽卡" else J.num0(card.get("耗气"))
	u["战意"] = maxf(0.0, J.num0(u.get("战意")) - 费)
	ctx["_当前出牌者"] = u.get("key")
	ctx["_当前目标"] = target_id
	var 靶 = Btl._存活敌(ctx, u, target_id)
	AtxSmoke.打出时(ctx, u, card, 靶)
	var 结果 := {"击破": 0.0}
	var 摘要: Array = []
	if 类 == "主武器卡" or 类 == "副武器卡":
		结果 = _打武器牌(ctx, u, card, 靶)
		if 类 == "主武器卡":
			u["主武器已销毁"] = true
	elif 类 == "大招槽卡":
		结果 = _打大招(ctx, u, card, 靶)
	else:
		摘要 = CardEffects.execute(ctx, card)
	if 类 == "主武器卡" or 类 == "大招槽卡":
		AtxFaction.攻击后二次下注(ctx, u, card)
	AtxFaction.记打出大招(ctx, card, u)
	AtxLuck.打出时(ctx, u, card)
	_记次数与冷却(u, card)
	var 从槽 := 找别名槽(u, card)
	var 从栏 := false
	for x in J.or_(u.get("武器栏"), []):
		if x is Dictionary and is_same(x, card):
			从栏 = true
			break
	var 手: Array = J.or_(u.get("专属手牌"), [])
	var 留: Array = []
	for c in 手:
		if is_same(c, card):
			continue
		留.append(c)
	u["专属手牌"] = 留
	if not 从槽.is_empty():
		从槽["本回合已打"] = true
		同步大招槽(u)
	elif 从栏:
		pass
	elif not J.truthy(card.get("每场一次")):
		if not (u.get("专属弃牌堆") is Array):
			u["专属弃牌堆"] = []
		(u["专属弃牌堆"] as Array).append(card)
	else:
		if not (ctx.get("移出牌") is Array):
			ctx["移出牌"] = []
		(ctx["移出牌"] as Array).append(card)
	AtxChips.打出后赌局(ctx, u, card)
	Btl.pushLog(ctx, "〔A6c〕%s 打出【%s】（战意 -%s，剩 %s%s）%s" % [
		str(u.get("name", "")), str(card.get("名", "")), J.s(费), J.s(u.get("战意")),
		"；主武器本回合销毁" if J.truthy(u.get("主武器已销毁")) else "", Btl.效果摘要文(摘要)],
		J.merged({"类型": "A6c出牌", "单位": u.get("key"), "卡牌ID": card.get("id"),
			"卡牌": card.get("名"), "卡类": 类, "战意": u.get("战意"),
			"效果摘要": 摘要,
			"主武器已销毁": J.truthy(u.get("主武器已销毁"))}, Btl.谁(u)))
	Btl.刷新敌方意图(ctx)
	return {"成功": true, "卡牌": str(card.get("名", "")), "战意": J.num0(u.get("战意")),
		"费用": 费, "目标": Btl.目标名Of(结果), "击破": J.num0(结果.get("击破")),
		"摘要": 摘要, "主武器已销毁": J.truthy(u.get("主武器已销毁"))}

static func 抗性分(t: Variant, 伤害类型: String, 基武器: Variant) -> float:
	if not (t is Dictionary):
		return 0.0
	var w: Dictionary = (基武器 as Dictionary).duplicate(true) if 基武器 is Dictionary else {}
	w["dmgType"] = 伤害类型
	var 和 := 0.0
	for e in Calc.weakList(t, w, {}):
		if e is Array and (e as Array).size() >= 2:
			和 += float(J.num0((e as Array)[1]))
	return 和

## 带 `变体 = ["光束","实弹"]` 的武器按目标抗性自动选最优弹种。
static func 援护弹种(w: Variant, t: Variant) -> String:
	if not (w is Dictionary):
		return ""
	var 变 = (w as Dictionary).get("变体")
	if not (变 is Array) or (变 as Array).size() < 2:
		return ""
	if not ((变 as Array).has("光束") and (变 as Array).has("实弹")):
		return ""
	if not (t is Dictionary):
		return "光束"
	var 光 := 抗性分(t, "光束", w)
	var 物 := 抗性分(t, "物理", w)
	return "实弹" if 光 < 物 else "光束"

static func 弹种伤害类型(弹种: String) -> String:
	return "物理" if 弹种 == "实弹" else "光束"

static func _打武器牌(ctx: Dictionary, u: Dictionary, card: Dictionary, 靶: Variant) -> Dictionary:
	var w0 = card.get("武器")
	if not (w0 is Dictionary) or (w0 as Dictionary).is_empty():
		return {"击破": 0.0}
	var w: Dictionary = (w0 as Dictionary).duplicate(true)
	if w.get("分段") is Array:
		var 表 := 段威力表(w)
		if not 表.is_empty():
			w["段威力"] = 表
			w["hits"] = float(表.size())
			w["special"] = "multi"
			w["power"] = float(表[0])
	w = _应用下一张(u, w)
	var 改写 := AtxRewrite.应用(ctx, u, w)
	if J.truthy(改写.get("生效")):
		w = 改写["武器"]
	if J.truthy(u.get("v01无视遮挡本回合")):
		w["无视遮挡"] = true
	var 倍 := float(J.num0(u.get("v01本次伤害倍率")))
	u.erase("v01本次伤害倍率")
	if 倍 <= 0.0:
		倍 = 1.0
	if 靶 == null or not (靶 is Dictionary):
		Btl.pushLog(ctx, "〔A6c〕%s【%s】没有可打的目标" % [str(u.get("name", "")), str(card.get("名", ""))],
			J.merged({"类型": "A6c攻击", "单位": u.get("key"), "卡牌": card.get("id"),
				"结果": "无目标"}, Btl.谁(u)))
		return {"击破": 0.0}
	return _贯穿打(ctx, u, card, w, 靶, 倍)

static func _贯穿打(ctx: Dictionary, u: Dictionary, card: Dictionary, w: Dictionary,
	靶: Dictionary, 伤害倍率: float) -> Dictionary:
	var 目标们: Array = [靶]
	if J.truthy(w.get("贯穿列")):
		var 同列 = _同列另一排(ctx, 靶)
		if 同列 != null:
			目标们.append(同列)
	var 击破 := 0.0
	for t in 目标们:
		if float((t as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 可达 := Reach.武器可达吗(ctx, u, w, t)
		if not J.truthy(可达.get("ok")) and not is_same(t, 靶):
			continue
		var 罚 := _被挡罚(ctx, u, t, w)
		var 本w: Dictionary = w
		if 伤害倍率 != 1.0:
			本w = w.duplicate(true)
			if 本w.get("段威力") is Array:
				var 新段: Array = []
				for v in 本w["段威力"]:
					新段.append(J.round(float(J.num0(v)) * 伤害倍率))
				本w["段威力"] = 新段
				本w["power"] = float(本w["段威力"][0])
			else:
				本w["power"] = float(本w.get("power", 0.0)) * 伤害倍率
		var 前 := float((t as Dictionary).get("hp", 0.0))
		var 结算: Dictionary = Flow.结算一个目标(ctx, u, t, 本w,
			{"改目标": false, "blockPenalty": 罚, "不写标准攻击日志": true, "旁路攻击": true})
		var rec: Dictionary = 结算.rec
		_记攻击(ctx, str(card.get("名", "")), card, u, t, rec,
			{"主目标": is_same(t, 靶), "贯穿列": J.truthy(w.get("贯穿列"))})
		if is_same(t, 靶) and 是响介(u):
			_记上次攻击(ctx, u, t, 本w, rec)
		if 前 > 0.0 and float((t as Dictionary).get("hp", 0.0)) <= 0.0:
			击破 += 1.0
	if J.truthy(card.get("自爆")):
		_自爆收尾(ctx, u, card)
	return {"击破": 击破, "目标": (靶 as Dictionary).get("key")}

static func _同列另一排(ctx: Dictionary, t: Dictionary) -> Variant:
	if t.get("slot") == null:
		return null
	var 位 := Fm.另一排同位(t.get("slot"))
	if 位 < 0:
		return null
	for e in Units.livingOf(str(t.get("side", "enemy")), ctx):
		if int((e as Dictionary).get("slot", -1)) == 位:
			return e
	return null

static func _被挡罚(ctx: Dictionary, 攻: Variant, t: Variant, w: Dictionary) -> float:
	if not (t is Dictionary) or (t as Dictionary).get("slot") == null:
		return 0.0
	var kind = Reach.rangeKindOf(w)
	if kind != Reach.KIND_DIRECT():
		return 0.0
	if Reach.无视遮挡(w):
		return 0.0
	var 活位: Array = Units.livingOf("enemy", ctx).map(func(x): return (x as Dictionary).slot)
	return Reach.rowBlockPenalty(kind, (t as Dictionary).get("slot"), 活位, 攻, t)

static func _记攻击(ctx: Dictionary, 牌名: String, card: Dictionary, 攻: Dictionary,
	t: Dictionary, rec: Dictionary, 额外: Dictionary = {}) -> void:
	var 字段: Dictionary = J.merged(J.merged({
		"类型": "攻击", "单位": 攻.get("key"), "武器": 牌名,
		"战术牌": card.get("id"), "目标": t.get("key"),
	}, Btl.谁(攻)), Btl.谁目标(t))
	字段 = J.merged(字段, rec.get("字段"))
	字段 = J.merged(字段, 额外)
	Btl.pushLog(ctx, "〔%s〕%s → %s：%s" % [牌名, str(攻.get("name", "")), str(t.get("name", "")), rec.get("文本")], 字段)
	_计数加(ctx, "攻击", 1)

static func _记上次攻击(ctx: Dictionary, u: Dictionary, t: Dictionary, w: Dictionary, rec: Dictionary) -> void:
	var 字段: Dictionary = rec.get("字段") if rec.get("字段") is Dictionary else {}
	var 段 := int(J.num0(字段.get("段数")))
	if 段 <= 0:
		段 = int(J.num0(w.get("hits"))) if J.num0(w.get("hits")) > 0.0 else 1
	var 中 := int(J.num0(字段.get("命中段数")))
	if 中 < 0:
		中 = 0
	if 中 > 段:
		中 = 段
	var 单威 := float(J.num0(w.get("power")))
	var 段威 = w.get("段威力")
	if 段威 is Array and not (段威 as Array).is_empty():
		var 和 := 0.0
		for v in 段威:
			和 += float(J.num0(v))
		单威 = 和 / float((段威 as Array).size())
	u[上次攻击键] = {
		"回合": int(J.num0(ctx.get("turn", 1))), "目标": (t as Dictionary).get("key"),
		"段数": 段, "命中段数": 中, "打空段": maxi(0, 段 - 中),
		"单段威力": 单威, "命中": float(J.num0(w.get("hit", 100.0))),
		"近战": str(w.get("fire", "")) == "melee",
		"伤害类型": str(w.get("dmgType", "物理")),
		"武器": str(w.get("name", "")),
	}

static func _自爆收尾(ctx: Dictionary, u: Dictionary, card: Dictionary) -> void:
	var 比 := float(J.num0(card.get("残HP比")))
	if 比 <= 0.0:
		比 = 自爆残HP比
	var 前 := float(u.get("hp", 0.0))
	var 后 := maxf(1.0, J.round(float(u.get("maxHp", 0.0)) * 比))
	u["hp"] = 后
	u["下阶段销毁武器"] = str(card.get("名", "Code：ATA"))
	Btl.pushLog(ctx, "〔%s〕%s 自爆突击：HP %s → %s（%d%%）；下个我方阶段她的武器牌全部销毁" % [
		str(card.get("名", "")), str(u.get("name", "")), J.s(J.round(前)), J.s(J.round(后)), int(比 * 100.0)],
		J.merged({"类型": "自爆突击", "单位": u.get("key"), "HP前": J.round(前), "HP后": J.round(后),
			"残HP比": 比, "下阶段销毁武器": true}, Btl.谁(u)))

static func _应用下一张(u: Dictionary, w: Dictionary) -> Dictionary:
	var 记 = u.get(下一张键)
	if not (记 is Dictionary) or (记 as Dictionary).is_empty():
		return w
	var 新: Dictionary = w.duplicate(true)
	var 命中 := J.num0((记 as Dictionary).get("命中"))
	var 暴击 := J.num0((记 as Dictionary).get("暴击"))
	var 伤害 := J.num0((记 as Dictionary).get("伤害"))
	if 命中 != 0.0:
		新["hit"] = float(新.get("hit", 100.0)) + 命中
	if 暴击 != 0.0:
		新["critMod"] = float(J.num0(新.get("critMod"))) + 暴击
	if 伤害 != 0.0:
		新["power"] = float(J.num0(新.get("power"))) * (1.0 + 伤害)
	if J.truthy((记 as Dictionary).get("无视遮挡")):
		新["无视遮挡"] = true
	if J.num0((记 as Dictionary).get("距离上限加")) > 0.0:
		var 界 := Reach.武器距离(新)
		新["range"] = [float(界.x), float(界.y + int(J.num0((记 as Dictionary).get("距离上限加"))))]
	u.erase(下一张键)
	return 新

# ---- 七、大招的三种特殊打法 ----
static func _打大招(ctx: Dictionary, u: Dictionary, card: Dictionary, 靶: Variant) -> Dictionary:
	if str(card.get("动作", "")) == "好运加护满开":
		return _满开(ctx, u, card)
	if int(J.num0(card.get("多锁"))) > 0:
		return _多锁(ctx, u, card, 靶)
	if J.truthy(card.get("切札")):
		return _切札(ctx, u, card, 靶)
	return _打武器牌(ctx, u, card, 靶)

static func _多锁(ctx: Dictionary, u: Dictionary, card: Dictionary, _靶: Variant) -> Dictionary:
	var 上限 := maxi(1, int(J.num0(card.get("多锁"))))
	var w0 = card.get("武器")
	var w: Dictionary = (w0 as Dictionary).duplicate(true) if w0 is Dictionary else {}
	if w.is_empty():
		return {"击破": 0.0}
	var 候选: Array = []
	for e in Units.livingOf("enemy", ctx):
		if float((e as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		if J.truthy(Reach.武器可达吗(ctx, u, w, e).get("ok")):
			候选.append(e)
	候选 = J.sort_num(候选.map(func(x): return (x as Dictionary).get("slot")))
	var 选: Array = []
	for 位 in 候选:
		for e in Units.livingOf("enemy", ctx):
			if int((e as Dictionary).get("slot", -1)) == int(位):
				选.append(e)
				break
		if 选.size() >= 上限:
			break
	var 击破 := 0.0
	for t in 选:
		var 前 := float(t.get("hp", 0.0))
		var 结算: Dictionary = Flow.结算一个目标(ctx, u, t, w,
			{"改目标": false, "blockPenalty": 0.0, "不写标准攻击日志": true, "旁路攻击": true})
		var rec: Dictionary = 结算.rec
		_记攻击(ctx, str(card.get("名", "")), card, u, t, rec, {"多锁": true, "锁台上限": 上限})
		var 字段: Dictionary = rec.get("字段") if rec.get("字段") is Dictionary else {}
		if 前 > 0.0 and float(t.get("hp", 0.0)) <= 0.0 and float(字段.get("伤害", 0.0)) > 0.0:
			击破 += 1.0
	var 暴 := float(J.num0(card.get("暴击X")))
	if 暴 != 0.0:
		Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), {"critX": 暴, "剩余": 1.0})
	Btl.pushLog(ctx, "〔%s〕%s 多重锁定 %d 台（上限 %d）；本回合暴击倍率 +%s" % [
		str(card.get("名", "")), str(u.get("name", "")), 选.size(), 上限, J.s(暴)],
		J.merged({"类型": "多锁", "单位": u.get("key"), "锁台数": 选.size(), "锁台上限": 上限,
			"暴击X": 暴}, Btl.谁(u)))
	return {"击破": 击破, "目标": (选[0] as Dictionary).get("key") if not 选.is_empty() else null}

## 【切札】：三连机炮（5 段）+ 方形钢弹（8 段）+ 左轮打桩机·全弹（12 段）合成 25 段攻击，按各自射程跳过不可达段。
static func _切札(ctx: Dictionary, u: Dictionary, card: Dictionary, 靶: Variant) -> Dictionary:
	if 靶 == null or not (靶 is Dictionary):
		return {"击破": 0.0}
	var 倍 := float(J.num0(card.get("段倍率")))
	if 倍 <= 0.0:
		倍 = 切札段倍率
	var 段们 := [
		{"w": _武("三连机炮", "direct", "物理", 300, 5, 80, [1, 3], "射击"), "段数": 5, "威力": 300.0},
		{"w": _武("方形钢弹", "direct", "物理", 250, 8, 75, [1, 2], "射击"), "段数": 8, "威力": 250.0},
		{"w": _近战("左轮打桩机·全弹", 500, 12, 75, [1, 2], {"critMod": 20.0}), "段数": 12, "威力": 500.0},
	]
	var 威力表: Array = []
	var 命中表: Array = []
	var 跳过: Array = []
	var 总段 := 0
	for e in 段们:
		var ww: Dictionary = e["w"]
		if not J.truthy(Reach.武器可达吗(ctx, u, ww, 靶).get("ok")):
			跳过.append(str(ww.get("name", "")))
			continue
		for _i in int(e["段数"]):
			威力表.append(J.round(float(e["威力"]) * 倍))
			命中表.append(ww)
			总段 += 1
	if 总段 <= 0:
		Btl.pushLog(ctx, "〔切札〕%s 三段都打不到 %s（跳过全部 25 段）" % [
			str(u.get("name", "")), str((靶 as Dictionary).get("name", ""))],
			J.merged({"类型": "切札", "单位": u.get("key"), "段数": 0}, Btl.谁(u)))
		return {"击破": 0.0}
	var w: Dictionary = _武("切札", "melee", "物理", 威力表[0], 1, 75, [1, 6], "格斗")
	w["hits"] = float(总段)
	w["special"] = "multi"
	w["段威力"] = 威力表
	w["critMod"] = 20.0
	var 前 := float((靶 as Dictionary).get("hp", 0.0))
	var 结算: Dictionary = Flow.结算一个目标(ctx, u, 靶, w,
		{"改目标": false, "blockPenalty": 0.0, "不写标准攻击日志": true, "旁路攻击": true})
	var rec: Dictionary = 结算.rec
	_记攻击(ctx, "切札", card, u, 靶, rec, {"切札": true, "段数": 总段,
		"每段倍率": 倍, "跳过的武器": 跳过})
	var 字段: Dictionary = rec.get("字段") if rec.get("字段") is Dictionary else {}
	var 击破 := 0.0
	if 前 > 0.0 and float((靶 as Dictionary).get("hp", 0.0)) <= 0.0 and float(字段.get("伤害", 0.0)) > 0.0:
		击破 = 1.0
	return {"击破": 击破, "目标": (靶 as Dictionary).get("key")}

static func _满开(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Dictionary:
	var 暴 := float(J.num0(card.get("暴击X")))
	if 暴 == 0.0:
		暴 = 满开暴击X
	var 命中 := float(J.num0(card.get("命中惩罚")))
	if 命中 == 0.0:
		命中 = 满开命中
	var 源 := "卡牌:%s:满开" % str(card.get("id"))
	var 名们: Array = []
	for a in Units.livingOf("ally", ctx):
		if not FacAtx._是ATX(a):
			continue
		Btl.换同源增益(a, 源, {"critX": 暴, "hit": 命中, "剩余": 1.0})
		名们.append(str((a as Dictionary).get("name", "")))
	u[满开禁主武器键] = int(J.num0(ctx.get("turn", 1)))
	Btl.pushLog(ctx, "〔%s〕ATX 全体（%d 台）到下个我方阶段前：暴击倍率 +%s、每段命中 %s；代价：她本回合不能打主武器" % [
		str(card.get("名", "")), 名们.size(), J.s(暴), J.s(命中)],
		J.merged({"类型": "满开", "单位": u.get("key"), "台数": 名们.size(),
			"critX": 暴, "hit": 命中, 满开禁主武器键: int(J.num0(ctx.get("turn", 1)))}, Btl.谁(u)))
	return {"击破": 0.0}

static func _满开算子(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	_满开(ctx, u, card)
	return ["ATX 全体：暴击倍率 +1、每段命中 −20"]

# ---- 八、精神牌与关键词算子 ----
static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx = 运行.get("ctx")
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	if not (ctx is Dictionary):
		return []
	var u = _施放者(运行)
	if u == null:
		return ["【%s】没有能出手的 ATX 成员" % str(card.get("名", ""))]
	match 动作:
		"下一张武器": return _下一张武器(ctx, u, 表, card)
		"孤注一掷": return _孤注一掷(ctx, u, card)
		"硬接": return _buff自身(ctx, u, card, {"受伤Mul": -0.30, "eva": -100.0}, "受到的伤害 −30%、闪避归零")
		"全速突击": return _全速突击(ctx, u, card)
		"再来一把": return _再来一把(ctx, u, card)
		"还没输呢": return _还没输呢(ctx, u, card)
		"艾克赛琳跟上": return _艾克赛琳跟上(ctx, u, card)
		"俄罗斯轮盘": return _俄罗斯轮盘(ctx, u, card)
		"押上全部": return _押上全部(ctx, u, card)
		"好运加护": return _好运加护(ctx, u, 表, card)
		"眨眼": return _眨眼(ctx, u, card)
		"打不中哦": return _buff自身(ctx, u, card, {"eva": 20.0}, "闪避 +20")
		"闪避": return _buff自身(ctx, u, card, {"eva": float(J.num0(表.get("值")))}, "闪避 +%s" % J.s(表.get("值")))
		"高空回避": return _高空回避(ctx, u, card)
		"响介交给你了": return _响介交给你了(ctx, u, card)
		"抗光束换实弹": return _抗光束换实弹(ctx, u, card)
		"Excellent": return _excellent(ctx, u, card)
		"好运连连": return _好运连连(ctx, u, card)
		"抽牌": return _抽牌(ctx, u, 表)
		"战意": return _加战意(ctx, u, 表, card)
		"回血": return _回血(ctx, u, 表, card)
		"烟幕扩散": return _烟幕扩散(ctx, u, card)
		"死角射击": return _死角射击(ctx, u, card)
		"W17中继": return _w17中继(ctx, u, card, 运行)
		"自我修复": return _回血(ctx, u, {"比": 0.20}, card)
		"语言回路故障": return _语言回路故障(ctx, u, card)
		"追加段": return _追加段(ctx, u, 表, card)
		"光环": return _光环(ctx, u, 表, card)
		"本次伤害倍率": return _本次伤害倍率(ctx, u, 表)
		"好运加护满开": return _满开算子(ctx, u, card)
	push_error("AtxThree：未知的动作「%s」" % 动作)
	return []

static func _施放者(运行: Dictionary) -> Variant:
	var ctx = 运行.get("ctx")
	if not (ctx is Dictionary):
		return null
	var 键 := str((ctx as Dictionary).get("_当前出牌者", ""))
	if 键 != "":
		var u = Btl.找单位(ctx, 键, "ally")
		if u is Dictionary:
			return u
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 角 := str(card.get("角色", ""))
	if 角 != "":
		for a in J.or_((ctx as Dictionary).get("allies"), []):
			if a is Dictionary and float((a as Dictionary).get("hp", 0.0)) > 0.0 and _键Of(a) == 角:
				return a
	return null

static func _友军(ctx: Dictionary, u: Dictionary, 表: Dictionary) -> Variant:
	var 指定 = (ctx as Dictionary).get("_当前目标")
	var t = Btl.找单位(ctx, 指定, "ally")
	if t is Dictionary and not is_same(t, u):
		return t
	var 们: Array = Units.livingOf("ally", ctx).filter(func(a): return not is_same(a, u))
	if 们.is_empty():
		return null
	J.sort(们, func(a, b):
		var d := _血比(a) - _血比(b)
		return d if d != 0.0 else float((a as Dictionary).get("slot", 0.0)) - float((b as Dictionary).get("slot", 0.0)))
	return 们[0]

static func _血比(u: Variant) -> float:
	var 上 := float((u as Dictionary).get("maxHp", 0.0))
	if 上 <= 0.0:
		return 0.0
	return float((u as Dictionary).get("hp", 0.0)) / 上

static func _记(ctx: Dictionary, 牌名: String, u: Variant, 文: String, 额外: Dictionary = {}) -> void:
	Btl.pushLog(ctx, "〔%s〕%s：%s" % [牌名, str((u as Dictionary).get("name", "")), 文],
		J.merged(J.merged({"类型": 牌名, "单位": (u as Dictionary).get("key"), "回合": ctx.get("turn")},
			Btl.谁(u)), 额外))

static func _下一张武器(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 增 = J.or_(表.get("增益"), {})
	if not (增 is Dictionary) or (增 as Dictionary).is_empty():
		return []
	var 记: Dictionary = (u.get(下一张键) as Dictionary).duplicate(true) if u.get(下一张键) is Dictionary else {}
	for k in (增 as Dictionary).keys():
		记[k] = float(J.num0(记.get(k))) + float(J.num0((增 as Dictionary)[k]))
	u[下一张键] = 记
	_记(ctx, str(card.get("名", "")), u, "下一张武器牌 %s" % str(记))
	return ["下一张武器牌：%s" % str(记)]

static func _孤注一掷(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), {"eva": 30.0, "剩余": 1.0})
	var 代价 := float(J.num0(card.get("命中代价")))
	if 代价 == 0.0:
		代价 = -10.0
	Btl.换同源增益(u, "卡牌:%s:代价" % str(card.get("id")), {"hit": 代价, "剩余": 1.0})
	u["v01孤注一掷"] = int(ctx.get("turn", 1))
	u["v01孤注每段战意"] = 1
	u["v01孤注上限"] = 8
	_记(ctx, "孤注一掷", u, "闪避 +30、每被敌人打空 1 段战意 +1（最多 +8）、本回合命中 %s" % J.s(代价))
	return ["孤注一掷：闪避 +30"]

static func _buff自身(ctx: Dictionary, u: Dictionary, card: Dictionary, 增益: Dictionary, 文: String) -> Array:
	var b: Dictionary = 增益.duplicate(true)
	if b.get("剩余") == null:
		b["剩余"] = 1.0
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), b)
	_记(ctx, str(card.get("名", "")), u, 文)
	return [文]

static func _全速突击(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), {"meleeDmgMul": 0.20, "剩余": 1.0})
	Btl.换同源增益(u, "卡牌:%s:代价" % str(card.get("id")), {"受伤Mul": 0.15, "剩余": 1.0})
	var 记: Dictionary = (u.get(下一张键) as Dictionary).duplicate(true) if u.get(下一张键) is Dictionary else {}
	记["距离上限加"] = 1.0
	u[下一张键] = 记
	_记(ctx, "全速突击", u, "近战伤害 +20%、近战距离上限 +1；到下个我方阶段前受到的伤害 +15%")
	return ["全速突击：近战伤害 +20%、距离上限 +1"]

static func _再来一把(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 因 := _再来一把不可打(ctx, u)
	if 因 != "":
		_记(ctx, "再来一把", u, "%s → 打不出去" % 因)
		return ["再来一把：%s" % 因]
	var 记: Dictionary = (u[上次攻击键] as Dictionary).duplicate(true)
	u.erase(上次攻击键)
	var 段 := int(J.num0(记.get("打空段")))
	var t = Btl.找单位(ctx, 记.get("目标"), "enemy")
	if not (t is Dictionary) or float((t as Dictionary).get("hp", 0.0)) <= 0.0:
		_记(ctx, "再来一把", u, "原目标已被击破 → 不重打")
		return ["再来一把：原目标已被击破，跳过"]
	var 单威 := float(J.num0(记.get("单段威力"))) * 0.5
	var w := {
		"name": 重打牌名, "fire": "melee" if J.truthy(记.get("近战")) else "direct",
		"dmgType": str(记.get("伤害类型", "物理")), "power": 单威,
		"hit": float(J.num0(记.get("命中", 100.0))), "critMod": 0.0,
		"stat": "射击", "cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
	}
	if 段 > 1:
		w["hits"] = float(段)
		w["special"] = "multi"
	var 前 := float((t as Dictionary).get("hp", 0.0))
	var 罚 := _被挡罚(ctx, u, t, w)
	var 结算: Dictionary = Flow.结算一个目标(ctx, u, t, w,
		{"改目标": false, "blockPenalty": 罚, "不写标准攻击日志": true, "旁路攻击": true})
	var rec: Dictionary = 结算.rec
	_记攻击(ctx, 重打牌名, card, u, t, rec,
		{"再来一把": true, "重打段": 段, "单段威力": J.round(单威),
			"原武器": str(记.get("武器", "")), "原段数": int(J.num0(记.get("段数")))})
	var 击破 := 0.0
	if 前 > 0.0 and float((t as Dictionary).get("hp", 0.0)) <= 0.0:
		击破 = 1.0
	u["连续攻击已用"] = true
	_记(ctx, "再来一把", u, "【%s】打空的 %d 段重打一次（每段 %s × 50%% = %s）；本回合不能用连续攻击" % [
		str(记.get("武器", "")), 段, J.s(J.round(float(J.num0(记.get("单段威力"))))), J.s(J.round(单威))],
		{"重打段": float(段), "单段威力": J.round(单威), "重打伤害": J.num0(rec.get("字段", {}).get("伤害")),
			"重打命中段": J.num0(rec.get("字段", {}).get("命中段数")), "目标": (t as Dictionary).get("key"),
			"连续攻击已用": true, "击破": 击破})
	return ["再来一把：重打 %d 段（每段 %s）" % [段, J.s(J.round(单威))]]

static func _还没输呢(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.加战意(u, 30.0, ctx, "还没输呢")
	ctx["v01赌神门槛无视"] = int(ctx.get("turn", 1))
	_记(ctx, "还没输呢", u, "战意 +30；本回合「赌神·入局」无视战意门槛（每场 1 次，本场已移出）",
		{"战意": u.get("战意")})
	return ["还没输呢：战意 +30"]

static func _艾克赛琳跟上(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 艾 = null
	for a in Units.livingOf("ally", ctx):
		if 是艾克赛琳(a):
			艾 = a
			break
	if 艾 == null:
		_记(ctx, "艾克赛琳跟上", u, "艾克赛琳不在场")
		return ["艾克赛琳不在场"]
	ctx[援护键] = {"回合": int(J.num0(ctx.get("turn", 1))), "目标": null, "已用": false}
	_记(ctx, "艾克赛琳跟上", 艾, "本回合响介攻击后，她对**同一目标**的援护射击：暴击 +30、不算消耗次数")
	return ["艾克赛琳跟上：援护射击 暴击 +30、不算消耗次数"]

static func _俄罗斯轮盘(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var rng = ctx.get("rng")
	if rng == null:
		return ["俄罗斯轮盘：没有随机数源"]
	var 点 := int(floorf(float(rng.next_float()) * 6.0)) + 1
	if 点 == 1:
		var 伤 := J.round(float(u.get("maxHp", 0.0)) * 0.15)
		u["hp"] = maxf(0.0, float(u.get("hp", 0.0)) - 伤)
		_记(ctx, "俄罗斯轮盘", u, "掷出 1 → 受到自身最大 HP 15% 的伤害（%s）" % J.s(伤),
			{"点数": 点, "自伤": 伤})
		return ["俄罗斯轮盘：掷出 1，自伤 %s" % J.s(伤)]
	var 加 := 5.0 * float(点)
	Btl.加战意(u, 加, ctx, "俄罗斯轮盘")
	_记(ctx, "俄罗斯轮盘", u, "掷出 %d → 战意 +%s" % [点, J.s(加)], {"点数": 点, "战意加": 加})
	return ["俄罗斯轮盘：掷出 %d，战意 +%s" % [点, J.s(加)]]

static func _押上全部(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 战 := J.num0(u.get("战意"))
	var 步 := int(floorf(战 / 10.0))
	var 加 := minf(0.5, float(步) * 0.05)
	var 记: Dictionary = (u.get(下一张键) as Dictionary).duplicate(true) if u.get(下一张键) is Dictionary else {}
	记["伤害"] = float(J.num0(记.get("伤害"))) + 加
	u[下一张键] = 记
	u["战意"] = 0.0
	_记(ctx, "押上全部", u, "下一张武器牌伤害 +%d%%（战意 %d）；打完后战意清零" % [int(加 * 100.0), int(战)])
	return ["押上全部：下一张武器牌伤害 +%d%%" % int(加 * 100.0)]

static func _好运加护(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 命中 := float(J.num0(card.get("命中惩罚")))
	if 命中 == 0.0:
		命中 = 好运加护命中
	var 次 := 2 if J.truthy(表.get("额外一台")) else 1
	var 名们: Array = []
	var 们: Array = Units.livingOf("ally", ctx).filter(func(a): return not is_same(a, u))
	J.sort(们, func(a, b):
		var d := _血比(a) - _血比(b)
		return d if d != 0.0 else float((a as Dictionary).get("slot", 0.0)) - float((b as Dictionary).get("slot", 0.0)))
	for i in mini(次, 们.size()):
		var t: Dictionary = 们[i]
		Btl.换同源增益(t, "卡牌:%s" % str(card.get("id")), {"critX": 好运加护暴击X, "hit": 命中, "剩余": 1.0})
		名们.append(str(t.get("name", "")))
	_记(ctx, "好运加护", u, "指定 %d 台友军：暴击倍率 +1、每段命中 %s（%s）" % [
		名们.size(), J.s(命中), "、".join(名们)], {"目标们": 名们, "hit": 命中})
	return ["好运加护：%d 台" % 名们.size()]

static func _眨眼(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var t = _友军(ctx, u, {})
	if t == null:
		_记(ctx, "眨眼", u, "没有可指定的友军")
		return ["眨眼：没有队友"]
	Btl.加战意(t, 8.0, ctx, "眨眼")
	var 代价 := float(J.num0(card.get("命中代价")))
	if 代价 == 0.0:
		代价 = -10.0
	Btl.换同源增益(u, "卡牌:%s:代价" % str(card.get("id")), {"hit": 代价, "剩余": 1.0})
	_记(ctx, "眨眼", t, "战意 +8（%s）；本回合艾克赛琳每段命中 %s" % [
		J.s((t as Dictionary).get("战意")), J.s(代价)], {"战意": (t as Dictionary).get("战意")})
	return ["眨眼：%s 战意 +8" % str((t as Dictionary).get("name", ""))]

static func _高空回避(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), {"近战不能选": 1.0, "剩余": 1.0})
	_禁用援护射击(u, 1)
	_记(ctx, "白骑士·高空回避", u, "到下个我方阶段前，敌方近战不能选她为目标；本回合不能打援护射击")
	return ["白骑士·高空回避：敌方近战不能选中"]

static func _禁用援护射击(u: Dictionary, 值: int) -> void:
	for e in J.or_(u.get("副武器栏"), []):
		if e is Dictionary and str((e.get("卡") as Dictionary).get("id", "")) == "ATX2_D1":
			e["禁用"] = 值 != 0

static func _响介交给你了(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 响 = null
	for a in Units.livingOf("ally", ctx):
		if 是响介(a):
			响 = a
			break
	if 响 == null:
		_记(ctx, "响介交给你了", u, "响介不在场")
		return ["响介不在场"]
	var 记: Dictionary = (响.get(下一张键) as Dictionary).duplicate(true) if 响.get(下一张键) is Dictionary else {}
	记["暴击"] = float(J.num0(记.get("暴击"))) + 20.0
	响[下一张键] = 记
	if AtxGodsbet.赌神开启(ctx):
		响["赌神翻盘概率"] = 0.6
	_记(ctx, "「响介，交给你了」", 响, "下一张武器牌暴击 +20%s" % (
		"；赌神开启中 → 这张牌的翻盘概率改为 60%" if AtxGodsbet.赌神开启(ctx) else ""))
	return ["响介：下一张武器牌暴击 +20"]

static func _抗光束换实弹(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.换同源增益(u, "卡牌:%s" % str(card.get("id")), {"无视抗性": 1.0, "剩余": 1.0})
	_记(ctx, "「抗光束？那换实弹」", u, "本回合主武器无视目标的光束 / 物理抗性",
		{"无视抗性": 1.0})
	return ["抗光束换实弹：本回合主武器无视抗性"]

static func _excellent(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var rng = ctx.get("rng")
	if rng == null:
		return ["Excellent：没有随机数源"]
	var 一 := float(rng.next_float()) < 0.5
	var 二 := float(rng.next_float()) < 0.5
	if 一 and 二:
		for a in Units.livingOf("ally", ctx):
			if FacAtx._是ATX(a):
				Btl.换同源增益(a, "卡牌:%s" % str(card.get("id")), {"crit": 20.0, "剩余": 1.0})
		_记(ctx, "「Excellent！」", u, "两次正面 → ATX 全体本回合暴击 +20", {"硬币": ["正面", "正面"]})
		return ["Excellent：ATX 全体暴击 +20"]
	if (not 一) and (not 二):
		Btl.加战意(u, -10.0, ctx, "Excellent")
		_记(ctx, "「Excellent！」", u, "两次反面 → 艾克赛琳战意 −10", {"硬币": ["反面", "反面"]})
		return ["Excellent：战意 −10"]
	_记(ctx, "「Excellent！」", u, "一正一反 → 没有效果", {"硬币": [("正面" if 一 else "反面"), ("正面" if 二 else "反面")]})
	return ["Excellent：一正一反，没有效果"]

static func _好运连连(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	u["强运必触发"] = int(ctx.get("turn", 1))
	_记(ctx, "好运连连", u, "本回合下一张带【强运】的牌必定触发")
	return ["好运连连：下一张【强运】必定触发"]

static func _烟幕扩散(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	var 片们: Array = J.or_(ctx.get("烟雾"), [])
	if 片们.is_empty():
		_记(ctx, "烟幕扩散", u, "场上一片烟都没有")
		return ["烟幕扩散：场上没有烟雾"]
	var 首: Dictionary = 片们[0]
	var 列 := int(J.num0(首.get("列")))
	var 邻 := 列 + 1 if int(J.num0(首.get("列"))) + 1 < int(Fm.行列数(Fm.ROW_FRONT)) else 列 - 1
	var 记 := AtxSmoke.放烟(ctx, u, 邻, str(首.get("方", "enemy")))
	_记(ctx, "烟幕扩散", u, "第 %d 列 → 相邻第 %d 列（持续时间照原来那片）" % [列 + 1, 邻 + 1],
		{"来源列": 列, "目标列": 邻})
	return ["烟幕扩散：第 %d 列" % (邻 + 1)]

static func _死角射击(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	u["v01无视遮挡本回合"] = int(ctx.get("turn", 1))
	_记(ctx, "死角射击", u, "本回合她的攻击无视遮挡")
	return ["死角射击：本回合无视遮挡"]

# [规范v0.3·断路器3]
static func W17候选(ctx: Dictionary, u: Variant) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	for a in Units.livingOf("ally", ctx):
		if is_same(a, u):
			continue
		if not FacAtx._是ATX(a):
			continue
		if not J.truthy((a as Dictionary).get("主武器已销毁")):
			continue
		if J.truthy((a as Dictionary).get("本回合再动已用")):
			continue
		出.append(a)
	return 出

static func _w17中继(ctx: Dictionary, u: Dictionary, card: Dictionary, _运行: Dictionary) -> Array:
	var 候选 := W17候选(ctx, u)
	if 候选.is_empty():
		_记(ctx, "W17·中继", u, "受断路器 3 约束：本回合没有可再动的 ATX 友军（每台机体每回合限 1 次）")
		return ["W17·中继：没有可再动的友军"]
	var 指定 = (ctx as Dictionary).get("_当前目标")
	var t = null
	for a in 候选:
		if 指定 != null and str((a as Dictionary).get("key", "")) == str(指定):
			t = a
			break
	if t == null:
		J.sort(候选, func(a, b):
			var d := Units.speedOf(b) - Units.speedOf(a)
			return d if d != 0.0 else float((a as Dictionary).get("slot", 0.0)) - float((b as Dictionary).get("slot", 0.0)))
		t = 候选[0]
	var 成: bool = DeckFlow.再动(ctx, t, "W17·中继")
	if not 成:
		return ["W17·中继：%s 被断路器 3 拦下（本回合已经再动过一次）" % str((t as Dictionary).get("name", ""))]
	(t as Dictionary)["v01不能打大招"] = int(ctx.get("turn", 1))
	_记(ctx, "W17·中继", u, "%s 的主武器全部恢复（可以再打一张，但不能打大招）" % str((t as Dictionary).get("name", "")),
		{"目标": (t as Dictionary).get("key"), "主武器已销毁": false})
	return ["W17·中继：%s 再动" % str((t as Dictionary).get("name", ""))]

static func _语言回路故障(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	Btl.加战意(u, 20.0, ctx, "语言回路故障")
	Btl.换同源增益(u, "卡牌:%s:代价" % str(card.get("id")), {"hit": -15.0, "剩余": 1.0})
	_记(ctx, "「语言回路……故障了的说」", u, "战意 +20；本回合每段命中 −15")
	return ["语言回路故障：战意 +20"]

static func _抽牌(ctx: Dictionary, u: Dictionary, 表: Dictionary) -> Array:
	var 张 := maxi(1, int(J.num0(表.get("数量"))))
	var 抽: Array = Setup.抽专属牌(u, 张)
	_记(ctx, "抽牌", u, "抽 %d 张（%d）" % [张, 抽.size()], {"抽": 抽.size()})
	return ["抽 %d 张（%d）" % [张, 抽.size()]]

static func _加战意(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 值 := float(J.num0(表.get("值")))
	Btl.加战意(u, 值, ctx, str(card.get("名", "")))
	_记(ctx, str(card.get("名", "")), u, "战意 +%s（现在 %s）" % [J.s(值), J.s(u.get("战意"))])
	return ["战意 +%s" % J.s(值)]

static func _回血(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 比 := float(J.num0(表.get("比")))
	var 前 := float(u.get("hp", 0.0))
	var 量 := J.round(float(u.get("maxHp", 0.0)) * 比)
	u["hp"] = minf(float(u.get("maxHp", 0.0)), 前 + 量)
	_记(ctx, str(card.get("名", "")), u, "回复 %s（%s → %s）" % [
		J.s(J.round(float(u.get("hp")) - 前)), J.s(J.round(前)), J.s(J.round(float(u.get("hp"))))],
		{"回复": J.round(float(u.get("hp")) - 前)})
	return ["回复 %s" % J.s(J.round(float(u.get("hp")) - 前))]

static func _追加段(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 段 := maxi(1, int(J.num0(表.get("段数"))))
	var w = card.get("武器")
	if not (w is Dictionary):
		return []
	var 靶 = Btl._存活敌(ctx, u, ctx.get("_当前目标"))
	if 靶 == null or not (靶 is Dictionary):
		return []
	var 武: Dictionary = (w as Dictionary).duplicate(true)
	武["hits"] = float(段)
	武["special"] = "multi"
	var 结算: Dictionary = Flow.结算一个目标(ctx, u, 靶, 武,
		{"改目标": false, "blockPenalty": 0.0, "不写标准攻击日志": true, "旁路攻击": true})
	var rec: Dictionary = 结算.rec
	_记攻击(ctx, "%s·追加" % str(card.get("名", "")), card, u, 靶, rec, {"追加段": 段})
	_记(ctx, str(card.get("名", "")), u, "强运：再打 %d 段" % 段)
	return ["强运：再打 %d 段" % 段]

static func _光环(ctx: Dictionary, u: Dictionary, 表: Dictionary, card: Dictionary) -> Array:
	var 增 = J.or_(表.get("增益"), {})
	var 源 := "卡牌:%s" % str(card.get("id"))
	var 数 := 0
	for a in Units.livingOf("ally", ctx):
		if str(表.get("范围", "ATX")) == "ATX" and not FacAtx._是ATX(a):
			continue
		var b: Dictionary = (增 as Dictionary).duplicate(true)
		if b.get("剩余") == null:
			b["剩余"] = 1.0
		Btl.换同源增益(a, 源, b)
		数 += 1
	_记(ctx, str(card.get("名", "")), u, "%d 台获得 %s" % [数, str(增)])
	return ["%d 台获得 %s" % [数, str(增)]]

static func _本次伤害倍率(ctx: Dictionary, u: Dictionary, 表: Dictionary) -> Array:
	var 值 := float(J.num0(表.get("值")))
	if 值 <= 0.0:
		return []
	u["v01本次伤害倍率"] = 值
	_记(ctx, "雾袭", u, "这一次攻击伤害 ×%s" % J.s(值))
	return ["伤害 ×%s" % J.s(值)]

# ---- 九、分段武器辅助 ----
static func 是分段武器(w: Variant) -> bool:
	return w is Dictionary and (w as Dictionary).get("段威力") is Array

static func 段威力表(w: Variant) -> Array:
	var 出: Array = []
	if not (w is Dictionary):
		return 出
	var 分 = (w as Dictionary).get("分段")
	if not (分 is Array):
		return 出
	for e in 分:
		if not (e is Dictionary):
			continue
		var n := maxi(1, int(J.num0(e.get("段数"))))
		var 威 := float(J.num0(e.get("威力")))
		for _i in n:
			出.append(威)
	return 出
