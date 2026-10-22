## 职责：用生产选项 + 确定性出牌策略重跑一场**原生**黄金样例（RT-2：新模式的标准答案）。
## 约定：只读 `输入`（我方 / 敌方规格 / 种子 / 编成 / 藏品），不读旧样例的期望；回合摘要只记新模式白名单字段。
class_name NativeGoldenRunner
extends RefCounted

## 只给玩家看、不参与对拍的字段（旧样例 `DISPLAY_ONLY` 的同口径）。
const DISPLAY_ONLY := ["文本", "效果说明", "触发说明", "来源文本", "来源位"]
## 不进套样的回合摘要键：闸门 G 会让它们归零或消失（施工单 §RT-2d + 补充要求 3）。
const 不记的计数键 := ["满手牌推迟数"]

## 跑一场。`样例` = inputs.json 里的一条（数值已 decode）。
static func run(样例: Dictionary) -> Dictionary:
	var 开 := 开局(样例)
	if not bool(开.get("ok", false)):
		return {"id": str(样例.get("id", "")), "错误": str(开.get("原因", "开局失败"))}
	var ctx: Dictionary = 开["ctx"]
	var 策略 := NativeGoldenPolicy.new()
	var 摘要们 := [摘要(ctx)]
	var 顶 := maxf(float(Db.T.MAX_TURN), J.num0(ctx.get("回合上限")) if J.truthy(ctx.get("回合上限")) else float(Db.T.MAX_TURN)) + 2.0
	var 护栏 := 0.0
	var 策略错误: Array = []
	var 策略rng := 0
	var 出牌们: Array = []
	while ctx.result == null and 护栏 < 顶:
		护栏 += 1.0
		var r := 策略.出牌阶段(ctx)
		策略rng += int(r["选择rng"])
		出牌们.append_array(r["出牌"])
		if str(r.get("失败", "")) != "":
			策略错误.append("回合 %s：%s" % [J.s(ctx.turn), str(r["失败"])])
			break
		Btl.结束我方回合(ctx)
		摘要们.append(摘要(ctx))
	if ctx.result == null:
		ctx.result = {"结果": "败", "原因": "超出回合上限"}
	Btl.pushLog(ctx, "战斗结束：%s（%s）" % [ctx.result.结果, ctx.result.原因], {"类型": "结束"})
	var events := []
	for i in (ctx.get("log") as Array).size():
		var o := {}
		for k in (ctx.log[i] as Dictionary).keys():
			if not DISPLAY_ONLY.has(String(k)):
				o[String(k)] = 纯数据(ctx.log[i][k])
		o["_rng"] = int(ctx._rng_at[i])
		events.append(o)
	return {
		"id": str(样例.get("id", "")),
		"期望": {
			"事件": events,
			"回合摘要": 摘要们,
			"结果": {"结果": ctx.result.结果, "原因": ctx.result.原因, "回合": ctx.turn},
		},
		"策略错误": 策略错误,
		"策略rng步数": 策略rng,
		"出牌": 出牌们,
	}

## 开局：`quick` 组走快速测试真路径（种子由门面自己变换），其余走 `Setup.开局` + 生产选项。
## 波次：用**生产同一个函数** `NodeResolver.增援波次(编成条目, 0)` 算；编成条目从 `Db.catalog.stages()` 里
## 按「敌方规格」逐条对上（旧样例导出的 `编成` 常只剩 {层, 类型}，而 `层` 又被导成 null，所以比对时忽略 `层`）。
static func 开局(样例: Dictionary) -> Dictionary:
	var 种子 = 样例.get("种子", 0)
	if str(样例.get("组", "")) == "quick":
		var s := GameSession.new()
		if not s.开始快速测试战斗(str(样例.get("快速测试阵容", GameSession.快速测试_秘银)), int(float(种子))):
			return {"ok": false, "原因": "快速测试开不起来"}
		if s.battle_ctx.is_empty():
			return {"ok": false, "原因": "快速测试没有给出 ctx"}
		return {"ok": true, "ctx": s.battle_ctx}
	var 选项 := SessionBattleOptions.生产(null)
	选项["藏品"] = 样例.get("藏品", [])
	var 真条目 := 认编成(样例)
	if not 真条目.is_empty():
		选项["波次"] = NodeResolver.增援波次(真条目, 0)
	var ctx := Setup.开局(样例.get("我方", []), 样例.get("敌方规格", []), 种子, null, 选项)
	if ctx.is_empty():
		return {"ok": false, "原因": "Setup.开局 返回空 ctx"}
	return {"ok": true, "ctx": ctx}

## 按「敌方规格」认出这一场用的是 `编成表` 里的哪一条（忽略 `层`：导出的样例把它写成了 null）。
## 认不出 / 有多条同形 → 返回 `{}`（不猜）。
static func 认编成(样例: Dictionary) -> Dictionary:
	var 表 := _编成索引()
	var k := _规整规格(样例.get("敌方规格", []))
	var 命中: Variant = 表.get(k)
	if 命中 is Array and (命中 as Array).size() == 1:
		return (命中 as Array)[0]
	return {}

static var _索引缓存: Dictionary = {}

static func _编成索引() -> Dictionary:
	if not _索引缓存.is_empty():
		return _索引缓存
	for e in Db.catalog.stages():
		if not (e is Dictionary):
			continue
		var k := _规整规格(NodeResolver.编成到规格(e, 0))
		if not _索引缓存.has(k):
			_索引缓存[k] = []
		(_索引缓存[k] as Array).append(e)
	return _索引缓存

static func _规整规格(规格: Array) -> String:
	var 出: Array = []
	for e in 规格:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		出.append([str(d.get("键", "")), float(d.get("位", 0.0)), float(d.get("等级", 0.0)),
			float(d.get("强化", 1.0)), JSON.stringify(d.get("词条", []))])
	出.sort()
	return JSON.stringify(出)

## 回合摘要（**白名单**：只记新模式的字段）。
## 每台机体：hp / maxHp / shieldHp / 掩护盾 / buffs / debuffs / 战意 / 主武器状态 / 武器 cd·uses / 势力状态
##          + 牌组各区张数与手牌 id。全局：回合 / 阶段 / rng 步数 / 公有三区的 id / 战况计数 / 结果。
static func 摘要(ctx: Dictionary) -> Dictionary:
	var 单位 := []
	for u in NativeGoldenPolicy.按槽位(ctx.allies) + NativeGoldenPolicy.按槽位(ctx.enemies):
		单位.append(_单位摘要(u))
	var r = ctx.get("result")
	return {
		"回合": ctx.turn, "阶段": str(ctx.get("阶段", "")), "rng": float(ctx.rng.steps),
		"公有牌库": _id们(ctx.get("公有牌库")), "公有手牌": _id们(ctx.get("公有手牌")),
		"公有弃牌堆": _id们(ctx.get("公有弃牌堆")),
		"战况计数": _计数摘要(ctx.get("战况计数")),
		"结果": {"结果": r.结果, "原因": r.原因} if r is Dictionary else null,
		"单位": 单位,
	}

static func _单位摘要(u: Dictionary) -> Dictionary:
	return {
		"方": u.side, "位": u.slot, "键": u.key, "hp": u.hp, "maxHp": u.maxHp,
		"shieldHp": J.or_(u.get("shieldHp"), 0.0), "掩护盾": J.or_(u.get("掩护盾"), 0.0),
		"buffs": J.or_(u.get("buffs"), []), "debuffs": J.or_(u.get("debuffs"), []),
		"战意": J.or_(u.get("战意"), null),
		"主武器已销毁": J.truthy(u.get("主武器已销毁")),
		"武器": J.or_(u.get("weapons"), []).map(func(w): return [w.get("cd"), w.get("uses")]),
		"势力状态": J.or_(u.get("势力状态"), null),
		"牌区": {
			"武器栏": _张数(u.get("武器栏")), "副武器栏": _张数(u.get("副武器栏")),
			"大招槽": _张数(u.get("大招槽")), "待入库": _张数(u.get("待入库")),
			"专属牌库": _张数(u.get("专属牌库")), "专属手牌": _张数(u.get("专属手牌")),
			"专属弃牌堆": _张数(u.get("专属弃牌堆")), "衍生手牌": _张数(u.get("衍生手牌")),
		},
		"专属手牌": _id们(u.get("专属手牌")), "衍生手牌": _id们(u.get("衍生手牌")),
	}

static func _张数(池: Variant) -> int:
	return (池 as Array).size() if 池 is Array else 0

static func _id们(池: Variant) -> Array:
	var 出: Array = []
	for c in (池 if 池 is Array else []):
		if c is Dictionary:
			出.append(str((c as Dictionary).get("id", "")))
		elif c is String:
			出.append(c)
	return 出

static func _计数摘要(计: Variant) -> Dictionary:
	if not (计 is Dictionary):
		return {}
	var 出 := {}
	for k in (计 as Dictionary).keys():
		if 不记的计数键.has(String(k)):
			continue
		出[String(k)] = (计 as Dictionary)[k]
	return 出

## 深拷贝成纯数据（事件 / 摘要里不能留对单位的引用）。
static func 纯数据(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v

## 压缩一串全量摘要：第 0 项留全量，之后只留 `单位数` + `单位变化`（与旧样例同一套写法，省体积）。
static func 压缩(全量们: Array) -> Array:
	var 出: Array = []
	var 上次: Array = []
	for i in 全量们.size():
		var d: Dictionary = (全量们[i] as Dictionary).duplicate(true)
		var 单位: Array = (d.get("单位", []) as Array).duplicate(true)
		d.erase("单位")
		d["单位数"] = 单位.size()
		if i == 0:
			d["单位"] = 单位
		else:
			var 变化: Array = []
			for j in maxi(单位.size(), 上次.size()):
				var 新: Variant = 单位[j] if j < 单位.size() else null
				var 旧: Variant = 上次[j] if j < 上次.size() else null
				if 新 == null or GoldenCompare.diff(旧, 新, "") != "":
					变化.append([j, 新])
			d["单位变化"] = 变化
		上次 = 单位
		出.append(d)
	return 出

## `压缩` 的逆：展开成每回合全量（比对用）。
static func 展开(压缩们: Array) -> Array:
	var 出: Array = []
	var 单位: Array = []
	for i in 压缩们.size():
		var e: Dictionary = (压缩们[i] as Dictionary).duplicate(true)
		if i == 0:
			单位 = (e.get("单位", []) as Array).duplicate(true)
		else:
			while 单位.size() < int(e.get("单位数", 单位.size())):
				单位.append(null)
			for pair in J.or_(e.get("单位变化"), []):
				单位[int(pair[0])] = pair[1]
		e.erase("单位变化")
		e.erase("单位数")
		e["单位"] = 单位.duplicate(true)
		出.append(e)
	return 出

## 逐回合比对（期望**未解码**、`实际` = `run()` 的返回值）。返回 "" 或第一处分叉。
static func compare(sample: Dictionary, 实际: Dictionary) -> String:
	var 期: Dictionary = sample.get("期望", {})
	var 实: Dictionary = 实际.get("期望", {})
	var d := GoldenCompare.compare_events(sample, 实.get("事件", []))
	if d != "":
		return d
	var 期望摘要: Array = GoldenCompare.decode(期.get("回合摘要", []))
	var 实摘要: Array = 实.get("回合摘要", [])
	var 展开后 := 展开(期望摘要)
	for i in mini(展开后.size(), 实摘要.size()):
		var dd := GoldenCompare.diff(展开后[i], 实摘要[i], "回合摘要[%d]" % i)
		if dd != "":
			return "%s · %s" % [str(sample.get("id", "")), dd]
	if 展开后.size() != 实摘要.size():
		return "%s · 回合摘要数不同（期望 %d，实际 %d）" % [str(sample.get("id", "")), 展开后.size(), 实摘要.size()]
	return GoldenCompare.diff(GoldenCompare.decode(期.get("结果", {})), 实.get("结果", {}), "结果")
