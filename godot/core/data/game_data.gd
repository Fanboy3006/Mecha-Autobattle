## 全部内容数据与规则参数的只读容器（纯逻辑，不做任何 IO）。
## 由 session/data_loader.gd 从 res://data/js/*.json 读入后构造；内核只通过这里取数。
class_name GameData
extends RefCounted

var source: String = ""            # 来源说明（JS 参考版版本）
var rules_signature: String = ""   # JS 参考版的规则签名
var _consts: Dictionary = {}       # 常量名 → 值
var _origin: Dictionary = {}       # 常量名 → 来源片段（排错用）

func _init(consts: Dictionary, origin: Dictionary, src: String, signature: String) -> void:
	_consts = consts
	_origin = origin
	source = src
	rules_signature = signature

func has(name: String) -> bool:
	return _consts.has(name)

## 取一个常量；不存在时报错并返回 null（数据缺失必须当场暴露，不能静默用默认值）
func get_const(name: String) -> Variant:
	if not _consts.has(name):
		push_error("GameData：没有常量 %s" % name)
		return null
	return _consts[name]

func origin_of(name: String) -> String:
	return _origin.get(name, "")

func names() -> Array:
	return _consts.keys()

## 全部常量（Db.install 用；调用方只读）
func consts() -> Dictionary:
	return _consts
