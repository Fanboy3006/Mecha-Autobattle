#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · **战术卡牌系统 P1** 独立测试套件
 * ----------------------------------------------------------------------------
 * 覆盖 `协作/派单/当前任务.md` §2.2 的 6 大段：
 *   [1] 表结构与三层牌池完整性（32 张 = 职业 12 + 势力 12 + 角色与统帅 8，0 rng）
 *   [2] 初始可用牌 vs 条件触发发牌闭环（根性 / 幻影反击 / 赌徒孤注 / 精密锁敌 / SEED·爆种）
 *   [3] 气力资源轮转（0 费回气 → 中高费爆发，伤害/命中/暴击/护盾真实进公式）
 *   [4] 肉鸽招募/晋升 3 选 1 获牌与带入战斗（候选战术牌们 + 选战术牌 + RUN.战术牌库）
 *   [5] 战斗手牌栏 UI 与三层反馈（.tactical-hand-bar / disabled / .is-triggered / 打战术牌:<id> / 战报统计）
 *   [6] 默认关闭零污染红线（开 === false 时零发牌、零 rng 消耗、日志逐字不变）
 * ★ 2026-10-13 **P1.2 追加两段**（`协作/派单/当前任务.md` §1）：
 *   [8] **开牌路径确定性基线报数**（§1.6：固定种子 20261015 + 默认五人队 + 固定脚本出牌 → 两遍逐字节一致）
 *   [9] P1.2 七条架构红线（§1.1 气势统一 25 / §1.2 当场写发牌日志 / §1.3 零 `ctx.log` 反向依赖 /
 *       §1.4 内核不读全局 `RUN` / §1.5 统帅牌转标准条件牌 · 不在手牌打不出 / §1.8 决策族接线）
 *   [10] P1.2 §1.1 **录像顶层 `战术卡牌` 字段契约**（新录像写 / 旧录像不补 / 重放只认这一个判据）
 *       + §1.5 **打牌与手动开 TRANS-AM 后立即复查条件发牌**（含「靠卡牌效果才成立」的衍生牌当场入牌）
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';
import { 读源码 } from './lib/读源码.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
/** 读源码片段（P1 源码机械拆分后走 `读源码()`）。 */
const 源码 = (...段) => 读源码(ROOT, 'src', 'js', ...段);
/** 去掉注释，便于「源码里不该出现某句」这类断言不被注释误伤。 */
const 去注释 = s => String(s).replace(/\/\*[\s\S]*?\*\//g, '').replace(/^[ \t]*\/\/.*$/gm, '');

let passes = 0;
let fails = 0;
const errs = [];
const ok = m => { passes++; console.log('  ✓ ' + m); };
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const assert = (cond, msg) => (cond ? ok(msg) : bad(msg));

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  process.exit(1);
}
const G = page.sandbox.__game;
const doc = page.sandbox.document;

console.log(`战术卡牌系统 P1 测试: 机甲指挥 ${G.version} · ${G.milestone}\n`);

/* ================= [1] 表结构与三层牌池完整性 ================= */
console.log('[1] 表结构与三层牌池完整性（32 张 · 0 rng）');
{
  const 表 = G.战术卡牌表;
  assert(Array.isArray(表) && 表.length === 32, `战术卡牌表共 32 张（实得 ${表 && 表.length}）`);
  const 职业牌 = 表.filter(c => c.层级 === '职业');
  const 势力牌 = 表.filter(c => c.层级 === '势力');
  const 角色统帅牌 = 表.filter(c => c.层级 === '角色' || c.层级 === '统帅');
  assert(职业牌.length === 12, `职业池 12 张（6 职业 × 2，实得 ${职业牌.length}）`);
  assert(势力牌.length === 12, `势力池 12 张（6 势力 × 2，实得 ${势力牌.length}）`);
  assert(角色统帅牌.length === 8, `角色与统帅池 8 张（6 角色 + 2 统帅，实得 ${角色统帅牌.length}）`);

  /* ★ P1.2 §1.5：两张统帅牌改成**标准条件触发牌**（入牌 = 条件、触发条件码 = MORALE_75、耗气 100）。 */
  const 统帅牌 = 表.filter(c => c.层级 === '统帅');
  assert(统帅牌.length === 2 && 统帅牌.every(c => c.入牌 === '条件' && c.触发条件码 === 'MORALE_75'
    && c.耗气 === 100 && c.回气 === 0 && c.触发说明 === '我方气势达到 75 或以上'),
    `两张统帅牌都是标准条件触发牌（入牌 条件 / MORALE_75 / 耗气 100 / 回气 0）：${统帅牌.map(c => c.名).join('、')}`);
  assert(表.filter(c => c.入牌 === '初始').length === 16 && 表.filter(c => c.入牌 === '条件').length === 16,
    `入牌方式分布：初始 16 张 / 条件 16 张（两张统帅牌从初始挪到条件，初始手牌槽不再被它们挤占；实得 `
    + `${表.filter(c => c.入牌 === '初始').length} / ${表.filter(c => c.入牌 === '条件').length}）`);

  const 缺字段 = 表.filter(c => !c.id || !c.名 || !c.层级 || !c.归属 || !c.入牌 || c.耗气 == null || c.限次 == null || !c.效果说明);
  assert(缺字段.length === 0, `32 张牌全部具备 id / 名 / 层级 / 归属 / 入牌 / 耗气 / 限次 / 效果说明`);

  // 验证生成队伍牌池准确筛选且 0 rng 消耗
  const 阵容 = [
    { 键: 'CB1', 位: 0, 等级: 20 }, // 近卫 · 天人 · CB1
    { 键: 'CB2', 位: 4, 等级: 20 }, // 狙击 · 天人 · CB2
    { 键: 'M1', 位: 5, 等级: 20 },  // 指挥 · 月球王国 · M1
  ];
  const 池 = G.生成队伍牌池(阵容);
  assert(池.职业牌池.some(c => c.id === 'C_GUARD_1') && 池.职业牌池.some(c => c.id === 'C_SNIPE_1') && 池.职业牌池.some(c => c.id === 'C_CMD_1'),
    '生成队伍牌池准确筛出参战职业牌（近卫/狙击/指挥）');
  assert(!池.职业牌池.some(c => c.归属 === '重装'), '未参战职业（重装）不会混入队伍牌池');
  assert(池.势力牌池.some(c => c.id === 'F_CB_1') && 池.势力牌池.some(c => c.id === 'F_MOON_1'),
    '生成队伍牌池准确筛出参战势力牌（天人/月球王国）');
  assert(池.角色牌池.some(c => c.id === 'U_CB1') && 池.角色牌池.some(c => c.id === 'U_CB2') && 池.角色牌池.some(c => c.id === 'U_M1'),
    '生成队伍牌池准确筛出参战王牌角色专属牌（CB1/CB2/M1）');
}

/* ================= [2] 初始可用牌 vs 条件触发发牌闭环 ================= */
console.log('\n[2] 初始可用牌 vs 条件触发发牌闭环');
{
  const 我方 = [
    { 键: 'CB4', 位: 0, 等级: 20 }, // 重装 · 天人
    { 键: 'B2', 位: 1, 等级: 20 },  // 尖兵 · 影世界
    { 键: 'A2', 位: 2, 等级: 20 },  // 狙击 · ATX
    { 键: 'CB2', 位: 4, 等级: 20 }, // 狙击 · 天人
    { 键: 'S1', 位: 5, 等级: 20 },  // 指挥 · 卫星国防军
  ];
  const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const ctx = G.开局(我方, 敌方, 20261013, null, { 战术卡牌: true });

  assert(Array.isArray(ctx.战术手牌) && ctx.战术手牌.length > 0 && ctx.战术手牌.every(c => c.入牌 === '初始'),
    `开局初始牌直接进入 ctx.战术手牌（共 ${ctx.战术手牌.length} 张，全部为初始牌）`);
  assert(Array.isArray(ctx.待触发战术牌) && ctx.待触发战术牌.length > 0 && ctx.待触发战术牌.every(c => c.入牌 === '条件'),
    `开局条件牌进入 ctx.待触发战术牌（共 ${ctx.待触发战术牌.length} 张，全部为条件牌）`);

  // ① 重装受击残血（<65%）→ 触发【根性】(C_HEAVY_2)
  const 重装 = ctx.allies.find(u => u.key === 'CB4');
  重装.hp = Math.floor(重装.maxHp * 0.5);
  const 发1 = G.检查条件发牌(ctx, '受击', { 目标: 重装 });
  assert(发1.some(c => c.id === 'C_HEAVY_2') && ctx.战术手牌.some(c => c.id === 'C_HEAVY_2' && c.新触发),
    '重装残血(<65%)确定性触发【根性】(C_HEAVY_2)进入手牌并挂 新触发: true');

  // ② 场上打空 2 次 → 触发【幻影反击】(C_VANG_2) 与【赌徒孤注】(F_ATX_2)
  ctx.战术手牌 = ctx.战术手牌.slice(0, 4);
  /* ★ P1.2 §1.3：条件触发的真源换成 `ctx.战况计数.未命中段`（`60-战斗-2` 在真实事件位置当场累加）。 */
  ctx.战况计数.未命中段 = 2;
  const 发2 = G.检查条件发牌(ctx, '攻击后', { 未命中段数: 2 });
  assert(发2.some(c => c.id === 'C_VANG_2') && 发2.some(c => c.id === 'F_ATX_2'),
    '打空累计 ≥2 次确定性触发【幻影反击】(C_VANG_2) 与【赌徒孤注】(F_ATX_2)');

  // ③ 敌机挂满 2 层标定 → 触发【精密锁敌】(C_SNIPE_2)
  // 先腾出手牌空间以防触顶
  ctx.战术手牌 = ctx.战术手牌.slice(0, 4);
  const 靶 = ctx.enemies[0];
  const 条 = G.标定经济拿条(靶);
  条.层数 = 2;
  const 发3 = G.检查条件发牌(ctx, '标定', { 目标: 靶, 层数: 2 });
  assert(发3.some(c => c.id === 'C_SNIPE_2'),
    '敌机带有 ≥2 层标定确定性触发【精密锁敌】(C_SNIPE_2)');

  // ④ SEED 累计满 30 → 触发【SEED·爆种】(F_SEED_2)
  const 拉克丝 = ctx.allies.find(u => u.key === 'S1');
  G.势力状态(拉克丝, '卫星国防军').累计 = 30;
  const 发4 = G.检查条件发牌(ctx, '回合结束', { SEED累计: 30 });
  assert(发4.some(c => c.id === 'F_SEED_2'),
    '我方单位 SEED 累计 ≥30 确定性触发【SEED·爆种】(F_SEED_2)');

  const 发牌日志 = ctx.log.filter(r => r.类型 === '发牌');
  assert(发牌日志.length >= 5 && 发牌日志.every(r => r.文本.startsWith('〔发牌〕')),
    `每次条件触发均写入〔发牌〕日志（共 ${发牌日志.length} 条）`);
}

/* ================= [3] 气力资源轮转（0 费回气 → 中高费爆发） ================= */
console.log('\n[3] 气力资源轮转（0 费回气 → 中高费爆发）与公式结算验证');
{
  const 我方 = [
    { 键: 'CB4', 位: 0, 等级: 20 }, // 重装
    { 键: 'B1', 位: 1, 等级: 20 },  // 近卫
    { 键: 'CB2', 位: 4, 等级: 20 }, // 狙击
    { 键: 'M1', 位: 5, 等级: 20 },  // 指挥
  ];
  const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const ctx = G.开局(我方, 敌方, 20261013, null, { 战术卡牌: true });

  assert(ctx.气势 === 25, `开启战术卡牌时开场默认气力为 25（实得 ${ctx.气势}）`);

  const 近卫 = ctx.allies.find(u => u.key === 'B1');
  const 狙击 = ctx.allies.find(u => u.key === 'CB2');
  const 重装 = ctx.allies.find(u => u.key === 'CB4');
  const 敌靶 = ctx.enemies[0];
  const 近卫武 = 近卫.weapons[0].t;
  const 狙击武 = 狙击.weapons[0].t;
  const 敌武 = 敌靶.weapons[0].t;

  const 基准近卫伤 = G.dmgCore(近卫, 近卫武, 敌靶, { power: 近卫武.power, preview: true, turn: 1, ctx }).dmg;
  const 基准狙击命 = G.hitRate(狙击, 狙击武, 敌靶, { baseHit: 40, turn: 1, ctx }).hit;
  const 基准狙击暴 = G.critRate(狙击武, 狙击);
  const 基准狙击伤 = G.dmgCore(狙击, 狙击武, 敌靶, { power: 狙击武.power, preview: true, turn: 1, ctx }).dmg;

  // Step 1: 打出 0 费回气牌【激励】(C_CMD_1: 耗 0 回 +25 → 气势升至 50)
  const r1 = G.打战术牌(ctx, 'C_CMD_1');
  assert(r1.成功 && ctx.气势 === 50, `打出【激励】(耗0回25)后气势由 25 升至 50（实得 ${ctx.气势}）`);

  // Step 2: 打出【热血】(C_GUARD_1: 耗 25 → 气势 25)
  const r2 = G.打战术牌(ctx, 'C_GUARD_1');
  assert(r2.成功 && ctx.气势 === 25, `打出【热血】(耗25)后气势为 25（实得 ${ctx.气势}）`);

  // Step 3: 打出【必中·直击】(C_SNIPE_1: 耗 25 → 气势 0)
  const r3 = G.打战术牌(ctx, 'C_SNIPE_1');
  assert(r3.成功 && ctx.气势 === 0, `打出【必中·直击】(耗25)后气势为 0（实得 ${ctx.气势}）`);

  // 验证伤害、命中、暴击真实进入 20-战斗计算.js 结算公式
  const 热血后近卫伤 = G.dmgCore(近卫, 近卫武, 敌靶, { power: 近卫武.power, preview: true, turn: 1, ctx }).dmg;
  const 必中后狙击命 = G.hitRate(狙击, 狙击武, 敌靶, { baseHit: 40, turn: 1, ctx }).hit;
  const 必中后狙击暴 = G.critRate(狙击武, 狙击);
  const 必中后狙击伤 = G.dmgCore(狙击, 狙击武, 敌靶, { power: 狙击武.power, preview: true, turn: 1, ctx }).dmg;

  assert(热血后近卫伤 > 基准近卫伤, `【热血】使近卫 dmgCore 伤害真实提升（${基准近卫伤} → ${热血后近卫伤}）`);
  assert(必中后狙击命 > 基准狙击命, `【激励+必中·直击】使狙击命中率真实提升（${基准狙击命}% → ${必中后狙击命}%）`);
  assert(必中后狙击暴 === 基准狙击暴 + 20, `【必中·直击】使狙击暴击率真实 +20%（${基准狙击暴}% → ${必中后狙击暴}%）`);
  assert(必中后狙击伤 > 基准狙击伤, `【必中·直击】使狙击 dmgCore 伤害真实提升（${基准狙击伤} → ${必中后狙击伤}）`);

  // 验证【铁壁】(C_HEAVY_1) 的防御与护盾真实进入减免管线
  ctx.气势 = 20;
  const 铁壁前挨打 = G.dmgCore(敌靶, 敌武, 重装, { power: 敌武.power, preview: true, turn: 1, ctx }).dmg;
  const r4 = G.打战术牌(ctx, 'C_HEAVY_1');
  const 铁壁后挨打 = G.dmgCore(敌靶, 敌武, 重装, { power: 敌武.power, preview: true, turn: 1, ctx }).dmg;
  assert(r4.成功 && 重装.shieldHp > 0 && 铁壁后挨打 < 铁壁前挨打,
    `【铁壁】赋予前排护盾(${重装.shieldHp})与防御+40，受击伤害显著降低（${铁壁前挨打} → ${铁壁后挨打}）`);
}

/* ================= [4] 肉鸽招募/晋升 3 选 1 获牌与带入战斗 ================= */
console.log('\n[4] 肉鸽招募/晋升 3 选 1 获牌与带入战斗');
{
  const 假RUN = { 战术牌库: [] };
  const 候选 = G.候选战术牌们(假RUN, 'CB1', 3); // CB1: 近卫 · 天人 · 刹那
  assert(候选.length === 3, `候选战术牌们(RUN, 'CB1', 3) 返回 3 张牌（实得 ${候选.length}）`);
  assert(候选.some(c => c.层级 === '职业' && c.归属 === '近卫')
    && 候选.some(c => c.层级 === '势力' && c.归属 === '天人')
    && 候选.some(c => c.层级 === '角色' && c.归属 === 'CB1'),
    '候选 3 张牌精准包含 1 张职业牌(近卫) + 1 张势力牌(天人) + 1 张角色专属牌(CB1)');

  const 选1 = G.选战术牌(假RUN, 候选[0].id);
  const 选2 = G.选战术牌(假RUN, 候选[2].id);
  assert(选1 && 选2 && 假RUN.战术牌库.includes(候选[0].id) && 假RUN.战术牌库.includes(候选[2].id),
    `选战术牌将所选卡牌并入 RUN.战术牌库（当前 [${假RUN.战术牌库.join(', ')}]）`);

  const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const ctx = G.开局([{ 键: 'CB1', 位: 0, 等级: 20 }], 敌方, 20261013, null, {
    战术卡牌: true,
    已选战术牌: 假RUN.战术牌库,
  });
  assert(ctx.战术手牌.some(c => c.id === 候选[0].id) && ctx.待触发战术牌.some(c => c.id === 候选[2].id),
    'RUN.战术牌库中的初始牌与条件牌在开局时准确装入 ctx.战术手牌 与 ctx.待触发战术牌');
}

/* ================= [5] 战斗手牌栏 UI 与三层反馈 ================= */
console.log('\n[5] 战斗手牌栏 UI 与三层反馈');
{
  try {
    G.界面.设等级(30);
    G.界面.默认五人队();
    G.界面.开战(20261013);
    const 屏El = doc.querySelector('#screen');
    const html1 = 屏El ? 屏El.innerHTML : '';
    assert(html1.includes('class="tactical-hand-bar"') && html1.includes('data-act="打战术牌:'),
      '默认开启战术卡牌时战斗屏渲染 .tactical-hand-bar 与 data-act="打战术牌:<id>" 按钮');

    // 令某张高费牌气势不足 → 验证 disabled
    G.界面.ctx.气势 = 10;
    // 触发一张条件牌 → 验证 .is-triggered
    const 重装 = G.界面.ctx.allies.find(u => u.tags && u.tags.战斗分类 === '重装');
    if (重装) 重装.hp = Math.floor(重装.maxHp * 0.4);
    G.检查条件发牌(G.界面.ctx, '受击', { 目标: 重装 });
    G.界面.刷();
    const html2 = 屏El.innerHTML;
    assert(html2.includes('is-triggered'), '条件触发发牌后手牌按钮挂上 .is-triggered 高亮类名');
    assert(html2.includes('disabled'), '气势不足(10 < 20)的卡牌按钮自动处于 disabled 状态');

    // 通过界面动作打出 0 费【激励】(C_CMD_1)
    const 打结果 = G.界面.动作('打战术牌:C_CMD_1');
    assert(打结果 && 打结果.成功 && G.界面.ctx.气势 === 35,
      `通过 界面.动作('打战术牌:C_CMD_1') 成功出牌并回气（10 → ${G.界面.ctx.气势}）`);

    // 验证战报统计与战报行们汇总
    const 统计 = G.战报统计({ 记录: G.界面.ctx.log, 我方: G.界面.ctx.allies, 敌方: G.界面.ctx.enemies });
    const 行们 = G.战报行们({ 记录: G.界面.ctx.log, 我方: G.界面.ctx.allies, 敌方: G.界面.ctx.enemies });
    assert(统计.战术卡牌 && 统计.战术卡牌.打出数 === 1 && 统计.战术卡牌.触发发牌数 >= 1 && 统计.战术卡牌.累计回气 === 25,
      `战报统计(log).战术卡牌 准确统计打出数(${统计.战术卡牌?.打出数})、触发数(${统计.战术卡牌?.触发发牌数})、回气(${统计.战术卡牌?.累计回气})`);
    assert(行们.some(line => line.startsWith('战术卡牌：')),
      '战报行们包含「战术卡牌：…」结算汇总行');
  } finally {
    G.界面.设等级(10);
  }
}

/* ================= [6] 后台模拟零污染与总闸可关红线 ================= */
console.log('\n[6] 后台模拟零污染与总闸可关红线');
{
  const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const simRes = G.simulate(G.默认五人队, 敌方, {}, 20261013);
  const sim卡牌日志 = simRes.记录.filter(r => r.类型 === '战术牌' || r.类型 === '发牌');
  assert(sim卡牌日志.length === 0, 'simulate() 后台批量模拟默认不写发牌/战术牌日志（保持 2788 基线零污染）');
  const 统计 = G.战报统计({ 记录: simRes.记录, 我方: simRes.我方, 敌方: simRes.敌方 });
  assert(统计.战术卡牌 === undefined, '未打牌时 战报统计 不多出 战术卡牌 字段（旧测试战报零污染）');

  G.战斗结构.战术卡牌.开 = false;
  try {
    const ctxOff = G.开局(G.默认五人队, 敌方, 20261013);
    assert(ctxOff.战术手牌 === undefined, '手动关掉 战斗结构.战术卡牌.开 时不挂战术手牌字段');
  } finally {
    G.战斗结构.战术卡牌.开 = true;
  }
}

/* ================= [7] 真实入口端到端验证（0 手改开关） ================= */
console.log('\n[7] 真实入口端到端验证（0 手改开关：练习战 / 编队屏 / 肉鸽招募3选1 / 晋升3选1 / 肉鸽首战）');
{
  // ① 默认状态断言（严禁手改开关）
  assert(G.战斗结构.战术卡牌.开 === true && G.战术卡牌开() === true,
    '默认状态下 G.战斗结构.战术卡牌.开 === true 且 G.战术卡牌开() === true');

  const 屏El = doc.querySelector('#screen');

  // ② 真实玩家从菜单进入编队屏 → 校验 .tactical-deck-preview
  G.界面.动作('回菜单');
  G.界面.动作('去编队');
  const 编队Html = 屏El ? 屏El.innerHTML : '';
  assert(编队Html.includes('tactical-deck-preview') && 编队Html.includes('初始手牌') && 编队Html.includes('条件触发牌'),
    '编队屏 DOM 真实包含 .tactical-deck-preview（显示当前出击阵容的初始手牌与条件触发牌预览）');

  // ③ 真实玩家在练习模式点击开战 → 校验 .tactical-hand-bar / .tactical-card / .tactical-pending-row 并直接出牌
  G.界面.动作('开战');
  const 练习战Html = 屏El ? 屏El.innerHTML : '';
  const 练习卡数 = (练习战Html.match(/class="tactical-card /g) || []).length;
  assert(练习战Html.includes('tactical-hand-bar') && 练习卡数 >= 3 && 练习战Html.includes('tactical-pending-row'),
    `练习模式战斗屏 DOM 真实包含 .tactical-hand-bar、.tactical-card（${练习卡数} 张 ≥ 3）与 .tactical-pending-row`);
  const 练习出牌 = G.界面.动作('打战术牌:C_CMD_1');
  /* ★ P1.2 §1.1：练习战开局**一律** 25 气势（不再按调用方分叉）→ 打出【激励】(0 费 +25) 后是 50。 */
  assert(练习出牌 && 练习出牌.成功 && G.界面.ctx.气势 === 50,
    `练习模式开战第 1 回合直接点击 界面.动作('打战术牌:C_CMD_1') 生效（气势 25 → ${G.界面.ctx.气势}）`);

  // ④ 真实玩家进入肉鸽：开新局 → 招募机师 → 选战术牌 → 晋升机师 → 选战术牌 → 进入肉鸽首场战斗
  G.界面.动作('回菜单');
  G.肉鸽.新的一局('天人', 20261013);
  G.界面.开屏('招募');
  G.界面.动作('用券:0');
  const 选券Html = 屏El ? 屏El.innerHTML : '';
  const 招匹配1 = 选券Html.match(/data-act="招募:([^"]+)"/);
  const 可招键1 = 招匹配1 && 招匹配1[1];
  assert(!!可招键1, `肉鸽开局选券后招募屏存在可招募机师按钮（${可招键1}）`);
  G.界面.动作(`招募:${可招键1}`);
  const 招募后Html = 屏El ? 屏El.innerHTML : '';
  const 招募待选 = (G.肉鸽.RUN.待选战术牌 || []).slice();
  assert(招募后Html.includes('tactical-pick-box') && 招募待选.length === 3,
    `招募机师后招募屏 DOM 真实出现 .tactical-pick-box（3 张候选牌：${招募待选.join(', ')}）`);
  const 选招牌 = 招募待选[0];
  G.界面.动作(`选战术牌:${选招牌}`);
  assert(G.肉鸽.RUN.战术牌库.includes(选招牌) && !(屏El.innerHTML || '').includes('tactical-pick-box'),
    `在招募屏点击 选战术牌:${选招牌} 后并入 RUN.战术牌库 且 3 选 1 面板收起`);

  // 再招第 2 台（Lv10）并去晋升屏升到 Lv20 → 验证晋升屏 .tactical-pick-box
  G.界面.动作('用券:0');
  const 招匹配2 = (屏El ? 屏El.innerHTML : '').match(/data-act="招募:([^"]+)"/);
  if (招匹配2 && 招匹配2[1]) G.界面.动作(`招募:${招匹配2[1]}`);
  if (G.肉鸽.RUN.待选战术牌 && G.肉鸽.RUN.待选战术牌.length) {
    G.界面.动作(`选战术牌:${G.肉鸽.RUN.待选战术牌[0]}`);
  }
  // 补一张同类券与希望供第 2 台机师在晋升屏晋升
  const 升目标键 = (G.肉鸽.RUN.队伍.find(m => m.等级 === 10) || G.肉鸽.RUN.队伍[0]).键;
  const 升目标Tpl = G.tplOf(升目标键);
  G.肉鸽.RUN.希望 = Math.max(G.肉鸽.RUN.希望, 20);
  G.肉鸽.RUN.券.push({ 类: '职业', 名: 升目标Tpl.tags.战斗分类, 档: null, 来源: '测试补券' });
  G.界面.动作('去晋升');
  G.界面.动作(`晋升:${升目标键}`);
  const 晋升后Html = 屏El ? 屏El.innerHTML : '';
  const 晋升待选 = (G.肉鸽.RUN.待选战术牌 || []).slice();
  assert(G.界面.屏 === '晋升' && 晋升后Html.includes('tactical-pick-box') && 晋升待选.length === 3,
    `晋升机师后晋升屏 DOM 真实出现 .tactical-pick-box（3 张候选牌：${晋升待选.join(', ')}）`);
  const 选升牌 = 晋升待选[0];
  G.界面.动作(`选战术牌:${选升牌}`);
  assert(G.界面.屏 === '晋升' && G.肉鸽.RUN.战术牌库.includes(选升牌) && !(屏El.innerHTML || '').includes('tactical-pick-box'),
    `在晋升屏点击 选战术牌:${选升牌} 后保持在晋升屏、卡牌并入 RUN.战术牌库 且面板收起`);

  // 进入肉鸽首场战斗 → 验证 .tactical-hand-bar 且包含已选入 RUN.战术牌库 的卡牌
  G.界面.动作('回大地图');
  G.肉鸽.RUN.出击阵 = G.肉鸽.RUN.队伍.slice(0, 3).map((m, i) => ({ 键: m.键, 位: i }));
  G.肉鸽.RUN.出击 = G.肉鸽.RUN.出击阵.map(x => x.键);
  G.界面.打这一场();
  const 肉鸽战Html = 屏El ? 屏El.innerHTML : '';
  const 全场牌Ids = G.界面.ctx.战术手牌.concat(G.界面.ctx.待触发战术牌).map(c => c.id);
  assert(肉鸽战Html.includes('tactical-hand-bar') && 全场牌Ids.includes(选招牌) && 全场牌Ids.includes(选升牌),
    `进入肉鸽战斗后 DOM 真实渲染 .tactical-hand-bar 且包含刚选入 RUN.战术牌库 的卡牌（${选招牌}、${选升牌}）`);
  G.肉鸽.清存档();
  G.肉鸽.RUN = null;
  G.肉鸽.进行中 = false;
  G.界面.动作('回菜单');
}

/* ================= [8] 开牌路径确定性基线报数（§1.6） ================= */
console.log('\n[8] 开牌路径确定性基线报数（§1.6：固定种子 20261015 + 默认五人队 + 固定脚本出牌）');
{
  /** 固定脚本：开牌开局 → 第 1 回合打出【激励】+【热血】→ 自动打完本场战斗。 */
  const 基线跑 = () => {
    const 敌方 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
    const ctx = G.开局(G.默认五人队, 敌方, 20261015, null, { 战术卡牌: true });
    const 出1 = G.打战术牌(ctx, 'C_CMD_1');    // 【激励】0 费回 25 气
    const 出2 = G.打战术牌(ctx, 'C_GUARD_1');  // 【热血】耗 25 气
    let 护栏 = 0;
    while (!ctx.result && 护栏++ < 20) G.打一回合(ctx);
    return { ctx, 出1, 出2 };
  };
  const 摘要 = c => ({
    条数: c.ctx.log.length,
    胜负: c.ctx.result ? c.ctx.result.结果 : '（未结束）',
    原因: c.ctx.result ? c.ctx.result.原因 : '',
    回合数: c.ctx.turn,
    我方存活: c.ctx.allies.filter(u => u.hp > 0).map(u => `${u.key}:${u.hp}`),
    敌方存活: c.ctx.enemies.filter(u => u.hp > 0).map(u => `${u.key}:${u.hp}`),
    战况计数: JSON.stringify(c.ctx.战况计数),
    末条: c.ctx.log.length ? c.ctx.log[c.ctx.log.length - 1].文本 : '',
  });
  const A = 基线跑(), B = 基线跑();
  const sA = 摘要(A), sB = 摘要(B);
  assert(A.出1.成功 && A.出2.成功,
    `固定脚本第 1 回合打出【激励】(气势 25 → 50) 与【热血】(50 → 25) 都成功`);
  assert(JSON.stringify(sA) === JSON.stringify(sB),
    `开牌路径同种子连跑两遍 100% 逐字节一致（ctx.log ${sA.条数} 条 / ${sA.胜负} / ${sA.回合数} 回合 / 双方存活 / 战况计数 / 末条全同）`);
  assert(sA.条数 > 0 && sA.胜负 !== '（未结束）',
    `基线确实打完了整场（结果 ${sA.胜负} · ${sA.原因 || '—'}）`);
  assert(A.ctx.log.some(r => r.类型 === '发牌') && A.ctx.log.filter(r => r.类型 === '战术牌').length === 2,
    `基线记录里两种卡牌记录都在：发牌 ${A.ctx.log.filter(r => r.类型 === '发牌').length} 条 · 战术牌 ${A.ctx.log.filter(r => r.类型 === '战术牌').length} 条`);
  console.log(`    · 【§1.6 开牌路径基线】种子 = 20261015 · 我方 = 默认五人队(B1/B2/CB4/CB2/M1) · 敌方 = 编成表[0](${G.编成表[0].层}层 ${G.编成表[0].类型})`);
  console.log(`    · 脚本 = 开局(战术卡牌:true) → 打战术牌 C_CMD_1 → 打战术牌 C_GUARD_1 → 自动打完`);
  console.log(`    · ctx.log.length = ${sA.条数} 条 · 结果 = ${sA.胜负}（${sA.原因 || '—'}） · 回合数 = ${sA.回合数}`);
  console.log(`    · 我方存活 = ${sA.我方存活.join('、') || '（全灭）'}`);
  console.log(`    · 敌方存活 = ${sA.敌方存活.join('、') || '（全灭）'}`);
  console.log(`    · ctx.战况计数 = ${sA.战况计数}`);
  console.log(`    · 末条记录 = 「${sA.末条}」`);
}

/* ================= [9] P1.2 架构红线（源码级 + 行为级） ================= */
console.log('\n[9] P1.2 架构红线（§1.1 气势统一 / §1.2 当场写日志 / §1.3 零 log 依赖 / §1.4 内核不读 RUN / §1.5 统帅牌）');
{
  const 开局源 = 去注释(源码('60-战斗-3-开局与simulate.js'));
  const 记录源 = 去注释(源码('60-战斗-1-方针与记录.js'));
  const 回合源 = 去注释(源码('60-战斗-2-回合流程.js'));
  const 全源 = [开局源, 记录源, 回合源].join('\n');
  /** 抠出一个 `function 名(...) { … }` 的函数体（大括号配平）。 */
  const 取函数 = (源, 名) => {
    const i = 源.indexOf(`function ${名}(`);
    if (i < 0) return '';
    const 起 = 源.indexOf('{', i);
    if (起 < 0) return '';
    let d = 0;
    for (let j = 起; j < 源.length; j++) {
      if (源[j] === '{') d++;
      else if (源[j] === '}') { d--; if (d === 0) return 源.slice(起, j + 1); }
    }
    return 源.slice(起);
  };
  const 敌9 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));

  /* ---- §1.1 初始气势统一（删掉按调用方分叉的隐式逻辑） ---- */
  assert(!/选项\.初始气势/.test(开局源),
    '§1.1 源码里不再有 `选项.初始气势` 这条按调用方分叉的隐式逻辑');
  const 开牌不传 = G.开局(G.默认五人队, 敌9, 20261015);
  const 开牌显式 = G.开局(G.默认五人队, 敌9, 20261015, null, { 战术卡牌: true });
  assert(开牌不传.气势 === 25 && 开牌显式.气势 === 25,
    `§1.1 只要开了牌，初始气势一律 25（不显式传 选项.战术卡牌 → ${开牌不传.气势}；显式传 true → ${开牌显式.气势}）`);
  assert(/战术卡牌: false/.test(开局源),
    '§1.1 `simulate()` 内部调 `开局` 时默认显式传 `{ 战术卡牌: false }`（关牌路径显式化）');
  const 关牌 = G.开局(G.默认五人队, 敌9, 20261015, null, { 战术卡牌: false });
  assert(关牌.气势 === 0 && 关牌.战术手牌 === undefined && 关牌.战况计数 === undefined,
    `§1.1 关牌路径（显式 { 战术卡牌: false }）气势仍是开场值 0、不挂战术字段（气势 ${关牌.气势}）`);

  /* ---- §1.2 发牌记录当场写入（删掉待写发牌日志延后补写机制） ---- */
  assert(!/待写发牌日志/.test(全源) && !/战术卡牌写日志/.test(全源),
    '§1.2 源码里 `ctx.待写发牌日志` / `ctx.战术卡牌写日志` 已彻底删除');
  const ctx2 = G.开局([{ 键: 'CB4', 位: 0, 等级: 20 }], 敌9, 20261015, null, { 战术卡牌: true });
  const 重装2 = ctx2.allies.find(u => u.key === 'CB4');
  重装2.hp = Math.floor(重装2.maxHp * 0.5);
  const 条数前 = ctx2.log.length;
  G.检查条件发牌(ctx2, '受击', { 目标: 重装2 });
  const 新条 = ctx2.log.slice(条数前);
  assert(新条.length >= 1 && 新条.every(r => r.类型 === '发牌' && r.文本.startsWith('〔发牌〕')),
    `§1.2 条件牌一进手牌就**当场**写一条发牌记录（不延后）：${新条.map(r => `「${r.文本}」`).join('')}`);
  assert(ctx2.待写发牌日志 === undefined,
    '§1.2 打牌前后 `ctx` 上都不存在 `待写发牌日志` 字段');

  /* ---- §1.3 触发条件零 `ctx.log` 反向依赖 + `ctx.战况计数` 显式状态 ---- */
  const 条件体 = 取函数(记录源, '是否满足卡牌触发条件');
  assert(条件体.length > 0 && !/ctx\.log/.test(条件体),
    '§1.3 `是否满足卡牌触发条件()` 里一次 `ctx.log` 都没读（100% 纯状态驱动）');
  const 发牌体 = 取函数(记录源, '检查条件发牌');
  /* 允许的唯一一处 `ctx.log` 是「有 log 才写」的写记录守卫（`Array.isArray(ctx.log)`），
     去掉它之后函数体里不许再出现任何 `ctx.log`（= 不许扫日志判条件）。 */
  const 发牌体净 = 发牌体.replace(/Array\.isArray\(ctx\.log\)/g, '').replace(/ctx\.log\.length/g, '');
  assert(发牌体.length > 0 && !/ctx\.log/.test(发牌体净),
    '§1.3 检查条件发牌() 不再扫 ctx.log 判断条件（只保留「有 log 就写一条发牌记录」那处守卫）');
  assert(!/累计未命中段数/.test(全源),
    '§1.3 旧的 `ctx.累计未命中段数` 已删除，换成 `ctx.战况计数.未命中段`');
  const 计3 = G.开局(G.默认五人队, 敌9, 20261015, null, { 战术卡牌: true }).战况计数;
  const 键们 = Object.keys(计3 || {}).sort().join('、');
  /* ★ P1.3 §FIX-3：**多了第六个子键 `满手牌推迟数`**（条件满足、可手牌到了上限时的推迟发牌计数；
     `ctx.满手牌推迟记录` 是它的明细）—— 五个 → 六个，别的地方一个都没动。 */
  assert(键们 === ['响介受击或打空', '刹那命中或TA', '未命中段', '残月或月国命中', '满手牌推迟数', '秘银标定'].sort().join('、'),
    `§1.3 开局初始化 ctx.战况计数 的六个子键齐备（${键们}）`);
  assert(Object.values(计3 || {}).every(v => v === 0), '§1.3 `ctx.战况计数` 六个子键初值全为 0');
  /* 真实事件真的会累加（打一场真战斗，看计数器动了没有） */
  const ctx3 = G.开局(G.默认五人队, 敌9, 20261015, null, { 战术卡牌: true });
  for (let i = 0; i < 3 && !ctx3.result; i++) G.打一回合(ctx3);
  assert(Object.values(ctx3.战况计数).some(v => v > 0),
    `§1.3 真打 3 回合后 ctx.战况计数 当场被真实事件累加（${JSON.stringify(ctx3.战况计数)}）`);

  /* ---- §1.4 战斗内核不读全局 `RUN` ---- */
  const 牌池体 = 取函数(记录源, '生成队伍牌池');
  assert(牌池体.length > 0 && !/肉鸽/.test(牌池体) && !/使用肉鸽牌库/.test(全源),
    '§1.4 `生成队伍牌池()` 里不再回退读全局 `肉鸽.RUN.战术牌库`（`使用肉鸽牌库` 已删）');
  const 备份RUN = G.肉鸽.RUN;
  try {
    /* ★ 挑「只有肉鸽牌库才拿得到」的牌：队伍里只有 CB1（近卫·天人·CB1），
       所以 `U_M1`（M1 的角色牌）不可能由三层牌池自己派生出来 —— 它只能来自 `选项.已选战术牌`。 */
    G.肉鸽.RUN = { 战术牌库: ['U_M1', 'U_A1'] };
    const 池无参 = G.生成队伍牌池([{ 键: 'CB1', 位: 0, 等级: 20 }]);
    const 池传参 = G.生成队伍牌池([{ 键: 'CB1', 位: 0, 等级: 20 }], { 已选战术牌: ['U_M1'] });
    assert(!池无参.全部牌池.some(c => c.id === 'U_M1') && !池无参.全部牌池.some(c => c.id === 'U_A1'),
      '§1.4 不传 `选项.已选战术牌` 时**绝不继承** `肉鸽.RUN.战术牌库`（练习战与肉鸽牌库严格隔离）');
    assert(池传参.全部牌池.some(c => c.id === 'U_M1'),
      '§1.4 显式传 `{ 已选战术牌: RUN.战术牌库 }` 时才装进队伍牌池（肉鸽入口那条路）');
  } finally {
    G.肉鸽.RUN = 备份RUN;
  }

  /* ---- §1.5 统帅牌 = 标准条件触发牌（不在手牌一律打不出；气势达标自动入牌） ---- */
  const ctx5 = G.开局(G.默认五人队, 敌9, 20261015, null, { 战术卡牌: true });
  assert(!ctx5.战术手牌.some(c => c.id === 'CMD_ALL_OUT') && ctx5.待触发战术牌.some(c => c.id === 'CMD_ALL_OUT'),
    '§1.5 两张统帅牌开局**不进初始手牌**，而是待在 `ctx.待触发战术牌`（不挤占 6 张初始手牌槽）');
  const 硬打 = G.打战术牌(ctx5, 'CMD_ALL_OUT');
  assert(硬打.成功 === false && 硬打.原因 === '手牌中不存在该战术牌',
    `§1.5 不在手牌里的统帅牌**打不出**（删掉自动塞手牌特例）：${硬打.原因}`);
  ctx5.气势 = 74;
  G.检查条件发牌(ctx5, '气势变动', { 回合: 1 });
  const 不到 = ctx5.战术手牌.some(c => c.id === 'CMD_ALL_OUT');
  G.加气势(ctx5, 1);
  const 到了 = ctx5.战术手牌.some(c => c.id === 'CMD_ALL_OUT');
  assert(!不到 && 到了,
    `§1.5 MORALE_75 由 加气势 当场触发：气势 74 不发、75 发（74 → ${不到}；75 → ${到了}）`);
  assert(G.战术卡牌参数().手牌总上限 === 10,
    `§1.5 手牌总上限 已按任务书设成 10（实得 ${G.战术卡牌参数().手牌总上限}），确保统帅牌不因满手牌卡死`);
  ctx5.气势 = 100;
  const 统帅打出 = G.打战术牌(ctx5, 'CMD_ALL_OUT');
  assert(统帅打出.成功 === true && ctx5.气势 === 0,
    `§1.5 气势 100 时手牌里的【⚡全军总攻】打得出来（100 → ${ctx5.气势}）`);

  /* ---- §1.8 决策日志接线（打战术牌 / 选战术牌 两族） ---- */
  assert(G.选项.动作们.includes('打战术牌') && G.选项.动作们.includes('选战术牌'),
    '§1.8 `决策动作们` 已加入 `打战术牌` 与 `选战术牌`');
  const 屏族们 = 屏 => { const v = G.选项.屏族[屏]; return typeof v === 'function' ? v(G.界面) : (v || []); };
  assert(屏族们('战斗').includes('打战术牌')
    && 屏族们('招募').includes('选战术牌') && 屏族们('晋升').includes('选战术牌'),
    '§1.8 `屏决策族` 的 战斗 / 招募 / 晋升 三屏都接上了战术卡牌那一族');
  G.界面.动作('回菜单');
  G.界面.设等级(10);
  G.界面.默认五人队();
  G.界面.开战(20261015);
  const 可打码 = G.选项.枚举(G.界面, '打战术牌');
  const 手牌可打 = G.界面.ctx.战术手牌.filter(c => (Number(G.界面.ctx.气势) || 0) >= (Number(c.耗气) || 0)
    && (Number(c.当前冷却) || 0) <= 0 && (c.剩余次数 == null || Number(c.剩余次数) > 0));
  assert(可打码.length === 手牌可打.length && 可打码.every(x => x.startsWith('打战术牌:')) && 可打码.length > 0,
    `§1.8 战斗屏指令阶段枚举出 ${可打码.length} 张真能打的牌（${可打码.join('、')}）—— 一张不可打的都不列`);
  G.界面.ctx.气势 = 0;
  const 不可打 = G.选项.枚举(G.界面, '打战术牌');
  assert(不可打.length === 1 && 不可打[0] === '打战术牌:C_CMD_1'
    && !不可打.includes('打战术牌:C_GUARD_1'),
    `§1.8 气势清零后只剩 0 费【激励】还能打（枚举 = ${不可打.join('、') || '（空）'}），耗气 25 的【热血】当场从选项里消失`);
  const 备份RUN2 = G.肉鸽.RUN;
  try {
    G.肉鸽.RUN = { 待选战术牌: ['C_GUARD_1', 'F_CB_1', 'U_CB1'] };
    const 选码 = G.选项.枚举(G.界面, '选战术牌');
    assert(选码.length === 3 && 选码.includes('选战术牌:C_GUARD_1'),
      `§1.8 RUN.待选战术牌 非空时枚举出 3 条 选战术牌:（${选码.join('、')}）`);
  } finally {
    G.肉鸽.RUN = 备份RUN2;
  }
  G.界面.动作('回菜单');
}

/* ================= [10] P1.2 §1.1 录像字段契约 + §1.5 打牌后立即复查发牌 ================= */
console.log('\n[10] P1.2 §1.1 录像顶层 `战术卡牌` 字段契约（唯一判据）+ §1.5 打牌后立即复查条件发牌');
{
  const { 应用录像战术卡牌开关 } = await import('../tools/replay.mjs');

  /* ---- ① 新录像开新局时写顶层 `战术卡牌`（= 录的时候 `战斗结构.战术卡牌.开`） ---- */
  const 备份RUN10 = G.肉鸽.RUN, 备份开10 = G.战斗结构.战术卡牌.开;
  let 开场 = null, 关场 = null;
  try {
    G.录像.清();
    G.肉鸽.RUN = { 种子: 20261015, 分队: '无', t0: 1760500000000 };
    G.战斗结构.战术卡牌.开 = true;
    开场 = G.录像.会话(true);
    G.录像.清();
    G.战斗结构.战术卡牌.开 = false;
    关场 = G.录像.会话(true);
  } finally {
    G.录像.清();
    G.肉鸽.RUN = 备份RUN10;
    G.战斗结构.战术卡牌.开 = 备份开10;
  }
  assert(!!开场 && 开场.战术卡牌 === true,
    `§1.1 新录像建会话时一律写顶层 \`战术卡牌\`（开=true → ${开场 && 开场.战术卡牌}）`);
  assert(!!关场 && 关场.战术卡牌 === false,
    `§1.1 关牌路径录下来的会话写 \`战术卡牌: false\`（→ ${关场 && 关场.战术卡牌}）`);

  /* ---- ② 旧录像没有这个字段 → `认场()` **一个字节都不补** ---- */
  const 旧场 = G.录像.认场({ 格式版本: 1, 游戏版本: G.version, 种子: 20261015, 分队: '无',
    开始时间: '2026-10-13 11:49:20', 结束时间: null, 结果: null, 操作: [] }, false);
  assert(!!旧场 && !('战术卡牌' in 旧场),
    `§1.1 旧录像（没有 \`战术卡牌\`）读回来**不凭空补字段**（认出来的字段：${旧场 ? Object.keys(旧场).join('、') : 'null'}）`);
  const 新场 = G.录像.认场({ 战术卡牌: true, 操作: [] }, false);
  assert(!!新场 && 新场.战术卡牌 === true, '§1.1 带 `战术卡牌: true` 的录像读回来保留 true');

  /* ---- ③ 重放侧严格判据：**只有 `录像.战术卡牌 === true` 才开牌**，其余（含缺字段）一律关牌 ---- */
  const 例 = [
    ['缺少字段（旧录像）', {}, false],
    ['显式 true', { 战术卡牌: true }, true],
    ['显式 false', { 战术卡牌: false }, false],
    ['字符串 "true"（不算）', { 战术卡牌: 'true' }, false],
    ['数字 1（不算）', { 战术卡牌: 1 }, false],
  ];
  const 错例 = 例.filter(([, 录, 期望]) => {
    const g = { 战斗结构: { 战术卡牌: { 开: true } } };
    const 实 = 应用录像战术卡牌开关(g, 录);
    return 实 !== 期望 || g.战斗结构.战术卡牌.开 !== 期望;
  });
  assert(错例.length === 0,
    `§1.1 重放侧**只认顶层字段**：${例.map(([名, , 期]) => `${名}→${期}`).join(' · ')} —— 全部吻合，且 \`战斗结构.战术卡牌.开\` 真的被钉成该值（不猜录像内容）`);

  /* ---- ④ §1.5：打牌 / 手动开 TRANS-AM 后**立即**复查（源码里的调用签名） ---- */
  const 记录源10 = 去注释(源码('60-战斗-1-方针与记录.js'));
  const 天人源10 = 去注释(源码('72-势力-4-天人与ATX.js'));
  assert(/检查条件发牌\(ctx, '打战术牌', \{ cardId: card\.id \}\)/.test(记录源10),
    "§1.5 `打战术牌()` 结算完气势与卡牌效果后**立即**调 `检查条件发牌(ctx, '打战术牌', { cardId })`（任务书点名的调用签名）");
  assert(/检查条件发牌\(ctx, '手动TRANSAM'/.test(天人源10),
    '§1.5 指令阶段手动开启 TRANS-AM 后也复查一次（`手动开天人()` 里那次调用）');

  /* ---- ⑤ 行为：靠**卡牌效果本身**才成立的衍生条件牌，在**同一次 `打战术牌()` 里**就进手牌 ---- */
  const 敌10 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const c10 = G.开局([{ 键: 'CB1', 位: 0, 等级: 20 }], 敌10, 20261015, null, { 战术卡牌: true });
  assert(c10.战术手牌.some(x => x.id === 'F_CB_1') && c10.待触发战术牌.some(x => x.id === 'F_CB_2'),
    '§1.5 摆好现场：【TRANS-AM 解放】(F_CB_1) 在初始手牌里，衍生条件牌【GN 粒子力场】(F_CB_2) 在待触发队列');
  c10.气势 = 100;
  const 出解放 = G.打战术牌(c10, 'F_CB_1');
  assert(出解放.成功 && c10.战况计数.刹那命中或TA >= 1,
    `§1.5 打出【TRANS-AM 解放】成功，且当场把 \`战况计数.刹那命中或TA\` 加到 ${c10.战况计数.刹那命中或TA}`);
  assert(c10.战术手牌.some(x => x.id === 'F_CB_2'),
    '§1.5 打牌**当场**就把「靠这次效果才成立」的衍生条件牌【GN 粒子力场】发进 `ctx.战术手牌`（= 结算完卡牌效果后才复查）');
  assert(c10.log.some(r => r.类型 === '发牌' && r.卡牌ID === 'F_CB_2'),
    '§1.5 这一次发牌**当场**写进了 `ctx.log`（没有延后补写）');

  const c75 = G.开局([{ 键: 'B1', 位: 0, 等级: 20 }], 敌10, 20261015, null, { 战术卡牌: true });
  c75.气势 = 50;
  const 待着 = c75.待触发战术牌.some(x => x.id === 'CMD_ALL_OUT');
  const 出激励 = G.打战术牌(c75, 'C_CMD_1');            // 【激励】0 费回 25 气 → 75
  assert(待着 && 出激励.成功 && c75.气势 === 75 && c75.战术手牌.some(x => x.id === 'CMD_ALL_OUT'),
    `§1.5 回气类牌把气势推到 75 → 统帅牌当回合当场入牌（气势 ${c75.气势}，到手 ${c75.战术手牌.some(x => x.id === 'CMD_ALL_OUT')}）`);
}

/* ================= [11] P1.3 §FIX-3 手牌满上限时的推迟发牌 =================
 * 任务书 §1.3 / §2.2 第三条。要钉住的四件事：
 *   ① 条件满足 + 手牌满 → 卡**留在** `ctx.待触发战术牌`（腾出空位后还能发）；
 *   ② **`ctx.log` 一行都不多**（`2788` 与开牌基线 `31` 条零改动靠这一条）；
 *   ③ `ctx.战况计数.满手牌推迟数` 递增 + `ctx.满手牌推迟记录` 记准 `{回合, id, 名}`（同回合同牌只记一次）；
 *   ④ 战后战报（`84-反馈.js`）能看见它，而 `满手牌推迟数 === 0` 时**一个字都不加**（零污染）。 */
console.log('\n[11] P1.3 §FIX-3 条件发牌被手牌总上限挡下：卡留队列 · ctx.log 零增行 · 战报看得见');
{
  const 敌11 = G.敌方规格组(G.编成到单位(G.编成表[0], 0));
  const 上限11 = G.战术卡牌参数().手牌总上限;
  const 造 = () => {
    const c = G.开局([{ 键: 'B1', 位: 0, 等级: 20 }], 敌11, 20261015, null, { 战术卡牌: true });
    /* 手牌塞满（用假卡占位，只关心「长度到上限」这一件事）。 */
    c.战术手牌 = Array.from({ length: 上限11 }, (_, i) => ({ id: `占位${i}`, 名: `占位${i}` }));
    /* 一张「条件一定满足」的牌：`ANY_MISS` 只读 `ctx.战况计数.未命中段`（纯状态，不扫日志）。 */
    c.待触发战术牌 = [{ id: 'T_FULL_1', 名: '测试·满手牌', 触发条件码: 'ANY_MISS', 触发说明: '任意未命中段' }];
    c.战况计数.未命中段 = 1;
    return c;
  };

  const c11 = 造();
  const log前 = c11.log.length;
  const 新11 = G.检查条件发牌(c11, '测试', {});
  assert(新11.length === 0 && c11.战术手牌.length === 上限11,
    `§FIX-3 手牌满（${c11.战术手牌.length}/${上限11}）→ 一张都没发出去（新发牌 ${新11.length}）`);
  assert(c11.待触发战术牌.some(x => x.id === 'T_FULL_1'),
    '§FIX-3 被挡下的那张牌**照旧留在 `ctx.待触发战术牌` 里**（后续手牌腾出空位还能发）');
  assert(c11.log.length === log前,
    `§FIX-3 **\`ctx.log\` 一行都不多**（${log前} → ${c11.log.length}）—— 2788 与开牌基线 31 条零改动靠这一条`);
  assert(c11.战况计数.满手牌推迟数 === 1,
    `§FIX-3 \`ctx.战况计数.满手牌推迟数\` 递增到 ${c11.战况计数.满手牌推迟数}`);
  const 记11 = c11.满手牌推迟记录[0] || {};
  assert(c11.满手牌推迟记录.length === 1 && 记11.回合 === 1 && 记11.id === 'T_FULL_1' && 记11.名 === '测试·满手牌',
    `§FIX-3 \`ctx.满手牌推迟记录\` 记准 {\`回合,id,名\`}：${JSON.stringify(记11)}`);

  /* 同一回合里 `检查条件发牌` 会被调用好几次（每次攻击后 / 打牌后 / 气势变动后）→ 不许重复记账。 */
  G.检查条件发牌(c11, '测试', {});
  G.检查条件发牌(c11, '再次', {});
  assert(c11.战况计数.满手牌推迟数 === 1 && c11.满手牌推迟记录.length === 1,
    '§FIX-3 同一回合同一张牌**只记一次**（连调三次仍然 1 笔）');

  /* 下一回合再被挡下 → 再记一笔（回合号变了，是另一次推迟）。 */
  c11.turn = 2;
  G.检查条件发牌(c11, '测试', {});
  assert(c11.战况计数.满手牌推迟数 === 2 && c11.满手牌推迟记录.length === 2 && c11.满手牌推迟记录[1].回合 === 2,
    `§FIX-3 换一个回合再被挡下 → 再记一笔（共 ${c11.战况计数.满手牌推迟数} 笔）`);

  /* 腾出一个手牌空位 → 下一次检查就该真的发出去，且推迟计数不再涨。 */
  c11.战术手牌.pop();
  const 好11 = G.检查条件发牌(c11, '腾位置', {});
  assert(好11.length === 1 && 好11[0].id === 'T_FULL_1' && !c11.待触发战术牌.some(x => x.id === 'T_FULL_1'),
    '§FIX-3 腾出一个空位后，**下一次检查就正常发出**（卡离开待触发队列）');
  assert(c11.战况计数.满手牌推迟数 === 2,
    `§FIX-3 真的发出去那一次**不算推迟**（推迟数仍是 ${c11.战况计数.满手牌推迟数}）`);

  /* 战后战报（三层反馈的「结算」那一层）：`84-反馈.js` 纯读 ctx，不另开一套账。 */
  const 统11 = G.战报统计(c11);
  assert(!!统11.战术卡牌 && 统11.战术卡牌.满手牌推迟数 === 2,
    `§FIX-3 \`战报统计(ctx).战术卡牌.满手牌推迟数\` = ${统11.战术卡牌 && 统11.战术卡牌.满手牌推迟数}`);
  assert(JSON.stringify(统11.战术卡牌.满手牌推迟明细) === JSON.stringify(['第1回合【测试·满手牌】', '第2回合【测试·满手牌】']),
    `§FIX-3 明细格式化成 \`第N回合【牌名】\`：${JSON.stringify(统11.战术卡牌.满手牌推迟明细)}`);
  const 行11 = G.战报行们(c11);
  assert(行11.some(x => String(x).indexOf('手牌满上限推迟发牌 2 次') === 0),
    `§FIX-3 战报里多一行清晰文案：${行11.filter(x => String(x).indexOf('推迟') >= 0)[0]}`);

  /* ★ 零污染：没有推迟发生时，`战报统计` 一个字段都不多、`战报行们` 一行都不加。 */
  const 净11 = G.开局([{ 键: 'B1', 位: 0, 等级: 20 }], 敌11, 20261015, null, { 战术卡牌: true });
  净11.战况计数.满手牌推迟数 = 0;
  净11.满手牌推迟记录 = [];
  const 统净 = G.战报统计(净11);
  assert(!统净.战术卡牌 || !('满手牌推迟数' in 统净.战术卡牌),
    '§FIX-3 零污染：没发生过推迟时 `战报统计` 的战术卡牌块**不带** `满手牌推迟数` / `满手牌推迟明细`');
  assert(!G.战报行们(净11).some(x => String(x).indexOf('推迟') >= 0),
    '§FIX-3 零污染：没发生过推迟时战报里**一行都不加**（既有战报断言照旧逐字成立）');

  /* 关牌路径（`ctx.战况计数` 不存在）整段空转：不崩、也不挂字段。 */
  const 关11 = G.开局([{ 键: 'B1', 位: 0, 等级: 20 }], 敌11, 20261015, null, { 战术卡牌: false });
  assert(关11.战况计数 === undefined && 关11.满手牌推迟记录 === undefined && JSON.stringify(G.检查条件发牌(关11, '测试', {})) === '[]',
    '§FIX-3 关牌路径：`ctx.战况计数` / `ctx.满手牌推迟记录` 都不挂，`检查条件发牌()` 返回空数组（与改前逐字同路）');
}

console.log(`\n========================================`);
console.log(`战术卡牌系统 P1 测试完成：通过 ${passes} 项，失败 ${fails} 项`);
if (fails > 0) {
  console.error('失败项：', errs);
  process.exit(1);
}
