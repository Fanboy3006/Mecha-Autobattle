/**
 * 动作 QTE 专项测试：刹那「七剑·TRANS-AM 乱舞」7 连斩独立 Demo 与引擎 resolveAttack 逐段注入接口
 * 运行：node tests/qte_demo.js
 */
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { makeSandbox, inlineScripts, runScripts, loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const DEMO_PATH = join(ROOT, '协作', '演出', 'demo-动作QTE-刹那七连斩.html');
const INDEX_PATH = join(ROOT, 'index.html');

let fails = 0;
const errs = [];
const ok = (m) => console.log('  ✓ ' + m);
const bad = (m) => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const assert = (cond, m) => (cond ? ok(m) : bad(m));

console.log('=== [动作QTE] 刹那「七剑·TRANS-AM 乱舞」7连斩 Demo 与引擎注入测试 ===');

// 1. 加载独立 Demo 页面
const demoHtml = readFileSync(DEMO_PATH, 'utf8').replace(/\r\n/g, '\n');
const { sandbox: demoSb, errors: demoErrs } = (() => {
  const { sandbox } = makeSandbox();
  const errors = runScripts(sandbox, inlineScripts(demoHtml), { quiet: true });
  return { sandbox, errors };
})();
assert(demoErrs.length === 0, `独立 Demo 脚本无报错加载 (errors=${demoErrs.length})`);
const QTE = demoSb.window.__actionQTE;
assert(Boolean(QTE), 'window.__actionQTE 接口已挂载');

// 2. 加载主游戏页面
const { sandbox: gameSb, errors: gameErrs } = loadPage(INDEX_PATH);
assert(gameErrs.length === 0, `主游戏 index.html 无报错加载 (errors=${gameErrs.length})`);
const G = gameSb.window.__game;
assert(
  typeof G.动作QTE参数 === 'function' &&
  typeof G.动作QTE开 === 'function' &&
  typeof G.计算QTE晃动参数 === 'function',
  'window.__game 已导出 动作QTE参数 / 动作QTE开 / 计算QTE晃动参数'
);

// ============================================================================
console.log('\n[1] 难度映射单调性（eva 10->30->55 递增，命中率 q 95->55 半径递减）');
{
  const p10 = QTE.取晃动参数(10, 95, 0);
  const p30 = QTE.取晃动参数(30, 95, 0);
  const p55 = QTE.取晃动参数(55, 95, 0);
  assert(
    p10.晃动频率Hz < p30.晃动频率Hz && p30.晃动频率Hz < p55.晃动频率Hz,
    `晃动频率Hz 随 eva(10->30->55) 严格递增：${p10.晃动频率Hz} < ${p30.晃动频率Hz} < ${p55.晃动频率Hz}`
  );
  assert(
    p10.晃动幅度X < p30.晃动幅度X && p30.晃动幅度X < p55.晃动幅度X,
    `晃动幅度X 随 eva(10->30->55) 严格递增：${p10.晃动幅度X} < ${p30.晃动幅度X} < ${p55.晃动幅度X}`
  );

  const q95 = G.计算QTE晃动参数(null, { eva: 30 }, null, 0, 95);
  const q75 = G.计算QTE晃动参数(null, { eva: 30 }, null, 1, 75);
  const q55 = G.计算QTE晃动参数(null, { eva: 30 }, null, 2, 55);
  assert(
    q95.有效半径Px > q75.有效半径Px && q75.有效半径Px > q55.有效半径Px,
    `有效半径Px 随命中率 q(95->75->55) 严格递减：${q95.有效半径Px} > ${q75.有效半径Px} > ${q55.有效半径Px}`
  );
  assert(
    q95.完美半径Px > q75.完美半径Px && q75.完美半径Px > q55.完美半径Px,
    `完美半径Px 随命中率 q(95->75->55) 严格递减：${q95.完美半径Px} > ${q75.完美半径Px} > ${q55.完美半径Px}`
  );

  // 验证引擎对 grunt / fighter / stealth 单位对象的 eva 映射一致性
  const uGrunt = G.makeUnit('grunt', 'enemy', 10, 0);
  const uFighter = G.makeUnit('fighter', 'enemy', 10, 1);
  const uStealth = G.makeUnit('stealth', 'enemy', 10, 2);
  const eg = G.计算QTE晃动参数(null, uGrunt, null, 0, 95);
  const ef = G.计算QTE晃动参数(null, uFighter, null, 0, 95);
  const es = G.计算QTE晃动参数(null, uStealth, null, 0, 95);
  assert(
    eg.目标闪避 === 10 && ef.目标闪避 === 30 && es.目标闪避 === 55,
    `引擎单位闪避映射正确：grunt=${eg.目标闪避}, fighter=${ef.目标闪避}, stealth(含隐匿等效)=${es.目标闪避}`
  );
}

// ============================================================================
console.log('\n[2] 几何斩击判定精度（PERFECT / HIT / MISS / 过短防误触）');
{
  const stg = QTE.取晃动参数(30, 95, 0); // 有效半径 37, 完美半径 15
  const target = { x: 120, y: 80 };

  // 穿过靶心 (距离 d = 0 <= 15) -> PERFECT
  const jPerf = QTE.判定斩击({ x: 90, y: 80 }, { x: 150, y: 80 }, target, stg);
  assert(
    jPerf.命中 === true && jPerf.评价 === 'PERFECT' && jPerf.距离 === 0 && jPerf.精度 === 1,
    `穿过靶心判为 PERFECT (距离=${jPerf.距离}, 精度=${jPerf.精度})`
  );

  // 擦过机身有效圈 (距离 d = 24, 15 < 24 <= 37) -> HIT
  const jHit = QTE.判定斩击({ x: 90, y: 104 }, { x: 150, y: 104 }, target, stg);
  assert(
    jHit.命中 === true && jHit.评价 === 'HIT' && jHit.距离 === 24,
    `擦过有效圈判为 HIT (距离=${jHit.距离}, 精度=${jHit.精度})`
  );

  // 偏离有效圈外 (距离 d = 50 > 37) -> MISS
  const jMiss = QTE.判定斩击({ x: 90, y: 130 }, { x: 150, y: 130 }, target, stg);
  assert(
    jMiss.命中 === false && jMiss.评价 === 'MISS' && jMiss.精度 === 0,
    `偏离有效圈外判为 MISS (距离=${jMiss.距离})`
  );

  // 线段过短 (< 18px) 防原地点击误触 -> MISS
  const jShort = QTE.判定斩击({ x: 118, y: 80 }, { x: 122, y: 80 }, target, stg);
  assert(
    jShort.命中 === false && jShort.评价 === 'MISS',
    `过短线段 (<18px) 防误触判为 MISS (原因=${jShort.原因})`
  );
}

// ============================================================================
console.log('\n[3] 七剑动态步进（-10 / +10）闭环');
{
  const sess = QTE.创建会话({ 种子: 20261013, 武器: { 基础命中: 95, 段数: 7, 步进: 10 } });
  sess.进入斩击幕();
  assert(sess.状态.当前理论命中率 === 95, '第 1 刀初始理论命中率 = 95');

  const s1 = sess.提交斩击('PERFECT', null, 200);
  assert(s1.命中 === true && sess.状态.当前理论命中率 === 85, `第 1 刀 PERFECT 后，第 2 刀理论命中率降为 ${sess.状态.当前理论命中率} (期望 85)`);

  const s2 = sess.提交斩击('MISS', null, 250);
  assert(s2.命中 === false && sess.状态.当前理论命中率 === 95, `第 2 刀 MISS 后，第 3 刀理论命中率回升至 ${sess.状态.当前理论命中率} (期望 95)`);

  const s3 = sess.提交斩击('HIT', null, 300);
  assert(s3.命中 === true && sess.状态.当前理论命中率 === 85, `第 3 刀 HIT 后，第 4 刀理论命中率降为 ${sess.状态.当前理论命中率} (期望 85)`);
}

// ============================================================================
console.log('\n[4] 引擎 resolveAttack 真实注入联动（CB1 刹那 Lv20 七剑·TRANS-AM 乱舞）');
{
  const makeTestPair = (seed = 20261013) => {
    /* 签名照引擎：`makeUnit(键, side, slot, lv)` —— 第三个是**站位**、第四个才是等级。 */
    const att = G.makeUnit('CB1', 'ally', 0, 20);
    const def = G.makeUnit('fighter', 'enemy', 4, 20);
    def.maxHp = 99999;
    def.hp = 99999;
    const ctx = {
      rng: G.mulberry32(seed),
      turn: 1,
      allies: [att],
      enemies: [def],
      log: [],
    };
    /* 真的开一次 TRANS-AM（走引擎自己的 `开启天人()`，不手改单位字段）：
       `七剑·TRANS-AM 乱舞` 带 `taOnly`、且威力 ×1.3 走 `势力威力倍率()`。 */
    G.开启天人(ctx, att, 1, G.势力状态(att, '天人'), G.天人参数());
    /* 武器传**解包后的模板**（`weapon.t`）—— `resolveAttack` 的 `w` 是模板，不是运行期包装。 */
    const w = att.weapons.find((x) => x.t && x.t.name.includes('七剑')) || att.weapons[att.weapons.length - 1];
    return { att, def, w: w.t, ctx };
  };

  // (a) 注入全 MISS (0/7)
  const qteMiss = QTE.模拟整套七连斩('MISS', { 种子: 20261013 });
  const pairMiss = makeTestPair(20261013);
  const outMiss = G.resolveAttack(pairMiss.att, pairMiss.def, pairMiss.w, pairMiss.ctx, {
    强制QTE: true,
    qte结果: qteMiss,
  });
  assert(
    outMiss.字段.命中 === false && outMiss.字段.命中段数 === 0 && outMiss.字段.伤害 === 0,
    `注入全 MISS (0/7)：命中=${outMiss.字段.命中}, 命中段数=${outMiss.字段.命中段数}, 伤害=${outMiss.字段.伤害}`
  );
  assert(
    outMiss.字段.动作QTE && outMiss.字段.动作QTE.命中段数 === 0 && outMiss.字段.动作QTE.完美段数 === 0,
    '全 MISS 记录字段.动作QTE 正确挂载 (0 命中 / 0 完美)'
  );

  // (b) 注入全 HIT (7/7, 非暴击) vs 全 PERFECT (7/7, 完美暴击加成 100 必暴)
  const qteHit = {
    模式: 'melee_slash',
    各段: Array.from({ length: 7 }, (_, i) => ({ 段号: i + 1, 命中: true, 评价: 'HIT', 暴击: false })),
  };
  const qtePerfect = {
    模式: 'melee_slash',
    各段: Array.from({ length: 7 }, (_, i) => ({ 段号: i + 1, 命中: true, 评价: 'PERFECT' })),
  };

  const prevBonus = G.战斗结构.动作QTE.完美暴击加成;
  G.战斗结构.动作QTE.完美暴击加成 = 100;
  try {
    const pairHit = makeTestPair(20261013);
    const outHit = G.resolveAttack(pairHit.att, pairHit.def, pairHit.w, pairHit.ctx, {
      强制QTE: true,
      qte结果: qteHit,
    });

    const pairPerf = makeTestPair(20261013);
    const outPerf = G.resolveAttack(pairPerf.att, pairPerf.def, pairPerf.w, pairPerf.ctx, {
      强制QTE: true,
      qte结果: qtePerfect,
    });

    assert(
      outHit.字段.命中段数 === 7 && outPerf.字段.命中段数 === 7,
      `全 HIT 与全 PERFECT 均打满 7 段 (HIT段数=${outHit.字段.命中段数}, PERFECT段数=${outPerf.字段.命中段数})`
    );
    assert(
      outPerf.字段.暴击 === 7 && outPerf.字段.伤害 > outHit.字段.伤害,
      `全 PERFECT (7暴击, 总伤=${outPerf.字段.伤害}) 显著高于普通全 HIT (0暴击, 总伤=${outHit.字段.伤害})`
    );
    assert(
      outPerf.字段.动作QTE && outPerf.字段.动作QTE.完美段数 === 7,
      `记录包含 动作QTE 字段且 完美段数 === 7`
    );
  } finally {
    G.战斗结构.动作QTE.完美暴击加成 = prevBonus;
  }
}

// ============================================================================
console.log('\n[5] 开关关闭与默认路径零污染（47 场默认路径记录数严格保持 2788）');
{
  assert(G.动作QTE开() === false && G.战斗结构.动作QTE.开 === false, '默认 战斗结构.动作QTE.开 === false');

  const att = G.makeUnit('CB1', 'ally', 20, 0);
  const def = G.makeUnit('fighter', 'enemy', 20, 0);
  const w = att.weapons[0];
  const ctx = { rng: G.mulberry32(99), turn: 1, allies: [att], enemies: [def], log: [] };
  const normalOut = G.resolveAttack(att, def, w, ctx, {});
  assert(!('动作QTE' in normalOut.字段), '未传 qte结果 时，记录字段绝不挂载 动作QTE 键（零污染）');

  // 跑 47 场默认五人队模拟，核对记录数 === 2788（口径照 tests/commands-1：不下方针 = 全军突击）
  const prevEnemyMech = G.战斗结构.敌人机制.开;
  G.战斗结构.敌人机制.开 = false;
  let totalLogs = 0;
  try {
    for (const entry of G.编成表) {
      const res = G.simulate(
        G.默认五人队,
        G.敌方规格组(G.编成到单位(entry, 0)),
        {},
        20261010,
        { 波次: G.编成波次到单位(entry, 0) }
      );
      totalLogs += res.记录.length;
    }
  } finally {
    G.战斗结构.敌人机制.开 = prevEnemyMech;
  }
  assert(totalLogs === 2788, `47 场默认路径总记录数严格保持 2788 (实测=${totalLogs})`);
}

// ============================================================================
console.log('\n[6] 确定性验证（同种子、同输入轨迹运行两遍逐字节相同）');
{
  const run1 = JSON.stringify(QTE.模拟整套七连斩('MIXED', { 种子: 20261013, enemyKey: 'stealth' }));
  const run2 = JSON.stringify(QTE.模拟整套七连斩('MIXED', { 种子: 20261013, enemyKey: 'stealth' }));
  assert(run1 === run2 && run1.length > 100, `同种子同轨迹两遍 JSON 逐字节相同 (length=${run1.length})`);
}

// ============================================================================
if (fails > 0) {
  console.log(`\nFAILED (${fails}): ${errs.join(' | ')}`);
  process.exit(1);
} else {
  console.log('\n=== 全部 6 项动作 QTE 断言通过 (0 失败) ===');
}
