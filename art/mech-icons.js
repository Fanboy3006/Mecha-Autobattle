/* ============================================================================
 * 机甲战棋 · 机体图标矢量素材  v1
 * ----------------------------------------------------------------------------
 * 这是地图上单位图标的**唯一几何来源**。所有图标都是原创矢量图形，不含外部
 * 图片、不含版权素材，可以随单文件 HTML 一起发布。
 *
 * 【坐标约定】
 *   图标在自己的**单位空间**里描述：左下 (0,0) 到右下 (1,1)。
 *   一个图标会被缩放到「单位占用的格子区域」上（1×1 就是 1 格，2×2 就是 2×2 格）。
 *   y 轴向下，(0.5, 0.1) 是机体的**正面**，所以所有图标都朝上画，
 *   朝向由游戏另外画的朝向标记表示（图标本身不旋转，保证 22px 下形体清晰）。
 *
 * 【绘制指令】四个基础图元，Canvas 后端和离屏光栅化后端都支持：
 *   {t:'p', pts:[[x,y],...], fill, grad, stroke, lw}   多边形
 *   {t:'e', cx, cy, rx, ry,  fill, grad, stroke, lw}   椭圆
 *   {t:'r', x, y, w, h, r,   fill, grad, stroke, lw}   圆角矩形
 *   {t:'s', a:[x,y], b:[x,y], lw, fill}                粗线段（圆头）
 *   fill 可以是颜色字符串，也可以是 grad（渐变），grad 优先。
 *   grad = {g:[[x0,y0],[x1,y1]], st:[[0,c0],[0.5,c1],[1,c2]]}
 *
 * 【调色板】由游戏按「阵营 / 是否已行动」传入，见 PAL。
 * ========================================================================== */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.MechIcons = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const VERSION = '1.0';

  /* ---------- 调色板 ---------- */

  // 阵营配色：armor 主体装甲 / light 亮面 / dark 暗面 / accent 能量光 / trim 装饰边 / visor 面罩
  const PAL = {
    // 影世界：暗紫 + 奥术辉光
    ying:   {armor:'#5f4f96', light:'#8a6bd8', dark:'#2e2650', accent:'#d9b8ff', trim:'#a98fe0', visor:'#eeddff'},
    // 月球王国：银蓝 + 月光
    moon:   {armor:'#7d92ad', light:'#9fb7d8', dark:'#39475d', accent:'#eaf6ff', trim:'#c2d6ef', visor:'#bfe6ff'},
    // 天人：青绿 + GN 粒子
    cb:     {armor:'#2c7663', light:'#4fc3a1', dark:'#153f35', accent:'#9ff3e0', trim:'#63d6b4', visor:'#b6ffe9'},
    // 敌方：暗红 + 橙黄警示
    enemy:  {armor:'#8c3a32', light:'#d9564b', dark:'#431a15', accent:'#ffcf8a', trim:'#e07a6c', visor:'#ffd8a0'},
    // 已行动：整体去饱和
    acted:  {armor:'#444b56', light:'#6b7480', dark:'#24282f', accent:'#98a2ae', trim:'#79828e', visor:'#a8b2be'},
    // 中立（陨石残骸）
    rock:   {armor:'#5d554e', light:'#8b7f74', dark:'#2f2b27', accent:'#c9b9a8', trim:'#7a6f65', visor:'#c9b9a8'},
    /* v0.17 新势力（Claude 合并时补的占位配色，DSH 在 v0.19 调整了两套）。
     * 底色取自游戏里头像徽章用的 FACTION_COL，保证地图和面板颜色一致。 */
    // 卫星国防军：樱粉 + 白　（色相 335°，和其他六套都拉得开）
    clyne:  {armor:'#a85d80', light:'#e88fb4', dark:'#4f2a3d', accent:'#ffe3f0', trim:'#f2b3cf', visor:'#ffd6ea'},
    // 预防者：金黄 + 白　（色相 42°，唯一大面积暖黄）
    prev:   {armor:'#a8822c', light:'#f2c14e', dark:'#4d3a12', accent:'#fff1c4', trim:'#f7d77f', visor:'#fff0b8'},
    /* ATX：近白钢 + 橙红能量。
     * 原来填的是「银白 #c7cfdc」，和月球王国「银蓝 #9fb7d8」**色相几乎一样、明度也接近**，
     * 35px 下两台机体分不出来。改成：亮面推到近白（#e6eaf0，几乎不带蓝）、装甲压暗到中性钢，
     * 靠**明度差**和月球王国拉开；强调色换成橙红（古铁的红黑印象），
     * 这是全七套里唯一的暖红点缀，识别度最高。 */
    atx:    {armor:'#6e7684', light:'#e9e7e2', dark:'#2b3038', accent:'#ff8a5c', trim:'#c6c3bc', visor:'#ffd9c0'},
    /* 秘银（原「米斯里尔」）：军用深橄榄绿 + 沙色。
     * 原来偏亮偏黄绿（#8fb86b），和天人「亮青绿 #4fc3a1」同属绿色区、又是接近的明度。
     * 整体压暗、去饱和，走军用橄榄的路子；强调色从淡绿换成沙色，避免和身体同色。 */
    mithril:{armor:'#54683a', light:'#7d9a58', dark:'#222d17', accent:'#ffd98a', trim:'#8fa970', visor:'#e6dfa4'},
  };

  // 战斗分类的强调色（图标上用来区分定位的小面积点缀）
  const ROLE_COL = {
    近卫:'#ff9a86', 尖兵:'#ffd766', 辅助:'#cfa8ff', 指挥:'#cfa8ff', 重装:'#8fd0ff',
    狙击:'#ffa8dd', 特种:'#7fe6ff',
    // v0.17：医疗分类已并入辅助（反馈第 15 条）
  };

  /* ---------- 颜色工具 ---------- */

  function hex2rgb(h) {
    h = h.replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    const n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  const clamp255 = v => v < 0 ? 0 : v > 255 ? 255 : Math.round(v);
  function rgb2hex(r, g, b) {
    return '#' + ((clamp255(r) << 16) | (clamp255(g) << 8) | clamp255(b)).toString(16).padStart(6, '0');
  }
  const mix = (a, b, t) => { const x = hex2rgb(a), y = hex2rgb(b);
    return rgb2hex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t); };
  // amt > 0 提亮，amt < 0 压暗
  function shade(hex, amt) {
    const c = hex2rgb(hex);
    const f = v => amt >= 0 ? v + (255 - v) * amt : v * (1 + amt);
    return rgb2hex(f(c[0]), f(c[1]), f(c[2]));
  }

  /* ---------- 绘制指令构造器 ---------- */

  function B() {
    const out = [];
    const M = {
      poly(pts, o) { out.push({t:'p', pts, fill:o && o.fill, grad:o && o.grad, stroke:o && o.stroke, lw:o && o.lw, alpha:o && o.alpha}); return M; },
      ell(cx, cy, rx, ry, o) { out.push({t:'e', cx, cy, rx, ry, fill:o && o.fill, grad:o && o.grad, stroke:o && o.stroke, lw:o && o.lw, alpha:o && o.alpha}); return M; },
      rr(x, y, w, h, r, o) { out.push({t:'r', x, y, w, h, r, fill:o && o.fill, grad:o && o.grad, stroke:o && o.stroke, lw:o && o.lw, alpha:o && o.alpha}); return M; },
      seg(a, b, lw, o) { out.push({t:'s', a, b, lw, fill:o && o.fill, alpha:o && o.alpha}); return M; },
      get list() { return out; },
    };
    return M;
  }

  /* ---------- 几何工具 ---------- */

  // 以 x=0.5 为轴镜像一组点（保持环绕方向）
  const mir = pts => pts.map(p => [1 - p[0], p[1]]).reverse();

  // a→b 之间宽度从 w0 收到 w1 的四边形（用来画刀身、炮管、四肢）
  function quad(a, b, w0, w1) {
    const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1;
    const nx = -dy / L, ny = dx / L;
    return [
      [a[0] + nx * w0, a[1] + ny * w0],
      [b[0] + nx * w1, b[1] + ny * w1],
      [b[0] - nx * w1, b[1] - ny * w1],
      [a[0] - nx * w0, a[1] - ny * w0],
    ];
  }

  // a→b 沿线段的矩形骨架（两端平头）
  function seg2poly(a, b, w) { return quad(a, b, w / 2, w / 2); }

  // 顶点角度起、逆时针的多边形（角度以「正上方」为 0，顺时针为正）
  function ringPts(cx, cy, rx, ry, n, phase) {
    const p = [];
    for (let i = 0; i < n; i++) {
      const a = (phase || 0) + i / n * Math.PI * 2 - Math.PI / 2;
      p.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
    }
    return p;
  }
  const hexPts = (cx, cy, rx, ry, ph) => ringPts(cx, cy, rx, ry, 6, ph);

  // 正多边形（用于炮塔底座等）
  function polyPts(cx, cy, rx, ry, n, ph) { return ringPts(cx, cy, rx, ry, n, ph); }

  /* ---------- 渐变工具 ---------- */

  // 垂直渐变：0 在上，1 在下
  const GY = (c0, c1, mid) => mid
    ? {g:[[0, 0], [0, 1]], st:[[0, c0], [0.5, mid], [1, c1]]}
    : {g:[[0, 0], [0, 1]], st:[[0, c0], [1, c1]]};
  // 沿任意方向
  const GG = (c0, c1, x0, y0, x1, y1) => ({g:[[x0, y0], [x1, y1]], st:[[0, c0], [1, c1]]});

  const STEEL = '#98a4b6', STEEL_HI = '#cdd7e4', STEEL_LO = '#464e5c', GUN = '#2c313b';

  /* ==========================================================================
   *  通用部件
   * ======================================================================== */

  /* SD（超级变形）比例系数：头比写实比例大一圈，四肢更粗。
   * SD 不只是风格问题 —— 大头在缩小之后仍然认得出来，是「小尺寸可读」的关键。
   * 所以这里用**统一系数**放大所有机体的头，而不是逐个图标手调。 */
  const SD_HEAD = 1.45;      // 头部尺寸倍率
  const SD_LIMB = 1.14;      // 四肢粗细倍率

  /* 人型机体核心。
   * o = {bulk:0..1 体重, leg:'biped'|'wide'|'stub'|'none'|'track', skirt:true, pack:0..1}
   * 画完之后各个角色再往上加武器、头部装饰、翅膀等等。
   */
  function core(M, C, o) {
    o = o || {};
    const b = o.bulk == null ? 0.45 : o.bulk;
    const W = 0.132 + 0.046 * b;          // 躯干半宽
    const SW = 0.300 + 0.112 * b;         // 肩部外缘
    const leg = o.leg || 'biped';

    const A = C.armor, AL = C.light, AD = C.dark, AC = C.accent;

    /* 背包 / 推进器（最底层，从肩后探出） */
    if (leg !== 'none') {
      const pw = 0.055 + 0.025 * b;
      for (const s of [1, -1]) {
        const cx = 0.5 + s * (W + 0.045);
        M.poly(quad([cx, 0.44], [cx - s * 0.035, 0.20], pw, pw * 0.75),
          {grad: GY(shade(AD, 0.16), shade(AD, -0.1)), stroke: shade(AD, -0.3), lw: 0.018});
        M.ell(cx - s * 0.035, 0.205, pw * 0.72, pw * 0.5, {fill: AC, alpha: 0.75});
      }
    }

    /* 腿（SD 比例：更短更粗） */
    if (leg === 'biped' || leg === 'wide' || leg === 'stub') {
      const spread = leg === 'wide' ? 0.052 : leg === 'stub' ? 0.028 : 0.030;
      const footY = leg === 'stub' ? 0.80 : 0.876;
      const kneeY = leg === 'stub' ? 0.71 : 0.742;
      const lw = 0.098 * SD_LIMB, fw = 0.108 * SD_LIMB;
      for (const s of [1, -1]) {
        M.poly([[0.5 + s * spread, 0.625], [0.5 + s * (spread + lw), 0.625],
                [0.5 + s * (spread + lw * 0.88), kneeY], [0.5 + s * (spread + 0.014), kneeY]],
          {grad: GY(shade(A, -0.04), shade(AD, 0.12)), stroke: shade(AD, -0.25), lw: 0.018});
        M.poly([[0.5 + s * (spread + 0.012), kneeY], [0.5 + s * (spread + lw * 0.92), kneeY],
                [0.5 + s * (spread + lw * 0.84), footY], [0.5 + s * (spread + 0.004), footY]],
          {grad: GY(shade(A, -0.10), shade(AD, 0.05)), stroke: shade(AD, -0.25), lw: 0.016});
        // 脚
        M.poly([[0.5 + s * (spread - 0.006), footY - 0.012], [0.5 + s * (spread + fw), footY - 0.012],
                [0.5 + s * (spread + fw + 0.010), footY + 0.055], [0.5 + s * (spread - 0.018), footY + 0.055]],
          {grad: GY(shade(AL, -0.18), shade(AD, -0.05)), stroke: shade(AD, -0.35), lw: 0.016});
        // 膝盖亮块
        M.rr(0.5 + s * (spread + 0.020), kneeY - 0.042, 0.062, 0.036, 0.012, {fill: shade(AL, 0.06), alpha: 0.9});
      }
    } else if (leg === 'track') {
      for (const s of [1, -1]) {
        M.rr(0.5 + s * 0.235 - 0.085, 0.60, 0.17, 0.335, 0.075,
          {grad: GY(shade(AD, 0.08), shade(AD, -0.25)), stroke: shade(AD, -0.4), lw: 0.02});
        for (let i = 0; i < 3; i++) {
          M.ell(0.5 + s * 0.235, 0.665 + i * 0.092, 0.052, 0.042, {fill: shade(STEEL_LO, -0.1)});
        }
      }
    }

    /* 髋 / 裙甲 */
    M.poly([[0.5 - 0.104, 0.560], [0.5 + 0.104, 0.560], [0.5 + 0.126, 0.652], [0.5 - 0.126, 0.652]],
      {fill: shade(AD, 0.18), stroke: shade(AD, -0.2), lw: 0.016});
    if (o.skirt !== false) {
      for (const s of [1, -1]) {
        M.poly([[0.5 + s * 0.108, 0.585], [0.5 + s * 0.186, 0.612], [0.5 + s * 0.176, 0.712], [0.5 + s * 0.106, 0.688]],
          {grad: GY(shade(A, -0.06), shade(AD, 0.10)), stroke: shade(AD, -0.25), lw: 0.014});
      }
    }

    /* 手臂（肩到腰，SD 比例：更粗） */
    for (const s of [1, -1]) {
      const ax = 0.5 + s * (W + 0.010);
      M.poly(quad([ax, 0.315], [ax + s * 0.012, 0.520], 0.058 * SD_LIMB, 0.048 * SD_LIMB),
        {grad: GY(shade(A, -0.08), shade(AD, 0.06)), stroke: shade(AD, -0.25), lw: 0.015});
      M.ell(ax + s * 0.012, 0.522, 0.032, 0.030, {fill: shade(AL, -0.25)});
    }

    /* 躯干 */
    M.poly([[0.5 - W * 0.86, 0.298], [0.5 + W * 0.86, 0.298], [0.5 + W, 0.402],
            [0.5 + W * 0.80, 0.578], [0.5 - W * 0.80, 0.578], [0.5 - W, 0.402]],
      {grad: GY(shade(AL, -0.02), shade(AD, 0.14)), stroke: shade(AD, -0.3), lw: 0.02});
    /* 胸甲 */
    M.poly([[0.5 - W * 0.66, 0.320], [0.5 + W * 0.66, 0.320], [0.5 + W * 0.74, 0.452], [0.5 - W * 0.74, 0.452]],
      {grad: GY(shade(AL, 0.16), shade(A, 0.02)), stroke: shade(AD, -0.05), lw: 0.014});
    /* 胸口核心（用「战斗分类」的颜色，是区分定位的主要色彩线索） */
    const KC = C.core || AC;
    M.ell(0.5, 0.428, 0.058, 0.054, {fill: KC, alpha: 0.98});
    M.ell(0.5, 0.428, 0.084, 0.078, {stroke: shade(KC, -0.42), lw: 0.024});
    M.rr(0.5 - W * 0.80, 0.545, W * 1.60, 0.030, 0.012, {fill: shade(AD, 0.30), alpha: 0.9});

    /* 肩甲 */
    for (const s of [1, -1]) {
      const x0 = 0.5 + s * (W * 0.55), x1 = 0.5 + s * SW;
      M.poly([[x0, 0.252], [x1, 0.300], [x1 - s * 0.012, 0.452], [x0 + s * 0.030, 0.472]],
        {grad: GG(shade(AL, 0.10), shade(AD, 0.10), 0.5, 0.25, 0.5 + s * 0.4, 0.5),
         stroke: shade(AD, -0.35), lw: 0.018});
      // 肩部能量线
      M.seg([x0 + s * 0.055, 0.286], [x1 - s * 0.030, 0.322], 0.020, {fill: AC, alpha: 0.85});
    }

    /* 颈 + 头 */
    M.rr(0.5 - 0.042, 0.268, 0.084, 0.048, 0.014, {fill: shade(AD, 0.22)});
    return {W, SW, A, AL, AD, AC};
  }

  /* 头（六棱柱 + 面罩 + 大眼睛），o = {y, rx, ry, crest:bool}
   * rx / ry 会统一乘以 SD_HEAD，所以各处传的比例保持不变，整体一起变大。 */
  function head(M, C, o) {
    o = o || {};
    const cy = o.y == null ? 0.228 : o.y;
    const rx = (o.rx || 0.086) * SD_HEAD, ry = (o.ry || 0.082) * SD_HEAD;
    M.poly(hexPts(0.5, cy, rx, ry, Math.PI / 6),
      {grad: GY(shade(C.light, -0.05), shade(C.armor, -0.05)), stroke: shade(C.dark, -0.3), lw: 0.018});
    // 面罩（正面朝上，所以画在头上半部）
    M.rr(0.5 - rx * 0.80, cy - ry * 0.62, rx * 1.60, ry * 0.50, ry * 0.22,
      {fill: C.visor, alpha: 0.95});
    // 两只发光的眼睛：SD 机体的表情全靠这里，缩小后也是最快认出「这是张脸」的东西
    for (const s of [1, -1]) {
      M.ell(0.5 + s * rx * 0.42, cy - ry * 0.34, rx * 0.24, ry * 0.20,
        {fill: shade(C.visor, 0.55), alpha: 0.95});
    }
    M.rr(0.5 - rx * 0.62, cy - ry * 0.50, rx * 1.24, ry * 0.20, ry * 0.10,
      {fill: shade(C.visor, 0.5), alpha: 0.85});
    if (o.crest) {
      M.poly([[0.5, cy - ry - 0.085], [0.5 + 0.026, cy - ry - 0.004], [0.5 - 0.026, cy - ry - 0.004]],
        {fill: C.accent, alpha: 0.95});
    }
    return {cy, rx, ry};
  }

  /* 手持武器：刀 / 剑 */
  function sword(M, C, a, b, w, glow) {
    M.poly(quad(a, b, w, w * 0.42), {grad: GG(STEEL_HI, STEEL_LO, a[0], a[1], b[0], b[1])});
    M.poly(quad(a, b, w * 0.34, w * 0.16), {fill: glow || C.accent, alpha: 0.9});
    // 尖
    const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy) || 1;
    M.poly([[b[0] + dx / L * w * 1.5, b[1] + dy / L * w * 1.5],
            [b[0] - dy / L * w * 0.5, b[1] + dx / L * w * 0.5],
            [b[0] + dy / L * w * 0.5, b[1] - dx / L * w * 0.5]], {fill: STEEL_HI});
  }

  /* 炮管 */
  function barrel(M, C, a, b, w) {
    M.poly(quad(a, b, w, w * 0.86), {grad: GG(shade(STEEL, 0.25), shade(STEEL_LO, 0.1), a[0], a[1], b[0], b[1]),
      stroke: '#20242c', lw: 0.030});
    // 枪口：只稍微加宽一点，做成环而不是一坨
    M.poly(quad([b[0] - (b[0] - a[0]) * 0.10, b[1] - (b[1] - a[1]) * 0.10], b, w * 1.06, w * 1.02),
      {fill: shade(STEEL_LO, -0.12)});
  }

  /* 能量环（推进器 / 屏障光） */
  function glowRing(M, cx, cy, rx, ry, col, a) {
    M.ell(cx, cy, rx, ry, {stroke: col, lw: 0.026, alpha: a == null ? 0.85 : a});
    M.ell(cx, cy, rx * 0.62, ry * 0.62, {fill: col, alpha: (a == null ? 0.85 : a) * 0.55});
  }

  /* ==========================================================================
   *  我方机体图标（9 + 纳德雷形态）
   * ======================================================================== */

  const BUILD = {};

  /* 雷萨 · B1 — 近卫。单手持长刀高举，刀身带门的紫色辉光。 */
  BUILD.B1 = (M, C, o) => {
    const AC = C.accent;
    const k = core(M, C, {bulk: 0.45, leg: 'biped'});
    head(M, C, {y: 0.232, crest: true});
    // 左肩尖刺
    M.poly([[0.5 - k.W * 0.55, 0.256], [0.5 - k.SW - 0.075, 0.196], [0.5 - k.SW + 0.02, 0.330]],
      {grad: GY(shade(C.light, 0.05), shade(C.dark, 0.1)), stroke: shade(C.dark, -0.35), lw: 0.024});
    // 右手长刀（斜举，够粗才看得见）
    sword(M, C, [0.720, 0.560], [0.892, 0.052], 0.055, AC);
    // 护手
    M.poly([[0.676, 0.556], [0.764, 0.510], [0.792, 0.578], [0.704, 0.624]],
      {fill: shade(C.dark, 0.25), stroke: shade(C.dark, -0.3), lw: 0.022});
    // 左手短刃
    sword(M, C, [0.286, 0.560], [0.170, 0.348], 0.044, AC);
    // 刀光（只在大尺寸画）
    if (o.detail) M.seg([0.770, 0.492], [0.874, 0.116], 0.034, {fill: AC, alpha: 0.40});
  };

  /* 蕾卡 · B2 — 尖兵。低矮宽大的后掠翼飞行框架：剪影是「一架飞机」，
   * 和 B1 的细高剑士完全区分开。 */
  BUILD.B2 = (M, C, o) => {
    const AC = C.accent;
    const KC = C.core || AC;
    // 主翼（大而薄，向侧后方展开，是剪影最主要的特征）
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.076, 0.296], [0.5 + s * 0.458, 0.596], [0.5 + s * 0.432, 0.700], [0.5 + s * 0.084, 0.472]],
        {grad: GG(shade(C.light, 0.18), shade(C.dark, 0.06), 0.5, 0.32, 0.5 + s * 0.46, 0.64),
         stroke: shade(C.dark, -0.45), lw: 0.032});
      // 翼前缘高光
      M.seg([0.5 + s * 0.104, 0.316], [0.5 + s * 0.452, 0.602], 0.028, {fill: AC, alpha: 0.8});
      // 翼尖推进器
      M.poly([[0.5 + s * 0.386, 0.638], [0.5 + s * 0.470, 0.586], [0.5 + s * 0.478, 0.684], [0.5 + s * 0.404, 0.722]],
        {fill: shade(C.dark, 0.28), stroke: shade(C.dark, -0.45), lw: 0.024});
      glowRing(M, 0.5 + s * 0.450, 0.700, 0.070, 0.050, AC, 0.9);
      // 前翼（鸭翼）
      M.poly([[0.5 + s * 0.064, 0.186], [0.5 + s * 0.246, 0.250], [0.5 + s * 0.224, 0.300], [0.5 + s * 0.068, 0.250]],
        {fill: shade(C.light, 0.04), stroke: shade(C.dark, -0.38), lw: 0.024});
    }
    // 机身
    M.poly([[0.5, 0.062], [0.5 + 0.086, 0.238], [0.5 + 0.094, 0.520], [0.5 + 0.076, 0.842],
            [0.5 - 0.076, 0.842], [0.5 - 0.094, 0.520], [0.5 - 0.086, 0.238]],
      {grad: GY(shade(C.light, 0.14), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.45), lw: 0.032});
    // 座舱
    M.ell(0.5, 0.222, 0.048, 0.080, {fill: C.visor, alpha: 0.95});
    // 胸口核心
    M.ell(0.5, 0.452, 0.062, 0.058, {fill: KC, alpha: 0.98});
    M.ell(0.5, 0.452, 0.088, 0.082, {stroke: shade(KC, -0.42), lw: 0.024});
    // 翼根双炮
    barrel(M, C, [0.5 - 0.078, 0.330], [0.5 - 0.118, 0.088], 0.042);
    barrel(M, C, [0.5 + 0.078, 0.330], [0.5 + 0.118, 0.088], 0.042);
    // 收起的起落架 / 腿（保留「这是机体」的读法）
    for (const s of [1, -1]) {
      M.poly(quad([0.5 + s * 0.048, 0.836], [0.5 + s * 0.098, 0.944], 0.052, 0.044),
        {fill: shade(C.armor, -0.10), stroke: shade(C.dark, -0.3), lw: 0.022});
      M.poly([[0.5 + s * 0.046, 0.928], [0.5 + s * 0.152, 0.914], [0.5 + s * 0.164, 0.968], [0.5 + s * 0.038, 0.980]],
        {fill: shade(C.dark, 0.18), stroke: shade(C.dark, -0.35), lw: 0.022});
    }
  };

  /* Feena · M1 — 辅助。长裙 + 头顶光环 + 新月，手持法球，没有武器。 */
  BUILD.M1 = (M, C) => {
    const AC = C.accent;
    // 头顶新月与光环
    M.ell(0.5, 0.150, 0.170, 0.062, {stroke: AC, lw: 0.024, alpha: 0.85});
    M.poly([[0.5, 0.038], [0.575, 0.078], [0.545, 0.092],
            [0.5, 0.104], [0.455, 0.092], [0.425, 0.078]],
      {fill: AC, alpha: 0.95});
    M.ell(0.5, 0.086, 0.150, 0.052, {stroke: AC, lw: 0.014, alpha: 0.45});
    // 裙摆（代替腿）
    M.poly([[0.5 - 0.128, 0.560], [0.5 + 0.128, 0.560], [0.5 + 0.250, 0.918], [0.5 - 0.250, 0.918]],
      {grad: GY(shade(C.light, 0.02), shade(C.dark, 0.10)), stroke: shade(C.dark, -0.3), lw: 0.022});
    // 裙摆纵向褶
    for (const dx of [-0.13, 0, 0.13]) {
      M.poly(quad([0.5 + dx * 0.62, 0.585], [0.5 + dx * 1.55, 0.900], 0.020, 0.030),
        {fill: shade(C.light, 0.22), alpha: 0.55});
    }
    // 躯干与肩
    M.poly([[0.5 - 0.104, 0.300], [0.5 + 0.104, 0.300], [0.5 + 0.132, 0.402],
            [0.5 + 0.126, 0.578], [0.5 - 0.126, 0.578], [0.5 - 0.132, 0.402]],
      {grad: GY(shade(C.light, 0.10), shade(C.armor, 0.04)), stroke: shade(C.dark, -0.25), lw: 0.02});
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.090, 0.276], [0.5 + s * 0.228, 0.312], [0.5 + s * 0.214, 0.420], [0.5 + s * 0.108, 0.418]],
        {grad: GY(shade(C.light, 0.18), shade(C.armor, 0.06)), stroke: shade(C.dark, -0.3), lw: 0.018});
      // 手臂
      M.poly(quad([0.5 + s * 0.150, 0.400], [0.5 + s * 0.196, 0.560], 0.040, 0.034),
        {fill: shade(C.armor, 0.02), stroke: shade(C.dark, -0.2), lw: 0.014});
      // 袖口
      M.poly(quad([0.5 + s * 0.176, 0.520], [0.5 + s * 0.212, 0.620], 0.052, 0.062),
        {fill: shade(C.light, 0.06), alpha: 0.9});
    }
    head(M, C, {y: 0.242, rx: 0.082, ry: 0.080});
    // 法球
    M.ell(0.790, 0.660, 0.062, 0.062, {fill: AC, alpha: 0.8});
    M.ell(0.790, 0.660, 0.092, 0.092, {stroke: AC, lw: 0.016, alpha: 0.5});
    // 胸口月纹
    M.poly([[0.5, 0.372], [0.548, 0.408], [0.528, 0.412], [0.5, 0.418], [0.472, 0.412], [0.452, 0.408]],
      {fill: AC, alpha: 0.9});
  };

  /* 阿布拉德 · M2 — 重装（2×2）。极宽肩甲、右臂巨大打桩机、左侧塔盾。 */
  BUILD.M2 = (M, C) => {
    const AC = C.accent;
    const k = core(M, C, {bulk: 1.0, leg: 'wide'});
    // 超宽肩甲
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.150, 0.218], [0.5 + s * 0.452, 0.276],
              [0.5 + s * 0.436, 0.492], [0.5 + s * 0.166, 0.500]],
        {grad: GG(shade(C.light, 0.14), shade(C.dark, 0.10), 0.5, 0.24, 0.5 + s * 0.44, 0.50),
         stroke: shade(C.dark, -0.35), lw: 0.022});
      // 肩甲分层与铆钉
      M.poly([[0.5 + s * 0.196, 0.252], [0.5 + s * 0.420, 0.300], [0.5 + s * 0.412, 0.352], [0.5 + s * 0.190, 0.310]],
        {fill: shade(C.light, 0.04), alpha: 0.65});
      for (const t of [0.30, 0.56, 0.82]) {
        M.ell(0.5 + s * (0.190 + (0.436 - 0.190) * t), 0.330 + t * 0.120, 0.017, 0.017, {fill: shade(STEEL_HI, -0.1)});
      }
    }
    head(M, C, {y: 0.246, rx: 0.070, ry: 0.066});
    // 右臂打桩机（亮面 + 三段钻头，远远就能认出「重装」）
    M.poly(quad([0.752, 0.448], [0.844, 0.752], 0.122, 0.136),
      {grad: GY(shade(C.armor, 0.22), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.42), lw: 0.030});
    M.rr(0.752, 0.752, 0.122, 0.082, 0.026, {fill: shade(STEEL_HI, -0.12), stroke: '#20242c', lw: 0.022});
    for (let i = 0; i < 3; i++) {
      M.poly([[0.756, 0.830 + i * 0.042], [0.870, 0.830 + i * 0.042], [0.813, 0.886 + i * 0.042]],
        {fill: i % 2 ? shade(STEEL_HI, -0.04) : shade(STEEL_HI, 0.20), stroke: '#20242c', lw: 0.018});
    }
    // 左臂塔盾（亮面 + 粗边）
    M.poly([[0.102, 0.378], [0.268, 0.334], [0.302, 0.762], [0.112, 0.812]],
      {grad: GG(shade(C.light, 0.24), shade(C.dark, 0.14), 0.10, 0.38, 0.30, 0.78),
       stroke: shade(C.dark, -0.46), lw: 0.032});
    M.poly([[0.146, 0.420], [0.252, 0.392], [0.270, 0.514], [0.162, 0.540]], {fill: AC, alpha: 0.55});
    M.seg([0.124, 0.466], [0.290, 0.428], 0.026, {fill: shade(C.light, 0.34), alpha: 0.75});
  };

  /* Iris · M3 — 医疗（飞行）。主体是一块白色医疗舱，上面一个大绿十字，
   * 22px 下也能一眼读出「医疗」。 */
  BUILD.M3 = (M, C, o) => {
    const AC = C.accent, HEAL = '#7de89a', WHITE = '#e6f1ef';
    // 悬浮喷口（在机体下面）
    for (const s of [1, -1]) {
      M.rr(0.5 + s * 0.152 - 0.072, 0.724, 0.144, 0.108, 0.038,
        {grad: GY(shade(STEEL_LO, 0.36), shade(STEEL_LO, -0.06)), stroke: shade(C.dark, -0.32), lw: 0.024});
      glowRing(M, 0.5 + s * 0.152, 0.846, 0.086, 0.044, AC, 0.9);
    }
    // 侧翼
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.110, 0.280], [0.5 + s * 0.372, 0.342], [0.5 + s * 0.354, 0.420], [0.5 + s * 0.114, 0.396]],
        {grad: GY(shade(C.light, 0.20), shade(C.dark, 0.08)), stroke: shade(C.dark, -0.38), lw: 0.028});
      glowRing(M, 0.5 + s * 0.354, 0.382, 0.062, 0.038, AC, 0.9);
    }
    // 主体医疗舱（偏白，医疗单位的识别色）
    M.poly([[0.5 - 0.176, 0.316], [0.5 + 0.176, 0.316], [0.5 + 0.196, 0.552], [0.5 + 0.156, 0.766],
            [0.5 - 0.156, 0.766], [0.5 - 0.196, 0.552]],
      {grad: GY(shade(WHITE, -0.02), shade(C.armor, 0.10)), stroke: shade(C.dark, -0.45), lw: 0.032});
    // 大十字
    M.rr(0.5 - 0.046, 0.368, 0.092, 0.340, 0.026, {fill: HEAL, stroke: '#1d5a39', lw: 0.024});
    M.rr(0.5 - 0.172, 0.484, 0.344, 0.092, 0.026, {fill: HEAL, stroke: '#1d5a39', lw: 0.024});
    // 头
    head(M, C, {y: 0.250, rx: 0.084, ry: 0.078});
    // 修理臂
    M.poly(quad([0.360, 0.420], [0.272, 0.680], 0.066, 0.076), {fill: shade(C.armor, 0.04), stroke: shade(C.dark, -0.32), lw: 0.026});
    // 防身机枪
    barrel(M, C, [0.644, 0.428], [0.744, 0.284], 0.040);
  };

  /* 刹那 · CB1 — 近卫。V 字天线、背后双 GN 剑、双肩 GN 锥。 */
  BUILD.CB1 = (M, C) => {
    const AC = C.accent;
    // 背后展开的双剑（X 形）
    M.poly(quad([0.300, 0.640], [0.086, 0.190], 0.044, 0.020), {grad: GG(STEEL, STEEL_HI, 0.3, 0.6, 0.1, 0.2)});
    M.poly(quad([0.700, 0.640], [0.914, 0.190], 0.044, 0.020), {grad: GG(STEEL, STEEL_HI, 0.7, 0.6, 0.9, 0.2)});
    M.seg([0.300, 0.640], [0.086, 0.190], 0.016, {fill: AC, alpha: 0.75});
    M.seg([0.700, 0.640], [0.914, 0.190], 0.016, {fill: AC, alpha: 0.75});
    const k = core(M, C, {bulk: 0.50, leg: 'biped'});
    head(M, C, {y: 0.236, rx: 0.084, ry: 0.082});
    // V 字天线
    M.poly([[0.5, 0.104], [0.560, 0.186], [0.530, 0.196], [0.5, 0.150]], {fill: AC, alpha: 0.95});
    M.poly([[0.5, 0.104], [0.440, 0.186], [0.470, 0.196], [0.5, 0.150]], {fill: AC, alpha: 0.95});
    M.seg([0.5, 0.100], [0.500, 0.156], 0.022, {fill: shade(AC, -0.15)});
    // 双肩 GN 锥
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * k.W * 0.62, 0.256], [0.5 + s * (k.SW + 0.052), 0.196],
              [0.5 + s * (k.SW + 0.020), 0.336]],
        {grad: GY(shade(C.light, 0.18), shade(C.dark, 0.10)), stroke: shade(C.dark, -0.35), lw: 0.018});
      M.seg([0.5 + s * (k.SW + 0.040), 0.216], [0.5 + s * (k.W * 0.72 + 0.045), 0.300], 0.014, {fill: AC, alpha: 0.8});
    }
    // 右手 GN 剑（剑模式，斜举）
    sword(M, C, [0.712, 0.556], [0.872, 0.104], 0.040, AC);
    // 左手长短刃
    sword(M, C, [0.288, 0.560], [0.170, 0.398], 0.032, AC);
    // 裙甲侧展
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.150, 0.590], [0.5 + s * 0.246, 0.626], [0.5 + s * 0.240, 0.742], [0.5 + s * 0.146, 0.706]],
        {fill: shade(C.armor, 0.08), stroke: shade(C.dark, -0.25), lw: 0.016});
    }
  };

  /* 洛克昂 · CB2 — 狙击。超长狙击枪斜贯整个图标，剪影就是一条对角线，
   * 机体缩到中间偏小，把画面让给枪。 */
  BUILD.CB2 = (M, C, o) => {
    const AC = C.accent;
    const KC = C.core || AC;
    // 机体（蹲姿、小一号）
    const k = core(M, C, {bulk: 0.10, leg: 'stub', skirt: false});
    head(M, C, {y: 0.296, rx: 0.074, ry: 0.070});
    // 肩甲
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * k.W * 0.60, 0.352], [0.5 + s * (k.SW - 0.010), 0.396],
              [0.5 + s * (k.SW - 0.034), 0.500], [0.5 + s * k.W * 0.74, 0.488]],
        {grad: GY(shade(C.light, 0.12), shade(C.armor, 0.02)), stroke: shade(C.dark, -0.38), lw: 0.026});
    }
    // 胸口核心
    M.ell(0.5, 0.446, 0.056, 0.052, {fill: KC, alpha: 0.98});
    // 狙击枪：贯穿全格的对角线
    const A = [0.112, 0.912], B = [0.928, 0.120];
    const dx = B[0] - A[0], dy = B[1] - A[1], L = Math.hypot(dx, dy);
    const ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
    barrel(M, C, A, B, 0.060);
    // 瞄准镜（沿枪身中段、偏向一侧）
    const mid = [A[0] + dx * 0.42, A[1] + dy * 0.42];
    const off = 0.062;
    const s1 = [mid[0] - ux * 0.095 + nx * off, mid[1] - uy * 0.095 + ny * off];
    const s2 = [mid[0] + ux * 0.095 + nx * off, mid[1] + uy * 0.095 + ny * off];
    barrel(M, C, s1, s2, 0.058);
    M.ell(s2[0] + ux * 0.02, s2[1] + uy * 0.02, 0.030, 0.030, {fill: AC, alpha: 0.95});
    // 弹匣
    M.poly(quad([A[0] + dx * 0.52, A[1] + dy * 0.52], [A[0] + dx * 0.60, A[1] + dy * 0.60], 0.052, 0.052),
      {fill: shade(C.dark, 0.30), stroke: '#20242c', lw: 0.020});
    // 两脚架
    M.poly(quad([A[0] + dx * 0.26, A[1] + dy * 0.26], [0.286, 0.930], 0.026, 0.020), {fill: shade(STEEL_LO, 0.18)});
    M.poly(quad([A[0] + dx * 0.32, A[1] + dy * 0.32], [0.652, 0.930], 0.026, 0.020), {fill: shade(STEEL_LO, 0.18)});
  };

  /* 阿雷路亚 · CB3 — 特种。宽箭头机身 + 正面冲撞板 + 折起的后掠翼。 */
  BUILD.CB3 = (M, C) => {
    const AC = C.accent;
    // 折起后掠翼（向后上方）
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.110, 0.330], [0.5 + s * 0.430, 0.232], [0.5 + s * 0.470, 0.312], [0.5 + s * 0.128, 0.424]],
        {grad: GG(shade(C.light, 0.14), shade(C.dark, 0.10), 0.5, 0.30, 0.5 + s * 0.46, 0.34),
         stroke: shade(C.dark, -0.3), lw: 0.018});
      M.seg([0.5 + s * 0.150, 0.402], [0.5 + s * 0.430, 0.272], 0.014, {fill: AC, alpha: 0.75});
    }
    core(M, C, {bulk: 0.34, leg: 'stub', skirt: false});
    // 正面冲撞板（GN 冲撞）
    M.poly([[0.5 - 0.232, 0.268], [0.5 + 0.232, 0.268], [0.5 + 0.180, 0.148], [0.5 - 0.180, 0.148]],
      {grad: GY(shade(C.light, 0.22), shade(C.armor, 0.06)), stroke: shade(C.dark, -0.35), lw: 0.022});
    M.poly([[0.5 - 0.150, 0.246], [0.5 + 0.150, 0.246], [0.5 + 0.110, 0.176], [0.5 - 0.110, 0.176]],
      {fill: AC, alpha: 0.55});
    head(M, C, {y: 0.108, rx: 0.062, ry: 0.052});
    // 双肩冲锋枪
    barrel(M, C, [0.700, 0.470], [0.760, 0.300], 0.036);
    barrel(M, C, [0.300, 0.470], [0.240, 0.300], 0.036);
  };

  /* 提耶利亚 · CB4 — 特种（德天使）。圆胖重装 + 右肩巨型火箭筒 + 底部 GN 推进锥。
   * 刻意左右不对称，避免和对称的人型机体混在一起。 */
  BUILD.CB4 = (M, C, o) => {
    const AC = C.accent, KC = C.core || AC;
    // 下方 GN 推进锥
    for (const s of [1, -1]) {
      M.poly(quad([0.5 + s * 0.168, 0.630], [0.5 + s * 0.212, 0.884], 0.124, 0.102),
        {grad: GY(shade(C.dark, 0.28), shade(C.dark, -0.14)), stroke: shade(C.dark, -0.42), lw: 0.028});
      glowRing(M, 0.5 + s * 0.220, 0.888, 0.086, 0.042, AC, 0.85);
    }
    // 粗腿
    for (const s of [1, -1]) {
      M.poly(quad([0.5 + s * 0.102, 0.626], [0.5 + s * 0.138, 0.846], 0.152, 0.132),
        {grad: GY(shade(C.armor, 0.06), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.38), lw: 0.028});
    }
    // 右侧巨型火箭筒（长而粗）
    M.rr(0.5 + 0.104, 0.108, 0.196, 0.152, 0.042,
      {fill: shade(C.armor, 0.14), stroke: shade(C.dark, -0.42), lw: 0.028});
    barrel(M, C, [0.5 + 0.204, 0.144], [0.5 + 0.222, 0.022], 0.086);
    // 左侧宽大盾形肩甲
    M.poly([[0.5 - 0.092, 0.326], [0.5 - 0.332, 0.266], [0.5 - 0.354, 0.470], [0.5 - 0.106, 0.502]],
      {grad: GG(shade(C.light, 0.18), shade(C.dark, 0.10), 0.5, 0.28, 0.5 - 0.35, 0.48),
       stroke: shade(C.dark, -0.44), lw: 0.032});
    M.seg([0.5 - 0.150, 0.320], [0.5 - 0.338, 0.290], 0.026, {fill: AC, alpha: 0.75});
    // 圆胖躯干
    M.ell(0.5, 0.472, 0.258, 0.212, {grad: GY(shade(C.light, 0.12), shade(C.dark, 0.18)),
      stroke: shade(C.dark, -0.46), lw: 0.034});
    M.ell(0.5, 0.458, 0.170, 0.142, {fill: shade(C.light, 0.22), alpha: 0.55});
    // 胸口核心
    M.ell(0.5, 0.478, 0.070, 0.066, {fill: KC, alpha: 0.98});
    M.ell(0.5, 0.478, 0.100, 0.094, {stroke: shade(KC, -0.42), lw: 0.028});
    // 头
    head(M, C, {y: 0.298, rx: 0.070, ry: 0.066});
  };

  /* 纳德雷形态 — 细身机体 + 从头部向两侧下方展开的**宽扇形长发缆线**，
   * 变身之后剪影和德天使（圆胖）完全相反，一眼就能看出换了形态。 */
  BUILD.CB4N = (M, C, o) => {
    const AC = C.accent, KC = C.core || AC;
    // 长发状缆线（纳德雷最标志性的剪影）
    const strands = [
      [0.418, 0.058, 0.996, 0.048],
      [0.452, 0.178, 0.968, 0.044],
      [0.482, 0.288, 0.926, 0.040],
      [0.518, 0.712, 0.926, 0.040],
      [0.548, 0.822, 0.968, 0.044],
      [0.582, 0.942, 0.996, 0.048],
    ];
    for (const [x0, x1, y1, w] of strands) {
      M.poly(quad([x0, 0.272], [x1, y1], w, w * 0.34),
        {grad: GY(shade(C.light, 0.14), shade(C.dark, 0.24)), stroke: shade(C.dark, -0.38), lw: 0.022});
    }
    // 细身机体
    core(M, C, {bulk: 0.16, leg: 'biped', skirt: false});
    head(M, C, {y: 0.238, rx: 0.084, ry: 0.084});
    // 头顶长天线
    M.seg([0.5, 0.156], [0.5, 0.042], 0.024, {fill: AC, alpha: 0.9});
    // 右手高举的光束剑（光刃很亮，和 CB1 的实体剑区分）
    M.poly(quad([0.704, 0.564], [0.846, 0.262], 0.046, 0.038),
      {fill: shade(C.dark, 0.22), stroke: shade(C.dark, -0.35), lw: 0.022});
    M.seg([0.846, 0.262], [0.902, 0.100], 0.048, {fill: shade(AC, 0.55), alpha: 0.95});
    M.seg([0.846, 0.262], [0.902, 0.100], 0.024, {fill: '#ffffff', alpha: 0.8});
    // 左手光束手枪
    barrel(M, C, [0.292, 0.494], [0.194, 0.406], 0.040);
  };

  /* ==========================================================================
   *  敌方机体图标（12）
   * ======================================================================== */

  /* 量产机 — 通用步兵：方头单眼、左肩尖刺、斜持突击步枪。 */
  BUILD.grunt = (M, C) => {
    const AC = C.accent;
    const k = core(M, C, {bulk: 0.52, leg: 'biped'});
    // 方头 + 单眼
    M.rr(0.5 - 0.092, 0.138, 0.184, 0.170, 0.030,
      {grad: GY(shade(C.light, -0.06), shade(C.armor, -0.06)), stroke: shade(C.dark, -0.3), lw: 0.02});
    M.rr(0.5 - 0.078, 0.176, 0.156, 0.048, 0.020, {fill: C.visor, alpha: 0.95});
    M.ell(0.5, 0.200, 0.026, 0.026, {fill: AC});
    // 左肩尖刺
    M.poly([[0.5 - k.W * 0.58, 0.260], [0.5 - k.SW - 0.086, 0.176], [0.5 - k.SW + 0.012, 0.336]],
      {grad: GY(shade(C.light, 0.08), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.35), lw: 0.02});
    // 右肩装甲块
    M.poly([[0.5 + k.W * 0.56, 0.256], [0.5 + k.SW - 0.010, 0.300], [0.5 + k.SW - 0.026, 0.446], [0.5 + k.W * 0.70, 0.468]],
      {grad: GY(shade(C.light, 0.04), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.35), lw: 0.02});
    // 突击步枪（斜持）
    barrel(M, C, [0.286, 0.660], [0.752, 0.288], 0.042);
    M.rr(0.474, 0.470, 0.086, 0.100, 0.024, {fill: shade(C.dark, 0.28), stroke: '#20242c', lw: 0.014});
    M.ell(0.316, 0.628, 0.046, 0.042, {fill: shade(C.light, -0.16)});
  };

  /* 猎犬 — 四足步行机：四条腿分居四角（俯视下的四足读法）+ 前伸犬首 + 背上猎枪。 */
  BUILD.hound = (M, C, o) => {
    const AC = C.accent;
    // 四条腿：前两条朝上前方，后两条朝下后方，四角各一条
    for (const [x0, y0, x1, y1] of [[0.336, 0.430, 0.098, 0.282], [0.664, 0.430, 0.902, 0.282],
                                    [0.336, 0.668, 0.116, 0.914], [0.664, 0.668, 0.884, 0.914]]) {
      M.poly(quad([x0, y0], [x1, y1], 0.064, 0.046),
        {fill: shade(C.dark, 0.24), stroke: shade(C.dark, -0.40), lw: 0.024});
      M.ell(x1, y1, 0.054, 0.040, {fill: shade(C.armor, -0.06), stroke: shade(C.dark, -0.32), lw: 0.018});
    }
    // 机体（扁长的六边形躯干）
    M.poly([[0.5 - 0.204, 0.436], [0.5 + 0.204, 0.436], [0.5 + 0.246, 0.562],
            [0.5 + 0.192, 0.690], [0.5 - 0.192, 0.690], [0.5 - 0.246, 0.562]],
      {grad: GY(shade(C.light, -0.02), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.44), lw: 0.030});
    // 前伸的犬首
    M.poly([[0.5 - 0.102, 0.412], [0.5 + 0.102, 0.412], [0.5 + 0.070, 0.226], [0.5 - 0.070, 0.226]],
      {grad: GY(shade(C.light, 0.14), shade(C.armor, -0.04)), stroke: shade(C.dark, -0.44), lw: 0.028});
    M.poly(quad([0.5, 0.240], [0.5, 0.130], 0.104, 0.084),
      {fill: shade(C.armor, -0.16), stroke: shade(C.dark, -0.40), lw: 0.024});
    M.rr(0.5 - 0.082, 0.274, 0.164, 0.050, 0.020, {fill: C.visor, alpha: 0.95});
    // 背上猎枪（偏右，避免和前伸的头叠在一起）
    barrel(M, C, [0.660, 0.478], [0.716, 0.158], 0.054);
    M.ell(0.702, 0.212, 0.036, 0.030, {fill: AC, alpha: 0.9});
    if (o.detail) for (const s of [1, -1]) {
      M.seg([0.5 + s * 0.068, 0.480], [0.5 + s * 0.116, 0.656], 0.022, {fill: AC, alpha: 0.55});
    }
  };

  /* 无人机 — 四旋翼：X 形机架、四个转子舱、中央单眼。 */
  BUILD.drone = (M, C) => {
    const AC = C.accent;
    for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) {
      const ex = 0.5 + sx * 0.336, ey = 0.5 + sy * 0.336;
      M.poly(quad([0.5 + sx * 0.09, 0.5 + sy * 0.09], [ex, ey], 0.056, 0.048),
        {fill: shade(C.dark, 0.22), stroke: shade(C.dark, -0.3), lw: 0.016});
      // 转子舱
      M.ell(ex, ey, 0.098, 0.094, {grad: GY(shade(C.armor, 0.10), shade(C.dark, 0.06)),
        stroke: shade(C.dark, -0.35), lw: 0.018});
      // 旋翼环
      M.ell(ex, ey, 0.072, 0.068, {stroke: AC, lw: 0.018, alpha: 0.8});
      M.ell(ex, ey, 0.040, 0.038, {fill: shade(C.light, -0.20)});
    }
    // 中央机体
    M.ell(0.5, 0.5, 0.150, 0.142, {grad: GY(shade(C.light, 0.02), shade(C.dark, 0.14)),
      stroke: shade(C.dark, -0.38), lw: 0.022});
    M.ell(0.5, 0.5, 0.096, 0.090, {fill: shade(C.dark, 0.10)});
    // 单眼
    M.ell(0.5, 0.462, 0.048, 0.044, {fill: C.visor, alpha: 0.95});
    M.ell(0.5, 0.462, 0.024, 0.022, {fill: AC});
    M.seg([0.5, 0.404], [0.5, 0.268], 0.016, {fill: AC, alpha: 0.6});
  };

  /* 铁壁 — 占满整格的一堵墙：平顶、通宽、纵向装甲柱 + 正面箭头，没有头也没有腿。
   * 和「盾卫」（有头有腿、举盾）刻意拉开差别。 */
  BUILD.ironwall = (M, C, o) => {
    const AC = C.accent;
    // 基座
    M.rr(0.066, 0.772, 0.868, 0.146, 0.040,
      {grad: GY(shade(STEEL_LO, 0.18), shade(STEEL_LO, -0.20)), stroke: '#1d2027', lw: 0.028});
    // 主装甲板（占满整格宽度）
    M.poly([[0.028, 0.764], [0.972, 0.764], [0.972, 0.146], [0.902, 0.072],
            [0.098, 0.072], [0.028, 0.146]],
      {grad: GY(shade(C.light, -0.02), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.48), lw: 0.034});
    // 两侧纵向装甲柱
    for (const x of [0.132, 0.868]) {
      M.rr(x - 0.040, 0.126, 0.080, 0.600, 0.022,
        {fill: shade(C.armor, 0.12), alpha: 0.9, stroke: shade(C.dark, -0.26), lw: 0.018});
    }
    // 中间的横向装甲带
    M.rr(0.170, 0.574, 0.660, 0.084, 0.020, {fill: shade(C.armor, 0.06), alpha: 0.85, stroke: shade(C.dark, -0.24), lw: 0.016});
    // 正面装甲箭头（说明只减正面伤害）
    M.poly([[0.5 - 0.166, 0.372], [0.5, 0.208], [0.5 + 0.166, 0.372], [0.5 + 0.166, 0.462],
            [0.5, 0.298], [0.5 - 0.166, 0.462]], {fill: AC, alpha: 0.55});
    // 观察缝
    M.rr(0.5 - 0.108, 0.104, 0.216, 0.036, 0.014, {fill: C.visor, alpha: 0.92});
    if (o.detail) {
      for (const x of [0.072, 0.928]) for (const t of [0.24, 0.52, 0.80]) {
        M.ell(x, 0.160 + t * 0.560, 0.022, 0.022, {fill: shade(STEEL_HI, -0.18)});
      }
    }
  };

  /* 突击兵 — 细长机体 + 前刺长枪 + 后掠头鳍。 */
  BUILD.raider = (M, C) => {
    const AC = C.accent;
    const k = core(M, C, {bulk: 0.12, leg: 'biped', skirt: false});
    // 长枪
    M.poly(quad([0.238, 0.712], [0.902, 0.126], 0.040, 0.016), {grad: GG(STEEL_LO, STEEL_HI, 0.24, 0.71, 0.90, 0.13)});
    M.seg([0.238, 0.712], [0.902, 0.126], 0.014, {fill: AC, alpha: 0.8});
    M.poly([[0.660, 0.336], [0.760, 0.300], [0.700, 0.404]], {fill: AC, alpha: 0.7});
    // 头 + 后掠鳍
    head(M, C, {y: 0.240, rx: 0.074, ry: 0.072});
    M.poly([[0.5 - 0.062, 0.196], [0.5 - 0.190, 0.062], [0.5 - 0.098, 0.176], [0.5 - 0.030, 0.196]],
      {fill: shade(C.light, 0.04), stroke: shade(C.dark, -0.3), lw: 0.016});
    M.poly([[0.5 + 0.062, 0.196], [0.5 + 0.190, 0.062], [0.5 + 0.098, 0.176], [0.5 + 0.030, 0.196]],
      {fill: shade(C.light, 0.04), stroke: shade(C.dark, -0.3), lw: 0.016});
    // 肩部小翼
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * k.W * 0.60, 0.268], [0.5 + s * (k.SW + 0.030), 0.318], [0.5 + s * (k.SW - 0.010), 0.404], [0.5 + s * k.W * 0.74, 0.430]],
        {fill: shade(C.armor, 0.06), stroke: shade(C.dark, -0.3), lw: 0.018});
    }
  };

  /* 固定炮台 — 三脚架 + 上仰迫击炮，没有腿。 */
  BUILD.turret = (M, C) => {
    const AC = C.accent;
    // 三脚架
    for (const [x1, y1] of [[0.148, 0.912], [0.852, 0.912], [0.5, 0.936]]) {
      M.poly(quad([0.5, 0.628], [x1, y1], 0.058, 0.042), {fill: shade(STEEL_LO, 0.14), stroke: '#1d2027', lw: 0.018});
      M.ell(x1, y1, 0.052, 0.032, {fill: shade(STEEL_LO, -0.06)});
    }
    // 底座
    M.ell(0.5, 0.620, 0.222, 0.116, {grad: GY(shade(C.armor, 0.12), shade(C.dark, 0.08)),
      stroke: shade(C.dark, -0.4), lw: 0.024});
    M.ell(0.5, 0.596, 0.132, 0.070, {fill: shade(C.dark, 0.22)});
    // 炮座
    M.rr(0.5 - 0.170, 0.398, 0.340, 0.202, 0.040,
      {grad: GY(shade(C.light, 0.02), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.4), lw: 0.024});
    M.rr(0.5 - 0.086, 0.352, 0.172, 0.046, 0.018, {fill: C.visor, alpha: 0.9});
    // 上仰的迫击炮管
    barrel(M, C, [0.474, 0.470], [0.398, 0.080], 0.070);
    glowRing(M, 0.400, 0.092, 0.062, 0.040, AC, 0.6);
    // 弹药箱
    M.rr(0.5 + 0.196, 0.508, 0.156, 0.150, 0.030, {fill: shade(C.dark, 0.30), stroke: '#20242c', lw: 0.018});
    M.seg([0.5 + 0.216, 0.556], [0.5 + 0.332, 0.556], 0.018, {fill: AC, alpha: 0.6});
  };

  /* 盾卫 — 举塔盾的步兵：头盔露在盾上方、双腿露在盾下方，所以和「铁壁」不会混。 */
  BUILD.shield = (M, C, o) => {
    const AC = C.accent;
    // 腿
    for (const s of [1, -1]) {
      M.poly(quad([0.5 + s * 0.074, 0.596], [0.5 + s * 0.110, 0.908], 0.096, 0.084),
        {fill: shade(C.armor, -0.14), stroke: shade(C.dark, -0.30), lw: 0.024});
      M.poly([[0.5 + s * 0.026, 0.884], [0.5 + s * 0.190, 0.884], [0.5 + s * 0.206, 0.952], [0.5 + s * 0.014, 0.952]],
        {fill: shade(C.dark, 0.18), stroke: shade(C.dark, -0.36), lw: 0.024});
    }
    // 躯干
    M.poly([[0.5 - 0.126, 0.286], [0.5 + 0.126, 0.286], [0.5 + 0.144, 0.620], [0.5 - 0.144, 0.620]],
      {grad: GY(shade(C.light, -0.08), shade(C.dark, 0.14)), stroke: shade(C.dark, -0.40), lw: 0.028});
    // 头盔（露在盾牌上方）
    head(M, C, {y: 0.198, rx: 0.088, ry: 0.084});
    // 塔盾（遮住躯干，但上下都露出一点机体）
    M.poly([[0.5 - 0.278, 0.700], [0.5 + 0.278, 0.700], [0.5 + 0.294, 0.352], [0.5 + 0.208, 0.276],
            [0.5 - 0.208, 0.276], [0.5 - 0.294, 0.352]],
      {grad: GY(shade(C.light, 0.08), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.48), lw: 0.036});
    // 盾面纵向棱
    M.poly([[0.5 - 0.058, 0.300], [0.5 + 0.058, 0.300], [0.5 + 0.058, 0.676], [0.5 - 0.058, 0.676]],
      {fill: shade(C.armor, 0.12), alpha: 0.75, stroke: shade(C.dark, -0.22), lw: 0.016});
    // 盾徽
    M.poly([[0.5, 0.380], [0.5 + 0.098, 0.462], [0.5, 0.544], [0.5 - 0.098, 0.462]], {fill: AC, alpha: 0.62});
    M.ell(0.5, 0.462, 0.034, 0.034, {fill: shade(C.dark, 0.36)});
    if (o.detail) {
      for (const t of [0.24, 0.50, 0.76]) {
        M.ell(0.5 - 0.262, 0.336 + t * 0.328, 0.019, 0.019, {fill: shade(STEEL_HI, -0.20)});
        M.ell(0.5 + 0.262, 0.336 + t * 0.328, 0.019, 0.019, {fill: shade(STEEL_HI, -0.20)});
      }
    }
    // 顶视观察口
    M.rr(0.5 - 0.068, 0.298, 0.136, 0.028, 0.010, {fill: C.visor, alpha: 0.85});
  };

  /* 追击炮车 — 履带自行火炮：车体明显比高炮台扁宽，两条履带 + 前倾长炮管，
   * 剪影是「一辆车」，和「固定炮台」的三脚架区分开。 */
  BUILD.pursuer = (M, C, o) => {
    const AC = C.accent;
    // 履带（左右各一条，带负重轮）
    for (const s of [1, -1]) {
      const cx = 0.5 + s * 0.318;
      M.rr(cx - 0.112, 0.286, 0.224, 0.664, 0.100,
        {grad: GY(shade(STEEL_LO, 0.04), shade(STEEL_LO, -0.30)), stroke: '#14171c', lw: 0.030});
      for (let i = 0; i < 5; i++) {
        M.ell(cx, 0.352 + i * 0.140, 0.062, 0.052, {fill: shade(STEEL_LO, 0.12)});
        M.ell(cx, 0.352 + i * 0.140, 0.026, 0.022, {fill: shade(STEEL_LO, -0.24)});
      }
    }
    // 车体（扁而宽）
    M.poly([[0.5 - 0.216, 0.276], [0.5 + 0.216, 0.276], [0.5 + 0.230, 0.560],
            [0.5 + 0.202, 0.876], [0.5 - 0.202, 0.876], [0.5 - 0.230, 0.560]],
      {grad: GY(shade(C.light, -0.02), shade(C.dark, 0.16)), stroke: shade(C.dark, -0.44), lw: 0.030});
    // 前部斜面装甲
    M.poly([[0.5 - 0.216, 0.276], [0.5 + 0.216, 0.276], [0.5 + 0.170, 0.196], [0.5 - 0.170, 0.196]],
      {fill: shade(C.light, 0.10), stroke: shade(C.dark, -0.36), lw: 0.026});
    // 炮管：向前上方倾斜，末端有大型炮口制退器
    const A = [0.5 - 0.030, 0.330], B = [0.5 + 0.096, 0.052];
    barrel(M, C, A, B, 0.076);
    M.rr(B[0] - 0.086, B[1] - 0.030, 0.172, 0.074, 0.022, {fill: shade(STEEL_LO, 0.16), stroke: '#20242c', lw: 0.020});
    // 观察窗
    M.rr(0.5 - 0.120, 0.212, 0.240, 0.042, 0.016, {fill: C.visor, alpha: 0.92});
    // 排气
    glowRing(M, 0.5 + 0.150, 0.860, 0.090, 0.032, AC, 0.6);
    // 警示条
    M.seg([0.5 - 0.150, 0.812], [0.5 + 0.060, 0.812], 0.030, {fill: AC, alpha: 0.55});
  };

  /* 战斗机 — 俯视飞机：尖机首、后掠主翼、双垂尾、尾部喷焰。 */
  BUILD.fighter = (M, C) => {
    const AC = C.accent;
    // 主翼
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.062, 0.320], [0.5 + s * 0.452, 0.646], [0.5 + s * 0.430, 0.742], [0.5 + s * 0.070, 0.598]],
        {grad: GG(shade(C.light, 0.08), shade(C.dark, 0.10), 0.5, 0.45, 0.5 + s * 0.44, 0.70),
         stroke: shade(C.dark, -0.3), lw: 0.02});
      // 翼尖挂架
      M.poly(quad([0.5 + s * 0.330, 0.586], [0.5 + s * 0.392, 0.660], 0.038, 0.030), {fill: shade(STEEL_LO, 0.14)});
      // 尾翼
      M.poly([[0.5 + s * 0.058, 0.706], [0.5 + s * 0.222, 0.856], [0.5 + s * 0.204, 0.906], [0.5 + s * 0.062, 0.812]],
        {fill: shade(C.armor, 0.06), stroke: shade(C.dark, -0.3), lw: 0.016});
    }
    // 机身
    M.poly([[0.5, 0.038], [0.5 + 0.082, 0.280], [0.5 + 0.096, 0.640], [0.5 + 0.074, 0.902],
            [0.5 - 0.074, 0.902], [0.5 - 0.096, 0.640], [0.5 - 0.082, 0.280]],
      {grad: GY(shade(C.light, 0.10), shade(C.dark, 0.12)), stroke: shade(C.dark, -0.36), lw: 0.022});
    // 座舱
    M.ell(0.5, 0.268, 0.048, 0.098, {fill: C.visor, alpha: 0.92});
    // 进气道
    for (const s of [1, -1]) M.poly(quad([0.5 + s * 0.046, 0.430], [0.5 + s * 0.058, 0.600], 0.036, 0.030), {fill: shade(C.dark, 0.26)});
    // 引擎喷焰
    glowRing(M, 0.5, 0.900, 0.084, 0.036, AC, 0.85);
    M.ell(0.5, 0.940, 0.048, 0.034, {fill: AC, alpha: 0.55});
  };

  /* 炮击机 — 自行榴弹炮：方正车体 + 粗短炮管 + 展开的驻锄。 */
  BUILD.artillery = (M, C) => {
    const AC = C.accent;
    // 驻锄（外侧支撑）
    for (const s of [1, -1]) {
      M.poly(quad([0.5 + s * 0.190, 0.640], [0.5 + s * 0.436, 0.836], 0.070, 0.058),
        {fill: shade(STEEL_LO, 0.16), stroke: '#1d2027', lw: 0.018});
      M.poly([[0.5 + s * 0.410, 0.836], [0.5 + s * 0.474, 0.902], [0.5 + s * 0.396, 0.904]], {fill: shade(STEEL_LO, -0.06)});
      // 负重轮
      for (const t of [0.28, 0.55, 0.82]) {
        M.ell(0.5 + s * (0.176 + 0.052), 0.470 + t * 0.400, 0.058, 0.052, {fill: shade(STEEL_LO, 0.06)});
        M.ell(0.5 + s * (0.176 + 0.052), 0.470 + t * 0.400, 0.024, 0.022, {fill: shade(STEEL_LO, -0.24)});
      }
    }
    // 车体
    M.poly([[0.5 - 0.212, 0.372], [0.5 + 0.212, 0.372], [0.5 + 0.198, 0.898], [0.5 - 0.198, 0.898]],
      {grad: GY(shade(C.light, -0.06), shade(C.dark, 0.16)), stroke: shade(C.dark, -0.38), lw: 0.024});
    // 前装甲斜面
    M.poly([[0.5 - 0.212, 0.372], [0.5 + 0.212, 0.372], [0.5 + 0.166, 0.300], [0.5 - 0.166, 0.300]],
      {fill: shade(C.light, 0.08), stroke: shade(C.dark, -0.3), lw: 0.02});
    // 炮塔（偏右）
    M.rr(0.5 - 0.052, 0.318, 0.240, 0.196, 0.044,
      {fill: shade(C.armor, 0.04), stroke: shade(C.dark, -0.4), lw: 0.022});
    // 粗炮管
    barrel(M, C, [0.620, 0.376], [0.780, 0.060], 0.078);
    // 近防机枪
    barrel(M, C, [0.336, 0.446], [0.278, 0.286], 0.030);
    // 观察窗
    M.rr(0.5 - 0.150, 0.410, 0.140, 0.040, 0.016, {fill: C.visor, alpha: 0.9});
    // 排气
    glowRing(M, 0.5, 0.884, 0.108, 0.036, AC, 0.55);
  };

  /* 重装要塞 — 2×2：六角重甲据点 + 双炮塔 + 履带 + 能量屏障。 */
  BUILD.fortress = (M, C) => {
    const AC = C.accent;
    // 履带底盘
    M.rr(0.088, 0.788, 0.824, 0.166, 0.070,
      {grad: GY(shade(STEEL_LO, 0.10), shade(STEEL_LO, -0.26)), stroke: '#16191e', lw: 0.026});
    for (const s of [-1, 1]) for (let i = 0; i < 4; i++) {
      M.ell(0.5 + s * 0.300, 0.830 + (i - 1.5) * 0.030, 0.030, 0.036, {fill: shade(STEEL_LO, 0.02)});
    }
    // 主体装甲（六角）
    M.poly([[0.5, 0.062], [0.5 + 0.372, 0.214], [0.5 + 0.442, 0.586], [0.5 + 0.286, 0.822],
            [0.5 - 0.286, 0.822], [0.5 - 0.442, 0.586], [0.5 - 0.372, 0.214]],
      {grad: GY(shade(C.light, -0.02), shade(C.dark, 0.16)), stroke: shade(C.dark, -0.44), lw: 0.030});
    // 内层装甲
    M.poly([[0.5, 0.148], [0.5 + 0.286, 0.266], [0.5 + 0.334, 0.566], [0.5 + 0.216, 0.760],
            [0.5 - 0.216, 0.760], [0.5 - 0.334, 0.566], [0.5 - 0.286, 0.266]],
      {fill: shade(C.armor, 0.04), alpha: 0.85, stroke: shade(C.dark, -0.2), lw: 0.018});
    // 双炮塔
    for (const s of [1, -1]) {
      M.ell(0.5 + s * 0.230, 0.410, 0.146, 0.132,
        {grad: GY(shade(C.light, 0.12), shade(C.dark, 0.06)), stroke: shade(C.dark, -0.42), lw: 0.024});
      barrel(M, C, [0.5 + s * 0.230, 0.392], [0.5 + s * 0.210, 0.098], 0.062);
      glowRing(M, 0.5 + s * 0.230, 0.410, 0.062, 0.056, AC, 0.45);
    }
    // 中央头部
    M.rr(0.5 - 0.098, 0.436, 0.196, 0.116, 0.034, {fill: shade(C.dark, 0.24), stroke: shade(C.dark, -0.4), lw: 0.020});
    M.rr(0.5 - 0.072, 0.456, 0.144, 0.038, 0.014, {fill: C.visor, alpha: 0.95});
    // 胸口屏障发生器
    M.ell(0.5, 0.672, 0.104, 0.064, {fill: AC, alpha: 0.75});
    // 能量屏障（六边形轮廓）
    M.poly(hexPts(0.5, 0.470, 0.500, 0.470, Math.PI / 2), {stroke: AC, lw: 0.028, alpha: 0.40});
    // 角部铆钉
    for (const [x, y] of [[0.14, 0.30], [0.86, 0.30], [0.20, 0.74], [0.80, 0.74]]) {
      M.ell(x, y, 0.030, 0.030, {fill: shade(STEEL_HI, -0.20)});
    }
  };

  /* 指挥舰 — 3×3 飞行 Boss：长舰体 + 舰桥 + 三对炮塔 + 尾部喷焰。 */
  BUILD.flagship = (M, C) => {
    const AC = C.accent;
    // 侧翼稳定鳍
    for (const s of [1, -1]) {
      M.poly([[0.5 + s * 0.230, 0.520], [0.5 + s * 0.470, 0.640], [0.5 + s * 0.462, 0.726], [0.5 + s * 0.226, 0.640]],
        {grad: GG(shade(C.light, 0.04), shade(C.dark, 0.12), 0.5, 0.58, 0.5 + s * 0.46, 0.68),
         stroke: shade(C.dark, -0.35), lw: 0.022});
      glowRing(M, 0.5 + s * 0.452, 0.682, 0.052, 0.062, AC, 0.7);
      // 炮塔（每侧 3 座）
      for (const ty of [0.300, 0.430, 0.560]) {
        M.ell(0.5 + s * 0.196, ty, 0.070, 0.062,
          {grad: GY(shade(C.light, 0.14), shade(C.dark, 0.08)), stroke: shade(C.dark, -0.4), lw: 0.020});
        barrel(M, C, [0.5 + s * 0.196, ty - 0.020], [0.5 + s * 0.352, ty - 0.066], 0.042);
      }
    }
    // 舰体
    M.poly([[0.5, 0.022], [0.5 + 0.170, 0.118], [0.5 + 0.212, 0.400], [0.5 + 0.196, 0.880],
            [0.5 + 0.140, 0.948], [0.5 - 0.140, 0.948], [0.5 - 0.196, 0.880], [0.5 - 0.212, 0.400],
            [0.5 - 0.170, 0.118]],
      {grad: GY(shade(C.light, 0.02), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.45), lw: 0.028});
    // 甲板
    M.poly([[0.5, 0.116], [0.5 + 0.104, 0.196], [0.5 + 0.130, 0.404], [0.5 + 0.116, 0.856],
            [0.5 - 0.116, 0.856], [0.5 - 0.130, 0.404], [0.5 - 0.104, 0.196]],
      {fill: shade(C.armor, 0.06), alpha: 0.9});
    // 舰桥塔
    M.rr(0.5 - 0.090, 0.596, 0.180, 0.244, 0.038,
      {grad: GY(shade(C.light, 0.16), shade(C.dark, 0.06)), stroke: shade(C.dark, -0.42), lw: 0.024});
    M.rr(0.5 - 0.070, 0.628, 0.140, 0.044, 0.016, {fill: C.visor, alpha: 0.95});
    M.rr(0.5 - 0.056, 0.694, 0.112, 0.034, 0.014, {fill: C.visor, alpha: 0.8});
    // 舰首舰炮
    M.ell(0.5, 0.170, 0.086, 0.074, {grad: GY(shade(C.light, 0.18), shade(C.dark, 0.06)),
      stroke: shade(C.dark, -0.42), lw: 0.022});
    barrel(M, C, [0.5, 0.156], [0.5, 0.030], 0.058);
    // 机库线
    for (const s of [1, -1]) M.seg([0.5 + s * 0.070, 0.856], [0.5 + s * 0.070, 0.930], 0.020, {fill: AC, alpha: 0.6});
    // 尾部喷焰
    for (const dx of [-0.104, 0, 0.104]) glowRing(M, 0.5 + dx, 0.946, 0.056, 0.030, AC, 0.85);
  };

  /* 陨石残骸 — 不规则岩块（中立）。 */
  BUILD.debris = (M, C) => {
    M.poly([[0.30, 0.108], [0.672, 0.068], [0.912, 0.322], [0.880, 0.664],
            [0.664, 0.916], [0.318, 0.888], [0.096, 0.606], [0.132, 0.268]],
      {grad: GY(shade(C.light, 0.06), shade(C.dark, 0.18)), stroke: shade(C.dark, -0.35), lw: 0.026});
    // 亮面
    M.poly([[0.30, 0.108], [0.672, 0.068], [0.640, 0.330], [0.256, 0.360]],
      {fill: shade(C.light, 0.22), alpha: 0.7});
    // 陨石坑
    M.ell(0.560, 0.600, 0.116, 0.092, {fill: shade(C.dark, 0.10), stroke: shade(C.dark, -0.2), lw: 0.016});
    M.ell(0.300, 0.680, 0.068, 0.054, {fill: shade(C.dark, 0.10)});
    M.ell(0.720, 0.360, 0.052, 0.044, {fill: shade(C.dark, 0.10)});
  };

  /* 补给箱 — 方正的军用箱（中立，可以打开）。v0.40 Claude 补：原来借用陨石残骸的图标，玩家分不清。
   * 读法要和陨石残骸完全相反：陨石是不规则、灰褐、没有亮色；补给箱是**方正**、**琥珀色**、
   * 正面一个**亮绿十字**（补给），22px 下也能一眼认出「这是能捡的东西」。颜色写死，不跟阵营调色板。 */
  BUILD.chest = (M) => {
    const BODY = '#b8873a', BODY_HI = '#e6b45e', BODY_LO = '#5e4219', EDGE = '#2a1d0b', MARK = '#8dff9e';
    // 箱体（稍微透视：顶面 + 正面）
    M.poly([[0.16, 0.30], [0.84, 0.30], [0.90, 0.40], [0.10, 0.40]],
      {grad: GY(shade(BODY_HI, 0.15), BODY_HI), stroke: EDGE, lw: 0.030});
    M.rr(0.10, 0.40, 0.80, 0.50, 0.04, {grad: GY(BODY, BODY_LO), stroke: EDGE, lw: 0.034});
    // 两道金属箍
    for (const x of [0.20, 0.72]) M.rr(x, 0.40, 0.08, 0.50, 0.01, {fill: shade(STEEL_LO, 0.25), stroke: EDGE, lw: 0.016});
    // 正面补给十字
    M.rr(0.43, 0.50, 0.14, 0.32, 0.03, {fill: MARK, stroke: shade(MARK, -0.55), lw: 0.018});
    M.rr(0.34, 0.59, 0.32, 0.14, 0.03, {fill: MARK, stroke: shade(MARK, -0.55), lw: 0.018});
    // 顶面把手
    M.seg([0.40, 0.33], [0.60, 0.33], 0.040, {fill: shade(STEEL_HI, -0.05)});
  };

  /* ==========================================================================
   *  底板（我方方块 / 敌方圆形，保持原有形状语义）
   * --------------------------------------------------------------------------
   * 底板要**明显比机体暗**，机体才跳得出来；再配一圈阵营色的细边。
   * ======================================================================== */

  /* kind: 'square' | 'circle' | 'none' */
  function platePrims(C, kind, detail) {
    if (kind === 'none' || !kind) return [];
    const M = B();
    const deep = mix(C.dark, '#070910', 0.58);          // 很暗的底
    const deepHi = mix(C.dark, '#0d1220', 0.30);
    const rim = shade(C.light, -0.10);
    const edge = '#05070b';
    if (kind === 'circle') {
      M.ell(0.5, 0.5, 0.474, 0.474, {grad: GG(deepHi, deep, 0.26, 0.18, 0.76, 0.86),
        stroke: edge, lw: 0.060});
      M.ell(0.5, 0.5, 0.452, 0.452, {stroke: rim, lw: 0.030, alpha: 0.85});
    } else {
      M.rr(0.02, 0.015, 0.96, 0.965, 0.155, {grad: GG(deepHi, deep, 0.26, 0.18, 0.76, 0.86),
        stroke: edge, lw: 0.060});
      M.rr(0.062, 0.056, 0.876, 0.876, 0.112, {stroke: rim, lw: 0.030, alpha: 0.85});
    }
    return M.list;
  }

  /* ==========================================================================
   *  几何变换（放大 / 缩小 / 平移整个图标）
   * ======================================================================== */

  function xformPrims(prims, sx, sy, dx, dy) {
    const P = p => [p[0] * sx + dx, p[1] * sy + dy];
    return prims.map(pr => {
      const q = Object.assign({}, pr);
      if (pr.lw != null) q.lw = pr.lw * (sx + sy) / 2;
      if (pr.t === 'p') q.pts = pr.pts.map(P);
      else if (pr.t === 'e') {
        const c = P([pr.cx, pr.cy]);
        q.cx = c[0]; q.cy = c[1]; q.rx = pr.rx * sx; q.ry = pr.ry * sy;
      } else if (pr.t === 'r') {
        const c = P([pr.x, pr.y]);
        q.x = c[0]; q.y = c[1]; q.w = pr.w * sx; q.h = pr.h * sy;
        q.r = (pr.r || 0) * (sx + sy) / 2;
      } else if (pr.t === 's') {
        q.a = P(pr.a); q.b = P(pr.b);
      }
      if (pr.grad) {
        q.grad = { g: pr.grad.g.map(P), st: pr.grad.st.map(s => [s[0], s[1]]) };
      }
      return q;
    });
  }

  /* ==========================================================================
   *  Canvas 后端：把绘制指令画到 2D 上下文上
   * --------------------------------------------------------------------------
   * 坐标按「单位空间」做了一次 ctx.scale(size, size)，所以线宽、渐变都能直接
   * 用单位空间的数值，和 tools/render-art.mjs 的离线光栅化器读同一份数据。
   * ======================================================================== */

  function pathPoly(ctx, pts) {
    ctx.beginPath();
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    ctx.closePath();
  }

  function pathRR(ctx, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, Math.min(w, h) / 2));
    ctx.beginPath();
    if (r <= 0) { ctx.rect(x, y, w, h); return; }
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }

  function styleOf(ctx, p) {
    if (p.grad) {
      const g = ctx.createLinearGradient(p.grad.g[0][0], p.grad.g[0][1], p.grad.g[1][0], p.grad.g[1][1]);
      for (const s of p.grad.st) g.addColorStop(s[0], s[1]);
      return g;
    }
    return p.fill;
  }

  function drawPrimCanvas(ctx, p) {
    const a = p.alpha == null ? 1 : p.alpha;
    if (a !== 1) ctx.globalAlpha = a;

    if (p.t === 's') {
      ctx.strokeStyle = styleOf(ctx, p);
      ctx.lineWidth = p.lw;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(p.a[0], p.a[1]);
      ctx.lineTo(p.b[0], p.b[1]);
      ctx.stroke();
    } else {
      if (p.t === 'p') pathPoly(ctx, p.pts);
      else if (p.t === 'e') { ctx.beginPath(); ctx.ellipse(p.cx, p.cy, p.rx, p.ry, 0, 0, Math.PI * 2); ctx.closePath(); }
      else if (p.t === 'r') pathRR(ctx, p.x, p.y, p.w, p.h, p.r || 0);
      if (p.fill || p.grad) { ctx.fillStyle = styleOf(ctx, p); ctx.fill(); }
      if (p.stroke && p.lw) {
        ctx.strokeStyle = p.stroke; ctx.lineWidth = p.lw;
        ctx.lineJoin = 'round'; ctx.lineCap = 'round';
        ctx.stroke();
      }
    }
    if (a !== 1) ctx.globalAlpha = 1;
  }

  /* 把一组绘制指令画到 (x, y) 为左上角、边长 size 的方框里 */
  function draw(ctx, prims, size, x, y) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(size, size);
    for (const p of prims) drawPrimCanvas(ctx, p);
    ctx.restore();
  }

  /* 把一组绘制指令变成纯色「剪影」，只用来描外轮廓 */
  function silhouette(prims, color) {
    return prims.map(p => {
      const q = Object.assign({}, p);
      q.grad = null;
      if (p.fill || p.grad) q.fill = color;
      if (p.stroke) q.stroke = color;
      return q;
    });
  }

  /* 预渲染成离屏 canvas。
   * 画布**不是正方形**：单位空间的 1×1（图标盒）放在画布**底部**的正方形区域里，
   * 上方留一点余量，这样机体可以「高出格子」站在格子上（像 SD 高达那样），
   * 而不是被硬塞进一格。
   *   boxPx        图标盒的渲染边长（像素）
   *   opts.headroom 上方额外余量，占图标盒的比例（默认 0.08）
   *   opts.size     图标的**显示**尺寸，用来决定细节等级
   *   opts.outline  外描边颜色（建议开启，见 build 的说明）
   */
  function makeSprite(id, opts, boxPx) {
    opts = opts || {};
    const box = Math.max(8, Math.round(boxPx || 96));
    const hr = opts.headroom == null ? 0.08 : opts.headroom;
    const W = box, H = Math.round(box * (1 + hr));
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const g = cv.getContext('2d');
    const prims = build(id, Object.assign({}, opts, {size: opts.size || box}));
    draw(g, prims, box, 0, H - box);        // 图标盒底部对齐画布底部
    return cv;
  }

  /* ==========================================================================
   *  光照后处理：统一光轴 + 两段硬边的赛璐璐明暗
   * --------------------------------------------------------------------------
   * 原来每个图元自己带一个渐变，方向各不相同，看起来就像「各画各的」。
   * 这里把所有渐变重做成**同一根光轴上的两段硬边明暗**：
   *   - 光源固定在左上方（LIGHT 指向光源）；
   *   - 明暗分界线（terminator）是全体共用的一个位置，所以整个机体像被同一盏灯照着；
   *   - 分界线是硬的（中间没有过渡），这是赛璐璐上色的关键特征；
   *   - 颜色仍然取自原来渐变的明暗两端，所以不同材质的色相不会串。
   * 纯色填充（能量光、面罩、贴花）不动。
   * ======================================================================== */

  const LIGHT = {x: -0.55, y: -0.835};        // 指向光源

  function lum(hex) {
    const c = hex2rgb(hex);
    return (c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114) / 255;
  }

  /* 图元在单位空间里的代表点与范围（只用于决定明暗分界） */
  function primPts(p) {
    if (p.t === 'p') return p.pts;
    if (p.t === 'e') return [[p.cx - p.rx, p.cy - p.ry], [p.cx + p.rx, p.cy - p.ry],
                             [p.cx - p.rx, p.cy + p.ry], [p.cx + p.rx, p.cy + p.ry]];
    if (p.t === 'r') return [[p.x, p.y], [p.x + p.w, p.y], [p.x, p.y + p.h], [p.x + p.w, p.y + p.h]];
    if (p.t === 's') return [p.a, p.b];
    return [[0.5, 0.5]];
  }

  function celShade(prims) {
    // 1) 先求全体沿光轴的投影范围，再定下一个共用的明暗分界线
    let lo = Infinity, hi = -Infinity;
    for (const p of prims) {
      if (!p.grad) continue;
      for (const q of primPts(p)) {
        const t = q[0] * LIGHT.x + q[1] * LIGHT.y;
        if (t < lo) lo = t;
        if (t > hi) hi = t;
      }
    }
    if (!isFinite(lo) || hi - lo < 1e-6) return prims;
    const term = lo + (hi - lo) * 0.54;        // 分界线：略偏向暗侧，主体更亮

    return prims.map(p => {
      if (!p.grad) return p;
      const pts = primPts(p);
      let pLo = Infinity, pHi = -Infinity, vLo = null, vHi = null;
      for (const q of pts) {
        const t = q[0] * LIGHT.x + q[1] * LIGHT.y;
        if (t < pLo) { pLo = t; vLo = q; }
        if (t > pHi) { pHi = t; vHi = q; }
      }
      if (pHi - pLo < 1e-6) return p;

      // 2) 明暗两端取原渐变里最亮 / 最暗的颜色，保住材质色相
      let lit = null, dark = null, lMax = -1, lMin = 2;
      for (const s of p.grad.st) {
        const L = lum(s[1]);
        if (L > lMax) { lMax = L; lit = s[1]; }
        if (L < lMin) { lMin = L; dark = s[1]; }
      }
      if (!lit || !dark || lit === dark) return p;
      // 压成两段：亮面稍微提亮，暗面压得更暗，对比拉大才有赛璐璐味
      const LIT = shade(lit, 0.10);
      const DRK = mix(shade(dark, -0.22), dark, 0.35);

      // 3) 分界线在这块图元上的参数位置
      const frac = (term - pLo) / (pHi - pLo);        // 0 = 全暗，1 = 全亮
      const q = Object.assign({}, p);
      if (frac <= 0) {                                 // 整块在暗面
        q.grad = null; q.fill = DRK;
      } else if (frac >= 1) {                          // 整块在亮面
        q.grad = null; q.fill = LIT;
      } else {
        // 硬边：把两个 stop 放在同一位置
        const b = +(1 - frac).toFixed(4);
        q.grad = {g: [vLo, vHi], st: b <= 0.001 ? [[0, LIT], [1, LIT]]
          : b >= 0.999 ? [[0, DRK], [1, DRK]]
          : [[0, DRK], [b, DRK], [b, LIT], [1, LIT]]};
        q.fill = null;
      }
      return q;
    });
  }

  /* ==========================================================================
   *  对外接口
   * ======================================================================== */

  /* 从 mech 名（游戏里 u.mech）取图标 id。 */
  const ICON_BY_MECH = {
    B1:'B1', B2:'B2', M1:'M1', M2:'M2', M3:'M3',
    CB1:'CB1', CB2:'CB2', CB3:'CB3', CB4:'CB4',
    量产机:'grunt', 猎犬:'hound', 无人机:'drone', 铁壁:'ironwall', 突击兵:'raider',
    固定炮台:'turret', 盾卫:'shield', 追击炮车:'pursuer', 战斗机:'fighter',
    炮击机:'artillery', 重装要塞:'fortress', 指挥舰:'flagship', 陨石残骸:'debris', 补给箱:'chest',
  };

  const NAMES = {
    B1:'雷萨 · B1（近卫）', B2:'蕾卡 · B2（尖兵）', M1:'Feena · M1（辅助）',
    M2:'阿布拉德 · M2（重装）', M3:'Iris · M3（辅助）',
    CB1:'刹那 · CB1（近卫）', CB2:'洛克昂 · CB2（狙击）', CB3:'阿雷路亚 · CB3（特种）',
    CB4:'提耶利亚 · CB4（德天使）', CB4N:'提耶利亚 · 纳德雷形态',
    grunt:'量产机', hound:'猎犬', drone:'无人机', ironwall:'铁壁', raider:'突击兵',
    turret:'固定炮台', shield:'盾卫', pursuer:'追击炮车', fighter:'战斗机',
    artillery:'炮击机', fortress:'重装要塞', flagship:'指挥舰', debris:'陨石残骸', chest:'补给箱',
  };

  const ROLE_OF = {
    B1:'近卫', B2:'尖兵', M1:'指挥', M2:'重装', M3:'指挥',
    CB1:'近卫', CB2:'狙击', CB3:'特种', CB4:'特种', CB4N:'特种',
  };

  /* 势力名 → 调色板键。**加新势力只需要在这里加一行 + 在 PAL 里加一套颜色**，
   * 不用碰任何图标。游戏侧读的是这张表（不再用旧的 ICON→势力 映射）。 */
  const FACTION_PAL = {
    '影世界': 'ying',
    '月球王国': 'moon',
    '天人': 'cb',
    '卫星国防军': 'clyne',
    '预防者': 'prev', '流星小队': 'prev',
    'ATX': 'atx',
    '秘银': 'mithril',            // v0.26 势力名「米斯里尔」改为「秘银」（Claude 改）
  };

  /* 旧接口：图标 id → 调色板键（只有对照表 / 渲染工具还在用） */
  const FACTION_OF = {
    B1:'ying', B2:'ying', M1:'moon', M2:'moon', M3:'moon',
    CB1:'cb', CB2:'cb', CB3:'cb', CB4:'cb', CB4N:'cb',
  };

  /* 主入口：build(id, {pal, plate, size, lod, inset, outline}) -> 绘制指令数组
   *   pal   ：调色板对象（见 PAL），或 PAL 里的键名
   *   plate ：'square' | 'circle' | 'none'，底板（画在图标下面）
   *   size  ：图标盒子的像素边长，用来自动决定细节等级
   *   lod   ：'s' | 'm' | 'l'，不传就按 size 推断（≤26 小、≤46 中、其余大）
   *   inset ：机体相对底板的缩放，圆形底板会自动缩到 0.84 以免出格
   *   outline：外描边颜色（推荐传）。把剪影在 8 个方向各偏移一份垫在本体下面，
   *            机体互相重叠时靠这圈暗边才分得开。outlinePx 控制粗细（默认 0.021）
   *   cel   ：默认 true。统一光轴的两段硬边赛璐璐明暗，设 false 可关掉
   */
  function build(id, o) {
    o = o || {};
    let C = o.pal || PAL.enemy;
    if (typeof C === 'string') C = PAL[C] || PAL.enemy;

    // 细节等级：小尺寸下把铆钉、细线这类东西去掉，保证 22px 还看得清
    let lod = o.lod;
    if (!lod) {
      const s = o.size || 96;
      lod = s <= 26 ? 's' : s <= 46 ? 'm' : 'l';
    }
    const opt = {pal: C, lod, detail: lod !== 's', fine: lod === 'l', plate: o.plate, size: o.size};

    const out = platePrims(C, o.plate, opt.detail);

    const fn = BUILD[id];
    if (!fn) return out;

    // 把「战斗分类」的颜色注入调色板，机体画胸口核心时会用到
    const CC = Object.assign({}, C);
    CC.core = ROLE_COL[o.role] || C.accent;
    opt.pal = CC;

    const M = B();
    fn(M, CC, opt);
    let body = M.list;

    // 统一光照：把所有渐变重做成同一根光轴上的两段硬边赛璐璐明暗
    if (o.cel !== false) body = celShade(body);

    // 小尺寸下把所有描边加粗：细线在 22px 会直接消失，反而变糊
    if (lod === 's') {
      body = body.map(p => {
        if (p.lw == null) return p;
        const q = Object.assign({}, p);
        q.lw = p.lw * 1.5;
        return q;
      });
    }

    // 内缩：圆形底板下机体缩小一点，方形底板下几乎不动
    let inset = o.inset;
    if (inset == null) inset = o.plate === 'circle' ? 0.84 : o.plate === 'square' ? 0.94 : 1;
    if (inset !== 1) {
      body = xformPrims(body, inset, inset, 0.5 * (1 - inset), 0.5 * (1 - inset));
    }

    /* 外描边：把整个剪影在 8 个方向各偏移一份垫在本体下面，等于给机体套一圈暗边。
       机体互相重叠时这圈边是「还分得开」的关键。放在几何层做，
       游戏里的 Canvas 后端和离线光栅化器看到的就是同一个结果。 */
    if (o.outline) {
      const col = o.outline === true ? '#05070d' : o.outline;
      const r = o.outlinePx == null ? 0.021 : o.outlinePx;
      const sil = silhouette(body, col);
      const ring = [];
      for (let i = 0; i < 8; i++) {
        const a = i / 8 * Math.PI * 2;
        for (const p of xformPrims(sil, 1, 1, Math.cos(a) * r, Math.sin(a) * r)) ring.push(p);
      }
      body = ring.concat(body);
    }

    return out.concat(body);
  }

  const ids = Object.keys(BUILD);

  return {
    VERSION, PAL, ROLE_COL, NAMES, ROLE_OF, FACTION_OF, FACTION_PAL, ICON_BY_MECH,
    build, ids, platePrims, shade, mix, hex2rgb, rgb2hex, B,
    draw, makeSprite,
    // 供测试 / 预览使用
    _geom: {quad, mir, hexPts, polyPts, ringPts, GY, GG, STEEL, STEEL_HI, STEEL_LO, GUN},
  };
});

/* ===== PIXEL BEGIN（自动生成：art/pixel/build_pixel.py，请勿手改）===== */
(function (root) {
  'use strict';
  const D = {"v":1,"spr":{"B1":{"s":24,"fx":"rasa","img":"data:image/png;base64,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"},"M1":{"s":24,"fx":"feena","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAAD/ElEQVR42s1XX0hTURj/bdmLb909ClsWPt0HAwkkNK5jheAQCUYEguDwxQUWRfigIs0HKWRKGJHog4gQEhj4ILY0bMoKJBEuJCPXBkYvmxJKQtDtYTvXs3vP/XP2x/rgMnbOud/vd37fd77zXYDDBMGtCIJbYY0rvz6qD2uNHd+osBnxL9qZToSjmPLy4cUCECIOAaf/85DW+j0r/kUFRxDcysFmZ+Gmj2LKwWancrDZqYIYCcIjDsFh+S1FHB7+ZC3Ll8MMJJOeBwDUdX3RzU9NBJEYr0XP8Bxw7jxcNQF1LrO/AFdNANls2mFnM5n0PA53XuDqmISpiSAAoKdvGtm1x7Z8lMIfAPpn/hjiOIycv95JoadvGgAgen1MEvJqVAWTXJ9OwQdvm4LaxZFXo0WJxMsfgCGOoUDN4XX1f2/9CRMgFIlB9PrUjQDAaLeTS5zxNyndHI13p/1mUQLR/K3MLBBVVi/31p+g8col5tzkfSAUiRZdSI3EIXjx7T38a3PaWdT+9DtzzEi4chgL878V6P2wx9YYr9E1oBL+z0SgUCSGlY1d3fjP499o6Jo1LIBWls2mHaRuafHi23tY2dgtqv5UXCBSPAGgLSmppBu6ZnWP6PWpa4SWoZKItCUlyKtRiF4fQpEYQpGYaWNp1Ldo+ZtlKb1HoWWI2b9Vmd0sT5IDBRky7Mql/XDmtLjSa+5RvQWv0X7IrwwAa48VkkWC4FYy+wvqO66agEJnmBV/K1wtXkEG0c6J6o9qRywjQNbIq1Fsv82t3ZJl7vadtRHR68O75yk1a0gDSh5arHLwF70+XSY5tdcu3dNoI3DYlHu0ESCN1uRSLnINoli22hFYmC7ozmnT/rfib5RBhD/LqszOZlstgOSIOpYYz8/R6/Inqn8tnwXUep76Y3jTYQDN4XXUdUZVodSAfX6GC9fmbPNnrqP4WwokVScg+T0IrwHH4hTnNoOQqhPc4kjVCVOs7EwQH/LRzWbTDldNQKE79nLzJ+8zPzXos7clyzoXN+6+yt1qfg86WhvV8cXlOMIPglyfGgSPhaPFpD8DBMGtfF26jsv+dR2GFX8jo/mTQDBrEJnIZFJMoqLXB9Hrw+RSCovLcXWuo7URg2PT/F/bDBxWQOh3jMSx4m9mNH+tX2YN+vbjSEc05PcAyB0hye9RCzKdSbymxWE2qvmUtxKH129RjSIrqiRziBjkAVCQSR2tjbYjZzd7ckHJmR1x7Pi1yiJte+I0U5+II1UndJlCyNMi8UTObC0Rh8a0kznlzh5do8ijPiGv7TOsbg8rHJY4rNpQzuwxy6KCNn2021kW1c1usWJwAreabB2vSvA3vCZLMTvRLrfPSvH/C42OAYvp7toLAAAAAElFTkSuQmCC"},"CB1":{"s":24,"fx":"setsuna","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAADz0lEQVR42u1YTUgbQRT+VkJKvIgp2F8iiDdJoJBDxYNCL9IW1OAhttBDwRYSDz0UG0ugSGOj1EOhJrQJ9VJIcgoVItibVooUWixtSkkJQlKxKiQeVESRTg9mltnJbrKb7EIPPhiQmbff+97n2/d2Apyafma12sgpfgXwSCxFjArC4hsRwzD+lDAhhGwVd3VPgscnhOiaSL38TdXAC4UcACAanxf3C4UcovF5+EY8pFjMC/WQl8MHgMmZsGH4WvibqgXZ3tnDajoD2+Xz4t775S+6Vej2zh4AoK+3GwCwms6IZ7F3Sdzqd9UlEo/P7qmxBrWOwaYkupx2dDntCDYlJYLpZavpjIjf5bT/F4OpqkBzC0sAgEXHhLi36JhAfn1TdzL59U18/PxdEqteo/xrNUHNezw5Ey7b9414UE/ps9hs+bMJGRlDLbag9lvBZDGLfx8fHJWda02EjcNi8zFqFYjPoxp/pTxMSl2fmq0niCdTYxh/FBT3nk2N4e/aPIaHbogTQsvEYePYeoKyPoH7DlpFpBbx5fJg+VOrlofAg/Id3jnwEq2drjISdxzZmsqWjaOEDQC5lSTyt4GzvleaKlXvPBrkRiJ1rJTA09ffam6A/DePnLV2unBufBaTM2EUCjkUCjmYLGao+chj8dk8HgcPJEtNHhKB7PYrmFtYElVkxVluS2K5LVnWqLU2vWIxL/hGPJhbWMJhdha5laSs36+3NxF4/kJMmP7z3CE/3CG/olAUn+Wl9E9Wk4eJLUtvIgr/wwcSkmfa76K104U3jtJ7u3byIXeYna15spSSICaL+USkUsWwcVniAOC3mDE4PYqQexgAEHIPw5uIIjx0r2o8msfGpzHuJCPJo6+3G/5SlVKRBCrQh99f0dHYDADwJqJIeAOS7k+FouTpJPiZ/SFW3/HBkaapY7XayMW2dmz/ycue89PGHfKLAolNVBAEHvPqtevoH5CKXC0Pej44PQoASHgDJ7nQixw1TzxC2AteJJYikViKtFxql6xILCVeAOmelgsmj09j0kXx2cur1WojnnhEsuRweY6EEFn+bGxPPFKmgQiY3i/KirNV3C27AbMJ8Odaxan0rFIMflX6aUMrf1mR5KpHThy1JPQQp54Y9fLntRDS+0XS0dgs23foO6rUV6xWG1HrW+szRvrL+bJ9zpuIwsSLQ38r4UegktFRzPiTSoS04muJUQt+GbbXI05JAIBS31H7CrD+1UpaK76WGHrzp0ugM58vN2otF2zYWMuWlWmlES1X1lrxtT5nFH9BzU2+Enkj/bU+ZwSffw02rjA9c5bRAAAAAElFTkSuQmCC"},"S1":{"s":24,"fx":"lacus","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAAEfklEQVR42rVZX2gURxz+drlnkSVQos2poaW0iO1DCG0QL+VM0nsJJeSO1j6cFKsgFNI82G0h2MM+XEMbxELAHIiBawVP7iEISYzXXl7CkWBeKhFBIqTgIbhHCYItFLcPdzPOzM7M/ulm4CA3u/P7vt9v5vd9exvAZ1hW0o1yLcqIO14c/E3djZaVdIufm9LrumtRkvWLF6UIcfA3LSvpVkcntcRIIPbj7PyqJSzGDJJ4duy4BytIcfaSv0kmVSD2tZfA1sdw6g3uU8rdal+TBHe2H4ZKgsxXvu/isIrvjwU+UXvF36CT5SWs3ryDsYUZtFo7hmUlXafeAADc/r0uJdVcXm+TaFRfrdl+iNWJqzQOWyAA3DzF9sHJF2xujTSpPeKfIDev3ryDVG4Y1XYSLgA8rW1iw9xFOpuRAtQYEFr5tcee+1qtHWNsYcZ1yks0Ppvw09omVUQRq1ZZDKRDKv4A0FxZl64ZHTqJhZW7Wv4JLoHcsDTQg3v3g6nl2mNuF/2S0J0Kgnmgtwcr879gKP+Z8n4//qNDJyPzN6UJdNqBEJx81INjg33cZ/JRDw709tD7RN0RW6CTBIeh0pcH9+5TjGODfYHdTMY/6FDxTwgJuFXhhifbf2LmDQB4jZuvTxzC7StryuqTmER/yImRYUCC2cY4jn+f/x3I5oPGDnp6SMyENIHODpD+xMgr0jKRI7vHBicxWZeRYXA4HV1LZzOoVRbx5MoNX5HW8Sdjw9zVirSOvyFzGPbod+2ztIV/ttvitEDmBCqXYV1OhfVst+XrYCx/AHDKS8DAEaxOXMXZ+nUt/7nB00hdPkf5knYj36U2T+xRZ5HsLnxRvICSPQ27UYXO5lO5YY8IsnZcsqfRPdIf2eYxcIS2C3syztav4/DBXs+6b988gRQr7J31Wpt3Lp9D6dQ3lGhzeR3dI/1IZzP4AfsBAF/jLwBA+UwB3SP9tIjV0UmtzVcBjxU79YZnE0Sr/zL7KX4+esiVxeX4w+tiqdww5gBPkTzFEQortfkqQEFIf5LiAMB33e1FL5qg19g+FntZVSR2lOxpzo434NWLvsoN9L3Nu9k/4zP449IJt9XaMcQNIJstFkksnMwBRf6GQvCoHvz01QXlgyIAvDfwIdUKstavHdjdt6ykq8OqVRaRL9hQPf/48Z8bPO09Kcx46/wpLX9DlQDZsfEPNrUa9OOt/ZxY64qjKljXPguHD/YqsexrLwPHjZu/0jrnLxY9VigbRKv8hNQvKR0e+a0UV7ww/KUnyKk3qDbIXEX1LBE2kaB46WwGrx99N1DsuPmbYvCtqVlOOPMFG+lshtMG8reoDVtTs6FeeLF45PdSvmB7MMMUJ27+ht/buU8+Gsfdtd+4PmUf6NgHxagaJIspfg+rQXHxN4L2MltxcS6q9uhw4sCIg7/p18uyBzdyZNPZTKi3fmFwiDaksxnMXyxGescdB/+EDoT0cllwgvKZQqz/eVDhNJfX6dzW1CzeuXTeDXOS4uBvhOln8cdlVN0JgiPb1aj69n/4/wdBGzaeUN+bAQAAAABJRU5ErkJggg=="},"W1":{"s":24,"fx":"heero","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAAFPklEQVR42rVYbUhbVxh+rugGMjd655iTLgvUySxYItvakY5AZdLA/GD5IcJmf0hZ6mAiTDoZihRlBJlMpG2mDCm6Dc2PrH6URfzRkq3SDAbioBvBQSLFtmyJ2yKZNrC7H+E9O/fk3HtjE18IhPPxPs99zvtx7sX88h1NVW0aimCqamO+VNWmzS/f0YrpX2aH5Z/4lwCAfyYAKxB6eF4Ecf6XzShON3mgqjYtkYizuXz8GwmdjxWDv7iW8c/npFXVpmm7P7DfVJ9dt1ZVbdrD5J5G9jC5x/wdNJIIS8SwOulC+Oes1TTmT6FB/0wAANB9rh3J5JaiU3PrG0wGd3WOSjYuoH/6XySTW4qq2jTf5Wm0ud8EAJzv7sft1SDzY+Y/5+QErE963zdcz+8rhL8YOYEbEeZH4ZUUQWjD5OwKWt1OHcBiaI09AAD4Lk+zuaWFZdxeDUpTwUgkI6zF0JqpSMXgz68lcciU5N972mp4nQ3yIB9ejeOFR7nOeWto7ENmO6QTCACeefopNLkcAAAj/3yEGWFZCVQs/qI4iUQcO6l9lNTYawEAm7Eo/DMBdJ9rR5PLgUQiji9GvLDbK7Hxa9TwR6SWFpZzwGvstTDyLxbW68EVto/3b7dXmtYgK/75FnkSJ5GIYzMWReBGBDX2WpSQ2jwQAOyk9pmDj3+qxOnX6nU/GgOAv2516ACXFpZ1YSr6Xw2vS0UicUT/VmbFPx9rcjl0whD/0s1YFEcqntSFl38mwNIDANZ7X8LuP490DmVjZC1tzXivs4P5EP3zGNROq+q9QLMHsdgfAH7Geu+rhv55M+M/4etCT3829WVp1tDYhwlfF5pcDl0ZIE47qX0ofAfgF9JJ9/RP49JFj5Tc0GgQE74uAMBXs3NoaWvW1SCxLohE6LSpTsmwrLqYGX/yu5P8UyrQ9z/e1e2hurMaXmeRqYgh7p8JoP3tU9kTBZDZDqG8olxKLp1Ko6zaDQAoS4Vz5ozynY9OAKhz9rD/Il46lbYUSMafT7ET9Q7p3rEr10yjnHUxcUFZtZudpLfzLKrqvTknOzQaxKWLHgyNBlF13INEpBfVR+1sPvTddd16GYHNWBR1zh6dbxmeVRcT/fOReWTtI5wa/k0qUGTwGHacY7pOy6cXAJRScaMwTSTiLHpa3U7c/z31P/knXgYA3G98DkOj2XsOPchIJLtm+14MY1eusaIp3lHEtCKjFODxaMx79Sae/eCMZtbFeP4HLdCUntTqKb0AQBFDlU6Vt7JUGAPD4/B2nmUPcfL1k8hUuHRr+NSSXQRlxF58awoP7gZz8ACg4Y1s+n7p90kf6nx3P5bmxxWRP5+2Dz4rA4CcKIoMHss2h74MALBaSsIQ/5yHoPxPp9IoryjHwPC4tAvQTXRksBfpVBo1dcexfS9mWTN4LNojGqXq80df0RV+8a61OPc5FEVRzPi7zmRF/rojo9v77lxWuPDNEFsrq3k5An06PsXyngqwlWW2Q+D35SOQWVQdpPCL71JG/C8MTOr28ZdIM/6KGWmj7iXrZjLCj/MNxt3qQfhmKG9RDpu/KRCpyncTAJCNFyKMFSb/bWlydiXvN/xi8C81AxHfqmVz4nihJsPkO1uhvg7K3zSCjC5sZnOFRpDoV0yVgzSBYvAvNXJOnwrE8CSj7kaXRhUhrdD6I8O04nHY/EuMQOjzg9G3lFa3k/2KZTJMKx6Hzd/wK52vS69dR8sJ2N/J3nxj3zowt7Shmxc/Xz5OBMkwRRziYdXJisU/75dAvgWazRVag/JZl28NKgb//wCGbnidrUGlpwAAAABJRU5ErkJggg=="},"A1":{"s":24,"fx":"kyosuke","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAAFN0lEQVR42rVYb2gbZRj/3Xp0DkThgs7VJUVKkbH5IcvJliztSgmh4DcRUrUqMspmKC1OCqWO7Dw6LSu0rkKpSicbDu226hgGaggxlDQdNbWfRCRstetWEUlg+GFuFM4P6fv2vct7l7skPp8u977P8/ze3/v8uwDbIkke7YtL32m+I8c1SfJocCh29MmeWvzU4r8afZEsjk58iuXlZXhlf2klD61YvCvYNV5Jn90DoKIfSfLU1X+1+rvIJgK8kiGz27Gjb2cP8TPc7YGTSPi/8O+yC1iSPFrhTgIEeD3Tg/VB/Lz51tvwBYKoh59a8IuVDANA4U4CABDuUQF4MNxdWv/4WzgGH8pfBgCMPWjV+Yknk/R3uEcBAASC7QCAlWzGdrrUG7/IA7+KEngC2gj4x8zC9vpFxGIKVrIZrj5PCDFe2Y/V3BJ9P59I0Wfip1qSvLIfJ6MDuHbtOlRVscQPAH3v9dojiL1VFjQLmP3NHoqnbwbejnz2ybD+RcOTjqKH1JT5RMo2fkuCVnNLFDx7s2VADeJr67LUZ4XdY0cKX79Mn13v/Ga516ltuyKSPF3Lr9GwX8uvmQJlxdXzM33m6bOtuli8KyAPLTf74o7+4bUym9nMAgLBdsR/uoVb2+9iMaVinWH9k0gt/n2f2jOTH77/pizdWfyClrlIC9WsegbR3E7W+QJBqKpiyTCpQfFkkh5EVRWsD3UAALoTm4LxQIVfuuA6PF8i/6ZCfQNANCdi9x5973j0cAuUZIOY4X/19Tcso5lNefZSp+QtRGIj1J6gnW/T5Lmdbn8yOoCnrvRRR0awRnn0cAvxZLIsn7OZBZx4nC4jiI0sSfJohaFmhBfcdO3E4zQAYKaxg75TVUXXDFiitPNtmlE/EhuB/MEleGU/4jeuWuJv2u+GV/YjlL+MSGwE4dGkzpYoz+3C4NP5HY0rfRh70IopOa8DaSaqqmA+kcKBlKonyEKXFwkkDWYyOySxxTQQbEdC+KeUmovlUzKrD/UMwHTSvfvctupNeDSpT8dUGqJX9gP5PO1AhKyZxg7dZmUxrjOmHHulrBMQQskB7chs8jbQ6NYfNJWm9YGV56MD+Hzqgq72WOnXpUiTB0JMJNSCsbnqjBFiIqEWzCxAV8/MIima82hTclp3qPd/fQJN++/rI3s7uoFWnOo/jXNnB/DhRxcQnRwHXx/4crAIDIbgfe13fue7XmoYvWMlnYmDejvRnAjBd+Q4d5rcvLeBQ96jNIq6wp3cGYmtOUZZyWZgZ7gj0UDq3d59bjQ0mBfVZ595DufODgAABEEQjPr0DIuhkk4FgpqOJU2bgiBJHm33HpEWq/iNq3TDlLxlK3KM6UgIs0sQS5QvEKTksrhIN9q8t4F3e/sBANOT49S+UZfXIY0SiY3oOh+rT+xS46f6T1OnANDWGcLykv1cZqOtGnKM0dTWGcL6H7fx158bulu1KvbsB6hT/Kx91i4lKJ1J46UDL8DlataxyaaLboLmrPNuwCk55PuPzFTELpnHSLu3ss9GkxP8PJumVZRNGVJf2HDmrfPmFKfCfv8Ru4Fgu63vplrx88Q0xXjTLOvAar2W/214dp36qoTPCX6RMDs9OU5JKtxUdBMlL0QPeY+WtfhozqNVS5IkeTQzvxMH/y0bWs3+/rCyUw1+kS1M05PjpSKX/QqAW1d0rUKYTJ01i4lfMldZ4bFjpxr83BvgtfdIqAWu0fVShA01lyZYg0RzImqJIDO/PF8ED6+T1RO/YNVqzdpqpfVaapCT/Wb+6on/P+Y3nLsLMyI4AAAAAElFTkSuQmCC"},"U7":{"s":24,"fx":"sousuke","img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEgAAAAYCAYAAABZY7uwAAADuklEQVR42u1ZXUgUURT+RnyIWAzmacUYWUGx3QxRQhBSUVJx3wTJAh+KDOlJwURQJPxDBHMhMhEp6EENwbcVlhLEHkpJkWQFfUh20dyXXTAW6W160Dvdmbkzc2d2hKQuLDuz99zzfefcc885Mwv8H6ZD4BUURUmm71OpuOAmkUutXxQlmR4vXs/JWsB/Vj9Rvvf9h+rjFsjfrj/LSnkyGcP+wbFuLthQg/6RMWRixGXQn20Fsn9wjKHRCeZcWXl5xhGqJa/FampuwfLSouw0Z7CcY2dYOmhodAKtrS14X7eGeytVAKBcLywsuloxCNZFYtgdWbyC7/AMlbdLUHm7RLl2Y4Qjq7rf3MRg6c+ozNNnMpWKC6IoyU3NLczFy0uLiozT8imKktw/MoZgQw3CkVVsbW4yMZyUc9f50+WQzvKiKMmSr1j1oecyKZ+iKMlG+p3ocpu/YJbxw5FVDPf1IpmMYXJ6XkeIzLHW8Ow6wQSg09/VcR+T0/MY7uvlikwz/uGPH/BqaoYZQVb8VUl6cnpeFeJl5eWKgmBDDQBg7kouHvw6PjcipqtyvJWNGNTW3q1aS3AIZldHDM+PgZc382UrR7H4A8BOdA9rK2GVbFVdkFmltfwFVj6gewXtKPLl6konnQjtRA+NZYRHMIkDSESxcgaLf5EvF23t3VhbCeO65FPmCgr9yoaY8RdYCc5z7SoAoLNnwJC0dtytqwUApE9OuZOqKEry569flPUeT47lmoePnijXb9/MYHdnQ2eDlj+rj6uqrkY6nVbsM+Kv8n5tfSN2o9tIHCVQXBLAYfzAVkm04xytMR5PDvyBUkPZ3ei26j76bR2BWxWmDnIyDB1ElHvzvPAHSlWEyiruAIAqTAsK/QCArfVPSKd/2nYOjandjM6eAZVMaHwQ6ZNT1W/ePO+Z4zQOok9CcUmAi8Nh/EDRr7XBtA+qrW9k7t7jp506AzyeHCSOEo76INoQbdQaESc8jfBYOS40Pqi6124EK3/qHjWIgChKcmX12fkk37NTIfgDpZidCqmcRYC0CZS3ktElnuggxlHlXvU8xrMRdP4MR1Z1UUjLGHXcAk9+oHeShDbJFxvra67kIO16s7lMdduRMX1YpUOQCr/zI7itJFdy5OxGEAuDdy5T3bwy2TxdKR1+lIdlchT+hPKY7ijwdr6sEFe3GO7q5sXI4nmPYvRyKZmMcfdJTjGcvkCz0k0/5jh6H0QaJ7ORX3Ajo1cJVhg8HC6av8D7L4BZqXX6b4HV+kz0u8X/N7kwW3TkuIA/AAAAAElFTkSuQmCC"},"B2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAAC/UlEQVR42q2WQWgTQRSG/w1BoXjQrVS0kKt6iB6SQ2EheGpFSmNbkODNnEK9KUgugl40FuyxRYUiCKXkEBpiIQ09lEgukkBIQJKLkGICCSTxUCoUZDzUWSazM7O7yT7YQ96++fZ/mXlvHgBA1wNkfa1BdD1A4NJUayfhesXh1/p0PUB+1lrCQNXDxydjBbB+N1w7wV7q037/IuTjmyZSu/MYDI41Ctv71JKKePnqNert7ZH4ZKwAAHixeUujIp1weRZvXuvT1tcaRATL56rKo1KqZIVQmnAyVoBTLs9izWt9flFwPldFJP7XBui+FnmR9BuR+CKARTx+uEJkO63iuDGfqP6oLbz3wwgHRx7qc1JnMi5NVsZzw3HauKg+X2p33gItVbLnkXt3ras5H1+vADAYHGtKLoC3T7+iVK6Lv8GYHcdpslSfpajpB4KzcSWo3t4GAIiaE/sxnptYyqJUycIIRUeEqxqXTJ8RiirrV6RPY6H7Wy3cNoC5uVX0Tsu4oF0SAs/ICRLLO7h88aopQiV2f6uFJ89XsbLwDJmDDQv7jJzArna90mfucGJ5B6Xvh+ai7rCGa1fuCIH8u+6wht5pWSha1wNkZipsiefZdjvslT4fdWYONgAARig6clSMUBRH6Q6O0h3hO9mxokLZ37L1RiiKfum+sjGp9DU7aTQ7afO3Sp+fNhkABAAyh7XzC/9Pw/yXvv348D+8ar5jY0W7q+sB0k8WAQDTqQhkbFpz00ZeusN2+m7eeDSSrEqfRSRtVvX2trJG2DgnyfaTRdz78hkAzN1wU8Ne6bMIpRB2kahDs3EskCZLE2UnnX6yiOvvHljYtKOy8bKEJ9WnyeqOjm9si08sZS1tX9aoZH4Rm87FdnO1F/p8knpxNL7Z1BycsvO5quNxcVJ9mt3RoccCgOu70yl7nDt5XH1+GZR2PrbGRL5xjOeMwx1Xn092yfN3Gn9vzkyFXQ/0MnZ3WDN9wdm4kjupPulkxFrvtAwAEPndHGsZ2w13Un3/ABFMI0X1zPrgAAAAAElFTkSuQmCC"},"M2":{"s":32,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAAAgCAYAAADtwH1UAAAFYUlEQVR42u1ZQUgcVxj+NmxPlRImWC2o2dCDhF3RS4KWUJYUxRUKWyFQaL1UerEp7rAG2kChKJhC3e6GpD00BCxSwUNkwoKbuAamoRCpLVh2h+AluG7puhGXUgw5pHR60DeZmX3vzczujNvD/iDIzJv/+77//e+9//0LNK1pTWta05rWtIaYz+kHgtCl8t5XKju+4yBu5tEo3GPVLwhdqnrwM/Pv+6mAakXQCx6NwnVDv88J+P5+Aan5NcuxM/FxzzKBx6NRuPXw8Dshsb17gOhwP3eMdG/d822AzeM2ZuLjqleT4IV+n5PZ3949AACc6z1LHbfx+2ONhFfZKAhd6m+KYnhm5vPvPydcxTbrtzIn+v1OZp+I/WSzSB1zrrdTm4TjMhJ8PacbodOeZL8XZnsCpHvriA73Y69cRGtbJ3XMXrnoGVEaF4LZ2taJb/v0nE54iulpGco7xb9I3EZ0uB+B9hZmlpDl51aZxuJDuABAoL1FOxzr3frs6Lez/djV7zMDP8gXqj6KfZ5CLp0EAJxqb+MS2N8tw44fqyDZ4aPnQnBZfvWBpY1plH6fGVh6uEV1HH27GxvfnMGz4C0ugVeVj/Hj3iTCkQjTDyHCC5YdPvL9w6yX5DxS12JMv4LQpT7ePvQ3e3MZC3OiYYxdPLf1A4Cv/LeqEmIs29zaQTgSgZzJ4IPW63gWvEVditlEDxdcb3ImwwzWg3yBGQizj2g4BEnOa5hmvyT4d6fPaN8pQkKbBKd4TvT/9URh+rp6eRSzN5fh39wqobD0FoKMgYqQ0P4PRyLAr9ddOXwIyZ9+EKv3URvB0Hw8L1Y9i4oxzFw8rd0HNrdKBi3BShxjU0kszIm2g1+r/mAlTn1+dzoOCImXVZA+0LyP9bMvlQ8P42jbgfYOcr7hDS4pmYI5+xUhgZTYgdV8JwpLziebpn/onYsAgIkrs4gO9zP182JrqNdGBgeQEjswMjiAkcEBx8LdKtPkTKbu1XWqvQ3vfzShba0pscMTrMCbZ23pZ8XWcA8YChW5YCefFw0gsV5SfuomIRyCdCSKdRYQ0eQgMpdpuXRSNW9VtO+j4RCiw/2QGKsuu3IHIx9+xtWk58DjG45EqvRPXJmtCrxef193V5WvoVARq/lOZxexXDpJJUe7dJGA5NJJ/LmxyC3VWFWQfhJoPsj3818pmmjzWUDGjAwOoLAExJJ/UFeBFRbxRdNPy3i9/quX1w3bneVN+OmL83j9lV+4JVZWsTNlk4YMqaVbSCoUmg9y0ckmeg552dwunr44D6DkCEuP51S/HQ5+Y7lZQl83neTi9BiAVptSF5kZ4rRbaPah//7rFR6fMqWcLjk+wwheLfppwTdz8NslycoOls3Ex7UqoR7j+eBxIlm7kn2E4FHVQbaDS6MXoMjuYfHwrWLrrzUT9dnBylKyD9faDzoaR+3NmNvD+maZfpUszIkYmzIe9oqMqtswD6tW/baacZOzd1TWZeHS6AV8Kb+HwBuvUUHILJv78/r3bv8mQOvNEyw9D9KgIxz1k2AOvlM8O/oD7S2IXVuGVWz9tAwxZwoNoJFmp+WtH1Op7PgW5kS11o5sLS321Pwa7MRW65eMTSUNF4SV7CMszIncDiDZYnjvvVgBNLz93TJYz+ttT9ejn6w+WmwrlR2f35gh1cvUTnlm9d5tY5WmvJLVbTy7+nmxNRzCtGVKOoXy/TXuQcO6gkuyiFw66dqP5Cw+hIsk57Xb8Uur/Yd6N/WztkC/VXUiPdzCyf/R/s/jQ+uO6oNZyyS4pZ+F7ePN/qffrXKbVaSP0vOuyG2M3ZgYqvsssOKTSyeZPEgbwQmP49L/H66EQODIkgpJAAAAAElFTkSuQmCC"},"M3":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADi0lEQVR42q2YTUgbQRTH/9pcCh5qWlBL/SieBAOFfiC0YFCQCFWDIqIoirmIJyUVtBAUAlqQsDl5aBssCCpIZWlEIipNhYq1gkIiKkU0HtQeElsMCL1MD7LD7GZn8rULC9nZmd/7v9333r4JYNBhNpeQ92/KiPbabC5RnelyFYZROk0iB0QLY7GzHHZeNBrBh6HHqjkbsRZYGh7BOzEAABgY8SLklwiPpXe0Nr/CRqwAy/IC0bObTF/Kb0t0SNOr9I3tnhOye05IdbdEOnudqje88nWHVHdLZHT+kJCbH2R0/pBI06u6LJ6Wzl4nqe6WqA3Fbir69Hi5es5GoxGcXsa5p91WhWg0AkvDIOSNIzzJ34a1vp77AMea/mLv6gW91rJcHh/3jXV1tQMAtbEejsDl8SXVx2PqhvTpZRxHv46EUSAHrjTO8Odb+zYBbCY8FMVGRXk+ZuVFdNibCS8U965eYKxpG9Y+L+zWSuNzGAAmzh9gqbFINfb6ywWWGotwcLyBkF+CFQCwCQAovqNePzMzh5B/gV7brZWw26qosy+fWSjv+05IKHRgxAsACPklfHq3b6zDcmALFeX5CLaVIn7zT3VPOxbyS/R3sb2VW0C04XVwfAUghGDb0wQbooem6FMeXFYOK6LcTgdcHh8Ojte4C91Oh9Ah3hq7bZ8KlgNb1Ibb6RBWVtbGrW0f12k5sEX1mc0lqjQxsc6uhyM0fNxOB+4XFugCo5e/wc7lfWqW5QUy93kR7S3NlN0z7EXIL2FqskDFS/YZ0dPHMpLpU/gmFhZcWaO5Bgxyi4McDCfMZUObdVpxNhnb7XQQkdMG6COx2FmOiS0KbFGRg+HbBbYq/PmWBwC4Vx1PuMdeiwoOj00r+d0IavtLuU6LGHW1NQCA/qHx21QR6MthQ8bSMEhvnP+cpYCywjz6uQKAutoaPHzeoSpcSo7pCRax2ZzjrVXYPIYc2FI5yNOncliBuzw+WkREOczOS6WNY9lTk28TeOkyMtWX4LACYRfpVVt2XqpieWxtxc+EkbE+tlc9ubhW9c0nF9cJY+nuqPTYqfbVRujL5e0ylHw1bEciYCs9cDaMVPXlJAsdJSwAQDuWrsM8drrcbPRxe+n+ofGEHNMby+TQcjLhZqovV9TRaFs3u62KnpaGQWSSw3ps9rsp2ioaoc8k2ploG4qe4Y9Z/8XCY8vBcNIGxgh9/wGp2WK4p5U4jAAAAABJRU5ErkJggg=="},"U2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAACrElEQVR42rWYMWgTURjH/xeqYyMxTmIH0yGLN5QsQWzAFBSnYnERXRQyGQcVJ12sSwMRJDSlnTrZoVibpXTocaRFMnjtEBcHI1TJItcSdUsgcWjf+XL33rv3Xs4PjsB37/3u/9173/e9C0BZIjExuPfg6SCRmBggQvtfXJ1njrEG35q9g63NdaG44+PvhqoIHleHFfbyjo4Ocf/hs4DfYIHW3m+gXC3g5YvnTNj86xIcy1USyuPqsmp2SThm+e0nbG2uB7hjokk7e9tMfzZnAmjCsTDQWR2aq8oiwfK0/bPzTC834CfFFSGuUS+MnGdZ89HpL4AicHf2tlTQ4cHyLcZylqsnwdy4sIKrmStDF/HpWLlaOF3Rk2BH5Yns5x9bPmDP0styPg17Uyngo/NZi9eoN7Wfa/AqXyafFE50LFepyhJ28dV1NOpNZHPmkHCZwuXXR3YL64Xw9Bk0rLz4GACwVFnF1y+/ETvziwns9+LwjxWJDWP3e3GpYKPQZ9CwtY133qROu4tzF88ygf57nXaXG7QsW7TCUerzcnipsuq1CXqrZHMmFub2sTC3z7zH21a0idjksqqHwsOEiHGw28LBbotqc3x9Q1t6Mj3u3fjW+oGp6RSyORMz124OtYPF+Q+4nLrkjZXZ0jw2nXO6DFILCE+kL1C0SLFyLFeYI/Q42aJF5pDVUMnhqPQFAiYQehKrQtPjZMXy2LIVPwp9Mf8hvt+Lo9+Lo2aXvC3iWC4cy/VyIpNPgoyTPVqK2DW7hJpdQiafFOZxFPpivC8XmeOb6jmax97Z25Y+Lo6qzwjbOmRbAFDunbJsnZ6sq4/78TA1nQrkGMunY36ODldXX0x0ovH3MLpvTqbHofoPBo/daXc9X1gej6rPCOt3pI8BAMuv+uHOYqhwR9X3F7XtUVaugn2ZAAAAAElFTkSuQmCC"},"CB2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADdklEQVR42uWYP0hbQRzHv5FY6yQ9iuLySgcdGiyigi0dagtGowWt4mDaLFaog0UwHXQIoYSigg7FgkPRwWdxSBOk1L8Zkm4KsYPYDlWQdIg6JCoIgkivg97z5b27l+eLWw8eSe7P576/e/f73e8C/GfFJmogRKJGA9PpPzYrE/K4VljXqo8QifJKsdtF/XtxWux20WwTmuWOy8ErswiRqH8vrjzjctA0086DpVIJ7B4ccSf7W/IDpU9r0e3qgr/PS82uJI9b2dt5LqLRAbIEUyzGKXnRhNefn+PrZBLdBY4MbntzPYAxrj47D7p7cISNzW3uhHn7VQCSlvyHt4hM9EhPAO7WNlNGM44VLXajxqGiML6V+ZXf0z0BDO2HMVLehq3ETk7Bgy2o1QX0ubqAyA66CxwXbzQHg0PzEZTduYvY/fc4PjlV6h/VVCBWWI3jk1NLBofmI4q4rcQOpnsCwG/gYfkzy5ycorTa0d99GDMc6O/zZkREQiTD7cjYm9sbiuDQfCSDJxrP2Fp9IqND8xGdPp3BhEj0za8wAGCi34ezpZ+wF97gAs9OTqHt29TagYW5IFd0NvbZyamhsYydiz7Gt6kF3Y5cbtPA4tS5n3CKtm0tugp5chSeV28xMzVm4xmbja1+I+qSSiWU7x9nvljSF1icUozOY5UT/T4lpKu3SntzPXrzq9CbX8VtM+NLIvZadFV5UqmE7mlq7cBKbB0AlE+ehsDAIAIDg6ojSawvY0vbGx2XLd+34BseQntzPUpvFWUcB5UVNcDjMqWr8+Y94RsWsZ0NLfB4zs9hWZ7lLpQ8OYqV2DqcddVYia3D88nH1cdiATNOq0+3pdXCWLDy93kNfYT1W4uuwuPphLOuWmiwls3ehrOhBQCwMBcU7o7ZUFgxWJZnUfvkwZX0aYOhzmAGUQ/iRWh1PyYqm8EitiiiAsByNE4Ze2EuCCv6DJMZQiTKct5k+lDJSwmRaDJ9qKsjRKLL0TillNKXXV6aLS3ksY1yYDVbPadZfbpMUXTLEOXSudxyROzdgyNT812HPmFqWVlRY6rOStFyrHCt6hMa7Bse0vkYr45FWWddtfk8WMMRcY3YV9Fn6q45LgeFPpJMH2bciQmRFB+zwi52u3R16jFqthV9hv946M7Mi3OM3Vu19cxPsuXSRmwjrpZtVR8r/wAfBDOnzd1/OAAAAABJRU5ErkJggg=="},"CB4":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADKUlEQVR42q1WP0gbURj/XTgqnaTXImTogYMuktJBENpBkAbULKHRwdIsqVA6hIDpoMMRJJRIaQah4NQshjqkCTfEKI2IHSoU7GJbh1gIJ0KmizgJErgO9c53d+/dH70PjoTvvfd7v+++7/t9BwAQBFHTNE17mcpqgiBq8Gh+zwmCqPl9gubH64tf937aNjuBdbsnHO2c0+WqqsCvcRwXKD/+JuQ+lr8gl8n6etOqqji+nPX1Dbvv0wcEzY8asKoq6JydMwETsSiAInKZ7I2CbZ22bfsacsXmu0/x3ZYfNeDO2TkOf/9FUJZ89fb/b3IOrdP2FSGY7vgs1/Ai/twoRSdzCtbNQmR5JJNzUFUF1c0mAKDQX8PT0Yjp0X0AMB2fNc5Nx2epfdXtnnANuYKGXLEFa8VzK18rPydLxKJUfiFrY5P/9x69swHRfG5Gy9qx0sb3g1+e8Fj8nIz1UniaeDTkCpZXizhW2kzAXCaLjWrNs2jpZxKxQ1Q3m0jEoqhuNo07cpmsp3LW+QFFo1powbL4cYIgavzkiG2ht/0H/N07VMDexSXSRzWsLUi2M1bSgiBq6aPri9cWJBt27+KSGWzQ/HgACE+MYb7vGjS/VUL6qIYHTXqG81slyPU6pKmUyUcja8WRplLIo2Q6e5VhjRV0kPxCANDZ/WE0ul4mcr1u+HqRGfQiM6Z1UhxYpaVnlNxH7iV90q7C/Jhw45dfXEJ+cYkYSWx+HK1swhNj6OTKkFYKSMSiCN/rN42Dx5FRYHzItZyZJfnt2MAme85rWVv56QKl4znx46zCsrxaNETEqUfIfSwlZmHr2SDxnBQ9SH42gdFBRp88w0m7BQB4nXljEB0IixAHh3Gwv+MqOCzsgbBoWhMHhwEAB/s77gJ2S36ck8CQI4h8u1aBYJWzF2yveEHxM81huV7HfN+IqcnJAU4TJ5o604yGzQrYD4ZffqYMP3yfQidXpvYEAHrPjA95yjAL2yteUPxsX1rSSoFZMrQ1rxlmnfeLd1t+PNkf5GzzUzL85AiEbWisscTCZgVsxQuSH+f0+UbOMABw2+N5DnswEi9Ifv8AMr+zmiHD054AAAAASUVORK5CYII="},"S2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADv0lEQVR42q2YX0hTURzHvxv6lKQeRuCDN5+EPVQaIVEvhg/DXgpBiEBGIIRv1/7IGK2YgzX80wyCyILYkggEIxJkkOwSBTIKzcJB6EMaDsLplMoHwdPDOLd7zz3n3k134Dzs3HM/5/u7v9/5nd8ZAIAQheKQTcSoBLfS+lyEKDTgdiO2v4/NzVVXqYvwc3lGOVzjc5HQSuoDIQod8jTRIU8TZRBCFGrX3j58aZ47Pm56n42XwjWyZAZXXB8PpZTSv+tbtp1BRcbKxMq45Rp9GH0Wt9+OBjG9W4Pq1mbbPbE3/x3ZSBAALOEmCknG7eju1J+9X14xzb16uetAHFl7dLLVos9tjPnY/j6Gg1H9hfufPTh/5oSpszHW7IyVcZmxIl4pnGwkiNnJmbKNNRlshLKmqcctIOOYk7EyLouQj5++Ctdw4nhDUUcPe0NRoT5p1kvci9kC/eFASVmW5//89gWzkzPo6O40eYnxnDK2UZ/M6NnJGZM+C5fPeuMXVUqIQpubWoSdEIXSxXVKF9f1uU7G8vMtPEppPJmWspwYIn3xZNrCdRGi0Hz+BwAgu7YNAEhp8zjy6g0afG1CA3KpjOlZLpVBYG5K6B1CFJrX5jCd1qTvL9c3QO1pR3ZtGyltHhHVbzlHnRi8vj9XLsHXXtzH3sZajL3QEFH9qGLGGpuvvRUpANjKoaO7E09+1QEArh8rAAAmUhkA0EOK/Za1p4EhNPjaLPPZ7+V3C477147Rcu4CAGC0f6Cot75BN5Y1tacdQAJV2bVteBtrde8ajV55nStOPlUc2y3+xMiShluGRWXeZXsnMDdFY4b5I0saRjnv8OuXwxjtHzB9QL4xGwHAFU+mKf81WFg/vtsvBGzsbOpJzR8OOCYtdoZ6Q8Wj6WZ8yPS8bzCue0QU0jyHnRCeo0S4Xt9gHHs3rgEAqh88N7FdhCg0NJYwhQBbVJap/eGAvljv74Jj4ZGP3cFwMIpnNXWWD8Z4HxYWHY01cngGry80ljAZDQAR1f8ftrRaoPFkWs9orHxjJRohiqVsE9W5lsxqKO1Y59ms/pWVmCJOKfriybRFn5t9uenTLYiofv0r7OYKKKegCLjd4C8PzCMsApjnePZuriDdfyJOqfoiqh+8PpfsamfcHxs7mwAAfszuKmh3reM5Mq4d+6D69AF+EX6P8dUXn6x4ht0Yz7HjVlqfW3RZzmtzwjTf0d2p99jZLlMIixKNSLiInTOcqYl7MUuZW0l9VbJDXlRQTPSGD/13jYydS2UcC5hK6PsHZI19o/iBSsQAAAAASUVORK5CYII="},"S5":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAACs0lEQVR42u1WMWsbMRT+7vDSVUvxoh8QMJgOxmQLHowzGrxk6ZIumTK0RQQymFA43C7u0CFeXXcIeLANIcTGHo8YAi0le0xISJu7Fg/NUqoOri463cl3h10oxQ8E4um9T+997+khYCUrWcl/JYRQTgjly7L7p+MjhHL+6Zofbu7ONY5r9zeSXTS+lGrcYDWkizlYAJjdDgV1RjZ6w9HSkwEA150Y8+yWHh8hlB9u7vJuvcV10q23llrdJB2zaHypMNB0MYdCpYT7m++hlxYqJQwAwG4vXDlCKBcVUSun80kXcwCA3tsPs1iOjh/i+rNPF3Ox4gMhdMbe1h7/cf0tdPGtPd6ttyLfUVTlxHm33vKwReXm4QtsUe2wvc7XUIFcd2IQQrnjXGorPDg6xtMqg7BVKyGqdjs493Sd0z6YwriobKFSAgA8ev4a929eeOc0m8HdlytD7RbhCwC3g3M8Ljzx7Rus5rtLjs+Uwax82QOVk6XZDGg2E8q07CN0F/vv0GA1rB3s+NrQcS59S04WAPD+lY/UXz/NAIli9YYj9IYjjM1pYJ8u5mDly3BGNtT4Am/YypfB7Daa21VP97V/NpuQkk6w3GA1n851J8bawQ638mUAwNiceu9L7RhfshLJ2fUN3E1drzLyO9f5BroQCMwF150YRljFnlkvI8f6zcmMBGa3Q4eLYPXq88dEE1t+LmrXjM1pZKJh0tyuenGm1Oowu83BHia1mHoqs82TM22yAksk3VQ6Y56ICaxK57TvnYmYBOk6jNjkEEK9iSlPPVWfFKdbbwUwZZ28TxKTboXFasYhwHUnRtQPKI7IjAs8WZekXUVMuqXzS+kOsusbifRxcMJ8o86XdXesz4faDlFtF4Wj+iZt6UXu1rY0IZQ7rBNJisM6iPppzcOJe09S26hYfwM3HtEfSUOtSwAAAABJRU5ErkJggg=="},"W2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADf0lEQVR42q2XQUgbQRSG/wQPIfS0wUMPZil4VYJ6kxahOSxSliIUKTVU9JZCDCRIrFCCpxAr2FK8WhqKldJQRERBqViKgumh7aHSiya5JW5aVDT04PSQzHZ2M7uZjT4IYWd2vve/mbdv37ogYJLkJwAwl883zMVkGZVKwYUrGvVBjceUJD+x0mC1xmxtIgKok9EbtevXZ7X/rYk45vJ5xGSZiAZtDoyapuV1bj0IA5MGuzURx90Xzw16UNcXk2Vit2G2oqgtnpIGe/fmFZEkP5EkPxkZixGrIOy4ZtbGp5zB5+IpMXBZXzwOq5UyeRrcPFGalodWLkIrF42nUB8LKioW5icdpyzLZVmalkcmswSfT4bPJ+spyktfmg0sw6yR6uMFzU1prVxE7qBUS5vbHdj4/BXXYWZx1AfoP5OKMVkmlgFzggSA0fYOaBf2Gtx2k7udvTi7+Iv+vi79t9vZi/6+risHnzso2fIqlYKLnnSrGyoc8Ob6CgAgebNxjjcmapQLAH+O9vAl98OWZ1V4WI5Ta+NV0HA0jYX5SSwf7VkuDEfTjp2Fo2n8OlCxub6CoFL7t/Nhx1mYB4KKarmxVJ8k+Q3Vvs1QVH7WbpqdjiAcTcPrOecCz6te0HtDU/tiBYuyn/YhlfXA60kaeIP3HzTlhEIP0e3O6EGzDCt9s9MRpLL/g3axgpY3jvVFhZ0Z+O884wLZudXtQ3S7M0hlPZbNQjP2cOgJQuNxrH18b8sITe3j3sAtR/roNdWnP8Oz0xEAtTRhUyWoqBiunmC4esKdEzE7dlBRhYoNZZj9BhUV8UQS8USSO2fWaOhkEkNVfeLl2iWep5IIKip87R2GKhgI9CAyWNur75chy5MRYdNnbnX70JYjSX6y9CGLb28HGxi0iFEeqw+AIftcZihtKJo9w/S+ZkJ5bHoa5mdYJODfxT1H+sLRtIHZEDCFsIt4VZLeN6A8Fg7Yih2OpoUDHn+kONJ3XvXaa2N71eNSwdA3H5cKDWNOe2kemxBCRsZitj0wr5cW0de08aC7IVJInJoVWysX9ep7nV0V72QtPw8DgR7myms51oqZOa1wW9XnalZg2K7KPFapFFzmTkYkrc0cHtdqLfUpqk/s87DepZjfYfS9FlRUJIaqaCVYHruwM6OPWX3W0RR1qq/pCZvfmfQ9BgC8cacB8xhOuFfV9w+EUB2fdvlRPwAAAABJRU5ErkJggg=="},"W3":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAAC9UlEQVR42uVXTWgTQRT+NhQpPYVBBEWWCuLNeqiHglh6yGEJGkrAi7QI1VNyCTSUnGTJKYQIpdgePRirLYVQgoZUApZCMYf0UDzYm01yKKbd2oPU0EPHQ51ld3Z2sz/Riw+GYd/s+943M+/NvAH+M5HsBgiRqZPh8XFL8uNQhOsHq6/8CJGpk6y8fkl7OXSL6wcrCD9JBKZpTWiHbUentWoZiVTe9Uo64XrBCspvQPSzdthGY6/T9/zhSTIf4eExvF0v4fFknLqZdK/JOsmA0+Dnm6NIh89MusLJJaTDZ/iwXw80+cZeB/fu3tbxthtf/smhNSCK9Vq1jPDwGNSrwM9f5jFex9uLdkjk42S/jm0A6v1Ri49etrVqGREl5utwkyilJsX00zQq62tYmp9zBEqk8tC0JnjbN69eSKKcY+NMHkzcsOCJFsuJn92kWf6K+GHjU4PSxENq7PPPrlBCZHr92mVhI0Sm9PsKnZqZNdlOzcxS0QqLfPB4dgvbb34XObxYBjZ39F4ef44MspDHVSGJ1lYWqxtHsNgadtAinI9CTuV3mLq1DcIvBABI/gmNpDVEIkoMByNJHIwkEVFi1jBysGWyuxzFanERP9p1rBYXsbsc1bEjSgzvN79B05qWFp18BDf80hkV6YyqfzvxCxWL7zDdvQXWsxVaqJzrNqk7F43JQuUcra3sRV5wtqKKJ1caRGsrqzcjtlE+bu6YegBww6+QU1HIqfpknfhJfP6wwyqRymNo8FRI7LQ7ZPrPTUlHiEyZDdsNJhPKE9voqKyvoZ/8LCcqAzEaiU5o439uKyQ7bJ6U3QL+FX6EyJTVqkedll6XEiLTo07LovNaA4uwvdTVQfmF7FbUTfnm9ZVjh60dtl2Xi0H5Sb3Cj4UFAPA6v886HscrbhB+trW08Z5kOSbS+REexw+uX34h4fPra154p7F7M6LEkIl34SeHRdjsCokoMSzNzzniBuUnLPQz8a5JlysNAgBEei9hbYftBTcov9+POxet25CqlwAAAABJRU5ErkJggg=="},"W4":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAAC/klEQVR42q2YMUhbQRjH/09EgpMcRUwpb0izipBKh5pRAkkXjZOlQ4eO4iBBpM3gEGqxwaHaDkLBgDSBonaKVCpdYlxEQcUiaEAHUwM+hIAEh14HvdeX9+4u9/ISOEi+7+53/+/efd9dHgCAEJ3++LVDCdEpXH5EY70wVefwNNbuIESnsqYihOcXsdwKb4W+ug60eiRsS++GqOqqW/vxuIzlNuhm9Wk86NXVGTIzw4hEY8LJJ+ePkf/+DYZxrqkIza6soryd4jI31vOYSO8qs7zoa+d1zswM4+fJY/RUQ1zY8lIWg8FT5BXzyDDOtdGROD3cTNbZ9+/5PeEQvoaBF0NxqhI004f1PDfoyfljoT5uwJFoDD3VELaDT5Douq3zpa878PIV8KeQ8lSI9qshDPT3In3dgUTXLbZ2DpTHRqIxYbAAMBg8FY5t4xk31u/WZtrv9E37gYH+3qaCZFzgbsG2dg64c6hwZNtZ5tPs+cG+zyVC0kkn0rt1W1Yl9wDgcDNpCrYugEoO2/WJAmM1QaqPEJ3Syxyllzk6+7qbEqLTRw8fcBuvbyOhMrZKlW6VPs2sfL9nkfmSMyeolIroDjzjTm73VUpFvF/1cVdSlS17wq3UZ+bwh7fj5v63bpVINIa+wBr6AmtcnyxfVNisbX4+g+xJyxjJhQKSCwVH/vL0adZVnIrXTMfH/F+kxsKIRGPwB8MAgPLJHfTp8zcYj/2vd6Knq8JWPYdlDFYLGE+mz1G0WLGaSO+i03fDnfym1glrP9lWZD4rmz0NK0+18HnV5wiYQayDeBXa2k+Uu9mVVYyOxGEY55qMrVrxW6kP9ss9rR7Ri71F815KiE4v9hYdNrf/oHhsN/dqr/raeNdAa742ujJKrpIOv4hdPikozdcKfVqjrcO2BQDYbSp5p8J2y/Wir10ETY2FHTnGszXzsXOa4Tarr010yPPupNZzcypeg9s3ECJ2pVQ0bXOJkJTrVV+77JBf/lS8t/jufye9vq0RsiulosPmlqGi7x+QJzmN9+47nAAAAABJRU5ErkJggg=="},"W5":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADI0lEQVR42r2YQWgTQRSG/y1FQk9looJSNwq9CiX1JkgOQRYpQSJYKpZCkVRyKAFDCRQk9BTSHopIoR4E7aFRsUipJUoPobTYQ+ylB0MRmq5eGptQeiihB8eDzLo7mZ1MmsUHC9k3s9/+s++9ebvRwBkhOkULVquZWrM5KkwVjhf6NB5W/ZZVhk1PjiOz5JOKVWGqcLzSp9lh2y978HblO+4P9CoB2dzg6E+hWDsTQFOuG8dLfZooXeZmJ5SA8US2aTraU1DGjSeyShFuV58wKrulDRRLFSnsqLylJJLn2o2/x4O7UaVF8xyRreWXhfo6ZRd96e1HsvvU4Zs5Oodk9yk+lrfQjhVLFdy8cd3ibRZ38D+sw+3pAED6UuOYyKdqjMsyZLO4cyaendOqaWepN3t9tNqadksbWMsvI2xEHMJbqWGmL2xEpOks1UeITulBjtKDHM0+ukgJ0WnP5fPCQzS3mVAZW6W3eqVPs/e3N58OrRuY61PQbz0V3pwfM9enXPuoKlsWYS/1dbDVT0+OAwDCRsSRKmEjgsH6MQbrx8Ix+7lbpNzYK4U9y1/NPAYhOmUHz5TpS6bSSKbS1rlMn0bLMQoA/mAeqWjdGny2+hszmTTCRgT+C1cAANVfPwAAfX1BjN/5t99llnyobht/U+bqC2GUeXbIGMFA6JpVy6zmGMcfzKNWM5X0sb2ALU6qj5ZjFIF5fC58xcLC4pl2vuHhIdwO9QP7Y/AH88KNghCdso1wpbCHQv6VNXZS77IEITAPvz9gXe+1PscTBIAu34klwm2njieyjnn2yDBjEbIvuMt3gpAxgtUP7xzseCLbEFk25rk+Uc0QolNKKT2smDT3+rlVV4cVs8Enuo6WY5SWYw3jD0efCNnM2DmfGV7q6+RTr1YzNUJ0yupV9dPL+r0/RvlIEaLTxfdLGLoXdewFzGT38lqfaxtgKWFPC97n1obcapiJ5TkqXK/0ub5Lz2TSDW9VIp/qh7zdz3NUuF7p65B9ZPOvbqyvhY0IUtF6y/8+uLHN9SnLNzc7IeW2q69pz2R9DABEftXPQxm7FW67+v4ASvkFNtXe/JQAAAAASUVORK5CYII="},"A2":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADpklEQVR42r1YT0hUQRj/7SqIBzsMXezPFgZdykMpreTBICmClPQShouhoDcJlGVx9xLt1ibaoYNRkRfNNSSRXXFRFu2g4MpbRFYPiqAuQoS4UB5CEKfDOuO8t/Oeb/XRB8uyM9/85vfNzPebbxawwAhx0MbmDkqIg8Jisxo732gio4HpdMrG/HZ3twAALgCD/b0nBqCHJTMRe2JshIrzmuFnelWNrLdviK84IQ46OaNQSiltbO6gueKKWDITscU5zfI7cYfZjm1u7+gSr6+pBhBEwOehuSyiDFfEMrMrufLTYkqP9Ob2DlY3UlanYxZJNseNm9cxNDaKZ0/qTQVtFOypcxgA3iTOY7ytWNX2+ONPjLcVY2V57UzBr26kUFleyvHmlCT+h9lljaORGADgx4srWX3attD3UdOTMVwAWFlew5ySlM4hM5ergc8l4uRqNj0F9fqDhgMDPo8q6Af3yuBq6cRgf6/NSJ0TSwpGIzHU11SriAd8HqmyTs4olGFPjI1A5JfJVfnCivykaUKIg8bXKY2vU1rVNEwJcdDiiyXSj+gbX88oqJFKn4RtRqUnZxRa1TScMz/mq8phQhw0urCF2akQAKDWCQDdqHUeSkmE43bua0ZVzWCbUfxa5yFmp0I58WO+yYibptMpGxct96tvqHWCH5NwfJpL/NW5vYw6VhZl9QHAopLAhUvXcP9hnZSAHvaiksgqMFR529IJABz7VnmZlN/digoAQKfXj/qa6ix+7Dff4XQ6ZUtG3BTo5p1rsS7A6c94PS3JfB9dB2uxLoTxmvtezjPemWTEDS32Yl4dXK4GAMDAQIgHJ9rAlx5Vezhul/Lr9PpVAWr5JSNunsc28egF338CAOz9SSPg86CgUH5r7f89gNcfRNE5AgDwtLdKBYIVCZ+/TsLT3sqFsCfgAwB+IkQxMrKz8FMFzIht//oNALhTdpsP0lPogsJ8vHzbh0fVFYjG5lWgWkzWzwhqsU9SVCv58SViYNHYPPb/HoCVb6LEJ5YUttYqknrGMMWVZ/kqYrP8ffchpFtiWsVPdSbYSpgt3zztrcDRMZNZNDafdaQIcVAtttlS0Qp+NjF/GTFCHFTMD7Yz2jbmK46VFRvao67FkeFqcazipyIi7oIsx7Rtor/Z96cMWw9XO84KfnbZgz66sKWSefHZxT6lNd3SHTRThGixw3E7b/P6g4Z/EpyVX75eoQCwO+/4ffHcN33m14oe9vEdaz81hhl+/wAYaXIZyevDbgAAAABJRU5ErkJggg=="},"A3":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADiUlEQVR42uWXzWsTQRjGnw0RESrI5lQPqScRtDkJDS20KKEKbUByaEH6D/QklBK2TQ4eEglBBS9W66UHbdiCQYiilFJoQGmxRUzqoVLJR4uFliw9FEtBHA/pTGcns9vdxJsDS3bn4zfPO/O+70yA/6woVg2q6id2Aw2jqjQzoYzbDOuf6lNVP7Erj57OktMmdMpthtWKPkUGq9UqKG/v2U6azS0gGdccr6Qd1w2rVX1emYuUt/ewUaq6ci2ZWLFNFEnnuHrtMmbfZHH3ToRYGS3qc+v6lOvhV20qNWfqfOvZGfRc7zQ9tI4WOk50IZ4pc6+NUlXKs9tVUZ+TImrwUNj+jtkdAACvAo0EoW7uxQr6B7tMUBnTxAXwbf07Pq4W5XNIjJXqc1BEfQohhOzvAPNvVzCqDbGOsUTKFpSMa+x9KjWH/sEuxqAC6bdhVBW6GGtfV5HNLSASDpmEW8Wwnb5IOGQbv7T8WK8AqDMUfXqZ9A924cLLCnb6OgAAE1EduWIUZ895pcCjw99Yf18x9aXuNqoNmd6psWJ/nn10+LvBWFX1E8OoKvr0MqEsO4aVPgBoX6pgf6SjbrCq+klNy2OnrwPtSxU8bvsEACjoHgSG/0iBYltB9yBXjLLzj08U1NjMWsZyvLjDVJMv1cvanTBkbWMH3cw2X6oXXgoOv0tjZiDI3KSgLwIAIuEQLh3E69mxLdHQxn9TweJuTUR1BIYhZdMyduM2fD0fCABQTfwC2DG6g0EAwHgsgUg4ZOZnfjGPqGn5k2MpV4wCA3ncH6l3nt+cRAB1A3Hlef33+DiY35wE9AcMnCtGLc9Qw6gquWKUAGnW38Q+jrkvq+eReZ2tV3x2xxiPJUwLyOubGQgy7wMAhaTLhLpOTcszl07GNdsYoUnNzYWBjnmYjDfwTEeJsMMyhlN9Ywfd4O1T+HipaXlcfHKzYZAsQ9PJZAnHymB+DM/mMyqNe5nRdgwrfT/vLTLbWE5QVT8h6TJRVT97CCGktLXL7qWq6ielrd2GOrd3YBlbdge2YrvVx9vGrpaGUVV8qV7CJwkn1ze3/3Lo7ols2Vx2OcGtPt425TT342PstLPT6S6LHLfcVvR5raA08/ExJqtrpoicZrjN6vPIVo/eUsSrWyQcYk+4M41mYljGLugeVhdLpGy5reqT7vBEVAfgOT7zTtaEntGtFCt2QW+sc8twou8vEq91CjnNBoQAAAAASUVORK5CYII="},"U6":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAADZElEQVR42uVXX0hTURz+btx8Kh2b9TKakCLzoREmyCVyZA97jfDFZBAIQuB6SXzJQTifJAcxJBSLwNSHpD8P5gKHqIWEtxHroRGboOJLzGEmBBO8PaxzPPfu3LO7TfKh87Ldc8/5ne87v+/35wL/2ZDMXtjtLk20MZvdlE4SeLn4ZDNjbxeHTY2FhoahxqCdFOlK8ElmxhZWosJDV5cSUGOZkj3N80wpNirFx/XwwkoUiqe3iMGeY/FMOWopRlY0ZNFL37lx7NdFdHNnNgLYr4sgXCZZI1jF6wGQ+GchIpvJQfEAcI8Bv3P6l7y5Mj1DVKR4AASA2zdvWSK9upT4e1EVEibxpcYyCKMH4Yj5RjWWoXvK8Yzi6cXVlktUMR/Vr5bjP3+2OWkSvzx8MmtsZPQeAOBJ5DnUWAanTv/kGjw8qAG7NpU8SkQi8qxnwpEeIDAO3zWxYtgkZ8QXX35tGR/BJbFkZ15N00272znYnFVcg7vbOTS6ffR58ukjAIC/uw8vno1IIuCBwXZKfHUpoVMM77I0TaOE/d19dP578r0QH/tudzuHVHIP2eymRAk3uKthc1ZRD8xPq/T5YW0QAPAwEwIApOMO+P2dR4QnZyhxSZK4pU5/43s69Rwe1Jh6eGdngxI1nvnj1yIUrwejobynm9vqoXg9OuyECyEsExmmki6tAdWYn1YBAOvpLTQ76wEAH5rW8qes5H+icxMUQPDBHaSSewAAx5uXMCNL1GNzVqEB1bA5a+ma4EA/xh6vUaWwHnU46nRebXT74Pd3Ijo3gea2ekr0KOPnsV/EBcqFkC1oPOx2l9Zyo5ZKTBTD7DpR3BZTTzru0HmPqIWnmOPAV0CYGGE38TI0u65YliakyVhPb1H5kTg+f/Y6AOCdQSWs7ePAJ5klF9IksCk+MNhekPatliTWO/HldIFHrLaZleKTeX2t3e7SrLRvpdTfbHZTUmPQCCh2BAf6LbeZleKTS2nOSTbMj5qyW0siZeKFBW/pvTEPCyl3onaVK2ljySC3aoyZUr6WRHZ588UuLjQ0XIDDii1ZVELYFpIUcHZ0dLVidqp4029ml8QjKSvG83h2Orpacf/ukOka1la+4dC3lpIomxprWLnfsjy7l6800f9fPn/Tzc9OfTK1K8JQDD8A/AH5qYlHGW0ZcQAAAABJRU5ErkJggg=="},"CB4N":{"s":20,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAUCAYAAADRA14pAAACA0lEQVR42u2WP0jDQBTGX0oRXM+SRYgIrYtWl26dC5aCS52Kk7MSIQ7tUGLpYJcOpR3d6tbqIApKR3EQdLHqJBQ72KmpnQQJnINeuPSveXebfhB4yQu/fEfuvjuAPyZl2guEaJS/t6y2IvpRninKk+qPEI3yKldrdPADIkxRnlR/DPZmvbsuEegoJpaH9eefBL26vh96FlpYFJrOnV4fAAAeHl+EeYzlRb5JzWgkDIv7JkQjYaeWKdk84QHf3DVh6fbcuedrrE4uGtJ4PEuKCNFouVpzXTJCi601GaFVrtak5AsQotG1owNKiEbV+SBV54OUfyZiUk3FHZ4IB+NPGQfzry+DffkE3e4rVI7rTs/UDWA9r3seIRrdfT6FQKPl4mE4WH9j13A2vu0koR3eBDu8OdTDKNBoQTIRg2Qi5mJ6Fe8vn85APp35lT//b4Jhb+vbWKUpNyP8zbqUEMwWDuWkNJsinV4fKsd1MHVDyJxltRXGYAnbTZ+ByFo2dQOSiZhTowe80wmNjX++h/0rpm6AqRswV9hAnX+l+yNEoyz2R9WiWwnbnkSOqRh/vknTD9PzopXgKuRKRdSUxvpTpsb/7AzYH5/fIfNTiwxYJhPDmhpafAJ6ScNxBnOlomPKstqK/fGJ/ssYfz74l/vopqbiThCoqTj6aDnIGzxqeuVi/X0Bva7kCFyUxGsAAAAASUVORK5CYII="},"ying_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB/ElEQVR42q1WMUvDQBT+UurWwSFm1kgdOoggtA11qKvXnyDioLgWzCCdpTgodHcpIvQPWHEQWqGidSjioEixdXGpGbo7nEO9crkml7vWB4Ek733ve+/lvrsAf2ZaNoWiBcXq4FVzqsTGeMf7DY1MIot5v6F0lkZm5Ydp2ZQFmJZN+UulQIYXsapNTcMfD0tULl753pUqhcgivEHPyO0s0/uLD9x13kQ3LVUK8AY9Q6URVX4jDHx+eeJ7v799BN0CxBx9rxWJNy2bEscN9NUfTifwgV+AET+tHQIA0s9nE8VE2X27Ob5neRZuW/hvM8KmsGRuaE9PlkMHr8Nv6G5nqktIhjUtm372XpBIJKT89euRDshWIZQ/FiYe4ri+CwDKxavIBlkO4rj4Pt4DcVzwgmTFL9qrUvHyOpDxx0Qwv3arZIgqGfrWtawJMcdufd6nB754cZIitkpqSHcOkO4coEpqofxxUXiv3cfxMyuAGe+LEu9r9xGpZBa5TH68gwAInHwQf6G+gnx+hG02mwC+AvkNce15g55hWjbNOJsYdH8AAFZyDu2Hxtgn0wLzMxH2vZaShqblj4clNrGOtjeaWirpAmgoiZiRpJJZrd1nWv6YyimoKmAZXmf71eE3ZHsw+/z8s8pJOssZossfeBIzIBes/If5h6G6Z8e0/L+CkZi8sKMi4AAAAABJRU5ErkJggg=="},"ying_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACDElEQVR42q1WMWvbQBh9Ms4/ULV0qoSXTIZAXaEOMWSTf0IQXrobosGYjMVkSMF7lyAC+QMOZAgkAYvEGUKmBGPkTF0U/YMM16G+4yTfSXdWPziwdN/73rvzve8ErMO0bALFEOXq4FVrquQ2+InFFaksUpazuCKkzkLq8sO0bEITTMsm/FARSPFFrOqituFvygqNB9Pcu9GkVykiS1eGFzgkjhLcPb0Wp8lo0kOWrgyVhajyGzLw7/OT3Psfh0PoCijWeMtmlXjTsonvhsK5y/vTDbzwH6DEj+0jAMDX518bYqoint+y37TOp+sZ/ncYsl34Yn7X3r2yGjp4HX7DtGzCT1QZTpQrKiyrU8yty9+Io4SBePP4bpgbADAeTHO5cZSAxxc94Lsh3u8O4LshiqZkR03C33G7uSHjb3qBgzhK4AUOE0EFn508AwD6wzZ4Y1GwFzhMhBc4JEtXBhVBPdAftjc8wYeM/8y/yOX1IeZvrFsf4ihhRC/LB0ZOBbwsH5gICs7SlcHj6e6MJj2GAQCvsw+vs1/WeoX8fMj4hefZtGzScbtIlx8AAKu1g/n9DZuTnWX+mZrwLZuVeqAuf1NqLuxhnp0CAHZbIYCbUgFFc+22vml1n235Gyq3YNFAureo7kedDr+w/b3//Pzv4jn+AwDgn1VuUpqviqnDX3keq/p91eeujvht+P8CtQzExSDvD8kAAAAASUVORK5CYII="},"ying_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB6UlEQVR42q1WMWvCUBD+IvYfpNlNcXHq1Dbo0D3+gYJ0c+gWaAbxB4QOCtkydCuFzIUIDh1aUGyKlE4Wkeou+QcdXpe+8Exekov2QAi5u++7797di8CfqZrOQDRZbJl8KiYltiI6lmNWCJIXsxwzdoiQQ/mhajrjAaqmM/FHKZDnJ3Opovbhr2YBOVaw867vtguLiLZrpXl9wqYP33j9+Eq6Wd9tI9quFYoQKr+SlXz/eLfzvtvpoWwBSYxNNCnMVzWdmYYt9Y1mg1S+9AQ48fvpLQDg7HOYKqbIpuFL/Mxxjp8n+G9TROVcnarprKa2MrsnxuZ1UsQo6v7B/OF8ES+IbAlFXzhfFO6DiEexffmrWYCOFcRj0Dy/RN9tk+9osTuiCMr+cJOdQOEIJYu3rm4AAK7vpUTIiuFHz8lEHNf3pEso4+fFdzu9nZ0URXCcSlJ1TW3Fhbq+B9f3+DUW+8t2j2OYhp37xS3Cl/lTI7SJJnCsAE/hENvVDwBAqx/BsYJYBHUExBHkTSgzRpSbT7oDfbcN07ARRgMAQKNuk3dANrOj2aD0DlCtmkXKu8afeRFZyyTD2EQTmIaNRv0izqfkZp2yjFvJu7+TgNQvqXiDAcBi9UbK3Ye/mqdUCC71DzM5bmVHpwz/L8BkgP6VjEAMAAAAAElFTkSuQmCC"},"ying_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACNklEQVR42q1Wz0sbQRT+VrYnr+NePLmSHnISBJNFW9bz+ieU3jx4C7jgD4QQKLHSlHor6M32T0jAQw/bmiWuoHhSRIwnL3GvPU8PdtKZ2ZnsbNIHgcnMe9/3ZvZ7bwb4a8RxKQxN5Vsk3hTTxHeKX7g7pbkgo3zuTimdZCOT8oM4LmUOxHEp/zNJkMXLsaabGoff1gE1a21hbvdwLTeJdNC3lt/P0/jkAT+vbuVlunu4hnTQt0w2Yspv6YKPv38U5tffbaNoAjLGY9rNjSeOSwMvVK51eq1MvPILMOKLhU0AwNL150wyeRYn0XDMcGZ+dPG/zZI1lQ76FnFcOkdWlKen8td1ER7jMe0K/rruU5TfBgCmtziJ0Om1aLPWFk6QkxANvBDLFZ/pcpjE1k4DAHCwX4eMyUuQOC6VNyHzV7xV+L4v8EfRKyQ9ZPht1SePkwgLjQ1REvWvwjoD4e3tm0UAjeEmeJzfAILkhZwVJL8R+cD+4QG/zi4z8mT8NtN8uVTFzf350OmaS5i3m/tzlEvV3JpgCck4cRIh8EJ0ei2h5mT+cPoIuHoZL00DEV4r+ZX6DbxQAAOAcqkqkMr6r3irAADf93GwX4dKw6pYXf08f5gV/s/sPSnbdqaFEceln758y1xE/Jyu/RWN0WEU4bdG9WB24vKc6V1QNG4c/ind7cdLiB83a+3ch5fqJp0jK8h7hozDL+hQ1bd1PX3Uaer6uFK3E/LbukJTEBV6ZY4qWpMYU/4/8jm/94FlGtAAAAAASUVORK5CYII="},"ying_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACMUlEQVR42q1WQWsTQRh9E3IpXsc9SrtSkApSEEyXVkmv2UD/gGgvXjwFugcJ2GPwsELw4KGeLELPQra0WGjUlLVKS0+RIib3uBd/wfRgZjs7O7M7u3Fg2TDzvfe+mf3eNwGmg1o2g+FQxRbBm3KaxFbEhcsDlkuSFXN5wNgsG5lVH9SyGQ+gls3ExyRBjpexppsqo1/VEXVavcRcu9vMTSKajMjqk9vsZPc3Pp//lJdZu9tENBkRk42Y6hMd+N2HV4n5Z49foGgCMsc4GuTiqWUz1/GUa0Hop/DKL8CFvy9vAQAeXLxOJZM3Tk778W/Oc/NogP89iO4UFuha4dPL4iiCL6JPyrSzrER0eNPSM9mgyFVRBXADuY6HP28+gdekbCxd7cs4VVdRJcsT4zo1Zz1+dPpVVQJi/W7uHSbqutPqod1tMvlEZezm3iGC0EfNWcf2y62U8N07tzBv30vwyBz1eh2PHt7/d5iNY6V+VWW+4a9vABC/AWCBriEI/cRclnH5if2dO8OXr2fo96/XTsNjbVmJ+t6NHeD8ek2lTVQ1GE1GRG5nvIVRy2bB/rTEGsm2KppvaXEFQeiX8k+evshTkcllgfcfnxM5xm00teYaRwMsLa6kOFXcKryJfq6JxZuQWjYLQh+dVg9PN94yatlMl4jqBi37x851PKzW6rG+63jY6QxT5s+9B8bRIPYAAPwY7hIeozLyrPeHqX7mTTwVZFLNsrxaFnFF+n8ZfT6uABeas49eBNnKAAAAAElFTkSuQmCC"},"ying_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACCElEQVR42q1VTUsCURQ9I/UPptm0qQk3rgKhHCxo0W76CdJORNoIDajtBJEWBu5ctIt+goILIYURMyhaFRE6rfX9h9ei3jQfb3xPpwsDw9x7zrnvvnvvAL+majqFpPFiV8HLcsrEJryOjx4VkiyL+ehRGucgcfWhajplAaqmU+8jkyDDB7Gyh1pHfyOKqFHq+L5dtc6ESZD5TMme79HR3RTDl/egm161zkDmM0XmILL6ShT49v7a9z2fq2DVBIIcDrGFeFXTqWlYXF933AzhuTfAhJ/2LwEAB683oWRENpoM3HfGs9W38d+mBHuKzGeKqul0Vz3iVo8XH7VFvBxR1Y+rnwCAcrWGxfDUR5jPVZBKZpBKZpDPVXy+xfAU5WotVA3Gw7gcYrvPMitXay6fjL43PsEjbJQ6GE0G2GkXsdMuYjQZIDhUMtYodWAaFi5epzANS3rXL+rbyKuFv/lTC1jUt7mx7gw0e8cA+j7nV7HNBf3EQuDrh3hMw0J33KQyi0B6Bnh9aBoW3j4ffYGpZAbdcRO8/o+aAe82yR6esHUYmoU4+hu8RAie4RDbHUKH2NCSm6GkRYdhSTjEdsV5+Dj6/B8Z0jCNtCv6V8kH6av1Vl9m/6+rnxD9AYNDKRpEEUccLE8/1Ivea+PtdFE1l+1wmQOsqh9qIQbkCEqtwF8cjepxka2q/w0WK4KA8VrAlwAAAABJRU5ErkJggg=="},"moon_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB/0lEQVR42rVWv0vDQBT+IhULdgwBt3KFCg4ODopQMOIgaAcp/jt1qCKOUgdB/BOsdKiCQ2mEQAmUDgoFhRYXFYpjFUXwOUjK9Xq5XKI+OEh4933fy937EUBhpsXItBghgsXB/AuXaTHqvxH130ibRMTw67/0EzJgECEAvPR7RhDZS79nzKUz1HnoAgCqdZd309ZaTomPo2+ImwTRMQsLIoxDhRex2cwMAOC++xyIH7uBq0YTE9sFqfjX2bnW9V81miPvQXxh2GymIOVTplCUQHUtLt/RaTjOkF3jgp2Xbm47tdAcVnHo4KPqG7pFxBeqzgeosKbF6KF3g1QqpdS/uKwBADY38nr6psXIvX0i02JULFdGFu8LC969faJiuUJ0sk/FcmUEZ1qMBoOBlEfU91od8lodpX5C7AB8wZSSdwCAnffZYTFV6y621nIkOwmRg8fxJ59m82MnKWJLyUOg/eNbTALHAfoJsQN47vXw3Q/AN94X1kU89xpLuRWsry4DAI73fvxpNq/E+hr5iyxs2wYAOI4D4FGqb8gGhWkxWlpexefUNABg8uMVXrMx9Kly0ff7hdh2alo19Ff6QzI/7/jnKL8BfO3E+Y3Q1Z/QnaTVugudYHSmeRx8kL50kJV2D8ZyXyf/ZfgFO4+2UyOd9htHX9mH+b79mzkQJfio+t/AUrCMAzsypwAAAABJRU5ErkJggg=="},"moon_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB9UlEQVR42rVWMWvCQBT+IpYKXUOgmyTg4NiliA4VKQ4tVKTQH1Ao9D9UB9cuYocu/Qm1OLiIiAqB4OJSsFBQnFoIWSuUQq+Ll17iXXJJ64OD3N37vu+Re+/dAQGmajpRNZ0ggsXBbIVL1XRirwixV0SaxI9hx7b0kzygiBAAHHuhiMgce6Fk0waZLecAgM7AZLdJpVQIxMfRV/xOPtENCwsijCMI78dmjH0AwOv8XYjfOIHe0ELivMoV/358kjr+3tDyzEV8YdiMUeXyBaZQlEBlLS7f3UM4TuEd48HRKdd5OuqG5nAQhww+qr6iajphF8M6Bs+XF5SIx+/7Z322TamaTsznN6JqOqm12p7B7oW1Oepba7UJebkitVbbg2VNpH9ydukZIv1kNm1gtpwjmzZc8uubWwBA47gHAKj3y+4aBa8xAODiHXuh0E5CC6/eLwcWoki/kWp6/Oolvn5i3btBe3dvaGFijl1xGsDEHLtBULBjLxQWT/9OpVRwMQBQLuZQLuaC7g6uPmsifW4+q5pODnNFfO3uAQB2Pj8wsYbuniiX2TktxOmoG1gD/6W/QUbznv2O8gxgayfOM0JWPyF7k3YGJmSCkbnN4+BF+tyLLG9dIJ8C7tfzRqoJWE3pICge+OWIYlH0Q/NR9iEnqgdZTFz9H5/x0Dumf6rEAAAAAElFTkSuQmCC"},"moon_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB20lEQVR42rVWu2oCQRQ9K4YUaZeFdGEFi5R2AQuDRRoLkfyEHyCkMCkSIQHLFDb5hDBsYWOxaGBBBLG0CCjpAoNthBDIpAizTMZ57QYvWKw759zXuXcWMJgfhMwPQoYMlgezFy4/CBndMka3zJlExoi/ffkvqoA6QgDY0LWnI9vQtXd6UmLLtxUAIIoT8TVr1qtGfB7/nnxIcrpjtiBsHCa8jC2XjgEAr6t3LX6nA6PxFIXLltL59zNxav9oPP3zrOOzYcullpLPKKEsgbpaXr7HJzvOE9u3oWvPD0JWqTWUhxeTIfgZm4xUHByvw/zL/2y+TKdd3iDiJvGDkM3mS+tWEflcLK//oo4wipNUexfnZ2jWq87rT6yOmIRtA4kmd2ExGdolJAffCn6HiFCyk4QqGN5+7kzkIZRg0OsYJSQHf3N9BQC4vXvYSYLzFOSsK7VGGiihBISSdH3x91mrxzna3T5MsrLxq94XVYMSxQnuu9f4OjwCABx8fiCKkzQJVwmIEnS5Q2TjlTdZUXfZtLt9DHqdtHKuM6DSLOfJEryrebor3DbEuhmQ/2t3+2kSttWrk6CqKJzLM+1wDhCfXb5lxOQBYJa8OGHz+DdWkR/OsgpVXcginaz+fwBICHOOTNYrOQAAAABJRU5ErkJggg=="},"moon_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACLUlEQVR42rWWvWvbUBTFfw7ulK24htKl2OChYwo1BjWWyZAlgzH9J7w3NAUlIYkhCRo6dAiUbl1LyOBFQ5CSGEQo9dihkNClFNzQrYEOrToEqdJ7T3qSSi4I9D7OOe/jXF1BRtTqjaBWbwQUiDKYW+Gq1RvB7DoIZtdBbhIRE39uS7+qAqYRAlzNLitpZFezy8qjh83g05cLAI6OJ/HhoL9kZOLL6FfESYKoFLpF6Diy8CK21bwPwOeLb6l46QYc12fu2UAp/uf9Ya7rd1w/0U7j02FbzYGSL9NCRRaaN8ryvX6rx1VUnlswV5STp95Y6XuVd1UcU28s2ed/9avxZHNcn4PRKhvra9K1Lfc69L0xQ8tmudeJ/Bgu4sXLLQD2dzcB2FhfS1x/iK/VG4G4CVH/zq+fmKaZ0Pc8D0DSr6q857g+dxcHgjcPE+MhSTwWnz4GtqJNxHk+/P4n3l8ypC+Kyuc3fHB69lHKk1C/CrC9s0fb6HI+OYkm/ThV++98ckLb6LK9s5crGUUex/UZWjYHo9WoT6X/fP4NTG/en8yDR0upr/Tv0LITZABto5sQFf3f7vQAME2T/d1Nyceif+Onr8qD76MHifY962tq/kml2371Tqqk8b6ssl8Ek8ZRRF/6IgwtO2qHJy726appGleeKlxUfy6tCsYtFH8/Op6gO1FVNV4wVzJxZfUTPoz7VvSsOKb7nUjLgazfiDL6qYmkKzi6DWgTToPJq/8X2GubvETuXi4AAAAASUVORK5CYII="},"moon_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACIUlEQVR42rVWv2vbQBh9Mtm6CkGXEGQwpYEMzmAMai3joZBoCE7/CS9ZEm2Ol2jT5g6C0r+gtMWDW0gbISURGA81gUKGQEKmFpTMGXNZKvV8upNOLj4QQrrvvffdj/fdATlN1XSiajpBibYIZilcqqaT+IGQ+IFIk7AY+lmW/goPKCIEgPv4RhGR3cc3ysu1Krm8vQYAjPyI7iY7HSMXv4i+wgYxoplWlEQRRx6exdaqzwEAV9d/hPjMChwHE1Tedrnij5++SC3/cTCZ+xbxFWFr1S6XL3cLlUlUti3K9+5DMU7hLWPdtLjBs3BcuIfzOGTwZfUVWROxZi1rQtmBy6wMzVXhBSRG6vVd3A1/oNd3eVVFaEIWR9f0vNKaJJboNJrt9BHpr/ASoE0ziC/mDDbyI+x0DMLOKIsdxBfwHBuNZhuDw/2M8PqLVazpG3M8LIdpmnj9ahMAsL0VcPW5VWganQJA+gaAumnBc2xMI0u6+oz8CJMTH2fnPxGGYfp/OgmE24rWP3j2Hpj966PzEZ4DCbGq6YTeAp5jp/+/fhv/nRUL7AwmBmwYLXiOvZB/ivRpngpLzgoc7e0qbMz2liU01ywco2G0Mpw8bh5eRr/QxPSJqGo68RwbIz/C4fAzUTWdyJ6k/3OJ6/VdvGk3U/1e30X063fG/EpRLZ6F49QDAPD941BJYnhGZmu47NlRVj93ALzLk8xljlfLyyZfVv8J7vGjAcZqjuoAAAAASUVORK5CYII="},"moon_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB8klEQVR42rVWMWvCQBh9CfYfWKG4FAWHji5FVKxYsEiHIoK/Qbq2iCCIIIjo1sGlP6EUBykKlSgVgkvo1KGgdCuoa4UuvU4JMX6XXCJ+EEi47713333v7gLYhD8QYv5AiMFFeMEchMsfCLHlhrHlhgmTWDHm51D6PgrIIwSA9XIh8cjWy4V0dhpmH19zAEBvNDUPs5tMwhbvRV+yJllEd8JpEk4cdngrNhI+AQB8zr+5+J0ODBUVciFPiv89PQu1f6ioW988PidsJJwn+Wwt5GaiouGV7+HRGSdRnoteXJPJ2rhP+p7yLsWhjfs79tlXX/IHQqxcqePu6g3HqVdjoDeaGq3LpmO4ySSMsdXkEp1BEq1mbasAnQfAFpe1WGsB5UodANBq1oT0zfkyVakOlgt5yIU8hooKp83N4ylV27h9n6NUbUP0OF01goirReM7rhaxagTJXKOAziBJepfyL5VrHrOO6xxuihAN0r+lahuz6WQr8TyRQrdxz7UENbFStW28Z9Mx7jG6j76Pmog2eoGmKsZm0sZ9HP3+wO4io4rRJ6GN++g2+PtgH33yGI1mcohmckbF+krOVEW4tebVp04fu3CjL7u5RXujqaOHRW5zr1hKf8eL5rZRZ7PTapo53HbAiz53M9ltNLc/ZKL28aL/D1r0baEA4e5kAAAAAElFTkSuQmCC"},"cb_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACD0lEQVR42tVWv0/CQBT+it1kcADCaIBoHGDRgE4FR/EvYILEhMGBycBMHCDMzDjxF1gHB6kupok62IHECJHBxEAHF0ZSh3J4PfvjWuPgS5r03vV937vefe8d8M9NoAeRWMIAAH06Fsg7MdqnT8eCGygbyxMTlF9kQTqjG5wlD41ir2Hxy5WWsZzzTKIzuoFyd81OGXKl5bkQv/yCXQLFXgNdqWTxn972wZMAjUGMYG0mMly7xyZPLeJHvGj3YVcqob3eR31uErfX++hKJchocZ/Nx1v1e7DECxTrYSE7536ztkoeAOrzEvabtV+Jjcb7MxHT27i2E7H4FkOd6/g4YfiJ98Mv8FSQoNXEKTYSSxhv42eEw2FXfvnqEgBQPDp25A85CSheLlgeACj2Gp4LJBjxcgGz8xPEywXQoiTJbyYyrgImnPS7HX+IDaYFpKWS0FJJi7jcFsFipF9HFlHSybN/ko3VUi/IPlWRfapCS7048ous+meqthqTBIjNVA2PnBVkpmqI5tLYlXLmcbgYrEqpWyzhP5a3kM/nAQCKogB4t+UXnLpg7qCAh08TbG8jDfV+wNWNyTwR4WKoc2koKL/oBDzZBhYXJvmkDOCeT8SEJJpLAwA+hgMu4QflD/F2Qh4Be3VS3hLqh19wq8Fk++kxz1XgNz3EL7/tVYIEruo2YPD+QX06Ftjv/TRAv/xfMDaBRVtnRA0AAAAASUVORK5CYII="},"cb_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACB0lEQVR42tVWv2vCQBh9UTeXDiqOxQrSIV0sRKcQ6eZ/4KRzByfR2Ulxdo5Q8C+oSwetXURoJwdBUHAQimbo4hjSQe96SXPJJdKhHwRy391770vy/Qjwz01iF4lUxgIAY7+RyD0x1mfsN5IXqRMrggmrH3OS9NZjNG5KVllv2fyjWsc67/kG0VuP8fr24tyyRrWO74ME1ZfcAijrLfTVis3/OB1CJACWgxjhus7cCX09Z/DMQ/zCx9wO9tUKuvEhmseTcDc+RF+tYISOcG5+TOc/izNfKKyPRdychXadBg8AzWMFhXb9omJj+f6siNnPGL1N2Hzm0hBKHx5HEHwQfSmRyljshlsH4XUTr67E43GevVQ/0luPKYgtoHRVs10AUNZbtrO99Rgs3lmI6aqGw/QB6aoGXmHy9JWiZrt4+rHGTYm2LkJKAl7UogAAWTepjwWTlkbwpFeX9RYtRFk3PQuTp/+cXdnOyTl3/Yix30iEhAgd5gsqTgI4zBc0CAI29huJxZO3M6p1KAYA8qqCvKpwU4KnzxpPX+JNQaWo4f3rRHR/JWM+m3hOY2cakSI0l4bQRA6rH+MRb3OAOTiJb6sAZt4BOIsrqcgAgM/lRKj7hNWPiE5CtoDCTlLRFhpE33USD3ZPQBZInteL7ArYrejazwgegDAmrL5vPvr1e7+/0SDDL4z+N8h7oNnVjRBuAAAAAElFTkSuQmCC"},"cb_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACD0lEQVR42tVWPUvDUBQ90WwuDqF0lDg56GCFdgt1EvoPCoUGujk4qZmdos5dpJCC0H8QEIf6sQVqF8FOFdxEM7g4hufQvnrzmpe8tDh4oZC8++65X+feFPjnotEXo2AyAAg/XjX+zIWehR+vWhqoaKtis6h/XQS5HPdxvLnPap4TO/dtl011mUFcjvu4f7wVVcy33cxE8vrXkgKoeQ7aVj12fvjQg0oAFIMLx9owd5S6JwZPkpiz15Mutq06ztd6OP2eOD5f66Ft1eHDVebm00Pw+zLFW8g2Q1aSDitnR7PgAeD0u47K2dFSw0bx/mSIjYLJeHuMgslWt4zYxWgUgupVqEAxqL3s/lL+g8EL41NuFEyW9OO6YPDCsipD8VRkUf+6DLDmOTMulqwyfFuN/2J1aBIqC4BLUgcyKSQGf73bAQA0hq25JJKC4a3nzihOY9jCe/dOmgT1z4M/OGkBAG4uOnNJcBw9KWvfdlFsVtEYtmIrjOtl1aA49A7HKTarQBfS+RGrLtNT7DkKRaMQNc9BeBVg8PUMANhb30bJc2JJqFCAUlC2x9OEVz5NdNkHo9isIupOMn1rAoHt5lpv0SjEJyYF8Lt3uWdAVXTZoJSsMp7IMw8iiz5UH43CCW3KwPvUXsVW1uUk31ra/hYBs3Y5/StAv6afwbOS7SL+9bRMZx8OgOVpq7hy81Inj/8fs2J2iFxwpBEAAAAASUVORK5CYII="},"cb_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACQElEQVR42tVWv2vbQBT+nGjz0kE2hi5FhUIGdzFUydBa6ur/QJNMu3XI0tYuFEJCIXI8dPJSXBwo+D8QhAyplQ5Fg7pkyJRshRJ7zRiug3LK3elOv9Klbzq90/u+d6f3vSfgP7ca+6A3DQIAq6vLGl1TY32rq8taFqgYWySmKr8mgowvTvDu8UvSmw05v9/3yO1ebhLjixMsTo/FLeL3vdyDlOWvyRLozYaYdB3O/yaYo0gCLAY1ivXIeFro64nJM4dIxWuyFyddB6P6HIPrmHhUn2PSdeDDK1ybURDePdziVYrNsTWZc3NvO0keAAbXDjb3tu8lNhbvn4pYJZb1DZ178eZ8pRSXSrgsxs35Sirm+/JrAEBrLgpC4BCkNxumPmPnvQm/75GWa6PTNZOapEkMPuzG5ba/gxTmXTz0pkHEQ4j85pYNy7I4/sWDBcKfSPFrsrqLghCvnCkH8HX+mtunIKy9eN4BsJscQsSJ3DjO73updiir+xgPOP0RpTRC+TUAODqYomG2sQzPpAmztgzP0DDbODqYFhKiiBMFIVqujT+H3xOfjP9t/QvwK14/qwMLPJHyS+u35docGAA0zDZHKta/uWUDACzLwmh/B7IaVg02mX6Wnx7y/B9/I3c46k2D6E2DjD9/I3Qt86n6d9kYFUYZ/lRHaLl28kxvXPQVHWZl46rwr6kmIFtC7Lo3GyLvRmXTdH1Dz4yrys/Voaxvq3p61m2q+njWT11Vfk0ltNTAAUiZCZkl2iIxRfn/AiUjpER6xwghAAAAAElFTkSuQmCC"},"cb_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACNUlEQVR42tVWsU7jQBB9hjQorYlSIWQa0BEaCkPBJabEfEEaElFSUABHGigoUDg6pDRIKK7yBRidDgknUJyClDQgRUIitUncUka+Ilmz3qxjbxAFI1n2zu68N17PmzXwzU2iB3JCcQHA6bQl8kyM9jmdtjQKlI2NEjMuf4wFOX+9w8HcuquXCz6/mS+6g7nQJM5f71C9/8tOuWa+GPoiovwSLwG9XEApnfX5d2oVREmAxiBGsGaVpUhfj02eeomh+BhvYSmdxVm8gsP3PvFZvIJSOgsTxci12ajVPwYDvLFiQ2yC51w52fWSB4DD9yxWTnY/JTYa78tETH/GyQXZ5+u1nEjlE4QhEi/CL0XpICIdJShepAuJ8HNLiIgomdPQvbhFMqf5/GECZOPIHHsFJUZ41FXNu4L4Y7wEaBGlmqc+cenlAsx80WV3lI1NNU9hGxbUVQ3HR3tDxD/mZzCrLPlwWIxMJoOfa8v95DcsLn+M1wG69ScA8O4AMLkgwzYs/KF8Yd1DLxew+DKF+4cGqtWq56//swLLiubfj18CzY+5bv0JDZGTmC4B27A8v3lzPdiVTbA7SMQ3raZgG9ZY+gnjp3EmWHCW4Pn3lcSu0Tc2A8XVazmYVlNDmDxsXnwU/lAR06ehnFBc27D65fBr25UTihuUyKhTVMTI7i+nVY8/mdOwZV4OiT/0HOi1HE8DAPBWe5TIGp6QP3t+ROUf+SvhdNqSDPhqjYxH1TIdJ9L/x+En9h85PJinyzOU3QAAAABJRU5ErkJggg=="},"cb_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACI0lEQVR42tVVPUjDQBT+Uru5OLQS6KDoIA51caiLlIiD0NGtUwrdHOxif8YWh5Y6uHQTWhC6ORZExBoX6VAQHIJDCw6F0mTtWOLQXrwkl+TSuvggkLt77/ve3b3vHvDPTaAHkc0dAwD0yVAg/8ToOX0yFLxA7bE8Mcvyh+0g9cELrnZPjFSzaJnvZKrGYs03ifrgBa9vT/Ylo5Op+m4kKL/ASiDVLKKRTFvmL5Q2eBKgMYgRrO2dA67bsydPbcIRH2Y5NpJp1NbbKEznxLX1NhrJNDqoctdmX+n9DhZ4S8X6WIg1eVS5NJMHgMI0jaPK5Upio/H+VMRuYlnbj1gcZ6ruKi434dIYJN5P8EH5QwBQKJWhKacWwLN8FtFEHNFEHGf5rGVNU05RKJWdp7zAIVgzVTc/z9splU08Hn7an1lCqWYRfaWH89wdznN36Cs9uAnLy1LNIkRZwsXHAKIsMW+JZdp1DK3RvTluje6hXceYvqaIbx6PATxbFh9us8yguS981p4dOKIsAS0YPC9ZoEZmPxlRlqD1Pi2O0UQc41bXtTmxTleUJfP/MJlwfQpX4Q+zEtn6AsaqbopwpurY2gDGHh2VtRmSxEzV0VmQs+JX4Wf2ge89QNyTzB2LsoRvAHjnv1r69MdqF0HKJgh/iLcLElH6CdEPY5VYFr+jFulrY73pbu85C8OvB3jF8vI7SogEOoQGcD2B+mQo2H2DlE9Q/h/7aW1fivuReAAAAABJRU5ErkJggg=="},"clyne_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB5ElEQVR42q1Vv0tCURT+noiTCIEIQYE8qq0HLoaQYQQZ9RanN2VL4OIW/Qetbi6N6tSukYEkOYiLw1sDESwFE3JpabkNch/3Xd6Pe58eEO7z3PN959x7vnMBzuIJlcDFvHzr7N0oP5ksCd0YT6i2NZksiWgSPI5oAWvzs+TTRo9MGz3CJyRbBMUQiZflV5wAzErNEVy7u8FiPlJEkgiKIRsbctoYK6TweHiMWCFlWwe1TWC4WdjNcb/367gWtffXjrXWCykpDDbWzxS3a6zmi7b/yu26UPtsAkMmVpEdVaIJeMXGEyoZj0xEo1FP/tZzEwBwdam78ofcBFTNF20/ADArNd8CKUY1X8T3wy2q+SJYUdLkk6rmKWD2Brz4Q3ww239GNgIjG7H1plcRPMZT78/W02zy/EnysUa2g/SwhPSwBCPbceUP8+Jpmn3rmyZAjfX5CbBp9qFrGZycn60c7ToAOJ68E7/eOkAulwMAdLtdAF+O/Arfe4v5SIknVHKUOcXW+BMA8JPcwaD/Zvm8tED9F9v7AICX2YeQhoLyh92Ar2O7KM/eVj2oZTAQFDEl0bWMVYCI8IPyh0RfQhEB+72kouNXht9xjPHXz377nSYbT030FoLwe85hdm6v8w7IPoAy/P+O951XkN7PAgAAAABJRU5ErkJggg=="},"clyne_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB8klEQVR42q1WPWsCQRScE2shoIKSQJCkjKBXiBAFMWgKGyur6B+wkzT+ADs7m5TGyt4iBkQSC7HQwjYgAYPCKcQmWG4K2WPv2PV2Tx8c7Lnvzcy67+MAm/mDEQKBHds7xfes/GS5I9TRH4xY1mS5I7Ii7DiyBziZnyVfdUZk1RkRuyDVQ1AMmXhVfo0HMG+2ueDRWgVbY6HJiHCLoRrr4Tn6ijG83N3DV4xZ1m7tHBgi84o2nm/+uGtZ+3wfmOtCMaaEwcY6mSa6xla+bPmt2n+VSp9zYKjEav5ghLAbToXG8+UBi3DsvqfyezbTGdhWRQuolS9bHgCYN9sW3810BjbeXoitfBmbjwe08mWIClPEn0hmLI+I3xvQ49hMZwjocVMEFVyqrwAA3UYY7JXS4IAeN0UE9DjZGguNiqB53G2Ej+a1iL+Usvp3fXx+z9ZYaBSEEvXmY5OcCujNx6YIGrw1FhobT/+daK1ixgBAOpdFOpcVpoSInzURPzef/cEISSQzuPj+AQD8Xl9iMh6ae6JcZt8fQ7cAgLf119EaOJXfKwJ+8l2huh4erjSaxMRBgL24CtGkeQCZzuOW3yM7CdkCcjuFZduvCj93kIX2dZRSQLV/eC+lBsBefrjQ+EP/Vj+ECr9jPjr1e6fPXpXh54b/Hy12vpvilU9tAAAAAElFTkSuQmCC"},"clyne_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAABz0lEQVR42q1Vv0vDQBT+WpwLQggUHCRYnAx0FMRFsAVd+g+0k1u3qpMgAScxWxc3066OBlpBBDtIoVOGQigUodKCCHZxPge5cLlckru0DwqXvve+9+O+9w7gRNMNghhJ0q1iu9b4ZLYk1FDTjdCZzJZENgkeR7aAleOzwefdAZl3B4RPSLUIiiHjrxo/JwLwbEcIbrYa+P6a5mSSyIqh6psXGRZqZdzvHaBQK4fOWWUdGHGyEae42PkVnmXl7fklOJ/WykoYrG+a5Niro9ej6QZpV+ohw2a/A1afRqU0DJH9SvGHo3Fk+vkf1Q1H49RhZPFkJGv8WAp5thNc5eHxEcxWQ3r7sN1hi5BZAFSqxVLou7eYpFOIT3735BoA4LtWpAhRMppukGqxFARjcXzXSqUQn/zt+RUA4PLuJlIExcnzVVeLpSBR37Xgu1awwqhetXsUo12pJz5qafgifYRCvcUEnu3g7PEBmx+fAICf7S14thMUIUsBloIq7wgV2nnlNWq2GmhX6mguXv87Z+5Lz4CIs81+R3kGMq1RlSGOmwH+P7oOk/gfNwNJTaFYsYPIOrDfMvufLR4Anrx3Kd8s8RO7yD4csqtQdAsq1FGN/wdXM4NxOLYd+wAAAABJRU5ErkJggg=="},"clyne_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACIUlEQVR42q1WPUsDQRB9J+kEqxgIdvGj8yAKhgMNCYJJkSZ/IPkD6eIHghACARE9bNJol6SytzCBgFyKYKHFtYJN0EC0EMF6LeIdu3u7udvTqeZ2Z96bvX27swBn0ViCQGKz5v4S+6/8ZPRJnMBoLMH4ZPRJghbB4wRdwJ/5afK3zoC8dQaEL0h1EQ5GkHxVfk0EYJstIbheLeNj8qIFKSIshmrunChwoZjE1fo2FopJxg9r/4Ehs4hs4mDlW+gHNavXd/1CMamEQef6mcbr6mPyokVjCdLMlZjASrftzvHxsoMqw5h1s6jyRwDA0ZzV66PSbRPbbHn+gm22oFfLpJkrIb2362rSKeLouA4AODutgccEMM3pthGNJQi/CJ4/ZWQx2lhm+FNfWTwM4eGPiLbN6vUxrtbYbTXrzLwDQlt6ZxNA3V0EjXPzuyPpvV3o1TKhd08mmykeYA0ePRJz+CMAcHjRQEE3cGsP3aA4VTBtt/YQBd3A4UUjkI55HKvXRzNXQqXbdsdE/Pvz18DT1N+aB+6xJuQX6reZKzFgAFDQDYaU13/KyAIAMpkMzk5ryMdXmdi78bMwV3Z+3htLzPfiyavnJ3muY6fZnF923MYjGpPd36o5MgwVfs+NQJ9+54/zY0GbmWpeGP45WQekJUT7ttnyfduIumk+vur7UAvDz+iQ1i2vWX7O7zkgOwOyvLD82qyG4tdwVJ69QeQThv8Hn8O/pCPNGbUAAAAASUVORK5CYII="},"clyne_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACFElEQVR42q1WMUsjQRT+VtIJVstCmkMWhQNxIVhIQCVycAkmTbprLv6B7XKWin8gjaS567LrwdknR1aRhKQIV9zBbRsQIZBALoWN9Vyhs86OM9mZmAdLZmfe+743k/e9WYAz07IJJDZv7S2+S+UnowdCHU3Ljo3J6IGoJsHjqG7gzfws+djvk7HfJ3xCupugGCrxuvyGCCCsNYTgTvUYs+mdoZLEohi6sSsix7VyBl+397BWzsTGi9oyMGSWki2cbDwKx6rWu76NxqVyRguDjU0yQ/Y31vOV2JwbeErlswwMnVhjkVaVVMO6Mbqtl8USaoCKqJ6v4N/FDehpyMTFC5CPY1si+8gSozy72cPokfGnRAmwNXjV8mO1GdYacKrHhD9RPvaq5cMNPOxmD3F2Wn1FvPX+HdZtJ4bDY+RyORzs7wAAikcdIX9KJKBmOACA6BcACulNuIGHAjOXJL6w1sD32T16/d/odrvR/K9BR1pWLP+X1W/An5e1poDbENXgbHpn8EKiIjItm7R+Np9PpQT+BAvpzafO42ThBt5C+kniZ3FWeHCe4JN/bvA+xaOSVFztyRAlJ/sKU4QtilfhTxQxexualk3cwENYa+DH53NiWjaRJTLvFtX9oKvnKzj4+CHir+croJ8VSvcALYX2ZBhpAAAu/wYG9REJmfpRa0+GWveHKv/cDfD1KHpX7eW6yevy/wdYFbGnSJIoigAAAABJRU5ErkJggg=="},"clyne_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB6ElEQVR42q1WMWvCQBT+FGcnEcQWirRDhwqOhbZLpeng4g9o+gOarZSgiwguQt2ydFT/QgcVHdShuBUXB6mLoKBCpVAcr4O9kMS75M74QLj43vu+d3fvewngsEg0QcAxN5+f2IPyk+ma0MBINGFbk+maiBbhxBHdgG9+K/ms3iezep84C5LdBMUQyZflD7AAhpUqEzz5/IjVYhIQKWJfDNncICswnE3h7eIK4WzKtt7XDoHBsxDP8XL6y1yLWq/VMdeZbEoKw5rrZQFnX60Wk0AkmiCGotoCtWbN9DnjeULlYbhNFln+IADouSKW3bQN8Obu1gyia+pbdtPQc8Wd06A4FEtr1mw/Xu/ruaKJJ8JvjWdqYFipotfqYFQuYFQuoNfqgCcsNxtWqjAUFU+fXzAUVXicLktxxDZ58zm2yWNZirtr4LVxDaBtc57rRWbSNhYevvYOjqGo0Jo1IjLJhDXA6kNDUfE+/LAFZpKX0Jo1sPpfRAO0DVij0A9/iFVI/WeKwXyM+9gZAKAxH+P75GinaK/N0CIa8zHwT87K98PPHKMP4WM8bK/bdpIDiau1nn5jPoZM28jwB0XfglSUXkL0wvCTy+Lf6UXrtVnN+r/XpwCNlb2Bffi5YnITmlcxvJedzKe0KP8fp1+Hzd20C8QAAAAASUVORK5CYII="},"prev_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB+ElEQVR42q1Wv0vDQBT+UlyspVAMIWNJoVMpLUhFlFK3UgtuLTgLXTIJ/gPFSde4OYt2EzR0s4QUdbHiH1BchKJ1qKCO59ILydlc71IPArkf3/vee/d+HMAZqmYQVTMIIo5FsAvzq5pByMQlZOJGEkLxURUQ5Y/JWCzqEfaMqBFR+BX2wKBTRbHRxaBTDYDpWrHRxfhtqPBIWCzF83BR+ZfChJ1lT3GY/AIAnHyuAMhECsXU2vH0rwtVM8g8I2SHMssLL8PnmYfTRl7Ii5YZ9+b1g/upA4DTQkYa7x+m9f0Hr4QJqRU+A2v2UxKi3vMrYbujSHhRfkW29IkoESaDYuktJxIJLv+NfQ0A2KnVQ/ljYQlomfHABwCDTnWugVSGZcbxfrQPy4wHEpIqnzby3ALgDyMef4wF9x3H22zqe2jqe9687zhcI1gZl6NzD8cqz3qSxTb1FEqPLZQeW2jqqVD+QBXqO840ZpMBBbw4dEcAHG74UAVsd4Talo7Ncnnqxq5XCHhYyl+/yaJSqQAAer0egNeZ/Aobe+O3oaJqBlnf2MbqzxUA4GN5Fw93t94eLxfoPk1C+ykplEP/xe8Ju2jnCO189F/mGXDRzknjovDHRDupSALz8DLKy/ArvBpMr98/F2lEi/YQGX5uHfbX7UX6gMzzQZb/F/PIh6v0s8mAAAAAAElFTkSuQmCC"},"prev_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACB0lEQVR42q2Wv0vDQBTHvwkuVigU09DBQSJ1ErEoiAoFwaGI4GS79S/IJPgPdNQ13Zw6tXVyKd1Eqb+mim4tBEdp66CgjufSOy4x19xdfRDIpe/7Pi+v7+UOmGCW7RDLdgg0bRrt1HzLdgj56BDy0dEKQvW6CcjyTZU3lq1I2Ef2JXT4Rtih2ywgV2yj2ywExPRZrtjGaOAbkyBhLdVP0unyZ0TBzperOEl+AQDOPucALGm1YmrjdHzXhmU7JO4lVM2IqsKr/xzpvOisSlXRcxNsfXD8MC4AUF1bUtbz5nrff/SGKMj+2mfgWespCdnq8Um0Om9aelm+Ef5b4wYuyjcqsChO2Hdavjns15iIH0DPTQQuAOg2CwHfYb8GXh8eRs9NYHi9B89NIGqwAUDE39zaDVwi/kw6W8awX0M6W2ZJ0IRLR9sAgMbFHfi+pOJ0tsySSGfLZDTwDZrE7c0N0wJg67CJ+KVML+DXWI/mm6OBb9AgFET7tnFxxxJodd5YElQ8GvgGr6fVyRXbgf7fyeexk88LW0LED8yAgB/Zz5btkM2tXcz/XAIA3mcP8Xh/xX4T9TK/pkPYekpOnIH/4v8JVq+sELrz0XuVY0C9sqKs0+GbsjspP0Ayu+k0BzgVvhkVZKH3glImxdalTAoLvRfpJKiej6FiKvzYfoz73scd5nSODir8Xyf7p9vRJ1ZNAAAAAElFTkSuQmCC"},"prev_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB6UlEQVR42qVWMUvDQBT+UgSxQkAMmSWFOlUacBM6hyK45Tc4ZBJcdNZBB5d08xdkcymZSwULhRSFQjoUxyI6tGDFKQ72hWtySe7SB4Umd9/73nv3vncBckzTjUjTjQglbRPsxvyabkTRvB9F834pJ4QvG4Aof0UmY9GKJPeIJlGGX0luCDwLpu0j8Kw1ML0zbR+fH1MljySJJXweriz/Vpazx3oHl+o3AOB+sQugVqoV947vVv98aLoRFSUhawqvCu/TV+7mA+NIqIquU42fTy9eVgUAOs2aNJ41x12m8AoLpEVNN6J2c7EG7o5UsOtFbURBdPuzFD4LsxH/YDiOBUJiSf5obTAcF4qS9SdiZfkzNRB4Fp57PQDASasF0/aFxx9bHTYJmf7nnUCuBlgiCv6w/gYACCeNVBK8YOjoiYz1E04a3B7m8VPwN1c2AOD61kslQX4qyazbzUUcaDhpIJw04jFG67LVIx+uU829E4r889ZTLdQdqQg8C+cPv9j/eQIAfO2cIfC24yREW4BtQdG7gDWqfJ5xNWDaPlynCsdVV5UbwLSXUvP5/7hnq/HnS2tA+h5IHm2RiLM0kHxH4zSv/7M0wC/KOn+mEFkA+yz6OUDJ010ggi3Dn1tF9uIQHYW8U5BpHVn+P7ZXfR8H+XYgAAAAAElFTkSuQmCC"},"prev_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACQElEQVR42qVWv2sUQRT+NlzjHQSEdTmxkQ2kO7lDMYScy6Y7lmB5f8VWEhGNEAKaEFPYbBqxs1tSWYQrw3iLSRFPtD9sgiHGIgemHYu7mZuZm/01edXszPve9+bNt/MGyDDbcantuBSGdhPsjfltx6X0qk/pVd8oCMObJlCUf67MjotWRPUpugkTfkt1GMQdtLo9DOKOBGZzrW4PlxdDK4tExTJ8Fs6Uv5IW7OPiPp7P/wMA7I1qABaMpHj70bvJqAfbcWneJsqapavCr+EPrfN990GhKkZhlX+vPTueFADYby6UxosWRtczeEvV1OXF0LIdlwbNkQQ+/D7P11R/nc5ZEof9c44X/dP+j7L8FQBcbwkhCKOxDhNCpABvX3lodXs0CqtY8TyuS5bEi5dbAIDdnU0A4D4AEfFaGan8S8uraPi+xP/31hFOvmKGn/8DYsIJIfj99KcUIPnckNanCU7Ne/IQwBbfhBjnAEAUNrDijQuhnoZasGk8gHw5lXMR+CsAsLEdI2jXJ8c9Puq7QsLSUfbPEbTr2NiOua/OWEJqnIQQRGEVYXTN53T867UPwLfx+uMacIRFLX+qfpl2mQXtukSq6n9peRUA4Ps+dnc2odOwDpvWJ/68uSd933l9NlOkmQuBNYq9958oG+vmsppMGUxajDL8VtYVxiquzhW5y3Wxyl6hRfjn0jqoKCFxPIg7uU8DXTcOmiPkPRNM+CUdirpVNauu5T0n0v6BNJwpv5XVUPIaTplndBH5mPD/B+rtrUwhxs8SAAAAAElFTkSuQmCC"},"prev_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACKElEQVR42qVWv2vbQBh9MpkcEASE8FSCAiWQEBxaMKapcbagGLyZ/A3lpv4Ym6Fju5XLUjp1ajy3wqRDjCKTdkhsQqcModDFtFkcqNfrEJ04n07y6XwgkI7vvXf36XvfHZAzHNdjjusxGI5FsAvrO67H2CRibBIZkXC86QJ09UtFdqybETlGdxMm+pYcMOzuYbvTw7C7NwPmc9udHm7/3Fh5IjKW4/NwpvpLWWQfHx7hlf0PAPDubhnAmlEprjx+G7/14Lgem7eJosNSZeHXzZUyeNXb0soiJeXku/X8e5wA4Ki6VhgvDkKnKbyVReJX72bmgpEN3eyJiwiisRFeV98yaX3zPFAUU9TsIldJFcANREkZf99/A8+mypwqE8o4sYOIT9bCuE6tvps8WfpLqgUMwjCZO75uJ++DMOSdIGVGGXt83QahU9Tquzh8/SIlvLH+AKve1gyPzNFsNtF4+ggAsO+fKvVTXWgQhnHd2kn9AoBfBQgF/KgLwFb+AXHjPGOfh3WEZxfo9/vJ/I/z08yyEvVfLn8ALgUfRGMAIXLPAU4sdwPeARzXY1+DL3FWWpAzyM3n71RA6NTIP/P0RZ6STC4LHBz+tOSYfb+Vaa5gZMPfqaQ4VdwqvI7+XBOLp6njeozQ6X05vNlkeYdR1ilscg+ipIwnjUaiT0kZv/vP8q8SqlIIRnbsgfvvTye3Fo9RGXmR86OIfu4G5HpUfev2ctOrg67+f5fCoTMFxoI3AAAAAElFTkSuQmCC"},"prev_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACC0lEQVR42q1Wv0vDQBh9KU4RCkIMgg6SguCgWCqIqBXBIYhzt25uZhJFnKQgiD/GuPkX9A8oGQQxttROLXYQChZHsV0q2PUc7IUkveQuid/U5L73vfu+e+9SICQUVSOKqhHEjCTYxPyKqhEyqBIyqMYqQvFxNyDKn4rSsehE/DmiTcThl/wJzbKObMFCs6x7wPRdtmCh/9WVwkj8WIoPw8Xlnwgqdr9wh5P0DwDg5nsSQCaWFKdWr0e/LCiqRnhNRA2JNYWP7iszeV5bFpqiacjO8/7Ry2gAwN1KJjLeHYY5HMNLfk31v7qSompkb+XbA6600s6aP5+lc7qJSvXTg+f5JSq/pKgaOT0r4Vh/xvT2g7PQLOuo2TYAYCOfR7ZgOWu9p13cWlu4ujz3NEDrAPDU8jfrb+D0rAQAuLo8F+J356dYR0XBbwdtvB20UbNtsIzJi2ZZh2nIOGy9wzRk4duodzGLuU7beZ7rtNG7mGXmOia+tbYAeKe2eL/EBP3lgrP2MFbHNGQY5v8aOVC/VLs09jZnYJjDQEmwpus240Y+H3idJuFnanJtfQeN+iOokSqtNOg7kenRDbnxYT5Iws/8DhRzDRRzMgzTPckGGnXxo/3DjG6i1hBRZBOFPyXyFXWbkmdEXo0kWBb/mBZZx+6XA++vRNAdLtJAVP5AM4UZTUTHvPufhxPl/wWZc3FhArj6qQAAAABJRU5ErkJggg=="},"atx_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB7klEQVR42tVVsWrCUBQ9CY5SOqSZa5RaELqIhnTStfULMkmoZBKXfkLHLtKpFEqnfkEtOOnkI4gOhUCFIl26qEPpBzRdfCZ5zXsxcSi9kCG599xz73s59wL/3KTgi6Jq3jag1WIu8XxxOXbBRuXIsM6b2zshuG23YglEOdp2yxM1kZRfTto9L1ZRNU9RNS+ugF1Pn40N3YBu1NG2W1henkYCD65H0I06HDKI9FO82bRC37vKq3+CgsJ4eGqPD/e/+EMNUEdndcyhGHGLD+JZC+cbJcaLYqSo6ymWSpHgmesKRfgX+AwvMK2tCTzR9FBUzXufvyCbzUoi/t7zEwDg/KzB5ZPZ7qkIzaYVeuiEiBMbzWE2LSyvLmA2rdBkocUfaidcLOWnJuKXWTAhxBdfQUa34PdICBE2webovH1vcGzx7K/AYruFPqpTG9WpjW6hz+UP/UKEEEzGji++dQHUgj6e0QImYwflig7DMDYTBEDkyUfxN3pHqNVqAIDhcAjgI5JfYmfrajGXFFXzdKOOz68FAGB/T4VDBhufaKNSPxUiq6c4XFJ+OZg4mDxfzGHmupi5LvLFHHhxPKGWKzrKFT2EicOl4ZdFQmJX/DbbcpdtnIZfuAfo9Qff08zxbXBp+YV7IBDs7bIHti0+Df8PQI1wHR8rRREAAAAASUVORK5CYII="},"atx_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB8UlEQVR42tVWv0vDQBR+CZ3FIckiCE2FCB1LCZet4F/RKQZKp+KS0dExS+lUBHXyf3AqLgmldAyYJYPgkmQQ/4E4lBfv4l1+dRAPMty9973vu7v33gXgnw+JniianjcBZUksiWx1MY7B8mL0ysbV+r4SvJjPagmqYizms7xqE2355ba7F/kqmp4rmp7XCTj29Mu+zA2YZAKL+QxS1+ICVc8Hk0xgG2y4dsRPbYdZXypvPydYIUyEx/H89PCLn9kAGm6ySwGFLxRP48uDjee3xlf5SLzrMYZDLjgKw8oi/Au8pGg6U1Rtugj68kSJ4pR9j+WXU9cqQHQRTm2H+bBD0L6pawGNpwOv1vcwtR1IX69gajvC7iLiN8mE+UT8PdXzIXUtUD0oRKDg5fX7IYcfz5nCQrDq+YUI1YM8S2IJRQRBUGABoJjzGgOPf3nxwtaRweeXsySWMAgS7XfbghwF7HfbQgSCsySWaDyeDvZqjEMIAUKIMCVE/PQQ8XPzWdH03CQT+PxKAADg9ESDbbApbKJcpudYiFEYNnqJu/LLdGA6+MDoQxSGEIUhDIw+iPzK62gbjU0YjU2uTXQTXfhl3knwCo4uoLo22PU17sLPbX/p3dmhwG4/DjlHzZv0cfRvijmGvzYf6/p93b9KG/Fd+L8BGNKeGo/YG98AAAAASUVORK5CYII="},"atx_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB3UlEQVR42tVWsU7CUBQ9kM7GofYDumDSTWNI3fgNptqEsIg6uDmzOai4EBLawfQ32GgaoFuJLH4AMhh/oC7e+tq+9/oKkzchAW7POffed+99Bf65NdgfumGmKqDd9qMh8lVxHILlcWhF52g8kYIH/V6lgIxj0O+lsiTq6jfrZi96VjfMVDfMtCqAQ6tffDZ3Am27g0G/h8/7Sy7w5HGOtt1BFM64fsJ3HTf3/7P+/ldBSWAiPFngT0v6uQTIcbs7FUjMhcGz+KLl+ea18bJntOJw6IaZrhaRdIB4x019LcNvkkQ6xIfoI1quU3JQPxc/5IuW68p+ZflUbF99TbYNwjAEANi2rbR9SICtMpuErPpFa1lW6fSk9wArRMFfnT0AALx4WEqCF4xumGnLsjIxlseLhwj8qTAJVp+Cv765AwC8vjyVkiCeZjHrlmVlgXrxEF48zPYv+etWjzi6jitdl1X8PL/GG7TReII3P8DX9xYAcHxkYDSeZEmotgDbglSEOm1ElZeZJrrtuo6LwJ/9Vq6tPAO8ng38ae0ZUDVNJEpVo+8UhGiYeBybJEHXcXF+0c7wKljRKfO0hYPII6za44RnNxgArBaREnYf/YZsG7CXk+oqlF1ydd9zVPR/ANmTRKy03N5hAAAAAElFTkSuQmCC"},"atx_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACEklEQVR42tVWPUsDQRB9kesEsTivsfIKFVKGeKygXP5GqhAIaYxaCCIKQVBCUPCzUSEEhPwNg0IWEe0OtNFKEJP/cBZycb/vLqncam9n33uzOzM7B/zzkWE/bMcNk4AG3+8ZnS2OYxysisMSjRdXN0ZwrVqJFTBx1KqV0HSItPoTaU+v22s7bmg7bhjnwLi3L+7lIuCRAmrVCvpby0rgzHEPHingkd4p7RG+WCpz62f2698NGhzT4aPRabckfe4AkWFjsKiR6GmdZ/Hi4Pl6qfGmPZYqdM9Pj4nDqMpnHf4tCKT94+pbbOFQStFpt7C2vglKKQcghAzDSwjhCsp23HB7Zx8A0GzU8RYEHCeLtx1XKmJRf3rKge/7nH632wUQSPrDFGIdppRirrjLEdDOIWePSNixupIDsI9moy7xfAFD8Vq1IkVPvLA/PuD+4Zn3hdG3AODy/BS5vMeF7oNxWAxvLu/h8vzUGOLIIZGHUopiqYxOuzVcU+lvTV4DL7/zpUmgi3mlfkaVh8VSWcrDXN7jRNkbtB039EgBAOD7PpqNOhayWSn/dc1IVQf9g1n+Bdz7jG+K0Vt+dHIbRnPVmq6o0mJ0HGn0pReBfYOjGxfXTJ3UxBWHG0Wf68RsF2VTiJ1fXN3Edk1VR17IZo24UfW5PGTzVsxZ0Rb3U6arAR1uVH1LV2gKocT/KnFFmwSTVP8HSPBy0XBoPhsAAAAASUVORK5CYII="},"atx_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACEklEQVR42tVWMWvbQBh9MtmyqhpD0JKAoIsxQoUEe7XzCzwZg/HkeKjplHTKFLIknhyD0CSPHZJ2KcWmJT5CsTdBvYQOJYPt/3BZIvl0utPZ8hB6ICzf3Xvvu7vvfSfgP28a+0c3TLoOaDl/0mRjKo5tsCKOHX6w2+unglvNhlIgjaPVbNC0RWyqn9t09bK5umFS3TCpKoBtd5+fGzsB2ymh1Wxg0fkgBL67GsN2SngkQ+F4iK/W6rH+a/3PagdTApPhw+Z7bkI/toBwoL08lEiMpcGzeL7F+cYb49PmaKLjObAsIXgWBKkmfAu8liUXs1QSVeBZq1AurRJUa3Usbr5HOakyaGhiHseanH1kgYU6tlOKHpn+jigAQsgqf6eD6J0Qgm6vLyyFPLY9HUSm+3z+MSFsHe5h33wf4+E5isUijo/yAIBKeSjUT9wDhBBMfj8CQPQLAAeWBd9zY30iLH+S//4+4+evCUajUcKIorRi9Tu7t8B0NSbSFt7Ey/mTphsmZVPA99yo/+u3+9ddOQG/g6EB8wUbvudm8o9Kn+XJ8eS8wM3lmcbPqZRPpOaaBQHyBTvBKeIW4dfRV5qYvVF1w6S+56Lb6+P00wXVDVP6KbDNTczzVGt1OI4T6VdrdQy+/EiYX1PV4lkQRB4AgIfhnRbOERmZr+Hr1P4s+tKPOSa/KJezVJXLLG6T+p9FP2wvcyt7FtJkAtYAAAAASUVORK5CYII="},"atx_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB7klEQVR42tVWPWvCUBQ9SuZSQV2c1MGCYymSghShQ3+CZAoBcShSB0HEoQqWUnBocRJBnPwNDkIpBR9SCl0CdbDdG6E/IR1KXvPx3ktipt4tuffcc9/9eg/45xKzfyTTOTMIaPf1EePp/HxEwbJ8SG7laDwRghv1mi+ByEejXjNFhwjLHw97ep5tMp0zk+mc6RdA1Oy7bR0VKMkVNOo1GK1TJjA1XKEkV7Amj0y9hVdUzfH/Ifn+l0FBYDy8JfPZ1MPvOICluNodcShW3ODteLc4/a1C40U2Eqt0ry/rwGVk9TMPv9F1j31UfgkA2p0+WhfPSJ0tKdFoPAEhBAAgy7JjeIyncwwXZdzdXjucWn4AUF9BNlC70wcA6s+P324f520CQggSzS4SzS4IIdhnOEfjCRRVw+XbFoqqBR5UY5BB1ejR76rRgzHIMG3pDAwXZQDOrH3f3zBBv7bw0S09fhRVw3w2Fa7RvS4yd2YUVfP04fFJCfPZlNsSrOzat4ksy3SP+81BGH6JFch284mNrqNQLNKePDxIC/uYdRgriI2uU3IWPgq/xAomX8giX8hSUiuTQdYcK/us7SOSMPxxdylFwzoaT3wHMeptHJbf04v2stnF/t/vQWbZhq3APvwS67Lh9GqYl6IZ9AUalf8HFS9Bg5z9Le0AAAAASUVORK5CYII="},"mith_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACA0lEQVR42q1WQUsCQRh9a3oQPG5ihyiWCE8eDIqiwwbhoQRB6BcUeLaL2E2IjkG/Q+ikHbq0gShdPCyBHkIKCZbsHwRth/XTnW1nnNn6YMCdmffe983MmxGYhp42XEhG2FwVvCynzNwY/djZPZAi0dOGu7N7EDp2XDp1oxbyH/pMAnracP2N+o5Lp66IfBGHKKLoa7ztubguMP1X5/cAgM+PkSa7xVE4VLGxILhWbwAAqlvfTAOAWr0hfVZr9Qa6HXvWqlvfmDweLiyc9HmcQf14cJJlWQCAk5tn8MZkwrIsJFfm32F8PBwAdDu2lL7GW4nMxhfT57wkpI7Pf3CoYDXV60zFAzysnjbc15GNVCol1G/ftTxzHxW5+r88QOYxyxmmkbEWFUgcZjmDyeUZzHKGMSQlv27kuFjSpxDpx4Jg/9lr5oto5ufVdzu2sIggx0m/xZxnf/LBlQxim/klbPcr2O5X0MwvcfUZE3c7Nob2GECCSYDCGxMHJTC0x8jmVrG37620desAQOjKh+kX25swTdNn3vdQfS149j4/Rhq9dm8T7+5dWy7gqfcwGxN5gcbJhM5LQspDUfXjPOLkygBOzxPP5gbSJiaRbG51WoAjZfyo+jGRkfwhY2ARXuX6VdHXRHcwbb//e9Fq/vUNUdWPh5EQcD5Z/h+mh2HnqzyAqvo/WpyDLqJM92YAAAAASUVORK5CYII="},"mith_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACC0lEQVR42q1WMWvCQBT+EnXobkSHUpAODsVBB1EUFMSlQ0HwF7i4FbuIbi4dC938D/6DLo0oSlepKEWE0kWMs0vBdNCXXtI7c0l9cJC7e+/73l2+9xLgaOFI3ISk8Xy9xMtiyviq9JDJlqRAwpG4mcmWuHu3d3XT70HOwW9LIByJm+ygtdu7unkK3A3jlPnhV0Svp/NUsa0/PrwAALablSL7iv1geI1VncGtdhcA0EzvbQMAWu2utFZb7S7Go6k1muk9jEHZ9eDEL8J08gedTrquAwBqz+8Q7cmYruu4iP3OeXiiOAAYj6ZS/IroJqLX37a19TIkJZ9zYHiJVcKRuMluuEmE58sDFuE4ff/LrxrDBtgqp+IpVqO2QYXF+hrDBth4FrjzVEGxGoUxKKNYjf4pSjIRfyZbsg0Rf1Ar9GAMG9AKPSsJSrh/f2Ppl9bYYK3Qs5LQCj1zu1kplARpmLTP0zQAiPj7qQ+bXy3G51e3m5VCIES0mH5Z5JTAYvplJUHB281KYePpdqjlEU4un0QunxRKQsTPmoifq2f62n0ah0SutAreJq/WnkjL7JyKcL0MnayB//IHRcAXsTnWkwN5Ijl3TcBZXInk5fEAa6nO45df5d0Er+DYAnJrgaKClW2/XvhVHkhzN0M/FbDm/VQAzd1MOgmKZzG8mBd+Vz269Xu3310vHz8//D8TT6mTtntJhAAAAABJRU5ErkJggg=="},"mith_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACAElEQVR42q1WPWvCQBh+Ijp0t5JOBXHolMVBbDooFBcHQegfqFs3XUQ7OegY6NKxf6Dg1kUoXMFaBCcptoMUiktQ/4FgOqQXz3iX3KV94SDJve/zvN8E+JVkKu1AUni6KvaymDK6MfqQyxelQJKptJPLF7l35UrNiRrIf/DvOZBMpR320G/lSs0JAg/DCJIo/JqoPG2rtPe91xgAANbLL022xFEwVG1jfuNmqwMAqGe3ewcAmq2OdK82Wx2MhlPv1LNbrF4uQwOn/CJMP3/cr0QIAQBc3b1DdCcjhBAcnezeeXgiOwAYDadS/BobPS1PMpV29MxmT9GeJ8Deh7VSGAZP/0/848lMOED+QRpPZqFtxOLJSFT+uAiwbZW8Mp5fGN4QyQwwmx02CJkFQIVXAZ5wiajzt4VXAECXmAdB8JyhpadkLE6XmCB9O7CF/M5f35QBAA/3TwdBUJyYP2o9s/Ec7RITXWJ6a4zeq2aPYhSqeuAWC8Pn3R+0kD1PoG2V8Py4wffKDeT0uIS2ZXhByLYA24I0CSptRDMfJNwZ6DUGKFR12G9uyc6MD/QattKvgVvuhbv++rbyDMhKXDQoNGv0mTohGiYehj1PoFDVcWbsgpCxFVWZx60F7W8/YNAeZ+3ZDQYAn9OFlG0U/nhQpDtltT9M/8pdLxeaevvJ8f8AvEh4J/eiCJgAAAAASUVORK5CYII="},"mith_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACQklEQVR42q1Wv2vbQBT+bJyhZFWFSvEiSvCkxVDjOC1nKF4yBAT9B5qldIspGJtCMBSHUHDpEkqHLN2zZfF0bRWFDu0gOmQoWUIhJPkPCrkO8cl3pzv5JPrgQHrv3vfdO70fAubiuD6Dpej2FvG3xbTZW+UPrXbXCsRxfdZqd7W2za1tVjaQ/8EvHcBxfSYurtvc2mZ54Msw8qQMf8X0eUbTnqSf9GcAgJur84rtJy6DUdS3qjoPhmMAwE7zVloAMBiOrXN1MBwjjpJ07TRvcf3l2dLAOb8JU+WvqZsopQCA5x9+wWSzEUop7j1YvOvwTH4AEEeJFX9Fjejm6rziuD7zHv2VNl7+Xklt6n5TFzFh5HWfovw1Md/iKAE9AhtNe5kbePEqwKQ/YyT0sL4RSHkpfvr9vV2omACwvhFg0p/BcX2mBqHyt9pdEEIyt//9FBn+NIXEA8dRgs7LEwng5GNHsnMQUZ4+aQIYp0GoOCTs8ECYWpC6lLnDA75++yHpRf4aABweHKMR1HGWXABYyRxYlLPkAo2gjsOD43SvTviBVJw4SkBCD/ToMtXp+F+vfgJ+3tkfrwIUa1p+bf6S0JuDLaQR1CVSNf/5cCGEYH9vV5v/Ol9T/Vy/fSi933/zJ3NJmXbMh8a795+ZOkhEnakFFvUxYRThz3QEEnqLwpnfuKqzHWZF/crwV0VncfqJKSQ+j6a9pcNMxeItNc+vLL+Uh2Leqjmr2pb9DphqwORXlr9mKrQsUbG/zLyitfGx5f8HhU2vHJwv7gAAAAAASUVORK5CYII="},"mith_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACPUlEQVR42q1Wv2vbQBT+ZOKhdBVCHVKKyGAoePFgnP5AhqIhDgRMPWbKkjVpwVjQgpeMgnYqnTsWTW2HZMi1NSod2kFk6GCyZBFx/oPSXAf75NPpzjopeXD4frz3fU9377szsDDTcig0TeZbJl4XU8e3xjrtTlcLxLQc2u50pWu9nT1a9UNugz+TgGk5lG9srrezR1eBF2Gssir8hup4/MDLzB8dHgMAri7PDd0jroJRNrYmBg9HYwDAQes60wBgOBpr1+pwNEY0idN20LrG7Ouzwg9n/CpMkX9NdCKEAAAGb86gWtMxQgju3FuOZXiqOACIJrEWv6HaCXvjb2Yumda1yuc2MMrEGlWuM50aLhNT9irlsWoyByYgt29j9vYEbt+GTFiyBPzAy8XJbhVZsiwxxtPudNOm4l+TJcDX34Dspv1oEsMPPBwdHlNxR8XYAdkFCRO0O128fvUiR/ywcR8PnGYGR8RwXRdPn7TmV+zWqZQ/J+JoEuNPfAGgvvidm70BkDBJ12QmCs8PPPybPcK3778yAvz541RZVjz/y7vvgd/LNT4fqQbYsV5dnhum5VC+BEiYpPOfv3xa7Mo2xB1k4ms010HCpJJ+ivh5nJoILhJ8fBcZok9va1sprmRaR6O5nsOUYcvidfgLRcxqkfVJmMAPPDzf36Sm5VBVInzcTf/YuX0bm4+bKb/btxF82M+Jv/AdSKb1hQbm47PowmA+MiHf9P3Q5Ve+xMv6ytYaG6+qZT6uzP1fhZ/Zf+AvpjC25gzMAAAAAElFTkSuQmCC"},"mith_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAACFElEQVR42q1VPWvCQBh+FB26W4kUKUgHRXBxEPsBEYpLhkKgf8Bu7WQX0UGwSKci9I90LqVDCupcQqUdUpcOPbRzOxRMB71rPu6Si+0LB0ne93meu7wfB6wslc7ZkDRebBS8LKdMbJw+VKo1KZJUOmdXqjWuTzs6sdc9yH/ouzaQSuds56LftKMTO4g8jCPI1tGPidLTGdRd3y/P7wAAH7NpTDbF63BExca94Fa7BwBolheuBQCtdk+6VlvtHsZDk61meYH5w2Howam+iNOrn/AGGYYBADi+foLIJ2OGYWAj8/vO4xPhAGA8NKX0Y94TfcymsVQ6Zys7365AYiWZzxsvmiIijqDpE1U/TlND00sDGqca8qUs8qUsGqeayzd/OAQv1ZSHchEr6Vqi2m+1e4xPRt8ZH+cRdgZ1jIcmit0Rit0RxkPT11Qy1hnUoeoKzh5foeqKdP/M+1tofk7Ye/Nzgnl/ixvLeuDq9gDAvcs5udjjgpaxCPHd+3hUXYFxA1tmkskat35VXcGL+eYKzJeyMG4IePUv6gFVV9jz7n6JjcOwPoiin+Bt5Ou9AGIR1oTESmJ7swCACOuYdxi6CWIlmTgP/xf9BG8zG5nnVbqJ408+R0qt8+8TiyBK2UTR911kQc3aGdRDGzGM4y9Ynr6vFp1p4830oHHo5Qia/2FYWX1fCVGgX1BuBC5x/MtOxqLq/wD75XlOi0bcIgAAAABJRU5ErkJggg=="},"drill_guard":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB1ElEQVR42tVWMWvCQBh9ETPVMWStvdKOjopDwUJxaAVdurS46i8QXLqKkNmlHaQUpGOG2iEIFUqRgDg4uIg2HbqIo50KvS7GJqeJl0s79CCQ3Md77+7yve874J8PySugqIQ6v+ezqRSUPAwHL1byAmudiWuucrIfeAGiHEGwUS+Sc/LhJgjxm22uyh+kkOcGdr5qocn157flBpTAfDZWeAOFuxIzcy+8kcvbOYBSKA4hE6vpKgBg1qsLm1iUgxcrbXM/O3hN6IdVVEKt6RCxWMxXv/34AAA4O83x6Ssqoc0hpYpKaL5huR5nbNvim0NK8w2L0usazTcsF05RCV0sFht5WH2zP6Jmf+SrH2FLl9M8utyCLrdcxtI6E88TZjkKnxcuQ9onHyeJtZNksbpcRHJQRnJQhi4XPfWjrPPHhvFj5OUC7DE2DOjIclWPsWHgIJtF4WgXAPCyjMdJwhdr6+fah8hkMgCAbrcL4H2jvsTm3nw2lRSV0FT6GK9IAQD2YMLsPa1ifrlox50G5PHQb+mvyOy8c74HqSBO74hUL179CE8bB+Cb+zz4MFcQP/2NjUy7ulnLfc3gX4QTr6arQK9Og/SAIPq+ddhZt8P0AdFbKI/+Nx3JbO8lSfTVAAAAAElFTkSuQmCC"},"drill_striker":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAABwklEQVR42tVWv2vCQBh9EZ26plm1yeY/IFIstEiXDsnSqQhCwf9AKC7dSsHZWUqXjs5B7NBBXR3aQUzTNWStY6+DfuklzeklR4d+EMj9eO/dJd/77oB/HppoQDdMxrfDwNOykqtwyGI1Ebg/XsX6uk0r8wLycmTBFkUkl+ZnnEDhNxNX9w9SSLiBg687ZfLRy8d2A3pmPsLm3oDz2En0POXeyNVDCKCjxJHLxEb9BgAQTO9zmzgvhyxW0w2T8YNJ9ycjbW4auYgnOVdZP1gzRiDdMNlwsWnbAz/28GM0N1gzxuN54uGCMXvgM/bWYfbAj2H5EOlf2NexR6RfrFYsvPorVCtWRH58O9kY6WxjPGfSi/oIvMUAQIQPA0+jEkgmdCa9naYU6Y9Krbgnz9P1C2HgaURCQkvXjcRpAUvXjRZB4DDwNB5PX6fbtCIMADiNMpxGWZgSIn0+RPqp+awbJqvVT/GOGgDgCHPMp8/RmCiX+TZvQJkTVVX/FxnlPf+epYLw3slTvWT1CzLHOAD0xyvILEaEV7mC7NJPPcjasxO0S8AhnYqlFjCTvwoQHvjhyBJZ9Pfm4756v+8mqXKLldH/BgCLkQAOdg0qAAAAAElFTkSuQmCC"},"drill_command":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAABrUlEQVR42tVWv0vDQBT+Im6OhqzFFJf+A1KKS+neLk6u2v8g0KUkRZBC/oM6iYuDg3MJWURKoXMXiZI1NKOr6aAvXH5ccnfRwYMMdy/ve+979967B/zzpfEEumEm7H4XvWuy4E0wRHU1nrLrBZkza9CWdkAVQ0b3kAdyYX5mARpcM2FZf5BCXAJHX7eNwZ9fwh8CujQe6SoTGD2McyePykQu73cAxo0wpItGN8ykM1wkneEiKZOJ4FVh/Lr99Wab/kjG8x/J1pttLQEWT2Sp2uemkOsFaR6OzluwBm3hm2S7BUtCposZ3UlmH63m1e8Aa4icd45bAAAnDgskypzRDTMxupPUGIvjxCFeZ30uCdY+OW/dXH/jTO8KJAjnIM/a6E5SR504hBOHaR8muWz0CKNn+5X1U4dfJi+kULSaw/UCPE2v8IEzAMAJ1nC9ICUhmgJsCqo8hhR56TZqDdro2T6iWR8AcGr7wjVQlrPWbK48jgjPQvmrrStiXg3kz3q2DwCV+c+rgaqgEBa3EFkFdl8XRZpj2Jf0bbkU0lWxXxlF+lmmFZbdguoUKmJ/D8PKLKevIO73AAAAAElFTkSuQmCC"},"drill_heavy":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB9ElEQVR42tVWMUvDQBh9kW5dYxaHQkr9A4JSQiWVkrmLk3t/gUUFJRTEWjK420lcHDOHEoOhFAf9A1Ihg4s6uLg2DvXi5XJncykO3nT3Hd97913ey3fAPx+KaEPV9Jhev78+K7Lgy2DkzVVEyc5omop1W1XpAxTFkMktiUB29c80wBKfmWB1/0BCwgLKs7Olwd0w+i5AlcYjuYULaF93mMhN4UL2rt4BdJbCEJqYZxYS0+qHAIDXyXlmjzUXGyeDh7HIrDL8Cm0YN4ww7u3AGU0zn7DdqKDbqsKwfbQblZSxVE2PD456AIBB3wYA0Jh0PlsEj3+r3oRpmin+IAhwP7nN8Jd4mnPDCKZREWrSDaMEhB7bjQ0AvaQIGudjhoS826rGbCE8zc/xgLvwIXMWwl8CAOdkiJpl4cnzfioe80305HmoWRack2EuE7I4bhjBsH2MeztJjMe/X74EHufzzTIQYJ3Lz9WvYfspMACoWVaKlNX/Vr0JADBNE4O+neiXDKJjXmPi+eftdC21Xj1+yVxSpi+omh6rmh47F9cxmfNiouYjmyPCkOHP/BEM20/W5MbZWN5uKptXhH9F1L5pCdFzZzTFohvlPQW0+uGveUX5U42MNiatWXruePkaDGty1gOLcvLyK3lffzIvS95N55FPEf4vDZBsiXQnDpgAAAAASUVORK5CYII="},"drill_sniper":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB70lEQVR42tVWMUjDQBR9sd26hoxaIgVBcHEopSg1lAxVsIuTexdHLXTRkkUK3QQXFxEdHFtQh1rbYgnFQQcHl9Kia62jq3HpxeR6Zy9XHDwIIf/uvff/5d7dAf+8KbwOVdMd7/dw0FeCkk/DIYpVeOByveeL5dPzgROQ5QiCDfNItvRPP8EUv5lw5f9gCXELiHwdTk1eab+NClAD8xGsdAHZ8xwVuZQuZPtsCCA3FYeUibVEAQAw6JSkTSzLIYpVJrmf1X5LhIcXNa9IcV6uGdYAsgMkiw28H90iWWz44pN2DxpH+uiHlxjRiSfW3IenH2Yl4DVQ9iPkM1a53kM+Pe/QM0pjsx8h2JaBeGINB/u7Y8KLC7OI6ks+HpojlUphdWUZALCeaTL1wyz3d2s1AHDfAKAlCrAtA93RuhTZOcr1HoZ3F7hvP6LVarnxh06Tu6y8+nuRE+Dpp69bq6ECk+8B8luHg76iarrjXQK2Zbjx65ur0axsgJ5BYryYacK2DCn/TNL38szQ5LRAdSeq0GPWMxtccw06JcRMc4yTxc3Ci+hPNLH3KFc13bEtA+V6D5vHr46q6Q4vEdYVQKaR2c+uzLn6yWIDp8/OmPkVkT2YeAAAXqo5hYxhGVmjPCJzhojoC99GiTj9/Ze32CD63wspZWQjXZ9/AAAAAElFTkSuQmCC"},"drill_special":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAABv0lEQVR42tVWv2vCQBT+FLeu4uIgtbi7lqCDhJvr0KmLk0tnsQ4SQqUI6T9RunSrY5EQEZHYzb2k4Jq4diu1g700udzl19Ghbwl37973ftx97wX451IQKcqV+iG43rvvhazgMhhpbQsiY8N0QnsD9SxzAHkxstiWRCCX9Y8wgMQ1U6zBHzwhYQInX3fS4LPV7ieBcmY8aps7gYvHPrPzlDuRq4c9gL4UhpDEPLLQvcr5DQDAtacRHUsuEU4Qg/eGZf0XAWA40uEt1RCgYTpoEIIGIaCEojpvqWI40iPVoDjeUvXPuvbUD0Akw5Hu46XxHzxf5AEapoPZaodmt4Zmt4bZage2K6QRw3SgaBaut8cvWz2ReJMqepu2v+5t2vAm1XgO3L+0AJgh5faZT6TjWSTozAiOollY651DnpkSO8jYyiiahbf5PHSwQQjWegei4cKrrqJZv02hVRP2cxn/JV4gn/NbuPYiRKJTvMZORF4yNAjXnmIdM1Fl/HPbaImMoZCxn7FfSXuR+mqD1Rd1IGFvz+C/mDTCWVImETEJQ8aW5z/yFtneSyWpn/Mwst5AHv9CMsURLSmYvH+hefx/A2yuQ0wW4J1aAAAAAElFTkSuQmCC"},"enemy_grunt":{"s":16,"img":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAQCAYAAABQrvyxAAAB/0lEQVR42tVWMUvDQBT+UgoOgnRoK+KWQcgmOEjJ4BXcWnAVf4E/QGudQidrlc79G5UK3UyGUBSEboEM3QradlDBOQ7tHZf4klxbFw8K15f7vvfe3fveHfDPh0YZ80U9oOyzyUhTJY5yrINN4tAo8LR5ThIX6h2lQCiOQr2jlMiy/jVVsGoSaRxJ+FX8Z/67BrJUhoelMnqb2yF79fsdz4MnJVK/74i5aXsAQHKmYVdKwGUGusNX3EXsRwDazBABqY5abms+8X5zxo3ucEzaT/Z347uQrPxabgutj69fgci2NB0kBUhhKcxhqQwA5MlzjowsHpcZAIDL+hlcZoR+l/UzcULT5nlskDKXywxMnWOBkdfI+Kh/HjxjDIwxkQjlP0vVnt93sNcIH5dvOal1ygMJcVnzcrj/3AkFMt9ZBHwno5y9ig/ABwBcVIDCgNaJSOChdIrbG0t8uDt5IevPtD1cXTcA20oUYXc4DmGi66NlFPVffdzDkfcKAHCMAwBj0r9IwLZtQWzaCFxJsHw+m4y0fFEP+FqqLk0bAReuLMa0C0z2ny/qQXvjDeZCc+7GG0zpm+w/y0HycaYJMGntbDLSWtADXs888XU4k9ZmojsUdxvKwlnnJk7rTMv6J9sZLwHeNuX/Km8Z0fsXQwW3qv/EfizvyjKvyr96iar4/wHM7HXq6HB7tAAAAABJRU5ErkJggg=="}},"byMech":{"B1":"B1","M1":"M1","CB1":"CB1","S1":"S1","W1":"W1","A1":"A1","U7":"U7","B2":"B2","M2":"M2","M3":"M3","U2":"U2","CB2":"CB2","CB4":"CB4","S2":"S2","S5":"S5","W2":"W2","W3":"W3","W4":"W4","W5":"W5","A2":"A2","A3":"A3","U6":"U6","CB4N":"CB4N"},"atlas":"data:image/png;base64,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","atl":{"grass0":[0,1,1],"grass1":[1,1,1],"grass2":[2,1,1],"grass3":[3,1,1],"grass4":[4,1,1],"grass5":[5,1,1],"dirt":[6,1,1],"rock":[7,1,1],"rockB":[8,1,1],"bush":[9,1,1],"treeA":[10,2,2],"treeB":[14,2,2],"boulder":[18,2,2],"hole00":[22,1,1],"hole10":[23,1,1],"hole20":[24,1,1],"hole30":[25,1,1],"hole01":[26,1,1],"hole11":[27,1,1],"hole21":[28,1,1],"hole31":[29,1,1],"hole02":[30,1,1],"hole12":[31,1,1],"hole22":[32,1,1],"hole32":[33,1,1],"hole03":[34,1,1],"hole13":[35,1,1],"hole23":[36,1,1],"hole33":[37,1,1],"cliff00":[38,1,1],"cliff10":[39,1,1],"cliff20":[40,1,1],"cliff30":[41,1,1],"cliff01":[42,1,1],"cliff11":[43,1,1],"cliff21":[44,1,1],"cliff31":[45,1,1],"cliff02":[46,1,1],"cliff12":[47,1,1],"cliff22":[48,1,1],"cliff32":[49,1,1],"water06":[50,1,1],"water16":[51,1,1],"water26":[52,1,1],"water36":[53,1,1],"water07":[54,1,1],"water17":[55,1,1],"water27":[56,1,1],"water37":[57,1,1],"water08":[58,1,1],"water18":[59,1,1],"water28":[60,1,1],"water38":[61,1,1],"water09":[62,1,1],"water19":[63,1,1],"water29":[64,1,1],"water39":[65,1,1],"abyss0":[66,1,1],"abyss1":[67,1,1]},"cols":16};
  const hasImg = typeof Image !== 'undefined';
  const img = {}; let pending = 0; const waiters = [];
  const done = () => { if (--pending === 0) waiters.splice(0).forEach(f => f()); };
  function load(key, src){ if (!hasImg) return; pending++; const i = new Image(); i.onload = () => { img[key] = i; done(); }; i.onerror = done; i.src = src; }
  if (hasImg){ for (const k in D.spr) load(k, D.spr[k].img); load('__atlas', D.atlas); }
  root.MechPixel = {
    data: D, img,
    ready: () => hasImg && pending === 0 && !!img.__atlas,
    onReady(f){ if (this.ready()) f(); else waiters.push(f); },
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
/* ===== PIXEL END ===== */
