#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 平衡工具测试（M6 的验收）
 * ----------------------------------------------------------------------------
 * 盯的是「工具本身能用、能复现、行数对得上、能写出文档」这四件事 ——
 * **不是**去测胜率是多少（胜率是 M6 要交给 Claude 审的数字，不是断言）。
 *
 * 场次一律用 `--quick` 级别（每档 5 场），所以 CI 不会被拖慢：
 *   `node tests/balance.js` 只要一两秒。
 *
 * ★ 一个本机的坑（写在这里免得以后有人改回去）：这份测试**不能用
 *   `child_process.spawnSync` 去跑 `tools/balance.mjs`**。DSH 沙箱里
 *   「程序不能开命名管道」，子进程的 `stdio: 'pipe'` 会直接
 *   `spawnSync … EPERM`（这是沙箱边界，不是代码 bug）。
 *   所以改成 **`import` 这个工具、直接调它的 `main()`**：
 *   `tools/balance.mjs` 为此做了两件事 —— ① `main()` 返回结果、不打印不退出；
 *   ② 只有 `node tools/balance.mjs` 直接跑时才走 CLI 那一块（`import.meta.url` 比对）。
 *   控制台那点输出用 `console.log` 临时接管来验（同一个进程，不经过管道）。
 *
 * 跑法：node tests/balance.js
 * ========================================================================== */
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { tmpdir } from 'os';
import * as 工具 from '../tools/balance.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);

/** 跑一次工具，拿走它打到 stdout 的那份 Markdown（不经过子进程 / 管道）。
 *  **不抛**：出错时把异常放进 `err0`，让每一段自己决定怎么断言。 */
function 跑(参数 = []) {
  const 原log = console.log, 原err = console.error;
  let 出 = '', 侧 = '', 异常 = null, r = null;
  console.log = (...a) => { 出 += a.join(' ') + '\n'; };
  console.error = (...a) => { 侧 += a.join(' ') + '\n'; };
  try {
    r = 工具.main(参数);
    if (r.帮助) 出 = r.md;
    else if (!r.参数.quiet) 出 = r.md;
  } catch (e) {
    异常 = e;
  } finally {
    console.log = 原log; console.error = 原err;
  }
  return { r, out: 出, err: 侧, err0: 异常 };
}
/** 真跑一次 CLI（就是 `node tools/balance.mjs` 那一段），只为了看它打到 stderr 的汇总行。
 *  ★ **子进程一律不试**：DSH 沙箱里 `spawnSync` / `execFileSync` 只要给子进程开管道
 *    （`stdio: 'pipe'`，哪怕是抓 stderr）就直接 `EPERM`，这是沙箱边界不是代码 bug。
 *    所以这里只能**在同进程里**验 CLI 的那几行：临时接管 console.error 调一次 CLI 块。 */
function 跑CLI看stderr(参数 = []) {
  const 原log = console.log, 原err = console.error;
  let 侧 = '';
  console.log = () => {};
  console.error = (...a) => { 侧 += a.join(' ') + '\n'; };
  try {
    // 复用 CLI 块里的那两行：main() + 汇总（内容与 `node tools/balance.mjs` 打的一模一样）
    const r = 工具.main(参数);
    console.error(`行数：单挑 ${r.单挑.length} 行、组队 ${r.组队.length} 行、汇总 ${r.汇总.length} 行；用时 ${r.用时.toFixed(1)}s`);
  } catch (e) {
    侧 += '错误：' + (e && e.message ? e.message : String(e)) + '\n';
  } finally {
    console.log = 原log; console.error = 原err;
  }
  return { err: 侧 };
}

console.log('平衡工具测试：机甲指挥 · M6\n');

/* ============================ [1] 三个模式都出表 ============================ */
console.log('[1] 三个模式都能跑通、都出表');
{
  const { r, out, err } = 跑(['--quick', '--no-write']);
  const md = out || r.md;
  if (md.startsWith('# 平衡表（机甲指挥 · M6）')) ok('表头是「# 平衡表（机甲指挥 · M6）」');
  else bad('第一行不是平衡表的标题');
  for (const [名, 标] of [['表一 · 单挑表（34 名角色）', '## 表一 · 单挑表（34 名角色'],
    ['表二 · 组队表（默认五人队）', '## 表二 · 组队表（默认五人队'],
    ['结论段', '## 结论（三问']]) {
    if (md.includes(标)) ok(`里面有「${名}」`);
    else bad(`缺少「${名}」（找不到 ${标}）`);
  }
  if (md.includes('### 一、「精英 / 头目到底有没有挑战」')
    && md.includes('### 二、「第 4 层该按几级队伍算」')
    && md.includes('### 三、明显过强 / 过弱的角色')) ok('三问的标题都在（精英 / 第 4 层 / 过强过弱）');
  else bad('三问的标题不齐');
  const 建议 = md.match(/建议第 4 层按 (Lv\d+) 队伍算/);
  if (建议) ok(`三问第二问给了明确建议：${建议[0]}`);
  else bad('三问第二问没有「建议第 4 层按 LvX 队伍算」的结论句');
  const 汇总行 = 跑CLI看stderr(['--quick', '--no-write']).err;
  const m = 汇总行.match(/单挑 (\d+) 行、组队 (\d+) 行、汇总 (\d+) 行/);
  if (m) ok(`CLI 那块报的行数汇总：单挑 ${m[1]} 行、组队 ${m[2]} 行、汇总 ${m[3]} 行`);
  else bad('CLI 那块没有报行数汇总');
  info(`Markdown ${md.length} 字符、单挑 ${r.单挑.length} 行、组队 ${r.组队.length} 行`);
}

/* ============================ [2] 行数与角色数 / 档数对得上 ============================ */
console.log('\n[2] 行数对得上：34 名角色 × 3 级 = 102 行；13 个「层 × 档」组合 × 3 级 = 39 行');
{
  const { r } = 跑(['--quick', '--no-write']);
  if (r.单挑.length === 34 * 3) ok(`单挑表 ${r.单挑.length} 行 = 34 名 × Lv10/Lv20/Lv30`);
  else bad(`单挑表 ${r.单挑.length} 行，预期 ${34 * 3}`);
  if (r.组队.length === 13 * 3) ok(`组队表 ${r.组队.length} 行 = 13 个「层 × 档」组合 × 3 个队伍等级`);
  else bad(`组队表 ${r.组队.length} 行，预期 ${13 * 3}（第 1 层没有侵蚀源、第 4 层没有精英/守军/侵蚀源）`);
  if (r.汇总.length === 5 * 3) ok(`按档汇总 ${r.汇总.length} 行 = 5 档 × 3 个队伍等级`);
  else bad(`按档汇总 ${r.汇总.length} 行，预期 15`);

  const 角色键 = new Set(r.单挑.map(x => x.键));
  if (角色键.size === 34) ok('单挑表覆盖全部 34 个角色键');
  else bad(`单挑表只覆盖 ${角色键.size} 个角色键`);
  if (new Set(r.单挑.map(x => x.lv)).size === 3) ok('单挑表真的跑了 3 个等级');
  else bad('单挑表的等级不是 3 个');
  const 组合 = new Set(r.组队.map(x => `${x.层}|${x.档}`));
  if (组合.size === 13) ok('组队表的 13 个「层 × 档」组合都在');
  else bad(`组队表只有 ${组合.size} 个组合`);
  for (const 档 of ['普通', '精英', '守军', '侵蚀源', 'Boss']) {
    const 行 = r.组队.filter(x => x.档 === 档);
    if (行.length >= 3) ok(`「${档}」这一档跑出了 ${行.length} 行（每行 ${行[0].总场} 场）`);
    else bad(`「${档}」这一档只有 ${行.length} 行`);
    if (行.every(x => x.总场 >= 5)) ok(`  「${档}」每行场次 ≥ 5（--quick 口径）`);
    else bad(`  「${档}」有行的场次 < 5`);
  }

  // 再从 Markdown 本体数一遍锚点行（防止「行数对、表里没有」）
  const md = r.md;
  const 表一 = md.split('## 表一 · 单挑表')[1].split('## 表二')[0];
  const 数据行 = 表一.split('\n').filter(l => /^\| [^|]+ \| [A-Z]{1,3}\d? \|/.test(l));
  if (数据行.length === 102) ok('Markdown 表一里真的数出 102 行角色数据');
  else bad(`Markdown 表一里数出 ${数据行.length} 行，预期 102`);
  const 汇总段 = md.split('**按编成档合并看**')[1].split('**三条典型编成')[0];
  const 档行 = 汇总段.split('\n').filter(l => /^\| (普通|精英|守军|侵蚀源|Boss) \| Lv\d+ \|/.test(l));
  if (档行.length === 15) ok('按档汇总表里 5 档 × 3 等级 = 15 行都在（Markdown 里数出来的）');
  else bad(`按档汇总表 ${档行.length} 行，预期 15`);
  if (/组队表每档 \*\*\d+ 场 × 编成条数\*\*，单挑表每级 \*\*\d+ 场\*\*/.test(md)) ok('抬头写清了场次口径');
  else bad('抬头没有场次口径');
}

/* ============================ [3] 单点查询 ============================ */
console.log('\n[3] 单点查询 `--char=B1 --lv=20`');
{
  const { r } = 跑(['--quick', '--char=B1', '--lv=20', '--no-write']);
  const md = r.md;
  if (md.includes('## 表三 · 单点查询')) ok('出了「表三 · 单点查询」');
  else bad('没有单点查询那一段');
  if (/雷萨（B1 · 近卫 · S 档）/.test(md)) ok('认得出 B1 = 雷萨 · 近卫 · S 档');
  else bad('单点查询没有正确认人');
  if (md.includes('逐条记录') && /\[ 1\] 战斗开始/.test(md)) ok('顺带打了第一场的逐条战斗记录');
  else bad('没有逐条战斗记录');
  if (r.单点 && r.单点.场次 === 5) ok(`单点跑了 ${r.单点.场次} 场（--quick 口径）`);
  else bad('单点的场次不对');
  const 坏键 = 跑(['--quick', '--char=ZZ9', '--no-write']);
  if (坏键.err0) ok(`不认识的键（ZZ9）会报错：${String(坏键.err0.message).slice(0, 30)}…`);
  else bad('不认识的键居然跑成功了');
  const 坏参 = 跑(['--不存在的参数']);
  if (坏参.err0 && 坏参.err0.constructor.name === '参数错') ok('不认识的命令行参数抛「参数错」（CLI 会按退出码 2 处理）');
  else bad('不认识的命令行参数没有按预期报错');
}

/* ============================ [4] 同种子两次逐字相同 ============================ */
console.log('\n[4] 同一主种子跑两遍，除了「生成时间」那一行，输出必须逐字相同');
{
  const a = 跑(['--quick', '--no-write', '--seed=20261010']);
  const b = 跑(['--quick', '--no-write', '--seed=20261010']);
  const 挖掉时间 = s => s.replace(/^> 生成时间：.*$/m, '> 生成时间：（忽略）');
  if (挖掉时间(a.r.md) === 挖掉时间(b.r.md)) ok('两次输出逐字相同（去掉「生成时间」那一行后）');
  else {
    bad('两次输出不一样（有随机数没走 mulberry32 + 种子）');
    const x = 挖掉时间(a.r.md).split('\n'), y = 挖掉时间(b.r.md).split('\n');
    for (let i = 0; i < Math.max(x.length, y.length); i++) {
      if (x[i] !== y[i]) { info(`第一处不同在第 ${i + 1} 行：\n      A: ${x[i]}\n      B: ${y[i]}`); break; }
    }
  }
  // 结构性对比：两次的每一行数据都得逐字一样
  const 逐字 = (p, q) => JSON.stringify(p) === JSON.stringify(q);
  if (逐字(a.r.单挑, b.r.单挑) && 逐字(a.r.组队, b.r.组队)) ok('单挑表 / 组队表的每一行数据对象也逐字相同');
  else bad('表里的数据对象两次不一样');
  const c = 跑(['--quick', '--no-write', '--seed=777']);
  if (c.r.md.split('## 表一')[1] !== b.r.md.split('## 表一')[1]) ok('换个主种子结果就变了（种子真的在起作用）');
  else bad('换种子结果一样（种子没接进随机数）');
  const 源码 = readFileSync(join(ROOT, 'tools', 'balance.mjs'), 'utf8');
  if (!/Math\.random/.test(源码)) ok('工具源码里一处「不带种子的全局随机函数」都没有（随机数一律 mulberry32 + 种子）');
  else bad('工具源码里出现了 Math.random');
}

/* ============================ [5] docs/平衡表.md 能生成、带结论段 ============================ */
console.log('\n[5] 平衡表能生成：抬头写明「自动生成」+ 时间 + 种子 + 场次，且含结论段');
{
  const 临时 = mkdtempSync(join(tmpdir(), 'mecha-balance-'));
  const 目标 = join(临时, '平衡表.md');
  try {
    const { r } = 跑(['--quick', `--out=${目标}`, '--quiet']);
    if (r.写入 === 目标) ok('`--out=<路径>` 真的写了文件（不弄脏仓库里的 docs/平衡表.md）');
    else bad('--out 没有写文件');
    if (existsSync(目标)) ok('文件在磁盘上');
    else bad('文件没写出来');
    const md = readFileSync(目标, 'utf8');
    if (md === r.md) ok('写进文件的内容和内存里那份逐字相同');
    else bad('写进文件的内容和返回的不一样');
    if (md.includes('本文件由 `node tools/balance.mjs` 生成，别手改')) ok('抬头写明「由 node tools/balance.mjs 生成，别手改」');
    else bad('抬头没写「自动生成、别手改」');
    if (/生成时间：\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/.test(md)) ok(`抬头有生成时间：${(md.match(/生成时间：[^\n（]*/) || [])[0]}`);
    else bad('抬头没有生成时间');
    if (/主种子：\*\*\d+\*\*/.test(md)) ok(`抬头有种子：${(md.match(/主种子：\*\*\d+\*\*/) || [])[0]}`);
    else bad('抬头没有种子');
    if (/组队表每档 \*\*\d+ 场/.test(md)) ok(`抬头有场次：${(md.match(/组队表每档 \*\*\d+ 场 × 编成条数\*\*，单挑表每级 \*\*\d+ 场\*\*/) || [])[0]}`);
    else bad('抬头没有场次');
    if (md.includes('## 结论（三问') && md.includes('### 一、') && md.includes('### 二、') && md.includes('### 三、')) ok('文件里有完整的结论段（三问）');
    else bad('文件里没有完整的结论段');
    if (md.includes('一个数值都没改') || md.includes('没改')) ok('文件里写明了「只测量、不改数值」');
    else bad('文件里没有「不改数值」的声明');
  } finally {
    rmSync(临时, { recursive: true, force: true });
  }
  const 仓库里 = join(ROOT, 'docs', '平衡表.md');
  if (existsSync(仓库里)) {
    const md = readFileSync(仓库里, 'utf8');
    if (md.includes('本文件由 `node tools/balance.mjs` 生成') && md.includes('## 结论（三问')) ok('仓库里的 docs/平衡表.md 已生成、且带结论段');
    else bad('仓库里的 docs/平衡表.md 不是这份工具生成的（缺抬头或结论段）');
    const 行数 = md.split('\n').filter(l => /^\| [^|]+ \| [A-Z]{1,3}\d? \|/.test(l)).length;
    if (行数 === 34 * 3) ok(`仓库里那份单挑表 ${行数} 行（= 全量 102 行）`);
    else info(`仓库里那份单挑表 ${行数} 行（全量应是 102；被 --quick 覆盖过就会变小，重跑一次全量即可）`);
  } else bad('仓库里没有 docs/平衡表.md');
}

/* ============================ [6] 三个模式的开关与场次口径 ============================ */
console.log('\n[6] 模式开关与场次口径（--solo / --team / --quick / --help）');
{
  const solo = 跑(['--no-write', '--solo', '--seed=20261010']);
  if (solo.r.组队.length === 0 && solo.r.md.includes('## 表一 · 单挑表')) ok('`--solo` 只跑单挑表（没跑组队表）');
  else bad('`--solo` 的产出不对');
  const team = 跑(['--no-write', '--team']);
  if (team.r.单挑.length === 0 && team.r.md.includes('## 表二 · 组队表')) ok('`--team` 只跑组队表（没跑单挑表）');
  else bad('`--team` 的产出不对');
  if (/组队表每档 \*\*30 场/.test(team.r.md)) ok('`--team` 全量：组队表每档 30 场');
  else bad('全量模式的场次不是 30：' + (team.r.md.match(/组队表每档 \*\*\d+ 场/) || ['（没找到）'])[0]);
  if (/单挑表每级 \*\*10 场/.test(跑(['--no-write', '--solo']).r.md)) ok('全量：单挑表每级 10 场');
  else bad('全量模式的单挑场次不是 10');
  const quick = 跑(['--quick', '--no-write']);
  if (/组队表每档 \*\*5 场/.test(quick.r.md) && /单挑表每级 \*\*5 场/.test(quick.r.md)) ok('`--quick`：组队每档 5 场、单挑每级 5 场');
  else bad('`--quick` 的场次口径不对');
  const 帮助 = 跑(['--help']);
  if (帮助.r.帮助 && 帮助.r.md.includes('--quick') && 帮助.r.md.includes('--char=B1 --lv=20')) ok('`--help` 出用法（含 --quick 与单点查询）');
  else bad('`--help` 的用法不对');
  // 单点模式不写文件（保护仓库里的 docs/平衡表.md）
  const one = 跑(['--quick', '--char=B1', '--lv=10']);
  if (one.r.写入 === null) ok('单点查询**不**写 docs/平衡表.md（保护仓库里那份）');
  else bad('单点查询居然写了文件：' + one.r.写入);
}

/* ============================ [7] ★ 作弊上限口径（--cheat） ============================ */
console.log('\n[7] 作弊上限口径（`--cheat`）：出表 / 行数 / 口径 / 同种子逐字相同 / 写文档 / 不碰 docs/平衡表.md');
{
  /* 先量一份「改动前就有的」基线（组队表），它用来验「跑完 --cheat 之后别的模式不受影响」。 */
  const 基线前 = 跑(['--quick', '--team', '--no-write']);

  const { r, out, err0 } = 跑(['--cheat', '--quick', '--no-write', '--seed=20261010']);
  if (err0) bad(`--cheat 跑挂了：${err0.message}`);
  const md = out || (r && r.md) || '';
  if (md.startsWith('# 难度上限表（机甲指挥 · 作弊口径）')) ok('表头是「# 难度上限表（机甲指挥 · 作弊口径）」');
  else bad('第一行不是难度上限表的标题');
  if (md.includes('本文件由 `node tools/balance.mjs --cheat` 生成，别手改')) ok('抬头写明「由 node tools/balance.mjs --cheat 生成，别手改」');
  else bad('抬头没写「自动生成、别手改」');
  if (/生成时间：\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/.test(md)) ok(`抬头有生成时间：${(md.match(/生成时间：[^\n（]*/) || [])[0]}`);
  else bad('抬头没有生成时间');
  if (/主种子：\*\*\d+\*\*/.test(md)) ok(`抬头有主种子：${(md.match(/主种子：\*\*\d+\*\*/) || [])[0]}`);
  else bad('抬头没有主种子');
  if (/每条编成 \*?\*?\d+ 场/.test(md)) ok(`抬头写清了场次：${(md.match(/每条编成 \*?\*?\d+ 场\*?\*?/) || [])[0]}`);
  else bad('抬头没有场次口径');
  for (const [名, 标] of [['一、作弊口径', '## 一、作弊口径'], ['二、主表', '## 二、主表'],
    ['三、作弊也 100% 的档', '## 三、★ 作弊口径也 100%'], ['四、Boss 档', '## 四、Boss 档'],
    ['五、对照表', '## 五、对照表'], ['六、结论', '## 六、结论']]) {
    if (md.includes(标)) ok(`里面有「${名}」`);
    else bad(`缺少「${名}」（找不到 ${标}）`);
  }

  /* ---- 行数对得上：13 个「层 × 档」组合；对照 10 组 × 13 行 ---- */
  if (r.作弊) ok('main() 返回了「作弊」那一份结果（r.作弊）');
  else bad('main() 没有返回 r.作弊');
  const 主 = (r.作弊 || {}).主表 || [];
  if (主.length === 13) ok(`主表 ${主.length} 行 = 13 个「层 × 档」组合`);
  else bad(`主表 ${主.length} 行，预期 13（第 1 层没有侵蚀源、第 4 层没有精英 / 守军 / 侵蚀源）`);
  const md主 = md.split('## 二、主表')[1].split('**同一档')[0];
  const 数行 = md主.split('\n').filter(l => /^\| \d \| (普通|精英|守军|侵蚀源|Boss) \|/.test(l));
  if (数行.length === 13) ok('Markdown 主表里真的数出 13 行');
  else bad(`Markdown 主表里数出 ${数行.length} 行，预期 13`);
  if ((r.作弊 || {}).对照 && r.作弊.对照.length === 11) ok(`对照表 ${r.作弊.对照.length} 组（每条规则一个开关）`);
  else bad(`对照表组数不是 11：${(r.作弊 || {}).对照 ? r.作弊.对照.length : '没有'}`);
  /* ★ 2026-10-12：乙组的标题从「指令策略」改成「全队方针」（逐台指令已经删了，§1.4） */
  const 对照行 = md.split('**乙组 · 全队方针')[1].split('**每一组的整体差')[0];
  const 乙行 = 对照行.split('\n').filter(l => /^\| \d \| (普通|精英|守军|侵蚀源|Boss) \|/.test(l));
  if (乙行.length === 13) ok('对照表（乙组）也是 13 行 —— 每一组都跑满了全套编成');
  else bad(`对照表乙组 ${乙行.length} 行，预期 13`);
  for (const 档 of ['普通', '精英', '守军', '侵蚀源', 'Boss']) {
    const 行 = 主.filter(x => x.档 === 档);
    if (行.length >= 1) ok(`「${档}」这一档在作弊主表里出了 ${行.length} 行（每行 ${行[0].总场} 场）`);
    else bad(`「${档}」这一档一行都没有`);
    if (行.every(x => x.总场 >= 5)) ok(`  「${档}」每行场次 ≥ 5（--quick 口径）`);
    else bad(`  「${档}」有行的场次 < 5`);
  }

  /* ---- 作弊口径本身：7 台（= 绝对顶，难度调整之后）/ 35 件 / 覆盖 6 个职业 / 真的在跑「会玩的策略」 ----
     ★ 2026-10-11 难度调整（杠杆 ②「压部署位」）：`绝对顶` 9 → 7，所以这里断言的是「台数 = 绝对顶」而不是写死 9
       （写死 9 的话，以后作者再调绝对顶这条断言就又红了 —— 口径跟着常量走）。 */
  if (r.作弊 && r.作弊.台数 === r.作弊.绝对顶 && r.作弊.绝对顶 === 7) ok(`出击 ${r.作弊.台数} 台 = 绝对顶 ${r.作弊.绝对顶}（等级线 ${r.作弊.等级线} + 藏品 +${r.作弊.部署加成}）`);
  else bad(`出击台数不对：${r.作弊 && r.作弊.台数}（绝对顶 ${r.作弊 && r.作弊.绝对顶}）`);
  if (r.作弊 && r.作弊.队伍.length === r.作弊.台数) ok(`摆位摆满 ${r.作弊.队伍.length} 台、位号是 ${r.作弊.队伍.map(m => m.位).join(',')}`);
  else bad('摆位台数和出击台数对不上');
  if (r.作弊 && r.作弊.藏品.length >= 30) ok(`带了 ${r.作弊.藏品.length} 件战斗类藏品（含 d1/d2/c1/c2/f4 五件编制类）`);
  else bad(`带的藏品太少：${r.作弊 && r.作弊.藏品.length}`);
  for (const id of ['d1', 'd2', 'c1', 'c2', 'f4', 'b1', 'e9']) {
    if ((r.作弊 || {}).藏品 && r.作弊.藏品.includes(id)) ok(`  藏品名单里有 ${id}`);
    else bad(`  藏品名单里缺 ${id}`);
  }
  if ((r.作弊 || {}).藏品 && !r.作弊.藏品.includes('d3')) ok('负面编制藏品 d3（出击上限 −2）没有带进去');
  else bad('把负面藏品 d3 也带上了');
  const 职业 = new Set(((r.作弊 || {}).队伍 || []).map(m => ((r.作弊.九人.find(x => x.键 === m.键) || {}).职业)));
  if (职业.size >= 5) ok(`最强九人覆盖 ${职业.size} 个职业（吃 b1 混编的「每个不同职业 +8%」）`);
  else bad(`最强九人只覆盖 ${职业.size} 个职业`);
  const 计 = (r.作弊 || {}).计数 || {};
  /* ★ 2026-10-12：计数从「每个单位 × 回合一条指令」换成「每场每回合一条**全队方针**」——
     现在有 `全军突击` / `集中攻击` 两条真的在跑（九人里没有能开 TRANS-AM 的机体，那条为 0 是正常的）。 */
  const 方针计 = ['全军突击', '集中攻击', '攻击后排', '前守后攻', '全军防御'].reduce((a, k) => a + (计[k] || 0), 0);
  if (方针计 > 0 && (计['集中攻击'] || 0) > 0) ok(`策略真的在跑：主表这一轮记了 ${方针计} 个「回合 × 场」的方针格，其中**集中攻击 ${计['集中攻击']} 次**、`
    + `全军突击 ${计['全军突击'] || 0} 次${计['全军防御'] ? `、全军防御 ${计['全军防御']} 次` : ''}`);
  else bad(`策略看起来没跑起来（方针格 ${方针计}、集中攻击 ${计['集中攻击'] || 0}）`);
  if (md.includes('这套策略在主表这一轮里真的触发过多少次')) ok('文档里报了「策略真的触发过多少次」（不是空壳）');
  else bad('文档里没有策略触发计数那一段');

  /* ---- 同种子两次逐字相同（挖掉「生成时间」那一行） ---- */
  const b = 跑(['--cheat', '--quick', '--no-write', '--seed=20261010']);
  const 挖掉时间 = s => s.replace(/^> 生成时间：.*$/m, '> 生成时间：（忽略）');
  if (挖掉时间(md) === 挖掉时间(b.r.md)) ok('同一主种子跑两遍，--cheat 的输出逐字相同（去掉「生成时间」那一行后）');
  else {
    bad('--cheat 两次输出不一样（有随机数没走 mulberry32 + 种子）');
    const x = 挖掉时间(md).split('\n'), y = 挖掉时间(b.r.md).split('\n');
    for (let i = 0; i < Math.max(x.length, y.length); i++) {
      if (x[i] !== y[i]) { info(`第一处不同在第 ${i + 1} 行：\n      A: ${x[i]}\n      B: ${y[i]}`); break; }
    }
  }
  if (JSON.stringify(主) === JSON.stringify(b.r.作弊.主表)) ok('主表每一行数据对象也逐字相同');
  else bad('主表的数据对象两次不一样');
  const c = 跑(['--cheat', '--quick', '--no-write', '--seed=777']);
  if (c.r.md.split('## 二、主表')[1] !== md.split('## 二、主表')[1]) ok('换个主种子结果就变了（种子真的在起作用）');
  else bad('换种子 --cheat 结果一样（种子没接进随机数）');

  /* ---- ★ 跑完 --cheat 之后，别的模式必须**一点都不受影响**（作弊用的 RUN 要还原） ---- */
  const 基线与 = 基线前.r.md.split('## 表二')[1];
  const 基线后 = 跑(['--quick', '--team', '--no-write']);
  if (基线与 === 基线后.r.md.split('## 表二')[1]) ok('跑完 --cheat 之后，组队表的数字逐字不变（作弊用的 RUN 还原了，藏品没漏到别的战斗里）');
  else bad('跑完 --cheat 之后组队表变了 —— 作弊用的 RUN 没还原（藏品漏进了别的战斗）');

  /* ---- 能写出 docs/难度-上限表.md，且**不碰 docs/平衡表.md** ---- */
  const 临时 = mkdtempSync(join(tmpdir(), 'mecha-cheat-'));
  const 目标 = join(临时, '难度-上限表.md');
  try {
    const 写 = 跑(['--cheat', '--quick', `--out=${目标}`, '--quiet']);
    if (写.r.写入 === 目标) ok('`--out=<路径>` 真的写了文件（不弄脏仓库里的 docs/难度-上限表.md）');
    else bad('--cheat 的 --out 没有写文件');
    const 写md = existsSync(目标) ? readFileSync(目标, 'utf8') : '';
    if (写md === 写.r.md) ok('写进文件的内容和内存里那份逐字相同');
    else bad('写进文件的内容和返回的不一样');
    if (写md.includes('## 六、结论') && 写md.includes('难度太低')) ok('写出的文件里有「结论」段 + 「难度太低」的判据');
    else bad('写出的文件里没有结论段 / 难度判据');
    if (写md.includes('一个游戏数值都没改') || 写md.includes('没有动任何游戏数值')) ok('文件里写明了「只测量、不改数值」');
    else bad('文件里没有「不改数值」的声明');
  } finally {
    rmSync(临时, { recursive: true, force: true });
  }
  /* `--cheat` 的默认输出是**另一个文件**：仓库里的 docs/平衡表.md 不能被动过 */
  const 仓库平衡 = join(ROOT, 'docs', '平衡表.md');
  const 平衡还在 = existsSync(仓库平衡) && readFileSync(仓库平衡, 'utf8').includes('## 结论（三问');
  if (平衡还在) ok('--cheat 没动 docs/平衡表.md（它还是「## 结论（三问）」那一份）');
  else bad('docs/平衡表.md 被 --cheat 覆盖了！');
  const 仓库上限 = join(ROOT, 'docs', '难度-上限表.md');
  if (existsSync(仓库上限)) {
    const 上限md = readFileSync(仓库上限, 'utf8');
    if (上限md.includes('本文件由 `node tools/balance.mjs --cheat` 生成') && 上限md.includes('## 六、结论')) ok('仓库里的 docs/难度-上限表.md 已生成、且带结论段');
    else bad('仓库里的 docs/难度-上限表.md 不是这份工具生成的（缺抬头或结论段）');
    const 主表段 = 上限md.split('## 二、主表')[1].split('**同一档')[0];
    const 上限行数 = (主表段 || '').split('\n').filter(l => /^\| \d \| (普通|精英|守军|侵蚀源|Boss) \|/.test(l)).length;
    if (上限行数 === 13) ok(`仓库里那份主表 ${上限行数} 行（13 个「层 × 档」组合）`);
    else info(`仓库里那份主表 ${上限行数} 行（全量应是 13；被 --quick 覆盖过也会是 13，只是场次小）`);
  } else bad('仓库里没有 docs/难度-上限表.md');

  /* ---- --cheat 的用法要写进 --help ---- */
  const 帮助 = 跑(['--help']);
  if (帮助.r.md.includes('--cheat')) ok('`--help` 里有 --cheat 的用法');
  else bad('`--help` 里没有 --cheat');
  const 源码 = readFileSync(join(ROOT, 'tools', 'balance.mjs'), 'utf8');
  if (!/Math\.random/.test(源码)) ok('加了 --cheat 之后，工具源码里还是没有「不带种子的全局随机函数」');
  else bad('工具源码里出现了 Math.random');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '平衡工具测试全部通过');
process.exit(fails ? 1 : 0);
