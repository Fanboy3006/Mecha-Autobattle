#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 美术与音乐测试（方案第 9 节 M5 的验收）
 * ----------------------------------------------------------------------------
 * 检查五件事：
 *   1. ART 素材（`art/mech-icons.js`）真的注入进页面了，`MI` 的接口齐全（build / draw / makeSprite /
 *      ICON_BY_MECH / FACTION_PAL / ids …）；
 *   2. 能按机体 id 画出图：全部 24 个图标、我方 34 名 + 敌方 29 种机体，画的时候不抛异常；
 *   3. 图标层（`78-图标.js`）的挑图规则对：有专属图标用专属、没有的按战斗分类 / 体型借原型、
 *      再挑不出来**退回势力色方块 + 短名**（不报错）；
 *   4. AUDIO 素材（`audio/local-music.js` + `music-room.js`）注入成功、接口齐全、**场景映射正确**
 *      （菜单 = title、大地图 / 编队 = mapStrategy、战斗中 = allyPhase、Boss 战 = boss）；
 *   5. **没有音频环境时优雅降级**（这里就是：替身里没有 Audio / AudioContext）：整体静音、声音按钮隐藏、
 *      play / stop / mute / unlock / themeOf 全都不抛异常；以及「放大招切主题曲、保持到本回合结束」。
 *
 * 不依赖 Playwright：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来（和其余五套一样）。
 *
 * 用法：node tests/art_audio.js
 * ========================================================================== */
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { makeSandbox, inlineScripts, runScripts, loadPage } from './lib/dom-stub.mjs';

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
const { 图标, 音乐, 界面, 播放, 场景曲, 肉鸽 } = G;
const MI = G.MechIcons;
const MA = G.MechAudio;
const 屏文字 = () => String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
console.log(`美术与音乐测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

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
    ['B1', 'ally', 'B1', 'ying'],     // 影世界近卫：有专属图标
    ['M2', 'ally', 'M2', 'moon'],     // 月球王国重装：有专属图标
    ['S1', 'ally', 'CB3', 'clyne'],   // 卫星国防军特种：没有专属图标 → 借特种原型，配色还是自己的
    ['U7', 'ally', 'CB3', 'mithril'], // 秘银特种：同上
    ['hound', 'enemy', 'hound', 'enemy'],
    ['bluefish', 'enemy', 'flagship', 'enemy'],   // 蓝色大肥鱼（3×3）→ 旗舰剪影
    ['swarm', 'enemy', 'fighter', 'enemy'],       // 蜂群无人机（飞行）→ 战斗机剪影
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

/* ============================ [5] AUDIO 接口 + 场景映射 ============================ */
console.log('\n[5] AUDIO 素材（local-music.js + music-room.js）接口齐全、场景映射正确');
if (!MA) bad('页面里没有 MechAudio（AUDIO 块没注入？）');
else {
  const 接口 = ['play', 'stop', 'mute', 'unlock', 'sfx', 'state', 'themeOf', 'hasCue', 'onAvailable', 'preview', 'seek', 'meta', 'openRoom'];
  const 缺 = 接口.filter(k => typeof MA[k] !== 'function');
  if (!缺.length) ok(`MechAudio 接口齐全（${接口.join(' / ')}）`);
  else bad('MechAudio 缺少：' + 缺.join('、'));
  if (MA.TRACKS && MA.CUES && MA.THEMES && MA.tuning) ok(`曲目表 ${Object.keys(MA.TRACKS).length} 首、场景表 ${Object.keys(MA.CUES).length} 个、主题曲表在`);
  else bad('MechAudio 的曲目 / 场景表缺失');
  /* 曲目文件都在仓库里（audio/SUNO/ 的 Suno 曲子；作者本地的版权曲读不到没关系，会退到 alt） */
  const 本地版权 = Object.keys(MA.TRACKS).filter(n => !MA.TRACKS[n].id);
  info(`进仓库的 Suno 曲子 ${Object.keys(MA.TRACKS).length - 本地版权.length} 首；作者本地版权曲 ${本地版权.length} 首（${本地版权.join('、')}，读不到时退到 alt）`);
  if (MA.tuning.defaults && MA.tuning.defaults.cues) ok('音乐鉴赏页要的 tuning（默认表 / get / assign / exportText）也在');
  else bad('tuning 缺失，音乐鉴赏页会打不开');
  /* 声音开关的基础行为 */
  if (typeof 音乐.切开关 === 'function' && 音乐.开关 === true) ok('音乐层默认开着声音');
  else bad('音乐层的声音开关不对');
}

{
  const 映射 = [
    ['菜单', false, 'title', '开场菜单 = title'],
    ['大地图', false, 'mapStrategy', '大地图 = mapStrategy'],
    ['编队', false, 'mapStrategy', '编队 = mapStrategy'],
    ['分队', false, 'mapStrategy', '分队 / 招募 / 奇遇这些肉鸽外壳画面 = mapStrategy'],
    ['招募', false, 'mapStrategy', '招募 = mapStrategy'],
    ['奇遇', false, 'mapStrategy', '奇遇 = mapStrategy'],
    ['战斗', false, 'allyPhase', '战斗中 = allyPhase（敌方行动不切曲）'],
    ['战斗', true, 'boss', 'Boss 战 = boss'],
    ['结算', false, null, '结算屏不切曲（战棋的 victory / defeat 两首都没有曲子）'],
    ['肉鸽结算', false, null, '本局结算也不切曲'],
  ];
  const 错 = 映射.filter(([屏, boss, 想]) => 场景曲(屏, boss) !== 想);
  if (!错.length) ok(`场景映射 ${映射.length} 条全对：${映射.map(m => `${m[0]}${m[1] ? '(Boss)' : ''}→${m[2] || '不切'}`).join('、')}`);
  else bad('场景映射不对：' + 错.map(m => `${m[0]} → ${场景曲(m[0], m[1])}（想 ${m[2]}）`).join('；'));
  界面.开屏('菜单');
  if (音乐.场景 === '菜单' && 音乐.当前曲 === 'title') ok(`真的切了：开屏('菜单') → 场景 ${音乐.场景}，当前曲 ${音乐.当前曲}`);
  else bad(`开屏('菜单') 没有切到 title（场景 ${音乐.场景} / 当前曲 ${音乐.当前曲}）`);
  界面.开屏('大地图');
  if (音乐.当前曲 === 'mapStrategy') ok(`开屏('大地图') → ${音乐.当前曲}`);
  else bad(`开屏('大地图') 没有切到 mapStrategy（${音乐.当前曲}）`);
}

/* ============================ [6] 没有音频环境时优雅降级 ============================ */
console.log('\n[6] 没有音频环境时的降级（这里就没有 Audio / AudioContext）');
{
  if (typeof page.sandbox.Audio === 'undefined' && typeof page.sandbox.AudioContext === 'undefined')
    info('替身里没有 Audio / AudioContext —— 和「别人的机器上读不到曲子」是同一条降级路径');
  else bad('替身里居然有 Audio，测试前提不对');

  const 状 = MA ? MA.state() : null;
  if (状 && 状.ready === false && 状.playing === false) ok(`播放层报「不可用」：ready ${状.ready}、playing ${状.playing}`);
  else bad(`播放层的状态不对：${JSON.stringify(状)}`);
  if (page.byId.get('btnSound') && page.byId.get('btnSound').hidden === true) ok('读不到曲子 → 声音按钮自动隐藏（方案 8.2）');
  else bad('读不到曲子时声音按钮没有隐藏');

  不炸('play / stop / mute / unlock / sfx / preview / seek 全都不抛异常', () => {
    MA.play('boss'); MA.play('theme:Suno 主角'); MA.play(null);
    MA.mute(true); MA.mute(false); MA.unlock(); MA.sfx('hit');
    MA.preview('Suno 主角'); MA.seek(3); MA.meta('Suno 主角');
  });
  不炸('音乐层的场景切换 / 刷曲 / 看记录 / 回合结束 也都不抛异常', () => {
    界面.开屏('战斗'); 音乐.刷曲(); 音乐.回合结束(); 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: 'x' });
    界面.开屏('菜单');
  });
  const 假记录 = 音乐.看记录(null);
  if (假记录 === null) ok('播放记录为空时看记录返回 null（不报错）');
  else bad('看记录(null) 应该返回 null');
  /* 连播放层都没有（AUDIO 块被关掉 / 没注入）时也不能炸 */
  const 真层 = page.sandbox.MechAudio;
  page.sandbox.MechAudio = undefined;
  不炸('连播放层都没有时：切开关 / 场景切换 / 看记录 都不抛异常', () => {
    音乐.切开关(false); 音乐.场景切换('菜单'); 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0 });
    音乐.切开关(true);
  });
  page.sandbox.MechAudio = 真层;
  if (音乐.层() === 真层) ok('恢复播放层，后续照常');
  else bad('恢复播放层失败');
}

/* ============================ [7] 声音开关 ============================ */
console.log('\n[7] 顶栏的声音开关（按钮 / M 键 / 测试接口）');
{
  const 钮 = page.byId.get('btnSound');
  const 关 = 音乐.切开关(false);
  if (关 === false && 钮.textContent === '静音' && 钮.getAttribute('aria-pressed') === 'false') ok('切到静音：按钮文字 / aria-pressed 跟着变');
  else bad(`切到静音没生效（${钮.textContent} / ${钮.getAttribute('aria-pressed')}）`);
  const 开 = 音乐.切开关();
  if (开 === true && 钮.textContent === '声音' && 音乐.开关 === true) ok('再切回来：按钮是「声音」');
  else bad('切回声音没生效');
  let 存 = null;
  try { 存 = page.sandbox.localStorage.getItem('mecha-autobattle-sound'); } catch (e) {}
  if (存 === 'on') ok(`开关偏好写进了 localStorage（${存}）—— 关掉页面也记得`);
  else bad(`开关偏好没存（${存}）`);
  /* 界面动作表里的「声音」也通到同一处 */
  page.sandbox.__game.界面.动作('声音');
  if (音乐.开关 === false) { ok('界面动作「声音」也能切（顶栏按钮走的就是它）'); 界面.动作('声音'); }
  else bad('界面动作「声音」没生效');
  /* 音乐鉴赏页：这条机器上没有曲子 → 提示而不是崩 */
  const 开赏 = 不炸('没有曲子时点「音乐鉴赏」不抛异常', () => 界面.动作('音乐鉴赏'));
  if (开赏 === true || 开赏 === false) ok(`「音乐鉴赏」入口可用（这台机器上返回 ${开赏}，读不到曲子时给提示）`);
  else bad('「音乐鉴赏」入口异常');
}

/* ============================ [8] 放大招切主题曲 ============================ */
console.log('\n[8] 放大招切主题曲、保持到本回合结束（方案 8.2）');
{
  /* 8a：构造一条记录，规则本身对不对 */
  界面.开屏('战斗');
  音乐.主题 = null;
  界面.ctx = { allies: [{ slot: 0, key: 'B1', weapons: [{ t: { name: '传送斩', unlock: 20 } }, { t: { name: '近战斩击', unlock: 1 } }] }], enemies: [] };
  const 普通 = 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: '近战斩击' });
  if (普通 === null && 音乐.主题 === null) ok('普通武器出手**不**切主题曲');
  else bad(`普通武器也切了主题曲：${普通}`);
  const 大招 = 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: '传送斩' });
  if (大招 === 'theme:Suno 主角' && 音乐.主题 === 大招 && 音乐.当前曲 === 大招) ok(`放大招 → 切主题曲 ${大招}（雷萨 B1 的主题曲）`);
  else bad(`放大招没有切主题曲（${大招}）`);
  const 敌方 = 音乐.看记录({ 类型: '攻击', 单位方: 'enemy', 单位位: 0, 武器: '传送斩' });
  if (敌方 === null && 音乐.主题 === 大招) ok('敌人放大招不切主题曲（还是我方那首）');
  else bad('敌人放大招把主题曲切走了');
  const 回 = 音乐.回合结束();
  if (回 === 'allyPhase' && 音乐.主题 === null && 音乐.当前曲 === 'allyPhase') ok(`回合结束 → 主题曲放回场景曲（${回}）`);
  else bad(`回合结束没有切回场景曲（${回}）`);
  /* 没有个人主题曲的机体：用势力的主题曲（战棋的 THEMES.faction） */
  界面.ctx = { allies: [{ slot: 0, key: 'W1', weapons: [{ t: { name: '大招', unlock: 20 } }] }], enemies: [] };
  const 势力曲 = 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: '大招' });
  if (势力曲 === 'theme:Suno 流星小队') ok(`没有个人主题曲的机体用势力的主题曲（W1 → ${势力曲}）`);
  else bad(`势力主题曲没生效（${势力曲}）`);
  音乐.回合结束();

  /* 8b：真打一场 Boss 战，看规则在实战里真的触发 */
  界面.开屏('编队');
  界面.清空(); 界面.默认五人队(); 界面.设等级(30);
  界面.设编成(G.编成表.length - 1);          // 第 4 层终点：蓝色大肥鱼
  界面.手动播放 = true;
  界面.开战(20261010);
  if (音乐.是Boss战 === true && 音乐.当前曲 === 'boss') ok(`Boss 战认出来了：场景曲 = ${音乐.当前曲}`);
  else bad(`Boss 战没有切到 boss（是Boss战 ${音乐.是Boss战} / 当前曲 ${音乐.当前曲}）`);
  let 大招记录 = 0, 主题切换 = 0, 回合护栏 = 0;
  const 见过的主题 = new Set();
  while (界面.阶段 !== '结算' && 回合护栏++ < 14) {
    界面.开打();
    let n = 0;
    while (播放.在放() && n++ < 100000) {
      const ev = 播放.事件()[播放.位置];
      const 前 = 音乐.主题;
      播放.tick();
      if (ev && ev.类型 === '攻击' && ev.单位方 === 'ally') {
        const u = 界面.ctx.allies.find(x => x.slot === ev.单位位);
        const e = u && (u.weapons || []).find(x => x.t && x.t.name === ev.武器);
        if (e && G.rangeKindOf && e.t.unlock >= 20) 大招记录++;
      }
      if (音乐.主题 && 音乐.主题 !== 前) { 主题切换++; 见过的主题.add(音乐.主题); }
    }
  }
  info(`实战：${回合护栏 - 1} 个回合打完（${界面.战报 ? 界面.战报.结果 : '—'}），我方放大招 ${大招记录} 次、主题曲切了 ${主题切换} 次（${[...见过的主题].join('、') || '无'}）`);
  if (大招记录 > 0) ok(`实战里我方确实放了大招（${大招记录} 次）`);
  else bad('实战里一次大招都没放，这段没验到');
  if (主题切换 > 0 && [...见过的主题].every(c => c.startsWith('theme:'))) ok(`放一次大招切一次主题曲：${主题切换} 次，全部是 theme: 开头的主题曲`);
  else bad(`实战里没有切到主题曲（${主题切换} 次）`);
  if (音乐.主题 === null) ok('这一场打完（本回合结束）主题曲已经放回场景曲');
  else bad(`打完还挂着主题曲：${音乐.主题}`);
}

/* ============================ [9] 装上假浏览器：音乐真的指向仓库里的曲子 ============================ */
console.log('\n[9] 装上「假浏览器」（有 location / URL / Audio）以后，切曲真的指向仓库里的 Suno 曲子');
{
  const HTML = readFileSync(join(ROOT, 'index.html'), 'utf8').replace(/\r\n/g, '\n');
  const SCRIPTS = inlineScripts(HTML);

  /** 造一个「能读音频」的沙箱：假 Audio 会检查 src 指向的文件在不在，
   *  在就发 loadedmetadata、不在就发 error —— 正是播放层判断可用 / 退到 alt 的依据。 */
  function 假浏览器(baseURI) {
    const { sandbox } = makeSandbox();
    sandbox.location = { pathname: baseURI.replace(/^file:\/\//, ''), href: baseURI };
    sandbox.document.baseURI = baseURI;
    sandbox.URL = URL;
    sandbox.Audio = function () {
      const 监听 = {};
      const a = {
        preload: '', loop: false, volume: 1, paused: true, currentTime: 0, duration: 0, src: '', _target: 0,
        addEventListener(k, f) { (监听[k] = 监听[k] || []).push(f); },
        removeEventListener() {},
        play() { a.paused = false; 探一次(); return { catch() {} }; },
        pause() { a.paused = true; },
        load() { 探一次(); },
      };
      function 探一次() {
        let 在 = false;
        try { 在 = existsSync(fileURLToPath(a.src)); } catch (e) { 在 = false; }
        播过.push({ src: a.src, 在 });
        (在 ? (监听.loadedmetadata || []) : (监听.error || [])).forEach(f => f());
      }
      return a;
    };
    const 播过 = [];
    const errors = runScripts(sandbox, SCRIPTS, { quiet: true });
    return { sandbox, 播过, errors };
  }

  const 根页 = 假浏览器('file:///F:/DSH-mecha/mecha-autobattle/index.html');
  if (根页.errors.length) bad('装了 Audio 以后内联脚本报错：' + 根页.errors[0]);
  else ok('装上假浏览器后页面照样跑得起来（没有 AudioContext、只有 <audio>）');
  const MA2 = 根页.sandbox.MechAudio, 音2 = 根页.sandbox.__game.音乐;
  if (MA2 && MA2.state().ready === true) ok('播放层探测到曲子读得到：ready = true（声音按钮会显示出来）');
  else bad(`播放层没有探测到曲子：${JSON.stringify(MA2 && MA2.state())}`);
  MA2.unlock();                                  // 浏览器里由第一次点击 / 按键触发
  音2.场景切换('菜单');
  const 菜单曲 = 根页.播过.filter(x => /Suno%20%E4%B8%BB%E8%A7%92|Suno 主角/.test(x.src));
  if (菜单曲.length && 菜单曲[菜单曲.length - 1].在) ok(`菜单曲指向仓库里真实的文件：${decodeURIComponent(菜单曲[菜单曲.length - 1].src).replace(/^file:\/\/\//, '')}`);
  else bad(`菜单曲没指向真实文件：${JSON.stringify(菜单曲)}`);
  音2.场景切换('大地图');                         // mapStrategy = 作者本地的版权曲（仓库里没有）→ 退到 alt
  if (MA2.state().track === 'Suno 主角') ok(`大地图的版权曲读不到 → 自动退到 alt（现在放 ${MA2.state().track}）`);
  else bad(`版权曲读不到时没有退到 alt（现在 ${MA2.state().track}）`);
  MA2.play('boss');                              // BOSS BGM 也是本地版权曲 → 退到「Suno 我方回合」
  if (MA2.state().track === 'Suno 我方回合') ok(`BOSS BGM 读不到 → 退到 ${MA2.state().track}`);
  else bad(`Boss 曲没有退到 alt（现在 ${MA2.state().track}）`);
  MA2.play('allyPhase');
  const 战曲 = 根页.播过[根页.播过.length - 1];
  if (战曲.在 && decodeURIComponent(战曲.src).includes('audio/SUNO/')) ok('战斗曲也指向 audio/SUNO/ 下的真实文件');
  else bad(`战斗曲不对：${JSON.stringify(战曲)}`);

  /* 片段版（src/artifact-fragment.html）在 src/ 里，基准路径要自己变成 ../audio/ */
  const 片页 = 假浏览器('file:///F:/DSH-mecha/mecha-autobattle/src/artifact-fragment.html');
  if (片页.errors.length) bad('片段版装上 Audio 后报错：' + 片页.errors[0]);
  else {
    const MA3 = 片页.sandbox.MechAudio;
    MA3.unlock(); MA3.play('allyPhase');
    const 最 = 片页.播过[片页.播过.length - 1];
    if (最.在 && decodeURIComponent(最.src).includes('/mecha-autobattle/audio/SUNO/')) ok(`片段版也找得到曲子（${decodeURIComponent(最.src).replace('file:///', '')}）—— MECHA_MUSIC_BASE 按在不在 src/ 里自动选 audio/ 还是 ../audio/`);
    else bad(`片段版找不到曲子：${JSON.stringify(最)}`);
  }
  const 找得到 = 根页.播过.filter(x => x.在).length, 找不到 = 根页.播过.filter(x => !x.在).length;
  info(`根页面一共试过 ${根页.播过.length} 次取曲：仓库里有 ${找得到} 首、读不到的 ${找不到} 首（读不到的全部退到 alt，没有报错）`);
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '美术与音乐测试全部通过');
process.exit(fails ? 1 : 0);
