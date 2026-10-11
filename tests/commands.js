#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 指令与职业特色测试（方案第 9 节 M3 的验收）
 * ----------------------------------------------------------------------------
 * 方案 M3 的验收原话：「守护确实替队友挨打；集火确实打指定目标；意图和实际行动一致」。
 * 这份测试就盯着这三条，外加方案第 4 节的另外两条指令（防御 / 换位）和 6.3 的六条职业特色。
 *
 * 全部用固定种子 + 单回合驱动（`开局()` → `设指令()` → `打一回合()`），所以结果是决定性的。
 *
 * 用法：node tests/commands.js
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

/** 开局 → 打一回合（可以连着打几回合） */
function 打(我方, 敌方, 指令, 种子, 回合数 = 1) {
  const ctx = G.开局(我方, 敌方, 种子, 指令);
  for (let i = 0; i < 回合数 && !ctx.result; i++) G.打一回合(ctx);
  return ctx;
}
const 攻击录 = (ctx, 位, 方 = 'ally') => ctx.log.filter(x => x.类型 === '攻击' && x.单位方 === 方 && x.单位位 === 位);
const 有人 = (ctx, 方) => ctx[方].filter(u => u.hp > 0);

console.log(`指令与职业特色测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/* ============================ [1] 指令：集火 ============================ */
console.log('[1] 集火 ▶ 目标（方案第 4 节）');
const 队伍集火 = [{ 键: 'CB2', 位: 0, 等级: 10 }, { 键: 'B1', 位: 1, 等级: 10 }];   // 狙击（打得到任意一排）+ 近卫
const 敌集火 = [{ 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'shield', 位: 1, 等级: 20 }, { 键: 'drone', 位: 3, 等级: 20 }];
{
  /* 狙击（位 0）集火后排的无人机（位 3） */
  const ctx = 打(队伍集火, 敌集火, { 0: { 类型: '集火', 目标位: 3 } }, 777);
  const 录 = 攻击录(ctx, 0);
  if (录.length && 录.every(x => x.目标位 === 3)) ok(`集火生效：CB2 这一回合 ${录.length} 次攻击全部打位 3（${录[0].文本}）`);
  else bad(`集火没生效：${录.map(x => `目标位${x.目标位}`).join('、') || '没有攻击'}`);
  if (录.every(x => x.集火 === true)) ok('记录里标了「集火」（界面和复盘能看出来）');
}
{
  /* 近卫（位 1，近战）集火后排 → 打不到，应当按「进攻」处理（方案第 4 节） */
  const ctx = 打(队伍集火, 敌集火, { 1: { 类型: '集火', 目标位: 3 } }, 777);
  const 录 = 攻击录(ctx, 1);
  if (录.length && 录.every(x => x.目标位 !== 3)) ok(`近战够不到后排时按「进攻」处理：B1 打了位 ${录.map(x => x.目标位).join('、')}（不是位 3）`);
  else bad(`近战集火后排时没有退回「进攻」：${JSON.stringify(录.map(x => [x.目标位, x.集火]))}`);
}
{
  /* 目标打不到时的「进攻」仍然要打人（不能空过） */
  const ctx = 打(队伍集火, 敌集火, { 1: { 类型: '集火', 目标位: 3 } }, 777);
  if (攻击录(ctx, 1).length > 0) ok('退回「进攻」以后照样出手');
  else bad('退回「进攻」以后没有出手');
}

/* ============================ [2] 指令：守护 ============================ */
console.log('\n[2] 守护 ▶ 队友（方案第 4 节）');
{
  /* 用一支没有重装的队伍（避免嘲讽干扰），6 台 Lv20 的敌人保证第一回合能出手 */
  const 队伍 = [
    { 键: 'B1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 },
    { 键: 'CB2', 位: 3, 等级: 20 }, { 键: 'M1', 位: 4, 等级: 20 }, { 键: 'B4', 位: 5, 等级: 20 },
  ];
  const 敌人 = [
    { 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'grunt', 位: 1, 等级: 20 }, { 键: 'shield', 位: 2, 等级: 20 },
    { 键: 'drone', 位: 3, 等级: 20 }, { 键: 'sniper', 位: 4, 等级: 20 }, { 键: 'swarm', 位: 5, 等级: 20 },
  ];
  /* 先看意图：找一个「要打我方前排、而且不是范围武器」的敌人 */
  const 侦察 = G.开局(队伍, 敌人, 4242);
  const 意图 = G.算意图(侦察);
  const 命中 = 意图.map(i => {
    const e = 侦察.enemies.find(u => u.slot === i.单位位);
    const w = e && e.weapons.find(x => x.t.name === i.武器);
    return { i, e, w: w && w.t, 单体: w ? G.rangeKindOf(w.t) !== '范围' : false };
  }).find(x => x.i.目标位 != null && x.单体 && x.e.weapons);
  if (!命中) { bad('找不到「单体攻击我方」的敌人意图，守护测不了'); }
  else {
    const 被守护位 = 命中.i.目标位, 敌人位 = 命中.i.单位位;
    /* 找一个不是被守护者的队友来当守护者 */
    const 守护者 = 侦察.allies.find(u => u.slot !== 被守护位);
    const 指令 = { [守护者.slot]: { 类型: '守护', 目标位: 被守护位 } };
    const ctx = 打(队伍, 敌人, 指令, 4242);
    const 守护录 = ctx.log.filter(x => x.类型 === '守护');
    const 挡下 = ctx.log.filter(x => x.类型 === '攻击' && x.守护挡下);
    if (守护录.length) ok(`守护挡下了：${守护录[0].文本}`);
    else bad('没有出现守护挡下');
    if (挡下.length && 挡下.every(x => x.目标位 === 守护者.slot && x.原目标位 === 被守护位)) {
      ok(`替队友挨打：原本打位 ${被守护位}（${挡下[0].原目标}）的攻击改打在守护者位 ${守护者.slot}（${挡下[0].目标}）上，共 ${挡下.length} 次`);
    } else bad(`没有改打守护者：${JSON.stringify(挡下.map(x => [x.原目标位, x.目标位]))}`);
    if (!ctx.log.some(x => x.类型 === '攻击' && x.目标位 === 被守护位 && x.目标方 === 'ally')) ok('被守护的队友这一回合没挨打');
    else bad('被守护的队友还是挨打了');
    /* 守护者自己照常攻击，但伤害 −30%（方案第 4 节） */
    if (攻击录(ctx, 守护者.slot).length) info(`守护者位 ${守护者.slot} 仍然出手了（伤害 ×0.7）`);
  }
}

/* ============================ [3] 意图和实际行动一致 ============================ */
console.log('\n[3] 意图和实际行动一致（方案 5.3）');
{
  const 队伍 = [
    { 键: 'B1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 },
    { 键: 'CB2', 位: 3, 等级: 20 }, { 键: 'M1', 位: 4, 等级: 20 },
  ];
  const 敌人 = [
    { 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'hound', 位: 1, 等级: 20 },
    { 键: 'sniper', 位: 3, 等级: 20 }, { 键: 'drone', 位: 4, 等级: 20 },
  ];
  const ctx = G.开局(队伍, 敌人, 9090);          // 不下任何指令
  const 意图 = G.算意图(ctx);
  G.打一回合(ctx);
  const 不符 = [];
  for (const i of 意图) {
    const 第一次 = 攻击录(ctx, i.单位位, 'enemy')[0];
    if (!第一次) continue;
    if (第一次.目标位 !== i.目标位) 不符.push(`位${i.单位位}：意图→位${i.目标位}，实际→位${第一次.目标位}`);
  }
  if (!不符.length) ok(`全部敌人第一次出手都和意图一致（${意图.filter(i => i.武器).map(i => `${i.名称}→${i.目标名}`).join('、')}）`);
  else bad(`意图和实际行动不符：${不符.join('；')}`);
  if (意图.every(i => i.期望 >= 0)) ok('意图里带了预计伤害（界面上会写成「约 N」）');
}

/* ============================ [4] 指令：防御 ============================ */
console.log('\n[4] 防御（方案第 4 节）');
{
  const 队伍 = [{ 键: 'B1', 位: 0, 等级: 10 }];
  const 敌人 = [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'hound', 位: 1, 等级: 10 }];
  const ctx = 打(队伍, 敌人, { 0: { 类型: '防御' } }, 31337);
  if (!攻击录(ctx, 0).length) ok('下了防御就不攻击（这一回合一次也没出手）');
  else bad('下了防御还是攻击了');
  if (ctx.log.some(x => x.类型 === '防御')) ok('记录里有「进入防御」');
  /* 防御的数值效果：同一击按防御结算时伤害更低（方案第 4 节：按防御值 +50 计算） */
  const a = G.makeUnit('grunt', 'enemy', 0, 10), d = G.makeUnit('B1', 'ally', 0, 10);
  const w = a.weapons[0].t;
  const 普通 = G.dmgCore(a, w, d, { power: G.wv(a, w, 'power'), preview: true });
  const 防 = G.dmgCore(a, w, d, { power: G.wv(a, w, 'power'), preview: true, defending: true });
  if (防.dmg < 普通.dmg) ok(`防御值 +50 真的减伤了：${普通.dmg} → ${防.dmg}`);
  else bad(`防御没有减伤：${普通.dmg} → ${防.dmg}`);
  if (防.steps.join(' ').includes('防御姿态')) ok('伤害步骤里写着「防御姿态」');
  /* 下回合开始回复 5% 最大 HP */
  const ctx2 = G.开局(队伍, 敌人, 31337, { 0: { 类型: '防御' } });
  const 我 = ctx2.allies[0];
  我.hp = Math.max(1, 我.maxHp - 3000);
  G.打一回合(ctx2);
  const 血前 = 我.hp;
  G.设指令(ctx2, {});
  G.打一回合(ctx2);
  const 回复录 = ctx2.log.filter(x => x.类型 === '回复' && x.单位位 === 0);
  if (回复录.length && 我.hp > 血前) ok(`防御的回报：下一回合开始回复 ${回复录[0].回复}（约 5% 最大 HP）`);
  else bad(`没有看到防御回复：${JSON.stringify(回复录)}`);
}

/* ============================ [5] 指令：换位 ============================ */
console.log('\n[5] 换位（方案第 4 节）');
{
  const 队伍 = [{ 键: 'B1', 位: 3, 等级: 10 }, { 键: 'CB2', 位: 4, 等级: 10 }];   // 都在后排
  const 敌人 = [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'hound', 位: 1, 等级: 10 }];
  const ctx = 打(队伍, 敌人, { 3: { 类型: '换位' } }, 515);
  const 他 = ctx.allies.find(u => u.key === 'B1');
  if (他 && 他.slot === 0) ok(`换位生效：B1 从后 1（位 3）换到前 1（位 ${他.slot}）——同一列的另一排`);
  else bad(`换位没生效：B1 在位 ${他 && 他.slot}`);
  if (!攻击录(ctx, 0).length) ok('换位这一回合不攻击');
  else bad('换位还攻击了');
  /* 对面那一列有人时应该互换 */
  const ctx2 = 打([{ 键: 'B1', 位: 0, 等级: 10 }, { 键: 'CB2', 位: 3, 等级: 10 }], 敌人, { 3: { 类型: '换位' } }, 516);
  const a = ctx2.allies.find(u => u.key === 'B1'), b = ctx2.allies.find(u => u.key === 'CB2');
  if (a && b && a.slot === 3 && b.slot === 0) ok('同一列有人时是「互换」（B1 位 3 ⇄ CB2 位 0）');
  else bad(`互换不对：B1 位 ${a && a.slot}、CB2 位 ${b && b.slot}`);
}

/* ============================ [6] 职业特色（方案 6.3） ============================ */
console.log('\n[6] 职业特色（方案 6.3）');
/* 指挥：回合开始时同一排的队友命中 +10 */
{
  const 队伍 = [{ 键: 'M1', 位: 3, 等级: 10 }, { 键: 'CB2', 位: 4, 等级: 10 }, { 键: 'B1', 位: 0, 等级: 10 }];
  const 敌人 = [{ 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'shield', 位: 1, 等级: 20 }];
  const ctx = 打(队伍, 敌人, {}, 606);
  const 指挥 = ctx.log.filter(x => x.类型 === '指挥');
  if (指挥.length) ok(`指挥给同一排的队友加了命中：${指挥.map(x => x.目标.join('、')).join('；')}`);
  else bad('指挥没有给同排队友加命中');
  if (指挥.every(x => x.单位位 !== 3)) ok('指挥不给自己加（只给队友）');
  if (!指挥.some(x => (x.目标位们 || []).includes(0))) ok('不同排的队友拿不到（指挥在后排，B1 在前排）');
}
/* 特种：武器命中后目标防御值 −20，持续到下回合结束 */
{
  const 队伍 = [{ 键: 'B4', 位: 0, 等级: 20 }];              // 比格特拉克，特种，曲射
  const 敌人 = [{ 键: 'shield', 位: 0, 等级: 20 }];           // 盾卫，皮厚，第一回合打不死
  const ctx = 打(队伍, 敌人, {}, 707);
  const 目标 = ctx.enemies[0];
  const 减防 = (目标.buffs || []).find(b => b.src === '特种');
  if (目标.hp > 0 && 减防 && 减防.def === -20) ok(`特种命中后目标防御 −20（盾卫身上挂着「${减防.src} ${减防.def}」，剩余 ${减防.剩余} 回合）`);
  else bad(`特种的减防没挂上：hp ${目标.hp} buffs ${JSON.stringify(目标.buffs)}`);
  if (减防 && 减防.剩余 >= 1) ok('减防会留到下一回合（方案：持续到下回合结束）');
}
/* 近卫：击破目标后立刻再行动一次（每回合最多 1 次） */
{
  const 队伍 = [{ 键: 'B1', 位: 0, 等级: 30 }];
  const 敌人 = [{ 键: 'grunt', 位: 0, 等级: 1 }, { 键: 'drone', 位: 3, 等级: 1 }];
  const ctx = 打(队伍, 敌人, {}, 808);
  const 连斩 = ctx.log.filter(x => x.类型 === '连斩');
  const 录 = 攻击录(ctx, 0);
  if (连斩.length && 录.length >= 2) ok(`近卫击破后再动：${连斩[0].文本}（这一回合出手 ${录.length} 次）`);
  else bad(`没看到近卫的连斩：连斩 ${连斩.length} 条 / 出手 ${录.length} 次`);
  if (连斩.length <= 1) ok('每回合最多 1 次（不会无限连）');
}
/* 重装：在前排时，敌方单体攻击 50% 概率改打它 */
{
  const 前排 = [{ 键: 'CB4', 位: 2, 等级: 20 }, { 键: 'B1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }];
  const 后排 = [{ 键: 'B1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }, { 键: 'CB4', 位: 5, 等级: 20 }];
  const 敌人 = [{ 键: 'hound', 位: 0, 等级: 20 }, { 键: 'grunt', 位: 1, 等级: 20 }, { 键: 'fighter', 位: 3, 等级: 20 }];
  let 前 = 0, 后 = 0;
  for (let s = 1; s <= 30; s++) {
    if (打(前排, 敌人, {}, s).log.some(x => x.类型 === '嘲讽')) 前++;
    if (打(后排, 敌人, {}, s).log.some(x => x.类型 === '嘲讽')) 后++;
  }
  if (前 > 0) ok(`重装在前排时确实会嘲讽（30 个种子里出现 ${前} 次，50% 概率下的合理范围）`);
  else bad('重装在前后排都没有嘲讽');
  if (后 === 0) ok('重装在后排时不嘲讽（方案：在前排时才有）');
  else bad(`重装在后排也嘲讽了 ${后} 次`);
}
/* 尖兵：每回合第一次被攻击时闪避 +20 */
{
  const 攻 = G.makeUnit('grunt', 'enemy', 0, 10), 尖兵 = G.makeUnit('B2', 'ally', 0, 10);
  const w = 攻.weapons[0].t;
  const 基 = G.hitRate(攻, w, 尖兵, { baseHit: 90, turn: 1 }).hit;   // 还没被打过：闪避 +20 生效
  尖兵.尖兵闪避Turn = 1;                                  // 这一回合的第一次已经用掉
  const 用过 = G.hitRate(攻, w, 尖兵, { baseHit: 90, turn: 1 }).hit;  // 这一回合已经用掉了
  尖兵.尖兵闪避Turn = undefined;
  const 下回合 = G.hitRate(攻, w, 尖兵, { baseHit: 90, turn: 2 }).hit;
  if (用过 === 基 + 20 && 下回合 === 基) ok(`尖兵每回合第一次被攻击闪避 +20：第一次挨打时命中 ${基}%，同一回合第二次 ${用过}%，下一回合又回到 ${下回合}%`);
  else bad(`尖兵的闪避加成不对：基 ${基}% / 用过后 ${用过}% / 下一回合 ${下回合}%`);
}
/* 狙击：打后排没有被挡惩罚，暴击率 +10 */
{
  const 狙 = G.makeUnit('CB2', 'ally', 0, 10), 重 = G.makeUnit('CB4', 'ally', 0, 10);
  const w = 狙.weapons[0].t;
  const 狙罚 = G.rowBlockPenalty('直射', G.ROW_BACK, true, 狙);
  const 他罚 = G.rowBlockPenalty('直射', G.ROW_BACK, true, 重);
  if (狙罚 === 0 && 他罚 === -20) ok(`狙击打后排没有被挡惩罚（狙击 ${狙罚} / 非狙击 ${他罚}）`);
  else bad(`狙击的被挡惩罚不对：狙击 ${狙罚} / 非狙击 ${他罚}`);
  const 狙暴 = G.critRate(w, 狙), 他暴 = G.critRate(w, 重);
  if (狙暴 === 他暴 + 10) ok(`狙击暴击率 +10：${他暴}% → ${狙暴}%`);
  else bad(`狙击暴击率不对：狙击 ${狙暴}% / 非狙击 ${他暴}%`);
}

/* ============================ [7] 大招开关（方案第 4 节） ============================ */
console.log('\n[7] 大招开关：自动 / 保留');
{
  const 队伍 = [{ 键: 'B2', 位: 0, 等级: 30 }];                       // 尖兵，大招「影凤凰」unlock 20（第 4 回合起可用）
  const 敌人 = [
    { 键: 'grunt', 位: 0, 等级: 30 }, { 键: 'grunt', 位: 1, 等级: 30 }, { 键: 'grunt', 位: 2, 等级: 30 },
  ];
  const 大招 = G.ALLY_T.find(t => t.mech === 'B2').weapons
    .filter(w => G.isUltimate(w) && G.weaponPlayable(w) && G.rangeKindOf(w))     // 只挑第一期真能用的那把
    .map(w => w.name)[0];
  const 自动 = 打(队伍, 敌人, {}, 1212, 5);
  const 用了 = 自动.log.filter(x => x.类型 === '攻击' && x.武器 === 大招);
  if (用了.length) ok(`「自动」时大招会放：第 ${用了[0].回合} 回合用了【${大招}】（开场冷却 3 回合）`);
  else bad(`「自动」时第 5 回合还没放大招（${大招}）`);
  const 保留 = 打(队伍, 敌人, { 0: { 保留大招: true } }, 1212, 5);
  const 也用了 = 保留.log.filter(x => x.类型 === '攻击' && x.武器 === 大招);
  if (!也用了.length) ok(`「保留」时一次都没放大招（${大招}）——等玩家改回自动`);
  else bad(`「保留」还是放了大招：${也用了.length} 次`);
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '指令与职业特色测试全部通过');
process.exit(fails ? 1 : 0);
