/* ============================================================================
 * 单位：把模板变成战场上的 Lv N 单位（方案 3.1 / 3.2 的站位与速度）
 * ----------------------------------------------------------------------------
 * 抄的出处：
 *   makeUnit      ← 07-状态.js:14-17     （去掉格子坐标 x/y、朝向、变身、ZOC 等）
 *   levelUp       ← 07-状态.js:18-26     （每级 +2、我方 Lv20 / Lv30 晋升 +25、装甲 +25%、闪避 +8、命中 +10）
 *   速度公式      ← 方案 3.2：机动（mov）× 10 + 闪避 ÷ 2，取整
 *
 * 站位：双方各 2 排 × 3 列，格子编号 slot = 排 × 3 + 列（0–2 前排、3–5 后排）。
 * ========================================================================== */

const otherSide = s => s === 'ally' ? 'enemy' : 'ally';
const unitRow = u => rowOfSlot(u.slot);
const unitCol = u => colOfSlot(u.slot);
const speedOf = u => Math.round(u.mov * 10 + u.eva / 2);      // 方案 3.2
/* 格子的人话名字：前1 / 后3（界面上和战斗记录里都用它） */
const 位名 = 位 => `${位 < COLS ? '前' : '后'}${位 % COLS + 1}`;
/* 职业（方案 6.3）：职业特色只对我方生效，敌人按梯队。判定函数在 30-射程.js。 */
const 战斗分类 = u => (u && u.tags && u.tags.战斗分类) || null;

/* 取某一方的单位列表；livingOf = 还活着的 */
const sideUnits = (side, ctx) => side === 'ally' ? ctx.allies : ctx.enemies;
const livingOf = (side, ctx) => sideUnits(side, ctx).filter(u => u.hp > 0);
const livingUnits = ctx => ctx.allies.concat(ctx.enemies).filter(u => u.hp > 0);
/* 这一排里还有没有人（近战能不能够到后排、直射打后排有没有被挡，都看它） */
const frontAlive = units => units.some(u => unitRow(u) === ROW_FRONT);

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

/* ---------- 造一台机体 ---------- */
function makeUnit(键, side, slot, lv) {
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
  return u;
}

/* ---------- 造一整队 ----------
 * 编成条目的写法：{键:'B1', 位:0, 等级:10}（键 / 位 / 等级 都可以省略，
 * 位默认按顺序摆，等级默认：我方 10，敌人按第 1 层普通作战的等级曲线）。 */
const 默认等级 = (键, side) => side === 'ally' ? 10 : (runEnemyLv('battle', 1, 0) + TIER_LV[tierOfEnemy(键)]);

function makeUnits(编成, side) {
  return 编成.map((s, i) => {
    const 键 = s.键 || s.key || s.mech;
    const 位 = s.位 != null ? s.位 : (s.slot != null ? s.slot : i);
    const 等级 = s.等级 || s.lv || 默认等级(键, side);
    if (位 < 0 || 位 >= SLOTS) throw new Error(`编成里的位置 ${位} 越界（只有 0–${SLOTS - 1}）`);
    return makeUnit(键, side, 位, 等级);
  });
}
