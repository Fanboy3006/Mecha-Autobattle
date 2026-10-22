#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 美术测试（方案第 9 节 M5 的验收 · 美术侧）
 * ----------------------------------------------------------------------------
 * ★ 2026-10-11 从共享文件 `tests/art_audio.js` **拆出来**（`协作\协作框架.md` 第 5 节 A1）：
 *   本文件 = 美术那一半（**美术线所有**），音乐那一半在 `tests/audio.js`。
 *   拆的原因见框架第 9 节的事故记录：两条线共改一个文件 → 美术线把音乐线**未提交**的
 *   `tests/art_audio.js` 一起提交 → **HEAD 自己变红**。拆完两条线各管各的，事故点根除。
 *   **段号 [1]–[4] 与原文件逐字相同；断言一条没删、一条没放宽**（方便与原文件逐条对账）。
 *
 * 检查四件事：
 *   1. ART 素材（`art/mech-icons.js`）真的注入进页面了，`MI` 的接口齐全（build / draw / makeSprite /
 *      ICON_BY_MECH / FACTION_PAL / ids …）；
 *   2. 能按机体 id 画出图：图标库里每一个图标（v0.7 补完 42 台后是 66 个）、
 *      我方 34 名 + 敌方 29 种机体，画的时候不抛异常；
 *   3. 图标层（`78-图标.js`）的挑图规则对：有专属图标用专属（v0.7 起数据里 63 台**全都有专属图标**）、
 *      没有的按战斗分类 / 体型借原型、再挑不出来**退回势力色方块 + 短名**（不报错）；
 *   4. 编队 / 战斗 / 招募三个画面真的画出了图标（含「同一个图标只画一次」的缓存）。
 *
 * 不依赖 Playwright：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来（和其余测试一样）。
 *
 * 用法：node tests/art_icons.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);
const 不炸 = (说明, fn) => { try { const r = fn(); ok(说明); return r; } catch (e) { bad(`${说明}（抛异常：${e && e.message}）`); return null; } };

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
const { 图标, 界面, 肉鸽 } = G;
const MI = G.MechIcons;
const 屏文字 = () => String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
console.log(`美术测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/* ============================ [1] ART 素材接口 ============================ */
console.log('[1] ART 素材（art/mech-icons.js）注入成功、MI 接口齐全');
if (!MI) bad('页面里没有 MechIcons（ART 块没注入？）');
else {
  const 接口 = [
    ['VERSION', v => typeof v === 'string'],
    ['PAL', v => v && typeof v === 'object' && Object.keys(v).length >= 7],
    ['FACTION_PAL', v => v && typeof v === 'object' && typeof v['影世界'] === 'string'],
    ['ICON_BY_MECH', v => v && typeof v === 'object' && v['B1'] === 'B1' && v['猎犬'] === 'hound'],
    ['ROLE_COL', v => v && typeof v === 'object'],
    ['NAMES', v => v && typeof v === 'object'],
    ['ids', v => Array.isArray(v) && v.length >= 20],
    ['build', v => typeof v === 'function'],
    ['draw', v => typeof v === 'function'],
    ['makeSprite', v => typeof v === 'function'],
    ['platePrims', v => typeof v === 'function'],
    ['shade', v => typeof v === 'function'],
    ['mix', v => typeof v === 'function'],
  ];
  for (const [名, 试] of 接口) {
    if (试(MI[名])) ok(`MI.${名} = ${typeof MI[名] === 'function' ? 'function' : JSON.stringify(MI[名]).slice(0, 48)}`);
    else bad(`MI.${名} 不对：${JSON.stringify(MI[名])}`);
  }
  const 关键 = ['B1', 'B2', 'M1', 'M2', 'M3', 'CB1', 'CB2', 'CB3', 'CB4', 'grunt', 'hound', 'drone', 'fortress', 'flagship'];
  const 缺 = 关键.filter(id => MI.ids.indexOf(id) < 0);
  if (!缺.length) ok(`图标库 ${MI.ids.length} 个，关键图标（${关键.length} 个）都在`);
  else bad('图标库里缺少：' + 缺.join('、'));
  /* build 返回的是绘制指令数组（方案 8.2 的用法：MI.draw(ctx, MI.build(id, ...), size, x, y)） */
  const prims = MI.build('B1', { pal: 'ying', plate: 'none', size: 68 });
  if (Array.isArray(prims) && prims.length > 10 && prims.every(p => p && p.t)) ok(`MI.build('B1', …) 给出 ${prims.length} 条绘制指令`);
  else bad('MI.build 没有返回绘制指令数组');
  info(`素材版本 ${MI.VERSION}；调色板 ${Object.keys(MI.PAL).length} 套；战斗分类色 ${Object.keys(MI.ROLE_COL).length} 个`);
}

/* ============================ [2] 按机体 id 画图 ============================ */
console.log('\n[2] 按机体 id 画图（不抛异常）');
const 画布 = page.sandbox.document.createElement('canvas');
画布.width = 68; 画布.height = 68;
const ctx = 画布.getContext('2d');
if (MI) {
  let 画了 = 0, 失败 = [];
  for (const id of MI.ids) {
    try {
      const 调 = Object.keys(MI.PAL)[画了 % Object.keys(MI.PAL).length];
      MI.draw(ctx, MI.build(id, { pal: 调, plate: 'none', size: 68 }), 68, 0, 0);
      画了++;
    } catch (e) { 失败.push(`${id}（${e.message}）`); }
  }
  if (!失败.length) ok(`图标库里 ${画了} 个图标全部画过一遍，没有抛异常`);
  else bad('这些图标画不出来：' + 失败.join('、'));
  const spr = 不炸('MI.makeSprite 能生成离屏画布', () => MI.makeSprite('M2', { pal: 'moon' }, 68));
  if (spr && spr.width > 0) ok(`MI.makeSprite('M2') = ${spr.width}×${spr.height} 的离屏画布`);
  else bad('MI.makeSprite 没有给出画布');
}

/* 数据里的每一台机体都要能拿出图标（要么专属、要么借原型），一个都不能漏 */
{
  const 漏 = [];
  let 专属 = 0, 借原型 = 0, 方块 = 0;
  for (const t of G.ALLY_T) {
    const id = 图标.图标号(t.mech, 'ally');
    if (!id) { 漏.push(`我方 ${t.mech}`); 方块++; }
    else if (MI.ICON_BY_MECH[t.mech]) 专属++; else 借原型++;
    const html = 图标.卡(t.mech, 'ally', 28);
    if (!/class="mic/.test(html) || /undefined|NaN/.test(html)) 漏.push(`我方 ${t.mech} 的卡片 HTML 不对`);
  }
  for (const k in G.ENEMY_T) {
    const id = 图标.图标号(k, 'enemy');
    if (!id) { 漏.push(`敌方 ${k}`); 方块++; }
    else if (MI.ICON_BY_MECH[G.ENEMY_T[k].mech]) 专属++; else 借原型++;
    const html = 图标.卡(k, 'enemy', 28);
    if (!/class="mic/.test(html) || /undefined|NaN/.test(html)) 漏.push(`敌方 ${k} 的卡片 HTML 不对`);
  }
  if (!漏.length) ok(`我方 ${G.ALLY_T.length} 名 + 敌方 ${Object.keys(G.ENEMY_T).length} 种机体都有图标（专属 ${专属} / 借原型 ${借原型}）`);
  else bad('这些机体没有图标：' + 漏.join('、'));
  info(`专属图标 ${专属} 个、按职业 / 体型借原型 ${借原型} 个、退方块 ${方块} 个（方块是兜底，正常不该出现）`);
}

/* ============================ [3] 图标层规则 ============================ */
console.log('\n[3] 图标层（78-图标.js）：挑图规则 + 方块退路');
{
  const 例 = [
    ['B1', 'ally', 'B1', 'ying'],       // 影世界近卫：有专属图标
    ['M2', 'ally', 'M2', 'moon'],       // 月球王国重装：有专属图标
    ['S1', 'ally', 'S1', 'clyne'],      // 卫星国防军特种：v0.7 起有专属图标（原来借 CB3），配色还是自己的
    ['U7', 'ally', 'U7', 'mithril'],    // 秘银特种：同上
    ['W1', 'ally', 'W1', 'prev'],       // 流星小队狙击（流星小队 → prev 调色板）
    ['U6', 'ally', 'U6', 'mithril'],    // 秘银狙击
    ['hound', 'enemy', 'hound', 'enemy'],
    ['bluefish', 'enemy', 'bluefish', 'enemy'],   // 蓝色大肥鱼（3×3）：v0.7 起是专属图标（原来借 flagship）
    ['swarm', 'enemy', 'swarm', 'enemy'],         // 蜂群无人机（飞行）：v0.7 起是专属图标（原来借 fighter）
    ['grunt', 'enemy', 'grunt', 'enemy'],
  ];
  const 错 = [];
  for (const [键, 方, 想, 想色] of 例) {
    const id = 图标.图标号(键, 方), pal = 图标.调色板(键, 方);
    if (id !== 想 || pal !== 想色) 错.push(`${键} → ${id}/${pal}（想 ${想}/${想色}）`);
  }
  if (!错.length) ok(`挑图规则对：${例.map(e => `${e[0]}→${e[2]}`).join('、')}`);
  else bad('挑图规则不对：' + 错.join('；'));

  const 有图 = 图标.卡('B1', 'ally', 34);
  if (有图.includes('<img class="mi"') && 有图.includes('data:image/png')) ok('有图标时卡片里是内联的 dataURL 图标（<img class="mi">）');
  else bad('有图标时没有画出 <img>：' + 有图.slice(0, 80));
  const 缓存 = Object.keys(图标.缓存).length;
  const 再画 = 图标.卡('B1', 'ally', 34);
  if (再画 === 有图 && Object.keys(图标.缓存).length === 缓存) ok(`同一个图标只画一次（缓存 ${缓存} 张），第二次直接复用`);
  else bad('图标没有走缓存');

  /* 没有对应图标的机体：退回「势力色方块 + 短名」，不报错 */
  const 兜底 = 不炸('没有对应图标的机体退回方块 + 短名（不报错）', () => 图标.卡('不存在的机体', 'ally', 34));
  if (兜底 && 兜底.includes('class="mic fb"') && 兜底.includes('不存在的机体') && !兜底.includes('<img')) ok(`方块退路：${兜底}`);
  else bad('方块退路不对：' + 兜底);
  const 兜底敌 = 图标.卡('不存在的敌人', 'enemy', 34);
  if (兜底敌.includes('class="mic fb"') && 兜底敌.includes('--fc:#d9564b')) ok('敌方方块退路用的是敌方红');
  else bad('敌方方块退路不对：' + 兜底敌);
}

/* ============================ [4] 界面真的用上了图标 ============================ */
console.log('\n[4] 编队 / 战斗 / 招募三个画面真的画出了图标');
{
  界面.开屏('编队');
  界面.默认五人队();
  const 编队HTML = 屏文字();
  const 编队图 = (编队HTML.match(/<img class="mi"/g) || []).length;
  /* 出击格子里有几台就有几个图标（Lv10 的出击上限是 3 台，不是 9 格都摆满） */
  const 出击台数 = 界面.编队.出击.length;
  if (编队图 >= G.ALLY_T.length + 出击台数) ok(`编队屏 ${编队图} 个图标（机师列表 ${G.ALLY_T.length} 名 + 出击 ${出击台数} 格）`);
  else bad(`编队屏图标太少：${编队图}`);
  if (/undefined|NaN/.test(编队HTML)) bad('编队屏 HTML 里出现了 undefined / NaN');
  else ok('编队屏 HTML 里没有 undefined / NaN');

  界面.清空(); 界面.默认五人队(); 界面.设等级(10);
  界面.开战(20261010);
  const 战斗HTML = 屏文字();
  const 战斗图 = (战斗HTML.match(/<img class="mi"/g) || []).length;
  const 应画 = 界面.ctx.allies.length + 界面.ctx.enemies.length;
  if (战斗图 === 应画) ok(`战斗屏 ${战斗图} 个图标 = 我方 ${界面.ctx.allies.length} + 敌方 ${界面.ctx.enemies.length}`);
  else bad(`战斗屏图标数不对：${战斗图}（想 ${应画}）`);
  if (/undefined|NaN/.test(战斗HTML)) bad('战斗屏 HTML 里出现了 undefined / NaN');
  else ok('战斗屏 HTML 里没有 undefined / NaN');

  肉鸽.新的一局('无', 12345);
  界面.开屏('招募');
  const 招募HTML = 屏文字();
  const 招募图 = (招募HTML.match(/<img class="mi"/g) || []).length;
  if (招募图 >= 1) ok(`招募屏 ${招募图} 个图标`);
  else bad('招募屏没有图标');
  if (/undefined|NaN/.test(招募HTML)) bad('招募屏 HTML 里出现了 undefined / NaN');
  else ok('招募屏 HTML 里没有 undefined / NaN');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '美术测试全部通过');
process.exit(fails ? 1 : 0);
