## ★ MITH3-3：秘银小队 v0.3 权威卡表（5 名成员全卡池 + 连携牌库 9 张 + 势力牌 9 张 + 18 张职业分类牌）。
##
## 权威依据（逐条照抄，数值是初稿）：
##   · `协作/设计/秘银势力卡牌设计 v0.3.md`（连携牌库版）
##   · `协作/设计/宗介卡牌设计 v0.2.md` / `克鲁兹卡牌设计 v0.1.md` / `毛卡牌设计 v0.1.md`
##   · `协作/设计/克鲁佐与杨卡牌设计 v0.1.md`
##   · `协作/设计/卡牌流转规则 v0.1.md` / `武器范围规则 v0.1.md`
##   · `协作/架构/任务单-秘银v0.3与卡牌流转范围规则v1.0-ARGON.md` §1.3 / §2 MITH3-3
##
## ★ 与 v0.2 的关系：**并存、不互相覆盖**。
##   `mithril_v02_cards.gd` 的 `卡表()` 仍然是 MITH-2 的 26 张（冻结，v0.2 的旧门禁全靠它）；
##   本文件是 v0.3 的另一份权威表，只在 `Params.秘银v03开(ctx) == true` 时装填。
##   这样既满足「类名 / 文件名兼容」，又不会因为数据形状变化把 2150 项既有门禁打翻。
##
## 牌面字段（在 v0.2 那套之上多出来的只有 v0.3 自己的）：
##   `卡类` = 主武器卡 / 副武器卡 / 大招槽卡 / 专属精神牌 / 公有牌 / 连携牌
##   `武器`（攻击牌直接带一把武器字典，走 `Flow.resolveAction` 与 `Reach` 的完整管线）
##   `入库条件`（null = 开战即入库；否则条件第一次满足时 `push_front` 到抽牌堆顶）
##   `获取` / `等级需求`（初始 10 / 剧情 20 / 肉鸽 30，肉鸽 Lv20、Lv30 晋升用它）
##   `连携`（bool）/ `连携放入`（更强的连携牌 id）
##   `武器牌`（大招槽里 `is_weapon`；false = 打出不销毁主武器）
class_name MithrilV03Cards
extends RefCounted

const 势力 := "秘银"
const 成员键: Array = ["U7", "U6", "U2", "U1", "U8"]
const 合体技成员: Array = ["U7", "U2", "U6"]
const 合体技ID := "V3_URUZ_TRI"

## 连携牌库的 9 张（一级 4 / 二级 3 / 三级 2）
const 连携一级: Array = ["V3_L1_TDD1", "V3_L1_TACTIC", "V3_L1_COVER", "V3_L1_AMMO"]
const 连携二级: Array = ["V3_L2_SALVO", "V3_L2_FIRE", "V3_L2_TESSA"]
const 连携三级: Array = ["V3_L3_FULL", "V3_L3_SUPPORT"]
const 连携全覆盖: Array = ["V3_L1_TDD1", "V3_L1_TACTIC", "V3_L1_COVER", "V3_L1_AMMO",
	"V3_L2_SALVO", "V3_L2_FIRE", "V3_L2_TESSA", "V3_L3_FULL", "V3_L3_SUPPORT"]

## 带【连携】的 8 张（势力 v0.3 §3）
const 带连携: Array = ["V3_U2_S1", "V3_U2_U2", "V3_U6_U2", "V3_U6_U3",
	"V3_U1_U1", "V3_U8_U1", "V3_F_2", "V3_F_8"]

## 宗介 λ 驱动那两张槽卡的 id（`DeckFlow.关闭λ / 觉醒` 调冷却时用它们，deck_flow 里不写死秘银卡 id）。
const λ启动ID := "V3_U7_U1"
const λ极限ID := "V3_U7_U3"

# ==========================================================================================
# 一、牌面小工具
# ==========================================================================================
static func _底(id: String, 名: String, 卡类: String, 类型: String, 层级: String, 种类: String) -> Dictionary:
	return {
		"id": id, "名": 名, "卡类": 卡类, "类型": 类型, "层级": 层级, "种类": 种类,
		"归属": 势力, "角色": "", "角色们": [], "占行动": [],
		"耗气": 0.0, "回气": 0.0, "限次": 1.0, "冷却": 0.0,
		"回库": false, "衍生": false, "入库条件": null, "获取": "初始", "等级需求": 10,
		"效果说明": "", "效果": [], "连携": false, "连携放入": null, "武器牌": false,
	}

static func _并(d: Dictionary, 额外: Variant) -> Dictionary:
	if 额外 is Dictionary:
		for k in (额外 as Dictionary).keys():
			d[k] = 额外[k]
	return d

## 角色专属牌：绑 1 个角色；`占行动` 默认就是那个角色（精神牌显式写 `[]`）。
static func _角色(id: String, 名: String, 卡类: String, 类型: String, 角色: String, 耗气: float, 额外: Dictionary = {}) -> Dictionary:
	var d := _底(id, 名, 卡类, 类型, "角色", "角色")
	d["角色"] = 角色
	d["角色所属势力"] = 势力
	d["占行动"] = [角色] if 卡类 == "主武器卡" else []
	d["耗气"] = 耗气
	_并(d, 额外)
	return d

static func _武器(id: String, 名: String, 角色: String, 类: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var w := _武(名, 额外)
	var d := _角色(id, 名, 类, "战术", 角色, 耗气, 额外)
	d["武器"] = w
	d["占行动"] = [角色] if 类 == "主武器卡" else []
	d["限次"] = float(J.or_(额外.get("每场次数"), 1.0))
	return d

## 武器字典（`Flow.resolveAction` / `Reach` 直接吃这一份）
static func _武(名: String, 参: Dictionary) -> Dictionary:
	var 类 := str(参.get("武器类型", "direct"))
	var w := {
		"name": 名, "fire": 类, "power": float(J.or_(参.get("威力"), 1000.0)),
		"hit": float(J.or_(参.get("命中"), 100.0)), "critMod": float(J.or_(参.get("暴击"), 0.0)),
		"stat": str(参.get("属性", "射击")), "dmgType": str(参.get("伤害类型", "物理")),
		"cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [],
		"ignoreDef": J.truthy(参.get("无视防御")), "special": null,
		"area": str(J.or_(参.get("area"), "single")),
		"距离": J.or_(参.get("距离"), [1, 6]),
	}
	if J.truthy(参.get("段数")):
		var n := int(参.get("段数"))
		if n > 1:
			w["hits"] = float(n)
			w["special"] = "multi"
	if J.truthy(参.get("无视遮挡")):
		w["ignore_block"] = true
	if 参.get("splash_mul") != null:
		w["splash_mul"] = float(参.get("splash_mul"))
	if 参.get("pierce_mul") != null:
		w["pierce_mul"] = float(参.get("pierce_mul"))
	if 参.get("远距") is Dictionary:
		w["远距"] = 参.get("远距")
	if 参.get("无视装甲比例") != null:
		w["ignoreArmorPct"] = float(参.get("无视装甲比例"))
	return w

## 大招槽条目（`u.大招槽` 里的每一条）
static func _槽(card: Dictionary, 额外: Dictionary = {}) -> Dictionary:
	var d := {
		"卡": card, "cd": 0.0, "cd_max": float(J.or_(card.get("冷却"), 0.0)),
		"is_weapon": J.truthy(card.get("武器牌")), "已解锁": false, "解锁说明": "",
		"实时门槛满足": true, "门槛说明": "", "本回合已打": false,
	}
	_并(d, 额外)
	return d

static func _入库(类型: String, 额外: Dictionary = {}) -> Dictionary:
	var d := {"类型": 类型}
	_并(d, 额外)
	return d

## 第 N 回合起的入库条件
static func _第N回合(n: int) -> Dictionary:
	return _入库("回合至少", {"阈值": n, "说明": "第 %d 回合起" % n})

# ==========================================================================================
# 二、卡表
# ==========================================================================================
static var _表: Array = []
static var _代: int = -1

const _整数键们 := ["每场次数", "等级需求", "阈值", "集中想象减免", "数量", "减免", "段数", "张数"]
const _值整数动作们 := ["距离下限减", "远距判定加", "副武器次数加", "减大招冷却", "降费", "连携多抽", "全队副武器加"]

static func 卡包() -> Dictionary:
	var 包们 = Db.T.get("卡包")
	var 包 = (包们 as Dictionary).get(势力) if 包们 is Dictionary else null
	if not (包 is Dictionary):
		push_error("秘银卡表没装入：缺 Db.T.卡包[\"%s\"]（见 session/data_loader.gd 与 data/cards/秘银.json）" % 势力)
		return {}
	return 包

static func 卡表() -> Array:
	if _代 != Db.代:
		_表 = _构建()
		_代 = Db.代
	return _表

static func 全部卡() -> Array:
	return 卡表().map(func(c): return c.duplicate(true))

static func 卡(id: Variant) -> Dictionary:
	var 键 := str(id.get("id", "")) if id is Dictionary else str(id)
	for c in 卡表():
		if str(c.get("id")) == 键:
			return c.duplicate(true)
	return {}

static func 有(id: Variant) -> bool:
	return not 卡(id).is_empty()

static func 是v03牌(card: Variant) -> bool:
	return card is Dictionary and 有(card.get("id"))

static func 角色牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "角色")

static func 势力牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "势力")

static func 职业牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "职业")

static func 连携牌们() -> Array:
	return 卡表().filter(func(c): return str(c.get("种类", "")) == "连携")

static func 合体技卡() -> Dictionary:
	return 卡(合体技ID)

## 这台机体的**全部**专属牌（角色牌 + 以它为参与者的合体技）。
static func 角色专属牌们(键: Variant) -> Array:
	var k := str(键)
	var 出: Array = []
	for c in 卡表():
		if str(c.get("角色", "")) == k or J.inc(J.or_(c.get("角色们"), []), k):
			出.append(c.duplicate(true))
	return 出

## 按肉鸽等级裁：`等级需求 <= lv` 的才算进牌库（Lv20 / Lv30 晋升解锁）。
static func 角色专属牌们按等级(键: Variant, lv: int) -> Array:
	return 角色专属牌们(键).filter(func(c): return int(c.get("等级需求", 10)) <= lv)

## 全队公有牌：9 张秘银势力牌 + 18 张职业分类牌（职业牌能不能打由 `Btl.身份对口` 判）。
static func 公有牌们() -> Array:
	var 出: Array = 势力牌们()
	出.append_array(职业牌们())
	return 出

## 判定这张牌对这台机体「身份对不对口」（下排公有牌的置灰判据；与 `Btl._身份对口` 同口径的纯读版）。
static func 身份对口(u: Variant, card: Variant, ctx: Variant) -> bool:
	if not (card is Dictionary) or not (u is Dictionary):
		return false
	var 层 := str(card.get("层级", ""))
	var 归 := str(card.get("归属", ""))
	if 层 == "角色":
		return str(u.get("key", "")) == str(card.get("角色", "")) \
			or J.inc(J.or_(card.get("角色们"), []), str(u.get("key", "")))
	if 层 == "职业":
		return Units.unit_class(u, ctx) == 归
	if 层 == "势力":
		return FacMith.是秘银(u)
	return true

static func 是秘银牌(card: Variant) -> bool:
	if not (card is Dictionary):
		return false
	if str(card.get("归属", "")) == 势力:
		return true
	if str(card.get("角色所属势力", "")) == 势力:
		return true
	return J.inc(连携全覆盖, card.get("id"))

## ★ CR-3 Batch C：宗介【λ 驱动】开启时替换后的武器栏。
##   `V3_U7_W1 → V3_U7_LW1`、`V3_U7_W2 → V3_U7_LW2`，末尾再补一把常驻【隔空 λ 拳】`V3_U7_LW3`。
##   **不替换的武器保留原卡对象引用**（不是副本）：配合 `DeckFlow.压栈武器栏 / 弹栈武器栏`，
##   弹栈时拿回来的还是压栈前那组卡，卡上的运行期字段（冷却 / 每场次数 …）不会被重置。
static func λ武器表(u: Dictionary) -> Array:
	var 出: Array = []
	if not (u is Dictionary):
		return 出
	var 映射 := {"V3_U7_W1": "V3_U7_LW1", "V3_U7_W2": "V3_U7_LW2"}
	for c in J.or_(u.get("武器栏"), []):
		if not (c is Dictionary):
			continue
		var id := str((c as Dictionary).get("id", ""))
		if 映射.has(id):
			var λc := 卡(映射[id])
			if λc.is_empty():
				出.append(c)
				continue
			λc["_原卡id"] = id
			出.append(λc)
		else:
			出.append(c)
	if not J.some(出, func(c): return c is Dictionary and str((c as Dictionary).get("id", "")) == "V3_U7_LW3"):
		var 拳 := 卡("V3_U7_LW3")
		if not 拳.is_empty():
			出.append(拳)
	return 出

## 规则钩子【卡不可打原因】：连携牌只有秘银成员能打；别的牌一律不接手。
static func 卡不可打原因(_ctx: Dictionary, u: Dictionary, card: Dictionary, _区: String) -> Dictionary:
	if str(card.get("种类", "")) != "连携":
		return {"终局": false}
	if FacMith.是秘银(u):
		return {"终局": true, "原因": ""}
	return {"终局": true, "原因": "连携牌只有秘银成员能打"}

# ---------------- 构建（从 data/cards/秘银.json 读入） ----------------
static func _还原值(k: String, v: Variant, 父: Dictionary = {}) -> Variant:
	if v is Dictionary:
		return _还原字典(v)
	if v is Array:
		var 组: Array = []
		for x in v:
			组.append(int(x) if k == "距离" else (_还原字典(x) if x is Dictionary else x))
		return 组
	if k in _整数键们:
		return int(v)
	if k == "值" and str(父.get("动作", "")) in _值整数动作们:
		return int(v)
	return v

static func _还原字典(原: Dictionary) -> Dictionary:
	var 出 := {}
	for k in 原.keys():
		出[k] = _还原值(str(k), 原[k], 原)
	return 出

static func _额外(条目: Dictionary, 跳过键们: Array) -> Dictionary:
	var 名 := str(条目.get("名", ""))
	var 武名 := str(条目.get("武器名", 名))
	var 出 := {}
	for k in 条目.keys():
		if k in 跳过键们 or k == "武器名":
			continue
		if k == "武器参":
			出["武器"] = _武(武名, _还原字典(条目[k]))
		else:
			出[k] = _还原值(str(k), 条目[k], 条目)
	return 出

static func _读角色段(段名: String) -> Array:
	var 表: Array = []
	for 条 in 卡包().get(段名, []):
		var id := str(条.get("id", ""))
		var 名 := str(条.get("名", ""))
		var 角色 := str(条.get("角色", ""))
		var 卡类 := str(条.get("卡类", ""))
		var 耗气 := float(条.get("耗气", 0.0))
		if J.truthy(条.get("武器卡")):
			表.append(_武器(id, 名, 角色, 卡类, 耗气, _额外(条, ["id", "名", "角色", "卡类", "耗气", "武器卡"])))
		else:
			表.append(_角色(id, 名, 卡类, str(条.get("类型", "战术")), 角色, 耗气,
				_额外(条, ["id", "名", "角色", "卡类", "类型", "耗气"])))
	return 表

static func _构建() -> Array:
	var 表: Array = []
	表.append_array(_宗介())
	表.append_array(_克鲁兹())
	表.append_array(_毛())
	表.append_array(_克鲁佐())
	表.append_array(_杨())
	var 合 := _合体技()
	if not 合.is_empty():
		表.append(合)
	表.append_array(_连携牌())
	表.append_array(_势力牌())
	表.append_array(_分类牌())
	return 表

static func _宗介() -> Array: return _读角色段("宗介")
static func _克鲁兹() -> Array: return _读角色段("克鲁兹")
static func _毛() -> Array: return _读角色段("毛")
static func _克鲁佐() -> Array: return _读角色段("克鲁佐")
static func _杨() -> Array: return _读角色段("杨")

static func _合体技() -> Dictionary:
	var 条 = 卡包().get("合体技")
	if not (条 is Dictionary) or (条 as Dictionary).is_empty():
		return {}
	var d := _底(str(条.get("id", 合体技ID)), str(条.get("名", "")), str(条.get("卡类", "主武器卡")),
		str(条.get("类型", "大招")), str(条.get("层级", "角色")), str(条.get("种类", "合体技")))
	return _并(d, _额外(条, ["id", "名", "卡类", "类型", "层级", "种类"]))

static func _连携(id: String, 名: String, 级: int, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, "连携牌", "战术", "势力", "连携")
	d["连携等级"] = 级
	d["耗气"] = 0.0
	d["不占主武器"] = true
	d["连携"] = false
	d["回库"] = 级 <= 2
	d["效果说明"] = str(额外.get("效果说明", ""))
	_并(d, 额外)
	return d

static func _连携牌() -> Array:
	var 表: Array = []
	for 条 in 卡包().get("连携牌", []):
		表.append(_连携(str(条.get("id", "")), str(条.get("名", "")), int(条.get("级", 1)),
			_额外(条, ["id", "名", "级"])))
	return 表

static func _势力(id: String, 名: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, "公有牌", "战术", "势力", "势力")
	d["耗气"] = 耗气
	d["回库"] = true
	_并(d, 额外)
	return d

static func _势力牌() -> Array:
	var 表: Array = []
	for 条 in 卡包().get("势力牌", []):
		表.append(_势力(str(条.get("id", "")), str(条.get("名", "")), float(条.get("耗气", 0.0)),
			_额外(条, ["id", "名", "耗气"])))
	return 表

static func _职业(id: String, 名: String, 职业: String, 耗气: float, 额外: Dictionary) -> Dictionary:
	var d := _底(id, 名, "公有牌", "战术", "职业", "职业")
	d["归属"] = 职业
	d["耗气"] = 耗气
	d["回库"] = true
	_并(d, 额外)
	return d

static func _分类牌() -> Array:
	var 表: Array = []
	for 条 in 卡包().get("分类牌", []):
		表.append(_职业(str(条.get("id", "")), str(条.get("名", "")), str(条.get("职业", "")),
			float(条.get("耗气", 0.0)), _额外(条, ["id", "名", "职业", "耗气"])))
	return 表

# ==========================================================================================
# 三、连携牌库（9 张，全队一份；一级 4 张开场就在库里）
# ==========================================================================================
static func 初始连携牌库() -> Array:
	var 出: Array = []
	for id in 连携一级:
		var c := 卡(id)
		if not c.is_empty():
			c["卡类"] = "连携牌"
			出.append(c)
	return 出

static func 连携等级(card: Variant) -> int:
	return int(card.get("连携等级", 0)) if card is Dictionary else 0

static func 各级张数(库: Variant) -> Dictionary:
	var 计 := {"一级": 0, "二级": 0, "三级": 0}
	for c in J.or_(库, []):
		match 连携等级(c):
			1: 计["一级"] = int(计["一级"]) + 1
			2: 计["二级"] = int(计["二级"]) + 1
			3: 计["三级"] = int(计["三级"]) + 1
	return 计

# ==========================================================================================
# 四、被动登记（不是牌）
# ==========================================================================================
## 开局把被动挂到单位身上（`Calc` / `Reach` 直接读这几个字段）。
##   · 宗介 U7：专业军人 / λ 力场（护盾 4000，开启中每回合回满）
##   · 克鲁兹 U6：狙击之王（距离 ≥ 4 → 命中 +20 / 暴击 +20）
##   · 毛 U2：小队长（【指令】牌给目标友军额外 +5 战意）
##   · 克鲁佐 U1：冷血（打 HP ≤ 50% 的目标伤害 +20%）/ 连续攻击
##   · 杨 U8：ECS 隐形（本回合还没打过主武器时，敌方后排不能选杨）
static func 挂被动(u: Dictionary) -> void:
	if not (u is Dictionary):
		return
	match str(u.get("key", "")):
		"U7":
			u["专业军人"] = true
			u["λ力场上限"] = 4000.0
			if not (u.get("形态") is Dictionary):
				u["形态"] = {}
			if not (u.形态.get("lambda") is Dictionary):
				u.形态["lambda"] = {"开启": false, "觉醒": false, "开启回合": 0, "力场被破次数": 0, "免除下次维持": false}
		"U6":
			u["狙击之王"] = true
		"U2":
			u["小队长"] = true
		"U1":
			u["冷血"] = true
			u["连续攻击"] = true
		"U8":
			u["ECS隐形"] = true

# ==========================================================================================
# 五、效果执行器（`CardEffects` 的 `{"算子": "v03", "动作": …}` 分发进来）
#
#   ★ 出牌者与目标怎么传进来：`Btl` 的几个出牌口子在 `CardEffects.execute` 之前写
#     `ctx["_当前出牌者"] = u.key` / `ctx["_当前目标"] = target_id`，这里先读它们，
#     读不到再退回「牌面绑定的角色」「队里第一台秘银成员」「自动挑一个」。
# ==========================================================================================
static func _ctxOf(运行: Dictionary) -> Dictionary:
	var c = 运行.get("ctx")
	return c if c is Dictionary else {}

static func _施放者(运行: Dictionary, card: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 键 := str(ctx.get("_当前出牌者", ""))
	if 键 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key", "")) == 键:
				return u
	var 单 := str(card.get("角色", ""))
	if 单 != "":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and str(u.get("key", "")) == 单:
				return u
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and FacMith.是秘银(u):
			return u
	for u in J.or_(ctx.get("allies"), []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			return u
	return null

## 友军目标：显式目标 → 牌面点名（`目标: "U7"`）→ 血比最低的存活友军。
static func _友军(运行: Dictionary, card: Dictionary, 排除自己: bool = false) -> Variant:
	var ctx := _ctxOf(运行)
	var 施 = _施放者(运行, card)
	var 显 = ctx.get("_当前目标")
	if 显 != null:
		var t = Btl.找单位(ctx, 显, "ally")
		if t is Dictionary and float(t.get("hp", 0.0)) > 0.0:
			return t
	var 名 := str(card.get("目标", ""))
	if 名 == "自身":
		return 施
	if 名 != "" and 名 != "友军":
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and str(u.get("key", "")) == 名 and float(u.get("hp", 0.0)) > 0.0:
				return u
	var 候选: Array = []
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary) or float(u.get("hp", 0.0)) <= 0.0:
			continue
		if 排除自己 and is_same(u, 施):
			continue
		候选.append(u)
	if 候选.is_empty():
		return 施
	J.sort(候选, func(a, b): return DeckFlow.血比(a) - DeckFlow.血比(b))
	return 候选[0]

## 敌机目标：显式目标 → 血比最低的存活敌机。
static func _敌机(运行: Dictionary) -> Variant:
	var ctx := _ctxOf(运行)
	var 显 = ctx.get("_当前目标")
	if 显 != null:
		var t = Btl.找单位(ctx, 显, "enemy")
		if t is Dictionary and float(t.get("hp", 0.0)) > 0.0:
			return t
	var 候选: Array = []
	for u in J.or_(ctx.get("enemies"), []):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			候选.append(u)
	if 候选.is_empty():
		return null
	J.sort(候选, func(a, b): return DeckFlow.血比(a) - DeckFlow.血比(b))
	return 候选[0]

static func _记(ctx: Dictionary, 牌名: String, 文本: String, 额外: Dictionary = {}) -> void:
	Btl.pushLog(ctx, "〔%s〕%s" % [牌名, 文本],
		J.merged({"类型": "秘银v03", "牌名": 牌名}, 额外))

## ★ 2026-10-22（任务单 P3-4）：一条效果摘要里要写的**作用目标名**（拿不到 = `目标`）。
##   作者反馈「精神卡的效果没有体现在战斗记录里」——摘要必须写清「作用于【谁】」。
static func _名(u: Variant) -> String:
	if u is Dictionary and not str((u as Dictionary).get("name", "")).is_empty():
		return str((u as Dictionary).get("name", ""))
	return "目标"

static func 执行算子(运行: Dictionary, 表: Dictionary, _目标们: Array) -> Array:
	var 动作 := str(表.get("动作", ""))
	var ctx := _ctxOf(运行)
	if ctx.is_empty():
		return []
	var card: Dictionary = 运行.get("card") if 运行.get("card") is Dictionary else {}
	var 牌名 := str(card.get("名", ""))
	var 施 = _施放者(运行, card)
	match 动作:
		"λ启动":
			if 施 == null:
				return ["没有能启动 λ 的机体"]
			if DeckFlow.λ开启(施):
				return ["作用于【%s】：λ 驱动已经开着（不重复开启）" % _名(施)]
			DeckFlow.开启λ(ctx, 施)
			return ["作用于【%s】：λ 驱动开启（力场 %d）" % [_名(施), int(J.num0(施.get("λ力场上限")))]]
		"歼灭作战":
			return _歼灭作战(ctx, card, 施)
		"乌鲁兹三角":
			return _乌鲁兹三角(ctx, card, 施)
		"本回合命中":
			var t = 施 if str(表.get("目标", "自身")) == "自身" else (_友军(运行, card))
			if t != null:
				Btl.换同源增益(t, "v3本回合命中", {"hit": float(J.or_(表.get("值"), 0.0)), "剩余": 1.0})
				if 表.get("大型增伤") != null:
					Btl.换同源增益(t, "v3大型增伤", {"大型DmgMul": float(表.get("大型增伤")), "剩余": 1.0})
			return ["作用于【%s】：本回合命中 %+d" % [_名(t), int(J.or_(表.get("值"), 0.0))]]
		"本回合伤害":
			if 施 != null:
				Btl.换同源增益(施, "v3本回合伤害", {"dmgMulPct": float(J.or_(表.get("值"), 0.0)) * 100.0, "剩余": 1.0})
			return ["作用于【%s】：本回合伤害 +%d%%" % [_名(施), int(float(J.or_(表.get("值"), 0.0)) * 100.0)]]
		"本回合闪避":
			if 施 != null:
				Btl.换同源增益(施, "v3本回合闪避", {"eva": float(J.or_(表.get("值"), 0.0)), "剩余": 1.0})
			return ["作用于【%s】：本回合闪避 %+d" % [_名(施), int(J.or_(表.get("值"), 0.0))]]
		"本回合暴击":
			if 施 != null:
				Btl.换同源增益(施, "v3本回合暴击", {"crit": float(J.or_(表.get("值"), 0.0)), "剩余": 1.0})
			return ["作用于【%s】：本回合暴击 %+d" % [_名(施), int(J.or_(表.get("值"), 0.0))]]
		"秘银命中":
			ctx["v3秘银命中"] = float(J.or_(ctx.get("v3秘银命中"), 0.0)) + float(J.or_(表.get("值"), 0.0))
			_记(ctx, 牌名, "本回合下一次秘银攻击命中 +%d" % int(J.or_(表.get("值"), 0.0)))
			return ["本回合所有秘银攻击命中 +%d（下一张秘银武器牌兑现）" % int(J.or_(表.get("值"), 0.0))]
		"加战意":
			var t2 = 施 if str(表.get("目标", "自身")) == "自身" else _友军(运行, card)
			if t2 != null:
				Btl.加战意(t2, 表.get("值"), ctx, 牌名)
				# 毛的被动「小队长」：【指令】牌给目标友军额外 +5 战意
				if J.truthy(card.get("指令")) and J.truthy(_施放者(运行, card).get("小队长")) \
					and t2 != null and not is_same(t2, _施放者(运行, card)):
					Btl.加战意(t2, 5.0, ctx, "小队长")
					_记(ctx, 牌名, "小队长：【指令】让 %s 额外 +5 战意" % str(t2.get("name", "")),
						J.merged({"小队长": true}, Btl.谁目标(t2)))
			return ["作用于【%s】：战意 +%d（现 %s）" % [_名(t2), int(J.or_(表.get("值"), 0.0)),
				J.s(J.num0(t2.get("战意"))) if t2 != null else "0"]]
		"战意转移":
			var 自 = _施放者(运行, card)
			var 收 = _友军(运行, card, true)
			if 自 != null:
				Btl.加战意(自, -float(J.or_(表.get("扣"), 0.0)), ctx, 牌名)
			if 收 != null:
				Btl.加战意(收, 表.get("给"), ctx, 牌名)
				Btl.加战意(收, 5.0, ctx, "小队长")
			return ["%s 战意 −%d → 作用于【%s】：战意 +%d（含小队长 +5）" % [
				_名(自), int(J.or_(表.get("扣"), 0.0)), _名(收), int(J.or_(表.get("给"), 0.0)) + 5]]
		"回力场":
			var t3 = _友军(运行, card)
			var 额 := 0.0
			if t3 != null and DeckFlow.λ开启(t3):
				var 前盾 := float(t3.get("shieldHp", 0.0))
				t3["shieldHp"] = minf(4000.0, 前盾 + 4000.0 * float(J.or_(表.get("比"), 0.5)))
				额 = float(t3.get("shieldHp", 0.0)) - 前盾
			return ["作用于【%s】：λ 力场回复 %d（现 %d / 4000）" % [_名(t3), int(额),
				int(float(t3.get("shieldHp", 0.0))) if t3 != null else 0]]
		"集中想象":
			var t4 = _友军(运行, card)
			if t4 != null:
				t4["v3集中想象"] = int(J.or_(表.get("减免"), 20))
				DeckFlow.λ状态(t4)["免除下次维持"] = true
				_记(ctx, 牌名, "本回合「λ 驱动·启动」门槛 −%d；λ 已开启则下次维持免除" % int(J.or_(表.get("减免"), 20)))
			return ["作用于【%s】：「λ 驱动·启动」门槛 −%d；λ 已开启则下次维持免除" % [
				_名(t4), int(J.or_(表.get("减免"), 20))]]
		"抽精神":
			var n1 := int(J.or_(表.get("数量"), 1))
			var 抽主 = _友军(运行, card) if str(表.get("目标", "")) == "友军" else _施放者(运行, card)
			var 抽 = Setup.抽专属牌(抽主, n1)
			var 抽名们: Array = []
			for c1 in 抽:
				if c1 is Dictionary:
					抽名们.append(str((c1 as Dictionary).get("名", "")))
			return ["作用于【%s】：抽到 %d 张精神牌%s" % [_名(抽主), 抽.size(),
				("（%s）" % "、".join(抽名们)) if not 抽名们.is_empty() else ""]]
		"抽公有":
			var 抽2 = Setup.抽公有牌(ctx, int(J.or_(表.get("数量"), 1)))
			var 抽名2: Array = []
			for c2 in 抽2:
				if c2 is Dictionary:
					抽名2.append(str((c2 as Dictionary).get("名", "")))
			return ["抽到 %d 张公有牌%s" % [抽2.size(),
				("（%s）" % "、".join(抽名2)) if not 抽名2.is_empty() else ""]]
		"置入连携":
			return _置入公有手牌(ctx, str(J.or_(表.get("id"), "V3_L1_TDD1")), int(J.or_(表.get("数量"), 1)))
		"降费":
			ctx["_v3降费"] = int(J.or_(ctx.get("_v3降费"), 0)) + int(J.or_(表.get("值"), 5))
			return ["下一张秘银牌费用 −%d" % int(J.or_(表.get("值"), 5))]
		"连携多抽":
			ctx["连携多抽"] = int(J.or_(ctx.get("连携多抽"), 0)) + int(J.or_(表.get("值"), 1))
			_记(ctx, 牌名, "本回合下一次连携多抽 %d 张连携牌" % int(J.or_(表.get("值"), 1)))
			return ["本回合下一次连携多抽 %d 张连携牌" % int(J.or_(表.get("值"), 1))]
		"副武器次数加":
			ctx["v3副武器加"] = int(J.or_(ctx.get("v3副武器加"), 0)) + int(J.or_(表.get("值"), 1))
			return ["作用于【%s】：本回合援护射击多打 %d 次" % [_名(施), int(J.or_(表.get("值"), 1))]]
		"全队副武器加":
			ctx["v3副武器加"] = int(J.or_(ctx.get("v3副武器加"), 0)) + int(J.or_(表.get("值"), 1))
			_记(ctx, 牌名, "本回合所有我方狙击的援护射击多打 %d 次" % int(J.or_(表.get("值"), 1)))
			return ["本回合所有我方狙击的援护射击多打 %d 次" % int(J.or_(表.get("值"), 1))]
		"各员开火":
			ctx["v3各员开火"] = {"伤害": float(J.or_(表.get("伤害"), 0.2)), "命中": float(J.or_(表.get("命中"), 10.0))}
			_记(ctx, 牌名, "本回合所有秘银成员下一张主武器牌伤害 +20%%、命中 +10")
			return ["本回合所有秘银成员下一张主武器牌伤害 +%d%%、命中 +%d" % [
				int(float(J.or_(表.get("伤害"), 0.2)) * 100.0), int(J.or_(表.get("命中"), 10.0))]]
		"减大招冷却":
			return _减大招冷却(ctx, int(J.or_(表.get("值"), 1)))
		"紧急支援":
			var 名单: Array = []
			for u in J.or_(ctx.get("allies"), []):
				if u is Dictionary and FacMith.是秘银(u) and J.truthy(u.get("主武器已销毁")) \
					and float(u.get("hp", 0.0)) > 0.0:
					if DeckFlow.再动(ctx, u):
						名单.append(str(u.get("name", "")))
			_记(ctx, 牌名, "达纳号紧急支援：%s 主武器恢复（再动）" % ("、".join(名单) if not 名单.is_empty() else "没有需要再动的成员"))
			if 名单.is_empty():
				return ["达纳号紧急支援：本回合没有「已打过主武器」的秘银成员 → 无人在再动"]
			return ["达纳号紧急支援：%s 的主武器全部恢复（再动，可以再打一张）" % "、".join(名单)]
		"再动":
			var t5 = _友军(运行, card)
			var 成 := false
			if t5 != null:
				成 = DeckFlow.再动(ctx, t5)
			if t5 == null:
				return ["再动：没有可指定的友军"]
			if not 成:
				return ["作用于【%s】：本回合已经再动过一次（每台机体每回合限 1 次）" % _名(t5)]
			return ["作用于【%s】：再动（恢复主武器栏）" % _名(t5)]
		"回血比":
			var t6 = _友军(运行, card)
			var 回 := 0.0
			if t6 != null:
				var 前 := float(t6.get("hp", 0.0))
				var 上限 := float(t6.get("maxHp", 1.0))
				var 量 := float(J.round(上限 * float(J.or_(表.get("比"), 0.25))))
				t6["hp"] = minf(上限, 前 + 量)
				回 = float(t6.get("hp", 0.0)) - 前
				_记(ctx, 牌名, "%s 回复 %d" % [str(t6.get("name", "")), int(回)],
					J.merged({"回复": 回}, Btl.谁目标(t6)))
			return ["作用于【%s】：回复 %d HP（上限的 %d%%）" % [_名(t6), int(回),
				int(float(J.or_(表.get("比"), 0.25)) * 100.0)]]
		"受伤减少":
			var t7 = _友军(运行, card)
			if t7 != null:
				Btl.换同源增益(t7, 牌名, {"受伤Mul": -float(J.or_(表.get("比"), 0.3)), "剩余": 1.0})
			return ["作用于【%s】：到下个我方阶段前受到伤害 −%d%%" % [_名(t7),
				int(float(J.or_(表.get("比"), 0.3)) * 100.0)]]
		"减伤":
			var t8 = _友军(运行, card)
			if t8 != null:
				if 表.get("命中减") != null:
					Btl.换同源增益(t8, "v3隐蔽", {"hit": -float(表.get("命中减")), "剩余": 1.0})
				if 表.get("值") != null:
					Btl.换同源增益(t8, "v3减伤", {"dmgCut": float(表.get("值")), "剩余": 1.0})
				_记(ctx, 牌名, "%s：到下个我方阶段前受到的伤害 / 命中修正已生效" % str(t8.get("name", "")),
					Btl.谁目标(t8))
			return ["作用于【%s】：到下个我方阶段前受到的伤害 / 命中修正已生效" % _名(t8)]
		"自受伤":
			if 施 != null:
				Btl.换同源增益(施, 牌名, {"受伤Mul": float(J.or_(表.get("值"), 0.2)), "剩余": 1.0})
			return ["作用于【%s】：本回合受到伤害 +%d%%" % [_名(施), int(float(J.or_(表.get("值"), 0.2)) * 100.0)]]
		"禁用副武器":
			var t9 = _友军(运行, card)
			if t9 != null:
				for e in J.or_(t9.get("副武器栏"), []):
					e["禁用"] = true
				_记(ctx, 牌名, "%s 本回合不能打副武器" % str(t9.get("name", "")), Btl.谁目标(t9))
			return ["作用于【%s】：本回合不能打副武器" % _名(t9)]
		"援护强化":
			if 施 != null:
				施["v3援护强化"] = true
			return ["作用于【%s】：援护射击伤害 100% + 必中" % _名(施)]
		"距离下限减":
			if 施 != null:
				施["v3距离下限减"] = int(J.or_(表.get("值"), 1))
			return ["作用于【%s】：主武器距离下限 −%d" % [_名(施), int(J.or_(表.get("值"), 1))]]
		"远距判定加":
			if 施 != null:
				施["v3远距判定加"] = int(J.or_(表.get("值"), 2))
			return ["作用于【%s】：远距判定距离 +%d" % [_名(施), int(J.or_(表.get("值"), 2))]]
		"狙击骄傲":
			if 施 != null:
				施["v3狙击骄傲"] = true
			return ["作用于【%s】：狙击之王的骄傲（本回合狙击不必满足距离下限）" % _名(施)]
		"火力压制减命中":
			for u in J.or_(ctx.get("enemies"), []):
				if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and u.get("slot") != null \
					and Fm.rowOfSlot(float(u.slot)) == Fm.ROW_FRONT:
					Btl.换同源增益(u, "火力压制", {"hit": -float(J.or_(表.get("值"), 15.0)), "剩余": 1.0})
			return ["火力压制：敌方前排命中 −%d" % int(J.or_(表.get("值"), 15.0))]
		"全员突击":
			# ★ 2026-10-22（任务单 P3-4）：卡面写明「**不算武器牌，不销毁主武器**」——
			#   这里从前错写了 `施["主武器已销毁"] = true`，现在删掉：毛打完这张照常能打主武器。
			var 突击名单: Array = []
			for u in J.or_(ctx.get("allies"), []):
				if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and FacMith.是秘银(u) \
					and str(u.get("key", "")) != "U2":
					Btl.加战意(u, 10.0, ctx, 牌名)
					Btl.换同源增益(u, "v3全员突击", {"dmgMulPct": 20.0, "剩余": 1.0})
					突击名单.append(str(u.get("name", "")))
			_记(ctx, 牌名, "%s 战意 +10、下一张主武器牌伤害 +20%%；本回合毛不能打主武器" % (
				"、".join(突击名单) if not 突击名单.is_empty() else "（在场没有其他秘银成员）"),
				J.merged({"类型": "全员突击", "战意加": 10.0, "主武器伤害加": 20.0},
					Btl.谁(施) if 施 != null else {}))
			var 摘: Array = []
			if 突击名单.is_empty():
				摘.append("Uruz 全员突击：在场没有其他秘银成员（只有毛自己）→ 没有队友吃「战意+10、下张主武器伤害+20%」")
			else:
				摘.append("%s 战意+10、下张主武器伤害+20%%（本回合毛不能打主武器；这张不算武器牌，不销毁主武器栏）"
					% "、".join(突击名单))
			# 卡面真带 `连携` 时把连携抽牌的结果也写进主摘要（本张牌面没有连携 → 不会多这一句）
			if J.truthy(card.get("连携")):
				var 连果 = DeckFlow.触发连携(ctx, card)
				var 连名 := str((连果 as Dictionary).get("抽到", "")) if 连果 is Dictionary else ""
				摘.append("抽 1 张连携牌%s" % (("（%s）" % 连名) if not 连名.is_empty() else ""))
			return 摘
		"指令战意λ":
			var t10 = _友军(运行, card)
			if t10 != null:
				Btl.加战意(t10, 表.get("值"), ctx, 牌名)
				Btl.加战意(t10, 5.0, ctx, "小队长")
				DeckFlow.λ状态(t10)["免除下次维持"] = true
				_记(ctx, 牌名, "%s 战意 +%d，本回合 λ 维持消耗免除" % [str(t10.get("name", "")), int(J.or_(表.get("值"), 10))],
					Btl.谁目标(t10))
			return ["作用于【%s】：战意 +%d（含小队长 +5）、本回合 λ 维持消耗免除" % [
				_名(t10), int(J.or_(表.get("值"), 10)) + 5]]
		"指令命中暴击":
			var t11 = _友军(运行, card)
			if t11 != null:
				Btl.换同源增益(t11, "v3指令命中", {"hit": float(J.or_(表.get("命中"), 15.0)), "剩余": 1.0})
				Btl.换同源增益(t11, "v3指令暴击", {"crit": float(J.or_(表.get("暴击"), 15.0)), "剩余": 1.0})
				Btl.加战意(t11, 5.0, ctx, "小队长")
				_记(ctx, 牌名, "%s 本回合命中 +%d、暴击 +%d（小队长再 +5 战意）" % [
					str(t11.get("name", "")), int(J.or_(表.get("命中"), 15)), int(J.or_(表.get("暴击"), 15))],
					Btl.谁目标(t11))
			return ["作用于【%s】：本回合命中 +%d、暴击 +%d（小队长再 +5 战意）" % [_名(t11),
				int(J.or_(表.get("命中"), 15)), int(J.or_(表.get("暴击"), 15))]]
		"掩护后方":
			var 宗 = _施放者(运行, card)
			if 宗 != null:
				宗["v3掩护后方"] = float(J.or_(表.get("受伤减免"), 0.3))
			return ["作用于【%s】：替后方队友挡枪（受到的伤害 −%d%%）" % [_名(宗),
				int(float(J.or_(表.get("受伤减免"), 0.3)) * 100.0)]]
		"反击地雷":
			if 施 != null:
				施["v3阔剑地雷"] = float(J.or_(表.get("值"), 1500.0))
			return ["作用于【%s】：阔剑地雷已布置（%d 伤害）" % [_名(施), int(J.or_(表.get("值"), 1500.0))]]
		"追加攻击":
			if 施 != null:
				施["v3追加攻击"] = float(J.or_(表.get("倍率"), 0.6))
			return ["作用于【%s】：射控交给 Al（下一次追加攻击 ×%s）" % [_名(施),
				J.s(J.num0(J.or_(表.get("倍率"), 0.6)))]]
		"爆破装药":
			if 施 != null:
				施["v3爆破装药"] = float(J.or_(表.get("倍率"), 2.0))
			return ["作用于【%s】：爆破装药（伤害 ×%s）" % [_名(施), J.s(J.num0(J.or_(表.get("倍率"), 2.0)))]]
		"邦太君":
			if 施 != null:
				Btl.换同源增益(施, "邦太君", {"受伤Mul": -0.5, "剩余": 1.0})
				施["v3邦太君"] = true
			return ["作用于【%s】：邦太君（到下个我方阶段前受到伤害 −50%%）" % _名(施)]
		"隐身":
			var t12 = _友军(运行, card)
			if t12 != null:
				t12["_隐身"] = true
				_记(ctx, 牌名, "%s 进入隐身：敌人不能选它为目标" % str(t12.get("name", "")), Btl.谁目标(t12))
			return ["作用于【%s】：进入隐身（敌人不能选它为目标）" % _名(t12)]
		"压制命中":
			var e2 = _敌机(运行)
			if e2 != null:
				Btl.换同源增益(e2, "v3压制", {"hit": -float(J.or_(表.get("值"), 20.0)), "剩余": 1.0})
				_记(ctx, 牌名, "%s 到下个我方阶段前命中 −%d" % [str(e2.get("name", "")), int(J.or_(表.get("值"), 20.0))],
					Btl.谁目标(e2))
			return ["作用于【%s】：到下个我方阶段前命中 −%d" % [_名(e2), int(J.or_(表.get("值"), 20.0))]]
		"秘银减命中":
			ctx["v3秘银减命中"] = float(J.or_(ctx.get("v3秘银减命中"), 0.0)) + float(J.or_(表.get("值"), 15.0))
			_记(ctx, 牌名, "本回合敌方打秘银成员命中 −%d" % int(J.or_(表.get("值"), 15.0)))
			return ["本回合敌方打秘银成员命中 −%d" % int(J.or_(表.get("值"), 15.0))]
		"前排减命中":
			ctx["v3前排减命中"] = float(J.or_(ctx.get("v3前排减命中"), 0.0)) + float(J.or_(表.get("值"), 10.0))
			_记(ctx, 牌名, "到下个我方阶段前，敌方打我方前排命中 −%d" % int(J.or_(表.get("值"), 10.0)))
			return ["到下个我方阶段前，敌方打我方前排命中 −%d" % int(J.or_(表.get("值"), 10.0))]
		"紧急防护":
			var t13 = _友军(运行, card)
			if t13 != null:
				Btl.换同源增益(t13, 牌名, {"受伤Mul": -float(J.or_(表.get("受伤减免"), 0.5)), "剩余": 1.0})
			return ["作用于【%s】：到下个我方阶段前受到的伤害 −%d%%" % [_名(t13),
				int(float(J.or_(表.get("受伤减免"), 0.5)) * 100.0)]]
		"查看连携":
			return _查看连携(ctx, int(J.or_(表.get("张数"), 1)))
		"饱和攻击":
			ctx["v3饱和攻击"] = int(J.or_(ctx.get("v3饱和攻击"), 0)) + 1
			_记(ctx, 牌名, "本回合此后每打出 1 张 TDD 系列连携牌，对随机敌机追加 800 伤害")
			return ["本回合此后每打出 1 张 TDD 系列连携牌，对随机敌机追加 800 伤害"]
		"破障射击":
			var t14 = _友军(运行, card)
			if t14 != null:
				Btl.换同源增益(t14, "破障射击", {"破障": true, "剩余": 1.0})
				_记(ctx, 牌名, "%s 本回合的直射武器无视遮挡" % str(t14.get("name", "")), Btl.谁目标(t14))
			return ["作用于【%s】：本回合的直射武器无视遮挡" % _名(t14)]
		"后方渗透":
			var t15 = _友军(运行, card)
			if t15 != null:
				Btl.换同源增益(t15, "后方渗透", {"渗透": true, "剩余": 1.0})
				Btl.换同源增益(t15, 牌名 + "代价", {"受伤Mul": 0.2, "剩余": 1.0})
			return ["作用于【%s】：本回合近战可以直打敌方后排（代价：受到伤害 +20%%）" % _名(t15)]
		"放诱饵":
			return _放诱饵(ctx)
		"放掩体":
			return _放掩体(ctx, float(J.or_(表.get("hp"), 3000.0)))
		"拆除":
			ctx["敌方陷坑"] = []
			_记(ctx, 牌名, "移除一个敌方陷坑 / 区域效果")
			return ["移除一个敌方陷坑 / 区域效果"]
		"电子侦察":
			ctx["v3电子侦察"] = true
			return ["本回合显示全部敌机的大招冷却与下一个行动目标"]
		"战场分析":
			ctx["v3战场分析"] = true
			return ["本回合显示敌方全体的下一个行动目标"]
		"战术目标":
			var e3 = _敌机(运行)
			if e3 != null:
				ctx["v3战术目标"] = str(e3.get("key", ""))
				Btl.换同源增益(e3, "战术目标", {"hit": float(J.or_(表.get("值"), 10.0)), "剩余": 1.0})
			return ["作用于【%s】：本回合我方攻击它命中 +%d" % [_名(e3), int(J.or_(表.get("值"), 10.0))]]
		"撤退命令":
			var t16 = _友军(运行, card)
			if t16 != null:
				Btl.换同源增益(t16, 牌名, {"受伤Mul": -float(J.or_(表.get("比"), 0.4)), "剩余": 1.0})
				t16["主武器已销毁"] = true
			return ["作用于【%s】：到下个我方阶段前受到伤害 −%d%%；它本回合不能打主武器" % [
				_名(t16), int(float(J.or_(表.get("比"), 0.4)) * 100.0)]]
		"鼓舞":
			var 鼓名: Array = []
			for u in J.or_(ctx.get("allies"), []):
				if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
					Btl.加战意(u, 表.get("值"), ctx, 牌名)
					鼓名.append(str(u.get("name", "")))
			return ["我方全体战意 +%d（%s）" % [int(J.or_(表.get("值"), 0.0)), "、".join(鼓名)]]
		"集中火力":
			ctx["v3集中火力"] = float(J.or_(表.get("值"), 0.15))
			return ["本回合我方对同一目标的第 2 次及以后攻击，伤害 +%d%%" % int(float(J.or_(表.get("值"), 0.15)) * 100.0)]
		"阵型调整":
			return _阵型调整(ctx)
		"伪装网":
			var t17 = _友军(运行, card)
			if t17 != null:
				t17["v3伪装网"] = true
			return ["作用于【%s】：到下个我方阶段前，敌方前排不能选它为目标" % _名(t17)]
		"狙击阵地":
			var t18 = _友军(运行, card)
			if t18 != null:
				Btl.换同源增益(t18, "v3狙击阵地", {"hit": 10.0, "crit": 10.0, "剩余": 1.0})
				t18["v3距离上限加"] = 1
			return ["作用于【%s】：本回合命中 +10、暴击 +10，主武器距离上限 +1（最多 6）" % _名(t18)]
		"观测员":
			var t19 = _友军(运行, card)
			if t19 != null:
				施 = _施放者(运行, card)
				if 施 != null:
					Btl.换同源增益(施, "v3观测员", {"hit": float(J.or_(表.get("值"), 20.0)), "剩余": 1.0})
			return ["观测员【%s】→ 作用于【%s】：本回合攻击它所在列的敌机命中 +%d" % [
				_名(t19), _名(施), int(J.or_(表.get("值"), 20.0))]]
		"反狙击":
			var t20 = _友军(运行, card)
			if t20 != null:
				t20["v3反狙击"] = true
			return ["作用于【%s】：到下个我方阶段前第一次被直射 / 曲射攻击时，先用主武器反击（无视距离下限）" % _名(t20)]
		"自受伤加成":
			return []
	push_error("MithrilV03Cards：未知的 v0.3 动作「%s」" % 动作)
	return []

# ---------------- 各动作的具体实现 ----------------
static func _歼灭作战(ctx: Dictionary, card: Dictionary, 施: Variant) -> Array:
	if 施 == null:
		return ["【歼灭作战】没有能出手的机体"]
	var 目标 = _敌机({"ctx": ctx, "card": card})
	if 目标 == null:
		return ["【歼灭作战】没有可打的目标"]
	var 段名们 := ["57mm 散弹炮", "单分子刀", "榴弹发射器"]
	var 摘要: Array = []
	var λ := DeckFlow.λ开启(施)
	for i in 段名们.size():
		var 名 := str(段名们[i])
		var id := "V3_U7_W%d" % (i + 1)
		if λ and i < 2:
			id = "V3_U7_LW%d" % (i + 1)
		名 = str(MithrilV03Cards.卡(id).get("名", 名))
		var 卡 := MithrilV03Cards.卡(id)
		if not (卡.get("武器") is Dictionary):
			continue
		var w: Dictionary = (卡.武器 as Dictionary).duplicate(true)
		w["power"] = float(w.get("power", 0.0)) * 0.7
		if not Reach.够得着吗(ctx, 施, w, 目标):
			continue
		var rec = Btl._执行武器攻击(ctx, 施, {"t": w, "cd": 0.0, "uses": null}, 目标.get("key"))
		摘要.append("%s → %s" % [名, str(目标.get("name", ""))])
		if float(目标.get("hp", 0.0)) <= 0.0:
			break
	_记(ctx, "歼灭作战", "三段连击：%s" % "、".join(摘要),
		J.merged({"类型": "歼灭作战", "段数": float(摘要.size())}, Btl.谁(施)))
	return 摘要

static func _乌鲁兹三角(ctx: Dictionary, card: Dictionary, 施: Variant) -> Array:
	var 摘要: Array = []
	var 达 = Btl._找队友(ctx, "U2")
	var 克 = Btl._找队友(ctx, "U6")
	var 宗 = Btl._找队友(ctx, "U7")
	if 达 == null or 克 == null or 宗 == null:
		return ["【乌鲁兹·三角】三人不齐，打不出来"]
	# ① 达纳号对敌方全体曲射 2000
	var w1 := _武("达纳号·巡航导弹", {"武器类型": "indirect", "威力": 2000.0, "命中": 100.0,
		"距离": [1, 6], "area": "all"})
	for e in J.or_(ctx.get("enemies"), []):
		if e is Dictionary and float(e.get("hp", 0.0)) > 0.0:
			Btl._执行武器攻击(ctx, 达, {"t": w1, "cd": 0.0, "uses": null}, e.get("key"))
	摘要.append("① 达纳号：敌方全体 2000")
	# ② 克鲁兹对指定目标狙击，必中
	var 目标 = _敌机({"ctx": ctx, "card": card})
	if 目标 != null:
		var w2 := _武("超长距离狙击", {"武器类型": "direct", "威力": 3950.0, "命中": 120.0,
			"距离": [1, 6], "无视防御": true, "无视遮挡": true})
		w2["hit"] = 200.0
		Btl._执行武器攻击(ctx, 克, {"t": w2, "cd": 0.0, "uses": null}, 目标.get("key"))
		摘要.append("② 克鲁兹：狙击（必中）")
	# ③ 宗介打「λ 驱动·极限放出」（λ 没开也照打）
	var 目标2 = _敌机({"ctx": ctx, "card": card})
	if 目标2 != null:
		var w3 := _武("λ 驱动·极限放出", {"武器类型": "direct", "威力": 4300.0, "命中": 95.0,
			"伤害类型": "特殊", "距离": [1, 6], "无视遮挡": true})
		Btl._执行武器攻击(ctx, 宗, {"t": w3, "cd": 0.0, "uses": null}, 目标2.get("key"))
		摘要.append("③ 宗介：λ 驱动·极限放出")
	_记(ctx, "乌鲁兹·三角", "合体技：%s" % "、".join(摘要),
		J.merged({"类型": "合体技", "参与者": ["U7", "U2", "U6"]}, Btl.谁(施)))
	return 摘要

static func _减大招冷却(ctx: Dictionary, 值: int) -> Array:
	var 摘要: Array = []
	for u in J.or_(ctx.get("allies"), []):
		if not (u is Dictionary) or not FacMith.是秘银(u) or float(u.get("hp", 0.0)) <= 0.0:
			continue
		for 槽 in J.or_(u.get("大招槽"), []):
			if float(槽.get("cd", 0.0)) > 0.0:
				槽["cd"] = maxf(0.0, float(槽["cd"]) - float(值))
				摘要.append("%s 的【%s】冷却 −%d（剩 %d）" % [str(u.get("name", "")),
					str(J.or_(槽.get("卡"), {}).get("名", "")), 值, int(槽.cd)])
				return 摘要
	return ["没有冷却中的秘银大招"]

static func _置入公有手牌(ctx: Dictionary, id: String, 数量: int) -> Array:
	var 摘要: Array = []
	var 卡 := MithrilV03Cards.卡(id)
	if 卡.is_empty():
		return ["置入失败：不认识的连携牌 %s" % id]
	卡["卡类"] = "连携牌"
	for _i in range(maxi(0, 数量)):
		if (ctx.get("公有手牌") as Array).size() >= DeckFlow.公有上限:
			摘要.append("公有手牌已满（%d/%d），【%s】放不进去" % [DeckFlow.公有上限, DeckFlow.公有上限, str(卡.get("名", ""))])
			break
		ctx.公有手牌.append(Btl.克隆战术牌(卡, ctx))
		摘要.append("置入公有手牌：【%s】" % str(卡.get("名", "")))
		Btl.记(ctx, {"类型": "置入公有手牌", "卡牌ID": id, "卡牌": 卡.get("名"),
			"文本": "〔连携〕置入公有手牌：【%s】" % str(卡.get("名", ""))})
	return 摘要

static func _查看连携(ctx: Dictionary, 张数: int) -> Array:
	var 摘要: Array = []
	var 库: Array = J.or_(ctx.get("连携牌库"), [])
	for i in range(库.size() - 1, -1, -1):
		var c: Dictionary = 库[i]
		if 连携等级(c) >= 3:
			continue
		if (ctx.get("公有手牌") as Array).size() >= DeckFlow.公有上限:
			break
		库.remove_at(i)
		ctx.公有手牌.append(c)
		摘要.append("查看连携牌库 → 取到【%s】" % str(c.get("名", "")))
		if 摘要.size() >= 张数:
			break
	if 摘要.is_empty():
		摘要.append("连携牌库里没有可取的牌（三级牌除外）")
	_记(ctx, "卡里宁的判断", "、".join(摘要))
	return 摘要

static func _放诱饵(ctx: Dictionary) -> Array:
	var 位 = Flow.空位(ctx, "ally")
	if 位 == null:
		return ["没有空位，放不下诱饵"]
	ctx["诱饵"] = {"位": 位, "hp": 1.0, "剩余": 1}
	_记(ctx, "诱饵气球", "在 %s 放了一个诱饵（HP 1，持续 1 回合）" % Fm.位名(float(位)), {"位": float(位)})
	return ["诱饵：%s" % Fm.位名(float(位))]

static func _放掩体(ctx: Dictionary, hp: float) -> Array:
	if not (ctx.get("掩体") is Dictionary):
		ctx["掩体"] = {}
	for c in range(4):
		var s := float(c)
		var 占 := false
		for u in J.or_(ctx.get("allies"), []):
			if u is Dictionary and float(u.get("hp", 0.0)) > 0.0 and J.same(float(u.get("slot", -1)), s):
				占 = true
				break
		if 占:
			continue
		if not (ctx.掩体.get("ally") is Dictionary):
			ctx.掩体["ally"] = {}
		ctx.掩体["ally"][str(int(s))] = {"hp": hp, "位": s}
		_记(ctx, "野战掩体", "在我方前排 %s 生成掩体（HP %d）" % [Fm.位名(s), int(hp)], {"位": s})
		return ["掩体：%s" % Fm.位名(s)]
	return ["我方前排没有空位，放不了掩体"]

static func _阵型调整(ctx: Dictionary) -> Array:
	var 活 := Units.livingOf("ally", ctx)
	if 活.size() < 2:
		return ["只有一台机体，换不了位"]
	var a = 活[0]
	var b = 活[1]
	if BattleSwap.换位(ctx, "ally", a.get("slot"), b.get("slot"), {"来源": "阵型调整"}) != 2:
		return ["换位没有成功"]
	for u in [a, b]:
		Btl.换同源增益(u, "阵型调整", {"hit": -10.0, "剩余": 1.0})
	_记(ctx, "阵型调整", "%s / %s 换了位置（本回合这两台命中 −10）" % [str(a.get("name", "")), str(b.get("name", ""))])
	return ["%s + %s 换了位置（本回合这两台命中 −10）" % [_名(a), _名(b)]]

