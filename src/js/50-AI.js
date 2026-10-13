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
 *   unitRow(u) / livingOf(side, ctx) / frontAlive(units) / 活位们(units)
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

/* 大招 = 战棋里 unlock 为 20 或 30 的武器，有开场冷却（方案第 4 节）。
 * ★ 2026-10-11 新加：**敌人自己的大招**（`战斗结构.敌方大招` 装上去的那批，标 `大招: true`）
 *   也算大招 —— 它的 `unlock` 是 1（敌人等级普遍 < 20，不能拿 unlock 当门），
 *   所以这里多认一个 `大招` 字段。我方的武器没有这个字段 → `isUltimate` 与改前逐字相同。
 * 开关「自动」= 冷却好了就放；「保留」= 这一回合不放（u.holdUlt）。 */
const ULT_UNLOCKS = [20, 30];
const isUltimate = w => !!w && (ULT_UNLOCKS.includes(w.unlock) || w.大招 === true);
const ultAllowed = (u, w) => isUltimate(w) && !u.holdUlt;

/* ---------- 修理阈值（作者 2026-10-10 拍板） ----------
 * 有人 HP 比例**低于这个值**时才优先修理；否则这个单位正常输出 / 上 debuff。
 * 出处：作者 2026-10-10 拍板（原来 M1 写的是「有伤就修」，见任务板 M1 段第 5 条）。
 * 要调就改这一个常量。0.6 = 60%。 */
const 修理阈值 = 0.6;

/* ---------- 5.1.2 目标优先级 ---------- */
/* 「能击破的目标优先（多个时打 HP 最高的那个，不浪费）；没有能击破的，
 *   打「期望伤害 ÷ 目标当前 HP」最大的。」                                         */
/* ★ 2026-10-13（难度上调第一步 · 第 2 步「AI 目标选择」）：
 *   **站位权重** —— 同一套判定里，**越靠前（能打到）的目标越优先**。
 *   作者原话：「让敌人优先打能打到的最前排（越靠前权重越高），让前排真的承伤」。
 *   ★ 这里**只改「挑谁打」的权重**：`rowReachable`（近战够不够得着）/
 *     `rowBlockPenalty`（直射被挡 −20）/ `areaSlots`（范围落点）**一个字节都没动**，
 *     所以「打不到后排的近战照样打不到」「被挡照样 −20」这两条规则照旧。
 *   ★ 权重乘在 `value`（期望伤害 ÷ 当前 HP）上、**不动 `canKill`** ——
 *     「这一下能击破就先击破」仍然是硬规则（方案 5.1.2 原样），站位只改「都打不死时先打谁」。
 *   ★ 为什么不是「硬指定前排」：这是**加权**，玩家用「全军防御 / 前守后攻」把前排的
 *     期望伤害降下来之后，敌人**仍然会**去挑后排里更划算的目标 —— 决策余地留着。
 *   参数在 `71-改动.js` 的 `难度调整.AI站位权重`（作者要调就改那一张表）。 */
function targetScore(exp, t, att) {
  const canKill = exp >= t.hp;
  const 权 = 站位权重(att, t);
  return { canKill, value: (canKill ? t.hp : exp / Math.max(1, t.hp)) * 权 };
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

/* 目标那一方的「局面」：前排还有没有人（近战够不够得着）+ 还活着的位集合。
 * ★ 作者 2026-10-10 拍板「按位阻挡」之后，直射有没有被挡**不能再只看「前排还有没有人」**——
 *   要看**这个后排位的阻挡位**（`遮挡位()`）里还有没有活人，所以把活位一次性算好传下去。 */
const 局面Of = foes => ({ 前排有人: frontAlive(foes), 活位: foes.map(u => u.slot) });

/* 一台机体对某个敌人最划算的（武器, 期望伤害）。
 * 局面 = 上面那个 `{前排有人, 活位}`：决定近战能不能够到后排、直射有没有被挡（−20）。 */
function bestWeaponOn(actor, target, pool, 局面, ctx) {
  let best = null;
  for (const e of pool) {
    const kind = rangeKindOf(e.t);
    const trow = unitRow(target);
    if (!rowReachable(kind, trow, 局面.前排有人)) continue;
    const 罚 = rowBlockPenalty(kind, target.slot, 局面.活位, actor, target);
    const exp = expectedDamage(actor, target, e.t, { blockPenalty: 罚, turn: ctx && ctx.turn, ctx });
    if (!best || exp > best.exp) best = { entry: e, exp, 被挡: 罚 < 0 };
  }
  return best;
}

/* ---------- 普通目标（近战 / 直射 / 曲射） ---------- */
function pickSingleTarget(actor, foes, pool, ctx) {
  const 局面 = 局面Of(foes);
  let best = null;
  for (const t of foes) {
    const w = bestWeaponOn(actor, t, pool, 局面, ctx);
    if (!w) continue;
    const score = targetScore(w.exp, t, actor);
    if (betterTarget(score, best && best.score)) best = { target: t, entry: w.entry, exp: w.exp, score, 被挡: w.被挡 };
  }
  return best;
}

/* ---------- 5.1.3 范围武器：按命中的敌人总期望伤害挑落点 ---------- */
function pickAreaTarget(actor, foes, pool, ctx) {
  let best = null;
  for (const e of pool) {
    if (!isAreaKind(rangeKindOf(e.t))) continue;
    for (let slot = 0; slot < SLOTS; slot++) {
      const hit = areaSlots(e.t, rowOfSlot(slot), colOfSlot(slot));
      const inside = foes.filter(t => hit.includes(t.slot));
      if (!inside.length) continue;
      const total = inside.reduce((n, t) => n + expectedDamage(actor, t, e.t, { blockPenalty: 0, ctx }), 0);
      // 并列时取格子编号小的（决定性；不要用 sort 的顺序去赌）
      if (!best || total > best.exp) best = { target: inside[0], entry: e, exp: total, slot, hit: inside };
    }
  }
  return best;
}

/* ---------- 5.1.2 全队方针怎么改「打进谁」（作者 2026-10-12 拍板的第一件，§1.2 / §1.3）----------
 * **方针本身不带任何加成**，它只改「挑谁打 / 打不打」；代价与收益全部来自现有规则。
 *   集中攻击（§1.3 第 2 条）：打得到目标位的都打它；打不到就照「全军突击」自由攻击。
 *   攻击后排（§1.3 第 3 条）：候选先只看对面**后排活着、而且这台用现有武器打得到**的单位，
 *                              在这些里照常按现有 AI 挑；一个都打不到 → 照「全军突击」。
 *   全军突击：**现在的「进攻」AI，逐字不变**（默认路径的唯一一条）。
 * 这两条都**不发明新规则**：挑目标用的还是 `pickSingleTarget` / `targetScore` 那一套。 */
const 指定目标位在 = (ctx, 位) => ((ctx && ctx.enemies) || []).find(u => u.slot === 位 && u.hp > 0) || null;

/** 集中攻击：打**指定那一位**。返回单个候选（形状和 `pickSingleTarget` 一样），打不到就 null。
 *  §1.3 第 2 条的规定**逐条照做**：
 *    ① 单体武器：照现在「集火」那一段的写法（`bestWeaponOn(actor, 指定, …)`），打不到才往下走自由攻击；
 *    ② 范围武器：落点**必须包含目标**的候选里挑期望伤害最高的（并列取格子号小的）；
 *    ③ **范围与单体之间照常比一比**（§1.2 的「打得到的都打它」指的是**目标**，
 *      不是「必须用单体武器」）—— `B2 蕾卡` 那把「影界·万刃归一」是一整排范围武器，
 *      打前排时比它的单体武器疼得多，这时照常选它；判定规矩和默认那条（能击破优先、再比期望值）一致。 */
function 集中攻击候选(actor, foes, pool, ctx) {
  const p = 当前方针(ctx);
  const 指定 = p.目标位 != null ? 指定目标位在(ctx, p.目标位) : null;
  if (!指定) return null;
  const 局面 = 局面Of(foes);
  let best = null;
  const 单 = pool.filter(e => !isAreaKind(rangeKindOf(e.t)));
  if (单.length) {
    const w = bestWeaponOn(actor, 指定, 单, 局面, ctx);
    /* ★ §1.3 第 2 条：「打不到的照常自由攻击」——`bestWeaponOn` 返回 null 就交给全军突击。 */
    if (w) best = { target: 指定, entry: w.entry, exp: w.exp, score: targetScore(w.exp, 指定, actor), 被挡: w.被挡 };
  }
  /* 范围武器：落点**必须包含目标**的候选里挑期望伤害最高的；没有能包含目标的落点 → 按单体规则处理。 */
  const 范围 = pool.filter(e => isAreaKind(rangeKindOf(e.t)));
  for (const e of 范围) {
    for (let slot = 0; slot < SLOTS; slot++) {
      const hit = areaSlots(e.t, rowOfSlot(slot), colOfSlot(slot));
      if (!hit.includes(指定.slot)) continue;                       // 落点必须包含目标
      const inside = foes.filter(t => hit.includes(t.slot));
      if (!inside.length) continue;
      const total = inside.reduce((n, t) => n + expectedDamage(actor, t, e.t, { blockPenalty: 0, ctx }), 0);
      const 分 = targetScore(total, 指定, actor);
      /* 与单体那条比：能击破优先，其次比期望值（并列时保留单体那条 = 格子号小的落点先来，决定性） */
      if (!best || (分.canKill && !best.score.canKill) || (分.canKill === best.score.canKill && 分.value > best.score.value)) {
        best = { target: 指定, entry: e, exp: total, score: 分, slot, hit: inside };
      }
    }
  }
  return best;
}

/** 攻击后排：候选先只看对面**后排活着、而且这台打得到**的；一个都打不到 → 返回 null（照全军突击）。
 *  §1.3 第 3 条：单体照现有 AI 在后排里挑；范围优先挑**覆盖后排单位最多**的落点，同样多再比期望伤害。 */
function 攻击后排候选(actor, foes, pool, ctx) {
  const 后 = foes.filter(t => unitRow(t) === ROW_BACK);
  if (!后.length) return null;
  const 单 = pool.filter(e => !isAreaKind(rangeKindOf(e.t)));
  let best = 单.length ? pickSingleTarget(actor, 后, 单, ctx) : null;
  /* 范围：优先「覆盖后排单位最多」，同样多再比期望伤害；一个覆盖后排的落点都没有 → 照突击 */
  const 范围 = pool.filter(e => isAreaKind(rangeKindOf(e.t)));
  let 范围最佳 = null;
  for (const e of 范围) {
    for (let slot = 0; slot < SLOTS; slot++) {
      const hit = areaSlots(e.t, rowOfSlot(slot), colOfSlot(slot));
      const inside = foes.filter(t => hit.includes(t.slot));
      if (!inside.length) continue;
      const 后排数 = inside.filter(t => unitRow(t) === ROW_BACK).length;
      if (!后排数) continue;                                        // 打不到后排的落点不算
      const total = inside.reduce((n, t) => n + expectedDamage(actor, t, e.t, { blockPenalty: 0, ctx }), 0);
      if (!范围最佳 || 后排数 > 范围最佳.后排数 || (后排数 === 范围最佳.后排数 && total > 范围最佳.exp)) {
        范围最佳 = { target: inside[0], entry: e, exp: total, slot, hit: inside, 后排数 };
      }
    }
  }
  if (范围最佳) {
    const 分 = targetScore(范围最佳.exp, 范围最佳.target, actor);
    if (!best || (分.canKill && !best.score.canKill) || (分.canKill === best.score.canKill && 分.value > best.score.value)) return 范围最佳;
  }
  return best;
}

/* ---------- 5.1 我方「进攻」（**默认路径：全军突击，逐字不变**） ---------- */
function chooseAttack(actor, ctx) {
  const foes = livingOf(otherSide(actor.side), ctx);
  if (!foes.length) return null;
  /* ★ §1.3 第 5 条：全军防御 / 前守后攻的前排**只禁止攻击**（含范围）——
     这里返回 null 之后 `aiAction()` 会照常试修理 / 支援，一个都挑不出来才去执行防御动作。
     `{忽略攻击禁令: true}` = `grantTargetOf()` / 平衡工具那种「估一下它本来能打多少」的调用。 */
  if (!(ctx && ctx.忽略攻击禁令) && typeof 禁止攻击 === 'function' && 禁止攻击(actor, ctx)) return null;
  const pool = weaponPool(actor, ctx);
  if (!pool.length) return null;

  /* 全队方针改「打进谁」（§1.3 第 2、3 条）：
       · 集中攻击 / 攻击后排**各自给一个候选**，然后和「全军突击」那两个候选放在一起比
         （能击破优先、再比期望值 —— 和默认那条**同一套排序**，所以并列时挑法完全一致）。
       · 方针那条候选比不过时**自然落到突击那条**（「打不到的照常自由攻击」/「后排全灭照突击」）。 */
  const 方针类 = 当前方针(ctx).类型;
  const 方针候选 = 方针类 === '集中攻击' ? 集中攻击候选(actor, foes, pool, ctx)
    : 方针类 === '攻击后排' ? 攻击后排候选(actor, foes, pool, ctx) : null;

  const areaPool = pool.filter(e => isAreaKind(rangeKindOf(e.t)));
  const singlePool = pool.filter(e => !isAreaKind(rangeKindOf(e.t)));

  const cands = [];
  if (方针候选) cands.push({ kind: 'attack', weapon: 方针候选.entry.t, target: 方针候选.target, expected: 方针候选.exp, score: 方针候选.score, entry: 方针候选.entry, hit: 方针候选.hit, slot: 方针候选.slot, 被挡: 方针候选.被挡 });
  if (singlePool.length) {
    const s = pickSingleTarget(actor, foes, singlePool, ctx);
    if (s) cands.push({ kind: 'attack', weapon: s.entry.t, target: s.target, expected: s.exp, score: s.score, entry: s.entry, 被挡: s.被挡 });
  }
  if (areaPool.length) {
    const a = pickAreaTarget(actor, foes, areaPool, ctx);
    if (a) cands.push({ kind: 'attack', weapon: a.entry.t, target: a.target, expected: a.exp, slot: a.slot, hit: a.hit, entry: a.entry });
  }
  if (!cands.length) return null;
  // 单体 / 范围之间：能击破的先打，其次比期望值；范围武器的 exp 是总伤害，直接比数值
  cands.sort((x, y) => {
    const kx = x.score ? x.score : targetScore(x.expected, x.target, actor);
    const ky = y.score ? y.score : targetScore(y.expected, y.target, actor);
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
    /* ★ §1.3 第 5 条：这里只是**排队**（谁被打断最亏），不是决策 —— 全军防御下所有单位都被禁止
       攻击，不豁免的话这一步会把「期望输出最高」退化成「位号最小」。所以传 `忽略攻击禁令`
       （再动出来的那一下**照当前方针**行动：全军防御下它照样只能修理 / 支援 / 防御）。 */
    const a = chooseAttack(u, Object.assign({}, ctx, { 忽略攻击禁令: true }));
    const v = a ? a.expected : 0;
    if (!best || v > best.v || (v === best.v && u.slot < best.u.slot)) best = { u, v };
  }
  return best.u;
}

function chooseSupport(actor, ctx) {
  /* ★ 2026-10-11：**已接的「势力支援武器」**要能被 `启用: false` 关掉（`势力支援关着()` 在 `72-势力.js`）——
     现在只有艾克赛琳的「好运加护」走这道门；没有那件武器 / 开着的时候它恒 false，行为与改动前逐字相同。 */
  const pool = usableWeapons(actor, ctx).filter(e => isSupportKind(rangeKindOf(e.t)) && !势力支援关着(e.t));
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
 * 顺序：修理 → 进攻 → 支援 → （方针禁止攻击时）**防御动作**。
 * 修理只在**有人 HP 比例低于 修理阈值（60%）**时才抢在进攻前面（作者 2026-10-10 拍板）；
 * 没人低于阈值就正常输出 / 上 debuff，一点血都不掉也不出手修。
 * 方案只写了「进攻」怎么挑；没有攻击手段的机体（例如第一期的 Feena）走到最后一步，
 * 用她唯一能做的事（月光祝福 / 再动），而不是直接跳过。
 * ★ 2026-10-12（§1.3 第 5 条「奶妈正常行动」）：全军防御 / 前守后攻的前排**只禁止攻击**，
 *   **不禁止行动** —— 上面三步（修理 / 进攻 / 支援）照常挑，只有「一个都挑不出来」时
 *   才执行防御动作（`{kind:'defend'}`：防御值 +50、下回合回 5% 最大 HP，数值沿用现有「防御」指令）。
 *   例：Iris / 维诺 / 苏菲照常修理；Feena 照常放「月光祝福」「再动」。 */
function aiAction(actor, ctx) {
  const heal = chooseHeal(actor, ctx);
  if (heal) return heal;
  const atk = chooseAttack(actor, ctx);
  if (atk) return atk;
  const sup = chooseSupport(actor, ctx);
  if (sup) return sup;
  if (typeof 禁止攻击 === 'function' && 禁止攻击(actor, ctx)) return { kind: 'defend' };
  return null;
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

/* 「近战类优先打够得到的、当前 HP 最少的」：候选先按**现成的**够不够得着过滤
 * （`rowReachable`，`30-射程.js` —— 近战要前排还有人），再在候选里比当前 HP（小的优先）。
 * ★ 2026-10-13（第 2 步「AI 目标选择」）：原来这一行写死 `unitRow(t) !== ROW_FRONT → 跳过`，
 *   改成用**同一个** `rowReachable` 判 —— 对纯近战单位两者**完全等价**（近战够不到后排），
 *   但「够不够得着」这件事从此**由射程那条规则说了算，不在这里再写一遍**
 *   （作者的约束：射程 / 阻挡 / 职业特色一条都不许改，只改挑谁打的权重）。 */
function pickLowestHp(actor, foes, pool, ctx) {
  const 局面 = 局面Of(foes);
  let best = null;
  for (const t of foes) {
    if (!pool.some(e => rowReachable(rangeKindOf(e.t), unitRow(t), 局面.前排有人))) continue;
    const w = bestWeaponOn(actor, t, pool, 局面, ctx);
    if (!w) continue;
    if (!best || t.hp < best.target.hp) best = { target: t, entry: w.entry, exp: w.exp, score: targetScore(w.exp, t, actor), 被挡: w.被挡 };
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
    const a = pickAreaTarget(actor, foes, areaPool, ctx);
    if (a && (!pick || a.exp > pick.exp)) pick = { target: a.target, entry: a.entry, exp: a.exp, slot: a.slot, hit: a.hit };
  }
  if (!pick) return null;
  return { kind: 'attack', weapon: pick.entry.t, target: pick.target, expected: pick.exp, slot: pick.slot, hit: pick.hit, entry: pick.entry, 被挡: !!pick.被挡 };
}

/* ---------- overwatch（替代战棋的压制射击，方案 5.2） ----------
 * 「有 overwatch 的敌人改成：第一个行动的我方单位会被它先打一下」。
 * 名单沿用战棋的 ENEMY_OVERWATCH（04-武器与机体.js），第一期是狙击型。
 * 具体「什么时候打、每回合几次」在战斗引擎（60-战斗.js）里执行，
 * 这里只提供判断，以及给 M3 的意图显示复用。 */
const hasOverwatch = u => u.side === 'enemy' && ENEMY_OVERWATCH.includes(u.key);

