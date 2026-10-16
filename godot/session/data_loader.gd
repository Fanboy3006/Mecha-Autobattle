## 从 res://data/js/ 读入全部数据，构造 GameData。IO 只在这里发生（core/ 不读文件）。
class_name DataLoader
extends RefCounted

const DATA_DIR := "res://data/js"

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
	if not errors.is_empty():
		return null
	return GameData.new(consts, origin, str(manifest.get("来源", "")), str(manifest.get("rulesSignature", "")))

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

## 读入并装进 Db（会话启动与测试共用）；失败返回 false，原因写进 errors
static func install(errors: Array = []) -> bool:
	var data := load_game_data(errors)
	if data == null:
		return false
	Db.install(data)
	return true

static func _read_json(path: String, errors: Array) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("找不到 %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s 解析失败：第 %d 行 %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
