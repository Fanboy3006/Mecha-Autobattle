## 职责：规则钩子注册表 —— 势力 / 职业模块只在 `顺序` 表里点名。
## 约定：模块自己判自己该不该接手（不认识的情形返回中性值）。
class_name RuleHooks
extends RefCounted

# 一、顺序表（次序 = 调用次序，不许重排）。
static var 顺序: Dictionary = {
	"开局初始化": [ColonialV01, MoonV02, ShadowV02, FactionIdentity],
	"装填单位": [ColonialV01, MoonV02, ShadowV02],
	"装填大招槽": [ColonialV01, MoonV02, ShadowV02],
	"公有扩展牌": [ColonialV01, MoonV02, ShadowV02],
	"公有牌打出": [ColonialV01, MoonV02, ShadowV02],
	"执行算子": [ColonialV01, MoonV02, ShadowV02],
	"闪避加成": [AtxThree, ColonialV01, ShadowV02],
	"命中修正": [AtxGodsbet, AtxSmoke, ClassCards, RepairCards, AtxDuo, AtxThree, CelestialV01, ColonialV01, MoonV02, ShadowV02],
	"命中修正_附加": [CelestialV01],
	"暴击修正": [AtxThree, ColonialV01, ShadowV02],
	"受击前": [AtxChips, AtxDuo, AtxThree, ColonialV01, MoonV02],
	"受击后": [ColonialV01, MoonV02],
	"攻方伤害倍率": [ClassCards, CelestialV01, ColonialV01, MoonV02, ShadowV02, FactionIdentity, FocusFire],
	"受方伤害倍率": [CelestialV01, AtxDuo, ColonialV01, MoonV02],
	"致命保留_前": [AtxChips],
	"致命保留_后": [ClassCards, ColonialV01, RepairCards],
	"武器攻击后": [ClassCards, RepairCards, AtxDuo, AtxThree, ColonialV01, MoonV02, ShadowV02, FactionIdentity, FocusFire],
	"我方阶段初_前": [FacAtx, AtxChips, AtxGodsbet, AtxSmoke],
	"我方阶段初_增援": [Flow],
	"我方阶段初_自爆": [BattleGuard],
	"我方阶段初_词条": [BattleGuard],
	"我方阶段初_势力": [Fac],
	"我方阶段初_指挥": [Flow],
	"我方阶段初_后": [ClassCards, RepairCards, AtxDuo, AtxThree, CelestialV01, ColonialV01, MoonV02, ShadowV02],
	"敌方阶段初": [AtxDuo, AtxThree, CelestialV01],
	"我方阶段末": [CelestialV01, ColonialV01],
	"换位后": [MoonV02, ShadowV02],
	"卡不可打原因": [AtxGodsbet, AtxThree, AtxChips, CelestialV01, AtxFaction, ClassCards, RepairCards, MithrilV03Cards, ColonialV01, MoonV02, ShadowV02],
	"区规则门槛": [AtxThree, AtxChips, ColonialV01],
	"合体技门槛": [AtxFaction],
	"大招费用预览": [AtxFaction],
	"大招处理者": [AtxGodsbet, AtxThree, AtxFaction, CelestialV01, ColonialV01],
	"处理者:AtxGodsbet": [AtxGodsbet],
	"处理者:AtxThree": [AtxThree],
	"处理者:AtxFaction": [AtxFaction],
	"处理者:CelestialV01": [CelestialV01],
	"处理者:ColonialV01": [ColonialV01],
	"大招打出前": [CelestialV01, AtxSmoke],
	"大招打出后": [AtxLuck],
	"大招结算后": [AtxFaction],
	"大招收尾后": [AtxChips, AtxFaction],
	"副武器门槛": [AtxThree, CelestialV01, ColonialV01, MoonV02, ShadowV02],
	"副武器特殊打出": [AtxSmoke, MoonV02, ShadowV02],
	"副武器武器实例": [CelestialV01],
	"副武器援护": [AtxThree],
	"副武器攻击前": [AtxSmoke],
	"副武器攻击后": [AtxThree],
	"副武器记账后": [CelestialV01],
	"条件值": [AtxSmoke, AtxDuo, CelestialV01, ColonialV01, MoonV02, ShadowV02],
	"可选目标": [ColonialV01],
	"AI自动出牌跳过": [ColonialV01, MoonV02, ShadowV02],
	"牌打出后": [ColonialV01, MoonV02, ShadowV02],
}

# 二、迭代
static var _方法缓存: Dictionary = {}

static func _方法名们(m: Script) -> Dictionary:
	var 键 := m.resource_path
	if 键.is_empty():
		键 = str(m.get_instance_id())
	if _方法缓存.has(键):
		return _方法缓存[键]
	var 集 := {}
	for 条 in m.get_script_method_list():
		if 条 is Dictionary:
			集[str((条 as Dictionary).get("name", ""))] = true
	_方法缓存[键] = 集
	return 集

## 实现了吗。
static func 实现了吗(m: Script, 钩子: String) -> bool:
	return _方法名们(m).has(钩子)

## 相加。
static func 汇总(钩子: String, 参: Array) -> float:
	var 总 := 0.0
	for m in 顺序.get(钩子, []):
		if 实现了吗(m, 钩子):
			总 += float(m.callv(钩子, 参))
	return 总

## 逐模块相乘（每步 `J.round`）。
static func 依次乘(钩子: String, 初值: float, 参: Array) -> float:
	var 值 := 初值
	for m in 顺序.get(钩子, []):
		if not 实现了吗(m, 钩子):
			continue
		var 倍 := float(m.callv(钩子, 参))
		if 倍 != 1.0:
			值 = J.round(值 * 倍)
	return 值

## 逐个调用。
static func 广播(钩子: String, 参: Array) -> void:
	for m in 顺序.get(钩子, []):
		if 实现了吗(m, 钩子):
			m.callv(钩子, 参)

## 把每个模块交回来的数组拼起来。
static func 收集(钩子: String, 参: Array) -> Array:
	var 出: Array = []
	for m in 顺序.get(钩子, []):
		if not 实现了吗(m, 钩子):
			continue
		var 回 = m.callv(钩子, 参)
		if 回 is Array:
			出.append_array(回)
	return 出

## 声明式算子派发：模块返回非空摘要 = 认领。
static func 执行算子(名: String, 运行: Dictionary, 表: Dictionary, 目标们: Array) -> Array:
	for m in 顺序.get("执行算子", []):
		if not 实现了吗(m, "执行算子"):
			continue
		var 回 = m.callv("执行算子", [名, 运行, 表, 目标们])
		if 回 is Array and not (回 as Array).is_empty():
			return 回
	return []

## 第一个 `终局 = true` 的模块说了算。
static func 首个结论(钩子: String, 参: Array) -> Dictionary:
	for m in 顺序.get(钩子, []):
		if not 实现了吗(m, 钩子):
			continue
		var 结 = m.callv(钩子, 参)
		if 结 is Dictionary and bool((结 as Dictionary).get("终局", false)):
			return 结
	return {"终局": false, "原因": ""}

# 三、按处理者分派（槽上的 `处理者` = 模块名）
## 这个槽归谁：先认 `处理者`，没写就问 `大招处理者`，认领了就补写。
static func 识别大招处理者(ctx: Variant, u: Variant, 槽: Variant) -> String:
	if not (槽 is Dictionary):
		return ""
	var 处 := str((槽 as Dictionary).get("处理者", ""))
	if 处 != "":
		return 处
	for m in 顺序.get("大招处理者", []):
		if not 实现了吗(m, "认领大招槽"):
			continue
		var 名 := str(m.callv("认领大招槽", [ctx, u, 槽]))
		if 名 != "":
			(槽 as Dictionary)["处理者"] = 名
			return 名
	return ""

## 交给处理者；没这个处理者 / 它没实现这个钩子 → `null`（调用方走通用逻辑）。
static func 按处理者(处理者: String, 钩子: String, 参: Array) -> Variant:
	if 处理者 == "":
		return null
	for m in 顺序.get("处理者:" + 处理者, []):
		if 实现了吗(m, 钩子):
			return m.callv(钩子, 参)
	return null
