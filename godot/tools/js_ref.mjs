// 加载 JS 参考版（js-reference-final）的「插桩副本」，供数据导出与黄金样例导出共用。
//
// 插桩只做三件事，全部不改变游戏行为（export_golden.mjs 用 2788 基线自检证明这一点）：
//   ① mulberry32 返回的函数上挂一个抽取计数 n；
//   ② 每写一条 ctx.log，把当时的随机数已抽次数记进一张 WeakMap（不往 ctx 上挂任何字段）；
//   ③ 把 pushLog / MAX_TURN 与全部纯数据常量挂到 globalThis.__REF。
// 插桩写在临时目录的副本里，仓库里的 JS 一个字节都不动。
import { execFileSync } from 'child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join, resolve } from 'path';
import { pathToFileURL } from 'url';

/** 封存时的规则签名：JS 参考版的数据或规则一旦被改动，签名就会变，导出直接拒绝 */
export const EXPECTED_RULES_SIGNATURE = 'r1:05a9cbf9';
export const REFERENCE_TAG = 'js-reference-final';

/** 不纳入导出的顶层常量：含函数的结构（要作为代码移植）与运行期状态对象 */
export const CODE_NOT_DATA = new Set(['势力特色表', 'REDUCTIONS', '事件表', '肉鸽']);

const 替换一次 = (src, from, to, 说明) => {
  const i = src.indexOf(from);
  if (i < 0 || src.indexOf(from, i + 1) >= 0) throw new Error(`插桩失败（${说明}）：目标文本应恰好出现一次`);
  return src.slice(0, i) + to + src.slice(i + from.length);
};

/** 检查仓库里 JS 部分与 js-reference-final 一致（有 git 时）；没有 git 时只靠规则签名把关 */
export function checkSealed(jsRoot) {
  try {
    execFileSync('git', ['-C', jsRoot, 'rev-parse', '--verify', REFERENCE_TAG], { stdio: 'pipe' });
  } catch {
    return `（未找到 git 或 tag ${REFERENCE_TAG}，只按规则签名把关）`;
  }
  try {
    execFileSync('git', ['-C', jsRoot, 'diff', '--quiet', REFERENCE_TAG, '--', '.', ':!godot', ':!.github', ':!协作'], { stdio: 'pipe' });
  } catch {
    throw new Error(`JS 参考版与 ${REFERENCE_TAG} 不一致：导出的样例将对应不上封存版本。请先还原 JS 改动。`);
  }
  return `JS 与 ${REFERENCE_TAG} 一致`;
}

/** 列出 L0/L1/L2/L3 片段里的顶层常量名（数据候选） */
function 顶层常量(jsRoot) {
  const shell = readFileSync(join(jsRoot, 'src', 'shell.html'), 'utf8');
  const files = [...shell.matchAll(/^<!-- @include js\/(\S+) -->/gm)].map(m => m[1])
    .filter(f => /^(00|05|10|11|12|20|30|40|50|60|61|70|71|72|90|91|93|94)/.test(f));
  const out = [];
  for (const f of files) {
    const src = readFileSync(join(jsRoot, 'src', 'js', f), 'utf8');
    for (const m of src.matchAll(/^(?:const|let|var)\s+([\p{L}_$][\p{L}\p{N}_$]*)\s*=/gmu)) out.push({ name: m[1], module: f });
  }
  return out;
}

export async function loadReference(jsRootArg) {
  const jsRoot = resolve(jsRootArg);
  const sealNote = checkSealed(jsRoot);
  const { loadPage } = await import(pathToFileURL(join(jsRoot, 'tests', 'lib', 'dom-stub.mjs')).href);
  const names = 顶层常量(jsRoot);
  let html = readFileSync(join(jsRoot, 'index.html'), 'utf8');
  html = 替换一次(html,
    'function mulberry32(a) {\n  return function () {\n',
    'function mulberry32(a) {\n  const __rng = function () {\n    __rng.n++;\n',
    'mulberry32 计数（开头）');
  html = 替换一次(html,
    '    return ((t ^ t >>> 14) >>> 0) / 4294967296;\n  };\n}',
    '    return ((t ^ t >>> 14) >>> 0) / 4294967296;\n  };\n  __rng.n = 0;\n  return __rng;\n}',
    'mulberry32 计数（结尾）');
  html = 替换一次(html,
    'ctx.log.push(Object.assign({ 回合: ctx.turn, 文本: text }, extra || {}));',
    'ctx.log.push(Object.assign({ 回合: ctx.turn, 文本: text }, extra || {}));\n'
    + '  if (globalThis.__RNG_AT) { let a = globalThis.__RNG_AT.get(ctx); if (!a) globalThis.__RNG_AT.set(ctx, a = []); a.push(ctx.rng && ctx.rng.n != null ? ctx.rng.n : -1); }',
    '记录随机数步数');
  const 暴露 = `globalThis.__REF = { pushLog, MAX_TURN, consts: {} };\n`
    + names.map(({ name }) => `try { globalThis.__REF.consts[${JSON.stringify(name)}] = ${name}; } catch (e) {}`).join('\n') + '\n';
  const at = html.lastIndexOf('})();');
  html = html.slice(0, at) + 暴露 + html.slice(at);
  const dir = mkdtempSync(join(tmpdir(), 'js-ref-'));
  writeFileSync(join(dir, 'index.html'), html);
  const page = loadPage(join(dir, 'index.html'), { quiet: true });
  if (page.errors.length) throw new Error('JS 参考版加载报错：' + page.errors.join(' | '));
  const sb = page.sandbox;
  sb.__RNG_AT = new WeakMap();
  const G = sb.__game;
  const signature = G.规则签名();
  if (signature !== EXPECTED_RULES_SIGNATURE) {
    throw new Error(`规则签名 ${signature} ≠ 封存签名 ${EXPECTED_RULES_SIGNATURE}：JS 参考版被改动过，拒绝导出`);
  }
  return { G, REF: sb.__REF, RNG_AT: sb.__RNG_AT, names, jsRoot, signature, version: G.version, sealNote };
}

/** 无损数值编码：整数照存；非整数（及 NaN/±∞）存 {"$f": IEEE-754 小端位串}。对象键排序；遇到函数直接报错。 */
export function normalize(v, path = '$') {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number') {
    if (Number.isInteger(v)) return v;
    const b = Buffer.alloc(8); b.writeDoubleLE(v);
    return { $f: b.toString('hex') };
  }
  if (typeof v === 'string' || typeof v === 'boolean') return v;
  if (typeof v === 'function') throw new Error(`${path} 是函数，不能作为数据导出`);
  if (Array.isArray(v)) return v.map((x, i) => normalize(x, `${path}[${i}]`));
  if (typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v).sort()) {
      if (v[k] === undefined) continue;
      o[k] = normalize(v[k], `${path}.${k}`);
    }
    return o;
  }
  throw new Error(`${path} 类型 ${typeof v} 不能导出`);
}
