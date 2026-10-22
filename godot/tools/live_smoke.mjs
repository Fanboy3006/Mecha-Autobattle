// 对【线上 Pages 站点】做一次真浏览器冒烟（与 godot/tools/web_smoke.mjs 的区别：
//   那个跑本地组装好的 _site；这个直接打真实的 https://<user>.github.io/... ——
//   会额外覆盖真实 CDN、真实 HTTPS、Pages 的头部与 MIME。）
// 用法：node live_smoke.mjs [基础URL]
import { chromium } from 'playwright-core';

const BASE = process.argv[2] || 'https://fanboy3006.github.io/Mecha-Autobattle';
const EXPECTED = 182751003;

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || undefined,
  args: ['--headless=new', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  headless: false,
});
let failed = false;
const check = (c, m) => { console.log(`${c ? '✓' : '✗'} ${m}`); if (!c) failed = true; };

// ① Godot M4 版（线上）
{
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', m => logs.push(m.text()));
  page.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto(`${BASE}/godot/`);
  while (Date.now() - t0 < 120000 && !logs.some(l => l.startsWith('MECHA_SMOKE'))) await page.waitForTimeout(300);
  const line = logs.find(l => l.startsWith('MECHA_SMOKE'));
  const got = line ? JSON.parse(line.slice('MECHA_SMOKE '.length)) : null;
  check(!!got, `线上 /godot/ 启动（${Date.now() - t0} ms）`);
  check(got && got.checksum === EXPECTED, `浏览器内确定性校验和 = ${got && got.checksum}（期望 ${EXPECTED}）`);
  const d = (got && got.data) || {};
  check(d.ALLY_T === 31 && d['编成表'] === 93 && d['战术卡牌表'] === 28,
    `线上包里带上了数据（机师 ${d.ALLY_T} · 编成 ${d['编成表']} · 战术牌 ${d['战术卡牌表']}）`);
  const errs = logs.filter(l => /PAGEERROR|USER ERROR|SCRIPT ERROR/.test(l));
  check(errs.length === 0, `无脚本错误${errs.length ? '：' + errs.slice(0, 3).join(' | ') : ''}`);
  // 顺手验一次「点得动」：主菜单上点「快速测试战斗」，看屏幕能不能切到战斗屏
  await page.waitForTimeout(1500);
  await page.mouse.click(638, 494);
  await page.waitForTimeout(3000);
  const after = logs.length;
  const errs2 = logs.slice(after).filter(l => /PAGEERROR|USER ERROR|SCRIPT ERROR/.test(l));
  check(errs2.length === 0, `线上点「快速测试战斗」之后无脚本错误（新增日志 ${logs.length - after} 行）`);
  await page.screenshot({ path: 'F:\\DSH-mecha\\.tools\\smoke\\live-battle.png' });
  await page.close();
}

// ② 根路径 JS 旧版仍能打开
{
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));
  const resp = await page.goto(`${BASE}/`);
  await page.waitForTimeout(2000);
  check(resp && resp.ok(), `线上根路径 JS 版 HTTP ${resp && resp.status()}`);
  check(/机甲/.test(await page.title()), `根路径标题「${await page.title()}」`);
  check(errs.length === 0, `JS 版无页面错误`);
  await page.close();
}

await browser.close();
process.exit(failed ? 1 : 0);
