## DECK-1：确定性 AI 选牌器（结束回合时替「没打过主武器卡」的我方机体补打 1 张）。
##
## 纪律：
##   · 只在 `Params.单机牌组_开(ctx) == true` 时工作；
##   · 复用现成的 `Ai.aiAction`（武器池 / 目标评分 / 修理阈值），**一个 `ctx.rng` 都不额外抽**；
##   · 只打【主武器卡】（u.weapons 里的武器），**绝不打精神牌与公有牌**（那是留给玩家的）。
class_name AiDeck
extends RefCounted

static func auto_play_unit_main_weapon(ctx: Dictionary, u: Dictionary) -> Variant:
	if ctx == null or not (u is Dictionary):
		return null
	if not Params.单机牌组_开(ctx):
		return null
	if float(u.get("hp", 0.0)) <= 0.0:
		return null
	if J.truthy(u.get("主武器已销毁")):
		return null
	var 动作 = Ai.aiAction(u, ctx)
	if 动作 is Dictionary:
		var 条目 = 动作.get("entry")
		if 条目 is Dictionary and 条目.get("t") is Dictionary:
			var 目标键 = null
			var 目标 = 动作.get("target")
			if 目标 is Dictionary:
				目标键 = 目标.get("key")
			return Btl.打出主武器卡(ctx, u.key, 条目.t.get("name"), 目标键)
	# 兜底：按武器池顺序试第一张能打出去的主武器卡（同样不消耗随机数）
	for entry in Calc.usableWeapons(u, ctx):
		if not (entry is Dictionary) or not (entry.get("t") is Dictionary):
			continue
		var w: Dictionary = entry.t
		if not Calc.weaponPlayable(w):
			continue
		var r = Btl.打出主武器卡(ctx, u.key, w.get("name"), null)
		if r is Dictionary and J.truthy(r.get("成功")):
			return r
	return null

## 别名（评审稿里的英文写法）
static func auto_play_unit_weapon(ctx: Dictionary, u: Dictionary) -> Variant:
	return auto_play_unit_main_weapon(ctx, u)
