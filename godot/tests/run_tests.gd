## 唯一测试入口（本地与 CI 同一条命令）：
##   godot --headless --path godot --script res://tests/run_tests.gd
## 自动发现 res://tests/unit/test_*.gd；每个文件 extends RefCounted 并实现 func run(t: TestContext)。
## 退出码：0 = 全绿，1 = 有失败或有测试文件加载失败。
## 只跑部分文件：在 `--` 后加 `--only=片段1,片段2`（文件名含任一片段即跑），例如 `-- --only=test_swap,test_colonial`。
extends SceneTree

class TestContext:
	var passes := 0
	var fails := 0
	var failures: Array[String] = []
	var _suite := ""
	var verbose := false
	var _suite_passes := 0
	var _suite_fails := 0

	func begin_suite(name: String) -> void:
		_suite = name
		_suite_passes = 0
		_suite_fails = 0
		if verbose:
			print("[%s]" % name.trim_suffix(".gd"))

	func end_suite() -> void:
		if verbose:
			print("")
			return
		var label := _suite.trim_suffix(".gd")
		if _suite_fails > 0:
			print("[%s] ✓ %d  ✗ %d" % [label, _suite_passes, _suite_fails])
		else:
			print("[%s] ✓ %d" % [label, _suite_passes])

	func ok(cond: bool, msg: String) -> void:
		if cond:
			passes += 1
			_suite_passes += 1
			if verbose:
				print("  ✓ " + msg)
		else:
			fails += 1
			_suite_fails += 1
			failures.append("[%s] %s" % [_suite, msg])
			print("  ✗ " + msg)

	func info(msg: String) -> void:
		if verbose:
			print("    · " + msg)

func _initialize() -> void:
	var t := TestContext.new()
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	t.verbose = "--verbose" in args
	var files := _test_files("res://tests/unit")
	var 片段: PackedStringArray = []
	for a in args:
		if a.begins_with("--only="):
			片段 = a.trim_prefix("--only=").split(",", false)
	if not 片段.is_empty():
		var 选中: Array[String] = []
		for path in files:
			for s in 片段:
				if s in path.get_file():
					选中.append(path)
					break
		files = 选中
	print("机甲指挥 · Godot 测试：%d 个测试文件\n" % files.size())
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			t.begin_suite(path.get_file())
			t.ok(false, "测试文件加载失败：%s" % path)
			t.end_suite()
			continue
		var suite = script.new()
		t.begin_suite(path.get_file())
		# ★ 测试可以是**协程**（`run()` 里有 `await`）：排版类断言必须先跑过帧，
		#   否则 `Control.get_global_rect()` 全是 0×0。同步的 `run()` 返回 null，
		#   这一句 await 立刻结束，既有测试一个字都不用改。
		await suite.run(t)
		t.end_suite()
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
