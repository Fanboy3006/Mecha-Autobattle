## `BattleWeaponExec._找武器栏卡` 的回归：**传字典也要能把武器栏里第 2 张及以后的牌找出来**。
## 修前那个分支在第一张卡上就直接 `return ... else null`，所以传字典只认第 1 张；
## 界面传的是 id 所以玩家碰不到，但原生样例策略 / 以后的调用方传字典会踩到。
extends RefCounted

const 敌方 := [{"键": "fighter", "位": 0, "等级": 1}, {"键": "tank", "位": 1, "等级": 1}]

func _ctx() -> Dictionary:
	var 我方 := [{"键": "A1", "位": 0, "等级": 30}, {"键": "A2", "位": 1, "等级": 30}]
	# 用生产选项（单机牌组 + 秘银v03 + 卡牌流转）：武器栏只在 `卡牌流转` 开着时才拆得出来。
	return Setup.开局(我方, 敌方, 20261019, null, SessionBattleOptions.生产(null))

func _单位(ctx: Dictionary, 键: String) -> Dictionary:
	for u in ctx.allies:
		if u is Dictionary and str((u as Dictionary).get("key", "")) == 键:
			return u
	return {}

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db")
	var ctx := _ctx()
	var u := _单位(ctx, "A1")
	var 栏: Array = u.get("武器栏") if u.get("武器栏") is Array else []
	t.ok(栏.size() >= 2, "A1 的武器栏至少 2 张（实际 %d 张）" % 栏.size())
	if 栏.size() < 2:
		return
	# ① 传 id：改前就能找到（界面的口径）
	t.ok(BattleWeaponExec._找武器栏卡(u, str((栏[1] as Dictionary).get("id", ""))) == 栏[1],
		"传 id 找得到第 2 张（%s）" % str((栏[1] as Dictionary).get("名", "")))
	# ② 传字典：这就是修的那一处
	t.ok(BattleWeaponExec._找武器栏卡(u, 栏[0]) == 栏[0], "传字典找得到第 1 张")
	t.ok(BattleWeaponExec._找武器栏卡(u, 栏[1]) == 栏[1],
		"★ 传字典找得到**第 2 张**（修前这里返回 null）")
	var 末: int = 栏.size() - 1
	t.ok(BattleWeaponExec._找武器栏卡(u, 栏[末]) == 栏[末], "传字典找得到最后一张（第 %d 张）" % (末 + 1))
	t.ok(BattleWeaponExec._找武器栏卡(u, {}) == null, "传一个不在武器栏里的空字典 → null（不会误认第 1 张）")
	t.ok(BattleWeaponExec._找武器栏卡(u, {"id": "不存在"}) == null, "传一个不在武器栏里的字典 → null")
	# ③ 端到端：用字典调 `打出武器栏卡` 真能打出去（改前会退到 `打出主武器卡` 并报「没有这张主武器卡」）
	var 敌 := _单位(ctx, "fighter")
	if 敌.is_empty():
		for e in ctx.enemies:
			敌 = e
			break
	var r := Btl.打出武器栏卡(ctx, "A1", 栏[1], str((敌 as Dictionary).get("key", "")))
	t.ok(bool(r.get("成功", false)),
		"★ 用字典调 `Btl.打出武器栏卡` 打第 2 张成功（改前：%s）" % str(r.get("原因", "成功")))
