/* ============================================================================
 * 敌方梯队 / 等级 / 武器威力换算（从机甲战棋 30b-关卡目标.js:1-54 复制）
 * ----------------------------------------------------------------------------
 * 这一整段在战棋里虽然叫「关卡目标」，但里面装的是**数值规则**，不是关卡：
 *   - 敌人分梯队（杂兵 / 精锐 / 头目 / Boss），决定防御值、护盾词缀、等级加成；
 *   - 我方按职业、敌方按梯队给防御值，每级 +2、晋升 +25（升级在 40-单位.js）；
 *   - 旧公式的武器威力在这里换算成新公式的威力（convPow / convWeapons）——
 *     **不跑这一段，一半角色的伤害会是错的**，所以必须跟着数据一起复制过来。
 * 逐字复制，只去掉了写「关卡目标」注释和肉鸽词缀 AFFIXES 的部分（那些在 31-战斗.js，
 * 不属于 M1；护盾词缀等 M4 做肉鸽时再补）。
 *
 * 出处：mecha-tactics `Claude hand off/src/js/30b-关卡目标.js:5-54`
 * ========================================================================== */

const ENEMY_TIER = {
  杂兵: ['grunt', 'fighter', 'drone', 'swarm', 'raider', 'hound', 'bomber'],
  精锐: ['shield', 'beamcoat', 'phase', 'stealth', 'mirror', 'jammer', 'sniper', 'artillery', 'beetle'],
  头目: ['captain', 'venom', 'regen', 'funnel', 'berserker'],
};
for (const k of ENEMY_TIER.头目) if (ENEMY_T[k]) ENEMY_T[k].weak = { ...(ENEMY_T[k].weak || {}), 范围: -50 };   // 范围护壁
for (const k of Object.keys(ENEMY_T)) ENEMY_T[k].key = k;   // 单位上记住模板键，方便按梯队判断
const BOSS_SPECIAL = ['flagship', 'bluefish'];   // 不进随机 Boss 池、但算 Boss 梯队的（手工关专用）
const tierOfEnemy = k => ENEMY_BOSS.includes(k) || BOSS_SPECIAL.includes(k) ? 'Boss' : Object.keys(ENEMY_TIER).find(t => ENEMY_TIER[t].includes(k)) || '杂兵';
const TIER_LV = { 杂兵: 0, 精锐: 1, 头目: 2, Boss: 2 };

/* ---------- 新伤害公式：防御 / 觉醒属性，旧武器威力换算 ----------
   新公式：伤害 =（威力 − 装甲）×（1 +（攻击能力值 − 防御值）/ 100）。
   防御：我方按职业、敌方按梯队给初始值，每级 +2，晋升 +25。觉醒：暂时全员 100。
   源数据里的 power 还是旧公式（威力 + 属性 ×5）的数值，开局时按下面的参照点换算：
   - 我方武器：Lv10 的攻击方，打 Lv2 杂兵（杂兵平均装甲、防御 52）；
   - 敌方武器：Lv5 的敌人，打 Lv10 我方平均（装甲 600、防御 103）；
   - 特殊伤害 / 无视防御：装甲、防御都按 0。 */
const DEF_BY_CLASS = { 重装: 110, 近卫: 95, 特种: 85, 指挥: 80, 狙击: 75, 尖兵: 75 };
const DEF_BY_TIER = { 杂兵: 50, 精锐: 65, 头目: 80, Boss: 95 };
const NEW_POWER = new Set(['W2', 'W3', 'W4', 'W5', 'CB2', 'CB3', 'CB4', 'CB5', 'B1', 'M1', 'M2', 'M3', 'M4', 'M5', 'A1', 'A2', 'A3', 'A4', 'A5', 'U1', 'U2', 'U6', 'U7', 'U8', 'CB1', 'S1', 'W1', 'S2', 'S3', 'S4', 'S5', 'B3', 'B4']);
function convPow(P, statRef, multi, noDef, Aref, Dref) {
  const old = P + (multi ? .5 : 5) * statRef;
  if (noDef) return Math.max(1, Math.round(old / (1 + statRef / 100)));
  const coef = Math.max(.3, 1 + (statRef - Dref) / 100);
  return Math.max(1, Math.round((old - Aref) / coef + Aref));
}
function convWeapons(ws, t, lvAdd, Aref, Dref) {
  for (const w of ws) {
    if (!(w.power > 0) || w.fire === 'heal' || w.fire === 'support' || w.fire === 'device' || w.special === 'gamble' || w.v37) continue;
    const sr = (w.stat === '格斗' ? t.melee : t.shoot) + lvAdd, multi = w.special === 'multi' || w.special === 'funnel';
    const f = (p, dt) => convPow(p, sr, multi, dt === '特殊' || w.ignoreDef, Aref, Dref);
    w.power = f(w.power, w.dmgType);
    for (const up of w.upgrades || []) if (up.power > 0) up.power = f(up.power, w.dmgType);
    if (w.awaken && w.awaken.power > 0) w.awaken.power = f(w.awaken.power, w.awaken.dmgType || w.dmgType);
    w.v37 = true;
  }
}
{
  const gA = Math.round(ENEMY_TIER.杂兵.reduce((t, k) => t + ENEMY_T[k].armor, 0) / ENEMY_TIER.杂兵.length), gD = DEF_BY_TIER.杂兵 + 2;   // 杂兵平均装甲
  ALLY_T.forEach(t => {
    t.defense = t.defense ?? DEF_BY_CLASS[t.tags.战斗分类] ?? 85; t.awaken = t.awaken ?? 100;
    if (!NEW_POWER.has(t.mech)) convWeapons(t.weapons, t, 18, gA, gD);
  });
  for (const f of Object.values(FORMS)) if (f.weapons) { const t = ALLY_T.find(a => a.transform && FORMS[a.transform] === f) || { melee: 150, shoot: 150 }; convWeapons(f.weapons, t, 18, gA, gD); }
  for (const [k, t] of Object.entries(ENEMY_T)) {
    t.defense = t.defense ?? DEF_BY_TIER[tierOfEnemy(k)] ?? 50; t.awaken = t.awaken ?? 100;
    convWeapons(t.weapons, t, 8, 600, 103);
  }
}

/* ---------- 肉鸽敌人等级曲线（原 31-战斗.js:51-54） ----------
   一层里随场次上升（第 1 层 Lv1→3、第 2 层 4→7、第 3 层 8→12、第 4 层 13→18）。
   方案第 7 节：敌人等级沿用 runEnemyLv。M1 的测试直接用第 1 层的值。 */
function runEnemyLv(kind, layer, layerBattles) {
  const base = [0, 1, 4, 8, 13][layer], span = [0, 2, 3, 4, 5][layer], n = layerBattles || 0;
  return base + Math.min(span, n) + (kind === 'elite' || kind === 'guard' || kind === 'source' ? (layer === 1 ? 1 : 2) : 0) + (kind === 'chase' ? 1 : 0);
}
