## 战斗内核读数据的唯一入口：Db.T.<常量名>（与 JS 里直接写全局常量名一一对应，如 Db.T.ENEMY_T、Db.T.战斗结构）。
## 由会话层在启动时 Db.install(GameData) 装入；内核只读，不改。
class_name Db
extends RefCounted

static var T: Dictionary = {}
static var installed: bool = false

static func install(data: GameData) -> void:
	T = data.consts()
	installed = true
