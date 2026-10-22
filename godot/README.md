# 机甲指挥 · Godot 版

本项目**唯一长期维护的游戏引擎**。仓库根目录的 JS 版是冻结的玩法参考（tag `js-reference-final`），迁移完成后移到 `archive/js/`。
架构与迁移计划：[`../协作/架构/Godot迁移架构-v1.md`](../协作/架构/Godot迁移架构-v1.md)

当前进度：**M0 地基** ✅ · **M1 数据与样例** ✅（`data/js/` 121 个常量）· **M2 Battle Core** ✅（`core/battle/`）· **M3-Prep** ✅（藏品开战注入 = `core/battle/relic_battle.gd`（DEBT-06：不读全局 `肉鸽.RUN`，由 `Setup.开局(..., 选项.藏品)` 传入）· 局外黄金样例 [`tests/golden/run_vectors.json`](tests/golden/run_vectors.json)：8 种子 × 4 层地图 / 推进剂 / 招募券 / 晋升面板 / 三选一）· **RT-2** ✅（**176 场 Godot 原生**战斗黄金样例 `tests/golden/native/`，口径见 [`tests/golden/README.md`](tests/golden/README.md)；旧的 168 场已退役，归档在 [`../协作/归档/`](../协作/归档/)）· 下一步 **M3 肉鸽内核**。

## 本地开发

- 用 **Godot 4.7.2** 打开 `godot/project.godot`（渲染器：Compatibility，Web 只支持 WebGL 2）。
- 只用 **GDScript**：Godot 4 的 C# 项目不能导出到 Web。

```
godot --headless --path godot --import
godot --headless --path godot --script res://tests/run_tests.gd     # 退出码 0 = 全绿
```

## 目录

| 目录 | 内容 | 规矩 |
|---|---|---|
| `core/` | 纯逻辑（战斗 / 肉鸽内核、随机数、规则） | 只继承 `RefCounted` / `Resource`；不碰场景树、文件、时间、引擎随机数；四舍五入用 `J.round`（= `JsCompat.js_round`），排序用 `J.sort`（= `JsCompat.stable_sort`）；与 JS 语义不同的地方（真假值、`||`、数字转字符串、`includes`…）一律走 `core/util/js.gd` 的 `J`。`tests/unit/test_boundary.gd` 自动检查 |
| `core/battle/` | 战斗内核，一个文件对应 JS 的一个片段：`setup`（开局 / 一回合 / 胜负）· `flow`（回合开始 / 行动 / 结算）· `btl`（记录 / 气势 / 嘲讽 / 自爆 / 词条 / 战术牌）· `calc`（命中 / 伤害 / 标定）· `ai` · `boss` · `fac*`（六个势力）· `params` · `units` · `traits` · `reach` · `fm` · `diff` · `relic_battle`（藏品开战注入，93-藏品.js） | 入口：`Setup.开局()` → 每回合 `Btl.打战术牌()`… → `Setup.打一回合()`；单位与 ctx 是 Dictionary，键名照 JS；藏品 id 从 `选项.藏品` 进来（DEBT-06，不读全局 `肉鸽.RUN`） |
| `data/js/` | 内容与数值（`manifest.json` 记来源与规则签名）；由 `session/data_loader.gd` 读入成 `GameData` | 内核只读；小数要能被 Godot 无损解析（`test_data` 检查） |
| `session/` | 会话层：读数据、存档、命令分发（IO 只在这里） | |
| `presentation/` | 场景与界面 | 只读内核状态；玩家操作变成命令交给内核 |
| `assets/fonts/` | `ui_font.tres` = 中文主字体子集 + emoji / 符号后备（全部 SIL OFL 1.1，许可证在同目录） | 缺字时 `test_font_coverage` 报红 → 运行下面的字体命令 |
| `tests/` | `run_tests.gd` 自动发现 `tests/unit/test_*.gd`；`golden/` 放从 JS 导出的对拍数据（格式见 `tests/golden/README.md`） | golden 文件**不存 JSON 小数**（Godot 解析会丢精度）：随机数存 uint32，浮点存 IEEE-754 位串 |
| `tools/` | CI 安装脚本、字体子集、JS 向量导出、浏览器冒烟 | 不打进游戏包 |

## 注释约定

> 目的：`.gd` 一律按这一份写注释。**历史写在提交记录里，不写在代码里**；读代码时不必再看「以前怎么写、哪张任务单改的」。

**保留**

1. **文件首行的 `##` 职责注释**——RouteMap 的「职责」列就是读这一行（`tools/build_godot_routemap.mjs` 取首个 `##` 行），**不许删、不许挪到第二行**。
   第二行写「本文件的约定 / 铁律」（例如「纯逻辑，不碰场景树」）。**开关已经删光了，不再写「关着时返回中性值」那种口径。**
2. **不变量和不显然的「为什么」**：例如「池扣到 0 之后不能回落到 A（`J.or_` 会把 0.0 当假值）—— 这里按 `??` 取」。
   只写「为什么必须这样」，不写「这一行代码做了什么」。
3. **规则锚点**，写成短标签，方便 `grep`：`# [规范v0.3·断路器3]`、`# [装甲共享池]`、`# [武力介入]`、`# [七剑]`、`# [狙い撃つ]`、`# [演算]`、`# [双人格]`。
   同一份规则在多个文件出现时用**同一个标签**，`grep '\[装甲共享池\]'` 就能一次找齐。
4. **公开函数前一行 `##` 说明**（参数和返回值不明显时最多两行）。私有辅助函数（`_xxx`）名字说清了就不必写。

**删除（历史信息交给提交记录）**

1. 来源与日期标签：`★ A6c` / `★ CB-2` / `★ 2026-10-21（任务单问题 4）` / `第 3 项断路器修复（DS41F）`。
2. 「从前……现在……」的变更叙述，以及大段横线分隔框（`# ====…====`）。章节分隔只留一行 `# ---- 一、开关与成员识别 ----`。
3. 「开关关着 = 一个字段都不多 / 黄金样例逐字不变 / 与改前逐字相同」这类**零影响声明**——开关已经删光，没有「关着」这条路了，一句都不要写。
4. 把代码直译成中文的注释（`# 遍历 allies`、`# 返回 true` 这类）。

**搬走**

- 设计讨论和长篇解释 → 链接到对应的设计稿或任务单，例如 `# 见 协作/设计/武器范围规则 v0.1.md §二`，不在代码里复述规则原文。

**顺带的硬指标**（`node godot/tools/build_godot_routemap.mjs` 的 §0.5 会量）：单文件注释占比 ≤ 15%（`tests/**` ≤ 20%），
估算 token = `CJK 字符数 × 1.0 + 其余字符数 ÷ 3.5`。`calc.gd` 与 `celestial_v01.gd` 是这一份规范的示范文件。
这一条已经是**门禁**（规则 ⑧）：阈值就是判据 —— 生产代码（`core/` `session/` `presentation/`）单文件 > 15%、
`tests/**` > 20% 即 `violations`。`COMMENT_RATCHET` 是一张**登记清单（只有路径、不记数值）**：登记过的文件必须一直待在
本层阈值以内（**没越阈值时往里加注释是允许的**，不是冻结建表时的占比）；未登记的文件同样不许超阈值，只是先走
RouteMap §0.5 的警告清单（不判红，等清理时再登记进清单）。

## 新增一个势力 / 职业模块时

1. 在 `core/battle/rule_hooks.gd` 的 `顺序` 表里**登记**（`"钩子名": [模块…]`；表里的顺序 = 派发序 = 改动前的调用序，不许重排，也不许在调用点写死）。
2. 按各钩子的约定签名实现（`(ctx, att, def, w, …)` 一一对应，参数直接 `callv`）；不实现的钩子按中性值处理。钩子名与原函数名不同时，模块内加**薄转发**。
3. 卡表数据放进 `data/cards/<模块>.json`，由 `session/data_loader.gd` 装入 `Db.T`（别写进 `.gd`）。卡包在 JSON 顶层写自己的
   **`"结构"` 声明**（`卡组` / `分人卡组` / `单卡` / `武器表`，见 `DataLoader.结构类型们`），加载器按它校验条目、并做**卡 `id` 全局唯一**检查；
   同时把该包的取表函数登记进 `tests/unit/test_card_table_snapshot.gd` 的快照注册表（`tests/golden/card_tables/<卡包名>.txt`），
   搬数据前后快照必须逐字一致。
4. 出牌门槛写在模块自己的 `static func 卡不可打原因(ctx, u, card, 区) -> Dictionary` 里，**返回 `{终局, 原因}`**（`{终局: false}` = 这张牌不归我管；`{终局: true, 原因: ""}` = 能打、`原因` 非空 = 不能打），由 `RuleHooks` 的 `卡不可打原因` 顺序表经 `首个结论` 派发，**不要往通用内核加分支**。
5. **大招槽按处理者分派**：装填大招槽时在槽条目上写 **`"处理者": "<模块名>"`**（例如 `AtxGodsbet` / `AtxThree` / `AtxFaction` / `CelestialV01`；通用大招**不写**）。模块按需实现 `大招不可打原因(ctx, u, 槽)`、`打出大招(ctx, u, 槽, 目标)`、`大招阶段初(ctx, u, 槽)` 三个钩子，由 `RuleHooks.按处理者()` 分派；没写处理者或处理者没实现该钩子，就走 `DeckFlow` 的通用逻辑。`认领大招槽` 只在「应该由谁处理」需要模块自己判断时才实现。
6. **武器栏换装一律走换装栈**：临时一层用 `DeckFlow.压栈武器栏(u, 新表, 来源, 永久 = false, ctx = {})`，撤掉用 `DeckFlow.弹栈武器栏(u, 来源)`（`来源` 唯一，例如 `"λ驱动"` / `"脱装"` / `"METEOR"`；`永久 = true` 的层不可弹出）。栈里存的是**原来那组卡对象本身**，弹出即原样恢复（冷却等运行期字段一律保留）—— **不许**再自己备份 `武器栏原样`、也不许用卡表重建原卡。
7. **不许**在 `calc.gd` / `btl.gd` / `flow.gd` / `card_play.gd` 里点名新模块 —— 规则 ⑤ 棘轮会拦截（`CORE_TO_FACTION_RATCHET_MAX` 只许下调，另见 RouteMap §4.0b 的注册表豁免）。
8. **也不许把引用搬进两个注册表文件**：`rule_hooks.gd` 只许在 `顺序` 表（声明块）里点名，`fac.gd` 只许在 `ORDER` / `match` / `势力 ==` 分派块里点名；区域外一个模块名都不许有 —— 规则 ⑥ 会判红（RouteMap §4.0c）。
9. 改完重建 RouteMap：`node godot/tools/build_godot_routemap.mjs` → `--check` 必须 `EXIT=0`。

## 文件体积约定

1. **一个文件只负责一件事**：文件首行 `##` 写清职责；同类的东西放一起，跨职责就再开一个文件，不靠「再长一点也没关系」。
2. **先拆再加功能**：单个 `.gd` 超过 **1,000 行** 或 **12,000 估算 token** 时，**先把现有代码拆出去，再动手加新功能**（拆分是纯搬家：只移动代码，不改判断、数值、战报文案）。
3. **既有超限文件受棘轮约束**：`godot/tools/build_godot_routemap.mjs` 的规则 ⑦ `SIZE_RATCHET` 逐文件登记了当前 `estTokens`，**只许下降、不许上调**；超过登记值就进 `violations`（`--check` 非零退出）。要改大文件，先拆小、再把表里的数字下调。
   **登记值是「实测值 × 1.03 向上取整」**（RT-4 重登记）：这点余量**只给修 bug 和补注释用**，不许拿来长新功能；文件拆小之后照样要往下调。
4. **新文件超限只给警告**：未登记进 `SIZE_RATCHET` 的新 `.gd` 一旦超过上面两个阈值，会出现在 RouteMap §0.5 末尾的 `sizeWarnings` 清单里（不判红，但要求下一个提交就拆）。
5. 阈值与判据都由工具现扫源码得出（估算 token 口径见上面「注释约定」末尾那句），**不要手改** `Godot-RouteMap*.md` 与 `Godot-AST依赖清单.json`。


## 常用命令

```
python godot/tools/build_font_subset.py                                    # 重新生成中文字体子集（需要 pip install fonttools）
node godot/tools/gen_rng_vectors.mjs . godot/tests/golden/rng_vectors.json # 从 JS 参考版导出 RNG 对拍向量
node godot/tools/export_run_golden.mjs                                     # 从 JS 参考版导出局外黄金样例 → tests/golden/run_vectors.json
godot --headless --path godot --script res://tools/record_native_golden.gd # 重录原生战斗黄金样例 → godot/tests/golden/native/
godot --headless --path godot --script res://tests/run_tests.gd            # 全部测试（含原生样例逐场重跑）
mkdir -p godot/build/web && touch godot/build/.gdignore
godot --headless --path godot --export-release "Web" build/web/index.html  # Web 导出（需要 4.7.2 的 Web 模板）
```

> `data/js/*.json` 从 M2 起由 Godot 侧直接维护，**没有导出脚本了**（`export_data.mjs` 已删，别再从 JS 参考版重导）。
> 战斗黄金样例同理：旧的那 168 场（JS 参考版导出）已退役，现在是 Godot 原生版（见 [`tests/golden/README.md`](tests/golden/README.md)）。

## 发布

推到 `main` 后，`.github/workflows/pages.yml` 依次执行：测试 → 导出 Web → 组装站点 → 浏览器冒烟 → 发布。任何一步失败都不会发布。

- `/`：JS 参考版（M4 之前朋友玩的仍是这一版）
- `/godot/`：Godot 版
