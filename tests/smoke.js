#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 冒烟测试
 * ----------------------------------------------------------------------------
 * 检查三件事：
 *   1. 生成物与源文件同步（`src/artifact-fragment.html`、`index.html`）；
 *   2. `index.html` 是一份完整、可双击打开的页面（doctype / head / 标记齐全）；
 *   3. 页面里**所有内联脚本真的能跑起来**、不报错，并且 `window.__game` 就绪、
 *      顶栏的版本 / 里程碑文字被脚本填上（证明 DOM 接线是通的）。
 *
 * 为什么不直接用 Playwright：本机（DSH 沙箱）装不了 Playwright —— npm 缓存在
 * 沙箱外，`npm i playwright` 会被系统拒绝。战棋那边同样的问题，用的是
 * `tools/boot-smoke.mjs`：在 Node 的 `vm` 里搭一套最小 DOM / Canvas 替身把页面
 * 的内联脚本真跑一遍。替身在 `tests/lib/dom-stub.mjs`，和 `tests/sim.js` 共用。
 * 等哪天 Playwright 能装了，再加一个真浏览器的 `tests/browser-smoke.js`。
 *
 * 用法：node tests/smoke.js
 * ========================================================================== */
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { 拼接主体 } from '../tools/build-src.mjs';   // M5：生成物 = shell + css + js + ART/AUDIO 素材，共用同一个函数
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const INDEX = join(ROOT, 'index.html');
const FRAG = join(ROOT, 'src', 'artifact-fragment.html');
const BEGIN = '<!-- ===== 游戏主体 BEGIN';
const END = '<!-- ===== 游戏主体 END ===== -->';
const lf = s => s.replace(/\r\n/g, '\n');

let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);

/* ============================ [1] 生成物同步 ============================ */
console.log('冒烟测试：机甲指挥\n\n[1] 生成物与源文件同步');
let body = null;
try {
  body = 拼接主体();
  ok(`源文件（src/shell.html + css + js + art + audio）能拼出游戏主体：${body.split('\n').length - 1} 行`);
} catch (e) { bad(`拼接失败：${e.message}`); }

if (body) {
  const frag = existsSync(FRAG) ? lf(readFileSync(FRAG, 'utf8')) : null;
  if (frag === null) bad('缺少 src/artifact-fragment.html（跑一次 node tools/build-src.mjs）');
  else if (frag !== body) bad('src/artifact-fragment.html 与源文件不同步（跑一次 node tools/build-src.mjs）');
  else ok('src/artifact-fragment.html 与源文件一致');
}

/* ============================ [2] index.html 完整性 ============================ */
console.log('\n[2] index.html 是一份能双击打开的完整页面');
if (!existsSync(INDEX)) bad('找不到 index.html（跑一次 node tools/build-src.mjs）');
const html = existsSync(INDEX) ? lf(readFileSync(INDEX, 'utf8')) : '';
if (html) {
  const need = [
    ['<!doctype html>', 'doctype'],
    ['<meta charset="utf-8">', 'charset'],
    ['<div class="app">', '游戏标记 .app'],
    ['id="ver"', '版本文字 #ver'],
    ['id="ms"', '里程碑文字 #ms'],
    ['id="btnSound"', '声音开关按钮 #btnSound'],
    /* M5：素材块真的被注入进去了（标记 + 素材本体） */
    ['<!-- ===== ART:mech-icons BEGIN', 'ART 素材块标记'],
    ['root.MechIcons = api', '机体图标素材本体'],
    ['<!-- ===== AUDIO BEGIN', 'AUDIO 素材块标记'],
    ['globalThis.MechAudio', '音乐播放层本体'],
    ['MA.openRoom = openRoom', '音乐鉴赏页本体'],
  ];
  const miss = need.filter(([s]) => !html.includes(s)).map(([, n]) => n);
  if (miss.length) bad('index.html 里缺少：' + miss.join('、'));
  else ok('doctype / charset / 游戏标记 / 顶栏文字都在');

  if (html.includes(BEGIN) && html.includes(END)) ok('游戏主体 BEGIN / END 标记齐全');
  else bad('index.html 里找不到「游戏主体 BEGIN / END」标记');

  if (body) {
    const at = html.indexOf(BEGIN);
    const i = at < 0 ? -1 : at + html.slice(at).indexOf('-->') + 3;
    const j = html.indexOf(END);
    if (i > 0 && j > i) {
      if (html.slice(i, j) === '\n' + body + '\n') ok('index.html 的游戏主体与源文件一致');
      else bad('index.html 的游戏主体与源文件不一致（跑一次 node tools/build-src.mjs）');
    }
  }

  if (/<!--\s*@include\s/.test(html)) bad('index.html 里还有没被替换的 @include 占位行');
  else ok('没有残留的 @include 占位行');
}

/* ============================ [3] 跑页面里的内联脚本 ============================ */
console.log('\n[3] 页面里的内联脚本能真的跑起来');
const page = html ? loadPage(INDEX) : { sandbox: {}, byId: new Map(), scripts: [], errors: ['没有 index.html，跳过'] };
if (!page.scripts.length) bad('页面里找不到内联脚本');
else info(`找到 ${page.scripts.length} 段内联脚本，共 ${page.scripts.reduce((n, s) => n + s.length, 0)} 字符`);
if (page.errors.length) page.errors.forEach(e => bad('内联脚本执行报错：' + e));
else if (page.scripts.length) ok('全部内联脚本执行完毕，没有抛异常');

/* ============================ [4] window.__game 接口 ============================ */
console.log('\n[4] window.__game 就绪');
const G = page.sandbox.__game;
if (!G) bad('window.__game 没有暴露');
else {
  ok('window.__game 已暴露');
  const checks = [
    ['version', v => typeof v === 'string' && /^\d+\.\d+\.\d+$/.test(v)],
    ['milestone', v => v === 'M4' || v === '晋升+零件'],       // M4 之后的追加段会把里程碑文字换掉（v0.6.1 起）
    ['ready', v => v === true],
    ['slots', v => v === 5],                                  // 作者 2026-10-10：暂时「前 3 后 2」= 5 格
    ['rows', v => v === 2],
    ['行列数', v => typeof v === 'function' && v(0) === 3 && v(1) === 2],   // 前排 3 格、后排 2 格
    // 带种子的随机数：同一种子必须给出同一串数（方案 6.1）
    ['mulberry32', v => typeof v === 'function' && v(12345)() === v(12345)()],
    // M1 的战斗内核：simulate(我方, 敌方, 指令, 种子) → 逐条战斗记录
    ['simulate', v => typeof v === 'function'],
    ['编成表', v => Array.isArray(v) && v.length > 0],
    ['默认五人队', v => Array.isArray(v) && v.length > 0],
    ['ALLY_T', v => Array.isArray(v) && v.length === 34],
    // M2 的界面与播放
    ['界面', v => v && typeof v.开屏 === 'function' && typeof v.开战 === 'function'],
    ['播放', v => v && typeof v.载入 === 'function' && typeof v.tick === 'function'],
    // M5 的美术与音乐
    ['MechIcons', v => v && typeof v.build === 'function' && typeof v.draw === 'function'],   // ART 块注入成功
    ['MechAudio', v => v && typeof v.play === 'function' && typeof v.themeOf === 'function'], // AUDIO 块注入成功
    ['图标', v => v && typeof v.卡 === 'function'],
    ['音乐', v => v && typeof v.场景切换 === 'function'],
  ];
  for (const [name, test] of checks) {
    const v = G[name];
    if (test(v)) ok(`__game.${name} = ${v === undefined ? 'undefined' : JSON.stringify(typeof v === 'function' ? 'function' : v)}`);
    else bad(`__game.${name} 不对：${JSON.stringify(v)}`);
  }
}

/* ============================ [5] 顶栏接线（DOM 真的被改到） ============================ */
console.log('\n[5] 脚本真的改到了页面上的元素');
const verEl = page.byId.get('ver'), msEl = page.byId.get('ms');
if (!verEl || !msEl) bad('脚本没有查询过 #ver / #ms（boot() 没接线？）');
else if (verEl.textContent === 'v' + (G ? G.version : '?') && msEl.textContent === (G ? G.milestone : '?')) ok(`顶栏文字被脚本填成：${verEl.textContent} · ${msEl.textContent}`);
else bad(`顶栏文字不对：#ver=${JSON.stringify(verEl.textContent)} #ms=${JSON.stringify(msEl.textContent)}`);

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '冒烟测试全部通过');
process.exit(fails ? 1 : 0);
