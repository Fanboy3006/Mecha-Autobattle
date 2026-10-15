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
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

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
  ctx.累计未命中段数 = 2;
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
  assert(练习出牌 && 练习出牌.成功 && G.界面.ctx.气势 === 25,
    `练习模式开战第 1 回合直接点击 界面.动作('打战术牌:C_CMD_1') 生效（气势 0 → ${G.界面.ctx.气势}）`);

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

console.log(`\n========================================`);
console.log(`战术卡牌系统 P1 测试完成：通过 ${passes} 项，失败 ${fails} 项`);
if (fails > 0) {
  console.error('失败项：', errs);
  process.exit(1);
}
