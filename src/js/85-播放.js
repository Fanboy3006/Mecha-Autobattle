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
  钩子: { 每步: null, 结束: null },

  载入(战报) {
    this.战报 = 战报;
    this.位置 = 0;
    this.倍速 = 1;
    this.暂停中 = false;
    this.快进 = false;
    this.当前 = null;
    this.单位 = {};
    for (const u of 战报.我方.concat(战报.敌方)) {
      this.单位[u.side + ':' + u.slot] = { hp: u.maxHp, maxHp: u.maxHp, shieldHp: u.shield || 0, 死: false };
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
  时长(ev) {
    const t = ev && ev.类型;
    return (t === '回合' || t === '开始' || t === '结束') ? 快进毫秒 : 每步毫秒;
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
    if (this.钩子.每步) this.钩子.每步(ev, this);
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
    if (this.钩子.每步) this.钩子.每步(null, this);
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
