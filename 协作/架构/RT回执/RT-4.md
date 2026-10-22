# RT 回执 · RT-4（收尾）

> 按「RT-4 补充清单」末尾的提交顺序做：第 1 条（session → core → data 键）→ 第 6、7 条 → 第 2、3、8 条 → 第 4 条 → 第 10 条 → 第 5 条。
> 实际执行顺序有两处调整，见 §0；**第 6 条与第 7 条剩下的部分没做完**，§8 写清了断点与继续步骤。
> 门禁口径照 §0.3：全量 `run_tests.gd` 全绿 + `--check` EXIT=0，每个提交前后原生样例逐条一致。

## 0. 两处顺序调整（先说明，免得看 diff 时以为漏了）

1. **第 7 条的「删旧入口 `start_quick_battle`」提前到第 1 条之前**（`[RT-4-1]`）。理由：第 1 条让单机牌组恒真之后，
   旧入口开出来的就是新战斗，`test_ux5_ux6_feedback` 段 ③ 的两条断言当场不成立 —— 两件事必须同一批落地。
2. **第 6 条（旧手牌只读口子）排到最后，且没做完**（§8）。它牵动 `display_helpers.gd` 约 250 行 + 6 个表现层读者 +
   `serve_site.mjs` + 5 个测试文件，是本单最大的一块；本对话的上下文预算不够安全做完，**留成断点**而不是半改。

## 1. `[RT-4-1]`（`e686f2c`）第 7 条前半：删旧入口 `start_quick_battle` + `test_ux5` 段 ③

- 删 `GameSession.start_quick_battle()`（生产 0 调用，只剩 `test_ux5` 段 ③ 一处故意保留的调用）与它的录像动作名。
- 删 `test_ux5_ux6_feedback.gd` 段 ③（旧战斗屏「憋大招」那 8 条断言）与 `run()` 里的调用；文件头第 ③ 条描述同步改。
- `toggle_unit_switch(保留大招)` 的内核覆盖仍在 `test_session_flow`（3 条）+ `test_ux5` 的 `_源码红线`（`has_method`）。
- 测试：全量 3568 → 3560（−8）· 原生样例 ✓ 11。

## 2. `[RT-4-2]`（`8f297aa`）第 1 条（session 层）：删 `GameSession.单机牌组模式`

- 删 `单机牌组模式` 变量与写它的 4 个口子（`set_unit_deck_mode` / `启用单机牌组` / `enable_unit_deck_mode` / `unit_deck_mode`）。
- `SessionBattleOptions.生产()` 去掉第三个参数：单机牌组 / 秘银v03 / 卡牌流转**恒写进选项**；`_开快速战` 的 `elif 单机牌组模式` → `else`。
- `_读存档` 里「恢复这一局的单机牌组模式」整段删；`_新局` 恒写 `特置(单机牌组, true)`；菜单 `_点开局()` 不再拨开关。
- 测试：删 6 条「全新会话默认不开 / 回菜单熄灭」对照 + `_段1_红线`；`set_unit_deck_mode(true)` 调用点全删。
- 测试：3560 → 3553（−7）· 原生样例 ✓ 11。

## 3. `[RT-4-3]`（`8295e3e`）第 1 条（core 层）：删 `Params.单机牌组_开`，71 个调用点按恒为真内联

- 形状对应：`ctx == null or not 开(ctx)` → `ctx == null`（7 处）；`if not 开(ctx): return 中性` → 整段删（8 处）；
  `if 开(ctx) and X` → `if X`；9 个模块级 `开(ctx)` 守卫（AtxChips/AtxDuo/AtxFaction/AtxGodsbet/AtxLuck/AtxSmoke/AtxThree/ClassCards）→ 恒 `return true`。
- 连带删掉只有「关着」才走得到的整段：`card_effects` 旧战术手牌通道（−34 行）、`fac_cb` 两条 v0.2 被动（−22 行）、
  `card_pool`「未命中段/打空」恒假分支、`Ai.hasOverwatch`（无调用者，−6 行）、`setup` 的 `单机开` 门。
- `Setup.开局` 现在恒调 `初始化单机牌组` —— **176 场原生样例逐条一致**（样例本来就是新模式口径）。
- 测试：8 个文件删掉「开关关」整段与 `_开关()` 夹具、4 条「默认关/收尾还原」对照；`test_atx_chips` ⑩ 改成正面断言。
- 测试：3553 → 3471（−82）· 原生样例 ✓ 11 · `--check` 一度红在 `atx_duo`/`atx_faction`/两个测试的注释占比，已就近修。

## 4. `[RT-4-4]`（`1effa84`）第 1 条（data 键）：删两个 `开` 键

- `data/js/71-改动-4-战斗结构.json`：`单机牌组.开`、`战术卡牌.开` 删掉（本单唯一允许的 `data/js` 改动），其余键一个不动。
- `test_armor_pool` 段 ⑦ 删两条读数据键的前置/收尾断言；`test_cr1_review_fixes` 删开战前拨键脚手架；`test_quick_battle_v03` 删未用助手。
- 测试：3471 → 3469（−2）· 原生样例 ✓ 11 · `--check` violations = []。

## 5. `[RT-4-5]`（`a6c2cc0`）第 2、3、8 条：棘轮重登记 + 待接入注释

- 第 2 条：`SIZE_RATCHET` 21 项全部重登记为「实测 × 1.03 向上取整」（例：`test_session_flow` 32608 → 33587、
  `celestial_v01` 31728 → 32680、`atx_three` 20772 → 21396、`game_session` 14351 → 14782）。
  `godot/README.md` §文件体积约定第 3 条写明：**这点余量只给修 bug 和补注释用**，不许拿来长新功能；拆小后照样往下调。
- 第 3 条：`CORE_TO_FACTION_RATCHET_MAX` 143 → 120（实测 120，现在持平）。
- 第 8 条：`AtxThree.升版卡表()` / `角色牌们加版()` 各加 `# 待接入：肉鸽升级（+ 版），勿当死代码删`；
  `BattleMorale.战术回合` **仍然加不了**（一加 17.72% > 15%，实测过）。
- 测试：3469（±0）· 原生样例 ✓ 11 · `--check` violations = []。

## 6. `[RT-4-6]`（`fc60674`）第 4 条（部分）：README + 6 个文件首行的旧口径说明

- `godot/README.md` 注释约定①：第二行不再要求写「开关关闭时返回中性值（黄金样例零影响）」；删除项③改成
  「零影响声明一句都不要写 —— 开关已经删光，没有『关着』这条路」；顺带删掉两处「JS 参考版 168 场」的历史句。
- 6 个 `.gd` 第二行的约定句删除（`atx_faction` / `atx_three` / `calc` / `celestial_v01` / `deck_flow` / `fac_atx`）——
  全仓「所有势力 / 版本分支在开关关闭时返回中性值」现在 **0 处**。
- **没清完**：还有 28 行散落在 15 个文件里的「黄金样例逐字不变 / 旧口径…」注释（不进门禁）。留给下一张单扫。
- 测试：3469（±0）· 原生样例 ✓ 11 · `--check` violations = []。

## 7. 汇总（第 5 条）

| 项目 | 数字 |
|---|---|
| 提交 | 6 个（`e686f2c` `8f297aa` `8295e3e` `1effa84` `a6c2cc0` `fc60674`）+ 本回执 |
| 与 RT-4 开工前（`238c89f`）相比 | 63 个文件 · **+3288 / −4990** 行（净 −1702 行） |
| 删掉的开关 | `Params.单机牌组_开`、`GameSession.单机牌组模式`（+ 4 个读写它的口子）、`AtxThree.装填开`、数据里的 `单机牌组.开` / `战术卡牌.开` |
| 测试项数 | **3568 → 3469（−99）**：删掉的全是「开关关着 / 默认关 / 收尾还原」这类对照断言 |
| 原生样例 | 每个提交前后 **176 场逐条一致**（`[test_native_goldens] ✓ 11` 全程没红过） |
| 全量耗时 | 见 §7.1（与基线同量级） |
| 门禁 | 最后一次：全量 ✓ 3469 项 · `--check` EXIT=0（violations = []） |

### 7.1 耗时

基线与收尾各跑一次全量（`godot --headless --path godot --script res://tests/run_tests.gd`）：
收尾实测 **219.6 秒**（`Measure-Command` 计），比开工前基线（约 190 秒量级）略长 —— 删掉的是断言不是场次，
`test_native_goldens` 的 176 场一场没少，加上本机负载波动，属同一量级。

## 8. 没做完的（断点，交给下一次续接）

### 8.1 第 6 条：旧手牌只读口子（**未做**）

要删的都在 `session/display_helpers.gd`：`hand_cards`（读 `ctx.战术手牌`）、`bench_cards`、`_附来源`、`card_source`、
`hand_count`、`cards_played_this_turn`、`cards_playable_now`、`hand_card_status`、`hand_status_all`、`_找手牌卡`、
`_补手牌连携状态`、`_卡可打吗`、`reserve_preview`、`deck_remaining`、`playable_hand_ids`、`_气氛`；
外加 `unit_view()` 的 `"气势"`、`turn_card_summary()` 的 `本场已打出`、`result_summary()` 的 `本场战术牌`
（结算界面那一行直接去掉）。

**已查清的读者（续接时照这张表改）**：`session/game_session.gd`（同名转发 + `turn_card_summary`）、
`session/battle_flow.gd`（3 处 `last` 里的 `"手牌"/"候补"`）、`session/run_facade.gd`（1 处）、
`presentation/battle/log_panel.gd:51/60`（战报提示那一行）、`presentation/battle/result_view.gd:162`（本场战术牌回顾）、
`session/tooltip_text.gd:82/86`（「当前手牌」）、`godot/tools/serve_site.mjs:93/94`（外部工具的 `气势=` / `手牌=` 显示）、
测试 `test_session_flow:135/140`（`turn_card_summary` 键集合）。
**注意**：`hand_count()` 被 6 处 `last` 摘要用着，删它要一起改（建议直接去键）。

### 8.2 第 7 条剩下的部分（**未做**）

`test_unit_deck_system.gd:533`「关着时一个字段都不多」与 `test_run_core.gd:371` 的 `{"战术卡牌": true}` 夹具：
两条都随第 1 条落地，但**现在它们还在**（前者已被第 1 条改成会走新模式，续接时要删或改判据）；
`presentation/battle/hand_panel.gd` / `hand_card_item.gd` 里只服务旧手牌栏的节点与分支也没删（和 §8.1 同一批做最省事）。

### 8.3 第 4 条剩下的 28 行旧口径注释

见 §6；`grep -rn "黄金样例\|零影响\|逐字不变" godot --include=*.gd` 里仍在 15 个文件的注释行。

## 9. 顺手记一笔（不属本单）

- `test_atx_chips` 段 ⑩ 从「开关关着 = 一个字段都不加」改成了「【赌局】真的会触发（库 4 → 3、随机数 1 次）」——
  这是本单唯一一处**改判据**（原来那条对照没有对应的生产方式了）。
- 9 个模块级 `开(ctx)` 守卫现在恒 `return true`，内部 100+ 处死守卫；已记进 `已知缺口汇总.md` 一类第 9 条。
- `.uid` 生成物：本单误提交过两次，已从提交中摘掉（保持未跟踪，和开工前一致）。

---

# RT-4 续接（冷启动第 2 段）

> 入口：施工单「RT-4 中途验收 + 续接清单」1~4。开工前 `git status` 只有两处：施工单本身被 Claude 追加了
> 验收结论（纯文档，+67 行）与 11 个 `.uid`（按 §9 保持未跟踪）—— 前者先单独提交 `[docs]`（`79fabf9`），后者不动。
> 基线：全量 **3469 项** 全绿、194.1 秒。临时子集跑测器 `_tmp_run_subset.gd` 放 `godot/.godot/`（扫描器跳过点目录，
> 实测「带它重建」与「挪走它重建」三份生成物 sha256 相同），提交前把任何 `godot/tests/` 下的临时文件删干净。

## 10. `[RT-4-7]`（`7ea071b`）第 6 条（§8.1）：删旧手牌只读口子

> **重号说明**：上一段最后一个提交 `a9192ac` 的标题也是 `[RT-4-7]`（「第 10、5 条：已知缺口汇总 + RT-4 总回执」）。
> 本段沿用施工单给的段号（§10 起），提交标题从 `RT-4-7` 接着排，因此这一个号出现两次 —— **以提交号为准，
> 不重排历史**（重排要把 12 个提交全部 rebase，代价大于收益）。

- `session/display_helpers.gd`：删 `hand_cards / bench_cards / _附来源 / card_source / hand_count / cards_played_this_turn /
  cards_playable_now / hand_card_status / hand_status_all / _找手牌卡 / _补手牌连携状态 / _卡可打吗 / reserve_preview /
  deck_remaining / playable_hand_ids / _气氛`（−201 行）；`unit_view()` 的 `气势`、`result_summary()` 的 `本场战术牌` 一并删。
  **`_我方阵()` 保留** —— `session/tooltip_text.gd:64`（来源机体那一行）还在用它。
- 读者同步：`game_session`（删 16 个转发口子、`turn_card_summary()` 只剩 `回合`、结算缓存去 `本场战术牌`）、
  `battle_flow`（3 处 `last` 摘 `手牌/候补`）、`run_facade`（1 处）、`live_monitor`（摘 `hand/playable_now/reserve_count`）、
  `log_panel`（旧战报提示那一行 / 结束回合回话的 else 支）、`result_view`（本场战术牌回顾整段 + `战术牌回顾` 节点）、
  `tooltip_text`（「当前手牌」两行）、`hand_panel._手牌快照()`（恒空，加一行说明）。
- 外部工具：`godot/tools/serve_site.mjs:93-95` 的 `气势=` / `手牌=` / `候补=` 三段删掉（`live_smoke.mjs` / `web_*.mjs`
  一个都不读这些键，已查）。
- 测试改动（4 条，逐条）：`test_session_flow` 两条键集断言改成「`turn_card_summary()` 只剩回合 + `deck_turn_summary()`
  报两排」；`test_battle_screen` 「本场打出的战术牌」改成「战斗日志一共 N 行」；`test_layout_log` 快照键表去掉 3 个；
  `test_presentation_smoke` 结算屏节点表去掉 `战术牌回顾`。
- 测试：3469 → **3465（−4）**· 原生样例 `✓ 11` · `--check` EXIT=0。

## 11. `[RT-4-8]`（`a70f1ca`）第 7 条剩余（§8.2）：删旧手牌栏节点与分支

- `hand_panel.gd`：删 `候补区 / 候补文 / 候补卡行 / 手牌滚动 / 手牌列表` 五棵子树与 `_建滚动盒`；`_切单机双排(单机)`
  收成只管专属排 / 公有排显隐；`_手牌卡控件()` 恒 null（发牌帧仍恒 0，6 条拆帧守卫原样保留）。
- `battle_view.gd`：删 5 个 var + 两处空态赋值 + `_建滚动盒` 转发 + `手牌滚动高`。
- 测试：`test_unit_deck_system` 删「`ctx.单机牌组 == true`」这条恒真断言（阶段仍由 ③ 段守）与文件头「关着那条路」；
  `test_run_core` 的 `{"战术卡牌": true}` 夹具 → `{}`；`layout_fixtures` 删只给旧手牌栏用的 `_手牌卡控件`；
  `test_presentation_smoke` / `test_layout_hand` / `test_layout_sidebar` 的「旧那行战术手牌仍在树上」三条改成不查。
- 测试：3465 → **3462（−3）**· 原生样例 `✓ 11` · `--check` EXIT=0。

## 12. `[RT-4-9]`（`8b8df31`）第 3 条 · 模块 1/9：`AtxLuck`

- 删 `开()` 与 2 处死守卫（`初始化` / `打出时`）；文件头「★ 开关」段删掉，章节名「开关与牌面判定」→「牌面判定」。
- 无外部调用点。测试：3462（±0，Luck 段全绿）· `--check` EXIT=0。

## 13. `[RT-4-10]`（`e846c1f`）第 3 条 · 模块 2/9：`AtxRewrite`

- 删 `开()` 与 3 处死守卫（`设` / `应用` / `打出时`）；`atx_three.gd:870`、`weapon_exec.gd:231` 两个调用点内联。
- 测试：3462（±0）· `--check` EXIT=0。

## 14. `[RT-4-11]`（`1777493`）第 3 条 · 模块 3/9：`AtxSmoke`

- 删 `开()` 与 7 处死守卫（`初始化 / 列有雾 / 命中惩罚 / 放烟 / 阶段初 / 打出时 / 副武器特殊打出`）。
- 测试：3462（±0）· `--check` EXIT=0。

## 15. `[RT-4-12]`（`d4a6aae`）第 3 条 · 模块 4/9：`AtxChips`

- 删 `开()` 与 10 处死守卫；连带去掉三句「筹码牌库未开启（单机牌组关着）」的原因文案（已无这条路）。
- 调用点内联 3 处：`battle_hand_view.gd:388/419`、`card_exec.gd:229`。
- 测试：3462（±0）· `--check` EXIT=0。

## 16. `[RT-4-13]`（`04dfdff`）第 3 条 · 模块 5/9：`AtxGodsbet`

- 删 `开()` 与 12 处死守卫（含 `不可打原因` / `认领大招槽` / `可翻盘` 的短路）；`card_exec.gd:223` 内联。
- 测试：3462（±0）· `--check` EXIT=0。

## 17. `[RT-4-14]`（`c9f53ff`）第 3 条 · 模块 6/9：`AtxDuo`

- 删 `开()` 与 15 处死守卫（R1 那条铁律整段从文件头删掉）。
- 测试：3462（±0）· `--check` EXIT=0。

## 18. `[RT-4-15]`（`a9c53e0`）第 3 条 · 模块 7/9：`AtxFaction`

- 删 `开()` 与 14 处死守卫；章节名「开关与身份」→「身份」；两处原因文案改「没有战斗上下文」。
- 无外部调用点。测试：3462（±0）· `--check` EXIT=0。

## 19. `[RT-4-16]`（`7910045`）第 3 条 · 模块 8/9：`ClassCards`

- 删 `开()` 与 14 处死守卫；`weapon_exec.gd:234` 内联；`test_class_cards` 删「`ClassCards.开(ctx)` = true」那条恒真断言。
- 测试：3462（±0）· `--check` EXIT=0。

## 20. `[RT-4-17]`（`94f70cd`）第 3 条 · 模块 9/9：`AtxThree`

- 删 `开()` 与 19 处死守卫 + 2 个钩子里的短路；`card_exec.gd:225` 内联。
- `已知缺口汇总.md`：删掉「一·9」（本单已做完）与「二·4」（旧手牌只读口子已做，原文写着「RT-4 未做」）。
- 测试：3462 → **3461（−1）**· 原生样例 `✓ 11` · `--check` EXIT=0。
- 备注：`CelestialV01.开(ctx)` **保留** —— 它不是恒真守卫，还要判「队里有没有天人成员」。

## 21. `[RT-4-18]`（`dc2ac62`）第 4 条（§8.3）：剩余旧口径注释

- 按 `grep -rn "黄金样例\|零影响\|逐字不变"` 清 20 个文件：能删的删（`ai` / `flow` / `boss` / `setup` / `units` /
  `card_effects` / `sub_deck` / `deck_builder` / `node_resolver` / `part_system` / `rule_hooks` / `relic_battle` /
  `map_view` / `boot` / `battle_flow` / `record_native_golden` / 7 个测试文件），仍成立的改写成不提旧样例的说法。
- 顺带清掉**已删开关**留下的「开关关着 = …」注释（`Params.单机牌组_开` / `秘银v03开` / `卡牌流转v01开` / `武器范围v01开`
  都已不存在，留着会让人以为还有两条路）。
- **故意保留**：`map_generator` / `run_state` / `test_run_map` / `test_run_core` 里那 6 处「黄金样例」指的是**还在用的
  `run_vectors.json`（局外样例）**，以及 `test_session_flow` / `test_card_table_snapshot` 里「连调两次逐字不变」这类
  **仍然成立的纯读断言** —— 不是旧口径。
- 测试：3461（±0）· 原生样例 `✓ 11` · `--check` EXIT=0。

## 22. RT 全单最终汇总（相对 RT 开工前 `3c10e82`）

| 项目 | 数字 |
|---|---|
| 提交 | RT-1 ~ RT-4 共 **46 个** `[RT-*]` 提交（RT-4 段 19 条，其中一处重号见 §10；本段 12 条 + 1 个 `[docs]`） |
| godot 源码 | **151 个文件 · +2331 / −7573 行（净 −5242）**（含 3 份 RouteMap 生成物的重算） |
| 全仓 | 173 个文件 · +14265 / −19060（净 −4795；差额是生成物与文档） |
| 删掉的开关 | `params.gd` 的 `…开()` **19 → 8**（退役 11 个主开关）+ 9 个模块级 `开(ctx)` 守卫 + `GameSession.单机牌组模式` 与 4 个读写口子 |
| 测试项数 | **3960 → 3461（−499）**：删的全是「开关关着 / 默认关 / 收尾还原」对照与旧手牌链路断言 |
| 原生战斗样例 | **176 场全程逐条一致**（`[test_native_goldens] ✓ 11` 在 31 个提交里没红过一次；未重录） |
| 全量耗时 | 开工 217.4 秒 → 收尾 **206.6 秒**（`Measure-Command` 口径，同量级） |
| 门禁 | 最后一次：`✓ 全部通过：3461 项` · `--check` EXIT=0（violations = []、索引页 7,817/8,000） |

**没做 / 留给下一张单的**（都在 `RT回执/已知缺口汇总.md`）：`Flow.回合开始` 那一票「开始与结束不对称」的规则、
`AtxThree.这一档发吗` 的 19 张剧情档、24 张 `+` 升版牌的「肉鸽升级」、发牌动画恒 0、`BattleFx._收窄到最后一拍`。
`.uid` 生成物仍按 §9 保持未跟踪（本段 12 个提交里又误纳过两次，均已 `--amend` 摘掉）。

**验证口径的如实说明（一句）**：§10、§11、§20、§21 四处跑了**全量**（含 `test_native_goldens` 的 176 场）；
§12~§19 那 8 个模块提交当时只跑了相关子集（`atx_*` / `class_cards` / `weapon_*` / `presentation_layout`），
它们的原生样例一致性由 §20 之前的那次全量覆盖 —— 这 8 处的改法形状是 `if not 开(ctx) or X:` → `if not X:`
（`开()` 逐字 `return true`），语义等价，但**不是每个提交都单独重跑过 176 场**。
