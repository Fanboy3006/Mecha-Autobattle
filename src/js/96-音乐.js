/* ============================================================================
 * 音乐接线（M5，方案 8.2）
 * ----------------------------------------------------------------------------
 * 播放层是 **原样搬过来的** `audio/local-music.js`（全局 `MechAudio`）+ `audio/music-room.js`（音乐鉴赏页），
 * 由 `tools/build-src.mjs` 内联进 HTML 的 AUDIO 块。这里只决定「什么时候放什么」，
 * 场景对应照方案 8.2 和战棋 `31d-音频接线与调试接口.js` 的规则：
 *
 *   开场菜单 = `title`；大地图 / 编队（分队、招募、奇遇这些肉鸽外壳画面）= `mapStrategy`；
 *   战斗中 = `allyPhase`（**敌方行动不切曲**：一回合只切一次，免得一阵一阵的）；
 *   Boss 战 = `boss`（肉鸽的 Boss 节点，或者练习模式里挑了 Boss 编成）；
 *   **放大招**（unlock 20 / 30 的武器）时切成这台机体的**主题曲**，保持到本回合结束
 *   （下一个我方回合开始 / 被另一首主题曲替换才换，普通攻击和敌方行动都不切；战棋 31d:45-50）。
 *   结算屏**不切曲**（战棋的 victory / defeat 两首都没有曲子，切过去就是静音，所以留在原曲上）。
 *
 * 读不到曲子（测试环境、别人的机器上没有作者本地的版权 mp3）时：播放层自己会静音、
 * 声音按钮隐藏，这里所有调用都包了 try/catch，绝不抛异常（方案 8.2 的硬性要求）。
 * ========================================================================== */

const 声音键 = 'mecha-autobattle-sound';

/** 场景 → 曲子。纯函数（测试直接调）：null = 不切曲，留在现在这首上。
 *  `是Boss` 只在「战斗」时有意义（方案 8.2：Boss 战 = boss）。 */
function 场景曲(屏, 是Boss) {
  switch (屏) {
    case '菜单': return 'title';
    case '分队': case '大地图': case '招募': case '奇遇': case '编队': return 'mapStrategy';
    case '战斗': return 是Boss ? 'boss' : 'allyPhase';
    default: return null;                       // 结算 / 肉鸽结算：不切曲
  }
}

const 音乐 = {
  场景: null,          // 现在在哪个屏（菜单 / 大地图 / 战斗 / 结算…）
  主题: null,          // 放大招切过来的主题曲 cue（null = 用场景曲）
  当前曲: null,        // 已经交给播放层的 cue
  是Boss战: false,
  开关: true,          // 顶栏的声音开关（和战棋一样存 localStorage）
  可用: null,          // 播放层报的「读得到曲子吗」；null = 还没回报
  提示: '',

  /** 播放层；AUDIO 块没注入（或者关了）时是 null，所有调用都要能承受。 */
  层() { return (typeof MechAudio !== 'undefined' && MechAudio) ? MechAudio : null; },

  /* ---------------- 启动接线 ---------------- */
  初始化() {
    /* 声音开关的偏好（关掉页面也记得） */
    try { const s = localStorage.getItem(声音键); if (s === 'off') this.开关 = false; } catch (e) {}
    const 钮 = $('#btnSound');
    if (钮) {
      钮.addEventListener('click', () => this.切开关());
      this.写按钮();
      const A = this.层();
      钮.hidden = true;                                // 先藏，等播放层回报能不能用
      if (!A) 钮.hidden = true;                        // 连播放层都没有：一直藏
      else if (A.onAvailable) A.onAvailable(ok => { this.可用 = !!ok; 钮.hidden = !ok; });
    }
    const A = this.层();
    if (A && !this.开关) { try { A.mute(true); } catch (e) {} }
    /* M 键切换（战棋的习惯） */
    if (typeof document !== 'undefined' && document.addEventListener)
      document.addEventListener('keydown', e => { if ((e.key === 'm' || e.key === 'M') && !e.ctrlKey && !e.metaKey) this.切开关(); });
    return this;
  },

  写按钮() {
    const 钮 = $('#btnSound');
    if (!钮) return;
    钮.textContent = this.开关 ? '声音' : '静音';
    钮.setAttribute('aria-pressed', String(this.开关));
    if (typeof 钮.classList.toggle === 'function') 钮.classList.toggle('on', this.开关);
  },
  /** 声音开关：顶栏按钮 / M 键 / 测试都走这里。 */
  切开关(开) {
    if (开 === undefined) 开 = !this.开关;
    this.开关 = !!开;
    try { localStorage.setItem(声音键, this.开关 ? 'on' : 'off'); } catch (e) {}
    this.写按钮();
    const A = this.层();
    if (A) {
      try {
        if (this.开关) { A.mute(false); if (A.unlock) A.unlock(); this.当前曲 = null; this.刷曲(); }
        else { this.当前曲 = null; A.stop(); A.mute(true); }
      } catch (e) {}
    }
    return this.开关;
  },

  /* ---------------- 场景 ---------------- */
  /** 这一场是不是 Boss 战：肉鸽的 Boss 节点，或者练习模式挑了 Boss 编成（方案 8.2）。 */
  算Boss() {
    const 战 = 界面.肉鸽战斗;
    if (战 && 战.类型 === 'Boss') return true;
    const 条 = 编成表[界面.编队 && 界面.编队.编成序号];
    return !!(条 && 条.类型 === 'Boss');
  },
  /** 界面切屏时调用（80-界面.js 的 开屏）。 */
  场景切换(屏) {
    this.场景 = 屏;
    this.是Boss战 = this.算Boss();
    if (屏 === '战斗') this.主题 = null;        // 新的一场战斗：从 allyPhase / boss 起
    return this.刷曲();
  },
  /** 现在该放哪首：主题曲优先，否则看场景。null = 不切（结算屏）。 */
  该放() { return this.主题 || 场景曲(this.场景, this.是Boss战); },
  /** 把该放的曲子交给播放层（同一首不重复切）。 */
  刷曲() {
    const cue = this.该放();
    if (cue == null || cue === this.当前曲) return cue;
    this.当前曲 = cue;
    const A = this.层();
    if (A) { try { A.play(cue); } catch (e) {} }
    return cue;
  },

  /* ---------------- 放大招切主题曲 ---------------- */
  /** 播放一条战斗记录时看：这是不是我方**放大招**？是的话切这台机体的主题曲。
   *  返回切过去的 cue（没切就是 null），方便测试直接断言。 */
  看记录(ev) {
    if (!ev || ev.类型 !== '攻击' || ev.单位方 !== 'ally') return null;
    const u = 界面.ctx && 界面.ctx.allies ? 界面.ctx.allies.find(x => x.slot === ev.单位位) : null;
    if (!u) return null;
    const 用 = (u.weapons || []).find(e => e.t && e.t.name === ev.武器);
    if (!用 || !isUltimate(用.t)) return null;              // 只有大招才切（普通攻击不切）
    const A = this.层();
    if (!A || !A.themeOf) return null;
    let cue = null;
    try { cue = A.themeOf(u.key, tplOf(u.key)); } catch (e) { cue = null; }
    if (!cue) return null;                                  // 这台机体 / 势力没有主题曲
    this.主题 = cue;
    this.刷曲();
    return cue;
  },
  /** 本回合结束：主题曲放回场景曲（方案 8.2「保持到本回合结束」）。 */
  回合结束() {
    if (!this.主题) return null;
    this.主题 = null;
    return this.刷曲();
  },

  /* ---------------- 音乐鉴赏页（audio/music-room.js） ---------------- */
  打开鉴赏页() {
    const A = this.层();
    if (!A || typeof A.openRoom !== 'function') { this.提示 = '音乐鉴赏页不可用（这台机器上读不到曲子）。'; return false; }
    const units = {};
    const 主题表 = (A.THEMES && A.THEMES.unit) || {};
    for (const k in 主题表) { const t = tplOf(k); units[k] = t ? t.pilot : k; }
    let r = null;
    try { r = A.openRoom({ factions: FACTIONS, units }); } catch (e) { return false; }
    if (r && r.then) r.then(() => { if (!this.开关) { try { A.stop(); } catch (e) {} } });
    return true;
  },
};

音乐.初始化();
