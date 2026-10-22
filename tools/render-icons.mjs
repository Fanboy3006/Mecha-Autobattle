#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 图标对照表渲染（**只读工具**：只读 art/mech-icons.js，只往 art/out/ 写 PNG）
 * ----------------------------------------------------------------------------
 * 为什么有它：headless 浏览器在本机装不上（沙箱装不了 Playwright），美术改完图标**没法用眼睛看**。
 * 这个脚本把 `art/mech-icons.js` 的矢量指令离线光栅化成 PNG（自带超采样 + 交错渐变 +
 * 只用 Node 内置 zlib 写 PNG，零依赖），用的是**同一份几何数据**，所以看到的就是游戏里的样子。
 * 出处：旧仓库 `tools/render-art.mjs`（战棋自己写的工具代码）。这里是照它的办法新写的一版：
 *       只画图标对照表，不画地图；格子尺寸换成本仓库图标卡片的真实尺寸（34px）。
 *
 * 用法：
 *   node tools/render-icons.mjs                     全部图标 × 2 套调色板
 *   node tools/render-icons.mjs B1 M2 bluefish      只画这几个 id（逗号也行）
 *   node tools/render-icons.mjs --roster            照游戏数据把每一台机体都画一遍
 *                                                   （走游戏自己的挑图规则，最终验收口径）
 *   node tools/render-icons.mjs --size=34           卡片逻辑尺寸（默认 34，真实渲染 = ×2）
 *   node tools/render-icons.mjs --sheet=名字 --out=art/out
 * 输出：art/out/sheet-icons.png（每格「上=大图 / 下=卡片真机放大」）+ 每个 id 一张 icon-<id>.png
 * ========================================================================== */
import { createRequire } from 'module';
import { deflateSync } from 'zlib';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const Icons = require(join(ROOT, 'art', 'mech-icons.js'));

const 参数 = process.argv.slice(2);
const 取值 = (名, 缺省) => {
  const m = 参数.find(a => a.startsWith(`--${名}=`));
  return m ? m.slice(名.length + 3) : 缺省;
};
const SIZE = Math.max(8, Math.min(192, parseInt(取值('size', '34'), 10) || 34));   // 卡片真实尺寸
const ZOOM = Math.max(1, Math.min(8, parseInt(取值('zoom', '5'), 10) || 5));       // 真机尺寸的放大倍数
const OUT = join(ROOT, 取值('out', 'art/out'));
const PAD = 0.06;                                   // 图标盒内留白（和界面上一致）
const SS = 4;                                       // 超采样倍数

/* ---------- 颜色 ---------- */
function parseColor(s) {
  if (typeof s !== 'string') return [0, 0, 0, 1];
  const h = s.trim();
  if (h.startsWith('rgb')) {
    const p = (h.match(/rgba?\(([^)]+)\)/) || [null, '0,0,0,1'])[1].split(',').map(Number);
    return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
  }
  let d = h.replace('#', '');
  if (d.length === 3) d = d[0] + d[0] + d[1] + d[1] + d[2] + d[2];
  const n = parseInt(d, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 1];
}

/* ---------- 图元 → 多边形 ---------- */
function ellipsePoly(cx, cy, rx, ry) {
  const n = Math.max(16, Math.min(96, Math.ceil(Math.max(Math.abs(rx), Math.abs(ry)) * 2)));
  const p = [];
  for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; p.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]); }
  return p;
}
function roundRectPoly(x, y, w, h, r) {
  r = Math.max(0, Math.min(r, Math.min(w, h) / 2));
  if (r <= 0.02) return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]];
  const seg = Math.max(3, Math.min(16, Math.ceil(r * 1.2)));
  const out = [];
  const cs = [[x + w - r, y + r, -Math.PI / 2, 0], [x + w - r, y + h - r, 0, Math.PI / 2],
              [x + r, y + h - r, Math.PI / 2, Math.PI], [x + r, y + r, Math.PI, Math.PI * 1.5]];
  for (const [cx, cy, a0, a1] of cs) for (let i = 0; i <= seg; i++) {
    const a = a0 + (a1 - a0) * i / seg;
    out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
  }
  return out;
}

/* ---------- 扫描线非零环绕填充（覆盖度） ---------- */
function fillPolygon(mask, W, H, poly) {
  let minY = Infinity, maxY = -Infinity;
  for (const p of poly) { if (p[1] < minY) minY = p[1]; if (p[1] > maxY) maxY = p[1]; }
  if (!isFinite(minY)) return;
  const y0 = Math.max(0, Math.floor(minY)), y1 = Math.min(H - 1, Math.ceil(maxY));
  const xs = [];
  for (let y = y0; y <= y1; y++) {
    const sy = y + 0.5;
    xs.length = 0;
    for (let i = 0; i < poly.length; i++) {
      const a = poly[i], b = poly[(i + 1) % poly.length];
      if (a[1] === b[1]) continue;
      const ymin = Math.min(a[1], b[1]), ymax = Math.max(a[1], b[1]);
      if (sy < ymin || sy >= ymax) continue;
      const t = (sy - a[1]) / (b[1] - a[1]);
      xs.push([a[0] + (b[0] - a[0]) * t, a[1] < b[1] ? 1 : -1]);
    }
    if (xs.length < 2) continue;
    xs.sort((p, q) => p[0] - q[0]);
    let w = 0;
    const row = y * W;
    for (let i = 0; i < xs.length - 1; i++) {
      w += xs[i][1];
      if (w === 0) continue;
      const xa = Math.max(0, Math.ceil(xs[i][0] - 0.5));
      const xb = Math.min(W - 1, Math.floor(xs[i + 1][0] - 0.5));
      for (let x = xa; x <= xb; x++) mask[row + x] = 1;
    }
  }
}

/* ---------- 合成（预乘 alpha，画家算法） ---------- */
function composite(dst, W, H, mask, grad, flat, alphaScale) {
  const isGrad = !!grad;
  let fr = 0, fg = 0, fb = 0, fa = 1, gx = 0, gy = 0, glen2 = 1, stops = null;
  if (isGrad) {
    gx = grad.g[1][0] - grad.g[0][0]; gy = grad.g[1][1] - grad.g[0][1];
    glen2 = gx * gx + gy * gy || 1e-9;
    stops = grad.st.map(([t, c]) => [t, parseColor(c)]);
  } else {
    const c = parseColor(flat || '#ffffff');
    fr = c[0]; fg = c[1]; fb = c[2]; fa = c[3];
  }
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const m = mask[i] * alphaScale;
      if (m <= 0) continue;
      let r, g, b, ca;
      if (isGrad) {
        const px = (x + 0.5) - grad.g[0][0], py = (y + 0.5) - grad.g[0][1];
        let t = (px * gx + py * gy) / glen2;
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        let k = stops.length - 2;
        for (let s = 0; s < stops.length - 1; s++) if (t >= stops[s][0] && t <= stops[s + 1][0]) { k = s; break; }
        const t0 = stops[k][0], c0 = stops[k][1], t1 = stops[k + 1][0], c1 = stops[k + 1][1];
        const u = t1 === t0 ? 0 : (t - t0) / (t1 - t0);
        r = c0[0] + (c1[0] - c0[0]) * u; g = c0[1] + (c1[1] - c0[1]) * u; b = c0[2] + (c1[2] - c0[2]) * u;
        ca = c0[3] + (c1[3] - c0[3]) * u;
      } else { r = fr; g = fg; b = fb; ca = fa; }
      const sa = m * ca;
      if (sa <= 0) continue;
      const inv = 1 - sa, j = i * 4;
      dst[j] = r * sa + dst[j] * inv;
      dst[j + 1] = g * sa + dst[j + 1] * inv;
      dst[j + 2] = b * sa + dst[j + 2] * inv;
      dst[j + 3] = sa + dst[j + 3] * inv;
    }
  }
}

/* ---------- 画一条图元 ---------- */
function drawPrim(dst, W, H, prim, k, ox) {
  const T = p => [ox + p[0] * k, ox + p[1] * k];
  const lw = (prim.lw || 0) * k;
  const alpha = prim.alpha == null ? 1 : prim.alpha;

  if (prim.t === 's') {
    const a = T(prim.a), b = T(prim.b);
    const mask = new Float32Array(W * H);
    const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1;
    const nx = -dy / L * lw / 2, ny = dx / L * lw / 2;
    fillPolygon(mask, W, H, [[a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], [b[0] - nx, b[1] - ny], [a[0] - nx, a[1] - ny]]);
    const r = lw / 2;
    fillPolygon(mask, W, H, ellipsePoly(a[0], a[1], r, r));
    fillPolygon(mask, W, H, ellipsePoly(b[0], b[1], r, r));
    composite(dst, W, H, mask, null, prim.fill, alpha);
    return;
  }
  let poly = null;
  if (prim.t === 'p') poly = prim.pts.map(T);
  else if (prim.t === 'e') poly = ellipsePoly(ox + prim.cx * k, ox + prim.cy * k, prim.rx * k, prim.ry * k);
  else if (prim.t === 'r') { const P = T([prim.x, prim.y]); poly = roundRectPoly(P[0], P[1], prim.w * k, prim.h * k, (prim.r || 0) * k); }
  if (!poly) return;

  const gradT = prim.grad ? { g: prim.grad.g.map(T), st: prim.grad.st } : null;
  const mask = new Float32Array(W * H);
  fillPolygon(mask, W, H, poly);
  if (prim.fill || gradT) composite(dst, W, H, mask, gradT, prim.fill, alpha);
  if (prim.stroke && lw > 0) {
    const sm = new Float32Array(W * H);
    const r = lw / 2;
    for (let i = 0; i < poly.length; i++) {
      const a = poly[i], b = poly[(i + 1) % poly.length];
      const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1;
      const nx = -dy / L * r, ny = dx / L * r;
      fillPolygon(sm, W, H, [[a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], [b[0] - nx, b[1] - ny], [a[0] - nx, a[1] - ny]]);
    }
    for (const p of poly) fillPolygon(sm, W, H, ellipsePoly(p[0], p[1], r, r));
    composite(dst, W, H, sm, null, prim.stroke, alpha);
  }
}

/* ---------- 渲染一个图标 → RGBA ---------- */
function renderIcon(id, opts) {
  const S = opts.size, pad = opts.pad || 0;
  const W = Math.round(S * (1 + 2 * pad));
  const Ws = Math.max(4, W * SS);
  const dst = new Float32Array(Ws * Ws * 4);
  const prims = Icons.build(id, opts);
  const k = Ws, ox = pad * Ws;
  for (const p of prims) drawPrim(dst, Ws, Ws, p, k, ox);
  const out = new Uint8Array(W * W * 4);
  for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const j = ((y * SS + sy) * Ws + (x * SS + sx)) * 4;
      r += dst[j]; g += dst[j + 1]; b += dst[j + 2]; a += dst[j + 3];
    }
    const n = SS * SS;
    r /= n; g /= n; b /= n; a /= n;
    const i = (y * W + x) * 4;
    if (a <= 0.0001) { out[i] = out[i + 1] = out[i + 2] = out[i + 3] = 0; continue; }
    out[i] = Math.min(255, Math.round(r / a));
    out[i + 1] = Math.min(255, Math.round(g / a));
    out[i + 2] = Math.min(255, Math.round(b / a));
    out[i + 3] = Math.min(255, Math.round(a * 255));
  }
  return { w: W, h: W, px: out };
}

/* ---------- PNG（只用 zlib） ---------- */
const CRC_TBL = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
const crc32 = buf => { let c = 0xffffffff; for (let i = 0; i < buf.length; i++) c = CRC_TBL[(c ^ buf[i]) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td), 0);
  return Buffer.concat([len, td, c]);
}
function encodePNG(w, h, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  }
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

/* ---------- 画布 ---------- */
function makeCanvas(w, h, bg) {
  const px = new Uint8Array(w * h * 4);
  if (bg) { const c = parseColor(bg); for (let i = 0; i < w * h; i++) { px[i * 4] = c[0]; px[i * 4 + 1] = c[1]; px[i * 4 + 2] = c[2]; px[i * 4 + 3] = 255; } }
  return { w, h, px };
}
function blit(cv, img, dx, dy) {
  for (let y = 0; y < img.h; y++) {
    const ty = dy + y; if (ty < 0 || ty >= cv.h) continue;
    for (let x = 0; x < img.w; x++) {
      const tx = dx + x; if (tx < 0 || tx >= cv.w) continue;
      const i = (y * img.w + x) * 4, j = (ty * cv.w + tx) * 4;
      const a = img.px[i + 3] / 255;
      if (a <= 0) continue;
      const inv = 1 - a;
      cv.px[j] = Math.round(img.px[i] * a + cv.px[j] * inv);
      cv.px[j + 1] = Math.round(img.px[i + 1] * a + cv.px[j + 1] * inv);
      cv.px[j + 2] = Math.round(img.px[i + 2] * a + cv.px[j + 2] * inv);
      cv.px[j + 3] = 255;
    }
  }
}
function upscale(img, f) {
  const out = { w: img.w * f, h: img.h * f, px: new Uint8Array(img.w * f * img.h * f * 4) };
  for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++) {
    const si = (Math.floor(y / f) * img.w + Math.floor(x / f)) * 4, di = (y * out.w + x) * 4;
    out.px[di] = img.px[si]; out.px[di + 1] = img.px[si + 1]; out.px[di + 2] = img.px[si + 2]; out.px[di + 3] = img.px[si + 3];
  }
  return out;
}

/* 5×7 点阵字（只做对照表标签用：A-Z a-z 0-9 - _ 空格） */
const FONT = (() => {
  const F = {
    A:['01110','10001','10001','11111','10001','10001','10001'], B:['11110','10001','11110','10001','10001','10001','11110'],
    C:['01111','10000','10000','10000','10000','10000','01111'], D:['11110','10001','10001','10001','10001','10001','11110'],
    E:['11111','10000','11110','10000','10000','10000','11111'], F:['11111','10000','11110','10000','10000','10000','10000'],
    G:['01110','10001','10000','10111','10001','10001','01110'], H:['10001','10001','11111','10001','10001','10001','10001'],
    I:['11111','00100','00100','00100','00100','00100','11111'], J:['00111','00010','00010','00010','10010','10010','01100'],
    K:['10001','10010','11100','10100','10010','10001','10001'], L:['10000','10000','10000','10000','10000','10000','11111'],
    M:['10001','11011','10101','10101','10001','10001','10001'], N:['10001','11001','10101','10011','10001','10001','10001'],
    O:['01110','10001','10001','10001','10001','10001','01110'], P:['11110','10001','10001','11110','10000','10000','10000'],
    Q:['01110','10001','10001','10001','10101','10010','01101'], R:['11110','10001','10001','11110','10100','10010','10001'],
    S:['01111','10000','01110','00001','00001','10001','01110'], T:['11111','00100','00100','00100','00100','00100','00100'],
    U:['10001','10001','10001','10001','10001','10001','01110'], V:['10001','10001','10001','10001','10001','01010','00100'],
    W:['10001','10001','10001','10101','10101','11011','10001'], X:['10001','01010','00100','00100','00100','01010','10001'],
    Y:['10001','01010','00100','00100','00100','00100','00100'], Z:['11111','00010','00100','00100','01000','10000','11111'],
    '0':['01110','10001','10011','10101','11001','10001','01110'], '1':['00100','01100','00100','00100','00100','00100','01110'],
    '2':['01110','10001','00001','00010','00100','01000','11111'], '3':['11111','00010','00100','00010','00001','10001','01110'],
    '4':['00010','00110','01010','10010','11111','00010','00010'], '5':['11111','10000','11110','00001','00001','10001','01110'],
    '6':['00110','01000','10000','11110','10001','10001','01110'], '7':['11111','00001','00010','00100','01000','01000','01000'],
    '8':['01110','10001','10001','01110','10001','10001','01110'], '9':['01110','10001','10001','01111','00001','00010','01100'],
    '-':['00000','00000','00000','11111','00000','00000','00000'], '_':['00000','00000','00000','00000','00000','00000','11111'],
    '.':['00000','00000','00000','00000','00000','01100','01100'], ' ':['00000','00000','00000','00000','00000','00000','00000'],
    ':':['00000','01100','01100','00000','01100','01100','00000'], '/':['00001','00010','00010','00100','01000','01000','10000'],
  };
  return F;
})();
function drawText(cv, x0, y0, s, col, scale) {
  const c = parseColor(col); let x = x0;
  for (const ch of String(s)) {
    const g = FONT[ch] || FONT[ch.toUpperCase()] || FONT[' '];
    for (let r = 0; r < 7; r++) for (let k = 0; k < 5; k++) {
      if (g[r][k] !== '1') continue;
      for (let sy = 0; sy < scale; sy++) for (let sx = 0; sx < scale; sx++) {
        const px = x + k * scale + sx, py = y0 + r * scale + sy;
        if (px < 0 || px >= cv.w || py < 0 || py >= cv.h) continue;
        const j = (py * cv.w + px) * 4;
        cv.px[j] = c[0]; cv.px[j + 1] = c[1]; cv.px[j + 2] = c[2]; cv.px[j + 3] = 255;
      }
    }
    x += 6 * scale;
  }
  return x - x0;
}
const 文字宽 = (s, scale) => String(s).length * 6 * scale;

/* ==================== 主流程 ==================== */
mkdirSync(OUT, { recursive: true });

/* 本仓库的调色板：我方按势力、敌方一律 enemy（和 src/js/78-图标.js 一个口径） */
const 图标层 = (() => {
  const 势力 = {
    B1:'影世界', B2:'影世界', B3:'影世界', B4:'影世界',
    M1:'月球王国', M2:'月球王国', M3:'月球王国', M4:'月球王国', M5:'月球王国',
    CB1:'天人', CB2:'天人', CB3:'天人', CB4:'天人', CB5:'天人',
    S1:'卫星国防军', S2:'卫星国防军', S3:'卫星国防军', S4:'卫星国防军', S5:'卫星国防军',
    W1:'流星小队', W2:'流星小队', W3:'流星小队', W4:'流星小队', W5:'流星小队',
    A1:'ATX', A2:'ATX', A3:'ATX', A4:'ATX', A5:'ATX',
    U1:'秘银', U2:'秘银', U6:'秘银', U7:'秘银', U8:'秘银',
  };
  /* 战斗分类（抄自 src/js/10-数据.js 的 tags.战斗分类，2026-10-11 实测值）：
   * 决定胸口核心色，和游戏里 `78-图标.js` 传给 MI.build 的 role 是同一个口径。 */
  const 角色 = {
    B1:'近卫', B2:'尖兵', B3:'特种', B4:'特种', M1:'指挥', M2:'重装', M3:'指挥', M4:'狙击', M5:'特种',
    CB1:'近卫', CB2:'狙击', CB3:'特种', CB4:'重装', CB5:'重装',
    S1:'特种', S2:'指挥', S3:'狙击', S4:'近卫', S5:'重装',
    W1:'狙击', W2:'近卫', W3:'重装', W4:'近卫', W5:'近卫',
    A1:'近卫', A2:'狙击', A3:'尖兵', A4:'重装', A5:'指挥',
    U1:'近卫', U2:'指挥', U6:'狙击', U7:'特种', U8:'尖兵',
  };
  return { 势力, 角色 };
})();

function 调色板(id) {
  const 势 = 图标层.势力[id];
  return 势 ? (Icons.FACTION_PAL[势] || 'cb') : 'enemy';
}
function 角色(id) { return 图标层.角色[id]; }
/* 三个画法（口径和游戏对齐）：
 *   画卡片(id, pal)   —— 卡片真实尺寸 = 逻辑 SIZE(34) × 倍 2 = 68 像素（LOD m，和 `78-图标.js` 一样）
 *   画真机(id, pal)   —— 34 逻辑像素那版（LOD 落 's'，游戏里放到更小的位置时就是这一档）
 *   画大图(id, pal)   —— 96 像素放大（LOD l，用来看几何细节）
 * 我上一版把「真机放大」写成 `upscale(画(…SIZE×2…), ZOOM)`，等于 2×ZOOM 倍、还画到了格子外面（已修）。 */
const 画大图 = (id, size, pal) => renderIcon(id, {
  size, pad: PAD, pal: pal || 调色板(id), plate: 'none', role: 角色(id), outline: '#05070d', lod: 'l',
});
const 画卡片 = (id, pal) => renderIcon(id, {
  size: SIZE * 2, pad: PAD, pal: pal || 调色板(id), plate: 'none', role: 角色(id), outline: '#05070d',
});

/* 选出要画的 id */
const 指名 = 参数.filter(a => !a.startsWith('--')).flatMap(a => a.split(',')).map(s => s.trim()).filter(Boolean);

/* --roster：直接照游戏数据（index.html 里跑起来的 ALLY_T / ENEMY_T）渲染每一台机体，
 * 用的是**游戏自己那条挑图规则**（图标.图标号 + 图标.调色板），所以看到的就是卡片上的那一张。
 * 这是最终验收口径：数据里每一台都画出来，谁借了原型一眼就看得出来。 */
let ROSTER = null;
if (参数.includes('--roster')) {
  const { loadPage } = await import('../tests/lib/dom-stub.mjs');
  const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
  if (page.errors.length) { console.error('index.html 跑不起来，先跑 node tools/build-src.mjs'); page.errors.forEach(e => console.error('  ' + e)); process.exit(2); }
  const G = page.sandbox.__game, MI = G.MechIcons, 图标 = G.图标;
  const 取 = (键, 方) => ({ id: 图标.图标号(键, 方), pal: 图标.调色板(键, 方) });
  const 我方 = G.ALLY_T.map(t => ({ id: 取(t.mech, 'ally').id, pal: 取(t.mech, 'ally').pal,
    标: `${t.pilot}-${t.mech}`, 专属: !!MI.ICON_BY_MECH[t.mech] }));
  const 敌方 = Object.entries(G.ENEMY_T).map(([k, t]) => ({ id: 取(k, 'enemy').id, pal: 'enemy',
    标: String(t.mech), 专属: !!MI.ICON_BY_MECH[t.mech] }));
  ROSTER = [...我方, ...敌方];
  console.log(`照游戏数据渲染 ${ROSTER.length} 台（我方 ${我方.length} + 敌方 ${敌方.length}）：` +
    `专属 ${ROSTER.filter(r => r.专属).length} / 借原型 ${ROSTER.filter(r => !r.专属).length}`);
}

const ALLY_IDS = ['B1', 'B2', 'B3', 'B4', 'M1', 'M2', 'M3', 'M4', 'M5',
  'CB1', 'CB2', 'CB3', 'CB4', 'CB4N', 'CB5',
  'S1', 'S2', 'S3', 'S4', 'S5', 'W1', 'W2', 'W3', 'W4', 'W5',
  'A1', 'A2', 'A3', 'A4', 'A5', 'U1', 'U2', 'U6', 'U7', 'U8'];
const ENEMY_IDS = ['grunt', 'hound', 'drone', 'ironwall', 'raider', 'turret', 'shield', 'pursuer',
  'fighter', 'artillery', 'fortress', 'flagship', 'debris', 'chest'];
const 库 = Icons.ids;
/* 每一格：{ id, pal（不传=按内置势力表）, 标（图上写的名字） } */
const LIST = ROSTER
  ? ROSTER.filter(r => r.id).map(r => ({ id: r.id, pal: Icons.PAL[r.pal] || r.pal, 标: `${r.标}${r.专属 ? '' : '←借'}` }))
  : (指名.length ? 指名 : 库.slice()).map(id => ({ id, pal: null, 标: id }));
const 非法 = LIST.filter(e => 库.indexOf(e.id) < 0).map(e => e.id);
if (非法.length) { console.error('图标库里没有这些 id：' + 非法.join('、')); process.exit(2); }

/* 单图标：大图（看得清几何） + 真机尺寸放大 + 标签。
 * 布局：每格自上而下 = 标签 / 大图 / 真机尺寸放大图；
 * 行高必须容下「大图 + 真机放大图」，否则上一格会压到下一格（第一版就踩过这个坑）。 */
const 大图尺寸 = 96, 大图格 = 108;      // 大图按 108 渲染（含 6% 留白），格子留 108 宽
const ZW = 大图格;                      // 真机放大图也做成 108 见方，格子整齐
const 列数 = ROSTER ? 8 : (参数.includes('--wide') ? 8 : 5);
const 行数 = Math.ceil(LIST.length / 列数);
const GAP = 8, LABEL = 12;
const CW = 大图格 + GAP;
const CH = LABEL + 大图格 + 4 + ZW + GAP;
const sheet = makeCanvas(CW * 列数 + GAP, CH * 行数 + GAP, '#0b0e12');

/* 最近邻放大到固定边长（放大倍数不是整数时取最近的整数倍）。 */
function 放大到(img, 目标) {
  const f = Math.max(1, Math.round(目标 / img.w));
  return upscale(img, f);
}

LIST.forEach((e, i) => {
  const { id, pal, 标 } = e;
  const gx = (i % 列数) * CW + GAP, gy = Math.floor(i / 列数) * CH + GAP;
  const big = 画大图(id, 大图尺寸, pal);              // LOD l：几何细节
  const small = 放大到(画卡片(id, pal), ZW);           // 卡片真实渲染（68px）放大，看玩家看到的像素
  if (参数.includes('--debug-blit') && i < 2) {
    console.log(`  [blit ${id}] big=${big.w}×${big.h} @ (${gx}, ${gy + LABEL})` +
      ` · small=${small.w}×${small.h} @ (${gx}, ${gy + LABEL + 大图尺寸 + 4})`);
  }
  blit(sheet, big, gx, gy + LABEL);
  blit(sheet, small, gx + Math.round((ZW - small.w) / 2), gy + LABEL + 大图格 + 4);
  // 8× 点阵印不出中文，这里只印能印的字符（id 或「借」的标记）
  const 可印 = String(标).replace(/[^\x20-\x7e]/g, '').trim() || String(id).slice(0, 8);
  drawText(sheet, gx + 2, gy + 2, 可印.slice(0, Math.floor((CW - 2) / 6)), '#9fd0ff', 1);
});

const SHEET_NAME = String(取值('sheet', 'sheet-icons'));
writeFileSync(join(OUT, `${SHEET_NAME}.png`), encodePNG(sheet.w, sheet.h, sheet.px));
console.log(`  每格 ${CW}×${CH}（标签 ${LABEL} + 大图 ${大图尺寸} + 真机放大 ${ZW} + 底 ${GAP}）；` +
  `格数 ${LIST.length} = ${列数} 列 × ${行数} 行`);

/* 每个 id 单出一张（大图 + 卡片真机放大），方便一张一张看 */
let 第几 = 0;
for (const e of LIST) {
  const id = e.id, pal = e.pal;
  const big = 画大图(id, 256, pal);
  const small = 放大到(画卡片(id, pal), 256);
  const cv = makeCanvas(256 * 2 + 40, 256 + 40, '#12151a');
  blit(cv, big, 8, 8);
  blit(cv, small, 256 + 24, 8);
  drawText(cv, 8, 256 + 26, (ROSTER ? `${id}` : id).slice(0, 40), '#9fd0ff', 1);
  const 名 = ROSTER ? `${id}-${第几++}` : id.replace(/[^\w-]/g, '_');
  writeFileSync(join(OUT, `icon-${名}.png`), encodePNG(cv.w, cv.h, cv.px));
}

const OUT相对 = OUT.replace(ROOT + '\\', '');
console.log(`⚠ 只为了「用眼睛看图标」，不进游戏、不参与构建（产物在 ${OUT相对}）`);
console.log(`画了 ${LIST.length} 个图标：卡片真实口径 = 逻辑 ${SIZE}px × 倍 2 = ${SIZE * 2}px（LOD m，和 78-图标.js 一致）；大图 ${大图尺寸}px（LOD l）`);
console.log(`输出：${OUT相对}/${SHEET_NAME}.png（${sheet.w}×${sheet.h}，每格「上=大图 / 下=卡片真机放大」）+ ${LIST.length} 张 icon-*.png`);

