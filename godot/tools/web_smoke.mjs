// Web 冒烟：用真实浏览器打开组装好的站点，检查
//   ① /godot/ 的 Godot 版能启动，浏览器里算出的确定性校验和 = 无界面测试的值；
//   ② 根路径的 JS 版照常能打开（迁移期间朋友在玩的那一版不能断）。
// 用法：node godot/tools/web_smoke.mjs <站点目录> [截图输出目录]
// 依赖：playwright-core；浏览器路径取环境变量 CHROME_PATH（CI 上是 ubuntu 自带的 google-chrome）。
import { chromium } from 'playwright-core';
import { createServer } from 'http';
import { readFile, stat } from 'fs/promises';
import { extname, join, resolve } from 'path';

const SITE = resolve(process.argv[2] || '_site');
const SHOTS = process.argv[3] || null;
const EXPECTED_CHECKSUM = 182751003;   // = tests/unit/test_rng.gd 断言的值
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
let failed = false;
const check = (cond, msg) => { console.log(`${cond ? '✓' : '✗'} ${msg}`); if (!cond) failed = true; };

// ① Godot 版
{
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', m => logs.push(m.text()));
  page.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto(`${base}/godot/`);
  while (Date.now() - t0 < 90000 && !logs.some(l => l.startsWith('MECHA_SMOKE'))) await page.waitForTimeout(250);
  const line = logs.find(l => l.startsWith('MECHA_SMOKE'));
  const got = line ? JSON.parse(line.slice('MECHA_SMOKE '.length)) : null;
  check(!!got, `/godot/ 启动（${Date.now() - t0} ms）`);
  check(got && got.checksum === EXPECTED_CHECKSUM, `浏览器内确定性校验和 = ${got && got.checksum}（期望 ${EXPECTED_CHECKSUM}）`);
  const d = (got && got.data) || {};
  // ★ 2026-10-20：这三个数跟着数据走（旧卫星国防军 / 流星小队退役后 34/32 → 29/28），
  //   改名册 / 卡表时一起改这里，别让它再拦发布；口径 = test_boundary 断言的那三个数。
  check(d.ALLY_T === 29 && d['编成表'] === 47 && d['战术卡牌表'] === 28,
    `Web 包里带上了数据（机师 ${d.ALLY_T} · 编成 ${d['编成表']} · 战术牌 ${d['战术卡牌表']}）`);
  const errors = logs.filter(l => /PAGEERROR|USER ERROR|SCRIPT ERROR/.test(l));
  check(errors.length === 0, `无脚本错误${errors.length ? '：' + errors.slice(0, 3).join(' | ') : ''}`);
  if (SHOTS) await page.screenshot({ path: join(SHOTS, 'smoke-godot.png') });
  await page.close();
}

// ② 根路径 JS 版
{
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));
  const resp = await page.goto(`${base}/`);
  await page.waitForTimeout(1500);
  const title = await page.title();
  check(resp && resp.ok(), `根路径 JS 版 HTTP ${resp && resp.status()}`);
  check(/机甲/.test(title), `根路径页面标题「${title}」`);
  check(errs.length === 0, `JS 版无页面错误${errs.length ? '：' + errs.slice(0, 3).join(' | ') : ''}`);
  if (SHOTS) await page.screenshot({ path: join(SHOTS, 'smoke-js-root.png') });
  await page.close();
}

await browser.close();
server.close();
process.exit(failed ? 1 : 0);
