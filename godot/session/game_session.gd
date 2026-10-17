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
##   6. ★ **补线记录（D-08）**：内核有「推进剂见底 → 追击战」这套机制
##      （`MapNavigator.exit_chase_pending` / `begin_exit_chase` / `after_chase_win`），
##      但 Godot 侧**从前一次都没调用过 `begin_exit_chase`**，`enter_current_node()` 里那个
##      `"追击"` 分支永远走不到（地图生成**从不产** `追击` 类型格）→ 推进剂在**非战斗、非出口**格上
##      见底就**永久卡死**（走不动、也没战斗格可进）。现已按封存 JS 接上：
##        · `92-肉鸽界面-1-大图与记录.js:315`：「**这一格结算完**就会触发追击战」；
##        · `80-界面-6-晋升零件与尾部.js:249-256` `追击战()`：`肉鸽战斗类型 = '追击'` → 打这一场；
##        · `90-肉鸽-3-开局与移动.js:192-198` `追击之后()`：`追击 = true`、`层推进剂修正 = -2` → `换层()`；
##        · `90-肉鸽-4-节点结算.js:399-403`（胜）/ `:420`（败）：**两条都**走 `追击之后()`；
##        · 口径 D（`:204-207`）：**只有「出口那一步」那次**才过守军闸（判据 = `s.exit_chase`，
##          由「站在出口格 + 推进剂 0」时 `begin_exit_chase` 置位）；**别处的追击战照旧能换层**。
##      接点：`move_to_cell` / `use_part` / `resolve_rest` / `leave_shop` / `resolve_event_choice`
##      在「这一格的事做完」之后，以及 `try_advance_floor()` 在出口格那一步（先置位再打）。
##      判据一律用内核的 `MapNavigator.exit_chase_pending(s)`，**不自写 `推进剂 <= 0`**。
##   8. ★ **纠错记录（D-10）**：D-08 把追击战接在 `move_to_cell()` 里 —— **时机早了**。
##      封存 JS `92-肉鸽界面-1-大图与记录.js:315` 的原文是「**这一格结算完**就会触发追击战」，
##      而 `move_to_cell()` 那一刻脚下这一格**还没结算**。后果很实：用**最后 1 点推进剂**落在
##      **作战 / 精英**这类战斗格上时，玩家打的是追击战，**那一格的节点战永远没打**
##      （追击战打赢就被赶到下一层，精英的藏品 / 掉落一起没）；`map_data["当前节点类型"]`
##      也被留成 `"追击"`。现已改成**受条件限定**（`_这一格要先结算吗(s)`）：
##        · **要先结算**（先不开，等这一格结算完）：`作战` / `精英` / `守军` / `侵蚀源` / `出口守军` /
##          `休整` / `黑市` / `事件` / `瞭望站` / `遗迹` / `隧道` / `招募站`；
##        · **当场开**（无可结算的东西）：`空` / 已经过的格 / 认不出来的类型。
##          ★ 这一条绝不能丢 —— 它正是 D-08 修掉的「0 推进剂 + 没东西可结算 = 走不动也打不了」的死锁。
##      接点相应变成三处：① `move_to_cell()` 只对「无可结算」的格当场开；
##      ② `enter_current_node()` 的非战斗分支统一走 `_收尾这一格(s)`；
##      ③ `finish_battle_and_settle()` 在**节点战**（格类型 ≠ `"追击"`）结算完之后补一次。
##      出口那一步（`try_advance_floor()` 的 `begin_exit_chase`）、追击战胜败都换层、
##      出口守军那道闸、`fight_chase_battle()` 公开口子**一个字都没动**。
##   9. 「源碳」在 `RunState` 里叫 `carbon`、to_dict() 里叫 `"源碳"`；本门面统一用 `run_state.carbon`。
class_name GameSession
extends RefCounted

## 单向数据流：命令改完状态 → 发一次 `changed` → UI 重画。
signal changed()
signal errored(msg: String)
## ★ 实时监视（2026-10-16 新增，**纯观测**）：每完成一个玩家动作就发一条完整记录
## （`{seq, kind:"action", action, args, result, state}`）。`boot.gd` 收到后原样转发给
## `tools/serve_site.mjs` 的 `POST /__ui_log`，落盘到 `.tools/smoke/live_actions.jsonl` +
## `.tools/smoke/live_state.json`。**只读、不改任何业务规则与返回值**。
signal action_recorded(entry: Dictionary)

const 存档文件名 := "user://save.json"
const 快速战斗种子偏移 := 8801
const 默认分队 := "混编"
## 实时监视：动作历史最多留这么多条（超了丢最老）。
const 动作历史上限 := 100
## ★ UX-1 第 6 项：`errors` 只增不减会跟着状态快照一起膨胀 —— 只留最近这么多条。
const 错误上限 := 50

## ---------------- 会话状态（UI 只读这些） ----------------
var run_state: RunState = null
var battle_ctx: Dictionary = {}
var screen: String = "menu"
var modal: Dictionary = {}
var last: Dictionary = {}
var errors: Array = []

## ---------------- ★ 战前编队确认态（2026-10-18 作者试玩反馈第 1 条） ----------------
## 走上战斗格 / 点「打追击战」**不直接开打**，而是先进 `"formation"` 屏把阵容摆好；
## 玩家点【确认编队 · 开始战斗】才真的进 `"battle"`。
##   · `pending_battle_confirm` = 现在是不是「战前编队确认」态（编队屏据此藏「回地图」、亮「开始战斗」）；
##   · `pending_battle_kind` = 这把要开的是哪种战斗：`"node"`（脚下这一格）或 `"chase"`（追击战）。
var pending_battle_confirm: bool = false
var pending_battle_kind: String = ""

## ---------------- ★ DECK-2 / DECK-3：单机牌组（阶段制）模式 ----------------
## `单机牌组模式` = **下一次开战要不要用单机牌组规则**（阶段制 / 单机战意 / 上下双排）。
##   · 默认 `false` —— 于是 `GameSession.new()` + `start_quick_battle(种子)` / `start_new_run(种子, 分队)`
##     这些**旧口径调用逐字不变**（既有 2000+ 项测试与黄金样例零改动）；
##   · 界面入口（`menu_view.gd` 的【快速测试战斗】/【开这一局】）在开战前调
##     `set_unit_deck_mode(true)` —— 玩家玩到的是新模式，测试走的是老模式；
##   · 与内核开关的关系：本标志只负责往 `选项.单机牌组` 里写一个 `true`，
##     真正的判据永远只有一处 —— `Params.单机牌组_开(battle_ctx)`。
var 单机牌组模式: bool = false
## ★ DECK-3：当前**选中**的我方机体键（空 = 还没选）。
##   开战时自动选格位 0 起第一台存活的我方；玩家点任意我方 `UnitCard` 换成那一台。
##   **只影响表现层取哪一台上排牌**，不影响内核（内核每台都能单独操作）。
var selected_unit_id: String = ""

## ★ 「当前这个动作为什么被拒」（空 = 这个动作做成了）。
##   与累积的 `errors` 分流：`errors` 是本局**全部**失败原因的流水（测试与监视侧读它），
##   这一个只代表**最后一个动作**——各视图的「上一次没做成：…」一律读它，
##   于是不会再把上一拍的陈旧原因挂在别的屏上误导玩家（作者试玩反馈第 1 条）。
var _当前错误: String = ""

## ---------------- 实时监视态（2026-10-16；**纯观测，不参与任何业务判据**） ----------------
## 已经记了多少个玩家动作（从 1 开始递增）。
var _action_seq: int = 0
## 最近 `动作历史上限` 条动作记录（`{seq, kind, action, args, result, state}`）；最老的先丢。
var action_history: Array = []
## 重入闸：`snapshot_for_monitor()` 只该在动作返回之后调一次，绝不允许自己套自己。
var _在看快照: bool = false

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
## ★ D-08：这一场战斗的**战斗格类型**（`"追击"` 与地图上的格类型无关 —— 追击战可能发生在任何一格的
##   结算之后，脚下那一格的类型还是原来的「空 / 事件 / 黑市…」）。结算时先用它，没有再退回脚下格类型。
var _本场格类型: String = ""

## ★ D-07 幂等闸：这一场是否**已经结算过**。`finish_battle_and_settle()` 靠它保证「同一场只结算一次」，
##   否则同一个 `battle_ctx` 可以原地无限重结算（每调一次再发一遍源碳 / 希望 / 藏品 / 经验，
##   `场次`/`胜场` 再 +1）。**每一处「开一场新战斗」都要把它复位**。
##   守的是标志、**不是清 `battle_ctx`** —— 结算屏还要用 ctx 画。
var _本场已结算: bool = false

## ★ 2026-10-18（作者试玩反馈第 3 条）：「同一格只结算一次」的**节点清单**。
##   键 = `"%d:%d" % [run_state.floor_num, run_state.current_node]`。
##   为什么必须有它：**休整**那一格从前可以连点 6 次刷属性（`resolve_rest` 无条件跑内核），
##   奇遇同理。现在 `_结算休整()` / `_结算奇遇()` 开头都查这张表 —— 结算过就直接拒绝。
##   每一处会话重置（`start_new_run` / `load_saved_run` / `return_to_menu`）都清空它。
var _已结算节点键: Dictionary = {}

# ==========================================================================================
# 一、开局与存档
# ==========================================================================================

## 开一局新肉鸽：`RosterManager.new_run` → 屏幕进 `"map"`。★ 实时监视：包一层（返回值逐字不变）。
func start_new_run(seed_val: int, squad: String = 默认分队) -> bool:
	return _record_action("start_new_run", {"seed_val": seed_val, "squad": squad}, _开始新局(seed_val, squad))

func _开始新局(seed_val: int, squad: String = 默认分队) -> bool:
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
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	# ★ DECK-4 接线（DECK-2 的同一处）：这一局开了单机牌组 → 在 `map_data["_rogue"]` 上留一个标记，
	#   `DeckBuilder.单机牌组模式()` 靠它把「战后三选一」自动收窄成**只出公有牌**
	#   （角色牌属于机体上排专属牌库，跟着晋升成长）。没开 = 一个字段都不加。
	if 单机牌组模式:
		RosterManager.特置(run_state, "单机牌组", true)
	_battle_options_cache = _build_battle_options()
	# ★ D-06 纠错：**开局不产生待选战术牌**。封存 JS 里 `R.待选战术牌` 只在
	#   招募（`90-肉鸽-5-晋升与通关.js:62`）与晋升（同文件 `:151`）两处被赋值；
	#   开局 / 移动 / 用零件 / 事件结算一处都不产生（那里曾错调 `refresh_card_offers()`）。
	last = {"行动": "开新局", "种子": seed_val, "分队": run_state.squad,
		"层": run_state.floor_num, "起源碳": run_state.carbon, "起希望": run_state.hope,
		"券": run_state.tickets.size(), "日志": _tail_logs(3)}
	_set_screen("map")
	return true

## 存当前这一局（只走 `SaveService`）。没有局 → false。★ 实时监视：包一层。
func save_current_run() -> bool:
	return _record_action("save_current_run", {}, _存当前局())

func _存当前局() -> bool:
	if run_state == null:
		_fail("没有进行中的局，存不了", {"ok": false})
		return false
	var ok := SaveService.save_to_file(run_state, 存档路径)
	last = {"行动": "存档", "成功": ok, "路径": 存档路径, "层": run_state.floor_num}
	if not ok:
		_fail("存档写不进去（%s）" % 存档路径, last)
	_emit()
	return ok

## 读存档并接管这一局。读不到 / 坏档 → false（且**不动**当前状态）。★ 实时监视：包一层。
func load_saved_run() -> bool:
	return _record_action("load_saved_run", {}, _读存档())

func _读存档() -> bool:
	var s := SaveService.load_from_file(存档路径)
	if s == null:
		_fail("没有可读的存档（%s）" % 存档路径, {"ok": false})
		return false
	run_state = s
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_quick_battle = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
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

# ==========================================================================================
# 一之二、给 UI 用的**状态读数**（纯读；表现层不许自己去摸 `battle_ctx` / `run_state` 的字段名）
#
#   为什么要有这几个口子（2026-10-16 作者试玩反馈的两条）：
#     ① 「点击结算没有反应」 —— 结算按钮的可用性原来写成 `not 打完`，见 `battle_view.gd`；
#        修法要读「现在到底在不在战斗里」，那就是 `in_battle()`；
#     ② 「选完小队没有招募页面 / 招募券卡住」 —— 要不要弹招募窗、要不要放行去编队，
#        判据全是「手上还有几张券 / 名册几台 / 一格走没走过」，就是下面这几个。
#   这几个一律 **纯读**：不改状态、不掷随机数、不 `_emit()`。
# ==========================================================================================

## 现在在不在战斗里（`battle_ctx` 非空）。
func in_battle() -> bool:
	return not battle_ctx.is_empty()

## 这一场是不是「快速测试战斗」（没有肉鸽地图可以回 → 结算屏的「继续」该回主菜单）。
func is_quick_battle() -> bool:
	return _quick_battle

## 手上的招募券张数（没有进行中的局 = 0）。
func ticket_count() -> int:
	return run_state.tickets.size() if run_state != null else 0

## 名册里的机体台数（没有进行中的局 = 0）。
func roster_count() -> int:
	return run_state.roster.size() if run_state != null else 0

## 这一局是不是「刚开局、一格都还没走过」（招募完就该去编队屏，而不是空转在大地图上）。
## 判据 = 清过的节点数 0 且打过的场次 0（都是内核自己的计数器，门面不另立口径）。
func 还没走过格() -> bool:
	if run_state == null:
		return false
	return run_state.nodes_cleared == 0 and run_state.battles_fought == 0

## ★ 手上还有没有**没决定**的招募券（要么招一台、要么按【放弃此券】）—— 纯读。
##   2026-10-18（作者试玩反馈第 2 条）：只要有它，大地图上点格子**不移动**，
##   而是先把招募弹窗弹出来把决定做完。
func 有未决的招募券() -> bool:
	return ticket_count() > 0

## 现在是不是「战前编队确认」态（编队屏据此藏「回地图」、亮【确认编队 · 开始战斗】）。
func 战前编队确认中() -> bool:
	return pending_battle_confirm

## ★ 「最后一个动作为什么没做成」（空 = 做成了）—— 各视图的「上一次没做成：…」一律读它。
##   纯读；与累积的 `errors` 分流（那一个照旧留着全部流水）。
func 当前动作错误() -> String:
	return _当前错误

## 这一格的「结算键」（`"层:格"`）——「同一格只结算一次」那张表的键。
## 用 `node_id`（脚下这一格的事实），不依赖 `map_data["当前节点类型"]`（那是可能过期的旧值）。
func 当前节点结算键() -> String:
	if run_state == null:
		return ""
	return "%d:%d" % [run_state.floor_num, run_state.node_id]

## 这一格（休整 / 奇遇…）是不是**已经结算过**了（纯读 `_已结算节点键`）。
func 节点已结算过() -> bool:
	var 键 := 当前节点结算键()
	return not 键.is_empty() and _已结算节点键.has(键)

## 回主菜单：把这一局留在存档里（有局才存），会话清空。★ 实时监视：包一层（返回值仍是 void）。
## ★ 时序：把**重置之后**的快照记下来，因为「回主菜单」这一步的结果局面就是空会话
##   （和 `_record_action` 的通用口径「动作做完之后取快照」一致）。
func return_to_menu() -> void:
	_回主菜单()
	_record_action("return_to_menu", {}, null)

func _回主菜单() -> void:
	if run_state != null and run_state.status == "进行中":
		SaveService.save_to_file(run_state, 存档路径)
	run_state = null
	battle_ctx = {}
	_result_cache = {}
	_血比战前 = {}
	_本场已结算 = false
	_本场格类型 = ""
	_node_result = {}
	_unit_switches = {}
	_battle_options_cache = {}
	_quick_battle = false
	_已结算节点键 = {}
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	modal = {}
	_set_screen("menu")

## ==========================================================================================
## ★ 一之二之三、UX-1 第 1 项（2026-10-19）：**战后回大地图**要收口在这里
##
##   作者试玩反馈第 2 条原文：「走地图的时候也需要可以打开查看编队」——实测根因是
##   结算屏点「继续（回大地图）」只发了一个切屏信号，**`battle_ctx` 一直没清**：
##   回到大地图后 `in_battle()` 仍为 `true` → 顶栏把「编队 / 招募 / 牌库」永久锁成灰的。
##
##   所以「战后回大地图」这件事的**唯一实现**就是本方法（视图只发信号，不自己改状态）：
##     · 这一场已经结算过（`_本场已结算`）→ 清掉 `battle_ctx`，把 `_本场已结算` 复位，
##       顺手把「战前编队确认」态与「本场格类型」一起复位；
##     · 打一半（`battle_ctx` 非空且还没结算）→ **拒绝**，绝不悄悄丢掉一场没结算的战斗
##       （那就是孤儿战斗死锁）；
##     · 最后 `_set_screen("map")` —— 于是回到大地图（非 `pending_battle_confirm`）时
##       `session.in_battle() == false`，顶栏「编队 / 招募 / 牌库」随时可点。
##   ★ 实时监视：包一层（返回值就是下面这个字典）。
## ==========================================================================================
func return_to_map_after_battle() -> Dictionary:
	return _record_action("return_to_map_after_battle", {}, _回大地图清战斗())

func _回大地图清战斗() -> Dictionary:
	if not battle_ctx.is_empty() and not _本场已结算:
		return _fail("这一场还没结算完（先在结算屏点「结算这一场」）", {"ok": false})
	var 清过 := not battle_ctx.is_empty()
	battle_ctx = {}
	_本场已结算 = false
	_本场格类型 = ""
	pending_battle_confirm = false
	pending_battle_kind = ""
	selected_unit_id = ""
	last = {"行动": "回大地图", "清了战斗上下文": 清过, "屏幕": "map"}
	_set_screen("map")
	return {"ok": true, "清了战斗上下文": 清过, "屏幕": str(screen)}

# ==========================================================================================
# 一之三、★ 实时监视（2026-10-16 新增）：全动作记录 + 完整局面快照
#
#   为什么要有这一块（作者要「主会话随时能看到作者在本地网页里的每一步操作、参数、
#   返回结果与完整局面」）：门面是**玩家命令的唯一入口**，所以「这一步点了什么、内核回了什么、
#   现在局面长什么样」这三件事只有在这里才能一次性拿全。
#
#   纪律（一个字都不许破）：
#     · **纯观测** —— 不参与任何业务判据、不掷随机数、不改任何状态、**不改任何方法的返回值**；
#     · `snapshot_for_monitor()` 走 `_need_run()` / `_data_ready()`（数据只在没装时才装一次），
#       其余全是读现有字段与既有纯读口子（`unit_view` / `hand_status_all` / `battle_log_lines`）；
#     · 动作记录一律**包一层**：`Xxx()`（新）= 记一条 + 原样返回 `_Xxx()`（原实现）的值，
#       于是「返回值逐字不变」这件事是**结构上成立**的，不靠人手核对每条 return。
# ==========================================================================================

## 现在这一局的完整可读快照（**纯读**：不掷随机数、不改状态、不发信号）。
## 返回字典的字段（顶层）：`screen` / `modal` / `is_quick_battle` / `in_battle` / `errors`；
## 有局时另有：`seed` / `squad` / `status` / `floor` / `pos` / `propellant` / `hope` / `carbon` /
## `base_hp` / `commander_lv` / `deploy_cap` / `tickets` / `pending_card_picks` / `roster` /
## `lineup` / `relics` / `parts`；
## 在战斗里另有：`turn` / `result` / `morale` / `policy` / `playable_now` / `hand` /
## `reserve_count` / `allies` / `enemies` / `recent_battle_log`。
func snapshot_for_monitor() -> Dictionary:
	# 数据只在真没装过时才装（`DataLoader.install` 内部幂等）；这里是为了「全新会话直接读快照」也能用。
	_data_ready()
	if _在看快照:
		return {"screen": screen, "modal": "", "is_quick_battle": _quick_battle,
			"in_battle": in_battle(), "errors": [], "重入": true}
	_在看快照 = true
	var 快 := {
		"screen": screen,
		"modal": str(modal.get("类型", "")),
		"is_quick_battle": _quick_battle,
		"in_battle": in_battle(),
		# ★ 上限 20 条：`errors` 是**累积**数组，长局会很长，快照只需要「最近为什么被拒」。
		"errors": errors.slice(maxi(0, errors.size() - 20)).duplicate(),
	}
	var s := run_state
	if s != null:
		快["seed"] = s.seed_val
		快["squad"] = s.squad
		快["status"] = s.status
		快["floor"] = s.floor_num
		快["pos"] = s.node_id
		快["propellant"] = "%d/%d" % [s.propellant, s.propellant_max]
		快["hope"] = s.hope
		快["carbon"] = s.carbon
		快["base_hp"] = s.base_hp
		快["commander_lv"] = s.level
		快["deploy_cap"] = RosterManager.deploy_limit(s)
		快["tickets"] = _监控券表(s)
		快["pending_card_picks"] = _监控待选牌(s)
		快["roster"] = _监控名册(s)
		快["lineup"] = _监控编队(s)
		快["relics"] = _监控藏品(s)
		快["parts"] = _监控零件(s)
	if not battle_ctx.is_empty():
		var 手状态 := hand_status_all()
		var 名册: Array = []
		var 敌: Array = []
		_收在场(名册, "allies")
		_收在场(敌, "enemies")
		快["turn"] = int(float(battle_ctx.get("turn", 0.0)))
		快["result"] = 战果文字()
		# ★ 气势是**单条全局值**（`ctx.气势`，只有我方用；`unit_view` 里敌方的气势恒报 0）——
		#   所以这里照实报：我方 = 那条真值，敌方 = 0（不自己编一个「敌方气势」）。
		快["morale"] = {"我方": _气氛(), "敌方": 0.0}
		快["policy"] = str((battle_ctx.get("方针") as Dictionary).get("类型", "")) if battle_ctx.get("方针") is Dictionary else ""
		快["playable_now"] = cards_playable_now()
		快["hand"] = 手状态.map(func(c): return "%s:%s(%s)" % [str(c.get("id", "")), str(c.get("名", "")), str(c.get("原因", ""))])
		快["reserve_count"] = reserve_preview().size()
		快["allies"] = 名册
		快["enemies"] = 敌
		快["recent_battle_log"] = battle_log_lines(8)
	_在看快照 = false
	return 快

## 待决定招募券：每张的 `id` / `名` / `类型`。
func _监控券表(s: RunState) -> Array:
	var out: Array = []
	for 券 in s.tickets:
		if 券 is Dictionary:
			out.append({"id": int(券.get("id", 0)), "名": RosterManager.券名(券), "类型": str(券.get("类", ""))})
		else:
			out.append({"id": 0, "名": str(券), "类型": ""})
	return out

## 待三选一：次数（候补张数）+ 当前 3 张候选**牌名**。
func _监控待选牌(s: RunState) -> Dictionary:
	var 名们: Array = []
	for id in s.pending_card_picks:
		var c := DeckBuilder.找到(str(id))
		名们.append(str(c.get("名", id)))
	return {"次数": s.pending_card_picks.size(), "候选": 名们}

## 名册简述：`键(Lv等级 HP百分比%)`。
func _监控名册(s: RunState) -> Array:
	var out: Array = []
	for k in s.roster.keys():
		var 键 := str(k)
		out.append("%s(Lv%d HP%d%%)" % [键, s.get_unit_level(键),
			int(JsCompat.js_round(s.get_unit_hp_ratio(键) * 100.0))])
	return out

## 当前编队上阵格位映射（`位号 -> 机体键(名)`）。
func _监控编队(s: RunState) -> Dictionary:
	var out := {}
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var 键 := str(x.get("key", ""))
		if 键.is_empty():
			continue
		out[_条位号(x)] = "%s(%s)" % [键, _监控名(键)]
	return out

## 藏品数 + 名字列表。
func _监控藏品(s: RunState) -> Dictionary:
	var 名们: Array = []
	for id in s.relics:
		名们.append(RelicSystem.名(str(id)))
	return {"数": s.relics.size(), "名": 名们}

## 零件数 + 名字列表（下标也一起给，UI 按 `parts` 下标调 `use_part`）。
func _监控零件(s: RunState) -> Dictionary:
	var 名们: Array = []
	for i in s.parts.size():
		var 键 := PartSystem.part_key(s.parts[i])
		var 信 := PartSystem.part_info(键)
		名们.append("#%d %s" % [i, str(信.get("名", 键)) if not 信.is_empty() else 键])
	return {"数": s.parts.size(), "名": 名们}

## 把 `battle_ctx` 里某一阵营的在场单位收成 `位号:名:HP/最大HP` 文本行。
func _收在场(out: Array, 池名: String) -> void:
	var 池: Variant = battle_ctx.get(池名)
	if not (池 is Array):
		return
	for u in (池 as Array):
		if not (u is Dictionary):
			continue
		out.append("%s:%s:%d/%d" % [Fm.位名(float(u.get("slot", 0.0))),
			str(u.get("name", u.get("key", ""))),
			int(JsCompat.js_round(float(u.get("hp", 0.0)))), int(JsCompat.js_round(float(u.get("maxHp", 0.0))))])

## 机体键 → 显示名（读纯目录；读不到就把键原样给）。
func _监控名(键: String) -> String:
	if 键.is_empty():
		return ""
	var 模 := RosterManager.模板(键)
	return str(模.get("名", 键))

## ★ 记一个玩家动作（**内部**）：序号 +1 → 组装 entry → 推历史（超 `动作历史上限` 丢最老）
## → 发 `action_recorded` → **原样返回 `res`**（调用方一律 `return _record_action(...)`）。
##
## ★ 2026-10-18（作者试玩反馈第 1 条「陈旧错误串」）：**每执行一个新的公开动作，先清掉
##   「上一个动作留下的那条原因」**（`_当前错误 = ""`）—— 于是各视图的「上一次没做成：…」
##   只会是**当前这个动作**的原因，不会再出现「点了脚下那一格留下的『已经在那一格』
##   一直挂在编队屏上」这种误导。
##   ★ `errors` 这个累积数组**一个字都没动**（`test_session_flow.gd` 的「错误路径都记进了
##     errors（≥3 条）」照旧成立）—— 变的只是「视图该显示哪一条」。
func _record_action(act: String, args: Dictionary, res: Variant) -> Variant:
	_action_seq += 1
	_当前错误 = ""
	var entry := {
		"seq": _action_seq, "kind": "action", "action": act,
		"args": args, "result": res, "state": snapshot_for_monitor(),
	}
	action_history.append(entry)
	while action_history.size() > 动作历史上限:
		action_history.remove_at(0)
	action_recorded.emit(entry)
	return res

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
## ★ 实时监视：包一层（返回值逐字不变）。**封存 JS / 门面里的原方法名 `move_to_cell` 一个字没改**；
##   `move_to` 是**同名别名**（作者的监视清单里写的是这个名字，两个都能调）。
func move_to_cell(cell_id: int) -> Dictionary:
	return _record_action("move_to_cell", {"cell_id": cell_id}, _走一格(cell_id))

func move_to(cell_id: int) -> Dictionary:
	return move_to_cell(cell_id)

func _走一格(cell_id: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有大地图", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	# ★ UX-1 第 6 项（2026-10-19）：点在**自己脚下这一格**上、而且这一格没有要结算的东西
	#   → 静默返回（`noop = true`），**绝不调 `_fail()`**。
	#   从前这一下会走内核的「已经在那一格」被拒，然后把一句没用的错误永久堆进 `session.errors`。
	if cell_id == int(s.node_id) and not _这一格要先结算吗(s):
		return {"ok": false, "why": "已经在当前所在格", "noop": true, "格": cell_id}
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
	# ★ D-08：走完这一格 → 推进剂见底就开追击战（站的是出口格时留给 `try_advance_floor()`）。
	# ★ D-10 纠错（对齐封存 JS `92-肉鸽界面-1-大图与记录.js:315`「**这一格结算完**就会触发追击战」）：
	#   落脚这一格**自己还有东西要结算**（战斗格 / 黑市 / 事件 / 休息…）时，这里**先不开** ——
	#   否则「用最后 1 点推进剂落在作战 / 精英格上」会变成：先打追击战、那一格的节点战永远没打
	#   （追击战打赢就被赶到下一层，精英的藏品 / 掉落一起没）。
	#   那条路改由「结算这一格的那一处」接（`enter_current_node()` / `finish_battle_and_settle()`）。
	#   ★ 无可结算的格（空 / 已过 / 认不出来的类型）**必须当场开**：不然「0 推进剂 + 没东西可结算」
	#     就是走不动也打不了的**死锁**（D-08 修的就是它）。
	if not _这一格要先结算吗(s):
		if _接追击战(s):
			return last
	_set_screen("map")
	return r

## 用一件零件（默认消耗 1 点推进剂；`spring` / `jet` / `bagua` 免推进剂）。
## `part_idx` = `run_state.parts` 的下标；`target_cell < 0` 只对 `bagua`（小八界）有意义 = 一键随机传送。
## ★ 实时监视：包一层。
func use_part(part_idx: int, target_cell: int = -1) -> Dictionary:
	return _record_action("use_part", {"part_idx": part_idx, "target_cell": target_cell}, _用零件(part_idx, target_cell))

## ★ 任务单 PART-2 · 4：按「格」使用（与 `use_part` 同一个内核；名字对齐任务单 / UI 新接口）。
## `cell_id < 0` → 交给内核按落点规则处理（`bagua` = 一键随机抽取，其余零件会被内核拒绝）。
func use_part_on_cell(idx: int, cell_id: int = -1) -> Dictionary:
	return _record_action("use_part_on_cell", {"part_idx": idx, "cell_id": cell_id}, _用零件(idx, cell_id))

## 零件位移内核：落点 → 同步「当前节点类型」→ 揭雾 → 推进剂见底接追击战。
## ★ 与普通移动落点**完全一致**（不自动结算落点节点）：`需要进入 = true` 时由视图按老路
##   走 `_进入脚下()` / `enter_current_node()`，战斗格仍先进战前编队确认屏。
## ★ D-06：用零件**不产生待选战术牌**（JS 只有招募 / 晋升两处产生）—— 这条一个字没改。
func _用零件(part_idx: int, target_cell: int) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if part_idx < 0 or part_idx >= s.parts.size():
		return _fail("没有这件零件（下标 %d，手上有 %d 件）" % [part_idx, s.parts.size()], {"ok": false})
	var 前推进 := int(s.propellant)
	var 前格 := int(s.node_id)
	var r := PartSystem.use_part(s, part_idx, target_cell)
	if not bool(r.get("ok", false)):
		var 因 := str(r.get("why", r.get("为什么", "用不了")))
		return _fail(因 if not 因.is_empty() else "用不了", {"ok": false, "why": 因})
	# ★ bagua 的落点由内核随机抽出后回填在 `target`；其余零件就是传进来的那一格。
	var 落 := int(r.get("target", r.get("到", s.node_id)))
	var 脚 := s.cell_at(落)
	var 脚类型 := str(脚.get("类型", ""))
	if 脚类型.is_empty():
		脚类型 = "空"
	# ★ 与 `_走一格()` 同款：落脚之后把「当前节点类型」同步成脚下这一格的真实类型。
	s.map_data["当前节点类型"] = 脚类型
	_battle_options_cache = _build_battle_options()
	var 需进 := _这一格要先结算吗(s)
	r["到"] = 落
	r["target"] = 落
	r["类型"] = 脚类型
	r["从"] = 前格
	r["需要进入"] = 需进
	r["推进剂前"] = 前推进
	r["推进剂后"] = s.propellant
	last = {"行动": "用零件", "零件": str(r.get("零件", "")), "到": 落, "落点": 落, "类型": 脚类型,
		"免费": bool(r.get("免费", false)), "推进剂前": 前推进, "推进剂后": s.propellant,
		"需要进入": 需进, "额外": r.get("额外", {}), "零件剩": s.parts.size(), "日志": _tail_logs(3)}
	# ★ D-08 / D-10：推进剂见底 → 这一格没东西要结算就当场开追击战；有东西要结算则由节点
	#   结算那一处（`enter_current_node()` 的 `_收尾这一格()`）接。
	if _接追击战(s):
		return last
	_set_screen("map")
	return r

# ==========================================================================================
# ★ D-08：推进剂见底 → 追击战（此前 Godot 侧**完全没接线**，会在非战斗格上永久卡死）
#   封存 JS 口径（三处原文）：
#     · `92-肉鸽界面-1-大图与记录.js:315`：「推进剂已经用光：**这一格结算完**就会触发追击战」；
#     · `80-界面-6-晋升零件与尾部.js:249-256` 的 `追击战()`：`肉鸽战斗类型 = '追击'` → 打这一场；
#     · `90-肉鸽-3-开局与移动.js:192-198` 的 `追击之后()`：`追击 = true`、`层推进剂修正 = -2` → `换层()`；
#     · `90-肉鸽-4-节点结算.js:399-403`（胜）/ `:420`（败）：**两条都**走 `追击之后()`；
#     · `:204-207` 明写「在**别处**把推进剂用光触发的追击战**本来就能换层**」，只有「出口那一步」那次
#       才过守军闸（判据 = `R.出口追击`，由 `界面.前进()` 在「脚下是出口格 + 推进剂 0」时置位）。
# ==========================================================================================

## ★ D-10（对齐封存 JS `92-肉鸽界面-1-大图与记录.js:315`）：「**这一格结算完**才会触发追击战」。
##   所以「推进剂见底」这一下要分两种时机：
##     · **这一格自己还有东西要结算**（作战 / 精英 / 守军 / 侵蚀源 / 出口守军 / 休整 / 黑市 /
##       事件 / 瞭望站 / 遗迹 / 隧道 / 招募站）→ **先别开追击战**，等这一格结算完由那一处接
##       （`enter_current_node()` 的收尾 / `finish_battle_and_settle()` 的节点战之后）；
##     · **这一格无可结算的东西**（空 / 已经过 / 认不出来的类型）→ **当场开**。
##       ★ 这一条绝不能丢：它正是 D-08 修掉的「0 推进剂 + 站在没有节点面板的格子上 =
##         走不动也打不了」的**死锁**。
func _这一格要先结算吗(s: RunState) -> bool:
	if s == null or s.map_data.is_empty():
		return false
	return _要先结算的类型.has(_脚下类型(s))

## D-10 的判据表（只有「节点类型」这一项输入 —— 不看推进剂、不看 rng）。
## 出口两型（出口尽头 / 出口小径）**不在表里也不在这里开**：那一步走 `try_advance_floor()` 的
## `_开追击战(s, true)`（先 `begin_exit_chase` 置位，出口守军那道闸才认得出它）。
const _要先结算的类型 := [
	"作战", "精英", "守军", "侵蚀源", "出口守军",
	"休整", "黑市", "事件", "瞭望站", "遗迹", "隧道", "招募站",
]

## 这一格结算完要不要开一场追击战？要 → 开战并返回 true（屏幕已进 `"battle"`）。
## 判据只用内核的 `MapNavigator.exit_chase_pending(s)`（= `推进剂 <= 0 and not chased`），**不自造**。
## 站的是出口格时**不在这里开** —— 出口那一步走在 `try_advance_floor()` 里（先 `begin_exit_chase` 置位）。
##
## ★ D-10 的关键参数 `已结算`（**它区分了两个调用时机，缺了它整条线会自锁**）：
##   · `false`（默认）= 「**走进去的那一下**」（`move_to_cell()`）：这一格自己还有东西要结算时
##     **不许开**（否则节点战被顶掉、`map_data["当前节点类型"]` 被留成 `"追击"`）；
##   · `true` = 「**这一格的事已经做完了**」（`enter_current_node()` 的 `_收尾这一格()` /
##     非战斗节点自己的结算之后 / `finish_battle_and_settle()` 的节点战之后）：这时**必须**开
##     —— 不再看「要不要先结算」（那件事刚刚做完了），否则就是 D-08 要修的死锁。
func _接追击战(s: RunState, 已结算: bool = false) -> bool:
	if not MapNavigator.exit_chase_pending(s):
		return false
	if MapGenerator.exit_kinds().has(s.current_type()):
		return false
	if not 已结算 and _这一格要先结算吗(s):
		return false
	return _开追击战(s, false)

## ★ D-10：非战斗节点的**统一收尾** —— 黑市 / 事件 / 瞭望站 / 遗迹 / 隧道 / 空 / 招募站
##   这些分支把这一格的事做完之后都走它：它内部接 `_接追击战(s, true)`。
##   返回 true = 已经在打追击战（屏幕已进 `"battle"`，调用方**别再 `_set_screen("map")`** ——
##   那样会把刚开的那一场顶掉，D-08 段 9b 取证的那条老路）。
func _收尾这一格(s: RunState) -> bool:
	return _接追击战(s, true)

## 真的开一场追击战：`NodeResolver.开战(state, 条目, "追击")`，并把这一场的格类型记成 `"追击"`
## （`finish_battle_and_settle()` 靠它走 `after_chase_win`）。`在出口` = 这一次是不是「出口那一步」的
## 那一次追击战（是 → 先 `begin_exit_chase` 置位，守军闸才认得它）。
## ★ 公开给 UI：大地图在「推进剂见底、没路可走」时给一个「打追击战」的按钮就走这里。
## ★ 实时监视：包一层；`trigger_pursuit_battle` 是**同名别名**（作者监视清单里的名字）。
func fight_chase_battle() -> bool:
	return _record_action("fight_chase_battle", {}, _打追击战())

func trigger_pursuit_battle() -> bool:
	return fight_chase_battle()

func _打追击战() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	# ★ 2026-10-18（作者试玩反馈第 2 条）：手上还有没决定的招募券 → 不许**手动**开新战斗，
	#   先把券处理掉（`_refresh_modal()` 会在下一次切屏时把「招募」弹出来）。
	#   ★ 注意：这道闸只在**玩家主动点**的那两条路上（`_打追击战()` / `_开节点战()`），
	#     不放在 `_开追击战()` 里 —— 那个是门面自己的「推进剂见底自动接一场」，
	#     拦了会把 `move_to_cell` / `_收尾这一格` 那条死锁修复线一起顶掉（D-08 / D-10）。
	if 有未决的招募券():
		_fail("手上还有 %d 张招募券没决定（先招募一台，或者按【放弃此券】）" % ticket_count(), {"ok": false})
		return false
	if not MapNavigator.exit_chase_pending(s):
		_fail("现在不是追击战的时机（推进剂 %d、本层已追击过 = %s）" % [s.propellant, str(s.chased)], {"ok": false})
		return false
	return _开追击战(s, s.exit_chase)

func _开追击战(s: RunState, 在出口: bool) -> bool:
	if NodeResolver.我方编成(s).is_empty():
		return false
	if 在出口:
		MapNavigator.begin_exit_chase(s)
	var 类型 := NodeResolver.战斗类型Of(s, "追击")
	var rng := Mulberry32.new(NodeResolver.编成种子(s, s.floor_num))
	var 详情 := NodeResolver.抽编成兜底(s.floor_num, 类型, rng)
	if 详情.is_empty() or not (详情.get("条目") is Dictionary):
		_fail("抽不到第 %d 层「追击」的编成" % s.floor_num, {"ok": false})
		return false
	s.map_data["本场兜底"] = {"层": s.floor_num, "格": s.node_id, "到": str(详情.get("类型", 类型))} if 详情.get("兜底") != null else null
	# ★ 让 `finish_battle_and_settle()` 认出这是一场追击战（它按 `_脚下类型(s)` 决定后处理）。
	s.map_data["当前节点类型"] = "追击"
	_本场格类型 = "追击"
	_battle_options_cache = _build_battle_options()
	var ctx := NodeResolver.开战(s, 详情["条目"], "追击", _附加战斗选项())
	if ctx.is_empty():
		_fail("追击战：战斗内核没有给出 ctx", {"ok": false})
		return false
	_quick_battle = false
	_本场已结算 = false
	_血比战前 = _名册血比()
	battle_ctx = ctx
	_unit_switches = 表(ctx, "选项")
	_result_cache = {}
	selected_unit_id = ""
	_选中默认机体()
	last = {"行动": "追击战", "格类型": "追击", "编成类型": str(详情.get("类型", 类型)),
		"出口那一步": 在出口, "推进剂": s.propellant, "已追击过": s.chased,
		"敌方": (ctx.get("enemies") as Array).size(), "我方": (ctx.get("allies") as Array).size(),
		"手牌": hand_count(), "候补": reserve_preview().size(), "日志": battle_log_lines(3)}
	_set_screen("battle")
	return true

## 走进当前格：战斗节点 → 开战（屏幕进 `"battle"`）；其余节点 → 各自结算（留在 `"map"`）。
## ★ 实时监视：包一层（返回值逐字不变）。
func enter_current_node() -> Dictionary:
	return _record_action("enter_current_node", {}, _进当前格())

func _进当前格() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	var 类型 := _脚下类型(s)
	match 类型:
		"作战", "精英", "守军", "侵蚀源", "出口守军", "追击":
			# ★ 调**内部**实现：这一趟的「动作」由 `enter_current_node` 那一条记录代表，
			#   不再多记一条 `start_node_battle`（同一次点击只留一条，便于监视侧读）。
			_开节点战()
			return last
		"休整":
			return _结算休整("耐久")
		"黑市":
			_node_result = {"ok": true, "节点": "黑市", "货": NodeResolver.黑市货(s)}
			last = {"行动": "进黑市", "货": _node_result["货"], "源碳": s.carbon, "日志": _tail_logs(2)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"事件":
			_node_result = {"ok": true, "节点": "事件", "事件": NodeResolver.当前事件(s), "选项": current_event_choices()}
			last = {"行动": "进事件", "事件": str(_node_result["事件"].get("名", "")), "日志": _tail_logs(2)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"瞭望站":
			_node_result = NodeResolver.结算瞭望站(s, "登高")
			_node_result["节点"] = "瞭望站"
			last = {"行动": "瞭望站", "结果": _node_result, "日志": _tail_logs(3)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"遗迹":
			_node_result = NodeResolver.结算遗迹(s, "藤蔓")
			_node_result["节点"] = "遗迹"
			last = {"行动": "遗迹", "结果": _node_result, "日志": _tail_logs(3)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"隧道":
			_node_result = NodeResolver.结算隧道(s)
			_node_result["节点"] = "隧道"
			last = {"行动": "隧道", "结果": _node_result, "从": s.node_id, "日志": _tail_logs(3)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"空":
			NodeResolver.清空格(s)
			_node_result = {"ok": true, "节点": "空", "文本": "林间空地：落脚休整片刻，未遭遇敌情。"}
			last = {"行动": "空格", "结果": _node_result, "日志": _tail_logs(2)}
			# ★ D-08 / D-10：这一格的事做完了 → 推进剂见底就追击战（不然玩家在这儿无路可走）。
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"招募站":
			var 领 := RosterManager.招募站领券(s)
			_node_result = {"ok": bool(领.get("ok", false)), "节点": "招募站", "券": 领.get("券", null),
				"券名": str(领.get("券名", "")), "重复": bool(领.get("重复", false))}
			last = {"行动": "招募站", "结果": _node_result, "券数": s.tickets.size(), "日志": _tail_logs(2)}
			if _收尾这一格(s):
				return _node_result
			_set_screen("map")
			return _node_result
		"出口尽头", "出口小径":
			return _换层()
	# ★ D-08 兜底：这一格没有「进去就结算」的东西时，也检查一次**追击战** ——
	#   否则「推进剂 0 + 站在没有节点面板的格子上」会让玩家**无路可走**（走不动、也没东西可点）。
	#   ★ D-10 之后正常路径上「推进剂见底」那一下分两种时机：无可结算的格在 `move_to_cell()` 里就接了，
	#     有东西可结算的格由上面各分支的 `_收尾这一格()` 接。走到这里 = 这一格**没进任何分支**
	#     （没有可结算的东西），所以传 `true`（不走 D-10 那道闸）。
	if _接追击战(s, true):
		return last
	return _fail("这一格（%s）没有可以直接进去的东西" % 类型, {"ok": false, "类型": 类型})

## 走出口 / 换层（内核 `MapNavigator.resolve_exit`）。★ 实时监视：包一层（返回值逐字不变）。
func try_advance_floor() -> Dictionary:
	return _record_action("try_advance_floor", {}, _换层())

## ★ 同名别名：作者监视清单里的 `advance_floor`。
func advance_floor() -> Dictionary:
	return try_advance_floor()

func _换层() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	if not s.pending_card_picks.is_empty():
		return _fail("还有 %d 张战术牌没选（先选完再换层）" % s.pending_card_picks.size(), {"ok": false})
	# ★ D-08（口径 D，照 JS `80-界面-6:211-226` 的 `前进()`）：站在**出口格**上、推进剂见底、本层还没被追击过
	#   → 先在**出口这一格**打一场追击战（先 `begin_exit_chase` 置位，守军闸才认得出「出口那一步」这一次）；
	#   打赢 / 打输都由 `finish_battle_and_settle()` 走 `after_chase_win` → 换层（守军没清则被记进「待换层」）。
	#   JS 同款：`if (R.推进剂 <= 0 && !R.追击) { R.出口追击 = true; …打这一场(); if (层变了) return; }`
	if MapNavigator.exit_chase_pending(s) and MapGenerator.exit_kinds().has(s.current_type()):
		if _开追击战(s, true):
			return last
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
## 手上没有对得上的券时**明确拒绝**并说明原因，绝不静默失败。★ 实时监视：包一层。
func recruit_unit(unit_key: String, ticket_idx: int = -1) -> Dictionary:
	return _record_action("recruit_unit", {"unit_key": unit_key, "ticket_idx": ticket_idx}, _招募(unit_key, ticket_idx))

func _招募(unit_key: String, ticket_idx: int = -1) -> Dictionary:
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

## ★ **丢弃 / 跳过一张招募券**（对齐封存 JS `92-肉鸽界面.js` 的「丢弃这张券」按钮，
##   内核 = `RosterManager.丢券`：只写一条日志，不退不换）。
##
##   为什么必须有这个口子（2026-10-16 作者试玩反馈）：招募券是「必须做出决定」的东西 ——
##   候选机体全都不想要的时候，玩家原来只能**卡在招募窗里**（关不掉、也走不了），
##   这就是「出现招募券要求做出决定才能进入下一个选择」那条反馈的根源。
##   现在有两条决定：① 招募一台；② 明确放弃这张券。
## ★ 实时监视：包一层（返回值逐字不变）。
func discard_ticket(ticket_idx: int = 0) -> Dictionary:
	return _record_action("discard_ticket", {"ticket_idx": ticket_idx}, _丢券(ticket_idx))

func _丢券(ticket_idx: int = 0) -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.tickets.is_empty():
		return _fail("手上没有招募券可以放弃", {"ok": false, "券": 0})
	var 下标 := ticket_idx
	if 下标 < 0 or 下标 >= s.tickets.size():
		下标 = 0
	var 券前 := s.tickets.size()
	var 名 := RosterManager.券名(s.tickets[下标])
	var r := RosterManager.丢券(s, 下标)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "丢不了")), {"ok": false, "券": 券前})
	_battle_options_cache = _build_battle_options()
	last = {"行动": "丢券", "券名": 名, "下标": 下标, "券前": 券前, "券后": s.tickets.size(),
		"名册": s.roster.size(), "日志": _tail_logs(3)}
	_refresh_modal()
	_emit()
	return r

## ★ 实时监视：包一层（返回值逐字不变）。
func promote_unit(unit_key: String) -> Dictionary:
	return _record_action("promote_unit", {"unit_key": unit_key}, _晋升(unit_key))

func _晋升(unit_key: String) -> Dictionary:
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
## ★ 实时监视：包一层（返回值逐字不变）。
func pick_tactical_card(card_id: String) -> bool:
	return _record_action("pick_tactical_card", {"card_id": card_id}, _选战术牌(card_id))

func _选战术牌(card_id: String) -> bool:
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
## ★ 实时监视：包一层（**记录不改它的行为**；它本身仍是纯读口子）。
func refresh_card_offers(unit_key: String = "") -> Array:
	return _record_action("refresh_card_offers", {"unit_key": unit_key}, _刷新候选(unit_key))

func _刷新候选(unit_key: String = "") -> Array:
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
	# ★ UX-1 第 2 项：**读之前先过一遍唯一性守卫**（同一台最多 1 格、同一格位最多 1 台）。
	# ★ UX-4：同一道守卫现在顺手把 `slot` 规范成明确位号，所以**编队屏看到的站位
	#   与 `NodeResolver.我方编成()` 进战斗用的站位是同一个口径**。
	_清理重复占格(s)
	var 占位 := {}
	if s != null:
		for x in s.lineup:
			if x is Dictionary:
				占位[str(x.get("key"))] = _条位号(x)
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

## ★ UX-4：**进编队屏 / 进战前编队确认时先调一次** —— 把旧档里 `slot == ""` / 位名 /
##   纯字符串的条目都补成明确位号（= 编队屏将要显示的站位，也 = 进战斗后真正站的站位）。
## 返回「真的改了名单」= true（幂等：已经规范过 / 玩家摆好的格位一个都不动）。
func normalize_lineup_slots() -> bool:
	_data_ready()
	return _规范编队槽位(run_state)

## `normalize_lineup_slots()` 的中文别名（作者监视清单里的名字）。
func 规范编队槽位() -> bool:
	return normalize_lineup_slots()

## ★ UX-4：玩家**亲手动过编队** → 记一笔（`map_data.lineup_customized = true`）。
## 有了这个标记，哪怕名单上的机体全倒了 / 槽位写法怪，进战斗也**只按这份名单出战**，
## 绝不会再从名册里把玩家特意下阵的机体补回来（反馈第 1 条的另一半）。
func _标记编队已调整(s: RunState) -> void:
	if s == null:
		return
	if bool(s.map_data.get("lineup_customized", false)):
		return
	s.map_data["lineup_customized"] = true

## 把一台摆到某个格位（位名照 `Fm.位名()`：前1..前4 / 后1..后4）。
##
## ★ UX-1 第 2 项（2026-10-19，作者试玩反馈第 3 条的**根因**）—— 三条铁律：
##   ① **已经在阵上的机体再摆 = 移动 / 互换**，绝不再过「出击位满了」那道闸
##      （从前把 `前1` 的机体挪到 `前2` 会被上限拦住，一卡就是 12 分钟）；
##   ② 目标格上原本有另一台 `other_key` 时：
##        · 这一台来自某个旧格 `old_slot` → `other_key` 换到 `old_slot`（**平滑互换**）；
##        · 这一台本来就坐在名册里（没有旧格）→ `other_key` 下阵（替换，**总人数不变**，
##          同样不过上限闸）；
##   ③ 任何时刻 `lineup` 里同一台机体最多 1 条、同一格位最多 1 条（`_清理重复占格()` 守着）。
## ★ 实时监视：包一层（返回值逐字不变）；`deploy_unit` 是**同名别名**（作者监视清单里的名字）。
func set_lineup_slot(unit_key: String, slot_name: String) -> bool:
	return _record_action("set_lineup_slot", {"unit_key": unit_key, "slot_name": slot_name}, _摆上阵(unit_key, slot_name))

func deploy_unit(unit_key: String, slot_name: String) -> bool:
	return set_lineup_slot(unit_key, slot_name)

func _摆上阵(unit_key: String, slot_name: String) -> bool:
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
	_清理重复占格(s)
	var 位 := _位号(slot_name)
	# ★ 纯函数式重建：先把「位号 → 一条出击记录」压实成一张表（同一位号只留最后一条），
	#   再从这张表里查「这一台现在在哪一格」与「目标格上是谁」。
	var 位表 := _压实出击位(s)
	var 旧 := -1
	for k in 位表.keys():
		if str(位表[k]) == unit_key:
			旧 = int(k)
			break
	var 占者 := str(位表.get(位, ""))
	var 会换人 := not 占者.is_empty() and 占者 != unit_key
	# ★ 上限闸只有一个口径：**上阵人数会不会变多**。
	#   · 这一台本来就在阵上（`旧 >= 0`）→ 移动 / 互换，人数不变 → 放行；
	#   · 目标格上已经有人（`会换人`）→ 替换 / 互换，人数不变 → 放行；
	#   · 只有「往一个空格上加一台还没上阵的机体」才查上限。
	if 旧 < 0 and not 会换人 and s.lineup.size() >= RosterManager.deploy_limit(s):
		_fail("出击位满了（上限 %d 台，先把一台撤下来）" % RosterManager.deploy_limit(s), {"ok": false})
		return false
	if 旧 == 位:
		# 已经站在这一格上：幂等（不改状态），只留一条即时反馈。
		last = {"行动": "编队", "键": unit_key, "位名": slot_name, "位": 位, "原": 旧,
			"出击": s.lineup.duplicate(true), "上限": RosterManager.deploy_limit(s), "没变": true}
		_set_screen("formation")
		return true
	# ① 先移除这一台原来的那一条（否则同一个键会占两格 —— 反馈第 3 条的假「满了」就是这么来的）。
	if 旧 >= 0:
		位表.erase(旧)
	# ② 目标格上那一台的去向：来自旧格 → 互换；没有旧格 → 下阵（替换）。
	if 会换人 and 旧 >= 0:
		位表[旧] = 占者
	# ③ 这一台落到目标格。
	位表[位] = unit_key
	s.lineup = _位表到出击(位表)
	_清理重复占格(s)
	_标记编队已调整(s)
	last = {"行动": "编队", "键": unit_key, "位名": slot_name, "位": 位, "原": 旧,
		"换下": 占者 if 会换人 else "", "出击": s.lineup.duplicate(true),
		"上限": RosterManager.deploy_limit(s)}
	_set_screen("formation")
	return true

## 撤下来（不在出击里 → false，不改状态）。★ 实时监视：包一层；`undeploy_unit` 是同名别名。
func remove_from_lineup(unit_key: String) -> bool:
	return _record_action("remove_from_lineup", {"unit_key": unit_key}, _撤下来(unit_key))

func undeploy_unit(unit_key: String) -> bool:
	return remove_from_lineup(unit_key)

func _撤下来(unit_key: String) -> bool:
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
	_清理重复占格(s)
	_标记编队已调整(s)
	last = {"行动": "撤下", "键": unit_key, "出击前": 前, "出击后": s.lineup.size(),
		"出击": s.lineup.duplicate(true)}
	_set_screen("formation")
	return true

## ★ 清空整个出击名单（编队屏「全部撤下」那一下；**不改名册、不改任何别的状态**）。
## 本来就已经是空的 → `false`（不改状态，与 `remove_from_lineup` 同一口径）。
## ★ 实时监视：包一层（同一次点击只留一条记录）。
func clear_lineup() -> bool:
	return _record_action("clear_lineup", {}, _清空编队())

func _清空编队() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	var 前 := s.lineup.size()
	if 前 == 0:
		_fail("出击名单本来就是空的", {"ok": false, "出击": 0})
		return false
	s.lineup = []
	_标记编队已调整(s)
	last = {"行动": "清空编队", "出击前": 前, "出击后": 0, "出击": []}
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
		"券名": RosterManager.券名(找["券"]) if not 找.is_empty() else "", "前": 预["前"], "后": 预["后"],
		"解锁专属牌": 预.get("解锁专属牌", []), "专属牌库": 预.get("专属牌库", []),
		"等级倍率": DeckBuilder.等级倍率(到)}

# ==========================================================================================
# 四、非战斗节点交互
# ==========================================================================================

## 休整三选一（"耐久" / "晋升" / "推进剂"）；无论选哪一项内核都会回血。
## ★ 实时监视：包一层（返回值逐字不变）；`rest_action` 是**同名别名**。
func resolve_rest(choice: String = "耐久") -> Dictionary:
	return _record_action("resolve_rest", {"choice": choice}, _结算休整(choice))

func rest_action(choice: String = "耐久") -> Dictionary:
	return resolve_rest(choice)

func _结算休整(choice: String = "耐久") -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	# ★ 2026-10-18（作者试玩反馈第 3 条）：**同一格只结算一次**。
	#   从前这一格可以连点 6 次「耐久 +2 / 推进剂 +2」把属性刷上去（`resolve_rest` 无条件跑内核）。
	#   键 = `"层:格"`，与本局的生命周期同长（`start_new_run` / `load_saved_run` / `return_to_menu` 清空）。
	var 键 := 当前节点结算键()
	if _已结算节点键.has(键):
		return _fail("当前节点已结算完毕", {"ok": false, "键": 键, "节点": "休整"})
	var 前 := {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	var r := NodeResolver.结算休整(s, choice)
	if r.is_empty():
		return _fail("休整结算失败", {"ok": false})
	_已结算节点键[键] = true
	r["节点"] = "休整"
	r["前"] = 前
	r["后"] = {"耐久": s.base_hp, "推进剂": s.propellant, "希望": s.hope}
	_node_result = r
	last = {"行动": "休整", "选": choice, "结果": r, "日志": _tail_logs(3)}
	# ★ D-08：休整也可能把推进剂补回来，但若仍是 0（例如选了「耐久」）→ 这一格结算完就追击战。
	if _接追击战(s):
		return r
	_set_screen("map")
	return r

## 黑市买藏品（内核 `NodeResolver.黑市买`）。★ 实时监视：包一层；`shop_buy` 是同名别名。
func buy_from_shop(relic_id: String) -> Dictionary:
	return _record_action("buy_from_shop", {"relic_id": relic_id}, _黑市买(relic_id))

func shop_buy(relic_id: String) -> Dictionary:
	return buy_from_shop(relic_id)

func _黑市买(relic_id: String) -> Dictionary:
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

## ★ 实时监视：包一层（返回值逐字不变）。
func refresh_shop() -> Dictionary:
	return _record_action("refresh_shop", {}, _黑市刷新())

func _黑市刷新() -> Dictionary:
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

## ★ 实时监视：包一层（返回值逐字不变）。
func sell_part_in_shop(part_idx: int) -> Dictionary:
	return _record_action("sell_part_in_shop", {"part_idx": part_idx}, _黑市卖零件(part_idx))

func _黑市卖零件(part_idx: int) -> Dictionary:
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

## ★ 实时监视：包一层（返回值逐字不变）。
func leave_shop() -> bool:
	return _record_action("leave_shop", {}, _离开黑市())

func _离开黑市() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	var ok := NodeResolver.黑市离开(s)
	last = {"行动": "离开黑市", "成功": ok, "已清节点": s.nodes_cleared, "日志": _tail_logs(2)}
	# ★ D-08：离开黑市 = 这一格的事做完了 → 推进剂见底就追击战。
	if _接追击战(s):
		return ok
	_set_screen("map")
	return ok

## 结算一个事件选项（内核 `NodeResolver.结算奇遇`，`choice` 是选项下标）。
## ★ 实时监视：包一层（返回值逐字不变）；`event_choose` 是**同名别名**。
func resolve_event_choice(choice: String = "") -> Dictionary:
	return _record_action("resolve_event_choice", {"choice": choice}, _结算奇遇(choice))

func event_choose(choice: String = "") -> Dictionary:
	return resolve_event_choice(choice)

func _结算奇遇(choice: String = "") -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	# ★ 2026-10-18（作者试玩反馈第 3 条）：**同一格只结算一次**（与休整同一口径）。
	var 键 := 当前节点结算键()
	if _已结算节点键.has(键):
		return _fail("当前节点已结算完毕", {"ok": false, "键": 键, "节点": "事件"})
	var r := NodeResolver.结算奇遇(s, choice)
	if not bool(r.get("ok", false)):
		return _fail(str(r.get("why", "这个事件结算不了")), {"ok": false})
	_已结算节点键[键] = true
	r["节点"] = "事件"
	_node_result = r
	last = {"行动": "事件", "事件": str(r.get("事件", "")), "选": str(r.get("选", "")),
		"结果": str(r.get("结果", "")), "日志": _tail_logs(3)}
	# ★ D-06：事件结算**不产生待选战术牌**（JS 只有招募 / 晋升两处产生）。
	# ★ D-08：这一格的事做完了 → 推进剂见底就追击战。
	if _接追击战(s):
		return r
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
## ★ 实时监视：包一层（返回值逐字不变）。
func start_quick_battle(seed_val: int = 20261013) -> bool:
	return _record_action("start_quick_battle", {"seed_val": seed_val}, _开快速战(seed_val))

func _开快速战(seed_val: int = 20261013) -> bool:
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
			run_state.lineup.append({"key": k, "slot": _第一个空位(_压实出击位(run_state))})
	_quick_battle = true
	_本场已结算 = false
	_本场格类型 = ""
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
	selected_unit_id = ""
	_选中默认机体()
	last = {"行动": "快速战斗", "种子": 种子, "我方": 我方.size(), "敌方": 敌方.size(),
		"手牌": hand_count(), "候补": reserve_preview().size(), "气势": _气氛(), "日志": battle_log_lines(3)}
	_set_screen("battle")
	return true

## ★ 打当前这一格的战斗节点（真肉鸽路径，走 `NodeResolver.开战`）。
## ★ 实时监视：包一层（返回值逐字不变）。
func start_node_battle() -> bool:
	return _record_action("start_node_battle", {}, _开节点战())

func _开节点战() -> bool:
	var s := _need_run()
	if s == null:
		_fail("还没有进行中的局", {"ok": false})
		return false
	if s.map_data.is_empty():
		_fail("还没有大地图", {"ok": false})
		return false
	# ★ D-08：脚下是「追击」→ 走追击战那条（编成用「追击」档、打完走 `after_chase_win`）。
	if str(s.map_data.get("当前节点类型", "")) == "追击":
		return _开追击战(s, s.exit_chase)
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
	var ctx := NodeResolver.开战(s, 详情["条目"], "", _附加战斗选项())
	if ctx.is_empty():
		_fail("战斗内核没有给出 ctx", {"ok": false})
		return false
	_quick_battle = false
	_本场已结算 = false
	_本场格类型 = 格类型
	_血比战前 = _名册血比()
	battle_ctx = ctx
	_unit_switches = 表(ctx, "选项")
	_result_cache = {}
	selected_unit_id = ""
	_选中默认机体()
	last = {"行动": "开战", "格类型": 格类型, "编成类型": str(详情.get("类型", 类型)),
		"编成层": int(详情.get("层", s.floor_num)), "兜底": 详情.get("兜底", null),
		"敌方": (ctx.get("enemies") as Array).size(), "我方": (ctx.get("allies") as Array).size(),
		"手牌": hand_count(), "候补": reserve_preview().size(), "日志": battle_log_lines(3)}
	_set_screen("battle")
	return true

## ==========================================================================================
## ★ 六之零、战前强制编队确认（2026-10-18 作者试玩反馈第 1 条）
##
##   从前「走上战斗格」= 直接开打，「点打追击战」= 直接开打 —— 玩家**没有机会**在开打前
##   调整出击阵容（换前排 / 补上一台刚招到的机体），只能先在大地图上点顶栏「编队」，
##   摆完再走回来，而走回来那一步又直接开打了。
##
##   现在的口径（本段三件事）：
##     ① `prepare_battle_formation(kind)` —— 走上战斗格 / 点「打追击战」只调它：
##        置 `pending_battle_confirm = true` / `pending_battle_kind = kind`，并切到 `"formation"` 屏；
##        `lineup` 空的话顺手把名册里还没上阵的机体按 `deploy_cap` 自动补进空位（一键自动补满）。
##     ② `confirm_formation_and_start_battle()` —— 编队屏那颗【确认编队 · 开始战斗】调它：
##        先验「至少 1 台存活机体」，再把 `pending_battle_confirm` 放掉，然后按 `kind`
##        调 `fight_chase_battle()`（追击）或 `enter_current_node()`（脚下这一格）。
##     ③ 编队屏在确认态下**藏掉「回地图按钮」** —— 不许退回大地图逃避当前格战斗。
##
##   注意：本段**一个字都没动** `_开节点战()` / `_开追击战()` / `NodeResolver` ——
##   真正开打还是走原来那两条路，这里只是加了一道「先摆阵容」的前置屏。
## ==========================================================================================

## 进「战前编队确认」屏。`kind` 收 `"node"`（脚下这一格）或 `"chase"`（追击战）。
## ★ 实时监视：包一层（返回值逐字不变）；`准备战斗编队` 是**同名别名**。
func prepare_battle_formation(kind: String = "node") -> Dictionary:
	return _record_action("prepare_battle_formation", {"kind": kind}, _准备战前编队(kind))

func 准备战斗编队(kind: String = "node") -> Dictionary:
	return prepare_battle_formation(kind)

func _准备战前编队(kind: String = "node") -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	if s.map_data.is_empty():
		return _fail("还没有大地图", {"ok": false})
	var 种 := "chase" if kind == "chase" else "node"
	pending_battle_confirm = true
	pending_battle_kind = 种
	# ★ UX-4：进战前编队确认屏之前**先把 slot 规范成明确位号** —— 编队屏现在显示的站位，
	#   就是 `NodeResolver.我方编成()` 进战斗时真正用的那个位号，两边不会再对不上。
	var 规范了 := _规范编队槽位(s)
	# ★ 一键自动补满：**只在出击名单为空时**动手（有名册 → 把还没上阵的按上限补进空位）。
	#   名单非空时一个字都不改 —— 玩家自己摆好的阵容不许被门面悄悄改掉。
	var 补了 := _自动补满编队(s)
	last = {"行动": "战前编队", "种类": 种, "格": s.node_id, "格类型": _脚下类型(s),
		"出击": s.lineup.size(), "上限": RosterManager.deploy_limit(s), "自动补": 补了, "槽位规范": 规范了,
		"提示": "确认出击阵容，然后点【确认编队 · 开始战斗】"}
	_set_screen("formation")
	return last

## ★ 实时监视：包一层（返回值逐字不变）；`确认编队并开战` 是**同名别名**。
func confirm_formation_and_start_battle() -> Dictionary:
	return _record_action("confirm_formation_and_start_battle", {}, _确认编队开战())

func 确认编队并开战() -> Dictionary:
	return confirm_formation_and_start_battle()

func _确认编队开战() -> Dictionary:
	var s := _need_run()
	if s == null:
		return _fail("还没有进行中的局", {"ok": false})
	# ★ UX-4：开打前最后再规范一次槽位（程序直接调这个口子时也保证「编队屏 = 战场」）。
	_规范编队槽位(s)
	# 闸：至少要 1 台**存活**机体（名册血比 > 0）—— 「出击名单是空的」由 `_开节点战()` 也会拦，
	# 但这里要给出**更准的原因**（玩家看得懂「请至少上阵 1 台机体」）。
	if _出击存活数(s) < 1:
		return _fail("请至少上阵 1 台机体", {"ok": false, "出击": s.lineup.size()})
	var 种 := pending_battle_kind if not pending_battle_kind.is_empty() else "node"
	pending_battle_confirm = false
	pending_battle_kind = ""
	if 种 == "chase":
		var ok := _打追击战()
		if not ok and not in_battle():
			# 追击战开不出来（时机过了）→ 把屏幕摆回大地图，别把玩家留在编队屏上出不去。
			_set_screen("map")
		return last
	return _进当前格()

## 出击名单里**活着**（名册血比 > 0）的台数。名单空 / 名册没这台 → 不算。
func _出击存活数(s: RunState) -> int:
	var n := 0
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var k := str(x.get("key", ""))
		if k.is_empty() or not s.roster.has(k):
			continue
		if float(s.get_unit_hp_ratio(k)) > 0.0:
			n += 1
	return n

## 一键自动补满：把名册里**还没上阵**的机体按 `deploy_limit` 塞进最小空位。返回补了几台。
## ★ 只在「出击名单为空」时被 `_准备战前编队()` 调用；名单非空时它是纯读（返回 0）。
## ★ UX-4：落位一律用**第一个空位**（不再用 `lineup.size()` 当位号），并且写的是明确的整数位号，
##   与 `NodeResolver.我方编成()` 的口径完全一致。
func _自动补满编队(s: RunState) -> int:
	if not s.lineup.is_empty():
		return 0
	var 上限 := RosterManager.deploy_limit(s)
	if 上限 <= 0:
		return 0
	var 位表 := {}
	var 补 := 0
	for 键 in s.roster.keys():
		if s.lineup.size() >= 上限:
			break
		var k := str(键)
		if k.is_empty() or _在出击里(s, k):
			continue
		var 位 := _第一个空位(位表)
		s.lineup.append({"key": k, "slot": 位})
		位表[位] = k
		补 += 1
	return 补

## ==========================================================================================
## 五之二、战斗动作
## ==========================================================================================

## 打一张战术牌 —— **纯委托**（内核 `Btl.打战术牌`，成败完全由气势 / 冷却 / 剩余次数与手牌事实决定）。
## ★ **没有张数门槛**（D-03 纠错）：JS 与内核都不限每回合出牌数，所以这里**不设**任何「打满 N 张」拦截。
##   想给 UI 置灰请用 `hand_card_status(card_id)` / `cards_playable_now()`（纯读，判据与 JS 同一套）。
## ★ 实时监视：包一层（返回值逐字不变）。
func play_tactical_card(card_id: String) -> Dictionary:
	return _record_action("play_tactical_card", {"card_id": card_id}, _打战术牌(card_id))

func _打战术牌(card_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if card_id.is_empty():
		return _fail("没有指定要打哪张牌", {"ok": false})
	var 手牌 := hand_cards()
	var 找到 := {}
	# ★ MITH-3：先按 `_实例号` 精确找（手里两张同名 TDD-1 时点哪张打哪张），再退回 id / 名。
	for c in 手牌:
		if str(c.get("_实例号", "")) == card_id:
			找到 = c
			break
	if 找到.is_empty():
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
## ★ 实时监视：包一层（返回值逐字不变）。
func toggle_unit_switch(unit_id: String, switch_key: String) -> bool:
	return _record_action("toggle_unit_switch", {"unit_id": unit_id, "switch_key": switch_key}, _切开关(unit_id, switch_key))

func _切开关(unit_id: String, switch_key: String) -> bool:
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
## ★ 实时监视：包一层（返回值逐字不变）。
func activate_unit_state(unit_id: String) -> bool:
	return _record_action("activate_unit_state", {"unit_id": unit_id}, _开势力状态(unit_id))

func _开势力状态(unit_id: String) -> bool:
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
## ★ 实时监视：包一层（返回值逐字不变）。
func step_battle_turn() -> Dictionary:
	return _record_action("step_battle_turn", {}, _打一回合())

func _打一回合() -> Dictionary:
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
## ★ 实时监视：包一层（返回值逐字不变）。
func auto_finish_battle() -> Dictionary:
	return _record_action("auto_finish_battle", {}, _自动打完())

func _自动打完() -> Dictionary:
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
## ★ 实时监视：包一层（返回值逐字不变；**幂等闸那一条也照记**，监视侧就能看到「为什么这次没结算」）。
func finish_battle_and_settle() -> Dictionary:
	return _record_action("finish_battle_and_settle", {}, _结算这一场())

func _结算这一场() -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if battle_ctx.get("result") == null:
		return _fail("这一场还没打完（先 `auto_finish_battle()` 或 `step_battle_turn()`）", {"ok": false})
	if _本场已结算:
		# ★ D-07：结算过就不再结算 —— 这里**不许**碰任何状态（不跑内核、不重算缓存、不改 last、不 emit）。
		#   只把一条错误记进 `errors` 并返回；连 `last` 都不覆盖（免得把结算屏的「上一动作」冲掉）。
		var 为什么 := "这一场已经结算过了（要再打请先走下一格 / 开下一场）"
		_记错误(为什么)
		errored.emit(为什么)
		return {"ok": false, "为什么": 为什么, "屏幕": screen, "已结算": true}
	var s := run_state
	if s == null or _quick_battle or s.map_data.is_empty():
		_本场已结算 = true
		_result_cache = _build_result_cache({})
		last = {"行动": "结算", "结果": result_summary()}
		_set_screen("result")
		return last["结果"]
	var 格类型 := _本场格类型 if not _本场格类型.is_empty() else _脚下类型(s)
	# ★ P0（2026-10-13 M4-3 实测 + ARGON 复核）：**「血比前」必须在这一句之前、且每次都重抓**。
	#   `NodeResolver.resolve_battle` 内部会依次跑 `RosterManager.记战斗HP`（把战后血量写回名册）
	#   再 `战后回血`（+50%）。「回血前后对照」要的是**打完那一瞬间、回血之前**的名册血比，
	#   所以：① 位置在这一句之前；② **不能**用 `is_empty()` 那种「有就复用」的写法——
	#   开战时抓的那份是「开战前」的满血值，复用它会让 `血比前 == 血比后`，结算那一层就空了。
	_血比战前 = _名册血比()
	# ★ 战后给券那一签用的场次：**取内核自增之前**的那一拍（`resolve_battle` 自己会 +1）。
	#   用「之前」是为了同一局面可复现（见 `_战后按率给券()`）。
	var 场次前 := int(s.battles_fought)
	var r := NodeResolver.resolve_battle(s, battle_ctx, 格类型)
	r["格类型"] = 格类型
	# ★ 2026-10-18（作者试玩反馈第 2 条）：**每次战斗后严格限定 90% 给 1 张招募券 / 10% 不给**。
	#   位置必须在 `_build_result_cache(r)` **之前** —— 结算屏读的是 `_result_cache`，
	#   所以「补发的券」或「撤掉的券」都要先写进 `r`（战利品那两格 `券` / `券名`）。
	_战后按率给券(s, r, 场次前)
	_result_cache = _build_result_cache(r)
	# 战斗之后：守军 / 追击要补上欠的换层；其他节点清空这一格。
	# ★ D-08：追击战**胜败都换层**（JS `90-肉鸽-4-节点结算.js:399-403` 胜 / `:420` 败，两条都走 `追击之后()`）。
	#   注意：内核这边只有**胜利**那一支会碰「按格类型分派」的后处理（而且只认 `出口守军`）——
	#   `"追击"` 两条、以及「败了但甩掉追兵」那条**内核里没有对应分支**（不是内核 bug，是它只管战斗本身）。
	#   所以门面这一层按 JS 口径自己分派：只要是「追击」且这一局还没结束，就先补上 JS 那两条结果标记。
	if 格类型 == "追击" and s.status != "失败":
		if not bool(r.get("胜", false)):
			r["追击结束"] = true
			r["甩掉追兵"] = true
			s.add_log("追击战没打赢，但甩掉了追兵")
		var 追 := MapNavigator.after_chase_win(s)
		r["追击换层"] = 追
		r["追击"] = true
	elif bool(r.get("胜", false)):
		if 格类型 == "出口守军":
			var 进 := MapNavigator.after_guard_win(s)
			r["换层"] = 进
		elif s.propellant <= 0:
			var 追2 := MapNavigator.after_chase_win(s)
			r["追击换层"] = 追2
			r["追击"] = true
		else:
			NodeResolver.清空格(s)
	else:
		if s.status != "失败":
			NodeResolver.清空格(s)
	_battle_options_cache = _build_battle_options()
	_result_cache["结算"] = r
	_本场已结算 = true
	# ★ D-10：**节点战**结算完才轮到追击战（JS `92-肉鸽界面-1:315`「这一格结算完就会触发追击战」）。
	#   判据 = 这一场的格类型**不是** `"追击"`（是追击战那说明追击战刚刚已经打过了，不许自己接自己）。
	#   上面那个 `elif bool(r.get("胜", false))` 分支里 `s.propellant <= 0` 走的是 `after_chase_win`
	#   （内核的 D-08 口径，**一个字都没动**）；没打赢那一支不碰推进剂，于是这里补上 JS 那一步
	#   → 玩家不会卡在「0 推进剂 + 节点战打完了却没路走」。
	#   注意顺序：必须在 `_set_screen("result")` **之前**接 —— `_开追击战()` 会把屏幕切成 `"battle"`。
	#   ★ 传 `true`：这一场**节点战已经结算完了**，D-10 那道「要先结算」的闸不该再拦（拦了就死锁）。
	if 格类型 != "追击" and _接追击战(s, true):
		return r
	last = {"行动": "结算", "结果": result_summary(), "内核": r}
	_set_screen("result")
	return r

## ==========================================================================================
## ★ 五之三、战后 90% 给 1 张招募券（2026-10-18 作者试玩反馈第 2 条）
##
##   要求原文：「**每次战斗后有 90% 的概率给一张招募券**」，而且**每次战斗最多 1 张**。
##   但内核那一档是按「奖励档」查 `肉鸽数值.战后券率`（普通 / 精英 / 守军 / Boss 各一个率），
##   于是精英 / 守军是 100%、普通是 35% —— 与「一律 90%」不符。
##
##   ★ 纪律：**不动 `core/run/node_resolver.gd`、不动 `core/run/roster_manager.gd`** ——
##     `tests/unit/test_run_core.gd` 的底层黄金样例盯的正是它们，改了必红。
##     所以「一律 90%」这一层是门面**在 `resolve_battle()` 已经跑完之后**补的一道**事后修正**：
##       · 掷一次确定性伪随机（`Mulberry32`，种子 = 局种子 / 层 / **内核自增前的场次** / 格号 的组合）；
##       · `roll < 0.90` 且内核这一场**没给券** → 补发 1 张（`RosterManager.发随机券`），写进战利品；
##       · `roll < 0.90` 且内核**已经给了券** → 保留这一张（**不重复发第 2 张**）；
##       · `roll >= 0.90` 且内核给了券 → 从 `run_state.tickets` 撤掉那一张，战利品清成 `null` / `""`；
##       · `roll >= 0.90` 且内核没给券 → 什么都不做。
##     于是**无论什么战斗格（普通 / 精英 / 守军 / 侵蚀源 / 追击）都是严格的 90% / 10%**。
##
##   ★ 「场次前」为什么要单独传：`resolve_battle()` 内部已经把 `battles_fought` +1 了，
##     这里若读现值，就与「抛这一签那一刻的场次」不是同一个数；用**自增前**的那一拍，
##     同一局面重放时掷出来的结果逐位相同（确定性可复现）。
##   ★ 本局已经结束（`status != "进行中"`，例如耐久耗尽那一支）→ 不掷、不发、不撤。
## ==========================================================================================

## 战后那一签的概率（规格写死 90%）。
const 战后给券率 := 0.90

## 战后「补发 / 保留 / 撤回」一张券，把结果写回 `战利品`（也即 `r` 的 `券` / `券名` 两格）。
## 纯门面动作，不碰内核文件；`场次前` = 调 `resolve_battle` **之前**的 `battles_fought`。
func _战后按率给券(s: RunState, r: Dictionary, 场次前: int) -> void:
	if s == null or r == null:
		return
	# 本局已经结束（耐久耗尽 / 通关）→ 不掷。
	if s.status != "进行中":
		return
	var 券: Variant = r.get("券")
	var 有券 := 券 is Dictionary
	var roll := _战后给券掷签(s, 场次前)
	r["战后券掷"] = roll
	if roll < 战后给券率:
		if 有券:
			# 内核已经给了 1 张 → 保留，**不重复发第 2 张**。
			r["券"] = 券
			r["券名"] = RosterManager.券名(券)
			return
		var 新券: Variant = RosterManager.发随机券(s, "战后")
		if 新券 is Dictionary:
			s.add_log("战斗结束：战后那一签给到了，获得【%s】" % RosterManager.券名(新券))
			r["券"] = 新券
			r["券名"] = RosterManager.券名(新券)
			r["补发券"] = true
		else:
			# 券池已满 / 抽不出来 → 照实报「没有」。
			r["券"] = null
			r["券名"] = ""
		return
	# roll >= 0.90：这一场**不给券**。内核若已经发过，就地撤回那一张。
	if 有券:
		_撤回刚发的券(s, 券)
		r["券"] = null
		r["券名"] = ""
		r["撤券"] = true
	# 没有券 → 什么都不用做。
	return

## 战后那一签的确定性掷点（`0.0 ≤ roll < 1.0`）。种子 = 局种子 / 层 / 场次 / 格号 的确定性组合。
func _战后给券掷签(s: RunState, 场次前: int) -> float:
	var 种子 := int(s.seed_val) + int(s.floor_num) * 613 + int(场次前) * 37 + int(s.node_id) * 17 + 20261018
	var rng := Mulberry32.new(种子)
	return rng.next_float()

## 从 `run_state.tickets` 里撤掉「刚发的那一张」（按 `id` 找，找不到退成「撤最后一张」）。
## ★ 只删**这一张**：同一次结算里不会有两张券（内核那一档最多发一张）。
func _撤回刚发的券(s: RunState, 券: Variant) -> void:
	if s == null or not (券 is Dictionary):
		return
	var id := int((券 as Dictionary).get("id", -1))
	var 下标 := -1
	for i in s.tickets.size():
		var x: Variant = s.tickets[i]
		if x is Dictionary and int((x as Dictionary).get("id", -2)) == id:
			下标 = i
			break
	if 下标 < 0 and not s.tickets.is_empty():
		下标 = s.tickets.size() - 1
	if 下标 < 0:
		return
	s.tickets.remove_at(下标)
	s.add_log("战斗结束：战后那一签没给到，这一场不获得招募券")

# ==========================================================================================
# 五之三、★ DECK-2 / DECK-3：单机牌组（阶段制 · 单机战意 · 上下双排）
#
#   上位文档：`协作/架构/任务单-单机牌组与阶段制战斗-v1.0-ARGON.md` §2 的 DECK-2 / DECK-3。
#
#   纪律（一个字都不许破）：
#     · **门面不发明规则**：能不能打、扣多少战意、身份对不对口，判据全在内核
#       （`Btl.打出主武器卡` / `打出衍生攻击卡` / `打出精神或公有牌` / `结束我方回合`）——
#       本段只做三件事：① 把内核的拒绝理由原文转述；② 把内核已有的字段排成「上排 / 下排」两行；
#       ③ 把「选中哪台」这件事记在 `selected_unit_id`（纯表现层选择，不改内核）。
#     · **默认关**：`单机牌组模式 == false` 时，本段所有口子都直接返回空 / 拒绝，
#       `start_quick_battle(种子)` / `start_new_run(种子, 分队)` 这些旧调用**一个字段都不多**，
#       既有 2000+ 项测试与 168 场黄金样例因此逐字不变。
#     · 零 `J.*`；随机数一次都不抽。
# ==========================================================================================

const 单机区_主武器 := "主武器卡"
const 单机区_衍生 := "衍生攻击卡"
const 单机区_精神 := "专属精神牌"
const 单机区_公有 := "公有牌"

## 显式开 / 关「单机牌组（阶段制）」模式。**界面入口在开战之前调它**
## （`menu_view.gd` 的【快速测试战斗】/【开这一局】）；测试与旧调用都不调 → 走旧口径。
func set_unit_deck_mode(on: bool = true) -> bool:
	单机牌组模式 = on
	_emit()
	return 单机牌组模式

func 启用单机牌组(on: bool = true) -> bool:
	return set_unit_deck_mode(on)

func enable_unit_deck_mode(on: bool = true) -> bool:
	return set_unit_deck_mode(on)

## 下一次开战会不会用单机牌组（纯读标志）。
func unit_deck_mode() -> bool:
	return 单机牌组模式

## 当前这一场是不是单机牌组 —— **判据只有内核那一处**（`Params.单机牌组_开(ctx)`）。
func 单机牌组开() -> bool:
	return not battle_ctx.is_empty() and Params.单机牌组_开(battle_ctx)

func deck_mode_active() -> bool:
	return 单机牌组开()

## 开战时自动选中「格位 0 起第一台存活的我方」。没开单机牌组 = 什么都不做（返回空串）。
func _选中默认机体() -> String:
	selected_unit_id = ""
	if battle_ctx.is_empty() or not Params.单机牌组_开(battle_ctx):
		return ""
	var 我: Variant = battle_ctx.get("allies")
	if not (我 is Array):
		return ""
	var 最小位 := 9999
	var 键 := ""
	for x in (我 as Array):
		if not (x is Dictionary) or float((x as Dictionary).get("hp", 0.0)) <= 0.0:
			continue
		var 位 := int(float((x as Dictionary).get("slot", 9999.0)))
		if 位 < 最小位:
			最小位 = 位
			键 = str((x as Dictionary).get("key", ""))
	selected_unit_id = 键
	return 键

## 我方单位（只认 ally；键 / tplKey / 名 都认）。找不到 = 空字典。
func _找我方单位(unit_id: String) -> Dictionary:
	if battle_ctx.is_empty() or unit_id.is_empty():
		return {}
	var 池: Variant = battle_ctx.get("allies")
	if not (池 is Array):
		return {}
	for x in (池 as Array):
		if not (x is Dictionary):
			continue
		if str(x.get("key", "")) == unit_id or str(x.get("tplKey", "")) == unit_id or str(x.get("name", "")) == unit_id:
			return x
	return {}

## 「这一排操作的是哪台机体」：入参优先，其次 `selected_unit_id`。
func _选中单位(unit_id: String = "") -> Dictionary:
	var 键 := unit_id if not unit_id.is_empty() else selected_unit_id
	if 键.is_empty():
		return {}
	return _找我方单位(键)

## 点选我方机体（DECK-3 §1）：把 `selected_unit_id` 换成那一台。
## **只改「现在操作哪一台」这一个表现层选择**；内核里每台机体本来就能单独操作。
## ★ 实时监视：包一层（返回值逐字不变）。
func select_battle_unit(unit_id: String) -> Dictionary:
	return _record_action("select_battle_unit", {"unit_id": unit_id}, _点选机体(unit_id))

func 点选机体(unit_id: String) -> Dictionary:
	return select_battle_unit(unit_id)

func _点选机体(unit_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if not Params.单机牌组_开(battle_ctx):
		return _fail("这一场没开单机牌组（点选机体只在单机牌组模式下有）", {"ok": false, "单位": unit_id})
	var u := _找我方单位(unit_id)
	if u.is_empty():
		return _fail("我方没有这台机体（%s）" % unit_id, {"ok": false, "单位": unit_id})
	if float(u.get("hp", 0.0)) <= 0.0:
		# 倒下的机体不许选中（没有牌可打），但把原因说清楚
		return _fail("%s 已经倒下，选不了（换一台活着的）" % str(u.get("name", unit_id)),
			{"ok": false, "单位": unit_id})
	selected_unit_id = str(u.get("key", unit_id))
	last = {"行动": "点选机体", "单位": selected_unit_id, "名": str(u.get("name", "")),
		"职业": str(Units.unit_class(u, battle_ctx)), "势力": str(Fac.势力名(u)),
		"战意": Btl.战意(u), "上排": upper_hand_cards().size(), "下排": lower_hand_cards().size()}
	_emit()
	return {"ok": true, "选中": selected_unit_id, "名": str(u.get("name", "")),
		"战意": Btl.战意(u), "上排": upper_hand_cards().size(), "下排": lower_hand_cards().size()}

## 当前选中机体的展示快照（纯读；没选中 = 空字典）。
func selected_unit_view() -> Dictionary:
	if selected_unit_id.is_empty():
		return {}
	return unit_view("ally", selected_unit_id)

## 当前选中的是哪一台（纯读）。
func selected_unit() -> String:
	return selected_unit_id

# ------------------------------------------------------------------------------------------
# 上排：【当前选中机体】的专属牌 —— 主武器卡（左）/ 衍生攻击卡（中）/ 专属精神牌（右）
# ------------------------------------------------------------------------------------------

## 上排三区（DECK-3 §2）。返回数组，每条：
##   `区` = 主武器卡 / 衍生攻击卡 / 专属精神牌；`手牌键`（UI 点击时原样传回 `play_unit_*`）；
##   `名` / `卡类` / `战意`（费用）/ `可打` / `原因` / `描述`；武器条目另有 `冷却` / `剩余`。
## 顺序固定：先主武器卡、再衍生攻击卡、最后专属精神牌（= 规格里的左 / 中 / 右）。
func upper_hand_cards(unit_id: String = "") -> Array:
	var 出: Array = []
	var u := _选中单位(unit_id)
	if u.is_empty():
		return 出
	# ---- ① 主武器卡：常驻武器（常规主武器 / 铁壁护卫 / 紧急修理）+ 已抽到手的角色大招牌 ----
	if u.get("weapons") is Array:
		for e in (u.weapons as Array):
			if not (e is Dictionary) or not ((e as Dictionary).get("t") is Dictionary):
				continue
			var w: Dictionary = (e as Dictionary).t
			if str(w.get("卡类", "")) == 单机区_衍生:
				continue
			if not Calc.weaponPlayable(w):
				continue   # 被动 / 不能主动打出的武器不算「手牌」
			出.append(_武器牌视图(u, e, w))
	if u.get("专属手牌") is Array:
		for c in (u.专属手牌 as Array):
			if not (c is Dictionary):
				continue
			if str((c as Dictionary).get("卡类", "")) == 单机区_主武器:
				出.append(_专属牌视图(u, c, 单机区_主武器))
	# ---- ② 衍生攻击卡（不毁主武）----
	if u.get("衍生手牌") is Array:
		for c in (u.衍生手牌 as Array):
			if c is Dictionary:
				出.append(_专属牌视图(u, c, 单机区_衍生))
	# ---- ③ 专属精神牌（不限张数，够战意就能打）----
	if u.get("专属手牌") is Array:
		for c in (u.专属手牌 as Array):
			if not (c is Dictionary):
				continue
			if str((c as Dictionary).get("卡类", "")) == 单机区_主武器:
				continue
			if Btl.是衍生攻击卡(c):
				continue
			出.append(_专属牌视图(u, c, 单机区_精神))
	return 出

## 一张「常驻武器卡」的视图。判据顺序照内核 `Btl.打出主武器卡` 的检查顺序（理由文案也照它）。
func _武器牌视图(u: Dictionary, entry: Dictionary, w: Dictionary) -> Dictionary:
	var 名 := str(w.get("name", ""))
	var 费 := Btl.战意费用(w)
	var 原因 := ""
	var 可打 := true
	if _真(u.get("主武器已销毁")):
		可打 = false
		原因 = "本回合主武器卡已销毁（下回合初回手）"
	elif entry.get("uses") != null and float(entry.uses) <= 0.0:
		可打 = false
		原因 = "使用次数已用尽"
	elif _读数(entry.get("cd")) > 0.0:
		可打 = false
		原因 = "冷却中"
	elif _读数(u.get("lv", 1.0)) < _读数(Params.残月武器运行期解锁(w)):
		可打 = false
		原因 = "等级不够"
	elif _读数(entry.get("readyTurn")) > float(battle_ctx.get("turn", 1.0)):
		可打 = false
		原因 = "还没到解锁回合"
	elif Btl.战意(u) < 费:
		可打 = false
		原因 = "战意不足"
	else:
		原因 = "点击发动"
	return {
		"区": 单机区_主武器, "手牌键": 名, "名": 名, "武器名": 名, "卡类": 单机区_主武器,
		"战意": 费, "耗气": 费, "冷却": _读数(entry.get("cd")),
		"剩余": (int(_读数(entry.get("uses"))) if entry.get("uses") != null else -1),
		"可打": 可打, "原因": 原因, "描述": str(w.get("desc", "")),
		"单机牌组_铁壁": _真(w.get("单机牌组_铁壁")),
		"是修理": Reach.isHealKind(Reach.rangeKindOf(w)),
	}

## 数字读法（门面里**不许出现 `J.*`** —— `test_boundary.gd` 会扫 `res://session`）：
## 不是数字（null / 空串 / 字典）= 0。
func _读数(v: Variant) -> float:
	if v is int or v is float:
		return float(v)
	return 0.0

## 真假读法（与内核 `J.truthy` 同一口径，但不引入 `J`）：null = 假、0 = 假、空串 = 假。
func _真(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return not (v as String).is_empty()
	return true

## 一张「上排卡牌」（大招牌 / 衍生 / 精神）的视图。
func _专属牌视图(u: Dictionary, c: Dictionary, 区: String) -> Dictionary:
	var 费 := Btl.战意费用(c)
	var 可打 := Btl.战意(u) >= 费
	var 原因 := "点击发动" if 可打 else "战意不足"
	var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
	var id := str(c.get("id", ""))
	return {
		"区": 区, "手牌键": (str(实例) if 实例 > 0 else id), "id": id, "实例号": 实例,
		"名": str(c.get("名", "")), "卡类": (区 if str(c.get("卡类", "")).is_empty() else str(c.get("卡类", ""))),
		"战意": 费, "耗气": 费, "可打": 可打, "原因": 原因,
		"描述": str(c.get("效果说明", c.get("描述", ""))),
		"归属": str(c.get("归属", "")), "种类": str(c.get("种类", "")),
	}

# ------------------------------------------------------------------------------------------
# 下排：全队公有牌（势力牌 / 职业牌 / 统帅牌 / 公共衍生牌）+ 动态身份置灰
# ------------------------------------------------------------------------------------------

## 下排（DECK-3 §2）。每条：`名` / `手牌键` / `卡类` / `归属` / `层级` / `原费` / `费`（折后）/
## `减费`（指挥机 -5）/ `可打` / `原因`。**归属与选中机体不对口 → 可打 = false、原因 = `〔需：近卫〕`**。
func lower_hand_cards(unit_id: String = "") -> Array:
	var 出: Array = []
	if battle_ctx.is_empty():
		return 出
	var 公: Variant = battle_ctx.get("公有手牌")
	if not (公 is Array):
		return 出
	var u := _选中单位(unit_id)
	for c in (公 as Array):
		if not (c is Dictionary):
			continue
		出.append(_公有牌视图(u, c))
	return 出

func _公有牌视图(u: Dictionary, c: Dictionary) -> Dictionary:
	var 原费 := Btl.战意费用(c)
	var 减 := 0.0
	var 指挥 := (not u.is_empty()) and str(Units.unit_class(u, battle_ctx)) == "指挥"
	if 指挥:
		减 = Params.指挥公有减费()
	var 费 := maxf(0.0, 原费 - 减)
	var 对口 := true
	if not u.is_empty():
		对口 = Btl.身份对口(u, c, battle_ctx)
	var 战意 := Btl.战意(u) if not u.is_empty() else 0.0
	var 可打 := 对口 and 战意 >= 费
	var 原因 := "点击发动"
	if not 对口:
		var 归 := str(c.get("归属", ""))
		原因 = "〔需：%s〕" % (归 if not 归.is_empty() else str(c.get("层级", "")))
	elif 战意 < 费:
		原因 = "战意不足"
	var 实例 := int(c.get("_实例号", 0)) if c.get("_实例号") != null else 0
	var id := str(c.get("id", ""))
	return {
		"区": 单机区_公有, "手牌键": (str(实例) if 实例 > 0 else id), "id": id, "实例号": 实例,
		"名": str(c.get("名", "")), "层级": str(c.get("层级", "")), "归属": str(c.get("归属", "")),
		"卡类": str(c.get("卡类", 单机区_公有)), "是衍生": Btl.是衍生攻击卡(c),
		"原费": 原费, "费": 费, "减费": 减, "战意": 费, "对口": 对口, "可打": 可打, "原因": 原因,
		"描述": str(c.get("效果说明", "")),
	}

# ------------------------------------------------------------------------------------------
# 打牌 / 结束回合（一律纯委托内核；门面只转述拒绝理由）
# ------------------------------------------------------------------------------------------

## 打一张【主武器卡】（上排左区 / 角色大招牌也走这里）。
func play_unit_main_weapon(weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return _record_action("play_unit_main_weapon",
		{"weapon_or_card_id": weapon_or_card_id, "target_id": target_id, "unit_id": unit_id},
		_打主武器卡(weapon_or_card_id, target_id, unit_id))

func 打出主武器卡(weapon_or_card_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_main_weapon(weapon_or_card_id, target_id, unit_id)

func _打主武器卡(weapon_or_card_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := Btl.打出主武器卡(battle_ctx, str(u.get("key", "")), weapon_or_card_id, target_id)
	if not bool(r.get("成功", false)):
		return _fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": 单机区_主武器})
	return _出牌成功("打主武器卡", 单机区_主武器, str(r.get("武器", weapon_or_card_id)), u, 战意前, r)

## 打一张【衍生攻击卡】（上排中区；公有手牌里的 TDD-1 等衍生牌也认）。
func play_unit_derived_card(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return _record_action("play_unit_derived_card",
		{"card_inst_id": card_inst_id, "target_id": target_id, "unit_id": unit_id},
		_打衍生卡(card_inst_id, target_id, unit_id))

func 打出衍生攻击卡(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_derived_card(card_inst_id, target_id, unit_id)

func _打衍生卡(card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := Btl.打出衍生攻击卡(battle_ctx, str(u.get("key", "")), card_inst_id, target_id)
	if not bool(r.get("成功", false)):
		return _fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": 单机区_衍生})
	return _出牌成功("打衍生攻击卡", 单机区_衍生, str(r.get("卡牌", card_inst_id)), u, 战意前, r)

## 打一张【专属精神牌】或【下排公有牌】（指挥机打公有牌内核自己减 5 战意）。
func play_unit_spirit_or_public_card(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return _record_action("play_unit_spirit_or_public_card",
		{"card_inst_id": card_inst_id, "target_id": target_id, "unit_id": unit_id},
		_打精神或公有卡(card_inst_id, target_id, unit_id))

func 打出精神或公有牌(card_inst_id: String, target_id: String = "", unit_id: String = "") -> Dictionary:
	return play_unit_spirit_or_public_card(card_inst_id, target_id, unit_id)

func _打精神或公有卡(card_inst_id: String, target_id: String, unit_id: String) -> Dictionary:
	var 门 := _单机出牌门(unit_id)
	if not bool(门.get("ok", false)):
		return 门
	var u: Dictionary = 门["单位"]
	var 战意前 := Btl.战意(u)
	var r := Btl.打出精神或公有牌(battle_ctx, str(u.get("key", "")), card_inst_id, target_id)
	if not bool(r.get("成功", false)):
		return _fail(str(r.get("原因", "打不出来")), {"ok": false, "单位": str(u.get("key", "")), "区": 单机区_精神})
	return _出牌成功("打精神或公有牌", 单机区_精神, str(r.get("卡牌", card_inst_id)), u, 战意前, r)

## 三个打牌口子共用的前置闸：在战斗里 + 单机牌组开着 + 选得出一台活着的我方。
func _单机出牌门(unit_id: String) -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if not Params.单机牌组_开(battle_ctx):
		return _fail("这一场没开单机牌组（主武器卡 / 衍生卡 / 公有牌只在单机牌组模式下能打）", {"ok": false})
	if battle_ctx.get("result") != null:
		return _fail("这一场已经打完了（%s）" % 战果文字(), {"ok": false})
	var u := _选中单位(unit_id)
	if u.is_empty():
		return _fail("还没有选中我方机体（先点一张机体卡）", {"ok": false})
	if float(u.get("hp", 0.0)) <= 0.0:
		return _fail("%s 已经倒下，打不了牌" % str(u.get("name", "")), {"ok": false})
	return {"ok": true, "单位": u}

## 打牌成功后的统一收尾：`last` + 发射 `changed`；返回内核结果（补一个 `ok: true`）。
func _出牌成功(行动: String, 区: String, 牌名: String, u: Dictionary, 战意前: float, 内核: Dictionary) -> Dictionary:
	var r: Dictionary = 内核.duplicate(true)
	r["ok"] = true
	r["行动"] = 行动
	r["区"] = 区
	r["单位"] = str(u.get("key", ""))
	r["战意前"] = 战意前
	r["战意后"] = Btl.战意(u)
	last = {"行动": 行动, "区": 区, "牌": 牌名, "单位": str(u.get("key", "")),
		"战意前": 战意前, "战意后": Btl.战意(u), "主武器已销毁": _真(u.get("主武器已销毁")),
		"击破": _读数(r.get("击破")), "日志": battle_log_lines(3)}
	_emit()
	return r

## 「结束我方回合」（DECK-3 §3）：内核 `Btl.结束我方回合` ——
##   Step A 没打过主武器的我方由 AI 补打 1 张 → Step B 敌方按格位 0..7 行动 → Step C 回合末 + 下一回合。
func end_player_turn() -> Dictionary:
	return _record_action("end_player_turn", {}, _结束我方回合())

func 结束我方回合() -> Dictionary:
	return end_player_turn()

## 「全员自动回合」= 同一件事（内核 Step A 就是「全员托管补打」）—— 只给 UI 一个说人话的名字。
func auto_play_all_units() -> Dictionary:
	return end_player_turn()

func _结束我方回合() -> Dictionary:
	if battle_ctx.is_empty():
		return _fail("现在不在战斗里", {"ok": false})
	if not Params.单机牌组_开(battle_ctx):
		return _fail("这一场没开单机牌组（结束我方回合只在单机牌组模式下有）", {"ok": false})
	if battle_ctx.get("result") != null:
		return _fail("这一场已经打完了（%s）" % 战果文字(), {"ok": false})
	var 前回合 := int(float(battle_ctx.get("turn", 1.0)))
	var 前日志 := battle_log_entries(0).size()
	Btl.结束我方回合(battle_ctx)
	var 后回合 := int(float(battle_ctx.get("turn", 1.0)))
	# ★ DECK-3：敌方阶段可能把「当前选中」那台打掉了 —— 换一台活着的，
	#   否则上排会一直挂着一台死机的牌（点了也只会回「已经倒下」）。
	var 选中 := _选中单位("")
	if 选中.is_empty() or float(选中.get("hp", 0.0)) <= 0.0:
		_选中默认机体()
	last = {"ok": true, "行动": "结束我方回合", "从回合": 前回合, "到回合": 后回合,
		"结果": 战果文字(), "结算": battle_ctx.get("result", null),
		"新日志": maxi(0, battle_log_entries(0).size() - 前日志),
		"阶段": str(battle_ctx.get("阶段", "")), "选中": selected_unit_id, "日志": battle_log_lines(4)}
	_emit()
	return last

## 底栏 / 标题那一行的小计（**纯读**；单机牌组模式下才带「阶段 / 选中 / 战意」这几个键）。
func deck_turn_summary() -> Dictionary:
	var 出 := turn_card_summary()
	if battle_ctx.is_empty() or not Params.单机牌组_开(battle_ctx):
		return 出
	var u := _选中单位("")
	var 上 := upper_hand_cards()
	var 下 := lower_hand_cards()
	var 上能 := 0
	for c in 上:
		if bool((c as Dictionary).get("可打", false)):
			上能 += 1
	var 下能 := 0
	for c in 下:
		if bool((c as Dictionary).get("可打", false)):
			下能 += 1
	出["阶段"] = str(battle_ctx.get("阶段", ""))
	出["单机牌组"] = true
	出["选中"] = selected_unit_id
	出["选中名"] = str(u.get("name", ""))
	出["选中职业"] = (str(Units.unit_class(u, battle_ctx)) if not u.is_empty() else "")
	出["选中势力"] = (str(Fac.势力名(u)) if not u.is_empty() else "")
	出["战意"] = Btl.战意(u) if not u.is_empty() else 0.0
	出["战意上限"] = Params.战意上限()
	出["主武器已销毁"] = _真(u.get("主武器已销毁"))
	出["上排"] = 上.size()
	出["下排"] = 下.size()
	出["上排能打"] = 上能
	出["下排能打"] = 下能
	return 出

## 敌方意图（DECK-2 §2）：逐台敌机一行的**纯读**预告，字段全部来自内核 `Btl.算意图(ctx)`。
func enemy_intents() -> Array:
	if battle_ctx.is_empty():
		return []
	var 意: Variant = battle_ctx.get("敌方意图")
	if not (意 is Array):
		# **纯读**：没有缓存就地算一份 `Btl.算意图()`（它本身是纯读，绝不写 ctx）。
		意 = Btl.算意图(battle_ctx)
	var 出: Array = []
	for x in (意 as Array):
		if x is Dictionary:
			出.append((x as Dictionary).duplicate(true))
		else:
			出.append(x)
	return 出

## 「某台单位此刻的意图预告行」（给 `UnitCard.意图行` 用；纯读）。
##   · 敌方 → 它下一拍要做什么（`意图：攻击【武器】→ 目标（预计 N）`）；
##   · 我方 → 有没有被瞄准（`〔被瞄准〕前1·强袭（预计 320）`）。
func unit_intent_lines(side: String, unit_id: String) -> Array:
	var 出: Array = []
	if battle_ctx.is_empty() or not Params.单机牌组_开(battle_ctx):
		return 出
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	var u := _找我方单位(unit_id) if 方 == "ally" else _找单位(unit_id)
	if u.is_empty():
		return 出
	if 方 == "enemy" and not _在敌方(u):
		return 出   # `_找单位` 会先找我方：键撞车时别把友军当敌机
	var 意 := enemy_intents()
	var 键 := str(u.get("key", ""))
	var 位 := float(u.get("slot", -1.0))
	for 条 in 意:
		if not (条 is Dictionary):
			continue
		var c: Dictionary = 条
		if 方 == "enemy":
			if str(c.get("单位", "")) != 键:
				continue
			出.append(_意图一行文本(c))
		else:
			var 打我 := str(c.get("目标", "")) == 键
			var 落点: Variant = c.get("落点们")
			if not 打我 and 落点 is Array and (落点 as Array).has(位):
				打我 = true
			if 打我:
				出.append("〔被瞄准〕%s·%s（预计 %s）" % [str(c.get("位名", "")), str(c.get("武器名", "")),
					_数文(c.get("预计伤害"))])
	return 出

## 一条 `算意图` 条目 → 一行中文预告。**只用内核给的字段**，一个数都不自己算。
## 例：`意图：攻击【强袭】→ 洛弟（前1）（预计 320）· 大招 · 范围：row`
func _意图一行文本(c: Dictionary) -> String:
	var 武 := str(c.get("武器名", ""))
	var 段 := "意图："
	if 武.is_empty():
		段 += "这一拍打不到人"
		return 段
	段 += "攻击【%s】" % 武
	var 目 := str(c.get("目标名", ""))
	if not 目.is_empty():
		段 += "→ %s（%s）" % [目, str(c.get("目标位名", ""))]
	段 += "（预计 %s）" % _数文(c.get("预计伤害"))
	if bool(c.get("是大招", false)):
		段 += "· 大招"
	if bool(c.get("是大技能", false)):
		段 += "· Boss 大技能"
	if bool(c.get("被挡", false)):
		段 += "· 被挡 -20"
	var 落: Variant = c.get("落点们")
	if 落 is Array and (落 as Array).size() > 1:
		段 += "· 范围：%s" % str(c.get("形状", ""))
	return 段

## 数值 → 文本（0 位小数；空 = "0"）。
func _数文(v: Variant) -> String:
	if v == null:
		return "0"
	return str(int(JsCompat.js_round(float(v))))

## 这台（`_找单位` 找到的）单位是不是敌方的。
func _在敌方(u: Dictionary) -> bool:
	var 池: Variant = battle_ctx.get("enemies")
	if not (池 is Array):
		return false
	for x in (池 as Array):
		if x is Dictionary and is_same(x, u):
			return true
	return false

# ==========================================================================================
# 六、展示辅助（给 M4-2 / M4-3 的 UI 用：**纯读，不改状态**）
#
#   ★ UX-2 第 1 项（2026-10-19，作者反馈第 4 条）：一批「牌 → 来源机体」的**纯读**辅助 ——
#     `card_source()` / `hand_cards()` / `bench_cards()` / `reserve_preview()` / `card_hover_text()`。
#     每张牌附 `source_unit_text`（含「来自：」）/ `source_slots`（位名数组）/ `source_kind`。
#     实现要点：**抄一份**再挂字段（不往 `battle_ctx.战术手牌` 里写），
#     因为 smoke 段 5 的 `_快照()` 真的在断言「表现层 refresh() 是纯读」。
# ==========================================================================================

func hand_cards() -> Array:
	if battle_ctx.is_empty():
		return []
	var 手: Variant = battle_ctx.get("战术手牌")
	return _附来源(手) if 手 is Array else []

## ★ UX-2 第 1 项：候补初始牌（D-01 的「排队等空位」那一批）。
## 与 `reserve_preview()` **同一份数据**，只是名字对齐任务单（`bench_cards()`）；
## 每张牌同样带 `source_unit_text` / `source_slots`（来源机体解析结果）。
func bench_cards() -> Array:
	return reserve_preview()

## ★ UX-2 第 1 项：给一批战术牌**抄一份**并附上「来源机体」三件套（**纯读**）。
##
## · `source_unit_text: String` —— 一律以 `来自：` 开头（卡面直接显示成 `【来自：…】`）；
## · `source_slots: Array`      —— 对应我方机体的位名数组（`["前1"]`；统帅牌 = 空）；
## · `source_kind: String`      —— `角色` / `职业` / `势力` / `统帅` / `未知`（只给悬停说明用）。
## ★ 为什么是**抄一份**：`battle_ctx.战术手牌` 里的字典是内核状态，表现层刷新一次就往里塞字段
##   会污染 `_快照()` 的「refresh 是纯读」断言（smoke 段 5 真的在查）。抄一份 = 零副作用。
func _附来源(牌们: Variant) -> Array:
	var out: Array = []
	if not (牌们 is Array):
		return out
	var 阵 := _我方阵()
	for c in (牌们 as Array):
		if not (c is Dictionary):
			out.append(c)
			continue
		var 牌: Dictionary = (c as Dictionary).duplicate()
		var 源 := Btl.牌来源机体(牌, 阵)
		牌["source_unit_text"] = str(源.get("文本", ""))
		牌["source_slots"] = (源.get("位") as Array).duplicate() if 源.get("位") is Array else []
		牌["source_kind"] = str(源.get("类别", ""))
		out.append(牌)
	return out

## ★ UX-2 第 1 项：一张战术牌「来自我方哪台机体」的**纯读**解析（门面口子）。
##
## 入参收**卡牌字典**或**卡牌 id / 卡名**（与 `card_hover_text()` 同一套认法）；
## 返回 `{文本, 位, 类别}` —— 文本以 `来自：` 开头，`位` 是位名数组（给联动高亮用）。
## 战斗中用 `battle_ctx.allies`；局外用编队 `lineup` 造同形状的伪单位（不改任何状态）。
func card_source(card_or_id: Variant) -> Dictionary:
	_data_ready()
	var c: Dictionary = {}
	if card_or_id is Dictionary:
		c = (card_or_id as Dictionary).duplicate()
		var 目录 := DeckBuilder.找到(str(c.get("id", "")))
		for k in 目录.keys():
			if not c.has(k) or c[k] == null:
				c[k] = 目录[k]
	elif card_or_id is String or card_or_id is StringName:
		c = DeckBuilder.找到(str(card_or_id))
	if c.is_empty():
		return {"文本": "来自：指挥官（统帅）", "位": [], "类别": "未知"}
	return Btl.牌来源机体(c, _我方阵())

## 「我方现在有哪些机体」—— 战斗中直接读 `battle_ctx.allies`（纯读，不复制）；
## 局外按 `run_state.lineup` 造同形状的伪单位（键 / 位号 / 机师名 / tags），一个数都不算。
func _我方阵() -> Array:
	if not battle_ctx.is_empty():
		var 我: Variant = battle_ctx.get("allies")
		if 我 is Array and not (我 as Array).is_empty():
			return 我
	var s := run_state
	var 出: Array = []
	if s == null or not Db.installed:
		return 出
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var 键 := str((x as Dictionary).get("key", ""))
		if 键.is_empty():
			continue
		var tpl := RosterManager.模板(键)
		var 名 := str(tpl.get("pilot", 键))
		var 标: Variant = tpl.get("tags")
		出.append({"key": 键, "slot": float(maxi(0, _条位号(x))),
			"name": 名, "tags": 标, "hp": 1.0})
	return 出

func hand_count() -> int:
	return hand_cards().size()

## ★ MITH-3 预告层：秘银连携的本回合状态（**纯读** `battle_ctx`，不改任何字段、不自造规则）。
## 返回：`启用`（`Params.秘银v02开(ctx)` 为真，或 ctx 里真有秘银成员 / 秘银连携牌）/
## `本回合秘银牌数` / `连携倍率` / `双倍连携` / `触发连携次数` / `打出TDD1数`。
## 开关关着、又不是秘银编成时：`启用 = false`、计数都是保守的 0 / 1，既有战斗屏一个字都不变。
func mithril_link_state() -> Dictionary:
	var 倍率 := int(battle_ctx.get("本回合连携触发倍率", 1))
	var 计: Dictionary = battle_ctx.get("战况计数") if battle_ctx.get("战况计数") is Dictionary else {}
	return {
		"启用": Params.秘银v02开(battle_ctx) or _ctx有秘银(battle_ctx),
		"本回合秘银牌数": int(battle_ctx.get("本回合秘银牌数", 0)),
		"连携倍率": 倍率,
		"双倍连携": 倍率 >= 2,
		"触发连携次数": int(计.get("触发连携", 0)),
		"打出TDD1数": int(计.get("打出TDD1", 0)),
	}

## ctx 里有没有秘银成员（我方 `tags.势力 == 秘银` 或键属于秘银五人队）或秘银连携牌
## （手牌 / 待触发池 / 候补牌里的 `归属 == 秘银` / `角色所属势力 == 秘银` / `是TDD1`）。
## **纯读**；秘银 v0.2 关着时用来判断「这场战斗值不值得显示连携计数」。
func _ctx有秘银(ctx: Dictionary) -> bool:
	if ctx.is_empty():
		return false
	var 我: Variant = ctx.get("allies")
	for u in (我 if 我 is Array else []):
		if not (u is Dictionary):
			continue
		var 键 := str((u as Dictionary).get("key", ""))
		if not 键.is_empty() and (键 in MithrilV02Cards.成员键):
			return true
		var 标签: Variant = (u as Dictionary).get("tags")
		if 标签 is Dictionary and str((标签 as Dictionary).get("势力", "")) == MithrilV02Cards.势力:
			return true
	for 池键 in ["战术手牌", "待触发战术牌", "候补初始牌"]:
		var 池: Variant = ctx.get(池键)
		if not (池 is Array):
			continue
		for c in (池 as Array):
			if not (c is Dictionary):
				continue
			if Btl.是秘银计入牌(c):
				return true
	return false

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
## ★ MITH-3：入参可以是 **卡牌字典**（战斗手牌对象，优先按 `_实例号` 定位 —— 手里两张同名 TDD-1
##   也能各查各的）或 **String / int**（先按 `_实例号`、再按 `id`、最后按 `名` 找）。
##   返回值追加秘银连携口径的纯读字段：`实例号` / `连携阈值` / `是衍生牌` / `连携就绪` /
##   `可连携亮边` / `实际耗气`。开关关着时这些字段照样给（值都是保守的 false / 0），旧字段一个不改。
func hand_card_status(card_or_id: Variant) -> Dictionary:
	var 空 := {"在手里": false, "可打": false, "原因": "手牌里没有这张牌", "耗气": 0.0, "回气": 0.0, "冷却": 0, "剩余": 0,
		"实例号": 0, "连携阈值": 0, "是衍生牌": false, "连携就绪": false, "可连携亮边": false, "实际耗气": 0}
	if battle_ctx.is_empty():
		空["原因"] = "现在不在战斗里"
		return 空
	var 找到 := _找手牌卡(card_or_id)
	if 找到.is_empty():
		return 空
	var s := _卡可打吗(找到)
	s["在手里"] = true
	return _补手牌连携状态(s, 找到)

## 全部手牌的预告行（UI 直接遍历画手牌栏；纯读）。
## ★ MITH-3：每行与 `hand_card_status(牌字典)` **同一份口径**（不再单独拼一套字段）。
func hand_status_all() -> Array:
	var out: Array = []
	for c in hand_cards():
		var s := hand_card_status(c)
		s["在手里"] = true
		s["id"] = str(c.get("id", ""))
		s["名"] = str(c.get("名", ""))
		s["层级"] = str(c.get("层级", ""))
		out.append(s)
	return out

## 在手牌里按入参找那张牌（**纯读**）。字典优先 `_实例号`（再身份、再 id），
## String / int 先 `_实例号`、再 `id`、最后 `名`。找不到 = 空字典。
func _找手牌卡(card_or_id: Variant) -> Dictionary:
	var 手 := hand_cards()
	if card_or_id is Dictionary:
		var 卡: Dictionary = card_or_id
		var 号 := str(卡.get("_实例号", ""))
		if not 号.is_empty() and 号 != "0":
			for c in 手:
				if c is Dictionary and str(c.get("_实例号", "")) == 号:
					return c
		for c in 手:
			if c is Dictionary and is_same(c, 卡):
				return c
		var id := str(卡.get("id", ""))
		if not id.is_empty():
			for c in 手:
				if c is Dictionary and str(c.get("id", "")) == id:
					return c
		return {}
	var 键 := str(card_or_id)
	if 键.is_empty():
		return {}
	for c in 手:
		if c is Dictionary and str(c.get("_实例号", "")) == 键:
			return c
	for c in 手:
		if c is Dictionary and (str(c.get("id", "")) == 键 or str(c.get("名", "")) == 键):
			return c
	return {}

## 给一张手牌的状态补上秘银 v0.2 的纯读字段（MITH-3 预告层）。
## 判据（与任务单一致）：非衍生牌 + `连携阈值 > 0` + 本回合秘银牌数 ≥ 阈值 → 连携就绪；
## 可打 + 连携就绪 → 可连携亮边。`实际耗气` 在秘银 v0.2 开着时走内核 `Btl.实际耗气`，否则就是原耗气。
func _补手牌连携状态(状: Dictionary, c: Dictionary) -> Dictionary:
	var 阈值 := int(c.get("连携阈值", 0))
	var 衍生 := bool(c.get("衍生", false))
	var 本回合 := int(battle_ctx.get("本回合秘银牌数", 0))
	var 就绪: bool = (not 衍生) and 阈值 > 0 and 本回合 >= 阈值
	var 原耗 := int(JsCompat.js_round(float(c.get("耗气", 0.0)) if c.get("耗气") != null else 0.0))
	状["实例号"] = int(c.get("_实例号", 0))
	状["连携阈值"] = 阈值
	状["是衍生牌"] = 衍生
	状["连携就绪"] = 就绪
	状["可连携亮边"] = bool(状.get("可打", false)) and 就绪
	状["实际耗气"] = Btl.实际耗气(battle_ctx, c) if Params.秘银v02开(battle_ctx) else 原耗
	return 状

## 一张牌的判据（与 JS `80-界面-3:94/100` 同一套；只读，不改任何状态）。
## ★ MITH-2：秘银 v0.2 开着时改用内核的 `Btl.卡可打吗` / `Btl.实际耗气`（占行动、绑定角色阵亡、
##   动态降费都在那一份判据里 —— 门面与内核只有一处真源）。关着时一个字都不变。
func _卡可打吗(c: Dictionary) -> Dictionary:
	var 气势 := _气氛()
	var 秘银v02: bool = Params.秘银v02开(battle_ctx)
	var 耗 := float(c.get("耗气", 0.0)) if c.get("耗气") != null else 0.0
	if 秘银v02:
		耗 = float(Btl.实际耗气(battle_ctx, c))
	var 回 := float(c.get("回气", 0.0)) if c.get("回气") != null else 0.0
	var 冷 := int(c.get("当前冷却", 0.0)) if c.get("当前冷却") != null else 0
	var 剩 := int(c.get("剩余次数", 1.0)) if c.get("剩余次数") != null else 1
	var 可打 := 气势 >= 耗 and 冷 <= 0 and 剩 > 0
	if 秘银v02:
		可打 = Btl.卡可打吗(battle_ctx, c)
	var 原因 := ""
	if not 可打:
		var 内核原因 := Btl.不可打原因(battle_ctx, c) if 秘银v02 else ""
		if 冷 > 0:
			原因 = "冷却 %d 回合" % 冷
		elif 气势 < 耗:
			原因 = "需 %d 气势" % int(JsCompat.js_round(耗))
		elif 剩 <= 0:
			原因 = "剩余 0 次"
		elif 内核原因 != "":
			原因 = 内核原因
		else:
			原因 = "打不出来"
	else:
		原因 = "点击发动"
	return {"在手里": true, "可打": 可打, "原因": 原因, "耗气": 耗, "回气": 回, "冷却": 冷, "剩余": 剩, "气势": 气势}

## 候补初始牌（D-01 重点）：数量与列表。
## ★ UX-2 第 1 项：每张牌同样带 `source_unit_text` / `source_slots`（来源机体）。
func reserve_preview() -> Array:
	if battle_ctx.is_empty():
		return []
	var 候: Variant = battle_ctx.get("候补初始牌")
	return _附来源(候) if 候 is Array else []

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
			out.append("[第 %d 回合] %s" % [int(float(e.get("回合", 0.0))), _单条战斗日志转文本(e)])
		else:
			out.append(str(e))
	return out

## ★ UX-2 第 1 项：**一条战斗日志的展示文本**。
## `发牌` 条目在内核里已经带上 `来源文本`（哪台机体带出来的这张牌）；万一那条日志是
## 旧存档 / 旧路径留下的（`文本` 里没有「来自：」），这里就地补上去 —— 只补**展示文本**，
## 一个字段都不改（`battle_log_entries()` 拿到的还是内核原样）。
func _单条战斗日志转文本(e: Dictionary) -> String:
	var 文 := str(e.get("文本", ""))
	var 源 := str(e.get("来源文本", ""))
	if 源.is_empty() or 文.contains("来自："):
		return 文
	return "%s · %s" % [文, 源]

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
	var d := {
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
	# ★ DECK-2 / DECK-3：单机牌组模式下再补「战意 / 主武状态 / 选中 / 意图预告」这几样。
	#   关着的时候一个键都不加 —— 既有断言（含 smoke 段 5 的快照比对）照旧。
	if Params.单机牌组_开(battle_ctx):
		d["战意"] = Btl.战意(u)
		d["战意上限"] = Params.战意上限()
		d["主武器已销毁"] = _真(u.get("主武器已销毁"))
		d["主武器状态"] = "〔已打主武〕" if _真(u.get("主武器已销毁")) else "〔主武就绪〕"
		d["选中"] = (方 == "ally" and str(u.get("key", "")) == selected_unit_id)
		if 方 == "enemy":
			d["意图"] = unit_intent_lines("enemy", str(u.get("key", "")))
		else:
			d["威胁"] = unit_intent_lines("ally", str(u.get("key", "")))
	# ★ 悬停说明（Mouse Over）：UI 只要把它贴到控件上（`HoverTooltip.bind`）就有整台机体的说明。
	d["悬停说明"] = _单位说明文字(方, u, true)
	return d

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
		"触发连携次数": int(r.get("触发连携次数", 0)),
		"打出TDD1数": int(r.get("打出TDD1数", 0)),
		"秘银v02": bool(r.get("秘银v02", false)),
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
# 六之二、Mouse Over 悬停说明（**纯读**：不改任何业务规则、不掷随机数、不写状态）
#
#   为什么要放在门面里：表现层不许自己拼数值与文案（契约 §1 第 5 条 / §5），
#   而「一台机体 / 一张牌到底长什么样」的**全部事实**都在内核与目录里。
#   所以这里只做一件事：把已有字段**抄**成一段多行中文说明。
# ==========================================================================================

## 战斗中一台单位的悬停说明（多行）。`side` 收 `"ally"`/`"我方"` 与 `"enemy"`/`"敌方"`，
## `unit_key` 收 `key` / `tplKey` / `name`（与 `unit_view()` 同一套认法）。
func unit_hover_text(side: String, unit_key: String) -> String:
	var 方 := "ally" if (side == "ally" or side == "我方") else "enemy"
	if battle_ctx.is_empty():
		return "【%s】现在不在战斗里 —— 开一场战斗之后这里会给出这台机体的实时状态与武器冷却。" % unit_key
	var u := _找单位(unit_key)
	if u.is_empty():
		return "【%s】%s这一方没有这台单位。" % [unit_key, "我方" if 方 == "ally" else "敌方"]
	return _单位说明文字(方, u, true)

## 局外（名册 / 编队格位 / 招募候选）一台机体的悬停说明。
## `level` 是**展示等级**（招募候选 / 名册里的等级由调用方传进来）；`is_enemy` 为真时查敌机模板。
## ★ 属性与武器一律走内核自己的 `Units.makeUnit()` 造一份**只读**快照来读 ——
##   门面**不自己算成长**（那会变成第二套口径）。造的这份快照不进任何战斗、不改任何状态。
func template_unit_hover_text(unit_key: String, level: int = 10, is_enemy: bool = false) -> String:
	_data_ready()
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
	# 只读快照：`makeUnit` 是纯函数（不掷随机数、不写状态），`强化` 传 1 就不吃敌方强化倍率。
	var u := Units.makeUnit(键, 方, 0.0, float(lv))
	if u.is_empty():
		return "【%s】（Lv%s）内核造不出这台机体的快照。" % [键, UiTheme.文本(lv)]
	return _单位说明文字(方, u, false)

## 一张战术牌的悬停说明（多行）。入参可以是**卡牌字典**（目录牌或战斗手牌都行）或**卡牌 id**。
func card_hover_text(card_or_id: Variant) -> String:
	_data_ready()
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
		return "【%s】数据表里没有这张战术牌。" % UiTheme.文本(card_or_id)
	var id := str(c.get("id", ""))
	var 段: Array = []
	段.append("【%s】（%s · 归属 %s · 精神标签 %s）" % [str(c.get("名", id)), str(c.get("层级", "—")),
		str(c.get("归属", "—")), str(c.get("精神标签", "—"))])
	段.append("消耗与限制：耗气 %s · 回气 %s · 冷却 %s 回合 · 每场限次 %s" % [_数(c.get("耗气", 0)),
		_数(c.get("回气", 0)), _数(c.get("冷却", 0)), _限次文字(c.get("限次"))])
	段.append("入牌方式：%s（条件码 %s）" % [str(c.get("入牌", "—")), str(c.get("触发条件码", "—"))])
	# ★ UX-2 第 1 项：这张牌是**哪台机体**带出来的（角色 / 职业 / 势力 / 统帅，纯读解析）。
	var 源 := Btl.牌来源机体(c, _我方阵())
	var 源类 := str(源.get("类别", ""))
	段.append("来源机体：%s · %s牌" % [str(源.get("文本", "")),
		"战术" if (源类.is_empty() or 源类 == "未知") else 源类])
	段.append("触发条件：%s" % str(c.get("触发说明", "—")))
	段.append("效果说明：%s" % str(c.get("效果说明", "—")))
	# ★ MITH-3 预告层（悬停说明）：衍生牌写清打出后移除；连携牌写清条件与当前进度。
	var 本回合秘银 := int(battle_ctx.get("本回合秘银牌数", 0)) if not battle_ctx.is_empty() else 0
	if bool(c.get("衍生", false)):
		段.append("【衍生牌 · 打出后移除】")
	else:
		var 阈 := int(c.get("连携阈值", 0))
		if 阈 > 0:
			段.append("连携条件：【连携·%d】（当前本回合秘银牌：%d / %d，%s）" % [
				阈, 本回合秘银, 阈, "已就绪" if 本回合秘银 >= 阈 else "未就绪"])
	if not battle_ctx.is_empty() and not id.is_empty():
		var 状 := hand_card_status(card_or_id if card_or_id is Dictionary else id)
		if bool(状.get("在手里", false)):
			段.append("当前手牌：%s（%s）· 剩余 %s 次 · 当前冷却 %s 回合" % [
				"可打" if bool(状.get("可打", false)) else "打不出来", str(状.get("原因", "")),
				UiTheme.文本(状.get("剩余", 0)), UiTheme.文本(状.get("冷却", 0))])
		else:
			段.append("当前手牌：不在手里（%s）" % str(状.get("原因", "")))
	return "\n".join(段)

# ---------- ★ UX-1 第 4 / 5 项（2026-10-19）：零件与藏品的悬停说明 + 「现在到底能不能用」 ----------

## 这一件零件**现在能不能用**（纯读；不改状态、不掷随机数）。
##
## 返回 `{ok, passive, targets, why, key, name, left}`：
##   · `passive = true`  → 常驻被动，**根本不需要点**（`ok = false`，`why` 写明原因）；
##   · `ok = false`      → 现在点不了，`why` 就是给玩家看的那句话；
##   · `ok = true`       → `targets` 是大地图上能点的高亮目标格。
## 口径（三条都来自作者试玩反馈第 1 条「零件点击了无法使用」）：
##   ① 不在大地图（战斗 / 结算 / 编队 / 菜单）→ 不许点；
##   ② 剩余次数 `<= 0` → 不许点；
##   ③ 在大地图但当前位置周围没有任何合法目标格 → 不许点（从前点完进空瞄准态、点哪格都被拒）。
func part_can_use_now(idx: int) -> Dictionary:
	_data_ready()
	var 空 := {"ok": false, "passive": false, "instant": false, "no_target_select": false,
		"targets": [], "why": "", "key": "", "name": "", "left": -1,
		"free": false, "rarity": "low", "breakOnNextFloor": false, "sell": 0, "类": ""}
	var s := run_state
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
	# ① 常驻被动（`用: false`：河谷祭祈 / 血蕈 / 浪花）——根本不需要点。
	if 信息.is_empty() or not bool(信息.get("用", false)):
		d["passive"] = true
		d["why"] = "常驻被动生效，无需手动点击使用"
		return d
	if str(screen) != "map":
		d["why"] = "请在大地图界面点击使用"
		return d
	if 左 == 0:
		d["why"] = "本层使用次数已用尽"
		return d
	# ② 推进剂禁则（作者拍板）：`free: false` 的零件在推进剂 < 1 时严禁使用。
	if not 免费 and int(s.propellant) < 1:
		d["why"] = "推进剂不足（需 1 点）"
		return d
	# ③ 小八界：**不用选落点**，一键随机传送（`instant` / `no_target_select` 两个标记都给）。
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

## 一件零件挂鼠标上的整段说明（多行）：名称 / 稀有度 / 分类 / 主动还是常驻被动 / 效果 /
## 剩余次数 / 推进剂消耗 / 跨层损坏 / 出售价 / 现在能不能用。
func part_hover_text(idx: int) -> String:
	var 状 := part_can_use_now(idx)
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
	段.append("剩余次数：%s" % ("常驻，不计次数" if 被 or 左 < 0 else UiTheme.文本(左)))
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
		段.append("这一版能作用 %s 格" % UiTheme.文本(目标.size()))
	if bool(状.get("ok", false)):
		段.append("现在可用：点击后在大地图选择高亮目标格生效" if not bool(状.get("instant", false))
			else "现在可用：点击直接发动随机传送")
	else:
		段.append("现在用不了：%s" % str(状.get("why", "")))
	return "\n".join(段)

## 一件藏品挂鼠标上的整段说明（多行）：名称 / 稀有度 / 分类 / 完整效果 / 数值加成 / 来源。
func relic_hover_text(relic_id: String) -> String:
	_data_ready()
	var id := relic_id
	var r := RelicSystem.件(id)
	if r.is_empty():
		return "【%s】数据表里没有这件藏品。" % UiTheme.文本(id)
	var 段: Array = []
	段.append("【%s】（稀有度 %s · %s）" % [str(r.get("名", id)), str(r.get("稀有", "—")), str(r.get("分类", "—"))])
	段.append("藏品键：%s · 实装：%s" % [id, str(r.get("实装", "—"))])
	var 说明 := str(r.get("说明", ""))
	段.append("效果说明：%s" % (说明 if not 说明.is_empty() else "（数据表里没有写说明）"))
	var 加成 := _藏品数值文字(RelicSystem.数值(r))
	段.append("数值加成：%s" % (加成 if not 加成.is_empty() else "（这件没有数值加成）"))
	段.append("来源：黑市买 / 精英与 Boss 战胜利发放 / 遗迹探明")
	return "\n".join(段)

## 藏品 `数值` 字典 → 一行可读文字（**只抄表里的键值**，门面不自己换算百分比）。
## 键名是数据表里的英文键（`hpPct` / `mods` …）—— 照抄，不改写、不翻译，免得与内核口径打架。
func _藏品数值文字(v: Variant, 前缀: String = "") -> String:
	if v is Dictionary:
		var 段: Array = []
		for k in (v as Dictionary).keys():
			var 子 := _藏品数值文字((v as Dictionary)[k], str(k) if 前缀.is_empty() else 前缀 + "." + str(k))
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
	return UiTheme.文本(v) if 前缀.is_empty() else "%s = %s" % [前缀, UiTheme.文本(v)]

## 一台单位的整段说明。`战斗中` = 要不要多写「气势 / 状态 / 增益减益 / 下一拍意图 / 觉醒」。
func _单位说明文字(方: String, u: Dictionary, 战斗中: bool) -> String:
	var 键 := str(u.get("key", ""))
	var 标签: Dictionary = u.get("tags") if u.get("tags") is Dictionary else {}
	var 分类 := str(标签.get("战斗分类", ""))
	var 势力 := str(标签.get("势力", ""))
	var 头 := "【%s】%s · Lv%s · %s · %s" % [str(u.get("mech", 键)), str(u.get("pilot", u.get("name", 键))),
		_数(u.get("lv", 0)), 分类 if not 分类.is_empty() else "—", 势力 if not 势力.is_empty() else "—"]
	if 战斗中:
		头 += " · %s" % Fm.位名(float(u.get("slot", 0.0)))
	var 段: Array = [头]
	var 生命 := float(u.get("hp", 0.0))
	var 满 := float(u.get("maxHp", 1.0))
	if 满 <= 0.0:
		满 = 1.0
	var 护盾 := _数(u.get("shieldHp", u.get("shield", 0)))
	if 战斗中:
		段.append("生命 %s / %s（%s%%）· 护盾 %s · 气势 %s · 在场 %s" % [_数(生命), _数(满),
			_数(生命 / 满 * 100.0), 护盾, _数(battle_ctx.get("气势", 0.0) if 方 == "ally" else 0.0),
			"是" if 生命 > 0.0 else "已经倒下"])
	else:
		段.append("生命 %s / %s · 护盾 %s" % [_数(生命), _数(满), 护盾])
	段.append("装甲 %s · 防御 %s · 机动 %s · 移动 %s · 闪避 %s · 命中基础 %s" % [_数(u.get("armor", 0)),
		_数(u.get("defense", 0)), _数(u.get("eva", 0)), _数(u.get("mov", 0)), _数(u.get("eva", 0)),
		_数(u.get("aim", 0))])
	段.append("格斗 %s · 射击 %s · 觉醒 %s" % [_数(u.get("melee", 0)), _数(u.get("shoot", 0)),
		_数(u.get("awaken", 0))])
	var 特性 := str(u.get("trait", "")) if u.get("trait") != null else ""
	var 技: Array = u.get("abilities") if u.get("abilities") is Array else []
	# ★ MITH-3：秘银 v0.2 开着时，毛（U2）/ 克鲁兹（U6）的旧机制提示（maoNet / markBreak /
	#   supportAtk）已随 v0.1 标定方案退役 —— 这里把它们从悬停说明里清掉，并标注新机制的名字。
	var 秘银v02 := Params.秘银v02开(battle_ctx)
	var 键名 := str(u.get("key", ""))
	var 旧提示: bool = 秘银v02 and (键名 == "U2" or 键名 == "U6")
	if 旧提示 and 特性 in ["maoNet", "markBreak", "supportAtk"]:
		特性 = ""
	if 旧提示:
		技 = 技.filter(func(x): return not (str(x) in ["maoNet", "markBreak", "supportAtk"]))
	段.append("特性：%s" % (特性 if not 特性.is_empty() else "（没有登记）"))
	段.append("技能：%s" % ("、".join(技.map(func(x): return UiTheme.文本(x))) if not 技.is_empty() else "（没有登记）"))
	if 旧提示:
		段.append("〔秘银连携作战〕旧版提示已下线（毛 / 克鲁兹改用秘银角色牌与连携效果）")
	var 武: Array = u.get("weapons") if u.get("weapons") is Array else []
	段.append("武器（%d 把）：" % 武.size())
	if 武.is_empty():
		段.append("· （这台机体没有登记武器）")
	for w in 武:
		段.append(_武器行文字(w, 战斗中, 旧提示))
	if not 战斗中:
		return "\n".join(段)
	段.append("状态：%s" % " · ".join(_状态行(方, u)))
	var 增 := _增益文字们(u.get("buffs"))
	var 减 := _增益文字们(u.get("debuffs"))
	段.append("增益：%s" % ("、".join(增) if not 增.is_empty() else "（没有）"))
	段.append("减益：%s" % ("、".join(减) if not 减.is_empty() else "（没有）"))
	if 方 == "enemy":
		段.append_array(_意图行(u))
	var 觉 := _觉醒文字(u)
	if not 觉.is_empty():
		段.append(觉)
	return "\n".join(段)

## 一把武器的说明行。`条目` 收两种形状：① **模板武器字典**（局外）；② **运行期条目**
## `{"t": 模板武器, "cd": …, "uses": …}`（`Units.makeUnit` 造出来的战斗单位手上那种）。
## ★ MITH-3：`隐去旧特殊` = 秘银 v0.2 下毛 / 克鲁兹的旧机制（标定射击等）已退役，不再把
##   `special` 字段原样贴到悬停说明里。
func _武器行文字(条目: Variant, 战斗中: bool, 隐去旧特殊: bool = false) -> String:
	if not (条目 is Dictionary):
		return "· （认不出来的武器条目）"
	var 运行: Dictionary = {}
	var w: Dictionary = 条目
	if (条目 as Dictionary).get("t") is Dictionary:
		运行 = 条目
		w = 运行["t"]
	if w.is_empty():
		return "· （认不出来的武器条目）"
	var 段: Array = ["威力 %s" % _数(w.get("power", 0)), "命中 %s%%" % _数(w.get("hit", 0))]
	var 段数: Variant = w.get("hits")
	if 段数 == null:
		段数 = w.get("hitsMax")
	if 段数 != null:
		段.append("段数 %s" % _数(段数))
	var 范: Variant = w.get("range")
	if 范 is Array and (范 as Array).size() >= 2:
		段.append("射程 %s-%s" % [_数((范 as Array)[0]), _数((范 as Array)[1])])
	var 类: Variant = Reach.rangeKindOf(w)
	if 类 != null:
		段.append(str(类))
	段.append("出手 %s" % str(w.get("fire", "—")))
	段.append("伤害类型 %s" % str(w.get("dmgType", "—")))
	段.append("能力值 %s" % str(w.get("stat", "—")))
	段.append("冷却 %s 回合" % _数(w.get("cd", 0)))
	段.append("每场限次 %s" % _限次文字(w.get("uses")))
	段.append("解锁 Lv%s" % _数(w.get("unlock", 1)))
	if bool(w.get("大招", false)):
		段.append("大招")
	if bool(w.get("ignoreDef", false)):
		段.append("无视防御")
	if w.get("special") != null and not (隐去旧特殊 and str(w.get("special")) in ["maoNet", "markBreak", "supportAtk"]):
		段.append("特殊 %s" % str(w.get("special")))
	if 战斗中:
		var cd运行 := int(JsCompat.js_round(float(运行.get("cd", 0.0)))) if not 运行.is_empty() else 0
		段.append("★ 当前冷却 %s 回合" % UiTheme.文本(cd运行))
		if not 运行.is_empty():
			段.append("★ 剩余次数 %s" % _限次文字(运行.get("uses")))
	var 文 := "· 【%s】%s" % [str(w.get("name", "（无名）")), " · ".join(段)]
	var 说明 := str(w.get("desc", ""))
	if not 说明.is_empty():
		文 += "\n    效果：%s" % 说明
	return 文

## 敌方下一拍行动意图预告（内核纯函数 `Boss.bossAction`，与战斗屏单位卡同一份事实）。
func _意图行(u: Dictionary) -> Array:
	var out: Array = []
	if battle_ctx.is_empty():
		return out
	var 动作: Variant = Boss.bossAction(u, battle_ctx)
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
		文 += " · 期望 %s" % _数(期望)
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
		out.append("Boss 第 %s 阶段 · 伤害倍率 ×%s" % [_数(p.get("第几阶段", 1)), UiTheme.文本(p.get("伤害倍率", 1.0))])
	return out

## 觉醒状态（今天只有卫星国防军的 SEED 这一条；`FacSeed`/`Fac` 都是纯读）。
func _觉醒文字(u: Dictionary) -> String:
	if str(Fac.势力名(u)) != "卫星国防军":
		return ""
	if FacSeed.SEED已觉醒(u):
		return "觉醒：SEED 已觉醒（觉醒值 %s）" % _数(Fac.势力觉醒值(u))
	return "觉醒：SEED 累计 %s（还没觉醒）" % _数(FacSeed.SEED累计(u))

## `限次` / `uses` 的文字：`null` = 不限。
func _限次文字(v: Variant) -> String:
	return "不限" if v == null else _数(v)

## 任意数值 → 紧凑文字（浮点按 `JsCompat.js_round` 收成整数，与别处同一套口径）。
func _数(v: Variant) -> String:
	if v == null:
		return "—"
	if v is int:
		return str(int(v))
	if v is float:
		return str(int(JsCompat.js_round(float(v))))
	return str(v)

# ==========================================================================================
# 七、内部：状态快照 / 找单位 / 小工具
# ==========================================================================================

## 开战时存的那一份「我方开关表」（键 = 位号字符串）；UI 拿它画开关的初始状态。
func unit_switches() -> Dictionary:
	return _unit_switches.duplicate(true)

func current_node_result() -> Dictionary:
	return _node_result.duplicate(true)

func _set_screen(v: String) -> void:
	var 前屏 := screen
	screen = v
	# ★ 切屏时把「常驻盖屏」的那两类弹窗收掉（`结算` / `战斗`）：
	#   它们只该**被别人显式打开**（`boot.打开弹窗`），不该跟着屏幕自动挂在弹窗层上 ——
	#   全屏黑幕弹窗盖死战斗界面 / 第二个 ResultView 叠在大地图上，都是从这里来的。
	if v != 前屏:
		var 类 := str(modal.get("类型", ""))
		if 类 == "结算" or 类 == "战斗":
			modal = {}
	_refresh_modal()
	_emit()

func _emit() -> void:
	changed.emit()

func _fail(msg: String, extra: Dictionary) -> Dictionary:
	if msg.is_empty():
		msg = "命令被拒绝"
	_记错误(msg)
	_当前错误 = msg
	var d := {"ok": false, "为什么": msg, "屏幕": screen}
	for k in extra.keys():
		d[k] = extra[k]
	last = d.duplicate(true)
	errored.emit(msg)
	_emit()
	return d

## 记一条错误流水（★ UX-1 第 6 项：**保留最近 `错误上限` 条**，最老的先丢）。
func _记错误(msg: String) -> void:
	errors.append(msg)
	while errors.size() > 错误上限:
		errors.remove_at(0)

## 清空累积的错误流水（视图 / 测试随时可调；**不改任何业务状态**）。
## ★ 2026-10-19（UX-1 第 6 项）：`errors` 从前只增不减，一局打到后面能堆几百条挂在状态快照里。
func clear_errors() -> void:
	errors.clear()
	_当前错误 = ""

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
	# ★ DECK-2：`单机牌组模式` 开着 → 往内核选项里写一个 `单机牌组: true`
	#   （真正的判据永远是 `Params.单机牌组_开(ctx)`；关着的时候一个字段都不多 → 旧路径逐字不变）。
	var o := {}
	if run_state == null:
		o = {"战术卡牌": true, "已选战术牌": [], "藏品": []}
	else:
		o = RelicSystem.build_battle_options(run_state)
		o["战术卡牌"] = true
	if 单机牌组模式:
		o["单机牌组"] = true
	return o

## ★ DECK-2：`NodeResolver.开战()` 那条路（节点战 / 追击战）的**附加选项**。
## 与 `_build_battle_options()` 同一个来源（同一面旗），两条开战路走的规则不会对不上。
func _附加战斗选项() -> Dictionary:
	var o := {}
	if 单机牌组模式:
		o["单机牌组"] = true
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
	return _位号(slot_name) >= 0

## 格位 → 位号。★ UX-4：除了位名（`前1` / `后4`…），**整数位号与数字字符串也认**
## （`"7"` / `"后4"` 都 = 7），与 `NodeResolver.解析槽位()` 同一张表；越界 / 认不出 → −1。
func _位号(slot_name: String) -> int:
	var n := int(Fm.SLOTS())
	for i in n:
		if Fm.位名(float(i)) == slot_name:
			return i
	var v := NodeResolver.解析槽位(slot_name)
	if v >= 0 and v < n:
		return v
	return -1

## 一条出击记录里的位号（`slot` 写成位名 / 数字字符串 / 整数都认；纯字符串条目 / 认不出 → −1）。
## ★ UX-4：从前这里一律 `int(x.get("slot", -1))` —— 旧档 / 外部写入的 `"前3"`、`""` 会被
##   静默读成 0（全部机体挤在 0 号位），编队屏与战斗的站位就都错了。
func _条位号(x: Variant) -> int:
	if x is Dictionary:
		return NodeResolver.解析槽位((x as Dictionary).get("slot"))
	return -1

func _在出击里(s: RunState, unit_key: String) -> bool:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return true
	return false

## 这一台在出击名单里占的位号（不在 → −1）。★ 诊断 / 纯读用；`_摆上阵()` 走的是压实表那条路。
func _在出击的第几格(s: RunState, unit_key: String) -> int:
	for x in s.lineup:
		if x is Dictionary and str(x.get("key")) == unit_key:
			return _条位号(x)
	return -1

## 出击名单 → 「位号 → 键」压实表：同一位号只留**最后**一条；位号越界（<0 / ≥ SLOTS）的丢掉。
func _压实出击位(s: RunState) -> Dictionary:
	var 位表 := {}
	for x in s.lineup:
		if not (x is Dictionary):
			continue
		var k := str(x.get("key", ""))
		var 位 := _条位号(x)
		if k.is_empty() or 位 < 0 or 位 >= int(Fm.SLOTS()):
			continue
		位表[位] = k
	return 位表

## ★ UX-1 第 2 项：编队名单的**唯一性守卫**（幂等，随时可以调）。
##
## 保证三件事：**同一台机体最多出现 1 次**、**同一格位最多放 1 台**、
## **每一条的 `slot` 都是明确的位号**（★ UX-4 起；实现全在 `_规范编队槽位()`）。
## 反馈第 3 条里「明明还有空格却永远报出击位满了」的根因就是名册单里同一台占了 3 格、
## `lineup.size()` 涨到 8 > 上限 6；有了这道守卫，任何读取 / 修改编队的地方都不会再带病。
## 返回「这次真的改过名单」= true（没改 → false，状态逐字不动）。
func _清理重复占格(s: RunState = null) -> bool:
	return _规范编队槽位(s)

## ★ UX-4（M4 二轮试玩反馈 1）：把出击名单压成
## 「每台一条 · 每一格最多一条 · `slot` 永远是明确位号（0..SLOTS-1）」。
##
## 为什么**进编队屏 / 进战前确认时必须先跑一次**：旧档与外部写入的 `lineup` 可能是
## `{"key": k, "slot": ""}` / `{"key": k, "slot": "前3"}` / 纯字符串。从前一律 `int(slot)`
## 读 —— `int("") == 0`、`int("前3") == 0`，于是**全部机体挤在 0 号位**，编队屏画的站位
## 与战斗里真正站的位置永远对不上（作者反馈第 1 条的另一半根因）。
## 规则（幂等，玩家亲手摆的格位一个都不动）：
##   · `slot` 解析成 0..SLOTS-1 且没被占 → **原样保留**；
##   · 空 / 认不出（旧档）/ 与前面撞格 → `NodeResolver.默认位号(键, 序号)`，被占 → 第一个空位；
##   · 纯字符串条目 → 补成 `{"key": 键, "slot": 位}`（**不丢玩家机体**）；
##   · 同一台重复出现 → 只留第一条（这才是唯一性守卫要删的那种「重复记录」）。
## 返回「真的改了名单」= true。
func _规范编队槽位(s: RunState = null) -> bool:
	var 局 := s if s != null else run_state
	if 局 == null:
		return false
	var 上限 := int(Fm.SLOTS())
	var 见过键 := {}
	var 已占 := {}
	var 清: Array = []
	var 脏 := false
	for x in 局.lineup:
		var 键 := ""
		var 槽: Variant = null
		var 是字典 := x is Dictionary
		if 是字典:
			键 = str((x as Dictionary).get("key", ""))
			槽 = (x as Dictionary).get("slot")
		elif x is String:
			键 = str(x)
		else:
			脏 = true
			continue
		if 键.is_empty() or 见过键.has(键):
			脏 = true
			continue
		见过键[键] = true
		var 位 := NodeResolver.解析槽位(槽)
		if 位 >= 0 and 位 < 上限 and not 已占.has(位):
			# ★ 玩家指定的格位**原样保留**；只有「写法不标准」才改写同一数值。
			if not 是字典 or not (槽 is int) or int(槽) != 位:
				脏 = true
		else:
			位 = _空位兜底(键, 清.size(), 已占)
			脏 = true
		if 位 < 0:
			# 8 格全满（`deploy_limit ≤ 7 < SLOTS`，正常玩到不了）：留一条但不占格。
			清.append({"key": 键, "slot": -1})
			continue
		已占[位] = true
		清.append({"key": 键, "slot": 位})
	if not 脏:
		return false
	局.lineup = 清
	return true

## 兜底位号：先问 `NodeResolver.默认位号()`（= 默认五人队的写死位）；被占了 → 第一个空位；全满 → −1。
func _空位兜底(键: String, 序: int, 已占: Dictionary) -> int:
	var 上限 := int(Fm.SLOTS())
	var 位 := NodeResolver.默认位号(键, 序)
	if 位 >= 0 and 位 < 上限 and not 已占.has(位):
		return 位
	for i in 上限:
		if not 已占.has(i):
			return i
	return -1

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

## `位表` 里没用掉的最小格位（诊断 / 兜底用）。★ 2026-10-19：`_摆上阵()` 改成「来自旧格就互换、
## 没有旧格就让占者下阵」之后，这条兜底不再参与换位判定 —— 留着给排查旧档用（纯读，不改状态）。
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
	# ★ MITH-3 结算层：本场「触发连携次数 / 打出 TDD-1 数」直接抄内核 `战况计数`（表现层不自己算）。
	var 计: Dictionary = battle_ctx.get("战况计数") if battle_ctx.get("战况计数") is Dictionary else {}
	var 结算: Dictionary = 内核
	return {
		"胜": bool(结算.get("胜", false)), "结果": _战果文字(),
		"原因": str((battle_ctx.get("result") as Dictionary).get("原因", "")) if battle_ctx.get("result") is Dictionary else "",
		"回合数": int(float(battle_ctx.get("turn", 0.0))) if not battle_ctx.is_empty() else 0,
		"触发连携次数": int(计.get("触发连携", 0)),
		"打出TDD1数": int(计.get("打出TDD1", 0)),
		"秘银v02": Params.秘银v02开(battle_ctx),
		"格类型": str(结算.get("格类型", "")), "通关": bool(run_state.status == "胜利") if run_state != null else false,
		"结束": bool(结算.get("结束", false)), "扣": int(结算.get("扣", 0)),
		"希望": int(结算.get("希望", 0)), "源碳": int(结算.get("源碳", 0)),
		"券": 结算.get("券", null), "藏品": 结算.get("藏品", null), "额外编制": 结算.get("额外编制", null),
		"零件": 结算.get("零件", null), "额外": 结算.get("额外", {}), "奖励档": str(结算.get("奖励档", "")),
		"带伤": int(结算.get("带伤", 0)), "倒下": int(结算.get("倒下", 0)),
		"回血": 结算.get("回血", {}), "名册回血前": 前, "本场战术牌": 打牌, "结算": 结算,
	}

## 自动弹窗的**唯一**判据（D-06 / 「面板溢出与叠加」根治）：
##   ① `pending_card_picks` 非空 → 弹「三选一」；
##   ② `pending_card_picks` 变空、而且当前弹的正是「三选一」→ 收起来（`modal = {}`）。
##   ★ 这里**不再**在 `screen == "battle"` 时塞「战斗」、也不在 `screen == "result"` 时塞「结算」：
##     前者是一整块全屏黑幕弹窗盖死战斗界面（「推进下一回合」点不到），
##     后者会在切回 `map` 时叠出**第二个** `ResultView` 盖在大地图上。
##     这两类现在只能由 `boot.打开弹窗("战斗" / "结算", …)` 显式打开。
##   ★ `结算` / `战斗` 的「切屏就清空」在 `_set_screen()` 里做（那才是唯一知道「切屏了」的地方）。
func _refresh_modal() -> void:
	if run_state != null and not run_state.pending_card_picks.is_empty():
		modal = {"类型": "三选一", "数据": run_state.pending_card_picks.duplicate()}
		return
	if str(modal.get("类型", "")) == "三选一":
		modal = {}
