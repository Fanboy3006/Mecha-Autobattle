/* ============================================================================
 * Godot 版 · 自动 RouteMap & AST 静态依赖分析器
 * ----------------------------------------------------------------------------
 * **为什么有它**：Godot 迁移后源码从「56 个拼接片段」变成「4 层 100+ 个 .gd 文件」，
 *   每问一句「`hitRate` 在哪个文件第几行 / 这个模块依赖谁 / 谁在偷偷反向依赖」
 *   就要派一个探查子代理现扫。本工具把这四类问题一次性扫成两份**权威文件**：
 *
 *     ① `协作/架构/Godot-RouteMap.md` —— **主索引**（每次会话开始时读这一份；目标 ≤ 8,000 token）
 *        §0 总览统计 / §0.5 Token 体积 Top 20 / §1 按现象查文件的速查路由表 /
 *        §4 架构分层与耦合合规审计（规则 ①②③④ + ⑤ 内核→势力棘轮 + ⑥ 豁免文件表外引用 + ⑦ 体积棘轮）
 *     ② `协作/架构/Godot-RouteMap-明细.md` —— **明细页**（§2 四层每个 .gd 的职责表 /
 *        §3 正向与反向依赖矩阵 / §4.1 读接口全清单 / §4.4 势力→势力全表）。
 *        **别整份读**：`grep` 它，或跑 `node godot/tools/route_query.mjs <符号|文件路径>` 只取切片
 *     ③ `协作/架构/Godot-AST依赖清单.json` —— 机器可读的完整 AST 符号 + 依赖图 + D1 体积统计
 *        （与 `协作/架构/依赖清单.json` 同构：`file` / `layer` / `declares` / `dependsOn[{to,layer,n,symbols}]`）
 *
 * **扫什么（全部现扫源码，一个行号都不写死）**：
 *   · `godot/` 下所有 `.gd`（**排除 `.godot/` 等点开头缓存目录**），按 `core/` `session/`
 *     `presentation/` `tests/` 分层；
 *   · 每个文件：行数 / 字节数 / `class_name` / `extends` / 顶层 `const` /
 *     `func` 与 `static func` 完整签名（含行号、返回类型、是否 static、外部调用次数）；
 *   · **符号级依赖边**：代码里出现的全局 `class_name` 引用（先建
 *     `class_name → 文件` 注册表，再做**标识符级精确匹配**，注释与字符串先抹成空格）
 *     + `preload("res://…")` / `load("res://…")` 字面量路径 → 解析到被扫到的 `.gd`；
 *   · **架构分层违规自检**（`violations: []`，见 `审计()`）：
 *       ① `core/**` 不得引用 `session/**`        ② `core/**` 不得引用 `presentation/**`
 *       ③ `session/**` 不得引用 `presentation/**`
 *       ④ `presentation/**` 不得绕过 `GameSession` 直接调 `core/**` 的**写接口**（任务书点名 `core/battle/**`，本工具按 `core/**` 全量查）
 *       ⑤ **通用内核文件 → 势力文件**的引用次数 ≤ 棘轮基线 `CORE_TO_FACTION_RATCHET_MAX`（初始 **213**、
 *          CR-2 Batch B 起 **211**、CR-2 Batch D 起 **182**，取自 CodeReview 报告 §3 的实测口径；
 *          **只许往下调、不许往上改**）。
 *          这一类「内核点名势力」的耦合跨层审计完全看不见（都在 core/ 内部），所以单列一条棘轮。
 *          `规则五豁免文件`（`fac.gd` / `rule_hooks.gd`）是**必须**点名势力的派发注册表：单列打印、不计入 ⑤。
 *       ⑥ **豁免文件审计**：`rule_hooks.gd` 的 `顺序` 表、`fac.gd` 的 `ORDER` / `match` 分派区**以外**，
 *          对势力 / 职业模块的引用必须为 **0**（见 `审计豁免文件()`）。防止「把引用搬进豁免文件」绕过 ⑤。
 *       ⑦ **体积棘轮**：`SIZE_RATCHET` 登记过的既有大文件（> 1,000 行或 > 12,000 估算 token）只许变小，
 *          当前 `estTokens` 超过登记值即违规；**未登记**的新大文件只进警告清单（§0.5 末尾），不判红。
 *     （判定规则写在 `写动词` 与 `审计()` 上方的注释里；**只认 `类名.函数名(`
 *       这一种直接静态调用**，不做别名 / 值流分析。）
 *
 * **四条硬规矩**（照 `tools/build-route-map.mjs` 的老规矩）：
 *   ① **零依赖、零子进程**：只用 `node:fs` / `node:path` / `node:url`；`main()` 返回结果不打印，
 *      其它工具可以直接 `import` 它（DSH 沙箱内子进程禁开 `pipe`）。
 *   ② **逐字节决定性**：文件里**不写生成时间**、不写随机数、不依赖文件系统枚举顺序
 *      （所有列表显式排序）→ 同一份源码 → 同一个字节序列 → `--check` 才有意义。
 *   ③ **口径纪律**：本工具**不加载、不执行** Godot（没有 `godot --headless`），
 *      所以一切数字都是「**静态扫描识别**」值，**不是**运行时真值；扫描范围与已知限制写在生成物抬头。
 *   ④ **不猜**：认不出的东西一律**记下来**而不是瞎填 —— 解不出的 `load(...)` 路径进
 *      `未解析资源路径`，找不到的锚点打 `—`，`class_name` 重复进 `审计().重复类名`。
 *
 * 用法：
 *   node godot/tools/build_godot_routemap.mjs             生成 / 覆盖三份文件（**违规时照样写**，见下）
 *   node godot/tools/build_godot_routemap.mjs --check     只校验是否同步（只读、绝不写；不同步 exit 1）
 *   node godot/tools/route_query.mjs <符号|文件路径>      从 JSON 里只取相关切片（不读整份 1.4 MB）
 *   import { main } from './godot/tools/build_godot_routemap.mjs'
 *     main({ check: true }) / main({ write: false }) / main() → { ok, 统计, violations, … }
 *
 * ★ **和 `tools/build-route-map.mjs` 的一处有意差别**：那边「ok = false 就绝不覆盖写生成物」；
 *   这边**发现分层违规时仍然覆盖写**（文档 §4 的「违规明细」表 + JSON 的 `violations[]` 就是
 *   给人看的证据，不写出来反而要靠人肉摸），**但退出码仍然是 1** —— 写盘与门禁两件事分开。
 *   审计通过 + `--check` 逐字节一致，两条都满足才算 `ok = true`。
 * ========================================================================== */
import { readFileSync, writeFileSync, existsSync, readdirSync, mkdirSync } from 'fs';
import { dirname, join, relative, sep } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const HERE = dirname(fileURLToPath(import.meta.url));
const GODOT = join(HERE, '..');            // godot/
const ROOT = join(GODOT, '..');            // mecha-autobattle/

/* ★ 主输出与 `Godot-AST依赖清单.json` **同目录**（`协作/架构/`）：不给 `docs/` 新增
 *   未列入 `tools/js_ref.mjs` 排除列表的路径，避免将来 `git add` 误收生成物。 */
export const 文档路径 = join(ROOT, '协作', '架构', 'Godot-RouteMap.md');
export const 明细路径 = join(ROOT, '协作', '架构', 'Godot-RouteMap-明细.md');
export const JSON路径 = join(ROOT, '协作', '架构', 'Godot-AST依赖清单.json');
export const 抬头 = '<!-- 自动生成：node godot/tools/build_godot_routemap.mjs · 严禁手改 -->';

/* ---- D3：索引页体积门禁（D1 口径的估算 token；**不是**分词器真值） ---- */
export const 索引TOKEN上限 = 8000;

/* ---- D2：规则 ⑤ 棘轮 ---- */
/** 「通用内核文件 → 势力文件」引用次数的**棘轮基线**。
 *  **只许往下调、不许往上改** —— 它守的是「势力逻辑不许再往内核里长」。
 *  初始值 213 = CodeReview 报告 §3 的实测值（`btl 76 + deck_flow 53 + calc 31 + setup 14 +
 *  deck_builder 13 + flow 9 + card_effects 8 + 其余 9`），本工具复算逐项一致才敢写死。
 *  ★ CR-2 Batch B：213 → **211**。`btl.gd` 把「ATX 势力牌 / 天人牌 / 职业牌」那几条重复门槛
 *  收进 `CardPlay` 后 76 → 74；`CardPlay` 本身那 27 次点名叫派发顺序表，登记进
 *  `规则五豁免文件`（与 `fac.gd` 同一类）。
 *  ★ CR-2 Batch D：211 → **182**。`calc / btl / card_play` 的势力 / 职业调用点全部改成
 *  `RuleHooks` 的汇总 / 连乘 / 广播 / 首中接口 —— `calc.gd` 31 → 13、`btl.gd` 74 → 63、
 *  `card_play.gd` 27 → **0**（出牌门槛顺序表整体搬进 `rule_hooks.gd`）；注册表文件
 *  （`fac.gd` / `rule_hooks.gd`）不计入 ⑤。 */
export const CORE_TO_FACTION_RATCHET_MAX = 120;

/* ---- D2：规则 ⑥ 豁免文件审计（注册表文件「表外」不许点名模块） ---- */
/** **职业模块文件**：与势力文件同属「模块」，但目录前缀不在 `势力文件前缀` 里（规则 ⑥ 一并审）。 */
export const 职业模块文件 = ['core/battle/class_cards.gd'];

/** 规则 ⑥ 的两个**豁免文件**与它们**允许点名模块**的区域（其余代码行 = 审计区）。
 *  · `rule_hooks.gd`：只允许在 `static var 顺序 := { … }` 这个**顺序表**里点名（派发顺序表是唯一登记处）；
 *  · `fac.gd`：允许 `const ORDER` 声明块 + `match 势力:` 块 + 以 `势力 ==` / `势力 in` 为条件的
 *    `if` / `elif` 块（这三样就是「分派表 / match 分派区」，见 `允许点模块行集()`）。
 *  区域一律**现扫源码**得出，不写死行号；区域内点名多少都行，区域外一个都不许有。 */
export const 规则六豁免文件 = [
  {
    文件: 'core/battle/rule_hooks.gd',
    允许区域: '`const` / `static var` 的 `{…}` `[…]` 声明块（= `顺序` 派发顺序表与按处理者映射表）',
  },
  {
    文件: 'core/battle/fac.gd',
    允许区域: '`const ORDER` 声明块 + `match 势力:` 块 + 条件里出现 `势力 ==` / `势力 in` 的 `if` / `elif` 块',
  },
];

/* ---- D2：规则 ⑦ 体积棘轮 ---- */
/** 单文件体积阈值：超过任一条就要拆（新文件进警告清单，既有文件进 `SIZE_RATCHET`）。 */
export const 体积行上限 = 1000;
export const 体积TOKEN上限 = 12000;

/** **体积棘轮**：每个文件的登记 token 上限**只许下降、不许上调**。
 *  登记口径：建表时（CR-3 Batch E）全仓所有 `行数 > 1,000` 或 `estTokens > 12,000` 的既有 `.gd`，
 *  按当时实测 `estTokens` 逐一登记（含 D1 拆分后的 `session/game_session.gd` = 15065）。
 *  任何一处上调都是「把大文件又养大了」，Reviewer 看 diff 直接拦；要改就先拆小再下调本表。 */
export const SIZE_RATCHET = {
  'core/battle/atx_duo.gd': 10431,
  'core/battle/atx_faction.gd': 10386,
  'core/battle/atx_three.gd': 21396,
  'core/battle/calc.gd': 18553,
  'core/battle/celestial_v01.gd': 32680,
  'core/battle/deck_flow.gd': 13416,
  'core/battle/fac_atx.gd': 7620,
  'core/battle/mithril_v03_cards.gd': 15910,
  'core/run/node_resolver.gd': 14253,
  'presentation/widgets/unit_card.gd': 8702,
  'session/game_session.gd': 14782,
  'tests/unit/test_atx_three_v01.gd': 19307,
  'tests/unit/test_celestial_v01.gd': 30588,
  'tests/unit/test_class_cards.gd': 13702,
  'tests/unit/test_class_heavy_cmd.gd': 12896,
  'tests/unit/test_cr2_pipelines.gd': 12334,
  'tests/unit/test_mithril_v03.gd': 17021,
  'tests/unit/test_presentation_smoke.gd': 14608,
  'tests/unit/test_run_map.gd': 17038,
  'tests/unit/test_session_flow.gd': 33587,
  'tests/unit/test_unit_deck_system.gd': 17483,
};

/* ---- D3：规则 ⑧ 注释占比棘轮 ---- */
/** 单文件注释占比阈值：生产代码（`core/` `session/` `presentation/`）> 15%、测试（`tests/**`）> 20% 即违规。 */
export const 注释行上限 = 0.15;
export const 注释行上限_测试 = 0.20;

/** **注释占比棘轮 = 登记清单（只有路径，没有数值）**：登记过的文件一旦注释占比 **> 本层阈值** 即 `violations`。
 *  登记口径（CR-4 Batch E 建表）：建表时全仓所有已达标的 `.gd`（`core/**` `session/**` `presentation/**` 按 15%，
 *  `tests/**` 按 20%），CR-4 Batch D 清理过的 7 个文件也在里面。
 *  ★ 语义（CR-4.1 修正）：登记的不是「当前占比上限」，而是「**这个文件必须一直待在阈值以内**」；
 *    上线后往里加注释是允许的，只要没越本层阈值。未登记的文件同样不许超阈值，只是先走 §0.5 警告清单（不判红）。 */
export const COMMENT_RATCHET = [
  'core/battle/atx_faction.gd',
  'core/battle/atx_three.gd',
  'core/battle/battle_log.gd',
  'core/battle/boss.gd',
  'core/battle/btl.gd',
  'core/battle/calc.gd',
  'core/battle/card_exec.gd',
  'core/battle/card_play.gd',
  'core/battle/card_pool.gd',
  'core/battle/celestial_v01.gd',
  'core/battle/deck_flow.gd',
  'core/battle/diff.gd',
  'core/battle/fac.gd',
  'core/battle/fac_atx.gd',
  'core/battle/fac_cb.gd',
  'core/battle/fac_mith.gd',
  'core/battle/fac_moon.gd',
  'core/battle/guard.gd',
  'core/battle/intent.gd',
  'core/battle/mithril_v03_cards.gd',
  'core/battle/morale.gd',
  'core/battle/phase_flow.gd',
  'core/battle/rule_hooks.gd',
  'core/battle/traits.gd',
  'core/battle/weapon_exec.gd',
  'presentation/battle/battle_animation_layer.gd',
  'presentation/battle/battle_fx_player.gd',
  'presentation/battle/battle_view.gd',
  'presentation/battle/board_panel.gd',
  'presentation/battle/deck_sidebar.gd',
  'presentation/battle/drag_aim.gd',
  'presentation/battle/hand_card_item.gd',
  'presentation/battle/hand_panel.gd',
  'presentation/battle/log_panel.gd',
  'presentation/widgets/unit_card.gd',
  'session/battle_deck_view.gd',
  'session/battle_flow.gd',
  'session/battle_hand_view.gd',
  'session/data_loader.gd',
  'session/display_helpers.gd',
  'session/game_session.gd',
  'session/live_monitor.gd',
  'session/roster_facade.gd',
  'session/run_facade.gd',
  'session/tooltip_text.gd',
  'tests/unit/layout_fixtures.gd',
  'tests/unit/test_atx_faction_v03.gd',
  'tests/unit/test_atx_godsbet_and_luck.gd',
  'tests/unit/test_atx_smoke.gd',
  'tests/unit/test_atx_three_v01.gd',
  'tests/unit/test_atx_v03_wiring.gd',
  'tests/unit/test_boundary.gd',
  'tests/unit/test_card_table_snapshot.gd',
  'tests/unit/test_celestial_v01.gd',
  'tests/unit/test_class_cards.gd',
  'tests/unit/test_class_heavy_cmd.gd',
  'tests/unit/test_cr2_pipelines.gd',
  'tests/unit/test_data.gd',
  'tests/unit/test_font_coverage.gd',
  'tests/unit/test_js_compat.gd',
  'tests/unit/test_layout_board.gd',
  'tests/unit/test_layout_drag.gd',
  'tests/unit/test_layout_flow.gd',
  'tests/unit/test_layout_hand.gd',
  'tests/unit/test_layout_log.gd',
  'tests/unit/test_layout_screens.gd',
  'tests/unit/test_layout_sidebar.gd',
  'tests/unit/test_layout_tooltip.gd',
  'tests/unit/test_layout_ux1.gd',
  'tests/unit/test_mithril_v03.gd',
  'tests/unit/test_presentation_layout.gd',
  'tests/unit/test_presentation_smoke.gd',
  'tests/unit/test_rng.gd',
  'tests/unit/test_run_core.gd',
  'tests/unit/test_run_map.gd',
  'tests/unit/test_session_flow.gd',
  'tests/unit/test_sub_deck.gd',
  'tests/unit/test_unit_deck_system.gd',
  'tests/unit/test_ux4_lineup_slots.gd',
];

/** 势力文件 = `core/battle/` 下命中这些前缀的 `.gd`（以 `_` 结尾的按前缀匹配，其余按整名匹配）。
 *  **不含注册表 `core/battle/fac.gd` 本身**。以后新增势力，把前缀加进这张表即可。 */
export const 势力文件前缀 = ['atx_', 'fac_atx', 'fac_cb', 'fac_mith', 'fac_moon',
  'celestial_', 'mithril_', 'colony_', 'colonial_', 'moon_', 'shadow_'];
export const 势力注册表文件 = 'core/battle/fac.gd';

/** D1 示范文件的**改前基线**（CR-1 之前，commit `2cd879e`；按本工具同一套口径实测）。
 *  改前的源码已经不在工作区了，所以这几个数是**固化的常量**，不随扫描变化 —— 只用来对照
 *  「同一公式下改前 / 改后差了多少 token」。 */
export const 示范改前 = [
  { 文件: 'core/battle/calc.gd', 提交: '2cd879e', 字节: 77877, estTokens: 23700, 注释占比: 0.310 },
  { 文件: 'core/battle/celestial_v01.gd', 提交: '2cd879e', 字节: 148828, estTokens: 45602, 注释占比: 0.171 },
];

export const 层们 = ['core', 'session', 'presentation', 'tests'];
export const 层标题 = {
  core: 'core · 内核（纯逻辑；不许认识 session / presentation）',
  session: 'session · 会话门面（界面唯一入口）',
  presentation: 'presentation · 表现层（只许经 GameSession 调内核）',
  tests: 'tests · 测试与黄金样例（可以认识所有层）',
  其他: '其他（不属于上面四层）',
};

/* ============================ 小工具 ============================ */
const lf = s => String(s).replace(/\r\n/g, '\n');
const 读文本 = p => lf(readFileSync(p, 'utf8'));
const 截 = (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + '…' : String(s));
const 逃 = s => String(s).replace(/\|/g, '\\|').replace(/\n/g, ' ');
const 折 = (前缀, 片段们, 宽 = 250) => {
  const 出 = []; let 行 = 前缀;
  for (const 片 of 片段们) {
    if (行 !== 前缀 && 行.length + 片.length + 1 > 宽) { 出.push(行); 行 = '  ' + 片; }
    else 行 += (行 === 前缀 ? '' : ' ') + 片;
  }
  if (行.trim()) 出.push(行);
  return 出;
};
const 层Of = 相对 => {
  const 头 = 相对.split('/')[0];
  return 层们.includes(头) ? 头 : '其他';
};

/* ============================ D1 体积：估算 token / 注释占比 ============================
 * **估算 token 口径**（CR-1 全单统一，和 `godot/README.md`「注释约定」同一句）：
 *     `token ≈ CJK 字符数 × 1.0 + 其余字符数 ÷ 3.5`
 *   CJK = 汉字 + 全角标点，判据是下面这条字符类（**按 Unicode 码点**数，一个码点算一个字符）：
 *     `/[\u2E80-\u9FFF\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFFEF\u3000-\u303F]/`
 *   这是**估算**（粗到能看见「这个文件要吃掉多少上下文」），不是任何分词器的真值。
 *
 * **注释占比口径**：
 *   分子 = 「以 `#` 开头的行（含前导空白后以 `#` 开头）」与「代码行尾 `# …`」的 **UTF-8 字节**合计；
 *   分母 = 文件总字节；**字符串字面量里的 `#` 不算**（先用同一套字符串状态机判「这个 `#` 在不在串里」）；
 *   行尾换行符不计。整行注释从**行首**算（含缩进），行尾注释从 `#` 算到行尾。
 * ========================================================================== */
const CJK类 = /[\u2E80-\u9FFF\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFFEF\u3000-\u303F]/u;

/** 源码体积 → { 字符数, cjk字符数, estTokens }。`源` 必须是 **LF 归一后**的文本（本工具统一口径）。 */
export function 量体积(源) {
  let 字 = 0, cjk = 0;
  for (const ch of 源) { 字++; if (CJK类.test(ch)) cjk++; }
  return { 字符数: 字, cjk字符数: cjk, estTokens: Math.round(cjk * 1.0 + (字 - cjk) / 3.5) };
}

/** 源码 → { 注释字节, 注释行数, 行尾注释行数, 占比 }（口径见上面那段注释）。 */
export function 量注释(源) {
  const 行们 = 源.split('\n');
  const n = 源.length;
  const 首井 = new Array(行们.length).fill(-1);
  let i = 0, 行号 = 0, 行首 = 0, 引 = '';
  while (i < n) {
    const c = 源[i];
    if (c === '\n') { if (引.length === 1) 引 = ''; 行号++; 行首 = i + 1; i++; continue; }
    if (引) {
      if (c === '\\') { i += 2; continue; }
      if (源.startsWith(引, i)) { i += 引.length; 引 = ''; continue; }
      i++; continue;
    }
    if (c === '"' || c === "'") { 引 = 源.startsWith(c + c + c, i) ? c + c + c : c; i += 引.length; continue; }
    if (c === '#') {
      首井[行号] = i - 行首;
      while (i < n && 源[i] !== '\n') i++;
      continue;
    }
    i++;
  }
  let 注释字节 = 0, 注释行数 = 0, 行尾注释行数 = 0;
  for (let k = 0; k < 行们.length; k++) {
    const idx = 首井[k];
    if (idx < 0) continue;
    const 前 = 行们[k].slice(0, idx);
    const 段 = 前.trim() === '' ? 行们[k] : 行们[k].slice(idx);
    注释字节 += Buffer.byteLength(段, 'utf8');
    if (前.trim() === '') 注释行数++; else 行尾注释行数++;
  }
  const 总 = Buffer.byteLength(源, 'utf8');
  return { 注释字节, 注释行数, 行尾注释行数, 占比: 总 ? 注释字节 / 总 : 0 };
}

const 百分比 = x => (x * 100).toFixed(1) + '%';

/* ---- D2 势力文件 / 通用内核文件的判定（**规则 ⑤ 的唯一口径**） ---- */
/** 规则 ⑤ 的**豁免文件**：本身**必须**点名势力 / 职业模块的「派发 · 判定注册表」。
 *  它们点名势力是设计上必须的 —— 收敛点就在这里，所以单列出来（仍打印次数），但不计入棘轮。
 *  · `core/battle/fac.gd` —— 势力特色注册表（17 个钩子）；
 *  · `core/battle/rule_hooks.gd` —— 规则钩子注册表（`顺序` 表；出牌门槛那一行
 *    `AtxGodsbet → AtxThree → AtxChips → CelestialV01 → AtxFaction → ClassCards → MithrilV03Cards`）。
 *    顺序表**以外**一个势力 / 职业模块名都不许出现（CR-3 Batch A：全部分派走 `首个结论`）。
 *  ★ 其它通用内核文件（含 `card_play.gd`）**不再豁免**：它们只许调 `RuleHooks` 的接口。 */
export const 规则五豁免文件 = [势力注册表文件, 'core/battle/rule_hooks.gd'];

export function 是势力文件(相对) {
  if (!相对.startsWith('core/battle/') || !相对.endsWith('.gd')) return false;
  const 基 = 相对.slice('core/battle/'.length, -3);
  if (基.includes('/')) return false;
  return 势力文件前缀.some(p => (p.endsWith('_') ? 基.startsWith(p) : 基 === p));
}

/** 通用内核 = `core/battle/` 下除势力文件与注册表 `fac.gd` 以外的 `.gd`，加上 `core/run/**` 全部 `.gd`。 */
export function 是通用内核文件(相对) {
  if (相对 === 势力注册表文件) return false;
  if (相对.startsWith('core/run/')) return true;
  if (!相对.startsWith('core/battle/')) return false;
  return !是势力文件(相对);
}

/** 规则 ⑤ 的**全部**数据：当前值 / 逐文件明细 / 势力→势力横向引用。与 CodeReview 报告 §3 同口径。
 *  ★ 注册表文件（`规则五豁免文件`）**照样算边、照样打印**，但归到 `豁免明细`、不计入 `总次数`。 */
export function 统计内核到势力(文件们) {
  const 势力文件们 = 文件们.filter(f => 是势力文件(f.相对)).map(f => f.相对).sort();
  const 势力集 = new Set(势力文件们);
  const 明细 = [];
  const 豁免明细 = [];
  let 总次数 = 0;
  for (const f of 文件们) {
    const 豁免 = 规则五豁免文件.includes(f.相对);
    if (!豁免 && !是通用内核文件(f.相对)) continue;
    const 边 = f.dependsOn.filter(e => 势力集.has(e.to));
    if (!边.length) continue;
    const 次数 = 边.reduce((a, e) => a + e.n, 0);
    if (豁免) {
      豁免明细.push({
        文件: f.相对, 势力文件数: 边.length, 次数,
        边: 边.map(e => ({ to: e.to, n: e.n, symbols: e.symbols })).sort((a, b) => b.n - a.n || (a.to < b.to ? -1 : 1)),
       });
      continue;
    }
    总次数 += 次数;
    明细.push({
      文件: f.相对, 势力文件数: 边.length, 次数,
      边: 边.map(e => ({ to: e.to, n: e.n, symbols: e.symbols })).sort((a, b) => b.n - a.n || (a.to < b.to ? -1 : 1)),
    });
  }
  明细.sort((a, b) => b.次数 - a.次数 || b.势力文件数 - a.势力文件数 || (a.文件 < b.文件 ? -1 : 1));
  豁免明细.sort((a, b) => (a.文件 < b.文件 ? -1 : 1));
  const 横向 = [];
  for (const f of 文件们) {
    if (!势力集.has(f.相对)) continue;
    for (const e of f.dependsOn) if (势力集.has(e.to)) 横向.push({ from: f.相对, to: e.to, n: e.n, symbols: e.symbols });
  }
  横向.sort((a, b) => (a.from < b.from ? -1 : a.from > b.from ? 1 : 0) || (a.to < b.to ? -1 : 1));
  return {
    总次数, 明细, 豁免明细, 势力文件们, 横向,
    通用文件数: 文件们.filter(f => 是通用内核文件(f.相对) && !规则五豁免文件.includes(f.相对)).length,
    基线: CORE_TO_FACTION_RATCHET_MAX,
    超过基线: 总次数 > CORE_TO_FACTION_RATCHET_MAX,
    低于基线: 总次数 < CORE_TO_FACTION_RATCHET_MAX,
  };
}

/* ============================ 规则 ⑥：豁免文件「表外」审计 ============================
 * 为什么要有这一条：规则 ⑤ 把 `fac.gd` / `rule_hooks.gd` 列为豁免（它们必须点名势力 / 职业模块）。
 * 豁免一旦没有边界，往 `rule_hooks.gd` 里塞一段「是不是某个势力」就绕过了 ⑤ ——
 * 所以再定一条：**两个注册表文件只在「登记表 / 分派区」里点名模块，区域外一个都不许有**。
 * ========================================================================== */
const 缩进数 = 行 => { let n = 0; for (const c of 行) { if (c === ' ' || c === '\t') n++; else break; } return n; };

/** 从起行往下找「括号配平」的结束行（`{`/`}`、`[`/`]`；单行声明返回起行本身）。 */
function 配平结束行(行们, 起, 开, 闭) {
  let 深 = 0;
  for (let i = 起; i < 行们.length; i++) {
    for (const c of 行们[i]) {
      if (c === 开) 深++;
      else if (c === 闭) { 深--; if (深 <= 0) return i; }
    }
  }
  return 行们.length - 1;
}

/** 从起行往下找「缩进退回」的结束行（GDScript 用缩进分块；空行不算结束）。 */
function 缩进结束行(行们, 起, 起缩进) {
  let 末 = 起;
  for (let i = 起 + 1; i < 行们.length; i++) {
    if (!行们[i].trim()) continue;
    if (缩进数(行们[i]) <= 起缩进) break;
    末 = i;
  }
  return 末;
}

/** **规则 ⑥ 的唯一判据**：算出这个文件里「允许点名势力 / 职业模块」的行号集合（0-based）。
 *  三类区域（全部现扫源码，不写死行号）：
 *    ① **登记表**：顶层 `const` / `static var` 声明里带 `{…}` 或 `[…]` 的块（`顺序` 表、`ORDER` 表、映射表）；
 *    ② **`match` 分派块**：`match …:` 到缩进退回的那一段（同一行写完的 `case: 语句` 也算块内）；
 *    ③ **条件式分派块**：条件里出现 `势力 ==` / `势力 in` 的 `if` / `elif` 块（含单行写法）。
 *  区域**外**的行 = 审计区：出现任何势力 / 职业模块名都算违规。 */
export function 允许点模块行集(代码) {
  const 行们 = 代码.split('\n');
  const 允许 = new Set();
  /* ① 登记表（花括号 / 方括号配平） */
  for (let i = 0; i < 行们.length; i++) {
    const 行 = 行们[i];
    if (缩进数(行) !== 0) continue;
    if (!/^(?:const|static\s+var)\b/.test(行)) continue;
    const 有花 = 行.includes('{'), 有方 = 行.includes('[');
    if (!有花 && !有方) continue;
    const 末 = 有花 ? 配平结束行(行们, i, '{', '}') : 配平结束行(行们, i, '[', ']');
    for (let k = i; k <= 末; k++) 允许.add(k);
    i = Math.max(i, 末);
  }
  /* ②③ 分派块（缩进配平） */
  for (let i = 0; i < 行们.length; i++) {
    const 行 = 行们[i].replace(/\s+$/, '');
    const 起头 = 行.trim();
    const 是match = /^match\b/.test(起头);
    const 是势力条件 = /^(?:if|elif)\b/.test(起头) && /势力\s*(?:==|in)(?:\s|$)/.test(起头);
    if (!是match && !是势力条件) continue;
    const 末 = 起头.endsWith(':') ? 缩进结束行(行们, i, 缩进数(行)) : i;   // 单行写法只覆盖本行
    for (let k = i; k <= 末; k++) 允许.add(k);
    i = Math.max(i, 末);
  }
  return 允许;
}

/** 扫一个文件里**代码行**（注释与字符串已抹）出现的模块名 → `[{行, 模块们}]`。 */
export function 扫模块引用(文件, 模块类名集) {
  const 出 = [];
  const 行们 = (文件.代码 || '').split('\n');
  for (let i = 0; i < 行们.length; i++) {
    const 令们 = 行们[i].match(/[\p{L}_][\p{L}\p{N}_]*/gu);
    if (!令们) continue;
    const 见 = new Set();
    for (const t of 令们) if (模块类名集.has(t)) 见.add(t);
    if (见.size) 出.push({ 行: i + 1, 模块们: [...见].sort() });
  }
  return 出;
}

/** 规则 ⑥ 的全量数据：两个豁免文件各自的「区域内 / 区域外」引用与违规。 */
export function 审计豁免文件(文件们) {
  const 模块表 = new Map();      // 类名 → 文件（只收势力文件 + 职业模块文件）
  for (const f of 文件们) {
    if (!f.类名) continue;
    if (是势力文件(f.相对) || 职业模块文件.includes(f.相对)) 模块表.set(f.类名, f.相对);
  }
  const 模块类名集 = new Set(模块表.keys());
  const 明细 = [], 违规 = [];
  for (const 规则 of 规则六豁免文件) {
    const f = 文件们.find(x => x.相对 === 规则.文件);
    if (!f) {
      违规.push({
        rule: '⑥', 类型: '豁免文件不存在', from: 规则.文件, to: '—', symbols: [], n: 1,
        说明: `规则 ⑥ 要审的注册表文件 ${规则.文件} 不在扫描结果里`,
      });
      continue;
    }
    const 允许 = 允许点模块行集(f.代码);
    const 引用 = 扫模块引用(f, 模块类名集);
    const 区内 = 引用.filter(r => 允许.has(r.行 - 1));
    const 区外 = 引用.filter(r => !允许.has(r.行 - 1));
    明细.push({
      文件: 规则.文件, 允许区域: 规则.允许区域, 允许行数: 允许.size,
      引用行数: 引用.length, 区内行数: 区内.length, 区外行数: 区外.length,
      区外明细: 区外, 区内模块们: [...new Set(区内.flatMap(r => r.模块们))].sort(),
    });
    for (const r of 区外) {
      违规.push({
        rule: '⑥', 类型: '豁免文件 → 势力/职业模块（表外引用）',
        from: 规则.文件, to: 模块表.get(r.模块们[0]) || '—',
        symbols: r.模块们.map(m => `${m}（第 ${r.行} 行）`), n: r.模块们.length,
        说明: `${规则.文件}:${r.行} 在允许区域（${规则.允许区域}）**之外**点名了 ${r.模块们.join(' / ')}：注册表只许在登记表 / 分派区里点名模块`,
      });
    }
  }
  return {
    明细, 违规, 模块类名们: [...模块类名集].sort(), 模块文件们: [...模块表.values()].sort(),
    违规数: 违规.length,
  };
}

/* ============================ 规则 ⑦：体积棘轮 ============================ */
/** 规则 ⑦ 的全量数据：`SIZE_RATCHET` 逐条对照 + 未登记的新大文件警告。 */
export function 统计体积棘轮(文件们) {
  const 表 = new Map(文件们.map(f => [f.相对, f]));
  const 已登记 = [], 已不存在 = [], 违规 = [], 警告 = [];
  for (const 路径 of Object.keys(SIZE_RATCHET).sort()) {
    const 上限 = SIZE_RATCHET[路径];
    const f = 表.get(路径);
    if (!f) { 已不存在.push({ 路径, 上限 }); continue; }
    const 超 = f.estTokens > 上限;
    已登记.push({ 路径, 上限, 当前: f.estTokens, 行数: f.行数, 余量: 上限 - f.estTokens, 超 });
    if (超) {
      违规.push({
        rule: '⑦', 类型: '体积棘轮：登记文件的 token 上限只许下降',
        from: 路径, to: `SIZE_RATCHET 登记上限 ${上限} token`,
        symbols: [`当前 ${f.estTokens} token（超 ${f.estTokens - 上限}）`], n: f.estTokens - 上限,
        说明: `${路径} 当前估算 ${f.estTokens} token > 登记上限 ${上限}：先把文件拆小再下调本表，不许上调上限`,
      });
    }
  }
  for (const f of 文件们) {
    if (Object.prototype.hasOwnProperty.call(SIZE_RATCHET, f.相对)) continue;
    const 超行 = f.行数 > 体积行上限, 超token = f.estTokens > 体积TOKEN上限;
    if (超行 || 超token) 警告.push({ 路径: f.相对, 行数: f.行数, estTokens: f.estTokens, 超行, 超token });
  }
  已登记.sort((a, b) => b.当前 - a.当前 || (a.路径 < b.路径 ? -1 : 1));
  已不存在.sort((a, b) => (a.路径 < b.路径 ? -1 : 1));
  警告.sort((a, b) => b.estTokens - a.estTokens || (a.路径 < b.路径 ? -1 : 1));
  return {
    违规, 警告, 已登记, 已不存在,
    行上限: 体积行上限, token上限: 体积TOKEN上限,
    登记数: 已登记.length, 登记合计上限: 已登记.reduce((a, x) => a + x.上限, 0),
    超限数: 已登记.filter(x => x.超).length, 警告数: 警告.length,
  };
}

/* ============================ 规则 ⑧：注释占比棘轮 ============================
 * **语义（CR-4.1 修正）**：`COMMENT_RATCHET` 是**登记清单（只有路径、没有数值）**，判据 = **本层阈值**
 * （生产 `core/ session/ presentation/` 15% / 测试 `tests/**` 20%）。登记过 ≠ 冻结当前占比：
 * 只要没越本层阈值，往里加注释是允许的；越了阈值就判红。
 * 未登记的文件同样不许超阈值，只是先走 RouteMap §0.5 的警告清单（不判红）—— 两个通道的判据是同一把尺。
 * ========================================================================== */
/** 规则 ⑧ 的全量数据：`COMMENT_RATCHET` 登记文件的本层阈值对照 + 未登记且超阈值的警告清单。 */
export function 统计注释棘轮(文件们) {
  const 表 = new Map(文件们.map(f => [f.相对, f]));
  const 登记集 = new Set(COMMENT_RATCHET);
  const 已登记 = [], 已不存在 = [], 违规 = [], 警告 = [];
  const 阈值 = (f) => (f.层 === 'tests' ? 注释行上限_测试 : 注释行上限);
  const 层名 = (f) => (f.层 === 'tests' ? 'tests' : '生产代码');
  const 百分比2 = (x) => (x * 100).toFixed(2) + '%';
  for (const 路径 of [...登记集].sort()) {
    const f = 表.get(路径);
    if (!f) { 已不存在.push({ 路径 }); continue; }
    const 限 = 阈值(f);
    const 超 = f.注释占比 > 限;
    已登记.push({
      路径, 层: f.层, 阈值: 限, 占比: f.注释占比, 注释字节: f.注释字节, 行数: f.行数,
      余量字节: Math.floor(限 * f.字节) - f.注释字节, 超,
    });
    if (超) {
      违规.push({
        rule: '⑧', 类型: '注释占比棘轮：登记文件不许超过本层阈值',
        from: 路径, to: `本层阈值 ${百分比(限)}（${层名(f)}）`,
        symbols: [`当前 ${百分比2(f.注释占比)}（超 ${百分比2(f.注释占比 - 限)}）`],
        n: Math.round((f.注释占比 - 限) * 10000),
        说明: `${路径} 注释占比 ${百分比2(f.注释占比)} 超过本层 ${百分比(限)} 阈值：这个文件已登记进 COMMENT_RATCHET，先把注释清回阈值以内`,
      });
    }
  }
  for (const f of 文件们) {
    if (登记集.has(f.相对)) continue;
    const 限 = 阈值(f);
    if (f.注释占比 > 限) 警告.push({ 路径: f.相对, 层: f.层, 阈值: 限, 占比: f.注释占比, 注释字节: f.注释字节, 行数: f.行数 });
  }
  已登记.sort((a, b) => b.占比 - a.占比 || (a.路径 < b.路径 ? -1 : 1));
  已不存在.sort((a, b) => (a.路径 < b.路径 ? -1 : 1));
  警告.sort((a, b) => b.占比 - a.占比 || (a.路径 < b.路径 ? -1 : 1));
  return {
    违规, 警告, 已登记, 已不存在,
    行上限: 注释行上限, 测试行上限: 注释行上限_测试,
    登记数: 已登记.length, 超限数: 已登记.filter(x => x.超).length, 警告数: 警告.length,
  };
}

/* ============================ ① 扫文件 ============================ */
/** 递归收 `godot/` 下的 `.gd`，**跳过所有点开头的目录**（`.godot/` 缓存、`.git/` …）。
 *  返回**相对 godot/ 的 POSIX 路径**并显式排序 —— 输出要逐字节决定性，不能靠 readdir 的顺序。 */
export function 扫gd文件(根 = GODOT) {
  const 出 = [];
  const 走 = (目录) => {
    let 项们;
    try { 项们 = readdirSync(目录, { withFileTypes: true }); } catch { return; }
    项们.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    for (const 项 of 项们) {
      if (项.name.startsWith('.')) continue;          // .godot 缓存 / .git / .import
      const 全 = join(目录, 项.name);
      if (项.isDirectory()) 走(全);
      else if (项.isFile() && 项.name.endsWith('.gd')) 出.push(relative(根, 全).split(sep).join('/'));
    }
  };
  走(根);
  return 出.sort();
}

/* ============================ ② 词法：抹掉注释与字符串 ============================
 * GDScript：`#` 到行尾是注释；`"…"` / `'…'` / `"""…"""` / `'''…'''` 是字符串。
 * 抹成**空格**（换行原样保留）→ 之后的「标识符精确匹配」不会被注释里的
 * `GameSession` 或字符串里的路径污染。**这不是完整词法分析**，只保证在本仓库的
 * 代码风格下把「注释 / 字符串」与「代码」分开（已知限制写进生成物抬头）。
 * ========================================================================== */
export function 去注释与字符串(源) {
  const 出 = 源.split('');
  const n = 源.length;
  let i = 0;
  while (i < n) {
    const c = 源[i];
    if (c === '#') {
      while (i < n && 源[i] !== '\n') { 出[i] = ' '; i++; }
      continue;
    }
    if (c === '"' || c === "'") {
      const 引 = (源.startsWith(c + c + c, i)) ? c + c + c : c;
      let j = i + 引.length;
      while (j < n) {
        if (源[j] === '\\') { j += 2; continue; }
        if (源.startsWith(引, j)) { j += 引.length; break; }
        if (引.length === 1 && 源[j] === '\n') break;     // 未闭合的单行字符串：止于行尾
        j++;
      }
      for (let k = i; k < Math.min(j, n); k++) if (源[k] !== '\n') 出[k] = ' ';
      i = j; continue;
    }
    i++;
  }
  return 出.join('');
}

/** 只抹注释、**保留字符串**（与上面同一套逐字符 1:1 回填：列号与换行都不变）。
 *  用途：`preload/load` 与 `const 路径 := "res://…"` 的**字面量**要读，注释里的示例路径要排除。 */
export function 去注释(源) {
  const 出 = 源.split('');
  const n = 源.length;
  let i = 0;
  while (i < n) {
    const c = 源[i];
    if (c === '#') { while (i < n && 源[i] !== '\n') { 出[i] = ' '; i++; } continue; }
    if (c === '"' || c === "'") {
      const 引 = (源.startsWith(c + c + c, i)) ? c + c + c : c;
      let j = i + 引.length;
      while (j < n) {
        if (源[j] === '\\') { j += 2; continue; }
        if (源.startsWith(引, j)) { j += 引.length; break; }
        if (引.length === 1 && 源[j] === '\n') break;
        j++;
      }
      i = j; continue;
    }
    i++;
  }
  return 出.join('');
}

/** 一段源码的**首个种类行**（`class_name` / `extends`）→ {名, 行}；没有就 null。 */
function 取头部声明(代码, 正则, 行偏移 = 0) {
  const m = 正则.exec(代码);
  if (!m) return null;
  const 行 = 代码.slice(0, m.index).split('\n').length + 行偏移;
  return { 名: m[1], 行 };
}

/** 从第 i 行开始拼一条 `func` 签名（跨行参数表也认），返回 {文本, 结束行下标}。
 *  **判据（不用行尾正则，单行函数体也认）**：从 `func` 行第一个 `(` 起数字符，
 *  括号深度**回到 0 之后**遇到的第一个 `:` 就是函数头结束 ——
 *  `static func KIND_MELEE() -> String: return Db.T.KIND_MELEE` 这种**一行写完**的
 *  函数会当场收住，不会把下一行 `func` 一起吞掉（这是第一版漏掉 58 个函数的原因）。
 *  `去注释与字符串()` 是**逐字符 1:1** 回填空格，所以列号可直接拿去切**原文**。 */
function 取签名(代码行们, 原行们, i) {
  const 起 = 代码行们[i].indexOf('(');
  let 深 = 0, 见左 = false, 结束行 = i, 结束列 = -1;
  for (let 行号 = i; 行号 < 代码行们.length && 行号 - i <= 10; 行号++) {
    const 行 = 代码行们[行号];
    for (let c = (行号 === i ? (起 < 0 ? 0 : 起) : 0); c < 行.length; c++) {
      const ch = 行[c];
      if (ch === '(') { 深++; 见左 = true; }
      else if (ch === ')') { 深--; }
      else if (见左 && 深 === 0 && ch === ':') { 结束行 = 行号; 结束列 = c; break; }
    }
    if (结束列 >= 0) break;
    结束行 = 行号;
  }
  let 文本;
  if (结束列 >= 0 && 结束行 === i) 文本 = 原行们[i].slice(0, 结束列);
  else if (结束列 >= 0) {
    const 段 = 原行们.slice(i, 结束行 + 1);
    段[段.length - 1] = 段[段.length - 1].slice(0, 结束列);
    文本 = 段.join(' ');
  } else 文本 = 原行们.slice(i, Math.min(结束行, 原行们.length - 1) + 1).join(' ');
  return { 文本: 文本.replace(/\s+/g, ' ').trim(), 结束行下标: 结束行 };
}

/* ============================ ③ 单文件解析（AST / 符号级） ============================ */
/** 解析一个 `.gd` 文件 → { 相对, 层, 行数, 字节, 字符数, cjk字符数, estTokens,
 *                           注释字节, 注释占比, 注释行数, 行尾注释行数,
 *                           类名, 父类, 常量[], 函数[], 职责 }。
 *  `常量` / `函数` 只收**顶格**声明（`^const` / `^(static )?func`）——
 *  内层 `class X:` 里的缩进成员不算这个文件的导出面（另行统计 `内类数`）。 */
export function 解析gd(相对, 源) {
  const 代码 = 去注释与字符串(源);
  const 行们 = 源.split('\n');
  const 代码行们 = 代码.split('\n');
  const 总行数 = 行们.length - (行们[行们.length - 1] === '' ? 1 : 0);

  const 类 = 取头部声明(代码, /^class_name\s+([A-Za-z_][A-Za-z0-9_]*)/m);
  const 父 = 取头部声明(代码, /^extends\s+([A-Za-z_][A-Za-z0-9_]*)/m);

  const 常量 = [];
  const 函数 = [];
  for (let i = 0; i < 代码行们.length; i++) {
    const 行 = 代码行们[i];
    const m常 = /^const\s+([\p{L}_][\p{L}\p{N}_]*)/u.exec(行);
    if (m常) { 常量.push({ 名: m常[1], 行: i + 1, 注: 前注释(行们, i) }); continue; }
    const m函 = /^(static\s+)?func\s+([\p{L}_][\p{L}\p{N}_]*)/u.exec(行);
    if (m函) {
      const { 文本, 结束行下标 } = 取签名(代码行们, 行们, i);
      const m返 = /->\s*([\p{L}_][\p{L}\p{N}_]*(?:\[\])?(?:\s*<[^>]*>)?)\s*$/u.exec(文本);
      函数.push({
        名: m函[2],
        行: i + 1,
        static: !!m函[1],
        签名: 截(文本, 220),
        返回: m返 ? m返[1] : '',
        注: 前注释(行们, i),
      });
      i = 结束行下标;
    }
  }
  const 职责 = 截(首文档行(行们), 60);
  const 体积 = 量体积(源);
  const 注释 = 量注释(源);
  return {
    相对,
    层: 层Of(相对),
    行数: 总行数,
    字节: Buffer.byteLength(源, 'utf8'),
    字符数: 体积.字符数,
    cjk字符数: 体积.cjk字符数,
    estTokens: 体积.estTokens,
    注释字节: 注释.注释字节,
    注释占比: 注释.占比,
    注释行数: 注释.注释行数,
    行尾注释行数: 注释.行尾注释行数,
    类名: 类 ? 类.名 : '',
    类名行: 类 ? 类.行 : null,
    父类: 父 ? 父.名 : '',
    父类行: 父 ? 父.行 : null,
    常量,
    函数,
    内类数: (代码.match(/^class\s+[\p{L}_]/gmu) || []).length,
    职责,
    代码,
    源_去注释: 去注释(源),
  };
}

/** 文件第一行 `## …` → 职责一句话（去 `##`、去 `★ 前缀` 保留原文，截断）。 */
function 首文档行(行们) {
  for (let i = 0; i < Math.min(行们.length, 6); i++) {
    const t = 行们[i].trim();
    if (!t.startsWith('##')) continue;
    const 文 = t.replace(/^#+\s*/, '').trim();
    if (文) return 文;
  }
  return '';
}

/** 声明行上方紧邻的 `##` 注释（最多往回找 3 行）→ 一句话说明。 */
function 前注释(行们, i) {
  for (let k = i - 1; k >= 0 && k >= i - 3; k--) {
    const t = (行们[k] || '').trim();
    if (!t) break;
    if (t.startsWith('##')) return 截(t.replace(/^#+\s*/, '').replace(/\*\*/g, ''), 70);
    if (t.startsWith('#') || !t.startsWith('#')) break;
  }
  return '';
}

/* ============================ ④ 依赖边 ============================
 * 两条来源：
 *   ① **符号级**：标识符 token 里出现别的文件的 `class_name`（`Calc.dmgCore(...)` /
 *      `extends RefCounted` / `is Calc` 都算）—— 先词法抹掉注释与字符串，再**整词精确匹配**；
 *   ② **资源级**：`preload("res://…")` / `load("res://…")` 的**字面量**路径
 *      （变量路径 `load(p)` 认不出 → 进 `未解析资源路径`，不猜）。
 * ========================================================================== */
/** `class_name → 文件` 注册表（**同名只认第一个**，重复会在 `审计().重复类名` 里报出来）。 */
export function 建类索引(文件表) {
  const 索引 = new Map();
  for (const f of 文件表) if (f.类名 && !索引.has(f.类名)) 索引.set(f.类名, f);
  return 索引;
}

export function 取引用(文件, 类索引) {
  const 令牌 = 文件.代码.match(/[\p{L}_][\p{L}\p{N}_]*/gu) || [];
  const 计 = new Map();
  for (const t of 令牌) {
    if (!类索引.has(t)) continue;
    const 目标 = 类索引.get(t);
    if (目标.相对 === 文件.相对) continue;      // 自引用不算依赖
    计.set(t, (计.get(t) || 0) + 1);
  }
  return 计;
}

/** 扫**代码里**（注释已抹掉、字符串保留）的 `res://…` 路径字面量：
 *  `preload("res://…")` / `load("res://…")` / `const BOOT_GD := "res://…"` 一网打尽。
 *  三类分开记（**不猜**）：`.gd` 且被扫到 → 依赖边；`.gd` 但找不到 → `未解析`；
 *  带扩展名的其他资源（`.tscn` / `.ttf` / `.json`）→ `非gd`；没有扩展名的（`res://data/js`）→ `目录`。 */
export function 取资源引用(源去注释, 文件集合) {
  const 已解析 = [], 未解析 = [], 非gd = [], 目录 = [];
  const 正则 = /"(res:\/\/[^"\n]+)"/g;
  let m;
  while ((m = 正则.exec(源去注释))) {
    const 路径 = m[1];
    const 末段 = 路径.slice(7).split('/').pop() || '';
    if (路径.endsWith('.gd')) {
      const 相对 = 路径.slice(6);
      if (!文件集合.has(相对)) { 未解析.push({ 路径, 原因: '不在扫描范围内（文件不存在或已被排除）' }); continue; }
      已解析.push({ 路径, 目标: 相对 });
      continue;
    }
    if (末段.includes('.')) 非gd.push(路径);
    else 目录.push(路径);
  }
  return { 已解析, 未解析, 非gd, 目录 };
}

/** 把「符号引用」与「资源引用」合并成 `dependsOn[]`（每个目标文件一条，带 n / symbols / kinds）。 */
export function 建依赖(文件们, 类索引, 文件集合) {
  const 未解析们 = [], 非gd们 = [], 目录们 = [];
  for (const f of 文件们) {
    const 边 = new Map();
    const 收 = (目标, 符号, 种类, n = 1) => {
      if (!边.has(目标)) 边.set(目标, { to: 目标, n: 0, symbols: [], kinds: [] });
      const e = 边.get(目标);
      e.n += n;
      if (!e.symbols.includes(符号)) e.symbols.push(符号);
      if (!e.kinds.includes(种类)) e.kinds.push(种类);
    };
    for (const [符号, n] of [...取引用(f, 类索引)].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
      const 目标 = 类索引.get(符号).相对;
      const 种类 = (f.父类 === 符号) ? '继承' : '类引用';
      收(目标, 符号, 种类, n);
    }
    const { 已解析, 未解析, 非gd, 目录 } = 取资源引用(f.源_去注释 || '', 文件集合);
    for (const r of 已解析) 收(r.目标, r.路径, 'preload/load');
    for (const r of 未解析) 未解析们.push({ from: f.相对, ...r });
    for (const p of 非gd) 非gd们.push({ from: f.相对, 路径: p });
    for (const p of 目录) 目录们.push({ from: f.相对, 路径: p });
    f.dependsOn = [...边.values()].sort((a, b) => (a.to < b.to ? -1 : a.to > b.to ? 1 : 0));
    for (const e of f.dependsOn) e.layer = 层Of(e.to);
  }
  return { 未解析: 未解析们, 非gd: 非gd们, 目录: 目录们 };
}

/* ============================ ⑤ 调用点（`类名.函数名(`） ============================ */
/** 全仓扫 `Class.func(` → Map(`Class.func` → Map(调用文件 → 次数))。
 *  这是「关键公开函数」的**排名依据**，也是 §4 第 ④ 条审计的证据来源。 */
export function 扫调用点(文件们, 类索引) {
  const 名们 = [...类索引.keys()].sort((a, b) => b.length - a.length || (a < b ? -1 : 1));
  if (!名们.length) return new Map();
  const 正则 = new RegExp(
    '(?<![\\p{L}\\p{N}_.])(' + 名们.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') +
    ')\\.([\\p{L}_][\\p{L}\\p{N}_]*)\\s*\\(', 'gu');
  const 表 = new Map();
  for (const f of 文件们) {
    let m;
    正则.lastIndex = 0;
    while ((m = 正则.exec(f.代码))) {
      const 键 = m[1] + '.' + m[2];
      if (!表.has(键)) 表.set(键, new Map());
      const 内 = 表.get(键);
      内.set(f.相对, (内.get(f.相对) || 0) + 1);
    }
  }
  return 表;
}

/* ============================ ⑥ 架构分层违规自检 ============================
 * 七条规则（`violations` 必须为空才算合规）：
 *   ① core → session           ② core → presentation
 *   ③ session → presentation
 *   ④ presentation → core/battle 的**写接口**（绕过 GameSession）
 *   ⑤ **通用内核文件 → 势力文件**的引用次数 ≤ `CORE_TO_FACTION_RATCHET_MAX`（棘轮，只许下调）
 *   ⑥ 两个豁免注册表文件（`fac.gd` / `rule_hooks.gd`）在**登记表 / 分派区之外**对势力 / 职业模块的引用 = 0
 *   ⑦ `SIZE_RATCHET` 登记过的既有大文件，`estTokens` 只许下降（超过登记值即违规）
 *   ⑧ `COMMENT_RATCHET` 登记的清单文件，注释占比必须一直待在**本层阈值**以内（生产 15% / 测试 20%；
 *      登记表只有路径、不记数值；未登记且超阈值的只进 §0.5 警告，不判红）
 *
 * ④ 的判定口径（**只认直接静态调用** `类名.函数名(`，不做别名 / 值流 / 反射分析）：
 *   · 目标类必须声明在 `core/battle/**`；
 *   · 被调函数名的**第一个字**命中 `写动词`（或整名命中 `写接口白名单`）→ 视为写接口。
 *   读接口（`Fm.slotOf` / `Params.*` 取值 / `Ai.isUltimate` / `Boss.bossAction` 纯计算…）
 *   **不算违规**，但会在 §4 里全部列出来当**审计证据**。
 * ========================================================================== */
const 写动词 = ['设', '加', '记', '应用', '执行', '打', '发', '抽', '弃', '洗', '放', '扣', '消耗', '推进',
  '开', '切', '置', '移除', '删', '同步', '更新', '重置', '初始化', '注册', '触发', '增', '减', '改',
  '清', '存', '写', '赋', '补', '回', '挂', '刷', '禁', '派', '拿', '用', '移', '累加'];
const 写接口白名单 = new Set(['pushLog', 'resolveAttack', 'apply_on_battle_start', 'auto_play_unit_main_weapon',
  'auto_play_unit_weapon', 'execute', 'execute_ops', 'bossTurn']);

export function 是写接口(名) {
  if (写接口白名单.has(名)) return true;
  return 写动词.includes(名[0]);
}

/** 层间「豁免」白名单（**唯一的、写死在这里、并在生成物里明示**的反向依赖例外）。
 *  目前的证据只有一条：`session/game_session.gd` 在拼「卡 / 藏品 / Boss / 零件」的提示文本时
 *  复用 `UiTheme.文本()` —— 它是**纯格式化函数**（数字 → 千分位文本，无状态、不建节点、
 *  不碰 `Control`），共用它不等于「会话反向依赖表现层」。
 *  ★ 纪律：这张表**只许加行、不许放宽到文件级**（必须写明 `to` + `理由`），
 *    而且每次都要在 `协作/架构/Godot-RouteMap.md` §4.2 里被引用 —— 想绕过就用 `GameSession` 自己的口子。 */
const 层间豁免 = [
  { from: 'session/game_session.gd', to: 'presentation/theme/ui_theme.gd', 理由: '复用纯格式化函数 `UiTheme.文本()`（数字→千分位文本；无状态、不建节点、不碰 Control），不是反向依赖画面' },
];

export function 审计(文件们, 类索引, 调用表) {
  const violations = [];
  const 豁免 = [];
  const 按类名 = new Map();
  for (const [名, f] of 类索引) 按类名.set(名, f);
  /* ①②③ 层间反向依赖（`层间豁免` 里登记过的 (from, to) 不算违规，但要单独列证据） */
  const 规则名 = { 'core→session': '①', 'core→presentation': '②', 'session→presentation': '③' };
  for (const f of 文件们) {
    if (!['core', 'session'].includes(f.层)) continue;
    for (const e of f.dependsOn) {
      const 键 = `${f.层}→${e.layer}`;
      if (!规则名[键]) continue;
      const 白 = 层间豁免.find(x => x.from === f.相对 && x.to === e.to);
      if (白) {
        const 用到的 = [];
        for (const [调用键] of 调用表) {
          const 类名 = 调用键.slice(0, 调用键.lastIndexOf('.'));
          const 声明 = 按类名.get(类名);
          if (!声明 || 声明.相对 !== e.to) continue;
          const 内 = 调用表.get(调用键);
          if (内.has(f.相对)) 用到的.push(`${调用键}×${内.get(f.相对)}`);
        }
        豁免.push({ rule: 规则名[键], from: f.相对, to: e.to, symbols: e.symbols, n: e.n, 理由: 白.理由, 实际调用: 用到的.sort() });
        continue;
      }
      violations.push({
        rule: 规则名[键], 类型: 键, from: f.相对, to: e.to,
        symbols: e.symbols, n: e.n,
        说明: `${f.层}/ 反向依赖 ${e.layer}/`,
      });
    }
  }

  /* ④ presentation → core 写接口（只看直接静态调用）
   * ★ 任务书点名的重点是 `core/battle/**`；本工具按 **`core/**` 全量**查（更严），
   *   实测表现层对 core/data、core/run 的调用也全是查询（价格 / 信息 / 几何 / 模板），
   *   所以 `violations` 依然为空 —— 这条比任务书的要求多查了一层，不是放水。 */
  const 只读调用 = [];
  for (const [键, 调用者们] of [...调用表.entries()].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
    const [类名, 函数名] = [键.slice(0, 键.lastIndexOf('.')), 键.slice(键.lastIndexOf('.') + 1)];
    const 声明 = 按类名.get(类名);
    if (!声明 || !声明.相对.startsWith('core/')) continue;
    const 写 = 是写接口(函数名);
    for (const [调用文件, n] of [...调用者们.entries()].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
      if (层Of(调用文件) !== 'presentation') continue;
      if (写) {
        violations.push({
          rule: '④', 类型: 'presentation→core 写接口',
          from: 调用文件, to: 声明.相对, symbols: [`${类名}.${函数名}`], n,
          说明: `表现层绕过 GameSession 直接调内核写接口 ${类名}.${函数名}()`,
        });
      } else {
        只读调用.push({ 调用方: 调用文件, 目标: 声明.相对, 符号: `${类名}.${函数名}`, n });
      }
    }
  }

  /* ⑤ 通用内核文件 → 势力文件：**棘轮**（只许往下调）。
   * 这类耦合全在 `core/` 内部，①②③④ 一条都看不见；口径与 CodeReview 报告 §3 完全一致：
   * 次数 = 该通用文件 `dependsOn` 里指向**势力文件**的那些边的 `n`（符号出现次数）之和。 */
  const 内核势力 = 统计内核到势力(文件们);
  if (内核势力.超过基线) {
    violations.push({
      rule: '⑤', 类型: '通用内核→势力文件 引用棘轮',
      from: '通用内核（core/battle 非势力 + core/run）',
      to: `势力文件 ${内核势力.势力文件们.length} 个`,
      symbols: 内核势力.明细.map(x => `${x.文件}(${x.次数})`),
      n: 内核势力.总次数,
      说明: `当前 ${内核势力.总次数} 次 > 棘轮基线 ${CORE_TO_FACTION_RATCHET_MAX} 次：新增的势力逻辑只能走 Fac 注册表，基线不许上调`,
    });
  }

  /* ⑥ 豁免文件审计：注册表文件「表外」不许点名势力 / 职业模块。
   * 这一条专门堵规则 ⑤ 的口子 —— ⑤ 豁免了 `fac.gd` / `rule_hooks.gd`，若不给豁免划边界，
   * 往注册表里搬一段点名代码就能让 ⑤ 的数字变好看（CR-3 §5 的原话）。 */
  const 豁免审计 = 审计豁免文件(文件们);
  violations.push(...豁免审计.违规);

  /* ⑦ 体积棘轮：登记过的既有大文件只许变小；未登记的新大文件进警告清单（不判红）。 */
  const 体积 = 统计体积棘轮(文件们);
  violations.push(...体积.违规);

  /* ⑧ 注释占比棘轮：登记清单里的文件必须一直待在**本层阈值**以内；未登记且超阈值的进 §0.5 警告（不判红）。 */
  const 注释 = 统计注释棘轮(文件们);
  violations.push(...注释.违规);

  /* 信息项（不算违规）：重复类名 / 自依赖 / 双向依赖对 / 未解析资源路径 */
  const 重复类名 = [];
  {
    const 见 = new Map();
    for (const f of 文件们) if (f.类名) {
      if (见.has(f.类名)) 重复类名.push({ 类名: f.类名, 文件们: [见.get(f.类名), f.相对] });
      else 见.set(f.类名, f.相对);
    }
  }
  const 双向 = [];
  const 有边 = new Set();
  for (const f of 文件们) for (const e of f.dependsOn) 有边.add(f.相对 + '→' + e.to);
  for (const 键 of [...有边].sort()) {
    const [a, b] = 键.split('→');
    if (a < b && 有边.has(b + '→' + a)) 双向.push([a, b]);
  }
  const 自环 = 文件们.filter(f => f.dependsOn.some(e => e.to === f.相对)).map(f => f.相对);

  return { violations, 豁免, 只读调用, 重复类名, 双向, 自环, 规则名, 内核势力, 豁免审计, 体积, 注释 };
}

/* ============================ ⑦ 速查路由表（人工维护分类 + 自动定位行号） ============================
 * 左边「现象 / 机制」与「去哪看」由**人工维护**（这是给 Reviewer 的导航语义，扫不出来）；
 * 右边的**行号**全部由本工具现扫源码得出（`定位()` → `文件:行号`），一个都不写死；
 * 锚点找不到就**打 `—` 并计入 `缺锚点`**（说明函数被改名 / 删了，不是脚本坏了）。
 * ========================================================================== */
const 路由 = [
  { 板: '一次战斗的算法', 项: [
    { 现象: '命中率 / 暴击率 / 伤害主公式 / 单次攻击结算', 锚: [['core/battle/calc.gd', 'hitRate'], ['core/battle/calc.gd', 'critRate'], ['core/battle/calc.gd', 'dmgCore'], ['core/battle/calc.gd', 'resolveAttack']] },
    { 现象: '**单目标攻击结算（唯一攻击结算入口）**：改目标 / 事后钩子 / 散布死', 锚: [['core/battle/flow.gd', '结算一个目标']] },
    { 现象: '装甲 / 破防 / 防御乘子 / 能力值系数（减免管线）', 锚: [['core/battle/calc.gd', 'effArmor'], ['core/battle/calc.gd', 'breakSum'], ['core/battle/calc.gd', 'defMul'], ['core/battle/calc.gd', 'statCoef']] },
    { 现象: '射程分类 / 被挡 −20 / 落点 / 可达判定', 锚: [['core/battle/reach.gd', 'rangeKindOf'], ['core/battle/reach.gd', 'rowBlockPenalty'], ['core/battle/reach.gd', 'areaSlots'], ['core/battle/reach.gd', 'rowReachable'], ['core/battle/reach.gd', '够得着吗']] },
    { 现象: '阵型几何：行 / 列 / 位名 / 阻挡位 / 对位 / 相邻位', 锚: [['core/battle/fm.gd', '位名'], ['core/battle/fm.gd', '阻挡位'], ['core/battle/fm.gd', '对位'], ['core/battle/fm.gd', '相邻位'], ['core/battle/fm.gd', '被挡吗'], ['core/battle/fm.gd', '阻挡束']] },
    { 现象: '修理量（奶妈回血）', 锚: [['core/battle/calc.gd', 'healAmount']] },
    { 现象: '标定经济（产标 / 层数 / 点名 / 引爆）', 锚: [['core/battle/calc.gd', '标定经济产标'], ['core/battle/calc.gd', '标定经济引爆'], ['core/battle/calc.gd', '标定经济参数']] },
    { 现象: '武器能不能打 / 大招能不能打（不可打原因）', 锚: [['core/battle/calc.gd', 'weaponPlayable'], ['core/battle/calc.gd', 'usableWeapons'], ['core/battle/deck_flow.gd', '大招不可打原因'], ['core/battle/deck_flow.gd', '副武器不可打原因']] },
  ] },
  { 板: '牌组与手牌', 项: [
    { 现象: '手牌上限 / 战意（气势）参数', 锚: [['core/battle/params.gd', '手牌上限'], ['core/battle/params.gd', '战意上限'], ['core/battle/params.gd', '单机牌组参数']] },
    { 现象: '开局发牌 / 阶段初检查 / 抽牌与弃牌 / 打出大招与副武器 / **武器栏换装栈：`压栈武器栏` · `弹栈武器栏`**', 锚: [['core/battle/deck_flow.gd', '初始化'], ['core/battle/deck_flow.gd', '阶段初_检查'], ['core/battle/deck_flow.gd', '打出大招'], ['core/battle/deck_flow.gd', '打出副武器'], ['core/battle/deck_flow.gd', '压栈武器栏'], ['core/battle/deck_flow.gd', '弹栈武器栏']] },
    { 现象: '**会话子模块（D1 拆出）**：上排 / 下排 / 公有牌 · 武器栏 / 大招槽 / 出牌 · 开战与节点结算 · 展示与悬停说明 · 大地图黑市休整奇遇 · 实时监视', 锚: [['session/battle_hand_view.gd', 'upper_hand_cards'], ['session/battle_hand_view.gd', 'lower_hand_cards'], ['session/battle_deck_view.gd', 'weapon_bar_cards'], ['session/battle_deck_view.gd', '打出大招'], ['session/battle_flow.gd', '_开节点战'], ['session/run_facade.gd', '_走一格'], ['session/display_helpers.gd', 'unit_view'], ['session/tooltip_text.gd', 'card_hover_text'], ['session/live_monitor.gd', 'snapshot_for_monitor']] },
    { 现象: '单机牌组初始化（专属库 / 公有库 / 起手 / 衍生卡）', 锚: [['core/battle/setup.gd', '初始化单机牌组'], ['core/battle/setup.gd', '初始化单机牌组单位'], ['core/battle/setup.gd', '派发衍生卡']] },
    { 现象: '副牌组（结构化牌库：放入 / 抽一张 / 三级档）', 锚: [['core/battle/sub_deck.gd', '新建'], ['core/battle/sub_deck.gd', '放入'], ['core/battle/sub_deck.gd', '抽一张'], ['core/battle/sub_deck.gd', '已放入三级']] },
    { 现象: 'AI 自动补打主武器（结束回合）', 锚: [['core/battle/ai_deck.gd', 'auto_play_unit_main_weapon']] },
    { 现象: '**出牌判定（不可打原因 / 目标方 / 找执行机体）**', 锚: [['core/battle/card_play.gd', '不可打原因'], ['core/battle/card_play.gd', '目标方'], ['core/battle/card_play.gd', '找执行机体']] },
  ] },
  { 板: '卡牌与势力机制', 项: [
    { 现象: '32 张战术牌的**效果本体**（声明式算子）', 锚: [['core/battle/card_effects.gd', 'execute'], ['core/battle/card_effects.gd', 'execute_ops']] },
    { 现象: '职业牌 / 职业机制（命中修正 / 伤害倍率 / 改写武器）', 锚: [['core/battle/class_cards.gd', '卡表'], ['core/battle/class_cards.gd', '命中修正'], ['core/battle/class_cards.gd', '改写武器']] },
    { 现象: '秘银 v0.3（连携 / 身份对口 / 角色专属）', 锚: [['core/battle/mithril_v03_cards.gd', '卡表'], ['core/battle/mithril_v03_cards.gd', '连携牌们'], ['core/battle/mithril_v03_cards.gd', '身份对口']] },
    { 现象: '天人 v0.1（TRANS-AM / 武力介入 / 粒子耗尽）', 锚: [['core/battle/celestial_v01.gd', '开启TRANSAM'], ['core/battle/celestial_v01.gd', '武力介入满足吗'], ['core/battle/celestial_v01.gd', '阶段初']] },
    { 现象: 'ATX：三小强 / 双子 / 势力牌 / 神赌 / 强运 / 烟雾 / 段数改写 / 筹码库', 锚: [['core/battle/atx_three.gd', '卡表'], ['core/battle/atx_duo.gd', '卡表'], ['core/battle/atx_faction.gd', '执行'], ['core/battle/atx_godsbet.gd', '掷翻盘'], ['core/battle/atx_luck.gd', '必触发'], ['core/battle/atx_smoke.gd', '放烟'], ['core/battle/atx_rewrite.gd', '应用'], ['core/battle/atx_chips.gd', '触发赌局']] },
    { 现象: '势力特色框架（17 个钩子 + 注册表）', 锚: [['core/battle/fac.gd', '势力开局'], ['core/battle/fac.gd', '势力伤害倍率'], ['core/battle/fac.gd', '势力在场'], ['core/battle/fac.gd', '势力参数']] },
    { 现象: '**规则钩子注册表（阶段 / 修正 / 出牌门槛）**：`顺序` 表定派发序，通用内核只许调它的接口', 锚: [['core/battle/rule_hooks.gd', '汇总'], ['core/battle/rule_hooks.gd', '依次乘'], ['core/battle/rule_hooks.gd', '广播'], ['core/battle/rule_hooks.gd', '首个结论']] },
    { 现象: '势力·ATX（含 v0.2 卡表）', 锚: [['core/battle/fac_cb.gd', 'ATX打空'], ['core/battle/fac_atx.gd', '卡表'], ['core/battle/fac_cb.gd', 'ATX减冷却']] },
    { 现象: '势力·秘银（SRT 交叉训练 / 挂标定 / 倒下接力）', 锚: [['core/battle/fac_mith.gd', '秘银挂标定'], ['core/battle/fac_mith.gd', '秘银兑现'], ['core/battle/fac_mith.gd', '倒下接力']] },
    { 现象: '势力·月球王国（光环 / 残月追加 / 不动如山）', 锚: [['core/battle/fac_moon.gd', '判定月球王国光环'], ['core/battle/fac_moon.gd', '残月追加攻击'], ['core/battle/fac_moon.gd', '判定月球不动']] },
    { 现象: '势力·天人（v0.1 大招牌 TRANS-AM / 太阳炉）', 锚: [['core/battle/celestial_v01.gd', '开启TRANSAM'], ['core/battle/celestial_v01.gd', 'transam中']] },
  ] },
  { 板: '战斗流程与对手', 项: [
    { 现象: '参数总入口（战斗结构开关一律从这里读）', 锚: [['core/battle/params.gd', '词条参数'], ['core/battle/params.gd', '大招开场冷却'], ['core/battle/params.gd', '兰斯战线开'], ['core/battle/params.gd', '职业排位开']] },
    { 现象: '回合流程：回合开始 / 单位动作 / 结算一次行动', 锚: [['core/battle/phase_flow.gd', '开始我方阶段'], ['core/battle/flow.gd', '单位动作'], ['core/battle/flow.gd', 'resolveAction'], ['core/battle/flow.gd', '增援']] },
    { 现象: '开一场 / 跑完一场 / 结束判定 / 回合结束', 锚: [['core/battle/setup.gd', '开局'], ['core/battle/setup.gd', '跑完'], ['core/battle/setup.gd', 'checkResult'], ['core/battle/setup.gd', 'endTurn']] },
    { 现象: '记录 / 战意 / 嘲讽 / 镜甲 / 自爆（`btl.gd` 留高频转发，实现已搬进子模块）', 锚: [['core/battle/btl.gd', 'pushLog'], ['core/battle/btl.gd', '战意'], ['core/battle/battle_log.gd', 'pushLog'], ['core/battle/morale.gd', '战意费用'], ['core/battle/guard.gd', '嘲讽'], ['core/battle/guard.gd', '镜甲反弹'], ['core/battle/guard.gd', '自爆']] },
    { 现象: '**内核子模块（D3 拆出）**：卡牌执行 / 阶段推进 / 敌方意图', 锚: [['core/battle/card_exec.gd', '打出精神或公有牌'], ['core/battle/card_exec.gd', '打出衍生攻击卡'], ['core/battle/phase_flow.gd', '开始我方阶段'], ['core/battle/phase_flow.gd', '结束我方回合'], ['core/battle/intent.gd', '算意图'], ['core/battle/intent.gd', '刷新敌方意图']] },
    { 现象: 'AI：憋大招 / 目标打分 / 武器池 / 选目标 / 两方出手', 锚: [['core/battle/ai.gd', 'isUltimate'], ['core/battle/ai.gd', 'targetScore'], ['core/battle/ai.gd', 'weaponPool'], ['core/battle/ai.gd', 'pickSingleTarget'], ['core/battle/ai.gd', 'aiAction'], ['core/battle/ai.gd', 'enemyAction']] },
    { 现象: 'Boss 站桩脚本（间隔 / 半血换阶段 / 大技能）', 锚: [['core/battle/boss.gd', 'bossTurn'], ['core/battle/boss.gd', 'Boss本回合放大技能'], ['core/battle/boss.gd', 'Boss伤害倍率'], ['core/battle/boss.gd', 'bossAction']] },
    { 现象: '难度：回合上限 / 站位权重 / 敌方强化', 锚: [['core/battle/diff.gd', '回合上限'], ['core/battle/diff.gd', '站位权重'], ['core/battle/diff.gd', '敌方强度倍率'], ['core/battle/diff.gd', '应用敌方强化']] },
    { 现象: '单位构造 / 等级 / 阵营与职业判定', 锚: [['core/battle/units.gd', 'makeUnit'], ['core/battle/units.gd', 'makeUnits'], ['core/battle/units.gd', 'levelUp'], ['core/battle/units.gd', 'unit_class']] },
    { 现象: '编成词条（确定性修饰：作用 / 叠加 / 到单位）', 锚: [['core/battle/traits.gd', '编成词条'], ['core/battle/traits.gd', '词条汇总'], ['core/battle/traits.gd', '应用词条到单位']] },
    { 现象: '藏品在战斗里的数值落地', 锚: [['core/battle/relic_battle.gd', 'apply_on_battle_start'], ['core/battle/relic_battle.gd', '藏品合计封顶'], ['core/battle/relic_battle.gd', '应用藏品我方']] },
  ] },
  { 板: '数据与肉鸽', 项: [
    { 现象: '全局数据表（角色 / 敌人 / 关卡 / 卡 / 藏品 / 零件）', 锚: [['core/data/db.gd', 'install'], ['core/data/game_data.gd', 'get_const'], ['core/data/game_catalog.gd', 'characters'], ['core/data/game_catalog.gd', 'cards'], ['core/battle/data_fn.gd', 'tplOf']] },
    { 现象: '卡包数据（天人 / 秘银 / ATX / 职业分类牌：每包自带 `"结构"` 声明，卡 `id` 全局唯一）', 锚: [['data/cards/*.json', ''], ['session/data_loader.gd', 'CARD_DIR']] },
    { 现象: '卡包加载与结构校验（扫描 `data/cards/*.json` → 校验 `结构` 类型 → 登记全局 `id`）', 锚: [['session/data_loader.gd', '_扫描卡包文件'], ['session/data_loader.gd', '_检查卡包'], ['session/data_loader.gd', '_登记卡id'], ['session/data_loader.gd', '结构类型们']] },
    { 现象: '地图生成（分层正方形 / 存在率 / 割点 / 推进剂余量）', 锚: [['core/run/map_generator.gd', 'shape'], ['core/run/map_generator.gd', 'propellant_max'], ['core/run/map_generator.gd', 'articulation_points']] },
    { 现象: '地图移动（邻接 / 隧道 / 退路成本 / 出口规则）', 锚: [['core/run/map_navigator.gd', 'can_move_to'], ['core/run/map_navigator.gd', 'use_tunnel'], ['core/run/map_navigator.gd', 'retreat_cost'], ['core/run/map_navigator.gd', 'current_exit_kind']] },
    { 现象: '节点结算（编成 / 奖励档 / 词条组 / 增援波次）', 锚: [['core/run/node_resolver.gd', '选编成'], ['core/run/node_resolver.gd', '编成到规格'], ['core/run/node_resolver.gd', '增援波次']] },
    { 现象: '一局状态（日志 / 格子 / 等级 / 希望 / 存档字典）', 锚: [['core/run/run_state.gd', 'to_dict'], ['core/run/run_state.gd', 'from_dict'], ['core/run/run_state.gd', 'gain_exp']] },
    { 现象: '编成 / 名册 / 零件 / 藏品（局外）', 锚: [['core/run/deck_builder.gd', 'offer_cards'], ['core/run/roster_manager.gd', '模板'], ['core/run/part_system.gd', '零件表'], ['core/run/relic_system.gd', '抽藏品']] },
    { 现象: '版本号（界面 / 存档 / 录像都读它）', 锚: [['core/version.gd', 'class']] },
    { 现象: 'JS 兼容层（truthy / 数字规整）/ 稳定排序 / 随机数', 锚: [['core/util/js.gd', 'truthy'], ['core/util/js.gd', 'num0'], ['core/util/js_compat.gd', 'stable_sort'], ['core/util/rng.gd', '_init'], ['core/util/rng.gd', 'next_float']] },
  ] },
  { 板: '会话与表现层', 项: [
    { 现象: '**界面唯一入口**（GameSession 门面：开局 / 存档 / 进战斗 / 节点结算）', 锚: [['session/game_session.gd', 'start_new_run'], ['session/game_session.gd', 'load_saved_run'], ['session/game_session.gd', 'in_battle'], ['session/game_session.gd', 'available_squads']] },
    { 现象: '数据装配（JSON → Db）/ 存档落盘', 锚: [['session/data_loader.gd', 'load_game_data'], ['session/save_service.gd', 'save_to_file'], ['session/save_service.gd', 'load_from_file']] },
    { 现象: '主题 / 提示 / 单位卡 / 顶栏 / 弹层（表现层公共件）', 锚: [['presentation/theme/ui_theme.gd', '建面板'], ['presentation/widgets/hover_tooltip.gd', 'class'], ['presentation/widgets/unit_card.gd', 'class'], ['presentation/widgets/top_bar.gd', 'setup'], ['presentation/widgets/modal_layer.gd', 'class']] },
    { 现象: '四个主画面：启动 / 菜单 / 战斗 / 结算', 锚: [['presentation/boot/boot.gd', '_ready'], ['presentation/menus/menu_view.gd', 'setup'], ['presentation/battle/battle_view.gd', 'setup'], ['presentation/battle/result_view.gd', 'setup']] },
    { 现象: '**战斗画面面板（D2 拆出）**：棋盘 / 手牌栏 / 左牌库 / 战报栏 / 拖拽瞄准 / 演出播放（`battle_view.gd` 组装 + 转发）', 锚: [['presentation/battle/board_panel.gd', '_画阵型'], ['presentation/battle/hand_panel.gd', '_画手牌'], ['presentation/battle/deck_sidebar.gd', '_画左牌库'], ['presentation/battle/log_panel.gd', '_画战报'], ['presentation/battle/drag_aim.gd', '拖拽到'], ['presentation/battle/battle_fx_player.gd', '构建单拍演出帧']] },
    { 现象: '肉鸽画面：大地图 / 编队 / 商店 / 休整 / 事件 / 选卡 / 名册', 锚: [['presentation/run_map/map_view.gd', 'setup'], ['presentation/run_map/formation_view.gd', 'setup'], ['presentation/menus/shop_view.gd', 'setup'], ['presentation/menus/rest_view.gd', 'setup'], ['presentation/menus/event_view.gd', 'setup'], ['presentation/menus/pick_card_view.gd', 'setup'], ['presentation/menus/roster_view.gd', 'setup']] },
    { 现象: '测试唯一入口 / 原生黄金样例对拍', 锚: [['tests/run_tests.gd', '_initialize'], ['tests/native_golden_runner.gd', 'run'], ['tests/golden_io.gd', 'class'], ['tests/golden_compare.gd', 'class']] },
  ] },
];

/* ============================ ⑧ 生成（纯计算，绝不写盘） ============================ */
export function 生成(opts = {}) {
  const 根 = opts.根 || GODOT;
  const 相对们 = 扫gd文件(根);
  const 文件们 = 相对们.map(相对 => 解析gd(相对, 读文本(join(根, 相对))));
  const 文件集合 = new Set(相对们);
  const 类索引 = 建类索引(文件们);
  const 资源 = 建依赖(文件们, 类索引, 文件集合);
  const 调用表 = 扫调用点(文件们, 类索引);

  /* 调用次数回填到函数上（外部 = 不含本文件内自调） */
  for (const f of 文件们) {
    for (const 函 of f.函数) {
      const 调用者们 = 调用表.get(`${f.类名}.${函.名}`);
      if (!调用者们) continue;   // 没有 class_name 的文件（boot.gd / run_tests.gd）不会被外部按类名调
      let 全 = 0, 外 = 0;
      for (const [调用文件, n] of 调用者们) { 全 += n; if (调用文件 !== f.相对) 外 += n; }
      函.全仓调用 = 全;
      函.外部调用 = 外;
    }
  }
  /* 反向依赖表 */
  for (const f of 文件们) f.被依赖 = [];
  for (const f of 文件们) for (const e of f.dependsOn) {
    const 目标 = 文件们.find(x => x.相对 === e.to);
    if (目标) 目标.被依赖.push({ from: f.相对, layer: f.层, n: e.n, symbols: e.symbols });
  }
  for (const f of 文件们) f.被依赖.sort((a, b) => (a.from < b.from ? -1 : 1));

  const 统计 = 汇总(文件们, 类索引, 资源);
  const 审计结果 = 审计(文件们, 类索引, 调用表);
  const 锚点们 = 解析锚点(文件们);

  /* D3：先把**索引页**渲染出来 → 量它自己的体积（D1 口径）→ 再把体积数字写进明细页，
   * 索引页里**故意不写自己的 token 数**（写进去就会自指、把数字搅成不稳定）。 */
  const md = 渲染主索引(文件们, 类索引, 统计, 审计结果, 锚点们);
  const 索引体积 = { 字节: Buffer.byteLength(md, 'utf8'), ...量体积(md) };
  索引体积.超限 = 索引体积.estTokens > 索引TOKEN上限;
  const 明细 = 渲染明细(文件们, 类索引, 统计, 审计结果, 锚点们, 索引体积);
  const 明细体积 = { 字节: Buffer.byteLength(明细, 'utf8'), ...量体积(明细) };
  const json = 渲染JSON(文件们, 类索引, 统计, 审计结果, 资源, 索引体积, 明细体积);
  return {
    md, 明细, json, 统计, 索引体积, 明细体积,
    violations: 审计结果.violations, 审计: 审计结果, 锚点们,
    未解析资源: 资源.未解析, 非gd资源: 资源.非gd, 目录资源: 资源.目录,
  };
}

function 汇总(文件们, 类索引, 资源) {
  const 层统计 = {};
  for (const 名 of [...层们, '其他']) 层统计[名] = { 文件: 0, 行数: 0, 字节: 0, 估算token: 0, 注释字节: 0, 注释占比: 0, 类名: 0, 常量: 0, 函数: 0, 出边: 0, 入边: 0, 跨层出边: 0 };
  for (const f of 文件们) {
    const s = 层统计[f.层] || 层统计['其他'];
    s.文件++; s.行数 += f.行数; s.字节 += f.字节;
    s.估算token += f.estTokens; s.注释字节 += f.注释字节;
    if (f.类名) s.类名++;
    s.常量 += f.常量.length; s.函数 += f.函数.length;
    s.出边 += f.dependsOn.length;
    for (const e of f.dependsOn) if (e.layer !== f.层) s.跨层出边++;
  }
  for (const f of 文件们) for (const e of f.dependsOn) {
    const s = 层统计[e.layer] || 层统计['其他'];
    s.入边++;
  }
  const 生产边 = 文件们.filter(f => f.层 !== 'tests').reduce((a, f) => a + f.dependsOn.length, 0);
  const 跨层边 = 文件们.filter(f => f.层 !== 'tests').reduce((a, f) => a + f.dependsOn.filter(e => e.layer !== f.层).length, 0);
  const 函数总 = 文件们.reduce((a, f) => a + f.函数.length, 0);
  const 静态函数 = 文件们.reduce((a, f) => a + f.函数.filter(x => x.static).length, 0);
  const 公开函数 = 文件们.reduce((a, f) => a + f.函数.filter(x => !x.名.startsWith('_')).length, 0);
  const 内类 = 文件们.reduce((a, f) => a + f.内类数, 0);
  for (const 名 of Object.keys(层统计)) {
    const s = 层统计[名];
    s.注释占比 = s.字节 ? s.注释字节 / s.字节 : 0;
  }
  return {
    文件数: 文件们.length,
    层统计,
    总行数: 文件们.reduce((a, f) => a + f.行数, 0),
    总字节: 文件们.reduce((a, f) => a + f.字节, 0),
    总估算token: 文件们.reduce((a, f) => a + f.estTokens, 0),
    总注释字节: 文件们.reduce((a, f) => a + f.注释字节, 0),
    总体注释占比: (() => {
      const 总 = 文件们.reduce((a, f) => a + f.字节, 0);
      return 总 ? 文件们.reduce((a, f) => a + f.注释字节, 0) / 总 : 0;
    })(),
    类名数: 类索引.size,
    常量数: 文件们.reduce((a, f) => a + f.常量.length, 0),
    函数数: 函数总,
    静态函数数: 静态函数,
    公开函数数: 公开函数,
    内类数: 内类,
    依赖边数: 文件们.reduce((a, f) => a + f.dependsOn.length, 0),
    生产依赖边数: 生产边,
    生产跨层边数: 跨层边,
    资源未解析数: (资源.未解析 || []).length,
    非gd资源数: (资源.非gd || []).length,
    目录路径数: (资源.目录 || []).length,
  };
}

/* ---- 锚点：`[文件, 符号]` → 行号；符号 'class' = class_name 那一行；'const:名' = 常量 ---- */
function 解析锚点(文件们) {
  const 索引 = new Map(文件们.map(f => [f.相对, f]));
  const 缺 = [];
  const 定位 = (相对, 符号) => {
    /* 非 .gd 资源（`data/cards/*.json` 这种）：没有行号可定位，也不算「缺锚点」 */
    if (!相对.endsWith('.gd')) return null;
    const f = 索引.get(相对);
    if (!f) { 缺.push(`${相对} (文件不存在)`); return null; }
    if (符号 === 'class') return f.类名行;
    if (符号.startsWith('const:')) {
      const c = f.常量.find(x => x.名 === 符号.slice(6));
      if (!c) { 缺.push(`${相对} const ${符号.slice(6)}`); return null; }
      return c.行;
    }
    const 函 = f.函数.find(x => x.名 === 符号);
    if (函) return 函.行;
    const 常 = f.常量.find(x => x.名 === 符号);
    if (常) return 常.行;
    缺.push(`${相对} ${符号}`);
    return null;
  };
  const 表 = 路由.map(板 => ({
    板: 板.板,
    项: 板.项.map(项 => {
      const 按文件 = new Map();
      for (const [相对, 符号] of 项.锚) {
        const 行 = 定位(相对, 符号);
        if (!按文件.has(相对)) 按文件.set(相对, []);
        按文件.get(相对).push(行 == null ? '—' : 行);
      }
      const 平铺 = [...按文件.entries()].filter(([f]) => !f.endsWith('.gd'))
        .map(([f]) => '`' + f + '`');
      return {
        现象: 项.现象,
        片: [...平铺, ...[...按文件.entries()].filter(([f]) => f.endsWith('.gd')).map(([f, 行们]) => '`' + f + ':' + 行们.join('/') + '`')],
      };
    }),
  }));
  return { 表, 缺 };
}

/* ============================ ⑨ 渲染 Markdown ============================
 * **两份产物分工（D3 拆分）**：
 *   · 主索引 `Godot-RouteMap.md` = 抬头 + §0 + §0.5 + §1 + §4 → 会话开机读这一份，**自限 ≤ 8,000 token**
 *   · 明细页 `Godot-RouteMap-明细.md` = §2 + §3 + §4.1 明细 + §4.4 全表 + §5 → **按需 `grep`，不许整份读**
 * ========================================================================== */
const 索引标题 = '# Godot 路由地图 · RouteMap 主索引（AST 符号级）';
const 明细标题 = '# Godot 路由地图 · RouteMap 明细页（AST 符号级）';

/** 两份文件共用的「口径 / 范围 / 限制 / 同步纪律 / 快照」提醒行（只写一遍，两边都引）。 */
function 公共提醒(统计, 违规) {
  return [
    '> **一句话**：Godot 版的「**免派定位探针**」——「哪个文件负责什么 / 某个函数在第几行 / 谁依赖谁 / 谁在偷偷反向依赖」，`grep` 这两页或跑 `route_query.mjs` 即可，不必再派探查子代理。',
    '> **口径**：所有数字与行号都由 `godot/tools/build_godot_routemap.mjs` **现扫 `godot/**/*.gd`** 得出，**一个行号都不写死**；本工具**不加载、不执行** Godot，所以全是「**静态扫描识别**」值，不是运行时真值。文件里**故意不写生成时间**（否则 `--check` 永远红）。',
    '> **扫描范围**：`godot/` 下全部 `.gd`（排除 `.godot/` 等点开头目录），按 `core/` `session/` `presentation/` `tests/` 分层；依赖边 = 代码里的 `class_name` 引用（整词精确匹配，注释与字符串先抹掉）+ `preload/load` 的 `res://` 字面量。',
    '> **已知限制**：只到**词法 + 符号表**级别（不建 GDScript AST、不做值流 / 别名 / 反射 / 动态 `load(变量)`）；顶层 `var` / `signal` / `enum` 不进符号表；`presentation → core` 的写接口只认 `类名.函数名(` 直接静态调用（`callv` / `Callable` / 字符串派发认不出）。',
    '> **同步纪律**：`.gd` 一改本文件即过期 —— 交单前跑 `node godot/tools/build_godot_routemap.mjs` 重建，再跑 `--check`（返回码 `0` = 三份生成物逐字节一致）。**别手改**。',
    `> **当前快照（静态扫描识别值）**：\`godot/\` 下 **${统计.文件数}** 个 \`.gd\` / **${统计.总行数}** 行 / **${统计.总字节}** 字节 · 估算 **${统计.总估算token}** token（注释 **${百分比(统计.总体注释占比)}**）· \`class_name\` **${统计.类名数}** 个 · 顶层 \`const\` **${统计.常量数}** / \`func\` **${统计.函数数}** 个（\`static func\` **${统计.静态函数数}**、公开 **${统计.公开函数数}**、内类 **${统计.内类数}**）· 依赖边 **${统计.依赖边数}**（生产层 **${统计.生产依赖边数}**，其中跨层 **${统计.生产跨层边数}**）· 解不出的 \`res://*.gd\` **${统计.资源未解析数}** 处 · 非 \`.gd\` 资源 **${统计.非gd资源数}** 处（目录路径 **${统计.目录路径数}** 处不计）· **架构分层违规 ${违规} 处**。`,
  ];
}

/** 「改前 / 改后」对照行（只在索引页 §0.5 出现；改前值来自 `示范改前` 常量）。 */
function 改前改后行们(文件们) {
  const 出 = [];
  for (const 旧 of 示范改前) {
    const f = 文件们.find(x => x.相对 === 旧.文件);
    if (!f) continue;
    const 字节降 = (1 - f.字节 / 旧.字节) * 100;
    const token降 = (1 - f.estTokens / 旧.estTokens) * 100;
    出.push(`> | \`${旧.文件}\` | ${旧.字节} 字节 · ${旧.estTokens} token · 注释 ${百分比(旧.注释占比)} | ${f.字节} 字节 · ${f.estTokens} token · 注释 ${百分比(f.注释占比)} | **${字节降 >= 0 ? '−' : '+'}${Math.abs(字节降).toFixed(1)}% 字节 / ${token降 >= 0 ? '−' : '+'}${Math.abs(token降).toFixed(1)}% token** |`);
  }
  return 出;
}

/** 势力文件的「谱系」——只用来在索引页里把「跨谱系横向引用」挑出来单独说。 */
function 势力谱系(相对) {
  const 基 = 相对.replace(/^core\/battle\//, '').replace(/\.gd$/, '');
  if (基 === 'fac_cb') return 'ATX/天人';
  if (基.startsWith('atx_') || 基 === 'fac_atx') return 'ATX';
  if (基.startsWith('celestial_')) return '天人';
  if (基.startsWith('mithril_') || 基 === 'fac_mith') return '秘银';
  if (基 === 'fac_moon') return '月球';
  return '其他';
}

function 渲染主索引(文件们, 类索引, 统计, 审计结果, 锚点们) {
  const L = [];
  const 推 = (...x) => L.push(...x);
  const 违规 = 审计结果.violations.length;
  const 势力统计 = 审计结果.内核势力;
  const top体积 = [...文件们]
    .sort((a, b) => b.estTokens - a.estTokens || b.字节 - a.字节 || (a.相对 < b.相对 ? -1 : 1))
    .slice(0, 20);
  const top体积和 = top体积.reduce((a, f) => a + f.estTokens, 0);

  推(抬头, 索引标题, '',
    '> **★ 这是索引页（自限 ≤ 8,000 估算 token），不是全量文档。** 要「某文件的函数表 / 某模块依赖谁」：① `grep` 明细页的 §2（职责表）/ §3（依赖矩阵），或 ② `node godot/tools/route_query.mjs <符号|文件路径>` 只取切片；**别整份读明细页，也别整份读 `Godot-AST依赖清单.json`（1.4 MB）**。',
    ...公共提醒(统计, 违规),
    '',
    '---',
    '',
    '## §0 总览统计（按四层）',
    '',
    '> **读法**：`出边` / `入边` = 本层指向别层 / 别层指向本层的依赖边数；`跨层出边` 越大越要盯 §4。',
    '',
    '| 层 | 文件 | 行数 | 字节 | 估算 token | 注释占比 | class_name | const | func | 出边 | 入边 | 跨层出边 |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|',
  );
  for (const 名 of [...层们, '其他']) {
    const s = 统计.层统计[名];
    if (!s.文件 && 名 === '其他') continue;
    推(`| **${名}** | ${s.文件} | ${s.行数} | ${s.字节} | ${s.估算token} | ${百分比(s.注释占比)} | ${s.类名} | ${s.常量} | ${s.函数} | ${s.出边} | ${s.入边} | ${s.跨层出边} |`);
  }
  推(`| **合计** | **${统计.文件数}** | **${统计.总行数}** | **${统计.总字节}** | **${统计.总估算token}** | **${百分比(统计.总体注释占比)}** | **${统计.类名数}** | **${统计.常量数}** | **${统计.函数数}** | **${统计.依赖边数}** | — | **${统计.生产跨层边数}** |`, '');

  /* ---- §0.5 Token 体积 Top 20（D1） ---- */
  推('---', '', '## §0.5 Token 体积 Top 20', '',
    '> **估算 token 口径**：`token ≈ CJK 字符数 × 1.0 + 其余字符数 ÷ 3.5`（CJK = 汉字 + 全角标点，按 Unicode 码点一个算一个）。这是**估算**，不是任何分词器的真值。',
    '> **注释占比口径**：以 `#` 开头的行（含前导空白后以 `#` 开头）与代码行尾 `# …` 的 **UTF-8 字节**合计 ÷ 文件总字节；**字符串字面量里的 `#` 不算**，行尾换行符不计。',
    `> **全仓合计**：**${统计.总字节}** 字节 / 估算 **${统计.总估算token}** token / 注释 **${统计.总注释字节}** 字节（**${百分比(统计.总体注释占比)}**）；下面 Top 20 合计 **${top体积和}** token，占全仓 **${百分比(统计.总估算token ? top体积和 / 统计.总估算token : 0)}** —— 改热路径之前先看这张表。`,
    '> **CR-1 两个示范文件的改前 / 改后对照、以及工程单里手写字节数与实测值的差异说明**，已搬到明细页 §0.5b（索引页省 token）。',
    '',
    '| 排名 | 文件 | 层 | 行 | 字节 | 估算 token | 注释字节 | 注释占比 |',
    '|---|---|---|---|---|---|---|---|');
  top体积.forEach((f, i) => {
    推(`| ${i + 1} | \`${f.相对}\` | ${f.层} | ${f.行数} | ${f.字节} | ${f.estTokens} | ${f.注释字节} | ${百分比(f.注释占比)} |`);
  });
  推('');

  /* §0.5 末尾：规则 ⑦ 的「未登记的新大文件」警告清单（**不判红**，只提醒拆） */
  const 体积 = 审计结果.体积;
  const 体积话 = `> **规则 ⑦ 体积警告**（未登记进 \`SIZE_RATCHET\` 且 > **${体积.行上限}** 行 或 > **${体积.token上限}** 估算 token 的新 \`.gd\`）：`;
  if (体积.警告.length) {
    推(体积话 + `**${体积.警告.length} 个文件** ✗ —— 先拆再加功能：`, '');
    推('| 文件 | 行 | 估算 token | 超了哪一条 |', '|---|---|---|---|');
    for (const w of 体积.警告) 推(`| \`${w.路径}\` | ${w.行数} | ${w.estTokens} | ${[w.超行 ? `行 > ${体积.行上限}` : '', w.超token ? `token > ${体积.token上限}` : ''].filter(Boolean).join(' · ')} |`);
    推('');
  } else 推(体积话 + `**0 个文件** ✓（D1~D4 拆出的新文件都在 ${体积.行上限} 行 / ${体积.token上限} token 以内；已登记的既有大文件见 §4.5）`, '');

  /* §0.5 末尾：规则 ⑧ 的「注释占比超阈值」警告 —— **清单整段在明细页 §4.6b**
   *   （施工单 RT-3b 收口的预先授权：索引页 8,000 token 上限优先，这里只留一行指针 + 总数）。 */
  const 注释棘 = 审计结果.注释;
  if (注释棘.警告.length) {
    推(`> **规则 ⑧ 注释占比警告**：未登记进 \`COMMENT_RATCHET\` 且超过本层阈值（生产 ${百分比(注释棘.行上限)} / \`tests/**\` ${百分比(注释棘.测试行上限)}）的 \`.gd\` 共 **${注释棘.警告.length} 个** ✗ —— 全表见明细页 §4.6b。`, '');
  } else 推(`> **规则 ⑧ 注释占比警告**：**0 个文件** ✓（全仓每个 \`.gd\` 都在阈值以内；已登记的文件见 §4.6）。`, '');

  推('---', '', '## §1 速查路由表（按现象 / 机制查文件）',
    '',
    '> **怎么用**：手上只有现象（「伤害不对」「大招打不出去」「地图走不动」）时，先在这里找**责任文件**，再进明细页 §2 看该文件的职责与导出面。',
    '> **行号**：左两列**人工维护**（导航语义扫不出来），`文件:行号` 全部现扫源码得出；打 `—` = 该符号当前找不到（改名 / 删了），不是脚本坏了。',
    '',
    '| 板块 | 现象 / 机制 | 去哪看（`文件:行号`，`/` 分隔同文件的多个锚点） |',
    '|---|---|---|');
  for (const 板 of 锚点们.表) {
    for (const 项 of 板.项) 推(`| ${板.板} | ${逃(项.现象)} | ${项.片.join(' · ')} |`);
  }
  推('');

  /* ---- §4 合规审计（含规则 ⑤ 棘轮） ---- */
  const 跨谱系 = 势力统计.横向.filter(x => 势力谱系(x.from) !== 势力谱系(x.to));
  const 同谱系边 = 势力统计.横向.length - 跨谱系.length;
  推('---', '', '## §4 架构分层与耦合合规审计',
    '',
    `**结论：\`violations: []\`（${违规} 处）** —— ${违规 ? '**有违规，明细见下表**' : '八条规则本次全部通过（①~④ 跨层依赖 + ⑤ 内核→势力棘轮 + ⑥ 豁免文件表外引用 + ⑦ 体积棘轮 + ⑧ 注释占比棘轮）'}。`,
    '',
    '| # | 规则 | 违规 | 检查了什么 |', '|---|---|---|---|',
    `| ① | \`core/**\` 不得引用 \`session/**\` | ${审计结果.violations.filter(v => v.rule === '①').length} | 逐文件比 \`dependsOn\` 的目标层（含 \`preload/load\` 解析到的 \`.gd\`） |`,
    `| ② | \`core/**\` 不得引用 \`presentation/**\` | ${审计结果.violations.filter(v => v.rule === '②').length} | 同上 |`,
    `| ③ | \`session/**\` 不得引用 \`presentation/**\` | ${审计结果.violations.filter(v => v.rule === '③').length} | 同上（\`层间豁免\` 登记过的 (from,to) 除外，见 §4.2） |`,
    `| ④ | \`presentation/**\` 不得绕过 \`GameSession\` 直接调 \`core/**\` 的**写接口** | ${审计结果.violations.filter(v => v.rule === '④').length} | 扫全仓 \`类名.函数名(\` 直接静态调用；函数名首字是写动词或整名在白名单里即判写接口 |`,
    `| ⑤ | **通用内核文件 → 势力文件**引用次数 ≤ 棘轮基线 **${CORE_TO_FACTION_RATCHET_MAX}**（当前 **${势力统计.总次数}**） | ${审计结果.violations.filter(v => v.rule === '⑤').length} | 见 §4.0：\`dependsOn\` 里指向势力文件的 \`n\` 之和（与 CodeReview 报告 §3 同一口径）；**基线只许下调** |`,
    `| ⑥ | **豁免注册表文件**（\`fac.gd\` / \`rule_hooks.gd\`）在**登记表 / 分派区之外**对势力 / 职业模块的引用 = **0** | ${审计结果.violations.filter(v => v.rule === '⑥').length} | 见 §4.0c：现扫允许区域（\`顺序\` / \`ORDER\` 声明块 + \`match 势力\` + \`势力 ==\` 的 \`if\`），区域外出现 ${审计结果.豁免审计.模块类名们.length} 个模块任意一个即违规 |`,
    `| ⑦ | **体积棘轮**：\`SIZE_RATCHET\` 登记的 ${审计结果.体积.登记数} 个既有大文件，\`estTokens\` 只许下降 | ${审计结果.violations.filter(v => v.rule === '⑦').length} | 见 §4.5：> ${审计结果.体积.行上限} 行或 > ${审计结果.体积.token上限} token 的既有文件逐个登记上限，**只许下调**；未登记的新大文件只进 §0.5 警告 |`,
    `| ⑧ | **注释占比棘轮**：\`COMMENT_RATCHET\` 登记的 ${审计结果.注释.登记数} 个文件必须一直待在**本层阈值**以内（生产 > ${百分比(审计结果.注释.行上限)} / 测试 > ${百分比(审计结果.注释.测试行上限)} 即违规；未登记的只进 §0.5 警告） | ${审计结果.violations.filter(v => v.rule === '⑧').length} | 见 §4.6：注释字节 ÷ 文件总字节（与「注释约定」同一口径）；登记表**只有路径**、判据就是本层阈值 |`,
    '',
  );
  if (违规) {
    推('### 违规明细（**必须修**）', '', '| # | 规则 | from | to | 符号 | n |', '|---|---|---|---|---|---|');
    审计结果.violations.forEach((v, i) => 推(`| ${i + 1} | ${v.rule} | \`${v.from}\` | \`${v.to}\` | ${逃(v.symbols.join('·'))} | ${v.n} |`));
    推('');
  } else {
    推('```json', '"violations": []', '```', '');
  }

  /* §4.0 规则 ⑤：棘轮 + 合计（逐文件明细搬到明细页 §4.0 —— 索引页要省 token 给 ⑥⑦） */
  推('### §4.0 规则 ⑤ 棘轮：通用内核 → 势力模块', '',
    '> **势力文件** = `core/battle/` 下前缀命中 ' + 势力文件前缀.map(x => '`' + x + '`').join(' / ') + ' 的 `.gd`（**不含 `fac.gd` / `rule_hooks.gd` 两个注册表**）；**通用内核** = `core/battle/` 其余 + `core/run/**`；**次数** = 该文件 `dependsOn` 指向势力文件的 `n` 之和。',
    `> **棘轮基线**：\`CORE_TO_FACTION_RATCHET_MAX = ${CORE_TO_FACTION_RATCHET_MAX}\` —— **只许往下调，不许往上改**；超过就进 \`violations\`，\`--check\` 直接红。**当前值 ${势力统计.总次数} / 基线 ${CORE_TO_FACTION_RATCHET_MAX}**` +
      (势力统计.低于基线 ? ` → **当前值 ${势力统计.总次数} 低于基线 ${CORE_TO_FACTION_RATCHET_MAX}，可将基线下调到 ${势力统计.总次数}**。`
        : 势力统计.超过基线 ? ` → **超出基线 ${势力统计.总次数 - CORE_TO_FACTION_RATCHET_MAX} 次，必须降回来（新增势力逻辑只能走 Fac 注册表）**。`
          : ' → **与基线持平**。'),
    '',
    `统计范围：**${势力统计.通用文件数}** 个通用内核文件 / **${势力统计.势力文件们.length}** 个势力文件。**合计 ${势力统计.总次数} 次**，集中在：` +
      (势力统计.明细.slice(0, 4).map(x => `\`${x.文件.replace(/^core\//, '')}\` ${x.次数}`).join(' · ') || '（无）') +
      `。**逐模块明细（${势力统计.明细.length} 行）见明细页 §4.0。**`,
    '');

  /* §4.0b 规则 ⑤ 的豁免文件：**必须**点名势力的派发 / 判定注册表（单列、不计入棘轮） */
  if (势力统计.豁免明细 && 势力统计.豁免明细.length) {
    推('**规则 ⑤ 的注册表文件**（`规则五豁免文件` = `core/battle/fac.gd` / `core/battle/rule_hooks.gd`：'
      + '本身**必须**点名势力 / 职业模块的派发 · 判定注册表；单列出来是为了不让它们变成「看不见的耦合」'
      + '—— 数字照样打印，只是**不进棘轮**）：', '');
    推('| 注册表文件 | 引用的势力文件数 | 引用次数（不计入 ⑤） | 明细（`→ 势力文件(n)`） |', '|---|---|---|---|');
    for (const x of 势力统计.豁免明细) {
      const 片 = x.边.map(e => `\`${e.to.replace(/^core\/battle\//, '')}\`(${e.n})`);
      推(`| \`${x.文件}\` | ${x.势力文件数} | ${x.次数} | ${片.join(' ')} |`);
    }
    推('', `> 合计 **${势力统计.豁免明细.reduce((a, x) => a + x.次数, 0)}** 次。两处都是**收敛点**（\`fac.gd\` = 势力特色注册表，\`rule_hooks.gd\` = 规则钩子 / 出牌门槛顺序表）：其它通用内核文件只许调它们的接口，自己不许点名势力模块。`, '');
  }

  推('**势力 → 势力横向引用**（不计入规则 ⑤；这里只列**跨谱系**的，ATX 家族内部的见明细页 §4.4）：', '');

  if (跨谱系.length) {
    推('| from | to | n | 谱系 |', '|---|---|---|---|');
    for (const x of 跨谱系) 推(`| \`${x.from}\` | \`${x.to}\` | ${x.n} | ${势力谱系(x.from)} → ${势力谱系(x.to)} |`);
    推('', `> 另有 **${同谱系边}** 条同谱系（ATX 家族内部）横向引用；全表（${势力统计.横向.length} 条边 / ${势力统计.横向.reduce((a, x) => a + x.n, 0)} 次）见明细页 §4.4。`);
  } else 推('- 无。');
  推('');

  /* §4.0c 规则 ⑥：豁免文件的「表外」不许点名势力 / 职业模块 */
  const 豁审 = 审计结果.豁免审计;
  推('### §4.0c 规则 ⑥ 豁免文件审计：登记表 / 分派区**之外**点名模块 = 违规', '',
    '> **为什么**：⑤ 把 `fac.gd` / `rule_hooks.gd` 列为豁免（它们**必须**点名模块），**豁免必须划边界** —— 否则往注册表里搬一段「是不是某个势力」就能让 ⑤ 变好看。',
    '> **判据（现扫，不写死行号）**：允许区域 = ① 顶层 `const` / `static var` 的 `{…}` `[…]` 声明块（`顺序` / `ORDER` / 映射表）② `match …:` 块 ③ 条件含 `势力 ==` / `势力 in` 的 `if` / `elif` 块；**区域外**出现任何势力 / 职业模块名即违规。',
    '');
  推('| 注册表文件 | 允许区域 | 区内引用行 | 区外引用行 | 结果 |', '|---|---|---|---|---|');
  for (const x of 豁审.明细) 推(`| \`${x.文件}\` | ${x.允许区域} | ${x.区内行数} | ${x.区外行数} | ${x.区外行数 ? '**✗ 违规**' : '**✓ 0 违规**'} |`);
  推('');
  if (豁审.违规数) {
    推(`**规则 ⑥ 违规 ${豁审.违规数} 处**（逐条见上面的违规明细）：`, '');
    for (const v of 豁审.违规) 推(`- \`${v.from}\` → ${v.symbols.join(' · ')}`, '');
  } else {
    推(`- **0 违规** ✓ 两个注册表文件的模块引用（${豁审.明细.reduce((a, x) => a + x.区内行数, 0)} 行 / ${豁审.模块类名们.length} 个模块）全部在允许区域里。`, '');
  }

  /* §4.5 规则 ⑦：体积棘轮（索引页只放摘要；逐条对照见明细页 §4.5b）—— 放在 §4 末尾 */
  const 体 = 审计结果.体积;

  /* §4.1 只读调用：索引页只放聚合表，逐条在明细页 */
  const 聚合 = new Map();
  for (const c of 审计结果.只读调用) {
    if (!聚合.has(c.目标)) 聚合.set(c.目标, { 目标: c.目标, 符号们: new Set(), n: 0 });
    const 项 = 聚合.get(c.目标);
    项.符号们.add(c.符号); 项.n += c.n;
  }
  推('### §4.1 审计证据：表现层对 `core/**` 的**读接口**调用（聚合）', '',
    `> 这些**不算违规**（只读、纯计算、无副作用），共 **${审计结果.只读调用.length}** 处 / **${new Set(审计结果.只读调用.map(c => c.符号)).size}** 个符号 —— 列出来是为了证明第 ④ 条不是「没扫到」而是「扫到了但都是读接口」。**逐条清单（调用方 × 符号 × n）见明细页 §4.1。**`, '');
  if (聚合.size) {
    推('| 目标模块 | 只读符号数 | 调用次数 |', '|---|---|---|');
    for (const 项 of [...聚合.values()].sort((a, b) => b.n - a.n || (a.目标 < b.目标 ? -1 : 1))) {
      推(`| \`${项.目标}\` | ${项.符号们.size} | ${项.n} |`);
    }
  } else 推('- （无）');
  推('');

  推('### §4.2 层间豁免白名单（**唯一允许的反向依赖例外**，明示出来供 Reviewer 复核）', '',
    `> 共 **${审计结果.豁免.length}** 条，全部来自脚本里的 \`层间豁免\` 常量（**只许加行、不许放宽到文件级**，必须写明 \`to\` + 理由）。没有列在这里的反向依赖一律进 \`violations\`。`, '');
  if (审计结果.豁免.length) {
    推('| 规则 | from | to | 符号 | n | 理由 | 实际调用 |', '|---|---|---|---|---|---|---|');
    for (const x of 审计结果.豁免) {
      推(`| ${x.rule} | \`${x.from}\` | \`${x.to}\` | ${x.symbols.join('·')} | ${x.n} | ${逃(x.理由)} | ${逃((x.实际调用 || []).join(' · ')) || '—'} |`);
    }
  } else 推('- （无）');
  推('');
  推('### §4.3 其余自检项（信息项，不算违规）', '',
    `- **自环依赖**（文件依赖自己）：**${审计结果.自环.length}** 处${审计结果.自环.length ? '：' + 审计结果.自环.join(' · ') : ''}。`,
    `- **重复 \`class_name\`**：**${审计结果.重复类名.length}** 处${审计结果.重复类名.length ? '：' + 审计结果.重复类名.map(x => x.类名).join(' · ') : ''}。`,
    `- **双向依赖对**：**${审计结果.双向.length}** 对（明细见明细页 §3.5）。`,
    `- **解不出的 \`res://*.gd\` 路径**：**${统计.资源未解析数}** 处${统计.资源未解析数 ? '（逐条见 JSON 的 `unresolvedResources`；工具**不猜**它们指向哪个 `.gd`）' : '。'}`,
    `- **不是 \`.gd\` 的资源路径**（\`.tscn\` / \`.ttf\` / \`.json\` 等，不进依赖图）：**${统计.非gd资源数}** 处（逐条见 JSON 的 \`nonGdResourcePaths\`）。`,
    `- **目录路径**（\`res://data/js\` 这种没有扩展名的，不是资源、不进依赖图）：**${统计.目录路径数}** 处。`,
    `- **缺锚点**（§1 里打 \`—\` 的符号）：**${锚点们.缺.length}** 处${锚点们.缺.length ? '：' + 锚点们.缺.slice(0, 12).map(s => '`' + s + '`').join(' · ') : '。'}`, '');

  /* §4.5 规则 ⑦ 摘要（本页只放状态 + 最大的五个；登记表全表在明细页 §4.5b） */
  推('### §4.5 规则 ⑦ 体积棘轮（`SIZE_RATCHET`：token 只许下降、不许上调）', '',
    `> **为什么**：拆过的大文件还会再长回去。超过 **${体.行上限}** 行 或 **${体.token上限}** token 的**既有**文件逐个登记上限，**只许下调**；超过登记值即 \`violations\`。**未登记**的新大文件只进 §0.5 的警告清单（不判红，但要求先拆再加功能）。`,
    `> **当前**：登记 **${体.登记数}** 个 · 上限合计 **${体.登记合计上限}** token · 超限 **${体.超限数}** 个${体.已不存在.length ? ` · 已不存在 ${体.已不存在.length} 个` : ''} · 未登记且超限的新文件 **${体.警告数}** 个。**登记表全表（当前值 / 余量 / 行数）见明细页 §4.5b。**`,
    '- **最大的五个**：' + 体.已登记.slice(0, 5).map(x => '`' + x.路径 + '`=' + x.上限).join(' · '), '');

  /* §4.6 规则 ⑧ 摘要（本页只放状态；登记清单全表在明细页 §4.6b） */
  const 棘 = 审计结果.注释;
  推('### §4.6 规则 ⑧ 注释占比棘轮（`COMMENT_RATCHET`：登记文件必须一直待在本层阈值以内）', '',
    `> **为什么**：**历史叙述、来源标签、直译式注释**会越堆越厚（CR-1 ~ CR-4 的清理量就是证据）。登记清单里的文件一旦超过**本层阈值**（生产 **${百分比(棘.行上限)}** / \`tests/**\` **${百分比(棘.测试行上限)}**）即 \`violations\`；**登记表只有路径、不记数值** —— 没越阈值往里面加注释是允许的。未登记且超阈值的只进 §0.5 警告。`,
    `> **当前**：登记 **${棘.登记数}** 个 · 超阈值 **${棘.超限数}** 个${棘.已不存在.length ? ` · 已不存在 ${棘.已不存在.length} 个` : ''} · 未登记且超阈值 **${棘.警告数}** 个（明细页 §4.6b 有全表）。`);
  return L.join('\n') + '\n';
}

function 渲染明细(文件们, 类索引, 统计, 审计结果, 锚点们, 索引体积) {
  const L = [];
  const 推 = (...x) => L.push(...x);
  const 违规 = 审计结果.violations.length;
  const 势力统计 = 审计结果.内核势力;

  推(抬头, 明细标题, '',
    '> **这是明细页**：索引页 `Godot-RouteMap.md` 的 §2 / §3 / §4.1 明细 / §4.4 全表 + §5 怎么用。**会话开机不必读它**。',
    '> **别整份读**：定位某个文件 / 符号用 `grep` 本页，或 `node godot/tools/route_query.mjs <符号|文件路径>` 只取切片。口径、扫描范围、已知限制与索引页同源（同一个脚本、同一次扫描）。',
    `> **体积（D1 口径）**：索引页 \`Godot-RouteMap.md\` **${索引体积.字节}** 字节 / 估算 **${索引体积.estTokens}** token（上限 **${索引TOKEN上限}**）${索引体积.超限 ? '**✗ 超限**' : '**✓**'}。本页体积见 \`node godot/tools/build_godot_routemap.mjs\` 的终端输出与 JSON 的 \`outputs.detail\`（本页自己写入自己的体积会变成自指的数字）。`,
    ...公共提醒(统计, 违规),
    '', '---', '',

    '## §0.5b CR-1 两个示范文件的改前 / 改后对照（索引页 §0.5 省 token 搬过来的）',
    '',
    '> **同一套公式、同一套注释口径**（`2cd879e` = CR-1 开工前）：',
    '',
    '| 文件 | 改前（commit `2cd879e`） | 改后（当前源码） | 变化 |',
    '|---|---|---|---|',
    ...改前改后行们(文件们),
    '',
    '> 注：改前是本工具**同一口径**下对 `2cd879e` 实测的值；施工单 §2 / §3 里手写的 78,217 / 148,829 字节是 Review 当时的测量点，与本行的差只是测量点 / 行尾口径，**数字以本表为准**。',
    '',

    '## §2 四层每个 `.gd` 的职责 / 行数 / `class_name` / 核心函数',
    '',
    '> **核心函数** = 该文件**公开**（不以 `_` 开头）函数里，按「**全仓被别的文件直接调用次数**」降序、同分按行号升序取前 **15** 个；`(n)` = 外部调用次数，`(0)` 省略不写。完整函数表（含签名 / 返回类型 / 行号 / 是否 static / 注释）在 `协作/架构/Godot-AST依赖清单.json` 的 `files[].funcs[]`。',
    '> **`(n)` 的口径**：只数 `类名.函数名(` 这种**静态调用**。实例方法（`session.start_new_run(...)` / `view.setup(...)`）**一律记 0** —— 所以会话门面与表现层视图的「核心函数」实际是**按行号顺序**的前 15 个（`GameSession` 的口子请直接看 §2.2 / JSON 的 `files[].funcs[]`，或跑 `node godot/tools/route_query.mjs GameSession`）。',
    '> **`职责`** 一律取该文件**首行 `##` 文档注释**（不是人写的摘要，扫出来的）。');
  for (const 名 of [...层们, '其他']) {
    const 集 = 文件们.filter(f => f.层 === 名);
    if (!集.length) continue;
    推('', `### §2.${层们.includes(名) ? 层们.indexOf(名) + 1 : 5} ${层标题[名]} —— ${集.length} 个文件 · ${集.reduce((a, f) => a + f.行数, 0)} 行`, '',
      '| 文件 | class_name | extends | 行 | 字节 | 估算 token | 注释占比 | const | func | 核心公开函数（前 15，按外部调用次数） | 职责（首行 `##`） |',
      '|---|---|---|---|---|---|---|---|---|---|---|');
    for (const f of 集) {
      const 核 = 关键函数(f);
      推(`| \`${f.相对}\` | ${f.类名 ? '`' + f.类名 + '`' : '—'} | ${f.父类 ? '`' + f.父类 + '`' : '—'} | ${f.行数} | ${f.字节} | ${f.estTokens} | ${百分比(f.注释占比)} | ${f.常量.length} | ${f.函数.length} | ${核} | ${逃(f.职责) || '—'} |`);
    }
  }
  推('');

  /* ---- §3 依赖矩阵 ---- */
  const 生产 = 文件们.filter(f => f.层 !== 'tests');
  推('---', '', '## §3 核心模块的正向与反向依赖矩阵',
    '',
    '> **口径**：依赖 = 「A 的**代码**里出现了 B 的 `class_name`」或「A `preload/load` 了 B」；`n` = 该类名在 A 里出现的**次数**（不是去重符号数）。**`tests/` 的依赖不参与矩阵**（测试本来就该认识所有层），它们只出现在 JSON 的 `files[].dependsOn` 里。',
    '', '### §3.1 层间依赖矩阵（行 = 依赖方，格 = `边数 / 文件数`）', '',
    '| 从 \\ 到 | core | session | presentation | tests | 合计出边 |', '|---|---|---|---|---|---|');
  for (const 从 of [...层们, '其他']) {
    const 集 = 文件们.filter(f => f.层 === 从);
    if (!集.length) continue;
    const 格 = [];
    let 合 = 0;
    for (const 到 of 层们) {
      const 边 = 集.reduce((a, f) => a + f.dependsOn.filter(e => e.layer === 到).length, 0);
      const 文 = new Set(集.flatMap(f => f.dependsOn.filter(e => e.layer === 到).map(e => f.相对))).size;
      合 += 边;
      格.push(边 ? `${边} / ${文}` : '—');
    }
    推(`| **${从}** | ${格.join(' | ')} | ${合} |`);
  }
  推('');

  /* 3.2 反向：被依赖最多的模块 */
  const 被依赖Top = [...生产]
    .map(f => ({ f, 入: f.被依赖.filter(x => 层Of(x.from) !== 'tests') }))
    .filter(x => x.入.length)
    .sort((a, b) => b.入.length - a.入.length || (a.f.相对 < b.f.相对 ? -1 : 1))
    .slice(0, 22);
  推('### §3.2 反向依赖：被最多模块引用的文件（生产层 top 22）', '',
    '| # | 文件 | class_name | 被依赖文件数 | 依赖边数 | 谁在依赖它（前 6） |', '|---|---|---|---|---|---|');
  被依赖Top.forEach((x, i) => {
    推(`| ${i + 1} | \`${x.f.相对}\` | ${x.f.类名 ? '`' + x.f.类名 + '`' : '—'} | ${x.入.length} | ${x.入.reduce((a, b) => a + b.n, 0)} | ${逃(x.入.slice(0, 6).map(y => y.from).join(' · '))} |`);
  });
  推('');

  /* 3.3 正向：每个生产文件依赖谁 */
  推('### §3.3 正向依赖：每个生产文件依赖谁（`→ 目标(n)`，括号里是被引用的符号）', '');
  for (const 名 of [...层们.filter(x => x !== 'tests')]) {
    const 集 = 生产.filter(f => f.层 === 名 && f.dependsOn.length);
    if (!集.length) continue;
    推(`**${名}/**（${集.length} 个文件有出边）`, '');
    for (const f of 集) {
      const 片 = f.dependsOn.map(e => `→ \`${e.to}\`(${e.n}${e.symbols.length ? '：' + e.symbols.join('·') : ''})`);
      推(...折(`- \`${f.相对}\`：`, 片, 250));
    }
    推('');
  }

  /* 3.4 热函数 */
  const 热 = 文件们.flatMap(f => f.函数.filter(x => (x.外部调用 || 0) > 0).map(x => ({ f, x })))
    .sort((a, b) => (b.x.外部调用 - a.x.外部调用) || (a.f.相对 < b.f.相对 ? -1 : 1) || (a.x.行 - b.x.行))
    .slice(0, 25);
  推('### §3.4 全局热点函数（被别的文件直接调用最多，top 25）', '',
    '| # | 符号 | 所在文件:行 | 外部调用 | 本文件内自调 |', '|---|---|---|---|---|');
  热.forEach((h, i) => {
    推(`| ${i + 1} | \`${h.f.类名 ? h.f.类名 + '.' : ''}${h.x.名}\` | \`${h.f.相对}:${h.x.行}\` | ${h.x.外部调用} | ${(h.x.全仓调用 || 0) - h.x.外部调用} |`);
  });
  推('');

  /* 3.5 双向依赖 */
  推('### §3.5 双向依赖对（A ⇄ B，成对出现的模块耦合）', '',
    `> 共 **${审计结果.双向.length}** 对。双向依赖不是违规（内核里 setup ⇄ deck_flow 这类「互调」是本项目的既有形态），但**改一侧就要看另一侧**。`,
    '');
  if (审计结果.双向.length) {
    推('| # | A | B |', '|---|---|---|');
    审计结果.双向.slice(0, 16).forEach(([a, b], i) => 推(`| ${i + 1} | \`${a}\` | \`${b}\` |`));
    if (审计结果.双向.length > 16) 推('', `> （只列前 16 对，全部 ${审计结果.双向.length} 对见 JSON 的 \`audit.mutualPairs\`。）`);
  } else 推('- 无。');
  推('');

  /* ---- §4.0 规则 ⑤ 逐模块明细（索引页只放合计） / §4.1 明细 / §4.4 全表 ---- */
  推('---', '', '## §4.0 规则 ⑤ 逐模块明细：通用内核 → 势力文件', '',
    `> 口径与索引页 §4.0 同源（同一次扫描）：共 **${势力统计.明细.length}** 个通用模块 / **${势力统计.总次数}** 次 / 棘轮基线 **${CORE_TO_FACTION_RATCHET_MAX}**。`,
    '');
  推('| 通用模块 | 引用的势力文件数 | 引用次数 | 明细（`→ 势力文件(n)`） |', '|---|---|---|---|');
  for (const x of 势力统计.明细) {
    const 片 = x.边.map(e => `\`${e.to.replace(/^core\/battle\//, '')}\`(${e.n})`);
    推(`| \`${x.文件}\` | ${x.势力文件数} | ${x.次数} | ${片.join(' ')} |`);
  }
  推(`| **合计** | — | **${势力统计.总次数}** | 棘轮基线 **${CORE_TO_FACTION_RATCHET_MAX}**（只许下调） |`, '');

  推('## §4.1 审计证据：表现层对 `core/**` 的**读接口**调用全清单', '',
    `> 索引页 §4.1 是这张表的**聚合版**；这里逐条列出（调用方 × 目标模块 × 符号 × n），共 **${审计结果.只读调用.length}** 处。全部**不算违规**（只读、纯计算、无副作用）。`, '');
  if (审计结果.只读调用.length) {
    推('| 调用方（presentation） | 目标模块 | 只读符号 | n |', '|---|---|---|---|');
    for (const c of 审计结果.只读调用) 推(`| \`${c.调用方}\` | \`${c.目标}\` | \`${c.符号}\` | ${c.n} |`);
  } else 推('- （无）');
  推('');

  推('### §4.4 势力 → 势力横向引用（全表，不计入规则 ⑤）', '',
    `> 共 **${势力统计.横向.length}** 条边 / **${势力统计.横向.reduce((a, x) => a + x.n, 0)}** 次引用。规则 ⑤ 只数「通用内核 → 势力文件」，势力之间的横向引用单列在这里 —— 它们同样是耦合，只是拆解顺序排在规则 ⑤ 之后。`, '');
  if (势力统计.横向.length) {
    推('| from | to | 谱系 | n | 符号 |', '|---|---|---|---|---|');
    for (const x of 势力统计.横向) {
      推(`| \`${x.from}\` | \`${x.to}\` | ${势力谱系(x.from)} → ${势力谱系(x.to)} | ${x.n} | ${逃(x.symbols.join('·'))} |`);
    }
  } else 推('- （无）');
  推('');

  /* ---- §4.5 规则 ⑥ 明细 + 规则 ⑦ 登记表全表 ---- */
  const 豁审 = 审计结果.豁免审计;
  推('### §4.5 规则 ⑥ 豁免文件明细（索引页 §4.0c 的全表）', '',
    `> 审计口径见索引页 §4.0c。势力 / 职业模块共 **${豁审.模块类名们.length}** 个（${豁审.模块类名们.map(x => '`' + x + '`').join(' · ')}），被测文件 ${豁审.明细.length} 个。`, '');
  推('| 注册表文件 | 允许区域 | 允许行数 | 区内引用行 | 区外引用行 |', '|---|---|---|---|---|');
  for (const x of 豁审.明细) 推(`| \`${x.文件}\` | ${x.允许区域} | ${x.允许行数} | ${x.区内行数} | ${x.区外行数} |`);
  推('');
  for (const x of 豁审.明细) {
    推(`- \`${x.文件}\` 允许区域里点名的模块：${x.区内模块们.length ? x.区内模块们.map(m => '`' + m + '`').join(' · ') : '（无）'}`, '');
  }

  const 体 = 审计结果.体积;
  推('### §4.5b 规则 ⑦ 体积棘轮登记表（全表，索引页 §4.5 只放摘要）', '',
    `> **上限 = 建表时（CR-3 Batch E）的实测 \`estTokens\`，只许下调**。阈值：> **${体.行上限}** 行 或 > **${体.token上限}** token。当前超限 **${体.超限数}** 个 · 未登记的新大文件警告 **${体.警告数}** 个${体.已不存在.length ? ` · 已不存在 ${体.已不存在.length} 个：${体.已不存在.map(x => '`' + x.路径 + '`').join(' · ')}` : ''}。`,
    '');
  推('| 文件 | 登记上限 token | 当前 token | 余量 | 行 | 状态 |', '|---|---|---|---|---|---|');
  for (const x of 体.已登记) 推(`| \`${x.路径}\` | ${x.上限} | ${x.当前} | ${x.余量} | ${x.行数} | ${x.超 ? '**✗ 超限**' : '✓'} |`);
  推(`| **合计** | **${体.登记合计上限}** | — | — | — | ${体.超限数 ? '✗' : '✓ 全部不超限'} |`, '');
  if (体.警告.length) {
    推('**未登记的新大文件（警告，要求先拆再加功能）**：', '');
    推('| 文件 | 行 | 估算 token | 超了哪一条 |', '|---|---|---|---|');
    for (const w of 体.警告) 推(`| \`${w.路径}\` | ${w.行数} | ${w.estTokens} | ${[w.超行 ? `行 > ${体.行上限}` : '', w.超token ? `token > ${体.token上限}` : ''].filter(Boolean).join(' · ')} |`);
    推('');
  } else 推(`- 未登记且超限的新 \`.gd\`：**0 个** ✓`, '');

  const 棘 = 审计结果.注释;
  推('### §4.6b 规则 ⑧ 注释占比棘轮登记表（全表，索引页 §4.6 只放摘要）', '',
    `> **登记 = 路径清单（\`COMMENT_RATCHET\`，不记数值）**，判据是**本层阈值**：生产代码（\`core/\` \`session/\` \`presentation/\`）> **${百分比(棘.行上限)}**、测试（\`tests/**\`）> **${百分比(棘.测试行上限)}**。登记文件里超阈值 **${棘.超限数}** 个 · 未登记且超阈值 **${棘.警告数}** 个${棘.已不存在.length ? ` · 已不存在 ${棘.已不存在.length} 个：${棘.已不存在.map(x => '`' + x.路径 + '`').join(' · ')}` : ''}。`,
    '> **「余量」列** = 本层阈值换算成的字节数减去当前注释字节（负数 = 已经超了），用来看「还能不能往里写注释」。',
    '');
  推('| 文件 | 层 | 本层阈值 | 当前占比 | 余量（字节） | 行 | 状态 |', '|---|---|---|---|---|---|---|');
  for (const x of 棘.已登记) 推(`| \`${x.路径}\` | ${x.层} | ${百分比(x.阈值)} | ${百分比(x.占比)} | ${x.余量字节} | ${x.行数} | ${x.超 ? '**✗ 超阈值**' : '✓'} |`);
  推(`| **合计** | — | — | — | — | — | ${棘.超限数 ? '✗' : '✓ 全部在阈值以内'} |`, '');
  if (棘.警告.length) {
    推('**未登记且超阈值（警告，要求先清注释）**：', '');
    推('| 文件 | 层 | 行 | 注释字节 | 注释占比 | 阈值 |', '|---|---|---|---|---|---|');
    for (const w of 棘.警告) 推(`| \`${w.路径}\` | ${w.层} | ${w.行数} | ${w.注释字节} | ${百分比(w.占比)} | ${百分比(w.阈值)} |`);
    推('');
  } else 推(`- 未登记且超阈值的 \`.gd\`：**0 个** ✓`, '');

  推('---', '', '## §5 怎么用这份地图（给人和 AI Reviewer）', '',
    '1. **只想知道「改这个要动哪些文件」** → 索引页 §4 合规审计 + 本页 §3.2 反向依赖（谁在依赖它）/ §3.3 正向依赖（它依赖谁）。',
    '2. **想知道「这个符号在哪 / 谁在调它」** → `node godot/tools/route_query.mjs <符号名|文件路径>`（推荐，只吐切片）；或 `grep "符号名" 本页`（§2 / §3.4 都有 `文件:行号`）。',
    '3. **想审「分层有没有塌」** → 只看索引页 §4：`violations: []` 才算合规；规则 ⑤ 的数字**只许往下走**。',
    '4. **机器读** → `协作/架构/Godot-AST依赖清单.json`（`files[].dependsOn` / `dependsBy` / `funcs[]` / `consts[]` / `estTokens` / `commentRatio` / `classIndex` / `violations` / `audit.coreToFactionRatchet`）—— **别整份读**，用 `route_query.mjs` 取切片。',
    '5. **改完代码** → `node godot/tools/build_godot_routemap.mjs` 重建，`node godot/tools/build_godot_routemap.mjs --check` 必须 `0`（三份生成物逐字节一致）。', '');
  return L.join('\n') + '\n';
}
/** 核心公开函数列表（前 15，按外部调用次数；`(n)` 只在 n>0 时写）。 */
function 关键函数(f) {
  const 排 = f.函数
    .filter(x => !x.名.startsWith('_'))
    .sort((a, b) => ((b.外部调用 || 0) - (a.外部调用 || 0)) || (a.行 - b.行))
    .slice(0, 15);
  if (!排.length) return '—';
  return 排.map(x => '`' + 截(x.名, 26) + '`' + ((x.外部调用 || 0) > 0 ? `(${x.外部调用})` : '')).join(' · ');
}

/* ============================ ⑩ 渲染 JSON ============================ */
function 渲染JSON(文件们, 类索引, 统计, 审计结果, 资源, 索引体积, 明细体积) {
  const 势力统计 = 审计结果.内核势力;
  const 出 = {
    generatedFrom: 'godot/**/*.gd（排除 .godot/ 等点开头缓存目录）静态扫描：class_name / extends / 顶层 const / func 与 static func 签名 / 全局 class_name 符号引用 / preload|load 字面量路径 / 字节 + 估算 token + 注释占比',
    tool: 'godot/tools/build_godot_routemap.mjs',
    mode: '静态扫描（不加载、不执行 Godot；所有数字都是静态识别值，不是运行时真值）',
    schema: '与 协作/架构/依赖清单.json 同构并扩展：file / layer / declares / dependsOn[{to,layer,n,symbols}] / bytes / estTokens / commentRatio',
    root: 'godot/',
    tokenEstimate: {
      公式: 'Math.round(CJK字符数 * 1.0 + 其余字符数 / 3.5)',
      CJK判据: '/[\\u2E80-\\u9FFF\\uF900-\\uFAFF\\uFE30-\\uFE4F\\uFF00-\\uFFEF\\u3000-\\u303F]/（按 Unicode 码点计一个字符）',
      注释字节: '以 # 开头的行（含前导空白）+ 行尾 # … 的 UTF-8 字节；字符串字面量里的 # 不算；行尾换行符不计',
      说明: '估算值，不是分词器真值；口径与 CR-1 D1 一致',
    },
    outputs: {
      index: { path: '协作/架构/Godot-RouteMap.md', bytes: 索引体积.字节, estTokens: 索引体积.estTokens, limit: 索引TOKEN上限, overLimit: 索引体积.超限 },
      detail: { path: '协作/架构/Godot-RouteMap-明细.md', bytes: 明细体积.字节, estTokens: 明细体积.estTokens },
      json: { path: '协作/架构/Godot-AST依赖清单.json' },
    },
    layers: [...层们, '其他'].filter(名 => 统计.层统计[名].文件).map(名 => ({
      name: 名,
      title: 层标题[名],
      files: 统计.层统计[名].文件,
      lines: 统计.层统计[名].行数,
      bytes: 统计.层统计[名].字节,
      estTokens: 统计.层统计[名].估算token,
      commentRatio: Number(统计.层统计[名].注释占比.toFixed(4)),
      classNames: 统计.层统计[名].类名,
      consts: 统计.层统计[名].常量,
      funcs: 统计.层统计[名].函数,
      edgesOut: 统计.层统计[名].出边,
      edgesIn: 统计.层统计[名].入边,
      crossLayerEdgesOut: 统计.层统计[名].跨层出边,
    })),
    summary: {
      files: 统计.文件数,
      lines: 统计.总行数,
      bytes: 统计.总字节,
      estTokens: 统计.总估算token,
      commentBytes: 统计.总注释字节,
      commentRatio: Number(统计.总体注释占比.toFixed(4)),
      classNames: 统计.类名数,
      consts: 统计.常量数,
      funcs: 统计.函数数,
      staticFuncs: 统计.静态函数数,
      publicFuncs: 统计.公开函数数,
      innerClasses: 统计.内类数,
      edges: 统计.依赖边数,
      productionEdges: 统计.生产依赖边数,
      productionCrossLayerEdges: 统计.生产跨层边数,
      unresolvedResources: 统计.资源未解析数,
      violations: 审计结果.violations.length,
      coreToFactionRefs: 势力统计.总次数,
      coreToFactionRatchetMax: CORE_TO_FACTION_RATCHET_MAX,
      coreToFactionExemptFiles: 规则五豁免文件,
      coreToFactionExemptRefs: (势力统计.豁免明细 || []).reduce((a, x) => a + x.次数, 0),
      exemptFileOutsideRefs: 审计结果.豁免审计.违规数,
      sizeRatchetFiles: 审计结果.体积.登记数,
      sizeRatchetOverLimit: 审计结果.体积.超限数,
      sizeWarnings: 审计结果.体积.警告数,
      indexEstTokens: 索引体积.estTokens,
      indexTokenLimit: 索引TOKEN上限,
    },
    classIndex: {},
    files: 文件们.map(f => ({
      file: f.相对,
      layer: f.层,
      lines: f.行数,
      bytes: f.字节,
      chars: f.字符数,
      cjkChars: f.cjk字符数,
      estTokens: f.estTokens,
      commentBytes: f.注释字节,
      commentRatio: Number(f.注释占比.toFixed(4)),
      commentLines: f.注释行数,
      trailingCommentLines: f.行尾注释行数,
      className: f.类名 || null,
      classLine: f.类名行,
      extends: f.父类 || null,
      extendsLine: f.父类行,
      innerClasses: f.内类数,
      responsibility: f.职责,
      declares: f.常量.length + f.函数.length,
      consts: f.常量.map(c => ({ name: c.名, line: c.行, doc: c.注 })),
      funcs: f.函数.map(x => ({
        name: x.名,
        line: x.行,
        static: x.static,
        returns: x.返回,
        signature: x.签名,
        callsOutside: x.外部调用 || 0,
        callsTotal: x.全仓调用 || 0,
        doc: x.注,
      })),
      dependsOn: f.dependsOn.map(e => ({ to: e.to, layer: e.layer, n: e.n, symbols: e.symbols, kinds: e.kinds })),
      dependsBy: f.被依赖.map(e => ({ from: e.from, layer: e.layer, n: e.n, symbols: e.symbols })),
    })),
    violations: 审计结果.violations,
    audit: {
      rules: [
        '① core/** 不得引用 session/**',
        '② core/** 不得引用 presentation/**',
        '③ session/** 不得引用 presentation/**',
        '④ presentation/** 不得绕过 GameSession 直接调 core/battle/** 的写接口（判据：类名.函数名( 直接静态调用 + 函数名首字命中写动词/白名单）',
        '⑤ 通用内核文件 → 势力文件 的引用次数 ≤ CORE_TO_FACTION_RATCHET_MAX（棘轮，只许下调）',
        '⑥ 豁免注册表文件（fac.gd / rule_hooks.gd）在登记表 / 分派区之外对势力 / 职业模块的引用 = 0',
        '⑦ SIZE_RATCHET 登记的既有大文件 estTokens 只许下降（未登记的新大文件 > 1000 行 / 12000 token 进 sizeWarnings，不判红）',
        '⑧ COMMENT_RATCHET 登记的 .gd 必须一直待在本层阈值以内（生产 15% / tests 20%），超了即违规（未登记且超阈值进 commentWarnings，不判红）',
      ],
      writeVerbs: 写动词,
      writeInterfaceWhitelist: [...写接口白名单].sort(),
      exemptions: 审计结果.豁免,
      readOnlyCoreBattleCalls: 审计结果.只读调用,
      selfLoops: 审计结果.自环,
      duplicateClassNames: 审计结果.重复类名,
      mutualPairs: 审计结果.双向,
      coreToFactionRatchet: {
        基线: CORE_TO_FACTION_RATCHET_MAX,
        当前值: 势力统计.总次数,
        超过基线: 势力统计.超过基线,
        低于基线: 势力统计.低于基线,
        提示: 势力统计.低于基线 ? `当前值 ${势力统计.总次数} 低于基线 ${CORE_TO_FACTION_RATCHET_MAX}，可将基线下调到 ${势力统计.总次数}`
          : 势力统计.超过基线 ? `当前值 ${势力统计.总次数} 超过基线 ${CORE_TO_FACTION_RATCHET_MAX}，必须降回来` : '与基线持平',
        势力文件: 势力统计.势力文件们,
        判定: '势力文件 = core/battle/ 下前缀命中 势力文件前缀 的 .gd（不含 fac.gd）；通用内核 = core/battle/ 其余 + core/run/**；次数 = dependsOn 指向势力文件的 n 之和',
        明细: 势力统计.明细,
        势力到势力: 势力统计.横向,
      },
      exemptFileAudit: {
        规则: '⑥ 豁免文件（规则五豁免文件）在「登记表 / 分派区」之外对势力 / 职业模块的引用必须为 0',
        判定: '允许区域 = 顶层 const / static var 的 {…} / […] 声明块 + match 块 + 条件含「势力 == / 势力 in」的 if/elif 块；区域外出现任何势力 / 职业模块名即违规',
        模块类名: 审计结果.豁免审计.模块类名们,
        违规数: 审计结果.豁免审计.违规数,
        文件: 审计结果.豁免审计.明细,
      },
      sizeRatchet: {
        规则: '⑦ 体积棘轮：SIZE_RATCHET 登记的既有大文件 estTokens 只许下降；未登记的新大文件超限进 sizeWarnings（不判红）',
        行上限: 审计结果.体积.行上限,
        token上限: 审计结果.体积.token上限,
        登记数: 审计结果.体积.登记数,
        超限数: 审计结果.体积.超限数,
        警告数: 审计结果.体积.警告数,
        登记表: SIZE_RATCHET,
        逐条: 审计结果.体积.已登记,
        已不存在: 审计结果.体积.已不存在,
        sizeWarnings: 审计结果.体积.警告,
      },
      commentRatchet: {
        规则: '⑧ 注释占比棘轮：COMMENT_RATCHET 登记的 .gd 必须一直待在本层阈值以内（生产 15% / tests 20%），超了即 violations；未登记且超阈值只进 commentWarnings（不判红）',
        生产阈值: 审计结果.注释.行上限,
        测试阈值: 审计结果.注释.测试行上限,
        口径: '注释字节 ÷ 文件总字节（与 README「注释约定」的估算口径同源；字符串字面量里的 # 不算）',
        登记形式: '路径清单（数组，不含逐文件数值）；判据 = 本层阈值，不冻结建表时的占比',
        登记数: 审计结果.注释.登记数,
        超限数: 审计结果.注释.超限数,
        警告数: 审计结果.注释.警告数,
        登记表: COMMENT_RATCHET,
        逐条: 审计结果.注释.已登记,
        已不存在: 审计结果.注释.已不存在,
        commentWarnings: 审计结果.注释.警告,
      },
    },
    unresolvedResources: 资源.未解析 || [],
    nonGdResourcePaths: 资源.非gd || [],
    directoryResourcePaths: 资源.目录 || [],
  };
  for (const 名 of [...类索引.keys()].sort()) {
    const f = 类索引.get(名);
    出.classIndex[名] = { file: f.相对, layer: f.层, line: f.类名行 };
  }
  return JSON.stringify(出, null, 1) + '\n';
}

/* ============================ ⑪ --check / 写盘 / CLI ============================ */
function 首个差异行(a, b) {
  const 甲 = a.split('\n'), 乙 = b.split('\n');
  for (let i = 0; i < Math.max(甲.length, 乙.length); i++) {
    if (甲[i] !== 乙[i]) return { 行: i + 1, 现有: 截(甲[i] == null ? '（文件到此结束）' : 甲[i], 90), 应为: 截(乙[i] == null ? '（文件到此结束）' : 乙[i], 90) };
  }
  return null;
}

export function main(opts = {}) {
  const check = !!(opts && (opts.check === true || opts.check === '--check'));
  const write = opts.write !== false && !check;
  const 产物 = 生成(opts);
  const 目标们 = [
    { 名: '协作/架构/Godot-RouteMap.md', 路径: 文档路径, 内容: 产物.md },
    { 名: '协作/架构/Godot-RouteMap-明细.md', 路径: 明细路径, 内容: 产物.明细 },
    { 名: '协作/架构/Godot-AST依赖清单.json', 路径: JSON路径, 内容: 产物.json },
  ];
  const 结果 = [];
  let ok = true;
  for (const t of 目标们) {
    const 现有 = existsSync(t.路径) ? readFileSync(t.路径, 'utf8') : null;   // ★ 逐字节：不做 CRLF 归一
    if (check) {
      const 同 = 现有 !== null && 现有 === t.内容;
      if (!同) {
        ok = false;
        const d = 现有 === null ? null : 首个差异行(现有, t.内容);
        结果.push({ ...t, sync: false, 现有字节: 现有 === null ? 0 : Buffer.byteLength(现有, 'utf8'), 期望字节: Buffer.byteLength(t.内容, 'utf8'), 差异: d });
      } else 结果.push({ ...t, sync: true });
    } else if (write) {
      if (现有 !== t.内容) {
        mkdirSync(dirname(t.路径), { recursive: true });
        writeFileSync(t.路径, t.内容, 'utf8');
      }
      结果.push({ ...t, sync: true, 写入: 现有 !== t.内容 });
    } else {
      /* 只算不写（`main({ write: false })` / 给测试用）：**不写盘，但同样报同步状态**，
       * 这样 `ok` 的语义在三种模式下一致 = 「生成物与源码同步且审计通过」。 */
      const 同 = 现有 === t.内容;
      if (!同) ok = false;
      结果.push({ ...t, sync: 同, 写入: false });
    }
  }
  return {
    ok: ok && !产物.索引体积.超限, sync: ok, check, write,
    统计: 产物.统计, violations: 产物.violations, 审计: 产物.审计, 锚点们: 产物.锚点们,
    索引体积: 产物.索引体积, 明细体积: 产物.明细体积,
    未解析资源: 产物.未解析资源, 非gd资源: 产物.非gd资源, 目录资源: 产物.目录资源, 目标们: 结果,
  };
}

const 是直接运行 = process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url;
if (是直接运行) {
  const check = process.argv.includes('--check');
  let r;
  try { r = main({ check }); } catch (e) {
    console.error('✗ 生成失败：' + (e && e.stack ? e.stack : e));
    process.exitCode = 1;
  }
  if (r) {
    const s = r.统计;
    console.log(`Godot 路由地图 · 静态扫描：${s.文件数} 个 .gd / ${s.总行数} 行 / ${s.总字节} 字节 · 估算 ${s.总估算token} token（注释 ${百分比(s.总体注释占比)}）· class_name ${s.类名数} · const ${s.常量数} · func ${s.函数数}（static ${s.静态函数数}）`);
    console.log(`依赖边：${s.依赖边数}（生产层 ${s.生产依赖边数}，跨层 ${s.生产跨层边数}）· 双向依赖对 ${r.审计.双向.length} · 解不出的 res://*.gd ${s.资源未解析数} · 非 .gd 资源 ${s.非gd资源数} · 目录路径 ${s.目录路径数}`);
    console.log(`架构分层审计：violations = ${r.violations.length === 0 ? '[] ✓' : r.violations.length + ' 处 ✗'}（层间豁免 ${r.审计.豁免.length} 条，见文档 §4.2）`);
    for (const v of r.violations.slice(0, 12)) console.log(`  ✗ [${v.rule}] ${v.from} → ${v.to} : ${(v.symbols || []).join('·')}（n=${v.n}）`);
    {
      const 势 = r.审计.内核势力;
      console.log(`规则 ⑤ 通用内核 → 势力文件：当前 ${势.总次数} / 基线 ${势.基线}` +
        (势.超过基线 ? ' ✗ 超基线' : 势.低于基线 ? `（当前值 ${势.总次数} 低于基线 ${势.基线}，可将基线下调到 ${势.总次数}）` : ' ✓ 持平') +
        ` · 势力文件 ${势.势力文件们.length} 个 / 通用内核 ${势.通用文件数} 个 / 势力→势力 ${势.横向.length} 条边`);
      for (const x of 势.明细) console.log(`    ${x.文件}：${x.势力文件数} 个势力文件 / ${x.次数} 次`);
    }
    {
      const 豁 = r.审计.豁免审计;
      console.log(`规则 ⑥ 豁免文件表外引用：违规 ${豁.违规数} 处` +
        ` · ` + 豁.明细.map(x => `${x.文件} 区内 ${x.区内行数} 行 / 区外 ${x.区外行数} 行`).join(' · '));
      for (const v of 豁.违规.slice(0, 8)) console.log(`    ✗ ${v.from} : ${(v.symbols || []).join('·')}`);
    }
    {
      const 体 = r.审计.体积;
      console.log(`规则 ⑦ 体积棘轮（> ${体.行上限} 行 / > ${体.token上限} token）：登记 ${体.登记数} 个 / 超限 ${体.超限数} 个` +
        (体.超限数 ? ' ✗' : ' ✓') + ` · 未登记的新大文件警告 ${体.警告数} 个` +
        (体.警告数 ? '（见 §0.5 末尾）' : ' ✓') +
        (体.已不存在.length ? ` · 已不存在 ${体.已不存在.length} 个` : ''));
      for (const x of 体.已登记.slice(0, 6)) console.log(`    ${x.路径}：当前 ${x.当前} / 上限 ${x.上限}（余量 ${x.余量}）`);
      for (const w of 体.警告.slice(0, 8)) console.log(`    ⚠ 未登记且超限：${w.路径}（${w.行数} 行 / ${w.estTokens} token）`);
    }
    {
      const 棘 = r.审计.注释;
      console.log(`规则 ⑧ 注释占比棘轮（登记文件必须 ≤ 本层阈值：生产 ${百分比(棘.行上限)} / 测试 ${百分比(棘.测试行上限)}）：登记 ${棘.登记数} 个文件 / 超阈值 ${棘.超限数} 个` +
        (棘.超限数 ? ' ✗' : ' ✓') + ` · 未登记且超阈值 ${棘.警告数} 个` +
        (棘.警告数 ? '（见 §0.5 末尾）' : ' ✓') +
        (棘.已不存在.length ? ` · 已不存在 ${棘.已不存在.length} 个` : ''));
      for (const x of 棘.已登记.slice(0, 6)) console.log(`    ${x.路径}：当前 ${百分比(x.占比)} / 本层阈值 ${百分比(x.阈值)}（余量 ${x.余量字节} 字节）`);
      for (const w of 棘.警告.slice(0, 8)) console.log(`    ⚠ 未登记且超阈值：${w.路径}（${百分比(w.占比)} > ${百分比(w.阈值)}）`);
    }
    console.log(`索引页体积（D1 口径）：${r.索引体积.字节} 字节 / 估算 ${r.索引体积.estTokens} token（上限 ${索引TOKEN上限}）${r.索引体积.超限 ? ' ✗ 超限' : ' ✓'} · 明细页 ${r.明细体积.字节} 字节 / 估算 ${r.明细体积.estTokens} token`);
    if (r.锚点们.缺.length) console.log(`⚠ 缺锚点 ${r.锚点们.缺.length} 处（§1 里打 —，检查函数是否被改名）：${r.锚点们.缺.slice(0, 8).join(' / ')}`);
    for (const t of r.目标们) {
      if (r.check) {
        if (t.sync) console.log(`  ✓ 逐字节一致：${t.名}`);
        else {
          console.log(`  ✗ 不同步：${t.名}（现有 ${t.现有字节} 字节 / 期望 ${t.期望字节} 字节）`);
          if (t.差异) console.log(`      首个差异在第 ${t.差异.行} 行\n      现有：${t.差异.现有}\n      应为：${t.差异.应为}`);
        }
      } else console.log(`  ${t.写入 ? '✎ 已重建' : '· 无变化'}：${t.名}`);
    }
    if (r.check && r.ok) console.log('✓ --check 通过（三份生成物与源码逐字节同步，索引页未超 8,000 估算 token）');
    if (r.check && !r.ok) console.log('✗ --check 失败：先跑 node godot/tools/build_godot_routemap.mjs 重建');
    if (r.violations.length) process.exitCode = 1;
    else if (r.索引体积.超限) process.exitCode = 1;
    else if (r.check && !r.ok) process.exitCode = 1;
  }
}
