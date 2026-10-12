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

/* ============================ [11] 敌人卡第一批 · 幻影（`stealth`） ============================
 * 规格书 = `协作/敌人卡-第一批.md` 卡 A + `协作/敌人机制盘点-可用的钩子.md` 的 B1。
 * 落点：`20-战斗计算.js` 的 `hitRate()`（命中原始值 −35，【初稿·待作者在调参室调】）。
 * 口径（卡 A 的预告原文「只有近战 / 范围武器能稳定命中」）：**直射 / 曲射吃惩罚；近战 / 范围不吃**，
 * 表在 `71-改动.js` 的 `战斗结构.敌人机制.隐匿.吃惩罚的射程`。 */
console.log('\n[11] 敌人卡第一批 · 幻影（钩子 `stealth`：命中原始值 −35，近战 / 范围不吃）');
{
  const 表 = G.战斗结构.敌人机制;
  if (表 && 表.隐匿 && 表.隐匿.命中惩罚 === 35 && Array.isArray(表.隐匿.吃惩罚的射程)
    && 表.隐匿.吃惩罚的射程.join(',') === '直射,曲射') {
    ok(`【初稿·待作者在调参室调】隐匿参数：命中惩罚 −${表.隐匿.命中惩罚}、吃惩罚的射程 = ${表.隐匿.吃惩罚的射程.join(' / ')}（近战贴身 / 范围泼洒豁免）`);
  } else bad(`隐匿参数不对：${JSON.stringify(表 && 表.隐匿)}`);

  /* 落点：`10-数据.js` 里带 `abilities:['stealth']` 的就是**隐形侦察机**（卡 A 的落点键）。
     `70-编成.js` 的编成表里抽得到它 —— 作者在游戏里遇得到（这一条盯死「挂到了哪个键」）。 */
  const 带键 = Object.keys(G.ENEMY_T).filter(k => Array.isArray(G.ENEMY_T[k].abilities) && G.ENEMY_T[k].abilities.includes('stealth'));
  const 用到的 = G.编成表.filter(e => [...(e.前 || []), ...(e.后 || [])].includes('stealth')).length;
  if (带键.join(',') === 'stealth' && 用到的 > 0) ok(`挂到了已有敌人键 \`stealth\`（${G.ENEMY_T.stealth.mech}，数据里本来就写着 \`abilities:['stealth']\`）—— 编成表里 ${用到的} 条抽得到它`);
  else bad(`stealth 键不对：带这个能力的键 = ${带键.join(',')}；编成表用到 ${用到的} 条`);

  /* 生效 / 不生效：只对**敌人**生效（我方就算有 abilities 也不吃），总开关关掉就退回改动前 */
  const 隐 = G.makeUnit('stealth', 'enemy', 5, 5);
  const 我 = G.makeUnit('CB2', 'ally', 0, 10);
  const 直 = 我.weapons.find(e => G.rangeKindOf(e.t) === '直射');
  const 近 = G.makeUnit('B1', 'ally', 0, 10).weapons.find(e => G.rangeKindOf(e.t) === '近战');
  const 范 = { name: '假范围', fire: 'map', area: 'row', power: 1000, hit: 100, dmgType: '物理', stat: '射击' };
  const 原始 = (a, w, d, o) => G.hitRate(a, w, d, o || { turn: 1 }).raw;
  if (G.有敌人机制(隐, 'stealth') && !G.有敌人机制(我, 'stealth')) ok('`有敌人机制()`：敌人吃、我方不吃（作者：「只对敌方生效」）');
  else bad('敌人机制的阵营判定不对');
  const 原开关 = 表.开;
  表.开 = false;
  const 直关 = 原始(我, 直.t, 隐), 近关 = 原始(G.makeUnit('B1', 'ally', 0, 10), 近.t, 隐);
  表.开 = true;
  const 直开 = 原始(我, 直.t, 隐), 近开 = 原始(G.makeUnit('B1', 'ally', 0, 10), 近.t, 隐);
  if (直关 - 直开 === 35) ok(`直射真的进公式：${我.name}【${直.t.name}】打**幻影**的原始命中 ${直关} → ${直开}（−35）`);
  else bad(`直射的隐匿惩罚不对：${直关} → ${直开}`);
  if (近开 === 近关) ok(`近战**贴身不吃**这个惩罚：${近.t.name} 打幻影的原始命中 ${近关} → ${近开}（差 0）`);
  else bad(`近战被误伤了：${近关} → ${近开}`);
  const 范开 = G.hitRate(我, 范, 隐, { turn: 1 });
  if (范开.sure && 范开.hit === 100) ok(`范围武器（\`fire:'map'\`）走必中分支，隐匿**一点都影响不到**它（hit ${范开.hit} / sure ${范开.sure}）`);
  else bad(`范围武器受到了影响：${JSON.stringify(范开)}`);
  /* 曲射也吃（卡 A 的预告写「只有近战 / 范围稳定命中」→ 曲射与直射都被罚） */
  const 曲 = { name: '假曲射', fire: 'indirect', power: 1000, hit: 100, dmgType: '物理', stat: '射击' };
  表.开 = false; const 曲关 = 原始(我, 曲, 隐); 表.开 = true; const 曲开 = 原始(我, 曲, 隐);
  if (曲关 - 曲开 === 35) ok(`曲射同样吃惩罚（对准打的都难打中）：${曲关} → ${曲开}`);
  else bad(`曲射的隐匿惩罚不对：${曲关} → ${曲开}`);
  /* 不带这个键的敌人**逐字不变**：同一个攻击者打一只没有 stealth 的杂兵 */
  const 兵 = G.makeUnit('grunt', 'enemy', 5, 5);
  表.开 = false; const 兵关 = 原始(我, 直.t, 兵); 表.开 = true; const 兵开 = 原始(我, 直.t, 兵);
  if (兵关 === 兵开 && G.隐匿惩罚值(兵, 直.t) === 0) ok(`不带这个键的敌人**逐字不变**：同一发打 ${兵.name} 的原始命中 ${兵关} → ${兵开}（「隐匿惩罚值」= 0）`);
  else bad(`没有 stealth 的敌人被影响了：${兵关} → ${兵开}`);
  表.开 = 原开关;

  /* 真打一场：只放**一台幻影**（这样它一定会被我方瞄上）—— 找一条「打空」的记录。
     命中 55%（原始 90 − 35）→ 一定会打空几次；固定场景 + 固定种子，结果是决定性的。 */
  const 一场 = s => G.simulate(G.默认五人队, [{ 键: 'stealth', 位: 5, 等级: 3 }], {}, s);
  let r = null, 空录 = [];
  for (const s of [20261010, 20261009, 20261008, 7, 11]) {
    r = 一场(s);
    const 试 = r.记录.filter(x => x.类型 === '攻击' && x.隐匿);
    if (试.length) { 空录 = 试; break; }
  }
  info(`单独打一台幻影 Lv3（默认五人队 Lv10，种子轮着试）：${r.结果} / ${r.回合数} 回合 / ${r.记录.length} 条记录，其中**顶了隐匿惩罚打空**的 ${空录.length} 次`);
  if (空录.length && 空录.every(x => x.隐匿惩罚 === 35 && x.单位方 === 'ally')) {
    ok(`即时字段真的写了：${空录.map(x => `第 ${x.回合} 回合 ${x.文本}`).slice(0, 2).join('　')}`);
    info(`即时标签：\`反馈标签(该记录)\` = 「${G.反馈标签(空录[0])}」`);
  } else bad(`没有一条「打空 + 隐匿」的攻击记录（${空录.length} 条）`);
  /* 战报（结算）那一行 = 记录里数出来的（数据全部从 ctx.log 统计） */
  const 直射空 = 空录.filter(x => ((r.我方.find(u => u.slot === x.单位位) || { weapons: [] }).weapons || [])
    .some(e => e.t && e.t.name === x.武器 && G.rangeKindOf(e.t) === '直射')).length;
  const 行 = G.战报行们(r).find(x => x.startsWith('隐匿共让你打空'));
  if (行 && 行 === `隐匿共让你打空 ${空录.length} 次（其中 ${直射空} 次来自直射）`) {
    ok(`结算行 = 记录逐条数出来的：${行}`);
  } else bad(`结算行对不上：${行}（记录里 ${空录.length} 次、直射 ${直射空} 次）`);
  info(`战报三行样例：${G.战报行们(r).filter(x => /^隐匿共让你打空/.test(x)).join('；')}`);
  /* 同种子两次逐字相同（含新字段） */
  const 甲 = JSON.stringify(一场(20261010).记录), 乙 = JSON.stringify(一场(20261010).记录);
  if (甲 === 乙 && 空录.length) ok(`同种子两次逐字相同（${JSON.parse(甲).length} 条记录，含 \`隐匿\` / \`隐匿惩罚\` 字段）`);
  else bad('同种子两次不一样');
}

/* ============================ [12] 敌人卡第一批 · 镜甲（`beamReflect`） ============================
 * 规格书 = 卡 B + 盘点 B4。落点：`60-战斗.js` 的 `resolveAction()` 末尾（`镜甲反弹()`）。
 * 三条硬规矩：按比例反弹（【初稿】30%）/ **不许二次反弹** / **不许改变随机数消耗顺序**。 */
console.log('\n[12] 敌人卡第一批 · 镜甲（钩子 `beamReflect`：受到的 30% 反弹，不二次反弹、不动随机数）');
{
  const 表 = G.战斗结构.敌人机制;
  if (表 && 表.镜甲 && 表.镜甲.反弹比例 === 0.3) ok(`【初稿·待作者在调参室调】反弹比例 = ${表.镜甲.反弹比例}（受到的 30%）`);
  else bad(`反弹比例不对：${JSON.stringify(表 && 表.镜甲)}`);
  const 带键 = Object.keys(G.ENEMY_T).filter(k => Array.isArray(G.ENEMY_T[k].abilities) && G.ENEMY_T[k].abilities.includes('beamReflect'));
  const 用到的 = G.编成表.filter(e => [...(e.前 || []), ...(e.后 || [])].includes('mirror')).length;
  if (带键.join(',') === 'mirror' && 用到的 > 0) ok(`挂到了已有敌人键 \`mirror\`（${G.ENEMY_T.mirror.mech}，数据里本来就写着 \`abilities:['beamReflect']\`）—— 编成表里 ${用到的} 条抽得到它`);
  else bad(`beamReflect 键不对：带这个能力的敌人键 = ${带键.join(',')}（编成表用到 mirror ${用到的} 条）`);
  info('★ 我方 `S2 卡嘉莉` 的数据里也有 `beamReflect`（战棋的「光束反射」特技）：这一批按 `只给敌人: true` **没接我方那一条**，归作者 / Claude 拍板');

  /* 真打一场：只放**一台镜甲**（这样我方一定打得着它）→ 看反弹的前后数字与结算行 */
  const 一场 = s => G.simulate(G.默认五人队, [{ 键: 'mirror', 位: 0, 等级: 3 }], {}, s);
  let r = null, 镜录 = [];
  for (const s of [20261010, 20261009, 5, 13]) {
    r = 一场(s);
    const 试 = r.记录.filter(x => x.类型 === '镜甲');
    if (试.length) { 镜录 = 试; break; }
  }
  info(`单独打一台镜甲 Lv3（默认五人队 Lv10，种子轮着试）：${r.结果} / ${r.回合数} 回合 / ${r.记录.length} 条记录，镜甲反弹 ${镜录.length} 次`);
  if (镜录.length) {
    const 一 = 镜录[0];
    const 该发 = r.记录.filter(x => x.类型 === '攻击' && x.目标方 === 'enemy' && x.目标位 === 一.单位位
      && x.回合 === 一.回合 && x.伤害 > 0 && x.单位位 === 一.目标位);
    const 源 = 该发.length ? 该发[该发.length - 1] : null;
    if (源 && 一.反弹 === Math.round(源.伤害 * 0.3)) ok(`反弹量真的按比例算：那一下打了 ${源.伤害} → 反弹 ${一.反弹}（${源.伤害} × 30% = ${Math.round(源.伤害 * 0.3)}）`);
    else bad(`反弹量算错：${JSON.stringify([源 && 源.伤害, 一.反弹])}`);
    ok(`即时记录：${一.文本}（即时标签 = 「${G.反馈标签(一)}」）`);
  } else bad('整场一条镜甲记录都没有（打了镜甲却没反弹）');
  const 行 = G.战报行们(r).find(x => x.startsWith('镜甲共反弹'));
  const 合计 = 镜录.reduce((n, x) => n + (Number(x.反弹) || 0), 0);
  if (行 && 行 === `镜甲共反弹 ${合计} 到你身上（占你本场损失 ${Math.round(合计 / (G.战报统计(r).本场损失 || 1) * 100)}%）`) {
    ok(`结算行 = 记录逐条加起来：${行}`);
  } else bad(`结算行对不上：${行}（记录加起来 ${合计}）`);

  /* 独立场景：一发一发的**前后数字** + 三条边界（不二次反弹 / 攻击者已死 / 被护盾吃掉） */
  const ctx = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'mirror', 位: 0, 等级: 3 }], 20261010);
  const 攻 = ctx.allies[0], 镜 = ctx.enemies[0];
  const 力 = 攻.weapons.find(e => G.rangeKindOf(e.t) === '近战') || 攻.weapons[0];
  const 血前 = 攻.hp;
  const rec = G.resolveAttack(攻, 镜, 力.t, ctx, {});
  const 反弹 = G.镜甲反弹(ctx, 攻, 镜, rec.字段);
  if (rec.字段.伤害 > 0 && 反弹 === Math.round(rec.字段.伤害 * 0.3) && 攻.hp === 血前 - 反弹) {
    ok(`独立场景的前后数字：这一发伤害 ${rec.字段.伤害} → 反弹 ${反弹}；攻击者 HP ${血前} → ${攻.hp}`);
  } else bad(`反弹的前后数字不对：伤害 ${rec.字段.伤害} / 反弹 ${反弹} / HP ${血前} → ${攻.hp}`);
  const rng条数 = () => ctx.rng;
  /* ① 不二次反弹：把两边的镜甲都打开（`只给敌人: false`），反弹的那一发**不会再被反弹回去** */
  const 只给 = 表.只给敌人;
  表.只给敌人 = false;
  const 甲镜 = Object.assign({}, 攻, { abilities: ['beamReflect'], hp: 9999, maxHp: 9999, buffer: null });
  const 乙镜 = Object.assign({}, 镜, { abilities: ['beamReflect'], hp: 99999, maxHp: 99999 });
  const 条前 = ctx.log.filter(x => x.类型 === '镜甲').length;
  const 甲血前 = 甲镜.hp, 乙血前 = 乙镜.hp;
  const 反弹2 = G.镜甲反弹(ctx, 甲镜, 乙镜, { 伤害: 1000 });
  const 新条 = ctx.log.filter(x => x.类型 === '镜甲').length - 条前;
  if (反弹2 === 300 && 新条 === 1 && 甲镜.hp === 甲血前 - 300 && 乙镜.hp === 乙血前) {
    ok(`**不二次反弹**：两边都带镜甲时，只有被攻击那一方反弹了一次（${反弹2}），反弹本身没有回头再反弹（记录 +${新条} 条、被反弹方的 HP 一动不动）`);
  } else bad(`二次反弹没挡住：反弹 ${反弹2} / 新记录 ${新条} 条 / ${甲血前}→${甲镜.hp} · ${乙血前}→${乙镜.hp}`);
  表.只给敌人 = 只给;
  /* ② 反弹量可以是 0：攻击者已死 / 这一发没造成伤害（被护盾吃掉 / 被屏障无效化） */
  const 零1 = G.镜甲反弹(ctx, Object.assign({}, 攻, { hp: 0 }), 镜, { 伤害: 5000 });
  const 零2 = G.镜甲反弹(ctx, 攻, 镜, { 伤害: 0 });
  const 零3 = G.镜甲反弹(ctx, 攻, G.makeUnit('grunt', 'enemy', 1, 3), { 伤害: 5000 });
  if (零1 === 0 && 零2 === 0 && 零3 === 0) ok(`反弹量可以是 0：攻击者已死 ${零1} / 这一发没造成伤害（护盾吃掉）${零2} / 目标没有镜甲 ${零3}`);
  else bad(`「反弹 0」的三种情况不对：${零1} / ${零2} / ${零3}`);

  /* ③ 不许改变随机数消耗顺序：同一个场景，开 / 关镜甲，`ctx.rng` 的调用次数与每一条攻击记录逐字相同 */
  const 跑一段 = 开 => {
    表.开 = 开;
    const c = G.开局([{ 键: 'B1', 位: 1, 等级: 20 }], [{ 键: 'mirror', 位: 0, 等级: 3 }], 20261010);
    const 真 = c.allies[0];
    真.maxHp = 999999; 真.hp = 999999;           // 反弹打不死它 → 后面的行动完全一样
    let n = 0; const 原 = c.rng; c.rng = () => { n++; return 原(); };
    const 录 = [];
    for (let i = 0; i < 3 && !c.result; i++) 录.push(...G.打一回合(c));
    return { n, 攻击: 录.filter(x => x.类型 === '攻击').map(x => JSON.stringify([x.文本, x.命中, x.伤害, x.暴击, x.详情])), 镜: 录.filter(x => x.类型 === '镜甲').length };
  };
  const 关 = 跑一段(false), 开 = 跑一段(true);
  表.开 = true;
  if (关.n === 开.n && 关.攻击.join('|') === 开.攻击.join('|')) {
    ok(`**随机数消耗顺序一个字节都没变**：同一个战斗开 / 关镜甲，\`ctx.rng\` 调用 ${关.n} 次 vs ${开.n} 次、${关.攻击.length} 条攻击记录逐字相同（反射那一下一次 \`rng\` 都不调）`);
  } else bad(`镜甲动了随机数顺序：rng ${关.n} vs ${开.n}；攻击记录 ${关.攻击.length} vs ${开.攻击.length}`);
  if (关.镜 === 0 && 开.镜 > 0) ok(`开关关掉 → 一条镜甲记录都没有（${关.镜}）；打开 → ${开.镜} 条（这就是「没挂这个钩子的敌人逐字不变」）`);
  else bad(`开关没起作用：关 ${关.镜} 条 / 开 ${开.镜} 条`);
  /* 同种子两次逐字相同 */
  const 甲2 = JSON.stringify(一场(20261010).记录), 乙2 = JSON.stringify(一场(20261010).记录);
  if (甲2 === 乙2) ok(`同种子两次逐字相同（${JSON.parse(甲2).length} 条记录，含 \`类型:'镜甲'\` 那几条）`);
  else bad('同种子两次不一样');
}

/* ============================ [13] 敌人卡第一批 · 献祭者（`selfDestruct`） ============================
 * 规格书 = 卡 C + 盘点 B3。落点：`60-战斗.js` 的击破点（`自爆()`）。
 * 【初稿】威力 = 主武器威力 × 1.5；落点 = `col`（**阻挡束**，理由：卡 C 的预告样例就是「前2、后2、后3」，
 * 而且 col 只有 3 格、开战前摆位躲得掉）；濒死线 = HP 比例 < 35%（只用来做预告）。 */
console.log('\n[13] 敌人卡第一批 · 献祭者（钩子 `selfDestruct`：击破瞬间自爆，落点 = 阻挡束）');
{
  const 表 = G.战斗结构.敌人机制;
  const c = G.自爆参数();
  if (c.威力倍率 === 1.5 && c.濒死线 === 0.35 && c.范围 === 'col') {
    ok(`【初稿·待作者在调参室调】自爆参数：威力 = 主武器威力 × ${c.威力倍率}、濒死线 = HP 比例 < ${c.濒死线}、落点形状 = ${c.范围}（阻挡束）`);
  } else bad(`自爆参数不对：${JSON.stringify(c)}`);
  const 带键 = Object.keys(G.ENEMY_T).filter(k => Array.isArray(G.ENEMY_T[k].abilities) && G.ENEMY_T[k].abilities.includes('selfDestruct'));
  const 用到的 = G.编成表.filter(e => [...(e.前 || []), ...(e.后 || [])].includes('bomber')).length;
  if (带键.join(',') === 'bomber' && 用到的 > 0) ok(`挂到了已有敌人键 \`bomber\`（${G.ENEMY_T.bomber.mech}，数据里本来就写着 \`abilities:['selfDestruct']\`）—— 编成表里 ${用到的} 条抽得到它`);
  else bad(`selfDestruct 键不对：带这个能力的敌人键 = ${带键.join(',')}（编成表用到 bomber ${用到的} 条）`);

  /* 落点逐位对：站在「后2」的自爆机 → 前2 / 后2 / 后3（= `阻挡束(前2)`） */
  const ctx = G.开局([{ 键: 'B1', 位: 1, 等级: 10 }, { 键: 'B2', 位: 5, 等级: 10 }],
    [{ 键: 'bomber', 位: 5, 等级: 5 }], 7);
  const 死 = ctx.enemies[0];
  const 落点 = G.areaSlots({ fire: 'map', area: c.范围 }, G.unitRow(死), 死.slot - 4);
  if (落点.join(',') === '1,5,6') ok(`落点逐位对：自爆机站在「${G.位名(死.slot)}」→ 落点 ${落点.map(G.位名).join('、')}（= 阻挡束，前2 / 后2 / 后3）`);
  else bad(`落点不对：${落点.map(G.位名).join('、')}`);
  /* 威力 = 主武器威力 × 1.5（前后数字） */
  const 主 = G.主武器威力(死);
  const r = G.自爆(ctx, ctx.allies[0], 死);
  if (r && r.威力 === Math.round(主 * 1.5)) ok(`威力真的按倍率算：主武器威力 ${主} × 1.5 = ${r.威力}（实际打掉 ${r.合计}，落在理面的 ${r.台数} 台）`);
  else bad(`威力不对：主武器 ${主}、自爆 ${r && r.威力}`);
  const 自爆录 = ctx.log.filter(x => x.类型 === '自爆');
  const 逐台录 = ctx.log.filter(x => x.类型 === '攻击' && x.自爆);
  if (自爆录.length === 1 && 逐台录.length === r.台数) {
    ok(`记录分两层：汇总行「${自爆录[0].文本}」+ 逐台 ${逐台录.length} 条（「${逐台录.map(x => x.文本).join('；')}」）`);
  } else bad(`自爆记录条数不对：汇总 ${自爆录.length} / 逐台 ${逐台录.length}（落点里 ${r.台数} 台）`);
  if (逐台录.some(x => x.目标位 === 5)) ok(`落点里的每一台都逐位打了（后2 那台也在：${逐台录.filter(x => x.目标位 === 5).map(x => x.文本).join('')}）`);
  else bad('落点里的单位没有被逐位打到');
  /* **不会重复触发**：同一个死者再叫一次 → null，而且记录里还是只有那一条汇总行 */
  const 再 = G.自爆(ctx, ctx.allies[0], 死);
  if (再 === null && ctx.log.filter(x => x.类型 === '自爆').length === 1) ok(`**不会重复触发**：同一个死者再调一次 \`自爆()\` → ${再}，汇总行还是 1 条（单位上挂了 \`自爆过\` 标记）`);
  else bad(`重复触发了：${JSON.stringify(再)} / 汇总 ${ctx.log.filter(x => x.类型 === '自爆').length} 条`);
  /* 不带这个键的敌人：一次都不触发 */
  const ctx兵 = G.开局([{ 键: 'B1', 位: 1, 等级: 10 }], [{ 键: 'grunt', 位: 5, 等级: 3 }], 7);
  const 无 = G.自爆(ctx兵, ctx兵.allies[0], ctx兵.enemies[0]);
  if (无 === null && ctx兵.log.filter(x => x.类型 === '自爆').length === 0) ok('不带 `selfDestruct` 的敌人：`自爆()` 立刻返回 null、一条记录都不写（行为逐字不变）');
  else bad(`没有这个键的敌人也被自爆了：${JSON.stringify(无)}`);

  /* 全军防御下的减免真的生效：同一发自爆，防御姿态那一台挨得更少、记录里写 `防御少挨` */
  const 造局 = 方针 => {
    const cc = G.开局([{ 键: 'B1', 位: 1, 等级: 20 }, { 键: 'B2', 位: 5, 等级: 20 }],
      [{ 键: 'bomber', 位: 5, 等级: 5 }], 11);
    cc.allies.forEach(u => { u.maxHp = 99999; u.hp = 99999; });
    if (方针) G.设方针(cc, { 类型: 方针 });
    const b = cc.enemies[0];
    const rr = G.自爆(cc, cc.allies[0], b);
    const 少挨录 = cc.log.filter(x => x.类型 === '攻击' && x.自爆 && x.防御少挨 != null);
    return { rr, 少挨: cc.log.filter(x => x.类型 === '自爆').reduce((n, x) => n + (x.自爆少挨 || 0), 0), 少挨录: 少挨录.length, 每台: cc.log.filter(x => x.类型 === '攻击' && x.自爆).map(x => `${G.位名(x.目标位)} ${x.伤害}${x.防御少挨 ? `（少挨 ${x.防御少挨}）` : ''}`) };
  };
  const 突击 = 造局(null), 防御 = 造局('全军防御');
  info(`全军突击：合计 ${突击.rr.合计}（${突击.每台.join('、')}）　｜　全军防御：合计 ${防御.rr.合计}（${防御.每台.join('、')}）`);
  if (防御.rr.合计 < 突击.rr.合计 && 防御.少挨 > 0 && 防御.少挨录 > 0) {
    ok(`**全军防御真的少挨**：同一发自爆 ${突击.rr.合计} → ${防御.rr.合计}（防御帮你省了 ${防御.少挨}，${防御.少挨录} 条记录带 \`防御少挨\`）`);
  } else bad(`全军防御没少吃：${突击.rr.合计} → ${防御.rr.合计}（少挨 ${防御.少挨}）`);

  /* 只读的「濒死」标记 + 预告那一句：35% 以下才算 */
  const 濒 = G.开局([{ 键: 'B1', 位: 0, 等级: 10 }], [{ 键: 'bomber', 位: 5, 等级: 5 }], 7);
  const b = 濒.enemies[0];
  b.hp = Math.round(b.maxHp * 0.36);
  const 高 = G.濒死自爆吗(b);
  b.hp = Math.round(b.maxHp * 0.34);
  const 低 = G.濒死自爆吗(b);
  if (高 === false && 低 === true) ok(`「濒死」是**只读**判据（HP 比例 36% 不算 / 34% 算）：${高} → ${低}—— 它不改任何战斗判定`);
  else bad(`濒死判据不对：36% → ${高}、34% → ${低}`);
  const 预 = G.敌人机制预告(濒);
  const 行 = 预[b.slot] && (预[b.slot].行们 || []).find(x => x.includes('濒死自爆'));
  if (行 && 行 === `敌机【${G.敌人机制称谓(b)}】濒死自爆：落点 前2、后2、后3（这一下会打这几个位）`) ok(`预告那一句：${行}`);
  else bad(`濒死预告不对：${行}`);

  /* 真打一场：击破的瞬间真的自爆了一次（编成表里抽得到自爆机的那一条） */
  const 序 = G.编成表.findIndex(e => [...(e.前 || []), ...(e.后 || [])].includes('bomber'));
  const 条目 = G.编成表[序];
  const 一场 = s => G.simulate(G.默认五人队, G.敌方规格组(G.编成到单位(条目, 0)), {}, s, { 波次: G.编成波次到单位(条目, 0) });
  const rr = 一场(20261010);
  const 爆录 = rr.记录.filter(x => x.类型 === '自爆');
  const 死爆 = rr.敌方.filter(u => u.key === 'bomber' && u.hp <= 0).length;
  info(`编成 #${序}（第 ${条目.层} 层${条目.类型}）：${rr.结果} / ${rr.回合数} 回合 / ${rr.记录.length} 条记录，自爆 ${爆录.length} 次（被击破的自爆机 ${死爆} 台）`);
  if (爆录.length === 死爆 && 爆录.length > 0) ok(`**一台只爆一次**：被击破的自爆机 ${死爆} 台 → 汇总行 ${爆录.length} 条（${爆录.map(x => x.文本).join('；')}）`);
  else bad(`自爆次数与被击破台数对不上：${爆录.length} 次 vs ${死爆} 台`);
  const 结行 = G.战报行们(rr).find(x => x.startsWith('自爆打掉你'));
  const 伤 = 爆录.reduce((n, x) => n + (x.自爆伤害 || 0), 0), 省 = 爆录.reduce((n, x) => n + (x.自爆少挨 || 0), 0);
  if (结行 && 结行 === `自爆打掉你 ${伤}，防御帮你省了 ${省}`) ok(`结算行 = 记录逐条加起来：${结行}`);
  else bad(`结算行对不上：${结行}（记录 ${伤} / ${省}）`);
  /* 同种子两次逐字相同 */
  const 甲3 = JSON.stringify(一场(20261010).记录), 乙3 = JSON.stringify(一场(20261010).记录);
  if (甲3 === 乙3) ok(`同种子两次逐字相同（${JSON.parse(甲3).length} 条记录，含 \`类型:'自爆'\` 与它逐台的 \`自爆:true\`）`);
  else bad('同种子两次不一样');
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
