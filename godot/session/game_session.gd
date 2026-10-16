## 会话门面（Stage M4-1）—— 玩家命令的唯一入口，表现为**零 `J.*`**、**零引擎依赖**的纯逻辑对象。
##
## 定位（交接卡 §3.1）：表现层（`godot/presentation/`）**不直接拼内核调用链**，
## 只做两件事：① 把 `screen` / `run_state` / `battle_ctx` / `modal` / `topbar_state()` … 画成
## Godot `Control`；② 把按钮点击转发成本文件里的一个命令方法。因此本文件可以在
## **`--headless` 下把整条 UI 动作流 100% 自动化测通**（见 `tests/unit/test_session_flow.gd`）。
##
## 严格遵守的纪律：
##   · 零 `J.*`（`test_boundary.gd` 扫 `res://session`）；四舍五入用 `JsCompat.js_round`，
##     稳定排序用 `JsCompat.stable_sort`，确定性随机只用 `Mulberry32`；
##   · **唯一存档 IO 出口 = `SaveService`**（本文件不出现 `FileAccess` / `DirAccess`）；
##   · 任意 Variant 转字符串一律 `str(x)`（`String(int)` 在 GDScript 4 会报构造器错误）；
##   · 从不直接改内核语义：所有规则都调 `core/` 的真实函数，本文件只做「命令 → 内核 → 快照」。
##
## ★ 与交接卡 §3.2 的真实内核偏差（照真实内核实现，已登记）：
##   1. `Btl.切换单位开关` / `Btl.激活单位状态` **在源码里不存在**。真实只有
##      `Btl.设单位开关(ctx, 开关表)`，开关表是 **以「位号」为键**的字典（`J.at(开关表, u.slot)`），
##      开关键是 `"保留大招"`（bool）/ `"TRANSAM"`（字符串 `"手动"`）/ `"本回合开TRANSAM"`（bool）。
##      开战那一刻表由 `Setup.开局(我方, 敌方, 种子, 开关表, 选项)` 的第 4 个参数传进去。
##      所以本门面自己持有 `_unit_switches`（位号 → 开关键值），
##      `toggle_unit_switch` = 改表 + 立刻对 ctx 里那一台再调一次 `Btl.设单位开关`；
##      `activate_unit_state` = 置 `本回合开TRANSAM` + 调真实引擎钩子 `FacCb.手动开天人`。
##   2. 起始是**8 格**（前排 前1..前4 + 后排 后1..后4，`Fm.SLOTS() = 8`），不是 9 格；
##      `lineup_slots()` 照 `Fm.位名()` 现场生成，格数跟着数据走。
##   3. ★ **纠错记录（D-03）**：交接卡 §3.2 那句「本回合剩余可打牌次数（`2 − 本回合已打出`）」
##      是**过期口径**，已作废。封存 JS 与内核**都没有张数门槛**：
##        · `src/js/80-界面-3-战斗屏与方针栏.js:94`：`够气 = 当前气 >= 耗 && 冷却 <= 0 && 剩 > 0`，
##          `可打 = 可点 && 够气` —— 判据只有这三种，**没有任何张数判据**；
##        · `src/js/60-战斗-1-方针与记录.js:1171`：`ctx.已打出战术牌.push(card.id)` 只是**记录**；
##        · `71-改动-4-战斗结构.js` 的 `战术卡牌` 只有 `初始手牌上限 6` / `手牌总上限 10`，
##          没有「每回合出牌数」这一项。
##      所以本门面**不设**张数门槛：`play_tactical_card()` 是纯委托（成败完全由内核与手牌事实决定），
##      只另外提供两个**说真话的读**给 UI 置灰 —— `cards_playable_now()` 与 `hand_card_status()`
##      （判据与 JS `:94` 同一套，原因文案照 JS `:100`：`冷却 N 回合` / `需 N 气势` / `点击发动`）。
##      曾一度加过的 `本回合打牌上限 = 2` 已**整体删除**（全文件不再出现任何 `2` 张预算）。
##   4. ★ **纠错记录（D-06）**：门面曾**自造「三选一」**——在 `start_new_run()` / `move_to_cell()` /
##      `use_part()` / `resolve_event_choice()` 四处都调了 `refresh_card_offers()`，而它当时会
##      `DeckBuilder.offer_cards()` **写** `pending_card_picks`。**封存 JS 里 `R.待选战术牌` 只有两处赋值**：
##      `src/js/90-肉鸽-5-晋升与通关.js:62`（招募）与 `:151`（晋升）；开局 / 移动 / 用零件 / 事件
##      **一处都不产生待选牌**。后果很实：每走一格弹一次 3 选 1、`try_advance_floor()` 被幻影待选牌
##      永久拦住（「走上去自动换层」走不通）、开局还会指向一个不在名册里的键。
##      现已修：那 4 处调用**全部删除**；`refresh_card_offers(unit_key)` 改成**纯读口子**
##      （只返回「这台机体此刻的 3 张候选」，不写 `pending_card_picks`、不 `_refresh_modal()`、不 `_emit()`）。
##      `_refresh_modal()` 保留原有口径（`pending_card_picks` 非空就弹三选一），
##      于是它**只在招募 / 晋升之后**才会触发。
##   5. ★ **纠错记录（D-07）**：`finish_battle_and_settle()` 曾**不幂等** —— 准入只看「有没有 ctx」与
##      「有没有打完」，而结算完成后这两条依然成立，于是同一个 `battle_ctx` 可以**原地无限重结算**
##      （每调一次再跑一遍 `NodeResolver.resolve_battle`：再发源碳 / 希望 / 藏品 / 经验，`场次`/`胜场` 再 +1。
##      端到端驱动器实测「第 1 层原地连结算 496 次、胜场 +496、源碳 +1984」）。
##      M4-3 只在**视图**里加了守卫，但门面是「玩家命令的唯一入口」，这道闸必须由门面守。
##      现已修：新增 `_本场已结算` 标志 —— 结算成功后置 true；重复调用**只回 `{"ok": false, "为什么": …}`**，
##      不跑内核、不重算 `_result_cache`、不覆盖 `last`、不 `_emit`；每一处「开一场新战斗」
##      （`start_quick_battle` / `start_node_battle`）与每一处会话重置（`start_new_run` / `load_saved_run` /
##      `return_to_menu`）都把它复位。**守的是标志，不是清 `battle_ctx`**（结算屏还要用 ctx 画）。
##   6. 「源碳」在 `RunState` 里叫 `carbon`、to_dict() 里叫 `"源碳"`；本门面统一用 `run_state.carbon`。
class_name GameSession
extends RefCounted

## 单向数据流：命令改完状态 → 发一次 `changed` → UI 重画。
signal changed()
signal errored(msg: String)

const 存档文件名 := "user://save.json"
const 快速战斗种子偏移 := 8801
const 默认分队 := "混编"

## ---------------- 会话状态（UI 只读这些） ----------------
var run_state: RunState = null
var battle_ctx: Dictionary = {}
var screen: String = "menu"
var modal: Dictionary = {}
var last: Dictionary = {}
var errors: Array = []

## ---------------- 内部态 ----------------
var 存档路径: String = 存档文件名
var _unit_switches: Dictionary = {}
var _node_result: Dictionary = {}
var _result_cache: Dictionary = {}
## ★ P0「回血前后对照」的战前名册血比快照（`key -> hpRatio`）。
##   **权威抓取点 = `finish_battle_and_settle()` 里「调 `NodeResolver.resolve_battle` 之前那一行」**
##   （那时已经打完了、还没回血）；`start_quick_battle()` / `start_node_battle()` 只在开战时抓一份兜底。
##   ★ 必须是**无条件重抓**（不能写 `if is_empty()`）：开战时那份是满血值，复用它会让「前」=「后」。
var _血比战前: Dictionary = {}
var _battle_options_cache: Dictionary = {}
var _quick_battle: bool = false
## ★ D-07 幂等闸：这一场是否**已经结算过**。`finish_battle_and_settle()` 靠它保证「同一场只结算一次」，
##   否则同一个 `battle_ctx` 可以原地无限重结算（每调一次再发一遍源碳 / 希望 / 藏品 / 经验，
##   `场次`/`胜场` 再 +1）。**每一处「开一场新战斗」都要把它复位**。
##   守的是标志、**不是清 `battle_ctx`** —— 结算屏还要用 ctx 画。
var _本场已结算: bool = false

# ==========================================================================================
# 一、开局与存档
# ==========================================================================================

## 开一局新肉鸽：`RosterManager.new_run` → 屏幕进 `"map"`。
func start_new_run(seed_val: int, squad: String = 默认分队) -> bool:
	_data_ready()
	var s := RosterManager.new_run(seed_val, squad if not squad.is_empty() else 默认分队)
	if s == null:
		_fail("开局失败：内核没有给出 RunState", {"ok": false})
		return false
	run_state = s
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_battle_options_cache = _build_battle_options()
	# ★ D-06 纠错：**开局不产生待选战术牌**。封存 JS 里 `R.待选战术牌` 只在
	#   招募（`90-肉鸽-5-晋升与通关.js:62`）与晋升（同文件 `:151`）两处被赋值；
	#   开局 / 移动 / 用零件 / 事件结算一处都不产生（那里曾错调 `refresh_card_offers()`）。
	last = {"行动": "开新局", "种子": seed_val, "分队": run_state.squad,
		"层": run_state.floor_num, "起源碳": run_state.carbon, "起希望": run_state.hope,
		"券": run_state.tickets.size(), "日志": _tail_logs(3)}
	_set_screen("map")
	return true

## 存当前这一局（只走 `SaveService`）。没有局 → false。
func save_current_run() -> bool:
	if run_state == null:
		_fail("没有进行中的局，存不了", {"ok": false})
		return false
	var ok := SaveService.save_to_file(run_state, 存档路径)
	last = {"行动": "存档", "成功": ok, "路径": 存档路径, "层": run_state.floor_num}
	if not ok:
		_fail("存档写不进去（%s）" % 存档路径, last)
	_emit()
	return ok

## 读存档并接管这一局。读不到 / 坏档 → false（且**不动**当前状态）。
func load_saved_run() -> bool:
	var s := SaveService.load_from_file(存档路径)
	if s == null:
		_fail("没有可读的存档（%s）" % 存档路径, {"ok": false})
		return false
	run_state = s
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_battle_options_cache = _build_battle_options()
	last = {"行动": "读档", "路径": 存档路径, "层": run_state.floor_num,
		"源碳": run_state.carbon, "希望": run_state.hope, "名册": run_state.roster.size(),
		"日志": _tail_logs(3)}
	_set_screen("map")
	return true

func has_saved_run() -> bool:
	return SaveService.load_from_file(存档路径) != null

## 可选分队列表（数据侧没导出 `分队表` 时给空数组，UI 自己兜底「混编」）。
func available_squads() -> Array:
	_data_ready()
	var out: Array = []
	var 表 := Db.catalog.squads()
	if 表.is_empty():
		return out
	for e in 表:
		if e is Dictionary:
			var 名 := str(e.get("名", e.get("id", "")))
			if not 名.is_empty():
				out.append(名)
		elif e is String:
			out.append(str(e))
	return out

## 回主菜单：把这一局留在存档里（有局才存），会话清空。
func return_to_menu() -> void:
	if run_state != null and run_state.status == "进行中":
		SaveService.save_to_file(run_state, 存档路径)
	run_state = null
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_node_result = {}
	_unit_switches = {}
	_battle_options_cache = {}
	_quick_battle = false
	modal = {}
	_set_screen("menu")

# ==========================================================================================
# 二、大地图与零件
# ==========================================================================================

## 纯读预告（三层反馈的「预告」那一层）：这一格走过去要几点推进剂、退路成本多少、能不能去。
func preview_cell_move(cell_id: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有大地图", {"ok": false, "格": cell_id})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false, "格": cell_id})
	var can := MapNavigator.can_move_to(s, cell_id)
	var 退 := MapNavigator.retreat_cost_preview(s, cell_id)
	var 格 := s.cell_at(cell_id)
	return {
		"ok": bool(can.get("ok", false)), "格": cell_id,
		"推进剂消耗": int(can.get("cost", 0)), "推进剂": s.propellant, "推进剂上限": s.propellant_max,
		"隧道": bool(can.get("隧道", false)), "路径": can.get("path", []),
		"退路成本": int(退.get("退路成本", -1)), "是干路": bool(退.get("是干路", false)),
		"是割点": bool(退.get("是割点", false)), "度数": int(退.get("度数", 0)),
		"类型": str(格.get("类型", "")), "列": int(格.get("列", 0)), "行": int(格.get("行", 0)),
		"已过": bool(格.get("已过", false)), "为什么": str(can.get("为什么", "")),
	}

## 真的走一格（内核 `MapNavigator.move_to`）。成功 → 屏幕留在 `"map"`，`last` 带这一步的即时数据。
func move_to_cell(cell_id: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有大地图", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	var 前 := {"推进剂": s.propellant, "格": s.node_id}
	var r := MapNavigator.move_to(s, cell_id)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("为什么", "走不过去")), {"ok": false, "格": cell_id})
	# ★ 落脚之后把「当前节点类型」同步成**脚下这一格**的真实类型：`_进层()` 只写过起点那一格，
	#   不同步的话 `enter_current_node()` 会拿着上一格（或起点）的类型去派发节点结算。
	var 脚 := s.cell_at(s.node_id)
	var 脚类型 := str(脚.get("类型", ""))
	if 脚类型.is_empty():
		脚类型 = "空"
	s.map_data["当前节点类型"] = 脚类型
	_battle_options_cache = _build_battle_options()
	last = {
		"行动": "移动", "从": 前["格"], "到": s.node_id, "类型": 脚类型,
		"距离": int(r.get("距离", 0)), "推进剂前": 前["推进剂"], "推进剂后": s.propellant,
		"追击": bool(r.get("追击", false)), "提示": str(r.get("提示", "")),
		"日志": _tail_logs(3),
	}
	_set_screen("map")
	return r

## 用一件零件（不花推进剂）。`part_idx` = `run_state.parts` 的下标。
func use_part(part_idx: int, target_cell: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if part_idx < 0 or part_idx >= s.parts.size():
		return _fail("没有这件零件（下标 %d，手上有 %d 件）" % [part_idx, s.parts.size()], {"ok": false})
	var r := PartSystem.use_part(s, part_idx, target_cell)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("为什么", "用不了")), {"ok": false})
	_battle_options_cache = _build_battle_options()
	last = {"行动": "用零件", "零件": str(r.get("零件", "")), "到": int(r.get("到", s.node_id)),
		"额外": r.get("额外", {}), "零件剩": s.parts.size(), "日志": _tail_logs(3)}
	# ★ D-06：用零件**不产生待选战术牌**（JS 只有招募 / 晋升两处产生）。
	_set_screen("map")
	return r

## 走进当前格：战斗节点 → 开战（屏幕进 `"battle"`）；其余节点 → 各自结算（留在 `"map"`）。
func enter_current_node() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	var 类型 := _脚下类型(s)
	match 类型:
		"作战", "精英", "守军", "侵蚀源", "出口守军", "追击":
			start_node_battle()
			return last
		"休整":
			return resolve_rest("耐久")
		"黑市":
			_node_result = {"ok": true, "节点": "黑市", "货": NodeResolver.黑市货(s)}
			last = {"行动": "进黑市", "货": _node_result["货"], "源碳": s.carbon, "日志": _tail_logs(2)}
			_set_screen("map")
			return _node_result
		"事件":
			_node_result = {"ok": true, "节点": "事件", "事件": NodeResolver.当前事件(s), "选项": current_event_choices()}
			last = {"行动": "进事件", "事件": str(_node_result["事件"].get("名", "")), "日志": _tail_logs(2)}
			_set_screen("map")
			return _node_result
		"瞭望站":
			_node_result = NodeResolver.结算瞭望站(s, "登高")
			_node_result["节点"] = "瞭望站"
			last = {"行动": "瞭望站", "结果": _node_result, "日志": _tail_logs(3)}
			_set_screen("map")
			return _node_result
		"遗迹":
			_node_result = NodeResolver.结算遗迹(s, "藤蔓")
			_node_result["节点"] = "遗迹"
			last = {"行动": "遗迹", "结果": _node_result, "日志": _tail_logs(3)}
			_set_screen("map")
			return _node_result
		"隧道":
			_node_result = NodeResolver.结算隧道(s)
			_node_result["节点"] = "隧道"
			last = {"行动": "隧道", "结果": _node_result, "从": s.node_id, "日志": _tail_logs(3)}
			_set_screen("map")
			return _node_result
		"空":
			NodeResolver.清空格(s)
			_node_result = {"ok": true, "节点": "空", "文本": "林间空地：落脚休整片刻，未遭遇敌情。"}
			last = {"行动": "空格", "结果": _node_result, "日志": _tail_logs(2)}
			_set_screen("map")
			return _node_result
		"招募站":
			var 领 := RosterManager.招募站领券(s)
			_node_result = {"ok": bool(领.get("ok", false)), "节点": "招募站", "券": 领.get("券", null),
				"券名": str(领.get("券名", "")), "重复": bool(领.get("重复", false))}
			last = {"行动": "招募站", "结果": _node_result, "券数": s.tickets.size(), "日志": _tail_logs(2)}
			_set_screen("map")
			return _node_result
		"出口尽头", "出口小径":
			return try_advance_floor()
	return _fail("这一格（%s）没有可以直接进去的东西" % 类型, {"ok": false, "类型": 类型})

## 走出口 / 换层（内核 `MapNavigator.resolve_exit`）。
func try_advance_floor() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	if not s.pending_card_picks.is_empty():
		return _fail("还有 %d 张战术牌没选（先选完再换层）" % s.pending_card_picks.size(), {"ok": false})
	var 前层 := s.floor_num
	var 前推进 := s.propellant
	var r := MapNavigator.resolve_exit(s)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("为什么", "这一层还换不了")), {"ok": false, "待换层": r.get("待换层", null)})
	_battle_options_cache = _build_battle_options()
	var 藏品希望 := RelicSystem.藏品每层希望(s, s.floor_num)
	last = {
		"行动": "换层", "从层": 前层, "到层": s.floor_num, "通关": bool(r.get("通关", false)),
		"出口类型": MapNavigator.current_exit_kind(s), "推进剂前": 前推进, "推进剂后": s.propellant,
		"推进剂上限": s.propellant_max, "希望": s.hope, "藏品希望": 藏品希望,
		"推进剂明细": MapGenerator.propellant_detail(s), "日志": _tail_logs(3),
	}
	if bool(r.get("通关", false)):
		_result_cache = {"胜": s.status == "胜利", "通关": true, "层": s.floor_num}
		_set_screen("result")
		return r
	_set_screen("map")
	return r

# ==========================================================================================
# 三、名册 / 招募 / 晋升 / 3 选 1 / 编队
# ==========================================================================================

## 用券招一台。`ticket_idx < 0`（默认）= 门面**自己**找第一张对得上的券（走内核 `RosterManager.找同类券`）；
## 手上没有对得上的券时**明确拒绝**并说明原因，绝不静默失败。
func recruit_unit(unit_key: String, ticket_idx: int = -1) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if RosterManager.模板(unit_key).is_empty():
		return _fail("没有这位机师（%s）" % unit_key, {"ok": false, "键": unit_key})
	# ★ P1 纠错（M4-3 实测）：内核 `RosterManager.recruit(state, 键, -1)` **不会**自己找券
	#   （它返回 `{"ok": false, "why": "没有选券：…"}`），所以默认参数必须在门面这一层解析成**显式下标**。
	var 找 := RosterManager.找同类券(s, unit_key)
	if ticket_idx < 0 and not 找.is_empty():
		ticket_idx = int(找.get("下标", -1))
	if ticket_idx < 0 or ticket_idx >= s.tickets.size():
		return _fail("手上没有能招 %s 的券（要有同职业 / 同势力的招募券；现在手上 %d 张：%s）"
			% [unit_key, s.tickets.size(), RosterManager.券汇总文字(s)], {"ok": false, "键": unit_key})
	var 前 := {"希望": s.hope, "券": s.tickets.size(), "名册": s.roster.size()}
	var r := RosterManager.recruit(s, unit_key, ticket_idx)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "招不了")), {"ok": false, "键": unit_key})
	_battle_options_cache = _build_battle_options()
	last = {
		"行动": "招募", "键": unit_key, "等级": int(r.get("等级", 0)), "费": int(r.get("费", 0)),
		"券名": str(r.get("券名", "")), "带队核心": bool(r.get("带队核心", false)),
		"希望前": 前["希望"], "希望后": s.hope, "券前": 前["券"], "券后": s.tickets.size(),
		"名册前": 前["名册"], "名册后": s.roster.size(), "候选战术牌": s.pending_card_picks.duplicate(),
		"日志": _tail_logs(3),
	}
	_refresh_modal()
	_emit()
	return r

func promote_unit(unit_key: String) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	var r := RosterManager.promote(s, unit_key)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "升不了")), {"ok": false, "键": unit_key})
	_battle_options_cache = _build_battle_options()
	last = {"行动": "晋升", "键": unit_key, "从": int(r.get("从", 0)), "到": int(r.get("到", 0)),
		"价": int(r.get("价", 0)), "前": r.get("前", {}), "后": r.get("后", {}),
		"希望": s.hope, "候选战术牌": s.pending_card_picks.duplicate(), "日志": _tail_logs(3)}
	_refresh_modal()
	_emit()
	return r

## 3 选 1：把候选里的一张并进 `tactical_deck`（内核 `DeckBuilder.select_card`）。
func pick_tactical_card(card_id: String) -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	if card_id.is_empty():
		_fail("没有指定要选哪张牌", {"ok": false})
		return false
	if s.pending_card_picks.is_empty():
		_fail("现在没有待选的战术牌", {"ok": false, "候选": []})
		return false
	if not s.pending_card_picks.has(card_id) and DeckBuilder.找到(card_id).is_empty():
		_fail("这张牌不在候选里（%s）" % card_id, {"ok": false, "候选": s.pending_card_picks.duplicate()})
		return false
	var 前 := s.tactical_deck.size()
	var ok := DeckBuilder.select_card(s, card_id)
	if not ok:
		_fail("选牌被内核拒绝（%s）" % card_id, {"ok": false})
		return false
	_battle_options_cache = _build_battle_options()
	last = {"行动": "选战术牌", "牌": card_id, "牌库前": 前, "牌库后": s.tactical_deck.size(),
		"候选清空": s.pending_card_picks.is_empty(), "日志": _tail_logs(2)}
	_refresh_modal()
	_emit()
	return true

## ★ **纯读口子**（D-06 纠错）：回答 UI「这台机体此刻的 3 张候选是哪三张」。
##   **不写 `pending_card_picks`、不调 `_refresh_modal()`、不 `_emit()`。**
##   待选战术牌**只能由招募 / 晋升产生** —— 封存 JS `90-肉鸽-5-晋升与通关.js:62`（招募）与
##   `:151`（晋升）是 `R.待选战术牌` 的**唯一**两处赋值；开局 / 移动 / 用零件 / 事件结算都不产生。
##
##   实现说明（照实登记）：内核 `DeckBuilder` **没有**一个既算候选又不写状态的函数 ——
##   `offer_cards()` 与别名 `候选战术牌们()` 是同一个函数，末尾都写 `state.pending_card_picks`。
##   所以这里用「**先把 `pending_card_picks` 清空，再调 `offer_cards()`**」的办法拿到候选：
##   它既复用了内核**唯一**的候选算法（不自己在门面里重写一遍排序 / 分池），
##   又保证**不新增**任何待选牌（函数返回前也不会把候选写回去）。
func refresh_card_offers(unit_key: String = "") -> Array:
	var s := _need_run()
	if s == null:
		return []
	var 键 := unit_key
	if 键.is_empty():
		键 = str(s.squad_leader) if not str(s.squad_leader).is_empty() else ""
	if 键.is_empty() and not s.roster.is_empty():
		键 = str(s.roster.keys()[0])
	if 键.is_empty() or RosterManager.模板(键).is_empty():
		return []
	# 只有「本来就没有待选牌」时才代跑一次内核算法；有牌在手时**绝不动它**
	# （那种情况是招募 / 晋升留下的，由 `pick_tactical_card` 负责清空）。
	if s.pending_card_picks.is_empty():
		DeckBuilder.offer_cards(s, 键, 3)
		var 候选: Array = s.pending_card_picks.duplicate()
		s.pending_card_picks = []
		return 候选
	return DeckBuilder.候选战术牌们(s, 键, 3)

## 编队 8 个格位（前排 前1.. + 后排 后1..，格数 = `Fm.SLOTS()`）。
func lineup_slots() -> Array:
	_data_ready()
	var s := run_state
	var 占位 := {}
	if s != null:
		for x in s.lineup:
			if x is Dictionary:
				占位[str(x.get("key"))] = int(x.get("slot", -1))
	var out: Array = []
	var n := int(Fm.SLOTS())
	for i in n:
		var 名 := Fm.位名(float(i))
		var 谁 := ""
		for k in 占位.keys():
			if int(占位[k]) == i:
				谁 = str(k)
				break
		out.append({"位": i, "位名": 名, "键": 谁})
	return out

## 把一台摆到某个格位（位名照 `Fm.位名()`：前1..前4 / 后1..后4）。占了位就换过来。
func set_lineup_slot(unit_key: String, slot_name: String) -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	if not s.roster.has(unit_key):
		_fail("名册里没有这台机体（%s）" % unit_key, {"ok": false, "键": unit_key})
		return false
	if not _位名合法(slot_name):
		_fail("没有这个格位（%s）" % slot_name, {"ok": false, "位名": slot_name})
		return false
	var 位 := _位号(slot_name)
	if not _在出击里(s, unit_key) and s.lineup.size() >= RosterManager.deploy_limit(s):
		_fail("出击位满了（上限 %d 台，先把一台撤下来）" % RosterManager.deploy_limit(s), {"ok": false})
		return false
	var 旧 := _在出击的第几格(s, unit_key)
	# ★ 纯函数式重建（不再「就地增删」）：先把「位号 → 一条出击记录」压实成一张表
	#   （同一位号只留最后一条，旧数据里万一有重复也不会带病传下去），再做两步：
	#     ① 把「占着目标位的那一台」搬到这一台原来待的位（旧位不存在就找第一个空位）；
	#     ② 把这一台放到目标位。
	#   这样**同一位号恒好只有一台**，不会再出现「3 条记录只占 2 个格位」。
	var 位表 := _压实出击位(s)
	var 占者 := str(位表.get(位, ""))
	if not 占者.is_empty() and 占者 != unit_key:
		var 挪到 := 旧
		if 挪到 < 0 or 挪到 == 位:
			挪到 = _第一个空位(位表)
		位表.erase(位)
		if 挪到 >= 0:
			位表[挪到] = 占者
	位表[位] = unit_key
	s.lineup = _位表到出击(位表)
	last = {"行动": "编队", "键": unit_key, "位名": slot_name, "位": 位, "原": 旧,
		"出击": s.lineup.duplicate(true), "上限": RosterManager.deploy_limit(s)}
	_set_screen("formation")
	return true

## 撤下来（不在出击里 → false，不改状态）。
func remove_from_lineup(unit_key: String) -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	var 前 := s.lineup.size()
	var 新出击: Array = []
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			continue
		新出击.append(x)
	if 新出击.size() == 前:
		_fail("%s 本来就不在出击位上" % unit_key, {"ok": false, "键": unit_key})
		return false
	s.lineup = 新出击
	last = {"行动": "撤下", "键": unit_key, "出击前": 前, "出击后": s.lineup.size(),
		"出击": s.lineup.duplicate(true)}
	_set_screen("formation")
	return true

## 这张券现在能招谁（纯读：把 `券合` 的机师列出来，附上等级与费用）。
func available_recruit_targets(ticket_idx: int = -1) -> Array:
	_data_ready()
	var s := _need_run()
	if s == null:
		return []
	if s.tickets.is_empty():
		return []
	if ticket_idx < 0 or ticket_idx >= s.tickets.size():
		return []
	var 券: Variant = s.tickets[ticket_idx]
	var 费表: Dictionary = Db.catalog.roguelike_config().get("招募费") if Db.catalog.roguelike_config().get("招募费") is Dictionary else {}
	var out: Array = []
	for 键 in RosterManager.券合机师们(券):
		if s.roster.has(键):
			continue
		var 档 := RosterManager.档(键)
		out.append({"键": 键, "名": str(RosterManager.模板(键).get("名", 键)), "档": 档,
			"费": int(费表.get(档)), "等级": RosterManager.带队核心等级 if s.roster.is_empty() else RosterManager.招募等级(s.floor_num),
			"职业": str(RosterManager.标签(键).get("战斗分类")), "势力": str(RosterManager.标签(键).get("势力")),
			"带队核心": s.roster.is_empty()})
	return out

## 晋升预览（纯读，走 `RosterManager.晋升预览` + `晋升要多少` + 手上的券）。
func promotion_preview(unit_key: String) -> Dictionary:
	_data_ready()
	var s := _need_run()
	if s == null:
		return {"ok": false, "why": "还没有进行中的局"}
	if not s.roster.has(unit_key):
		return {"ok": false, "why": "名册里没有这台机体", "键": unit_key}
	var 从 := s.get_unit_level(unit_key)
	var 到 := RosterManager.晋升目标(从)
	if 到 == 0:
		return {"ok": false, "why": "%s 已经 Lv%d，到顶了" % [unit_key, 从], "键": unit_key, "等级": 从}
	var 价 := RosterManager.晋升要多少(unit_key, 到, s)
	var 找 := RosterManager.找同类券(s, unit_key)
	var 预 := RosterManager.晋升预览(unit_key, 从)
	return {"ok": true, "键": unit_key, "从": 从, "到": 到, "价": 价, "希望": s.hope,
		"能升": s.hope >= 价 and not 找.is_empty(), "有券": not 找.is_empty(),
		"券名": RosterManager.券名(找["券"]) if not 找.is_empty() else "", "前": 预["前"], "后": 预["后"]}

# ==========================================================================================
# 四、非战斗节点交互
# ==========================================================================================

## 休整三选一（"耐久" / "晋升" / "推进剂"）；无论选哪一项内核都会回血。
func resolve_rest(choice: String = "耐久") -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	var 前 := {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	var r := NodeResolver.结算休整(s, choice)
	if r.is_empty():
		return _fail("休整结算失败", {"ok": false})
	r["节点"] = "休整"
	r["前"] = 前
	r["后"] = {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	_node_result = r
	last = {"行动": "休整", "选": choice, "结果": r, "日志": _tail_logs(3)}
	_set_screen("map")
	return r

## 黑市买藏品（内核 `NodeResolver.黑市买`）。
func buy_from_shop(relic_id: String) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if relic_id.is_empty():
		return _fail("没有指定要买哪一件", {"ok": false})
	var 前碳 := s.carbon
	var r := NodeResolver.黑市买(s, relic_id)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "买不了")), {"ok": false, "id": relic_id})
	last = {"行动": "黑市买", "id": relic_id, "名": str(r.get("名", "")), "价": int(r.get("价", 0)),
		"源碳前": 前碳, "源碳后": s.carbon, "藏品数": s.relics.size(), "日志": _tail_logs(3)}
	_battle_options_cache = _build_battle_options()
	_emit()
	return r

func refresh_shop() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	var r := NodeResolver.黑市刷新(s)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "刷新不了")), {"ok": false})
	last = {"行动": "黑市刷新", "价": int(r.get("价", 0)), "次": int(r.get("次", 0)),
		"货": r.get("货", []), "源碳": s.carbon, "日志": _tail_logs(3)}
	_emit()
	return r

func sell_part_in_shop(part_idx: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if part_idx < 0 or part_idx >= s.parts.size():
		return _fail("没有这件零件（下标 %d，手上有 %d 件）" % [part_idx, s.parts.size()], {"ok": false})
	var 前碳 := s.carbon
	var r := PartSystem.sell_part(s, part_idx)
	if r.is_empty():
		return _fail("卖不出去（下标 %d）" % part_idx, {"ok": false})
	last = {"行动": "卖零件", "名": str(r.get("名", "")), "价": int(r.get("价", 0)),
		"源碳前": 前碳, "源碳后": s.carbon, "零件剩": s.parts.size(), "日志": _tail_logs(3)}
	_emit()
	return r

func leave_shop() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	var ok := NodeResolver.黑市离开(s)
	last = {"行动": "离开黑市", "成功": ok, "已清节点": s.nodes_cleared, "日志": _tail_logs(2)}
	_set_screen("map")
	return ok

## 结算一个事件选项（内核 `NodeResolver.结算奇遇`，`choice` 是选项下标）。
func resolve_event_choice(choice: String = "") -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	var r := NodeResolver.结算奇遇(s, choice)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "这个事件结算不了")), {"ok": false})
	r["节点"] = "事件"
	_node_result = r
	last = {"行动": "事件", "事件": str(r.get("事件", "")), "选": str(r.get("选", "")),
		"结果": str(r.get("结果", "")), "日志": _tail_logs(3)}
	# ★ D-06：事件结算**不产生待选战术牌**（JS 只有招募 / 晋升两处产生）。
	_set_screen("map")
	return r

## 这一格事件的选项文字（纯读；UI 拿去画按钮）。
func current_event_choices() -> Array:
	var s := _need_run()
	if s == null:
		return []
	var 事 := NodeResolver.当前事件(s)
	var out: Array = []
	var 选项们: Array = 事.get("选") if 事.get("选") is Array else []
	for i in 选项们.size():
		var 条: Variant = 选项们[i]
		out.append({"序": i, "文": str((条 as Dictionary).get("文", "")) if 条 is Dictionary else str(条)})
	return out

# ==========================================================================================
# 五、战斗
# ==========================================================================================

## 快速测试战：默认五人队（Lv10）对第 1 层普通编成，**不需要先开一局肉鸽**（D-01 体感试玩）。
func start_quick_battle(seed_val: int = 20261013) -> bool:
	_data_ready()
	var 我方 := _默认五人编成()
	if 我方.is_empty():
		_fail("默认五人队读不到（数据没装好）", {"ok": false})
		return false
	var 条目: Dictionary = _第几层普通编成(1)
	if 条目.is_empty():
		_fail("编成表里没有第 1 层「普通」编成", {"ok": false})
		return false
	if run_state == null:
		run_state = RosterManager.new_run(seed_val, 默认分队)
	# ★ 快速战斗也要把默认五人队填进名册：顶栏 / 结算屏的「名册」与「血比」才有内容可画。
	#   用**数据里写的等级**（默认五人队 = Lv10），不要跟着 `招募等级` 走。
	for 条 in 我方:
		var k := str((条 as Dictionary).get("键", ""))
		if k.is_empty() or run_state.roster.has(k):
			continue
		run_state.roster[k] = {"key": k, "lv": int(float((条 as Dictionary).get("等级", 10))), "hpRatio": 1.0}
		if run_state.lineup.size() < RosterManager.deploy_limit(run_state):
			run_state.lineup.append({"key": k, "slot": run_state.lineup.size()})
	_quick_battle = true
	_本场已结算 = false
	_血比战前 = _名册血比()
	_battle_options_cache = _build_battle_options()
	var 种子 := seed_val + 快速战斗种子偏移
	var 敌方 := NodeResolver.编成到规格(条目, 0)
	# ★ 快速战斗也要给 ctx 一张真正能被 UI 认的开关表（键 = 位号字符串，照 `Btl.设单位开关` 的口径）。
	_battle_options_cache["单位开关"] = _unit_switches.duplicate(true)
	var ctx := Setup.开局(我方, 敌方, 种子, _unit_switches.duplicate(true), _battle_options_cache)
	if ctx.is_empty():
		_fail("战斗内核没有给出 ctx", {"ok": false})
		return false
	battle_ctx = ctx
	_unit_switches = 表(ctx, "选项")
	_result_cache = {}
	last = {"行动": "快速战斗", "种子": 种子, "我方": 我方.size(), "敌方": 敌方.size(),
		"手牌": hand_count(), "候补": reserve_preview().size(), "气势": _气氛(), "日志": battle_log_lines(3)}
	_set_screen("battle")
	return true

## 打当前这一格的战斗节点（真肉鸽路径，走 `NodeResolver.开战`）。
func start_node_battle() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	if s.map_data.is_empty():
		_fail("还没有大地图", {"ok": false})
		return false
	if NodeResolver.我方编成(s).is_empty():
		_fail("出击名单是空的（先去招募并编队）", {"ok": false})
		return false
	var 格类型 := _脚下类型(s)
	var 类型 := NodeResolver.战斗类型Of(s, 格类型)
	var rng := Mulberry32.new(NodeResolver.编成种子(s, s.floor_num))
	var 详情 := NodeResolver.抽编成兜底(s.floor_num, 类型, rng)
	if 详情.is_empty() or not (详情.get("条目") is Dictionary):
		_fail("抽不到第 %d 层「%s」的编成" % [s.floor_num, 类型], {"ok": false})
		return false
	s.map_data["本场兜底"] = {"层": s.floor_num, "格": s.node_id, "到": str(详情.get("类型", 类型))} if 详情.get("兜底") != null else null
	_battle_options_cache = _build_battle_options()
	_battle_options_cache["单位开关"] = _unit_switches.duplicate(true)
	var ctx := NodeResolver.开战(s, 详情["条目"])
	if ctx.is_empty():
		_fail("战斗内核没有给出 ctx", {"ok": false})
		return false
	_quick_battle = false
	_本场已结算 = false
	_血比战前 = _名册血比()
	battle_ctx = ctx
	_unit_switches = 表(ctx, "选项")
	_result_cache = {}
	last = {"行动": "开战", "格类型": 格类型, "编成类型": str(详情.get("类型", 类型)),
		"编成层": int(详情.get("层", s.floor_num)), "兜底": 详情.get("兜底", null),
		"敌方": (ctx.get("enemies") as Array).size(), "我方": (ctx.get("allies") as Array).size(),
		"手牌": hand_count(), "候补": reserve_preview().size(), "日志": battle_log_lines(3)}
	_set_screen("battle")
	return true

## 打一张战术牌 —— **纯委托**（内核 `Btl.打战术牌`，成败完全由气势 / 冷却 / 剩余次数与手牌事实决定）。
## ★ **没有张数门槛**（D-03 纠错）：JS 与内核都不限每回合出牌数，所以这里**不设**任何「打满 N 张」拦截。
##   想给 UI 置灰请用 `hand_card_status(card_id)` / `cards_playable_now()`（纯读，判据与 JS 同一套）。
func play_tactical_card(card_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if card_id.is_empty():
		return _fail("没有指定要打哪张牌", {"ok": false})
	var 手牌 := hand_cards()
	var 找到 := {}
	for c in 手牌:
		if str(c.get("id", "")) == card_id or str(c.get("名", "")) == card_id:
			找到 = c
			break
	if 找到.is_empty():
		return _fail("手牌里没有这张牌（%s）" % card_id, {"ok": false, "手牌": 手牌.size()})
	var 气势前 := _气氛()
	var r := Btl.打战术牌(battle_ctx, card_id)
	if not bool(r.get("成功", false)):
		return _fail(str(r.get("原因", "打不出来")), {"ok": false, "本回合已打出": cards_played_this_turn()})
	last = {"行动": "打战术牌", "牌": card_id, "牌名": str(找到.get("名", "")), "层级": str(找到.get("层级", "")),
		"耗气": float(找到.get("耗气", 0.0)) if 找到.get("耗气") != null else 0.0,
		"回气": float(找到.get("回气", 0.0)) if 找到.get("回气") != null else 0.0,
		"气势前": 气势前, "气势后": _气氛(), "本回合已打出": cards_played_this_turn(),
		"效果摘要": r.get("效果摘要", {}), "日志": battle_log_lines(3)}
	_emit()
	return r

## 切一台的开关：`"保留大招"`（大招憋住/放开）或 `"TRANSAM"`（`"自动"` / `"手动"`）。
## 语义 = 真实内核 `Btl.设单位开关` 的开关表（**键是位号**），这里改表 + 立刻对活单位生效。
func toggle_unit_switch(unit_id: String, switch_key: String) -> bool:
	if battle_ctx.is_empty():
		_fail("现在不在战斗里", {"ok": false})
		return false
	var u := _找单位(unit_id)
	if u.is_empty():
		_fail("这一方没有这台单位（%s）" % unit_id, {"ok": false, "单位": unit_id})
		return false
	var 位 := str(int(float(u.get("slot", -1))))
	if not _unit_switches.has(位) or not (_unit_switches[位] is Dictionary):
		_unit_switches[位] = {}
	var 表条: Dictionary = _unit_switches[位]
	var 值 := ""
	if switch_key == "保留大招":
		var 新: bool = not bool(u.get("holdUlt", false))
		表条["保留大招"] = 新
		值 = "开" if 新 else "关"
	elif switch_key == "TRANSAM":
		var 新2: String = "自动" if bool(u.get("TRANSAM手动", false)) else "手动"
		表条["TRANSAM"] = 新2
		值 = 新2
	else:
		_fail("没有这个开关（%s）—— 真实内核只有「保留大招」与「TRANSAM」" % switch_key, {"ok": false})
		return false
	Btl.设单位开关(battle_ctx, _unit_switches)
	last = {"行动": "切开关", "单位": unit_id, "开关": switch_key, "值": 值,
		"开关表": _unit_switches.duplicate(true), "状态行": unit_view("ally", unit_id).get("状态", [])}
	_emit()
	return true

## 立刻开这一台的势力状态（今天真实可用的只有天人 TRANS-AM 的手动开启）。
## 语义 = 真实内核钩子 `FacCb.手动开天人`：先置 `本回合开TRANSAM`，再让引擎自己过闸
## （没解锁 / 冷却中 / 已经开着 → 引擎返回 0 次 → 这里 false）。
func activate_unit_state(unit_id: String) -> bool:
	if battle_ctx.is_empty():
		_fail("现在不在战斗里", {"ok": false})
		return false
	var u := _找单位(unit_id)
	if u.is_empty():
		_fail("这一方没有这台单位（%s）" % unit_id, {"ok": false, "单位": unit_id})
		return false
	if not FacCb.有TRANSAM(u, null):
		_fail("%s 没有 TRANS-AM（这台机体不吃这条命令）" % unit_id, {"ok": false, "单位": unit_id})
		return false
	var 位 := str(int(float(u.get("slot", -1))))
	if not _unit_switches.has(位) or not (_unit_switches[位] is Dictionary):
		_unit_switches[位] = {}
	(_unit_switches[位] as Dictionary)["TRANSAM"] = "手动"
	(_unit_switches[位] as Dictionary)["本回合开TRANSAM"] = true
	Btl.设单位开关(battle_ctx, _unit_switches)
	var 开数 := FacCb.手动开天人(battle_ctx, float(battle_ctx.get("turn", 1.0)), null)
	(_unit_switches[位] as Dictionary)["本回合开TRANSAM"] = false
	var 状: Dictionary = Fac.势力状态(u, "天人")
	var ok: bool = 开数 > 0.0
	if not ok:
		_fail("%s 现在开不了 TRANS-AM（没解锁 / 冷却中 / 已经开着）" % unit_id,
			{"ok": false, "单位": unit_id, "冷却到回合": float(状.get("冷却到回合", 0.0))})
		return false
	last = {"行动": "开势力状态", "单位": unit_id, "势力": "天人", "特色": "TRANS-AM",
		"启动回合": float(状.get("启动回合", 0.0)), "结束回合": float(状.get("结束回合", 0.0)),
		"冷却到回合": float(状.get("冷却到回合", 0.0)), "状态行": unit_view("ally", unit_id).get("状态", []),
		"日志": battle_log_lines(2)}
	_emit()
	return true

## 推进一个完整战斗回合（内核 `Setup.打一回合`）。
func step_battle_turn() -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if battle_ctx.get("result") != null:
		return _fail("这一场已经打完了（%s）" % str((battle_ctx["result"] as Dictionary).get("结果", "")), {"ok": false})
	var 前回合 := int(float(battle_ctx.get("turn", 1.0)))
	Setup.打一回合(battle_ctx)
	var 后回合 := int(float(battle_ctx.get("turn", 1.0)))
	last = {"行动": "打一回合", "从回合": 前回合, "到回合": 后回合,
		"结果": 战果文字(), "结算": battle_ctx.get("result", null),
		"手牌": hand_count(), "候补": reserve_preview().size(), "气势": _气氛(),
		"日志": battle_log_lines(4)}
	_emit()
	return last

## 一路 `Setup.打一回合` 到出结果（带护栏，照 `NodeResolver.打完一场` 的口径）。
func auto_finish_battle() -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	var 打了几回合 := 0
	if battle_ctx.get("result") == null:
		var 顶 := maxf(float(Db.T.get("MAX_TURN", 12.0)), float(battle_ctx.get("回合上限", 12.0))) + 2.0
		var 护栏 := 0.0
		while battle_ctx.get("result") == null and 护栏 < 顶:
			护栏 += 1.0
			打了几回合 += 1
			Setup.打一回合(battle_ctx)
		if battle_ctx.get("result") == null:
			battle_ctx["result"] = {"结果": "败", "原因": "超出回合上限"}
	last = {"行动": "自动打完", "回合数": 打了几回合, "结果": 战果文字(), "结算": battle_ctx.get("result", null),
		"我方存活": _存活数("ally"), "敌方存活": _存活数("enemy"), "日志": battle_log_lines(4)}
	_emit()
	return last

## 战后结算：肉鸽路径走内核 `NodeResolver.resolve_battle`（回血 / 券 / 藏品 / 零件 / 耐久 / 换层）。
## ★ **幂等**（D-07）：同一场只结算一次。重复调用**一个字都不改**（不重跑内核、不重算 `_result_cache`、
##   不改 `last`、不 `_emit`），只回一条 `{"ok": false, "为什么": …}`。
func finish_battle_and_settle() -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if battle_ctx.get("result") == null:
		return _fail("这一场还没打完（先 `auto_finish_battle()` 或 `step_battle_turn()`）", {"ok": false})
	if _本场已结算:
		# ★ D-07：结算过就不再结算 —— 这里**不许**碰任何状态（不跑内核、不重算缓存、不改 last、不 emit）。
		#   只把一条错误记进 `errors` 并返回；连 `last` 都不覆盖（免得把结算屏的「上一动作」冲掉）。
		var 为什么 := "这一场已经结算过了（要再打请先走下一格 / 开下一场）"
		errors.append(为什么)
		errored.emit(为什么)
		return {"ok": false, "为什么": 为什么, "屏幕": screen, "已结算": true}
	var s := run_state
	if s == null or _quick_battle or s.map_data.is_empty():
		_本场已结算 = true
		_result_cache = _build_result_cache({})
		last = {"行动": "结算", "结果": result_summary()}
		_set_screen("result")
		return last["结果"]
	var 格类型 := _脚下类型(s)
	# ★ P0（2026-10-13 M4-3 实测 + ARGON 复核）：**「血比前」必须在这一句之前、且每次都重抓**。
	#   `NodeResolver.resolve_battle` 内部会依次跑 `RosterManager.记战斗HP`（把战后血量写回名册）
	#   再 `战后回血`（+50%）。「回血前后对照」要的是**打完那一瞬间、回血之前**的名册血比，
	#   所以：① 位置在这一句之前；② **不能**用 `is_empty()` 那种「有就复用」的写法——
	#   开战时抓的那份是「开战前」的满血值，复用它会让 `血比前 == 血比后`，结算那一层就空了。
	_血比战前 = _名册血比()
	var r := NodeResolver.resolve_battle(s, battle_ctx, 格类型)
	r["格类型"] = 格类型
	_result_cache = _build_result_cache(r)
	# 战斗之后：守军 / 追击打赢要补上欠的换层；其他节点清空这一格。
	if bool(r.get("胜", false)):
		if 格类型 == "出口守军":
			var 进 := MapNavigator.after_guard_win(s)
			r["换层"] = 进
		elif s.propellant <= 0:
			var 追 := MapNavigator.after_chase_win(s)
			r["追击换层"] = 追
			r["追击"] = true
		else:
			NodeResolver.清空格(s)
	else:
		if s.status != "失败":
			NodeResolver.清空格(s)
	_battle_options_cache = _build_battle_options()
	_result_cache["结算"] = r
	_本场已结算 = true
	last = {"行动": "结算", "结果": result_summary(), "内核": r}
	_set_screen("result")
	return r

# ==========================================================================================
# 六、展示辅助（给 M4-2 / M4-3 的 UI 用：**纯读，不改状态**）
# ==========================================================================================

func hand_cards() -> Array:
	if battle_ctx.is_empty():
		return []
	var 手: Variant = battle_ctx.get("战术手牌")
	return (手 as Array).duplicate() if 手 is Array else []

func hand_count() -> int:
	return hand_cards().size()

## 本回合已经打出的战术牌张数 —— **是「事实报告」，不是「预算」**（D-03：内核没有张数上限）。
## 数法：`ctx.log` 里 `类型 == "战术牌"` 且 `回合 == ctx.turn` 的条目数（纯读）。
func cards_played_this_turn() -> int:
	if battle_ctx.is_empty():
		return 0
	var 回合 := float(battle_ctx.get("turn", 1.0))
	var n := 0
	var 日志: Variant = battle_ctx.get("log")
	if 日志 is Array:
		for e in (日志 as Array):
			if e is Dictionary and str(e.get("类型", "")) == "战术牌" and float(e.get("回合", 0.0)) == 回合:
				n += 1
	return n

## 现在能打几张 —— 当前手牌里**满足与 JS 完全同一判据**的张数（**没有任何「上限」**，D-03）。
## 判据 = `src/js/80-界面-3-战斗屏与方针栏.js:94`：`当前气 >= 耗 && 冷却 <= 0 && 剩 > 0`。
func cards_playable_now() -> int:
	var n := 0
	for c in hand_cards():
		if _卡可打吗(c).get("可打", false):
			n += 1
	return n

## 一张手牌的「预告」（三层反馈的预告那一层 · 手牌半边）：能不能打、为什么不能打。
## 返回 `{在手里, 可打, 原因, 耗气, 回气, 冷却, 剩余}`；原因文案照 JS `80-界面-3:100` 的口径
## （`冷却 N 回合` / `需 N 气势` / `剩余 0 次`，可打时 `点击发动`）。
func hand_card_status(card_id: String) -> Dictionary:
	var 空 := {"在手里": false, "可打": false, "原因": "手牌里没有这张牌", "耗气": 0.0, "回气": 0.0, "冷却": 0, "剩余": 0}
	if battle_ctx.is_empty():
		空["原因"] = "现在不在战斗里"
		return 空
	for c in hand_cards():
		if str(c.get("id", "")) == card_id or str(c.get("名", "")) == card_id:
			var s := _卡可打吗(c)
			s["在手里"] = true
			return s
	return 空

## 全部手牌的预告行（UI 直接遍历画手牌栏；纯读）。
func hand_status_all() -> Array:
	var out: Array = []
	for c in hand_cards():
		var s := _卡可打吗(c)
		s["在手里"] = true
		s["id"] = str(c.get("id", ""))
		s["名"] = str(c.get("名", ""))
		s["层级"] = str(c.get("层级", ""))
		out.append(s)
	return out

## 一张牌的判据（与 JS `80-界面-3:94/100` 同一套；只读，不改任何状态）。
func _卡可打吗(c: Dictionary) -> Dictionary:
	var 气势 := _气氛()
	var 耗 := float(c.get("耗气", 0.0)) if c.get("耗气") != null else 0.0
	var 回 := float(c.get("回气", 0.0)) if c.get("回气") != null else 0.0
	var 冷 := int(c.get("当前冷却", 0.0)) if c.get("当前冷却") != null else 0
	var 剩 := int(c.get("剩余次数", 1.0)) if c.get("剩余次数") != null else 1
	var 可打 := 气势 >= 耗 and 冷 <= 0 and 剩 > 0
	var 原因 := ""
	if not 可打:
		if 冷 > 0:
			原因 = "冷却 %d 回合" % 冷
		elif 气势 < 耗:
			原因 = "需 %d 气势" % int(JsCompat.js_round(耗))
		elif 剩 <= 0:
			原因 = "剩余 0 次"
		else:
			原因 = "打不出来"
	else:
		原因 = "点击发动"
	return {"在手里": true, "可打": 可打, "原因": 原因, "耗气": 耗, "回气": 回, "冷却": 冷, "剩余": 剩, "气势": 气势}

## 候补初始牌（D-01 重点）：数量与列表。
func reserve_preview() -> Array:
	if battle_ctx.is_empty():
		return []
	var 候: Variant = battle_ctx.get("候补初始牌")
	return (候 as Array).duplicate() if 候 is Array else []

## 还没进手牌的牌还有多少张（候补 + 还在等条件的触发牌）。
func deck_remaining() -> int:
	if battle_ctx.is_empty():
		return 0
	var n := 0
	var 候: Variant = battle_ctx.get("候补初始牌")
	if 候 is Array:
		n += (候 as Array).size()
	var 待: Variant = battle_ctx.get("待触发战术牌")
	if 待 is Array:
		n += (待 as Array).size()
	return n

## 手牌里现在气力够、冷却好了、次数还有的牌 id（判据同 `cards_playable_now()`，纯读）。
func playable_hand_ids() -> Array:
	var out: Array = []
	for c in hand_cards():
		if _卡可打吗(c).get("可打", false):
			out.append(str(c.get("id", c.get("名", ""))))
	return out

## 战斗日志文本行（纯读；`limit` ≤ 0 = 全部）。
func battle_log_lines(limit: int = 40) -> Array:
	if battle_ctx.is_empty():
		return []
	var 日志: Variant = battle_ctx.get("log")
	if not (日志 is Array):
		return []
	var 全: Array = 日志
	var 起 := 0 if limit <= 0 else maxi(0, 全.size() - limit)
	var out: Array = []
	for i in range(起, 全.size()):
		var e: Variant = 全[i]
		if e is Dictionary:
			out.append("[第 %d 回合] %s" % [int(float(e.get("回合", 0.0))), str(e.get("文本", ""))])
		else:
			out.append(str(e))
	return out

## 结构化日志（最近 `limit` 条，字典原样；UI 要按 `类型` 高亮时用它）。
func battle_log_entries(limit: int = 40) -> Array:
	if battle_ctx.is_empty():
		return []
	var 日志: Variant = battle_ctx.get("log")
	if not (日志 is Array):
		return []
	var 全: Array = 日志
	var 起 := 0 if limit <= 0 else maxi(0, 全.size() - limit)
	var out: Array = []
	for i in range(起, 全.size()):
		var e: Variant = 全[i]
		out.append((e as Dictionary).duplicate(true) if e is Dictionary else {"文本": str(e)})
	return out

## 一台单位的展示快照（HP / 护盾 / 气势 / 状态行 / 开关；纯读）。
## `side` 收 `"ally"`（`"我方"`）/ `"enemy"`（`"敌方"`），`unit_id` 收 `key` / `tplKey` / `名`。
func unit_view(side: String, unit_id: String) -> Dictionary:
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	if battle_ctx.is_empty():
		return {"ok": false, "为什么": "现在不在战斗里"}
	var 池: Variant = battle_ctx.get(方 + "s")
	if not (池 is Array):
		池 = battle_ctx.get("allies") if 方 == "ally" else battle_ctx.get("enemies")
	var u := {}
	for x in (池 as Array):
		if not (x is Dictionary):
			continue
		if str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id:
			u = x
			break
	if u.is_empty():
		return {"ok": false, "为什么": "这一方没有这台单位（%s）" % unit_id, "单位": unit_id}
	var 生命 := float(u.get("hp", 0.0))
	var 满 := float(u.get("maxHp", 1.0))
	if 满 <= 0.0:
		满 = 1.0
	var 势 := float(battle_ctx.get("气势", 0.0)) if 方 == "ally" else 0.0
	return {
		"ok": true, "键": str(u.get("key", "")), "模板": str(u.get("tplKey", "")), "名": str(u.get("name", unit_id)),
		"方": 方, "位": int(float(u.get("slot", -1))), "位名": Fm.位名(float(u.get("slot", 0.0))),
		"职业": str(Reach.战斗分类Of(u)), "势力": str(Fac.势力名(u)),
		"等级": int(float(u.get("lv", 0.0))),
		"HP": 生命, "最大HP": 满, "血比": clampf(生命 / 满, 0.0, 1.0),
		"护盾": float(u.get("shield", 0.0)), "气势": 势,
		"标定层数": int(Calc.标定经济层数(u)),
		"SEED累计": int(JsCompat.js_round(FacSeed.SEED累计(u))), "SEED已觉醒": FacSeed.SEED已觉醒(u),
		"增益": _增益文字们(u.get("buffs")), "减益": _增益文字们(u.get("debuffs")),
		"状态": _状态行(方, u), "开关": _开关行(u),
		"活着": 生命 > 0.0,
	}

## 顶栏常驻状态（层 / 推进剂 / 源碳 / 希望 / 基地耐久 / 等级经验 / 出击上限 / 藏品 / 零件）。
func topbar_state() -> Dictionary:
	_data_ready()
	var s := run_state
	if s == null:
		return {"有局": false, "屏幕": screen}
	var 账 := MapGenerator.propellant_detail(s) if not s.map_data.is_empty() else {}
	var 门槛: Variant = RosterManager.升级门槛(s.level)
	return {
		"有局": true, "屏幕": screen, "层": s.floor_num, "状态": s.status,
		"当前格": s.node_id, "节点类型": str(s.map_data.get("当前节点类型", s.current_type())),
		"推进剂": s.propellant, "推进剂上限": s.propellant_max, "推进剂明细": 账,
		"源碳": s.carbon, "希望": s.hope,
		"基地耐久": s.base_hp, "基地最大耐久": s.base_max_hp,
		"等级": s.level, "经验": s.exp_val, "升级门槛": 门槛,
		"出击上限": RosterManager.deploy_limit(s), "出击数": s.lineup.size(),
		"名册数": s.roster.size(), "券数": s.tickets.size(),
		"藏品数": s.relics.size(), "藏品": s.relics.duplicate(),
		"零件数": s.parts.size(), "零件": s.parts.duplicate(true),
		"战术牌库": s.tactical_deck.duplicate(), "待选战术牌": s.pending_card_picks.duplicate(),
		"已清节点": s.nodes_cleared, "场次": s.battles_fought, "胜场": s.battles_won,
	}

## 结算面板的数据（三层反馈的「结算」那一层）：胜负 / 回血前后 / 战利品 / 本场打出的战术牌回顾。
func result_summary() -> Dictionary:
	_data_ready()
	if _result_cache.is_empty() and battle_ctx.is_empty() and run_state == null:
		return {"有结果": false}
	var r := _result_cache
	var 结算: Dictionary = r.get("结算") if r.get("结算") is Dictionary else {}
	var 打牌: Array = r.get("本场战术牌", [])
	var 回血: Variant = r.get("回血", {})
	var 前: Dictionary = r.get("名册回血前", {})
	var 后 := _名册血比()
	return {
		"有结果": not r.is_empty(),
		"胜": bool(r.get("胜", false)), "负": not bool(r.get("胜", false)),
		"结果": str(r.get("结果", "未知")), "原因": str(r.get("原因", "")),
		"回合数": int(r.get("回合数", 0)), "格类型": str(r.get("格类型", "")),
		"通关": bool(r.get("通关", false)), "结束": bool(r.get("结束", false)),
		"耐久扣": int(r.get("扣", 0)),
		"战利品": {
			"希望": int(r.get("希望", 0)), "源碳": int(r.get("源碳", 0)),
			"券": r.get("券", null), "券名": RosterManager.券名(r["券"]) if r.get("券") is Dictionary else "",
			"藏品": r.get("藏品", null), "额外编制": r.get("额外编制", null), "零件": r.get("零件", null),
			"额外": r.get("额外", {}),
		},
		"回血": {
			"台数": int(回血.get("台数", 0)) if 回血 is Dictionary else 0,
			"回复比例": float(回血.get("回复比例", 0.0)) if 回血 is Dictionary else 0.0,
			"名字们": 回血.get("名字们", []) if 回血 is Dictionary else [],
			"文本": str(回血.get("文本", "")) if 回血 is Dictionary else "",
		},
		"血比前": 前, "血比后": 后,
		"带伤": int(r.get("带伤", 0)), "倒下": int(r.get("倒下", 0)), "奖励档": str(r.get("奖励档", "")),
		"本场战术牌": 打牌, "本场战术牌数": 打牌.size(),
		"换层": r.get("换层", {}), "冲击追击": bool(r.get("追击", false)),
		"战斗日志行数": battle_log_lines(0).size(),
		"日志": _tail_logs(4),
	}

# ==========================================================================================
# 七、内部：状态快照 / 找单位 / 小工具
# ==========================================================================================

## 开战时存的那一份「我方开关表」（键 = 位号字符串）；UI 拿它画开关的初始状态。
func unit_switches() -> Dictionary:
	return _unit_switches.duplicate(true)

func current_node_result() -> Dictionary:
	return _node_result.duplicate(true)

func _set_screen(v: String) -> void:
	screen = v
	_refresh_modal()
	_emit()

func _emit() -> void:
	changed.emit()

func _fail(msg: String, extra: Dictionary) -> Dictionary:
	if msg.is_empty():
		msg = "命令被拒绝"
	errors.append(msg)
	var d := {"ok": false, "为什么": msg, "屏幕": screen}
	for k in extra.keys():
		d[k] = extra[k]
	last = d.duplicate(true)
	errored.emit(msg)
	_emit()
	return d

func _need_run() -> RunState:
	_data_ready()
	return run_state

func _data_ready() -> void:
	if Db.installed:
		return
	var errs: Array = []
	DataLoader.install(errs)

## `_unit_switches` 的兼容读法：优先用自己那张表，其次读 ctx["选项"]（内核存在那儿的选项）。
## ★ 另给一个纯 ASCII 名字 `unit_switch_table()`：GDScript 里 `字典名.中文方法名` 这种动态调用
##   在部分写法下会找错符号（实测 `.table(...)` 报 `Nonexistent function 'table'`），ASCII 名字更稳。
func 表(ctx: Dictionary, 键: String) -> Dictionary:
	var v: Variant = ctx.get(键)
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return _unit_switches.duplicate(true)

func unit_switch_table(ctx: Dictionary, 键: String = "选项") -> Dictionary:
	return 表(ctx, 键)

func _build_battle_options() -> Dictionary:
	if run_state == null:
		return {"战术卡牌": true, "已选战术牌": [], "藏品": []}
	var o := RelicSystem.build_battle_options(run_state)
	o["战术卡牌"] = true
	return o

func _默认五人编成() -> Array:
	_data_ready()
	var 表队: Variant = Db.T.get("默认五人队")
	if not (表队 is Array):
		return []
	var out: Array = []
	for e in (表队 as Array):
		if not (e is Dictionary):
			continue
		var 键 := str(e.get("键", ""))
		if 键.is_empty():
			continue
		var 等级 := float(e.get("等级", 10)) if e.get("等级") != null else 10.0
		out.append({"键": 键, "等级": 等级, "hp比": 1.0})
	return out

func _第几层普通编成(层: int):
	var 表 := Db.catalog.stages()
	for e in 表:
		if e is Dictionary and int(e.get("层", 0)) == 层 and str(e.get("类型", "")) == "普通":
			return e
	# 该层没有「普通」→ 退到全表第一条（兜底，不崩）
	for e in 表:
		if e is Dictionary:
			return e
	return {}

func _找单位(unit_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return {}
	var 池: Variant = battle_ctx.get("allies")
	if 池 is Array:
		for x in (池 as Array):
			if x is Dictionary and (str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id):
				return x
	池 = battle_ctx.get("enemies")
	if 池 is Array:
		for x in (池 as Array):
			if x is Dictionary and (str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id):
				return x
	return {}

func _气氛() -> float:
	if battle_ctx.is_empty():
		return 0.0
	var v: Variant = battle_ctx.get("气势")
	return float(v) if v != null else 0.0

func _存活数(方: String) -> int:
	if battle_ctx.is_empty():
		return 0
	var 池: Variant = battle_ctx.get("allies") if 方 == "ally" else battle_ctx.get("enemies")
	if not (池 is Array):
		return 0
	var n := 0
	for u in (池 as Array):
		if u is Dictionary and float(u.get("hp", 0.0)) > 0.0:
			n += 1
	return n

func _战果文字() -> String:
	if battle_ctx.is_empty():
		return ""
	var r: Variant = battle_ctx.get("result")
	if r is Dictionary:
		return str(r.get("结果", ""))
	return ""

func 战果文字() -> String:
	return _战果文字()

func _增益文字们(v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for b in (v as Array):
		if not (b is Dictionary):
			continue
		var 段 := []
		段.append(str(b.get("src", "增益")))
		for k in b.keys():
			if k == "src" or k == "剩余":
				continue
			var 值: Variant = b[k]
			if 值 is int or 值 is float:
				段.append("%s %s%s" % [str(k), "+" if float(值) > 0.0 else "", str(int(JsCompat.js_round(float(值))))])
		out.append("：".join([段[0], "、".join(段.slice(1))]) if 段.size() > 1 else str(段[0]))
	return out

func _状态行(方: String, u: Dictionary) -> Array:
	var out: Array = []
	if bool(u.get("holdUlt", false)):
		out.append("憋大招")
	var 势力 := str(Fac.势力名(u))
	if 势力 == "天人":
		var 状: Dictionary = Fac.势力状态(u, "天人")
		out.append("TRANS-AM")
		if bool(状.get("激活", false)):
			out.append("TRANS-AM：开着（第 %d 回合起）" % int(float(状.get("启动回合", 0.0))))
		elif bool(状.get("冷却中", false)):
			out.append("TRANS-AM：冷却到第 %d 回合" % int(float(状.get("冷却到回合", 0.0))))
		else:
			out.append("TRANS-AM：待机")
		out.append("TRANS-AM：手动" if bool(u.get("TRANSAM手动", false)) else "TRANS-AM：自动")
	var 标 := int(Calc.标定经济层数(u))
	if 标 > 0:
		out.append("标定 %d 层" % 标)
	if 方 == "enemy" and bool(u.get("词条全场", false)):
		out.append("全场词条")
	if float(u.get("shield", 0.0)) > 0.0:
		out.append("护盾 %d" % int(JsCompat.js_round(float(u.get("shield", 0.0)))))
	if out.is_empty():
		out.append("正常")
	return out

func _开关行(u: Dictionary) -> Array:
	var out: Array = []
	out.append("保留大招：%s" % ("开" if bool(u.get("holdUlt", false)) else "关"))
	if str(Fac.势力名(u)) == "天人":
		out.append("TRANSAM：%s" % ("手动" if bool(u.get("TRANSAM手动", false)) else "自动"))
	return out

## 脚下这一格的**真实**类型（判据只此一处：格表优先，认不出来才退回 `map_data["当前节点类型"]`）。
## ★ 为什么不直接用 `map_data["当前节点类型"]`：`RosterManager._进层()` 只写过起点那一格，
##   换层 / 测试里直接摆 `node_id` 之后它就是**旧值**；从格表读才是脚下这一格的事实。
func _脚下类型(s: RunState) -> String:
	var t := str(s.cell_at(s.node_id).get("类型", ""))
	if not t.is_empty():
		return t
	return str(s.map_data.get("当前节点类型", ""))

func _位名合法(slot_name: String) -> bool:
	var n := int(Fm.SLOTS())
	for i in n:
		if Fm.位名(float(i)) == slot_name:
			return true
	return false

func _位号(slot_name: String) -> int:
	var n := int(Fm.SLOTS())
	for i in n:
		if Fm.位名(float(i)) == slot_name:
			return i
	return -1

func _在出击里(s: RunState, unit_key: String) -> bool:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return true
	return false

## 这一台在出击名单里占的位号（不在 → −1）。
func _在出击的第几格(s: RunState, unit_key: String) -> int:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return int(x.get("slot", -1))
	return -1

## 出击名单 → 「位号 → 键」压实表：同一位号只留**最后**一条；位号越界（<0 / ≥ SLOTS）的丢掉。
func _压实出击位(s: RunState) -> Dictionary:
	var 位表 := {}
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var k := str(x.get("key", ""))
		var 位 := int(x.get("slot", -1))
		if k.is_empty() or 位 < 0 or 位 >= int(Fm.SLOTS()):
			continue
		位表[位] = k
	return 位表

## 「位号 → 键」→ 出击名单（按位号升序，形状照 `RunState.lineup`）。
func _位表到出击(位表: Dictionary) -> Array:
	var 位们 := []
	for 位 in 位表.keys():
		位们.append(int(位))
	位们 = JsCompat.stable_sort(位们, func(a, b): return int(a) < int(b))
	var out: Array = []
	for 位 in 位们:
		out.append({"key": str(位表[位]), "slot": int(位)})
	return out

## `位表` 里没用掉的最小格位（换位时找不到旧格就用它兜底）。
func _第一个空位(位表: Dictionary) -> int:
	for i in int(Fm.SLOTS()):
		if not 位表.has(i):
			return i
	return 0

func _名册血比() -> Dictionary:
	var out := {}
	if run_state == null:
		return out
	for k in run_state.roster.keys():
		out[str(k)] = float(run_state.get_unit_hp_ratio(str(k)))
	return out

func _tail_logs(n: int) -> Array:
	if run_state == null:
		return []
	var 全: Array = run_state.logs
	var 起 := maxi(0, 全.size() - maxi(0, n))
	var out: Array = []
	for i in range(起, 全.size()):
		out.append(str(全[i]))
	return out

## 每回合打牌的即时小计（UI 底栏那一行）。★ **只报事实，不报「上限」**（D-03：内核没有张数上限）。
func turn_card_summary() -> Dictionary:
	return {
		"回合": int(float(battle_ctx.get("turn", 0.0))) if not battle_ctx.is_empty() else 0,
		"本回合已打出": cards_played_this_turn(), "现在能打": cards_playable_now(),
		"手牌": hand_count(), "候补": reserve_preview().size(),
		"牌库剩余": deck_remaining(), "气势": _气氛(),
		"本场已打出": (battle_ctx.get("已打出战术牌") as Array).size() if battle_ctx.get("已打出战术牌") is Array else 0,
	}

func _build_result_cache(内核: Dictionary) -> Dictionary:
	# ★ P0：`血比前` 用**开战那一刻**的快照（`_血比战前`，由 `start_*_battle()` / `finish_battle_and_settle()`
	#   在调内核之前抓），`血比后` 用结算之后的现值。绝不能在这里现取「前」——那时内核已经回完血了。
	var 前: Dictionary = _血比战前.duplicate() if not _血比战前.is_empty() else _名册血比()
	var 打牌: Array = []
	if not battle_ctx.is_empty() and battle_ctx.get("已打出战术牌") is Array:
		打牌 = (battle_ctx.get("已打出战术牌") as Array).duplicate()
	var 结算: Dictionary = 内核
	return {
		"胜": bool(结算.get("胜", false)), "结果": _战果文字(),
		"原因": str((battle_ctx.get("result") as Dictionary).get("原因", "")) if battle_ctx.get("result") is Dictionary else "",
		"回合数": int(float(battle_ctx.get("turn", 0.0))) if not battle_ctx.is_empty() else 0,
		"格类型": str(结算.get("格类型", "")), "通关": bool(run_state.status == "胜利") if run_state != null else false,
		"结束": bool(结算.get("结束", false)), "扣": int(结算.get("扣", 0)),
		"希望": int(结算.get("希望", 0)), "源碳": int(结算.get("源碳", 0)),
		"券": 结算.get("券", null), "藏品": 结算.get("藏品", null), "额外编制": 结算.get("额外编制", null),
		"零件": 结算.get("零件", null), "额外": 结算.get("额外", {}), "奖励档": str(结算.get("奖励档", "")),
		"带伤": int(结算.get("带伤", 0)), "倒下": int(结算.get("倒下", 0)),
		"回血": 结算.get("回血", {}), "名册回血前": 前, "本场战术牌": 打牌, "结算": 结算,
	}

func _refresh_modal() -> void:
	if run_state != null and not run_state.pending_card_picks.is_empty():
		modal = {"类型": "三选一", "数据": run_state.pending_card_picks.duplicate()}
		return
	if modal.has("类型") and modal["类型"] == "三选一":
		modal = {}
	if screen == "result":
		modal = {"类型": "结算", "数据": result_summary()}
		return
	if screen == "battle":
		# ★ 只报「现在一张都打不出来」（手牌空 / 全在冷却 / 气势不够）；**不是**「打满张数」（D-03）。
		modal = {"类型": "战斗", "数据": turn_card_summary()} if cards_playable_now() <= 0 else {}
		return
	if screen != "result":
		if modal.has("类型") and modal["类型"] == "结算":
			modal = {}
