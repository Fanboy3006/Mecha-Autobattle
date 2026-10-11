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
 * 2026-10-11 追加**第二件 = 流星小队「单独行动」**（作者亲口重新定义：相邻和前方格子没有队友时战斗力提升）：
 *   [9] 一条一段，七件事：① 相邻位无队友 → 吃到；② 相邻位有队友 → 吃不到；
 *       ③ 前方（遮挡位）有 / 无队友各一条（后排位）；④ 前排单位按任务书写死的口径（不参与「前方」判定）；
 *       ⑤ 加成**真的进公式**（贴 dmgCore / hitRate 前后数字 + 一场真战斗的「带 vs 不带」）；
 *       ⑥ **只对我方生效**（挂到敌人身上不生效）；⑦ 同种子两次逐字相同 + 判定时机。
 *
 * 用法：node tests/faction.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';
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
  for (const 名 of ['势力开局', '势力回合开始', '势力回合结束', '势力击破', '势力友军攻击后', '势力闪避', '势力防御', '势力觉醒值', '势力卡行',
    '势力逐段未命中', '势力武器用后', '注册势力特色']) {
    if (typeof G[名] === 'function') ok(`框架钩子 \`${名}()\` 在 \`window.__game\` 上（后面 4 个势力共用）`);
    else bad(`\`${名}\` 没有暴露 / 不是函数`);
  }
  /* 2026-10-11：第二件（流星小队）/ 第三件（月球王国）/ 第四件（天人 TRANS-AM）也进了同一张表
     → 这里从「1 个条目」改成「四件都在」；
     2026-10-11 第五件（ATX「打空」按段）也进同一张表 → 现在是 5 个条目。 */
  const 表里 = Object.keys(G.势力特色表);
  if (表里.length === 5 && G.势力特色表['卫星国防军'] && G.势力特色表['流星小队']
    && G.势力特色表['月球王国'] && G.势力特色表['天人'] && G.势力特色表['ATX']) {
    ok(`\`势力特色表\` 现在有 5 个条目（${表里.join('、')}）——最后一个势力（秘银）往同一张表加`);
  } else bad(`势力特色表的内容不对：${JSON.stringify(表里)}`);
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

/* ==================== [9] 流星小队 · 单独行动（作者 2026-10-11 亲口重新定义） ====================
 * 作者原话（`协作/势力特色落地决定.md` 第 2 条）：「**相邻和前方格子没有队友的时候战斗力提升**」。
 *   相邻 = `相邻位(位)`（同排左右 + 有阻挡关系的对位）；前方 = `遮挡位(位)`（挡着后排位的前排位）。
 *   数值照战棋：`03-能力与减免管线.js:110` 的 `loneWolf:{dmg:u => isAlone(u) ? 20 : 0, eva:u => isAlone(u) ? 15 : 0}`
 *   （描述 `:46`；「伤害 +N%」= 攻击能力值 +N，`:185-188`）。★ 前排口径按任务书写死的那条（见 (e)）。 */
console.log('\n[9] 流星小队 · 单独行动：相邻 / 前方没有队友 → 伤害 +20、闪避 +15（作者原话重新定义，不是战棋原版）');
{
  const p = G.势力特色['流星小队'];
  const 面 = 位们 => (位们.length ? 位们.map(G.位名).join('、') : '（空）');
  /* 一格一格对出来的几何（贴出来给人看，少让人在脑子里摆格子）：
     前1=0 前2=1 前3=2 前4=3 / 后1=4 后2=5 后3=6 后4=7 后5=8 */
  const 检查位 = (位, 参) => G.流星检查位(位, 参);

  /* ---- (a) 参数与战棋 / 作者原话对账（数值逐字照抄，触发条件是作者换的义） ---- */
  if (p && p.伤害加成 === 20 && p.闪避加成 === 15) {
    ok(`数值与战棋逐字对账：伤害加成 = ${p.伤害加成}（03:110 的 dmg:20）、闪避加成 = ${p.闪避加成}（03:110 的 eva:15）　出处 ${p.出处}`);
  } else bad(`流星小队的数值不对：${JSON.stringify(p && { 伤害加成: p.伤害加成, 闪避加成: p.闪避加成 })}`);
  if (p && p.特技 === 'loneWolf' && p.初稿 === true) ok(`按数据里的 \`abilities: ['${p.特技}']\` 查（不手写名单）、整条标了「初稿」（触发条件是作者换的义，数值照战棋）`);
  else bad(`特技 / 初稿标记不对：${JSON.stringify(p && { 特技: p.特技, 初稿: p.初稿 })}`);
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === '流星小队').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档段 = 源码('协作\\势力特色.md').split('### 3.2 这个势力有哪些角色')[1].split('### 3.3')[0];
  const 文档名册 = 文档段.split('\n')
    .map(l => l.match(/^\|\s*(W\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: m[3] }));
  if (数据名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`数据里（\`tags.势力 === '流星小队'\`）正好 5 人，且与 \`协作/势力特色.md\` 第 3.2 节的成员表**逐行一致**：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  } else bad(`流星小队成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);
  info(`前1 的相邻位 = ${面(G.相邻位(0))}；前方（遮挡位(前1)）= ${面(G.遮挡位(0))} → 前排位没有「更前面的排」`);
  info(`后2 的相邻位 = ${面(G.相邻位(5))}；前方（遮挡位(后2)）= ${面(G.遮挡位(5))} → 后排位的「前方」是相邻位的子集`);

  /* ---- (b) 相邻位没有队友 → 吃到加成（顺带把「真的进公式」的前后数字贴出来） ---- */
  const ctxB = G.开局([{ 键: 'W2', 位: 0, 等级: 10 }], 肉靶(), 20261011);
  const W2 = ctxB.allies[0];
  if (G.流星孤立(W2) === true && G.势力闪避(W2) === 15 && G.buffSum(W2, 'dmg') === 20) {
    ok(`(b) 前1 单机（相邻位 ${面(G.相邻位(0))} 全空）→ \`流星孤立\` = true、势力闪避 +${G.势力闪避(W2)}、伤害加成 +${G.buffSum(W2, 'dmg')}`);
  } else bad(`(b) 相邻位没队友却没吃到：孤立 ${G.流星孤立(W2)} / 闪避 ${G.势力闪避(W2)} / dmg ${G.buffSum(W2, 'dmg')}`);
  const 开局录 = ctxB.log.filter(x => x.类型 === '势力').pop();
  if (开局录 && 开局录.结果 === '成立' && 开局录.文本.startsWith('〔势力〕')) ok(`开局就写了一条 \`〔势力〕\` 记录：「${开局录.文本}」`);
  else bad(`开局的〔势力〕记录不对：${JSON.stringify(开局录)}`);

  /* 命中 / 闪避：`hitRate` 的 eva 那一项 +15（战棋 03:110 的 eva:15）。
     ★ 闪避那 +15 读的是**缓存判定**（`势力闪避()` 的签名拿不到 ctx），不是 buff —— 要拿「没吃到」的基线，
       就把缓存翻过去（`势力状态.流星小队.孤立`），不是摘 buff。 */
  const 枪 = { name: '试作直射枪', fire: 'direct', hit: 100, dmgType: '物理', power: 1000, stat: '射击', range: [1, 1], upgrades: [] };
  const 敌 = G.makeUnit('grunt', 'enemy', 4, 10);
  const 状B = G.势力状态(W2, '流星小队');
  状B.孤立 = false; const 无前 = G.hitRate(敌, 枪, W2, { turn: 1 });
  状B.孤立 = true;  const 有前 = G.hitRate(敌, 枪, W2, { turn: 1 });
  info(`迪奥（W2 · 近卫）Lv10：闪避 ${W2.eva} → ${有前.eva}（势力闪避 +${G.势力闪避(W2)} 是从缓存判定读出来的）`);
  info(`同一把直射枪（命中 100）打它：命中原始值 ${无前.raw}% → ${有前.raw}%（结算 ${无前.hit}% → ${有前.hit}%）`);
  if (有前.raw === 无前.raw - 15 && 有前.eva === 无前.eva + 15) ok(`闪避 +15 真的进了公式：命中原始值 ${无前.raw} → ${有前.raw}、eva ${无前.eva} → ${有前.eva}（正好差 15）`);
  else bad(`命中没变：原始 ${无前.raw} → ${有前.raw}、eva ${无前.eva} → ${有前.eva}`);

  /* 伤害：战棋 v0.37 起「伤害 +20%」= **攻击能力值 +20**（03:185-188）。
     要看清「+20 攻击能力值 = 伤害 +20%」，把基准配成 statCoef = 1（攻击能力值 = 防御值、装甲 0）。 */
  const w斩 = W2.weapons.map(e => e.t).find(x => String(x.stat).includes('格斗'));
  const 干净靶 = () => { const t = G.makeUnit('grunt', 'enemy', 0, 6); t.armor = 0; t.eva = 0; return t; };
  const 靶 = 干净靶(); 靶.defense = G.atkStat(W2, w斩);
  W2.buffs = [];                                     // 临时摘掉这条 buff（下面判定会按规则挂回来）
  const d无 = G.dmgCore(W2, w斩, 靶, { power: G.wv(W2, w斩, 'power'), preview: true, turn: 1 }).dmg;
  G.判定流星小队(ctxB, p);                          // ← 判定会把这条 buff 按规则挂回来
  const d有 = G.dmgCore(W2, w斩, 靶, { power: G.wv(W2, w斩, 'power'), preview: true, turn: 1 }).dmg;
  const 比 = d有 / d无;
  info(`【${w斩.name}】打干净靶（装甲 0、防御 = 攻击能力值 ${G.atkStat(W2, w斩)}，系数正好 1.00）：${d无} → ${d有}`);
  info(`公式第 2 行：${G.dmgCore(W2, w斩, 靶, { power: G.wv(W2, w斩, 'power'), preview: true, turn: 1 }).steps[1]}`);
  if (Math.abs(比 - 1.2) < 0.005) ok(`伤害 +20（攻击能力值 +20）→ dmgCore ×${比.toFixed(3)}：${d无} → ${d有}（「伤害加成」那一段写进了公式步骤）`);
  else bad(`伤害加成没进公式：${d无} → ${d有}（比 ${比.toFixed(3)}，预期 1.2）`);
  if (String(G.势力卡行(W2)).includes('单独行动 · 伤害 +20 闪避 +15')) ok(`单位卡上写得出「吃到加成」：${G.势力卡行(W2)}`);
  else bad(`吃到加成时卡行不对：${G.势力卡行(W2)}`);

  /* ---- (c) 相邻位有队友 → 吃不到 ---- */
  const ctxC = G.开局([{ 键: 'W2', 位: 0, 等级: 10 }, { 键: 'W3', 位: 1, 等级: 10 }], 肉靶(), 20261011);
  const W2c = ctxC.allies.find(u => u.key === 'W2'), W3c = ctxC.allies.find(u => u.key === 'W3');
  info(`这一次前2（slot 1）站了 ${W3c.name}，而 slot 1 正在前1 的相邻位里（${面(G.相邻位(0))}）`);
  if (G.流星孤立(W2c) === false && G.势力闪避(W2c) === 0 && G.buffSum(W2c, 'dmg') === 0) ok(`(c) 相邻位有队友 → 吃不到：孤立 ${G.流星孤立(W2c)}、势力闪避 ${G.势力闪避(W2c)}、伤害加成 ${G.buffSum(W2c, 'dmg')}`);
  else bad(`(c) 相邻位有队友却还吃到了：孤立 ${G.流星孤立(W2c)} / 闪避 ${G.势力闪避(W2c)} / dmg ${G.buffSum(W2c, 'dmg')}`);
  if (G.流星孤立(W3c) === false) ok(`挨着的那台自己也吃不到（互相挡）：${W3c.name} 的相邻位 ${面(G.相邻位(1))} 里有前1 ${W2c.name}`);
  else bad(`${W3c.name} 不该吃到`);
  if (String(G.势力卡行(W2c)).includes('单独行动 未生效') && String(G.势力卡行(W2c)).includes('前2 特洛瓦')) ok(`卡行看得出来「没吃到」+ 是谁挡的：${G.势力卡行(W2c)}`);
  else bad(`没吃到时卡行不对：${G.势力卡行(W2c)}`);

  /* ---- (d) 前方（遮挡位）有 / 无队友各一条（都用**后排位**）---- */
  const ctxD = G.开局([{ 键: 'W4', 位: 5, 等级: 10 }, { 键: 'W2', 位: 1, 等级: 10 }], 肉靶(), 7);
  const W4d = ctxD.allies.find(u => u.key === 'W4'), W2d = ctxD.allies.find(u => u.key === 'W2');
  info(`后2（slot 5）的**前方** = 遮挡位 = ${面(G.遮挡位(5))}，这次 ${W2d.name} 就站在 前2（slot 1）`);
  if (G.流星孤立(W4d) === false && G.势力闪避(W4d) === 0) ok(`(d-前方有队友) 前方站着队友 → 吃不到：孤立 ${G.流星孤立(W4d)}、闪避 ${G.势力闪避(W4d)}、卡行「${G.势力卡行(W4d)}」`);
  else bad(`(d) 前方有队友却吃到了：孤立 ${G.流星孤立(W4d)} / 闪避 ${G.势力闪避(W4d)}`);
  W2d.slot = 3;                                      // 队友挪到 前4（既不在前方、也不在相邻位）
  G.判定流星小队(ctxD, p);
  if (G.流星孤立(W4d) === true && G.势力闪避(W4d) === 15) ok(`(d-前方没队友) 队友挪到 前4 之后 → 吃到：孤立 ${G.流星孤立(W4d)}、闪避 +${G.势力闪避(W4d)}、伤害加成 +${G.buffSum(W4d, 'dmg')}`);
  else bad(`(d) 前方没人了却没吃到：孤立 ${G.流星孤立(W4d)} / 闪避 ${G.势力闪避(W4d)}`);
  W2d.slot = 4;                                      // 后1：**不在**前方（遮挡位）里，但在相邻位里
  G.判定流星小队(ctxD, p);
  if (G.流星孤立(W4d) === false) ok(`（顺带钉住一条事实）后2 的「前方」${面(G.遮挡位(5))} 是「相邻位」${面(G.相邻位(5))} 的子集 —— 队友站在 后1 也照样让判定失效（${G.势力卡行(W4d)}）`);
  else bad('后排位的「前方」居然不是「相邻位」的子集');

  /* ---- (e) 前排口径：**前排单位不参与「前方」判定，只看相邻位**（任务书写死的那条；另一条候选见任务板）---- */
  const 前排遮挡空 = [0, 1, 2, 3].every(s => G.遮挡位(s).length === 0);
  if (前排遮挡空) ok(`(e) 四个前排位的 \`遮挡位()\` 全是空数组 → 前排没有「更前面的排」，「前方」那一条对前排天然恒成立（代码不用特判）`);
  else bad('前排位的遮挡位不是空的（口径要重写）');
  if (G.相邻位(3).includes(2)) ok(`(e) 另一条候选「前排位看它左边的同排位」**在几何上等价**：前4 的相邻位 ${面(G.相邻位(3))} 里本来就有左边那一格 前3 —— 换口径结果一个字节都不会变`);
  else bad('前4 的相邻位里没有左边那一格（候选口径不等价了，要重新算）');
  const ctxE = G.开局([{ 键: 'W4', 位: 3, 等级: 10 }, { 键: 'W2', 位: 5, 等级: 10 }], 肉靶(), 9);
  const W4e = ctxE.allies.find(u => u.key === 'W4'), W2e = ctxE.allies.find(u => u.key === 'W2');
  if (G.流星孤立(W4e) === true) ok(`(e) 前4（相邻位 ${面(G.相邻位(3))}）旁边没人、队友站在 后2（不在它的相邻位里）→ 照样吃到：闪避 +${G.势力闪避(W4e)}、伤害 +${G.buffSum(W4e, 'dmg')}`);
  else bad(`(e) 前4 没吃到：${G.势力卡行(W4e)}`);
  W2e.slot = 7;                                      // 后4 = 前4 的**阻挡位 / 对位**（在「相邻位」里）
  G.判定流星小队(ctxE, p);
  if (G.流星孤立(W4e) === false) ok(`(e) ★ 待作者确认的那条口径：队友站在前4 **正后方**的 后4（它的阻挡位 / 对位，\`相邻位()\` 把这两格也算「相邻」）→ 判定失效（${G.势力卡行(W4e)}）`);
  else bad('队友站到前排位的对位上却没让判定失效');

  /* ---- (f) 只对我方生效（挂到敌人身上不生效；队友不看势力） ---- */
  const ctxF = G.开局([{ 键: 'W2', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 4, 等级: 10 }], 11);
  const 敌F = ctxF.enemies[0];
  敌F.tags = Object.assign({}, 敌F.tags, { 势力: '流星小队' });
  敌F.abilities = ['loneWolf'];
  G.势力开局(ctxF);                                  // 重新判一次（敌人不在 `势力在场()` 里）
  if (G.势力名(敌F) === '流星小队' && !G.是我方势力(敌F, '流星小队')) ok(`敌人的 \`tags.势力\` 确实写成了流星小队，但 \`是我方势力()\` 为假（\`side === 'ally'\` 那道门）`);
  else bad('判定的门不对');
  if (G.势力闪避(敌F) === 0 && G.buffSum(敌F, 'dmg') === 0 && G.势力卡行(敌F) === '' && G.流星孤立(敌F) === false) {
    ok(`(f) 敌人身上一点不生效：势力闪避 ${G.势力闪避(敌F)}、伤害加成 ${G.buffSum(敌F, 'dmg')}、卡行「${G.势力卡行(敌F)}」、孤立 ${G.流星孤立(敌F)}`);
  } else bad(`(f) 敌人被算了加成：闪避 ${G.势力闪避(敌F)} / dmg ${G.buffSum(敌F, 'dmg')} / 卡行「${G.势力卡行(敌F)}」`);
  const ctxF2 = G.开局([{ 键: 'W2', 位: 0, 等级: 10 }, { 键: 'B1', 位: 1, 等级: 10 }], 肉靶(), 13);
  const W2f = ctxF2.allies.find(u => u.key === 'W2'), B1f = ctxF2.allies.find(u => u.key === 'B1');
  if (G.流星孤立(W2f) === false && G.势力闪避(B1f) === 0) {
    ok(`(f) 「队友」= **我方活着的单位**（战棋 \`a.side === u.side\`，**不看势力**）：影世界的 B1 站在前2 也算有人 → W2 吃不到；B1 自己没有这条特色（闪避 ${G.势力闪避(B1f)}）`);
  } else bad(`(f) 「不看势力」这条不对：W2 孤立 ${G.流星孤立(W2f)} / B1 闪避 ${G.势力闪避(B1f)}`);

  /* ---- (g) 判定时机（回合开始 / 击破）+ 同种子两次逐字相同 ---- */
  const ctxG = G.开局([{ 键: 'W2', 位: 0, 等级: 10 }, { 键: 'W3', 位: 1, 等级: 10 }], 肉靶(), 15);
  const W2g = ctxG.allies.find(u => u.key === 'W2'), W3g = ctxG.allies.find(u => u.key === 'W3');
  W3g.hp = 0;                                        // 队友阵亡
  G.势力击破(ctxG, ctxG.enemies[0], W3g);           // 引擎在击破时调的就是这个钩子
  const 击破录 = ctxG.log.filter(x => x.类型 === '势力').pop();
  if (G.流星孤立(W2g) === true && 击破录 && 击破录.结果 === '成立') {
    ok(`(g) 队友阵亡当场重判（击破钩子）：${W2g.name} 立刻吃到 +20 / +15 —— 记录「${击破录.文本}」`);
  } else bad(`(g) 阵亡后没重判：孤立 ${G.流星孤立(W2g)} / 记录 ${JSON.stringify(击破录)}`);
  const 流星队 = [{ 键: 'W1', 位: 0, 等级: 10 }, { 键: 'W3', 位: 1, 等级: 10 }, { 键: 'W2', 位: 8, 等级: 10 }, { 键: 'W4', 位: 6, 等级: 10 }];
  const 跑 = 种子 => {
    const ctx = G.开局(流星队, 肉靶(), 种子);
    for (let i = 0; i < 3 && !ctx.result; i++) G.打一回合(ctx);
    return ctx;
  };
  const 甲 = 跑(20261011), 乙 = 跑(20261011);
  if (JSON.stringify(甲.log) === JSON.stringify(乙.log)) ok(`(g) 同种子跑 3 回合，${甲.log.length} 条记录逐字相同（加成全走缓存 + \`ctx.rng\`，没有 \`Math.random\`）`);
  else bad('(g) 同种子两次结果不一致');
  const 势力录 = 甲.log.filter(x => x.类型 === '势力');
  info(`这一场写了 ${势力录.length} 条 \`〔势力〕\` 记录，例如「${势力录[0] && 势力录[0].文本}」`);

  /* ---- (g2) 一场真战斗：同种子「带 vs 不带」（关掉 `启用` 做对照，不改任何数值） ---- */
  const 编成条 = G.编成表.filter(x => x.层 === 2 && x.类型 === '精英')[0];
  const 敌队 = G.编成到单位(编成条, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
  const 打一场 = () => {
    const r = G.simulate(流星队, 敌队, null, 20261011);
    const 我方伤害 = r.记录.reduce((a, x) => a + (x.单位方 === 'ally' ? (x.伤害 || 0) : 0), 0);
    const 我方剩余 = r.我方.reduce((a, u) => a + Math.max(0, u.hp), 0);
    const 敌剩余 = r.敌方.reduce((a, u) => a + Math.max(0, u.hp), 0);
    return { 结果: r.结果, 回合数: r.回合数, 我方伤害, 我方剩余, 敌剩余, 记录: r.记录, 我方存活: r.我方.filter(u => u.hp > 0).length };
  };
  let 带 = null, 不带 = null;
  try {
    p.启用 = true; 带 = 打一场();
    p.启用 = false; 不带 = 打一场();
  } finally { p.启用 = true; }                        // 一定要还原（后面的段落 / 别的测试都靠默认值）
  info(`对照场：第 2 层精英「${编成条.考点}」（${敌队.length} 台，我方 4 台流星小队 Lv10、不下指令、同种子 ${20261011}）`);
  info(`关掉这套特色（\`启用: false\`）：${不带.结果} · ${不带.回合数} 回合 · 我方总伤害 ${不带.我方伤害} · 我方存活 ${不带.我方存活}/4 · 我方剩余 HP ${不带.我方剩余} · 敌剩余 ${不带.敌剩余}`);
  info(`带着这套特色      ：${带.结果} · ${带.回合数} 回合 · 我方总伤害 ${带.我方伤害} · 我方存活 ${带.我方存活}/4 · 我方剩余 HP ${带.我方剩余} · 敌剩余 ${带.敌剩余}`);
  info(`这一场的站位：前1 希罗 + 前2 特洛瓦（互相挨着 → 吃不到）、后5 迪奥 + 后3 卡托尔（周围空着 → 吃到）`);
  if (带.我方伤害 > 不带.我方伤害) ok(`(g) 同一场、同种子：带特色的一方打得更狠 —— 我方总伤害 ${不带.我方伤害} → ${带.我方伤害}、我方剩余 HP ${不带.我方剩余} → ${带.我方剩余}`);
  else bad(`(g) 带了特色反而打得少：${不带.我方伤害} → ${带.我方伤害}`);
  /* 同一台机体 + 同一把武器的**第一发**逐条对：吃到的两台（迪奥 / 卡托尔）伤害必须变高 */
  const 伤害键 = x => `${x.单位}【${x.武器}】`;
  const 首发表 = r => { const m = new Map(); for (const x of r.记录) if (x.类型 === '攻击' && x.伤害 > 0 && !m.has(伤害键(x))) m.set(伤害键(x), x); return m; };
  const 表带 = 首发表(带), 表不带 = 首发表(不带), 更狠 = [];
  for (const [k, x] of 表带) if (表不带.has(k) && x.伤害 > 表不带.get(k).伤害) 更狠.push(`${k} → ${x.目标} ${表不带.get(k).伤害} → ${x.伤害}`);
  if (更狠.length) ok(`(g) 同一台机体同一把武器的第一发真的更狠（${更狠.length} 处）：${更狠.slice(0, 3).join('；')}`);
  else bad(`(g) 没有一发的伤害变高（带：${JSON.stringify([...表带].map(([k, x]) => [k, x.伤害]))}）`);

  /* ---- (g3) 战斗屏单位卡上看得见（`80-界面.js` 的 `.faction` 那行） ---- */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'W2', 位: 0 }, { 键: 'W3', 位: 1 }, { 键: 'W4', 位: 8 }];
  界面.开战(20261011);
  const html = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 行数 = (html.match(/class="faction"/g) || []).length;
  if (界面.屏 === '战斗' && 行数 === 3) ok(`(g) 战斗屏画了 ${行数} 行势力特色（3 台流星小队都有）`);
  else bad(`战斗屏的势力行不对：屏 ${界面.屏}、${行数} 行`);
  if (html.includes('单独行动 · 伤害 +20 闪避 +15')) ok('卡上写得出「吃到加成」：`单独行动 · 伤害 +20 闪避 +15（相邻 / 前方 … 都没有队友）`');
  else bad(`卡上没写吃到加成：${(html.match(/单独行动[^<]*/g) || []).join(' / ')}`);
  if (html.includes('单独行动 未生效（前2 特洛瓦 在相邻 / 前方）')) ok('挨着的那两台写「单独行动 未生效（前2 特洛瓦 在相邻 / 前方）」');
  else bad(`没吃到那一行不对：${(html.match(/单独行动[^<]*/g) || []).join(' / ')}`);
  const 席德 = 界面.ctx.allies.find(u => u.key === 'W2');
  if (G.势力卡行(席德) === '' ) ok('（顺带）没这条能力的机体不会有这一行');
  else info(`W2 的卡行：${G.势力卡行(席德)}`);
}

/* ============ [10] 月球王国 · 围绕 Feena 构筑（作者 2026-10-11 拍板） ============
 * 作者原话（`协作/势力特色落地决定.md` 第 3 条）：
 *   「**月球王国是围绕 Feena 构筑，Feena 周围的队友大规模 buff**」
 *   「**大招残月的余响改成队友攻击时追加一次攻击**」「她可以操作质量加速器，相当于丢一个陨石下来」。
 * 这一段按任务书的七件事来：① 相邻位队友吃到光环、不在相邻位吃不到（各贴数字）；
 *   ② 队友攻击 → **真的追加一次攻击**（贴出手次数与伤害）；③ **每回合上限真的生效**（第 2 次不追）；
 *   ④ **Feena 自己攻击不触发**；⑤ **只对我方生效**；⑥ 旧的「残月的余响」**不再按范围伤害走**；
 *   ⑦ 同种子两次逐字相同。
 * 数值出处：**逐字照抄**战棋 `04-武器与机体.js:34-35`（← 本仓库复制件 `10-数据.js:53-55`，
 *   说明在 `docs/角色与敌人一览.md:719` / `协作/势力特色.md:259`）；
 *   换机制 / 光环范围（`相邻位(位)`）与初稿常量 = 作者 2026-10-11（决定文档第 3 条与 `:59`）。 */
console.log('\n[10] 月球王国：Feena 光环（相邻位队友大 buff）+ 残月的余响（队友攻击后追加一发）');
{
  const p = G.势力特色['月球王国'];
  const 光来源 = G.月球光环来源;
  const 枪 = { name: '试作直射枪', fire: 'direct', hit: 100, dmgType: '物理', power: 1000, stat: '射击', range: [1, 1], upgrades: [] };
  const 敌靶 = () => G.makeUnit('grunt', 'enemy', 4, 10);

  /* ---- (a) 参数 / 数值出处 / 成员表逐行一致 ---- */
  if (p && p.光环特技 === 'autoCast' && p.光环武器 === '月光祝福' && p.残月余响每回合上限 === 1 && p.初稿 === true) {
    ok(`参数：光环按数据里的 \`trait === '${p.光环特技}'\` 查（**不手写角色键**）、数值来源 = 数据里那把「${p.光环武器}」`
      + `（不另抄一份）、每回合上限 ${p.残月余响每回合上限}（**初稿·待作者调**）、整条标了「初稿」`);
    info(`出处登记：${p.出处}`);
  } else bad(`月球王国的参数不对：${JSON.stringify(p && { 光环特技: p.光环特技, 光环武器: p.光环武器, 残月余响每回合上限: p.残月余响每回合上限, 初稿: p.初稿 })}`);
  /* 光环数值 = 数据里「月光祝福」的 buff / upgrades（逐字照抄战棋 04-武器与机体.js:34-35） */
  const 月 = G.ALLY_T.find(t => t.mech === 'M1');
  const 祝 = 月 && 月.weapons.find(w => w.name === '月光祝福');
  const 档期望 = [
    [10, '04-武器与机体.js:34（buff: eva 15 / hit 15）', { eva: 15, hit: 15 }],
    [20, '04-武器与机体.js:35（upgrades lv20：再加 def 20 / crit 10）', { eva: 15, hit: 15, def: 20, crit: 10 }],
    [30, '04-武器与机体.js:35（upgrades lv30：eva 20 / hit 20 / def 30 / crit 15）', { eva: 20, hit: 20, def: 30, crit: 15 }],
  ];
  for (const [lv, 出处, 期望] of 档期望) {
    const u = G.makeUnit('M1', 'ally', 0, lv);
    const 实 = G.月光祝福数值(u, p);
    if (JSON.stringify(实) === JSON.stringify(期望)) ok(`光环数值 Lv${lv} 与战棋逐字对账：${G.光环文字(实)}　出处 ${出处}`);
    else bad(`Lv${lv} 的光环数值不对：${JSON.stringify(实)}，预期 ${JSON.stringify(期望)}`);
    if (祝 && JSON.stringify(G.wv(u, 祝, 'buff')) === JSON.stringify(期望)) info(`（同一条数值也确实是数据里「月光祝福」那一档：\`wv(u, 月光祝福, 'buff')\` = ${JSON.stringify(实)}）`);
  }
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === '月球王国').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档段 = 源码('协作\\势力特色.md').split('### 5.2 这个势力有哪些角色')[1].split('### 5.3')[0];
  const 文档名册 = 文档段.split('\n')
    .map(l => l.match(/^\|\s*(M\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: m[3] }));
  if (数据名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`数据里（\`tags.势力 === '月球王国'\`）正好 5 人，且与 \`协作/势力特色.md\` 第 5.2 节的成员表**逐行一致**：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  } else bad(`月球王国成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);

  /* ---- (b) 光环：相邻位吃到 / 不在相邻位吃不到（各贴数字） ---- */
  /* 前1=0 前2=1 前3=2 前4=3 / 后1=4 后2=5 后3=6 后4=7 后5=8
     Feena 站 前1（0）→ 相邻位 = 前2(1)、后1(4)、后2(5)（同排右边 + 她的两个对位） */
  const 队10 = [{ 键: 'M1', 位: 0, 等级: 10 }, { 键: 'M2', 位: 4, 等级: 10 }, { 键: 'M3', 位: 5, 等级: 10 }, { 键: 'M4', 位: 2, 等级: 10 }];
  const c10 = G.开局(队10, 肉靶(), 20261011);
  const 菲10 = c10.allies.find(u => u.key === 'M1'), M2 = c10.allies.find(u => u.key === 'M2');
  const M3 = c10.allies.find(u => u.key === 'M3'), M4 = c10.allies.find(u => u.key === 'M4');
  info(`Feena 站 ${G.位名(菲10.slot)} → 相邻位 = ${G.相邻位(菲10.slot).map(G.位名).join('、')}（同排左右 + 有阻挡关系的对位）`);
  const 状10 = G.势力状态(菲10, '月球王国');
  if (JSON.stringify(状10.光环名单) === JSON.stringify(['M2', 'M3']) && JSON.stringify(状10.光环位) === JSON.stringify([4, 5])) {
    ok(`(b) 相邻位上的队友吃到了：后1 阿布拉德(M2)、后2 Iris(M3)（判定缓存 \`光环名单\` = ${JSON.stringify(状10.光环名单)}）`);
  } else bad(`(b) 光环受益名单不对：${JSON.stringify(状10.光环名单)} / 位 ${JSON.stringify(状10.光环位)}`);
  if (G.buffSum(M2, 'hit') === 15 && G.buffSum(M2, 'eva') === 15 && G.buffSum(M3, 'hit') === 15) {
    ok(`(b) 吃到的人身上真的挂了加成：M2 命中 +${G.buffSum(M2, 'hit')}、闪避 +${G.buffSum(M2, 'eva')}；M3 命中 +${G.buffSum(M3, 'hit')}（Lv10 档 = 月光祝福的 Lv10 数值）`);
  } else bad(`(b) 加成没挂上：M2 hit ${G.buffSum(M2, 'hit')} / eva ${G.buffSum(M2, 'eva')}；M3 hit ${G.buffSum(M3, 'hit')}`);
  if (G.buffSum(M4, 'hit') === 0 && G.buffSum(M4, 'eva') === 0 && G.buffSum(M4, 'def') === 0 && G.buffSum(M4, 'crit') === 0) {
    ok(`(b) 不在相邻位的吃不到：前3 小太刀 Nagi(M4) 四项加成全是 0（他的相邻位 ${G.相邻位(M4.slot).map(G.位名).join('、')} 里没有 Feena）`);
  } else bad(`(b) 不在相邻位也吃到了：${JSON.stringify({ hit: G.buffSum(M4, 'hit'), eva: G.buffSum(M4, 'eva'), def: G.buffSum(M4, 'def'), crit: G.buffSum(M4, 'crit') })}`);
  if (G.buffSum(菲10, 'hit') === 0) ok('(b) Feena 自己不吃自己的光环（作者说的是「周围的队友」；战棋月光祝福也写「不含自己」）');
  else bad(`(b) Feena 自己也吃到了：${G.buffSum(菲10, 'hit')}`);
  const 光环录 = c10.log.filter(x => x.特色 === '月光环绕').pop();
  if (光环录 && 光环录.结果 === '生效' && 光环录.文本.startsWith('〔势力〕')) ok(`开局就写了一条 \`〔势力〕\` 记录：「${光环录.文本}」`);
  else bad(`开局的光环记录不对：${JSON.stringify(光环录)}`);

  /* 光环**真的进公式**：命中 / 闪避（`hitRate` 的 eva 项）、防御（`REDUCTIONS` 的防御增益）、暴击（`critRate`）。
     基线 = 手动把这条 buff 摘掉再算，算完按规则挂回来（判定的入口就是 `判定月球王国光环()`）。 */
  const 敌b = 敌靶();
  M2.buffs = M2.buffs.filter(b => b.src !== 光来源);          // 基线：先摘掉光环
  const 闪基 = G.hitRate(敌b, 枪, M2, { turn: 1 });
  const 攻基 = G.hitRate(M2, 枪, 敌b, { turn: 1 });
  const 暴基 = G.critRate(枪, M2);
  G.判定月球王国光环(c10, p);                                 // 按规则挂回来
  const 闪有 = G.hitRate(敌b, 枪, M2, { turn: 1 });
  const 攻有 = G.hitRate(M2, 枪, 敌b, { turn: 1 });
  const 暴有 = G.critRate(枪, M2);
  info(`同一把直射枪（命中 100）打 M2：没有光环命中原始值 ${闪基.raw}%（eva ${闪基.eva}）→ 有光环 ${闪有.raw}%（eva ${闪有.eva}）`);
  if (闪有.raw === 闪基.raw - 15 && 闪有.eva === 闪基.eva + 15) ok(`(b) 闪避 +15 真的进了公式：命中原始值 ${闪基.raw} → ${闪有.raw}、eva ${闪基.eva} → ${闪有.eva}`);
  else bad(`(b) 闪避没进公式：${闪基.raw} → ${闪有.raw}、eva ${闪基.eva} → ${闪有.eva}`);
  if (攻有.raw === 攻基.raw + 15) ok(`(b) 命中 +15 真的进了公式：M2 打人时命中原始值 ${攻基.raw} → ${攻有.raw}`);
  else bad(`(b) 命中没进公式：${攻基.raw} → ${攻有.raw}`);
  if (暴基 === 暴有) ok(`(b) Lv10 档不带暴击加成（与战棋 Lv10 档只有 eva / hit 一致）：暴击率 ${暴基}% → ${暴有}%`);
  else bad(`(b) Lv10 档多了暴击：${暴基} → ${暴有}`);
  /* Lv20 档：防御 +20 / 暴击 +10 真的进公式。★ 靶子剥掉装甲（重装的装甲 1875 > 威力时，
     伤害被压到「命中后最少 10」，防御 +20 就看不出来了）→ 用一把大威力的枪看清楚。 */
  const 重枪 = { name: '试作重炮', fire: 'direct', hit: 100, dmgType: '物理', power: 5000, stat: '射击', range: [1, 1], upgrades: [] };
  const c20 = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'M2', 位: 4, 等级: 20 }], 肉靶(), 7);
  const M2b = c20.allies.find(u => u.key === 'M2');
  const 敌c = 敌靶(); 敌c.armor = 0;
  M2b.buffs = M2b.buffs.filter(b => b.src !== 光来源);
  const 伤基 = G.dmgCore(敌c, 重枪, M2b, { power: 5000, preview: true, turn: 1 });
  const 暴基20 = G.critRate(重枪, M2b);
  G.判定月球王国光环(c20, p);
  const 伤有 = G.dmgCore(敌c, 重枪, M2b, { power: 5000, preview: true, turn: 1 });
  const 暴有20 = G.critRate(重枪, M2b);
  info(`Lv20 档挨同一发（威力 5000、靶子装甲剥掉）：没有光环 ${伤基.dmg} → 有光环 ${伤有.dmg}；${伤有.steps[1]}`);
  if (伤有.dmg < 伤基.dmg && 伤有.steps.join(' ').includes('防御增益 +20')) ok(`(b) Lv20 档的防御 +20 真的进了减免管线（stage 2 的「防御增益」）：伤害 ${伤基.dmg} → ${伤有.dmg}`);
  else bad(`(b) 防御 +20 没进公式：${伤基.dmg} → ${伤有.dmg}；${JSON.stringify(伤有.steps)}`);
  if (暴有20 === 暴基20 + 10) ok(`(b) Lv20 档的暴击 +10 真的进了公式：暴击率 ${暴基20}% → ${暴有20}%`);
  else bad(`(b) 暴击 +10 没进公式：${暴基20}% → ${暴有20}%`);

  /* ---- (c) 队友攻击 → 真的追加一次攻击（贴出手次数 / 伤害前后） ---- */
  const 靶队 = () => { const t = G.makeUnit('bluefish', 'enemy', 0, 1); t.hp = t.maxHp = 9999999; return t; };
  const cR = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }, { 键: 'CB2', 位: 1, 等级: 20 }],
    [{ 键: 'bluefish', 位: 0, 等级: 1 }], 20261011);
  const 靶R = cR.enemies[0]; 靶R.hp = 靶R.maxHp = 9999999;
  cR.rng = () => 0;                                    // 必中（引擎的随机数入口就是 ctx.rng）
  const 靶血前 = 靶R.hp;
  const 录R = G.打一回合(cR);
  const 攻R = 录R.filter(x => x.类型 === '攻击' && x.单位方 === 'ally');
  const 追R = 录R.filter(x => x.类型 === '残月余响');
  const 打掉 = 靶血前 - 靶R.hp;
  info(`第 1 回合：我方出手 ${攻R.length} 次（${攻R.map(x => x.单位).join('、')}）→ 追加 ${追R.length} 次；靶子一共掉了 ${打掉} HP`);
  if (攻R.length >= 2 && 追R.length === 1) ok(`(c) 队友攻击后**真的追加了一次攻击**（我方出手 ${攻R.length} 次 → 追加 ${追R.length} 次）：${追R[0].文本}`);
  else bad(`(c) 追加不对：我方出手 ${攻R.length} 次 → 追加 ${追R.length} 次`);
  if (追R.length && 追R[0].单位 === 'M1' && 追R[0].队友 !== 'M1' && 追R[0].伤害 > 0 && 追R[0].武器) {
    ok(`(c) 是 Feena 放的、记录里写着触发它的队友（队友 ${追R[0].队友}）、用的武器【${追R[0].武器}】、造成 ${追R[0].伤害} 伤害`);
  } else bad(`(c) 追加记录的字段不对：${JSON.stringify(追R[0])}`);
  if (追R.length && 追R[0].文本.startsWith('〔势力〕') && 追R[0].类型 === '残月余响') ok('(c) 记录还是 `pushLog` 那一套（`〔势力〕` 前缀 + `类型: 残月余响`），**记录格式没有改**');
  else bad(`(c) 记录格式不对：${JSON.stringify(追R[0])}`);
  /* 队友同回合第 2 次出手 → 不再追加（每回合上限）。
     ★ 这里不能用 `打一回合()` —— 它跑完会 `endTurn()` 并把 `ctx.turn++`，那就进下一回合了；
       要验「同一回合里的上限」，就直接对同一个 ctx 调两次 `resolveAction()`。 */
  const cU = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }, { 键: 'CB2', 位: 2, 等级: 20 }],
    [{ 键: 'bluefish', 位: 0, 等级: 1 }], 20261011);
  const 靶U = cU.enemies[0]; 靶U.hp = 靶U.maxHp = 9999999;
  cU.rng = () => 0;
  const 打一次 = u => {
    const 用 = G.usableWeapons(u, cU).find(e => !['支援', '修理'].includes(G.rangeKindOf(e.t)));
    G.resolveAction(u, { kind: 'attack', weapon: 用.t, target: 靶U, entry: 用 }, cU);
    return 用;
  };
  const 追数 = () => cU.log.filter(x => x.类型 === '残月余响').length;
  打一次(cU.allies.find(u => u.key === 'B2'));
  const 次1 = 追数();
  打一次(cU.allies.find(u => u.key === 'CB2'));
  const 次2 = 追数();
  if (次1 === 1 && 次2 === 1) ok(`(c) ★ 每回合上限真的生效：第 1 回合里第 1 个队友出手 → 追加 ${次1} 次，第 2 个队友再出手 → 还是 ${次2} 次（上限 ${p.残月余响每回合上限}）`);
  else bad(`(c) 每回合上限没生效：第 1 次出手后 ${次1} 次 → 第 2 次出手后 ${次2} 次`);
  G.endTurn(cU); cU.turn++;                        // 走一次回合结束 + 进入下一回合（`打一回合` 里就是这么走的）
  打一次(cU.allies.find(u => u.key === 'B2'));
  const 次3 = 追数();
  const 最新 = cU.log.filter(x => x.类型 === '残月余响').pop();
  if (次3 === 2 && 最新 && 最新.回合 === 2 && 最新.本回合第几次 === 1) {
    ok(`(c) 下一回合重新开一次（第 ${最新.回合} 回合又追加了 1 次、\`本回合第几次\` 回到 1）`);
  } else bad(`(c) 下一回合的追加不对：共 ${次3} 次（最新一条：${JSON.stringify(最新 && { 回合: 最新.回合, 第几次: 最新.本回合第几次 })}）`);

  /* ---- (d) Feena 自己攻击不触发 ---- */
  const cF2 = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 9);
  const 靶F = cF2.enemies[0]; 靶F.hp = 靶F.maxHp = 9999999;
  cF2.rng = () => 0;
  const 菲F = cF2.allies.find(u => u.key === 'M1');
  菲F.weapons.push({ t: 枪, cd: 0, uses: null, readyTurn: 1 });      // 临时给她一把普通武器（数据里她没有主动攻击武器）
  const 前F = cF2.log.length;
  const 打F = G.resolveAction(菲F, { kind: 'attack', weapon: 枪, target: 靶F, entry: 菲F.weapons[菲F.weapons.length - 1] }, cF2);
  const 新F = cF2.log.slice(前F);
  if (新F.some(x => x.类型 === '攻击' && x.伤害 > 0) && !新F.some(x => x.类型 === '残月余响')) {
    ok(`(d) ★ Feena 自己攻击（打了 ${(新F.find(x => x.类型 === '攻击') || {}).伤害} 伤害）**不触发**追加（作者的话是「队友攻击时」）`);
  } else bad(`(d) Feena 自己攻击触发了追加：${新F.map(x => `${x.类型}|${x.文本}`).join('｜')}`);
  /* 同一个回合里，**队友**再打一次 → 照样触发（说明 Feena 那一下没把次数用掉） */
  const 队F = cF2.allies.find(u => u.key === 'B2');
  const 用F = G.usableWeapons(队F, cF2).find(e => !['支援', '修理'].includes(G.rangeKindOf(e.t)));
  G.resolveAction(队F, { kind: 'attack', weapon: 用F.t, target: 靶F, entry: 用F }, cF2);
  if (cF2.log.filter(x => x.类型 === '残月余响').length === 1) ok('(d) 同一回合里队友随后出手照样触发（Feena 自己那一下没有占用这一回合的次数）');
  else bad(`(d) 队友随后出手没触发：${cF2.log.filter(x => x.类型 === '残月余响').length} 次`);
  /* 未命中（伤害 0）不算「造成伤害」 */
  const 未中 = cF2.log.length;
  G.势力友军攻击后(cF2, 队F, 靶F, { 伤害: 0 });
  if (cF2.log.length === 未中) ok('(d) 「一击伤害 0」（未命中）不走追加 —— 触发条件是**造成伤害之后**');
  else bad('(d) 伤害 0 也追加了');
  /* 敌人打我方的伤害不触发（框架那一层就挡住了：`攻击者.side === 'ally'`） */
  const 敌打 = cF2.log.length;
  G.势力友军攻击后(cF2, cF2.enemies[0], 菲F, { 伤害: 1234 });
  if (cF2.log.length === 敌打) ok('(d) 敌人造成伤害不走这个钩子（框架：`攻击者.side !== \'ally\'` 直接返回）');
  else bad('(d) 敌人也触发了追加');

  /* ---- (e) 只对我方生效 ---- */
  const cE = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'M2', 位: 4, 等级: 20 }], [{ 键: 'grunt', 位: 4, 等级: 20 }], 5);
  const 敌E = cE.enemies[0];
  敌E.tags = Object.assign({}, 敌E.tags, { 势力: '月球王国' });
  敌E.trait = 'autoCast';                              // 连「月光共鸣」也挂上
  G.势力开局(cE);
  if (G.势力名(敌E) === '月球王国' && !G.是我方势力(敌E, '月球王国')) ok('敌人的 `tags.势力` 确实写成了月球王国，但 `是我方势力()` 为假（`side === \'ally\'` 那道门）');
  else bad('判定的门不对');
  if ((敌E.buffs || []).every(b => b.src !== 光来源) && G.buffSum(敌E, 'hit') === 0 && G.势力卡行(敌E) === '' && !G.有月光共鸣(敌E, p)) {
    ok(`(e) 敌人一点不生效：身上没有光环 buff（命中 +${G.buffSum(敌E, 'hit')}）、卡行「${G.势力卡行(敌E)}」、\`有月光共鸣()\` = ${G.有月光共鸣(敌E, p)}（**只认我方**）`);
  } else bad(`(e) 敌人被算了光环：${JSON.stringify({ buffs: 敌E.buffs, hit: G.buffSum(敌E, 'hit'), 卡行: G.势力卡行(敌E) })}`);
  if (!(cE.allies.some(u => (u.buffs || []).some(b => b.src === 光来源)))) bad('(e) 我方反而没挂上光环（判定漏了）');
  else ok('(e) 同一场里我方的 M2 照常吃到光环（只屏蔽敌人，不是整套关掉）');
  const 敌伤前 = cE.log.length;
  G.势力友军攻击后(cE, 敌E, cE.allies.find(u => u.key === 'M2'), { 伤害: 999 });
  if (cE.log.length === 敌伤前) ok('(e) 敌人造成伤害也不会引出 Feena 的追加（框架只对我方调这个钩子）');
  else bad('(e) 敌人的伤害触发了追加');

  /* ---- (f) 旧的「残月的余响」不再按范围伤害走 ---- */
  const cG = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'CB2', 位: 1, 等级: 20 }],
    [{ 键: 'bluefish', 位: 4, 等级: 1 }, { 键: 'bluefish', 位: 5, 等级: 1 }], 11);
  const 敌甲 = cG.enemies.find(u => u.slot === 4), 敌乙 = cG.enemies.find(u => u.slot === 5);
  敌甲.hp = 敌甲.maxHp = 9999999; 敌乙.hp = 敌乙.maxHp = 9999999;
  cG.rng = () => 0;
  const 乙前 = 敌乙.hp;
  const 狙 = cG.allies.find(u => u.key === 'CB2');
  const 用狙 = G.usableWeapons(狙, cG).find(e => !['支援', '修理'].includes(G.rangeKindOf(e.t)));
  G.resolveAction(狙, { kind: 'attack', weapon: 用狙.t, target: 敌甲, entry: 用狙 }, cG);
  const 旧录 = cG.log.filter(x => x.类型 === '残月余响');
  if (敌乙.hp === 乙前 && 旧录.length <= 1 && 旧录.every(x => x.目标 === 敌甲.key)) {
    ok(`(f) ★ 不再是范围伤害：队友只打了 ${G.位名(敌甲.slot)} 的一台，追加的那一发也只落在它身上（同一个后排的另一台 ${G.位名(敌乙.slot)} 一点血都没掉：${乙前} → ${敌乙.hp}）`);
  } else bad(`(f) 还在按范围打：敌甲 ${敌甲.hp} / 敌乙 ${乙前} → ${敌乙.hp}；追加 ${JSON.stringify(旧录.map(x => x.目标))}`);
  const c旧2 = G.开局([{ 键: 'M1', 位: 4, 等级: 20 }], [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'shield', 位: 1, 等级: 10 }], 13);
  const 旧前 = c旧2.log.length;
  for (const u of c旧2.allies) G.runAutoCast(u, c旧2);
  if (c旧2.log.length === 旧前) ok('(f) 「行动结束后自动放、范围 = 敌方前排」那条旧路径**一条记录都不写**（`runAutoCast()` 认不出 `echoFollow`）');
  else bad(`(f) 旧路径还在跑：${c旧2.log.slice(旧前).map(x => x.文本).join('｜')}`);
  if (月 && !月.weapons.some(w => w.special === 'echo') && 月.weapons.some(w => w.special === G.残月余响标记)
    && G.残月余响范围 !== '敌方前排') {
    ok(`(f) 武器标记换成 \`${G.残月余响标记}\`、常量 \`残月余响范围\` 也不再写「敌方前排」（现在是「${G.残月余响范围}」）——威力 / 必中 / 物理一个字没改`);
  } else bad(`(f) 数据没换干净：${JSON.stringify((月 || {}).weapons.map(w => [w.name, w.special]))} / 范围 ${G.残月余响范围}`);

  /* ---- (g) 同种子两次逐字相同 ---- */
  const 月队 = [{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'M2', 位: 4, 等级: 20 }, { 键: 'M3', 位: 5, 等级: 20 }, { 键: 'M4', 位: 2, 等级: 20 }];
  const 跑 = 种子 => {
    const ctx = G.开局(月队, 肉靶(), 种子);
    for (let i = 0; i < 3 && !ctx.result; i++) G.打一回合(ctx);
    return ctx;
  };
  const 甲 = 跑(20261011), 乙 = 跑(20261011);
  if (JSON.stringify(甲.log) === JSON.stringify(乙.log)) ok(`(g) 同种子跑 3 回合，${甲.log.length} 条记录逐字相同（加成与追加全走 \`ctx.rng\` / 纯函数，没有 \`Math.random\`）`);
  else bad('(g) 同种子两次结果不一致');
  const 势力录 = 甲.log.filter(x => x.类型 === '势力' || x.类型 === '残月余响');
  info(`这一场写了 ${势力录.length} 条月球王国记录，例如「${(势力录[0] || {}).文本}」`);
  for (const 文件 of ['src\\js\\72-势力.js', 'src\\js\\71-改动.js']) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }

  /* ---- (h) 一场真战斗：同种子「带 vs 不带」（关掉 `启用` 做对照，不改任何数值） ---- */
  const 编成条 = G.编成表.filter(x => x.层 === 1 && x.类型 === '精英')[0];
  const 敌队 = G.编成到单位(编成条, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
  const 打一场 = () => {
    const r = G.simulate(月队, 敌队, null, 20261011);
    const 伤害 = 类型 => r.记录.reduce((a, x) => a + ((x.类型 === 类型 && x.单位方 === 'ally') ? (x.伤害 || 0) : 0), 0);
    return {
      结果: r.结果, 回合数: r.回合数, 攻击伤害: 伤害('攻击'), 追加伤害: 伤害('残月余响'),
      追加次数: r.记录.filter(x => x.类型 === '残月余响').length,
      我方剩余: r.我方.reduce((a, u) => a + Math.max(0, u.hp), 0),
    };
  };
  let 带 = null, 不带 = null;
  try {
    p.启用 = true; 带 = 打一场();
    p.启用 = false; 不带 = 打一场();
  } finally { p.启用 = true; }                          // 一定要还原（后面的段落 / 别的测试都靠默认值）
  info(`对照场：第 1 层精英「${编成条.考点}」（${敌队.length} 台，我方 4 台月球王国 Lv10、不下指令、同种子 ${20261011}）`);
  info(`关掉这套特色（\`启用: false\`）：${不带.结果} · ${不带.回合数} 回合 · 攻击伤害 ${不带.攻击伤害} · 追加 ${不带.追加次数} 次 / ${不带.追加伤害} 伤害 · 我方剩余 HP ${不带.我方剩余}`);
  info(`带着这套特色      ：${带.结果} · ${带.回合数} 回合 · 攻击伤害 ${带.攻击伤害} · 追加 ${带.追加次数} 次 / ${带.追加伤害} 伤害 · 我方剩余 HP ${带.我方剩余}`);
  info('（两场结束的回合数不同，所以「伤害总量」不能直接比 —— 记录里算的是每一击的满额伤害，含过量击杀；看回合数与剩余 HP 更准）');
  info(`这一场的站位：前1 Feena（光环中心）、后1 阿布拉德 + 后2 Iris（相邻位，吃到）、前3 Nagi（不在相邻位，吃不到）`);
  if (带.追加次数 > 0 && 带.追加伤害 > 0) ok(`(h) 真战斗里追加攻击真的打出来了：${带.追加次数} 次、共 ${带.追加伤害} 伤害（关掉特色时 ${不带.追加次数} 次）`);
  else bad(`(h) 真战斗里一次追加都没打出来：${JSON.stringify(带)}`);
  if (带.回合数 <= 不带.回合数 && 带.我方剩余 >= 不带.我方剩余) {
    ok(`(h) 同种子、同一场：带特色的一方打完更快 / 剩得更多 —— 回合数 ${不带.回合数} → ${带.回合数}、我方剩余 HP ${不带.我方剩余} → ${带.我方剩余}（光环的命中 / 闪避 / 防御与追加的那一发都在起作用）`);
  } else bad(`(h) 带了特色没变好：回合数 ${不带.回合数} → ${带.回合数}、我方剩余 HP ${不带.我方剩余} → ${带.我方剩余}`);

  /* ---- (i) 战斗屏单位卡那一行（`80-界面.js` 的 `.faction`） ---- */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'M1', 位: 0 }, { 键: 'M2', 位: 4 }, { 键: 'M4', 位: 2 }];
  界面.开战(20261011);
  const html = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 行数 = (html.match(/class="faction"/g) || []).length;
  if (界面.屏 === '战斗' && 行数 === 2) ok(`(i) 战斗屏画了 ${行数} 行势力特色（Feena 写「照到了谁」、吃到的 M2 写「吃到了」；不在相邻位的 M4 不多画）`);
  else bad(`(i) 战斗屏的势力行不对：屏 ${界面.屏}、${行数} 行`);
  if (html.includes('月光环绕 · 命中 +15、闪避 +15')) ok('(i) 卡上写得出「吃到了」：`月光环绕 · 命中 +15、闪避 +15（在 Feena 的相邻位）`');
  else bad(`(i) 卡上没写吃到光环：${(html.match(/月光环绕[^<]*/g) || []).join(' / ')}`);
  if (html.includes('月光环绕 · 命中 +15、闪避 +15（相邻位 后1 的队友吃到了）')) ok('(i) Feena 自己的卡上写着这条光环照到了哪一格');
  else bad(`(i) Feena 的卡不对：${(html.match(/月光环绕[^<]*/g) || []).join(' / ')}`);
  if (!/undefined|NaN/.test(html)) ok('(i) 战斗屏 HTML 里没有 undefined / NaN');
  else bad('(i) 战斗屏 HTML 里出现了 undefined / NaN');
}

/* ========== [11] 天人 · TRANS-AM（作者 2026-10-11 拍板：持续 2 回合 / CD 3 回合） ==========
 * 作者原话（`协作/势力特色落地决定.md` 第 4 条）：
 *   「战棋原版：持续 3 回合、威力 ×1.3 / 闪避 +15、冷却 10。
 *     **作者拍板：持续 2 回合、CD 3 回合**（其余倍数先照战棋 ×1.3 / 闪避 +15，标初稿）。
 *     落地要点：12 回合上限下 CD 3 是能开出多次的；记录里要能看出「开 / 关 / 冷却中」。」
 * 逐字出处（战棋 `Claude hand off/src/js/`，只读）：
 *   `17b-角色机制.js:122-147`（TA_LEN/TA_CD `:126`、taActive/taAfter/taReadyTurn/canTA `:127-138`、
 *     taButton `:139-145`、taPowMul `:146`、taMovAdd `:147`）、
 *   `03-能力与减免管线.js:14`（逐字描述 + Lv10 等级门）/`:130`（`transAm:{eva:…15…}`）、
 *   `15-战斗计算.js:36`（`wPow = … * taPowMul(u)`）。
 * 这一段按任务书的六件事来：① 参数与战棋逐字对账（含作者改的持续 2 / CD 3）；
 *   ② 持续真的 2 回合（第 1 回合开、第 2 回合仍生效、第 3 回合失效，贴回合号）；
 *   ③ CD 真的 3 回合（贴下一轮开启的回合号）；④ 威力 ×1.3 / 闪避 +15 真的进公式（贴伤害与命中前后数字）；
 *   ⑤ 只对我方生效（含拉塞 CB5 开不了）；⑥ 同种子两次逐字相同。 */
console.log('\n[11] 天人 · TRANS-AM（作者 2026-10-11 拍板：持续 2 回合 / CD 3 回合；威力 ×1.3 / 闪避 +15 照战棋）');
{
  const p = G.势力特色['天人'];
  const 枪 = { name: '试作直射枪', fire: 'direct', hit: 100, dmgType: '物理', power: 1000, stat: '射击', range: [1, 1], upgrades: [] };
  const 天人队 = [{ 键: 'CB1', 位: 0, 等级: 10 }, { 键: 'CB2', 位: 1, 等级: 10 }, { 键: 'CB3', 位: 2, 等级: 10 }, { 键: 'CB4', 位: 3, 等级: 10 }];

  /* ---- (a) 参数与战棋逐字对账（含作者改的两处：持续 2 / CD 3） ---- */
  const 对账 = [
    ['持续回合', 'TA_LEN（战棋 = 3）→ ★ 作者改成 2', 2, '17b-角色机制.js:126 + 协作/势力特色落地决定.md 第 4 条'],
    ['冷却回合', 'TA_CD（战棋 = 10）→ ★ 作者改成 3', 3, '17b-角色机制.js:126 + 协作/势力特色落地决定.md 第 4 条'],
    ['威力倍率', 'taPowMul：taActive ? 1.3 : 1（逐字）', 1.3, '17b:146（接线 15-战斗计算.js:36 的 wPow）'],
    ['闪避加成', 'TRAIT_FX.transAm.eva：taActive ? 15 : 0（逐字）', 15, '03-能力与减免管线.js:130'],
    ['解锁等级', 'ABIL.transAm.lv = 10（等级门）', 10, '03-能力与减免管线.js:14（门在 03:140 的 abilOn）'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 对账) {
    if (p[字段] === 值) ok(`${字段} = ${JSON.stringify(p[字段])}（${战棋名}）　出处 ${出处}`);
    else bad(`${字段} = ${JSON.stringify(p[字段])}，预期 ${JSON.stringify(值)}（${出处}）`);
  }
  if (p.特技 === 'transAm' && p.自动开启 === true && p.初稿 === true) {
    ok(`按数据里的 \`abilities: ['${p.特技}']\` 查（不手写名单）、**自动开启**（${p.自动开启}）、整条标了「初稿」`);
  } else bad(`特技 / 自动开启 / 初稿标记不对：${JSON.stringify({ 特技: p.特技, 自动开启: p.自动开启, 初稿: p.初稿 })}`);
  info(`出处登记：${p.出处}`);
  info(`威力倍率的落点（登记差异）：${p.威力倍率落点}`);
  info(`未接项 ${p.未接项.length} 条（照抄登记、这一版不接）：${p.未接项.map(x => x.项.split('：')[0]).join('；')}`);
  /* 未接项必须**照抄有出处**（不是我们瞎写）：每条都有「战棋」与「为什么不接」 */
  if (p.未接项.length === 4 && p.未接项.every(x => x.项 && x.战棋 && x.为什么不接)) {
    ok(`4 条未接项（移动 ±2 / 各人专属效果 / taOnly 专用招 / taMove）都写了战棋出处与不接的理由 —— **没有自己发明数值**`);
  } else bad(`未接项登记不完整：${JSON.stringify(p.未接项.map(x => x.项))}`);

  /* 成员：**按 10-数据.js 的 tags.势力 查**，并与 `协作/势力特色.md` 第 4.2 节的成员表逐行对 */
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === '天人').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档段 = 源码('协作\\势力特色.md').split('### 4.2 这个势力有哪些角色')[1].split('### 4.3')[0];
  const 文档名册 = 文档段.split('\n')
    .map(l => l.match(/^\|\s*(CB\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: m[3] }));
  if (数据名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`数据里（\`tags.势力 === '天人'\`）正好 5 人，且与 \`协作/势力特色.md\` 第 4.2 节的成员表**逐行一致**：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  } else bad(`天人成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);
  /* 谁能开：按 abilities 查（照战棋 C8「拉塞不能开 TRANS-AM」） */
  const 能开 = 数据名册.map(x => x.键).filter(k => G.有TRANSAM(G.makeUnit(k, 'ally', 0, 10), p));
  if (JSON.stringify(能开) === JSON.stringify(['CB1', 'CB2', 'CB3', 'CB4'])) {
    ok(`谁有开关按数据查：${能开.join('、')} 有 \`transAm\`，**CB5 拉塞没有**（照战棋 C8「拉塞不能开 TRANS-AM」，协作/势力特色.md:212）`);
  } else bad(`有 transAm 的人不对：${JSON.stringify(能开)}`);
  /* 与**战棋源码**逐字对一遍（只读旧仓库；本机没有旧仓库就只登记、不算失败） */
  const 战棋根 = join(ROOT, '..', 'mecha-tactics', 'Claude hand off', 'src', 'js');
  if (existsSync(战棋根)) {
    const 战棋源 = f => readFileSync(join(战棋根, f), 'utf8');
    const 逐字 = [
      ['17b-角色机制.js', 'const TA_LEN = 3, TA_CD = 10;', '战棋原版常量（我们按作者的话改成 2 / 3）'],
      ['17b-角色机制.js', 'const taPowMul = u => taActive(u) ? 1.3 : 1;', '威力 ×1.3 的逐字写法'],
      ['17b-角色机制.js', 'u.taEnd = turn + TA_LEN', '启动时算结束回合（我们照这个形状）'],
      ['17b-角色机制.js', 'const taReadyTurn = u => taOn(u) ? u.taEnd + TA_CD : 0;', '冷却到哪一回合（我们照这个形状）'],
      ['03-能力与减免管线.js', 'transAm:{eva:u => taActive(u) ? 15 : 0', '闪避 +15 的逐字写法'],
      ['15-战斗计算.js', '* taPowMul(u));', '×1.3 接在 wPow（威力）上 —— 我们落点的差异登记在参数表'],
    ];
    let 缺 = [];
    for (const [f, 片段, 说明] of 逐字) {
      if (!战棋源(f).includes(片段)) 缺.push(`${f}：${片段}`);
      else info(`战棋 ${f} 里确实有「${片段}」（${说明}）`);
    }
    if (!缺.length) ok(`与战棋源码逐字对账：6 条片段全在（只读旧仓库，一个字节都没改）`);
    else bad(`战棋源码里找不到这些片段：${缺.join('；')}`);
  } else info('（本机没有旧仓库 `F:\\DSH-mecha\\mecha-tactics` → 跳过与战棋源码的逐字核对，只按上面的出处行号对账）');

  /* 框架钩子：第 10 个数值钩子（伤害倍率）也在 __game 上 */
  if (typeof G.势力伤害倍率 === 'function') ok('框架新钩子 `势力伤害倍率(u, w)` 在 `window.__game` 上（默认 1 → 别的战斗逐字不变）');
  else bad('`势力伤害倍率` 没有暴露');

  /* ---- (b)(c) 真的打一场：持续 2 回合 / CD 3 回合 / 真实回合号 ----
     ★ 只把双方的 HP 顶高，让这一场**不会提前打完**（12 回合上限才看得到第 3 次开启）；
       状态机与 HP 无关，改 HP 不影响这一段要看的数字。 */
  const 跑一场 = 种子 => {
    const ctx = G.开局(天人队, [{ 键: 'bluefish', 位: 0, 等级: 1 }], 种子);
    for (const u of ctx.allies) { u.hp = u.maxHp = 999999; }
    for (const u of ctx.enemies) { u.hp = u.maxHp = 99999999; }
    const CB1 = ctx.allies.find(u => u.key === 'CB1');
    const 状 = () => G.势力状态(CB1, '天人');
    const 看 = 回合 => ({
      回合, 激活: 状().激活, 剩余: 状().剩余回合, 冷却中: 状().冷却中, 冷却剩余: 状().冷却剩余,
      启动回合: 状().启动回合, 结束回合: 状().结束回合, 冷却到回合: 状().冷却到回合, 第几次: 状().开启次数,
    });
    const 观 = [看(ctx.turn)];
    for (let i = 0; i < 11 && !ctx.result; i++) { G.打一回合(ctx); 观.push(看(ctx.turn)); }
    return { ctx, CB1, 观 };
  };
  const { ctx: cT, CB1: 刹, 观 } = 跑一场(20261011);
  const 激活回合 = 观.filter(x => x.激活).map(x => x.回合);
  const 冷却回合 = 观.filter(x => x.冷却中).map(x => x.回合);
  console.log('    回合  状态          剩余  冷却剩余  启动回合  生效到  冷却到');
  for (const x of 观) {
    console.log(`    ${String(x.回合).padStart(3)}   ${(x.激活 ? 'TRANS-AM 中' : x.冷却中 ? '冷却中' : '待机').padEnd(12)}`
      + `${String(x.剩余).padStart(3)}  ${String(x.冷却剩余).padStart(6)}  ${String(x.启动回合).padStart(7)}  ${String(x.结束回合 - 1).padStart(5)}  ${String(x.冷却到回合).padStart(5)}`);
  }
  info(`（这一段把双方 HP 顶高，只为了让 12 回合都走得完；状态机与 HP 无关）`);
  if (JSON.stringify(激活回合) === JSON.stringify([1, 2, 6, 7, 11, 12])) {
    ok(`② 持续真的 **2 回合**：第 1 回合开 → 第 ${激活回合[0]}、${激活回合[1]} 回合生效、第 3 回合**失效**（观里的「激活」回合号 = ${激活回合.join('、')}）`);
  } else bad(`持续不是 2 回合：激活的回合号 = ${JSON.stringify(激活回合)}，预期 [1,2,6,7,11,12]`);
  const 观3 = 观.find(x => x.回合 === 3), 观2 = 观.find(x => x.回合 === 2);
  if (观2.激活 && 观2.剩余 === 1 && !观3.激活 && 观3.冷却中) {
    ok(`② 第 2 回合仍生效（剩余 ${观2.剩余} 回合）、第 3 回合失效并进入冷却（第 3 回合冷却剩余 ${观3.冷却剩余} 回合）`);
  } else bad(`第 2 / 3 回合的状态不对：第 2 回合 ${JSON.stringify(观2)}、第 3 回合 ${JSON.stringify(观3)}`);
  const 启动录 = cT.log.filter(x => x.特色 === 'TRANS-AM' && x.结果 === '启动' && x.单位 === 'CB1').map(x => x.启动回合);
  const 结束录 = cT.log.filter(x => x.特色 === 'TRANS-AM' && x.结果 === '结束' && x.单位 === 'CB1');
  if (JSON.stringify(启动录) === JSON.stringify([1, 6, 11])) {
    ok(`③ CD 真的 **3 回合**：12 回合上限里**开了 3 次** —— 真实回合号 **第 ${启动录.join('、')} 回合**（相邻两次相隔 ${启动录[1] - 启动录[0]} = 持续 ${p.持续回合} + 冷却 ${p.冷却回合}）`);
  } else bad(`开启的回合号不对：${JSON.stringify(启动录)}，预期 [1,6,11]`);
  if (结束录.length === 2 && 结束录[0].启动回合 === 1 && 结束录[0].冷却到回合 === 6 && 结束录[1].启动回合 === 6 && 结束录[1].冷却到回合 === 11) {
    ok(`记录里看得出「关 / 冷却中」（战棋 taAfter / taReadyTurn 那一对）：第 3 回合与第 8 回合各写一条结束记录，例如「${结束录[0].文本}」`);
  } else bad(`结束记录不对：${JSON.stringify(结束录.map(x => ({ 回合: x.回合, 启动: x.启动回合, 冷却到: x.冷却到回合 })))}`);
  const 启动一条 = cT.log.find(x => x.特色 === 'TRANS-AM' && x.结果 === '启动' && x.单位 === 'CB1');
  if (启动一条 && 启动一条.文本.startsWith('〔势力〕') && 启动一条.持续回合 === 2 && 启动一条.冷却回合 === 3 && 启动一条.威力倍率 === 1.3) {
    ok(`启动记录带字段：持续 ${启动一条.持续回合} / 冷却 ${启动一条.冷却回合} / 威力倍率 ${启动一条.威力倍率} —— 「${启动一条.文本}」`);
  } else bad(`启动记录字段不对：${JSON.stringify(启动一条)}`);
  /* 4 台能在开的人**同回合一起开**（都按 CD 自动开，不用玩家点） */
  const 各台 = 天人队.map(x => x.键).map(k => {
    const u = cT.allies.find(y => y.key === k);
    return `${u.name}×${G.势力状态(u, '天人').开启次数}`;
  });
  if (各台.every(s => s.endsWith('×3'))) ok(`③ 四台（刹那 / 洛克昂 / 阿雷路亚 / 提耶利亚）都是**自动开**、各自开了 3 次：${各台.join('、')}`);
  else bad(`四台的开启次数不对：${各台.join('、')}`);

  /* ---- (d) 威力 ×1.3 / 闪避 +15 **真的进公式**（贴前后数字） ---- */
  const cD = G.开局([{ 键: 'CB2', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 4, 等级: 10 }], 20261011);
  const 狙 = cD.allies[0];
  const 状D = G.势力状态(狙, '天人');
  const 敌靶 = () => G.makeUnit('grunt', 'enemy', 4, 10);
  const 敌枪 = 敌靶();
  /* 闪避：`hitRate()` 的 eva 那一项 +15（战棋 03:130） */
  状D.激活 = false; const 闪前 = G.hitRate(敌枪, 枪, 狙, { turn: 1 });
  状D.激活 = true;  const 闪后 = G.hitRate(敌枪, 枪, 狙, { turn: 1 });
  info(`洛克昂（CB2 · 狙击）Lv10：基础 eva ${狙.eva}；同一把直射枪（命中 100）打它：`);
  info(`  关（未开 TRANS-AM）：命中原始值 ${闪前.raw}%（结算 ${闪前.hit}%、eva ${闪前.eva}）`);
  info(`  开（TRANS-AM 中）  ：命中原始值 ${闪后.raw}%（结算 ${闪后.hit}%、eva ${闪后.eva}）　势力闪避 ${G.势力闪避(狙)}`);
  if (闪后.eva === 闪前.eva + 15 && 闪后.raw === 闪前.raw - 15) {
    ok(`④ 闪避 +15 真的进了 hitRate() 的公式：eva ${闪前.eva} → ${闪后.eva}、命中原始值 ${闪前.raw} → ${闪后.raw}（正好差 15）`);
  } else bad(`闪避没进公式：eva ${闪前.eva} → ${闪后.eva}、raw ${闪前.raw} → ${闪后.raw}`);
  /* 伤害：走 `resolveAction`（框架新钩子 `势力伤害倍率` 就挂在它上面，`60-战斗.js`）。
     必中 + 不暴击（随机数走 ctx.rng：第 1 次判定命中、第 2 次判定暴击 → 0 / 0.999） */
  let 摇 = 0;
  cD.rng = () => (摇++ % 2 ? 0.999 : 0);
  const 打一发 = () => {
    const 靶 = 敌靶();
    const 前 = cD.log.length;
    G.resolveAction(狙, { kind: 'attack', weapon: 枪, target: 靶, entry: null }, cD);
    const 录 = cD.log.slice(前).find(x => x.类型 === '攻击');
    return 录;
  };
  状D.激活 = true;  const 录有 = 打一发();
  状D.激活 = false; const 录无 = 打一发();
  状D.激活 = true;   // 还原
  const 比 = 录有.伤害 / 录无.伤害;
  info(`同一发【${枪.name}】（威力 1000、必中、不暴击）打同一款量产机：`);
  info(`  关（未开 TRANS-AM）：${录无.文本}`);
  info(`  开（TRANS-AM 中）  ：${录有.文本}`);
  info(`  倍率入口读到的值：\`势力伤害倍率(洛克昂, 枪)\` 现在是 ${G.势力伤害倍率(狙, 枪)}；开时口径 = 参数表里的 威力倍率 = 1.3`);
  if (录有.伤害 === Math.round(录无.伤害 * 1.3) && Math.abs(比 - 1.3) < 0.001) {
    ok(`④ 威力 ×1.3 真的进了公式：伤害 ${录无.伤害} → ${录有.伤害}（×${比.toFixed(3)}，= round(${录无.伤害} × 1.3)）`);
  } else bad(`伤害没按 ×1.3 走：${录无.伤害} → ${录有.伤害}（比 ${比.toFixed(4)}，预期 ${Math.round(录无.伤害 * 1.3)}）`);
  /* ★ 登记差异：战棋乘在 `wPow`（威力）上，我们走现成的「伤害倍率」口子（公式之后）→
     `dmgCore` 本体前后**一模一样**，差的就是最后那一下 ×1.3。 */
  const 靶器 = 敌靶();
  const 干净 = { ...枪, power: 1000 };
  状D.激活 = false; const d核心无 = G.dmgCore(狙, 干净, 靶器, { power: 1000, preview: true, turn: 1 }).dmg;
  状D.激活 = true;  const d核心有 = G.dmgCore(狙, 干净, 靶器, { power: 1000, preview: true, turn: 1 }).dmg;
  if (d核心无 === d核心有) {
    ok(`★ 落点差异（如实登记）：\`dmgCore\` 本体前后一样（${d核心无} = ${d核心有}）—— 战棋把 ×1.3 乘在 \`wPow\`（威力，公式之前），我们走现成的「伤害倍率」口子（公式之后）；数值 1.3 逐字，位置差异写在参数表的 \`威力倍率落点\` 里`);
  } else bad(`dmgCore 本体被改了：${d核心无} → ${d核心有}（框架说好不动公式的）`);
  if (G.势力伤害倍率(狙, 枪) === 1.3) ok(`数值钩子直接读得到：\`势力伤害倍率(洛克昂, 枪)\` = ${G.势力伤害倍率(狙, 枪)}（关掉时 = 1）`);
  else bad(`势力伤害倍率 不对：${G.势力伤害倍率(狙, 枪)}`);

  /* ---- (e) 只对我方生效（含 CB5 拉塞开不了） ---- */
  const cE = G.开局([{ 键: 'CB1', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 4, 等级: 10 }], 5);
  const 敌E = cE.enemies[0];
  敌E.tags = Object.assign({}, 敌E.tags, { 势力: '天人' });
  敌E.abilities = ['transAm'];                          // 连能力也挂上
  G.势力开局(cE);                                        // 重新推一次（敌人不在 `势力在场()` 里）
  if (G.势力名(敌E) === '天人' && !G.是我方势力(敌E, '天人')) ok('敌人的 `tags.势力` 确实写成了天人，但 `是我方势力()` 为假（`side === \'ally\'` 那道门）');
  else bad('判定的门不对');
  const 敌状 = (敌E.势力状态 || {}).天人 || {};
  if (!敌状.激活 && G.势力伤害倍率(敌E, 枪) === 1 && G.势力闪避(敌E) === 0 && G.势力卡行(敌E) === '') {
    ok(`⑤ 敌人一点不生效：状态机没给它建状态（激活 ${!!敌状.激活}）、伤害倍率 ${G.势力伤害倍率(敌E, 枪)}、势力闪避 ${G.势力闪避(敌E)}、卡行「${G.势力卡行(敌E)}」`);
  } else bad(`⑤ 敌人被算了：${JSON.stringify({ 状: 敌状, 倍率: G.势力伤害倍率(敌E, 枪), 闪避: G.势力闪避(敌E), 卡行: G.势力卡行(敌E) })}`);
  if (G.势力伤害倍率(cE.allies[0], 枪) === 1.3 && G.势力闪避(cE.allies[0]) === 15) ok('⑤ 同一场里我方的刹那照常开到（倍率 1.3 / 闪避 +15）——只屏蔽敌人，不是整套关掉');
  else bad('⑤ 我方反而没开到');
  /* 拉塞 CB5：天的人，但数据里没有 `transAm`（战棋 C8）→ 一次都不进状态机 */
  const cL = G.开局([{ 键: 'CB5', 位: 0, 等级: 30 }], [{ 键: 'grunt', 位: 4, 等级: 10 }], 9);
  const 拉 = cL.allies[0];
  const 拉状 = (拉.势力状态 || {}).天人 || {};
  if (G.有TRANSAM(拉, p) === false && 拉状.激活 !== true && !(拉状.开启次数 > 0) && 拉状.已推进回合 == null
    && G.势力伤害倍率(拉, 枪) === 1 && G.势力闪避(拉) === 0 && G.势力卡行(拉) === '') {
    ok(`⑤ 拉塞（CB5，天人但没有 \`transAm\`）：\`有TRANSAM()\` = false、**一次都没进状态机**（\`已推进回合\` ${拉状.已推进回合}、\`开启次数\` ${拉状.开启次数}）、`
      + `倍率 ${G.势力伤害倍率(拉, 枪)}、闪避 ${G.势力闪避(拉)}、卡行「${G.势力卡行(拉)}」　照战棋 C8`);
  } else bad(`⑤ 拉塞被算了：${JSON.stringify({ 有: G.有TRANSAM(拉, p), 状: 拉状, 倍率: G.势力伤害倍率(拉, 枪), 卡行: G.势力卡行(拉) })}`);

  /* ---- (f) 同种子两次逐字相同 ---- */
  const 跑 = 种子 => {
    const ctx = G.开局(天人队, [{ 键: 'bluefish', 位: 0, 等级: 1 }], 种子);
    for (let i = 0; i < 6 && !ctx.result; i++) G.打一回合(ctx);
    return ctx;
  };
  const 甲 = 跑(20261011), 乙 = 跑(20261011);
  if (JSON.stringify(甲.log) === JSON.stringify(乙.log)) ok(`⑥ 同种子跑 6 回合，${甲.log.length} 条记录逐字相同（开启 / 结束全走回合号，没有 \`Math.random\`）`);
  else bad('⑥ 同种子两次结果不一致');
  const 丙 = 跑(20261012);
  if (JSON.stringify(丙.log) !== JSON.stringify(甲.log)) ok('⑥ 换种子结果就不一样（随机数确实在起作用）');
  else info('⑥ 换种子记录一样（这一场太碾压时可能如此，不算错）');
  const 势力录 = 甲.log.filter(x => x.特色 === 'TRANS-AM');
  info(`这一场写了 ${势力录.length} 条 TRANS-AM 记录，例如「${(势力录[0] || {}).文本}」`);
  for (const 文件 of ['src\\js\\72-势力.js', 'src\\js\\71-改动.js', 'src\\js\\60-战斗.js']) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }

  /* ---- (g) 一场真战斗：同种子「开 vs 关」（关掉 `启用` 做对照，不改任何数值） ---- */
  const 编成条 = G.编成表.filter(x => x.层 === 2 && x.类型 === '精英')[0];
  const 敌队 = G.编成到单位(编成条, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
  const 打一场 = () => {
    const r = G.simulate(天人队, 敌队, null, 20261011);
    return {
      结果: r.结果, 回合数: r.回合数,
      攻击伤害: r.记录.reduce((a, x) => a + (x.类型 === '攻击' && x.单位方 === 'ally' ? (x.伤害 || 0) : 0), 0),
      我方剩余: r.我方.reduce((a, u) => a + Math.max(0, u.hp), 0),
      我方存活: r.我方.filter(u => u.hp > 0).length,
      记录: r.记录,
    };
  };
  let 带 = null, 不带 = null;
  try {
    p.启用 = true; 带 = 打一场();
    p.启用 = false; 不带 = 打一场();
  } finally { p.启用 = true; }                          // 一定要还原（后面的段落 / 别的测试都靠默认值）
  info(`对照场：第 2 层精英「${编成条.考点}」（${敌队.length} 台，我方 4 台天人 Lv10、不下指令、同种子 ${20261011}）`);
  info(`关掉这套特色（\`启用: false\`）：${不带.结果} · ${不带.回合数} 回合 · 我方攻击伤害 ${不带.攻击伤害} · 我方存活 ${不带.我方存活}/4 · 剩余 HP ${不带.我方剩余}`);
  info(`带着这套特色（自动开）  ：${带.结果} · ${带.回合数} 回合 · 我方攻击伤害 ${带.攻击伤害} · 我方存活 ${带.我方存活}/4 · 剩余 HP ${带.我方剩余}`);
  const 键 = x => `${x.单位}【${x.武器}】`;
  const 首发表 = r => { const m = new Map(); for (const x of r.记录) if (x.类型 === '攻击' && x.伤害 > 0 && !m.has(键(x))) m.set(键(x), x); return m; };
  const 表带 = 首发表(带), 表不带 = 首发表(不带), 更狠 = [], 更少 = [];
  for (const [k, x] of 表带) {
    if (!表不带.has(k)) continue;
    if (x.伤害 > 表不带.get(k).伤害) 更狠.push(`${k} ${表不带.get(k).伤害} → ${x.伤害}`);
    else if (x.伤害 < 表不带.get(k).伤害) 更少.push(`${k} ${表不带.get(k).伤害} → ${x.伤害}`);
  }
  if (更狠.length && !更少.length) {
    ok(`(g) 同一台机体同一把武器的第一发**全部变狠**（${更狠.length} 处，一处都没变少）：${更狠.slice(0, 4).join('；')}`);
  } else bad(`(g) 对照不对：更狠 ${更狠.length} 处、更少 ${更少.length} 处 ${JSON.stringify(更少.slice(0, 3))}`);
  if (带.攻击伤害 > 不带.攻击伤害 && 带.我方剩余 >= 不带.我方剩余) {
    ok(`(g) 整场看：我方攻击伤害 ${不带.攻击伤害} → ${带.攻击伤害}、剩余 HP ${不带.我方剩余} → ${带.我方剩余}（回合数 ${不带.回合数} → ${带.回合数}）`);
  } else bad(`(g) 带了特色没变强：伤害 ${不带.攻击伤害} → ${带.攻击伤害}、剩余 ${不带.我方剩余} → ${带.我方剩余}`);

  /* ---- (h) 战斗屏单位卡上的那一行（`80-界面.js` 的 `.faction`） ---- */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'CB1', 位: 0 }, { 键: 'CB2', 位: 1 }, { 键: 'CB5', 位: 4 }];
  界面.开战(20261011);
  const html = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 行数 = (html.match(/class="faction"/g) || []).length;
  if (界面.屏 === '战斗' && 行数 === 2) ok(`(g) 战斗屏画了 ${行数} 行势力特色（CB1 / CB2 有；拉塞 CB5 没有 \`transAm\` → 不多画）`);
  else bad(`(g) 战斗屏的势力行不对：屏 ${界面.屏}、${行数} 行`);
  if (html.includes('TRANS-AM · 剩余 2 回合（威力 ×1.3、闪避 +15）')) ok('(g) 卡上写着「TRANS-AM · 剩余 2 回合（威力 ×1.3、闪避 +15）」（第 1 回合指令阶段，自动开出来的）');
  else bad(`(g) 卡上没写 TRANS-AM 那一行：${(html.match(/TRANS-AM[^<]*/g) || []).join(' / ')}`);
  if (!/undefined|NaN/.test(html)) ok('(g) 战斗屏 HTML 里没有 undefined / NaN');
  else bad('(g) 战斗屏 HTML 里出现了 undefined / NaN');
  /* 打完一回合 → 第 2 回合指令阶段：剩余 1 回合。
     ★ 先把双方 HP 顶高（这一场本来第 1 回合就打完了，`endTurn` 不会跑 → 进不到第 2 回合）。 */
  for (const u of 界面.ctx.enemies) { u.hp = u.maxHp = 99999999; }
  for (const u of 界面.ctx.allies) { u.hp = u.maxHp = 999999; }
  if (界面.开打()) {
    const ctxUI = 界面.ctx;
    const 状UI = G.势力状态(ctxUI.allies.find(u => u.key === 'CB1'), '天人');
    if (ctxUI.turn === 2 && 状UI.激活 && 状UI.剩余回合 === 1) {
      ok(`(g) 打完第 1 回合、进到第 2 回合的指令阶段：卡片读到的还是「剩余 1 回合」（回合结束推进下一回合 → 指令阶段看到的数字对得上当前回合）`);
    } else bad(`(g) 第 2 回合指令阶段的状态不对：回合 ${ctxUI.turn}、${JSON.stringify(状UI)}`);
  } else bad('(g) 界面.开打() 没打起来');
}

/* ========== [12] ATX · 「打空」按段 → 减大招冷却（作者 2026-10-11 拍板「按段」） ==========
 * 作者原话（`协作/势力特色落地决定.md` 第 5 条）：
 *   「**可以试试看按段，如果太过分继续加初始CD就行**」——
 *   「打空」= 武器没打中；**按段计**：多段武器（`w.hits > 1`）逐段判定，
 *   **每一段未命中都算一次「打空」**（不是「整次攻击全空才算一次」）。
 * 逐字出处（战棋 `Claude hand off/src/js/`，只读，一个字节都没改）：
 *   `17b-角色机制.js:73-91`（`EVADE_START = 10` :76、`evadeN` / `evadeCdCut` :77-78、
 *     每次打空 `cutCd(u, 1)` :79-86、余量一次性抵冷却 :87-91）、
 *   `03-能力与减免管线.js:17`（`gamblerSense` 的逐字描述）、
 *   `13-武器可用性.js:9,12-16`（`cutCd` / `readyTurnOf`）、
 *   `04-武器与机体.js:188`（左轮打桩机 `startCd:10 / cd:3 / evadeCd:true / hits:12`）← 复制件 `10-数据.js:207`。
 * ★ 「整次全空才算一次」的旧口径 ← `协作/势力特色.md:53`（作者这一条改的就是它）。
 * 这一段按任务书的七件事来：① 参数与战棋逐字对账（含「按段」这条是作者改的）；
 *   ② **多段逐段判定**：1 段中 1 段空 = 记 **1** 次（不是 0 也不是 2）；
 *   ③ 全部打空 = 记 `hits` 次；④ 打空**真的减大招冷却**（贴冷启前后的回合数字）；
 *   ⑤ **初始 CD / 每回合上限**真的生效；⑥ **只对我方生效**；⑦ 同种子两次逐字相同。 */
console.log('\n[12] ATX · 「打空」按段 → 减大招冷却（作者 2026-10-11：「可以试试看按段，如果太过分继续加初始CD就行」）');
{
  const p = G.势力特色['ATX'];
  const 打空录 = (ctx, 单位) => ctx.log.filter(x => x.类型 === '势力' && x.特色 === '赌徒的直觉'
    && x.结果 === '打空' && (!单位 || x.单位 === 单位));
  const 造靶 = () => G.makeUnit('bluefish', 'enemy', 0, 1);        // HP 240000：打不死，能一直当靶子
  /** 用一串**指定的随机数**打一发（`resolveAttack()` 的取数顺序：每段先判命中，命中后才判暴击）。 */
  const 一枪 = (ctx, att, w, 队列, t) => {
    const 靶 = t || 造靶();
    let i = 0;
    const 旧 = ctx.rng;
    ctx.rng = () => (i < 队列.length ? 队列[i++] : (队列.length ? 队列[队列.length - 1] : 0));
    const r = G.resolveAttack(att, 靶, w, ctx, {});
    ctx.rng = 旧;
    return r;
  };
  /** 把这一把武器的**结算命中率**调到 50%（这样「中 / 空」各用一个固定随机数就能稳住）。 */
  const 调到五十 = (ctx, att, w, 靶) => {
    const h0 = G.hitRate(att, w, 靶, { baseHit: 0, turn: ctx.turn }).raw;
    w.hit = 50 - h0;
    return G.hitRate(att, w, 靶, { baseHit: w.hit, turn: ctx.turn }).hit;
  };
  /** 一把「必定打空」的枪（结算命中率 0：`rng() * 100 < 0` 永远为假）—— 用来精确数「段」。 */
  const 必空枪 = () => ({ name: '测试·必空枪', fire: 'direct', hit: -999, dmgType: '物理', power: 1, stat: '射击', range: [1, 1], hits: 1, upgrades: [] });

  /* ---- (a) 参数与战棋逐字对账（「按段」这条是作者改的） ---- */
  const 对账 = [
    ['余量起算', 'EVADE_START', 10, '17b-角色机制.js:76'],
    ['每段减冷却', 'cutCd(u, 1)', 1, '17b-角色机制.js:83'],
    ['特技', "abilOn(u,'gamblerSense') / ABIL.gamblerSense", 'gamblerSense', '03-能力与减免管线.js:17'],
    ['武器标记', 'u.weapons.some(w => w.evadeCd && u.lv >= w.unlock)', 'evadeCd', '17b-角色机制.js:81'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 对账) {
    if (p[字段] === 值) ok(`${字段} = ${JSON.stringify(p[字段])}（战棋 ${战棋名}）　出处 ${出处}`);
    else bad(`${字段} = ${JSON.stringify(p[字段])}，战棋是 ${JSON.stringify(值)}（${出处}）`);
  }
  /* ★ 两个「初稿·待作者调」的常量：默认值 + 理由（**不自己发明平衡数值**） */
  if (p.初始CD === 0 && p.每回合上限 === 0 && p.初稿 === true) {
    ok(`两个常量都是初稿且默认「不动数据」：\`初始CD = ${p.初始CD}\`（= 照数据，左轮打桩机的开场冷却 10 在 \`10-数据.js:207\` 原样）、\`每回合上限 = ${p.每回合上限}\`（= 不封顶，照战棋 \`17b:79-86\` 全场累计、没有每回合上限）`);
  } else bad(`两个初稿常量的默认值不对：初始CD ${p.初始CD} / 每回合上限 ${p.每回合上限} / 初稿 ${p.初稿}`);
  info(`出处登记：${p.出处}`);
  info(`未接项 ${p.未接项.length} 条（照抄登记、这一版不接）：${p.未接项.map(x => x.项.split('：')[0].split('（')[0]).join('；')}`);
  if (p.未接项.length === 7 && p.未接项.every(x => x.项 && x.战棋 && x.为什么不接 && x.换义建议)) {
    ok('7 条未接项（烟雾 / 迷彩 / 好运加护 / 赌神与四个个人特技 / 双势力 / 随机段数 / 反击那一半）'
      + '都写了战棋出处、不接的理由与**换义建议** —— 位置类（烟雾 / 迷彩）交作者拍板，没有自己发明数值');
  } else bad(`未接项登记不完整：${JSON.stringify(p.未接项.map(x => x.项))}`);

  /* 「按段」这条**是作者改的**：把战棋的旧口径与我们的新口径都摆出来 */
  const 战棋根12 = join(ROOT, '..', 'mecha-tactics', 'Claude hand off', 'src', 'js');
  if (existsSync(战棋根12)) {
    const 战棋源12 = f => readFileSync(join(战棋根12, f), 'utf8');
    const 逐字 = [
      ['17b-角色机制.js', 'const EVADE_START = 10;', 'EVADE_START（余量起算）逐字'],
      ['17b-角色机制.js', 'const evadeCdCut = u => Math.max(0, evadeN(u) - EVADE_START);', '余量的逐字算法'],
      ['17b-角色机制.js', 'u.evN = evadeN(u) + 1; u.evB = BATTLE_ID;', '记账（本场累计）逐字'],
      ['17b-角色机制.js', 'cutCd(u, 1);', '每次打空减 1 点冷却（逐字）'],
      ['17b-角色机制.js', 'if (cut >= w.cd) w.cdLeft = 0; else if (cut > 0) w.cdLeft = Math.max(0, w.cdLeft - cut);', '余量抵冷却（逐字）'],
      ['13-武器可用性.js', 'if (w.cdLeft > 0) w.cdLeft = Math.max(0, w.cdLeft - n);', 'cutCd 里减普通冷却那一行'],
      ['13-武器可用性.js', 'return et + sc - (u.cdCutB === BATTLE_ID ? u.cdCut : 0);', '开场冷却被 cdCut 抵掉（readyTurnOf）'],
      ['03-能力与减免管线.js', "gamblerSense:{name:'赌徒的直觉'", '能力 key 逐字'],
      ['17-战斗执行.js', "Hooks.emit('strikeResolved', {att, def, w, hit:nh > 0", '战棋旧口径：多段只在**循环外**发一次（整次全空才算一次）'],
    ];
    let 缺 = [];
    for (const [f, 片段, 说明] of 逐字) {
      if (!战棋源12(f).includes(片段)) 缺.push(`${f}：${片段}`);
      else info(`战棋 ${f} 里确实有「${片段}」（${说明}）`);
    }
    if (!缺.length) ok(`与战棋源码逐字对账：${逐字.length} 条片段全在（只读旧仓库，一个字节都没改）`);
    else bad(`战棋源码里找不到这些片段：${缺.join('；')}`);
    /* 数据也对一遍：左轮打桩机的四个键（startCd / cd / evadeCd / unlock）逐字 */
    const 数据源 = 源码('src\\js\\10-数据.js');
    const 桩数据 = ['左轮打桩机', 'hits:12', 'step:10', 'cd:3', 'unlock:20', 'startCd:10', 'evadeCd:true'].filter(s => 数据源.includes(s));
    if (桩数据.length === 7) ok(`数据逐字对账：\`10-数据.js\` 里左轮打桩机带着 ${桩数据.slice(1).join(' / ')}（照抄战棋 04-武器与机体.js:188，一个字没改）`);
    else bad(`数据里左轮打桩机的字段不全：${JSON.stringify(桩数据)}`);
  } else info('（本机没有旧仓库 `F:\\DSH-mecha\\mecha-tactics` → 跳过与战棋源码的逐字核对，只按上面的出处行号对账）');
  /* 我们自己这一侧：新钩子确实发在「逐段判定」的循环里（不是整次攻击之后） */
  const 计算源 = 源码('src\\js\\20-战斗计算.js');
  const 未中段 = 计算源.split('第 ${i + 1} 段（${q}%）未中')[1] || '';
  if (未中段.includes('势力逐段未命中(ctx, att, def, w, { 段号: i + 1, 段数: hits')) {
    ok('`20-战斗计算.js` 的**逐段未命中分支**里发了 `势力逐段未命中(…, {段号: i + 1, 段数: hits…})` —— 这就是作者要的「按段」（战棋旧口径是整次攻击只发一次）');
  } else bad('没有在逐段循环里发新钩子（那就退化成战棋的「整次全空才算一次」了）');
  for (const 文件 of ['src\\js\\72-势力.js', 'src\\js\\71-改动.js', 'src\\js\\20-战斗计算.js', 'src\\js\\60-战斗.js']) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }

  /* 成员：按 `tags.势力` 查，并与 `协作/势力特色.md` 第 1.2 节的成员表逐行对 */
  const 去括号 = s => String(s).replace(/（.*$/, '').trim();
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === 'ATX').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档段 = 源码('协作\\势力特色.md').split('### 1.2 这个势力有哪些角色')[1].split('### 1.3')[0];
  const 文档名册 = 文档段.split('\n')
    .map(l => l.match(/^\|\s*(A\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: 去括号(m[3]) }));
  if (数据名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`数据里（\`tags.势力 === 'ATX'\`）正好 5 人，且与 \`协作/势力特色.md\` 第 1.2 节的成员表**逐行一致**：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  } else bad(`ATX 成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);
  /* 谁吃这条特色：按数据里的 `abilities` 查（**不手写名单**） */
  const 吃得 = 数据名册.map(x => x.键).filter(k => G.有赌徒直觉(G.makeUnit(k, 'ally', 0, 20), p));
  if (JSON.stringify(吃得) === JSON.stringify(['A1'])) {
    ok(`按数据里的 \`abilities\` 查：只有 ${吃得.join('、')} 响介有 \`gamblerSense\`（\`10-数据.js:204\`），其余四人吃不到 —— 不手写名单`);
  } else bad(`有 gamblerSense 的人不对：${JSON.stringify(吃得)}`);
  if (G.是减冷却武器(G.ALLY_T.find(t => t.mech === 'A1').weapons.find(w => w.name === '左轮打桩机'), p)
    && !G.是减冷却武器(G.ALLY_T.find(t => t.mech === 'A1').weapons.find(w => w.name === '三连机炮'), p)) {
    ok('`是减冷却武器()`：左轮打桩机（`evadeCd: true`）吃，三连机炮不吃 —— 按数据里的标记查');
  } else bad('`是减冷却武器()` 判据不对');

  /* ---- (b)(c) 多段武器**逐段**判定：贴数字 ---- */
  const cB = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 20261011);
  const 响 = cB.allies[0];
  const 双段 = { name: '测试·双段枪', fire: 'direct', hit: 100, dmgType: '物理', power: 100, stat: '射击', range: [1, 1], hits: 2, upgrades: [] };
  const q2 = 调到五十(cB, 响, 双段, 造靶());
  const 中2 = (q2 - 20) / 100, 空2 = (q2 + 20) / 100;
  info(`测试武器【${双段.name}】：${双段.hits} 段，结算命中率调到 ${q2}%（第 1 段用一个「中」的随机数 ${中2}、第 2 段用一个「空」的 ${空2}）`);
  const 三发 = [];
  for (const [名, 队列, 期望] of [
    ['两段全中', [中2, 0.999, 中2, 0.999], 0],
    ['**1 段中 1 段空**', [中2, 0.999, 空2], 1],
    ['两段全空', [空2, 空2], 2],
  ]) {
    const 前 = G.ATX打空(响), 录前 = 打空录(cB, 'A1').length;
    const r = 一枪(cB, 响, 双段, 队列);
    const 打 = G.ATX打空(响) - 前, 条 = 打空录(cB, 'A1').length - 录前;
    if (打 === 期望 && 条 === 期望) {
      ok(`②③ ${名} → 记 **${打}** 次打空（记录 ${条} 条）：${r.字段.命中段数}/${r.字段.段数} 段命中 —— 「${r.文本}」`);
    } else bad(`${名} 记成了 ${打} 次（预期 ${期望}）、记录 ${条} 条`);
    三发.push({ 名, 打, 命中段数: r.字段.命中段数, 段数: r.字段.段数, 文本: r.文本 });
  }
  info(`逐段判定的数字：${三发.map(x => `${x.名} ${x.命中段数}/${x.段数} 段命中 → 打空 ${x.打} 次`).join('；')}`);
  if (三发[1].打 === 1) ok('★ 作者要的「按段」成立：**1 段中 1 段空 = 1 次打空**（不是 0 —— 旧口径整次攻击 `hit: 命中段数 > 0` 会算 0；也不是 2 —— 那是把命中段也算进去了）');
  else bad('「1 段中 1 段空」不是 1 次');
  const 四段 = { name: '测试·四段枪', fire: 'direct', hit: -999, dmgType: '物理', power: 1, stat: '射击', range: [1, 1], hits: 4, upgrades: [] };
  const 前4 = G.ATX打空(响), 录前4 = 打空录(cB, 'A1').length;
  const r4 = 一枪(cB, 响, 四段, [0.9]);
  const 打4 = G.ATX打空(响) - 前4, 条4 = 打空录(cB, 'A1').length - 录前4;
  const 段号们 = 打空录(cB, 'A1').slice(-4).map(x => x.段号);
  if (打4 === 4 && 条4 === 4 && JSON.stringify(段号们) === JSON.stringify([1, 2, 3, 4])) {
    ok(`③ 全部打空 → 记 **${打4}** 次 = \`hits\` 段数（${r4.字段.命中段数}/${r4.字段.段数}），记录里段号 ${段号们.join('、')} 逐段都在`);
  } else bad(`全空时记了 ${打4} 次（预期 4）、记录 ${条4} 条、段号 ${JSON.stringify(段号们)}`);

  /* ---- (d) 打空**真的减大招冷却**（贴冷启前后的回合数字） ---- */
  const 新场 = 种子 => {
    const ctx = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 种子);
    const 介 = ctx.allies[0];
    const 枪 = 介.weapons.find(e => e.t.name === '左轮打桩机');
    return { ctx, 介, 枪, 靶: ctx.enemies[0] };
  };
  const 可用吗 = (介, 回合) => G.usableWeapons(介, { turn: 回合 }).some(e => e.t.name === '左轮打桩机');
  const 甲场 = 新场(20261011);
  info(`响介（A1）Lv20 的左轮打桩机（数据 10-数据.js:207：hits:12 / cd:3 / unlock:20 / startCd:10 / evadeCd:true）`
    + ` 开局时：\`readyTurn\` = **${甲场.枪.readyTurn}**（= 1 + startCd 10 → 第 10 回合还不能用、第 11 回合起可用：`
    + `第 10 回合 ${可用吗(甲场.介, 10)}、第 11 回合 ${可用吗(甲场.介, 11)}）`);
  for (let i = 0; i < 10; i++) 一枪(甲场.ctx, 甲场.介, 必空枪(), [0.999], 甲场.靶);
  info(`打空 ${G.ATX打空(甲场.介)} 段之后：\`readyTurn\` = **${甲场.枪.readyTurn}**（第 1 回合起就能用：`
    + `第 1 回合 ${可用吗(甲场.介, 1)}；余量 \`ATX余量()\` = ${G.ATX余量(甲场.介, p)}）`);
  if (甲场.枪.readyTurn === 1 && G.ATX打空(甲场.介) === 10 && 可用吗(甲场.介, 1) && !可用吗(甲场.介, 0)) {
    ok(`④ 开场冷却真的被打空减掉了：\`readyTurn\` **11 → 1**（10 段打空 × 每段 −1 = −10，正好等于 startCd 10）→ 第 1 回合起可用`);
  } else bad(`④ 开场冷却没减对：readyTurn ${甲场.枪.readyTurn}、打空 ${G.ATX打空(甲场.介)}`);
  /* ④-1 规则本体：战棋 `17b:87-91` 的两条支路（`cut >= w.cd` 一次性归零 / 否则抵掉 cut 点）。
     直接调框架钩子 `势力武器用后()`，累计（战棋 `u.evN`）与出手后的 cd（战棋 `w.cdLeft`）都是我们摆好的 → 数字干净。 */
  const 直测 = (打空数, cd前) => {
    const 场 = 新场(9);
    场.ctx.turn = 11;
    G.势力状态(场.介, 'ATX').打空 = 打空数;
    场.枪.cd = cd前;
    G.势力武器用后(场.ctx, 场.介, 场.枪, 场.枪.t);
    return {
      累计: 打空数, cd前, 余量: G.ATX余量(场.介, p), cd: 场.枪.cd,
      录: 场.ctx.log.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '余量抵冷却').length,
    };
  };
  const 余量表 = [[10, 3], [11, 3], [13, 3], [20, 3]].map(([累, cd]) => 直测(累, cd));
  console.log('    本场累计  余量  出手前 cd  出手后 cd  记录');
  for (const x of 余量表) console.log(`    ${String(x.累计).padStart(6)}  ${String(x.余量).padStart(4)}  ${String(x.cd前).padStart(8)}  ${String(x.cd).padStart(9)}  ${x.录 ? '余量抵冷却' : '—'}`);
  if (余量表[0].余量 === 0 && 余量表[0].cd === 3 && 余量表[0].录 === 0
    && 余量表[1].余量 === 1 && 余量表[1].cd === 2 && 余量表[1].录 === 1
    && 余量表[2].余量 === 3 && 余量表[2].cd === 0 && 余量表[2].录 === 1
    && 余量表[3].余量 === 10 && 余量表[3].cd === 0) {
    ok(`④ 余量抵冷却逐字照战棋：累计 10（= 起算 10，余量 0）→ cd **不动**（3 → ${余量表[0].cd}）；`
      + `累计 11（余量 1）→ 抵 1 点（3 → ${余量表[1].cd}）；累计 13（余量 3 ≥ cd 3）→ **一次性归零**（3 → ${余量表[2].cd}，`
      + `「减到 0 后每次行动都能用」）；累计 20（余量 10）也是 0`);
  } else bad(`④ 余量抵冷却不对：${JSON.stringify(余量表.map(x => [x.累计, x.余量, x.cd, x.录]))}`);
  /* ④-2 这条钩子真的接在引擎里（不是只在测试里调得到）：同样打空 13 段、同样真出手一次大招，
     关掉特色 → cd 原样 3；带着特色 → cd 被抵到 0。两边都走 `resolveAction()` 的真实出手路径
     （`spendWeapon()` 把 cd 设上之后才调 `势力武器用后` —— 和战棋 `consume(w)` 先设 cdLeft、
     再在 `strikeResolved` 上算 `evadeCdCut` 的顺序一致）。 */
  const 真出手 = (启用, 累计段) => {
    const 场 = 新场(11);
    try {
      p.启用 = 启用;
      for (let i = 0; i < 累计段; i++) 一枪(场.ctx, 场.介, 必空枪(), [0.999], 场.靶);
      场.ctx.turn = 11;
      const 摇 = 场.ctx.rng; 场.ctx.rng = () => 0;                 // 12 段里能中的都中（剩下的按命中率自然漏）
      G.resolveAction(场.介, { kind: 'attack', weapon: 场.枪.t, target: 场.靶, entry: 场.枪 }, 场.ctx);
      场.ctx.rng = 摇;
    } finally { p.启用 = true; }
    return {
      累计: G.ATX打空(场.介), 余量: G.ATX余量(场.介, p), cd: 场.枪.cd, readyTurn: 场.枪.readyTurn,
      用录: 场.ctx.log.filter(x => x.类型 === '攻击' && x.单位 === 'A1' && x.武器 === '左轮打桩机').length,
    };
  };
  const 不带 = 真出手(false, 13), 带 = 真出手(true, 13);
  info('真出手对照（同样先打空 13 段、同样真出手一次【左轮打桩机】，第 11 回合）：');
  info(`  关掉特色（启用 false）：累计 ${不带.累计}、余量 ${不带.余量}、出手后 cd **${不带.cd}**（= 数据里的 3，没人抵它）、readyTurn ${不带.readyTurn}`);
  info(`  带着特色（默认）      ：累计 ${带.累计}、余量 ${带.余量}、出手后 cd **${带.cd}**（余量 ≥ cd → 一次性归零）、readyTurn ${带.readyTurn}`);
  if (不带.cd === 3 && 不带.累计 === 0 && 带.cd === 0 && 带.累计 >= 13 && 不带.用录 === 1 && 带.用录 === 1 && 带.readyTurn === 1) {
    ok(`④ 钩子真的接在引擎里：同样一次真实出手，**不带特色 → cd ${不带.cd}、带特色 → cd ${带.cd}**`
      + `（走 \`resolveAction()\` 的 \`spendWeapon()\` 之后那一步，战棋 \`strikeResolved\` 的同一个时机）`);
  } else bad(`④ 真出手对照不对：不带 ${JSON.stringify(不带)} / 带 ${JSON.stringify(带)}`);

  /* ---- (e) 初始 CD / 每回合上限 真的生效（两个初稿常量） ---- */
  try {
    p.初始CD = 4;
    const 丙场 = 新场(5);
    const 开录 = 丙场.ctx.log.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '初始CD');
    for (let i = 0; i < 10; i++) 一枪(丙场.ctx, 丙场.介, 必空枪(), [0.999], 丙场.靶);
    info(`\`初始CD = 4\`（初稿常量）：开局 \`readyTurn\` = **${11 + 4}**（= 1 + startCd 10 + 4）；打空 10 段之后 = **${丙场.枪.readyTurn}**`
      + `（第 4 回合还不可用：${可用吗(丙场.介, 4)}；第 ${丙场.枪.readyTurn} 回合起可用：${可用吗(丙场.介, 丙场.枪.readyTurn)}）`);
    if (丙场.枪.readyTurn === 11 + 4 - 10 && !可用吗(丙场.介, 4) && 可用吗(丙场.介, 5) && 开录.length === 1 && 开录[0].初始CD === 4) {
      ok(`⑤ \`初始CD\` 真的生效：先按初稿加 4 回合（总开场冷却 14），再被 10 段打空减 10 → **第 5 回合起可用**`
        + `（默认 0 时是第 1 回合起）—— 作者原话「太强就加初始CD就行」，**一个常量就能调**`);
    } else bad(`⑤ 初始CD 没生效：readyTurn ${丙场.枪.readyTurn}、开局记录 ${开录.length} 条`);
  } finally { p.初始CD = 0; }
  try {
    p.每回合上限 = 2;
    const 丁场 = 新场(6);
    for (let i = 0; i < 5; i++) 一枪(丁场.ctx, 丁场.介, 必空枪(), [0.999], 丁场.靶);
    const 第一回合 = G.ATX打空(丁场.介), 本回合次数 = G.势力状态(丁场.介, 'ATX').本回合次数;
    丁场.ctx.turn = 2;
    for (let i = 0; i < 5; i++) 一枪(丁场.ctx, 丁场.介, 必空枪(), [0.999], 丁场.靶);
    const 第二回合后 = G.ATX打空(丁场.介);
    info(`\`每回合上限 = 2\`（初稿常量）：第 1 回合打 5 段 → 累计 **${第一回合}**（本回合次数 ${本回合次数}）；`
      + `进第 2 回合再打 5 段 → 累计 **${第二回合后}**`);
    if (第一回合 === 2 && 本回合次数 === 2 && 第二回合后 === 4) {
      ok(`⑤ \`每回合上限\` 真的生效：**每台每回合**最多记 2 段（第 1 回合打 5 段只记 2、第 2 回合再记 2）—— `
        + `这是防「一手把冷却减到 0」的旋钮；默认 0 = 不封顶（照战棋）`);
    } else bad(`⑤ 每回合上限没生效：第 1 回合 ${第一回合}（本回合次数 ${本回合次数}）、第 2 回合后 ${第二回合后}`);
  } finally { p.每回合上限 = 0; }
  if (p.初始CD === 0 && p.每回合上限 === 0) ok('⑤ 两个常量都还原成默认值 0 了（后面的段落 / 别的测试不背这个状态）');
  else bad('常量没有还原');

  /* ---- (f) 只对我方生效 ---- */
  const cF = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }, { 键: 'A2', 位: 1, 等级: 20 }],
    [{ 键: 'grunt', 位: 4, 等级: 10 }], 7);
  const 敌F = cF.enemies[0];
  敌F.tags = Object.assign({}, 敌F.tags, { 势力: 'ATX' });      // 连势力也写成 ATX
  敌F.abilities = ['gamblerSense'];                             // 连能力也挂上
  const 敌桩 = { t: { name: '敌方测试打桩机', fire: 'direct', hit: 50, dmgType: '物理', power: 10, stat: '射击', range: [1, 1], hits: 2, upgrades: [], evadeCd: true, cd: 3, unlock: 1 }, cd: 0, uses: null, readyTurn: 4 };
  敌F.weapons = 敌F.weapons.concat([敌桩]);
  G.势力开局(cF);                                                // 重新跑一次势力开局（敌人不在 `势力在场()` 里）
  const 响F = cF.allies.find(u => u.key === 'A1'), 二F = cF.allies.find(u => u.key === 'A2');
  const 敌桩前 = 敌桩.readyTurn, 敌桩cd前 = 敌桩.cd;
  一枪(cF, 响F, 必空枪(), [0.999], 敌F);                          // 我方在打敌人，这一发打空了
  const 敌状 = (敌F.势力状态 || {}).ATX || {};
  if (G.ATX打空(敌F) === 0 && 敌桩.readyTurn === 敌桩前 && 敌桩.cd === 敌桩cd前 && G.ATX减冷却(敌F, 5, p) === 0
    && G.是我方势力(敌F, 'ATX') === false && G.势力卡行(敌F) === '') {
    ok(`⑥ 只对我方生效：敌人的 \`tags.势力\` 写成了 ATX、\`abilities\` 也挂了 \`gamblerSense\`，`
      + `打空**一点没记**（累计 ${G.ATX打空(敌F)}、状态 ${JSON.stringify(敌状)}）、它的打桩机冷却没动`
      + `（readyTurn ${敌桩.readyTurn}、cd ${敌桩.cd}）、直接调 \`ATX减冷却(敌人, 5)\` = 0、卡行「${G.势力卡行(敌F)}」`);
  } else bad(`⑥ 敌人被算了：${JSON.stringify({ 累计: G.ATX打空(敌F), 状: 敌状, readyTurn: 敌桩.readyTurn, cd: 敌桩.cd, 卡行: G.势力卡行(敌F) })}`);
  if (G.ATX打空(响F) === 1 && G.ATX打空(二F) === 0 && G.势力卡行(二F) === '' && G.ATX减冷却(二F, 5, p) === 0) {
    ok(`⑥ 同一场里：响介（有 \`gamblerSense\`）照常记了 ${G.ATX打空(响F)} 段；艾克赛琳 A2（ATX 但没有这个能力）`
      + `一次都不记、冷却减不动、卡行「${G.势力卡行(二F)}」（**不手写名单**，按数据查）`);
  } else bad(`⑥ 我方判定不对：响介 ${G.ATX打空(响F)} / A2 ${G.ATX打空(二F)}`);
  /* 战棋还有一道「必中武器不会打空」：`if (c.hit || isSure(c.w)) return;`（17b:80）—— 我们靠「必中不进未中分支」实现 */
  const 必中枪 = { name: '测试·必中范围枪', fire: 'map', hit: 0, dmgType: '物理', power: 100, stat: '射击', range: [0, 9], hits: 3, upgrades: [] };
  const 前必 = G.ATX打空(响F);
  一枪(cF, 响F, 必中枪, [0.999], 敌F);
  if (G.ATX打空(响F) === 前必) ok(`⑥ 必中武器（\`fire:'map'\`，战棋的 \`isSure\`）**一段都不会打空** → 打空累计还是 ${前必}（照战棋 \`17b:80\` 的 \`isSure(c.w)\` 那一道门，我们靠「必中走不进未中分支」天然满足）`);
  else bad(`⑥ 必中武器居然记了打空：${前必} → ${G.ATX打空(响F)}`);

  /* ---- (g) 同种子两次逐字相同 + 一场真战斗的前后数字 ----
     ★ 挑的对照场是**第 4 层 Boss**（大肥鱼那一档，12 回合打满）：Lv20 的 ATX 五人打第 2 层精英是 1 回合碾压、
       一次打空都不会有 —— 要看清「按段」在真战斗里的效果，得挑一场打得久的。 */
  const 编成条12 = G.编成表.filter(x => x.层 === 4 && x.类型 === 'Boss')[0];
  const 敌队12 = G.编成到单位(编成条12, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
  const ATX队 = [{ 键: 'A1', 位: 0, 等级: 20 }, { 键: 'A2', 位: 1, 等级: 20 }, { 键: 'A3', 位: 2, 等级: 20 },
    { 键: 'A4', 位: 3, 等级: 20 }, { 键: 'A5', 位: 4, 等级: 20 }];
  const 打一场 = 种子 => G.simulate(ATX队, 敌队12, null, 种子);
  const 甲12 = 打一场(20261011), 乙12 = 打一场(20261011), 丙12 = 打一场(20261012);
  if (JSON.stringify(甲12.记录) === JSON.stringify(乙12.记录)) {
    ok(`⑦ 同种子跑一整场，${甲12.记录.length} 条记录逐字相同（打空计数 / 减冷却全走 \`ctx.rng\` 之外的状态，没有 \`Math.random\`）`);
  } else bad('⑦ 同种子两次结果不一致');
  if (JSON.stringify(丙12.记录) !== JSON.stringify(甲12.记录)) ok('⑦ 换种子结果就不一样（随机数确实在起作用）');
  else info('⑦ 换种子记录一样（这一场太碾压时可能如此，不算错）');
  const 甲打空 = 甲12.ctx.allies.filter(u => u.key === 'A1').map(u => G.ATX打空(u))[0];
  const 甲桩 = 甲12.ctx.allies.find(u => u.key === 'A1').weapons.find(e => e.t.name === '左轮打桩机');
  const 甲势力录 = 甲12.记录.filter(x => x.特色 === '赌徒的直觉');
  info(`对照场：第 4 层 Boss「${编成条12.考点}」（${敌队12.map(x => `${x.键} Lv${x.等级}`).join('、')}；`
    + `我方 ATX 五人 Lv20、不下指令、同种子 20261011）`);
  info(`这一场：${甲12.结果} · ${甲12.回合数} 回合 · 响介本场累计打空 **${甲打空}** 段（左轮打桩机 \`readyTurn\` 从 11 减到 ${甲桩.readyTurn}）`
    + ` · 〔势力〕记录 ${甲势力录.length} 条（打空 ${甲势力录.filter(x => x.结果 === '打空').length} / 余量抵冷却 ${甲势力录.filter(x => x.结果 === '余量抵冷却').length}）`);
  if (甲势力录.length) info(`例如「${甲势力录[0].文本}」`);
  if (甲打空 > 0) ok(`⑦ 一整场真战斗里「打空」真的在记（响介本场累计 ${甲打空} 段，${甲势力录.length} 条 〔势力〕 记录）—— 不是只在单测里能动`);
  else bad('⑦ 一整场打下来一次打空都没记到（按段这条没接上真战斗）');
  /* 带 vs 不带（关掉 `启用` 做对照，不改任何数值） */
  let 带12 = null, 不带12 = null;
  try {
    p.启用 = true; 带12 = 打一场(20261011);
    p.启用 = false; 不带12 = 打一场(20261011);
  } finally { p.启用 = true; }
  const 桩次数 = r => r.记录.filter(x => x.类型 === '攻击' && x.单位 === 'A1' && x.武器 === '左轮打桩机').length;
  const 打空数 = r => r.记录.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '打空').length;
  info(`带 vs 不带：打空记录 ${打空数(不带12)} 条 → ${打空数(带12)} 条；`
    + `响介用【左轮打桩机】${桩次数(不带12)} 次 → ${桩次数(带12)} 次（回合数 ${不带12.回合数} → ${带12.回合数}）`);
  if (打空数(带12) > 0 && 打空数(不带12) === 0) ok('⑦ 关掉 `启用` 时一条打空记录都不写（对照成立，别的数值一个都没改）');
  else bad(`⑦ 开关对照不对：带 ${打空数(带12)} 条 / 不带 ${打空数(不带12)} 条`);

  /* ---- (h) 战斗屏单位卡上的那一行（`80-界面.js` 的 `.faction`） ---- */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'A1', 位: 0 }, { 键: 'A2', 位: 1 }];
  界面.开战(20261011);
  const html12 = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 行数12 = (html12.match(/class="faction"/g) || []).length;
  const 卡行12 = (html12.match(/赌徒的直觉[^<]*/g) || [])[0] || '';
  if (界面.屏 === '战斗' && 行数12 === 1 && 卡行12.includes('赌徒的直觉 · 打空 0 段')) {
    ok(`(h) 战斗屏画了 ${行数12} 行势力特色（响介 A1 有；艾克赛琳 A2 没有 \`gamblerSense\` → 不多画）：`
      + `「${卡行12}」`);
  } else bad(`(h) 战斗屏的势力行不对：屏 ${界面.屏}、${行数12} 行、「${卡行12}」`);
  if (!/undefined|NaN/.test(html12)) ok('(h) 战斗屏 HTML 里没有 undefined / NaN');
  else bad('(h) 战斗屏 HTML 里出现了 undefined / NaN');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '势力特色测试全部通过');
process.exit(fails ? 1 : 0);
