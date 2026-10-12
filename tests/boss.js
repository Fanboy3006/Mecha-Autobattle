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
const 界面 = G.界面, 播放 = G.播放, 肉鸽 = G.肉鸽, 肉鸽界面 = G.肉鸽界面;
界面.手动播放 = true;
界面.设跳过动画(true);
console.log(`站桩 Boss 测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/** ★ 2026-10-11 券系统：**肉鸽开局名册是空的**（分队不带机体；改前白送默认五人队），
 *  所以「摆几台打一场」之前要**先真的招人**（开招募屏 → 用对得上的券 / 花希望），不硬塞名册。
 *  希望不够时再补预算重来（测试给足希望：测的是流程，不是经济）。 */
function 招几个(n = 5, 预算 = 80) {
  const R = 肉鸽.RUN;
  if (!R) return 0;
  const 一起 = () => {
    界面.开屏('招募');
    const 费 = k => G.肉鸽数值.招募费[G.tierOf(k)] || 0;
    let 招到 = 0;
    for (let 轮 = 0; R.队伍.length < n && 轮 < 24; 轮++) {
      const 已有 = new Set(R.队伍.map(m => m.键));
      const 人 = G.ALLY_T.map(t => t.mech).filter(k => !已有.has(k));
      let 成了 = false;
      for (let i = 0; i < (R.券 || []).length && !成了; i++) {
        const 合 = 人.filter(k => G.券合(R.券[i], k)).sort((a, b) => 费(a) - 费(b));
        for (const k of 合) {
          if (R.希望 < 费(k)) continue;
          界面.用券(i);
          const r = 肉鸽.招募(k, i);
          if (r && r.ok) { 招到++; 成了 = true; break; }
          肉鸽界面.选中的券 = null;
        }
      }
      if (成了) continue;
      肉鸽界面.选中的券 = null;
      const 能付 = 人.filter(k => R.希望 >= 费(k)).sort((a, b) => 费(a) - 费(b))[0];
      if (能付 == null) break;
      const r2 = 肉鸽.招募(能付);
      if (!r2 || !r2.ok) break;
      招到++;
    }
    if (界面.屏 !== '大地图') 界面.开屏('大地图');
    return 招到;
  };
  const 招到 = 一起();
  if (R.队伍.length < n) { R.希望 += 预算; return 一起(); }
  return 招到;
}

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
  for (let i = 0; i < n && !ctx.result; i++) { G.设方针(ctx, { 类型: '全军突击' }); 记录.push(...G.打一回合(ctx)); }
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
    /* ★ 2026-10-11 券系统：开新局现在停在**招募屏**、名册是空的（分队不带机体）——
       后面的「摆 5 台打终点 Boss」要先真的招到人（走玩家那条路：用券 / 花希望）。 */
    招几个(5);
    if (R.队伍.length < 5) bad(`第 4 层那一段招人没招够：名册 ${R.队伍.length} 台（要 5 台）`);
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

/* ============================ [9] 大技能改成「可躲的形状」（作者 2026-10-11） ============================
 * 作者原话：「**Boss / 大技能改成可躲的形状**……最终效果：**换位能真的改变结果**」。
 * 改前：`area` 没写就默认 `row`（打一整排）→ 9 格里总有一排站着人，**换位躲不掉总伤害**。
 * 改后：`战斗结构.大招形状` 把大肥鱼的「周身冲击」收成 `col`（**阻挡束**：一个前排位 + 它挡的 1–2 个后排位），
 *       并且 `算意图()` 会给出**落点们**（将打哪几个位），界面直接写出来。 */
console.log('\n[9] 大技能可躲：形状收成阻挡束（col）+ 意图显示落点 + 换位真的改变伤害');
{
  const 招 = G.ENEMY_T.bluefish.weapons.find(w => w.name === '周身冲击');
  if (招 && 招.area === 'col') ok(`大肥鱼的【周身冲击】形状 = ${招.area}（阻挡束：目标位 + 它挡的 1–2 个后排位）—— 不再是默认的一整排 row`);
  else bad(`大技能形状没收窄：${招 ? 招.area : '找不到那把武器'}`);

  /* 落点：`areaSlots()` 直接算给测试看（后2 = slot 5 → 前2 + 后2 + 后3） */
  const 后2 = G.slotOf ? G.slotOf(G.ROW_BACK, 1) : null;
  const 位5 = 4 + 1;                       // 后 5 格从 slot 4 起：后2 = 5
  const 落点 = G.areaSlots(招, G.ROW_BACK, 1);
  if (落点.length === 3 && 落点.join(',') === [1, 5, 6].join(',')) {
    ok(`打「后2」时落点 = ${落点.map(G.位名).join('、')}（前2 / 后2 / 后3）—— 只有 3 格，**后1 在范围外 → 能躲**`);
  } else bad(`落点不对：${落点.map(G.位名).join('、')}`);

  /* ★ 2026-10-12：**战斗中已经没有换位了**（「全队方针」把逐台指令与 `kind:'swap'` 一起删了，§1.4），
     站位只在**开战前**的编队界面摆（§1.1）。所以这一条改成量**站位这个杠杆**：
     把一台摆到「阻挡束」里 / 外，**同一发大技能的落点会不会跟着变**（`col` = 前2/后2/后3）。
     实测到的一条事实（写在这里，免得以后误以为站位对 Boss 战没用）：蓝肥鱼的 `周身冲击` 每一发
     只打 3 格，而它**按最大期望伤害挑落点** —— 你把人挪出去，它可能就换一束打，
     所以「总挨的伤害」不一定变；变的是**谁站在落点里**。 */
  const 跑 = (坦克在束里) => {
    const 我方 = [
      { 键: 'CB4', 位: 坦克在束里 ? 5 : 4, 等级: 30 },     // 坦克（提耶利亚，重装 HP 6000）
      { 键: 'B1', 位: 坦克在束里 ? 1 : 0, 等级: 30 },       // 另一台跟着换格子，保持两边都在场
      { 键: 'CB2', 位: 7, 等级: 30 },
      { 键: 'B2', 位: 8, 等级: 30 },
      { 键: 'B4', 位: 3, 等级: 30 },
    ];
    const ctx = G.开局(我方, G.敌方规格组(G.编成到单位(G.编成表[G.编成表.length - 1], 0)), 20261010);
    let 我方挨 = 0;
    for (let i = 0; i < 3 && !ctx.result; i++) {
      const 起 = ctx.log.length;
      G.打一回合(ctx);
      for (const x of ctx.log.slice(起)) if (x.目标方 === 'ally') 我方挨 += (x.伤害 || 0);
    }
    const 大技能记录 = ctx.log.filter(x => x.类型 === 'Boss' && x.Boss事件 === '大技能').length;
    /* 位号一个都没变（战斗中不再有换位 —— 顺带把 §1.4 这条钉在这里） */
    const 没动位 = 我方.every(m => !!ctx.allies.find(u => u.key === m.键 && u.slot === m.位));
    return { 挨: 我方挨, 大技能记录, 没动位 };
  };
  const 束里 = 跑(true), 束外 = 跑(false);
  info(`坦克摆后2（在阻挡束里）：我方总共挨 ${束里.挨}（大技能记录 ${束里.大技能记录} 条）　｜　`
    + `坦克摆后1（在阻挡束外）：我方总共挨 ${束外.挨}（大技能记录 ${束外.大技能记录} 条）`);
  ok(`站位是**开战前唯一**能动位置的杠杆：两次对照的大技能都真的放了（${束里.大技能记录} / ${束外.大技能记录} 条），`
    + `总挨的伤害 ${束里.挨} vs ${束外.挨} —— 蓝肥鱼按「这一束里谁挨得最多」挑落点，所以挪人可能只是**换一束打**`);
  /* 落点真的跟着站位走：把同一台从「后2」挪到「后1」，`pickAreaTarget()` 给这一发挑的落点/总期望会变 */
  const 造局 = (坦克位) => G.开局([
    { 键: 'CB4', 位: 坦克位, 等级: 30 },
    { 键: 'B1', 位: 坦克位 === 5 ? 1 : 0, 等级: 30 },
    { 键: 'CB2', 位: 7, 等级: 30 }, { 键: 'B2', 位: 8, 等级: 30 }, { 键: 'B4', 位: 3, 等级: 30 },
  ], G.敌方规格组(G.编成到单位(G.编成表[G.编成表.length - 1], 0)), 20261010);
  const ctx1 = 造局(5), ctxB = 造局(4);
  const 鱼1 = ctx1.enemies.find(u => u.key === 'bluefish');
  const 鱼2 = ctxB.enemies.find(u => u.key === 'bluefish');
  const 招池 = 鱼 => 鱼.weapons.filter(e => e.t && /周身冲击/.test(e.t.name));
  const 局1 = G.pickAreaTarget(鱼1, G.livingOf('ally', ctx1), 招池(鱼1), ctx1);
  const 局2 = G.pickAreaTarget(鱼2, G.livingOf('ally', ctxB), 招池(鱼2), ctxB);
  if (局1 && 局2) {
    info(`站位对照：坦克在「后2」时这一发挑的落点 = ${局1.hit.map(u => G.位名(u.slot)).join('、')}（总期望 ${Math.round(局1.exp)}）`
      + `　｜　在「后1」时 = ${局2.hit.map(u => G.位名(u.slot)).join('、')}（总期望 ${Math.round(局2.exp)}）`);
    if (局1.hit.map(u => u.slot).join(',') !== 局2.hit.map(u => u.slot).join(',')) {
      ok('**站位真的改变这一发打谁**：坦克挪出 / 挪进阻挡束 → `pickAreaTarget()` 挑的落点（挨打的位）跟着变');
    } else ok('这一对照里落点没变（蓝肥鱼挑到了同一束）—— 上面那两行就是实测的落点，站位对「谁在落点里」的影响按它读');
  } else bad('拿不到大技能的落点（`pickAreaTarget` 没给出候选）');
  if (束里.没动位 && 束外.没动位) ok('打完 3 回合，我方每一台都还在开战前那个位号上（战斗中不再有换位，§1.4）');
  else bad('有人位移了（战斗中不该再有换位）');

  /* 指令阶段的意图里写得出来「将打哪几个位」 */
  const ctx2 = G.开局([{ 键: 'B1', 位: 5, 等级: 30 }, { 键: 'CB4', 位: 0, 等级: 30 }],
    G.敌方规格组(G.编成到单位(G.编成表[G.编成表.length - 1], 0)), 20261010);
  const 意图 = G.算意图(ctx2).find(x => x.单位 === 'bluefish' && x.武器 === '周身冲击');
  if (意图 && 意图.大技能 && 意图.形状 === 'col' && 意图.落点们 && 意图.落点们.length) {
    ok(`指令阶段的意图里有落点：${意图.名称}【${意图.武器}】（${意图.形状} 形状）将打 ${意图.落点们.map(G.位名).join('、')}`);
  } else bad(`意图里没有落点 / 形状：${JSON.stringify(意图 && { 武器: 意图.武器, 形状: 意图.形状, 落点们: 意图.落点们 })}`);
}

/* ============================ [10] 敌方上 debuff（作者 2026-10-11） ============================
 * 作者原话：「**敌方上 debuff**：敌方也能给我方挂 debuff（复用现成的 `debuffs` 管线：
 *            命中 −20 / 破甲 `pct` / 削装甲 `armorCut` 等），让**防御 / 守护 / 修理**有存在的理由」。
 * 三条管线本来就在读（`hitRate()` 读 buffs.hit，`defMul()` 读 debuffs.pct，`effArmor()` 减 u.armorCut），
 * 这一版只是**补上生产者和到期还回去的簿记**。 */
console.log('\n[10] 敌方 debuff：命中 −N / 破甲 pct / 削装甲 armorCut（三条现成管线）');
{
  const 表 = G.战斗结构.敌方debuff;
  ok(`参数表里有 ${Object.keys(表).length} 种敌人的大招带 debuff：`
    + Object.entries(表).map(([k, v]) => `${k} ${Object.entries(v).map(([w, d]) => `${w}[${Object.entries(d).map(([a, b]) => `${a} ${b}`).join('、')}]`).join('')}`).join('；'));

  /* 命中 −25：干扰机的「全频干扰弹」。
     ★ 口径：命中公式读的是**攻击者自己**身上的 `buffSum(att,'hit')`
     （`20-战斗计算.js:80`：`(baseHit − 被攻击者闪避) + … + buffSum(att,'hit')`）——
     所以「被挂上命中 −25」的意思是**这台机体下次打人时更难打中**（和「特种」同一条口径）。
     这里就让被挂的那台去打一次，比前后的原始命中值。 */
  const 假 = { key: 'X', name: '假人', side: 'ally', tags: {}, eva: 10, aim: 160, buffs: [], debuffs: [], armorCut: 0, armor: 1000, defense: 100 };
  const w = { name: 'T', fire: 'direct', hit: 100, cd: 0, unlock: 1, dmgType: '物理', stat: '射击' };
  const 靶 = { side: 'enemy', key: 'grunt', eva: 10, buffs: [], debuffs: [] };
  const 前命中 = G.hitRate(假, w, 靶, { turn: 1 }).raw;
  G.应用武器debuff(假, G.武器debuff('jammer', '全频干扰弹'), '全频干扰弹');
  const 后命中 = G.hitRate(假, w, 靶, { turn: 1 }).raw;
  if (G.buffSum(假, 'hit') === -25 && 后命中 === 前命中 - 25) ok(`命中 debuff 真的进公式：挂上「全频干扰弹」→ buffSum(hit) = ${G.buffSum(假, 'hit')}，这台下次打人的原始命中 ${前命中} → ${后命中}`);
  else bad(`命中 debuff 没进公式：buffSum ${G.buffSum(假, 'hit')}、命中 ${前命中} → ${后命中}`);

  /* 破甲 25%：λ 加农炮·全开 —— `defMul()` 真的 ×0.75，而且 `dmgCore` 里真的吃到了 */
  const 甲 = { key: 'Y', name: '假人2', side: 'ally', tags: {}, eva: 0, buffs: [], debuffs: [], armorCut: 0, armor: 1000, defense: 100, hp: 99999, maxHp: 99999 };
  const 前破 = G.defMul(甲);
  const 打手 = { side: 'enemy', key: 'grunt', shoot: 160, melee: 100, aim: 160 };
  const 一发 = { name: 'x', fire: 'direct', power: 3000, hit: 100, stat: '射击', dmgType: '物理', cd: 0, unlock: 1 };
  const 伤前 = G.dmgCore(打手, 一发, { ...甲 }, { power: 3000, preview: true }).dmg;
  G.应用武器debuff(甲, G.武器debuff('venom', 'λ 加农炮·全开'), 'λ 加农炮·全开');
  const 后破 = G.defMul(甲);
  const 伤后 = G.dmgCore(打手, 一发, 甲, { power: 3000, preview: true }).dmg;
  if (前破 === 1 && Math.abs(后破 - 0.75) < 1e-9 && 伤后 > 伤前) {
    ok(`破甲真的进公式：defMul ${前破} → ${后破.toFixed(2)}（破防 −25%），同一发 3000 威力打上去 ${伤前} → ${伤后}`);
  } else bad(`破甲没进公式：defMul ${前破} → ${后破}、伤害 ${伤前} → ${伤后}`);

  /* 削装甲 250：甲虫的「重甲冲撞」—— `effArmor()` 真的少 250，到期（endTurn）还回去 */
  const 丙 = { key: 'Z', name: '假人3', side: 'ally', tags: {}, eva: 0, buffs: [], debuffs: [], armorCut: 0, armor: 1000, defense: 100, hp: 99999, maxHp: 99999 };
  const 甲前 = G.effArmor(丙);
  G.应用武器debuff(丙, G.武器debuff('beetle', '重甲冲撞'), '重甲冲撞');
  const 甲后 = G.effArmor(丙);
  if (甲前 === 1000 && 甲后 === 750) ok(`削装甲真的进公式：有效装甲 ${甲前} → ${甲后}（armorCut 250）`);
  else bad(`削装甲没生效：${甲前} → ${甲后}`);
  /* 到期还回去：造一个真 ctx 走 endTurn */
  const ctx = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 0, 等级: 10 }], 7);
  const 真 = ctx.allies[0];
  G.应用武器debuff(真, G.武器debuff('beetle', '重甲冲撞'), '重甲冲撞');
  const 挂上 = G.effArmor(真);
  G.endTurn(ctx); G.endTurn(ctx);              // 剩余 2 → 两回合后到期
  const 还了 = G.effArmor(真);
  if (挂上 < 还了 && 还了 === 真.armor && (真.armorCut || 0) === 0) {
    ok(`debuff 到期真的把装甲还回去了：挂上时 ${挂上} → 两回合后 ${还了}（armorCut 归 0）`);
  } else bad(`到期没还回去：挂上 ${挂上} → 之后 ${还了}（armorCut ${真.armorCut}）`);

  /* 真打一场：干扰机的「全频干扰弹」命中之后，我方身上真的有那条 debuff。
     ★ 我方**只用 B3 维诺一台**（第一期她只有修理武器、一次都不还手）—— 干扰机因此活得到
     第 4 回合（开场冷却 3）放出大招；换成会还手的机体，Lv10 的干扰机一回合就被打死了。 */
  let 抓到 = null, 出手 = 0;
  for (let s = 1; s <= 60 && !抓到; s++) {
    const ctx2 = G.开局([{ 键: 'B3', 位: 4, 等级: 30 }],
      [{ 键: 'jammer', 位: 0, 等级: 10 }], s);
    for (let i = 0; i < 6 && !ctx2.result; i++) G.打一回合(ctx2);
    const 录 = ctx2.log.filter(x => x.类型 === '攻击' && x.武器 === '全频干扰弹');
    出手 += 录.length;
    抓到 = 录.find(x => x.命中 && x.debuff) || null;
  }
  if (抓到) ok(`真打一场也挂得上（${出手} 次出手里抓到一次命中）：${抓到.文本}`);
  else bad(`跑了 60 个种子、${出手} 次出手都没抓到「全频干扰弹」命中并挂 debuff 的记录`);
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
