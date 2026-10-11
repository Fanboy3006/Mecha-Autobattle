/* ============================================================================
 * 战斗引擎：回合流程 + 指令 + 职业特色 + simulate()（方案 3.2 / 第 4 / 5 / 6.3 节）
 * ----------------------------------------------------------------------------
 * 对外接口（M3 起是「一回合一个回合地打」，因为玩家的指令会变，不能一次算完整场）：
 *
 *   开局(我方, 敌方, 种子) → ctx      一次战斗的状态：双方单位、记录、带种子的随机数
 *   设指令(ctx, 指令表)               指令表 = { 位: {类型, 目标位, 保留大招} }
 *                                     类型 = 进攻（默认）/ 集火 / 守护 / 防御 / 换位（方案第 4 节）
 *   算意图(ctx)                        敌人这一回合打算打谁、用什么武器、期望多少伤害（方案 5.3，纯函数）
 *   打一回合(ctx)                      指令阶段 → 行动阶段 → 回合结束；返回**这一回合**的记录
 *   simulate(我方, 敌方, 指令, 种子)   一整场（M1 的接口，测试和以后的平衡工具用）
 *
 * 一个回合（方案 3.2）：全场单位按速度从高到低各行动一次（同速 → 我方先，再按列号），
 * 然后 buff / 冷却计时减 1。胜负：敌方全灭 = 胜；我方全灭或第 12 回合结束 = 败。
 * ========================================================================== */

const MAX_TURN = 12;          // 第 12 回合结束还没分出胜负 = 败（方案 3.2）
const ULT_START_CD = 3;       // 大招（unlock 20 / 30）开场冷却 3 回合（方案第 4 节）
const 指令们 = ['进攻', '集火', '守护', '防御', '换位'];

/* ---------- 记录 ---------- */
function pushLog(ctx, text, extra) {
  ctx.log.push(Object.assign({ 回合: ctx.turn, 文本: text }, extra || {}));
}
/* 记录里带上「谁 / 打谁」的阵营与格子：界面回放要靠它画血条、闪白、飘伤害数字。
   只用单位键不行——编成里常常有两台同名敌人（例如两个 grunt）。 */
const 谁 = u => ({ 单位方: u.side, 单位位: u.slot });
const 谁目标 = u => ({ 目标方: u.side, 目标位: u.slot });

/* ---------- 指令（方案第 4 节） ---------- */
const 默认指令 = () => ({ 类型: '进攻', 目标位: null, 保留大招: false });

function 设指令(ctx, 指令表) {
  for (const u of ctx.allies) {
    const c = Object.assign(默认指令(), (指令表 && 指令表[u.slot]) || {});
    u.指令 = 指令们.includes(c.类型) ? c.类型 : '进攻';
    u.指定目标位 = c.目标位 != null ? c.目标位 : null;
    u.holdUlt = !!c.保留大招;
  }
  return ctx;
}

/* ---------- 行动顺序 ---------- */
/* 速度从高到低；同速：我方先，再按列号（方案 3.2）。同速同列再按格子编号，保证决定性。 */
function actionOrder(ctx) {
  return livingUnits(ctx).sort((a, b) =>
    speedOf(b) - speedOf(a) ||
    (a.side === b.side ? 0 : a.side === 'ally' ? -1 : 1) ||
    colOfSlot(a.slot) - colOfSlot(b.slot) ||
    a.slot - b.slot
  );
}

/* ---------- 守护 / 嘲讽（方案第 4 节 / 6.3） ---------- */
/** 谁在守护谁：被守护者的格子 → 守护者。一名队友同时只能被一人守护（速度高的优先）。 */
function 守护关系(ctx) {
  const 表 = new Map();
  for (const u of actionOrder(ctx)) {
    const t = u.守护对象;
    if (!t || t.hp <= 0 || t === u) continue;
    if (!表.has(t.slot)) 表.set(t.slot, u);
  }
  return 表;
}
const 守护者 = (ctx, 被守护) => {
  const 表 = 守护关系(ctx);
  // 用单位引用比对：换位之后格子会变，只靠格子号会认错人
  for (const [位, g] of 表) if (g.守护对象 === 被守护 && g.hp > 0) return g;
  return null;
};
/** 重装（方案 6.3）：在前排时，敌方的单体攻击 50% 概率改打它。 */
function 嘲讽(ctx, 攻击者, 原目标) {
  if (攻击者.side !== 'enemy' || 原目标.side !== 'ally') return null;
  const 候选 = livingOf('ally', ctx).filter(u => 职业是(u, '重装') && unitRow(u) === ROW_FRONT && u !== 原目标 && u.hp > 0);
  if (!候选.length) return null;
  if (ctx.rng() >= 0.5) return null;                  // 50%（走带种子的随机数）
  候选.sort((a, b) => b.hp - a.hp || a.slot - b.slot);  // 并列时血多的（决定性）
  return 候选[0];
}

/* ---------- 回合开始（指令解析 + 指挥 + 防御回报） ---------- */
function 回合开始(ctx) {
  /* 1. 把「位」形式的指令解析成**单位引用**：换位之后引用不会错 */
  for (const u of livingOf('ally', ctx)) {
    u.守护对象 = null;
    u.指定目标 = null;
    if (u.指令 === '守护' && u.指定目标位 != null) {
      const t = livingOf('ally', ctx).find(x => x.slot === u.指定目标位);
      if (t && t !== u) u.守护对象 = t;
    }
    if (u.指令 === '集火' && u.指定目标位 != null) {
      u.指定目标 = livingOf('enemy', ctx).find(x => x.slot === u.指定目标位) || null;
    }
  }
  for (const u of livingOf('enemy', ctx)) { u.守护对象 = null; u.指令 = '进攻'; }

  /* 2. 指挥（方案 6.3）：回合开始时，同一排的队友命中 +10（本回合） */
  for (const c of livingOf('ally', ctx)) {
    if (!职业是(c, '指挥')) continue;
    const 同排 = livingOf('ally', ctx).filter(t => t !== c && unitRow(t) === unitRow(c));
    if (!同排.length) continue;
    for (const t of 同排) 换同源增益(t, '指挥', { hit: 10 });
    pushLog(ctx, `〔指挥〕${c.name} 让同一排的队友命中 +10（本回合）：${同排.map(t => t.name).join('、')}`,
      Object.assign({ 类型: '指挥', 单位: c.key, 目标: 同排.map(t => t.key), 目标位们: 同排.map(t => t.slot), 目标方们: 同排.map(t => t.side) }, 谁(c)));
  }

  /* 3. 防御的回报：上一回合选了「防御」的，这一回合开始回复 5% 最大 HP（方案第 4 节） */
  for (const u of livingUnits(ctx)) {
    if (!u.防御回复) continue;
    u.防御回复 = false;
    const amt = Math.min(Math.round(u.maxHp * 0.05), u.maxHp - u.hp);
    if (amt > 0) {
      u.hp += amt;
      pushLog(ctx, `${u.name} 防御调整完成，回复 ${amt}`, Object.assign({ 类型: '回复', 回复: amt, 目标剩余HP: u.hp }, 谁(u), 谁目标(u)));
    }
  }
}

/* ---------- 换位：算出该换到哪个格子（作者 2026-10-10 定：按列对位） ----------
 *   1. 同一列的另一排有这一格 → 就用它（对面有人就互换，空着就移过去）；
 *   2. 没有对位格（前 3 后 2 时前排的第 3 列）→ 在本排里找空位，没空位就和本排第一个队友互换；
 *   3. 本排也没有别的格子 → 返回 null（这次换位作罢）。 */
function 换位目标(ctx, actor) {
  const r = rowOfSlot(actor.slot), c = colOfSlot(actor.slot);
  const 对排 = r === ROW_FRONT ? ROW_BACK : ROW_FRONT;
  if (有这一列(对排, c)) return slotOf(对排, c);
  const 占 = new Map(livingOf(actor.side, ctx).map(u => [u.slot, u]));
  const 本排 = [];
  for (let i = 0; i < 行列数(r); i++) 本排.push(slotOf(r, i));
  const 空位 = 本排.filter(位 => 位 !== actor.slot && !占.has(位));
  if (空位.length) return 空位[0];
  const 队友位 = 本排.filter(位 => 位 !== actor.slot && 占.has(位));
  return 队友位.length ? 队友位[0] : null;
}

/* ---------- 一个单位这次行动做什么 ---------- */
function 单位动作(u, ctx) {
  if (u.side === 'enemy') return enemyAction(u, ctx);
  switch (u.指令) {
    case '防御': return { kind: 'defend' };
    case '换位': return { kind: 'swap' };
    case '守护': return aiAction(u, ctx);      // 守护者照常攻击（伤害在结算时 −30%）
    default: return aiAction(u, ctx);          // 进攻 / 集火
  }
}

/* ---------- 一个单位行动一次 ---------- */
function actOnce(u, ctx) {
  if (u.hp <= 0) return;
  u.actedTurn = ctx.turn;              // 「再动」要知道谁这一回合已经行动过
  const action = 单位动作(u, ctx);
  let r = null;
  if (action) r = resolveAction(u, action, ctx);
  else pushLog(ctx, `${u.name} 没有能打到人的武器，跳过`, Object.assign({ 类型: '跳过', 单位: u.key }, 谁(u)));
  runAutoCast(u, ctx);                 // 残月的余响：行动结束后自动释放（被动）

  /* 近卫（方案 6.3）：击破目标后立刻再行动一次，每回合最多 1 次 */
  if (r && r.击破 > 0 && 职业是(u, '近卫') && u.近卫再动Turn !== ctx.turn) {
    u.近卫再动Turn = ctx.turn;
    ctx.again.push(u);
    pushLog(ctx, `〔连斩〕${u.name} 击破了目标，立刻再行动一次（近卫，每回合 1 次）`, Object.assign({ 类型: '连斩' }, 谁(u)));
  }
}

/* ---------- 增益：同一个来源只留一份（避免每回合叠成天文数字） ---------- */
function 换同源增益(u, src, buff) {
  u.buffs = (u.buffs || []).filter(b => b.src !== src);
  u.buffs.push(Object.assign({ src, 剩余: 1 }, buff));
}

/* ---------- 残月的余响（被动；范围由作者 2026-10-10 定为「敌方前排」） ---------- */
function runAutoCast(u, ctx) {
  if (u.echoTurn === ctx.turn) return;
  const pool = u.weapons.filter(e => e.t.special === 'echo' && u.lv >= e.t.unlock && e.cd <= 0);
  if (!pool.length) return;
  pool.sort((a, b) => a.t.unlock - b.t.unlock);
  const e = pool[pool.length - 1], w = e.t;
  const foes = livingOf(otherSide(u.side), ctx);
  const targets = 残月余响范围 === '敌方前排' ? foes.filter(t => unitRow(t) === ROW_FRONT) : foes;
  if (!targets.length) return;
  u.echoTurn = ctx.turn;
  if (w.cd) e.cd = w.cd;
  for (const t of targets) {
    if (t.hp <= 0) continue;
    const rec = resolveAttack(u, t, w, ctx, {});
    pushLog(ctx, `〔${w.name}〕${rec.文本}`, Object.assign({ 类型: '残月余响', 单位: u.key, 目标: t.key, 武器: w.name }, 谁(u), 谁目标(t), rec.字段));
  }
}

/* ---------- 结算一个动作（攻击 / 修理 / 增益 / 再动 / 防御 / 换位） ----------
   返回 { 击破: 这一下打死了几台 }，近卫的「连斩」要用。 */
function resolveAction(actor, action, ctx) {
  const w = action.weapon;
  const 空 = { 击破: 0 };

  /* 支援①：加增益（月光祝福） */
  if (action.kind === 'buff') {
    const buff = wv(actor, w, 'buff') || w.buff || {};
    for (const t of action.targets) 换同源增益(t, w.name, buff);
    spendWeapon(actor, action.entry);
    pushLog(ctx, `${actor.name}【${w.name}】→ ${action.targets.map(t => t.name).join('、')}：${Object.entries(buff).map(([k, v]) => `${k} ${v > 0 ? '+' : ''}${v}`).join('、')}（到本回合结束）`,
      Object.assign({ 类型: '增益', 单位: actor.key, 武器: w.name, 目标: action.targets.map(t => t.key), 目标位们: action.targets.map(t => t.slot), 目标方们: action.targets.map(t => t.side) }, 谁(actor)));
    return 空;
  }

  /* 支援②：再动 */
  if (action.kind === 'grant') {
    const t = action.target;
    t.grantedTurn = ctx.turn;
    ctx.again.push(t);
    spendWeapon(actor, action.entry);
    pushLog(ctx, `${actor.name}【${w.name}】→ ${t.name}：再行动一次`, Object.assign({ 类型: '再动', 单位: actor.key, 目标: t.key }, 谁(actor), 谁目标(t)));
    return 空;
  }

  /* 防御（方案第 4 节）：不攻击；本回合受到的伤害按防御值 +50 结算；下回合开始回复 5% 最大 HP */
  if (action.kind === 'defend') {
    actor.defending = true;
    actor.防御回复 = true;
    pushLog(ctx, `${actor.name} 进入防御（本回合伤害按防御 +50 结算，下回合开始回复 5% HP）`, Object.assign({ 类型: '防御' }, 谁(actor)));
    return 空;
  }

  /* 换位（方案第 4 节 + 作者 2026-10-10：按列对位）：和同一列的另一排交换；对面是空位就直接移过去；
     前排多出来、后排没有对位的那一列（前 3 后 2 时的前 3），就在本排里换空位 / 换队友。本回合不攻击。 */
  if (action.kind === 'swap') {
    const 目标位 = 换位目标(ctx, actor);
    if (目标位 == null) {
      pushLog(ctx, `${actor.name} 没有可以换的位置（作罢）`, Object.assign({ 类型: '换位', 结果: '作罢' }, 谁(actor)));
      return 空;
    }
    const 对方 = livingOf(actor.side, ctx).find(x => x.slot === 目标位);
    const 原 = actor.slot;
    if (对方) { actor.slot = 对方.slot; 对方.slot = 原; }
    else actor.slot = 目标位;
    pushLog(ctx, `${actor.name} 换位到 ${位名(actor.slot)}${对方 ? `（和 ${对方.name} 互换）` : ''}`, Object.assign({ 类型: '换位', 位: actor.slot, 原: 原 }, 谁(actor)));
    return 空;
  }

  if (action.kind === 'heal') {
    const amount = healAmount(actor, w);
    const before = action.target.hp;
    action.target.hp = Math.min(action.target.maxHp, action.target.hp + amount);
    spendWeapon(actor, action.entry);
    pushLog(ctx, `${actor.name} 修理 ${action.target.name}，回复 ${action.target.hp - before}`, Object.assign({
      类型: '修理', 单位: actor.key, 目标: action.target.key, 武器: w.name, 回复: action.target.hp - before, 目标剩余HP: action.target.hp,
    }, 谁(actor), 谁目标(action.target)));
    return 空;
  }

  /* 攻击（含范围）：一次打落点上的所有敌人，或打单个目标 */
  const kind = rangeKindOf(w);
  const targets = isAreaKind(kind) ? (action.hit || []) : [action.target];
  const 守护方 = actor.指令 === '守护' && actor.守护对象 ? 0.7 : 1;   // 守护者自己攻击伤害 −30%
  let 击破 = 0;

  for (const t of targets) {
    if (t.hp <= 0) continue;
    let 实际 = t, 按防御 = false;

    if (!isAreaKind(kind) && actor.side === 'enemy') {
      const g = 守护者(ctx, t);
      if (g) {
        实际 = g; 按防御 = true;
        pushLog(ctx, `〔守护〕${g.name} 替 ${t.name} 挡下这一击（按防御结算）`, Object.assign({ 类型: '守护', 目标: g.key, 原目标: t.key }, 谁(g), 谁目标(g)));
      } else {
        const 嘲 = 嘲讽(ctx, actor, t);
        if (嘲) {
          pushLog(ctx, `〔嘲讽〕${嘲.name} 把这一击勾了过去`, Object.assign({ 类型: '嘲讽', 目标: 嘲.key, 原目标: t.key }, 谁(嘲), 谁目标(嘲)));
          实际 = 嘲;
        }
      }
    }

    const 血 = 实际.hp;
    const 行 = unitRow(实际);
    const frontAliveNow = frontAlive(livingOf(otherSide(actor.side), ctx));
    const blockPenalty = isAreaKind(kind) ? 0 : rowBlockPenalty(kind, 行, frontAliveNow, actor);
    const rec = resolveAttack(actor, 实际, w, ctx, { blockPenalty, defending: 按防御, 伤害倍率: 守护方 });
    if (血 > 0 && 实际.hp <= 0) 击破++;
    pushLog(ctx, rec.文本, Object.assign({ 类型: '攻击', 单位: actor.key, 目标: 实际.key, 武器: w.name, 集火: !!action.集火, 守护挡下: 按防御, 原目标: 按防御 ? t.key : null, 原目标位: 按防御 ? t.slot : null }, 谁(actor), 谁目标(实际), rec.字段));
  }
  spendWeapon(actor, action.entry);
  return { 击破 };
}

/* ---------- overwatch（方案 5.2）：第一个行动的我方单位会被它先打一下 ---------- */
function runOverwatch(ally, ctx) {
  for (const e of livingOf('enemy', ctx)) {
    if (!hasOverwatch(e) || e.overwatchFiredTurn === ctx.turn) continue;
    if (ally.hp <= 0) return;
    const action = enemyAction(e, ctx);
    if (!action) continue;
    e.overwatchFiredTurn = ctx.turn;
    pushLog(ctx, `〔压制射击〕${e.name} 抢先开火`, Object.assign({ 类型: '压制射击', 单位: e.key, 目标: ally.key }, 谁(e), 谁目标(ally)));
    resolveAction(e, action, ctx);
  }
}

/* ---------- 一个回合 ---------- */
function runTurn(ctx) {
  pushLog(ctx, `—— 第 ${ctx.turn} 回合 ——`, { 类型: '回合' });
  for (const u of actionOrder(ctx)) {
    if (ctx.result) return;
    if (u.hp <= 0) continue;
    if (u.side === 'ally') runOverwatch(u, ctx);     // 我方第一个行动的人会被压制射击
    if (u.hp <= 0) continue;
    actOnce(u, ctx);
    drainAgain(ctx);                                 // 「再动」「连斩」的队友立刻行动
    ctx.result = checkResult(ctx);
    if (ctx.result) return;
  }
}

/* ---------- 再动 / 连斩：被点名的队友立刻行动一次 ---------- */
function drainAgain(ctx) {
  while (ctx.again.length) {
    const g = ctx.again.shift();
    if (g.hp <= 0 || ctx.result) continue;
    actOnce(g, ctx);
    ctx.result = checkResult(ctx);
  }
}

/* ---------- 胜负（方案 3.2） ---------- */
function checkResult(ctx) {
  const alliesAlive = livingOf('ally', ctx).length;
  const enemiesAlive = livingOf('enemy', ctx).length;
  if (!enemiesAlive) return { 结果: '胜', 原因: '敌方全灭' };
  if (!alliesAlive) return { 结果: '败', 原因: '我方全灭' };
  return null;
}

/* ---------- 回合结束：buff / 冷却计时减 1（方案 3.2） ---------- */
function endTurn(ctx) {
  for (const u of livingUnits(ctx)) {
    for (const e of u.weapons) if (e.cd > 0) e.cd--;
    u.buffs = (u.buffs || []).filter(b => (b.剩余 = (b.剩余 == null ? 1 : b.剩余) - 1) > 0);
    u.defending = false;
  }
}

/* ---------- 开场 ---------- */
function 开局(我方编成, 敌方编成, 种子, 指令表) {
  const rng = mulberry32((种子 >>> 0) || 1);
  const ctx = {
    turn: 1, 种子: (种子 >>> 0) || 1, rng,
    allies: makeUnits(我方编成, 'ally'), enemies: makeUnits(敌方编成, 'enemy'),
    log: [], result: null, again: [],
  };
  for (const u of livingUnits(ctx)) {
    /* 开场冷却**只由 readyTurn 管**（= 1 + startCdOf(w)，规则见 13-武器可用性.js）：
       开场冷却 3 回合 = 第 4 回合才能用；普通冷却 cd 开场一律是 0。 */
    u.weapons = u.weapons.map(e => Object.assign({}, e, { cd: 0 }));
    u.指令 = '进攻'; u.指定目标位 = null; u.holdUlt = false;
  }
  设指令(ctx, 指令表);
  pushLog(ctx, `战斗开始：我方 ${ctx.allies.length} 台 vs 敌方 ${ctx.enemies.length} 台`, { 类型: '开始' });
  return ctx;
}

/* ---------- 敌人意图（方案 5.3）：纯函数，不改任何状态，给界面在指令阶段显示 ----------
 * 说明：这里算的是「如果现在开打，这个敌人会打谁」。目标中途倒下或被守护时就按规则改打
 * （守护挡下 / 重新挑目标），这一点在行动阶段由引擎自己处理。 */
function 算意图(ctx) {
  return livingOf('enemy', ctx).map(u => {
    const a = enemyAction(u, ctx);
    return {
      单位: u.key, 单位位: u.slot, 名称: u.name,
      武器: a && a.weapon ? a.weapon.name : null,
      目标: a && a.target ? a.target.key : null,
      目标位: a && a.target ? a.target.slot : null,
      目标名: a && a.target ? a.target.name : null,
      期望: a && a.expected ? Math.round(a.expected) : 0,
      压制射击: hasOverwatch(u),
    };
  });
}

/* ---------- 打一个回合 ---------- */
function 打一回合(ctx) {
  const 起 = ctx.log.length;
  回合开始(ctx);
  runTurn(ctx);
  if (!ctx.result) {
    if (ctx.turn >= MAX_TURN) ctx.result = { 结果: '败', 原因: `第 ${MAX_TURN} 回合结束还没分出胜负（按撤退处理）` };
    else { endTurn(ctx); ctx.turn++; }
  }
  return ctx.log.slice(起);
}

/* ---------- simulate（方案第 9 节 M1 的接口；一整场，指令固定不变） ---------- */
function simulate(我方, 敌方, 指令, 种子) {
  const ctx = 开局(我方, 敌方, 种子, 指令);
  let 护栏 = 0;
  while (!ctx.result && 护栏++ < MAX_TURN + 2) {
    设指令(ctx, 指令);
    打一回合(ctx);
  }
  if (!ctx.result) ctx.result = { 结果: '败', 原因: '超出回合上限' };
  pushLog(ctx, `战斗结束：${ctx.result.结果}（${ctx.result.原因}）`, { 类型: '结束' });
  return {
    结果: ctx.result.结果, 原因: ctx.result.原因, 回合数: ctx.turn,
    记录: ctx.log, 我方: ctx.allies, 敌方: ctx.enemies, 种子: ctx.种子, ctx,
  };
}
