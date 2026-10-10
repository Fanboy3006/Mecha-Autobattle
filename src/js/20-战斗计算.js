/* ============================================================================
 * 战斗计算（方案 6.1）· 照抄机甲战棋的数值部分
 * ----------------------------------------------------------------------------
 * 抄的是战棋 v0.37/v0.42 的公式，**去掉朝向、地形、区域、压制、援护、特技、藏品、肉鸽**。
 * 每段的出处都写在注释里，Claude 复审时（方案第 11 节）对着看：
 *
 *   命中 / 暴击          ← 15-战斗计算.js:11-31     （去掉 zone / 地形 / tfx / 烟雾 / 赌神）
 *   属性                  ← 15-战斗计算.js:46-49     （STAT_KEY / statNames / statVal / atkStat，原样）
 *   伤害系数             ← 15-战斗计算.js:91        coef = 1 +（攻击能力值 − 防御值）/ 100
 *                          方案里把这个系数叫 `statCoef`；**战棋源码里没有这个函数名**，
 *                          它是写死在 dmgCore 里的一行内联表达式。这里补了一个同名函数，
 *                          数值与战棋完全一致（见下面 statCoef）。
 *   伤害主体             ← 15-战斗计算.js:52-106    （去掉 g.pct / Hooks / 朝向 pierce / 地形）
 *   暴击倍率             ← 03-能力与减免管线.js:164  （×2；零式 ×2.5 是特技，第一期不做）
 *   弱点 / 抗性          ← 03-能力与减免管线.js:170-181（去掉「背面」这一项，新项目没有朝向）
 *   减免管线             ← 03-能力与减免管线.js:202-242（只留数值类：防御姿态 / 物理减免 /
 *                          防御增益 / 能量屏障 / λ 力场 / 护盾；其余条目是特技，第一期不做）
 *   修理回复量           ← 17-战斗执行.js:259
 *   武器可用性 / 开场冷却 ← 13-武器可用性.js:7-16    （unlock 等级门、次数、冷却、startCd）
 *   武器数值取升级后      ← 13-武器可用性.js:32      wv()
 *
 * 【方案与源码不一致的地方（已记在 协作/任务板.md 里，等作者确认）】
 *   1. 方案写的 `statCoef` / `ENEMY_SCALE` 在战棋源码里都不存在（`ENEMY_SCALE` 见 11-敌方梯队.js 的说明）；
 *   2. 方案写的减免顺序「屏障 → 百分比 → 装甲 → 力场 → 护盾」与源码不同，
 *      源码是：弱点/抗性并进威力 → 装甲 → 防御值（stage 2 只是给 D 加数）→ 公式 → 屏障 → λ 力场 → 护盾。
 *      这里按**源码**实现。
 * ========================================================================== */

/* ---------- 属性 ---------- */
const STAT_KEY = { 格斗: 'melee', 射击: 'shoot', 觉醒: 'awaken', 防御: 'defense' };
const statNames = w => String(w.stat || '射击').split('+');
const statVal = (u, k) => u[STAT_KEY[k]] ?? 100;
const atkStat = (u, w) => Math.round(statNames(w).reduce((a, k) => a + statVal(u, k), 0) * (w.statMul || 1));

/* ---------- 增益 / 装甲 / 破防 ---------- */
const buffSum = (u, k) => (u.buffs || []).reduce((a, b) => a + (b[k] || 0), 0);
const effArmor = u => Math.max(0, Math.round(u.armor * Math.max(0, 1 + buffSum(u, 'armorPct') / 100)) - (u.armorCut || 0));
const breakSum = u => (u.debuffs || []).reduce((a, b) => a + b.pct, 0);
const defMul = u => Math.max(0, 1 - breakSum(u) / 100);
const critMul = () => 2;   // 战棋：暴击威力 ×2（零式 ×2.5 走特技，第一期不做）

/* 地图炮必中（战棋原样）。注意：新项目的「范围」类就是从 map / support 换算来的，
   所以从 map 过来的范围武器保留战棋的必中；从 support 过来的走正常命中判定。 */
const isSure = w => w.fire === 'map' || w.fire === 'passive';

/* 能力开关。战棋里还有「Lv10 起才生效」的 ABIL 等级表（属于特技），第一期去掉。 */
const abilOn = (u, k) => !!u && Array.isArray(u.abilities) && u.abilities.includes(k);
const shieldOn = u => !!u && u.shield > 0 && u.shieldHp > 0;
const lsLeft = (u, turn) => u.lsTurn !== turn ? 2 : 2 - (u.lsCount || 0);   // λ 力场：每回合 2 次

/* ---------- 命中 / 暴击 ---------- */
function hitRate(att, w, def, opts = {}) {
  if (isSure(w)) return { hit: 100, raw: 100, eva: 0, sure: true };
  const eva = Math.max(0, def.eva - (def.dodgePen || 0)) + buffSum(def, 'eva') + (def.moveEva || 0);
  const h = (opts.baseHit ?? w.hit) - eva + Math.round(((att.aim ?? 160) - 160) / 2) + buffSum(att, 'hit') + (opts.blockPenalty || 0);
  return { hit: clamp(Math.round(h), 0, 100), raw: Math.round(h), eva };
}
function critRate(w, att) {
  if (isSure(w)) return 0;
  return clamp(10 + ((att && att.critBase) || 0) + (w.critMod || 0) + buffSum(att, 'crit'), 0, 100);
}

/* ---------- 弱点 / 抗性 ---------- */
/* 正数 = 弱点（生成阶段增伤），负数 = 抗性（百分比减免阶段，受破防削弱）。没有「背面」。 */
function weakList(def, w, o = {}) {
  if (!def.weak || !w) return [];
  const out = [];
  for (const [k, v] of Object.entries(def.weak)) {
    const ok = (k === '光束' || k === '物理') ? w.dmgType === k
      : k === '近战' ? w.fire === 'melee'
      : k === '直射' ? w.fire === 'direct'
      : k === '曲射' ? w.fire === 'indirect'
      : k === '范围' ? isSure(w)
      : k === '暴击' ? !!o.crit
      : k === '多段' ? (w.special === 'multi' || w.hits > 1)
      : false;
    if (ok) out.push([k, v]);
  }
  return out;
}

/* ---------- 减免管线 ----------
 * stage 1 / 3 / 4 = 公式算完之后的门槛与吸收；stage 2 = 给「防御值」加数。
 * 第一期只保留数值类，带特技的条目（地形 / 正面装甲 / GN 全盾 / 光束反射 /
 * SEED 防御 / λ 驱动器 / 减伤）**不做**，等 Claude 出换算方案（方案 6.2）。 */
const REDUCTIONS = [
  { id: 'guard', name: '防御姿态', stage: 2, applies: c => !!c.def.defending, def: () => 50 },
  { id: 'physRed', name: '物理减免', stage: 2, applies: c => c.w.dmgType === '物理' && buffSum(c.def, 'physRed') > 0, def: c => buffSum(c.def, 'physRed') },
  { id: 'buffDef', name: '防御增益', stage: 2, applies: c => buffSum(c.def, 'def') !== 0, def: c => buffSum(c.def, 'def') },
  {
    id: 'barrier', name: '能量屏障', stage: 1,
    applies: c => abilOn(c.def, 'barrier') && c.def.barrierLeft > 0 && c.dmg <= 2500,
    apply: c => { c.dmg = 0; c.nullified = true; if (!c.preview) c.def.barrierLeft--; return `≤2500 无效化（剩 ${c.def.barrierLeft} 次）`; },
  },
  {
    id: 'lambdaShield', name: 'λ 力场', stage: 3,
    applies: c => c.dmg > 0 && abilOn(c.def, 'lambdaShield') && lsLeft(c.def, c.turn) > 0,
    apply: c => {
      const a = Math.round(3000 * c.defMul);
      c.dmg = Math.max(0, c.dmg - a);
      if (!c.preview) { if (c.def.lsTurn !== c.turn) { c.def.lsTurn = c.turn; c.def.lsCount = 0; } c.def.lsCount++; }
      return `−${a}（本回合剩 ${Math.max(0, lsLeft(c.def, c.turn) - (c.preview ? 1 : 0))} 次）`;
    },
  },
  {
    id: 'shield', name: '护盾', stage: 4,
    applies: c => c.dmg > 0 && shieldOn(c.def),
    apply: c => {
      const a = Math.min(c.dmg, c.def.shieldHp);
      c.dmg -= a;
      if (!c.preview) c.def.shieldHp -= a;
      return `吸收 ${a}（护盾剩 ${c.def.shieldHp - (c.preview ? a : 0)}）`;
    },
  },
];

/* ---------- 伤害系数 ---------- */
/* 方案里叫 `statCoef`：战棋源码 15-战斗计算.js:91 的 `const coef = 1 + (atk - D) / 100`。 */
const statCoef = (atk, D) => 1 + (atk - D) / 100;

/* ---------- 伤害主体 ----------
 * 伤害 =（威力 − 装甲）× statCoef（攻击能力值 − 防御值），命中后最少 10。
 * o = {power, crit, preview, turn, useStat}
 * 返回 c：{dmg, steps, nullified, defMul}；preview=true 时**不改任何状态**。 */
function dmgCore(att, w, def, o = {}) {
  const c = {
    att, def, w, preview: o.preview !== false, crit: !!o.crit, turn: o.turn || 0,
    defMul: defMul(def), steps: [], nullified: false,
  };
  const special = w.dmgType === '特殊', ign = !!w.ignoreDef, useStat = o.useStat !== false;

  /* 1. 武器威力：弱点 / 抗性 → 暴击 */
  let W = o.power;
  const wn = [`威力 ${o.power}`];
  const wk = weakList(def, w, c);
  if (wk.length) {
    const pos = wk.filter(([, v]) => v > 0).reduce((a, [, v]) => a + v, 0);
    const neg = wk.filter(([, v]) => v < 0).reduce((a, [, v]) => a + v, 0) * (ign ? 0 : c.defMul);
    const v = Math.max(-95, pos + neg);
    if (v) { W *= 1 + v / 100; wn.push(wk.map(([k, x]) => `${x > 0 ? '弱点' : '抗性'}·${k} ${x > 0 ? '+' : ''}${x}%`).join('、')); }
  }
  if (c.crit) { const x = critMul(); W *= x; wn.push(`暴击 ×${x}`); }
  W = Math.round(W);

  /* 2. 装甲（特殊伤害 / 无视防御按 0） */
  let A = 0;
  if (!special && !ign) A = Math.round(effArmor(def) * c.defMul);

  /* 3. 攻击能力值（战棋里还有特技 / 藏品 / 肉鸽的加成，第一期都没有） */
  const atk = (useStat && att) ? atkStat(att, w) : 0;

  /* 4. 防御值：基础防御 + stage 2 的数值条目，整体 × 破防 */
  let D = 0; const dn = [];
  if (!special && !ign) {
    if (useStat && def.defense) { D += def.defense; dn.push(`防御 ${def.defense}`); }
    for (const r of REDUCTIONS) {
      if (r.stage !== 2 || !r.applies(c)) continue;
      const v = r.def(c); if (!v) continue;
      D += v; dn.push(`${r.name} ${v < 0 ? '−' + (-v) : '+' + v}`);
    }
    if (c.defMul < 1 && D) { D = Math.round(D * c.defMul); dn.push(`破防 ×${+c.defMul.toFixed(2)}`); }
  }

  const coef = statCoef(atk, D), base = Math.max(0, W - A);
  c.dmg = Math.max(10, Math.round(base * coef));
  c.steps.push(`威力 ${W}${A ? ` − 装甲 ${A}` : ''} = ${base}${wn.length > 1 ? `（${wn.join('，')}）` : ''}`);
  c.steps.push(`× statCoef（1 +（攻击 ${atk} − 防御 ${D}）/ 100）= ×${+coef.toFixed(2)}${dn.length ? `（防御：${dn.join('、')}）` : ''}`);
  c.steps.push(`= ${c.dmg}${base * coef < 10 ? '（命中后最少 10）' : ''}`);

  if (ign) { c.steps.push('无视防御：不经过屏障 / 力场 / 护盾'); return c; }

  /* 5. 能量屏障 → λ 力场 → 护盾（战棋 03:99-104） */
  for (const stg of [1, 3, 4]) for (const r of REDUCTIONS) {
    if (r.stage !== stg || !r.applies(c)) continue;
    const note = r.apply(c); c.dmg = Math.max(0, Math.round(c.dmg));
    c.steps.push(`${r.name} ${note} → ${c.dmg}`);
    if (c.nullified) return c;
  }
  return c;
}

/* ---------- 升级后的武器数值（13-武器可用性.js:32，原样） ----------
 * Lv30 之类的 upgrades 会覆盖 power / range；方案第 2 节说升级加点照搬。 */
function wv(u, w, key) { let v = w[key]; for (const up of w.upgrades || []) if (u.lv >= up.lv && up[key] != null) v = up[key]; return v; }

/* ---------- 期望伤害（方案 5.1.1：命中率 × 伤害，暴击按 1 + 暴击率 计） ---------- */
function expectedDamage(att, def, w, opts = {}) {
  const hits = Math.max(1, w.hits || 1);
  const hr = hitRate(att, w, def, { blockPenalty: opts.blockPenalty || 0 }).hit / 100;
  const crit = 1 + critRate(w, att) / 100;
  const dmg = dmgCore(att, w, def, { power: wv(att, w, 'power'), preview: true, turn: opts.turn || 0 }).dmg;
  return hr * dmg * crit * hits;
}

/* ---------- 武器可用性（13-武器可用性.js:7-16 / 18-31 的数值部分） ---------- */
const START_CD_ULT = 3;   // 大招（unlock ≥ 20）开场冷却 3 回合
const startCdOf = w => w.startCd != null ? w.startCd : (w.unlock >= 20 ? START_CD_ULT : 0);

/* 第一期不做的武器（方案 6.2）：带 special 的特殊武器全部不用，
   只有「多段」是方案明确要保留的，所以 special === 'multi' 放行。 */
function weaponPlayable(w) {
  if (w.fire === 'passive' || w.fire === 'device') return false;
  if (w.special && w.special !== 'multi') return false;
  return true;
}

/** 这台机体现在能用哪些武器（等级门 / 次数 / 冷却 / 开场冷却）。返回运行期条目。 */
function usableWeapons(u, ctx) {
  return (u.weapons || []).filter(e => {
    const w = e.t;
    if (!weaponPlayable(w)) return false;
    if (u.lv < w.unlock) return false;
    if (e.uses != null && e.uses <= 0) return false;
    if (e.cd > 0) return false;
    if (ctx && ctx.turn != null && ctx.turn < e.readyTurn) return false;
    if (!(w.power > 0) && !isHealKind(rangeKindOf(w))) return false;
    return true;
  });
}

/** 用掉一次：普通冷却 + 次数 −1（开场冷却由 readyTurn 管，不在这里） */
function spendWeapon(u, entry) {
  if (!entry) return;
  if (entry.t.cd) entry.cd = entry.t.cd;
  if (entry.uses != null) entry.uses--;
}

/* ---------- 修理 ---------- */
const healAmount = (u, w) => Math.round(w.power * u.shoot / 100);   // 17-战斗执行.js:259

/* ---------- 一次普通攻击的结算（第一期唯一的攻击路径） ----------
 * 随机数全部走 ctx.rng（带种子，方案 6.1）。返回一条战斗记录用的文本 + 字段。
 * 多段：w.hits 段，每段独立判定命中与暴击；武器写了 w.step 时命中后逐段递减命中（战棋 multi 的做法）。 */
function resolveAttack(att, def, w, ctx, opts = {}) {
  const rng = ctx.rng;
  const blockPenalty = opts.blockPenalty || 0;
  const sure = isSure(w);
  const hits = Math.max(1, w.hits || 1);
  const rolls = [];
  let total = 0, landed = 0, crits = 0, p = w.hit;

  for (let i = 0; i < hits; i++) {
    const q = hitRate(att, w, def, { baseHit: p, blockPenalty }).hit;
    const hit = sure || rng() * 100 < q;
    if (hit) {
      const cr = !sure && rng() * 100 < critRate(w, att);
      const c = dmgCore(att, w, def, { power: wv(att, w, 'power'), crit: cr, preview: false, turn: ctx.turn });
      total += c.dmg; landed++; if (cr) crits++;
      rolls.push(`第 ${i + 1} 段（${sure ? '必中' : q + '%'}）${cr ? '暴击 ' : ''}${c.dmg}`);
      if (c.nullified) break;
      if (w.step) p -= w.step;
    } else {
      rolls.push(`第 ${i + 1} 段（${q}%）未中`);
      if (w.step) p += w.step;
    }
    if (def.hp - total <= 0) break;
  }

  def.hp = Math.max(0, def.hp - total);
  const 段 = hits > 1 ? `${landed}/${hits} 段 ` : '';
  return {
    文本: landed
      ? `${att.name}【${w.name}】→ ${def.name}：${段}伤害 ${total}${crits ? `（暴击 ${crits} 次）` : ''}`
      : `${att.name}【${w.name}】→ ${def.name}：未命中（${rolls.join('；')}）`,
    字段: { 命中: landed > 0, 伤害: total, 段数: hits, 命中段数: landed, 暴击: crits, 目标剩余HP: def.hp, 详情: rolls.join('；') },
  };
}
