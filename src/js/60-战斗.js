/* ============================================================================
 * 战斗引擎：回合流程 + simulate()（方案 3.2 / 第 5 节 / 第 9 节 M1）
 * ----------------------------------------------------------------------------
 * 一个回合（方案 3.2）：
 *   1. 指令阶段：M1 还没有界面，所有人的指令都是「进攻」（M3 才有全部指令）；
 *   2. 行动阶段：全场单位按速度从高到低各行动一次（同速 → 我方先，再按列号），
 *      自动结算，逐条写进战斗记录；
 *   3. 回合结束：buff / 冷却计时减 1。
 * 胜负：敌方全灭 = 胜；我方全灭 = 败；第 12 回合结束还没分出胜负 = 败（按撤退处理）。
 *
 * 对外只暴露一个函数（方案第 9 节 M1 的验收就是它）：
 *   simulate(我方, 敌方, 指令, 种子) → {结果, 回合数, 记录, 我方, 敌方, 种子}
 *
 * 「我方 / 敌方」是编成数组，每一项：
 *   {键:'B1' 或 mech:'B1', 等级:10, 位:0}     ← 我方按角色键查 ALLY_T
 *   {键:'hound', 等级:10, 位:2}               ← 敌方按敌人键查 ENEMY_T
 * 「指令」是 {单位键: 指令对象}，M1 只用默认的「进攻」（不传就是全进攻）。
 * ========================================================================== */

const MAX_TURN = 12;          // 第 12 回合结束还没分出胜负 = 败（方案 3.2）
const ULT_START_CD = 3;       // 大招（unlock 20 / 30）开场冷却 3 回合（方案第 4 节）

/* ---------- 记录 ---------- */
function pushLog(ctx, text, extra) {
  ctx.log.push(Object.assign({ 回合: ctx.turn, 文本: text }, extra || {}));
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

/* ---------- 一个单位行动一次 ---------- */
function actOnce(u, ctx) {
  if (u.hp <= 0) return;
  const action = u.side === 'ally' ? aiAction(u, ctx) : enemyAction(u, ctx);
  if (!action) { pushLog(ctx, `${u.name} 没有能打到人的武器，跳过`, { 类型: '跳过', 单位: u.key }); return; }
  resolveAction(u, action, ctx);
}

/* ---------- 结算一个动作（攻击 / 修理） ---------- */
function resolveAction(actor, action, ctx) {
  const w = action.weapon;
  if (action.kind === 'heal') {
    const amount = healAmount(actor, w);
    const before = action.target.hp;
    action.target.hp = Math.min(action.target.maxHp, action.target.hp + amount);
    spendWeapon(actor, action.entry, ctx);
    pushLog(ctx, `${actor.name} 修理 ${action.target.name}，回复 ${action.target.hp - before}`, {
      类型: '修理', 单位: actor.key, 目标: action.target.key, 武器: w.name, 回复: action.target.hp - before,
    });
    return;
  }

  /* 范围武器：一次打落点上的所有敌人（方案 3.3）；其他类型打单个目标 */
  const kind = rangeKindOf(w);
  const targets = isAreaKind(kind) ? (action.hit || []) : [action.target];

  const frontAliveNow = frontAlive(livingOf(otherSide(actor.side), ctx));
  for (const t of targets) {
    if (t.hp <= 0) continue;
    const trow = unitRow(t);
    const blockPenalty = isAreaKind(kind) ? 0 : rowBlockPenalty(kind, trow, frontAliveNow);
    const rec = resolveAttack(actor, t, w, ctx, { blockPenalty });
    pushLog(ctx, rec.文本, Object.assign({ 类型: '攻击', 单位: actor.key, 目标: t.key, 武器: w.name }, rec.字段));
  }
  spendWeapon(actor, action.entry, ctx);
}

/* ---------- overwatch（方案 5.2）：第一个行动的我方单位会被它先打一下 ---------- */
function runOverwatch(ally, ctx) {
  for (const e of livingOf('enemy', ctx)) {
    if (!hasOverwatch(e) || e.overwatchFiredTurn === ctx.turn) continue;
    if (ally.hp <= 0) return;
    const action = enemyAction(e, ctx);
    if (!action) continue;
    e.overwatchFiredTurn = ctx.turn;
    pushLog(ctx, `〔压制射击〕${e.name} 抢先开火`, { 类型: '压制射击', 单位: e.key, 目标: ally.key });
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
    ctx.result = checkResult(ctx);
    if (ctx.result) return;
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

/* ---------- 开场 ---------- */
function newBattle(allies, enemies, commands, rng) {
  const ctx = { turn: 1, allies, enemies, commands: commands || {}, rng, log: [], result: null };
  for (const u of livingUnits(ctx)) {
    u.weapons = u.weapons.map(e => Object.assign({}, e, {
      // 大招开场冷却 3 回合（方案第 4 节）
      cd: isUltimate(e.t) ? ULT_START_CD : (e.t.cd || 0),
    }));
  }
  pushLog(ctx, `战斗开始：我方 ${allies.length} 台 vs 敌方 ${enemies.length} 台`, { 类型: '开始' });
  return ctx;
}

/* ---------- simulate（方案第 9 节 M1 的对外接口） ---------- */
function simulate(我方, 敌方, 指令, 种子) {
  const rng = mulberry32(种子 >>> 0);
  const allies = makeUnits(我方, 'ally');
  const enemies = makeUnits(敌方, 'enemy');
  const ctx = newBattle(allies, enemies, 指令, rng);

  while (!ctx.result && ctx.turn <= MAX_TURN) {
    runTurn(ctx);
    if (ctx.result) break;
    if (ctx.turn >= MAX_TURN) { ctx.result = { 结果: '败', 原因: `第 ${MAX_TURN} 回合结束还没分出胜负（按撤退处理）` }; break; }
    endTurn(ctx);
    ctx.turn++;
  }
  if (!ctx.result) ctx.result = { 结果: '败', 原因: `第 ${MAX_TURN} 回合结束还没分出胜负（按撤退处理）` };
  pushLog(ctx, `战斗结束：${ctx.result.结果}（${ctx.result.原因}）`, { 类型: '结束' });

  return {
    结果: ctx.result.结果, 原因: ctx.result.原因, 回合数: ctx.turn,
    记录: ctx.log, 我方: ctx.allies, 敌方: ctx.enemies, 种子,
  };
}

/* ---------- 回合结束：buff / 冷却计时减 1（方案 3.2） ---------- */
function endTurn(ctx) {
  for (const u of livingUnits(ctx)) {
    for (const e of u.weapons) if (e.cd > 0) e.cd--;
    u.buffs = (u.buffs || []).filter(b => (b.剩余 = (b.剩余 == null ? 1 : b.剩余) - 1) > 0);
  }
}
