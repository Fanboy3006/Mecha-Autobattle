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

# ==========================================================================================
# ★ MITH3-1：《武器范围规则 v0.1》—— 4×4 战场 · 真实距离 `1..6` · 顶位（仅影响近战）
#
#   坐标：每方 8 格。`slot 0..3` = 前排（`row = 0`）、`slot 4..7` = 后排（`row = 1`），`col = slot % 4`。
#   真实距离 `dist_real(a, b) = abs(col_a - col_b) + (row_a + row_b + 1)` 在 `1..6`：
#     都在前排 = 1 + 横差；一前一后 = 2 + 横差；都在后排 = 3 + 横差。
#   **顶位**：某一方前排 4 格全部没有存活单位（含掩体）时，该方后排全体进入「顶位」。
#   顶位**只影响近战**：近战资格视为站在前排，近战距离的排差按 `row = 0` 算；
#   直射 / 曲射 / 【远距·N】 的距离始终按 `真实距离` 算（避免后排狙击手因前排没人而丢距离）。
#
#   纪律：这一整段**纯几何 + 纯读** —— 不掷随机数、不改任何状态；
#         并且只在 `Params.武器范围v01开(ctx)` 为真时被 reach.gd / flow.gd 调用（默认关）。
# ==========================================================================================

## 真实距离（照真实前/后排位置算，不受顶位影响）。范围 `1..6`。
static func 真实距离(位甲: Variant, 位乙: Variant) -> int:
	if _越界(位甲) or _越界(位乙):
		return 0
	var 横 := absi(int(colOfSlot(float(位甲))) - int(colOfSlot(float(位乙))))
	var 纵 := int(rowOfSlot(float(位甲))) + int(rowOfSlot(float(位乙))) + 1
	return 横 + 纵

## 别名（门面 / 表现层想写 `dist_real` 的用这个）。
static func dist_real(位甲: Variant, 位乙: Variant) -> int:
	return 真实距离(位甲, 位乙)

## 近战距离：处于顶位的一侧按 `row = 0`（前排）算，其余照真实位置算。
static func 近战距离(位甲: Variant, 位乙: Variant, 甲顶位: bool = false, 乙顶位: bool = false) -> int:
	if _越界(位甲) or _越界(位乙):
		return 0
	var 横 := absi(int(colOfSlot(float(位甲))) - int(colOfSlot(float(位乙))))
	var 排甲 := 0 if 甲顶位 else int(rowOfSlot(float(位甲)))
	var 排乙 := 0 if 乙顶位 else int(rowOfSlot(float(位乙)))
	return 横 + 排甲 + 排乙 + 1

## 任务单 §2 的通用签名：`格距离(位甲, 位乙, 是近战, 甲顶位, 乙顶位) -> int`。
## `是近战 == false`（直射 / 曲射 / 【远距·N】）→ **一律真实距离**，顶位参数被忽略。
static func 格距离(位甲: Variant, 位乙: Variant, 是近战: bool = false, 甲顶位: bool = false, 乙顶位: bool = false) -> int:
	if 是近战:
		return 近战距离(位甲, 位乙, 甲顶位, 乙顶位)
	return 真实距离(位甲, 位乙)

## 这个格子上「有东西占着」吗：存活单位 或 掩体（`ctx.掩体 = { "0": hp, ... }`，也可写数组）。
static func 格被占(ctx: Variant, side: String, slot: int) -> bool:
	if ctx is Dictionary:
		# 注意：这里**故意不调 `Units.sideUnits`** —— `units.gd` 已经静态依赖 `Fm`，
		# 反向再依赖会构成循环引用（GDScript 编译期会报 cyclic）。改成直接读 ctx 上的两个数组。
		var 们: Array = ctx.get("allies") if side == "ally" else ctx.get("enemies")
		for u in J.or_(们, []):
			if u != null and int(u.get("slot", -1)) == slot and float(u.get("hp", 0.0)) > 0.0:
				return true
		var 掩 = ctx.get("掩体")
		if 掩 is Dictionary:
			var 方掩 = 掩.get(side) if 掩.get(side) is Dictionary else 掩
			if 方掩 is Dictionary:
				var v = 方掩.get(str(slot))
				if v == null:
					v = 方掩.get(slot)
				if v is Dictionary and float(v.get("hp", 0.0)) > 0.0:
					return true
				if (v is int or v is float) and float(v) > 0.0:
					return true
		elif 掩 is Array:
			for e in 掩:
				if e is Dictionary and str(e.get("方", "")) == side and int(e.get("位", -1)) == slot \
					and float(e.get("hp", 0.0)) > 0.0:
					return true
	return false

## 某一方**前排 4 格（slot 0..3）全部没有存活单位（含掩体）** → 该方后排全体处于「顶位」。
static func 是否顶位(ctx: Variant, side: String) -> bool:
	if not (ctx is Dictionary):
		return false
	for s in range(4):
		if 格被占(ctx, side, s):
			return false
	return true

## 某台单位算不算「站在前排」（真前排 **或** 顶位）—— 近战资格用这个。
static func 是前排有效(u: Variant, ctx: Variant) -> bool:
	if not (u is Dictionary) or u.get("slot") == null:
		return false
	if rowOfSlot(float(u.slot)) == ROW_FRONT:
		return true
	return 是否顶位(ctx, str(u.get("side", "")))

## 任务单 §1.1 的 `is_front_effective(side, u)` 写法（按单位自己那一方算顶位）。
static func is_front_effective(ctx: Variant, u: Variant) -> bool:
	return 是前排有效(u, ctx)

## 同列的另一排格子（前排 / 后排）。`位` 越界 → `-1`。
static func 另一排同位(位: Variant) -> int:
	if _越界(位):
		return -1
	return int(slotOf(ROW_BACK if rowOfSlot(float(位)) == ROW_FRONT else ROW_FRONT, colOfSlot(float(位))))

## 同一方阵内「十字相邻格」：同排左右相邻列 + 同列另一排（最多 3 格，不含自己）。
static func 十字相邻位(位: Variant) -> Array:
	if _越界(位):
		return []
	var out := []
	var r := rowOfSlot(float(位))
	var c := colOfSlot(float(位))
	if 有这一列(r, c - 1):
		out.append(int(slotOf(r, c - 1)))
	if 有这一列(r, c + 1):
		out.append(int(slotOf(r, c + 1)))
	out.append(另一排同位(位))
	return J.uniq(out)
