# COL-4b 回执：补完 COL-4「没做完」的 4 条（表现层）

一、完成（只动表现层 / 会话层，**不改战斗结果**，原生样例逐条不变、未重录）
1. **QTE 手动弹窗**：新文件 `presentation/battle/colonial_overlay.gd` 建「失手 / 成功 / 完美 + 取消」浮层。
   点武器型觉醒大招且 `session.get_qte_mode() == "manual"` → **先弹窗、不结算**；选完带档位重新走同一张牌
   （`GameSession.play_unit_ultimate_qte` → `ctx.QTE指定` → 打完立刻收掉）。判据：`ColonialV01.走QTE(卡)`。
2. **顶栏 QTE 模式循环键**：`TopBar` 新增「QTE：手动选择 / 固定完美 / 固定成功 / 固定失手 / 随机」
   （`name = "QTE模式按钮"`），只在战斗里可点；点一下 `session.cycle_qte_mode()`，文案读 `topbar_state().QTE模式`。
3. **【觉醒感应】牌亮金边**：手牌控件（`_建单机卡`）与左牌库卡（`_建左库卡`）都用 `UiTheme.金边` + 2px 边框；
   判据 `ColonialV01.该亮金边(u, 卡)`（门面视图字段 `亮金边`，控件另挂 `gold_edge` meta）。觉醒后自动熄灭。
   （说明：手牌栏只画「现在打得出来」的牌；打不出来的【觉醒感应】大招躺在左牌库，所以两处都接。）
4. **觉醒徽章配色**：`UiTheme.觉醒色()` → SEED 蓝 / ZERO 绿 / 隐身（alpha 0.55）；`unit_view` 新增 `觉醒类型`，
   `UnitCard` 把状态行首位那枚〔觉醒中·X〕按类型上色。
5. **感应牌库可点开看库内牌**：左栏「查看感应牌库」按钮（殖民卫星军在场才露）→ 面板逐张列出一 / 二 / 三级 + 本场移出；
   数据走 `GameSession.感应牌库状态()`。顺手修了 `ColonialDeck.感应牌库明细` 读错等级键（`感应等级` → `级`）。
6. 拆件：`battle_view.gd` 只留一行转发，覆盖层实现搬到 `colonial_overlay.gd`（不然它会冲过 12,000 token）。

二、测试（新增 `tests/unit/test_colonial_presentation.gd`，34 项）
- manual 模式下大招**等待选择**（弹窗出现、战意 / 战报一个字没动）→ 选「完美」后日志出现〔QTE·完美〕、闪避 +20、战意下降。
- 金边判据接到控件上：左牌库那张觉醒大招 2px 金边；把一张【觉醒感应】精神牌挪进手牌 → 手牌控件 2px 金边；觉醒后不再亮。
- 觉醒徽章三色（SEED / ZERO / 隐身 alpha < 0.8）+ `unit_view.觉醒类型` 这条链。
- 感应牌库按钮可见 → 面板逐张列出库内牌、标题写各级张数。
- 顶栏 QTE 键：文案跟会话一致、点 5 下循环一圈回到原档。

三、门禁：全量 `run_tests.gd` **3676 项全绿**（3642 + 新增 34）；`build_godot_routemap.mjs --check` **EXIT=0 / violations []**；
原生样例 `tests/golden/native/` **一个字节没改**（`git status godot/tests/golden` 无输出）。

四、耗时：全量测试 **4.6 分钟**；本批**不重录**样例（0 分钟）。

五、下一步从哪开始：COL-5 收尾 —— 先给 `tests/golden/native/inputs.json` 加殖民卫星军 quick 分区
（新文件 `quick_colonial`），跑 `record_native_golden.gd --coverage` 看觉醒入场 / 感应抽牌与放入 / METEOR / 隐身
是否都覆盖到，再重录一次 + 10 局无头自检。
