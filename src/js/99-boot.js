/* ============================================================================
 * 机甲指挥 · 收尾（boot）
 * ----------------------------------------------------------------------------
 * 1. 把顶栏上的版本 / 里程碑文字填上（让「页面打开了而且没报错」肉眼可见）；
 * 2. 关闭 `00-head.js` 打开的 IIFE，把调试接口挂到 `window.__game`。
 *
 * M0 到这里就结束：不启动任何战斗，不画任何东西。
 * ========================================================================== */

function boot() {
  const verEl = $('#ver'); if (verEl) verEl.textContent = 'v' + VERSION;
  const msEl = $('#ms'); if (msEl) msEl.textContent = MILESTONE;
}

const G = {
  version: VERSION,
  milestone: MILESTONE,
  ready: false,
  slots: SLOTS,          // 6：双方各 2 排 × 3 列（方案 3.1）
  rows: ROWS, cols: COLS,
  mulberry32,            // 带种子的随机数，M1 的战斗内核要用
  boot,
};
window.__game = G;
boot();
G.ready = true;
})();
