## 职责：BR-1.1-b 正面断言 —— 同一场里同一个敌人键出现第二次就发 `键#2`、`键#3`…
##   （内部 `key` 唯一、`tplKey` 还是原键、显示名不变），并且**用第二台的 key 出牌，伤害落在第二台**。
## 这一条是玩家可见的 bug：BR-1-e 接回增援后同场会出现两台 `hound`，点第二台会打到第一台。
extends RefCounted

const 种子 := 20261019

func run(t) -> void:
	var errs := []
	t.ok(DataLoader.install(errs), "数据装得进去（%s）" % str(errs))
	if not errs.is_empty():
		return
	_开局编成同键两台(t)
	_增援同键(t)
	_按第二台的键打(t)

## 开局编成里写两个 `hound` → `hound` / `hound#2`
func _开局编成同键两台(t) -> void:
	var ctx := _开([])
	var 一 = Btl.找单位(ctx, "hound", "enemy")
	var 二 = Btl.找单位(ctx, "hound#2", "enemy")
	t.ok(一 is Dictionary and 二 is Dictionary, "① 开局编成两台 `hound` → 发成 `hound` 与 `hound#2`")
	if not (一 is Dictionary) or not (二 is Dictionary):
		return
	t.ok(not is_same(一, 二) and 一.key != 二.key, "① 两台不是同一台（key：%s / %s）" % [str(一.key), str(二.key)])
	t.ok(str(一.name) == str(二.name), "① **显示名不变**（两台都叫 %s）" % str(一.name))
	t.ok(str(二.get("tplKey", "")) == "hound", "① 第二台的 `tplKey` 还是原键（%s），按类型查得到" % str(二.get("tplKey", "")))
	t.ok(int((ctx.get("enemies") as Array).size()) == 2, "① 场上确实两台（%d）" % (ctx.get("enemies") as Array).size())

## 增援来一台已经在场的键 → 接着发号（`hound#2`）
func _增援同键(t) -> void:
	var 选项 := SessionBattleOptions.生产(null)
	选项["波次"] = [{"回合": 2.0, "来": [{"键": "hound", "等级": 1.0}]}]
	var ctx := Setup.开局([{"键": "W1", "位": 0, "等级": 30}], [{"键": "hound", "位": 0, "等级": 1}], 种子, null, 选项)
	BattlePhaseFlow.开始我方阶段(ctx)
	var 二 = Btl.找单位(ctx, "hound#2", "enemy")
	t.ok(int(ctx.turn) == 2 and 二 is Dictionary,
		"② 第 2 回合增援的 `hound` 接着发成 `hound#2`（场上 %d 台）" % (ctx.get("enemies") as Array).size())
	if 二 is Dictionary:
		var 一 = Btl.找单位(ctx, "hound", "enemy")
		t.ok(一 is Dictionary and not is_same(一, 二) and str(一.name) == str(二.name),
			"② 两台同名不同 key（%s / %s）" % [str(一.key), str(二.key)])

## 用第二台的 key 出一张主武器牌 → 战报的目标是 `hound#2`，第一台的 HP 一点没掉
func _按第二台的键打(t) -> void:
	# 用刹那（CB1）当打手：只有 v0.1 / v0.2 / v0.3 的势力才有单机牌组卡池，W1 这类旧势力没有武器栏
	var ctx := Setup.开局([{"键": "CB1", "位": 0, "等级": 30}],
		[{"键": "hound", "位": 0, "等级": 1}, {"键": "hound", "位": 1, "等级": 1}],
		种子, null, SessionBattleOptions.生产(null))
	BattlePhaseFlow.开始我方阶段(ctx)
	var 一 = Btl.找单位(ctx, "hound", "enemy")
	var 二 = Btl.找单位(ctx, "hound#2", "enemy")
	var 打手 = Btl.找单位(ctx, "CB1", "ally")
	if not (一 is Dictionary) or not (二 is Dictionary) or not (打手 is Dictionary):
		t.ok(false, "③ 场没搭起来")
		return
	var 一前 := float(一.hp)
	var 二前 := float(二.hp)
	var 卡 := _挑一张单发武器(ctx, 打手, 二)
	if 卡.is_empty():
		t.ok(false, "③ CB1 没有能打到 `hound#2` 的单发主武器")
		return
	var r := Btl.打出武器栏卡(ctx, "CB1", str(卡.get("id", "")), "hound#2")
	t.ok(bool(r.get("成功", false)), "③ 用 `hound#2` 作目标出【%s】成功（%s）" % [str(卡.get("名")), str(r.get("原因", ""))])
	var 攻击 := _最后一条(ctx, "攻击")
	t.ok(str(攻击.get("目标", "")) == "hound#2",
		"★ ③ 战报里这一发的目标 = `hound#2`（实际 %s）" % str(攻击.get("目标", "")))
	t.ok(is_equal_approx(float(一.hp), 一前),
		"★ ③ 第一台 `hound` 的 HP 一点没掉（%s → %s）" % [J.s(一前), J.s(一.hp)])
	t.ok(float(二.hp) <= 二前, "③ 第二台挨了这一发（%s → %s）" % [J.s(二前), J.s(二.hp)])

func _开(_未用: Array) -> Dictionary:
	return Setup.开局([{"键": "W1", "位": 0, "等级": 30}],
		[{"键": "hound", "位": 0, "等级": 1}, {"键": "hound", "位": 1, "等级": 1}],
		种子, null, SessionBattleOptions.生产(null))

## 武器栏里第一张「单体、非修理 / 非支援、打得到目标」的主武器卡。
func _挑一张单发武器(ctx: Dictionary, u: Dictionary, t: Dictionary) -> Dictionary:
	for 卡 in J.or_(u.get("武器栏"), []):
		if not (卡 is Dictionary):
			continue
		var w = (卡 as Dictionary).get("武器")
		if not (w is Dictionary) or (w as Dictionary).is_empty():
			continue
		var k = Reach.rangeKindOf(w)
		if not J.truthy(k) or Reach.isHealKind(k) or Reach.isSupportKind(k) or Reach.isAreaKind(k):
			continue
		if J.truthy(Reach.武器可达吗(ctx, u, w, t).get("ok")):
			return 卡
	return {}

func _最后一条(ctx: Dictionary, 类型: String) -> Dictionary:
	var 日志: Array = J.or_(ctx.get("log"), [])
	for i in range(日志.size() - 1, -1, -1):
		var e = 日志[i]
		if e is Dictionary and str(e.get("类型", "")) == 类型:
			return e
	return {}
