## 05-阵型.js：正交双排 4×2 共 8 格的几何（前排 0..3、后排 4..7）。
## 位号一律是 float（与 JSON 读进来的单位位号同类型），作数组下标时再转 int。
class_name Fm
extends RefCounted

const ROW_FRONT := 0.0
const ROW_BACK := 1.0

static func ROWS() -> int:
	return int(Db.T.ROWS)

static func SLOTS() -> float:
	return float(Db.T.SLOTS)

static func 行列数(i: float) -> float:
	return float(Db.T.阵型.行[int(i)].列数)

static func 行首格(i: float) -> float:
	return float(Db.T.阵型.行[int(i)].起)

static func 行名(i: float) -> String:
	return String(Db.T.阵型.行[int(i)].名)

static func 行短名(i: float) -> String:
	var t: Dictionary = Db.T.阵型表[int(i)]
	return String(J.or_(J.or_(t.get("短名"), t.get("短")), 行名(i)))

static func rowOfSlot(slot: float) -> float:
	var r := 0
	while r < ROWS() - 1 and slot >= 行首格(r + 1):
		r += 1
	return float(r)

static func colOfSlot(slot: float) -> float:
	return slot - 行首格(rowOfSlot(slot))

static func slotOf(row: float, col: float) -> float:
	return 行首格(row) + col

static func 有这一列(row: float, col: float) -> bool:
	return col >= 0 and col < 行列数(row)

static func 位名(slot: float) -> String:
	return 行短名(rowOfSlot(slot)) + J.s(colOfSlot(slot) + 1)

static func 列上所有格(col: float) -> Array:
	var out := []
	for r in ROWS():
		if 有这一列(r, col):
			out.append(slotOf(r, col))
	return out

## JS 返回 Set；这里返回 { 位号字符串: true }（字典查找按 J.k 统一成字符串，避免 1 与 1.0 不等）
static func 活位集(x: Variant) -> Dictionary:
	if x is Dictionary:
		return x
	var s := {}
	for v in J.or_(x, []):
		s[J.k(v.slot if v is Dictionary else v)] = true
	return s

static func _越界(位: Variant) -> bool:
	return 位 == null or float(位) < 0 or float(位) >= SLOTS()

static func 阻挡位(位: Variant) -> Array:
	if _越界(位):
		return []
	if rowOfSlot(位) != ROW_FRONT:
		return []
	var 列: Array = J.or_(J.at(Db.T.阻挡表, colOfSlot(位)), [])
	return 列.map(func(c): return slotOf(ROW_BACK, c))

static func 遮挡位(位: Variant) -> Array:
	if _越界(位):
		return []
	if rowOfSlot(位) != ROW_BACK:
		return []
	var c := colOfSlot(位)
	var out := []
	var 表: Array = Db.T.阻挡表
	for i in 表.size():
		if J.inc(表[i], c):
			out.append(slotOf(ROW_FRONT, i))
	return out

static func 对位(位: float) -> Array:
	return 阻挡位(位) if rowOfSlot(位) == ROW_FRONT else 遮挡位(位)

static func 相邻位(位: float) -> Array:
	var out := []
	var r := rowOfSlot(位)
	var c := colOfSlot(位)
	if 有这一列(r, c - 1):
		out.append(slotOf(r, c - 1))
	if 有这一列(r, c + 1):
		out.append(slotOf(r, c + 1))
	for s in 对位(位):
		if not J.inc(out, s):
			out.append(s)
	return out

static func 被挡吗(位: Variant, 活着的位: Variant) -> bool:
	if 位 == null or rowOfSlot(位) != ROW_BACK:
		return false
	var 活 := 活位集(活着的位)
	return J.some(遮挡位(位), func(s): return 活.has(J.k(s)))

static func 阻挡束(位: Variant) -> Array:
	if _越界(位):
		return []
	var c := colOfSlot(位)
	return J.sort_num(列上所有格(c).duplicate())
