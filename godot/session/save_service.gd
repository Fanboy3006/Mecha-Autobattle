## 存档服务（原生 Godot，**零 `J.*`**）。
##
## 序列化**不用** `JSON.stringify`：肉鸽状态里到处是整数型实参，而 Godot 的 JSON 往返会把
## 整数变成 float（`8` → `8.0`），「存档往返后 `to_dict()` 逐字节一致」就做不到了。
## 所以这里自己写一份与 `JSON.stringify` 输出格式一致的编码器：
##   · 整数（含整数值的 float）→ `8`；  · 非整数 → `{"$f": ≤16 位十六进制 IEEE-754 小端位串}`；
##   · 字符串 / 布尔 / null / 数组 / 字典（键顺序 = 插入顺序）照 JSON 写。
## 键顺序保留插入顺序 —— `RunState.to_dict()` 的键顺序固定，所以同一局的存档**逐字节相同**。
##
## 解析侧同样是自己写的递归下降（不用 `JSON.parse_string`：它同样把整数读成 float）。
## 旧版本号 / 坏 JSON / 缺字段一律安全兜底（返回 `null` 或补默认值），**绝不崩**。
class_name SaveService
extends RefCounted

const 存档版本 := 4
const 默认路径 := "user://save.json"

# ======================== 对外接口 ========================
static func serialize(state: Variant) -> String:
	if state == null:
		return "null"
	if state is RunState:
		return _写(state.to_dict(), 0)
	if state is Dictionary or state is Array:
		return _写(state, 0)
	return "null"

static func deserialize(json_str: String) -> RunState:
	var d: Variant = parse_dict(json_str)
	if not (d is Dictionary):
		return null
	return RunState.from_dict(d)

## 沙箱兼容：`user://` 在 Windows 无沙箱写权限时落到 `res://.godot/` 下的同名文件
## （`.godot/` 是工程内的临时目录，沙箱下可写；正式运行照旧优先 `user://`）。
static func 落盘路径(path: String) -> String:
	if not path.begins_with("user://"):
		return path
	return "res://.godot/" + path.trim_prefix("user://").replace("/", "_")

static func save_to_file(state: RunState, path: String = 默认路径) -> bool:
	if state == null:
		return false
	var 文本 := serialize(state)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(文本)
		f.close()
		return true
	var 备 := 落盘路径(path)
	if 备 == path:
		return false
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var f2 := FileAccess.open(备, FileAccess.WRITE)
	if f2 == null:
		return false
	f2.store_string(文本)
	f2.close()
	return true

static func load_from_file(path: String = 默认路径) -> RunState:
	var 文本 := ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		文本 = f.get_as_text()
		f.close()
	else:
		var 备 := 落盘路径(path)
		if 备 != path and FileAccess.file_exists(备):
			var f2 := FileAccess.open(备, FileAccess.READ)
			if f2 != null:
				文本 = f2.get_as_text()
				f2.close()
	if 文本.is_empty():
		return null
	return deserialize(文本)

# ======================== 序列化 ========================
static func _写(v: Variant, 缩进: int) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(int(v))
		TYPE_FLOAT:
			return _写浮点(float(v))
		TYPE_STRING, TYPE_STRING_NAME:
			return _写字符串(String(v))
		TYPE_ARRAY:
			var 段 := []
			for x in v:
				段.append(_写(x, 缩进 + 1))
			return "[" + ",".join(段) + "]"
		TYPE_DICTIONARY:
			# 键一律按 JS 的对象键写（数值键 = 它的十进制字符串）；**保持插入顺序**（Godot 的 Dictionary 就是插入序）
			var 段2 := []
			for k in v.keys():
				段2.append(_写字符串(str(k)) + ":" + _写(v[k], 缩进 + 1))
			return "{" + ",".join(段2) + "}"
	return "null"

static func _写浮点(x: float) -> String:
	if is_nan(x) or is_inf(x):
		return "null"
	if x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	var 串 := ""
	for i in 8:
		串 += "%02x" % b[i]
	return '{"$f":"%s"}' % 串

static func _写字符串(s: String) -> String:
	var 出 := "\""
	for i in s.length():
		var c := s[i]
		var o := c.unicode_at(0)
		if c == "\"":
			出 += "\\\""
		elif c == "\\":
			出 += "\\\\"
		elif c == "\n":
			出 += "\\n"
		elif c == "\r":
			出 += "\\r"
		elif c == "\t":
			出 += "\\t"
		elif o < 0x20:
			出 += "\\u%04x" % o
		else:
			出 += c
	return 出 + "\""

# ======================== 反序列化 ========================
## 解析成 Variant（`{"$f": …}` 的数值编码会在这里还原成 float）。
## **坏 JSON 一律返回 `null`**（不抛异常、不返回半成品）。
static func parse_dict(json_str: String) -> Variant:
	var p := _解析器.new(json_str)
	p.skip_ws()
	var v: Variant = p.value()
	if p.坏:
		return null
	if v == null:
		return null
	p.skip_ws()
	if not p.done():
		return null
	return _规格化(_还原(v))

## `{"$f": 十六进制位串}` → float（递归）。
static func _还原(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.size() == 1 and d.has("$f") and d["$f"] is String:
			return _浮点串到数(d["$f"])
		var o := {}
		for k in d.keys():
			o[k] = _还原(d[k])
		return o
	if v is Array:
		return (v as Array).map(func(x): return _还原(x))
	return v

## 一个刚解析出来的对象是不是 `{"$f": 十六进制位串}`？是 → 当场还原成 float；不是 → 原样返回。
static func _浮点字典(d: Dictionary) -> Variant:
	if d.size() == 1 and d.has("$f") and d["$f"] is String:
		return _浮点串到数(d["$f"])
	return d

## ≤16 位十六进制（小端 IEEE-754）→ float。就是 `PackedByteArray.decode_double(0)`。
static func _浮点串到数(hex: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	for i in 8:
		b[i] = hex.substr(i * 2, 2).hex_to_int()
	return b.decode_double(0)

## 值的**整型归一**：`8.0` → `8`（肉鸽状态里的数都是「整数型实参 / 整数值 float」两种写法混用，
## 统一成 int，`to_dict()` 的往返就真的逐字段（含类型）一致）。
static func _规格化(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
			return int(f)
		return f
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			o[k] = _规格化(v[k])
		return o
	if v is Array:
		return (v as Array).map(func(x): return _规格化(x))
	return v

class _解析器:
	extends RefCounted
	var s: String
	var i: int = 0
	var 坏: bool = false

	func _init(文本: String) -> void:
		s = 文本

	func done() -> bool:
		return 坏 or i >= s.length()

	func skip_ws() -> void:
		while i < s.length():
			var c := s[i]
			if c == " " or c == "\t" or c == "\n" or c == "\r":
				i += 1
			else:
				break

	func _要(c: String) -> bool:
		if i < s.length() and s[i] == c:
			i += 1
			return true
		坏 = true
		return false

	func value() -> Variant:
		skip_ws()
		if 坏 or i >= s.length():
			坏 = true
			return null
		var c := s[i]
		if c == "{":
			return obj()
		if c == "[":
			return arr()
		if c == "\"":
			return 字符串()
		if s.substr(i, 4) == "true":
			i += 4
			return true
		if s.substr(i, 5) == "false":
			i += 5
			return false
		if s.substr(i, 4) == "null":
			i += 4
			return null
		if c == "-" or (c >= "0" and c <= "9"):
			return 数字()
		坏 = true
		return null

	func obj() -> Variant:
		if not _要("{"):
			return null
		var d := {}
		skip_ws()
		if i < s.length() and s[i] == "}":
			i += 1
			return _出(d)
		var 需要键 := true
		while i < s.length():
			skip_ws()
			if i < s.length() and s[i] == "}":
				i += 1
				return _出(d)
			if not 需要键:
				if not _要(","):
					return _出(d)
				skip_ws()
				if i < s.length() and s[i] == "}":
					i += 1
					return _出(d)
			var k: Variant = 字符串()
			if 坏:
				return _出(d)
			skip_ws()
			if not _要(":"):
				return _出(d)
			var v: Variant = value()
			if 坏:
				return _出(d)
			d[str(k)] = v
			需要键 = false
		return _出(d)

	## ★ 解析出一个对象的那一刻就查一遍 `{"$f": 十六进制位串}` —— 是就**当场**还原成 float
	##   （`PackedByteArray.decode_double(0)`），别等递归的 `_还原()`（那样 `obj()` 的返回值
	##   在 `_还原()` 之外就不对了）。判据照旧：`d.size() == 1 and d.has("$f") and d["$f"] is String`。
	func _出(d: Dictionary) -> Variant:
		return SaveService._浮点字典(d)

	func arr() -> Variant:
		if not _要("["):
			return null
		var a := []
		skip_ws()
		if i < s.length() and s[i] == "]":
			i += 1
			return a
		var 需要逗号 := false
		while i < s.length():
			skip_ws()
			if i < s.length() and s[i] == "]":
				i += 1
				return a
			if 需要逗号:
				if not _要(","):
					return a
			var v: Variant = value()
			if 坏:
				return a
			a.append(v)
			需要逗号 = true
		return a

	func 字符串() -> Variant:
		if not _要("\""):
			return ""
		var 出 := ""
		while i < s.length():
			var c := s[i]
			if c == "\\":
				i += 1
				if i >= s.length():
					坏 = true
					return 出
				var e := s[i]
				i += 1
				match e:
					"\"":
						出 += "\""
					"\\":
						出 += "\\"
					"/":
						出 += "/"
					"b":
						出 += "\b"
					"f":
						出 += "\f"
					"n":
						出 += "\n"
					"r":
						出 += "\r"
					"t":
						出 += "\t"
					"u":
						if i + 4 > s.length():
							坏 = true
							return 出
						var 码 := s.substr(i, 4).hex_to_int()
						i += 4
						出 += String.chr(码)
					_:
						坏 = true
						return 出
			elif c == "\"":
				i += 1
				return 出
			else:
				出 += c
				i += 1
		坏 = true
		return 出

	func 数字() -> Variant:
		var 起 := i
		if i < s.length() and s[i] == "-":
			i += 1
		while i < s.length() and s[i] >= "0" and s[i] <= "9":
			i += 1
		var 是浮点 := false
		if i < s.length() and s[i] == ".":
			是浮点 = true
			i += 1
			while i < s.length() and s[i] >= "0" and s[i] <= "9":
				i += 1
		if i < s.length() and (s[i] == "e" or s[i] == "E"):
			是浮点 = true
			i += 1
			if i < s.length() and (s[i] == "+" or s[i] == "-"):
				i += 1
			while i < s.length() and s[i] >= "0" and s[i] <= "9":
				i += 1
		var 文本 := s.substr(起, i - 起)
		if 文本.is_empty() or 文本 == "-":
			坏 = true
			return 0
		if not 是浮点 and absf(文本.to_float()) <= 9007199254740992.0:
			return int(文本)
		return 文本.to_float()
