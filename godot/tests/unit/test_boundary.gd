## 边界门禁：core/ 必须是纯逻辑（迁移架构 §6.1 / §5.2 / §5.3）。
## 只看代码、不看注释与字符串；每条规则先用一个「坏样本」自检，证明它真的能抓到。
extends RefCounted

const RULES := [
	["只能继承 RefCounted / Resource / Object（不碰场景树）", "extends\\s+(?!RefCounted\\b|Resource\\b|Object\\b)\\w+", "extends Node2D"],
	["不用引擎随机数（只用 Mulberry32）", "\\b(randi|randf|randi_range|randf_range|randfn|randomize|seed)\\s*\\(|RandomNumberGenerator", "var x = randi() % 6"],
	["不用内置 round()（用 J.round / JsCompat.js_round）", "(?<![\\w.])(?<!func )round\\s*\\(", "var d = round(a * 1.5)"],
	["不用 sort / sort_custom（用 J.sort / JsCompat.stable_sort）", "(?<!\\bJ)\\.sort(_custom)?\\s*\\(", "arr.sort_custom(f)"],
	["不读时间", "\\b(Time\\.|OS\\.get_ticks|OS\\.get_unix_time)", "var now = Time.get_ticks_msec()"],
	["不读写文件 / user://", "\\b(FileAccess|DirAccess|ResourceSaver|ConfigFile)\\b", "FileAccess.open(p, 1)"],
	["不访问场景树", "\\b(get_tree|get_node|get_parent|add_child)\\s*\\(", "get_tree().quit()"],
]

func run(t) -> void:
	var files := _gd_files("res://core")
	t.ok(files.size() > 0, "core/ 下有 %d 个脚本参与扫描" % files.size())
	for rule in RULES:
		var re := RegEx.new()
		var compiled := re.compile(rule[1]) == OK
		var self_check := compiled and re.search(rule[2]) != null
		var hits := []
		for path in files:
			var lines := _code_only(FileAccess.get_file_as_string(path)).split("\n")
			for i in lines.size():
				if re.search(lines[i]) != null:
					hits.append("%s:%d" % [path.trim_prefix("res://"), i + 1])
		t.ok(self_check and hits.is_empty(), "%s%s%s" % [rule[0],
			"" if self_check else "（规则自检失败：坏样本没被抓到）",
			"" if hits.is_empty() else "：" + ", ".join(hits)])

## 去掉注释与字符串内容（保留行结构）
static func _code_only(src: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < src.length():
		var c := src[i]
		if quote != "":
			if c == "\\":
				out += "  "
				i += 2
				continue
			if c == quote:
				quote = ""
				out += c
			elif c == "\n":
				out += "\n"
			else:
				out += " "
			i += 1
			continue
		if c == "\"" or c == "'":
			quote = c
			out += c
		elif c == "#":
			while i < src.length() and src[i] != "\n":
				i += 1
			continue
		else:
			out += c
		i += 1
	return out

static func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		out.append_array(_gd_files(dir_path.path_join(d)))
	return out
