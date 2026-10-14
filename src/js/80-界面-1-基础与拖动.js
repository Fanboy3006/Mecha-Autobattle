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
  肉鸽战斗类型: null,             // ★ 这一场**改写用**的节点类型（`null` = 用脚下这一格的真实类型）。
                                  //   谁写它：`准备肉鸽编队()`（走进去那一格）、`追击战()`（写成 `'追击'`）——
                                  //   两者都在开打**之前**写，所以 `打这一场()` 只要非 null 就照它跑。
                                  //   ⚠ 2026-10-13 修「很多选项点不了」时改的：这里原来写死 `'作战'`，
                                  //   而 `打这一场()` 是 `this.肉鸽战斗类型 || 脚下格类型` —— 于是**永远**
                                  //   取到 `'作战'`，侵蚀源那一格「先付代价」的弹窗判断（要 `=== '侵蚀源'`）
                                  //   一次都不会成立 → 弹窗没人回答就直接开打（见 `打这一场()` 顶上那一段）。
                                  //   打完之后它被写回**这一场真正用的那个类型**（不是写死 `'作战'`），
                                  //   所以「下一场回到脚下这一格」这条老语义一个字都没变。
  肉鸽编队模式: false,            // 编队屏是「肉鸽里出战前编队」还是沙盒练习
  调参模式: false,                // ★ 调参室（§3.2）：出击上限固定 6、编队状态同步进调参设置；
                                 //   只在「调参室 / 战斗 / 结算」这几屏里开着（`开屏()` 里会关掉）
  种子: null,
  /* ★ 作战记录（作者 2026-10-12：「**现在这个作战记录你看看能不能安排保存一下**」）——
     实现在 `src/js/88-战斗记录.js`（**独立** localStorage 键，和肉鸽存档 `存档键` 无关）。
     界面这一层只管四件事：① 一场打完存一份；② 结算屏上画「本场记录」；③ 菜单上的
     「战斗记录（最近 N 场）」屏；④ 复制为文本 / 下载 .txt（失败各有可见兜底）。 */
  本场记录: null,                 // 刚打完那一场的记录（`战斗记录.做一场()` 给的；结算屏画它）
  本场规格: null,                 // 这一场开打时的规格（我方 / 敌方 / 条目 / 层 / 节点类型 / 波次）
  方针历史: {},                   // 回合号 → 这一回合下的方针（导出文本里的「方针表」）
  记录保存: null,                 // 存这一场的结果（`战斗记录.存()`；三层反馈的「保存」那一层）
  记录已存的ctx: null,            // 同一场只存一次（`到结算()` 有可能被重复调用）
  记录选: null,                   // 记录屏里正在看第几场（`战斗记录.读()` 的下标；null = 列表）
  复制结果: null,                 // 「复制为文本」的可见反馈（失败时带整段文本 → 摊在屏上）
  下载结果: null,                 // 「下载 .txt」的可见反馈
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
    /* ★ 2026-10-13：进**编队屏**先把上一轮留下的提示（「先点一名机师」/「出击上限」）清掉 ——
       编队屏现在会画这一行（见 `编队屏()`），不清的话从别处绕回来还挂着上一句话。 */
    if (名 === '编队') this.提示 = '';
    /* ★ 调参室（作者 2026-10-12 的第 3 件，规格书 §3.2）：**调参模式**只在
       「调参室 → 看一场的战斗 → 那场的结算」这几屏里有效；换到别的屏（菜单 / 编队 / 肉鸽…）
       就关掉 —— 练习模式与肉鸽因此**一个字节都不受影响**。 */
    if (名 !== '调参室' && 名 !== '战斗' && 名 !== '结算') this.调参模式 = false;
    this.刷();
    /* M5：切屏跟着换曲子（方案 8.2）。`96-音乐.js` 在最后，加载期/测试期取不到就跳过 —— 音乐是可选层，
       任何一种「读不到曲子」的情况都不该让界面切屏失败（M5 的降级规矩）。 */
    if (typeof 音乐 !== 'undefined' && 音乐 && typeof 音乐.场景切换 === 'function') 音乐.场景切换(名);
    return this;
  },

  刷() {
    const 屏 = $('#screen');
    /* ★ 2026-10-13（作者拍板 A）：**每一屏的选项区末尾都挂一行「🔊 音乐：开 / 🔇 音乐：关」**——
       它画在 `#screen` **里面**，所以「每一个画面都要有」这条**不依赖顶栏**（顶栏那一颗读不到曲子时
       会被 `96-音乐.js` 隐藏；音乐鉴赏那种盖住顶栏的全屏层也照样点得到屏内这一颗）。
       一律加在屏本体之后：**屏自己的 HTML 一个字都没改**（只多这一行），老的 `data-act` 断言照旧能匹配。 */
    if (屏) 屏.innerHTML = (this[this.屏 + '屏'] ? this[this.屏 + '屏']() : '') + this.声音行Html();
    this.刷顶栏(); this.刷控件();
    this.接线();
    /* 顶栏那一颗也要显示成「🔊 音乐：开」这种**图标 + 文字**（`96-音乐.js` 只写 '声音 / 静音'，这里补图标）。 */
    this.同步声音钮();
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
        /* ★★ 2026-10-13 修**真 bug**（界面线报「调参室那一屏的选项点了行为不对 / 没反应」）：
           这一句原来写的是 `const [动, 参] = String(data-act).split(':')` ——
           **解构只取前两个元素**，所以含 **≥2 个 `:`** 的 `data-act`（`调参室:类型:精英`、`调参室:层:3`…）
           第三段起**全被丢掉**：`动作()` 收到 `('调参室', '类型')`，`调参室动作()` 再拆一次只剩空参数
           （`类型 = ''` / `层 = 0` / `场次 = 1`）→ **选项点了行为不对**（不是没画出来，是画出来了、点了不算数）。
           ⚠ **这不是 Node / `split` 的 bug**（界面线一度这么诊断，已被统筹判错）：
             `'a:b:c'.split(':')` 老老实实给三个元素；错的是**解构只要两个**，全仓库没有一处 `split` 写错。
           改法：按**第一个** `:` 拆一次，**它之后的所有段原样留着**当「参」
           （下游 `动作内()` / `调参室动作()` 那两处「再按第一个 `:` 拆一次」的写法一个字都没改）。
           没有 `:` 时「参」= `null`：**不是 `''`**，与 `split` 时代的 `undefined` 一样都过 `参 == null` 的判定。
           为什么这样最小：只动这一句、只多一个 `indexOf`，派发的形状（`动作(动, 参)`）没变，
           整键动作（`开新局`）/ 两段式 `弹窗:藤蔓` / 一段式 `选分队:近卫` 三条老路逐字同路；
           而且对**任意段数**都成立（4 段、5 段也不会再丢）。 */
        const 串 = String(t.getAttribute('data-act'));
        const 切点 = 串.indexOf(':');
        const 动 = 切点 < 0 ? 串 : 串.slice(0, 切点);
        const 参 = 切点 < 0 ? null : 串.slice(切点 + 1);
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
   *    ② 动作表里直接写了带冒号的键名（例如 `黑市买:g2` 不会这样写，但 `黑市离开` 是整键）—— 先查整键。
   *  ★ 对局录像（作者 2026-10-12，实现在 `89-录像.js`）：**这里是动作派发的唯一入口**，
   *    所以录像的钩子也只挂在这一处（`派发前` / `派发后`）—— 界面上的每个按钮都经过它，
   *    不每个按钮各记一份。没有进行中的肉鸽局（练习模式 / `simulate()` / 平衡工具 / 调参室）时
   *    `录像` 一个字节都不写；`tools/replay.mjs` 也从这个入口逐条重放。 */
  动作(动, 参) {
    if (动 == null) return null;
    const 名 = String(动);
    const 有录像 = (typeof 录像 !== 'undefined' && 录像);
    if (有录像 && typeof 录像.派发前 === 'function') 录像.派发前(this, 名, 参);
    const 回 = this.动作内(名, 参);
    if (有录像 && typeof 录像.派发后 === 'function') 录像.派发后(this, 名, 参, 回);
    return 回;
  },
  /** `动作()` 的本体（原来整个身子就在 `动作()` 里；2026-10-12 挪出来，只为了给录像留一个入口）。 */
  动作内(名, 参) {
    /* ★★ 2026-10-13 修**真 bug**（作者：「遗迹三选一还是选不了」/「有弹窗，但点了完全没反应」）：
      界面上点弹窗按钮走的是 `接线()` 那一句
          `const [动, 参] = String(data-act).split(':');  this.动作(动, 参)`
      —— `data-act="弹窗:藤蔓"` 被**先按 `:` 拆开**，传进来的就是 `名 = '弹窗'`、`参 = '藤蔓'`。
      下面那条 `名.indexOf('弹窗:') === 0` 只认**没拆过的整串**，于是 `回答()` 从来没被调用过：
      **弹窗不消失、状态一个字节都不动**（正是作者看到的那个症状）。
      更早那一版 `对话框()` 同步返回 null（弹窗刚画出来就当场按「没选」结算完），
      所以这个「拆参数」的坑一直显不出来 —— 改成 Promise 之后它才浮出来。
      同一屏上别的按钮点得动，是因为它们的 `data-act` **不带 `:`**（`回大地图` / `去晋升` 这类），
      或者参数本来就该用 `动作:参数` 那条通用分支（`去节点:29` / `休整:耐久`）——
      **全文只有弹窗这一族是「动作名 + 参数」两个 `:` 段**，所以只有它坏。
      两路都接住：`弹窗:<值>`（测试 / 探针 / 录像重放直接喂整串）与 `('弹窗', '<值>')`（浏览器）。
      这里**不动 `接线()`**：它那句拆分是通用的、别处都靠它，改它风险更大。 */
    if (名.indexOf('弹窗:') === 0) return this.回答(名.slice(3));
    if (名 === '弹窗' && 参 != null) return this.回答(参);
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
    /* ★ 作战记录（作者 2026-10-12）：菜单入口 / 列表里点一场 / 两个导出按钮 */
    去战斗记录: function () { return this.去战斗记录(); },
    看战斗记录: function (参) { return this.看战斗记录(参); },
    回战斗记录: function () { return this.回战斗记录列表(); },
    复制记录: function () { return this.复制本场记录(); },
    下载记录: function () { return this.下载本场记录(); },
    /* ★ 对局录像（作者 2026-10-12）：菜单入口 / 看某一局 / 复制 / 下载 / 理由输入框的展开。
       实现在 `89-录像.js`（录操作不录局面）；这几个动作**自己不进录像**（只是「看 / 导出」）。 */
    去录像: function () { return 录像.去录像(); },
    看录像: function (参) { return 录像.看录像(参); },
    回录像: function () { return 录像.回列表(); },
    复制录像: function () { return 录像.复制当前(); },
    下载录像: function () { return 录像.下载当前(); },
    录像理由: function () { return 录像.切理由(); },
    /* ★ 2026-10-13 录像线「一键保存录像」（作者：「太复杂了，你再想想还有什么方法」）：
       点一次 → 一个自包含 JSON 落到**浏览器默认下载目录**（不弹对话框、不问任何东西）。
       实现在 `89-录像.js` 的 ⑥b；这两颗按钮在**大地图 / 本局结算屏 / 战斗结算屏**上。 */
    保存本局录像: function () { return 录像.保存本局(); },
    保存全部录像: function () { return 录像.保存全部(); },
    /* ★ 对局上报（`src/js/8a-上报.js`）：菜单里那两个按钮 —— 开关（开 / 关，存 localStorage）与
       「试传一条」（拿最新一局录像或一条最小样例，成功 / 失败都有一句可见反馈）。
       地址为空（默认）时菜单里根本不画这两个按钮（`上报.菜单块()` 返回空串）。 */
    上报开关: function () { return 上报.切开关(); },
    上报试传: function () { return 上报.试传一条(); },
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
    /* ★ 2026-10-12「记录导出」（作者：「需要一个对话在理解规则的情况下检视我的游戏记录」）：
       **本局日志（`RUN.日志`）**的复制 / 下载 —— 数据层在 `88-战斗记录.js`、界面在 `92-肉鸽界面.js`，
       这里只留两个动作名（记录屏 + 大地图上各有一对按钮，走的是同一对函数）。 */
    复制日志: function () { return this.复制本局日志(); },
    下载日志: function () { return this.下载本局日志(); },
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
    /* ★ 调参室（作者 2026-10-12 的第 3 件，`95-调参室.js`）：
       `去调参室` = 菜单上那个入口；`调参室:<子动作>[:参数]` = 屏里所有按钮（`动作()` 只按第一个 `:`
       拆一次，所以子动作名连同它自己的参数一起作为「参」传下去，由 `调参室动作()` 再拆一次）；
       `看一场` = §3.4 那个「用正常战斗界面播这一场」。 */
    去调参室: function () { return 去调参室(); },
    调参室: function (参) { return 调参室动作(参); },
    /* 下拉单独一个动作名：接线对 `SELECT` 传的是**它的 value**（敌人键），当「参」用 */
    调参选敌人键: function (参) { return 调参选敌人键(参); },
    看一场: function () { return 调参开一场(调参室模型.看一场种子); },
  },

