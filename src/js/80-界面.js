/* ============================================================================
 * 界面（方案 8.1）：菜单 → 编队 → 战斗 → 结算
 * ----------------------------------------------------------------------------
 * M2：编队 + 战斗画面 + 播放控制。
 * M3：**指令阶段**（每台机体下指令、大招开关、看敌人意图）+ 一回合一个回合地打。
 *
 * 战斗屏的阶段：
 *   指令阶段：点我方卡片 → 在右边指令面板上下指令（进攻 / 集火 / 守护 / 防御 / 换位 + 大招开关）；
 *             敌人卡片上显示**意图**（它这一回合打算打谁、用什么、预计多少伤害，方案 5.3）。
 *   播放阶段：点「开打」跑这一回合，逐条放出来（攻击者冲一下、受击闪白、飘字）。
 *   回合播完：没分出胜负就回到指令阶段（指令会留着，方案 3.2）；分出胜负就去结算。
 *
 * 机体图标是 M5，现在用势力配色的方块 + 短名。
 * 事件都用 #screen / #ctrl 上的事件委托（data-act="动作:参数"），每个动作也都能被测试直接调用。
 * ========================================================================== */

/* 势力配色：战棋里那七套（原来在 art/mech-icons.js 的 FACTION_PAL 和规则面板的图例里） */
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
  阶段: '指令',                   // 战斗屏的阶段：指令 / 播放 / 结算
  编队: { 等级: 10, 出击: [], 选中: null, 编成序号: 0, 势力: '全部' },
  ctx: null,                      // 这一场战斗的引擎状态（开局() 给的）
  指令: {},                       // 位 → {类型, 目标位, 保留大招}（下过就一直留着）
  选中位: null,
  选目标: null,                   // '集火' / '守护'：正在等玩家点目标
  提示: '',
  显示单位: null,                 // 播放阶段用的「这一回合开始时」的快照
  战报: null,                     // 结算用的小结
  肉鸽战斗: null,                 // 正在打的这一场是哪个肉鸽节点（打完回调 肉鸽.战斗结束）
  种子: null,
  手动播放: false,                // 测试用：播放引擎不排计时器，自己 tick
  跳过动画总是: false,
  预览缓存: {},

  /* ---------------- 小工具 ---------------- */
  位名,
  单位模板: (键, 方) => 方 === 'ally' ? tplOf(键) : ENEMY_T[键],
  单位名: (键, 方) => { const t = 界面.单位模板(键, 方); return t ? (方 === 'ally' ? t.pilot : t.mech) : 键; },
  单位短名: (键, 方) => { const t = 界面.单位模板(键, 方); return t ? (t.short || t.mech || 键) : 键; },

  /** 预览一台机体在某等级下的关键数字（速度、HP、大招）——编队界面要用。 */
  预览(键, 等级) {
    const k = 键 + '@' + 等级;
    if (!this.预览缓存[k]) {
      const u = makeUnit(键, 'ally', 0, 等级);
      const 大招 = u.weapons.filter(e => isUltimate(e.t) && rangeKindOf(e.t)).map(e => e.t.name);
      this.预览缓存[k] = {
        速度: speedOf(u), hp: u.maxHp, 大招,
        开场: 大招.length ? Math.max(...u.weapons.filter(e => isUltimate(e.t)).map(e => startCdOf(e.t))) + 1 : 0,
        t: tplOf(键),
      };
    }
    return this.预览缓存[k];
  },

  /* ---------------- 屏幕切换 ---------------- */
  开屏(名) { this.屏 = 名; this.刷(); 音乐.场景切换(名); return this; },   // M5：切屏跟着换曲子（方案 8.2）

  刷() {
    const 屏 = $('#screen');
    if (屏) 屏.innerHTML = this[this.屏 + '屏'] ? this[this.屏 + '屏']() : '';
    this.刷顶栏(); this.刷控件();
    this.接线();
    return this;
  },
  刷顶栏() { const t = $('#hud'); if (t) t.innerHTML = this.顶栏(); },
  刷控件() { const t = $('#ctrl'); if (t) t.innerHTML = this.控件(); this.接线(); },

  接线() {
    const 挂 = (el, 事件, 选择器) => {
      if (!el || el['_接了' + 事件]) return;
      el['_接了' + 事件] = true;
      el.addEventListener(事件, e => {
        const t = e.target && e.target.closest ? e.target.closest(选择器) : null;
        if (!t) return;
        const [动, 参] = String(t.getAttribute('data-act')).split(':');
        this.动作(动, t.tagName === 'SELECT' ? t.value : 参);
      });
    };
    挂($('#screen'), 'click', '[data-act]');
    挂($('#screen'), 'change', 'select[data-act]');
    挂($('#ctrl'), 'click', '[data-act]');

    /* 拖动（作者 2026-10-10）：用 pointer 事件，鼠标和手指都能拖（HTML5 的 drag 在手机上不行）。
       编队界面用；M4 的招募 / 编队界面直接复用这一套。 */
    const 屏 = $('#screen');
    if (屏 && !屏._接了拖) {
      屏._接了拖 = true;
      屏.addEventListener('pointerdown', e => {
        const el = e.target && e.target.closest ? e.target.closest('[data-drag]') : null;
        if (!el) return;
        const [类型, 值] = String(el.getAttribute('data-drag')).split(':');
        this.拖动开始(类型, 值, e);
        if (e.preventDefault) e.preventDefault();
      });
      屏.addEventListener('pointermove', e => { if (this.拖动) this.拖动到(e.clientX, e.clientY); });
      屏.addEventListener('pointerup', e => {
        if (!this.拖动) return;
        const el = e.target && e.target.closest ? e.target.closest('[data-drop]') : null;
        this.拖动放下(el ? el.getAttribute('data-drop') : null);
      });
    }
  },

  /* ---------------- 拖动：候选 ⇄ 格子，格子 ⇄ 格子 ---------------- */
  拖动: null,                     // {类型:'候选'|'位', 值, 幽灵}
  拖动开始(类型, 值, 事件) {
    this.拖动 = { 类型, 值 };
    if (事件 && typeof document !== 'undefined' && document.createElement) {
      const 幽灵 = document.createElement('div');
      幽灵.className = 'dragghost';
      const 键 = 类型 === '候选' ? 值 : ((this.编队.出击.find(x => x.位 === Number(值)) || {}).键);
      幽灵.textContent = this.单位名(键, 'ally') || '拖动中';
      if (document.body && document.body.appendChild) document.body.appendChild(幽灵);
      this.拖动.幽灵 = 幽灵;
      this.拖动到(事件.clientX, 事件.clientY);
    }
    return this.拖动;
  },
  拖动到(x, y) {
    const g = this.拖动 && this.拖动.幽灵;
    if (g && g.style) { g.style.left = ((x || 0) + 10) + 'px'; g.style.top = ((y || 0) + 10) + 'px'; }
    return this.拖动;
  },
  /** 松手：落在格子上就放进去 / 挪过去；落在候选区（或空白处）就是取回 */
  拖动放下(位) {
    const d = this.拖动;
    if (!d) return false;
    this.拖动 = null;
    if (d.幽灵 && d.幽灵.remove) d.幽灵.remove();
    if (位 == null || 位 === '候选' || 位 === '') return d.类型 === '位' ? this.取回(Number(d.值)) : false;
    const 位号 = Number(位);
    if (d.类型 === '候选') return this.拖入(d.值, 位号);
    return this.挪位(Number(d.值), 位号);
  },
  /** 把一名机师拖进某个格子：格子里原来的人被挤回候选列表 */
  拖入(键, 位) {
    const B = this.编队;
    if (位 < 0 || 位 >= SLOTS) return false;
    if (B.出击.some(x => x.键 === 键)) this.挪位(B.出击.find(x => x.键 === 键).位, 位);
    else {
      if (B.出击.some(x => x.位 === 位)) B.出击 = B.出击.filter(x => x.位 !== 位);
      if (B.出击.length >= SLOTS) { this.提示 = `出击位置已经满了（${SLOTS} 格）。`; this.刷(); return false; }
      B.出击.push({ 键, 位 });
      this.刷();
    }
    this.提示 = '';
    return true;
  },
  /** 格子 → 格子：目标有人就互换，空着就移过去 */
  挪位(从位, 到位) {
    const B = this.编队;
    if (从位 === 到位) return false;
    const 甲 = B.出击.find(x => x.位 === 从位);
    if (!甲) return false;
    const 乙 = B.出击.find(x => x.位 === 到位);
    if (乙) 乙.位 = 从位;
    甲.位 = 到位;
    this.提示 = '';
    this.刷();
    return true;
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
      case '开战': return this.肉鸽编队模式 ? this.从编队开战肉鸽() : this.开战();
      case '备战': return this.准备肉鸽编队();
      case '开打': return this.开打();
      case '暂停': return this.暂停();
      case '二倍速': return this.二倍速();
      case '跳过': return this.跳过();
      case '再来一场': return this.来一场(参);
      /* M3 的指令阶段 */
      case '选单位': return this.选单位(Number(参));
      case '指令': return this.下指令(参);
      case '点敌人': return this.点敌人(Number(参));
      case '点队友': return this.点队友(Number(参));
      case '大招': return this.切大招(Number(参));
      /* M4 肉鸽 */
      case '去分队': return this.开屏('分队');
      case '选分队': return this.选分队(参);
      case '开新局': return this.开新局();
      case '继续上一局': return this.继续上一局();
      case '回大地图': return this.开屏('大地图');
      case '备战': return this.准备肉鸽编队();
      case '去节点': return this.去节点(参);
      case '打这一场': return this.打这一场();
      case '去招募': return this.开屏('招募');
      case '招募': return this.招募(参);
      case '补给': return this.领补给();
      case '去奇遇': return this.开屏('奇遇');
      case '奇遇': return this.选奇遇(参);
      case '存个档': return this.存个档();
      case '放弃本局': return this.放弃本局();
      /* M5 美术和音乐 */
      case '音乐鉴赏': return this.去音乐鉴赏();
      case '声音': return 音乐.切开关();
      default: return null;
    }
  },

  /* ---------------- 顶栏 ---------------- */
  顶栏() {
    if (this.屏 === '战斗' || this.屏 === '结算') {
      const 回合 = this.ctx ? this.ctx.turn : 1;
      return `<div class="chip"><span class="lbl">回合</span><b>${回合}${this.ctx && this.ctx.turn > MAX_TURN ? '' : ''} / ${MAX_TURN}</b></div>`
        + `<div class="chip"><span class="lbl">阶段</span><b>${this.屏 === '结算' ? '结算' : this.阶段}</b></div>`
        + (this.ctx ? `<div class="chip"><span class="lbl">种子</span><b>${this.ctx.种子}</b></div>` : '');
    }
    return `<div class="chip"><span class="lbl">机师</span><b>${ALLY_T.length}</b></div><div class="chip"><span class="lbl">敌人</span><b>${Object.keys(ENEMY_T).length}</b></div>`;
  },
  控件() {
    if (this.屏 === '战斗') {
      const 播放中 = this.阶段 === '播放';
      return `<button data-act="开打" class="primary"${播放中 ? ' disabled' : ''}>${播放中 ? '播放中…' : '开打 ▶'}</button>`
        + `<button data-act="暂停"${播放中 ? '' : ' disabled'}>${播放.暂停中 ? '继续' : '暂停'}</button>`
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
    const 有存档 = !!肉鸽.读存档();
    return `<section class="card menu">
      <h3>机甲指挥 · M5 美术和音乐</h3>
      <p>自动战斗回合制 RPG：把机体摆进<b>前排 / 后排</b>（前 3 后 2），每回合给每台机体下一条<b>大方向指令</b>，这一回合按速度自动打完。</p>
      <ul>
        <li><b>肉鸽</b>（方案第 7 节）：选分队 → 大地图走节点（作战 / 精英 / Boss / 招募 / 补给 / 奇遇）→ 层出口；
          希望 / 源碳结晶 / 作战耐久，<b>关掉页面能继续</b>（存档）。</li>
        <li><b>战斗</b>：指令阶段（进攻 / 集火 / 守护 / 防御 / 换位 + 大招开关）→ 看敌人意图 →「开打 ▶」自动打完。</li>
        <li><b>练习</b>：不进肉鸽，直接用编队界面挑一队打一场（试数值用）。</li>
      </ul>
      <div class="acts">
        <button class="primary" data-act="去分队">新的一局（肉鸽）→</button>
        ${有存档 ? `<button data-act="继续上一局">继续上一局（第 ${肉鸽.读存档().层} 层）</button>` : ''}
        <button data-act="去编队">练习：直接编队打一场</button>
        <button data-act="音乐鉴赏">音乐鉴赏</button>
      </div>
      <p class="small">M5 美术和音乐：机体图标是原创矢量素材（<code>art/mech-icons.js</code>）；
        音乐按场景切（菜单 = 主题曲、大地图 / 编队 = 战略、战斗中 = 我方回合、Boss 战 = Boss 曲），
        <b>放大招</b>时切成那台机体的主题曲、保持到本回合结束。右上角是声音开关（按 <b>M</b> 也行）；
        读不到曲子时自动静音、按钮隐藏。</p>
    </section>`;
  },

  /* ---------------- 编队 ---------------- */
  编队屏() {
    const B = this.编队;
    /* 肉鸽里进战斗前会先走这一步：候选项是**名册**（RUN.队伍），不是全部 34 名 */
    const 肉鸽模式 = !!this.肉鸽编队模式 && !!肉鸽.RUN;
    const 势力们 = ['全部'].concat(FACTIONS);
    const 候选 = 肉鸽模式
      ? 肉鸽.RUN.队伍.map(m => Object.assign({}, tplOf(m.键), { 等级: m.等级 }))
      : ALLY_T.filter(t => B.势力 === '全部' || inFaction(t, B.势力));
    const 列表 = 候选.filter(t => t && t.mech).map(t => {
      const p = this.预览(t.mech, t.等级 || B.等级);
      const 已上 = B.出击.some(x => x.键 === t.mech);
      return `<button class="pick${B.选中 === t.mech ? ' on' : ''}${已上 ? ' used' : ''}" data-act="选人:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}">
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}${肉鸽模式 ? ` · Lv${t.等级}` : ''}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}${p.大招.length ? ` · 大招 ${p.大招.length}` : ''}</span>
      </button>`;
    }).join('');
    const 格 = [];
    /* 前排在下面（靠近敌人那一侧），后排在上面；每一排一行，列数从阵型配置取 */
    const 格序 = [];
    for (let r = ROWS - 1; r >= 0; r--) for (let c = 0; c < 行列数(r); c++) 格序.push(slotOf(r, c));
    const 行格 = new Map();
    for (const 位 of 格序) {
      const r = rowOfSlot(位);
      if (!行格.has(r)) 行格.set(r, []);
      const 占 = B.出击.find(x => x.位 === 位);
      if (占) {
        const p = this.预览(占.键, B.等级);
        行格.get(r).push(`<button class="slot filled" data-act="取回:${位}" data-drag="位:${位}" data-drop="${位}" style="--fc:${势力色(占.键)}">
          <span class="pos">${位名(位)}</span>
          <span class="pk-top">${图标.卡(占.键, 'ally', 图标.尺寸.格)}<span class="pk-nm"><b>${this.单位名(占.键, 'ally')}</b><small>${占.键} · 速 ${p.速度}</small></span></span>
          <span class="nums">HP ${p.hp}</span></button>`);
      } else {
        行格.get(r).push(`<button class="slot" data-act="放位:${位}" data-drop="${位}"><span class="pos">${位名(位)}</span><b>空位</b><small>${行名(r)}</small></button>`);
      }
    }
    for (const [r, 列表] of 行格) 格.push(`<div class="row" style="--cols:${最大列数}">${列表.join('')}</div>`);
    const 编成选项 = 编成表.map((e, i) => {
      const 名 = `第${e.层}层 ${e.类型}｜前 ${(e.前 || []).join('+') || '—'} / 后 ${(e.后 || []).join('+') || '—'}`;
      return `<option value="${i}"${i === B.编成序号 ? ' selected' : ''}>${名}</option>`;
    }).join('');
    const 选中 = B.选中 ? this.预览(B.选中, B.等级) : null;
    const 当前节点 = 肉鸽模式 ? 肉鸽.当前节点() : null;
    return `<section class="编队屏">
      <div class="col 候选" data-drop="候选">
        <h3>${肉鸽模式 ? `名册（${候选.length} 台）` : `机师（${候选.length} 名）`}<span class="small">拖到右边格子里，或者点一名再点格子；格子之间也能拖（互换）</span></h3>
        ${肉鸽模式 ? '' : `<div class="filters">
          ${[10, 20, 30].map(n => `<button class="mini${B.等级 === n ? ' on' : ''}" data-act="等级:${n}">Lv${n}</button>`).join('')}
          <span class="sep"></span>
          ${势力们.map(f => `<button class="mini${B.势力 === f ? ' on' : ''}" data-act="势力:${f}">${f}</button>`).join('')}
        </div>`}
        <div class="picks">${列表}</div>
      </div>
      <div class="col 站位">
        <h3>出击编队（${B.出击.length} / ${SLOTS}）<span class="small">上排 = 后排 2 格，下排 = 前排 3 格</span></h3>
        <div class="grid">${格.join('')}</div>
        <div class="acts">
          <button data-act="默认五人队">${肉鸽模式 ? '把名册前 5 台摆上' : '默认五人队'}</button>
          <button data-act="清空">清空</button>
        </div>
        ${肉鸽模式 ? `<p class="small">这一场：第 ${肉鸽.RUN.层} 层 <b>${节点类型表[当前节点 && 当前节点.类型] ? 节点类型表[当前节点.类型].名 : '作战'}</b>（敌人由编成表随机抽；敌人等级按层数走）</p>
          <div class="acts"><button class="primary" data-act="开战">开战 →</button><button data-act="回大地图">回大地图</button></div>`
        : `<h3>敌方编成<span class="small">（方案第 10 节第 4 条：这 3 条是初稿，等作者配）</span></h3>
          <select id="编成选" data-act="编成" class="sel">${编成选项}</select>
          <div class="acts"><button class="primary" data-act="开战">开战 →</button></div>`}
        ${选中 ? `<p class="small">已选：${this.单位名(B.选中, 'ally')}（${B.选中}，速度 ${选中.速度}${选中.大招.length ? `，大招：${选中.大招.join('、')}，第 ${选中.开场} 回合起` : '，没有大招'}）</p>` : '<p class="small">还没选机师。</p>'}
      </div>
    </section>`;
  },

  /* ---------------- 战斗 ---------------- */
  战斗屏() {
    if (!this.ctx) return '<section class="card"><p>还没有战斗。回菜单重新开始。</p></section>';
    const 指令阶段 = this.阶段 === '指令';
    const 我方单位 = 指令阶段 ? this.ctx.allies : (this.显示单位 ? this.显示单位.我方 : this.ctx.allies);
    const 敌方单位 = 指令阶段 ? this.ctx.enemies : (this.显示单位 ? this.显示单位.敌方 : this.ctx.enemies);
    const 意图 = 指令阶段 ? 算意图(this.ctx) : [];
    const 排 = (列表, 方, 从后往前) => {
      const 行序 = 从后往前 ? [ROW_BACK, ROW_FRONT] : [ROW_FRONT, ROW_BACK];
      return 行序.map(r => `<div class="row" style="--cols:${行列数(r)}">${Array.from({ length: 行列数(r) }, (_, c) => {
        const 位 = slotOf(r, c);
        const u = 列表.find(x => x.slot === 位);
        return u ? this.单位卡(u, 方, 意图.find(i => i.单位位 === 位), 指令阶段) : `<div class="uc empty"><span class="pos">${位名(位)}</span></div>`;
      }).join('')}</div>`).join('');
    };
    return `<section class="战斗屏">
      <div class="side ally">
        <h3>我方 <span class="small">${指令阶段 ? '点一张卡片下指令' : '后排在上 · 前排贴住接触线'}</span></h3>
        ${排(我方单位, 'ally', true)}
      </div>
      <div class="side enemy">
        <h3>敌方 <span class="small">${指令阶段 ? '卡上的箭头 = 它这一回合的意图' : '前排在上'}</span></h3>
        ${排(敌方单位, 'enemy', false)}
      </div>
      <aside class="logcol">
        ${指令阶段 ? this.指令面板() : ''}
        <h3>战斗记录</h3>
        <ol id="log"></ol>
      </aside>
    </section>`;
  },

  /** 指令面板（方案第 4 节）：选中的我方机体能下的指令 + 大招开关 */
  指令面板() {
    const 位 = this.选中位;
    if (位 == null) return `<div class="cmdpanel"><h3>指令</h3><p class="small">先点一张我方卡片。指令会一直留着，不想改就直接「开打 ▶」。</p>${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}</div>`;
    const u = this.ctx.allies.find(x => x.slot === 位);
    if (!u) return '';
    const c = this.当前指令(位);
    const 目标 = c.目标位 != null ? (c.类型 === '集火' ? this.ctx.enemies : this.ctx.allies).find(x => x.slot === c.目标位) : null;
    const 按钮 = [['进攻', '进攻'], ['集火', '集火 ▶ 敌人'], ['守护', '守护 ▶ 队友'], ['防御', '防御'], ['换位', '换位']]
      .map(([k, 名]) => `<button class="mini${c.类型 === k ? ' on' : ''}" data-act="指令:${k}">${名}</button>`).join('');
    return `<div class="cmdpanel">
      <h3>指令 · ${u.name}<span class="small">${u.key} · ${u.tags.战斗分类} · ${位名(位)}</span></h3>
      <div class="cmds">${按钮}<button class="mini${c.保留大招 ? ' on' : ''}" data-act="大招:${位}">大招：${c.保留大招 ? '保留' : '自动'}</button></div>
      <p class="small">当前：<b>${c.类型}</b>${目标 ? ` → ${目标.name}（${位名(目标.slot)}）` : ''}${c.类型 === '集火' && !目标 ? '（还没点目标）' : ''}${c.类型 === '守护' && !目标 ? '（还没点队友）' : ''}</p>
      ${this.选目标 ? `<p class="warn small">正在选目标：点一个${this.选目标 === '集火' ? '敌方' : '我方'}单位。</p>` : ''}
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </div>`;
  },

  单位卡(u, 方, 意图, 可点) {
    const 色 = 方 === 'ally' ? 势力色(u.key) : 敌方色;
    const hp = Math.max(0, Math.round(u.hp / u.maxHp * 100));
    const 动 = 可点 ? (方 === 'ally' ? ` data-act="选单位:${u.slot}"` : ` data-act="点敌人:${u.slot}"`) : '';
    const c = 方 === 'ally' ? this.当前指令(u.slot) : null;
    const 指令行 = c ? `${c.类型}${c.目标位 != null ? '→' + 位名(c.目标位) : ''}${c.保留大招 ? ' · 大招保留' : ''}` : '';
    /* 站桩 Boss（61-Boss.js）：大技能那一下前面标 ★，蓄力时直接写「蓄力中」——
       玩家在指令阶段就能看见 Boss 的节奏（方案 5.3 的意图显示） */
    const 意图行 = 意图 && 意图.武器
      ? `${意图.大技能 ? '★大技能 ' : ''}→ ${意图.目标名}(${位名(意图.目标位)}) · ${意图.武器} · 约 ${意图.期望}`
      : (意图 ? (意图.蓄力 ? '蓄力中（这一回合不出手）' : '不行动') : '');
    const 选中 = 方 === 'ally' && this.选中位 === u.slot ? ' sel' : '';
    return `<div class="uc${u.hp <= 0 ? ' down' : ''}${选中}" id="u-${方}-${u.slot}" data-side="${方}" data-slot="${u.slot}" style="--fc:${色}"${动}>
      <span class="pos">${位名(u.slot)}</span>
      <div class="head">${图标.卡(u.key, 方, 图标.尺寸.卡)}<div class="nm"><b>${u.name}</b><small>${u.key} · 速 ${speedOf(u)}</small></div></div>
      <div class="bar hp"><i style="width:${hp}%"></i></div>
      <div class="nums">HP ${Math.max(0, u.hp)} / ${u.maxHp}${u.shieldHp ? ` · 盾 ${u.shieldHp}` : ''}</div>
      <div class="tags">${(u.tags && u.tags.战斗分类) || ''}${u.weapons && u.weapons.filter(e => isUltimate(e.t)).length ? ' · 大招' : ''}</div>
      ${方 === 'ally' && 指令行 ? `<div class="cmd">${指令行}</div>` : ''}
      ${方 === 'enemy' && 意图行 ? `<div class="intent">${意图行}</div>` : ''}
    </div>`;
  },

  /** 播放每应用一条记录就刷一次这张卡：血条、闪白、飘伤害数字、当前行动的人加一圈光。 */
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
    if (飘) {
      el.classList && el.classList.add(飘.暴击 ? 'hit crit' : 'hit');
      if (飘.伤害) el.innerHTML += `<span class="float${飘.暴击 ? ' crit' : ''}">${飘.伤害}</span>`;
    }
  },

  /* ---------------- 战斗流程 ---------------- */
  /** 由编队进入战斗：建立引擎状态（不再一次算完整场——玩家的指令每回合都可能改）。 */
  开战(种子) {
    const B = this.编队;
    if (!B.出击.length) return false;
    const 我方 = B.出击.slice().sort((a, b) => a.位 - b.位).map(x => ({ 键: x.键, 位: x.位, 等级: B.等级 }));
    const 条目 = 编成表[B.编成序号];
    const 敌方 = 编成到单位(条目, 0).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
    this.种子 = 种子 != null ? Number(种子) : Math.floor(Date.now() % 900000) + 100000;
    this.ctx = 开局(我方, 敌方, this.种子);
    this.指令 = {};
    this.选中位 = null;
    this.选目标 = null;
    this.提示 = '';
    this.显示单位 = null;
    this.战报 = null;
    this.阶段 = '指令';
    this.开屏('战斗');
    return this.ctx;
  },

  /** 「开打」：把这一回合的指令交给引擎 → 打一回合 → 把这一回合的记录交给播放引擎放出来。 */
  开打() {
    if (!this.ctx || this.阶段 !== '指令') return false;
    /* 记下这一回合**开始时**的状态：播放时血条从这里开始走 */
    const 快照 = 列表 => 列表.map(u => ({
      side: u.side, slot: u.slot, key: u.key, name: u.name, maxHp: u.maxHp, hp: u.hp,
      shieldHp: u.shieldHp, tags: u.tags, weapons: u.weapons,
    }));
    this.显示单位 = { 我方: 快照(this.ctx.allies), 敌方: 快照(this.ctx.enemies) };
    设指令(this.ctx, this.指令);
    const 记录 = 打一回合(this.ctx);
    播放.载入({ 记录, 我方: this.显示单位.我方, 敌方: this.显示单位.敌方 });
    播放.手动 = !!this.手动播放;
    播放.快进 = !!this.跳过动画总是;
    this.阶段 = '播放';
    this.刷();
    播放.钩子.每步 = (ev, p) => this.播一步(ev, p);
    播放.钩子.结束 = () => this.回合播完();
    播放.开始();
    this.刷控件(); this.刷顶栏();
    return true;
  },

  /** 这一回合播放完了：分出胜负就去结算，否则回到指令阶段（指令留着）。 */
  回合播完() {
    音乐.回合结束();                 // M5：主题曲只保持到本回合结束（方案 8.2）
    if (this.ctx.result) return this.到结算();
    this.阶段 = '指令';
    this.选中位 = null;
    this.选目标 = null;
    this.提示 = '';
    this.刷();
    return true;
  },

  暂停() { 播放.暂停中 ? 播放.继续() : 播放.暂停(); this.刷控件(); return 播放.暂停中; },
  二倍速() { 播放.切倍速(); this.刷控件(); return 播放.倍速; },
  /** 跳过动画：立刻跳到本回合结尾；记住这个偏好，后面每回合直接到结尾。再按一次取消。 */
  设跳过动画(开) {
    this.跳过动画总是 = !!开;
    if (this.跳过动画总是 && this.阶段 === '播放') { 播放.快进 = true; 播放.跳到结尾(); }
    this.刷控件();
    return this.跳过动画总是;
  },
  跳过() { return this.设跳过动画(!this.跳过动画总是); },

  /** 播放一条记录：攻击者冲一下（并加一圈光）、受击方闪白 + 飘伤害数字，再追一行战斗记录。 */
  播一步(ev, p) {
    音乐.看记录(ev);                 // M5：我方放大招就切这台机体的主题曲（保持到本回合结束）
    if (ev && ev.目标方 != null) this.刷卡(ev.目标方, ev.目标位, { 伤害: ev.伤害, 暴击: ev.暴击 > 0 });
    const 屏 = $('#screen');
    const 旧的 = 屏 && 屏.querySelectorAll ? 屏.querySelectorAll('.uc.act') : [];
    for (const el of 旧的) el.classList && el.classList.remove('act');
    if (ev && ev.单位方 != null) {
      const 攻击者 = $(`#u-${ev.单位方}-${ev.单位位}`);
      if (攻击者 && 攻击者.classList) 攻击者.classList.add('act');
    }
    const 日志 = $('#log');
    if (日志) {
      const 类 = ev ? (ev.类型 === '攻击' || ev.类型 === '残月余响' ? (ev.单位方 || '') : ev.类型 === '回合' ? 'sys' : 'sys2') : 'sys';
      日志.innerHTML += ev ? `<li class="${类}"><span class="t">${ev.回合}</span>${ev.文本}</li>` : '<li class="sys">（本回合播放结束）</li>';
      if (日志.scrollTop != null) 日志.scrollTop = 99999;
    }
    if (p) this.刷顶栏();
  },

  到结算() {
    const c = this.ctx;
    this.战报 = {
      结果: c.result ? c.result.结果 : '败', 原因: c.result ? c.result.原因 : '—',
      回合数: c.turn, 记录: c.log, 我方: c.allies, 敌方: c.enemies, 种子: c.种子,
    };
    /* 肉鸽里的战斗：把结果交回肉鸽（发奖励 / 扣作战耐久），然后回大地图 */
    if (this.肉鸽战斗) {
      const 这次 = this.肉鸽战斗;
      this.肉鸽战斗 = null;
      const r = 肉鸽.战斗结束(this.战报.结果, 这次.类型, this.战报);
      this.阶段 = '结算';
      this.开屏(r && r.结束 ? '肉鸽结算' : '大地图');
      return;
    }
    this.阶段 = '结算';
    this.开屏('结算');
  },

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
        <li>种子：<b>${b.种子}</b>（同种子同编队同指令重放，结果完全一样）</li>
      </ul>
      <div class="acts">
        <button class="primary" data-act="再来一场">再来一场（换种子）</button>
        <button data-act="再来一场:${b.种子}">重放这一场（同种子）</button>
        <button data-act="去编队">改编队</button>
        <button data-act="回菜单">回菜单</button>
      </div>
    </section>`;
  },
  来一场(同种子) {
    const s = 同种子 ? Number(同种子) : null;
    this.开战(s);
    return this.ctx;
  },

  /* ---------------- 指令阶段的动作（方案第 4 节） ---------------- */
  当前指令(位) { return Object.assign({ 类型: '进攻', 目标位: null, 保留大招: false }, this.指令[位] || {}); },
  设某指令(位, 补丁) { this.指令[位] = Object.assign(this.当前指令(位), 补丁); this.提示 = ''; this.刷(); return this.指令[位]; },
  选单位(位) {
    if (this.阶段 !== '指令') return false;
    this.选中位 = this.选中位 === 位 ? null : 位;
    this.选目标 = null; this.提示 = '';
    this.刷();
    return this.选中位;
  },
  下指令(类型) {
    if (this.阶段 !== '指令' || this.选中位 == null) return false;
    if (类型 === '集火' || 类型 === '守护') { this.选目标 = 类型; this.提示 = ''; this.刷(); return this.选目标; }
    this.选目标 = null;
    return this.设某指令(this.选中位, { 类型, 目标位: null });
  },
  点敌人(位) {
    if (this.阶段 !== '指令' || this.选目标 !== '集火' || this.选中位 == null) return false;
    const 目标 = this.ctx.enemies.find(x => x.slot === 位);
    if (!目标 || 目标.hp <= 0) return false;
    this.选目标 = null;
    return this.设某指令(this.选中位, { 类型: '集火', 目标位: 位 });
  },
  点队友(位) {
    if (this.阶段 !== '指令' || this.选目标 !== '守护' || this.选中位 == null) return false;
    if (位 === this.选中位) { this.提示 = '不能守护自己。'; this.刷(); return false; }
    const 冲突 = Object.keys(this.指令).some(k => Number(k) !== this.选中位 && this.指令[k].类型 === '守护' && this.指令[k].目标位 === 位);
    if (冲突) { this.提示 = `${位名(位)} 已经有人守护了（一名队友同时只能被一人守护）。`; this.刷(); return false; }
    this.选目标 = null;
    return this.设某指令(this.选中位, { 类型: '守护', 目标位: 位 });
  },
  切大招(位) {
    const c = this.当前指令(位);
    return this.设某指令(位, { 保留大招: !c.保留大招 });
  },

  /* ---------------- 肉鸽：把 92-肉鸽界面.js 的画面接进来 ---------------- */
  分队屏() { return 肉鸽界面.分队屏(); },
  大地图屏() { return 肉鸽界面.大地图屏(); },
  招募屏() { return 肉鸽界面.招募屏(); },
  奇遇屏() { return 肉鸽界面.奇遇屏(); },
  肉鸽结算屏() { return 肉鸽界面.肉鸽结算屏(); },

  选分队(名) { 肉鸽界面.分队ID = 名; 肉鸽界面.提示 = ''; this.刷(); return 名; },
  开新局() {
    if (!肉鸽界面.分队ID) { 肉鸽界面.提示 = '先挑一个分队。'; this.刷(); return false; }
    肉鸽.新的一局(肉鸽界面.分队ID);
    this.开屏('大地图');
    return true;
  },
  继续上一局() {
    const R = 肉鸽.读存档();
    if (!R) { this.开屏('菜单'); return false; }
    this.开屏('大地图');
    return true;
  },
  去节点(id) {
    const 类型 = 肉鸽.移动(id);
    if (!类型) return false;
    this.刷();
    /* 走到哪一类节点就开哪个屏（战斗类留在原地，等玩家点「打这一场」） */
    if (类型 === '招募') this.开屏('招募');
    else if (类型 === '奇遇') this.开屏('奇遇');
    else if (类型 === '补给') this.领补给();
    else if (类型 === '出口') { 肉鸽.节点完成(); this.开屏('大地图'); }   // 走到出口就进下一层
    return 类型;
  },
  打这一场() {
    if (!肉鸽.进行中) return false;
    const R = 肉鸽.RUN;
    const 条目 = 肉鸽.抽当前编成();
    if (!条目) { 肉鸽界面.提示 = `第 ${R.层} 层没有「${肉鸽.当前战斗类型()}」的编成，写进编成表再打。`; this.开屏('大地图'); return false; }
    /* 出击名单：优先用编队界面摆好的阵（RUN.出击阵 = [{键, 位}]），没有就用名册前几台 */
    const 阵 = (R.出击阵 && R.出击阵.length) ? R.出击阵 : R.队伍.slice(0, 肉鸽数值.出击上限).map((m, i) => ({ 键: m.键, 位: i }));
    const 等级 = 键 => { const m = R.队伍.find(x => x.键 === 键); return (m && m.等级) || 肉鸽数值.招募等级; };
    const 我方 = 阵.map(x => ({ 键: x.键, 位: x.位, 等级: 等级(x.键) }));
    const 敌方 = 编成到单位(条目, R.场次).map(u => ({ 键: u.key, 位: u.slot, 等级: u.lv }));
    this.肉鸽编队模式 = false;
    this.种子 = (R.种子 + R.层 * 131 + R.场次 * 17) >>> 0;
    this.肉鸽战斗 = { 类型: 肉鸽.当前战斗类型(), 条目 };
    this.ctx = 开局(我方, 敌方, this.种子);
    this.指令 = {};
    this.选中位 = null; this.选目标 = null; this.提示 = '';
    this.显示单位 = null; this.战报 = null;
    this.阶段 = '指令';
    this.开屏('战斗');
    return this.ctx;
  },
  /** 肉鸽：进战斗前先编队（方案 8.1 的第 3 条）——候选项是名册，摆进前 3 后 2 */
  准备肉鸽编队() {
    const R = 肉鸽.RUN;
    if (!R) return false;
    this.肉鸽编队模式 = true;
    this.编队.选中 = null;
    this.编队.出击 = (R.出击阵 && R.出击阵.length ? R.出击阵 : R.队伍.slice(0, 肉鸽数值.出击上限).map((m, i) => ({ 键: m.键, 位: i })))
      .map(x => ({ 键: x.键, 位: x.位 }));
    this.开屏('编队');
    return this.编队.出击;
  },
  /** 编队界面点「开战」：把摆好的阵记进 RUN，再开始这一场战斗 */
  从编队开战肉鸽() {
    const R = 肉鸽.RUN;
    if (!R) return false;
    const 阵 = this.编队.出击.slice().sort((a, b) => a.位 - b.位);
    if (!阵.length) { this.提示 = '先把机师拖进格子里。'; this.刷(); return false; }
    R.出击阵 = 阵.map(x => ({ 键: x.键, 位: x.位 }));
    R.出击 = 阵.map(x => x.键);
    肉鸽.存档();
    return this.打这一场();
  },
  招募(键) {
    const R = 肉鸽.RUN;
    if (!R) return false;
    if (R.队伍.length >= 肉鸽数值.队伍上限) { 肉鸽界面.提示 = `队伍已经满了（${肉鸽数值.队伍上限} 台）。`; this.开屏('招募'); return false; }
    if (R.队伍.some(m => m.键 === 键)) { 肉鸽界面.提示 = '这位机师已经在队里了。'; this.开屏('招募'); return false; }
    const 停 = 肉鸽.当前节点();
    const 之前 = R.场次;
    肉鸽.招募(键);                          // 内部会 节点完成()（含存档）
    if (停) { /* 招募完直接回大地图 */ }
    this.开屏('大地图');
    return true;
  },
  领补给() { 肉鸽.补给(); this.开屏('大地图'); return true; },
  选奇遇(选) { 肉鸽.奇遇(选); this.开屏('大地图'); return true; },
  存个档() { const ok = 肉鸽.存档(); 肉鸽界面.提示 = ok ? '已存档（关掉页面也能继续）。' : '存档失败（浏览器不让存？）'; this.开屏('大地图'); return ok; },
  放弃本局() { 肉鸽.失败('玩家放弃'); this.开屏('肉鸽结算'); return true; },

  /* ---------------- M5：音乐 ---------------- */
  /** 音乐鉴赏页（audio/music-room.js 的画面）：菜单进，关闭后回到菜单屏。 */
  去音乐鉴赏() {
    const ok = 音乐.打开鉴赏页();
    this.提示 = ok ? '' : (音乐.提示 || '音乐鉴赏页不可用。');
    this.刷();
    return ok;
  },

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
  设等级(n) { this.编队.等级 = n; this.预览缓存 = {}; this.刷(); return n; },
  设势力(f) { this.编队.势力 = f; this.刷(); return f; },
  设编成(i) { this.编队.编成序号 = Math.max(0, Math.min(编成表.length - 1, i || 0)); this.刷(); return this.编队.编成序号; },
  默认五人队() {
    /* 肉鸽模式：把名册前几台摆上；练习模式：默认五人队 */
    if (this.肉鸽编队模式 && 肉鸽.RUN) this.编队.出击 = 肉鸽.RUN.队伍.slice(0, 肉鸽数值.出击上限).map((m, i) => ({ 键: m.键, 位: i }));
    else this.编队.出击 = 默认五人队.map(x => ({ 键: x.键, 位: x.位 }));
    this.刷();
    return this.编队.出击;
  },
};
