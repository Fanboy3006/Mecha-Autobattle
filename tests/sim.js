#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 战斗内核测试（方案第 9 节 M1 的验收）
 * ----------------------------------------------------------------------------
 * 方案要求：
 *   1. 固定种子跑同一场 2 次，结果**完全一样**；
 *   2. 打印 Lv10 五人队对**第 1 层三种编成**各 100 场的胜率。
 * 另外顺手检查：数据有没有真的导入、公式有没有被 11-敌方梯队.js 的换算跑到、
 * 射程换算（方案 3.3）的每种 fire 是不是按表走的。
 *
 * 不依赖任何 npm 包：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来，
 * 再从 `window.__game` 里取 simulate（本机装不了 Playwright，原因见那个文件开头）。
 *
 * 用法：node tests/sim.js
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

/* ============================ 载入内核 ============================ */
const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
if (!G || typeof G.simulate !== 'function') {
  bad('window.__game.simulate 不存在');
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
console.log(`战斗内核测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/* ============================ [1] 数据导入 ============================ */
console.log('[1] 数据导入');
if (G.ALLY_T.length === 34) ok(`角色表 ALLY_T：${G.ALLY_T.length} 名（战棋现役 34 名）`);
else bad(`ALLY_T 有 ${G.ALLY_T.length} 条，预期 34`);
const enemyKeys = Object.keys(G.ENEMY_T);
ok(`敌人表 ENEMY_T：${enemyKeys.length} 种，敌人池 ${G.ENEMY_T['grunt'] ? '含 grunt' : '缺 grunt'}`);

/* 04-武器与机体.js 的加工 + 11-敌方梯队.js 的换算有没有跑到 */
const noDef = G.ALLY_T.filter(t => t.defense == null || t.awaken == null);
if (noDef.length) bad(`有 ${noDef.length} 名角色没有 defense / awaken（11-敌方梯队.js 的换算没跑到？）`);
else ok('每个角色都补上了 defense / awaken（换算流水线跑过了）');
const v37 = G.ALLY_T.filter(t => t.weapons.every(w => w.v37));
if (v37.length === G.ALLY_T.length) ok('全部角色的武器都标了 v37（威力已经是新公式的值）');
else info(`还有 ${G.ALLY_T.length - v37.length} 名角色的武器没走换算（NEW_FORMULA 里按新公式手写的，正常）`);
const badW = G.ALLY_T.flatMap(t => t.weapons
  .filter(w => G.rangeKindOf(w) && G.rangeKindOf(w) !== '修理' && G.weaponPlayable(w) && !(w.power > 0) && w.dmgType !== '—')
  .map(w => `${t.mech}/${w.name}`));
if (badW.length) bad(`有 ${badW.length} 把第一期可用的伤害武器威力 ≤ 0：${badW.slice(0, 6).join('、')}`);
else ok('第一期可用的伤害武器都有正的威力（带 special 的特殊武器、支援类、dmgType 为「—」的不算）');

/* ============================ [2] 射程换算（方案 3.3） ============================ */
console.log('\n[2] 射程换算：能打到哪一排');
const cases = [
  ['melee', '近战'], ['direct', '直射'], ['indirect', '曲射'], ['map', '范围'], ['support', '范围'],
  ['heal', '修理'], ['passive', null], ['device', null],
];
for (const [fire, want] of cases) {
  const got = G.rangeKindOf({ fire });
  if (got === want) ok(`fire=${fire} → ${got === null ? '第一期不做' : got}`);
  else bad(`fire=${fire} 应该 → ${want}，实际 → ${got}`);
}
if (G.rowReachable('近战', G.ROW_BACK, true) === false) ok('近战打不到后排（前排还有人）');
else bad('近战居然能越过前排打后排');
if (G.rowReachable('近战', G.ROW_BACK, false) === true) ok('前排全灭后近战可以打后排');
else bad('前排全灭后近战仍打不到后排');
/* 被挡：作者 2026-10-10 拍板改成**按位**（★ 2026-10-13 正交 4×2 之后：后1..后4 = 位 4..7，
   后N **只被同路的前N 挡**（1 对 1）—— `遮挡位(5)` = `[1]`，不再是旧 9 格的「前1+前2」；
   参数 = `rowBlockPenalty(类型, 目标位, 那一方还活着的位, 攻击者)`）。 */
if (G.rowBlockPenalty('直射', 5, [1], null) === -20) ok('直射打后2、它唯一的阻挡位（同路 前2）有人 → 命中 −20（打得到，不是打不到）');
else bad('直射的「被挡」修正不对');
if (G.rowBlockPenalty('直射', 5, [], null) === 0) ok('同一个后2 的阻挡位全灭 → 无惩罚');
else bad('阻挡位全灭后还有惩罚');
if (G.rowBlockPenalty('直射', 0, [0], null) === 0) ok('直射打前排永远不被自己挡');
else bad('打前排不该有被挡惩罚');
if (G.rowBlockPenalty('曲射', 5, [1], null) === 0) ok('曲射打后排没有惩罚（无视阻挡）');
else bad('曲射不该有被挡惩罚');
const rows = G.areaSlots({ fire: 'map', area: 'row' }, 0, 1);
const cols = G.areaSlots({ fire: 'map', area: 'col' }, 0, 1);
const cross = G.areaSlots({ fire: 'map', area: 'cross' }, 1, 1);
const all = G.areaSlots({ fire: 'map', area: 'all' }, 0, 0);
/* ★ 2026-10-13 正交 4×2：`row` = 一整排（恒 4 格）/ `col` = 该路纵列两格 `[c, c+4]`（恒 2 格，
   旧 9 格里 后3 会被 前2+前3 同时挡、`col` 有 3 格）/ `cross` = 正交十字（同排左右 + 同路对侧 = 4 格）/
   `all` = 全部 8 格。 */
if (rows.length === 4 && cols.length === 2 && cross.length === 4 && all.length === 8) ok(`范围落点：row 4 格 / col 2 格（阻挡束 = 同路纵列 前2+后2）/ cross 4 格 / all 8 格`);
else bad(`范围落点不对：row ${rows.length} / col ${cols.length} / cross ${cross.length} / all ${all.length}`);

/* ============================ [3] 固定种子可复现 ============================ */
console.log('\n[3] 固定种子跑同一场 2 次，结果必须完全一样');
const 编成 = G.选编成(1, '普通');
/* ★ 2026-10-13（关卡变体池）：**旧 → 新 → 为什么** ——
   旧：第 1 层普通**恒 3 条**（作者 2026-10-10「每种类型每层先 3 条」）。
   新：**7 条**（原案的 `1-N1`…`1-N7` 七个普通变体，作者 2026-10-13 拍板「扩池、不加节点」）。
   为什么：池子从 3 条扩到 7 条是这一版的**目的本身**（反复开局不重样）；`tests/comp.js` 第 [1][8] 段
   把「每层每类型该有几条」钉成定额，这里只跟着报一条。 */
if (编成.length !== 7) bad(`第 1 层普通编成应该有 7 条（原案 1-N1…1-N7），实际 ${编成.length} 条`);
else ok(`第 1 层普通编成：${编成.length} 条（1-N1…1-N7）`);
const 队伍 = G.默认五人队;
const 敌 = G.编成到单位(编成[0], 0);
const 波次 = G.编成波次到单位(编成[0], 0);      // 敌方增援波次（作者 2026-10-10：被击坠后可以增援）
const 甲 = G.simulate(队伍, G.敌方规格组(敌), null, 20261010, { 波次 });
const 乙 = G.simulate(队伍, G.敌方规格组(敌), null, 20261010, { 波次 });
const s甲 = JSON.stringify({ 结果: 甲.结果, 回合数: 甲.回合数, 记录: 甲.记录 });
const s乙 = JSON.stringify({ 结果: 乙.结果, 回合数: 乙.回合数, 记录: 乙.记录 });
if (s甲 === s乙) ok(`同种子同结果：${甲.结果} · ${甲.回合数} 回合 · ${甲.记录.length} 条记录（两次逐字相同）`);
else bad('同一种子两次结果不一致（有随机数没走 ctx.rng？）');
const 丙 = G.simulate(队伍, G.敌方规格组(敌), null, 20261011);
if (JSON.stringify(丙.记录) !== s甲) ok('换个种子结果就不一样（随机数确实在起作用）');
else info('换种子结果一样（可能这一场太碾压，不算错）');

/* 记录本身要自洽 */
const 记录 = 甲.记录;
if (记录.length && 记录.every(r => r.回合 >= 1 && typeof r.文本 === 'string')) ok('每条记录都有回合号和文本');
else bad('有记录缺回合号 / 文本');
const 血崩 = 甲.我方.concat(甲.敌方).some(u => u.hp < 0 || u.hp > u.maxHp);
if (!血崩) ok('战斗结束时没有 HP 越界（<0 或 > 上限）');
else bad('有单位 HP 越界');

/* ============================ [4] 100 场胜率 ============================ */
console.log('\n[4] Lv10 五人队 vs 第 1 层三种编成，各 100 场');
console.log(`    我方：${队伍.map(s => { const t = G.ALLY_T.find(a => a.mech === s.键); return `${t.pilot}(${s.键}/${t.tags.战斗分类})`; }).join('、')}`);
console.log('');
console.log('    编成                                      平均回合   胜   败   胜率');
console.log('    ----------------------------------------------------------------');
const N = 100;
const 统计 = [];
for (const e of 编成) {
  let 胜 = 0, 回合和 = 0, 败因 = {};
  for (let i = 0; i < N; i++) {
    const 敌军 = G.敌方规格组(G.编成到单位(e, 0));
    const r = G.simulate(队伍, 敌军, null, 1000 + i, { 波次: G.编成波次到单位(e, 0) });   // 种子固定，结果可复现
    if (r.结果 === '胜') 胜++;
    else 败因[r.原因] = (败因[r.原因] || 0) + 1;
    回合和 += r.回合数;
  }
  const 名 = `前${e.前.join('+')} / 后${e.后.join('+')}`;
  统计.push({ 名, 胜率: 胜 / N, 平均回合: 回合和 / N, 败因 });
  console.log(`    ${名.padEnd(42)} ${(回合和 / N).toFixed(1).padStart(6)}  ${String(胜).padStart(3)}  ${String(N - 胜).padStart(3)}  ${String(Math.round(胜 / N * 100)).padStart(3)}%`);
}
console.log('');
for (const s of 统计) {
  const 因 = Object.entries(s.败因).map(([k, v]) => `${k}×${v}`).join('，');
  info(`${s.名}：胜率 ${Math.round(s.胜率 * 100)}%${因 ? `，败因：${因}` : ''}`);
}

/* ============================ [5] 一场样例 ============================ */
console.log('\n[5] 样例战斗（种子 20261010，前 14 条 + 结尾）');
const 样例 = 甲.记录;
const 显示 = 样例.length <= 18 ? 样例 : 样例.slice(0, 14).concat([{ 文本: `…… 中间省略 ${样例.length - 18} 条 ……` }], 样例.slice(-4));
for (const r of 显示) console.log(`    [${String(r.回合).padStart(2)}] ${r.文本}`);
console.log('');
console.log(`    双方存活：我方 ${甲.我方.filter(u => u.hp > 0).length}/${甲.我方.length}，敌方 ${甲.敌方.filter(u => u.hp > 0).length}/${甲.敌方.length}`);

/* ============================ [6] 公式对照（给 Claude 复审用，方案第 11 节） ============================ */
console.log('\n[6] 公式对照：Lv10 我方主武器 打 Lv2 量产机（战棋注释里的参照点）');
const 量产机 = G.makeUnit('grunt', 'enemy', 0, 2);
console.log(`    参照目标：量产机 Lv2 · 装甲 ${量产机.armor} · 防御 ${量产机.defense} · HP ${量产机.maxHp}`);
console.log('    战棋 v0.40.4 注释的参照点：普通武器 Lv10 打 Lv2 量产机——精锐约 6000、骨干约 4500');
console.log('');
for (const 键 of ['B1', 'B2', 'CB2', 'CB4', 'M1']) {
  const t = G.ALLY_T.find(a => a.mech === 键);
  const a = G.makeUnit(键, 'ally', 0, 10);
  for (const e of a.weapons) {
    const w = e.t;
    const kind = G.rangeKindOf(w);
    if (!kind || kind === '修理' || !G.weaponPlayable(w) || !(w.power > 0)) continue;
    const d = G.dmgCore(a, w, 量产机, { power: G.wv(a, w, 'power'), preview: true, turn: 1 });
    const h = G.hitRate(a, w, 量产机, {});
    console.log(`    ${`${t.pilot}(${键})`.padEnd(14)} ${w.name.padEnd(14)} 档位 ${G.tierOf(键)} · 伤害 ${String(d.dmg).padStart(5)} · 命中 ${h.hit}%${w.hits ? ` × ${w.hits} 段` : ''}`);
  }
}

/* ============================ [7] 支援与大招（Feena 的三条，作者 2026-10-10 定） ============================ */
console.log('\n[7] Feena：月光祝福（增益）/ 残月的余响 / 再动');
/* ★ 2026-10-13（`[特色与角色] Feena 主动攻击补强`）**旧 → 新 → 为什么**：
   旧：这一段在**默认开关**下跑 —— 那时 Feena 没有任何主动攻击武器（「残月的余响」是 `fire:'passive'`
       + `unlock:20`），所以 `aiAction()` 的「进攻」那一档永远挑不出东西，她的行动必然是
       「月光祝福 → 再动 → 防御」，下面 7a / 7b / 7e 的三条断言（第 1 回合放月光祝福、
       跳过开场冷却后放得出再动、第 4 回合之前没有大招）钉的正是那套行为。
   新：`战斗结构.Feena主动攻击.开` **默认 true** → 她**自己回合会主动开「残月的余响」**（曲射、Lv10 解锁），
       `aiAction()` 的「修理 → **进攻** → 支援」顺序意味着进攻一旦可选就**不再放月光祝福 / 再动** →
       那三条断言会把「她现在会主动打了」误判成失败。
   为什么这么改：**这一段的主题是「支援与大招子系统」（月光祝福 / 再动 / 开场冷却）本身**，
       与「她能不能主动打」是两件事；用**关掉新开关**的口径跑它，恰好就是**改动前那一份行为**
       （`开 === false` 铁律：逐字节退回改前）—— 断言一句不用放宽，而且顺带把「关掉开关 = 改前」
       这条铁律钉在这一段上。**她主动攻击的新行为由 `tests/faction-2-流星小队与月球王国.js`
       的 P0 专项段从正面钉**（Lv10 单挑真的造成伤害 / 队友造成伤害后触发追加 / 同种子两遍一致）。
   测完**恢复默认**（`开 = true`），后面的段落照默认口径跑。 */
const 主动攻击开关 = G.战斗结构.Feena主动攻击.开;
G.战斗结构.Feena主动攻击.开 = false;
const 队伍20 = [
  { 键: 'B2', 位: 0, 等级: 20 },   // 尖兵，速度最高，会抢在 Feena 之前行动 → 有「再动」目标
  { 键: 'B1', 位: 1, 等级: 20 },
  { 键: 'CB2', 位: 3, 等级: 20 },
  { 键: 'CB4', 位: 4, 等级: 20 },
  { 键: 'M1', 位: 4, 等级: 20 },   // Feena（指挥）
];
const 敌军20 = [
  { 键: 'grunt', 位: 0, 等级: 5 }, { 键: 'shield', 位: 1, 等级: 5 },
  { 键: 'drone', 位: 3, 等级: 5 }, { 键: 'sniper', 位: 4, 等级: 5 },
];

/* ---- 7a. 不跳过开场冷却：第 1 回合「再动」还不能用，她只能放月光祝福 ----
 * 这里换一支硬一点的敌人（6 台 Lv20），保证第 1 回合打不完 —— 不然回合结束时不会走 endTurn，
 * 「增益到本回合结束就消失」就试不出来。 */
const 敌军久 = [
  { 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'grunt', 位: 1, 等级: 20 }, { 键: 'shield', 位: 2, 等级: 20 },
  { 键: 'drone', 位: 3, 等级: 20 }, { 键: 'sniper', 位: 4, 等级: 20 },
];
const ctxB = G.开局(队伍20, 敌军久, 20261010);
const 甲B = ctxB.allies;
G.打一回合(ctxB);
const 增益B = ctxB.log.filter(x => x.类型 === '增益');
const 再动B = ctxB.log.filter(x => x.类型 === '再动');
if (增益B.length) {
  ok(`月光祝福放了 ${增益B.length} 次：${增益B[0].文本}`);
  if (增益B.every(x => Array.isArray(x.目标) && !x.目标.includes('M1'))) ok('目标是全体队友且不含自己');
  else bad('月光祝福的目标里出现了自己');
  /* 增益真的进了命中公式：手动挂一样的增益，命中率立刻变化（公式层面的证据） */
  const 甲 = ctxB.allies.find(u => u.hp > 0), 乙 = ctxB.enemies.find(u => u.hp > 0);
  const e = 甲 && 甲.weapons.find(x => { const k = G.rangeKindOf(x.t); return k && k !== '修理' && k !== '支援'; });
  if (甲 && 乙 && e) {
    const 基 = G.hitRate(甲, e.t, 乙, { baseHit: 50 }).hit;
    乙.buffs.push({ src: '测试', eva: 15 });
    const 闪 = G.hitRate(甲, e.t, 乙, { baseHit: 50 }).hit;
    乙.buffs = 乙.buffs.filter(b => b.src !== '测试');
    甲.buffs.push({ src: '测试', hit: 15 });
    const 中 = G.hitRate(甲, e.t, 乙, { baseHit: 50 }).hit;
    甲.buffs = 甲.buffs.filter(b => b.src !== '测试');
    if (闪 === Math.max(0, 基 - 15) && 中 === Math.min(100, 基 + 15)) ok(`增益真的进了命中公式：给目标闪避 +15 → 命中 ${基}%→${闪}%；给自己命中 +15 → ${基}%→${中}%`);
    else bad(`增益没进命中公式：基线 ${基}% / 加闪避 ${闪}% / 加命中 ${中}%`);
  }
  const 有buff = 甲B.find(u => u.key === 'B2');
  if (!(有buff.buffs || []).some(x => x.src === '月光祝福')) ok('回合结束后增益消失（「持续到本回合结束」生效）');
  else bad('回合结束后增益还在');
} else bad('Feena 第 1 回合没放月光祝福（支援类武器没进 AI 的可用列表？）');
if (!再动B.length) ok('第 1 回合没有「再动」（开场冷却 3 回合，第 4 回合才可用）');
else bad('第 1 回合就放出了「再动」，开场冷却没生效');

/* ---- 7b. 跳过「再动」的开场冷却，专门验它的效果 ---- */
const 甲C = G.makeUnits(队伍20, 'ally'), 乙C = G.makeUnits(敌军20, 'enemy');
const ctxC = G.开局(队伍20, 敌军20, 20261010);
for (const u of ctxC.allies) for (const e of u.weapons) if (e.t.grant) e.readyTurn = 1;   // 只改这一条，其他照规则
let 护栏 = 0;
while (!ctxC.result && 护栏++ < 14) G.打一回合(ctxC);
const 录C = ctxC.log;
const 再动C = 录C.filter(x => x.类型 === '再动');
const 余响 = 录C.filter(x => x.类型 === '残月余响');
console.log(`    跳过开场冷却那一场打了 ${ctxC.turn} 回合：再动 ${再动C.length} 次、残月的余响 ${余响.length} 次`);
if (再动C.length) {
  const e0 = 再动C[0];
  const 该回合该单位 = 录C.filter(x => x.回合 === e0.回合 && x.单位 === e0.目标 && ['攻击', '修理', '增益'].includes(x.类型));
  if (该回合该单位.length >= 2) ok(`再动生效：${e0.目标} 在第 ${e0.回合} 回合行动了 ${该回合该单位.length} 次（${e0.文本}）`);
  else bad(`再动没生效：${e0.目标} 在第 ${e0.回合} 回合只行动了 ${该回合该单位.length} 次`);
  const 重复 = 再动C.filter(x => 再动C.filter(y => y.回合 === x.回合 && y.目标 === x.目标).length > 1);
  if (!重复.length) ok('同一名队友一回合最多被再动一次（不会无限连锁）');
  else bad(`有队友一回合被再动多次：${重复.map(x => `${x.回合}/${x.目标}`).join('、')}`);
} else bad('跳过开场冷却后「再动」还是没放出来');

/* ---- 7c. 残月的余响（★ 作者 2026-10-11 **换机制**）：不再是范围伤害，改成「队友攻击后追加一发」 ----
 * 原来的断言盯的是「行动结束后自动放、只打敌方前排」；作者把这条大招改成了
 * 「队友攻击时追加一次攻击」（`协作/势力特色落地决定.md` 第 3 条）→ 这里**跟着改成新机制的断言**，
 * 不是删掉断言。旧机制「一次都不走」单独在下面钉一条。 */
const 打一场换机制 = () => {
  const ctx = G.开局([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'B2', 位: 1, 等级: 20 }, { 键: 'CB2', 位: 2, 等级: 20 }],
    [{ 键: 'bluefish', 位: 0, 等级: 1 }], 20261011);
  const 靶 = ctx.enemies[0];
  靶.hp = 靶.maxHp = 9999999;         // 打不死的靶子：队友每一击都不会把人打死 → 追加条件稳定成立
  ctx.rng = () => 0;                  // 必中（引擎的随机数入口就是 ctx.rng）
  return ctx;
};
const ctxR = 打一场换机制();
const 录R1 = G.打一回合(ctxR);
const 追1 = 录R1.filter(x => x.类型 === '残月余响');
const 攻击1 = 录R1.filter(x => x.类型 === '攻击' && x.单位方 === 'ally');
if (追1.length === 1) ok(`队友攻击后真的追加了一发（第 1 回合：我方出手 ${攻击1.length} 次 → 追加 ${追1.length} 次）：${追1[0].文本}`);
else bad(`追加次数不对：我方出手 ${攻击1.length} 次 → 追加 ${追1.length} 次（预期 1）`);
if (追1.length && 追1[0].单位 === 'M1' && 追1[0].队友 && 追1[0].队友 !== 'M1') ok(`是 Feena（${追1[0].单位}）放的，记录里写着是哪个队友触发的（队友 ${追1[0].队友}）、武器【${追1[0].武器}】、目标 ${追1[0].目标}`);
else bad(`追加记录的字段不对：${JSON.stringify(追1[0])}`);
if (追1.length && 追1[0].每回合上限 === 1 && 追1[0].本回合第几次 === 1) ok(`★ 每回合上限是常量 1（记录里带 \`每回合上限: ${追1[0].每回合上限}\`、\`本回合第几次: ${追1[0].本回合第几次}\`）—— 第 1 回合我方出手 ${攻击1.length} 次也只追加 1 次`);
else bad(`每回合上限字段不对：${JSON.stringify(追1[0])}`);
const 录R2 = G.打一回合(ctxR);
const 追2 = 录R2.filter(x => x.类型 === '残月余响');
if (追2.length === 1 && 追2[0].本回合第几次 === 1) ok(`下一回合重新开一次上限（第 2 回合照样追加 1 次、\`本回合第几次\` 回到 1）`);
else bad(`第 2 回合的追加不对：${追2.length} 次（${JSON.stringify(追2.map(x => x.本回合第几次))}）`);
/* 旧的「行动结束后自动放、范围 = 敌方前排」那条路径**一次都不该走** */
const ctx旧 = G.开局([{ 键: 'M1', 位: 4, 等级: 20 }], 敌军久, 5);
const 旧前 = ctx旧.log.length;
for (const u of ctx旧.allies) G.runAutoCast(u, ctx旧);
if (ctx旧.log.length === 旧前) ok('旧的「行动结束后自动放、范围 = 敌方前排」那条路径已经不走（`runAutoCast()` 一条记录都不写）');
else bad(`旧的余响路径还在跑：${ctx旧.log.slice(旧前).map(x => x.文本).join('｜')}`);
const M1模板 = G.ALLY_T.find(t => t.mech === 'M1');
if (M1模板 && !M1模板.weapons.some(w => w.special === 'echo') && M1模板.weapons.some(w => w.special === G.残月余响标记)) {
  ok(`武器上的标记已经从 \`echo\` 换成 \`${G.残月余响标记}\`（\`runAutoCast()\` 只认 \`echo\` → 认不出它了），数值 / 必中 / 物理一个字没改`);
} else bad(`残月的余响的 special 标记不对：${JSON.stringify((M1模板 || {}).weapons.map(w => [w.name, w.special]))}`);

/* ---- 7d. Lv30 的「满月·月蚀」：数据里写明「冷却好时代替残月的余响」，换机制后这条仍然成立 ---- */
const ctx30 = G.开局([{ 键: 'M1', 位: 0, 等级: 30 }, { 键: 'B2', 位: 1, 等级: 30 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 5);
const 菲娜30 = ctx30.allies.find(u => u.key === 'M1');
const 靶30 = ctx30.enemies[0];
靶30.hp = 靶30.maxHp = 9999999;
for (const e of 菲娜30.weapons) e.readyTurn = 1;    // 直接跳过大招开场冷却（这里只验「用哪一把」）
ctx30.rng = () => 0;
const 枪手 = ctx30.allies.find(u => u.key === 'B2');
const 用30 = G.usableWeapons(枪手, ctx30).find(e => !['支援', '修理'].includes(G.rangeKindOf(e.t)));
if (用30) {
  G.resolveAction(枪手, { kind: 'attack', weapon: 用30.t, target: 靶30, entry: 用30 }, ctx30);
  const 名30 = [...new Set(ctx30.log.filter(x => x.类型 === '残月余响').map(x => x.武器))];
  if (名30.length === 1 && 名30[0] === '满月·月蚀') ok(`Lv30 冷却好时用【满月·月蚀】代替残月的余响（一回合还是只放一把）：${名30.join('、')}`);
  else bad(`Lv30 的追加武器不对：${名30.join('、') || '（没有追加）'}`);
} else bad('B2（Lv30）没有可用武器（7d 段没跑起来）');

/* ---- 7e. 开场冷却：大招（unlock ≥ 20）在第 4 回合之前不能用 ---- */
const 大招名 = G.ALLY_T.flatMap(t => t.weapons.filter(w => w.unlock >= 20 && G.rangeKindOf(w) && w.power > 0).map(w => w.name));
const 早放 = 录C.filter(x => x.类型 === '攻击' && 大招名.includes(x.武器) && x.回合 < 4);
if (早放.length) bad(`有 ${早放.length} 次大招在第 4 回合之前就放了（开场冷却 3 回合没生效）：${早放.map(x => `第${x.回合}回合 ${x.武器}`).join('、')}`);
else ok('开场冷却生效：第 4 回合之前没有出现大招');
/* ★ 恢复默认（`开 === false` 只是 [7] 这一段的验证口径，见段首那段说明） */
G.战斗结构.Feena主动攻击.开 = 主动攻击开关;
if (G.战斗结构.Feena主动攻击.开 === true) ok('（[7] 段把 `战斗结构.Feena主动攻击.开` 恢复成默认 true —— 那一段用的是「关掉 = 改前」口径）');
else bad('（[7] 段跑完没有把 `战斗结构.Feena主动攻击.开` 恢复成默认 true）');

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '战斗内核测试全部通过');
process.exit(fails ? 1 : 0);
