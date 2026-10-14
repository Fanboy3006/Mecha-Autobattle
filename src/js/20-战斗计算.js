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
  const eva = Math.max(0, def.eva - (def.dodgePen || 0)) + buffSum(def, 'eva') + (def.moveEva || 0) + 尖兵闪 + 势力闪避(def);  /* ★ 2026-10-12（敌人卡第一批 · 钩子 `stealth` = 卡 A「幻影」）：「**隐匿**」——
     挂着 `abilities:['stealth']` 的**敌人**被「瞄准打」的射程（默认直射 / 曲射）瞄上时，
     **命中原始值 −35**（【初稿·待作者在调参室调】，一个常量在 `71-改动.js` 的 `战斗结构.敌人机制.隐匿`）。
     ★ 三条边界（都在 `71-改动.js` 那张表里，**这里只读表**）：
       ① **范围武器**根本走不到这一行（`isSure(w)` 在上面已经提前返回）→ 本来就不吃；
       ② **近战贴身 / 修理 / 支援**由 `隐匿吃惩罚()` 的射程数组豁免 → 不吃；
       ③ 没有 stealth 敌人 / 总开关 `开:false` / 不是敌人（我方那位不带这个键）→ **恒 0**，
          `h` 与改动前**逐字相同**。
     ★ 它是「减在原始命中上」的（和「特种 −20」「被挡 −20」同一条管线、同一个位置）——
       `raw` 会变、`hit` 再夹到 0–100。 */
  const 隐匿 = 隐匿惩罚值(def, w);
  const h = (opts.baseHit ?? w.hit) - eva + Math.round(((att.aim ?? 160) - 160) / 2) + buffSum(att, 'hit') + (opts.blockPenalty || 0) - 隐匿;
  return { hit: clamp(Math.round(h), 0, 100), raw: Math.round(h), eva, 尖兵闪, 隐匿 };
}

function critRate(w, att) {
  if (isSure(w)) return 0;
  return clamp(10 + ((att && att.critBase) || 0) + (w.critMod || 0) + buffSum(att, 'crit') + (职业是(att, '狙击') ? 10 : 0), 0, 100);
}

/* ---------- 弱点 / 抗性 ---------- */
/* 正数 = 弱点（生成阶段增伤），负数 = 抗性（百分比减免阶段，受破防削弱）。没有「背面」。
 * ★ 2026-10-13（关卡变体池 · `1-Boss`【原型重型装甲列车】P1 的词条键 `免直射物理`）：
 *   现有 8 个键是**「或」**（各自独立判定、数值相加），做不到「**同时**满足 `direct` 且 `物理`」。
 *   所以这里补**一条专用规则**：单位上写着 `免直射物理`（词条给的数，作者拍板 **−95%、不归 0**）时，
 *   凡是 `fire==='direct' && dmgType==='物理'` 的那一发就吃一个 −95% 抗性。
 *   ★ 三条边界：① 没有这个词条的单位 → 这一段不进（`def.免直射物理` 是 undefined）；
 *   ② 它与别的弱点**照旧相加**（下限仍是 `:199` 的 −95），所以「光束直射」照样打得进（原案后半句）；
 *   ③ 公式本体（并进威力 / 装甲 / 防御 / 减免链）**一行没改**。 */
function weakList(def, w, o = {}) {
  if (!w) return [];
  const out = [];
  const 免直 = Number(def.免直射物理);
  if (Number.isFinite(免直) && 免直 > 0 && w.fire === 'direct' && w.dmgType === '物理') {
    out.push(['直射物理', -Math.min(95, 免直)]);
  }
  if (!def.weak) return out;
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
/* ---------- 词条层的两个小工具（关卡变体池 · 2026-10-13）----------
 * 都**只读**、都在「没有词条」时恒为 0 / false（所以默认路径一行都不进）。 */
/** 「护卫减伤」（`2-Boss` 审判者）：这台单位带多少减伤（0 = 没有这个词条）。 */
function 护卫减伤值(u) {
  const v = u && u.护卫减伤;
  const 默认 = (词条参数() || {}).护卫减伤值;
  return Number.isFinite(Number(v)) && Number(v) > 0 ? Number(v) : 0;
}
/** 这一方的**别人**里还有活人吗（不含自己）—— 「只要护卫不死」这句的现成判据。 */
function 同侧还有别人(u, ctx) {
  if (!u || !ctx) return false;
  const 们 = (u.side === 'ally' ? ctx.allies : ctx.enemies) || [];
  return 们.some(x => x !== u && x && x.hp > 0);
}

const REDUCTIONS = [
/* 「防御」指令 / 全军防御那一档：这一下按防御结算 → 防御值 +50（方案第 4 节，§1.3 第 4 条） */
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
  /* ★ 2026-10-13（关卡变体池 · `2-Boss`【战术指挥官·审判者】的词条键 `护卫减伤`）：
   * 原案「只要护卫不死，本体拥有 90% 绝对减伤」——没有「免疫 / 绝对减伤」这个内核，
   * 所以照**现成的同构模板**加一条**条件条目**：同侧**还有别的活人**（`livingOf`，不看自己）时，
   * 自己获得 `减伤 值`（【初稿 90】，配置在 `71-改动.js` 的 `战斗结构.词条.护卫减伤值`）。
   * ★ 「还有没有别人」只能从 `ctx` 里读 —— 所以 `dmgCore()` 的上下文多带一个 `ctx`（`o.ctx`，
   *   `resolveAttack()` / `expectedDamage()` 本来就在传它）；**没有 ctx 的战斗恒 false** →
   *   `applies` 为假 → 一行都不进步骤，公式与改动前**逐字相同**。 */
  { id: 'guardRed', name: '护卫减伤', stage: 2,
    applies: c => 护卫减伤值(c.def) > 0 && 同侧还有别人(c.def, c.ctx),
    def: c => 护卫减伤值(c.def) },
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
    /* ★ 2026-10-13（关卡变体池）：把 `ctx` 也带进来 —— `REDUCTIONS` 里那条**条件条目**
       「护卫减伤」要问「这一方还有没有别的活人」（`同侧还有别人()`）。
       不传 / 没有 ctx 的战斗：那一条的 `applies` 恒 false，公式与改动前**逐字相同**。 */
    ctx: o.ctx || null,
    /* 这一下是不是按**防御姿态**结算（防御值 +50，方案第 4 节）。
       ★ 2026-10-12：来源从「单位的防御指令 / 守护替人挨打」换成两个（见 `60-战斗.js` 的 `按防御结算()`）：
         ① 这台单位本回合真的要执行防御动作（`def.defending`）；
         ② **当前方针**就是让它防御的那一档（全军防御 / 前守后攻的前排）——
            `算意图()` 在指令阶段也算得到（§1.6：「全军防御下我方的防御值 +50 会影响敌人挑谁打」）。
       默认路径（全军突击）两个来源都是假 → 逐字不变。
       ★ 2026-10-12（三层反馈 · 第 2 件，§2.4）`o.不带防御加成: true` = **只给显示用**的那一次再算：
         「防御少挨了多少」＝同一套参数、**不带防御加成**再算一次 `dmgCore`，两次取差值（§2.4 原话）。
         它把上面三个来源**一起压成 false**，所以那一次算出来的就是「没有防御加成时这一下会挨多少」。
         它只影响这一次预览：不改实际伤害、不消耗随机数（`dmgCore` 里一个 `rng` 都没有）。
         默认（不传这个字段）与改动前逐字相同。 */
    defending: o.不带防御加成 ? false : (!!o.defending || !!(def && def.defending) || 按防御结算(def, o.ctx)),
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
  const hr = hitRate(att, w, def, { blockPenalty: opts.blockPenalty || 0, ctx: opts.ctx }).hit / 100;
  const crit = 1 + critRate(w, att) / 100;
  const dmg = dmgCore(att, w, def, { power: wv(att, w, 'power'), preview: true, turn: opts.turn || 0, ctx: opts.ctx }).dmg;
  return hr * dmg * crit * hits;
}

/* ---------- 武器可用性（13-武器可用性.js:7-16 / 18-31 的数值部分） ---------- */
const START_CD_ULT = 3;   // 大招（unlock ≥ 20）开场冷却 3 回合 ← **改前的兜底值**
/* ★ 2026-10-11 大招变稀缺（作者：「大招：保留」这个开关要真的有意义）：
   开场冷却从写死的 3 改成读 `71-改动.js` 的 `战斗结构.大招冷却.开场`（初稿 5 回合 → 第 6 回合才能放）；
   数据里**显式写了 `startCd`** 的武器（例如敌人的大招）仍然听数据的，不走这条。 */
const startCdOf = w => w.startCd != null ? w.startCd : (w.unlock >= 20 ? 大招开场冷却() : 0);

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

/** 用掉一次：普通冷却 + 次数 −1（开场冷却由 readyTurn 管，不在这里）
 *  ★ 2026-10-11 大招变稀缺：**大招**（`unlock ≥ 20`）的普通冷却至少 `战斗结构.大招冷却.普通`
 *  （初稿 3 回合），数据里写了更长的就听数据的。敌人自己的大招不走这条（它们的 `cd` 写在数据里、
 *  `unlock` 是 1）→ 只有我方大招被拉长，「大招：保留」这个开关因此才有意义。 */
function spendWeapon(u, entry) {
  if (!entry) return;
  const 冷却 = entry.t.unlock >= 20 ? Math.max(entry.t.cd || 0, 大招普攻冷却()) : (entry.t.cd || 0);
  if (冷却) entry.cd = 冷却;
  if (entry.uses != null) entry.uses--;
  /* ★ 2026-10-13（关卡变体池 · 词条键 `冷却延长`）：这一把武器**真的打出去了** → 摘掉
     「这一轮冷却已经被延长过」的标记（`60-战斗.js` 的 `词条冷却延长()` 每轮最多延一次，
     标记只在这里清 —— 这样「延长 1 回合」是有界的，不会把武器永久锁死）。
     没有词条的武器这个字段恒为 undefined → 这一行什么都不做。 */
  entry.词条已延 = false;
}

/* ---------- 修理 ---------- */
const healAmount = (u, w) => Math.round(w.power * u.shoot / 100);   // 17-战斗执行.js:259

/* 特种的降命中值（作者 2026-10-10：先按 20 做，和原来「防御 −20」同一个量级；要调就改这一个常量） */
const 特种降命中值 = 20;

/* ============================================================================
 * **标定经济 —— 全职业通用的「传球」机制**（作者 2026-10-13 拍板「OK」，第一批 · 最小闭环）
 * ----------------------------------------------------------------------------
 * 方案出处 = 作者转来的设计稿，核心一句：**「标记是全职业通用的『传球』机制」**
 *   —— 把秘银已有的「标定 → 接力」（`72-势力.js` 的第六件势力特色）**泛化成全职业通用**：
 *     谁产标（生产端）→ 谁引爆（消费端），中间那张敌机卡上写着「几层 / 谁挂的 / 将被谁引爆」。
 *
 * 【和秘银那一条的关系 —— 两套「标定」并存，互不干扰（★ 写清楚，免得以后误删）】
 *   · 秘银（`72-势力.js`，势力特色第六件）：**只有秘银五个人**吃，标定写在 `u.debuffs[]`
 *     （靠 `debuffs[].pct → breakSum → defMul` 那条**破防**管线，每回合结束 −1 层）。
 *   · 本段（标定经济）：**按职业**（特种 / 指挥 产、狙击 / 范围 引爆），标定写在
 *     `u.标定经济` 上（**自己一个字段**），**层数保留到被消耗或战斗结束、不清零**。
 *   · 两者**同时开着也不打架**：字段不同、判定不同、写记录的前缀不同（`〔势力〕` vs `〔标定〕`）。
 *
 * 【四条边界（★ 硬验收靠它们）】
 *   ① **参数与开关**在 `71-改动.js` 的 `战斗结构.标定经济`（`开: true` 是默认；
 *      显式写 `false` = **逐字回到改动前**，用来做 A/B 测量）—— 这里一个数字都不写死。
 *   ② **一个随机数都不消耗**（`ctx.rng` 一次都不调）：所以「不产标的战斗」的**整场随机数序列
 *      与改动前逐字相同**；「产了标的战斗」也只有伤害数值变，随机数流不变。
 *   ③ **对称**（作者 2026-10-11 的老规矩「敌人也吃职业特色」）：判定一律走 `职业是()`
 *      （`30-射程.js`，敌方认 `战斗结构.敌方职业`）→ 敌方的特种 / 指挥 / 狙击 / 范围武器照样产标、引爆。
 *   ④ **不改公式**：狙击那 +30% 是「公式算完之后的伤害倍率」（和 Boss 阶段倍率 / 势力伤害倍率
 *      同一个口子），范围引爆是**独立的溅射伤害**（不打 `dmgCore`）。`dmgCore()` / `hitRate()` /
 *      减免链**一行都没动**。
 *
 * 【生产端 / 消费端】
 *   生产：`标定经济产标(ctx, 攻击者, 目标)`  ← `resolveAttack()` 里 `landed > 0 && 职业是(att,'特种')`
 *         `标定经济点名(ctx)`               ← `60-战斗.js` 的 `回合开始()`（**指挥**号令点名标定一台敌机）
 *   消费：`标定经济狙击层数(目标)`（读参数）→ 段循环里只对**暴击段**吃伤害加成 + 消耗 1 层
 *         `标定经济引爆(ctx, 攻击者, 目标, w, 主伤害)`（范围武器命中后引爆**全部**层 → 溅射）
 * ========================================================================== */

/** 标定经济的参数（`71-改动.js` 的 `战斗结构.标定经济`）。 */
function 标定经济参数() { return (战斗结构 && 战斗结构.标定经济) || {}; }
/** 标定经济开着吗。**默认开**；显式写 `开: false` 才关 —— 那是「与改动前逐字相同」的验证口径。 */
function 标定经济开() { return !(标定经济参数().开 === false); }

/** 一个数读参数（读不到 / 写坏了 → 默认值）。 */
function 标定数(键, 默认值) {
  const v = Number(标定经济参数()[键]);
  return Number.isFinite(v) ? v : 默认值;
}
/** 层数上限（`层数上限`，默认 3 —— 作者 2026-10-13 定「上限 3」）。 */
function 标定层数上限() { return Math.max(1, Math.round(标定数('层数上限', 3))); }
/** 狙击引爆的**暴击率加成**（`狙击.暴击加成`，默认 +25）。 */
function 标定狙击暴击() {
  const v = Number((标定经济参数().狙击 || {}).暴击加成);
  return Number.isFinite(v) ? v : 25;
}
/** 狙击引爆的**伤害倍率**（`狙击.伤害倍率`，默认 1.3 = +30%）。 */
function 标定狙击倍率() {
  const v = Number((标定经济参数().狙击 || {}).伤害倍率);
  return Number.isFinite(v) && v > 0 ? v : 1.3;
}
/** 范围引爆的**每层溅射**（占这一发主伤害的比例，`范围引爆.每层比例`，默认 0.15）。 */
function 标定范围每层() {
  const v = Number((标定经济参数().范围引爆 || {}).每层比例);
  return Number.isFinite(v) && v > 0 ? v : 0.15;
}
/** 狙击引爆的**一次消耗几层**（`狙击.消耗层数`，默认 1 —— 作者定「消耗 1 层」）。 */
function 标定狙击消耗层() {
  const v = Number((标定经济参数().狙击 || {}).消耗层数);
  return Number.isFinite(v) ? Math.max(1, Math.round(v)) : 1;
}
/** 指挥号令**每回合全场最多点名几台**（`指挥点名.每回合全场上限`，默认 **1**）。
 *  ★ 统筹 2026-10-13 裁决：从「每个指挥各点一次」改成「全场 1 台」（理由见 `标定经济点名()`）。 */
function 标定点名全场上限() {
  const v = Number((标定经济参数().指挥点名 || {}).每回合全场上限);
  return Number.isFinite(v) ? Math.max(1, Math.round(v)) : 1;
}

/** 这台单位身上的「标定经济」条目（0 条 = 没被标定过；一台最多一条，层数往上加）。 */
const 标定经济条 = u => ((u && u.标定经济) || [])[0] || null;
/** 这台单位身上有几层标定（**没有 = 0**）。★ 纯读：不改状态、不消耗随机数。 */
function 标定经济层数(u) { const d = 标定经济条(u); return d ? Math.max(0, Number(d.层数) || 0) : 0; }
/** 这台单位身上的标定条目（读不到就现造一条挂上去 —— 只有**产标**那一侧会调它）。 */
function 标定经济拿条(u) {
  if (!u) return null;
  const 有 = 标定经济条(u);
  if (有) return 有;
  const d = { 层数: 0, 上限: 标定层数上限(), 来源们: [] };
  u.标定经济 = (u.标定经济 || []).concat([d]);
  return d;
}
/** 这些层分别是谁产的（记录 / 卡行用；去重、保序）。 */
const 标定来源名 = d => [...new Set(((d && d.来源们) || []).map(g => (g && (g.名 || g.键)) || '').filter(Boolean))];

/** **生产端①（特种）**：特种的一次攻击**真的造成伤害**之后 → 那台敌机 +1 层标定（上限 3）。
 *  返回这一台现在几层（0 = 没挂上：不是特种 / 打的是自己人 / 到上限）。
 *  ★ 对称：`职业是()` 敌我都认（敌方的特种照样产标）。
 *  ★ 与「特种」原有的职业特色**并存**：命中 −20 那一条在 `resolveAttack()` 里一个字没改，
 *    标定是**额外**挂上去的（作者 2026-10-13 明确要求保留）。
 *  ★ **`ctx.log` 不是数组时不写记录、照样加层**（`tests/heal.js` 有一段用极简的假 ctx
 *    `{rng, turn}` 直接调 `resolveAttack()` 只看职业特色 —— 那种调用点不能被写记录打死）。 */
function 标定经济产标(ctx, 攻击者, 目标) {
  if (!ctx || !攻击者 || !目标) return 0;
  if (!标定经济开()) return 0;
  if (!职业是(攻击者, '特种')) return 0;                     // ★ 对称：职业是() 敌我都认
  if (目标.side === 攻击者.side) return 0;                    // 标定挂在**对面**身上
  const 能写记录 = Array.isArray(ctx.log);
  const 上限 = 标定层数上限();
  const d = 标定经济拿条(目标);
  if (!d) return 0;
  d.上限 = 上限;
  const 前 = Math.max(0, Number(d.层数) || 0);
  if (前 >= 上限) {
    if (能写记录) pushLog(ctx, `〔标定〕${攻击者.name}（特种）又标定了 ${目标.name}，但它已经到层数上限 ${上限} 层了（不再加）`, {
      类型: '标定', 事件: '预定到上限', 结果: '到上限',
      单位: 攻击者.key, 单位方: 攻击者.side, 单位位: 攻击者.slot,
      目标: 目标.key, 目标方: 目标.side, 目标位: 目标.slot, 层数: 前, 层数上限: 上限, 生产: '特种',
    });
    return 前;
  }
  if (!(d.来源们 || []).some(g => g && g.键 === 攻击者.key)) {
    d.来源们 = (d.来源们 || []).concat([{ 键: 攻击者.key, 名: 攻击者.name, 方: 攻击者.side, 怎么来的: '特种' }]);
  }
  d.层数 = 前 + 1;
  if (能写记录) pushLog(ctx, `〔标定〕${攻击者.name}（特种）命中 → ${目标.name} +1 层标定：${d.层数}/${上限} 层`
    + `（来自 ${标定来源名(d).join('、')}）`, {
    类型: '标定', 事件: '产标', 结果: '挂标定', 生产: '特种',
    单位: 攻击者.key, 单位方: 攻击者.side, 单位位: 攻击者.slot,
    目标: 目标.key, 目标方: 目标.side, 目标位: 目标.slot,
    层数: d.层数, 层数上限: 上限, 来源: 标定来源名(d), 来源键: (d.来源们 || []).map(g => g.键),
  });
  return d.层数;
}

/** **生产端②（指挥）**：指挥的号令 = **点名标定一台敌机**（+1 层，走同一个上限）。
 *  选谁（★ 我们定的口径，写进任务板）：候选 = 对面活着的单位里
 *    **先挑层数少的**（让标定铺开）→ 同档里**格子号最小**（决定性、同种子可复现）。
 *  ★ **每回合全场只点名 1 台**（`指挥点名.每回合全场上限`，默认 1）—— 统筹 2026-10-13 裁决：
 *    原来「每个活着的指挥各点名一次」在带 2–3 个指挥时会**线性膨胀**，而唯一总闸只有层数上限 3，
 *    太靠上限兜；改成**全场 1 台**最可控、也最好讲清楚（「每回合一次点名」）。
 *    ⚠ 名额的**归属顺序**：先我方（`方` 循环 `['ally','enemy']`，位号小的先），我方点名完就收工
 *      → 我方的指挥优先用掉这一回合那一次；我方没有指挥 / 都用不上（对面全到上限）时**才轮到敌方**
 *      （`回合开始()` 的顺序本来就是我方先处理）。
 *  调用点 = `60-战斗.js` 的 `回合开始()`，紧跟在现成的「指挥：同排命中 +10」那一段**后面**
 *  （那一条**一个字都没改**，作者 2026-10-13 要求保留）。返回这一台现在几层。 */
function 标定经济点名(ctx) {
  if (!ctx || !标定经济开()) return 0;
  const 能写记录 = Array.isArray(ctx.log);
  const 上限 = 标定层数上限();
  const 全场上限 = 标定点名全场上限();
  let 点名了 = 0;
  let 已点 = 0;
  for (const 方 of ['ally', 'enemy']) {                       // ★ 对称：敌方的指挥也点名（我方先）
    if (已点 >= 全场上限) break;                              // ★ 全场名额用完 → 收工
    for (const c of livingOf(方, ctx)) {
      if (已点 >= 全场上限) break;
      if (!职业是(c, '指挥')) continue;
      const 候选 = livingOf(otherSide(方), ctx)
        .filter(t => t.hp > 0 && 标定经济层数(t) < 上限)
        .sort((a, b) => (标定经济层数(a) - 标定经济层数(b)) || (a.slot - b.slot));
      if (!候选.length) continue;
      const t = 候选[0];
      const d = 标定经济拿条(t);
      if (!d) continue;
      d.上限 = 上限;
      const 前 = Math.max(0, Number(d.层数) || 0);
      if (!(d.来源们 || []).some(g => g && g.键 === c.key)) {
        d.来源们 = (d.来源们 || []).concat([{ 键: c.key, 名: c.name, 方: c.side, 怎么来的: '指挥号令' }]);
      }
      d.层数 = 前 + 1;
      已点++;
      if (能写记录) pushLog(ctx, `〔标定〕${c.name}（指挥）号令点名 → ${t.name} +1 层标定：${d.层数}/${上限} 层`
        + `（来自 ${标定来源名(d).join('、')}${全场上限 > 0 ? `；每回合全场只点名 ${全场上限} 台` : ''}）`, {
        类型: '标定', 事件: '点名', 结果: '指挥点名', 生产: '指挥',
        单位: c.key, 单位方: c.side, 单位位: c.slot,
        目标: t.key, 目标方: t.side, 目标位: t.slot,
        层数: d.层数, 层数上限: 上限, 来源: 标定来源名(d), 来源键: (d.来源们 || []).map(g => g.键),
        全场上限,
      });
      点名了 = d.层数;
    }
  }
  return 点名了;
}

/** **消费端①（狙击）**：狙击打带标定的目标 → **暴击那一段的伤害 +30%**，消耗 1 层。
 *  ★ **文案口径（统筹 2026-10-13 裁决，★ 重要）**：这句**不是**「暴击率 +25」——
 *    实现是「**真的暴击的那一段才兑现**」：消耗 1 层 + 那一段伤害 ×1.3。
 *    **为什么不把 +25 加进 `critRate()`**：那会让整场随机数流与改动前错位，
 *    破坏「同种子逐字相同 / 关掉开关 = 与改动前逐字相同」两条硬规矩（作者 2026-10-11 立）。
 *    所以**所有文案（卡片预告 / 战报 / 参数表注释）都必须如实写成「暴击段伤害 +30%」**，
 *    参数名 `暴击加成` 保留（它是 25 这个**档位**的数，用在文案里说清是「暴击那一段的档」）。
 *  ★ 判据只在这里（`resolveAttack()` 里一行 read-only 的调用）：狙击 + 目标有层 + 开关开着。
 *  ★ `expectedDamage()` 的**期望值不吃这个加成**（它是纯期望、不消耗层数）。 */
function 标定经济狙击加成(目标) {
  if (!目标 || !标定经济开()) return null;
  if (标定经济层数(目标) <= 0) return null;
  return { 暴击加成: 标定狙击暴击(), 伤害倍率: 标定狙击倍率() };
}
/** 狙击真的兑现了一次 → 消耗 1 层（`狙击.消耗层数`，默认 1）。返回 `{消耗, 剩}`。 */
function 标定经济消耗一(目标) {
  const d = 标定经济条(目标);
  const 要 = 标定狙击消耗层();
  if (!d) return { 消耗: 0, 剩: 0 };
  const 前 = Math.max(0, Number(d.层数) || 0);
  const 消耗 = Math.min(前, 要);
  d.层数 = 前 - 消耗;
  return { 消耗, 剩: d.层数 };
}

/** **消费端②（范围武器引爆）**：范围武器打中带标定的目标 → **引爆全部标定** → 溅射。
 *  每层给一点溅射伤害 = `round(这一发主伤害 × 每层比例)`（默认 15%/层）→ 直接扣在**这个目标**身上。
 *  ★ 落点语义（写进任务板）：只溅射**被打中的那一台**（不溢到邻格 —— 那要在 `60-战斗.js` 的
 *    逐目标循环里做，属于下一批；这一批按「引爆全部标定 → 每层给一点溅射伤害」逐字实现）。
 *  返回 `null`（没引爆）/ `{层数, 伤害, 来源, 剩余HP, 公式}`。 */
function 标定经济引爆(ctx, 攻击者, 目标, w, 主伤害) {
  if (!ctx || !攻击者 || !目标) return null;
  if (!标定经济开()) return null;
  if (目标.side === 攻击者.side) return null;
  const kind = w && rangeKindOf(w);
  if (!kind || !isAreaKind(kind)) return null;                // 只有**范围**武器引爆
  const d = 标定经济条(目标);
  if (!d) return null;
  const 层数 = Math.max(0, Number(d.层数) || 0);
  if (层数 <= 0) return null;
  const 每层 = 标定范围每层();
  const 总 = Math.round((Number(主伤害) || 0) * 每层 * 层数);
  const 来源 = 标定来源名(d);
  d.层数 = 0;                                                 // ★ 消耗**全部**层数
  const 剩HP = Math.max(0, 目标.hp - 总);
  const 公式 = `${主伤害} × ${每层} × ${层数} 层 = ${总}`;
  if (Array.isArray(ctx.log)) pushLog(ctx, `〔标定〕${来源.join('、') || '（无来源）'} 的标定 → ${攻击者.name}【${w.name}】引爆 ${层数} 层，`
    + `溅射 ${总}（${公式}）`, {
    类型: '标定', 事件: '引爆', 结果: '范围引爆',
    单位: 攻击者.key, 单位方: 攻击者.side, 单位位: 攻击者.slot,
    目标: 目标.key, 目标方: 目标.side, 目标位: 目标.slot,
    层数, 消耗层数: 层数, 标定伤害: 总, 伤害: 总, 来源, 剩余HP: 剩HP, 公式, 武器: w.name,
    产标方们: (d.来源们 || []).map(g => g && g.方), 产标位们: (d.来源们 || []).map(g => (g && g.键) || null),
  });
  return { 层数, 伤害: 总, 来源, 剩余HP: 剩HP, 公式 };
}
/** 记录 / 卡行用的一行来源（`克鲁兹的标定` 这种）。 */
const 标定来源词 = d => {
  const 名 = 标定来源名(d);
  return 名.length ? `${名.join('、')} 的标定` : '标定';
};
/** **连锁日志**（作者要的那一句）：`A 的标定 → B 引爆 5292!`（`!` 只在真的把目标打掉时加）。 */
function 标定连锁文本(引爆者, 目标, 来源词, 伤害, 打死了) {
  return `${来源词} → ${引爆者.name} 引爆 ${伤害}${打死了 ? '!' : ''}`;
}
/** **中继 / 即时**：把一次「消耗」写进记录并发一条连锁日志（`resolveAction()` 调用，主攻击记录之后）。
 *  `一` = 那一条攻击记录；`记号` = `rec.字段.标定`（由 `resolveAttack()` 填）。 */
function 标定经济记录(ctx, 攻击者, 目标, 一, 记号) {
  if (!ctx || !记号 || !记号.消耗) return;
  if (!Array.isArray(ctx.log)) return;
  const 死 = 目标 && 目标.hp <= 0;
  pushLog(ctx, `〔标定〕${标定连锁文本(攻击者, 目标, 记号.来源词 || '标定', 记号.消耗伤害 || 0, 死)}`, {
    类型: '标定', 事件: 记号.怎么引爆 === '范围' ? '引爆连锁' : '狙击连锁',
    结果: 记号.怎么引爆 === '范围' ? '范围引爆' : '狙击引爆',
    单位: (记号.引爆键 != null ? 记号.引爆键 : (攻击者 && 攻击者.key)),
    单位方: 记号.引爆方 != null ? 记号.引爆方 : (攻击者 && 攻击者.side),
    单位位: 记号.引爆位 != null ? 记号.引爆位 : (攻击者 && 攻击者.slot),
    目标: 目标 && 目标.key, 目标方: 目标 && 目标.side, 目标位: 目标 && 目标.slot,
    层数: 记号.消耗, 消耗层数: 记号.消耗, 标定伤害: 记号.消耗伤害 || 0,
    来源: 记号.来源 || [], 武器: (一 && 一.武器) || null, 剩余HP: 目标 ? 目标.hp : null,
    暴击加成: 记号.暴击加成 || 0, 伤害倍率: 记号.伤害倍率 || 1, 公式: 记号.公式 || null,
  });
}

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
  /* ★ 2026-10-12（三层反馈 · 第 2 件，§2.4）：这一下是不是按**防御姿态**结算 ——
     判定只此一份（`dmgCore()` 里面那一行用的是同一个函数、同一组来源）。
     `少挨合计` = 逐段「实际挨的这一下」与「不带防御加成时会挨的那一下」的差，**只用来显示**。 */
  const 按防 = !!(opts.defending || (def && def.defending) || 按防御结算(def, ctx));
  let 少挨合计 = 0;
  /* ★ 2026-10-12（敌人卡第一批 · 钩子 `stealth`）：这一发打在「隐匿」单位身上要减多少命中
     （`hitRate()` 里面那一行用的是**同一个函数、同一个表**）。只用来写记录里的即时字段：
     **整次一段都没中**（`landed === 0`）时才写 `隐匿: true` + `隐匿惩罚: N` —— 界面把它翻成
     「隐匿 −N」那个小标签，战报统计「隐匿共让你打空 N 次」。
     ★ 恒 0（没有 stealth 敌人）→ 这一个字段**一个字节都不多**（默认路径逐字不变）。 */
  const 隐匿罚 = 隐匿惩罚值(def, w);
  /* ★ 2026-10-13 **标定经济 · 消费端①（狙击）**：狙击打带标定的目标 → **暴击那一段的伤害 +30%**，消耗 1 层。
     ★ 见 `标定经济狙击加成()` 那一段的注释：**只对真的暴击的那几段生效**、**一个随机数都不消耗**
       （`ctx.rng` 的调用次数与位置一个字没改 → 随机数流与改动前逐字相同）。
     没有标定 / 不是狙击 / 开关关掉 → `加成` 是 null，下面这些语句**一个字段都不多**（默认路径逐字不变）。 */
  const 加成 = (!sure && 职业是(att, '狙击')) ? 标定经济狙击加成(def) : null;
  let 标定记号 = null;
  for (let i = 0; i < hits; i++) {
    /* ★ 2026-10-11：这一段的**命中步长**（势力钩子第 15 个「段内命中加成」，实现在 `72-势力.js`）——
       第一条用它的是月球王国「连射 + 残心」（小太刀 Nagi 的月光狙击枪）：
       连射每命中一次下一枪命中 −70，Lv20 残心减轻成 −55、Lv30 −45
       （战棋 `17b-角色机制.js:33` 的 `chainStepOf`；段落循环本身照战棋 multi 的做法，一行没动）。
       ★ 没有条目写它 → 恒 0 → `p` 与改动前逐字相同。 */
    const 步长 = 命中段步长(att, w, { 段号: i + 1, 段数: hits });
    const q = hitRate(att, w, def, { baseHit: p, blockPenalty, turn: ctx.turn, ctx }).hit;
    const hit = sure || rng() * 100 < q;
    if (hit) {
      const cr = !sure && rng() * 100 < critRate(w, att);
      /* ★ 2026-10-13 **标定经济 · 消费端①（狙击）**：这一**段**真的暴击了、目标身上还有标定 →
         这一段吃「伤害 +30%」并**消耗 1 层**（★ 作者定「消耗 1 层」）。
         ★ 位置很讲究：判据写在 `cr` **之后** —— 所以暴击判定用的还是原来的 `critRate()`，
           随机数流不变；这里**不是**「让暴击更容易发生」，而是**那一段的伤害乘子**（见参数表的口径），
           实现上是「暴击的那一段才兑现」，写成记录字段给测试与战报读（`标定` / `标定伤害` / `标定剩`）。 */
      const 段标 = (cr && 加成 && !标定记号) ? (() => {
        const 记号 = { 怎么引爆: '狙击', 暴击加成: 加成.暴击加成, 伤害倍率: 加成.伤害倍率, 消耗: 0, 消耗伤害: 0, 层数: 标定经济层数(def), 来源: 标定来源名(标定经济条(def)), 来源词: 标定来源词(标定经济条(def)), 引爆键: att.key, 引爆方: att.side, 引爆位: att.slot };
        const 消 = 标定经济消耗一(def);
        记号.消耗 = 消.消耗; 记号.标定剩 = 消.剩;
        记号.公式 = `（暴击段 ×${记号.伤害倍率}）`;
        return 记号;
      })() : null;
      /* ★ 三层反馈 · 「防御少挨了多少」（§2.4）：**同一套参数、不带防御加成再算一次 `dmgCore`**，
         两次取差值。三个要点：
           ① **先算预览、再算真的** —— 预览走 `preview: true`（屏障 / 力场 / 护盾一个计数器都不动），
              所以在真的一发之前算，两次看到的**靶子状态完全一样**（先算真的就会看到已经被打掉一层的盾）；
           ② **不消耗随机数**：这一次调用里一个 `rng` 都没有，`hit / cr` 已经判完了，
              所以段数、命中段数、暴击次数与整场随机数序列**一个都不变**；
           ③ **只用来显示**：`total` 加的还是原来那一个 `d`（`少挨合计` 只进记录字段）。 */
      const 无防 = 按防 ? dmgCore(att, w, def, { power: wv(att, w, 'power') * 威力倍率, crit: cr, preview: true, turn: ctx.turn, 不带防御加成: true, ctx }).dmg : 0;
      const c = dmgCore(att, w, def, { power: wv(att, w, 'power') * 威力倍率, crit: cr, preview: false, turn: ctx.turn, defending: opts.defending, ctx });
      const d = Math.round(c.dmg * 倍率 * (段标 ? 段标.伤害倍率 : 1));
      /* 「少挨了多少」＝**不带防御加成时会挨的** − **实际挨的**（大减小，所以是正数；
         防御只会让伤害更低，`Math.max(0, …)` 只是兜底：万一某条减免让反向差出现，也不写负数）。 */
      if (按防) 少挨合计 += Math.max(0, Math.round(无防 * 倍率) - d);
      total += d; landed++; if (cr) crits++;
      /* ★ 标定经济：这一段的伤害里有**多少是标定加成带来的**（差值账，给记录 / 战报读）。
         没有标定记号 → 这一行什么都不做（`段标` 是 null）。 */
      if (段标) { 段标.消耗伤害 += Math.max(0, d - Math.round(c.dmg * 倍率)); 标定记号 = 段标; }
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
    if (def.hp - total - (标定记号 ? (标定记号.溅射 || 0) : 0) <= 0) break;
  }

  def.hp = Math.max(0, def.hp - total);
  /* ★ 2026-10-13 **标定经济 · 消费端②（范围武器引爆）**：范围武器打中带标定的目标 →
     **引爆全部标定** → 每层给一点溅射伤害（`标定经济引爆()`，记录也在那里写）。
     ★ 位置：`def.hp -= total` **之后** —— 所以这条攻击记录的「伤害」还是**主伤害**
       （口径和「镜甲反弹」「自爆」一致：额外伤害走自己的 `〔标定〕` 记录，不被重复计账），
       而「目标剩余HP」带的是**引爆之后**的血；引爆破防 / 被打死由引擎的正常击破路径接手。
     ★ 一个随机数都不消耗；没有标定 / 不是范围武器 → `null`，一个字段都不多（默认路径逐字不变）。 */
  const 引爆 = 标定经济引爆(ctx, att, def, w, total);
  if (引爆) def.hp = 引爆.剩余HP;
  /* 尖兵：这一回合的「第一次被攻击闪避 +20」用掉了 */
  if (尖兵加成) def.尖兵闪避Turn = ctx.turn;
  /* ★ 2026-10-13（关卡变体池 · `2-E3`【光学迷彩机】的词条键 `隐身刷新`）：**打中一下就摘掉隐身**
     （原案「每回合隐身（免疫单体攻击一次）」，我们用「命中 −35 + 打中就破」表达；回合开始会重新挂，
     见 `60-战斗.js` 的 `词条隐身刷新()`）。没有这个词条的单位这个字段恒为 undefined → 这一行什么都不做。 */
  if (landed > 0 && def.隐身中) def.隐身中 = false;
  /* 特种（作者 2026-10-10）：武器命中后给对方挂「命中 −20」——对方的攻击更难打中（到下回合结束，
     同一个来源只留一份，不叠加）。作者说推人 / 破坏阵型以后可以单独设计，职业特色先做降命中。 */
  let 特种减命中 = 0;
  if (landed && 职业是(att, '特种')) {
    特种减命中 = 特种降命中值;
    def.buffs = (def.buffs || []).filter(b => b.src !== '特种');
    def.buffs.push({ src: '特种', hit: -特种减命中, 剩余: 2 });
  }
  /* ★ 2026-10-13 **标定经济 · 生产端①（特种）**：特种**命中即挂标**（目标 +1 层，上限 3）。
     ★ 与上面那条「命中 −20」**并存**（作者 2026-10-13 明确要求保留现有特色，标定是**额外**挂上去的）
       —— 上面那三行一个字都没改。
     ★ 位置：`landed > 0` 之后（未命中不产标）、`def.buffs` 那一段之后 ——
       所以「命中 −20」那条 buff 与标定层数各自独立；记录由 `标定经济产标()` 自己写。
     ★ 对称：`职业是()` 敌我都认 → 敌方的特种照样给我方挂标。 */
  const 标定产 = landed ? 标定经济产标(ctx, att, def) : 0;

  /* ★ 2026-10-11 新加的**敌方武器 debuff**（作者：「敌方也能给我方挂 debuff」）：
     数据在 `71-改动.js` 的 `战斗结构.敌方debuff[敌人键][武器名]`，**复用现成的三条管线**：
       · `hit`      → `def.buffs[]`（命中公式 `hitRate()` 读 `buffSum(def,'hit')`，和「特种」同一条）
       · `pct`      → `def.debuffs[]`（破甲：`breakSum()` → `defMul()`，装甲与防御一起降）
       · `armorCut` → `def.armorCut`（削装甲：`effArmor()` 减的那一项；到期由 `60-战斗.js` 的 `endTurn()` 还回去）
     ★ **公式一行没改**：这三项本来就在读，只是一直没有（或只有秘银一个）生产者。
     ★ 没有配 debuff 的武器 → `武器debuff()` 返回 null → 这一整段不进，行为与改前逐字相同。 */
  let 挂上的debuff = null;
  if (landed) {
    /* ★ 2026-10-13（关卡变体池）：第三个参数把**攻击者单位**传下去 —— 带 `词条` 的编成
       （`2-N3` 的 `cd+1` / `2-E2` 的「转成自身攻击力」/ `2-Boss` 的「攻击附带破甲」）
       在单位上挂着一份 `词条武器debuff`，`武器debuff()` 优先读它。
       没挂词条的单位 → 走原来那句表查询，行为与改动前逐字相同。 */
    挂上的debuff = 武器debuff(att.key, w.name, att);
    if (挂上的debuff) 应用武器debuff(def, 挂上的debuff, w.name, att);
  }

  const 段 = hits > 1 ? `${landed}/${hits} 段 ` : '';
  return {
    /* ★ 2026-10-12（三层反馈 · 第 2 件）：`防御少挨` 只在**真的按防御姿态挨了这一下**时才带上
       （`少挨合计 > 0`）—— 字段不出现 = 这一下与防御无关，默认路径（全军突击）**一个字段都不多**。 */
    文本: landed
      ? `${att.name}【${w.name}】→ ${def.name}：${段}伤害 ${total}${crits ? `（暴击 ${crits} 次）` : ''}`
        + `${特种减命中 ? `（特种：对方命中 −${特种减命中}，到下回合结束）` : ''}`
        + `${挂上的debuff ? `（${debuff文字(挂上的debuff)}）` : ''}`
      : `${att.name}【${w.name}】→ ${def.name}：未命中（${rolls.join('；')}）`,
    字段: Object.assign({
      命中: landed > 0, 伤害: total, 段数: hits, 命中段数: landed, 暴击: crits, 目标剩余HP: def.hp,
      特种减命中, debuff: 挂上的debuff || null, 详情: rolls.join('；'),
    }, 少挨合计 > 0 ? { 防御少挨: 少挨合计 } : null,
    (隐匿罚 > 0 && landed === 0) ? { 隐匿: true, 隐匿惩罚: 隐匿罚 } : null,
    /* ★ 2026-10-13 标定经济（即时那一层）：**只有真的用上了才写字段** ——
       默认路径（开关关掉 / 没有标定）一个字段都不多，记录逐字不变。
         · `标定`       = 狙击引爆的记号（`resolveAction()` 用它发连锁日志）；
         · `标定溅射`   = 范围引爆的溅射伤害（上面已经扣掉了，这里只报数）；
         · `标定引爆`   = 范围引爆的层数；
         · `标定产`     = 这一发让目标多了几层（特种命中即挂标）。 */
    (标定记号 || 引爆 || 标定产) ? Object.assign({},
      标定记号 ? { 标定: 标定记号, 标定伤害: 标定记号.消耗伤害, 标定剩: 标定记号.标定剩 }
        : (引爆 ? { 标定溅射: 引爆.伤害, 标定引爆: 引爆.层数, 标定来源: 引爆.来源 } : null),
      标定产 ? { 标定产 } : null) : null),
  };
}

/* ---------- 敌方武器 debuff 的落点（2026-10-11，出处见 `71-改动.js` 的 `战斗结构.敌方debuff`） ----------
 * 同一来源**只留一份**（和 `换同源增益()` 同一个规矩），换新的时候先把旧的副作用还回去，
 * 免得 `armorCut` 这种**累加**的量越挂越多。
 * ★ 2026-10-13（关卡变体池 · 词条层）**新加两个键**（老的三键 `hit` / `pct` / `armorCut` 一个字节没改）：
 *   · `cd`   —— 替代 ≠ 原案（原案是「扣大招能量条 10%」，我们是**冷却制**，见对账 §0.3 边界 3）：
 *               命中时把目标**带大招的武器**冷却 +N（`2-N3`【气力压制官】/ `2-E2`【能量黑洞】）。
 *               没配 `cd` 的 debuff → 这一段不进（老行为逐字不变）。
 *   · `自身` —— `2-E2` 的「把扣掉的能量转化成自身攻击力」：给**攻击者**挂一份**可累加**的
 *               `buffSum(att,'dmg')`（和藏品同一个入口），同源条数只有一条、数值往上叠（滚雪球）。
 *   第 4 个参数 `att`（攻击者，可选）只有 `自身` 用得上；不传 / 没写 `自身` → 行为与改动前一致。 */
function 应用武器debuff(def, d, 武器名, att) {
  const 源 = d.src || `${武器名}(敌)`;
  const 剩余 = Number.isFinite(Number(d.剩余)) ? Number(d.剩余) : 2;
  /* 先把同源的旧条目摘掉，并把可累加的那一项（armorCut）还回去 */
  for (const b of (def.debuffs || [])) if (b.src === 源 && b.armorCut) def.armorCut = Math.max(0, (def.armorCut || 0) - b.armorCut);
  def.debuffs = (def.debuffs || []).filter(b => b.src !== 源);
  def.buffs = (def.buffs || []).filter(b => b.src !== 源);
  if (d.hit) def.buffs.push({ src: 源, hit: d.hit, 剩余 });
  if (d.pct || d.armorCut) {
    /* ★ `pct` **一定要写数字**（哪怕 0）：`breakSum()` 是 `reduce((a,b) => a + b.pct, 0)`，
       少写一个 `pct` 会让它变成 `0 + undefined = NaN`，接着 `defMul()` / `dmgCore()` 全线 NaN。
       （这个坑是 `tests/balance.js` 跑出来的：某些档的「平均剩余 HP 比例」变成了 NaN%。） */
    const 条 = { src: 源, pct: d.pct || 0, 剩余 };
    if (d.armorCut) { 条.armorCut = d.armorCut; def.armorCut = (def.armorCut || 0) + d.armorCut; }
    def.debuffs.push(条);
  }
  /* ★ 第 4 个键 `cd`（替代写法：扣能量 → 大招冷却 +N） */
  if (d.cd) {
    const n = Math.max(1, Math.round(Number(d.cd)));
    for (const e of (def.weapons || [])) if (isUltimate(e.t)) e.cd = Math.max(0, (e.cd || 0) + n);
  }
  /* ★ `自身`：给**攻击者**叠一份可累加的增益（同源只留一条、数值往上加 —— 这就是「滚雪球」） */
  if (d.自身 && att) {
    const 旧 = (att.buffs || []).find(b => b.src === 源);
    if (旧) { for (const [k, v] of Object.entries(d.自身)) 旧[k] = (Number(旧[k]) || 0) + Number(v); 旧.剩余 = 剩余; }
    else att.buffs = (att.buffs || []).concat([Object.assign({ src: 源, 剩余 }, d.自身)]);
  }
  return 源;
}

/** debuff 的人话（记录里那一句「（破甲 −25%，到下回合结束）」）。 */
function debuff文字(d) {
  const 们 = [];
  if (d.hit) 们.push(`命中 ${d.hit}`);
  if (d.pct) 们.push(`破甲 −${d.pct}%`);
  if (d.armorCut) 们.push(`削装甲 ${d.armorCut}`);
  if (d.cd) 们.push(`大招冷却 +${Math.round(Number(d.cd))}`);
  if (d.自身) 们.push(`自身${Object.entries(d.自身).map(([k, v]) => ` ${k} +${v}`).join('、')}`);
  return `挂上 debuff：${们.join('、')}，到下回合结束`;
}
