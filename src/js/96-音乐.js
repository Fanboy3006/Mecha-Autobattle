/* ============================================================================
 * 音乐接线（M5，方案 8.2；2026-10-11 作者拍板后扩了三条）
 * ----------------------------------------------------------------------------
 * 播放层是 `audio/local-music.js`（全局 `MechAudio`）+ `audio/music-room.js`（音乐鉴赏页），
 * 由 `tools/build-src.mjs` 内联进 HTML 的 AUDIO 块。这里只决定「什么时候放什么」，
 * 场景对应照方案 8.2 和战棋 `31d-音频接线与调试接口.js` 的规则：
 *
 *   开场菜单 = `title`（★ 2026-10-11 起有专门的标题曲「Suno 标题」）；
 *   大地图 / 编队（分队、招募、奇遇这些肉鸽外壳画面）= `mapStrategy`（「SUNO 战略」）；
 *   战斗中 = `allyPhase` / `enemyPhase`（★ 2026-10-11 作者拍板：**我方回合 / 敌方回合分开切**，
 *   判定就在这一层 —— 看战斗记录的出手方，**没动 80-界面.js / 85-播放.js / 也没动记录格式**）；
 *   Boss 战 = `boss`（肉鸽的 Boss 节点，或者练习模式里挑了 Boss 编成）—— Boss 战**一直**是这一首；
 *   **放大招**（unlock 20 / 30 的武器）时切成这台机体的**主题曲**，保持到本回合结束
 *   （下一个我方回合开始 / 被另一首主题曲替换才换，普通攻击和敌方行动都不切；战棋 31d:45-50）；
 *   结算屏 = `victory`（打赢 / 通关）或 `defeat`（打输 / 本局失败），没打完**不切曲**。
 *
 * 读不到曲子（测试环境、别人的机器上没有作者本地的版权 mp3）时：播放层自己会静音、
 * 声音按钮隐藏，这里所有调用都包了 try/catch，绝不抛异常（方案 8.2 的硬性要求）。
 * ========================================================================== */

const 声音键 = 'mecha-autobattle-sound';

/** 战斗阶段（★ 2026-10-11 作者拍板：我方回合 / 敌方回合各一首）。
 *  `阶段曲(方, 是Boss)`：Boss 战的曲子**优先**，不跟着敌我阶段来回切。
 *  `null` = 说不清是谁在出手 → 保持现在这首（不切）。 */
function 阶段曲(方, 是Boss) {
  if (是Boss) return 'boss';
  if (方 === 'ally') return 'allyPhase';
  if (方 === 'enemy') return 'enemyPhase';
  return null;
}

/** 这一场打完了吗、赢了吗（结算屏专用，**只读**）。
 *  `开屏('结算')` 只可能是打完了（`80-界面.js:642-643`）→ 看 `界面.战报.结果`；
 *  `开屏('肉鸽结算')` 有三种来路（通关 / 耐久耗尽 / 玩家放弃）→ 看 `肉鸽.RUN.结局`。
 *  读不到 / 还没打完 → `null`（= 不切曲，留在原曲上）。 */
function 这一场的结果(屏) {
  try {
    if (屏 === '肉鸽结算') {
      const 局 = (typeof 肉鸽 !== 'undefined' && 肉鸽 && 肉鸽.RUN) ? 肉鸽.RUN.结局 : null;
      if (局 === '通关') return '胜';
      if (局 === '失败') return '败';
      return null;
    }
    if (屏 === '结算') {
      const r = (typeof 界面 !== 'undefined' && 界面 && 界面.战报) ? 界面.战报.结果 : null;
      if (r === '胜') return '胜';
      if (r === '败') return '败';
      return null;
    }
  } catch (e) {}
  return null;
}

/** 场景 → 曲子。纯函数（测试直接调）：null = 不切曲，留在现在这首上。
 *  `是Boss` 只在「战斗」时有意义；`结果`（'胜' / '败' / null）只在结算两屏有意义。 */
function 场景曲(屏, 是Boss, 结果) {
  switch (屏) {
    case '菜单': return 'title';
    case '分队': case '大地图': case '招募': case '奇遇': case '编队': return 'mapStrategy';
    case '战斗': return 阶段曲('ally', 是Boss);      // 真的按出手方切在 `音乐.看记录`（下面）
    case '结算': case '肉鸽结算':
      return 结果 === '胜' ? 'victory' : 结果 === '败' ? 'defeat' : null;   // 没打完：不切曲
    default: return null;                           // 其它屏：不切曲（留在原曲上）
  }
}

const 音乐 = {
  场景: null,          // 现在在哪个屏（菜单 / 大地图 / 战斗 / 结算…）
  主题: null,          // 放大招切过来的主题曲 cue（null = 用场景曲）
  当前曲: null,        // 已经交给播放层的 cue
  是Boss战: false,
  阶段方: null,        // 战斗里现在是谁在出手：'ally' / 'enemy' / null（★ 2026-10-11 分开切曲用）
  本回合切过阶段: false,  // ★ 每回合只在第一次换方时切一次（长战斗里一回合会换好几次方，见 `切阶段`）
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
    if (屏 === '战斗') { this.主题 = null; this.阶段方 = 'ally'; this.本回合切过阶段 = false; }   // 新的一场战斗：从我方回合起
    else { this.阶段方 = null; this.本回合切过阶段 = false; }                                      // 离开战斗：阶段的账清掉
    return this.刷曲();
  },
  /** 现在该放哪首：主题曲优先，否则看场景（结算两屏要带「赢了没有」）。 */
  该放() {
    if (this.主题) return this.主题;
    if (this.场景 === '战斗' && !this.是Boss战) return 阶段曲(this.阶段方, false);
    return 场景曲(this.场景, this.是Boss战, this.这一屏的结果());
  },
  /** 结算两屏的胜负：从界面 / 肉鸽的状态现读（读不到就是 null，见 `这一场的结果`）。 */
  这一屏的结果() { return 这一场的结果(this.场景); },
  /** 把该放的曲子交给播放层（同一首不重复切）。 */
  刷曲() {
    const cue = this.该放();
    if (cue == null || cue === this.当前曲) return cue;
    this.当前曲 = cue;
    const A = this.层();
    if (A) { try { A.play(cue); } catch (e) {} }
    return cue;
  },

  /* ---------------- 敌我阶段切曲（★ 2026-10-11 作者拍板） ---------------- */
  /** 出手方变了就切曲 —— **每回合只在「第一次换方」时切一次**（作者 2026-10-11 拍板）。
   *
   *  为什么不是「出手方一变就切」：战斗结构改成「敌人数量大幅增加」之后（5 台敌人打 3 台我方），
   *  一回合里的出手顺序真的是 `我方→敌方→我方→敌方→我方` —— 那样一首曲子会被切 4 次、抖得厉害。
   *  现在这条规矩下**一回合最多切 2 次**（我方段一次 + 敌方段一次），曲子不会一阵一阵的。
   *
   *  判定只看记录里的 `单位方` 与 `类型`（`60-战斗.js:32` 的 `谁()` 给每条动作记录都盖了），
   *  **不需要动播放引擎 / 界面 / 记录格式**。
   *    - 「换方」= 这一条记录的 `单位方` 和当前阶段不同；
   *    - 本回合**已经切过**就不再切（`本回合切过阶段`，回合结束时复位）；
   *    - 我方**辅助**（修理 / 增益 / 防御…）不算「换回我方」——它在敌方段里出现时按「还在敌方段」处理；
   *    - Boss 战整场一首；放大招的主题曲优先，阶段曲顶不掉它。
   *  返回切过去的 cue（没切就是 null）。 */
  切阶段(方, 类型) {
    if (方 !== 'ally' && 方 !== 'enemy') return null;
    if (方 === this.阶段方) return null;                       // 同一个方连着动作：不切（也不占这一回合的那一次）
    if (方 === 'ally' && 类型 !== '攻击') return null;         // 敌方段里我方的辅助动作：不算换方（免得一阵一阵）
    if (this.本回合切过阶段) return null;                      // ★ 每回合只切第一次换方
    this.阶段方 = 方;
    this.本回合切过阶段 = true;
    if (this.场景 !== '战斗') return null;                     // 不在战斗屏（结算 / 大地图）：只记账，不切
    if (this.是Boss战 || this.主题) return null;               // Boss 战整场一首；主题曲优先，都不许被阶段曲顶掉
    return this.刷曲();
  },

  /* ---------------- 放大招切主题曲 ---------------- */
  /** 播放一条战斗记录时看：这是不是我方**放大招**？是的话切这台机体的主题曲。
   *  返回切过去的 cue（没切就是 null）—— 注意**阶段曲的切换不从这里返回**，要看 `音乐.当前曲`。 */
  看记录(ev) {
    /* 出手方变了就切敌我阶段曲（大招优先：切了主题曲就不再切阶段曲） */
    if (ev) this.切阶段(ev.单位方, ev.类型);
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
  /** 本回合结束：主题曲放回场景曲（方案 8.2「保持到本回合结束」）。
   *  ★ 2026-10-11 起：放回的是**这个阶段的**场景曲 —— 打完敌方回合就是 `enemyPhase`；
   *  同时把「本回合切过阶段」复位，下一回合可以再切一次（每回合最多 2 次阶段曲）。 */
  回合结束() {
    this.本回合切过阶段 = false;
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
