## JS 语义帮手：移植 JS 战斗内核时，凡是 GDScript 与 JS 行为不同的地方一律走这里。
## （实测差异：empty 数组/字典在 GDScript 里是假、NaN 是真；1 in [1.0] 为假；str(1.0) 是 "1.0"；整数相除截断。）
## 约定：游戏状态里的数一律是 float（JSON 读进来本来就是 float；代码里写字面量也用 1.0 这种写法）。
## JS 的 undefined 与 null 在这里都表现为 null（取不存在的键用 .get(k) 得到 null）。
class_name J
extends RefCounted

## JS ToBoolean
static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v) != ""
	return true   # 对象 / 数组 / 字典 / Callable：JS 里都为真（包括空数组、空对象）

## a || b（a 为假时取 b；两边都会求值，带副作用的右边请自己写 if）
static func or_(a: Variant, b: Variant) -> Variant:
	return a if truthy(a) else b

## a && b
static func and_(a: Variant, b: Variant) -> Variant:
	return b if truthy(a) else a

## a ?? b
static func nz(a: Variant, b: Variant) -> Variant:
	return b if a == null else a

## Number(v)。null 按 JS 的 undefined 处理（→ NaN）：取不存在的字段是最常见的情况。
static func num(v: Variant) -> float:
	match typeof(v):
		TYPE_NIL:
			return NAN
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v).strip_edges()
			if s == "":
				return 0.0
			if s.is_valid_float():
				return s.to_float()
			return NAN
	return NAN

## Number(v) || 0
static func num0(v: Variant) -> float:
	var n := num(v)
	return 0.0 if (is_nan(n) or n == 0.0) else n

## Number.isFinite(Number(v))（v 已经是数时就是 Number.isFinite(v)）
static func finite(v: Variant) -> bool:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return false
	return is_finite(float(v))

## 是数字类型（typeof v === 'number'）
static func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

## String(v)：数字按 JS 的格式（整数不带小数点）
static func s(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return fmt(v)
	return str(v)

static func fmt(x: float) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x):
		return "Infinity" if x > 0 else "-Infinity"
	if x == floorf(x) and absf(x) < 1e21:
		return String.num_int64(int(x))
	# JS 的 String(x)：能精确还原 x 的最短十进制写法（String.num 按小数位四舍五入并去掉末尾的 0）
	for d in range(1, 21):
		var t := String.num(x, d)
		if t.to_float() == x:
			return t
	return String.num(x, 20)

## 数字作字典键时的 JS 字符串形式（JS 对象的键都是字符串）
static func k(v: Variant) -> String:
	return s(v)

## o[key]：数组按整数下标、字典按 JS 的字符串键；越界 / 缺键得 null
static func at(o: Variant, key: Variant) -> Variant:
	if o is Array:
		if is_num(key) and float(key) == floorf(float(key)) and float(key) >= 0 and int(key) < o.size():
			return o[int(key)]
		return null
	if o is Dictionary:
		if is_num(key):
			return o.get(k(key))
		return o.get(key)
	return null

## Number.isInteger(v)
static func is_int(v: Variant) -> bool:
	return is_num(v) and is_finite(float(v)) and float(v) == floorf(float(v))

## Math.round（.5 朝 +∞）
static func round(x: float) -> float:
	return JsCompat.js_round(x)

static func clamp(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))

## JS 的 % （截断取余，与 C 的 fmod 相同）
static func mod(a: float, b: float) -> float:
	return fmod(a, b)

## arr.includes(v)：按 == 比较（1 与 1.0 相等）
static func inc(arr: Variant, v: Variant) -> bool:
	if arr == null:
		return false
	for x in arr:
		if _eq(x, v):
			return true
	return false

## arr.indexOf(v)
static func index_of(arr: Array, v: Variant) -> int:
	for i in arr.size():
		if _eq(arr[i], v):
			return i
	return -1

static func _eq(a: Variant, b: Variant) -> bool:
	if is_num(a) and is_num(b):
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		if (typeof(a) == TYPE_STRING or typeof(a) == TYPE_STRING_NAME) and (typeof(b) == TYPE_STRING or typeof(b) == TYPE_STRING_NAME):
			return String(a) == String(b)
		return false
	if typeof(a) == TYPE_DICTIONARY or typeof(a) == TYPE_ARRAY or typeof(a) == TYPE_OBJECT:
		return is_same(a, b)
	return a == b

## a === b（数字按值、对象按引用）
static func same(a: Variant, b: Variant) -> bool:
	return _eq(a, b)

## arr.find(pred) → 元素或 null
static func find(arr: Variant, pred: Callable) -> Variant:
	if arr == null:
		return null
	for x in arr:
		if pred.call(x):
			return x
	return null

## arr.findIndex(pred)
static func find_index(arr: Array, pred: Callable) -> int:
	for i in arr.size():
		if pred.call(arr[i]):
			return i
	return -1

## arr.some(pred)
static func some(arr: Variant, pred: Callable) -> bool:
	if arr == null:
		return false
	for x in arr:
		if truthy(pred.call(x)):
			return true
	return false

## arr.every(pred)
static func every(arr: Variant, pred: Callable) -> bool:
	if arr == null:
		return true
	for x in arr:
		if not truthy(pred.call(x)):
			return false
	return true

## arr.filter(pred)（谓词结果按 JS 真假判断）
static func filter(arr: Variant, pred: Callable) -> Array:
	var out := []
	if arr == null:
		return out
	for x in arr:
		if truthy(pred.call(x)):
			out.append(x)
	return out

## arr.reduce((a, x) => …, init)
static func reduce(arr: Variant, f: Callable, init: Variant) -> Variant:
	var acc: Variant = init
	if arr == null:
		return acc
	for x in arr:
		acc = f.call(acc, x)
	return acc

## arr.reduce((a, b) => a + (b[key] || 0), 0)：最常见的「按字段求和」
static func sum_field(arr: Variant, key: String) -> float:
	var t := 0.0
	if arr == null:
		return t
	for b in arr:
		t += num0(b.get(key))
	return t

## arr.sort(cmp)：原地稳定排序（与 V8 一致），cmp 返回数字（< 0 表示 a 在前）。返回 arr 本身。
static func sort(arr: Array, cmp: Callable) -> Array:
	var sorted := JsCompat.stable_sort(arr, func(a, b): return float(cmp.call(a, b)) < 0.0)
	for i in arr.size():
		arr[i] = sorted[i]
	return arr

## 数组按数值升序（arr.sort((a, b) => a - b)）
static func sort_num(arr: Array) -> Array:
	return sort(arr, func(a, b): return float(a) - float(b))

## [...new Set(arr)]（保持首次出现的顺序；数按值去重）
static func uniq(arr: Array) -> Array:
	var out := []
	for x in arr:
		if not inc(out, x):
			out.append(x)
	return out

## Object.assign(target, src…)
static func assign(target: Dictionary, a: Variant = null, b: Variant = null, c: Variant = null) -> Dictionary:
	for src in [a, b, c]:
		if src is Dictionary:
			for key in src.keys():
				target[key] = src[key]
	return target

## Object.assign({}, a, b, c)
static func merged(a: Variant = null, b: Variant = null, c: Variant = null) -> Dictionary:
	return assign({}, a, b, c)

## Array.isArray(v)
static func is_arr(v: Variant) -> bool:
	return typeof(v) == TYPE_ARRAY

## 取字段：o 为 null 时返回 null（JS 的 o && o.k / o?.k）
static func g(o: Variant, key: String) -> Variant:
	if o is Dictionary:
		return o.get(key)
	return null

## Math.max(...arr)；空数组得 -Infinity
static func max_of(arr: Array) -> float:
	var m := -INF
	for x in arr:
		m = maxf(m, float(x))
	return m

static func min_of(arr: Array) -> float:
	var m := INF
	for x in arr:
		m = minf(m, float(x))
	return m

## arr.concat(b)（返回新数组；b 可以是数组或单个元素）
static func concat(a: Variant, b: Variant) -> Array:
	var out: Array = (a as Array).duplicate() if a != null else []
	if b is Array:
		out.append_array(b)
	elif b != null:
		out.append(b)
	return out

## JSON.stringify(v)（数字按 JS 的格式；只用于生成「签名」这类要与 JS 逐字相同的字符串）
static func json(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT, TYPE_FLOAT:
			return fmt(float(v)) if is_finite(float(v)) else "null"
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(v))
		TYPE_ARRAY:
			var parts := []
			for x in v:
				parts.append(json(x))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts2 := []
			for key in v.keys():
				parts2.append(JSON.stringify(String(key)) + ":" + json(v[key]))
			return "{" + ",".join(parts2) + "}"
	return "null"
