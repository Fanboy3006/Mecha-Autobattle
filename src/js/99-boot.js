/* ============================================================================
 * 机甲指挥 · 收尾（boot）
 * ----------------------------------------------------------------------------
 * 1. 把顶栏上的版本 / 里程碑文字填上（让「页面打开了而且没报错」肉眼可见）；
 * 2. 关闭 `00-head.js` 打开的 IIFE，把调试接口挂到 `window.__game`。
 *
 * M1（战斗内核）还没有界面：战斗画面在 M2。这里把内核暴露出去，
 * 让 `node tests/sim.js` 能在没有浏览器的情况下跑一百场。
 * ========================================================================== */

function boot() {
  const verEl = $('#ver'); if (verEl) verEl.textContent = 'v' + VERSION;
  const msEl = $('#ms'); if (msEl) msEl.textContent = MILESTONE;
  const cnt = $('#count'); if (cnt) {
    cnt.textContent = `${ALLY_T.length} 名角色 · ${Object.keys(ENEMY_T).length} 种敌人 · ${Object.keys(ENEMY_TIER).reduce((n, k) => n + ENEMY_TIER[k].length, 0)} 个梯队敌人`;
  }
}

const G = {
  version: VERSION,
  milestone: MILESTONE,
  ready: false,
  slots: SLOTS,          // 6：双方各 2 排 × 3 列（方案 3.1）
  rows: ROWS, cols: COLS,
  mulberry32,            // 带种子的随机数（方案 6.1）
  /* ---- M1 战斗内核 ---- */
  simulate,              // simulate(我方, 敌方, 指令, 种子) → {结果, 回合数, 记录, …}
  makeUnits,             // 编成数组 → 单位数组
  makeUnit,              // 单个：{键, 位, 等级}
  speedOf, livingOf, unitRow, frontAlive,
  expectedDamage, resolveAttack, usableWeapons, healAmount, weaponPlayable, wv,
  /* 引擎内部（给测试驱动一场战斗用） */
  newBattle, runTurn, endTurn, checkResult, aiAction, enemyAction, grantTargetOf, runAutoCast, actionOrder,
  /* 射程换算 / 公式（给测试和以后的界面用） */
  rangeKindOf, rowReachable, rowBlockPenalty, areaSlots, ROW_FRONT, ROW_BACK,
  isAreaKind, isHealKind, isSupportKind, KIND_SUPPORT,
  statCoef, hitRate, critRate, dmgCore, critMul, isSure,
  编成表, 选编成, 编成到单位, 默认五人队, 类型到Kind,
  月光祝福范围, 残月余响范围, 再动,
  /* ---- 数据（方便在控制台里查看） ---- */
  ALLY_T, ENEMY_T, CLASSES, FACTIONS, TIER, TIER_NAME, tierOf, AIM_BY_CLASS, ENEMY_TIER, tierOfEnemy, runEnemyLv,
  boot,
};
window.__game = G;
boot();
G.ready = true;
})();
