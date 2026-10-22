## 显示名取名入口：玩家看得到的名字一律从这里取（去版权化-A），键是内部 id。
## 纯读 Db.T，不碰场景树和文件。
class_name DisplayNames
extends RefCounted

## 表里有该类别该 id 就用表里的文字；没有就用 兜底，兜底为空则返回 id 本身。
static func 名(类别: String, id: String, 兜底: String = "") -> String:
	var 表 = Db.T.get("显示名")
	if 表 is Dictionary:
		var 区 = (表 as Dictionary).get(类别)
		if 区 is Dictionary and (区 as Dictionary).has(id):
			return str((区 as Dictionary)[id])
	return 兜底 if 兜底 != "" else id

## 卡名：`卡牌` 区有该卡 id 的覆盖就用覆盖，否则用卡包里的 `名`。
static func 卡名(卡: Dictionary) -> String:
	var 表 = Db.T.get("显示名")
	if 表 is Dictionary:
		var 区 = (表 as Dictionary).get("卡牌")
		if 区 is Dictionary and (区 as Dictionary).has(str(卡.get("id", ""))):
			return str((区 as Dictionary)[str(卡.get("id", ""))])
	return str(卡.get("名", ""))
