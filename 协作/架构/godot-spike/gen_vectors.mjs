// 从真实 JS 构建里导出对拍向量（只读：加载 index.html，调用游戏自己的 mulberry32）。
// 约定：golden 文件里**不存 JSON 小数**——Godot 的 JSON 解析浮点会丢精度。
//   · RNG 抽取存成 uint32 整数（r() * 2^32 恰好是整数）
//   · 其他浮点存 IEEE-754 小端位串（16 位十六进制）
// 用法：node gen_vectors.mjs <JS 仓库路径> <输出 json>
const { loadPage } = await import(new URL('tests/lib/dom-stub.mjs', 'file://' + process.argv[2].replace(/\\/g, '/').replace(/\/?$/, '/')).href);
import { writeFileSync } from 'fs';

const page = loadPage(process.argv[2] + '/index.html', { quiet: true });
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

writeFileSync(process.argv[3], JSON.stringify({
  来源: 'mecha-autobattle JS（P1.2 工作区）· 游戏自身的 mulberry32',
  rng, rounds, jsonProbe, sortInput, sortExpected,
}));
console.log('ok', Object.keys(rng).length, 'seeds × 2000 · rounds', rounds.length);
