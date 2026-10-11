/* ============================================================================
 * 射程换算：能打到哪一排（方案 3.3）
 * ----------------------------------------------------------------------------
 * 战棋里每把武器都有 `fire`（melee / direct / indirect / map / support / heal /
 * passive / device）和 `range`。新项目里**只用 fire 判断"能打谁"**：
 * `range` 的数值不再用，`afterMove` 等移动相关字段一律忽略。
 *
 * 换算必须是**纯函数**，不要手改每把武器（方案 3.3 的硬要求）。
 *
 *   fire       新类型   能打谁
 *   melee      近战     只能打敌方前排；前排没人了才能打后排
 *   direct     直射     任意目标；打后排时敌方前排还有人 → 命中 −20（被挡）
 *   indirect   曲射     任意目标，没有惩罚
 *   map/support 范围    按武器新加的 area：row / col / cross / all（没写默认 row）
 *   heal       修理     我方任意一台，优先 HP 比例最低的
 *   passive / device    第一期不做（方案 6.2）
 *
 * 站位在 05-阵型.js 里配（作者 2026-10-10：暂时「前 3 后 2」，之后会扩充）：slot 从 0 开始按排数下来，
 * row 0 = 前排、1 = 后排；前排靠近敌人。
 * ========================================================================== */

const KIND_MELEE = '近战', KIND_DIRECT = '直射', KIND_INDIRECT = '曲射', KIND_AREA = '范围', KIND_HEAL = '修理';
/* 支援类（加增益 / 再动）：方案 3.3 的表里 `support`（伤害类）算「范围」，
   但作者 2026-10-10 定了要做的两种支援（Feena 的月光祝福、再动）没有伤害，
   所以单独判成「支援」，不参与「进攻」的武器挑选。 */
const KIND_SUPPORT = '支援';

/* 排号 ROW_FRONT / ROW_BACK 和格子编号都在 05-阵型.js 里（阵型可扩充） */

const RANGE_KIND = {
  melee: KIND_MELEE,
  direct: KIND_DIRECT,
  indirect: KIND_INDIRECT,
  map: KIND_AREA,
  support: KIND_AREA,
  heal: KIND_HEAL,
};

/** 武器的射程类型；第一期不做的武器返回 null（调用方直接跳过这把武器）。 */
function rangeKindOf(w) {
  const fire = w && w.fire;
  if (fire === 'passive' || fire === 'device') return null;
  // 没有伤害的支援武器（带 buff / grant 字段）单算一类
  if (fire === 'support' && (w.buff || w.grant)) return KIND_SUPPORT;
  return RANGE_KIND[fire] || KIND_DIRECT;   // 没写 fire 的按直射处理（wp() 的默认值也是 direct）
}

const isAreaKind = kind => kind === KIND_AREA;
const isHealKind = kind => kind === KIND_HEAL;
const isSupportKind = kind => kind === KIND_SUPPORT;
/* 带支援字段的支援武器（方案 3.3 之外，作者 2026-10-10 定） */
const hasSupportField = w => !!(w && (w.buff || w.grant));

/** 这个类型能不能打到指定那一排。frontAlive = 敌方前排是否还有人。 */
function rowReachable(kind, targetRow, frontAlive) {
  if (kind === KIND_MELEE) return targetRow === ROW_FRONT || !frontAlive;
  return true;
}

/** 「被挡」的命中修正：直射打后排、而敌方前排还有人 → −20；其他情况 0。
 *  职业特色（方案 6.3）：我方的狙击打后排没有这个惩罚。 */
function rowBlockPenalty(kind, targetRow, frontAlive, attacker) {
  if (职业是(attacker, '狙击')) return 0;
  return (kind === KIND_DIRECT && targetRow === ROW_BACK && frontAlive) ? -20 : 0;
}
/* 方案 6.3 的职业特色都只对我方生效（敌人按梯队，没有「职业」）。 */
const 职业是 = (u, k) => !!u && u.side === 'ally' && !!(u.tags && u.tags.战斗分类 === k);

/** 范围武器的落点：area 决定打哪些格子（没写 area 默认 row）。返回 slot 数组。
 *  阵型是「前 3 后 2」（可扩充），所以一排有几格由 05-阵型.js 决定：
 *   - row   = 那一整排；
 *   - col   = 同一列上的格子（前列0+后列0、前列1+后列1；前列2 后排没有对位，就只有自己）；
 *   - cross = 目标格 + 同排左右相邻 + 另一排同列（有的话）；
 *   - all   = 全部。 */
function areaSlots(w, row, col) {
  const area = (w && w.area) || 'row';
  const out = [];
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < 行列数(r); c++) {
      let hit = false;
      if (area === 'all') hit = true;
      else if (area === 'row') hit = r === row;
      else if (area === 'col') hit = c === col;
      else if (area === 'cross') hit = (r === row && Math.abs(c - col) <= 1) || (c === col && Math.abs(r - row) === 1);
      if (hit) out.push(slotOf(r, c));
    }
  }
  return out;
}

