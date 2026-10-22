## 职责：武器卡拖拽状态机、吸附判定、瞄准线数据与鼠标接线（`_process` 心跳）。
extends RefCounted

static func _必须拖动到友军(宿主, c: Dictionary, 区: String = "") -> bool:
	if c.is_empty():
		return false
	if 宿主._拖拽目标方(c) != 宿主.我方:
		return false
	return 宿主.可拖拽释放(c, 区 if not 区.is_empty() else str(c.get("区", "")))

## 这张牌能不能「按住拖动、松手落在目标机体卡上」。
static func 可拖拽释放(宿主, c: Dictionary, 区: String) -> bool:
	if not bool(c.get("可打", false)):
		return false
	var 方 := str(c.get("目标方", ""))
	if 方 == "无":
		return false
	if 方 == "友方" or 方 == "敌方":
		return not bool(c.get("单机牌组_铁壁", false))
	if 宿主._卡目标方(c, 区) == "无":
		return 区 == "公有牌" and bool(c.get("是衍生", false))
	return not bool(c.get("单机牌组_铁壁", false))

static func _拖拽目标方(宿主, c: Dictionary) -> String:
	match str(c.get("目标方", "")):
		"友方":
			return 宿主.我方
		"敌方":
			return 宿主.敌方
	return 宿主.我方 if 宿主._卡目标方(c, str(c.get("区", ""))) == "友方" else 宿主.敌方

static func _卡目标方(宿主, c: Dictionary, 区: String) -> String:
	var 方 := str(c.get("目标方", ""))
	if not 方.is_empty():
		return 方
	if 宿主.session == null:
		return ""
	return 宿主.session.卡目标方(c, 区)

static func _拥有者位(宿主) -> int:
	var 键 = str(宿主.session.selected_unit_id) if 宿主.session != null else ""
	if 键.is_empty():
		return -1
	for i in 宿主._我方卡.size():
		var 卡: Variant = 宿主._我方卡[i]
		if 卡 is UnitCard and str((卡 as UnitCard).数据.get("键", "")) == 键:
			return i
	return -1

static func _拥有者卡(宿主) -> UnitCard:
	var i = 宿主._拥有者位()
	return 宿主._卡(宿主.我方, i) if i >= 0 else null

static func _单机卡数据(宿主, 键: String) -> Dictionary:
	for 卡 in 宿主.手牌卡控件们(true) + 宿主.手牌卡控件们(false):
		var c: Variant = (卡 as Node).get_meta("unit_card_data")
		if c is Dictionary and (str((c as Dictionary).get("手牌键", "")) == 键
				or str((c as Dictionary).get("名", "")) == 键):
			return c
	return {}

static func _卡心全局(宿主, 卡: Variant) -> Vector2:
	if not (卡 is Control) or not is_instance_valid(卡):
		return Vector2.ZERO
	var r: Rect2 = (卡 as Control).get_global_rect()
	return r.position + r.size * 0.5

static func _到特效层(宿主, 全局点: Vector2) -> Vector2:
	if 宿主._战斗动画层 is Control and is_instance_valid(宿主._战斗动画层):
		return (宿主._战斗动画层 as Control).get_global_transform().affine_inverse() * 全局点
	return 全局点

static func _命中机体卡(宿主, 全局点: Vector2, 方: String = "") -> Dictionary:
	var 边们: Array = []
	if 方.is_empty() or 方 == 宿主.我方:
		边们.append(宿主.我方)
	if 方.is_empty() or 方 == 宿主.敌方:
		边们.append(宿主.敌方)
	for 边 in 边们:
		var 池: Array = 宿主._我方卡 if str(边) == 宿主.我方 else 宿主._敌方卡
		for i in 池.size():
			var 卡: Variant = 池[i]
			if not (卡 is UnitCard) or not is_instance_valid(卡):
				continue
			var d: Dictionary = (卡 as UnitCard).数据
			if not bool(d.get("ok", false)):
				continue
			if float(d.get("HP", 0.0)) <= 0.0:
				continue
			if (卡 as Control).get_global_rect().has_point(全局点):
				return {"方": str(边), "位": i, "键": str(d.get("键", "")), "卡": 卡}
	return {}

static func _我方卡By键(宿主, 键: String) -> UnitCard:
	if 键.is_empty():
		return null
	for 卡 in 宿主._我方卡:
		if 卡 is UnitCard and is_instance_valid(卡) and str((卡 as UnitCard).数据.get("键", "")) == 键:
			return 卡
	return null

static func _拖拽起点卡(宿主) -> UnitCard:
	for 键 in [str(宿主._拖拽牌.get("所属键", "")), str(宿主._拖拽牌.get("发动键", ""))]:
		if 键.is_empty():
			continue
		var 卡 = 宿主._我方卡By键(键)
		if 卡 != null:
			return 卡
	return 宿主._拥有者卡()

static func _拖拽起点(宿主) -> Vector2:
	var 起卡 = 宿主._拖拽起点卡()
	if 起卡 != null and is_instance_valid(起卡):
		return 宿主._卡心全局(起卡)
	if 宿主._拖拽卡控件 != null and is_instance_valid(宿主._拖拽卡控件):
		return 宿主._卡心全局(宿主._拖拽卡控件)
	return 宿主._拖拽按住点

## 当前瞄准线的**数据**（自动化测试与 `_刷新瞄准()` 都读它；不在瞄准 = 空字典）。
static func 拖拽瞄准线(宿主) -> Dictionary:
	if not 宿主._拖拽已启动 or 宿主._拖拽区.is_empty():
		return {}
	var 起卡: Variant = 宿主._拖拽起点卡()
	var 止卡: Variant = 宿主._卡(宿主._拖拽吸附方, 宿主._拖拽吸附位) if 宿主._拖拽吸附位 >= 0 else null
	var 维修 = 宿主._拖拽目标方(宿主._拖拽牌) == 宿主.我方
	return {
		"显示": true,
		"起始卡": 起卡,
		"终止卡": 止卡,
		"起点": 宿主._拖拽起点(),
		"终点": 宿主._卡心全局(止卡) if 止卡 != null else 宿主._拖拽当前点,
		"颜色": 宿主.瞄准色_维修 if 维修 else 宿主.瞄准色_攻击,
		"类型": "瞄准",
		"吸附": 止卡 != null,
		"目标键": 宿主._拖拽吸附键,
		"目标方": 宿主._拖拽吸附方,
		"维修": 维修,
		"区": 宿主._拖拽区,
		"牌": str(宿主._拖拽牌.get("名", 宿主._拖拽键)),
		"宽": 4.0,
	}

static func _刷新瞄准(宿主) -> void:
	if 宿主._战斗动画层 == null or not is_instance_valid(宿主._战斗动画层):
		return
	var 线 = 宿主.拖拽瞄准线()
	if 线.is_empty():
		宿主._战斗动画层.set_aim({})
		return
	宿主._战斗动画层.set_aim({
		"起点卡": 线.get("起始卡"),
		"终点卡": 线.get("终止卡"),
		"起点": 宿主._到特效层(线.get("起点", Vector2.ZERO)),
		"终点": 宿主._到特效层(线.get("终点", Vector2.ZERO)),
		"颜色": 线.get("颜色", 宿主.瞄准色_攻击),
		"吸附": bool(线.get("吸附", false)),
		"维修": bool(线.get("维修", false)),
		"牌": str(线.get("牌", "")),
	})

## 按下（「按住一张武器卡」）：记下起点与牌，**先不进瞄准**（要移动超过 `拖拽阈值` 才画线）。
static func 开始拖拽(宿主, 区: String, 键: String, 上排: bool, 全局点: Vector2, 牌: Dictionary = {},
		卡控件: Control = null) -> Dictionary:
	var c := 牌
	if c.is_empty():
		c = 宿主._单机卡数据(键)
	if not 宿主.可拖拽释放(c, 区):
		宿主._清拖拽状态()
		return {"可拖拽": false, "牌": str(c.get("名", 键)), "起卡": null,
			"原因": "这张牌不走拖动释放（点一下就打，或现在打不出来）"}
	宿主._拖拽区 = 区
	宿主._拖拽键 = 键
	宿主._拖拽上排 = 上排
	宿主._拖拽牌 = c
	宿主._拖拽卡控件 = 卡控件
	宿主._拖拽按住点 = 全局点
	宿主._拖拽当前点 = 全局点
	宿主._拖拽已启动 = false
	宿主._吸附到({})
	if 宿主._拖拽目标方(c) == 宿主.我方:
		宿主._亮友军可投放()
	宿主._刷新瞄准()
	return {"可拖拽": true, "牌": str(c.get("名", 键)), "起卡": 宿主._拖拽起点卡(), "原因": ""}

## 拖动中：更新终点 → 超过 `拖拽阈值` 才真的进瞄准；鼠标落在目标机体卡上就**吸附 + 高亮**。
static func 拖拽到(宿主, 全局点: Vector2) -> Dictionary:
	if 宿主._拖拽区.is_empty():
		return {"拖拽中": false, "已启动": false}
	宿主._拖拽当前点 = 全局点
	if not 宿主._拖拽已启动 and 全局点.distance_to(宿主._拖拽按住点) > 宿主.拖拽阈值:
		宿主._拖拽已启动 = true
	if not 宿主._拖拽已启动:
		return {"拖拽中": true, "已启动": false, "终点": 全局点, "吸附": false, "目标键": "", "目标方": ""}
	if 宿主._拖拽目标方(宿主._拖拽牌) == 宿主.我方 and not 宿主._友军目标亮着:
		宿主._亮友军可投放()
	var 命 = 宿主._命中机体卡(全局点, 宿主._拖拽目标方(宿主._拖拽牌))
	宿主._吸附到(命)
	宿主._刷新瞄准()
	return {"拖拽中": true, "已启动": true, "终点": 全局点,
		"吸附": not 命.is_empty(), "目标键": str(命.get("键", "")), "目标方": str(命.get("方", ""))}

## 松手：拖到目标机体卡上 → **指定目标释放**；空白处 → 取消；没拖过 8px → 交给点击老路。
static func 结束拖拽(宿主, 全局点: Vector2) -> Dictionary:
	if 宿主._拖拽区.is_empty():
		return {"释放": false, "原因": "没有正在拖的牌"}
	var 区 = 宿主._拖拽区
	var 键 = 宿主._拖拽键
	var 上排 = 宿主._拖拽上排
	var 真拖 = 宿主._拖拽已启动
	var 方 = 宿主._拖拽目标方(宿主._拖拽牌)
	宿主._拖拽当前点 = 全局点
	var 命 = 宿主._命中机体卡(全局点, 方) if 真拖 else {}
	宿主._清拖拽状态()
	if not 真拖:
		return {"释放": false, "原因": "原地轻点（没拖动超过 %dpx）→ 交给点击出牌" % int(宿主.拖拽阈值)}
	if 命.is_empty():
		宿主._回话("拖到了空白处：这一张不出（要落在%s的机体卡上松手）"
			% ("我方" if 方 == 宿主.我方 else "敌方"), false)
		宿主.refresh()
		return {"释放": false, "原因": "松手位置不在可选的机体卡上"}
	var 目标键 = str(命.get("键", ""))
	var r = 宿主._打单机卡(区, 键, 上排, 目标键)
	return {"释放": true, "目标键": 目标键, "目标方": str(命.get("方", "")), "结果": r}

## 取消这次拖拽（Esc / 拖到空白处 / 换场）。
static func 取消拖拽(宿主) -> void:
	宿主._清拖拽状态()

## 现在是不是正在拖动瞄准（自动化测试读它）。
static func 拖拽中(宿主) -> bool:
	return 宿主._拖拽已启动 and not 宿主._拖拽区.is_empty()

## 按住点是哪个全局坐标（测试用）。
static func 拖拽按住点(宿主) -> Vector2:
	return 宿主._拖拽按住点

static func _吸附到(宿主, 命: Dictionary) -> void:
	var 新方 := str(命.get("方", ""))
	var 新位 := int(命.get("位", -1))
	if 新方 == 宿主._拖拽吸附方 and 新位 == 宿主._拖拽吸附位:
		return
	if 宿主._拖拽吸附位 >= 0:
		var 旧: Variant = 宿主._卡(宿主._拖拽吸附方, 宿主._拖拽吸附位)
		if 旧 is UnitCard and is_instance_valid(旧):
			(旧 as UnitCard).set_aim_highlight(false)
	宿主._拖拽吸附方 = ""
	宿主._拖拽吸附位 = -1
	宿主._拖拽吸附键 = ""
	if 新位 >= 0:
		var 卡: Variant = 宿主._卡(新方, 新位)
		if 卡 is UnitCard and is_instance_valid(卡):
			(卡 as UnitCard).set_aim_highlight(true, 宿主._拖拽目标方(宿主._拖拽牌) == 宿主.我方)
			宿主._拖拽吸附方 = 新方
			宿主._拖拽吸附位 = 新位
			宿主._拖拽吸附键 = str(命.get("键", ""))

static func _清拖拽状态(宿主) -> void:
	if 宿主._拖拽吸附位 >= 0:
		var 旧: Variant = 宿主._卡(宿主._拖拽吸附方, 宿主._拖拽吸附位)
		if 旧 is UnitCard and is_instance_valid(旧):
			(旧 as UnitCard).set_aim_highlight(false)
	宿主._拖拽吸附方 = ""
	宿主._拖拽吸附位 = -1
	宿主._拖拽吸附键 = ""
	宿主._拖拽区 = ""
	宿主._拖拽键 = ""
	宿主._拖拽上排 = true
	宿主._拖拽牌 = {}
	宿主._拖拽已启动 = false
	宿主._拖拽卡控件 = null
	宿主._灭友军可投放()
	if 宿主._战斗动画层 != null and is_instance_valid(宿主._战斗动画层):
		宿主._战斗动画层.set_aim({})

static func _单机卡按下(宿主, 区: String, 键: String, 上排: bool, 卡: Control) -> void:
	var c: Dictionary = {}
	if 卡 != null and is_instance_valid(卡) and 卡.has_meta("unit_card_data"):
		var v: Variant = 卡.get_meta("unit_card_data")
		if v is Dictionary:
			c = v
	宿主.开始拖拽(区, 键, 上排, 宿主._鼠标全局(), c, 卡)

static func _process(宿主, dt: float) -> void:
	if 宿主._友军提示秒 > 0.0 and 宿主._拖拽区.is_empty():
		宿主._友军提示秒 = maxf(0.0, 宿主._友军提示秒 - dt)
		if 宿主._友军提示秒 <= 0.0:
			宿主._灭友军可投放()
	if 宿主._拖拽区.is_empty():
		return
	宿主.拖拽到(宿主._鼠标全局())

static func _单机卡松开(宿主, _区: String, _键: String, _上排: bool, _卡: Control) -> void:
	if 宿主._拖拽区.is_empty():
		return
	宿主.结束拖拽(宿主._鼠标全局())

static func _悬停单机卡(宿主, 卡: Variant) -> void:
	if not (卡 is Control) or not is_instance_valid(卡):
		return
	宿主.联动高亮(宿主._拥有者位名们(), true)

static func _移开单机卡(宿主) -> void:
	宿主.联动高亮([], false)

static func _拥有者位名们(宿主) -> Array:
	var i = 宿主._拥有者位()
	return [] if i < 0 else [Fm.位名(float(i))]

static func _鼠标全局(宿主) -> Vector2:
	if 宿主.is_inside_tree():
		return 宿主.get_global_mouse_position()
	return 宿主._拖拽按住点
