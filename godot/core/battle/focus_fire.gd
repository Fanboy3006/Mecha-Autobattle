## 职责：IT-5 ②【破绽】（作者 10-21 拍板）—— 同一回合内，敌机被我方一台机体打中后露出破绽：
##   本回合**其他**我方机体再打它，伤害 +15%（不叠层；同一台机体自己补刀不算）。
## 约定：开关 `选项.集火破绽 == false` 关掉（默认开）；只记我方打敌方。规则正文：`协作/迭代/IT-5-战术选择体检-v0.1.md`。
class_name FocusFire
extends RefCounted

const 选项键 := "集火破绽"
const 加成 := 0.15

static func 开(ctx: Variant) -> bool:
	if not (ctx is Dictionary):
		return false
	var 选 = (ctx as Dictionary).get("选项")
	return not (选 is Dictionary and (选 as Dictionary).get(选项键) == false)

static func _账(ctx: Dictionary) -> Dictionary:
	var 账: Variant = ctx.get("破绽")
	var 回合 := int(ctx.get("turn", 1))
	if not (账 is Dictionary) or int((账 as Dictionary).get("回合", -1)) != 回合:
		账 = {"回合": 回合, "表": {}}
		ctx["破绽"] = 账
	return 账["表"]

static func _我打敌(att: Variant, def: Variant) -> bool:
	return att is Dictionary and def is Dictionary \
		and str((att as Dictionary).get("side", "")) == "ally" and str((def as Dictionary).get("side", "")) == "enemy"

## 本回合打中过这台敌机的我方机体键（纯读）。
static func 打中过的(ctx: Dictionary, def: Dictionary) -> Array:
	return (_账(ctx).get(str(def.get("key", "")), []) as Array).duplicate()

static func 有破绽(ctx: Variant, att: Variant, def: Variant) -> bool:
	if not 开(ctx) or not _我打敌(att, def):
		return false
	for k in 打中过的(ctx, def):
		if str(k) != str(att.get("key", "")):
			return true
	return false

static func 攻方伤害倍率(ctx: Variant, att: Variant, def: Variant, _w: Variant) -> float:
	return 1.0 + 加成 if 有破绽(ctx, att, def) else 1.0

static func 武器攻击后(ctx: Dictionary, att: Variant, def: Variant, landed: Variant, _w: Variant) -> void:
	if not 开(ctx) or not _我打敌(att, def) or float(J.num0(landed)) <= 0.0:
		return
	var 表 := _账(ctx)
	var 键 := str(def.get("key", ""))
	var 们: Array = 表.get(键, [])
	var 我 := str(att.get("key", ""))
	if 们.has(我):
		return
	们.append(我)
	表[键] = 们
	if 们.size() == 1 and float(def.get("hp", 0.0)) > 0.0:
		Btl.pushLog(ctx, "〔破绽〕%s 被 %s 打中 → 本回合其他队友打它伤害 +%d%%" % [
			str(def.get("name", "")), str(att.get("name", "")), int(加成 * 100.0)],
			J.merged({"类型": "破绽"}, Btl.谁(def)))
