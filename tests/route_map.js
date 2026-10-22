#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · RouteMap 生成器边界测试（★ 2026-10-13 · 审查项 1–6 的验收）
 * ----------------------------------------------------------------------------
 * 被测对象：`tools/build-route-map.mjs`（零依赖、零子进程）。
 * 本测试**直接 `import` 它的 `main()` 与导出的纯函数**，**不启子进程 pipe**
 * （DSH 沙箱内子进程禁开 pipe —— 铁律 §3.4）。
 *
 * 七组断言（每个数字都真的跑出来、贴出来）：
 *   [1] `write:false` 与 `--check` **不写文件**证明：磁盘内容 / mtime 逐位不变；
 *       内容不一致时 `check:true` 返回 `ok:false, 同步:false`；`!ok` 时 `write:true` 也绝不覆盖
 *   [2] `扫块成员` / `解析导出` / `取值名` / `顶层定义` 的边界：重复键去重 + `重复键:['a']` +
 *       `键: 内部名` 别名映射 / 简写属性 / 同行多属性 / 带引号键 / 计算属性与展开运算符**安全跳过不崩**
 *   [3] 运行期 `Object.assign(window.__game, X)` 识别 + **Set 并集去重**（同一键不重复计入总键数）
 *   [4] 锚点缺失 → 硬门禁 `缺锚点.length > 0 && ok === false`
 *   [5] 行数越界 → 硬门禁 `行数越界 === true && ok === false`
 *   [6] `src/shell.html` 的 `@include` 校验（重复 include + 目标文件不存在 → `include错误` 且 `ok === false`）
 *   [7] 真实仓库闭环：默认 `main({ check: true })` → `ok:true / 同步:true / 缺锚点:[] /
 *       include错误:[] / 行数越界:false`；默认 write 模式写到 `outPath`；口径文字不许把静态值说成运行时真值
 *
 * 用法：node tests/route_map.js
 * ========================================================================== */
import { readFileSync, writeFileSync, existsSync, statSync, mkdtempSync, rmSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { tmpdir } from 'os';
import {
  main, 片段顺序, 扫块成员, 解析导出, 取值名, 顶层定义, 运行期导出, 合并导出,
  输出路径, 行数下限, 行数上限,
} from '../tools/build-route-map.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);
/** 深比较式断言（真的跑出来的值与期望值一起打出来）。 */
function 断言(名, 实际, 期望) {
  const a = JSON.stringify(实际), e = JSON.stringify(期望);
  if (a === e) { ok(`${名} = ${a}`); return true; }
  bad(`${名} 期望 ${e}，实际 ${a}`);
  return false;
}
/** 布尔断言（可带证据串）。 */
function 断言真(名, 条件, 证据 = '') {
  if (条件) ok(`${名}${证据 ? '：' + 证据 : ''}`);
  else bad(`${名} 不成立${证据 ? '：' + 证据 : ''}`);
  return !!条件;
}
const 建临时目录 = 前缀 => mkdtempSync(join(tmpdir(), 前缀));

/* ============================ [1] 不写文件 ============================ */
console.log('\n[1] write:false 与 --check 都不写文件（磁盘内容 / mtime 逐位不变）');
{
  const 临时 = 建临时目录('dsh-route-map-');
  try {
    /* ① outPath 指向**不存在**的文件 */
    const 不存在 = join(临时, 'route-map-尚未生成.md');
    const r1 = main({ write: false, outPath: 不存在 });
    断言真('outPath 不存在 + write:false → 不写盘（已写 false，文件仍不存在）',
      r1.已写 === false && r1.写入 === null && existsSync(不存在) === false, `已写=${r1.已写}`);

    const r2 = main({ check: true, outPath: 不存在 });
    断言真('outPath 不存在 + check:true → 不写盘，且判 ok:false / 同步:false',
      r2.已写 === false && existsSync(不存在) === false && r2.ok === false && r2.同步 === false && r2.一致 === false,
      `ok=${r2.ok} 同步=${r2.同步} 首个不同行=${r2.首个不同行}`);

    /* ② outPath 指向**内容故意不同**的文件：内容与 mtime 都不许动 */
    const 坏 = join(临时, 'route-map-故意写坏.md');
    writeFileSync(坏, '故意写坏\n', 'utf8');
    const m0 = statSync(坏).mtimeMs, 字0 = readFileSync(坏, 'utf8');

    const r3 = main({ write: false, outPath: 坏 });
    断言真('write:false → 坏文件内容 / mtime 一个字节都没动',
      r3.已写 === false && readFileSync(坏, 'utf8') === 字0 && statSync(坏).mtimeMs === m0, `已写=${r3.已写}`);

    const r4 = main({ check: true, outPath: 坏 });
    断言真('check:true → 内容不一致（ok:false / 同步:false）且不写盘',
      r4.已写 === false && r4.ok === false && r4.同步 === false
      && readFileSync(坏, 'utf8') === 字0 && statSync(坏).mtimeMs === m0,
      `ok=${r4.ok} 同步=${r4.同步}（首个不同行 ${r4.首个不同行}）`);

    /* ③ write:true 但 ok:false（锚点缺失）→ 也绝不覆盖写坏文件 */
    const r5 = main({
      outPath: 坏,
      extraChains: [{ 组: '⑩ 测试专用：绝不存在的链路', 项: [{ 标签: '绝不存在的锚点', 锚: [['05-阵型.js', /^function 这个函数绝对不存在\(/]] }] }],
    });
    断言真('write:true 且 ok:false → 绝不覆盖（已写 false，内容 / mtime 不变）',
      r5.ok === false && r5.已写 === false
      && readFileSync(坏, 'utf8') === 字0 && statSync(坏).mtimeMs === m0,
      `ok=${r5.ok} 已写=${r5.已写}`);

    /* ④ CLI 数组形参（main(['--check'])）同样只读 —— 拿真实生成物当靶子 */
    const 真m0 = statSync(输出路径).mtimeMs;
    const 数组形 = main(['--check']);
    断言真('main(["--check"]) 只读（真实 RouteMap.md 的 mtime 不变、已写 false）',
      statSync(输出路径).mtimeMs === 真m0 && 数组形.已写 === false && 数组形.检查 === true,
      `检查=${数组形.检查} 同步=${数组形.同步}`);
  } finally { rmSync(临时, { recursive: true, force: true }); }
}

/* ============================ [2] 字面量扫描边界 ============================ */
console.log('\n[2] 扫块成员 / 解析导出 / 取值名 / 顶层定义 的边界');
{
  const 段们 = 扫块成员('{ a: 1, b, a: 2, c: fnC }', 0);
  断言('扫块成员：顶层段数', 段们.length, 4);
  断言('扫块成员：段文本按顶层逗号切开', 段们.map(x => x.文本.trim()), ['a: 1', 'b', 'a: 2', 'c: fnC']);

  const 内联 = [
    'const G = {',
    '  a: 1,',
    '  b,',
    '  a: 2,',
    '  c: fnC,',
    '  别名: 内部名,',
    "  'q-k': 1,",
    '  ["算"]: 2,',
    '  [`模`]: 3,',
    '  ...rest,',
    '};',
  ].join('\n');
  const 解 = 解析导出(内联, /^const G = \{/m);
  断言('解析导出：去重键（保留首次出现顺序）', 解.去重, ['a', 'b', 'c', '别名', 'q-k']);
  断言('解析导出：重复键', 解.重复键, ['a']);
  断言('解析导出：重复明细（键名 × 次数）', 解.重复明细, [['a', 2]]);
  断言('解析导出：槽位数（含重复槽）', 解.槽位.length, 6);
  断言('解析导出：重复键两处的绝对行号', 解.槽位.filter(x => x.名 === 'a').map(x => x.行), [2, 4]);
  断言真('计算属性 / 模板字符串键 / 展开运算符 → 安全跳过且不崩',
    !['算', '模', 'rest'].some(n => 解.去重.includes(n)), `去重=${解.去重.join(',')}`);
  断言('带引号键：正常认出来（引号不进键名）',
    解析导出("const G = { 'q-k': 1 };", /^const G = \{/m).去重, ['q-k']);
  断言('同行多属性：一行里多个键也算得对',
    解析导出('const G = { x: 1, y: 2, z };', /^const G = \{/m).去重, ['x', 'y', 'z']);

  断言('取值名：`键: 内部名` 别名映射 → 内部名', 取值名('  别名: 内部名'), '内部名');
  断言('取值名：getter 简写之外的同名简写属性 → 同名', 取值名('b'), 'b');
  断言('取值名：值是字面量表达式 → null', 取值名('a: 1'), null);
  断言('取值名：计算属性（取不到键）→ null', 取值名('["算"]: 2'), null);

  断言('顶层定义：function / 同行多声明 const / 两格缩进的对象方法',
    [...顶层定义(['function a() {', 'const b = 1, c = 2;', '  m() {']).keys()], ['a', 'b', 'c', 'm']);
}

/* ============================ [3] 运行期导出 + 并集去重 ============================ */
console.log('\n[3] 运行期 Object.assign 导出识别 + Set 并集去重');
{
  const 假文件 = '80-界面-2-顶栏菜单编队.js';
  const 假文本 = new Map([[假文件, [
    'const 排位接口 = {};',
    '排位接口.职业排位开 = 职业排位开;',
    '排位接口.职业排位数 = 职业排位数;',
    'Object.assign(window.__game, 排位接口);',
    'window.__game.新增直挂键 = 1;',
  ].join('\n')]]);

  const 出 = 运行期导出(假文本, [假文件], []);
  断言('运行期导出：识别数', 出.length, 3);
  断言('运行期导出：键名', 出.map(x => x.名), ['职业排位开', '职业排位数', '新增直挂键']);
  断言('运行期导出：行号', 出.map(x => x.行), [2, 3, 5]);
  断言('运行期导出：方式（Object.assign 段 / 直接赋值）', 出.map(x => x.方式),
    ['Object.assign(排位接口)', 'Object.assign(排位接口)', '直接赋值']);

  const 出2 = 运行期导出(假文本, [假文件], ['职业排位开']);
  断言('已在 99-boot.js 字面量里的键 → 不再算运行期导出',
    出2.map(x => x.名), ['职业排位数', '新增直挂键']);

  const 并 = 合并导出(['a', 'b', '职业排位开'], [{ 名: '职业排位开' }, { 名: '职业排位数' }]);
  断言('合并导出：总键数（同一键只算一次）', 并.总键数, 4);
  断言('合并导出：跨层重复键（被记下、不重复计数）', 并.跨层重复, ['职业排位开']);
  断言('合并导出：全集 = 字面量 3 + 运行期新增 1', 并.全部键, ['a', 'b', '职业排位开', '职业排位数']);

  const 真 = main({ write: false });
  断言('真实仓库：导出总键 = 字面量去重 + 运行期识别（并集无重叠）',
    真.统计.导出总键, 真.统计.导出符号 + 真.统计.运行期导出);
  断言('真实仓库：跨层重复键 = 0（运行期那一段已与字面量去重）', 真.统计.跨层重复, 0);
  info(`真实仓库：字面量 ${真.统计.导出槽位} 槽去重 ${真.统计.导出符号} + 运行期识别 ${真.统计.运行期导出} → 并集 ${真.统计.导出总键} 项（重复键 ${真.统计.重复键} 个）`);
}

/* ============================ [4] 缺锚点硬门禁 ============================ */
console.log('\n[4] 锚点缺失 → 硬门禁 ok:false');
{
  const 真m0 = statSync(输出路径).mtimeMs;
  const r = main({
    write: false,
    extraChains: [{ 组: '⑩ 测试专用：绝不存在的链路', 项: [{ 标签: '绝不存在的锚点', 锚: [['05-阵型.js', /^function 这个函数绝对不存在\(/]] }] }],
  });
  断言真('缺锚点 1 处（锚点原文照抄）', r.缺锚点.length === 1, JSON.stringify(r.缺锚点));
  断言真('ok === false', r.ok === false, `ok=${r.ok}`);
  断言真('write:false → 已写 false 且真实 RouteMap.md mtime 不变',
    r.已写 === false && statSync(输出路径).mtimeMs === 真m0);
  断言真('生成的文本里那条链路打 `—`', r.文本.includes('- 绝不存在的锚点：`05-阵型.js:—`'));
}

/* ============================ [5] 行数越界硬门禁 ============================ */
console.log('\n[5] 行数越界 → 硬门禁 ok:false');
{
  const 基准 = main({ write: false });
  info(`真实生成行数 = ${基准.行数}（默认要求 ${行数下限}~${行数上限}）`);
  断言真('默认区间内 → 行数越界 false / ok true',
    基准.行数越界 === false && 基准.行数 >= 行数下限 && 基准.行数 <= 行数上限 && 基准.ok === true);

  const 小上限 = main({ write: false, maxLines: 50 });
  断言真('maxLines:50 → 行数越界 true 且 ok false 且不写盘',
    小上限.行数越界 === true && 小上限.ok === false && 小上限.已写 === false,
    `行数=${小上限.行数} 要求=${小上限.行数下限}~${小上限.行数上限}`);

  const 大下限 = main({ write: false, minLines: 9999 });
  断言真('minLines:9999 → 行数越界 true 且 ok false 且不写盘',
    大下限.行数越界 === true && 大下限.ok === false && 大下限.已写 === false);

  const 放宽 = main({ write: false, minLines: 1, maxLines: 100000 });
  断言真('区间放宽 → 行数越界 false', 放宽.行数越界 === false && 放宽.ok === true);
}

/* ============================ [6] shell.html include 校验 ============================ */
console.log('\n[6] src/shell.html 的 @include 列表校验（重复 include + 目标文件不存在）');
{
  const shell = readFileSync(join(ROOT, 'src', 'shell.html'), 'utf8');
  const 干净 = 片段顺序({ shellHtmlText: shell });
  断言('真实 shell.html：include 错误 0 处', 干净.错误, []);
  断言('真实 shell.html：片段数（去重后）', 干净.列表.length, 56);

  const 坏shell = shell + '\n<!-- @include js/00-head.js -->\n<!-- @include js/99-不存在.js -->\n';
  const 校验 = 片段顺序({ shellHtmlText: 坏shell });
  断言('坏 shell：错误 2 处', 校验.错误.length, 2);
  断言真('坏 shell：报出「重复 @include」并指出是哪个文件',
    校验.错误.some(x => x.includes('重复 @include') && x.includes('00-head.js')), 校验.错误.join(' | '));
  断言真('坏 shell：报出「目标不存在或不是常规文件」',
    校验.错误.some(x => x.includes('不存在') && x.includes('99-不存在.js')));
  断言真('坏 shell：重复项只保留第一次（列表仍 56，00-head.js 只出现 1 次）',
    校验.列表.length === 56 && 校验.列表.filter(x => x === '00-head.js').length === 1);

  const r = main({ write: false, shellHtmlText: 坏shell });
  断言真('include错误 > 0 → ok === false，且错误随返回值带出',
    r.ok === false && r.include错误.length === 2 && r.已写 === false,
    `ok=${r.ok} include错误=${r.include错误.length}`);
  断言真('include 列表被改坏也照样生成完整文本（不抛异常）',
    r.行数 >= 行数下限 && r.文本.includes('## §1'), `行数=${r.行数}`);
}

/* ============================ [7] 真实仓库闭环 + 口径文字 ============================ */
console.log('\n[7] 真实仓库生成 + --check 闭环');
{
  const 真m0 = statSync(输出路径).mtimeMs;
  const r = main({ check: true });
  断言真('默认 main({ check: true }) → ok === true', r.ok === true);
  断言真('同步 === true', r.同步 === true && r.一致 === true);
  断言真('缺锚点 === []', r.缺锚点.length === 0 && Array.isArray(r.缺锚点));
  断言真('include错误 === []', r.include错误.length === 0 && Array.isArray(r.include错误));
  断言真('行数越界 === false', r.行数越界 === false, `行数=${r.行数}（${r.行数下限}~${r.行数上限}）`);
  断言真('--check 绝不写盘（已写 false + mtime 不变）',
    r.已写 === false && statSync(输出路径).mtimeMs === 真m0);

  /* 默认 write 模式（审查项 3）：写到 outPath，置 已写 = 同步 = true；内容一致时不重复写盘 */
  const 临时 = 建临时目录('dsh-route-map-w-');
  try {
    const 目标 = join(临时, 'RouteMap.md');
    const w1 = main({ outPath: 目标 });
    断言真('默认 write 模式：写盘 + 已写/同步 = true + 内容逐字等于生成文本',
      w1.已写 === true && w1.同步 === true && existsSync(目标)
      && readFileSync(目标, 'utf8') === w1.文本, `写入=${w1.写入}`);
    const w2 = main({ outPath: 目标 });
    断言真('内容已一致 → 不重复写盘（写入 null，已写 仍 true）',
      w2.写入 === null && w2.已写 === true);
    const c2 = main({ check: true, outPath: 目标 });
    断言真('对刚生成的文件再 --check → ok/同步 true、已写 false',
      c2.ok === true && c2.同步 === true && c2.已写 === false);
  } finally { rmSync(临时, { recursive: true, force: true }); }

  /* 审查项 1 / 4 / 5 的文档口径：静态扫描值不许说成运行时真值 */
  断言真('§3 标题改成「人工维护分类 + 自动匹配行号」',
    r.文本.includes('## §3 核心机制链路与关键代码锚点索引（人工维护分类 + 自动匹配行号）'));
  断言真('§3 写明边界：不构成完整静态调用图 / 不是运行时依赖图',
    r.文本.includes('不构成完整静态调用图，也不是运行时依赖图'));
  断言真('抬头与 §4 都改用「静态扫描识别的导出项」',
    r.文本.includes('静态扫描识别的导出项') && r.文本.includes('静态扫描识别的导出项（共 '));
  断言真('明确「不加载、不执行页面」+ 已知限制（动态计算属性 / 闭包内动态导出）',
    r.文本.includes('不加载、不执行页面')
    && r.文本.includes('动态计算属性') && r.文本.includes('IIFE 闭包内动态导出'));
  断言真('不再把静态值宣称为运行时 Object.keys(window.__game).length 的真值',
    !r.文本.includes('就是 `Object.keys(window.__game).length` 的真值')
    && r.文本.includes('不是**运行时 `Object.keys(window.__game).length` 的真值'));
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `RouteMap 边界测试：共 ${fails} 项失败` : 'RouteMap 边界测试：七组全部通过');
process.exit(fails ? 1 : 0);
