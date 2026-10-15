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

/* ---------- ★ 2026-10-13 月球王国 Feena(M1) 主动攻击补强：读取辅助 + 一个同步钩子 ----------
 * 分工（改法照派单 §2.2 第 1 条）：
 *   · **武器属性本身**在 `71-改动-1-角色与Boss.js` 的 `应用残月主动攻击()` 里**就地**改
 *     （`unlock` 下放到 10 / `fire` 改成 `'indirect'` / `lv10Power` = 2200），原始值抄在
 *     `残月原始unlock` / `残月原始fire` 上 —— 所以 `30-射程.js`（`rangeKindOf()` 直接读 `w.fire`）与
 *     `50-AI.js`（`isUltimate()` 直接读 `w.unlock`）**一个字节都不用改**；
 *   · **动态关掉开关**（测试在页面加载后改 `战斗结构.Feena主动攻击.开 = false`）由
 *     `20-战斗计算.js` 的 `weaponPlayable()`（`残月武器可主动()`）与
 *     `72-势力-3-月球王国.js` 的 `残月武器()`（`残月武器运行期解锁()`）**动态**拦回去；
 *   · 本文件末尾的 `同步残月武器属性()` 在**页面加载时**按真表校一次
 *     （新开的页面若写 `开: false`，武器属性逐字回到数据原样）。
 * ★ 下面每个函数在 `开 === false` 时的返回值都**与改前逐字相同**（见每一行的「改前 = …」）。 */
/** `战斗结构.Feena主动攻击`（没有就返回空对象 → 下面几个辅助的默认值生效）。 */
function Feena主动攻击参数() { return (战斗结构 && 战斗结构.Feena主动攻击) || {}; }
/** 补强开着吗（**默认开**；显式写 `开: false` 才关 —— 那是「与改前逐字节一致」的验证口径）。 */
function Feena主动攻击开() { return Feena主动攻击参数().开 !== false; }
/** ★ 页面加载时按真表把两把武器的属性校一遍（`71-改动-4` 已定义 `战斗结构`）。
 *  幂等；`开 === false` → 把 `unlock` / `fire` **原样写回**（与改前逐字节一致）。 */
function 同步残月武器属性() { return 应用残月主动攻击(Feena主动攻击参数()); }

/** 这把武器是不是「残月的余响」本人（`71-改动-1` 打的 `残月下放` 标记；改名 / 改顺序都不影响）。
 *  `满月·月蚀` 是另一把（它的 `unlock` 照数据的 30，不下放）。 */
function 是残月的余响(w) { return !!(w && w.友军攻击后追加 && w.残月下放); }

/** ★ 这把「友军攻击后追加」的武器**是不是「主动攻击这一类」**（`weaponPlayable()` 里那道门）。
 *  · 不是这两把武器 → `true`（这道门**不表态**，照旧由 `weaponPlayable()` 按数据判）；
 *  · 是这两把、`开 === false`（改前）→ `false` —— 数据里它们是 `fire:'passive'`，**不许主动用**（战棋同款）；
 *  · 是这两把、`开 !== false` → `true` —— 已就地解禁成主动曲射武器，允许参与 `chooseAttack()`。
 *  ★ 这里**只看武器类别 + 总开关**（和改前 `weaponPlayable(w)` 只看武器的职责一样）：
 *    等级门 / 冷却 / 次数仍然由 `usableWeapons()` 管（残月的解锁门 = `残月武器运行期解锁()`）。 */
function 残月武器可主动(w) {
  if (!w || !w.友军攻击后追加) return true;     // 不是这两把 → 这道门不表态（照旧）
  return Feena主动攻击开();                     // 关 = false（改前）；开 = true（放行主动曲射）
}

/** ★ 这把「友军攻击后追加」武器的**运行期解锁等级**（改前 = 数据里的 `w.unlock`，逐字不变）。
 *  `71-改动-1` 把 `w.unlock` 装成了**取值器**（见那里的 `装残月运行期属性()`）：
 *  · `开 === false` → 读出来就是**数据原样**（残月的余响 20 / 满月·月蚀 30）；
 *  · `开 !== false` → 残月的余响 = `残月解锁等级`（初稿 10）；满月·月蚀 仍是 30。
 *  被 `usableWeapons()`（等级门）、`spendWeapon()`（大招判定 → 冷缺口径：下放到 10 = 不算大招，
 *  冷却只听数据的 `cd` 0）、`72-势力-3` 的 `残月武器()`、`84-反馈.js` 的 `大招状态()` 调用。 */
function 残月武器运行期解锁(w) { return w && w.unlock; }

/** ★ 这把「友军攻击后追加」武器的**运行期射程类型**（改前 = 数据里的 `w.fire`，逐字不变）。
 *  同上：`w.fire` 也是取值器 —— 关 = `'passive'`（`rangeKindOf()` 返回 `null`、`weaponPlayable()` false）、
 *  开 = `主动射程类型`（初稿 `'indirect'` = 曲射）。
 *  ★ `30-射程.js` 的 `rangeKindOf()` **不调这个函数**（它直接读 `w.fire`）—— 这里只给
 *    「要区分开 / 关两种宇宙」的调用方用（`84-反馈.js` 的预告、测试、`99-boot` 的调试口）。 */
function 残月武器运行期火(w) { return w && w.fire; }

/** ★ 残月的余响**运行期威力**：`开 !== false` 且 `u.lv < 20` → `w.lv10Power`（`71-改动-1` 就地写的初稿 2200）。
 *  其他情况一律 = `wv(u, w, 'power')`（含 `upgrades[]` 按等级取档：Lv20 = 3200、Lv30 = 5400）
 *  → `开 === false` 时**与改前逐字相同**。
 *  被 `expectedDamage()` / `dmgCore()` 的威力入口 / `resolveAttack()` 两处调用。 */
function 残月武器运行期威力(u, w) {
  if (!u || !是残月的余响(w) || !Feena主动攻击开()) return wv(u, w, 'power');
  if (!(u.lv < 20)) return wv(u, w, 'power');
  const v = Number(w && w.lv10Power != null ? w.lv10Power : Feena主动攻击参数().残月Lv10威力);
  return Number.isFinite(v) ? v : 2200;
}
/** `wv()` 的**威力专用**包装（其余 key 走原样）：只在「残月的余响 + 开 + Lv<20」时换成初稿威力。
 *  调用点见 `20-战斗计算.js` 的 `expectedDamage()` / `resolveAttack()` 与 `60-战斗-1-方针与记录.js` 的
 *  `主武器威力()`（只用来显示 / 估算，不进公式）。 */
function 威力取档(u, w, key) {
  const v = (key === 'power' || key == null) ? 残月武器运行期威力(u, w) : wv(u, w, key);
  return v;
}
/** 这台单位的武器列表里**有没有**一把「开 !== false 时能主动用的残月武器」（单位的武器列表是
 *  `makeUnit()` 原样带上的，**不按 `unlock` 过滤** —— 所以 Lv10 的 Feena 面板上一直有它）。 */
function 残月武器有主动吗(u) {
  return ((u && u.weapons) || []).some(e => e && e.t && e.t.友军攻击后追加 && 残月武器可主动(e.t));
}

/* ★ 2026-10-13：**页面加载时**按真表把两把残月武器的属性校一遍 ——
   `71-改动-1-角色与Boss.js` 先按初稿（`残月余响运行期`）就地改过（那时 `战斗结构` 还在 TDZ），
   这里 `战斗结构` 已经定义好了：`开 === false` → 属性原样写回（新开的页面逐字节等于改前）。
   放在本文件（`71-改动-5`）末尾 = 所有 `71-*` 表都定好了、任何 `makeUnit()` 都还没跑。 */
同步残月武器属性();

/* ============================================================================
 * ★ 2026-10-13 **《兰斯10》式前后排与四路战线**（正交 4×2 阵型）的读参数入口
 * ----------------------------------------------------------------------------
 * 真源 = `71-改动-4-战斗结构.js` 的 `战斗结构.兰斯战线`（用户派单 §1 原样照抄，全部【初稿·待作者调】）；
 * 接口登记 = `协作/接口约定.md` §22.2。**这里一个数字都不写死**，只做两件事：
 *   ① 把表里的数读出来（读不到 → 用表里那份初稿当兜底）；
 *   ② 把「判定」集中成**一份**（`兰斯伤害倍率` / `兰斯命中修正` / `兰斯暴击修正` / `兰斯掩护减免` /
 *      `兰斯破阵暴露` / `中枢重装防御加成`），让 `20-战斗计算.js` / `30-射程.js` / `50-AI.js` /
 *      `60-战斗-1` / `84-反馈.js` **没有第二套判据**。
 *
 * ★ **纯读**：不改单位状态、不写记录、**一个 `ctx.rng` 都不消耗**（预告层与实战同一套算式）。
 * ★ **`开 === false` 时全部恒为 0 / false / 1** → 上面那四处的算式与改前**逐字相同**。
 * ========================================================================== */
/** `战斗结构.兰斯战线`（没有就返回空对象 → 下面的默认值生效）。 */
function 兰斯战线参数() { return (战斗结构 && 战斗结构.兰斯战线) || {}; }
/** 兰斯战线开着吗（**默认开**；显式写 `开: false` 才关 —— 那是「逐字不变」的验证口径）。 */
function 兰斯战线开() { return 兰斯战线参数().开 !== false; }
/** 读一个数（读不到 / 配错 → 默认值；`开 === false` 时由各个「修正」函数自己短路成 0）。 */
function 兰斯数(键, 默认值) {
  const v = Number(兰斯战线参数()[键]);
  return Number.isFinite(v) ? v : 默认值;
}
const 前排近战增伤 = () => 兰斯数('前排近战增伤', 0.15);
const 前排远程命中惩罚 = () => 兰斯数('前排远程命中惩罚', 15);
const 后排隔排近战惩罚 = () => 兰斯数('后排隔排近战惩罚', 0.25);
const 后排远程增伤 = () => 兰斯数('后排远程增伤', 0.10);
const 后排远程命中 = () => 兰斯数('后排远程命中', 10);
const 侧翼闪避加成 = () => 兰斯数('侧翼闪避加成', 10);
const 侧翼暴击加成 = () => 兰斯数('侧翼暴击加成', 10);
const 中枢重装防御 = () => 兰斯数('中枢重装防御', 15);
const 同路索敌权重 = () => 兰斯数('同路索敌权重', 1.35);
const 相邻路索敌权重 = () => 兰斯数('相邻路索敌权重', 1.10);

/** **外侧两路**（第 1 路 `col 0` / 第 4 路 `col 3`）：侧翼游击（尖兵 / 流星小队）的判据。 */
const 在外侧两路 = u => !!u && u.slot != null && (colOfSlot(u.slot) === 0 || colOfSlot(u.slot) === 3);
/** **尖兵 / 流星小队**（侧翼游击的受益者；判据与派单 §1 原样，`职业是()` 敌我都认）。 */
const 是侧翼游击 = u => !!u && (职业是(u, '尖兵') || (u.tags && u.tags.势力 === '流星小队'));
/** **远程位（曲射类）**：`indirect` 或狙击 / 指挥。 */
const 是远程排位手 = (att, w) => !!w && (w.fire === 'indirect' || 职业是(att, '狙击') || 职业是(att, '指挥'));
/** **远程位（贴脸那一半）**：`indirect` 或狙击（不含指挥 —— 指挥不吃「前排贴脸 −15」）。 */
const 是远程贴脸手 = (att, w) => !!w && (w.fire === 'indirect' || 职业是(att, '狙击'));

/** **中枢固守**：重装站在**前排中枢**（`slot 1` / `slot 2`）→ 防御值 `+N`（0 = 不吃）。
 *  ★ 纯读、`开 === false` 恒 0 → `dmgCore` 那条 stage-2 条目 `applies` 为假、一行都不进。 */
function 中枢重装防御加成(u) {
  if (!u || !兰斯战线开()) return 0;
  if (!(u.slot === 1 || u.slot === 2)) return 0;
  if (!职业是(u, '重装')) return 0;
  const v = 中枢重装防御();
  return Number.isFinite(v) && v > 0 ? v : 0;
}

/** **命中修正**（`hitRate()` 直接加在 `h` 上；0 = 不吃）。
 *   ① 前排远程命中惩罚：`att` 在前排 +（`indirect` 或狙击）→ `−N`；
 *   ② 后排远程命中加成：`att` 在后排 +（`indirect` 或狙击 / 指挥）→ `+N`；
 *   ③ 侧翼闪避加成：守方 `def` 在外侧两路 + 尖兵 / 流星 → 有效闪避 `+N`（写在命中上就是 `−N`）。 */
function 兰斯命中修正(att, def, w, ctx) {
  if (!兰斯战线开()) return 0;
  let n = 0;
  if (att && att.slot != null) {
    if (rowOfSlot(att.slot) === ROW_FRONT && 是远程贴脸手(att, w)) n -= 前排远程命中惩罚();
    if (rowOfSlot(att.slot) === ROW_BACK && 是远程排位手(att, w)) n += 后排远程命中();
  }
  if (def && 在外侧两路(def) && 是侧翼游击(def)) n -= 侧翼闪避加成();
  return n;
}

/** **暴击修正**（`critRate()` 直接加在暴击率上；0 = 不吃）。
 *  ★ 侧翼暴击：`att` 在外侧两路 + 尖兵 / 流星 → `+N`。
 *  ⚠ `critRate(w, att)` 的签名里**没有 `def`** —— 所以这一条只看 `att`（派单 §1 也只要求看 `att`）；
 *    接口登记里写明了「不改签名」这条口径（`协作/接口约定.md` §22.4）。 */
function 兰斯暴击修正(att, w) {
  if (!兰斯战线开()) return 0;
  if (!在外侧两路(att) || !是侧翼游击(att)) return 0;
  return 侧翼暴击加成();
}

/** **同路掩护减免**：这一下该不该吃「同路掩护 −N%」，以及该减多少（0 = 不吃）。
 *  条件（派单 §1 + §2.3 第 3 条，**逐条照做**）：
 *    · `def` 在**后排**；`rangeKindOf(w) === 'direct'`（直射）；`被挡吗(def.slot, 活位们)` 为真；
 *    · 攻击者**不是狙击**；`秘银取消被挡(att, def)` 不为真（破防免除）；
 *    · `开 === false` → 0。
 *  ★ `ctx` 只用来取「被打那一方还活着的位」（`livingOf`）；没有 ctx / 战斗还没开局 → 0。
 *  ★ **纯读**：不改任何状态、不消耗随机数。 */
function 兰斯掩护减免(def, w, ctx, 被挡) {
  if (!兰斯战线开()) return 0;
  if (!def || !兰斯战线参数().同路掩护减伤) return 0;
  if (rangeKindOf(w) !== KIND_DIRECT) return 0;
  if (rowOfSlot(def.slot) !== ROW_BACK) return 0;
  const 真被挡 = (被挡 != null) ? !!被挡
    : (!!ctx && Array.isArray(def.side === 'ally' ? ctx.allies : ctx.enemies)
      && 被挡吗(def.slot, livingOf(def.side, ctx).map(x => x.slot)));
  if (!真被挡) return 0;
  return 兰斯数('同路掩护减伤', 0.30);
}

/** **同路索敌倍率**（`50-AI.js` 的 `targetScore()` 乘在 `value` 上；`开 === false` → 恒 1）。
 *  同路（`colOfSlot` 差 0）→ `同路索敌权重`；相邻路（差 1）→ `相邻路索敌权重`；其余 1。 */
function 同路索敌倍率(att, t) {
  if (!兰斯战线开() || !att || !t || att.slot == null || t.slot == null) return 1;
  const d = Math.abs(colOfSlot(att.slot) - colOfSlot(t.slot));
  if (d === 0) return 同路索敌权重();
  if (d === 1) return 相邻路索敌权重();
  return 1;
}

/** **破阵暴露**：这个（后排）单位现在同路正前方**没有任何存活敌军**吗（`30-射程.js` 的近战突袭判据）。
 *  逐条：`兰斯战线.开 && 破阵近战突袭` + 目标是后排 + `!被挡吗(target.slot, 敌方活位们)`。
 *  `敌方活位们` 可省（省了就用 `ctx` 现算）。★ 纯读。 */
function 兰斯破阵暴露(target, 敌方活位们, ctx) {
  if (!兰斯战线开() || 兰斯战线参数().破阵近战突袭 === false) return false;
  if (!target || target.slot == null) return false;
  if (rowOfSlot(target.slot) !== ROW_BACK) return false;
  const 方 = target.side || 'enemy';
  const 活位 = 敌方活位们 != null ? 敌方活位们
    : ((ctx && Array.isArray(方 === 'ally' ? ctx.allies : ctx.enemies))
      ? livingOf(方, ctx).map(x => x.slot) : []);
  return !被挡吗(target.slot, 活位);
}

/** **同路重装铁壁护卫**（`60-战斗-1` 的 `嘲讽()` 第一道门；`开 === false` → null = 走原来的 50% 掷骰）。
 *  `target` 在后排 → 同路正前方格（`target.slot - 4`）上**存活、同阵营、职业是重装**的那一台 → 直接返回它。
 *  ★ **绝不调用 `ctx.rng`**（100% 铁壁护卫）。 */
function 同路铁壁护卫(ctx, 攻击者, target) {
  if (!ctx || !target) return null;
  if (!兰斯战线开() || 兰斯战线参数().同路重装必护卫 === false) return null;
  if (target.slot == null || rowOfSlot(target.slot) !== ROW_BACK) return null;
  const 位 = 遮挡位(target.slot)[0];
  if (位 == null) return null;
  if (!ctx || !Array.isArray(target.side === 'ally' ? ctx.allies : ctx.enemies)) return null;
  const 候选 = livingOf(target.side, ctx)
    .filter(u => u.slot === 位 && 职业是(u, '重装') && u !== target && u.hp > 0);
  return 候选[0] || null;
}

/** **排位攻防倍率**（`dmgCore()` 在公式算完之后逐段相乘的那一个乘子；1 = 不吃）。
 *  按**攻击者 / 防御者的排位 + 武器类型**给（派单 §1 的四条 + 同路掩护减伤）：
 *    · 前排近战增伤      ×(1 + 0.15)
 *    · 后排隔排近战惩罚  ×(1 − 0.25)（同路前排还有存活友军时）
 *    · 后排远程增伤      ×(1 + 0.10)（`indirect` 或狙击 / 指挥）
 *    · 同路掩护减伤      ×(1 − 0.30)（直射打「被同路前排挡着」的后排；狙击 / 秘银破防免除）
 *  `o` = `dmgCore` 的上下文（要 `ctx`；`被挡` 可选 —— 传了就不重算「被挡吗」）。
 *  ★ `o.不带掩护: true` = **把「同路掩护减伤」那一项撤掉、其余一项不动** ——
 *    `resolveAttack()` 用它算「这一下因为掩护少挨了多少」的**基准那一发**（纯预览、只用来取差值）。
 *  ★ **纯读**、`开 === false` → 恒 1 → `c.dmg` 与改前**逐字相同**。 */
function 兰斯伤害倍率(att, def, w, o) {
  if (!兰斯战线开()) return 1;
  const ctx = o && o.ctx;
  const kind = rangeKindOf(w);
  let m = 1;
  const 排 = u => (u && u.slot != null ? rowOfSlot(u.slot) : null);
  const att排 = 排(att), def排 = 排(def);
  if (kind === KIND_MELEE) {
    if (att排 === ROW_FRONT) m *= 1 + 前排近战增伤();
    if (att排 === ROW_BACK && ctx && att && att.slot != null) {
      const 同路前 = (att.side === 'ally' ? ctx.allies : ctx.enemies) || [];
      if (同路前.some(x => x && x !== att && x.hp > 0 && x.slot === att.slot - 4)) m *= 1 - 后排隔排近战惩罚();
    }
  }
  if (att排 === ROW_BACK && 是远程排位手(att, w) && !(职业排位开() && 职业是(att, '狙击'))) m *= 1 + 后排远程增伤();
  if (!(o && o.不带掩护)) {
    const 掩护 = 兰斯掩护减免(def, w, ctx, o ? o.被挡 : undefined);
    if (掩护 > 0 && !职业是(att, '狙击') && !秘银取消被挡(att, def)) m *= 1 - 掩护;
  }
  return m;
}

/** **这一下因为同路掩护少挨了多少**（正整数；0 = 没触发）—— `rec.掩护减伤` 的**唯一**出处。
 *  · `未乘 = 不带掩护那一次的伤害`（由 `resolveAttack()` 走 `<1` 的倍率再算一遍 `dmgCore`，**纯预览**）；
 *  · `实 = 这一下真正的伤害`（已经含掩护减伤）；
 *  · 只有在**真的被掩护救过**（两者都在、`实 < 未乘`）时才返回正数 → 未触发时**一个字段都不挂**。 */
function 掩护减免值(未乘, 实) {
  const a = Number(未乘), b = Number(实);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return 0;
  return Math.max(0, Math.round(a - b));
}

/* ==========================================================================
 * ★ 2026-10-13：【初稿·待作者调】六大职业 × 前后排「4 专精 + 2 双态」排位体系
 * 参数表 = `战斗结构.职业排位`（`开: false` = 退回**纯兰斯战线基线**）。
 * ★ 与上面 §22 的 `兰斯战线` **并存**：两项重叠**取 max、不重复叠**
 *   （近卫前排增伤 vs 前排近战增伤、狙击后排增伤 vs 后排远程增伤）。
 * ★ **纯读**：不改单位状态、不写记录、**一个 `ctx.rng` 都不消耗**（预告层与实战同一套算式）。
 * ========================================================================== */
/** `战斗结构.职业排位`（没有就返回空对象 → 下面的默认值生效）。 */
function 职业排位参数() {
  return (typeof 战斗结构 !== 'undefined' && 战斗结构 && 战斗结构.职业排位) || {};
}
/** 职业排位开着吗（**默认开**；显式写 `开: false` 才关 —— 那是「退回兰斯战线基线」的验证口径）。
 *  ★ 2026-10-13：**兰斯战线关掉时职业排位一并关掉** —— 职业排位是《兰斯10》四路战线的专精层，
 *    战线本身不在时它没有判据（`兰斯战线开() && 职业排位参数().开 !== false`）。 */
function 职业排位开() { return 兰斯战线开() && 职业排位参数().开 !== false; }
/** 读一个数（读不到 / 配错 → 默认值；`开 === false` 时由各个「修正」函数自己短路）。 */
function 职业排位数(键, 默认值) {
  if (!职业排位开()) return 默认值;
  const v = 职业排位参数()[键];
  return typeof v === 'number' && !Number.isNaN(v) ? v : 默认值;
}

/** **职业命中修正**（`hitRate()` 里加的那一项；0 = 不吃）。
 *  · 攻方在后排：重装 `−重装后排命中惩罚`、尖兵 `+尖兵后排命中`、特种 `+特种后排命中`；
 *  · 守方在前排且是尖兵：`−尖兵前排常驻闪避`（重装/狙击/指挥的「前排贴脸 −15」仍归 `兰斯战线`）。
 *  ★ 纯读、`开 === false` 恒 0 → 命中算式与改前**逐字相同**。 */
function 职业排位命中修正(att, def, w, ctx) {
  if (!职业排位开()) return 0;
  let n = 0;
  if (att && Number.isInteger(att.slot) && rowOfSlot(att.slot) === ROW_BACK) {
    if (职业是(att, '重装')) n -= 职业排位数('重装后排命中惩罚', 15);
    if (职业是(att, '尖兵')) n += 职业排位数('尖兵后排命中', 15);
    if (职业是(att, '特种')) n += 职业排位数('特种后排命中', 10);
  }
  if (def && Number.isInteger(def.slot) && rowOfSlot(def.slot) === ROW_FRONT && 职业是(def, '尖兵')) {
    n -= 职业排位数('尖兵前排常驻闪避', 10);
  }
  return n;
}

/** **前排尖兵每回合首次受击的闪避值**（把原来写死的 `20` 换成读参数表；非「前排尖兵」恒 `20`）。
 *  ★ 纯读、`开 === false` 恒 `20` → 与改前**逐字相同**。 */
function 尖兵首闪值(def) {
  if (职业排位开() && def && Number.isInteger(def.slot) && rowOfSlot(def.slot) === ROW_FRONT) {
    return 职业排位数('尖兵前排首闪', 30);
  }
  return 20;
}

/** **职业暴击修正**（加到暴击率上的百分点；0 = 不吃）。
 *  · 后排狙击 `+狙击后排额外暴击`；后排尖兵 `+尖兵后排暴击`。
 *  ★ 纯读、`开 === false` 恒 0 → 暴击算式与改前**逐字相同**。 */
function 职业排位暴击修正(att, w) {
  if (!职业排位开() || !att || !Number.isInteger(att.slot)) return 0;
  if (rowOfSlot(att.slot) === ROW_BACK) {
    if (职业是(att, '狙击')) return 职业排位数('狙击后排额外暴击', 5);
    if (职业是(att, '尖兵')) return 职业排位数('尖兵后排暴击', 15);
  }
  return 0;
}

/** **职业攻防倍率**（`dmgCore()` 在公式算完之后逐段相乘的那一个乘子；1 = 不吃）。
 *  攻方：重装后排惩罚 / 近卫前排增伤 + 连斩追击增伤 / 近卫后排隔排惩罚 /
 *        狙击后排增伤（与 `兰斯战线` 的「后排远程增伤」**取 max**）/ 尖兵后排增伤 / 特种前排增伤；
 *  守方（前排）：重装·尖兵·特种 减伤、狙击·指挥 易伤。
 *  ★ 「已吃兰斯近战」= `兰斯战线开() && kind === KIND_MELEE` → 近卫前排增伤 / 特种前排增伤**不重复叠**；
 *  ★ `近卫连斩追击增伤` 只在该单位**本回合**是〔连斩〕追击（`att.近卫连斩追击Turn === ctx.turn`）时吃；
 *  ★ 纯读、`开 === false` 恒 1、一个 `ctx.rng` 都不消耗 → `c.dmg` 与基线**逐字相同**。 */
function 职业排位伤害倍率(att, def, w, o) {
  if (!职业排位开()) return 1;
  const ctx = o && o.ctx;
  const kind = w ? rangeKindOf(w) : null;
  const 已吃兰斯近战 = 兰斯战线开() && kind === KIND_MELEE;
  let m = 1;
  if (att && Number.isInteger(att.slot)) {
    const attRow = rowOfSlot(att.slot);
    if (职业是(att, '重装') && attRow === ROW_BACK) {
      m *= 1 - 职业排位数('重装后排伤害惩罚', 0.20);
    }
    if (职业是(att, '近卫') && attRow === ROW_FRONT) {
      if (!已吃兰斯近战) m *= 1 + 职业排位数('近卫前排增伤', 0.15);
      if (ctx && att.近卫连斩追击Turn != null && att.近卫连斩追击Turn === ctx.turn) {
        m *= 1 + 职业排位数('近卫连斩追击增伤', 0.20);
      }
    }
    if (职业是(att, '近卫') && attRow === ROW_BACK) {
      if (!已吃兰斯近战 && ctx &&
          ((att.side === 'ally' ? ctx.allies : ctx.enemies) || [])
            .some(x => x && x !== att && x.hp > 0 && x.slot === att.slot - 4)) {
        m *= 1 - 职业排位数('近卫后排隔排惩罚', 0.25);
      }
    }
    if (职业是(att, '狙击') && attRow === ROW_BACK) {
      m *= 1 + Math.max(兰斯战线开() ? 后排远程增伤() : 0, 职业排位数('狙击后排增伤', 0.15));
    }
    if (职业是(att, '尖兵') && attRow === ROW_BACK) {
      m *= 1 + 职业排位数('尖兵后排增伤', 0.15);
    }
    if (职业是(att, '特种') && attRow === ROW_FRONT) {
      if (!已吃兰斯近战) m *= 1 + 职业排位数('特种前排增伤', 0.15);
    }
  }
  if (def && Number.isInteger(def.slot) && rowOfSlot(def.slot) === ROW_FRONT) {
    if (职业是(def, '重装')) m *= 1 - 职业排位数('重装前排减伤', 0.20);
    if (职业是(def, '尖兵')) m *= 1 - 职业排位数('尖兵前排减伤', 0.15);
    if (职业是(def, '特种')) m *= 1 - 职业排位数('特种前排减伤', 0.10);
    if (职业是(def, '狙击')) m *= 1 + 职业排位数('狙击前排易伤', 0.15);
    if (职业是(def, '指挥')) m *= 1 + 职业排位数('指挥前排易伤', 0.15);
  }
  return m;
}

/** **职业修理倍率**（乘在 `healAmount` 上；1 = 不吃）。
 *  · 后排指挥 `×指挥后排修理加成`；后排特种 `×特种后排修理加成`。
 *  ★ 纯读、`开 === false` 恒 1 → 治疗量与改前**逐字相同**。 */
function 职业排位修理倍率(u) {
  if (职业排位开() && u && Number.isInteger(u.slot) && rowOfSlot(u.slot) === ROW_BACK) {
    if (职业是(u, '指挥')) return 1 + 职业排位数('指挥后排修理加成', 0.20);
    if (职业是(u, '特种')) return 1 + 职业排位数('特种后排修理加成', 0.20);
  }
  return 1;
}

/** **产标层数**（这一下攻击给目标挂几层标；原写死 `1`）。
 *  · 后排特种 `→ 特种后排产标层数`（上限仍由原逻辑夹在 3）；其余恒 `1`。
 *  ★ 纯读、`开 === false` 恒 1 → 产标与改前**逐字相同**。 */
function 特种产标层数(att) {
  if (职业排位开() && att && Number.isInteger(att.slot) && rowOfSlot(att.slot) === ROW_BACK && 职业是(att, '特种')) {
    return 职业排位数('特种后排产标层数', 2);
  }
  return 1;
}

/** **动作QTE 参数表与纯读辅助函数**（2026-10-13，§24；0 `rng`） */
function 动作QTE参数() {
  return (typeof 战斗结构 !== 'undefined' && 战斗结构 && 战斗结构.动作QTE) || {};
}

function 动作QTE开() {
  return Boolean(typeof 战斗结构 !== 'undefined' && 战斗结构 && 战斗结构.动作QTE && 战斗结构.动作QTE.开);
}

function 计算QTE晃动参数(att, def, w, stageIdx = 0, currentHitRate = 80) {
  const cfg = 动作QTE参数();
  const q = Math.max(0, Math.min(100, Number.isFinite(currentHitRate) ? currentHitRate : (w && Number.isFinite(w.hit) ? w.hit : 80)));
  let eva = 10;
  if (typeof def === 'number' && Number.isFinite(def)) {
    eva = def;
  } else if (def && typeof def === 'object') {
    const baseEva = Number.isFinite(def.eva) ? def.eva : (Number.isFinite(def.evade) ? def.evade : 10);
    const hasStealth = (Array.isArray(def.abilities) && def.abilities.includes('stealth')) || def.key === 'stealth';
    eva = baseEva + (hasStealth && baseEva <= 30 ? 25 : 0);
  }
  const minR = Number.isFinite(cfg.最小判定半径) ? cfg.最小判定半径 : 16;
  const maxR = Number.isFinite(cfg.最大判定半径) ? cfg.最大判定半径 : 38;
  const pRatio = Number.isFinite(cfg.完美核心比例) ? cfg.完美核心比例 : 0.42;
  const baseWin = Number.isFinite(cfg.基础窗口毫秒) ? cfg.基础窗口毫秒 : 650;
  const rawR = minR + (maxR - minR) * (q / 100);
  return {
    段号: stageIdx + 1,
    理论命中率: q,
    目标闪避: eva,
    晃动频率Hz: +(0.8 + eva * 0.035 + (100 - q) * 0.015).toFixed(2),
    晃动幅度X: Math.round(Math.min(68, 12 + eva * 0.75 + (100 - q) * 0.35)),
    晃动幅度Y: Math.round(Math.min(28, 4 + eva * 0.28 + (100 - q) * 0.12)),
    有效半径Px: Math.round(rawR),
    完美半径Px: Math.round(rawR * pRatio),
    窗口毫秒: Math.round(Math.max(380, baseWin - eva * 2.5)),
  };
}

