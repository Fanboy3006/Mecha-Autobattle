/* ============================================================================
 * 射程换算：能打到哪一格（方案 3.3 + 作者 2026-10-10 拍板的「按位阻挡」）
 * ----------------------------------------------------------------------------
 * 战棋里每把武器都有 `fire`（melee / direct / indirect / map / support / heal /
 * passive / device）和 `range`。新项目里**只用 fire 判断"能打谁"**：
 * `range` 的数值不再用，`afterMove` 等移动相关字段一律忽略。
 *
 * 换算必须是**纯函数**，不要手改每把武器（方案 3.3 的硬要求）。
 *
 *   fire       新类型   能打谁
 *   melee      近战     只能打敌方前排；前排没人了才能打后排（现状不变）
 *   direct     直射     任意目标；打**某个后排位**时看这个位的**阻挡位里还有没有活人**
 *                       —— 有 → 命中 −20（被挡）；阻挡位全灭 → 无惩罚（不是打不到！）
 *   indirect   曲射     任意目标，无视阻挡、没有惩罚
 *   map/support 范围    按武器新加的 area：row / col / cross / all（没写默认 row）
 *   heal       修理     我方任意一台，优先 HP 比例最低的
 *   passive / device    第一期不做（方案 6.2）
 *
 * ★ 作者 2026-10-10 拍板的四条（这次阵型大改）：
 *   ① 9 格 = 前排 4 + 后排 5，阻挡关系 F0→B0,B1 / F1→B1,B2 / F2→B2,B3 / F3→B3,B4；
 *   ② 直射是「命中 −20」，**不是打不到**；
 *   ③ 曲射 / 范围**无视阻挡**（本文件里它们根本不算被挡惩罚）；
 *   ④ 范围的形状跟着新几何走：`row` = 一整排（前 4 / 后 5）；
 *      `col` = **阻挡束**（一个前排位 + 它挡的 1–2 个后排位）；
 *      `cross` = 目标位 + 左右邻居 + 对位；`all` = 全场。
 *
 * 站位与阻挡关系都在 05-阵型.js 里配（`阻挡位 / 遮挡位 / 对位 / 相邻位 / 被挡吗 / 阻挡束`）。
 * ========================================================================== */

const KIND_MELEE = '近战', KIND_DIRECT = '直射', KIND_INDIRECT = '曲射', KIND_AREA = '范围', KIND_HEAL = '修理';
/* 支援类（加增益 / 再动）：方案 3.3 的表里 `support`（伤害类）算「范围」，
   但作者 2026-10-10 定了要做的两种支援（Feena 的月光祝福、再动）没有伤害，
   所以单独判成「支援」，不参与「进攻」的武器挑选。 */
const KIND_SUPPORT = '支援';

/* 排号 ROW_FRONT / ROW_BACK、格子编号、阻挡关系都在 05-阵型.js 里（阵型可扩充） */

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

/** 这个类型能不能打到指定那一排。frontAlive = 敌方前排是否还有人。
 *  ★ 近战规则**现状不变**：只能打前排，前排全灭才能打后排。 */
function rowReachable(kind, targetRow, frontAlive) {
  if (kind === KIND_MELEE) return targetRow === ROW_FRONT || !frontAlive;
  return true;
}

/** 「被挡」的命中修正（作者 2026-10-10 拍板改成**按位**）：
 *  直射 打**后排位**、而这个位的阻挡位（`遮挡位()`）里还有活人 → −20；其他情况 0。
 *  ★ 是命中修正，**不是打不到** —— 打得到，只是难打（`tests/grid.js` 第 [2] 段盯着）。
 *  职业特色（方案 6.3）：我方的狙击打后排没有这个惩罚。
 *  ★ **2026-10-11 作者拍板（看板第 5 节第 9 条「B：接」）：秘银的「取消被挡」接上了** ——
 *    作战岗**兑现过**的标定敌机 → **我方**打它时取消这个 −20（判据在 `72-势力.js` 的 `秘银取消被挡()`：
 *    只对我方生效、且只对**已兑现**的标定生效）。要取消它就把第 5 个参数（目标单位）传进来。
 *  参数：`目标位` = 被打的格子编号；`活着的位` = 被打那一方还活着的位（Set / 数组 / 单位数组都行）；
 *        `目标`（可选）= 被打的那台单位本身（不传 = 老口径，没有「取消被挡」）。 */
function rowBlockPenalty(kind, 目标位, 活着的位, attacker, 目标) {
  if (职业是(attacker, '狙击')) return 0;
  if (kind !== KIND_DIRECT) return 0;          // 近战够不够得着看 rowReachable；曲射 / 范围无视阻挡
  if (!被挡吗(目标位, 活着的位)) return 0;
  if (秘银取消被挡(attacker, 目标)) return 0;  // ★ 作战岗兑现过的标定敌机 → 取消 −20（只对我方 + 只对已兑现）
  return -20;
}
/* 方案 6.3 的职业特色。★ **2026-10-11 改成对称**（作者：「敌人也吃职业特色」）：
 *   改前 = `u.side === 'ally' && u.tags.战斗分类 === k`（**只对我方生效**，敌人按梯队）；
 *   现在 = 我方认 `tags.战斗分类`，敌方认 `71-改动.js` 的 `战斗结构.敌方职业`（查不到 = 没有特色）。
 *   一个参数控制：`战斗结构.对称职业特色`（默认 true；显式写 false 就退回改前的口径）。
 *   出处（战棋同款规则）：`17b-角色机制.js` 的六条职业特效本来就不分敌我。
 *   ★ 没有 `side` 的裸对象（某些测试造的假单位）仍然按「我方」算 → 老写法逐字不变。 */
function 战斗分类Of(u) {
  if (!u) return null;
  const t = (u.tags && u.tags.战斗分类) || null;
  if (t) return t;
  if (u.side === 'enemy') return 敌方职业(u.key);
  return null;
}
const 职业是 = (u, k) => {
  if (!u) return false;
  if (u.side && u.side !== 'ally' && !对称职业特色开()) return false;
  return 战斗分类Of(u) === k;
};

/** 范围武器的落点：area 决定打哪些格子（没写 area 默认 row）。返回**升序**的 slot 数组。
 *  新几何（作者 2026-10-10 拍板，配置在 05-阵型.js）：
 *   - row   = 那一整排（前 4 格 / 后 5 格）；
 *   - col   = **阻挡束**：一个前排位 + 它挡的 1–2 个后排位（`阻挡束(位)`）；
 *   - cross = 目标位 + 同排左右邻居 + 对位（有阻挡关系的那 1–2 格）；
 *   - all   = 全场 9 格。 */
function areaSlots(w, row, col) {
  const area = (w && w.area) || 'row';
  const 位 = slotOf(row, col);
  let out;
  if (area === 'all') {
    out = [];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < 行列数(r); c++) out.push(slotOf(r, c));
  } else if (area === 'col') {
    out = 阻挡束(位).slice();
  } else if (area === 'cross') {
    out = [位];
    const r = rowOfSlot(位), c = colOfSlot(位);
    if (有这一列(r, c - 1)) out.push(slotOf(r, c - 1));
    if (有这一列(r, c + 1)) out.push(slotOf(r, c + 1));
    for (const s of 对位(位)) if (!out.includes(s)) out.push(s);
  } else {                                   // 'row' 与没写的都按一整排
    out = [];
    for (let c = 0; c < 行列数(row); c++) out.push(slotOf(row, c));
  }
  return [...new Set(out)].sort((a, b) => a - b);
}
