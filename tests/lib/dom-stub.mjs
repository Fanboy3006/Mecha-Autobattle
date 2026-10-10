/* ============================================================================
 * 测试用的最小 DOM / Canvas 替身（不依赖任何 npm 包）
 * ----------------------------------------------------------------------------
 * 本机（DSH 沙箱）装不了 Playwright：npm 缓存目录在沙箱外，`npm i playwright`
 * 会被系统拒绝。战棋那边同样的问题，用的是 `tools/boot-smoke.mjs` 的办法：
 * 在 Node 的 `vm` 里搭一套最小 DOM / Canvas 替身，把页面里的内联脚本真跑一遍。
 * 这里把同一套替身抽出来，让 `tests/smoke.js`、`tests/sim.js` 共用一份。
 *
 * 只实现游戏真的用到的那点 API；以后片段变多，缺什么就往这里加。
 * ========================================================================== */
import { readFileSync } from 'fs';
import vm from 'vm';

/* ---------- Canvas ---------- */
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

/* ---------- 元素 ---------- */
export function makeEl(tag = 'div', id = '') {
  return {
    tagName: String(tag).toUpperCase(), nodeType: 1, id,
    innerHTML: '', textContent: '', value: '', hidden: false, disabled: false,
    style: {}, dataset: {}, children: [], _attrs: {}, _ctx: null,
    classList: {
      _s: new Set(),
      add(...c) { c.forEach(x => this._s.add(x)); },
      remove(...c) { c.forEach(x => this._s.delete(x)); },
      toggle(c, f) { const on = f === undefined ? !this._s.has(c) : !!f; on ? this._s.add(c) : this._s.delete(c); return on; },
      contains(c) { return this._s.has(c); },
    },
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

/* ---------- 沙箱 ---------- */
export function makeSandbox() {
  const byId = new Map();
  const getEl = sel => {
    const id = String(sel).replace(/^#/, '');
    if (!byId.has(id)) byId.set(id, id === 'cv' ? makeCanvas(800, 600) : makeEl('div', id));
    return byId.get(id);
  };

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
    localStorage: {
      getItem: k => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: k => store.delete(k), clear: () => store.clear(),
    },
    navigator: { userAgent: 'node' },
    addEventListener() {}, removeEventListener() {},
    getComputedStyle: () => ({ getPropertyValue: () => '#000' }),
    alert() {}, confirm: () => true, prompt: () => null,
  };
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox;
  return { sandbox, byId, getEl };
}

/* ---------- 加载页面里的内联脚本 ---------- */
export function inlineScripts(html) {
  return [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]);
}

/** 把 html 里的全部内联脚本在沙箱里跑一遍，返回跑错的信息（没报错就是空数组）。 */
export function runScripts(sandbox, scripts, { quiet = true } = {}) {
  const ctxVm = vm.createContext(sandbox);
  const errors = [];
  for (let i = 0; i < scripts.length; i++) {
    try {
      new vm.Script(scripts[i], { filename: `index.html#script${i}` }).runInContext(ctxVm);
      if (!quiet) console.log(`    · 脚本 ${i} 执行完成（${scripts[i].length} 字符）`);
    } catch (e) {
      errors.push(`脚本 ${i}：${e && e.stack ? e.stack.split('\n').slice(0, 4).join('\n      ') : e}`);
    }
  }
  return errors;
}

/** 一步到位：读 index.html → 建沙箱 → 跑脚本 → 返回 { sandbox, byId, scripts, errors }。 */
export function loadPage(indexPath, opts) {
  const html = readFileSync(indexPath, 'utf8').replace(/\r\n/g, '\n');
  const { sandbox, byId, getEl } = makeSandbox();
  const scripts = inlineScripts(html);
  const errors = runScripts(sandbox, scripts, opts);
  return { html, sandbox, byId, getEl, scripts, errors };
}
