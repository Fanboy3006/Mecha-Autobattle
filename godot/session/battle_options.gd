## 职责：生产战斗选项的**唯一来源** —— 节点战 / 追击战 / 快速测试 / 会话缓存都从这里取。
## 约定：纯静态函数，不持有 `GameSession`；只拼选项，不读不改任何内核状态、不掷随机数。
class_name SessionBattleOptions
extends RefCounted

## 玩家真正开战时用的选项（`全卡池体验` = 菜单那两个快速测试入口）；单机牌组是唯一模式，不再有开关。
static func 生产(run_state: RunState, 全卡池体验: bool = false) -> Dictionary:
	var o := {}
	if run_state == null:
		o = {"战术卡牌": true, "已选战术牌": [], "藏品": []}
	else:
		o = RelicSystem.build_battle_options(run_state)
		o["战术卡牌"] = true
	o["单机牌组"] = true
	o["秘银v03"] = true
	o["卡牌流转"] = true
	if 全卡池体验:
		o["快速测试"] = true
		o["全卡池体验"] = true
	return o
