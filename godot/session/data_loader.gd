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
			consts[name] = parsed[name]
			origin[name] = file
	if not errors.is_empty():
		return null
	return GameData.new(consts, origin, str(manifest.get("来源", "")), str(manifest.get("rulesSignature", "")))

static func _read_json(path: String, errors: Array) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("找不到 %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s 解析失败：第 %d 行 %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
