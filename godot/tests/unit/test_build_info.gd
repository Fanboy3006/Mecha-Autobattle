## ★ BUILD：主菜单那行「版本 0.7.1-m0（<提交> · <构建时间>）· 规则参考 …」的取名逻辑。
## 构建信息由 CI / 导出脚本写进 `data/build_info.json`（不进版本库）；没有文件 = 本地开发版，括号那一段整个不显示。
extends RefCounted

func run(t) -> void:
	var 旧 := GameVersion.构建
	GameVersion.构建 = {}
	t.ok(GameVersion.构建串() == "", "没有构建信息（本地开发版）→ 括号里什么都不显示")
	GameVersion.构建 = {"commit": "abc1234", "commit_long": "abc1234ffff", "built_at": "2026-10-20 22:14 UTC"}
	t.ok(GameVersion.构建串() == "（abc1234 · 2026-10-20 22:14 UTC）",
		"有构建信息 → 「（提交 · 构建时间）」（%s）" % GameVersion.构建串())
	GameVersion.构建 = {"commit": "abc1234"}
	t.ok(GameVersion.构建串() == "（abc1234）", "只有提交、没有时间 → 只显示提交")
	t.ok(GameVersion.GAME_VERSION.begins_with("0.7.1"), "版本号已推到 0.7.1（%s）" % GameVersion.GAME_VERSION)
	GameVersion.构建 = 旧
