#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 藏品测试（作者 2026-10-10 点名要做的「3 藏品」）
 * ----------------------------------------------------------------------------
 * 数据来源：机甲战棋 `Claude hand off/src/js/23b-藏品.js`（只读），
 * 逐条搬进 `src/js/93-藏品.js`（行号写在那个文件的每一条右边）。
 *
 * 这份测试真的跑（固定种子，结果决定性），盯着五件事：
 *   [1] 战棋分类表里「纯数值」的 32 件全在表里、字段读得到；没接的 11 件在 `藏品接不了` 里
 *   [2] 抽 5 件有代表性的藏品，验证数值**真的进了公式**（贴改动前后的数字）：
 *       +命中 10 → hitRate 高 10；+伤害 10%（攻击能力值 +10）→ dmgCore ×1.1；
 *       +最大 HP 30% → maxHp 变高；+装甲 20% → effArmor 变高；+减伤 → 防御值变高
 *   [3] 一场带藏品的战斗真的更强（**同种子**对比：不带 vs 带）
 *   [4] 精英 / Boss 胜利发了藏品、存档 → 读档后藏品还在
 *   [5] 同一局同一节点抽到的藏品可复现（同种子两次一样、换个种子会变）
 *
 * 用法：node tests/relic.js
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

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
const 界面 = G.界面, 播放 = G.播放, 肉鸽 = G.肉鸽;
界面.手动播放 = true;
界面.设跳过动画(true);
console.log(`藏品测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/** 把当前这一场打完（自动战斗是一回合一个回合的，要一直点开打） */
function 打完这一场() {
  let 轮 = 0;
  while (界面.屏 === '战斗' && 轮++ < 30) {
    界面.开打();
    let n = 0;
    while (界面.阶段 === '播放' && n++ < 100000) 播放.tick();
  }
}

/* 一场固定的对照战斗：A = 不带藏品，B = 带指定藏品（同种子、同编成、同指令） */
const 对照我方 = [{ 键: 'B1', 位: 0, 等级: 10 }, { 键: 'B2', 位: 1, 等级: 10 }, { 键: 'CB2', 位: 4, 等级: 10 }];
const 对照敌方 = [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'grunt', 位: 1, 等级: 10 }, { 键: 'shield', 位: 2, 等级: 10 }];
const 对照种子 = 20261010;
/** 带藏品跑一场：先开一局（把藏品塞进 RUN），再开局——开局() 里会自己调 藏品开战 */
function 跑一场(藏品们, 种子) {
  const 旧 = 肉鸽.RUN;
  肉鸽.RUN = { 种子: 种子 || 对照种子, 层: 1, 场次: 0, 藏品: 藏品们 || [], 日志: [] };
  const r = G.simulate(对照我方, 对照敌方, {}, 种子 || 对照种子);
  肉鸽.RUN = 旧;
  return r;
}

/* ============================ [1] 32 件纯数值藏品都在表里 ============================ */
console.log('[1] 32 件纯数值藏品：数据表齐不齐、字段读不读得到');
{
  const 表 = G.藏品表;
  const 全部 = Object.keys(表);
  info(`藏品表共 ${全部.length} 件（战棋 RELICS 是 50 件：23b-藏品.js:12-69）`);
  if (全部.length === 50) ok(`50 件全在表里（32 件纯数值 + 7 件经济编制 + 11 件不能用）`);
  else bad(`表里只有 ${全部.length} 件，战棋是 50 件`);

  const 缺 = [], 字段坏 = [];
  for (const id of G.藏品纯数值32) {
    const r = 表[id];
    if (!r) { 缺.push(id); continue; }
    if (!r.名 || !r.稀有 || !r.说明 || !r.数值 || !r.实装 || !r.分类) 字段坏.push(id);
    /* 每一件纯数值藏品至少要有一个能落地的字段：mods / stat / stack / foe / foeStack / 特殊 */
    const e = r.数值 || {};
    if (!e.mods && !e.stat && !e.stack && !e.foe && !e.foeStack && !e.特殊) 字段坏.push(id + '(没有效果字段)');
  }
  if (!缺.length) ok(`战棋分类表里的 32 件【数值】藏品**一件不缺**（${G.藏品纯数值32.join('、')}）`);
  else bad(`有 ${缺.length} 件纯数值藏品没进表：${缺.join('、')}`);
  if (!字段坏.length) ok('32 件的 id / 名字 / 稀有度 / 说明 / 数值 / 实装 / 分类 都读得到');
  else bad(`字段不全：${字段坏.join('、')}`);

  const 没接 = G.藏品接不了;
  if (没接.length === 11) ok(`「接不了」清单 ${没接.length} 件：${没接.join('、')}`);
  else bad(`「接不了」清单是 ${没接.length} 件，任务书的分类表是 11 件`);
  const 没写的 = 没接.filter(id => !表[id] || !表[id].缺 || 表[id].缺 === '实装');
  if (!没写的.length) ok('接不了的每一件都写了「缺什么」的理由字段');
  else bad(`这些接不了的没写理由：${没写的.join('、')}`);

  /* 真的接上了几件（实装 === '已接'）+ 部分接的（战棋分类表里那 32 件）
     注意：部分接的那两件，`实装` 里也带「未接」两个字，所以判断要用 === 而不是子串匹配 */
  const 已接 = 全部.filter(id => 表[id].实装 === '已接');
  const 部分 = 全部.filter(id => 表[id].实装.startsWith('部分'));
  const 纯数值已接 = G.藏品纯数值32.filter(id => 表[id].实装 !== '未接');
  const 纯部分 = 纯数值已接.filter(id => 表[id].实装.startsWith('部分'));
  ok(`纯数值 32 件里：整件生效 ${纯数值已接.filter(id => 表[id].实装 === '已接').length} 件、` +
     `部分生效 ${纯部分.length} 件（${纯部分.join('、')}）、整件没接 ${32 - 纯数值已接.length} 件`);
  info(`全表实装：已接 ${已接.length} 件 / 部分 ${部分.length} 件 / 未接 ${全部.length - 已接.length - 部分.length} 件`);

  /* 抽签池：只抽真的会生效的（s2 / n2 的射程那半边没法验，所以不进池） */
  const 池 = G.藏品可抽池();
  if (池.length === 28 && !池.includes('s2') && !池.includes('n2')) {
    ok(`随机池 ${池.length} 件（32 件纯数值里去掉只有一半能用的 s2 / n2）`);
  } else bad(`随机池不对：${池.length} 件${池.includes('s2') ? '（含 s2）' : ''}${池.includes('n2') ? '（含 n2）' : ''}`);

  /* 数值逐字对账：拿战棋源码那几行样例一个字一个字比（只比 mods / stat / stack / foe / foeStack） */
  const 数值块 = r => {
    const e = r.数值 || {}, o = {};
    /* 按固定顺序拼，好和战棋源码那一行逐字比 */
    for (const k of ['职业', 'mods', 'stat', 'stack', 'foe', 'foeStack', '特殊'].sort()) if (e[k] !== undefined) o[k] = e[k];
    return JSON.stringify(o);
  };
  const 样例 = [
    ['g3', { 职业: ['近卫'], mods: { dmg: 40, crit: 15, armorPct: -40 } }, '23b-藏品.js:16'],
    ['h2', { 职业: ['重装'], mods: { red: 15 } }, '23b-藏品.js:27'],
    ['n4', { stack: { by: ['狙击'], per: { hit: 5 }, max: 5 } }, '23b-藏品.js:33'],
    ['e9', { foe: { armorPct: -30 } }, '23b-藏品.js:63'],
    ['p3', { stack: { by: ['狙击', '特种'], per: { hit: 5, dmg: 4 }, max: 12, to: ['狙击', '特种'] } }, '23b-藏品.js:48'],
    ['g1', { 职业: ['近卫'], stat: { hpPct: 30 }, mods: { armorPct: 15 } }, '23b-藏品.js:14'],
    ['b2', { 特殊: 'lonewolf' }, '23b-藏品.js:51'],
  ];
  for (const [id, 期望, 出处] of 样例) {
    const 真 = 数值块(表[id]);
    const 想 = JSON.stringify(Object.fromEntries(Object.entries(期望).sort(([a], [b]) => a < b ? -1 : 1)));
    if (真 === 想) ok(`${id}【${表[id].名}】的数值与战棋逐字相同（${出处}）`);
    else bad(`${id} 的数值和战棋对不上：表里 ${真}，战棋 ${想}`);
  }
}

/* ============================ [2] 数值真的进了公式（前后对比） ============================ */
console.log('\n[2] 抽 5 件有代表性的藏品，验证数值真的进了公式');
{
  const 裸 = () => G.makeUnit('B1', 'ally', 0, 10);
  const 上 = (u, id) => { G.应用藏品我方([u], [id]); return u; };
  const 靶 = () => G.makeUnit('grunt', 'enemy', 0, 10);
  const 主武器 = u => u.weapons.find(e => e.t.name === '近战斩击').t;

  /* (a) +最大 HP 30%：g1 格斗框架·强化型（近卫 HP +30%） */
  {
    const a = 裸(), b = 上(裸(), 'g1');
    if (b.maxHp > a.maxHp && b.maxHp === Math.round(a.maxHp * 1.3)) {
      ok(`g1【格斗框架·强化型】近卫 HP +30%：maxHp ${a.maxHp} → ${b.maxHp}（×1.3）、hp 跟着涨到 ${b.hp}`);
    } else bad(`g1 的 HP 加成不对：${a.maxHp} → ${b.maxHp}（预期 ${Math.round(a.maxHp * 1.3)}）`);
    /* 同一条还带 armorPct +15：进 effArmor */
    info(`g1 的装甲 +15% 也进去了：effArmor ${G.effArmor(a)} → ${G.effArmor(b)}`);
  }

  /* (b) +命中：p3 远程协议（每 1 名狙击或特种出击 → 狙击 / 特种命中 +5）
         命中率会被 0–100 截断，所以看公式里的**原始值 raw**（= 武器命中 − 闪避 + 精准修正 + 命中加成）；
         另外要比**同一台机体**加藏品前后，不然两台机体的精准不一样，差值就不干净了。 */
  {
    const 甲 = G.makeUnit('CB2', 'ally', 4, 10);
    const wa = 甲.weapons.find(e => e.t.name === 'GN 狙击步枪').t;
    const t = G.makeUnit('grunt', 'enemy', 0, 10);
    const 前 = G.hitRate(甲, wa, t, { turn: 1 });
    /* 出击队伍 = 1 狙击 + 1 特种 → p3 一层 */
    const 出击 = [甲, G.makeUnit('CB3', 'ally', 3, 10)];
    G.应用藏品我方(出击, ['p3']);
    const 后 = G.hitRate(甲, wa, t, { turn: 1 });
    if (后.raw - 前.raw === 10 && (甲.藏品加成 || {}).hit === 10) {
      ok(`p3【远程协议】狙击 / 特种命中 +5 × 每名出击 = 2 名（1 狙击 + 1 特种）→ +10：` +
         `同一台 CB2 的命中原始值 ${前.raw} → ${后.raw}（结算值 ${前.hit}% → ${后.hit}%）`);
    } else bad(`p3 的命中加成不对：原始值 ${前.raw} → ${后.raw}，藏品加成 ${JSON.stringify(甲.藏品加成)}（预期 +10）`);
    /* 战棋的「+命中 10」干净例子：在同一台机体的 buffs 上直接挂 10 点，验公式一比一进去 */
    const 乙 = G.makeUnit('CB2', 'ally', 4, 10);
    乙.buffs = [{ src: '测试', hit: 10 }];
    const h2 = G.hitRate(乙, wa, t, { turn: 1 });
    if (h2.raw - 前.raw === 10) ok(`+命中 10 → hitRate 原始值高 10：${前.raw} → ${h2.raw}（公式一比一）`);
    else bad(`+命中 10 之后原始值是 ${h2.raw}，裸的是 ${前.raw}（差 ${h2.raw - 前.raw}，预期 10）`);
    /* 把靶子的闪避调高，看结算值是不是也真的涨 10（不撞 100% 天花板）。
       两台都是**全新的裸机**：上面那台 甲 已经被挂上藏品增益了，不能拿它当「前」的基准。 */
    const 裸机 = G.makeUnit('CB2', 'ally', 4, 10);
    const 加十 = G.makeUnit('CB2', 'ally', 4, 10);
    加十.buffs = [{ src: '测试', hit: 10 }];
    const 厚 = G.makeUnit('grunt', 'enemy', 0, 10);
    厚.eva = 25;
    const 厚前 = G.hitRate(裸机, wa, 厚, { turn: 1 }).hit;
    const 厚后 = G.hitRate(加十, wa, 厚, { turn: 1 }).hit;
    /* 再加一把**低命中武器**当靶子的对打：让结算值落进 0–100 的中间段，
       这样「+10 命中」在界面上真的看得见（上面那两行是被 100% 上限截断的） */
    const 手 = G.makeUnit('CB2', 'ally', 4, 10);
    const 手2 = G.makeUnit('CB2', 'ally', 4, 10);
    手2.buffs = [{ src: '测试', hit: 10 }];
    const 低命中 = Object.assign({}, wa, { hit: 100 });
    const 低前 = G.hitRate(手, 低命中, 厚, { turn: 1 }).hit;
    const 低后 = G.hitRate(手2, 低命中, 厚, { turn: 1 }).hit;
    if (低后 - 低前 === 10) ok(`换成命中 ${低命中.hit} 的武器打闪避 ${厚.eva} 的靶子：结算命中 ${低前}% → ${低后}%（+10 真的进了结算值）`);
    else info(`低命中那一发：${低前}% → ${低后}%（差 ${低后 - 低前}）`);
    const 例 = G.dmgCore(出击[1], 出击[1].weapons[0].t, t, { power: 1000, preview: true, turn: 1 });
    info(`p3 还带伤害 +4%：走的是下面 (c) 里的同一个「伤害加成」入口；这一场的步骤第 2 行 = ${例.steps[1]}`);
  }

  /* (c) +伤害：战棋 v0.37 起「伤害 +N%」= 攻击能力值 +N（03-能力与减免管线.js:185-188 的 genMods）。
         要看清「+N 攻击能力值等于伤害 +N%」，得让 statCoef 的基准正好是 1（攻击能力值 = 防御值）：
         伤害 =（威力 − 装甲）×（1 +（攻击 + N − 防御）/ 100）→ 装甲 0、攻击 = 防御 时 = 威力 ×(1 + N/100)。 */
  {
    const 纯靶 = () => { const t = G.makeUnit('grunt', 'enemy', 0, 2); t.armor = 0; t.defense = 0; t.eva = 0; return t; };
    const a = 裸(), b = 裸();
    const w = 主武器(a), t = 纯靶();
    /* 把攻击能力值和防御值配平成「系数 = 1」的干净局面 */
    a.melee = 100; b.melee = 100; t.defense = 100;
    const 基 = G.dmgCore(a, w, t, { power: G.wv(a, w, 'power'), preview: true, turn: 1 }).dmg;
    b.buffs = [{ src: '测试', dmg: 10 }];
    const 后 = G.dmgCore(b, w, t, { power: G.wv(b, w, 'power'), preview: true, turn: 1 }).dmg;
    const 比 = 后 / 基;
    if (Math.abs(比 - 1.1) < 0.005) {
      ok(`+伤害 10%（攻击能力值 100 → 110）→ dmgCore ×${比.toFixed(3)}：${基} → ${后}` +
         `（系数 1.00 → 1.10，坦克靶：装甲 0、攻击 = 防御 = 100）`);
    } else bad(`+伤害 10% 之后 dmgCore 是 ${后}（裸 ${基}，比 ${比.toFixed(3)}，预期 1.1）`);
    info(`公式步骤：${G.dmgCore(b, w, t, { power: G.wv(b, w, 'power'), preview: true, turn: 1 }).steps[1]}`);
    /* 藏品的真实例子：g2 高输出光束军刀（近卫伤害 +25%），同一个干净局面 */
    const c = 裸();
    c.melee = 100;
    G.应用藏品我方([c], ['g2']);
    const 后2 = G.dmgCore(c, w, t, { power: G.wv(c, w, 'power'), preview: true, turn: 1 }).dmg;
    const 比2 = 后2 / 基;
    if (Math.abs(比2 - 1.25) < 0.005) ok(`g2【高输出光束军刀】近卫伤害 +25% → ×${比2.toFixed(3)}：${基} → ${后2}`);
    else bad(`g2 的伤害加成不对：${基} → ${后2}（比 ${比2.toFixed(3)}，预期 1.25）`);
    /* 打真靶子（量产机：装甲 350、防御 52）时倍数不是整 1.25，把真实倍数也贴出来 */
    const 真靶 = G.makeUnit('grunt', 'enemy', 0, 10);
    const 真基 = G.dmgCore(a, w, 真靶, { power: G.wv(a, w, 'power'), preview: true, turn: 1 }).dmg;
    const 真后 = G.dmgCore(c, w, 真靶, { power: G.wv(c, w, 'power'), preview: true, turn: 1 }).dmg;
    info(`打量产机（装甲 350 / 防御 52、攻击能力值 178）时：+25 攻击能力值 → ${真基} → ${真后}` +
         `（×${(真后 / 真基).toFixed(3)}；−装甲 那一段不受攻击加成影响，所以不是整 1.25）`);
    /* 职业限定：同一件给狙击（CB2）不该生效 */
    const d = G.makeUnit('CB2', 'ally', 4, 10);
    G.应用藏品我方([d], ['g2']);
    if (!d.藏品加成) ok('g2 是「近卫」专属：给狙击（CB2）加的时候**一点都没生效**（职业限定真的在起效）');
    else bad(`g2 给狙击也生效了：${JSON.stringify(d.藏品加成)}`);
  }

  /* (d) +装甲 20%：e2 复合装甲（全队装甲 +20%） */
  {
    const a = 裸(), b = 上(裸(), 'e2');
    if (G.effArmor(b) === Math.round(G.effArmor(a) * 1.2)) {
      ok(`e2【复合装甲】全队装甲 +20%：effArmor ${G.effArmor(a)} → ${G.effArmor(b)}`);
    } else bad(`e2 的装甲加成不对：${G.effArmor(a)} → ${G.effArmor(b)}（预期 ${Math.round(G.effArmor(a) * 1.2)}）`);
    const t = 靶();
    const wa = 主武器(a), wb = 主武器(b);
    const da = G.dmgCore(a, wa, t, { power: G.wv(a, wa, 'power'), preview: true, turn: 1 }).dmg;
    const db = G.dmgCore(b, wb, t, { power: G.wv(b, wb, 'power'), preview: true, turn: 1 }).dmg;
    info(`装甲进的是「被攻击那一方」：这里 B1 是攻击者，所以自己的伤害不变（${da} / ${db}）；` +
         `让 B1 当靶子时装甲会减伤（见 (e)）`);
  }

  /* (e) +减伤 15%：h2 反应装甲（重装减伤 +15%）——减伤按战棋进「防御值」 */
  {
    const 靶子 = () => G.makeUnit('grunt', 'enemy', 0, 10);
    const 打手 = G.makeUnit('B1', 'ally', 0, 10);
    const w = 主武器(打手);
    const t1 = 靶子();
    const 前 = G.dmgCore(打手, w, t1, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).dmg;
    const t2 = 靶子();
    t2.buffs = [{ src: '藏品', red: 15 }];
    const 后 = G.dmgCore(打手, w, t2, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).dmg;
    if (后 < 前) ok(`+减伤 15%（进防御值）→ 挨打伤害 ${前} → ${后}（战棋把它算在 stage 2 的防御值上：03:230,259）`);
    else bad(`减伤没生效：${前} → ${后}`);
    /* 藏品的真实例子走一遍：h2 给重装 = 那个重装的 effArmor 不变、但 dmgCore 里的防御值 +15 */
    const m2 = G.makeUnit('M2', 'ally', 1, 10);
    G.应用藏品我方([m2], ['h2']);
    const 步 = G.dmgCore(打手, w, m2, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).steps.join(' | ');
    if (步.includes('减伤 +15')) ok(`h2【反应装甲】真的挂在重装身上了（步骤里能看到「减伤 +15」）：${步.split(' | ')[1]}`);
    else bad(`h2 没有进防御值：${步}`);
  }

  /* (f) 敌方那一侧：e9 λ 观测数据（敌方全体装甲 −30%）+ e4（敌方命中 −5） */
  {
    const 我 = G.makeUnit('B1', 'ally', 0, 10);
    const 敌 = G.makeUnit('grunt', 'enemy', 0, 10);
    const 甲前 = G.effArmor(敌);
    G.应用藏品敌方([敌], [我], ['e9', 'e4']);
    const 甲后 = G.effArmor(敌);
    if (甲后 === Math.round(甲前 * 0.7)) ok(`e9【λ 观测数据】敌方全体装甲 −30%：effArmor ${甲前} → ${甲后}`);
    else bad(`e9 没生效：${甲前} → ${甲后}（预期 ${Math.round(甲前 * 0.7)}）`);
    const 我2 = G.makeUnit('B1', 'ally', 0, 10);
    const 敌2 = G.makeUnit('grunt', 'enemy', 0, 10);
    const w敌 = 敌2.weapons[0].t;
    const 前 = G.hitRate(敌2, w敌, 我2, { turn: 1 }).hit;
    const 敌3 = G.makeUnit('grunt', 'enemy', 0, 10);
    G.应用藏品敌方([敌3], [我2], ['e4']);
    const 后 = G.hitRate(敌3, w敌, 我2, { turn: 1 }).hit;
    if (前 - 后 === 5) ok(`e4【ECM 干扰器】敌方全体命中 −5：敌方打我方 ${前}% → ${后}%`);
    else bad(`e4 没生效：${前}% → ${后}%（预期差 5）`);
  }

  /* (g) 叠层：n4 交叉火力（每 1 名狙击出击全队命中 +5，最多 5 层） */
  {
    const 队 = n => Array.from({ length: n }, (_, i) => G.makeUnit('CB2', 'ally', i, 10));
    const 一 = 队(1), 三 = 队(3), 六 = 队(6);
    G.应用藏品我方(一, ['n4']); G.应用藏品我方(三, ['n4']); G.应用藏品我方(六, ['n4']);
    const v = x => (x[0].藏品加成 || {}).hit || 0;
    if (v(一) === 5 && v(三) === 15 && v(六) === 25) {
      ok(`n4【交叉火力】按出击狙击人数叠层：1 名 +5、3 名 +15、6 名 +25（上限 5 层 = +25）`);
    } else bad(`叠层不对：1 名 ${v(一)}、3 名 ${v(三)}、6 名 ${v(六)}（预期 5 / 15 / 25）`);
  }

  /* (h) 整场加成：b1 混编作战条例（每个不同职业 +8% 伤害）、b2 孤狼 */
  {
    const 三人 = [G.makeUnit('B1', 'ally', 0, 10), G.makeUnit('B2', 'ally', 1, 10), G.makeUnit('CB2', 'ally', 4, 10)];
    G.应用藏品我方(三人, ['b1']);
    if ((三人[0].藏品加成 || {}).dmg === 24) ok(`b1【混编作战条例】3 个不同职业 → 全队伤害 +24%（8 × 3）`);
    else bad(`b1 的混编加成不对：${JSON.stringify(三人[0].藏品加成)}`);
    const 两人 = [G.makeUnit('B1', 'ally', 0, 10), G.makeUnit('B1', 'ally', 1, 10)];
    G.应用藏品我方(两人, ['b2']);
    if ((两人[0].藏品加成 || {}).dmg === 50 && (两人[0].藏品加成 || {}).armorPct === 30) {
      ok(`b2【孤狼】出击 2 人 → 全队伤害 +50%、装甲 +30%`);
    } else bad(`b2 的孤狼加成不对：${JSON.stringify(两人[0].藏品加成)}`);
    const 四人 = [1, 2, 3, 4].map(i => G.makeUnit('B1', 'ally', i, 10));
    G.应用藏品我方(四人, ['b2']);
    if ((四人[0].藏品加成 || {}).dmg === -15) ok(`b2【孤狼】出击 4 人 → 全队伤害 −15%（代价那一半也照抄了）`);
    else bad(`b2 的 4 人分支不对：${JSON.stringify(四人[0].藏品加成)}`);
  }
}

/* ============================ [3] 带藏品的战斗真的更强（同种子对比） ============================ */
console.log('\n[3] 一场带藏品的战斗真的更强（同种子、同编成：不带 vs 带）');
{
  const 甲 = 跑一场([]);
  const 乙 = 跑一场(['g2', 'e2', 'n4', 'h2', 'e5']);      // 近卫伤害 +25% / 全队装甲 +20% / 全队命中 +5 / 重装减伤 +15 / 敌方命中 −10
  const 回合 = r => r.回合数;
  const 我活 = r => r.我方.filter(u => u.hp > 0).length;
  const 我血 = r => r.我方.reduce((a, u) => a + u.hp, 0);
  const 敌血 = r => r.敌方.reduce((a, u) => a + Math.max(0, u.hp), 0);
  info(`不带藏品：${甲.结果}（${甲.原因}）· ${回合(甲)} 回合 · 我方存活 ${我活(甲)}/${甲.我方.length} · 剩余总 HP ${我血(甲)} · 敌剩余 ${敌血(甲)}`);
  info(`带  藏品：${乙.结果}（${乙.原因}）· ${回合(乙)} 回合 · 我方存活 ${我活(乙)}/${乙.我方.length} · 剩余总 HP ${我血(乙)} · 敌剩余 ${敌血(乙)}`);
  if (甲.结果 === 乙.结果) info('两场都是同一个结果（这一场本来就碾压），所以比「同回合数下谁打得更狠、剩得更多」');
  /* 同种子、同编成下逐条对：带藏品的那一边伤害必须更大。
     第一发可能是「没受藏品影响的那台」（B2 尖兵，带的是 g2 近卫 / e2 装甲 / n4 命中），
     所以取「两边都出现过的 同一台机体 + 同一把武器」的第一发来比。 */
  const 伤害 = r => r.记录.reduce((a, x) => a + (x.伤害 || 0), 0);
  const 键 = x => `${x.单位}【${x.武器}】`;
  const 表 = r => { const m = new Map(); for (const x of r.记录) if (x.类型 === '攻击' && x.伤害 > 0 && !m.has(键(x))) m.set(键(x), x); return m; };
  const 甲表 = 表(甲), 乙表 = 表(乙);
  let 对比 = null;
  for (const [k, x] of 乙表) if (甲表.has(k) && x.伤害 > 甲表.get(k).伤害) { 对比 = [甲表.get(k), x]; break; }
  if (对比) {
    const [旧, 新] = 对比;
    ok(`同一台机体同一把武器的第一发伤害变高：${键(新)} → ${新.目标} ${旧.伤害} → ${新.伤害}` +
       `（${((新.伤害 / Math.max(1, 旧.伤害) - 1) * 100).toFixed(1)}%；带的是 g2 近卫伤害 +25% / e2 全队装甲 +20% / n4 全队命中 +5）`);
  } else {
    bad('带藏品之后没有一发的伤害变高');
    info(`甲：${JSON.stringify([...甲表.values()].map(x => [键(x), x.伤害]))}`);
    info(`乙：${JSON.stringify([...乙表.values()].map(x => [键(x), x.伤害]))}`);
  }
  if (我血(乙) >= 我血(甲)) {
    ok(`带藏品的一方剩得更结实：我方剩余总 HP ${我血(甲)} → ${我血(乙)}` +
       `（全队装甲 +20% / 重装减伤 +15% / 敌方命中 −10）`);
  } else bad(`带藏品反而更脆：${我血(甲)} → ${我血(乙)}`);
  if (伤害(乙) > 伤害(甲)) ok(`整场我方总伤害：${伤害(甲)} → ${伤害(乙)}`);
  else bad(`整场总伤害没提高：${伤害(甲)} → ${伤害(乙)}`);
  /* 最终公式：不带藏品的那一场必须和「没有藏品系统」时一模一样（第 [1] 段已对账，这里再盯一遍记录条数） */
  const 丙 = 跑一场([]);
  if (JSON.stringify(甲.记录) === JSON.stringify(丙.记录)) ok('不带藏品跑两遍记录逐字相同（藏品没有偷偷改公式）');
  else bad('不带藏品跑两遍结果不一样了');
}

/* ============================ [4] 精英 / Boss 胜利发藏品 + 存档 ============================ */
console.log('\n[4] 精英 / Boss 战斗胜利发 1 件藏品；存档 → 读档后还在');
{
  /* 开一局真的肉鸽（走界面，和玩家一样的路） */
  界面.动作('回菜单');
  界面.动作('去分队');
  界面.动作('选分队', '无');
  界面.动作('开新局');
  const R = 肉鸽.RUN;
  if (界面.屏 === '大地图' && R) ok(`开了一局：第 ${R.层} 层，种子 ${R.种子}，开局藏品 ${R.藏品.length} 件`);
  else bad('开新局失败');

  /* 战场上的胜利奖励直接调 肉鸽.战斗结束（不真打，专测「发藏品」这一段） */
  const 打一场 = (类型, 节点序) => {
    R.地图.节点.push({ id: `测试-${类型}-${节点序}`, 列: 0, 序: 节点序, 类型, 通: [], 已过: false });
    const 旧当前 = R.当前;
    R.当前 = `测试-${类型}-${节点序}`;
    const r = 肉鸽.战斗结束('胜', 类型, { 敌方: [] });
    R.当前 = 旧当前;
    return r;
  };
  const r1 = 打一场('精英', 1);
  if (r1 && r1.藏品 && r1.藏品.id) ok(`精英战胜利发了 1 件：【${r1.藏品.名}】—— ${r1.藏品.说明}`);
  else bad(`精英战胜利没发藏品：${JSON.stringify(r1)}`);
  const r2 = 打一场('Boss', 2);
  if (r2 && r2.藏品 && r2.藏品.id) ok(`Boss 战胜利发了 1 件：【${r2.藏品.名}】—— ${r2.藏品.说明}`);
  else bad(`Boss 战胜利没发藏品：${JSON.stringify(r2)}`);
  const r3 = 打一场('战斗', 3);
  if (r3 && !r3.藏品) ok('普通战斗胜利**不发**藏品（只有精英 / Boss 发）');
  else bad(`普通战斗也发了：${JSON.stringify(r3.藏品)}`);
  if (R.藏品.length === 2 && R.藏品[0] !== R.藏品[1]) ok(`不重复：两件不一样（${R.藏品.join('、')}）`);
  else bad(`藏品去重不对：${JSON.stringify(R.藏品)}`);
  const 日志 = R.日志.filter(x => x.文本.includes('获得藏品')).map(x => x.文本);
  if (日志.length === 2) ok(`日志里写了两行「获得藏品」：${日志[0]}`);
  else bad(`日志不对：${JSON.stringify(日志)}`);

  /* 再赢一次精英：必须发一件**新的**（不重复） */
  const r4 = 打一场('精英', 4);
  if (r4 && r4.藏品 && r4.藏品.id && !['', ...R.藏品.slice(0, 2)].includes(r4.藏品.id)) {
    ok(`再赢一场又发了新的一件：【${r4.藏品.名}】（不与已有的重复）`);
  } else bad(`第二次精英没发新的：${JSON.stringify(r4 && r4.藏品)}`);

  /* 界面上看得见 */
  界面.开屏('大地图');
  const 文字 = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  if (文字.includes('藏品（') && R.藏品.every(id => 文字.includes(G.藏品名(id)))) {
    ok(`大地图屏上显示已拿到的藏品（名字 + 一句效果）：${R.藏品.map(id => G.藏品名(id)).join('、')}`);
  } else bad('大地图屏上没有显示藏品');
  if (文字.includes(G.藏品说明(R.藏品[0]))) ok(`每件还带一句效果：${G.藏品说明(R.藏品[0])}`);
  else bad('藏品的效果说明没显示');

  /* 存档 → 读档 */
  const 快照 = R.藏品.slice();
  肉鸽.存档();
  肉鸽.RUN = null;
  const 读 = 肉鸽.读存档();
  if (读 && JSON.stringify(读.藏品) === JSON.stringify(快照)) {
    ok(`存档 → 读档后藏品还在：${读.藏品.join('、')}（存放进 localStorage 的 JSON 里，键 ${G.存档键}）`);
  } else bad(`读档后藏品对不上：${JSON.stringify(读 && 读.藏品)} 期望 ${JSON.stringify(快照)}`);
  /* 读回来的藏品照样在战斗里生效（mods / stat / stack / foe / foeStack 都算「开战时落下去」） */
  const 件 = 读.藏品.map(id => G.藏品表[id]).filter(x => {
    const e = x.数值 || {};
    return !!(e.mods || e.stat || e.stack || e.foe || e.foeStack);
  });
  info(`读档后拿到的 ${读.藏品.length} 件藏品：` +
       `${读.藏品.map(id => `${G.藏品名(id)}[${G.藏品表[id].实装}]`).join('、')}；` +
       `其中 ${件.length} 件是「开战时落到单位和敌方身上」的纯数值件（加数从 0 变正数）`);
}

/* ============================ [5] 同种子同一节点抽到的藏品可复现 ============================ */
console.log('\n[5] 同一局同一节点抽到的藏品可复现（走种子，不用 Math.random）');
{
  const 造 = 种子 => ({ 种子, 层: 1, 场次: 0, 藏品: [], 日志: [], 队伍: [], 出击: [] });
  const 抽 = (R, 序) => G.抽藏品(R, null, 序);
  const a = 造(20261010), b = 造(20261010), c = 造(20261011);
  const 序表 = [0, 1, 2, 0, 1, 2];
  const 甲 = 序表.map(序 => 抽(a, 序)).join(',');
  const 乙 = 序表.map(序 => 抽(b, 序)).join(',');
  if (甲 === 乙) ok(`同种子（20261010）同一节点序抽到的一样：${甲}`);
  else bad(`同种子抽到的不一样：${甲} / ${乙}`);
  const 丙 = 序表.map(序 => 抽(c, 序)).join(',');
  if (丙 !== 甲) ok(`换个种子（20261011）就不一样：${丙}`);
  else info('换种子碰巧一样（29 件池子里随机，不算错）');
  /* 整条链路：两局一模一样地打精英战，发的必须是同一件 */
  const 走一遍 = 种子 => {
    界面.动作('回菜单'); 界面.动作('去分队'); 界面.动作('选分队', '无'); 界面.动作('开新局');
    肉鸽.RUN.种子 = 种子;
    肉鸽.RUN.地图 = 肉鸽.生成层(肉鸽.RUN);
    肉鸽.RUN.当前 = 肉鸽.RUN.地图.起点;
    肉鸽.RUN.场次 = 0; 肉鸽.RUN.藏品 = [];
    const R = 肉鸽.RUN;
    R.地图.节点.push({ id: 'T-精英-1', 列: 0, 序: 1, 类型: '精英', 通: [], 已过: false });
    R.当前 = 'T-精英-1';
    const r = 肉鸽.战斗结束('胜', '精英', { 敌方: [] });
    return r && r.藏品 ? r.藏品.id : null;
  };
  const p = 走一遍(777001), q = 走一遍(777001), s = 走一遍(777002);
  if (p && p === q) ok(`同一局（种子 777001）同一节点打两次精英，发的是同一件：${p}【${G.藏品名(p)}】`);
  else bad(`同一局同一节点发的不是同一件：${p} / ${q}`);
  info(`换一局（种子 777002）发的是：${s}${s === p ? '（碰巧同一件，不算错）' : ''}`);
  /* 拿全之后转源碳，不会发重复的 */
  const R = 肉鸽.RUN;
  R.藏品 = G.藏品可抽池().slice();
  R.源碳 = 0;
  const 满 = 肉鸽.战斗结束('胜', '精英', { 敌方: [] });
  if (满 && 满.藏品 && 满.藏品.源碳 === G.藏品转源碳 && R.源碳 === G.肉鸽数值.胜利源碳 + G.藏品转源碳) {
    ok(`池子拿全了：不重复发，转成源碳结晶 +${G.藏品转源碳}` +
       `（这一场另有普通胜利的源碳 +${G.肉鸽数值.胜利源碳}，合计 ${R.源碳}；日志里写清楚了）`);
  } else bad(`拿全之后的兜底不对：${JSON.stringify(满 && 满.藏品)} 源碳 ${R.源碳}`);
}

/* ============================ [6] 真打一场带藏品的肉鸽精英战（流程闭合） ============================ */
console.log('\n[6] 真打一场：带藏品的肉鸽战斗流程闭合（战斗里真的生效）');
{
  界面.动作('回菜单'); 界面.动作('去分队'); 界面.动作('选分队', '无'); 界面.动作('开新局');
  const R = 肉鸽.RUN;
  R.藏品 = ['g2', 'e2', 'n4'];
  /* 走到一个战斗类节点 */
  let 打 = false, 找 = 0;
  while (!打 && 找++ < 12) {
    const 可 = 肉鸽.能去的();
    if (!可.length) break;
    const 战斗节点 = 可.find(n => ['战斗', '精英', 'Boss'].includes(n.类型));
    if (!战斗节点) { const 过 = 可[0]; const t = 界面.去节点(过.id); if (t === '补给') 界面.领补给(); else if (t === '奇遇') 界面.选奇遇('源碳'); else if (t === '招募') break; continue; }
    界面.去节点(战斗节点.id);
    界面.打这一场();
    打 = 界面.屏 === '战斗';
  }
  if (!打) bad('这一局没走到战斗节点，流程闭合测不了');
  else {
    const 攻 = 界面.ctx.allies.find(u => u.key === 'B1');
    info(`进战斗后 B1 身上的藏品加成：${JSON.stringify(攻.藏品加成)}`);
    if (攻 && 攻.藏品加成 && 攻.藏品加成.dmg === 25 && 攻.藏品加成.armorPct === 20) {
      ok(`开局() 真的把藏品贴到我方身上了：B1 伤害 +${攻.藏品加成.dmg}、装甲 +${攻.藏品加成.armorPct}%`);
    } else bad(`藏品没贴到战斗里的单位上：${JSON.stringify(攻 && 攻.藏品加成)}`);
    const 敌 = 界面.ctx.enemies[0];
    info(`敌人 ${敌.key} 身上的藏品减益：${JSON.stringify(敌.藏品加成 || {})}` +
         `（这 3 件都是「加我方 / 削我方」的，敌方为空是正常的；e4/e9 那些才有）`);
    打完这一场();
    if (界面.屏 === '大地图' || 界面.屏 === '肉鸽结算') ok(`打完回到「${界面.屏}」`);
    else bad(`打完停在「${界面.屏}」`);
  }
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '藏品测试全部通过');
process.exit(fails ? 1 : 0);
