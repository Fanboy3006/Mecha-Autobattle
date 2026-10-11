/* ============================================================================
 * 编成表（方案第 7 节）· 取代战棋的关卡和地图
 * ----------------------------------------------------------------------------
 * 每条 = 一组敌人和站位：{层, 类型, 前:[…], 后:[…]}。
 * 站位跟着阵型（05-阵型.js：前 3 后 2），所以 前 最多 3 个、后 最多 2 个。
 * 战斗节点从对应层 / 对应类型里**随机抽一条**（`抽编成()`）。
 *
 * ⚠ 方案第 10 节第 4 条：「敌人编成表里放哪些敌人」**不要自己决定**——
 *   下面是按「每层每种 3 条」配的**初稿**，配完给作者看，等作者改。
 *   敌人等级不用写：沿用 `runEnemyLv(kind, 层, 场次) + 梯队加成`（11-敌方梯队.js）。
 *
 * 敌人梯队（11-敌方梯队.js 的 ENEMY_TIER）：
 *   杂兵 = grunt / fighter / drone / swarm / raider / hound / bomber
 *   精锐 = shield / beamcoat / phase / stealth / mirror / jammer / sniper / artillery / beetle
 *   头目 = captain / venom / regen / funnel / berserker
 *   Boss = ENEMY_BOSS（fortress / tank / skyfort）+ BOSS_SPECIAL（flagship / bluefish）
 * ========================================================================== */

/* 类型 → runEnemyLv 的 kind（11-敌方梯队.js 的曲线用这几个词） */
const 类型到Kind = { 普通: 'battle', 精英: 'elite', 守军: 'guard', 侵蚀源: 'source', 追击: 'chase', Boss: 'final' };

/* 三档敌人池（配编成时从这里挑；同一个键在同一条里不重复） */
const 杂兵池 = ['grunt', 'fighter', 'drone', 'swarm', 'raider', 'hound', 'bomber'];
const 精锐池 = ['shield', 'beamcoat', 'phase', 'stealth', 'mirror', 'jammer', 'sniper', 'artillery', 'beetle'];
const 头目池 = ['captain', 'venom', 'regen', 'funnel', 'berserker'];

const 编成表 = [
  /* ================= 第 1 层（杂兵为主） ================= */
  { 层: 1, 类型: '普通', 前: ['grunt', 'grunt'], 后: ['drone'] },
  { 层: 1, 类型: '普通', 前: ['hound', 'fighter'], 后: ['grunt'] },
  { 层: 1, 类型: '普通', 前: ['raider', 'swarm', 'swarm'], 后: ['drone'] },
  /* 精英：作者 2026-10-10「精英必须有点挑战」→ 精锐带路 + 少量杂兵 */
  { 层: 1, 类型: '精英', 前: ['shield', 'grunt'], 后: ['sniper'] },
  { 层: 1, 类型: '精英', 前: ['beetle', 'hound'], 后: ['artillery'] },
  { 层: 1, 类型: '精英', 前: ['jammer', 'fighter', 'drone'], 后: ['stealth'] },
  /* Boss：头目 + 护卫 */
  { 层: 1, 类型: 'Boss', 前: ['captain', 'shield'], 后: ['sniper'] },
  { 层: 1, 类型: 'Boss', 前: ['venom', 'beetle'], 后: ['artillery'] },
  { 层: 1, 类型: 'Boss', 前: ['regen', 'phase'], 后: ['jammer'] },

  /* ================= 第 2 层（精锐变多） ================= */
  { 层: 2, 类型: '普通', 前: ['grunt', 'hound', 'fighter'], 后: ['drone'] },
  { 层: 2, 类型: '普通', 前: ['raider', 'swarm'], 后: ['sniper'] },
  { 层: 2, 类型: '普通', 前: ['bomber', 'grunt'], 后: ['artillery'] },
  { 层: 2, 类型: '精英', 前: ['shield', 'beamcoat', 'beetle'], 后: ['sniper'] },
  { 层: 2, 类型: '精英', 前: ['phase', 'stealth'], 后: ['mirror'] },
  { 层: 2, 类型: '精英', 前: ['jammer', 'artillery'], 后: ['beetle'] },
  { 层: 2, 类型: 'Boss', 前: ['venom', 'shield', 'beetle'], 后: ['sniper'] },
  { 层: 2, 类型: 'Boss', 前: ['berserker', 'phase'], 后: ['artillery'] },
  { 层: 2, 类型: 'Boss', 前: ['funnel', 'beamcoat'], 后: ['jammer'] },

  /* ================= 第 3 层（头目坐镇） ================= */
  { 层: 3, 类型: '普通', 前: ['shield', 'hound', 'fighter'], 后: ['sniper'] },
  { 层: 3, 类型: '普通', 前: ['beetle', 'raider'], 后: ['artillery'] },
  { 层: 3, 类型: '普通', 前: ['phase', 'swarm'], 后: ['jammer'] },
  { 层: 3, 类型: '精英', 前: ['berserker', 'beamcoat', 'stealth'], 后: ['sniper'] },
  { 层: 3, 类型: '精英', 前: ['funnel', 'mirror'], 后: ['artillery'] },
  { 层: 3, 类型: '精英', 前: ['regen', 'jammer'], 后: ['beetle'] },
  { 层: 3, 类型: 'Boss', 前: ['captain', 'venom', 'shield'], 后: ['berserker'] },
  { 层: 3, 类型: 'Boss', 前: ['funnel', 'beetle'], 后: ['artillery'] },
  { 层: 3, 类型: 'Boss', 前: ['regen', 'stealth'], 后: ['sniper'] },

  /* ================= 第 4 层（终点：蓝色大肥鱼） =================
     战棋：3 层航区 + 第 4 层终点；方案 5.2 说第一期 Boss 只做蓝色大肥鱼这一个。 */
  { 层: 4, 类型: 'Boss', 前: ['bluefish'], 后: ['sniper', 'artillery'] },
  { 层: 4, 类型: 'Boss', 前: ['bluefish', 'shield'], 后: ['jammer'] },
  { 层: 4, 类型: 'Boss', 前: ['bluefish', 'beetle', 'phase'], 后: ['regen'] },
];

/** 按层 / 类型筛出候选编成。 */
function 选编成(层, 类型) {
  return 编成表.filter(e => (层 == null || e.层 === 层) && (类型 == null || e.类型 === 类型));
}

/** 从对应层 / 类型的候选里随机抽一条（走带种子的随机数，测试可复现）。 */
function 抽编成(层, 类型, rng) {
  const 候选 = 选编成(层, 类型);
  if (!候选.length) return null;
  const r = rng || Math.random;
  return 候选[Math.min(候选.length - 1, Math.floor(r() * 候选.length))];
}

/** 把一条编成变成"敌方单位数组"。场次 = 本层打到第几场（影响等级）。 */
function 编成到单位(条目, 场次 = 0) {
  const kind = 类型到Kind[条目.类型] || 'battle';
  const 前排 = 条目.前 || [], 后排 = 条目.后 || [];
  const 列表 = [];
  前排.slice(0, 行列数(ROW_FRONT)).forEach((键, i) => 列表.push({ 键, 位: slotOf(ROW_FRONT, i), 等级: runEnemyLv(kind, 条目.层, 场次) + TIER_LV[tierOfEnemy(键)] }));
  后排.slice(0, 行列数(ROW_BACK)).forEach((键, i) => 列表.push({ 键, 位: slotOf(ROW_BACK, i), 等级: runEnemyLv(kind, 条目.层, 场次) + TIER_LV[tierOfEnemy(键)] }));
  return makeUnits(列表, 'enemy');
}

/* ---------- 默认的 Lv10 五人队（方案第 9 节 M1 验收用；肉鸽开局的样例队伍也用它） ----------
 * 方案没有指定是哪五个人，先按「五个不同职业 + 覆盖三个势力」挑一队**初稿**。 */
const 默认五人队 = [
  { 键: 'B1', 位: 0, 等级: 10 },    // 近卫 · 雷萨（影世界）
  { 键: 'B2', 位: 1, 等级: 10 },    // 尖兵 · 蕾卡（影世界）
  { 键: 'CB4', 位: 2, 等级: 10 },   // 重装 · 提耶利亚（天人）
  { 键: 'CB2', 位: 3, 等级: 10 },   // 狙击 · 洛克昂（天人）
  { 键: 'M1', 位: 4, 等级: 10 },    // 指挥 · Feena（月球王国）
];
