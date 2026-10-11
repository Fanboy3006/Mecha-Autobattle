/* ============================================================================
 * 单位：把模板变成战场上的 Lv N 单位（方案 3.1 / 3.2 的站位与速度）
 * ----------------------------------------------------------------------------
 * 抄的出处：
 *   makeUnit      ← 07-状态.js:14-17     （去掉格子坐标 x/y、朝向、变身、ZOC 等）
 *   levelUp       ← 07-状态.js:18-26     （每级 +2、我方 Lv20 / Lv30 晋升 +25、装甲 +25%、闪避 +8、命中 +10）
 *   速度公式      ← 方案 3.2：机动（mov）× 10 + 闪避 ÷ 2，取整
 *
 * 站位：双方各 9 格 = 2 排（前排 4 + 后排 5），格子编号 slot = 排首格 + 列
 * （0–3 前排、4–8 后排；排首格 / 列数 / 阻挡关系都在 05-阵型.js）。
 * ========================================================================== */

const otherSide = s => s === 'ally' ? 'enemy' : 'ally';
const unitRow = u => rowOfSlot(u.slot);
const unitCol = u => colOfSlot(u.slot);
const speedOf = u => Math.round(u.mov * 10 + u.eva / 2);      // 方案 3.2
/* 职业（方案 6.3）：职业特色只对我方生效，敌人按梯队。判定函数在 30-射程.js。 */
const 战斗分类 = u => (u && u.tags && u.tags.战斗分类) || null;

/* 取某一方的单位列表；livingOf = 还活着的 */
const sideUnits = (side, ctx) => side === 'ally' ? ctx.allies : ctx.enemies;
const livingOf = (side, ctx) => sideUnits(side, ctx).filter(u => u.hp > 0);
const livingUnits = ctx => ctx.allies.concat(ctx.enemies).filter(u => u.hp > 0);
/* 这一排里还有没有人（近战能不能够到后排看它；直射的「被挡」改成**按位**看 `被挡吗()`） */
const frontAlive = units => units.some(u => unitRow(u) === ROW_FRONT);
/* 还活着的位集合：直射被挡判定（30-射程.js 的 `rowBlockPenalty` / 05-阵型.js 的 `被挡吗`）要用 */
const 活位们 = units => new Set(units.map(u => u.slot));

/* ---------- 升级（07-状态.js:18-26） ---------- */
function levelUp(u, heal = false) {
  u.lv++; u.maxHp += 200; if (heal) u.hp += 200;
  u.melee += 2; u.shoot += 2; u.awaken = (u.awaken ?? 100) + 2;
  u.defense = (u.defense || 0) + (u.side === 'neutral' ? 0 : 2);
  /* 晋升档位：我方 Lv20 / Lv30 基础属性再提升一档（敌人没有这一档） */
  if (u.side === 'ally' && (u.lv === 20 || u.lv === 30)) {
    const add = Math.round(u.maxHp * .25); u.maxHp += add; if (heal) u.hp += add;
    u.armor = Math.round(u.armor * 1.25); u.melee += 25; u.shoot += 25; u.awaken += 25; u.defense += 25; u.eva += 8; u.aim += 10;
    if (u.lv === 30) u.mov += 1;
  }
}

/* ---------- 造一台机体 ----------
 * `强化` = **敌方强度倍率**（作者 2026-10-11 拍板的难度调整；默认 1 = 不强化）。
 * 只有敌人会用到它，值由 `70-编成.js` 的 `编成到单位()` / `编成波次到单位()` 按编成条目的
 * 「层 + 梯队」算好（常量与理由在 `71-改动.js` 的「难度调整」段）。
 * `当前HP比` = **HP 继承**（2026-10-11 作者：「同一次出击的队伍带着伤打下一场」）：
 * 0–1 的比例，默认 `null` = **满血**（改前的老口径逐字不变）。
 * ★ 只有肉鸽那条路（`80-界面.js` 的 `打这一场()`）会传它，别的调用点（菜单固定战斗 /
 *   `simulate()` / `tools/balance.mjs` / 测试）**一个字节都不变**（`tests/run.js` 有一段盯着）。 */
function makeUnit(键, side, slot, lv, 强化 = 1, 当前HP比 = null) {
  const tpl = side === 'ally' ? tplOf(键) : ENEMY_T[键];
  if (!tpl) throw new Error(`编成里出现了不认识的${side === 'ally' ? '角色键' : '敌人键'}：${键}`);
  const u = Object.assign({}, tpl, {
    key: 键, side, slot, lv: 1,
    maxHp: tpl.hp, hp: tpl.hp,
    /* 精准：我方按战斗分类查 AIM_BY_CLASS，敌人默认 160（07-状态.js:15） */
    aim: tpl.aim ?? (side === 'ally' ? (AIM_BY_CLASS[(tpl.tags || {}).战斗分类] ?? 160) : 160),
    shieldHp: tpl.shield || 0,
    buffs: [], debuffs: [], armorCut: 0,
    barrierLeft: 3,          // 能量屏障开场 3 次（07-状态.js:15）
    name: side === 'ally' ? tpl.pilot : tpl.mech,
    /* 武器运行期状态：cd = 普通冷却（开场都是 0）、uses = 剩余次数、readyTurn = 开场冷却到第几回合 */
    weapons: tpl.weapons.map(w => ({ t: w, cd: 0, uses: w.uses, readyTurn: 1 + startCdOf(w) })),
  });
  while (u.lv < lv) levelUp(u, true);
  u.hp = u.maxHp;
  /* ★ 敌方强度（`ENEMY_SCALE` 的「强度」那一半 · 作者 2026-10-11 拍板的难度调整）：
     按「层 + 梯队」给的倍率，乘在 威力 / 装甲 / 防御 / HP / 精准 上。
     常量、公式形状、出处与实测理由全部写在 `71-改动.js` 的「难度调整」段；
     **公式一个字没改**，`10-数据.js`（战棋复制件）也一个字节没改（缩放的是单位自己的武器副本）。
     ★ 倍率 = 1（第 1 层 / 默认 1 / 手搭的敌方规格没写 `强化`）→ **这一整段不进**，与改前逐字相同；
     ★ 我方（`side !== 'enemy'`）永远不会走到这一段。 */
  u.强化 = 1;
  if (side === 'enemy' && Number(强化) > 1.0001) {
    应用敌方强化(u, Number(强化), { 来源: '编成（层 × 梯队）' });
    u.强化 = Number(强化);
  }
  /* ★ HP 继承（2026-10-11）：**放在最后** —— 上面任何一步（升级 / 强化）都可能改过 `maxHp`，
     按比例算出来的才是「这一台现在还剩多少」。传 `null` = 满血，与改前**逐字相同**。 */
  u.hp = 按比例算HP(u.maxHp, 当前HP比, HP继承参数());
  return u;
}

/* ---------- 造一整队 ----------
 * 编成条目的写法：{键:'B1', 位:0, 等级:10}（键 / 位 / 等级 都可以省略，
 * 位默认按顺序摆，等级默认：我方 10，敌人按第 1 层普通作战的等级曲线）。
 * `hp`（可选，0–1 的比例）= **HP 继承**（肉鸽那条路会带上；不写 = 满血）。 */
const 默认等级 = (键, side) => side === 'ally' ? 10 : (runEnemyLv('battle', 1, 0) + TIER_LV[tierOfEnemy(键)]);

function makeUnits(编成, side) {
  return 编成.map((s, i) => {
    const 键 = s.键 || s.key || s.mech;
    const 位 = s.位 != null ? s.位 : (s.slot != null ? s.slot : i);
    const 等级 = s.等级 || s.lv || 默认等级(键, side);
    if (位 < 0 || 位 >= SLOTS) throw new Error(`编成里的位置 ${位} 越界（只有 0–${SLOTS - 1}）`);
    /* `s.强化` = 敌方强度倍率（只有敌人会被 `70-编成.js` 写上；没有 = 1 = 不强化） */
    const 强化 = s.强化 != null ? s.强化 : (s.敌方强度 && s.敌方强度.倍率) || 1;
    /* `s.hp` = HP 比例（0–1，**肉鸽那条路才传**；不写 = null = 满血） */
    const 比例 = s.hp != null ? s.hp : (s.hp比 != null ? s.hp比 : null);
    return makeUnit(键, side, 位, 等级, 强化, 比例);
  });
}
