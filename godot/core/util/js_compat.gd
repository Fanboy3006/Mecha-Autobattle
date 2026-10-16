## 与 JS 结算语义对齐的小工具。战斗规则里一律用这里的函数，不直接用 Godot 内置的同名函数。
class_name JsCompat
extends RefCounted

## JS 的 Math.round：四舍五入，.5 一律朝 +∞（-2.5 → -2）。
## Godot 内置 round() 是「远离 0」（-2.5 → -3），对负数结果不同。
static func js_round(x: float) -> float:
	var r := floorf(x)
	return r + 1.0 if x - r >= 0.5 else r

## 稳定排序（与 V8 的 Array.prototype.sort 一致：比较相等时保持原顺序）。
## Godot 的 Array.sort_custom 不保证稳定，规则代码里一律用这个。
## less(a, b) 返回 a 是否应排在 b 前面（严格小于）。
static func stable_sort(arr: Array, less: Callable) -> Array:
	var n := arr.size()
	if n <= 1:
		return arr.duplicate()
	var src := arr.duplicate()
	var dst := []
	dst.resize(n)
	var width := 1
	while width < n:
		var i := 0
		while i < n:
			var mid := mini(i + width, n)
			var hi := mini(i + 2 * width, n)
			var l := i
			var r := mid
			var k := i
			while l < mid and r < hi:
				# 只有右边严格小于左边才先取右边 → 相等时保持左边在前（稳定）
				if less.call(src[r], src[l]):
					dst[k] = src[r]
					r += 1
				else:
					dst[k] = src[l]
					l += 1
				k += 1
			while l < mid:
				dst[k] = src[l]
				l += 1
				k += 1
			while r < hi:
				dst[k] = src[r]
				r += 1
				k += 1
			i += 2 * width
		var tmp := src
		src = dst
		dst = tmp
		width *= 2
	return src
