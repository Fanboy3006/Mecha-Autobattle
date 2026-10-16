## 战斗屏（Stage M4-3 实装）：双方 8 格阵型 + 底部战术手牌栏 + 战报栏。
##
## 契约（`协作/架构/M4-表现层接口契约.md` §3 / §5）：
##   · `extends Control`，只有 `setup(session)` / `refresh()` 两个入口；`_ready()` 里不读 session；
##   · 节点树 headless 能建起来（`new()` + `setup()`，不 load 只有编辑器里才有的资源）；
##   · 关键节点名固定（`find_child` 靠它）：`战斗屏` / `阵型区` / `手牌栏` / `候补区` / `战报栏`；
##   · 数据只从门面读（`hand_cards()` / `hand_card_status()` / `reserve_preview()` /
##     `turn_card_summary()` / `unit_view()` / `battle_log_entries()` …），动作只调门面命令；
##   · ★ **不发明规则**：手牌能不能打只有一个判据 —— 门面 `hand_card_status()` 的 `可打` / `原因`。
##     这里**不写任何张数上限**（内核与封存 JS 都没有「每回合最多打 N 张」这条规则）。
##
## 站位几何**照 `Fm` 现场生成**（前 4 + 后 4 · 正交 4×2 = 8 格；★ 不是 9 格），
## 与 `run_map/formation_view.gd` 同一套读法（`Fm.ROWS()` / `Fm.行列数(行)` / `Fm.slotOf` / `Fm.位名`）。
##
## 只有三处「越过门面的**纯读**」，用的全是 `core/` 里现成的纯函数，表现层自己一个数都不算：
##   ① 敌方下一拍行动意图预告 —— `Boss.bossAction(u, ctx)`
##      （它正是封存 JS `算意图()` 内层调的那一个纯函数：Boss 走脚本，非 Boss 落到 `Ai.enemyAction`）；
##   ② Boss 阶段预告 —— `Boss.Boss参数` / `Boss.Boss本回合放大技能` / `Boss.Boss下次技能回合`；
##   ③ SEED 觉醒 —— `FacSeed.SEED累计` / `FacSeed.SEED已觉醒`（纯读，不建任何字段；
##      门面 `unit_view()` 没暴露这一项 → 已登记为缺口）。
class_name BattleView
extends Control

signal 请求弹窗(类型: String, 数据: Dictionary)
signal 请求屏幕(屏名: String)
signal 请求关闭弹窗()

const 我方 := "ally"
const 敌方 := "enemy"

var session: GameSession = null

# ---------------- 阵型区 ----------------
var _阵型提示: Label
var _我方列: VBoxContainer
var _敌方列: VBoxContainer
## 位号 → UnitCard（每方 8 张，`_build()` 只建一次，`refresh()` 只换数据）
var _我方卡: Array = []
var _敌方卡: Array = []
## 已经调过 `finish_battle_and_settle()`（避免重画时二次结算）
var _已结算: bool = false

# ---------------- 手牌栏 / 候补区 ----------------
var _手牌栏: PanelContainer
var _手牌标题: Label
var _手牌气势: Label
var _候补区: PanelContainer
var _候补文: Label
var _手牌列表: HBoxContainer
var _操作结果: Label

# ---------------- 战报栏 ----------------
var _战报栏: PanelContainer
var _战报提示: Label
var _战报滚: VBoxContainer
var _推进按钮: Button
var _自动按钮: Button
var _结算按钮: Button

## 上一条命令的反馈（三层反馈里「即时 + 为什么」那一小块）
var _反馈文字: String = ""
var _反馈是好消息: bool = true

func setup(p_session: GameSession) -> void:
	session = p_session
	_build()

func refresh() -> void:
	if _手牌标题 == null:
		return
	if session == null:
		_阵型提示.visible = true
		_我方列.visible = false
		_敌方列.visible = false
		_手牌标题.text = "手牌栏：没有会话。"
		_手牌气势.text = ""
		_候补文.text = "候补区：没有会话。"
		_战报提示.text = "战报栏：没有会话。"
		_操作结果.text = ""
		_清空(_手牌列表)
		_清空(_战报滚)
		return
	var 在战斗 := not session.battle_ctx.is_empty()
	if not 在战斗:
		_已结算 = false
	_阵型提示.visible = not 在战斗
	_我方列.visible = 在战斗
	_敌方列.visible = 在战斗
	_画阵型(在战斗)
	_画手牌(在战斗)
	_画战报(在战斗)
	_操作结果.text = _反馈文字
	_操作结果.add_theme_color_override("font_color", UiTheme.正面 if _反馈是好消息 else UiTheme.负面)

# ==========================================================================================
# 建节点树（只在 setup 里跑一次）
# ==========================================================================================

func _build() -> void:
	name = "战斗屏"
	UiTheme.占满(self)
	var 列 := UiTheme.建盒(self, "战斗屏上下列", true, UiTheme.间距_小)
	_建阵型区(列)
	_建手牌栏(列)
	_建战报栏(列)
	_反馈文字 = "点手牌发动战术牌；点「推进下一回合」让内核打一个完整回合。"

func _建阵型区(父: Node) -> void:
	var 区 := UiTheme.建盒(父, "阵型区", false, UiTheme.间距)
	区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_阵型提示 = UiTheme.建说明(区, "现在不在战斗里 —— 从主菜单点「快速测试战斗」，或者在大地图的作战格上点「开战」。",
		UiTheme.字号_小, UiTheme.弱文字)
	_阵型提示.name = "阵型提示"
	_我方列 = _建一方(区, "我方阵型", "我方阵型（前 4 + 后 4，正交 4×2 = 8 格）", 我方)
	_敌方列 = _建一方(区, "敌方阵型", "敌方阵型（前 4 + 后 4，正交 4×2 = 8 格）", 敌方)

## 一方阵型：行数 / 每行列数全部读 `Fm`（8 格 = 前 4 + 后 4）。
func _建一方(父: Node, 名: String, 标题: String, 方: String) -> VBoxContainer:
	var 列 := UiTheme.建盒(父, 名, true, UiTheme.间距_小)
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.建标签(列, 标题, UiTheme.字号_小节, UiTheme.高亮)
	var 卡们: Array = _我方卡 if 方 == 我方 else _敌方卡
	for 行 in int(Fm.ROWS()):
		var 行盒 := UiTheme.建盒(列, "%s第%d排" % [名, 行], false, UiTheme.间距_小)
		UiTheme.建标签(行盒, Fm.行名(float(行)), UiTheme.字号_小, UiTheme.次要文字)
		for 列号 in int(Fm.行列数(float(行))):
			var 卡 := UnitCard.new()
			行盒.add_child(卡)
			卡.setup({"ok": false, "为什么": "现在不在战斗里"})
			卡.custom_minimum_size = Vector2(UiTheme.格边长 * 2.0, 0)
			卡.开关切换.connect(_点开关)
			卡.开状态.connect(_点开状态)
			卡们.append(卡)
	return 列

func _建手牌栏(父: Node) -> void:
	_手牌栏 = UiTheme.建面板(父, "手牌栏", UiTheme.面板底, UiTheme.边框_亮)
	var 列 := UiTheme.建盒(_手牌栏, "手牌栏上下列", true, UiTheme.间距_小)
	_手牌标题 = UiTheme.建标签(列, "手牌栏", UiTheme.字号_小节, UiTheme.高亮)
	_手牌标题.name = "手牌标题"
	_手牌气势 = UiTheme.建标签(列, "", UiTheme.字号_小, UiTheme.希望色)
	_手牌气势.name = "手牌气势"
	# ★ D-01 重点展示区：候补初始牌（角色牌开局在手、职业牌排队进候补 —— 作者要在这里一眼看到）
	_候补区 = UiTheme.建面板(列, "候补区", UiTheme.卡片底, UiTheme.边框_亮)
	var 候补列 := UiTheme.建盒(_候补区, "候补区上下列", true, UiTheme.间距_小)
	UiTheme.建标签(候补列, "候补初始牌（开局超出「初始手牌上限」的那一批，每回合开始有空位就按序补进手牌）",
		UiTheme.字号_小, UiTheme.高亮)
	_候补文 = UiTheme.建说明(候补列, "候补区：还没开战。", UiTheme.字号_小, UiTheme.主文字)
	_候补文.name = "候补文"
	_手牌列表 = _建滚动盒(列, "手牌滚动", "手牌列表")
	_操作结果 = UiTheme.建说明(列, "", UiTheme.字号_小, UiTheme.正面)
	_操作结果.name = "操作结果"

func _建战报栏(父: Node) -> void:
	_战报栏 = UiTheme.建面板(父, "战报栏", UiTheme.面板底, UiTheme.边框)
	var 列 := UiTheme.建盒(_战报栏, "战报栏上下列", true, UiTheme.间距_小)
	var 按钮行 := UiTheme.建盒(列, "战斗按钮组", false, UiTheme.间距)
	_推进按钮 = UiTheme.建按钮(按钮行, "推进下一回合", _点推进)
	_推进按钮.name = "推进按钮"
	_推进按钮.tooltip_text = "让内核真的打一个完整回合（门面 step_battle_turn()）"
	_自动按钮 = UiTheme.建按钮(按钮行, "自动打完本场", _点自动)
	_自动按钮.name = "自动按钮"
	_自动按钮.tooltip_text = "一路推进到出结果（门面 auto_finish_battle()）"
	_结算按钮 = UiTheme.建按钮(按钮行, "结束并结算", _点结算)
	_结算按钮.name = "结算按钮"
	_结算按钮.tooltip_text = "战后结算（门面 finish_battle_and_settle()），然后由壳路由到结算屏"
	_战报提示 = UiTheme.建标签(列, "战报栏", UiTheme.字号_小, UiTheme.次要文字)
	_战报提示.name = "战报提示"
	_战报滚 = UiTheme.建滚动(列, "战报滚动", 150.0)

# ==========================================================================================
# 阵型（读 Fm 的 8 格几何 + 门面 unit_view）
# ==========================================================================================

func _画阵型(在战斗: bool) -> void:
	if not 在战斗:
		_填一方(_我方卡, 我方, {}, false)
		_填一方(_敌方卡, 敌方, {}, false)
		return
	_填一方(_我方卡, 我方, _位号到键(我方), true)
	_填一方(_敌方卡, 敌方, _位号到键(敌方), true)

func _填一方(卡们: Array, 方: String, 占位: Dictionary, 在战斗: bool) -> void:
	for 位号 in 卡们.size():
		var 卡: UnitCard = 卡们[位号]
		if not 在战斗:
			卡.数据 = {"ok": false, "为什么": "现在不在战斗里"}
			卡.refresh()
			continue
		var 键 := str(占位.get(位号, ""))
		if 键.is_empty():
			卡.数据 = {"ok": false, "为什么": "%s 空着（这一格没有机体）" % Fm.位名(float(位号))}
			卡.refresh()
			continue
		var d := session.unit_view(方, 键)
		d["开关提示"] = _开关提示(d)
		if 方 == 敌方:
			d["意图"] = _敌意(位号)
		if str(d.get("势力", "")) == "卫星国防军":
			var 醒 := _SEED行(位号)
			if not 醒.is_empty():
				d["觉醒"] = 醒
		卡.数据 = d
		卡.refresh()

## `位号 → 机体键`：直接读 `battle_ctx` 的 `allies` / `enemies`（纯读，一个数都不算）。
func _位号到键(方: String) -> Dictionary:
	var out := {}
	if session == null or session.battle_ctx.is_empty():
		return out
	var 池: Variant = session.battle_ctx.get("allies") if 方 == 我方 else session.battle_ctx.get("enemies")
	if not (池 is Array):
		return out
	for x in (池 as Array):
		if x is Dictionary:
			out[int(float((x as Dictionary).get("slot", -1.0)))] = str((x as Dictionary).get("key", ""))
	return out

func _单位字典(方: String, 位号: int) -> Dictionary:
	if session == null or session.battle_ctx.is_empty():
		return {}
	var 池: Variant = session.battle_ctx.get("allies") if 方 == 我方 else session.battle_ctx.get("enemies")
	if not (池 is Array):
		return {}
	for x in (池 as Array):
		if x is Dictionary and int(float((x as Dictionary).get("slot", -1.0))) == 位号:
			return x
	return {}

## 开关按钮的文字**直接用门面 `unit_view()` 给的 `开关` 行**（就是把事实原样贴到按钮上），
## 一个可点性门槛都不加 —— 开不出来时由内核给 `why`，这里只把它显示出来。
func _开关提示(d: Dictionary) -> Dictionary:
	var 行: Array = d.get("开关") if d.get("开关") is Array else []
	var out := {}
	out["保留大招"] = {
		"文字": str(行[0]) if 行.size() > 0 else "保留大招", "可点": true,
		"为什么": "点它 = 让门面把这一键翻转（内核那边是整表替换）；点不动会把原因写在下面",
	}
	if str(d.get("势力", "")) == "天人":
		out["TRANSAM"] = {
			"文字": str(行[1]) if 行.size() > 1 else "TRANSAM", "可点": true,
			"为什么": "点它 = 在「自动 / 手动」之间切换",
		}
		out["开状态"] = {
			"文字": "开 TRANS-AM", "可点": true,
			"为什么": "没解锁 / 冷却中 / 已经开着 → 这一下开不出来，原因会写在手牌栏下面",
		}
	return out

## 敌方下一拍行动意图预告：`Boss.bossAction()` 是内核现成的纯函数（JS `算意图()` 内层就是它）。
func _敌意(位号: int) -> Array:
	var 条: Array = []
	if session == null or session.battle_ctx.is_empty():
		return 条
	var u := _单位字典(敌方, 位号)
	if u.is_empty():
		return 条
	var ctx: Dictionary = session.battle_ctx
	var 动作: Variant = Boss.bossAction(u, ctx)
	if not (动作 is Dictionary):
		条.append("下一拍：这一拍打不到人")
	else:
		var a: Dictionary = 动作
		var w: Variant = a.get("weapon")
		var 目标: Variant = a.get("target")
		var 段 := "下一拍："
		if w is Dictionary:
			段 += "【%s】" % str((w as Dictionary).get("name", ""))
		else:
			段 += "普通攻击"
		if 目标 is Dictionary:
			段 += " → %s（%s）" % [str((目标 as Dictionary).get("name", "")),
				Fm.位名(float((目标 as Dictionary).get("slot", 0.0)))]
		var 期望 := float(a.get("expected", 0.0))
		if 期望 > 0.0:
			段 += " · 期望 %d" % int(JsCompat.js_round(期望))
		if bool(a.get("被挡", false)):
			段 += " · 被挡 -20"
		if w is Dictionary and Ai.isUltimate(w):
			段 += " · 大招"
		if bool(a.get("大技能", false)):
			段 += " · Boss 大技能"
		条.append(段)
		var 落点: Array = a.get("hit") if a.get("hit") is Array else []
		if not 落点.is_empty():
			var 名们: Array = []
			for t in 落点:
				if t is Dictionary:
					名们.append(Fm.位名(float((t as Dictionary).get("slot", 0.0))))
			条.append("落点：" + "、".join(名们))
	# Boss 阶段预告（`Boss.Boss参数` 对非 Boss 返回 null）
	var 参: Variant = Boss.Boss参数(u)
	if 参 is Dictionary:
		var p: Dictionary = 参
		var 文 := "Boss 第 %d 阶段 · 伤害倍率 ×%s" % [int(float(p.get("第几阶段", 1.0))),
			UiTheme.文本(p.get("伤害倍率", 1.0))]
		var 间隔 := float(p.get("大技能间隔", 0.0))
		var 武器: Variant = p.get("大技能武器")
		if 间隔 > 0.0 and 武器 != null:
			if Boss.Boss本回合放大技能(u, ctx):
				文 += " · 这一拍放【%s】" % str(武器)
			else:
				var 下: Variant = Boss.Boss下次技能回合(u, ctx)
				if 下 != null:
					文 += " · 第 %s 回合放【%s】" % [UiTheme.文本(int(float(下))), str(武器)]
				else:
					文 += " · 蓄力中"
		条.append(文)
	return 条

## SEED 觉醒（门面 `unit_view()` 没给这一项 —— 缺口已登记；这里用内核现成的纯读函数）。
func _SEED行(位号: int) -> String:
	var u := _单位字典(我方, 位号)
	if u.is_empty():
		return ""
	if FacSeed.SEED已觉醒(u):
		return "SEED 已觉醒 · 觉醒值 %s" % UiTheme.文本(int(JsCompat.js_round(Fac.势力觉醒值(u))))
	var 累 := FacSeed.SEED累计(u)
	if 累 > 0.0:
		return "SEED 累计 %s" % UiTheme.文本(int(JsCompat.js_round(累)))
	return ""

# ==========================================================================================
# 手牌栏 / 候补区
# ==========================================================================================

func _画手牌(在战斗: bool) -> void:
	_清空(_手牌列表)
	if not 在战斗:
		_手牌标题.text = "手牌栏：现在不在战斗里。"
		_手牌气势.text = ""
		_候补文.text = "候补区：还没开战，没有候补初始牌。"
		return
	var 小结 := session.turn_card_summary()
	_手牌标题.text = "手牌 %d / %d 张（初始手牌上限 %d）· 牌库剩余 %d 张 · 本回合已打出 %d 张（事实报告，内核没有张数上限）· 现在能打 %d 张 · 第 %d 回合" % [
		int(小结.get("手牌", 0)), _手牌总上限(), _初始手牌上限(), int(小结.get("牌库剩余", 0)),
		int(小结.get("本回合已打出", 0)), int(小结.get("现在能打", 0)), int(小结.get("回合", 0))]
	_手牌气势.text = "我方气势 %d / %d" % [int(JsCompat.js_round(float(小结.get("气势", 0.0)))),
		int(JsCompat.js_round(Btl.气势上限()))]
	_画候补()
	for c in session.hand_cards():
		if c is Dictionary:
			_建手牌卡(c)
	if _手牌列表.get_child_count() == 0:
		UiTheme.建标签(_手牌列表, "手牌是空的 —— 推进一回合，候补初始牌会按序补进来。", UiTheme.字号_小, UiTheme.弱文字)

## ★ D-01 的地方：候补初始牌的数量 + 列表（带层级），让作者一眼看出「谁开局在手、谁在排队」。
func _画候补() -> void:
	var 候 := session.reserve_preview()
	if 候.is_empty():
		_候补文.text = "候补初始牌：0 张 —— 初始牌全部进了手牌（没有超出「初始手牌上限」的）。"
		return
	var 名们: Array = []
	for c in 候:
		if c is Dictionary:
			名们.append("【%s】%s" % [str((c as Dictionary).get("名", "")), str((c as Dictionary).get("层级", ""))])
	_候补文.text = "候补初始牌：%d 张（%s）\n%s" % [候.size(),
		"开局超出初始手牌上限的初始牌，每回合开始手牌有空位就按序补进来", "、".join(名们)]

func _建手牌卡(c: Dictionary) -> void:
	var id := str(c.get("id", ""))
	var 状 := session.hand_card_status(id)
	var 可打 := bool(状.get("可打", false))
	var 原因 := str(状.get("原因", ""))
	var 卡 := PanelContainer.new()
	卡.name = "手牌卡%d" % (_手牌列表.get_child_count() + 1)
	卡.custom_minimum_size = Vector2(UiTheme.格边长 * 2.4, 0)
	卡.add_theme_stylebox_override("panel", UiTheme.底样式(
		UiTheme.卡片底_亮 if 可打 else UiTheme.卡片底,
		UiTheme.高亮 if 可打 else UiTheme.边框))
	_手牌列表.add_child(卡)
	var 列 := UiTheme.建盒(卡, "手牌内容", true, UiTheme.间距_小)
	var 按 := UiTheme.建按钮(列, str(c.get("名", "")), _点手牌.bind(id))
	按.name = "手牌按钮"
	按.disabled = not 可打
	按.tooltip_text = str(c.get("效果说明", ""))
	按.add_theme_color_override("font_color", UiTheme.高亮 if 可打 else UiTheme.禁用文字)
	按.add_theme_color_override("font_disabled_color", UiTheme.禁用文字)
	var 层级 := UiTheme.建标签(列, "%s · 耗气 %s · 回气 %s · 冷却 %s 回合 · 剩余 %s 次" % [
		_层级文字(c), UiTheme.文本(int(JsCompat.js_round(float(状.get("耗气", 0.0))))),
		UiTheme.文本(int(JsCompat.js_round(float(状.get("回气", 0.0))))),
		UiTheme.文本(状.get("冷却", 0)), UiTheme.文本(状.get("剩余", 0))],
		UiTheme.字号_小, UiTheme.次要文字)
	层级.name = "手牌层级"
	# ★ 置灰的原因 = 门面 hand_card_status()["原因"] 的**原文**，一个字都不改
	var 原因行 := UiTheme.建说明(列, "【%s】%s" % [原因, str(c.get("效果说明", ""))],
		UiTheme.字号_小, UiTheme.高亮 if 可打 else UiTheme.禁用文字)
	原因行.name = "手牌原因"
	var 层 := str(c.get("层级", ""))
	if not 可打:
		卡.modulate = Color(1.0, 1.0, 1.0, 0.72)

func _层级文字(c: Dictionary) -> String:
	var 层 := str(c.get("层级", ""))
	var 归 := str(c.get("归属", ""))
	if 归.is_empty():
		return 层 if not 层.is_empty() else "基础"
	return "%s·%s" % [层, 归]

## 手牌总上限 / 初始手牌上限：纯读数据目录（不写死数字）
func _手牌总上限() -> int:
	var v: Variant = _卡牌参数().get("手牌总上限")
	return int(float(v)) if v != null else 10
func _初始手牌上限() -> int:
	var v: Variant = _卡牌参数().get("初始手牌上限")
	return int(float(v)) if v != null else 6
func _卡牌参数() -> Dictionary:
	var b := Db.catalog.battle_config()
	var t: Variant = b.get("战术卡牌")
	return t if t is Dictionary else {}

# ==========================================================================================
# 战报栏（即时那一层）
# ==========================================================================================

func _画战报(在战斗: bool) -> void:
	_清空(_战报滚)
	if not 在战斗:
		_战报提示.text = "战报栏：现在不在战斗里。"
		_推进按钮.disabled = true
		_自动按钮.disabled = true
		_结算按钮.disabled = true
		return
	var 打完 := session.battle_ctx.get("result") != null
	var 小结 := session.turn_card_summary()
	_战报提示.text = "第 %d 回合 · 本回合已打出 %d 张 · 现在能打 %d 张 · 手牌 %d · 候补 %d · 本场已打出 %d 张%s" % [
		int(小结.get("回合", 0)), int(小结.get("本回合已打出", 0)), int(小结.get("现在能打", 0)),
		int(小结.get("手牌", 0)), int(小结.get("候补", 0)), int(小结.get("本场已打出", 0)),
		"  · 这一场已经打完了，点「结束并结算」" if 打完 else ""]
	_推进按钮.disabled = 打完
	_自动按钮.disabled = 打完
	_结算按钮.disabled = not 打完
	# 结构化日志（要按「类型」高亮）；文本用门面给的那一份，不自己拼
	var 条们 := session.battle_log_entries(60)
	var 行们 := session.battle_log_lines(60)
	if 条们.is_empty():
		UiTheme.建标签(_战报滚, "还没有战报 —— 点「推进下一回合」开打。", UiTheme.字号_小, UiTheme.弱文字)
		return
	for i in 条们.size():
		var e: Dictionary = 条们[i] if 条们[i] is Dictionary else {}
		var 文 := str(行们[i]) if i < 行们.size() else str(e.get("文本", ""))
		var 色 := _日志色(e)
		var l := UiTheme.建说明(_战报滚, 文, UiTheme.字号_正文 if _是高亮(e) else UiTheme.字号_小, 色)
		l.name = "战报行%d" % (i + 1)

## 高亮判据全部来自日志条目自己的字段（只读字段，不编）：
## `类型` = 战术牌 / 势力 / Boss / 发牌（`触发条件码 == "候补补位"` 就是补位）。
func _日志色(e: Dictionary) -> Color:
	var 类 := str(e.get("类型", ""))
	var 文 := str(e.get("文本", ""))
	if 类 == "战术牌":
		return UiTheme.高亮
	if 类 == "势力":
		return UiTheme.希望色
	if 类 == "Boss":
		return UiTheme.负面
	if 类 == "发牌":
		if str(e.get("触发条件码", "")) == "候补补位" or 文.contains("候补"):
			return UiTheme.推进剂色
		return UiTheme.次要文字
	if 类 == "回合" or 类 == "开始" or 类 == "结束":
		return UiTheme.主文字
	return UiTheme.次要文字

func _是高亮(e: Dictionary) -> bool:
	var 类 := str(e.get("类型", ""))
	return 类 == "战术牌" or 类 == "势力" or 类 == "Boss" or 类 == "回合"

# ==========================================================================================
# 动作（一律调门面命令；失败就把 why 显示出来）
# ==========================================================================================

func _点手牌(id: String) -> void:
	if session == null:
		return
	var r := session.play_tactical_card(id)
	if bool(r.get("成功", false)):
		_回话("打出【%s】：%s（本回合已打出 %d 张）" % [str(session.last.get("牌名", id)),
			str(session.last.get("效果摘要", "")), session.cards_played_this_turn()], true)
	else:
		_回话("打不出来：%s" % _为什么(r), false)
	refresh()

func _点开关(单位键: String, 开关键: String) -> void:
	if session == null:
		return
	if session.toggle_unit_switch(单位键, 开关键):
		_回话("已切【%s】的「%s」→ %s" % [单位键, 开关键, str(session.last.get("值", ""))], true)
	else:
		_回话("开关点不动：%s" % _为什么(session.last), false)
	refresh()

func _点开状态(单位键: String) -> void:
	if session == null:
		return
	if session.activate_unit_state(单位键):
		_回话("%s 的 TRANS-AM 开了（第 %s 回合起）" % [单位键, UiTheme.文本(session.last.get("启动回合", 0.0))], true)
	else:
		_回话("开不出来：%s" % _为什么(session.last), false)
	refresh()

func _点推进() -> void:
	if session == null:
		return
	if session.battle_ctx.get("result") != null:
		_点结算()
		return
	var 前 := int(float(session.battle_ctx.get("turn", 1.0)))
	var r := session.step_battle_turn()
	if not bool(r.get("ok", true)):
		_回话("推不动：%s" % _为什么(r), false)
		refresh()
		return
	var 后 := int(float(session.battle_ctx.get("turn", 1.0)))
	_回话("第 %d 回合打完了（现在第 %d 回合）· 本回合已打出 %d 张 · 现在能打 %d 张" % [前, 后,
		session.cards_played_this_turn(), session.cards_playable_now()], true)
	if session.battle_ctx.get("result") != null:
		_点结算()
		return
	refresh()

func _点自动() -> void:
	if session == null:
		return
	if session.battle_ctx.get("result") != null:
		_点结算()
		return
	session.auto_finish_battle()
	_回话("打完了：%s · 一共打了 %s 个回合" % [session.战果文字(), UiTheme.文本(session.last.get("回合数", 0))], true)
	_点结算()

func _点结算() -> void:
	if session == null:
		return
	if session.battle_ctx.get("result") == null:
		_回话("这一场还没打完（先推进或自动打完）", false)
		refresh()
		return
	if _已结算:
		refresh()
		return
	session.finish_battle_and_settle()
	_已结算 = true
	_回话("战后已结算：%s（屏幕已经切到结算屏）" % str(session.result_summary().get("结果", "")), true)
	refresh()

func _回话(文: String, 好消息: bool) -> void:
	_反馈文字 = 文
	_反馈是好消息 = 好消息

func _为什么(r: Dictionary) -> String:
	var w := str(r.get("为什么", ""))
	if not w.is_empty():
		return w
	if not session.errors.is_empty():
		return str(session.errors[session.errors.size() - 1])
	return "门面没有给出原因"

# ==========================================================================================
# 小工具
# ==========================================================================================

## 往 `父` 上挂一个左右滚动的 `ScrollContainer` + 里面的 `HBoxContainer`，返回那个盒。
func _建滚动盒(父: Node, 滚动名: String, 盒名: String) -> HBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = 滚动名
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, UiTheme.格边长 * 2.6)
	父.add_child(sc)
	var 盒 := UiTheme.建盒(sc, 盒名, false, UiTheme.间距_小)
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return 盒

func _清空(节点: Node) -> void:
	if 节点 == null:
		return
	for c in 节点.get_children():
		节点.remove_child(c)
		c.queue_free()
