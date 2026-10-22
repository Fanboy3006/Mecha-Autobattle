## 领域数据目录：把「常量名 → 值」的扁平常量表包装成按领域分类的强语义只读查询 API。
## 由 Db.install(data) 自动构建（Db.catalog）；M3/M4 的新代码只从这里取数据，不再自己记常量名。
## 本文件受 tests/unit/test_boundary.gd 的「J.* 禁令」约束：只用原生 GDScript 类型与语法。
## 注意：返回的都是底层表的**只读引用**（不深拷贝）；调用方一律不要改。
class_name GameCatalog
extends RefCounted

# ---------------- 领域 → 常量名（改数据名只动这一处；常量清单见 res://data/js/manifest.json） ----------------
const 名_角色 := "ALLY_T"
const 名_敌人 := "ENEMY_T"
const 名_敌人梯队 := "ENEMY_TIER"
const 名_编成 := "编成表"
const 名_词条组 := "词条组表"
const 名_卡牌 := "战术卡牌表"
const 名_藏品 := "藏品表"
const 名_藏品价格 := "藏品价格"
const 名_零件 := "零件表"
const 名_肉鸽 := "肉鸽数值"
const 名_分队 := "分队表"
const 名_事件 := "事件表"
const 名_战斗结构 := "战斗结构"
const 名_势力 := "势力特色"

## 角色表的主键字段（ALLY_T 是数组，条目里拿 mech 当键）
const 角色键 := "mech"
## 战术卡牌表的主键字段
const 卡牌键 := "id"

var _tables: Dictionary = {}
var _角色索引: Dictionary = {}

func _init(tables: Dictionary) -> void:
	_tables = tables

# ======================== 通用取数 ========================
func has(常量名: String) -> bool:
	return _tables.has(常量名)

## 逃生口：领域 API 还没覆盖到的常量（如 KIND_MELEE / 阵型）从这里拿原始值
func raw(常量名: String) -> Variant:
	return _tables.get(常量名)

func _字典(常量名: String) -> Dictionary:
	var v: Variant = _tables.get(常量名)
	return v if v is Dictionary else {}

func _数组(常量名: String) -> Array:
	var v: Variant = _tables.get(常量名)
	return v if v is Array else []

func _取(常量名: String, id: String) -> Dictionary:
	var v: Variant = _字典(常量名).get(id)
	return v if v is Dictionary else {}

## 在数组型表里按主键字段找一条（找不到给空字典，不报错）
static func _按字段找(表: Array, 字段: String, id: String) -> Dictionary:
	for t in 表:
		if t is Dictionary and String(t.get(字段)) == id:
			return t
	return {}

# ======================== 角色 / 敌人 ========================
## 我方机师：id（= 条目的 mech）→ 条目
func characters() -> Dictionary:
	if _角色索引.is_empty():
		for t in _数组(名_角色):
			if t is Dictionary and t.get(角色键) != null:
				_角色索引[String(t[角色键])] = t
	return _角色索引

func character(id: String) -> Dictionary:
	var v: Variant = characters().get(id)
	return v if v is Dictionary else {}

## 敌方单位表：id → 条目
func enemies() -> Dictionary:
	return _字典(名_敌人)

func enemy(id: String) -> Dictionary:
	return _取(名_敌人, id)

## 敌方梯队表（键 → 梯队名），给分级 / 强度换算用
func enemy_tiers() -> Dictionary:
	return _字典(名_敌人梯队)

# ======================== 编成 / 词条 ========================
## 编成表（关卡敌人编成，数组，按数据顺序）
func stages() -> Array:
	return _数组(名_编成)

## 一条编成；越界给空字典
func stage(index: int) -> Dictionary:
	var 表 := stages()
	if index < 0 or index >= 表.size():
		return {}
	var t: Variant = 表[index]
	return t if t is Dictionary else {}

## 词条组表：编成里的「挂载」键 → 词条数组
func trait_groups() -> Dictionary:
	return _字典(名_词条组)

func trait_group(id: String) -> Array:
	var v: Variant = trait_groups().get(id)
	return v if v is Array else []

# ======================== 战术卡牌 ========================
## 战术卡牌表（数组，按数据顺序 = 发牌顺序）
func cards() -> Array:
	return _数组(名_卡牌)

func card(id: String) -> Dictionary:
	return _按字段找(cards(), 卡牌键, id)

# ======================== 藏品 / 零件 ========================
## 藏品表：id → 条目
func relics() -> Dictionary:
	return _字典(名_藏品)

func relic(id: String) -> Dictionary:
	return _取(名_藏品, id)

## 藏品价格
func relic_prices() -> Dictionary:
	return _字典(名_藏品价格)

## 零件表：id → 条目
func parts() -> Dictionary:
	return _字典(名_零件)

func part(id: String) -> Dictionary:
	return _取(名_零件, id)

# ======================== 肉鸽 / 分队 / 事件 ========================
func roguelike_config() -> Dictionary:
	return _字典(名_肉鸽)

## 分队表（数据侧还没导出时是空数组，读的地方要能容忍）
func squads() -> Array:
	return _数组(名_分队)

## 奇遇事件表（函数型数据还在 JS 侧，没导出时是空数组）
func events() -> Array:
	return _数组(名_事件)

# ======================== 规则参数 ========================
## 战斗结构（全部战斗规则参数的根）
func battle_config() -> Dictionary:
	return _字典(名_战斗结构)

## 势力特色参数：势力名 → 参数
func faction_config() -> Dictionary:
	return _字典(名_势力)
