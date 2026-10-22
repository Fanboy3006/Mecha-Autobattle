/* ============================================================================
 * Godot 版 · 路由查询（`Godot-AST依赖清单.json` 的**切片查询器**）
 * ----------------------------------------------------------------------------
 * **为什么有它**：`协作/架构/Godot-AST依赖清单.json` 有 1.4 MB（≈ 40 万 token），
 *   任何代理都**不该整份读**它，也不该整份读 `Godot-RouteMap-明细.md`。
 *   这个工具只把**与查询词相关的那一小块**打到终端：
 *
 *   · 命中**文件路径**（子串，含文件名）→ 层 / 行 / 字节 / 估算 token / 注释占比 /
 *     `class_name` / 公开函数签名（前 30 个）/ `dependsOn`（依赖谁）/ `dependsBy`（被谁依赖）
 *   · 命中 **`class_name` / 函数名 / 常量名** → 定义所在的 `文件:行号`、函数签名，
 *     以及全仓引用它的文件位置（依赖图口径 + 现扫源码的调用点 `类.函数(` 行号）
 *
 * 用法：
 *   node godot/tools/route_query.mjs Calc                    # class_name / 符号
 *   node godot/tools/route_query.mjs 抵消甲                   # 函数 / 常量
 *   node godot/tools/route_query.mjs celestial_v01.gd        # 文件路径子串
 *   node godot/tools/route_query.mjs 势力 --all              # 不截断（默认每段最多 30~40 行）
 *   import { 查询 } from './godot/tools/route_query.mjs'     # 返回结构，不打印
 *
 * **四条硬规矩**（与 `build_godot_routemap.mjs` 同一套）：
 *   ① 零依赖、零子进程：只用 `node:fs` / `node:path` / `node:url`；
 *   ② 只读：绝不写任何文件（`--check` 之外没有第二个人改生成物）；
 *   ③ 不猜：查不到就明说「没命中」，并列出手头有哪些近似名字（最多 8 个）；
 *   ④ **行号有两个来源**，输出里分开标：`[清单]` = JSON（静态扫描的权威行号），
 *      `[现扫]` = 这次现读 `.gd` 源码（用来给调用点定位，注释与字符串已抹掉）。
 * ========================================================================== */
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
/* ★ 口径只留一份：扫描规则 /「抹掉注释与字符串」的词法 / 清单路径**全部从生成器 import**，
 *   不在这里另写一套（否则两边迟早写出两个数字）。 */
import { JSON路径, 扫gd文件, 去注释与字符串 } from './build_godot_routemap.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const GODOT = join(HERE, '..');
const 清单路径 = JSON路径;

const lf = s => String(s).replace(/\r\n/g, '\n');
const 读文本 = p => lf(readFileSync(p, 'utf8'));
const 截 = (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + '…' : String(s));
const 百分比 = x => (Number(x || 0) * 100).toFixed(1) + '%';

/* ---- 现扫：`类.函数(` / 裸符号 的行号调用点 ---- */
function 扫调用点(模式们, opt = {}) {
  const 上限 = opt.全部 ? Infinity : 600;
  const 结果 = [];
  for (const 相对 of 扫gd文件()) {
    let 源;
    try { 源 = 读文本(join(GODOT, 相对)); } catch { continue; }
    const 代码行们 = 去注释与字符串(源).split('\n');
    const 原行们 = 源.split('\n');
    for (let i = 0; i < 代码行们.length; i++) {
      const 行 = 代码行们[i];
      if (!行.trim()) continue;
      for (const p of 模式们) {
        p.正则.lastIndex = 0;
        if (!p.正则.test(行)) continue;
        p.正则.lastIndex = 0;
        结果.push({ 文件: 相对, 行: i + 1, 代码: 截(原行们[i].trim(), 110), 类: p.标签 });
        break;
      }
      if (结果.length >= 上限) return 结果;
    }
  }
  return 结果;
}

const 转义 = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** 核心查询（纯计算，返回结构；打印在 `打印()` 里） */
export function 查询(词, opt = {}) {
  if (!existsSync(清单路径)) {
    return { 错误: `找不到 ${清单路径} —— 先跑 node godot/tools/build_godot_routemap.mjs 生成` };
  }
  const 清单 = JSON.parse(读文本(清单路径));
  const 文件们 = 清单.files || [];
  const q = String(词 || '').trim();
  const 下 = s => String(s || '').toLowerCase();
  const 含 = s => 下(s).includes(下(q));

  const 文件命中 = q ? 文件们.filter(f => 含(f.file) || 含(f.file.split('/').pop())) : [];
  const 类精确 = 文件们.filter(f => f.className && 下(f.className) === 下(q));
  const 类模糊 = 文件们.filter(f => f.className && 含(f.className) && !类精确.includes(f));
  const 函命中 = [];
  const 常命中 = [];
  if (q) {
    for (const f of 文件们) {
      for (const 函 of f.funcs || []) {
        if (下(函.name) === 下(q)) 函命中.push({ f, 项: 函, 精度: 0 });
        else if (含(函.name)) 函命中.push({ f, 项: 函, 精度: 1 });
      }
      for (const 常 of f.consts || []) {
        if (下(常.name) === 下(q)) 常命中.push({ f, 项: 常, 精度: 0 });
        else if (含(常.name)) 常命中.push({ f, 项: 常, 精度: 1 });
      }
    }
    函命中.sort((a, b) => a.精度 - b.精度 || (a.f.file < b.f.file ? -1 : 1) || a.项.line - b.项.line);
    常命中.sort((a, b) => a.精度 - b.精度 || (a.f.file < b.f.file ? -1 : 1) || a.项.line - b.项.line);
  }
  /* 有精确命中时，不再拿「名字里含这个词」的模糊命中来凑数（否则查 Calc 会带出 recalc_…） */
  const 精确函数 = 函命中.filter(x => x.精度 === 0);
  const 精确常量 = 常命中.filter(x => x.精度 === 0);
  const 函数显示 = 精确函数.length ? 精确函数 : 函命中;
  const 常量显示 = 精确常量.length ? 精确常量 : 常命中;
  const 模糊函数数 = 精确函数.length ? 函命中.length - 精确函数.length : 0;
  const 模糊常量数 = 精确常量.length ? 常命中.length - 精确常量.length : 0;

  const 类们 = [...类精确, ...类模糊];
  const 命中 = !!(文件命中.length || 类们.length || 函命中.length || 常命中.length);

  /* 现扫调用点：查类 / 函数 / 常量时才扫（查纯文件路径不必） */
  let 调用点 = [];
  if (类们.length || 函命中.length || 常命中.length) {
    const 模式们 = [];
    for (const f of 类们) {
      if (f.className) 模式们.push({ 标签: f.className, 正则: new RegExp(`(?<![\\p{L}\\p{N}_.])${转义(f.className)}(?![\\p{L}\\p{N}_])`, 'gu') });
    }
    for (const x of 函命中.filter(x => x.精度 === 0)) {
      const 类 = x.f.className;
      模式们.push({
        标签: 类 ? `${类}.${x.项.name}(` : `${x.项.name}(`,
        正则: 类 ? new RegExp(`(?<![\\p{L}\\p{N}_.])${转义(类)}\\.${转义(x.项.name)}\\s*\\(`, 'g') : new RegExp(`(?<![\\p{L}\\p{N}_.])${转义(x.项.name)}\\s*\\(`, 'g'),
      });
    }
    if (模式们.length) 调用点 = 扫调用点(模式们, opt);
    /* 补一段：**本文件内**不带类名前缀的调用（`A = 抵消甲(def, w)` 这种）。
     * 生成器的 `全仓调用` 只数 `类名.函数名(`，所以同文件内的调用它一个都看不见 —— 这里补上，
     * 并且**跳过定义行本身**，只列真正的调用行。 */
    for (const x of 函命中.filter(x => x.精度 === 0)) {
      const 全 = join(GODOT, x.f.file);
      if (!existsSync(全)) continue;
      const 源 = 读文本(全);
      const 代码行们 = 去注释与字符串(源).split('\n');
      const 原行们 = 源.split('\n');
      const 定义 = new RegExp(`^\\s*(static\\s+)?func\\s+${转义(x.项.name)}\\s*\\(`);
      const 调用 = new RegExp(`(?<![\\p{L}\\p{N}_.])${转义(x.项.name)}\\s*\\(`, 'g');
      for (let i = 0; i < 代码行们.length; i++) {
        if (定义.test(代码行们[i])) continue;
        if (!调用.test(代码行们[i])) continue;
        调用点.push({ 文件: x.f.file, 行: i + 1, 代码: 截(原行们[i].trim(), 110), 类: `${x.项.name}(本文件内)` });
      }
    }
    调用点.sort((a, b) => (a.文件 < b.文件 ? -1 : a.文件 > b.文件 ? 1 : a.行 - b.行));
  }

  /* 近似候选（查不到时给个台阶） */
  let 近似 = [];
  if (!命中 && q) {
    const 候选 = new Set();
    for (const f of 文件们) {
      if (f.className && 下(f.className).includes(下(q).slice(0, 3))) 候选.add(f.className);
      for (const 函 of f.funcs || []) if (下(函.name).includes(下(q).slice(0, 2))) 候选.add(`${函.name}  (${f.file}:${函.line})`);
    }
    近似 = [...候选].slice(0, 8);
  }

  return { 词: q, 清单, 文件们, 文件命中, 类精确, 类模糊, 函命中, 常命中, 函数显示, 常量显示, 模糊函数数, 模糊常量数, 调用点, 近似, 命中, opt };
}

/* ============================ 打印（紧凑） ============================ */
export function 打印(r) {
  if (r.错误) { console.log('✗ ' + r.错误); return; }
  const 上限 = r.opt && r.opt.全部 ? Infinity : 30;
  const 文件上限 = r.opt && r.opt.全部 ? Infinity : 6;
  const 调用上限 = r.opt && r.opt.全部 ? Infinity : 40;
  const 行 = s => console.log(s);

  行(`# route_query：「${r.词}」`);
  if (!r.命中) {
    行('✗ 没命中任何文件 / class_name / 函数 / 常量。');
    if (r.近似.length) 行('  近似候选：' + r.近似.join(' · '));
    行('  提示：参数可以是文件路径子串（如 celestial_v01.gd）、class_name（Calc）或函数/常量名（抵消甲）。');
    return;
  }

  /* ---- ① 文件 ---- */
  if (r.文件命中.length) {
    行('');
    行(`■ 文件命中 ${r.文件命中.length} 个${r.文件命中.length > 文件上限 ? `（只显示前 ${文件上限}，--all 看全部）` : ''}`);
    for (const f of r.文件命中.slice(0, 文件上限)) {
      行('');
      行(`  文件  ${f.file}`);
      行(`        层 ${f.layer} · ${f.lines} 行 · ${f.bytes} 字节 · 估算 ${f.estTokens} token · 注释 ${百分比(f.commentRatio)}（${f.commentBytes} 字节，${f.commentLines} 行整行 + ${f.trailingCommentLines} 行尾）`);
      行(`        class_name ${f.className ? f.className + `（第 ${f.classLine} 行）` : '—'} · extends ${f.extends || '—'} · 常量 ${(f.consts || []).length} · 函数 ${(f.funcs || []).length}`);
      if (f.responsibility) 行(`        职责  ${f.responsibility}`);
      const 公开 = (f.funcs || []).filter(x => !x.name.startsWith('_'));
      行(`        公开函数 ${公开.length} 个${公开.length ? '：' : ''}`);
      for (const x of 公开.slice(0, 上限)) {
        行(`          ${String(x.line).padStart(5)}  ${截(x.signature, 130)}${x.callsOutside ? `   ← 外部 ${x.callsOutside} 次` : ''}`);
      }
      if (公开.length > 上限) 行(`          …（另有 ${公开.length - 上限} 个，--all 看全部）`);
      依赖行(行, '依赖谁（dependsOn）', '→', f.dependsOn || []);
      依赖行(行, '被谁依赖（dependsBy）', '←', f.dependsBy || []);
    }
    if (r.文件命中.length > 文件上限) 行(`  …（另有 ${r.文件命中.length - 文件上限} 个文件命中）`);
  }

  /* ---- ② 符号：class_name ---- */
  if (r.类精确.length || r.类模糊.length) {
    行('');
    行(`■ class_name 命中 ${r.类精确.length + r.类模糊.length} 个（精确 ${r.类精确.length}）`);
    for (const f of [...r.类精确, ...r.类模糊].slice(0, 4)) {
      行(`  ${f.className}  [清单] ${f.file}:${f.classLine} · 层 ${f.layer} · ${f.lines} 行 · 估算 ${f.estTokens} token · 注释 ${百分比(f.commentRatio)}`);
    }
  }

  /* ---- ③ 符号：函数 / 常量 ---- */
  const 符号们 = [
    ...(r.函数显示 || r.函命中).slice(0, 6).map(x => ({ 种类: 'func', ...x })),
    ...(r.常量显示 || r.常命中).slice(0, 6).map(x => ({ 种类: 'const', ...x })),
  ];
  if (符号们.length) {
    const 省略 = (r.函数显示 || r.函命中).length + (r.常量显示 || r.常命中).length - 符号们.length;
    行('');
    行(`■ 函数 / 常量命中 ${符号们.length} 个${省略 > 0 ? `（另有 ${省略} 个未显示，--all 看全部）` : ''}${r.模糊函数数 + r.模糊常量数 ? `；另有 ${r.模糊函数数 + r.模糊常量数} 个「名字里含该词」的模糊命中已省略` : ''}`);
    for (const x of 符号们) {
      行('');
      if (x.种类 === 'func') {
        行(`  符号  ${x.f.className ? x.f.className + '.' : ''}${x.项.name}   [清单] ${x.f.file}:${x.项.line}`);
        行(`        签名  ${截(x.项.signature, 200)}`);
        行(`        返回  ${x.项.returns || '—'} · ${x.项.static ? 'static' : '实例方法'} · 外部调用 ${x.项.callsOutside} 次 / 全仓 ${x.项.callsTotal} 次 · 所在文件 ${x.f.lines} 行 · 估算 ${x.f.estTokens} token`);
        if (x.项.doc) 行(`        说明  ${x.项.doc}`);
      } else {
        行(`  常量  ${x.f.className ? x.f.className + '.' : ''}${x.项.name}   [清单] ${x.f.file}:${x.项.line}`);
        if (x.项.doc) 行(`        说明  ${x.项.doc}`);
      }
    }
  }

  /* ---- ④ 调用点 ---- */
  if (r.调用点.length) {
    const 类们 = [...new Set(r.调用点.map(x => x.类))];
    行('');
    行(`■ 全仓调用点 [现扫] ${r.调用点.length} 行（模式：${类们.join(' / ')}）`);
    const 按文件 = new Map();
    for (const c of r.调用点) 按文件.set(c.文件, (按文件.get(c.文件) || 0) + 1);
    行(`  涉及 ${按文件.size} 个文件：` + [...按文件.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10).map(([f, n]) => `${f}(${n})`).join(' · '));
    for (const c of r.调用点.slice(0, 调用上限)) {
      行(`  ${c.文件}:${c.行}  ${c.代码}`);
    }
    if (r.调用点.length > 调用上限) 行(`  …（另有 ${r.调用点.length - 调用上限} 行，--all 看全部）`);
  } else if (r.类精确.length || r.函命中.length || r.常命中.length) {
    行('');
    行('■ 全仓调用点 [现扫] 0 行（没有任何 `.gd` 代码里出现这个符号；注释/字符串里的不算）');
  }
  行('');
  行('（行号两个来源：`[清单]` = Godot-AST依赖清单.json 的静态扫描值；`[现扫]` = 本次现读 .gd 源码。想改口径请改 godot/tools/build_godot_routemap.mjs。）');
}

function 依赖行(行, 标题, 箭头, 边们) {
  if (!边们.length) { 行(`        ${标题}：—`); return; }
  const 总次 = 边们.reduce((a, e) => a + (e.n || 0), 0);
  行(`        ${标题} ${边们.length} 个文件 / ${总次} 次：`);
  for (const e of 边们) {
    const 目标 = e.to || e.from;
    const 符 = (e.symbols || []).slice(0, 4).join('·');
    行(`          ${箭头} ${目标}（${e.n}${符 ? '：' + 截(符, 60) : ''}）`);
  }
}

/* ============================ CLI ============================ */
const 是直接运行 = process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url;
if (是直接运行) {
  const 参数 = process.argv.slice(2);
  const opt = { 全部: 参数.includes('--all') || 参数.includes('--全部') };
  const 词 = 参数.filter(x => !x.startsWith('--') && x !== '--全部').join(' ').trim();
  if (!词) {
    console.log('用法：node godot/tools/route_query.mjs <符号名 | class_name | 函数名 | 常量名 | 文件路径子串> [--all]');
    console.log('例：  node godot/tools/route_query.mjs Calc');
    console.log('      node godot/tools/route_query.mjs 抵消甲');
    console.log('      node godot/tools/route_query.mjs celestial_v01.gd');
    process.exitCode = 2;
  } else {
    try {
      const r = 查询(词, opt);
      打印(r);
      if (r.错误) process.exitCode = 1;
      else if (!r.命中) process.exitCode = 3;
    } catch (e) {
      console.error('✗ 查询失败：' + (e && e.stack ? e.stack : e));
      process.exitCode = 1;
    }
  }
}
