/* ============================================================================
 * 符号级自动导航图生成器 —— `docs/实现/RouteMap.md`
 * ----------------------------------------------------------------------------
 * **为什么有它**：主 Agent（Architect）不许在主会话里 `read` 源码，于是每问一句
 *   「`兰斯伤害倍率()` 在哪一行 / `window.__game` 里有没有这个符号 / `tests` 第 [10] 段在哪个文件」
 *   就要**派一个探查子代理**。本工具把这五类问题一次性扫成一张**紧凑高密度索引**，
 *   以后 `grep docs/实现/RouteMap.md` 就能秒答（省一整次派单）。
 *
 * **五个索引**（全部**现扫源码**得出，一个行号都不写死）：
 *   §1 `src/js/` 56 片段：`src/shell.html` 的 `@include` 顺序 / 行数 / 首个顶层入口
 *   §2 `71-改动-4-战斗结构.js`：`战斗结构` 下每个**顶层开关块**的名字、行号、字段数、`开:` 现值
 *   §3 核心跨模块链路：九条链路的**定义行号 + 关键调用行号**（`文件:行号`）
 *   §4 `window.__game` 导出：解析 `99-boot.js` 的 `const G = {…}` + 运行期 `Object.assign` 识别，
 *      按**定义所在片段**归组 + 重复键清单
 *   §5 `tests/*.js`：所有 `console.log('[N] …')` 分段标题与行号 + 基线常数（`rulesSignature` /
 *      `defaultPathBattleLogCount`）的断言位点
 *
 * **三条硬规矩**：
 *   ① **零依赖、零子进程**：只 `fs.readFileSync`；`main()` 返回结果不打印，
 *      测试 / verify 工具直接 `import` 它（DSH 沙箱内子进程禁开 `pipe`，见 铁律 §3.4）。
 *   ② **逐字节决定性**：文件里**不写生成时间**（时间戳会让 `--check` 永远红）；
 *      同一份源码 → 同一个字节序列。
 *   ③ **口径纪律**：本工具**不加载、不执行页面**，所以 §4 的数字一律叫
 *      「**静态扫描识别的导出项**」（`99-boot.js` 字面量去重 + 运行期 `Object.assign` 识别，两段并集去重），
 *      **绝不许**写成运行时 `Object.keys(window.__game).length` 的真值；扫描范围与已知限制见生成物抬头。
 *
 * **硬门禁（`ok`）**：`include错误` 为空 ∧ `缺锚点` 为空 ∧ 行数不越界 ∧（`--check` 时）逐字节同步。
 *   任一条不满足 → `ok = false` → CLI `process.exitCode = 1`，**并且绝不覆盖写生成物**。
 *
 * 用法：node tools/build-route-map.mjs          生成 / 覆盖 `docs/实现/RouteMap.md`
 *       node tools/build-route-map.mjs --check  只校验是否同步（只读、绝不写；不同步 exit 1）
 *       import { main } from './tools/build-route-map.mjs'
 *         `main(['--check'])` ≡ `main({ check: true })`（等价于 CLI 的 --check）
 *         `main({ write: false })` 只算不写；`main({ outPath, minLines, maxLines,
 *          extraChains, shellHtmlText })` 是给 `tests/route_map.js` 用的轻量注入口。
 * ========================================================================== */
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const SRC = join(ROOT, 'src');
const SRC_JS = join(SRC, 'js');
const TESTS = join(ROOT, 'tests');
const 快照路径 = join(ROOT, '协作', '架构快照.json');

export const 输出路径 = join(ROOT, 'docs', '实现', 'RouteMap.md');
export const 抬头 = '<!-- 自动生成：node tools/build-route-map.mjs · 严禁手改 -->';
/* 本图只在 240~350 行之间（超出就说明索引写胖了，见 `自检`）。
   ★ 2026-10-13：上限 340 → 350 —— 抬头补了「静态扫描口径 + 已知限制」两行说明（审查项 1 / 4 / 5），
   与 `协作/审计/src可发现性与RouteMap评估.md` 写的目标区间（250–350 行）对齐。 */
export const 行数下限 = 240, 行数上限 = 350;

const lf = s => String(s).replace(/\r\n/g, '\n');
const 读文本 = p => lf(readFileSync(p, 'utf8'));
const 折 = (前缀, 片段们, 宽 = 255) => {
  const 出 = []; let 行 = 前缀;
  for (const 片 of 片段们) {
    if (行 !== 前缀 && 行.length + 片.length + 1 > 宽) { 出.push(行); 行 = '  ' + 片; }
    else 行 += (行 === 前缀 ? '' : ' ') + 片;
  }
  if (行.trim()) 出.push(行);
  return 出;
};
const 截 = (s, n) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

/* ============================ 字符级扫描（跳注释 / 字符串） ============================
 * 两份「大对象字面量」都要按**顶层成员**切开：`战斗结构 = {…}` 与 `window.__game` 的 `G = {…}`。
 * 注释一律换成空格、换行原样保留 —— 这样切出来的段里**字符下标与源码一一对应**，
 * 于是「成员名在第几行」可以直接算出来（不能靠 `indexOf` 猜）。
 * ========================================================================== */
const 关键字 = new Set(['if', 'for', 'while', 'switch', 'catch', 'return', 'function', 'else', 'do', 'try',
  'typeof', 'new', 'delete', 'void', 'in', 'of', 'class', 'case', 'default', 'await', 'yield', 'get', 'set']);

/** 从 `开括号下标`（必须指向 `{`）扫到这个对象的 `}`，返回顶层成员 `[{文本, 起始行}]`（注释已换成空格）。 */
export function 扫块成员(文本, 开括号下标) {
  const 成员 = [];
  let 深 = 0, 行 = 1 + (文本.slice(0, 开括号下标).match(/\n/g) || []).length;
  let 段行 = 行, buf = '';
  /* 每收一段就把「段起始行」挪到当前行 —— 键的绝对行 = 段起始行 + 键之前那几个换行（见 `扫字面量`）。 */
  const 收 = () => { if (buf.trim()) 成员.push({ 文本: buf, 起始行: 段行 }); buf = ''; 段行 = 行; };
  for (let i = 开括号下标; i < 文本.length; i++) {
    const c = 文本[i], d = 文本[i + 1];
    if (c === '/' && d === '/') { while (i < 文本.length && 文本[i] !== '\n') { buf += ' '; i++; } i--; continue; }
    if (c === '/' && d === '*') {
      i += 2;
      while (i < 文本.length && !(文本[i] === '*' && 文本[i + 1] === '/')) { if (文本[i] === '\n') { 行++; buf += '\n'; } else buf += ' '; i++; }
      i++; buf += ' '; continue;
    }
    if (c === '\n') { 行++; buf += '\n'; continue; }
    if (c === '"' || c === "'" || c === '`') {
      const q = c; buf += c; i++;
      while (i < 文本.length && 文本[i] !== q) {
        if (文本[i] === '\\') { buf += 文本[i]; i++; }
        if (文本[i] === '\n') 行++;
        buf += 文本[i]; i++;
      }
      buf += q; continue;
    }
    if (c === '{' || c === '(' || c === '[') {
      if (深 === 0 && c === '{') { 深 = 1; 段行 = 行; buf = ''; continue; }
      深++; buf += c; continue;
    }
    if (c === '}' || c === ')' || c === ']') {
      if (深 === 1 && c === '}') { 收(); break; }
      深--; buf += c; continue;
    }
    if (c === ',' && 深 === 1) { 收(); continue; }
    buf += c;
  }
  return 成员;
}

/** 一段顶层成员文本 → `{名, 偏移, 键文本, 段}`（这一段的键、键在段里的起点与**原样键文本**，以及它在第几行）。
 *  取不到（展开运算符 `...rest` / 计算属性 `[expr]` / 模板字符串键等）返回 null —— **安全跳过、不崩**。
 *  `键文本` 供 `取值名()` 精确切出键后面那一截（带引号的键也算得对）。 */
export function 取键(段) {
  let s = 段, off = 0;
  const 前导 = (/^\s*/.exec(s) || [''])[0].length;
  off += 前导; s = s.slice(前导).replace(/\s+$/, '');
  let m = /^get\s+([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*\(/.exec(s);
  if (m) {
    const 内 = s.indexOf(m[1]);
    return { 名: m[1], 偏移: off + 内, 键文本: m[1], 段 };
  }
  m = /^([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*(?=[:(,}]|$)/.exec(s);
  if (m && !关键字.has(m[1])) return { 名: m[1], 偏移: off, 键文本: m[1], 段 };
  m = /^(['"][^'"]+['"])\s*:/.exec(s);
  if (m) return { 名: m[1].slice(1, -1), 偏移: off, 键文本: m[1], 段 };
  return null;
}

/** 一段顶层成员文本 → **值那一侧的标识符**（`键: 内部名` 的别名映射 / 简写属性 `键` → 同名）。
 *  值是表达式（`a: 1` / `c: fn() {...}`）时返回 null —— 只认「键指向一个同名可见标识符」这一种写法。 */
export function 取值名(段) {
  const k = 取键(段);
  if (!k) return null;
  const 后 = 段.slice(k.偏移 + k.键文本.length);
  const m = /^\s*:\s*([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*(?=[,}]|$)/.exec(后);
  if (m) return m[1];
  if (/^\s*(?=[,}]|$)/.test(后)) return k.名;   // 简写属性：`{ b }`
  return null;
}

/** `const 名 = {` 这种字面量 → 顶层成员（带**绝对行号**）。 */
function 扫字面量(文本, 声明正则, 说明) {
  const m = 声明正则.exec(文本);
  if (!m) throw new Error(`找不到 ${说明}`);
  const 开括 = 文本.indexOf('{', m.index);
  if (开括 < 0) throw new Error(`${说明} 后面没有 {`);
  const 出 = [];
  for (const 段 of 扫块成员(文本, 开括)) {
    const k = 取键(段.文本);
    if (!k) continue;
    出.push({ 名: k.名, 行: 段.起始行 + (段.文本.slice(0, k.偏移).match(/\n/g) || []).length, 段: 段.文本 });
  }
  return 出;
}

/** 一个值是不是对象字面量：是就把它自己的顶层成员数与字段名列出来。 */
function 值字段(段文本) {
  const i = 段文本.indexOf('{');
  if (i < 0) return null;
  const 子 = 扫块成员(段文本, i);
  const 名们 = 子.map(x => { const k = 取键(x.文本); return k && k.名; }).filter(Boolean);
  return { 数: 名们.length, 名们 };
}

/** 一份「大对象字面量」源码 → `{槽位, 去重, 重复键, 重复明细}`（顶层键，保留出现顺序）。
 *  ⚠ **静态扫描**：只数**字面量槽位**；不解析跨行复杂表达式、条件分支挂载、动态属性名 `G[expr]`。
 *  `重复键` = 同名键的**名字**数组（后者覆盖前者，排查漏改时先看它）。 */
export function 解析导出(文本, 声明正则 = /^const G = \{/m, 说明 = '`const G = {`（window.__game）') {
  const 槽位 = 扫字面量(文本, 声明正则, 说明);
  const 计数 = new Map();
  for (const x of 槽位) 计数.set(x.名, (计数.get(x.名) || 0) + 1);
  const 重复明细 = [...计数.entries()].filter(([, n]) => n > 1);
  return { 槽位, 去重: [...计数.keys()], 重复键: 重复明细.map(([n]) => n), 重复明细 };
}

/* ============================ §1 片段顺序 ============================ */
/** `src/shell.html` 的 `@include js/…` 列表（顺序 = 拼接顺序）+ **两项基本校验**。
 *  ① 重复 include：同一个 `js/xxx.js` 被 `@include` 超过 1 次 → 记 `错误`（只保留**第一次**）；
 *  ② 目标文件存在性：`src/js/xxx.js` 不存在或不是常规文件 → 记 `错误`（该片段不进 `列表`）。
 *  `opts.shellHtmlText` 是给 `tests/route_map.js` 的注入口（不传就读真实 `src/shell.html`）。
 *  返回 `{列表, 错误}`：`错误.length > 0` 时 `main()` 直接判 `ok = false`。 */
export function 片段顺序(opts = {}) {
  const shell = opts.shellHtmlText != null ? lf(String(opts.shellHtmlText)) : 读文本(join(SRC, 'shell.html'));
  const 列表 = [], 错误 = [], 见过 = new Set();
  const re = /<!--\s*@include\s+js\/([^\s>]+?)\s*-->/g;
  let m;
  while ((m = re.exec(shell))) {
    const 名 = m[1];
    if (见过.has(名)) { 错误.push(`重复 @include：js/${名} 被 include 了不止 1 次（只取第一次）`); continue; }
    见过.add(名);
    const 全 = join(SRC_JS, 名);
    let st = null;
    try { st = statSync(全); } catch { st = null; }
    if (!st || !st.isFile()) { 错误.push(`@include 目标不存在或不是常规文件：js/${名}（应有 src/js/${名}）`); continue; }
    列表.push(名);
  }
  return { 列表, 错误 };
}

/** 拆顶层逗号（`const a = 1, b = 2` 这种一行多个声明要能认出来）。 */
function 拆顶层逗号(体) {
  const 出 = []; let 深 = 0, 起 = 0;
  for (let i = 0; i < 体.length; i++) {
    const c = 体[i];
    if (c === '"' || c === "'" || c === '`') {
      const q = c; i++;
      while (i < 体.length && 体[i] !== q) { if (体[i] === '\\') i++; i++; }
      continue;
    }
    if ('([{'.includes(c)) 深++;
    else if (')]}'.includes(c)) 深--;
    else if (c === ',' && 深 === 0) { 出.push(体.slice(起, i)); 起 = i + 1; }
  }
  出.push(体.slice(起));
  return 出;
}

/** 一个片段里**顶格**的顶层定义（函数 / 常量对象 / 对象方法），按出现顺序。 */
export function 顶层定义(行们) {
  const 表 = new Map();
  const 记 = (名, 行) => { if (名 && !关键字.has(名) && !表.has(名)) 表.set(名, 行); };
  for (let i = 0; i < 行们.length; i++) {
    const 行 = 行们[i];
    let m;
    if ((m = /^(?:async\s+)?function\s+([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)/.exec(行))) 记(m[1], i + 1);
    else if ((m = /^(?:const|let|var)\s+/.exec(行))) {
      for (const 片 of 拆顶层逗号(行.replace(/^(?:const|let|var)\s+/, ''))) {
        const n = /^\s*([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*(?:=|$)/.exec(片);
        if (n) 记(n[1], i + 1);
      }
    } else if ((m = /^  ([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*\([^)]*\)\s*\{/.exec(行))) 记(m[1], i + 1);
    else if ((m = /^  ([A-Za-z_$\u4e00-\u9fa5][\w$\u4e00-\u9fa5]*)\s*:\s*(?:function|\()/.exec(行))) 记(m[1], i + 1);
  }
  return 表;
}

/* ============================ §3 九条核心链路（锚点表） ============================
 * 每条锚点 = `[片段, 定位正则]`；脚本现扫源码把行号填进去（**没有锚点行 = 打 `—`**，
 * 并在 CLI 里报「缺锚点」——那是提醒「这条链路被改名 / 删了」，不是脚本坏了）。
 * 正则匹配时**跳过注释行**（`*` / `//` / `/*` 开头的行不算定义 / 调用点）。
 * ========================================================================== */
const 链路 = [
  { 组: '① 阵型几何 —— `05-阵型.js`（正交双排 4×2：前 1..前 4 = slot 0..3 / 后 1..后 4 = slot 4..7）', 项: [
    { 标签: '阵型表 / 正交路数 / 排·路·位名换算', 锚: [['05-阵型.js', /^const 阵型表 = \[/], ['05-阵型.js', /^const 正交路数/], ['05-阵型.js', /^const 行列数/], ['05-阵型.js', /^const 最大列数/], ['05-阵型.js', /^const 行首格/], ['05-阵型.js', /^const 行名/], ['05-阵型.js', /^const 行短名/]] },
    { 标签: 'slot ↔ 排 / 路 / 位名（同路 = 同一 col，对位 = slot ± 4）', 锚: [['05-阵型.js', /^function rowOfSlot/], ['05-阵型.js', /^const colOfSlot/], ['05-阵型.js', /^const slotOf/], ['05-阵型.js', /^const 有这一列/], ['05-阵型.js', /^const 位名/], ['05-阵型.js', /^function 列上所有格/]] },
    { 标签: '阻挡：4 条 1 对 1 关系（前1→后1 … 前4→后4）+ 对照表', 锚: [['05-阵型.js', /^const 阻挡表 = \[/], ['05-阵型.js', /^const 阻挡关系 = \[/]] },
    { 标签: '阻挡位 / 遮挡位 / 对位 / 相邻位（正交十字）/ 被挡吗 / 阻挡束（= col 两格）', 锚: [['05-阵型.js', /^function 阻挡位/], ['05-阵型.js', /^function 遮挡位/], ['05-阵型.js', /^const 对位/], ['05-阵型.js', /^function 相邻位/], ['05-阵型.js', /^function 被挡吗/], ['05-阵型.js', /^function 阻挡束/]] },
    { 标签: '出击上限（Lv1–3→4 / Lv4–6→5 / Lv7+→6，藏品可破到绝对顶 7）+ 四个常量', 锚: [['05-阵型.js', /^function 出击上限\(/], ['05-阵型.js', /^function 出击上限提示/], ['05-阵型.js', /^function 藏品部署位加成/], ['05-阵型.js', /^function 出击上限按机体等级/], ['05-阵型.js', /^function 出击上限由名册/], ['05-阵型.js', /^const 出击上限初值/], ['05-阵型.js', /^const 等级成长顶/], ['05-阵型.js', /^const 绝对顶/], ['05-阵型.js', /^const 每几级加一台/]] },
    { 标签: '`被挡吗()` 的调用点（掩护 / 破阵 / 反馈 / 射程惩罚唯一判据）', 锚: [['30-射程.js', /被挡吗\(/], ['20-战斗计算.js', /被挡吗\(/], ['71-改动-5-参数入口.js', /被挡吗\(/], ['84-反馈.js', /被挡吗\(/]] },
  ] },
  { 组: '② 射程与阻挡 —— `30-射程.js`（5 类射程 / 破阵突袭 / 被挡 −20 / 落点）', 项: [
    { 标签: '5 类常量 + `rangeKindOf` + 三个 is* 判定', 锚: [['30-射程.js', /^const KIND_MELEE/], ['30-射程.js', /^const KIND_SUPPORT/], ['30-射程.js', /^const RANGE_KIND = \{/], ['30-射程.js', /^function rangeKindOf/], ['30-射程.js', /^const isAreaKind/], ['30-射程.js', /^const isHealKind/], ['30-射程.js', /^const isSupportKind/]] },
    { 标签: '`rowReachable`（近战只能打前排，前排全灭才够后排）', 锚: [['30-射程.js', /^function rowReachable/]] },
    { 标签: '兰斯「破阵突袭」三件：`破阵暴露吗` / `近战可达` / `targetableEnemies`', 锚: [['30-射程.js', /^function 破阵暴露吗/], ['30-射程.js', /^function 近战可达/], ['30-射程.js', /^function targetableEnemies/]] },
    { 标签: '`rowBlockPenalty`（直射被挡 −20 的**唯一**实现；狙击 / 秘银免除）', 锚: [['30-射程.js', /^function rowBlockPenalty/], ['30-射程.js', /^const 职业是/], ['30-射程.js', /^function 战斗分类Of/]] },
    { 标签: '`areaSlots`（row / col / cross / all 四类落点）', 锚: [['30-射程.js', /^function areaSlots/]] },
  ] },
  { 组: '③ 伤害 / 命中 / 暴击 / 减免 / 修理 / 标定 —— `20-战斗计算.js`', 项: [
    { 标签: '`hitRate`（命中主公式）+ 兰斯命中 / 隐匿 / 尖兵首闪 的接入点', 锚: [['20-战斗计算.js', /^function hitRate/], ['20-战斗计算.js', /const 兰斯命中 = /], ['20-战斗计算.js', /const 尖兵闪 = /], ['20-战斗计算.js', /隐匿惩罚值\(def/]] },
    { 标签: '`critRate`（暴击 = 10 + 职业 +10 + 兰斯暴击 + 职排暴击）', 锚: [['20-战斗计算.js', /^function critRate/], ['20-战斗计算.js', /const 兰斯暴击 = /], ['20-战斗计算.js', /职排暴击/]] },
    { 标签: '减免管线：`REDUCTIONS` / 装甲 / 破防 / 能力值系数', 锚: [['20-战斗计算.js', /^const REDUCTIONS = \[/], ['20-战斗计算.js', /^const effArmor/], ['20-战斗计算.js', /^const breakSum/], ['20-战斗计算.js', /^const defMul/], ['20-战斗计算.js', /^const statCoef/]] },
    { 标签: '`dmgCore`（伤害主公式）+ `兰斯伤害倍率()` 的乘点', 锚: [['20-战斗计算.js', /^function dmgCore/], ['20-战斗计算.js', /const 兰斯倍 = /]] },
    { 标签: '`resolveAttack`（一次攻击结算）+ 掩护减伤 / 标定引爆 / 武器 debuff 的落点', 锚: [['20-战斗计算.js', /^function resolveAttack/], ['20-战斗计算.js', /const 掩 = /], ['20-战斗计算.js', /标定经济引爆\(ctx/], ['20-战斗计算.js', /标定经济产标\(ctx/], ['20-战斗计算.js', /应用武器debuff\(def/]] },
    { 标签: '`healAmount`（修理量 = 威力 × 射击 ÷ 100）', 锚: [['20-战斗计算.js', /^const healAmount/]] },
    { 标签: '标定经济（全职业传球）：参数 / 层数 / 产标 / 点名 / 狙击加成 / 引爆 / 记录', 锚: [['20-战斗计算.js', /^function 标定经济参数/], ['20-战斗计算.js', /^function 标定经济开/], ['20-战斗计算.js', /^function 标定层数上限/], ['20-战斗计算.js', /^const 标定经济条/], ['20-战斗计算.js', /^function 标定经济层数/], ['20-战斗计算.js', /^function 标定经济产标/], ['20-战斗计算.js', /^function 标定经济点名/], ['20-战斗计算.js', /^function 标定经济狙击加成/], ['20-战斗计算.js', /^function 标定经济引爆/], ['20-战斗计算.js', /^function 标定经济记录/]] },
  ] },
  { 组: '④ 参数读取包装（**所有机制的读表口子**）—— `71-改动-5-参数入口.js`', 项: [
    { 标签: '词条 / 大招冷却 / 对称职业特色 / 敌方职业', 锚: [['71-改动-5-参数入口.js', /^function 词条参数/], ['71-改动-5-参数入口.js', /^function 词条开/], ['71-改动-5-参数入口.js', /^function 大招开场冷却/], ['71-改动-5-参数入口.js', /^function 大招普攻冷却/], ['71-改动-5-参数入口.js', /^function 对称职业特色开/], ['71-改动-5-参数入口.js', /^function 敌方职业/]] },
    { 标签: '敌人机制（隐匿 / 镜甲 / 自爆）', 锚: [['71-改动-5-参数入口.js', /^function 敌人机制开/], ['71-改动-5-参数入口.js', /^function 隐匿命中惩罚/], ['71-改动-5-参数入口.js', /^function 镜甲反弹比例/], ['71-改动-5-参数入口.js', /^function 濒死自爆吗/], ['71-改动-5-参数入口.js', /^function 武器debuff/]] },
    { 标签: 'HP 继承 / 气势总攻', 锚: [['71-改动-5-参数入口.js', /^function HP继承开/], ['71-改动-5-参数入口.js', /^function 按比例算HP/], ['71-改动-5-参数入口.js', /^function 气势总攻开/]] },
    { 标签: 'Feena 主动攻击（残月 Lv10 解锁 / 主动曲射 / 运行期威力）', 锚: [['71-改动-5-参数入口.js', /^function Feena主动攻击开/], ['71-改动-5-参数入口.js', /^function 同步残月武器属性/], ['71-改动-5-参数入口.js', /^function 残月武器可主动/], ['71-改动-5-参数入口.js', /^function 残月武器运行期威力/], ['71-改动-5-参数入口.js', /^function 威力取档/], ['71-改动-5-参数入口.js', /^function 残月武器有主动吗/]] },
    { 标签: '★《兰斯10》战线判据（**纯读、零 rng**）：参数 / 开关 / 命中 / 暴击 / 掩护 / 伤害 / 破阵 / 铁壁 / 索敌', 锚: [['71-改动-5-参数入口.js', /^function 兰斯战线参数/], ['71-改动-5-参数入口.js', /^function 兰斯战线开/], ['71-改动-5-参数入口.js', /^function 兰斯命中修正/], ['71-改动-5-参数入口.js', /^function 兰斯暴击修正/], ['71-改动-5-参数入口.js', /^function 兰斯掩护减免/], ['71-改动-5-参数入口.js', /^function 兰斯伤害倍率/], ['71-改动-5-参数入口.js', /^function 同路索敌倍率/], ['71-改动-5-参数入口.js', /^function 兰斯破阵暴露/], ['71-改动-5-参数入口.js', /^function 同路铁壁护卫/], ['71-改动-5-参数入口.js', /^function 掩护减免值/]] },
    { 标签: '★ 职业排位判据（4 专精 + 2 双态）：参数 / 开关 / 命中 / 暴击 / 伤害 / 修理 / 产标', 锚: [['71-改动-5-参数入口.js', /^function 职业排位参数/], ['71-改动-5-参数入口.js', /^function 职业排位开/], ['71-改动-5-参数入口.js', /^function 职业排位数/], ['71-改动-5-参数入口.js', /^function 职业排位命中修正/], ['71-改动-5-参数入口.js', /^function 尖兵首闪值/], ['71-改动-5-参数入口.js', /^function 职业排位暴击修正/], ['71-改动-5-参数入口.js', /^function 职业排位伤害倍率/], ['71-改动-5-参数入口.js', /^function 职业排位修理倍率/], ['71-改动-5-参数入口.js', /^function 特种产标层数/]] },
  ] },
  { 组: '⑤ AI 索敌与选武器 —— `50-AI.js`（+ 站位权重在 `71-改动-3`）', 项: [
    { 标签: '大招判定与憋大招 / 修理阈值 0.6', 锚: [['50-AI.js', /^const isUltimate/], ['50-AI.js', /^const 憋住大招吗/], ['50-AI.js', /^const ultAllowed/], ['50-AI.js', /^const 修理阈值/]] },
    { 标签: '`targetScore`（站位权重 × 同路索敌倍率 1.35 / 1.10）', 锚: [['71-改动-3-难度调整.js', /^function 站位权重/], ['50-AI.js', /^function targetScore/], ['50-AI.js', /const 权 = /]] },
    { 标签: '武器池与选目标：`weaponPool` / `bestWeaponOn` / `pickSingleTarget` / `pickAreaTarget`', 锚: [['50-AI.js', /^function weaponPool/], ['50-AI.js', /^function bestWeaponOn/], ['50-AI.js', /^function pickSingleTarget/], ['50-AI.js', /^function pickAreaTarget/]] },
    { 标签: '五方针的候选与出手：集中 / 后排 / `chooseAttack` / `chooseHeal` / `grantTargetOf` / `chooseSupport`', 锚: [['50-AI.js', /^function 集中攻击候选/], ['50-AI.js', /^function 攻击后排候选/], ['50-AI.js', /^function chooseAttack/], ['50-AI.js', /^function chooseHeal/], ['50-AI.js', /^function grantTargetOf/], ['50-AI.js', /^function chooseSupport/]] },
    { 标签: '`aiAction` / `enemyAction`（两边各一套）', 锚: [['50-AI.js', /^function aiAction/], ['50-AI.js', /^function enemyAction/]] },
  ] },
  { 组: '⑥ 方针 / 气势 / 嘲讽 / 回合流程 / 开局 —— `60-战斗-1/2/3`', 项: [
    { 标签: '-1 方针与记录：五方针 / 规整 / `pushLog` / `设方针` / `设单位开关`', 锚: [['60-战斗-1-方针与记录.js', /^const 方针们/], ['60-战斗-1-方针与记录.js', /^const 默认方针/], ['60-战斗-1-方针与记录.js', /^const 规整方针/], ['60-战斗-1-方针与记录.js', /^function pushLog/], ['60-战斗-1-方针与记录.js', /^function 设方针/], ['60-战斗-1-方针与记录.js', /^function 设单位开关/], ['60-战斗-1-方针与记录.js', /^function 禁止攻击/], ['60-战斗-1-方针与记录.js', /^const 按防御结算/]] },
    { 标签: '-1 气势与战术指令：`战术集合` / `加气势` / `设战术` / `设全队憋大招` / `战术回合`', 锚: [['60-战斗-1-方针与记录.js', /^const 战术集合/], ['60-战斗-1-方针与记录.js', /^function 加气势/], ['60-战斗-1-方针与记录.js', /^function 设战术/], ['60-战斗-1-方针与记录.js', /^function 设全队憋大招/], ['60-战斗-1-方针与记录.js', /^function 战术回合/]] },
    { 标签: '-1 行动序 / 嘲讽 / 镜甲 / 自爆 / 全场词条（+ 同路铁壁护卫的取调用点）', 锚: [['60-战斗-1-方针与记录.js', /^function actionOrder/], ['60-战斗-1-方针与记录.js', /^function 嘲讽/], ['60-战斗-1-方针与记录.js', /const 卫 = /], ['60-战斗-1-方针与记录.js', /^function 镜甲反弹/], ['60-战斗-1-方针与记录.js', /^function 自爆/], ['60-战斗-1-方针与记录.js', /^function 应用全场词条/]] },
    { 标签: '-2 回合流程：`回合开始` / `空位` / `增援` / `单位动作` / `actOnce` / `runAutoCast` / `resolveAction`', 锚: [['60-战斗-2-回合流程.js', /^function 回合开始/], ['60-战斗-2-回合流程.js', /^function 空位/], ['60-战斗-2-回合流程.js', /^function 增援/], ['60-战斗-2-回合流程.js', /^function 单位动作/], ['60-战斗-2-回合流程.js', /^function actOnce/], ['60-战斗-2-回合流程.js', /^function runAutoCast/], ['60-战斗-2-回合流程.js', /^function resolveAction/], ['60-战斗-2-回合流程.js', /同路铁壁护卫|后方本阵/]] },
    { 标签: '-3 开局与 simulate：`runOverwatch` / `runTurn` / `drainAgain` / `checkResult` / `endTurn` / `开局` / `算意图` / `打一回合` / `simulate`', 锚: [['60-战斗-3-开局与simulate.js', /^function runOverwatch/], ['60-战斗-3-开局与simulate.js', /^function runTurn/], ['60-战斗-3-开局与simulate.js', /^function drainAgain/], ['60-战斗-3-开局与simulate.js', /^function checkResult/], ['60-战斗-3-开局与simulate.js', /^function endTurn/], ['60-战斗-3-开局与simulate.js', /^function 开局\(/], ['60-战斗-3-开局与simulate.js', /^function 算意图/], ['60-战斗-3-开局与simulate.js', /^function 打一回合/], ['60-战斗-3-开局与simulate.js', /^function simulate/]] },
  ] },
  { 组: '⑦ 六大势力钩子 —— `72-势力-1..5`（框架 + 17 个钩子 + 六件条目）', 项: [
    { 标签: '注册表与查询：`注册势力特色` / `势力参数` / `势力启用` / `势力状态` / `势力在场` / `势力记录`', 锚: [['72-势力-1-框架与钩子.js', /^function 注册势力特色/], ['72-势力-1-框架与钩子.js', /^const 势力参数/], ['72-势力-1-框架与钩子.js', /^const 势力启用/], ['72-势力-1-框架与钩子.js', /^function 势力状态/], ['72-势力-1-框架与钩子.js', /^const 势力在场/], ['72-势力-1-框架与钩子.js', /^function 势力记录/]] },
    { 标签: '生命周期钩子：开局 / 回合开始 / 回合结束 / 击破 / 友军攻击后 / 逐段未命中 / 武器用后 / 攻击前', 锚: [['72-势力-1-框架与钩子.js', /^function 势力开局/], ['72-势力-1-框架与钩子.js', /^function 势力回合开始/], ['72-势力-1-框架与钩子.js', /^function 势力回合结束/], ['72-势力-1-框架与钩子.js', /^function 势力击破/], ['72-势力-1-框架与钩子.js', /^function 势力友军攻击后/], ['72-势力-1-框架与钩子.js', /^function 势力逐段未命中/], ['72-势力-1-框架与钩子.js', /^function 势力武器用后/], ['72-势力-1-框架与钩子.js', /^function 势力攻击前/]] },
    { 标签: '数值钩子：`段内命中加成` / 装甲 / 修理 / 闪避 / 防御 / 觉醒 / 伤害倍率 / 威力倍率 / 支援关着 / 卡行', 锚: [['72-势力-1-框架与钩子.js', /^function 段内命中加成/], ['72-势力-1-框架与钩子.js', /^function 势力装甲/], ['72-势力-1-框架与钩子.js', /^function 势力修理/], ['72-势力-1-框架与钩子.js', /^function 势力闪避/], ['72-势力-1-框架与钩子.js', /^function 势力防御/], ['72-势力-1-框架与钩子.js', /^const 势力觉醒值/], ['72-势力-1-框架与钩子.js', /^function 势力伤害倍率/], ['72-势力-1-框架与钩子.js', /^function 势力威力倍率/], ['72-势力-1-框架与钩子.js', /^function 势力支援关着/], ['72-势力-1-框架与钩子.js', /^function 势力卡行/]] },
    { 标签: '六件条目（卫星国防军 SEED / 流星小队 / 月球王国 / 天人 / ATX / 秘银）', 锚: [['72-势力-2-卫星国防军与流星.js', /^注册势力特色\('卫星国防军'/], ['72-势力-2-卫星国防军与流星.js', /^注册势力特色\('流星小队'/], ['72-势力-3-月球王国.js', /^注册势力特色\('月球王国'/], ['72-势力-4-天人与ATX.js', /^注册势力特色\('天人'/], ['72-势力-4-天人与ATX.js', /^注册势力特色\('ATX'/], ['72-势力-5-秘银.js', /^注册势力特色\('秘银'/]] },
  ] },
  { 组: '⑧ 三层反馈与角标 / 摘要 —— `84-反馈.js`（预告 + 即时 + 结算，**全纯读**）', 项: [
    { 标签: '预告：`集中攻击预告` / `打得到位` / `打得到后排` / `攻击武器们` / `大招状态` / `防御姿态吗` / `敌人机制预告` / `预告快照`', 锚: [['84-反馈.js', /^function 集中攻击预告/], ['84-反馈.js', /^function 攻击武器们/], ['84-反馈.js', /^function 打得到位/], ['84-反馈.js', /^function 打得到后排/], ['84-反馈.js', /^function 大招状态/], ['84-反馈.js', /^const 防御姿态吗/], ['84-反馈.js', /^function 敌人机制预告/], ['84-反馈.js', /^function 预告快照/]] },
    { 标签: '即时：`反馈签们`（结构化）/ `反馈标签` / `势力特色短签`', 锚: [['84-反馈.js', /^function 反馈签们/], ['84-反馈.js', /^function 势力特色短签/], ['84-反馈.js', /^function 反馈标签/]] },
    { 标签: '③「看见特色」四层：`职业短述字典` / `势力短述字典` / `特色摘要` / `特色角标们` / `兰斯角标们`', 锚: [['84-反馈.js', /^const 职业短述字典/], ['84-反馈.js', /^const 势力短述字典/], ['84-反馈.js', /^function 特色摘要/], ['84-反馈.js', /^function 特色角标们/], ['84-反馈.js', /^function 兰斯角标们/], ['84-反馈.js', /兰斯角标们\(u, ctx\)\) out\.push/]] },
    { 标签: '机制预告：`气势战术预告` / `标定经济预告` / `标定角标`', 锚: [['84-反馈.js', /^function 气势战术预告/], ['84-反馈.js', /^function 标定经济预告/], ['84-反馈.js', /^function 标定角标/]] },
    { 标签: '结算：`战报统计` / `战报行们` / `本场战报Html` / `是记录大招` / `是记录直射`', 锚: [['84-反馈.js', /^function 战报统计/], ['84-反馈.js', /^function 战报行们/], ['84-反馈.js', /^function 本场战报Html/], ['84-反馈.js', /^function 是记录大招/], ['84-反馈.js', /^function 是记录直射/]] },
  ] },
  { 组: '⑨ 界面 —— `80-界面-1..6` & `92-肉鸽界面-1..2`', 项: [
    { 标签: '80-1 底座：`FACTION_COL` / `势力色` / `界面` 对象（屏 / 编队 / ctx / 方针 / 开关）', 锚: [['80-界面-1-基础与拖动.js', /^const FACTION_COL = \{/], ['80-界面-1-基础与拖动.js', /^const 势力色/], ['80-界面-1-基础与拖动.js', /^const 界面 = \{/]] },
    { 标签: '80-2 顶栏 / 菜单 / 编队：`对话框` / `顶栏` / `菜单屏` / `当前出击上限` / `出击上限说明` / `编队屏`', 锚: [['80-界面-2-顶栏菜单编队.js', /^ 对话框\(/], ['80-界面-2-顶栏菜单编队.js', /^ 顶栏\(\)/], ['80-界面-2-顶栏菜单编队.js', /^ 菜单屏\(\)/], ['80-界面-2-顶栏菜单编队.js', /^ 当前出击上限\(\)/], ['80-界面-2-顶栏菜单编队.js', /^ 出击上限说明\(\)/], ['80-界面-2-顶栏菜单编队.js', /^ 编队屏\(\)/]] },
    { 标签: '80-3 战斗屏：`战斗屏` / `方针栏` / `指令面板` / `单位卡` / `刷卡` / `开战` / `开打` / `播一步` / `到结算`', 锚: [['80-界面-3-战斗屏与方针栏.js', /^ 战斗屏\(\)/], ['80-界面-3-战斗屏与方针栏.js', /^ 方针栏\(/], ['80-界面-3-战斗屏与方针栏.js', /^ 指令面板\(\)/], ['80-界面-3-战斗屏与方针栏.js', /^ 单位卡\(/], ['80-界面-3-战斗屏与方针栏.js', /^ 刷卡\(/], ['80-界面-3-战斗屏与方针栏.js', /^ 开战\(/], ['80-界面-3-战斗屏与方针栏.js', /^ 开打\(\)/], ['80-界面-3-战斗屏与方针栏.js', /^ 播一步\(/], ['80-界面-3-战斗屏与方针栏.js', /^ 到结算\(\)/]] },
    { 标签: '80-4 结算 / 作战记录：`结算屏` / `存本场记录` / `导出反馈Html` / `战斗记录屏`', 锚: [['80-界面-4-结算与作战记录.js', /^ 结算屏\(\)/], ['80-界面-4-结算与作战记录.js', /^ 存本场记录\(\)/], ['80-界面-4-结算与作战记录.js', /^ 导出反馈Html\(\)/], ['80-界面-4-结算与作战记录.js', /^ 战斗记录屏\(\)/]] },
    { 标签: '80-5 肉鸽接线 / 指令动作：`录像屏` / `设某开关` / `选方针` / `点敌人` / `选战术` / `切全队大招` / `切TRANSAM` / `大地图屏`', 锚: [['80-界面-5-肉鸽接线与节点.js', /^ 录像屏\(\)/], ['80-界面-5-肉鸽接线与节点.js', /^ 设某开关\(/], ['80-界面-5-肉鸽接线与节点.js', /^ 选方针\(/], ['80-界面-5-肉鸽接线与节点.js', /^ 点敌人\(/], ['80-界面-5-肉鸽接线与节点.js', /^ 选战术\(/], ['80-界面-5-肉鸽接线与节点.js', /^ 切全队大招\(\)/], ['80-界面-5-肉鸽接线与节点.js', /^ 切TRANSAM\(/], ['80-界面-5-肉鸽接线与节点.js', /^ 大地图屏\(\)/]] },
    { 标签: '80-6 节点动作：`晋升` / `休整` / `前进` / `追击战` / `去音乐鉴赏`', 锚: [['80-界面-6-晋升零件与尾部.js', /^ 晋升\(/], ['80-界面-6-晋升零件与尾部.js', /^ 休整\(/], ['80-界面-6-晋升零件与尾部.js', /^ 前进\(/], ['80-界面-6-晋升零件与尾部.js', /^ 追击战\(\)/], ['80-界面-6-晋升零件与尾部.js', /^ 去音乐鉴赏\(\)/]] },
    { 标签: '92-1 肉鸽界面底座：`肉鸽界面` / `设结果` / `结果条Html` / `最近存档`', 锚: [['92-肉鸽界面-1-大图与记录.js', /^const 肉鸽界面 = \{/], ['92-肉鸽界面-1-大图与记录.js', /^ 设结果\(/], ['92-肉鸽界面-1-大图与记录.js', /^ 结果条Html\(\)/], ['92-肉鸽界面-1-大图与记录.js', /^ 最近存档\(\)/]] },
    { 标签: '92-2 招募 / 奇遇 / 结算：`招募屏` / `奇遇屏` / `肉鸽结算屏` / `队伍卡片Html` / `战斗奖励清单Html`', 锚: [['92-肉鸽界面-2-招募与结算.js', /^ 招募屏\(\)/], ['92-肉鸽界面-2-招募与结算.js', /^ 奇遇屏\(\)/], ['92-肉鸽界面-2-招募与结算.js', /^ 肉鸽结算屏\(\)/], ['92-肉鸽界面-2-招募与结算.js', /^function 队伍卡片Html/], ['92-肉鸽界面-2-招募与结算.js', /^function 战斗奖励清单Html/]] },
  ] },
];

/* ============================ 锚点定位 ============================ */
/** 在一份源码里找第一个匹配（跳过注释行）→ 行号；找不到返回 null。
 *  `^  方法(` 这类**带缩进的**锚点：对「左去空白的行」再试一次（片段里对象方法的缩进有两格 / 四格 / 更多）。 */
export function 找行(行们, re) {
  const 源 = re.source;
  const 带缩进 = /^\^\s+/.test(源);
  const re2 = 带缩进 ? new RegExp('^' + 源.replace(/^\^\s+/, ''), re.flags) : re;
  for (let i = 0; i < 行们.length; i++) {
    const t = 行们[i].trim();
    if (!t || t.startsWith('*') || t.startsWith('//') || t.startsWith('/*')) continue;
    if (re.test(行们[i]) || re2.test(t)) return i + 1;
  }
  return null;
}

/* ============================ 运行期追加的导出 ============================
 * 除了 `99-boot.js` 的 `G` 字面量，还有一条**合法口子**能把东西挂上 `window.__game`：
 *     const 排位接口 = {};  排位接口.职业排位开 = 职业排位开;  Object.assign(window.__game, 排位接口);
 * （施工会话并行改 `99-boot.js` 会撞车时就这么挂 —— `80-界面-2` 第 145–156 行是样板。）
 * 不扫这一段，§4 的「**静态扫描识别的导出项**」就会少十个键 —— 那正是「导航图不准」。
 * ★ 口径：本表数字是**静态扫描识别**值，**不是**运行时 `Object.keys(window.__game).length` 的真值
 *   （本工具不加载、不执行页面；已知限制见生成物抬头与 §4 抬头）。
 * ========================================================================== */
export function 运行期导出(文本们, 顺序, 已在) {
  const 出 = [], 见 = new Set(已在);
  const 键 = '([A-Za-z_$\\u4e00-\\u9fa5][\\w$\\u4e00-\\u9fa5]*)';
  for (const f of 顺序) {
    const 行们 = (文本们.get(f) || '').split('\n');
    const 跳过 = t => !t || t.startsWith('*') || t.startsWith('//') || t.startsWith('/*');
    for (let i = 0; i < 行们.length; i++) {
      const t = 行们[i].trim();
      if (跳过(t)) continue;
      let m = new RegExp('Object\\.assign\\(\\s*window\\.__game\\s*,\\s*' + 键 + '\\s*\\)').exec(t);
      if (m) {
        const 对象 = m[1];
        const re = new RegExp('(?:^|[^\\w$.])' + 对象 + '\\.' + 键 + '\\s*=');
        for (let j = 0; j < 行们.length; j++) {
          if (跳过(行们[j].trim())) continue;
          const mm = re.exec(行们[j]);
          if (mm && !见.has(mm[1])) { 见.add(mm[1]); 出.push({ 名: mm[1], 文件: f, 行: j + 1, 方式: `Object.assign(${对象})` }); }
        }
        continue;
      }
      m = new RegExp('(?:window\\.__game|\\bG)\\.' + 键 + '\\s*=[^=]').exec(t);
      if (m && !见.has(m[1])) { 见.add(m[1]); 出.push({ 名: m[1], 文件: f, 行: i + 1, 方式: '直接赋值' }); }
    }
  }
  return 出;
}

/** 合并「`99-boot.js` 字面量键」与「运行期导出」→ **Set 并集去重**。
 *  同一个键既在字面量、又被运行期挂一次时**只算一项**（`跨层重复` 把这种键名记下来，便于排查）。
 *  这是 `总键数` 的**唯一**算法：`总键数 = new Set([...字面量键, ...运行期键]).size`。 */
export function 合并导出(字面量键们, 运行期们) {
  const 集 = new Set(字面量键们), 跨层重复 = [];
  for (const x of 运行期们) {
    const n = typeof x === 'string' ? x : x.名;
    if (集.has(n)) 跨层重复.push(n); else 集.add(n);
  }
  return { 全部键: [...集], 总键数: 集.size, 跨层重复 };
}

/* ============================ 生成 ============================
 * `生成(opts)`：纯计算，**绝不写文件**（写盘只在 `main()` 里、且只在 `ok === true` 时）。
 * `opts` 注入口（给 `tests/route_map.js`）：`shellHtmlText` / `extraChains`（附加链路锚点）。
 * ========================================================================== */
export function 生成(opts = {}) {
  const { 列表: 顺序, 错误: include错误 } = 片段顺序(opts);
  const 文本们 = new Map();
  for (const 名 of 顺序) 文本们.set(名, 读文本(join(SRC_JS, 名)));
  const 行们Of = 名 => (文本们.get(名) || '').split('\n');
  const 链路们 = [...链路, ...(opts.extraChains || [])];

  /* ---- 快照（规则签名 / 默认路径基线，只读、不改） ---- */
  let 快照 = {};
  try { 快照 = JSON.parse(读文本(快照路径)); } catch { 快照 = {}; }
  const 签名 = String(快照.rulesSignature || '（快照里没有）');
  const 基线 = 快照.simulation && 快照.simulation.defaultPathBattleLogCount;

  const 缺锚点 = [];
  const L = [];
  const 推 = (...x) => L.push(...x);

  /* ---- §2 战斗结构 ---- */
  const 战斗结构文本 = 文本们.get('71-改动-4-战斗结构.js') || '';
  const 战斗结构行们 = 战斗结构文本.split('\n');
  /* 片段缺失（include 列表被改坏）时**不抛**：include错误 已经记下来了，CLI 会以 exit 1 报出来。 */
  const 开关块 = (战斗结构文本 ? 扫字面量(战斗结构文本, /^const 战斗结构 = \{/m, '`const 战斗结构 = {`') : []).map(x => {
    const v = 值字段(x.段);
    const 开 = /开:\s*(true|false)/.exec(x.段);
    let 注 = '';
    for (let i = x.行 - 2; i >= 0 && i > x.行 - 12; i--) {
      const t = 战斗结构行们[i].trim();
      if (!t) break;
      if (t.startsWith('*') || t.startsWith('//')) { 注 = t.replace(/^[*/]+\s*/, '').trim(); break; }
    }
    return { 名: x.名, 行: x.行, 字段: v ? v.数 : 0, 开: 开 ? 开[1] : '', 注: 截(注, 44) };
  }).filter(x => x.字段 > 0 || x.开);

  /* ---- §4 导出（**静态扫描识别**：字面量槽位 + 运行期 Object.assign，两段并集去重） ---- */
  const G文本 = 文本们.get('99-boot.js') || '';
  const 导出 = G文本 ? 解析导出(G文本, /^const G = \{/m) : { 槽位: [], 去重: [], 重复键: [], 重复明细: [] };
  const G槽 = 导出.槽位;
  const 槽数 = G槽.length;
  const 重复 = 导出.重复明细;        // [[键名, 次数], …]：同一个键在 G 里写了两次（后者覆盖前者）
  const 重复键名 = 导出.重复键;
  const 符号们 = 导出.去重;          // G 字面量去重后的键名

  const 定义索引 = new Map();
  for (const 名 of 顺序) {
    for (const [n, l] of 顶层定义(行们Of(名))) if (!定义索引.has(n)) 定义索引.set(n, { 文件: 名, 行: l });
  }
  for (const k of ['MechIcons', 'MechAudio']) {
    if (定义索引.has(k)) continue;
    定义索引.set(k, { 文件: '99-boot.js', 行: 找行(行们Of('99-boot.js'), new RegExp('^  get ' + k + '\\(')) });
  }
  const 按文件 = new Map();
  const 未定位 = [];
  for (const 名 of 符号们) {
    const d = 定义索引.get(名);
    if (!d) { 未定位.push(名); continue; }
    if (!按文件.has(d.文件)) 按文件.set(d.文件, []);
    按文件.get(d.文件).push({ 名, 行: d.行 });
  }
  for (const [f, 项] of 按文件) 项.sort((a, b) => (a.行 || 0) - (b.行 || 0));
  /* 运行期追加（`Object.assign(window.__game, …)` / `G.X = …`）—— 与 `G` 字面量去重后单独成组。 */
  const 运行期 = 运行期导出(文本们, 顺序, 符号们);
  /* 总键数 = 「G 字面量去重键」∪「运行期识别键」的 **Set 并集大小**（同一键只算一次）。 */
  const 合并 = 合并导出(符号们, 运行期);
  const 总键数 = 合并.总键数;

  /* ---- §5 测试分段 ---- */
  const 测试文件们 = readdirSync(TESTS).filter(f => f.endsWith('.js')).sort();
  /* 分段标题三种写法都认：`'…'` / `"…"` / `` `…` ``（标题里**允许有反引号**，例如
     `[1] … \`simulate(…)\` == 改动前`；所以按「引号成对」逐种试，不能用 `[^'"`]` 一刀切）。 */
  const 段正则们 = [
    /console\.log\(\s*'((?:\\n)?\s*)\[([0-9]+[0-9a-zA-Z-]*)\]\s*([^']*)'/,
    /console\.log\(\s*"((?:\\n)?\s*)\[([0-9]+[0-9a-zA-Z-]*)\]\s*([^"]*)"/,
    /console\.log\(\s*`((?:\\n)?\s*)\[([0-9]+[0-9a-zA-Z-]*)\]\s*([^`]*)`/,
  ];
  const 测试段 = [];
  let 段总数 = 0;
  for (const f of 测试文件们) {
    const 行们 = 读文本(join(TESTS, f)).split('\n');
    const 段 = [];
    for (let i = 0; i < 行们.length; i++) {
      let m = null;
      for (const re of 段正则们) { m = re.exec(行们[i]); if (m) break; }
      if (!m) continue;
      const 号 = m[2];
      if (段.some(x => x.号 === 号)) continue;
      段.push({ 号, 行: i + 1, 题: 截(m[3].trim().replace(/\*\*/g, '').replace(/`/g, ''), 16) });
    }
    if (!段.length) continue;
    段总数 += 段.length;
    测试段.push({ 文件: f, 段 });
  }
  const 基线位点 = [];
  for (const f of ['arch.js', 'commands-1-默认路径与方针.js', 'faction-7-补充条目与结果.js']) {
    if (!测试文件们.includes(f)) continue;
    const 行们 = 读文本(join(TESTS, f)).split('\n');
    for (let i = 0; i < 行们.length; i++) {
      if (/defaultPathBattleLogCount|rulesSignature/.test(行们[i])) 基线位点.push({ 文件: `tests/${f}`, 行: i + 1, 文: 截(行们[i].trim(), 66) });
    }
  }
  const 快照位点 = [];
  {
    const 行们 = 读文本(快照路径).split('\n');
    for (let i = 0; i < 行们.length; i++) if (/"(rulesSignature|defaultPathBattleLogCount)"/.test(行们[i])) 快照位点.push({ 行: i + 1, 文: 行们[i].trim() });
  }

  /* ============================ 渲染 ============================ */
  推(抬头,
    '# 符号级自动导航图 · RouteMap',
    '',
    '> **一句话**：本图是给 Agent 用的「**免派定位探针**」——查函数定义行号、跨文件调用链、`window.__game` 导出、`战斗结构` 开关行号、`tests` `[N]` 分段，**直接在这里 `grep` / `read` 即可，不必再派一个探查子代理**。',
    '> **口径**：每个行号都由 `tools/build-route-map.mjs` **现扫源码**得出（`src/shell.html` 的 `@include` 顺序 · `src/js/99-boot.js` 的 `const G = {…}` · `tests/*.js` 的 `console.log(\'[N] …\')`），**一个行号都不写死**；文件里**故意不写生成时间**（否则 `--check` 永远红）。',
    '> **同步纪律**：`src/**` / `tests/**` 一改，本图即过期 —— 交单前跑 `node tools/build-route-map.mjs` 重建 + `node tools/build-route-map.mjs --check`（返回码 `0` = 逐字节一致）。',
    `> **当前快照（全部是「静态扫描识别」值）**：\`src/js\` 片段 **${顺序.length}** · \`window.__game\` **静态扫描识别的导出项 ${总键数} 项**（\`99-boot.js\` 字面量 ${槽数} 槽去重 ${符号们.length} 项 + 运行期 \`Object.assign\` 识别 ${运行期.length} 项，重复键 **${重复键名.length}** 个）· \`tests\` \`[N]\` 分段 **${段总数}**（**${测试段.length}** 个文件）· \`规则签名\` **${签名}** · \`defaultPathBattleLogCount\` **${基线}** · \`VERSION\` **${(/^const VERSION = '([^']+)'/m.exec(文本们.get('00-head.js')) || [, '?'])[1]}**。`,
    '> **导出项数的统计口径**：上面的数字 = **静态扫描识别的导出项**（`99-boot.js` 字面量去重 **+** 运行期 `Object.assign` 识别，两段取 **Set 并集再去重**；同一键两处都出现只算一次）——**不是**运行时 `Object.keys(window.__game).length` 的真值。**扫描范围** = `src/shell.html` 里 `@include` 到的 `src/js/**` 片段源码；**已知限制**：本工具**不加载、不执行页面**（零依赖、零子进程），所以动态计算属性、条件分支挂载、IIFE 闭包内动态导出、执行期才新增的键**一律扫不到**。',
    '> **轻量正则扫描的已知限制**（针对 `顶层定义()` / `运行期导出()` / `扫块成员()`）：三者都是**零依赖行级正则 + 单层花括号深度计数**，只识别标准顶层 `function/const/let/var` 声明、`99-boot.js` 里的单层 `键: 内部名` / 简写属性、以及 `const X = { … }; Object.assign(window.__game, X)` 这一**固定模式**；**不解析**跨行复杂表达式、字符串 / 注释对花括号的干扰（字符串与注释按「跳过」处理，但**不做语法分析**）、动态属性名 `G[expr]`、IIFE 闭包内的动态导出。',
    '',
    '---',
    '',
    `## §1 \`src/js/\` ${顺序.length} 片段构建顺序与行数速查（按 \`src/shell.html\` \`@include\` 顺序）`,
    '',
    '> **读法**：`#` = 拼接顺序（**不是文件名排序**）；片段共享同一个 `<script>`，前一片段的顶层名字后一片段直接用。',
    '',
    '| # | 片段 | 行 | 首个顶层入口（函数 / 对象） |',
    '|---|---|---|---|',
  );
  顺序.forEach((名, i) => {
    const 行们 = 行们Of(名);
    const 入口 = [...顶层定义(行们).entries()].slice(0, 3).map(([n]) => '`' + n + '`').join(' · ');
    L.push(`| ${i + 1} | \`${名}\` | ${行们.length - (行们[行们.length - 1] === '' ? 1 : 0)} | ${入口} |`);
  });

  /* ---- §2 ---- */
  推('---', '', '## §2 `71-改动-4-战斗结构.js` 顶层开关块索引（`战斗结构.*` 总闸）', '',
    `> 一共 **${开关块.length}** 个顶层块；\`开: false\` 一律表示「退回改前 / 只保留几何」。读表入口一律在 \`71-改动-5-参数入口.js\`。`, '',
    '| 行号 | 开关块 | 字段 | `开:` | 一句话（块前注释） |', '|---|---|---|---|---|');
  for (const b of 开关块) L.push(`| \`:L${b.行}\` | \`战斗结构.${b.名}\` | ${b.字段} | ${b.开 ? '`' + b.开 + '`' : '—'} | ${b.注 || '—'} |`);
  推('');

  /* ---- §3 ---- */
  推('---', '', '## §3 核心机制链路与关键代码锚点索引（人工维护分类 + 自动匹配行号）', '',
    '> **两份都自动定位**：左边是**定义**（唯一真相源在哪一行），同一行里用 `·` 分开的多个 `文件:行号` 是**调用点**。找不到锚点时打 `—`（= 这条链路被改名 / 删了，CLI 会以 exit 1 报出「缺锚点」）。',
    '> **边界说明**：机制**分类**、链路**顺序**与**正则锚点**由**人工维护**，脚本只负责自动匹配源码里的**当前行号**；本表**不构成完整静态调用图，也不是运行时依赖图**（不做值流 / 别名分析，不跨函数传播，不追条件分支）。', '');
  for (const g of 链路们) {
    推(`### ${g.组}`, '');
    for (const it of g.项) {
      const 按文件 = new Map();
      for (const [f, re] of it.锚) {
        const 行 = 找行(行们Of(f), re);
        if (行 == null) 缺锚点.push(`${f} ${re}`);
        if (!按文件.has(f)) 按文件.set(f, []);
        按文件.get(f).push(行 == null ? '—' : 行);
      }
      const 片 = [...按文件.entries()].map(([f, 行们2]) => '`' + f + ':' + 行们2.join('/') + '`');
      推(...折(`- ${it.标签}：`, 片));
    }
    推('');
  }

  /* ---- §4 ---- */
  推('---', '', `## §4 \`window.__game\` 静态扫描识别的导出项（共 ${总键数} 项去重：\`99-boot.js\` 字面量 ${槽数} 槽去重 ${符号们.length} 项 + 运行期 \`Object.assign\` 识别 ${运行期.length} 项）→ 定义位置分组索引`, '',
    `> 解析 \`src/js/99-boot.js\` 的 \`const G = {…}\`（**含 getter**），再按**定义所在的 \`src/js/NN-*.js\` 片段**归组（同片段按行号升序）；行号 = 那个符号**首次**被定义的行。**${总键数}** = 上面两段的 **Set 并集去重**结果。`,
    `> ⚠ **口径**：**${总键数}** 是「**静态扫描识别的导出项**」，**不是**运行时 \`Object.keys(window.__game).length\` 的真值 —— 本生成器**不加载、不执行页面**（零依赖、零子进程），所以动态计算属性 \`G[expr]\`、条件分支挂载、IIFE 闭包内动态导出、执行期才新增的键**都扫不到**；反过来，源码里挂了但运行期分支没走到的键**也会被数进来**。`,
    `> **重复键 ${重复键名.length} 个**（同一个键在 \`G\` 里写了两次，后者覆盖前者 —— 排查漏改时先看这里）：${重复.length ? 重复.map(([n, c]) => '`' + n + '`×' + c).join(' · ') : '无'}`, '');
  for (const 名 of 顺序) {
    const 项 = 按文件.get(名);
    if (!项) continue;
    推(...折(`- \`${名}\`（${项.length}）：`, 项.map(x => '`' + x.名 + ':L' + x.行 + '`')));
  }
  if (未定位.length) 推(...折(`- **未定位**（${未定位.length}，只在 \`G\` 里出现的键、源码里没有同名定义，需人工确认）：`, 未定位.map(x => '`' + x + '`')));
  if (运行期.length) {
    推('', `### 4.1 运行期追加（**不在** \`G\` 字面量里）：\`Object.assign(window.__game, …)\` / \`G.X = …\` —— 并行施工改不动 \`99-boot.js\` 时的合法口子（样板 = \`80-界面-2\` 的 \`排位接口\`）；**只扫不猜**，键名一律来自源码赋值语句`, '');
    const 按文件2 = new Map();
    for (const x of 运行期) { if (!按文件2.has(x.文件)) 按文件2.set(x.文件, []); 按文件2.get(x.文件).push(x); }
    for (const [f, 项] of 按文件2) {
      项.sort((a, b) => a.行 - b.行);
      推(...折(`- \`${f}\`（${项.length}，${项[0].方式}）：`, 项.map(x => '`' + x.名 + ':L' + x.行 + '`')));
    }
  }
  推('');

  /* ---- §5 ---- */
  推('---', '', `## §5 \`tests/\` 测试套件 \`[N]\` 分段索引与核心基线常数位点（共 ${段总数} 段 / ${测试段.length} 个文件）`, '',
    '### 5.1 分段标题与行号（`文件` → `[N]:L行 标题`；标题截到 16 字）', '');
  for (const t of 测试段) {
    推(...折(`- \`${t.文件}\`（${t.段.length}）：`, t.段.map(s => `\`[${s.号}]:L${s.行}\` ${s.题}`)));
  }
  推('', `### 5.2 核心基线常数位点（\`rulesSignature\` / \`defaultPathBattleLogCount\`）`, '',
    `> **机器可读真值** = \`协作/架构快照.json\`：\`rulesSignature\` = \`${签名}\` · \`defaultPathBattleLogCount\` = \`${基线}\`（\`tests/arch.js\` [1] 拿它当同步门禁）。`, '');
  for (const x of 快照位点) L.push(`- \`协作/架构快照.json:L${x.行}\` — \`${x.文}\``);
  for (const x of 基线位点) L.push(`- \`${x.文件}:L${x.行}\` — \`${x.文}\``);
  推('', '> **改规则时的连锁**：改 `71-改动-4` / `71-改动-3` / `71-改动-2` / `90-肉鸽-1` 的任一参数 → `rulesSignature` 变 → `tests/arch.js` [1] 红 → 同步 `协作/架构快照.json` + 重跑 `node tools/replay.mjs <旧录像>` 看跨规则诊断；改内核 → `defaultPathBattleLogCount` 变 → `tests/commands-1` [1] 与 `tests/faction-7` [16] 两处断言 + 快照一起改。');

  const 文本 = L.join('\n') + '\n';
  return {
    文本,
    行数: 文本.split('\n').length - 1,
    缺锚点,
    include错误,
    统计: {
      片段数: 顺序.length, 导出槽位: 槽数, 导出符号: 符号们.length, 运行期导出: 运行期.length,
      导出总键: 总键数, 跨层重复: 合并.跨层重复.length, 重复键: 重复键名.length,
      测试段: 段总数, 测试文件: 测试段.length, 开关块: 开关块.length, 签名, 基线,
    },
    开关块, 重复, 运行期,
  };
}

/* ============================ 命令行入口 ============================ */
/** `main(opts)`：`opts` 可以是 `['--check']`（CLI 原样传参）或一个对象。
 *  **返回结果、不打印**（打印在 CLI 块里）—— 测试直接 `import { main }`。
 *
 *  写盘规矩（审查项 3）：
 *    · `check: true`  → **只读**，绝不写任何文件（`已写 = false`），只比对 `同步 = (现有 === 文本)`；
 *    · `write: false` → **只算不写**（`已写 = false`），返回完整计算结果；
 *    · `write` 默认 = `opts.write !== false && !check`：为真**且 `ok === true`** 时才写 `outPath`
 *      （默认 `docs/实现/RouteMap.md`），并设 `已写 = true` / `同步 = true`；
 *      `ok === false` 时**绝不覆盖写坏文件**（由 CLI 报错 + `process.exitCode = 1`）。
 *
 *  硬门禁（审查项 2）：`ok = include错误为空 ∧ 缺锚点为空 ∧ !行数越界 ∧ (!check || 同步)`。
 *  轻量注入口（给 `tests/route_map.js`）：`outPath` / `minLines` / `maxLines` /
 *  `extraChains` / `shellHtmlText`（后者两个透传给 `生成()`）。 */
export function main(opts = process.argv.slice(2)) {
  const 参 = Array.isArray(opts) ? { check: opts.includes('--check') } : (opts || {});
  const check = !!参.check;
  const write = 参.write !== false && !check;
  const outPath = 参.outPath || 输出路径;
  const minLines = 参.minLines != null ? 参.minLines : 行数下限;
  const maxLines = 参.maxLines != null ? 参.maxLines : 行数上限;

  const r = 生成(参);
  const include错误 = r.include错误 || [];
  const 现有 = existsSync(outPath) ? lf(readFileSync(outPath, 'utf8')) : null;
  const 同步 = 现有 === r.文本;
  const 行数越界 = r.行数 < minLines || r.行数 > maxLines;
  const ok = include错误.length === 0 && r.缺锚点.length === 0 && !行数越界 && (!check || 同步);

  const 出 = {
    ...r, ok, 检查: check, 写模式: write, 路径: outPath, 已写: false, 写入: null,
    同步, 一致: 同步, 行数越界, 行数下限: minLines, 行数上限: maxLines,
    上次行数: 现有 == null ? null : 现有.split('\n').length - 1,
  };

  if (!同步) {
    let 首异 = 0;
    const a = (现有 || '').split('\n'), b = r.文本.split('\n');
    while (首异 < Math.max(a.length, b.length) && a[首异] === b[首异]) 首异++;
    出.首个不同行 = 首异 + 1;
    出.现有行 = 现有 == null ? '（文件不存在）' : String(a[首异] == null ? '（文件更短）' : a[首异]).slice(0, 80);
    出.应有行 = String(b[首异] == null ? '（文件更长）' : b[首异]).slice(0, 80);
  }
  /* 只有 write 模式 + ok 才落盘；`check` / `write:false` / `!ok` 一律**一个字节都不写**。 */
  if (write && ok) {
    if (!同步) { writeFileSync(outPath, r.文本, 'utf8'); 出.写入 = outPath; }
    出.已写 = true; 出.同步 = true; 出.一致 = true;
  }
  return 出;
}

const 直接跑 = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (直接跑) {
  const r = main(process.argv.slice(2));
  const s = r.统计;
  console.log('build-route-map：');
  console.log(`  · 片段 ${s.片段数} 个 · 战斗结构开关块 ${s.开关块} 个 · 静态扫描识别的导出项 ${s.导出总键} 项（99-boot.js 字面量 ${s.导出槽位} 槽去重 ${s.导出符号} + 运行期 Object.assign 识别 ${s.运行期导出}，重复键 ${s.重复键}）`);
  console.log(`  · 测试 [N] 分段 ${s.测试段} 个（${s.测试文件} 个文件）· 规则签名 ${s.签名} · 默认路径基线 ${s.基线}`);
  console.log(`  · 生成 ${r.行数} 行（要求 ${r.行数下限}~${r.行数上限} 行）${r.行数越界 ? '  ✗ 行数越界' : '  ✓'}`);

  /* 失败原因逐条列清（无论普通模式还是 --check，只要 !ok 就 exitCode = 1）。 */
  const 原因行 = [];
  let 类数 = 0;
  const 记原因 = (标题, 细节们 = []) => { 类数++; 原因行.push(标题, ...细节们.map(x => '    · ' + x)); };
  if (r.include错误.length) 记原因(`include错误 ${r.include错误.length} 处（src/shell.html 的 @include 列表有问题）`, r.include错误.slice(0, 20));
  if (r.缺锚点.length) 记原因(`缺锚点 ${r.缺锚点.length} 处（链路被改名 / 删了？）`, r.缺锚点.slice(0, 40));
  if (r.行数越界) 记原因(`行数越界：${r.行数} 行不在 ${r.行数下限}~${r.行数上限} 之间（索引写胖了 / 写瘦了）`);
  if (r.检查 && !r.同步) {
    记原因(`不同步：${r.路径} 与源码不一致（第 ${r.首个不同行} 行起）`,
      [`现有：${r.现有行}`, `应有：${r.应有行}`, '修法：node tools/build-route-map.mjs']);
  }

  if (!r.检查) {
    if (r.已写) console.log(`  ✓ 已写入 ${r.写入 || r.路径}（${r.行数} 行）`);
    else if (r.ok) console.log('  ✓ docs/实现/RouteMap.md 已是最新（没有改动）');
  } else if (r.ok) {
    console.log(`  ✓ --check：${r.路径} 与源码完全同步（${r.行数} 行）`);
  }

  if (!r.ok) {
    console.log(`  ✗ 硬门禁未通过（${类数} 类原因）：`);
    原因行.forEach(x => console.log('  ' + x));
    process.exitCode = 1;
  } else {
    if (!r.检查 && !r.已写) console.log('  ✓ 门禁全绿（内容一致，未改盘）');
    else console.log('  ✓ 门禁全绿');
  }
}
export { 链路 };
