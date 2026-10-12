/* ============================================================================
 * 界面（方案 8.1）：菜单 → 编队 → 战斗 → 结算
 * ----------------------------------------------------------------------------
 * M2：编队 + 战斗画面 + 播放控制。
 * M3：**指令阶段**（看敌人意图）+ 一回合一个回合地打。
 * ★ 2026-10-12（作者拍板「全队方针」）：那一层现在叫**方针阶段** —— 全队一条方针 + 每台只有大招开关。
 *
 * 战斗屏的阶段：
 *   指令阶段：**战场上方一条方针栏（5 条全军方针，当前的那条高亮）** + 点我方卡片改「大招：自动 / 保留」
 *             （天人另有 TRANS-AM 开关）；敌人卡片上显示**意图**（它这一回合打算打谁、用什么、
 *             预计多少伤害，方案 5.3）。选「集中攻击」之后**点敌人卡片**选目标。
 *   播放阶段：点「开打」跑这一回合，逐条放出来（攻击者冲一下、受击闪白、飘字）。
 *   回合播完：没分出胜负就回到指令阶段（**方针保持到玩家改为止**）；分出胜负就去结算。
 *
 * ★ 2026-10-12 作者拍板「全队方针」（`协作/方向调整-全队方针与反馈.md` §1.1 / §1.7）：
 *   决策分两层 —— **全队层 = 一条方针**（保持到改为止），**单位层 = 只有大招开关**；
 *   **战斗中不再有换位**、逐台指令与「守护」整条删掉（§1.4）。
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
  屏: '菜单',                     // 菜单 / 编队 / 战斗 / 结算 / 分队 / 大地图 / 招募 / 奇遇 / 黑市 / 肉鸽结算
  阶段: '指令',                   // 战斗屏的阶段：指令 / 播放 / 结算
  编队: { 等级: 10, 出击: [], 选中: null, 编成序号: 0, 势力: '全部' },
  ctx: null,                      // 这一场战斗的引擎状态（开局() 给的）
  /* ★ 两层决策（作者 2026-10-12，§1.1 / §1.6）：
     全队层 = `方针`（一条，保持到玩家改为止；开局 = 全军突击）；
     单位层 = `单位开关`（位 → {保留大招, TRANSAM, 本回合开TRANSAM}）。 */
  方针: { 类型: '全军突击', 目标位: null },
  单位开关: {},                   // 位 → {保留大招, TRANSAM, 本回合开TRANSAM}
  选中位: null,
  选目标: false,                  // true = 正在等玩家点一个敌人当「集中攻击」的目标
  提示: '',
  显示单位: null,                 // 播放阶段用的「这一回合开始时」的快照
  战报: null,                     // 结算用的小结
  肉鸽战斗: null,                 // 正在打的这一场是哪个肉鸽节点 {格类型, 类型, 条目}
  肉鸽战斗类型: '作战',           // 这一场的节点类型（打这一场() 从它取，出口守军 / 追击战会改写）
  肉鸽编队模式: false,            // 编队屏是「肉鸽里出战前编队」还是沙盒练习
  种子: null,
  手动播放: false,                // 测试用：播放引擎不排计时器，自己 tick
  跳过动画总是: false,
  预览缓存: {},
  对话框: null,                   // 测试用：`对话框(标题, 文本, 选项)` 给一个返回值就顶替弹窗（见 肉鸽弹窗）

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
  开屏(名) {
    this.屏 = 名;
    this.刷();
    /* M5：切屏跟着换曲子（方案 8.2）。`96-音乐.js` 在最后，加载期/测试期取不到就跳过 —— 音乐是可选层，
       任何一种「读不到曲子」的情况都不该让界面切屏失败（M5 的降级规矩）。 */
    if (typeof 音乐 !== 'undefined' && 音乐 && typeof 音乐.场景切换 === 'function') 音乐.场景切换(名);
    return this;
  },

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
      const 上限 = this.当前出击上限();
      if (B.出击.length >= 上限) { this.提示 = this.出击上限说明() + '。'; this.刷(); return false; }
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

  /** 界面上的所有动作都走这里（浏览器里由按钮点，测试里直接调用）。
   *  动作名有两种写法（沿用 M4 起的老约定）：
   *    ① `动作` 或 `动作:参数`（例如 `选分队:近卫`、`去节点:12`、`休整:耐久`）—— 按 `:` 拆一次；
   *    ② 动作表里直接写了带冒号的键名（例如 `黑市买:g2` 不会这样写，但 `黑市离开` 是整键）—— 先查整键。 */
  动作(动, 参) {
    if (动 == null) return null;
    const 名 = String(动);
    /* 弹窗上的按钮：`弹窗:<值>` —— 先把答案填回去（`对话框()` 正同步等着它） */
    if (名.indexOf('弹窗:') === 0) return this.回答(名.slice(3));
    if (typeof this.动作表[名] === 'function') return this.动作表[名].call(this, 参);
    const i = 名.indexOf(':');
    if (i > 0) {
      const 头 = 名.slice(0, i), 尾 = 名.slice(i + 1);
      if (typeof this.动作表[头] === 'function') return this.动作表[头].call(this, 尾);
    }
    return null;
  },
  /* 动作表（M4）：键 = 界面上 `data-act` 的名字，值 = 处理函数（`this` = 界面）。
     原来是一个大 switch，换成表之后「出口被守军挡着」那条带参数的动作名
     （`去节点:<格号>`）可以在 动作() 里按前缀转一次。
     用 `键: function(参){…}` 的写法（不用简写方法），因为键名和 `界面` 上的方法同名，
     简写会让人以为 `this.xxx` 指的是表里的项 —— 写成函数属性最不容易看错。 */
  动作表: {
    去编队: function () { return this.开屏('编队'); },
    回菜单: function () { return this.开屏('菜单'); },
    选人: function (参) { return this.选人(参); },
    放位: function (参) { return this.放位(Number(参)); },
    取回: function (参) { return this.取回(Number(参)); },
    默认五人队: function () { return this.默认五人队(); },
    清空: function () { return this.清空(); },
    等级: function (参) { return this.设等级(Number(参)); },
    势力: function (参) { return this.设势力(参); },
    编成: function (参) { return this.设编成(Number(参)); },
    开战: function () { return this.肉鸽编队模式 ? this.从编队开战肉鸽() : this.开战(); },
    开打: function () { return this.开打(); },
    暂停: function () { return this.暂停(); },
    二倍速: function () { return this.二倍速(); },
    跳过: function () { return this.跳过(); },
    再来一场: function (参) { return this.来一场(参); },
    /* M3 / ★ 2026-10-12 全队方针 */
    选单位: function (参) { return this.选单位(Number(参)); },
    方针: function (参) { return this.选方针(参); },
    点敌人: function (参) { return this.点敌人(Number(参)); },
    大招: function (参) { return this.切大招(Number(参)); },
    /* ★ 天人的 TRANS-AM 单位级开关（作者 2026-10-11 拍板）：切自动 / 手动、手动档本回合点开 */
    TRANSAM: function (参) { return this.切TRANSAM(Number(参)); },
    开TRANSAM: function (参) { return this.开TRANSAM(Number(参)); },
    /* M4 肉鸽 */
    去分队: function () { return this.开屏('分队'); },
    选分队: function (参) { return this.选分队(参); },
    /* `开新局` 可以带一个**测试用的种子**：`界面.动作('开新局:20261010')`
       （`动作()` 按第一个 `:` 拆，写法和 `选分队:近卫` 一样；界面按钮仍然不传 → 照旧现取时间）。 */
    开新局: function (参) { return this.开新局(参); },
    继续上一局: function () { return this.继续上一局(); },
    回大地图: function () { return this.开屏('大地图'); },
    去节点: function (参) { return this.去节点(参); },
    打这一场: function () { return this.打这一场(); },
    去招募: function () { return this.开屏('招募'); },
    招募: function (参) { return this.招募(参); },
    /* ★ 2026-10-11 招募券：选中 / 取消选中手上的第 N 张券（招募屏用）+ 丢弃一张券。
       为什么只有「用券」这一条带下标：`动作()` 只按第一个 `:` 拆一次，界面上不能写
       `券招募:0:B1`；选中的券存在 `肉鸽界面.选中的券` 里，招募按钮照旧是 `招募:<键>`。 */
    用券: function (参) { return this.用券(Number(参)); },
    丢券: function (参) { return this.丢券(参); },
    /* 晋升（10 → 20 → 30）+ 零件（大地图上用的那几个） */
    去晋升: function () { return this.去晋升(); },
    晋升: function (参) { return this.晋升(参); },
    去零件: function () { return this.去零件(); },
    使用零件: function (参) { return this.使用零件(Number(参)); },
    去黑市: function () { return this.开屏('黑市'); },
    /* ★ 2026-10-11 记录屏（作者「记录也需要显示」）：入口在大地图 + 本局结算屏上。 */
    去记录: function () { return this.去记录(); },
    记录清结果: function () { return this.记录清结果(); },
    黑市买: function (参) { return this.黑市买(参); },
    黑市离开: function () { return this.黑市离开(); },
    黑市刷新: function () { return this.黑市刷新(); },
    黑市卖: function (参) { return this.黑市卖零件(参); },
    瞭望: function () { return this.去瞭望(); },
    穿隧道: function () { return this.穿隧道(); },
    探查遗迹: function () { return this.去遗迹(); },
    休整: function (参) { return this.休整(参); },
    前进: function (参) { return this.前进(参); },
    跳过节点: function () { return this.跳过节点(); },
    补给: function () { return this.领补给(); },
    去奇遇: function () { return this.开屏('奇遇'); },
    奇遇: function (参) { return this.选奇遇(参); },
    存个档: function () { return this.存个档(); },
    放弃本局: function () { return this.放弃本局(); },
    /* M5 美术和音乐 */
    音乐鉴赏: function () { return this.去音乐鉴赏(); },
    声音: function () { return 音乐.切开关(); },
  },

  /* ---------------- 通用弹窗（隧道 / 休整 / 出口都用它） ----------------
     ① 测试用：`界面.对话框钩子 = (标题, 文本, 选项) => 值` 直接顶替弹窗；
     ② 真的在浏览器里：记在 `this.弹窗` 上，画面右边出现一排按钮，
        点一下走 `data-act="弹窗:<值>"` → 动作表里的 `弹窗` → 回调。
     两种都是**同步**返回的（`回答` 就是最后选的那个值），所以节点的结算不需要 await。 */
  对话框(标题, 文本, 选项) {
    if (typeof this.对话框钩子 === 'function') return this.对话框钩子(标题, 文本, 选项);
    if (typeof document === 'undefined' || !document.body) return 选项 && 选项.length ? 选项[0].值 : null;
    this.弹窗 = { 标题, 文本, 选项, 答案: null };
    this.刷();
    return this.弹窗.答案;
  },
  /** 回答当前弹窗（界面上点按钮 / 测试直接调） */
  回答(值) {
    const d = this.弹窗;
    this.弹窗 = null;
    if (d) d.答案 = 值;
    return 值;
  },
  弹窗控件Html() {
    const d = this.弹窗;
    if (!d) return '';
    return `<div class="rv-card dlg"><h3>${d.标题}</h3><p class="small">${d.文本 || ''}</p>
      <div class="acts">${(d.选项 || []).map(o => `<button data-act="弹窗:${o.值}">${o.名}</button>`).join('')}</div></div>`;
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
      <h3>机甲指挥 · 晋升 + 零件（大地图上用的那一批）</h3>
      <p>自动战斗回合制 RPG：把机体摆进<b>前排 4 格 / 后排 5 格</b>的 9 格阵型（一开始只上 3 台，最多 6 台），每回合给全队下一条<b>大方向方针</b>（单位层只管大招开不开），这一回合按速度自动打完。</p>
      <ul>
        <li><b>肉鸽</b>（方案第 7 节）：选分队 → <b>6×4 网格大地图</b>（战棋那套：四邻接 BFS 走格子、
          <b>推进剂</b>每层 7、走一格扣 1、用光触发追击战）→ 作战 / 精英 / 侵蚀源 / 黑市 / 事件 / 瞭望站 /
          遗迹 / 休整 / 招募站 / 隧道 / 出口守军 → 第 4 层出口通关；
          希望 / 源碳结晶 / 作战耐久 / 藏品 / <b>零件</b>，<b>关掉页面能继续</b>（存档）。</li>
        <li><b>晋升</b>（大地图上随时点）：花<b>希望</b>把队里的机体从 Lv10 升到 20、再升到 30
         （价格照战棋：精锐 3/4、骨干 2/3、普通 1/2；休整节点能给「下次 −1 希望」）；
          <b>零件</b>也全在大地图上用：补推进剂上限（河谷祭祈）/ 跳格 / 传送（喷气背包、小八界…），不花推进剂。</li>
        <li><b>战斗</b>：方针阶段（全队一条方针：全军突击 / 集中攻击 / 攻击后排 / 前守后攻 / 全军防御；
          单位层只有「大招：自动 / 保留」，天人另有 TRANS-AM）→ 看敌人意图 →「开打 ▶」自动打完。</li>
        <li><b>练习</b>：不进肉鸽，直接用编队界面挑一队打一场（试数值用）。</li>
      </ul>
      <div class="acts">
        <button class="primary" data-act="去分队">新的一局（肉鸽）→</button>
        ${有存档 ? `<button data-act="继续上一局">继续上一局（第 ${肉鸽.读存档().层} 层）</button>` : ''}
        <button data-act="去编队">练习：直接编队打一场</button>
        <button data-act="音乐鉴赏">音乐鉴赏</button>
      </div>
      <p class="small">网格大地图照战棋 <code>26-地图生成.js</code> / <code>28-层.js</code> / <code>30-移动与节点.js</code> 实现
        （数值逐字照抄，出处写在 <code>91-地图.js</code> 里）；机体图标是原创矢量素材（<code>art/mech-icons.js</code>）；
        音乐按场景切，<b>放大招</b>时切成那台机体的主题曲、保持到本回合结束。右上角是声音开关（按 <b>M</b> 也行）。</p>
    </section>`;
  },

  /* ---------------- 编队 ---------------- */
  /** 这一屏最多能上几台（作者 2026-10-10 **第二次拍板**：按**肉鸽等级**算，起始 3 台、每 3 级 +1、封顶 6）。
   *  肉鸽里走 `肉鸽.出击上限()`（= `RUN.等级` → `05-阵型.js` 的 `出击上限()`）；
   *  练习模式没有 RUN、也没有肉鸽等级，走**旧口径** `出击上限按机体等级(编队.等级)`
   *  （Lv10 → 3 台、Lv15 → 4、Lv20 → 5、Lv25+ → 6）。 */
  当前出击上限() {
    if (this.肉鸽编队模式 && 肉鸽.RUN) return 肉鸽.出击上限();
    return 出击上限按机体等级(this.编队.等级);
  },
  /** 出击上限那一句说明（编队屏的标题 + 拖不进去时的提示都用它，口径只有一份）：
   *  肉鸽里写「**两级封顶**：等级那条线几台 / 最多 6 台，藏品 +N 台、最多加到 9 台」；
   *  练习模式写旧口径（练习模式没有 RUN、也没有藏品加成，封顶仍是 6）。 */
  出击上限说明() {
    const 上限 = this.当前出击上限();
    if (this.肉鸽编队模式 && 肉鸽.RUN) {
      const t = 出击上限提示(肉鸽.RUN.等级, 藏品部署位加成(肉鸽.RUN));
      return `出击上限 ${上限} 台（肉鸽部队 Lv${肉鸽.RUN.等级}：**等级那条** ${t.等级上限} / ${t.等级成长顶} 台` +
        `${t.等级到顶 ? '，等级已到顶' : `，再升到 Lv${t.解锁等级} 加 1 台`}；` +
        `**藏品** +${t.藏品加成} 台，7–9 台只能靠藏品，绝对封顶 ${t.绝对顶} 台）`;
    }
    return `出击上限 ${上限} 台（练习模式按机体等级：每 ${机体每几级加一台} 级 +1，最多 ${等级成长顶} 台；练习模式没有藏品加成）`;
  },
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
    const 上限 = this.当前出击上限();
    const 编成选项 = 编成表.map((e, i) => {
      /* 下拉里带上这一条的「考点」（作者 2026-10-10：每条编成必须考一个指令）——
         练习模式换编成的时候能直接看到这一场想让玩家练什么。 */
      const 名 = `第${e.层}层 ${e.类型}｜前 ${(e.前 || []).join('+') || '—'} / 后 ${(e.后 || []).join('+') || '—'}｜${e.考点 || '（没写考点）'}`;
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
        <h3>出击编队（${B.出击.length} / ${上限}）<span class="small">9 格阵型：上排 = 后排 5 格，下排 = 前排 4 格；${this.出击上限说明()}</span></h3>
        <div class="grid">${格.join('')}</div>
        <div class="acts">
          <button data-act="默认五人队">${肉鸽模式 ? `把名册前 ${上限} 台摆上` : `摆上前 ${上限} 台`}</button>
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
    /* ★ 三层反馈的**预告**（作者 2026-10-12 拍板的第 2 件，§2.2 的「预告」列）：
       指令阶段每一屏算一次（全是纯读：`chooseAttack()` / `rowReachable()` / `按防御结算()` ——
       不改战斗状态、不消耗随机数），再交给每张卡片；播放阶段不算（`预告快照()` 自己会拦）。 */
    const 预告 = 指令阶段 ? 预告快照(this.ctx) : null;
    const 排 = (列表, 方, 从后往前) => {
      const 行序 = 从后往前 ? [ROW_BACK, ROW_FRONT] : [ROW_FRONT, ROW_BACK];
      return 行序.map(r => `<div class="row" style="--cols:${行列数(r)}">${Array.from({ length: 行列数(r) }, (_, c) => {
        const 位 = slotOf(r, c);
        const u = 列表.find(x => x.slot === 位);
        return u ? this.单位卡(u, 方, 意图.find(i => i.单位位 === 位), 指令阶段, 预告) : `<div class="uc empty"><span class="pos">${位名(位)}</span></div>`;
      }).join('')}</div>`).join('');
    };
    return `<section class="战斗屏">
      ${this.方针栏(指令阶段)}
      <div class="side ally">
        <h3>我方 <span class="small">${指令阶段 ? '点一张卡片改大招开关' : '后排在上 · 前排贴住接触线'}</span></h3>
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

  /* ---------------- 方针栏（作者 2026-10-12 拍板，§1.7） ----------------
   * 战场**上方一条**，5 个按钮，当前方针高亮；**战斗进行中也一直显示**（「玩家随时看得见现在全队在干什么」）。
   * 选「集中攻击」之后进入「点敌人」状态 → 点一张敌方卡片选目标（`点敌人()`）。
   * 五种类型 + 一句代价 / 收益，全部照 §1.2 那张表（**方针本身不带任何加成**）。 */
  方针栏(可点) {
    const p = this.ctx ? 当前方针(this.ctx) : this.方针;
    const 当前 = p.类型;
    const 目标 = this.ctx ? 方针目标(this.ctx) : null;
     const 一句 = {
      全军突击: '每台各自挑目标（代价 / 收益都没有）',
      集中攻击: '打得到的都打它；打不到的照常自由攻击',
      攻击后排: '优先打对面后排；打不到就照突击',
      前守后攻: '前排执行防御规则、后排照突击',
      全军防御: '放弃攻击；非攻击动作照常做，其余执行防御动作',
    };
    return `<div class="cmdpanel policybar">
      <h3>全队方针 · <b>${当前}</b>${目标 ? ` → ${目标.name}（${位名(目标.slot)}）` : ''}
        <span class="small">保持到改为止 · 单位层只有大招开关</span></h3>
      <div class="cmds">${方针们.map(k => `<button class="mini${当前 === k ? ' on' : ''}"${可点 ? ` data-act="方针:${k}"` : ' disabled'}>${k}</button>`).join('')}</div>
      <p class="small">${一句[当前] || ''}${当前 === '集中攻击' ? (目标 ? '　目标已选。' : '　<b>还没点目标</b>：点一张敌方卡片。') : ''}
        ${可点 && this.选目标 ? '　<b>正在选目标：点一个敌人。</b>' : ''}</p>
      ${可点 && this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </div>`;
  },

  /** 指令面板（§1.7）：单位卡片上只有「大招：自动 / 保留」（天人另有 TRANS-AM 开关）。
   *  先点一张我方卡片才会出现；没点就写一句提示。 */
  指令面板() {
    const 位 = this.选中位;
    if (位 == null) return `<div class="cmdpanel"><h3>单位开关</h3><p class="small">全队方针在上面那一栏。<b>点一张我方卡片</b>改这一台的大招开关（天人另有 TRANS-AM）。</p></div>`;
    const u = this.ctx.allies.find(x => x.slot === 位);
    if (!u) return '';
    const c = this.当前指令(位);
    return `<div class="cmdpanel">
      <h3>单位开关 · ${u.name}<span class="small">${u.key} · ${u.tags.战斗分类} · ${位名(位)}</span></h3>
      <div class="cmds"><button class="mini${c.保留大招 ? ' on' : ''}" data-act="大招:${位}">大招：${c.保留大招 ? '保留' : '自动'}</button></div>
      ${this.天人开关(位, u, c)}
      <p class="small">「保留」= 这一回合不放这个大招（推迟，不是作废）。其余交给上面的全队方针。</p>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </div>`;
  },

  /** ★ **TRANS-AM 的单位级开关**（作者 2026-10-11 拍板原话「TRANS-AM 应该是单个单位开关的」）：
   *  指令面板上给**每台有 `transAm` 的机体**一个「TRANS-AM：自动 / 手动」开关；
   *  手动档多一个「**开 TRANS-AM**」按钮 —— **CD 没到就 `disabled`，并把为什么写在按钮上与下面那行小字里**
   *  （「为什么」和单位卡那一行**同源**：都读 `72-势力.js` 的 `天人手动可开()`，两处不会说两套话）。
   *  没有 `transAm` 的机体（拉塞 CB5）返回空串 —— 一张卡都不多画。
   *  ★ 开关存进**指令表**（`TRANSAM` / `本回合开TRANSAM`），和「大招：自动 / 保留」同一层、逐回合保留。 */
  天人开关(位, u, c) {
    if (!有TRANSAM(u, 天人参数())) return '';
    const 手 = c || this.当前指令(位);
    const 手动 = 手.TRANSAM === '手动';
    const 判 = 天人手动可开(u, 天人参数());
    const 开 = 手动
      ? `<button class="mini${手.本回合开TRANSAM ? ' on' : ''}" data-act="开TRANSAM:${位}"${判.可以 ? '' : ' disabled'}`
        + ` title="${判.可以 ? '点了就在本回合开' : '开不了：' + 判.原因}">`
        + `开 TRANS-AM${手.本回合开TRANSAM ? '（本回合已点）' : ''}${判.可以 ? '' : `（${判.原因}）`}</button>`
      : '';
    return `<div class="cmds">
        <button class="mini${手动 ? ' on' : ''}" data-act="TRANSAM:${位}">TRANS-AM：${手动 ? '手动' : '自动'}</button>${开}
      </div>
      <p class="small">${手动
        ? `手动档：CD 到了也<b>不会自动开</b>，要在本回合点「开 TRANS-AM」。${判.可以 ? `现在${判.原因}。` : `现在<b>开不了</b>：${判.原因}。`}`
        : '自动档（默认）：CD 一到就在回合开始自动开，不用点。'}</p>`;
  },

  单位卡(u, 方, 意图, 可点, 预告) {
    const 色 = 方 === 'ally' ? 势力色(u.key) : 敌方色;
    const hp = Math.max(0, Math.round(u.hp / u.maxHp * 100));
    const 动 = 可点 ? (方 === 'ally' ? ` data-act="选单位:${u.slot}"` : ` data-act="点敌人:${u.slot}"`) : '';
    const c = 方 === 'ally' ? this.当前指令(u.slot) : null;
    const 指令行 = c ? `大招：${c.保留大招 ? '保留' : '自动'}` : '';
    /* ★ 2026-10-12（§1.7）：被「集中攻击」点名的敌机卡片上**一直挂标记**，直到它被击破或方针改掉。
       判定读**引擎的当前方针**（`ctx.方针`）—— 目标被击破时引擎会自动回到全军突击，
       界面跟着变，不会出现「界面写集中攻击、实际在自由攻击」。 */
    const 方针现 = this.ctx ? 当前方针(this.ctx) : this.方针;
    const 被点名 = 方 === 'enemy' && 方针现.类型 === '集中攻击' && 方针现.目标位 === u.slot;
    const 点目标中 = 方 === 'enemy' && 可点 && this.选目标 && 方针现.类型 === '集中攻击';
    /* 站桩 Boss（61-Boss.js）：大技能那一下前面标 ★；蓄力时直接写「蓄力中」——
       玩家在指令阶段就能看见 Boss 的节奏（方案 5.3 的意图显示）。
       ★ 2026-10-11：**敌方大招**（精锐 / 头目档的强武器，`战斗结构.敌方大招`）也标 ★ ——
       玩家因此能在指令阶段看到「这一回合必须扛住」的那一发（作者要的「有压力」）。
       ★ 2026-10-11 第二轮：大技能 / 范围武器再写一句**「将打哪几个位」**（`算意图()` 的 `落点们`）——
       形状收窄成 `col`（阻挡束）/ `cross` 之后，玩家能一眼看出「换位躲不躲得掉」（作者要的「可躲」）。 */
    const 落点文字 = 意图 && 意图.落点们 && 意图.落点们.length && 意图.形状 !== '单格'
      ? `　将打：${意图.落点们.map(位名).join('、')}（${意图.形状} 形状）` : '';
    const 意图行 = 意图 && 意图.武器
      ? `${意图.大技能 || 意图.大招 ? '★大技能 ' : ''}→ ${意图.目标名}(${位名(意图.目标位)}) · ${意图.武器} · 约 ${意图.期望}${意图.被挡 ? '（被挡 −20 命中）' : ''}${落点文字}`
      : (意图 ? (意图.蓄力 ? '蓄力中（这一回合不出手）' : '不行动') : '');
    const 选中 = 方 === 'ally' && this.选中位 === u.slot ? ' sel' : '';
    /* 势力特色（作者 2026-10-10；框架在 `72-势力.js`）：单位卡上多一行字，**只多这一行**——
       第一件 = 卫星国防军 SEED「累计 / 还差多少」与觉醒后的加成；没有特色的单位是空串。 */
    const 势力行 = 方 === 'ally' ? 势力卡行(u) : '';
    /* 秘银（势力特色第六件，`72-势力.js`）：**敌机卡**上显示它身上挂的标定（几层 / 谁挂的 / 兑现了没）——
       框架的 `势力卡行()` 只问我方单位（敌人卡走不到那里），所以这一行走 `秘银标定卡行()`；
       **没有标定 = 空串**（一张卡都不多画，别的战斗逐字不变；播放阶段的快照没有 `debuffs` 也走同一条）。 */
    const 标定行 = 方 === 'enemy' ? 秘银标定卡行(u) : '';
    /* ★ 三层反馈的**预告**（作者 2026-10-12 拍板的第 2 件，§2.2 的「预告」列）——
       只在**指令阶段**画（`可点` = 指令阶段；播放阶段传的是「这一回合开始时」的快照，
       那些单位对象没有齐全的武器运行期字段，也不该在播放中改口）。
       判据全部来自 `84-反馈.js` 的 `预告快照()`（纯读，不改状态、不消耗随机数）：
         · 大招开关：冷却剩几回合 / 「保留」时把「保留」标出来（§2.2 第 5 行）；
         · 攻击后排：每台我方标「打得到 / 打不到后排」（§2.2 第 3 行）；
         · 前守后攻 / 全军防御：进入防御的单位挂盾标 + 「防御值 +50」（§2.2 第 4 行）；
         · 集中攻击：被点名的那张敌机卡上写「全队对它的预计伤害合计 X / 它剩 Y HP」（§2.2 第 2 行）。 */
    const 预 = 可点 && 预告 ? 预告 : null;
    const 预告行们 = [];
    if (预 && 方 === 'ally') {
      const g = 预.大招 ? 预.大招[u.slot] : null;
      if (g && g.有大招) 预告行们.push(`大招${g.可放 ? '已就绪' : `冷却剩 ${g.冷却剩} 回合`}${g.保留 ? ' · <b>保留</b>（这一回合不放）' : ''}`);
      if (预.方针 === '攻击后排') 预告行们.push(预.后排我能 && 预.后排我能[u.slot] ? '打得到后排' : '打不到后排');
      if (预.防御位 && 预.防御位.includes(u.slot)) 预告行们.push(`🛡 防御姿态：${预.防御说明 || '防御值 +50'}`);
    }
    if (预 && 方 === 'enemy') {
      if (预.后排位 && 预.后排位.includes(u.slot) && 预.方针 === '攻击后排') 预告行们.push('攻击后排：全队优先打它');
      if (预.集中 && 预.集中.目标位 === u.slot) {
        预告行们.push(`全队对它的预计伤害合计 ${预.集中.预计伤害合计} / 它剩 ${预.集中.剩余HP} HP`
          + `（${预.集中.台数} 台打得到${预.集中.会打 < 预.集中.台数 ? `，这一回合 ${预.集中.会打} 台会打它` : ''}）`);
      }
    }
    const 预告行 = 预告行们.length ? `<div class="fb-line" data-forecast="1">${预告行们.join('<br>')}</div>` : '';
    return `<div class="uc${u.hp <= 0 ? ' down' : ''}${选中}${被点名 ? ' marked' : ''}${点目标中 ? ' pickable' : ''}" id="u-${方}-${u.slot}" data-side="${方}" data-slot="${u.slot}" style="--fc:${色}"${动}>
      <span class="pos">${位名(u.slot)}</span>
      <div class="head">${图标.卡(u.key, 方, 图标.尺寸.卡)}<div class="nm"><b>${u.name}</b><small>${u.key} · 速 ${speedOf(u)}</small></div></div>
      <div class="bar hp"><i style="width:${hp}%"></i></div>
      <div class="nums">HP ${Math.max(0, u.hp)} / ${u.maxHp}${u.shieldHp ? ` · 盾 ${u.shieldHp}` : ''}</div>
      <div class="tags">${(u.tags && u.tags.战斗分类) || ''}${u.weapons && u.weapons.filter(e => isUltimate(e.t)).length ? ' · 大招' : ''}</div>
      ${势力行 ? `<div class="faction">${势力行}</div>` : ''}
      ${标定行 ? `<div class="faction">${标定行}</div>` : ''}
      ${被点名 ? `<div class="cmd">集中攻击（全队打它）</div>` : ''}
      ${预告行}
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
      /* ★ 三层反馈的**即时**（作者 2026-10-12 拍板的第 2 件，§2.2 的「即时」列）：
         「伤害数字旁」那一个小标签（`集中` / `被挡 −20` / `防御 少挨 N`）——
         字段来自记录，`反馈标签()` 把记录翻成人话；没有那三个字段时**一个字都不多**（默认路径的显示也不变）。 */
      const 签 = 飘.标签 ? `<span class="float-tag${飘.暴击 ? ' crit' : ''}">${飘.标签}</span>` : '';
      if (飘.伤害 || 签) el.innerHTML += `<span class="float${飘.暴击 ? ' crit' : ''}">${飘.伤害 || ''}</span>${签}`;
    }
  },

  /* ---------------- 战斗流程 ---------------- */
  /** 由编队进入战斗：建立引擎状态（不再一次算完整场——玩家的方针每回合都可能改）。
   *  ★ 每一场新战斗开始时是**全军突击**（§1.3 第 1 条 / §6 第 1 条）。 */
  开战(种子) {
    const B = this.编队;
    if (!B.出击.length) return false;
    const 我方 = B.出击.slice().sort((a, b) => a.位 - b.位).map(x => ({ 键: x.键, 位: x.位, 等级: B.等级 }));
    const 条目 = 编成表[B.编成序号];
    const 敌方 = 敌方规格组(编成到单位(条目, 0));
    this.种子 = 种子 != null ? Number(种子) : Math.floor(Date.now() % 900000) + 100000;
    /* 敌方增援波次（作者 2026-10-10）：编成表里配的波次交给引擎，回合开始时按回合号补人 */
    this.ctx = 开局(我方, 敌方, this.种子, null, { 波次: 编成波次到单位(条目, 0) });
    this.方针 = { 类型: '全军突击', 目标位: null };
    this.单位开关 = {};
    this.选中位 = null;
    this.选目标 = false;
    this.提示 = '';
    this.显示单位 = null;
    this.战报 = null;
    this.阶段 = '指令';
    this.开屏('战斗');
    return this.ctx;
  },

  /** 「开打」：把方针 + 单位开关交给引擎 → 打一回合 → 把这一回合的记录交给播放引擎放出来。 */
  开打() {
    if (!this.ctx || this.阶段 !== '指令') return false;
    /* ★ 「集中攻击」没点目标 = 这一条下不了（引擎也会把它当全军突击）；
       界面上直接写清「先点一个敌人」，不要让玩家以为点了没反应。 */
    if (this.方针.类型 === '集中攻击' && this.方针.目标位 == null) {
      this.提示 = '「集中攻击」要先点一张敌方卡片选目标。';
      this.刷();
      return false;
    }
    /* 记下这一回合**开始时**的状态：播放时血条从这里开始走。
       字段要够单位卡用（`速 ` 读 `speedOf()` 的 `mov` / `eva`）+ 势力特色那一行
       （`abilities` / `awaken` / `势力状态`，`势力卡行()` 读它们，第一件 = SEED 层数）——
       少了就会在播放阶段显示「速 NaN」/ 0 层（**顺手修掉的老问题：「速 NaN」**）。 */
    const 快照 = 列表 => 列表.map(u => ({
      side: u.side, slot: u.slot, key: u.key, name: u.name, maxHp: u.maxHp, hp: u.hp,
      shieldHp: u.shieldHp, tags: u.tags, weapons: u.weapons, abilities: u.abilities,
      mov: u.mov, eva: u.eva, awaken: u.awaken,
      /* ★ 天人的 TRANS-AM 单位级开关也要进快照（作者 2026-10-11 拍板）：不然播放阶段
         单位卡那一行会写回「开关：自动」，和指令阶段看到的不一致。 */
      TRANSAM手动: !!u.TRANSAM手动,
      势力状态: u.势力状态 ? JSON.parse(JSON.stringify(u.势力状态)) : null,
    }));
    this.显示单位 = { 我方: 快照(this.ctx.allies), 敌方: 快照(this.ctx.enemies) };
    设方针(this.ctx, this.方针);                 // 全队层（保持到玩家改为止）
    设单位开关(this.ctx, this.单位开关);          // 单位层（只有大招 / TRANS-AM）
    const 记录 = 打一回合(this.ctx);
    /* ★ 集中攻击的目标被击破时引擎会**自动回全军突击**（§1.3 第 2 条）——界面跟着走。 */
    this.方针 = { 类型: 当前方针(this.ctx).类型, 目标位: 当前方针(this.ctx).目标位 };
    /* ★ TRANS-AM 的「本回合开」**点一次只管本回合**：打完了就把表里那一位清掉
       （`72-势力.js` 的 `手动开天人()` 读掉之后也会清单位上那一位）；
       开关 `TRANSAM`（自动 / 手动）**留着**——下一回合还是玩家上次选的那一档（逐回合保留）。 */
    for (const k of Object.keys(this.单位开关)) this.单位开关[k].本回合开TRANSAM = false;
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

  /** 这一回合播放完了：分出胜负就去结算，否则回到指令阶段（**方针保持到改为止**）。 */
  回合播完() {
    音乐.回合结束();                 // M5：主题曲只保持到本回合结束（方案 8.2）
    if (this.ctx.result) return this.到结算();
    this.阶段 = '指令';
    this.选中位 = null;
    this.选目标 = false;
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
    /* ★ 三层反馈的**即时**（§2.2 的「即时」列）：这张卡上那一下要不要挂个小标签 ——
       `集中` / `被挡 −20` / `防御 少挨 N`（字段由引擎写在记录上；没有就一个标签都不画）。 */
    const 签 = 反馈标签(ev);
    if (ev && ev.目标方 != null) this.刷卡(ev.目标方, ev.目标位, { 伤害: ev.伤害, 暴击: ev.暴击 > 0, 标签: 签 });
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
      日志.innerHTML += ev ? `<li class="${类}"><span class="t">${ev.回合}</span>${ev.文本}${签 ? ` <span class="tagx">〔${签}〕</span>` : ''}</li>` : '<li class="sys">（本回合播放结束）</li>';
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
    /* 肉鸽里的战斗：把结果交回肉鸽（发奖励 / 扣作战耐久 / 出口守军放行 / 追击后换层），
       然后回大地图；本局结束（耐久耗尽 / 通关）就去肉鸽结算屏。
       ★ 2026-10-11「界面体验修复」（作者：「现在很多事情结束以后，结果没有提示」）：
         打完之后**必须**在结果条上留一句「这一场拿到了什么 / 付出了什么」——
         以前这里一个 `提示` 都不设，玩家打赢回大地图只看到推进剂变了。 */
    if (this.肉鸽战斗) {
      const 这次 = this.肉鸽战斗;
      this.肉鸽战斗 = null;
      const r = 肉鸽.战斗结束(this.战报.结果, 这次.格类型, this.战报);
      /* 这一场的**奖励清单**原样存着（大屏上的「战斗结算清单」画它；只读返回值，不改任何奖励逻辑）。 */
      肉鸽界面.战斗结算 = r || null;
      const 名 = (节点类型表[这次.格类型] && 节点类型表[这次.格类型].名) || 这次.格类型;
      const 首 = 战斗奖励清单文字(r);
      /* `去重 = true`：引擎自己已经写过更细的一行（「XX胜利：希望 +N、源碳 +N」等），
         同一句话就不重复记 —— 结果条上那句话玩家照样看得到。 */
      if (r && r.胜) 肉鸽界面.设结果('成功', `${名}胜利 —— ${首}`);
      else if (r && r.结束) 肉鸽界面.设结果('失败', `${名}失败 —— ${首}（本局结束）`);
      else 肉鸽界面.设结果('失败', `${名}失败 —— ${首}`);
      this.阶段 = '结算';
      if (!肉鸽.进行中 || (肉鸽.RUN && 肉鸽.RUN.结局)) this.开屏('肉鸽结算');
      else this.开屏('大地图');
      return r;
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
        <li>种子：<b>${b.种子}</b>（同种子同编队同方针重放，结果完全一样）</li>
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

  /* ---------------- 指令阶段的动作（★ 2026-10-12 全队方针，§1.6 / §1.7） ----------------
   * 两层：全队层 `选方针(类型)` + `点敌人(位)`（集中攻击的目标）；单位层 `切大招(位)` / TRANS-AM 两个。
   * ★ **兼容别名**（内部名沿用旧的两层叫法，`interface` 给测试与老调用点用）：
   *   `界面.单位开关[位]` = 这一台的开关（旧名 `界面.指令[位]` 已删）；
   *   `当前指令(位)` / `切TRANSAM(位)` / `开TRANSAM(位)` 名字没变（**势力特色第四件**的测试与界面都读它）。
   *   ★ 为什么名字保留：`tests/faction.js` 第 [14] 段 6 条断言逐字读 `界面.指令[0].TRANSAM` / `本回合开TRANSAM`
   *     （§1.8 授权删的只有「旧集火 / 守护 / 换位」那批），所以这里**留一个 `指令` 的 getter** 指向同一张表，
   *     一条断言都不用改（`界面.指令` 就是 `界面.单位开关`）。 */
  当前指令(位) { return Object.assign({ 保留大招: false, TRANSAM: '自动', 本回合开TRANSAM: false }, this.单位开关[位] || {}); },
  /** ★ 兼容别名：`界面.指令[位]` 就是 `界面.单位开关[位]`（同一张表；`tests/faction.js` 第 [14] 段读它）。
   *  旧名里的「指令」两个字现在只剩「单位层开关」这一层意思 —— 逐台指令那一层已经删掉（§1.4）。 */
  get 指令() { return this.单位开关; },

  设某开关(位, 补丁) {
    this.单位开关[位] = Object.assign(this.当前指令(位), 补丁);
    this.提示 = '';
    /* ★ 把开关同步给引擎（`60-战斗.js` 的 `设单位开关()`）：TRANS-AM 的开关要**立刻**反映到
       单位卡那一行 / 那个按钮上（不然得等点「开打 ▶」才更新）。`设单位开关()` 只写开关类字段，
       不动任何战斗状态；「开打」时还会再同步一次，两处一致。 */
    if (this.ctx) 设单位开关(this.ctx, this.单位开关);
    this.刷();
    return this.单位开关[位];
  },
  选单位(位) {
    if (this.阶段 !== '指令') return false;
    this.选中位 = this.选中位 === 位 ? null : 位;
    this.选目标 = false; this.提示 = '';
    this.刷();
    return this.选中位;
  },
  /** 全队层：选一条全军方针。**保持到改为止**（存在 `界面.方针`，回合之间不重置）。
   *  选「集中攻击」→ 进入「点敌人选目标」状态（**没点目标时不让开打**，`开打()` 会拦）。
   *  ★ 引擎那一侧「集中攻击没有目标位」会被 `设方针()` 当成全军突击（§1.6），
   *    所以这里的 `ctx.方针` 只在**真的有点到目标**时才写成集中攻击 —— 免得「界面写集中攻击、
   *    引擎在突击」两套话；没点目标时 `界面.方针` 照样记着玩家想选它（方针栏高亮 + 提示要点目标）。 */
  选方针(类型) {
    if (this.阶段 !== '指令') return false;
    if (!方针们.includes(类型)) { this.提示 = `认不出来的方针：${类型}。`; this.刷(); return false; }
    this.方针 = { 类型, 目标位: 类型 === '集中攻击' ? this.方针.目标位 : null };
    this.选目标 = (类型 === '集中攻击' && this.方针.目标位 == null);
    this.提示 = '';
    if (this.ctx) {
      if (类型 === '集中攻击' && this.方针.目标位 == null) this.ctx.方针 = { 类型: '全军突击', 目标位: null };
      else 设方针(this.ctx, this.方针);
    }
    this.刷();
    return this.方针;
  },
  /** 「集中攻击」的目标：点一张敌方卡片。只有方针是集中攻击时才吃这一下（§1.7）。 */
  点敌人(位) {
    if (this.阶段 !== '指令') return false;
    if (this.方针.类型 !== '集中攻击') return false;
    const 目标 = this.ctx.enemies.find(x => x.slot === 位);
    if (!目标 || 目标.hp <= 0) return false;
    this.选目标 = false;
    this.方针 = { 类型: '集中攻击', 目标位: 位 };
    this.提示 = '';
    if (this.ctx) 设方针(this.ctx, this.方针);
    this.刷();
    return this.方针;
  },
  切大招(位) {
    const c = this.当前指令(位);
    return this.设某开关(位, { 保留大招: !c.保留大招 });
  },
  /* ★ TRANS-AM 的单位级开关（作者 2026-10-11 拍板「TRANS-AM 应该是单个单位开关的」；
     2026-10-12 起它和「大招：自动 / 保留」一起构成**单位层的全部**决策，§1.1）：
     ① `切TRANSAM(位)`：在「自动 / 手动」之间切（存开关表，逐回合保留；切回自动时清掉本回合那次点击）；
     ② `开TRANSAM(位)`：手动档下**本回合点开**——CD 没到（或在 TRANS-AM 中 / 等级不够 / 没有这个能力）
        点了一点用都没有（返回 false + 写一句提示），界面上那个按钮这时本来就是 `disabled`。 */
  切TRANSAM(位) {
    if (this.阶段 !== '指令') return false;
    const u = this.ctx.allies.find(x => x.slot === 位);
    if (!u || !有TRANSAM(u, 天人参数())) { this.提示 = '这台机体没有 TRANS-AM。'; this.刷(); return false; }
    const c = this.当前指令(位);
    const 新 = c.TRANSAM === '手动' ? '自动' : '手动';
    return this.设某开关(位, { TRANSAM: 新, 本回合开TRANSAM: 新 === '手动' ? c.本回合开TRANSAM : false });
  },
  开TRANSAM(位) {
    if (this.阶段 !== '指令') return false;
    const u = this.ctx.allies.find(x => x.slot === 位);
    if (!u) return false;
    const c = this.当前指令(位);
    if (c.TRANSAM !== '手动') {
      this.提示 = '这台是「自动」档：CD 一到会在回合开始自己开，不用点（要自己掌握就先切成「手动」）。';
      this.刷(); return false;
    }
    const 判 = 天人手动可开(u, 天人参数());
    if (!判.可以) { this.提示 = `开不了：${判.原因}`; this.刷(); return false; }   // ★ CD 没到 → 点了也无效
    return this.设某开关(位, { 本回合开TRANSAM: true });
  },

  /* ---------------- 肉鸽：把 92-肉鸽界面.js 的画面接进来 ----------------
   *  ★ 2026-10-11「界面体验修复」：肉鸽里的**每一个动作**都改走
   *    `肉鸽界面.设结果(类型, 文本)`（＝ 顶部结果条 **＋** 同一句话进 `RUN.日志`）——
   *    类型四个：`成功 / 警告 / 失败 / 信息`。口径（清空时机 / 条数上限）在 `92-肉鸽界面.js` 顶上。 */
  分队屏() { return 肉鸽界面.分队屏(); },
  大地图屏() { return 肉鸽界面.大地图屏(); },
  招募屏() { return 肉鸽界面.招募屏(); },
  奇遇屏() { return 肉鸽界面.奇遇屏(); },
  黑市屏() { return 肉鸽界面.黑市屏(); },
  晋升屏() { return 肉鸽界面.晋升屏(); },
  零件屏() { return 肉鸽界面.零件屏(); },
  肉鸽结算屏() { return 肉鸽界面.肉鸽结算屏(); },
  记录屏() { return 肉鸽界面.记录屏(); },

  选分队(名) { 肉鸽界面.分队ID = 名; 肉鸽界面.清结果(); this.刷(); return 名; },
  /** 进「选分队」屏 = **新的一局从这一刻开始**：把上一局的结果条清掉
   *  （★ 2026-10-11 清空时机 ② 的落点 —— 不然上一局的「招到…」会挂在选分队屏上，
   *   而这一屏现在不画结果条：`92-肉鸽界面.js` 的 `分队屏()` 不放 `结果条Html()`）。 */
  去分队() { 肉鸽界面.清结果(); this.开屏('分队'); return true; },
  /** 开新的一局。`种子` **可选，只给测试用**：
   *    界面上的按钮不传（`data-act="开新局"`）→ `肉鸽.新的一局()` 照旧用 `Date.now()` 现取一个；
   *    测试写 `界面.动作('开新局:20261010')` → 这一局的种子被钉死，**同一局每次逐字一样**
   *    （方案 6.1 的硬规矩；`肉鸽.新的一局(分队, 种子)` 本来就收种子，这里只是把它接出来）。
   *    为什么要有它：`tests/run.js` 原来靠 `Date.now()`，个别种子下第 5 段那场终点守军会打输
   *    （实测约 1/30–1/90，纯 HEAD 上同样复现）→ 测试偶发红。 */
  开新局(种子) {
    if (!肉鸽界面.分队ID) { 肉鸽界面.设结果('失败', '先挑一个分队。'); this.刷(); return false; }
    肉鸽.新的一局(肉鸽界面.分队ID, 种子 == null || 种子 === '' ? undefined : Number(种子));
    /* ★ 2026-10-11 作者拍板（任务书 §8 附）：发完 3 张券**立刻进招募流程** ——
       照战棋 `27-开局.js:50` 的「选完分队 → 依次弹券对话框」；我们落在**招募屏**（最直观，
       券也可以先留着，下次在大地图上再点「去招募」）。 */
    肉鸽界面.选中的券 = null;
    /* ★ 2026-10-11：新的一局 → 结果条与上一场战斗的奖励清单都清掉（不跨局）。 */
    肉鸽界面.清结果();
    肉鸽界面.战斗结算 = null;
    this.开屏('招募');
    return true;
  },
  继续上一局() {
    const R = 肉鸽.读存档();
    if (!R) { this.开屏('菜单'); return false; }
    肉鸽界面.清结果();
    肉鸽界面.战斗结算 = null;
    this.开屏('大地图');
    return true;
  },
  /* ---------------- 肉鸽：网格大地图上的移动与节点（作者 2026-10-10：换成网格 + 推进剂） ----------------
     走到一格之后按**节点类型**决定开哪个屏，返回的是**节点类型字符串**（老的 `去节点(id)` 也是这个约定）：
       作战 / 精英 / 侵蚀源 / 出口守军 → 先进编队屏（摆好阵再点「开战」）；
       招募站 / 事件 / 黑市 → 开对应的屏；
       瞭望站 / 遗迹 / 隧道 / 休整 → 走弹窗（`肉鸽弹窗`），结算完回大地图；
       出口 → 守军没清就先指路，清了就下一层（第 4 层 = 通关）。 */
  去节点(参) {
    const k = Number(参);
    /* 正在用零件：这一下不是普通移动，而是「把零件用在这一格上」（不花推进剂，见 94-零件.js） */
    const 走 = (肉鸽界面.用零件中 != null) ? this.用零件走到(k) : 肉鸽.移动(k);
    if (!走) { 肉鸽界面.设结果('失败', `走不过去：这一格到不了，或者推进剂不够（现在 ${肉鸽.RUN ? 肉鸽.RUN.推进剂 : 0}）。`); this.刷(); return null; }
    /* ★ 2026-10-11：以前这里写 `提示 = ''` —— 玩家一结算回来就被清掉，「结果没有提示」多半就是这条引起的。
       现在**不清**：走一格不产生新结果，顶部那条结果要留到下一次结算（口径 ⑤ 写在 92-肉鸽界面.js 顶上）。 */
    const 类型 = 走.类型;
    if (走.已过) { this.刷(); return 类型; }                    // 走过的空格：只挪位置
    if (['作战', '精英', '侵蚀源', '出口守军'].includes(类型)) {
      /* ★ 侵蚀源：先弹「硬闯 / 花源碳净化」（照抄原作「理念在进入节点时生效」的口径）——
         在编队屏之前就付掉，所以玩家在编队时已经知道自己面对的是哪一种。 */
      if (类型 === '侵蚀源' && !肉鸽.侵蚀源代价()) {
        if (!this.试着侵蚀源代价()) return 类型;
      }
      this.准备肉鸽编队(); return 类型;
    }
    if (类型 === '招募站') {
      /* ★ 2026-10-11 招募券：招募站给 1 张随机券（照战棋 `30-移动与节点.js:63-67`，
         每个招募站格只给一次）。**先给券、再开招募屏** —— 玩家能在招募屏上马上用掉它，
         也可以留着（券随时可用）。这里用 `肉鸽.招募站领券()`，重复进站不会重复给。 */
      const 领 = 肉鸽.招募站领券();
      if (领 && 领.ok && !领.重复 && 领.券) 肉鸽界面.设结果('成功', `招募站：获得【${领.券名}】（手上一共 ${肉鸽.RUN.券.length} 张券）`);
      else if (领 && 领.ok && 领.重复) 肉鸽界面.设结果('信息', '这个招募站的券已经领过了。');
      肉鸽界面.选中的券 = null;
      this.开屏('招募');
      return 类型;
    }
    if (类型 === '事件') { this.开屏('奇遇'); return 类型; }
    if (类型 === '黑市') { this.开屏('黑市'); return 类型; }
    if (类型 === '瞭望站') { this.去瞭望(); return 类型; }
    if (类型 === '遗迹') { this.去遗迹(); return 类型; }
    if (类型 === '隧道') { this.穿隧道(); return 类型; }
    if (类型 === '休整') { this.休整(); return 类型; }
    if (出口类型表[类型]) { this.前进(出口类型表[类型]); return 类型; }
    this.刷();
    return 类型;
  },
  /** 打这一场（战斗节点 / 出口守军 / 侵蚀源 / 追击战都走这里） */
  打这一场() {
    if (!肉鸽.进行中) return false;
    const R = 肉鸽.RUN;
    const 格 = 肉鸽.当前格();
    const 格类型 = this.肉鸽战斗类型 || (格 ? 格.类型 : '作战');
    /* ★ 2026-10-11 第 9 条：**侵蚀源先付代价**才让打（硬闯 = 敌方 +15% / 净化 = 花 8 源碳）。
       它是**同步弹窗**，没选完就不进战斗（`试着` 返回 false = 已经切回大地图）。 */
    if (格类型 === '侵蚀源' && !肉鸽.侵蚀源代价()) {
      const 选了 = this.试着侵蚀源代价();
      if (!选了) { this.肉鸽战斗类型 = '作战'; return false; }
    }
    this.肉鸽战斗类型 = '作战';            // 读掉就用掉：下一场默认回到「这一格的类型」
    /* 抽编成：`抽当前编成详情()` 里带着**兜底**（70-编成.js 的 `抽编成兜底()`：某层某类型没编成
       就退回同层「普通」…，并往 RUN.日志 写一行），所以下面这个 `!条目` 只在**编成表整张空**时成立。 */
    const 详情 = 肉鸽.抽当前编成详情(格类型);
    const 条目 = 详情 && 详情.条目;
    if (!条目) { 肉鸽界面.设结果('失败', `第 ${R.层} 层没有「${肉鸽.当前战斗类型(格类型)}」的编成，写进编成表再打。`); this.开屏('大地图'); return false; }
    /* 出击名单：优先用编队界面摆好的阵（RUN.出击阵 = [{键, 位}]），没有就用名册前几台
       （台数上限 = 肉鸽.出击上限()，作者 2026-10-10 第二次拍板：按肉鸽等级，Lv1 起 3 台） */
    const 阵 = (R.出击阵 && R.出击阵.length) ? R.出击阵 : R.队伍.slice(0, 肉鸽.出击上限()).map((m, i) => ({ 键: m.键, 位: i }));
    const 等级 = 键 => { const m = R.队伍.find(x => x.键 === 键); return (m && m.等级) || 肉鸽数值.招募等级; };
    /* ★ HP 继承（作者 2026-10-11：「同一次出击的队伍带着伤打下一场」）：
       名册上这一台现在还剩下多少血（**比例**，0–1）→ 交给 `makeUnits` 的开场 HP。
       `肉鸽.名册HP比()` 在没有 RUN / 关掉开关时返回 `null` = 满血，与改前逐字相同；
       这一条是**唯一**会传 HP 比例的地方（菜单固定战斗 / simulate / 平衡工具 / 测试都不经过这里）。 */
    const 我方 = 阵.map(x => ({ 键: x.键, 位: x.位, 等级: 等级(x.键), hp: 肉鸽.名册HP比(x.键) }));
    const 敌方 = 敌方规格组(编成到单位(条目, R.场次));
    this.肉鸽编队模式 = false;
    this.种子 = (R.种子 + R.层 * 131 + R.场次 * 17 + (格 ? 格.k : 0) * 7) >>> 0;
    this.肉鸽战斗 = { 格类型, 类型: 详情.类型, 条目, 兜底: 详情.兜底, 请求类型: 肉鸽.当前战斗类型(格类型), 波次: 肉鸽.增援波次(条目) };
    this.ctx = 开局(我方, 敌方, this.种子, null, { 波次: this.肉鸽战斗.波次 });
    /* ★ 2026-10-11 节点改造第 9 条：**侵蚀源「先付代价」**（★ 作者交代：不要改名，只补代价）。
       玩家在 `去节点` 弹出的「硬闯 / 花 8 源碳买净化」里选了硬闯 → 这一场敌方全体攻防 +15%。
       实现落点放在**界面这一层**（不改编成表、不动战斗内核）：开局之后按 `RUN.侵蚀源已净化` 现加。
       只改 enemy 单位自己的属性（`dmgCore` 读的就是这些字段），所以没有「额外改引擎」的风险；
       没选过 / 选的是净化 → `侵蚀源敌方加成()` 返回 0，这一段什么都不做（与改前逐字相同）。 */
    const 强攻 = (格类型 === '侵蚀源') ? 肉鸽.侵蚀源敌方加成() : 0;
    if (强攻 > 0) {
      const 倍 = 1 + 强攻;
      for (const u of this.ctx.enemies) {
        u.armor = Math.round(u.armor * 倍);
        u.defense = Math.round(u.defense * 倍);
        u.melee = Math.round(u.melee * 倍);
        u.shoot = Math.round(u.shoot * 倍);
      }
      肉鸽.记(`侵蚀源（硬闯）：本场敌方全体攻防 +${Math.round(强攻 * 100)}%（×${倍}，${this.ctx.enemies.length} 台）`);
    }
    this.单位开关 = {};
    this.选中位 = null; this.选目标 = false; this.提示 = '';
    this.显示单位 = null; this.战报 = null;
    this.阶段 = '指令';
    this.开屏('战斗');
    return this.ctx;
  },
  /** 侵蚀源：**先付代价**再打（★ 第 9 条；★ 作者交代「不要改名」，所以名字没动）。
   *  两个选项互斥（照方案书 §3.3）：`硬闯`（敌方全体 +15% 攻防【初稿】）/ `净化`（花 8 源碳【初稿】）。
   *  返回 true = 选好了、可以开打；false = 没选 / 源碳不够（已经切回大地图）。 */
  试着侵蚀源代价() {
    const R = 肉鸽.RUN;
    if (!R) return false;
    const 做 = 答案 => {
      if (!答案) { 肉鸽界面.设结果('警告', '还没有打定主意：侵蚀源要先付代价才让打。'); return false; }
      const r = 肉鸽.结算侵蚀源代价(答案 === '净化' ? '净化' : '硬闯');
      if (!r || !r.ok) { 肉鸽界面.设结果('失败', (r && r.why) || '代价付不了。'); return false; }
      肉鸽界面.设结果('警告', r.选 === '净化'
        ? `侵蚀源：花 ${r.花源碳} 源碳净化，这一场正常打（剩 ${R.源碳}）。`
        : `侵蚀源：硬闯 —— 这一场敌方全体攻防 +${Math.round(r.敌方加成 * 100)}%【初稿】。`);
      return true;
    };
    const 选 = 肉鸽弹窗('侵蚀源（这一格要先付代价）',
      `源碳结晶 ${R.源碳}。原作里的「侵蚀」是环境异变（实托邦那类负面），不是一个白送奖励的格子 —— ` +
      `所以这里两条互斥的路，选完才开打：`, [
      ['硬闯', `硬闯：这一场敌方全体攻防 +${Math.round(肉鸽数值.侵蚀源强攻加成 * 100)}%（【初稿】），不花源碳`],
      ['净化', `花 ${肉鸽数值.侵蚀源净化价} 源碳结晶买净化：这一场正常打（${R.源碳 < 肉鸽数值.侵蚀源净化价 ? '源碳不够' : `剩 ${R.源碳 - 肉鸽数值.侵蚀源净化价}`}）`],
    ], 做);
    if (选 !== true) { this.开屏('大地图'); return false; }
    return true;
  },
  /** 肉鸽：进战斗前先编队（方案 8.1 的第 3 条）——候选项是名册，摆进 9 格阵型（前 4 后 5） */
  准备肉鸽编队() {
    const R = 肉鸽.RUN;
    if (!R) return false;
    const 格 = 肉鸽.当前格();
    this.肉鸽编队模式 = true;
    this.肉鸽战斗类型 = 格 ? 格.类型 : '作战';
    this.编队.选中 = null;
    this.编队.出击 = (R.出击阵 && R.出击阵.length ? R.出击阵 : R.队伍.slice(0, 肉鸽.出击上限()).map((m, i) => ({ 键: m.键, 位: i })))
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
  /** 招募一位机师。
   *  ★ 2026-10-11 券系统：把**当前选中的券**传下去（`肉鸽界面.选中的券`）——
   *  持券时那张券必须和这位机师对得上（`90-肉鸽.js` 的 `招募()` 里判），**券与希望同时消耗**；
   *  没选券 → 和改前逐字一样（只花希望）。 */
  招募(键) {
    const R = 肉鸽.RUN;
    if (!R) return false;
    if (R.队伍.length >= 肉鸽数值.队伍上限) { 肉鸽界面.设结果('失败', `队伍已经满了（${肉鸽数值.队伍上限} 台）。`); this.开屏('招募'); return false; }
    if (R.队伍.some(m => m.键 === 键)) { 肉鸽界面.设结果('失败', '这位机师已经在队里了。'); this.开屏('招募'); return false; }
    const 券下标 = (肉鸽界面.选中的券 != null && (R.券 || [])[肉鸽界面.选中的券]) ? 肉鸽界面.选中的券 : -1;
    const r = 肉鸽.招募(键, 券下标 >= 0 ? 券下标 : undefined);   // 内部会 节点完成()（含存档）
    if (!r || !r.ok) { 肉鸽界面.设结果('失败', (r && r.why) || '招不了。'); this.开屏('招募'); return false; }
    /* ★ 2026-10-11：把「花了多少希望 / 用掉哪张券 / 现在队里几台」写全（作者要的「明确反馈」）。 */
    肉鸽界面.设结果('成功', `招到 ${键}（Lv${肉鸽数值.招募等级}，花希望 ${r.费}${r.券名 ? `，用掉一张 ${r.券名}` : '，没用券'}；` +
      `剩 ${R.希望} 希望，队里 ${R.队伍.length} / ${肉鸽数值.队伍上限} 台）。`);
    /* 用掉一张券之后，手上所有券的下标都会往前挪 → 选中状态一律清掉，避免指到别人身上。 */
    if (r.用券) 肉鸽界面.选中的券 = null;
    this.开屏('招募');
    return true;
  },
  /** 选中 / 取消选中手上的第 N 张券（招募屏那一段）。返回选中的下标或 `null`。 */
  用券(i) {
    const R = 肉鸽.RUN;
    if (!R) return null;
    const 们 = R.券 || [];
    if (!(i >= 0 && i < 们.length)) { 肉鸽界面.设结果('失败', '这张券不在手上了。'); this.开屏('招募'); return null; }
    if (肉鸽界面.选中的券 === i) { 肉鸽界面.选中的券 = null; 肉鸽界面.设结果('信息', `取消选中：${券名(们[i])} 先留着。`); }
    else { 肉鸽界面.选中的券 = i; 肉鸽界面.设结果('信息', `选中 ${券名(们[i])}：候选池只留对得上的机师（招完这张券就用掉了）。`); }
    this.开屏('招募');
    return 肉鸽界面.选中的券;
  },
  /** 丢弃一张券（照战棋 `27:82` 的「丢弃这张券」；只写日志、不退不换）。 */
  丢券(参) {
    const r = 肉鸽.丢券(参);
    /* ★ 2026-10-11：丢券也要说清「丢掉的是哪一张、还剩几张」（失败给原因）。 */
    if (!r || !r.ok) 肉鸽界面.设结果('失败', (r && r.why) || '丢不了。');
    else 肉鸽界面.设结果('警告', `丢掉了一张 ${券名(r.券)}，手上还剩 ${r.剩} 张。`);
    肉鸽界面.选中的券 = null;
    this.开屏('招募');
    return r;
  },
  /* ---------------- 新节点的界面（7 种：黑市 / 瞭望站 / 隧道 / 遗迹 / 休整 / 出口守军 / 侵蚀源） ---------------- */
  黑市买(id) {
    const r = 肉鸽.黑市买(id);
    if (!r || !r.ok) 肉鸽界面.设结果('失败', (r && r.why) || '买不了。');
    else 肉鸽界面.设结果('成功', `买下了【${r.名}】（−${r.价} 源碳，剩 ${肉鸽.RUN.源碳} 源碳，藏品 ${肉鸽.RUN.藏品.length} 件）。`);
    this.开屏('黑市');
    return r;
  },
  黑市离开() { 肉鸽.黑市离开(); this.开屏('大地图'); return true; },
  /** 刷新黑市库存（★ 第 4 条：初始 4 源碳、每次 +4、每格最多 4 次 —— 照抄原作诡意行商）。 */
  黑市刷新() {
    const r = 肉鸽.黑市刷新();
    肉鸽界面.设结果(!r || !r.ok ? '失败' : '成功', (!r || !r.ok) ? ((r && r.why) || '刷不了。')
      : `花 ${r.价} 源碳刷新（第 ${r.次} / ${肉鸽数值.黑市刷新上限} 次）：摆出 ${r.货.length} 件` +
        `${r.下次价 != null ? `，下次要 ${r.下次价}` : '，这一格刷满了'}（剩 ${肉鸽.RUN.源碳} 源碳）。`);
    this.开屏('黑市');
    return r;
  },
  /** 卖零件（★ 第 4 条：把 `94-零件.js` 里早写好的 `卖零件()` 接上界面）。 */
  黑市卖零件(i) {
    const r = 肉鸽.黑市卖零件(Number(i));
    肉鸽界面.设结果(!r || !r.ok ? '失败' : '成功', (!r || !r.ok) ? ((r && r.why) || '卖不了。')
      : `卖出零件【${r.名}】+${r.价} 源碳（现在 ${r.源碳} 源碳，零件箱 ${(肉鸽.RUN.零件 || []).length} 件）。`);
    this.开屏('黑市');
    return r;
  },

  /* ---------------- 晋升（10 → 20 → 30） ----------------
     照战棋 `29-渲染.js:62-70`：点一下名册上的「→Lv20（N）」就升，扣希望、写日志、进存档。
     升完**留在晋升屏**（战棋也是留在队伍卡片上），提示里贴出晋升前后的数字。
     ★ 2026-10-11 券系统：`肉鸽.晋升()` 还要**用掉一张同类券**（找不到就直接拒绝、希望一分不扣），
       提示里把「用掉哪张券」写出来。 */
  去晋升() { 肉鸽界面.清结果(); this.开屏('晋升'); return true; },
  晋升(键) {
    const r = 肉鸽.晋升(键);
    if (!r || !r.ok) {
      肉鸽界面.设结果('失败', (r && r.why) || '升不了。');
    } else {
      肉鸽界面.设结果('成功', `${r.名} 晋升到 Lv${r.到}（−${r.价} 希望，剩 ${r.希望}；用掉一张 ${r.券名}）：` +
        `HP ${r.前.maxHp} → ${r.后.maxHp}、装甲 ${r.前.armor} → ${r.后.armor}、` +
        `防御 ${r.前.defense} → ${r.后.defense}、机动 ${r.前.mov} → ${r.后.mov}、速度 ${r.前.速度} → ${r.后.速度}`);
    }
    this.开屏('晋升');
    return r;
  },

  /* ---------------- 零件（大地图上用的那几个） ----------------
     点「使用」→ 记下下标 → 回大地图 → 点高亮的格子（`去节点` 会先问 `用零件走到`）。 */
  去零件() {
    /* 进零件屏 = 取消「正在用零件」（不然从零件屏走开时那件零件还挂着） */
    肉鸽界面.用零件中 = null;
    this.开屏('零件');
    return true;
  },
  使用零件(i) {
    const R = 肉鸽.RUN;
    if (!R) return false;
    if (肉鸽界面.用零件中 === i) {                  // 再点一次 = 取消
      肉鸽界面.用零件中 = null;
      肉鸽界面.设结果('信息', '取消使用零件。');
      this.开屏('零件');
      return true;
    }
    const p = (R.零件 || [])[i];
    if (!p) { 肉鸽界面.设结果('失败', '没有这件零件。'); this.开屏('零件'); return false; }
    const P = 零件表[p.k] || { 名: p.k };
    const 目标 = 零件目标(p);
    if (!目标.length) { 肉鸽界面.设结果('失败', `【${P.名}】现在没有能去的格子（换一层或者换一件）。`); this.开屏('零件'); return false; }
    肉鸽界面.用零件中 = i;
    肉鸽界面.设结果('信息', `正在使用【${P.名}】：点大地图上高亮的 ${目标.length} 个格子之一（不花推进剂）。`);
    this.开屏('大地图');
    return true;
  },
  /** 用零件走一格（`去节点` 在「用零件中」时调它）：用掉之后接着按节点类型结算，
   *  结算完的回程和普通移动一样（推进剂为 0 就触发追击战，照战棋 `30:34`）。 */
  用零件走到(k) {
    const R = 肉鸽.RUN;
    if (!R) return null;
    const i = 肉鸽界面.用零件中;
    const r = 用零件(i, k);
    if (!r || !r.ok) { 肉鸽界面.设结果('失败', (r && r.why) || '用不了这件零件。'); return null; }
    肉鸽界面.用零件中 = null;
    const 格 = R.地图.格[r.到];
    肉鸽界面.设结果('成功', `零件【${r.零件}】用掉了：到了 (${格.列 + 1}, ${格.行 + 1})（${(节点类型表[格.类型] || {}).名 || 格.类型}），没花推进剂（剩 ${R.推进剂} 点）。`);
    return { 格, 类型: 格.类型, 距离: r.距离, 追击: R.推进剂 <= 0, 已过: 格.已过 || 格.类型 === '空', 从: r.从, 零件: r.零件 };
  },

  去瞭望() {
    /* ★ 2026-10-11 节点改造第 6 条：瞭望站**只给视野**（删掉原来的「希望 +3」），两选一 ——
     *   出处 = 原作「羽瞰点」（方案书 §3.6 逐字）：远眺 4 格 / 登高 12 格 +1 行动力。 */
    const R = 肉鸽.RUN;
    const 做 = 答案 => {
      const r = 肉鸽.结算瞭望站(答案);
      if (r) 肉鸽界面.设结果('信息', `瞭望站（${r.选}）：揭开周围 ${r.半径} 格（本次新揭开 ${r.揭开} 格）` +
        `${r.选 === '登高' ? `、推进剂 ${r.推进剂}` : '、不给推进剂也不给希望'}。`);
      this.开屏('大地图');
      return r;
    };
    if (!R) return null;
    return 肉鸽弹窗('瞭望站', `推进剂 ${R.推进剂}。原作「羽瞰点」：出现时只揭示周围 4 格；走到它上面再扩大范围。`, [
      ['远眺', `只远眺：揭开周围 ${肉鸽数值.瞭望站远眺} 格（不给推进剂、不给希望）`],
      ['登高', `登上去：揭开周围 ${肉鸽数值.瞭望站登高} 格，并获得 ${肉鸽数值.瞭望站推进剂} 推进剂`],
    ], 做);
  },
  /** 遗迹（★ 第 7 条：**三选一**，照抄黑流树海「沉寂之屋」，删掉「50% 送藏品」）。
   *  出处：方案书 §3.7 逐字 —— 清理藤蔓 = 消耗 2 目标生命值 / 交流 = 消耗 8 源石锭 / 离开。 */
  去遗迹() {
    const R = 肉鸽.RUN;
    if (!R) return null;
    const 做 = 答案 => {
      const r = 肉鸽.结算遗迹(答案);
      if (r && r.ok === false) 肉鸽界面.设结果('失败', r.why);
      else if (r) 肉鸽界面.设结果(r.选 === '离开' ? '信息' : '成功',
        `遗迹（${r.选 === '藤蔓' ? '清理门口的藤蔓' : r.选 === '交流' ? '试着和它交流' : '离开'}）：` +
        `${r.选 === '离开' ? '什么也没拿' : `源碳 +${r.源碳}${r.零件 ? `、零件【${r.零件.名}】` : '（零件箱满了）'}（作战耐久 ${R.耐久}、源碳 ${R.源碳}）`}。`);
      this.开屏('大地图');
      return r;
    };
    return 肉鸽弹窗('遗迹',
      `一座残破的古代遗迹。源碳 ${R.源碳}、作战耐久 ${R.耐久}。照抄黑流树海「沉寂之屋」的三条路：`, [
      ['藤蔓', `清理门口的藤蔓：消耗 ${肉鸽数值.遗迹耐久价} 作战耐久 → 拿到零件 + 源碳 ${肉鸽数值.遗迹源碳}`],
      ['交流', `试着和它交流：消耗 ${肉鸽数值.遗迹源碳价} 源碳 → 拿到零件 + 源碳 ${肉鸽数值.遗迹源碳}`],
      ['离开', '离开（什么都没有）'],
    ], 做);
  },
  /** 隧道：弹窗问一句（**同步**版 —— 弹窗的答案通过 `肉鸽弹窗(标题, 文本, 选项, 回调)` 回填，
   *  这样「点一下 → 传送 → 回大地图」是同一个调用里做完的，测试不用等 Promise）。
   *  ★ 2026-10-11 第 9 条：**进入要花 1 点推进剂**（照抄原作「行动力只在进入时被消耗」）。 */
  穿隧道() {
    const R = 肉鸽.RUN;
    if (!R) return null;
    const 到 = 肉鸽.隧道另一头();
    const 花费 = 肉鸽数值.隧道花费;
    const 做 = 答案 => {
      if (答案 === 'go') {
        const r = 肉鸽.结算隧道();
        if (!r || r.ok === false) {
          肉鸽界面.设结果('失败', (r && r.why) || '传不过去。');
        } else {
          肉鸽界面.设结果('成功', `穿过隧道（花 ${花费} 推进剂，剩 ${R.推进剂}），到了 ${坐标文字(R.地图.格[r.到])}。`);
        }
        this.开屏('大地图');
        return r;
      }
      肉鸽界面.设结果('信息', '留在了隧道这一头。');
      this.开屏('大地图');
      return null;
    };
    if (到 == null) return 做('no');
    const 够 = 肉鸽.隧道花费() != null;
    return 肉鸽弹窗('废弃隧道',
      `隧道另一端在 ${坐标文字(R.地图.格[到])}（${节点类型表[R.地图.格[到].类型].名}）。` +
      `进隧道要花 <b>${花费}</b> 点推进剂（照抄原作「行动力只在进入时被消耗」）—— 现在有 ${R.推进剂}。`,
      [['go', 够 ? `传送过去（−${花费} 推进剂）` : `推进剂不够（要 ${花费}，只有 ${R.推进剂}）`], ['no', '留在这里']], 做);
  },
  /** 休整（★ 第 8 条：**互斥三选一**，拿一个就结束；删掉「花希望买耐久」与「跳过」）。
   *  照抄原作战棋 `30:58-61`（耐久 +2 / 下次晋升 −1）+ 原作「安全的角落」的「2 行动力」（方案书 §3.8）。
   *  同步版同上（弹窗的答案通过 `肉鸽弹窗(标题, 文本, 选项, 回调)` 回填）。 */
  休整(参) {
    const R = 肉鸽.RUN;
    if (!R) return null;
    if (R.层 <= 1) {
      肉鸽界面.设结果('失败', '第 1 层没有休整（照抄原作「安全的角落」：※该节点不会在第 Ⅰ 层出现）。');
      this.开屏('大地图');
      return false;
    }
    const 做 = 答案 => {
      const r = 肉鸽.结算休整(答案);
      肉鸽界面.设结果((r && r.ok === false) ? '失败' : '成功', (r && r.ok === false) ? r.why
        : `休整完了（${r.选}）：作战耐久 ${肉鸽.RUN.耐久}、希望 ${肉鸽.RUN.希望}、推进剂 ${肉鸽.RUN.推进剂}` +
          `${肉鸽.RUN.下次晋升减价 ? '（下次晋升 −1 希望）' : ''}。`);
      this.开屏('大地图');
      return r;
    };
    if (参) return 做(参);
    return 肉鸽弹窗('休整', `作战耐久 ${R.耐久}、希望 ${R.希望}、推进剂 ${R.推进剂}。<b>三选一</b>（拿一个就结束）：`, [
      ['耐久', `坐下休息：作战耐久 +${肉鸽数值.休整耐久}（战棋 30:60）`],
      ['晋升', '放弃休息：下次晋升 −1 希望（战棋 30:60）'],
      ['推进剂', `把这一格让出来：推进剂 +${肉鸽数值.休整推进剂}（原作「安全的角落」的 2 行动力）`],
    ], 做);
  },
  /** 「跳过」：不结算，直接离开这一格（隧道 / 休整这类想反悔的节点） */
  跳过节点() { 肉鸽.节点完成(); this.开屏('大地图'); return true; },
  /** 出口：守军没清就先指路；清了就**二选一**换层（第 4 层 = 通关）；
   *  推进剂归零时先在出口这一格打一场追击战（战棋 30:34「结算完再判 prop <= 0」），打完再换层。
   *  ★ 2026-10-11 节点改造第 1、2 条（作者拍板，照抄黑流树海「险路尽头 / 险路小径」）：
   *    · `前进:尽头` → 剩余推进剂 1:1 换希望；`前进:小径` → 下一层推进剂上限 +1；
   *    · 不传参数（老调用点 / 测试）→ 默认**尽头**（老行为是「剩余推进剂白扔」，现在至少换成希望）。 */
  前进(参) {
    const R = 肉鸽.RUN;
    if (!R) return false;
    const 守 = R.地图.格[R.地图.守军];
    if (守 && !守.已过 && 守.类型 !== '空') {
      肉鸽界面.设结果('警告', '出口被守军挡着：先走到 ⇛ 守军那一格把它打掉。');
      this.开屏('大地图');
      return false;
    }
    /* 出口类型：显式传的优先，否则看脚下这一格（玩家点的是尽头还是小径的格子） */
    const 脚下 = 肉鸽.当前格();
    const 类型 = (参 === '尽头' || 参 === '小径') ? 参
      : (脚下 && 出口类型表[脚下.类型]) || '尽头';
    if (R.层 < 4) 肉鸽.选出口(类型);
    if (R.推进剂 <= 0 && !R.追击) {
      this.肉鸽战斗类型 = '追击';
      肉鸽界面.设结果('警告', '推进剂用光了 —— 追兵到了，打一场追击战，赢了才出得去。');
      const 层前 = R.层;
      const 打 = this.打这一场();
      /* ★ 追击战自己就会换层（`90-肉鸽.js` 的 `追击之后()` → `换层()`，战棋 31:300 的 chase 分支），
         所以这里**必须**提前收工 —— 否则下面那句 `肉鸽.下一层()` 会**连换两层**，
         第 4 层那一下还会把已经写好的「通关」覆盖成「失败」。 */
      if (!肉鸽.进行中 || R.结局 || R.层 !== 层前) {
        if (R.结局) this.开屏('肉鸽结算');
        return 打;
      }
    }
    const 之前 = R.层;
    const 希望前 = R.希望, 推进剂前 = R.推进剂;
    肉鸽.下一层();
    if (!肉鸽.进行中 || R.结局) { this.开屏('肉鸽结算'); return true; }
    if (之前 !== R.层) {
      /* ★ 换层是「清结果」的时机之一（口径 ①）—— 上一层的账翻篇了，结果条从这一层重新开始记。 */
      肉鸽界面.清结果();
      肉鸽界面.设结果('信息', 类型 === '小径'
        ? `走了出口小径：第 ${R.层} 层推进剂上限 ${推进剂上限(R)}（+${肉鸽数值.出口小径加成}【初稿】）。`
        : `走了出口尽头：剩余推进剂 ${推进剂前} → 希望 +${R.希望 - 希望前}（现在 ${R.希望}）；进入第 ${R.层} 层（推进剂 ${R.推进剂}）。`);
    }
    this.开屏('大地图');
    return 之前 !== R.层;
  },
  /** 追击战：推进剂用光之后强制打一场（战棋 31:304-307） */
  追击战() {
    const R = 肉鸽.RUN;
    if (!R || !肉鸽.进行中) return false;
    this.肉鸽战斗类型 = '追击';
    肉鸽界面.设结果('警告', '推进剂用光了 —— 追兵到了，打一场追击战！');
    return this.打这一场();
  },
  领补给() { 肉鸽.补给(); 肉鸽界面.设结果('成功', `补给：源碳 +${肉鸽数值.补给源碳}（现在 ${肉鸽.RUN ? 肉鸽.RUN.源碳 : 0}）。`); this.开屏('大地图'); return true; },
  /** 事件（★ 第 5 条）：`选` 是选项文字（界面按钮 `data-act="奇遇:<文字>"`）或下标；
   *  做不成（源碳 / 名额不够）就留在这一格，把原因写进提示（红条 = 失败 + 为什么）。 */
  选奇遇(选) {
    const r = 肉鸽.奇遇(选);
    if (r && r.ok === false) { 肉鸽界面.设结果('失败', r.why); this.开屏('大地图'); return r; }
    肉鸽界面.设结果('成功', r && r.事件 ? `事件「${r.事件}」：${r.选} → ${r.结果}` : '事件看完了。');
    this.开屏('大地图');
    return r;
  },
  存个档() { const ok = 肉鸽.存档(); 肉鸽界面.设结果(ok ? '成功' : '失败', ok ? '已存档（关掉页面也能继续）。' : '存档失败（浏览器不让存？）'); this.开屏('大地图'); return ok; },
  /* ---------------- ★ 记录屏（2026-10-11「记录也需要显示」） ----------------
     两个动作都转给 `肉鸽界面`（口子只有一个：`肉鸽界面.去记录()` / `清掉结果条()`）。 */
  去记录() { return 肉鸽界面.去记录(); },
  记录清结果() { return 肉鸽界面.清掉结果条(); },
  放弃本局() {
    肉鸽.失败('玩家放弃');
    肉鸽界面.设结果('失败', '本局结束：玩家放弃。');
    this.开屏('肉鸽结算');
    return true;
  },

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
    if (B.出击.length >= this.当前出击上限()) return false;   // 出击上限（3 → 6，见 当前出击上限()）
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
    /* 肉鸽模式：把名册前几台摆上（最多 = 出击上限）；练习模式：默认五人队里前几台（按当前 Lv 的上限） */
    const 上限 = this.当前出击上限();
    if (this.肉鸽编队模式 && 肉鸽.RUN) this.编队.出击 = 肉鸽.RUN.队伍.slice(0, 上限).map((m, i) => ({ 键: m.键, 位: i }));
    else this.编队.出击 = 默认五人队.slice(0, 上限).map(x => ({ 键: x.键, 位: x.位 }));
    this.刷();
    return this.编队.出击;
  },
};
