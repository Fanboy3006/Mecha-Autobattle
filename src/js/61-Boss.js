/* ============================================================================
 * 站桩大 Boss 的脚本框架（方案 5.2）
 * ----------------------------------------------------------------------------
 * 方案 5.2 原文：「Boss：各写一个简单脚本（每 N 回合放一次大技能、半血换阶段），
 *                第一期只做蓝色大肥鱼一个。」
 *
 * 新项目**没有格子地图**：战棋那套「逐格右移 / 碾压路线上的单位 / 到终点判负 /
 * 撞碎力场壁 / 永远朝右」全都搬不了（逐条见 `协作/战棋协作可搬清单.md` 第一节 A1–A12）。
 * 所以新项目里的 Boss 是**站着打的**：脚本只管两件事——「每 N 回合放一次大技能」和
 * 「半血换阶段」。作者 2026-10-10 拍板：「可以做站桩大boss」。
 *
 * 数据驱动：参数写在 `src/js/71-改动.js` 的 `Boss脚本` 里（新项目改数据只改那里），
 * 引擎这一侧只认下面这几个字段（**下面是初稿，作者试玩后再调**）：
 *
 *   Boss脚本[敌人键] = {
 *     大技能间隔: 3,             // 每 N 回合放一次：第 1、1+N、1+2N… 回合
 *     大技能武器: '周身冲击',     // 用数据里的武器名指定
 *     伤害倍率: 1,              // 第 1 阶段（基础参数）
 *     阶段: [ { 触发: '半血', 大技能间隔: 2, 伤害倍率: 1.25 } ],   // 半血换第 2 阶段
 *   }
 *
 * 规则（这一版自己定的地方，任务板里也写了）：
 *   1. **只对我方之外的单位生效**（`side === 'enemy'` 且键在 `Boss脚本` 里）；
 *      没配脚本的敌人一个字节的行为都不变（还是 50-AI.js 的 `enemyAction`）。
 *   2. 大技能回合：`（回合 − 1) % 大技能间隔 === 0`，也就是**第 1 回合起算**
 *      （第 1、4、7… 回合），这样开场第一回合就能在记录里看到它出手。
 *   3. 不是大技能回合时，大技能武器**不进普通 AI 的武器池**——否则它就变成「每回合都放」，
 *      「每 N 回合一次」就没有意义了。如果这名 Boss 除了大技能没有别的武器能打
 *      （蓝色大肥鱼只有一把「周身冲击」），这一回合就**蓄力**：不出手，记录里写
 *      `〔Boss〕… 蓄力中（第 N 回合释放【…】）`。玩家因此能看见「下一发什么时候来」。
 *   4. 阶段按**当前 HP 比例**判定（纯计算，不存状态）：`hp / maxHp <= 触发阈值` 就进那个阶段。
 *      `触发` 写 `'半血'`（= 0.5）或直接写数字（0.5 / 50 都认）；多个阶段按顺序判，
 *      **最后一个满足的生效**。基础参数 = 第 1 阶段，`阶段[0]` = 第 2 阶段，依此类推。
 *      换阶段只在战斗记录里报**一次**（`〔Boss〕蓝色大肥鱼 进入第 2 阶段`）。
 *   5. `伤害倍率` 是这一阶段下 Boss 造成的**全部**伤害的倍率（在 60-战斗.js 的
 *      `resolveAction` 里乘进去，和「守护者 ×0.7」相乘）；没配就是 1。
 *   6. 脚本自己**不含随机数**（阶段只看 HP、间隔只看回合号），所以同种子同结果照旧。
 *
 * 【不归我做的地方】大肥鱼的 240000 HP / 1800 装甲怎么按新公式换算成产品数值，
 * 由 Claude 定（`协作/战棋协作可搬清单.md` B1/B2 只列了事实）。这一版**照数据原样用**，
 * 所以 12 回合上限下打不死——任务板里写明了这一点，测试里只做「把 HP 临时改小」的验算。
 * ========================================================================== */

/* ---------- 取脚本：只认敌人 ---------- */
/** 这名单位有没有 Boss 脚本（`Boss脚本` 在 71-改动.js，新项目改数据只改那里）。 */
function 取Boss脚本(u) {
  if (!u || u.side !== 'enemy' || !u.key) return null;
  return (Boss脚本 && Boss脚本[u.key]) || null;
}
const 是Boss单位 = u => !!取Boss脚本(u);

/* ---------- 阶段（纯计算：只看当前 HP 比例） ---------- */
/** 触发条件 → HP 比例阈值：`'半血'` = 0.5；数字 0–1 直接用；数字 >1 当百分数（50 = 0.5）。 */
function Boss触发阈值(触发) {
  if (typeof 触发 === 'number') return 触发 > 1 ? 触发 / 100 : 触发;
  if (触发 === '半血') return 0.5;
  return null;   // 认不出来的触发条件：这一条阶段不生效（不抛异常）
}

/** 现在是第几阶段：0 = 基础（第 1 阶段），1 = `阶段[0]`（第 2 阶段）…；没脚本返回 0。 */
function Boss阶段序号(u) {
  const s = 取Boss脚本(u);
  if (!s || !Array.isArray(s.阶段) || !s.阶段.length || !(u.maxHp > 0)) return 0;
  const 血比 = u.hp / u.maxHp;
  let n = 0;
  for (let i = 0; i < s.阶段.length; i++) {
    const t = Boss触发阈值(s.阶段[i] && s.阶段[i].触发);
    if (t != null && 血比 <= t) n = i + 1;   // 后面的阶段覆盖前面的
  }
  return n;
}

/** 这一阶段实际生效的参数：基础字段 + 阶段覆盖（脚本没写的字段用默认值）。纯函数。 */
function Boss参数(u) {
  const s = 取Boss脚本(u);
  if (!s) return null;
  const 阶段 = Boss阶段序号(u);
  const o = (阶段 > 0 ? s.阶段[阶段 - 1] : null) || {};
  const 取 = (k, d) => (o[k] != null ? o[k] : (s[k] != null ? s[k] : d));
  return {
    脚本: s, 阶段, 第几阶段: 阶段 + 1,
    大技能间隔: 取('大技能间隔', 0),
    大技能武器: 取('大技能武器', null),
    伤害倍率: 取('伤害倍率', 1),
  };
}

/* ---------- 大技能的节奏 ---------- */
/** 这一回合是不是「大技能回合」：`（回合 − 1) % 间隔 === 0`（第 1、1+间隔、…回合）。 */
function Boss本回合放大技能(u, ctx) {
  const p = Boss参数(u);
  if (!p || !p.大技能武器 || !(p.大技能间隔 > 0)) return false;
  if (!ctx || ctx.turn == null) return false;
  return ((ctx.turn - 1) % p.大技能间隔) === 0;
}

/** 下一次大技能在第几回合（蓄力的记录里要写）。 */
function Boss下次技能回合(u, ctx) {
  const p = Boss参数(u);
  if (!p || !(p.大技能间隔 > 0) || !ctx || ctx.turn == null) return null;
  const 间隔 = p.大技能间隔;
  return ctx.turn + (间隔 - ((ctx.turn - 1) % 间隔));
}

/** 普通 AI 的武器池要不要**排除**这把武器（间隔外不许把大技能当普通武器用）。
 *  纯函数，被 50-AI.js 的 `weaponPool` 调用。 */
function Boss本回合禁用(u, ctx, w) {
  const p = Boss参数(u);
  if (!p || !p.大技能武器 || !(p.大技能间隔 > 0)) return false;
  if (!w || w.name !== p.大技能武器) return false;
  if (!ctx || ctx.turn == null) return false;
  return !Boss本回合放大技能(u, ctx);
}

/** 这一阶段下 Boss 伤害的倍率（没有脚本 / 没配 / 配错 → 1）。 */
function Boss伤害倍率(u) {
  const p = Boss参数(u);
  const v = p ? p.伤害倍率 : 1;
  return (typeof v === 'number' && v > 0) ? v : 1;
}

/* ---------- 大技能这一下打谁 ---------- */
/** 脚本点名的那把武器，现在能不能用（等级门 / 冷却 / 次数都照 `usableWeapons` 的规则）。 */
function Boss大技能条目(u, ctx) {
  const p = Boss参数(u);
  if (!p || !p.大技能武器) return null;
  return usableWeapons(u, ctx).find(e => e.t.name === p.大技能武器) || null;
}

/** 只用一把武器挑目标 / 落点：范围武器按「命中的敌人总期望伤害」挑，其余按单体挑。
 *  复用 50-AI.js 里的纯函数（`pickAreaTarget` / `pickSingleTarget`），不改那边。 */
function 单武器动作(u, 条目, ctx) {
  const foes = livingOf(otherSide(u.side), ctx);
  if (!条目 || !foes.length) return null;
  const w = 条目.t, pool = [条目];
  if (isAreaKind(rangeKindOf(w))) {
    const a = pickAreaTarget(u, foes, pool);
    if (a) return { kind: 'attack', weapon: w, target: a.target, expected: a.exp, slot: a.slot, hit: a.hit, entry: a.entry, 被挡: false };
  }
  const s = pickSingleTarget(u, foes, pool, ctx);
  if (s) return { kind: 'attack', weapon: w, target: s.target, expected: s.exp, entry: s.entry, 被挡: !!s.被挡 };
  return null;
}

/* ---------- 一台 Boss 这一回合想做什么 ---------- */
/** **纯函数**：不改状态、不写记录（`算意图()` 也用它，界面在指令阶段就能看见 Boss 的节奏）。
 *  返回 null = 这一回合没有出手的手段（大肥鱼在间隔外就是这样，由 bossTurn 记「蓄力」）。 */
function bossAction(u, ctx) {
  if (!取Boss脚本(u)) return enemyAction(u, ctx);          // 没配脚本 → 普通敌方 AI（行为不变）
  if (Boss本回合放大技能(u, ctx)) {
    const a = 单武器动作(u, Boss大技能条目(u, ctx), ctx);
    if (a) { a.大技能 = true; a.第几阶段 = Boss参数(u).第几阶段; return a; }
  }
  const a = enemyAction(u, ctx);
  if (a) return a;
  return null;
}

/* ---------- 真的行动：补记录 + 出手 ---------- */
/** 敌方单位的一次行动（60-战斗.js 的 `单位动作` 走这里）。
 *  - 先补「进入第 N 阶段」的记录（只报一次，所以这里是**会改状态**的那一半）；
 *  - 大技能回合：记录 `〔Boss〕…释放【…】`，再按大技能出手；
 *  - 间隔外又无别的武器：记录 `〔Boss〕…蓄力中`，这一回合不出手（kind: 'none'）。 */
function bossTurn(u, ctx) {
  const p = Boss参数(u);
  if (!p) return enemyAction(u, ctx);

  const 已报 = u.boss阶段已报 || 0;
  if (p.第几阶段 > 已报) {
    u.boss阶段已报 = p.第几阶段;
    /* 第 1 阶段 = 基础参数：报一次「登场」，让记录里一开场就能看见它的节奏；
       第 2 阶段起 = 换的那套参数，报「进入第 N 阶段」（方案 5.2 的「半血换阶段」）。 */
    const 文 = p.第几阶段 > 1
      ? `〔Boss〕${u.name} 进入第 ${p.第几阶段} 阶段（大技能间隔 ${p.大技能间隔} 回合、伤害倍率 ×${p.伤害倍率}）`
      : `〔Boss〕${u.name} 站桩 Boss：${p.大技能间隔 > 0 && p.大技能武器 ? `每 ${p.大技能间隔} 回合放一次【${p.大技能武器}】` : '（没配大技能）'}（伤害倍率 ×${p.伤害倍率}）`;
    pushLog(ctx, 文,
      Object.assign({ 类型: 'Boss', Boss事件: '阶段', Boss阶段: p.第几阶段, 大技能间隔: p.大技能间隔, 伤害倍率: p.伤害倍率 }, 谁(u)));
  }

  const a = bossAction(u, ctx);
  if (!a) {
    const 下次 = Boss下次技能回合(u, ctx);
    pushLog(ctx, `〔Boss〕${u.name} 蓄力中${下次 ? `（第 ${下次} 回合释放【${p.大技能武器}】）` : ''}`,
      Object.assign({ 类型: 'Boss', Boss事件: '蓄力', 大技能回合: 下次 }, 谁(u)));
    return { kind: 'none' };
  }
  if (a.大技能) {
    pushLog(ctx, `〔Boss〕${u.name} 释放【${a.weapon.name}】`,
      Object.assign({ 类型: 'Boss', Boss事件: '大技能', BOSS大技能: true, 武器: a.weapon.name,
        目标: a.target ? a.target.key : null, 目标位: a.target ? a.target.slot : null }, 谁(u)));
  }
  return a;
}
