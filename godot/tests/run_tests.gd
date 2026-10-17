## 唯一测试入口（本地与 CI 同一条命令）：
##   godot --headless --path godot --script res://tests/run_tests.gd
## 自动发现 res://tests/unit/test_*.gd；每个文件 extends RefCounted 并实现 func run(t: TestContext)。
## 退出码：0 = 全绿，1 = 有失败或有测试文件加载失败。
extends SceneTree

class TestContext:
	var passes := 0
	var fails := 0
	var failures: Array[String] = []
	var _suite := ""

	func ok(cond: bool, msg: String) -> void:
		if cond:
			passes += 1
			print("  ✓ " + msg)
		else:
			fails += 1
			failures.append("[%s] %s" % [_suite, msg])
			print("  ✗ " + msg)

	func info(msg: String) -> void:
		print("    · " + msg)

func _initialize() -> void:
	var t := TestContext.new()
	var files := _test_files("res://tests/unit")
	print("机甲指挥 · Godot 测试：%d 个测试文件\n" % files.size())
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			t._suite = path.get_file()
			t.ok(false, "测试文件加载失败：%s" % path)
			continue
		var suite = script.new()
		t._suite = path.get_file()
		print("[%s]" % path.get_file().trim_suffix(".gd"))
		# ★ 测试可以是**协程**（`run()` 里有 `await`）：排版类断言必须先跑过帧，
		#   否则 `Control.get_global_rect()` 全是 0×0。同步的 `run()` 返回 null，
		#   这一句 await 立刻结束，既有测试一个字都不用改。
		await suite.run(t)
		print("")
	print("==========================================")
	if t.fails == 0:
		print("✓ 全部通过：%d 项" % t.passes)
	else:
		print("✗ 失败 %d 项 / 通过 %d 项" % [t.fails, t.passes])
		for f in t.failures:
			print("   " + f)
	quit(0 if t.fails == 0 else 1)

func _test_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	out.sort()
	return out
