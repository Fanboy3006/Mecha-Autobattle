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
    /* M4 之后的追加段会把里程碑文字换掉；M6（v0.6.2）起是「M6 平衡工具」。
       ★ 2026-10-13（v0.6.3）：界面那两条（声音开关每一屏都常驻 / 选项集中在画面中间）落地，
       副标题换成这次的改动说法 —— 白名单跟着加一条（这里断的是「顶栏文字被脚本填对了」）。
       ★ 2026-10-13（v0.6.4）：修「含 ≥2 个 `:` 的 `data-act` 被事件委托截断」（调参室那一屏），
       副标题再换一次 —— 白名单再加一条（框架 §16：这是「填对了」的关系式，不是钉历史常量）。
       ★ 2026-10-13（v0.6.5）：录像线的一键「保存本局录像」（下载到浏览器默认下载目录），
       副标题再换一次 —— 白名单再加一条（同一条规矩：断的是「顶栏文字被脚本填对了」）。
       ★ 2026-10-13（v0.6.6）：出口线**口径 A**「出口小径免打守军」（作者亲手拍板，玩法改动）
       → 副标题换到这一条；白名单**再加一条**（0.6.5 那一条是录像线的，**留着不删** —— 它是同一族
       「历史副标题」，两条线的提交顺序谁前谁后都不影响这一段）。
       ★ 2026-10-13（v0.6.7）：分队线的**带队核心**（作者亲手拍板：「每个特色分队的第一台是可以
       直升 20 级的」）—— 本局第一次成功招募的那一台直接 Lv20。副标题换到这一条，白名单**再加一条**。
       ★ 2026-10-13（v0.6.8）：界面线的 **K3 UI 改版**（把作者副本 `K3/autobattle` 的纯表现层改版
       搬回正式仓库：战斗屏 / 大地图屏 / 编队屏 / 结算屏 + 小件，只动 `src/css/main.css` 文末一节）。
       副标题换到这一条，白名单**再加一条**（同一条规矩：这是一族「历史副标题」，**只加不删**）。
       ★ 2026-10-13（v0.6.9）：战斗线的**第一批「标定经济」**（作者亲手拍板「OK」）——
       把秘银已有的「标定 → 接力」泛化成**全职业通用的「传球」机制**：特种命中即挂标 / 指挥号令点名标定，
       狙击打带标定目标（暴击 +25 / 伤害 +30%，消耗 1 层）/ 范围武器引爆全部标定。
       副标题换到这一条，白名单**再加一条**（同一条规矩：**只加不删**）。 */
    ['milestone', v => v === 'M4' || v === '晋升+零件' || v === 'M6 平衡工具' || v === '界面：声音开关常驻 + 选项居中'
      || v === '界面：修 data-act 三段被截断（调参室选项）'
      || v === '录像：一键保存本局录像（下载文件夹）'
      || v === '出口：小径免打守军（口径A）'
      || v === '分队：带队核心直接 Lv20'
      || v === '界面：K3 UI 改版（战斗屏 / 大地图屏 / 编队屏）'
      || v === '战斗：标定经济（特种产标 → 狙击引爆）'],
    ['ready', v => v === true],
    ['slots', v => v === 9],                                  // 作者 2026-10-10 拍板：错开的 9 格 = 前排 4 + 后排 5
    ['rows', v => v === 2],
    ['行列数', v => typeof v === 'function' && v(0) === 4 && v(1) === 5],   // 前排 4 格、后排 5 格
    // 阻挡关系 + 出击上限（作者 2026-10-10 拍板；2026-10-10 **第二次拍板**：出击上限按肉鸽等级算）
    ['阻挡关系', v => Array.isArray(v) && v.length === 8],
    ['阻挡位', v => typeof v === 'function' && v(0).join(',') === '4,5'],
    ['被挡吗', v => typeof v === 'function' && v(5, [0]) === true && v(5, []) === false],
    ['相邻位', v => typeof v === 'function' && v(0).join(',') === '1,4,5' && v(4).includes(0) && v(4).includes(5)],
    // 出击上限：**两级封顶**（作者 2026-10-11 第三次拍板）——
    // 等级那条线：肉鸽等级 1/4/7/10 → 3/4/5/6（每 3 级 +1、等级封顶 6）；
    // ★ 2026-10-11 难度调整（杠杆 ②「压部署位」）：**绝对顶 9 → 7** —— 藏品加成最多把上限推到 7 台
    //   （作者允许的是「可以允许上到 7-9 台」，这一轮取下界；理由写在 `05-阵型.js` 的 `绝对顶` 注释里）。
    ['出击上限', v => typeof v === 'function' && v(1) === 3 && v(4) === 4 && v(7) === 5 && v(10) === 6 && v(99) === 6
      && v(10, 1) === 7 && v(10, 2) === 7 && v(10, 3) === 7 && v(10, 9) === 7],
    ['出击上限提示', v => typeof v === 'function' && v(1).解锁等级 === 4
      && v(10).等级到顶 === true && v(10).到顶 === false && v(10, 3).到顶 === true],
    ['出击上限由名册', v => typeof v === 'function' && v([{ 等级: 10 }]) === 3 && v([{ 等级: 20 }]) === 5],
    ['升级门槛', v => typeof v === 'function' && v(1) === 8 && v(3) === 30],   // 战棋 27-开局.js:102 的 LV_NEED
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
