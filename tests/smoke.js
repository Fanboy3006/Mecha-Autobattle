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
 * 沙箱外，`npm i playwright` 会被系统拒绝。战棋那边同样的问题，用的办法是
 * `tools/boot-smoke.mjs`：在 Node 的 `vm` 里搭一套最小 DOM / Canvas 替身，把页面
 * 的内联脚本真跑一遍。这里沿用同一套办法，所以 `node tests/smoke.js` 不需要任何依赖。
 * 等哪天 Playwright 能装了，再加一个真浏览器的 `tests/browser-smoke.js`。
 *
 * 用法：node tests/smoke.js
 * ========================================================================== */
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import vm from 'vm';
import { assemble } from '../tools/assemble-src.mjs';

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

/* ============================ DOM / Canvas 替身 ============================ */
/* 只实现游戏真的用到的那点 API；以后片段变多，缺什么就往这里加。 */
const byId = new Map();

function makeCtx() {
  const noop = () => {};
  const target = {
    globalAlpha: 1, fillStyle: '#000', strokeStyle: '#000', lineWidth: 1,
    font: '10px sans-serif', textAlign: 'start', textBaseline: 'alphabetic',
    measureText: t => ({ width: String(t).length * 6 }),
    createLinearGradient: () => ({ addColorStop: noop }),
    createRadialGradient: () => ({ addColorStop: noop }),
    getImageData: (x, y, w, h) => ({ width: w, height: h, data: new Uint8ClampedArray(Math.max(4, w * h * 4)) }),
    createImageData: (w, h) => ({ width: w, height: h, data: new Uint8ClampedArray(Math.max(4, w * h * 4)) }),
    getLineDash: () => [],
  };
  return new Proxy(target, {
    get(t, k) { return k in t ? t[k] : noop; },
    set(t, k, v) { t[k] = v; return true; },
  });
}

function makeEl(tag = 'div', id = '') {
  return {
    tagName: String(tag).toUpperCase(), nodeType: 1, id,
    innerHTML: '', textContent: '', value: '', hidden: false, disabled: false,
    style: {}, dataset: {}, children: [], _attrs: {}, _ctx: null,
    classList: { _s: new Set(), add(...c) { c.forEach(x => this._s.add(x)); }, remove(...c) { c.forEach(x => this._s.delete(x)); }, toggle(c, f) { const on = f === undefined ? !this._s.has(c) : !!f; on ? this._s.add(c) : this._s.delete(c); return on; }, contains(c) { return this._s.has(c); } },
    setAttribute(k, v) { this._attrs[k] = String(v); },
    getAttribute(k) { return k in this._attrs ? this._attrs[k] : null; },
    removeAttribute(k) { delete this._attrs[k]; },
    addEventListener() {}, removeEventListener() {},
    appendChild(c) { this.children.push(c); return c; },
    insertBefore(c) { this.children.push(c); return c; },
    prepend(c) { this.children.unshift(c); return c; },
    removeChild() {}, remove() {}, focus() {}, blur() {}, click() {}, select() {},
    scrollTo() {}, scrollIntoView() {},
    querySelector() { return makeEl('div'); },
    querySelectorAll() { return []; },
    closest() { return null; },
    getBoundingClientRect: () => ({ left: 0, top: 0, right: 900, bottom: 700, width: 900, height: 700 }),
  };
}

function makeCanvas(w = 300, h = 150) {
  const cv = makeEl('canvas');
  cv.width = w; cv.height = h; cv.clientWidth = w; cv.clientHeight = h;
  cv.getContext = () => (cv._ctx = cv._ctx || makeCtx());
  cv.toDataURL = () => 'data:image/png;base64,';
  return cv;
}

function getEl(sel) {
  const id = String(sel).replace(/^#/, '');
  if (!byId.has(id)) byId.set(id, id === 'cv' ? makeCanvas(800, 600) : makeEl('div', id));
  return byId.get(id);
}

const documentStub = {
  documentElement: makeEl('html'), body: makeEl('body'), head: makeEl('head'),
  title: '', cookie: '', hidden: false,
  querySelector: sel => getEl(sel),
  querySelectorAll: () => [],
  getElementById: id => getEl('#' + id),
  createElement: tag => (tag === 'canvas' ? makeCanvas() : makeEl(tag)),
  createDocumentFragment: () => makeEl('fragment'),
  addEventListener() {}, removeEventListener() {},
};

const store = new Map();
const sandbox = {
  console,
  document: documentStub,
  devicePixelRatio: 2, innerWidth: 1440, innerHeight: 900,
  matchMedia: q => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {} }),
  requestAnimationFrame: () => 0, cancelAnimationFrame() {},
  setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {},
  performance: { now: () => Date.now() },
  localStorage: { getItem: k => (store.has(k) ? store.get(k) : null), setItem: (k, v) => store.set(k, String(v)), removeItem: k => store.delete(k), clear: () => store.clear() },
  navigator: { userAgent: 'node' },
  addEventListener() {}, removeEventListener() {},
  getComputedStyle: () => ({ getPropertyValue: () => '#000' }),
  alert() {}, confirm: () => true, prompt: () => null,
};
sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox;

/* ============================ [1] 生成物同步 ============================ */
console.log('冒烟测试：机甲指挥\n\n[1] 生成物与源文件同步');
let body = null;
try {
  body = lf(assemble(join(ROOT, 'src'))).replace(/\n+$/, '') + '\n';
  ok(`源文件（src/shell.html + css + js）能拼出游戏主体：${body.split('\n').length - 1} 行`);
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
const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (!scripts.length) bad('页面里找不到内联脚本');
else info(`找到 ${scripts.length} 段内联脚本，共 ${scripts.reduce((n, s) => n + s.length, 0)} 字符`);

const ctxVm = vm.createContext(sandbox);
let loaded = true;
for (let i = 0; i < scripts.length; i++) {
  try {
    new vm.Script(scripts[i], { filename: `index.html#script${i}` }).runInContext(ctxVm);
    info(`脚本 ${i} 执行完成`);
  } catch (e) {
    bad(`脚本 ${i} 执行报错：${e && e.stack ? e.stack.split('\n').slice(0, 4).join('\n      ') : e}`);
    loaded = false;
  }
}
if (loaded && scripts.length) ok('全部内联脚本执行完毕，没有抛异常');

/* ============================ [4] window.__game 接口 ============================ */
console.log('\n[4] window.__game 就绪');
const G = sandbox.__game;
if (!G) bad('window.__game 没有暴露');
else {
  ok('window.__game 已暴露');
  const checks = [
    ['version', v => typeof v === 'string' && /^\d+\.\d+\.\d+$/.test(v)],
    ['milestone', v => v === 'M0'],
    ['ready', v => v === true],
    ['slots', v => v === 6],                                  // 方案 3.1：双方各 2 排 × 3 列
    ['rows', v => v === 2],
    ['cols', v => v === 3],
    // 带种子的随机数：同一种子必须给出同一串数（方案 6.1）
    ['mulberry32', v => typeof v === 'function' && v(12345)() === v(12345)()],
  ];
  for (const [name, test] of checks) {
    const v = G[name];
    if (test(v)) ok(`__game.${name} = ${v === undefined ? 'undefined' : JSON.stringify(typeof v === 'function' ? 'function' : v)}`);
    else bad(`__game.${name} 不对：${JSON.stringify(v)}`);
  }
}

/* ============================ [5] 顶栏接线（DOM 真的被改到） ============================ */
console.log('\n[5] 脚本真的改到了页面上的元素');
const verEl = byId.get('ver'), msEl = byId.get('ms');
if (!verEl || !msEl) bad('脚本没有查询过 #ver / #ms（boot() 没接线？）');
else if (verEl.textContent === 'v0.0.1' && msEl.textContent === 'M0') ok(`顶栏文字被脚本填成：${verEl.textContent} · ${msEl.textContent}`);
else bad(`顶栏文字不对：#ver=${JSON.stringify(verEl.textContent)} #ms=${JSON.stringify(msEl.textContent)}`);

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '冒烟测试全部通过');
process.exit(fails ? 1 : 0);
