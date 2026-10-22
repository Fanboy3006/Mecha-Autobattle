## 职责：Battle 内核的对外门面 —— 每个函数都在这里留一行同名转发（实现在 core/battle 下的八个子模块），
## 调用方（表现层 / 会话层 / 测试 / 内核其它文件）一行都不用改。
class_name Btl
extends RefCounted

const 阶段_我方开始 := "PLAYER_START"
const 阶段_我方主 := "PLAYER_MAIN"
const 阶段_敌方 := "ENEMY_PHASE"

# ---- 战报与描述 → battle_log.gd ----
static func pushLog(ctx: Dictionary, text: String, extra: Variant = null) -> void:
	return BattleLog.pushLog(ctx, text, extra)
static func 记(ctx: Dictionary, 事件: Dictionary) -> void:
	return BattleLog.记(ctx, 事件)
static func 谁(u: Dictionary) -> Dictionary:
	return BattleLog.谁(u)
static func 谁目标(u: Dictionary) -> Dictionary:
	return BattleLog.谁目标(u)
static func 援护剩余文(护者: Variant) -> String:
	return BattleLog.援护剩余文(护者)
static func 目标名Of(结果: Variant) -> Variant:
	return BattleLog.目标名Of(结果)
static func _增益摘要(增: Dictionary) -> String:
	return BattleLog._增益摘要(增)
static func _增益中文(键: String) -> String:
	return BattleLog._增益中文(键)
static func _增益单位(键: String) -> String:
	return BattleLog._增益单位(键)
static func 效果摘要文(摘要: Variant) -> String:
	return BattleLog.效果摘要文(摘要)
static func _最后一条文(ctx: Variant, 类型们: Array) -> String:
	return BattleLog._最后一条文(ctx, 类型们)
static func 攻击结果摘要(结果: Variant) -> Array:
	return BattleLog.攻击结果摘要(结果)

# ---- 士气 → morale.gd ----
static func 是单机牌组单位(u: Variant) -> bool:
	return BattleMorale.是单机牌组单位(u)
static func 战意(u: Variant) -> float:
	return BattleMorale.战意(u)
static func 战意Of(u: Variant) -> float:
	return BattleMorale.战意Of(u)
static func 设战意(u: Variant, 值: Variant) -> float:
	return BattleMorale.设战意(u, 值)
static func 连续攻击可用(u: Dictionary, _ctx: Dictionary) -> bool:
	return BattleMorale.连续攻击可用(u, _ctx)
static func 连续攻击记(u: Dictionary, _ctx: Dictionary) -> void:
	return BattleMorale.连续攻击记(u, _ctx)
static func 加战意(u: Variant, 值: Variant, _ctx: Variant = null, _原因: String = "") -> float:
	return BattleMorale.加战意(u, 值, _ctx, _原因)
static func _战意费用(d: Variant) -> float:
	return BattleMorale._战意费用(d)
static func 战意费用(d: Variant) -> float:
	return BattleMorale.战意费用(d)

# ---- 护卫 / 镜甲 / 自爆 / 敌方词条 → guard.gd ----
static func 嘲讽(ctx: Dictionary, 攻击者: Dictionary, 原目标: Dictionary, 预览: bool = false) -> Variant:
	return BattleGuard.嘲讽(ctx, 攻击者, 原目标, 预览)
static func _可挡枪(u: Variant) -> bool:
	return BattleGuard._可挡枪(u)
static func _靶机援护(ctx: Variant, 原目标: Variant, 预览: bool = false) -> Variant:
	return BattleGuard._靶机援护(ctx, 原目标, 预览)
static func 重置靶机援护(ctx: Variant) -> void:
	return BattleGuard.重置靶机援护(ctx)
static func 当前援护连线们(ctx: Variant) -> Array:
	return BattleGuard.当前援护连线们(ctx)
static func _连线条(护者: Variant, 被护者: Variant, 方: String, 剩: int, 上: int, 标签: String) -> Dictionary:
	return BattleGuard._连线条(护者, 被护者, 方, 剩, 上, 标签)
static func _同列后排友军(ctx: Variant, 方: String, 排除: Variant, 列: int) -> Variant:
	return BattleGuard._同列后排友军(ctx, 方, 排除, 列)
static func _同排友军(ctx: Variant, 方: String, 排除: Variant, 排: float, 列: int) -> Variant:
	return BattleGuard._同排友军(ctx, 方, 排除, 排, 列)
static func 镜甲反弹(ctx: Dictionary, 攻击者: Variant, 防御者: Variant, 一击: Variant, 武器: Variant) -> float:
	return BattleGuard.镜甲反弹(ctx, 攻击者, 防御者, 一击, 武器)
static func 主武器威力(u: Variant) -> float:
	return BattleGuard.主武器威力(u)
static func 自爆(ctx: Dictionary, _击破者: Variant, 死者: Variant, 缘由: Variant = null, 强制: bool = false) -> Variant:
	return BattleGuard.自爆(ctx, _击破者, 死者, 缘由, 强制)
static func 词条到点自爆(ctx: Dictionary, 在场的: Array) -> float:
	return BattleGuard.词条到点自爆(ctx, 在场的)
static func 词条冷却延长(ctx: Dictionary) -> float:
	return BattleGuard.词条冷却延长(ctx)
static func 词条隐身刷新(ctx: Dictionary) -> float:
	return BattleGuard.词条隐身刷新(ctx)
static func 应用全场词条(ctx: Dictionary) -> float:
	return BattleGuard.应用全场词条(ctx)
static func 换同源增益(u: Dictionary, src: Variant, buff: Dictionary) -> void:
	return BattleGuard.换同源增益(u, src, buff)

# ---- 敌方意图 → intent.gd ----
static func _自动目标(ctx: Dictionary, u: Dictionary, 打人: bool) -> Variant:
	return BattleIntent._自动目标(ctx, u, 打人)
static func 算意图(ctx: Dictionary) -> Array:
	return BattleIntent.算意图(ctx)
static func 算意图表(ctx: Dictionary) -> Dictionary:
	return BattleIntent.算意图表(ctx)
static func 刷新敌方意图(ctx: Dictionary) -> Array:
	return BattleIntent.刷新敌方意图(ctx)

# ---- 阶段流转 → phase_flow.gd ----
static func 默认方针() -> Dictionary:
	return BattlePhaseFlow.默认方针()
static func 设单位开关(ctx: Dictionary, 开关表: Variant) -> void:
	return BattlePhaseFlow.设单位开关(ctx, 开关表)
static func 禁止攻击(_u: Variant, _ctx: Variant) -> bool:
	return BattlePhaseFlow.禁止攻击(_u, _ctx)
static func 按防御结算(u: Variant, _ctx: Variant) -> bool:
	return BattlePhaseFlow.按防御结算(u, _ctx)
static func actionOrder(ctx: Dictionary) -> Array:
	return BattlePhaseFlow.actionOrder(ctx)
static func 记击破(ctx: Variant, 攻击者: Variant, 被击破者: Variant) -> void:
	return BattlePhaseFlow.记击破(ctx, 攻击者, 被击破者)
static func 开始我方阶段(ctx: Dictionary) -> void:
	return BattlePhaseFlow.开始我方阶段(ctx)
static func _AI选牌器() -> Variant:
	return BattlePhaseFlow._AI选牌器()
static func 结束我方回合(ctx: Dictionary) -> void:
	return BattlePhaseFlow.结束我方回合(ctx)

# ---- 牌池 / 发牌 / 查找 → card_pool.gd ----
static func 是秘银计入牌(card: Variant) -> bool:
	return BattleCardPool.是秘银计入牌(card)
static func 卡可打吗(ctx: Variant, card: Variant) -> bool:
	return BattleCardPool.卡可打吗(ctx, card)
static func _找队友(ctx: Variant, 键: String) -> Variant:
	return BattleCardPool._找队友(ctx, 键)
static func 提取单位三层信息(u: Variant) -> Dictionary:
	return BattleCardPool.提取单位三层信息(u)
static func 牌来源机体(card: Variant, 单位们: Variant) -> Dictionary:
	return BattleCardPool.牌来源机体(card, 单位们)
static func _单位键(u: Variant) -> String:
	return BattleCardPool._单位键(u)
static func _单位键属于(u: Variant, 键们: Array) -> bool:
	return BattleCardPool._单位键属于(u, 键们)
static func _单位职业(u: Variant) -> String:
	return BattleCardPool._单位职业(u)
static func _单位势力(u: Variant) -> String:
	return BattleCardPool._单位势力(u)
static func _单位显示名(u: Variant) -> String:
	return BattleCardPool._单位显示名(u)
static func 克隆战术牌(c: Variant, ctx: Variant = null) -> Variant:
	return BattleCardPool.克隆战术牌(c, ctx)
static func _是(u: Variant, k: String) -> bool:
	return BattleCardPool._是(u, k)
static func _声明式触发(cond: Dictionary, ctx: Variant, 事件类型: Variant, 计: Dictionary, card: Variant = null) -> bool:
	return BattleCardPool._声明式触发(cond, ctx, 事件类型, 计, card)
static func _触发阈值(card: Dictionary) -> float:
	return BattleCardPool._触发阈值(card)
static func 加卡牌护盾(u: Variant, 盾值: float) -> float:
	return BattleCardPool.加卡牌护盾(u, 盾值)
static func 减单位大招冷却(u: Variant, 减值: Variant, 清零: bool = false) -> void:
	return BattleCardPool.减单位大招冷却(u, 减值, 清零)
static func 减秘银牌冷却(ctx: Variant, card: Variant, 值: int = 1) -> int:
	return BattleCardPool.减秘银牌冷却(ctx, card, 值)
static func 卡牌加标定(目标: Variant, 层数: Variant, 来源名: Variant = "战术牌", 补满: bool = false) -> float:
	return BattleCardPool.卡牌加标定(目标, 层数, 来源名, 补满)
static func 找单位(ctx: Dictionary, 标识: Variant, 方: String) -> Variant:
	return BattleCardPool.找单位(ctx, 标识, 方)
static func _是活体(u: Dictionary) -> bool:
	return BattleCardPool._是活体(u)
static func _键匹配(u: Dictionary, 文: String) -> bool:
	return BattleCardPool._键匹配(u, 文)
static func _按位单位(们: Array, 位号: int) -> Variant:
	return BattleCardPool._按位单位(们, 位号)
static func _卡匹配(c: Variant, 标识: Variant) -> bool:
	return BattleCardPool._卡匹配(c, 标识)
static func _找手牌卡(u: Dictionary, 标识: Variant) -> Variant:
	return BattleCardPool._找手牌卡(u, 标识)
static func _找公有手牌卡(ctx: Dictionary, 标识: Variant) -> Variant:
	return BattleCardPool._找公有手牌卡(ctx, 标识)
static func _找衍生卡(u: Dictionary, 标识: Variant) -> Variant:
	return BattleCardPool._找衍生卡(u, 标识)
static func _找武器(u: Dictionary, 标识: Variant) -> Variant:
	return BattleCardPool._找武器(u, 标识)
static func 身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	return BattleCardPool.身份对口(u, card, ctx)
static func 是衍生攻击卡(c: Variant) -> bool:
	return BattleCardPool.是衍生攻击卡(c)
static func _不销毁主武器(w: Variant) -> bool:
	return BattleCardPool._不销毁主武器(w)
static func _是衍生卡(c: Variant) -> bool:
	return BattleCardPool._是衍生卡(c)

# ---- 出牌执行（战术牌 / 精神牌 / 衍生 / 合体技）→ card_exec.gd ----
static func 是合体技牌(card: Variant) -> bool:
	return BattleCardExec.是合体技牌(card)
static func 合体技参与者(card: Variant) -> Array:
	return BattleCardExec.合体技参与者(card)
static func _ATX实际战意(ctx: Dictionary, card: Dictionary) -> float:
	return BattleCardExec._ATX实际战意(ctx, card)
static func _打出手牌合体技(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	return BattleCardExec._打出手牌合体技(ctx, u, card, target_id)
static func 打出衍生攻击卡(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleCardExec.打出衍生攻击卡(ctx, unit_id, card_inst_id, target_id)
static func play_derived_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleCardExec.play_derived_card(ctx, unit_id, card_inst_id, target_id)
static func _衍生假武器(名: String, 威力: float) -> Dictionary:
	return BattleCardExec._衍生假武器(名, 威力)
static func _执行衍生效果(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	return BattleCardExec._执行衍生效果(ctx, u, card, target_id)
static func 打出精神或公有牌(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleCardExec.打出精神或公有牌(ctx, unit_id, card_inst_id, target_id)
static func play_spirit_or_public_card(ctx: Dictionary, unit_id: Variant, card_inst_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleCardExec.play_spirit_or_public_card(ctx, unit_id, card_inst_id, target_id)
static func _筹码默认目标(ctx: Dictionary, u: Dictionary, card: Variant) -> Variant:
	return BattleCardExec._筹码默认目标(ctx, u, card)
static func _打出专属手牌衍生(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	return BattleCardExec._打出专属手牌衍生(ctx, u, card, target_id)
static func _身份对口(u: Dictionary, card: Dictionary, ctx: Dictionary) -> bool:
	return BattleCardExec._身份对口(u, card, ctx)
static func 牌的势力归属(u: Variant, card: Variant) -> Array:
	return BattleCardExec.牌的势力归属(u, card)
static func _执行精神效果(ctx: Dictionary, u: Dictionary, card: Dictionary) -> Array:
	return BattleCardExec._执行精神效果(ctx, u, card)

# ---- 武器卡执行（主武器 / 武器栏）→ weapon_exec.gd ----
static func 打出主武器卡(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleWeaponExec.打出主武器卡(ctx, unit_id, weapon_or_card_id, target_id)
static func play_unit_weapon_card(ctx: Dictionary, unit_id: Variant, weapon_or_card_id: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleWeaponExec.play_unit_weapon_card(ctx, unit_id, weapon_or_card_id, target_id)
static func 武器栏不可打原因(ctx: Dictionary, u: Dictionary, 卡: Variant, target_id: Variant = null) -> String:
	return BattleWeaponExec.武器栏不可打原因(ctx, u, 卡, target_id)
static func _自动武器栏卡(ctx: Dictionary, u: Dictionary, target_id: Variant = null) -> Variant:
	return BattleWeaponExec._自动武器栏卡(ctx, u, target_id)
static func _找武器栏卡(u: Dictionary, 标识: Variant) -> Variant:
	return BattleWeaponExec._找武器栏卡(u, 标识)
static func 打出武器栏卡(ctx: Dictionary, unit_id: Variant, 标识: Variant = null, target_id: Variant = null) -> Dictionary:
	return BattleWeaponExec.打出武器栏卡(ctx, unit_id, 标识, target_id)
static func _存活敌(ctx: Dictionary, u: Dictionary, target_id: Variant) -> Variant:
	return BattleWeaponExec._存活敌(ctx, u, target_id)
static func _执行武器攻击(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	return BattleWeaponExec._执行武器攻击(ctx, u, entry, target_id)
static func _执行修理卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	return BattleWeaponExec._执行修理卡(ctx, u, entry, target_id)
static func _执行支援卡(ctx: Dictionary, u: Dictionary, entry: Dictionary, target_id: Variant) -> Dictionary:
	return BattleWeaponExec._执行支援卡(ctx, u, entry, target_id)
static func _执行铁壁护卫(ctx: Dictionary, u: Dictionary, entry: Dictionary) -> Dictionary:
	return BattleWeaponExec._执行铁壁护卫(ctx, u, entry)
static func _打出手牌主武器(ctx: Dictionary, u: Dictionary, card: Dictionary, target_id: Variant) -> Dictionary:
	return BattleWeaponExec._打出手牌主武器(ctx, u, card, target_id)
