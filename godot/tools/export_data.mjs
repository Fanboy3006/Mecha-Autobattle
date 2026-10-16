// 从 JS 参考版导出全部内容数据与规则参数 → godot/data/js/<来源片段>.json
// 用法（仓库根目录）：node godot/tools/export_data.mjs [JS 根目录=.] [输出目录=godot/data/js]
//
// · 只导出「纯数据」顶层常量：对象 / 数组 / 原始值；含函数的 4 个结构（势力特色表、REDUCTIONS、事件表、肉鸽）
//   是代码，按迁移清单逐函数移植，不在这里导出。
// · 数据文件给人编辑，所以保留可读的小数（实测这批数据里的 29 个不同小数经 Godot JSON 解析全部无损）；
//   同时写出 _decimals.json（小数 → IEEE-754 位串），Godot 测试据此守住「以后新加的小数也必须无损」。
// · manifest.json 记录来源版本、规则签名与每个常量的来源片段。
import { mkdirSync, writeFileSync, rmSync } from 'fs';
import { join, resolve } from 'path';
import { CODE_NOT_DATA, loadReference } from './js_ref.mjs';

const JS_ROOT = resolve(process.argv[2] || '.');
const OUT = resolve(process.argv[3] || join(JS_ROOT, 'godot', 'data', 'js'));
const ref = await loadReference(JS_ROOT);
console.log(`JS 参考版 ${ref.version} · ${ref.signature} · ${ref.sealNote}`);

/* 游戏跑在独立的 VM 上下文里，它的 Object.prototype 与这里不是同一个对象 —— 按「原型链只有一层、构造器叫 Object」判断 */
const 是普通对象 = v => {
  if (v === null || typeof v !== 'object') return false;
  if (Array.isArray(v)) return true;
  const p = Object.getPrototypeOf(v);
  return p === null || (Object.getPrototypeOf(p) === null && p.constructor && p.constructor.name === 'Object');
};
const 含函数 = (v, seen = new Set()) => {
  if (typeof v === 'function') return true;
  if (!v || typeof v !== 'object' || seen.has(v)) return false;
  seen.add(v);
  return Object.values(v).some(x => 含函数(x, seen));
};
const 非普通 = (v, seen = new Set()) => {
  if (!v || typeof v !== 'object' || seen.has(v)) return false;
  seen.add(v);
  if (!是普通对象(v)) return true;
  return Object.values(v).some(x => 非普通(x, seen));
};
const 排序键 = v => {
  if (Array.isArray(v)) return v.map(排序键);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().filter(k => v[k] !== undefined).map(k => [k, 排序键(v[k])]));
  return v;
};

const byModule = {};
const skipped = [];
const decimals = new Map();
const 收小数 = v => {
  if (typeof v === 'number' && Number.isFinite(v) && !Number.isInteger(v)) {
    const b = Buffer.alloc(8); b.writeDoubleLE(v); decimals.set(String(v), b.toString('hex'));
  } else if (v && typeof v === 'object') Object.values(v).forEach(收小数);
};
const sets = [];
const 类名 = v => { const p = v && typeof v === 'object' ? Object.getPrototypeOf(v) : null; return p && p.constructor ? p.constructor.name : ''; };
for (const { name, module } of ref.names) {
  let v = ref.REF.consts[name];
  if (CODE_NOT_DATA.has(name)) { skipped.push({ name, module, 原因: '含函数（作为代码移植）' }); continue; }
  if (类名(v) === 'Map') { skipped.push({ name, module, 原因: '运行期缓存（Map），不是数据' }); continue; }
  if (类名(v) === 'Set') {                                                 // 字符串集合 → 按插入顺序导出成数组
    v = [...v];
    sets.push(name);
  }
  if (typeof v === 'function') continue;                                   // 函数：不是数据
  if (typeof v === 'number' && !Number.isFinite(v)) { skipped.push({ name, module, 原因: '非有限数' }); continue; }
  if (含函数(v)) { skipped.push({ name, module, 原因: '含函数（未登记，需人工确认）' }); continue; }
  if (非普通(v)) { skipped.push({ name, module, 原因: '含 Map / Set / 类实例' }); continue; }
  (byModule[module] ||= {})[name] = 排序键(v);
  收小数(v);
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const manifest = { 来源: `机甲指挥 JS 参考版 ${ref.version}`, rulesSignature: ref.signature, tag: 'js-reference-final',
  说明: '由 godot/tools/export_data.mjs 生成；M2 起这批文件归 Godot 维护', 文件: {}, 集合: sets, 未导出: skipped };
let 总数 = 0;
for (const [module, consts] of Object.entries(byModule)) {
  const file = module.replace(/\.js$/, '.json');
  writeFileSync(join(OUT, file), JSON.stringify(consts, null, 1) + '\n');
  manifest.文件[file] = Object.keys(consts);
  总数 += Object.keys(consts).length;
}
writeFileSync(join(OUT, '_decimals.json'), JSON.stringify([...decimals.entries()].map(([s, h]) => [Number(s), h])) + '\n');
writeFileSync(join(OUT, 'manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
console.log(`已导出 ${总数} 个常量 → ${Object.keys(byModule).length} 个文件；不同小数 ${decimals.size} 个；未导出 ${skipped.length} 个：`);
for (const s of skipped) console.log(`  · ${s.name}（${s.module}）：${s.原因}`);
