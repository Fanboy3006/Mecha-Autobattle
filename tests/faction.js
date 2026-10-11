#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 势力特色测试（作者 2026-10-10 拍板「势力特色优先」· 第一件 = 卫星国防军）
 * ----------------------------------------------------------------------------
 * 这一版做的是「势力特色」这条线的**框架**（`src/js/72-势力.js`）+ **第一套特色**：
 * **卫星国防军 = SEED 觉醒**（作者原话「国防军特色没问题」，照战棋原样）。
 * 参数表在 `src/js/71-改动.js` 的 `势力特色.卫星国防军`，**数值逐字照抄**战棋
 * `Claude hand off/src/js/17b-角色机制.js:187-240`（常量在 `:195`）。
 *
 * 这份测试真的跑（固定种子 / 决定性），盯着八件事：
 *   [1] SEED 参数与战棋**逐字对账**（贴出处行号）+ 成员按 `tags.势力` 查（与 协作/势力特色.md 第二节的成员表逐行对）
 *   [2] 每回合真的 +5（贴前后层数）
 *   [3] 击破真的 +3（贴数字）
 *   [4] 累计到阈值 → 闪避 / 防御**真的进公式**（贴 hitRate / 防御值前后数字；顺带贴「觉醒喂进攻击能力值」）
 *   [5] **只对我方生效**（把同一套特色挂到敌人身上 → 一点不生效）
 *   [6] 不满足阈值时不给加成（边界：阈值 −1 / 刚好阈值 / 封顶 / 拉克丝的「无尽的 SEED」）
 *   [7] 同种子两次跑，记录逐字相同（随机数一律 `mulberry32` + 种子）
 *   [8] 界面上看得出「SEED 层数 / 还差多少」（战斗屏单位卡多一行，没特色的单位不多画）
 *
 * 用法：node tests/faction.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync } from 'fs';
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
const 界面 = G.界面;

console.log(`势力特色测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/** 读源码 / 文档（只读，用来对账；**不改**任何文件） */
const 源码 = p => readFileSync(join(ROOT, ...p.split(/[\\/]/)), 'utf8');
const 势力们 = () => G.势力特色['卫星国防军'];
/** 一个「打不死」的靶子：蓝色大肥鱼（HP 240000），Boss 脚本让它每 3 回合才出手一次 */
const 肉靶 = () => [{ 键: 'bluefish', 位: 0, 等级: 1 }];

/* ============================ [1] 参数与战棋逐字对账 ============================ */
console.log('[1] SEED 参数与战棋逐字对账（`17b-角色机制.js:187-240`，常量 `:195`）+ 成员按数据查');
{
  const p = 势力们();
  if (!p) bad('`71-改动.js` 的 `势力特色.卫星国防军` 不存在');
  /* 战棋原文（逐字）：
     const SEED_NEED = 50, SEED_TURN = 5, SEED_KILL = 3, SEED_EVA = .15, SEED_DEF = .25, ORB_R = 4, ORB_TURN = 1;
     ← Claude hand off/src/js/17b-角色机制.js:195 */
  const 对账 = [
    ['每回合', 'SEED_TURN', 5, '17b-角色机制.js:195'],
    ['每次击破', 'SEED_KILL', 3, '17b-角色机制.js:195'],
    ['阈值', 'SEED_NEED', 50, '17b-角色机制.js:195'],
    ['闪避系数', 'SEED_EVA', 0.15, '17b-角色机制.js:195'],
    ['防御系数', 'SEED_DEF', 0.25, '17b-角色机制.js:195'],
    ['第几回合起', '（我方阶段开始第 2 回合起）', 2, '17b:221 / 03-能力与减免管线.js:33'],
    ['重装分类', 'isHeavy：tags.战斗分类 === 重装', '重装', '17b-角色机制.js:196'],
    ['不封顶特技', 'endlessSeed（无尽的 SEED）', 'endlessSeed', '17b:201 / 03:34'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 对账) {
    if (p[字段] === 值) ok(`${字段} = ${JSON.stringify(p[字段])}（战棋 ${战棋名}）　出处 ${出处}`);
    else bad(`${字段} = ${JSON.stringify(p[字段])}，战棋是 ${JSON.stringify(值)}（${出处}）`);
  }
  if (p.初稿 === true) ok('标了「初稿·待调」：战棋的阈值 50 是按长战斗设计的（docs/角色与敌人一览.md:805-810「不击破第 11 回合觉醒」），我们常常 1–2 回合打完 → **先照抄、留一个可调常量**，难度等作者玩过一起调');
  else bad('没有「初稿·待调」的标记（作者说过难度最后一起调，我们自己不能改平衡数值）');
  info(`出处登记：${p.出处}`);

  /* 成员：**按 10-数据.js 的 tags.势力 查**，不手写名单 */
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === '卫星国防军').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档 = 源码('协作\\势力特色.md');
  const 段 = 文档.split('### 2.2 这个势力有哪些角色')[1].split('### 2.3')[0];
  const 文档名册 = 段.split('\n')
    .map(l => l.match(/^\|\s*([SWACBU]\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: m[3] }));
  if (数据名册.length === 5) ok(`数据里（\`tags.势力 === '卫星国防军'\`）正好 5 人：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  else bad(`数据里查到 ${数据名册.length} 人，预期 5`);
  if (文档名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`与 \`协作/势力特色.md\` 第二节的成员表**逐行一致**（键 / 机师 / 战斗分类都对上）`);
  } else {
    bad(`成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);
  }
  /* 「不要手写死名单」：框架与**势力特色参数表**里不许出现写死的角色键
     （71-改动.js 别的地方有 `'B3'` / `'M5'` 这类键，那是奶妈那条线的，不在这张表里） */
  const 框架源码 = 源码('src\\js\\72-势力.js');
  const 参数表 = 源码('src\\js\\71-改动.js').split('const 势力特色 = {')[1] || '';
  const 写死 = [['72-势力.js', 框架源码], ['71-改动.js 的势力特色表', 参数表]].filter(([, s]) => /['"][SWACBU]\d['"]/.test(s));
  if (!写死.length) ok('`72-势力.js` / `71-改动.js` 的 `势力特色` 表里**没有写死的角色键**（成员一律按 `tags.势力` 查，加人只改数据）');
  else bad(`有写死的键：${写死.map(([f]) => f).join('、')}（成员应该按 tags.势力 查）`);

  /* 框架的基本形状：钩子是函数、参数表在 71、注册表在 72 */
  for (const 名 of ['势力开局', '势力回合开始', '势力回合结束', '势力击破', '势力闪避', '势力防御', '势力觉醒值', '势力卡行', '注册势力特色']) {
    if (typeof G[名] === 'function') ok(`框架钩子 \`${名}()\` 在 \`window.__game\` 上（后面 5 个势力共用）`);
    else bad(`\`${名}\` 没有暴露 / 不是函数`);
  }
  if (Object.keys(G.势力特色表).length === 1 && G.势力特色表['卫星国防军']) ok(`\`势力特色表\` 现在有 1 个条目（${Object.keys(G.势力特色表).join('、')}）——后面 5 个势力往同一张表加`);
  else bad(`势力特色表的内容不对：${JSON.stringify(Object.keys(G.势力特色表))}`);
}

/* ============================ [2] 每回合真的 +5 ============================ */
console.log('\n[2] 每回合真的 +5（战棋 17b:220-226「我方阶段开始（第 2 回合起）」）');
{
  const 队 = [{ 键: 'S2', 位: 0, 等级: 10 }, { 键: 'S5', 位: 1, 等级: 10 }, { 键: 'B1', 位: 2, 等级: 10 }];
  const ctx = G.开局(队, 肉靶(), 20261010);
  const S2 = ctx.allies.find(u => u.key === 'S2'), S5 = ctx.allies.find(u => u.key === 'S5'), B1 = ctx.allies.find(u => u.key === 'B1');
  info(`开局：S2 卡嘉莉（指挥）觉醒 ${G.势力觉醒值(S2)}、S5 史黛拉（重装）觉醒 ${G.势力觉醒值(S5)}、B1 雷萨（影世界，不吃特色）觉醒 ${G.势力觉醒值(B1)}`);
  if (G.SEED累计(S2) === 0 && G.SEED累计(S5) === 0) ok('开局本场累计 = 0（`势力开局()` 显式清零，等价战棋 `awG = 0`）');
  else bad(`开局累计不是 0：${G.SEED累计(S2)} / ${G.SEED累计(S5)}`);
  const 序列 = [0];
  for (let i = 0; i < 3; i++) {
    const 录 = G.打一回合(ctx);
    const 势力录 = 录.filter(x => x.类型 === '势力');
    info(`第 ${ctx.turn - 1} 回合结束 → 累计：S2=${G.SEED累计(S2)} S5=${G.SEED累计(S5)}；记录「${势力录.length ? 势力录[0].文本 : '（没有）'}」`);
    if (势力录.length !== 1 || !势力录[0].文本.startsWith('〔势力〕')) bad(`第 ${ctx.turn - 1} 回合的〔势力〕记录不对：${JSON.stringify(势力录.map(x => x.文本))}`);
    序列.push(G.SEED累计(S2));
  }
  if (JSON.stringify(序列) === JSON.stringify([0, 5, 10, 15])) ok(`每回合 +5 真的生效：累计依次 ${序列.join(' → ')}（3 回合 +15）`);
  else bad(`每回合的累计不对：${序列.join(' → ')}，预期 0 → 5 → 10 → 15`);
  if (G.SEED累计(B1) === 0 && G.SEED累计(S5) === 15) ok('同队里**不是**卫星国防军的 B1 一点没涨（只对这个势力的人生效）');
  else bad(`B1 也涨了？B1=${G.SEED累计(B1)} S5=${G.SEED累计(S5)}`);
  /* 战棋第 2 回合起：第 1 回合的**战斗开始时**不加（第一次加在「第 2 回合开始」= 我们第 1 回合结束） */
  info('★ 我们挂在**回合结束**：第 N 回合结束 = 第 N+1 回合开始 → 加点与次数和战棋一致（12 回合上限下各 11 次）');
}

/* ============================ [3] 击破真的 +3 ============================ */
console.log('\n[3] 击破真的 +3（战棋 17b:227-233）');
{
  const ctx = G.开局([{ 键: 'S3', 位: 0, 等级: 10 }, { 键: 'S2', 位: 1, 等级: 10 }, { 键: 'B1', 位: 2, 等级: 10 }],
    [{ 键: 'grunt', 位: 0, 等级: 1 }], 7);
  const 杀手 = ctx.allies.find(u => u.key === 'S3'), 队友 = ctx.allies.find(u => u.key === 'S2'), 外人 = ctx.allies.find(u => u.key === 'B1');
  const 目 = ctx.enemies[0];
  目.hp = 1;                                  // 一枪就死，专门验击破钩子
  ctx.rng = () => 0;                          // 必中（引擎的随机数入口就是 ctx.rng）
  const 用 = G.usableWeapons(杀手, ctx).find(e => G.rangeKindOf(e.t) === '直射') || G.usableWeapons(杀手, ctx)[0];
  const r = G.resolveAction(杀手, { kind: 'attack', weapon: 用.t, target: 目, entry: 用 }, ctx);
  info(`露娜玛丽亚（S3）用【${用.t.name}】打死 1 HP 的量产机（击破 ${r.击破} 台）`);
  info(`记录：${ctx.log.slice(-2).map(x => x.文本).join(' ｜ ')}`);
  if (r.击破 === 1 && 目.hp <= 0) ok('真的打死了（`resolveAction` 返回 `击破: 1`）');
  else bad(`没打死：${JSON.stringify(r)} / 目 hp ${目.hp}`);
  if (G.SEED累计(杀手) === 3 && G.SEED累计(队友) === 3) ok(`在场每个卫星国防军 +3：击破者 ${杀手.name} ${G.SEED累计(杀手)}、队友 ${队友.name} ${G.SEED累计(队友)}（战棋 SEED_KILL = 3）`);
  else bad(`击破后累计不对：${G.SEED累计(杀手)} / ${G.SEED累计(队友)}，预期都是 3`);
  if (G.SEED累计(外人) === 0) ok(`同队但不是卫星国防军的 ${外人.name}（影世界）没有涨（0）`);
  else bad(`${外人.name} 也涨了：${G.SEED累计(外人)}`);
  const 录 = ctx.log.filter(x => x.类型 === '势力').pop();
  if (录 && 录.加觉醒 === 3 && 录.击破者 === 'S3') ok(`〔势力〕记录带字段：加觉醒 ${录.加觉醒}、击破者 ${录.击破者}、被击破者 ${录.被击破者}`);
  else bad(`击破的〔势力〕记录字段不对：${JSON.stringify(录)}`);
  /* 反向：非卫星国防军的人击破 → 一点不涨（战棋 `!inFaction(by,'卫星国防军') return`） */
  const 前 = G.SEED累计(杀手);
  G.势力击破(ctx, 外人, 目);
  if (G.SEED累计(杀手) === 前) ok('别的势力的人击破敌机时，卫星国防军的 SEED 不涨（战棋要求击破者属于这个势力）');
  else bad('别的人击破也涨了');
}

/* ============================ [4] 累计到阈值 → 真的进公式 ============================ */
console.log('\n[4] 本场累计到阈值 50 → SEED 觉醒，闪避 / 防御真的进公式');
{
  const 枪 = { name: '试作直射枪', fire: 'direct', hit: 100, dmgType: '物理', power: 1000, stat: '射击', range: [1, 1], upgrades: [] };
  const 敌人 = G.makeUnit('grunt', 'enemy', 4, 10);

  /* 闪避：战棋 03-能力与减免管线.js:100 `TRAIT_FX.seed = eva: round(觉醒 × 0.15)`（重装不加闪避） */
  const 卡 = G.makeUnit('S2', 'ally', 0, 10);
  const 前 = G.hitRate(敌人, 枪, 卡, { turn: 1 });
  const 加 = G.加SEED(卡, 50, null);
  const 后 = G.hitRate(敌人, 枪, 卡, { turn: 1 });
  info(`卡嘉莉（S2 · 指挥）Lv10：觉醒值 ${G.势力觉醒值(卡)} = 模板 ${卡.awaken} + 本场 ${G.SEED累计(卡)}`);
  info(`hitRate：原始 ${前.raw}% → ${后.raw}%（结算 ${前.hit}% → ${后.hit}%），eva ${前.eva} → ${后.eva}`);
  if (加 === 50 && G.SEED已觉醒(卡)) ok(`加满 50 → SEED 觉醒（\`加SEED\` 返回 ${加}）`);
  else bad(`加 SEED 不对：返回 ${加}，已觉醒 ${G.SEED已觉醒(卡)}`);
  if (G.势力闪避(卡) === Math.round(G.势力觉醒值(卡) * 0.15) && G.势力闪避(卡) === 21) ok(`闪避加成 = round(觉醒 ${G.势力觉醒值(卡)} × 0.15) = ${G.势力闪避(卡)}（进的是 \`hitRate\` 的 eva 那一项）`);
  else bad(`闪避加成不对：${G.势力闪避(卡)}`);
  if (后.raw === 前.raw - G.势力闪避(卡) && 后.raw !== 前.raw) ok(`真的进了公式：命中原始值 ${前.raw} → ${后.raw}（正好差 ${G.势力闪避(卡)}）`);
  else bad(`命中没变：${前.raw} → ${后.raw}（闪避加成 ${G.势力闪避(卡)}）`);

  /* 防御：战棋 03:227-229 的 `REDUCTIONS.seedDef`，值 = `seedDefOf` = round(觉醒 × 0.25)，**只给重装** */
  const 史 = G.makeUnit('S5', 'ally', 0, 10);
  const d前 = G.dmgCore(敌人, 枪, 史, { power: 2000, preview: true, turn: 1 });
  G.加SEED(史, 50, null);
  const d后 = G.dmgCore(敌人, 枪, 史, { power: 2000, preview: true, turn: 1 });
  info(`史黛拉（S5 · 重装）Lv10：觉醒值 ${G.势力觉醒值(史)}　势力防御 +${G.势力防御(史)}`);
  info(`挨同一发（威力 2000）：${d前.dmg} → ${d后.dmg}；${d后.steps[1]}`);
  if (G.势力防御(史) === 35 && G.势力防御(史) === Math.round(G.势力觉醒值(史) * 0.25)) ok(`重装档：防御 + round(觉醒 ${G.势力觉醒值(史)} × 0.25) = +${G.势力防御(史)}（重装**不加闪避**，\`势力闪避\` = ${G.势力闪避(史)}）`);
  else bad(`重装防御加成不对：${G.势力防御(史)}（闪避 ${G.势力闪避(史)}）`);
  if (d后.dmg < d前.dmg && d后.steps.join(' ').includes(`势力防御 +${G.势力防御(史)}`)) ok(`真的进了公式：伤害 ${d前.dmg} → ${d后.dmg}，步骤里写着「势力防御 +${G.势力防御(史)}」`);
  else bad(`伤害没变：${d前.dmg} → ${d后.dmg}；steps ${JSON.stringify(d后.steps)}`);
  const 条 = G.REDUCTIONS.find(r => r.id === 'factionDef');
  if (条 && 条.stage === 2) ok(`\`REDUCTIONS\` 里的 \`factionDef\`（${条.name}）是 stage 2、加到防御值上（战棋 seedDef 同款）`);
  else bad('REDUCTIONS 里没有 factionDef / stage 不对');

  /* ★ 顺带照抄：觉醒值喂进「射击 + 觉醒」那类大招（战棋 15-战斗计算.js:48 的 `statVal('觉醒')`） */
  const s5b = G.makeUnit('S5', 'ally', 0, 20);
  const w5 = s5b.weapons.map(e => e.t).find(x => x.name === '毁灭·全方位炮击');
  const a前 = G.atkStat(s5b, w5);
  G.加SEED(s5b, 50, null);
  const a后 = G.atkStat(s5b, w5);
  info(`S5 Lv20 的【${w5.name}】（stat ${w5.stat}）：攻击能力值 ${a前} → ${a后}（觉醒 ${a前 && G.势力觉醒值(s5b) - 50} → ${G.势力觉醒值(s5b)}）`);
  if (a后 === a前 + 50) ok(`觉醒值真的喂进攻击能力值：${a前} → ${a后}（+50 = 这一场涨的觉醒；出处 15-战斗计算.js:48）`);
  else bad(`觉醒没喂进攻击能力值：${a前} → ${a后}`);

  /* 没有势力特色的单位：数值一个字节都没变 */
  const b1 = G.makeUnit('B1', 'ally', 0, 10);
  const b前 = G.dmgCore(敌人, 枪, b1, { power: 2000, preview: true, turn: 1 });
  if (G.势力闪避(b1) === 0 && G.势力防御(b1) === 0 && G.势力觉醒值(b1) === b1.awaken && b前.steps.join(' ').includes('势力防御') === false) {
    ok(`没有势力特色的单位（B1 影世界）三个加数恒 0、公式里一个「势力防御」都不出现 → 既有战斗逐字不变`);
  } else bad(`B1 被影响了：闪避 ${G.势力闪避(b1)} / 防御 ${G.势力防御(b1)} / ${JSON.stringify(b前.steps)}`);
}

/* ============================ [5] 只对我方生效 ============================ */
console.log('\n[5] 只对我方生效（敌人按梯队，把同一套特色挂到敌人身上也不生效）');
{
  const ctx = G.开局([{ 键: 'S2', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 0, 等级: 10 }], 5);
  const 我方 = ctx.allies[0], 敌 = ctx.enemies[0];
  /* 把「卫星国防军 + seed」挂到敌人身上（`tags` 是模板共享的引用，所以换一份自己的副本，别弄脏数据） */
  敌.tags = Object.assign({}, 敌.tags, { 势力: '卫星国防军' });
  敌.abilities = ['seed'];
  if (G.势力名(敌) === '卫星国防军' && !G.是我方势力(敌, '卫星国防军')) ok('敌人的 `tags.势力` 确实写成了卫星国防军，但 `是我方势力()` 为假（`side === \'ally\'` 这道门）');
  else bad('判定不对');
  G.势力回合结束(ctx);
  G.势力击破(ctx, 敌, 我方);              // 敌人「击破」我方
  const 加 = G.加SEED(敌, 50, ctx);
  if (G.SEED累计(敌) === 0 && 加 === 0) ok(`敌人：回合结束不加（累计 ${G.SEED累计(敌)}）、击破我方不加、直接调 \`加SEED\` 也返回 ${加}（只对我方生效）`);
  else bad(`敌人居然涨了：累计 ${G.SEED累计(敌)} / 加SEED ${加}`);
  if (G.势力闪避(敌) === 0 && G.势力防御(敌) === 0 && G.势力卡行(敌) === '') ok('敌人的 `势力闪避` / `势力防御` 都是 0、单位卡上也不会有那一行');
  else bad(`敌人被算了加成：闪避 ${G.势力闪避(敌)} / 防御 ${G.势力防御(敌)} / 卡行「${G.势力卡行(敌)}」`);
  if (G.势力觉醒值(敌) === (敌.awaken ?? 100)) ok(`敌人的觉醒值还是模板值 ${G.势力觉醒值(敌)}（觉醒不成长）`);
  else bad(`敌人的觉醒值变了：${G.势力觉醒值(敌)}`);
  /* 对照：同一场里我方的 S2 照样涨 */
  const 我方前 = G.SEED累计(我方);
  G.势力回合结束(ctx);
  if (G.SEED累计(我方) === 我方前 + 5) ok(`同一场的我方 ${我方.name} 照常 +5（${我方前} → ${G.SEED累计(我方)}）—— 只对我方生效，不是「整套关掉」`);
  else bad(`我方没涨：${我方前} → ${G.SEED累计(我方)}`);
  /* `势力在场()` 只收我方这个势力的人 */
  const 名 = G.势力在场('卫星国防军', ctx).map(u => u.key);
  if (名.length === 1 && 名[0] === 'S2') ok(`\`势力在场('卫星国防军')\` = ${JSON.stringify(名)}（敌人不在里面）`);
  else bad(`势力在场不对：${JSON.stringify(名)}`);
}

/* ============================ [6] 阈值边界 ============================ */
console.log('\n[6] 不满足阈值不给加成（阈值 −1 / 刚好阈值 / 封顶 / 无尽的 SEED）');
{
  const 卡 = G.makeUnit('S2', 'ally', 0, 10);
  G.加SEED(卡, 49, null);
  if (!G.SEED已觉醒(卡) && G.SEED闪避加成(卡) === 0 && G.势力闪避(卡) === 0) ok(`累计 49（阈值 −1）：**没觉醒**、闪避 +0，卡行写「${G.势力卡行(卡)}」`);
  else bad(`49 就给加成了：觉醒 ${G.SEED已觉醒(卡)} / 闪避 ${G.SEED闪避加成(卡)}`);
  const 加1 = G.加SEED(卡, 1, null);
  if (加1 === 1 && G.SEED累计(卡) === 50 && G.SEED已觉醒(卡) && G.SEED闪避加成(卡) === 21) ok(`刚好 50：这一下 +${加1} → **觉醒**、闪避 +${G.SEED闪避加成(卡)}（觉醒 ${G.势力觉醒值(卡)} × 0.15）；卡行「${G.势力卡行(卡)}」`);
  else bad(`刚好阈值不对：累计 ${G.SEED累计(卡)} / 觉醒 ${G.SEED已觉醒(卡)} / 闪避 ${G.SEED闪避加成(卡)}`);
  const 再加 = G.加SEED(卡, 100, null);
  if (再加 === 0 && G.SEED累计(卡) === 50) ok(`觉醒后再加 100 → 只加了 ${再加}，累计仍是 ${G.SEED累计(卡)}（战棋 \`Math.min(n, SEED_NEED − awG)\` + 觉醒后不再成长）`);
  else bad(`觉醒后还在涨：加 ${再加}、累计 ${G.SEED累计(卡)}`);
  /* 重装档的边界 */
  const 史 = G.makeUnit('S5', 'ally', 0, 10);
  G.加SEED(史, 49, null);
  const 前49 = G.SEED防御加成(史);
  G.加SEED(史, 1, null);
  if (前49 === 0 && G.SEED防御加成(史) === 35) ok(`重装（S5）：49 时防御 +${前49}、50 时防御 +${G.SEED防御加成(史)}（觉醒 ${G.势力觉醒值(史)} × 0.25）`);
  else bad(`重装边界不对：49 → ${前49}、50 → ${G.SEED防御加成(史)}`);
  /* 拉克丝「无尽的 SEED」（战棋 17b:201 / 03:34）：不封顶 */
  const 拉 = G.makeUnit('S1', 'ally', 0, 10);
  const 无 = G.加SEED(拉, 100, null);
  if (无 === 100 && G.SEED累计(拉) === 100 && G.SEED已觉醒(拉) && G.SEED闪避加成(拉) === 31) {
    ok(`拉克丝（S1「无尽的 SEED」）：一次加 100 → 累计 ${G.SEED累计(拉)}（**不封顶**）、闪避 +${G.SEED闪避加成(拉)}（觉醒 ${G.势力觉醒值(拉)} × 0.15）；卡行「${G.势力卡行(拉)}」`);
  } else bad(`无尽 SEED 不对：加 ${无} / 累计 ${G.SEED累计(拉)} / 闪避 ${G.SEED闪避加成(拉)}`);
  const 无2 = G.加SEED(拉, 5, null);
  if (无2 === 5) ok(`觉醒后照样成长：再 +${无2} → 累计 ${G.SEED累计(拉)}、闪避 +${G.SEED闪避加成(拉)}`);
  else bad(`拉克丝觉醒后不涨了：+${无2}`);
}

/* ============================ [7] 同种子两次逐字相同 ============================ */
console.log('\n[7] 带种子的确定性：同种子两次跑，记录逐字相同');
{
  const 队 = [{ 键: 'S1', 位: 0, 等级: 10 }, { 键: 'S2', 位: 1, 等级: 10 }, { 键: 'S5', 位: 2, 等级: 10 }, { 键: 'B1', 位: 3, 等级: 10 }];
  const 跑 = 种子 => {
    const ctx = G.开局(队, 肉靶(), 种子);
    for (let i = 0; i < 4 && !ctx.result; i++) G.打一回合(ctx);
    return ctx;
  };
  const 甲 = 跑(20261011), 乙 = 跑(20261011);
  const s甲 = JSON.stringify(甲.log), s乙 = JSON.stringify(乙.log);
  if (s甲 === s乙) ok(`同种子跑 4 回合，${甲.log.length} 条记录逐字相同（SEED 的加重全走 \`ctx.rng\` / 纯函数，没有 \`Math.random\`）`);
  else bad('同种子两次结果不一致');
  const 势力录 = 甲.log.filter(x => x.类型 === '势力');
  if (势力录.length >= 4) ok(`这一场写了 ${势力录.length} 条 〔势力〕 记录，例如「${势力录[0].文本}」`);
  else bad(`〔势力〕记录太少：${势力录.length}`);
  const 觉醒录 = 势力录.filter(x => x.结果 === '觉醒');
  if (觉醒录.length === 3) ok(`4 回合里 3 台国防军都觉醒了一次，记录例如「${觉醒录[0].文本}」`);
  else info(`4 回合里觉醒 ${觉醒录.length} 次（第 4 回合结束时累计 15，本来就到不了 50 —— 阈值按长战斗设计，见「初稿·待调」）`);
  const 丙 = 跑(20261012);
  if (JSON.stringify(丙.log) !== s甲) ok('换种子结果就不一样（随机数确实在起作用）');
  else info('换种子记录一样（这一场太碾压时可能如此，不算错）');
  for (const 文件 of ['src\\js\\72-势力.js', 'src\\js\\71-改动.js']) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }
}

/* ============================ [8] 界面：单位卡上的那一行 ============================ */
console.log('\n[8] 界面：战斗屏单位卡看得出「SEED 层数 / 还差多少」');
{
  const 屏文字 = () => String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'S2', 位: 0 }, { 键: 'S5', 位: 1 }, { 键: 'B1', 位: 4 }];
  界面.开战(20261011);
  let html = 屏文字();
  const 行数 = (html.match(/class="faction"/g) || []).length;
  if (界面.屏 === '战斗' && 行数 === 2) ok(`战斗屏画了 ${行数} 行势力特色（我方 3 台里只有 S2 / S5 有）`);
  else bad(`战斗屏的势力行不对：屏 ${界面.屏}、${行数} 行`);
  if (html.includes('SEED 0/50（还差 50）')) ok('觉醒前写的是「SEED 0/50（还差 50）」');
  else bad(`卡上没写层数：${(html.match(/SEED[^<]*/g) || []).join(' / ')}`);
  G.加SEED(界面.ctx.allies.find(u => u.key === 'S2'), 50, 界面.ctx);
  G.加SEED(界面.ctx.allies.find(u => u.key === 'S5'), 30, 界面.ctx);
  界面.刷();
  html = 屏文字();
  if (html.includes('SEED 觉醒 · 觉醒 138 · 闪避 +21')) ok('觉醒后写「SEED 觉醒 · 觉醒 138 · 闪避 +21」（卡嘉莉 Lv10）');
  else bad(`觉醒后的行不对：${(html.match(/SEED[^<]*/g) || []).join(' / ')}`);
  if (html.includes('SEED 30/50（还差 20）')) ok('没觉醒的那台写「SEED 30/50（还差 20）」（史黛拉）');
  else bad(`未觉醒的行不对：${(html.match(/SEED[^<]*/g) || []).join(' / ')}`);
  if (!/undefined|NaN/.test(html)) ok('战斗屏 HTML 里没有 undefined / NaN');
  else bad('战斗屏 HTML 里出现了 undefined / NaN');
  /* 播放阶段读的是「快照」：快照要带上 `势力状态` / `awaken`，否则卡上会显示成 0 层。
     这里**真的打一回合**，直接看 `界面.显示单位`（快照）画出来的卡。 */
  if (界面.开打()) {
    const 快照S2 = 界面.显示单位.我方.find(u => u.key === 'S2');
    const 快照卡 = 界面.单位卡(快照S2, 'ally', null, false);
    const 段 = (快照卡.match(/<div class="faction">[^<]*<\/div>/) || ['（没有那一行）'])[0];
    if (段.includes('SEED 觉醒') && !/undefined|NaN/.test(快照卡)) {
      ok(`播放阶段的快照也带着势力状态：快照卡上还是「${段}」（不是 0 层）`);
    } else bad(`快照单位卡不对：${段}（觉醒 ${快照S2 && 快照S2.awaken} / 状态 ${JSON.stringify(快照S2 && 快照S2.势力状态)}）`);
    info(`这一回合打完，播放器${G.播放.在放() ? '还在放（手动播放，测试没有 tick）' : '已经放完'}`);
  } else bad('界面.开打() 没打起来（第 [8] 段的界面闭环断了）');
  const 别人 = 界面.单位卡({ side: 'ally', slot: 4, key: 'B1', name: '雷萨', maxHp: 100, hp: 100, tags: { 势力: '影世界', 战斗分类: '近卫' }, weapons: [] }, 'ally', null, false);
  if (!别人.includes('class="faction"')) ok('没有势力特色的单位（B1 影世界）不多画那一行');
  else bad('B1 的卡上也画了势力行');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '势力特色测试全部通过');
process.exit(fails ? 1 : 0);
