## 会话门面的「六之二 悬停说明」子模块 —— 机体 / 卡面 / 零件 / 藏品的 Mouse Over 文本（纯读）。
## 约定：纯静态函数，不持有 `GameSession`；状态一律经 `session` 读写，返回值与搬迁前逐字一致（`GameSession` 上有同名转发）。
class_name SessionTooltipText
extends RefCounted

## 战斗中一台单位的悬停说明（多行）
static func unit_hover_text(session: GameSession, side: String, unit_key: String) -> String:
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	if session.battle_ctx.is_empty():
		return "【%s】现在不在战斗里 —— 开一场战斗之后这里会给出这台机体的实时状态与武器冷却。" % unit_key
	var u := session._找单位(unit_key)
	if u.is_empty():
		return "【%s】%s这一方没有这台单位。" % [unit_key, "我方" if 方 == "ally" else "敌方"]
	return _单位说明文字(session, 方, u, true)

## 局外（名册 / 编队格位 / 招募候选）一台机体的悬停说明
static func template_unit_hover_text(session: GameSession, unit_key: String, level: int = 10, is_enemy: bool = false) -> String:
	session._data_ready()
	var 键 := unit_key
	if 键.is_empty():
		return "没有指定机体键。"
	var 方 := "enemy" if is_enemy else "ally"
	var lv := level
	if lv <= 0:
		lv = int(float(Units.默认等级(键, 方)))
	var tpl: Dictionary = {}
	if is_enemy:
		var 敌表: Variant = Db.T.get("ENEMY_T")
		if 敌表 is Dictionary:
			var e: Variant = (敌表 as Dictionary).get(键)
			if e is Dictionary:
				tpl = e
	if tpl.is_empty():
		tpl = RosterManager.模板(键)
	if tpl.is_empty():
		return "【%s】数据表里没有这台机体。" % 键
	var u := Units.makeUnit(键, 方, 0.0, float(lv))
	if u.is_empty():
		return "【%s】（Lv%s）内核造不出这台机体的快照。" % [键, session._界面文本(lv)]
	return _单位说明文字(session, 方, u, false)

## 一张战术牌的悬停说明（多行）
static func card_hover_text(session: GameSession, card_or_id: Variant) -> String:
	session._data_ready()
	var c: Dictionary = {}
	if card_or_id is Dictionary:
		c = (card_or_id as Dictionary).duplicate(true)
		var 目录 := DeckBuilder.找到(str(c.get("id", "")))
		for k in 目录.keys():
			if not c.has(k) or c[k] == null:
				c[k] = 目录[k]
	elif card_or_id is String or card_or_id is StringName:
		c = DeckBuilder.找到(str(card_or_id))
	if c.is_empty():
		return "【%s】数据表里没有这张战术牌。" % session._界面文本(card_or_id)
	var id := str(c.get("id", ""))
	var 段: Array = []
	段.append("【%s】（%s · 归属 %s · 精神标签 %s）" % [str(c.get("名", id)), str(c.get("层级", "—")),
		str(c.get("归属", "—")), str(c.get("精神标签", "—"))])
	段.append("消耗与限制：耗气 %s · 回气 %s · 冷却 %s 回合 · 每场限次 %s" % [_数(session, c.get("耗气", 0)),
		_数(session, c.get("回气", 0)), _数(session, c.get("冷却", 0)), _限次文字(session, c.get("限次"))])
	段.append("入牌方式：%s（条件码 %s）" % [str(c.get("入牌", "—")), str(c.get("触发条件码", "—"))])
# ★ UX-2 第 1 项：这张牌是**哪台机体**带出来的（角色 / 职业 / 势力 / 统帅，纯读解析）。
	var 源 := Btl.牌来源机体(c, session._我方阵())
	var 源类 := str(源.get("类别", ""))
	段.append("来源机体：%s · %s牌" % [str(源.get("文本", "")),
		"战术" if (源类.is_empty() or 源类 == "未知") else 源类])
	段.append("触发条件：%s" % str(c.get("触发说明", "—")))
	段.append("效果说明：%s" % str(c.get("效果说明", "—")))
# ★ MITH-3 预告层（悬停说明）：衍生牌写清打出后移除；连携牌写清条件与当前进度。
	var 本回合秘银 := int(session.battle_ctx.get("本回合秘银牌数", 0)) if not session.battle_ctx.is_empty() else 0
	if bool(c.get("衍生", false)):
		段.append("【衍生牌 · 打出后移除】")
	else:
		var 阈 := int(c.get("连携阈值", 0))
		if 阈 > 0:
			段.append("连携条件：【连携·%d】（当前本回合秘银牌：%d / %d，%s）" % [
				阈, 本回合秘银, 阈, "已就绪" if 本回合秘银 >= 阈 else "未就绪"])
	return "\n".join(段)

## 这一件零件**现在能不能用**（纯读
static func part_can_use_now(session: GameSession, idx: int) -> Dictionary:
	session._data_ready()
	var 空 := {"ok": false, "passive": false, "instant": false, "no_target_select": false,
		"targets": [], "why": "", "key": "", "name": "", "left": -1,
		"free": false, "rarity": "low", "breakOnNextFloor": false, "sell": 0, "类": ""}
	var s := session.run_state
	if s == null:
		空["why"] = "还没有进行中的局"
		return 空
	if idx < 0 or idx >= s.parts.size():
		空["why"] = "没有这件零件（下标 %d，手上有 %d 件）" % [idx, s.parts.size()]
		return 空
	var 件: Variant = s.parts[idx]
	var 键 := PartSystem.part_key(件)
	var 信息 := PartSystem.part_info(键)
	var 名 := str(信息.get("名", 键))
	var 左 := -1
	if 件 is Dictionary and (件 as Dictionary).get("uses") != null:
		左 = int((件 as Dictionary).get("uses"))
	var 免费 := PartSystem.part_is_free(键)
	var d := {"ok": false, "passive": false, "instant": false, "no_target_select": false,
		"targets": [], "why": "", "key": 键, "name": 名, "left": 左,
		"free": 免费, "rarity": PartSystem.part_rarity(键),
		"breakOnNextFloor": PartSystem.part_breaks_on_next_floor(键),
		"sell": PartSystem.sell_price(件), "类": str(信息.get("类", ""))}
	if 信息.is_empty() or not bool(信息.get("用", false)):
		d["passive"] = true
		d["why"] = "常驻被动生效，无需手动点击使用"
		return d
	if str(session.screen) != "map":
		d["why"] = "请在大地图界面点击使用"
		return d
	if 左 == 0:
		d["why"] = "本层使用次数已用尽"
		return d
	if not 免费 and int(s.propellant) < 1:
		d["why"] = "推进剂不足（需 1 点）"
		return d
	var 一键 := 键 == "bagua"
	if 一键:
		d["instant"] = true
		d["no_target_select"] = true
	var 目标: Array = PartSystem.part_targets(s, 键)
	d["targets"] = 目标
	if 目标.is_empty():
		d["why"] = "本层没有可以传送的非战斗格" if 一键 else "当前位置附近没有可作用的地图格"
		return d
	d["ok"] = true
	return d

static func part_hover_text(session: GameSession, idx: int) -> String:
	var 状 := part_can_use_now(session, idx)
	var 被 := bool(状.get("passive", false))
	var 键 := str(状.get("key", ""))
	var 信息 := PartSystem.part_info(键)
	var 类 := str(信息.get("类", 状.get("类", "")))
	var 段: Array = []
	段.append("【%s】（稀有度 %s · %s）" % [str(状.get("name", "")),
		PartSystem.rarity_name(str(状.get("rarity", "low"))),
		"常驻被动（不用点，带着就生效）" if 被 else "主动零件（点一下用掉一次）"])
	var 说明 := str(信息.get("说明", ""))
	if 说明.is_empty():
		说明 = str(信息.get("效果", ""))
	段.append("效果：%s" % (说明 if not 说明.is_empty() else "（数据表里没有写说明）"))
	var 左 := int(状.get("left", -1))
	段.append("剩余次数：%s" % ("常驻，不计次数" if 被 or 左 < 0 else session._界面文本(左)))
	段.append("推进剂：%s" % ("免推进剂" if bool(状.get("free", false)) else "消耗 1 推进剂"))
	if bool(状.get("breakOnNextFloor", false)):
		段.append("跨层：跨层自动损坏（进入下一层时从手上移除）")
	if 类 == "自然物":
		段.append("出售价：%d 源碳（黑市按当前估价收）" % int(状.get("sell", 0)))
	else:
		段.append("出售价：1 源碳（加工品 / 概念体固定）")
	if bool(状.get("instant", false)):
		段.append("用法：一键发动（不用选落点），随机传送到一个非战斗格")
	else:
		var 目标: Array = 状.get("targets") if 状.get("targets") is Array else []
		段.append("这一版能作用 %s 格" % session._界面文本(目标.size()))
	if bool(状.get("ok", false)):
		段.append("现在可用：点击后在大地图选择高亮目标格生效" if not bool(状.get("instant", false))
			else "现在可用：点击直接发动随机传送")
	else:
		段.append("现在用不了：%s" % str(状.get("why", "")))
	return "\n".join(段)

static func relic_hover_text(session: GameSession, relic_id: String) -> String:
	session._data_ready()
	var id := relic_id
	var r := RelicSystem.件(id)
	if r.is_empty():
		return "【%s】数据表里没有这件藏品。" % session._界面文本(id)
	var 段: Array = []
	段.append("【%s】（稀有度 %s · %s）" % [str(r.get("名", id)), str(r.get("稀有", "—")), str(r.get("分类", "—"))])
	段.append("藏品键：%s · 实装：%s" % [id, str(r.get("实装", "—"))])
	var 说明 := str(r.get("说明", ""))
	段.append("效果说明：%s" % (说明 if not 说明.is_empty() else "（数据表里没有写说明）"))
	var 加成 := _藏品数值文字(session, RelicSystem.数值(r))
	段.append("数值加成：%s" % (加成 if not 加成.is_empty() else "（这件没有数值加成）"))
	段.append("来源：黑市买 / 精英与 Boss 战胜利发放 / 遗迹探明")
	return "\n".join(段)

static func _藏品数值文字(session: GameSession, v: Variant, 前缀: String = "") -> String:
	if v is Dictionary:
		var 段: Array = []
		for k in (v as Dictionary).keys():
			var 子 := _藏品数值文字(session, (v as Dictionary)[k], str(k) if 前缀.is_empty() else 前缀 + "." + str(k))
			if not 子.is_empty():
				段.append(子)
		return " · ".join(段)
	if v is Array:
		var 项: Array = []
		for x in (v as Array):
			项.append(str(x))
		var 体 := "、".join(项)
		return 体 if 前缀.is_empty() else "%s = %s" % [前缀, 体]
	if v == null:
		return ""
	return session._界面文本(v) if 前缀.is_empty() else "%s = %s" % [前缀, session._界面文本(v)]

## 一台单位的整段说明
static func _单位说明文字(session: GameSession, 方: String, u: Dictionary, 战斗中: bool) -> String:
	var 键 := str(u.get("key", ""))
	var 标签: Dictionary = u.get("tags") if u.get("tags") is Dictionary else {}
	var 分类 := str(标签.get("战斗分类", ""))
	var 势力 := str(标签.get("势力", ""))
	var 头 := "【%s】%s · Lv%s · %s · %s" % [str(u.get("mech", 键)), str(u.get("pilot", u.get("name", 键))),
		_数(session, u.get("lv", 0)), 分类 if not 分类.is_empty() else "—", 势力 if not 势力.is_empty() else "—"]
	if 战斗中:
		头 += " · %s" % Fm.位名(float(u.get("slot", 0.0)))
	var 段: Array = [头]
	var 生命 := float(u.get("hp", 0.0))
	var 满 := float(u.get("maxHp", 1.0))
	if 满 <= 0.0:
		满 = 1.0
	var 护盾 := _数(session, u.get("shieldHp", u.get("shield", 0)))
	if 战斗中:
		段.append("生命 %s / %s（%s%%）· 护盾 %s · 在场 %s" % [_数(session, 生命), _数(session, 满),
			_数(session, 生命 / 满 * 100.0), 护盾,
			"是" if 生命 > 0.0 else "已经倒下"])
	else:
		段.append("生命 %s / %s · 护盾 %s" % [_数(session, 生命), _数(session, 满), 护盾])
	段.append("装甲 %s · 防御 %s · 机动 %s · 移动 %s · 闪避 %s · 命中基础 %s" % [_数(session, u.get("armor", 0)),
		_数(session, u.get("defense", 0)), _数(session, u.get("eva", 0)), _数(session, u.get("mov", 0)), _数(session, u.get("eva", 0)),
		_数(session, u.get("aim", 0))])
	段.append("格斗 %s · 射击 %s · 觉醒 %s" % [_数(session, u.get("melee", 0)), _数(session, u.get("shoot", 0)),
		_数(session, u.get("awaken", 0))])
	var 特性 := str(u.get("trait", "")) if u.get("trait") != null else ""
	var 技: Array = u.get("abilities") if u.get("abilities") is Array else []
	段.append("特性：%s" % (特性 if not 特性.is_empty() else "（没有登记）"))
	段.append("技能：%s" % ("、".join(技.map(func(x): return session._界面文本(x))) if not 技.is_empty() else "（没有登记）"))
	var 武: Array = u.get("weapons") if u.get("weapons") is Array else []
	段.append("武器（%d 把）：" % 武.size())
	if 武.is_empty():
		段.append("· （这台机体没有登记武器）")
	for w in 武:
		段.append(_武器行文字(session, w, 战斗中))
	if not 战斗中:
		return "\n".join(段)
	段.append("状态：%s" % " · ".join(session._状态行(方, u)))
	var 增 := session._增益文字们(u.get("buffs"))
	var 减 := session._增益文字们(u.get("debuffs"))
	段.append("增益：%s" % ("、".join(增) if not 增.is_empty() else "（没有）"))
	段.append("减益：%s" % ("、".join(减) if not 减.is_empty() else "（没有）"))
	if 方 == "enemy":
		段.append_array(_意图行(session, u))
	return "\n".join(段)

## 一把武器的说明行
static func _武器行文字(session: GameSession, 条目: Variant, 战斗中: bool) -> String:
	if not (条目 is Dictionary):
		return "· （认不出来的武器条目）"
	var 运行: Dictionary = {}
	var w: Dictionary = 条目
	if (条目 as Dictionary).get("t") is Dictionary:
		运行 = 条目
		w = 运行["t"]
	if w.is_empty():
		return "· （认不出来的武器条目）"
	var 段: Array = ["威力 %s" % _数(session, w.get("power", 0)), "命中 %s%%" % _数(session, w.get("hit", 0))]
	var 段数: Variant = w.get("hits")
	if 段数 == null:
		段数 = w.get("hitsMax")
	if 段数 != null:
		段.append("段数 %s" % _数(session, 段数))
	var 范: Variant = w.get("range")
	if 范 is Array and (范 as Array).size() >= 2:
		段.append("射程 %s-%s" % [_数(session, (范 as Array)[0]), _数(session, (范 as Array)[1])])
	var 类: Variant = Reach.rangeKindOf(w)
	if 类 != null:
		段.append(str(类))
	段.append("出手 %s" % str(w.get("fire", "—")))
	段.append("伤害类型 %s" % str(w.get("dmgType", "—")))
	段.append("能力值 %s" % str(w.get("stat", "—")))
	段.append("冷却 %s 回合" % _数(session, w.get("cd", 0)))
	段.append("每场限次 %s" % _限次文字(session, w.get("uses")))
	段.append("解锁 Lv%s" % _数(session, w.get("unlock", 1)))
	if bool(w.get("大招", false)):
		段.append("大招")
	if bool(w.get("ignoreDef", false)):
		段.append("无视防御")
	if w.get("special") != null:
		段.append("特殊 %s" % str(w.get("special")))
	if 战斗中:
		var cd运行 := int(JsCompat.js_round(float(运行.get("cd", 0.0)))) if not 运行.is_empty() else 0
		段.append("★ 当前冷却 %s 回合" % session._界面文本(cd运行))
		if not 运行.is_empty():
			段.append("★ 剩余次数 %s" % _限次文字(session, 运行.get("uses")))
	var 文 := "· 【%s】%s" % [str(w.get("name", "（无名）")), " · ".join(段)]
	var 说明 := str(w.get("desc", ""))
	if not 说明.is_empty():
		文 += "\n    效果：%s" % 说明
	return 文

static func _意图行(session: GameSession, u: Dictionary) -> Array:
	var out: Array = []
	if session.battle_ctx.is_empty():
		return out
	var 动作: Variant = Boss.bossAction(u, session.battle_ctx)
	if not (动作 is Dictionary):
		out.append("下一拍意图：这一拍打不到人")
		return out
	var a: Dictionary = 动作
	var 文 := "下一拍意图："
	var w: Variant = a.get("weapon")
	if w is Dictionary:
		文 += "【%s】" % str((w as Dictionary).get("name", ""))
	else:
		文 += "普通攻击"
	var 目标: Variant = a.get("target")
	if 目标 is Dictionary:
		文 += " → %s（%s）" % [str((目标 as Dictionary).get("name", "")), Fm.位名(float((目标 as Dictionary).get("slot", 0.0)))]
	var 期望 := float(a.get("expected", 0.0))
	if 期望 > 0.0:
		文 += " · 期望 %s" % _数(session, 期望)
	if bool(a.get("被挡", false)):
		文 += " · 被挡 -20"
	if w is Dictionary and Ai.isUltimate(w):
		文 += " · 大招"
	if bool(a.get("大技能", false)):
		文 += " · Boss 大技能"
	out.append(文)
	var 参: Variant = Boss.Boss参数(u)
	if 参 is Dictionary:
		var p: Dictionary = 参
		out.append("Boss 第 %s 阶段 · 伤害倍率 ×%s" % [_数(session, p.get("第几阶段", 1)), session._界面文本(p.get("伤害倍率", 1.0))])
	return out

static func _限次文字(session: GameSession, v: Variant) -> String:
	return "不限" if v == null else _数(session, v)

static func _数(session: GameSession, v: Variant) -> String:
	if v == null:
		return "—"
	if v is int:
		return str(int(v))
	if v is float:
		return str(int(JsCompat.js_round(float(v))))
	return str(v)
