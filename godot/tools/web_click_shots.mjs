// M4 试玩截图：进 Web 版，从主菜单点进去，逐屏截图（给作者看的 D-01 证据）
// 用法：node m4_shots.mjs <站点目录> <截图目录>
// 依赖：playwright-core；浏览器路径取 CHROME_PATH。
// 说明：Godot Web 画在 <canvas> 上，页面里没有 DOM 按钮 —— 只能按坐标点。
//       坐标来自 1280×720 视口下的 smoke-godot.png 实测（画布与视口 1:1）。
import { chromium } from 'playwright-core';
import { createServer } from 'http';
import { readFile, stat, mkdir } from 'fs/promises';
import { extname, join, resolve } from 'path';

const SITE = resolve(process.argv[2] || '_site');
const SHOTS = resolve(process.argv[3] || 'shots');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.mp3': 'audio/mpeg', '.json': 'application/json', '.css': 'text/css' };

await mkdir(SHOTS, { recursive: true });

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
async function openGodot() {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => logs.push(m.text()));
  page.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  await page.goto(`${base}/godot/`);
  const t0 = Date.now();
  while (Date.now() - t0 < 90000 && !logs.some(l => l.startsWith('MECHA_SMOKE'))) await page.waitForTimeout(250);
  await page.waitForTimeout(1200);          // 让首屏画完
  return page;
}
const shot = async (page, name) => { await page.screenshot({ path: join(SHOTS, name) }); console.log('  截图 ' + name); };

// ── 路径 A：主菜单 → 快速测试战斗（D-01 手牌体感入口）
{
  const page = await openGodot();
  await shot(page, 'm4-01-menu.png');
  console.log('A: 点「快速测试战斗」(638,494)');
  await page.mouse.click(638, 494);
  await page.waitForTimeout(2500);
  await shot(page, 'm4-02-battle.png');
  // 战斗中：点一张手牌（手牌栏在画面下方，先猜第一张牌的位置）
  await page.waitForTimeout(500);
  await page.close();
}

// ── 路径 B：主菜单 → 开始新肉鸽（看分队选择屏）
{
  const page = await openGodot();
  console.log('B: 点「开始新肉鸽」(638,465)');
  await page.mouse.click(638, 465);
  await page.waitForTimeout(2500);
  await shot(page, 'm4-03-squad.png');
  await page.close();
}

// ── 路径 C：主菜单 → 战术牌库（弹窗层）
{
  const page = await openGodot();
  console.log('C: 点顶栏「战术牌库」(1101,58)');
  await page.mouse.click(1101, 58);
  await page.waitForTimeout(2000);
  await shot(page, 'm4-04-modal.png');
  await page.close();
}

const errors = logs.filter(l => /PAGEERROR|USER ERROR|SCRIPT ERROR/.test(l));
console.log('脚本错误：' + errors.length + (errors.length ? ' → ' + errors.slice(0, 5).join(' | ') : ''));
await browser.close();
server.close();
process.exit(errors.length ? 1 : 0);
