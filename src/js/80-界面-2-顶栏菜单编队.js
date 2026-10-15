  /* ---------------- 通用弹窗（隧道 / 休整 / 瞭望站 / 遗迹 / 侵蚀源都用它） ----------------
     ① 测试用：`界面.对话框钩子 = (标题, 文本, 选项) => 值` 直接顶替弹窗 —— **同步**返回那个值；
     ② 真的在浏览器里：记在 `this.弹窗` 上，当前那一屏（大地图 / 记录 / 晋升）末尾出现一排按钮，
        点一下走 `data-act="弹窗:<值>"` → 动作表里的 `弹窗` → `回答(值)`。
     ★★ 2026-10-13 修**真 bug**（作者 2026-10-13 试玩：「**很多选项点不了**」）：
        `对话框()` 原来在这一条路上 `return this.弹窗.答案` —— 而 `答案` 是玩家**之后**点按钮
        才填的，所以**那一刻**它一定是 `null`，函数立刻返回 null 退回给调用方。
        连锁反应（实测，见任务板「界面可点项审计」那一段）：
          · 隧道 / 休整 / 瞭望站 / 遗迹：结算当场按「没选」跑完第一项，再 `开屏('大地图')` 回地图 ——
            弹窗是画出来了，可玩家点它时动作已经做完（结果还跟点哪个按钮无关）；
          · 侵蚀源：`试着侵蚀源代价()` 拿着 `null` 继续往下走 → **弹窗没人回答，战斗却开了**，
            玩家根本没选过「硬闯 / 净化」；
          · 大地图上那颗「不招，继续前进」按钮（`data-act="跳过"`）**动作表里没有这个键** → 点了真的什么都不发生。
     现在的口径：**浏览器里返回 Promise**（玩家点哪一个，Promise 就 resolve 成那个值）；
       `对话框钩子`（测试 / 探针 / 录像重放）那条路**仍然是同步返回**，一行都没改。
       调用方统一用「同步值或 Promise 都认」的写法：`肉鸽弹窗()` / `试着侵蚀源代价()` / `去节点()`。
       没有 DOM 的裸 Node（连 `document.body` 都没有）仍然返回第一个选项 —— 那是**离线兜底**，
       浏览器与 `tests/lib/dom-stub.mjs`（两者都有 `document.body`）都走不到它。 */
  对话框(标题, 文本, 选项) {
    if (typeof this.对话框钩子 === 'function') return this.对话框钩子(标题, 文本, 选项);
    if (typeof document === 'undefined' || !document.body) return 选项 && 选项.length ? 选项[0].值 : null;
    this.弹窗 = { 标题, 文本, 选项, 答案: null };
    const 我 = this;
    const 等待 = new Promise(res => { 我.弹窗._落地 = res; });
    this.刷();
    return 等待;
  },
  /** 回答当前弹窗（界面上点按钮 / 测试直接调）：把答案填回去并让 `对话框()` 那个 Promise 落地。
   *  ⚠ 必须在清空 `this.弹窗` **之前**把答案填好 —— 动作表里 `弹窗:<值>` 走的就是这一句。 */
  回答(值) {
    const d = this.弹窗;
    if (d) {
      d.答案 = 值;
      if (typeof d._落地 === 'function') { const 落 = d._落地; d._落地 = null; 落(值); }
    }
    this.弹窗 = null;
    return 值;
  },
  弹窗控件Html() {
    const d = this.弹窗;
    if (!d) return '';
    /* ★ 2026-10-13 任务书 §1 模块 4 / 5：详情弹窗的正文里有 `<div>` / `<details>` / `<h4>` 这类**块级**内容 ——
       原来那一层是 `<p class="small">`，块级元素嵌在 `<p>` 里是**非法嵌套**（浏览器会把 `</p>` 提前收掉、
       正文的 DOM 结构就散了）。改成 `<div class="small dlg-body">`：**样式与文字一个字没变**
       （`.small` 是全局类，见 `main.css:40`），块级正文照旧放得下。`<h3>` 标题与那一排按钮都没动。
       ⚠ 按钮文字取 `o.名 || o.文`：旧调用点（`肉鸽弹窗`）给的是 `{值, 名}`，新调用点（藏品 / 机体详情）
         给的是 `{名, 文, 值}` —— 两种都能写对按钮文字。 */
    return `<div class="rv-card dlg"><h3>${d.标题}</h3><div class="small dlg-body">${d.文本 || ''}</div>
      <div class="acts" data-center="1">${(d.选项 || []).map(o => `<button data-act="弹窗:${o.值}">${o.名 || o.文 || o.值}</button>`).join('')}</div></div>`;
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
  /* ---------------- ★ 声音开关：每一屏都有、而且显眼（作者 2026-10-13 亲手提的两条 UI 修改之 A） ----------------
   * 作者原话：「**音乐关闭的按钮位置也不明显。每一个画面都要有**」「所有可选项都需要集中在画面中间」。
   *
   * **现状（改之前，逐处读过）**：开关全仓库**只有一颗** —— `src/shell.html:18` 的
   *   `<button class="sndbtn" id="btnSound">声音</button>`，钉在**顶栏 `.bar` 最右**（`.ctrl` 之后）。
   *   它由 `96-音乐.js` 的 `初始化()`（`src/js/96-音乐.js:83-101`）接线：点击 → `切开关()`（`:111-124`）、
   *   `M` 键 → 同一处、偏好存 `localStorage['mecha-autobattle-sound']`。
   *   ① 它**本来是全局的**（顶栏在 `#screen` 之外），但**长得不显眼**：只有两个字「声音 / 静音」、
   *      贴在 `.ctrl` 后面（那一排按屏变来变去），而且**只有点了才知道状态**（文字是「声音」= 开着，
   *      「静音」= 关着 —— 反过来读才对得上意思）；
   *   ② **读不到曲子时它整颗被隐藏**（`96-音乐.js:91-93` 的 `钮.hidden = true`；测试环境就是这样，
   *      `tests/audio.js` 第 [6] 段还逐字钉着这条降级）→ 那种机器上**一屏都看不到**这个开关；
   *   ③ **盖住顶栏的屏点不到它**：音乐鉴赏页（`audio/music-room.js` 的 `.modal`，`main.css:334` 是
   *      `position:fixed; inset:0` 的全屏层）把它整个压在下面。
   *
   * **改法（只动界面 / 布局层，`96-音乐.js` 一个字节都没动）**：
   *   · 开关**统一由 `声音钮Html()` 画**：**图标 + 文字**（`🔊 音乐：开 / 🔇 音乐：关`），
   *     `data-act="声音"` → 走**现成的动作表**（`动作表.声音` → `音乐.切开关()`，那条路一直在）；
   *   · **每一屏的 `#screen` 末尾各画一颗**（`.snd-inline`，`界面.刷()` 里自动加）——
   *     「每一个画面都要有」这条由它保证：**屏幕自己那段 HTML 里就有**，不靠顶栏在不在、也不靠顶栏可不可见；
   *   · **顶栏那一颗也补成同款**（补图标 + 文字，不再只是「声音」两个字），并且挪进 `.ctrl` 里，
   *     跟着「选项集中在画面中间」那条 CSS **一起居中** —— 一共两处，一屏都不少；
   *   · `M` 键**既有行为一个字没动**（那一条在 `96-音乐.js` 的 `初始化()` 里）；音乐鉴赏那条全屏层
   *     照样点得到：见文件末尾 `声音点击兜底()`（`document` 捕获层）。
   *   · 每次 `刷()` 调一次 `同步声音钮()`：**从 `音乐.开关` 现读**（不重画屏、不动音乐层、不绑死它的按钮 HTML），
   *     顶栏被音乐层隐藏时屏内那一颗照旧显示 —— 这台机器上读不到曲子时，开关仍然看得见、点得动。 */
  /** 一颗开关要写的字：**图标 + 文字**（开着 🔊 / 关着 🔇 —— 文字说的是「现在的状态」，不是「点它会发生什么」）。 */
  声音钮文字() { return (this.声音开着() ? '🔊 音乐：开' : '🔇 音乐：关'); },
  /** 现在声音是开着还是关着（**只读** `音乐.开关`；取不到音乐层时按「开着」显示，绝不抛异常）。 */
  声音开着() {
    try { return !(typeof 音乐 !== 'undefined' && 音乐 && 音乐.开关 === false); } catch (e) { return true; }
  },
  /** 一颗声音开关（`data-center` 由外面那一行带 —— 「选项集中在画面中间」那一条的判据就是这个属性）。 */
  声音钮Html(内联) {
    const 开 = this.声音开着();
    return `<button class="sndbtn${内联 ? ' snd-inline' : ''}${开 ? ' on' : ' off'}" data-act="声音"`
      + ` aria-pressed="${开 ? 'true' : 'false'}" title="音乐开关（按 M 也行）：点一下开 / 关">${this.声音钮文字()}</button>`;
  },
  /** 每一屏最后一行的声音开关（居中；`data-center="1"` = `main.css` 里那条居中的判据）。 */
  声音行Html() {
    return `<div class="opt-center snd-row" data-center="1" data-snd-row="1">${this.声音钮Html(true)}`
      + `<span class="small">点这里或者按 <b>M</b>：音乐开 / 关（这一屏就有，不用去顶栏找）</span></div>`;
  },
  /** 把页面上**每一颗**声音开关刷成现在的状态（顶栏那一颗 + 屏内那一颗）。
   *  ★ 只写 `textContent` / `aria-pressed` / `class`：**不重画屏**、不动 `96-音乐.js` 的按钮逻辑。 */
  同步声音钮() {
    const 文 = this.声音钮文字(), 开 = this.声音开着();
    const 刷一颗 = 钮 => {
      if (!钮) return;
      if (钮.textContent !== 文) 钮.textContent = 文;
      if (typeof 钮.setAttribute === 'function') 钮.setAttribute('aria-pressed', 开 ? 'true' : 'false');
      if (钮.classList && typeof 钮.classList.toggle === 'function') 钮.classList.toggle('on', 开);
    };
    try {
      if (typeof $ === 'function') 刷一颗($('#btnSound'));                          // 顶栏那一颗（屏外、所有屏都在）
      if (typeof document !== 'undefined' && document.querySelectorAll)
        for (const 钮 of document.querySelectorAll('.snd-inline')) 刷一颗(钮);        // 每一屏那一颗
    } catch (e) { /* 取不到 DOM（裸 Node / 测试替身）：一个字都不改，绝不抛 */ }
    return 文;
  },
  /** 顶栏那一颗的图标也要跟着状态走（`96-音乐.js` 的 `写按钮()` **只写文字** '声音 / 静音' ——
   *  那条口径是 `tests/audio.js` 第 [7] 段逐字钉着的，所以这里**不动它**；图标由 `同步声音钮()` 每屏补上）。 */

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
    /* ★ 作战记录屏（作者 2026-10-12）：顶上给一个回菜单（列表里还有「回战斗记录列表」） */
    if (this.屏 === '战斗记录') return `<button data-act="回菜单">回菜单</button>`;
    /* ★ 对局录像屏（作者 2026-10-12）：屏里自己有「复制录像 / 下载录像 / 回列表」 */
    if (this.屏 === '录像') return `<button data-act="去录像">录像列表</button><button data-act="回菜单">回菜单</button>`;
    /* ★ 调参室（§3.1）：回菜单 + 一句「只在调参室里生效」 */
    if (this.屏 === '调参室') return `<button data-act="回菜单">回菜单</button>`;
    return '';
  },

  /* ---------------- 菜单 ---------------- */
  菜单屏() {
    /* ★ 2026-10-13 职业排位（正交 4×2）：把这套接口挂到 `window.__game`（只在**还没挂过**时挂一次）。
       ★ 逐个 `typeof` 判 —— 分阶段施工里某个文件缺位时**不抛**（挂上几个算几个）；全在时与
         「一次性对象字面量」等价。 */
    if (typeof window !== 'undefined' && window.__game && !window.__game.职业排位角标) {
      const 排位接口 = {};
      if (typeof 职业排位参数 === 'function') 排位接口.职业排位参数 = 职业排位参数;
      if (typeof 职业排位开 === 'function') 排位接口.职业排位开 = 职业排位开;
      if (typeof 职业排位数 === 'function') 排位接口.职业排位数 = 职业排位数;
      if (typeof 职业排位命中修正 === 'function') 排位接口.职业排位命中修正 = 职业排位命中修正;
      if (typeof 职业排位暴击修正 === 'function') 排位接口.职业排位暴击修正 = 职业排位暴击修正;
      if (typeof 职业排位伤害倍率 === 'function') 排位接口.职业排位伤害倍率 = 职业排位伤害倍率;
      if (typeof 职业排位修理倍率 === 'function') 排位接口.职业排位修理倍率 = 职业排位修理倍率;
      if (typeof 尖兵首闪值 === 'function') 排位接口.尖兵首闪值 = 尖兵首闪值;
      if (typeof 特种产标层数 === 'function') 排位接口.特种产标层数 = 特种产标层数;
      if (typeof 职业排位角标 === 'function') 排位接口.职业排位角标 = 职业排位角标;
      Object.assign(window.__game, 排位接口);
    }
    /* ★ 2026-10-13 任务书 §1 模块 5：把纯读的 `机体详情Html(键或单位, 选项)` 挂到 `window.__game`。
       为什么挂在这里、不挂在 `80-界面-6`（函数本体就在那儿）：`window.__game` 是 `99-boot.js:321` 建的，
       而 `80-界面-6` 在它**之前**执行 —— 那一刻 `window.__game` 还不存在（写在那儿会挂空）。
       `菜单屏()` 是**运行期**必然走一次的那一处（`boot()` → `开屏('菜单')` → 刷 → 菜单屏），
       而且这段判据与上面「职业排位接口」那段**同一个样板**（只在还没挂过时挂一次、`typeof` 逐个判）。
       `tools/build-route-map.mjs` 的「运行期导出」扫描认下面这一句的直接赋值（归到「直接赋值」那一组）。 */
    if (typeof window !== 'undefined' && window.__game && !window.__game.机体详情Html) {
      if (typeof 机体详情Html === 'function') window.__game.机体详情Html = 机体详情Html;
    }
    /* ★ 对局上报（实现在 `src/js/8a-上报.js`；作者 2026-10-12 拍板「网页端任何人玩了以后都留一条记录」）：
       进菜单时（**页面加载时 `boot()` 走的也是同一条路**：`开屏('菜单')` → 刷 → 菜单屏）顺手把
       「还没上报过的肉鸽整局」POST 走。**纯追加**：`上报地址` 为空（默认）时 `顺便传()` 第一句就返回，
       一次 fetch 都不发、一个字节都不刷屏 —— 与加这一行之前完全一致。 */
    if (typeof 上报 !== 'undefined' && 上报) 上报.顺便传();
    const 有存档 = !!肉鸽.读存档();
    return `<section class="card menu">
      <h3>机甲指挥 · 晋升 + 零件（大地图上用的那一批）</h3>
      <p>自动战斗回合制 RPG：把机体摆进<b>4×2 正交阵型（前排 4 格 / 后排 4 格，四路上下对齐）</b>的 8 格棋盘（一开始上 4 台，最多 6 台），每回合给全队下一条<b>大方向方针</b>（单位层只管大招开不开），这一回合按速度自动打完。</p>
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
      <div class="acts" data-center="1">
        <button class="primary" data-act="去分队">新的一局（肉鸽）→</button>
        ${有存档 ? `<button data-act="继续上一局">继续上一局（第 ${肉鸽.读存档().层} 层）</button>` : ''}
        <button data-act="去编队">练习：直接编队打一场</button>
        <button data-act="去调参室">调参室（作者调难度）</button>
        <!-- ★ 作战记录（作者 2026-10-12「作战记录你看看能不能安排保存一下」）：N = 现在存了几场。
             0 场时这个入口照旧能进，进去写一句「还没有作战记录」—— 没打过战斗时这个入口不许崩。 -->
        <button data-act="去战斗记录">战斗记录（最近 ${战斗记录.读().length} 场）</button>
        <!-- ★ 对局录像（作者 2026-10-12「录操作，不录局面」）：N = 已封存几局（上限 20，超了从最老丢）。
             0 局时这个入口照旧能进，进去写一句「还没有封存的录像」—— 没走过一局时这个入口不许崩。 -->
        <button data-act="去录像">对局录像（最近 ${录像.读().封存.length} 局）</button>
        <button data-act="音乐鉴赏">音乐鉴赏</button>
      </div>
      <p class="small">网格大地图照战棋 <code>26-地图生成.js</code> / <code>28-层.js</code> / <code>30-移动与节点.js</code> 实现
        （数值逐字照抄，出处写在 <code>91-地图.js</code> 里）；机体图标是原创矢量素材（<code>art/mech-icons.js</code>）；
        音乐按场景切，<b>放大招</b>时切成那台机体的主题曲、保持到本回合结束。右上角是声音开关（按 <b>M</b> 也行）。</p>
      ${typeof 上报 !== 'undefined' && 上报 ? 上报.菜单块() : ''}
    </section>`;
  },

  /* ---------------- 编队 ---------------- */
  /** 这一屏最多能上几台（作者 2026-10-10 **第二次拍板**：按**肉鸽等级**算，起始 3 台、每 3 级 +1、封顶 6）。
   *  肉鸽里走 `肉鸽.出击上限()`（= `RUN.等级` → `05-阵型.js` 的 `出击上限()`）；
   *  练习模式没有 RUN、也没有肉鸽等级，走**旧口径** `出击上限按机体等级(编队.等级)`
   *  （Lv10 → 3 台、Lv15 → 4、Lv20 → 5、Lv25+ → 6）。 */
  当前出击上限() {
    /* ★ 调参室（§3.2「从全角色里挑 3–6 台」）：调参室里**固定 6 台**，不跟着等级走
       （练习模式的旧口径一个字没改：`出击上限按机体等级()`）。 */
    if (this.调参模式) return 调参出击上限;
    if (this.肉鸽编队模式 && 肉鸽.RUN) return 肉鸽.出击上限();
    return 出击上限按机体等级(this.编队.等级);
  },
  /** 出击上限那一句说明（编队屏的标题 + 拖不进去时的提示都用它，口径只有一份）：
   *  肉鸽里写「**两级封顶**：等级那条线几台 / 最多 6 台，藏品 +N 台、最多加到 9 台」；
   *  练习模式写旧口径（练习模式没有 RUN、也没有藏品加成，封顶仍是 6）。 */
  出击上限说明() {
    const 上限 = this.当前出击上限();
    if (this.调参模式) return `出击上限 ${上限} 台（**调参室**：作者要的「从全角色里挑 3–6 台」，这里固定 6 台；练习模式那句「按机体等级」在调参室里不生效）`;
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
      /* ★ 2026-10-13 任务书 §1 模块 5：**编队屏候选卡**的「ⓘ 详情」（5 屏入口之一）。
         ⚠ 用 `<span role="button">` 嵌在 `<button class="pick">` 里面 —— 这一屏的候选卡**没有**
           `disabled`（点一下就选中），所以不必像招募屏那样套一层壳；而 `<button>` 不能嵌 `<button>`，
           所以内层只能是 `<span>`。事件委托按 `closest('[data-act]')` 取**最里面**那个 → 点详情走
           `看机体`、点卡片其它地方照旧走 `选人:<键>`（**原来那条一个字节没改**）。 */
      return `<button class="pick${B.选中 === t.mech ? ' on' : ''}${已上 ? ' used' : ''}" data-act="选人:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}">
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}${肉鸽模式 ? ` · Lv${t.等级}` : ''}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}${p.大招.length ? ` · 大招 ${p.大招.length}` : ''}</span>
        ${特色摘要(t).文本 ? `<div class="特色摘要" data-特色摘要="1">${特色摘要(t).文本}</div>` : ''}
        <span class="mech-info-btn" role="button" tabindex="0" data-act="看机体:${t.mech}" title="查看 ${t.pilot} 的机体特性与武器详情">ⓘ 详情</span>
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
        /* ★ 2026-10-13 职业排位（正交 4×2 · 预告层）：卡片上先给一句「这个职业站这儿对不对」。
           总闸关掉 / 查不到职业 → 空串 → 模板**逐字不变**（不多一个 `<span>`）。 */
        const 排位标 = typeof 职业排位角标 === 'function' ? 职业排位角标({ 键: 占.键, slot: 位, tags: p && p.tags }, null) : '';
        const 排位行 = 排位标 ? '<span class="特色角标">' + 排位标 + '</span>' : '';
        行格.get(r).push(`<button class="slot filled" data-act="取回:${位}" data-drag="位:${位}" data-drop="${位}" style="--fc:${势力色(占.键)}">
          <span class="pos">${位名(位)}</span>
          <span class="pk-top">${图标.卡(占.键, 'ally', 图标.尺寸.格)}<span class="pk-nm"><b>${this.单位名(占.键, 'ally')}</b><small>${占.键} · 速 ${p.速度}</small></span></span>
          <span class="nums">HP ${p.hp}</span>
          ${排位行}
          ${特色摘要(占.键).文本 ? `<div class="特色摘要" data-特色摘要="1">${特色摘要(占.键).文本}</div>` : ''}
          <!-- ★ 2026-10-13 任务书 §1 模块 5：**阵型格**上的「ⓘ 详情」（5 屏入口之一）。
               同样只能是 span role=button（外层已经是 button class="slot filled"，
               而 tests/faction-7 用 /&lt;button class="slot filled"[…]*?&lt;\/button&gt;/g 逐张对账 ——
               里面**不能出现 &lt;/button&gt;**，用 span 既点得到又不破坏那一条断言）。 -->
          <span class="mech-info-btn" role="button" tabindex="0" data-act="看机体:${占.键}" title="查看 ${this.单位名(占.键, 'ally')} 的机体特性与武器详情">ⓘ 详情</span></button>`);
      } else {
        行格.get(r).push(`<button class="slot" data-act="放位:${位}" data-drop="${位}"><span class="pos">${位名(位)}</span><b>空位</b><small>${行名(r)}</small></button>`);
      }
    }
    /* ★ 2026-10-13（正交 4×2）：两排都固定四列，上下**严格对齐**（`.编队屏 .grid .row` 也是 `repeat(4,1fr)`） */
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
    const 牌池预览块 = (typeof 战术卡牌开 === 'function' && 战术卡牌开() && typeof 生成队伍牌池 === 'function') ? (() => {
      /* ★ P1.2 §1.4（练习战与肉鸽牌库严格隔离）：**只有肉鸽态才显式传 `已选战术牌`**；
         练习态**不传**这个键 —— 严格只用当前参战编队自己派生的三层牌池，绝不继承正在进行的肉鸽局牌库。 */
      const 预览选项 = { 补齐基础激励: true };
      if (肉鸽模式 && 肉鸽.RUN && Array.isArray(肉鸽.RUN.战术牌库)) 预览选项.已选战术牌 = 肉鸽.RUN.战术牌库;
      const 预览池 = 生成队伍牌池(B.出击.map(x => ({ 键: x.键, 位: x.位 })), 预览选项);
      const 初Html = 预览池.初始手牌.map(c => {
        const 耗 = Number(c.耗气) || 0, 回 = Number(c.回气) || 0;
        const 气标 = 回 > 0 ? `+${回}气` : `耗${耗}气`;
        return `<span class="tp-chip init" title="${c.效果说明}"><b>【${c.精神标签 || c.层级}】${c.名}</b><small>${c.层级}·${c.归属}｜${气标}</small></span>`;
      }).join('') || '<span class="small">（无）</span>';
      const 条Html = 预览池.待触发牌.map(c =>
        `<span class="tp-chip cond" title="${c.效果说明}">🔒<b>【${c.名}】</b><small>${c.触发说明}</small></span>`
      ).join('') || '<span class="small">（无）</span>';
      return `<div class="tactical-deck-preview" data-tactical-preview="1">
        <h4>🎴 本场出击战术牌池预览<span class="small">初始手牌 ${预览池.初始手牌.length} 张 · 条件触发牌 ${预览池.待触发牌.length} 张（随参战职业/势力/角色实时变化）</span></h4>
        <div class="tdp-row"><span class="tdp-label">⚡ 初始手牌（开战直接入牌）：</span><div class="tdp-chips">${初Html}</div></div>
        <div class="tdp-row"><span class="tdp-label">🔒 条件触发牌（战中达成条件发牌）：</span><div class="tdp-chips">${条Html}</div></div>
      </div>`;
    })() : '';
    return `<section class="编队屏">
      <div class="col 候选" data-drop="候选">
        <h3>${肉鸽模式 ? `名册（${候选.length} 台）` : `机师（${候选.length} 名）`}<span class="small">拖到右边格子里，或者点一名再点格子；格子之间也能拖（互换）</span></h3>
        ${肉鸽模式 ? '' : `<div class="filters" data-center="1">
          ${[10, 20, 30].map(n => `<button class="mini${B.等级 === n ? ' on' : ''}" data-act="等级:${n}">Lv${n}</button>`).join('')}
          <span class="sep"></span>
          ${势力们.map(f => `<button class="mini${B.势力 === f ? ' on' : ''}" data-act="势力:${f}">${f}</button>`).join('')}
        </div>`}
        <div class="picks" data-center="1">${列表}</div>
      </div>
      <div class="col 站位">
        <h3>出击编队（${B.出击.length} / ${上限}）<span class="small">4×2 正交阵型：上排 = 后排 4 格，下排 = 前排 4 格（四路上下对齐）；${this.出击上限说明()}</span></h3>
        <!-- ★ 2026-10-13：界面上那句提示（this.提示）原来在**编队屏上根本没画** —— 「点空位没反应」「拖不进去（超过出击上限）」
             那两句提示设了也没人看得到。这里补一行（空的时候不画，别的屏一个字都不改）。 -->
        ${this.提示 ? `<p class="warn small" data-form-hint="1">${this.提示}</p>` : ''}
        <div class="grid">${格.join('')}</div>
        <div class="acts" data-center="1">
          <button data-act="默认五人队">${肉鸽模式 ? `把名册前 ${上限} 台摆上` : `摆上前 ${上限} 台`}</button>
          <button data-act="清空">清空</button>
        </div>
        ${牌池预览块}
        ${肉鸽模式 ? `<p class="small">这一场：第 ${肉鸽.RUN.层} 层 <b>${节点类型表[当前节点 && 当前节点.类型] ? 节点类型表[当前节点.类型].名 : '作战'}</b>（敌人由编成表随机抽；敌人等级按层数走）</p>
          <div class="acts" data-center="1"><button class="primary" data-act="开战">开战 →</button><button data-act="回大地图">回大地图</button></div>`
        : `<h3>敌方编成<span class="small">（方案第 10 节第 4 条：这 3 条是初稿，等作者配）</span></h3>
          <select id="编成选" data-act="编成" class="sel">${编成选项}</select>
          <div class="acts" data-center="1"><button class="primary" data-act="开战">开战 →</button></div>`}
        ${选中 ? `<p class="small">已选：${this.单位名(B.选中, 'ally')}（${B.选中}，速度 ${选中.速度}${选中.大招.length ? `，大招：${选中.大招.join('、')}，第 ${选中.开场} 回合起` : '，没有大招'}）</p>` : '<p class="small">还没选机师。</p>'}
      </div>
      <!-- ★ 2026-10-13 任务书 §1 模块 4 / 5：编队屏上点「ⓘ 详情」也要弹得出正文 —— 弹窗控件原来只在
           大地图 / 记录 / 晋升三屏画（界面.弹窗控件Html()），这里补一份，全屏通用才算数。 -->
      ${this.弹窗控件Html()}
    </section>`;
  },

