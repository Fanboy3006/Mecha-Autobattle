// 从 JS 参考版导出 RNG / 四舍五入 / 稳定排序的对拍向量（只读：加载 JS 的 index.html，调用游戏自己的 mulberry32）。
// 用法（仓库根目录）：node godot/tools/gen_rng_vectors.mjs . godot/tests/golden/rng_vectors.json
// 约定：golden 文件里不存 JSON 小数 —— Godot 的 JSON 解析浮点会丢精度。
//   · RNG 抽取存成 uint32 整数（r() * 2^32 恰好是整数）
//   · 其他浮点存 IEEE-754 小端位串（16 位十六进制）
import { writeFileSync } from 'fs';
import { join, resolve } from 'path';
import { pathToFileURL } from 'url';

const JS_ROOT = resolve(process.argv[2] || '.');
const OUT = process.argv[3] || join(JS_ROOT, 'godot', 'tests', 'golden', 'rng_vectors.json');
const { loadPage } = await import(pathToFileURL(join(JS_ROOT, 'tests', 'lib', 'dom-stub.mjs')).href);

const page = loadPage(join(JS_ROOT, 'index.html'), { quiet: true });
const G = page.sandbox.__game;
const mul = G.mulberry32;
if (typeof mul !== 'function') { console.error('mulberry32 未导出'); process.exit(1); }

const 位 = x => { const b = Buffer.alloc(8); b.writeDoubleLE(x); return b.toString('hex'); };

const seeds = [1, 20261010, 20261015, 895903, 4294967295, 2147483648, 123456789];
const rng = {};
for (const s of seeds) {
  const r = mul((s >>> 0) || 1);
  rng[s] = Array.from({ length: 2000 }, () => r() * 4294967296);
}

const rounds = [];
for (let i = -60; i <= 60; i++) { const x = i / 4; rounds.push([位(x), 位(Math.round(x))]); }
for (const x of [0.49999999999999994, -0.49999999999999994, 2.5, -2.5, 1234.5, -1234.5, 0.1 + 0.2, 1e15 + 0.5]) {
  rounds.push([位(x), 位(Math.round(x))]);
}

// 对照组：同一个浮点分别以 JSON 小数和位串存，看 Godot 解析后是否一致
const jsonProbe = [0.1 + 0.2, 1e15 + 0.5, 1 / 3, 123456.789, 0.7 * 3].map(x => [x, 位(x)]);

// 稳定排序：按 k 升序，同 k 保持原顺序（V8 的 Array.prototype.sort 是稳定的）
const sortInput = Array.from({ length: 40 }, (_, i) => ({ id: i, k: (i * 7) % 5 }));
const sortExpected = sortInput.slice().sort((a, b) => a.k - b.k).map(x => x.id);

writeFileSync(OUT, JSON.stringify({
  来源: `机甲指挥 JS 参考版 ${G.version} · 游戏自身的 mulberry32`,
  rng, rounds, jsonProbe, sortInput, sortExpected,
}));
console.log('已写入', OUT, '·', Object.keys(rng).length, '个种子 × 2000 次 · 四舍五入样本', rounds.length);
