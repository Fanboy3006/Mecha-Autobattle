## 职责：士气 —— 气势总攻槽、单机战意与战意费用、连续攻击计次。
class_name BattleMorale
extends RefCounted

## 是不是单机牌组单位。
static func 是单机牌组单位(u: Variant) -> bool:
	return u is Dictionary and u.get("战意") != null

## 单机战意读数。
static func 战意(u: Variant) -> float:
	return J.num0(u.get("战意")) if u is Dictionary else 0.0

static func 战意Of(u: Variant) -> float:
	return 战意(u)

## 设战意（带上限、最低 0）。
static func 设战意(u: Variant, 值: Variant) -> float:
	if not 是单机牌组单位(u):
		return 0.0
	var 上 := J.num0(u.get("战意上限"))
	if 上 <= 0.0:
		上 = Params.战意上限()
	u["战意"] = maxf(0.0, minf(上, J.num0(值)))
	return u["战意"]

static func 连续攻击可用(u: Dictionary, _ctx: Dictionary) -> bool:
	if J.truthy(u.get("连续攻击已用")):
		return false
	return not J.truthy(u.get("本回合再动已用"))

static func 连续攻击记(u: Dictionary, _ctx: Dictionary) -> void:
	u["连续攻击已用"] = true
	u["本回合再动已用"] = true

static func 加战意(u: Variant, 值: Variant, _ctx: Variant = null, _原因: String = "") -> float:
	if not 是单机牌组单位(u):
		return 0.0
	var 上 := J.num0(u.get("战意上限"))
	if 上 <= 0.0:
		上 = Params.战意上限()
	var 前 := J.num0(u.get("战意"))
	var 后 := maxf(0.0, minf(上, 前 + J.num0(值)))
	u["战意"] = 后
	return 后

## 一张牌的战意费用（`战意` 优先，退回 `耗气`）。
static func _战意费用(d: Variant) -> float:
	if not (d is Dictionary):
		return 0.0
	if d.get("战意") != null:
		return maxf(0.0, J.num0(d.get("战意")))
	return maxf(0.0, J.num0(d.get("耗气")))

static func 战意费用(d: Variant) -> float:
	return _战意费用(d)
