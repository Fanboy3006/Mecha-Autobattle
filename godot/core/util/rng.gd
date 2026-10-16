## Mulberry32 —— 与 JS 版 `00-head.js` 的 `mulberry32()` 逐位一致。
## 全部运算在 32 位无符号整数上做（GDScript 的 int 是 64 位有符号，需要手动掩码）。
## 每局战斗一个实例；`steps` 记录已经抽了几次，用于对账时定位第一处分叉。
class_name Mulberry32
extends RefCounted

const MASK := 0xFFFFFFFF

var _a: int
var steps: int = 0

func _init(seed: int) -> void:
	var s := seed & MASK
	_a = s if s != 0 else 1   # JS: mulberry32((种子 >>> 0) || 1)

## Math.imul 的 32 位乘法（拆 16 位，避免 64 位溢出）
static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var a_hi := (a >> 16) & 0xFFFF
	var a_lo := a & 0xFFFF
	var b_hi := (b >> 16) & 0xFFFF
	var b_lo := b & 0xFFFF
	return ((a_lo * b_lo) + ((((a_hi * b_lo) + (a_lo * b_hi)) & 0xFFFF) << 16)) & MASK

## 下一个 [0, 1) 浮点数
func next_float() -> float:
	steps += 1
	_a = (_a + 0x6D2B79F5) & MASK
	var t := imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
	var u := (t ^ (t >> 14)) & MASK
	return float(u) / 4294967296.0
