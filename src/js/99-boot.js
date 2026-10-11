/* ============================================================================
 * 机甲指挥 · 收尾（boot）
 * ----------------------------------------------------------------------------
 * 1. 把顶栏上的版本 / 里程碑文字填上；
 * 2. 把界面点亮（菜单屏）；
 * 3. 关闭 `00-head.js` 打开的 IIFE，把调试接口挂到 `window.__game`
 *    （测试 `tests/smoke.js` / `tests/sim.js` / `tests/battle_ui.js` 都从这里取）。
 * ========================================================================== */

function boot() {
  const verEl = $('#ver'); if (verEl) verEl.textContent = 'v' + VERSION;
  const msEl = $('#ms'); if (msEl) msEl.textContent = MILESTONE;
  界面.开屏('菜单');
}

const G = {
  version: VERSION,
  milestone: MILESTONE,
  ready: false,
  slots: SLOTS,          // 双方各几个位置（现在「前 3 后 2」= 5，阵型在 05-阵型.js 里配）
  rows: ROWS, 行列数, 阵型表, 行名, 位名, 列上所有格,
  mulberry32,            // 带种子的随机数（方案 6.1）

  /* ---- 界面 / 播放（M2） ---- */
  界面, 播放, FACTION_COL, 势力色,
  /* ---- 肉鸽（M4） ---- */
  肉鸽, 肉鸽界面, 肉鸽数值, 存档键, 节点类型表, 抽编成, 选编成, 行列数,
  /* ---- 美术 / 音乐（M5） ---- */
  图标, 音乐, 场景曲,        // 图标层（art/mech-icons.js）、音乐接线（audio/local-music.js）
  get MechIcons() { return 图标.取MI(); },   // 素材本体，给测试 / 控制台用
  get MechAudio() { return 音乐.层(); },

  /* ---- 战斗内核（M1 / M3） ---- */
  开局, 设指令, 算意图, 打一回合,   // M3：一回合一个回合地打（玩家的指令每回合都可能改）
  simulate,              // simulate(我方, 敌方, 指令, 种子) → 一整场（测试 / 平衡工具用）
  makeUnits,             // 编成数组 → 单位数组
  makeUnit,              // 单个：{键, 位, 等级}
  speedOf, livingOf, unitRow, frontAlive, 位名, 职业是, 战斗分类,
  expectedDamage, resolveAttack, usableWeapons, healAmount, weaponPlayable, wv,
  /* 引擎内部（给测试驱动一场战斗用） */
  endTurn, checkResult, aiAction, enemyAction, grantTargetOf, runAutoCast, actionOrder,
  chooseHeal, 修理阈值,       // 修理策略（作者 2026-10-10：低于 60% 才修）——tests/heal.js 直接读它
  守护关系, 守护者, 嘲讽, 单位动作,
  /* 射程换算 / 公式（给测试和以后的界面用） */
  rangeKindOf, rowReachable, rowBlockPenalty, areaSlots, ROW_FRONT, ROW_BACK,
  isAreaKind, isHealKind, isSupportKind, KIND_SUPPORT,
  statCoef, hitRate, critRate, dmgCore, critMul, isSure, isUltimate,
  编成表, 选编成, 编成到单位, 默认五人队, 类型到Kind,
  月光祝福范围, 残月余响范围, 再动,
  /* ---- 站桩 Boss 脚本（方案 5.2 / 61-Boss.js） ---- */
  Boss脚本, 取Boss脚本, 是Boss单位, Boss参数, Boss阶段序号, Boss触发阈值,
  Boss本回合放大技能, Boss下次技能回合, Boss本回合禁用, Boss伤害倍率, bossAction, bossTurn,
  /* ---- 数据（方便在控制台里查看） ---- */
  ALLY_T, ENEMY_T, CLASSES, FACTIONS, TIER, TIER_NAME, tierOf, AIM_BY_CLASS, ENEMY_TIER, tierOfEnemy, runEnemyLv,
  boot,
};
window.__game = G;
boot();
G.ready = true;
})();
