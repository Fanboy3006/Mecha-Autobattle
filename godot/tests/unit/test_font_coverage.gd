## 字体覆盖：工程里会上屏的每个非 ASCII 字符（汉字、标点、符号、emoji），项目字体或它的后备字体里都要有。
## 否则 Web 版显示方框（Web 没有系统字体可借）。缺字时运行 python godot/tools/build_font_subset.py。
extends RefCounted

const FONT_PATH := "res://assets/fonts/ui_font.tres"
const TEXT_EXT := ["gd", "tscn", "tres", "json", "cfg", "godot"]
const SKIP_DIRS := [".godot", "build", "tools", "tests"]   # tests 只在控制台输出，不上屏

func run(t) -> void:
	t.ok(ProjectSettings.get_setting("gui/theme/custom_font", "") == FONT_PATH, "项目默认字体 = %s" % FONT_PATH)
	var font: Font = load(FONT_PATH)
	t.ok(font != null, "项目字体能加载")
	if font == null:
		return
	var chain: Array[Font] = [font]
	if font is FontVariation and font.base_font != null:
		chain = [font.base_font]
	chain.append_array(font.fallbacks)
	t.info("字体链：%s" % ", ".join(chain.map(func(f): return f.resource_path.get_file())))

	var seen := {}
	for path in _text_files("res://"):
		var s := FileAccess.get_file_as_string(path)
		for i in s.length():
			var code := s.unicode_at(i)
			if code > 0x7F and code != 0xFEFF and not (code >= 0xFE00 and code <= 0xFE0F):   # 跳过 BOM 与变体选择符
				seen[code] = true
	var missing := []
	for code in seen.keys():
		if not chain.any(func(f): return f.has_char(code)):
			missing.append(String.chr(code))
	t.ok(missing.is_empty(), "会上屏的 %d 个非 ASCII 字符全部有字形%s" % [seen.size(),
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
