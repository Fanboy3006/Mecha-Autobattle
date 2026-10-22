<!-- 自动生成：node godot/tools/build_godot_routemap.mjs · 严禁手改 -->
# Godot 路由地图 · RouteMap 明细页（AST 符号级）

> **这是明细页**：索引页 `Godot-RouteMap.md` 的 §2 / §3 / §4.1 明细 / §4.4 全表 + §5 怎么用。**会话开机不必读它**。
> **别整份读**：定位某个文件 / 符号用 `grep` 本页，或 `node godot/tools/route_query.mjs <符号|文件路径>` 只取切片。口径、扫描范围、已知限制与索引页同源（同一个脚本、同一次扫描）。
> **体积（D1 口径）**：索引页 `Godot-RouteMap.md` **25796** 字节 / 估算 **7861** token（上限 **8000**）**✓**。本页体积见 `node godot/tools/build_godot_routemap.mjs` 的终端输出与 JSON 的 `outputs.detail`（本页自己写入自己的体积会变成自指的数字）。
> **一句话**：Godot 版的「**免派定位探针**」——「哪个文件负责什么 / 某个函数在第几行 / 谁依赖谁 / 谁在偷偷反向依赖」，`grep` 这两页或跑 `route_query.mjs` 即可，不必再派探查子代理。
> **口径**：所有数字与行号都由 `godot/tools/build_godot_routemap.mjs` **现扫 `godot/**/*.gd`** 得出，**一个行号都不写死**；本工具**不加载、不执行** Godot，所以全是「**静态扫描识别**」值，不是运行时真值。文件里**故意不写生成时间**（否则 `--check` 永远红）。
> **扫描范围**：`godot/` 下全部 `.gd`（排除 `.godot/` 等点开头目录），按 `core/` `session/` `presentation/` `tests/` 分层；依赖边 = 代码里的 `class_name` 引用（整词精确匹配，注释与字符串先抹掉）+ `preload/load` 的 `res://` 字面量。
> **已知限制**：只到**词法 + 符号表**级别（不建 GDScript AST、不做值流 / 别名 / 反射 / 动态 `load(变量)`）；顶层 `var` / `signal` / `enum` 不进符号表；`presentation → core` 的写接口只认 `类名.函数名(` 直接静态调用（`callv` / `Callable` / 字符串派发认不出）。
> **同步纪律**：`.gd` 一改本文件即过期 —— 交单前跑 `node godot/tools/build_godot_routemap.mjs` 重建，再跑 `--check`（返回码 `0` = 三份生成物逐字节一致）。**别手改**。
> **当前快照（静态扫描识别值）**：`godot/` 下 **205** 个 `.gd` / **71502** 行 / **3572297** 字节 · 估算 **1080394** token（注释 **17.8%**）· `class_name` **112** 个 · 顶层 `const` **638** / `func` **4672** 个（`static func` **2720**、公开 **2266**、内类 **4**）· 依赖边 **1593**（生产层 **922**，其中跨层 **192**）· 解不出的 `res://*.gd` **0** 处 · 非 `.gd` 资源 **58** 处（目录路径 **31** 处不计）· **架构分层违规 0 处**。

---

## §0.5b CR-1 两个示范文件的改前 / 改后对照（索引页 §0.5 省 token 搬过来的）

> **同一套公式、同一套注释口径**（`2cd879e` = CR-1 开工前）：

| 文件 | 改前（commit `2cd879e`） | 改后（当前源码） | 变化 |
|---|---|---|---|
> | `core/battle/calc.gd` | 77877 字节 · 23700 token · 注释 31.0% | 58346 字节 · 17614 token · 注释 14.9% | **−25.1% 字节 / −25.7% token** |
> | `core/battle/celestial_v01.gd` | 148828 字节 · 45602 token · 注释 17.1% | 104010 字节 · 31713 token · 注释 12.1% | **−30.1% 字节 / −30.5% token** |

> 注：改前是本工具**同一口径**下对 `2cd879e` 实测的值；施工单 §2 / §3 里手写的 78,217 / 148,829 字节是 Review 当时的测量点，与本行的差只是测量点 / 行尾口径，**数字以本表为准**。

## §2 四层每个 `.gd` 的职责 / 行数 / `class_name` / 核心函数

> **核心函数** = 该文件**公开**（不以 `_` 开头）函数里，按「**全仓被别的文件直接调用次数**」降序、同分按行号升序取前 **15** 个；`(n)` = 外部调用次数，`(0)` 省略不写。完整函数表（含签名 / 返回类型 / 行号 / 是否 static / 注释）在 `协作/架构/Godot-AST依赖清单.json` 的 `files[].funcs[]`。
> **`(n)` 的口径**：只数 `类名.函数名(` 这种**静态调用**。实例方法（`session.start_new_run(...)` / `view.setup(...)`）**一律记 0** —— 所以会话门面与表现层视图的「核心函数」实际是**按行号顺序**的前 15 个（`GameSession` 的口子请直接看 §2.2 / JSON 的 `files[].funcs[]`，或跑 `node godot/tools/route_query.mjs GameSession`）。
> **`职责`** 一律取该文件**首行 `##` 文档注释**（不是人写的摘要，扫出来的）。

### §2.1 core · 内核（纯逻辑；不许认识 session / presentation） —— 80 个文件 · 29288 行

| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |
|---|---|---|---|---|---|---|---|---|---|---|
| `core/battle/ai.gd` | `Ai` | `RefCounted` | 268 | 12421 | 3644 | 15.4% | 1 | 19 | `isUltimate`(8) · `aiAction`(3) · `enemyAction`(3) · `pickSingleTarget`(2) · `pickAreaTarget`(2) · `局面Of`(1) · `bestWeaponOn`(1) · `chooseHeal`(1) · `grantTargetOf`(1) · `chooseSupport`(1) · `憋住大招吗` · `ultAllowed` · `targetScore` · `betterTarget` · `weaponPool` | 50-AI.js：自动战斗的选武器 / 选目标。 |
| `core/battle/ai_deck.gd` | `AiDeck` | `RefCounted` | 40 | 1700 | 514 | 34.5% | 0 | 2 | `auto_play_unit_main_weapon` · `auto_play_unit_weapon` | DECK-1：确定性 AI 选牌器（结束回合时替「没打过主武器卡」的我方机体补打 1 张）。 |
| `core/battle/atx_chips.gd` | `AtxChips` | `RefCounted` | 568 | 30604 | 9352 | 35.8% | 9 | 42 | `卡`(34) · `赌局触发次数`(12) · `打出筹码牌`(12) · `等级`(11) · `赌局放入次数`(9) · `触发赌局`(9) · `初始筹码牌库`(7) · `卡表`(4) · `是筹码牌`(4) · `初始化`(4) · `筹码牌库张数`(3) · `打出后赌局`(3) · `阶段初`(1) · `闪开后`(1) · `全部卡` | ★ A3b：ATX「筹码牌库」10 张牌 + 【赌局】触发管线 + 「放入 X」。 |
| `core/battle/atx_duo.gd` | `AtxDuo` | `RefCounted` | 652 | 32605 | 9902 | 33.1% | 32 | 49 | `卡表`(11) · `敌方阶段初`(7) · `卡`(6) · `角色牌们`(3) · `主武器卡们`(3) · `大招卡们`(3) · `精神牌们`(3) · `初始化`(2) · `掩护收口`(2) · `大招条件`(2) · `模板`(1) · `不在名册`(1) · `名册新增键们`(1) · `正后方队友`(1) · `行动前`(1) | ★ A6b：塔斯克（A6 · 重装 · 吉甘斯库德）+ 雷欧娜（A7 · 指挥 · 齐格利昂）。 |
| `core/battle/atx_faction.gd` | `AtxFaction` | `RefCounted` | 752 | 32955 | 9944 | 4.6% | 28 | 59 | `记打出大招`(15) · `合体技槽`(8) · `轮盘双响不可打原因`(3) · `诱敌预告`(2) · `攻击后二次下注`(2) · `大招费用预览`(2) · `大招实际费用`(2) · `执行算子`(1) · `可选目标`(1) · `尝试二次下注`(1) · `初始化`(1) · `阶段初`(1) · `轮盘双响可打吗`(1) · `合体技不可打原因`(1) · `各付费用`(1) | ★ A6d：ATX **势力牌 v0.3（9 张）** 的状态与算子 —— 「公有排 / 只有 ATX 成员能打 / … |
| `core/battle/atx_godsbet.gd` | `AtxGodsbet` | `RefCounted` | 359 | 18815 | 5783 | 40.8% | 9 | 31 | `记上一次攻击`(16) · `装填大招槽`(13) · `打出入局`(13) · `上一次攻击`(12) · `上一把输了`(9) · `赌神开启`(9) · `找入局槽`(9) · `赌神本场翻盘段数`(8) · `入局不可打原因`(8) · `翻盘概率`(6) · `入局可用吗`(6) · `阶段初`(6) · `是响介`(2) · `掷翻盘`(2) · `打出算子`(2) | ★ A4（响介 v0.3，作者 2026-10-17 拍板）：「赌神」—— 全局「上一次攻击」账 + 入局 / 翻盘 … |
| `core/battle/atx_luck.gd` | `AtxLuck` | `RefCounted` | 131 | 6947 | 2132 | 53.6% | 1 | 8 | `打出时`(11) · `强运本场正反面次数`(8) · `强运文字`(2) · `概率`(2) · `是强运牌`(1) · `初始化`(1) · `必触发` · `大招打出后` | ★ A4（艾克赛琳 v0.3）：「强运」硬币框架。 |
| `core/battle/atx_rewrite.gd` | `AtxRewrite` | `RefCounted` | 294 | 16260 | 4982 | 41.5% | 15 | 19 | `应用`(22) · `设`(21) · `槽`(12) · `槽文字`(8) · `是弓牌`(6) · `段数Of`(3) · `卡`(3) · `改写本场次数`(2) · `规则表`(1) · `匹配`(1) · `卡表`(1) · `打出时`(1) · `是改写类型` · `清` · `有` | ★ A5b（拉米亚 v0.1 / 响介 v0.1）：武器「**段数改写**」层。 |
| `core/battle/atx_smoke.gd` | `AtxSmoke` | `RefCounted` | 373 | 19516 | 5960 | 40.7% | 2 | 29 | `放烟`(27) · `初始化`(22) · `雾袭本场触发次数`(11) · `命中惩罚`(7) · `打出时`(7) · `烟雾本场放出次数`(3) · `是拉米亚`(2) · `单位在雾里`(2) · `片数`(1) · `有雾吗`(1) · `惩罚来源`(1) · `是烟雾卡` · `是雾袭牌` · `雾袭文字` · `是攻击牌` | ★ A5a（拉米亚 v0.1）：「烟雾」场上状态 + 独有关键词【雾袭】+ 烟雾弹副武器。 |
| `core/battle/atx_three.gd` | `AtxThree` | `RefCounted` | 1581 | 68578 | 20580 | 1.9% | 46 | 130 | `卡`(55) · `有`(10) · `开局牌库`(10) · `打出牌`(8) · `卡表`(6) · `装填单位`(6) · `不可打原因`(6) · `角色牌们加版`(4) · `升版卡表`(3) · `装填大招槽`(3) · `亮起原因`(3) · `大招卡们`(2) · `按角色张数`(2) · `卡表张数`(2) · `阶段初`(2) | ★ A6c：响介（A1）/ 艾克赛琳（A2）/ 拉米亚（A3）三人按 **v0.1 稿**补齐卡表。 |
| `core/battle/battle_log.gd` | `BattleLog` | `RefCounted` | 132 | 4503 | 1351 | 14.6% | 0 | 12 | `pushLog`(1) · `记`(1) · `谁`(1) · `谁目标`(1) · `援护剩余文`(1) · `目标名Of`(1) · `效果摘要文`(1) · `攻击结果摘要`(1) | 职责：战报与描述 —— 记一条事件、单位 / 目标署名、增益与攻击结果摘要文。「一张牌打出了什么」这类文本都从这里出。 |
| `core/battle/boss.gd` | `Boss` | `RefCounted` | 251 | 12712 | 3833 | 13.9% | 0 | 18 | `bossTurn`(14) · `Boss本回合禁用`(7) · `bossAction`(6) · `大技能预告回合`(5) · `取Boss脚本`(3) · `Boss参数`(3) · `撤离检查`(2) · `Boss伤害倍率`(1) · `Boss触发阈值` · `Boss阶段序号` · `Boss本回合放大技能` · `Boss下次技能回合` · `脚本大技能武器们` · `Boss大技能条目` · `单武器动作` | 61-Boss.js：站桩 Boss 脚本（阶段 / 大技能间隔 / 伤害倍率）。 |
| `core/battle/btl.gd` | `Btl` | `RefCounted` | 240 | 14786 | 4417 | 4.5% | 3 | 108 | `pushLog`(208) · `战意`(143) · `谁`(138) · `换同源增益`(92) · `打出精神或公有牌`(88) · `找单位`(86) · `加战意`(61) · `克隆战术牌`(51) · `刷新敌方意图`(42) · `战意费用`(35) · `打出武器栏卡`(31) · `打出主武器卡`(29) · `谁目标`(27) · `效果摘要文`(26) · `开始我方阶段`(25) | 职责：Battle 内核的对外门面 —— 每个函数都在这里留一行同名转发（实现在 core/battle 下的八个子模… |
| `core/battle/calc.gd` | `Calc` | `RefCounted` | 1200 | 58346 | 17614 | 14.9% | 2 | 72 | `resolveAttack`(80) · `hitRate`(49) · `buffSum`(34) · `九死一生_闪`(11) · `九死一生_本阶段轮转`(9) · `dmgCore`(8) · `usableWeapons`(8) · `wv`(6) · `spendWeapon`(6) · `λ次数上限`(5) · `weaponPlayable`(5) · `critMul`(4) · `λ减免量`(4) · `critRate`(4) · `effArmor`(3) | 20-战斗计算.js：命中 / 暴击 / 伤害管线（弱点 → 装甲 → 防御 → 公式 → 屏障 → λ力场 → 护盾… |
| `core/battle/card_effects.gd` | `CardEffects` | `RefCounted` | 591 | 25476 | 7767 | 28.6% | 5 | 26 | `execute`(19) · `execute_ops`(3) · `grant_derived_card`(3) · `组表` · `衍生牌定义` · `选单位` · `执行算子` | 战术卡牌效果的声明式执行器。 |
| `core/battle/card_exec.gd` | `BattleCardExec` | `RefCounted` | 398 | 21588 | 6544 | 12.7% | 0 | 16 | `打出精神或公有牌`(35) · `是合体技牌`(1) · `合体技参与者`(1) · `打出衍生攻击卡`(1) · `play_derived_card`(1) · `play_spirit_or_public_card`(1) · `牌的势力归属`(1) | 职责：出牌执行 —— 精神牌 / 公有牌、衍生攻击卡、合体技的效果执行与回收。门槛在 `CardPlay`。 |
| `core/battle/card_play.gd` | `CardPlay` | `RefCounted` | 298 | 12173 | 3694 | 11.6% | 13 | 20 | `不可打原因`(26) · `目标方`(17) · `主武器门槛`(4) · `找执行机体`(2) · `是要指定友军` · `要指定友军` · `副武器门槛` · `大招门槛` · `衍生门槛` | 职责：出牌判定（唯一真源）—— 能不能打 / 打谁 / 由谁打。**纯读**。 |
| `core/battle/card_pool.gd` | `BattleCardPool` | `RefCounted` | 394 | 14384 | 4312 | 12.0% | 0 | 31 | `是秘银计入牌`(1) · `卡可打吗`(1) · `提取单位三层信息`(1) · `牌来源机体`(1) · `克隆战术牌`(1) · `加卡牌护盾`(1) · `减单位大招冷却`(1) · `减秘银牌冷却`(1) · `卡牌加标定`(1) · `找单位`(1) · `身份对口`(1) · `是衍生攻击卡`(1) | 职责：卡牌可用性判定 / 声明式触发条件求值 / 卡牌与单位的查找 / 护盾与标定层数。 |
| `core/battle/celestial_v01.gd` | `CelestialV01` | `RefCounted` | 2180 | 104010 | 31713 | 12.1% | 14 | 141 | `武器打出前`(15) · `装填大招槽`(12) · `势力牌们`(9) · `伤害倍率`(8) · `出鞘剑数`(8) · `开`(7) · `武力介入满足吗`(7) · `太阳炉卡表`(7) · `放入太阳炉`(7) · `打出太阳炉牌`(7) · `拉塞卡表`(7) · `装填单位`(7) · `狙溢暴击`(7) · `我方阶段末`(6) · `太阳炉卡`(6) | 天人 v0.1：TRANS-AM / 太阳炉牌库 / 9 张势力牌 / 拉塞 CB5 / 四名驾驶员的完整卡池与独有机… |
| `core/battle/class_cards.gd` | `ClassCards` | `RefCounted` | 605 | 31175 | 9485 | 28.2% | 6 | 36 | `按名`(14) · `职业牌们`(4) · `卡表`(3) · `卡`(3) · `是分类牌`(1) · `执行算子`(1) · `改写武器`(1) · `绕后奇袭`(1) · `攻击后`(1) · `可选目标`(1) · `横向掩护接管`(1) · `顺劈副目标们`(1) · `是顺劈武器`(1) · `不可打原因` · `卡不可打原因` | ★ A6a：三套**职业分类牌** 18 张（近卫 6 / 尖兵 6 / 重装 6）。 |
| `core/battle/colonial_awaken.gd` | `ColonialAwaken` | `RefCounted` | 399 | 17816 | 5401 | 19.9% | 11 | 40 | `觉醒中`(11) · `是殖民卫星军`(9) · `入场槽`(9) · `取QTE结果`(9) · `是ZERO中`(6) · `开QTE`(6) · `清QTE`(6) · `是隐身中`(5) · `键`(3) · `结束`(3) · `检查系统拒绝`(3) · `入场门原因`(3) · `类型Of`(2) · `挂ZERO暴伤`(2) · `实际费用`(2) | 职责：殖民卫星军的觉醒状态机（SEED / ZERO / 隐身）与 QTE 接口 —— 只读写单位字典上的状态，不认任… |
| `core/battle/colonial_deck.gd` | `ColonialDeck` | `RefCounted` | 495 | 23045 | 7015 | 9.6% | 3 | 37 | `初始化`(9) · `势力牌们`(4) · `卡包`(3) · `感应牌们`(3) · `感应牌`(3) · `放入感应牌`(3) · `触发觉醒感应`(3) · `是殖民卫星军牌`(2) · `感应牌库左栏文`(2) · `是感应牌`(1) · `公有扩展牌`(1) · `初始牌库`(1) · `库`(1) · `抽感应牌`(1) · `各级张数`(1) | 职责：殖民卫星军的感应牌库（11 张，`SubDeck` 结构化库）+ 9 张势力牌 + 【觉醒感应】的抽牌 / 放入。 |
| `core/battle/colonial_units.gd` | `ColonialUnits` | `RefCounted` | 696 | 34089 | 10273 | 10.6% | 7 | 39 | `角色牌们`(5) · `装填单位`(5) · `卡表`(2) · `武器门槛`(2) · `命中修正`(1) · `闪避加成`(1) · `攻方伤害倍率`(1) · `受方伤害倍率`(1) · `受击后`(1) · `暴击修正`(1) · `武器攻击后`(1) · `致命保留_后`(1) · `牌打出后`(1) · `阶段初`(1) · `执行算子`(1) | 职责：殖民卫星军七名成员的卡池（`data/cards/殖民卫星军.json` 的「驾驶员」）与独有机制（METEOR… |
| `core/battle/colonial_v01.gd` | `ColonialV01` | `RefCounted` | 456 | 22396 | 6793 | 15.8% | 4 | 47 | `命中修正`(6) · `入场牌`(4) · `是殖民卫星军`(4) · `装填大招槽`(3) · `闪避加成`(3) · `攻方伤害倍率`(3) · `受击后`(3) · `武器攻击后`(3) · `可选目标`(3) · `致命保留_后`(3) · `该亮金边`(3) · `入场牌们`(2) · `有成员`(2) · `受方伤害倍率`(2) · `我方阶段初_后`(2) | 职责：殖民卫星军的**唯一注册点** —— 成员识别、入口（装填 / 公有牌）与全部规则钩子的转发（觉醒在 `Colo… |
| `core/battle/data_fn.gd` | `DataFn` | `RefCounted` | 31 | 1368 | 410 | 43.5% | 0 | 3 | `tierOfEnemy`(15) · `tplOf`(7) · `wp`(3) | 10-数据 / 11-敌方梯队 / 12-档位职业 里战斗运行期要用的三个小函数（其余是启动期就算好的数据，见 dat… |
| `core/battle/deck_flow.gd` | `DeckFlow` | `RefCounted` | 997 | 44338 | 13416 | 5.4% | 4 | 57 | `打出大招`(58) · `大招不可打原因`(40) · `找大招槽`(30) · `阶段初_检查`(29) · `条件满足`(26) · `打出副武器`(24) · `当前换装来源`(21) · `记上张打出牌`(16) · `再动`(13) · `拆分单位牌`(12) · `λ开启`(12) · `阶段初_冷却与维持`(11) · `副武器不可打原因`(8) · `λ文案`(8) · `刷新实时门槛`(7) | ★ MITH3-2 / MITH3-3：卡牌流转规则 v0.1 的**唯一状态机** + 秘银 v0.3 的连携牌库与… |
| `core/battle/diff.gd` | `Diff` | `RefCounted` | 78 | 3720 | 1107 | 2.7% | 0 | 4 | `敌方强度倍率`(3) · `回合上限`(1) · `站位权重`(1) · `应用敌方强化`(1) | 71-改动-3-难度调整.js 的运行期函数：回合上限、AI 站位权重、敌方强度。 |
| `core/battle/enemy_mech.gd` | `EnemyMech` | `RefCounted` | 121 | 6537 | 1984 | 18.7% | 0 | 8 | `武器攻击后`(5) · `敌方阶段初`(3) · `可选目标`(3) · `攻方伤害倍率`(3) · `机制提示`(1) · `牌打出后` · `悬赏开` · `悬赏目标` | 职责：敌方阵营机制里要挂规则钩子的部分（N4 粒子抑制场的精神牌加费、N2 悬赏令、N5 影锁拽位）。只认单位数据字段… |
| `core/battle/fac.gd` | `Fac` | `RefCounted` | 173 | 6799 | 2079 | 14.9% | 1 | 27 | `势力状态`(14) · `势力记录`(9) · `势力名`(8) · `势力在场`(6) · `势力击破`(6) · `是我方势力`(5) · `势力参数`(4) · `势力逐段未命中`(3) · `势力防御`(2) · `势力开局`(1) · `势力回合结束`(1) · `势力友军攻击后`(1) · `势力武器用后`(1) · `势力攻击前`(1) · `势力修理`(1) | 72-势力-1-框架与钩子.js：势力特色的框架与引擎钩子。 |
| `core/battle/fac_atx.gd` | `FacAtx` | `RefCounted` | 606 | 24503 | 7355 | 2.7% | 8 | 56 | `卡`(35) · `合体技卡`(12) · `卡表`(6) · `势力牌们`(6) · `有`(5) · `角色专属牌们`(4) · `角色牌们`(3) · `按名取`(2) · `按id取`(2) · `是主武器卡`(2) · `是公有牌`(2) · `公有牌们`(2) · `是专属精神牌`(1) · `涉及角色键`(1) · `执行算子`(1) | DECK-4：ATX 势力卡牌设计 v0.2 的卡表（25 张）+ 装填 + 专属效果执行器。 |
| `core/battle/fac_cb.gd` | `FacCb` | `RefCounted` | 105 | 4614 | 1384 | 9.8% | 0 | 11 | `ATX打空`(2) · `ATX逐段未命中`(1) · `ATX武器用后`(1) · `ATX开局`(1) · `ATX参数` · `有赌徒直觉` · `是减冷却武器` · `ATX余量` · `ATX武器们` · `ATX减冷却` | 72-势力-4：ATX（赌徒的直觉）。 |
| `core/battle/fac_mith.gd` | `FacMith` | `RefCounted` | 248 | 12503 | 3814 | 1.6% | 1 | 20 | `是秘银`(13) · `秘银取消被挡`(2) · `秘银兑现`(1) · `倒下接力`(1) · `刷新秘银缓存`(1) · `秘银开局`(1) · `秘银回合结束`(1) · `秘银友军攻击后`(1) · `秘银参数` · `卡类` · `是专属牌` · `是秘银情报岗` · `是秘银作战岗` · `秘银岗位` · `键名` | 72-势力-5：秘银（SRT 交叉训练：情报岗挂标定 → 作战岗兑现破防；倒下接力）。 |
| `core/battle/fac_moon.gd` | `FacMoon` | `RefCounted` | 246 | 11939 | 3619 | 6.4% | 2 | 22 | `判定月球王国光环`(3) · `残月追加攻击`(2) · `连射残心`(2) · `v02让位`(1) · `月光祝福数值`(1) · `月球光环受益`(1) · `不动装甲`(1) · `判定月球不动`(1) · `战地急救`(1) · `月球参数` · `有月光共鸣` · `是残月武器` · `光环文字` · `残月可追加` · `残月武器` | 72-势力-3：月球王国（月光环绕 / 残月的余响 / 不动如山 / 战地急救 / 连射残心）。 |
| `core/battle/faction_identity.gd` | `FactionIdentity` | `RefCounted` | 112 | 4858 | 1468 | 22.2% | 11 | 12 | `押注层数`(4) · `攻方伤害倍率`(3) · `武器攻击后`(2) · `连携触发后`(2) · `开` · `是响介` · `是宗介` · `开局初始化` | 职责：IT-4「势力手感 v0.1」的**唯一注册点**（作者 10-21 试玩方向）—— |
| `core/battle/flow.gd` | `Flow` | `RefCounted` | 424 | 24609 | 7529 | 32.7% | 0 | 13 | `结算一个目标`(11) · `resolveAction`(8) · `actOnce`(5) · `空位`(2) · `增援一波`(1) · `我方阶段初_增援` · `增援` · `指挥被动` · `我方阶段初_指挥` · `单位动作` · `runAutoCast` | 60-战斗-2-回合流程.js：单位行动、动作结算。 |
| `core/battle/fm.gd` | `Fm` | `RefCounted` | 222 | 8749 | 2635 | 32.4% | 2 | 30 | `rowOfSlot`(70) · `位名`(48) · `colOfSlot`(41) · `SLOTS`(30) · `slotOf`(19) · `另一排同位`(17) · `真实距离`(12) · `行列数`(11) · `是前排有效`(10) · `是否顶位`(9) · `十字相邻位`(7) · `ROWS`(5) · `格被占`(5) · `被挡吗`(4) · `相邻位`(3) | 05-阵型.js：正交双排 4×2 共 8 格的几何（前排 0..3、后排 4..7）。 |
| `core/battle/focus_fire.gd` | `FocusFire` | `RefCounted` | 57 | 2506 | 750 | 19.0% | 2 | 7 | `攻方伤害倍率`(5) · `武器攻击后`(2) · `开` · `打中过的` · `有破绽` | 职责：IT-5 ②【破绽】（作者 10-21 拍板）—— 同一回合内，敌机被我方一台机体打中后露出破绽： |
| `core/battle/guard.gd` | `BattleGuard` | `RefCounted` | 377 | 17528 | 5289 | 15.0% | 0 | 20 | `掩护额度`(8) · `嘲讽`(1) · `是掩护者`(1) · `重置靶机援护`(1) · `当前援护连线们`(1) · `镜甲反弹`(1) · `主武器威力`(1) · `自爆`(1) · `词条到点自爆`(1) · `词条冷却延长`(1) · `词条隐身刷新`(1) · `应用全场词条`(1) · `换同源增益`(1) · `我方阶段初_自爆` · `我方阶段初_词条` | 职责：护卫与敌方词条的回合效果 —— 嘲讽 / 靶机援护 / 援护连线 / 镜甲反弹 / 自爆 / 冷却延长 / 隐身… |
| `core/battle/intent.gd` | `BattleIntent` | `RefCounted` | 131 | 5790 | 1753 | 13.0% | 0 | 4 | `算意图`(3) · `算意图表`(1) · `刷新敌方意图`(1) | 职责：敌方意图预告（DECK-2）—— 算意图 / 算意图表 / 刷新敌方意图。预览与实际同源，只读、不掷随机数。 |
| `core/battle/mithril_v03_cards.gd` | `MithrilV03Cards` | `RefCounted` | 1069 | 51022 | 15481 | 12.4% | 13 | 62 | `卡`(21) · `执行算子`(9) · `职业牌们`(6) · `角色专属牌们按等级`(4) · `势力牌们`(3) · `连携牌们`(3) · `合体技卡`(3) · `卡表`(2) · `角色专属牌们`(2) · `初始连携牌库`(2) · `角色牌们`(1) · `公有牌们`(1) · `λ武器表`(1) · `挂被动`(1) · `卡包` | ★ MITH3-3：秘银小队 v0.3 权威卡表（5 名成员全卡池 + 连携牌库 9 张 + 势力牌 9 张 + 18… |
| `core/battle/moon_deck.gd` | `MoonDeck` | `RefCounted` | 285 | 13399 | 4085 | 10.2% | 3 | 24 | `随侍结算`(14) · `各级张数`(10) · `势力牌们`(8) · `库`(5) · `放入`(4) · `月光牌们`(3) · `月光牌`(3) · `是月球牌`(2) · `卡包`(1) · `效果组`(1) · `初始牌库`(1) · `初始化`(1) · `打出`(1) · `卡不可打原因`(1) · `执行算子`(1) | 职责：月球王国的【月光牌库】（三层 `SubDeck`）+ 7 张势力牌 + ★【随侍】的抽牌 / 放入。 |
| `core/battle/moon_faction.gd` | `MoonFaction` | `RefCounted` | 94 | 4689 | 1413 | 6.2% | 0 | 3 | `执行算子`(1) | 职责：月球王国势力牌的算子（号令 / 阵形变换 / 战线轮换 / 月相仪典 / 王国之盾 / 公主挺身）。 |
| `core/battle/moon_phase.gd` | `MoonPhase` | `RefCounted` | 251 | 10545 | 3199 | 14.4% | 9 | 27 | `活着`(19) · `王女`(18) · `是月球王国`(15) · `月相`(14) · `状态`(13) · `治疗`(8) · `随侍数`(6) · `到过`(5) · `切换月相`(5) · `有拘束`(5) · `键`(4) · `是随侍`(3) · `随侍达成`(3) · `释放月相`(3) · `余响`(2) | 职责：月球王国的【月相】状态机、【随侍】判定与回合级状态（月面偏导 / 拘束 / 月球护盾 / 月华溢流 / 不动如山… |
| `core/battle/moon_units.gd` | `MoonUnits` | `RefCounted` | 350 | 17738 | 5351 | 6.7% | 6 | 23 | `角色牌们`(7) · `装填单位`(1) · `刷新站位武器栏`(1) · `阶段初`(1) · `装填后`(1) · `副武器门槛`(1) · `副武器特殊打出`(1) · `条件值`(1) · `执行算子`(1) · `命中修正`(1) · `攻方伤害倍率`(1) · `受击后`(1) · `武器攻击后`(1) · `牌打出后`(1) · `AI补打`(1) | 职责：月球王国五名成员的卡池（`data/cards/月球王国.json` 的「驾驶员」）、精神牌 / 大招 / 副武… |
| `core/battle/moon_v02.gd` | `MoonV02` | `RefCounted` | 156 | 6019 | 1811 | 16.6% | 1 | 26 | `受方伤害倍率`(7) · `开`(5) · `武器攻击后`(5) · `我方阶段初_后`(4) · `命中修正`(3) · `公有扩展牌`(2) · `受击前`(2) · `牌打出后`(1) · `选项开` · `开局初始化` · `装填单位` · `装填大招槽` · `公有牌打出` · `执行算子` · `攻方伤害倍率` | 职责：月球王国 v0.2.1 的**唯一注册点** —— 开关与成员识别、装填入口与全部规则钩子的转发。 |
| `core/battle/morale.gd` | `BattleMorale` | `RefCounted` | 67 | 2329 | 698 | 13.4% | 0 | 10 | `抑制层数`(6) · `加战意`(5) · `战意`(2) · `设战意`(2) · `是单机牌组单位`(1) · `战意Of`(1) · `连续攻击可用`(1) · `连续攻击记`(1) · `战意费用`(1) | 职责：士气 —— 气势总攻槽、单机战意与战意费用、连续攻击计次。 |
| `core/battle/params.gd` | `Params` | `RefCounted` | 508 | 23259 | 7044 | 8.0% | 0 | 107 | `指挥公有减费`(9) · `战意上限`(8) · `残月武器运行期解锁`(7) · `词条开`(6) · `回合初战意`(6) · `命中战意`(6) · `击破战意`(6) · `专属手牌上限`(6) · `公有手牌自然上限`(5) · `气势总攻参数`(4) · `气势总攻开`(4) · `职业排位开`(4) · `单机牌组_维修职业`(4) · `职业排位数`(3) · `专属起手`(3) | 71-改动-5-参数入口.js：所有「读战斗结构参数」的函数与兰斯战线 / 职业排位 / 卡牌伤害等纯计算。 |
| `core/battle/phase_flow.gd` | `BattlePhaseFlow` | `RefCounted` | 152 | 6221 | 1882 | 14.7% | 0 | 9 | `开始我方阶段`(8) · `默认方针`(1) · `设单位开关`(1) · `禁止攻击`(1) · `按防御结算`(1) · `actionOrder`(1) · `记击破`(1) · `结束我方回合`(1) | 职责：阶段流转 —— 开始我方阶段 / 结束我方回合、出手顺序、单位人工开关、击破记账、AI 选牌器取用。 |
| `core/battle/public_cooldown.gd` | `PublicCooldown` | `RefCounted` | 62 | 2985 | 904 | 26.3% | 0 | 5 | `阶段初`(2) · `初始化`(1) · `去处`(1) · `放入`(1) · `状态` | 职责：公有牌的**冷却区** —— 带 `进冷却区` 的公有牌打出后按卡上的 `冷却` 倒计时，归 0 洗回公有牌库。 |
| `core/battle/reach.gd` | `Reach` | `RefCounted` | 316 | 13414 | 4011 | 25.0% | 5 | 32 | `rangeKindOf`(53) · `职业是`(41) · `武器可达吗`(28) · `isAreaKind`(15) · `KIND_MELEE`(13) · `isHealKind`(11) · `武器距离`(10) · `KIND_DIRECT`(9) · `遮挡命中惩罚`(9) · `是范围武器`(8) · `isSupportKind`(7) · `无视遮挡`(7) · `近战可达`(6) · `范围落点`(6) · `areaSlots`(5) | 30-射程.js：5 类射程、能不能打到、被挡惩罚、职业判定、范围落点。 |
| `core/battle/relic_battle.gd` | `RelicBattle` | `RefCounted` | 183 | 8614 | 2614 | 35.1% | 0 | 10 | `apply_on_battle_start`(1) · `战斗分类` · `取件们` · `藏品层数` · `藏品单体效果` · `藏品合计封顶` · `应用藏品我方` · `应用藏品敌方` | 93-藏品.js 的「开战应用」段（`藏品开战` / `应用藏品我方` / `应用藏品敌方` / `藏品单体效果` /… |
| `core/battle/repair_cards.gd` | `RepairCards` | `RefCounted` | 418 | 19776 | 6000 | 24.2% | 4 | 33 | `按名`(12) · `卡表`(2) · `职业牌们`(2) · `卡不可打原因`(2) · `统计`(2) · `命中修正`(2) · `致命保留_后`(2) · `我方阶段初_后`(2) · `是维修牌`(1) · `执行算子`(1) · `武器攻击后`(1) · `卡` · `血比` · `触发过量整备` · `状态行` | 职责：第 7 职业【维修】的 6 张分类牌 + 职业专属机制【过量整备】。 |
| `core/battle/rival.gd` | `Rival` | `RefCounted` | 107 | 4859 | 1469 | 16.9% | 0 | 8 | `开局初始化`(5) · `攻方伤害倍率`(4) · `键Of`(3) · `可选目标`(3) · `条件成立`(2) | 职责：Boss「宿敌」彩蛋骨架（B 稿 N1 宿敌在场 / N2 指定角色修正 / N3 猎杀名单）。只读敌机模板的 … |
| `core/battle/rule_hooks.gd` | `RuleHooks` | `RefCounted` | 162 | 6564 | 1984 | 11.9% | 0 | 10 | `广播`(34) · `首个结论`(12) · `汇总`(5) · `识别大招处理者`(3) · `按处理者`(3) · `依次乘`(2) · `收集`(2) · `执行算子`(1) · `实现了吗` | 职责：规则钩子注册表 —— 势力 / 职业模块只在 `顺序` 表里点名。 |
| `core/battle/setup.gd` | `Setup` | `RefCounted` | 541 | 27264 | 8363 | 35.9% | 1 | 26 | `开局`(60) · `抽专属牌`(22) · `抽公有牌`(14) · `checkResult`(12) · `打一回合`(12) · `跑完`(6) · `endTurn`(4) · `派发衍生卡`(2) · `drainAgain`(1) · `初始化单机牌组单位`(1) · `是秘银公有牌`(1) · `紧急修理武器` · `铁壁护卫武器` · `衍生卡模板` · `初始化单机牌组` | 60-战斗-3-开局与simulate.js：开局、一回合的行动顺序、胜负判定、回合结束。 |
| `core/battle/shadow_deck.gd` | `ShadowDeck` | `RefCounted` | 398 | 19568 | 5950 | 9.0% | 3 | 29 | `错位触发`(7) · `势力牌们`(4) · `错位敌们`(4) · `影门牌`(3) · `放入影门牌`(3) · `影门牌们`(2) · `是势力牌`(2) · `是影世界公有牌`(2) · `不可打原因`(2) · `卡包`(1) · `效果组`(1) · `是影门牌`(1) · `初始牌库`(1) · `初始化`(1) · `打出`(1) | 职责：影世界的【影门牌库】（`SubDeck` 结构化库）+ 8 张势力牌 + ★【错位】的抽牌 / 放入 + 这两类… |
| `core/battle/shadow_ults.gd` | `ShadowUlts` | `RefCounted` | 138 | 6790 | 2050 | 12.9% | 0 | 8 | `执行算子`(1) | 职责：影世界五张大招的效果本体（传送斩 / ★影界·万刃归一 / ★影凤凰 / ★影之森 / ★连锁投掷）。 |
| `core/battle/shadow_units.gd` | `ShadowUnits` | `RefCounted` | 314 | 16155 | 4897 | 11.4% | 5 | 23 | `武器攻击后`(6) · `暴击修正`(4) · `闪避加成`(3) · `攻方伤害倍率`(3) · `牌打出后`(3) · `是影世界动作牌`(2) · `命中修正`(2) · `武器`(1) · `角色牌们`(1) · `装填单位`(1) · `刷新本人门槛`(1) · `副武器门槛`(1) · `打出副武器`(1) · `执行算子`(1) · `换位后`(1) | 职责：影世界四人（雷萨 / 蕾卡 / 维诺 / 比格特拉克）的卡池（`data/cards/影世界.json` 的「驾… |
| `core/battle/shadow_v02.gd` | `ShadowV02` | `RefCounted` | 233 | 9635 | 2899 | 13.7% | 4 | 35 | `记`(24) · `名`(19) · `换位`(17) · `活`(9) · `对位格`(8) · `按血挑`(8) · `开`(6) · `友目标`(5) · `敌目标`(5) · `真伤`(4) · `施放者`(3) · `是影世界成员`(2) · `键`(2) · `是主成员`(1) · `暴击修正`(1) | 职责：影世界 v0.2.1 的唯一注册点 —— 开关、成员识别、共用小工具与规则钩子转发（牌库 `ShadowDeck… |
| `core/battle/sub_deck.gd` | `SubDeck` | `RefCounted` | 174 | 9885 | 3057 | 65.8% | 6 | 10 | `牌们`(45) · `放入`(22) · `抽一张`(12) · `回库或移出`(9) · `各级张数`(7) · `新建`(6) · `等级`(5) · `随机下标`(2) · `是结构化库` · `已放入三级` | ★ A3a：通用「副牌库（SubDeck）」层 —— 从既有那一套里抽出来的**纯存取实现**。 |
| `core/battle/swap.gd` | `BattleSwap` | `RefCounted` | 309 | 15382 | 4676 | 26.2% | 7 | 23 | `换位`(37) · `已错位`(23) · `格上单位`(13) · `合法吗`(5) · `锁定动作`(5) · `顶位`(3) · `是互换吗`(2) · `清回合状态`(2) · `意图快照` | 职责：共用换位底座 —— `swapPos` 原语 + 换位后的 6 项刷新链（月球王国 / 影世界共用同一份）。 |
| `core/battle/traits.gd` | `Traits` | `RefCounted` | 179 | 6893 | 2062 | 2.4% | 0 | 10 | `词条到单位`(4) · `应用词条到单位`(2) · `编成词条` · `词条作用在` · `词条汇总` · `词条夹` · `词条增益` · `词条加能力` · `词条加武器` · `词条威力系数` | 70-编成.js 的词条层（运行期）：把编成上的词条落到单位上。 |
| `core/battle/units.gd` | `Units` | `RefCounted` | 269 | 11211 | 3335 | 16.8% | 0 | 23 | `livingOf`(163) · `makeUnit`(38) · `unit_class`(38) · `势力们`(15) · `unitRow`(14) · `otherSide`(12) · `sideUnits`(5) · `livingUnits`(5) · `speedOf`(4) · `已用键表`(2) · `makeUnits`(2) · `frontAlive`(1) · `下一个键`(1) · `runEnemyLv`(1) · `默认等级`(1) | 40-单位.js：造单位（模板 → 运行期单位）、升级、按方取单位。单位就是 Dictionary（与 JS 对象一一… |
| `core/battle/weapon_exec.gd` | `BattleWeaponExec` | `RefCounted` | 383 | 21019 | 6373 | 14.9% | 0 | 12 | `打出主武器卡`(1) · `play_unit_weapon_card`(1) · `武器栏不可打原因`(1) · `打出武器栏卡`(1) | 职责：武器卡执行 —— 主武器卡与武器栏卡的打出，武器攻击 / 修理 / 支援 / 铁壁护卫的结算入口。 |
| `core/data/db.gd` | `Db` | `RefCounted` | 18 | 834 | 252 | 63.8% | 0 | 1 | `install`(1) | 战斗内核读数据的入口。 |
| `core/data/display_names.gd` | `DisplayNames` | `RefCounted` | 22 | 1028 | 314 | 34.3% | 0 | 2 | `名`(4) · `卡名`(2) | 显示名取名入口：玩家看得到的名字一律从这里取（去版权化-A），键是内部 id。 |
| `core/data/game_catalog.gd` | `GameCatalog` | `RefCounted` | 153 | 5201 | 1584 | 39.7% | 16 | 28 | `has` · `raw` · `characters` · `character` · `enemies` · `enemy` · `enemy_tiers` · `stages` · `stage` · `trait_groups` · `trait_group` · `cards` · `card` · `relics` · `relic` | 领域数据目录：把「常量名 → 值」的扁平常量表包装成按领域分类的强语义只读查询 API。 |
| `core/data/game_data.gd` | `GameData` | `RefCounted` | 39 | 1409 | 426 | 44.3% | 0 | 7 | `has` · `get_const` · `origin_of` · `names` · `consts` · `tables` | 全部内容数据与规则参数的只读容器（纯逻辑，不做任何 IO）。 |
| `core/run/deck_builder.gd` | `DeckBuilder` | `RefCounted` | 369 | 17572 | 5370 | 42.9% | 3 | 26 | `offer_cards`(13) · `找到`(10) · `unit_exclusive_cards`(8) · `新解锁专属牌`(4) · `select_card`(4) · `等级倍率`(3) · `是公有牌`(3) · `公有扩展牌们`(3) · `offer_public_cards`(3) · `应用等级倍率`(2) · `候选战术牌们`(1) · `全表` · `键们` · `缩放威力` · `单机牌组模式` | 战术牌构筑（3 选 1）——原生 Godot，**零 `J.*`**。 |
| `core/run/map_generator.gd` | `MapGenerator` | `RefCounted` | 679 | 28073 | 8295 | 25.2% | 8 | 37 | `propellant_max`(10) · `propellant_remainder`(8) · `propellant_detail`(8) · `exit_kinds`(7) · `neighbors_of`(6) · `shape`(5) · `map_seed`(5) · `int_key_set`(5) · `bfs_distances`(4) · `remainder_is_even`(2) · `remainder_detail`(2) · `cell_col`(2) · `cell_row`(2) · `articulation_points`(2) · `generate_floor`(2) | 大地图生成（MapGenerator）—— 100% 复现封存 JS 参考版 `src/js/91-地图.js` 的 |
| `core/run/map_navigator.gd` | `MapNavigator` | `RefCounted` | 439 | 21023 | 6297 | 32.7% | 2 | 31 | `reachable_cells`(23) · `can_move_to`(15) · `cell_ids`(14) · `exit_chase_pending`(12) · `enter_floor`(9) · `move_to`(7) · `is_known`(7) · `retreat_cost_preview`(6) · `choose_exit`(6) · `advance_floor`(6) · `current_exit_kind`(5) · `is_guard_cleared`(4) · `columns`(3) · `walkable`(3) · `exit_requires_guard`(3) | 大地图移动 / 层流转（MapNavigator）—— 对齐封存 JS 参考版的 |
| `core/run/node_resolver.gd` | `NodeResolver` | `RefCounted` | 964 | 46965 | 14247 | 17.7% | 3 | 72 | `解析槽位`(13) · `开战`(9) · `resolve_battle`(7) · `我方编成`(6) · `黑市货`(6) · `选编成`(4) · `抽编成兜底`(4) · `清空格`(4) · `战斗类型Of`(3) · `编成种子`(3) · `编成到规格`(3) · `第一层减负`(3) · `黑市买牌`(3) · `结算奇遇`(3) · `当前事件`(3) | 7 类节点结算 ——原生 Godot，**零 `J.*`**。 |
| `core/run/part_system.gd` | `PartSystem` | `RefCounted` | 663 | 29633 | 8932 | 37.3% | 7 | 54 | `new_part`(31) · `part_targets`(27) · `part_info`(16) · `use_part`(13) · `part_key`(9) · `part_is_free`(8) · `grant_part`(7) · `sell_price`(7) · `part_breaks_on_next_floor`(6) · `current_value`(6) · `wave_fluctuate`(6) · `sell_part`(6) · `part_rarity`(5) · `draw_part`(5) · `buy_price`(5) | 零件系统（PartSystem）—— ★ 2026-10-17 按《黑流树海》原版规格全面重写（任务单 PART-1）。 |
| `core/run/relic_system.gd` | `RelicSystem` | `RefCounted` | 156 | 6664 | 2019 | 26.4% | 3 | 15 | `名`(6) · `拿藏品`(5) · `件`(4) · `战斗胜利发藏品`(4) · `build_battle_options`(3) · `说明`(2) · `藏品每层希望`(2) · `表`(1) · `数值`(1) · `可抽池`(1) · `候选`(1) · `抽藏品`(1) · `编制类额外掉落`(1) · `是编制类` · `编制件数` | 58 藏品系统（局外逻辑）——原生 Godot，**零 `J.*`**。 |
| `core/run/roster_manager.gd` | `RosterManager` | `RefCounted` | 683 | 31791 | 9622 | 20.9% | 5 | 56 | `new_run`(36) · `deploy_limit`(32) · `模板`(17) · `数`(13) · `标签`(13) · `券名`(11) · `券合`(11) · `整数`(9) · `recruit`(8) · `券留存上限`(8) · `名册键们`(6) · `加经验`(6) · `记希望来源`(5) · `券类`(5) · `券合机师们`(5) | 名册 / 招募券 / 晋升（原生 Godot，**零 `J.*`**）。 |
| `core/run/run_state.gd` | `RunState` | `RefCounted` | 293 | 12350 | 3673 | 22.0% | 3 | 20 | `from_dict`(2) · `add_log` · `grid` · `cell_at` · `has_cell` · `current_cell` · `current_type` · `mark_visited` · `is_visited` · `mark_revealed` · `is_revealed` · `gain_exp` · `has_relic` · `roster_keys` · `is_in_roster` | 肉鸽单局状态领域模型（RunState） |
| `core/util/js.gd` | `J` | `RefCounted` | 303 | 8746 | 2564 | 27.8% | 0 | 38 | `truthy`(1023) · `num0`(816) · `or_`(792) · `s`(586) · `merged`(199) · `round`(198) · `g`(160) · `inc`(109) · `num`(91) · `same`(71) · `some`(49) · `sort`(37) · `every`(24) · `at`(20) · `concat`(20) | JS 语义帮手：移植 JS 战斗内核时，凡是 GDScript 与 JS 行为不同的地方一律走这里。 |
| `core/util/js_compat.gd` | `JsCompat` | `RefCounted` | 52 | 1482 | 443 | 42.4% | 0 | 2 | `js_round`(56) · `stable_sort`(15) | 与 JS 结算语义对齐的小工具。战斗规则里一律用这里的函数，不直接用 Godot 内置的同名函数。 |
| `core/util/rng.gd` | `Mulberry32` | `RefCounted` | 33 | 1102 | 327 | 38.8% | 1 | 3 | `imul` · `next_float` | Mulberry32 —— 与 JS 版 `00-head.js` 的 `mulberry32()` 逐位一致。 |
| `core/version.gd` | `GameVersion` | `RefCounted` | 23 | 986 | 301 | 52.3% | 2 | 1 | `构建串`(5) | 版本信息。显示在界面、写进存档与录像。 |

### §2.2 session · 会话门面（界面唯一入口） —— 12 个文件 · 5018 行

| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |
|---|---|---|---|---|---|---|---|---|---|---|
| `session/battle_deck_view.gd` | `SessionBattleDeckView` | `RefCounted` | 548 | 29336 | 8749 | 9.2% | 0 | 48 | `v03_active`(1) · `卡牌流转开`(1) · `weapon_bar_cards`(1) · `sub_weapon_cards`(1) · `ultimate_slots`(1) · `spirit_hand_cards`(1) · `精神手牌`(1) · `deck_counts`(1) · `link_library_state`(1) · `chip_library_state`(1) · `last_card_state`(1) · `lambda_state_of`(1) · `weapon_range_check`(1) · `play_unit_ultimate`(1) · `打出大招`(1) | 会话门面的「五之三 单机牌组」下半 —— 四区域视图与徽章、武器栏 / 大招槽 / 牌库计数、出牌命令、回合结束与意图。 |
| `session/battle_flow.gd` | `SessionBattleFlow` | `RefCounted` | 491 | 22220 | 6690 | 14.3% | 1 | 19 | — | 会话门面的「五 战斗」重实现部分 —— 开战装配、试玩靶机、回合推进、战后结算与给券。 |
| `session/battle_hand_view.gd` | `SessionBattleHandView` | `RefCounted` | 447 | 20485 | 6151 | 12.1% | 0 | 31 | `卡目标方`(1) · `单机牌组开`(1) · `deck_mode_active`(1) · `select_battle_unit`(1) · `点选机体`(1) · `selected_unit_view`(1) · `selected_unit`(1) · `upper_hand_cards`(1) · `衍生视图们`(1) · `pending_cards`(1) · `lower_hand_cards`(1) | 会话门面的「五之三 单机牌组」上半 —— 选机体、上排 / 下排、公有牌判定与卡面行。 |
| `session/battle_options.gd` | `SessionBattleOptions` | `RefCounted` | 20 | 884 | 274 | 44.6% | 0 | 1 | `生产`(14) | 职责：生产战斗选项的**唯一来源** —— 节点战 / 追击战 / 快速测试 / 会话缓存都从这里取。 |
| `session/data_loader.gd` | `DataLoader` | `RefCounted` | 186 | 7382 | 2222 | 13.9% | 4 | 10 | `install`(67) · `load_game_data`(2) | 从 res://data/js/ 与 res://data/cards/ 读入全部数据，构造 GameData。IO … |
| `session/display_helpers.gd` | `SessionDisplayHelpers` | `RefCounted` | 378 | 17180 | 5138 | 14.2% | 0 | 24 | `mithril_link_state`(1) · `battle_log_lines`(1) · `battle_log_entries`(1) · `unit_view`(1) · `topbar_state`(1) · `result_summary`(1) · `战果文字`(1) · `太阳炉明细`(1) · `太阳炉左栏文`(1) · `介入标记`(1) · `出鞘标记文`(1) · `卡出鞘文`(1) · `默认拔刀目标`(1) · `默认太阳炉牌`(1) | 会话门面的「六 展示辅助」子模块 —— 战报 / 单位卡 / 顶栏 / 结算摘要，以及末端「天人 v0.1 的表现层读… |
| `session/game_session.gd` | `GameSession` | `RefCounted` | 1320 | 49698 | 14768 | 11.3% | 25 | 282 | `QTE模式文`(3) · `start_new_run` · `save_current_run` · `load_saved_run` · `has_saved_run` · `available_squads` · `in_battle` · `is_quick_battle` · `ticket_count` · `roster_count` · `还没走过格` · `有未决的招募券` · `战前编队确认中` · `当前动作错误` · `当前节点结算键` | 职责：会话门面 —— 玩家命令的唯一入口；表现为**零 `J.*`**、**零引擎依赖**的纯逻辑对象。 |
| `session/live_monitor.gd` | `SessionLiveMonitor` | `RefCounted` | 146 | 5811 | 1722 | 13.9% | 0 | 11 | `snapshot_for_monitor`(1) | 会话门面的「一之三 实时监视」子模块 —— 动作历史记录 + 完整局面快照（纯观测，不改任何业务规则与返回值）。 |
| `session/roster_facade.gd` | `SessionRosterFacade` | `RefCounted` | 316 | 14717 | 4378 | 8.1% | 0 | 25 | `recruit_unit`(1) · `有未决的券`(1) · `discard_ticket`(1) · `promote_unit`(1) · `pick_tactical_card`(1) · `refresh_card_offers`(1) · `lineup_slots`(1) · `normalize_lineup_slots`(1) · `规范编队槽位`(1) · `set_lineup_slot`(1) · `deploy_unit`(1) · `remove_from_lineup`(1) · `undeploy_unit`(1) · `clear_lineup`(1) · `available_recruit_targets`(1) | 会话门面的「三 名册 / 招募 / 晋升 / 三选一 / 编队」子模块。 |
| `session/run_facade.gd` | `SessionRunFacade` | `RefCounted` | 437 | 22160 | 6633 | 11.3% | 0 | 35 | `preview_cell_move`(1) · `move_to_cell`(1) · `move_to`(1) · `use_part`(1) · `use_part_on_cell`(1) · `fight_chase_battle`(1) · `trigger_pursuit_battle`(1) · `enter_current_node`(1) · `try_advance_floor`(1) · `advance_floor`(1) · `resolve_rest`(1) · `rest_action`(1) · `buy_from_shop`(1) · `shop_buy`(1) · `refresh_shop`(1) | 会话门面的「二 大地图与零件 / 四 非战斗节点」子模块 —— 移动、零件、追击战、换层、休整 / 黑市 / 奇遇结算。 |
| `session/save_service.gd` | `SaveService` | `RefCounted` | 390 | 10359 | 3062 | 24.0% | 2 | 13 | `serialize`(12) · `deserialize`(6) · `load_from_file`(5) · `save_to_file`(4) · `parse_dict`(2) · `落盘路径` | 存档服务（原生 Godot，**零 `J.*`**）。 |
| `session/tooltip_text.gd` | `SessionTooltipText` | `RefCounted` | 339 | 16264 | 4868 | 5.0% | 0 | 12 | `unit_hover_text`(1) · `template_unit_hover_text`(1) · `card_hover_text`(1) · `part_can_use_now`(1) · `part_hover_text`(1) · `relic_hover_text`(1) | 会话门面的「六之二 悬停说明」子模块 —— 机体 / 卡面 / 零件 / 藏品的 Mouse Over 文本（纯读）。 |

### §2.3 presentation · 表现层（只许经 GameSession 调内核） —— 25 个文件 · 9090 行

| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |
|---|---|---|---|---|---|---|---|---|---|---|
| `presentation/battle/battle_animation_layer.gd` | — | `Control` | 330 | 12256 | 3661 | 11.6% | 0 | 25 | `set_intent_links` · `意图连线数` · `set_guard_links` · `护卫连线数` · `清空` · `set_aim` · `瞄准中` · `set_trajectories` · `set_popups` · `开始淡出` · `弹道数` · `飘字数` · `飞卡数` · `播放飞卡` | 职责：战斗动画覆盖层（`Control`）—— 弹道 / 飘字 / 飞卡 / 援护连线 / 拖拽瞄准线的绘制与淡出。 |
| `presentation/battle/battle_fx_player.gd` | — | `RefCounted` | 679 | 27716 | 8507 | 12.4% | 0 | 42 | `构建单拍演出帧` · `演出帧数` · `已播帧数` | 职责：演出帧构建（发牌 / 攻击 / 修理 / 战术牌 / 事件 / 横幅）、弹道与飘字、卡片反馈。 |
| `presentation/battle/battle_view.gd` | `BattleView` | `Control` | 620 | 35238 | 10777 | 13.7% | 47 | 198 | `setup` · `refresh` · `需QTE弹窗` · `QTE弹窗显示中` · `开感应牌库面板` · `关感应牌库面板` · `感应面板显示中` · `援护连线数` · `播报文本` · `手牌卡控件们` · `联动高亮` · `友军可投放高亮中` · `左库卡控件们` · `可拖拽释放` · `拖拽瞄准线` | 职责：战斗屏协调层 —— 建三栏骨架、把各面板 / 演出子模块装起来、对测试与外部保留同名转发。 |
| `presentation/battle/board_panel.gd` | — | `RefCounted` | 541 | 23082 | 7009 | 11.2% | 0 | 34 | `援护连线数` · `播报文本` | 职责：4×4 棋盘（敌方 / 战线 / 我方）、双方机体卡填充、援护连线、动作播报条与本拍摘要。 |
| `presentation/battle/colonial_overlay.gd` | — | `RefCounted` | 178 | 8195 | 2509 | 11.6% | 0 | 10 | `需QTE弹窗` · `弹QTE` · `选QTE` · `取消QTE` · `建QTE弹层` · `开感应面板` · `关感应面板` · `建感应面板` · `级文` · `级色` | 职责：殖民卫星军的两个覆盖层 —— QTE 手动弹窗（大招结算前选「失手 / 成功 / 完美」）与感应牌库明细面板。 |
| `presentation/battle/deck_sidebar.gd` | — | `RefCounted` | 324 | 15922 | 4859 | 11.1% | 0 | 14 | `左库卡控件们` | 职责：左栏牌库三分区（武器大招 / 精神待入库 / 公有副牌库）、高密度左库卡与副牌库概览。 |
| `presentation/battle/drag_aim.gd` | — | `RefCounted` | 312 | 12941 | 3991 | 6.7% | 0 | 30 | `可拖拽释放` · `拖拽瞄准线` · `开始拖拽` · `拖拽到` · `结束拖拽` · `取消拖拽` · `拖拽中` · `拖拽按住点` | 职责：武器卡拖拽状态机、吸附判定、瞄准线数据与鼠标接线（`_process` 心跳）。 |
| `presentation/battle/hand_card_item.gd` | — | `RefCounted` | 280 | 13440 | 4088 | 11.4% | 0 | 12 | — | 职责：一张手牌 / 单机牌卡面的构建、字号自适应、悬停文案与点击打出（含卡面文字行）。 |
| `presentation/battle/hand_panel.gd` | — | `RefCounted` | 326 | 16704 | 5135 | 13.7% | 0 | 26 | `手牌卡控件们` · `联动高亮` · `友军可投放高亮中` | 职责：手牌三栏 + 公有排的双排手牌栏、卡牌缩放、分组标签与联动高亮。 |
| `presentation/battle/log_panel.gd` | — | `RefCounted` | 263 | 13498 | 4192 | 10.1% | 0 | 17 | — | 职责：右栏战报、推进 / 自动 / 倍速 / 跳过 / 结算按钮、牌库点打与顶部状态叠层。 |
| `presentation/battle/result_view.gd` | `ResultView` | `Control` | 308 | 16373 | 5017 | 30.3% | 1 | 13 | `setup` · `refresh` | 结算屏：胜负 / 战后回血前后对照 / 战利品 / 战斗日志回顾。 |
| `presentation/boot/boot.gd` | — | `Control` | 389 | 17744 | 5411 | 50.8% | 0 | 25 | `smoke_checksum` · `启动` · `route` · `视图键` · `去屏` · `打开弹窗` · `关闭弹窗` · `当前视图` | 唯一的标题 / 路由壳（Stage M4-2 重写；`res://presentation/boot/boot.tsc… |
| `presentation/menus/event_view.gd` | `EventView` | `Control` | 178 | 7981 | 2442 | 28.2% | 0 | 10 | `setup` · `refresh` | 奇遇 / 瞭望站 / 遗迹 / 侵蚀源（Stage M4-2）。 |
| `presentation/menus/menu_view.gd` | `MenuView` | `Control` | 241 | 12470 | 3864 | 27.8% | 0 | 18 | `setup` · `refresh` · `随机种子` | 主菜单 + 分队选择屏（Stage M4-2；`session.screen` 为 `"menu" \| "squad"… |
| `presentation/menus/pick_card_view.gd` | `PickCardView` | `Control` | 137 | 6789 | 2070 | 27.7% | 0 | 8 | `setup` · `refresh` | 3 选 1 战术牌构筑弹窗（Stage M4-2）。 |
| `presentation/menus/rest_view.gd` | `RestView` | `Control` | 143 | 7044 | 2163 | 32.1% | 0 | 9 | `setup` · `refresh` | 休整（Stage M4-2）。 |
| `presentation/menus/roster_view.gd` | `RosterView` | `Control` | 341 | 17766 | 5420 | 21.6% | 0 | 16 | `setup` · `refresh` | 招募与晋升面板（Stage M4-2）。 |
| `presentation/menus/shop_view.gd` | `ShopView` | `Control` | 230 | 10648 | 3242 | 21.8% | 0 | 12 | `setup` · `refresh` | 黑市（Stage M4-2）。 |
| `presentation/run_map/formation_view.gd` | `FormationView` | `Control` | 551 | 25832 | 7883 | 37.7% | 1 | 25 | `setup` · `refresh` | 8 格编队（前排 4 + 后排 4，正交 4×2 · Stage M4-2）。 |
| `presentation/run_map/map_view.gd` | `MapView` | `Control` | 711 | 38478 | 11878 | 37.5% | 2 | 25 | `setup` · `refresh` · `选中预告` · `瞄准零件` | 正方形大地图（Stage M4-2，本单最难的一块）。 |
| `presentation/theme/ui_theme.gd` | `UiTheme` | `RefCounted` | 314 | 12766 | 3864 | 35.7% | 52 | 22 | `文本`(190) · `建标签`(90) · `建盒`(83) · `建按钮`(58) · `建说明`(50) · `占满`(28) · `建面板`(16) · `建滚动`(12) · `底样式`(11) · `节点全名`(9) · `无声模式`(9) · `占满留边`(8) · `建标题`(5) · `建比例条`(2) · `建分隔`(2) | 表现层视觉常量与建控件小工具（Stage M4-2）。 |
| `presentation/widgets/hover_tooltip.gd` | `HoverTooltip` | `Control` | 296 | 14125 | 4315 | 50.2% | 10 | 18 | `bind`(19) · `重绑` · `show_for_control` · `show_text` · `hide_tip` · `当前文本` | 悬停说明层（Mouse Over Tooltip）—— **整局只有一层**，挂在 boot 的最后一个子节点上。 |
| `presentation/widgets/modal_layer.gd` | `ModalLayer` | `Control` | 268 | 10577 | 3245 | 31.9% | 0 | 16 | `setup` · `refresh` · `标题Of` | 弹窗层（Stage M4-2）—— **所有弹窗都走这一个层**，不要每屏各弹各的。 |
| `presentation/widgets/top_bar.gd` | `TopBar` | `Control` | 372 | 20233 | 6201 | 33.8% | 0 | 16 | `setup` · `refresh` | 顶栏常驻状态条（Stage M4-2）。 |
| `presentation/widgets/unit_card.gd` | `UnitCard` | `Control` | 758 | 26598 | 8012 | 5.1% | 10 | 43 | `setup` · `setup_unit` · `设紧凑棋盘` · `refresh` · `选中中` · `设为选中` · `set_card_source_highlight` · `联动高亮中` · `set_aim_highlight` · `瞄准高亮中` · `set_combat_fx` · `play_action_feedback` · `clear_combat_fx` · `combat_fx_kind` · `战斗反馈中` | 单位卡（Stage M4-2 建骨架，**Stage M4-3 的战斗屏复用 / 扩展**）。 |

### §2.4 tests · 测试与黄金样例（可以认识所有层） —— 81 个文件 · 27319 行

| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |
|---|---|---|---|---|---|---|---|---|---|---|
| `tests/golden_compare.gd` | `GoldenCompare` | `RefCounted` | 68 | 3160 | 945 | 25.3% | 0 | 3 | `decode`(27) · `diff`(27) · `compare_events`(1) | 黄金样例比对器（测试专用）。M2 起 Battle Core 的输出用它与 JS 导出的期望逐项比对。 |
| `tests/golden_io.gd` | `GoldenIO` | `RefCounted` | 45 | 1428 | 417 | 26.8% | 0 | 4 | `load_json`(19) · `encode`(8) · `bits_to_float`(5) · `float_to_bits` | 读取黄金样例的工具（测试专用）。 |
| `tests/native_golden_policy.gd` | `NativeGoldenPolicy` | `RefCounted` | 172 | 8524 | 2590 | 21.8% | 1 | 8 | `按槽位`(2) · `出牌阶段` · `找下一张` · `挑目标` · `打出` | 职责：原生黄金样例的**确定性出牌策略** —— 替玩家把每回合能打的牌按固定顺序打完（不掷任何随机数）。 |
| `tests/native_golden_runner.gd` | `NativeGoldenRunner` | `RefCounted` | 235 | 10327 | 3140 | 18.3% | 2 | 14 | `run`(4) · `展开`(4) · `认编成`(1) · `压缩`(1) · `compare`(1) · `开局` · `摘要` · `纯数据` | 职责：用生产选项 + 确定性出牌策略重跑一场**原生**黄金样例（RT-2：新模式的标准答案）。 |
| `tests/run_tests.gd` | — | `SceneTree` | 101 | 3152 | 921 | 22.9% | 0 | 2 | — | 唯一测试入口（本地与 CI 同一条命令）： |
| `tests/unit/layout_fixtures.gd` | `LayoutFixtures` | `RefCounted` | 297 | 10160 | 3026 | 14.3% | 8 | 34 | `run` | 职责：版面门禁的公共夹具（原 `test_presentation_layout.gd` 顶部「工具」一节 + 各段共… |
| `tests/unit/test_armor_pool.gd` | — | `RefCounted` | 187 | 9602 | 2855 | 34.0% | 2 | 15 | `run` | ★ A1（作者 2026-10-17 拍板）：**装甲在「一次攻击」内是一个共享抵消池** —— 内核验收。 |
| `tests/unit/test_atx_chips.gd` | — | `RefCounted` | 584 | 37549 | 11314 | 21.9% | 2 | 29 | `run` | ★ A3b：ATX「筹码牌库」10 张牌 + 【赌局】触发管线 + 「放入 X」—— 内核验收。 |
| `tests/unit/test_atx_faction_v03.gd` | — | `RefCounted` | 653 | 37954 | 11358 | 17.3% | 1 | 35 | `run` | ★ A6d 验收：① 新旧同名卡退场（7 张旧卡一张都不进牌池）；② 势力牌 9 张按 v0.3 重写； |
| `tests/unit/test_atx_godsbet_and_luck.gd` | — | `RefCounted` | 610 | 33641 | 10188 | 19.9% | 1 | 32 | `run` | ★ A4（响介 v0.3「赌神」+ 艾克赛琳【强运】）—— 内核验收。 |
| `tests/unit/test_atx_nine_lives.gd` | — | `RefCounted` | 334 | 18322 | 5506 | 30.5% | 1 | 21 | `run` | ★ A2（作者 2026-10-17 拍板）：ATX 势力机制【九死一生】—— 内核验收。 |
| `tests/unit/test_atx_smoke.gd` | — | `RefCounted` | 598 | 33579 | 10144 | 19.9% | 1 | 31 | `run` | ★ A5a（拉米亚 v0.1）：「烟雾」场上状态 + 【雾袭】关键词 + 烟雾弹副武器 —— 内核验收。 |
| `tests/unit/test_atx_spread_and_rewrite.gd` | — | `RefCounted` | 525 | 30221 | 9072 | 22.3% | 2 | 34 | `run` | ★ A5b（拉米亚 v0.1 / 响介 v0.1）：武器「**段数改写**」层 +「**散布**」（每段随机换目标）—… |
| `tests/unit/test_atx_three_v01.gd` | — | `RefCounted` | 1054 | 62109 | 18744 | 18.2% | 2 | 42 | `run` | ★ A6c（响介 / 艾克赛琳 / 拉米亚 v0.1 三人卡表）—— 内核验收。 |
| `tests/unit/test_atx_v03_wiring.gd` | — | `RefCounted` | 675 | 38124 | 11490 | 17.7% | 1 | 21 | `run` | ★ 第 3 / 5 / 6 / 7 项断路器修复（DS41F）的**端到端**验收。 |
| `tests/unit/test_battle_screen.gd` | — | `RefCounted` | 172 | 9694 | 2962 | 16.8% | 0 | 6 | `run` | 职责：战斗屏端到端冒烟 —— 真开一局战斗再验（专属排 / 公有排 / 打牌 / 推进 / 自动打完 / 结算）。 |
| `tests/unit/test_blockade.gd` | — | `RefCounted` | 38 | 2882 | 877 | 13.4% | 0 | 1 | `run` | 职责：N1【封锁线】—— 敌方前排 4 格都有活着的机体、且场上有带「封锁线」的敌机时， |
| `tests/unit/test_boss_phase_entry.gd` | — | `RefCounted` | 115 | 5653 | 1692 | 2.8% | 0 | 10 | `run` | 职责：Boss 阶段进场事件（B 稿 N4）：进新阶段只执行一次 —— 叫增援 / 套词条 / 写战报；`除非` 条件… |
| `tests/unit/test_boss_retreat.gd` | — | `RefCounted` | 78 | 4019 | 1212 | 3.8% | 0 | 6 | `run` | 职责：敌方中途撤退（B 稿 N9）：到线 / 到回合撤离 → 移出战场、判我方胜利；结算希望 / 源碳减半、不发零件。 |
| `tests/unit/test_boundary.gd` | — | `RefCounted` | 212 | 10784 | 3210 | 17.9% | 6 | 8 | `run` | 边界门禁：core/ 必须是纯逻辑（迁移架构 §6.1 / §5.2 / §5.3）。 |
| `tests/unit/test_bounty.gd` | — | `RefCounted` | 38 | 2792 | 855 | 13.4% | 0 | 1 | `run` | 职责：N2【悬赏令】—— 敌方阶段开始标记我方本回合输出最高者；带悬赏令的敌机够得着就只打它、伤害 +20%； |
| `tests/unit/test_build_info.gd` | — | `RefCounted` | 15 | 1050 | 318 | 26.2% | 0 | 1 | `run` | ★ BUILD：主菜单那行「版本 0.7.1-m0（<提交> · <构建时间>）· 规则参考 …」的取名逻辑。 |
| `tests/unit/test_card_table_snapshot.gd` | — | `RefCounted` | 171 | 8375 | 2569 | 10.4% | 1 | 13 | `run` · `快照注册表` | 卡表等价快照：各卡包注册表的卡表用 `var_to_str` 序列化后，与 `tests/golden/card_ta… |
| `tests/unit/test_celestial_v01.gd` | — | `RefCounted` | 1650 | 98744 | 29697 | 12.4% | 2 | 48 | `run` · `t_info_fail` · `无天人队` · `拿炉` | ★ CB-1（任务单 §1.2）：天人 v0.1 公共机制 —— TRANS-AM / 【武力介入】/ 太阳炉牌库 /… |
| `tests/unit/test_class_cards.gd` | — | `RefCounted` | 722 | 43781 | 13281 | 19.1% | 1 | 41 | `run` | ★ A6a：三套**职业分类牌** 18 张（近卫 6 / 尖兵 6 / 重装 6）+ 拉米亚双势力 + 「散布击杀计… |
| `tests/unit/test_class_heavy_cmd.gd` | — | `RefCounted` | 712 | 41510 | 12521 | 19.8% | 1 | 38 | `run` | ★ A6b：塔斯克（A6 · 重装）+ 雷欧娜（A7 · 指挥）—— |
| `tests/unit/test_colonial_mooks.gd` | — | `RefCounted` | 145 | 8465 | 2561 | 6.2% | 1 | 8 | `run` | ★ COL-MOOK-1：殖民卫星军两名大众脸（卡特尔 W4 尖兵 / 五飞 W5 特种）—— |
| `tests/unit/test_colonial_presentation.gd` | — | `RefCounted` | 217 | 11531 | 3491 | 9.5% | 0 | 8 | `run` | ★ COL-4b（施工单 §2 COL-4）：表现层接线 —— QTE 手动弹窗 / 感应牌金边 / 觉醒徽章配色 /… |
| `tests/unit/test_colonial_units.gd` | — | `RefCounted` | 355 | 18433 | 5539 | 16.8% | 2 | 19 | `run` | ★ COL-3（施工单 §2）：五人卡池与独有机制 —— 装填档位 / 贯穿一列 / 斩首 / 破隐一击 / METE… |
| `tests/unit/test_colonial_v01.gd` | — | `RefCounted` | 497 | 27974 | 8422 | 14.1% | 2 | 24 | `run` · `双` | ★ COL-2（施工单 §2）：殖民卫星军核心 —— 觉醒框架（SEED / ZERO / 隐身）+ QTE 接口 +… |
| `tests/unit/test_cr1_review_fixes.gd` | — | `RefCounted` | 181 | 10825 | 3268 | 23.4% | 0 | 12 | `run` | CR-1（Claude Opus 5.5 Code Review，2026-10-18）：P1-1 / P1-2 / … |
| `tests/unit/test_cr2_pipelines.gd` | — | `RefCounted` | 783 | 39461 | 11974 | 18.5% | 4 | 46 | `run` | CR-2 Batch A（**红灯复现**）：P2-2 / P2-3 / P2-4 / P2-5 的门禁。 |
| `tests/unit/test_data.gd` | — | `RefCounted` | 38 | 2081 | 626 | 19.8% | 1 | 1 | `run` | 数据层：从 JS 参考版导出的内容数据能完整读入，规模与来源可核对，小数无损。 |
| `tests/unit/test_display_names.gd` | — | `RefCounted` | 42 | 2243 | 686 | 13.7% | 1 | 1 | `run` | 显示名表骨架与取名入口：八个分区齐全；表里有就用表里的，没有就回落到兜底 / 卡包名。 |
| `tests/unit/test_fac_turn_start.gd` | — | `RefCounted` | 150 | 9105 | 2777 | 19.1% | 2 | 9 | `run` | 职责：BR-1 / BR-1.1 正面断言 —— 「我方阶段初」这一拍真的在干活： |
| `tests/unit/test_faction_layers.gd` | — | `RefCounted` | 127 | 6024 | 1809 | 13.0% | 1 | 7 | `run` | 职责：第 2 层起各层阵营敌机（cw_ / ok_ / hg_ / tr_）的数据落地与开战冒烟。 |
| `tests/unit/test_font_coverage.gd` | — | `RefCounted` | 47 | 1987 | 585 | 17.4% | 3 | 2 | `run` | 字体覆盖：工程里会上屏的每个非 ASCII 字符（汉字、标点、符号、emoji），项目字体或它的后备字体里都要有。 |
| `tests/unit/test_iteration_fixes.gd` | — | `RefCounted` | 147 | 8177 | 2501 | 13.7% | 0 | 9 | `run` | 试玩反馈迭代（10-21 夜起）的回归测试：一条反馈一段，防止修好的问题回来。 |
| `tests/unit/test_js_compat.gd` | — | `RefCounted` | 27 | 1451 | 427 | 5.0% | 0 | 1 | `run` | JsCompat：与 JS 结算语义对齐的四舍五入与稳定排序。 |
| `tests/unit/test_l1_enemies.gd` | — | `RefCounted` | 92 | 5003 | 1499 | 8.3% | 2 | 7 | `run` | 职责：第 1 层新敌机（lr_ 六台）与三条编成（1-L1~1-L3）的数据与开战冒烟。 |
| `tests/unit/test_lambda_resonance.gd` | — | `RefCounted` | 31 | 2116 | 632 | 10.7% | 0 | 1 | `run` | 职责：N3【λ 共振】—— λ 力场减免量按单位读；同侧 ≥2 台带「λ共振」的 λ 机在场时，每回合减免次数 2 →… |
| `tests/unit/test_layout_board.gd` | — | `func` | 497 | 27875 | 8374 | 13.0% | 0 | 8 | `走一遍` | 职责：版面门禁：棋盘（段 14 4×4 棋盘与援护连线 / 段 15 敌方前后排按真实 slot 对齐与友方目标选中）。 |
| `tests/unit/test_layout_drag.gd` | — | `func` | 208 | 14379 | 4318 | 9.9% | 0 | 5 | `走一遍` | 职责：版面门禁：拖拽瞄准（段 13 武器卡拖动释放 / 拥有者→目标瞄准连线 / 指定目标出伤害）。 |
| `tests/unit/test_layout_flow.gd` | — | `func` | 496 | 26591 | 8049 | 14.0% | 0 | 13 | `走一遍` | 职责：版面门禁：肉鸽流程（段 4 试玩反馈四个修复 / 段 6 战前编队确认与顶栏锁 / 段 7 幂等休整与战后给券）。 |
| `tests/unit/test_layout_hand.gd` | — | `func` | 503 | 29369 | 8856 | 13.2% | 1 | 20 | `走一遍` | 职责：版面门禁：手牌（段 12 DECK-2/DECK-3 单机牌组战斗屏：点选机体 / 战意条 / 上下双排 / 即… |
| `tests/unit/test_layout_log.gd` | — | `func` | 463 | 30477 | 9182 | 16.9% | 0 | 4 | `走一遍` | 职责：版面门禁：战报栏与播报层（段 5 实时监视与全动作记录 / 段 11 UX-3 动作播报条与战斗动画层）。 |
| `tests/unit/test_layout_screens.gd` | — | `func` | 444 | 22890 | 7000 | 13.7% | 0 | 16 | `走一遍` | 职责：版面门禁：单屏可见性与弹窗不误遮挡（段 1）+ 顶栏与主屏 1280×720 边界（段 2）。 |
| `tests/unit/test_layout_sidebar.gd` | — | `func` | 414 | 24088 | 7287 | 11.8% | 1 | 7 | `走一遍` | 职责：版面门禁：左牌库与手牌栏（段 16 手牌栏三栏零滚动自适应 / 左牌库三分类 / 天人 11 张友方目标 / 友… |
| `tests/unit/test_layout_tooltip.gd` | — | `func` | 327 | 16895 | 5158 | 18.2% | 0 | 14 | `走一遍` | 职责：版面门禁：Mouse-Over 说明信息（段 3：机体卡 / 编队格位 / 名册 / 招募候选 / 手牌 / 候… |
| `tests/unit/test_layout_ux1.gd` | — | `func` | 471 | 22953 | 6923 | 13.0% | 0 | 12 | `走一遍` | 职责：版面门禁：UX-1 六项修复（段 9：战后回大地图 / 编队拖拽 / 藏品零件悬停 / 零件瞄准横幅）。 |
| `tests/unit/test_mithril_v03.gd` | — | `RefCounted` | 885 | 54973 | 16518 | 13.1% | 1 | 29 | `run` | ★ MITH3-1 ~ MITH3-4 验收：武器范围规则 v0.1 + 卡牌流转规则 v0.1 + 秘银 v0.3（… |
| `tests/unit/test_moon_cards.gd` | — | `RefCounted` | 202 | 10842 | 3280 | 4.2% | 2 | 17 | `run` | 月球王国 v0.2.1 单卡细节：螺旋式打桩机亮起 / 不动如山 / 弦月·一闪随侍必中 / 自卫激光枪 / 陨石召唤… |
| `tests/unit/test_moon_units.gd` | — | `RefCounted` | 236 | 12319 | 3721 | 5.7% | 2 | 15 | `run` | 月球王国 v0.2.1 五人：刀枪切换（站位层）/ 拘束与重力网 / 月华溢流护盾 / 换位牌走 BattleSwap… |
| `tests/unit/test_moon_v02.gd` | — | `RefCounted` | 249 | 14324 | 4320 | 6.2% | 2 | 18 | `run` | 月球王国 v0.2.1 核心：开关 / 月相开局 / 随侍与换位 / 月面偏导 / ★随侍抽牌 / 月光牌库断路器 /… |
| `tests/unit/test_named_bosses.gd` | — | `RefCounted` | 104 | 5277 | 1596 | 8.6% | 3 | 6 | `run` | 职责：第 1～4 层代号 Boss 池（守关 / 终点 / 精英头目）的数据落地与开战冒烟。 |
| `tests/unit/test_native_goldens.gd` | — | `RefCounted` | 103 | 4550 | 1386 | 19.7% | 3 | 5 | `run` | RT-2d：原生黄金样例（Godot 原生标准答案）逐场重跑并对拍 —— 这是本仓唯一的战斗黄金样例。 |
| `tests/unit/test_particle_suppression.gd` | — | `RefCounted` | 29 | 1950 | 591 | 13.6% | 0 | 1 | `run` | 职责：N4【粒子抑制场】—— 敌方每台活着的粒子散布机算 1 层（最多 2 层）： |
| `tests/unit/test_presentation_layout.gd` | — | `const` | 20 | 772 | 226 | 15.0% | 1 | 1 | `run` | 职责：版面门禁薄入口 —— 按原顺序调各 test_layout_*.gd 的 走一遍()，每段只跑 1 次。 |
| `tests/unit/test_presentation_smoke.gd` | — | `RefCounted` | 876 | 46740 | 14175 | 19.0% | 3 | 33 | `run` | Stage M4-2 表现层 UI 冒烟（契约 §7）：段 1 ~ 6，加段 3b / 3c / 4b / 4c / … |
| `tests/unit/test_quick_battle_v03.gd` | — | `RefCounted` | 458 | 28134 | 8510 | 22.5% | 3 | 18 | `run` | ★ A7 收官批验收：「快速测试战斗」双入口（秘银五人 Lv30 / ATX 五人 Lv30）+ 筹码牌库 UI 展示… |
| `tests/unit/test_quick_new_factions.gd` | — | `RefCounted` | 47 | 1926 | 579 | 7.6% | 0 | 3 | `run` | 月球王国 / 影世界 v0.2.1 的快速测试入口：门面开得起来、新模块接手、战斗画面能画、连打几回合不报错。 |
| `tests/unit/test_repair_cards.gd` | — | `RefCounted` | 329 | 20050 | 6040 | 19.7% | 0 | 19 | `run` · `tar_armorCut` · `tar_掩护补充` | 第 7 职业【维修】6 张分类牌 + 【过量整备】的单元断言（含公有冷却区 / 每场 1 次移出本场）。 |
| `tests/unit/test_rf0_fixes.gd` | — | `RefCounted` | 150 | 8079 | 2452 | 14.8% | 0 | 7 | `run` | 职责：RF-0 三处缺陷修复的回归测试。 |
| `tests/unit/test_rival.gd` | — | `RefCounted` | 54 | 3493 | 1049 | 8.2% | 0 | 3 | `run` | 职责：Boss 宿敌骨架（B 稿 N1 宿敌在场 / N2 指定角色修正 / N3 猎杀名单）。 |
| `tests/unit/test_rng.gd` | — | `RefCounted` | 26 | 1208 | 358 | 19.7% | 0 | 1 | `run` | Mulberry32 与 JS 参考版逐位一致（向量由 tools/gen_rng_vectors.mjs 从 JS … |
| `tests/unit/test_run_core.gd` | — | `RefCounted` | 553 | 29921 | 9043 | 16.5% | 1 | 16 | `run` | Stage M3-Core-B 单元测试： |
| `tests/unit/test_run_golden.gd` | — | `RefCounted` | 105 | 6366 | 1943 | 20.2% | 1 | 1 | `run` | 局外（肉鸽）黄金样例的形状与自洽校验：godot/tests/golden/run_vectors.json |
| `tests/unit/test_run_map.gd` | — | `RefCounted` | 1035 | 55018 | 16541 | 12.6% | 2 | 19 | `run` | Stage M3-Core-A 单元测试：大地图生成 / 导航 / 零件（原生 Godot，零 `J.*`）。 |
| `tests/unit/test_session_flow.gd` | — | `RefCounted` | 1898 | 107039 | 32341 | 16.7% | 4 | 42 | `run` | Stage M4-1 单元测试：会话门面 `GameSession` 的 headless 会话流（**真跑内核，不 … |
| `tests/unit/test_session_run.gd` | — | `RefCounted` | 517 | 26772 | 8152 | 28.3% | 6 | 14 | `run` | ★ 端到端回归：**用门面（`GameSession`）完整打通一局肉鸽**（固定种子 20261016 / 分队「混… |
| `tests/unit/test_shadow_cards.gd` | — | `RefCounted` | 244 | 11927 | 3586 | 2.5% | 2 | 13 | `run` | 影世界 v0.2.1 卡牌效果：四人的副武器 / 命中后换位 / 被动，五张大招，势力牌；外加开选项的整场冒烟。 |
| `tests/unit/test_shadow_chain.gd` | — | `RefCounted` | 25 | 1646 | 500 | 10.0% | 0 | 1 | `run` | 职责：N5【影锁拽位】—— 锁链抓投机用「影锁」打中我方后排 → 和同列前排换位；打前排、别的武器、旧敌机都不拽。 |
| `tests/unit/test_shadow_v02.gd` | — | `RefCounted` | 298 | 16116 | 4859 | 7.4% | 2 | 21 | `run` | 影世界 v0.2.1 试玩 MVP：开关 / 移位计数 / ★错位抽牌 / 影门牌库三级断路器 / 影种 / 深渊之门… |
| `tests/unit/test_sub_deck.gd` | — | `RefCounted` | 110 | 5783 | 1757 | 18.0% | 1 | 4 | `run` | ★ A3a：通用「副牌库（SubDeck）」层的单元断言 —— 抽一张 / 回库或移出 / 放入（断路器）。 |
| `tests/unit/test_swap.gd` | — | `RefCounted` | 297 | 17727 | 5318 | 20.3% | 1 | 20 | `run` | 换位底座（`BattleSwap`）单元断言：原语 / 合用范围 / 6 项刷新链 / 三步意图规则 / 顶位 / 掩… |
| `tests/unit/test_ticket_keep.gd` | — | `RefCounted` | 30 | 1650 | 500 | 9.3% | 0 | 1 | `run` | 职责：招募券留存（作者 10-22 试玩反馈）：最多留 3 张；≤3 张且名册非空可以不招直接走；>3 张或名册空才拦。 |
| `tests/unit/test_unit_deck_system.gd` | — | `RefCounted` | 923 | 56435 | 17098 | 14.5% | 2 | 33 | `run` · `J以` | DECK-1 / DECK-2 内核验收：单机牌组（阶段制 + 单机战意 + 主武器卡 / 衍生攻击卡 + 7 职业 … |
| `tests/unit/test_unit_keys.gd` | — | `RefCounted` | 98 | 5200 | 1562 | 16.0% | 1 | 7 | `run` | 职责：BR-1.1-b 正面断言 —— 同一场里同一个敌人键出现第二次就发 `键#2`、`键#3`… |
| `tests/unit/test_ux4_lineup_slots.gd` | — | `RefCounted` | 249 | 13182 | 3966 | 17.3% | 1 | 9 | `run` | ★ UX-4（M4 二轮试玩反馈第 1 条）：**编队屏摆成什么样，进战斗就站什么样**， |
| `tests/unit/test_ux5_ux6_feedback.gd` | — | `RefCounted` | 359 | 20960 | 6412 | 28.8% | 2 | 11 | `run` | M4 试玩反馈二轮修复：UX-5（0.5 秒串行战斗 / 发牌动画队列）+ UX-6（删掉憋大招按钮与必经点文案）。 |
| `tests/unit/test_weapon_bar_lookup.gd` | — | `RefCounted` | 47 | 2720 | 834 | 26.1% | 1 | 3 | `run` | `BattleWeaponExec._找武器栏卡` 的回归：**传字典也要能把武器栏里第 2 张及以后的牌找出来**。 |

### §2.5 其他（不属于上面四层） —— 7 个文件 · 787 行

| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |
|---|---|---|---|---|---|---|---|---|---|---|
| `tools/compare_gate_g.gd` | — | `SceneTree` | 102 | 4382 | 1322 | 13.6% | 3 | 3 | — | 职责：闸门 G 的**签字依据** —— 把「删前」那份原生样例里的 `类型 == "发牌"` 事件去掉，再与「删后」… |
| `tools/diff_native_summary.gd` | — | `SceneTree` | 133 | 5209 | 1560 | 7.5% | 3 | 8 | `有差异` | 职责：§0.3 原生样例差异摘要 —— 只统计两份录制（重录前 / 重录后），不打开内容给人看。 |
| `tools/export_card_pack.gd` | — | `SceneTree` | 105 | 3294 | 978 | 6.7% | 0 | 6 | — | 一次性卡包导出脚本：调用现有卡表取表函数生成 JSON 卡包，并输出需还原为 int 的字段路径清单。 |
| `tools/extract_native_inputs.gd` | — | `SceneTree` | 96 | 4428 | 1343 | 25.6% | 4 | 2 | — | 职责：把旧战斗黄金样例的**输入**抽成 `tests/golden/native/inputs.json`（只取输入… |
| `tools/record_native_golden.gd` | — | `SceneTree` | 162 | 7370 | 2220 | 9.5% | 2 | 4 | — | 职责：headless 录原生黄金样例 —— 按 `tests/golden/native/inputs.json` … |
| `tools/record_run_golden.gd` | — | `SceneTree` | 139 | 6556 | 1972 | 7.3% | 4 | 4 | — | 职责：headless 录**局外（肉鸽）黄金样例** —— 地图 / 推进剂 / 招募券 / 晋升面板 / 三选一战… |
| `tools/smoke_colonial_quick.gd` | — | `SceneTree` | 50 | 2163 | 657 | 29.3% | 2 | 1 | — | 职责：殖民卫星军「快速测试战斗（五人）」的**无头连跑自检** —— 不同种子各开一局、自动打完， |

---

## §3 核心模块的正向与反向依赖矩阵

> **口径**：依赖 = 「A 的**代码**里出现了 B 的 `class_name`」或「A `preload/load` 了 B」；`n` = 该类名在 A 里出现的**次数**（不是去重符号数）。**`tests/` 的依赖不参与矩阵**（测试本来就该认识所有层），它们只出现在 JSON 的 `files[].dependsOn` 里。

### §3.1 层间依赖矩阵（行 = 依赖方，格 = `边数 / 文件数`）

| 从 \ 到 | core | session | presentation | tests | 合计出边 |
|---|---|---|---|---|---|
| **core** | 652 / 75 | — | — | — | 652 |
| **session** | 92 / 12 | 19 / 9 | 1 / 1 | — | 112 |
| **presentation** | 50 / 22 | 16 / 15 | 59 / 24 | — | 125 |
| **tests** | 480 / 73 | 98 / 71 | 58 / 21 | 35 / 19 | 671 |
| **其他** | 15 / 4 | 7 / 5 | — | 11 / 5 | 33 |

### §3.2 反向依赖：被最多模块引用的文件（生产层 top 22）

| # | 文件 | class_name | 被依赖文件数 | 依赖边数 | 谁在依赖它（前 6） |
|---|---|---|---|---|---|
| 1 | `core/util/js.gd` | `J` | 63 | 3096 | core/battle/ai.gd · core/battle/ai_deck.gd · core/battle/atx_chips.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_godsbet.gd |
| 2 | `core/battle/btl.gd` | `Btl` | 55 | 950 | core/battle/ai.gd · core/battle/ai_deck.gd · core/battle/atx_chips.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_godsbet.gd |
| 3 | `core/data/db.gd` | `Db` | 52 | 189 | core/battle/ai.gd · core/battle/atx_chips.gd · core/battle/atx_duo.gd · core/battle/atx_three.gd · core/battle/boss.gd · core/battle/calc.gd |
| 4 | `core/battle/units.gd` | `Units` | 50 | 224 | core/battle/ai.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_smoke.gd · core/battle/atx_three.gd · core/battle/boss.gd |
| 5 | `core/battle/fm.gd` | `Fm` | 47 | 318 | core/battle/ai.gd · core/battle/atx_duo.gd · core/battle/atx_smoke.gd · core/battle/atx_three.gd · core/battle/calc.gd · core/battle/card_effects.gd |
| 6 | `core/battle/deck_flow.gd` | `DeckFlow` | 27 | 92 | core/battle/atx_chips.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_smoke.gd · core/battle/atx_three.gd · core/battle/card_exec.gd |
| 7 | `core/battle/reach.gd` | `Reach` | 27 | 187 | core/battle/ai.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_three.gd · core/battle/boss.gd · core/battle/calc.gd |
| 8 | `core/battle/params.gd` | `Params` | 26 | 107 | core/battle/ai.gd · core/battle/atx_chips.gd · core/battle/calc.gd · core/battle/card_effects.gd · core/battle/card_exec.gd · core/battle/card_play.gd |
| 9 | `session/game_session.gd` | `GameSession` | 25 | 293 | presentation/battle/battle_view.gd · presentation/battle/colonial_overlay.gd · presentation/battle/result_view.gd · presentation/boot/boot.gd · presentation/menus/event_view.gd · presentation/menus/menu_view.gd |
| 10 | `core/util/js_compat.gd` | `JsCompat` | 24 | 63 | core/battle/card_effects.gd · core/battle/relic_battle.gd · core/run/deck_builder.gd · core/run/map_generator.gd · core/run/map_navigator.gd · core/run/node_resolver.gd |
| 11 | `presentation/theme/ui_theme.gd` | `UiTheme` | 24 | 1245 | presentation/battle/battle_animation_layer.gd · presentation/battle/battle_fx_player.gd · presentation/battle/battle_view.gd · presentation/battle/board_panel.gd · presentation/battle/colonial_overlay.gd · presentation/battle/deck_sidebar.gd |
| 12 | `core/run/run_state.gd` | `RunState` | 23 | 213 | core/run/deck_builder.gd · core/run/map_generator.gd · core/run/map_navigator.gd · core/run/node_resolver.gd · core/run/part_system.gd · core/run/relic_system.gd |
| 13 | `core/battle/calc.gd` | `Calc` | 22 | 51 | core/battle/ai.gd · core/battle/ai_deck.gd · core/battle/atx_chips.gd · core/battle/atx_three.gd · core/battle/boss.gd · core/battle/card_effects.gd |
| 14 | `core/battle/setup.gd` | `Setup` | 21 | 51 | core/battle/atx_chips.gd · core/battle/atx_duo.gd · core/battle/atx_faction.gd · core/battle/atx_smoke.gd · core/battle/atx_three.gd · core/battle/celestial_v01.gd |
| 15 | `core/battle/card_effects.gd` | `CardEffects` | 16 | 26 | core/battle/atx_faction.gd · core/battle/atx_luck.gd · core/battle/atx_smoke.gd · core/battle/atx_three.gd · core/battle/card_exec.gd · core/battle/celestial_v01.gd |
| 16 | `core/battle/fac.gd` | `Fac` | 16 | 63 | core/battle/ai.gd · core/battle/atx_chips.gd · core/battle/calc.gd · core/battle/card_effects.gd · core/battle/fac_cb.gd · core/battle/fac_mith.gd |
| 17 | `core/run/roster_manager.gd` | `RosterManager` | 16 | 117 | core/run/node_resolver.gd · core/run/relic_system.gd · presentation/battle/result_view.gd · presentation/menus/menu_view.gd · presentation/menus/roster_view.gd · presentation/run_map/formation_view.gd |
| 18 | `core/battle/card_play.gd` | `CardPlay` | 13 | 52 | core/battle/atx_chips.gd · core/battle/atx_three.gd · core/battle/card_exec.gd · core/battle/celestial_v01.gd · core/battle/colonial_units.gd · core/battle/colonial_v01.gd |
| 19 | `core/battle/rule_hooks.gd` | `RuleHooks` | 13 | 61 | core/battle/ai.gd · core/battle/calc.gd · core/battle/card_effects.gd · core/battle/card_exec.gd · core/battle/card_play.gd · core/battle/colonial_v01.gd |
| 20 | `core/battle/atx_duo.gd` | `AtxDuo` | 12 | 22 | core/battle/ai.gd · core/battle/boss.gd · core/battle/card_effects.gd · core/battle/card_exec.gd · core/battle/data_fn.gd · core/battle/fac_atx.gd |
| 21 | `core/battle/celestial_v01.gd` | `CelestialV01` | 12 | 53 | core/battle/atx_duo.gd · core/battle/calc.gd · core/battle/card_effects.gd · core/battle/card_exec.gd · core/battle/flow.gd · core/battle/guard.gd |
| 22 | `core/battle/flow.gd` | `Flow` | 12 | 20 | core/battle/atx_three.gd · core/battle/boss.gd · core/battle/card_exec.gd · core/battle/deck_flow.gd · core/battle/fac_atx.gd · core/battle/fac_moon.gd |

### §3.3 正向依赖：每个生产文件依赖谁（`→ 目标(n)`，括号里是被引用的符号）

**core/**（75 个文件有出边）

- `core/battle/ai.gd`：→ `core/battle/atx_duo.gd`(2：AtxDuo) → `core/battle/atx_faction.gd`(1：AtxFaction) → `core/battle/boss.gd`(1：Boss) → `core/battle/btl.gd`(2：Btl) → `core/battle/calc.gd`(6：Calc) → `core/battle/class_cards.gd`(1：ClassCards)
  → `core/battle/diff.gd`(1：Diff) → `core/battle/fac.gd`(1：Fac) → `core/battle/fm.gd`(4：Fm) → `core/battle/params.gd`(3：Params) → `core/battle/reach.gd`(27：Reach) → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/units.gd`(9：Units)
  → `core/data/db.gd`(1：Db) → `core/util/js.gd`(22：J)
- `core/battle/ai_deck.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/btl.gd`(2：Btl) → `core/battle/calc.gd`(2：Calc) → `core/util/js.gd`(2：J)
- `core/battle/atx_chips.gd`：→ `core/battle/btl.gd`(18：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/card_play.gd`(3：CardPlay) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fac.gd`(1：Fac) → `core/battle/params.gd`(1：Params)
  → `core/battle/setup.gd`(1：Setup) → `core/battle/sub_deck.gd`(5：SubDeck) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(63：J)
- `core/battle/atx_duo.gd`：→ `core/battle/btl.gd`(12：Btl) → `core/battle/celestial_v01.gd`(2：CelestialV01) → `core/battle/deck_flow.gd`(5：DeckFlow) → `core/battle/fm.gd`(3：Fm) → `core/battle/guard.gd`(3：BattleGuard) → `core/battle/reach.gd`(5：Reach)
  → `core/battle/setup.gd`(1：Setup) → `core/battle/units.gd`(4：Units) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(37：J)
- `core/battle/atx_faction.gd`：→ `core/battle/atx_chips.gd`(3：AtxChips) → `core/battle/btl.gd`(32：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fac_atx.gd`(31：FacAtx)
  → `core/battle/mithril_v03_cards.gd`(1：MithrilV03Cards) → `core/battle/reach.gd`(1：Reach) → `core/battle/setup.gd`(1：Setup) → `core/battle/sub_deck.gd`(1：SubDeck) → `core/battle/units.gd`(7：Units) → `core/util/js.gd`(61：J)
- `core/battle/atx_godsbet.gd`：→ `core/battle/btl.gd`(13：Btl) → `core/battle/fac_atx.gd`(1：FacAtx) → `core/util/js.gd`(26：J)
- `core/battle/atx_luck.gd`：→ `core/battle/btl.gd`(2：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/util/js.gd`(24：J)
- `core/battle/atx_rewrite.gd`：→ `core/battle/btl.gd`(4：Btl) → `core/util/js.gd`(33：J)
- `core/battle/atx_smoke.gd`：→ `core/battle/btl.gd`(15：Btl) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fm.gd`(2：Fm) → `core/battle/setup.gd`(2：Setup) → `core/battle/units.gd`(1：Units)
  → `core/util/js.gd`(31：J)
- `core/battle/atx_three.gd`：→ `core/battle/atx_chips.gd`(2：AtxChips) → `core/battle/atx_faction.gd`(5：AtxFaction) → `core/battle/atx_godsbet.gd`(2：AtxGodsbet) → `core/battle/atx_luck.gd`(2：AtxLuck) → `core/battle/atx_rewrite.gd`(1：AtxRewrite)
  → `core/battle/atx_smoke.gd`(3：AtxSmoke) → `core/battle/btl.gd`(53：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/card_play.gd`(3：CardPlay) → `core/battle/deck_flow.gd`(1：DeckFlow)
  → `core/battle/fac_atx.gd`(5：FacAtx) → `core/battle/flow.gd`(5：Flow) → `core/battle/fm.gd`(6：Fm) → `core/battle/mithril_v03_cards.gd`(1：MithrilV03Cards) → `core/battle/reach.gd`(10：Reach) → `core/battle/setup.gd`(1：Setup)
  → `core/battle/units.gd`(14：Units) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(205：J)
- `core/battle/battle_log.gd`：→ `core/util/js.gd`(19：J)
- `core/battle/boss.gd`：→ `core/battle/ai.gd`(6：Ai) → `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/btl.gd`(13：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/data_fn.gd`(3：DataFn) → `core/battle/diff.gd`(1：Diff)
  → `core/battle/flow.gd`(1：Flow) → `core/battle/reach.gd`(5：Reach) → `core/battle/rival.gd`(3：Rival) → `core/battle/swap.gd`(2：BattleSwap) → `core/battle/traits.gd`(1：Traits) → `core/battle/units.gd`(4：Units) → `core/data/db.gd`(2：Db)
  → `core/util/js.gd`(61：J)
- `core/battle/btl.gd`：→ `core/battle/battle_log.gd`(12：BattleLog) → `core/battle/card_exec.gd`(15：BattleCardExec) → `core/battle/card_pool.gd`(31：BattleCardPool) → `core/battle/guard.gd`(16：BattleGuard) → `core/battle/intent.gd`(4：BattleIntent)
  → `core/battle/morale.gd`(9：BattleMorale) → `core/battle/phase_flow.gd`(9：BattlePhaseFlow) → `core/battle/weapon_exec.gd`(12：BattleWeaponExec)
- `core/battle/calc.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/atx_chips.gd`(1：AtxChips) → `core/battle/atx_godsbet.gd`(8：AtxGodsbet) → `core/battle/atx_rewrite.gd`(1：AtxRewrite) → `core/battle/atx_smoke.gd`(1：AtxSmoke)
  → `core/battle/btl.gd`(13：Btl) → `core/battle/celestial_v01.gd`(1：CelestialV01) → `core/battle/fac.gd`(9：Fac) → `core/battle/fac_mith.gd`(1：FacMith) → `core/battle/fm.gd`(13：Fm) → `core/battle/params.gd`(36：Params)
  → `core/battle/reach.gd`(17：Reach) → `core/battle/rule_hooks.gd`(10：RuleHooks) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(2：Db) → `core/util/js.gd`(299：J) → `core/util/rng.gd`(2：Mulberry32)
- `core/battle/card_effects.gd`：→ `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/atx_three.gd`(1：AtxThree) → `core/battle/btl.gd`(11：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/celestial_v01.gd`(2：CelestialV01)
  → `core/battle/class_cards.gd`(1：ClassCards) → `core/battle/fac.gd`(2：Fac) → `core/battle/fac_atx.gd`(1：FacAtx) → `core/battle/fm.gd`(5：Fm) → `core/battle/mithril_v03_cards.gd`(1：MithrilV03Cards) → `core/battle/params.gd`(1：Params)
  → `core/battle/reach.gd`(2：Reach) → `core/battle/repair_cards.gd`(1：RepairCards) → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/units.gd`(6：Units) → `core/data/db.gd`(1：Db) → `core/util/js_compat.gd`(4：JsCompat)
- `core/battle/card_exec.gd`：→ `core/battle/atx_chips.gd`(3：AtxChips) → `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/atx_faction.gd`(5：AtxFaction) → `core/battle/atx_godsbet.gd`(2：AtxGodsbet) → `core/battle/atx_luck.gd`(1：AtxLuck)
  → `core/battle/atx_rewrite.gd`(1：AtxRewrite) → `core/battle/atx_smoke.gd`(1：AtxSmoke) → `core/battle/atx_three.gd`(2：AtxThree) → `core/battle/btl.gd`(48：Btl) → `core/battle/card_effects.gd`(3：CardEffects) → `core/battle/card_play.gd`(5：CardPlay)
  → `core/battle/celestial_v01.gd`(5：CelestialV01) → `core/battle/deck_flow.gd`(5：DeckFlow) → `core/battle/fac_atx.gd`(2：FacAtx) → `core/battle/flow.gd`(1：Flow) → `core/battle/params.gd`(1：Params) → `core/battle/public_cooldown.gd`(2：PublicCooldown)
  → `core/battle/rule_hooks.gd`(2：RuleHooks) → `core/battle/units.gd`(5：Units) → `core/util/js.gd`(69：J)
- `core/battle/card_play.gd`：→ `core/battle/btl.gd`(15：Btl) → `core/battle/deck_flow.gd`(2：DeckFlow) → `core/battle/morale.gd`(1：BattleMorale) → `core/battle/params.gd`(1：Params) → `core/battle/reach.gd`(3：Reach)
  → `core/battle/rule_hooks.gd`(6：RuleHooks) → `core/battle/units.gd`(2：Units) → `core/util/js.gd`(13：J)
- `core/battle/card_pool.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/btl.gd`(1：Btl) → `core/battle/calc.gd`(2：Calc) → `core/battle/data_fn.gd`(1：DataFn) → `core/battle/fm.gd`(2：Fm) → `core/battle/units.gd`(1：Units) → `core/util/js.gd`(46：J)
- `core/battle/celestial_v01.gd`：→ `core/battle/btl.gd`(99：Btl) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/card_play.gd`(5：CardPlay) → `core/battle/deck_flow.gd`(3：DeckFlow) → `core/battle/fm.gd`(4：Fm)
  → `core/battle/guard.gd`(2：BattleGuard) → `core/battle/reach.gd`(7：Reach) → `core/battle/setup.gd`(7：Setup) → `core/battle/sub_deck.gd`(17：SubDeck) → `core/battle/units.gd`(4：Units) → `core/data/db.gd`(5：Db) → `core/util/js.gd`(228：J)
- `core/battle/class_cards.gd`：→ `core/battle/btl.gd`(9：Btl) → `core/battle/data_fn.gd`(1：DataFn) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fm.gd`(12：Fm) → `core/battle/reach.gd`(4：Reach) → `core/battle/setup.gd`(2：Setup)
  → `core/battle/units.gd`(5：Units) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(66：J)
- `core/battle/colonial_awaken.gd`：→ `core/battle/btl.gd`(20：Btl) → `core/battle/colonial_deck.gd`(1：ColonialDeck) → `core/battle/colonial_units.gd`(1：ColonialUnits) → `core/battle/reach.gd`(2：Reach) → `core/battle/units.gd`(1：Units)
  → `core/util/js.gd`(41：J)
- `core/battle/colonial_deck.gd`：→ `core/battle/atx_luck.gd`(1：AtxLuck) → `core/battle/btl.gd`(32：Btl) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/colonial_awaken.gd`(13：ColonialAwaken)
  → `core/battle/colonial_units.gd`(1：ColonialUnits) → `core/battle/colonial_v01.gd`(1：ColonialV01) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/params.gd`(2：Params) → `core/battle/setup.gd`(2：Setup) → `core/battle/sub_deck.gd`(7：SubDeck)
  → `core/battle/units.gd`(1：Units) → `core/data/db.gd`(5：Db) → `core/util/js.gd`(34：J)
- `core/battle/colonial_units.gd`：→ `core/battle/btl.gd`(35：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/card_play.gd`(3：CardPlay) → `core/battle/colonial_awaken.gd`(18：ColonialAwaken) → `core/battle/colonial_deck.gd`(2：ColonialDeck)
  → `core/battle/deck_flow.gd`(3：DeckFlow) → `core/battle/fm.gd`(2：Fm) → `core/battle/reach.gd`(4：Reach) → `core/battle/setup.gd`(2：Setup) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(2：Db) → `core/util/js.gd`(122：J)
- `core/battle/colonial_v01.gd`：→ `core/battle/btl.gd`(13：Btl) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/card_play.gd`(6：CardPlay) → `core/battle/colonial_awaken.gd`(38：ColonialAwaken)
  → `core/battle/colonial_deck.gd`(10：ColonialDeck) → `core/battle/colonial_units.gd`(19：ColonialUnits) → `core/battle/deck_flow.gd`(2：DeckFlow) → `core/battle/rule_hooks.gd`(4：RuleHooks) → `core/data/db.gd`(2：Db) → `core/util/js.gd`(40：J)
- `core/battle/data_fn.gd`：→ `core/battle/atx_duo.gd`(1：AtxDuo) → `core/data/db.gd`(4：Db) → `core/util/js.gd`(5：J)
- `core/battle/deck_flow.gd`：→ `core/battle/btl.gd`(62：Btl) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/card_play.gd`(2：CardPlay) → `core/battle/fac_mith.gd`(4：FacMith) → `core/battle/faction_identity.gd`(1：FactionIdentity)
  → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(4：Fm) → `core/battle/mithril_v03_cards.gd`(10：MithrilV03Cards) → `core/battle/params.gd`(1：Params) → `core/battle/public_cooldown.gd`(2：PublicCooldown)
  → `core/battle/rule_hooks.gd`(20：RuleHooks) → `core/battle/sub_deck.gd`(7：SubDeck) → `core/battle/swap.gd`(1：BattleSwap) → `core/battle/units.gd`(7：Units) → `core/util/js.gd`(117：J)
- `core/battle/diff.gd`：→ `core/battle/data_fn.gd`(1：DataFn) → `core/battle/fm.gd`(1：Fm) → `core/battle/units.gd`(1：Units) → `core/data/db.gd`(4：Db) → `core/util/js.gd`(31：J)
- `core/battle/enemy_mech.gd`：→ `core/battle/btl.gd`(9：Btl) → `core/battle/calc.gd`(2：Calc) → `core/battle/card_play.gd`(1：CardPlay) → `core/battle/fm.gd`(3：Fm) → `core/battle/morale.gd`(3：BattleMorale) → `core/battle/reach.gd`(2：Reach)
  → `core/battle/swap.gd`(1：BattleSwap) → `core/battle/units.gd`(2：Units) → `core/util/js.gd`(23：J)
- `core/battle/fac.gd`：→ `core/battle/btl.gd`(1：Btl) → `core/battle/fac_cb.gd`(3：FacCb) → `core/battle/fac_mith.gd`(6：FacMith) → `core/battle/fac_moon.gd`(8：FacMoon) → `core/battle/units.gd`(1：Units) → `core/data/db.gd`(1：Db) → `core/util/js.gd`(8：J)
- `core/battle/fac_atx.gd`：→ `core/battle/atx_chips.gd`(1：AtxChips) → `core/battle/atx_duo.gd`(3：AtxDuo) → `core/battle/atx_faction.gd`(5：AtxFaction) → `core/battle/atx_godsbet.gd`(3：AtxGodsbet) → `core/battle/atx_luck.gd`(1：AtxLuck)
  → `core/battle/atx_three.gd`(2：AtxThree) → `core/battle/btl.gd`(25：Btl) → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(4：Fm) → `core/battle/reach.gd`(3：Reach) → `core/battle/units.gd`(14：Units) → `core/data/db.gd`(3：Db)
  → `core/util/js.gd`(62：J)
- `core/battle/fac_cb.gd`：→ `core/battle/fac.gd`(7：Fac) → `core/battle/units.gd`(1：Units) → `core/util/js.gd`(34：J)
- `core/battle/fac_mith.gd`：→ `core/battle/calc.gd`(2：Calc) → `core/battle/fac.gd`(12：Fac) → `core/battle/fm.gd`(2：Fm) → `core/battle/units.gd`(3：Units) → `core/util/js.gd`(87：J)
- `core/battle/fac_moon.gd`：→ `core/battle/btl.gd`(2：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/fac.gd`(12：Fac) → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(4：Fm) → `core/battle/moon_v02.gd`(1：MoonV02)
  → `core/battle/params.gd`(3：Params) → `core/battle/units.gd`(3：Units) → `core/util/js.gd`(73：J)
- `core/battle/faction_identity.gd`：→ `core/battle/btl.gd`(9：Btl) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fac_atx.gd`(1：FacAtx) → `core/util/js.gd`(11：J)
- `core/battle/flow.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/boss.gd`(2：Boss) → `core/battle/btl.gd`(40：Btl) → `core/battle/calc.gd`(10：Calc) → `core/battle/celestial_v01.gd`(5：CelestialV01)
  → `core/battle/class_cards.gd`(2：ClassCards) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fac.gd`(9：Fac) → `core/battle/fm.gd`(9：Fm) → `core/battle/params.gd`(7：Params) → `core/battle/reach.gd`(8：Reach)
  → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/traits.gd`(1：Traits) → `core/battle/units.gd`(14：Units) → `core/util/js.gd`(67：J)
- `core/battle/fm.gd`：→ `core/data/db.gd`(8：Db) → `core/util/js.gd`(14：J)
- `core/battle/focus_fire.gd`：→ `core/battle/btl.gd`(2：Btl) → `core/util/js.gd`(2：J)
- `core/battle/guard.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/btl.gd`(9：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/celestial_v01.gd`(1：CelestialV01) → `core/battle/class_cards.gd`(1：ClassCards)
  → `core/battle/fac.gd`(1：Fac) → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(23：Fm) → `core/battle/params.gd`(10：Params) → `core/battle/reach.gd`(7：Reach) → `core/battle/setup.gd`(1：Setup) → `core/battle/units.gd`(17：Units)
  → `core/util/js.gd`(71：J)
- `core/battle/intent.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/boss.gd`(3：Boss) → `core/battle/btl.gd`(1：Btl) → `core/battle/fm.gd`(4：Fm) → `core/battle/reach.gd`(8：Reach) → `core/battle/units.gd`(3：Units) → `core/util/js.gd`(13：J)
- `core/battle/mithril_v03_cards.gd`：→ `core/battle/btl.gd`(58：Btl) → `core/battle/deck_flow.gd`(17：DeckFlow) → `core/battle/fac_mith.gd`(6：FacMith) → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(6：Fm) → `core/battle/reach.gd`(1：Reach)
  → `core/battle/setup.gd`(2：Setup) → `core/battle/swap.gd`(1：BattleSwap) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(155：J)
- `core/battle/moon_deck.gd`：→ `core/battle/btl.gd`(27：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/moon_faction.gd`(1：MoonFaction) → `core/battle/moon_phase.gd`(19：MoonPhase)
  → `core/battle/params.gd`(1：Params) → `core/battle/setup.gd`(1：Setup) → `core/battle/sub_deck.gd`(6：SubDeck) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(5：Db) → `core/util/js.gd`(23：J)
- `core/battle/moon_faction.gd`：→ `core/battle/btl.gd`(3：Btl) → `core/battle/fm.gd`(12：Fm) → `core/battle/moon_deck.gd`(12：MoonDeck) → `core/battle/moon_phase.gd`(17：MoonPhase) → `core/battle/setup.gd`(2：Setup) → `core/battle/swap.gd`(5：BattleSwap)
  → `core/battle/units.gd`(2：Units) → `core/util/js.gd`(6：J)
- `core/battle/moon_phase.gd`：→ `core/battle/btl.gd`(16：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/fac.gd`(1：Fac) → `core/battle/fm.gd`(7：Fm) → `core/battle/units.gd`(4：Units) → `core/util/js.gd`(25：J)
- `core/battle/moon_units.gd`：→ `core/battle/btl.gd`(20：Btl) → `core/battle/card_effects.gd`(3：CardEffects) → `core/battle/card_play.gd`(5：CardPlay) → `core/battle/deck_flow.gd`(4：DeckFlow) → `core/battle/fm.gd`(17：Fm)
  → `core/battle/moon_deck.gd`(15：MoonDeck) → `core/battle/moon_phase.gd`(43：MoonPhase) → `core/battle/setup.gd`(2：Setup) → `core/battle/swap.gd`(2：BattleSwap) → `core/battle/units.gd`(9：Units) → `core/data/db.gd`(2：Db) → `core/util/js.gd`(43：J)
- `core/battle/moon_v02.gd`：→ `core/battle/moon_deck.gd`(7：MoonDeck) → `core/battle/moon_phase.gd`(17：MoonPhase) → `core/battle/moon_units.gd`(15：MoonUnits) → `core/battle/units.gd`(1：Units) → `core/util/js.gd`(2：J)
- `core/battle/morale.gd`：→ `core/battle/params.gd`(2：Params) → `core/util/js.gd`(13：J)
- `core/battle/params.gd`：→ `core/battle/calc.gd`(4：Calc) → `core/battle/fac_mith.gd`(1：FacMith) → `core/battle/fm.gd`(42：Fm) → `core/battle/reach.gd`(37：Reach) → `core/battle/units.gd`(4：Units) → `core/data/db.gd`(1：Db) → `core/util/js.gd`(76：J)
- `core/battle/phase_flow.gd`：→ `core/battle/ai_deck.gd`(1：res://core/battle/ai_deck.gd) → `core/battle/atx_faction.gd`(1：AtxFaction) → `core/battle/btl.gd`(15：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/celestial_v01.gd`(1：CelestialV01)
  → `core/battle/deck_flow.gd`(4：DeckFlow) → `core/battle/flow.gd`(1：Flow) → `core/battle/fm.gd`(4：Fm) → `core/battle/params.gd`(4：Params) → `core/battle/rule_hooks.gd`(10：RuleHooks) → `core/battle/setup.gd`(8：Setup) → `core/battle/units.gd`(6：Units)
  → `core/data/db.gd`(1：Db) → `core/util/js.gd`(15：J)
- `core/battle/public_cooldown.gd`：→ `core/battle/btl.gd`(1：Btl) → `core/util/js.gd`(8：J)
- `core/battle/reach.gd`：→ `core/battle/calc.gd`(1：Calc) → `core/battle/class_cards.gd`(1：ClassCards) → `core/battle/fac_mith.gd`(1：FacMith) → `core/battle/fm.gd`(40：Fm) → `core/battle/params.gd`(3：Params) → `core/battle/units.gd`(3：Units)
  → `core/data/db.gd`(7：Db) → `core/util/js.gd`(35：J)
- `core/battle/relic_battle.gd`：→ `core/data/db.gd`(2：Db) → `core/util/js.gd`(60：J) → `core/util/js_compat.gd`(2：JsCompat)
- `core/battle/repair_cards.gd`：→ `core/battle/btl.gd`(19：Btl) → `core/battle/guard.gd`(2：BattleGuard) → `core/battle/setup.gd`(1：Setup) → `core/battle/units.gd`(3：Units) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(38：J)
- `core/battle/rival.gd`：→ `core/battle/btl.gd`(2：Btl) → `core/battle/reach.gd`(1：Reach) → `core/battle/traits.gd`(1：Traits) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(1：Db) → `core/util/js.gd`(32：J)
- `core/battle/rule_hooks.gd`：→ `core/battle/atx_chips.gd`(6：AtxChips) → `core/battle/atx_duo.gd`(7：AtxDuo) → `core/battle/atx_faction.gd`(7：AtxFaction) → `core/battle/atx_godsbet.gd`(5：AtxGodsbet) → `core/battle/atx_luck.gd`(1：AtxLuck)
  → `core/battle/atx_smoke.gd`(6：AtxSmoke) → `core/battle/atx_three.gd`(14：AtxThree) → `core/battle/celestial_v01.gd`(15：CelestialV01) → `core/battle/class_cards.gd`(6：ClassCards) → `core/battle/colonial_v01.gd`(26：ColonialV01)
  → `core/battle/enemy_mech.gd`(5：EnemyMech) → `core/battle/fac.gd`(1：Fac) → `core/battle/fac_atx.gd`(1：FacAtx) → `core/battle/faction_identity.gd`(3：FactionIdentity) → `core/battle/flow.gd`(2：Flow) → `core/battle/focus_fire.gd`(2：FocusFire)
  → `core/battle/guard.gd`(2：BattleGuard) → `core/battle/mithril_v03_cards.gd`(1：MithrilV03Cards) → `core/battle/moon_v02.gd`(20：MoonV02) → `core/battle/repair_cards.gd`(5：RepairCards) → `core/battle/rival.gd`(3：Rival)
  → `core/battle/shadow_v02.gd`(19：ShadowV02) → `core/util/js.gd`(1：J)
- `core/battle/setup.gd`：→ `core/battle/atx_chips.gd`(1：AtxChips) → `core/battle/atx_duo.gd`(1：AtxDuo) → `core/battle/atx_faction.gd`(1：AtxFaction) → `core/battle/atx_godsbet.gd`(1：AtxGodsbet) → `core/battle/atx_smoke.gd`(1：AtxSmoke)
  → `core/battle/atx_three.gd`(2：AtxThree) → `core/battle/boss.gd`(1：Boss) → `core/battle/btl.gd`(14：Btl) → `core/battle/celestial_v01.gd`(3：CelestialV01) → `core/battle/deck_flow.gd`(3：DeckFlow) → `core/battle/diff.gd`(1：Diff)
  → `core/battle/fac.gd`(2：Fac) → `core/battle/fac_atx.gd`(1：FacAtx) → `core/battle/flow.gd`(1：Flow) → `core/battle/mithril_v03_cards.gd`(1：MithrilV03Cards) → `core/battle/params.gd`(11：Params) → `core/battle/relic_battle.gd`(1：RelicBattle)
  → `core/battle/rule_hooks.gd`(3：RuleHooks) → `core/battle/units.gd`(13：Units) → `core/data/db.gd`(4：Db) → `core/run/deck_builder.gd`(3：DeckBuilder) → `core/util/js.gd`(28：J) → `core/util/rng.gd`(1：Mulberry32)
- `core/battle/shadow_deck.gd`：→ `core/battle/btl.gd`(22：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/deck_flow.gd`(3：DeckFlow) → `core/battle/fm.gd`(4：Fm) → `core/battle/params.gd`(2：Params) → `core/battle/setup.gd`(2：Setup)
  → `core/battle/shadow_v02.gd`(56：ShadowV02) → `core/battle/sub_deck.gd`(5：SubDeck) → `core/battle/swap.gd`(6：BattleSwap) → `core/battle/units.gd`(6：Units) → `core/data/db.gd`(5：Db) → `core/util/js.gd`(58：J)
- `core/battle/shadow_ults.gd`：→ `core/battle/boss.gd`(1：Boss) → `core/battle/btl.gd`(1：Btl) → `core/battle/fm.gd`(9：Fm) → `core/battle/shadow_deck.gd`(8：ShadowDeck) → `core/battle/shadow_units.gd`(1：ShadowUnits)
  → `core/battle/shadow_v02.gd`(19：ShadowV02) → `core/battle/swap.gd`(1：BattleSwap) → `core/battle/units.gd`(5：Units) → `core/util/js.gd`(23：J)
- `core/battle/shadow_units.gd`：→ `core/battle/btl.gd`(17：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/card_play.gd`(4：CardPlay) → `core/battle/deck_flow.gd`(7：DeckFlow) → `core/battle/fm.gd`(8：Fm)
  → `core/battle/params.gd`(1：Params) → `core/battle/reach.gd`(2：Reach) → `core/battle/setup.gd`(1：Setup) → `core/battle/shadow_deck.gd`(6：ShadowDeck) → `core/battle/shadow_v02.gd`(28：ShadowV02) → `core/battle/swap.gd`(8：BattleSwap)
  → `core/battle/units.gd`(3：Units) → `core/util/js.gd`(46：J)
- `core/battle/shadow_v02.gd`：→ `core/battle/btl.gd`(6：Btl) → `core/battle/card_effects.gd`(1：CardEffects) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fac.gd`(1：Fac) → `core/battle/fm.gd`(1：Fm) → `core/battle/shadow_deck.gd`(8：ShadowDeck)
  → `core/battle/shadow_ults.gd`(1：ShadowUlts) → `core/battle/shadow_units.gd`(16：ShadowUnits) → `core/battle/sub_deck.gd`(1：SubDeck) → `core/battle/swap.gd`(2：BattleSwap) → `core/battle/units.gd`(4：Units) → `core/util/js.gd`(12：J)
- `core/battle/sub_deck.gd`：→ `core/util/js.gd`(1：J)
- `core/battle/swap.gd`：→ `core/battle/ai.gd`(5：Ai) → `core/battle/btl.gd`(5：Btl) → `core/battle/calc.gd`(1：Calc) → `core/battle/deck_flow.gd`(1：DeckFlow) → `core/battle/fm.gd`(3：Fm) → `core/battle/reach.gd`(8：Reach)
  → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/units.gd`(5：Units) → `core/util/js.gd`(28：J)
- `core/battle/traits.gd`：→ `core/battle/calc.gd`(1：Calc) → `core/battle/data_fn.gd`(2：DataFn) → `core/battle/diff.gd`(1：Diff) → `core/battle/fm.gd`(1：Fm) → `core/battle/params.gd`(2：Params) → `core/data/db.gd`(3：Db) → `core/util/js.gd`(93：J)
- `core/battle/units.gd`：→ `core/battle/calc.gd`(1：Calc) → `core/battle/data_fn.gd`(6：DataFn) → `core/battle/diff.gd`(1：Diff) → `core/battle/fm.gd`(3：Fm) → `core/battle/params.gd`(6：Params) → `core/battle/traits.gd`(1：Traits)
  → `core/data/db.gd`(3：Db) → `core/util/js.gd`(49：J)
- `core/battle/weapon_exec.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/atx_faction.gd`(3：AtxFaction) → `core/battle/atx_rewrite.gd`(1：AtxRewrite) → `core/battle/atx_smoke.gd`(2：AtxSmoke) → `core/battle/atx_three.gd`(2：AtxThree)
  → `core/battle/btl.gd`(55：Btl) → `core/battle/calc.gd`(4：Calc) → `core/battle/card_effects.gd`(2：CardEffects) → `core/battle/card_play.gd`(1：CardPlay) → `core/battle/celestial_v01.gd`(6：CelestialV01) → `core/battle/class_cards.gd`(2：ClassCards)
  → `core/battle/deck_flow.gd`(12：DeckFlow) → `core/battle/fac_mith.gd`(2：FacMith) → `core/battle/flow.gd`(4：Flow) → `core/battle/fm.gd`(4：Fm) → `core/battle/mithril_v03_cards.gd`(2：MithrilV03Cards) → `core/battle/params.gd`(1：Params)
  → `core/battle/reach.gd`(13：Reach) → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/units.gd`(8：Units) → `core/util/js.gd`(64：J)
- `core/data/db.gd`：→ `core/data/game_catalog.gd`(2：GameCatalog) → `core/data/game_data.gd`(1：GameData)
- `core/data/display_names.gd`：→ `core/data/db.gd`(2：Db)
- `core/run/deck_builder.gd`：→ `core/battle/atx_three.gd`(1：AtxThree) → `core/battle/btl.gd`(1：Btl) → `core/battle/celestial_v01.gd`(3：CelestialV01) → `core/battle/class_cards.gd`(1：ClassCards) → `core/battle/fac_atx.gd`(3：FacAtx)
  → `core/battle/mithril_v03_cards.gd`(4：MithrilV03Cards) → `core/battle/repair_cards.gd`(1：RepairCards) → `core/battle/rule_hooks.gd`(1：RuleHooks) → `core/battle/setup.gd`(7：Setup) → `core/data/db.gd`(3：Db) → `core/run/run_state.gd`(6：RunState)
  → `core/util/js_compat.gd`(1：JsCompat)
- `core/run/map_generator.gd`：→ `core/data/db.gd`(3：Db) → `core/run/run_state.gd`(3：RunState) → `core/util/js_compat.gd`(8：JsCompat) → `core/util/rng.gd`(3：Mulberry32)
- `core/run/map_navigator.gd`：→ `core/data/db.gd`(6：Db) → `core/run/map_generator.gd`(17：MapGenerator) → `core/run/part_system.gd`(3：PartSystem) → `core/run/run_state.gd`(26：RunState) → `core/util/js_compat.gd`(1：JsCompat)
- `core/run/node_resolver.gd`：→ `core/battle/btl.gd`(1：Btl) → `core/battle/data_fn.gd`(2：DataFn) → `core/battle/diff.gd`(1：Diff) → `core/battle/fm.gd`(11：Fm) → `core/battle/params.gd`(1：Params) → `core/battle/setup.gd`(2：Setup)
  → `core/battle/units.gd`(1：Units) → `core/data/db.gd`(30：Db) → `core/run/deck_builder.gd`(5：DeckBuilder) → `core/run/part_system.gd`(2：PartSystem) → `core/run/relic_system.gd`(11：RelicSystem) → `core/run/roster_manager.gd`(36：RosterManager)
  → `core/run/run_state.gd`(38：RunState) → `core/util/js_compat.gd`(4：JsCompat) → `core/util/rng.gd`(6：Mulberry32)
- `core/run/part_system.gd`：→ `core/data/db.gd`(6：Db) → `core/run/map_generator.gd`(2：MapGenerator) → `core/run/map_navigator.gd`(6：MapNavigator) → `core/run/run_state.gd`(23：RunState) → `core/util/js_compat.gd`(1：JsCompat)
  → `core/util/rng.gd`(3：Mulberry32)
- `core/run/relic_system.gd`：→ `core/data/db.gd`(2：Db) → `core/run/roster_manager.gd`(3：RosterManager) → `core/run/run_state.gd`(7：RunState) → `core/util/js_compat.gd`(1：JsCompat) → `core/util/rng.gd`(3：Mulberry32)
- `core/run/roster_manager.gd`：→ `core/battle/atx_duo.gd`(2：AtxDuo) → `core/battle/data_fn.gd`(1：DataFn) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(18：Db) → `core/run/deck_builder.gd`(8：DeckBuilder) → `core/run/run_state.gd`(27：RunState)
  → `core/util/js_compat.gd`(4：JsCompat) → `core/util/rng.gd`(5：Mulberry32)
- `core/run/run_state.gd`：→ `core/data/db.gd`(6：Db)
- `core/util/js.gd`：→ `core/util/js_compat.gd`(2：JsCompat)

**session/**（12 个文件有出边）

- `session/battle_deck_view.gd`：→ `core/battle/atx_chips.gd`(1：AtxChips) → `core/battle/btl.gd`(23：Btl) → `core/battle/card_play.gd`(5：CardPlay) → `core/battle/colonial_v01.gd`(2：ColonialV01) → `core/battle/deck_flow.gd`(6：DeckFlow)
  → `core/battle/fac.gd`(2：Fac) → `core/battle/params.gd`(3：Params) → `core/battle/reach.gd`(2：Reach) → `core/battle/units.gd`(1：Units) → `core/util/js_compat.gd`(1：JsCompat) → `session/game_session.gd`(71：GameSession)
- `session/battle_flow.gd`：→ `core/battle/btl.gd`(4：Btl) → `core/battle/fm.gd`(4：Fm) → `core/battle/setup.gd`(3：Setup) → `core/data/db.gd`(1：Db) → `core/run/map_navigator.gd`(3：MapNavigator) → `core/run/node_resolver.gd`(9：NodeResolver)
  → `core/run/roster_manager.gd`(8：RosterManager) → `core/run/run_state.gd`(5：RunState) → `core/util/rng.gd`(2：Mulberry32) → `session/game_session.gd`(28：GameSession)
- `session/battle_hand_view.gd`：→ `core/battle/atx_chips.gd`(2：AtxChips) → `core/battle/btl.gd`(14：Btl) → `core/battle/calc.gd`(2：Calc) → `core/battle/card_play.gd`(9：CardPlay) → `core/battle/colonial_v01.gd`(2：ColonialV01)
  → `core/battle/deck_flow.gd`(2：DeckFlow) → `core/battle/fac.gd`(1：Fac) → `core/battle/params.gd`(2：Params) → `core/battle/reach.gd`(6：Reach) → `core/battle/units.gd`(2：Units) → `session/game_session.gd`(49：GameSession)
- `session/battle_options.gd`：→ `core/run/relic_system.gd`(1：RelicSystem) → `core/run/run_state.gd`(1：RunState)
- `session/data_loader.gd`：→ `core/data/db.gd`(1：Db) → `core/data/game_data.gd`(2：GameData) → `core/version.gd`(2：GameVersion)
- `session/display_helpers.gd`：→ `core/battle/atx_godsbet.gd`(6：AtxGodsbet) → `core/battle/atx_rewrite.gd`(2：AtxRewrite) → `core/battle/atx_smoke.gd`(2：AtxSmoke) → `core/battle/btl.gd`(3：Btl) → `core/battle/calc.gd`(5：Calc)
  → `core/battle/celestial_v01.gd`(9：CelestialV01) → `core/battle/colonial_v01.gd`(5：ColonialV01) → `core/battle/deck_flow.gd`(3：DeckFlow) → `core/battle/fac.gd`(1：Fac) → `core/battle/fm.gd`(2：Fm)
  → `core/battle/mithril_v03_cards.gd`(2：MithrilV03Cards) → `core/battle/params.gd`(1：Params) → `core/battle/reach.gd`(1：Reach) → `core/data/db.gd`(1：Db) → `core/run/map_generator.gd`(1：MapGenerator) → `core/run/roster_manager.gd`(4：RosterManager)
  → `core/run/run_state.gd`(1：RunState) → `core/util/js_compat.gd`(2：JsCompat) → `session/game_session.gd`(24：GameSession)
- `session/game_session.gd`：→ `core/battle/colonial_deck.gd`(6：ColonialDeck) → `core/battle/fm.gd`(6：Fm) → `core/data/db.gd`(4：Db) → `core/run/node_resolver.gd`(4：NodeResolver) → `core/run/roster_manager.gd`(2：RosterManager)
  → `core/run/run_state.gd`(24：RunState) → `core/util/js_compat.gd`(1：JsCompat) → `presentation/theme/ui_theme.gd`(1：UiTheme) → `session/battle_deck_view.gd`(48：SessionBattleDeckView) → `session/battle_flow.gd`(18：SessionBattleFlow)
  → `session/battle_hand_view.gd`(31：SessionBattleHandView) → `session/battle_options.gd`(2：SessionBattleOptions) → `session/data_loader.gd`(1：DataLoader) → `session/display_helpers.gd`(24：SessionDisplayHelpers)
  → `session/live_monitor.gd`(10：SessionLiveMonitor) → `session/roster_facade.gd`(25：SessionRosterFacade) → `session/run_facade.gd`(35：SessionRunFacade) → `session/save_service.gd`(4：SaveService) → `session/tooltip_text.gd`(12：SessionTooltipText)
- `session/live_monitor.gd`：→ `core/battle/fm.gd`(1：Fm) → `core/run/deck_builder.gd`(1：DeckBuilder) → `core/run/part_system.gd`(2：PartSystem) → `core/run/relic_system.gd`(1：RelicSystem) → `core/run/roster_manager.gd`(3：RosterManager)
  → `core/run/run_state.gd`(6：RunState) → `core/util/js_compat.gd`(3：JsCompat) → `session/game_session.gd`(11：GameSession)
- `session/roster_facade.gd`：→ `core/battle/fm.gd`(2：Fm) → `core/data/db.gd`(2：Db) → `core/run/deck_builder.gd`(5：DeckBuilder) → `core/run/roster_manager.gd`(26：RosterManager) → `core/run/run_state.gd`(1：RunState)
  → `session/game_session.gd`(25：GameSession)
- `session/run_facade.gd`：→ `core/run/map_generator.gd`(3：MapGenerator) → `core/run/map_navigator.gd`(9：MapNavigator) → `core/run/node_resolver.gd`(17：NodeResolver) → `core/run/part_system.gd`(2：PartSystem) → `core/run/relic_system.gd`(1：RelicSystem)
  → `core/run/roster_manager.gd`(2：RosterManager) → `core/run/run_state.gd`(4：RunState) → `core/util/rng.gd`(1：Mulberry32) → `session/game_session.gd`(36：GameSession)
- `session/save_service.gd`：→ `core/run/run_state.gd`(5：RunState)
- `session/tooltip_text.gd`：→ `core/battle/ai.gd`(1：Ai) → `core/battle/boss.gd`(2：Boss) → `core/battle/btl.gd`(1：Btl) → `core/battle/fm.gd`(2：Fm) → `core/battle/reach.gd`(1：Reach) → `core/battle/units.gd`(2：Units) → `core/data/db.gd`(1：Db)
  → `core/run/deck_builder.gd`(2：DeckBuilder) → `core/run/part_system.gd`(9：PartSystem) → `core/run/relic_system.gd`(2：RelicSystem) → `core/run/roster_manager.gd`(1：RosterManager) → `core/util/js_compat.gd`(2：JsCompat)
  → `session/game_session.gd`(12：GameSession)

**presentation/**（25 个文件有出边）

- `presentation/battle/battle_animation_layer.gd`：→ `presentation/theme/ui_theme.gd`(15：UiTheme)
- `presentation/battle/battle_fx_player.gd`：→ `core/battle/fm.gd`(2：Fm) → `presentation/theme/ui_theme.gd`(29：UiTheme) → `presentation/widgets/unit_card.gd`(11：UnitCard)
- `presentation/battle/battle_view.gd`：→ `core/battle/fm.gd`(1：Fm) → `presentation/battle/battle_animation_layer.gd`(1：res://presentation/battle/battle_animation_layer.gd)
  → `presentation/battle/battle_fx_player.gd`(1：res://presentation/battle/battle_fx_player.gd) → `presentation/battle/board_panel.gd`(1：res://presentation/battle/board_panel.gd)
  → `presentation/battle/colonial_overlay.gd`(1：res://presentation/battle/colonial_overlay.gd) → `presentation/battle/deck_sidebar.gd`(1：res://presentation/battle/deck_sidebar.gd)
  → `presentation/battle/drag_aim.gd`(1：res://presentation/battle/drag_aim.gd) → `presentation/battle/hand_card_item.gd`(1：res://presentation/battle/hand_card_item.gd) → `presentation/battle/hand_panel.gd`(1：res://presentation/battle/hand_panel.gd)
  → `presentation/battle/log_panel.gd`(1：res://presentation/battle/log_panel.gd) → `presentation/theme/ui_theme.gd`(12：UiTheme) → `presentation/widgets/unit_card.gd`(7：UnitCard) → `session/game_session.gd`(2：GameSession)
- `presentation/battle/board_panel.gd`：→ `core/battle/ai.gd`(2：Ai) → `core/battle/boss.gd`(3：Boss) → `core/battle/enemy_mech.gd`(1：EnemyMech) → `core/battle/fm.gd`(12：Fm) → `core/battle/params.gd`(1：Params) → `core/util/js_compat.gd`(2：JsCompat)
  → `presentation/theme/ui_theme.gd`(30：UiTheme) → `presentation/widgets/unit_card.gd`(9：UnitCard)
- `presentation/battle/colonial_overlay.gd`：→ `presentation/theme/ui_theme.gd`(51：UiTheme) → `session/game_session.gd`(1：GameSession)
- `presentation/battle/deck_sidebar.gd`：→ `core/util/js_compat.gd`(2：JsCompat) → `presentation/theme/ui_theme.gd`(29：UiTheme) → `presentation/widgets/hover_tooltip.gd`(2：HoverTooltip)
- `presentation/battle/drag_aim.gd`：→ `core/battle/fm.gd`(1：Fm) → `presentation/widgets/unit_card.gd`(15：UnitCard)
- `presentation/battle/hand_card_item.gd`：→ `core/data/db.gd`(1：Db) → `core/util/js_compat.gd`(8：JsCompat) → `presentation/theme/ui_theme.gd`(43：UiTheme) → `presentation/widgets/hover_tooltip.gd`(2：HoverTooltip)
- `presentation/battle/hand_panel.gd`：→ `core/battle/fm.gd`(1：Fm) → `core/util/js_compat.gd`(2：JsCompat) → `presentation/theme/ui_theme.gd`(48：UiTheme) → `presentation/widgets/unit_card.gd`(7：UnitCard)
- `presentation/battle/log_panel.gd`：→ `core/util/js_compat.gd`(2：JsCompat) → `presentation/theme/ui_theme.gd`(29：UiTheme)
- `presentation/battle/result_view.gd`：→ `core/run/roster_manager.gd`(1：RosterManager) → `core/util/js_compat.gd`(1：JsCompat) → `presentation/theme/ui_theme.gd`(61：UiTheme) → `session/game_session.gd`(2：GameSession)
- `presentation/boot/boot.gd`：→ `core/data/db.gd`(1：Db) → `core/util/rng.gd`(1：Mulberry32) → `core/version.gd`(2：GameVersion) → `presentation/battle/battle_view.gd`(1：BattleView) → `presentation/battle/result_view.gd`(1：ResultView)
  → `presentation/menus/menu_view.gd`(1：MenuView) → `presentation/run_map/formation_view.gd`(1：FormationView) → `presentation/run_map/map_view.gd`(3：MapView) → `presentation/theme/ui_theme.gd`(3：UiTheme)
  → `presentation/widgets/hover_tooltip.gd`(3：HoverTooltip) → `presentation/widgets/modal_layer.gd`(2：ModalLayer) → `presentation/widgets/top_bar.gd`(2：TopBar) → `session/data_loader.gd`(1：DataLoader) → `session/game_session.gd`(2：GameSession)
- `presentation/menus/event_view.gd`：→ `core/run/node_resolver.gd`(1：NodeResolver) → `core/run/run_state.gd`(3：RunState) → `presentation/theme/ui_theme.gd`(57：UiTheme) → `session/game_session.gd`(2：GameSession)
- `presentation/menus/menu_view.gd`：→ `core/run/roster_manager.gd`(1：RosterManager) → `core/version.gd`(3：GameVersion) → `presentation/theme/ui_theme.gd`(44：UiTheme) → `session/game_session.gd`(6：GameSession)
- `presentation/menus/pick_card_view.gd`：→ `core/run/deck_builder.gd`(1：DeckBuilder) → `core/run/run_state.gd`(2：RunState) → `presentation/theme/ui_theme.gd`(56：UiTheme) → `presentation/widgets/hover_tooltip.gd`(3：HoverTooltip)
  → `session/game_session.gd`(2：GameSession)
- `presentation/menus/rest_view.gd`：→ `core/data/db.gd`(1：Db) → `core/run/run_state.gd`(1：RunState) → `presentation/theme/ui_theme.gd`(50：UiTheme) → `session/game_session.gd`(2：GameSession)
- `presentation/menus/roster_view.gd`：→ `core/run/roster_manager.gd`(8：RosterManager) → `core/run/run_state.gd`(5：RunState) → `core/util/js_compat.gd`(1：JsCompat) → `presentation/theme/ui_theme.gd`(102：UiTheme)
  → `presentation/widgets/hover_tooltip.gd`(4：HoverTooltip) → `session/game_session.gd`(2：GameSession)
- `presentation/menus/shop_view.gd`：→ `core/data/db.gd`(1：Db) → `core/run/node_resolver.gd`(4：NodeResolver) → `core/run/part_system.gd`(5：PartSystem) → `core/run/relic_system.gd`(4：RelicSystem) → `core/run/run_state.gd`(4：RunState)
  → `presentation/theme/ui_theme.gd`(78：UiTheme) → `session/game_session.gd`(2：GameSession)
- `presentation/run_map/formation_view.gd`：→ `core/battle/fm.gd`(5：Fm) → `core/run/roster_manager.gd`(3：RosterManager) → `core/run/run_state.gd`(4：RunState) → `core/util/js_compat.gd`(2：JsCompat) → `presentation/theme/ui_theme.gd`(78：UiTheme)
  → `presentation/widgets/hover_tooltip.gd`(2：HoverTooltip) → `session/game_session.gd`(2：GameSession)
- `presentation/run_map/map_view.gd`：→ `core/run/map_generator.gd`(3：MapGenerator) → `core/run/map_navigator.gd`(11：MapNavigator) → `core/run/roster_manager.gd`(1：RosterManager) → `core/run/run_state.gd`(11：RunState)
  → `presentation/theme/ui_theme.gd`(152：UiTheme) → `session/game_session.gd`(2：GameSession)
- `presentation/theme/ui_theme.gd`：→ `core/data/db.gd`(2：Db)
- `presentation/widgets/hover_tooltip.gd`：→ `presentation/theme/ui_theme.gd`(11：UiTheme)
- `presentation/widgets/modal_layer.gd`：→ `core/run/deck_builder.gd`(1：DeckBuilder) → `core/run/roster_manager.gd`(2：RosterManager) → `presentation/battle/result_view.gd`(1：ResultView) → `presentation/menus/event_view.gd`(1：EventView)
  → `presentation/menus/pick_card_view.gd`(1：PickCardView) → `presentation/menus/rest_view.gd`(1：RestView) → `presentation/menus/roster_view.gd`(1：RosterView) → `presentation/menus/shop_view.gd`(1：ShopView)
  → `presentation/theme/ui_theme.gd`(36：UiTheme) → `presentation/widgets/hover_tooltip.gd`(1：HoverTooltip) → `session/game_session.gd`(2：GameSession)
- `presentation/widgets/top_bar.gd`：→ `core/run/part_system.gd`(3：PartSystem) → `core/run/relic_system.gd`(2：RelicSystem) → `presentation/theme/ui_theme.gd`(108：UiTheme) → `presentation/widgets/hover_tooltip.gd`(3：HoverTooltip)
  → `session/game_session.gd`(3：GameSession)
- `presentation/widgets/unit_card.gd`：→ `core/util/js_compat.gd`(6：JsCompat) → `presentation/theme/ui_theme.gd`(122：UiTheme) → `presentation/widgets/hover_tooltip.gd`(2：HoverTooltip) → `session/game_session.gd`(1：GameSession)

### §3.4 全局热点函数（被别的文件直接调用最多，top 25）

| # | 符号 | 所在文件:行 | 外部调用 | 本文件内自调 |
|---|---|---|---|---|
| 1 | `J.truthy` | `core/util/js.gd:9` | 1023 | 0 |
| 2 | `J.num0` | `core/util/js.gd:54` | 816 | 0 |
| 3 | `J.or_` | `core/util/js.gd:24` | 792 | 0 |
| 4 | `J.s` | `core/util/js.gd:69` | 586 | 0 |
| 5 | `Btl.pushLog` | `core/battle/btl.gd:11` | 208 | 0 |
| 6 | `J.merged` | `core/util/js.gd:247` | 199 | 0 |
| 7 | `J.round` | `core/util/js.gd:116` | 198 | 0 |
| 8 | `UiTheme.文本` | `presentation/theme/ui_theme.gd:305` | 190 | 0 |
| 9 | `Units.livingOf` | `core/battle/units.gd:17` | 163 | 0 |
| 10 | `J.g` | `core/util/js.gd:255` | 160 | 0 |
| 11 | `Btl.战意` | `core/battle/btl.gd:39` | 143 | 0 |
| 12 | `Btl.谁` | `core/battle/btl.gd:15` | 138 | 0 |
| 13 | `J.inc` | `core/util/js.gd:127` | 109 | 0 |
| 14 | `Btl.换同源增益` | `core/battle/btl.gd:87` | 92 | 0 |
| 15 | `J.num` | `core/util/js.gd:36` | 91 | 0 |
| 16 | `UiTheme.建标签` | `presentation/theme/ui_theme.gd:190` | 90 | 0 |
| 17 | `Btl.打出精神或公有牌` | `core/battle/btl.gd:201` | 88 | 0 |
| 18 | `Btl.找单位` | `core/battle/btl.gd:157` | 86 | 0 |
| 19 | `UiTheme.建盒` | `presentation/theme/ui_theme.gd:182` | 83 | 0 |
| 20 | `Calc.resolveAttack` | `core/battle/calc.gd:602` | 80 | 0 |
| 21 | `J.same` | `core/util/js.gd:154` | 71 | 0 |
| 22 | `Fm.rowOfSlot` | `core/battle/fm.gd:28` | 70 | 0 |
| 23 | `DataLoader.install` | `session/data_loader.gd:41` | 67 | 0 |
| 24 | `Btl.加战意` | `core/battle/btl.gd:49` | 61 | 0 |
| 25 | `Setup.开局` | `core/battle/setup.gd:470` | 60 | 0 |

### §3.5 双向依赖对（A ⇄ B，成对出现的模块耦合）

> 共 **60** 对。双向依赖不是违规（内核里 setup ⇄ deck_flow 这类「互调」是本项目的既有形态），但**改一侧就要看另一侧**。

| # | A | B |
|---|---|---|
| 1 | `core/battle/ai.gd` | `core/battle/boss.gd` |
| 2 | `core/battle/ai.gd` | `core/battle/calc.gd` |
| 3 | `core/battle/atx_chips.gd` | `core/battle/calc.gd` |
| 4 | `core/battle/atx_chips.gd` | `core/battle/setup.gd` |
| 5 | `core/battle/atx_duo.gd` | `core/battle/guard.gd` |
| 6 | `core/battle/atx_duo.gd` | `core/battle/setup.gd` |
| 7 | `core/battle/atx_faction.gd` | `core/battle/fac_atx.gd` |
| 8 | `core/battle/atx_faction.gd` | `core/battle/setup.gd` |
| 9 | `core/battle/atx_godsbet.gd` | `core/battle/fac_atx.gd` |
| 10 | `core/battle/atx_smoke.gd` | `core/battle/setup.gd` |
| 11 | `core/battle/atx_three.gd` | `core/battle/card_effects.gd` |
| 12 | `core/battle/atx_three.gd` | `core/battle/fac_atx.gd` |
| 13 | `core/battle/atx_three.gd` | `core/battle/setup.gd` |
| 14 | `core/battle/boss.gd` | `core/battle/flow.gd` |
| 15 | `core/battle/btl.gd` | `core/battle/card_exec.gd` |
| 16 | `core/battle/btl.gd` | `core/battle/card_pool.gd` |

> （只列前 16 对，全部 60 对见 JSON 的 `audit.mutualPairs`。）

---

## §4.0 规则 ⑤ 逐模块明细：通用内核 → 势力文件

> 口径与索引页 §4.0 同源（同一次扫描）：共 **17** 个通用模块 / **117** 次 / 棘轮基线 **120**。

| 通用模块 | 引用的势力文件数 | 引用次数 | 明细（`→ 势力文件(n)`） |
|---|---|---|---|
| `core/battle/card_exec.gd` | 10 | 23 | `atx_faction.gd`(5) `celestial_v01.gd`(5) `atx_chips.gd`(3) `atx_godsbet.gd`(2) `atx_three.gd`(2) `fac_atx.gd`(2) `atx_duo.gd`(1) `atx_luck.gd`(1) `atx_rewrite.gd`(1) `atx_smoke.gd`(1) |
| `core/battle/weapon_exec.gd` | 7 | 18 | `celestial_v01.gd`(6) `atx_faction.gd`(3) `atx_smoke.gd`(2) `atx_three.gd`(2) `fac_mith.gd`(2) `mithril_v03_cards.gd`(2) `atx_rewrite.gd`(1) |
| `core/battle/deck_flow.gd` | 2 | 14 | `mithril_v03_cards.gd`(10) `fac_mith.gd`(4) |
| `core/battle/calc.gd` | 6 | 13 | `atx_godsbet.gd`(8) `atx_chips.gd`(1) `atx_rewrite.gd`(1) `atx_smoke.gd`(1) `celestial_v01.gd`(1) `fac_mith.gd`(1) |
| `core/battle/setup.gd` | 9 | 12 | `celestial_v01.gd`(3) `atx_three.gd`(2) `atx_chips.gd`(1) `atx_duo.gd`(1) `atx_faction.gd`(1) `atx_godsbet.gd`(1) `atx_smoke.gd`(1) `fac_atx.gd`(1) `mithril_v03_cards.gd`(1) |
| `core/run/deck_builder.gd` | 4 | 11 | `mithril_v03_cards.gd`(4) `celestial_v01.gd`(3) `fac_atx.gd`(3) `atx_three.gd`(1) |
| `core/battle/card_effects.gd` | 5 | 6 | `celestial_v01.gd`(2) `atx_duo.gd`(1) `atx_three.gd`(1) `fac_atx.gd`(1) `mithril_v03_cards.gd`(1) |
| `core/battle/flow.gd` | 2 | 6 | `celestial_v01.gd`(5) `atx_duo.gd`(1) |
| `core/battle/ai.gd` | 2 | 3 | `atx_duo.gd`(2) `atx_faction.gd`(1) |
| `core/battle/guard.gd` | 2 | 2 | `atx_duo.gd`(1) `celestial_v01.gd`(1) |
| `core/battle/phase_flow.gd` | 2 | 2 | `atx_faction.gd`(1) `celestial_v01.gd`(1) |
| `core/run/roster_manager.gd` | 1 | 2 | `atx_duo.gd`(2) |
| `core/battle/boss.gd` | 1 | 1 | `atx_duo.gd`(1) |
| `core/battle/data_fn.gd` | 1 | 1 | `atx_duo.gd`(1) |
| `core/battle/faction_identity.gd` | 1 | 1 | `fac_atx.gd`(1) |
| `core/battle/params.gd` | 1 | 1 | `fac_mith.gd`(1) |
| `core/battle/reach.gd` | 1 | 1 | `fac_mith.gd`(1) |
| **合计** | — | **117** | 棘轮基线 **120**（只许下调） |

## §4.1 审计证据：表现层对 `core/**` 的**读接口**调用全清单

> 索引页 §4.1 是这张表的**聚合版**；这里逐条列出（调用方 × 目标模块 × 符号 × n），共 **76** 处。全部**不算违规**（只读、纯计算、无副作用）。

| 调用方（presentation） | 目标模块 | 只读符号 | n |
|---|---|---|---|
| `presentation/battle/board_panel.gd` | `core/battle/ai.gd` | `Ai.isUltimate` | 2 |
| `presentation/battle/board_panel.gd` | `core/battle/boss.gd` | `Boss.Boss参数` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/boss.gd` | `Boss.bossAction` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/boss.gd` | `Boss.大技能预告回合` | 1 |
| `presentation/menus/pick_card_view.gd` | `core/run/deck_builder.gd` | `DeckBuilder.找到` | 1 |
| `presentation/widgets/modal_layer.gd` | `core/run/deck_builder.gd` | `DeckBuilder.找到` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/enemy_mech.gd` | `EnemyMech.机制提示` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.ROWS` | 1 |
| `presentation/run_map/formation_view.gd` | `core/battle/fm.gd` | `Fm.ROWS` | 1 |
| `presentation/battle/battle_fx_player.gd` | `core/battle/fm.gd` | `Fm.SLOTS` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.SLOTS` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.slotOf` | 4 |
| `presentation/run_map/formation_view.gd` | `core/battle/fm.gd` | `Fm.slotOf` | 1 |
| `presentation/battle/battle_fx_player.gd` | `core/battle/fm.gd` | `Fm.位名` | 1 |
| `presentation/battle/battle_view.gd` | `core/battle/fm.gd` | `Fm.位名` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.位名` | 3 |
| `presentation/battle/drag_aim.gd` | `core/battle/fm.gd` | `Fm.位名` | 1 |
| `presentation/battle/hand_panel.gd` | `core/battle/fm.gd` | `Fm.位名` | 1 |
| `presentation/run_map/formation_view.gd` | `core/battle/fm.gd` | `Fm.位名` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.行列数` | 1 |
| `presentation/run_map/formation_view.gd` | `core/battle/fm.gd` | `Fm.行列数` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/fm.gd` | `Fm.行名` | 1 |
| `presentation/run_map/formation_view.gd` | `core/battle/fm.gd` | `Fm.行名` | 1 |
| `presentation/menus/menu_view.gd` | `core/version.gd` | `GameVersion.构建串` | 1 |
| `presentation/battle/board_panel.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 2 |
| `presentation/battle/deck_sidebar.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 2 |
| `presentation/battle/hand_card_item.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 8 |
| `presentation/battle/hand_panel.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 2 |
| `presentation/battle/log_panel.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 2 |
| `presentation/battle/result_view.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 1 |
| `presentation/menus/roster_view.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 1 |
| `presentation/run_map/formation_view.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 2 |
| `presentation/widgets/unit_card.gd` | `core/util/js_compat.gd` | `JsCompat.js_round` | 6 |
| `presentation/run_map/map_view.gd` | `core/run/map_generator.gd` | `MapGenerator.cell_id` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_generator.gd` | `MapGenerator.exit_kinds` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_generator.gd` | `MapGenerator.shape` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.current_exit_kind` | 2 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.exit_chase_pending` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.exit_requires_guard` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.is_guard_cleared` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.is_known` | 3 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.reachable_cells` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.retreat_cost_preview` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/map_navigator.gd` | `MapNavigator.tunnel_other_end` | 1 |
| `presentation/boot/boot.gd` | `core/util/rng.gd` | `Mulberry32.new` | 1 |
| `presentation/menus/event_view.gd` | `core/run/node_resolver.gd` | `NodeResolver.当前事件` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/node_resolver.gd` | `NodeResolver.黑市价` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/node_resolver.gd` | `NodeResolver.黑市刷新价` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/node_resolver.gd` | `NodeResolver.黑市刷新次数` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/node_resolver.gd` | `NodeResolver.黑市货` | 1 |
| `presentation/battle/board_panel.gd` | `core/battle/params.gd` | `Params.战意上限` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/part_system.gd` | `PartSystem.part_info` | 1 |
| `presentation/widgets/top_bar.gd` | `core/run/part_system.gd` | `PartSystem.part_info` | 2 |
| `presentation/menus/shop_view.gd` | `core/run/part_system.gd` | `PartSystem.part_key` | 1 |
| `presentation/widgets/top_bar.gd` | `core/run/part_system.gd` | `PartSystem.part_key` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/part_system.gd` | `PartSystem.sell_price` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/relic_system.gd` | `RelicSystem.件` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/relic_system.gd` | `RelicSystem.名` | 2 |
| `presentation/widgets/top_bar.gd` | `core/run/relic_system.gd` | `RelicSystem.名` | 1 |
| `presentation/menus/shop_view.gd` | `core/run/relic_system.gd` | `RelicSystem.说明` | 1 |
| `presentation/widgets/top_bar.gd` | `core/run/relic_system.gd` | `RelicSystem.说明` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.deploy_limit` | 1 |
| `presentation/run_map/formation_view.gd` | `core/run/roster_manager.gd` | `RosterManager.deploy_limit` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.券合机师们` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.券名` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.券文字` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.券留存上限` | 1 |
| `presentation/run_map/map_view.gd` | `core/run/roster_manager.gd` | `RosterManager.券留存上限` | 1 |
| `presentation/widgets/modal_layer.gd` | `core/run/roster_manager.gd` | `RosterManager.券留存上限` | 2 |
| `presentation/menus/menu_view.gd` | `core/run/roster_manager.gd` | `RosterManager.势力们` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.标签` | 1 |
| `presentation/run_map/formation_view.gd` | `core/run/roster_manager.gd` | `RosterManager.标签` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.档名` | 1 |
| `presentation/battle/result_view.gd` | `core/run/roster_manager.gd` | `RosterManager.模板` | 1 |
| `presentation/menus/roster_view.gd` | `core/run/roster_manager.gd` | `RosterManager.模板` | 1 |
| `presentation/run_map/formation_view.gd` | `core/run/roster_manager.gd` | `RosterManager.模板` | 1 |

### §4.4 势力 → 势力横向引用（全表，不计入规则 ⑤）

> 共 **50** 条边 / **475** 次引用。规则 ⑤ 只数「通用内核 → 势力文件」，势力之间的横向引用单列在这里 —— 它们同样是耦合，只是拆解顺序排在规则 ⑤ 之后。

| from | to | 谱系 | n | 符号 |
|---|---|---|---|---|
| `core/battle/atx_duo.gd` | `core/battle/celestial_v01.gd` | ATX → 天人 | 2 | CelestialV01 |
| `core/battle/atx_faction.gd` | `core/battle/atx_chips.gd` | ATX → ATX | 3 | AtxChips |
| `core/battle/atx_faction.gd` | `core/battle/fac_atx.gd` | ATX → ATX | 31 | FacAtx |
| `core/battle/atx_faction.gd` | `core/battle/mithril_v03_cards.gd` | ATX → 秘银 | 1 | MithrilV03Cards |
| `core/battle/atx_godsbet.gd` | `core/battle/fac_atx.gd` | ATX → ATX | 1 | FacAtx |
| `core/battle/atx_three.gd` | `core/battle/atx_chips.gd` | ATX → ATX | 2 | AtxChips |
| `core/battle/atx_three.gd` | `core/battle/atx_faction.gd` | ATX → ATX | 5 | AtxFaction |
| `core/battle/atx_three.gd` | `core/battle/atx_godsbet.gd` | ATX → ATX | 2 | AtxGodsbet |
| `core/battle/atx_three.gd` | `core/battle/atx_luck.gd` | ATX → ATX | 2 | AtxLuck |
| `core/battle/atx_three.gd` | `core/battle/atx_rewrite.gd` | ATX → ATX | 1 | AtxRewrite |
| `core/battle/atx_three.gd` | `core/battle/atx_smoke.gd` | ATX → ATX | 3 | AtxSmoke |
| `core/battle/atx_three.gd` | `core/battle/fac_atx.gd` | ATX → ATX | 5 | FacAtx |
| `core/battle/atx_three.gd` | `core/battle/mithril_v03_cards.gd` | ATX → 秘银 | 1 | MithrilV03Cards |
| `core/battle/colonial_awaken.gd` | `core/battle/colonial_deck.gd` | 其他 → 其他 | 1 | ColonialDeck |
| `core/battle/colonial_awaken.gd` | `core/battle/colonial_units.gd` | 其他 → 其他 | 1 | ColonialUnits |
| `core/battle/colonial_deck.gd` | `core/battle/atx_luck.gd` | 其他 → ATX | 1 | AtxLuck |
| `core/battle/colonial_deck.gd` | `core/battle/colonial_awaken.gd` | 其他 → 其他 | 13 | ColonialAwaken |
| `core/battle/colonial_deck.gd` | `core/battle/colonial_units.gd` | 其他 → 其他 | 1 | ColonialUnits |
| `core/battle/colonial_deck.gd` | `core/battle/colonial_v01.gd` | 其他 → 其他 | 1 | ColonialV01 |
| `core/battle/colonial_units.gd` | `core/battle/colonial_awaken.gd` | 其他 → 其他 | 18 | ColonialAwaken |
| `core/battle/colonial_units.gd` | `core/battle/colonial_deck.gd` | 其他 → 其他 | 2 | ColonialDeck |
| `core/battle/colonial_v01.gd` | `core/battle/colonial_awaken.gd` | 其他 → 其他 | 38 | ColonialAwaken |
| `core/battle/colonial_v01.gd` | `core/battle/colonial_deck.gd` | 其他 → 其他 | 10 | ColonialDeck |
| `core/battle/colonial_v01.gd` | `core/battle/colonial_units.gd` | 其他 → 其他 | 19 | ColonialUnits |
| `core/battle/fac_atx.gd` | `core/battle/atx_chips.gd` | ATX → ATX | 1 | AtxChips |
| `core/battle/fac_atx.gd` | `core/battle/atx_duo.gd` | ATX → ATX | 3 | AtxDuo |
| `core/battle/fac_atx.gd` | `core/battle/atx_faction.gd` | ATX → ATX | 5 | AtxFaction |
| `core/battle/fac_atx.gd` | `core/battle/atx_godsbet.gd` | ATX → ATX | 3 | AtxGodsbet |
| `core/battle/fac_atx.gd` | `core/battle/atx_luck.gd` | ATX → ATX | 1 | AtxLuck |
| `core/battle/fac_atx.gd` | `core/battle/atx_three.gd` | ATX → ATX | 2 | AtxThree |
| `core/battle/fac_moon.gd` | `core/battle/moon_v02.gd` | 月球 → 其他 | 1 | MoonV02 |
| `core/battle/mithril_v03_cards.gd` | `core/battle/fac_mith.gd` | 秘银 → 秘银 | 6 | FacMith |
| `core/battle/moon_deck.gd` | `core/battle/moon_faction.gd` | 其他 → 其他 | 1 | MoonFaction |
| `core/battle/moon_deck.gd` | `core/battle/moon_phase.gd` | 其他 → 其他 | 19 | MoonPhase |
| `core/battle/moon_faction.gd` | `core/battle/moon_deck.gd` | 其他 → 其他 | 12 | MoonDeck |
| `core/battle/moon_faction.gd` | `core/battle/moon_phase.gd` | 其他 → 其他 | 17 | MoonPhase |
| `core/battle/moon_units.gd` | `core/battle/moon_deck.gd` | 其他 → 其他 | 15 | MoonDeck |
| `core/battle/moon_units.gd` | `core/battle/moon_phase.gd` | 其他 → 其他 | 43 | MoonPhase |
| `core/battle/moon_v02.gd` | `core/battle/moon_deck.gd` | 其他 → 其他 | 7 | MoonDeck |
| `core/battle/moon_v02.gd` | `core/battle/moon_phase.gd` | 其他 → 其他 | 17 | MoonPhase |
| `core/battle/moon_v02.gd` | `core/battle/moon_units.gd` | 其他 → 其他 | 15 | MoonUnits |
| `core/battle/shadow_deck.gd` | `core/battle/shadow_v02.gd` | 其他 → 其他 | 56 | ShadowV02 |
| `core/battle/shadow_ults.gd` | `core/battle/shadow_deck.gd` | 其他 → 其他 | 8 | ShadowDeck |
| `core/battle/shadow_ults.gd` | `core/battle/shadow_units.gd` | 其他 → 其他 | 1 | ShadowUnits |
| `core/battle/shadow_ults.gd` | `core/battle/shadow_v02.gd` | 其他 → 其他 | 19 | ShadowV02 |
| `core/battle/shadow_units.gd` | `core/battle/shadow_deck.gd` | 其他 → 其他 | 6 | ShadowDeck |
| `core/battle/shadow_units.gd` | `core/battle/shadow_v02.gd` | 其他 → 其他 | 28 | ShadowV02 |
| `core/battle/shadow_v02.gd` | `core/battle/shadow_deck.gd` | 其他 → 其他 | 8 | ShadowDeck |
| `core/battle/shadow_v02.gd` | `core/battle/shadow_ults.gd` | 其他 → 其他 | 1 | ShadowUlts |
| `core/battle/shadow_v02.gd` | `core/battle/shadow_units.gd` | 其他 → 其他 | 16 | ShadowUnits |

### §4.5 规则 ⑥ 豁免文件明细（索引页 §4.0c 的全表）

> 审计口径见索引页 §4.0c。势力 / 职业模块共 **28** 个（`AtxChips` · `AtxDuo` · `AtxFaction` · `AtxGodsbet` · `AtxLuck` · `AtxRewrite` · `AtxSmoke` · `AtxThree` · `CelestialV01` · `ClassCards` · `ColonialAwaken` · `ColonialDeck` · `ColonialUnits` · `ColonialV01` · `FacAtx` · `FacCb` · `FacMith` · `FacMoon` · `MithrilV03Cards` · `MoonDeck` · `MoonFaction` · `MoonPhase` · `MoonUnits` · `MoonV02` · `ShadowDeck` · `ShadowUlts` · `ShadowUnits` · `ShadowV02`），被测文件 2 个。

| 注册表文件 | 允许区域 | 允许行数 | 区内引用行 | 区外引用行 |
|---|---|---|---|---|
| `core/battle/rule_hooks.gd` | `const` / `static var` 的 `{…}` `[…]` 声明块（= `顺序` 派发顺序表与按处理者映射表） | 55 | 47 | 0 |
| `core/battle/fac.gd` | `const ORDER` 声明块 + `match 势力:` 块 + 条件里出现 `势力 ==` / `势力 in` 的 `if` / `elif` 块 | 31 | 17 | 0 |

- `core/battle/rule_hooks.gd` 允许区域里点名的模块：`AtxChips` · `AtxDuo` · `AtxFaction` · `AtxGodsbet` · `AtxLuck` · `AtxSmoke` · `AtxThree` · `CelestialV01` · `ClassCards` · `ColonialV01` · `FacAtx` · `MithrilV03Cards` · `MoonV02` · `ShadowV02`

- `core/battle/fac.gd` 允许区域里点名的模块：`FacCb` · `FacMith` · `FacMoon`

### §4.5b 规则 ⑦ 体积棘轮登记表（全表，索引页 §4.5 只放摘要）

> **上限 = 建表时（CR-3 Batch E）的实测 `estTokens`，只许下调**。阈值：> **1000** 行 或 > **12000** token。当前超限 **0** 个 · 未登记的新大文件警告 **0** 个。

| 文件 | 登记上限 token | 当前 token | 余量 | 行 | 状态 |
|---|---|---|---|---|---|
| `tests/unit/test_session_flow.gd` | 33587 | 32341 | 1246 | 1898 | ✓ |
| `core/battle/celestial_v01.gd` | 32680 | 31713 | 967 | 2180 | ✓ |
| `tests/unit/test_celestial_v01.gd` | 30588 | 29697 | 891 | 1650 | ✓ |
| `core/battle/atx_three.gd` | 21396 | 20580 | 816 | 1581 | ✓ |
| `tests/unit/test_atx_three_v01.gd` | 19307 | 18744 | 563 | 1054 | ✓ |
| `core/battle/calc.gd` | 18553 | 17614 | 939 | 1200 | ✓ |
| `tests/unit/test_unit_deck_system.gd` | 17483 | 17098 | 385 | 923 | ✓ |
| `tests/unit/test_run_map.gd` | 17038 | 16541 | 497 | 1035 | ✓ |
| `tests/unit/test_mithril_v03.gd` | 17021 | 16518 | 503 | 885 | ✓ |
| `core/battle/mithril_v03_cards.gd` | 15910 | 15481 | 429 | 1069 | ✓ |
| `session/game_session.gd` | 14782 | 14768 | 14 | 1320 | ✓ |
| `core/run/node_resolver.gd` | 14253 | 14247 | 6 | 964 | ✓ |
| `tests/unit/test_presentation_smoke.gd` | 14608 | 14175 | 433 | 876 | ✓ |
| `core/battle/deck_flow.gd` | 13416 | 13416 | 0 | 997 | ✓ |
| `tests/unit/test_class_cards.gd` | 13702 | 13281 | 421 | 722 | ✓ |
| `tests/unit/test_class_heavy_cmd.gd` | 12896 | 12521 | 375 | 712 | ✓ |
| `tests/unit/test_cr2_pipelines.gd` | 12334 | 11974 | 360 | 783 | ✓ |
| `core/battle/atx_faction.gd` | 10386 | 9944 | 442 | 752 | ✓ |
| `core/battle/atx_duo.gd` | 10431 | 9902 | 529 | 652 | ✓ |
| `presentation/widgets/unit_card.gd` | 8702 | 8012 | 690 | 758 | ✓ |
| `core/battle/fac_atx.gd` | 7620 | 7355 | 265 | 606 | ✓ |
| **合计** | **356693** | — | — | — | ✓ 全部不超限 |

- 未登记且超限的新 `.gd`：**0 个** ✓

### §4.6b 规则 ⑧ 注释占比棘轮登记表（全表，索引页 §4.6 只放摘要）

> **登记 = 路径清单（`COMMENT_RATCHET`，不记数值）**，判据是**本层阈值**：生产代码（`core/` `session/` `presentation/`）> **15.0%**、测试（`tests/**`）> **20.0%**。登记文件里超阈值 **0** 个 · 未登记且超阈值 **78** 个。
> **「余量」列** = 本层阈值换算成的字节数减去当前注释字节（负数 = 已经超了），用来看「还能不能往里写注释」。

| 文件 | 层 | 本层阈值 | 当前占比 | 余量（字节） | 行 | 状态 |
|---|---|---|---|---|---|---|
| `tests/unit/test_atx_godsbet_and_luck.gd` | tests | 20.0% | 19.9% | 34 | 610 | ✓ |
| `tests/unit/test_atx_smoke.gd` | tests | 20.0% | 19.9% | 39 | 598 | ✓ |
| `tests/unit/test_data.gd` | tests | 20.0% | 19.8% | 3 | 38 | ✓ |
| `tests/unit/test_class_heavy_cmd.gd` | tests | 20.0% | 19.8% | 70 | 712 | ✓ |
| `tests/unit/test_rng.gd` | tests | 20.0% | 19.7% | 3 | 26 | ✓ |
| `tests/unit/test_class_cards.gd` | tests | 20.0% | 19.1% | 385 | 722 | ✓ |
| `tests/unit/test_presentation_smoke.gd` | tests | 20.0% | 19.0% | 451 | 876 | ✓ |
| `tests/unit/test_cr2_pipelines.gd` | tests | 20.0% | 18.5% | 582 | 783 | ✓ |
| `tests/unit/test_layout_tooltip.gd` | tests | 20.0% | 18.2% | 296 | 327 | ✓ |
| `tests/unit/test_atx_three_v01.gd` | tests | 20.0% | 18.2% | 1132 | 1054 | ✓ |
| `tests/unit/test_sub_deck.gd` | tests | 20.0% | 18.0% | 115 | 110 | ✓ |
| `tests/unit/test_boundary.gd` | tests | 20.0% | 17.9% | 225 | 212 | ✓ |
| `tests/unit/test_atx_v03_wiring.gd` | tests | 20.0% | 17.7% | 871 | 675 | ✓ |
| `tests/unit/test_font_coverage.gd` | tests | 20.0% | 17.4% | 51 | 47 | ✓ |
| `tests/unit/test_ux4_lineup_slots.gd` | tests | 20.0% | 17.3% | 356 | 249 | ✓ |
| `tests/unit/test_atx_faction_v03.gd` | tests | 20.0% | 17.3% | 1034 | 653 | ✓ |
| `tests/unit/test_layout_log.gd` | tests | 20.0% | 16.9% | 958 | 463 | ✓ |
| `tests/unit/test_session_flow.gd` | tests | 20.0% | 16.7% | 3543 | 1898 | ✓ |
| `tests/unit/test_run_core.gd` | tests | 20.0% | 16.5% | 1044 | 553 | ✓ |
| `tests/unit/test_presentation_layout.gd` | tests | 20.0% | 15.0% | 38 | 20 | ✓ |
| `core/battle/guard.gd` | core | 15.0% | 15.0% | 3 | 377 | ✓ |
| `core/battle/calc.gd` | core | 15.0% | 14.9% | 31 | 1200 | ✓ |
| `core/battle/weapon_exec.gd` | core | 15.0% | 14.9% | 11 | 383 | ✓ |
| `core/battle/fac.gd` | core | 15.0% | 14.9% | 8 | 173 | ✓ |
| `core/battle/phase_flow.gd` | core | 15.0% | 14.7% | 17 | 152 | ✓ |
| `core/battle/battle_log.gd` | core | 15.0% | 14.6% | 17 | 132 | ✓ |
| `tests/unit/test_unit_deck_system.gd` | tests | 20.0% | 14.5% | 3088 | 923 | ✓ |
| `session/battle_flow.gd` | session | 15.0% | 14.3% | 161 | 491 | ✓ |
| `tests/unit/layout_fixtures.gd` | tests | 20.0% | 14.3% | 583 | 297 | ✓ |
| `session/display_helpers.gd` | session | 15.0% | 14.2% | 136 | 378 | ✓ |
| `tests/unit/test_layout_flow.gd` | tests | 20.0% | 14.0% | 1591 | 496 | ✓ |
| `session/live_monitor.gd` | session | 15.0% | 13.9% | 61 | 146 | ✓ |
| `session/data_loader.gd` | session | 15.0% | 13.9% | 80 | 186 | ✓ |
| `core/battle/boss.gd` | core | 15.0% | 13.9% | 145 | 251 | ✓ |
| `presentation/battle/hand_panel.gd` | presentation | 15.0% | 13.7% | 209 | 326 | ✓ |
| `tests/unit/test_layout_screens.gd` | tests | 20.0% | 13.7% | 1434 | 444 | ✓ |
| `presentation/battle/battle_view.gd` | presentation | 15.0% | 13.7% | 470 | 620 | ✓ |
| `core/battle/morale.gd` | core | 15.0% | 13.4% | 36 | 67 | ✓ |
| `tests/unit/test_layout_hand.gd` | tests | 20.0% | 13.2% | 2009 | 503 | ✓ |
| `tests/unit/test_mithril_v03.gd` | tests | 20.0% | 13.1% | 3801 | 885 | ✓ |
| `tests/unit/test_layout_board.gd` | tests | 20.0% | 13.0% | 1941 | 497 | ✓ |
| `core/battle/intent.gd` | core | 15.0% | 13.0% | 114 | 131 | ✓ |
| `tests/unit/test_layout_ux1.gd` | tests | 20.0% | 13.0% | 1601 | 471 | ✓ |
| `core/battle/card_exec.gd` | core | 15.0% | 12.7% | 501 | 398 | ✓ |
| `tests/unit/test_run_map.gd` | tests | 20.0% | 12.6% | 4061 | 1035 | ✓ |
| `presentation/battle/battle_fx_player.gd` | presentation | 15.0% | 12.4% | 715 | 679 | ✓ |
| `tests/unit/test_celestial_v01.gd` | tests | 20.0% | 12.4% | 7495 | 1650 | ✓ |
| `core/battle/mithril_v03_cards.gd` | core | 15.0% | 12.4% | 1349 | 1069 | ✓ |
| `core/battle/celestial_v01.gd` | core | 15.0% | 12.1% | 2994 | 2180 | ✓ |
| `session/battle_hand_view.gd` | session | 15.0% | 12.1% | 600 | 447 | ✓ |
| `core/battle/card_pool.gd` | core | 15.0% | 12.0% | 436 | 394 | ✓ |
| `core/battle/rule_hooks.gd` | core | 15.0% | 11.9% | 202 | 162 | ✓ |
| `tests/unit/test_layout_sidebar.gd` | tests | 20.0% | 11.8% | 1975 | 414 | ✓ |
| `presentation/battle/battle_animation_layer.gd` | presentation | 15.0% | 11.6% | 412 | 330 | ✓ |
| `core/battle/card_play.gd` | core | 15.0% | 11.6% | 417 | 298 | ✓ |
| `presentation/battle/hand_card_item.gd` | presentation | 15.0% | 11.4% | 478 | 280 | ✓ |
| `session/run_facade.gd` | session | 15.0% | 11.3% | 810 | 437 | ✓ |
| `session/game_session.gd` | session | 15.0% | 11.3% | 1823 | 1320 | ✓ |
| `presentation/battle/board_panel.gd` | presentation | 15.0% | 11.2% | 882 | 541 | ✓ |
| `presentation/battle/deck_sidebar.gd` | presentation | 15.0% | 11.1% | 626 | 324 | ✓ |
| `tests/unit/test_card_table_snapshot.gd` | tests | 20.0% | 10.4% | 808 | 171 | ✓ |
| `presentation/battle/log_panel.gd` | presentation | 15.0% | 10.1% | 657 | 263 | ✓ |
| `tests/unit/test_layout_drag.gd` | tests | 20.0% | 9.9% | 1451 | 208 | ✓ |
| `core/battle/fac_cb.gd` | core | 15.0% | 9.8% | 241 | 105 | ✓ |
| `session/battle_deck_view.gd` | session | 15.0% | 9.2% | 1700 | 548 | ✓ |
| `session/roster_facade.gd` | session | 15.0% | 8.1% | 1015 | 316 | ✓ |
| `presentation/battle/drag_aim.gd` | presentation | 15.0% | 6.7% | 1074 | 312 | ✓ |
| `core/battle/fac_moon.gd` | core | 15.0% | 6.4% | 1029 | 246 | ✓ |
| `core/battle/deck_flow.gd` | core | 15.0% | 5.4% | 4272 | 997 | ✓ |
| `presentation/widgets/unit_card.gd` | presentation | 15.0% | 5.1% | 2626 | 758 | ✓ |
| `session/tooltip_text.gd` | session | 15.0% | 5.0% | 1627 | 339 | ✓ |
| `tests/unit/test_js_compat.gd` | tests | 20.0% | 5.0% | 218 | 27 | ✓ |
| `core/battle/atx_faction.gd` | core | 15.0% | 4.6% | 3420 | 752 | ✓ |
| `core/battle/btl.gd` | core | 15.0% | 4.5% | 1548 | 240 | ✓ |
| `core/battle/fac_atx.gd` | core | 15.0% | 2.7% | 3005 | 606 | ✓ |
| `core/battle/diff.gd` | core | 15.0% | 2.7% | 458 | 78 | ✓ |
| `core/battle/traits.gd` | core | 15.0% | 2.4% | 866 | 179 | ✓ |
| `core/battle/atx_three.gd` | core | 15.0% | 1.9% | 9010 | 1581 | ✓ |
| `core/battle/fac_mith.gd` | core | 15.0% | 1.6% | 1673 | 248 | ✓ |
| **合计** | — | — | — | — | — | ✓ 全部在阈值以内 |

**未登记且超阈值（警告，要求先清注释）**：

| 文件 | 层 | 行 | 注释字节 | 注释占比 | 阈值 |
|---|---|---|---|---|---|
| `core/battle/sub_deck.gd` | core | 174 | 6504 | 65.8% | 15.0% |
| `core/data/db.gd` | core | 18 | 532 | 63.8% | 15.0% |
| `core/battle/atx_luck.gd` | core | 131 | 3724 | 53.6% | 15.0% |
| `core/version.gd` | core | 23 | 516 | 52.3% | 15.0% |
| `presentation/boot/boot.gd` | presentation | 389 | 9019 | 50.8% | 15.0% |
| `presentation/widgets/hover_tooltip.gd` | presentation | 296 | 7084 | 50.2% | 15.0% |
| `session/battle_options.gd` | session | 20 | 394 | 44.6% | 15.0% |
| `core/data/game_data.gd` | core | 39 | 624 | 44.3% | 15.0% |
| `core/battle/data_fn.gd` | core | 31 | 595 | 43.5% | 15.0% |
| `core/run/deck_builder.gd` | core | 369 | 7540 | 42.9% | 15.0% |
| `core/util/js_compat.gd` | core | 52 | 628 | 42.4% | 15.0% |
| `core/battle/atx_rewrite.gd` | core | 294 | 6745 | 41.5% | 15.0% |
| `core/battle/atx_godsbet.gd` | core | 359 | 7668 | 40.8% | 15.0% |
| `core/battle/atx_smoke.gd` | core | 373 | 7952 | 40.7% | 15.0% |
| `core/data/game_catalog.gd` | core | 153 | 2066 | 39.7% | 15.0% |
| `core/util/rng.gd` | core | 33 | 428 | 38.8% | 15.0% |
| `presentation/run_map/formation_view.gd` | presentation | 551 | 9746 | 37.7% | 15.0% |
| `presentation/run_map/map_view.gd` | presentation | 711 | 14416 | 37.5% | 15.0% |
| `core/run/part_system.gd` | core | 663 | 11064 | 37.3% | 15.0% |
| `core/battle/setup.gd` | core | 541 | 9782 | 35.9% | 15.0% |
| `core/battle/atx_chips.gd` | core | 568 | 10945 | 35.8% | 15.0% |
| `presentation/theme/ui_theme.gd` | presentation | 314 | 4556 | 35.7% | 15.0% |
| `core/battle/relic_battle.gd` | core | 183 | 3024 | 35.1% | 15.0% |
| `core/battle/ai_deck.gd` | core | 40 | 587 | 34.5% | 15.0% |
| `core/data/display_names.gd` | core | 22 | 353 | 34.3% | 15.0% |
| `tests/unit/test_armor_pool.gd` | tests | 187 | 3264 | 34.0% | 20.0% |
| `presentation/widgets/top_bar.gd` | presentation | 372 | 6840 | 33.8% | 15.0% |
| `core/battle/atx_duo.gd` | core | 652 | 10806 | 33.1% | 15.0% |
| `core/battle/flow.gd` | core | 424 | 8053 | 32.7% | 15.0% |
| `core/run/map_navigator.gd` | core | 439 | 6879 | 32.7% | 15.0% |
| `core/battle/fm.gd` | core | 222 | 2834 | 32.4% | 15.0% |
| `presentation/menus/rest_view.gd` | presentation | 143 | 2264 | 32.1% | 15.0% |
| `presentation/widgets/modal_layer.gd` | presentation | 268 | 3375 | 31.9% | 15.0% |
| `tests/unit/test_atx_nine_lives.gd` | tests | 334 | 5581 | 30.5% | 20.0% |
| `presentation/battle/result_view.gd` | presentation | 308 | 4962 | 30.3% | 15.0% |
| `tools/smoke_colonial_quick.gd` | 其他 | 50 | 633 | 29.3% | 15.0% |
| `tests/unit/test_ux5_ux6_feedback.gd` | tests | 359 | 6030 | 28.8% | 20.0% |
| `core/battle/card_effects.gd` | core | 591 | 7285 | 28.6% | 15.0% |
| `tests/unit/test_session_run.gd` | tests | 517 | 7589 | 28.3% | 20.0% |
| `presentation/menus/event_view.gd` | presentation | 178 | 2252 | 28.2% | 15.0% |
| `core/battle/class_cards.gd` | core | 605 | 8787 | 28.2% | 15.0% |
| `core/util/js.gd` | core | 303 | 2435 | 27.8% | 15.0% |
| `presentation/menus/menu_view.gd` | presentation | 241 | 3462 | 27.8% | 15.0% |
| `presentation/menus/pick_card_view.gd` | presentation | 137 | 1883 | 27.7% | 15.0% |
| `tests/golden_io.gd` | tests | 45 | 382 | 26.8% | 20.0% |
| `core/run/relic_system.gd` | core | 156 | 1756 | 26.4% | 15.0% |
| `core/battle/public_cooldown.gd` | core | 62 | 786 | 26.3% | 15.0% |
| `core/battle/swap.gd` | core | 309 | 4034 | 26.2% | 15.0% |
| `tests/unit/test_build_info.gd` | tests | 15 | 275 | 26.2% | 20.0% |
| `tests/unit/test_weapon_bar_lookup.gd` | tests | 47 | 709 | 26.1% | 20.0% |
| `tools/extract_native_inputs.gd` | 其他 | 96 | 1134 | 25.6% | 15.0% |
| `tests/golden_compare.gd` | tests | 68 | 798 | 25.3% | 20.0% |
| `core/run/map_generator.gd` | core | 679 | 7075 | 25.2% | 15.0% |
| `core/battle/reach.gd` | core | 316 | 3355 | 25.0% | 15.0% |
| `core/battle/repair_cards.gd` | core | 418 | 4786 | 24.2% | 15.0% |
| `session/save_service.gd` | session | 390 | 2487 | 24.0% | 15.0% |
| `tests/unit/test_cr1_review_fixes.gd` | tests | 181 | 2531 | 23.4% | 20.0% |
| `tests/run_tests.gd` | tests | 101 | 722 | 22.9% | 20.0% |
| `tests/unit/test_quick_battle_v03.gd` | tests | 458 | 6341 | 22.5% | 20.0% |
| `tests/unit/test_atx_spread_and_rewrite.gd` | tests | 525 | 6731 | 22.3% | 20.0% |
| `core/battle/faction_identity.gd` | core | 112 | 1077 | 22.2% | 15.0% |
| `core/run/run_state.gd` | core | 293 | 2719 | 22.0% | 15.0% |
| `tests/unit/test_atx_chips.gd` | tests | 584 | 8221 | 21.9% | 20.0% |
| `presentation/menus/shop_view.gd` | presentation | 230 | 2322 | 21.8% | 15.0% |
| `tests/native_golden_policy.gd` | tests | 172 | 1858 | 21.8% | 20.0% |
| `presentation/menus/roster_view.gd` | presentation | 341 | 3844 | 21.6% | 15.0% |
| `core/run/roster_manager.gd` | core | 683 | 6636 | 20.9% | 15.0% |
| `tests/unit/test_swap.gd` | tests | 297 | 3603 | 20.3% | 20.0% |
| `tests/unit/test_run_golden.gd` | tests | 105 | 1284 | 20.2% | 20.0% |
| `core/battle/colonial_awaken.gd` | core | 399 | 3550 | 19.9% | 15.0% |
| `core/battle/focus_fire.gd` | core | 57 | 475 | 19.0% | 15.0% |
| `core/battle/enemy_mech.gd` | core | 121 | 1221 | 18.7% | 15.0% |
| `core/run/node_resolver.gd` | core | 964 | 8303 | 17.7% | 15.0% |
| `core/battle/rival.gd` | core | 107 | 822 | 16.9% | 15.0% |
| `core/battle/units.gd` | core | 269 | 1880 | 16.8% | 15.0% |
| `core/battle/moon_v02.gd` | core | 156 | 1000 | 16.6% | 15.0% |
| `core/battle/colonial_v01.gd` | core | 456 | 3535 | 15.8% | 15.0% |
| `core/battle/ai.gd` | core | 268 | 1907 | 15.4% | 15.0% |

---

## §5 怎么用这份地图（给人和 AI Reviewer）

1. **只想知道「改这个要动哪些文件」** → 索引页 §4 合规审计 + 本页 §3.2 反向依赖（谁在依赖它）/ §3.3 正向依赖（它依赖谁）。
2. **想知道「这个符号在哪 / 谁在调它」** → `node godot/tools/route_query.mjs <符号名|文件路径>`（推荐，只吐切片）；或 `grep "符号名" 本页`（§2 / §3.4 都有 `文件:行号`）。
3. **想审「分层有没有塌」** → 只看索引页 §4：`violations: []` 才算合规；规则 ⑤ 的数字**只许往下走**。
4. **机器读** → `协作/架构/Godot-AST依赖清单.json`（`files[].dependsOn` / `dependsBy` / `funcs[]` / `consts[]` / `estTokens` / `commentRatio` / `classIndex` / `violations` / `audit.coreToFactionRatchet`）—— **别整份读**，用 `route_query.mjs` 取切片。
5. **改完代码** → `node godot/tools/build_godot_routemap.mjs` 重建，`node godot/tools/build_godot_routemap.mjs --check` 必须 `0`（三份生成物逐字节一致）。

