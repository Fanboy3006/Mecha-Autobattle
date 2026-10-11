/* ============================================================================
 * 自动行为（AI）· 方案第 5 节
 * ----------------------------------------------------------------------------
 * 这个片段只做「挑一个动作」，不改状态、不算随机数，所以它是纯函数：
 *   同一个局面 → 同一个选择（决定性的比较 + 明确的并列规则）。
 *
 * 依赖（在 20-战斗计算.js / 40-单位.js / 30-射程.js 里定义，函数声明会提升，
 * 所以谁先谁后无所谓）：
 *   usableWeapons(u, ctx) → [{t: 模板武器, cd, uses, ...}]  「这台机体现在能用哪些武器」
 *   expectedDamage(att, def, w, opts) → 期望伤害（只用来比大小）
 *   unitRow(u) / livingOf(side, ctx) / frontAlive(side, ctx)
 *   rangeKindOf / rowReachable / rowBlockPenalty / isAreaKind / isHealKind / areaSlots
 *
 * 方案里的对应关系：
 *   5.1 我方「进攻」怎么挑       → chooseAttack()
 *   5.2 敌方（普通 / 近战 / 狙击 / overwatch / Boss）→ enemyAction()
 *   第 4 节 大招开关（自动 / 保留）→ u.holdUlt
 *
 * Boss 脚本（`61-Boss.js`，方案 5.2 的「每 N 回合大技能 + 半血换阶段」）**不写在这里**：
 * 它只在 `weaponPool` 里挂了一个纯函数钩子（`Boss本回合禁用`），
 * 由 `60-战斗.js` 的 `单位动作` 把敌方单位交给 `bossTurn`。没配脚本的敌人行为不变。
 * ========================================================================== */

/* 大招 = 战棋里 unlock 为 20 或 30 的武器，有开场冷却 3 回合（方案第 4 节）。
 * 开关「自动」= 冷却好了就放；「保留」= 这一回合不放（u.holdUlt）。 */
const ULT_UNLOCKS = [20, 30];
const isUltimate = w => !!w && ULT_UNLOCKS.includes(w.unlock);
const ultAllowed = (u, w) => isUltimate(w) && !u.holdUlt;

/* ---------- 修理阈值（作者 2026-10-10 拍板） ----------
 * 有人 HP 比例**低于这个值**时才优先修理；否则这个单位正常输出 / 上 debuff。
 * 出处：作者 2026-10-10 拍板（原来 M1 写的是「有伤就修」，见任务板 M1 段第 5 条）。
 * 要调就改这一个常量。0.6 = 60%。 */
const 修理阈值 = 0.6;

/* ---------- 5.1.2 目标优先级 ---------- */
/* 「能击破的目标优先（多个时打 HP 最高的那个，不浪费）；没有能击破的，
 *   打「期望伤害 ÷ 目标当前 HP」最大的。」                                         */
function targetScore(exp, t) {
  const canKill = exp >= t.hp;
  return { canKill, value: canKill ? t.hp : exp / Math.max(1, t.hp) };
}
/* 返回 true 表示 a 比 b 更该打 */
function betterTarget(a, b) {
  if (!b) return true;
  if (a.canKill !== b.canKill) return a.canKill;
  return a.value > b.value;
}

/* ---------- 5.1.1 武器优先级 ---------- */
/* 「能用的武器里，按对目标的期望伤害最大的选；大招开关为自动且冷却好时，大招优先。」 */
function weaponPool(actor, ctx) {
  const pool = usableWeapons(actor, ctx).filter(e => {
    const kind = rangeKindOf(e.t);
    if (kind === null || isHealKind(kind) || isSupportKind(kind)) return false;   // 被动 / 修理 / 支援 不参与「进攻」
    if (isUltimate(e.t) && actor.holdUlt) return false;   // 大招开关「保留」= 这一回合不放（方案第 4 节）
    /* 站桩 Boss 脚本（61-Boss.js）：间隔外不许把「大技能武器」当普通武器用，
       否则「每 N 回合放一次」就变成「每回合都放」。没配脚本的单位不受影响。 */
    if (Boss本回合禁用(actor, ctx, e.t)) return false;
    return true;
  });
  const ults = pool.filter(e => ultAllowed(actor, e.t));
  return ults.length ? ults : pool;                  // 大招优先（方案 5.1.1）
}

/* 一台机体对某个敌人最划算的（武器, 期望伤害）。
 * frontAliveNow：敌方前排是否还有人（决定近战能不能够到后排、直射有没有被挡）。 */
function bestWeaponOn(actor, target, pool, frontAliveNow, ctx) {
  let best = null;
  for (const e of pool) {
    const kind = rangeKindOf(e.t);
    const trow = unitRow(target);
    if (!rowReachable(kind, trow, frontAliveNow)) continue;
    const exp = expectedDamage(actor, target, e.t, { blockPenalty: rowBlockPenalty(kind, trow, frontAliveNow, actor), turn: ctx && ctx.turn });
    if (!best || exp > best.exp) best = { entry: e, exp };
  }
  return best;
}

/* ---------- 普通目标（近战 / 直射 / 曲射） ---------- */
function pickSingleTarget(actor, foes, pool, ctx) {
  const frontAliveNow = frontAlive(foes);
  let best = null;
  for (const t of foes) {
    const w = bestWeaponOn(actor, t, pool, frontAliveNow, ctx);
    if (!w) continue;
    const score = targetScore(w.exp, t);
    if (betterTarget(score, best && best.score)) best = { target: t, entry: w.entry, exp: w.exp, score };
  }
  return best;
}

/* ---------- 5.1.3 范围武器：按命中的敌人总期望伤害挑落点 ---------- */
function pickAreaTarget(actor, foes, pool) {
  let best = null;
  for (const e of pool) {
    if (!isAreaKind(rangeKindOf(e.t))) continue;
    for (let slot = 0; slot < SLOTS; slot++) {
      const hit = areaSlots(e.t, rowOfSlot(slot), colOfSlot(slot));
      const inside = foes.filter(t => hit.includes(t.slot));
      if (!inside.length) continue;
      const total = inside.reduce((n, t) => n + expectedDamage(actor, t, e.t, { blockPenalty: 0 }), 0);
      // 并列时取格子编号小的（决定性；不要用 sort 的顺序去赌）
      if (!best || total > best.exp) best = { target: inside[0], entry: e, exp: total, slot, hit: inside };
    }
  }
  return best;
}

/* ---------- 5.1 我方「进攻」 ---------- */
function chooseAttack(actor, ctx) {
  const foes = livingOf(otherSide(actor.side), ctx);
  if (!foes.length) return null;
  const pool = weaponPool(actor, ctx);
  if (!pool.length) return null;

  /* 「集火 ▶ 目标」（方案第 4 节）：玩家点了谁就打谁；打不到（例如近战够不到后排）
     就按「进攻」处理，继续往下走。 */
  if (actor.指令 === '集火') {
    const 指定 = (actor.指定目标 && actor.指定目标.hp > 0) ? actor.指定目标
      : (actor.指定目标位 != null ? foes.find(t => t.slot === actor.指定目标位) : null);
    if (指定) {
      const w = bestWeaponOn(actor, 指定, pool, frontAlive(foes), ctx);
      if (w) return { kind: 'attack', weapon: w.entry.t, target: 指定, expected: w.exp, entry: w.entry, 集火: true };
    }
  }

  const areaPool = pool.filter(e => isAreaKind(rangeKindOf(e.t)));
  const singlePool = pool.filter(e => !isAreaKind(rangeKindOf(e.t)));

  const cands = [];
  if (singlePool.length) {
    const s = pickSingleTarget(actor, foes, singlePool, ctx);
    if (s) cands.push({ kind: 'attack', weapon: s.entry.t, target: s.target, expected: s.exp, score: s.score, entry: s.entry });
  }
  if (areaPool.length) {
    const a = pickAreaTarget(actor, foes, areaPool);
    if (a) cands.push({ kind: 'attack', weapon: a.entry.t, target: a.target, expected: a.exp, slot: a.slot, hit: a.hit, entry: a.entry });
  }
  if (!cands.length) return null;
  // 单体 / 范围之间：能击破的先打，其次比期望值；范围武器的 exp 是总伤害，直接比数值
  cands.sort((x, y) => {
    const kx = x.score ? x.score : targetScore(x.expected, x.target);
    const ky = y.score ? y.score : targetScore(y.expected, y.target);
    if (kx.canKill !== ky.canKill) return kx.canKill ? -1 : 1;
    return ky.value - kx.value;
  });
  return cands[0];
}

/* ---------- 修理：我方任意一台，优先 HP 比例最低的（方案 3.3） ----------
 * 什么时候该修理、而不是进攻：**有人 HP 比例低于 修理阈值（0.6 = 60%）时才修**，
 * 否则返回 null、让 `aiAction` 往下走去正常出手（作者 2026-10-10 拍板，阈值在上面）。
 * 注意：修理武器拿不拿得到由 `usableWeapons` / `weaponPlayable` 决定，这里**不额外卡条件**，
 * 所以修理工在该修的时候一定拿得到修理武器（tests/heal.js 第 [2] 段盯着这一条）。 */
function chooseHeal(actor, ctx) {
  const pool = usableWeapons(actor, ctx).filter(e => isHealKind(rangeKindOf(e.t)));
  if (!pool.length) return null;
  const mates = livingOf(actor.side, ctx);
  const hurt = mates.filter(u => u.hp / u.maxHp < 修理阈值);
  if (!hurt.length) return null;
  hurt.sort((a, b) => (a.hp / a.maxHp) - (b.hp / b.maxHp) || a.slot - b.slot);
  const target = hurt[0];
  const e = pool[0];
  return { kind: 'heal', weapon: e.t, target, entry: e };
}

/* ---------- 支援类武器（加增益 / 再动）----------
 * 作者 2026-10-10 定：Feena 的「月光祝福」要做进去（全体队友不含自己、到本回合结束），
 * 她的大招「再动」= 让本回合已经行动过、期望伤害最高的队友立刻再行动一次。
 * 方案第 4 节明写「大招开关自动 = 冷却好了就放」，所以这里先挑能放的大招，再挑普通增援。 */
function grantTargetOf(actor, ctx) {
  const done = livingOf(actor.side, ctx).filter(u => u !== actor && u.actedTurn === ctx.turn && u.grantedTurn !== ctx.turn);
  if (!done.length) return null;
  let best = null;
  for (const u of done) {
    const a = chooseAttack(u, ctx);
    const v = a ? a.expected : 0;
    if (!best || v > best.v || (v === best.v && u.slot < best.u.slot)) best = { u, v };
  }
  return best.u;
}

function chooseSupport(actor, ctx) {
  const pool = usableWeapons(actor, ctx).filter(e => isSupportKind(rangeKindOf(e.t)));
  if (!pool.length) return null;
  const ults = pool.filter(e => ultAllowed(actor, e.t));
  const 有序 = (ults.length ? ults : []).concat(pool.filter(e => !ults.includes(e)));
  for (const e of 有序) {
    if (e.t.grant) {
      const t = grantTargetOf(actor, ctx);
      // 还没人行动过就没人能「再动」，这时退回去放增益
      if (t) return { kind: 'grant', weapon: e.t, target: t, entry: e };
      continue;
    }
    if (e.t.buff) {
      const mates = livingOf(actor.side, ctx).filter(u => u !== actor);
      if (mates.length) return { kind: 'buff', weapon: e.t, targets: mates, entry: e };
    }
  }
  return null;
}

/* ---------- 我方一台机体的动作 ----------
 * 顺序：修理 → 进攻 → 支援。修理只在**有人 HP 比例低于 修理阈值（60%）**时才抢在进攻前面
 * （作者 2026-10-10 拍板）；没人低于阈值就正常输出 / 上 debuff，一点血都不掉也不出手修。
 * 方案只写了「进攻」怎么挑；没有攻击手段的机体（例如第一期的 Feena）走到最后一步，
 * 用她唯一能做的事（月光祝福 / 再动），而不是直接跳过。 */
function aiAction(actor, ctx) {
  const heal = chooseHeal(actor, ctx);
  if (heal) return heal;
  const atk = chooseAttack(actor, ctx);
  if (atk) return atk;
  return chooseSupport(actor, ctx);
}

/* ---------- 5.2 敌方 ---------- */
/* 敌方的「战斗分类」：模板的 tags.战斗分类；没有就按武器推断。 */
function combatClassOf(u, ctx) {
  const t = u.tags && u.tags.战斗分类;
  if (t) return t;
  const kinds = usableWeapons(u, ctx || { turn: 1 }).map(e => rangeKindOf(e.t));
  if (kinds.every(k => k === KIND_MELEE)) return '近卫';
  if (kinds.some(k => k === KIND_INDIRECT)) return '狙击';
  return '重装';
}

/* 「近战敌人优先打我方前排血最少的」：只在候选目标里比当前 HP（小的优先）。 */
function pickLowestHp(actor, foes, pool, ctx) {
  const frontAliveNow = frontAlive(foes);
  let best = null;
  for (const t of foes) {
    if (unitRow(t) !== ROW_FRONT) continue;
    const w = bestWeaponOn(actor, t, pool, frontAliveNow, ctx);
    if (!w) continue;
    if (!best || t.hp < best.target.hp) best = { target: t, entry: w.entry, exp: w.exp, score: targetScore(w.exp, t) };
  }
  return best;
}

/* 「狙击类优先打后排」：后排打得到就打后排，打不到再按普通规则。 */
function pickBackRowFirst(actor, foes, pool, ctx) {
  const back = foes.filter(t => unitRow(t) === ROW_BACK);
  if (back.length) {
    const s = pickSingleTarget(actor, back, pool, ctx);
    if (s) return s;
  }
  return pickSingleTarget(actor, foes, pool, ctx);
}

function enemyAction(actor, ctx) {
  const foes = livingOf(otherSide(actor.side), ctx);
  if (!foes.length) return null;
  const pool = weaponPool(actor, ctx);
  if (!pool.length) return null;

  const cls = combatClassOf(actor, ctx);
  const allMelee = pool.every(e => rangeKindOf(e.t) === KIND_MELEE);

  let pick = null;
  if (cls === '狙击') pick = pickBackRowFirst(actor, foes, pool, ctx);
  else if (allMelee) pick = pickLowestHp(actor, foes, pool, ctx);
  if (!pick) pick = pickSingleTarget(actor, foes, pool, ctx);

  // 范围武器按总期望伤害比一比（5.1.3 对敌方同样适用）
  const areaPool = pool.filter(e => isAreaKind(rangeKindOf(e.t)));
  if (areaPool.length) {
    const a = pickAreaTarget(actor, foes, areaPool);
    if (a && (!pick || a.exp > pick.exp)) pick = { target: a.target, entry: a.entry, exp: a.exp, slot: a.slot, hit: a.hit };
  }
  if (!pick) return null;
  return { kind: 'attack', weapon: pick.entry.t, target: pick.target, expected: pick.exp, slot: pick.slot, hit: pick.hit, entry: pick.entry };
}

/* ---------- overwatch（替代战棋的压制射击，方案 5.2） ----------
 * 「有 overwatch 的敌人改成：第一个行动的我方单位会被它先打一下」。
 * 名单沿用战棋的 ENEMY_OVERWATCH（04-武器与机体.js），第一期是狙击型。
 * 具体「什么时候打、每回合几次」在战斗引擎（60-战斗.js）里执行，
 * 这里只提供判断，以及给 M3 的意图显示复用。 */
const hasOverwatch = u => u.side === 'enemy' && ENEMY_OVERWATCH.includes(u.key);
