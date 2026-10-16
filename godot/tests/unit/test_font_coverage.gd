## 字体覆盖：工程里出现的每个中文字符，打包的字体子集里都要有（否则 Web 版显示方框）。
## 缺字时运行 python godot/tools/build_font_subset.py 重新生成子集。
extends RefCounted

const FONT_PATH := "res://assets/fonts/NotoSansSC-Subset.otf"
const TEXT_EXT := ["gd", "tscn", "tres", "json", "cfg", "godot"]
const SKIP_DIRS := [".godot", "build", "tools"]

func run(t) -> void:
	t.ok(ProjectSettings.get_setting("gui/theme/custom_font", "") == FONT_PATH,
		"项目默认字体 = %s" % FONT_PATH)
	var font: FontFile = load(FONT_PATH)
	t.ok(font != null, "字体子集能加载")
	if font == null:
		return
	var seen := {}
	for path in _text_files("res://"):
		var s := FileAccess.get_file_as_string(path)
		for i in s.length():
			var code := s.unicode_at(i)
			if code >= 0x2E80:
				seen[code] = true
	var missing := []
	for code in seen.keys():
		if not font.has_char(code):
			missing.append(String.chr(code))
	t.ok(missing.is_empty(), "工程里的 %d 个中文字符字体全部覆盖%s" % [seen.size(),
		"" if missing.is_empty() else "；缺：" + "".join(missing.slice(0, 40))])

func _text_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension() in TEXT_EXT:
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if d in SKIP_DIRS:
			continue
		out.append_array(_text_files(dir_path.path_join(d)))
	return out
