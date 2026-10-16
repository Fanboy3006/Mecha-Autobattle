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
