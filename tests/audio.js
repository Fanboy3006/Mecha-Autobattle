#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 音乐测试（方案第 9 节 M5 的验收 · 音乐侧）
 * ----------------------------------------------------------------------------
 * ★ 2026-10-11 从共享文件 `tests/art_audio.js` **拆出来**（`协作\协作框架.md` 第 5 节 A1）：
 *   本文件 = 音乐那一半（**音乐线所有**），美术那一半在 `tests/art_icons.js`。
 *   拆的原因见框架第 9 节的事故记录：两条线共改一个文件 → 美术线把音乐线**未提交**的
 *   `tests/art_audio.js` 一起提交 → **HEAD 自己变红**。拆完两条线各管各的，事故点根除。
 *   **段号沿用原文件的 [5]–[9]（含 [8b]），断言一条没删、一条没放宽** —— 段号不改是为了
 *   能拿本文件与原 `tests/art_audio.js` 逐条对账。
 *
 * 检查五件事：
 *   5. AUDIO 素材（`audio/local-music.js` + `music-room.js`）注入成功、接口齐全、**场景映射正确**
 *      （菜单 = title、大地图 / 编队 = mapStrategy、战斗中 = allyPhase、Boss 战 = boss）；
 *   6. **没有音频环境时优雅降级**（这里就是：替身里没有 Audio / AudioContext）：整体静音、声音按钮隐藏、
 *      play / stop / mute / unlock / themeOf 全都不抛异常；
 *   7. 顶栏的声音开关（按钮 / M 键 / 测试接口）+「音乐鉴赏」入口；
 *   8. **放大招切主题曲、保持到本回合结束**（方案 8.2）+ 敌我阶段分开切曲（8c）+ 真打一场 Boss 战（8b）
 *      和一场**普通**战斗（[8b] 段后半）；
 *   9. 装上「假浏览器」（有 Audio）以后，曲子真的指向仓库里的 Suno 文件（含 `THEMES` 全表逐条验）。
 *
 * 不依赖 Playwright：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来（第 [9] 段自己造沙箱）。
 *
 * 用法：node tests/audio.js
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
const { 音乐, 界面, 播放, 场景曲, 肉鸽 } = G;
const MA = G.MechAudio;
console.log(`音乐测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

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
  /* ★ 2026-10-11：`场景曲` 的第三个参数是**这一场的结果**（`'胜'` / `'败'` / `null`，
     只在结算两屏有意义）；「战斗」那一行给的是**这场战斗的第一首**（我方阶段）——
     敌方阶段由 `音乐.切阶段` 按出手方切，所以这里断言的是「默认 / 第一次」的曲子，
     真的按出手方切在下面的 [8] 段验。 */
  const 映射 = [
    ['菜单', false, 'title', '开场菜单 = title（现在是专门的「Suno 标题」）'],
    ['大地图', false, 'mapStrategy', '大地图 = mapStrategy（「SUNO 战略」）'],
    ['编队', false, 'mapStrategy', '编队 = mapStrategy'],
    ['分队', false, 'mapStrategy', '分队 / 招募 / 奇遇这些肉鸽外壳画面 = mapStrategy'],
    ['招募', false, 'mapStrategy', '招募 = mapStrategy'],
    ['奇遇', false, 'mapStrategy', '奇遇 = mapStrategy'],
    ['战斗', false, 'allyPhase', '战斗从我方回合起 = allyPhase（敌方阶段由看记录的出手方切，见 [8]）'],
    ['战斗', true, 'boss', 'Boss 战 = boss（现在是专门的「Suno Boss」）'],
  ];
  const 错 = 映射.filter(([屏, boss, 想]) => 场景曲(屏, boss) !== 想);
  if (!错.length) ok(`场景映射 ${映射.length} 条全对：${映射.map(m => `${m[0]}${m[1] ? '(Boss)' : ''}→${m[2] || '不切'}`).join('、')}`);
  else bad('场景映射不对：' + 错.map(m => `${m[0]} → ${场景曲(m[0], m[1])}（想 ${m[2]}）`).join('；'));

  /* ★ 2026-10-11 作者补了专门的通关 / 败北曲：赢了 → victory、输了 → defeat、没打完 → 不切曲 */
  const 结算映射 = [
    ['结算', '胜', 'victory', '打完赢了 → victory（「Suno 通关」）'],
    ['结算', '败', 'defeat', '打输了 → defeat（「Suno 败北」，以前是「不切曲」）'],
    ['结算', null, null, '没有战报（还没打完）→ 不切曲'],
    ['肉鸽结算', '胜', 'victory', '本局通关 → victory'],
    ['肉鸽结算', '败', 'defeat', '耐久耗尽 / 玩家放弃 → defeat'],
    ['肉鸽结算', null, null, '既没通关也没失败 → 不切曲'],
  ];
  const 结算错 = 结算映射.filter(([屏, 结果, 想]) => 场景曲(屏, false, 结果) !== 想);
  if (!结算错.length) ok(`结算两屏 ${结算映射.length} 条全对：${结算映射.map(m => `${m[0]}${m[1] === null ? '(无战报)' : m[1] === '胜' ? '(赢)' : '(输)'}→${m[2] || '不切'}`).join('、')}`);
  else bad('结算两屏的映射不对：' + 结算错.map(m => `${m[0]}(${m[1]}) → ${场景曲(m[0], false, m[1])}（想 ${m[2]}）`).join('；'));

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
  音乐.阶段方 = 'ally';              // 从「我方阶段」起（下面的敌人记录会把阶段切到敌方，所以这里先复位）
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
  /* 上面那条敌人记录把阶段切到了敌方（★ 2026-10-11 起阶段曲会跟着走），
     所以这里期望的是「**敌方阶段的**场景曲」= enemyPhase —— 原文那句「放回场景曲」仍然成立。 */
  if (回 === 'enemyPhase' && 音乐.主题 === null && 音乐.当前曲 === 'enemyPhase') ok(`回合结束 → 主题曲放回**这个阶段的**场景曲（${回}）`);
  else bad(`回合结束没有切回场景曲（${回}）`);
  /* 没有个人主题曲的机体：用势力的主题曲（战棋的 THEMES.faction） */
  界面.ctx = { allies: [{ slot: 0, key: 'W1', weapons: [{ t: { name: '大招', unlock: 20 } }] }], enemies: [] };
  const 势力曲 = 音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: '大招' });
  if (势力曲 === 'theme:Suno 流星小队') ok(`没有个人主题曲的机体用势力的主题曲（W1 → ${势力曲}）`);
  else bad(`势力主题曲没生效（${势力曲}）`);
  音乐.回合结束();

  /* 8c：★ 2026-10-11 作者拍板：**我方 / 敌方回合分开切曲**，且**每回合只在第一次换方时切一次**
     （长战斗里一回合真的会换好几次方：`我方→敌方→我方→敌方→我方`，一变更就切会抖得厉害）。
     注意：`看记录` 只有「切到主题曲」时才返回 cue —— 阶段曲切没切要看 `音乐.当前曲`。 */
  界面.开屏('战斗');                                   // 练习模式这条编成不是 Boss → 走敌我阶段
  音乐.主题 = null;
  音乐.阶段方 = 'ally';                                // 从「我方阶段」这个已知状态起（白盒复位，方便逐条断言）
  音乐.本回合切过阶段 = false;                          // 本回合还没切过（正常由 `回合结束` / `场景切换` 复位）
  界面.ctx = { allies: [{ slot: 0, key: 'B1', weapons: [{ t: { name: '近战斩击', unlock: 1 } }] }], enemies: [{ slot: 0, key: 'grunt' }] };
  音乐.看记录({ 类型: '攻击', 单位方: 'enemy', 单位位: 0, 武器: '机枪' });
  if (音乐.阶段方 === 'enemy' && 音乐.当前曲 === 'enemyPhase') ok(`敌方出手 → 切 ${音乐.当前曲}（「Suno 敌方回合」这首曲子终于有人用了）`);
  else bad(`敌方出手没有切到 enemyPhase（阶段方 ${音乐.阶段方} / 当前曲 ${音乐.当前曲}）`);
  音乐.看记录({ 类型: '攻击', 单位方: 'enemy', 单位位: 0, 武器: '机枪' });
  音乐.看记录({ 类型: '跳过', 单位方: 'enemy', 单位位: 0 });
  if (音乐.当前曲 === 'enemyPhase' && 音乐.刷曲() === 'enemyPhase') ok('敌方**连着**出手不重复切（`刷曲` 说就是同一首）');
  else bad(`同一个方连着出手切了：${音乐.当前曲}`);
  /* ★ 新规矩（作者 2026-10-11）：本回合**已经切过一次** → 这次换方**什么都不做**
     （连阶段方都不改，下一条记录再按「同一个方」跳过）—— 长战斗里一回合会换好几次方，一变更就切就抖 */
  音乐.看记录({ 类型: '攻击', 单位方: 'ally', 单位位: 0, 武器: '近战斩击' });
  if (音乐.阶段方 === 'enemy' && 音乐.当前曲 === 'enemyPhase') ok('我方出手 → **本回合不再换曲**（每回合只切第一次换方；阶段方也保持不变）');
  else bad(`本回合第二次换方还是动了（阶段方 ${音乐.阶段方} / 当前曲 ${音乐.当前曲}）`);
  音乐.看记录({ 类型: '攻击', 单位方: 'enemy', 单位位: 0, 武器: '机枪' });
  音乐.看记录({ 类型: '修理', 单位方: 'ally', 单位位: 0, 回复: 100 });     // 敌方段里我方修理
  音乐.看记录({ 类型: '增益', 单位方: 'ally', 单位位: 0 });
  if (音乐.阶段方 === 'enemy' && 音乐.当前曲 === 'enemyPhase') ok('我方**修理 / 增益**不算「换回我方」（按还在敌方段处理，不会抖一下曲子）');
  else bad(`我方辅助动作把阶段弄乱了（阶段方 ${音乐.阶段方} / 当前曲 ${音乐.当前曲}）`);
  音乐.回合结束();
  if (音乐.当前曲 === 'enemyPhase' && 音乐.本回合切过阶段 === false) ok('本回合结束：曲子保持这个阶段（enemyPhase），「本回合切过」复位 → 下一回合可以再切一次');
  else bad(`回合结束时的状态不对（当前曲 ${音乐.当前曲} / 本回合切过 ${音乐.本回合切过阶段}）`);

  /* 8b：真打一场 Boss 战，看规则在实战里真的触发 */
  界面.开屏('编队');
  界面.清空(); 界面.默认五人队(); 界面.设等级(30);
  界面.设编成(G.编成表.length - 1);          // 第 4 层终点：蓝色大肥鱼
  界面.手动播放 = true;
  界面.开战(20261010);
  if (音乐.是Boss战 === true && 音乐.当前曲 === 'boss') ok(`Boss 战认出来了：场景曲 = ${音乐.当前曲}`);
  else bad(`Boss 战没有切到 boss（是Boss战 ${音乐.是Boss战} / 当前曲 ${音乐.当前曲}）`);
  let 大招记录 = 0, 主题切换 = 0, 回合护栏 = 0, 阶段切过 = 0, 见过阶段方 = 0, 被打断 = 0;
  const 见过的主题 = new Set();
  while (界面.阶段 !== '结算' && 回合护栏++ < 14) {
    界面.开打();
    let n = 0;
    while (播放.在放() && n++ < 100000) {
      const ev = 播放.事件()[播放.位置];
      const 前 = 音乐.主题, 阶段前 = 音乐.阶段方, 曲前 = 音乐.当前曲;
      音乐.看记录(ev);                     // 这里手动调 tick()，绕过 `播一步` 钩子 → 自己补这一次「看记录」
      播放.tick();
      if (阶段前 !== null && 阶段前 !== 音乐.阶段方) 见过阶段方++;
      /* Boss 战整场一首：出手方记下来了，但曲子不能被**阶段曲**顶掉（主题曲还是允许的） */
      if (曲前 === 'boss' && (音乐.当前曲 === 'allyPhase' || 音乐.当前曲 === 'enemyPhase')) 被打断++;
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
  /* ★ 2026-10-11：Boss 战**整场一首**（`boss`），不跟着敌我阶段来回切。
     注意：`到结算` 会把屏切到「结算」，`场景切换` 顺手清掉阶段账 —— 所以要在**循环里**数。 */
  if (见过阶段方 > 0) ok(`Boss 战里出手方真的换过 ${见过阶段方} 次（阶段账在走）`);
  else bad('Boss 战里阶段方一次都没变过，这段没验到');
  if (被打断 === 0) ok('Boss 战整场没被阶段曲顶掉过（曲子一直是 boss）');
  else bad(`Boss 战里曲子被阶段曲顶掉了 ${被打断} 次`);
  const 这一场胜 = !!(界面.战报 && 界面.战报.结果 === '胜');
  const 结算该放 = 场景曲('结算', true, 这一场胜 ? '胜' : '败');
  if (结算该放 === (这一场胜 ? 'victory' : 'defeat')) ok(`这一场打完（${界面.战报 ? 界面.战报.结果 : '—'}）→ 结算屏放 ${结算该放}`);
  else bad(`结算屏该放的曲子不对：${结算该放}`);
  if (音乐.主题 === null) ok('这一场打完（本回合结束）主题曲已经放回场景曲');
  else bad(`打完还挂着主题曲：${音乐.主题}`);
}

/* ============================ [8b] 真打一场普通战斗：敌我阶段曲真的在走 ============================ */
console.log('\n[8b] 真打一场**普通**战斗（★ 2026-10-11：我方 / 敌方阶段分开切曲）');
{
  界面.开屏('编队');
  界面.清空(); 界面.默认五人队(); 界面.设等级(10);   // Lv10 → 我方 3 台、敌方也不是一击就倒
  界面.设编成(0);                              // 第 1 层第 1 条「普通」编成
  界面.手动播放 = true;
  界面.开战(20261011);
  if (音乐.是Boss战 === false && 音乐.当前曲 === 'allyPhase') ok(`普通编成：不是 Boss 战（是Boss战 ${音乐.是Boss战}）、从 ${音乐.当前曲} 起`);
  else bad(`普通编成的开场不对（是Boss战 ${音乐.是Boss战} / 当前曲 ${音乐.当前曲}）`);
  let 见过我方 = 0, 见过敌方 = 0, 出手方 = 0, 档 = 0, 换曲 = 0, 一回合最多换几次 = 0;
  const 方向 = new Set(), 走过的曲 = [], 逐回合 = [];
  while (界面.阶段 !== '结算' && 档++ < 14) {
    const 回合前 = 音乐.阶段方;
    let 这次换 = 0, 这次大招 = 0;
    const 本回合曲 = [音乐.当前曲];
    界面.开打();
    let n = 0;
    while (播放.在放() && n++ < 100000) {
      const ev = 播放.事件()[播放.位置];
      const 曲前 = 音乐.当前曲;
      if (ev && ev.类型 === '攻击' && ev.单位方 === 'ally') {
        const u = 界面.ctx.allies.find(x => x.slot === ev.单位位);
        const e = u && (u.weapons || []).find(x => x.t && x.t.name === ev.武器);
        if (e && e.t.unlock >= 20) 这次大招++;
      }
      /* 这一段**不要**手动调 `看记录`：没开「跳过动画」，`播放.tick()` 自己会走 `播一步` 钩子
         （Boss 那一段相反：它开了「跳过动画」，钩子只在结尾报一次 null，所以要手动补） */
      播放.tick();
      /* 只数**阶段曲之间的切换**：`victory` / `defeat` 是「到结算」切屏切的，不算阶段，
         `theme:` 是放大招切的，也不算 */
      if (音乐.当前曲 !== 曲前 && (音乐.当前曲 === 'allyPhase' || 音乐.当前曲 === 'enemyPhase')) {
        换曲++; 这次换++; 本回合曲.push(音乐.当前曲);
      }
      if (!ev || !ev.单位方) continue;
      出手方++;
      方向.add(ev.单位方);
      if (音乐.当前曲 === 'allyPhase') 见过我方++;
      if (音乐.当前曲 === 'enemyPhase') 见过敌方++;
    }
    逐回合.push(`第${档}回合 ${本回合曲.map(c => c === null ? '（不切）' : c).join('→')}`);
    if (这次换 > 一回合最多换几次) 一回合最多换几次 = 这次换;
    /* 一回合最多切 1 次阶段曲（★ 2026-10-11 作者拍板）+ 每次我方大招切一次主题曲 */
    if (这次换 > 1 + 这次大招) bad(`第 ${档} 回合换了 ${这次换} 次曲（上限 1 次阶段 + 大招 ${这次大招}）`);
  }
  info(`普通战斗实战：${档 - 1} 个回合打完（${界面.战报 ? 界面.战报.结果 : '—'}），带出手方的记录 ${出手方} 条、出手方 ${[...方向].join(' + ') || '无'}`);
  info(`逐回合切曲：${逐回合.join(' ｜ ')}`);
  info(`换过 ${换曲} 次曲（含主题曲），一回合最多 ${一回合最多换几次} 次`);
  if (见过敌方 > 0) ok(`实战里真的切到过敌方阶段曲（enemyPhase 出现过 ${见过敌方} 次）`);
  else bad('实战里一次都没切到 enemyPhase，这段没验到');
  if (见过我方 > 0) ok(`实战里也真的切回过我方阶段曲（allyPhase 出现过 ${见过我方} 次）`);
  else bad('实战里一次都没切到 allyPhase');
  if (一回合最多换几次 <= 1) ok(`一回合里最多换 ${一回合最多换几次} 次阶段曲（★ 每回合只在第一次换方时切一次，**不是一发一换 / 也不是一变更就切**）`);
  else bad(`一回合里阶段曲换太多次了：${一回合最多换几次} 次`);

  /* ★ 结算屏：赢了放 victory、输了放 defeat（★ 2026-10-11 作者补了这两首曲子）。
     战报要够 `结算屏()` 画得出来（它要读 我方 / 敌方），否则会抛异常。 */
  const 假战报 = 结果 => ({ 结果, 原因: '测试', 回合数: 1, 记录: [], 种子: 1, 我方: [{ hp: 1 }], 敌方: [{ hp: 0 }] });
  界面.战报 = 假战报('胜');
  音乐.当前曲 = null;
  界面.开屏('结算');
  if (音乐.当前曲 === 'victory') ok(`打完赢了 → 开屏('结算') 切到 ${音乐.当前曲}（「Suno 通关」）`);
  else bad(`赢了没有切到 victory（当前曲 ${音乐.当前曲}）`);
  界面.战报 = 假战报('败');
  音乐.当前曲 = null;                          // 假装现在放的是别的曲子
  界面.开屏('结算');
  if (音乐.当前曲 === 'defeat') ok(`打输了 → 切到 ${音乐.当前曲}（「Suno 败北」；以前是「不切曲」）`);
  else bad(`输了没切到 defeat（当前曲 ${音乐.当前曲}）`);
  /* 肉鸽结算屏：通关算赢、失败算输。用一局**真空的** RUN 来试（界面要读 队伍 / 藏品 等字段）。 */
  const 真RUN = 肉鸽.RUN;
  肉鸽.RUN = 肉鸽.新的一局('无', 24680);
  肉鸽.RUN.结局 = '通关';
  音乐.当前曲 = null; 界面.开屏('肉鸽结算');
  if (音乐.当前曲 === 'victory') ok(`肉鸽本局**通关** → ${音乐.当前曲}`);
  else bad(`通关没有切到 victory（${音乐.当前曲}）`);
  肉鸽.RUN.结局 = '失败';
  音乐.当前曲 = null; 界面.开屏('肉鸽结算');
  if (音乐.当前曲 === 'defeat') ok(`肉鸽本局失败 / 玩家放弃 → ${音乐.当前曲}`);
  else bad(`肉鸽失败没切到 defeat（${音乐.当前曲}）`);
  肉鸽.RUN = 真RUN;
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
  const 菜单曲 = 根页.播过.filter(x => /Suno%20Title|Suno Title/.test(x.src));
  if (MA2.state().track === 'Suno 标题' && 菜单曲.length && 菜单曲[菜单曲.length - 1].在)
    ok(`标题曲指向仓库里真实的文件：${decodeURIComponent(菜单曲[菜单曲.length - 1].src).replace(/^file:\/\/\//, '')}`);
  else bad(`标题曲没指向真实文件（现在 ${MA2.state().track} / ${JSON.stringify(菜单曲)}）`);
  音2.场景切换('大地图');                         // mapStrategy = 「SUNO 战略」（2026-10-11 起不再指向版权曲）
  if (MA2.state().track === 'SUNO 战略') ok(`大地图现在是进仓库的 Suno 曲：${MA2.state().track}`);
  else bad(`大地图曲子不对（现在 ${MA2.state().track}）`);
  MA2.play('boss');                              // ★ 2026-10-11 作者补了专门的 Boss 曲
  const Boss曲 = 根页.播过[根页.播过.length - 1];
  if (MA2.state().track === 'Suno Boss' && Boss曲.在 && decodeURIComponent(Boss曲.src).includes('audio/SUNO/'))
    ok(`Boss 曲指向仓库里真实的 Suno 曲子：${decodeURIComponent(Boss曲.src).replace(/^file:\/\/\//, '')}`);
  else bad(`Boss 曲不对（现在 ${MA2.state().track} / ${JSON.stringify(Boss曲)}）`);
  MA2.play('victory');                           // victory = 「Suno 通关」
  if (MA2.state().track === 'Suno 通关') ok(`结算的 victory 曲是 ${MA2.state().track}`);
  else bad(`victory 曲不对（现在 ${MA2.state().track}）`);
  MA2.play('defeat');                            // defeat = 「Suno 败北」（以前是 null）
  if (MA2.state().track === 'Suno 败北') ok(`结算的 defeat 曲是 ${MA2.state().track}（以前没有曲子）`);
  else bad(`defeat 曲不对（现在 ${MA2.state().track}）`);
  MA2.play('allyPhase');
  const 战曲 = 根页.播过[根页.播过.length - 1];
  if (战曲.在 && decodeURIComponent(战曲.src).includes('audio/SUNO/')) ok('战斗曲也指向 audio/SUNO/ 下的真实文件');
  else bad(`战斗曲不对：${JSON.stringify(战曲)}`);
  /* ★ CUES 里已经没有一处指向版权曲了，而且**每一个 cue 的曲子文件都真的在仓库里** */
  const 版权曲cue = Object.keys(MA2.CUES).filter(k => {
    const n = MA2.CUES[k];
    return n !== null && (!MA2.TRACKS[n] || !MA2.TRACKS[n].id);
  });
  if (版权曲cue.length === 0) ok(`场景表 ${Object.keys(MA2.CUES).length} 个 cue 现在**全部**指向进仓库的 Suno 曲子（版权曲只留在 TRACKS 里当退路）`);
  else bad(`这些 cue 还指向版权曲：${版权曲cue.join('、')}`);
  /* 逐条把「场景表里的 cue」真正 play 一遍，看它指向的文件在不在仓库里 */
  const 缺文件 = [];
  for (const k of Object.keys(MA2.CUES)) {
    const n = MA2.CUES[k]; if (!n) continue;
    MA2.play(k);
    const 最后 = 根页.播过[根页.播过.length - 1];
    if (!最后 || !最后.在) 缺文件.push(`${k} → ${n}`);
  }
  if (!缺文件.length) ok(`场景表里每个 cue 都指向仓库里真实存在的文件（${Object.keys(MA2.CUES).length} 个 cue 逐个 play 验过）`);
  else bad('这些 cue 指向的文件不在仓库里：' + 缺文件.join('、'));
  /* 主题曲表：7 个势力 + 3 台机体，全部也要指向真实文件 */
  const 主题表 = [];
  for (const f in MA2.THEMES.faction) 主题表.push(['势力 ' + f, MA2.THEMES.faction[f]]);
  for (const u in MA2.THEMES.unit) 主题表.push(['机体 ' + u, MA2.THEMES.unit[u]]);
  const 主题缺 = [];
  for (const [谁, n] of 主题表) {
    if (!MA2.TRACKS[n] || !MA2.TRACKS[n].id) 主题缺.push(`${谁} → ${n}（不在 TRACKS 里）`);
    else {
      MA2.play('theme:' + n);
      const 最后 = 根页.播过[根页.播过.length - 1];
      if (!最后 || !最后.在) 主题缺.push(`${谁} → ${n}（文件读不到）`);
    }
  }
  if (!主题缺.length) ok(`主题曲表 ${主题表.length} 条（${Object.keys(MA2.THEMES.faction).length} 个势力 + ${Object.keys(MA2.THEMES.unit).length} 台机体）全部指向仓库里真实的文件`);
  else bad('主题曲表有问题：' + 主题缺.join('、'));
  if (MA2.THEMES.faction['天人'] === 'SUNO 天人') ok('天人（CB）终于有势力曲了（以前 CB1–CB5 放大招不切曲）');
  else bad(`天人的势力曲不对：${MA2.THEMES.faction['天人']}`);

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
console.log(fails ? `共 ${fails} 项失败` : '音乐测试全部通过');
process.exit(fails ? 1 : 0);
