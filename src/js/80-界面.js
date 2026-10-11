/* ============================================================================
 * 界面（方案 8.1）：菜单 → 编队 → 战斗 → 结算
 * ----------------------------------------------------------------------------
 * M2 的范围：**编队 + 战斗画面 + 播放控制**；指令面板 / 敌人意图 / 职业特色在 M3。
 * 机体图标是 M5（复制 art/mech-icons.js），所以现在用势力配色的方块 + 短名代替。
 *
 * 三个画面：
 *   菜单   ：进场，一句话说明 + 「开始编队」
 *   编队   ：左边机师列表（按势力筛、Lv 10/20/30），右边 2×3 格子（点机师再点格子放入、
 *            点已放的格子取回），显示每台的速度和大招；下面选敌方编成
 *   战斗   ：左右各 2 排 × 3 列（中间那条缝是接触线，双方前排靠在一起）+ 右边战斗记录；
 *            顶栏：回合数、开打、暂停、二倍速、跳过动画
 *   结算   ：胜负、回合数、双方存活、种子（同一种子能重放）
 *
 * 事件都用 #screen 上的事件委托（data-act="动作:参数"），
 * 这样每个画面的按钮不用逐个接线；测试里直接调用 界面 上的同名方法。
 * ========================================================================== */

/* 势力配色：战棋里那七套（原来在 art/mech-icons.js 的 FACTION_PAL 和规则面板的图例里），
   图标在 M5 搬过来，先借用颜色把敌我 / 势力区分开。 */
const FACTION_COL = {
  影世界: '#8a6bd8', 月球王国: '#9fb7d8', 天人: '#4fc3a1', 卫星国防军: '#e88fb4',
  流星小队: '#f2c14e', ATX: '#e8e6e1', 秘银: '#7d9a58',
};
const 势力色 = 键 => {
  const t = tplOf(键);
  return (t && FACTION_COL[t.tags.势力]) || '#8a99ab';
};
const 敌方色 = '#d9564b';

const 界面 = {
  屏: '菜单',                     // 菜单 / 编队 / 战斗 / 结算
  编队: { 等级: 10, 出击: [], 选中: null, 编成序号: 0, 势力: '全部' },
  战报: null,
  种子: null,
  手动播放: false,                // 测试用：播放引擎不排计时器，自己 tick
  跳过动画总是: false,            // 「跳过动画」按下去以后，后面每场也直接跳到结尾（再按一次恢复）
  预览缓存: {},

  /* ---------------- 小工具 ---------------- */
  位名: 位 => `${位 < COLS ? '前' : '后'}${位 % COLS + 1}`,
  单位模板: (键, 方) => 方 === 'ally' ? tplOf(键) : ENEMY_T[键],
  单位名: (键, 方) => { const t = 界面.单位模板(键, 方); return t ? (方 === 'ally' ? t.pilot : t.mech) : 键; },
  单位短名: (键, 方) => { const t = 界面.单位模板(键, 方); return t ? (t.short || t.mech || 键) : 键; },

  /** 预览一台机体在某等级下的关键数字（速度、HP、大招）——编队界面要用。 */
  预览(键, 等级) {
    const k = 键 + '@' + 等级;
    if (!this.预览缓存[k]) {
      const u = makeUnit(键, 'ally', 0, 等级);
      const 大招 = u.weapons.filter(e => G_大招(e.t)).map(e => e.t.name);
      this.预览缓存[k] = {
        速度: speedOf(u), hp: u.maxHp, 大招,
        开场: 大招.length ? Math.max(...u.weapons.filter(e => G_大招(e.t)).map(e => startCdOf(e.t))) + 1 : 0,
        t: tplOf(键),
      };
    }
    return this.预览缓存[k];
  },

  /* ---------------- 屏幕切换 ---------------- */
  开屏(名) {
    this.屏 = 名;
    this.刷();
    return this;
  },

  刷() {
    const 屏 = $('#screen');
    if (屏) 屏.innerHTML = this[this.屏 + '屏'] ? this[this.屏 + '屏']() : '';
    const 顶 = $('#hud'); if (顶) 顶.innerHTML = this.顶栏();
    const 控 = $('#ctrl'); if (控) 控.innerHTML = this.控件();
    this.接线();
    return this;
  },

  接线() {
    const 屏 = $('#screen');
    if (屏 && !屏._接了) {
      屏._接了 = true;
      屏.addEventListener('click', e => {
        const el = e.target && e.target.closest ? e.target.closest('[data-act]') : null;
        if (!el || el.tagName === 'SELECT') return;
        const [动, 参] = String(el.getAttribute('data-act')).split(':');
        this.动作(动, 参);
      });
      /* 下拉框（敌方编成）走 change：值在 el.value 里，不能靠 data-act 的参数 */
      屏.addEventListener('change', e => {
        const el = e.target && e.target.closest ? e.target.closest('select[data-act]') : null;
        if (!el) return;
        this.动作(String(el.getAttribute('data-act')).split(':')[0], el.value);
      });
    }
    const 控 = $('#ctrl');
    if (控 && !控._接了) {
      控._接了 = true;
      控.addEventListener('click', e => {
        const el = e.target && e.target.closest ? e.target.closest('[data-act]') : null;
        if (!el) return;
        const [动, 参] = String(el.getAttribute('data-act')).split(':');
        this.动作(动, 参);
      });
    }
  },

  /** 界面上的所有动作都走这里（浏览器里由按钮点，测试里直接调用）。 */
  动作(动, 参) {
    switch (动) {
      case '去编队': return this.开屏('编队');
      case '回菜单': return this.开屏('菜单');
      case '选人': return this.选人(参);
      case '放位': return this.放位(Number(参));
      case '取回': return this.取回(Number(参));
      case '默认五人队': return this.默认五人队();
      case '清空': return this.清空();
      case '等级': return this.设等级(Number(参));
      case '势力': return this.设势力(参);
      case '编成': return this.设编成(Number(参));
      case '开战': return this.开战();
      case '开打': return this.开打();
      case '暂停': return this.暂停();
      case '二倍速': return this.二倍速();
      case '跳过': return this.跳过();
      case '再来一场': return this.来一场(参);
      default: return null;
    }
  },

  /* ---------------- 顶栏 ---------------- */
  顶栏() {
    if (this.屏 === '战斗' || this.屏 === '结算') {
      const b = this.战报;
      return `<div class="chip"><span class="lbl">回合</span><b>${播放.战报 ? Math.min(播放.当前 ? 播放.当前.回合 : 1, MAX_TURN) : 1}</b></div>`
        + (b ? `<div class="chip"><span class="lbl">种子</span><b>${b.种子}</b></div>` : '');
    }
    return `<div class="chip"><span class="lbl">机师</span><b>${ALLY_T.length}</b></div><div class="chip"><span class="lbl">敌人</span><b>${Object.keys(ENEMY_T).length}</b></div>`;
  },
  控件() {
    if (this.屏 === '战斗') {
      return `<button data-act="开打">开打</button>`
        + `<button data-act="暂停">${播放.暂停中 ? '继续' : '暂停'}</button>`
        + `<button data-act="二倍速"${播放.倍速 === 2 ? ' class="on"' : ''}>${播放.倍速 === 2 ? '二倍速 ✓' : '二倍速'}</button>`
        + `<button data-act="跳过"${this.跳过动画总是 ? ' class="on"' : ''}>${this.跳过动画总是 ? '跳过动画 ✓' : '跳过动画'}</button>`
        + `<button data-act="回菜单">回菜单</button>`;
    }
    if (this.屏 === '结算') return `<button data-act="再来一场">再来一场</button><button data-act="去编队">改编队</button><button data-act="回菜单">回菜单</button>`;
    if (this.屏 === '编队') return `<button data-act="回菜单">回菜单</button>`;
    return '';
  },

  /* ---------------- 菜单 ---------------- */
  菜单屏() {
    return `<section class="card menu">
      <h3>机甲指挥 · M2 战斗画面</h3>
      <p>自动战斗回合制 RPG：把机体摆进<b>前排 / 后排</b>（各 2 排 × 3 列），每回合下一批指令，这一回合按速度自动打完。</p>
      <ul>
        <li>M2 的画面：<b>编队 → 开打 → 自动打完 → 结算</b>，带播放 / 暂停 / 二倍速 / 跳过动画。</li>
        <li>指令现在只有「进攻」（方案 5.1 的 AI 自己挑目标和武器）；集火 / 守护 / 防御 / 换位、敌人意图、职业特色在 <b>M3</b>。</li>
        <li>机体图标在 <b>M5</b>，现在用势力颜色的方块 + 短名代替。</li>
      </ul>
      <div class="acts"><button class="primary" data-act="去编队">开始编队 →</button></div>
      <p class="small">想直接看一场：点「开始编队」→「默认五人队」→「开打」。</p>
    </section>`;
  },

  /* ---------------- 编队 ---------------- */
  编队屏() {
    const B = this.编队;
    const 势力们 = ['全部'].concat(FACTIONS);
    const 候选 = ALLY_T.filter(t => B.势力 === '全部' || inFaction(t, B.势力));
    const 列表 = 候选.map(t => {
      const p = this.预览(t.mech, B.等级);
      const 已上 = B.出击.some(x => x.键 === t.mech);
      return `<button class="pick${B.选中 === t.mech ? ' on' : ''}${已上 ? ' used' : ''}" data-act="选人:${t.mech}" style="--fc:${势力色(t.mech)}">
        <b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small>
        <span class="nums">速 ${p.速度} · HP ${p.hp}${p.大招.length ? ` · 大招 ${p.大招.length}` : ''}</span>
      </button>`;
    }).join('');
    const 格 = [];
    /* 前排在下面（靠近敌人那一侧），后排在上面 */
    for (const 位 of [3, 4, 5, 0, 1, 2]) {
      const 占 = B.出击.find(x => x.位 === 位);
      if (占) {
        const p = this.预览(占.键, B.等级);
        格.push(`<button class="slot filled" data-act="取回:${位}" style="--fc:${势力色(占.键)}">
          <span class="pos">${this.位名(位)}</span>
          <b>${this.单位名(占.键, 'ally')}</b><small>${占.键} · 速 ${p.速度}</small>
          <span class="nums">HP ${p.hp}</span></button>`);
      } else {
        格.push(`<button class="slot" data-act="放位:${位}"><span class="pos">${this.位名(位)}</span><b>空位</b><small>${位 < COLS ? '前排' : '后排'}</small></button>`);
      }
    }
    const 编成选项 = 编成表.map((e, i) => {
      const 名 = `第${e.层}层 ${e.类型}｜前 ${(e.前 || []).join('+') || '—'} / 后 ${(e.后 || []).join('+') || '—'}`;
      return `<option value="${i}"${i === B.编成序号 ? ' selected' : ''}>${名}</option>`;
    }).join('');
    const 选中 = B.选中 ? this.预览(B.选中, B.等级) : null;
    return `<section class="编队屏">
      <div class="col 候选">
        <h3>机师（${候选.length} 名）<span class="small">点一名 → 再点右边的格子放入</span></h3>
        <div class="filters">
          ${[10, 20, 30].map(n => `<button class="mini${B.等级 === n ? ' on' : ''}" data-act="等级:${n}">Lv${n}</button>`).join('')}
          <span class="sep"></span>
          ${势力们.map(f => `<button class="mini${B.势力 === f ? ' on' : ''}" data-act="势力:${f}">${f}</button>`).join('')}
        </div>
        <div class="picks">${列表}</div>
      </div>
      <div class="col 站位">
        <h3>出击编队（${B.出击.length} / ${SLOTS}）</h3>
        <div class="grid">${格.join('')}</div>
        <div class="acts">
          <button data-act="默认五人队">默认五人队</button>
          <button data-act="清空">清空</button>
        </div>
        <h3>敌方编成<span class="small">（方案第 10 节第 4 条：这 3 条是初稿，等作者配）</span></h3>
        <select id="编成选" data-act="编成" class="sel">${编成选项}</select>
        <div class="acts"><button class="primary" data-act="开战">开战 →</button></div>
        ${选中 ? `<p class="small">已选：${this.单位名(B.选中, 'ally')}（${B.选中}，速度 ${选中.速度}${选中.大招.length ? `，大招：${选中.大招.join('、')}，第 ${选中.开场} 回合起` : '，没有大招'}）</p>` : '<p class="small">还没选机师。</p>'}
      </div>
    </section>`;
  },

  /* ---------------- 战斗 ---------------- */
  战斗屏() {
    const b = this.战报;
    if (!b) return '<section class="card"><p>还没有战斗。回菜单重新开始。</p></section>';
    const 我方 = b.我方.slice().sort((a, c) => a.slot - c.slot);
    const 敌方 = b.敌方.slice().sort((a, c) => a.slot - c.slot);
    const 排 = (列表, 方, 从后往前) => {
      const 行 = 从后往前 ? [ROW_BACK, ROW_FRONT] : [ROW_FRONT, ROW_BACK];
      return 行.map(r => `<div class="row">${[0, 1, 2].map(c => {
        const 位 = r * COLS + c;
        const u = 列表.find(x => x.slot === 位);
        return u ? this.单位卡(u, 方) : `<div class="uc empty"><span class="pos">${this.位名(位)}</span></div>`;
      }).join('')}</div>`).join('');
    };
    return `<section class="战斗屏">
      <div class="side ally">
        <h3>我方 <span class="small">后排在上 · 前排贴住接触线</span></h3>
        ${排(我方, 'ally', true)}
      </div>
      <div class="side enemy">
        <h3>敌方 <span class="small">前排在上</span></h3>
        ${排(敌方, 'enemy', false)}
      </div>
      <aside class="logcol">
        <h3>战斗记录</h3>
        <ol id="log"></ol>
      </aside>
    </section>`;
  },

  单位卡(u, 方) {
    const 色 = 方 === 'ally' ? 势力色(u.key) : 敌方色;
    const hp = Math.round(u.hp / u.maxHp * 100);
    return `<div class="uc" id="u-${方}-${u.slot}" data-side="${方}" data-slot="${u.slot}" style="--fc:${色}">
      <span class="pos">${this.位名(u.slot)}</span>
      <div class="head"><b>${u.name}</b><small>${u.key} · 速 ${speedOf(u)}</small></div>
      <div class="bar hp"><i style="width:${hp}%"></i></div>
      <div class="nums">HP ${u.hp} / ${u.maxHp}${u.shieldHp ? ` · 盾 ${u.shieldHp}` : ''}</div>
      <div class="tags">${(u.tags && u.tags.战斗分类) || ''}${u.weapons.filter(e => G_大招(e.t)).length ? ' · 大招' : ''}</div>
    </div>`;
  },

  /* 播放每应用一条记录就刷一次这张卡：血条、已倒下、闪白、飘伤害数字。
     真实浏览器里能看到动画；Node 的 DOM 替身里这些更新是无害的（不解析）。 */
  刷卡(方, 位, 飘) {
    const el = $(`#u-${方}-${位}`);
    if (!el || !el.style) return;
    const s = 播放.单位[方 + ':' + 位];
    if (!s) return;
    const i = el.querySelector ? el.querySelector('.bar.hp i') : null;
    if (i && i.style) i.style.width = Math.max(0, Math.round(s.hp / s.maxHp * 100)) + '%';
    const n = el.querySelector ? el.querySelector('.nums') : null;
    if (n) n.textContent = `HP ${Math.max(0, s.hp)} / ${s.maxHp}${s.shieldHp ? ` · 盾 ${s.shieldHp}` : ''}`;
    el.classList && el.classList.toggle('down', s.死);
    el.classList && el.classList.add(飘 && 飘.暴击 ? 'hit crit' : 'hit');
    if (飘 && 飘.伤害) el.innerHTML += `<span class="float${飘.暴击 ? ' crit' : ''}">${飘.伤害}</span>`;
  },

  /* ---------------- 战斗流程 ---------------- */
  /** 由编队进入战斗：先一次算完整场（带种子、可复现），再交给播放引擎放出来。 */
  开战(种子) {
    const B = this.编队;
    if (!B.出击.length) return false;
    const 我方 = B.出击.slice().sort((a, b) => a.位 - b.位).map(x => ({ 键: x.键, 位: x.位, 等级: B.等级 }));
    const 条目 = 编成表[B.编成序号];
    const 敌方 = 编成到单位(条目, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
    this.种子 = 种子 != null ? 种子 : Math.floor(Date.now() % 900000) + 100000;
    this.战报 = simulate(我方, 敌方, null, this.种子);
    this.开屏('战斗');
    播放.载入(this.战报);
    播放.手动 = !!this.手动播放;
    播放.快进 = !!this.跳过动画总是;      // 「跳过动画」按过一次以后，后面每场都直接到结尾
    播放.钩子.每步 = (ev, p) => this.播一步(ev, p);
    播放.钩子.结束 = () => this.到结算();
    return this.战报;
  },

  开打() {
    if (!this.战报) return false;
    if (!播放.在放()) {   // 已经放完了就重放同一场（同种子，结果一样）
      播放.位置 = 0; this.刷();
    }
    this.刷();            // 先把我方 / 敌方的单位卡拉出来，再开始放
    播放.钩子.每步 = (ev, p) => this.播一步(ev, p);
    播放.钩子.结束 = () => this.到结算();
    播放.开始();
    this.刷顶栏();
    return true;
  },
  暂停() { 播放.暂停中 ? 播放.继续() : 播放.暂停(); this.刷控件(); return 播放.暂停中; },
  二倍速() { 播放.切倍速(); this.刷控件(); return 播放.倍速; },
  /** 跳过动画：立刻跳到本场结尾；同时记住这个偏好，后面每场都直接到结尾。再按一次取消。 */
  设跳过动画(开) {
    this.跳过动画总是 = !!开;
    if (this.跳过动画总是) { 播放.快进 = true; 播放.跳到结尾(); }
    this.刷控件();
    return this.跳过动画总是;
  },
  跳过() { return this.设跳过动画(!this.跳过动画总是); },

  刷顶栏() { const t = $('#hud'); if (t) t.innerHTML = this.顶栏(); },
  刷控件() { const t = $('#ctrl'); if (t) t.innerHTML = this.控件(); this.接线(); },

  /** 播放一条记录：攻击者向前冲一下、受击方闪白 + 飘伤害数字，再往战斗记录里追一行。 */
  播一步(ev, p) {
    if (ev && ev.目标方 != null) this.刷卡(ev.目标方, ev.目标位, { 伤害: ev.伤害, 暴击: ev.暴击 > 0 });
    /* 攻击者向前冲一下（方案 8.1）：先把上一张的冲劲清掉，再给这一张加上 */
    const 攻击者 = ev && ev.单位方 != null ? $(`#u-${ev.单位方}-${ev.单位位}`) : null;
    if (攻击者 && 攻击者.classList) {
      const 屏 = $('#screen');
      const 旧的 = 屏 && 屏.querySelectorAll ? 屏.querySelectorAll('.uc.act') : [];
      for (const el of 旧的) el.classList && el.classList.remove('act');
      攻击者.classList.add('act');
    }
    const 日志 = $('#log');
    if (日志) {
      const 行 = ev ? `<li class="${ev.类型 === '攻击' || ev.类型 === '残月余响' ? (ev.单位方 || '') : ev.类型 === '回合' ? 'sys' : ''}"><span class="t">${ev.回合}</span>${ev.文本}</li>`
        : '<li class="sys">（播放结束）</li>';
      日志.innerHTML += 行;
      if (日志.scrollTop != null) 日志.scrollTop = 99999;
    }
    if (p) this.刷顶栏();
  },

  到结算() { this.开屏('结算'); },

  /* ---------------- 结算 ---------------- */
  结算屏() {
    const b = this.战报;
    if (!b) return '<section class="card"><p>这场还没打完。</p></section>';
    const 胜 = b.结果 === '胜';
    const 活 = b.我方.filter(u => u.hp > 0).length, 敌活 = b.敌方.filter(u => u.hp > 0).length;
    return `<section class="card end ${胜 ? 'win' : 'lose'}">
      <div class="eyebrow">${胜 ? '战斗胜利' : '战斗失败'}</div>
      <h2>${b.结果} · ${b.原因}</h2>
      <ul>
        <li>回合数：<b>${b.回合数}</b></li>
        <li>我方存活：<b>${活} / ${b.我方.length}</b>　敌方存活：<b>${敌活} / ${b.敌方.length}</b></li>
        <li>战斗记录：<b>${b.记录.length}</b> 条</li>
        <li>种子：<b>${b.种子}</b>（同种子同编队重放，结果完全一样）</li>
      </ul>
      <div class="acts">
        <button class="primary" data-act="再来一场">再来一场（换种子）</button>
        <button data-act="再来一场:${b.种子}">重放这一场（同种子）</button>
        <button data-act="去编队">改编队</button>
        <button data-act="回菜单">回菜单</button>
      </div>
    </section>`;
  },
  来一场(同种子) { const s = 同种子 ? Number(同种子) : null; this.开战(s); this.开打(); return this.战报; },

  /* ---------------- 编队动作 ---------------- */
  选人(键) { this.编队.选中 = this.编队.选中 === 键 ? null : 键; this.刷(); return this.编队.选中; },
  放位(位) {
    const B = this.编队;
    if (!B.选中) return false;
    if (B.出击.some(x => x.键 === B.选中)) return false;      // 同一台不重复上
    const 旧 = B.出击.find(x => x.位 === 位);
    if (旧) B.出击 = B.出击.filter(x => x.位 !== 位);
    if (B.出击.length >= SLOTS) return false;
    B.出击.push({ 键: B.选中, 位 });
    this.刷();
    return true;
  },
  取回(位) { this.编队.出击 = this.编队.出击.filter(x => x.位 !== 位); this.刷(); return true; },
  清空() { this.编队.出击 = []; this.刷(); return true; },
  设等级(n) { this.编队.等级 = n; this.预览缓存 = {}; 播放.战报 = 播放.战报; this.刷(); return n; },
  设势力(f) { this.编队.势力 = f; this.刷(); return f; },
  设编成(i) { this.编队.编成序号 = Math.max(0, Math.min(编成表.length - 1, i || 0)); this.刷(); return this.编队.编成序号; },
  默认五人队() {
    this.编队.出击 = 默认五人队.map(x => ({ 键: x.键, 位: x.位 }));
    this.刷();
    return this.编队.出击;
  },
};

/* 界面里用到的两个小判断（写在最后，避免和引擎里的名字撞车） */
function G_大招(w) { return isUltimate(w) && !!rangeKindOf(w); }
