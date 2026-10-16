## 边界门禁：core/ 必须是纯逻辑（迁移架构 §6.1 / §5.2 / §5.3）。
## 只看代码、不看注释与字符串；每条规则先用一个「坏样本」自检，证明它真的能抓到。
## ★ R1 新增两条硬性门禁：
##   ① 「J.* 禁令」：core/run、core/data/game_catalog.gd、session、presentation 里禁止再出现 J.* 宏调用
##      （这几个地盘是新代码；逼着后面所有 M3/M4 的代码用原生 GDScript 类型与语法）。
##   ② 「领域目录」：Db.catalog 的领域查询接口必须有货、类型正确；CardEffects.CARD_OPS 覆盖全部战术牌。
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

## ★ R1：禁止 J.* 的地盘（新代码都写在这儿；目录 + 单个文件混着写）
const J_BAN_地盘 := ["res://core/run", "res://core/data/game_catalog.gd", "res://session", "res://presentation"]
## J.* 的匹配式（JsCompat.* 不算：那是与 JS 数值语义对齐的底层工具，不是 JS 怪癖宏）
const J_BAN_式 := "\\bJ\\s*\\."

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
	_检查J禁令(t)
	_检查领域目录(t)

# ======================== ① J.* 禁令 ========================
func _检查J禁令(t) -> void:
	var files := _J_BAN_文件()
	var re := RegEx.new()
	var compiled := re.compile(J_BAN_式) == OK
	var 抓得到 := compiled and re.search("var a = J.truthy(b)") != null
	var 不误伤 := compiled and re.search("var a = JsCompat.js_round(b)") == null
	t.ok(抓得到 and 不误伤, "规则自检：J.truthy(…) 抓得到、JsCompat.js_round(…) 不误伤")
	t.ok(files.size() > 0, "J.* 禁令覆盖 %d 个脚本（%s）" % [files.size(), ", ".join(J_BAN_地盘)])
	var hits := []
	for path in files:
		var lines := _code_only(FileAccess.get_file_as_string(path)).split("\n")
		for i in lines.size():
			if re.search(lines[i]) != null:
				hits.append("%s:%d" % [path.trim_prefix("res://"), i + 1])
	t.ok(hits.is_empty(), "新地盘里没有 J.* 调用%s" % ("" if hits.is_empty() else "：" + ", ".join(hits)))

# ======================== ② 领域目录 / 卡牌效果表 ========================
func _检查领域目录(t) -> void:
	var errors := []
	DataLoader.install(errors)
	t.ok(Db.installed and errors.is_empty(), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var c := Db.catalog
	t.ok(c != null, "Db.install 顺手建好了 Db.catalog（领域数据目录）")
	if c == null:
		return
	t.ok(Db.T.size() > 0, "向后兼容的 Db.T 还在（%d 个常量）" % Db.T.size())

	t.ok(c.characters() is Dictionary and c.characters().size() == 34, "catalog.characters() = 34 名机师")
	t.ok(String(c.character("B1").get("mech")) == "B1", "catalog.character(\"B1\") 查得到")
	t.ok(c.character("不存在的键").is_empty(), "catalog.character(查不到) 给空字典，不报错")
	t.ok(c.enemies() is Dictionary and c.enemies().size() >= 20, "catalog.enemies() = %d 个敌机模板" % c.enemies().size())
	t.ok(not c.enemy("bluefish").is_empty(), "catalog.enemy(\"bluefish\") 查得到")
	t.ok(c.stages() is Array and c.stages().size() == 47, "catalog.stages() = 47 条编成")
	t.ok(not c.stage(0).is_empty() and c.stage(9999).is_empty(), "catalog.stage(0) 有货、越界给空字典")
	t.ok(c.trait_groups() is Dictionary and not c.trait_groups().is_empty(), "catalog.trait_groups() = %d 组词条" % c.trait_groups().size())
	t.ok(c.cards() is Array and c.cards().size() == 32, "catalog.cards() = 32 张战术牌")
	t.ok(String(c.card("CMD_ALL_OUT").get("id")) == "CMD_ALL_OUT", "catalog.card(\"CMD_ALL_OUT\") 查得到")
	t.ok(c.relics() is Dictionary and not c.relics().is_empty(), "catalog.relics() = %d 件藏品" % c.relics().size())
	t.ok(not c.relic("g1").is_empty(), "catalog.relic(\"g1\") 查得到")
	t.ok(c.relic_prices() is Dictionary and not c.relic_prices().is_empty(), "catalog.relic_prices() 有货")
	t.ok(c.parts() is Dictionary and c.parts().size() == 13, "catalog.parts() = 13 件零件")
	t.ok(not c.part("wheel").is_empty(), "catalog.part(\"wheel\") 查得到")
	t.ok(c.roguelike_config() is Dictionary and not c.roguelike_config().is_empty(), "catalog.roguelike_config() 有货")
	t.ok(c.squads() is Array and c.events() is Array, "catalog.squads() / events() 是数组（数据侧还没导出时为空）")
	t.ok(not c.battle_config().is_empty(), "catalog.battle_config() 有货")
	t.ok(not c.faction_config().is_empty(), "catalog.faction_config() 有货")
	t.ok(c.has("MAX_TURN") and c.raw("MAX_TURN") != null, "catalog.has / raw 能拿领域 API 没覆盖的常量")

	# 战术牌效果表：不多不少正好覆盖数据里的全部牌，而且每条都写清了「选」或「全局」
	var 缺 := []
	var 结构坏 := []
	for card in c.cards():
		var id := String(card.get("id"))
		var 组们 = CardEffects.CARD_OPS.get(id)
		if not (组们 is Array) or 组们.is_empty():
			缺.append(id)
			continue
		for 组 in 组们:
			if not (组 is Dictionary) or not (组.has("选") or 组.has("全局")):
				结构坏.append(id)
	var 多余 := []
	for id in CardEffects.CARD_OPS.keys():
		if c.card(String(id)).is_empty():
			多余.append(String(id))
	t.ok(CardEffects.CARD_OPS.size() == 32 and 缺.is_empty(),
		"CardEffects.CARD_OPS 覆盖全部 32 张战术牌%s" % ("" if 缺.is_empty() else "；缺：" + ", ".join(缺)))
	t.ok(多余.is_empty(), "CARD_OPS 里没有数据表里不存在的牌%s" % ("" if 多余.is_empty() else "：" + ", ".join(多余)))
	t.ok(结构坏.is_empty(), "CARD_OPS 每条都写清了「选」（按单位）或「全局」（只动 ctx）%s" % ("" if 结构坏.is_empty() else "：" + ", ".join(结构坏)))

# ======================== 扫描工具 ========================
func _J_BAN_文件() -> Array[String]:
	var out: Array[String] = []
	for 路径 in J_BAN_地盘:
		if 路径.ends_with(".gd"):
			if FileAccess.file_exists(路径):
				out.append(路径)
			continue
		out.append_array(_gd_files(路径))
	return out

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
