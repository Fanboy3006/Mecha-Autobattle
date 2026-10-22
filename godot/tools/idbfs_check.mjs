// 检查 Web 版的**存档存储层**：Godot 的 user:// 在浏览器里走 IDBFS（IndexedDB）。
//   headless 下会报 「Could not create directory: user:/...」，浏览器里**不该**报；
//   并且启动后 IndexedDB 里应该出现 Godot 建的文件系统库。
// 用法：node idbfs_check.mjs <站点目录>
// 依赖：playwright-core；浏览器路径取 CHROME_PATH。
import { chromium } from 'playwright-core';
import { createServer } from 'http';
import { readFile, stat } from 'fs/promises';
import { extname, join, resolve } from 'path';

const SITE = resolve(process.argv[2] || '_site');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.mp3': 'audio/mpeg', '.json': 'application/json', '.css': 'text/css' };

const server = createServer(async (req, res) => {
  try {
    let p = join(SITE, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if ((await stat(p)).isDirectory()) p = join(p, 'index.html');
    res.writeHead(200, { 'Content-Type': TYPES[extname(p)] || 'application/octet-stream' });
    res.end(await readFile(p));
  } catch { res.writeHead(404); res.end(); }
}).listen(0);
const base = `http://127.0.0.1:${server.address().port}`;

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || undefined,
  args: ['--headless=new', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  headless: false,
});

const logs = [];
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', m => logs.push(m.text()));
page.on('pageerror', e => logs.push('PAGEERROR ' + e.message));

await page.goto(`${base}/godot/`);
const t0 = Date.now();
while (Date.now() - t0 < 90000 && !logs.some(l => l.startsWith('MECHA_SMOKE'))) await page.waitForTimeout(250);
const 起来了 = logs.some(l => l.startsWith('MECHA_SMOKE'));
console.log(`✓ 游戏启动 = ${起来了}（${Date.now() - t0} ms）`);

// 给 Godot 的文件系统一点时间落库
await page.waitForTimeout(2500);

// ① IndexedDB 里有没有 Godot 的文件系统库
const 库 = await page.evaluate(async () => {
  if (!indexedDB.databases) return { 支持: false, 名字们: [] };
  const dbs = await indexedDB.databases();
  return { 支持: true, 名字们: dbs.map(d => d.name) };
});
console.log(`✓ indexedDB.databases() 可用 = ${库.支持}`);
console.log(`  IndexedDB 里的库：${JSON.stringify(库.名字们)}`);

// ② 控制台里有没有 user:// 建目录失败（headless 下必然出现的那几条）
const 建目录失败 = logs.filter(l => /Could not create directory|Error attempting to create data dir|Failed to open log file/i.test(l));
console.log(`${建目录失败.length === 0 ? '✓' : '✗'} user:// 建目录失败条数 = ${建目录失败.length}${建目录失败.length ? ' → ' + 建目录失败.slice(0, 3).join(' | ') : ''}`);

// ③ 有没有脚本错误
const 错误 = logs.filter(l => /PAGEERROR|USER ERROR|SCRIPT ERROR/.test(l));
console.log(`${错误.length === 0 ? '✓' : '✗'} 脚本错误 = ${错误.length}${错误.length ? ' → ' + 错误.slice(0, 4).join(' | ') : ''}`);

await page.screenshot({ path: join(SITE, '..', 'shots', 'idbfs-after-boot.png') }).catch(() => {});
await browser.close();
server.close();
process.exit((起来了 && 建目录失败.length === 0 && 错误.length === 0) ? 0 : 1);
