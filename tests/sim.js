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
if (G.rowBlockPenalty('直射', G.ROW_BACK, true) === -20) ok('直射打后排被挡：命中 −20');
else bad('直射的「被挡」修正不对');
if (G.rowBlockPenalty('曲射', G.ROW_BACK, true) === 0) ok('曲射打后排没有惩罚');
else bad('曲射不该有被挡惩罚');
const rows = G.areaSlots({ fire: 'map', area: 'row' }, 0, 1);
const cols = G.areaSlots({ fire: 'map', area: 'col' }, 0, 1);
const cross = G.areaSlots({ fire: 'map', area: 'cross' }, 1, 1);
const all = G.areaSlots({ fire: 'map', area: 'all' }, 0, 0);
if (rows.length === 3 && cols.length === 2 && cross.length === 4 && all.length === 6) ok(`范围落点：row 3 格 / col 2 格 / cross 4 格 / all 6 格`);
else bad(`范围落点不对：row ${rows.length} / col ${cols.length} / cross ${cross.length} / all ${all.length}`);

/* ============================ [3] 固定种子可复现 ============================ */
console.log('\n[3] 固定种子跑同一场 2 次，结果必须完全一样');
const 编成 = G.选编成(1, '普通');
if (编成.length !== 3) bad(`第 1 层普通编成应该有 3 条，实际 ${编成.length} 条`);
else ok(`第 1 层普通编成：${编成.length} 条`);
const 队伍 = G.默认五人队;
const 敌 = G.编成到单位(编成[0], 0);
const 甲 = G.simulate(队伍, 敌.map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv })), null, 20261010);
const 乙 = G.simulate(队伍, 敌.map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv })), null, 20261010);
const s甲 = JSON.stringify({ 结果: 甲.结果, 回合数: 甲.回合数, 记录: 甲.记录 });
const s乙 = JSON.stringify({ 结果: 乙.结果, 回合数: 乙.回合数, 记录: 乙.记录 });
if (s甲 === s乙) ok(`同种子同结果：${甲.结果} · ${甲.回合数} 回合 · ${甲.记录.length} 条记录（两次逐字相同）`);
else bad('同一种子两次结果不一致（有随机数没走 ctx.rng？）');
const 丙 = G.simulate(队伍, 敌.map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv })), null, 20261011);
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
    const 敌军 = G.编成到单位(e, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
    const r = G.simulate(队伍, 敌军, null, 1000 + i);      // 种子固定，结果可复现
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

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '战斗内核测试全部通过');
process.exit(fails ? 1 : 0);
