/* ============================================================================
 * 播放引擎（方案 8.1：动画只影响播放，不影响结果）
 * ----------------------------------------------------------------------------
 * 做法：先用 `simulate()` 把整场**一次算完**（带种子、可复现），拿到的逐条记录
 * 再按时间"放"出来——攻击者前冲、受击闪白、飘伤害数字。
 * 二倍速 / 跳过动画只改播放速度，**不碰战斗结果**，所以同一种子无论怎么看结果一样。
 *
 * 记录里带的字段（60-战斗.js 写的）：
 *   类型：开始 / 回合 / 攻击 / 修理 / 增益 / 再动 / 压制射击 / 残月余响 / 跳过 / 结束
 *   单位 / 位、目标 / 目标位、伤害、目标剩余HP、回复、命中、暴击、段数
 * ========================================================================== */

const 每步毫秒 = 500;        // 方案 8.1：「每次行动 0.5 秒左右」
const 快进毫秒 = 120;        // 回合标记 / 开始 / 结束这类没有动作的记录

/* ★ 2026-10-13（播放层兜底，作者报的「播放到〔嘲讽〕卡住」收尾）：
 * **记录怎么放，只认这张表**；表里没有的（以后新加的任何 `类型`）走 `默认毫秒`。
 * 以前是一句三元表达式（`回合/开始/结束` ? 快进 : 每步），认不出的类型**碰巧**也走每步 —— 但那是巧合，
 * 不是兜底：哪天表改成「查不到就是 undefined」，`setTimeout(fn, undefined)` 就等于**这一步永远不推进**。
 * 现在写成明面上的兜底：**认不出的类型 / 缺 `类型` / 算出来不是正数 → 一律 `默认毫秒`**。 */
const 时长表 = { 回合: 快进毫秒, 开始: 快进毫秒, 结束: 快进毫秒 };
const 默认毫秒 = 每步毫秒;

const 播放 = {
  战报: null,
  位置: 0,
  单位: {},          // "side:slot" → {hp, maxHp, shieldHp, 死}
  当前: null,
  倍速: 1,
  暂停中: false,
  快进: false,
  手动: false,       // 测试用：true 时不排计时器，由测试自己调 tick()
  计时: null,
  上次出错: null,    // 上一次「每步」钩子抛的异常（吞掉了但要留证据，见 `叫每步()`）
  钩子: { 每步: null, 结束: null },

  载入(战报) {
    this.战报 = 战报;
    this.位置 = 0;
    this.倍速 = 1;
    this.暂停中 = false;
    this.快进 = false;
    this.当前 = null;
    this.单位 = {};
    this.上次出错 = null;    // 每一回合 / 每一场重新起算（上一回合吞掉的异常不带到这一场）
    /* 血条从**这一回合开始时**的状态开始走（打一回合之后传进来的快照就是这个状态） */
    for (const u of 战报.我方.concat(战报.敌方)) {
      const 满 = u.maxHp, 血 = u.hp != null ? u.hp : 满;
      this.单位[u.side + ':' + u.slot] = { hp: 血, maxHp: 满, shieldHp: u.shieldHp != null ? u.shieldHp : (u.shield || 0), 死: 血 <= 0 };
    }
    return this;
  },

  事件() { return this.战报 ? this.战报.记录 : []; },
  剩余() { return this.事件().length - this.位置; },
  在放() { return !!this.战报 && this.位置 < this.事件().length; },

  /** 开始播放。快进（跳过动画）时直接把剩下的记录全部应用掉。 */
  开始() {
    if (this.快进) return this.跳到结尾();
    this.暂停中 = false;
    this.排一次();
    return this;
  },
  排一次() {
    if (this.手动 || this.暂停中 || !this.在放()) return;
    if (this.计时) clearTimeout(this.计时);
    const ev = this.事件()[this.位置];
    this.计时 = setTimeout(() => this.tick(), this.时长(ev) / this.倍速);
  },
  /** 这一条记录该等多少毫秒。★ **任何记录都有时长**（认不出的类型 → `默认毫秒`）：
   *  `setTimeout(fn, undefined / NaN / 0)` 在浏览器里虽然会当成 0 立刻跑，但那属于「碰巧」——
   *  这里给出一个**正数**，播放层就永远有一根能烧到头的引线（作者 2026-10-13 报的卡死要的就是这条）。 */
  时长(ev) {
    const t = ev && ev.类型;
    const ms = Object.prototype.hasOwnProperty.call(时长表, t) ? 时长表[t] : 默认毫秒;
    return Number.isFinite(ms) && ms > 0 ? ms : 默认毫秒;
  },

  /** 叫一次「每步」钩子（界面画那一条）。★ **钩子抛异常只记一笔、绝不往外扔** ——
   *  播放层对「怎么放」负全责：任何一条记录（包括以后新加的类型、包括界面自己写错的一行）
   *  都不许把播放链弄断。2026-10-13 的真 bug 就是这里的反面：`界面.播一步()` 抛了
   *  `InvalidCharacterError`（`classList.add('hit crit')`），异常从 `tick()` 里冒出去，
   *  把末尾那句 `排一次()` 跳过 → 停在暴击那一条、必须点「跳过动画」才能继续。 */
  叫每步(ev) {
    if (!this.钩子.每步) return this;
    try { this.钩子.每步(ev, this); }
    catch (e) { this.上次出错 = (e && e.message) ? e.message : String(e); }
    return this;
  },

  /** 应用**一条**记录（浏览器里由计时器调，测试里手动调）。 */
  tick() {
    if (this.计时) { clearTimeout(this.计时); this.计时 = null; }
    if (this.暂停中) return this;
    if (!this.在放()) { this.收尾(); return this; }
    const ev = this.事件()[this.位置];
    this.当前 = ev;
    this.应用(ev);
    this.位置++;
    this.叫每步(ev);
    if (this.在放()) this.排一次(); else this.收尾();
    return this;
  },

  /** 把一条记录的效果落到 this.单位 上（只为了显示血条 / 闪白 / 飘字）。 */
  应用(ev) {
    if (!ev || ev.目标方 == null || ev.目标位 == null) return;
    const 受 = this.单位[ev.目标方 + ':' + ev.目标位];
    if (!受) return;
    if (ev.目标剩余HP != null) { 受.hp = ev.目标剩余HP; 受.死 = 受.hp <= 0; }
    else if (ev.回复 != null) 受.hp = Math.min(受.maxHp, 受.hp + ev.回复);
  },

  暂停() { this.暂停中 = true; if (this.计时) { clearTimeout(this.计时); this.计时 = null; } return this; },
  继续() { if (this.暂停中) { this.暂停中 = false; this.排一次(); } return this; },
  切倍速() { this.倍速 = this.倍速 === 1 ? 2 : 1; return this; },
  设倍速(n) { this.倍速 = n; return this; },

  /** 跳过动画：把剩下的记录全部应用完，直接到结算（结果不变）。 */
  跳到结尾() {
    if (!this.战报) return this;
    while (this.在放()) { const ev = this.事件()[this.位置]; this.当前 = ev; this.应用(ev); this.位置++; }
    this.当前 = null;
    this.叫每步(null);
    this.收尾();
    return this;
  },

  收尾() {
    if (this.计时) { clearTimeout(this.计时); this.计时 = null; }
    this.暂停中 = false;
    if (this.钩子.结束) { const f = this.钩子.结束; this.钩子.结束 = null; f(this); }
    return this;
  },
};
