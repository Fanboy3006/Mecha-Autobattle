## 读取黄金样例的工具（测试专用）。
class_name GoldenIO
extends RefCounted

static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

## 16 位十六进制的 IEEE-754（小端）位串 → float，与 JS 的 Buffer.writeDoubleLE 对应
static func bits_to_float(hex: String) -> float:
	var b := PackedByteArray()
	for i in 8:
		b.append(hex.substr(i * 2, 2).hex_to_int())
	return b.decode_double(0)

## float → 16 位十六进制的 IEEE-754（小端）位串（`bits_to_float` 的逆）
static func float_to_bits(v: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, v)
	var s := ""
	for i in 8:
		s += "%02x" % b[i]
	return s

## 数值编码（与 `tools/js_ref.mjs` 的 `normalize` 同口径）：整数照存，非整数（含 NaN / ±∞）存 `{"$f": 位串}`。
static func encode(v: Variant) -> Variant:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		var f := float(v)
		if is_finite(f) and f == floor(f) and absf(f) < 9.0e15:
			return int(f)
		return {"$f": float_to_bits(f)}
	if v is Dictionary:
		var o := {}
		for k in (v as Dictionary).keys():
			o[str(k)] = encode((v as Dictionary)[k])
		return o
	if v is Array:
		return (v as Array).map(func(x): return encode(x))
	return v
