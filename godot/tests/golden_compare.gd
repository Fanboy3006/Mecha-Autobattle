## 黄金样例比对器（测试专用）。M2 起 Battle Core 的输出用它与 JS 导出的期望逐项比对。
## 只报告「第一处分叉」：在哪个事件 / 哪个回合摘要、哪个字段、当时随机数抽到第几次。
class_name GoldenCompare
extends RefCounted

## 把 {"$f": 位串} 还原成 float；其余原样（递归）
static func decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.size() == 1 and v.has("$f"):
			return GoldenIO.bits_to_float(v["$f"])
		var o := {}
		for k in v.keys():
			o[k] = decode(v[k])
		return o
	if v is Array:
		return v.map(func(x): return decode(x))
	return v

## 深比较；返回 "" 表示相同，否则返回第一处不同的路径与两边的值。
## 数字一律按 float 比较（Godot 的 JSON 把整数也解析成 float；JS 的数本来就是双精度）。
static func diff(expected: Variant, actual: Variant, path: String = "") -> String:
	if (expected is int or expected is float) and (actual is int or actual is float):
		return "" if float(expected) == float(actual) else "%s：期望 %s，实际 %s" % [path, expected, actual]
	if typeof(expected) != typeof(actual):
		return "%s：类型不同（期望 %s，实际 %s）" % [path, type_string(typeof(expected)), type_string(typeof(actual))]
	if expected is Dictionary:
		var keys := {}
		for k in expected.keys():
			keys[k] = true
		for k in actual.keys():
			keys[k] = true
		var sorted := keys.keys()
		sorted.sort()
		for k in sorted:
			if not expected.has(k):
				return "%s.%s：实际多出这个字段" % [path, k]
			if not actual.has(k):
				return "%s.%s：实际缺少这个字段" % [path, k]
			var d := diff(expected[k], actual[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	if expected is Array:
		for i in mini(expected.size(), actual.size()):
			var d := diff(expected[i], actual[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		if expected.size() != actual.size():
			return "%s：长度不同（期望 %d，实际 %d）" % [path, expected.size(), actual.size()]
		return ""
	return "" if expected == actual else "%s：期望 %s，实际 %s" % [path, expected, actual]

## 比对一场战斗：events = 实际事件数组（已解码），sample = 黄金样例（未解码）。返回 "" 或第一处分叉的说明。
static func compare_events(sample: Dictionary, events: Array) -> String:
	var expected: Array = sample["期望"]["事件"]
	for i in mini(expected.size(), events.size()):
		var e = decode(expected[i])
		var d := diff(e, events[i], "事件[%d]" % i)
		if d != "":
			return "%s · 第 %d 回合 · %s · 期望此时随机数已抽 %d 次" % [sample["id"], int(e.get("回合", -1)), d, int(e.get("_rng", -1))]
	if expected.size() != events.size():
		return "%s · 事件数不同（期望 %d，实际 %d）" % [sample["id"], expected.size(), events.size()]
	return ""
