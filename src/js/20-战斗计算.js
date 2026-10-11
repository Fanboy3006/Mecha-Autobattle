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
/* `觉醒` 这一项读**战斗内会成长**的觉醒值（框架 `势力觉醒值()`，在 `72-势力.js`）——
 * 出处：战棋 `15-战斗计算.js:48` `statVal = (u,k) => STAT_KEY[k]==='awaken' ? awakenOf(u) : (u[STAT_KEY[k]] ?? 100)`
 * （v0.41.4 卫星国防军：觉醒值在战斗中成长，17b:198 的 `awakenOf = 模板 awaken + 本场成长`）。
 * ★ 没有势力成长的单位（**全部敌人** + 没有 `awaken` 字段的机体）算出来还是 `u.awaken ?? 100`，
 *   与改动前**逐字相同** —— 只有吃势力特色的我方单位会变（第一件 = 卫星国防军 SEED）。 */
const statVal = (u, k) => k === '觉醒' ? 势力觉醒值(u) : (u[STAT_KEY[k]] ?? 100);
const atkStat = (u, w) => Math.round(statNames(w).reduce((a, k) => a + statVal(u, k), 0) * (w.statMul || 1));

/* ---------- 增益 / 装甲 / 破防 ---------- */
const buffSum = (u, k) => (u.buffs || []).reduce((a, b) => a + (b[k] || 0), 0);
/* 有效装甲 = 装甲 ×（1 + `armorPct`）− 破甲 —— 战棋 `15-战斗计算.js:5`。
 * ★ 2026-10-11：**势力特色的装甲那一路**（框架第 16 个钩子 `势力装甲()`，实现在 `72-势力.js`）
 *   乘在 `u.armor` 上、与战棋同一个落点（`hasTrait(u,'steadfast') && !u.movedThisRound ? 1.3 : 1` 就在那里）。
 *   第一条用它的是月球王国的「不动如山」（阿布拉德，装甲 +30%，触发条件是换义过的「本回合没换位」）。
 *   **没有势力条目 → `势力装甲(u)` 恒 0 → 这一行与改动前逐字相同**（`× (1 + 0)`）。 */
const effArmor = u => Math.max(0, Math.round(u.armor * (1 + 势力装甲(u) / 100) * Math.max(0, 1 + buffSum(u, 'armorPct') / 100)) - (u.armorCut || 0));
const breakSum = u => (u.debuffs || []).reduce((a, b) => a + b.pct, 0);
const defMul = u => Math.max(0, 1 - breakSum(u) / 100);
/* 暴击倍率：战棋 `03-能力与减免管线.js:164` 的
   `const critMul = u => (hasTrait(u,'zero') ? 2.5 : 2) + buffSum(u,'critX');` ——
   基础 **×2**（零式 ×2.5 是个人特技，第一期不做）+ **`buffSum(att,'critX')`**。
   ★ 2026-10-11 开的口子（势力特色第五件 ATX 的**「好运加护」**，作者拍板接上）：
     `critX` 这个键**只有**「好运加护」那把支援武器会写到受益人身上（`buff:{critX:1, hit:-20}`，
     战棋 `04-武器与机体.js:194` ← 本仓库复制件 `10-数据.js:213`），值 = **暴击倍率 +1**。
     没有这个 buff 的战斗 `buffSum` 是 0 → `critMul(att)` **恒等于 2**，与改动前逐字相同
     （`tests/sim.js` 的胜率表与公式对照盯着这一条）。最低不低于 1（防负数 buff 把暴击变成减伤）。 */
const critMul = att => Math.max(1, 2 + buffSum(att, 'critX'));

/* 地图炮必中（战棋原样）。注意：新项目的「范围」类就是从 map / support 换算来的，
   所以从 map 过来的范围武器保留战棋的必中；从 support 过来的走正常命中判定。 */
const isSure = w => w.fire === 'map' || w.fire === 'passive';

/* 能力开关。战棋里还有「Lv10 起才生效」的 ABIL 等级表（属于特技），第一期去掉。 */
const abilOn = (u, k) => !!u && Array.isArray(u.abilities) && u.abilities.includes(k);
const shieldOn = u => !!u && u.shield > 0 && u.shieldHp > 0;
const lsLeft = (u, turn) => u.lsTurn !== turn ? 2 : 2 - (u.lsCount || 0);   // λ 力场：每回合 2 次

/* ---------- 命中 / 暴击 ---------- */
/* 职业特色（方案 6.3）也在这里生效：
 *   尖兵：每回合第一次被攻击时闪避 +20（打完这一下就把这一回合的加成用掉）；
 *   狙击：打后排没有被挡惩罚（在 30-射程.js 的 rowBlockPenalty 里）、暴击率 +10。 */
function hitRate(att, w, def, opts = {}) {
  if (isSure(w)) return { hit: 100, raw: 100, eva: 0, sure: true };
  const 尖兵闪 = (职业是(def, '尖兵') && def.尖兵闪避Turn !== opts.turn) ? 20 : 0;
  /* `势力闪避(def)`（`72-势力.js` 的框架钩子）＝ 势力特色给的闪避，**只对我方、没有特色恒 0**
     （第一件 = 卫星国防军 SEED 觉醒：闪避 + 觉醒 × 0.15；战棋同款是 `03-能力与减免管线.js:100` 的
     `TRAIT_FX.seed`，那里也是加在闪避上）。所以别的战斗与改动前**逐字相同**。 */
  const eva = Math.max(0, def.eva - (def.dodgePen || 0)) + buffSum(def, 'eva') + (def.moveEva || 0) + 尖兵闪 + 势力闪避(def);
  const h = (opts.baseHit ?? w.hit) - eva + Math.round(((att.aim ?? 160) - 160) / 2) + buffSum(att, 'hit') + (opts.blockPenalty || 0);
  return { hit: clamp(Math.round(h), 0, 100), raw: Math.round(h), eva, 尖兵闪 };
}
function critRate(w, att) {
  if (isSure(w)) return 0;
  return clamp(10 + ((att && att.critBase) || 0) + (w.critMod || 0) + buffSum(att, 'crit') + (职业是(att, '狙击') ? 10 : 0), 0, 100);
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
  /* 「防御」指令 / 守护替人挨打：这一下按防御结算 → 防御值 +50（方案第 4 节） */
  { id: 'guard', name: '防御姿态', stage: 2, applies: c => !!c.defending, def: () => 50 },
  { id: 'physRed', name: '物理减免', stage: 2, applies: c => c.w.dmgType === '物理' && buffSum(c.def, 'physRed') > 0, def: c => buffSum(c.def, 'physRed') },
  { id: 'buffDef', name: '防御增益', stage: 2, applies: c => buffSum(c.def, 'def') !== 0, def: c => buffSum(c.def, 'def') },
  /* 「减伤」入口（藏品用；★ 这一版新加，出处见下面的说明）：
   * 战棋把「减伤 %」算在 softRed 里、stage 2 加到**防御值**上（03-能力与减免管线.js:230-232、259），
   * 那里写着 `Math.min(90, softRed(c))`。我们照抄这一条，只读 buffSum(def,'red')。
   * **没有藏品的战斗 buffSum 是 0 → applies 为假 → 一行都不进步骤**，公式与改动前逐字相同。 */
  { id: 'relicRed', name: '减伤', stage: 2, applies: c => buffSum(c.def, 'red') > 0, def: c => Math.min(90, buffSum(c.def, 'red')) },
  /* 「势力防御」（**势力特色**用；★ 第一件 = 卫星国防军 SEED 的**重装**档，实现在 `72-势力.js`）：
   * 战棋把「SEED 防御」放在同一个 stage 2、加到**防御值**上（`03-能力与减免管线.js:227-229` 的
   * `REDUCTIONS.seedDef`，值来自 `17b:200` 的 `seedDefOf = seedActive(u) && isHeavy(u) ? round(觉醒 × 0.25) : 0`）。
   * 我们把它做成**通用的势力入口**（`势力防御(u)`），后面 5 个势力共用。
   * **没有势力特色的战斗这个值是 0 → applies 为假 → 一行都不进步骤**，公式与改动前逐字相同。 */
  { id: 'factionDef', name: '势力防御', stage: 2, applies: c => 势力防御(c.def) > 0, def: c => 势力防御(c.def) },
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
    /* 这一下是不是按防御结算：单位的「防御」指令，或替队友挡下的那一下（方案第 4 节） */
    defending: !!o.defending || !!def.defending,
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
  if (c.crit) { const x = critMul(att); W *= x; wn.push(`暴击 ×${x}`); }
  W = Math.round(W);

  /* 2. 装甲（特殊伤害 / 无视防御按 0） */
  let A = 0;
  if (!special && !ign) A = Math.round(effArmor(def) * c.defMul);

  /* 3. 攻击能力值（战棋里还有特技 / 藏品 / 肉鸽的加成，第一期都没有）
   * ★ 这一版新加「伤害加成」入口（藏品用，出处：战棋 03-能力与减免管线.js:185-188 的 genMods ——
   *   v0.37 起「伤害 +N%」改成「攻击能力值 +N」，所以这里加在 `atk` 上，不是最后乘伤害）。
   *   加数只来自 buffSum(att,'dmg')，也就是藏品的 `src:'藏品'` 那条常驻 buff；
   *   没有藏品时它是 0，`atk` 与改动前完全一样（tests/sim.js 的胜率表盯着这一条）。 */
  const 伤害加成 = (useStat && att) ? buffSum(att, 'dmg') : 0;
  const atk = ((useStat && att) ? atkStat(att, w) : 0) + 伤害加成;

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
  c.steps.push(`× statCoef（1 +（攻击 ${atk}${伤害加成 ? `（含伤害加成 +${伤害加成}）` : ''} − 防御 ${D}）/ 100）= ×${+coef.toFixed(2)}${dn.length ? `（防御：${dn.join('、')}）` : ''}`);
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
   例外是方案明确要保留的「多段」（special === 'multi'），以及 **2026-10-11 放行的 `chain`**。
   ★ `chain`（连射）是**月球王国「连射 + 残心」**的前提（作者点头要做的三条之一）：
     它只有一个字段（`chainStep:70`，数据 `10-数据.js:75` ← 战棋 `04-武器与机体.js:56`），
     战棋那条规则**本来就长在 `multi` 的逐段循环上**（`17-战斗执行.js:106-125` 与 `:79-104` 同一个形状），
     我们把它照抄成 `w.hits`（段数）+ 势力钩子给的 step（残心按等级减轻）→ **不依赖任何新引擎机制**。
     放行之前 `月光狙击枪` 被这一行挡着（Nagi 只有「月影迫击炮 / 掷弹筒 / 小太刀」可用，是他的主武器用不出来）；
     放行之后它按数据原样（威力 2100 / 命中 125 / 光束 / 段数 8）参战。
     ★ **别的 `special` 一律照旧挡着**（`lock` 多重锁定 / `pull` 拉人 / `markBreak` 标定 / `summon` 召唤…），
     所以这条改动只影响 `月光狙击枪` 一把武器，其他单位的可用武器池**一个字节都没变**。
   另一个例外是作者 2026-10-10 定的两条支援：Feena 的「月光祝福」（buff）和「再动」（grant）——
   没有伤害的支援武器，用 buff / grant 字段标记。 */
function weaponPlayable(w) {
  if (w.fire === 'passive' || w.fire === 'device') return false;
  if (w.special && w.special !== 'multi' && w.special !== 'chain') return false;
  if (w.fire === 'support' && !hasSupportField(w)) return false;   // 召唤 / 烟雾 / 回复% 之类的支援第一期不做
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
    if (!(w.power > 0) && !isHealKind(rangeKindOf(w)) && !isSupportKind(rangeKindOf(w))) return false;
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

/* 特种的降命中值（作者 2026-10-10：先按 20 做，和原来「防御 −20」同一个量级；要调就改这一个常量） */
const 特种降命中值 = 20;

/* ★ 2026-10-11 新加的**段内命中加成**（框架第 15 个钩子 `势力段内命中加成()`，实现在 `72-势力.js`）：
   多段武器（`w.hits > 1`）**逐段**乘在「这一段判定的基础命中」`p` 上 ——
   第一条用它的是**月球王国**的「连射 + 残心」（小太刀 Nagi 的月光狙击枪）：
     连射：命中后对同一目标再开一枪，**每命中一次下一枪命中修正再 −step**（战棋 `17-战斗执行.js:106-125`）；
     残心（Lv20 被动）：把那个 step 从 **70** 减轻成 **55**（Lv30 起 **45**）
       —— 战棋 `17b-角色机制.js:33` 的 `const chainStepOf = (u, w) => abilOn(u, 'zanshin') ? (L30(u) ? 45 : 55) : (w.chainStep || 70);`
     战棋是 `p -= step`（命中后递减，未中 `break` 结束连射）；本仓库的逐段循环本来就是
     「命中 → `p -= w.step` / 未中 → `p += w.step`」（战棋 multi 的做法），**step 由这个钩子按等级给**，
     所以这一段循环**一行都没动**，只是 `w.step` 的来源从数据换成「势力按等级算」。
   参数：`(攻击者, 武器, 段)`，`段 = { 段号, 段数 }`（段号从 1 开始）；返回这一段的 step（0 = 照数据）。
   ★ 没有势力条目 / 没写这个钩子 → 恒 0 → `p` 与改动前逐字相同（`p -= 0`）。 */
const 命中段步长 = (att, w, 段) => 段内命中加成(att, w, 段);

/* ---------- 一次普通攻击的结算（第一期唯一的攻击路径） ----------
 * 随机数全部走 ctx.rng（带种子，方案 6.1）。返回一条战斗记录用的文本 + 字段。
 * 多段：w.hits 段，每段独立判定命中与暴击；武器写了 w.step 时命中后逐段递减命中（战棋 multi 的做法）。
 * opts：
 *   blockPenalty  直射打后排的 −20（方案 3.3）
 *   defending     这一下按防御结算（守护替队友挨打）
 *   伤害倍率       守护者本回合自己攻击时 ×0.7（方案第 4 节：伤害 −30%）；**公式之后**逐段相乘
 *   威力倍率       ★ 2026-10-11 作者拍板新加（天人 ×1.3 挪到威力）：**公式之前**乘在 `wv(att,w,'power')` 上
 *                  （框架第 14 个钩子 `势力威力倍率()`，和战棋 `15-战斗计算.js:36` 的 `wPow` 同一个落点）
 * 职业特色（方案 6.3 + 作者 2026-10-10）：
 *   特种 = 武器命中后给对方挂「命中 −20」（持续到下回合结束，同一来源只留一份、不叠加）；
 *          作者原话：「推人其实还是可以设计，用来破坏对手的阵型，或者给对方上 DEBUFF，作为职业特色可以先设置降低命中率」；
 *   尖兵 = 每回合第一次被攻击闪避 +20。 */
function resolveAttack(att, def, w, ctx, opts = {}) {
  const rng = ctx.rng;
  const blockPenalty = opts.blockPenalty || 0;
  const 倍率 = opts.伤害倍率 == null ? 1 : opts.伤害倍率;
  /* ★ 威力倍率（框架第 14 个钩子，`72-势力.js` 的 `势力威力倍率()`；作者 2026-10-11 拍板「天人的 ×1.3 挪到威力」）：
     乘在**武器威力**上（`wv(att, w, 'power') * 威力倍率`）、进 `dmgCore()` 之前 ——
     和战棋 `15-战斗计算.js:36` 的 `wPow = round(wv(u,w,'power') * tierUp * taPowMul(u))` 同一个落点。
     没有势力条目 / 倍率是 1 → 威力与改动前逐字相同（`wv(...) * 1`）。 */
  const 威力倍率 = opts.威力倍率 == null ? 1 : opts.威力倍率;
  const sure = isSure(w);
  const hits = Math.max(1, w.hits || 1);
  const rolls = [];
  let total = 0, landed = 0, crits = 0, p = w.hit;
  const 尖兵加成 = (职业是(def, '尖兵') && def.尖兵闪避Turn !== ctx.turn) ? 20 : 0;

  for (let i = 0; i < hits; i++) {
    /* ★ 2026-10-11：这一段的**命中步长**（势力钩子第 15 个「段内命中加成」，实现在 `72-势力.js`）——
       第一条用它的是月球王国「连射 + 残心」（小太刀 Nagi 的月光狙击枪）：
       连射每命中一次下一枪命中 −70，Lv20 残心减轻成 −55、Lv30 −45
       （战棋 `17b-角色机制.js:33` 的 `chainStepOf`；段落循环本身照战棋 multi 的做法，一行没动）。
       ★ 没有条目写它 → 恒 0 → `p` 与改动前逐字相同。 */
    const 步长 = 命中段步长(att, w, { 段号: i + 1, 段数: hits });
    const q = hitRate(att, w, def, { baseHit: p, blockPenalty, turn: ctx.turn }).hit;
    const hit = sure || rng() * 100 < q;
    if (hit) {
      const cr = !sure && rng() * 100 < critRate(w, att);
      const c = dmgCore(att, w, def, { power: wv(att, w, 'power') * 威力倍率, crit: cr, preview: false, turn: ctx.turn, defending: opts.defending });
      const d = Math.round(c.dmg * 倍率);
      total += d; landed++; if (cr) crits++;
      rolls.push(`第 ${i + 1} 段（${sure ? '必中' : q + '%'}）${cr ? '暴击 ' : ''}${d}`);
      if (c.nullified) break;
      const 减 = 步长 || w.step;
      if (减) p -= 减;
    } else {
      rolls.push(`第 ${i + 1} 段（${q}%）未中`);
      /* ★ 2026-10-11 新加的势力钩子 `势力逐段未命中(ctx, 攻击者, 目标, 武器, 段)`（框架第 11 个，`72-势力.js`）：
         触发时机 = **这一段没打中**（多段武器**逐段发**，作者 2026-10-11 拍板「按段」——
         战棋是「整次攻击全空才算一次」，见 `协作/势力特色.md:53`；第一条用它的是 **ATX**，减大招冷却）。
         段号从 1 开始（和记录里「第 N 段」一致）。
         ★ **敌我双方的未命中都会进来**（战棋原话「敌我都算」）；必中武器走不到这里。
         ★ 没有势力条目写这个钩子 → 框架里是空循环，**公式与记录逐字不变**；
           条目里**不许消耗 `ctx.rng`**（在这个位置上动随机数会改整场结果）。 */
      势力逐段未命中(ctx, att, def, w, { 段号: i + 1, 段数: hits, 本段命中率: q });
      const 加 = 步长 || w.step;
      if (加) p += 加;
    }
    if (def.hp - total <= 0) break;
  }

  def.hp = Math.max(0, def.hp - total);
  /* 尖兵：这一回合的「第一次被攻击闪避 +20」用掉了 */
  if (尖兵加成) def.尖兵闪避Turn = ctx.turn;
  /* 特种（作者 2026-10-10）：武器命中后给对方挂「命中 −20」——对方的攻击更难打中（到下回合结束，
     同一个来源只留一份，不叠加）。作者说推人 / 破坏阵型以后可以单独设计，职业特色先做降命中。 */
  let 特种减命中 = 0;
  if (landed && 职业是(att, '特种')) {
    特种减命中 = 特种降命中值;
    def.buffs = (def.buffs || []).filter(b => b.src !== '特种');
    def.buffs.push({ src: '特种', hit: -特种减命中, 剩余: 2 });
  }

  const 段 = hits > 1 ? `${landed}/${hits} 段 ` : '';
  return {
    文本: landed
      ? `${att.name}【${w.name}】→ ${def.name}：${段}伤害 ${total}${crits ? `（暴击 ${crits} 次）` : ''}${特种减命中 ? `（特种：对方命中 −${特种减命中}，到下回合结束）` : ''}`
      : `${att.name}【${w.name}】→ ${def.name}：未命中（${rolls.join('；')}）`,
    字段: { 命中: landed > 0, 伤害: total, 段数: hits, 命中段数: landed, 暴击: crits, 目标剩余HP: def.hp, 特种减命中, 详情: rolls.join('；') },
  };
}
