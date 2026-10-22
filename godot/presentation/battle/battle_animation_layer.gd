## 职责：战斗动画覆盖层（`Control`）—— 弹道 / 飘字 / 飞卡 / 援护连线 / 拖拽瞄准线的绘制与淡出。
extends Control

## 当前这一拍的弹道（含起点槽位、终点槽位、颜色、类型、alpha）。
var active_trajectories: Array = []
## 当前这一拍的头顶飘字 / 效果胶囊（同上，带颜色、字号、alpha）。
var active_popups: Array = []
## ★ UX-5：发牌帧的一条「金色流光 + 飞行卡背」（来源机体卡中心 → 底部手牌栏目标卡中心）。
var active_flycards: Array = []
## ★ 2026-10-20：武器卡拖拽瞄准线（空字典 = 没在瞄准）。
var aim_line: Dictionary = {}
var _字体缓存: Font = null
var _淡出补间: Tween = null
var _飞卡补间: Tween = null

## ★ 2026-10-21（任务单问题 4）：4×4 棋盘上的**援护防御连线**。
var active_guards: Array = []

## ★ IT-5：敌方下一拍的**意图连线**（敌机 → 它要打的我方机体，红色虚线 + 期望伤害）。
var active_intents: Array = []

func set_intent_links(线们: Array) -> void:
	active_intents = 线们 if 线们 != null else []
	queue_redraw()

func 意图连线数() -> int:
	return active_intents.size()

## 设置 / 清空援护连线（传空数组 = 清掉）。**纯表现**，零状态修改。
func set_guard_links(线们: Array) -> void:
	active_guards = 线们 if 线们 != null else []
	queue_redraw()

## 现在画着几条援护连线（自动化测试读它）。
func 护卫连线数() -> int:
	return active_guards.size()

## 清空这一拍的所有表现（离场 / 换场 / 淡出结束时调）。
func 清空() -> void:
	active_trajectories = []
	active_popups = []
	active_flycards = []
	aim_line = {}
	if _飞卡补间 != null and _飞卡补间.is_valid():
		_飞卡补间.kill()
	_飞卡补间 = null
	queue_redraw()

## ★ 2026-10-20：设置 / 清空拖拽瞄准线（传空字典 = 清掉）。**纯表现**，零状态修改。
func set_aim(线: Dictionary) -> void:
	aim_line = 线 if 线 != null else {}
	queue_redraw()

## 现在有没有瞄准线在画（自动化测试读它）。
func 瞄准中() -> bool:
	return not aim_line.is_empty()

func set_trajectories(列: Array) -> void:
	active_trajectories = 列
	queue_redraw()

func set_popups(列: Array) -> void:
	active_popups = 列
	queue_redraw()

## 非 headless：把这一拍的表现整体淡出（0.7 秒）后清空。
func 开始淡出(秒: float) -> void:
	if not is_inside_tree():
		return
	if _淡出补间 != null and _淡出补间.is_valid():
		_淡出补间.kill()
	_淡出补间 = create_tween()
	_淡出补间.tween_method(_设透明度, 1.0, 0.0, 秒)
	_淡出补间.tween_callback(清空)

func _设透明度(a: float) -> void:
	for t in active_trajectories:
		if t is Dictionary:
			(t as Dictionary)["alpha"] = a
	for p in active_popups:
		if p is Dictionary:
			(p as Dictionary)["alpha"] = a
	queue_redraw()

func 弹道数() -> int:
	return active_trajectories.size()

func 飘字数() -> int:
	return active_popups.size()

func 飞卡数() -> int:
	return active_flycards.size()

## ★ UX-5：播一道发牌流光 / 飞行卡背（`起卡` 来源机体卡 → `止卡` 底部手牌栏那张牌）。
func 播放飞卡(起卡: Variant, 止卡: Variant, 秒: float) -> void:
	if not (起卡 is Control) or not (止卡 is Control):
		return
	active_flycards = [{"起点卡": 起卡, "终点卡": 止卡, "进度": 1.0, "alpha": 1.0}]
	queue_redraw()
	if UiTheme.无声模式() or not is_inside_tree():
		return
	_set_飞卡进度(0.0)
	if _飞卡补间 != null and _飞卡补间.is_valid():
		_飞卡补间.kill()
	_飞卡补间 = create_tween()
	_飞卡补间.tween_method(_set_飞卡进度, 0.0, 1.0, maxf(秒, 0.05))
	_飞卡补间.tween_callback(清空)

func _set_飞卡进度(v: float) -> void:
	for x in active_flycards:
		if x is Dictionary:
			(x as Dictionary)["进度"] = v
	queue_redraw()

## 一个控件中心点 → 本层局部坐标（拿不到有效矩形 → null）。
func _卡心(卡: Variant) -> Variant:
	if not (卡 is Control) or not is_instance_valid(卡):
		return null
	var r: Rect2 = (卡 as Control).get_global_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return null
	var 心 := r.position + r.size * 0.5
	return get_global_transform().affine_inverse() * 心

func _字体() -> Font:
	if _字体缓存 == null:
		_字体缓存 = get_theme_default_font()
		if _字体缓存 == null:
			_字体缓存 = ThemeDB.fallback_font
	return _字体缓存

func _draw() -> void:
	for i in active_intents:
		if i is Dictionary:
			_画意图线(i)
	for g in active_guards:
		if g is Dictionary:
			_画援护连线(g)
	for t in active_trajectories:
		if t is Dictionary:
			_画弹道(t)
	for f in active_flycards:
		if f is Dictionary:
			_画飞卡(f)
	for p in active_popups:
		if p is Dictionary:
			_画飘字(p)
	if not aim_line.is_empty():
		_画瞄准线(aim_line)

func _画援护连线(g: Dictionary) -> void:
	var 起: Variant = _卡心(g.get("起点卡"))
	var 止: Variant = _卡心(g.get("终点卡"))
	if 起 == null or 止 == null:
		return
	var 甲: Vector2 = 起 as Vector2
	var 乙: Vector2 = 止 as Vector2
	if 甲.distance_to(乙) < 1.0:
		return
	var 色 := UiTheme.连携色
	var 主 := Color(色.r, 色.g, 色.b, 0.92)
	var 晕 := Color(色.r, 色.g, 色.b, 0.22)
	draw_line(甲, 乙, 晕, 11.0, true)
	draw_line(甲, 乙, 主, 2.5, true)
	var 向 := (乙 - 甲).normalized()
	if 向.length() > 0.0:
		var 头 := 乙 - 向 * 16.0
		var 法 := Vector2(-向.y, 向.x)
		draw_line(头 + 法 * 8.0, 乙, 主, 2.5, true)
		draw_line(头 - 法 * 8.0, 乙, 主, 2.5, true)
	draw_arc(甲, 8.0, 0.0, TAU, 28, 主, 1.6, true)
	draw_arc(乙, 12.0, 0.0, TAU, 32, Color(色.r, 色.g, 色.b, 0.55), 1.4, true)
	var 文 := str(g.get("文案", ""))
	if 文.is_empty():
		return
	var 方 := _字体()
	var 字号 := UiTheme.字号_小
	var 中点 := (甲 + 乙) * 0.5
	var 宽 := 方.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
	var 高 := float(字号) + 8.0
	var 块 := Rect2(中点 - Vector2(宽 * 0.5 + 7.0, 高 * 0.5), Vector2(宽 + 14.0, 高))
	draw_rect(块, Color(UiTheme.底色.r, UiTheme.底色.g, UiTheme.底色.b, 0.88), true)
	draw_rect(块, 主, false, 1.5)
	draw_string(方, Vector2(块.position.x + 7.0, 块.position.y + 高 * 0.5 + float(字号) * 0.36),
		文, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, 主)

func _画意图线(g: Dictionary) -> void:
	var 起: Variant = _卡心(g.get("起点卡"))
	var 止: Variant = _卡心(g.get("终点卡"))
	if 起 == null or 止 == null:
		return
	var 甲: Vector2 = 起 as Vector2
	var 乙: Vector2 = 止 as Vector2
	if 甲.distance_to(乙) < 1.0:
		return
	var 色 := UiTheme.负面
	var 主 := Color(色.r, 色.g, 色.b, 0.75 if bool(g.get("大招", false)) else 0.45)
	draw_dashed_line(甲, 乙, 主, 2.0 if bool(g.get("大招", false)) else 1.2, 8.0, true)
	draw_arc(乙, 10.0, 0.0, TAU, 28, 主, 1.4, true)
	var 文 := str(g.get("文案", ""))
	if 文.is_empty():
		return
	var 方 := _字体()
	var 字号 := UiTheme.字号_小
	var 点 := 甲.lerp(乙, 0.7)
	var 宽 := 方.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
	var 高 := float(字号) + 6.0
	var 块 := Rect2(点 - Vector2(宽 * 0.5 + 5.0, 高 * 0.5), Vector2(宽 + 10.0, 高))
	draw_rect(块, Color(UiTheme.底色.r, UiTheme.底色.g, UiTheme.底色.b, 0.85), true)
	draw_string(方, Vector2(块.position.x + 5.0, 块.position.y + 高 * 0.5 + float(字号) * 0.36),
		文, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, Color(色.r, 色.g, 色.b, 0.95))

func _画瞄准线(t: Dictionary) -> void:
	var 起: Variant = _卡心(t.get("起点卡"))
	if 起 == null:
		起 = t.get("起点")
	var 止: Variant = _卡心(t.get("终点卡"))
	if 止 == null:
		止 = t.get("终点")
	if not (起 is Vector2) or not (止 is Vector2):
		return
	var 甲: Vector2 = 起 as Vector2
	var 乙: Vector2 = 止 as Vector2
	var 色: Color = t.get("颜色") if t.get("颜色") is Color else Color(1.0, 0.42, 0.16)
	var 宽 := maxf(1.0, float(t.get("宽", 4.0)))
	var 锁 := bool(t.get("吸附", false))
	var 主 := Color(色.r, 色.g, 色.b, 0.95)
	var 晕 := Color(色.r, 色.g, 色.b, 0.22)
	draw_line(甲, 乙, 晕, 宽 + 9.0, true)
	draw_line(甲, 乙, 主, 宽, true)
	var 向 := (乙 - 甲).normalized()
	if 向.length() > 0.0:
		var 头 := 乙 - 向 * maxf(14.0, 宽 * 4.0)
		var 法 := Vector2(-向.y, 向.x)
		draw_line(头 + 法 * (7.0 + 宽), 乙, 主, 宽, true)
		draw_line(头 - 法 * (7.0 + 宽), 乙, 主, 宽, true)
		draw_line(头 + 法 * (7.0 + 宽), 乙, Color(0.0, 0.0, 0.0, 0.35), maxf(1.0, 宽 * 0.45), true)
	var 半径 := 15.0 if 锁 else 11.0
	draw_arc(乙, 半径, 0.0, TAU, 40, 主, maxf(1.5, 宽 * 0.6), true)
	draw_arc(乙, 半径 + (5.0 if 锁 else 0.0), 0.0, TAU, 44,
		Color(色.r, 色.g, 色.b, 0.45 if 锁 else 0.28), maxf(1.0, 宽 * 0.35), true)
	for i in 4:
		var 角 := TAU * float(i) / 4.0 + PI * 0.25
		var 内 := 乙 + Vector2(cos(角), sin(角)) * (半径 - 4.0)
		var 外 := 乙 + Vector2(cos(角), sin(角)) * (半径 + (6.0 if 锁 else 3.0))
		draw_line(内, 外, 主, maxf(1.0, 宽 * 0.45), true)
	draw_arc(甲, 7.0, 0.0, TAU, 24, 主, maxf(1.2, 宽 * 0.45), true)

func _画弹道(t: Dictionary) -> void:
	var 起: Variant = _卡心(t.get("起点卡"))
	var 止: Variant = _卡心(t.get("终点卡"))
	if 起 == null or 止 == null:
		return
	var a := clampf(float(t.get("alpha", 1.0)), 0.0, 1.0)
	if a <= 0.0:
		return
	var 色: Color = t.get("颜色") if t.get("颜色") is Color else UiTheme.弹道色
	var 宽 := float(t.get("宽度", 2.5))
	var 虚 := bool(t.get("虚线", false))
	var 主 := Color(色.r, 色.g, 色.b, 色.a * a)
	var 晕 := Color(色.r, 色.g, 色.b, 色.a * a * 0.28)
	var 甲: Vector2 = 起 as Vector2
	var 乙: Vector2 = 止 as Vector2
	if 虚:
		draw_dashed_line(甲, 乙, 晕, 宽 + 5.0, 6.0, true)
		draw_dashed_line(甲, 乙, 主, 宽, 6.0, true)
	else:
		draw_line(甲, 乙, 晕, 宽 + 5.0, true)
		draw_line(甲, 乙, 主, 宽, true)
	var 向 := (乙 - 甲).normalized()
	if 向.length() <= 0.0:
		return
	var 头 := 乙 - 向 * 12.0
	var 左 := 头 + Vector2(-向.y, 向.x) * 7.0
	var 右 := 头 - Vector2(-向.y, 向.x) * 7.0
	if 虚:
		draw_dashed_line(头, 左, 主, 宽, 4.0, true)
		draw_dashed_line(头, 右, 主, 宽, 4.0, true)
	else:
		draw_line(头, 左, 主, 宽, true)
		draw_line(头, 右, 主, 宽, true)

func _画飞卡(f: Dictionary) -> void:
	var 起: Variant = _卡心(f.get("起点卡"))
	var 止: Variant = _卡心(f.get("终点卡"))
	if 起 == null or 止 == null:
		return
	var a := clampf(float(f.get("alpha", 1.0)), 0.0, 1.0)
	if a <= 0.0:
		return
	var 甲: Vector2 = 起 as Vector2
	var 乙: Vector2 = 止 as Vector2
	var p := clampf(float(f.get("进度", 0.0)), 0.0, 1.0)
	var 色 := UiTheme.高亮
	var 主 := Color(色.r, 色.g, 色.b, a * 0.9)
	var 晕 := Color(色.r, 色.g, 色.b, a * 0.20)
	draw_line(甲, 乙, 晕, 5.0, true)
	draw_dashed_line(甲, 乙, Color(主.r, 主.g, 主.b, 主.a * 0.55), 1.5, 8.0, true)
	var 位 := 甲.lerp(乙, p)
	var 背 := Rect2(位 - Vector2(5.0, 7.0), Vector2(10.0, 14.0))
	draw_rect(背, Color(色.r, 色.g, 色.b, a * 0.9), true)
	draw_rect(背, Color(1.0, 1.0, 1.0, a * 0.85), false, 1.5)

func _画飘字(p: Dictionary) -> void:
	var 心: Variant = _卡心(p.get("卡"))
	if 心 == null:
		return
	var a := clampf(float(p.get("alpha", 1.0)), 0.0, 1.0)
	if a <= 0.0:
		return
	var 字 := str(p.get("文本", ""))
	if 字.is_empty():
		return
	var 色: Color = p.get("颜色") if p.get("颜色") is Color else UiTheme.主文字
	var 字号 := int(p.get("字号", 16))
	var 上移 := float(p.get("上移", 0.0))
	var 半高 := 74.0
	var 卡: Variant = p.get("卡")
	if 卡 is Control and is_instance_valid(卡):
		半高 = (卡 as Control).get_global_rect().size.y * 0.5
	var 位: Vector2 = (心 as Vector2) + Vector2(0.0, -(半高 + 32.0) - 上移)
	var 方 := _字体()
	var 宽 := 方.get_string_size(字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x
	var 起 := 位 - Vector2(宽 * 0.5, 0.0)
	var 正 := 色
	正.a = a
	var 描 := UiTheme.底色
	描.a = a * 0.92
	draw_string_outline(方, 起, 字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, 5, 描)
	draw_string(方, 起, 字, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号, 正)
