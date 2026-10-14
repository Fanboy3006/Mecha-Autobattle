/** 词条层的参数（没有就返回空对象 → 下面的默认值生效）。 */
function 词条参数() { return (战斗结构 && 战斗结构.词条) || {}; }
/** 词条层开着吗（**默认开**；显式写 `开: false` 才关 —— 那是「逐字不变」的验证口径）。 */
function 词条开() { return !(词条参数().开 === false); }
/** 某个词条键的数值上限（没列进去 / 配错 → null = 不夹）。 */
function 词条上限(键) {
  const 表 = 词条参数().上限;
  const v = 表 && 表[键];
  return Number.isFinite(v) && v > 0 ? v : null;
}

/** 把 `战斗结构.敌方大招` 落进 `ENEMY_T`（这一步在 `10-数据.js` 之外，**模板复制件不改**）。
 *  · 已经有的同名武器**不重复 push**（重复执行本文件也只会加一次）；
 *  · `startCd` = 开场冷却（`20-战斗计算.js` 的 `startCdOf()` 只对显式写了 `startCd` 的武器听它）；
 *  · `大招: true` → `isUltimate()` 认它（界面标「· 大招」、AI 的武器池优先挑它）。
 *  ★ 战棋复制件 `10-数据.js` 一个字节都没改（`tests/balance.js` 的「模板没动」自检盯着这一条）。 */
(function 装配敌方大招() {
  for (const [键, 招] of Object.entries(战斗结构.敌方大招 || {})) {
    const t = ENEMY_T[键];
    if (!t || !Array.isArray(t.weapons)) continue;
    if (t.weapons.some(w => w && w.name === 招.名)) continue;
    const 规格 = Object.assign({}, 招);
    delete 规格.名; delete 规格.开场冷却; delete 规格.冷却;
    if (规格.威力 != null) { 规格.power = 规格.威力; delete 规格.威力; }   // 中文键 `威力` → `wp()` 的 `power`
    t.weapons.push(wp(Object.assign({
      name: 招.名,
      unlock: 1,                  // ★ 不用 unlock 当大招门（敌人等级普遍 < 20）→ 用下面的 `大招: true`
      大招: true,
      cd: 招.冷却 != null ? 招.冷却 : 5,
      startCd: 招.开场冷却 != null ? 招.开场冷却 : 3,
      uses: null,
      upgrades: [],
    }, 规格)));
  }
})();

/** ★ 大招的开场冷却（改前恒 3；现在读 `战斗结构.大招冷却.开场`）。
 *  被 `20-战斗计算.js` 的 `startCdOf()` 调用 —— **只影响没显式写 `startCd` 的大招**。 */
function 大招开场冷却() {
  const c = 战斗结构 && 战斗结构.大招冷却;
  const v = c && c.开场;
  return Number.isFinite(v) && v >= 0 ? v : 3;
}
/** ★ 大招的**普通冷却下限**（改前不额外加，数据写多少是多少；现在至少这么久）。
 *  被 `20-战斗计算.js` 的 `spendWeapon()` 调用。 */
function 大招普攻冷却() {
  const c = 战斗结构 && 战斗结构.大招冷却;
  const v = c && c.普通;
  return Number.isFinite(v) && v >= 0 ? v : 0;
}
/** 对称职业特色开着吗（`30-射程.js` 的 `职业是()` 用它）。**默认开**；显式写 false 才关。 */
function 对称职业特色开() {
  return !(战斗结构 && 战斗结构.对称职业特色 === false);
}
/** 敌人的「战斗分类」（`战斗结构.敌方职业`）；查不到 = null（这台敌人没有职业特色）。 */
function 敌方职业(键) {
  const t = 战斗结构 && 战斗结构.敌方职业;
  return (t && t[键]) || null;
}

/* ---------- ⑩ 敌人机制钩子（`stealth` / `beamReflect` / `selfDestruct`）的读参数入口 ----------
 * 全部**纯读**：不改单位状态、一个随机数都不消耗（预告 / 结算那两半也靠它们）。
 * 三个钩子的实现分别在：
 *   · **隐匿（卡 A · 幻影）** → `20-战斗计算.js` 的 `hitRate()`（命中原始值 −N）与 `resolveAttack()`（写 `隐匿` 字段）
 *   · **镜甲（卡 B · 镜甲）** → `60-战斗.js` 的 `镜甲反弹()`
 *   · **自爆（卡 C · 献祭者）**→ `60-战斗.js` 的 `自爆()` 与 `濒死自爆吗()`
 * ★ 默认**只对敌人生效**（`只给敌人: true`；我方数据里那条 `beamReflect` 这一批没接 —— 见配置注释）。 */
function 敌人机制参数() { return (战斗结构 && 战斗结构.敌人机制) || {}; }
/** 三个机制的总开关（**默认开**；显式写 `开: false` 才关 —— 那是「逐字不变」的验证口径）。 */
function 敌人机制开() { return !(敌人机制参数().开 === false); }
/** 这台单位吃不吃「敌人机制」这套钩子（默认只给敌人）。 */
function 是敌人机制单位(u) {
  if (!u) return false;
  const c = 敌人机制参数();
  return !(c.只给敌人 !== false && u.side !== 'enemy');
}
/** 这台单位现在有没有某个机制：总开关开着 + 阵营对 + 数据里写着这个能力键（`abilOn`）。 */
function 有敌人机制(u, 键) {
  return !!(u && 键 && 敌人机制开() && 是敌人机制单位(u) && abilOn(u, 键));
}
/** 三层反馈里那个【名字】（`称谓` 表；查不到就用单位自己的名字 —— 数据改名不影响这里）。 */
function 敌人机制称谓(u) {
  const t = 敌人机制参数().称谓 || {};
  return (u && ((u.key && t[u.key]) || u.name)) || '敌机';
}
/** 隐匿的**命中原始值惩罚**（配置里那个数；没配置 / 配错 → 0）。 */
function 隐匿命中惩罚() {
  const c = 敌人机制参数().隐匿 || {};
  const v = Number(c.命中惩罚);
  return Number.isFinite(v) ? Math.max(0, Math.round(v)) : 0;
}
/** 这一发**吃不吃**隐匿惩罚（卡 A 的口径：只有「瞄准打」的射程吃；近战贴身 / 范围泼洒不吃）。 */
function 隐匿吃惩罚(武器) {
  const c = 敌人机制参数().隐匿 || {};
  const 吃 = (Array.isArray(c.吃惩罚的射程) && c.吃惩罚的射程.length) ? c.吃惩罚的射程 : ['直射', '曲射'];
  const k = rangeKindOf(武器);
  return !!k && 吃.includes(k);
}
/** 这一发打在这个防御者身上要减多少命中（0 = 不吃；**纯读**，`hitRate()` 直接用它）。
 *  ★ 2026-10-13（关卡变体池 · `2-E3`【光学迷彩机】的词条键 `隐身刷新`）：
 *    「每回合重新隐身」不靠数据里的 `abilities:['stealth']`，而是**回合开始时挂的 `u.隐身中` 标记**
 *    （`60-战斗.js` 的 `词条隐身刷新()`；打中一次就摘掉，见 `20-战斗计算.js` 的 `resolveAttack()`）。
 *    两种来源**是「或」**：数据里带 `stealth` 的敌人（隐形侦察机）行为一个字节没变。 */
function 隐匿惩罚值(def, 武器) {
  if (!(有敌人机制(def, 'stealth') || (def && def.隐身中))) return 0;
  return 隐匿吃惩罚(武器) ? 隐匿命中惩罚() : 0;
}
/** 镜甲的反弹比例（0–1；没配置 / 配错 → 0 = 不反弹）。 */
function 镜甲反弹比例() {
  const c = 敌人机制参数().镜甲 || {};
  const v = Number(c.反弹比例);
  return Number.isFinite(v) ? Math.max(0, v) : 0;
}
/** 自爆的参数（威力倍率 / 濒死线 / 落点形状 / 虚拟武器名；缺项走初稿默认值）。 */
function 自爆参数() {
  const c = 敌人机制参数().自爆 || {};
  const 倍 = Number(c.威力倍率), 线 = Number(c.濒死线);
  return {
    威力倍率: Number.isFinite(倍) ? Math.max(0, 倍) : 1.5,
    濒死线: Number.isFinite(线) ? 线 : 0.35,
    范围: c.范围 || 'col',
    武器名: c.武器名 || '濒死自爆',
  };
}
/** 卡 C 的**只读标记**：这一台现在在「濒死」区间吗（HP 比例 < 濒死线 35%，还活着）。
 *  ★ **纯计算、不挂任何状态**（比在单位上挂标记更安全：战斗判定一个字节都不碰）——
 *  只用来让界面把它的卡片标红 + 写「濒死自爆：落点 …」那一句预告。 */
function 濒死自爆吗(u) {
  const c = 自爆参数();
  if (!有敌人机制(u, 'selfDestruct') || !(u && u.maxHp > 0) || u.hp <= 0) return false;
  return u.hp / u.maxHp < c.濒死线;
}

/* ---------- ⑥ 大技能形状：把 `战斗系统.大招形状` 里的覆盖落到 `ENEMY_T` 的武器上 ----------
 * 只改**武器副本的属性**（`area`），`10-数据.js` 一个字节不改、公式一行不改。 */
(function 装配大招形状() {
  for (const [键, 规] of Object.entries((战斗结构 && 战斗结构.大招形状) || {})) {
    const t = ENEMY_T[键];
    if (!t || !Array.isArray(t.weapons)) continue;
    const w = t.weapons.find(x => x && x.name === 规.武器);
    if (w && 规.area) w.area = 规.area;
  }
})();

/** ⑦ 敌方武器给我方挂的 debuff：`战斗结构.敌方debuff[敌人键][武器名]` → `{hit, pct, armorCut, 剩余}`。
 *  查不到 = null（这把武器不带 debuff，行为和改前逐字相同）。
 *  ★ 2026-10-13（关卡变体池的**词条层**）：第 3 个参数是**攻击者单位**本身（可选）——
 *    带 `词条` 的编成会在单位上挂一份 `词条武器debuff`（`{ '*': 规格 }` 或 `{ 武器名: 规格 }`），
 *    这里**优先读它**（`70-编成.js` 的 `词条到单位()` 写的）。
 *    **没挂这个词条的单位 → 走原来那句表查询，行为一个字节都不变**（调用点只在 `20-战斗计算.js`）。 */
function 武器debuff(单位键, 武器名, 单位) {
  const 自定义 = 单位 && 单位.词条武器debuff;
  if (自定义) {
    const 规 = 自定义['*'] || 自定义[武器名];
    if (规) return 规;
  }
  const t = 战斗结构 && 战斗结构.敌方debuff;
  const 招 = t && t[单位键];
  return (招 && 招[武器名]) || null;
}

/* ---------- ③ HP 继承的三个小工具（读的是上面的 `战斗结构.HP继承`） ---------- */
/** HP 继承开着吗（**默认开**；显式写 `开: false` 就退回「每场满血」）。 */
function HP继承开() {
  const c = 战斗结构 && 战斗结构.HP继承;
  return !(c && c.开 === false);
}
/** HP 继承的参数（没有就返回空对象 → 下面的默认值生效）。 */
function HP继承参数() {
  return (战斗结构 && 战斗结构.HP继承) || {};
}
/** **HP 比例（0–1）→ 这一台开场的 HP**：比例是 `null` / 不是数字 = 满血（老口径）。
 *  夹在 `最低HP`（初稿 1，被击坠的下一场按 1 点出场）与 `maxHp` 之间。 */
function 按比例算HP(maxHp, 比, 参数) {
  const c = 参数 || HP继承参数();
  const 最低 = Number.isFinite(Number(c.最低HP)) ? Number(c.最低HP) : 1;
  if (比 == null || !Number.isFinite(Number(比))) return maxHp;
  return Math.max(最低, Math.min(maxHp, Math.round(maxHp * Number(比))));
}

/* ---------- ⑧ 气势与战术指令（总攻 / 紧急掩护）的参数入口 ---------- */
function 气势总攻参数() {
  return (战斗结构 && 战斗结构.气势总攻) || {};
}
function 气势总攻开() {
  const c = 气势总攻参数();
  return c.开 !== false;
}

