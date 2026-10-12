/* ============================================================================
 * 调参室（作者亲手调难度）· 模型层
 * ----------------------------------------------------------------------------
 * 规格书 = `协作/方向调整-全队方针与反馈.md` **第 3 节**（§3.1–§3.6，作者 2026-10-12 拍板）。
 * 界面层在同一份文件的后半段（`界面.调参室屏` + `调参室动作()`）；**这一层不碰 DOM**，
 * 所以 Node 里（`tests/tuner.js`、`tools/`）可以直接调它、与 `simulate()` 逐场对账。
 *
 * 【§3.6 第 6 条：注入口（硬约束）】
 *   倍率**不许**写进 `71-改动.js` 的正式表（那会污染正常游戏与「同种子逐字不变」）。
 *   唯一的注入口 = `开局(我方, 敌方, 种子, 单位开关表, 选项)` 的 **`选项.调参`**：
 *
 *     选项.调参 = {
 *       敌人:     { HP倍率, 伤害倍率, 装甲倍率, 防御加成 },        // 全局四项（默认 1 / 1 / 1 / 0）
 *       覆盖:     { 敌人键: { HP倍率, 装甲倍率, 威力倍率 } },       // 按敌人键 **取代** 全局那一项
 *       Boss:     { 敌人键: { 大技能间隔, 伤害倍率, 阶段间隔, 阶段倍率 } },   // Boss 脚本覆盖
 *       回合上限: 数字 | undefined,                                // 不写 = 照引擎自己那套（难度调整.回合上限）
 *     }
 *
 *   四个量各自落在哪（**落点都不改公式本体**）：
 *     · HP ×        → `u.maxHp`（与 `u.hp` 同比缩放），在 `开局()` / `增援()` 造完单位之后；
 *     · 装甲 ×      → `u.armor`；
 *     · 防御值 +    → `u.defense`（**加法**，照 §3.3 的「防御值 +」）；
 *     · 伤害 ×      → `u.调参伤害倍率`，在 `60-战斗.js` 的 `resolveAction()` 里
 *                     **和「Boss 阶段倍率」「势力伤害倍率」挤在同一个口子**（公式之后逐段相乘）；
 *     · 威力倍率（按敌人键）→ 那一台的武器副本 `e.t.power` / `upgrades[].power`（进 `dmgCore()` 之前）；
 *     · Boss 脚本覆盖 → `u.调参Boss`（`61-Boss.js` 的 `取Boss脚本()` 优先读它）；
 *     · 回合上限    → `ctx.回合上限`（`打一回合()` 本来就读它；`simulate()` 的护栏跟着放宽）。
 *   ★ **没传 `选项.调参` 时**，上面这些字段一个都不会出现，代码路径与改动前逐字相同
 *     （`tests/tuner.js` 第 [1] 段 + 仓库外「调参室前快照」`F:\DSH-mecha\_probe\调参室前快照.json`）。
 *
 * 【§3.5：存与交回】
 *   · 改动存 `localStorage`，键 **`mecha-autobattle-tune`**；**只在调参室里生效**（正常游戏读都不读它）；
 *   · 「复制设置」= 人话改动清单 + JSON（`调参导出文本()`）；JSON 能原样读回（`调参读回文本()`）；
 *   · 「恢复默认」= `调参默认设置()`（四项 1 / 1 / 1 / 0）。
 *
 * 【随机数】调参室自己**一处 `Math.random` 都没有**：种子从 1 开始连续（§3.2），
 *   抽条目、跑批全部按种子现算（同一设置跑两遍逐字相同）。
 * ========================================================================== */

/* ---------- 常量 ---------- */
const 调参存档键 = 'mecha-autobattle-tune';
const 调参版本 = 1;
/** §3.2 的节点类型（界面上的 6 个按钮）；后四个直接对应 `编成表` 里的 `类型`，
 *  「终点」= **第 4 层的 Boss**（蓝色大肥鱼那一档，层选择对它无效）。 */
const 调参节点类型们 = ['普通', '精英', '侵蚀源', '守军', 'Boss', '终点'];
/** 方针的可选项（§3.2 第一版只有两种：整场固定一条 / 简单策略）。 */
const 调参简单策略 = '简单策略：第 1 回合全军防御 → 之后全军突击';
const 调参方针们 = () => 方针们.concat([调参简单策略]);
/** 界面上滑条的范围（**只影响界面**，引擎侧只认最终数值）。 */
const 调参倍率范围 = { 最小: 0.5, 最大: 5, 步: 0.05 };
const 调参防御加成范围 = { 最小: 0, 最大: 500, 步: 5 };
const 调参回合上限范围 = { 最小: 0, 最大: 30, 步: 1 };      // 0 = 默认（照引擎自己那套）
const 调参场次们 = [20, 100, 200];
const 调参默认场次 = 100;
const 调参每批场次 = 10;          // §3.4：每批 10 场让出一次主线程
const 调参出击上限 = 6;           // §3.2：从全角色里挑 3–6 台（调参室里固定 6，不跟着等级走）

/* ---------- 默认设置（§3.3 的默认值：1 / 1 / 1 / 0） ---------- */
function 调参默认设置() {
  return {
    版本: 调参版本,
    层: 1,
    类型: '普通',
    条目: null,                 // null = 「这一类全部」；数字 = `编成表` 的下标
    等级: 10,                   // 10 / 20 / 30
    出击: null,                 // null = 默认五人队；否则 [{键, 位}]
    方针: '全军突击',            // 五条方针之一，或 `调参简单策略`
    场次: 调参默认场次,
    种子起: 1,                  // §3.2：种子从 1 开始连续
    敌人: { HP倍率: 1, 伤害倍率: 1, 装甲倍率: 1, 防御加成: 0 },
    覆盖: {},                   // { 敌人键: {HP倍率, 装甲倍率, 威力倍率} }
    Boss: {},                   // { 敌人键: {大技能间隔, 伤害倍率, 阶段间隔, 阶段倍率} }
    回合上限: null,              // null = 引擎默认
  };
}

/* ---------- 规整（异常输入不崩：所有入口都先过这一关） ---------- */
/** 数一下：`null` / `undefined` / `''` / `NaN` 一律当「没写」，返回默认值。
 *  ⚠ 一定要先拦 `null` —— `Number(null) === 0` 会被夹成 0.1（一个真出过的坑）。 */
const 调参数 = (v, 默认, 最小, 最大) => {
  if (v == null || v === '') return 默认;
  const n = Number(v);
  if (!Number.isFinite(n)) return 默认;
  return Math.min(最大, Math.max(最小, n));
};
/** 倍率一项：没写 / 认不出来 → `null`（= **这一项没被覆盖**，用全局）。 */
const 调参倍率项 = v => {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.min(10, Math.max(0.1, n)) : null;
};
const 调参整数 = (v, 默认, 最小, 最大) => Math.round(调参数(v, 默认, 最小, 最大));
const 调参选 = (v, 名单, 默认) => (名单.includes(v) ? v : 默认);
const 调参正对象 = o => (o && typeof o === 'object' && !Array.isArray(o)) ? o : null;

/** 把任何（localStorage 里读回来的 / 作者手打的 JSON / 半截对象）整成一份**合法设置**。 */
function 调参规整(原始) {
  const d = 调参默认设置();
  const o = 调参正对象(原始) || {};
  const 敌 = 调参正对象(o.敌人) || {};
  const 出 = 调参默认设置();
  出.版本 = 调参版本;
  出.层 = 调参整数(o.层, d.层, 1, 4);
  出.类型 = 调参选(o.类型, 调参节点类型们, d.类型);
  出.等级 = 调参选(Number(o.等级), [10, 20, 30], d.等级);
  出.方针 = 调参选(o.方针, 调参方针们(), d.方针);
  出.场次 = 调参整数(o.场次, d.场次, 1, 2000);
  出.种子起 = Math.max(1, 调参整数(o.种子起, d.种子起, 1, 999999));
  出.敌人 = {
    HP倍率: 调参数(敌.HP倍率, 1, 0.1, 10),
    伤害倍率: 调参数(敌.伤害倍率, 1, 0.1, 10),
    装甲倍率: 调参数(敌.装甲倍率, 1, 0.1, 10),
    防御加成: 调参整数(敌.防御加成, 0, -500, 500),
  };
  /* 「这一类全部」= null / '全部' / 认不出来的值 */
  const 条 = Number(o.条目);
  出.条目 = (o.条目 == null || o.条目 === '全部' || !Number.isFinite(条) || 条 < 0 || 条 >= 编成表.length)
    ? null : Math.round(条);
  /* 出击名单：键必须在 ALLY_T 里、位 0–8、不重复、最多 6 台；一个都不合法 → null（用默认五人队） */
  if (Array.isArray(o.出击)) {
    const 用过的键 = new Set(), 用过的位 = new Set(), 名单 = [];
    for (const x of o.出击) {
      const 键 = x && (x.键 || x.key || x.mech);
      const 位 = 调参整数(x && (x.位 != null ? x.位 : x.slot), -1, -1, SLOTS - 1);
      if (!键 || !tplOf(键) || 位 < 0 || 用过的键.has(键) || 用过的位.has(位)) continue;
      if (名单.length >= 调参出击上限) break;
      用过的键.add(键); 用过的位.add(位); 名单.push({ 键, 位 });
    }
    出.出击 = 名单.length ? 名单 : null;
  }
  /* 按敌人键覆盖（键必须在 ENEMY_T 里）。★ **只记真的写了的项** ——
     没写的项在 `应用调参单位()` 里回落成「全局那一项」（不是 1）。 */
  const 覆 = 调参正对象(o.覆盖);
  if (覆) {
    for (const [键, v] of Object.entries(覆)) {
      if (!ENEMY_T[键]) continue;
      const w = 调参正对象(v);
      if (!w) continue;
      const 一条 = {};
      for (const k of ['HP倍率', '装甲倍率', '威力倍率']) {
        const x = 调参倍率项(w[k]);
        if (x != null) 一条[k] = x;
      }
      if (Object.keys(一条).length) 出.覆盖[键] = 一条;
    }
  }
  /* Boss 脚本覆盖（键必须真的在 `Boss脚本` 里；四项都可缺，缺 = 用正式表那一条） */
  const B = 调参正对象(o.Boss);
  if (B) {
    for (const [键, v] of Object.entries(B)) {
      if (!Boss脚本 || !Boss脚本[键]) continue;
      const w = 调参正对象(v);
      if (!w) continue;
      const 一条 = {};
      if (w.大技能间隔 != null) 一条.大技能间隔 = 调参整数(w.大技能间隔, 1, 0, 12);
      if (w.伤害倍率 != null) 一条.伤害倍率 = 调参数(w.伤害倍率, 1, 0.1, 10);
      if (w.阶段间隔 != null) 一条.阶段间隔 = 调参整数(w.阶段间隔, 1, 0, 12);
      if (w.阶段倍率 != null) 一条.阶段倍率 = 调参数(w.阶段倍率, 1, 0.1, 10);
      出.Boss[键] = 一条;
    }
  }
  出.回合上限 = (o.回合上限 == null) ? null : 调参整数(o.回合上限, MAX_TURN, 1, MAX_TURN + 18);
  return 出;
}

/* ============================================================================
 * 二、选战斗（§3.2）：层 × 节点类型 × 具体条目
 * ========================================================================== */

/** 节点类型 → `编成表` 里的类型（只有「终点」是换义：= 第 4 层的 Boss）。 */
const 调参编成类型 = 类型 => (类型 === '终点' ? 'Boss' : 类型);
/** 这一档实际用第几层（「终点」锁第 4 层）。 */
const 调参层 = 设置 => (调参规整(设置).类型 === '终点' ? 4 : 调参规整(设置).层);

/** 这一档的候选条目：`[{ 条目, 下标 }]`（下标 = `编成表` 的全局下标）。 */
function 调参候选(设置) {
  const s = 调参规整(设置);
  const 编成类型 = 调参编成类型(s.类型), 层 = 调参层(s);
  const 出 = [];
  for (let i = 0; i < 编成表.length; i++) {
    const e = 编成表[i];
    if (e.层 === 层 && e.类型 === 编成类型) 出.push({ 条目: e, 下标: i });
  }
  return 出;
}

/** 这一档是否可用（「第 2 层 + Boss」这种组合在 `编成表` 里没有条目）。 */
const 调参这一档有吗 = 设置 => 调参候选(设置).length > 0;

/** 这一场用哪一条：选定就那一条，选「这一类全部」就**按场次轮流**取
 *  （`(第几场 − 1) % 条目数`，决定性、可复现 —— Node 那边对账用同一个规则）。 */
function 调参本场条目(场景, 第几场) {
  const 用们 = 场景.用们;
  if (!用们.length) return null;
  const k = ((Math.max(1, 第几场) - 1) % 用们.length);
  return 用们[k];
}

/** 把设置摊成一次「跑批」的场景：`{ 设置, 候选, 用们 }`。
 *  `用们` = 这一次真的会打的那几条（选了单条就是那一条，否则 = 全部候选）。 */
function 调参场景(原始设置) {
  const 设置 = 调参规整(原始设置);
  const 候选 = 调参候选(设置);
  const 用们 = (设置.条目 != null && 候选.some(x => x.下标 === 设置.条目))
    ? 候选.filter(x => x.下标 === 设置.条目)
    : 候选;
  return { 设置, 候选, 用们 };
}

/** 我方出击名单（`{键, 位, 等级}`）—— 没挑人时 = **默认五人队**（§3.2）。 */
function 调参出击(原始设置) {
  const s = 调参规整(原始设置);
  const 名单 = s.出击 || 默认五人队.map(x => ({ 键: x.键, 位: x.位 }));
  return 名单.map(x => ({ 键: x.键, 位: x.位, 等级: s.等级 }));
}

/* ============================================================================
 * 三、能调的数（§3.3）：把设置翻译成 `选项.调参`（注入口）
 * ========================================================================== */

/** **只把真的改过的项写进去** —— 全默认时返回 `{}`（一个键都没有）。
 *  这样「默认设置跑 100 场」与 `simulate(…, {})` 是**同一条代码路径**（可对账）。 */
function 调参调参对象(原始设置) {
  const s = 调参规整(原始设置);
  const 出 = {};
  const 敌 = s.敌人;
  if (敌.HP倍率 !== 1 || 敌.伤害倍率 !== 1 || 敌.装甲倍率 !== 1 || 敌.防御加成 !== 0) {
    出.敌人 = { HP倍率: 敌.HP倍率, 伤害倍率: 敌.伤害倍率, 装甲倍率: 敌.装甲倍率, 防御加成: 敌.防御加成 };
  }
  if (Object.keys(s.覆盖).length) 出.覆盖 = JSON.parse(JSON.stringify(s.覆盖));
  if (Object.keys(s.Boss).length) 出.Boss = JSON.parse(JSON.stringify(s.Boss));
  if (s.回合上限 != null) 出.回合上限 = s.回合上限;
  return 出;
}

/* ---------- 注入口的另一半：真的落到单位上（`开局()` / `增援()` 调它） ---------- */

/** 把 Boss 脚本覆盖**合并**到正式表那一条上（只覆盖写了的字段；`阶段` 整条替换）。 */
function 调参合并Boss脚本(基础, 覆盖) {
  const 出 = Object.assign({}, 基础 || {});
  if (!覆盖) return 出;
  if (覆盖.大技能间隔 != null) 出.大技能间隔 = 覆盖.大技能间隔;
  if (覆盖.伤害倍率 != null) 出.伤害倍率 = 覆盖.伤害倍率;
  if (覆盖.阶段间隔 != null || 覆盖.阶段倍率 != null) {
    const 旧 = (基础 && Array.isArray(基础.阶段) && 基础.阶段[0]) || {};
    出.阶段 = [Object.assign({}, 旧, {
      触发: 旧.触发 != null ? 旧.触发 : '半血',
      大技能间隔: 覆盖.阶段间隔 != null ? 覆盖.阶段间隔 : 旧.大技能间隔,
      伤害倍率: 覆盖.阶段倍率 != null ? 覆盖.阶段倍率 : 旧.伤害倍率,
    })];
  }
  return 出;
}

/** 把调参落到**一组敌方单位**上（`开局()` 里刚造好的那批 / `增援()` 补进来的那几台）。
 *  ★ 只认 `side === 'enemy'`；**一个数值都没改公式本体**，全部是「这一场临时套上去」的覆盖。 */
function 应用调参单位(单位们, 调参) {
  if (!调参 || !单位们) return 单位们;
  const g = 调参.敌人 || {};
  for (const u of 单位们) {
    if (!u || u.side !== 'enemy') continue;
    const 覆 = (调参.覆盖 && 调参.覆盖[u.key]) || null;
    /* 按敌人键覆盖 = **取代**全局那一项（不是叠加）；**没写的那一项回落成全局**
       （`调参规整()` 只记真的写了的项，所以手写的半截 JSON 也能用）。 */
    const 取值 = (覆项, 全局) => (覆项 != null ? 覆项 : 全局);
    const HP倍率 = 取值(覆 && 覆.HP倍率, 调参数(g.HP倍率, 1, 0.1, 10));
    const 装甲倍率 = 取值(覆 && 覆.装甲倍率, 调参数(g.装甲倍率, 1, 0.1, 10));
    const 威力倍率 = 取值(覆 && 覆.威力倍率, 1);
    const 伤害倍率 = 调参数(g.伤害倍率, 1, 0.1, 10);
    const 防御加成 = 调参整数(g.防御加成, 0, -500, 500);

    if (HP倍率 !== 1) {
      const 旧 = u.maxHp;
      u.maxHp = Math.max(1, Math.round(u.maxHp * HP倍率));
      /* HP 按同一比例缩放（`makeUnit()` 里 HP 继承那一步可能让 hp < maxHp） */
      u.hp = Math.max(1, Math.min(u.maxHp, Math.round(u.hp * (u.maxHp / Math.max(1, 旧)))));
    }
    if (装甲倍率 !== 1) u.armor = Math.max(0, Math.round(u.armor * 装甲倍率));
    if (防御加成 !== 0) u.defense = Math.max(0, (u.defense || 0) + 防御加成);
    if (威力倍率 !== 1) {
      u.weapons = (u.weapons || []).map(e => {
        const t = Object.assign({}, e.t);
        if (t.power > 0) t.power = Math.max(1, Math.round(t.power * 威力倍率));
        if (Array.isArray(t.upgrades)) {
          t.upgrades = t.upgrades.map(up => (up && up.power > 0
            ? Object.assign({}, up, { power: Math.max(1, Math.round(up.power * 威力倍率)) }) : up));
        }
        return Object.assign({}, e, { t });
      });
    }
    if (伤害倍率 !== 1) u.调参伤害倍率 = 伤害倍率;
    /* Boss 脚本覆盖（§3.3 第三项）：只对**正式表里有脚本**的那几种敌人有意义 */
    const bs = 调参.Boss && 调参.Boss[u.key];
    if (bs && Boss脚本 && Boss脚本[u.key]) u.调参Boss = 调参合并Boss脚本(Boss脚本[u.key], bs);
  }
  return 单位们;
}

/** 开局那一次：敌方全体 + 回合上限。`ctx` 是 `60-战斗.js` 的 `开局()` 造好的状态。 */
function 应用调参(ctx, 调参) {
  if (!ctx || !调参) return ctx;
  应用调参单位(ctx.enemies, 调参);
  if (调参.回合上限 != null) ctx.回合上限 = 调参整数(调参.回合上限, ctx.回合上限 || MAX_TURN, 1, MAX_TURN + 18);
  return ctx;
}

/* ============================================================================
 * 四、跑（§3.2 场次 / §3.4 分批跑）
 * ========================================================================== */

/** 方针 → `simulate()` 吃的那个参数（§3.2 第一版就两种：整场固定一条 / 「简单策略」）。 */
function 调参方针(原始设置) {
  const s = 调参规整(原始设置);
  if (s.方针 === 调参简单策略) return { 1: '全军防御', 2: '全军突击' };
  return s.方针;
}

/** 这一场下，界面上该显示的那条方针（按回合取；和 `simulate()` 的口径一致）。 */
const 调参回合方针 = (原始设置, 回合) => 第几回合的方针(调参方针(原始设置), 回合);

function 调参新统计() {
  return {
    总场: 0, 胜场: 0, 胜场回合和: 0, 回合和: 0,
    回合分布: {},          // 回合数 → 几场
    阵亡分布: {},          // 我方阵亡台数 → 几场
    先倒: {},              // 最先倒下的我方 → 几次
    我方伤害: {},          // 我方单位键 → 伤害合计
    敌方伤害: {},          // 敌方单位键 → 伤害合计
    明细: [],              // 逐场（对账用）：{种子, 条目下标, 结果, 回合数, 阵亡, 先倒, 我方伤害合计, 敌方伤害合计, 记录条数}
    错误: null,
  };
}

/** 一场战斗 → 小结（**全部从记录与最终单位读**，不另开一套账）。 */
function 调参一场小结(结果, 种子, 条目下标) {
  const 记录 = (结果 && 结果.记录) || [];
  const 我方伤害 = {}, 敌方伤害 = {};
  let 先倒 = null;
  for (const x of 记录) {
    if (!x) continue;
    const 伤 = Number(x.伤害) || 0;
    if (战报伤害类型.includes(x.类型) && x.伤害 != null) {
      if (x.单位方 === 'ally') 我方伤害[x.单位 || '?'] = (我方伤害[x.单位 || '?'] || 0) + 伤;
      else if (x.单位方 === 'enemy') 敌方伤害[x.单位 || '?'] = (敌方伤害[x.单位 || '?'] || 0) + 伤;
    } else if (x.类型 === '镜甲' && x.单位方 === 'enemy') {
      /* 镜甲反弹：`类型` 不在战报伤害白名单里（`84-反馈.js` 的口径），但**这一份血真的掉了**，
         所以「谁是威胁」这一栏把它算在**带镜甲的那台**头上（口径写在任务板里）。 */
      敌方伤害[x.单位 || '?'] = (敌方伤害[x.单位 || '?'] || 0) + 伤;
    }
    if (先倒 == null && x.目标方 === 'ally' && typeof x.目标剩余HP === 'number' && x.目标剩余HP <= 0) {
      先倒 = x.目标 || (x.目标位 != null ? ('位' + x.目标位) : null);
    }
  }
  let 阵亡 = 0;
  const 我方 = (结果 && 结果.我方) || [];
  for (const u of 我方) if (u.hp <= 0) 阵亡++;
  const 合计 = o => Object.values(o).reduce((a, b) => a + b, 0);
  return {
    种子, 条目下标,
    结果: (结果 && 结果.结果) || '败',
    回合数: (结果 && 结果.回合数) || 0,
    阵亡, 先倒, 我方伤害, 敌方伤害,
    我方伤害合计: 合计(我方伤害), 敌方伤害合计: 合计(敌方伤害),
    记录条数: 记录.length,
  };
}

function 调参并进(统计, 一场) {
  统计.总场++;
  if (一场.结果 === '胜') { 统计.胜场++; 统计.胜场回合和 += 一场.回合数; }
  统计.回合和 += 一场.回合数;
  统计.回合分布[一场.回合数] = (统计.回合分布[一场.回合数] || 0) + 1;
  统计.阵亡分布[一场.阵亡] = (统计.阵亡分布[一场.阵亡] || 0) + 1;
  if (一场.先倒) 统计.先倒[一场.先倒] = (统计.先倒[一场.先倒] || 0) + 1;
  for (const [k, v] of Object.entries(一场.我方伤害)) 统计.我方伤害[k] = (统计.我方伤害[k] || 0) + v;
  for (const [k, v] of Object.entries(一场.敌方伤害)) 统计.敌方伤害[k] = (统计.敌方伤害[k] || 0) + v;
  统计.明细.push({
    种子: 一场.种子, 条目下标: 一场.条目下标, 结果: 一场.结果, 回合数: 一场.回合数,
    阵亡: 一场.阵亡, 先倒: 一场.先倒, 记录条数: 一场.记录条数,
    我方伤害合计: 一场.我方伤害合计, 敌方伤害合计: 一场.敌方伤害合计,
  });
  return 统计;
}

/** **跑一场**：用 `simulate()`（和 Node 里对账用的是同一个函数）。
 *  种子 = `种子起 + (第几场 − 1)`（§3.2：从 1 开始连续）。 */
function 调参跑一场(场景, 第几场) {
  const s = 场景.设置;
  const 条目 = 调参本场条目(场景, 第几场);
  if (!条目) return null;
  const 种子 = s.种子起 + (第几场 - 1);
  const 选项 = { 波次: 编成波次到单位(条目.条目, 0) };
  const 调参 = 调参调参对象(s);
  if (Object.keys(调参).length) 选项.调参 = 调参;
  const r = simulate(调参出击(s), 敌方规格组(编成到单位(条目.条目, 0)), 调参方针(s), 种子, 选项);
  return 调参一场小结(r, 种子, 条目.下标);
}

/** 跑 `[从, 到)` 这些场（**同步**；界面用的是 `调参分批跑()`，一次只跑一批）。 */
function 调参跑批(场景, 统计, 从, 到) {
  for (let k = 从; k < 到; k++) {
    const 一场 = 调参跑一场(场景, k + 1);
    if (一场) 调参并进(统计, 一场);
  }
  return 统计;
}

/** ★ §3.4 的硬要求：**跑 100 场不卡死** —— 分批跑（默认每批 10 场），每批之后把主线程让出去。
 *  返回一个句柄：`{ 场景, 统计, 进度, 总场, 完, 继续(), 错误 }`。
 *  · 界面：`setTimeout(句柄.继续, 0)`（`每批后` 回调里排下一批）；
 *  · 测试 / Node：直接反复调 `句柄.继续()`（本机测试的 DOM 替身里 `setTimeout` 是空转的，
 *    所以「分批的进度与总场数」必须能**手工驱动**才测得出来）。 */
function 调参分批跑(原始设置, 每批, 每批后) {
  const 场景 = 调参场景(原始设置);
  const 批 = Math.max(1, Math.round(Number(每批) || 调参每批场次));
  const 句柄 = {
    场景, 统计: 调参新统计(), 进度: 0, 总场: 场景.设置.场次, 每批: 批, 完: false, 错误: null, 每批后: 每批后 || null,
  };
  if (!场景.用们.length) {
    句柄.错误 = '这一层没有这个类型的编成（换一层 / 换一个类型）。';
    句柄.完 = true;
    句柄.统计.错误 = 句柄.错误;
    return 句柄;
  }
  句柄.继续 = () => {
    if (句柄.完) return 句柄;
    const 到 = Math.min(句柄.总场, 句柄.进度 + 句柄.每批);
    调参跑批(场景, 句柄.统计, 句柄.进度, 到);
    句柄.进度 = 到;
    if (句柄.进度 >= 句柄.总场) 句柄.完 = true;
    if (句柄.每批后) 句柄.每批后(句柄);
    return 句柄;
  };
  return 句柄;
}

/** 一次跑完（同步；测试 / Node 用，界面**不用**它 —— 界面走 `调参分批跑()`）。 */
function 调参跑完(原始设置, 每批) {
  const 句柄 = 调参分批跑(原始设置, 每批 || 调参每批场次, null);
  let 护栏 = 0;
  while (!句柄.完 && 护栏++ < 100000) 句柄.继续();
  return 句柄;
}

/* ============================================================================
 * 五、看结果里的几个派生量（§3.4）
 * ========================================================================== */
const 调参占比 = (部分, 全部) => (!全部 ? 0 : Math.round(部分 / 全部 * 1000) / 10);

/** 统计 → 界面上那几行（纯派生，不改统计）。 */
function 调参结果摘要(统计) {
  const t = 统计 || 调参新统计();
  const 胜率 = t.总场 ? Math.round(t.胜场 / t.总场 * 1000) / 10 : 0;
  const 胜场平均回合 = t.胜场 ? Math.round(t.胜场回合和 / t.胜场 * 10) / 10 : 0;
  const 平均回合 = t.总场 ? Math.round(t.回合和 / t.总场 * 10) / 10 : 0;
  const 最大回合 = Math.max(MAX_TURN, ...Object.keys(t.回合分布).map(Number).filter(Number.isFinite), 0);
  const 回合分布 = [];
  for (let i = 1; i <= 最大回合; i++) 回合分布.push({ 回合: i, 场数: t.回合分布[i] || 0 });
  const 阵亡最大 = Math.max(0, ...Object.keys(t.阵亡分布).map(Number).filter(Number.isFinite));
  const 阵亡分布 = [];
  for (let i = 0; i <= 阵亡最大; i++) 阵亡分布.push({ 阵亡: i, 场数: t.阵亡分布[i] || 0 });
  const 排序 = o => Object.entries(o).map(([键, 值]) => ({ 键, 值 })).sort((a, b) => b.值 - a.值 || (a.键 < b.键 ? -1 : 1));
  const 我方总 = Object.values(t.我方伤害).reduce((a, b) => a + b, 0);
  const 敌方总 = Object.values(t.敌方伤害).reduce((a, b) => a + b, 0);
  return {
    总场: t.总场, 胜场: t.胜场, 胜率, 胜场平均回合, 平均回合,
    回合分布, 阵亡分布,
    先倒: 排序(t.先倒),
    我方伤害: 排序(t.我方伤害).map(x => Object.assign(x, { 占比: 调参占比(x.值, 我方总) })),
    敌方伤害: 排序(t.敌方伤害).map(x => Object.assign(x, { 占比: 调参占比(x.值, 敌方总) })),
    我方伤害合计: 我方总, 敌方伤害合计: 敌方总,
  };
}

/* ============================================================================
 * 六、存与交回（§3.5）：localStorage + 复制设置 + 恢复默认
 * ========================================================================== */

/** 读 localStorage（读不到 / 坏 JSON / 没这个环境 → null，**绝不抛**）。 */
function 调参读存档() {
  try {
    if (typeof localStorage === 'undefined' || !localStorage) return null;
    const t = localStorage.getItem(调参存档键);
    if (!t) return null;
    return 调参规整(JSON.parse(t));
  } catch (e) { return null; }
}
function 调参写存档(设置) {
  try {
    if (typeof localStorage === 'undefined' || !localStorage) return false;
    localStorage.setItem(调参存档键, JSON.stringify(调参规整(设置)));
    return true;
  } catch (e) { return false; }
}
function 调参清存档() {
  try { if (typeof localStorage !== 'undefined' && localStorage) localStorage.removeItem(调参存档键); return true; }
  catch (e) { return false; }
}

/** 人话改动清单（§3.5：「复制设置」= 人话改动清单 + JSON）。 */
function 调参改动清单(原始设置) {
  const s = 调参规整(原始设置);
  const 行 = [];
  const 敌 = s.敌人;
  const 有敌 = 敌.HP倍率 !== 1 || 敌.伤害倍率 !== 1 || 敌.装甲倍率 !== 1 || 敌.防御加成 !== 0;
  行.push(`· 敌人全局倍率：${有敌
    ? `HP ×${敌.HP倍率}、伤害 ×${敌.伤害倍率}、装甲 ×${敌.装甲倍率}、防御值 ${敌.防御加成 >= 0 ? '+' : ''}${敌.防御加成}`
    : '默认（HP ×1 / 伤害 ×1 / 装甲 ×1 / 防御值 +0，没改）'}`);
  const 覆键 = Object.keys(s.覆盖);
  行.push(`· 按敌人键覆盖：${覆键.length
    ? 覆键.map(k => {
      const c = s.覆盖[k];
      /* 只列**真的写了的项**（没写的回落成全局，不在这儿重复一遍） */
      const 项 = ['HP倍率', '装甲倍率', '威力倍率'].filter(x => c[x] != null).map(x => `${x.replace('倍率', '')} ×${c[x]}`);
      return `${k}（${项.join('、') || '空'}）`;
    }).join('；')
    : '没有'}`);
  const B键 = Object.keys(s.Boss);
  行.push(`· Boss 脚本：${B键.length
    ? B键.map(k => {
      const b = s.Boss[k], 基础 = (Boss脚本 && Boss脚本[k]) || {};
      return `${k}（大技能间隔 ${b.大技能间隔 != null ? b.大技能间隔 : 基础.大技能间隔}、伤害倍率 ×${b.伤害倍率 != null ? b.伤害倍率 : 基础.伤害倍率}`
        + `、半血阶段间隔 ${b.阶段间隔 != null ? b.阶段间隔 : (基础.阶段 && 基础.阶段[0] ? 基础.阶段[0].大技能间隔 : '—')}`
        + `、阶段倍率 ×${b.阶段倍率 != null ? b.阶段倍率 : (基础.阶段 && 基础.阶段[0] ? 基础.阶段[0].伤害倍率 : '—')}）`;
    }).join('；')
    : '没有（照正式表）'}`);
  行.push(`· 回合上限：${s.回合上限 != null ? `${s.回合上限}（只在调参室里生效）` : '默认（照引擎按档位那套）'}`);
  const 候选 = 调参候选(s);
  行.push(`· 关卡：第 ${调参层(s)} 层 ${s.类型}（${候选.length} 条；`
    + `${s.条目 != null && 候选.some(x => x.下标 === s.条目) ? `只打第 ${s.条目} 条` : '这一类全部'}）`);
  const 出击 = 调参出击(s);
  行.push(`· 我方：Lv${s.等级} ${出击.map(x => `${调参单位名(x.键)}@${位名(x.位)}`).join('、')}（共 ${出击.length} 台）`);
  行.push(`· 方针：${s.方针}`);
  行.push(`· 场次 ${s.场次}（种子 ${s.种子起} – ${s.种子起 + s.场次 - 1}，连续）`);
  return 行;
}
/** 出击名单里那一台的机师名（拿不到就退回键）。 */
function 调参单位名(键) {
  const t = tplOf(键);
  return (t && (t.pilot || t.mech)) || 键;
}

/** §3.5 的「复制设置」：一段文字 = 人话清单 + JSON（JSON 能被 `调参读回文本()` 读回）。 */
function 调参导出文本(原始设置) {
  const s = 调参规整(原始设置);
  return '【调参室 · 改动清单】（作者把这段发给 Claude / DSH；下面的 JSON 可以原样读回）\n'
    + 调参改动清单(s).join('\n')
    + '\n\n【调参室 JSON（键 ' + 调参存档键 + '，可直接读回）】\n'
    + JSON.stringify(s, null, 2);
}

/** 把导出的那段文字读回来（只认第一个 `{` 到最后一个 `}`；认不出来 → null，不抛）。 */
function 调参读回文本(文本) {
  const t = String(文本 == null ? '' : 文本);
  const i = t.indexOf('{'), j = t.lastIndexOf('}');
  if (i < 0 || j <= i) return null;
  try { return 调参规整(JSON.parse(t.slice(i, j + 1))); } catch (e) { return null; }
}

/* ---------- 模型对象（界面与测试都读它；**它自己不碰 DOM**） ---------- */
const 调参室模型 = {
  键: 调参存档键,
  版本: 调参版本,
  设置: 调参默认设置(),
  结果: null,               // 最近一次跑批的句柄
  导出文本: null,           // 「复制设置」上一次导出的那段文字（界面上画在 textarea 里）
  读回框: '',               // 界面上那个「读回」文本框里的内容（测试可以自己塞）
  提示: '',
  默认: 调参默认设置,
  规整: 调参规整,
  当前调参() { return 调参调参对象(this.设置); },
  /** 改设置（补丁）→ 存 localStorage → 返回规整后的设置 */
  设(补丁) {
    const o = (补丁 && typeof 补丁 === 'object') ? 补丁 : {};
    const 深 = k => (o[k] && typeof o[k] === 'object' && !Array.isArray(o[k]))
      ? Object.assign({}, this.设置[k], o[k]) : o[k];
    const 新 = Object.assign({}, this.设置, o, {
      敌人: 深('敌人') || this.设置.敌人,
      覆盖: 深('覆盖') || this.设置.覆盖,
      Boss: 深('Boss') || this.设置.Boss,
    });
    this.设置 = 调参规整(新);
    this.提示 = '';
    调参写存档(this.设置);
    return this.设置;
  },
  载入() { const s = 调参读存档(); if (s) this.设置 = s; return this.设置; },
  保存() { return 调参写存档(this.设置); },
  恢复默认() {
    this.设置 = 调参默认设置();
    this.结果 = null; this.导出文本 = null; this.读回框 = ''; this.提示 = '';
    调参清存档();
    return this.设置;
  },
  清结果() { this.结果 = null; this.导出文本 = null; return null; },
  场景() { return 调参场景(this.设置); },
  统计() { return (this.结果 && this.结果.统计) || 调参新统计(); },
  /** 同步跑一次（测试 / Node 用） */
  跑完() { this.结果 = 调参跑完(this.设置); return this.结果; },
  /** 分批跑（界面用；`每批后` 里排下一批） */
  分批跑(每批后) { this.结果 = 调参分批跑(this.设置, 调参每批场次, 每批后); return this.结果; },
  导出() { this.导出文本 = 调参导出文本(this.设置); return this.导出文本; },
  读回(文本) {
    const s = 调参读回文本(文本 != null ? 文本 : this.读回框);
    if (!s) { this.提示 = '读不回来：没找到能认的调参 JSON。'; return null; }
    this.设置 = s; this.结果 = null; this.导出文本 = null; this.读回框 = ''; this.提示 = '';
    调参写存档(s);
    return s;
  },
};

/* ============================================================================
 * 七、界面层（§3.1：**左选战斗 / 中调数 / 右看结果**）
 * ----------------------------------------------------------------------------
 * 全部画在一块 `界面.调参室屏()` 里（3 列），动作走 `data-act="调参室:<子动作>"`
 * （`80-界面.js` 的动作表里只多一个转发口 `调参室`）。
 * 滑条（`<input type="range" data-tune="…">`）走**自己的**事件委托：`input` 时只改模型 + 改那个数字，
 * **不整屏重画**（否则拖动会被打断）；`change`（松手）时才重画一次。
 * 自己挑人 / 摆位直接复用现成的编队交互（`data-act="选人:" / "放位:" / "取回:"` + `data-drag` / `data-drop`）——
 * 调参模式下 `界面.当前出击上限()` 固定 6（§3.2「从全角色里挑 3–6 台」）。
 * ========================================================================== */

/** 一个滑条（`data-tune` = `"路径:键"`，例如 `敌人:HP倍率` / `覆盖:captain:HP倍率`）。
 *  `范围` 里的 `最小 / 最大 / 步` 决定 input 的属性，`值` 是当前值。 */
function 调参滑条Html(路径, 标签, 值, 范围, 后缀) {
  const v = Number(值);
  return `<div class="tune-row" data-tune-row="${路径}">
    <label>${标签}</label>
    <input type="range" data-tune="${路径}" min="${范围.最小}" max="${范围.最大}" step="${范围.步}" value="${v}">
    <span class="val" data-tune-val="${路径}">${v}${后缀 || ''}</span>
  </div>`;
}

/** 调参室里那一块「我方出击」：等级 + 势力筛选 + 候选 + 9 格（复用编队交互）。 */
function 调参编队Html(界面对象) {
  const B = 界面对象.编队;
  const 势力们 = ['全部'].concat(FACTIONS);
  const 候选 = ALLY_T.filter(t => B.势力 === '全部' || inFaction(t, B.势力));
  const 列表 = 候选.filter(t => t && t.mech).map(t => {
    const p = 界面对象.预览(t.mech, B.等级);
    const 已上 = B.出击.some(x => x.键 === t.mech);
    return `<button class="pick${B.选中 === t.mech ? ' on' : ''}${已上 ? ' used' : ''}" data-act="选人:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}">
      <span class="pk-top"><span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
      <span class="nums">速 ${p.速度} · HP ${p.hp}</span></button>`;
  }).join('');
  const 行格 = new Map();
  for (let r = ROWS - 1; r >= 0; r--) {
    for (let c = 0; c < 行列数(r); c++) {
      const 位 = slotOf(r, c);
      if (!行格.has(r)) 行格.set(r, []);
      const 占 = B.出击.find(x => x.位 === 位);
      if (占) {
        const p = 界面对象.预览(占.键, B.等级);
        行格.get(r).push(`<button class="slot filled" data-act="取回:${位}" data-drag="位:${位}" data-drop="${位}" style="--fc:${势力色(占.键)}">
          <span class="pos">${位名(位)}</span><span class="pk-top"><span class="pk-nm"><b>${界面对象.单位名(占.键, 'ally')}</b><small>${占.键} · 速 ${p.速度}</small></span></span>
          <span class="nums">HP ${p.hp}</span></button>`);
      } else {
        行格.get(r).push(`<button class="slot" data-act="放位:${位}" data-drop="${位}"><span class="pos">${位名(位)}</span><b>空位</b><small>${行名(r)}</small></button>`);
      }
    }
  }
  const 格 = [...行格.entries()].map(([r, 列表2]) => `<div class="row" style="--cols:${最大列数}">${列表2.join('')}</div>`).join('');
  return `<h4>我方（${B.出击.length} / ${调参出击上限}）<span class="small">拖到格子里，或点一名再点格子</span></h4>
    <div class="filters">
      ${[10, 20, 30].map(n => `<button class="mini${B.等级 === n ? ' on' : ''}" data-act="等级:${n}">Lv${n}</button>`).join('')}
      <span class="sep"></span>
      ${势力们.map(f => `<button class="mini${B.势力 === f ? ' on' : ''}" data-act="势力:${f}">${f}</button>`).join('')}
    </div>
    <div class="acts"><button data-act="默认五人队">默认五人队</button><button data-act="清空">清空</button></div>
    <div class="tune-grid">${格}</div>
    <div class="picks">${列表}</div>`;
}

/** 左列：选战斗（§3.2）。 */
function 调参左列Html(界面对象) {
  const s = 调参室模型.设置;
  const 候选 = 调参候选(s);
  const 层按钮 = [1, 2, 3, 4].map(k =>
    `<button class="mini${s.层 === k ? ' on' : ''}" data-act="调参室:层:${k}">第 ${k} 层</button>`).join('');
  const 类型按钮 = 调参节点类型们.map(t => {
    const 数 = 调参候选(Object.assign({}, s, { 类型: t })).length;
    const 现 = s.类型 === t;
    return `<button class="mini${现 ? ' on' : ''}" data-act="调参室:类型:${t}"${数 ? '' : ' disabled'}
      title="${数 ? `${数} 条编成` : '这一层没有这个类型的编成'}">${t}${数 ? `（${数}）` : '（—）'}</button>`;
  }).join('');
  const 条目按钮 = [`<button class="mini${s.条目 == null ? ' on' : ''}" data-act="调参室:条目:全部">这一类全部（${候选.length} 条）</button>`]
    .concat(候选.map(x => {
      const 选中 = s.条目 === x.下标;
      const 名 = `第${x.条目.层}层 ${x.条目.类型} #${x.下标}｜前 ${(x.条目.前 || []).join('+') || '—'} / 后 ${(x.条目.后 || []).join('+') || '—'}`;
      return `<button class="mini${选中 ? ' on' : ''}" data-act="调参室:条目:${x.下标}" title="${x.条目.考点 || ''}">${名}</button>`;
    })).join('');
  const 方针钮 = 调参方针们().map(p =>
    `<button class="mini${s.方针 === p ? ' on' : ''}" data-act="调参室:方针:${encodeURIComponent(p)}">${p === 调参简单策略 ? '简单策略（第 1 回合全军防御 → 之后全军突击）' : p}</button>`).join('');
  return `<div class="col">
    <h3>① 选战斗</h3>
    <h4>层</h4><div class="cmds">${层按钮}</div>
    <h4>节点类型</h4><div class="cmds">${类型按钮}</div>
    <h4>具体编成条目</h4><div class="cmds">${条目按钮}</div>
    ${候选.length ? '' : '<p class="warn small">这一层没有这个类型的编成：换一层或换一个类型。</p>'}
    <p class="small">${s.类型 === '终点'
      ? '「终点」= **第 4 层**的 Boss（蓝色大肥鱼那一档），层选择对它无效。'
      : `第 ${s.层} 层 ${s.类型}：${候选.length} 条编成（选「这一类全部」时，按场次轮着抽：第 1 场第 1 条、第 2 场第 2 条…）。`}</p>
    <h4>方针（整场）</h4><div class="cmds">${方针钮}</div>
    ${调参编队Html(界面对象)}
  </div>`;
}

/** 中列：调数（§3.3）。 */
function 调参中列Html() {
  const s = 调参室模型.设置;
  const 敌 = s.敌人;
  const 覆盖键 = Object.keys(s.覆盖);
  const Boss键 = Object.keys(Boss脚本 || {});
  const 覆盖行 = 覆盖键.map(k => {
    const c = s.覆盖[k];
    return `<div class="tune-row"><label>${k}</label>
      <span class="small">HP ×${c.HP倍率}、装甲 ×${c.装甲倍率}、威力 ×${c.威力倍率}</span>
      <button class="mini" data-act="调参室:覆盖去掉:${k}">去掉</button></div>`;
  }).join('');
  const Boss行 = Boss键.map(k => {
    const b = s.Boss[k] || {};
    const 基础 = Boss脚本[k] || {};
    const 阶段 = (基础.阶段 && 基础.阶段[0]) || {};
    return `<div class="tune-card">
      <h4>${k}<span class="small">（正式表：间隔 ${基础.大技能间隔}、倍率 ×${基础.伤害倍率}；半血后 ${阶段.大技能间隔} / ×${阶段.伤害倍率}）</span></h4>
      ${调参滑条Html(`Boss:${k}:大技能间隔`, '大技能间隔', b.大技能间隔 != null ? b.大技能间隔 : 基础.大技能间隔, { 最小: 0, 最大: 12, 步: 1 }, ' 回合')}
      ${调参滑条Html(`Boss:${k}:伤害倍率`, '伤害倍率', b.伤害倍率 != null ? b.伤害倍率 : 基础.伤害倍率, 调参倍率范围, '×')}
      ${调参滑条Html(`Boss:${k}:阶段间隔`, '半血后间隔', b.阶段间隔 != null ? b.阶段间隔 : (阶段.大技能间隔 != null ? 阶段.大技能间隔 : 0), { 最小: 0, 最大: 12, 步: 1 }, ' 回合')}
      ${调参滑条Html(`Boss:${k}:阶段倍率`, '半血后倍率', b.阶段倍率 != null ? b.阶段倍率 : (阶段.伤害倍率 != null ? 阶段.伤害倍率 : 1), 调参倍率范围, '×')}
      <div class="acts"><button class="mini" data-act="调参室:Boss清:${k}">这一台恢复正式表</button></div>
    </div>`;
  }).join('');
  const 敌人键们 = Object.keys(ENEMY_T).sort();
  const 当前键 = 调参室模型.选中敌人键 && ENEMY_T[调参室模型.选中敌人键] ? 调参室模型.选中敌人键 : 敌人键们[0];
  /* 「待加」的草稿优先（拖滑条时还没按「加上」；不然一重画就跳回旧值）。
     草稿的起点 = **当前的全局值**（这样「加上覆盖」在没拖之前是个空操作）。 */
  const 覆盖底 = (调参室模型.草稿 || {})[当前键] || s.覆盖[当前键]
    || { HP倍率: s.敌人.HP倍率, 装甲倍率: s.敌人.装甲倍率, 威力倍率: 1 };
  const 场次钮 = 调参场次们.map(n =>
    `<button class="mini${s.场次 === n ? ' on' : ''}" data-act="调参室:场次:${n}">${n} 场</button>`).join('');
  return `<div class="col">
    <h3>② 调数</h3>
    <h4>敌人全局倍率<span class="small">（默认 1 / 1 / 1 / 0）</span></h4>
    ${调参滑条Html('敌人:HP倍率', 'HP ×', 敌.HP倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:伤害倍率', '伤害 ×', 敌.伤害倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:装甲倍率', '装甲 ×', 敌.装甲倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:防御加成', '防御值 +', 敌.防御加成, 调参防御加成范围, '')}
    <p class="small">「伤害 ×」作用在**公式之后**的敌方伤害上（和 Boss 阶段倍率同一个口子）；「防御值 +」是**加法**。</p>

    <h4>按敌人键覆盖<span class="small">（取代全局那一项，不是叠加）</span></h4>
    <select class="sel" data-act="调参室:选敌人键">${敌人键们.map(k =>
      `<option value="${k}"${k === 当前键 ? ' selected' : ''}>${k}${ENEMY_T[k].mech ? ` · ${ENEMY_T[k].mech}` : ''}（${tierOfEnemy(k)}）</option>`).join('')}</select>
    ${调参滑条Html(`覆盖底:${当前键}:HP倍率`, 'HP ×', 覆盖底.HP倍率, 调参倍率范围, '×')}
    ${调参滑条Html(`覆盖底:${当前键}:装甲倍率`, '装甲 ×', 覆盖底.装甲倍率, 调参倍率范围, '×')}
    ${调参滑条Html(`覆盖底:${当前键}:威力倍率`, '威力 ×', 覆盖底.威力倍率, 调参倍率范围, '×')}
    <div class="acts"><button class="mini" data-act="调参室:覆盖加上:${当前键}">加上「${当前键}」的覆盖</button></div>
    ${覆盖行 || '<p class="small">还没有任何按键覆盖。</p>'}

    <h4>Boss 脚本</h4>
    ${Boss行 || '<p class="small">正式表里没有 Boss 脚本。</p>'}

    <h4>回合上限<span class="small">（只在调参室里生效）</span></h4>
    ${调参滑条Html('回合上限', '上限', s.回合上限 != null ? s.回合上限 : 0, 调参回合上限范围, '')}
    <p class="small">0 = 用引擎自己那套（按敌方档位：杂兵/精锐 12、头目 11、Boss 11）。</p>

    <h4>场次</h4><div class="cmds">${场次钮}</div>
    <p class="small">种子从 1 开始连续（第 1 场种子 ${s.种子起}，共 ${s.场次} 场 → 到 ${s.种子起 + s.场次 - 1}）。</p>
    <div class="acts">
      <button class="primary" data-act="调参室:跑">跑 ${s.场次} 场</button>
      <button data-act="调参室:清结果">清空结果</button>
      <button data-act="调参室:存储存">存进 localStorage</button>
      <button data-act="调参室:恢复默认">恢复默认</button>
    </div>
    <p class="small">存 localStorage（键 <code>${调参存档键}</code>），**只在调参室里生效**，正常游戏读都不读它。</p>
  </div>`;
}

/** 结果区里那一行「键 / 名 / 数字 / 占比 + 条形」。 */
function 调参条形行(名, 值, 占比, 最大) {
  const w = 最大 > 0 ? Math.round(值 / 最大 * 100) : 0;
  return `<div class="stat"><span class="nm">${名}</span><span class="n">${值}</span><span class="pc">${占比 != null ? 占比 + '%' : ''}</span></div>
    <div class="bar2"><i style="width:${w}%"></i></div>`;
}

/** 右列：看结果（§3.4）。 */
function 调参右列Html() {
  const s = 调参室模型.设置;
  const 句柄 = 调参室模型.结果;
  const 统计 = (句柄 && 句柄.统计) || 调参新统计();
  const 摘要 = 调参结果摘要(统计);
  const 进度 = 句柄 ? `${句柄.进度} / ${句柄.总场}` : `0 / ${s.场次}`;
  const 进度百 = 句柄 && 句柄.总场 ? Math.round(句柄.进度 / 句柄.总场 * 100) : 0;
  const 分布行 = 摘要.回合分布.map(x => 调参条形行(`${x.回合} 回合`, x.场数, null, Math.max(1, ...摘要.回合分布.map(y => y.场数)))).join('');
  const 阵亡行 = 摘要.阵亡分布.map(x => 调参条形行(`${x.阵亡} 台`, x.场数, null, Math.max(1, ...摘要.阵亡分布.map(y => y.场数)))).join('');
  const 先倒最大 = 摘要.先倒.length ? 摘要.先倒[0].值 : 1;
  const 先倒行 = 摘要.先倒.slice(0, 6).map(x => 调参条形行(`${调参单位名(x.键)}（${x.键}）`, x.值, null, 先倒最大)).join('');
  const 我伤最大 = 摘要.我方伤害.length ? 摘要.我方伤害[0].值 : 1;
  const 我伤行 = 摘要.我方伤害.slice(0, 8).map(x => 调参条形行(`${调参单位名(x.键)}（${x.键}）`, x.值, x.占比, 我伤最大)).join('');
  const 敌伤最大 = 摘要.敌方伤害.length ? 摘要.敌方伤害[0].值 : 1;
  const 敌伤行 = 摘要.敌方伤害.slice(0, 8).map(x =>
    `<div class="stat"><span class="nm">${ENEMY_T[x.键] ? ENEMY_T[x.键].mech : x.键}（${x.键}）</span><span class="n">${x.值}</span><span class="pc">${x.占比}%</span></div>
     <div class="bar2"><i style="width:${Math.round(x.值 / Math.max(1, 敌伤最大) * 100)}%"></i></div>`).join('');
  const 导出块 = 调参室模型.导出文本
    ? `<textarea data-tune="导出文本" readonly>${调参室模型.导出文本}</textarea>`
    : '<p class="small">点「复制设置」会在这里给出一段文字（人话改动清单 + JSON），发给我就行。</p>';
  return `<div class="col">
    <h3>③ 看结果</h3>
    ${句柄 && 句柄.错误 ? `<p class="warn small">${句柄.错误}</p>` : ''}
    <div class="tune-row"><label>进度</label><span class="small" data-tune-progress="1">${进度}（每批 ${调参每批场次} 场让出一次主线程）</span></div>
    <div class="bar2"><i style="width:${进度百}%"></i></div>
    <p class="small">${统计.总场 ? `这一批真的跑完 ${统计.总场} 场` : `还没跑（点中间的「跑 ${s.场次} 场」）`}</p>
    ${统计.总场 ? `
      <div class="tune-card">
        <h4>胜负</h4>
        <p><b>胜率 ${摘要.胜率}%</b>（${摘要.胜场} / ${摘要.总场}）　胜场平均回合 <b>${摘要.胜场平均回合}</b>　总平均 ${摘要.平均回合}</p>
      </div>
      <div class="tune-card"><h4>回合数分布</h4>${分布行}</div>
      <div class="tune-card"><h4>每场我方阵亡数</h4>${阵亡行}</div>
      <div class="tune-card"><h4>最常先倒下的是谁</h4>${先倒行 || '<p class="small">一场都没倒人。</p>'}</div>
      <div class="tune-card"><h4>我方每台伤害占比<span class="small">（合计 ${摘要.我方伤害合计}）</span></h4>${我伤行 || '<p class="small">没有输出记录。</p>'}</div>
      <div class="tune-card"><h4>敌方每台对我方的伤害占比<span class="small">（谁是威胁；合计 ${摘要.敌方伤害合计}）</span></h4>${敌伤行 || '<p class="small">没挨打。</p>'}</div>
    ` : ''}
    <div class="tune-card">
      <h4>看一场<span class="small">（用正常战斗界面播这一场，带记录）</span></h4>
      <div class="tune-row"><label>种子</label>
        <input type="number" data-tune="看一场种子" min="1" max="999999" value="${调参室模型.看一场种子 || s.种子起}">
        <button class="mini" data-act="看一场">看这一场 ▶</button></div>
      <p class="small">「这一类全部」时看的是第一条（${(调参候选(s)[0] || { 下标: '—' }).下标}）。看完点「回调参室」回来，结果与设置都还在。</p>
    </div>
    <div class="tune-card">
      <h4>交回给作者 / Claude</h4>
      <div class="acts">
        <button class="primary" data-act="调参室:复制设置">复制设置</button>
        <button data-act="调参室:读回">读回这段文字</button>
      </div>
      ${导出块}
      <div class="tune-row"><label>读回框</label>
        <input type="text" data-tune="读回框" value="" placeholder="把导出的那段文字粘到这里，再点「读回」"></div>
      ${调参室模型.提示 ? `<p class="warn small">${调参室模型.提示}</p>` : ''}
    </div>
  </div>`;
}

/** 调参室这一屏（3 列）。`刷()` 走 `this['调参室屏']()`。 */
界面.调参室屏 = function () {
  调参接线();          // 滑条 / 输入框的事件委托（只接一次，#screen 上）
  return `<section class="调参室屏">${调参左列Html(this)}${调参中列Html()}${调参右列Html()}</section>`;
};

/** 滑条 / 输入框的**事件委托**：`#screen` 只接一次（`刷()` 换 innerHTML 不会丢）。
 *  · `input`  → 只改模型 + 改那个数字（**不重画**，拖动不会被打断）；
 *  · `change` → 改完再重画一次（导出的文字 / 派生显示跟着更新）。 */
function 调参接线() {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  if (!屏 || !屏.addEventListener || 屏._接了调参) return false;
  屏._接了调参 = true;
  const 读 = e => {
    const t = e && e.target;
    if (!t || !t.getAttribute) return null;
    const 路径 = t.getAttribute('data-tune');
    if (!路径) return null;
    const 值 = t.value != null ? t.value : '';
    if (t.tagName === 'INPUT' || t.tagName === 'SELECT') 调参设滑条(路径, 值);
    else if (t.tagName === 'TEXTAREA' && 路径 === '导出文本') 调参室模型.读回框 = 调参室模型.读回框 || '';
    else if (t.tagName === 'TEXTAREA') 调参室模型.读回框 = 值;
    return 路径;
  };
  屏.addEventListener('input', e => { const p = 读(e); if (p) 调参刷数字(p); });
  屏.addEventListener('change', e => { const p = 读(e); if (p) 刷调参屏(); });
  return true;
}

/** 把一个滑条的值写进设置（`路径` 形如 `敌人:HP倍率` / `覆盖底:captain:HP倍率` / `Boss:bluefish:伤害倍率`）。 */
function 调参设滑条(路径, 值) {
  const 段 = String(路径 || '').split(':');
  const 组 = 段[0];
  const 数 = Number(值);
  if (!Number.isFinite(数)) return false;
  if (组 === '敌人') return !!调参室模型.设({ 敌人: { [段[1]]: 数 } });
  if (组 === '覆盖底') {
    const 键 = 段[1];
    if (!ENEMY_T[键]) return false;
    const s0 = 调参室模型.设置;
    const 旧 = 调参室模型.设置.覆盖[键]
      || { HP倍率: s0.敌人.HP倍率, 装甲倍率: s0.敌人.装甲倍率, 威力倍率: 1 };
    /* 只是「待加」的草稿：真的加上要按「加上这一台的覆盖」 */
    调参室模型.草稿 = Object.assign({}, 调参室模型.草稿 || {}, { [键]: Object.assign({}, 旧, { [段[2]]: 数 }) });
    return true;
  }
  if (组 === 'Boss') {
    const 键 = 段[1], 项 = 段[2];
    if (!Boss脚本 || !Boss脚本[键]) return false;
    return !!调参室模型.设({ Boss: { [键]: Object.assign({}, 调参室模型.设置.Boss[键] || {}, { [项]: 数 }) } });
  }
  if (组 === '回合上限') { 调参室模型.设({ 回合上限: 数 > 0 ? 数 : null }); return true; }
  if (组 === '看一场种子') { 调参室模型.看一场种子 = Math.max(1, Math.round(数)); return true; }
  if (组 === '读回框') { 调参室模型.读回框 = String(值); return true; }
  return false;
}

/** `input` 时只改那个数字（不重画）。 */
function 调参刷数字(路径) {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  const el = 屏 && 屏.querySelector ? 屏.querySelector(`[data-tune-val="${路径}"]`) : null;
  if (!el) return false;
  const 段 = String(路径).split(':');
  const 后缀 = (段[段.length - 1] === '防御加成') ? '' : (段[0] === '回合上限' || 段[2] === '大技能间隔' || 段[2] === '阶段间隔') ? ' 回合' : '×';
  el.textContent = String(调参滑条现值(路径)) + 后缀;
  return true;
}

/** 滑条当前该显示的值（从设置里现取）。 */
function 调参滑条现值(路径) {
  const 段 = String(路径).split(':');
  const s = 调参室模型.设置;
  if (段[0] === '敌人') return s.敌人[段[1]];
  if (段[0] === '覆盖底') {
    const 键 = 段[1];
    const s0 = 调参室模型.设置;
    const 草 = (调参室模型.草稿 || {})[键] || s0.覆盖[键]
      || { HP倍率: s0.敌人.HP倍率, 装甲倍率: s0.敌人.装甲倍率, 威力倍率: 1 };
    return 草[段[2]];
  }
  if (段[0] === 'Boss') {
    const 键 = 段[1], 项 = 段[2];
    const b = (s.Boss[键] || {})[项];
    if (b != null) return b;
    const 基础 = Boss脚本[键] || {}, 阶段 = (基础.阶段 && 基础.阶段[0]) || {};
    if (项 === '大技能间隔') return 基础.大技能间隔;
    if (项 === '伤害倍率') return 基础.伤害倍率;
    if (项 === '阶段间隔') return 阶段.大技能间隔 != null ? 阶段.大技能间隔 : 0;
    if (项 === '阶段倍率') return 阶段.伤害倍率 != null ? 阶段.伤害倍率 : 1;
  }
  if (段[0] === '回合上限') return s.回合上限 != null ? s.回合上限 : 0;
  return '';
}

function 刷调参屏() {
  if (界面.屏 === '调参室') 界面.刷();
  return true;
}

/** 调参室的「我方出击」直接把**编队屏那一套状态**（`界面.编队`）当输入 ——
 *  所以要把它同步回设置里（不然点完「放位」跑批用的还是进来时那张名单）。
 *  ★ 只有调参模式（`界面.调参模式`）下才写；**刚好等于默认五人队就写成 `null`**（导出 JSON 保持干净）。 */
function 调参同步编队() {
  if (!界面 || !界面.调参模式 || !界面.编队) return false;
  const 击 = (界面.编队.出击 || []).map(x => ({ 键: x.键, 位: x.位 })).sort((a, b) => a.位 - b.位);
  /* 「清空」之后一台都没有 → 跑批没法跑：**屏幕和设置一起回到默认五人队**（两处不许说两套话）。 */
  if (!击.length) { 界面.默认五人队(); return false; }
  const 默 = 默认五人队.map(x => ({ 键: x.键, 位: x.位 })).sort((a, b) => a.位 - b.位);
  const 是默认 = 击.length === 默.length && 击.every((x, i) => x.键 === 默[i].键 && x.位 === 默[i].位);
  调参室模型.设({ 等级: 界面.编队.等级, 出击: 是默认 ? null : 击 });
  return true;
}
/** 编队那 7 个动作在调参模式下会改到我方名单 → 事后同步一次（正常游戏里这一句立刻返回）。 */
for (const 名 of ['选人', '放位', '取回', '默认五人队', '清空', '等级', '势力']) {
  const 原 = 界面.动作表[名];
  界面.动作表[名] = function (参) { const r = 原.call(this, 参); 调参同步编队(); return r; };
}

/** 进调参室（菜单上那个入口）：载入 localStorage → 开屏。 */
function 去调参室() {
  调参室模型.载入();
  /* 编队区沿用现成的编队交互：默认把「默认五人队」摆上（调参模式下上限固定 6，见 `当前出击上限()`） */
  界面.调参模式 = true;
  界面.编队.等级 = 调参室模型.设置.等级;
  if (调参室模型.设置.出击) 界面.编队.出击 = 调参室模型.设置.出击.map(x => ({ 键: x.键, 位: x.位 }));
  else 界面.默认五人队();
  界面.提示 = '';
  界面.开屏('调参室');
  return 界面.屏 === '调参室';
}

/** ★「看一场」（§3.4）：用**正常的战斗界面**播这一场 —— 建 ctx（带调参）→ 开屏（战斗）→
 *  剩下的交给现成的「开打 ▶ / 播放 / 回合播完 / 结算」，**`85-播放.js` 的时序一个字节没动**。 */
function 调参开一场(种子) {
  调参同步编队();
  const 场景 = 调参场景(调参室模型.设置);
  if (!场景.用们.length) {
    调参室模型.提示 = '这一层没有这个类型的编成，先换一层 / 换一个类型。';
    刷调参屏();
    return false;
  }
  const s = 场景.设置;
  const 条目 = 场景.用们[0];
  const 种子号 = Math.max(1, Math.round(Number(种子 != null ? 种子 : (调参室模型.看一场种子 || s.种子起)) || s.种子起));
  const 选项 = { 波次: 编成波次到单位(条目.条目, 0) };
  const 调参 = 调参调参对象(s);
  if (Object.keys(调参).length) 选项.调参 = 调参;
  const 起手 = 调参回合方针(s, 1);
  界面.ctx = 开局(调参出击(s), 敌方规格组(编成到单位(条目.条目, 0)), 种子号, null, 选项);
  /* 「简单策略」在**播放过程中**自动换方针（第 1 回合全军防御 → 第 2 回合起全军突击）：
     表挂在 ctx 上，`80-界面.js` 的 `回合播完()` 会调 `调参回合播完()` 落地（正常游戏没有这张表）。 */
  if (typeof 调参方针(s) === 'object') 界面.ctx.调参方针表 = 调参方针(s);
  const 起手方针 = { 类型: 规整方针(起手), 目标位: (起手 && 起手.目标位 != null) ? 起手.目标位 : null };
  /* 「集中攻击」在调参室里没有「点一张敌机卡」这一步：目标位默认取**敌方前 1**（0 号位）——
     编成表每条编成都至少有 1 台前排，那一格开局一定有活人（§3.2 只给了「整场固定一条」）。 */
  if (起手方针.类型 === '集中攻击' && 起手方针.目标位 == null) 起手方针.目标位 = 0;
  界面.方针 = 起手方针;
  设方针(界面.ctx, 起手方针);
  界面.单位开关 = {};
  界面.选中位 = null;
  界面.选目标 = false;
  界面.提示 = '';
  界面.显示单位 = null;
  界面.战报 = null;
  界面.种子 = 种子号;
  界面.肉鸽战斗 = null;          // 调参室这一场不是肉鸽节点 → 打完回**战斗结算屏**
  界面.调参模式 = true;
  界面.阶段 = '指令';
  界面.开屏('战斗');
  return true;
}

/** ★ §3.4 的「**看一场**」按钮：任选一个种子，用**正常的战斗界面**播这一场（带记录）。 */
function 看一场(种子) { return 调参开一场(种子); }

/** ★ 「简单策略」的自动换方针（`80-界面.js` 的 `回合播完()` 里那一个**空转**钩子）。
 *  正常游戏的战斗没有 `ctx.调参方针表` → 立刻返回，什么都不做。 */
function 调参回合播完(界面对象) {
  const ctx = 界面对象 && 界面对象.ctx;
  if (!ctx || !ctx.调参方针表) return false;
  const p = 第几回合的方针(ctx.调参方针表, ctx.turn);
  const 类型 = 规整方针(p);
  界面对象.方针 = { 类型, 目标位: (p && p.目标位 != null) ? p.目标位 : null };
  return true;
}

/** 调参室的所有按钮都走这里（`data-act="调参室:<子动作>[:参数]"`）。 */
function 调参室动作(参) {
  const 名 = String(参 == null ? '' : 参);
  const i = 名.indexOf(':');
  const 头 = i < 0 ? 名 : 名.slice(0, i);
  const 尾 = i < 0 ? '' : 名.slice(i + 1);
  const M = 调参室模型;
  switch (头) {
    case '层': M.设({ 层: Number(尾), 条目: null }); break;
    case '类型': M.设({ 类型: 尾, 条目: null }); break;
    case '条目': M.设({ 条目: 尾 === '全部' ? null : Number(尾) }); break;
    case '方针': M.设({ 方针: decodeURIComponent(尾) }); break;
    case '场次': M.设({ 场次: Number(尾) }); break;
    case '选敌人键': M.选中敌人键 = 尾; break;
    case '覆盖加上': {
      const 键 = 尾;
      if (!ENEMY_T[键]) { M.提示 = '认不出的敌人键：' + 键; break; }
      const 草 = (M.草稿 || {})[键] || M.设置.覆盖[键] || { HP倍率: 1, 装甲倍率: 1, 威力倍率: 1 };
      M.设({ 覆盖: { [键]: 草 } });
      if (M.草稿) delete M.草稿[键];
      break;
    }
    case '覆盖去掉': {
      const 覆 = Object.assign({}, M.设置.覆盖);
      delete 覆[尾];
      M.设置 = M.规整(Object.assign({}, M.设置, { 覆盖: 覆 }));
      M.保存();
      break;
    }
    case 'Boss清': {
      const B = Object.assign({}, M.设置.Boss);
      delete B[尾];
      M.设置 = M.规整(Object.assign({}, M.设置, { Boss: B }));
      M.保存();
      break;
    }
    case '跑': 开始跑批(); return M.结果;
    case '清结果': M.清结果(); break;
    case '存储存': M.保存(); M.提示 = '已存进 localStorage（键 ' + 调参存档键 + '）。'; break;
    case '恢复默认': M.恢复默认(); 界面.默认五人队(); break;
    case '复制设置': {
      调参同步编队();
      const 文 = M.导出();
      /* 真的复制一份（浏览器给不给是它的事，失败也不抛 —— 文本框里照样看得到） */
      try {
        const nv = (typeof navigator !== 'undefined') ? navigator : null;
        if (nv && nv.clipboard && nv.clipboard.writeText) nv.clipboard.writeText(文);
      } catch (e) { /* 忽略：文本框才是唯一可靠的交付方式 */ }
      M.提示 = '已导出（下面那个框：人话清单 + JSON，Ctrl+C 或直接发给我）。';
      break;
    }
    case '读回': {
      const s = M.读回(null);
      if (s) { 界面.编队.等级 = s.等级; 界面.编队.出击 = 调参出击(s).map(x => ({ 键: x.键, 位: x.位 })); }
      break;
    }
    default: M.提示 = '认不出的调参室动作：' + 名;
  }
  if (界面.屏 === '调参室') 界面.刷();
  return true;
}

/** 跑批（§3.4 的分批跑）：每批 10 场，批间用 `setTimeout(…, 0)` 让出主线程。
 *  ★ 句柄同时留在 `调参室模型.结果` 里 —— 测试可以**手工**驱动它（DOM 替身里 `setTimeout` 是空转的），
 *    这一条保证「分批跑的进度与总场数」真的测得出来。 */
function 开始跑批() {
  const M = 调参室模型;
  调参同步编队();          // 屏幕上那张名单就是这一次跑的名单
  M.提示 = '';
  const 句柄 = M.分批跑(句 => {
    /* 进度先画到 DOM 上（**不整屏重画**：重画会把进度条换掉） */
    调参画进度(句);
    if (!句.完) 排下一批(句);
    else 刷调参屏();
  });
  调参画进度(句柄);
  if (句柄.完 || 句柄.错误) 刷调参屏();
  return 句柄;
}

/** 排下一批：让出一次主线程（`setTimeout(…, 0)`）；没有定时器（测试替身）就同步跑完。 */
function 排下一批(句柄) {
  if (typeof setTimeout === 'function') setTimeout(() => { 句柄.继续(); }, 0);
  else 句柄.继续();
  return 句柄;
}

function 调参画进度(句柄) {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  const el = 屏 && 屏.querySelector ? 屏.querySelector('[data-tune-progress="1"]') : null;
  if (!el) return false;
  el.textContent = `${句柄.进度} / ${句柄.总场}（每批 ${句柄.每批} 场让出一次主线程）`;
  const bar = 屏.querySelector ? 屏.querySelector('.bar2 i') : null;
  if (bar && bar.style && 句柄.总场) bar.style.width = Math.round(句柄.进度 / 句柄.总场 * 100) + '%';
  return true;
}

