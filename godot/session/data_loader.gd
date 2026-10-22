## 从 res://data/js/ 与 res://data/cards/ 读入全部数据，构造 GameData。IO 只在这里发生（core/ 不读文件）。
class_name DataLoader
extends RefCounted

const DATA_DIR := "res://data/js"
## 卡包目录：自动扫描 `res://data/cards/*.json`，按文件名排序装入 `Db.T.卡包[<包名>]`。
const CARD_DIR := "res://data/cards"
## 卡包顶层必须有的元数据键 → 类型；实际卡组段由各卡包在 `"结构"` 里自己声明。
const 卡包必需 := {
	"势力": TYPE_STRING, "结构": TYPE_DICTIONARY,
}
## `"结构"` 支持的段类型清单（未知类型当场报错，不按势力名写特判）。
const 结构类型们 := ["卡组", "分人卡组", "单卡", "武器表"]

## 读失败返回 null，并把原因写进 errors
static func load_game_data(errors: Array = []) -> GameData:
	var manifest = _read_json(DATA_DIR.path_join("manifest.json"), errors)
	if not manifest is Dictionary:
		return null
	var consts := {}
	var origin := {}
	var files: Dictionary = manifest.get("文件", {})
	for file in files.keys():
		var parsed = _read_json(DATA_DIR.path_join(file), errors)
		if not parsed is Dictionary:
			continue
		for name in files[file]:
			if not parsed.has(name):
				errors.append("%s 里缺少常量 %s" % [file, name])
				continue
			consts[name] = _decode(parsed[name])
			origin[name] = file
	var 卡包 := _load_card_packs(errors)
	if not errors.is_empty():
		return null
	consts["卡包"] = 卡包
	origin["卡包"] = CARD_DIR
	return GameData.new(consts, origin, str(manifest.get("来源", "")), str(manifest.get("rulesSignature", "")))

## 读入并装进 Db（会话启动与测试共用）；失败返回 false，原因写进 errors
static func install(errors: Array = []) -> bool:
	var data := load_game_data(errors)
	if data == null:
		return false
	Db.install(data)
	_读构建信息()
	return true

## ★ 构建信息（可选）：CI / 导出脚本写的 `data/build_info.json`；没有这个文件 = 本地开发版。
static func _读构建信息() -> void:
	GameVersion.构建 = {}
	var 路径 := "res://data/build_info.json"
	if not FileAccess.file_exists(路径):
		return
	var 读 = _read_json(路径, [])
	GameVersion.构建 = 读 if 读 is Dictionary else {}

## 扫描并读入全部卡包（缺文件 / 解析失败 / 缺键 / id 重复都进 errors，由调用方整单失败）
static func _load_card_packs(errors: Array) -> Dictionary:
	var 包们 := {}
	var 全id := {}
	var 文件们 := _扫描卡包文件(errors)
	for 文件名 in 文件们:
		var 势力 := str(文件名).get_basename()
		var 路径: String = CARD_DIR.path_join(str(文件名))
		var 包 = _read_json(路径, errors)
		if not 包 is Dictionary:
			continue
		_检查卡包(势力, 包, 全id, errors)
		包们[势力] = 包
	return 包们

static func _扫描卡包文件(errors: Array) -> Array:
	var dir := DirAccess.open(CARD_DIR)
	if dir == null:
		errors.append("打不开卡包目录 %s" % CARD_DIR)
		return []
	var 文件们: Array = []
	dir.list_dir_begin()
	var 名 := dir.get_next()
	while 名 != "":
		if not dir.current_is_dir() and 名.ends_with(".json"):
			文件们.append(名)
		名 = dir.get_next()
	dir.list_dir_end()
	文件们.sort()
	if 文件们.is_empty():
		errors.append("%s 下没有任何 .json 卡包文件" % CARD_DIR)
	return 文件们

static func _检查卡包(势力: String, 包: Dictionary, 全id: Dictionary, errors: Array) -> void:
	for k in 卡包必需.keys():
		if not 包.has(k):
			errors.append("%s 卡包缺少顶层键「%s」（%s）" % [势力, k, CARD_DIR])
		elif typeof(包[k]) != 卡包必需[k]:
			errors.append("%s 卡包的「%s」类型不对：期望 %s，实际 %s"
				% [势力, k, type_string(卡包必需[k]), type_string(typeof(包[k]))])
	var 结构 = 包.get("结构")
	if not (结构 is Dictionary) or (结构 as Dictionary).is_empty():
		errors.append("%s 卡包的「结构」是空的" % 势力)
		return
	for 段名 in (结构 as Dictionary).keys():
		var 类型 := str(结构[段名])
		if not (类型 in 结构类型们):
			errors.append("%s 卡包的「结构.%s」使用了未知类型「%s」" % [势力, 段名, 类型])
			continue
		if not 包.has(段名):
			errors.append("%s 卡包缺少结构声明的顶层键「%s」" % [势力, 段名])
			continue
		var 值 = 包[段名]
		match 类型:
			"卡组":
				_检查条目们(势力, str(段名), 值, 全id, errors)
			"分人卡组":
				if not (值 is Dictionary) or (值 as Dictionary).is_empty():
					errors.append("%s 卡包的「%s」不是非空字典" % [势力, 段名])
				else:
					for 键 in (值 as Dictionary).keys():
						_检查条目们(势力, "%s.%s" % [段名, 键], 值[键], 全id, errors)
			"单卡":
				if not (值 is Dictionary) or not 值.has("id") or not 值.has("名"):
					errors.append("%s 卡包的「%s」不是带 id / 名的单卡字典" % [势力, 段名])
				else:
					_登记卡id(势力, str(段名), 值, 全id, errors)
			"武器表":
				if not ((值 is Dictionary and not (值 as Dictionary).is_empty())
					or (值 is Array and not (值 as Array).is_empty())):
					errors.append("%s 卡包的「%s」是空的" % [势力, 段名])

## 一组卡至少一条，且每条都得有 id / 名，并做全局 id 唯一检查
static func _检查条目们(势力: String, 表名: String, 条目们: Variant, 全id: Dictionary, errors: Array) -> void:
	if not (条目们 is Array) or (条目们 as Array).is_empty():
		errors.append("%s 卡包的「%s」是空的" % [势力, 表名])
		return
	for 条 in 条目们:
		if not (条 is Dictionary) or not 条.has("id") or not 条.has("名"):
			errors.append("%s 卡包的「%s」里有条目缺 id / 名" % [势力, 表名])
			return
		_登记卡id(势力, 表名, 条, 全id, errors)

static func _登记卡id(势力: String, 表名: String, 条: Dictionary, 全id: Dictionary, errors: Array) -> void:
	if bool(条.get("复用", false)):
		return
	var id := str(条.get("id", ""))
	var 位置 := "%s.%s" % [势力, 表名]
	if id == "":
		errors.append("%s 里有空 id" % 位置)
		return
	if 全id.has(id):
		errors.append("卡包卡 id 重复：「%s」同时出现在 %s 与 %s" % [id, 全id[id], 位置])
		return
	全id[id] = 位置
	var 加 = 条.get("+")
	if 加 is Dictionary:
		var 加id := str((加 as Dictionary).get("id", id + "+"))
		if 全id.has(加id):
			errors.append("卡包 + 版卡 id 重复：「%s」同时出现在 %s 与 %s(+)" % [加id, 全id[加id], 位置])
		else:
			全id[加id] = 位置 + "(+)"

## 数据里 JSON 存不了的数（Infinity / NaN）按 {"$f": IEEE-754 位串} 存，这里还原
static func _decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.size() == 1 and v.has("$f"):
			var b := PackedByteArray()
			for i in 8:
				b.append(String(v["$f"]).substr(i * 2, 2).hex_to_int())
			return b.decode_double(0)
		for key in v.keys():
			v[key] = _decode(v[key])
		return v
	if v is Array:
		for i in v.size():
			v[i] = _decode(v[i])
		return v
	return v

static func _read_json(path: String, errors: Array) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("找不到 %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s 解析失败：第 %d 行 %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
