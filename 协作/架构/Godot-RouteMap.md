<!-- 自动生成：node godot/tools/build_godot_routemap.mjs · 严禁手改 -->
# Godot 路由地图 · RouteMap 主索引（AST 符号级）

> **★ 这是索引页（自限 ≤ 8,000 估算 token），不是全量文档。** 要「某文件的函数表 / 某模块依赖谁」：① `grep` 明细页的 §2（职责表）/ §3（依赖矩阵），或 ② `node godot/tools/route_query.mjs <符号|文件路径>` 只取切片；**别整份读明细页，也别整份读 `Godot-AST依赖清单.json`（1.4 MB）**。
> **一句话**：Godot 版的「**免派定位探针**」——「哪个文件负责什么 / 某个函数在第几行 / 谁依赖谁 / 谁在偷偷反向依赖」，`grep` 这两页或跑 `route_query.mjs` 即可，不必再派探查子代理。
> **口径**：所有数字与行号都由 `godot/tools/build_godot_routemap.mjs` **现扫 `godot/**/*.gd`** 得出，**一个行号都不写死**；本工具**不加载、不执行** Godot，所以全是「**静态扫描识别**」值，不是运行时真值。文件里**故意不写生成时间**（否则 `--check` 永远红）。
> **扫描范围**：`godot/` 下全部 `.gd`（排除 `.godot/` 等点开头目录），按 `core/` `session/` `presentation/` `tests/` 分层；依赖边 = 代码里的 `class_name` 引用（整词精确匹配，注释与字符串先抹掉）+ `preload/load` 的 `res://` 字面量。
> **已知限制**：只到**词法 + 符号表**级别（不建 GDScript AST、不做值流 / 别名 / 反射 / 动态 `load(变量)`）；顶层 `var` / `signal` / `enum` 不进符号表；`presentation → core` 的写接口只认 `类名.函数名(` 直接静态调用（`callv` / `Callable` / 字符串派发认不出）。
> **同步纪律**：`.gd` 一改本文件即过期 —— 交单前跑 `node godot/tools/build_godot_routemap.mjs` 重建，再跑 `--check`（返回码 `0` = 三份生成物逐字节一致）。**别手改**。
> **当前快照（静态扫描识别值）**：`godot/` 下 **190** 个 `.gd` / **70148** 行 / **3497475** 字节 · 估算 **1057793** token（注释 **17.9%**）· `class_name` **110** 个 · 顶层 `const` **631** / `func` **4587** 个（`static func` **2688**、公开 **2225**、内类 **4**）· 依赖边 **1480**（生产层 **895**，其中跨层 **189**）· 解不出的 `res://*.gd` **0** 处 · 非 `.gd` 资源 **58** 处（目录路径 **31** 处不计）· **架构分层违规 0 处**。

---

## §0 总览统计（按四层）

> **读法**：`出边` / `入边` = 本层指向别层 / 别层指向本层的依赖边数；`跨层出边` 越大越要盯 §4。

| 层 | 文件 | 行数 | 字节 | 估算 token | 注释占比 | class_name | const | func | 出边 | 入边 | 跨层出边 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **core** | 78 | 28877 | 1346419 | 407546 | 18.6% | 78 | 362 | 2277 | 628 | 1191 | 0 |
| **session** | 12 | 5013 | 216112 | 64536 | 11.8% | 12 | 32 | 510 | 112 | 126 | 93 |
| **presentation** | 25 | 9062 | 422379 | 129123 | 23.2% | 15 | 123 | 682 | 122 | 117 | 63 |
| **tests** | 68 | 26409 | 1479163 | 446536 | 16.8% | 5 | 96 | 1090 | 585 | 46 | 550 |
| **其他** | 7 | 787 | 33402 | 10052 | 12.4% | 0 | 18 | 28 | 33 | 0 | 33 |
| **合计** | **190** | **70148** | **3497475** | **1057793** | **17.9%** | **110** | **631** | **4587** | **1480** | — | **189** |

---

## §0.5 Token 体积 Top 20

> **估算 token 口径**：`token ≈ CJK 字符数 × 1.0 + 其余字符数 ÷ 3.5`（CJK = 汉字 + 全角标点，按 Unicode 码点一个算一个）。这是**估算**，不是任何分词器的真值。
> **注释占比口径**：以 `#` 开头的行（含前导空白后以 `#` 开头）与代码行尾 `# …` 的 **UTF-8 字节**合计 ÷ 文件总字节；**字符串字面量里的 `#` 不算**，行尾换行符不计。
> **全仓合计**：**3497475** 字节 / 估算 **1057793** token / 注释 **626539** 字节（**17.9%**）；下面 Top 20 合计 **345066** token，占全仓 **32.6%** —— 改热路径之前先看这张表。
> **CR-1 两个示范文件的改前 / 改后对照、以及工程单里手写字节数与实测值的差异说明**，已搬到明细页 §0.5b（索引页省 token）。

| 排名 | 文件 | 层 | 行 | 字节 | 估算 token | 注释字节 | 注释占比 |
|---|---|---|---|---|---|---|---|
| 1 | `tests/unit/test_session_flow.gd` | tests | 1898 | 107039 | 32341 | 17864 | 16.7% |
| 2 | `core/battle/celestial_v01.gd` | core | 2180 | 104010 | 31713 | 12607 | 12.1% |
| 3 | `tests/unit/test_celestial_v01.gd` | tests | 1650 | 98744 | 29697 | 12253 | 12.4% |
| 4 | `core/battle/atx_three.gd` | core | 1581 | 68578 | 20580 | 1276 | 1.9% |
| 5 | `tests/unit/test_atx_three_v01.gd` | tests | 1054 | 62109 | 18744 | 11289 | 18.2% |
| 6 | `core/battle/calc.gd` | core | 1182 | 57365 | 17327 | 8523 | 14.9% |
| 7 | `tests/unit/test_unit_deck_system.gd` | tests | 923 | 56435 | 17098 | 8199 | 14.5% |
| 8 | `tests/unit/test_run_map.gd` | tests | 1035 | 55018 | 16541 | 6942 | 12.6% |
| 9 | `tests/unit/test_mithril_v03.gd` | tests | 885 | 54973 | 16518 | 7193 | 13.1% |
| 10 | `core/battle/mithril_v03_cards.gd` | core | 1069 | 51022 | 15481 | 6304 | 12.4% |
| 11 | `session/game_session.gd` | session | 1320 | 49675 | 14760 | 5631 | 11.3% |
| 12 | `core/run/node_resolver.gd` | core | 958 | 46768 | 14188 | 8400 | 18.0% |
| 13 | `tests/unit/test_presentation_smoke.gd` | tests | 876 | 46740 | 14175 | 8897 | 19.0% |
| 14 | `core/battle/deck_flow.gd` | core | 997 | 44338 | 13416 | 2378 | 5.4% |
| 15 | `tests/unit/test_class_cards.gd` | tests | 722 | 43781 | 13281 | 8371 | 19.1% |
| 16 | `tests/unit/test_class_heavy_cmd.gd` | tests | 712 | 41496 | 12517 | 8232 | 19.8% |
| 17 | `tests/unit/test_cr2_pipelines.gd` | tests | 783 | 39461 | 11974 | 7310 | 18.5% |
| 18 | `presentation/run_map/map_view.gd` | presentation | 711 | 38443 | 11867 | 14416 | 37.5% |
| 19 | `tests/unit/test_atx_v03_wiring.gd` | tests | 675 | 38124 | 11490 | 6753 | 17.7% |
| 20 | `tests/unit/test_atx_faction_v03.gd` | tests | 653 | 37954 | 11358 | 6556 | 17.3% |

> **规则 ⑦ 体积警告**（未登记进 `SIZE_RATCHET` 且 > **1000** 行 或 > **12000** 估算 token 的新 `.gd`）：**0 个文件** ✓（D1~D4 拆出的新文件都在 1000 行 / 12000 token 以内；已登记的既有大文件见 §4.5）

> **规则 ⑧ 注释占比警告**：未登记进 `COMMENT_RATCHET` 且超过本层阈值（生产 15.0% / `tests/**` 20.0%）的 `.gd` 共 **76 个** ✗ —— 全表见明细页 §4.6b。

---

## §1 速查路由表（按现象 / 机制查文件）

> **怎么用**：手上只有现象（「伤害不对」「大招打不出去」「地图走不动」）时，先在这里找**责任文件**，再进明细页 §2 看该文件的职责与导出面。
> **行号**：左两列**人工维护**（导航语义扫不出来），`文件:行号` 全部现扫源码得出；打 `—` = 该符号当前找不到（改名 / 删了），不是脚本坏了。

| 板块 | 现象 / 机制 | 去哪看（`文件:行号`，`/` 分隔同文件的多个锚点） |
|---|---|---|
| 一次战斗的算法 | 命中率 / 暴击率 / 伤害主公式 / 单次攻击结算 | `core/battle/calc.gd:67/98/227/584` |
| 一次战斗的算法 | **单目标攻击结算（唯一攻击结算入口）**：改目标 / 事后钩子 / 散布死 | `core/battle/flow.gd:164` |
| 一次战斗的算法 | 装甲 / 破防 / 防御乘子 / 能力值系数（减免管线） | `core/battle/calc.gd:26/29/35/223` |
| 一次战斗的算法 | 射程分类 / 被挡 −20 / 落点 / 可达判定 | `core/battle/reach.gd:12/60/90/32/238` |
| 一次战斗的算法 | 阵型几何：行 / 列 / 位名 / 阻挡位 / 对位 / 相邻位 | `core/battle/fm.gd:43/65/86/89/102/108` |
| 一次战斗的算法 | 修理量（奶妈回血） | `core/battle/calc.gd:411` |
| 一次战斗的算法 | 标定经济（产标 / 层数 / 点名 / 引爆） | `core/battle/calc.gd:473/523/414` |
| 一次战斗的算法 | 武器能不能打 / 大招能不能打（不可打原因） | `core/battle/calc.gd:370/383` · `core/battle/deck_flow.gd:463/587` |
| 牌组与手牌 | 手牌上限 / 战意（气势）参数 | `core/battle/params.gd:427/469/449` |
| 牌组与手牌 | 开局发牌 / 阶段初检查 / 抽牌与弃牌 / 打出大招与副武器 / **武器栏换装栈：`压栈武器栏` · `弹栈武器栏`** | `core/battle/deck_flow.gd:12/155/526/608/348/369` |
| 牌组与手牌 | **会话子模块（D1 拆出）**：上排 / 下排 / 公有牌 · 武器栏 / 大招槽 / 出牌 · 开战与节点结算 · 展示与悬停说明 · 大地图黑市休整奇遇 · 实时监视 | `session/battle_hand_view.gd:123/316` · `session/battle_deck_view.gd:13/243` · `session/battle_flow.gd:206` · `session/run_facade.gd:32` · `session/display_helpers.gd:97` · `session/tooltip_text.gd:43` · `session/live_monitor.gd:6` |
| 牌组与手牌 | 单机牌组初始化（专属库 / 公有库 / 起手 / 衍生卡） | `core/battle/setup.gd:221/83/190` |
| 牌组与手牌 | 副牌组（结构化牌库：放入 / 抽一张 / 三级档） | `core/battle/sub_deck.gd:43/146/102/61` |
| 牌组与手牌 | AI 自动补打主武器（结束回合） | `core/battle/ai_deck.gd:10` |
| 牌组与手牌 | **出牌判定（不可打原因 / 目标方 / 找执行机体）** | `core/battle/card_play.gd:18/47/84` |
| 卡牌与势力机制 | 32 张战术牌的**效果本体**（声明式算子） | `core/battle/card_effects.gd:112/138` |
| 卡牌与势力机制 | 职业牌 / 职业机制（命中修正 / 伤害倍率 / 改写武器） | `core/battle/class_cards.gd:68/269/380` |
| 卡牌与势力机制 | 秘银 v0.3（连携 / 身份对口 / 角色专属） | `core/battle/mithril_v03_cards.gd:146/177/203` |
| 卡牌与势力机制 | 天人 v0.1（TRANS-AM / 武力介入 / 粒子耗尽） | `core/battle/celestial_v01.gd:168/344/227` |
| 卡牌与势力机制 | ATX：三小强 / 双子 / 势力牌 / 神赌 / 强运 / 烟雾 / 段数改写 / 筹码库 | `core/battle/atx_three.gd:144` · `core/battle/atx_duo.gd:169` · `core/battle/atx_faction.gd:137` · `core/battle/atx_godsbet.gd:149` · `core/battle/atx_luck.gd:58` · `core/battle/atx_smoke.gd:152` · `core/battle/atx_rewrite.gd:167` · `core/battle/atx_chips.gd:189` |
| 卡牌与势力机制 | 势力特色框架（17 个钩子 + 注册表） | `core/battle/fac.gd:45/160/36/17` |
| 卡牌与势力机制 | **规则钩子注册表（阶段 / 修正 / 出牌门槛）**：`顺序` 表定派发序，通用内核只许调它的接口 | `core/battle/rule_hooks.gd:83/91/102/129` |
| 卡牌与势力机制 | 势力·ATX（含 v0.2 卡表） | `core/battle/fac_cb.gd:22/34` · `core/battle/fac_atx.gd:52` |
| 卡牌与势力机制 | 势力·秘银（SRT 交叉训练 / 挂标定 / 倒下接力） | `core/battle/fac_mith.gd:53/90/144` |
| 卡牌与势力机制 | 势力·月球王国（光环 / 残月追加 / 不动如山） | `core/battle/fac_moon.gd:51/99/205` |
| 卡牌与势力机制 | 势力·天人（v0.1 大招牌 TRANS-AM / 太阳炉） | `core/battle/celestial_v01.gd:168/125` |
| 战斗流程与对手 | 参数总入口（战斗结构开关一律从这里读） | `core/battle/params.gd:14/26/153/309` |
| 战斗流程与对手 | 回合流程：回合开始 / 单位动作 / 结算一次行动 | `core/battle/phase_flow.gd:64` · `core/battle/flow.gd:76/293/20` |
| 战斗流程与对手 | 开一场 / 跑完一场 / 结束判定 / 回合结束 | `core/battle/setup.gd:470/531/14/25` |
| 战斗流程与对手 | 记录 / 战意 / 嘲讽 / 镜甲 / 自爆（`btl.gd` 留高频转发，实现已搬进子模块） | `core/battle/btl.gd:11/39` · `core/battle/battle_log.gd:6` · `core/battle/morale.gd:54` · `core/battle/guard.gd:6/193/231` |
| 战斗流程与对手 | **内核子模块（D3 拆出）**：卡牌执行 / 阶段推进 / 敌方意图 | `core/battle/card_exec.gd:197/111` · `core/battle/phase_flow.gd:64/108` · `core/battle/intent.gd:28/119` |
| 战斗流程与对手 | AI：憋大招 / 目标打分 / 武器池 / 选目标 / 两方出手 | `core/battle/ai.gd:8/23/35/81/185/232` |
| 战斗流程与对手 | Boss 站桩脚本（间隔 / 半血换阶段 / 大技能） | `core/battle/boss.gd:115/44/69/100` |
| 战斗流程与对手 | 难度：回合上限 / 站位权重 / 敌方强化 | `core/battle/diff.gd:5/22/35/48` |
| 战斗流程与对手 | 单位构造 / 等级 / 阵营与职业判定 | `core/battle/units.gd:67/248/26/185` |
| 战斗流程与对手 | 编成词条（确定性修饰：作用 / 叠加 / 到单位） | `core/battle/traits.gd:5/26/78` |
| 战斗流程与对手 | 藏品在战斗里的数值落地 | `core/battle/relic_battle.gd:175/72/102` |
| 数据与肉鸽 | 全局数据表（角色 / 敌人 / 关卡 / 卡 / 藏品 / 零件） | `core/data/db.gd:14` · `core/data/game_data.gd:21` · `core/data/game_catalog.gd:64/109` · `core/battle/data_fn.gd:27` |
| 数据与肉鸽 | 卡包数据（天人 / 秘银 / ATX / 职业分类牌：每包自带 `"结构"` 声明，卡 `id` 全局唯一） | `data/cards/*.json` · `session/data_loader.gd:7` |
| 数据与肉鸽 | 卡包加载与结构校验（扫描 `data/cards/*.json` → 校验 `结构` 类型 → 登记全局 `id`） | `session/data_loader.gd:73/91/141/13` |
| 数据与肉鸽 | 地图生成（分层正方形 / 存在率 / 割点 / 推进剂余量） | `core/run/map_generator.gd:45/247/164` |
| 数据与肉鸽 | 地图移动（邻接 / 隧道 / 退路成本 / 出口规则） | `core/run/map_navigator.gd:106/198/219/293` |
| 数据与肉鸽 | 节点结算（编成 / 奖励档 / 词条组 / 增援波次） | `core/run/node_resolver.gd:72/170/188` |
| 数据与肉鸽 | 一局状态（日志 / 格子 / 等级 / 希望 / 存档字典） | `core/run/run_state.gd:197/244/124` |
| 数据与肉鸽 | 编成 / 名册 / 零件 / 藏品（局外） | `core/run/deck_builder.gd:281` · `core/run/roster_manager.gd:70` · `core/run/part_system.gd:117` · `core/run/relic_system.gd:57` |
| 数据与肉鸽 | 版本号（界面 / 存档 / 录像都读它） | `core/version.gd:2` |
| 数据与肉鸽 | JS 兼容层（truthy / 数字规整）/ 稳定排序 / 随机数 | `core/util/js.gd:9/54` · `core/util/js_compat.gd:14` · `core/util/rng.gd:12/27` |
| 会话与表现层 | **界面唯一入口**（GameSession 门面：开局 / 存档 / 进战斗 / 节点结算） | `session/game_session.gd:106/153/202/185` |
| 会话与表现层 | 数据装配（JSON → Db）/ 存档落盘 | `session/data_loader.gd:16` · `session/save_service.gd:41/61` |
| 会话与表现层 | 主题 / 提示 / 单位卡 / 顶栏 / 弹层（表现层公共件） | `presentation/theme/ui_theme.gd:174` · `presentation/widgets/hover_tooltip.gd:16` · `presentation/widgets/unit_card.gd:3` · `presentation/widgets/top_bar.gd:39` · `presentation/widgets/modal_layer.gd:9` |
| 会话与表现层 | 四个主画面：启动 / 菜单 / 战斗 / 结算 | `presentation/boot/boot.gd:43` · `presentation/menus/menu_view.gd:38` · `presentation/battle/battle_view.gd:180` · `presentation/battle/result_view.gd:40` |
| 会话与表现层 | **战斗画面面板（D2 拆出）**：棋盘 / 手牌栏 / 左牌库 / 战报栏 / 拖拽瞄准 / 演出播放（`battle_view.gd` 组装 + 转发） | `presentation/battle/board_panel.gd:93` · `presentation/battle/hand_panel.gd:75` · `presentation/battle/deck_sidebar.gd:124` · `presentation/battle/log_panel.gd:38` · `presentation/battle/drag_aim.gd:186` · `presentation/battle/battle_fx_player.gd:12` |
| 会话与表现层 | 肉鸽画面：大地图 / 编队 / 商店 / 休整 / 事件 / 选卡 / 名册 | `presentation/run_map/map_view.gd:63` · `presentation/run_map/formation_view.gd:119` · `presentation/menus/shop_view.gd:24` · `presentation/menus/rest_view.gd:21` · `presentation/menus/event_view.gd:25` · `presentation/menus/pick_card_view.gd:22` · `presentation/menus/roster_view.gd:29` |
| 会话与表现层 | 测试唯一入口 / 原生黄金样例对拍 | `tests/run_tests.gd:50` · `tests/native_golden_runner.gd:12` · `tests/golden_io.gd:2` · `tests/golden_compare.gd:3` |

---

## §4 架构分层与耦合合规审计

**结论：`violations: []`（0 处）** —— 八条规则本次全部通过（①~④ 跨层依赖 + ⑤ 内核→势力棘轮 + ⑥ 豁免文件表外引用 + ⑦ 体积棘轮 + ⑧ 注释占比棘轮）。

| # | 规则 | 违规 | 检查了什么 |
|---|---|---|---|
| ① | `core/**` 不得引用 `session/**` | 0 | 逐文件比 `dependsOn` 的目标层（含 `preload/load` 解析到的 `.gd`） |
| ② | `core/**` 不得引用 `presentation/**` | 0 | 同上 |
| ③ | `session/**` 不得引用 `presentation/**` | 0 | 同上（`层间豁免` 登记过的 (from,to) 除外，见 §4.2） |
| ④ | `presentation/**` 不得绕过 `GameSession` 直接调 `core/**` 的**写接口** | 0 | 扫全仓 `类名.函数名(` 直接静态调用；函数名首字是写动词或整名在白名单里即判写接口 |
| ⑤ | **通用内核文件 → 势力文件**引用次数 ≤ 棘轮基线 **120**（当前 **117**） | 0 | 见 §4.0：`dependsOn` 里指向势力文件的 `n` 之和（与 CodeReview 报告 §3 同一口径）；**基线只许下调** |
| ⑥ | **豁免注册表文件**（`fac.gd` / `rule_hooks.gd`）在**登记表 / 分派区之外**对势力 / 职业模块的引用 = **0** | 0 | 见 §4.0c：现扫允许区域（`顺序` / `ORDER` 声明块 + `match 势力` + `势力 ==` 的 `if`），区域外出现 28 个模块任意一个即违规 |
| ⑦ | **体积棘轮**：`SIZE_RATCHET` 登记的 21 个既有大文件，`estTokens` 只许下降 | 0 | 见 §4.5：> 1000 行或 > 12000 token 的既有文件逐个登记上限，**只许下调**；未登记的新大文件只进 §0.5 警告 |
| ⑧ | **注释占比棘轮**：`COMMENT_RATCHET` 登记的 79 个文件必须一直待在**本层阈值**以内（生产 > 15.0% / 测试 > 20.0% 即违规；未登记的只进 §0.5 警告） | 0 | 见 §4.6：注释字节 ÷ 文件总字节（与「注释约定」同一口径）；登记表**只有路径**、判据就是本层阈值 |

```json
"violations": []
```

### §4.0 规则 ⑤ 棘轮：通用内核 → 势力模块

> **势力文件** = `core/battle/` 下前缀命中 `atx_` / `fac_atx` / `fac_cb` / `fac_mith` / `fac_moon` / `celestial_` / `mithril_` / `colony_` / `colonial_` / `moon_` / `shadow_` 的 `.gd`（**不含 `fac.gd` / `rule_hooks.gd` 两个注册表**）；**通用内核** = `core/battle/` 其余 + `core/run/**`；**次数** = 该文件 `dependsOn` 指向势力文件的 `n` 之和。
> **棘轮基线**：`CORE_TO_FACTION_RATCHET_MAX = 120` —— **只许往下调，不许往上改**；超过就进 `violations`，`--check` 直接红。**当前值 117 / 基线 120** → **当前值 117 低于基线 120，可将基线下调到 117**。

统计范围：**41** 个通用内核文件 / **27** 个势力文件。**合计 117 次**，集中在：`battle/card_exec.gd` 23 · `battle/weapon_exec.gd` 18 · `battle/deck_flow.gd` 14 · `battle/calc.gd` 13。**逐模块明细（17 行）见明细页 §4.0。**

**规则 ⑤ 的注册表文件**（`规则五豁免文件` = `core/battle/fac.gd` / `core/battle/rule_hooks.gd`：本身**必须**点名势力 / 职业模块的派发 · 判定注册表；单列出来是为了不让它们变成「看不见的耦合」—— 数字照样打印，只是**不进棘轮**）：

| 注册表文件 | 引用的势力文件数 | 引用次数（不计入 ⑤） | 明细（`→ 势力文件(n)`） |
|---|---|---|---|
| `core/battle/fac.gd` | 3 | 17 | `fac_moon.gd`(8) `fac_mith.gd`(6) `fac_cb.gd`(3) |
| `core/battle/rule_hooks.gd` | 13 | 128 | `colonial_v01.gd`(26) `moon_v02.gd`(20) `shadow_v02.gd`(19) `celestial_v01.gd`(15) `atx_three.gd`(14) `atx_duo.gd`(7) `atx_faction.gd`(7) `atx_chips.gd`(6) `atx_smoke.gd`(6) `atx_godsbet.gd`(5) `atx_luck.gd`(1) `fac_atx.gd`(1) `mithril_v03_cards.gd`(1) |

> 合计 **145** 次。两处都是**收敛点**（`fac.gd` = 势力特色注册表，`rule_hooks.gd` = 规则钩子 / 出牌门槛顺序表）：其它通用内核文件只许调它们的接口，自己不许点名势力模块。

**势力 → 势力横向引用**（不计入规则 ⑤；这里只列**跨谱系**的，ATX 家族内部的见明细页 §4.4）：

| from | to | n | 谱系 |
|---|---|---|---|
| `core/battle/atx_duo.gd` | `core/battle/celestial_v01.gd` | 2 | ATX → 天人 |
| `core/battle/atx_faction.gd` | `core/battle/mithril_v03_cards.gd` | 1 | ATX → 秘银 |
| `core/battle/atx_three.gd` | `core/battle/mithril_v03_cards.gd` | 1 | ATX → 秘银 |
| `core/battle/colonial_deck.gd` | `core/battle/atx_luck.gd` | 1 | 其他 → ATX |
| `core/battle/fac_moon.gd` | `core/battle/moon_v02.gd` | 1 | 月球 → 其他 |

> 另有 **45** 条同谱系（ATX 家族内部）横向引用；全表（50 条边 / 475 次）见明细页 §4.4。

### §4.0c 规则 ⑥ 豁免文件审计：登记表 / 分派区**之外**点名模块 = 违规

> **为什么**：⑤ 把 `fac.gd` / `rule_hooks.gd` 列为豁免（它们**必须**点名模块），**豁免必须划边界** —— 否则往注册表里搬一段「是不是某个势力」就能让 ⑤ 变好看。
> **判据（现扫，不写死行号）**：允许区域 = ① 顶层 `const` / `static var` 的 `{…}` `[…]` 声明块（`顺序` / `ORDER` / 映射表）② `match …:` 块 ③ 条件含 `势力 ==` / `势力 in` 的 `if` / `elif` 块；**区域外**出现任何势力 / 职业模块名即违规。

| 注册表文件 | 允许区域 | 区内引用行 | 区外引用行 | 结果 |
|---|---|---|---|---|
| `core/battle/rule_hooks.gd` | `const` / `static var` 的 `{…}` `[…]` 声明块（= `顺序` 派发顺序表与按处理者映射表） | 47 | 0 | **✓ 0 违规** |
| `core/battle/fac.gd` | `const ORDER` 声明块 + `match 势力:` 块 + 条件里出现 `势力 ==` / `势力 in` 的 `if` / `elif` 块 | 17 | 0 | **✓ 0 违规** |

- **0 违规** ✓ 两个注册表文件的模块引用（64 行 / 28 个模块）全部在允许区域里。

### §4.1 审计证据：表现层对 `core/**` 的**读接口**调用（聚合）

> 这些**不算违规**（只读、纯计算、无副作用），共 **73** 处 / **46** 个符号 —— 列出来是为了证明第 ④ 条不是「没扫到」而是「扫到了但都是读接口」。**逐条清单（调用方 × 符号 × n）见明细页 §4.1。**

| 目标模块 | 只读符号数 | 调用次数 |
|---|---|---|
| `core/util/js_compat.gd` | 1 | 26 |
| `core/battle/fm.gd` | 6 | 21 |
| `core/run/roster_manager.gd` | 8 | 12 |
| `core/run/map_navigator.gd` | 8 | 11 |
| `core/run/part_system.gd` | 3 | 6 |
| `core/run/relic_system.gd` | 3 | 6 |
| `core/run/node_resolver.gd` | 5 | 5 |
| `core/battle/boss.gd` | 4 | 4 |
| `core/run/map_generator.gd` | 3 | 3 |
| `core/battle/ai.gd` | 1 | 2 |
| `core/run/deck_builder.gd` | 1 | 2 |
| `core/battle/params.gd` | 1 | 1 |
| `core/util/rng.gd` | 1 | 1 |
| `core/version.gd` | 1 | 1 |

### §4.2 层间豁免白名单（**唯一允许的反向依赖例外**，明示出来供 Reviewer 复核）

> 共 **1** 条，全部来自脚本里的 `层间豁免` 常量（**只许加行、不许放宽到文件级**，必须写明 `to` + 理由）。没有列在这里的反向依赖一律进 `violations`。

| 规则 | from | to | 符号 | n | 理由 | 实际调用 |
|---|---|---|---|---|---|---|
| ③ | `session/game_session.gd` | `presentation/theme/ui_theme.gd` | UiTheme | 1 | 复用纯格式化函数 `UiTheme.文本()`（数字→千分位文本；无状态、不建节点、不碰 Control），不是反向依赖画面 | UiTheme.文本×1 |

### §4.3 其余自检项（信息项，不算违规）

- **自环依赖**（文件依赖自己）：**0** 处。
- **重复 `class_name`**：**0** 处。
- **双向依赖对**：**59** 对（明细见明细页 §3.5）。
- **解不出的 `res://*.gd` 路径**：**0** 处。
- **不是 `.gd` 的资源路径**（`.tscn` / `.ttf` / `.json` 等，不进依赖图）：**58** 处（逐条见 JSON 的 `nonGdResourcePaths`）。
- **目录路径**（`res://data/js` 这种没有扩展名的，不是资源、不进依赖图）：**31** 处。
- **缺锚点**（§1 里打 `—` 的符号）：**0** 处。

### §4.5 规则 ⑦ 体积棘轮（`SIZE_RATCHET`：token 只许下降、不许上调）

> **为什么**：拆过的大文件还会再长回去。超过 **1000** 行 或 **12000** token 的**既有**文件逐个登记上限，**只许下调**；超过登记值即 `violations`。**未登记**的新大文件只进 §0.5 的警告清单（不判红，但要求先拆再加功能）。
> **当前**：登记 **21** 个 · 上限合计 **356693** token · 超限 **0** 个 · 未登记且超限的新文件 **0** 个。**登记表全表（当前值 / 余量 / 行数）见明细页 §4.5b。**
- **最大的五个**：`tests/unit/test_session_flow.gd`=33587 · `core/battle/celestial_v01.gd`=32680 · `tests/unit/test_celestial_v01.gd`=30588 · `core/battle/atx_three.gd`=21396 · `tests/unit/test_atx_three_v01.gd`=19307

### §4.6 规则 ⑧ 注释占比棘轮（`COMMENT_RATCHET`：登记文件必须一直待在本层阈值以内）

> **为什么**：**历史叙述、来源标签、直译式注释**会越堆越厚（CR-1 ~ CR-4 的清理量就是证据）。登记清单里的文件一旦超过**本层阈值**（生产 **15.0%** / `tests/**` **20.0%**）即 `violations`；**登记表只有路径、不记数值** —— 没越阈值往里面加注释是允许的。未登记且超阈值的只进 §0.5 警告。
> **当前**：登记 **79** 个 · 超阈值 **0** 个 · 未登记且超阈值 **76** 个（明细页 §4.6b 有全表）。
