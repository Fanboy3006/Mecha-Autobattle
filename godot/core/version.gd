## 版本信息。显示在界面、写进存档与录像。
class_name GameVersion
extends RefCounted

## Godot 版自己的版本号（里程碑推进时更新）
const GAME_VERSION := "0.7.1-m0"
## 玩法语义来源：JS 参考版的封存 tag 与它的规则签名
const RULES_REFERENCE := "js-reference-final · r1:05a9cbf9"

## 构建信息（CI / 导出脚本写的 `data/build_info.json`；没有 = 本地开发版，留空）。
## 只放纯数据（`commit` / `built_at`），由 `DataLoader.install` 灌进来 —— core 自己不读文件。
static var 构建: Dictionary = {}

## 主菜单那一段「（342ec24 · 2026-10-20 22:14 UTC）」；没有构建信息就返回空串。
static func 构建串() -> String:
	var 段: Array = []
	var 提交 := str(构建.get("commit", ""))
	var 时间 := str(构建.get("built_at", ""))
	if 提交 != "":
		段.append(提交)
	if 时间 != "":
		段.append(时间)
	return "" if 段.is_empty() else "（%s）" % " · ".join(段)
