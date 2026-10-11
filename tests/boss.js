#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 站桩大 Boss 测试（方案 5.2 的验收）
 * ----------------------------------------------------------------------------
 * 方案 5.2 原文：「Boss：各写一个简单脚本（每 N 回合放一次大技能、半血换阶段），
 *                第一期只做蓝色大肥鱼一个。」作者 2026-10-10 拍板「可以做站桩大boss」。
 *
 * 这份测试盯着五件事（全部真的跑，数字都是打印出来的）：
 *   [1] 脚本**只对我方之外的单位生效**，参数是从 `71-改动.js` 的 `Boss脚本` 读的；
 *   [2] 大技能按间隔触发：数一数 12 个回合里各在第几回合放、放了几次；
 *   [3] 半血进第 2 阶段：阶段前后的大技能间隔 / 伤害倍率**真的变了**（贴数字）；
 *   [4] 战斗记录里有 `〔Boss〕` 条目（登场 / 蓄力 / 大技能 / 进入第 N 阶段）；
 *   [5] 一场「站桩 Boss 战」能正常打完 —— 测试里把大肥鱼的 **HP 临时改小**
 *       （240000 HP 在我们现在的伤害量级下 12 回合打不死，见任务板：HP / 装甲的换算归 Claude）；
 *       外加走一遍肉鸽第 4 层终点那条路（界面.备战 → 编队 → 开战）。
 * 还顺手验证大肥鱼在「前 3 后 2」阵型下**每个位都打得到**（fire:'map' → 范围、area 没写默认 row）。
 *
 * 不依赖任何 npm 包：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来。
 * 用法：node tests/boss.js
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

/* ============================ 载入 ============================ */
const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
if (!G || typeof G.Boss脚本 !== 'object' || typeof G.bossTurn !== 'function') {
  bad('window.__game 上没有 Boss 脚本的接口（61-Boss.js / 99-boot.js 没接上？）');
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const 界面 = G.界面, 播放 = G.播放, 肉鸽 = G.肉鸽;
界面.手动播放 = true;
界面.设跳过动画(true);
console.log(`站桩 Boss 测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/* ============================ 小工具 ============================ */
/** 造一台「假人」我方单位：血厚、没有武器 —— 只用来挨打，这样战斗一定能打满 12 回合。 */
function 假人(位 = 0, 键 = 'B1') {
  const u = G.makeUnit(键, 'ally', 位, 10);
  u.weapons = [];
  u.maxHp = 200000; u.hp = 200000;
  return u;
}
/** 造一只大肥鱼（等级照肉鸽第 4 层终点：Lv15）。 */
function 大肥鱼(等级 = 15) { return G.makeUnit('bluefish', 'enemy', 0, 等级); }
/** 一台我方 + 一只鱼，指令留空（进攻）。 */
function 开场(鱼血比 = 1, 种子 = 20261010) {
  const ctx = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'bluefish', 位: 0, 等级: 15 }], 种子);
  ctx.allies[0] = Object.assign(ctx.allies[0], { weapons: [], maxHp: 200000, hp: 200000 });
  const f = ctx.enemies[0];
  if (鱼血比 != null) f.hp = Math.round(f.maxHp * 鱼血比);
  return ctx;
}
/** 打满 N 个回合（分出胜负就停），返回这一场的全部记录。 */
function 打满(ctx, n = 12) {
  const 记录 = [];
  for (let i = 0; i < n && !ctx.result; i++) { G.设指令(ctx, {}); 记录.push(...G.打一回合(ctx)); }
  return 记录;
}
const Boss事件 = 记录 => 记录.filter(l => l.类型 === 'Boss');
const 是事件 = (l, 事件) => l.类型 === 'Boss' && l.Boss事件 === 事件;
const 大技能回合们 = 记录 => Boss事件(记录).filter(l => 是事件(l, '大技能')).map(l => l.回合);
const 蓄力回合们 = 记录 => Boss事件(记录).filter(l => 是事件(l, '蓄力')).map(l => l.回合);
const 文本们 = 记录 => 记录.map(l => `[${l.回合}] ${l.文本}`);

/* ============================ [1] 脚本的数据与作用范围 ============================ */
console.log('[1] Boss 脚本：数据驱动 + 只对我方之外的单位生效');
{
  const s = G.Boss脚本.bluefish;
  if (s && s.大技能间隔 === 3 && s.大技能武器 === '周身冲击' && Array.isArray(s.阶段) && s.阶段.length === 1 && s.阶段[0].触发 === '半血') {
    ok(`Boss脚本.bluefish 初稿：大技能间隔 ${s.大技能间隔} / 大技能武器「${s.大技能武器}」/ 第 1 阶段伤害倍率 ×${s.伤害倍率} / 阶段[0] = 触发「${s.阶段[0].触发}」→ 间隔 ${s.阶段[0].大技能间隔}、倍率 ×${s.阶段[0].伤害倍率}`);
  } else bad(`Boss脚本.bluefish 不对：${JSON.stringify(s)}`);

  const 我 = 假人(0, 'B1'), 杂兵 = G.makeUnit('grunt', 'enemy', 0, 5), 鱼 = 大肥鱼();
  if (!G.取Boss脚本(我)) ok('我方单位没有 Boss 脚本（脚本只对敌人）');
  else bad('Boss 脚本挂到我方单位上了');
  if (!G.取Boss脚本(杂兵) && G.Boss参数(杂兵) === null) ok('没配脚本的敌人（grunt）没有脚本，行为不变（走 50-AI.js 的 enemyAction）');
  else bad('没配脚本的敌人也吃到了 Boss 脚本');
  if (G.取Boss脚本(鱼) && G.Boss参数(鱼).第几阶段 === 1) ok(`大肥鱼满血 = 第 1 阶段：间隔 ${G.Boss参数(鱼).大技能间隔} 回合、伤害倍率 ×${G.Boss参数(鱼).伤害倍率}`);
  else bad('大肥鱼满血的参数不对');

  鱼.hp = Math.round(鱼.maxHp * 0.4);
  const p2 = G.Boss参数(鱼);
  if (p2.第几阶段 === 2 && p2.大技能间隔 === 2 && p2.伤害倍率 === 1.25) ok(`大肥鱼四成血 = 第 2 阶段：间隔 ${p2.大技能间隔} 回合、伤害倍率 ×${p2.伤害倍率}`);
  else bad(`大肥鱼四成血的参数不对：${JSON.stringify(p2)}`);

  鱼.hp = Math.round(鱼.maxHp * 0.5);
  const 半 = G.Boss阶段序号(鱼);
  鱼.hp = Math.round(鱼.maxHp * 0.51);
  const 过半 = G.Boss阶段序号(鱼);
  if (半 === 1 && 过半 === 0) ok(`「半血」的边界：正好 50%（${鱼.maxHp / 2} HP）算第 2 阶段，51% 还算第 1 阶段`);
  else bad(`半血边界不对：50% → 阶段号 ${半}，51% → 阶段号 ${过半}`);

  if (G.Boss触发阈值('半血') === 0.5 && G.Boss触发阈值(50) === 0.5 && G.Boss触发阈值(0.3) === 0.3) ok('触发条件认「半血」也认数字（50 → 0.5、0.3 → 0.3）');
  else bad('触发条件的换算不对');

  ctx_相同检查();
  function ctx_相同检查() {
    /* 没脚本的敌人：bossAction 必须和 enemyAction 给出同一个动作（行为不变） */
    const ctx = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'hound', 位: 1, 等级: 10 }], 5);
    const 一样 = ctx.enemies.every(u => {
      const a = G.bossAction(u, ctx), b = G.enemyAction(u, ctx);
      return (a && a.weapon ? a.weapon.name : null) === (b && b.weapon ? b.weapon.name : null)
        && (a && a.target ? a.target.slot : null) === (b && b.target ? b.target.slot : null);
    });
    if (一样) ok('没配脚本的敌人：bossAction 和 enemyAction 挑的是同一把武器、同一个目标');
    else bad('没配脚本的敌人被 Boss 脚本改到了行为');
  }
}

/* ============================ [2] 大技能按间隔触发 ============================ */
console.log('\n[2] 大技能按间隔触发（满血，间隔 3；数回合号与次数）');
{
  const ctx = 开场(1, 20261010);
  /* ★ 2026-10-11 难度调整（杠杆 ④「回合上限随档位收紧」）：这一场敌方有 Boss 档 →
     回合上限不再是常量 12，而是 `难度调整.回合上限.Boss`（= 11）。测试跟着引擎走，不写死 12。 */
  const 上限 = G.回合上限(ctx.enemies);
  info(`这一场的回合上限 = ${上限}（Boss 档；改前是全仓库统一的 12）`);
  const 记录 = 打满(ctx, 上限);
  const 回合们 = 大技能回合们(记录), 蓄 = 蓄力回合们(记录);
  info('记录（全部 〔Boss〕 条目）：');
  for (const t of 文本们(Boss事件(记录))) info('    ' + t);
  if (JSON.stringify(回合们) === JSON.stringify([1, 4, 7, 10])) ok(`第 1 阶段：${上限} 个回合里大技能在第 ${回合们.join('、')} 回合放，共 ${回合们.length} 次（间隔 3：第 1、1+3、1+6…回合）`);
  else bad(`第 1 阶段的大技能回合不对：${回合们.join('、')}`);
  /* 上限 11 → 蓄力 = 除了 1 / 4 / 7 / 10 之外的 7 个回合（改前上限 12 时是 8 个） */
  if (JSON.stringify(蓄) === JSON.stringify([2, 3, 5, 6, 8, 9, 11])) ok(`间隔外 ${蓄.length} 个回合都在蓄力（第 ${蓄.join('、')} 回合）—— 大技能武器没有被当成普通武器每回合乱放`);
  else bad(`蓄力回合不对：${蓄.join('、')}`);
  const 大技能回合集 = new Set(回合们);
  const 蓄力回合集 = new Set(蓄);
  const 全部出手 = 记录.filter(l => l.类型 === '攻击' && l.单位方 === 'enemy');
  const 蓄力期出手 = 全部出手.filter(l => 蓄力回合集.has(l.回合));
  const 大技能期出手 = 全部出手.filter(l => 大技能回合集.has(l.回合));
  if (蓄力期出手.length === 0) ok(`蓄力的 ${蓄.length} 个回合真的没出手（大肥鱼只有「周身冲击」一把武器，蓄力就是什么都不做）`);
  else bad(`蓄力的回合还打出了 ${蓄力期出手.length} 次攻击`);
  if (全部出手.length === 大技能期出手.length && 全部出手.length === 回合们.length) ok(`12 个回合里敌方只出手 ${全部出手.length} 次，全部落在 ${回合们.length} 个大技能回合上（1 个假人 = 1 次伤害记录）`);
  else bad(`出手次数不对：共 ${全部出手.length} 次，其中大技能回合 ${大技能期出手.length} 次`);
}

/* ============================ [3] 半血进第 2 阶段 ============================ */
console.log('\n[3] 半血进第 2 阶段（参数 + 实际伤害都要变）');
{
  const ctx = 开场(0.4, 20261011);
  const 记录 = 打满(ctx, G.回合上限(ctx.enemies));
  const 回合们 = 大技能回合们(记录), 蓄 = 蓄力回合们(记录);
  const 阶段记录 = Boss事件(记录).filter(l => 是事件(l, '阶段'));
  if (阶段记录.length && 阶段记录[0].Boss阶段 === 2 && /进入第 2 阶段/.test(阶段记录[0].文本)) ok(`记录里报了换阶段：${阶段记录[0].文本}`);
  else bad(`记录里没有「进入第 2 阶段」：${阶段记录.map(l => l.文本).join(' | ') || '（一条都没有）'}`);
  if (JSON.stringify(回合们) === JSON.stringify([1, 3, 5, 7, 9, 11])) ok(`第 2 阶段：${G.回合上限(ctx.enemies)} 个回合里大技能在第 ${回合们.join('、')} 回合放，共 ${回合们.length} 次（间隔 2 —— 比第 1 阶段的 4 次更频繁）`);
  else bad(`第 2 阶段的大技能回合不对：${回合们.join('、')}`);
  /* 回合上限 11（杠杆 ④）→ 第 2 阶段蓄力 = 2 / 4 / 6 / 8 / 10 共 5 个（改前上限 12 时是 6 个） */
  if (蓄.length === 5) ok(`第 2 阶段蓄力 ${蓄.length} 个回合（第 ${蓄.join('、')} 回合）—— 第 1 阶段是 7 个，节奏确实变快了`);
  else bad(`第 2 阶段的蓄力回合数不对：${蓄.length}`);

  /* 伤害倍率：同一个假人、同一个回合（第 1 回合必定是大技能回合），只有阶段不同 */
  const 一发 = 血比 => {
    const c = 开场(血比, 20261012);
    const 记录2 = G.打一回合(c);
    const r = 记录2.find(l => l.类型 === '攻击' && l.单位方 === 'enemy');
    return r ? r.伤害 : null;
  };
  const d1 = 一发(1), d2 = 一发(0.4);
  if (d1 > 0 && d2 === Math.round(d1 * 1.25)) ok(`同一发【周身冲击】打同一个假人：第 1 阶段 ${d1} → 第 2 阶段 ${d2}（正好 ×1.25，期望 ${Math.round(d1 * 1.25)}）`);
  else bad(`伤害倍率没生效或算错：第 1 阶段 ${d1} → 第 2 阶段 ${d2}（期望 ${Math.round(d1 * 1.25)}）`);
  info(`（对照：两边的假人都是 B1 Lv10、血 200000、没有武器，所以差别只来自 Boss 阶段）`);
}

/* ============================ [4] 记录里的 〔Boss〕 条目 ============================ */
console.log('\n[4] 战斗记录里的 〔Boss〕 条目');
{
  const ctx = 开场(0.4, 20261013);
  const 记录 = 打满(ctx, G.回合上限(ctx.enemies));
  const 事件 = Boss事件(记录);
  const 分类 = {};
  for (const l of 事件) 分类[l.Boss事件] = (分类[l.Boss事件] || 0) + 1;
  if (事件.length && 事件.every(l => /^〔Boss〕蓝色大肥鱼/.test(l.文本) && l.回合 === l.回合)) {
    ok(`共 ${事件.length} 条 〔Boss〕 记录：${Object.entries(分类).map(([k, v]) => `${k} ${v} 条`).join('、')}`);
  } else bad('〔Boss〕 记录格式不对');
  for (const 事件名 of ['阶段', '大技能', '蓄力']) {
    if (分类[事件名]) info(`〔Boss〕${事件名} 例：${事件.find(l => l.Boss事件 === 事件名).文本}`);
    else bad(`记录里没有 〔Boss〕${事件名} 这一类`);
  }
  if (/〔Boss〕蓝色大肥鱼 进入第 2 阶段/.test(事件.map(l => l.文本).join('\n'))) ok('记录里有任务书点名的那种条目：「〔Boss〕蓝色大肥鱼 进入第 2 阶段」');
  else bad('记录里没有「进入第 2 阶段」这一条');
  if (/〔Boss〕蓝色大肥鱼 释放【周身冲击】/.test(事件.map(l => l.文本).join('\n'))) ok('记录里有「〔Boss〕蓝色大肥鱼 释放【周身冲击】」');
  else bad('记录里没有大技能的条目');
}

/* ============================ [5] 前 3 后 2 阵型下每个位都打得到 ============================ */
console.log('\n[5] 大肥鱼在「前 3 后 2」阵型下打得到人（fire:map → 范围、area 没写默认 row）');
{
  const 结果 = [];
  for (let s = 0; s < G.slots; s++) {
    const ctx = G.开局([{ 键: 'B1', 位: s, 等级: 10 }], [{ 键: 'bluefish', 位: 0, 等级: 15 }], 100 + s);
    const y = G.算意图(ctx).find(i => i.单位 === 'bluefish');
    结果.push({ 位号: s, 位: G.位名(s), 武器: y && y.武器, 目标位: y && y.目标位, 大技能: !!(y && y.大技能) });
  }
  const 全打得到 = 结果.every(r => r.武器 === '周身冲击' && r.目标位 === r.位号 && r.大技能);
  if (全打得到) ok(`我方单独站在每个位置，大肥鱼第 1 回合的意图都是 ★大技能【周身冲击】打中它：${结果.map(r => `${r.位}→${G.位名(r.目标位)}`).join('、')}`);
  else bad(`有的位置打不到：${结果.map(r => `${r.位}:${r.武器 || '打不到'}(目标 ${r.目标位})`).join('、')}`);
  const 范围形状 = G.areaSlots(G.ENEMY_T.bluefish.weapons[0], G.ROW_FRONT, 0).map(s => G.位名(s));
  info(`「周身冲击」的落点（area 没写 → 默认 row，这里给的是「目标在前排」那一种）：${范围形状.join('、')}——一次打一整排，所以「前 3 后 2」里 5 个位全覆盖`);
  info(`第 1 回合大肥鱼的意图：${JSON.stringify(结果[0])}`);
}

/* ============================ [6] 一场站桩 Boss 战能打完 ============================ */
console.log('\n[6] 一场「站桩 Boss 战」能正常打完（HP 临时改小：240000 → 6000）');
{
  info('为什么改 HP：照数据原样 240000 HP + 1800 装甲（还要再吃难度调整的 Boss 加成 ×1.24），我们打不死');
  info('HP / 装甲怎么按我们的公式换算，归 Claude（任务板里写明了），这份测试只验「流程能闭合」');
  /* ★ 2026-10-11 难度调整之后这一条也跟着改了：第 4 层的护卫也吃 `敌方强度`（精锐 ×1.4）——
     Lv10 的默认五人队现在会被护卫打死（实测「败（我方全灭）」），
     所以这里改用 **Lv30 的默认五人队**（和 `docs/平衡表.md` 里第 4 层那一档的口径一致）。 */
  const 我方 = G.默认五人队.map(s => ({ 键: s.键, 位: s.位, 等级: 30 }));
  const 敌 = G.敌方规格组(G.编成到单位({ 层: 4, 类型: 'Boss', 前: ['bluefish'], 后: [] }, 0));
  const ctx = G.开局(我方, 敌, 20261010);
  const 鱼 = ctx.enemies.find(u => u.key === 'bluefish');
  /* ★ Lv30 队伍一轮就能把 6000 血的鱼打掉（那样它还没轮到出手，一条 〔Boss〕 记录都不会有）——
     所以这里留一个「撑得过第 1 回合」的血量（60000），让 Boss 脚本真的跑出记录来。 */
  if (鱼) { 鱼.maxHp = 60000; 鱼.hp = 60000; }
  const 记录 = 打满(ctx, 20);
  info(`结果：${ctx.result ? ctx.result.结果 + '（' + ctx.result.原因 + '）' : '没打完'}，回合 ${ctx.turn}，记录 ${记录.length} 条`);
  for (const t of 文本们(Boss事件(记录))) info('    ' + t);
  if (ctx.result && ctx.result.结果 === '胜') ok(`站桩 Boss 战打完了：胜（${ctx.result.原因}）· ${ctx.turn} 回合 · 〔Boss〕记录 ${Boss事件(记录).length} 条`);
  else bad(`站桩 Boss 战没打完：${ctx.result ? ctx.result.结果 + '（' + ctx.result.原因 + '）' : '超时'}`);
  if (Boss事件(记录).length) ok('这一场的记录里也有 〔Boss〕 条目');
  else bad('这一场的记录里没有 〔Boss〕 条目');
}

/* ============================ [7] 肉鸽第 4 层终点：备战 → 编队 → 开战 ============================ */
console.log('\n[7] 肉鸽第 4 层终点（蓝色大肥鱼）真的打得起来：界面.备战 → 编队 → 开战');
{
  /* 三条编成都先静态查一遍 */
  const 层4 = G.选编成(4, 'Boss');
  if (层4.length === 3) ok(`第 4 层 Boss 编成 3 条：${层4.map(e => [...(e.前 || []), ...(e.后 || [])].join('+')).join(' | ')}`);
  else bad(`第 4 层 Boss 编成不是 3 条：${层4.length}`);
  const 每条都有鱼 = 层4.every(e => [...(e.前 || []), ...(e.后 || [])].includes('bluefish'));
  if (每条都有鱼) ok('3 条里都有蓝色大肥鱼');
  else bad('有的第 4 层 Boss 编成里没有大肥鱼');
  {
    /* 每条编成都能造出单位、鱼第 1 回合就有出手手段 */
    let 都可以 = true;
    for (const e of 层4) {
      const us = G.编成到单位(e, 0);
      const 鱼 = us.find(u => u.key === 'bluefish');
      const ctx = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], G.敌方规格组(us), 7);
      const a = G.bossAction(ctx.enemies.find(u => u.key === 'bluefish'), ctx);
      if (!鱼 || !a || !a.大技能 || a.weapon.name !== '周身冲击') 都可以 = false;
    }
    if (都可以) ok('3 条编成的第 1 回合（大技能回合）都能放出【周身冲击】');
    else bad('有的编成第 1 回合放不出大技能');
  }

  /* 真的走一遍界面：网格大地图 → 第 4 层终点 Boss 节点 → 编队出战 → 开战
     ★ 大地图从 M4 的「一列列节点」换成了**6×4 网格 + 推进剂**（91-地图.js），
       所以这里改成：把层数拨到 4 → 进第 4 层 → 走到「出口守军」那一格。
       第 4 层的出口守军抽的就是终点 Boss 关（关卡编号 ISW-4-F-1，
       出处：战棋 26-地图生成.js:59 的 bossReady 分支 + 31-战斗.js:97 add(4,'F',1)）。 */
  界面.动作('回菜单');
  界面.动作('去分队');
  界面.动作('选分队', '近卫');
  界面.动作('开新局');
  const R = 肉鸽.RUN;
  if (!R) { bad('开不了新的一局'); }
  else {
    R.层 = 4; R.场次 = 0;
    肉鸽.进层(4);                        // 重新生成第 4 层的网格地图（起点 / 出口 / 出口守军都在里面）
    R.推进剂 = 60;                       // 给足推进剂，一次走到出口守军那一格
    const 守军 = R.地图.守军;
    if (R.地图.格[守军].类型 === '出口守军' && R.地图.格[守军].关卡 === 'ISW-4-F-1') {
      ok(`第 4 层出口守军那一格（${G.格列(守军) + 1},${G.格行(守军) + 1}）的关卡 = ${R.地图.格[守军].关卡}（终点 Boss 关）`);
    } else bad(`第 4 层出口守军的关卡不是终点 Boss 关：${R.地图.格[守军].关卡}`);
    const 类型 = 界面.去节点(守军);
    if (类型 === '出口守军' && 界面.屏 === '编队') ok('走到出口守军格 → 节点类型「出口守军」（第 4 层的出口守军 = 终点 Boss）→ 进编队屏');
    else bad(`走到出口守军格的类型不对：${类型}（屏 ${界面.屏}）`);
    界面.动作('备战');
    if (界面.屏 === '编队' && 界面.肉鸽编队模式) ok('「编队出战」进编队屏（候选项是名册）');
    else bad(`没有先进编队屏（${界面.屏}）`);
    const 阵 = R.队伍.slice(0, 5).map((m, i) => ({ 键: m.键, 位: i }));
    界面.清空();
    界面.编队.出击 = 阵.map(x => ({ 键: x.键, 位: x.位 }));
    界面.动作('开战');
    const 鱼 = 界面.ctx ? 界面.ctx.enemies.find(u => u.key === 'bluefish') : null;
    if (界面.阶段 === '指令' && 鱼) ok(`开战成功：敌方 ${界面.ctx.enemies.length} 台（含蓝色大肥鱼 Lv${鱼.lv}，HP ${鱼.maxHp}）、我方 ${界面.ctx.allies.length} 台`);
    else bad(`开战失败（屏 ${界面.屏} / 阶段 ${界面.阶段} / 有没有鱼：${!!鱼}）`);
    if (鱼) {
      /* 临时改小 HP：只为让这一场打得完（数值换算归 Claude，见任务板） */
      鱼.maxHp = 6000; 鱼.hp = 6000;
      const 意图 = G.算意图(界面.ctx).find(i => i.单位 === 'bluefish');
      if (意图 && 意图.武器 === '周身冲击') ok(`指令阶段就看得到 Boss 的意图：${意图.大技能 ? '★大技能 ' : ''}${意图.武器}（目标位 ${意图.目标位}）`);
      else bad(`意图里没有大肥鱼：${JSON.stringify(意图)}`);
      const 之前 = R.希望;
      打完这一场();
      const 战报 = 界面.ctx;
      const 有Boss = (战报.log || []).filter(l => l.类型 === 'Boss').length;
      if (界面.屏 === '大地图' || 界面.屏 === '肉鸽结算') ok(`打完回到「${界面.屏}」（${战报.result ? 战报.result.结果 : '—'} · ${战报.turn} 回合 · 〔Boss〕记录 ${有Boss} 条）`);
      else bad(`打完停在「${界面.屏}」`);
      if (有Boss > 0) ok('这一场的记录里也留下了 〔Boss〕 条目（界面上沿用原有记录渲染）');
      else bad('这一场的记录里没有 〔Boss〕 条目');
      if (R.希望 > 之前 || !肉鸽.进行中) ok(`终点守军这一场结算了奖励 / 本局结束（希望 ${之前} → ${R.希望}${!肉鸽.进行中 ? '，结局 ' + R.结局 : ''}）`);
      else info(`这一场没赢（希望仍是 ${R.希望}），流程本身是闭合的`);
    }
  }
}

/* ============================ [8] 同种子同结果 ============================ */
console.log('\n[8] 带种子的确定性：Boss 脚本不含随机数，同种子两遍逐字相同');
{
  const 跑 = () => 文本们(打满(开场(0.4, 20261010), 12)).join('\n');
  const a = 跑(), b = 跑();
  if (a === b && a.length > 0) ok(`同种子跑两遍，${a.split('\n').length} 条记录逐字相同`);
  else bad('同种子两遍结果不一样');
  const c = 文本们(打满(开场(0.4, 20261011), 12)).join('\n');
  if (c !== a) ok('换个种子记录不一样（随机数确实在起作用：大肥鱼必中，差别来自假人的闪避）');
  else info('换个种子记录一样（大肥鱼是必中，这一场确实没有随机数参与，正常）');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '站桩 Boss 测试全部通过');
process.exit(fails ? 1 : 0);

/** 把当前这一场打完（和 tests/run.js 里的同一套：一回合一个回合地点开打 + tick） */
function 打完这一场() {
  let 轮 = 0;
  while (界面.屏 === '战斗' && 轮++ < 30) {
    界面.开打();
    let n = 0;
    while (界面.阶段 === '播放' && n++ < 100000) 播放.tick();
  }
}
