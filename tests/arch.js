#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 架构门禁（Architecture 2.0 · 2026-10-13）
 * ----------------------------------------------------------------------------
 * **这个套件只验证「机器可读的架构事实与不变量」** —— 六段，全部是「跑一下、数一数、
 * 比一比」；**绝不触碰任何 `AI速查卡.md` 的散文措辞**（GPT 踩刹车第 1 条：
 * 文档怎么写是文档的事，这里只管**能被机器证伪的事实**）。
 *
 *   [1] **架构快照同步**：`协作/架构快照.json` 的 `gameVersion` / `rulesSignature` /
 *       `modules.shellIncludes` 与当前运行时、`src/shell.html` 的 `@include` **100% 一致**；
 *       快照里点名的每一个模块都真的在 56 个片段里。
 *   [2] **随机数纪律**：`src/js/*.js` 除注释外 **0 处** `Math.random(`；
 *       `readOnlyPresentationModules` 除注释外 **0 处** `ctx.rng(`。
 *   [3] **Simulation / Presentation 隔离（State Owner 边界）** ★ 2026-10-13 Guardian 审查后
 *       **升级为真扫全部 56 个片段**（去注释后）：`.log.push(` 只有 `stateOwners['ctx.log']`
 *       的模块能写；`pushLog(` / `ctx.气势 =` / `ctx.当前战术 =` 只有 `stateOwners.ctx` 的模块能写；
 *       `readOnlyPresentationModules`（含 `92-肉鸽界面-1..2`）**6 个禁令词一个都不许出现**；
 *       且指令阶段连续调 `预告快照` / `算意图` / `选项.枚举` / `战报统计` 前后
 *       `ctx.rng` 调用次数 **0**、双方 `hp/cd/buffs/debuffs`、`ctx.log.length`、`ctx.气势` **零变化**。
 *   [4] **默认路径零污染**：同一场（含特种 / 指挥 / 狙击 / 重装）在
 *       `战斗结构.气势总攻.开 = false` vs `true`（不下战术指令）下 **记录逐字节相等**、
 *       每条记录的 `Object.keys` 集合 **100% 相等**。
 *   [5] **Replay 协议完整性**：`规则签名()` 形如 `r1:xxxxxxxx`；新开的录像同时关联
 *       当前 `游戏版本` 与 `规则签名`；**旧录像（没有这个字段）照样能读**且不被凭空补字段。
 *   [6] **架构债务账本对齐 + Owner 定义自洽**：`协作/架构债务.md` 存在，且快照里每个
 *       `knownDebtIds` 都有登记条目；`stateOwners` 的 `ctx.log` ⊆ `ctx`、
 *       `readOnlyPresentationModules` 与 `readOnlyScope`（`ctx` / `ctx.log` / `RUN`）**完全不相交**。
 *   [7] ★ 2026-10-15 CC **迁移边界**：内核（快照 `migration.kernelModules`）不读禁读全局、
 *       不新增对上层模块的调用（放行清单 = 棘轮，每项挂债务 ID）；规则层 0 处把 `ctx.log` 当输入查询。
 *   [8] ★ 2026-10-15 CC **开牌路径确定性基线**：固定脚本连跑两遍逐字节相同，
 *       且记录条数 = 快照 `simulation.cardPathBattleLogCount`（与 `2788` 对称的第二条真值）。
 *
 * 用法：node tests/arch.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { readFileSync, readdirSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const JS目录 = join(ROOT, 'src', 'js');
const 快照路径 = join(ROOT, '协作', '架构快照.json');
const 债务路径 = join(ROOT, '协作', '架构债务.md');

let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);
const P = (标签, v) => info(`${标签}：${typeof v === 'object' ? JSON.stringify(v) : v}`);

/* ============================================================================
 * 零、扫描工具（**只看代码、不看注释**）
 * ========================================================================== */
/** 去掉注释的源码（**保留换行**，所以行号对得上；字符串 / 模板里的内容一个字节不动）。
 *  为什么不用正则一把梭：`//` 会出现在 `https://…` 这类字符串里，`/*` 也可能出现在文案里 ——
 *  逐字符走一遍、认字符串与模板字面量，是这里唯一稳的做法。 */
function 去注释(源) {
  let out = '';
  let i = 0;
  const n = 源.length;
  let 态 = '普通';                 // 普通 | 单引号 | 双引号 | 模板 | 行注释 | 块注释
  while (i < n) {
    const c = 源[i], d = 源[i + 1];
    if (态 === '普通') {
      if (c === '/' && d === '*') { 态 = '块注释'; i += 2; out += '  '; continue; }
      if (c === '/' && d === '/') { 态 = '行注释'; i += 2; out += '  '; continue; }
      if (c === "'") { 态 = '单引号'; out += c; i++; continue; }
      if (c === '"') { 态 = '双引号'; out += c; i++; continue; }
      if (c === '`') { 态 = '模板'; out += c; i++; continue; }
      out += c; i++; continue;
    }
    if (态 === '块注释') {
      if (c === '*' && d === '/') { 态 = '普通'; i += 2; continue; }
      if (c === '\n') out += '\n';
      i++; continue;
    }
    if (态 === '行注释') { if (c === '\n') { 态 = '普通'; out += '\n'; } i++; continue; }
    /* 字符串 / 模板：转义照抄，遇到同种引号收尾 */
    if (c === '\\') { out += c + (d == null ? '' : d); i += 2; continue; }
    if ((态 === '单引号' && c === "'") || (态 === '双引号' && c === '"') || (态 === '模板' && c === '`')) {
      态 = '普通'; out += c; i++; continue;
    }
    out += c; i++;
  }
  return out;
}
/** 代码（已去注释）里某个正则出现了几次。 */
const 数代码 = (源, 正则) => {
  const 码 = 去注释(源);
  const m = 码.match(new RegExp(正则, 'g'));
  return m ? m.length : 0;
};
/** 原文里出现了几次（**只用来打在屏上做对照**，不作断言）。 */
const 数原文 = (源, 正则) => {
  const m = 源.match(new RegExp(正则, 'g'));
  return m ? m.length : 0;
};
const 读js = f => readFileSync(join(JS目录, f), 'utf8');
/** 有对象键排序的稳定 JSON（比 `JSON.stringify` 稳，用来逐字节比对状态） */
const 稳 = v => {
  if (v == null) return null;
  if (Array.isArray(v)) return v.map(稳);
  if (typeof v === 'function') return '[fn]';
  if (typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v).sort()) o[k] = 稳(v[k]);
    return o;
  }
  return v;
};

/* ============================================================================
 * 载入页面
 * ========================================================================== */
const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
const 界面 = G.界面, 录像 = G.录像, 肉鸽 = G.肉鸽;
const 片段们 = readdirSync(JS目录).filter(f => f.endsWith('.js')).sort();

console.log(`架构门禁：机甲指挥 ${G.version} · ${G.milestone}`);
console.log(`规则签名 = ${G.规则签名()} · src/js 片段 ${片段们.length} 个\n`);

/* ============================================================================
 * [1] 架构快照同步
 * ========================================================================== */
console.log('[1] 架构快照同步（gameVersion / rulesSignature / shellIncludes）');
{
  let 快照 = null;
  if (!existsSync(快照路径)) bad(`找不到 协作/架构快照.json（架构 2.0 的机器可读快照）`);
  else {
    try { 快照 = JSON.parse(readFileSync(快照路径, 'utf8')); } catch (e) { bad(`协作/架构快照.json 不是合法 JSON：${e.message}`); }
  }
  if (快照) {
    /* ① 版本号 */
    if (String(快照.gameVersion) === String(G.version)) ok(`gameVersion 同步：${快照.gameVersion} = __game.version`);
    else bad(`快照的 gameVersion 是 ${快照.gameVersion}，当前 __game.version 是 ${G.version} —— 请更新 协作/架构快照.json`);
    /* ② 规则签名（改了 战斗结构 / 肉鸽数值 的任何参数都会在这里红） */
    const 现签名 = String(G.规则签名());
    if (String(快照.rulesSignature) === 现签名) ok(`rulesSignature 同步：${现签名}（五张规则表：战斗结构 / 难度调整 / 势力特色 / 肉鸽数值 / 守军奖励 未漂移）`);
    else bad('规则参数已变更，请更新 协作/架构快照.json 的 rulesSignature 并核查 Replay 影响' +
      `（快照 ${快照.rulesSignature} ≠ 当前 ${现签名}）`);
    /* ③ @include 列表逐项相等 */
    const shell = readFileSync(join(ROOT, 'src', 'shell.html'), 'utf8').replace(/\r\n/g, '\n');
    const 真列表 = [...shell.matchAll(/@include\s+js\/([^\s]+)/g)].map(m => m[1]);
    const 快列表 = (快照.modules && Array.isArray(快照.modules.shellIncludes)) ? 快照.modules.shellIncludes : [];
    if (真列表.length === 快列表.length && 真列表.every((x, i) => x === 快列表[i])) {
      ok(`modules.shellIncludes 与 src/shell.html 的 @include **逐项相等**（${真列表.length} 项，顺序也一致）`);
    } else {
      const 首个 = 真列表.findIndex((x, i) => x !== 快列表[i]);
      bad(`shellIncludes 与 src/shell.html 的 @include 不一致（真 ${真列表.length} 项 / 快照 ${快列表.length} 项；` +
        `第一处不同在下标 ${首个 < 0 ? '（长度不同）' : 首个}：真 ${真列表[首个] || '—'} / 快照 ${快列表[首个] || '—'}）` +
        ' —— 新增 / 删除 / 重排 JS 模块都要同步 协作/架构快照.json');
    }
    /* ④ modules.count / 文件存在性 */
    if (快照.modules && Number(快照.modules.count) === 真列表.length && 真列表.length === 片段们.length) {
      ok(`modules.count = ${快照.modules.count} = @include 项数 = src/js 里的 .js 文件数`);
    } else {
      bad(`modules.count（${快照.modules && 快照.modules.count}）/ @include（${真列表.length}）/ src/js 文件数（${片段们.length}）三者对不上`);
    }
    const 缺文件 = 真列表.filter(f => !片段们.includes(f));
    if (!缺文件.length) ok(`@include 点名的 ${真列表.length} 个片段在 src/js 里都存在`);
    else bad(`@include 点名了不存在的片段：${缺文件.join('、')}`);
    /* ⑤ 快照里点名的模块（stateOwners / readOnlyPresentationModules）都必须在 56 个片段里 */
    const 点名 = [];
    for (const v of Object.values(快照.stateOwners || {})) if (Array.isArray(v)) 点名.push(...v);
    if (Array.isArray(快照.readOnlyPresentationModules)) 点名.push(...快照.readOnlyPresentationModules);
    const 野的 = [...new Set(点名.filter(f => !真列表.includes(f)))];
    if (!野的.length) ok(`stateOwners / readOnlyPresentationModules 点名的 ${new Set(点名).size} 个模块都在片段清单里`);
    else bad(`快照点名了不在 @include 清单里的模块（名字写错 / 模块已删）：${野的.join('、')}`);
    /* ⑥ simulation 那三个事实（机器可读，不求值 —— 2925 由 commands 那条线自己钉） */
    const sim = 快照.simulation || {};
    if (sim.deterministic === true && sim.rngProvider === 'mulberry32' && Number(sim.defaultPathBattleLogCount) > 0) {
      ok(`simulation：deterministic=true · rngProvider=${sim.rngProvider} · defaultPathBattleLogCount=${sim.defaultPathBattleLogCount}`);
    } else bad(`simulation 那三个字段不对：${JSON.stringify(sim).slice(0, 200)}`);
    /* ⑦ 运行时随机源就是 mulberry32（快照写的是事实，这里验它真是事实） */
    const ctx探 = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 0, 等级: 10 }], 20261013);
    if (String(ctx探.rng).indexOf('0x6D2B79F5') >= 0 && typeof G.mulberry32 === 'function' && String(G.mulberry32).indexOf('0x6D2B79F5') >= 0) {
      ok('模拟随机源的来源确实是 mulberry32（`ctx.rng` 与 `__game.mulberry32` 的源码里都是那个 0x6D2B79F5 常量）');
    } else bad('快照写的 `rngProvider = mulberry32` 与运行时对不上（ctx.rng / __game.mulberry32 里找不到那个常量）');
  }
}

/* ============================================================================
 * [2] 随机数纪律
 * ========================================================================== */
console.log('\n[2] 随机数纪律：源码 0 处 Math.random( · 只读表现层 0 处 ctx.rng(');
{
  let 原文 = 0, 代码 = 0, 坏文件 = [];
  for (const f of 片段们) {
    const 源 = 读js(f);
    原文 += 数原文(源, 'Math\\.random\\(');
    const n = 数代码(源, 'Math\\.random\\(');
    代码 += n;
    if (n) 坏文件.push(`${f}×${n}`);
  }
  P('Math.random( 出现次数', { 原文: 原文, 去注释后: 代码 });
  if (!代码) ok(`src/js 全部 ${片段们.length} 个片段：除注释外 **0 处** \`Math.random(\`（原文 ${原文} 处在注释里）—— 随机数只能走 ctx.rng`);
  else bad(`有 ${代码} 处代码里的 \`Math.random(\`：${坏文件.join('、')} —— 破坏「同种子逐字相同」`);

  /* 只读表现层：一个 ctx.rng 都不许调（调了就说明它在推进随机序列 = 会影响结果） */
  const 只读们 = (() => {
    try { return JSON.parse(readFileSync(快照路径, 'utf8')).readOnlyPresentationModules || []; } catch (e) { return []; }
  })();
  if (!只读们.length) bad('拿不到 readOnlyPresentationModules（协作/架构快照.json 读不出来）');
  else {
    const 坏 = [], 数 = [];
    for (const f of 只读们) {
      if (!片段们.includes(f)) { 坏.push(`${f}（文件不存在）`); continue; }
      const n = 数代码(读js(f), 'ctx\\.rng\\(');
      数.push(`${f}:${n}`);
      if (n) 坏.push(`${f}×${n}`);
    }
    if (!坏.length) ok(`只读表现层 ${只读们.length} 个模块：除注释外 **0 处** \`ctx.rng(\`（${数.join(' ')}）`);
    else bad(`只读表现层里调了 \`ctx.rng(\`：${坏.join('、')}`);
  }
}

/* ============================================================================
 * [3] Simulation / Presentation 隔离（State Owner 边界 · **机器静态写入扫描**）
 * ========================================================================== */
console.log('\n[3] Simulation / Presentation 隔离（真扫 56 个片段的越权写入 + 纯读实测）');
{
  /* ★ 2026-10-13（Guardian 破坏性审查后升级）：这一段原来是「点名的 4 个文件查 3 个词」——
     那**不是**越权检查（换个文件写 `ctx.log.push()` 照样绿）。现在拿 `协作/架构快照.json`
     的 Owner 名单去扫**全部 56 个片段**（去注释后），判据**全在快照里**：
       (a) `.log.push(`                       —— 只有 `stateOwners['ctx.log']` 的模块能写
                                                 （= `pushLog()` 本体的家 = `60-战斗-1-方针与记录.js`）；
       (b) `pushLog(` / `ctx.气势 =` / `ctx.当前战术 =`
                                              —— 只有 `stateOwners.ctx` 的模块能写；
       (c) `readOnlyPresentationModules`（含 `92-肉鸽界面-1..2`）
                                              —— 6 个禁令词一个都不许出现。 */
  let 快照3 = null;
  try { 快照3 = JSON.parse(readFileSync(快照路径, 'utf8')); } catch (e) { /* [1] 已经报过 */ }
  const 主表 = (快照3 && 快照3.stateOwners) || {};
  const 写日志主 = Array.isArray(主表['ctx.log']) ? 主表['ctx.log'] : [];
  const 写ctx主 = Array.isArray(主表.ctx) ? 主表.ctx : [];
  const 只读清单 = (快照3 && Array.isArray(快照3.readOnlyPresentationModules)) ? 快照3.readOnlyPresentationModules : [];
  const 扫 = 正则 => 片段们.map(f => [f, 数代码(读js(f), 正则)]).filter(x => x[1] > 0);
  const 摆 = 们 => 们.map(([f, n]) => `${f}×${n}`).join(' ') || '（一处都没有）';
  let 越权 = 0;
  /* ---- (a) `.log.push(`：只有 `ctx.log` 的 Owner 能写 ---- */
  if (!写日志主.length) bad('拿不到 stateOwners["ctx.log"]（协作/架构快照.json 读不出来 / 是空的）');
  else {
    const 全 = 扫('\\.log\\.push\\(');
    const 越 = 全.filter(x => !写日志主.includes(x[0]));
    P('`.log.push(` 的写入者', 摆(全));
    if (!全.length) bad('56 个片段里一处 `.log.push(` 都没有 —— 判据写错了吧（`pushLog` 本体就写它）');
    else if (越.length) { 越权++; bad(`这些**不在** \`stateOwners["ctx.log"]\` 名单里的模块写了 \`.log.push(\`：${摆(越)} —— 战绩只能从 \`pushLog()\` 进 \`ctx.log\``); }
    else ok(`\`.log.push(\` 的写入者只有 ${写日志主.length} 个 Owner（${摆(全)}）—— 名单外一个都没有`);
  }
  /* ---- (b) `pushLog(` / `ctx.气势 =` / `ctx.当前战术 =`：只有 `ctx` 的 Owner 能写 ---- */
  {
    const 三词 = [
      ['pushLog\\(', 'pushLog('],
      ['ctx\\.气势\\s*(?:\\+|-|\\*|/)?=(?!=)', 'ctx.气势 ='],
      ['ctx\\.当前战术\\s*(?:\\+|-|\\*|/)?=(?!=)', 'ctx.当前战术 ='],
    ];
    if (!写ctx主.length) bad('拿不到 stateOwners.ctx（协作/架构快照.json 读不出来 / 是空的）');
    else for (const [正则, 词] of 三词) {
      const 全 = 扫(正则);
      const 越 = 全.filter(x => !写ctx主.includes(x[0]));
      P(`${词} 的写入者`, 摆(全));
      if (!全.length) bad(`56 个片段里一处 \`${词}\` 都没有 —— 判据写错了吧（引擎自己就在写它们）`);
      else if (越.length) { 越权++; bad(`这些**不在** \`stateOwners.ctx\` 名单里的模块动了 \`${词}\`：${摆(越)} —— 战斗状态只能由 ctx 的 Owner 写`); }
      else ok(`\`${词}\`：只有 stateOwners.ctx 名单里的 ${全.length} 个模块碰它（${摆(全)}）`);
    }
  }
  /* ---- (c) 只读表现层：6 个禁令词一个都不许出现 ---- */
  if (!只读清单.length) bad('拿不到 readOnlyPresentationModules（协作/架构快照.json 读不出来）');
  else {
    const 禁令 = [
      ['ctx\\.rng\\(', 'ctx.rng(', '推进随机序列'],
      ['pushLog\\(', 'pushLog(', '往 ctx.log 塞记录'],
      ['\\.log\\.push\\(', 'ctx.log.push(', '直接写 ctx.log'],
      ['ctx\\.气势\\s*(?:\\+|-|\\*|/)?=(?!=)', 'ctx.气势 =', '改战斗状态'],
      ['levelUp\\(', 'levelUp(', '给单位升级'],
      ['spendWeapon\\(', 'spendWeapon(', '花武器冷却'],
    ];
    let 脏 = 0;
    for (const f of 只读清单) if (!片段们.includes(f)) { 脏++; bad(`只读表现层点名的 ${f} 不在 56 个片段里`); }
    for (const [正则, 词, 说明] of 禁令) {
      const 全 = 扫(正则).filter(x => 只读清单.includes(x[0]));
      if (全.length) { 脏++; bad(`只读表现层里出现 \`${词}\`（${说明}）：${摆(全)}`); }
    }
    if (!脏) ok(`只读表现层 ${只读清单.length} 个模块（${只读清单.join(' / ')}）：除注释外 6 个禁令词` +
      `（\`ctx.rng(\` / \`pushLog(\` / \`ctx.log.push(\` / \`ctx.气势 =\` / \`levelUp(\` / \`spendWeapon(\`）**一个都没有**`);
    else 越权 += 脏;
    /* 原文里的出现次数（只作对照，证明「除注释外」这句不是空话） */
    P('这些词在原文里的出现次数（含注释）', 只读清单.map(f => {
      const 源 = 读js(f);
      const n = 禁令.reduce((a, [re]) => a + 数原文(源, re), 0);
      return n ? `${f}:${n}` : null;
    }).filter(Boolean).join(' ') || '（一处都没有）');
  }
  if (!越权) ok('越权写入静态扫描：全部 56 个片段的 `.log.push(` / `pushLog(` / `ctx.气势 =` / `ctx.当前战术 =` 都在 Owner 名单内');

  /* ---- 运行一次：指令阶段的四个纯读口子，调两遍，前后零变化 ---- */
  const 队 = [
    { 键: 'B1', 位: 0, 等级: 20 },   // 近卫
    { 键: 'B2', 位: 1, 等级: 20 },   // 尖兵
    { 键: 'B3', 位: 2, 等级: 20 },   // 特种
    { 键: 'M2', 位: 3, 等级: 20 },   // 重装
    { 键: 'M1', 位: 4, 等级: 20 },   // 指挥
    { 键: 'CB2', 位: 5, 等级: 20 },  // 狙击
  ];
  const 敌 = [
    { 键: 'shield', 位: 0, 等级: 15 }, { 键: 'berserker', 位: 1, 等级: 15 },
    { 键: 'sniper', 位: 2, 等级: 15 }, { 键: 'jammer', 位: 4, 等级: 15 },
  ];
  const ctx = G.开局(队, 敌, 20261013);
  const 原rng = ctx.rng;
  let 计数 = 0;
  const 包装 = function () { 计数++; return 原rng.apply(null, arguments); };
  const 单位快 = u => ({
    slot: u.slot, hp: u.hp, maxHp: u.maxHp,
    cd: (u.weapons || []).map(w => [w.cd == null ? null : w.cd, w.readyTurn == null ? null : w.readyTurn]),
    buffs: 稳(u.buffs), debuffs: 稳(u.debuffs),
  });
  const 状态 = () => JSON.stringify({
    turn: ctx.turn, 气势: ctx.气势, 累计防御气势: ctx.累计防御气势,
    我方: (ctx.allies || []).map(单位快), 敌方: (ctx.enemies || []).map(单位快),
    日志条数: ctx.log.length,
  });
  ctx.rng = 包装;
  const 原屏 = 界面.屏, 原ctx = 界面.ctx;
  界面.屏 = '战斗'; 界面.ctx = ctx;
  let 崩 = null, 枚举条数 = 0;
  const 前 = 状态();
  try {
    for (let 轮 = 0; 轮 < 2; 轮++) {          // 「连续调用」—— 连调两遍也不许有任何变化
      G.预告快照(ctx);
      G.算意图(ctx);
      枚举条数 = (G.选项.枚举(界面) || []).length;
      G.战报统计({ ctx, 记录: ctx.log });
    }
  } catch (e) { 崩 = (e && e.message) || String(e); }
  const 后 = 状态();
  ctx.rng = 原rng;
  界面.屏 = 原屏; 界面.ctx = 原ctx;
  P('指令阶段纯读实测', { rng调用次数: 计数, 枚举条数, 前后一致: 前 === 后, 崩 });
  if (崩) bad(`指令阶段的四个纯读口子抛异常：${崩}`);
  else ok('预告快照 / 算意图 / 选项.枚举 / 战报统计 连调两遍都不抛异常');
  if (计数 === 0) ok(`\`ctx.rng\` 调用次数 = **0**（预告 / 意图 / 枚举 / 战报统计一处随机数都不消耗）`);
  else bad(`指令阶段消耗了 ${计数} 次 ctx.rng —— 预告类口子必须纯读`);
  if (前 === 后) ok('`ctx.rng` 之外的状态（双方 hp/cd/buffs/debuffs、ctx.log.length、ctx.气势）**100% 零变化**');
  else {
    const 甲 = JSON.parse(前), 乙 = JSON.parse(后);
    const 键 = Object.keys(甲).filter(k => JSON.stringify(甲[k]) !== JSON.stringify(乙[k]));
    bad(`纯读口子改了状态（变化的字段：${键.join('、')}）`);
  }
  if (ctx.rng === 原rng) ok('调完之后 `ctx.rng` 还是原来那一个函数（没有被替换 / 被吃掉）');
  else bad('`ctx.rng` 被换掉了');
}

/* ============================================================================
 * [4] 默认路径零污染（气势总攻 开 = false vs true，不下战术指令）
 * ========================================================================== */
console.log('\n[4] 默认路径零污染：气势总攻 开=false vs true（未下达战术指令）');
{
  const 队 = [
    { 键: 'B1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }, { 键: 'B3', 位: 2, 等级: 20 },
    { 键: 'M2', 位: 3, 等级: 20 }, { 键: 'M1', 位: 4, 等级: 20 }, { 键: 'CB2', 位: 5, 等级: 20 },
  ];
  const 敌 = [
    { 键: 'shield', 位: 0, 等级: 18 }, { 键: 'berserker', 位: 1, 等级: 18 },
    { 键: 'sniper', 位: 2, 等级: 18 }, { 键: 'jammer', 位: 4, 等级: 18 },
  ];
  const 原 = G.战斗结构.气势总攻.开;
  let r开 = null, r关 = null, 崩 = null;
  try {
    G.战斗结构.气势总攻.开 = true;
    r开 = G.simulate(队, 敌, {}, 20261013);
    G.战斗结构.气势总攻.开 = false;
    r关 = G.simulate(队, 敌, {}, 20261013);
  } catch (e) { 崩 = (e && e.message) || String(e); }
  G.战斗结构.气势总攻.开 = 原;
  if (崩) bad(`这一场跑不起来：${崩}`);
  else {
    const 甲 = JSON.stringify(r开.记录), 乙 = JSON.stringify(r关.记录);
    P('这一场', { 开记录数: r开.记录.length, 关记录数: r关.记录.length, 开结果: r开.结果, 关结果: r关.结果, 开回合: r开.回合数, 关回合: r关.回合数 });
    if (甲 === 乙) ok(`未下达战术指令时 \`ctx.log\` 的 JSON.stringify **逐字节相等**（${r开.记录.length} 条记录）`);
    else bad(`开=true 与 开=false 的记录不一样（开 ${r开.记录.length} 条 / 关 ${r关.记录.length} 条）—— 默认路径被污染了`);
    const 键差 = r开.记录.filter((x, i) => {
      const y = r关.记录[i];
      if (!y) return true;
      const a = Object.keys(x).sort().join(','), b = Object.keys(y).sort().join(',');
      return a !== b;
    });
    if (!键差.length) ok(`每一条记录的 \`Object.keys\` 集合 **100% 相等**（${r开.记录.length} / ${r开.记录.length}）`);
    else bad(`有 ${键差.length} 条记录的字段集合不一样（例：${Object.keys(键差[0]).sort().join('/')}）`);
    /* 收尾：开关真的还原了 */
    if (G.战斗结构.气势总攻.开 === 原) ok(`\`战斗结构.气势总攻.开\` 已还原成 ${原}`);
    else bad('测试没把 `战斗结构.气势总攻.开` 还原回去');
  }
}

/* ============================================================================
 * [5] Replay 协议完整性
 * ========================================================================== */
console.log('\n[5] Replay 协议完整性（规则签名格式 + 新录像关联版本与签名 + 旧录像兼容）');
{
  const 签名 = String(G.规则签名());
  if (/^r1:[0-9a-f]{8}$/.test(签名)) ok(`\`规则签名()\` = ${签名}（形如 r1:8 位十六进制）`);
  else bad(`\`规则签名()\` 的格式不对：${JSON.stringify(签名)}（应该是 r1:xxxxxxxx）`);
  if (签名 === String(录像.规则签名())) ok('`录像.规则签名` 与 `window.__game.规则签名` 是同一份实现（同一个值）');
  else bad('`录像.规则签名` 与 `__game.规则签名` 对不上');
  /* 连调两遍 + 与页面无关的稳定性 */
  if (String(G.规则签名()) === 签名) ok('`规则签名()` 是纯函数（连调两遍同一个值）');
  else bad('`规则签名()` 两次调用不一样（不是决定性函数）');

  /* 真开一局：新录像必须同时带上 游戏版本 与 规则签名 */
  录像.清();
  肉鸽.RUN = null; 肉鸽.进行中 = false;
  界面.动作('选分队', '无');
  界面.动作('开新局', '12345');
  const 场 = 录像.进行中();
  if (!场) bad('开了一局却没有「进行中」的录像（录像.开始 那条路没建起场）');
  else {
    const 文 = 录像.文本(场);
    P('新录像的关联字段', { 格式版本: 场.格式版本, 游戏版本: 场.游戏版本, 规则签名: 场.规则签名, 种子: 场.种子 });
    if (String(场.游戏版本) === String(G.version)) ok(`录像的 \`游戏版本\` = ${场.游戏版本} = 当前 __game.version`);
    else bad(`录像的 \`游戏版本\`（${场.游戏版本}）与当前（${G.version}）对不上`);
    if (String(场.规则签名) === 签名) ok(`录像的 \`规则签名\` = ${场.规则签名} = 当前规则宇宙`);
    else bad(`录像没把 \`规则签名\` 记成当前那一份：${JSON.stringify(场.规则签名)} ≠ ${签名}`);
    if (文.indexOf(`"规则签名": "${签名}"`) >= 0 && 文.indexOf(`"游戏版本": "${G.version}"`) >= 0) {
      ok('导出文本（`录像.文本`）里同时看得到 `游戏版本` 与 `规则签名`（跨规则版本重放的判据）');
    } else bad('导出文本里找不到 `游戏版本` / `规则签名`');
    /* 旧录像：把签名抹掉再读回来 —— 照旧能读，且**不会被凭空补一个字段** */
    const 旧 = JSON.parse(JSON.stringify(场));
    delete 旧.规则签名;
    录像.写({ 版本: 1, 进行中: 旧, 封存: [] });
    const 读回 = 录像.进行中();
    if (读回 && !('规则签名' in 读回) && 读回.种子 === 场.种子) {
      ok('旧录像（没有 `规则签名`）照旧能读，且读回来**不凭空补字段**（工具把「没有这个字段」算成一条跨规则判据）');
    } else bad(`旧录像读回来不对：${读回 ? Object.keys(读回).join('/') : 'null'}`);
  }
  /* 收尾：把这一局收干净，别把状态留给后面的段 */
  录像.清();
  肉鸽.RUN = null; 肉鸽.进行中 = false;
  界面.开屏('菜单');
}

/* ============================================================================
 * [6] 架构债务账本对齐 + Owner 定义自洽（消除重叠歧义）
 * ========================================================================== */
console.log('\n[6] 架构债务账本对齐（协作/架构债务.md）+ stateOwners 定义自洽');
{
  let 快照 = null;
  try { 快照 = JSON.parse(readFileSync(快照路径, 'utf8')); } catch (e) { /* 上面已经报过 */ }
  const ids = (快照 && Array.isArray(快照.knownDebtIds)) ? 快照.knownDebtIds : [];
  if (!existsSync(债务路径)) bad('找不到 协作/架构债务.md（架构债务账本）');
  else {
    const 债 = readFileSync(债务路径, 'utf8');
    const 行数 = 债.replace(/\r\n/g, '\n').split('\n').length;
    ok(`协作/架构债务.md 存在（${行数} 行）`);
    if (!ids.length) bad('架构快照里 knownDebtIds 是空的');
    else {
      const 缺 = ids.filter(id => 债.indexOf(id) < 0);
      if (!缺.length) ok(`knownDebtIds ${ids.length} 笔（${ids.join('、')}）在 协作/架构债务.md 里**都有登记条目**`);
      else bad(`这些债务 ID 在 协作/架构债务.md 里查不到：${缺.join('、')}`);
    }
  }
  /* ★ 2026-10-13：`stateOwners` 的**语义**写死在快照里、并由这里验它自洽（不再靠读者猜）：
       · `stateOwners.ctx.log` ⊆ `stateOwners.ctx`（写战绩的必须是战斗状态的 Owner，
         不然「谁能改战斗状态」和「谁能写日志」两套口径会打架）；
       · `readOnlyPresentationModules` 与 `readOnlyScope`（默认 `ctx` / `ctx.log` / `RUN`）
         **完全不相交**（「只读表现层」= 对这些**引擎状态**只读 —— 它可以拥有 `界面` / `播放`，
         但一个字节都不许写引擎状态；这就把「92-肉鸽界面-1..2 既在界面 Owner 名单、
         又在只读清单里」这类**看起来重叠**的情况定死了）。 */
  const 主 = (快照 && 快照.stateOwners) || {};
  const 范围 = (快照 && Array.isArray(快照.readOnlyScope)) ? 快照.readOnlyScope : ['ctx', 'ctx.log', 'RUN'];
  const 只读 = (快照 && Array.isArray(快照.readOnlyPresentationModules)) ? 快照.readOnlyPresentationModules : [];
  const 日志主 = Array.isArray(主['ctx.log']) ? 主['ctx.log'] : [];
  const ctx主 = Array.isArray(主.ctx) ? 主.ctx : [];
  P('Owner 定义', { ctx: ctx主.length, 'ctx.log': 日志主.length, RUN: (主.RUN || []).length, 播放: (主.播放 || []).length, 界面: (主.界面 || []).length, 只读: 只读.length, readOnlyScope: 范围 });
  if (!ctx主.length || !日志主.length) bad('stateOwners.ctx / stateOwners["ctx.log"] 缺一个（[3] 段的扫描就没有判据了）');
  else {
    const 野的 = 日志主.filter(f => !ctx主.includes(f));
    if (!野的.length) ok(`stateOwners["ctx.log"] ⊆ stateOwners.ctx（写战绩的 ${日志主.join('、')} 也是 ctx 的 Owner）`);
    else bad(`这些模块能写 \`ctx.log\` 却不在 \`stateOwners.ctx\` 里：${野的.join('、')} —— 两套 Owner 口径打架`);
  }
  const 范围外的 = 范围.filter(s => !Array.isArray(主[s]));
  if (范围外的.length) bad(`readOnlyScope 点名了 stateOwners 里没有的状态：${范围外的.join('、')}`);
  else {
    const 引擎主 = [...new Set(范围.flatMap(s => 主[s] || []))];
    const 撞 = 只读.filter(f => 引擎主.includes(f));
    if (!撞.length) ok(`readOnlyPresentationModules（${只读.length} 个）与 readOnlyScope（${范围.join(' / ')}：共 ${引擎主.length} 个 Owner）**完全不相交** —— 只读表现层不拥有任何引擎状态`);
    else bad(`这些模块既是「只读表现层」又是引擎状态的 Owner（重叠歧义）：${撞.join('、')} —— 要么从只读清单里去掉，要么只读范围写错`);
  }
}

/* ============================================================================
 * [7] 迁移边界（CC · 2026-10-15）：MBR-1 内核只认显式输入 + MBR-2 规则不读日志
 * ----------------------------------------------------------------------------
 * 判据全部写在 `协作/架构快照.json` 的 `migration` 里（内核模块清单 / 禁读的全局名 /
 * 允许的「内核 → 上层」调用 + 对应债务 ID），这里只做机械扫描（去注释、去字符串内容）。
 * 允许清单是**棘轮**：清单外的新调用 / 新全局读取一律红；清单里的某项已经消失，只提示、不红
 * （留给 CC 下一次清账时从快照和债务账本里一起删）。
 * ========================================================================== */
console.log('\n[7] 迁移边界：MBR-1 内核只认显式输入 · MBR-2 规则不读 ctx.log');
{
  let 快照 = null;
  try { 快照 = JSON.parse(readFileSync(快照路径, 'utf8')); } catch (e) { /* [1] 已报 */ }
  const 迁 = (快照 && 快照.migration) || null;
  if (!迁 || !Array.isArray(迁.kernelModules) || !迁.kernelModules.length) {
    bad('协作/架构快照.json 缺 migration.kernelModules（迁移边界的判据）');
  } else {
    /** 去注释后再把字符串 / 模板的**内容**抹成空格（引号保留），避免文案里的词被当成标识符。 */
    const 去字符串 = 码 => {
      let out = '', 态 = null;
      for (let i = 0; i < 码.length; i++) {
        const c = 码[i];
        if (态) {
          if (c === '\\') { out += '  '; i++; continue; }
          if (c === 态) { 态 = null; out += c; continue; }
          out += c === '\n' ? '\n' : ' ';
          continue;
        }
        if (c === "'" || c === '"' || c === '`') { 态 = c; out += c; continue; }
        out += c;
      }
      return out;
    };
    const 纯码 = f => 去字符串(去注释(读js(f)));
    /* 全仓顶层声明：行首的 function / const / let / class（片段共享一个作用域，顶层声明都在行首） */
    const 声明处 = {};
    for (const f of 片段们) {
      const 码 = 纯码(f);
      for (const m of 码.matchAll(/^(?:async\s+)?(?:function\s*\*?\s*|const\s+|let\s+|var\s+|class\s+)([\p{L}_$][\p{L}\p{N}_$]*)/gmu)) {
        if (!(m[1] in 声明处)) 声明处[m[1]] = f;
      }
    }
    const 内核 = 迁.kernelModules;
    const 缺模块 = 内核.filter(f => !片段们.includes(f));
    if (缺模块.length) bad(`migration.kernelModules 点名的片段不存在：${缺模块.join('、')}`);
    const 内核集 = new Set(内核);
    const 下层 = new Set(Array.isArray(迁.kernelMayDependOn) ? 迁.kernelMayDependOn : []);
    const 禁读 = Array.isArray(迁.kernelForbiddenGlobals) ? 迁.kernelForbiddenGlobals : [];
    const 放行 = 迁.kernelUpwardCallAllowlist || {};     // { 符号: 'DEBT-xx' 或 '说明' }
    const 越界 = [], 禁读命中 = [], 用到的放行 = new Set();
    /** 本片段里作为局部变量 / 函数参数出现过的名字（简易作用域：同名的跨模块引用不算，
     *  例如参数 `选项` 与 `8b` 的全局 `选项` 对象同名）。禁读全局的检查**不受**这条豁免影响。 */
    const 局部名 = 码 => {
      const 名们 = new Set();
      const 标 = /[\p{L}_$][\p{L}\p{N}_$]*/gu;
      for (const m of 码.matchAll(/\b(?:const|let|var)\s+([\p{L}_$][\p{L}\p{N}_$]*)/gu)) 名们.add(m[1]);
      for (const m of 码.matchAll(/\bfunction\b[^(]*\(([^)]*)\)/gu)) for (const n of m[1].matchAll(标)) 名们.add(n[0]);
      for (const m of 码.matchAll(/\(([^()]*)\)\s*=>/gu)) for (const n of m[1].matchAll(标)) 名们.add(n[0]);
      for (const m of 码.matchAll(/([\p{L}_$][\p{L}\p{N}_$]*)\s*=>/gu)) 名们.add(m[1]);
      for (const m of 码.matchAll(/\bcatch\s*\(\s*([\p{L}_$][\p{L}\p{N}_$]*)/gu)) 名们.add(m[1]);
      return 名们;
    };
    for (const f of 内核) {
      if (!片段们.includes(f)) continue;
      const 本地 = 局部名(纯码(f));
      const 行们 = 纯码(f).split('\n');
      行们.forEach((行, i) => {
        for (const m of 行.matchAll(/(^|[^.\p{L}\p{N}_$])([\p{L}_$][\p{L}\p{N}_$]*)/gu)) {
          const 名 = m[2];
          /* 对象字面量的键（`{ 名: …` / `, 名: …` / 行首 `名: …`）不是引用 */
          const 起 = m.index + m[1].length;
          if (/^\s*:(?!:)/.test(行.slice(起 + 名.length)) && /(^|[{,])\s*$/.test(行.slice(0, 起))) continue;
          if (禁读.includes(名)) 禁读命中.push(`${f}:${i + 1} ${名}`);
          const 在 = 声明处[名];
          if (!在 || 在 === f || 内核集.has(在) || 下层.has(在) || 本地.has(名)) continue;
          if (名 in 放行) { 用到的放行.add(名); continue; }
          越界.push(`${f}:${i + 1} ${名}（定义在 ${在}）`);
        }
      });
    }
    const 去重 = a => [...new Set(a)];
    if (!禁读命中.length) ok(`内核 ${内核.length} 个片段 0 处读取禁读全局（${禁读.join(' / ')}）`);
    else bad(`内核读了禁读全局（MBR-1）：${去重(禁读命中).slice(0, 8).join('；')}${禁读命中.length > 8 ? ' …' : ''}`);
    if (!越界.length) ok(`内核 → 上层的调用全部在放行清单内（${用到的放行.size} 项：${[...用到的放行].map(s => `${s}[${放行[s]}]`).join('、') || '无'}）`);
    else bad(`内核新增了对上层模块的依赖（MBR-1；要放行请先给 CC 提架构需求）：${去重(越界).slice(0, 8).join('；')}${越界.length > 8 ? ' …' : ''}`);
    const 过期 = Object.keys(放行).filter(s => !用到的放行.has(s));
    if (过期.length) info(`放行清单里这些项已不再使用（CC 清账时删）：${过期.join('、')}`);

    /* MBR-2：规则层（内核 + 规则参数 + 局外）不准把 ctx.log 当输入查询 */
    const 规则层 = 去重(内核.concat(Array.isArray(迁.ruleModulesNoLogRead) ? 迁.ruleModulesNoLogRead : []));
    const 查日志 = [];
    const 查日志正则 = /\(?\s*\bctx\s*\.\s*log\s*(?:\|\|\s*\[\s*\]\s*)?\)?\s*\.\s*(some|filter|find|findIndex|findLast|findLastIndex|reduce|every|includes|indexOf|lastIndexOf|map|forEach)\s*\(/g;
    for (const f of 规则层) {
      if (!片段们.includes(f)) continue;
      纯码(f).split('\n').forEach((行, i) => { if (查日志正则.test(行)) 查日志.push(`${f}:${i + 1}`); 查日志正则.lastIndex = 0; });
    }
    if (!查日志.length) ok(`规则层 ${规则层.length} 个片段 0 处查询 ctx.log（日志只追加、只做输出）`);
    else bad(`规则层把 ctx.log 当输入查询（MBR-2；改读 ctx 上的显式状态，比如 ctx.战况计数）：${查日志.join('、')}`);
  }
}

/* ============================================================================
 * [8] 开牌路径确定性基线（CC · 2026-10-15）：与 2788 对称的第二条回归真值
 * ----------------------------------------------------------------------------
 * 脚本写死在快照 `simulation.cardPathBattleLogSpec` 的说明里；这里按同一脚本重跑，
 * 记录条数必须等于 `simulation.cardPathBattleLogCount`（卡牌规则 / 数值 / 发牌时机改了，
 * 这里会红 —— 那是 Gameplay 侧的有意改动，就由交付人同步快照并在交付里报数）。
 * ========================================================================== */
console.log('\n[8] 开牌路径确定性基线（种子 20261015 · 默认五人队 vs 编成表[0] · 激励 + 热血）');
{
  let 快照 = null;
  try { 快照 = JSON.parse(readFileSync(快照路径, 'utf8')); } catch (e) { /* [1] 已报 */ }
  const 期望 = 快照 && 快照.simulation ? 快照.simulation.cardPathBattleLogCount : undefined;
  if (!Number.isFinite(期望)) bad('协作/架构快照.json 缺 simulation.cardPathBattleLogCount');
  else {
    const 跑 = () => {
      const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
      const ctx = G.开局(G.默认五人队, 敌方, 20261015, null, { 战术卡牌: true });
      G.打战术牌(ctx, 'C_CMD_1');
      G.打战术牌(ctx, 'C_GUARD_1');
      let 护栏 = 0;
      while (!ctx.result && 护栏++ < 20) G.打一回合(ctx);
      return ctx;
    };
    const a = 跑(), b = 跑();
    const 同 = JSON.stringify(a.log) === JSON.stringify(b.log);
    if (同) ok(`同一脚本连跑两遍 ctx.log 逐字节相同（${a.log.length} 条）`);
    else bad('同一脚本连跑两遍 ctx.log 不一致 —— 开牌路径不确定');
    if (a.log.length === 期望) ok(`开牌路径记录条数 = ${期望}（= 快照 simulation.cardPathBattleLogCount）`);
    else bad(`开牌路径记录条数 ${a.log.length} ≠ 快照的 ${期望} —— 卡牌规则有改动就同步快照并在交付里报数`);
    P('末状态', { 结果: a.result && a.result.结果, 回合: a.turn, 战况计数: a.战况计数 });
  }
}

/* ============================================================================
 * 总结
 * ========================================================================== */
console.log('');
if (fails) {
  console.log(`✗ 架构门禁：${fails} 处不通过`);
  console.log(`ERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
console.log('✓ 架构门禁：八段全部通过（快照同步 / 随机数纪律 / 状态 Owner 边界 / 默认路径零污染 / Replay 协议 / 债务账本 + Owner 自洽 / 迁移边界 / 开牌路径基线）');
process.exit(0);
